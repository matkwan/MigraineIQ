//
//  BackgroundTaskCoordinator.swift
//  MigraineIQ
//
//  Manages the nightly `BGProcessingTask` that recomputes the 24-hour
//  migraine risk forecast while the device is idle overnight.
//
//  Usage
//  ─────────────────────────────────────────────────────────────────────────
//  1. Call `BackgroundTaskCoordinator.registerHandler()` from `App.init()`
//     before the app finishes launching (BGTaskScheduler requirement).
//  2. Call `shared.configure(...)` from `DependencyContainer.init()` to
//     inject the repositories the task needs.
//  3. Call `shared.scheduleNightlyRun()` once the app is in the foreground
//     to queue the first (and every subsequent) overnight run.
//
//  Xcode requirements
//  ─────────────────────────────────────────────────────────────────────────
//  Target → Signing & Capabilities → + Capability:
//    • Background Modes → check "Background processing"
//  Info.plist:
//    • BGTaskSchedulerPermittedIdentifiers → [nightlyRiskIdentifier]
//    • UIBackgroundModes → ["processing"]   (Xcode adds this automatically)
//
//  Notification note
//  ─────────────────────────────────────────────────────────────────────────
//  When risk ≥ .elevated the task delegates to NotificationService.shared
//  which schedules a Time Sensitive 7 am alert (requires the
//  "Time Sensitive Notifications" entitlement in Xcode).
//

import Foundation
import BackgroundTasks

@Observable
@MainActor
final class BackgroundTaskCoordinator {

    // MARK: - Identifier

    static let nightlyRiskIdentifier = "com.kieny.migraineiq.nightly-risk"

    // MARK: - Shared instance

    /// Accessed by the BGTaskScheduler handler closure, which runs before
    /// DependencyContainer may be fully initialised. Repositories are
    /// injected via `configure(...)` immediately after DependencyContainer
    /// sets up its own graph.
    static let shared = BackgroundTaskCoordinator()

    // MARK: - Injected dependencies (set by DependencyContainer)

    private var headacheRepository:   HeadacheRepositoryProtocol?
    private var aiInsightsRepository: (any AIInsightsRepositoryProtocol)?

    private init() {}

    // MARK: - Registration (call from App.init before app finishes launching)

    /// Registers the BGProcessingTask handler with the system scheduler.
    /// **Must be called from `App.init()`** — BGTaskScheduler rejects
    /// registration after `applicationDidFinishLaunching` returns.
    nonisolated static func registerHandler() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: nightlyRiskIdentifier,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                await BackgroundTaskCoordinator.shared.handle(processingTask)
            }
        }
    }

    // MARK: - Configuration

    /// Called by DependencyContainer after it builds the repository graph.
    func configure(
        headacheRepository:   HeadacheRepositoryProtocol,
        aiInsightsRepository: (any AIInsightsRepositoryProtocol)?
    ) {
        self.headacheRepository   = headacheRepository
        self.aiInsightsRepository = aiInsightsRepository
    }

    // MARK: - Scheduling

    /// Submits a BGProcessingTaskRequest to run sometime after 2 am.
    /// Safe to call repeatedly — BGTaskScheduler silently replaces any
    /// existing pending request with the same identifier.
    func scheduleNightlyRun() {
        let request = BGProcessingTaskRequest(identifier: Self.nightlyRiskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower       = false
        request.earliestBeginDate           = nextOccurrenceOf(hour: 2, minute: 0)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Scheduling failures are non-fatal — the next foreground launch
            // will attempt to reschedule.
        }
    }

    // MARK: - Task handler

    private func handle(_ task: BGProcessingTask) async {
        // Re-schedule immediately so future nights are covered even if this
        // run is cancelled early by the system.
        scheduleNightlyRun()

        guard
            let headacheRepo = headacheRepository,
            let aiRepo       = aiInsightsRepository
        else {
            task.setTaskCompleted(success: true)  // AI not configured — not an error.
            return
        }

        // Cancel the task if the system reclaims it before we finish.
        let workTask = Task {
            let useCase = PredictMigraineRiskUseCase(
                headacheRepository: headacheRepo,
                aiRepository: aiRepo
            )
            return try await useCase.execute()
        }
        task.expirationHandler = {
            workTask.cancel()
            task.setTaskCompleted(success: false)
        }

        do {
            let alert = try await workTask.value
            persistAlert(alert)
            if alert.riskLevel == .elevated || alert.riskLevel == .high {
                await NotificationService.shared.scheduleRiskAlert(for: alert)
            }
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
    }

    // MARK: - Risk cache (mirrors DashboardViewModel's key)

    private static let riskCacheKey = "com.migraineiq.cachedRiskAlert"

    private func persistAlert(_ alert: PredictiveAlert) {
        guard let data = try? JSONEncoder().encode(alert) else { return }
        UserDefaults.standard.set(data, forKey: Self.riskCacheKey)
    }

    // MARK: - Date helpers

    private func nextOccurrenceOf(hour: Int, minute: Int) -> Date {
        let cal = Calendar.current
        var components        = DateComponents()
        components.hour       = hour
        components.minute     = minute
        components.second     = 0
        // `nextDate` always returns tomorrow-or-later if `matchingPolicy` is
        // `.nextTimePreservingSmallerComponents` and the time has already passed today.
        return cal.nextDate(
            after: Date(),
            matching: components,
            matchingPolicy: .nextTimePreservingSmallerComponents
        ) ?? Date().addingTimeInterval(86_400)
    }
}

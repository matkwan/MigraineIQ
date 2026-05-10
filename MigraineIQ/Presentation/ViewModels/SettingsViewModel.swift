//
//  SettingsViewModel.swift
//  MigraineIQ
//
//  Manages Settings screen state: HealthKit permission and notification status.
//
//  HealthKit authorization note
//  ─────────────────────────────────────────────────────────────────────────
//  iOS does not expose whether the user granted or denied individual HK
//  types — it only lets us know if the authorization prompt has been shown
//  (to protect user privacy). Consequently our status has three states:
//    .unavailable   — device has no HealthKit (rare; some iPads)
//    .notRequested  — prompt has never been shown; show "Connect" button
//    .requested     — prompt was shown; data flows if granted, silently
//                     returns nothing if denied. Direct user to iOS Settings
//                     if they want to change access after the fact.
//

import SwiftUI
import UserNotifications

@Observable
@MainActor
final class SettingsViewModel {

    // MARK: - Types

    enum HealthKitStatus {
        case unavailable
        case notRequested
        case requested
    }

    enum NotificationStatus {
        case unknown
        case authorized
        case denied
    }

    // MARK: - State

    private(set) var healthKitStatus: HealthKitStatus = .notRequested
    private(set) var isRequestingHealthKit: Bool = false
    private(set) var requestError: String? = nil

    private(set) var notificationStatus: NotificationStatus = .unknown

    // MARK: - Dependencies

    private let healthDataRepository: (any HealthDataRepositoryProtocol)?

    // MARK: - Init

    init(healthDataRepository: (any HealthDataRepositoryProtocol)?) {
        self.healthDataRepository = healthDataRepository
        refreshHealthKitStatus()
    }

    // MARK: - HealthKit

    /// Reads current authorization state from the repository.
    func refreshHealthKitStatus() {
        guard let repo = healthDataRepository else {
            healthKitStatus = .unavailable
            return
        }
        healthKitStatus = repo.isAuthorized ? .requested : .notRequested
    }

    func requestHealthKitAccess() async {
        guard let repo = healthDataRepository else { return }
        guard !isRequestingHealthKit else { return }

        isRequestingHealthKit = true
        requestError = nil
        defer { isRequestingHealthKit = false }

        do {
            try await repo.requestAuthorization()
            refreshHealthKitStatus()
        } catch {
            requestError = "Couldn't connect to HealthKit. Please try again."
        }
    }

    // MARK: - Notifications

    /// Checks the current system notification authorization status.
    func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            notificationStatus = .authorized
        case .denied:
            notificationStatus = .denied
        default:
            notificationStatus = .unknown
        }
    }

    // MARK: - System Settings

    /// Opens iOS Settings — works for both HealthKit and notification access.
    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

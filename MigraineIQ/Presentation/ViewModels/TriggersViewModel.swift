//
//  TriggersViewModel.swift
//  MigraineIQ
//
//  Drives the trigger-analysis section of the Insights tab.
//  Wraps AnalyzePersonalTriggersUseCase so the view stays declarative.
//
//  Offline strategy
//  ─────────────────────────────────────────────────────────────────────────
//  After each successful API call the result is persisted to UserDefaults.
//  When the device is offline (NWPathMonitor), the cached result is served
//  instead of showing an error card. If there is no cache and the device is
//  offline, a clear offline message is shown via .failed so the retry button
//  remains functional once connectivity is restored.
//  ─────────────────────────────────────────────────────────────────────────
//

import Foundation
import Observation

@Observable
@MainActor
final class TriggersViewModel {

    // MARK: - View state

    enum ViewState: Equatable {
        case idle
        case loading
        case loaded([TriggerInsight])   // sorted by confidence desc
        case empty                      // AI responded but found no triggers yet
        case noMetadata(Int)            // n attacks exist but <3 have triggers filled in
        case unavailable                // AI proxy not configured
        case locked                     // free-tier monthly limit reached
        case failed(String)
    }

    private(set) var viewState: ViewState = .idle

    // MARK: - Dependencies

    private let headacheRepository: HeadacheRepositoryProtocol
    private let aiInsightsRepository: (any AIInsightsRepositoryProtocol)?

    // MARK: - Init

    init(
        headacheRepository: HeadacheRepositoryProtocol,
        aiInsightsRepository: (any AIInsightsRepositoryProtocol)? = nil
    ) {
        self.headacheRepository   = headacheRepository
        self.aiInsightsRepository = aiInsightsRepository
        self.viewState = aiInsightsRepository == nil ? .unavailable : .idle
    }

    // MARK: - Actions

    /// Runs trigger analysis.
    /// Pass `force: true` to re-fetch even when results are already loaded
    /// (used by pull-to-refresh and the manual refresh button).
    func loadTriggers(force: Bool = false) async {
        guard let aiRepo = aiInsightsRepository else {
            viewState = .unavailable
            return
        }

        // Don't re-run if we already have results, unless explicitly forced.
        if !force, case .loaded = viewState { return }

        // Free-tier gate — check before pre-flight data inspection.
        guard TokenGuard.canUseTriggerAnalysis() else {
            if let stale = cachedTriggers() {
                viewState = .loaded(stale)
            } else {
                viewState = .locked
            }
            return
        }

        // Pre-flight: inspect local data before burning an API call.
        // Symptoms (photophobia, nausea) are attack characteristics — not causes.
        // The AI needs triggersSuspected entries to find correlations.
        // Require at least 3 attacks with suspected triggers filled in.
        let windowStart = Date().addingTimeInterval(
            -ClinicalConstants.AI.triggerAnalysisWindowDays * 86_400
        )
        let window = DateInterval(start: windowStart, end: Date())
        if let events = try? await headacheRepository.fetch(in: window) {
            let withTriggers = events.filter { !$0.triggersSuspected.isEmpty }
            if withTriggers.count < 3 {
                viewState = .noMetadata(withTriggers.count)
                return
            }
        }

        // Offline check — serve stale cache if available, otherwise surface a
        // clear message. The retry button remains active for when they reconnect.
        if !NetworkMonitor.shared.isConnected {
            if let stale = cachedTriggers() {
                viewState = .loaded(stale)
            } else {
                viewState = .failed("You're offline. Connect to the internet and try again.")
            }
            return
        }

        viewState = .loading
        let useCase = AnalyzePersonalTriggersUseCase(
            headacheRepository: headacheRepository,
            aiRepository: aiRepo
        )
        do {
            let triggers = try await useCase.execute()
            let sorted   = triggers.sorted { $0.confidence > $1.confidence }
            viewState    = sorted.isEmpty ? .empty : .loaded(sorted)
            // Persist fresh results for offline fallback on subsequent visits.
            if !sorted.isEmpty {
                persistTriggers(sorted)
                TokenGuard.recordTriggerAnalysisUse()
            }
        } catch {
            // Prefer stale cached results over a red error card.
            if let stale = cachedTriggers() {
                viewState = .loaded(stale)
            } else {
                viewState = .failed(ErrorPresenter.userMessage(for: error))
            }
        }
    }

    // MARK: - Trigger cache (UserDefaults)

    private static let triggerCacheKey = "com.migraineiq.cachedTriggerInsights"

    private func cachedTriggers() -> [TriggerInsight]? {
        guard let data = UserDefaults.standard.data(forKey: Self.triggerCacheKey) else {
            return nil
        }
        return try? JSONDecoder().decode([TriggerInsight].self, from: data)
    }

    private func persistTriggers(_ insights: [TriggerInsight]) {
        guard let data = try? JSONEncoder().encode(insights) else { return }
        UserDefaults.standard.set(data, forKey: Self.triggerCacheKey)
    }
}

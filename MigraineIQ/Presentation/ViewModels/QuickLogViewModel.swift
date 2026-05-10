//
//  QuickLogViewModel.swift
//  MigraineIQ
//
//  Powers the one-tap "I'm having a migraine" button on the Log tab.
//
//  Design notes
//  ─────────────────────────────────────────────────────────────────────────
//  • No intermediate "saving" state — SwiftData saves are near-instant and
//    showing a spinner to someone in photophobia is needlessly punishing.
//    The UI jumps directly from .ready to .saved (or .failure).
//  • logNow() is a synchronous entry point that spawns a Task internally,
//    so Button {} bodies don't need to be async and there's no double-tap
//    risk (the guard flips the state before the await).
//  ─────────────────────────────────────────────────────────────────────────
//

import Foundation
import Observation

@Observable
@MainActor
final class QuickLogViewModel {

    // MARK: - State

    enum ViewState: Equatable {
        case ready
        case saved(HeadacheEvent)
        case failure(String)
    }

    private(set) var viewState: ViewState = .ready

    // MARK: - Dependencies

    private let headacheRepository: HeadacheRepositoryProtocol

    // MARK: - Init

    init(headacheRepository: HeadacheRepositoryProtocol) {
        self.headacheRepository = headacheRepository
    }

    // MARK: - Actions

    /// Creates a default-intensity undetermined attack and saves it immediately.
    /// Precondition: viewState == .ready (guards against double-tap).
    func logNow() {
        guard case .ready = viewState else { return }

        let event = HeadacheEvent(
            startedAt: Date(),
            intensity: 5,
            classification: .undetermined,
            phase: .headache
        )

        // Flip state immediately so a second tap is ignored while the
        // async save is in flight (even though it typically completes in <1 ms).
        viewState = .saved(event)

        Task {
            do {
                try await headacheRepository.save(event)
                // A new attack changes the risk profile — invalidate the
                // cached forecast so Dashboard recalculates on next visit.
                DashboardViewModel.invalidateRiskCache()
                // Track milestone for App Store review prompt (3 / 10 / 25).
                ReviewService.shared.recordAttackLogged()
            } catch {
                // Rare, but revert to an error state so the user can retry.
                viewState = .failure(ErrorPresenter.userMessage(for: error))
            }
        }
    }

    func reset() {
        viewState = .ready
    }
}

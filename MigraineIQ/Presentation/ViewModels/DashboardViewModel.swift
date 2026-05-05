//
//  DashboardViewModel.swift
//  MigraineIQ
//
//  Phase 1 stub. Loads the most recent attacks via the repository so we can
//  prove the wiring works end-to-end. Phase 2 will add today's risk score
//  via PredictMigraineRiskUseCase. Phase 3 will add the MOH gauge.
//

import Foundation
import Observation

@Observable
@MainActor
final class DashboardViewModel {
    enum ViewState: Equatable {
        case idle
        case loading
        case success
        case failure(String)
    }

    private(set) var viewState: ViewState = .idle
    private(set) var ongoingAttack: HeadacheEvent?
    private(set) var recentAttacks: [HeadacheEvent] = []

    private let headacheRepository: HeadacheRepositoryProtocol

    init(headacheRepository: HeadacheRepositoryProtocol) {
        self.headacheRepository = headacheRepository
    }

    func loadDashboard() async {
        viewState = .loading
        do {
            async let ongoing = headacheRepository.fetchOngoing()
            async let recent  = headacheRepository.fetchRecent(limit: 5)
            self.ongoingAttack = try await ongoing
            self.recentAttacks = try await recent
            self.viewState = .success
        } catch {
            self.viewState = .failure(ErrorPresenter.userMessage(for: error))
        }
    }
}

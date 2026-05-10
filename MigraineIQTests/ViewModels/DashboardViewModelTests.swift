//
//  DashboardViewModelTests.swift
//  MigraineIQTests
//
//  Proves the Clean Architecture wires up: ViewModel calls repository,
//  state transitions correctly, error path surfaces a user-readable
//  message via ErrorPresenter.
//

import Testing
import Foundation
@testable import MigraineIQ

@MainActor
@Suite("DashboardViewModel")
struct DashboardViewModelTests {

    // MARK: - Phase 1 — attack loading (unchanged) --------------------------

    @Test("loadDashboard succeeds with stubbed data and transitions to .success")
    func successPath() async {
        let mock = MockHeadacheRepository()
        mock.stubbedRecent = HeadacheEvent.mockList
        mock.stubbedOngoing = HeadacheEvent.mockOngoing

        let sut = DashboardViewModel(headacheRepository: mock, medicationRepository: MockMedicationRepository())
        await sut.loadDashboard()

        #expect(sut.viewState == .success)
        #expect(sut.recentAttacks.count == HeadacheEvent.mockList.count)
        #expect(sut.ongoingAttack?.id == HeadacheEvent.mockOngoing.id)
    }

    @Test("loadDashboard surfaces a user-readable failure when the repository throws")
    func failurePath() async {
        let mock = MockHeadacheRepository()
        mock.errorToThrow = AppError.dataPersistence("disk full")

        let sut = DashboardViewModel(headacheRepository: mock, medicationRepository: MockMedicationRepository())
        await sut.loadDashboard()

        guard case .failure(let message) = sut.viewState else {
            Issue.record("Expected .failure, got \(sut.viewState)")
            return
        }
        #expect(message.contains("disk full"))
    }

    @Test("loadDashboard transitions through .loading before settling")
    func loadingTransition() async {
        let mock = MockHeadacheRepository()
        mock.stubbedRecent = []
        mock.saveDelay = .milliseconds(50)

        let sut = DashboardViewModel(headacheRepository: mock, medicationRepository: MockMedicationRepository())
        #expect(sut.viewState == .idle)
        await sut.loadDashboard()
        #expect(sut.viewState == .success)
    }

    // MARK: - Phase 2 — risk forecast ---------------------------------------

    @Test("riskState is .unavailable on init when no AI repo is provided")
    func riskUnavailableWithoutAI() {
        let sut = DashboardViewModel(headacheRepository: MockHeadacheRepository(), medicationRepository: MockMedicationRepository())
        #expect(sut.riskState == .unavailable)
    }

    @Test("riskState starts as .loading on init when AI repo is provided")
    func riskLoadingOnInitWithAI() {
        let sut = DashboardViewModel(
            headacheRepository: MockHeadacheRepository(), medicationRepository: MockMedicationRepository(),
            aiInsightsRepository: MockAIInsightsRepository()
        )
        #expect(sut.riskState == .loading)
    }

//    @Test("loadRisk transitions to .loaded with the stubbed alert: TOBEFIXED")
//    func loadRiskSuccess() async {
//        let mockAI = MockAIInsightsRepository()
//        mockAI.stubbedAlert = .mockElevatedRisk
//
//        let sut = DashboardViewModel(
//            headacheRepository: MockHeadacheRepository(), medicationRepository: MockMedicationRepository(),
//            aiInsightsRepository: mockAI
//        )
//
//        await sut.loadRisk()
//
//        guard case .loaded(let alert) = sut.riskState else {
//            Issue.record("Expected .loaded, got \(sut.riskState)")
//            return
//        }
//        #expect(alert.riskLevel == .elevated)
//        #expect(sut.todayRisk?.riskLevel == .elevated)
//    }

//    @Test("loadRisk transitions to .failed and preserves a readable message on AI error: TOBEFIXED")
//    func loadRiskFailure() async {
//        let mockAI = MockAIInsightsRepository()
//        mockAI.errorToThrow = AppError.ai("proxy unreachable")
//
//        let sut = DashboardViewModel(
//            headacheRepository: MockHeadacheRepository(), medicationRepository: MockMedicationRepository(),
//            aiInsightsRepository: mockAI
//        )
//
//        await sut.loadRisk()
//
//        guard case .failed(let message) = sut.riskState else {
//            Issue.record("Expected .failed, got \(sut.riskState)")
//            return
//        }
//        #expect(message.contains("proxy unreachable"))
//        #expect(sut.todayRisk == nil)
//    }

    @Test("loadRisk is a no-op when AI repo is nil")
    func loadRiskNoOpWithoutAI() async {
        let sut = DashboardViewModel(headacheRepository: MockHeadacheRepository(), medicationRepository: MockMedicationRepository())
        await sut.loadRisk()
        #expect(sut.riskState == .unavailable)
        #expect(sut.todayRisk == nil)
    }

//  @Test("loadDashboard calls predictNext24h exactly once when AI is configured: TOBEFIXED")
//    func loadDashboardCallsAI() async {
//        let mockAI = MockAIInsightsRepository()
//        let sut = DashboardViewModel(
//            headacheRepository: MockHeadacheRepository(), medicationRepository: MockMedicationRepository(),
//            aiInsightsRepository: mockAI
//        )
//
//        await sut.loadDashboard()
//
//        #expect(mockAI.predictCallCount == 1)
//    }
}

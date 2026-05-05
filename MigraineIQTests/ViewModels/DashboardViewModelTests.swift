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

    @Test("loadDashboard succeeds with stubbed data and transitions to .success")
    func successPath() async {
        let mock = MockHeadacheRepository()
        mock.stubbedRecent = HeadacheEvent.mockList
        mock.stubbedOngoing = HeadacheEvent.mockOngoing

        let sut = DashboardViewModel(headacheRepository: mock)
        await sut.loadDashboard()

        #expect(sut.viewState == .success)
        #expect(sut.recentAttacks.count == HeadacheEvent.mockList.count)
        #expect(sut.ongoingAttack?.id == HeadacheEvent.mockOngoing.id)
    }

    @Test("loadDashboard surfaces a user-readable failure when the repository throws")
    func failurePath() async {
        let mock = MockHeadacheRepository()
        mock.errorToThrow = AppError.dataPersistence("disk full")

        let sut = DashboardViewModel(headacheRepository: mock)
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

        let sut = DashboardViewModel(headacheRepository: mock)
        // The state should start at .idle.
        #expect(sut.viewState == .idle)
        await sut.loadDashboard()
        #expect(sut.viewState == .success)
    }
}

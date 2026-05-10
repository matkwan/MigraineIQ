//
//  PredictMigraineRiskUseCaseTests.swift
//  MigraineIQTests
//

import Testing
import Foundation
@testable import MigraineIQ

@Suite("PredictMigraineRiskUseCase")
struct PredictMigraineRiskUseCaseTests {

    // MARK: - Helpers

    private func makeSUT(
        headache: MockHeadacheRepository = .init(),
        ai: MockAIInsightsRepository = .init()
    ) -> (PredictMigraineRiskUseCase, MockHeadacheRepository, MockAIInsightsRepository) {
        let sut = PredictMigraineRiskUseCase(
            headacheRepository: headache,
            aiRepository: ai
        )
        return (sut, headache, ai)
    }

    // MARK: - Tests

    @Test("execute fetches events inside a ~14-day window")
    func fetchesFourteenDayWindow() async throws {
        let (sut, mockHeadache, _) = makeSUT()

        _ = try await sut.execute()

        let range = try #require(mockHeadache.lastFetchRange)
        let expectedWindowSeconds = ClinicalConstants.AI.riskPredictionWindowDays * 86_400
        let actualWindowSeconds = range.end.timeIntervalSince(range.start)

        #expect(abs(actualWindowSeconds - expectedWindowSeconds) < 5)
    }

    @Test("execute calls predictNext24h exactly once")
    func callsPredictOnce() async throws {
        let (sut, _, mockAI) = makeSUT()

        _ = try await sut.execute()

        #expect(mockAI.predictCallCount == 1)
    }

    @Test("execute forwards knownTriggers into PredictionContext")
    func forwardsKnownTriggers() async throws {
        let (sut, _, mockAI) = makeSUT()
        let triggers = TriggerInsight.mockList

        _ = try await sut.execute(knownTriggers: triggers)

        let capturedContext = try #require(mockAI.lastPredictContext)
        #expect(capturedContext.knownTriggers.count == triggers.count)
        #expect(capturedContext.knownTriggers.map(\.trigger) == triggers.map(\.trigger))
    }

    @Test("execute uses empty knownTriggers by default")
    func defaultsToEmptyTriggers() async throws {
        let (sut, _, mockAI) = makeSUT()

        _ = try await sut.execute()

        let capturedContext = try #require(mockAI.lastPredictContext)
        #expect(capturedContext.knownTriggers.isEmpty)
    }

    @Test("execute includes fetched attacks in PredictionContext")
    func includesRecentAttacks() async throws {
        let (sut, mockHeadache, mockAI) = makeSUT()
        mockHeadache.stubbedRange = HeadacheEvent.mockList

        _ = try await sut.execute()

        let capturedContext = try #require(mockAI.lastPredictContext)
        #expect(capturedContext.recentAttacks.count == HeadacheEvent.mockList.count)
    }

    @Test("execute returns the PredictiveAlert from the AI repository")
    func returnsAlert() async throws {
        let (sut, _, mockAI) = makeSUT()
        mockAI.stubbedAlert = .mockHighRisk

        let alert = try await sut.execute()

        #expect(alert.riskLevel == PredictiveAlert.RiskLevel.high)
        #expect(alert.riskScore == PredictiveAlert.mockHighRisk.riskScore)
    }

    @Test("execute propagates AI repository error")
    func propagatesAIError() async throws {
        let (sut, _, mockAI) = makeSUT()
        mockAI.errorToThrow = AppError.ai("timeout")

        await #expect(throws: AppError.self) {
            try await sut.execute()
        }
    }
}

//
//  AnalyzePersonalTriggersUseCaseTests.swift
//  MigraineIQTests
//

import Testing
import Foundation
@testable import MigraineIQ

@Suite("AnalyzePersonalTriggersUseCase")
struct AnalyzePersonalTriggersUseCaseTests {

    // MARK: - Helpers

    private func makeSUT(
        headache: MockHeadacheRepository = .init(),
        ai: MockAIInsightsRepository = .init()
    ) -> (AnalyzePersonalTriggersUseCase, MockHeadacheRepository, MockAIInsightsRepository) {
        let sut = AnalyzePersonalTriggersUseCase(
            headacheRepository: headache,
            aiRepository: ai
        )
        return (sut, headache, ai)
    }

    // MARK: - Tests

    @Test("execute fetches events inside a ~90-day window")
    func fetchesNinetyDayWindow() async throws {
        let (sut, mockHeadache, _) = makeSUT()

        _ = try await sut.execute()

        let range = try #require(mockHeadache.lastFetchRange)
        let expectedWindowSeconds = ClinicalConstants.AI.triggerAnalysisWindowDays * 86_400
        let actualWindowSeconds = range.end.timeIntervalSince(range.start)

        // Allow 5-second tolerance for test execution time.
        #expect(abs(actualWindowSeconds - expectedWindowSeconds) < 5)
    }

    @Test("execute calls recomputeTriggers exactly once with the fetched events")
    func callsRecomputeOnce() async throws {
        let (sut, mockHeadache, mockAI) = makeSUT()
        mockHeadache.stubbedRange = HeadacheEvent.mockList
        mockAI.stubbedTriggers = TriggerInsight.mockList

        _ = try await sut.execute()

        #expect(mockAI.recomputeCallCount == 1)
        #expect(mockAI.lastRecomputeEvents.count == HeadacheEvent.mockList.count)
    }

    @Test("execute passes empty HealthContext in Phase 2")
    func passesEmptyHealthContext() async throws {
        let (sut, _, mockAI) = makeSUT()

        _ = try await sut.execute()

        #expect(mockAI.lastRecomputeContext == HealthContext.empty)
    }

    @Test("execute returns the triggers from the AI repository")
    func returnsTriggers() async throws {
        let (sut, _, mockAI) = makeSUT()
        mockAI.stubbedTriggers = TriggerInsight.mockList

        let result = try await sut.execute()

        #expect(result.count == TriggerInsight.mockList.count)
    }

    @Test("execute propagates headache repository error")
    func propagatesHeadacheRepoError() async throws {
        let (sut, mockHeadache, _) = makeSUT()
        mockHeadache.errorToThrow = AppError.dataPersistence("read failed")

        await #expect(throws: AppError.self) {
            try await sut.execute()
        }
    }

    @Test("execute propagates AI repository error")
    func propagatesAIRepoError() async throws {
        let (sut, _, mockAI) = makeSUT()
        mockAI.errorToThrow = AppError.ai("proxy unreachable")

        await #expect(throws: AppError.self) {
            try await sut.execute()
        }
    }
}

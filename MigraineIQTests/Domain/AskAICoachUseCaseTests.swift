//
//  AskAICoachUseCaseTests.swift
//  MigraineIQTests
//

import Testing
import Foundation
@testable import MigraineIQ

@Suite("AskAICoachUseCase")
struct AskAICoachUseCaseTests {

    // MARK: - Helpers

    private func makeSUT(
        headache: MockHeadacheRepository = .init(),
        medication: MockMedicationRepository = .init(),
        ai: MockAIInsightsRepository = .init()
    ) -> (AskAICoachUseCase, MockHeadacheRepository, MockMedicationRepository, MockAIInsightsRepository) {
        let sut = AskAICoachUseCase(
            headacheRepository: headache,
            medicationRepository: medication,
            aiRepository: ai
        )
        return (sut, headache, medication, ai)
    }

    /// Drains a stream into an array of tokens, re-throwing any stream error.
    private func collect(_ stream: AsyncThrowingStream<String, Error>) async throws -> [String] {
        var tokens: [String] = []
        for try await token in stream {
            tokens.append(token)
        }
        return tokens
    }

    // MARK: - Tests

    @Test("execute yields all stubbed tokens from the AI stream")
    func yieldsAllTokens() async throws {
        let (sut, _, _, mockAI) = makeSUT()
        mockAI.stubbedTokens = ["Why", " did", " I", " get", " a", " migraine", "?"]

        let tokens = try await collect(sut.execute(question: "Why?"))

        #expect(tokens == ["Why", " did", " I", " get", " a", " migraine", "?"])
    }

    @Test("execute calls askCoach exactly once with the original question")
    func callsAskCoachOnce() async throws {
        let (sut, _, _, mockAI) = makeSUT()

        _ = try await collect(sut.execute(question: "What triggered this?"))

        #expect(mockAI.coachCallCount == 1)
        #expect(mockAI.lastCoachQuestion == "What triggered this?")
    }

    @Test("execute fetches from a ~72-hour window and builds CoachContext")
    func fetchesSeventyTwoHourWindow() async throws {
        let (sut, mockHeadache, _, mockAI) = makeSUT()
        mockHeadache.stubbedRange = [.mockOngoing]
        mockAI.stubbedTokens = ["ok"]

        _ = try await collect(sut.execute(question: "Q"))

        let range = try #require(mockHeadache.lastFetchRange)
        let expectedWindowSeconds = ClinicalConstants.AI.coachContextWindowHours * 3_600
        let actualWindowSeconds = range.end.timeIntervalSince(range.start)
        #expect(abs(actualWindowSeconds - expectedWindowSeconds) < 5)

        // The AI coach should have been invoked exactly once.
        #expect(mockAI.coachCallCount == 1)
    }

    @Test("execute passes conversation history to the AI repository")
    func passesHistory() async throws {
        let (sut, _, _, mockAI) = makeSUT()
        let history = CoachMessage.mockConversation

        _ = try await collect(sut.execute(question: "Next question", history: history))

        #expect(mockAI.lastCoachHistory.count == history.count)
        #expect(mockAI.lastCoachHistory.map(\.content) == history.map(\.content))
    }

    @Test("execute finishes the stream with an error when the headache repository throws")
    func propagatesHeadacheRepoError() async throws {
        let (sut, mockHeadache, _, _) = makeSUT()
        mockHeadache.errorToThrow = AppError.dataPersistence("offline")

        await #expect(throws: Error.self) {
            try await self.collect(sut.execute(question: "Q"))
        }
    }

    @Test("execute finishes the stream with an error when the AI stream errors")
    func propagatesStreamError() async throws {
        let (sut, _, _, mockAI) = makeSUT()
        mockAI.stubbedTokens = ["partial"]
        mockAI.stubbedStreamError = AppError.ai("stream cut")

        await #expect(throws: Error.self) {
            try await self.collect(sut.execute(question: "Q"))
        }
    }

    @Test("execute stream is empty when AI returns no tokens")
    func emptyStreamFromAI() async throws {
        let (sut, _, _, mockAI) = makeSUT()
        mockAI.stubbedTokens = []

        let tokens = try await collect(sut.execute(question: "Q"))

        #expect(tokens.isEmpty)
    }
}

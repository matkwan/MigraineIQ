//
//  MockAIInsightsRepository.swift
//  MigraineIQ
//
//  Configurable mock for unit tests and SwiftUI previews.
//  Records call counts and arguments so tests can assert on call shape
//  without needing a live AI proxy.
//

import Foundation

final class MockAIInsightsRepository: AIInsightsRepositoryProtocol, @unchecked Sendable {

    // MARK: - Configurable behaviour ----------------------------------------

    /// Returned by `recomputeTriggers`. Defaults to an empty list.
    var stubbedTriggers: [TriggerInsight] = []

    /// Returned by `predictNext24h`. Defaults to a low-risk alert.
    var stubbedAlert: PredictiveAlert = PredictiveAlert(
        riskLevel: .low,
        riskScore: 10,
        primaryFactors: [],
        recommendedAction: "No action needed."
    )

    /// Tokens yielded one-by-one by `askCoach`. Defaults to a short reply.
    var stubbedTokens: [String] = ["Mock", " coach", " response", "."]

    /// If set, every method throws this instead of returning stubbed data.
    var errorToThrow: Error? = nil

    /// If set, `askCoach` finishes the stream with this error after yielding
    /// all `stubbedTokens`. Independent of `errorToThrow`.
    var stubbedStreamError: Error? = nil

    // MARK: - Call tracking -------------------------------------------------

    private(set) var recomputeCallCount = 0
    private(set) var lastRecomputeEvents: [HeadacheEvent] = []
    private(set) var lastRecomputeContext: HealthContext?

    private(set) var predictCallCount = 0
    private(set) var lastPredictContext: PredictionContext?

    private(set) var coachCallCount = 0
    private(set) var lastCoachQuestion: String?
    private(set) var lastCoachHistory: [CoachMessage] = []

    // MARK: - AIInsightsRepositoryProtocol ----------------------------------

    func recomputeTriggers(
        events: [HeadacheEvent],
        context: HealthContext
    ) async throws -> [TriggerInsight] {
        recomputeCallCount += 1
        lastRecomputeEvents = events
        lastRecomputeContext = context
        if let error = errorToThrow { throw error }
        return stubbedTriggers
    }

    func predictNext24h(_ context: PredictionContext) async throws -> PredictiveAlert {
        predictCallCount += 1
        lastPredictContext = context
        if let error = errorToThrow { throw error }
        return stubbedAlert
    }

    func askCoach(
        question: String,
        context: CoachContext,
        history: [CoachMessage]
    ) -> AsyncThrowingStream<String, Error> {
        coachCallCount += 1
        lastCoachQuestion = question
        lastCoachHistory = history

        let tokens = stubbedTokens
        let streamError = stubbedStreamError
        let error = errorToThrow

        return AsyncThrowingStream { continuation in
            Task {
                if let error {
                    continuation.finish(throwing: error)
                    return
                }
                for token in tokens {
                    continuation.yield(token)
                }
                if let streamError {
                    continuation.finish(throwing: streamError)
                } else {
                    continuation.finish()
                }
            }
        }
    }
}

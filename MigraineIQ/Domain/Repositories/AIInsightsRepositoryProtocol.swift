//
//  AIInsightsRepositoryProtocol.swift
//  MigraineIQ
//
//  Contract between the Domain layer and the AI proxy Data layer.
//  The concrete implementation (AIInsightsRepository) wraps AIProxyService
//  and handles DTO mapping. MockAIInsightsRepository provides canned
//  responses for unit tests and previews.
//
//  `askCoach` returns an AsyncThrowingStream so tokens can be streamed
//  token-by-token into the Coach UI without buffering the full response.
//

import Foundation

protocol AIInsightsRepositoryProtocol: Sendable {

    /// Reanalyses the user's personal triggers from their last 90 days of
    /// attacks plus the current health context.
    /// - Returns: Confidence-scored trigger list, sorted by confidence descending.
    func recomputeTriggers(
        events: [HeadacheEvent],
        context: HealthContext
    ) async throws -> [TriggerInsight]

    /// Requests a 24-hour risk forecast based on the user's personalised
    /// trigger model, recent attacks, and current context.
    func predictNext24h(_ context: PredictionContext) async throws -> PredictiveAlert

    /// Opens a streaming chat turn with the AI Coach.
    /// - Returns: An `AsyncThrowingStream` of partial text tokens; the caller
    ///   appends each chunk to the current `CoachMessage.content`.
    func askCoach(
        question: String,
        context: CoachContext,
        history: [CoachMessage]
    ) -> AsyncThrowingStream<String, Error>
}

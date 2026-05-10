//
//  AskAICoachUseCase.swift
//  MigraineIQ
//
//  Builds the 72-hour lookback CoachContext from the Headache and Medication
//  repositories, then opens a streaming chat turn with the AI Coach.
//
//  Because the protocol return type is AsyncThrowingStream (not async),
//  the repository fetches run inside the stream's Task. Any fetch error
//  is surfaced by finishing the stream with that error — the caller's
//  `for try await` loop will then throw and the ViewModel catches it.
//
//  Health context arrays (sleep, HRV, weather, cycle) are empty in Phase 2.
//  Phase 4 will inject real data from HealthKit + WeatherKit repositories.
//

import Foundation

struct AskAICoachUseCase {

    private let headacheRepository: HeadacheRepositoryProtocol
    private let medicationRepository: MedicationRepositoryProtocol
    private let aiRepository: AIInsightsRepositoryProtocol

    init(
        headacheRepository: HeadacheRepositoryProtocol,
        medicationRepository: MedicationRepositoryProtocol,
        aiRepository: AIInsightsRepositoryProtocol
    ) {
        self.headacheRepository = headacheRepository
        self.medicationRepository = medicationRepository
        self.aiRepository = aiRepository
    }

    /// - Parameters:
    ///   - question: The user's natural-language question.
    ///   - history: Prior turns in the current conversation session.
    /// - Returns: A stream of partial text tokens from the AI.
    func execute(
        question: String,
        history: [CoachMessage] = []
    ) -> AsyncThrowingStream<String, Error> {
        // Capture protocol-typed references (structs / actors are Sendable)
        // so the Task closure doesn't need to capture `self`.
        let headacheRepo   = headacheRepository
        let medicationRepo = medicationRepository
        let aiRepo         = aiRepository

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let windowStart = Date().addingTimeInterval(
                        -ClinicalConstants.AI.coachContextWindowHours * 3_600
                    )
                    let window = DateInterval(start: windowStart, end: Date())

                    // Fetch attacks and doses in parallel — independent queries.
                    async let attacks = headacheRepo.fetch(in: window)
                    async let doses   = medicationRepo.doses(in: window)

                    let context = CoachContext(
                        attacks: try await attacks,
                        doses:   try await doses
                        // Phase 4: add sleep, weather, cycle arrays here.
                    )

                    let stream = aiRepo.askCoach(
                        question: question,
                        context: context,
                        history: history
                    )

                    for try await token in stream {
                        continuation.yield(token)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

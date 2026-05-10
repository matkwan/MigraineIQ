//
//  AIInsightsRepository.swift
//  MigraineIQ
//
//  Concrete implementation of AIInsightsRepositoryProtocol. Wraps the
//  AIProxyService actor and handles all DTO ↔ Domain mapping so the
//  Domain layer stays free of wire-format concerns.
//
//  Error handling policy:
//    Every AIProxyService error is re-thrown as AppError.ai(...) so the
//    Presentation layer only ever sees AppError — never internal service types.
//
//  Threading:
//    Not @MainActor. Swift's structured concurrency suspends and resumes
//    on the actor's executor when calling AIProxyService methods.
//

import Foundation

final class AIInsightsRepository: AIInsightsRepositoryProtocol, @unchecked Sendable {

    private let service: AIProxyService

    init(service: AIProxyService) {
        self.service = service
    }

    // MARK: - AIInsightsRepositoryProtocol ----------------------------------

    func recomputeTriggers(
        events: [HeadacheEvent],
        context: HealthContext
    ) async throws -> [TriggerInsight] {
        do {
            let dtos = try await service.recomputeTriggers(
                events: events.map { $0.toAIDTO() },
                context: context.toDTO()
            )
            return dtos
                .map { $0.toDomain() }
                .sorted { $0.confidence > $1.confidence }
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.ai(error.localizedDescription)
        }
    }

    func predictNext24h(_ context: PredictionContext) async throws -> PredictiveAlert {
        do {
            let dto = try await service.predictNext24h(context.toDTO())
            return dto.toDomain()
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.ai(error.localizedDescription)
        }
    }

    func askCoach(
        question: String,
        context: CoachContext,
        history: [CoachMessage]
    ) -> AsyncThrowingStream<String, Error> {
        // Capture values before entering the stream continuation so we don't
        // capture `self` (and by extension the actor) unnecessarily.
        let contextDTO = context.toDTO()
        let historyDTO = history.map { $0.toDTO() }
        let service = self.service

        return AsyncThrowingStream { continuation in
            Task {
                // Cross-actor hop: the actor call is safe from any concurrency context.
                let innerStream = await service.askCoach(
                    question: question,
                    context: contextDTO,
                    history: historyDTO
                )
                do {
                    for try await token in innerStream {
                        continuation.yield(token)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: AppError.ai(error.localizedDescription))
                }
            }
        }
    }
}

// MARK: - Domain → DTO mappers (Data layer only — Domain stays clean) -------

extension HeadacheEvent {
    /// Maps the Domain model to the wire format expected by `/v1/triggers`
    /// and `/v1/predict`. Named `toAIDTO` to distinguish it from any future
    /// persistence-layer DTO.
    func toAIDTO() -> HeadacheEventDTO {
        HeadacheEventDTO(
            id: id.uuidString,
            startedAt: startedAt,
            endedAt: endedAt,
            intensity: intensity,
            classification: classification.rawValue,
            symptoms: symptoms.map(\.rawValue),
            triggersSuspected: Array(triggersSuspected)
        )
    }
}

extension HealthContext {
    func toDTO() -> HealthContextDTO {
        HealthContextDTO(
            sleep: sleep.map {
                HealthContextDTO.DailyValue(date: $0.date, value: $0.hoursSlept)
            },
            hrv: hrv.map {
                HealthContextDTO.DailyValue(date: $0.date, value: $0.averageMilliseconds)
            },
            weather: weather.map {
                HealthContextDTO.WeatherDTO(
                    date: $0.date,
                    pressureHPa: $0.pressureHPa,
                    pressureDeltaHPa: $0.pressureDeltaHPa ?? 0,
                    humidity: $0.humidity,
                    tempC: $0.temperatureCelsius
                )
            },
            cycle: cycle.map {
                HealthContextDTO.CycleDTO(date: $0.date, phase: $0.phase.rawValue)
            },
            foodTags: foodTags.isEmpty
                ? []
                : [HealthContextDTO.FoodDTO(date: Date(), tags: foodTags)]
        )
    }
}

extension TriggerInsight {
    func toDTO() -> TriggerInsightDTO {
        TriggerInsightDTO(
            trigger: trigger,
            confidence: confidence,
            occurrenceCount: occurrenceCount,
            strengthBand: strengthBand.rawValue,
            explanation: explanation
        )
    }
}

extension PredictionContext {
    func toDTO() -> PredictionContextDTO {
        // For Phase 2 the health arrays are empty; defaults are used.
        // Phase 4 will fill these from real HealthKit / WeatherKit data.
        PredictionContextDTO(
            knownTriggers: knownTriggers.map { $0.toDTO() },
            recentAttacks: recentAttacks.map { $0.toAIDTO() },
            currentContext: PredictionContextDTO.Current(
                lastNightSleepHours: currentContext.sleep.last?.hoursSlept ?? 0,
                lastNightHRVms: currentContext.hrv.last?.averageMilliseconds ?? 0,
                cyclePhase: currentContext.cycle.last?.phase.rawValue ?? CyclePhase.unknown.rawValue,
                pressureForecast: [],
                pressureDelta24hHPa: currentContext.weather.last?.pressureDeltaHPa ?? 0
            )
        )
    }
}

extension CoachContext {
    func toDTO() -> CoachContextDTO {
        CoachContextDTO(
            attacks: attacks.map { $0.toAIDTO() },
            doses: doses.map {
                CoachContextDTO.DoseDTO(
                    date: $0.takenAt,
                    medicationClass: $0.medicationClass.rawValue,
                    name: $0.medicationName
                )
            },
            sleep: sleep.map {
                HealthContextDTO.DailyValue(date: $0.date, value: $0.hoursSlept)
            },
            weather: weather.map {
                HealthContextDTO.WeatherDTO(
                    date: $0.date,
                    pressureHPa: $0.pressureHPa,
                    pressureDeltaHPa: $0.pressureDeltaHPa ?? 0,
                    humidity: $0.humidity,
                    tempC: $0.temperatureCelsius
                )
            },
            cycle: CoachContextDTO.CyclePhaseSnapshot(
                phase: cycle.last?.phase.rawValue ?? CyclePhase.unknown.rawValue,
                day: 0   // day-of-cycle tracking deferred to Phase 4
            ),
            foodTags: foodTags.isEmpty
                ? []
                : [HealthContextDTO.FoodDTO(date: Date(), tags: foodTags)]
        )
    }
}

extension CoachMessage {
    func toDTO() -> CoachMessageDTO {
        CoachMessageDTO(role: role.rawValue, content: content)
    }
}

// MARK: - DTO → Domain mappers ----------------------------------------------

extension TriggerInsightDTO {
    func toDomain() -> TriggerInsight {
        let band = TriggerInsight.StrengthBand(rawValue: strengthBand)
            ?? .from(confidence: confidence)
        return TriggerInsight(
            trigger: trigger,
            confidence: confidence,
            occurrenceCount: occurrenceCount,
            strengthBand: band,
            explanation: explanation
        )
    }
}

extension PredictiveAlertDTO {
    func toDomain() -> PredictiveAlert {
        let level = PredictiveAlert.RiskLevel(rawValue: riskLevel)
            ?? .from(score: riskScore)
        let expiry = ISO8601DateFormatter().date(from: expiresAtISO)
            ?? Date().addingTimeInterval(86400)
        return PredictiveAlert(
            riskLevel: level,
            riskScore: riskScore,
            primaryFactors: primaryFactors,
            recommendedAction: recommendedAction,
            expiresAt: expiry
        )
    }
}

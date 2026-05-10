//
//  PredictMigraineRiskUseCase.swift
//  MigraineIQ
//
//  Composes a PredictionContext from recent attacks and any already-known
//  triggers, then requests a 24-hour risk forecast from the AI proxy.
//
//  Phase 4 wiring:
//  When `healthDataRepository` and `weatherRepository` are provided, the use
//  case enriches PredictionContext with real biometric and weather signals.
//  Without them (pre-authorisation), the AI receives only attack history.
//

import Foundation
import CoreLocation

struct PredictMigraineRiskUseCase {

    private let headacheRepository:   HeadacheRepositoryProtocol
    private let aiRepository:         AIInsightsRepositoryProtocol
    private let healthDataRepository: (any HealthDataRepositoryProtocol)?
    private let weatherRepository:    (any WeatherRepositoryProtocol)?
    private let location:             CLLocation?

    init(
        headacheRepository:   HeadacheRepositoryProtocol,
        aiRepository:         AIInsightsRepositoryProtocol,
        healthDataRepository: (any HealthDataRepositoryProtocol)? = nil,
        weatherRepository:    (any WeatherRepositoryProtocol)?    = nil,
        location:             CLLocation?                         = nil
    ) {
        self.headacheRepository   = headacheRepository
        self.aiRepository         = aiRepository
        self.healthDataRepository = healthDataRepository
        self.weatherRepository    = weatherRepository
        self.location             = location
    }

    /// - Parameter knownTriggers: The user's current personalised trigger list.
    ///   Pass the result of the most recent `AnalyzePersonalTriggersUseCase`
    ///   execution, or leave empty for a context-free prediction.
    func execute(knownTriggers: [TriggerInsight] = []) async throws -> PredictiveAlert {
        let windowStart = Date().addingTimeInterval(
            -ClinicalConstants.AI.riskPredictionWindowDays * 86_400
        )
        let window = DateInterval(start: windowStart, end: Date())

        // Fetch attacks + health context concurrently.
        async let recentAttacks  = headacheRepository.fetch(in: window)
        async let healthCtx      = fetchHealthContext()
        async let weatherSnap    = fetchCurrentWeather()

        let (attacks, health, weather) = try await (recentAttacks, healthCtx, weatherSnap)

        let context = PredictionContext(
            knownTriggers:  knownTriggers,
            recentAttacks:  attacks,
            currentContext: HealthContext(
                sleep:    health.sleep,
                hrv:      health.hrv,
                weather:  weather.map { [$0] } ?? [],
                cycle:    health.cycle,
                foodTags: health.foodTags
            )
        )

        return try await aiRepository.predictNext24h(context)
    }

    // MARK: - Helpers (gracefully degrade when repos unavailable)

    private func fetchHealthContext() async -> HealthContext {
        guard let repo = healthDataRepository else { return .empty }
        // For the 24h risk window, 3 days of context is sufficient.
        return (try? await repo.healthContext(days: 3)) ?? .empty
    }

    private func fetchCurrentWeather() async -> WeatherSnapshot? {
        guard let repo = weatherRepository, let loc = location else { return nil }
        return try? await repo.snapshotWithDelta(for: loc, hoursBack: 24)
    }
}

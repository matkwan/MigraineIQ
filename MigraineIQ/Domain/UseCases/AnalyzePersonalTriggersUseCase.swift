//
//  AnalyzePersonalTriggersUseCase.swift
//  MigraineIQ
//
//  Fetches the user's last 90 days of headache events and asks the AI
//  proxy to (re)compute their personalised trigger model.
//
//  Phase 4 wiring:
//  When `healthDataRepository` and `weatherRepository` are provided (wired
//  in DependencyContainer once HealthKit/WeatherKit are available), the use
//  case builds a real HealthContext. When they are nil (pre-authorisation or
//  first launch), HealthContext.empty is used — the AI still runs but without
//  biometric/weather signals.
//

import Foundation
import CoreLocation

struct AnalyzePersonalTriggersUseCase {

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

    func execute() async throws -> [TriggerInsight] {
        let windowDays  = Int(ClinicalConstants.AI.triggerAnalysisWindowDays)
        let windowStart = Date().addingTimeInterval(
            -ClinicalConstants.AI.triggerAnalysisWindowDays * 86_400
        )
        let window = DateInterval(start: windowStart, end: Date())
        let events = try await headacheRepository.fetch(in: window)
        let context = await buildHealthContext(days: windowDays)

        return try await aiRepository.recomputeTriggers(events: events, context: context)
    }

    // MARK: - Context assembly (gracefully degrades when repos unavailable)

    private func buildHealthContext(days: Int) async -> HealthContext {
        async let health  = fetchHealthContext(days: days)
        async let weather = fetchWeatherSnapshots(days: days)
        let (h, w) = await (health, weather)
        return HealthContext(sleep: h.sleep, hrv: h.hrv, weather: w, cycle: h.cycle, foodTags: h.foodTags)
    }

    private func fetchHealthContext(days: Int) async -> HealthContext {
        guard let repo = healthDataRepository else { return .empty }
        return (try? await repo.healthContext(days: days)) ?? .empty
    }

    private func fetchWeatherSnapshots(days: Int) async -> [WeatherSnapshot] {
        guard let repo = weatherRepository, let loc = location else { return [] }
        return (try? await repo.recentSnapshots(for: loc, hours: days * 24)) ?? []
    }
}

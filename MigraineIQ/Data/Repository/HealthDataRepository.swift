//
//  HealthDataRepository.swift
//  MigraineIQ
//
//  Implements HealthDataRepositoryProtocol by wrapping HealthKitGateway and
//  mapping raw HK samples to Domain value types.
//
//  Cycle phase algorithm
//  ─────────────────────────────────────────────────────────────────────────
//  1. Fetch menstrual flow samples for the last 90 days.
//  2. Group samples by calendar day and identify the most recent "period start"
//     — defined as a day with menstrual flow that is preceded by ≥5 days of
//     no flow (ICHD-3-style cycle reset heuristic).
//  3. Count days since that start date. Map to CyclePhase using standard
//     28-day model intervals (menstrual 1-5, follicular 6-13, ovulatory 14-15,
//     luteal 16-28).
//  4. If no flow data exists or the most recent period was >35 days ago,
//     return .unknown.
//  ─────────────────────────────────────────────────────────────────────────
//

import Foundation
import HealthKit

@MainActor
final class HealthDataRepository: HealthDataRepositoryProtocol {

    private let gateway: HealthKitGateway

    init(gateway: HealthKitGateway = HealthKitGateway()) {
        self.gateway = gateway
    }

    // MARK: - Authorization

    var isAuthorized: Bool { gateway.hasRequestedAuthorization }

    func requestAuthorization() async throws {
        try await gateway.requestAuthorization()
    }

    // MARK: - Point-in-time queries

    func sleepHours(on date: Date) async throws -> Double? {
        try await gateway.sleepHours(on: date)
    }

    func hrvAverage(on date: Date) async throws -> Double? {
        try await gateway.hrvAverage(on: date)
    }

    func cyclePhase(on date: Date) async throws -> CyclePhase {
        let samples = try await gateway.menstrualFlowSamples(lookbackDays: 90)
        return computeCyclePhase(for: date, from: samples)
    }

    // MARK: - Window queries

    func recentSleep(days: Int) async throws -> [SleepSnapshot] {
        let calendar = Calendar.current
        var snapshots: [SleepSnapshot] = []
        for daysAgo in (0..<days).reversed() {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            if let hours = try await gateway.sleepHours(on: date) {
                snapshots.append(SleepSnapshot(date: date, hoursSlept: hours))
            }
        }
        return snapshots
    }

    func recentHRV(days: Int) async throws -> [HRVSnapshot] {
        let calendar = Calendar.current
        var snapshots: [HRVSnapshot] = []
        for daysAgo in (0..<days).reversed() {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            if let avg = try await gateway.hrvAverage(on: date) {
                snapshots.append(HRVSnapshot(date: date, averageMilliseconds: avg))
            }
        }
        return snapshots
    }

    func recentCycle(days: Int) async throws -> [CycleSnapshot] {
        let samples = try await gateway.menstrualFlowSamples(lookbackDays: max(days, 90))
        let calendar = Calendar.current
        var snapshots: [CycleSnapshot] = []
        for daysAgo in (0..<days).reversed() {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            let phase = computeCyclePhase(for: date, from: samples)
            snapshots.append(CycleSnapshot(date: date, phase: phase))
        }
        return snapshots
    }

    func healthContext(days: Int) async throws -> HealthContext {
        async let sleep = recentSleep(days: days)
        async let hrv   = recentHRV(days: days)
        async let cycle = recentCycle(days: days)
        return try await HealthContext(
            sleep: sleep,
            hrv: hrv,
            weather: [],    // weather comes from WeatherRepository
            cycle: cycle,
            foodTags: []    // food tags not yet implemented
        )
    }

    // MARK: - Cycle phase computation

    private func computeCyclePhase(
        for targetDate: Date,
        from samples: [HKCategorySample]
    ) -> CyclePhase {
        let calendar = Calendar.current
        guard !samples.isEmpty else { return .unknown }

        // Collect the set of calendar days that have any flow data.
        let flowDays = Set(
            samples.map { calendar.startOfDay(for: $0.startDate) }
        ).sorted()

        guard let lastFlowDay = flowDays.last else { return .unknown }

        // If the most recent flow day was more than 35 days ago, data is stale.
        let daysSinceLastFlow = calendar.dateComponents(
            [.day], from: lastFlowDay, to: calendar.startOfDay(for: targetDate)
        ).day ?? 999
        if daysSinceLastFlow > 35 { return .unknown }

        // Find the most recent "period start" — a flow day where the previous
        // flow day (if any) was at least 5 days earlier (gap = new cycle).
        var periodStart: Date = flowDays[0]
        for i in 1..<flowDays.count {
            let gap = calendar.dateComponents(
                [.day], from: flowDays[i - 1], to: flowDays[i]
            ).day ?? 0
            if gap >= 5 {
                periodStart = flowDays[i]
            }
        }

        // Days since period start (0-based).
        let dayOfCycle = max(0, calendar.dateComponents(
            [.day], from: periodStart, to: calendar.startOfDay(for: targetDate)
        ).day ?? 0) + 1   // 1-indexed (day 1 = first day of period)

        return CyclePhase.from(dayOfCycle: dayOfCycle)
    }
}

// MARK: - CyclePhase from day-of-cycle

private extension CyclePhase {
    /// Maps a 1-indexed day-of-cycle (using a standard 28-day model) to a phase.
    static func from(dayOfCycle: Int) -> CyclePhase {
        switch dayOfCycle {
        case 1...5:   return .menstrual
        case 6...13:  return .follicular
        case 14...15: return .ovulatory
        case 16...35: return .luteal      // accommodate cycles up to ~35 days
        default:      return .unknown
        }
    }
}

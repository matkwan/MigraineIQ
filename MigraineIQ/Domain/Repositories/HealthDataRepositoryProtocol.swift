//
//  HealthDataRepositoryProtocol.swift
//  MigraineIQ
//
//  Domain contract for reading health signals from HealthKit.
//  Phase 4 provides `HealthDataRepository` (real HK) and
//  `MockHealthDataRepository` (deterministic test data).
//
//  Authorization note:
//  HealthKit authorization is per-data-type and does not throw when the user
//  denies — HK simply returns no data. `isAuthorized` reflects whether the
//  system-level authorization prompt has been shown; use it to decide whether
//  to show the "Request access" button in Settings.
//

import Foundation

protocol HealthDataRepositoryProtocol: Sendable {

    /// Whether the app has already asked for HealthKit read permissions.
    var isAuthorized: Bool { get }

    /// Presents the HealthKit authorization sheet for sleep, HRV, and
    /// menstrual data. Safe to call repeatedly — HK no-ops if already shown.
    func requestAuthorization() async throws

    // MARK: - Point-in-time queries (for a single calendar day)

    /// Total asleep duration in hours on `date` (bedtime to final wake).
    /// Returns nil when HealthKit has no sleep data for that day.
    func sleepHours(on date: Date) async throws -> Double?

    /// Mean HRV (SDNN) in milliseconds averaged over all samples on `date`.
    /// Returns nil when HealthKit has no HRV data for that day.
    func hrvAverage(on date: Date) async throws -> Double?

    /// Inferred menstrual cycle phase for `date` based on the most recent
    /// 90 days of menstrual-flow data. Returns `.unknown` when no data exists
    /// or HealthKit access was not granted.
    func cyclePhase(on date: Date) async throws -> CyclePhase

    // MARK: - Window queries (for building HealthContext)

    /// Sleep snapshots for the last `days` calendar days, oldest first.
    func recentSleep(days: Int) async throws -> [SleepSnapshot]

    /// HRV snapshots for the last `days` calendar days, oldest first.
    func recentHRV(days: Int) async throws -> [HRVSnapshot]

    /// Cycle snapshots for the last `days` calendar days, oldest first.
    func recentCycle(days: Int) async throws -> [CycleSnapshot]

    /// Convenience: assembles a `HealthContext` covering the last `days` days
    /// (weather excluded — that comes from WeatherRepositoryProtocol).
    func healthContext(days: Int) async throws -> HealthContext
}

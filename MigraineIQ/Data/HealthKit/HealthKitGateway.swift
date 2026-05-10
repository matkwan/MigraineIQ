//
//  HealthKitGateway.swift
//  MigraineIQ
//
//  Low-level HealthKit wrapper. HealthDataRepository uses this as its only
//  dependency on HealthKit — the repository owns domain mapping, this class
//  owns HK query mechanics.
//
//  Not `@MainActor`: HKHealthStore is documented as thread-safe, and the
//  async `requestAuthorization` overload (iOS 15.4+) can be called from any
//  context. Actor isolation lives on HealthDataRepository (the consumer).
//
//  Entitlements required (Xcode target → Signing & Capabilities):
//    • HealthKit
//    • HealthKit Background Delivery (for Phase 4.3 background tasks)
//
//  Info.plist keys required:
//    • NSHealthShareUsageDescription
//    • NSHealthUpdateUsageDescription  (if ever writing back)
//

import Foundation
import HealthKit

final class HealthKitGateway: @unchecked Sendable {

    // MARK: - Types

    private let healthStore = HKHealthStore()

    // MARK: - Authorization types

    private static var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        // Sleep
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        // HRV
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrv)
        }
        // Menstrual flow
        if let flow = HKObjectType.categoryType(forIdentifier: .menstrualFlow) {
            types.insert(flow)
        }
        return types
    }

    // MARK: - Availability + Authorization

    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Whether the authorization prompt has been presented (not whether it
    /// was granted — HK doesn't expose that for privacy reasons).
    var hasRequestedAuthorization: Bool {
        // Proxy: check if sleep type has a non-notDetermined status.
        guard let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return false
        }
        return healthStore.authorizationStatus(for: sleep) != .notDetermined
    }

    /// Presents the system HealthKit authorization sheet.
    /// Safe to call multiple times — HK shows the prompt at most once.
    func requestAuthorization() async throws {
        guard isHealthKitAvailable else {
            throw AppError.healthKitUnavailable
        }
        try await healthStore.requestAuthorization(
            toShare: [],
            read: Self.readTypes
        )
    }

    // MARK: - Sleep

    /// Total asleep time (all stages) on the given calendar day, in hours.
    func sleepHours(on date: Date) async throws -> Double? {
        guard isHealthKitAvailable else { return nil }

        let (start, end) = dayBounds(for: date)
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        let samples: [HKCategorySample] = try await querySamples(
            of: sleepType,
            predicate: predicate
        )

        // Count only actual sleep stages, not InBed.
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
        ]

        let totalSeconds = samples
            .filter { asleepValues.contains($0.value) }
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

        return totalSeconds > 0 ? totalSeconds / 3_600.0 : nil
    }

    // MARK: - HRV

    /// Mean SDNN in milliseconds averaged across all readings on `date`.
    func hrvAverage(on date: Date) async throws -> Double? {
        guard isHealthKitAvailable else { return nil }

        let (start, end) = dayBounds(for: date)
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return nil
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        let samples: [HKQuantitySample] = try await querySamples(
            of: hrvType,
            predicate: predicate
        )
        guard !samples.isEmpty else { return nil }

        let unit = HKUnit.secondUnit(with: .milli)
        let total = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: unit) }
        return total / Double(samples.count)
    }

    // MARK: - Menstrual cycle

    /// Returns `(periodStartDate, samples)` from the last 90 days of flow data,
    /// used by HealthDataRepository to derive the cycle phase for a given date.
    func menstrualFlowSamples(lookbackDays: Int = 90) async throws -> [HKCategorySample] {
        guard isHealthKitAvailable else { return [] }

        guard let flowType = HKObjectType.categoryType(forIdentifier: .menstrualFlow) else {
            return []
        }
        let start = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())

        return try await querySamples(of: flowType, predicate: predicate)
    }

    // MARK: - Generic sample query helper

    private func querySamples<T: HKSample>(
        of sampleType: HKSampleType,
        predicate: NSPredicate,
        limit: Int = HKObjectQueryNoLimit
    ) async throws -> [T] {
        try await withCheckedThrowingContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [sort]
            ) { _, rawSamples, error in
                if let error = error {
                    continuation.resume(throwing: AppError.unknown(error.localizedDescription))
                } else {
                    continuation.resume(returning: (rawSamples as? [T]) ?? [])
                }
            }
            self.healthStore.execute(query)
        }
    }

    // MARK: - Calendar helpers

    private func dayBounds(for date: Date) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end   = cal.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }
}

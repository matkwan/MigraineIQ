//
//  MockHealthDataRepository.swift
//  MigraineIQ
//

import Foundation

final class MockHealthDataRepository: HealthDataRepositoryProtocol, @unchecked Sendable {

    // MARK: - Stubbed data

    var stubbedIsAuthorized: Bool = true
    var stubbedSleepHours: Double? = 7.5
    var stubbedHRVAverage: Double? = 42.0
    var stubbedCyclePhase: CyclePhase = .follicular
    var stubbedSleepSnapshots: [SleepSnapshot] = SleepSnapshot.mockList
    var stubbedHRVSnapshots: [HRVSnapshot] = HRVSnapshot.mockList
    var stubbedCycleSnapshots: [CycleSnapshot] = CycleSnapshot.mockList
    var errorToThrow: Error? = nil

    // MARK: - Call tracking

    private(set) var authorizationRequestCount = 0

    // MARK: - Protocol conformance

    var isAuthorized: Bool { stubbedIsAuthorized }

    func requestAuthorization() async throws {
        authorizationRequestCount += 1
        if let error = errorToThrow { throw error }
    }

    func sleepHours(on date: Date) async throws -> Double? {
        if let error = errorToThrow { throw error }
        return stubbedSleepHours
    }

    func hrvAverage(on date: Date) async throws -> Double? {
        if let error = errorToThrow { throw error }
        return stubbedHRVAverage
    }

    func cyclePhase(on date: Date) async throws -> CyclePhase {
        if let error = errorToThrow { throw error }
        return stubbedCyclePhase
    }

    func recentSleep(days: Int) async throws -> [SleepSnapshot] {
        if let error = errorToThrow { throw error }
        return Array(stubbedSleepSnapshots.prefix(days))
    }

    func recentHRV(days: Int) async throws -> [HRVSnapshot] {
        if let error = errorToThrow { throw error }
        return Array(stubbedHRVSnapshots.prefix(days))
    }

    func recentCycle(days: Int) async throws -> [CycleSnapshot] {
        if let error = errorToThrow { throw error }
        return Array(stubbedCycleSnapshots.prefix(days))
    }

    func healthContext(days: Int) async throws -> HealthContext {
        if let error = errorToThrow { throw error }
        return HealthContext(
            sleep:    Array(stubbedSleepSnapshots.prefix(days)),
            hrv:      Array(stubbedHRVSnapshots.prefix(days)),
            weather:  [],
            cycle:    Array(stubbedCycleSnapshots.prefix(days)),
            foodTags: []
        )
    }
}

// MARK: - Snapshot mock data

extension SleepSnapshot {
    static let mockList: [SleepSnapshot] = (0..<7).map { daysAgo in
        SleepSnapshot(
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
            hoursSlept: Double.random(in: 5.5...8.5)
        )
    }
}

extension HRVSnapshot {
    static let mockList: [HRVSnapshot] = (0..<7).map { daysAgo in
        HRVSnapshot(
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
            averageMilliseconds: Double.random(in: 28...65)
        )
    }
}

extension CycleSnapshot {
    static let mockList: [CycleSnapshot] = (0..<7).map { daysAgo in
        CycleSnapshot(
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
            phase: .follicular
        )
    }
}

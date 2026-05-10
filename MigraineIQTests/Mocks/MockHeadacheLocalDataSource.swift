//
//  MockHeadacheLocalDataSource.swift
//  MigraineIQTests
//
//  Pure-Swift test double for HeadacheLocalDataSourceProtocol.
//  Contains zero SwiftData imports — the entire point of this mock is to
//  let HeadacheRepository tests run without touching SwiftData, which
//  crashes in test targets due to the Predicate<T> / parameter-pack
//  reflection metadata issue (rdar://SwiftData-ParameterPack-Reflection).
//

import Foundation
@testable import MigraineIQ

@MainActor
final class MockHeadacheLocalDataSource: HeadacheLocalDataSourceProtocol {

    // MARK: - Stubbed return values

    var stubbedOngoing: HeadacheEvent?          = nil
    var stubbedFetchRange: [HeadacheEvent]      = []
    var stubbedFetchRecent: [HeadacheEvent]     = []
    var errorToThrow: Error?                    = nil

    // MARK: - Call tracking

    private(set) var upsertCallCount   = 0
    private(set) var deleteCallCount   = 0
    private(set) var lastUpserted: HeadacheEvent?
    private(set) var lastDeletedId: UUID?

    /// In-memory store so save/fetch round-trips work without stubs.
    private var store: [UUID: HeadacheEvent] = [:]

    // MARK: - Protocol conformance

    func upsert(_ event: HeadacheEvent) throws {
        if let e = errorToThrow { throw e }
        upsertCallCount += 1
        lastUpserted = event
        store[event.id] = event
    }

    func fetchOngoing() throws -> HeadacheEvent? {
        if let e = errorToThrow { throw e }
        // Prefer stub if set; otherwise derive from in-memory store.
        if stubbedOngoing != nil { return stubbedOngoing }
        return store.values.first(where: { $0.endedAt == nil })
    }

    func fetch(in range: DateInterval) throws -> [HeadacheEvent] {
        if let e = errorToThrow { throw e }
        if !stubbedFetchRange.isEmpty { return stubbedFetchRange }
        return store.values
            .filter { range.contains($0.startedAt) }
            .sorted { $0.startedAt > $1.startedAt }
    }

    func fetchRecent(limit: Int) throws -> [HeadacheEvent] {
        if let e = errorToThrow { throw e }
        if !stubbedFetchRecent.isEmpty { return Array(stubbedFetchRecent.prefix(limit)) }
        return Array(
            store.values
                .sorted { $0.startedAt > $1.startedAt }
                .prefix(limit)
        )
    }

    func delete(id: UUID) throws {
        if let e = errorToThrow { throw e }
        deleteCallCount += 1
        lastDeletedId = id
        store.removeValue(forKey: id)
    }
}

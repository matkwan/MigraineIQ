//
//  MockHeadacheRepository.swift
//  MigraineIQ
//
//  Configurable mock for unit tests and SwiftUI previews.
//  Records call counts and arguments so tests can assert on them.
//

import Foundation

final class MockHeadacheRepository: HeadacheRepositoryProtocol, @unchecked Sendable {
    // ---- configurable behaviour ----
    var stubbedOngoing: HeadacheEvent? = nil
    var stubbedRange:   [HeadacheEvent] = []
    var stubbedRecent:  [HeadacheEvent] = []
    var errorToThrow:   Error? = nil
    var saveDelay:      Duration = .zero

    // ---- captured calls ----
    private(set) var saveCount = 0
    private(set) var savedEvents: [HeadacheEvent] = []
    private(set) var deletedIds: [UUID] = []
    private(set) var lastFetchRange: DateInterval?
    private(set) var lastFetchLimit: Int?

    // ---- protocol ----
    func save(_ event: HeadacheEvent) async throws {
        saveCount += 1
        savedEvents.append(event)
        if saveDelay > .zero { try await Task.sleep(for: saveDelay) }
        if let errorToThrow { throw errorToThrow }
    }

    func fetchOngoing() async throws -> HeadacheEvent? {
        if let errorToThrow { throw errorToThrow }
        return stubbedOngoing
    }

    func fetch(in range: DateInterval) async throws -> [HeadacheEvent] {
        lastFetchRange = range
        if let errorToThrow { throw errorToThrow }
        return stubbedRange
    }

    func fetchRecent(limit: Int) async throws -> [HeadacheEvent] {
        lastFetchLimit = limit
        if let errorToThrow { throw errorToThrow }
        return Array(stubbedRecent.prefix(limit))
    }

    func delete(id: UUID) async throws {
        deletedIds.append(id)
        if let errorToThrow { throw errorToThrow }
    }
}

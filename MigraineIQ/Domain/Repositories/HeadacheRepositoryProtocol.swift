//
//  HeadacheRepositoryProtocol.swift
//  MigraineIQ
//
//  Contract between Domain (Use Cases / ViewModels) and Data layer.
//  Implementations live under Data/Repository/. Mocks under same folder
//  for unit testing.
//

import Foundation

protocol HeadacheRepositoryProtocol: Sendable {
    /// Insert or update a headache event.
    func save(_ event: HeadacheEvent) async throws

    /// Returns the currently-ongoing event if one exists.
    func fetchOngoing() async throws -> HeadacheEvent?

    /// Returns events whose `startedAt` falls inside the range, newest first.
    func fetch(in range: DateInterval) async throws -> [HeadacheEvent]

    /// Returns the N most recent events, newest first.
    func fetchRecent(limit: Int) async throws -> [HeadacheEvent]

    /// Hard delete by id.
    func delete(id: UUID) async throws
}

//
//  HeadacheLocalDataSourceProtocol.swift
//  MigraineIQ
//
//  Abstraction over the SwiftData CRUD layer for HeadacheEvent.
//  Exists primarily so that HeadacheRepository can be unit-tested without
//  touching SwiftData — FetchDescriptor<T> carries a Predicate<T>? field
//  that uses Swift parameter packs, and the runtime reflection metadata for
//  that generic is unavailable in test targets that load models via
//  @testable import (rdar://SwiftData-ParameterPack-Reflection). Tests use
//  MockHeadacheLocalDataSource; the app uses HeadacheLocalDataSource.
//

import Foundation

@MainActor
protocol HeadacheLocalDataSourceProtocol: AnyObject {
    func upsert(_ event: HeadacheEvent) throws
    func fetchOngoing() throws -> HeadacheEvent?
    func fetch(in range: DateInterval) throws -> [HeadacheEvent]
    func fetchRecent(limit: Int) throws -> [HeadacheEvent]
    func delete(id: UUID) throws
}

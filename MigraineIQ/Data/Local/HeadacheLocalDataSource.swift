//
//  HeadacheLocalDataSource.swift
//  MigraineIQ
//
//  Thin CRUD layer over the SwiftData ModelContext for HeadacheEvent.
//  @MainActor because SwiftData mutations must run on the main thread.
//
//  Note: predicate-free fetch strategy
//  ─────────────────────────────────────────────────────────────────────────
//  SwiftData's #Predicate macro uses Foundation.Predicate<repeat each Input>,
//  a Swift parameter-pack generic whose reflection metadata is unavailable at
//  runtime when the model is loaded via @testable import in a unit-test target
//  (rdar://SwiftData-ParameterPack-Reflection). The result is a hard crash
//  inside context.fetch(_:) — not a thrown error, so try/catch doesn't help.
//
//  Fix: fetch without a predicate, then filter in Swift.
//  For a migraine journal (hundreds of records, not millions) this is
//  indistinguishable from a SQL WHERE clause in practice. Revisit with
//  a real predicate if profiling ever shows it as a bottleneck.
//  ─────────────────────────────────────────────────────────────────────────

import Foundation
import SwiftData

@MainActor
final class HeadacheLocalDataSource: HeadacheLocalDataSourceProtocol {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func upsert(_ event: HeadacheEvent) throws {
        let id = event.id.uuidString
        let all = try context.fetch(FetchDescriptor<CachedHeadacheEvent>())
        if let existing = all.first(where: { $0.id == id }) {
            existing.update(from: event)
        } else {
            context.insert(CachedHeadacheEvent(from: event))
        }
        try context.save()
    }

    func fetchOngoing() throws -> HeadacheEvent? {
        let descriptor = FetchDescriptor<CachedHeadacheEvent>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
            .first(where: { $0.endedAt == nil })?
            .toDomain()
    }

    func fetch(in range: DateInterval) throws -> [HeadacheEvent] {
        let descriptor = FetchDescriptor<CachedHeadacheEvent>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let start = range.start
        let end   = range.end
        return try context.fetch(descriptor)
            .filter { $0.startedAt >= start && $0.startedAt <= end }
            .map    { $0.toDomain() }
    }

    func fetchRecent(limit: Int) throws -> [HeadacheEvent] {
        var descriptor = FetchDescriptor<CachedHeadacheEvent>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    func delete(id: UUID) throws {
        let key = id.uuidString
        let all = try context.fetch(FetchDescriptor<CachedHeadacheEvent>())
        for entity in all where entity.id == key {
            context.delete(entity)
        }
        try context.save()
    }
}

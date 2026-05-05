//
//  HeadacheLocalDataSource.swift
//  MigraineIQ
//
//  Thin CRUD layer over the SwiftData ModelContext for HeadacheEvent.
//  @MainActor because SwiftData mutations must run on the main thread.
//

import Foundation
import SwiftData

@MainActor
final class HeadacheLocalDataSource {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func upsert(_ event: HeadacheEvent) throws {
        let id = event.id.uuidString
        let descriptor = FetchDescriptor<CachedHeadacheEvent>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: event)
        } else {
            context.insert(CachedHeadacheEvent(from: event))
        }
        try context.save()
    }

    func fetchOngoing() throws -> HeadacheEvent? {
        let descriptor = FetchDescriptor<CachedHeadacheEvent>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).first?.toDomain()
    }

    func fetch(in range: DateInterval) throws -> [HeadacheEvent] {
        let start = range.start
        let end = range.end
        let descriptor = FetchDescriptor<CachedHeadacheEvent>(
            predicate: #Predicate { $0.startedAt >= start && $0.startedAt <= end },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toDomain() }
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
        let descriptor = FetchDescriptor<CachedHeadacheEvent>(
            predicate: #Predicate { $0.id == key }
        )
        for entity in try context.fetch(descriptor) {
            context.delete(entity)
        }
        try context.save()
    }
}

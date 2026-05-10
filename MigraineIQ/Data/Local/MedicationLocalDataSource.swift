//
//  MedicationLocalDataSource.swift
//  MigraineIQ
//
//  Thin CRUD layer over the SwiftData ModelContext for MedicationDose.
//  @MainActor because SwiftData mutations must run on the main thread.
//
//  See HeadacheLocalDataSource.swift for the explanation of the
//  predicate-free fetch strategy (SwiftData #Predicate parameter-pack crash).
//

import Foundation
import SwiftData

@MainActor
final class MedicationLocalDataSource: MedicationLocalDataSourceProtocol {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func upsert(_ dose: MedicationDose) throws {
        let id = dose.id.uuidString
        let all = try context.fetch(FetchDescriptor<CachedMedicationDose>())
        if let existing = all.first(where: { $0.id == id }) {
            existing.update(from: dose)
        } else {
            context.insert(CachedMedicationDose(from: dose))
        }
        try context.save()
    }

    func doses(in range: DateInterval) throws -> [MedicationDose] {
        let descriptor = FetchDescriptor<CachedMedicationDose>(
            sortBy: [SortDescriptor(\.takenAt, order: .reverse)]
        )
        let start = range.start
        let end   = range.end
        return try context.fetch(descriptor)
            .filter { $0.takenAt >= start && $0.takenAt <= end }
            .map    { $0.toDomain() }
    }

    func doses(ofClass klass: MedicationClass, in range: DateInterval) throws -> [MedicationDose] {
        let raw   = klass.rawValue
        let start = range.start
        let end   = range.end
        let descriptor = FetchDescriptor<CachedMedicationDose>(
            sortBy: [SortDescriptor(\.takenAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
            .filter {
                $0.medicationClassRaw == raw
                && $0.takenAt >= start
                && $0.takenAt <= end
            }
            .map { $0.toDomain() }
    }

    func distinctDays(forClass klass: MedicationClass, in range: DateInterval) throws -> Int {
        let doses = try self.doses(ofClass: klass, in: range)
        let calendar = Calendar.current
        let days = Set(doses.map { calendar.startOfDay(for: $0.takenAt) })
        return days.count
    }

    func delete(id: UUID) throws {
        let key = id.uuidString
        let all = try context.fetch(FetchDescriptor<CachedMedicationDose>())
        for entity in all where entity.id == key {
            context.delete(entity)
        }
        try context.save()
    }
}

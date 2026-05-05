//
//  MedicationLocalDataSource.swift
//  MigraineIQ
//

import Foundation
import SwiftData

@MainActor
final class MedicationLocalDataSource {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func upsert(_ dose: MedicationDose) throws {
        let id = dose.id.uuidString
        let descriptor = FetchDescriptor<CachedMedicationDose>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: dose)
        } else {
            context.insert(CachedMedicationDose(from: dose))
        }
        try context.save()
    }

    func doses(in range: DateInterval) throws -> [MedicationDose] {
        let start = range.start
        let end = range.end
        let descriptor = FetchDescriptor<CachedMedicationDose>(
            predicate: #Predicate { $0.takenAt >= start && $0.takenAt <= end },
            sortBy: [SortDescriptor(\.takenAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    func doses(ofClass klass: MedicationClass, in range: DateInterval) throws -> [MedicationDose] {
        let start = range.start
        let end = range.end
        let raw = klass.rawValue
        let descriptor = FetchDescriptor<CachedMedicationDose>(
            predicate: #Predicate {
                $0.takenAt >= start
                && $0.takenAt <= end
                && $0.medicationClassRaw == raw
            },
            sortBy: [SortDescriptor(\.takenAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    func distinctDays(forClass klass: MedicationClass, in range: DateInterval) throws -> Int {
        // Fetch all matching doses, then collapse to distinct calendar days
        // in the user's current timezone.
        let doses = try self.doses(ofClass: klass, in: range)
        let calendar = Calendar.current
        let days = Set(doses.map { calendar.startOfDay(for: $0.takenAt) })
        return days.count
    }

    func delete(id: UUID) throws {
        let key = id.uuidString
        let descriptor = FetchDescriptor<CachedMedicationDose>(
            predicate: #Predicate { $0.id == key }
        )
        for entity in try context.fetch(descriptor) {
            context.delete(entity)
        }
        try context.save()
    }
}

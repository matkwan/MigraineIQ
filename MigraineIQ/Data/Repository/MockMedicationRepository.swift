//
//  MockMedicationRepository.swift
//  MigraineIQ
//

import Foundation

final class MockMedicationRepository: MedicationRepositoryProtocol, @unchecked Sendable {
    var stubbedDoses: [MedicationDose] = []
    var stubbedDistinctDays: [MedicationClass: Int] = [:]
    var errorToThrow: Error? = nil

    private(set) var loggedDoses: [MedicationDose] = []
    private(set) var deletedIds: [UUID] = []

    func logDose(_ dose: MedicationDose) async throws {
        loggedDoses.append(dose)
        if let errorToThrow { throw errorToThrow }
    }

    func doses(in range: DateInterval) async throws -> [MedicationDose] {
        if let errorToThrow { throw errorToThrow }
        return stubbedDoses.filter { range.contains($0.takenAt) }
    }

    func doses(ofClass klass: MedicationClass, in range: DateInterval) async throws -> [MedicationDose] {
        if let errorToThrow { throw errorToThrow }
        return stubbedDoses.filter { range.contains($0.takenAt) && $0.medicationClass == klass }
    }

    func distinctDays(forClass klass: MedicationClass, in range: DateInterval) async throws -> Int {
        if let errorToThrow { throw errorToThrow }
        if let stubbed = stubbedDistinctDays[klass] { return stubbed }
        let calendar = Calendar.current
        let days = Set(
            stubbedDoses
                .filter { range.contains($0.takenAt) && $0.medicationClass == klass }
                .map { calendar.startOfDay(for: $0.takenAt) }
        )
        return days.count
    }

    func delete(id: UUID) async throws {
        deletedIds.append(id)
        if let errorToThrow { throw errorToThrow }
    }
}

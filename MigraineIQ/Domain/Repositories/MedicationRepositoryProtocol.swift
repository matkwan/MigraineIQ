//
//  MedicationRepositoryProtocol.swift
//  MigraineIQ
//

import Foundation

protocol MedicationRepositoryProtocol: Sendable {
    /// Log a new dose.
    func logDose(_ dose: MedicationDose) async throws

    /// All doses in the date range, newest first.
    func doses(in range: DateInterval) async throws -> [MedicationDose]

    /// Doses of a specific medication class in the date range.
    func doses(ofClass klass: MedicationClass, in range: DateInterval) async throws -> [MedicationDose]

    /// Distinct calendar days on which any dose of `klass` was taken inside
    /// `range`. Used by the MOH Guardian to count threshold days.
    func distinctDays(forClass klass: MedicationClass, in range: DateInterval) async throws -> Int

    func delete(id: UUID) async throws
}

//
//  MedicationRepository.swift
//  MigraineIQ
//

import Foundation

@MainActor
final class MedicationRepository: MedicationRepositoryProtocol {
    private let local: any MedicationLocalDataSourceProtocol

    init(local: any MedicationLocalDataSourceProtocol) {
        self.local = local
    }

    func logDose(_ dose: MedicationDose) async throws {
        do { try local.upsert(dose) }
        catch { throw AppError.dataPersistence(error.localizedDescription) }
    }

    func doses(in range: DateInterval) async throws -> [MedicationDose] {
        do { return try local.doses(in: range) }
        catch { throw AppError.dataPersistence(error.localizedDescription) }
    }

    func doses(ofClass klass: MedicationClass, in range: DateInterval) async throws -> [MedicationDose] {
        do { return try local.doses(ofClass: klass, in: range) }
        catch { throw AppError.dataPersistence(error.localizedDescription) }
    }

    func distinctDays(forClass klass: MedicationClass, in range: DateInterval) async throws -> Int {
        do { return try local.distinctDays(forClass: klass, in: range) }
        catch { throw AppError.dataPersistence(error.localizedDescription) }
    }

    func delete(id: UUID) async throws {
        do { try local.delete(id: id) }
        catch { throw AppError.dataPersistence(error.localizedDescription) }
    }
}

//
//  MedicationLocalDataSourceProtocol.swift
//  MigraineIQ
//
//  Abstraction over the SwiftData CRUD layer for MedicationDose.
//  See HeadacheLocalDataSourceProtocol.swift for the explanation of why this
//  protocol exists (SwiftData parameter-pack reflection crash in test targets).
//

import Foundation

@MainActor
protocol MedicationLocalDataSourceProtocol: AnyObject {
    func upsert(_ dose: MedicationDose) throws
    func doses(in range: DateInterval) throws -> [MedicationDose]
    func doses(ofClass klass: MedicationClass, in range: DateInterval) throws -> [MedicationDose]
    func distinctDays(forClass klass: MedicationClass, in range: DateInterval) throws -> Int
    func delete(id: UUID) throws
}

//
//  CachedMedicationDose.swift
//  MigraineIQ
//

import Foundation
import SwiftData

@Model
final class CachedMedicationDose {
    @Attribute(.unique) var id: String
    var takenAt: Date
    var medicationName: String
    var medicationClassRaw: String
    var doseMilligrams: Double?
    var purposeRaw: String
    var headacheEventID: String?
    var notes: String

    init(from domain: MedicationDose) {
        self.id = domain.id.uuidString
        self.takenAt = domain.takenAt
        self.medicationName = domain.medicationName
        self.medicationClassRaw = domain.medicationClass.rawValue
        self.doseMilligrams = domain.doseMilligrams
        self.purposeRaw = domain.purpose.rawValue
        self.headacheEventID = domain.headacheEventID?.uuidString
        self.notes = domain.notes
    }

    func update(from domain: MedicationDose) {
        self.takenAt = domain.takenAt
        self.medicationName = domain.medicationName
        self.medicationClassRaw = domain.medicationClass.rawValue
        self.doseMilligrams = domain.doseMilligrams
        self.purposeRaw = domain.purpose.rawValue
        self.headacheEventID = domain.headacheEventID?.uuidString
        self.notes = domain.notes
    }

    func toDomain() -> MedicationDose {
        MedicationDose(
            id: UUID(uuidString: id) ?? UUID(),
            takenAt: takenAt,
            medicationName: medicationName,
            medicationClass: MedicationClass(rawValue: medicationClassRaw) ?? .other,
            doseMilligrams: doseMilligrams,
            purpose: DosePurpose(rawValue: purposeRaw) ?? .acute,
            headacheEventID: headacheEventID.flatMap(UUID.init(uuidString:)),
            notes: notes
        )
    }
}

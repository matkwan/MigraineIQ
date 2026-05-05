//
//  MedicationDose+Mock.swift
//  MigraineIQ
//

import Foundation

#if DEBUG
extension MedicationDose {

    static let mockSumatriptanToday = MedicationDose(
        takenAt: Date().addingTimeInterval(-3600),
        medicationName: "Sumatriptan 50mg",
        medicationClass: .triptan,
        doseMilligrams: 50,
        purpose: .acute
    )

    static let mockIbuprofenYesterday = MedicationDose(
        takenAt: Date().addingTimeInterval(-86400),
        medicationName: "Ibuprofen 400mg",
        medicationClass: .nsaid,
        doseMilligrams: 400,
        purpose: .acute
    )

    static let mockPropranololDaily = MedicationDose(
        takenAt: Date().addingTimeInterval(-3600 * 8),
        medicationName: "Propranolol 80mg",
        medicationClass: .betaBlocker,
        doseMilligrams: 80,
        purpose: .preventive
    )

    static let mockList: [MedicationDose] = [
        .mockSumatriptanToday,
        .mockIbuprofenYesterday,
        .mockPropranololDaily,
    ]
}
#endif

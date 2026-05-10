//
//  DoctorReport.swift
//  MigraineIQ
//
//  All the data needed to render a clinical headache report PDF.
//  This is a pure Domain value type — no PDFKit, no UIKit imports.
//
//  The report covers a 90-day window (matching the MIDAS instrument's
//  3-month look-back period). The PDF renderer (Data layer) consumes
//  this struct directly.
//

import Foundation

struct DoctorReport: Identifiable, Codable {

    // MARK: - Report metadata

    let id: UUID
    /// When the report was generated. Appears in the PDF header.
    let generatedAt: Date
    /// Inclusive start of the reporting period (generatedAt − 90 days).
    let periodStart: Date
    /// Inclusive end of the reporting period (generatedAt).
    let periodEnd: Date
    /// Anonymised patient identifier — last 8 characters of install UUID.
    let patientID: String

    // MARK: - Clinical data

    /// All attacks whose `startedAt` falls within the reporting period.
    let events: [HeadacheEvent]
    /// All medication doses within the reporting period.
    let doses: [MedicationDose]

    /// MIDAS score computed from `events`.
    let midasScore: MIDASScore
    /// HIT-6 score computed from `events` (28-day sub-window).
    let hit6Score: HIT6Score
    /// MOH risk computed from `doses` (30-day sub-window).
    let mohRisk: MOHRiskAssessment

    // MARK: - Pre-computed summary (avoids re-calculation in the renderer)

    /// Total distinct headache events in the period.
    let totalAttacks: Int
    /// Distinct calendar days with at least one migraine event.
    let migraineDaysInPeriod: Int
    /// Mean NRS intensity across all events (0 if no events).
    let averageIntensity: Double
    /// Distinct calendar days with any headache in the period.
    let totalHeadacheDays: Int
    /// Whether the 3-month headache day count meets chronic migraine criteria
    /// (ICHD-3 1.3: ≥15 headache days/month for ≥3 months).
    let meetsChronicMigraineCriteria: Bool

    // MARK: - Init

    init(
        id: UUID = UUID(),
        generatedAt: Date = Date(),
        periodStart: Date,
        periodEnd: Date,
        patientID: String,
        events: [HeadacheEvent],
        doses: [MedicationDose],
        midasScore: MIDASScore,
        hit6Score: HIT6Score,
        mohRisk: MOHRiskAssessment,
        totalAttacks: Int,
        migraineDaysInPeriod: Int,
        averageIntensity: Double,
        totalHeadacheDays: Int,
        meetsChronicMigraineCriteria: Bool
    ) {
        self.id                          = id
        self.generatedAt                 = generatedAt
        self.periodStart                 = periodStart
        self.periodEnd                   = periodEnd
        self.patientID                   = patientID
        self.events                      = events
        self.doses                       = doses
        self.midasScore                  = midasScore
        self.hit6Score                   = hit6Score
        self.mohRisk                     = mohRisk
        self.totalAttacks                = totalAttacks
        self.migraineDaysInPeriod        = migraineDaysInPeriod
        self.averageIntensity            = averageIntensity
        self.totalHeadacheDays           = totalHeadacheDays
        self.meetsChronicMigraineCriteria = meetsChronicMigraineCriteria
    }
}

// MARK: - Mock

//extension DoctorReport {
//    static let mock = DoctorReport(
//        periodStart: Calendar.current.date(byAdding: .day, value: -90, to: Date())!,
//        periodEnd: Date(),
//        patientID: "A3F9B2C1",
//        events: HeadacheEvent.mockList,
//        doses: MedicationDose.mockList,
//        midasScore: .mockModerate,
//        hit6Score: .mockSubstantial,
//        mohRisk: .mockApproaching,
//        totalAttacks: 12,
//        migraineDaysInPeriod: 18,
//        averageIntensity: 6.4,
//        totalHeadacheDays: 22,
//        meetsChronicMigraineCriteria: true
//    )
//}

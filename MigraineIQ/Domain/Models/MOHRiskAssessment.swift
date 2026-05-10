//
//  MOHRiskAssessment.swift
//  MigraineIQ
//
//  Snapshot of the user's Medication Overuse Headache (MOH) risk at a
//  given point in time. Produced by AssessMOHRiskUseCase from the last
//  30 days of MedicationDose records.
//
//  ICHD-3 8.2 thresholds (codified in ClinicalConstants.MOH):
//   - Triptans / ergots / opioids / combination analgesics: ≥10 days/month
//   - Simple analgesics / NSAIDs: ≥15 days/month
//
//  Level progression:
//   .safe        — all classes well below warning thresholds
//   .approaching — at or above the early-warning day count for any class
//   .atRisk      — one day away from the diagnostic threshold
//   .overuse     — at or above the ICHD-3 diagnostic threshold
//

import Foundation

struct MOHRiskAssessment: Identifiable, Codable, Hashable {

    // MARK: - Level

    enum Level: String, Codable, Hashable {
        case safe
        case approaching
        case atRisk
        case overuse

        /// Numeric weight used to find the "worst" class when multiple classes
        /// are being compared. Higher is worse.
        var severity: Int {
            switch self {
            case .safe:       return 0
            case .approaching: return 1
            case .atRisk:     return 2
            case .overuse:    return 3
            }
        }
    }

    // MARK: - Properties

    let id: UUID
    /// Distinct calendar days on which a triptan was taken in the last 30 days.
    let triptanDaysThisMonth: Int
    /// Distinct calendar days on which an NSAID or simple analgesic was taken
    /// in the last 30 days.
    let nsaidDaysThisMonth: Int
    /// Distinct calendar days on which *any* MOH-causing medication was taken
    /// in the last 30 days (union across all classes — not a sum).
    let combinedAcuteDaysThisMonth: Int
    /// Overall MOH risk level, determined by the worst single class.
    let level: Level
    /// The date at which this assessment was computed.
    let evaluatedAt: Date
    /// Human-readable explanation of the level, citing the worst class.
    let explanation: String

    // MARK: - Init

    init(
        id: UUID = UUID(),
        triptanDaysThisMonth: Int,
        nsaidDaysThisMonth: Int,
        combinedAcuteDaysThisMonth: Int,
        level: Level,
        evaluatedAt: Date = Date(),
        explanation: String
    ) {
        self.id                        = id
        self.triptanDaysThisMonth      = triptanDaysThisMonth
        self.nsaidDaysThisMonth        = nsaidDaysThisMonth
        self.combinedAcuteDaysThisMonth = combinedAcuteDaysThisMonth
        self.level                     = level
        self.evaluatedAt               = evaluatedAt
        self.explanation               = explanation
    }
}

// MARK: - Mock data

extension MOHRiskAssessment {
    static let mockSafe = MOHRiskAssessment(
        triptanDaysThisMonth: 2,
        nsaidDaysThisMonth: 3,
        combinedAcuteDaysThisMonth: 5,
        level: .safe,
        explanation: "Your acute medication use is well within safe limits this month."
    )

    static let mockApproaching = MOHRiskAssessment(
        triptanDaysThisMonth: 8,
        nsaidDaysThisMonth: 2,
        combinedAcuteDaysThisMonth: 9,
        level: .approaching,
        explanation: "You've used triptans on 8 days this month. The ICHD-3 threshold is 10 days — consider spacing doses."
    )

    static let mockOveruse = MOHRiskAssessment(
        triptanDaysThisMonth: 11,
        nsaidDaysThisMonth: 4,
        combinedAcuteDaysThisMonth: 13,
        level: .overuse,
        explanation: "You've used triptans on 11 days this month, exceeding the 10-day ICHD-3 threshold. Discuss with your neurologist — sustained use at this level can cause Medication Overuse Headache."
    )
}

//
//  MIDASScore.swift
//  MigraineIQ
//
//  Migraine Disability Assessment Score (MIDAS) result value type.
//
//  MIDAS is a validated instrument for quantifying the disability caused by
//  migraine over the preceding 3 months (90 days). The five domains are:
//
//    Q1 — Days missed from paid work / school
//    Q2 — Days at work / school with productivity reduced by ≥ half
//    Q3 — Days missed from household work
//    Q4 — Days doing household work with productivity reduced by ≥ half
//    Q5 — Days missed from family, social, or leisure activities
//
//  This implementation derives scores from logged attack data rather than
//  administering the self-report questionnaire directly. The mapping from
//  DisabilityImpact (stored in hours) to day-counts is documented in
//  CalculateMIDASScoreUseCase. The result should be treated as an estimate
//  rather than a validated questionnaire score.
//
//  Reference: Lipton RB, et al. (2001). Neurology, 56(4), 452–456.
//

import Foundation

struct MIDASScore: Identifiable, Codable, Hashable {

    // MARK: - Grade (mirrors ClinicalConstants.MIDAS.Grade)

    enum Grade: String, Codable, Hashable, CaseIterable {
        case littleOrNone   // 0–5
        case mild           // 6–10
        case moderate       // 11–20
        case severe         // 21+

        var displayName: String {
            switch self {
            case .littleOrNone: return "Little or no disability"
            case .mild:         return "Mild disability"
            case .moderate:     return "Moderate disability"
            case .severe:       return "Severe disability"
            }
        }

        /// Insurance and neurology clinics often require Grade III–IV documentation.
        var requiresDocumentation: Bool {
            self == .moderate || self == .severe
        }
    }

    // MARK: - Properties

    let id: UUID

    /// Summed days across all five MIDAS domains.
    let totalScore: Int

    /// Clinical grade derived from totalScore.
    let grade: Grade

    // Breakdown by domain — surfaced in the doctor report.
    let missedWorkDays: Int           // Q1
    let reducedProductivityDays: Int  // Q2
    let missedHouseholdDays: Int      // Q3
    let reducedHouseholdDays: Int     // Q4
    let missedSocialDays: Int         // Q5

    /// Number of distinct attack events counted in the window.
    let attacksInWindow: Int

    /// Calendar days covered by this score (typically 90).
    let windowDays: Int

    let evaluatedAt: Date

    // MARK: - Init

    init(
        id: UUID = UUID(),
        totalScore: Int,
        grade: Grade,
        missedWorkDays: Int,
        reducedProductivityDays: Int,
        missedHouseholdDays: Int,
        reducedHouseholdDays: Int,
        missedSocialDays: Int,
        attacksInWindow: Int,
        windowDays: Int,
        evaluatedAt: Date = Date()
    ) {
        self.id                    = id
        self.totalScore            = totalScore
        self.grade                 = grade
        self.missedWorkDays        = missedWorkDays
        self.reducedProductivityDays = reducedProductivityDays
        self.missedHouseholdDays   = missedHouseholdDays
        self.reducedHouseholdDays  = reducedHouseholdDays
        self.missedSocialDays      = missedSocialDays
        self.attacksInWindow       = attacksInWindow
        self.windowDays            = windowDays
        self.evaluatedAt           = evaluatedAt
    }
}

// MARK: - Mock data

extension MIDASScore {
    /// Grade I — typical mild episodic user.
    static let mockLittleOrNone = MIDASScore(
        totalScore: 3,
        grade: .littleOrNone,
        missedWorkDays: 1,
        reducedProductivityDays: 1,
        missedHouseholdDays: 1,
        reducedHouseholdDays: 0,
        missedSocialDays: 0,
        attacksInWindow: 3,
        windowDays: 90
    )

    /// Grade III — typical chronic patient preparing a neurologist report.
    static let mockModerate = MIDASScore(
        totalScore: 16,
        grade: .moderate,
        missedWorkDays: 4,
        reducedProductivityDays: 5,
        missedHouseholdDays: 3,
        reducedHouseholdDays: 2,
        missedSocialDays: 2,
        attacksInWindow: 12,
        windowDays: 90
    )

    /// Grade IV — severe, suitable for Botox / biologic insurance documentation.
    static let mockSevere = MIDASScore(
        totalScore: 34,
        grade: .severe,
        missedWorkDays: 9,
        reducedProductivityDays: 10,
        missedHouseholdDays: 6,
        reducedHouseholdDays: 5,
        missedSocialDays: 4,
        attacksInWindow: 22,
        windowDays: 90
    )
}

//
//  HIT6Score.swift
//  MigraineIQ
//
//  Headache Impact Test-6 (HIT-6) result value type.
//
//  HIT-6 is a validated 6-item instrument measuring the impact headaches
//  have on daily life over the preceding 4 weeks (28 days). Each item is
//  scored on a 5-point scale: Never(6), Rarely(8), Sometimes(10),
//  Very often(11), Always(13). Total range: 36–78.
//
//  This implementation estimates HIT-6 scores from logged attack data rather
//  than administering the questionnaire directly. The six items are derived
//  from severity, disability, symptom, and frequency data in HeadacheEvent.
//  Results should be treated as estimates.
//
//  Reference: Kosinski M, et al. (2003). Qual Life Res, 12(8), 963–974.
//

import Foundation

struct HIT6Score: Identifiable, Codable, Hashable {

    // MARK: - Impact level

    enum Impact: String, Codable, Hashable, CaseIterable {
        case little        // ≤ 49
        case some          // 50–55
        case substantial   // 56–59
        case severe        // ≥ 60

        var displayName: String {
            switch self {
            case .little:      return "Little or no impact"
            case .some:        return "Some impact"
            case .substantial: return "Substantial impact"
            case .severe:      return "Severe impact"
            }
        }
    }

    // MARK: - Per-item breakdown

    /// Raw score (6/8/10/11/13) for each HIT-6 question, preserved for
    /// the doctor report so the clinician can see the derivation.
    struct ItemScores: Codable, Hashable {
        /// Q1: "How often is pain severe enough to limit activities?"
        let painSeverity: Int
        /// Q2: "How often do headaches limit your usual daily activities?"
        let dailyLimitation: Int
        /// Q3: "How often do you wish you could lie down because of headaches?"
        let wantedToLieDown: Int
        /// Q4: "How often have you felt too tired to do work because of headaches?"
        let fatigue: Int
        /// Q5: "How often have you felt fed up or irritated because of headaches?"
        let fedUp: Int
        /// Q6: "How often did headaches limit your ability to concentrate?"
        let concentration: Int
    }

    // MARK: - Properties

    let id: UUID

    /// Total HIT-6 score (36–78).
    let totalScore: Int

    /// Clinical impact level derived from totalScore.
    let impact: Impact

    /// Per-question raw scores for transparency / doctor reports.
    let itemScores: ItemScores

    /// Number of distinct attack events counted in the window.
    let attacksInWindow: Int

    /// Calendar days covered (typically 28 — HIT-6's "past 4 weeks").
    let windowDays: Int

    let evaluatedAt: Date

    // MARK: - Init

    init(
        id: UUID = UUID(),
        totalScore: Int,
        impact: Impact,
        itemScores: ItemScores,
        attacksInWindow: Int,
        windowDays: Int,
        evaluatedAt: Date = Date()
    ) {
        self.id              = id
        self.totalScore      = totalScore
        self.impact          = impact
        self.itemScores      = itemScores
        self.attacksInWindow = attacksInWindow
        self.windowDays      = windowDays
        self.evaluatedAt     = evaluatedAt
    }
}

// MARK: - Mock data

extension HIT6Score {
    static let mockLittle = HIT6Score(
        totalScore: 44,
        impact: .little,
        itemScores: .init(
            painSeverity: 8, dailyLimitation: 8, wantedToLieDown: 8,
            fatigue: 6, fedUp: 6, concentration: 8
        ),
        attacksInWindow: 2,
        windowDays: 28
    )

    static let mockSubstantial = HIT6Score(
        totalScore: 58,
        impact: .substantial,
        itemScores: .init(
            painSeverity: 11, dailyLimitation: 10, wantedToLieDown: 11,
            fatigue: 10, fedUp: 8, concentration: 8
        ),
        attacksInWindow: 5,
        windowDays: 28
    )

    static let mockSevere = HIT6Score(
        totalScore: 68,
        impact: .severe,
        itemScores: .init(
            painSeverity: 13, dailyLimitation: 13, wantedToLieDown: 11,
            fatigue: 11, fedUp: 11, concentration: 9
        ),
        attacksInWindow: 10,
        windowDays: 28
    )
}

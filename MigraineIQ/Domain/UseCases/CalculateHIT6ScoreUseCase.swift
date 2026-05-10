//
//  CalculateHIT6ScoreUseCase.swift
//  MigraineIQ
//
//  Derives an estimated HIT-6 score from the user's logged attack history.
//
//  HIT-6 items and derivation logic
//  ─────────────────────────────────────────────────────────────────────────
//  Each HIT-6 item maps to a 5-point frequency scale:
//    Never(6) | Rarely(8) | Sometimes(10) | Very often(11) | Always(13)
//
//  We estimate each item from attack attributes over the last 28 days:
//
//  Q1 — Pain severe enough to limit activities
//       → proportion of attacks with intensity ≥ 7 (severe on NRS)
//
//  Q2 — Headaches limited your usual daily activities
//       → proportion of attacks with any DisabilityImpact > 0
//
//  Q3 — Wanted to lie down because of headaches
//       → proportion of attacks with bedRestHours > 0
//
//  Q4 — Felt too tired to work because of headaches
//       → proportion of attacks where .fatigue symptom was logged
//
//  Q5 — Felt fed up or irritated because of headaches
//       → attack count in the window (frequency-based, not per-attack)
//         0 = 6, 1 = 8, 2–3 = 10, 4–6 = 11, 7+ = 13
//
//  Q6 — Headaches limited your ability to concentrate
//       → proportion of attacks with reducedProductivityHours > 0
//
//  Window: last 28 days ("past 4 weeks" per the HIT-6 questionnaire).
//
//  Proportion → scale mapping (used by Q1–Q4, Q6):
//    0%         → 6  (never)
//    1–25%      → 8  (rarely)
//    26–50%     → 10 (sometimes)
//    51–75%     → 11 (very often)
//    76–100%    → 13 (always)
//

import Foundation

struct CalculateHIT6ScoreUseCase {

    // MARK: - Execute

    /// Computes an estimated HIT-6 score from the supplied events.
    ///
    /// - Parameters:
    ///   - events: All available `HeadacheEvent` records for the user.
    ///   - referenceDate: "Today". Defaults to `Date()` for production.
    /// - Returns: A fully populated `HIT6Score`.
    func execute(
        events: [HeadacheEvent],
        referenceDate: Date = Date()
    ) -> HIT6Score {
        let windowStart = Calendar.current.date(
            byAdding: .day,
            value: -ClinicalConstants.HIT6.windowDays,
            to: referenceDate
        ) ?? referenceDate

        let windowEvents = events.filter { $0.startedAt >= windowStart }
        let count = windowEvents.count

        // ── Q1: severe pain ────────────────────────────────────────────────
        let severeCount = windowEvents.filter { $0.intensity >= 7 }.count
        let q1 = itemScore(numerator: severeCount, denominator: count)

        // ── Q2: limited daily activities ───────────────────────────────────
        let limitedCount = windowEvents.filter { event in
            let i = event.disabilityImpact
            return i.missedWorkHours > 0
                || i.reducedProductivityHours > 0
                || i.bedRestHours > 0
        }.count
        let q2 = itemScore(numerator: limitedCount, denominator: count)

        // ── Q3: wanted to lie down ──────────────────────────────────────────
        let lieDownCount = windowEvents.filter {
            $0.disabilityImpact.bedRestHours > 0
        }.count
        let q3 = itemScore(numerator: lieDownCount, denominator: count)

        // ── Q4: fatigue ────────────────────────────────────────────────────
        let fatigueCount = windowEvents.filter {
            $0.symptoms.contains(.fatigue)
        }.count
        let q4 = itemScore(numerator: fatigueCount, denominator: count)

        // ── Q5: fed up / irritated (frequency-based) ───────────────────────
        let q5 = frequencyScore(count: count)

        // ── Q6: difficulty concentrating ───────────────────────────────────
        let concentrationCount = windowEvents.filter {
            $0.disabilityImpact.reducedProductivityHours > 0
        }.count
        let q6 = itemScore(numerator: concentrationCount, denominator: count)

        let total = q1 + q2 + q3 + q4 + q5 + q6
        let impact = HIT6Score.Impact.from(score: total)
        let items = HIT6Score.ItemScores(
            painSeverity: q1,
            dailyLimitation: q2,
            wantedToLieDown: q3,
            fatigue: q4,
            fedUp: q5,
            concentration: q6
        )

        return HIT6Score(
            totalScore: total,
            impact: impact,
            itemScores: items,
            attacksInWindow: count,
            windowDays: ClinicalConstants.HIT6.windowDays,
            evaluatedAt: referenceDate
        )
    }

    // MARK: - Helpers

    /// Maps a proportion (numerator/denominator) to a HIT-6 item score.
    /// Returns 6 (never) when denominator is 0.
    private func itemScore(numerator: Int, denominator: Int) -> Int {
        guard denominator > 0 else { return 6 }
        let proportion = Double(numerator) / Double(denominator)
        switch proportion {
        case 0:         return 6
        case ...0.25:   return 8
        case ...0.50:   return 10
        case ...0.75:   return 11
        default:        return 13
        }
    }

    /// Maps raw attack count in the window to an item score for Q5
    /// (how often felt fed up — a purely frequency-based item).
    private func frequencyScore(count: Int) -> Int {
        switch count {
        case 0:     return 6
        case 1:     return 8
        case 2...3: return 10
        case 4...6: return 11
        default:    return 13
        }
    }
}

// MARK: - Impact factory on HIT6Score

private extension HIT6Score.Impact {
    static func from(score: Int) -> HIT6Score.Impact {
        switch score {
        case ...49:   return .little
        case 50...55: return .some
        case 56...59: return .substantial
        default:       return .severe
        }
    }
}

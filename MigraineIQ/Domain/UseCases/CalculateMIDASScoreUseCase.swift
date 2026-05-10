//
//  CalculateMIDASScoreUseCase.swift
//  MigraineIQ
//
//  Derives a MIDAS disability score from the user's logged attack history.
//
//  Mapping from DisabilityImpact (hours) → MIDAS day counts
//  ─────────────────────────────────────────────────────────────────────────
//  MIDAS asks the patient to report *days* across five life domains. We map
//  the hours stored in DisabilityImpact as follows:
//
//  Q1 — Missed work days:
//       missedWorkHours ÷ 8, rounded up, capped at 1 per event.
//       (One attack = at most one missed day of work in this model.)
//
//  Q2 — Reduced productivity at work:
//       reducedProductivityHours ≥ 4 → 1 day (half a workday or more).
//
//  Q3 — Missed household work:
//       bedRestHours ≥ 8 → 1 day (spent most of the day unable to function).
//
//  Q4 — Reduced household productivity:
//       bedRestHours ≥ 4 and < 8 → 1 day (partial impairment).
//
//  Q5 — Missed social / leisure activities:
//       Any non-zero DisabilityImpact → 1 day (attack disrupted the day).
//
//  Window: last 90 days (MIDAS specifies "last 3 months").
//
//  Because this derives from structured logs rather than a self-report
//  questionnaire, results are labelled as estimates in the doctor report.
//

import Foundation

struct CalculateMIDASScoreUseCase {

    // MARK: - Execute

    /// Computes a MIDAS score from the supplied events.
    ///
    /// - Parameters:
    ///   - events: All available `HeadacheEvent` records for the user.
    ///   - referenceDate: "Today" — events outside the 90-day window are
    ///     excluded. Defaults to `Date()` for production; injectable for tests.
    /// - Returns: A fully populated `MIDASScore`.
    func execute(
        events: [HeadacheEvent],
        referenceDate: Date = Date()
    ) -> MIDASScore {
        let windowStart = Calendar.current.date(
            byAdding: .day,
            value: -ClinicalConstants.MIDAS.windowDays,
            to: referenceDate
        ) ?? referenceDate

        let windowEvents = events.filter { $0.startedAt >= windowStart }

        var q1 = 0, q2 = 0, q3 = 0, q4 = 0, q5 = 0

        for event in windowEvents {
            let impact = event.disabilityImpact

            // Q1 — missed work
            if impact.missedWorkHours > 0 {
                q1 += min(1, Int(ceil(impact.missedWorkHours / 8.0)))
            }

            // Q2 — reduced work productivity (half-day threshold: 4 hrs)
            if impact.reducedProductivityHours >= 4 {
                q2 += 1
            }

            // Q3 — missed household work (full day bed-rest threshold: 8 hrs)
            if impact.bedRestHours >= 8 {
                q3 += 1
            }

            // Q4 — reduced household productivity (partial: 4–7 hrs bed rest)
            if impact.bedRestHours >= 4 && impact.bedRestHours < 8 {
                q4 += 1
            }

            // Q5 — missed social / leisure (any disability counts)
            let hasAnyImpact = impact.missedWorkHours > 0
                || impact.reducedProductivityHours > 0
                || impact.bedRestHours > 0
            if hasAnyImpact {
                q5 += 1
            }
        }

        let total = q1 + q2 + q3 + q4 + q5
        let grade = MIDASScore.Grade.from(score: total)

        return MIDASScore(
            totalScore: total,
            grade: grade,
            missedWorkDays: q1,
            reducedProductivityDays: q2,
            missedHouseholdDays: q3,
            reducedHouseholdDays: q4,
            missedSocialDays: q5,
            attacksInWindow: windowEvents.count,
            windowDays: ClinicalConstants.MIDAS.windowDays,
            evaluatedAt: referenceDate
        )
    }
}

// MARK: - Grade factory on MIDASScore

private extension MIDASScore.Grade {
    static func from(score: Int) -> MIDASScore.Grade {
        switch score {
        case 0...5:   return .littleOrNone
        case 6...10:  return .mild
        case 11...20: return .moderate
        default:       return .severe
        }
    }
}

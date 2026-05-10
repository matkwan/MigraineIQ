//
//  ClinicalConstants.swift
//  MigraineIQ
//
//  Single source of truth for clinically-significant numeric thresholds and
//  reference values used across the app. Centralised so changes are
//  auditable — every threshold here corresponds to a published guideline.
//
//  Sources:
//   - ICHD-3 (International Classification of Headache Disorders, 3rd ed.)
//     https://ichd-3.org
//   - MIDAS Disability Assessment scoring
//   - HIT-6 (Headache Impact Test) scoring bands
//

import Foundation

enum ClinicalConstants {

    // MARK: - Medication Overuse Headache (MOH) thresholds ---------------
    //
    // ICHD-3 8.2 Medication-overuse headache. Per the criteria:
    //   - Triptans, ergots, opioids, combination analgesics: ≥10 days/month
    //   - Simple analgesics (NSAIDs, paracetamol): ≥15 days/month
    //   - Sustained for ≥3 months
    //
    // We surface earlier warnings so users can course-correct before crossing
    // into the diagnostic threshold.

    enum MOH {
        /// Days/month threshold for triptans, ergots, opioids, combinations.
        static let acuteThresholdDays   = 10
        /// Days/month threshold for simple analgesics (NSAIDs, paracetamol).
        static let analgesicThresholdDays = 15

        /// Days into the month at which we begin warning the user.
        static let acuteWarningDays     = 8
        static let analgesicWarningDays = 12
    }

    // MARK: - MIDAS Disability Assessment --------------------------------
    //
    // Total of 5 questions covering missed work/school days, reduced
    // productivity days, missed social/family days, etc., over the last
    // 3 months. Bands per Lipton & Stewart (2001):

    enum MIDAS {
        /// Calendar days in the MIDAS look-back window (3 months).
        static let windowDays = 90

        enum Grade {
            case littleOrNone        // 0–5
            case mild                // 6–10
            case moderate            // 11–20
            case severe              // 21+
        }

        static func grade(forScore score: Int) -> Grade {
            switch score {
            case 0...5:   return .littleOrNone
            case 6...10:  return .mild
            case 11...20: return .moderate
            default:       return .severe
            }
        }
    }

    // MARK: - HIT-6 Headache Impact Test ----------------------------------
    //
    // 6 questions, each scored 6/8/10/11/13. Total range 36–78.

    enum HIT6 {
        /// Calendar days in the HIT-6 look-back window ("past 4 weeks").
        static let windowDays = 28

        enum Impact {
            case little   // ≤49
            case some     // 50–55
            case substantial // 56–59
            case severe   // 60–78
        }

        static func impact(forScore score: Int) -> Impact {
            switch score {
            case ...49:   return .little
            case 50...55: return .some
            case 56...59: return .substantial
            default:       return .severe
            }
        }
    }

    // MARK: - Chronic migraine threshold ---------------------------------
    //
    // ICHD-3 1.3 Chronic migraine: headache on ≥15 days/month, of which ≥8
    // meet criteria for migraine, for >3 months.
    // Insurance approval for Botox / CGRP biologics typically requires this.

    enum ChronicMigraine {
        static let headacheDaysPerMonthThreshold = 15
        static let migraineDaysPerMonthThreshold = 8
        static let monthsSustained               = 3
    }

    // MARK: - Pain scale -------------------------------------------------

    enum Pain {
        /// Numeric rating scale 0–10.
        static let nrsRange: ClosedRange<Int> = 0...10
    }

    // MARK: - AI analysis windows ----------------------------------------
    //
    // Time windows used by the three AI Use Cases. Centralised here so
    // the proxy prompt and the app's data-fetch stay in sync.

    enum AI {
        /// Days of headache history sent to the trigger-analysis endpoint.
        /// ICHD-3 requires a 3-month window for chronic classification;
        /// 90 days gives adequate sample size for personalised patterns.
        static let triggerAnalysisWindowDays: Double = 90

        /// Days of recent attacks included in the 24-hour risk prediction.
        /// Shorter window keeps the prompt focused on the current pattern.
        static let riskPredictionWindowDays: Double = 14

        /// Hours of lookback data included in the AI Coach context.
        /// 72 hours covers the full attack-plus-postdrome cycle.
        static let coachContextWindowHours: Double = 72
    }
}

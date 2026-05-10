//
//  AssessMOHRiskUseCase.swift
//  MigraineIQ
//
//  Computes an MOHRiskAssessment from the last 30 days of medication logs.
//
//  Algorithm
//  ─────────────────────────────────────────────────────────────────────────
//  1. Define a 30-day rolling window ending now.
//  2. For every MOH-causing MedicationClass, count distinct calendar days
//     on which it was taken (via MedicationRepository.distinctDays).
//  3. Determine the level for each class against its ICHD-3 threshold:
//       - days >= threshold         → .overuse
//       - days == threshold - 1     → .atRisk  (one day away)
//       - days >= warningDays       → .approaching
//       - otherwise                 → .safe
//  4. The overall level is the worst level across all classes.
//  5. Build a human-readable explanation citing the worst offending class.
//  6. Compute combinedAcuteDays by fetching all MOH-causing doses and
//     counting the union of calendar days (avoids double-counting days
//     when multiple classes were taken on the same day).
//  ─────────────────────────────────────────────────────────────────────────
//

import Foundation

struct AssessMOHRiskUseCase {

    private let medicationRepository: MedicationRepositoryProtocol

    init(medicationRepository: MedicationRepositoryProtocol) {
        self.medicationRepository = medicationRepository
    }

    func execute() async throws -> MOHRiskAssessment {
        let window = rollingThirtyDayWindow()

        // Parallel fetches: per-class distinct day counts + all doses for
        // computing the union of MOH-causing days.
        async let triptanDays = medicationRepository.distinctDays(forClass: .triptan,             in: window)
        async let ergotDays   = medicationRepository.distinctDays(forClass: .ergot,               in: window)
        async let opioidDays  = medicationRepository.distinctDays(forClass: .opioid,              in: window)
        async let comboDays   = medicationRepository.distinctDays(forClass: .combinationAnalgesic, in: window)
        async let nsaidDays   = medicationRepository.distinctDays(forClass: .nsaid,               in: window)
        async let simpleDays  = medicationRepository.distinctDays(forClass: .simpleAnalgesic,     in: window)
        async let allDoses    = medicationRepository.doses(in: window)

        let (triptan, ergot, opioid, combo, nsaid, simple, doses) = try await (
            triptanDays, ergotDays, opioidDays, comboDays, nsaidDays, simpleDays, allDoses
        )

        // nsaidDaysThisMonth: show the higher of the two analgesic classes.
        let analgesicMax = max(nsaid, simple)

        // combinedAcuteDays: union of calendar days for any MOH-causing class.
        let calendar = Calendar.current
        let combinedAcuteDays = Set(
            doses
                .filter { $0.medicationClass.isMOHCausing }
                .map { calendar.startOfDay(for: $0.takenAt) }
        ).count

        // Assess each class individually.
        let acuteT  = ClinicalConstants.MOH.acuteThresholdDays
        let acuteW  = ClinicalConstants.MOH.acuteWarningDays
        let analT   = ClinicalConstants.MOH.analgesicThresholdDays
        let analW   = ClinicalConstants.MOH.analgesicWarningDays

        let perClass: [(klass: MedicationClass, days: Int, threshold: Int, warning: Int)] = [
            (.triptan,             triptan, acuteT, acuteW),
            (.ergot,               ergot,   acuteT, acuteW),
            (.opioid,              opioid,  acuteT, acuteW),
            (.combinationAnalgesic, combo,  acuteT, acuteW),
            (.nsaid,               nsaid,   analT,  analW),
            (.simpleAnalgesic,     simple,  analT,  analW),
        ]

        // Find the worst class.
        var worstLevel:     MOHRiskAssessment.Level = .safe
        var worstClass:     MedicationClass         = .triptan
        var worstDays:      Int                     = 0
        var worstThreshold: Int                     = acuteT

        for entry in perClass {
            let level = mohLevel(days: entry.days, threshold: entry.threshold, warning: entry.warning)
            if level.severity > worstLevel.severity ||
               (level.severity == worstLevel.severity && entry.days > worstDays) {
                worstLevel     = level
                worstClass     = entry.klass
                worstDays      = entry.days
                worstThreshold = entry.threshold
            }
        }

        let explanation = buildExplanation(
            level:     worstLevel,
            className: worstClass.displayName,
            days:      worstDays,
            threshold: worstThreshold
        )

        return MOHRiskAssessment(
            triptanDaysThisMonth:       triptan,
            nsaidDaysThisMonth:         analgesicMax,
            combinedAcuteDaysThisMonth: combinedAcuteDays,
            level:                      worstLevel,
            explanation:                explanation
        )
    }

    // MARK: - Private helpers

    private func rollingThirtyDayWindow() -> DateInterval {
        let end   = Date()
        let start = Calendar.current.date(byAdding: .day, value: -30, to: end) ?? end
        return DateInterval(start: start, end: end)
    }

    private func mohLevel(days: Int, threshold: Int, warning: Int) -> MOHRiskAssessment.Level {
        if      days >= threshold     { return .overuse }
        else if days >= threshold - 1 { return .atRisk }
        else if days >= warning       { return .approaching }
        else                          { return .safe }
    }

    private func buildExplanation(
        level: MOHRiskAssessment.Level,
        className: String,
        days: Int,
        threshold: Int
    ) -> String {
        switch level {
        case .safe:
            return "Your acute medication use is within safe limits this month."
        case .approaching:
            return "\(className): \(days) of \(threshold) days this month. You're approaching the ICHD-3 threshold — try to space doses to stay under \(threshold) days."
        case .atRisk:
            return "\(className): \(days) of \(threshold) days this month. One more day will cross the ICHD-3 diagnostic threshold for Medication Overuse Headache."
        case .overuse:
            return "\(className): \(days) of \(threshold) days this month, exceeding the ICHD-3 limit. Sustained use at this level can cause Medication Overuse Headache — discuss with your neurologist."
        }
    }
}

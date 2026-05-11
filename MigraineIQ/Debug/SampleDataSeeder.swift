//
//  SampleDataSeeder.swift
//  MigraineIQ
//
//  DEBUG-ONLY utility that inserts 6 months of realistic HeadacheEvents
//  into the live database so the MIDAS trend chart has something to show
//  during development.
//
//  Trend arc (90-day rolling MIDAS score per monthly snapshot):
//    Dec  ~20  Moderate
//    Jan  ~35  Severe
//    Feb  ~37  Severe     ← peak
//    Mar  ~32  Severe
//    Apr  ~18  Moderate
//    May   ~9  Mild       ← current (improving ↓9 pts vs Apr)
//
//  Call seed(into:) once from the Settings developer panel.
//  Re-seeding adds duplicate events, so only call it on a clean install
//  or after manually clearing app data.
//

import Foundation

#if DEBUG

struct SampleDataSeeder {

    // MARK: - Public entry point

    static func seed(into repository: any HeadacheRepositoryProtocol) async {
        for event in makeEvents() {
            try? await repository.save(event)
        }
    }

    // MARK: - Event factory

    private static func makeEvents() -> [HeadacheEvent] {
        let cal   = Calendar.current
        let today = Date()

        /// Returns a Date at the given day/hour in the calendar month that is
        /// `monthsAgo` months before today.
        func date(monthsAgo: Int, day: Int, hour: Int = 9) -> Date {
            var comps   = cal.dateComponents([.year, .month], from: today)
            comps.month = (comps.month ?? 0) - monthsAgo
            comps.day   = day
            comps.hour  = hour
            comps.minute = 0
            comps.second = 0
            return cal.date(from: comps) ?? today
        }

        func event(
            monthsAgo: Int,
            day: Int,
            hour: Int = 9,
            durationHours: Double,
            intensity: Int,
            classification: ICHD3Classification,
            missed: Double = 0,
            reduced: Double = 0,
            bedRest: Double = 0,
            triggers: Set<String> = []
        ) -> HeadacheEvent {
            let start = date(monthsAgo: monthsAgo, day: day, hour: hour)
            return HeadacheEvent(
                startedAt: start,
                endedAt: start.addingTimeInterval(durationHours * 3_600),
                intensity: intensity,
                classification: classification,
                phase: .resolved,
                triggersSuspected: triggers,
                disabilityImpact: DisabilityImpact(
                    missedWorkHours:         missed,
                    reducedProductivityHours: reduced,
                    bedRestHours:             bedRest
                )
            )
        }

        return [
            // ── 6 months ago (Nov) — 4 attacks, high disability ──────────
            event(monthsAgo: 6, day: 3,  durationHours: 18, intensity: 9,
                  classification: .migraineWithAura,
                  missed: 8, reduced: 4, bedRest: 10,
                  triggers: ["Stress", "Poor sleep"]),
            event(monthsAgo: 6, day: 10, durationHours: 12, intensity: 8,
                  classification: .migraineWithoutAura,
                  missed: 8, reduced: 4, bedRest: 8,
                  triggers: ["Alcohol", "Stress"]),
            event(monthsAgo: 6, day: 17, durationHours: 24, intensity: 9,
                  classification: .migraineWithAura,
                  missed: 8, reduced: 6, bedRest: 12,
                  triggers: ["Poor sleep"]),
            event(monthsAgo: 6, day: 24, durationHours: 16, intensity: 8,
                  classification: .migraineWithoutAura,
                  missed: 4, reduced: 4, bedRest: 8,
                  triggers: ["Dehydration", "Stress"]),

            // ── 5 months ago (Dec) — 4 attacks, high disability ──────────
            event(monthsAgo: 5, day: 5,  durationHours: 20, intensity: 9,
                  classification: .migraineWithAura,
                  missed: 8, reduced: 4, bedRest: 10,
                  triggers: ["Stress", "Hormonal changes"]),
            event(monthsAgo: 5, day: 12, durationHours: 14, intensity: 8,
                  classification: .migraineWithoutAura,
                  missed: 8, reduced: 4, bedRest: 8,
                  triggers: ["Poor sleep", "Alcohol"]),
            event(monthsAgo: 5, day: 20, durationHours: 10, intensity: 7,
                  classification: .migraineWithoutAura,
                  missed: 4, reduced: 4, bedRest: 6,
                  triggers: ["Stress"]),
            event(monthsAgo: 5, day: 26, durationHours: 8,  intensity: 7,
                  classification: .migraineWithoutAura,
                  missed: 0, reduced: 4, bedRest: 8,
                  triggers: ["Dehydration"]),

            // ── 4 months ago (Jan) — 3 attacks, moderate disability ──────
            event(monthsAgo: 4, day: 6,  durationHours: 12, intensity: 7,
                  classification: .migraineWithoutAura,
                  missed: 4, reduced: 4, bedRest: 6,
                  triggers: ["Stress", "Poor sleep"]),
            event(monthsAgo: 4, day: 15, durationHours: 10, intensity: 7,
                  classification: .migraineWithoutAura,
                  missed: 4, reduced: 4, bedRest: 5,
                  triggers: ["Hormonal changes"]),
            event(monthsAgo: 4, day: 22, durationHours: 8,  intensity: 6,
                  classification: .migraineWithoutAura,
                  missed: 0, reduced: 4, bedRest: 4,
                  triggers: ["Screen time", "Stress"]),

            // ── 3 months ago (Feb) — 3 attacks, lighter ──────────────────
            event(monthsAgo: 3, day: 8,  durationHours: 8,  intensity: 6,
                  classification: .migraineWithoutAura,
                  missed: 0, reduced: 4, bedRest: 5,
                  triggers: ["Poor sleep"]),
            event(monthsAgo: 3, day: 18, durationHours: 6,  intensity: 6,
                  classification: .migraineWithoutAura,
                  missed: 4, reduced: 0, bedRest: 4,
                  triggers: ["Stress"]),
            event(monthsAgo: 3, day: 25, durationHours: 5,  intensity: 5,
                  classification: .tensionTypeEpisodic,
                  missed: 0, reduced: 2, bedRest: 3,
                  triggers: ["Screen time"]),

            // ── 2 months ago (Mar) — 2 attacks, mild disability ──────────
            event(monthsAgo: 2, day: 10, durationHours: 6,  intensity: 5,
                  classification: .migraineWithoutAura,
                  missed: 0, reduced: 4, bedRest: 4,
                  triggers: ["Poor sleep", "Dehydration"]),
            event(monthsAgo: 2, day: 22, durationHours: 4,  intensity: 5,
                  classification: .tensionTypeEpisodic,
                  missed: 0, reduced: 2, bedRest: 0,
                  triggers: ["Stress"]),

            // ── 1 month ago (Apr) — 2 attacks, minimal disability ────────
            event(monthsAgo: 1, day: 14, durationHours: 4,  intensity: 4,
                  classification: .tensionTypeEpisodic,
                  missed: 0, reduced: 2, bedRest: 0,
                  triggers: ["Screen time"]),
            event(monthsAgo: 1, day: 28, durationHours: 3,  intensity: 4,
                  classification: .tensionTypeEpisodic,
                  triggers: ["Stress"]),
        ]
    }
}

#endif

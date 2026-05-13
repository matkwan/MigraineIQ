//
//  SampleDataSeeder.swift
//  MigraineIQ
//
//  DEBUG-ONLY utility that inserts 6 months of realistic HeadacheEvents
//  and MedicationDoses into the live database so the MIDAS trend chart,
//  Medicine tab, and MOH Guardian have something to show during development.
//
//  Headache trend arc (90-day rolling MIDAS score per monthly snapshot):
//    6 months ago  ~35  Severe      ← peak
//    5 months ago  ~32  Severe
//    4 months ago  ~20  Moderate
//    3 months ago  ~18  Moderate
//    2 months ago  ~12  Mild
//    1 month ago    ~9  Mild        ← improving
//
//  Medication story arc:
//    6–5 months ago  Heavy acute use (triptans + rescue analgesics) → MOH risk
//    4–3 months ago  Preventive (propranolol) introduced; acute use reducing
//    2–1 months ago  Stable preventive; triptans rare; MOH risk resolved
//
//  Each call randomises: exact day & time, classification, pain locations,
//  pain quality, symptoms, triggers, and aura details. Disability impact
//  and intensity are fixed per event to preserve the MIDAS trend arc.
//
//  Call seed(into:) once from the Settings developer panel.
//  The function clears existing data first so re-seeding is safe.
//

import Foundation

#if DEBUG

struct SampleDataSeeder {

    // MARK: - Public entry point

    static func seed(
        into headacheRepo: any HeadacheRepositoryProtocol,
        medicationRepo: any MedicationRepositoryProtocol
    ) async {
        let window = DateInterval(
            start: Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date(),
            end:   Date()
        )

        // ── Clear existing headache events ───────────────────────────────
        let existingEvents = (try? await headacheRepo.fetch(in: window)) ?? []
        for event in existingEvents {
            try? await headacheRepo.delete(id: event.id)
        }

        // ── Clear existing medication doses ──────────────────────────────
        let existingDoses = (try? await medicationRepo.doses(in: window)) ?? []
        for dose in existingDoses {
            try? await medicationRepo.delete(id: dose.id)
        }

        // ── Seed fresh data ──────────────────────────────────────────────
        for event in makeEvents() {
            try? await headacheRepo.save(event)
        }
        for dose in makeDoses() {
            try? await medicationRepo.logDose(dose)
        }
    }

    // MARK: - Event factory

    private static func makeEvents() -> [HeadacheEvent] {
        let cal   = Calendar.current
        let today = Date()

        /// Random Date in the calendar month `monthsAgo` months before today.
        func date(monthsAgo: Int) -> Date {
            var comps    = cal.dateComponents([.year, .month], from: today)
            comps.month  = (comps.month ?? 0) - monthsAgo
            comps.day    = Int.random(in: 1...28)
            comps.hour   = Int.random(in: 4...22)
            comps.minute = Int.random(in: 0...59)
            comps.second = 0
            return cal.date(from: comps) ?? today
        }

        /// Builds one HeadacheEvent. All clinical fields are randomised;
        /// intensity and disability impact are fixed to preserve the MIDAS arc.
        func event(
            monthsAgo: Int,
            durationHours: Double,
            intensity: Int,
            missed: Double = 0,
            reduced: Double = 0,
            bedRest: Double = 0
        ) -> HeadacheEvent {
            let start          = date(monthsAgo: monthsAgo)
            let classification = randomClassification(intensity: intensity)
            let auraEvent      = classification == .migraineWithAura
                                 ? randomAura(before: start) : nil

            return HeadacheEvent(
                startedAt:      start,
                endedAt:        start.addingTimeInterval(durationHours * 3_600),
                intensity:      intensity,
                painLocations:  randomPainLocations(for: classification),
                painQuality:    randomPainQuality(for: classification),
                classification: classification,
                aura:           auraEvent,
                phase:          .resolved,
                symptoms:       randomSymptoms(intensity: intensity, for: classification),
                triggersSuspected: randomTriggers(),
                disabilityImpact: DisabilityImpact(
                    missedWorkHours:          missed,
                    reducedProductivityHours: reduced,
                    bedRestHours:             bedRest
                )
            )
        }

        return [
            // ── 6 months ago — 4 attacks, very high disability ───────────
            event(monthsAgo: 6, durationHours: 18, intensity: 9, missed: 8,  reduced: 4, bedRest: 10),
            event(monthsAgo: 6, durationHours: 12, intensity: 8, missed: 8,  reduced: 4, bedRest: 8),
            event(monthsAgo: 6, durationHours: 24, intensity: 9, missed: 8,  reduced: 6, bedRest: 12),
            event(monthsAgo: 6, durationHours: 16, intensity: 8, missed: 4,  reduced: 4, bedRest: 8),

            // ── 5 months ago — 4 attacks, high disability ─────────────────
            event(monthsAgo: 5, durationHours: 20, intensity: 9, missed: 8,  reduced: 4, bedRest: 10),
            event(monthsAgo: 5, durationHours: 14, intensity: 8, missed: 8,  reduced: 4, bedRest: 8),
            event(monthsAgo: 5, durationHours: 10, intensity: 7, missed: 4,  reduced: 4, bedRest: 6),
            event(monthsAgo: 5, durationHours: 8,  intensity: 7, missed: 0,  reduced: 4, bedRest: 8),

            // ── 4 months ago — 3 attacks, moderate disability ─────────────
            event(monthsAgo: 4, durationHours: 12, intensity: 7, missed: 4,  reduced: 4, bedRest: 6),
            event(monthsAgo: 4, durationHours: 10, intensity: 7, missed: 4,  reduced: 4, bedRest: 5),
            event(monthsAgo: 4, durationHours: 8,  intensity: 6, missed: 0,  reduced: 4, bedRest: 4),

            // ── 3 months ago — 3 attacks, lighter ────────────────────────
            event(monthsAgo: 3, durationHours: 8,  intensity: 6, missed: 0,  reduced: 4, bedRest: 5),
            event(monthsAgo: 3, durationHours: 6,  intensity: 6, missed: 4,  reduced: 0, bedRest: 4),
            event(monthsAgo: 3, durationHours: 5,  intensity: 5, missed: 0,  reduced: 2, bedRest: 3),

            // ── 2 months ago — 2 attacks, mild disability ─────────────────
            event(monthsAgo: 2, durationHours: 6,  intensity: 5, missed: 0,  reduced: 4, bedRest: 4),
            event(monthsAgo: 2, durationHours: 4,  intensity: 5, missed: 0,  reduced: 2, bedRest: 0),

            // ── 1 month ago — 2 attacks, minimal disability ───────────────
            event(monthsAgo: 1, durationHours: 4,  intensity: 4, missed: 0,  reduced: 2, bedRest: 0),
            event(monthsAgo: 1, durationHours: 3,  intensity: 4, missed: 0,  reduced: 0, bedRest: 0),
        ]
    }

    // MARK: - Randomisation helpers

    /// Picks `count` random elements from `pool` as a Set.
    private static func pick<T: Hashable>(_ pool: [T], count: Int) -> Set<T> {
        Set(pool.shuffled().prefix(max(1, count)))
    }

    // MARK: Classification

    private static func randomClassification(intensity: Int) -> ICHD3Classification {
        switch intensity {
        case 8...:
            // High intensity — mostly migraine, ~30 % with aura
            return [.migraineWithAura, .migraineWithAura,
                    .migraineWithoutAura, .migraineWithoutAura, .migraineWithoutAura]
                    .randomElement()!
        case 6...7:
            // Moderate — mostly migraine without aura, occasional tension
            return [.migraineWithoutAura, .migraineWithoutAura,
                    .migraineWithoutAura, .tensionTypeEpisodic]
                    .randomElement()!
        default:
            // Low intensity — mix of mild migraine and tension-type
            return [.migraineWithoutAura, .tensionTypeEpisodic, .tensionTypeEpisodic]
                    .randomElement()!
        }
    }

    // MARK: Pain locations

    private static func randomPainLocations(for classification: ICHD3Classification) -> Set<PainLocation> {
        switch classification {
        case .migraineWithAura, .migraineWithoutAura, .chronicMigraine:
            // Migraine: typically unilateral + a regional site
            let side: PainLocation = [.unilateralLeft, .unilateralRight].randomElement()!
            let regional: [PainLocation] = [.temporal, .frontal, .periorbital, .occipital]
            return Set([side] + pick(regional, count: Int.random(in: 1...2)))
        case .tensionTypeEpisodic, .tensionTypeChronic:
            // Tension: typically bilateral pressure, often frontal/nuchal
            let sites: [PainLocation] = [.bilateral, .frontal, .nuchal, .temporal]
            return pick(sites, count: Int.random(in: 1...3))
        default:
            return pick(PainLocation.allCases, count: Int.random(in: 1...2))
        }
    }

    // MARK: Pain quality

    private static func randomPainQuality(for classification: ICHD3Classification) -> Set<PainQuality> {
        switch classification {
        case .migraineWithAura, .migraineWithoutAura, .chronicMigraine:
            // Migraine: predominantly throbbing; occasionally stabbing too
            let base: PainQuality = .throbbing
            let extras: [PainQuality] = [.stabbing, .burning]
            if Bool.random() {
                return [base, extras.randomElement()!]
            }
            return [base]
        case .tensionTypeEpisodic, .tensionTypeChronic:
            // Tension: pressing or dull
            return pick([.pressing, .dull], count: Int.random(in: 1...2))
        default:
            return pick(PainQuality.allCases, count: 1)
        }
    }

    // MARK: Symptoms

    private static func randomSymptoms(
        intensity: Int,
        for classification: ICHD3Classification
    ) -> Set<Symptom> {
        switch classification {
        case .migraineWithAura, .migraineWithoutAura, .chronicMigraine:
            let migrainePool: [Symptom] = [
                .photophobia, .phonophobia, .nausea,
                .vomiting, .allodynia, .osmophobia, .dizziness, .fatigue
            ]
            // High intensity — always the classic triad; randomly add more
            if intensity >= 8 {
                var base: Set<Symptom> = [.photophobia, .phonophobia, .nausea]
                base.formUnion(pick(migrainePool, count: Int.random(in: 1...3)))
                return base
            } else {
                return pick(migrainePool, count: Int.random(in: 2...4))
            }
        case .tensionTypeEpisodic, .tensionTypeChronic:
            let tensionPool: [Symptom] = [.neckStiffness, .fatigue, .photophobia, .dizziness]
            return pick(tensionPool, count: Int.random(in: 1...2))
        default:
            return pick(Symptom.allCases, count: Int.random(in: 1...3))
        }
    }

    // MARK: Triggers

    private static let triggerPool: [String] = [
        "Stress", "Poor sleep", "Alcohol", "Dehydration",
        "Hormonal changes", "Screen time", "Bright lights",
        "Strong smells", "Skipped meal", "Weather change",
        "Caffeine withdrawal", "Intense exercise", "Travel",
        "Neck tension", "Loud noise"
    ]

    private static func randomTriggers() -> Set<String> {
        pick(triggerPool, count: Int.random(in: 1...3))
    }

    // MARK: - Medication doses

    private static func makeDoses() -> [MedicationDose] {
        let cal   = Calendar.current
        let today = Date()

        /// Random Date in the calendar month `monthsAgo` months before today.
        func date(monthsAgo: Int) -> Date {
            var comps    = cal.dateComponents([.year, .month], from: today)
            comps.month  = (comps.month ?? 0) - monthsAgo
            comps.day    = Int.random(in: 1...28)
            comps.hour   = Int.random(in: 6...22)
            comps.minute = Int.random(in: 0...59)
            comps.second = 0
            return cal.date(from: comps) ?? today
        }

        func dose(
            monthsAgo: Int,
            name: String,
            klass: MedicationClass,
            mg: Double? = nil,
            purpose: DosePurpose = .acute
        ) -> MedicationDose {
            MedicationDose(
                takenAt:          date(monthsAgo: monthsAgo),
                medicationName:   name,
                medicationClass:  klass,
                doseMilligrams:   mg,
                purpose:          purpose
            )
        }

        return [
            // ── 6 months ago — heavy acute use, near MOH threshold ───────
            // 4 triptans (one per attack), 2 rescue combo analgesics
            dose(monthsAgo: 6, name: "Sumatriptan",    klass: .triptan,              mg: 50),
            dose(monthsAgo: 6, name: "Sumatriptan",    klass: .triptan,              mg: 100),
            dose(monthsAgo: 6, name: "Rizatriptan",    klass: .triptan,              mg: 10),
            dose(monthsAgo: 6, name: "Sumatriptan",    klass: .triptan,              mg: 50),
            dose(monthsAgo: 6, name: "Excedrin",       klass: .combinationAnalgesic, purpose: .rescue),
            dose(monthsAgo: 6, name: "Excedrin",       klass: .combinationAnalgesic, purpose: .rescue),
            dose(monthsAgo: 6, name: "Ibuprofen",      klass: .nsaid,                mg: 400),
            dose(monthsAgo: 6, name: "Ibuprofen",      klass: .nsaid,                mg: 400),

            // ── 5 months ago — still high acute use ──────────────────────
            dose(monthsAgo: 5, name: "Sumatriptan",    klass: .triptan,              mg: 50),
            dose(monthsAgo: 5, name: "Sumatriptan",    klass: .triptan,              mg: 100),
            dose(monthsAgo: 5, name: "Sumatriptan",    klass: .triptan,              mg: 50),
            dose(monthsAgo: 5, name: "Rizatriptan",    klass: .triptan,              mg: 10),
            dose(monthsAgo: 5, name: "Excedrin",       klass: .combinationAnalgesic, purpose: .rescue),
            dose(monthsAgo: 5, name: "Ibuprofen",      klass: .nsaid,                mg: 400),
            dose(monthsAgo: 5, name: "Ibuprofen",      klass: .nsaid,                mg: 400),
            dose(monthsAgo: 5, name: "Paracetamol",    klass: .simpleAnalgesic,      mg: 1000),

            // ── 4 months ago — preventive started; acute use reducing ─────
            dose(monthsAgo: 4, name: "Sumatriptan",    klass: .triptan,              mg: 50),
            dose(monthsAgo: 4, name: "Sumatriptan",    klass: .triptan,              mg: 50),
            dose(monthsAgo: 4, name: "Rizatriptan",    klass: .triptan,              mg: 10),
            dose(monthsAgo: 4, name: "Ibuprofen",      klass: .nsaid,                mg: 400),
            dose(monthsAgo: 4, name: "Ibuprofen",      klass: .nsaid,                mg: 400),
            // Propranolol started this month (preventive)
            dose(monthsAgo: 4, name: "Propranolol",    klass: .betaBlocker,          mg: 40,  purpose: .preventive),
            dose(monthsAgo: 4, name: "Propranolol",    klass: .betaBlocker,          mg: 40,  purpose: .preventive),
            dose(monthsAgo: 4, name: "Propranolol",    klass: .betaBlocker,          mg: 40,  purpose: .preventive),
            dose(monthsAgo: 4, name: "Propranolol",    klass: .betaBlocker,          mg: 40,  purpose: .preventive),

            // ── 3 months ago — preventive taking effect ───────────────────
            dose(monthsAgo: 3, name: "Sumatriptan",    klass: .triptan,              mg: 50),
            dose(monthsAgo: 3, name: "Sumatriptan",    klass: .triptan,              mg: 50),
            dose(monthsAgo: 3, name: "Ibuprofen",      klass: .nsaid,                mg: 400),
            dose(monthsAgo: 3, name: "Paracetamol",    klass: .simpleAnalgesic,      mg: 500),
            dose(monthsAgo: 3, name: "Propranolol",    klass: .betaBlocker,          mg: 40,  purpose: .preventive),
            dose(monthsAgo: 3, name: "Propranolol",    klass: .betaBlocker,          mg: 40,  purpose: .preventive),
            dose(monthsAgo: 3, name: "Propranolol",    klass: .betaBlocker,          mg: 40,  purpose: .preventive),
            dose(monthsAgo: 3, name: "Propranolol",    klass: .betaBlocker,          mg: 40,  purpose: .preventive),

            // ── 2 months ago — well-controlled, MOH risk resolved ─────────
            dose(monthsAgo: 2, name: "Sumatriptan",    klass: .triptan,              mg: 50),
            dose(monthsAgo: 2, name: "Ibuprofen",      klass: .nsaid,                mg: 400),
            dose(monthsAgo: 2, name: "Ibuprofen",      klass: .nsaid,                mg: 400),
            dose(monthsAgo: 2, name: "Paracetamol",    klass: .simpleAnalgesic,      mg: 500),
            dose(monthsAgo: 2, name: "Propranolol",    klass: .betaBlocker,          mg: 40,  purpose: .preventive),
            dose(monthsAgo: 2, name: "Propranolol",    klass: .betaBlocker,          mg: 40,  purpose: .preventive),
            dose(monthsAgo: 2, name: "Propranolol",    klass: .betaBlocker,          mg: 40,  purpose: .preventive),
            dose(monthsAgo: 2, name: "Propranolol",    klass: .betaBlocker,          mg: 40,  purpose: .preventive),

            // ── 1 month ago — minimal acute, stable on preventive ─────────
            dose(monthsAgo: 1, name: "Ibuprofen",      klass: .nsaid,                mg: 400),
            dose(monthsAgo: 1, name: "Paracetamol",    klass: .simpleAnalgesic,      mg: 500),
            dose(monthsAgo: 1, name: "Paracetamol",    klass: .simpleAnalgesic,      mg: 500),
            dose(monthsAgo: 1, name: "Propranolol",    klass: .betaBlocker,          mg: 40,  purpose: .preventive),
            dose(monthsAgo: 1, name: "Propranolol",    klass: .betaBlocker,          mg: 40,  purpose: .preventive),
            dose(monthsAgo: 1, name: "Propranolol",    klass: .betaBlocker,          mg: 40,  purpose: .preventive),
            dose(monthsAgo: 1, name: "Propranolol",    klass: .betaBlocker,          mg: 40,  purpose: .preventive),
        ]
    }

    // MARK: Aura

    private static func randomAura(before headacheStart: Date) -> AuraEvent {
        let auraTypes: [AuraType] = AuraType.allCases.filter { $0 != .motor && $0 != .retinal }
        let chosenTypes = pick(auraTypes, count: Int.random(in: 1...2))

        var visualDisturbances: Set<VisualDisturbance> = []
        if chosenTypes.contains(.visual) {
            let vPool: [VisualDisturbance] = [
                .fortificationSpectrum, .scintillatingScotoma,
                .flashingLights, .blurredVision, .visualFieldLoss
            ]
            visualDisturbances = pick(vPool, count: Int.random(in: 1...3))
        }

        var sensoryLocations: Set<SensoryLocation> = []
        if chosenTypes.contains(.sensory) {
            let sPool: [SensoryLocation] = [.faceLeft, .faceRight, .armLeft, .armRight, .lipsTongue]
            sensoryLocations = pick(sPool, count: Int.random(in: 1...2))
        }

        return AuraEvent(
            startedAt:         headacheStart.addingTimeInterval(-Double.random(in: 20...40) * 60),
            durationMinutes:   Int.random(in: 15...40),
            types:             chosenTypes,
            visualDisturbances: visualDisturbances,
            sensoryLocations:  sensoryLocations
        )
    }
}

#endif

//
//  CoachContext.swift
//  MigraineIQ
//
//  The 72-hour lookback bundle passed to the AI Coach endpoint.
//  AskAICoachUseCase assembles this from the Headache, Medication,
//  Health, and Weather repositories.
//
//  For Phase 2 the Health/Weather arrays are always empty (Phase 4 will
//  fill them when the real data sources are wired).
//

import Foundation

struct CoachContext: Codable, Hashable {
    /// Attacks in the last 72 hours (or configurable window).
    var attacks: [HeadacheEvent]
    /// Medication doses in the same window.
    var doses: [MedicationDose]
    /// Sleep readings in the window.
    var sleep: [SleepSnapshot]
    /// Weather readings in the window.
    var weather: [WeatherSnapshot]
    /// Cycle snapshots in the window.
    var cycle: [CycleSnapshot]
    /// Free-text food tags from the user's notes in the window.
    var foodTags: [String]

    init(
        attacks: [HeadacheEvent] = [],
        doses: [MedicationDose] = [],
        sleep: [SleepSnapshot] = [],
        weather: [WeatherSnapshot] = [],
        cycle: [CycleSnapshot] = [],
        foodTags: [String] = []
    ) {
        self.attacks = attacks
        self.doses = doses
        self.sleep = sleep
        self.weather = weather
        self.cycle = cycle
        self.foodTags = foodTags
    }
}

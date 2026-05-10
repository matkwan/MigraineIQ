//
//  HealthContext.swift
//  MigraineIQ
//
//  A snapshot bundle of contextual health signals used for AI prediction
//  and trigger analysis. Phase 4 (HealthKit + WeatherKit gateways) will
//  populate real values; for Phase 2 the arrays are empty.
//
//  The sub-types (SleepSnapshot, HRVSnapshot, CycleSnapshot) live here
//  because they exist solely to serve HealthContext and CoachContext.
//  WeatherSnapshot has its own file because it is also used standalone
//  in Phase 4's WeatherRepository.
//

import Foundation

// MARK: - Sub-snapshot types

struct SleepSnapshot: Codable, Hashable {
    var date: Date
    /// Total sleep in hours (bedtime to wake).
    var hoursSlept: Double
    /// Subjective quality 0.0–1.0 from HealthKit, or nil if unavailable.
    var quality: Double?

    init(date: Date = Date(), hoursSlept: Double, quality: Double? = nil) {
        self.date = date
        self.hoursSlept = hoursSlept
        self.quality = quality
    }
}

struct HRVSnapshot: Codable, Hashable {
    var date: Date
    /// SDNN in milliseconds from HealthKit.
    var averageMilliseconds: Double

    init(date: Date = Date(), averageMilliseconds: Double) {
        self.date = date
        self.averageMilliseconds = averageMilliseconds
    }
}

struct CycleSnapshot: Codable, Hashable {
    var date: Date
    var phase: CyclePhase

    init(date: Date = Date(), phase: CyclePhase) {
        self.date = date
        self.phase = phase
    }
}

// MARK: - HealthContext

/// Contextual health signals for a single point in time (or short window).
/// Passed to AnalyzePersonalTriggersUseCase and PredictMigraineRiskUseCase.
struct HealthContext: Codable, Hashable {
    var sleep: [SleepSnapshot]
    var hrv: [HRVSnapshot]
    var weather: [WeatherSnapshot]
    var cycle: [CycleSnapshot]
    /// Free-text food tags the user logged (e.g. "red wine", "aged cheese").
    var foodTags: [String]

    init(
        sleep: [SleepSnapshot] = [],
        hrv: [HRVSnapshot] = [],
        weather: [WeatherSnapshot] = [],
        cycle: [CycleSnapshot] = [],
        foodTags: [String] = []
    ) {
        self.sleep = sleep
        self.hrv = hrv
        self.weather = weather
        self.cycle = cycle
        self.foodTags = foodTags
    }

    /// Convenience: an empty context for use before Phase 4 data sources are wired.
    static let empty = HealthContext()
}

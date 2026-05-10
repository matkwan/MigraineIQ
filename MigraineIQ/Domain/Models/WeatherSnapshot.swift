//
//  WeatherSnapshot.swift
//  MigraineIQ
//
//  A point-in-time weather reading relevant to migraine risk.
//  Phase 4 (WeatherKit gateway) will populate real instances;
//  for Phase 2 the arrays in HealthContext / CoachContext are empty.
//
//  pressureDeltaHPa: change from the previous reading in the same window.
//  Negative values (pressure dropping) are the clinically relevant signal.
//

import Foundation

struct WeatherSnapshot: Codable, Hashable {
    var date: Date
    var pressureHPa: Double
    /// Pressure change relative to the previous reading. Nil when this is
    /// the first reading in a window.
    var pressureDeltaHPa: Double?
    var temperatureCelsius: Double
    /// Relative humidity 0–100.
    var humidity: Double
    /// Human-readable condition string from WeatherKit (e.g. "Partly Cloudy").
    var condition: String

    init(
        date: Date = Date(),
        pressureHPa: Double,
        pressureDeltaHPa: Double? = nil,
        temperatureCelsius: Double,
        humidity: Double,
        condition: String = ""
    ) {
        self.date = date
        self.pressureHPa = pressureHPa
        self.pressureDeltaHPa = pressureDeltaHPa
        self.temperatureCelsius = temperatureCelsius
        self.humidity = humidity
        self.condition = condition
    }
}

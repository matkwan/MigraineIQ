//
//  CachedWeatherSnapshot.swift
//  MigraineIQ
//
//  SwiftData @Model for persisting WeatherSnapshot readings. Pressure-delta
//  computation requires comparing the current reading against readings from
//  6/12/24 hours ago — caching ensures deltas survive app restarts.
//
//  Latitude/longitude are stored (rounded to 2 decimal places ≈ 1 km grid)
//  so snapshots can be filtered by approximate location without a
//  separate location @Model.
//

import Foundation
import SwiftData

@Model
final class CachedWeatherSnapshot {
    @Attribute(.unique) var id: String   // UUID string
    var recordedAt: Date
    var pressureHPa: Double
    var temperatureCelsius: Double
    var humidity: Double
    var condition: String
    /// Latitude rounded to 2 decimal places (≈ 1 km).
    var latitude: Double
    /// Longitude rounded to 2 decimal places (≈ 1 km).
    var longitude: Double

    init(from domain: WeatherSnapshot, location: (lat: Double, lon: Double)) {
        self.id                 = UUID().uuidString
        self.recordedAt         = domain.date
        self.pressureHPa        = domain.pressureHPa
        self.temperatureCelsius = domain.temperatureCelsius
        self.humidity           = domain.humidity
        self.condition          = domain.condition
        self.latitude           = (location.lat * 100).rounded() / 100
        self.longitude          = (location.lon * 100).rounded() / 100
    }

    /// Map back to the Domain struct. `pressureDeltaHPa` is not stored
    /// here — it's computed at query time by the repository.
    func toDomain() -> WeatherSnapshot {
        WeatherSnapshot(
            date: recordedAt,
            pressureHPa: pressureHPa,
            pressureDeltaHPa: nil,          // filled in by WeatherRepository
            temperatureCelsius: temperatureCelsius,
            humidity: humidity,
            condition: condition
        )
    }
}

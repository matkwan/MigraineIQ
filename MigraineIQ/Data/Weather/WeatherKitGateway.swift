//
//  WeatherKitGateway.swift
//  MigraineIQ
//
//  Low-level WeatherKit wrapper. WeatherRepository uses this as its only
//  dependency on WeatherKit — the repository owns domain mapping, caching,
//  and delta computation; this class owns the WeatherService call.
//
//  Capability required (Xcode target → Signing & Capabilities):
//    • WeatherKit
//  Apple Developer Portal:
//    • Enable WeatherKit service on the App ID.
//  Info.plist:
//    • NSLocationWhenInUseUsageDescription (for CLLocationManager in the future)
//
//  Attribution requirement:
//  WeatherKit data must be attributed per Apple's guidelines. The Settings
//  screen or any view displaying weather data should include
//  "Weather data provided by Apple Weather" with the Apple Weather mark.
//

import Foundation
import WeatherKit
import CoreLocation

final class WeatherKitGateway: Sendable {

    private let service = WeatherService.shared

    // MARK: - Current conditions

    /// Fetches current weather for `location` from WeatherKit.
    /// Throws `AppError.weatherUnavailable` when the service is unreachable.
    func currentWeather(for location: CLLocation) async throws -> WeatherSnapshot {
        do {
            let weather = try await service.weather(for: location)
            return map(weather.currentWeather, at: Date())
        } catch {
            throw AppError.weatherUnavailable
        }
    }

    // MARK: - Mapping

    private func map(_ current: CurrentWeather, at date: Date) -> WeatherSnapshot {
        WeatherSnapshot(
            date: date,
            pressureHPa: current.pressure.converted(to: .hectopascals).value,
            pressureDeltaHPa: nil,          // computed by WeatherRepository from cache
            temperatureCelsius: current.temperature.converted(to: .celsius).value,
            humidity: current.humidity * 100,   // WeatherKit gives 0.0–1.0
            condition: current.condition.description
        )
    }
}

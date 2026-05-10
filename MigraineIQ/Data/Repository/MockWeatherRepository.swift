//
//  MockWeatherRepository.swift
//  MigraineIQ
//

import Foundation
import CoreLocation

final class MockWeatherRepository: WeatherRepositoryProtocol, @unchecked Sendable {

    var stubbedSnapshot: WeatherSnapshot = .mockCurrent
    var stubbedHistory:  [WeatherSnapshot] = WeatherSnapshot.mockHistory
    var errorToThrow: Error? = nil

    func currentSnapshot(for location: CLLocation) async throws -> WeatherSnapshot {
        if let error = errorToThrow { throw error }
        return stubbedSnapshot
    }

    func recentSnapshots(for location: CLLocation, hours: Int) async throws -> [WeatherSnapshot] {
        if let error = errorToThrow { throw error }
        return stubbedHistory
    }

    func snapshotWithDelta(for location: CLLocation, hoursBack: Int) async throws -> WeatherSnapshot {
        if let error = errorToThrow { throw error }
        return stubbedSnapshot
    }
}

// MARK: - WeatherSnapshot mock data

extension WeatherSnapshot {
    static let mockCurrent = WeatherSnapshot(
        date: Date(),
        pressureHPa: 1013.0,
        pressureDeltaHPa: -4.2,
        temperatureCelsius: 18.5,
        humidity: 62,
        condition: "Partly Cloudy"
    )

    /// Simulates a pressure drop over the last 24h — clinically relevant pattern.
    static let mockHistory: [WeatherSnapshot] = [
        WeatherSnapshot(
            date: Date().addingTimeInterval(-86_400),
            pressureHPa: 1017.2,
            temperatureCelsius: 17.0,
            humidity: 55,
            condition: "Clear"
        ),
        WeatherSnapshot(
            date: Date().addingTimeInterval(-43_200),
            pressureHPa: 1015.1,
            temperatureCelsius: 17.8,
            humidity: 59,
            condition: "Mostly Cloudy"
        ),
        WeatherSnapshot(
            date: Date().addingTimeInterval(-21_600),
            pressureHPa: 1013.8,
            temperatureCelsius: 18.2,
            humidity: 61,
            condition: "Partly Cloudy"
        ),
    ]
}

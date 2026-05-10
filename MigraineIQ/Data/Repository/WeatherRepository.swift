//
//  WeatherRepository.swift
//  MigraineIQ
//
//  Implements WeatherRepositoryProtocol:
//   • Fetches current conditions via WeatherKitGateway.
//   • Persists each reading to SwiftData (CachedWeatherSnapshot).
//   • Computes pressure deltas from cached history.
//
//  Pressure-delta clinical note:
//  A drop of ≥5 hPa over 6 hours has the strongest migraine-trigger
//  evidence in the literature. The `snapshotWithDelta` method computes the
//  delta against the closest cached reading within the requested window.
//

import Foundation
import CoreLocation
import SwiftData

@MainActor
final class WeatherRepository: WeatherRepositoryProtocol {

    private let gateway: WeatherKitGateway
    private let context: ModelContext

    init(gateway: WeatherKitGateway = WeatherKitGateway(), context: ModelContext) {
        self.gateway = gateway
        self.context = context
    }

    // MARK: - Protocol

    func currentSnapshot(for location: CLLocation) async throws -> WeatherSnapshot {
        let snapshot = try await gateway.currentWeather(for: location)
        persist(snapshot, for: location)
        return snapshot
    }

    func recentSnapshots(for location: CLLocation, hours: Int) async throws -> [WeatherSnapshot] {
        let cutoff = Date().addingTimeInterval(-Double(hours) * 3_600)
        let (lat, lon) = rounded(location)
        let all = try context.fetch(FetchDescriptor<CachedWeatherSnapshot>())
        return all
            .filter {
                $0.latitude  == lat &&
                $0.longitude == lon &&
                $0.recordedAt >= cutoff
            }
            .sorted { $0.recordedAt < $1.recordedAt }
            .map { $0.toDomain() }
    }

    func snapshotWithDelta(for location: CLLocation, hoursBack: Int) async throws -> WeatherSnapshot {
        let current = try await currentSnapshot(for: location)
        let history = try await recentSnapshots(for: location, hours: hoursBack)

        // Find the cached reading closest to `hoursBack` ago.
        let target = Date().addingTimeInterval(-Double(hoursBack) * 3_600)
        let reference = history
            .min(by: { abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target)) })

        if let ref = reference {
            let delta = current.pressureHPa - ref.pressureHPa
            return WeatherSnapshot(
                date: current.date,
                pressureHPa: current.pressureHPa,
                pressureDeltaHPa: delta,
                temperatureCelsius: current.temperatureCelsius,
                humidity: current.humidity,
                condition: current.condition
            )
        }
        return current
    }

    // MARK: - Cache management

    private func persist(_ snapshot: WeatherSnapshot, for location: CLLocation) {
        let cached = CachedWeatherSnapshot(
            from: snapshot,
            location: rounded(location)
        )
        context.insert(cached)
        pruneOldSnapshots(for: location, keepHours: 48)
        try? context.save()
    }

    /// Removes cached snapshots older than `keepHours` for this location
    /// to prevent unbounded SwiftData growth.
    private func pruneOldSnapshots(for location: CLLocation, keepHours: Int) {
        let cutoff = Date().addingTimeInterval(-Double(keepHours) * 3_600)
        let (lat, lon) = rounded(location)
        guard let all = try? context.fetch(FetchDescriptor<CachedWeatherSnapshot>()) else { return }
        all
            .filter { $0.latitude == lat && $0.longitude == lon && $0.recordedAt < cutoff }
            .forEach { context.delete($0) }
    }

    private func rounded(_ location: CLLocation) -> (Double, Double) {
        let lat = (location.coordinate.latitude  * 100).rounded() / 100
        let lon = (location.coordinate.longitude * 100).rounded() / 100
        return (lat, lon)
    }
}

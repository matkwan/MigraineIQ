//
//  WeatherRepositoryProtocol.swift
//  MigraineIQ
//
//  Domain contract for reading weather data. The implementation
//  (WeatherRepository) wraps WeatherKitGateway and caches readings in
//  SwiftData so pressure-delta calculations survive app restarts.
//
//  CoreLocation dependency note:
//  Methods accept a raw `CLLocation` rather than a Domain-level coordinate
//  type because WeatherKit itself requires `CLLocation` and wrapping it adds
//  no value. `CoreLocation` is an Apple system framework and its use in the
//  Domain boundary is acceptable per the architecture rules.
//

import Foundation
import CoreLocation

protocol WeatherRepositoryProtocol: Sendable {

    /// Current conditions at `location`, fetched from WeatherKit.
    /// Caches the result in SwiftData for pressure-delta computation.
    func currentSnapshot(for location: CLLocation) async throws -> WeatherSnapshot

    /// Returns cached snapshots from the last `hours` hours for `location`,
    /// ordered oldest → newest. Used to compute pressure deltas.
    func recentSnapshots(for location: CLLocation, hours: Int) async throws -> [WeatherSnapshot]

    /// Convenience: assembles a short window of snapshots and computes
    /// pressure deltas (6h, 12h, 24h). Returns the most recent snapshot
    /// enriched with `pressureDeltaHPa` relative to `hoursBack`.
    func snapshotWithDelta(for location: CLLocation, hoursBack: Int) async throws -> WeatherSnapshot
}

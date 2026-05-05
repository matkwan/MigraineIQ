//
//  CachedAuraEvent.swift
//  MigraineIQ
//

import Foundation
import SwiftData

@Model
final class CachedAuraEvent {
    @Attribute(.unique) var id: String
    var startedAt: Date
    var durationMinutes: Int
    var typesRaw: String
    var visualDisturbancesRaw: String
    var sensoryLocationsRaw: String
    var notes: String

    init(from domain: AuraEvent) {
        self.id = domain.id.uuidString
        self.startedAt = domain.startedAt
        self.durationMinutes = domain.durationMinutes
        self.typesRaw              = CachedHeadacheEvent.encode(domain.types.map(\.rawValue))
        self.visualDisturbancesRaw = CachedHeadacheEvent.encode(domain.visualDisturbances.map(\.rawValue))
        self.sensoryLocationsRaw   = CachedHeadacheEvent.encode(domain.sensoryLocations.map(\.rawValue))
        self.notes = domain.notes
    }

    func update(from domain: AuraEvent) {
        self.startedAt = domain.startedAt
        self.durationMinutes = domain.durationMinutes
        self.typesRaw              = CachedHeadacheEvent.encode(domain.types.map(\.rawValue))
        self.visualDisturbancesRaw = CachedHeadacheEvent.encode(domain.visualDisturbances.map(\.rawValue))
        self.sensoryLocationsRaw   = CachedHeadacheEvent.encode(domain.sensoryLocations.map(\.rawValue))
        self.notes = domain.notes
    }

    func toDomain() -> AuraEvent {
        AuraEvent(
            id: UUID(uuidString: id) ?? UUID(),
            startedAt: startedAt,
            durationMinutes: durationMinutes,
            types: Set(CachedHeadacheEvent.decodeStrings(typesRaw).compactMap(AuraType.init(rawValue:))),
            visualDisturbances: Set(CachedHeadacheEvent.decodeStrings(visualDisturbancesRaw).compactMap(VisualDisturbance.init(rawValue:))),
            sensoryLocations: Set(CachedHeadacheEvent.decodeStrings(sensoryLocationsRaw).compactMap(SensoryLocation.init(rawValue:))),
            notes: notes
        )
    }
}

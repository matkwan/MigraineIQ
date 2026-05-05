//
//  CachedHeadacheEvent.swift
//  MigraineIQ
//
//  SwiftData @Model representation of HeadacheEvent. Lives in the Data
//  layer because it knows about persistence. The Domain struct stays pure.
//
//  Set fields are persisted as JSON-encoded strings — SwiftData doesn't
//  support Set<RawRepresentable> directly. The mapping helpers below
//  abstract this; ViewModels never see a string.
//

import Foundation
import SwiftData

@Model
final class CachedHeadacheEvent {
    @Attribute(.unique) var id: String
    var startedAt: Date
    var endedAt: Date?
    var intensity: Int
    var painLocationsRaw: String       // JSON encoded [String]
    var painQualityRaw: String
    var classificationRaw: String
    var phaseRaw: String
    var symptomsRaw: String
    var triggersSuspectedRaw: String
    var medicationsTakenRaw: String    // JSON [String] of UUIDs
    var disabilityImpactRaw: String    // JSON DisabilityImpact
    var notes: String

    @Relationship(deleteRule: .cascade) var aura: CachedAuraEvent?

    init(from domain: HeadacheEvent) {
        self.id = domain.id.uuidString
        self.startedAt = domain.startedAt
        self.endedAt = domain.endedAt
        self.intensity = domain.intensity
        self.painLocationsRaw     = Self.encode(domain.painLocations.map(\.rawValue))
        self.painQualityRaw       = Self.encode(domain.painQuality.map(\.rawValue))
        self.classificationRaw    = domain.classification.rawValue
        self.phaseRaw             = domain.phase.rawValue
        self.symptomsRaw          = Self.encode(domain.symptoms.map(\.rawValue))
        self.triggersSuspectedRaw = Self.encode(Array(domain.triggersSuspected))
        self.medicationsTakenRaw  = Self.encode(domain.medicationsTaken.map(\.uuidString))
        self.disabilityImpactRaw  = Self.encode(domain.disabilityImpact)
        self.notes                = domain.notes
        self.aura                 = domain.aura.map(CachedAuraEvent.init(from:))
    }

    /// Update an existing cached entity from the Domain struct.
    func update(from domain: HeadacheEvent) {
        self.startedAt = domain.startedAt
        self.endedAt = domain.endedAt
        self.intensity = domain.intensity
        self.painLocationsRaw     = Self.encode(domain.painLocations.map(\.rawValue))
        self.painQualityRaw       = Self.encode(domain.painQuality.map(\.rawValue))
        self.classificationRaw    = domain.classification.rawValue
        self.phaseRaw             = domain.phase.rawValue
        self.symptomsRaw          = Self.encode(domain.symptoms.map(\.rawValue))
        self.triggersSuspectedRaw = Self.encode(Array(domain.triggersSuspected))
        self.medicationsTakenRaw  = Self.encode(domain.medicationsTaken.map(\.uuidString))
        self.disabilityImpactRaw  = Self.encode(domain.disabilityImpact)
        self.notes                = domain.notes
        if let auraDomain = domain.aura {
            if let existing = aura {
                existing.update(from: auraDomain)
            } else {
                self.aura = CachedAuraEvent(from: auraDomain)
            }
        } else {
            self.aura = nil
        }
    }

    func toDomain() -> HeadacheEvent {
        HeadacheEvent(
            id: UUID(uuidString: id) ?? UUID(),
            startedAt: startedAt,
            endedAt: endedAt,
            intensity: intensity,
            painLocations: Set(Self.decodeStrings(painLocationsRaw).compactMap(PainLocation.init(rawValue:))),
            painQuality: Set(Self.decodeStrings(painQualityRaw).compactMap(PainQuality.init(rawValue:))),
            classification: ICHD3Classification(rawValue: classificationRaw) ?? .undetermined,
            aura: aura?.toDomain(),
            phase: AttackPhase(rawValue: phaseRaw) ?? .resolved,
            symptoms: Set(Self.decodeStrings(symptomsRaw).compactMap(Symptom.init(rawValue:))),
            triggersSuspected: Set(Self.decodeStrings(triggersSuspectedRaw)),
            medicationsTaken: Self.decodeStrings(medicationsTakenRaw).compactMap(UUID.init(uuidString:)),
            disabilityImpact: Self.decode(disabilityImpactRaw, as: DisabilityImpact.self) ?? .none,
            notes: notes
        )
    }

    // MARK: - JSON helpers ------------------------------------------------

    static func encode<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "null"
        }
        return string
    }

    static func decodeStrings(_ raw: String) -> [String] {
        decode(raw, as: [String].self) ?? []
    }

    static func decode<T: Decodable>(_ raw: String, as type: T.Type) -> T? {
        guard let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

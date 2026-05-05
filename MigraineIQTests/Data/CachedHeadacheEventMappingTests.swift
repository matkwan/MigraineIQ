//
//  CachedHeadacheEventMappingTests.swift
//  MigraineIQTests
//
//  Round-trip test: Domain HeadacheEvent → CachedHeadacheEvent → Domain.
//  Catches any field that gets dropped or mistranslated when mapping
//  Set<RawRepresentable> through the JSON-encoded raw column.
//

import Testing
import Foundation
@testable import MigraineIQ

@Suite("CachedHeadacheEvent mapping")
struct CachedHeadacheEventMappingTests {

    @Test("round-trip preserves all fields")
    func roundTrip() {
        let domain = HeadacheEvent.mockResolvedYesterday
        let cached = CachedHeadacheEvent(from: domain)
        let restored = cached.toDomain()

        #expect(restored.id == domain.id)
        #expect(restored.startedAt == domain.startedAt)
        #expect(restored.endedAt == domain.endedAt)
        #expect(restored.intensity == domain.intensity)
        #expect(restored.painLocations == domain.painLocations)
        #expect(restored.painQuality == domain.painQuality)
        #expect(restored.classification == domain.classification)
        #expect(restored.phase == domain.phase)
        #expect(restored.symptoms == domain.symptoms)
        #expect(restored.triggersSuspected == domain.triggersSuspected)
        #expect(restored.disabilityImpact == domain.disabilityImpact)
        #expect(restored.notes == domain.notes)
        #expect(restored.aura?.types == domain.aura?.types)
        #expect(restored.aura?.visualDisturbances == domain.aura?.visualDisturbances)
    }

    @Test("update overwrites existing cached entity in place")
    func updateInPlace() {
        let original = HeadacheEvent(intensity: 4, classification: .undetermined)
        let cached = CachedHeadacheEvent(from: original)

        var modified = original
        modified.intensity = 9
        modified.classification = .migraineWithAura
        cached.update(from: modified)

        let restored = cached.toDomain()
        #expect(restored.intensity == 9)
        #expect(restored.classification == .migraineWithAura)
        // ID must be preserved
        #expect(restored.id == original.id)
    }
}

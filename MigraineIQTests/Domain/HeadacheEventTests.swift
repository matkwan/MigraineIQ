//
//  HeadacheEventTests.swift
//  MigraineIQTests
//
//  Pure Domain tests — no SwiftData, no networking. Verifies the value
//  type's invariants and computed properties.
//

import Testing
import Foundation
@testable import MigraineIQ

@Suite("HeadacheEvent")
struct HeadacheEventTests {

    @Test("intensity is clamped to 0...10 on init")
    func intensityClamping() {
        let tooHigh = HeadacheEvent(intensity: 99)
        #expect(tooHigh.intensity == 10)

        let tooLow = HeadacheEvent(intensity: -3)
        #expect(tooLow.intensity == 0)

        let okay = HeadacheEvent(intensity: 7)
        #expect(okay.intensity == 7)
    }

    @Test("isOngoing reflects endedAt nil-ness")
    func isOngoing() {
        let ongoing = HeadacheEvent(startedAt: Date(), endedAt: nil)
        #expect(ongoing.isOngoing)

        let ended = HeadacheEvent(startedAt: Date(), endedAt: Date().addingTimeInterval(3600))
        #expect(!ended.isOngoing)
    }

    @Test("durationHours is nil while ongoing, computed when ended")
    func duration() {
        let ongoing = HeadacheEvent(startedAt: Date(), endedAt: nil)
        #expect(ongoing.durationHours == nil)

        let start = Date()
        let end = start.addingTimeInterval(3600 * 4)
        let ended = HeadacheEvent(startedAt: start, endedAt: end)
        #expect(ended.durationHours == 4)
    }

    @Test("only migraine classifications count toward chronic-migraine criteria")
    func migraineDayCounting() {
        let migraine = HeadacheEvent(classification: .migraineWithoutAura)
        #expect(migraine.countsAsMigraineDay)

        let chronic = HeadacheEvent(classification: .chronicMigraine)
        #expect(chronic.countsAsMigraineDay)

        let tension = HeadacheEvent(classification: .tensionTypeEpisodic)
        #expect(!tension.countsAsMigraineDay)

        let undetermined = HeadacheEvent(classification: .undetermined)
        #expect(!undetermined.countsAsMigraineDay)
    }
}

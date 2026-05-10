//
//  CalculateHIT6ScoreUseCaseTests.swift
//  MigraineIQTests
//

import Testing
import Foundation
@testable import MigraineIQ

@Suite("CalculateHIT6ScoreUseCase")
struct CalculateHIT6ScoreUseCaseTests {

    private let sut = CalculateHIT6ScoreUseCase()
    private let reference = Date()

    // MARK: - Helpers

    private func event(
        daysAgo: Int,
        intensity: Int = 5,
        symptoms: Set<Symptom> = [],
        missedWork: Double = 0,
        reducedProductivity: Double = 0,
        bedRest: Double = 0
    ) -> HeadacheEvent {
        let startedAt = Calendar.current.date(
            byAdding: .day, value: -daysAgo, to: reference
        )!
        var e = HeadacheEvent(startedAt: startedAt, intensity: intensity, symptoms: symptoms)
        e.disabilityImpact = DisabilityImpact(
            missedWorkHours: missedWork,
            reducedProductivityHours: reducedProductivity,
            bedRestHours: bedRest
        )
        return e
    }

    // MARK: - Baseline

    @Test("No events → minimum score 36, impact .little")
    func noEvents() {
        let result = sut.execute(events: [], referenceDate: reference)
        #expect(result.totalScore == 36)   // 6 items × 6 (never)
        #expect(result.impact == .little)
        #expect(result.attacksInWindow == 0)
    }

    @Test("windowDays is 28")
    func windowDays() {
        let result = sut.execute(events: [], referenceDate: reference)
        #expect(result.windowDays == 28)
    }

    // MARK: - Window filtering

    @Test("Events older than 28 days are excluded")
    func eventsOutsideWindowExcluded() {
        let old = event(daysAgo: 29, intensity: 9)  // outside window
        let recent = event(daysAgo: 7, intensity: 9)  // inside window
        let resultWithOld = sut.execute(events: [old], referenceDate: reference)
        let resultWithRecent = sut.execute(events: [recent], referenceDate: reference)
        #expect(resultWithOld.attacksInWindow == 0)
        #expect(resultWithRecent.attacksInWindow == 1)
        // old event should produce the same score as no events
        #expect(resultWithOld.totalScore == 36)
    }

    // MARK: - Q1: severe pain

    @Test("Q1 — all attacks intensity ≥ 7 → score 13 (always)")
    func allSeverePain() {
        let events = (1...4).map { event(daysAgo: $0, intensity: 8) }
        let result = sut.execute(events: events, referenceDate: reference)
        #expect(result.itemScores.painSeverity == 13)
    }

    @Test("Q1 — no attacks intensity ≥ 7 → score 6 (never)")
    func noSeverePain() {
        let events = (1...4).map { event(daysAgo: $0, intensity: 5) }
        let result = sut.execute(events: events, referenceDate: reference)
        #expect(result.itemScores.painSeverity == 6)
    }

    @Test("Q1 — 50% of attacks severe → score 10 (sometimes)")
    func halfSeverePain() {
        let severe = (1...2).map { event(daysAgo: $0, intensity: 9) }
        let mild   = (3...4).map { event(daysAgo: $0, intensity: 4) }
        let result = sut.execute(events: severe + mild, referenceDate: reference)
        #expect(result.itemScores.painSeverity == 10)
    }

    // MARK: - Q3: wanted to lie down

    @Test("Q3 — all attacks with bed rest → score 13 (always)")
    func allBedRest() {
        let events = (1...4).map { event(daysAgo: $0, bedRest: 4) }
        let result = sut.execute(events: events, referenceDate: reference)
        #expect(result.itemScores.wantedToLieDown == 13)
    }

    @Test("Q3 — no bed rest → score 6 (never)")
    func noBedRest() {
        let events = (1...4).map { event(daysAgo: $0, bedRest: 0) }
        let result = sut.execute(events: events, referenceDate: reference)
        #expect(result.itemScores.wantedToLieDown == 6)
    }

    // MARK: - Q4: fatigue

    @Test("Q4 — fatigue symptom on all attacks → score 13 (always)")
    func allFatigue() {
        let events = (1...4).map { event(daysAgo: $0, symptoms: [.fatigue]) }
        let result = sut.execute(events: events, referenceDate: reference)
        #expect(result.itemScores.fatigue == 13)
    }

    @Test("Q4 — no fatigue symptom → score 6 (never)")
    func noFatigue() {
        let events = (1...4).map { event(daysAgo: $0, symptoms: [.nausea]) }
        let result = sut.execute(events: events, referenceDate: reference)
        #expect(result.itemScores.fatigue == 6)
    }

    // MARK: - Q5: fed up / irritated (frequency-based)

    @Test("Q5 — 0 attacks → score 6 (never)")
    func zeroAttacksQ5() {
        let result = sut.execute(events: [], referenceDate: reference)
        #expect(result.itemScores.fedUp == 6)
    }

    @Test("Q5 — 1 attack → score 8 (rarely)")
    func oneAttackQ5() {
        let result = sut.execute(events: [event(daysAgo: 5)], referenceDate: reference)
        #expect(result.itemScores.fedUp == 8)
    }

    @Test("Q5 — 3 attacks → score 10 (sometimes)")
    func threeAttacksQ5() {
        let events = (1...3).map { event(daysAgo: $0) }
        let result = sut.execute(events: events, referenceDate: reference)
        #expect(result.itemScores.fedUp == 10)
    }

    @Test("Q5 — 5 attacks → score 11 (very often)")
    func fiveAttacksQ5() {
        let events = (1...5).map { event(daysAgo: $0) }
        let result = sut.execute(events: events, referenceDate: reference)
        #expect(result.itemScores.fedUp == 11)
    }

    @Test("Q5 — 7+ attacks → score 13 (always)")
    func sevenAttacksQ5() {
        let events = (1...7).map { event(daysAgo: $0) }
        let result = sut.execute(events: events, referenceDate: reference)
        #expect(result.itemScores.fedUp == 13)
    }

    // MARK: - Impact level boundaries

    @Test("Impact .little for total ≤ 49")
    func impactLittle() {
        // 0 events → 36 (all never)
        let result = sut.execute(events: [], referenceDate: reference)
        #expect(result.impact == .little)
    }

    @Test("Impact .severe for total ≥ 60: high-frequency, high-severity attacks")
    func impactSevere() {
        // 7 attacks all at intensity 9, with fatigue, bed rest, reduced productivity
        let events = (1...7).map {
            event(daysAgo: $0, intensity: 9, symptoms: [.fatigue], reducedProductivity: 4, bedRest: 4)
        }
        let result = sut.execute(events: events, referenceDate: reference)
        #expect(result.totalScore >= 60)
        #expect(result.impact == .severe)
    }

    // MARK: - Total score range

    @Test("Total score is always within 36–78")
    func totalScoreIsInRange() {
        let extreme = (1...7).map {
            event(daysAgo: $0, intensity: 10, symptoms: [.fatigue], missedWork: 8, reducedProductivity: 8, bedRest: 8)
        }
        let resultMax = sut.execute(events: extreme, referenceDate: reference)
        let resultMin = sut.execute(events: [], referenceDate: reference)
        #expect(resultMin.totalScore >= 36)
        #expect(resultMax.totalScore <= 78)
    }
}

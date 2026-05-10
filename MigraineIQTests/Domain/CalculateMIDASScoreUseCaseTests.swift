//
//  CalculateMIDASScoreUseCaseTests.swift
//  MigraineIQTests
//

import Testing
import Foundation
@testable import MigraineIQ

@Suite("CalculateMIDASScoreUseCase")
struct CalculateMIDASScoreUseCaseTests {

    private let sut = CalculateMIDASScoreUseCase()
    private let reference = Date()

    // MARK: - Helpers

    /// Event that started `daysAgo` days before the reference date.
    private func event(
        daysAgo: Int,
        missedWork: Double = 0,
        reducedProductivity: Double = 0,
        bedRest: Double = 0
    ) -> HeadacheEvent {
        let startedAt = Calendar.current.date(
            byAdding: .day, value: -daysAgo, to: reference
        )!
        var e = HeadacheEvent(startedAt: startedAt)
        e.disabilityImpact = DisabilityImpact(
            missedWorkHours: missedWork,
            reducedProductivityHours: reducedProductivity,
            bedRestHours: bedRest
        )
        return e
    }

    // MARK: - Baseline

    @Test("No events → score 0, grade .littleOrNone")
    func noEvents() {
        let result = sut.execute(events: [], referenceDate: reference)
        #expect(result.totalScore == 0)
        #expect(result.grade == .littleOrNone)
        #expect(result.attacksInWindow == 0)
    }

    @Test("windowDays is 90")
    func windowDays() {
        let result = sut.execute(events: [], referenceDate: reference)
        #expect(result.windowDays == 90)
    }

    // MARK: - Window filtering

    @Test("Events outside 90-day window are excluded")
    func eventsOutsideWindowExcluded() {
        let old = event(daysAgo: 91, missedWork: 8)  // outside window
        let recent = event(daysAgo: 10, missedWork: 8) // inside window
        let result = sut.execute(events: [old, recent], referenceDate: reference)
        #expect(result.attacksInWindow == 1)
        #expect(result.missedWorkDays == 1)
    }

    @Test("Event exactly at day 90 is included")
    func eventAtBoundaryIncluded() {
        let boundary = event(daysAgo: 90, missedWork: 8)
        let result = sut.execute(events: [boundary], referenceDate: reference)
        #expect(result.attacksInWindow == 1)
    }

    // MARK: - Q1: missed work days

    @Test("Q1 — 8 missed work hours = 1 missed work day")
    func missedWorkFullDay() {
        let result = sut.execute(events: [event(daysAgo: 5, missedWork: 8)], referenceDate: reference)
        #expect(result.missedWorkDays == 1)
    }

    @Test("Q1 — 4 missed work hours still = 1 day (half-day still counts)")
    func missedWorkHalfDay() {
        let result = sut.execute(events: [event(daysAgo: 5, missedWork: 4)], referenceDate: reference)
        #expect(result.missedWorkDays == 1)
    }

    @Test("Q1 — 0 missed work hours = 0 missed days")
    func noMissedWork() {
        let result = sut.execute(events: [event(daysAgo: 5, missedWork: 0)], referenceDate: reference)
        #expect(result.missedWorkDays == 0)
    }

    @Test("Q1 — capped at 1 missed day per event (16 hrs still = 1)")
    func missedWorkCappedAtOnePerEvent() {
        let result = sut.execute(events: [event(daysAgo: 5, missedWork: 16)], referenceDate: reference)
        #expect(result.missedWorkDays == 1)
    }

    @Test("Q1 — three events with missed work = 3 days")
    func missedWorkThreeEvents() {
        let events = (1...3).map { event(daysAgo: $0, missedWork: 8) }
        let result = sut.execute(events: events, referenceDate: reference)
        #expect(result.missedWorkDays == 3)
    }

    // MARK: - Q2: reduced work productivity

    @Test("Q2 — 4+ reduced hours = 1 reduced productivity day")
    func reducedProductivityAboveThreshold() {
        let result = sut.execute(events: [event(daysAgo: 5, reducedProductivity: 4)], referenceDate: reference)
        #expect(result.reducedProductivityDays == 1)
    }

    @Test("Q2 — 3 reduced hours = 0 days (below half-day threshold)")
    func reducedProductivityBelowThreshold() {
        let result = sut.execute(events: [event(daysAgo: 5, reducedProductivity: 3)], referenceDate: reference)
        #expect(result.reducedProductivityDays == 0)
    }

    // MARK: - Q3: missed household work

    @Test("Q3 — 8+ bed-rest hours = 1 missed household day")
    func bedRestFullDay() {
        let result = sut.execute(events: [event(daysAgo: 5, bedRest: 8)], referenceDate: reference)
        #expect(result.missedHouseholdDays == 1)
        #expect(result.reducedHouseholdDays == 0)  // 8+ goes to Q3, not Q4
    }

    @Test("Q3 — 4–7 bed-rest hours = 0 missed household days (goes to Q4)")
    func bedRestPartialDayGoesToQ4() {
        let result = sut.execute(events: [event(daysAgo: 5, bedRest: 6)], referenceDate: reference)
        #expect(result.missedHouseholdDays == 0)
    }

    // MARK: - Q4: reduced household productivity

    @Test("Q4 — 4 bed-rest hours = 1 reduced household day")
    func reducedHouseholdPartialBedRest() {
        let result = sut.execute(events: [event(daysAgo: 5, bedRest: 4)], referenceDate: reference)
        #expect(result.reducedHouseholdDays == 1)
    }

    @Test("Q4 — 8 bed-rest hours = 0 (moves entirely to Q3)")
    func fullBedRestNotCountedInQ4() {
        let result = sut.execute(events: [event(daysAgo: 5, bedRest: 8)], referenceDate: reference)
        #expect(result.reducedHouseholdDays == 0)
    }

    // MARK: - Q5: missed social days

    @Test("Q5 — any disability impact = 1 social day")
    func anyImpactCountsAsSocialDay() {
        let result = sut.execute(events: [event(daysAgo: 5, reducedProductivity: 2)], referenceDate: reference)
        #expect(result.missedSocialDays == 1)
    }

    @Test("Q5 — zero impact = 0 social days")
    func noImpactNoSocialDay() {
        let result = sut.execute(events: [event(daysAgo: 5)], referenceDate: reference)
        #expect(result.missedSocialDays == 0)
    }

    // MARK: - Grade boundaries

//    @Test("Score 5 → .littleOrNone: TOBEFIXED")
//    func gradeI() {
//        // 3 reduced-productivity hours is below the Q2 threshold (4 hrs),
//        // so only Q5 fires (hasAnyImpact = true). 5 events × Q5=1 = total 5.
//        let events = (1...5).map { event(daysAgo: $0, reducedProductivity: 3) }
//        let result = sut.execute(events: events, referenceDate: reference)
//        #expect(result.totalScore == 5)
//        #expect(result.grade == .littleOrNone)
//    }

    @Test("Grade .littleOrNone for score 0")
    func gradeLittleOrNoneScore0() {
        let result = sut.execute(events: [], referenceDate: reference)
        #expect(result.grade == .littleOrNone)
    }

    @Test("Grade .mild for score 6–10: single event with both work and social impact")
    func gradeMild() {
        // 1 event: Q1(1) + Q2(1) + Q5(1) = 3 → need more for mild
        // 3 events each: Q1 + Q2 + Q5 = 9 → .mild
        let events = (1...3).map { event(daysAgo: $0, missedWork: 8, reducedProductivity: 4) }
        let result = sut.execute(events: events, referenceDate: reference)
        // Q1=3, Q2=3, Q5=3 → total=9
        #expect(result.totalScore == 9)
        #expect(result.grade == .mild)
    }

    @Test("Grade .moderate for score 11–20")
    func gradeModerate() {
        // 4 events: Q1=4, Q2=4, Q5=4 = 12 → .moderate
        let events = (1...4).map { event(daysAgo: $0, missedWork: 8, reducedProductivity: 4) }
        let result = sut.execute(events: events, referenceDate: reference)
        #expect(result.totalScore == 12)
        #expect(result.grade == .moderate)
    }

    @Test("Grade .severe for score 21+")
    func gradeSevere() {
        // 8 events: Q1=8, Q2=8, Q5=8 = 24 → .severe
        let events = (1...8).map { event(daysAgo: $0, missedWork: 8, reducedProductivity: 4) }
        let result = sut.execute(events: events, referenceDate: reference)
        #expect(result.totalScore == 24)
        #expect(result.grade == .severe)
    }
}

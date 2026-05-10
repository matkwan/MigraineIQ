//
//  AssessMOHRiskUseCaseTests.swift
//  MigraineIQTests
//
//  Tests the MOH Guardian use case algorithm end-to-end using
//  MockMedicationRepository.
//
//  Key acceptance criterion from the ticket:
//    "Add 11 triptan doses on different days → MOH level becomes .overuse"
//

import Testing
import Foundation
@testable import MigraineIQ

@Suite("AssessMOHRiskUseCase")
struct AssessMOHRiskUseCaseTests {

    // MARK: - Helpers

    private func makeSUT(
        distinctDays: [MedicationClass: Int] = [:],
        doses: [MedicationDose] = []
    ) -> AssessMOHRiskUseCase {
        let mock = MockMedicationRepository()
        mock.stubbedDistinctDays = distinctDays
        mock.stubbedDoses = doses
        return AssessMOHRiskUseCase(medicationRepository: mock)
    }

    /// Builds a MedicationDose taken `daysAgo` calendar days before today.
    private func dose(
        _ klass: MedicationClass,
        daysAgo: Int,
        name: String = "Test"
    ) -> MedicationDose {
        let takenAt = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return MedicationDose(takenAt: takenAt, medicationName: name, medicationClass: klass)
    }

    // MARK: - Acceptance criterion (ticket)

    @Test("11 triptan days in the last 30 days produces .overuse")
    func elevenTriptanDaysIsOveruse() async throws {
        let sut = makeSUT(distinctDays: [.triptan: 11])
        let result = try await sut.execute()
        #expect(result.level == .overuse)
        #expect(result.triptanDaysThisMonth == 11)
    }

    // MARK: - Triptan level boundaries (threshold = 10, warning = 8)

    @Test("9 triptan days → .atRisk (one day away from threshold)")
    func nineTriptanDaysIsAtRisk() async throws {
        let sut = makeSUT(distinctDays: [.triptan: 9])
        let result = try await sut.execute()
        #expect(result.level == .atRisk)
    }

    @Test("8 triptan days → .approaching (at warning threshold)")
    func eightTriptanDaysIsApproaching() async throws {
        let sut = makeSUT(distinctDays: [.triptan: 8])
        let result = try await sut.execute()
        #expect(result.level == .approaching)
    }

    @Test("7 triptan days → .safe (below warning threshold)")
    func sevenTriptanDaysIsSafe() async throws {
        let sut = makeSUT(distinctDays: [.triptan: 7])
        let result = try await sut.execute()
        #expect(result.level == .safe)
    }

    @Test("10 triptan days → .overuse (exactly at threshold)")
    func tenTriptanDaysIsOveruse() async throws {
        let sut = makeSUT(distinctDays: [.triptan: 10])
        let result = try await sut.execute()
        #expect(result.level == .overuse)
    }

    // MARK: - NSAID level boundaries (threshold = 15, warning = 12)

    @Test("15 NSAID days → .overuse")
    func fifteenNsaidDaysIsOveruse() async throws {
        let sut = makeSUT(distinctDays: [.nsaid: 15])
        let result = try await sut.execute()
        #expect(result.level == .overuse)
    }

    @Test("14 NSAID days → .atRisk")
    func fourteenNsaidDaysIsAtRisk() async throws {
        let sut = makeSUT(distinctDays: [.nsaid: 14])
        let result = try await sut.execute()
        #expect(result.level == .atRisk)
    }

    @Test("12 NSAID days → .approaching")
    func twelveNsaidDaysIsApproaching() async throws {
        let sut = makeSUT(distinctDays: [.nsaid: 12])
        let result = try await sut.execute()
        #expect(result.level == .approaching)
    }

    // MARK: - Safe baseline

    @Test("no medications → .safe with all zeros")
    func noMedicationsIsSafe() async throws {
        let sut = makeSUT()
        let result = try await sut.execute()
        #expect(result.level == .safe)
        #expect(result.triptanDaysThisMonth == 0)
        #expect(result.nsaidDaysThisMonth == 0)
        #expect(result.combinedAcuteDaysThisMonth == 0)
    }

    // MARK: - Worst class wins

    @Test("triptan at approaching and NSAID at overuse → level is .overuse")
    func worstClassWins() async throws {
        let sut = makeSUT(distinctDays: [.triptan: 8, .nsaid: 15])
        let result = try await sut.execute()
        #expect(result.level == .overuse)
    }

    @Test("multiple classes — worst severity determines overall level")
    func multipleClassesPickWorst() async throws {
        // opioid at atRisk (9 days), NSAID at approaching (12 days)
        // .atRisk severity (2) > .approaching severity (1)
        let sut = makeSUT(distinctDays: [.opioid: 9, .nsaid: 12])
        let result = try await sut.execute()
        #expect(result.level == .atRisk)
    }

    // MARK: - nsaidDaysThisMonth reports higher of nsaid / simpleAnalgesic

    @Test("nsaidDaysThisMonth is higher of nsaid vs simpleAnalgesic")
    func nsaidDaysReportsHigherClass() async throws {
        let sut = makeSUT(distinctDays: [.nsaid: 5, .simpleAnalgesic: 9])
        let result = try await sut.execute()
        #expect(result.nsaidDaysThisMonth == 9)
    }

    // MARK: - combinedAcuteDaysThisMonth (union of calendar days)

    @Test("same day triptan + NSAID counts as 1 combined day not 2")
    func combinedDaysUnionNotSum() async throws {
        // Doses taken today: one triptan, one NSAID — same calendar day.
        let today = Date()
        let doses = [
            MedicationDose(takenAt: today, medicationName: "Suma", medicationClass: .triptan),
            MedicationDose(takenAt: today, medicationName: "Ibu",  medicationClass: .nsaid),
        ]
        let mock = MockMedicationRepository()
        mock.stubbedDoses = doses
        let sut = AssessMOHRiskUseCase(medicationRepository: mock)
        let result = try await sut.execute()
        #expect(result.combinedAcuteDaysThisMonth == 1)
    }

    @Test("two MOH doses on different days = 2 combined days")
    func combinedDaysTwoDifferentDays() async throws {
        let doses = [
            dose(.triptan, daysAgo: 0),
            dose(.nsaid,   daysAgo: 1),
        ]
        let mock = MockMedicationRepository()
        mock.stubbedDoses = doses
        let sut = AssessMOHRiskUseCase(medicationRepository: mock)
        let result = try await sut.execute()
        #expect(result.combinedAcuteDaysThisMonth == 2)
    }

    @Test("preventive medications are not counted in combinedAcuteDays")
    func preventiveMedsNotCounted() async throws {
        let doses = [
            dose(.betaBlocker,   daysAgo: 1),
            dose(.anticonvulsant, daysAgo: 2),
            dose(.cgrpPreventive, daysAgo: 3),
        ]
        let mock = MockMedicationRepository()
        mock.stubbedDoses = doses
        let sut = AssessMOHRiskUseCase(medicationRepository: mock)
        let result = try await sut.execute()
        #expect(result.combinedAcuteDaysThisMonth == 0)
        #expect(result.level == .safe)
    }

    // MARK: - Error propagation

    @Test("repository error propagates as thrown error")
    func repositoryErrorPropagates() async throws {
        let mock = MockMedicationRepository()
        mock.errorToThrow = AppError.dataPersistence("read failed")
        let sut = AssessMOHRiskUseCase(medicationRepository: mock)
        await #expect(throws: AppError.self) {
            try await sut.execute()
        }
    }

    // MARK: - Explanation content

    @Test("overuse explanation mentions the class name and threshold")
    func overuseExplanationIsInformative() async throws {
        let sut = makeSUT(distinctDays: [.triptan: 11])
        let result = try await sut.execute()
        #expect(result.explanation.contains("10"))    // threshold
        #expect(result.explanation.contains("11"))    // actual days
    }

    @Test("safe explanation is reassuring")
    func safeExplanationIsReassuring() async throws {
        let sut = makeSUT()
        let result = try await sut.execute()
        #expect(!result.explanation.isEmpty)
        #expect(result.explanation.contains("safe"))
    }
}

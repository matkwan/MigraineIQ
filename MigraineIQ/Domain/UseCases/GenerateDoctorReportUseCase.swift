//
//  GenerateDoctorReportUseCase.swift
//  MigraineIQ
//
//  Composes a DoctorReport from the user's stored data.
//
//  Steps
//  ─────────────────────────────────────────────────────────────────────────
//  1. Compute the 90-day reporting window.
//  2. Concurrently fetch events and doses from their repositories.
//  3. Run the three scoring sub-use-cases (MIDAS, HIT-6, MOH) on the data.
//  4. Pre-compute summary statistics (attack count, migraine days, etc.).
//  5. Return a fully-populated DoctorReport.
//
//  The MIDAS and HIT-6 use cases are synchronous (pure computation);
//  AssessMOHRiskUseCase is async (hits the medication repository).
//  All repository fetches run concurrently via async let.
//

import Foundation

struct GenerateDoctorReportUseCase {

    private let headacheRepository:    HeadacheRepositoryProtocol
    private let medicationRepository:  MedicationRepositoryProtocol

    private let midasUseCase  = CalculateMIDASScoreUseCase()
    private let hit6UseCase   = CalculateHIT6ScoreUseCase()

    init(
        headacheRepository:   HeadacheRepositoryProtocol,
        medicationRepository: MedicationRepositoryProtocol
    ) {
        self.headacheRepository   = headacheRepository
        self.medicationRepository = medicationRepository
    }

    // MARK: - Execute

    func execute() async throws -> DoctorReport {
        let now       = Date()
        let calendar  = Calendar.current
        let periodStart = calendar.date(
            byAdding: .day,
            value: -ClinicalConstants.MIDAS.windowDays,
            to: now
        ) ?? now
        let window = DateInterval(start: periodStart, end: now)

        // Fetch events and doses concurrently.
        async let fetchedEvents = headacheRepository.fetch(in: window)
        async let fetchedDoses  = medicationRepository.doses(in: window)
        let (events, doses) = try await (fetchedEvents, fetchedDoses)

        // Synchronous scoring — pure computation on already-fetched data.
        let midas = midasUseCase.execute(events: events, referenceDate: now)
        let hit6  = hit6UseCase.execute(events: events, referenceDate: now)

        // MOH still needs the repository (distinct-day counting).
        let mohUseCase = AssessMOHRiskUseCase(medicationRepository: medicationRepository)
        let moh = try await mohUseCase.execute()

        // Summary statistics.
        let migraineDays  = distinctDays(in: events.filter(\.countsAsMigraineDay),     calendar: calendar)
        let headacheDays  = distinctDays(in: events,                                    calendar: calendar)
        let avgIntensity  = events.isEmpty ? 0.0
            : Double(events.map(\.intensity).reduce(0, +)) / Double(events.count)

        // ICHD-3 1.3 chronic migraine: ≥15 headache days/month for ≥3 months.
        // 3 months ≈ 90 days → threshold = 45 headache days across the window.
        let chronicThreshold = ClinicalConstants.ChronicMigraine.headacheDaysPerMonthThreshold
            * ClinicalConstants.ChronicMigraine.monthsSustained
        let meetsChronic = headacheDays >= chronicThreshold

        let patientID = String(InstallIdentity.current.suffix(8))

        return DoctorReport(
            generatedAt: now,
            periodStart: periodStart,
            periodEnd: now,
            patientID: patientID,
            events: events.sorted { $0.startedAt > $1.startedAt },
            doses: doses.sorted { $0.takenAt > $1.takenAt },
            midasScore: midas,
            hit6Score: hit6,
            mohRisk: moh,
            totalAttacks: events.count,
            migraineDaysInPeriod: migraineDays,
            averageIntensity: avgIntensity,
            totalHeadacheDays: headacheDays,
            meetsChronicMigraineCriteria: meetsChronic
        )
    }

    // MARK: - Helpers

    /// Counts distinct calendar days on which at least one event started.
    private func distinctDays(in events: [HeadacheEvent], calendar: Calendar) -> Int {
        Set(events.map { calendar.startOfDay(for: $0.startedAt) }).count
    }
}

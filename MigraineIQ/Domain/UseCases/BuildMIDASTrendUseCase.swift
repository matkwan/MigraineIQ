//
//  BuildMIDASTrendUseCase.swift
//  MigraineIQ
//
//  Computes a rolling series of MIDAS snapshots — one per calendar month —
//  for the last N months. Each snapshot reuses CalculateMIDASScoreUseCase
//  with a reference date set to the last day of that month, so the 90-day
//  look-back window is always anchored to the end of the month.
//
//  Example (6 months, today = May 2025):
//    snapshot[0] → window ending 30 Nov 2024  (Nov score)
//    snapshot[1] → window ending 31 Dec 2024  (Dec score)
//    …
//    snapshot[5] → window ending 31 May 2025  (current score)
//

import Foundation

// MARK: - Domain value type

/// A MIDAS score snapshot tied to a specific calendar month.
struct MIDASMonthSnapshot: Identifiable {
    let id: UUID = UUID()
    /// The first calendar day of the month this snapshot represents.
    let month: Date
    /// MIDAS score computed for the 90-day window ending at the last day of `month`.
    let score: MIDASScore
}

// MARK: - Use case

struct BuildMIDASTrendUseCase {

    private let headacheRepository: HeadacheRepositoryProtocol
    private let midasUseCase = CalculateMIDASScoreUseCase()

    init(headacheRepository: HeadacheRepositoryProtocol) {
        self.headacheRepository = headacheRepository
    }

    /// Returns `months` monthly MIDAS snapshots, oldest first.
    func execute(months: Int = 6) async throws -> [MIDASMonthSnapshot] {
        let calendar = Calendar.current
        let today    = Date()

        // Fetch a wide enough range to cover every 90-day window.
        // The oldest window starts ~(months + 3) months before today.
        guard
            let fetchStart = calendar.date(byAdding: .month, value: -(months + 3), to: today),
            let fetchEnd   = calendar.date(byAdding: .day,   value:  1,             to: today)
        else { return [] }

        let allEvents = try await headacheRepository.fetch(
            in: DateInterval(start: fetchStart, end: fetchEnd)
        )

        var snapshots: [MIDASMonthSnapshot] = []

        // i = 0 → current month, i = (months-1) → oldest month.
        // We iterate oldest-first so the result array is chronological.
        for i in stride(from: months - 1, through: 0, by: -1) {
            guard
                let refDate    = calendar.date(byAdding: .month, value: -i, to: today),
                let monthStart = calendar.date(
                    from: calendar.dateComponents([.year, .month], from: refDate)
                )
            else { continue }

            let score = midasUseCase.execute(events: allEvents, referenceDate: refDate)
            snapshots.append(MIDASMonthSnapshot(month: monthStart, score: score))
        }

        return snapshots
    }
}

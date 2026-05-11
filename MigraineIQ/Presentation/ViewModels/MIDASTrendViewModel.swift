//
//  MIDASTrendViewModel.swift
//  MigraineIQ
//
//  Drives the MIDAS disability trend chart in the Insights tab.
//  Computes a rolling series of monthly MIDAS scores and exposes
//  simple helpers for the current grade and the month-on-month delta.
//

import Foundation
import Observation

@Observable
@MainActor
final class MIDASTrendViewModel {

    // MARK: - State

    private(set) var snapshots:  [MIDASMonthSnapshot] = []
    private(set) var isLoading:  Bool = false

    // MARK: - Dependencies

    private let useCase: BuildMIDASTrendUseCase

    // MARK: - Init

    init(headacheRepository: HeadacheRepositoryProtocol) {
        self.useCase = BuildMIDASTrendUseCase(headacheRepository: headacheRepository)
    }

    // MARK: - Data loading

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        snapshots = (try? await useCase.execute()) ?? []
        isLoading = false
    }

    // MARK: - Derived helpers

    /// The most recent month's snapshot (rightmost bar on the chart).
    var currentSnapshot: MIDASMonthSnapshot? { snapshots.last }

    /// True when at least one month contains logged attacks.
    var hasData: Bool { snapshots.contains { $0.score.attacksInWindow > 0 } }

    /// Score change between the two most recent months.
    /// Positive → worsening, negative → improving, nil → insufficient data.
    var trendDelta: Int? {
        guard snapshots.count >= 2 else { return nil }
        let prev = snapshots[snapshots.count - 2].score.totalScore
        let curr = snapshots[snapshots.count - 1].score.totalScore
        return curr == prev ? nil : curr - prev
    }
}

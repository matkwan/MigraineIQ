//
//  MedicationViewModel.swift
//  MigraineIQ
//
//  Drives the medication history list (last 30 days).
//  Loaded once on appear; supports pull-to-refresh and swipe-to-delete.
//

import Foundation
import Observation

@Observable
@MainActor
final class MedicationViewModel {

    enum ViewState {
        case loading
        case loaded([MedicationDose])
        case empty
        case failed(String)
    }

    private(set) var viewState: ViewState = .loading

    private let medicationRepository: MedicationRepositoryProtocol

    init(medicationRepository: MedicationRepositoryProtocol) {
        self.medicationRepository = medicationRepository
    }

    // MARK: - Load

    func load() async {
        viewState = .loading
        let range = Self.last30DaysRange()
        do {
            let doses = try await medicationRepository.doses(in: range)
            viewState = doses.isEmpty ? .empty : .loaded(doses)
        } catch {
            viewState = .failed(ErrorPresenter.userMessage(for: error))
        }
    }

    // MARK: - Delete

    func delete(_ dose: MedicationDose) async {
        try? await medicationRepository.delete(id: dose.id)
        await load()
    }

    // MARK: - Helpers

    private static func last30DaysRange() -> DateInterval {
        let now  = Date()
        let start = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        return DateInterval(start: start, end: now)
    }
}

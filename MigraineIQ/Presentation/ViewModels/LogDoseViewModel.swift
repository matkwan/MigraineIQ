//
//  LogDoseViewModel.swift
//  MigraineIQ
//
//  Drives the "Log a dose" form. Same synchronous-guard + Task pattern
//  used throughout the app (no async on the public save() entry point).
//

import Foundation
import Observation

@Observable
@MainActor
final class LogDoseViewModel {

    enum SaveState: Equatable {
        case ready
        case saving
        case saved
        case deleted
        case failure(String)
    }

    // MARK: - Form fields

    var medicationName: String = ""
    var medicationClass: MedicationClass = .triptan
    var hasDose: Bool = false
    var doseMilligrams: Double = 50
    var purpose: DosePurpose = .acute
    var takenAt: Date = Date()
    var notes: String = ""

    // MARK: - State

    private(set) var saveState: SaveState = .ready

    /// Top medication names from the last 90 days, ordered by frequency.
    /// Populated asynchronously by loadRecentNames().
    private(set) var recentNames: [String] = []

    /// recentNames filtered against the current medicationName entry.
    var availableNameSuggestions: [String] {
        let typed = medicationName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return recentNames.filter { !$0.lowercased().hasPrefix(typed) || typed.isEmpty }
    }

    var canSave: Bool {
        !medicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Private

    private let medicationRepository: MedicationRepositoryProtocol
    /// Non-nil when editing an existing dose — preserves the original UUID on save.
    private let existingID: UUID?

    /// `true` when this ViewModel was initialised with an existing dose to edit.
    let isEditing: Bool

    // MARK: - Init

    /// Create a blank "Log dose" form.
    init(medicationRepository: MedicationRepositoryProtocol) {
        self.medicationRepository = medicationRepository
        self.existingID = nil
        self.isEditing  = false
    }

    /// Create a pre-populated "Edit dose" form.
    init(editing dose: MedicationDose, medicationRepository: MedicationRepositoryProtocol) {
        self.medicationRepository = medicationRepository
        self.existingID   = dose.id
        self.isEditing    = true
        self.medicationName    = dose.medicationName
        self.medicationClass   = dose.medicationClass
        self.hasDose           = dose.doseMilligrams != nil
        self.doseMilligrams    = dose.doseMilligrams ?? 50
        self.purpose           = dose.purpose
        self.takenAt           = dose.takenAt
        self.notes             = dose.notes
    }

    // MARK: - Actions

    func save() {
        guard saveState == .ready, canSave else { return }
        saveState = .saving

        // Preserve the original UUID when editing so the upsert updates
        // the existing record rather than inserting a duplicate.
        let dose = MedicationDose(
            id: existingID ?? UUID(),
            takenAt: takenAt,
            medicationName: medicationName.trimmingCharacters(in: .whitespacesAndNewlines),
            medicationClass: medicationClass,
            doseMilligrams: hasDose ? doseMilligrams : nil,
            purpose: purpose,
            notes: notes
        )

        Task {
            do {
                try await medicationRepository.logDose(dose)
                await checkMOHAndNotify()
                saveState = .saved
            } catch {
                saveState = .failure(ErrorPresenter.userMessage(for: error))
            }
        }
    }

    func clearError() {
        if case .failure = saveState { saveState = .ready }
    }

    /// Hard-deletes this dose. Only valid when `isEditing` is true.
    func delete() {
        guard isEditing, let id = existingID, saveState == .ready else { return }
        saveState = .saving
        Task {
            do {
                try await medicationRepository.delete(id: id)
                await checkMOHAndNotify()
                saveState = .deleted
            } catch {
                saveState = .failure(ErrorPresenter.userMessage(for: error))
            }
        }
    }

    // MARK: - MOH notification check

    /// Recomputes the MOH risk after any dose mutation and fires a
    /// Time Sensitive notification if the level has escalated.
    private func checkMOHAndNotify() async {
        let useCase = AssessMOHRiskUseCase(medicationRepository: medicationRepository)
        guard let assessment = try? await useCase.execute() else { return }
        await NotificationService.shared.scheduleMOHWarningIfNeeded(for: assessment)
    }

    /// Fetches up to 5 most-used medication names from the last 90 days.
    func loadRecentNames() async {
        let now   = Date()
        let start = Calendar.current.date(byAdding: .day, value: -90, to: now) ?? now
        let range = DateInterval(start: start, end: now)
        guard let doses = try? await medicationRepository.doses(in: range) else { return }

        var counts: [String: Int] = [:]
        for dose in doses {
            let key = dose.medicationName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            counts[key, default: 0] += 1
        }

        recentNames = counts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map(\.key)
    }
}

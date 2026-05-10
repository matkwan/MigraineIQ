//
//  HeadacheDetailViewModel.swift
//  MigraineIQ
//
//  Drives the full HeadacheDetail editing form. Initialised from an existing
//  HeadacheEvent (typically one just created by QuickLog) and writes the
//  updated event back to the repository when the user taps Accept.
//

import Foundation
import Observation

@Observable
@MainActor
final class HeadacheDetailViewModel {

    // MARK: - Save state

    enum SaveState: Equatable {
        case ready
        case saving
        case saved
        case deleted
        case failure(String)
    }

    private(set) var saveState: SaveState = .ready

    // MARK: - Form fields (all pre-populated from the source event)

    var intensity: Int
    var classification: ICHD3Classification
    var painLocations: Set<PainLocation>
    var painQuality: Set<PainQuality>
    var symptoms: Set<Symptom>

    // Aura
    var hasAura: Bool
    var auraTypes: Set<AuraType>
    var auraDurationMinutes: Int                    // 0 = not recorded
    var auraVisualDisturbances: Set<VisualDisturbance>
    var auraSensoryLocations: Set<SensoryLocation>

    // Triggers (free-text, comma-separated; parsed to Set<String> on save)
    var triggerText: String

    // Notes
    var notes: String

    // Disability impact
    var missedWorkHours: Double
    var reducedProductivityHours: Double
    var bedRestHours: Double

    // MARK: - Private

    private let source: HeadacheEvent
    private let headacheRepository: HeadacheRepositoryProtocol

    // MARK: - Init

    init(event: HeadacheEvent, headacheRepository: HeadacheRepositoryProtocol) {
        self.source             = event
        self.headacheRepository = headacheRepository
        self.intensity          = event.intensity
        self.classification     = event.classification
        self.painLocations      = event.painLocations
        self.painQuality        = event.painQuality
        self.symptoms           = event.symptoms
        self.hasAura                   = event.aura != nil
        self.auraTypes                 = event.aura?.types ?? []
        self.auraDurationMinutes       = event.aura?.durationMinutes ?? 0
        self.auraVisualDisturbances    = event.aura?.visualDisturbances ?? []
        self.auraSensoryLocations      = event.aura?.sensoryLocations ?? []
        self.triggerText        = event.triggersSuspected.sorted().joined(separator: ", ")
        self.notes              = event.notes
        self.missedWorkHours         = event.disabilityImpact.missedWorkHours
        self.reducedProductivityHours = event.disabilityImpact.reducedProductivityHours
        self.bedRestHours            = event.disabilityImpact.bedRestHours
    }

    // MARK: - Actions

    /// Persists all edited fields back to the repository.
    func save() {
        guard saveState == .ready else { return }
        saveState = .saving

        var updated = source
        updated.intensity      = intensity
        updated.classification = classification
        updated.painLocations  = painLocations
        updated.painQuality    = painQuality
        updated.symptoms       = symptoms

        if hasAura {
            var aura = source.aura ?? AuraEvent()
            aura.types                = auraTypes
            aura.durationMinutes      = auraDurationMinutes
            aura.visualDisturbances   = auraVisualDisturbances
            aura.sensoryLocations     = auraSensoryLocations
            updated.aura = aura
        } else {
            updated.aura = nil
        }

        updated.triggersSuspected = parsedTriggers
        updated.notes             = notes
        updated.disabilityImpact  = DisabilityImpact(
            missedWorkHours: missedWorkHours,
            reducedProductivityHours: reducedProductivityHours,
            bedRestHours: bedRestHours
        )

        Task {
            do {
                try await headacheRepository.save(updated)
                // Editing an attack changes the risk inputs — invalidate the
                // cached forecast so Dashboard recalculates on next visit.
                DashboardViewModel.invalidateRiskCache()
                saveState = .saved
            } catch {
                saveState = .failure(ErrorPresenter.userMessage(for: error))
            }
        }
    }

    func clearSaveError() {
        if case .failure = saveState { saveState = .ready }
    }

    /// Hard-deletes this attack from the repository and invalidates the risk cache.
    func delete() {
        guard saveState == .ready else { return }
        saveState = .saving
        Task {
            do {
                try await headacheRepository.delete(id: source.id)
                DashboardViewModel.invalidateRiskCache()
                saveState = .deleted
            } catch {
                saveState = .failure(ErrorPresenter.userMessage(for: error))
            }
        }
    }

    // MARK: - Helpers

    /// True when the aura mapper has been filled in with at least one detail.
    var auraHasDetails: Bool {
        !auraTypes.isEmpty || !auraVisualDisturbances.isEmpty || !auraSensoryLocations.isEmpty
    }

    var parsedTriggers: Set<String> {
        Set(
            triggerText
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    // MARK: - Copy from last attack

    /// The most recent attack other than the one being edited.
    /// nil until loadLastAttack() completes (or if no prior attack exists).
    private(set) var lastAttack: HeadacheEvent? = nil

    var canCopyFromLast: Bool { lastAttack != nil }

    /// Fetches the most recent prior attack. Call once from the view's .task modifier.
    func loadLastAttack() async {
        guard let events = try? await headacheRepository.fetchRecent(limit: 2) else { return }
        lastAttack = events.first(where: { $0.id != source.id })
    }

    /// Overwrites all clinical-profile fields with the last attack's values.
    /// Notes and disability hours are intentionally excluded — those are
    /// specific to how each attack played out, not to the person's profile.
    func copyFromLastAttack() {
        guard let last = lastAttack else { return }
        intensity      = last.intensity
        classification = last.classification
        painLocations  = last.painLocations
        painQuality    = last.painQuality
        symptoms       = last.symptoms
        hasAura                = last.aura != nil
        auraTypes              = last.aura?.types ?? []
        auraDurationMinutes    = last.aura?.durationMinutes ?? 0
        auraVisualDisturbances = last.aura?.visualDisturbances ?? []
        auraSensoryLocations   = last.aura?.sensoryLocations ?? []
        triggerText    = last.triggersSuspected.sorted().joined(separator: ", ")
    }

    // MARK: - Trigger suggestions

    /// Top triggers from recent history, excluding ones already entered.
    /// Populated asynchronously by loadSuggestions().
    private(set) var suggestedTriggers: [String] = []

    /// suggestedTriggers filtered against the current triggerText entry.
    var availableSuggestions: [String] {
        let entered = parsedTriggers.map { $0.lowercased() }
        return suggestedTriggers.filter { !entered.contains($0.lowercased()) }
    }

    /// Appends a tapped suggestion to triggerText (comma-separated).
    func addSuggestion(_ trigger: String) {
        let trimmed = triggerText.trimmingCharacters(in: .whitespacesAndNewlines)
        triggerText = trimmed.isEmpty ? trigger : trimmed + ", " + trigger
    }

    /// Fetches the 30 most recent events and builds a ranked list of the
    /// top 5 triggers by frequency. Call once from the view's .task modifier.
    func loadSuggestions() async {
        guard let events = try? await headacheRepository.fetchRecent(limit: 30) else { return }

        var counts: [String: Int] = [:]
        for event in events where event.id != source.id {
            for trigger in event.triggersSuspected {
                let key = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty else { continue }
                counts[key, default: 0] += 1
            }
        }

        suggestedTriggers = counts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map(\.key)
    }
}

//
//  HeadacheEvent.swift
//  MigraineIQ
//
//  The core entity. Every recorded attack — from a 1-tap quick log to a
//  fully classified migraine with aura — is a HeadacheEvent.
//
//  Domain rules:
//   - Pure value type (struct), no UI, no persistence concerns.
//   - All fields are var so the user can edit retrospectively (e.g. mark
//     intensity, add aura details after the attack ends).
//   - `endedAt == nil` means the attack is currently ongoing.
//

import Foundation

struct HeadacheEvent: Identifiable, Codable, Hashable {
    let id: UUID
    var startedAt: Date
    var endedAt: Date?
    var intensity: Int                       // NRS 0-10
    var painLocations: Set<PainLocation>
    var painQuality: Set<PainQuality>
    var classification: ICHD3Classification
    var aura: AuraEvent?
    var phase: AttackPhase
    var symptoms: Set<Symptom>
    /// Free-text triggers the user suspects. The AI builds a separate
    /// confidence-scored model in `TriggerInsight`.
    var triggersSuspected: Set<String>
    /// IDs of MedicationDose records taken to treat this attack.
    var medicationsTaken: [UUID]
    var disabilityImpact: DisabilityImpact
    var notes: String

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        intensity: Int = 0,
        painLocations: Set<PainLocation> = [],
        painQuality: Set<PainQuality> = [],
        classification: ICHD3Classification = .undetermined,
        aura: AuraEvent? = nil,
        phase: AttackPhase = .headache,
        symptoms: Set<Symptom> = [],
        triggersSuspected: Set<String> = [],
        medicationsTaken: [UUID] = [],
        disabilityImpact: DisabilityImpact = .none,
        notes: String = ""
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.intensity = max(ClinicalConstants.Pain.nrsRange.lowerBound,
                             min(ClinicalConstants.Pain.nrsRange.upperBound, intensity))
        self.painLocations = painLocations
        self.painQuality = painQuality
        self.classification = classification
        self.aura = aura
        self.phase = phase
        self.symptoms = symptoms
        self.triggersSuspected = triggersSuspected
        self.medicationsTaken = medicationsTaken
        self.disabilityImpact = disabilityImpact
        self.notes = notes
    }

    // MARK: - Computed properties ----------------------------------------

    /// Duration in hours, or nil if the attack is ongoing.
    var durationHours: Double? {
        guard let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt) / 3600
    }

    var isOngoing: Bool { endedAt == nil }

    /// Whether this event counts toward chronic-migraine criteria
    /// (15+ headache days/month, 8+ migraine days/month).
    var countsAsMigraineDay: Bool { classification.countsAsMigraineDay }
}

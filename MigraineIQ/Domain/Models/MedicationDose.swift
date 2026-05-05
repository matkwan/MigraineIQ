//
//  MedicationDose.swift
//  MigraineIQ
//
//  A single medication intake event. The MOH Guardian (Phase 3) sums these
//  by class over a rolling 30-day window.
//

import Foundation

struct MedicationDose: Identifiable, Codable, Hashable {
    let id: UUID
    var takenAt: Date
    var medicationName: String          // user-readable, e.g. "Sumatriptan 50mg"
    var medicationClass: MedicationClass
    var doseMilligrams: Double?
    var purpose: DosePurpose
    /// If this dose was taken specifically to treat a logged attack.
    var headacheEventID: UUID?
    var notes: String

    init(
        id: UUID = UUID(),
        takenAt: Date = Date(),
        medicationName: String,
        medicationClass: MedicationClass,
        doseMilligrams: Double? = nil,
        purpose: DosePurpose = .acute,
        headacheEventID: UUID? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.takenAt = takenAt
        self.medicationName = medicationName
        self.medicationClass = medicationClass
        self.doseMilligrams = doseMilligrams
        self.purpose = purpose
        self.headacheEventID = headacheEventID
        self.notes = notes
    }
}

/// The MOH-relevant categorisation. Determines which monthly threshold
/// applies in `AssessMOHRiskUseCase`.
enum MedicationClass: String, Codable, CaseIterable, Hashable, Identifiable {
    // Acute treatment
    case triptan                 // sumatriptan, rizatriptan, etc — 10 day MOH
    case ergot                   // ergotamine, dihydroergotamine     — 10 day MOH
    case opioid                  // codeine, tramadol                 — 10 day MOH
    case combinationAnalgesic    // Excedrin etc                      — 10 day MOH
    case nsaid                   // ibuprofen, naproxen               — 15 day MOH
    case simpleAnalgesic         // paracetamol/acetaminophen         — 15 day MOH

    // CGRP era
    case cgrpAcute               // ubrogepant, rimegepant (gepants)  — no MOH risk
    case cgrpPreventive          // erenumab, fremanezumab, etc       — preventive

    // Other preventive
    case betaBlocker             // propranolol etc
    case anticonvulsant          // topiramate, valproate
    case antidepressant          // amitriptyline, venlafaxine
    case botox                   // onabotulinumtoxinA (Botox)

    // Catch-all
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .triptan:              return "Triptan"
        case .ergot:                return "Ergot"
        case .opioid:               return "Opioid"
        case .combinationAnalgesic: return "Combination analgesic"
        case .nsaid:                return "NSAID"
        case .simpleAnalgesic:      return "Simple analgesic"
        case .cgrpAcute:            return "CGRP (acute) — gepant"
        case .cgrpPreventive:       return "CGRP (preventive)"
        case .betaBlocker:          return "Beta blocker"
        case .anticonvulsant:       return "Anticonvulsant"
        case .antidepressant:       return "Antidepressant (preventive)"
        case .botox:                return "Botox"
        case .other:                return "Other"
        }
    }

    /// Days/month threshold at which sustained use risks MOH per ICHD-3 8.2.
    /// Returns nil for medications that are not MOH-causing.
    var mohThresholdDays: Int? {
        switch self {
        case .triptan, .ergot, .opioid, .combinationAnalgesic:
            return ClinicalConstants.MOH.acuteThresholdDays
        case .nsaid, .simpleAnalgesic:
            return ClinicalConstants.MOH.analgesicThresholdDays
        default:
            return nil
        }
    }

    var isMOHCausing: Bool { mohThresholdDays != nil }
}

enum DosePurpose: String, Codable, CaseIterable, Hashable {
    case acute       // taken to treat an active attack
    case preventive  // scheduled prophylaxis
    case rescue      // taken as last-resort when acute didn't work
}

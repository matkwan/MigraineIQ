//
//  PainCharacteristics.swift
//  MigraineIQ
//
//  Enums describing where and how a headache hurts. Maps to ICHD-3
//  diagnostic criteria for laterality (unilateral/bilateral), quality
//  (pulsating, pressing), and aggravation by routine activity.
//

import Foundation

enum PainLocation: String, Codable, CaseIterable, Hashable, Identifiable {
    case unilateralLeft
    case unilateralRight
    case bilateral
    case frontal
    case temporal
    case occipital
    case periorbital     // around the eye — common in cluster
    case nuchal          // back of neck

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unilateralLeft:  return "Left side"
        case .unilateralRight: return "Right side"
        case .bilateral:       return "Both sides"
        case .frontal:         return "Forehead"
        case .temporal:        return "Temple"
        case .occipital:       return "Back of head"
        case .periorbital:     return "Around eye"
        case .nuchal:          return "Back of neck"
        }
    }
}

enum PainQuality: String, Codable, CaseIterable, Hashable, Identifiable {
    case throbbing       // pulsating — typical migraine
    case pressing        // band-like — typical tension
    case stabbing        // sharp, brief — cluster / SUNCT
    case burning
    case dull

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .throbbing: return "Throbbing / pulsating"
        case .pressing:  return "Pressing / tightening"
        case .stabbing:  return "Sharp / stabbing"
        case .burning:   return "Burning"
        case .dull:      return "Dull ache"
        }
    }
}

enum Symptom: String, Codable, CaseIterable, Hashable, Identifiable {
    // Migraine-associated
    case photophobia        // light sensitivity
    case phonophobia        // sound sensitivity
    case osmophobia         // smell sensitivity
    case nausea
    case vomiting
    case allodynia          // skin sensitivity (combing hair hurts)

    // Cluster / TAC autonomic
    case lacrimation        // tearing
    case rhinorrhea         // runny nose
    case ptosis             // drooping eyelid
    case miosis             // small pupil
    case eyelidEdema

    // General
    case dizziness
    case neckStiffness
    case fatigue

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .photophobia:     return "Light sensitivity"
        case .phonophobia:     return "Sound sensitivity"
        case .osmophobia:      return "Smell sensitivity"
        case .nausea:          return "Nausea"
        case .vomiting:        return "Vomiting"
        case .allodynia:       return "Skin/scalp sensitivity"
        case .lacrimation:     return "Tearing"
        case .rhinorrhea:      return "Runny nose"
        case .ptosis:          return "Drooping eyelid"
        case .miosis:          return "Small pupil"
        case .eyelidEdema:     return "Eyelid swelling"
        case .dizziness:       return "Dizziness"
        case .neckStiffness:   return "Neck stiffness"
        case .fatigue:         return "Fatigue"
        }
    }
}

enum AttackPhase: String, Codable, CaseIterable, Hashable {
    case prodrome   // hours-days before headache (mood, fatigue, food cravings)
    case aura       // 5-60 min, neurological symptoms
    case headache   // the painful phase itself
    case postdrome  // hours-days after, brain fog
    case resolved
}

struct DisabilityImpact: Codable, Hashable {
    /// Hours of work / school missed entirely.
    var missedWorkHours: Double
    /// Hours where work continued but at reduced productivity.
    var reducedProductivityHours: Double
    /// Hours spent in bed or otherwise unable to function.
    var bedRestHours: Double

    static let none = DisabilityImpact(
        missedWorkHours: 0,
        reducedProductivityHours: 0,
        bedRestHours: 0
    )
}

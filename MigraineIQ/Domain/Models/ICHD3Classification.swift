//
//  ICHD3Classification.swift
//  MigraineIQ
//
//  ICHD-3 (International Classification of Headache Disorders, 3rd ed.)
//  primary headache types relevant to a journaling app. We capture the
//  major branches users will most often log; the AI classifier in later
//  phases will refine to specific sub-codes (1.1.1, 1.2.1, etc).
//
//  Source: https://ichd-3.org
//

import Foundation

enum ICHD3Classification: String, Codable, CaseIterable, Hashable, Identifiable {
    // 1. Migraine
    case migraineWithoutAura     // 1.1
    case migraineWithAura        // 1.2
    case chronicMigraine         // 1.3
    case migraineComplications   // 1.4 (status migrainosus, etc.)

    // 2. Tension-type headache
    case tensionTypeEpisodic     // 2.1 / 2.2
    case tensionTypeChronic      // 2.3

    // 3. Trigeminal autonomic cephalalgias
    case clusterHeadache         // 3.1
    case otherTAC                // 3.2–3.5

    // 4. Other primary headaches
    case otherPrimary            // 4.x

    // Secondary / unclassified
    case secondary               // 5–14 (post-traumatic, infection, etc.)
    case undetermined

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .migraineWithoutAura:   return "Migraine without aura"
        case .migraineWithAura:      return "Migraine with aura"
        case .chronicMigraine:       return "Chronic migraine"
        case .migraineComplications: return "Migraine complication"
        case .tensionTypeEpisodic:   return "Tension-type (episodic)"
        case .tensionTypeChronic:    return "Tension-type (chronic)"
        case .clusterHeadache:       return "Cluster headache"
        case .otherTAC:              return "Other TAC"
        case .otherPrimary:          return "Other primary"
        case .secondary:             return "Secondary headache"
        case .undetermined:          return "Not yet classified"
        }
    }

    var ichd3Code: String {
        switch self {
        case .migraineWithoutAura:   return "1.1"
        case .migraineWithAura:      return "1.2"
        case .chronicMigraine:       return "1.3"
        case .migraineComplications: return "1.4"
        case .tensionTypeEpisodic:   return "2.1/2.2"
        case .tensionTypeChronic:    return "2.3"
        case .clusterHeadache:       return "3.1"
        case .otherTAC:              return "3.x"
        case .otherPrimary:          return "4.x"
        case .secondary:             return "5–14"
        case .undetermined:          return "—"
        }
    }

    /// Whether this entry counts toward the "migraine days/month" tally for
    /// chronic-migraine criteria and insurance coverage triggers.
    var countsAsMigraineDay: Bool {
        switch self {
        case .migraineWithoutAura, .migraineWithAura,
             .chronicMigraine, .migraineComplications:
            return true
        default:
            return false
        }
    }
}

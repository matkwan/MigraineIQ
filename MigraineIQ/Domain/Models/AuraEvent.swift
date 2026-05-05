//
//  AuraEvent.swift
//  MigraineIQ
//
//  Aura is the neurological prodrome to migraine — visual, sensory,
//  language, motor, brainstem, or retinal disturbances lasting 5–60 min.
//  Required for ICHD-3 1.2 (Migraine with aura) classification.
//

import Foundation

struct AuraEvent: Identifiable, Codable, Hashable {
    let id: UUID
    var startedAt: Date
    var durationMinutes: Int
    var types: Set<AuraType>
    var visualDisturbances: Set<VisualDisturbance>
    var sensoryLocations: Set<SensoryLocation>
    var notes: String

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        durationMinutes: Int = 0,
        types: Set<AuraType> = [],
        visualDisturbances: Set<VisualDisturbance> = [],
        sensoryLocations: Set<SensoryLocation> = [],
        notes: String = ""
    ) {
        self.id = id
        self.startedAt = startedAt
        self.durationMinutes = durationMinutes
        self.types = types
        self.visualDisturbances = visualDisturbances
        self.sensoryLocations = sensoryLocations
        self.notes = notes
    }
}

enum AuraType: String, Codable, CaseIterable, Hashable, Identifiable {
    case visual         // most common (~90% of aura)
    case sensory        // tingling, numbness — usually in face/arm
    case language       // dysphasia, word-finding difficulty
    case motor          // hemiplegic migraine — rare, requires specialist
    case brainstem      // basilar — vertigo, double vision, ataxia
    case retinal        // monocular visual loss

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .visual:    return "Visual"
        case .sensory:   return "Sensory (tingling)"
        case .language:  return "Language difficulty"
        case .motor:     return "Motor weakness"
        case .brainstem: return "Brainstem"
        case .retinal:   return "Retinal (one eye)"
        }
    }
}

enum VisualDisturbance: String, Codable, CaseIterable, Hashable, Identifiable {
    case scintillatingScotoma   // shimmering blind spot
    case fortificationSpectrum  // zigzag lines (classic migraine aura)
    case blurredVision
    case visualFieldLoss
    case flashingLights
    case tunnel
    case kaleidoscope

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .scintillatingScotoma:  return "Shimmering blind spot"
        case .fortificationSpectrum: return "Zigzag lines"
        case .blurredVision:         return "Blurred vision"
        case .visualFieldLoss:       return "Loss of visual field"
        case .flashingLights:        return "Flashing lights"
        case .tunnel:                return "Tunnel vision"
        case .kaleidoscope:          return "Kaleidoscope effect"
        }
    }
}

enum SensoryLocation: String, Codable, CaseIterable, Hashable, Identifiable {
    case faceLeft, faceRight
    case armLeft, armRight
    case legLeft, legRight
    case lipsTongue

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .faceLeft:    return "Face (left)"
        case .faceRight:   return "Face (right)"
        case .armLeft:     return "Arm (left)"
        case .armRight:    return "Arm (right)"
        case .legLeft:     return "Leg (left)"
        case .legRight:    return "Leg (right)"
        case .lipsTongue:  return "Lips / tongue"
        }
    }
}

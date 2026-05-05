//
//  AIProxyDTOs.swift
//  MigraineIQ
//
//  Wire-format types exchanged with the Cloudflare Worker proxy. These
//  exist so the API shape can change without forcing changes in the Domain
//  layer. Phase 2 adds toDomain() / fromDomain() mappers between these and
//  the Domain Models.
//

import Foundation

struct HeadacheEventDTO: Codable {
    let id: String
    let startedAt: Date
    let endedAt: Date?
    let intensity: Int
    let classification: String
    let symptoms: [String]
    let triggersSuspected: [String]
}

struct HealthContextDTO: Codable {
    let sleep: [DailyValue]
    let hrv: [DailyValue]
    let weather: [WeatherDTO]
    let cycle: [CycleDTO]
    let foodTags: [FoodDTO]

    struct DailyValue: Codable { let date: Date; let value: Double }
    struct WeatherDTO: Codable {
        let date: Date
        let pressureHPa: Double
        let pressureDeltaHPa: Double
        let humidity: Double
        let tempC: Double
    }
    struct CycleDTO: Codable { let date: Date; let phase: String }
    struct FoodDTO: Codable { let date: Date; let tags: [String] }
}

struct TriggerInsightDTO: Codable {
    let trigger: String
    let confidence: Double
    let occurrenceCount: Int
    let strengthBand: String
    let explanation: String
}

struct PredictionContextDTO: Codable {
    let knownTriggers: [TriggerInsightDTO]
    let recentAttacks: [HeadacheEventDTO]
    let currentContext: Current

    struct Current: Codable {
        let lastNightSleepHours: Double
        let lastNightHRVms: Double
        let cyclePhase: String
        let pressureForecast: [PressurePoint]
        let pressureDelta24hHPa: Double
    }
    struct PressurePoint: Codable { let hourOffset: Int; let pressureHPa: Double }
}

struct PredictiveAlertDTO: Codable {
    let riskLevel: String
    let riskScore: Int
    let primaryFactors: [String]
    let recommendedAction: String
    let expiresAtISO: String
}

struct CoachContextDTO: Codable {
    let attacks: [HeadacheEventDTO]
    let doses: [DoseDTO]
    let sleep: [HealthContextDTO.DailyValue]
    let weather: [HealthContextDTO.WeatherDTO]
    let cycle: CyclePhaseSnapshot
    let foodTags: [HealthContextDTO.FoodDTO]

    struct DoseDTO: Codable { let date: Date; let medicationClass: String; let name: String }
    struct CyclePhaseSnapshot: Codable { let phase: String; let day: Int }
}

struct CoachMessageDTO: Codable {
    let role: String   // "user" | "assistant"
    let content: String
}

//
//  AIInsightsDTOMapperTests.swift
//  MigraineIQTests
//
//  Verifies the DTO ↔ Domain mappers defined in AIInsightsRepository.swift.
//  Tests both directions where a round-trip is possible, and one-way
//  (DTO → Domain) for server-response types like PredictiveAlertDTO.
//

import Testing
import Foundation
@testable import MigraineIQ

@Suite("AIInsights DTO mapper")
struct AIInsightsDTOMapperTests {

    // MARK: - TriggerInsight round-trip ------------------------------------

    @Test("TriggerInsight → DTO → Domain preserves all fields")
    func triggerInsightRoundTrip() {
        let original = TriggerInsight(
            trigger: "Poor sleep",
            confidence: 0.82,
            occurrenceCount: 11,
            lastObserved: Date(timeIntervalSince1970: 1_700_000_000),
            strengthBand: .strong,
            explanation: "Short sleep preceded 11 of 14 attacks."
        )

        let dto = original.toDTO()
        let restored = dto.toDomain()

        #expect(restored.trigger == original.trigger)
        #expect(restored.confidence == original.confidence)
        #expect(restored.occurrenceCount == original.occurrenceCount)
        #expect(restored.strengthBand == original.strengthBand)
        #expect(restored.explanation == original.explanation)
    }

    @Test("TriggerInsightDTO falls back to confidence-derived band when rawValue is unrecognised")
    func triggerInsightUnknownBandFallback() {
        let dto = TriggerInsightDTO(
            trigger: "Stress",
            confidence: 0.71,
            occurrenceCount: 5,
            strengthBand: "super_strong", // unrecognised value from future API version
            explanation: ""
        )

        let domain = dto.toDomain()
        // confidence 0.71 → .strong via TriggerInsight.StrengthBand.from(confidence:)
        #expect(domain.strengthBand == .strong)
    }

    // MARK: - HeadacheEvent → DTO ------------------------------------------

    @Test("HeadacheEvent.toAIDTO maps id, intensity, classification, symptoms")
    func headacheEventToDTO() {
        let event = HeadacheEvent.mockResolvedYesterday
        let dto = event.toAIDTO()

        #expect(dto.id == event.id.uuidString)
        #expect(dto.intensity == event.intensity)
        #expect(dto.classification == event.classification.rawValue)
        #expect(Set(dto.symptoms) == Set(event.symptoms.map(\.rawValue)))
        #expect(dto.endedAt == event.endedAt)
    }

    // MARK: - PredictiveAlertDTO → Domain ----------------------------------

    @Test("PredictiveAlertDTO.toDomain maps riskLevel, riskScore, factors, action")
    func predictiveAlertDTOToDomain() {
        let iso = ISO8601DateFormatter()
        let expiry = Date().addingTimeInterval(86400)

        let dto = PredictiveAlertDTO(
            riskLevel: "elevated",
            riskScore: 63,
            primaryFactors: ["Poor sleep", "Pressure drop"],
            recommendedAction: "Keep rescue meds close.",
            expiresAtISO: iso.string(from: expiry)
        )

        let alert = dto.toDomain()

        #expect(alert.riskLevel == .elevated)
        #expect(alert.riskScore == 63)
        #expect(alert.primaryFactors == ["Poor sleep", "Pressure drop"])
        #expect(alert.recommendedAction == "Keep rescue meds close.")
        // Allow 2-second tolerance for ISO round-trip
        #expect(abs(alert.expiresAt.timeIntervalSince(expiry)) < 2)
    }

    @Test("PredictiveAlertDTO falls back to score-derived riskLevel for unrecognised string")
    func predictiveAlertUnknownLevelFallback() {
        let dto = PredictiveAlertDTO(
            riskLevel: "very_high", // unrecognised
            riskScore: 80,
            primaryFactors: [],
            recommendedAction: "",
            expiresAtISO: ISO8601DateFormatter().string(from: Date())
        )

        let alert = dto.toDomain()
        // score 80 → .high via PredictiveAlert.RiskLevel.from(score:)
        #expect(alert.riskLevel == .high)
    }

    // MARK: - CoachMessage → DTO -------------------------------------------

    @Test("CoachMessage.toDTO preserves role rawValue and content")
    func coachMessageToDTO() {
        let message = CoachMessage(role: .user, content: "Why did I get a migraine?")
        let dto = message.toDTO()

        #expect(dto.role == "user")
        #expect(dto.content == message.content)
    }

    // MARK: - HealthContext → DTO ------------------------------------------

    @Test("HealthContext.toDTO maps sleep and hrv hours/ms correctly")
    func healthContextToDTO() {
        let context = HealthContext.mockHighRisk
        let dto = context.toDTO()

        #expect(dto.sleep.count == context.sleep.count)
        #expect(dto.hrv.count == context.hrv.count)
        #expect(dto.weather.count == context.weather.count)
        #expect(dto.cycle.count == context.cycle.count)

        if let firstSleep = context.sleep.first, let dtoSleep = dto.sleep.first {
            #expect(dtoSleep.value == firstSleep.hoursSlept)
        }
    }

    @Test("HealthContext.toDTO collapses flat foodTags into a single FoodDTO entry")
    func healthContextFoodTagsCollapsed() {
        let context = HealthContext(foodTags: ["red wine", "aged cheese"])
        let dto = context.toDTO()

        #expect(dto.foodTags.count == 1)
        #expect(dto.foodTags.first?.tags == ["red wine", "aged cheese"])
    }

    @Test("HealthContext.toDTO produces empty foodTags array when domain list is empty")
    func healthContextEmptyFoodTags() {
        let dto = HealthContext.empty.toDTO()
        #expect(dto.foodTags.isEmpty)
    }
}

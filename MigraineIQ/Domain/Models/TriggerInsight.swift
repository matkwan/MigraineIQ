//
//  TriggerInsight.swift
//  MigraineIQ
//
//  AI-generated, confidence-scored personal trigger assessment.
//  Produced by AnalyzePersonalTriggersUseCase via AIInsightsRepositoryProtocol.
//
//  confidence: 0.0 (no evidence) → 1.0 (near-certain association).
//  strengthBand: human-readable bucketing of confidence for display.
//

import Foundation

struct TriggerInsight: Identifiable, Codable, Hashable {
    let id: UUID
    /// The trigger label (e.g. "Poor sleep", "Barometric pressure drop").
    var trigger: String
    /// Confidence score 0.0–1.0 from the AI model.
    var confidence: Double
    /// How many logged attacks showed this trigger in the analysis window.
    var occurrenceCount: Int
    /// Date of the most recent attack in which this trigger was observed.
    var lastObserved: Date
    var strengthBand: StrengthBand
    /// Plain-language explanation from the AI (1-2 sentences).
    var explanation: String

    init(
        id: UUID = UUID(),
        trigger: String,
        confidence: Double,
        occurrenceCount: Int,
        lastObserved: Date = Date(),
        strengthBand: StrengthBand,
        explanation: String = ""
    ) {
        self.id = id
        self.trigger = trigger
        self.confidence = confidence.clamped(to: 0...1)
        self.occurrenceCount = max(0, occurrenceCount)
        self.lastObserved = lastObserved
        self.strengthBand = strengthBand
        self.explanation = explanation
    }

    // MARK: - Nested types

    enum StrengthBand: String, Codable, CaseIterable, Hashable {
        case weak      // confidence < 0.4
        case moderate  // 0.4 – 0.69
        case strong    // ≥ 0.7
    }
}

// MARK: - StrengthBand convenience

extension TriggerInsight.StrengthBand {
    /// Derives the band from a raw confidence value (mirrors the AI worker's
    /// bucketing so the UI can reconstruct it if the API omits the field).
    static func from(confidence: Double) -> Self {
        switch confidence {
        case ..<0.4:  return .weak
        case ..<0.7:  return .moderate
        default:      return .strong
        }
    }
}

// MARK: - Double clamping helper (Foundation-only, no Darwin import needed)

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

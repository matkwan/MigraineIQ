//
//  PredictiveAlert.swift
//  MigraineIQ
//
//  A 24-hour migraine risk forecast produced by PredictMigraineRiskUseCase.
//  The AI composes sleep quality, barometric trend, cycle phase, and recent
//  attack history into a single probabilistic estimate.
//
//  riskScore: 0 (no risk) → 100 (near-certain).
//  primaryFactors: ordered list of the factors that drove the score, most
//    significant first. Shown directly in the Dashboard risk card.
//

import Foundation

struct PredictiveAlert: Identifiable, Codable, Hashable {
    let id: UUID
    var riskLevel: RiskLevel
    /// Integer 0–100 for easy display (e.g. "73% risk").
    var riskScore: Int
    /// Top contributing factors, most significant first.
    var primaryFactors: [String]
    /// Actionable recommendation (1 sentence, clinically safe language).
    var recommendedAction: String
    /// When this forecast expires and should be recomputed.
    var expiresAt: Date

    init(
        id: UUID = UUID(),
        riskLevel: RiskLevel,
        riskScore: Int,
        primaryFactors: [String] = [],
        recommendedAction: String = "",
        expiresAt: Date = Date().addingTimeInterval(86400)
    ) {
        self.id = id
        self.riskLevel = riskLevel
        self.riskScore = Swift.min(100, Swift.max(0, riskScore))
        self.primaryFactors = primaryFactors
        self.recommendedAction = recommendedAction
        self.expiresAt = expiresAt
    }

    // MARK: - Nested types

    enum RiskLevel: String, Codable, CaseIterable, Hashable {
        case low       // riskScore < 25
        case moderate  // 25 – 49
        case elevated  // 50 – 74
        case high      // ≥ 75
    }

    // MARK: - Computed

    var isExpired: Bool { Date() >= expiresAt }
}

// MARK: - RiskLevel convenience

extension PredictiveAlert.RiskLevel {
    /// Derives the level from a raw risk score.
    static func from(score: Int) -> Self {
        switch score {
        case ..<25: return .low
        case ..<50: return .moderate
        case ..<75: return .elevated
        default:    return .high
        }
    }
}

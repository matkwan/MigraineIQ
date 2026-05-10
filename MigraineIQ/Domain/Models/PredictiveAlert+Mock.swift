//
//  PredictiveAlert+Mock.swift
//  MigraineIQ
//
//  Static mock data for SwiftUI previews and unit tests.
//  Never use these in production code paths.
//

import Foundation

#if DEBUG
extension PredictiveAlert {

    static let mockLowRisk = PredictiveAlert(
        riskLevel: .low,
        riskScore: 12,
        primaryFactors: ["Good sleep last night (7.5 hrs)", "Stable barometric pressure"],
        recommendedAction: "No special precautions needed today.",
        expiresAt: Date().addingTimeInterval(86400)
    )

    static let mockElevatedRisk = PredictiveAlert(
        riskLevel: .elevated,
        riskScore: 63,
        primaryFactors: [
            "Short sleep last night (5.1 hrs)",
            "Barometric pressure dropped 8 hPa in 6 hours",
            "Luteal phase day 22 — estrogen declining",
        ],
        recommendedAction: "Keep rescue medication accessible and limit screen time this afternoon.",
        expiresAt: Date().addingTimeInterval(86400)
    )

    static let mockHighRisk = PredictiveAlert(
        riskLevel: .high,
        riskScore: 88,
        primaryFactors: [
            "Only 4.2 hours of sleep",
            "Pressure drop 12 hPa — storm front approaching",
            "Migraine 48 hours ago (rebound window)",
            "High self-reported stress yesterday",
        ],
        recommendedAction: "Consider taking preventive action now. Hydrate, rest in a dark room, and take rescue medication at first warning sign.",
        expiresAt: Date().addingTimeInterval(86400)
    )

    static let mockModerateRisk = PredictiveAlert(
        riskLevel: .moderate,
        riskScore: 38,
        primaryFactors: [
            "Slightly below average sleep (6.2 hrs)",
            "Minor pressure fluctuation overnight",
        ],
        recommendedAction: "Stay hydrated and keep your regular routine today.",
        expiresAt: Date().addingTimeInterval(86400)
    )
}
#endif

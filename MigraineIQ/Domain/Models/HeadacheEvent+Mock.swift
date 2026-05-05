//
//  HeadacheEvent+Mock.swift
//  MigraineIQ
//
//  Static mock data for SwiftUI previews and unit tests.
//  Never use these in production code paths.
//

import Foundation

#if DEBUG
extension HeadacheEvent {

    static let mockOngoing = HeadacheEvent(
        startedAt: Date().addingTimeInterval(-3600 * 2),
        endedAt: nil,
        intensity: 7,
        painLocations: [.unilateralRight, .temporal],
        painQuality: [.throbbing],
        classification: .migraineWithoutAura,
        phase: .headache,
        symptoms: [.photophobia, .phonophobia, .nausea],
        triggersSuspected: ["Poor sleep", "Barometric pressure drop"]
    )

    static let mockResolvedYesterday = HeadacheEvent(
        startedAt: Date().addingTimeInterval(-3600 * 26),
        endedAt: Date().addingTimeInterval(-3600 * 20),
        intensity: 8,
        painLocations: [.unilateralLeft, .periorbital],
        painQuality: [.throbbing, .stabbing],
        classification: .migraineWithAura,
        aura: AuraEvent(
            startedAt: Date().addingTimeInterval(-3600 * 26),
            durationMinutes: 22,
            types: [.visual],
            visualDisturbances: [.scintillatingScotoma, .fortificationSpectrum]
        ),
        phase: .resolved,
        symptoms: [.photophobia, .nausea, .vomiting],
        triggersSuspected: ["Red wine", "Late dinner"],
        disabilityImpact: DisabilityImpact(
            missedWorkHours: 4,
            reducedProductivityHours: 0,
            bedRestHours: 6
        )
    )

    static let mockTensionLastWeek = HeadacheEvent(
        startedAt: Date().addingTimeInterval(-86400 * 5),
        endedAt: Date().addingTimeInterval(-86400 * 5 + 3600 * 4),
        intensity: 4,
        painLocations: [.bilateral, .frontal],
        painQuality: [.pressing],
        classification: .tensionTypeEpisodic,
        phase: .resolved,
        symptoms: [.fatigue],
        triggersSuspected: ["Screen time", "Stress"]
    )

    static let mockList: [HeadacheEvent] = [
        .mockOngoing,
        .mockResolvedYesterday,
        .mockTensionLastWeek,
    ]
}
#endif

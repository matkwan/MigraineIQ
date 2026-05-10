//
//  PredictionContext+Mock.swift
//  MigraineIQ
//
//  Static mock data for SwiftUI previews and unit tests.
//  Never use these in production code paths.
//

import Foundation

#if DEBUG
extension PredictionContext {

    static let mockHighRiskContext = PredictionContext(
        knownTriggers: TriggerInsight.mockList,
        recentAttacks: HeadacheEvent.mockList,
        currentContext: .mockHighRisk
    )

    static let mockLowRiskContext = PredictionContext(
        knownTriggers: [.mockPoorSleep, .mockBarometricDrop],
        recentAttacks: [.mockTensionLastWeek],
        currentContext: .mockLowRisk
    )
}
#endif

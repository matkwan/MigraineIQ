//
//  TriggerInsight+Mock.swift
//  MigraineIQ
//
//  Static mock data for SwiftUI previews and unit tests.
//  Never use these in production code paths.
//

import Foundation

#if DEBUG
extension TriggerInsight {

    static let mockPoorSleep = TriggerInsight(
        trigger: "Poor sleep",
        confidence: 0.82,
        occurrenceCount: 11,
        lastObserved: Date().addingTimeInterval(-86400 * 2),
        strengthBand: .strong,
        explanation: "Poor sleep (under 6 hours) preceded 11 of your last 14 migraines, usually within 24 hours."
    )

    static let mockBarometricDrop = TriggerInsight(
        trigger: "Barometric pressure drop",
        confidence: 0.61,
        occurrenceCount: 7,
        lastObserved: Date().addingTimeInterval(-86400 * 5),
        strengthBand: .moderate,
        explanation: "A drop of more than 5 hPa within 6 hours preceded 7 attacks over the past 90 days."
    )

    static let mockRedWine = TriggerInsight(
        trigger: "Red wine",
        confidence: 0.34,
        occurrenceCount: 3,
        lastObserved: Date().addingTimeInterval(-86400 * 18),
        strengthBand: .weak,
        explanation: "Red wine appeared in your notes before 3 attacks, but the sample is too small to be confident."
    )

    static let mockStress = TriggerInsight(
        trigger: "High stress day",
        confidence: 0.74,
        occurrenceCount: 9,
        lastObserved: Date().addingTimeInterval(-86400 * 1),
        strengthBand: .strong,
        explanation: "High-stress days were logged before 9 attacks; the effect is strongest when combined with poor sleep."
    )

    static let mockList: [TriggerInsight] = [
        .mockPoorSleep,
        .mockStress,
        .mockBarometricDrop,
        .mockRedWine,
    ]
}
#endif

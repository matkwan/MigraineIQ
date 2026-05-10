//
//  HealthContext+Mock.swift
//  MigraineIQ
//
//  Static mock data for SwiftUI previews and unit tests.
//  Never use these in production code paths.
//

import Foundation

#if DEBUG
extension SleepSnapshot {
    static let mockPoorSleep  = SleepSnapshot(date: Date().addingTimeInterval(-86400),     hoursSlept: 5.1, quality: 0.4)
    static let mockGoodSleep  = SleepSnapshot(date: Date().addingTimeInterval(-86400 * 2), hoursSlept: 7.5, quality: 0.8)
}

extension HRVSnapshot {
    static let mockLowHRV  = HRVSnapshot(date: Date().addingTimeInterval(-86400),     averageMilliseconds: 28)
    static let mockNormHRV = HRVSnapshot(date: Date().addingTimeInterval(-86400 * 2), averageMilliseconds: 47)
}

extension WeatherSnapshot {
    static let mockPressureDrop = WeatherSnapshot(
        date: Date().addingTimeInterval(-21600), // 6 h ago
        pressureHPa: 1004,
        pressureDeltaHPa: -8,
        temperatureCelsius: 18,
        humidity: 72,
        condition: "Overcast"
    )
    static let mockStable = WeatherSnapshot(
        date: Date().addingTimeInterval(-86400),
        pressureHPa: 1013,
        pressureDeltaHPa: 0.5,
        temperatureCelsius: 21,
        humidity: 55,
        condition: "Partly Cloudy"
    )
}

extension CycleSnapshot {
    static let mockLuteal     = CycleSnapshot(date: Date(), phase: .luteal)
    static let mockFollicular = CycleSnapshot(date: Date().addingTimeInterval(-86400 * 7), phase: .follicular)
}

extension HealthContext {
    static let mockHighRisk = HealthContext(
        sleep: [.mockPoorSleep],
        hrv: [.mockLowHRV],
        weather: [.mockPressureDrop],
        cycle: [.mockLuteal],
        foodTags: ["red wine", "aged cheese"]
    )

    static let mockLowRisk = HealthContext(
        sleep: [.mockGoodSleep],
        hrv: [.mockNormHRV],
        weather: [.mockStable],
        cycle: [.mockFollicular],
        foodTags: []
    )
}
#endif

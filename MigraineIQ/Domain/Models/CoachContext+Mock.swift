//
//  CoachContext+Mock.swift
//  MigraineIQ
//
//  Static mock data for SwiftUI previews and unit tests.
//  Never use these in production code paths.
//

import Foundation

#if DEBUG
extension CoachContext {

    static let mockRichContext = CoachContext(
        attacks: [.mockOngoing, .mockResolvedYesterday],
        doses: [.mockSumatriptanToday, .mockIbuprofenYesterday],
        sleep: [.mockPoorSleep],
        weather: [.mockPressureDrop],
        cycle: [.mockLuteal],
        foodTags: ["red wine", "skipped lunch"]
    )

    static let mockEmptyContext = CoachContext()
}
#endif

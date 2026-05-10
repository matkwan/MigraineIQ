//
//  CoachMessage+Mock.swift
//  MigraineIQ
//
//  Static mock data for SwiftUI previews and unit tests.
//  Never use these in production code paths.
//

import Foundation

#if DEBUG
extension CoachMessage {

    static let mockUserQuestion = CoachMessage(
        role: .user,
        content: "Why did I get a migraine yesterday?",
        createdAt: Date().addingTimeInterval(-120)
    )

    static let mockAssistantAnswer = CoachMessage(
        role: .assistant,
        content: "Based on your logs from the past 72 hours, three factors aligned yesterday: you slept only 5.1 hours the night before, barometric pressure dropped 8 hPa in the 6 hours before your attack, and you're currently in the luteal phase of your cycle — all three are in your personal top-4 triggers. The combination of sleep deficit and pressure drop accounts for a similar pattern in 7 of your last 14 migraines.",
        createdAt: Date().addingTimeInterval(-90)
    )

    static let mockUserFollowUp = CoachMessage(
        role: .user,
        content: "What should I do differently tonight?",
        createdAt: Date().addingTimeInterval(-30)
    )

    static let mockAssistantFollowUp = CoachMessage(
        role: .assistant,
        content: "Prioritise an early bedtime — your data shows that getting at least 7 hours consistently reduces attack frequency. If you take magnesium glycinate, tonight would be a good time. Keep rescue medication nearby in case symptoms start overnight.",
        createdAt: Date()
    )

    static let mockConversation: [CoachMessage] = [
        .mockUserQuestion,
        .mockAssistantAnswer,
        .mockUserFollowUp,
        .mockAssistantFollowUp,
    ]
}
#endif

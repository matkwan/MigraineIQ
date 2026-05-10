//
//  CoachMessage.swift
//  MigraineIQ
//
//  A single turn in the AI Coach conversation thread.
//  The coach view maintains a [CoachMessage] array and streams assistant
//  tokens into the last message via AskAICoachUseCase.
//

import Foundation

struct CoachMessage: Identifiable, Codable, Hashable {
    let id: UUID
    var role: Role
    /// Full message text. For streaming assistant turns this grows token by token.
    var content: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }

    // MARK: - Nested types

    enum Role: String, Codable, Hashable {
        case user
        case assistant
    }
}

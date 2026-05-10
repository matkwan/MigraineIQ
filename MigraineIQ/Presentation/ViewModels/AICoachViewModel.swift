//
//  AICoachViewModel.swift
//  MigraineIQ
//
//  Drives the AI Coach chat screen. Manages the message history and the
//  token-by-token streaming state from AskAICoachUseCase.
//
//  Streaming pattern
//  ─────────────────────────────────────────────────────────────────────────
//  While the response is arriving, tokens accumulate in `streamingText`
//  (not in `messages`). The UI renders `streamingText` as a live "typing"
//  bubble. When the stream ends, the complete assistant message is committed
//  to `messages` and `streamingText` is cleared — one clean state
//  transition, no mid-array mutation.
//
//  Offline pattern
//  ─────────────────────────────────────────────────────────────────────────
//  `send()` checks NetworkMonitor before starting the stream. If offline,
//  the user's text is restored to the input field and a clear message is
//  surfaced via .failed so they know exactly why nothing happened.
//  ─────────────────────────────────────────────────────────────────────────
//

import Foundation
import Observation

@Observable
@MainActor
final class AICoachViewModel {

    // MARK: - View state

    enum SendState: Equatable {
        case idle
        case streaming
        case locked               // free tier — AI Coach requires Pro
        case failed(String)
    }

    private(set) var messages: [CoachMessage] = []
    private(set) var streamingText: String    = ""
    private(set) var sendState: SendState     = .idle

    /// Two-way bound to the text input field.
    var inputText: String = ""

    let isAIAvailable: Bool

    /// `true` when the user has Pro access to the AI Coach.
    var isCoachUnlocked: Bool { TokenGuard.canUseAICoach() }

    /// Convenience accessor so the view can observe connectivity without
    /// importing Network or holding a separate reference.
    var isOffline: Bool { !NetworkMonitor.shared.isConnected }

    // MARK: - Dependencies

    private let headacheRepository: HeadacheRepositoryProtocol
    private let medicationRepository: MedicationRepositoryProtocol
    private let aiInsightsRepository: (any AIInsightsRepositoryProtocol)?

    /// Retained so the streaming loop can be cancelled (e.g. user taps Stop).
    private var sendTask: Task<Void, Never>?

    // MARK: - Init

    init(
        headacheRepository: HeadacheRepositoryProtocol,
        medicationRepository: MedicationRepositoryProtocol,
        aiInsightsRepository: (any AIInsightsRepositoryProtocol)? = nil
    ) {
        self.headacheRepository   = headacheRepository
        self.medicationRepository = medicationRepository
        self.aiInsightsRepository = aiInsightsRepository
        self.isAIAvailable        = aiInsightsRepository != nil
    }

    // MARK: - Actions

    func send() {
        let question = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, let aiRepo = aiInsightsRepository else { return }

        // Free-tier gate — AI Coach is a Pro-only feature.
        guard TokenGuard.canUseAICoach() else {
            sendState = .locked
            return
        }

        // Offline guard — surface a clear message and restore the input text
        // so the user doesn't lose what they typed.
        guard NetworkMonitor.shared.isConnected else {
            sendState = .failed("You're offline. Connect to the internet to chat with your coach.")
            return
        }

        // Commit user message immediately so the UI shows it right away.
        messages.append(CoachMessage(role: .user, content: question))
        inputText     = ""
        streamingText = ""
        sendState     = .streaming

        // History excludes the message we just appended.
        let history = Array(messages.dropLast())

        let useCase = AskAICoachUseCase(
            headacheRepository: headacheRepository,
            medicationRepository: medicationRepository,
            aiRepository: aiRepo
        )

        sendTask = Task {
            do {
                let stream = useCase.execute(question: question, history: history)
                for try await token in stream {
                    streamingText += token
                }
                // Stream finished — commit the full assistant response.
                messages.append(CoachMessage(role: .assistant, content: streamingText))
                streamingText = ""
                sendState     = .idle
            } catch is CancellationError {
                // User tapped Stop — discard partial response silently.
                streamingText = ""
                sendState     = .idle
            } catch {
                streamingText = ""
                sendState     = .failed(ErrorPresenter.userMessage(for: error))
            }
        }
    }

    /// Cancels an in-flight streaming response.
    func cancelStreaming() {
        sendTask?.cancel()
        sendTask = nil
    }

    /// Clears the send error without wiping the conversation.
    func clearSendError() {
        if case .failed = sendState { sendState = .idle }
    }

    /// Clears the conversation (for a "New chat" button in future).
    func clearHistory() {
        cancelStreaming()
        messages      = []
        streamingText = ""
        sendState     = .idle
    }
}

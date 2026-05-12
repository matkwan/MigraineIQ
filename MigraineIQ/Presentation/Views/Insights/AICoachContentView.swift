//
//  AICoachContentView.swift
//  MigraineIQ
//
//  Chat interface for the AI coach. Message bubbles stream token-by-token
//  while a response is in flight; the last partial token accumulates in
//  `viewModel.streamingText` and commits to `viewModel.messages` when done.
//

import SwiftUI

struct AICoachContentView: View {
    @Bindable var viewModel: AICoachViewModel
    @FocusState private var inputFocused: Bool
    @State private var speechService = SpeechRecognitionService()

    var body: some View {
        VStack(spacing: 0) {
            messageList
            Divider()
                .background(AppTheme.Colors.elevatedSurface)
            inputBar
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("AI Coach")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            // Stop the mic engine if the user navigates away mid-recording.
            // Without this the AVAudioEngine keeps capturing until the 58 s
            // session timer fires.
            if case .recording = speechService.state {
                speechService.stop()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if case .failed = viewModel.sendState {
                    // Dismiss the error banner without wiping the conversation.
                    Button("Dismiss") { viewModel.clearSendError() }
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.accent)
                }
            }
        }
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AppTheme.Spacing.s) {
                    if viewModel.messages.isEmpty && viewModel.streamingText.isEmpty {
                        emptyState
                    }

                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    // Live streaming bubble
                    if !viewModel.streamingText.isEmpty {
                        StreamingBubble(text: viewModel.streamingText)
                            .id("streaming")
                    }

                    // Pro locked banner
                    if viewModel.sendState == .locked || !viewModel.isCoachUnlocked {
                        ProCoachLockedBanner()
                            .id("locked")
                    }

                    // Error banner
                    if case .failed(let msg) = viewModel.sendState {
                        ErrorBanner(message: msg)
                            .id("error")
                    }
                }
                .padding(AppTheme.Spacing.m)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.streamingText) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if !viewModel.streamingText.isEmpty {
            withAnimation(.easeOut(duration: 0.15)) {
                proxy.scrollTo("streaming", anchor: .bottom)
            }
        } else if let last = viewModel.messages.last {
            withAnimation(.easeOut(duration: 0.15)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            // Offline notice — shown above the text field when there's no connection.
            if viewModel.isOffline {
                offlineBanner
            }

            HStack(spacing: AppTheme.Spacing.s) {
                TextField("Ask your coach…", text: $viewModel.inputText, axis: .vertical)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .tint(AppTheme.Colors.accent)
                    .lineLimit(1...5)
                    .focused($inputFocused)
                    .disabled(viewModel.sendState == .streaming
                              || viewModel.isOffline
                              || !viewModel.isCoachUnlocked)
                    .onSubmit {
                        if viewModel.sendState != .streaming, !viewModel.isOffline {
                            viewModel.send()
                        }
                    }

                // Mic button — only shown when Coach is unlocked and not streaming.
                // Uses the same MicButtonView as the attack and medication forms
                // for consistent recording UI (red circle, pulse ring, arc).
                if viewModel.isCoachUnlocked,
                   viewModel.sendState != .streaming {
                    Button {
                        switch speechService.state {
                        case .recording:
                            let final = speechService.stop()
                            if viewModel.inputText.isEmpty, !final.isEmpty {
                                viewModel.inputText = final
                            }
                        case .unavailable:
                            speechService.resetError()
                        default:
                            Task { await speechService.start() }
                        }
                    } label: {
                        MicButtonView(service: speechService)
                    }
                    .buttonStyle(.plain)
                    .disabled({
                        if case .requestingPermissions = speechService.state { return true }
                        return false
                    }())
                }

                actionButton
            }
            .padding(.horizontal, AppTheme.Spacing.m)
            .padding(.vertical, AppTheme.Spacing.s)
            .background(AppTheme.Colors.cardBackground)
        }
        // ── Live transcript → input field ────────────────────────────────
        // Replace inputText as each partial result arrives. The `guard
        // !transcript.isEmpty` prevents stop() clearing the field after the
        // session ends (stop() sets partialTranscript = "" synchronously, but
        // by then inputText already holds the final question).
        .onChange(of: speechService.partialTranscript) { _, transcript in
            guard !transcript.isEmpty else { return }
            guard case .recording = speechService.state else { return }
            viewModel.inputText = transcript
        }
        // ── Auto-stop (58 s limit) ───────────────────────────────────────
        .onChange(of: speechService.state) { old, new in
            guard case .recording = old, case .idle = new else { return }
            // inputText already holds the final text from the live updates.
            // Clean up the service's internal partial transcript.
            speechService.clearTranscript()
        }
    }

    private var offlineBanner: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 12, weight: .semibold))
            Text("You're offline — messages will send when you reconnect")
                .font(AppTheme.Typography.caption)
        }
        .foregroundStyle(AppTheme.Colors.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppTheme.Spacing.m)
        .padding(.vertical, AppTheme.Spacing.xs)
        .background(AppTheme.Colors.elevatedSurface)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch viewModel.sendState {
        case .streaming:
            Button {
                viewModel.cancelStreaming()
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.Colors.riskModerate)
            }

        default:
            Button {
                // If mic is still active when the user taps send, stop it
                // first so the final transcript lands in inputText.
                if case .recording = speechService.state {
                    let final = speechService.stop()
                    if viewModel.inputText.isEmpty, !final.isEmpty {
                        viewModel.inputText = final
                    }
                }
                viewModel.send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? AppTheme.Colors.tertiaryText
                            : AppTheme.Colors.accent
                    )
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.m) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.accentMuted)
            Text("Your AI migraine coach")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.primaryText)
            Text("Ask anything about your patterns, triggers, treatment options, or what to do during an attack.")
                .font(AppTheme.Typography.body)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, AppTheme.Spacing.xxl)
        .padding(.horizontal, AppTheme.Spacing.l)
    }
}

// MARK: - MessageBubble

private struct MessageBubble: View {
    let message: CoachMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: AppTheme.Spacing.xxl) }

            Text(message.content)
                .font(AppTheme.Typography.body)
                .foregroundStyle(isUser ? Color.white : AppTheme.Colors.primaryText)
                .padding(.horizontal, AppTheme.Spacing.m)
                .padding(.vertical, AppTheme.Spacing.s)
                .background(isUser ? AppTheme.Colors.accentMuted : AppTheme.Colors.elevatedSurface)
                .clipShape(RoundedRectangle(
                    cornerRadius: AppTheme.Radius.card,
                    style: .continuous
                ))

            if !isUser { Spacer(minLength: AppTheme.Spacing.xxl) }
        }
    }
}

// MARK: - StreamingBubble

private struct StreamingBubble: View {
    let text: String

    var body: some View {
        HStack {
            Group {
                if text.isEmpty {
                    // Dots while waiting for first token
                    TypingIndicator()
                } else {
                    Text(text)
                        .font(AppTheme.Typography.body)
                        .foregroundStyle(AppTheme.Colors.primaryText)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.m)
            .padding(.vertical, AppTheme.Spacing.s)
            .background(AppTheme.Colors.elevatedSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))

            Spacer(minLength: AppTheme.Spacing.xxl)
        }
    }
}

// MARK: - TypingIndicator

private struct TypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(AppTheme.Colors.secondaryText)
                    .frame(width: 6, height: 6)
                    .scaleEffect(phase == i ? 1.3 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.4)
                            .repeatForever()
                            .delay(Double(i) * 0.15),
                        value: phase
                    )
            }
        }
        .onAppear { phase = (phase + 1) % 3 }
    }
}

// MARK: - ProCoachLockedBanner

private struct ProCoachLockedBanner: View {
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: AppTheme.Spacing.s) {
            Image(systemName: "crown.fill")
                .font(.system(size: 28))
                .foregroundStyle(AppTheme.Colors.accent)
            Text("AI Coach is a Pro feature")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(AppTheme.Colors.primaryText)
            Text("Upgrade to Pro to chat with your personal migraine coach and get personalized answers about your patterns.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
            Button("Upgrade to Pro") {
                showPaywall = true
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, AppTheme.Spacing.l)
            .padding(.vertical, AppTheme.Spacing.s)
            .background(AppTheme.Colors.accent, in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.l)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

// MARK: - ErrorBanner

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.Colors.riskHigh)
            Text(message)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.riskHigh)
        }
        .padding(AppTheme.Spacing.s)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Colors.riskHigh.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }
}

// MARK: - Previews ---------------------------------------------------------- TOBEFIXED

//#Preview {
//    NavigationStack {
//        AICoachContentView(
//            viewModel: {
//                let vm = AICoachViewModel(
//                    headacheRepository: MockHeadacheRepository(),
//                    medicationRepository: MockMedicationRepository(),
//                    aiInsightsRepository: MockAIInsightsRepository()
//                )
//                return vm
//            }()
//        )
//    }
//    .environment(DependencyContainer.preview())
//}

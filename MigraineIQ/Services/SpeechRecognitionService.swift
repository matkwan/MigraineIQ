//
//  SpeechRecognitionService.swift
//  MigraineIQ
//
//  AVAudioEngine + SFSpeechRecognizer wrapper for live voice-to-text dictation.
//  Pro-gated — callers must verify SubscriptionManager.shared.isProSubscriber
//  before invoking `start()`.
//
//  Session limits
//  ─────────────────────────────────────────────────────────────────────────
//  Apple enforces a hard 1-minute limit per SFSpeechAudioBufferRecognitionRequest.
//  The service auto-signals `endAudio()` at 58 s to stay safely within that
//  bound and publishes `sessionProgress` (0.0 → 1.0) so the UI can animate
//  the countdown arc.
//
//  On auto-stop the state transitions to `.idle` with `partialTranscript`
//  still holding the final text so the view's `onChange` can pick it up.
//  On explicit `stop()`, the transcript is returned directly and then cleared.
//
//  Usage
//  ─────────────────────────────────────────────────────────────────────────
//  1. `await service.start()` — handles permission requests.
//  2. Observe `partialTranscript` for live streaming text.
//  3. `service.stop()` → returns final transcript and resets.
//     — or —
//     Watch `state` for `.idle` transition (auto-stop after ~58 s).
//

import AVFoundation
import Speech
import Observation

// MARK: - State

enum SpeechRecognizerState: Equatable {
    case idle
    case requestingPermissions
    case recording
    case unavailable(String)
}

// MARK: - Service

@Observable
@MainActor
final class SpeechRecognitionService {

    // MARK: - Constants

    static let sessionDuration: Double = 58.0   // safely below Apple's 60 s hard cap

    // MARK: - Observable state

    private(set) var state: SpeechRecognizerState = .idle
    /// Live transcript text — appended as the recognizer produces results.
    private(set) var partialTranscript: String = ""
    /// Fraction 0.0 → 1.0 representing elapsed / sessionDuration.
    private(set) var sessionProgress: Double = 0.0

    // MARK: - Private

    // NOTE: A fresh AVAudioEngine is created for every recording session.
    // Reusing a stopped engine causes `IsFormatSampleRateAndChannelCountValid`
    // assertion failures on the second and subsequent recordings.
    private var audioEngine: AVAudioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var progressTimer: Timer?
    private var elapsed: Double = 0

    // MARK: - Public API

    /// Requests permissions (if needed) then begins recording.
    /// No-op if already recording or in `.requestingPermissions` state.
    func start() async {
        guard case .idle = state else { return }
        state = .requestingPermissions

        // 1. Microphone
        guard await requestMicPermission() else {
            state = .unavailable(
                "Microphone access is required.\nGo to Settings → Privacy → Microphone to enable it."
            )
            return
        }

        // 2. Speech recognition
        guard await requestSpeechPermission() else {
            state = .unavailable(
                "Speech Recognition access is required.\nGo to Settings → Privacy → Speech Recognition to enable it."
            )
            return
        }

        // 3. Recognizer availability (locale + hardware)
        guard
            let recognizer = SFSpeechRecognizer(locale: .current),
            recognizer.isAvailable
        else {
            state = .unavailable("Speech recognition is not available on this device or in your current locale.")
            return
        }

        // 4. Begin audio capture
        do {
            try beginRecording(recognizer: recognizer)
            state = .recording
            startProgressTimer()
        } catch {
            state = .unavailable("Could not start microphone: \(error.localizedDescription)")
        }
    }

    /// Stops recording, returns the final transcript string, and resets all state.
    /// The returned string should be appended to the notes field by the caller.
    @discardableResult
    func stop() -> String {
        let result = partialTranscript
        tearDown()
        partialTranscript = ""
        state = .idle
        return result
    }

    /// Resets an `.unavailable` error back to `.idle` so the user can retry.
    func resetError() {
        if case .unavailable = state { state = .idle }
    }

    /// Clears `partialTranscript` without affecting recording state.
    /// Called by the view after it has consumed and appended the transcript.
    func clearTranscript() {
        partialTranscript = ""
    }

    // MARK: - Private helpers

    private func beginRecording(recognizer: SFSpeechRecognizer) throws {
        tearDown()   // stops & releases any previous session

        // Create a brand-new engine every time. Reusing a stopped AVAudioEngine
        // leaves stale hardware state that causes the sample-rate assertion:
        //   "required condition is false: IsFormatSampleRateAndChannelCountValid"
        audioEngine = AVAudioEngine()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Prefer on-device recognition for privacy; fall back to server.
        request.requiresOnDeviceRecognition = false
        recognitionRequest = request

        // Activate the audio session for recording BEFORE touching the engine.
        // Without this, AVAudioEngine.start() throws -10868 (invalid property
        // value) because iOS has no active input session to bind to.
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord,
            mode: .measurement,          // low-latency, minimal processing
            options: [.duckOthers, .allowBluetooth]
        )
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        // Pass `nil` so AVAudioEngine installs the tap using the hardware's
        // native format. Explicitly fetching `outputFormat(forBus: 0)` before
        // the engine has started returns sampleRate = 0 on many devices,
        // which also triggers the IsFormatSampleRateAndChannelCountValid crash.
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.partialTranscript = result.bestTranscription.formattedString
                }
                // Session ended (Apple limit or explicit endAudio)
                if error != nil || result?.isFinal == true {
                    if case .recording = self.state {
                        // Auto-stop: leave partialTranscript intact so the
                        // view's onChange handler can append it to notes.
                        self.tearDown()
                        self.state = .idle
                    }
                }
            }
        }
    }

    private func tearDown() {
        progressTimer?.invalidate()
        progressTimer = nil
        elapsed = 0
        sessionProgress = 0

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        // Stop the engine and remove any installed tap. Safe to call even if
        // the engine was never started (isRunning = false).
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        // removeTap is safe to call on a stopped engine; no-op if no tap exists.
        audioEngine.inputNode.removeTap(onBus: 0)

        // Deactivate the audio session so other apps (music, podcasts) can
        // resume. Failure here is non-fatal — swallow it silently.
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    private func startProgressTimer() {
        elapsed = 0
        sessionProgress = 0
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.elapsed += 0.1
                self.sessionProgress = min(self.elapsed / Self.sessionDuration, 1.0)
                if self.elapsed >= Self.sessionDuration {
                    // Signal end-of-audio — recognizer will finalize and call
                    // the task completion handler, which transitions to .idle.
                    self.recognitionRequest?.endAudio()
                    self.progressTimer?.invalidate()
                    self.progressTimer = nil
                }
            }
        }
    }

    // MARK: - Permissions

    private func requestMicPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

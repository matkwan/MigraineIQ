//
//  WatchLogModel.swift
//  MigraineIQWatch
//
//  Observable view model for the Watch app. Sends a WatchConnectivity
//  message to the iPhone and tracks the in-flight / result state so the
//  UI can show feedback without any blocking waits.
//
//  WCSession strategy
//  ─────────────────────────────────────────────────────────────────────────
//  • isReachable == true  → sendMessage with real-time reply.
//  • isReachable == false → transferUserInfo (queued delivery, no reply).
//    The UI shows an optimistic "Logged" immediately because the payload
//    will reach the phone as soon as it becomes reachable.
//  • 10-second timeout on sendMessage guards against the simulator scenario
//    where neither replyHandler nor errorHandler ever fires, which would
//    leave the spinner on screen forever.
//  • All WCSession callbacks arrive on a background queue; we dispatch to
//    the main queue before mutating @Observable state.
//

import Foundation
import Observation
import WatchConnectivity

@Observable
final class WatchLogModel: NSObject {

    // MARK: - State

    enum LogState: Equatable {
        case ready
        case sending
        case saved
        case error(String)
    }

    private(set) var state: LogState = .ready

    // MARK: - Init

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Actions

    func logNow() {
        guard case .ready = state else { return }
        guard WCSession.default.activationState == .activated else {
            state = .error("Open iPhone app")
            scheduleReset()
            return
        }

        let payload: [String: Any] = [
            "action":    "quicklog",
            "timestamp": Date().timeIntervalSince1970
        ]

        if WCSession.default.isReachable {
            // Fast path — phone is reachable; expect a real-time reply.
            state = .sending
            sendWithTimeout(payload)
        } else {
            // Slow path — phone not reachable; queue for later delivery.
            WCSession.default.transferUserInfo(payload)
            state = .saved          // Optimistic: payload will arrive soon.
            scheduleReset()
        }
    }

    // MARK: - Private helpers

    /// Sends a message and resolves whichever comes first:
    /// the real reply, the error handler, or a 10-second timeout.
    ///
    /// Timeout resolves as `.saved` (optimistic) because if WatchConnectivity
    /// accepted the message without an error, it was delivered — the reply
    /// just didn't make it back (a known simulator limitation).
    /// Only a definitive `errorHandler` callback shows the error state.
    private func sendWithTimeout(_ payload: [String: Any]) {
        var finished = false

        // Timeout — assume success if WC never calls back (simulator bug).
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard !finished else { return }
            finished = true
            self?.state = .saved
            self?.scheduleReset()
        }

        WCSession.default.sendMessage(payload, replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                guard !finished else { return }
                finished = true
                let status = reply["status"] as? String
                self?.state = (status == "saved") ? .saved : .error("Save failed")
                self?.scheduleReset()
            }
        }, errorHandler: { [weak self] _ in
            // Definitive failure — phone rejected the message outright.
            DispatchQueue.main.async {
                guard !finished else { return }
                finished = true
                self?.state = .error("Open iPhone app")
                self?.scheduleReset()
            }
        })
    }

    private func scheduleReset() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.state = .ready
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchLogModel: WCSessionDelegate {

    // watchOS only requires activationDidCompleteWith.
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}
}

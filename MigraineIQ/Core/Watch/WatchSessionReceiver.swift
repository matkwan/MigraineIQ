//
//  WatchSessionReceiver.swift
//  MigraineIQ
//
//  iPhone-side WatchConnectivity delegate. Receives a "quicklog" message
//  from the Apple Watch, creates a HeadacheEvent, and saves it via the
//  headache repository — exactly the same path that QuickLogViewModel uses.
//
//  Threading model
//  ─────────────────────────────────────────────────────────────────────────
//  WCSessionDelegate callbacks arrive on a WatchConnectivity background
//  serial queue. We hop to @MainActor before touching the repository or
//  any AppState, keeping all persistence work on the main actor where
//  SwiftData expects it.
//
//  Lifecycle
//  ─────────────────────────────────────────────────────────────────────────
//  1. DependencyContainer.init() sets headacheRepository on the singleton.
//  2. AppDelegate.application(_:didFinishLaunchingWithOptions:) calls
//     activate() so the WCSession is ready before the first view appears.
//

import Foundation
import WatchConnectivity

final class WatchSessionReceiver: NSObject {

    // MARK: - Singleton

    static let shared = WatchSessionReceiver()

    // MARK: - Dependencies

    /// Injected by DependencyContainer before activate() is called.
    var headacheRepository: HeadacheRepositoryProtocol?

    // MARK: - Activation

    /// Activates the WCSession. Safe to call on any thread; WatchConnectivity
    /// is thread-safe for activation. No-op when WCSession is not supported
    /// (e.g. on iPad or simulator without paired watch).
    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionReceiver: WCSessionDelegate {

    // Required — iOS only.
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    // Required on iOS — called when the Watch switches between paired devices.
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    // Required on iOS — re-activate after paired Watch handoff completes.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    // MARK: - Message handlers

    /// Fast path — called when `sendMessage` is used (phone was reachable).
    /// Message format:
    ///   - "action"    : String — must be "quicklog"
    ///   - "timestamp" : TimeInterval — seconds since 1970 (optional)
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let action = message["action"] as? String, action == "quicklog" else {
            replyHandler(["status": "unknown_action"])
            return
        }
        let startedAt = date(from: message)
        Task { @MainActor in
            await save(startedAt: startedAt)
            replyHandler(["status": "saved"])
        }
    }

    /// Slow path — called when `transferUserInfo` was used (phone was not reachable).
    /// Same payload format; no reply expected.
    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        guard let action = userInfo["action"] as? String, action == "quicklog" else { return }
        let startedAt = date(from: userInfo)
        Task { @MainActor in
            await save(startedAt: startedAt)
        }
    }

    // MARK: - Private helpers

    nonisolated private func date(from dict: [String: Any]) -> Date {
        if let ts = dict["timestamp"] as? TimeInterval {
            return Date(timeIntervalSince1970: ts)
        }
        return Date()
    }

    @MainActor
    private func save(startedAt: Date) async {
        let event = HeadacheEvent(
            startedAt: startedAt,
            intensity: 5,
            classification: .undetermined,
            phase: .headache
        )
        do {
            try await headacheRepository?.save(event)
            DashboardViewModel.invalidateRiskCache()
            ReviewService.shared.recordAttackLogged()
        } catch {
            // Silently drop — the Watch can't receive an error at this point
            // (transferUserInfo has no reply channel). The user can retry.
        }
    }
}

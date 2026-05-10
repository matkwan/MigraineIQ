//
//  NotificationService.swift
//  MigraineIQ
//
//  Centralised notification scheduling for the two user-facing alert types:
//
//    1. Risk alert   — scheduled at 7 am when nightly risk ≥ .elevated.
//                      Uses a UNCalendarNotificationTrigger (fires once).
//
//    2. MOH warning  — delivered immediately when the MOH level escalates
//                      (.safe → .approaching / .atRisk / .overuse).
//                      Re-notifies only on escalation; resets when level
//                      drops back to .safe.
//
//  Both notifications use interruptionLevel = .timeSensitive, which
//  requires the "Time Sensitive Notifications" entitlement in Xcode:
//    Target → Signing & Capabilities → + "Time Sensitive Notifications"
//
//  Without that entitlement the notifications still deliver but fall back
//  to the default .active interruption level — no crash.
//

import Foundation
import UserNotifications

final class NotificationService {

    // MARK: - Singleton

    static let shared = NotificationService()
    private init() {}

    // MARK: - Identifiers

    private enum ID {
        static let risk = "migraineiq.risk.today"
        static let moh  = "migraineiq.moh.warning"
    }

    // MARK: - Risk alert (called from BackgroundTaskCoordinator)

    /// Schedules a Time Sensitive risk notification for 7 am today.
    /// Replaces any existing pending risk notification to avoid stacking.
    func scheduleRiskAlert(for alert: PredictiveAlert) async {
        let center = UNUserNotificationCenter.current()
        guard await isAuthorized(center) else { return }

        center.removePendingNotificationRequests(withIdentifiers: [ID.risk])

        let content = UNMutableNotificationContent()
        content.title = riskTitle(for: alert.riskLevel)
        content.body  = alert.recommendedAction.isEmpty
            ? "\(alert.riskScore)% migraine risk forecast for today."
            : "\(alert.riskScore)% risk today — \(alert.recommendedAction)"
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        var components    = DateComponents()
        components.hour   = 7
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: ID.risk, content: content, trigger: trigger)
        try? await center.add(request)
    }

    func removeRiskAlert() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [ID.risk])
    }

    // MARK: - MOH warning (called from LogDoseViewModel after each save/delete)

    /// Delivers an immediate MOH warning when the risk level has escalated
    /// since the last notification. Resets tracking when level returns to .safe.
    func scheduleMOHWarningIfNeeded(for assessment: MOHRiskAssessment) async {
        let center = UNUserNotificationCenter.current()

        if assessment.level == .safe {
            // Back to safe — clear the tracking so the next crossing re-notifies.
            lastNotifiedMOHLevel = nil
            center.removePendingNotificationRequests(withIdentifiers: [ID.moh])
            center.removeDeliveredNotifications(withIdentifiers: [ID.moh])
            return
        }

        // Only fire when the level has escalated.
        guard isSeverityIncrease(from: lastNotifiedMOHLevel, to: assessment.level) else { return }
        guard await isAuthorized(center) else { return }

        lastNotifiedMOHLevel = assessment.level

        let content = UNMutableNotificationContent()
        content.title = mohTitle(for: assessment.level)
        content.body  = assessment.explanation
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        // Deliver immediately (1-second delay keeps the request from being
        // rejected if the app is still in the foreground).
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: ID.moh, content: content, trigger: trigger)
        try? await center.add(request)
    }

    func removeMOHWarning() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [ID.moh])
        center.removeDeliveredNotifications(withIdentifiers: [ID.moh])
    }

    // MARK: - MOH level tracking (UserDefaults)

    private static let lastMOHLevelKey = "notif.lastNotifiedMOHLevel"

    private var lastNotifiedMOHLevel: MOHRiskAssessment.Level? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: Self.lastMOHLevelKey) else { return nil }
            return MOHRiskAssessment.Level(rawValue: raw)
        }
        set {
            UserDefaults.standard.set(newValue?.rawValue, forKey: Self.lastMOHLevelKey)
        }
    }

    /// Returns true only when the new level is strictly more severe than
    /// the last level we sent a notification for.
    private func isSeverityIncrease(
        from old: MOHRiskAssessment.Level?,
        to   new: MOHRiskAssessment.Level
    ) -> Bool {
        func rank(_ level: MOHRiskAssessment.Level) -> Int {
            switch level {
            case .safe:        return 0
            case .approaching: return 1
            case .atRisk:      return 2
            case .overuse:     return 3
            }
        }
        guard let old else { return true }   // first notification ever
        return rank(new) > rank(old)
    }

    // MARK: - Authorisation helper

    private func isAuthorized(_ center: UNUserNotificationCenter) async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    // MARK: - Copy helpers

    private func riskTitle(for level: PredictiveAlert.RiskLevel) -> String {
        switch level {
        case .low:      return "Low Migraine Risk Today"
        case .moderate: return "Moderate Migraine Risk Today"
        case .elevated: return "Elevated Migraine Risk Today"
        case .high:     return "High Migraine Risk Today ⚠️"
        }
    }

    private func mohTitle(for level: MOHRiskAssessment.Level) -> String {
        switch level {
        case .safe:        return "MOH Risk: Safe"
        case .approaching: return "Medication Use Approaching MOH Threshold"
        case .atRisk:      return "Medication Overuse Headache Risk"
        case .overuse:     return "Medication Overuse Detected"
        }
    }
}

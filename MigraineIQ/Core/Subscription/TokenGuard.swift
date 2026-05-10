//
//  TokenGuard.swift
//  MigraineIQ
//
//  Enforces per-feature AI usage limits for free-tier users.
//  Pro subscribers bypass every check unconditionally.
//
//  Free-tier limits
//  ─────────────────────────────────────────────────────────────────────────
//  • Risk forecast:     3 per rolling 7-day window
//  • Trigger analysis:  1 per rolling 30-day window
//  • AI Coach:          blocked entirely
//
//  Usage counts and window-start timestamps are stored in UserDefaults so
//  they survive app restarts. The guard resets a counter automatically
//  when its window has expired.
//
//  Usage
//  ─────────────────────────────────────────────────────────────────────────
//  // Before making an AI call:
//  guard TokenGuard.canUseRiskForecast() else {
//      riskState = .locked; return
//  }
//  // After a successful call:
//  TokenGuard.recordRiskForecastUse()
//

import Foundation

enum TokenGuard {

    // MARK: - Limits

    /// Weekly risk-forecast allowance for free tier.
    static let riskForecastWeeklyLimit: Int = 3

    /// Monthly trigger-analysis allowance for free tier.
    static let triggerAnalysisMonthlyLimit: Int = 1

    // MARK: - UserDefaults keys

    private enum Key {
        static let riskWindowStart   = "tg.riskWindowStart"
        static let riskUseCount      = "tg.riskUseCount"
        static let triggerWindowStart = "tg.triggerWindowStart"
        static let triggerUseCount   = "tg.triggerUseCount"
    }

    // MARK: - Risk forecast

    /// Returns `true` when the user may request a risk forecast.
    /// Pro subscribers always return `true`.
    static func canUseRiskForecast() -> Bool {
        if SubscriptionManager.shared.isProSubscriber { return true }
        let (_, count) = riskWindow()
        return count < riskForecastWeeklyLimit
    }

    /// Records one risk-forecast use. Call AFTER a successful API response.
    static func recordRiskForecastUse() {
        guard !SubscriptionManager.shared.isProSubscriber else { return }
        var (start, count) = riskWindow()
        // If the window expired, we're starting a fresh one.
        if isExpired(start, windowDays: 7) {
            start = Date()
            count = 0
        }
        UserDefaults.standard.set(start.timeIntervalSinceReferenceDate, forKey: Key.riskWindowStart)
        UserDefaults.standard.set(count + 1, forKey: Key.riskUseCount)
    }

    /// Remaining risk-forecast uses in the current 7-day window.
    static var remainingRiskForecasts: Int {
        if SubscriptionManager.shared.isProSubscriber { return .max }
        let (_, count) = riskWindow()
        return max(0, riskForecastWeeklyLimit - count)
    }

    // MARK: - Trigger analysis

    /// Returns `true` when the user may run a trigger analysis.
    /// Pro subscribers always return `true`.
    static func canUseTriggerAnalysis() -> Bool {
        if SubscriptionManager.shared.isProSubscriber { return true }
        let (_, count) = triggerWindow()
        return count < triggerAnalysisMonthlyLimit
    }

    /// Records one trigger-analysis use. Call AFTER a successful API response.
    static func recordTriggerAnalysisUse() {
        guard !SubscriptionManager.shared.isProSubscriber else { return }
        var (start, count) = triggerWindow()
        if isExpired(start, windowDays: 30) {
            start = Date()
            count = 0
        }
        UserDefaults.standard.set(start.timeIntervalSinceReferenceDate, forKey: Key.triggerWindowStart)
        UserDefaults.standard.set(count + 1, forKey: Key.triggerUseCount)
    }

    /// Remaining trigger analyses in the current 30-day window.
    static var remainingTriggerAnalyses: Int {
        if SubscriptionManager.shared.isProSubscriber { return .max }
        let (_, count) = triggerWindow()
        return max(0, triggerAnalysisMonthlyLimit - count)
    }

    // MARK: - AI Coach

    /// Returns `true` when the user may use the AI Coach.
    /// Free tier: always `false`. Pro: always `true`.
    static func canUseAICoach() -> Bool {
        SubscriptionManager.shared.isProSubscriber
    }

    // MARK: - Window helpers

    /// Returns the current risk window's start date and use count.
    /// Auto-resets if the 7-day window has expired.
    private static func riskWindow() -> (start: Date, count: Int) {
        let raw   = UserDefaults.standard.double(forKey: Key.riskWindowStart)
        let start = raw == 0 ? Date() : Date(timeIntervalSinceReferenceDate: raw)
        if isExpired(start, windowDays: 7) {
            // Stale window — pretend it starts now with count 0.
            UserDefaults.standard.set(Date().timeIntervalSinceReferenceDate,
                                      forKey: Key.riskWindowStart)
            UserDefaults.standard.set(0, forKey: Key.riskUseCount)
            return (Date(), 0)
        }
        let count = UserDefaults.standard.integer(forKey: Key.riskUseCount)
        return (start, count)
    }

    /// Returns the current trigger window's start date and use count.
    /// Auto-resets if the 30-day window has expired.
    private static func triggerWindow() -> (start: Date, count: Int) {
        let raw   = UserDefaults.standard.double(forKey: Key.triggerWindowStart)
        let start = raw == 0 ? Date() : Date(timeIntervalSinceReferenceDate: raw)
        if isExpired(start, windowDays: 30) {
            UserDefaults.standard.set(Date().timeIntervalSinceReferenceDate,
                                      forKey: Key.triggerWindowStart)
            UserDefaults.standard.set(0, forKey: Key.triggerUseCount)
            return (Date(), 0)
        }
        let count = UserDefaults.standard.integer(forKey: Key.triggerUseCount)
        return (start, count)
    }

    private static func isExpired(_ start: Date, windowDays: Double) -> Bool {
        Date().timeIntervalSince(start) > windowDays * 86_400
    }

    // MARK: - Debug / testing

    #if DEBUG
    /// Resets all token counters. Use in unit tests or via the debug menu.
    static func resetAll() {
        UserDefaults.standard.removeObject(forKey: Key.riskWindowStart)
        UserDefaults.standard.removeObject(forKey: Key.riskUseCount)
        UserDefaults.standard.removeObject(forKey: Key.triggerWindowStart)
        UserDefaults.standard.removeObject(forKey: Key.triggerUseCount)
    }
    #endif
}

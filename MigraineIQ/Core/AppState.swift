//
//  AppState.swift
//  MigraineIQ
//
//  Global app state singleton — persists user preferences and onboarding
//  completion across launches via UserDefaults.
//
//  Rules:
//  - Stored properties + didSet for UserDefaults (computed properties break
//    @Observable's dependency tracking in SwiftUI).
//  - Singleton pattern: AppState.shared. Never instantiate a second one.
//  - All keys are namespaced under "appstate." to avoid collisions.
//

import Foundation
import Observation

@Observable
final class AppState {

    // MARK: - Singleton

    static let shared = AppState()

    // MARK: - Persisted state

    /// Set to true once the user completes all onboarding steps.
    /// Gating on this value in the root view shows onboarding on first launch.
    var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: Keys.hasCompletedOnboarding) {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    /// The user's first name, entered during onboarding.
    /// Empty string if the user skipped the name step.
    var userName: String = UserDefaults.standard.string(forKey: Keys.userName) ?? "" {
        didSet { UserDefaults.standard.set(userName, forKey: Keys.userName) }
    }

    // MARK: - Deep link / widget state (ephemeral — not persisted)

    /// Set to `true` by the URL handler when `migraineiq://quicklog` is opened.
    /// `QuickLogContentView` observes this and calls `viewModel.logNow()`,
    /// then immediately resets it to false.
    var pendingQuickLog: Bool = false

    /// The currently selected root tab index (0 = Today, 1 = Log, 2 = Insights, 3 = Settings).
    /// Set by the URL handler before raising `pendingQuickLog` so the Log tab
    /// is visible when the auto-log fires.
    var selectedTab: Int = 0

    // MARK: - Actions

    /// Marks onboarding as complete. Call this on the final onboarding step.
    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    // MARK: - Debug / Testing

    #if DEBUG
    /// Resets onboarding state so the flow can be re-triggered. Use in
    /// Settings debug builds or unit tests only.
    func resetOnboarding() {
        hasCompletedOnboarding = false
        userName = ""
    }
    #endif

    // MARK: - Keys

    private enum Keys {
        static let hasCompletedOnboarding = "appstate.hasCompletedOnboarding"
        static let userName               = "appstate.userName"
    }
}

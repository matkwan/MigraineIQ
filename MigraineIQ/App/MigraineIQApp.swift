//
//  MigraineIQApp.swift
//  MigraineIQ
//
//  App entry. Owns a single DependencyContainer and exposes it (and the
//  underlying SwiftData ModelContainer) to the entire view tree.
//
//  Onboarding gate
//  ─────────────────────────────────────────────────────────────────────────
//  AppRootView reads AppState.shared.hasCompletedOnboarding. On first
//  launch this is false, so OnboardingContentView is shown. The final
//  onboarding step calls AppState.shared.completeOnboarding(), flipping
//  the flag and causing AppRootView to swap in RootTabView automatically.
//
//  Background task note
//  ─────────────────────────────────────────────────────────────────────────
//  BGTaskScheduler handler registration lives in AppDelegate, wired via
//  @UIApplicationDelegateAdaptor. This is the only lifecycle point that is
//  guaranteed to fire before any @State default values are evaluated.
//  scheduleNightlyRun() is called from .task {} on the root view — after
//  the handler is already registered and DependencyContainer is configured.
//

import SwiftUI
import SwiftData

@main
struct MigraineIQApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var container = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(container)
                .modelContainer(container.modelContainer)
                // Schedule the nightly BGProcessingTask once the view is
                // live — guaranteed to be after registerHandler() has run.
                .task { BackgroundTaskCoordinator.shared.scheduleNightlyRun() }
                // Resolve current subscription state on every cold launch.
                .task { await SubscriptionManager.shared.refreshEntitlements() }
        }
    }
}

// MARK: - AppRootView

/// The root gate. Reads AppState (an @Observable) so SwiftUI re-renders
/// automatically when hasCompletedOnboarding flips from false → true.
/// Also handles the `migraineiq://quicklog` URL scheme used by the widget
/// to switch to the Log tab and auto-fire QuickLog.
private struct AppRootView: View {
    private let appState = AppState.shared

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                RootTabView()
            } else {
                OnboardingContentView()
            }
        }
        .onOpenURL { url in
            guard url.scheme == "migraineiq", url.host == "quicklog" else { return }
            // Switch to Today tab, then signal DashboardContentView to open
            // the new-attack sheet via the floating + button handler.
            // The brief delay lets the tab transition settle first.
            appState.selectedTab = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                appState.pendingQuickLog = true
            }
        }
    }
}

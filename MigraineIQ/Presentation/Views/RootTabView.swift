//
//  RootTabView.swift
//  MigraineIQ
//
//  The 5-tab shell that wraps everything. Reads the DependencyContainer
//  from the environment and hands it down to each tab's view.
//
//  Tab indices:
//    0 — Today (Dashboard)  ← floating + button opens new Attack form
//    1 — Calendar
//    2 — Medicine
//    3 — Insights
//    4 — Settings
//

import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(DependencyContainer.self) private var container
    @Bindable private var appState = AppState.shared

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            DashboardView()
                .tabItem { Label("Today", systemImage: "circle.hexagongrid.fill") }
                .tag(0)

            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(1)

            MedicationView()
                .tabItem { Label("Medicine", systemImage: "pills.fill") }
                .tag(2)

            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(3)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .tint(AppTheme.Colors.accent)
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

// MARK: - Previews ---------------------------------------------------------- TOBEFIXED

//#Preview {
//    RootTabView()
//        .environment(DependencyContainer.preview())
//        .modelContainer(SwiftDataStack.makeInMemory().container)
//}

//
//  RootTabView.swift
//  MigraineIQ
//
//  The 4-tab shell that wraps everything. Reads the DependencyContainer
//  from the environment and hands it down to each tab's view.
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

            LogView()
                .tabItem { Label("Log", systemImage: "plus.circle.fill") }
                .tag(1)

            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(2)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(3)
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

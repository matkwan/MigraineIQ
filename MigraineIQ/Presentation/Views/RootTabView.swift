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

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Today", systemImage: "circle.hexagongrid.fill")
                }

            LogView()
                .tabItem {
                    Label("Log", systemImage: "plus.circle.fill")
                }

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(AppTheme.Colors.accent)
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

#Preview {
    RootTabView()
        .environment(DependencyContainer.preview())
        .modelContainer(SwiftDataStack.makeInMemory().container)
}

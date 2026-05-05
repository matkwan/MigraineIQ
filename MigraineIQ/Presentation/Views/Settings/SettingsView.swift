//
//  SettingsView.swift
//  MigraineIQ
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Install ID")
                        Spacer()
                        Text(InstallIdentity.current.prefix(8) + "…")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Coming next") {
                    Text("Notification preferences (Phase 4)")
                    Text("HealthKit + WeatherKit permissions (Phase 4)")
                    Text("Subscription management (Phase 5)")
                    Text("Export data + privacy controls (Phase 6)")
                }
                .foregroundStyle(.secondary)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.Colors.background)
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}

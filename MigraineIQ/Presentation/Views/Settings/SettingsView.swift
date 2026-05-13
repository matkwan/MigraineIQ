//
//  SettingsView.swift
//  MigraineIQ
//
//  Shell view — reads the container from the environment, makes the
//  ViewModel, hands it to SettingsContentView. Required because @Environment
//  is not available inside `init()`.
//

import SwiftUI

struct SettingsView: View {
    @Environment(DependencyContainer.self) private var container

    var body: some View {
        #if DEBUG
        SettingsContentView(
            viewModel: container.makeSettingsViewModel(),
            onSeedSampleData: {
                await SampleDataSeeder.seed(
                    into: container.headacheRepository,
                    medicationRepo: container.medicationRepository
                )
            }
        )
        #else
        SettingsContentView(viewModel: container.makeSettingsViewModel())
        #endif
    }
}

// MARK: - Previews ---------------------------------------------------------- TOBEFIXED

//#Preview {
//    SettingsView()
//        .environment(DependencyContainer.preview())
//}

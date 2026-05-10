//
//  MedicationView.swift
//  MigraineIQ
//
//  Shell — reads DependencyContainer, creates MedicationViewModel, wraps
//  everything in a NavigationStack for pushing LogDoseView.
//

import SwiftUI

struct MedicationView: View {
    @Environment(DependencyContainer.self) private var container

    var body: some View {
        NavigationStack {
            MedicationContentView(
                viewModel: container.makeMedicationViewModel()
            )
        }
    }
}

// MARK: - Previews ---------------------------------------------------------- TOBEFIXED

//#Preview {
//    MedicationView()
//        .environment(DependencyContainer.preview())
//}

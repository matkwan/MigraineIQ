//
//  LogDoseView.swift
//  MigraineIQ
//
//  Shell — reads DependencyContainer and creates LogDoseViewModel.
//

import SwiftUI

struct LogDoseView: View {
    @Environment(DependencyContainer.self) private var container
    var editing: MedicationDose? = nil

    var body: some View {
        LogDoseContentView(
            viewModel: editing == nil
                ? container.makeLogDoseViewModel()
                : container.makeLogDoseViewModel(editing: editing!)
        )
    }
}

// MARK: - Previews ---------------------------------------------------------- TOBEFIXED

//#Preview {
//    NavigationStack {
//        LogDoseView()
//            .environment(DependencyContainer.preview())
//    }
//    .preferredColorScheme(.dark)
//}

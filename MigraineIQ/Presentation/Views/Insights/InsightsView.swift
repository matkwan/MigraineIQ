//
//  InsightsView.swift
//  MigraineIQ
//
//  Shell view — reads the DependencyContainer from the environment, creates
//  the TriggersViewModel via the factory, and passes it to InsightsContentView.
//  Required because @Environment is not available inside `init()`.
//

import SwiftUI

struct InsightsView: View {
    @Environment(DependencyContainer.self) private var container

    var body: some View {
        InsightsContentView(viewModel: container.makeTriggersViewModel())
    }
}

// MARK: - Previews ---------------------------------------------------------- TOBEFIXED

//#Preview {
//    InsightsView()
//        .environment(DependencyContainer.preview())
//}

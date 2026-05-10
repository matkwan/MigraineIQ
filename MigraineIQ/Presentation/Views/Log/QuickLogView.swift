//
//  QuickLogView.swift
//  MigraineIQ
//
//  Shell view — reads the DependencyContainer from the environment, creates
//  the QuickLogViewModel via the factory, and passes it to QuickLogContentView.
//  Required because @Environment is not available inside `init()`.
//

import SwiftUI

struct QuickLogView: View {
    @Environment(DependencyContainer.self) private var container

    var body: some View {
        QuickLogContentView(viewModel: container.makeQuickLogViewModel())
    }
}

// MARK: - Previews ---------------------------------------------------------- TOBEFIXED

//#Preview {
//    QuickLogView()
//        .environment(DependencyContainer.preview())
//}

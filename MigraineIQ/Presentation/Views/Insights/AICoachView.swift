//
//  AICoachView.swift
//  MigraineIQ
//
//  Shell view — reads the DependencyContainer from the environment, creates
//  the AICoachViewModel via the factory, and passes it to AICoachContentView.
//  Required because @Environment is not available inside `init()`.
//

import SwiftUI

struct AICoachView: View {
    @Environment(DependencyContainer.self) private var container

    var body: some View {
        AICoachContentView(viewModel: container.makeAICoachViewModel())
    }
}

// MARK: - Previews ---------------------------------------------------------- TOBEFIXED

//#Preview {
//    NavigationStack {
//        AICoachView()
//    }
//    .environment(DependencyContainer.preview())
//}

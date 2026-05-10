//
//  LogView.swift
//  MigraineIQ
//

import SwiftUI

struct LogView: View {
    @Environment(DependencyContainer.self) private var container

    var body: some View {
        QuickLogContentView(viewModel: container.makeQuickLogViewModel())
    }
}

// MARK: - Previews ---------------------------------------------------------- TOBEFIXED

//#Preview {
//    LogView()
//        .environment(DependencyContainer.preview())
//}

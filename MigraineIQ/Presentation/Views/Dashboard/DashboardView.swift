//
//  DashboardView.swift
//  MigraineIQ
//
//  Shell view — reads the container from the environment, makes the
//  ViewModel, hands it to the content view. Required because @Environment
//  is not available inside `init()`.
//

import SwiftUI

struct DashboardView: View {
    @Environment(DependencyContainer.self) private var container

    var body: some View {
        DashboardContentView(viewModel: container.makeDashboardViewModel())
    }
}

#Preview {
    DashboardView()
        .environment(DependencyContainer.preview())
}

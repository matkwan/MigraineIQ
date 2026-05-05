//
//  LogView.swift
//  MigraineIQ
//

import SwiftUI

struct LogView: View {
    @Environment(DependencyContainer.self) private var container

    var body: some View {
        LogContentView(viewModel: container.makeLogViewModel())
    }
}

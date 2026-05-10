//
//  ReportView.swift
//  MigraineIQ
//
//  Shell view — reads DependencyContainer, makes the ViewModel,
//  passes it to ReportContentView.
//

import SwiftUI

struct ReportView: View {
    @Environment(DependencyContainer.self) private var container

    var body: some View {
        ReportContentView(viewModel: container.makeReportViewModel())
    }
}

// MARK: - Previews ---------------------------------------------------------- TOBEFIXED

//#Preview {
//    ReportView()
//        .environment(DependencyContainer.preview())
//}

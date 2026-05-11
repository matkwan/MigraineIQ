//
//  HeadacheDetailView.swift
//  MigraineIQ
//
//  Shell view — receives the HeadacheEvent from the NavigationStack, reads
//  the DependencyContainer from the environment, and passes a fresh
//  HeadacheDetailViewModel to HeadacheDetailContentView.
//

import SwiftUI

struct HeadacheDetailView: View {
    let event: HeadacheEvent
    /// Pass `true` when creating a brand-new event so the form shows
    /// "Add Attack" and a Cancel button instead of "Edit Attack".
    var isNew: Bool = false
    @Environment(DependencyContainer.self) private var container

    var body: some View {
        HeadacheDetailContentView(
            viewModel: container.makeHeadacheDetailViewModel(event: event),
            isNew: isNew
        )
    }
}

// MARK: - Previews ---------------------------------------------------------- TOBEFIXED

//#Preview {
//    NavigationStack {
//        HeadacheDetailView(event: .mockOngoing)
//            .environment(DependencyContainer.preview())
//    }
//}

//
//  MigraineIQApp.swift
//  MigraineIQ
//
//  App entry. Owns a single DependencyContainer and exposes it (and the
//  underlying SwiftData ModelContainer) to the entire view tree.
//

import SwiftUI
import SwiftData

@main
struct MigraineIQApp: App {
    @State private var container = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(container)
                .modelContainer(container.modelContainer)
        }
    }
}

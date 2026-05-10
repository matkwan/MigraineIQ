//
//  SwiftDataStack.swift
//  MigraineIQ
//
//  Single source of truth for the SwiftData ModelContainer. CloudKit sync
//  is OFF by default for now — every cached model uses non-optional fields
//  for Codable round-trips. Flip `useCloudKit` to true and remove
//  `isStoredInMemoryOnly` once we're ready to enable iCloud sync (which
//  requires every property to be optional or have a default).
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataStack {
    let container: ModelContainer

    init(inMemory: Bool = false) {
        let schema = Schema([
            CachedHeadacheEvent.self,
            CachedAuraEvent.self,
            CachedMedicationDose.self,
            CachedWeatherSnapshot.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none      // change to .automatic when CloudKit is wired
        )
        do {
            self.container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    /// Convenience for previews and unit tests — pure in-memory stack.
    @MainActor
    static func makeInMemory() -> SwiftDataStack {
        SwiftDataStack(inMemory: true)
    }
}

//
//  ConcurrencyPatterns.swift
//  MigraineIQ
//
//  Reference patterns for Swift Concurrency used across the codebase. Not
//  meant to be called directly — kept as compileable examples so new
//  contributors can grep for the canonical shape.
//
//  Rules of thumb:
//   - ViewModels are @Observable @MainActor final class — no DispatchQueue.
//   - Repositories and Use Cases are NOT @MainActor — they hop off the main
//     thread automatically at each `await` boundary.
//   - Use `async let` for independent parallel fetches.
//   - Use `TaskGroup` for dynamic-fan-out (e.g. iterate N items in parallel).
//   - Use `actor` for shared mutable state with thread-safe access.
//

import Foundation

#if DEBUG
enum ConcurrencyExamples {

    // MARK: - Independent parallel fetch (async let) ---------------------
    //
    // Use when you have a small fixed number of independent calls and want
    // them to overlap. Both fetches start immediately; the await blocks
    // until both have finished.
    static func parallelDashboardLoad() async throws -> (todayRisk: String, recentAttacks: Int) {
        async let risk = fetchRisk()
        async let attacks = fetchRecentAttackCount()
        return (try await risk, try await attacks)
    }

    // MARK: - Dynamic fan-out (TaskGroup) -------------------------------
    //
    // Use when the number of parallel calls is determined at runtime (e.g.
    // refresh weather for N saved locations).
    static func refreshAll(locationIDs: [String]) async throws -> [String: Double] {
        try await withThrowingTaskGroup(of: (String, Double).self) { group in
            for id in locationIDs {
                group.addTask {
                    let pressure = try await fetchPressure(for: id)
                    return (id, pressure)
                }
            }
            var results: [String: Double] = [:]
            for try await (id, pressure) in group {
                results[id] = pressure
            }
            return results
        }
    }

    // MARK: - Actor for shared mutable state ----------------------------
    //
    // Used in this app for: SearchDebouncer, AIProxyService.
    actor ExampleCounter {
        private var count = 0
        func increment() { count += 1 }
        func value() -> Int { count }
    }

    // MARK: - Cooperative cancellation ----------------------------------
    //
    // Long-running operations should periodically check Task.isCancelled
    // or call try Task.checkCancellation() so they can be cancelled
    // when the user navigates away.
    static func longRunningWork() async throws -> [Int] {
        var results: [Int] = []
        for i in 0..<1000 {
            try Task.checkCancellation()
            results.append(i * 2)
        }
        return results
    }

    // ---- stubs to make the file compile ----
    private static func fetchRisk() async throws -> String { "low" }
    private static func fetchRecentAttackCount() async throws -> Int { 3 }
    private static func fetchPressure(for id: String) async throws -> Double { 1013.0 }
}
#endif

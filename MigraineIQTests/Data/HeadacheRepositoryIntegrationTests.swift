//
//  HeadacheRepositoryIntegrationTests.swift
//  MigraineIQTests
//
//  Integration test using a real in-memory SwiftData stack. Proves the
//  full Domain → Repository → LocalDataSource → SwiftData → back to Domain
//  path works without mocks.
//

import Testing
import Foundation
@testable import MigraineIQ

@MainActor
@Suite("HeadacheRepository integration")
struct HeadacheRepositoryIntegrationTests {

    private func makeSUT() -> HeadacheRepository {
        let stack = SwiftDataStack.makeInMemory()
        let local = HeadacheLocalDataSource(context: stack.container.mainContext)
        return HeadacheRepository(local: local)
    }

    @Test("save then fetchOngoing returns the saved event")
    func saveAndFetchOngoing() async throws {
        let sut = makeSUT()
        let ongoing = HeadacheEvent(
            startedAt: Date().addingTimeInterval(-1800),
            endedAt: nil,
            intensity: 6,
            classification: .migraineWithoutAura
        )
        try await sut.save(ongoing)

        let fetched = try await sut.fetchOngoing()
        #expect(fetched?.id == ongoing.id)
        #expect(fetched?.intensity == 6)
        #expect(fetched?.classification == .migraineWithoutAura)
    }

    @Test("fetchRecent returns events in newest-first order")
    func fetchRecentOrdering() async throws {
        let sut = makeSUT()
        let now = Date()
        for offset in [3600, 7200, 10800] {
            let event = HeadacheEvent(
                startedAt: now.addingTimeInterval(TimeInterval(-offset)),
                endedAt: now.addingTimeInterval(TimeInterval(-offset + 1800)),
                intensity: 5
            )
            try await sut.save(event)
        }

        let recent = try await sut.fetchRecent(limit: 5)
        #expect(recent.count == 3)
        // Newest first → smallest offset first.
        for i in 0..<(recent.count - 1) {
            #expect(recent[i].startedAt > recent[i + 1].startedAt)
        }
    }

    @Test("delete removes the event")
    func deleteRemovesEvent() async throws {
        let sut = makeSUT()
        let event = HeadacheEvent(intensity: 3)
        try await sut.save(event)
        try await sut.delete(id: event.id)
        let recent = try await sut.fetchRecent(limit: 5)
        #expect(recent.isEmpty)
    }
}

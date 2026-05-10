//
//  HeadacheRepositoryTests.swift
//  MigraineIQTests
//
//  Unit tests for HeadacheRepository using MockHeadacheLocalDataSource.
//
//  Why not a real SwiftData stack?
//  ─────────────────────────────────────────────────────────────────────────
//  SwiftData's FetchDescriptor<T> carries a `predicate: Predicate<T>?`
//  field. Predicate<T> is built on Swift parameter packs, and the runtime
//  reflection metadata for that generic is stripped from test-target
//  binaries that import the models via @testable import. The result is a
//  hard crash inside context.fetch() — not a thrown error, so try/catch
//  doesn't help. (rdar://SwiftData-ParameterPack-Reflection)
//
//  Fix: depend on HeadacheLocalDataSourceProtocol in the repository, and
//  swap in MockHeadacheLocalDataSource here. Zero SwiftData in the test
//  binary; the Data layer stays fully covered at the logic level.
//  ─────────────────────────────────────────────────────────────────────────

import Testing
import Foundation
@testable import MigraineIQ

@MainActor
@Suite("HeadacheRepository")
struct HeadacheRepositoryTests {

    let mock: MockHeadacheLocalDataSource
    let sut: HeadacheRepository

    init() {
        mock = MockHeadacheLocalDataSource()
        sut  = HeadacheRepository(local: mock)
    }

    // MARK: - save → fetchOngoing

    @Test("save then fetchOngoing returns the saved event")
    func saveAndFetchOngoing() async throws {
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

    // MARK: - fetchRecent ordering

    @Test("fetchRecent returns events newest-first")
    func fetchRecentOrdering() async throws {
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
        for i in 0..<(recent.count - 1) {
            #expect(recent[i].startedAt > recent[i + 1].startedAt)
        }
    }

    // MARK: - delete

    @Test("delete removes the event")
    func deleteRemovesEvent() async throws {
        let event = HeadacheEvent(intensity: 3)
        try await sut.save(event)
        try await sut.delete(id: event.id)

        let recent = try await sut.fetchRecent(limit: 5)
        #expect(recent.isEmpty)
    }

    // MARK: - error wrapping

    @Test("data-source error is wrapped in AppError.dataPersistence")
    func errorWrapping() async throws {
        struct FakeError: Error {}
        mock.errorToThrow = FakeError()

        await #expect(throws: AppError.self) {
            try await sut.fetchRecent(limit: 5)
        }
    }

    // MARK: - call tracking

    @Test("save delegates to upsert exactly once")
    func saveDelegatesToUpsert() async throws {
        let event = HeadacheEvent(intensity: 4)
        try await sut.save(event)

        #expect(mock.upsertCallCount == 1)
        #expect(mock.lastUpserted?.id == event.id)
    }

    @Test("delete delegates to delete exactly once")
    func deleteDelegatesToDelete() async throws {
        let event = HeadacheEvent(intensity: 4)
        try await sut.save(event)
        try await sut.delete(id: event.id)

        #expect(mock.deleteCallCount == 1)
        #expect(mock.lastDeletedId == event.id)
    }
}

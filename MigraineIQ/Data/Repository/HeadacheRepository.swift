//
//  HeadacheRepository.swift
//  MigraineIQ
//
//  Real implementation of HeadacheRepositoryProtocol. Right now it's a thin
//  pass-through to the local SwiftData store. When CloudKit sync is wired
//  in (Phase 4+), this is where the offline-first / stale-while-revalidate
//  logic will live.
//

import Foundation

@MainActor
final class HeadacheRepository: HeadacheRepositoryProtocol {
    private let local: HeadacheLocalDataSource

    init(local: HeadacheLocalDataSource) {
        self.local = local
    }

    func save(_ event: HeadacheEvent) async throws {
        do {
            try local.upsert(event)
        } catch {
            throw AppError.dataPersistence(error.localizedDescription)
        }
    }

    func fetchOngoing() async throws -> HeadacheEvent? {
        do { return try local.fetchOngoing() }
        catch { throw AppError.dataPersistence(error.localizedDescription) }
    }

    func fetch(in range: DateInterval) async throws -> [HeadacheEvent] {
        do { return try local.fetch(in: range) }
        catch { throw AppError.dataPersistence(error.localizedDescription) }
    }

    func fetchRecent(limit: Int) async throws -> [HeadacheEvent] {
        do { return try local.fetchRecent(limit: limit) }
        catch { throw AppError.dataPersistence(error.localizedDescription) }
    }

    func delete(id: UUID) async throws {
        do { try local.delete(id: id) }
        catch { throw AppError.dataPersistence(error.localizedDescription) }
    }
}

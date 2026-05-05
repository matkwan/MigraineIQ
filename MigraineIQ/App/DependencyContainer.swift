//
//  DependencyContainer.swift
//  MigraineIQ
//
//  Wires the entire dependency graph: SwiftData stack -> data sources ->
//  repositories -> use cases -> view models. Injected via .environment(...)
//  at the app root so any view can pull it via @Environment.
//
//  Two inits:
//    init() — production: real SwiftData + real repositories
//    init(headacheRepository:medicationRepository:modelContainer:) — tests
//

import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class DependencyContainer {

    // MARK: - Stored ----------------------------------------------------

    let modelContainer: ModelContainer
    let headacheRepository: HeadacheRepositoryProtocol
    let medicationRepository: MedicationRepositoryProtocol
    /// nil if APP_PROXY_URL/SECRET aren't set in Info.plist — UI surfaces
    /// a friendly message instead of crashing.
    let aiProxy: AIProxyService?

    // MARK: - Production init -------------------------------------------

    init() {
        let stack = SwiftDataStack()
        self.modelContainer = stack.container
        let context = stack.container.mainContext

        let headacheLocal   = HeadacheLocalDataSource(context: context)
        let medicationLocal = MedicationLocalDataSource(context: context)

        self.headacheRepository   = HeadacheRepository(local: headacheLocal)
        self.medicationRepository = MedicationRepository(local: medicationLocal)

        self.aiProxy = try? AIProxyService()
    }

    // MARK: - Test / preview init --------------------------------------

    init(
        headacheRepository: HeadacheRepositoryProtocol,
        medicationRepository: MedicationRepositoryProtocol,
        modelContainer: ModelContainer,
        aiProxy: AIProxyService? = nil
    ) {
        self.headacheRepository = headacheRepository
        self.medicationRepository = medicationRepository
        self.modelContainer = modelContainer
        self.aiProxy = aiProxy
    }

    // MARK: - ViewModel factories --------------------------------------

    func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(headacheRepository: headacheRepository)
    }

    func makeLogViewModel() -> LogViewModel {
        LogViewModel(headacheRepository: headacheRepository)
    }
}

#if DEBUG
extension DependencyContainer {
    /// Preview / canvas helper — pure in-memory, with mock data preloaded.
    static func preview() -> DependencyContainer {
        let stack = SwiftDataStack.makeInMemory()
        let mockHeadache = MockHeadacheRepository()
        mockHeadache.stubbedRecent = HeadacheEvent.mockList
        mockHeadache.stubbedOngoing = HeadacheEvent.mockOngoing
        return DependencyContainer(
            headacheRepository: mockHeadache,
            medicationRepository: MockMedicationRepository(),
            modelContainer: stack.container
        )
    }
}
#endif

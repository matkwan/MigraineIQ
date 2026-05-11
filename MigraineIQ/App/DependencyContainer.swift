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

    // MARK: - Stored --------------------------------------------------------

    let modelContainer: ModelContainer
    let headacheRepository:    HeadacheRepositoryProtocol
    let medicationRepository:  MedicationRepositoryProtocol
    let healthDataRepository:  (any HealthDataRepositoryProtocol)?
    let weatherRepository:     (any WeatherRepositoryProtocol)?

    /// nil if APP_PROXY_URL/SECRET aren't set in Info.plist — UI surfaces
    /// a friendly message instead of crashing.
    let aiProxy: AIProxyService?
    /// nil when aiProxy is nil (AI not configured). Use cases and ViewModels
    /// check for nil and degrade gracefully to "AI not configured" state.
    let aiInsightsRepository: (any AIInsightsRepositoryProtocol)?

    // MARK: - Production init -----------------------------------------------

    init() {
        let stack   = SwiftDataStack()
        self.modelContainer = stack.container
        let context = stack.container.mainContext

        let headacheLocal   = HeadacheLocalDataSource(context: context)
        let medicationLocal = MedicationLocalDataSource(context: context)

        self.headacheRepository   = HeadacheRepository(local: headacheLocal)
        self.medicationRepository = MedicationRepository(local: medicationLocal)

        // Phase 4: HealthKit + WeatherKit — always instantiated; queries
        // return nil/empty before the user grants permission.
        self.healthDataRepository = HealthDataRepository()
        self.weatherRepository    = WeatherRepository(context: context)

        let proxy = try? AIProxyService()
        self.aiProxy = proxy
        self.aiInsightsRepository = proxy.map { AIInsightsRepository(service: $0) }

        // Wire the nightly background task coordinator now that the
        // repository graph is fully constructed.
        // NOTE: scheduleNightlyRun() is NOT called here — BGTaskScheduler
        // rejects submit() unless registerHandler() has already run, but
        // @State default values are evaluated before App.init() body, so
        // this init executes before MigraineIQApp.init() can call
        // registerHandler(). scheduleNightlyRun() is deferred to the app's
        // first .task {} instead.
        BackgroundTaskCoordinator.shared.configure(
            headacheRepository:   headacheRepository,
            aiInsightsRepository: self.aiInsightsRepository
        )

        // Inject the repository and activate WatchConnectivity in one step so
        // the session is never activated before the repository is ready.
        WatchSessionReceiver.shared.headacheRepository = headacheRepository
        WatchSessionReceiver.shared.activate()
    }

    // MARK: - Test / preview init -------------------------------------------

    init(
        headacheRepository:   HeadacheRepositoryProtocol,
        medicationRepository: MedicationRepositoryProtocol,
        modelContainer:       ModelContainer,
        healthDataRepository: (any HealthDataRepositoryProtocol)? = nil,
        weatherRepository:    (any WeatherRepositoryProtocol)?    = nil,
        aiProxy:              AIProxyService?                      = nil,
        aiInsightsRepository: (any AIInsightsRepositoryProtocol)? = nil
    ) {
        self.headacheRepository   = headacheRepository
        self.medicationRepository = medicationRepository
        self.modelContainer       = modelContainer
        self.healthDataRepository = healthDataRepository
        self.weatherRepository    = weatherRepository
        self.aiProxy              = aiProxy
        self.aiInsightsRepository = aiInsightsRepository
    }

    // MARK: - ViewModel factories -------------------------------------------

    func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(
            headacheRepository:   headacheRepository,
            medicationRepository: medicationRepository,
            aiInsightsRepository: aiInsightsRepository
        )
    }

    func makeLogViewModel() -> LogViewModel {
        LogViewModel(headacheRepository: headacheRepository)
    }

    func makeQuickLogViewModel() -> QuickLogViewModel {
        QuickLogViewModel(headacheRepository: headacheRepository)
    }

    func makeHeadacheDetailViewModel(event: HeadacheEvent) -> HeadacheDetailViewModel {
        HeadacheDetailViewModel(event: event, headacheRepository: headacheRepository)
    }

    func makeTriggersViewModel() -> TriggersViewModel {
        TriggersViewModel(
            headacheRepository:   headacheRepository,
            aiInsightsRepository: aiInsightsRepository
        )
    }

    func makeAICoachViewModel() -> AICoachViewModel {
        AICoachViewModel(
            headacheRepository:   headacheRepository,
            medicationRepository: medicationRepository,
            aiInsightsRepository: aiInsightsRepository
        )
    }

    func makeMedicationViewModel() -> MedicationViewModel {
        MedicationViewModel(medicationRepository: medicationRepository)
    }

    func makeLogDoseViewModel() -> LogDoseViewModel {
        LogDoseViewModel(medicationRepository: medicationRepository)
    }

    func makeLogDoseViewModel(editing dose: MedicationDose) -> LogDoseViewModel {
        LogDoseViewModel(editing: dose, medicationRepository: medicationRepository)
    }

    func makeCalendarViewModel() -> CalendarViewModel {
        CalendarViewModel(headacheRepository: headacheRepository)
    }

    func makeMIDASTrendViewModel() -> MIDASTrendViewModel {
        MIDASTrendViewModel(headacheRepository: headacheRepository)
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(healthDataRepository: healthDataRepository)
    }

    func makeReportViewModel() -> ReportViewModel {
        ReportViewModel(
            generateReportUseCase: GenerateDoctorReportUseCase(
                headacheRepository:   headacheRepository,
                medicationRepository: medicationRepository
            ),
            renderer: DoctorReportPDFRenderer()
        )
    }
}

#if DEBUG
extension DependencyContainer {
    /// Preview / canvas helper — pure in-memory, with mock data preloaded.
    static func preview() -> DependencyContainer {
        let stack = SwiftDataStack.makeInMemory()
        let mockHeadache = MockHeadacheRepository()
        mockHeadache.stubbedRecent  = HeadacheEvent.mockList
        mockHeadache.stubbedOngoing = HeadacheEvent.mockOngoing
        return DependencyContainer(
            headacheRepository:   mockHeadache,
            medicationRepository: MockMedicationRepository(),
            modelContainer:       stack.container,
            healthDataRepository: MockHealthDataRepository(),
            weatherRepository:    MockWeatherRepository()
        )
    }
}
#endif

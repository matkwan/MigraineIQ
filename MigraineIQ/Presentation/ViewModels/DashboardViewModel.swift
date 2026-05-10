//
//  DashboardViewModel.swift
//  MigraineIQ
//
//  Drives the Today tab. Loads recent attacks (always), the 24-hour
//  AI risk forecast (only when an AI proxy is configured), and the
//  MOH Guardian assessment (always — computed locally from SwiftData).
//
//  Loading order within loadDashboard():
//    1. attacks + MOH (both local/fast) — rendered immediately
//    2. AI risk forecast (network/slow) — fills in once AI responds
//

import Foundation
import Observation

@Observable
@MainActor
final class DashboardViewModel {

    // MARK: - View state

    enum ViewState: Equatable {
        case idle
        case loading
        case success
        case failure(String)
    }

    /// State specific to the risk-forecast card, so an AI error never fails
    /// the whole dashboard.
    enum RiskState: Equatable {
        case unavailable          // AI proxy not configured
        case noData               // no attacks logged yet — nothing to forecast from
        case locked               // free-tier weekly limit reached
        case loading              // network request in flight
        case loaded(PredictiveAlert)
        case failed(String)
    }

    private(set) var viewState: ViewState = .idle
    private(set) var ongoingAttack: HeadacheEvent?
    private(set) var recentAttacks: [HeadacheEvent] = []

    private(set) var todayRisk: PredictiveAlert?
    private(set) var riskState: RiskState = .unavailable

    /// MOH Guardian assessment — nil until first local load completes.
    /// Always computed from SwiftData; never nil once loadMOH() has run.
    private(set) var mohRisk: MOHRiskAssessment?

    // MARK: - Dependencies

    private let headacheRepository: HeadacheRepositoryProtocol
    private let medicationRepository: MedicationRepositoryProtocol
    private let aiInsightsRepository: (any AIInsightsRepositoryProtocol)?

    // MARK: - Init

    init(
        headacheRepository: HeadacheRepositoryProtocol,
        medicationRepository: MedicationRepositoryProtocol,
        aiInsightsRepository: (any AIInsightsRepositoryProtocol)? = nil
    ) {
        self.headacheRepository   = headacheRepository
        self.medicationRepository = medicationRepository
        self.aiInsightsRepository = aiInsightsRepository
        self.riskState = aiInsightsRepository == nil ? .unavailable : .loading
    }

    // MARK: - Actions

    /// Hard-deletes an attack and refreshes the dashboard.
    func delete(_ event: HeadacheEvent) async {
        try? await headacheRepository.delete(id: event.id)
        DashboardViewModel.invalidateRiskCache()
        await loadAttacks()
        await loadRisk()
    }

    /// Refreshes local attack data and MOH assessment — no AI call.
    /// Used when returning from the HeadacheDetail edit form or LogDose
    /// form so changes appear immediately.
    func loadAttacks() async {
        async let ongoing = headacheRepository.fetchOngoing()
        async let recent  = headacheRepository.fetchRecent(limit: 5)
        if let (o, r) = try? await (ongoing, recent) {
            self.ongoingAttack = o
            self.recentAttacks = r
        }
        await loadMOH()
    }

    /// Loads attacks + MOH (local, fast), then the AI risk forecast (network, slow).
    /// Pass `force: true` (pull-to-refresh) to bypass the risk cache.
    func loadDashboard(force: Bool = false) async {
        viewState = .loading
        do {
            // Attack data and MOH are both local — run them in parallel.
            async let ongoing = headacheRepository.fetchOngoing()
            async let recent  = headacheRepository.fetchRecent(limit: 5)
            self.ongoingAttack = try await ongoing
            self.recentAttacks = try await recent
            self.viewState = .success
        } catch {
            self.viewState = .failure(ErrorPresenter.userMessage(for: error))
        }
        // MOH is purely local (SwiftData) — runs in <5 ms before the AI call.
        await loadMOH()
        await loadRisk(force: force)
    }

    // MARK: - MOH Guardian

    /// Computes the MOH risk assessment from the last 30 days of medication
    /// logs. Always succeeds — errors are swallowed silently so a SwiftData
    /// blip doesn't remove the card from the Dashboard.
    func loadMOH() async {
        let useCase = AssessMOHRiskUseCase(medicationRepository: medicationRepository)
        mohRisk = try? await useCase.execute()
    }

    // MARK: - AI risk forecast

    /// Requests a 24-hour risk forecast from the AI proxy.
    ///
    /// Caching behaviour:
    ///  - Serves the UserDefaults-cached alert if it hasn't expired yet and
    ///    `force` is false — no API call made.
    ///  - On API failure, falls back to the stale cached result rather than
    ///    showing an error (a yesterday forecast is better than nothing).
    ///  - No-ops silently when the AI proxy is not configured.
    ///  - Sets `.locked` when the user's free-tier weekly limit is exhausted.
    func loadRisk(force: Bool = false) async {
        guard let aiRepo = aiInsightsRepository else { return }

        // Free-tier gate — check before any network work.
        guard TokenGuard.canUseRiskForecast() else {
            // Still serve a stale cached result if one exists so the card
            // remains informative even after the limit is hit.
            if let stale = cachedRisk() {
                todayRisk = stale
                riskState = .loaded(stale)
            } else {
                riskState = .locked
            }
            return
        }

        // Minimum data guard — don't call the AI when there are no attacks
        // in the forecast window. An empty history produces a meaningless
        // generic score and wastes the user's free-tier quota.
        let windowStart = Date().addingTimeInterval(
            -ClinicalConstants.AI.riskPredictionWindowDays * 86_400
        )
        let windowInterval = DateInterval(start: windowStart, end: Date())
        let windowAttacks = (try? await headacheRepository.fetch(in: windowInterval)) ?? []
        guard !windowAttacks.isEmpty else {
            riskState = .noData
            return
        }

        // Serve from cache when fresh and not explicitly forced.
        if !force, let cached = cachedRisk(), !cached.isExpired {
            todayRisk = cached
            riskState = .loaded(cached)
            return
        }

        riskState = .loading
        let useCase = PredictMigraineRiskUseCase(
            headacheRepository: headacheRepository,
            aiRepository: aiRepo
        )
        do {
            let alert = try await useCase.execute()
            self.todayRisk = alert
            self.riskState = .loaded(alert)
            persistRisk(alert)
            TokenGuard.recordRiskForecastUse()
        } catch {
            // Prefer a stale cached result over a red error card.
            if let stale = cachedRisk() {
                self.todayRisk = stale
                self.riskState = .loaded(stale)
            } else {
                self.riskState = .failed(ErrorPresenter.userMessage(for: error))
            }
        }
    }

    // MARK: - Risk cache (UserDefaults)

    private static let riskCacheKey = "com.migraineiq.cachedRiskAlert"

    private func cachedRisk() -> PredictiveAlert? {
        guard let data = UserDefaults.standard.data(forKey: Self.riskCacheKey) else { return nil }
        return try? JSONDecoder().decode(PredictiveAlert.self, from: data)
    }

    private func persistRisk(_ alert: PredictiveAlert) {
        guard let data = try? JSONEncoder().encode(alert) else { return }
        UserDefaults.standard.set(data, forKey: Self.riskCacheKey)
    }

    /// Invalidates the cached risk forecast so the next Dashboard visit
    /// triggers a fresh calculation. Call this whenever new attack data is saved.
    ///
    /// Expiry strategy (not deletion):
    ///   The cache entry is kept but its expiresAt is set to .distantPast so
    ///   loadRisk() treats it as stale and re-fetches. If the device is offline
    ///   when re-fetch is attempted, the stale entry still serves as a fallback
    ///   rather than showing a red error card.
    static func invalidateRiskCache() {
        guard
            let data   = UserDefaults.standard.data(forKey: riskCacheKey),
            var cached = try? JSONDecoder().decode(PredictiveAlert.self, from: data)
        else {
            // Nothing cached yet — nothing to invalidate.
            return
        }
        cached.expiresAt = .distantPast
        if let updated = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(updated, forKey: riskCacheKey)
        }
    }
}

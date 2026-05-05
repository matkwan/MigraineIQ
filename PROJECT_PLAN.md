# MigraineIQ — Project Plan

> **Purpose of this document.** This file is a self-contained spec so a local LLM (or any new contributor) can pick up the project mid-stream without further context. Every phase, file, and contract is defined here. When in doubt, follow the rules in section 3 — they are non-negotiable.

---

## 1. Product overview

**What it is.** A clinical-grade migraine journal for iOS. Users log attacks (intensity, location, symptoms, aura, medication), and the app produces three high-value outputs: AI-detected personal triggers with confidence scores, 24-hour migraine risk predictions, and doctor-ready PDF reports classified to ICHD-3.

**Target user.** Chronic migraine sufferers who need detailed tracking for neurologist visits, insurance documentation (Botox / CGRP biologic approvals require ≥15 headache days/month for 3 months), and disability claims.

**Positioning.** "Built for the doctor visit, not the data broker." Privacy-first + clinical-grade. Medication Overuse Headache (MOH) Guardian is a flagship feature that competitors don't have.

**Top differentiators (vs. Migraine Buddy and others):**
1. **MOH Guardian** — warns at 8 days/month triptan use, hard alert at the ICHD-3 10-day threshold.
2. **Doctor-Ready PDF Reports** — ICHD-3 classification, MIDAS / HIT-6 scores, MOH risk flag, one-tap share.
3. **AI Predictive Alerts** — composes sleep + weather + cycle + history into 24h risk forecast.
4. **Personal Trigger Model** — confidence-scored, not generic checklists.
5. **AI Coach with 72h lookback** — answers "why did I get a migraine yesterday?" with cited data.
6. **Photophobia-first UX** — 1-tap log, OLED-black dark mode, Apple Watch + Lock Screen widget.

---

## 2. Tech stack

- **iOS 17+** (required for `@Observable`, SwiftData, modern WeatherKit)
- **SwiftUI** (no UIKit unless absolutely required)
- **SwiftData** for persistence (CloudKit sync deferred — see SwiftDataStack.swift comment)
- **HealthKit** for sleep, HRV, menstrual cycle (Phase 4)
- **WeatherKit** (Apple's native) for barometric pressure (Phase 4)
- **PDFKit** for doctor reports (Phase 5)
- **StoreKit 2** for subscription paywall (Phase 5)
- **BackgroundTasks** for nightly risk computation (Phase 4)
- **Cloudflare Worker** as AI proxy → routes to OpenAI GPT-4o
- **Auth** — shared secret (`X-App-Secret`) + per-install UUID (`X-Install-Id`). NOT App Attest.

**Bundle identifier:** `com.codevibelab.migraineiq`

---

## 3. Architecture rules (NON-NEGOTIABLE)

### 3.1 Layer rules

The app uses 5 layers. Dependencies flow strictly downward. **Never** import upward.

```
App/          →  Domain, Data, Presentation, Core   (allowed)
Presentation/ →  Domain, Core                       (NEVER Data — go through repos)
Data/         →  Domain, Core
Domain/       →  Foundation only (zero infra imports)
Core/         →  Foundation only
```

### 3.2 Layer-specific rules

**Domain/**
- Models are `struct` (value types), never `class`.
- Every model conforms to `Identifiable`, `Codable`, `Hashable`.
- No SwiftData, no SwiftUI, no URLSession imports. Foundation only.
- Repository contracts are `protocol` with `async throws` methods.
- Use Cases are `struct` with a single `execute(...)` method (Phase 2+).

**Data/**
- Implements Domain repository protocols.
- DTOs are separate from Domain models — `struct ...DTO: Codable` with `toDomain()` mappers.
- SwiftData `@Model` classes live in `Data/Local/` and have `Cached` prefix.
- `LocalDataSource` classes are `@MainActor` (SwiftData requirement).
- Repository implementations are `@MainActor`.

**Presentation/**
- ViewModels are `@Observable @MainActor final class`.
- **Never** `ObservableObject` / `@Published` — that's pre-iOS 17.
- ViewState enum lives **inside** the ViewModel, conforms to `Equatable`.
- **Shell + Content view split** is mandatory:
  - Shell: reads `@Environment(DependencyContainer.self)`, calls factory, passes ViewModel to Content.
  - Content: receives ViewModel as init param, stores as `@State`.
- Async actions wrapped in `Task { await viewModel.someAction() }`.

**Core/**
- App-wide concerns only: theme, error types, install identity, clinical constants.
- Nothing here depends on Domain, Data, or Presentation.

### 3.3 Naming conventions

| Thing | Convention | Example |
|---|---|---|
| Domain model | PascalCase, no suffix | `HeadacheEvent` |
| SwiftData @Model | `Cached` prefix | `CachedHeadacheEvent` |
| DTO | `DTO` suffix | `HeadacheEventDTO` |
| Repository protocol | `Protocol` suffix | `HeadacheRepositoryProtocol` |
| Repository impl | no suffix | `HeadacheRepository` |
| Mock | `Mock` prefix | `MockHeadacheRepository` |
| Use Case | `UseCase` suffix | `AssessMOHRiskUseCase` |
| ViewModel | `ViewModel` suffix | `DashboardViewModel` |
| Shell view | feature name | `DashboardView` |
| Content view | `ContentView` suffix | `DashboardContentView` |
| Test | `methodName_condition_result` | `test_loadDashboard_success_setsViewStateToSuccess` |

### 3.4 Concurrency

- ViewModels: `@Observable @MainActor final class`. No `DispatchQueue`.
- Use Cases / Repositories: not `@MainActor` — they hop off main automatically at `await`.
- Shared mutable state → `actor`.
- Independent parallel fetches → `async let`.
- Dynamic fan-out → `TaskGroup`.

### 3.5 No-ops

- No CocoaPods, no Carthage. SPM only if needed.
- No third-party libraries unless absolutely necessary. The only acceptable additions are Apple frameworks.
- No `print()` in shipped code — use a logger if/when one is added.
- No hard-coded strings for clinically-significant numbers — they belong in `Core/ClinicalConstants.swift`.
- No hex colors outside `Core/Theme/AppTheme.swift` — use `AppTheme.Colors.<name>`.

---

## 4. Current status (as of Phase 1 complete)

### ✓ Phase 0 — Project bootstrap
Xcode 16 project created, SwiftUI + SwiftData template.

### ✓ Phase 1 — Foundation + Architecture skeleton
5-layer folder structure, `DependencyContainer`, Domain models (`HeadacheEvent`, `MedicationDose`, `AuraEvent`, `ICHD3Classification`, supporting enums), SwiftData `@Model` classes with mappers, real + mock repositories, 4-tab Presentation shell, dark theme, install identity, 16 passing unit tests. See `PHASE_1_INTEGRATION.md` for Xcode integration steps.

### ⚠ Phase 2 — AI Integration (HALF DONE)
**Done:** Cloudflare Worker deployed, `AIProxyService.swift` (talks to `/v1/triggers`, `/v1/predict`, `/v1/coach`).
**Remaining:** Build `AIInsightsRepository` (implementing a new Domain protocol), the three Use Cases, the ViewModels, and the UI to surface AI output.

### ◯ Phase 3 — Core logging features
Photophobia-first QuickLog, full HeadacheDetail form, medication logging, MOH Guardian.

### ◯ Phase 4 — HealthKit + WeatherKit + background tasks
Real data sources for sleep / HRV / cycle / pressure. Nightly risk computation.

### ◯ Phase 5 — Doctor reports + monetisation
PDFKit-based doctor PDF, MIDAS/HIT-6 scoring, StoreKit 2 paywall.

### ◯ Phase 6 — Onboarding, notifications, polish, App Store prep

---

## 5. Reference files — what to copy when building new code

When a local LLM needs to generate a new file, point it at the matching reference file in the project so the style stays consistent.

| New file kind | Reference to read first |
|---|---|
| Domain model | `MigraineIQ/Domain/Models/HeadacheEvent.swift` |
| Domain enum | `MigraineIQ/Domain/Models/ICHD3Classification.swift` |
| Repository protocol | `MigraineIQ/Domain/Repositories/HeadacheRepositoryProtocol.swift` |
| Use Case | (no example yet — Phase 2 will produce the first) |
| SwiftData @Model | `MigraineIQ/Data/Local/CachedHeadacheEvent.swift` |
| LocalDataSource | `MigraineIQ/Data/Local/HeadacheLocalDataSource.swift` |
| Repository impl | `MigraineIQ/Data/Repository/HeadacheRepository.swift` |
| Mock repository | `MigraineIQ/Data/Repository/MockHeadacheRepository.swift` |
| DTO | `MigraineIQ/Data/Network/DTO/AIProxyDTOs.swift` |
| ViewModel | `MigraineIQ/Presentation/ViewModels/DashboardViewModel.swift` |
| Shell view | `MigraineIQ/Presentation/Views/Dashboard/DashboardView.swift` |
| Content view | `MigraineIQ/Presentation/Views/Dashboard/DashboardContentView.swift` |
| Domain unit test | `MigraineIQTests/Domain/HeadacheEventTests.swift` |
| ViewModel test | `MigraineIQTests/ViewModels/DashboardViewModelTests.swift` |
| Integration test | `MigraineIQTests/Data/HeadacheRepositoryIntegrationTests.swift` |

---

## 6. External services

### 6.1 Cloudflare Worker
- Deployed at `<your-worker>.workers.dev` (URL stored in `Config.xcconfig` → `APP_PROXY_URL`).
- Source: `CloudflareWorker/` in this repo.
- Endpoints:
  - `POST /v1/triggers` — body `{events, context}`, returns `{insights: [...]}`
  - `POST /v1/predict` — body `PredictionContextDTO`, returns `PredictiveAlertDTO`
  - `POST /v1/coach` — body `{question, context, conversationHistory}`, returns SSE stream
  - `POST /v1/health` — liveness check
- Auth headers (set by `AIProxyService`):
  - `X-App-Secret: <APP_PROXY_SECRET from Info.plist>`
  - `X-Install-Id: <UUID from InstallIdentity.current>`

### 6.2 Info.plist keys (must exist)
- `APP_PROXY_URL` → `$(APP_PROXY_URL)`
- `APP_PROXY_SECRET` → `$(APP_PROXY_SECRET)`

Both pull from `Config.xcconfig` (gitignored). If absent, `DependencyContainer` sets `aiProxy = nil` — UI must handle gracefully.

### 6.3 HealthKit (Phase 4)
Required Info.plist usage strings:
- `NSHealthShareUsageDescription`
- `NSHealthUpdateUsageDescription` (only if writing back)

Capabilities to enable in Xcode:
- HealthKit (with Background Delivery)
- Background Modes → Background fetch + Background processing

### 6.4 WeatherKit (Phase 4)
Required Info.plist:
- `NSLocationWhenInUseUsageDescription`

Capability: WeatherKit. Apple Developer Portal needs WeatherKit service enabled on the App ID.

---

## 7. Phase-by-phase build tickets

Each ticket below is sized for one focused work session. Reads like an issue tracker — feed one ticket at a time to the local LLM.

### PHASE 2 — AI Integration (finish)

#### Ticket 2.1 — Domain repository protocol for AI
**Create:** `MigraineIQ/Domain/Repositories/AIInsightsRepositoryProtocol.swift`
**Pattern:** Copy `HeadacheRepositoryProtocol.swift`.
**Methods:**
```swift
protocol AIInsightsRepositoryProtocol: Sendable {
    func recomputeTriggers(events: [HeadacheEvent], context: HealthContext) async throws -> [TriggerInsight]
    func predictNext24h(_ context: PredictionContext) async throws -> PredictiveAlert
    func askCoach(question: String, context: CoachContext, history: [CoachMessage]) -> AsyncThrowingStream<String, Error>
}
```
**Also create** the Domain types this protocol references (in `MigraineIQ/Domain/Models/`):
- `TriggerInsight.swift` — `id, trigger, confidence (0-1), occurrenceCount, lastObserved, strengthBand (weak/moderate/strong), explanation`
- `PredictiveAlert.swift` — `id, riskLevel (low/moderate/elevated/high), riskScore (0-100), primaryFactors, recommendedAction, expiresAt`
- `HealthContext.swift` — `sleep, hrv, weather, cycle, foodTags` arrays of value snapshots
- `PredictionContext.swift` — composes `knownTriggers, recentAttacks, currentContext`
- `CoachContext.swift` — `attacks, doses, sleep, weather, cycle, foodTags`
- `CoachMessage.swift` — `role (user/assistant), content`

**Acceptance:** All types compile. Each is `Identifiable, Codable, Hashable` where applicable. `+Mock.swift` companion file for each, with at least 2 mock instances.

#### Ticket 2.2 — Repository implementation
**Create:** `MigraineIQ/Data/Repository/AIInsightsRepository.swift`
**Job:** Wraps `AIProxyService`. Adds `toDomain()` / `fromDomain()` mapping between Domain types and DTOs in `AIProxyDTOs.swift`. Throws `AppError.ai(...)` on failure.

**Also create:** `MigraineIQ/Data/Repository/MockAIInsightsRepository.swift` following the pattern of `MockHeadacheRepository.swift`.

**Then update** `DependencyContainer.swift` to instantiate `AIInsightsRepository` (only when `aiProxy != nil`) and add a factory method `makeAICoachViewModel()`.

**Acceptance:** Compile passes. Existing tests still pass. Add a unit test for the DTO mapper round-trip.

#### Ticket 2.3 — Use Cases
**Create three files in** `MigraineIQ/Domain/UseCases/`:
- `AnalyzePersonalTriggersUseCase.swift` — gathers events from HeadacheRepo over last 90 days, builds `HealthContext` (Phase 4 will provide real data — use empty arrays for now), calls `recomputeTriggers`, returns `[TriggerInsight]`.
- `PredictMigraineRiskUseCase.swift` — composes `PredictionContext`, calls `predictNext24h`, returns `PredictiveAlert`.
- `AskAICoachUseCase.swift` — composes `CoachContext`, returns the `AsyncThrowingStream<String, Error>` from the repository unchanged.

Each Use Case is a `struct` with `init(repository:)` and a single `execute(...)` method.

**Acceptance:** Each Use Case has a unit test with a `MockAIInsightsRepository` proving the call shape.

#### Ticket 2.4 — Wire into Dashboard
**Modify** `DashboardViewModel.swift` to add:
- `var todayRisk: PredictiveAlert?`
- A `loadRisk()` method that calls `PredictMigraineRiskUseCase` (only when AI is configured)

**Modify** `DashboardContentView.swift` to replace the "Coming in Phase 2" placeholder with a real risk card showing `riskLevel`, `riskScore`, `primaryFactors`, and `recommendedAction`. Use `AppTheme.Colors.riskLow/Moderate/Elevated/High` based on `riskLevel`.

**Acceptance:** Run on Simulator. With a deployed worker, the Today tab shows a real AI risk forecast. Without a worker, it shows "AI not configured — see Settings."

#### Ticket 2.5 — Insights tab + AI Coach UI
**Create:** `Presentation/ViewModels/TriggersViewModel.swift`, `AICoachViewModel.swift` (with `[CoachMessage]` array, streaming token append).
**Create:** `Presentation/Views/Insights/InsightsContentView.swift` showing:
- Top section: list of `TriggerInsight` sorted by confidence, with a colored confidence badge.
- "Refresh triggers" button that calls `AnalyzePersonalTriggersUseCase`.
- "Ask the coach" link that pushes `AICoachView`.
**Create:** `Presentation/Views/Insights/AICoachView.swift` + `AICoachContentView.swift` — chat interface, message bubbles, streaming response token-by-token.

**Acceptance:** Real coach question → tokens stream into the UI. "What's my biggest trigger?" returns something sensible.

---

### PHASE 3 — Core logging features

#### Ticket 3.1 — QuickLog (photophobia-first)
**Create:** `Presentation/Views/Log/QuickLogView.swift` + `QuickLogContentView.swift` + `QuickLogViewModel.swift`.

**Behaviour:** Single huge "I'm having a migraine" button at the top of the Log tab. One tap → creates a `HeadacheEvent` with `phase = .headache`, `intensity = 5`, `classification = .undetermined`, `startedAt = now`. Saves immediately. Shows confirmation + a "wait, edit details" link.

**Constraints:** Button must be ≥80pt tall, accessible to a person with eyes barely open. Pure black background, single dim accent. No spinners, no animation, no haptics that fire repeatedly.

#### Ticket 3.2 — Full HeadacheDetail form
**Create:** `Presentation/Views/Log/HeadacheDetailView.swift` + content + viewModel.

**Sections:**
- Intensity (slider, 0-10, color-coded by `AppTheme.Colors.intensity()`)
- Type (picker, `ICHD3Classification.allCases`)
- Pain location (multi-select chips, `PainLocation.allCases`)
- Pain quality (multi-select chips, `PainQuality.allCases`)
- Symptoms (multi-select chips, `Symptom.allCases`)
- Aura (toggle → reveals AuraEvent sub-form)
- Triggers suspected (free-text tags, comma-separated)
- Notes (TextEditor)
- Disability impact (3 number fields: missed work, reduced productivity, bed rest hours)

**Accept** button saves via `HeadacheRepository.save(...)`.

#### Ticket 3.3 — Aura mapper
**Create:** `Presentation/Views/Log/AuraMapperView.swift`.
**Sections:** types (multi-select), visual disturbances (icon grid), sensory locations (body diagram — use SF Symbols `figure.arms.open` with overlay highlights for v1).

#### Ticket 3.4 — Medication logging
**Create:** `Presentation/Views/Medication/` — `MedicationView`, `MedicationContentView`, `LogDoseView`, `LogDoseContentView`, `MedicationViewModel`, `LogDoseViewModel`.

**LogDose form:** medication name, class picker (`MedicationClass.allCases`), dose mg (optional), purpose picker (`DosePurpose.allCases`), link to current ongoing attack (toggle).

**Medication tab list:** doses in last 30 days, grouped by class, day count visible.

#### Ticket 3.5 — MOH Guardian
**Create:** `Domain/Models/MOHRiskAssessment.swift`:
```swift
struct MOHRiskAssessment: Codable, Hashable {
    enum Level: String, Codable { case safe, approaching, atRisk, overuse }
    let triptanDaysThisMonth: Int
    let nsaidDaysThisMonth: Int
    let combinedAcuteDaysThisMonth: Int
    let level: Level
    let evaluatedAt: Date
    let explanation: String
}
```

**Create:** `Domain/UseCases/AssessMOHRiskUseCase.swift`. Algorithm:
1. Pull last-30-days doses from `MedicationRepository.distinctDays(forClass:in:)`.
2. For each MOH-causing class, compare distinct days vs `klass.mohThresholdDays`.
3. Compute `Level`:
   - Any class above threshold → `.overuse`
   - Any acute class at threshold-2 to threshold-1 → `.atRisk`
   - Any acute class at warning threshold → `.approaching`
   - Otherwise `.safe`
4. Build a human explanation citing the worst class.

**Create:** `Presentation/Views/Medication/MOHGaugeView.swift` — visual gauge component, colored per `AppTheme.Colors.mohSafe/Approaching/AtRisk/Overuse`.

**Wire:** Add MOH gauge to Dashboard. Trigger recompute every time a dose is logged.

**Acceptance:** Add 11 triptan doses on different days in the last 30 days → MOH level becomes `.overuse`. Test in `AssessMOHRiskUseCaseTests`.

---

### PHASE 4 — HealthKit + WeatherKit + background tasks

#### Ticket 4.1 — HealthKit gateway
**Create:** `Data/HealthKit/HealthKitGateway.swift`.

Wraps `HKHealthStore`. Methods:
- `requestAuthorization() async throws` for sleep, HRV, menstrual flow.
- `sleepHours(on date: Date) async throws -> Double?`
- `hrvAverage(on date: Date) async throws -> Double?`
- `cyclePhase(on date: Date) async throws -> CyclePhase?` (compute follicular/ovulatory/luteal/menstrual from last 90 days of menstrual flow data)

**Create:** `Domain/Models/CyclePhase.swift` enum.
**Create:** `Domain/Repositories/HealthDataRepositoryProtocol.swift` and `Data/Repository/HealthDataRepository.swift`.

#### Ticket 4.2 — WeatherKit gateway
**Create:** `Data/Weather/WeatherKitGateway.swift` wrapping `WeatherService.shared.weather(for: CLLocation)`.
**Create:** `Domain/Models/WeatherSnapshot.swift`, `WeatherRepositoryProtocol.swift`, `WeatherRepository.swift`.

Compute pressure delta over 6/12/24h windows in the repository. Cache `CachedWeatherSnapshot` (new SwiftData @Model).

#### Ticket 4.3 — Background risk computation
**Create:** `Core/Background/BackgroundTaskCoordinator.swift`.

Registers a `BGProcessingTaskRequest` with identifier `com.codevibelab.migraineiq.nightly-risk`. Wakes nightly. Runs `PredictMigraineRiskUseCase`. Persists the result. Schedules a notification via `UNUserNotificationCenter` if `risk >= .elevated`.

**Modify** `MigraineIQApp.swift` to register the task identifier in `init()`.

**Add Info.plist key:** `BGTaskSchedulerPermittedIdentifiers` array containing `com.codevibelab.migraineiq.nightly-risk`.

#### Ticket 4.4 — Settings: HealthKit permissions
Surface granular permission status in Settings. Allow user to re-request.

---

### PHASE 5 — Doctor reports + monetisation

#### Ticket 5.1 — Disability scoring use cases
**Create:** `Domain/UseCases/CalculateMIDASScoreUseCase.swift` and `CalculateHIT6ScoreUseCase.swift`. Both consume `[HeadacheEvent]` over the relevant window and return scores per `ClinicalConstants.MIDAS.Grade` / `ClinicalConstants.HIT6.Impact`.

#### Ticket 5.2 — Doctor PDF renderer
**Create:** `Domain/Models/DoctorReport.swift` (a value type containing all the data a report needs).
**Create:** `Domain/UseCases/GenerateDoctorReportUseCase.swift` (composes events, doses, MOH, MIDAS, HIT-6).
**Create:** `Data/PDF/DoctorReportPDFRenderer.swift` using PDFKit + `UIGraphicsPDFRenderer`. Returns a file URL.

**Create:** `Presentation/Views/Reports/ReportPreviewView.swift` showing the PDF in `PDFKitView`, with a Share button.

#### Ticket 5.3 — StoreKit 2 paywall
**Create:** `Core/Subscription/SubscriptionManager.swift` — `@Observable` singleton tracking entitlements via `Transaction.currentEntitlements`.
**Create:** `Presentation/Views/Paywall/PaywallView.swift`.
Product IDs:
- `com.codevibelab.migraineiq.pro.monthly` ($7.99/mo)
- `com.codevibelab.migraineiq.pro.annual` ($59/yr)
Both with 7-day free trial.
**Create:** `MigraineIQ.storekit` config file for Simulator testing.

#### Ticket 5.4 — TokenGuard
**Create:** `Core/Subscription/TokenGuard.swift` — gates AI calls per tier:
- Free: 3 predictive alerts/week, 1 trigger recompute/month, no coach.
- Pro: unlimited.

---

### PHASE 6 — Onboarding, notifications, polish, App Store prep

#### Ticket 6.1 — Onboarding
3-card carousel, name input, notification permission request, HealthKit permission request. `AppState.hasCompletedOnboarding` gates access to `RootTabView`.

#### Ticket 6.2 — Notification scheduling
- Predictive alert at 7am if `risk >= .elevated`.
- MOH warning when `level` first becomes `.approaching` or `.atRisk`.
- Both as Time Sensitive Notifications.

#### Ticket 6.3 — Polish
- `EmptyStateView` for Dashboard, Insights, Medication.
- `HapticService` enum.
- `ReviewService` — `SKStoreReviewController` after 3 / 10 / 25 logged attacks (once per app version).
- Settings screen complete (name, notification toggle, subscription mgmt, privacy policy link, version).

#### Ticket 6.4 — Lock Screen widget
Single 1-tap "Log attack now" intent.

#### Ticket 6.5 — Apple Watch complication
Same 1-tap log via `WKApplicationDelegate`.

#### Ticket 6.6 — App Store assets
- Screenshots in 6.7" + 6.5" sizes.
- Description copy, subtitle, 100-char keyword string.
- Privacy nutrition label: Health & Fitness data linked to user, not used for tracking.
- Marketing.html / privacy.html / support.html using the brand pattern.

---

## 8. Coding conventions cheat sheet

```swift
// VIEWMODEL TEMPLATE
import Foundation
import Observation

@Observable
@MainActor
final class FeatureViewModel {
    enum ViewState: Equatable {
        case idle
        case loading
        case success
        case failure(String)
    }

    private(set) var viewState: ViewState = .idle
    private let someUseCase: SomeUseCase

    init(someUseCase: SomeUseCase) {
        self.someUseCase = someUseCase
    }

    func loadSomething() async {
        viewState = .loading
        do {
            let result = try await someUseCase.execute()
            // ... assign result to stored properties
            viewState = .success
        } catch {
            viewState = .failure(ErrorPresenter.userMessage(for: error))
        }
    }
}

// SHELL VIEW TEMPLATE
struct FeatureView: View {
    @Environment(DependencyContainer.self) private var container
    var body: some View {
        FeatureContentView(viewModel: container.makeFeatureViewModel())
    }
}

// CONTENT VIEW TEMPLATE
struct FeatureContentView: View {
    @State var viewModel: FeatureViewModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
                // ...
            }
            .padding(AppTheme.Spacing.m)
        }
        .background(AppTheme.Colors.background)
        .task { await viewModel.loadSomething() }
        .refreshable { await viewModel.loadSomething() }
    }
}

// USE CASE TEMPLATE
struct SomeUseCase {
    private let repository: SomeRepositoryProtocol
    init(repository: SomeRepositoryProtocol) { self.repository = repository }
    func execute(_ input: SomeInput) async throws -> SomeOutput {
        // pure business logic, composes repositories
    }
}
```

---

## 9. Test conventions

- Framework: **Swift Testing** (`import Testing`), not XCTest.
- One `@Suite("Name")` per file.
- `@MainActor` on the suite if it tests `@MainActor` types.
- Test names: descriptive sentences, e.g. `@Test("intensity is clamped to 0...10 on init")`.
- `#expect(...)` for assertions, `Issue.record(...)` for explicit failure.
- Each ViewModel/UseCase test gets a fresh `MockXxxRepository` per test.
- Add at least one integration test per real repository (uses `SwiftDataStack.makeInMemory()`).

---

## 10. Useful prompts to paste into your local LLM

### General prompt prefix (always paste this first)

```
You are working on MigraineIQ, an iOS clinical migraine journal in Swift 5.10.

ARCHITECTURE: 5-layer Clean Architecture — App, Domain, Data, Presentation, Core.
Dependencies flow strictly downward. Domain is pure Swift (Foundation only).

NON-NEGOTIABLE RULES:
- Domain models are struct, value types, conform to Identifiable/Codable/Hashable.
- ViewModels are @Observable @MainActor final class. Never ObservableObject.
- ViewState enum lives inside the ViewModel, conforms to Equatable.
- Shell + Content view split is mandatory.
- DTOs are separate from Domain models with toDomain()/fromDomain() mappers.
- SwiftData @Model classes have "Cached" prefix and live in Data/Local.
- Tests use Swift Testing (@Suite, @Test, #expect), not XCTest.
- All clinical numbers (MOH thresholds etc) come from Core/ClinicalConstants.swift.
- All colors come from Core/Theme/AppTheme.swift.

Before generating, READ these existing files for style:
- Domain model:   MigraineIQ/Domain/Models/HeadacheEvent.swift
- Repository:     MigraineIQ/Data/Repository/HeadacheRepository.swift
- ViewModel:      MigraineIQ/Presentation/ViewModels/DashboardViewModel.swift
- Content view:   MigraineIQ/Presentation/Views/Dashboard/DashboardContentView.swift

Now do this task:
[paste ticket here]
```

### Per-ticket pattern

For each ticket in section 7, paste the prefix above followed by the ticket text. Local LLMs work best when you give them ONE file at a time. If a ticket lists multiple files, run the LLM N times.

### Verification prompt (after the LLM produces a file)

```
Review the file you just generated against these rules:
1. Does it import only what's necessary?
2. Are all types Sendable / @MainActor where needed?
3. Does it follow the naming conventions?
4. Are there any hardcoded clinical numbers (should be in ClinicalConstants)?
5. Are there any hardcoded hex colors (should be in AppTheme.Colors)?
6. Does the code compile in your head?
List any violations and fix them.
```

---

## 11. When to come back to Claude (the cloud LLM)

Use Claude for the high-leverage, low-token-volume tasks:

- **Architecture decisions** — "should I split this Use Case into two?"
- **Code review** — paste a generated file, ask "any architectural smells?"
- **Debugging weird Swift errors** — especially SwiftData / Concurrency / @Observable warnings
- **Phase planning** — "what should ticket N look like?"
- **Reviewing the Cloudflare Worker code** — JS / system design feedback
- **Writing the App Store description, privacy policy, marketing copy**

Use the local LLM for the bulk grunt work:

- Generating individual files following an existing pattern
- Adding new fields to existing models
- Writing more unit tests for existing logic
- Renaming things across the codebase
- Boilerplate (DTO mappers, mock repositories, simple CRUD views)

---

## 12. Build + run sanity check

Any time the local LLM finishes a ticket:

```bash
# From project root
xcodebuild -project MigraineIQ.xcodeproj \
           -scheme MigraineIQ \
           -destination 'platform=iOS Simulator,name=iPhone 16' \
           build 2>&1 | grep -E '(error|warning):'
```

Run the test suite:

```bash
xcodebuild -project MigraineIQ.xcodeproj \
           -scheme MigraineIQ \
           -destination 'platform=iOS Simulator,name=iPhone 16' \
           test 2>&1 | tail -50
```

If either fails, the LLM's output needs review before proceeding to the next ticket.

---

*Last updated: end of Phase 1. Update the "Current status" section in §4 every time a phase completes.*

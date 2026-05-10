# Session bootstrap

> **Start every new Claude/Cowork session by pasting the kickoff message in §1 below.** It tells the new model what's done, what's next, and where to look for the full spec.

---

## 1. Kickoff message — paste this into the new session

```
I'm continuing work on MigraineIQ, an iOS clinical migraine journal.

The project folder is already mounted at /Users/mkwan/Documents/GitHub/MigraineIQ.

Before doing anything else, please read these three files in order:
1. SESSION_BOOTSTRAP.md  — current state and decisions made
2. PROJECT_PLAN.md       — full architectural spec, ticketed phases 2-6
3. PHASE_1_INTEGRATION.md — Xcode integration steps if I haven't done them yet

Then ask me which ticket from PROJECT_PLAN.md §7 I want to tackle today,
or what specific question I have. Don't generate any code yet.
```

---

## 2. Where we are right now

**Phase 1 — done.** Architecture skeleton is in place:
- 5-layer Clean Architecture (App / Domain / Data / Presentation / Core)
- Domain models for `HeadacheEvent`, `MedicationDose`, `AuraEvent`, `ICHD3Classification`
- Repository protocols + real impls + mocks for Headache and Medication
- SwiftData `@Model` classes with round-trip mappers
- 4-tab shell (Today / Log / Insights / Settings) with working quick-log on the Log tab
- DependencyContainer wired
- 16 unit tests passing
- AppTheme dark palette tuned for photophobia
- ClinicalConstants centralised (MOH thresholds, MIDAS, HIT-6, chronic migraine criteria)

**Pending integration:** Files are on disk but not yet added to the Xcode project. See `PHASE_1_INTEGRATION.md`. Until that's done, the project won't build.

**Phase 2 — half done.** Cloudflare Worker is deployed and `AIProxyService` is built. Still need: `AIInsightsRepositoryProtocol`, the three Use Cases (triggers / predict / coach), and Insights/Coach UI. Tickets 2.1 → 2.5 in PROJECT_PLAN.md.

**Phase 3-6 — not started.** Detailed in PROJECT_PLAN.md §7.

---

## 3. Key decisions made (don't relitigate without reason)

| Decision | Why |
|---|---|
| Shared-secret auth for AI proxy, NOT App Attest | Simulator-only testing; complexity not worth it for a v1; can upgrade later. |
| Skipped `RATE_KV` for now | Worker tolerates missing KV; relying on OpenAI spend cap as the safety net until TestFlight. |
| SwiftData with CloudKit OFF | Will enable in Phase 4+ once we're ready to make all properties optional. |
| Swift Testing (`@Suite`/`@Test`) not XCTest | Matches Xcode 16 template; simpler. |
| `@Observable @MainActor final class` ViewModels | iOS 17+ baseline; never `ObservableObject`. |
| Shell + Content view split | Required because `@Environment` can't be used in `init()`. |
| DTOs separate from Domain models | Insulates Domain from API shape changes. |
| Bundle ID: `com.codevibelab.migraineiq` | |

---

## 4. What I have NOT set up yet

- Apple Team ID is unknown / placeholder.
- Apple Developer Portal App ID isn't registered (capabilities to enable: HealthKit, WeatherKit, iCloud, App Groups, In-App Purchase, Push Notifications, Time Sensitive Notifications, Data Protection).
- `Config.xcconfig` may not exist yet — copy from `Config.xcconfig.template` and fill in real `APP_PROXY_URL` + `APP_PROXY_SECRET`.
- `Info.plist` keys for `APP_PROXY_URL` and `APP_PROXY_SECRET` may not be wired to xcconfig yet.
- Phase 1 files are on disk but not added to the Xcode project (`PHASE_1_INTEGRATION.md` step 2 + 3).

If a new session asks "is X done?", these are the things most likely to be open.

---

## 5. Model recommendation

| Model | Use for |
|---|---|
| **Claude Sonnet 4.6** (default in Cowork) | Default. Architectural decisions, code review, multi-file refactors, debugging — everything we've been doing. |
| **Claude Haiku 4.5** | Quick lookups, single-file edits where you already know exactly what you want, summarising, naming things. Don't use for architecture. |
| **Local LLM (Llama / Qwen Coder / etc)** | Boilerplate file generation following an existing pattern. See PROJECT_PLAN.md §10 for the prompt prefix. |
| **Claude Opus** | Reserve for genuinely hard problems — novel system design, gnarly debugging where Sonnet has tried and failed. Don't make it the default. |

In Cowork, switch model: Settings → Model. The mounted folder, plugins, and skills carry across.

---

## 6. Workflow per ticket

1. Open the ticket in `PROJECT_PLAN.md` §7.
2. Decide: cheap-grunt (local LLM) or architectural (Sonnet)?
3. Read the reference file listed in PROJECT_PLAN.md §5 for that file kind.
4. Generate / edit the file.
5. Build:
   ```bash
   xcodebuild -project MigraineIQ.xcodeproj \
              -scheme MigraineIQ \
              -destination 'platform=iOS Simulator,name=iPhone 16' \
              build 2>&1 | grep -E '(error|warning):'
   ```
6. Test:
   ```bash
   xcodebuild -project MigraineIQ.xcodeproj \
              -scheme MigraineIQ \
              -destination 'platform=iOS Simulator,name=iPhone 16' \
              test 2>&1 | tail -50
   ```
7. Commit. Update PROJECT_PLAN.md §4 "Current status" if a phase completes.
8. Update §2 of THIS file if a key decision changes.

---

## 7. Files Claude/Cowork should read on every fresh session

In order, so context is built layer by layer:

1. `SESSION_BOOTSTRAP.md` (this file)
2. `PROJECT_PLAN.md` — full spec
3. `PHASE_1_INTEGRATION.md` — only if Xcode integration not done yet
4. `CloudflareWorker/SETUP.md` — only if AI work is in scope this session

If only updating one ticket, the model can usually skip 2–4 and just open the reference file from PROJECT_PLAN.md §5 plus the file being edited.

---

## 8. Token-saving tips

- **Be specific in your prompts.** "Implement Ticket 2.1" is much cheaper than "let's work on AI integration."
- **Don't ask Claude to read everything every time.** Once context is established in a session, just point at the specific files relevant to your current question.
- **Use Sonnet by default.** Switch to Opus only when Sonnet is visibly struggling (multiple wrong answers in a row).
- **Push boilerplate to the local LLM.** DTO mappers, mock repos, simple CRUD views — these don't need Claude.
- **Group related questions in one message** instead of sending five short ones — fewer "rebuild context" overheads.
- **End sessions cleanly.** Update §2 of this file with a one-line "where I left off" so the next session starts focused.

---

*Last session ended at: end of Phase 1 architecture, PROJECT_PLAN.md created, Phase 1 integration into Xcode pending. Next session should start with §1 kickoff message above.*

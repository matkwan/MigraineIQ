# Phase 1 — Xcode integration

Phase 1 dropped 30+ new files into the project on disk. Xcode doesn't
auto-pick them up; you need to add them to the project once. This file
walks through the few-minute integration.

## Step 1 — Delete the Xcode template files

These are no longer used. Delete the file references inside Xcode (right
click → Delete → Move to Trash):

- `MigraineIQ/MigraineIQApp.swift` (the original at the root — replaced by `App/MigraineIQApp.swift`)
- `MigraineIQ/ContentView.swift`
- `MigraineIQ/Item.swift`
- `MigraineIQ/Services/AIProxyService.swift`     (moved to `Data/Network/`)
- `MigraineIQ/Services/InstallIdentity.swift`    (moved to `Core/Identity/`)

After deleting in Xcode, also remove the now-empty folder on disk:

```bash
cd /Users/mkwan/Documents/GitHub/MigraineIQ
rmdir MigraineIQ/Services
```

## Step 2 — Add the new folders to the project

In Xcode's Project Navigator:

1. Right-click the **MigraineIQ** group (the one inside the project, not
   the very top one) → **Add Files to "MigraineIQ"…**
2. Select these five folders:
   - `App/`
   - `Core/`
   - `Domain/`
   - `Data/`
   - `Presentation/`
3. **Important options in the dialog:**
   - "Created groups" — selected (not "Folder references")
   - "Copy items if needed" — UNchecked (the files are already in place)
   - Add to targets: **MigraineIQ** ✓ (the app target)
4. Click **Add**.

Xcode will create the matching group structure and add every Swift file
inside.

## Step 3 — Add the new test files

1. Right-click the **MigraineIQTests** group → **Add Files to "MigraineIQ"…**
2. Select these folders inside `MigraineIQTests/`:
   - `Domain/`
   - `Data/`
   - `ViewModels/`
3. Same options as above, but Add to target: **MigraineIQTests** ✓ (NOT the
   app target).
4. Click **Add**.

Optionally delete the placeholder `MigraineIQTests/MigraineIQTests.swift` —
it just has an empty `example()` test.

## Step 4 — Verify Info.plist has the proxy keys

Phase 2 set these up but in case they aren't there yet — make sure
`Info.plist` has:

```
APP_PROXY_URL    : $(APP_PROXY_URL)
APP_PROXY_SECRET : $(APP_PROXY_SECRET)
```

Both pull from `Config.xcconfig` at build time. Without these the
`DependencyContainer` builds an `aiProxy = nil` and the AI features fail
gracefully (Phase 2 will surface a friendly UI for that case).

## Step 5 — Build and run

`Cmd-B` to build. You should get zero errors.

`Cmd-R` to run on Simulator. You should see:
- A 4-tab interface (Today, Log, Insights, Settings).
- Today tab showing "No attacks logged yet."
- Log tab with an intensity slider, type picker, and "Log this attack" button.
- Tap **Log this attack** → returns to "Saved." → switch back to Today and
  pull-to-refresh → the attack appears in the Recent list.
- Settings tab showing your install ID prefix.

If that works, the entire Domain → Repository → SwiftData → ViewModel →
View pipeline is wired correctly.

## Step 6 — Run the tests

`Cmd-U` to run the test suite. You should see ~14 tests pass:

- `HeadacheEventTests` (4) — Domain invariants
- `MedicationDoseTests` (4) — MOH thresholds
- `DashboardViewModelTests` (3) — ViewModel state transitions
- `CachedHeadacheEventMappingTests` (2) — round-trip mapping
- `HeadacheRepositoryIntegrationTests` (3) — full SwiftData pipeline

If a test fails, the architecture is broken somewhere — fix before moving
to Phase 2.

## Architecture summary

```
App/
  MigraineIQApp.swift         @main, owns DependencyContainer
  DependencyContainer.swift   wires entire graph

Domain/                       pure Swift, zero infra imports
  Models/                     HeadacheEvent, MedicationDose, AuraEvent, ICHD3, ...
  Repositories/               HeadacheRepositoryProtocol, MedicationRepositoryProtocol

Data/                         implements Domain contracts
  Network/                    AIProxyService + DTO/
  Local/                      SwiftDataStack, Cached@Model classes, LocalDataSources
  Repository/                 HeadacheRepository + Mock, MedicationRepository + Mock

Presentation/
  ViewModels/                 @Observable @MainActor classes
  Views/                      RootTabView + 4 tab pairs (Shell + Content split)

Core/
  Theme/                      Color+Hex, AppTheme palette
  Identity/                   InstallIdentity (Keychain UUID)
  ClinicalConstants.swift     MOH / MIDAS / HIT-6 / chronic migraine thresholds
  ErrorHandling.swift         AppError + ErrorPresenter
  ConcurrencyPatterns.swift   reference patterns (DEBUG only)
```

Data flows strictly downward. Nothing in `Domain/` imports `Data/` or
`Presentation/`. Nothing in `Data/` imports `Presentation/`. ViewModels
talk to repositories through protocols, never to SwiftData or URLSession
directly.

You're now ready for Phase 2.

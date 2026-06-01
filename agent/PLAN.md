# PullerBox iOS Native Migration Plan

## Goal

Migrate the deprecated Flutter prototype in `deprecated_flutter/lib` into a native Swift iOS app while following `docs/01-architecture.md`.

## Confirmed Decisions

- Rebuild as native SwiftUI instead of translating Flutter code line by line.
- Follow `SwiftUI + MVVM + Repository + Service + Store + CoreBluetooth`.
- First implementation uses simulated force data through the same repository/service boundary that real Bluetooth will later use.
- Do not migrate old Flutter local data.
- Migrate all prototype functionality.
- Rebuild UI with iOS-native SwiftUI patterns; do not perform pixel-level Material UI replication.
- Proceed autonomously by phases. User will review final outcome.

## Success Criteria

- The Swift app no longer uses the template `Item` / SwiftData sample flow.
- App structure follows `App`, `Features`, `Domain`, `Data`, `SharedUI`, and `Core`.
- Training tab supports plan training and free training.
- Plan library supports selection, creation, editing, deletion, reordering, and free-training mode.
- Monitor flow supports simulated device connection, live samples, charts, pause, previous/next phase, reset, exit, and save.
- Timed and free-training records persist locally with JSON File Store.
- Records tab supports list, detail, delete, clear all, calendar view, compare view, metric visibility, and seed data generation.
- Statistics logic is migrated to Swift and covered by focused tests.
- The project builds and tests run successfully, or blockers are recorded here.

## Architecture Mapping

- `View`: SwiftUI screens and reusable UI components.
- `ViewModel`: Observable page state and user actions.
- `RepositoryProtocol`: Stable domain-facing data interfaces.
- `Repository`: Composes stores and force-device services.
- `Service`: Simulated force data first; CoreBluetooth implementation later.
- `Store`: JSON file storage for plans, records, settings, and metric visibility.
- `Model`: Pure Swift domain objects, `Codable` where persistence is needed.

## Phases

1. [in-progress] Plan and progress log
   - Create this file.
   - Use this file to record checkpoints during migration.

2. [completed] Architecture skeleton
   - Create `App/AppContainer.swift`.
   - Replace template app entry with container-backed `RootView`.
   - Create top-level directories matching the architecture.

3. [completed] Domain, data, statistics
   - Migrate training plan, samples, timed records, free records, summaries, metric definitions.
   - Implement JSON File Store.
   - Implement repository protocols and repositories.
   - Port statistics calculator and seed record builder.
   - Add focused tests.

4. [completed] Training feature
   - Training home with plan/free mode.
   - Plan editing and plan selection.
   - Simulated device connection state.
   - Training monitor and free-training monitor with live charting.

5. [completed] Records and analysis feature
   - Record list and detail.
   - Calendar view.
   - Compare view.
   - Metric visibility settings.
   - Delete, clear all, and seed data generation.

6. [completed] Verification and cleanup
   - Remove obsolete template code.
   - Run tests.
   - Run build.
   - Record final status and any remaining risks.

## Progress Log

- 2026-06-01: Inspected architecture docs and Flutter prototype.
- 2026-06-01: Confirmed migration strategy with project owner through questions 1-6.
- 2026-06-01: Created migration plan and progress log.
- 2026-06-01: Added Swift native architecture skeleton, domain models, JSON stores, repositories, mock force service, training flow, records flow, statistics calculator, seed data generation, and focused tests.
- 2026-06-01: Removed the SwiftData template flow (`ContentView` and `Item`) and wired the app entry to `RootView`.
- 2026-06-01: `swiftc -typecheck -module-cache-path /private/tmp/pullerbox-module-cache pullerbox-ios/**/*.swift` passed.
- 2026-06-01: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -scheme pullerbox-ios -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/pullerbox-ios-deriveddata` passed.
- 2026-06-01: Full scheme test compiled and ran unit tests, but the template UI test runner timed out on accessibility initialization; the migrated unit tests passed.
- 2026-06-01: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme pullerbox-ios -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath /private/tmp/pullerbox-ios-deriveddata -only-testing:pullerbox-iosTests` passed.

# 00 — Bootstrap report

2026-10-28 · PLAN §0.2, steps 1–6 · Skeleton commit `chore: project skeleton` (folded into the 0.1.0 history's first commits on 2026-10-29) · **Waiting for review**

## Result

All five gates pass from a clean state: `make generate build test lint universal-check` exits 0 in 61 s. Getting there took nine changes to what PLAN.md specifies. Four of them fix problems in the plan itself that would have broken the build or the shipped bundle (deviations 1–4), so they need your approval and a matching PLAN.md amendment. Phase 0 has not started.

## Toolchain (step 2)

| Check | Plan | This Mac |
|---|---|---|
| macOS | 27.x | 27.0.1 (26A434). Software Update offers 27.2 (26B123) |
| Xcode | 27.1 or later | 27.1 (27A9275) |
| Swift | 6.4 or later | 6.4 (swiftlang-6.4.0.34.1) |
| SDK | 27.x | 27.0 |
| `uname -m` | arm64 | arm64 |
| Tools | installed | XcodeGen 2.46.0, SwiftLint 0.65.1, SwiftFormat 0.64.4 (`brew install` upgraded SwiftLint from 0.65.0 and SwiftFormat from 0.62.1) |
| Signing | an Apple Development and a Developer ID Application identity | Apple Development: Khanh Hoang (2HY96CNG4K) and Developer ID Application: Khanh Hoang (4XVYLW8RXS), both team 4XVYLW8RXS |
| Rosetta (needed by `universal-check`) | — | Missing; installed with `softwareupdate --install-rosetta --agree-to-license`, no admin prompt |

## What exists now

- **Root:** `CLAUDE.md` (Appendix B, verbatim), `project.yml`, `Makefile`, `.swiftlint.yml`, `.swiftformat`, `.gitignore`, `README.md`.
- **docs/:** `PLAN.md` (byte-identical to `~/Downloads/ORIEL-PLAN.md`), `checklist.md` (§13), `decisions/ADR-001-deployment-floor.md` (§2.2), `qa-checklists.md` (§14.6 plus a run log), `bootstrap.example.json` (§7.7.5), `provenance.md` (empty table), `os-quirks.md` (four findings from today), `spikes/` (empty) and this report.
- **App target `Oriel`:** `AppDelegate` is the entry point and shows a status item whose only command is Quit. `SelfTest` handles `--self-test`: it prints the running slice, the Rosetta state and the 13 linked packages, then exits 0. XcodeGen writes `App/Info.plist` and `App/Oriel.entitlements` from `project.yml`; both are committed. `Localizable.xcstrings` is empty (en).
- **CLI target `oriel-cli`** (binary `oriel`): answers `--help`; anything else exits 64.
- **13 packages** wired with the §6.2 dependency graph. Each has `<Name>Placeholder.packageName` and one Swift Testing test. SharedUI, WindowSwitcher, Capture, Recording and Editor default to MainActor isolation. OrielCore also ships `OrielTestSupport`, which holds the `.requiresTCC` trait.
- **App tests:** `OrielTests` has two Swift Testing tests: the self-test lists every package, and the CLI embedded in the test host runs. `OrielUITests` has one XCTest placeholder.

## Gate results (step 5, from a clean state)

| Gate | Result |
|---|---|
| generate | OK |
| build | Succeeded with no warnings (Debug and Release) |
| test | `OrielTests` 2 of 2 passed. `OrielUITests` compiled but not run (deviation 6). Packages: 13 tests passed, and the `.requiresTCC` test was skipped as intended. Run separately with `ORIEL_TCC_TESTS=1`, that test runs and passes. |
| lint | SwiftLint: no violations. SwiftFormat: 0 of 48 files need formatting |
| universal-check | `lipo`: `x86_64 arm64` for both `Contents/MacOS/Oriel` and `Contents/Helpers/oriel`. Self-test under `arch -x86_64`: `arch: x86_64`, `rosetta: true`. Native: `arch: arm64`, `rosetta: false`. `codesign --verify --deep --strict` passes |

## Deviations from PLAN.md

Fixes to the plan (please approve, then PLAN.md should be amended):

1. **The CLI lives at `Oriel.app/Contents/Helpers/oriel`, not `Contents/MacOS/oriel`.** APFS is case-insensitive by default, on this Mac and on users' Macs, so `MacOS/oriel` is the same path as the app's executable `MacOS/Oriel`. Embedding there would replace one binary with the other. The plan's `lipo -archs …/MacOS/oriel` check would read the app binary and pass even with no CLI at all. Apple documents `Contents/Helpers` as a place for helper tools. Changed: the copy phase in `project.yml`, the `lipo` path in the `Makefile`, and §13.7 in `docs/checklist.md`. This affects PLAN §6.1, §7.1.8 (symlink target), §13.7 and Appendices C and D.
2. **The CLI target is `oriel-cli`, as §6.2 names it (Appendix D says `oriel`), and its Swift module is `OrielCLI`.** Xcode names intermediate folders after the target (`Oriel.build`) and module files after the module, so names that differ only by case collide there too. This actually happened: the first build put the app's module inside `oriel.swiftmodule`, and the test build then failed with "Unable to resolve module dependency: 'Oriel'". The binary is still called `oriel`.
3. **The `Translation` package is now `OrielTranslation`.** The macOS 27 SDK ships `Translation.framework`. A module of ours with the same name would shadow it, and the Apple Translation provider could not `import Translation`.
4. **Packages use `swift-tools-version: 6.2`** (A.2 says 6.0). `.defaultIsolation(MainActor.self)` only exists from PackageDescription 6.2.

Smaller adjustments:

5. `DEVELOPMENT_TEAM` is set to `4XVYLW8RXS`, because manual signing fails with the `<TEAMID>` placeholder. Both test bundles get `GENERATE_INFOPLIST_FILE: YES`, because Xcode will not sign a test bundle without an Info.plist.
6. `make test` skips `OrielUITests` unless `ORIEL_UI_TESTS=1`. Automation Mode on this Mac requires authentication, so a UI test run would stop at an admin-password prompt (see decision 3). I did not try it, to avoid an unattended prompt.
7. `universal-check` passes `CONFIGURATION_BUILD_DIR=$(CURDIR)/build/Release`. With the relative path, Xcode built each package into `Packages/<X>/build/Release` and the app could not find the modules.
8. `.swiftlint.yml` sets `trailing_comma: { mandatory_comma: true }`, because SwiftLint's default forbids the trailing commas that SwiftFormat's default adds. It also excludes `Packages/*/.build`, where `swift test` writes generated Swift sources.
9. OrielCore has a second product, `OrielTestSupport` (A.2 says one product per package). Other packages' test targets can only reach the trait through a product.

Also: the branch is `main`, since git has no `init.defaultBranch` set. `.claude/settings.json` and `.claude/mcp.json` were already in the folder; they are personal settings and stay untracked.

## Not done yet, by design

- `scripts/` (`install.sh`, `release/*`), `ExportOptions.plist` and the tap belong to spike S0. Until then `make install` and `make release-dry-run` fail.
- `.github/workflows/` comes in Phase 1. `Spikes/` and `Tests/Fixtures/` will be created when first needed.
- The app icon (`Assets.xcassets`), the C target in PrivateAPIs and the image-diff helper arrive in Phase 1, with the first code that needs them.
- No checklist box is ticked; every item belongs to a later phase.

## Decisions for you

1. Approve deviations 1–9. I will then amend PLAN.md §6.1, §6.2, §7.1.8, §13.7 and Appendices A.1, A.2, C and D to match.
2. Package names: keep the current approach of renaming only the package that clashes, or prefix every package with `Oriel`, as D14 ("packages `Oriel*`") suggests.
3. UI tests: either run `automationmodetool enable-automationmode-without-authentication` once (needs admin), after which I put UI tests back into `make test`, or keep them opt-in.
4. Placeholders that S0 needs: `<ORG>`, `<FILEHOST>`, the `com.yourcompany` bundle-ID prefix, and `<SIGNING_NAME>` (presumably "Developer ID Application: Khanh Hoang (4XVYLW8RXS)").
5. The Developer ID Application certificate chains to the original Developer ID CA and expires on 2027-02-01. A replacement under the G2 CA is needed before the 1.0 release work (PLAN §15.2).
6. macOS 27.2 (26B123) is available. Appendix F item 8 says to update before recording spike results.

## Noticed, not changed

- `ORIEL_TCC_TESTS=1 make test` does not reach `OrielTests`. The scheme pins `ORIEL_TCC_TESTS` to 0, and xcodebuild only passes shell variables to tests when they carry a `TEST_RUNNER_` prefix. Package tests do see the variable. This needs fixing before the first app-level TCC test.
- In Debug, `xcodebuild -showBuildSettings` reports `ARCHS = arm64` because of `ONLY_ACTIVE_ARCH`. The §13.1 verify command needs `-configuration Release` to show `arm64 x86_64`.
- A Release `xcodebuild build` still carries `com.apple.security.get-task-allow`, which notarization rejects. Only the S0 archive and export path can produce a releasable build.
- The CLI's code-signing identifier is plain `oriel`, because the tool has no Info.plist. S0 could give it an explicit identifier.
- §2.3 says only WindowSwitcher links PrivateAPIs, but Appendix D also links it into the app. I kept Appendix D.

## Review outcome (2026-10-28)

You approved every recommendation. Here is what happened to each item.

| Item | Outcome |
|---|---|
| Deviations 1–9 | Kept. PLAN.md is now version 2.1 and describes them, and its Appendices A.4, B, C and D are exact copies of the repository files. |
| Package names (decision 2) | Plain names stay. Only `OrielCore` and `OrielTranslation` carry the prefix, and D14 now says so. |
| UI tests (decision 3) | Still opt-in. `automationmodetool enable-automationmode-without-authentication` needs your admin password; after that, `ORIEL_UI_TESTS=1 make test` runs them. |
| Placeholders (decision 4) | The team ID and signing identity are filled in. `<ORG>`, `<FILEHOST>` and the `com.yourcompany` prefix still need you. |
| Certificate expiry (decision 5) | Recorded as a risk in PLAN §16. Renewing it is your action. |
| macOS 27.2 (decision 6) | Recorded in Appendix F, item 8. Update before the spikes that run on the OS (S1–S7, S9). |
| `ORIEL_TCC_TESTS` did not reach `OrielTests` | Fixed. `make test` forwards it as `TEST_RUNNER_ORIEL_TCC_TESTS`, and `OrielTests` has a `.requiresTCC` test (through `OrielTestSupport`) that runs only when it arrives. |
| The §13.1 verify command showed `ARCHS = arm64` | Fixed; it now uses `-configuration Release`. |
| `get-task-allow` in Release builds | Kept on purpose, because Instruments needs it. PLAN §15.3 now says that only the `developer-id` export is notarized. |
| The CLI signed as `oriel` | Fixed. The CLI embeds an Info.plist and signs as `com.yourcompany.oriel.cli`. |
| §2.3 and Appendix D disagreed about PrivateAPIs | §2.3 now says no package other than WindowSwitcher depends on it. |
| Added | `make run` (Debug build, then launch), and CLAUDE.md rule 12: no two names may differ only by case. |

Phase 0 has started with S8, the SDK audit, because it needs neither permissions nor the OS update. See `docs/spikes/S8-sdk-audit.md`: the floor stays at 26.0, and the audit found one deprecation the plan must avoid (the callback-based `AVAssetExportSession` export).

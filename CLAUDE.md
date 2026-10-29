# Oriel — instructions for Claude Code

## Product
Internal menu-bar macOS utility: window switcher, screenshot/recording + editor, screenshot translation.
Developer ID signed, Hardened Runtime, notarized, NOT sandboxed. Deployment target macOS 26.0, built with the
macOS 27 SDK, primary target macOS 27. Universal binary (arm64 + x86_64); Intel is best-effort.
Swift 6 language mode, strict concurrency = complete. Zero runtime dependencies.

## Plan
docs/PLAN.md is the single source of truth. docs/checklist.md tracks progress. Phases run in order (PLAN §12);
human checkpoints: end of Phase 0, end of Phase 3, end of Phase 6, before tagging 1.0.

## Hard rules
1. Code is written from scratch. Reading open-source projects (e.g. alt-tab-macos) to learn private-API
   signatures or OS-quirk handling is fine; copying or paraphrasing their code is not. Record where each
   private-API signature came from in docs/provenance.md.
2. All private symbols go through Packages/PrivateAPIs via dlsym and are Optional. Never link private
   frameworks directly. Every private call has a public fallback or a disabled-feature path.
3. No polling: no Timer / DispatchSourceTimer outside an active Recording or ScrollingCapture session.
4. AppKit for overlays, panels, switcher and editor canvas. SwiftUI only for settings, onboarding, history,
   the translation panel and the language-pack download sheet.
5. APIs newer than 26.0 (26.4 Translation strategy, anything 27-only, Apple Intelligence features) go
   behind `#available` AND a FeatureGate; UI is hidden when unavailable. Intel/Rosetta are runtime gates.
6. Never call AX on the main thread in hot paths; use the AX actor with messaging timeout 0.25 s.
7. Secrets only in the Keychain. Logs use `privacy: .private` for user content.
8. Never read or write TCC.db. Permissions are checked only through AXIsProcessTrusted,
   CGPreflightScreenCaptureAccess, AVCaptureDevice and NSPasteboard.accessBehavior (Paste from Other Apps).
9. Keep ARCHS = "arm64 x86_64" explicit. Run `make universal-check` before finishing any task that touches
   build settings. Never pass -ld_classic.
10. No new SwiftPM dependencies, deployment-target changes or ARCHS changes without an explicit instruction.
    Test helpers live in-repo.
11. If an API in docs/PLAN.md is missing from the SDK or behaves differently, do not guess: check the SDK
    (PLAN Appendix E), record it in docs/os-quirks.md with the macOS build, and propose the change in the
    phase report.
12. Never give two targets, products, modules or bundle files names that differ only by case: the default APFS
    volume is case-insensitive, so `oriel` and `Oriel` are the same file (docs/os-quirks.md).
13. scripts/apple-credentials.env holds real Apple credentials. Never print it, copy its values anywhere or
    commit it; the release scripts read them from the environment after it is sourced (docs/RELEASING.md).
14. The release is `com.codertapsu.oriel`; Debug builds are `com.codertapsu.oriel.debug` ("Oriel Debug"). Never
    give a Debug build the release's bundle ID: macOS keeps one permission entry per bundle ID, signed by the
    build that asked first, and a Debug-signed entry locks the release out of Accessibility (docs/os-quirks.md).

## Workflow
- Follow the phases in order; tick a checklist item only after its Verify command passes; commit per item.
- Pure logic gets Swift Testing tests first. Tests needing Accessibility or Screen Recording use the
  `.requiresTCC` trait and run only with ORIEL_TCC_TESTS=1 on the dev Mac or the macOS 26 VM. UI tests
  (XCUITest) run only with ORIEL_UI_TESTS=1, because they need macOS Automation Mode.
- Commands: `make generate`, `make build`, `make run`, `make test`, `make lint`, `make universal-check`,
  `make install`, `make release-dry-run` (after `source scripts/apple-credentials.env`).
- Test on macOS 27 first, then the macOS 26 VM. Never add workarounds for macOS < 26.
- When an Apple API behaves differently between 26 and 27, note it in docs/os-quirks.md with the build number.
- End each phase with docs/reports/phase-N.md: what was built, what deviated from the plan, open questions.

## Style
- Protocol-first services in OrielCore; implementations in feature packages; DI through ServiceContainer.
- @Observable view models on @MainActor; services are actors; cross-module events via AsyncStream.
- One type per file, doc comments on public API, no force unwraps outside tests, no Combine.

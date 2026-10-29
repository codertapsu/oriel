# Oriel — Technical Design and Implementation Plan

**Version 2.6 · 2026-10-29 · Supersedes v2.5, v2.4, v2.3, v2.2, v2.1, v2.0 (consolidated), the v1 research plan and the v2 addendum**

**Changes in 2.6** (release 0.1.0, `docs/reports/02-clipboard-history.md`): Clipboard History is the second utility module (§7.9): it keeps text, links, colors, images, files and other data, encrypted at rest with a key in the Keychain, and opens a panel on ⌥V to search, preview, pin, reorder, delete and paste an item into the app in front. It notices copies without a timer, by comparing the pasteboard's change count after input events and app switches (§7.9 item 3, CLAUDE.md rule 3), and reads other apps' copies only as macOS's Paste from Other Apps allows, which is checked with `NSPasteboard.accessBehavior` (§8.1; CLAUDE.md rule 8 names it). Every interactive capture is also copied to the clipboard, on by default, so it is in Clipboard History even when Quick Access is closed with Esc (§7.2 item 8). Every write Oriel makes to the general pasteboard goes through `SharedUI.Pasteboard`, which announces it (§6.2). Modules that arrive in an update are turned on once (§6.3).

**Changes in 2.5** (release 0.1.0, `docs/reports/01-implementation.md`): the parts of §7 that the pre-release builds lacked are built. Capture has the live mode for video (Settings → Capture → Freeze the screen while selecting, off; §7.2 item 2) and Capture with Timer in the menu, as a shortcut, as `oriel://capture/timer` and as the CLI's `--delay` (§7.2 item 3, §7.1.8). Record Window records the picked window's frame (§7.4). The status menu has Pinned (§10.1). The editor has Quick Look on ⌘Y (§7.5). The switcher's display is a setting (§7.1.3). Google glossaries use Cloud Translation v3 with a service account key, because v3 takes no API keys (§7.7.2, §7.7.5). Models running on an Intel Mac carry a warning (§7.7.7, §11). Move to Applications hands over without a race (§15.6). CI runs `.github/workflows/ci.yml`, signing ad hoc (§15.7, Appendix C).

**Changes in 2.4** (pre-release testing): the bundle ID is `com.codertapsu.oriel` (D14), and Debug builds are `com.codertapsu.oriel.debug`, shown as "Oriel Debug" (§15 item 2, CLAUDE.md rule 14), because macOS keeps one permission entry per bundle ID and a Debug build's entry locked the notarized build out of Accessibility (`docs/os-quirks.md`); Debug and release keep separate settings and keychain items and never run at the same time; permissions are re-read when any app comes to the front and when macOS reports an Accessibility change, not only when Oriel is activated (§8.1); on macOS 27 the Accessibility pane is called "Device Control and Data Access", and the permission list names it.

**Changes in 2.3** (the feature-complete build, `docs/reports/01-implementation.md`): the §6.2 table matches the packages (Recording depends on OrielCore, Permissions and SharedUI and gets its region from the app through Capture's `selectRegion`, so it does not link Capture; OrielTranslation and Upload also use SharedUI; PrivateAPIs is Swift-only and loads no MultitouchSupport symbol, because the event tap's gesture events were enough, §7.1.5); the Info.plist gains an ATS exception for plain-HTTP `.internal` hosts and the `.oriel` document type (Appendix D); the build number is the commit count (§15); the §13 Verify scripts exist (`scripts/verify-windows.sh`, `verify-cmdtab-restore.sh`, `verify-recording.sh`, `idle-cpu.sh`, `perf-capture.sh`, helpers in `scripts/support/`), driven by two Debug-only verbs, `oriel debug record` and `oriel debug perf-capture`; `docs/BUILDING.md` documents building, signing, notarizing and packaging by hand, and `docs/APP_STORE.md` what a Mac App Store submission would take (a separate sandboxed edition; D3 is unchanged).

**Changes in 2.2:** releases are built, notarized and verified on the maintainer's Mac by `scripts/release/release-macos.sh`, with the `scripts/apple-credentials.env` file shared with Gitweaver and Mother Claude (Apple ID plus app-specific password), instead of in CI with an API key; `docs/RELEASING.md` is the runbook (§15).

**Changes in 2.1** (bootstrap review, `docs/reports/00-bootstrap.md`): the CLI is embedded at `Oriel.app/Contents/Helpers/oriel` (target `oriel-cli`, module `OrielCLI`), because in `Contents/MacOS` the name `oriel` is the app's own executable on a case-insensitive volume; the `Translation` package is `OrielTranslation`; packages use `swift-tools-version: 6.2`; UI tests are opt-in with `ORIEL_UI_TESTS=1`; `make test` forwards `ORIEL_TCC_TESTS` to the Xcode test bundles; `make run` launches a Debug build; the team ID and signing identity are filled in; Appendices A.4, B, C and D match the repository files; spike S8 answered Appendix F items 1 and 2.

Oriel is an internal, native macOS menu-bar utility with three tools: an AltTab-class window switcher, a snipping tool (screenshot, screen recording, editor) and instant screenshot translation. It is written from scratch in Swift 6 (AppKit + SwiftUI), targets macOS 26.0 and later, is built with the macOS 27 SDK, ships as a Universal binary, is Developer ID signed and notarized, is not sandboxed, and has zero runtime dependencies.

---

## 0. Instructions for Claude Code — read this first

### 0.1 What this document is

This is the single source of truth for Oriel: product requirements (§1), decisions (§2), system requirements (§3), feasibility (§4), stack (§5), architecture (§6), implementation approaches (§7), permissions (§8), performance (§9), UI/UX (§10), platform strategy (§11), roadmap (§12), checklist (§13), testing (§14), release (§15), risks (§16), future features (§17) and the project files to create (Appendices A–E).

Placeholders to replace once, everywhere: `<ORG>` (GitHub org or user), `<FILEHOST>` (internal HTTPS host for DMGs). Already filled in: the bundle ID, `com.codertapsu.oriel`, the Apple Team ID, `4XVYLW8RXS`, and the signing identity, `Developer ID Application: Khanh Hoang (4XVYLW8RXS)`.

### 0.2 Bootstrap procedure — do these in order, then stop and report

1. If this text arrived as a chat message, save it verbatim as `docs/PLAN.md`. Run `git init`, add a `.gitignore` (Appendix A.3) and commit.
2. Verify the toolchain and abort with a report if any check fails:
   ```bash
   sw_vers                                   # ProductVersion 27.x (26.x acceptable for a secondary machine)
   xcodebuild -version                       # Xcode 27.1 or later
   swift --version                           # Swift 6.4 or later
   xcrun --sdk macosx --show-sdk-version     # 27.x
   uname -m                                  # arm64
   brew --version && brew install xcodegen swiftlint swiftformat
   security find-identity -v -p codesigning  # at least one "Apple Development" and one "Developer ID Application"
   ```
3. Create `CLAUDE.md` (Appendix B, verbatim), `project.yml` (Appendix D), `Makefile` (Appendix C, recipes tab-indented), `.swiftlint.yml` and `.swiftformat` (Appendix A.4), `README.md` (purpose, the §3 requirements block, install commands from §15.6) and the `docs/` skeleton: `docs/checklist.md` (copy of §13), `docs/decisions/ADR-001-deployment-floor.md` (copy of §2.2), `docs/spikes/` (empty), `docs/provenance.md`, `docs/os-quirks.md`, `docs/qa-checklists.md` (copy of §14.6), `docs/bootstrap.example.json` (§7.7.5).
4. Scaffold the app target, the CLI target and every package in Appendix A.1 with one placeholder public type and one passing Swift Testing test each, plus the `.requiresTCC` trait (§14.2) in `OrielCore`'s test support target.
5. Run `make generate build test lint universal-check`. All five must pass on the empty skeleton.
6. Commit `chore: project skeleton`, then write `docs/reports/00-bootstrap.md` with what was created and anything that deviated from this document. Stop and wait for review.
7. On approval, start Phase 0 (§12.1).

### 0.3 Working rules

- Work phase by phase (§12) and, within a phase, task by task in the listed order. Tick a checklist box in `docs/checklist.md` only after its **Verify** command has passed. Commit after each ticked item with a message that names it.
- Human checkpoints (stop, write `docs/reports/<phase>.md`, wait): end of Phase 0 (spike go/no-go table), end of Phase 3 (switcher acceptance), end of Phase 6 (translation acceptance), before tagging 1.0. Otherwise continue to the next phase.
- Never add a SwiftPM dependency, change the deployment target, change `ARCHS`, or link a private framework directly without an explicit instruction from the user.
- If an API named in this document does not exist in the macOS 27 SDK, is deprecated, or behaves differently from what is described, do not guess. Check the SDK (Appendix E), record the finding in `docs/os-quirks.md` with the macOS build number, and propose the change in the phase report.
- Tests that need Accessibility or Screen Recording grants run only with `ORIEL_TCC_TESTS=1` on the dev Mac or the macOS 26 VM, never on hosted CI.
- Reference policy: reading open-source projects (for example `lwouis/alt-tab-macos`) to learn private-API signatures or how an OS quirk was handled is allowed. Copying or paraphrasing their code is not. Every private-API signature gets a line in `docs/provenance.md` saying where it came from (an `nm`/`dyld_info` dump, Apple documentation, or which project's behaviour was studied).
- Prefer the simplest implementation that meets the spec. Do not build abstractions for features that are not in this document.

---

## 1. Product requirements

### 1.1 Context

- Internal use only. Any approach, technology or private API is acceptable if it meets the requirements and is robust.
- Primary development and test machine: MacBook Pro with Apple M4 Pro, macOS 27.0.1 (26A434). Check Software Update before starting Phase 0 and record the build actually tested.
- An Apple Developer account with Developer ID signing is available.
- Target the latest macOS first. Older versions are supported only where it costs nothing; they are never a blocker.
- Minimum macOS version and hardware requirements, including supported chips, must be stated clearly to users (§3).
- Primary goals: native macOS integration; excellent performance and responsiveness; minimal CPU and memory; low battery consumption; smooth animations; reliable window management and screen capture; a beautiful, modern, intuitive UI; maintainable, modular, extensible code; room for future utility tools without architectural change.

### 1.2 Feature 1 — Window switcher ("find the right window, keep your flow")

- Every window, not just every app: all windows including minimized, hidden and windows on other Spaces, each with a badge for its location or state.
- Preview before switching: a full-size preview of the selected window above everything else.
- Native light and dark modes following the system appearance.
- Close, minimize or enter full screen directly from the switcher by hovering a thumbnail, without switching first.
- Display styles: window thumbnails, application icons, compact list of titles.
- Search by typing part of a window title or app name.
- Automatic sizing of previews based on the number of windows.
- Up to nine configurable shortcuts, each with its own key combination and filters.
- Instant switching (release keys to switch) or persistent mode (switcher stays open).
- Almost any key combination, with optional filtering by application, Space or screen.
- Accessibility: Sticky Keys, reduced transparency and other macOS accessibility features (VoiceOver polish deferred, see §2).
- Native on Apple silicon and Intel.
- Battery efficiency: no CPU use while idle.
- Command-line support to list and focus windows from Terminal or scripts.
- Fast and lightweight: minimal memory, storage and CPU.
- Trackpad gestures: switch windows with three-finger swipes.
- Application exceptions: exclude virtual machines, remote desktop apps and any other app.

Reference for behaviour only (no code reuse): AltTab (`github.com/lwouis/alt-tab-macos`, `alt-tab.app/features`).

### 1.3 Feature 2 — Snipping tool (screenshot and screen recording)

- Simple, fast capture similar to the Windows Snipping Tool: area, window, full screen.
- Screen recording as well as screen capture.
- Advanced image editor: annotations and markup tools, scrolling capture, cropping and other editing.
- Beautiful, intuitive interface with cloud sharing.
- Native macOS integration.

References for features and UX patterns only: CleanShot X, Monosnap, Snagit, Lightshot.

### 1.4 Feature 3 — Instant screenshot translation

- Capture any portion of the screen and instantly translate the text in it.
- Automatic text detection and extraction with OCR.
- Multiple source and target languages.
- Configurable translation provider: OpenAI API, Anthropic Claude API, local LLMs, Google Translate API, others (DeepL, Apple on-device).
- Configurable API keys, endpoints, models and provider-specific settings.
- A quick way to switch providers.
- Fast, intuitive workflow integrated with capture: capture region → translate → see the result.
- Fully offline translation where technically feasible (local models or Apple's on-device translation).

### 1.5 Non-goals for 1.0

Mac App Store distribution; sandboxing; localization of the app's own UI; VoiceOver polish; public documentation; supporting macOS 25 or earlier.

---

## 2. Decisions and assumptions

### 2.1 Decision log

| # | Decision | Rationale |
|---|---|---|
| D1 | **Deployment target macOS 26.0**, built with the **macOS 27 SDK (Xcode 27.1+)**, primary test target **macOS 27.x**. | ADR-001 (§2.2). |
| D2 | **Universal binary** (arm64 + x86_64). Apple silicon has the full feature set; Intel is best-effort, verified under Rosetta. | Intel costs two build settings and one smoke test. No hosted Intel CI, no mandatory physical Intel QA. |
| D3 | **Developer ID + Hardened Runtime + notarization. Not sandboxed.** Distributed through a **private Homebrew tap** (DMG on `<FILEHOST>`) and `make install`. No Sparkle, no public cask, no privacy manifest, no App Store path. | The switcher needs the Accessibility API, private SkyLight/HIServices symbols and event taps that consume keystrokes; sandboxed apps can use none of these. Notarization is one step of the local release script and removes Gatekeeper friction; Homebrew gives fleet updates with no in-app updater. |
| D4 | **Zero runtime dependencies.** Own Carbon hotkey engine and shortcut recorder; `SMAppService` called directly; in-repo image-diff test helper. | From-scratch codebase. |
| D5 | **Reference policy: read, don't copy** (see §0.3). | Internal use is not GPL distribution, and the code is ours regardless. Reading de-risks the private-API spikes. |
| D6 | **Private APIs are the primary path** for focus/Spaces (SkyLight), Cmd-Tab takeover (`CGSSetSymbolicHotKeyEnabled`) and, if needed, gestures (MultitouchSupport). Every symbol is loaded with `dlsym`, reported as a capability flag, and has a public fallback or a disabled-feature path. | Only breakage risk remains; the fallbacks exist for that. |
| D7 | **Stack: Swift 6 language mode, strict concurrency, AppKit for every panel/overlay/canvas, SwiftUI (hosted) for settings, onboarding, history, translation panel.** | §5. |
| D8 | **Recording through `SCRecordingOutput`** as the single pipeline; pause/resume by segment files concatenated at stop; GIF rendered from the finished MP4. | Available everywhere at this floor; the system handles encoding and audio mixing. |
| D9 | **Translation defaults:** Apple Translation (headless `TranslationSession`, offline) → internal Ollama/LM Studio endpoint → Foundation Models (Apple silicon with Apple Intelligence) → cloud providers. One `TranslationProvider` protocol. Endpoints and keys bootstrap from a shared config file. | Free, private and offline by default. |
| D10 | **OCR:** `RecognizeDocumentsRequest` primary (structure), `RecognizeTextRequest` for the low-latency path. | Floor 26. |
| D11 | **Materials:** `NSGlassEffectView` plus an opaque Reduce-Transparency path. No `NSVisualEffectView` branch. | Floor 26. |
| D12 | **Kept:** Reduce Transparency, Increase Contrast, Reduce Motion, Sticky Keys handling. **Deferred:** VoiceOver polish, localization. | Internal audience; the kept items are cheap and affect the glass panels. |
| D13 | **MDM is optional:** if the fleet is managed, a PPPC profile pre-grants Accessibility, lets standard users approve Screen Recording, and `forceBypassScreenCaptureAlert` suppresses the periodic screen-recording prompt. | Removes the biggest UX headache when available. |
| D14 | **Name: Oriel.** Bundle ID `com.codertapsu.oriel` (Debug builds `com.codertapsu.oriel.debug`, CLAUDE.md rule 14), CLI `oriel`, URL scheme `oriel://`, tap `homebrew-oriel`, packages under plain names, prefixed `Oriel` where the plain name is too generic or already taken (`OrielCore`; `OrielTranslation`, because the SDK ships `Translation.framework`). | A single find-and-replace if it ever changes. |

### 2.2 ADR-001: Deployment floor

**Status:** Accepted · **Date:** 2026-10-28

**Context.** The requirement is to use the latest frameworks, with older versions supported only when free. macOS 27 runs on Apple silicon only; macOS 26 is the last release for Intel Macs. The dev machine runs macOS 27.

**Options.**

| Option | Intel | Framework access | Cost |
|---|---|---|---|
| A: floor 27.0, arm64 only | None | Everything, including anything 27-only | Simplest build; drops all Intel Macs |
| B: floor 26.0, Universal, 27 SDK | Yes (four Intel models) | Everything that matters; 27-only APIs behind `#available(macOS 27, *)` | Two build settings, one Rosetta smoke test, a few availability checks |
| C: floor 15 or 14 | More Intel models | Loses headless `TranslationSession`, Foundation Models, `RecognizeDocumentsRequest`, `NSGlassEffectView` | A second code path for several features |

**Decision: B.** Every framework the app leans on arrived by macOS 26: `NSGlassEffectView`, the headless `TranslationSession(installedSource:target:)` initializer, FoundationModels, `RecognizeDocumentsRequest`, the richer `SCScreenshotManager` configuration, plus `SCRecordingOutput` and ScreenCaptureKit microphone capture (15) and the Swift Vision API (15). The 27-specific changes known so far are toolchain-level: Swift 6.4, removal of the ld64 linker (`-ld_classic` no longer accepted), `ARCHS_STANDARD` dropping x86_64 for 27.0+ deployment targets, and apps losing direct access to the TCC database. A 27 floor would drop every Intel Mac for no API gain.

**Consequences.** Any 27-only API goes behind `#available(macOS 27, *)` with the 26 behaviour as the fallback. If the Phase 0 SDK audit (Appendix E) finds a 27-only API that is worth more than Intel support, raise `deploymentTarget` to 27.0 and drop `x86_64`; that is a two-line change in `project.yml` plus removing the Rosetta job. Intel verification is Rosetta-only unless a physical Intel Mac is available.

### 2.3 Assumptions

1. Direct distribution only (D3). If App Store distribution were ever wanted, the switcher is not viable there; capture and translation could ship as a separate sandboxed app using `SCContentSharingPicker`, Vision and Translation. No package other than `WindowSwitcher` depends on `PrivateAPIs` (the app target links it as well, for the Diagnostics flags), so that split stays possible.
2. Minimum tooling: Xcode 27.1 (Swift 6.4), macOS 27 SDK, XcodeGen, SwiftLint, SwiftFormat.
3. The internal fleet runs macOS 26 or 27. Nothing older is tested or worked around.

---

## 3. System requirements

### 3.1 User-facing statement (README and About)

```
Oriel system requirements

macOS:         macOS 26 Tahoe or later. Developed and tested on macOS 27.
Apple silicon: M1 or later — all features.
Intel:         Supported on the Intel Macs that run macOS 26: MacBook Pro 16" (2019),
               MacBook Pro 13" four-port (2020), iMac 27" (2020), Mac Pro (2019).
               Best-effort: no on-device AI features; slower OCR and video encoding.
On-device AI:  The Foundation Models translation provider and Apple Translation's
               high-fidelity strategy need an Apple silicon Mac with Apple Intelligence
               turned on and a supported language/region.
Offline use:   Apple Translation language packs (downloaded on first use) or a local /
               internal LLM endpoint. OCR is always on-device.
Trackpad:      Three-finger gestures need a built-in Multi-Touch trackpad or a Magic
               Trackpad, with the system's three-finger Spaces gesture moved to four fingers.
Permissions:   Accessibility (required). Screen & System Audio Recording (capture, recording,
               window thumbnails). Microphone and Camera (optional, recording only).
Memory:        8 GB minimum. 16 GB recommended when running a local LLM on the same Mac.
```

### 3.2 Enforcement

- `LSMinimumSystemVersion = 26.0` in Info.plist (Finder refuses to launch on older systems with a clear alert).
- `Capabilities` (in `OrielCore`) is computed once at launch and shown in Settings → About → Diagnostics, and printed by `oriel debug capabilities --json` in Debug builds:
  - `arch`: `#if arch(arm64)` per slice; `isRosetta` via `sysctlbyname("sysctl.proc_translated")`; `isAppleSiliconHardware` via `hw.optional.arm64` (true even under Rosetta).
  - `appleIntelligence`: `SystemLanguageModel.default.availability` (`.available` / `.unavailable(reason)`), re-checked on `NSApplication.didBecomeActiveNotification`.
  - `translationPacks`: `LanguageAvailability().status(from:to:)` for the configured pair.
  - `privateSymbols`: one flag per `dlsym` lookup.
  - `permissions`: `AXIsProcessTrusted()`, `CGPreflightScreenCaptureAccess()`, `AVCaptureDevice.authorizationStatus(for:)` for audio and video.
- First launch on Intel shows a one-time banner: "Running on Intel: on-device AI features are unavailable."
- First launch under Rosetta (x86_64 slice on Apple silicon hardware) shows "Running under Rosetta; reinstall the Universal build" and logs it. This only happens when someone runs `arch -x86_64` deliberately or a build is broken.

---

## 4. Feasibility analysis

### 4.1 Window switcher

| Requirement | Feasible | How | Limitation / risk |
|---|---|---|---|
| All windows incl. minimized, hidden, other Spaces, full screen | Yes, with private APIs | `CGWindowListCopyWindowInfo(.optionAll)` for discovery, SkyLight `SLSCopy…Spaces` calls for Space membership, AX (`kAXWindowsAttribute`) for titles and actions, `_AXUIElementCreateWithRemoteToken` for AX elements of windows on other Spaces | AX only returns windows on the current Space. Native tabs are inconsistent: the SkyLight window list omits minimized, hidden and tabbed windows, whereas `CGWindowListCopyWindowInfo` lists them all. |
| State badges | Yes | `kAXMinimizedAttribute`, `NSRunningApplication.isHidden`, `kAXFullScreenAttribute`, Space and display IDs | Space identity is unstable across reboots; show "Space 3" / "Other Space", never names |
| Full-size preview | Yes (Screen Recording) | ScreenCaptureKit window capture at native resolution in a separate panel | Minimized windows cannot be captured live; show the last cached image or the app icon |
| Close / minimize / full screen from hover | Yes | AX: `kAXCloseButtonAttribute` → `AXPress`, `kAXMinimizedAttribute = true`, `AXFullScreen` attribute | Electron and Java apps implement AX poorly; test each action per app |
| Thumbnails / icons / title list | Yes | Same model, three renderers | — |
| Search, auto-size | Yes | Pure functions | — |
| Nine shortcuts with filters | Yes | Event tap + shortcut table | Cmd-Tab takeover needs the private symbolic-hotkey switch or consuming Cmd-Tab in the tap |
| Release-to-switch vs keep-open | Yes | `flagsChanged` tracking in the tap | Sticky Keys latches modifiers, so "release" fires immediately (§7.1.4) |
| Accessibility options | Yes | `NSWorkspace` accessibility display options | VoiceOver focus does not enter a non-activating panel by default (deferred) |
| Zero CPU at idle | Yes | AXObserver + NSWorkspace notifications; no timers | The tap callback runs on keystrokes; negligible |
| CLI list/focus | Yes | Bundled CLI over a Unix domain socket | — |
| Three-finger swipe | Yes, with caveats | Gesture events in the event tap; private MultitouchSupport as fallback | Conflicts with the system's three-finger Spaces swipe; the user moves Mission Control to four fingers |
| App exceptions | Yes | Bundle-ID rules | — |

### 4.2 Snipping tool

All features are feasible with public APIs. ScreenCaptureKit covers screenshots (`SCScreenshotManager`), streaming and recording (`SCStream`, `SCRecordingOutput`), system audio and microphone. Two areas carry real risk: **scrolling capture** is heuristic and fails on sticky headers, parallax, lazy loading and animated content (mitigations in §7.3), and the **periodic Screen Recording re-confirmation** introduced in macOS 15 cannot be suppressed outside MDM.

### 4.3 Screenshot translation

Fully feasible. Vision OCR is mature; the Translation framework is on-device and, from macOS 26, usable without SwiftUI; cloud LLMs and machine-translation APIs are plain HTTPS. Weak spots: vertical CJK and stylized text (offer an "AI Vision" mode that sends the image to a vision LLM), font fitting when the translation is longer than the source, and Apple Translation needing a known source language (use the OCR-detected language, then `NLLanguageRecognizer`).

---

## 5. Technology stack

### 5.1 Comparison

| Stack | Window/AX/private APIs | ScreenCaptureKit | Overlay latency, idle CPU | Memory | Native look (Liquid Glass) | Verdict |
|---|---|---|---|---|---|---|
| **Swift: AppKit + SwiftUI hybrid** | Direct | Direct | Best; zero idle achievable | ~30–60 MB | Full (`NSGlassEffectView`, `glassEffect()`) | **Chosen** |
| Pure SwiftUI | Through AppKit bridges anyway | Direct | Panel/window-level control awkward; layout cost in hot paths | Similar | Full | Rejected for overlays and the editor; used for settings |
| Objective-C + AppKit | Direct | Direct | Excellent | Low | Full | No advantage over Swift; worse safety and concurrency |
| Electron | Native addons for everything | Addon | Chromium idle wakeups; 150 MB+ | High | Imitation | Rejected |
| Tauri (Rust + WebView) | Rust FFI | Crates exist | WebView overlays slow to show | Medium | Partial | Rejected |
| Flutter | Platform channels | Plugins | Engine overhead; non-native widgets | Medium-high | Imitation | Rejected |
| Qt | Obj-C++ glue | Glue | OK | Medium | Non-native | Rejected |

Every hard requirement (non-activating panels at custom levels, event taps, AX, SkyLight, ScreenCaptureKit, Vision, Translation) is a native Swift/AppKit API. Cross-platform stacks would wrap all of it in native code anyway and add runtime cost, which works against the idle-CPU, memory and battery goals.

### 5.2 Chosen technologies

| Area | Choice |
|---|---|
| Language | Swift 6.4, Swift 6 language mode, `SWIFT_STRICT_CONCURRENCY = complete`, main-actor default isolation in UI targets |
| Shell, panels, overlays, editor canvas | AppKit |
| Settings, onboarding, history, translation panel, language-pack sheet | SwiftUI in `NSHostingView` / `NSHostingController`, `@Observable` models |
| Capture and recording | ScreenCaptureKit, AVFoundation (`AVMutableComposition`, `AVAssetExportSession`, `AVAssetImageGenerator`), AVKit (`AVPlayerView` trimming) |
| Image processing | Core Graphics, Core Image (`CIGaussianBlur`, `CIPixellate`), Accelerate (vDSP for stitching), ImageIO (`CGImageDestination` for PNG/JPEG/HEIC/GIF) |
| OCR | Vision (`RecognizeDocumentsRequest`, `RecognizeTextRequest`) |
| Translation | Translation framework, FoundationModels, URLSession providers |
| Global hotkeys | Own `CGEventTap` engine (switcher) and own Carbon `RegisterEventHotKey` engine (capture/translate/record) |
| Launch at login | `SMAppService.mainApp` |
| Logging | `os.Logger` with one category per module; `os_signpost` intervals for the hot paths |
| Project | XcodeGen (`project.yml`) + local Swift packages; SwiftLint + SwiftFormat as dev tools only |
| Tests | Swift Testing (XCTest only for `XCTMetric` performance tests); in-repo image-diff helper |

**Deliberately not used:** Sparkle, KeyboardShortcuts, HotKey, LaunchAtLogin-Modern, swift-snapshot-testing, gifski or other copyleft encoders, Tesseract, Combine in new code.

---

## 6. Architecture

### 6.1 Shape

```
┌──────────────────────────── Oriel.app (LSUIElement menu-bar agent) ───────────────────────────┐
│ AppShell (AppKit): NSStatusItem, AppDelegate, ModuleRegistry, PermissionCenter, SettingsWindow │
│                                                                                               │
│  ┌──────────── Feature modules (conform to UtilityModule) ────────────┐                       │
│  │ WindowSwitcher   Capture   Recording   Editor   OrielTranslation   │                       │
│  │ History   Pinboard   (future tools…)                               │                       │
│  └────────────────────────────────────────────────────────────────────┘                       │
│  ┌──────────── Services (protocols in OrielCore, implementations in packages) ──┐             │
│  │ WindowService  SpaceService  FocusService  ThumbnailService                  │             │
│  │ HotkeyService  GestureService  ScreenshotEngine  RecordingService            │             │
│  │ OCRService  TranslationService(+Providers)  UploadService  SettingsStore     │             │
│  │ KeychainStore  PermissionService  IPCServer  Logger  BootstrapImporter       │             │
│  └──────────────────────────────────────────────────────────────────────────────┘             │
│  PrivateAPIs (dlsym-resolved SkyLight/HIServices/MultitouchSupport shims, all Optional)       │
└───────────────────────────────────────────────────────────────────────────────────────────────┘
        ▲ Unix domain socket (newline-delimited JSON, 0600, same-UID check)
        │
   oriel (CLI in Oriel.app/Contents/Helpers/oriel) → symlink in /usr/local/bin or ~/.local/bin
```

### 6.2 Packages (local SPM, one per concern)

| Package | Depends on | Contents |
|---|---|---|
| `OrielCore` | — | Protocols, models (`WindowInfo`, `ShortcutSpec`, `CaptureResult`, `OCRBlock`, `TranslationRequest`), `Capabilities`, `FeatureGate`, `SettingsStore`, `KeychainStore`, errors, DI `ServiceContainer`, logging categories, and test support as a second product, `OrielTestSupport` (`.requiresTCC`, image diff) |
| `PrivateAPIs` | — (Swift only) | `dlsym` loading of `_AXUIElementGetWindow`, `_AXUIElementCreateWithRemoteToken`, `_SLPSSetFrontProcessWithOptions`, `SLPSPostEventRecordTo`, `GetProcessForPID`, `SLSMainConnectionID`, `SLSGetActiveSpace`, `SLSCopyManagedDisplaySpaces`, `SLSCopySpacesForWindows`, `CGSGetSymbolicHotKeyValue`, `CGSSetSymbolicHotKeyEnabled`, `CGSIsSymbolicHotKeyEnabled` (docs/provenance.md). Each symbol is `Optional`; `PrivateAPIs.presence` reports which resolved. No MultitouchSupport: gestures come from the event tap (§7.1.5). |
| `Permissions` | OrielCore | AX trust, Screen Recording preflight/request, mic/camera, System Settings deep links, change observation |
| `Hotkeys` | OrielCore | `EventTapHotkeyEngine` (switcher), `CarbonHotkeyEngine` (capture/translate/record), `ShortcutRecorderView`, Sticky Keys policy |
| `SharedUI` | OrielCore | `Material.make(for:)` (glass / opaque), HUD primitives, panel base classes, accessibility helpers, `Pasteboard` (every write to the general pasteboard, announced to Clipboard History) |
| `IPC` | OrielCore | Socket server (app) and client (CLI), Codable request/response types |
| `WindowSwitcher` | OrielCore, PrivateAPIs, Permissions, Hotkeys, SharedUI | `WindowStore`, AX observers, focus engine, switcher panel, preview panel, layout, search, gesture recognizer, exceptions |
| `Capture` | OrielCore, Permissions, SharedUI | Shareable-content cache, screenshot engine, freeze-frame overlay, window snapping, magnifier, Quick Access Overlay, scrolling capture, pinboard |
| `Recording` | OrielCore, Permissions, SharedUI | `SCRecordingOutput` session, segments, audio, camera bubble, click/keystroke overlays, GIF export, trimming |
| `Editor` | OrielCore, SharedUI | Document model, tools, renderer, undo, export |
| `OCR` | OrielCore | `OCRService`, geometry conversion, layout grouping, language detection |
| `OrielTranslation` | OrielCore, OCR, SharedUI | `TranslationProvider` protocol, providers, segment JSON contract, overlay renderer, history, usage counters |
| `Upload` | OrielCore, SharedUI | `UploadDestination` protocol, `S3CompatibleDestination` |
| `ClipboardHistory` | OrielCore, SharedUI | The Clipboard History `UtilityModule` (§7.9): pasteboard watcher and reader, classifier, encrypted store, OCR indexing, the history panel, pasting by posting ⌘V, the Settings pane |
| App target `Oriel` | all of the above | Status item, `ModuleRegistry`, onboarding, Settings window, bootstrap import |
| Tool target `oriel-cli` (binary `oriel`, module `OrielCLI`, embedded at `Contents/Helpers/oriel`) | IPC, OrielCore | `oriel windows …`, `oriel capture …`, `oriel translate …`, `oriel debug …` |

### 6.3 Module interface (future tools without re-architecture)

```swift
@MainActor
public protocol UtilityModule: AnyObject {
    static var id: ModuleID { get }                  // "window-switcher", "capture", …
    var displayName: String { get }
    var requiredPermissions: Set<PermissionKind> { get }
    var menuItems: [NSMenuItem] { get }              // contributed to the status menu
    var settingsPane: AnyView? { get }               // SwiftUI pane in Settings
    var ipcCommands: [IPCCommandHandler] { get }     // contributed CLI verbs
    func activate(context: ModuleContext) async      // start observers and hotkeys
    func deactivate() async                          // tear down; must leave zero timers
}

public struct ModuleContext: Sendable {
    public let services: ServiceContainer            // DI: protocol existentials only
    public let settings: SettingsStore
    public let log: Logger
}
```

`ModuleRegistry` reads the enabled-modules setting, activates modules lazily and deactivates a module when the user disables it, releasing its observers, taps and caches. A new tool (color picker, ruler…) is a new package conforming to `UtilityModule`, as Clipboard History is (§7.9). A default-on module that arrives in an update is turned on once, also for a user who had already chosen their tools (`app.offeredModules` remembers which were offered), and a tool's global shortcut is registered only while the tool is on.

### 6.4 Concurrency and state

- **Main actor:** all AppKit/SwiftUI, the switcher panel state machine, menu and status item.
- **AX actor:** a dedicated serial actor for every `AXUIElement*` call, with `AXUIElementSetMessagingTimeout(element, 0.25)` on each app element. AX calls are synchronous IPC to other processes and block when the target hangs; they never run on the main thread during switcher presentation.
- **Service actors:** `WindowStore` (source of truth for windows), `ThumbnailCache`, `ScreenshotEngine`, `RecordingSession`, `ScrollingCaptureSession`, `TranslationService`, `UploadService`.
- **State:** `@Observable` view models on the main actor, fed with immutable value snapshots (`[WindowInfo]`) from actors.
- **Events:** `AsyncStream` from services (`WindowService.events`). No Combine.
- **DI:** `ServiceContainer` is a struct of protocol existentials built in `AppDelegate`; tests build it with fakes.

### 6.5 Communication paths

| From → To | Mechanism |
|---|---|
| OS → app (windows) | `AXObserver` per app pid (created, destroyed, focused, moved, resized, title changed, minimized/deminimized) + `NSWorkspace` notifications (launch, terminate, activate, hide/unhide, `activeSpaceDidChangeNotification`, `NSApplication.didChangeScreenParametersNotification`) |
| OS → app (keys, gestures) | One active `CGEventTap` (session level, head insert) for the switcher; Carbon hotkeys for capture/translate/record |
| Module ↔ module | Service protocols only (Translation consumes `CaptureResult` through an explicit `translate(image:)` call) |
| CLI ↔ app | Unix domain socket at `~/Library/Application Support/Oriel/ipc.sock` |
| Scripts, other apps | URL scheme `oriel://capture/area`, `oriel://translate/area`; App Intents later |

---

## 7. Implementation approaches

### 7.1 Window management

#### 7.1.1 Enumeration (event-driven, cached)

1. **Bootstrap** at launch and whenever Accessibility is granted: for each `NSRunningApplication` with `activationPolicy == .regular` (plus `.accessory` apps that own layer-0 windows) create `AXUIElementCreateApplication(pid)` and an `AXObserver`; read `kAXWindowsAttribute`; map each AX element to its `CGWindowID` with `_AXUIElementGetWindow`; read title, role/subrole, minimized and full-screen state.
2. **Other Spaces:** `CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)`; keep layer-0 windows of known pids that AX did not return; build AX elements for them with `_AXUIElementCreateWithRemoteToken` so titles and actions work. **Fallback** when the symbol is missing: list the window with the app name only and focus the app rather than the window.
3. **Space and display membership:** `SLSCopySpacesForWindows` and `SLSCopyManagedDisplaySpaces` give a Space index per display and the active Space. **Fallback:** no Space badges; "current Space only" filters use `CGWindowListCopyWindowInfo(.optionOnScreenOnly)`.
4. **Filtering:** drop subroles other than `AXStandardWindow`/`AXDialog`, tiny windows, layer ≠ 0, and apps on the exception list.
5. **MRU order:** maintained from `kAXFocusedWindowChangedNotification` and `NSWorkspace.didActivateApplicationNotification`, in memory only.

```swift
// AX observer registration (inside the AX actor; run-loop source added on the main run loop)
func observe(pid: pid_t) throws {
    var observer: AXObserver?
    guard AXObserverCreate(pid, axCallback, &observer) == .success, let observer else { throw AXError.observerFailed }
    let app = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(app, 0.25)
    for note in [kAXWindowCreatedNotification, kAXFocusedWindowChangedNotification,
                 kAXUIElementDestroyedNotification, kAXWindowMiniaturizedNotification,
                 kAXWindowDeminiaturizedNotification, kAXTitleChangedNotification,
                 kAXWindowMovedNotification, kAXWindowResizedNotification] {
        AXObserverAddNotification(observer, app, note as CFString, Unmanaged.passUnretained(self).toOpaque())
    }
    CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
}
```

Apps that are still launching refuse AX for a few hundred milliseconds: retry on `kAXApplicationActivatedNotification` / `didActivateApplicationNotification`, never on a timer.

#### 7.1.2 Private API register

| Symbol | Purpose | Risk | Fallback |
|---|---|---|---|
| `_AXUIElementGetWindow` (HIServices) | AX element → `CGWindowID` | Low; stable for years, present on macOS 27 | Match by pid + frame + title (ambiguous for identical bounds) |
| `_AXUIElementCreateWithRemoteToken` | AX elements for windows on other Spaces | Medium | Window shown without actions; focus the app only |
| `_SLPSSetFrontProcessWithOptions` + `SLPSPostEventRecordTo` (SkyLight) | Bring exactly one window front and key, switching Space | Medium; signatures come from reverse engineering. SkyLight ordering calls are reported to be ignored when issued from CLI processes on macOS 27, so only the GUI app calls them. | `NSRunningApplication.activate()` + `AXRaise` + `kAXMainAttribute` |
| `SLSMainConnectionID`, `SLSGetActiveSpace`, `SLSCopyManagedDisplaySpaces`, `SLSCopySpacesForWindows` | Space badges and filters | Medium | Hide Space badges and filters |
| `CGSGetSymbolicHotKeyValue`, `CGSSetSymbolicHotKeyEnabled` | Disable the native Cmd-Tab while ours is bound | Medium; must be restored on quit, crash and launch | Consume Cmd-Tab in the event tap |
| MultitouchSupport | Raw trackpad contacts | Medium-high; no headers | Gesture events via the event tap (primary path anyway) |

Rules: resolve every symbol with `dlopen`/`dlsym` at launch so that a missing symbol disables a capability instead of crashing; show the flags in Settings → About → Diagnostics; keep a "symbol presence" test that runs on each macOS VM image; record each signature's provenance in `docs/provenance.md`.

#### 7.1.3 Focusing and raising

```swift
@MainActor func focus(_ w: WindowInfo) async {
    if caps.skyLightFocus, let psn = processSerialNumber(for: w.pid) {
        PrivateAPIs.setFrontProcess(psn, windowID: w.id)      // _SLPSSetFrontProcessWithOptions, user-generated mode
        PrivateAPIs.makeKeyWindow(psn, windowID: w.id)        // two SLPSPostEventRecordTo records
    } else {
        NSRunningApplication(processIdentifier: w.pid)?.activate()   // cooperative activation: a request, not a command
    }
    await ax.perform(w.element, kAXRaiseAction)
    await ax.set(w.element, kAXMainAttribute, true)
    if w.isMinimized { await ax.set(w.element, kAXMinimizedAttribute, false) }
    if w.isAppHidden { NSRunningApplication(processIdentifier: w.pid)?.unhide() }
}
```

- Since macOS 14 activation is cooperative: `activate(ignoringOtherApps:)` is deprecated and the flag is ignored. Our panel is non-activating (that is what keeps the user's current app focused), so we cannot yield activation on anyone's behalf. The SkyLight path is therefore primary.
- Focusing a window on another Space makes macOS switch Spaces as long as "When switching to an application, switch to a Space with open windows" is on; detect the off state and show a tip.
- Full-screen windows live in their own Space and use the same path. Focusing never moves a window between displays; the panel opens on the display under the pointer, or, per Settings → Window Switcher → Show on, the one with the active window (from the cached window list, never a blocking Accessibility call) or the main display; "current screen" filters follow that display.

#### 7.1.4 Hotkeys

| Mechanism | Permission | Consumes Cmd-Tab | Sees modifier release | Used for |
|---|---|---|---|---|
| Active `CGEventTap` (session level) | Accessibility | Yes | Yes (`flagsChanged`) | Switcher |
| Carbon `RegisterEventHotKey` | None | No | No | Capture, translate, record (own `CarbonHotkeyEngine`) |
| `NSEvent` global monitor, listen-only tap | Accessibility / Input Monitoring | No | Yes | Not used |

- One active tap with mask `keyDown | keyUp | flagsChanged` (plus the gesture event type when gestures are enabled). On `kCGEventTapDisabledByTimeout` or `…ByUserInput` re-enable immediately and log. The callback does table lookups only and returns in well under 1 ms; all other work hops to the main actor.
- **Cmd-Tab takeover:** find the Cmd-Tab symbolic hotkey ID by enumerating `CGSGetSymbolicHotKeyValue` in spike S4 (never hard-code a guessed number), disable it with `CGSSetSymbolicHotKeyEnabled` while our binding is active, and restore it on quit, in a signal handler, via `atexit`, and defensively at launch.
- **Shortcut table:**

```swift
struct ShortcutSpec: Codable, Hashable, Sendable {
    var holdModifiers: CGEventFlags      // e.g. .maskCommand or .maskAlternate
    var nextKey: KeyCode                 // e.g. Tab
    var prevModifier: CGEventFlags?      // e.g. .maskShift
    var filter: WindowFilter             // apps: all/active; spaces: all/current; screens: all/current; minimized/hidden: include/exclude
    var releaseBehavior: ReleaseBehavior // .switchOnRelease / .keepOpen
    var style: DisplayStyle?             // per-shortcut override
}
```

- **State machine (pure, unit-tested):** `idle → armed(hold modifiers down) → open(selection) → committing | cancelled`. While open, the tap consumes every key: arrows, Tab, Shift-Tab, typing (search), Esc (cancel), Return (commit), W/M/F/Q (close/minimize/full-screen/quit), 1–9 (jump). On `flagsChanged` with hold modifiers released: commit if `.switchOnRelease`, else stay open.
- **Sticky Keys:** a latched modifier is released by the system after the next key, so release-to-switch would commit instantly. Detect Sticky Keys (candidate: `UserDefaults(suiteName: "com.apple.universalaccess")?.bool(forKey: "stickyKey")`, verify in S4); when on, force `.keepOpen` with Return/Space to commit and say so in Settings. Offer a keep-open toggle per shortcut for everyone.
- **`CarbonHotkeyEngine`:** `RegisterEventHotKey(keyCode, carbonModifiers, hotKeyID, GetEventDispatcherTarget(), 0, &ref)` with one `InstallEventHandler` for `kEventClassKeyboard` / `kEventHotKeyPressed`; maps `NSEvent.ModifierFlags` to `cmdKey | optionKey | controlKey | shiftKey`.
- **`ShortcutRecorderView`** (AppKit, ≈300 lines): click to record, Esc cancels, Delete clears, shows the combo with SF Symbols, rejects system-reserved combos (Cmd-Q, Cmd-Space, Cmd-Tab), flags conflicts with the switcher's shortcut table.

#### 7.1.5 Trackpad gestures

- **Primary:** gesture events in the same event tap (the `CGEventType` that corresponds to `NSEvent.EventType.gesture`; confirm the raw value in S5). Recognize three-finger horizontal travel with a distance threshold and per-finger travel checks; invalidate the session when a fourth finger appears (prevents misfires during four-finger Spaces swipes) or when only two fingers are down (scrolling). Swiping opens the switcher, further travel moves the selection, lifting commits.
- **Fallback (spike only):** private MultitouchSupport contact frames, only if gesture events cannot produce reliable finger counts on macOS 26/27.
- Onboarding detects that the system's three-finger "swipe between full-screen apps" is enabled and links to Trackpad settings.

#### 7.1.6 Zero-CPU idle

- No `Timer`, `DispatchSourceTimer` or polling in the steady state. A SwiftLint custom rule bans `Timer.scheduledTimer` outside `Recording` and `Capture` sessions. Clipboard History checks the pasteboard only after events (§7.9 item 3).
- Thumbnails are captured only when the switcher opens (visible tiles first), then cached. No background refresh.
- Let App Nap work. During recording or scrolling capture wrap the work in `ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled], reason:)`.
- Verify with `scripts/idle-cpu.sh` (§13) and `powermetrics`.

#### 7.1.7 Thumbnails and the permission regime

- Cache `SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)` and refresh it only on window-set change events; every fetch and capture costs `tccd` work (authorization checks with code-signature validation per capture have been measured at tens of milliseconds of root `tccd` CPU on macOS 26).
- Tiles: `SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow:), configuration:)` with width/height set to the **tile pixel size**, `showsCursor = false`; at most four captures in flight; visible tiles first. Full resolution only for the large preview of the selected window.
- **Screen Recording is optional for the switcher.** Without it, show app icons and AX titles (icon and list styles).
- macOS 15 and later periodically asks the user to re-confirm Screen Recording for apps that capture without the system picker. This applies to ScreenCaptureKit too. Onboarding explains it once; MDM can suppress it (§8.3).
- **Memory:** LRU cache capped at 48 MB of decoded thumbnails; `DispatchSource.makeMemoryPressureSource([.warning, .critical])` drops everything except visible tiles; full-resolution previews are released when the panel closes; tile views are recycled. (AltTab's issue tracker documents multi-hundred-MB RSS growth from retained raster data after days of use; the 48 h soak test in §14 guards against this.)

#### 7.1.8 CLI over a Unix domain socket

| Option | Verdict |
|---|---|
| XPC Mach service | Needs a launchd agent; complexity for no gain |
| Distributed notifications | No replies, no auth, payload limits |
| URL scheme | One-way; kept as a supplement |
| AppleScript / App Intents | Later, for Shortcuts.app |
| **Unix domain socket** | **Chosen.** Request/response, streaming, trivially testable. 0600 in Application Support, `getpeereid` same-UID check, newline-delimited JSON. |

```
oriel windows list [--json] [--space current|all] [--app <bundle-id>]
oriel windows focus <window-id> | --title <substring>
oriel windows close|minimize <window-id>
oriel capture area|window|screen [--rect x,y,w,h] [--delay <1–60 s>] [--to clipboard|file|editor] [--path …]
oriel translate area [--rect …] [--to <lang>] [--provider <id>] [--json]
oriel debug capabilities --json | open-switcher --shortcut N | capture --fixture <png>   # Debug builds only
```

Settings → Advanced → "Install command-line tool…" creates a symlink to `Oriel.app/Contents/Helpers/oriel` at `/usr/local/bin/oriel` (admin prompt) or `~/.local/bin/oriel`. The CLI cannot live next to the app's executable in `Contents/MacOS`: on a case-insensitive volume, the macOS default, `oriel` and `Oriel` are the same file.

#### 7.1.9 Accessibility options

Observe `NSWorkspace.accessibilityDisplayOptionsDidChangeNotification`: `accessibilityDisplayShouldReduceTransparency` → opaque `windowBackgroundColor` fill; `…ShouldIncreaseContrast` → 1 px borders; `…ShouldReduceMotion` → no spring/scale animations. Each tile is an `NSView` with `accessibilityRole = .button` and a label "Title — App, minimized, Space 2" so basic VoiceOver works; announcement polish is deferred.

#### 7.1.10 Switcher UI

- `NSPanel` with `styleMask [.nonactivatingPanel, .borderless]`, `level = .popUpMenu`, `collectionBehavior [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]`, `hidesOnDeactivate = false`, `becomesKeyOnlyIfNeeded = true`.
- Material: `NSGlassEffectView(style: .regular)`, no tint (macOS 27 changed how dark tints composite), content in `contentView`; under Reduce Transparency swap in an opaque layer. The choice lives in `SharedUI.Material.make(for:)`.
- Preview: a second borderless panel at `.popUpMenu - 1` showing the selected window's cached full-resolution capture at its real frame, dimmed when stale.
- Styles: thumbnail grid; app icons with a window-count badge; title list (table). Search filters live with a subsequence fuzzy score over "title app" and highlights matches. Auto-size: §10.3.

### 7.2 Screenshot capture

1. **Trigger:** Carbon hotkey (default ⌃⇧4-style, configurable), status menu, CLI or URL.
2. **Freeze-frame overlay (default):** capture every display at once with `SCScreenshotManager` (per-display `SCContentFilter(display:excludingWindows:)`, excluding our own windows) and show one borderless `NSWindow` per `NSScreen` at `.screenSaver` level displaying the frozen image. Transient UI (menus, hovers) stays in the shot, the magnifier is exact, selection has zero latency. A "live" toggle covers video-like content: with Settings → Capture → Freeze the screen while selecting off, the overlay windows are see-through and hit-testable, there is no loupe, and the pick is captured once the overlay has gone, from freshly fetched shareable content so every window of Oriel's is excluded.
3. **Modes:** area (drag), window (hover highlights the window under the cursor using cached `SCShareableContent.windows` frames; click captures the window image itself with optional shadow), full screen (click a display), previous area, timer (3/5/10 s: a countdown, then the area overlay, so a menu opened during the countdown is frozen into the shot), all displays.
4. **Precision:** 8× magnifier loupe sampled from the frozen image with pixel grid and hex colour; crosshair with W×H readout; arrows nudge 1 px (Shift: 10 px), Option+arrows resize, Space+drag moves; snapping to window edges.
5. **Coordinates:** Cocoa global coordinates have a bottom-left origin on the primary screen; CG/SCK use top-left. All conversion lives in `ScreenGeometry` and is unit-tested with synthetic layouts (negative origins, mixed 1×/2× scales). Crop in pixel space using each display's `backingScaleFactor`; write the scale into image metadata (DPI 144 for 2×).
6. **Quick Access Overlay:** after capture, a small non-activating panel in a screen corner offers Copy, Save, Annotate, Translate, Pin, Upload, Copy Text (OCR) and drag-out; auto-dismisses after N seconds (pauses on hover); stacks for multiple captures.
7. **HDR:** SDR PNG by default; HEIC HDR as an option via the macOS 26 screenshot configuration (confirm the exact type name in the SDK audit).
8. **Clipboard:** every interactive capture, in every mode, is also copied to the clipboard (Settings → Capture → Copy every capture to the clipboard, on by default), whatever the after-capture action, so it is in Clipboard History (§7.9) even when Quick Access is closed with Esc. Quick Access keeps its Copy button, for copying a capture again after something else. Headless captures (`oriel capture --rect`) keep their explicit `--to`.

### 7.3 Scrolling capture

1. The user selects a region; the scroll target is under its centre.
2. Capture frame 0 pixel-exact.
3. Post synthetic scrolls at the region centre: `CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: -Δ, …)` posted to `.cghidEventTap` (needs Accessibility), Δ ≈ 40–60 % of the region height.
4. Wait for visual stability: two consecutive captures identical within tolerance, capped at ≈250 ms (absorbs smooth-scroll inertia and lazy loading).
5. **Offset estimation:** grayscale both frames, compute per-row signatures (row mean + hashed downsample), find the vertical offset maximizing normalized cross-correlation over the overlap band with vDSP, constrained to ±25 % of the expected Δ (defeats repeated table rows); reject below a confidence threshold. Validate offline against `VNTranslationalImageRegistrationRequest` during development.
6. **Sticky header/footer:** rows identical across all frames at the top or bottom are fixed; exclude them from matching and include them once. Mask the rightmost 16 px when matching (overlay scrollbars).
7. **Stop** when a frame equals the previous one, on Esc/Done, or at 30,000 px.
8. Compose into a tall `CGContext` incrementally.
9. **Manual mode:** the user scrolls; we sample each stable frame. Covers apps that ignore synthetic scrolls. **Horizontal:** same algorithm transposed.
10. On low confidence, fail fast and suggest manual mode.

### 7.4 Screen recording (`SCRecordingOutput`)

```swift
let config = SCStreamConfiguration()
config.sourceRect = region                              // display points
config.width = pixelSize.width; config.height = pixelSize.height
config.minimumFrameInterval = CMTime(value: 1, timescale: Int32(preset.fps))
config.showsCursor = settings.showCursor
config.capturesAudio = settings.systemAudio
config.excludesCurrentProcessAudio = true
config.captureMicrophone = settings.microphone
config.microphoneCaptureDeviceID = settings.microphoneDeviceID

let stream = SCStream(filter: filter, configuration: config, delegate: streamDelegate)
let outConfig = SCRecordingOutputConfiguration()
outConfig.outputURL = segmentURL(index: 0)
outConfig.outputFileType = .mp4
outConfig.videoCodecType = preset.codec == .hevc ? .hevc : .h264
let output = SCRecordingOutput(configuration: outConfig, delegate: recordingDelegate)
try stream.addRecordingOutput(output)
try await stream.startCapture()
```

- **Pause:** `stream.removeRecordingOutput(output)` finalizes segment N. **Resume:** add a new `SCRecordingOutput` for segment N+1. **Stop:** `stopCapture()`, then concatenate with `AVMutableComposition` and export with `AVAssetExportPresetPassthrough` through `export(to:as:)` (the callback API is deprecated in macOS 27, S8). Single-segment recordings skip this.
- Click rings, keystroke HUD and the camera bubble are on-screen overlay panels, recorded naturally. The filter excludes our windows for screenshots but includes these overlays for recordings. The camera bubble is a floating circular `NSPanel` hosting `AVCaptureVideoPreviewLayer`; click rings are driven by a listen-only mouse-down observation in the existing tap.
- **GIF:** `AVAssetImageGenerator` at 10–15 fps from the final MP4 → `CGImageDestination` with `UTType.gif`, max width 800 px by default.
- **Record Window** picks a window on the overlay (window mode) and records its frame when recording starts: the area does not follow the window, but the click rings, keystroke HUD and camera bubble stay in the video, which a single-window filter would drop.
- **Trimming:** `AVPlayerView.beginTrimming(completionHandler:)` + passthrough export.
- **Presets:** Standard (1080p-equivalent, 30 fps, H.264 ~8 Mbps), High (native resolution, 60 fps, HEVC), Small (720p, 24 fps). Frames arrive only on change, so MP4s are variable frame rate; offer "Export CFR" for editors.
- Active recordings run inside `beginActivity(.userInitiated, .idleSystemSleepDisabled)`.

### 7.5 Image editor (AppKit canvas + Core Graphics/Core Image, SwiftUI chrome)

| Option | Verdict |
|---|---|
| SwiftUI `Canvas` | Weak hit-testing, text editing, per-object undo and pixel-exact export. Rejected for the canvas. |
| Metal | Overkill for annotation. Reserved for future effects. |
| **Layer-backed `NSView` + Core Graphics, Core Image for effects** | **Chosen.** Mature text editing (`NSTextView` overlay while editing), precise mouse handling, one renderer for screen and export. |

```swift
struct EditorDocument: Codable, Sendable {
    var base: ImageRef                 // original pixels, never mutated
    var crop: CGRect?                  // non-destructive
    var canvasPadding: Padding?
    var background: BackgroundStyle?   // gradient / solid / wallpaper, shadow, corner radius
    var items: [AnnotationItem]        // z-ordered
}
enum AnnotationItem: Codable, Sendable, Identifiable {
    case arrow(Arrow), line(Line), rect(Shape), ellipse(Shape), freehand(Path),
         highlighter(Path), text(TextBox), counter(Counter),
         blur(Region), pixelate(Region), spotlight(Region), magnify(Loupe), image(Sticker)
}
```

- **Undo/redo:** `NSUndoManager` with inverse document snapshots per gesture (documents are small value types), coalesced during drags.
- **Rendering:** one `render(document, into: CGContext, scale:)` used by both the view and export. Blur and pixelate are computed from `base` via Core Image and cached per region.
- **Export:** PNG/JPEG/HEIC via `CGImageDestination`; PDF via `CGContext(consumer:mediaBox:)`; clipboard (`NSPasteboard`, PNG + TIFF); drag-out (`NSDraggingSource` with a promised file); Quick Look (`QLPreviewPanel` on ⌘Y, from a temporary PNG removed when the panel lets go of the window); `.oriel` editable bundle (JSON + original PNG).
- **Tools at launch:** arrow, line, rectangle, ellipse, freehand, highlighter, text, numbered steps, blur, pixelate, spotlight, crop, background/padding, colour and width. Later: magnifier callout, stickers, smart redact.

### 7.6 OCR

```swift
func recognize(_ image: CGImage, mode: OCRMode) async throws -> [OCRBlock] {
    switch mode {
    case .document:                                    // translation overlay, history indexing
        var request = RecognizeDocumentsRequest()
        // configure recognition languages where the request supports it; empty = automatic
        let documents = try await request.perform(on: image)
        return blocks(fromParagraphs: documents)       // paragraphs, lists, tables → OCRBlock with pixel boxes
    case .fast:                                        // "copy text", quick translate
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        return blocks(fromLines: try await request.perform(on: image))
    }
}
```

- Vision regions are normalized with a bottom-left origin; convert once to pixel coordinates in `OCRGeometry` (unit-tested).
- CJK: horizontal text is fine; vertical Japanese/Chinese goes to "AI Vision" mode. RTL: natural alignment with the base writing direction from the detected language.
- Tesseract is not included; add it only if a script Vision lacks becomes necessary.

### 7.7 Translation

#### 7.7.1 Provider protocol

```swift
public struct TranslationSegment: Sendable, Codable { public let id: Int; public let text: String }
public struct TranslationRequest: Sendable {
    public var segments: [TranslationSegment]
    public var source: Locale.Language?     // nil = auto (provider-dependent)
    public var target: Locale.Language
    public var image: CGImage?              // only for .imageInput providers in "AI Vision" mode
    public var glossary: [String: String]
}
public struct ProviderCapabilities: OptionSet, Sendable { /* streaming, imageInput, offline, autoDetect, batch */ }

public protocol TranslationProvider: Sendable {
    var id: ProviderID { get }
    var displayName: String { get }
    var capabilities: ProviderCapabilities { get }
    func availability() async -> ProviderAvailability          // key missing, pack not installed, model unreachable, …
    func translate(_ req: TranslationRequest) -> AsyncThrowingStream<TranslatedSegment, Error>
}
```

#### 7.7.2 Providers (priority order)

| Priority | Provider | Availability | Notes |
|---|---|---|---|
| 1 (default) | `AppleTranslationProvider` | 26+ headless | Offline once packs are installed. Source language required: OCR-detected language, then `NLLanguageRecognizer`. On 26.4+ set the preferred strategy to high fidelity when Apple Intelligence is available, otherwise low latency (confirm the property name in the SDK audit). |
| 2 | `OpenAICompatibleProvider` → internal Ollama / LM Studio / llama.cpp server, or OpenAI | Any | One implementation for every `/v1/chat/completions` endpoint; SSE streaming; vision models for AI Vision mode. Default base URL from the bootstrap config. |
| 3 | `FoundationModelsProvider` | 26+, Apple silicon, Apple Intelligence on | `LanguageModelSession` with a translation instruction; chunk segments to stay well within the session's context window (Apple documented 4,096 tokens per session; verify the current value); hidden when `SystemLanguageModel.default.availability != .available`. |
| 4 | `AnthropicProvider` (`POST /v1/messages`, `x-api-key`, `anthropic-version`, SSE, base64 image blocks) | Any | Image input supported |
| 5 | `GoogleTranslateProvider` (v2 with API key by default; v3 for glossaries) | Any | v3 takes no API keys, so a provider with a glossary signs an RS256 JWT with a service account key, exchanges it at the key's `token_uri` for an OAuth token (scope `cloud-translation`, cached until a minute before expiry) and sends `translateText` with `glossaryConfig`, preferring `glossaryTranslations`. The glossary is a full resource name or an ID in `us-central1` of the key's project; a glossary needs the source language, so without one the text goes without it. |
| 6 | `DeepLProvider` (`/v2/translate`, `Authorization: DeepL-Auth-Key …`) | Any | Batch texts per request; formality option |

Model identifiers and prices change; keep model IDs user-configurable with no hard-coded defaults beyond what the bootstrap file supplies. Show a per-provider usage counter (characters/tokens) with an optional monthly cap.

#### 7.7.3 Headless Apple Translation

```swift
actor AppleTranslationProvider: TranslationProvider {
    func translate(_ req: TranslationRequest) -> AsyncThrowingStream<TranslatedSegment, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                guard let source = req.source ?? LanguageDetector.detect(req.segments) else {
                    continuation.finish(throwing: TranslationError.sourceUnknown); return
                }
                let status = await LanguageAvailability().status(from: source, to: req.target)
                guard status == .installed else {
                    continuation.finish(throwing: TranslationError.packNotInstalled(source, req.target)); return
                }
                let session = TranslationSession(installedSource: source, target: req.target)
                let requests = req.segments.map {
                    TranslationSession.Request(sourceText: $0.text, clientIdentifier: String($0.id))
                }
                do {
                    for try await response in session.translate(batch: requests) {
                        continuation.yield(.init(id: Int(response.clientIdentifier ?? "") ?? -1, text: response.targetText))
                    }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
```

Language-pack downloads can only be triggered through SwiftUI's `translationTask` with `prepareTranslation()` and the user's consent: keep one small SwiftUI sheet in Settings → Translation ("Download language pack for X → Y") and open it automatically on `packNotInstalled`.

#### 7.7.4 LLM prompting and modes

- Send segments as JSON (`[{"id":1,"text":"…"}]`) with the instruction: return a JSON array of `{id, translation}` with exactly the same ids; translate into the target language; preserve numbers, URLs, code and line breaks; no commentary. Use structured outputs where supported; parse incrementally while streaming so boxes fill in progressively. The parser tolerates extra prose and missing ids.
- **OCR-then-translate (default)** gives box-accurate overlays, text-only cost, offline capability and text-only privacy. **AI Vision mode** (providers with `.imageInput`) sends the whole image and handles stylized, vertical or handwritten text; it is a per-capture button, never the default.

#### 7.7.5 Keys, settings and bootstrap config

- API keys live in the Keychain (`kSecClassGenericPassword`, service `com.codertapsu.oriel.provider.<id>` (`com.codertapsu.oriel.debug.provider.<id>` in Debug builds), `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), never in UserDefaults or logs.
- Per provider: endpoint, model, temperature, timeout, custom headers, "Test connection".
- Quick switcher: a provider pop-up in the translation toolbar plus ⌘1…⌘9; the last-used provider is remembered per target language.
- **Bootstrap:** on first launch, if `~/Library/Application Support/Oriel/bootstrap.json` exists (dropped by `make install`, a DMG post-install step or MDM) or a `BootstrapURL` managed preference points at an internal HTTPS file, import it into Settings and the Keychain, then delete the file. "Reload shared config" in Settings re-imports. Format (`docs/bootstrap.example.json`):

```json
{
  "version": 1,
  "providers": [
    { "id": "ollama", "kind": "openai-compatible", "baseURL": "http://ollama.internal:11434/v1", "model": "qwen2.5:14b", "apiKey": "" },
    { "id": "anthropic", "kind": "anthropic", "model": "<model-id>", "apiKey": "<key>" }
  ],
  "defaultProvider": "apple",
  "upload": { "kind": "s3", "endpoint": "https://minio.internal", "bucket": "oriel", "accessKey": "…", "secretKey": "…", "publicBaseURL": "https://files.internal/oriel" }
}
```

A `google` provider may add `"glossary"` and `"serviceAccountKey"`, the key file's JSON object pasted in (or that JSON as a string), which goes to the Keychain under the provider's service, account `serviceAccount`.

#### 7.7.6 Result presentation

- **In-place overlay:** per block, sample the background as the median of a 2 px ring around the box, fill the box, draw the translation in a contrasting colour (contrast-checked), fit the font by binary search between 6 pt and the original line height until `boundingRect(with:options:)` fits; if it fails at minimum size, let the box grow downward and mark it with an expand hint. Hold ⌥ to peek at the original.
- **Side panel (SwiftUI):** source and translation per block, copy all / per block, swap languages, re-translate with another provider, export (TXT / Markdown / annotated PNG).
- **History:** local (JSON files or SQLite via a small in-repo wrapper) with thumbnail, source, translation and provider; opt-in; retention setting.

#### 7.7.7 Fully offline path

| Combination | Requirement |
|---|---|
| Vision OCR + Apple Translation (packs installed) | 26+; Apple silicon; Intel to be verified in S7 |
| Vision OCR + local LLM via Ollama / LM Studio / llama.cpp | Any; Intel impractically slow (warn in UI) |
| Vision OCR + Foundation Models | 26+, Apple silicon with Apple Intelligence (experimental) |

### 7.8 Upload

One destination at launch: `S3CompatibleDestination` (AWS, MinIO, R2, B2) with `PUT` + SigV4, keys from the Keychain, copy-link after upload, optional EXIF/metadata stripping. The `UploadDestination` protocol stays so WebDAV, a shared folder or OAuth providers can be added later.

### 7.9 Clipboard History

The second `UtilityModule` (package `ClipboardHistory`, on by default, General → Tools). The panel opens with ⌥V (Settings → Shortcuts), from the status menu or with `oriel://clipboard`.

1. **What is kept:** every copy: text, formatted text (RTF, RTFD, HTML), links, colors (`#RGB` to `#RRGGBBAA`, `rgb()`, `hsl()`, `NSColor`), images (PNG, TIFF, JPEG, HEIC, GIF, WebP, PDF), files (file URLs, file-reference URLs resolved to paths) and any other data, with all of each item's types (at most 512 items and 64 MB a copy). Promises, web archives and a TIFF next to a PNG of the same image are dropped. A copy with the same content (SHA-256 of its text, image bytes or file list) is the same item again: it moves to the top with the new source and date. By default the history keeps 500 items, for 30 days, in at most 500 MB (100–2000 items; 1, 7, 30 or 90 days, or until a limit; 100 MB to 5 GB), dropping the oldest first: every capture is copied (§7.2 item 8), and without a size limit a few hundred Retina screenshots would fill gigabytes. Pinned items are never dropped; they count toward the size only.
2. **Oriel's own copies** go through `SharedUI.Pasteboard`, which announces each write with its contents and change count (`Pasteboard.writes()`, one `AsyncStream` per listener). They are kept whatever macOS allows for other apps' copies, which is how a screenshot reaches the history when Quick Access is closed with Esc (§7.2 item 8).
3. **Noticing other apps' copies without polling:** macOS posts no notification when the pasteboard changes (none in the 27.0.1 shared cache), and rule 3 bans timers. `PasteboardWatcher` compares `NSPasteboard.changeCount` after what comes before a copy: a mouse-up or a key-down anywhere (an `NSEvent` global monitor; key-downs only with Accessibility, which macOS requires for them; the monitor never looks at the key), the same in Oriel's own windows (a local monitor), another app coming to the front, wake and session activation, and the panel opening. After an event it checks twice, 150 ms and 1 s later (one-shot sleeps that the next event restarts), for apps that write a moment after the key press. Idle cost is zero.
4. **Paste from Other Apps (macOS 15.4+):** reading another app's copy without a paste gesture makes macOS ask, unless the app is set to Allow in System Settings → Privacy & Security → Paste from Other Apps (link anchor `Privacy_Pasteboard`). `NSPasteboard.accessBehavior` gives the state. `.alwaysAllow`: read. `.default` (never asked): read; macOS asks once and then lists Oriel. `.ask` and `.alwaysDeny`: do not read (every read would ask, or fail); count the copies missed and say so in the panel and Settings. The first time the user lets a copy through, Oriel opens that pane once, so Oriel can be set to Allow. A copy's types are looked at before its data, so a concealed copy is never read.
5. **Privacy:** copies carrying an nspasteboard.org marker (`org.nspasteboard.ConcealedType`, `TransientType`, `AutoGeneratedType`) or an older password-manager marker are never kept, nor copies made while a listed app is in front (by default Keychain Access, Passwords, 1Password, Bitwarden and KeePassXC; Settings → Clipboard History). Pause stops all keeping. Logs never contain what was copied.
6. **Storage:** `~/Library/Application Support/Oriel/ClipboardHistory/<bundle ID>/` holds `index.sealed`, the item list, and under `items/` each item's contents and an image's thumbnail, each sealed with AES-GCM under a 256-bit key kept in the Keychain (service `clipboard`, this device only, separate for the Debug build), and is excluded from backups. An index that cannot be opened (a different key) moves to `unreadable/` and the history starts afresh. The store is an actor; contents are decrypted off the main thread. Images are read by on-device OCR at utility priority, so they can be found by their text.
7. **Panel (AppKit, rule 4):** a `FloatingPanel` that becomes key without activating Oriel, so the app the user was in stays active and takes the paste. A search field (every word, ignoring case and accents, over the text, title, file names, source app, kind, color and the text read from an image), a type menu (All, Pinned, Text, Images, Files, Links, Colors), a list with Pinned and History sections (thumbnails, file icons, color swatches, source app and time, ⌘1–⌘9 on the first nine) and a preview of the selected item (text or formatted text, a link, a color in HEX, RGB and HSL, an image, files and whether they still exist, the types of other data). Return pastes; ⌥Return pastes the other way (plain or formatted, per Settings); a double-click pastes; the paste button names the app ("Paste to Safari"). ⌘C copies without pasting, ⌘P pins, ⌘⌫ deletes (Undo until the panel closes), ⌥⌘↑/↓ move items, drag and drop reorders (dropping into Pinned pins) and drops an item into another app, several selected items paste as their texts on separate lines (or as one set of files), and Clear History keeps pinned items. Esc clears the search, then closes; a click elsewhere closes.
8. **Pasting:** the items are written back (`Pasteboard.write(_:announces: false)`), the panel closes, and ⌘V is posted with `CGEvent` at the HID tap, with the key that types "v" in the current keyboard layout while ⌘ is held (`UCKeyTranslate`). macOS delivers posted keys only with Accessibility; without it the item is copied and the user presses ⌘V. A pasted item moves to the top, or leaves the history when "Remove items from the history after pasting them" is on (pinned items stay).
9. **CLI:** `oriel debug clipboard [--json]` reports the state (open, watching, paused, access, copies missed, item and pinned counts, bytes on disk), never contents.

---

## 8. macOS APIs, permissions and security

### 8.1 Permissions (TCC)

| Permission | Needed by | Check / request | Notes |
|---|---|---|---|
| Accessibility | Switcher (AX, event tap, focus), scrolling capture (posting scrolls), click overlays, Clipboard History (posting ⌘V to paste; key-downs that time a clipboard check) | `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])`; re-check on app activation, never on a timer | Tied to the code signature: use one stable Apple Development certificate on every dev machine, Developer ID for releases |
| Screen & System Audio Recording | Thumbnails/preview (optional), capture, recording, window titles via CGWindowList | `CGPreflightScreenCaptureAccess()` / `CGRequestScreenCaptureAccess()` | Periodic re-confirmation on 15+; a relaunch is usually needed after granting |
| Microphone | Recording with mic | `AVCaptureDevice.requestAccess(for: .audio)` + `NSMicrophoneUsageDescription` | Entitlement `com.apple.security.device.audio-input` |
| Camera | Camera bubble | `NSCameraUsageDescription` | Entitlement `com.apple.security.device.camera` |
| Paste from Other Apps | Clipboard History reading other apps' copies (§7.9) | `NSPasteboard.general.accessBehavior` (macOS 15.4+): `.alwaysAllow` granted, `.alwaysDeny` denied, `.default` and `.ask` not yet; a read of another app's copy makes macOS ask and list Oriel | Pasteboard privacy, not a TCC service Oriel checks; System Settings anchor `Privacy_Pasteboard`; Oriel's own copies need nothing |
| Input Monitoring, Automation | Not needed | — | Keep it that way |
| Network | Providers, uploads | — | Not sandboxed; plain-HTTP local endpoints need `NSAllowsLocalNetworking` in ATS |

Hardened Runtime entitlements: only `device.audio-input` and `device.camera`. No sandbox, no `disable-library-validation`, no JIT.

### 8.2 Onboarding

A permissions window lists each permission, what it unlocks and its live status (re-checked on activation), with deep links `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`, `?Privacy_ScreenCapture` and `?Privacy_Pasteboard`. "Continue without" leads to degraded modes (icons-only switcher, no capture). Never read or write `TCC.db`; macOS 27 removes app access to it anyway.

### 8.3 MDM (optional)

If the fleet is managed: a PPPC profile with `Accessibility` allowed for the app's code requirement and `ScreenCapture` set to let standard users approve; the `forceBypassScreenCaptureAlert` key (macOS 15.1+) in a configuration profile to suppress the periodic prompt.

### 8.4 Security practices

IPC socket 0600 with UID check; credentials only in the Keychain; logs mark user content (`privacy: .private`) and never contain OCR text, titles or translations unless debug logging is on; no telemetry; shareable links use unguessable keys.

---

## 9. Performance, memory and battery

| Metric | Target |
|---|---|
| Idle CPU (switcher enabled, 10 min) | 0.0 % average; idle wake-ups < 1/s |
| Idle footprint (`footprint <pid>`) | < 60 MB |
| Switcher hotkey → first frame | p95 < 50 ms with cached data; thumbnails stream in after |
| Selection change → redraw | < 8 ms |
| Capture hotkey → frozen overlay | p95 < 120 ms on two displays |
| OCR (1,000×600 px, accurate) | < 400 ms on M-series |
| Apple Translation of 1,500 characters (installed pair) | < 1 s |
| Recording 1080p30 HEVC | < 10 % of one core on M-series |
| Thumbnail cache | ≤ 48 MB decoded, LRU |

Techniques: event-driven everything; lazy tile-size thumbnails with at most four captures in flight; `SCShareableContent` refreshed only on change; thumbnails drawn as `CALayer.contents` (`CGImage`/IOSurface) with no `NSImage` round-trips; view recycling and memory-pressure purge; QoS `.userInteractive` for tap work, `.userInitiated` for thumbnails/OCR, `.utility` for history indexing, `.background` for uploads; `os_signpost` around hotkey→panel, capture→overlay and OCR→translate→render; recording capped by preset fps with `queueDepth = 5`. Tooling: Instruments (Time Profiler, Allocations, Leaks, Energy/Power Profiler, Swift Executors and Task instruments), `powermetrics --samplers tasks -i 1000 -n 60`, `footprint`, `leaks`, `XCTMetric` tests for the pure pipelines.

---

## 10. UI/UX architecture

### 10.1 App shell

`LSUIElement = YES` (no Dock icon). Status menu: Pause Clipboard History, Capture Area / Window / Screen / Scrolling / Previous Area / with Timer, Record Area / Window / Screen, Translate Area, Clipboard History (⌥V), Open History, Pinned (each pin, to bring it to the front, and Close All Pins), Settings…, Quit. Settings is a SwiftUI `TabView`: General, Window Switcher, Clipboard History, Shortcuts, Capture, Recording, Translation, Upload, Permissions, Advanced/Diagnostics, About. System appearance is followed automatically with semantic colors and SF Symbols.

### 10.2 Liquid Glass

Glass (`NSGlassEffectView`, no tint) is used for floating chrome only: switcher, Quick Access Overlay, recording control bar, translation toolbar. The editor canvas and screenshots themselves stay opaque. Under Reduce Transparency / Increase Contrast an opaque `windowBackgroundColor` with a 1 px separator is applied live; do not rely on the glass view to do this itself.

### 10.3 Switcher auto-size

Input: window count *n*, the screen's visible frame, the style and the maximum panel fraction (default 80 % × 60 %). Choose rows *r* and tile width *w* that maximize *w* subject to `cols = ceil(n/r)`, `cols·w + gaps ≤ maxW`, `r·(w/aspect + titleH) + gaps ≤ maxH`, `w ∈ [minTile, maxTile]`; if `minTile` does not fit, scroll rows. Pure and table-tested.

### 10.4 Capture UX patterns adopted

Lightshot's speed (hotkey → drag → inline mini-toolbar, no mandatory editor); CleanShot's Quick Access Overlay, pins, backgrounds and history; Snagit's numbered steps and OCR-searchable library; Monosnap's pluggable destinations. Pinned screenshots are floating `NSPanel`s with opacity, click-through and a lock.

### 10.5 Translation UX

Hotkey (default ⌃⇧T) → select area → overlay over the frozen region with translations streaming in; toolbar with provider pop-up, target language, swap, copy all, AI Vision, Open in Editor. From the Quick Access Overlay, Translate runs the same flow on an existing capture.

---

## 11. Platform strategy: Apple silicon, Intel, build settings

- `ARCHS = arm64 x86_64` set explicitly for every configuration; `ONLY_ACTIVE_ARCH = YES` in Debug, `NO` in Release. `lipo -archs` on every binary in the bundle (app, CLI) on every release build.
- All code is first-party Swift, so there are no third-party binaries to worry about. Private-API shims declare the same signatures for both architectures.
- **Rosetta on the M4 Pro:** `arch -x86_64 /Applications/Oriel.app/Contents/MacOS/Oriel --self-test` and `arch -x86_64 oriel windows list --json`. This catches architecture-specific code, not Intel-only OS behaviour (GPU, HEVC encoder availability, WindowServer timing). Rosetta is available through macOS 27; macOS 28 reduces it to selected games. Install it with `softwareupdate --install-rosetta --agree-to-license` if the upgrade dropped it.
- **VMs:** Apple silicon hosts virtualize only arm64 macOS (Tart or UTM); use them for the macOS 26 matrix, not for Intel.
- **Physical Intel Mac:** optional; if one exists, run the §14.6 release QA on macOS 26 before 1.0 (hotkeys, focus, capture, HEVC encode, OCR speed, Apple Translation availability).
- **Runtime gates:** Foundation Models and Apple Intelligence strategies are Apple silicon only; local LLMs on Intel get a performance warning; `FeatureGate` combines `#available`, `Capabilities` and settings, and hides UI when false.

---

## 12. Roadmap (risk-first, ≈20 weeks, one developer driving Claude Code)

### 12.1 Phase 0 — spikes (weeks 1–2)

Spikes are throwaway executables under `Spikes/<id>/` (own `Package.swift`, no production code reuse required). Each ends with `docs/spikes/<id>.md`: result (works / partial / no-go) per macOS build tested, measurements, and the recommendation. Run on macOS 27 first, then on the macOS 26 arm64 VM. Phase 0 ends with a go/no-go table in `docs/reports/phase-0.md` and a human checkpoint.

| Spike | Goal | Gate |
|---|---|---|
| **S0** Build/release skeleton | Universal Release build, Developer ID export, notarize + staple a "Hello" DMG, install it through a local tap, `make install`, Rosetta self-test | `spctl -a -t open --context context:primary-signature -vv` passes; `lipo -archs` shows both; `arch -x86_64 … --self-test` exits 0 |
| **S1** Enumeration | All windows (current/other Space, minimized, hidden, full screen, tabs) via AX + CGWindowList + SkyLight; fixture: `scripts/fixtures/open-windows.sh` opens TextEdit ×3, one minimized, one hidden app, one window on Space 2, one full-screen Safari | ≥ 95 % of fixture windows listed correctly; every private symbol present on 27 and 26 |
| **S2** Focus/raise | Focus any S1 window (other Space, minimized, full screen, other display) from a non-activating panel | Correct window key and front in ≤ 300 ms in 20/20 trials per OS; fallback documented |
| **S3** Thumbnails + permission | 50 window tiles at tile size; count prompts and `tccd` CPU on 27 and 26; behaviour with permission denied and revoked mid-session | 50 tiles < 500 ms; no prompt beyond the documented periodic one; icon mode works without permission |
| **S4** Hotkeys | Event tap: Cmd-Tab and Option-Tab takeover, hold/release, Shift reverse, consume-while-open, tap-timeout recovery; find the Cmd-Tab symbolic hotkey ID; Sticky Keys detection and policy; Carbon engine prototype | Zero leaked keystrokes to the front app over a 200-press script; Sticky Keys policy works; Cmd-Tab restored after `kill -9` |
| **S5** Gestures | Three-finger horizontal swipe via gesture events; MultitouchSupport only if needed; four-finger and two-finger rejection | ≥ 95 % recognition, 0 false triggers in 100 trials of two-finger scrolls and four-finger Spaces swipes |
| **S6** Scrolling stitch | Auto-scroll + stitch on Safari, Chrome, Mail, Xcode, Slack, Finder list view; sticky header handling | Seamless on 5/6 apps; clean failure + manual fallback on the rest |
| **S7** OCR + translation | `RecognizeDocumentsRequest` → headless Apple Translation and an Ollama endpoint → in-place overlay with font fitting; Foundation Models availability check; Apple Translation on Intel if a machine exists | EN↔JA and EN↔DE screenshots readable; < 2 s end-to-end offline on the M4 Pro |
| **S8** SDK audit | Appendix E | `docs/spikes/S8-sdk-audit.md` written; floor decision re-confirmed or a change proposed |
| **S9** Recording pipeline | `SCRecordingOutput` with pause-by-segment, mic + system audio, 60 fps HEVC | A 30 s recording with one pause has correct duration ±0.2 s and both audio tracks |

### 12.2 Phases 1–9

| Phase | Weeks | Scope |
|---|---|---|
| 1 Core shell | 3–4 | Productionize `OrielCore`, `PrivateAPIs`, `Permissions`, `SharedUI`, `IPC` from spikes; status item, `ModuleRegistry`, Settings skeleton, onboarding, Diagnostics pane, bootstrap import, launch at login, OSLog + signposts; CI (build, lint, tests, Universal check, Rosetta job); release workflow to a notarized DMG and tap bump; fold v1/v2 history into this document if anything changed |
| 2 Switcher MVP | 5–7 | `WindowStore` with AX observers + NSWorkspace; MRU; capabilities and fallbacks; one shortcut (Option-Tab default); hold/release; thumbnail grid; preview panel; focus engine; badges; hover actions; exception list; display placement |
| 3 Switcher complete | 8–9 | Nine shortcuts with filters and per-shortcut style; three display styles; search; auto-size; Cmd-Tab takeover with restore; gestures; CLI `windows list/focus/close/minimize`; Reduce Transparency/Contrast/Motion; Sticky Keys policy; **checkpoint** |
| 4 Capture MVP | 10–11 | Freeze-frame overlay on all displays; area/window/screen/previous/timer; magnifier; nudging; window snapping; Quick Access Overlay; copy/save/drag-out; filename templates; default folder; sound/flash |
| 5 Editor | 12–14 | Document model, renderer, all launch tools, undo/redo, exports, background tool, crop, `.oriel` bundle |
| 6 Translation | 15–16 | Provider protocol and six providers; Keychain; settings with Test connection; quick switcher; overlay + side panel; history; usage counters; AI Vision; offline indicator; language-pack sheet; **checkpoint** |
| 7 Recording | 17–18 | Production `SCRecordingOutput` session from S9; region/window/screen; system audio; mic; camera bubble; click/keystroke overlays; pause/resume; control bar; trim; GIF; presets |
| 8 Scrolling, pins, history, upload | 19 | Scrolling capture (auto + manual, horizontal); pinned screenshots; capture history with OCR search; S3-compatible upload with copy-link |
| 9 Hardening and 1.0 | 20 | Performance budget verification (§9), energy audit, accessibility-options audit, matrix run (§14.5), 48 h soak, README, tap release; **checkpoint before tagging v1.0.0** |

---

## 13. Implementation and verification checklist

Conventions: run from the repo root; tick only when **Verify** passes; `make` targets are in Appendix C.

### 13.0 Global

```bash
make generate                      # xcodegen generate
make build                         # Debug build
make run                           # Debug build, then launch it (quits a running copy first)
make test                          # package tests + app tests, without TCC or UI tests
ORIEL_TCC_TESTS=1 make test        # with TCC tests (dev Mac / VM only)
ORIEL_UI_TESTS=1 make test         # with the XCUITest bundle (needs Automation Mode, §14.3)
make lint                          # swiftlint --strict && swiftformat --lint .
make universal-check               # Release build, lipo, Rosetta self-test
make install                       # build, sign, copy to /Applications
make release-dry-run               # after `source scripts/apple-credentials.env`: gate, archive, export, notarize + staple app and DMG, verify
```

### 13.1 Foundation
- [ ] `project.yml`: app, CLI and test targets; `ARCHS = arm64 x86_64`; `MACOSX_DEPLOYMENT_TARGET = 26.0`; Swift 6 mode; strict concurrency. **Verify:** `xcodebuild -project Oriel.xcodeproj -scheme Oriel -configuration Release -showBuildSettings | grep -E ' ARCHS | MACOSX_DEPLOYMENT_TARGET | SWIFT_STRICT_CONCURRENCY | SWIFT_VERSION '` (Release, because Debug narrows `ARCHS` to the active architecture)
- [ ] `Info.plist`: `LSUIElement`, `LSMinimumSystemVersion = 26.0`, mic/camera usage strings, `oriel` URL scheme. **Verify:** `plutil -lint App/Info.plist` and a unit test reading the built bundle.
- [ ] `--self-test` loads every module, prints capability flags, exits 0. **Verify:** `build/Release/Oriel.app/Contents/MacOS/Oriel --self-test`
- [ ] `PrivateAPIs` resolves symbols via `dlsym` and never crashes when one is missing. **Verify:** unit test with an injected resolver returning nil for each symbol.
- [ ] Permissions center reflects live state without timers. **Verify:** `rg "Timer\.scheduledTimer|DispatchSource\.makeTimerSource" Packages/Permissions` returns nothing; manual toggle test.
- [ ] Launch at login via `SMAppService`. **Verify:** `SMAppService.mainApp.status == .enabled` after toggling; visible in System Settings → Login Items.
- [ ] Bootstrap import populates Settings and the Keychain and deletes the file. **Verify:** `--filter BootstrapImportTests`
- [ ] Diagnostics shows arch, Rosetta, Apple Intelligence, packs, private symbols, permissions. **Verify:** `oriel debug capabilities --json` lists all six keys.
- [ ] No dependencies. **Verify:** `rg -n "dependencies:" Packages/*/Package.swift` shows only local `path:` entries; `rg -n "url:" Packages/*/Package.swift` returns nothing.

### 13.2 Window switcher
- [ ] `WindowStore` builds the list from AX + CGWindowList + SkyLight with a fake `WindowSource` in tests. **Verify:** `swift test --package-path Packages/WindowSwitcher --filter WindowStoreTests`
- [ ] Filter, ordering, search and layout are pure functions with table tests. **Verify:** `--filter 'LayoutTests|SearchTests|FilterTests'`
- [ ] State machine covers hold/release, keep-open, cancel, Sticky Keys. **Verify:** `--filter SwitcherStateMachineTests`
- [ ] `oriel windows list --json` matches the fixture set. **Verify:** `ORIEL_TCC_TESTS=1 scripts/verify-windows.sh`
- [ ] `oriel windows focus <id>` focuses the right window on another Space. **Verify:** the script reads the frontmost window via AX afterwards.
- [ ] Cmd-Tab takeover is restored after quit and after `kill -9`. **Verify:** `scripts/verify-cmdtab-restore.sh` (TCC)
- [ ] Idle: 10 minutes at 0.0 % CPU. **Verify:** `scripts/idle-cpu.sh` (uses `top -l 600 -s 1 -pid $PID -stats cpu,idlew`)
- [ ] Reduce Transparency switches to opaque live. **Verify:** image-diff test with forced accessibility flags + manual.
- [ ] Exceptions exclude apps by bundle ID. **Verify:** unit test.
- [ ] Gesture recognizer rejects four-finger and two-finger sequences. **Verify:** unit test on recorded sequences in `Tests/Fixtures/gestures/`.
- [ ] `ShortcutRecorderView` rejects reserved combos and flags conflicts. **Verify:** `--filter ShortcutRecorderTests`
- [ ] Carbon engine registers/unregisters and fires. **Verify:** `swift test --package-path Packages/Hotkeys --filter CarbonHotkeyEngineTests`

### 13.3 Capture
- [ ] `ScreenGeometry` conversions correct for multi-display, mixed-scale layouts. **Verify:** `--filter ScreenGeometryTests`
- [ ] Area capture pixel dimensions = selection × scale. **Verify:** `oriel capture area --rect 100,100,400,300 --to file --path /tmp/a.png && sips -g pixelWidth -g pixelHeight /tmp/a.png` (TCC)
- [ ] Window capture excludes our overlays. **Verify:** image-diff test (TCC).
- [ ] Hotkey → overlay p95 < 120 ms. **Verify:** `scripts/perf-capture.sh` (signposts).
- [ ] Stitcher output correct on synthetic sequences (sticky header, repeated rows, end detection). **Verify:** `swift test --package-path Packages/Capture --filter StitcherTests`

### 13.4 Editor
- [ ] Every tool creates/edits/deletes items; undo/redo restores exact documents. **Verify:** `--filter EditorDocumentTests`
- [ ] Renderer output stable at 1× and 2×. **Verify:** image-diff tests.
- [ ] PNG/JPEG/HEIC/PDF export round-trips (UTType and dimensions). **Verify:** `--filter ExportTests`

### 13.5 Translation
- [ ] Each provider tested with `URLProtocol` stubs (request shape, headers, streaming parse, error mapping). **Verify:** `swift test --package-path Packages/OrielTranslation`
- [ ] Segment JSON contract tolerates extra prose and missing ids. **Verify:** `--filter SegmentParserTests`
- [ ] Keychain round-trip; keys never logged. **Verify:** unit test + `rg -n "apiKey" Packages | rg -v Keychain` review.
- [ ] Apple provider availability states map to UI. **Verify:** unit test with a fake availability adapter.
- [ ] Font fitting never overflows at ≥ minimum size. **Verify:** `--filter FontFitTests`
- [ ] Offline EN→JA works with packs installed and Wi-Fi off. **Verify:** `oriel translate area --rect … --to ja --provider apple --json` (TCC, manual).

### 13.6 Recording
- [ ] 10 s recording has duration ±0.2 s and the audio tracks enabled. **Verify:** `scripts/verify-recording.sh` (TCC)
- [ ] Pause-by-segment yields one playable file. **Verify:** `scripts/verify-recording.sh --pause` (TCC)
- [ ] GIF frame count and width limits. **Verify:** unit test on a generated asset.

### 13.7 Release
- [ ] Notarized, stapled DMG. **Verify:**
```bash
codesign --verify --deep --strict --verbose=2 dist/Oriel.app
codesign -d --entitlements :- dist/Oriel.app            # only device.audio-input and device.camera; no app-sandbox
lipo -archs dist/Oriel.app/Contents/MacOS/Oriel         # x86_64 arm64
lipo -archs dist/Oriel.app/Contents/Helpers/oriel      # x86_64 arm64
xcrun stapler validate "dist/Oriel-${VERSION}.dmg"
spctl -a -t open --context context:primary-signature -vv "dist/Oriel-${VERSION}.dmg"
```
- [ ] Installs through the tap on a clean macOS 26 VM with no Gatekeeper prompt. **Verify:** manual, recorded in `docs/qa-checklists.md`.

### 13.8 Clipboard History
- [ ] Classification, colors, the index (repeat copies, pins, reordering, Undo, limits), search, paste composition and the panel model are pure and tested. **Verify:** `swift test --package-path Packages/ClipboardHistory`
- [ ] The store is encrypted at rest, survives a restart and sets an unreadable history aside. **Verify:** `--filter ClipboardStoreTests`
- [ ] No polling and no concealed reads. **Verify:** `make lint` (the `no_polling` rule covers the package); `--filter 'PasteboardWatcherTests|PasteboardReaderTests'`
- [ ] Copies in other apps appear once Paste from Other Apps allows it; ⌥V opens the panel over the app in front; Return pastes into VS Code, Chrome and Messages. **Verify:** manual (`docs/qa-checklists.md`), with Accessibility and Paste from Other Apps.

---

## 14. Testing strategy

### 14.1 Unit tests
Swift Testing for all pure logic: state machines, layout, search, filters, geometry, stitching, segment parsing, provider request building/parsing, editor document operations, settings migrations. Target ≥ 80 % line coverage in pure packages; parameterized `@Test(arguments:)` for table tests.

### 14.2 TCC-gated and integration tests
```swift
extension Trait where Self == ConditionTrait {
    static var requiresTCC: Self {
        .enabled(if: ProcessInfo.processInfo.environment["ORIEL_TCC_TESTS"] == "1", "needs Accessibility/Screen Recording grants")
    }
}
```
Protocol fakes (`WindowSource`, `ScreenshotEngine`, `TranslationProvider`) in normal CI; real integration tests tagged `.requiresTCC` run on the dev Mac and the macOS 26 VM. Hosted runners cannot be granted Accessibility or Screen Recording, so they never run these. Live provider contract tests run behind `ORIEL_LIVE_PROVIDER_TESTS=1`. The trait lives in `OrielTestSupport`, a second product of `OrielCore`. xcodebuild passes environment variables to test processes only when they carry a `TEST_RUNNER_` prefix, so `make test` forwards `ORIEL_TCC_TESTS` as `TEST_RUNNER_ORIEL_TCC_TESTS`.

### 14.3 UI tests
XCUITest drives Settings, onboarding and the editor window. It cannot press global hotkeys into other apps or inspect non-activating overlays; use the Debug-only hooks `oriel debug open-switcher --shortcut N` and `oriel debug capture --fixture <png>` (compiled out of Release with `#if DEBUG`). UI tests need macOS Automation Mode, which asks for an admin password unless `automationmodetool enable-automationmode-without-authentication` has been run once, so `make test` runs them only with `ORIEL_UI_TESTS=1`. CI sets it if the runner image allows Automation Mode without authentication (check in Phase 1).

### 14.4 Image-diff and performance tests
In-repo helper: render to `CGImage`, compare against PNG references in `Tests/Fixtures/snapshots/` with a per-channel tolerance, record with `ORIEL_RECORD_SNAPSHOTS=1`, skip on OS versions other than the one the references were recorded on. `XCTClockMetric`/`XCTMemoryMetric` tests cover stitching 20 frames, OCR grouping of 500 lines, layout for n = 1…200 and thumbnail cache churn. Instruments runs each phase: Time Profiler on switcher open, Allocations over 1 h of use, Energy over 10 min idle.

### 14.5 Compatibility matrix

| Environment | macOS 26 | macOS 27 |
|---|---|---|
| M4 Pro (physical) | — | Primary: all suites incl. TCC, Instruments, 48 h soak |
| M4 Pro under Rosetta | — | x86_64 slice: self-test, unit tests, CLI smoke |
| arm64 VM (Tart / UTM) | Smoke + TCC suite nightly; clean-install onboarding | Optional second VM |
| Intel Mac (physical, optional) | Release QA (§14.6) | n/a |
| GitHub Actions arm64 runner (`macos-26`, or the newest available) | Build, lint, unit tests, Universal check, Rosetta job | — |

Multi-display, mixed-scale (Retina + 1× external) setups are tested manually before each release.

### 14.6 Manual QA script
60+ windows across four Spaces and two displays; full-screen Safari video; Electron apps (Slack, VS Code); a Java app; a VM app on the exception list; Sticky Keys on; Reduce Transparency on; Screen Recording denied; Accessibility revoked mid-session; sleep/wake; display unplug while the switcher is open; 48 h soak with memory sampling (`footprint` every 10 min).

---

## 15. Build, signing, notarization, installation and release

1. **Project:** XcodeGen `project.yml` (Appendix D); the generated `.xcodeproj` is git-ignored; local packages under `Packages/`. `MARKETING_VERSION` is SemVer; the build number (`CURRENT_PROJECT_VERSION`) is the git commit count at archive time, set by `scripts/release/export-app.sh`.
2. **Certificates:** one "Apple Development" certificate shared by every dev machine (export once; TCC grants are tied to the signing identity) and one "Developer ID Application" certificate for releases. The two signatures cannot share a bundle ID's permission entries, so Debug builds use `com.codertapsu.oriel.debug` ("Oriel Debug") and the release `com.codertapsu.oriel`; the release's certificate is chained to the current Developer ID CA (the original CA expires 2027-02-01). No "Developer ID Installer": there is no `.pkg`.
3. **Signing:** Hardened Runtime on the app and the CLI; sign inside-out (CLI first, then the app); `--deep` is for verification only. The CLI embeds its Info.plist, so it signs as `com.codertapsu.oriel.cli` rather than `oriel`. Plain builds, Release included, keep `com.apple.security.get-task-allow` so Instruments can attach; only the `developer-id` export strips it, so only `dist/` output gets notarized.
4. **Notarization:** `scripts/release/notarize.sh` runs `xcrun notarytool submit … --apple-id "$APPLE_ID" --password "$APPLE_PASSWORD" --team-id "$APPLE_TEAM_ID" --wait`, checks that the result is Accepted (printing Apple's log if not), staples the ticket and validates it. The release script uses it twice: on the exported app, so the copy a user drags out of the DMG carries its own ticket, and then on the DMG built from it. The four variables come from `scripts/apple-credentials.env`, git-ignored and shared with the other desktop apps; `APPLE_PASSWORD` is an app-specific password.
5. **DMG:** `scripts/release/make-dmg.sh` runs `hdiutil create -volname Oriel -srcfolder dist/dmgroot -ov -format ULFO dist/Oriel-$VERSION.dmg` with the stapled app and an `/Applications` symlink, then `codesign --sign "$APPLE_SIGNING_IDENTITY" --timestamp` on the DMG.
6. **Install:**
   - `make install` on a dev Mac (`scripts/install.sh`: Developer ID export, copy to /Applications, `codesign --verify`, open; local builds are not quarantined, so Gatekeeper never prompts).
   - Fleet: private tap `github.com/<ORG>/homebrew-oriel` with `Casks/oriel.rb` (Appendix A.5). Users run `brew tap <ORG>/oriel git@github.com:<ORG>/homebrew-oriel.git`, then `brew install --cask oriel` and later `brew upgrade --cask oriel`. The DMG lives on `<FILEHOST>` because private GitHub release assets need a custom download strategy. Notarized, so no `--no-quarantine`.
   - First launch from a read-only or translocated volume offers "Move to Applications", then onboarding. The copied app is launched with `--replacing <pid>` while the old copy quits without starting its services; the new one starts only after that process has ended (the workspace's terminate notification, a 30 s deadline), so the two never hold the socket, the shortcuts or the event tap at once.
   - Settings → About shows the version and a "Copy update command" button (`brew upgrade --cask oriel`). No updater code.
7. **CI (GitHub Actions):** `ci.yml` on pull requests and pushes to `main` (arm64 runner: XcodeGen, lint, Debug build, unit tests, Release Universal build, `lipo` check, Rosetta self-test after `softwareupdate --install-rosetta --agree-to-license`), signing ad hoc through the Makefile's `XCODEBUILD_FLAGS` (`CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=`), on `macos-26` with Xcode 27.1 unless the repository variables `ORIEL_CI_RUNNER` and `ORIEL_CI_XCODE` say otherwise; no release workflow: installers are built, notarized and verified on the maintainer's Mac by `scripts/release/release-macos.sh` (`docs/RELEASING.md`), as Gitweaver's and Mother Claude's are, so CI holds no signing secrets. `nightly-tcc.yml` targets a self-hosted runner only if one is ever set up.
8. **Uninstall:** Advanced → "Uninstall Oriel…" removes Application Support data, Keychain items, the login item and the CLI symlink; the cask's `zap` stanza does the same from Homebrew.

---

## 16. Risks and trade-offs

| Risk | Likelihood / impact | Mitigation |
|---|---|---|
| Private SkyLight/HIServices symbols change in a macOS update | Medium / High (switcher) | `dlsym` + capability flags + public fallbacks; symbol-presence test on each new beta; a fix release within days of each macOS .0 |
| Periodic Screen Recording prompt (15+) and `tccd` overhead | High / Medium | Screen Recording optional for the switcher; tile-size cached thumbnails; onboarding copy; MDM key when managed |
| TCC grants lost on re-sign or bundle move | Medium / Medium | Stable identities; detect a missing grant on activation and guide the user |
| Cooperative activation makes public focus unreliable | High (without SkyLight) | SkyLight primary, AX raise secondary |
| Event tap disabled by the system | Medium / High | Minimal callback; auto re-enable; check `tapIsEnabled` on app activation |
| Sticky Keys and accessibility edge cases | Medium / Medium | Forced keep-open mode; live opaque mode; Reduce Motion |
| Three-finger gesture conflicts with system gestures | High / Low | Onboarding prompt to move system gestures to four fingers; four-finger rejection |
| Liquid Glass changes between 26 and 27 (tint compositing) | Medium / Low | Untinted glass; one `Material` factory; image-diff tests per OS |
| SwiftUI performance in overlays | Medium / Medium | AppKit for every hot path |
| Memory growth with many windows | Medium / Medium | LRU cap, memory-pressure purge, release on close, 48 h soak |
| Scrolling capture failures | High / Low–Medium | Confidence threshold → manual mode; clear messaging |
| Translation API cost or key leakage | Medium / Medium | Apple/local defaults; usage caps; Keychain only; redacted logs |
| Intel coverage disappears (Rosetta gone in macOS 28) | High / Low | Rosetta while it lasts; optional physical Intel Mac; decide an Intel end-of-support date when Apple stops Tahoe security updates |
| A 27-only API turns out to matter | Low / Low | Floor change is two lines (§2.2) |
| The Developer ID certificate expires: the current one chains to the original CA and expires 2027-02-01 | High / High (no new signatures after that date) | Issue a G2-chained Developer ID Application certificate before 1.0 and update the CI secrets |

---

## 17. Additional features (after 1.0)

**1.x:** capture history with OCR-indexed search; pinned screenshots with opacity/click-through; background tool for social-ready shots; hide desktop icons during capture; "Copy Text" OCR mode; numbered-step and step-capture sequences; Smart Redact (auto-blur emails, phone numbers, keys found by OCR and data detectors, on device); more upload destinations (WebDAV, SFTP, shared folder, Dropbox/Drive via OAuth); Lightshot-style instant mode; switcher presets (active-app-only, app-grouped, per-display, quit-app).

**2.x:** video editor beyond trim (zoom/pan to clicks, webcam background blur, chapters); Snagit-style Smart Move/Simplify via Vision segmentation; "translate under cursor" live mode, file drag-in translation, per-project glossary, video-frame OCR; utility modules (color picker with contrast checker, screen ruler, window tiling hotkeys) as `UtilityModule`s, next to the switcher and Clipboard History; App Intents for capture/translate/focus; iCloud KVS settings sync.

---

## Appendix A — Repository files

### A.1 Layout

```
oriel/
├── CLAUDE.md                        # Appendix B
├── README.md                        # purpose, §3 requirements, install commands
├── project.yml                      # Appendix D (XcodeGen)
├── Makefile                         # Appendix C
├── ExportOptions.plist              # method: developer-id, signingStyle: manual, teamID
├── .gitignore  .swiftlint.yml  .swiftformat
├── App/
│   ├── Sources/                     # AppDelegate, StatusMenu, ModuleRegistry, Onboarding/, Settings/, Diagnostics/, Bootstrap/
│   ├── Resources/                   # Assets.xcassets (app icon: window with a projecting bay), Localizable.xcstrings (en only)
│   ├── Info.plist
│   └── Oriel.entitlements
├── CLI/Sources/main.swift           # oriel command (argument parsing by hand; no swift-argument-parser)
├── Packages/
│   ├── OrielCore/  PrivateAPIs/  Permissions/  Hotkeys/  SharedUI/  IPC/
│   ├── WindowSwitcher/  Capture/  Recording/  Editor/
│   └── OCR/  OrielTranslation/  Upload/
├── Spikes/S0-Release/ … S9-Recording/     # throwaway packages, deleted after Phase 1
├── Tests/
│   ├── OrielTests/  OrielUITests/
│   └── Fixtures/  (images/, gestures/, ocr/, scroll-frames/, snapshots/)
├── scripts/
│   ├── idle-cpu.sh  perf-capture.sh  verify-windows.sh  verify-recording.sh  verify-cmdtab-restore.sh
│   ├── fixtures/open-windows.sh
│   ├── install.sh                   # make install
│   ├── apple-credentials.env.example  # copy to apple-credentials.env (git-ignored), shared with the other desktop apps
│   └── release/  (release-macos.sh, export-app.sh, notarize.sh, make-dmg.sh; bump-cask.sh once the tap exists)
├── docs/
│   ├── PLAN.md                      # this document
│   ├── checklist.md  provenance.md  os-quirks.md  qa-checklists.md  bootstrap.example.json  RELEASING.md
│   ├── decisions/ADR-001-deployment-floor.md
│   ├── spikes/S0.md … S9.md
│   └── reports/00-bootstrap.md, phase-0.md, …
└── .github/workflows/  (ci.yml)
```

### A.2 Package template

Every package uses `// swift-tools-version: 6.2` (the first version with `.defaultIsolation`), `platforms: [.macOS("26.0")]`, `swiftLanguageModes: [.v6]`, one library product named after the package (`OrielCore` also exports `OrielTestSupport` for test targets), a `Tests/<Name>Tests` target, and `swiftSettings: [.defaultIsolation(MainActor.self)]` only for UI packages (`SharedUI`, `WindowSwitcher`, `Capture`, `Recording`, `Editor`); service packages keep nonisolated defaults and use actors.

### A.3 .gitignore

```
*.xcodeproj
build/
dist/
.build/
DerivedData/
*.p8
*.p12
bootstrap.json
.DS_Store
```

### A.4 Lint configuration

`.swiftlint.yml`
```yaml
included: [App, CLI, Packages, Tests]
excluded: [Spikes, build, .build, Packages/*/.build]   # swift test writes generated sources into each package's .build
custom_rules:
  no_polling:
    name: "No polling"
    regex: "Timer\\.scheduledTimer|DispatchSource\\.makeTimerSource|Timer\\.publish"
    message: "Polling is banned. Use observers/notifications. Allowed only inside Recording, ScrollingCapture and Activity Monitor sampling sessions."
    severity: error
    excluded: "Packages/(Recording|Capture|ActivityMonitor)/Sources/.*Session\\.swift"
  no_tcc_db:
    regex: "TCC\\.db|com\\.apple\\.TCC"
    message: "Never touch the TCC database."
    severity: error
opt_in_rules: [force_unwrapping, implicitly_unwrapped_optional, private_outlet, sorted_imports]
force_unwrapping: { severity: error }
trailing_comma: { mandatory_comma: true }   # agree with SwiftFormat's trailingCommas rule instead of fighting it
line_length: { warning: 140, error: 180 }
```

`.swiftformat`
```
--swiftversion 6.0
--indent 4
--maxwidth 140
--wraparguments before-first
--stripunusedargs closure-only
--exclude Spikes,build,.build
```

### A.5 Homebrew cask (`<ORG>/homebrew-oriel/Casks/oriel.rb`)

```ruby
cask "oriel" do
  version "0.1.0"
  sha256 "<sha256 of the DMG>"
  url "https://<FILEHOST>/oriel/Oriel-#{version}.dmg"
  name "Oriel"
  desc "Window switcher, capture, recording and screenshot translation"
  homepage "https://github.com/<ORG>/oriel"
  auto_updates false
  app "Oriel.app"
  zap trash: [
    "~/Library/Application Support/Oriel",
    "~/Library/Preferences/com.codertapsu.oriel.plist",
  ]
end
```

---

## Appendix B — CLAUDE.md (write verbatim)

```markdown
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
3. No polling: no repeating Timer, DispatchSourceTimer or sleep loop outside an active Recording or ScrollingCapture
   session, or while Activity Monitor's window is open (it samples only then). Everything else reacts to events.
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
```

---

## Appendix C — Makefile (recipes must be indented with a tab)

```makefile
SCHEME      := Oriel
PROJECT     := Oriel.xcodeproj
CONFIG_DIR  := build
DIST        := dist
VERSION     := $(shell sed -n -E 's/^ +MARKETING_VERSION: *"?([^"]*)"?.*$$/\1/p' project.yml)
PACKAGES    := $(wildcard Packages/*)
TOOL_LIST   := xcodegen swiftlint swiftformat
# UI tests need macOS Automation Mode, which asks for an admin password unless
# `automationmodetool enable-automationmode-without-authentication` has been run. Opt in with ORIEL_UI_TESTS=1.
UI_TESTS    := $(if $(filter 1,$(ORIEL_UI_TESTS)),,-skip-testing:OrielUITests)
# xcodebuild hands only TEST_RUNNER_-prefixed variables to test processes, so `test` forwards ORIEL_TCC_TESTS that way.
# Extra xcodebuild arguments for build, test and universal-check; CI signs ad hoc with them (.github/workflows/ci.yml).
XCODEBUILD_FLAGS ?=

.PHONY: generate build run test lint universal-check install release-dry-run clean tools

tools:
	@for t in $(TOOL_LIST); do command -v $$t >/dev/null || { echo "missing $$t (brew install $$t)"; exit 1; }; done

generate: tools
	xcodegen generate

build: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=macOS' -configuration Debug build $(XCODEBUILD_FLAGS)

run: build
	@pkill -x Oriel 2>/dev/null || true
	@for i in 1 2 3 4 5 6 7 8 9 10; do pgrep -x Oriel >/dev/null || break; sleep 0.2; done
	open "$$(xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $$2; exit}')/Oriel.app"

test: generate
	TEST_RUNNER_ORIEL_TCC_TESTS="$(ORIEL_TCC_TESTS)" xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=macOS' test $(UI_TESTS) \
	$(XCODEBUILD_FLAGS)
	@for p in $(PACKAGES); do echo "== $$p"; swift test --package-path "$$p" || exit 1; done

lint: tools
	swiftlint --strict
	swiftformat --lint .

universal-check: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release -destination 'generic/platform=macOS' \
	ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO CONFIGURATION_BUILD_DIR=$(CURDIR)/$(CONFIG_DIR)/Release build $(XCODEBUILD_FLAGS)
	lipo -archs $(CONFIG_DIR)/Release/Oriel.app/Contents/MacOS/Oriel | grep -q "x86_64 arm64\|arm64 x86_64"
	lipo -archs $(CONFIG_DIR)/Release/Oriel.app/Contents/Helpers/oriel | grep -q "x86_64 arm64\|arm64 x86_64"
	arch -x86_64 $(CONFIG_DIR)/Release/Oriel.app/Contents/MacOS/Oriel --self-test
	$(CONFIG_DIR)/Release/Oriel.app/Contents/MacOS/Oriel --self-test

install: generate
	bash scripts/install.sh        # archive → export (developer-id) → /Applications → codesign --verify → open

# Needs `source scripts/apple-credentials.env` first. Rehearses a release of the working tree at project.yml's
# version (gate, archive, export, notarize + staple the app and the dmg, verify) and publishes nothing.
release-dry-run: generate
	SKIP_UPLOAD=1 ALLOW_DIRTY=1 RELEASE_TAG=v$(VERSION) bash scripts/release/release-macos.sh

clean:
	rm -rf $(CONFIG_DIR) $(DIST) $(PROJECT)
```

---

## Appendix D — project.yml (XcodeGen)

```yaml
name: Oriel
options:
  bundleIdPrefix: com.codertapsu
  deploymentTarget:
    macOS: "26.0"
  xcodeVersion: "27.1"
  createIntermediateGroups: true
  generateEmptyDirectories: true

packages:
  OrielCore:        { path: Packages/OrielCore }
  PrivateAPIs:      { path: Packages/PrivateAPIs }
  Permissions:      { path: Packages/Permissions }
  Hotkeys:          { path: Packages/Hotkeys }
  SharedUI:         { path: Packages/SharedUI }
  IPC:              { path: Packages/IPC }
  WindowSwitcher:   { path: Packages/WindowSwitcher }
  Capture:          { path: Packages/Capture }
  Recording:        { path: Packages/Recording }
  Editor:           { path: Packages/Editor }
  OCR:              { path: Packages/OCR }
  OrielTranslation: { path: Packages/OrielTranslation }   # not "Translation": the SDK's Translation.framework owns that module name
  Upload:           { path: Packages/Upload }
  ClipboardHistory: { path: Packages/ClipboardHistory }
  DiskAnalyzer:     { path: Packages/DiskAnalyzer }
  ActivityMonitor:  { path: Packages/ActivityMonitor }
  ColorPicker:      { path: Packages/ColorPicker }
  ScreenRuler:      { path: Packages/ScreenRuler }
  WindowTiling:     { path: Packages/WindowTiling }

settings:
  base:
    MACOSX_DEPLOYMENT_TARGET: "26.0"
    ARCHS: "arm64 x86_64"              # explicit; never rely on ARCHS_STANDARD
    SWIFT_VERSION: "6.0"               # Swift 6 language mode
    SWIFT_STRICT_CONCURRENCY: complete
    ENABLE_HARDENED_RUNTIME: YES
    CODE_SIGN_STYLE: Manual
    DEVELOPMENT_TEAM: 4XVYLW8RXS
    DEAD_CODE_STRIPPING: YES
    ENABLE_USER_SCRIPT_SANDBOXING: YES
    MARKETING_VERSION: "0.1.0"
    CURRENT_PROJECT_VERSION: "1"
  configs:
    Debug:
      ONLY_ACTIVE_ARCH: YES
      CODE_SIGN_IDENTITY: "Apple Development"
    Release:
      ONLY_ACTIVE_ARCH: NO
      CODE_SIGN_IDENTITY: "Developer ID Application"
      SWIFT_COMPILATION_MODE: wholemodule

targets:
  Oriel:
    type: application
    platform: macOS
    sources: [App/Sources, App/Resources]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.codertapsu.oriel
        ORIEL_DISPLAY_NAME: Oriel
        SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor
      configs:
        Debug:                       # macOS keeps one permission entry per bundle ID, signed by whichever build asked
          PRODUCT_BUNDLE_IDENTIFIER: com.codertapsu.oriel.debug   # first; a shared ID locks the release out (os-quirks)
          ORIEL_DISPLAY_NAME: Oriel Debug                          # how System Settings lists it
    info:
      path: App/Info.plist
      properties:
        CFBundleDisplayName: $(ORIEL_DISPLAY_NAME)
        CFBundleShortVersionString: $(MARKETING_VERSION)   # XcodeGen's defaults are a literal 1.0 and 1
        CFBundleVersion: $(CURRENT_PROJECT_VERSION)
        LSUIElement: true
        LSMinimumSystemVersion: "26.0"
        NSMicrophoneUsageDescription: "Oriel records your microphone only during screen recordings you start."
        NSCameraUsageDescription: "Oriel shows your camera only in the recording overlay you enable."
        NSAppTransportSecurity:
          NSAllowsLocalNetworking: true      # Ollama / LM Studio / llama.cpp on localhost
          NSExceptionDomains:
            internal:                        # plain-HTTP team hosts such as http://ollama.internal (PLAN §7.7.5)
              NSIncludesSubdomains: true
              NSExceptionAllowsInsecureHTTPLoads: true
        UTExportedTypeDeclarations:
          - UTTypeIdentifier: com.codertapsu.oriel.document
            UTTypeDescription: Oriel Document
            UTTypeConformsTo: [com.apple.package, public.composite-content]
            UTTypeTagSpecification:
              public.filename-extension: [oriel]
        CFBundleDocumentTypes:
          - CFBundleTypeName: Oriel Document
            CFBundleTypeRole: Editor
            LSHandlerRank: Owner
            LSTypeIsPackage: true
            LSItemContentTypes: [com.codertapsu.oriel.document]
          - CFBundleTypeName: Image
            CFBundleTypeRole: Viewer
            LSHandlerRank: Alternate
            LSItemContentTypes: [public.png, public.jpeg, public.heic, public.tiff]
        CFBundleURLTypes:
          - CFBundleURLName: com.codertapsu.oriel
            CFBundleURLSchemes: [oriel]
    entitlements:
      path: App/Oriel.entitlements
      properties:
        com.apple.security.device.audio-input: true
        com.apple.security.device.camera: true
    dependencies:
      - package: OrielCore
      - package: PrivateAPIs
      - package: Permissions
      - package: Hotkeys
      - package: SharedUI
      - package: IPC
      - package: WindowSwitcher
      - package: Capture
      - package: Recording
      - package: Editor
      - package: OCR
      - package: OrielTranslation
      - package: Upload
      - package: ClipboardHistory
      - package: DiskAnalyzer
      - package: ActivityMonitor
      - package: ColorPicker
      - package: ScreenRuler
      - package: WindowTiling
      - target: oriel-cli
        embed: true                  # copied into Oriel.app/Contents/Helpers/oriel
        codeSign: true
        copy:                        # not Contents/MacOS: on case-insensitive APFS "oriel" there is the app's "Oriel"
          destination: wrapper
          subpath: Contents/Helpers

  oriel-cli:                         # target name must differ from "Oriel" by more than case (shared intermediates dir)
    type: tool
    platform: macOS
    sources: [CLI/Sources]
    settings:
      base:
        PRODUCT_NAME: oriel
        PRODUCT_MODULE_NAME: OrielCLI  # "oriel.swiftmodule" would share a path with the app's "Oriel.swiftmodule"
        PRODUCT_BUNDLE_IDENTIFIER: com.codertapsu.oriel.cli
        GENERATE_INFOPLIST_FILE: YES             # embedded in the binary, so the code signature's
        CREATE_INFOPLIST_SECTION_IN_BINARY: YES  # identifier is the bundle ID instead of "oriel"
        SKIP_INSTALL: YES              # it ships inside the app; installed on its own it makes the archive generic
    dependencies:
      - package: IPC
      - package: OrielCore

  OrielTests:
    type: bundle.unit-test
    platform: macOS
    sources: [Tests/OrielTests]
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES   # test bundles must be signed, and signing needs an Info.plist
    dependencies:
      - target: Oriel
      - package: OrielCore
        product: OrielTestSupport

  OrielUITests:
    type: bundle.ui-testing
    platform: macOS
    sources: [Tests/OrielUITests]
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
    dependencies: [{ target: Oriel }]

schemes:
  Oriel:
    build:
      targets: { Oriel: all, oriel-cli: all }
    run:
      config: Debug
    test:
      config: Debug
      targets: [OrielTests, OrielUITests]
      environmentVariables:
        ORIEL_TCC_TESTS: "0"
    archive:
      config: Release
```

If XcodeGen rejects any key (its schema moves), fix the key rather than the intent, and note it in `docs/reports/00-bootstrap.md`.

---

## Appendix E — macOS 27 SDK audit (spike S8)

```bash
SDK=$(xcrun --sdk macosx --show-sdk-path); xcrun --sdk macosx --show-sdk-version     # expect 27.x
# Objective-C frameworks: APIs introduced in 27
for f in ScreenCaptureKit Vision VisionKit AppKit AVFoundation ApplicationServices CoreGraphics; do
  echo "== $f"; grep -rn "macos(27" "$SDK/System/Library/Frameworks/$f.framework/Headers" 2>/dev/null
done
# Swift-only frameworks: read the .swiftinterface files
for f in Translation FoundationModels Observation; do
  echo "== $f"; grep -rn "macOS 27" "$SDK/System/Library/Frameworks/$f.framework/Modules" 2>/dev/null
done
# Deprecations to avoid
grep -rn "API_DEPRECATED.*macos(27" "$SDK/System/Library/Frameworks/ScreenCaptureKit.framework/Headers" \
                                  "$SDK/System/Library/Frameworks/AppKit.framework/Headers"
# Names this plan uses but could not verify against the SDK text
grep -rn "ScreenshotConfiguration\|preferredStrategy\|installedSource\|RecognizeDocumentsRequest\|captureMicrophone\|SCRecordingOutput" \
  "$SDK/System/Library/Frameworks/ScreenCaptureKit.framework" "$SDK/System/Library/Frameworks/Translation.framework" \
  "$SDK/System/Library/Frameworks/Vision.framework" 2>/dev/null | head -50
```

Record the findings in `docs/spikes/S8-sdk-audit.md` under three headings: *adopt now behind `#available(macOS 27, *)`*, *adopt if the floor moves to 27*, *ignore*. Look specifically for: a FoundationModels API for third-party or remote model providers (reported after WWDC 2026 by secondary sources only); `SCScreenshotManager` / `SCStreamConfiguration` additions; Vision document-recognition changes; `NSGlassEffectView` tint or style changes; the Translation `preferredStrategy` availability; the exact names of the APIs listed in the last grep.

---

## Appendix F — Open items to verify in Phase 0

1. Exact names of the macOS 26 screenshot-configuration type and the Translation preferred-strategy property (S8). **Resolved:** `SCScreenshotConfiguration` (26.0) and `TranslationSession.Strategy` with `preferredStrategy` (26.4); see `docs/spikes/S8-sdk-audit.md`.
2. Whether FoundationModels on macOS 27 exposes third-party or remote providers (S8). **Resolved:** yes, through the `LanguageModel` and `LanguageModelExecutor` protocols (27.0); not adopted while the floor is 26.
3. Apple Translation availability on Intel Macs (S7, only if an Intel Mac exists).
4. The Cmd-Tab symbolic hotkey ID for `CGSSetSymbolicHotKeyEnabled` (S4).
5. The Sticky Keys detection key in `com.apple.universalaccess` (S4).
6. The `CGEventType` raw value for gesture events in a tap (S5).
7. Rosetta availability on the hosted arm64 runner after `softwareupdate --install-rosetta` (S0).
8. The current macOS 27.x point release on the dev Mac (Software Update) before recording spike results. On 2026-10-28 the dev Mac runs 27.0.1 (26A434) and Software Update offers 27.2 (26B123).
9. Current model identifiers and prices for OpenAI, Anthropic, Google and DeepL (bootstrap file; never hard-coded).

---

## Appendix G — References consulted for this plan (verify before relying on them)

- AltTab behaviour and compatibility notes: https://github.com/lwouis/alt-tab-macos · https://alt-tab.app/features · ScreenCaptureKit thumbnails commit https://github.com/lwouis/alt-tab-macos/commit/7821d7c
- macOS 27 / Xcode 27 developer changes: https://blakecrosley.com/blog/macos-27-golden-gate-release · https://blakecrosley.com/blog/xcode-27-release · https://blakecrosley.com/blog/xcode-27-build-failures-ld64-clang-modules · https://en.wikipedia.org/wiki/MacOS_Golden_Gate
- Legacy capture API removal: https://trac.macports.org/ticket/70957
- Sequoia screen-recording prompt: https://tinyapps.org/blog/202409180700_disable_sequoia_nag.html · https://community.jamf.com/t5/jamf-pro/monthly-tccc-prompts-macos-v15/m-p/339150
- Cooperative activation (macOS 14): https://wwdcnotes.com/documentation/wwdc23-10054-whats-new-in-appkit/ · https://github.com/macvim-dev/macvim/issues/1456
- Option-only hotkeys on macOS 15.0–15.1: https://developer.apple.com/forums/thread/763878 · https://github.com/feedback-assistant/reports/issues/552
- Liquid Glass behaviour: https://github.com/luzijun360/LiquidGlass · https://github.com/manaflow-ai/cmux/issues/5860 · https://github.com/KiwiCanopy/KiwiDesk/pull/1419
- Vision document recognition (WWDC 2025): https://developer.apple.com/videos/play/wwdc2025/272/
- Foundation Models provider reports: https://dev.to/arshtechpro/wwdc-2026-apple-just-opened-the-foundation-models-framework-to-any-llm-provider-5ejn
- Competitor features: https://cleanshot.com/features · https://snagit.software/ · https://monosnap.ai/ · https://app.prntscr.com/en/index.html

# Oriel — Technical Design and Implementation Plan

**Version 2.10 · 2026-10-30 · Supersedes v2.9, v2.8, v2.7, v2.6, v2.5, v2.4, v2.3, v2.2, v2.1, v2.0 (consolidated), the v1 research plan and the v2 addendum**

**Changes in 2.10** (release 0.1.0, `docs/reports/06-dock-and-clean-up.md`): the window switcher shows an app's windows next to its Dock icon while the pointer rests on it, and the number of windows on the Dock icons of apps with two or more, drawn by a click-through window over the Dock because no app can set another app's Dock badge; both read the Dock through Accessibility, are on by default and run while the switcher itself is off (§7.1.12). Disk Space Analyzer's **Clean Up**, in a folder's menu, the inspector and Space Hogs' rows, checks a folder and recommends the safest way to get its space back: a catalog of the folders Oriel knows, else the folder's place, name and contents, then what can only make it more cautious (processes using it, its app running, repositories, personal files, who may remove it); everything goes to the Trash with Undo, and Apple Intelligence's on-device model explains folders the catalog does not know without ever making the advice less careful (§7.10 item 19). The Info.plist names the app category (Appendix D). No entitlement, private API or dependency was added.

**Changes in 2.9** (release 0.1.0, `docs/reports/05-administrator-helper.md`): Read as Administrator asks for a password once. Oriel's helper, a launchd daemon in the app bundle registered with `SMAppService` and switched on once in System Settings with an administrator's password, reads the folders only an administrator can open after every scan, each end of its XPC connection requiring the other's code signature; the password prompt stays for a single scan and for builds without the helper (§7.10 item 17, §8.1). Biggest Files lists macOS's own files at the top level (§7.10 item 18). A build phase writes the helper's launchd property list (Appendix D). No entitlement or dependency was added.

**Changes in 2.8** (release 0.1.0, `docs/reports/04-first-use-fixes.md`): fixes from the first days of use. The switcher and Window Tiling never send Oriel itself an AX request, which macOS answers inside Oriel on the calling thread: the switcher trapped there once an Oriel window had made it relevant, which looked like Oriel quitting after its window closed (§7.1.1, §7.14; CLAUDE.md rule 6 and Appendix B say so). Oriel opens Settings when the user starts it, not at login (§10.1). Disk Space Analyzer says why a folder could not be read, since Full Disk Access does not open folders only their owner may open; reads those as an administrator on request, by running its own executable as root through macOS's password prompt to list them; counts macOS's own volumes file by file in a folder named macOS, Preboot as one block; and measures volumes with `ATTR_VOL_SPACEUSED`, since `statfs` gives every APFS volume the whole container's use (§7.10 items 2, 6, 12, 16–18). No entitlement or dependency was added.

**Changes in 2.7** (release 0.1.0, `docs/reports/03-roadmap-and-tools.md`): everything §17 listed for 1.x and 2.x is built, and so are two tools it did not list, Disk Space Analyzer (§7.10) and Activity Monitor (§7.11); §17 now maps each item to its section and lists what remains. Tools and features declare their own commands (`ToolCommand`), which get a shortcut, a status-menu item, an `oriel://` route, a row in Settings → Shortcuts and a place in the Shortcuts app, so a tool plugs in without changes to the app (§6.3, §6.5). Five new tools are `UtilityModule`s, on by default and turned on once after the update: Disk Space Analyzer, Activity Monitor, Color Picker (§7.12), Screen Ruler (§7.13) and Window Tiling (§7.14). The switcher has presets (§7.1.11); capture has Capture Text, Step Capture, hidden desktop icons, history snippets and fuller pins (§7.2); the editor has Instant Capture, backgrounds, numbered-step styles, Smart Redact, Simplify and Smart Move (§7.5); recording keeps clicks for Auto Zoom and can blur the camera background (§7.4), and a video editor trims, zooms, adds chapters and reads a frame's text (§7.15); translation has Translate Under Cursor, file translation and glossary projects (§7.7.8–§7.7.10); upload has six kinds of destination (§7.8). Settings sync through iCloud (§7.16) and App Intents (§7.17) are built. CLAUDE.md rule 3, and its copy in Appendix B, lets Activity Monitor sample while its window is open and only then (§7.11, §9). Disk Space Analyzer asks for nothing up front: macOS asks for the folders a scan reads, with the usage strings in Appendix D, and Full Disk Access is suggested from the folders it could not read, never probed (§8.1). No entitlement or dependency was added.

**Changes in 2.6** (release 0.1.0, `docs/reports/02-clipboard-history.md`): Clipboard History is the second utility module (§7.9): it keeps text, links, colors, images, files and other data, encrypted at rest with a key in the Keychain, and opens a panel on ⌥V to search, preview, pin, reorder, delete and paste an item into the app in front. It notices copies without a timer, by comparing the pasteboard's change count after input events and app switches (§7.9 item 3, CLAUDE.md rule 3), and reads other apps' copies only as macOS's Paste from Other Apps allows, which is checked with `NSPasteboard.accessBehavior` (§8.1; CLAUDE.md rule 8 names it). Every interactive capture is also copied to the clipboard, on by default, so it is in Clipboard History even when Quick Access is closed with Esc (§7.2 item 8). Every write Oriel makes to the general pasteboard goes through `SharedUI.Pasteboard`, which announces it (§6.2). Modules that arrive in an update are turned on once (§6.3).

**Changes in 2.5** (release 0.1.0, `docs/reports/01-implementation.md`): the parts of §7 that the pre-release builds lacked are built. Capture has the live mode for video (Settings → Capture → Freeze the screen while selecting, off; §7.2 item 2) and Capture with Timer in the menu, as a shortcut, as `oriel://capture/timer` and as the CLI's `--delay` (§7.2 item 3, §7.1.8). Record Window records the picked window's frame (§7.4). The status menu has Pinned (§10.1). The editor has Quick Look on ⌘Y (§7.5). The switcher's display is a setting (§7.1.3). Google glossaries use Cloud Translation v3 with a service account key, because v3 takes no API keys (§7.7.2, §7.7.5). Models running on an Intel Mac carry a warning (§7.7.7, §11). Move to Applications hands over without a race (§15.6). CI runs `.github/workflows/ci.yml`, signing ad hoc (§15.7, Appendix C).

**Changes in 2.4** (pre-release testing): the bundle ID is `com.codertapsu.oriel` (D14), and Debug builds are `com.codertapsu.oriel.debug`, shown as "Oriel Debug" (§15 item 2, CLAUDE.md rule 14), because macOS keeps one permission entry per bundle ID and a Debug build's entry locked the notarized build out of Accessibility (`docs/os-quirks.md`); Debug and release keep separate settings and keychain items and never run at the same time; permissions are re-read when any app comes to the front and when macOS reports an Accessibility change, not only when Oriel is activated (§8.1); on macOS 27 the Accessibility pane is called "Device Control and Data Access", and the permission list names it.

**Changes in 2.3** (the feature-complete build, `docs/reports/01-implementation.md`): the §6.2 table matches the packages (Recording depends on OrielCore, Permissions and SharedUI and gets its region from the app through Capture's `selectRegion`, so it does not link Capture; OrielTranslation and Upload also use SharedUI; PrivateAPIs is Swift-only and loads no MultitouchSupport symbol, because the event tap's gesture events were enough, §7.1.5); the Info.plist gains an ATS exception for plain-HTTP `.internal` hosts and the `.oriel` document type (Appendix D); the build number is the commit count (§15); the §13 Verify scripts exist (`scripts/verify-windows.sh`, `verify-cmdtab-restore.sh`, `verify-recording.sh`, `idle-cpu.sh`, `perf-capture.sh`, helpers in `scripts/support/`), driven by two Debug-only verbs, `oriel debug record` and `oriel debug perf-capture`; `docs/BUILDING.md` documents building, signing, notarizing and packaging by hand, and `docs/APP_STORE.md` what a Mac App Store submission would take (a separate sandboxed edition; D3 is unchanged).

**Changes in 2.2:** releases are built, notarized and verified on the maintainer's Mac by `scripts/release/release-macos.sh`, with the `scripts/apple-credentials.env` file shared with Gitweaver and Mother Claude (Apple ID plus app-specific password), instead of in CI with an API key; `docs/RELEASING.md` is the runbook (§15).

**Changes in 2.1** (bootstrap review, `docs/reports/00-bootstrap.md`): the CLI is embedded at `Oriel.app/Contents/Helpers/oriel` (target `oriel-cli`, module `OrielCLI`), because in `Contents/MacOS` the name `oriel` is the app's own executable on a case-insensitive volume; the `Translation` package is `OrielTranslation`; packages use `swift-tools-version: 6.2`; UI tests are opt-in with `ORIEL_UI_TESTS=1`; `make test` forwards `ORIEL_TCC_TESTS` to the Xcode test bundles; `make run` launches a Debug build; the team ID and signing identity are filled in; Appendices A.4, B, C and D match the repository files; spike S8 answered Appendix F items 1 and 2.

Oriel is an internal, native macOS menu-bar utility with three main tools, an AltTab-class window switcher, a snipping tool (screenshot, screen recording, editor) and instant screenshot translation, and six utilities beside them: Clipboard History, Disk Space Analyzer, Activity Monitor, Color Picker, Screen Ruler and Window Tiling (§7.9–§7.14). It is written from scratch in Swift 6 (AppKit + SwiftUI), targets macOS 26.0 and later, is built with the macOS 27 SDK, ships as a Universal binary, is Developer ID signed and notarized, is not sandboxed, and has zero runtime dependencies.

---

## 0. Instructions for Claude Code — read this first

### 0.1 What this document is

This is the single source of truth for Oriel: product requirements (§1), decisions (§2), system requirements (§3), feasibility (§4), stack (§5), architecture (§6), implementation approaches (§7), permissions (§8), performance (§9), UI/UX (§10), platform strategy (§11), roadmap (§12), checklist (§13), testing (§14), release (§15), risks (§16), the roadmap items built in 0.1.0 and what remains (§17) and the project files to create (Appendices A–E).

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
| Capture and recording | ScreenCaptureKit, AVFoundation (`AVMutableComposition`, `AVAssetExportSession`, `AVAssetImageGenerator`; `AVAssetReader`, `AVAssetWriter` and a custom `AVVideoCompositing` compositor for the video editor), AVKit (`AVPlayerView` trimming) |
| Image processing | Core Graphics, Core Image (`CIGaussianBlur`, `CIPixellate`), Accelerate (vDSP for stitching), ImageIO (`CGImageDestination` for PNG/JPEG/HEIC/GIF), Vision segmentation and saliency for Smart Move and the camera background |
| OCR | Vision (`RecognizeDocumentsRequest`, `RecognizeTextRequest`) |
| Translation | Translation framework, FoundationModels, URLSession providers; PDFKit and NaturalLanguage for file translation |
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
│  ┌──────────── Features and tools (tools are UtilityModules) ─────────┐                       │
│  │ WindowSwitcher   Capture   Recording   Editor   OrielTranslation   │                       │
│  │ ClipboardHistory   DiskAnalyzer   ActivityMonitor   ColorPicker    │                       │
│  │ ScreenRuler   WindowTiling   (future tools…)                       │                       │
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
| `OrielCore` | — | Protocols, models (`WindowInfo`, `ShortcutSpec`, `CaptureResult`, `OCRBlock`, `TranslationRequest`), `Capabilities`, `FeatureGate`, `SettingsStore`, `KeychainStore`, errors, DI `ServiceContainer`, logging categories, `UtilityModule`, `ToolCommand` and `CommandProviding` (§6.3, §6.5), the settings-sync model (`SettingsSyncPolicy`, `SettingsSnapshot`, `SettingsMerge`, §7.16), and test support as a second product, `OrielTestSupport` (`.requiresTCC`, image diff) |
| `PrivateAPIs` | — (Swift only) | `dlsym` loading of `_AXUIElementGetWindow`, `_AXUIElementCreateWithRemoteToken`, `_SLPSSetFrontProcessWithOptions`, `SLPSPostEventRecordTo`, `GetProcessForPID`, `SLSMainConnectionID`, `SLSGetActiveSpace`, `SLSCopyManagedDisplaySpaces`, `SLSCopySpacesForWindows`, `CGSGetSymbolicHotKeyValue`, `CGSSetSymbolicHotKeyEnabled`, `CGSIsSymbolicHotKeyEnabled` (docs/provenance.md). Each symbol is `Optional`; `PrivateAPIs.presence` reports which resolved. No MultitouchSupport: gestures come from the event tap (§7.1.5). |
| `Permissions` | OrielCore | AX trust, Screen Recording preflight/request, mic/camera, System Settings deep links, change observation |
| `Hotkeys` | OrielCore | `EventTapHotkeyEngine` (switcher), `CarbonHotkeyEngine` (capture/translate/record), `ShortcutRecorderView`, Sticky Keys policy |
| `SharedUI` | OrielCore | `Material.make(for:)` (glass / opaque), HUD primitives, panel base classes, accessibility helpers, `Pasteboard` (every write to the general pasteboard, announced to Clipboard History) |
| `IPC` | OrielCore | Socket server (app) and client (CLI), Codable request/response types |
| `WindowSwitcher` | OrielCore, PrivateAPIs, Permissions, Hotkeys, SharedUI | `WindowStore`, AX observers, focus engine, switcher panel, preview panel, layout, search, presets and grouping (§7.1.11), gesture recognizer, exceptions |
| `Capture` | OrielCore, Permissions, SharedUI | Shareable-content cache, screenshot engine, freeze-frame overlay, window snapping, magnifier, Quick Access Overlay, scrolling capture, pinboard, Capture Text, Step Capture, the desktop-icon filter, history search (§7.2) |
| `Recording` | OrielCore, Permissions, SharedUI | `SCRecordingOutput` session, segments, audio, camera bubble and its background effect, click/keystroke overlays, the click log for Auto Zoom, GIF export, trimming, the video editor (§7.15) |
| `Editor` | OrielCore, SharedUI | Document model, tools, renderer, undo, export, Instant Capture, backgrounds, Smart Redact, Simplify and Smart Move (§7.5) |
| `OCR` | OrielCore | `OCRService`, geometry conversion, layout grouping, language detection |
| `OrielTranslation` | OrielCore, OCR, SharedUI | `TranslationProvider` protocol, providers, segment JSON contract, overlay renderer, history, usage counters, Translate Under Cursor, file translation, glossary projects (§7.7.8–§7.7.10) |
| `Upload` | OrielCore, SharedUI | `DestinationUploader` protocol (S3, WebDAV, SFTP, shared folder, Dropbox, Google Drive), `UploadService` actor, the destinations and their Settings pane, the progress panel (§7.8) |
| `ClipboardHistory` | OrielCore, SharedUI | The Clipboard History `UtilityModule` (§7.9): pasteboard watcher and reader, classifier, encrypted store, OCR indexing, the history panel, pasting by posting ⌘V, the Settings pane |
| `DiskAnalyzer` | OrielCore, SharedUI | Disk Space Analyzer (§7.10): the scanner and its compact tree, volumes and cloud locations, charts and analyses, `FileOperator` and its safety rules, the window, the Settings pane, `oriel disk …` |
| `ActivityMonitor` | OrielCore, SharedUI | Activity Monitor (§7.11): process and system readers, `SamplingSession`, the window, signals and their safeguards, the Settings pane, `oriel top` |
| `ColorPicker` | OrielCore, SharedUI | Color Picker and contrast checker (§7.12): color math, formats and parsing, the library store, the panel, palette export |
| `ScreenRuler` | OrielCore, SharedUI, Permissions | Screen Ruler (§7.13): the edge map, the session state machine, the overlay |
| `WindowTiling` | OrielCore, SharedUI, Permissions | Window Tiling (§7.14): layout geometry, `WindowArranger`, the tool's own AX actor `WindowMover`, the submenu, the Settings pane |
| App target `Oriel` | all of the above | Status item, `ModuleRegistry`, onboarding, Settings window, bootstrap import, settings sync (§7.16), App Intents (§7.17) |
| Tool target `oriel-cli` (binary `oriel`, module `OrielCLI`, embedded at `Contents/Helpers/oriel`) | IPC, OrielCore | `oriel windows …`, `oriel capture …`, `oriel translate …`, `oriel top`, `oriel disk …`, `oriel debug …` |

### 6.3 Module interface (future tools without re-architecture)

```swift
@MainActor
public protocol UtilityModule: CommandProviding {    // commands: [ToolCommand] (§6.5), none by default
    static var id: ModuleID { get }                  // "window-switcher", "disk-analyzer", …
    var displayName: String { get }
    var requiredPermissions: Set<PermissionKind> { get }
    var menuItems: [NSMenuItem] { get }              // extra status-menu items; its commands are listed already
    var settingsPane: AnyView? { get }               // SwiftUI pane in Settings
    var settingsSymbol: String { get }               // the SF Symbol of that pane
    var ipcCommands: [IPCCommandHandler] { get }     // contributed CLI verbs
    func activate(context: ModuleContext) async      // start observers and hotkeys
    func deactivate() async                          // tear down; must leave zero timers
}

public struct ModuleContext: Sendable {
    public let services: ServiceContainer            // DI: protocol existentials only
    public let settings: SettingsStore
    public let log: Logger
    public let openSettings: @MainActor @Sendable () -> Void   // Settings at the module's own pane
}
```

`ModuleRegistry` reads the enabled-modules setting, activates modules lazily and deactivates a module when the user disables it, releasing its observers, taps and caches. A new tool is a new package conforming to `UtilityModule`, as Clipboard History (§7.9) and the tools of §7.10–§7.14 are. A default-on module that arrives in an update is turned on once, also for a user who had already chosen their tools (`app.offeredModules` remembers which were offered).

A tool plugs in without changes to the app. Its `commands` (`ToolCommand`: a stable id, a title, an SF Symbol, a status-menu group, an optional default shortcut and an optional `oriel://` route) get a global shortcut, a status-menu item, a URL and a row in Settings → Shortcuts, under the tool's name. Its `settingsPane` gets a Settings pane under the module's ID, titled with its display name and shown with its `settingsSymbol`. Its `ipcCommands` get CLI verbs, which answer that the tool is off while it is (status 69). Its `ModuleContext` opens Settings at its own pane. A tool's commands are registered only while it is turned on, so a tool that is off keeps no key from other apps, and they are listed in the menu only while it runs. A change of the tools that does not go through Settings, as from settings sync (§7.16), starts and stops them (`ModuleRegistry.applyEnabledModules`).

### 6.4 Concurrency and state

- **Main actor:** all AppKit/SwiftUI, the switcher panel state machine, menu and status item.
- **AX actor:** a dedicated serial actor for every `AXUIElement*` call, with `AXUIElementSetMessagingTimeout(element, 0.25)` on each app element. AX calls are synchronous IPC to other processes and block when the target hangs; they never run on the main thread during switcher presentation. Window Tiling has an AX actor of its own, `WindowMover`, with the same timeout, so it works with the switcher off (§7.14 item 6).
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
| Features and tools → app | `ToolCommand`s through `CommandProviding` (below); CLI verbs as `IPCCommandHandler`s |
| CLI ↔ app | Unix domain socket at `~/Library/Application Support/Oriel/ipc.sock` |
| Scripts, other apps | URL scheme `oriel://…`, one route per action and command (`oriel://capture/area`, `oriel://ruler`); App Intents in Shortcuts and Spotlight (§7.17) |
| Mac ↔ Mac | Settings sync through iCloud Drive or iCloud key-value storage (§7.16) |

`AppAction` remains the table of the app's own actions. Features and tools add theirs as `ToolCommand`s, through `CommandProviding`: Capture, Recording, Translation and the editor return them from their coordinators (the editor returns none: everything it adds acts on an open document), and tools from their modules. Instant Capture's command is the app's own (`FeatureHub`), because it joins Capture and the editor. The app wires every command the same way as an action, through shortcuts, the status menu, `oriel://` URLs, Settings → Shortcuts and App Intents (§7.17); a command with `showsInMenu` false (Window Tiling's, which its submenu lists, and Disk Space Analyzer's Scan Folder…) stays out of the menu. A command's shortcut is stored as `shortcuts.<id>`, so ids never change, and `commands` is read again whenever it is needed, so a title can follow state ("Finish Step Capture"). Clipboard History's ⌥V moved from the table to its module under the same id (`showClipboardHistory`) and route (`clipboard`), so a shortcut set before keeps working. No two actions or commands share an id, a default shortcut or a route (`AllCommandsTests`).

---

## 7. Implementation approaches

### 7.1 Window management

#### 7.1.1 Enumeration (event-driven, cached)

1. **Bootstrap** at launch and whenever Accessibility is granted: for each `NSRunningApplication` with `activationPolicy == .regular` (plus `.accessory` apps that own layer-0 windows) create `AXUIElementCreateApplication(pid)` and an `AXObserver`; read `kAXWindowsAttribute`; map each AX element to its `CGWindowID` with `_AXUIElementGetWindow`; read title, role/subrole, minimized and full-screen state. **Never Oriel itself:** macOS answers an AX request to the asking process inside it, on the calling thread, so AppKit would walk Oriel's views on the AX queue (it trapped on a main-actor check in every build so far, `docs/os-quirks.md`). `AXClient` refuses Oriel's pid, and `OwnWindows` lists, focuses, closes and minimizes Oriel's standard windows (titled, normal level, not panels) through AppKit on the main thread, with `NSWindow` notifications in place of AX observers (`OwnWindowObserver`). Quitting from the switcher never quits Oriel; only its menu's Quit does.
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
- **Key hints:** a line under the tiles names the window keys with the shortcut's own modifier ("⌥W Close ⌥M Minimize ⌥F Full Screen ⌥Q Quit App"); W, M, F and Q act only with ⌘, ⌥ or ⌃ held, plain letters type into the search (§7.1.11 item 4).

#### 7.1.5 Trackpad gestures

- **Primary:** gesture events in the same event tap (the `CGEventType` that corresponds to `NSEvent.EventType.gesture`; confirm the raw value in S5). Recognize three-finger horizontal travel with a distance threshold and per-finger travel checks; invalidate the session when a fourth finger appears (prevents misfires during four-finger Spaces swipes) or when only two fingers are down (scrolling). Swiping opens the switcher, further travel moves the selection, lifting commits.
- **Fallback (spike only):** private MultitouchSupport contact frames, only if gesture events cannot produce reliable finger counts on macOS 26/27.
- Onboarding detects that the system's three-finger "swipe between full-screen apps" is enabled and links to Trackpad settings.

#### 7.1.6 Zero-CPU idle

- No `Timer`, `DispatchSourceTimer` or polling in the steady state. A SwiftLint custom rule bans `Timer.scheduledTimer` outside `Recording` and `Capture` sessions and Activity Monitor's `SamplingSession`, which runs only while its window is open (§7.11 item 1). Clipboard History checks the pasteboard only after events (§7.9 item 3); the other tools wait for events too, with one-shot delays at most.
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
| AppleScript / App Intents | App Intents are built, for the Shortcuts app and Spotlight (§7.17); no AppleScript |
| **Unix domain socket** | **Chosen.** Request/response, streaming, trivially testable. 0600 in Application Support, `getpeereid` same-UID check, newline-delimited JSON. |

```
oriel windows list [--json] [--space current|all] [--app <bundle-id>]
oriel windows focus <window-id> | --title <substring>
oriel windows close|minimize <window-id>
oriel capture area|window|screen [--rect x,y,w,h] [--delay <1–60 s>] [--to clipboard|file|editor] [--path …]
oriel capture text [--rect x,y,w,h] [--json]                        # §7.2 item 10
oriel translate area [--rect …] [--to <lang>] [--provider <id>] [--json]
oriel top [--sort cpu|memory|disk|network] [--limit <n>] [--json]   # §7.11
oriel disk volumes [--json]                                         # §7.10, read-only
oriel disk scan <path> [--top <n>] [--json]                         # §7.10, read-only; waits up to 10 minutes
oriel debug capabilities --json | open-switcher --shortcut N | capture --fixture <png>   # Debug builds only
```

`CommandParser` turns `oriel <noun> <verb>` into the verb `noun.verb` and a one-word command (`top`) into its own verb; the app answers usage errors with status 64. Capture answers `capture.text` itself, and a tool's verbs come from its module (§6.3).

Settings → Advanced → "Install command-line tool…" creates a symlink to `Oriel.app/Contents/Helpers/oriel` at `/usr/local/bin/oriel` (admin prompt) or `~/.local/bin/oriel`. The CLI cannot live next to the app's executable in `Contents/MacOS`: on a case-insensitive volume, the macOS default, `oriel` and `Oriel` are the same file.

#### 7.1.9 Accessibility options

Observe `NSWorkspace.accessibilityDisplayOptionsDidChangeNotification`: `accessibilityDisplayShouldReduceTransparency` → opaque `windowBackgroundColor` fill; `…ShouldIncreaseContrast` → 1 px borders; `…ShouldReduceMotion` → no spring/scale animations. Each tile is an `NSView` with `accessibilityRole = .button` and a label "Title — App, minimized, Space 2" so basic VoiceOver works; announcement polish is deferred.

#### 7.1.10 Switcher UI

- `NSPanel` with `styleMask [.nonactivatingPanel, .borderless]`, `level = .popUpMenu`, `collectionBehavior [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]`, `hidesOnDeactivate = false`, `becomesKeyOnlyIfNeeded = true`.
- Material: `NSGlassEffectView(style: .regular)`, no tint (macOS 27 changed how dark tints composite), content in `contentView`; under Reduce Transparency swap in an opaque layer. The choice lives in `SharedUI.Material.make(for:)`.
- Preview: a second borderless panel at `.popUpMenu - 1` showing the selected window's cached full-resolution capture at its real frame, dimmed when stale.
- Styles: thumbnail grid; app icons with a window-count badge; title list (table). Search filters live with a subsequence fuzzy score over "title app" and highlights matches. Auto-size: §10.3.

#### 7.1.11 Presets, grouping and quitting apps

1. **Presets:** every shortcut shows one of **All windows**, **Active app's windows**, **Windows grouped by app** or **This display's windows** (the display the switcher opens on, per Show on). A preset sets the shortcut's apps filter, its screens filter and its new grouping (`ShortcutSpec.grouping`, `ungrouped` or `byApp`), and leaves the Spaces, minimized and hidden filters alone, so they combine. `SwitcherPreset` is derived from those three settings, never stored beside them, so the two cannot disagree; a mix no preset names (the active app on this display) shows as Custom. The picker sits in each shortcut's row in Settings → Window Switcher; the row's disclosure has the Apps, Screens (now "The screen it opens on") and Order pickers.
2. **Migration:** `grouping` is an optional field of `switcher.shortcuts`; settings written by earlier builds decode as `ungrouped`, so every shortcut shows the preset it already amounts to (⌥⇥ All windows; the ⌥\` that Add Shortcut proposes, Active app's windows) and nothing else changes.
3. **Grouped by app:** the windows are ordered by app with app headers, rather than a row per app that expands into its windows, which would need a second level and a key to enter it, and would clash with ↑/↓ between grid rows and with release-to-switch. Ordering keeps every key as before: Tab, arrows, digits, search and release. Apps come in the order of their most recent window, each app's windows most recent first; a search keeps the best match first with the rest of its app after it. In the thumbnail grid every row carries a 22 pt label band with each app's name over its tiles in that row (repeated when a group wraps), so groups pack the rows as ungrouped tiles do; in the title list each group gets a 26 pt header row. Headers are accessibility headings (`NSAccessibility.Role.headingRole`, `docs/os-quirks.md`). The app-icons style is unchanged. The first selection still lands on the previously used window, wherever grouping put it, so a quick ⌥⇥ keeps switching back and forth.
4. **Quitting from the switcher:** with ⌘, ⌥ or ⌃ held, Q quits the selected window's app through `NSRunningApplication.terminate()` (apps may ask to save), W closes the window, M minimizes it and F toggles full screen; plain letters type into the search. A hint line under the tiles names those keys with the shortcut's modifier, hidden for an empty list and switchable in Settings → Window Switcher → Appearance (`switcher.showsKeyHints`, on).
5. **Budget (§9):** opening runs filter, rank, group, items, layout, header placement and the first selection synchronously in the tap callback; with 200 windows that took 0.1–0.8 ms at p95 in the unoptimized test build for every preset (`OpeningCostTests`), against the 50 ms hotkey-to-first-frame budget.

#### 7.1.12 Dock previews and window counts

1. **What it does:** resting the pointer on the Dock icon of an app with windows shows them next to the icon as the switcher's thumbnail tiles (title, and badges for minimized, hidden, another Space or display), most recently used first, after 250 ms, and at once when moving from icon to icon. A click switches to the window (§7.1.3); the hover buttons close, minimize or toggle full screen. Apps with two or more windows (on every Space, minimized and hidden included, as the switcher lists them) get their number on their icon: white digits on a dark capsule at the icon's lower corner away from the screen's edge (lower right for a Dock at the bottom or on the left, lower left on the right), clear of the app's own badge and of the running indicator.
2. **Reading the Dock** (`DockAccessibility`, an actor on a serial queue of its own with the 0.25 s messaging timeout, rule 6): the Dock's application element has one `AXList`, whose children are `AXDockItem`s with `AXSubrole` (`AXApplicationDockItem` for an app), `AXTitle`, `AXURL`, `AXPosition`, `AXSize` and `AXIsApplicationRunning`, each read in one `AXUIElementCopyMultipleAttributeValues`; the list's `AXOrientation` and frame give the edge. An observer on the list gets `AXSelectedChildrenChanged` (the icon under the pointer, read from `AXSelectedChildren`) and `AXCreated` and `AXUIElementDestroyed` (an icon added or removed); macOS 27.0.1's Dock supports no moved, resized or layout notification (`docs/os-quirks.md`). A Dock that restarts is found again when `NSWorkspace.runningApplications` changes. The callbacks only map the notification; every request runs in the actor.
3. **Which windows an icon stands for:** its URL's bundle ID names its app, and it stands for the store's windows of that bundle ID. An app run more than once gets an icon per process, matched to the processes in the order they started (`DockWindowMap`).
4. **Counts are drawn, not set:** the Dock's `AXStatusLabel` cannot be set, and LaunchServices changes another app's information only with a private entitlement, so a transparent window just above the Dock's level that the mouse goes through holds the capsules (`DockBadgeOverlay`). It is on every Space but not on full-screen ones, where the Dock hides (no `.fullScreenAuxiliary`), stays put in Mission Control, is no accessibility element (VoiceOver reads the Dock), and is left out of Oriel's captures like all its windows. Because the Dock reports no moves, it is read again after a one-shot delay, with the counts hidden meanwhile: 0.7 s after an icon added or removed has set the others moving (a read at once tells, so a notification that moved nothing changes nothing), after the Dock's preferences file changes (a kqueue watch on `~/Library/Preferences`) and after the screens change; and 0.4 s after the pointer leaves the Dock, for icons dragged elsewhere. A Dock that hides itself shows its counts only while the pointer is in it; with magnification they step aside while it is (`DockPreferences`).
5. **The preview** (`DockPreviewPanel`, a non-activating `FloatingPanel` at `.popUpMenu`, rule 4): next to the icon (above a bottom Dock, beside a side one) inside the screen's visible frame; tiles in a row for a bottom Dock and a column for a side one, wrapping, then smaller down to 120 points, then the most recent that fit (`DockPreviewLayout`). When it shows and goes is a pure machine (`DockHoverMachine`): 250 ms to show, at once between icons, gone 350 ms after the pointer has left both the icon and the panel, so it can cross from one to the other; a click outside, another app coming forward or the switcher opening dismisses it, and it stays away until the pointer rests on another icon. Only while it shows, global monitors of clicks and pointer moves cover a Dock that does not say the pointer left. Thumbnails come from the switcher's `ThumbnailService`, cached first and then fresh, with Screen Recording only; without it the tiles show the app's icon.
6. **Settings** (`switcher.dockPreviews`, `switcher.dockWindowCounts`, both on) are in Settings → Window Switcher → Dock. Either one keeps the module's store and observers running while `switcher.enabled` is off, without its event tap or the Cmd-Tab takeover; Show Window Switcher and `debug open-switcher` need the switcher itself.
7. **Rules:** no private API; no timer, only one-shot delays and, while the preview shows, event monitors (rule 3); Accessibility only off the main thread and never to Oriel (rule 6).

### 7.2 Screenshot capture

1. **Trigger:** Carbon hotkey (default ⌃⇧4-style, configurable), status menu, CLI or URL.
2. **Freeze-frame overlay (default):** capture every display at once with `SCScreenshotManager` (per-display `SCContentFilter(display:excludingWindows:)`, excluding our own windows) and show one borderless `NSWindow` per `NSScreen` at `.screenSaver` level displaying the frozen image. Transient UI (menus, hovers) stays in the shot, the magnifier is exact, selection has zero latency. A "live" toggle covers video-like content: with Settings → Capture → Freeze the screen while selecting off, the overlay windows are see-through and hit-testable, there is no loupe, and the pick is captured once the overlay has gone, from freshly fetched shareable content so every window of Oriel's is excluded.
3. **Modes:** area (drag), window (hover highlights the window under the cursor using cached `SCShareableContent.windows` frames; click captures the window image itself with optional shadow), full screen (click a display), previous area, timer (3/5/10 s: a countdown, then the area overlay, so a menu opened during the countdown is frozen into the shot), all displays.
4. **Precision:** 8× magnifier loupe sampled from the frozen image with pixel grid and hex colour; crosshair with W×H readout; arrows nudge 1 px (Shift: 10 px), Option+arrows resize, Space+drag moves; snapping to window edges.
5. **Coordinates:** Cocoa global coordinates have a bottom-left origin on the primary screen; CG/SCK use top-left. All conversion lives in `ScreenGeometry` and is unit-tested with synthetic layouts (negative origins, mixed 1×/2× scales). Crop in pixel space using each display's `backingScaleFactor`; write the scale into image metadata (DPI 144 for 2×).
6. **Quick Access Overlay:** after capture, a small non-activating panel in a screen corner offers Copy, Save, Annotate, Translate, Pin, Upload, Copy Text (OCR) and drag-out; auto-dismisses after N seconds (pauses on hover); stacks for multiple captures.
7. **HDR:** SDR PNG by default; HEIC HDR as an option via the macOS 26 screenshot configuration (confirm the exact type name in the SDK audit).
8. **Clipboard:** every interactive capture, in every mode, is also copied to the clipboard (Settings → Capture → Copy every capture to the clipboard, on by default), whatever the after-capture action, so it is in Clipboard History (§7.9) even when Quick Access is closed with Esc. Quick Access keeps its Copy button, for copying a capture again after something else. Headless captures (`oriel capture --rect`) keep their explicit `--to`.
9. **Hide desktop icons and widgets** (Settings → Capture, `capture.hidesDesktopIcons`, off by default) leaves Finder's desktop icons and the desktop widgets out of area, screen, all-displays and previous-area captures, and of the frozen screen they are selected on, through the ScreenCaptureKit filter; Finder is never restarted and its defaults are never written. `SCShareableContent` is fetched with `excludingDesktopWindows: false`, so it lists the desktop's windows (window mode never offers them: its targets are layers 0 up to the Dock), and `DesktopClutter` picks the windows of Finder (`com.apple.finder`) and Notification Center (`com.apple.notificationcenterui`) from `kCGDesktopIconWindowLevel` up to `kCGBackstopMenuLevel`, where 27.0.1 puts the icons and each widget; the wallpaper, owned by the Window Server and WindowManager below the desktop level, stays (`docs/os-quirks.md`). Selections for recording, translation and Instant Capture (`selectRegion`, `selectWindow`), headless captures (`captureRect`, `captureScreen`) and scrolling capture keep the icons, because what they capture afterwards does.
10. **Capture Text** (⌃⇧O, `oriel://capture/text`, command `captureText`, offered only with on-device OCR): the frozen overlay in area mode, which reads as soon as the mouse goes up, or a click on a window, which reads all of it. `RecognizeTextRequest` (`OCRMode.fast`: accurate, language correction, automatic language) reads the lines, `TextLayout` puts them in order, and the text is copied through `SharedUI.Pasteboard`, so Clipboard History keeps it; a toast shows its start and line count, or "No text found". **Reading order:** the lines are cut apart where no line crosses, first between columns of prose (at least two lines of 15 characters or more on each side), else between rows at the widest gap; what is left reads as rows, left to right, or right to left where Arabic or Hebrew letters dominate, with a tab between cells farther apart than one and a half line heights, so tables and forms read row by row and newspaper columns one after the other. A gap between rows half again the usual one (the lower quartile, at least 0.6 line heights) is a blank line. **Hyphens:** a line ending in a hyphen after a letter or digit is joined with the next; the hyphen goes when the joined word is in `NSSpellChecker`'s dictionary for the text's language ("searchable"), else it stays ("well-known", "10-20"); a soft hyphen always goes, a dash keeps its line break. ⇧ while selecting, or Settings → Capture → Open captured text for editing (`capture.textOpensPanel`), opens the text in a small AppKit panel to correct first (⌘Return copies). "Reading text…" appears over the area once reading takes longer than 400 ms, because Vision's first request after launch can take seconds (`docs/os-quirks.md`). Quick Access's Copy Text uses the same layout. **CLI:** `oriel capture text [--rect x,y,w,h] [--json]` reads the area given (Screen Recording must be granted), or one the user selects, prints the text and copies nothing; no text is exit status 1; `--json` adds every line with its text, place in global points, confidence and language.
11. **Step Capture** (Start Step Capture, Finish Step Capture while one runs; command `stepCapture`, `oriel://capture/steps`, no default shortcut): a floating, non-activating glass palette at the top of the screen counts the steps and has Add Step, Mark clicks, Cancel and Finish. While a session runs, every interactive capture in any mode becomes the next step instead of opening Quick Access or running the after-capture action; it is still copied to the clipboard and kept in history. Capture Text, headless captures and the selections of recording, translation and Instant Capture are not steps. Closing the palette keeps the session going (Finish Step Capture is in the status menu); Cancel asks before discarding steps. **Mark clicks** (`capture.steps.marksClicks`, on) remembers the last click in another app with an `NSEvent` global mouse-down monitor, which needs no permission, learns only the position and exists only during a session that marks clicks; the next step draws it as a red ring when it falls inside a capture shown one to one, so window captures with a shadow get none. Each image is written as a PNG under `Oriel Step Capture/<session>/` in the temporary directory, off the main thread, and deleted with the window. The sequence window (AppKit) has numbered thumbnails, editable titles and notes, drag to reorder, Delete, Retake (the step's own mode), Add Step and Annotate, all undoable; `CaptureActionHandling.annotate` gives nothing back, so the edited image returns by a drop or ⌘V onto the step. **Exports**, off the main thread, one image at a time from disk: one tall PNG with numbered headers (640–1,600 points wide, at most 30,000 pixels tall and 80 megapixels), a PDF with a page per step, its heading and note as text and a bookmark each (PDFKit adds the outline to a new document, `docs/os-quirks.md`), Markdown with an images folder, and one self-contained HTML file with the images embedded. Closing the window asks when the steps changed since the last export.
12. **History search:** every capture's text is read once, at utility priority, after each capture and, for older captures, when the history window opens (`.document` OCR, automatic language); images longer than 4,096 pixels on a side, such as scrolling captures, are read in 4,096-pixel tiles with 128 pixels of overlap (`TextTiles`), because Vision scales large images down and loses their text. Every word of a query must appear, ignoring case and accents, in the text, the app, the window title or the kind; each entry's fields are folded once and kept until the entry changes, so a keystroke folds nothing. While searching, each capture shows about 90 characters of its text around the first word found, every searched word in semibold (`HistorySnippet`), else its window title, and the status says how many captures are still being read.
13. **Pins** (§10.4): opacity 10–100 % from a slider in the pin's context menu and its submenu of the status menu's Pinned, ⌥ and the scroll wheel, or the number keys while the pin is in front (1 is 10 %, 0 is 100 %); scrolling or pinching zooms around the pointer, 10–800 %, ⌘+, ⌘− and ⌘0 step through fixed levels, and from 200 % pixels are drawn nearest-neighbour. Lock Position, Border and Shadow, the arrows (⇧ for ten points), ⌘C, ⌘S and ⌘W work while the pin is the key window, which a click makes it without activating Oriel. **Click-through** has four ways back: the corner button; the pin's submenu in Pinned (Click-Through is a checkmark); Stop Click-Through on All Pins, there while any pin lets clicks through; and ⌥⌘ held with the pointer over the pin, which holds it open with an accent outline until the keys go up. Holding open needs an `NSEvent` global mouse-moved monitor (no permission) and, with Accessibility, a `flagsChanged` one, so the pin opens without the pointer moving; both exist only while a pin is click-through. `PinState` is the pure value behind it.

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
- **Finished-recording panel:** plays the movie and offers Edit… (⌘E, the video editor, §7.15), Trim (passthrough, and the click sidecar with it), an Export pull-down (GIF, or a constant-frame-rate copy for video editors), Copy Text (the frame shown, §7.15 item 9), Show in Finder and Copy.
- **Clicks for Auto Zoom:** the click rings' mouse-down monitors (`NSEvent` global and local, no permission) moved into `ClickMonitor`, which feeds both the rings and the recording's `ClickLog`. It runs while Highlight clicks or Remember clicks for Auto Zoom (`recording.remembersClicks`, on) is on, so recordings without rings have the monitors too; no new kind of monitoring was added, and a click costs one appended value. A click is kept as its position normalized to the recorded area (top-left origin), its segment and its time since that segment's output was added; clicks on the control bar and while paused are dropped. On save, the segment files' durations place each click on the joined movie's timeline, and the clicks are written next to the movie as `<movie name>.oriel-clicks.json`: compact JSON with `format` ("oriel-clicks"), `version` (1; a reader takes every version up to its own and refuses newer ones), the movie's `width`, `height` and `duration`, and `clicks` (`time` in seconds, `x` and `y` from 0 to 1, `button` left, right or other; invalid clicks are dropped, at most 20,000 kept).
- **Camera background** (Settings → Recording, with the camera bubble): **Portrait effect** shows whether macOS's own effect is on for Oriel (`AVCaptureDevice.isPortraitEffectEnabled`, read again when a window becomes key) and **Video Effects…** opens the system's controls (`AVCaptureDevice.showSystemUserInterface(.videoEffects)`), which cost Oriel nothing. **Blur camera background** (`recording.blursCameraBackground`, off; Blurred or a solid color, `recording.cameraBackgroundStyle` and `recording.cameraBackgroundColor`) is offered only on Apple silicon outside Rosetta (`CameraBackground.gate`, a `FeatureGate`, rule 5). An `AVCaptureVideoDataOutput` (BGRA, the camera's own size, late frames dropped) joins the bubble's session; on a private queue `VNGeneratePersonSegmentationRequest` (`.balanced`) runs at most 15 times a second, reusing the mask in between, the frame is fitted to the bubble first and mirrored, and the background is blurred (σ = height / 36) or replaced, so the work follows the bubble's size, not the camera's. The newest picture reaches the main thread through a one-slot mailbox and covers the live preview. The effect steps aside while macOS's Portrait or background replacement is active, and `SegmentationGovernor` turns it off for the rest of the recording when segmentation averages more than 45 ms, the Mac runs hot (serious or critical) or Low Power Mode is on (§9); its output then leaves the session. The camera is not asked to scale frames (`docs/os-quirks.md`).

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
    var background: BackgroundStyle?   // fill, shadow, inset, aspect, alignment, window frame, corner radius
    var items: [AnnotationItem]        // z-ordered
    var tone: Double?                  // Simplify's tone-down of the image (0…1)
}
enum AnnotationItem: Codable, Sendable, Identifiable {
    case arrow(Arrow), line(Line), rect(Box), ellipse(Box), freehand(FreehandPath),
         highlighter(FreehandPath), text(TextBox), counter(Counter),
         blur(Region), pixelate(Region), spotlight(Region),
         image(ImageLayer), patch(ImageLayer), bar(Bar)   // Smart Move's objects and fills, Simplify's bars
}
```

- **Undo/redo:** `NSUndoManager` with inverse document snapshots per gesture (documents are small value types), coalesced during drags.
- **Rendering:** one `render(document, into: CGContext, scale:)` used by both the view and export. Blur and pixelate are computed from `base` via Core Image and cached per region.
- **Export:** PNG/JPEG/HEIC via `CGImageDestination`; PDF via `CGContext(consumer:mediaBox:)`; clipboard (`NSPasteboard`, PNG + TIFF); drag-out (`NSDraggingSource` with a promised file); Quick Look (`QLPreviewPanel` on ⌘Y, from a temporary PNG removed when the panel lets go of the window); `.oriel` editable bundle (JSON + original PNG).
- **Tools at launch:** arrow, line, rectangle, ellipse, freehand, highlighter, text, numbered steps, blur, pixelate, spotlight, crop, background/padding, colour and width. Later: magnifier callout, stickers.

Added in 0.1.0 (§17):

1. **Instant Capture** (⌃⇧2, `oriel://capture/instant`, command `captureInstant`, declared by the app because it joins Capture and the editor), Lightshot's instant mode: after `selectRegion` and `captureRect`, `EditorLauncher.openInstant(_:at:)` shows the capture at 1:1 exactly where it was taken, so drawing on it looks like drawing on the screen. `InstantPlacement` flips the selection's global CoreGraphics points to Cocoa with `ScreenGeometry`, picks the display that holds most of it and snaps the frame to that display's pixel grid. `InstantPanel` is borderless, non-activating and at `.statusBar` level, so it covers the menu bar too, and it takes the keyboard while the app the user was in stays in front. A compact AppKit toolbar on the floating-chrome glass sits below the selection, above it when there is no room below, inside it when the selection fills the screen, always on screen: select, pen, arrow, line, rectangle, ellipse, highlighter, text, step, blur, pixelate, colour and width, Undo, Redo, Upload (when a destination is set), Save, Open in Editor, Copy and Close. Tool letters, Delete, the arrows, ⌘Z and ⇧⌘Z work as in the editor; Return or ⌘C copies the flattened image through `SharedUI.Pasteboard` (labelled "Screenshot" for Clipboard History) and closes; ⌘S opens the editor's export panel; ⌘E moves the same `EditorSession`, undo history included, to an editor window; Esc ends a drag or a label first, then closes without keeping anything. It runs the editor's own session, canvas and renderer, and never gets the default background, so it matches the screen it covers.
2. **Backgrounds for social-ready shots:** `BackgroundStyle` has fills (none, solid, linear and radial gradients, and a picture: the desktop picture, read only from /System/Library, /Library or ~/Pictures outside a Photos library, where no privacy prompt can appear, or an image chosen in an open panel; decoded off the main thread at most 4,096 pixels across and optionally blurred), a shadow with radius, opacity and offset (`ShadowStyle`; nil keeps version 1's automatic shadow), an inset in the image's own edge colour (`EdgeColor`), a light or dark window frame with the three lights, the canvas's aspect (`CanvasAspect`: auto, a ratio from 16:9 to 9:16, the sizes X, LinkedIn and Instagram ask for, or a custom pixel size, which every export, copy, drag and upload then has exactly, at 72 DPI) and nine alignments for the card. Eleven presets (None, Ocean, Sunset, Mint, Lavender, Peach, Sky, Aurora, Midnight, Graphite, Paper) change the fill and keep the rest. The popover's tiles are live previews of the screenshot on each background (`BackgroundPreviews`, cached), and it keeps the user's own presets (`editor.savedBackgrounds`; a chosen picture is copied to `~/Library/Application Support/Oriel/Editor/Backgrounds/`, a desktop picture is read again when applied).
3. **Numbered steps:** a step (`Counter`) has a shape (circle, rounded square), a label style (1 2 3, A B C, a b c, I II III), an optional pointer (a wedge to a tip that is a handle when selected) and a sequence: Restart at 1, or any start number, begins a new series, and deleting a step renumbers only its own series. The options restyle the selection as one undo step; the arrows move a step with its pointer.
4. **Smart Redact** (⇧⌘R in an editor window): `SmartAnalyzer`, an actor, reads lines through the app's `TextRecognizing` (`.fast`; the protocol gives no word boxes), and `RedactionDetector` finds keys and tokens (AWS, GitHub, Slack, Stripe, Google, JWTs, PEM private keys, password values, and long random strings judged by length, character set, entropy and how often the character class changes, with UUIDs, paths and short hex excluded), card numbers that pass Luhn, IBANs that pass mod 97, IPv4 and IPv6 addresses, email addresses, and, through `NSDataDetector`, phone numbers and links. A find's box inside its line is the union of a proportional and a monospaced width estimate, with slack along the line and padding, so it is covered in any font. The review lists the categories with counts and switches (links off by default) and adds the editor's own blur or pixelate regions, strong enough for the text's height, as one undo step; logs carry counts only.
5. **Simplify** turns every recognized line into a bar in its ink colour (`TextInkEstimator`) on the background estimated around it, and can tone the rest of the image down (`EditorDocument.tone`). **Smart Move** lifts blocks of text, foreground objects (`VNGenerateForegroundInstanceMaskRequest`) and salient regions (`VNGenerateObjectnessBasedSaliencyImageRequest`) into image layers that can be dragged, resized or deleted, and fills each hole from the pixels around it (`HoleFiller`: exact on flat panels, linear across gradients); objects that overlap one kept before, or show only background, are left out. Both panels say they work best on flat backgrounds. Public Vision only; both requests predate macOS 26, so there is no gate.
6. **Document format 2:** the step styles, the background's new fields, the tone and three new item kinds (`image` for a lifted object, `patch` for a fill, which is part of the image layer and cannot be selected, `bar`), whose pixels are PNGs in the bundle's `images/` folder. Every new field decodes with a default, so version 1 documents open and look as before; build 26 of 0.1.0 refuses version 2 with "saved by a newer version of Oriel". The editor window is at least 780 pt wide, so its tool strip never clips; its new popovers (background, step options, smart reviews) extend its SwiftUI chrome, while Instant Capture is all AppKit.

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
    public var glossary: TranslationGlossary // the active glossary project's terms for the pair (§7.7.10)
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

#### 7.7.8 Translate Under Cursor

A mode, toggled by the command `translateUnderCursor` ("Translate Under Cursor", "Stop Translating Under Cursor" while on; ⌃⇧U, `oriel://translate/cursor`, the status menu's translation section). While it is on, resting the pointer on text shows its translation in a tooltip below the text.

1. **Noticing rest without polling (rule 3):** `CursorEventMonitor` installs one `NSEvent` global monitor (mouse moved, scroll wheel, mouse down, left-mouse dragged, and key down only with Accessibility) and a local key-down monitor for Oriel's own windows. `CursorRestMachine`, a pure state machine fed with instants, keeps the time of the last movement and asks for one wake-up at a time, 400 ms after it, re-armed when it wakes early: while the pointer moves that is at most one wake-up every 400 ms, and at rest nothing runs.
2. **Reading:** at rest, 600 × 120 pt centred on the pointer (moved, not shrunk, to stay on its display) is captured through `TranslationCoordinator.screenCapture`, which `FeatureHub` sets to Capture's `captureRect`, so Oriel's own windows are left out, and read with `.fast` OCR. `CursorTextPicker` takes the line under the point and, by default, its paragraph (same height within 40 %, gaps under ¾ of a line, same column), joined as running text (hyphenation undone, no spaces between CJK lines). Text that touches an edge of the capture that is not the screen's is read once more from a larger area, up to 1,600 × 640 pt. A read is reused for 3 s while the pointer stays inside it and nothing scrolled.
3. **Translating once:** the text goes to the provider Settings would pick for the target, with the active glossary, as one segment. Results are cached (64, least recently used first) by text, provider, target, glossary and source setting; a text already on its way is never sent again, and text already in the target language shows nothing. Requests happen only at rest, never for movement or jitter (under 3 pt from where the screen was last read).
4. **Tooltip:** `CursorTooltipPanel`, a `FloatingPanel` at `.popUpMenu` level on all Spaces and over full-screen apps, ignoring the mouse, never key or main: glass, the caption ("Japanese → English · DeepL"), the translation wrapped at 380 pt (14 lines at most), "Translating…" while waiting, a warning line on failure, right to left for right-to-left targets; below the text, above it when there is no room, inside the visible frame. VoiceOver announces each translation. It stays while the pointer moves within its text (plus 10 pt); leaving hides it and starts a new wait; a scroll hides it and reads the same spot again; a click, a drag or a key hides it and nothing is read until the pointer moves, so typing never brings it back.
5. **Badge and stopping:** while on, `CursorStatusItem` adds a menu-bar icon of its own (`character.cursor.ibeam`) whose menu says what it translates into, with which provider, and has Stop Translating Under Cursor. Esc (in other apps only with Accessibility), the shortcut, the command or the badge turn it off; a toast says how when it starts.
6. **Permissions:** Screen & System Audio Recording, checked with `CGPreflightScreenCaptureAccess()` (rule 8); without it an alert explains and offers System Settings and the mode does not start, and a capture that fails once the permission is gone stops it. Accessibility is optional (Esc in other apps), checked with `AXIsProcessTrusted()` and never requested.
7. **Settings:** `translation.cursor.unit`, `paragraph` (default) or `line` (Settings → Translation → Translate Under Cursor); the shortcut is `shortcuts.translateUnderCursor`.

Each rest costs one full-display ScreenCaptureKit screenshot cropped to the area (what `captureRect` does), about 20–60 ms of GPU work, and nothing while the pointer moves. The badge can be hidden behind the notch on a crowded menu bar.

#### 7.7.9 File translation

The command `translateFile` ("Translate File…", no shortcut, `oriel://translate/file`) opens an open panel; a file dropped on the side panel or on the file window opens there too (the first of several, with a toast).

1. **Routing** (`DocumentKind`, by extension, then by type conformance): images (PNG, JPEG, HEIC, TIFF, GIF, BMP, WebP) through OCR; PDF; plain text; Markdown; RTF, RTFD, Word (.docx, .doc) and OpenDocument text through `NSAttributedString`; HTML through Oriel's own reader; SRT and WebVTT subtitles. Anything else is refused with a reason.
2. **Reading** (`DocumentReader`, a detached task, so no file I/O on the main thread): text in UTF-8, UTF-16 with a byte-order mark, an HTML-declared charset, else Windows Latin 1; plain text split at blank lines, hard-wrapped prose joined; Markdown blocks with their markers kept aside and code, tables, HTML, rules and front matter verbatim; HTML without WebKit, whose importer needs the main thread and loads remote resources (headings, paragraphs, list items, quotes, cells; `<pre>` verbatim; scripts, styles and the head skipped); rich text by paragraph, list markers turned into Markdown; subtitles cue by cue, forgiving of byte-order marks, CRLF, missing numbers and either decimal mark; images upright, at most 8,000 pixels, `.document` OCR; PDFs page by page with PDFKit's `selectionsByLine()` when a page has text, else rendered at 3,000 pixels and read with OCR. A PDF with a password says so; files with over 50 MB of text are refused.
3. **Chunking** (`DocumentChunker`, `ChunkLimits` per provider kind): segments are packed in order, never merged, within a count and a character limit (Apple 40 and 6,000; DeepL 50 and 25,000; Google 100 and 20,000; local LLMs 30 and 3,000; Anthropic 60 and twice `max_tokens`; Apple Intelligence 20 and 1,500). Only a paragraph longer than the per-segment limit is split, at sentences (`NLTokenizer`), then spaces, then anywhere for scripts without spaces, and joined again afterwards.
4. **The job:** each part (a PDF page) is translated as soon as it is read, so results appear page by page. Before the first chunk: the source language (Settings, else detected from the first 40 segments; the same language as the target sends nothing), the provider's state and cap, Apple's language pack (the download window, then Resume), and, for a provider that may bill, a confirmation for files over 100,000 characters (estimated from the first page of a PDF). Usage is recorded per chunk. Stop (⌘.) and failures keep what was translated; Resume translates only what is missing, reading the file again if it was not read to the end (segment ids depend only on the file). Changing the provider, the target or the glossary translates everything again; closing the window stops the job.
5. **Window** (`FileTranslationWindowController`, AppKit per rule 4): the file's icon, name and summary ("PDF · 12 pages · 87 paragraphs · English → Japanese · read with OCR") with pop-ups for provider, target and glossary; a two-column table (original, translation) with page headings, cue timing, headings, list bullets and code shown as such; for images, the translated picture above the table, drawn like Translate Area's overlay, with a Translation | Original switch; a footer with progress, Stop, Resume or Translate Again, Copy All (Copy Text and Copy Image for images) and Export. ⌘C copies the selected rows' translations. The whole window takes file drops.
6. **Export** (`DocumentExporter`, off the main thread): text; Markdown with the file's structure ("## Page N" for PDFs); Markdown with each original quoted above its translation; SRT and WebVTT from any subtitle file, timing to the millisecond (WebVTT keeps its header, identifiers, cue settings and voices; SRT keeps `{\an8}` positions); PNG for images. A segment without a translation keeps its original; the suggested name is `<file>.<target>.<ext>`.

Rich text, HTML and Markdown inline formatting are not rebuilt (exports are text or Markdown), Markdown tables stay untranslated, inline subtitle styling is dropped, and file translations are not added to the translation history.

#### 7.7.10 Glossary projects

1. **Model:** a `GlossaryProject` (a name, language pairs and optionally a Google Cloud glossary) holds `GlossaryLanguagePair`s (source and target BCP 47 codes, either empty for any language) of `GlossaryTerm`s (source, target, note, case-sensitive). A translation gets the active project's terms for its pair (`TranslationGlossary`, which replaced the request's dictionary): the most specific pair first, each source term once; a pair with a fixed source never applies to text whose language is unknown.
2. **Storage:** `~/Library/Application Support/Oriel/Glossaries/glossaries.json` (`GlossaryStore` actor; atomic, pretty-printed, sorted keys; not secret), saved 0.6 s after the last edit, at once for structural changes and when the editor closes. An unreadable file is moved aside as `glossaries.unreadable-<date>.json`. The single glossary of earlier builds (`translation.glossary`) becomes a project "Glossary" for any languages, active, and the key goes.
3. **Matching** (`GlossaryMatcher`): whole words in scripts with spaces, anywhere in CJK, Thai, Lao, Khmer and Myanmar; case-insensitive unless the term says otherwise; the longest term wins where two overlap.
4. **Per provider:**
   - *DeepL* uses its glossary API (v2): the supported pairs (`GET /v2/glossary-language-pairs`, cached a day), `POST /v2/glossaries` with cleaned TSV entries, then `glossary_id` with `source_lang` (detected when unknown) on `/v2/translate`. `DeepLGlossaryBook` keeps one glossary per provider, project and pair in `translation.deepl.glossaries`, with a SHA-256 of its entries; changed terms make a new glossary and delete the old (v2 glossaries cannot be edited), one DeepL no longer knows is made again once, and deleting a project deletes its glossaries. Unsupported pairs, or a glossary DeepL refuses, fall back to placeholders.
   - *Google:* a project can name a Cloud Translation glossary (a full name, or an ID in `us-central1` of the key's project). With a service account key, translations then use v3 with it; when Google refuses it for the pair and an API key is there, Basic with placeholders instead; without a service account, Basic with placeholders. The provider's own glossary field still works when the project names none. Creating a Google glossary needs a file in Cloud Storage, which Oriel does not write, so the editor exports "CSV for Google Cloud" and explains the steps.
   - *Language models* (OpenAI-compatible, Anthropic, Apple Intelligence) get in their instructions the terms that occur in that request's segments (every term in AI Vision), at most 80, with notes and "[case-sensitive]".
   - *Apple Translation and Google Basic* (`GlossaryProtection`): each occurrence becomes a token `[[N]]`, and afterwards each token becomes the term's translation, capitalized like the original for case-insensitive terms. Tokens may come back full-width, spaced or with one bracket pair lost; a token lost, doubled or mangled sends that segment again without tokens and uses the plain translation. The engine translates around a token it cannot read, so articles, gender and endings may not agree with the term.
5. **UI:** Settings → Translation → Glossary: Use glossary (None or a project) and Edit Glossaries…, a sheet with the projects, the selected project's name, its language pairs ("Any language" allowed), an editable table of terms, Import (CSV or TSV, header names in any order or none, optional `source_language` and `target_language` columns) and Export (CSV, TSV, CSV for Google Cloud), and the Google Cloud glossary field. The side panel and the file window have a glossary pop-up; changing it translates again. The active project is `translation.glossary.activeProject`.

### 7.8 Upload

Upload (Quick Access, the editor, Instant Capture) sends a capture or a file to a destination and copies its link. Settings → Upload holds any number of destinations of six kinds; one is the default (Upload to), and each has its own file-name template and link format. The protocol this section once called `UploadDestination` is `DestinationUploader`; `UploadDestination` is now the stored destination.

1. **Destinations:** `UploadDestinationList` (`upload.destinations`) holds them in Settings order with the default's ID; a removed default falls back to the first. A destination is a name, a target (its kind and that kind's configuration), a name template, a link format and whether image files lose their metadata (GPS, EXIF and TIFF, keeping the orientation; captures are fresh PNGs anyway). Decoding is tolerant: a missing field takes its default, and a destination of an unknown kind, from a newer Oriel, is left out instead of losing the list. `UploadCoordinator.upload(_:scale:name:to:)` and `upload(fileAt:to:)` use the default when no destination is given.
2. **S3-compatible** (AWS, MinIO, R2, B2): one SigV4-signed `PUT` streamed from the file, its SHA-256 read a megabyte at a time; the key is the folder in the bucket, then the rendered template; the link is the public base URL, else the object's address. Test Connection uploads and deletes a tiny object; errors come from the XML `<Code>`.
3. **WebDAV:** `MKCOL` for each folder not known to exist (405 means it does), then `PUT` with `If-None-Match: *`, so a name in use answers 412 and the file is renamed "Shot 2.png" rather than replacing another. The server chooses Basic or Digest; URLSession answers its challenge once per request with the user name and the Keychain password, in an ephemeral session of its own. Test Connection is `PROPFIND` depth 0.
4. **SFTP** through `/usr/bin/sftp -b -` in batch mode with `BatchMode=yes`, `StrictHostKeyChecking=yes` and timeouts: the system's OpenSSH reads `~/.ssh/config`, uses the user's key or agent and checks `~/.ssh/known_hosts`; there is never a password, and Settings says how to set up a key. Every path in the batch is quoted, and a path with a character sftp would still read inside quotes is refused; sftp is handed a symbolic link with a name Oriel chose, never the user's own file name; host and user name cannot become ssh options. Exit status and standard error become errors that say what to do (unknown or changed host key, key refused, unreadable key file, unknown host, refused, timed out, no SFTP subsystem, missing folder, permission denied, disk full). sftp prints no progress in batch mode, so the bar is indeterminate. The link is the public URL template, else `sftp://user@host:port/path`.
5. **Shared folder:** a copy a megabyte at a time into a hidden partial file renamed when complete, so a web server never serves half a file; a name in use gets a number. The folder is kept as a bookmark, resolved without UI and without mounting, so it follows a rename and an unmounted share says to connect in Finder. The link is the public URL template, else the file's `smb://` address on a network volume (without the user name), else its `file://` URL.
6. **Dropbox** (OAuth 2, PKCE S256, a public client the user creates: an app with `files.content.write`, `sharing.write` and `sharing.read`, whose app key is pasted in). Sign-in opens Dropbox's authorize page with `token_access_type=offline` and the redirect `db-<app key>://2/token` in `ASWebAuthenticationSession`, which catches the custom scheme itself: no URL scheme in Info.plist and no local server (§16). A sign-in that lacks a permission says which to tick. Uploads use `files/upload` up to 150 MiB, else an upload session in 8 MiB chunks; arguments travel in `Dropbox-API-Arg` as header-safe JSON. The shared link (made, or found when it exists) is copied as Dropbox's page, the file itself (`raw=1`) or a download (`dl=1`).
7. **Google Drive** (OAuth 2, PKCE S256, an OAuth client of type iOS that the user creates with the bundle ID `com.codertapsu.oriel`): the redirect is the reversed client ID, `com.googleusercontent.apps.<id>:/oauth2redirect`, caught by `ASWebAuthenticationSession`, with `access_type=offline`. Scope `drive.file` (files Oriel creates, no verification) or, chosen in Settings, `drive`, which a folder the user made needs. Without a folder, Oriel makes or finds an "Oriel" folder at the top of My Drive once. Uploads are multipart up to 5 MB, else resumable in 8 MiB chunks, asking Google where an interrupted upload stands, three times at most; shared drives work. Optionally the file is shared with anyone with the link; a domain that forbids it does not fail the upload. The link is `webViewLink` or `webContentLink`.
8. **Sign-in tokens** (`OAuthTokens`) are JSON in the Keychain. `UploadService` refreshes a token two minutes before it expires, or when a request meets a 401, once at a time per destination; `invalid_grant` forgets the tokens, so Settings shows the sign-in is gone. Sign Out and deleting a destination revoke them, best effort.
9. **Names and links:** the template is the path below the destination's folder: `{name}` (window title, file name or "Oriel"), `{date}`, `{time}`, `{random}` (128 random bits, §8.4) and `/` for folders. It is split at `/` before tokens are filled, so a title never makes a folder, and each part loses characters file systems refuse and is cut to 200 characters. The default is `{random}/{name}` where the link is the file's address (S3, WebDAV, SFTP, shared folder; 0.1's S3 keys) and `{name} {date} at {time}` for Dropbox and Drive, whose links cannot be guessed anyway; Settings warns when a template can repeat or be guessed. A URL template takes `{path}`. The link is copied as the link, as Markdown or as HTML (`upload.copiesLink` turns copying off for every destination).
10. **Progress, Cancel, errors:** uploads run at utility priority in `UploadService` (an actor), the user waiting for the link (§9). A glass panel at the bottom of the screen appears after 300 ms, so a quick upload shows only the toast, with the bytes sent (at most ten updates a second) and Cancel, which stops URLSession, terminates sftp or removes a partial copy. Success copies the link; a failure turns the panel into a selectable message for 12 s that says what to do. Two uploads at once stack their panels.
11. **Secrets** (S3 secret keys, WebDAV passwords, sign-in tokens) are Keychain items of the service `upload.s3`, which Uninstall removes, with the account `<destination ID>.<secretKey|password|oauth>`; Settings saves a typed secret only on Save or Return and never shows it again. Logs carry kinds and statuses; host names and paths are `privacy: .private`; credentials, tokens and signed URLs are never logged.
12. **0.1's S3 setting** (`upload.configuration`, Keychain account `secretKey`) is an inbox: at launch, and whenever a bootstrap import writes it, it becomes or updates the destination with the fixed ID `UploadDestinationList.legacyID` (the default when none was chosen), its secret moves to that destination's account, and both old entries are cleared; `BootstrapImporter` is unchanged.

S3 uploads are single `PUT`s (5 GB at most). sftp's `put`, and WebDAV servers that ignore `If-None-Match`, replace a file of the same name. While a Google consent screen is in Testing, Google ends the sign-in after 7 days. `UploadCoordinator.destinationMenu(_:)` builds a menu of destinations for an Upload button, but no button uses it yet, and nothing calls `upload(fileAt:)` (§17).

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

### 7.10 Disk Space Analyzer

A `UtilityModule` (package `DiskAnalyzer`, on by default, General → Tools): where the space on each drive goes, and safe ways to get it back. **Disk Space Analyzer** (command `openDiskAnalyzer`, no default shortcut, `oriel://disk`, the status menu's tools) opens or focuses its window; **Scan Folder…** (`scanFolderWithDiskAnalyzer`, `oriel://disk/scan`, not in the menu) opens it with a folder picker. Nothing runs while the window is closed: volume watching, scans, the FSEvents stream, hashing and Spotlight lookups start with the window and stop with it, and closing it lets the scan go.

1. **Volumes:** `FileManager.mountedVolumeURLs(includingResourceValuesForKeys:options: [.skipHiddenVolumes])` with the total, available, important-usage and opportunistic-usage capacities and the keys that tell a volume's kind: the startup disk first, then internal, external and network volumes. *Used* is total − available, as Finder counts it. *Purgeable* is min(important, total) − available: what macOS frees by itself when something needs the space (local Time Machine snapshots, iCloud files that are safely in iCloud, caches marked purgeable). A volume is *nearly full* below 10 % or 10 GB available, purgeable included. Volumes are read off the main thread when the window opens, on `NSWorkspace` mount, unmount and rename notifications, and after a scan or an operation; never on a timer. **Eject** (`NSWorkspace.unmountAndEjectDevice(at:)`, after a confirmation) is offered for external, removable and network volumes, never for an internal one.
2. **The startup disk** is a sealed system volume and a data volume joined by firmlinks. A scan of "Macintosh HD" reads `/System/Volumes/Data`, so nothing is counted twice, and shows paths through the firmlinks (`/Users/…`). With **Count macOS's own files one by one** (on by default) it also reads macOS's own volumes into a folder named **macOS** (`MacOSVolumes`, a tree *anchor* whose paths start at `/`): the sealed system volume at `/`, its firmlinks, automount triggers, the folders that only steer path resolution (`/.nofollow`, `/.resolve`, `/.vol`) and foreign mounts (the data volume, `/dev`) left out, entering the helper volumes VM (the swap files) and Update; **Preboot** is one block of the space it uses, because its cryptexes are grafted from disk images that are APFS clones of each other and its files would count the same space two or three times (`docs/os-quirks.md`). On the dev Mac that folder is within 1 % of what `df` shows for the four volumes, and takes about 3.5 s more. Off, it is **macOS (system)**, one block for the system volume and the helper volumes of its APFS container. Every volume's own use comes from `getattrlist`'s `ATTR_VOL_SPACEUSED`, as `df` does: on APFS `statfs` gives every volume the whole container's use. A volume scan also adds **Other space**, what no scanned file accounts for (local snapshots, the container's other volumes, unreadable folders, file-system overhead) when that is at least 100 MB and 0.5 % of the used space. The scan then adds up to what Finder calls used. A scan of another whole volume adds Other space only.
3. **Scanning:** `getattrlistbulk(2)` returns many entries' attributes per call: type, allocated and content size, the dates, flags (`UF_HIDDEN`, `SF_DATALESS`, `SF_FIRMLINK`), inode and link count, the real device, mount status and APFS's extended flags. A file system that refuses the extended attributes is asked again without them, and one that refuses bulk reads is listed with `FileManager`, with an autorelease pool per folder (`docs/os-quirks.md`). Sizes are allocated sizes; a file with several hard links is counted once per device and inode; symbolic links are never followed (folders are opened with `O_NOFOLLOW`); volumes mounted inside the folder are entered only when Settings allows it, and then only local, browsable ones the user mounted, never network shares, automount triggers or the disk images macOS mounts for itself. Up to eight threads of the scan's own take folders from a shared depth-first stack, since reading a directory blocks and must stay off Swift's cooperative pool. Their I/O policy (`setiopolicy_np`) turns off materializing dataless files, so a scan never downloads a cloud-only file, and access-time updates, so a scan does not make files look used. Progress is reported from inside the work once 120 ms have passed since the last report, without a timer; **Stop** keeps what was read, marked partial.
4. **Memory:** the tree is one array of 56-byte nodes without references (parent, first child and next sibling as indices; sizes, counts, dates as 32-bit seconds, category and flags) with interned names. Files at or above the small-file threshold (1 MB by default; 100 KB to 10 MB in Settings) are kept one by one; the smaller ones of a folder become one aggregate with their exact count, size and newest date. A node's children have higher indices, so totals are summed in one backward pass. Measured on the dev Mac (release build, warm cache): 200,000 files in 10,000 folders scan in 0.10–0.13 s with `getattrlistbulk` (0.5 s with the fallback) into 21,021 nodes, about 1.3 MB, while the footprint grows by 7 MB.
5. **Keeping the scan current:** while the window is open (Settings, on by default) an FSEvents stream on the scanned folder (`WatchRoot`, `IgnoreSelf`, 1.5 s latency) collects the folders that changed; two seconds after the last event, a one-shot sleep that the next event restarts, those folders are listed again in place, all the way down where the system asks for it, and a moved or deleted root is read again. Oriel's own operations are not in the stream (`IgnoreSelf`), so the window applies them itself. Edits of the tree run one after another; removed nodes are compacted away once there are over 50,000 and they are a third of the tree.
6. **Permissions** (§8.1): none required, none probed (rule 8). A folder that cannot be opened is kept with why (`UnreadableReason`): **only its owner may open it** (`EACCES`: macOS, one of its accounts or another user; `.Spotlight-V100`, `.fseventsd`, much of `/private/var/db`, other users' homes), which Full Disk Access does not change, or **macOS protects it** (`EPERM`): privacy protection, which Full Disk Access lifts (Mail, Messages, Safari, other apps' data), or System Integrity Protection, which keeps it from every app (`/private/var/db/biome`, `com.apple.TCC`). The two cannot be told apart without probing, so the note names both. Each reason has its own banner and inspector section: the second offers **Full Disk Access…** (`x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles`), the first **Read as Administrator…** (item 17). The first read of Desktop, Documents, Downloads, a removable or network volume, iCloud Drive or a File Provider folder makes macOS ask, with Oriel's usage strings (Appendix D), and before the first scan that covers the home folder the window says so once. A folder the user keeps private is then one macOS protects.
7. **Cloud storage:** iCloud Drive and the File Provider domains in `~/Library/CloudStorage` (Google Drive, Dropbox, OneDrive and Box by folder name, any other by its name) are found by name, and nothing inside them is read until the user scans one. A dataless file counts 0 bytes on disk, is flagged cloud-only and keeps its content size. No public API reports a provider's quota, so the overview says so and links to the provider's storage page (iCloud's in System Settings). **Remove Download** (`FileManager.evictUbiquitousItem(at:)`) frees the local copy of downloaded iCloud Drive items, which stay in iCloud; File Provider domains offer no such call to other apps. There are no network connections.
8. **Window (AppKit, rule 4):** an `NSSplitViewController` with a sidebar (Volumes, each with a bar of used, purgeable and free space; Cloud; Recent Scans), the main area and an inspector, under a toolbar (Scan, Stop, Choose Folder…, Reveal in Finder, Quick Look, Copy to…, Move to…, Move to Trash, search). Before a scan a location shows its overview (capacity, purgeable space and what it is, local snapshots, the Trash, Storage Settings, the provider's page); during one, its progress; after it, breadcrumbs, notes (unreadable folders, a partial scan, what grew since the last scan) and eight views, ⌘1–⌘8: **Sunburst**, **Treemap**, **List** (an outline with size bars), **Biggest Files** (the files kept one by one, filtered by kind, size and the search; the 1,000 largest matches, with how many matched), **Old Files** (not used for 30 days to 5 years, one year by default; *used* is the latest of the modification date, the access date and Spotlight's "last opened", read with `MDItemCreate` for the first 600 listed, never a query; a file without a date is never old), **Duplicates**, **File Types** (bytes and files per UTType category, a package counted as one) and **Space Hogs**. The views share the selection and the folder shown. Context menus, the keyboard (⌘↑ goes up, Space or ⌘Y Quick Look, ⌘⌫ Move to Trash, ⌥⌘⌫ Delete Immediately, ⌘R scan again, ⌘. stop, ⌘O choose a folder, ⌘F search, ⌥⌘I the inspector, ⌘C copies the items as Finder does) and VoiceOver, with one element per chart segment, cover them. The inspector shows the selection's details, including what deleting it frees (`ATTR_CMNEXT_PRIVATESIZE`) and notes on clones, hard links, purgeable and cloud-only files, firmlinks and mount points; with nothing selected, the scan's summary.
9. **Charts** (Core Graphics, laid out off the main thread): the sunburst has the folder shown in the middle and five rings around it, each item's angle proportional to its size, slivers under about a third of a degree merged per folder; the treemap is squarified (Bruls, Huizing and van Wijk 2000), nested folders with a name strip opened while tiles of at least 48 × 40 pt fit, up to eight levels, items under about 10 × 10 pt merged. Each item of the folder shown has its own system color, lighter with each ring or level, so the biggest consumers read as large areas of one color; macOS and Other space are grays. Hover shows a tip with name, size and share; in the sunburst a click opens a folder and a click on the center goes up, in the treemap a click selects and a double-click opens; the change cross-fades in 0.22 s, not at all with Reduce Motion.
10. **Duplicates:** among the files kept one by one below the folder shown, files of the same size, then of the same SHA-256 of their first and last 64 KB, then of all their content (CryptoKit, a megabyte at a time with `F_NOCACHE`), each stage reading only what the one before left, on four threads with the scanning I/O policy; cloud-only files and further links of a hard-linked file are never read. Groups come largest waste first, each APFS clone counted once (`ATTR_CMNEXT_CLONEID`). **Mark All but Newest** or **Mark All but Oldest** keeps one copy by modification date; **Move Marked to Trash…** goes through the usual confirmation.
11. **File operations** run in an actor (`FileOperator`), on a thread of their own, item by item. A copy is `copyfile(3)` with `COPYFILE_CLONE`, so a copy on the same APFS volume is a clone that takes no time or space, with byte progress; a name that is taken gets " 2", " 3"… as in Finder. A move is `renamex_np(RENAME_EXCL)` on one volume, and to another volume a copy, a check that the copy has every file and byte, then removal of the original (a failed copy is removed and the original kept). **Move to Trash** (`FileManager.trashItem`, so Put Back works) has **Undo** (⌘Z); **Delete Immediately** asks twice and removes a symbolic link itself, never its target. Every removal and move is confirmed first with the number of items and their size (the Trash's confirmation can be turned off; copies are not confirmed, since they change nothing where the items are); one item's failure does not stop the others; Stop ends before the next item or in the middle of a copy; afterwards the tree is updated and a toast says what happened.
12. **Safety rules** (pure and tested, and run again in the actor on what is there, with `lstat`): removals and moves refuse the top of a volume, macOS itself (`/System`, `/bin`, `/sbin`, `/usr` except `/usr/local`, `/private` and `/var` except `/tmp`, `/etc`, `/dev`, the data volume outside the firmlinks…), `/Applications`, `/Library`, `/Users`, `/Volumes` and `/opt` and their direct children (apps in `/Applications` excepted, but not the apps of macOS), everything else directly at the top of the startup volume (`/.file`, `/pkg`), the home folder and its top-level folders, `~/Library`'s own folders, the tops of iCloud Drive and of every File Provider domain, anything inside an app or another package, and Oriel. Anything in the macOS folder, and anything read as an administrator, is refused whatever its path. Paths are standardized (`..`, `~`, the data volume's spelling) before the rules run; the user's temporary folder's contents are theirs.
13. **Reclaiming space,** each confirmed: local Time Machine snapshots, listed with `tmutil listlocalsnapshots` (unprivileged), where **Remove Snapshots…** runs `tmutil thinlocalsnapshots <mount> <bytes> 4` as the user and, if macOS wants an administrator, again through the system's password dialog (`osascript … with administrator privileges`, every argument quoted), so Oriel never sees a password and needs no helper tool; Remove Download (item 7); the Trash's size and **Open Trash** (emptying it stays the user's choice, in Finder); **Storage Settings…** (`com.apple.settings.Storage`). **Space Hogs**, measured when the user asks, since some make macOS ask for access: app caches, logs, Xcode's DerivedData, Archives and device support, simulators (**Delete Unavailable…**, `xcrun simctl delete unavailable`, offered only where simulators exist) and their caches, iPhone and iPad backups (reveal only), iOS updates, Mail downloads, installers in Downloads, the outermost `node_modules` and `.build` folders of the open scan, the npm and Gradle caches, and the Trash; each says what it is and whether it comes back by itself, and offers **Clean Up** (item 19) on its folder (the installers', on Downloads), or on any of the folders found by name from a menu; after Clean Up or a removal, the hogs whose folders it touched are measured again.
14. **History, export and exclusions:** after each complete scan (on by default) a snapshot of the totals and of every folder worth following (at least 10 MB and a two-thousandth of the total, eight levels, the 4,000 largest) is saved in `~/Library/Application Support/Oriel/DiskAnalyzer/Scans/`: names and sizes, never contents, the newest five per folder and thirty in all, removed by Forget Remembered Scans. The next scan of the same folder says what grew, pointing at the folder that explains a change rather than every folder above it (**Show Changes…**). **Export as CSV…** writes RFC 4180, sizes in bytes and ISO 8601 dates, with an apostrophe before names a spreadsheet would run as formulas. Exclusions are paths or folder names (`node_modules`), listed and marked but not entered; hidden files are included by default.
15. **CLI** (read-only): `oriel disk volumes [--json]` lists the volumes with total, used, free and purgeable bytes; `oriel disk scan <path> [--top <n>] [--json]` scans a folder or volume (an absolute or `~` path; `--top` 1–1,000, 10 by default) with the window's settings and reports the total, the largest items and files, the categories, the unreadable folders and what is only in the cloud. The parser gives `disk scan` ten minutes (`--timeout` overrides). The scan runs in the app, so a first scan of a protected folder from Terminal makes macOS ask there.
16. **Settings** (`disk.*`): `smallFileThreshold` (1,000,000 bytes), `includesHiddenFiles` (on), `countsMacOSFiles` (on, item 2), `crossesVolumes` (off), `exclusions`, `usesSpotlightDates` (on), `confirmsTrash` (on), `watchesChanges` (on), `remembersScans` (on), `oldFileDays` (365), `view` (`sunburst`), `readsAsAdministrator` (on, item 17), `explainsFolders` (on, item 19), and this Mac's own `explainedFolderAccess` and `helperBuild`.
17. **Read as Administrator** (`ElevatedRead`): for the folders only their owner may open, listed as root by Oriel's own executable with the scan's reader, counting and I/O rules (no cloud downloads, no access times), by one of two routes.
    - **Oriel's helper** (`PrivilegedReader`), once the user has allowed it. It is a launchd daemon in the bundle, `Contents/Library/LaunchDaemons/<bundle ID>.disk-reader.plist`, written by a build phase from `App/LaunchDaemons/disk-reader.plist` so the Debug build's has its own name, whose `BundleProgram` is Oriel's executable; `main()` runs it when launchd starts that executable as root with the job's label in `XPC_SERVICE_NAME` (`PrivilegedReaderDaemon`). It answers one XPC request on its Mach service, list these folders, with the JSON listings, and exits when its last connection closes; launchd starts it again for the next request. Both ends require the other's code signature, Oriel's identifier and team with an Apple-issued certificate (`NSXPCConnection.setCodeSigningRequirement`, `CodeIdentity`), so no other app can use it. **Install Helper…**, offered by the window and in Settings, registers it with `SMAppService.daemon(plistName:)` and opens Login Items, where the user switches it on under Allow in the Background with an administrator's password, once; Oriel notices when it next comes to the front. Allowed, it reads those folders after every complete scan (`readsAsAdministrator`) and for the CLI's `disk scan`, without asking. An update replaces the executable, and `SMAppService`'s header says a daemon may then not launch until registered again, so Oriel registers it again the first time it is used after an update (`helperBuild`) and once more when it does not answer; a read the user asked for that still fails falls back to the password. **Remove Helper** and Uninstall Oriel unregister it.
    - **macOS's password prompt**, for one scan, and in builds without the helper: Oriel runs its own executable again as root through `osascript … with administrator privileges` (every argument quoted, the folders and the scan's options on the command line), and `main()` sees `--disk-read-folders` first and does nothing else: it prints the listings as one JSON document and exits.

    Either way, as root it opens no file, writes nothing and follows no link, and the password goes to macOS. The listings go into the scan where the folders were, marked `readAsAdministrator`: refreshes leave them as read, since the user's rights cannot read them again; Duplicates leaves them out, since they cannot be opened to compare; removals and moves are refused. A folder still closed to root (System Integrity Protection) comes back as one macOS protects. At most 2,000 folders per run; a whole Mac has a few hundred. The totals, the summary and the volume's blocks are summed again.
18. **The lists:** Biggest Files lists macOS's own files with everyone else's, as the search does. Old Files leaves them out, since the sealed system's unused files are nothing to remove, unless the list is of a folder inside the macOS folder; Duplicates never compares them.

19. **Clean Up** (a folder's context menu, the inspector and Space Hogs' rows): checks one folder, of the open scan or not (a space hog's folder outside it gets a scan of its own, by the window's settings, which closing the sheet stops), and says how safe it is to clean up (**Safe to clean up**, **Clean up with care**, **Look before you remove it**, **Keep it**), what it is and what happens afterwards, what Oriel found for and against, and the ways to get its space back, the recommended one first. What it removes goes to the Trash through the usual confirmation, with Undo; nothing is deleted at once.
    - **Facts** (`CleanupInspector`, off the main thread): from the scan, the folder's size, its contents with when each was last used, the kinds of files, the Git repositories and the outermost caches inside; from the folder, its names (with the smaller files the scan summed up), a `CACHEDIR.TAG` with the specification's signature, `isExcludedFromBackup`, and whether the user may move it and what it holds; the processes with files open in it or working in it (`FolderUsers`: libproc's `PROC_PIDLISTFDS`, `PROC_PIDFDVNODEPATHINFO` and `PROC_PIDVNODEPATHINFO`, which macOS answers for the user's own processes; Oriel left out); the apps its path names, by bundle ID (an extension's by its app's) or by name, and the apps running (a bundle ID no installed app has, other than `com.apple.`'s, is a removed app's); what the safety rules (item 12) refuse, for the folder and for what it holds.
    - **Judgment** (`CleanupAdvisor`, pure and table-tested): the first rule of the catalog that matches speaks for the folder (`CleanupCatalog`: Xcode's DerivedData, Archives, device support and previews; the simulators, their caches and runtimes, and CoreSimulator's root-owned shared caches; device backups and updates; Mail, Messages, Photos and cloud storage, kept; Downloads, the user's own, with its installers offered; the Trash; macOS's temporary folders and swap; Gradle's caches, distributions and home; Maven, npm, pnpm, Cargo, Go, CocoaPods, Hugging Face and other tools' caches, Ollama, Android's emulators and SDK, Docker, Homebrew, JetBrains IDEs; projects' build folders, known by the file next to them; any app's cache and logs last). Otherwise the folder's place, name and contents decide: temporary browser profiles that automated tests left behind, a Chromium browser's data (kept), a cache (tagged, or by its name), temporary files, logs, an app's data (kept, unless its app is gone), the user's own folders (Old Files), an app, a folder its app keeps out of Time Machine, and otherwise an unknown folder to look at first. Then what can only make it more cautious: the safety rules, cloud storage, repositories (unless a known tool made them), mostly personal kinds of files, processes using it (what is in use stays out of every method), its apps running (with Quit), and who may remove it (then only the tool's command or Finder). Leftovers inside any folder are offered as well: older versions' folders (`VersionedNames`: of the folders named with a dotted version, every version but the newest of each name, such as Gradle 9.1.0–9.6.1 beside 9.8.1; files named with a version are the user's downloads), leftover temporary profiles, and caches.
    - **Methods** (`CleanupMethod`): the folder, what it holds (the folder stays for the apps that use it) or chosen items to the Trash, checked again for processes using them just before; the tool's own command, which Oriel runs only with the fixed arguments of `xcrun simctl runtime dyld_shared_cache remove --all` and `xcrun simctl delete unavailable`, after a confirmation, and otherwise copies for Terminal (`go clean -modcache`, `docker system prune`, `brew cleanup --prune=all`…); the app that manages it; Old Files of the folder; Finder.
    - **Apple Intelligence** (`CleanupExplainer`, FoundationModels, gated on `SystemLanguageModel.default.availability`, rule 5, and on `explainsFolders`): for a folder the catalog does not know, the on-device model reads the path from `~`, the largest names and sizes inside, the kinds of files and the signals, never what a file holds, and answers in a `@Generable` structure what the folder probably is, which app made it, and whether removing it could lose what cannot be rebuilt. It can be wrong, so it only explains, or turns the advice careful when it thinks something would be lost; it never makes the advice less careful. On the dev Mac it answered in about 3 s.
    - On the dev Mac gathering the facts took 0.06–0.18 s for folders of 7–18 GB, the check of every process's open files included.

No private API: `getattrlistbulk`, `getattrlist`, `setiopolicy_np`, `copyfile`, `renamex_np`, `statfs`, FSEvents, Spotlight's `MDItem`, libproc's process information and FoundationModels are public. The main thread reads no folders and does no hashing or layout. A scan counts APFS clones at full size (there is no cheap public way to see shared blocks for every file), so a volume's files can add up to more than its used space; the inspector shows what deleting one item really frees. Copying or moving a cloud-only file to another volume fails with "It is only in the cloud" rather than downloading it, and changes Oriel itself makes in a scanned folder outside the window appear at the next scan.

### 7.11 Activity Monitor

A `UtilityModule` (package `ActivityMonitor`, on by default, General → Tools): the running apps, background services and processes and what each uses, like macOS's Activity Monitor, in an AppKit window. **Activity Monitor** (command `openActivityMonitor`, no default shortcut, `oriel://activity`, the status menu's tools) opens it.

1. **Sampling only while the window is open** (rule 3, as amended): opening the window starts `SamplingSession` (`Session/SamplingSession.swift`, the one file of the package the `no_polling` rule exempts), a loop that samples at utility priority, hands the snapshot to the window and sleeps for the interval (1, 2 or 5 s, 2 by default, with a tolerance of a tenth). It wakes early when the window needs new sources (a tab or view change, the window coming back on screen), when memory pressure changes (`DispatchSource.makeMemoryPressureSource`) and when the thermal state changes. Closing the window cancels the loop, terminates any `ps` or nettop it started and drops the history. While the window is minimized or covered, samples skip `ps` and nettop and the views are not redrawn; the history keeps going. With the window closed it costs nothing. `oriel top` takes two samples of its own a second apart (one `Task.sleep`, not a loop).
2. **Every process:** one `sysctl(KERN_PROC_ALL)` gives each process's pid, parent, owner, start time, short name, state and `P_TRANSLATED` flag (about 0.2 ms for 900 processes). A process is its pid *and* its start time (`ProcessIdentity`): pids are reused, so rates, history, selection and every signal use the pair. `proc_pidpath` gives every user's executable path except the kernel's. Names are the running app's localized name, else the executable's file name, else the kernel's 16-character name.
3. **The user's own processes:** `proc_pid_rusage(RUSAGE_INFO_V6)` gives the CPU time, the physical footprint (Activity Monitor's "Memory"), the resident set ("Real Memory"), the disk bytes, the energy and the wake-ups, and `PROC_PIDTASKINFO` the threads. CPU times are timebase ticks converted with `hw.tbfrequency`, which is right in both slices, while `mach_timebase_info` reports 1/1 under Rosetta; on Apple silicon the wake-ups are interrupt wake-ups, because the package idle ones stay 0 (`docs/os-quirks.md`).
4. **Other users' processes:** macOS refuses rusage, task info, file descriptors and arguments for them (EPERM), so Kind comes from `P_TRANSLATED` for everyone and `/bin/ps`, which is setuid root, gives CPU time, resident set and state: `ps -o pid=,time=,rss=,state= -p <their pids>` in the C locale, about half the cost of `ps -ax`. It runs only while another user's CPU or memory is on screen (CPU, Memory and Energy tabs; not with My Processes, Apps or Show only my processes): every other user's process every ~6 s, and in between only those that used the processor when last measured, and new ones, so a busy daemon such as WindowServer still updates every sample. A process not read in a sample keeps its last numbers for at most 15 s, and its next rate spans the time since its own last reading. kernel_task's numbers are not available to the user's account.
5. **Rates:** each process is compared with its own last reading, if that is at most 15 s old and came from the same reader. CPU % is Δ CPU time / Δ uptime (`CLOCK_UPTIME_RAW`, which stops during sleep, as CPU time does), capped at all cores; a counter that went down is a reset and gives no rate that time. Power is Δ energy / Δ time, in watts: Apple's Energy Impact score is not public.
6. **Network per process:** one `nettop -L 1 -n -x -t external -J bytes_in,bytes_out` run per sample, on the Network tab only (about 4–6 ms of CPU); a long-lived nettop spins a core between samples and buffers its output when piped (`docs/os-quirks.md`). Rates are summed per connection, so a connection that closed between two runs costs only its last interval; the parser takes the columns from nettop's header and the pid after the last dot, since names may hold dots, commas and spaces. `ps` and nettop run as short-lived children through `posix_spawn` with signals unblocked, a timeout and cancellation.
7. **The Mac:** per-core load with core types (`host_processor_info`, the device tree's `cluster-type`), the memory breakdown (App Memory, Wired, Compressed, Cached Files, Swap Used) and pressure (`host_statistics64`, `kern.memorystatus_vm_pressure_level`, `kern.memorystatus_level`), disks (each `IOBlockStorageDriver`'s statistics, disk images left out), physical network interfaces (`NET_RT_IFLIST2`, 64-bit counters), GPU utilization (`IOAccelerator`, hidden when absent), the battery and, on the Energy tab, the processes keeping the Mac awake.
8. **Heavy use:** CPU, disk or network over its limit for the whole sustain time (80 % of a core, 50 MB/s, 5 MB/s, 10 s by default), or memory over its limit now (2 GB): the process gets a flame beside its name and an orange value, and the strip above the list names the three processes using the most of the tab's measure.
9. **Window (AppKit, rule 4):** a unified toolbar with Quit Process, Info and a More menu (Send Signal, Sample Process…, Reveal in Finder, Copy, Settings), the tabs CPU, Memory, Energy, Disk and Network (⌘1–⌘5), the View menu (All Processes, My Processes, System Processes, Other User Processes, Apps, Active Processes, All Processes, Hierarchically, and Apps with Their Helpers, which groups each app's helpers by bundle and ancestry, since macOS's own responsible-process tracking is private API) and search (⌘F). One `NSOutlineView` per tab keeps its columns, their order and visibility, its sort and its scroll position; the selection survives updates and follows the user across tabs. Cells draw their own text, which made a reload about seven times cheaper than text-field cells (`docs/os-quirks.md`). Below the list, the Mac's summary for the tab with Core Graphics history graphs; beside it, the details (⌘I, or Return): live CPU and memory graphs, the parent, user, start time, Kind, status, path, code signature (`SecStaticCode`: Apple, Mac App Store, Developer ID, ad hoc, unsigned; team, sandbox, hardened runtime) and, for the user's own processes, the command line (`KERN_PROCARGS2`; the environment is never read) and the open files and sockets.
10. **Quit, Force Quit and Send Signal:** `SignalPolicy` refuses pid ≤ 0 (`kill` would signal a group or every process), kernel_task, launchd, WindowServer and loginwindow (losing either logs the user out), Oriel itself and zombies, with the reason. Every action is confirmed in a sheet that names the processes and says what will happen (⌥⌘Q always opens it, with Quit, Force Quit and Cancel). The user's apps quit through `NSRunningApplication.terminate()` or `forceTerminate()`; other own processes get `kill(2)` (TERM, INT, HUP, KILL, STOP, CONT, USR1, USR2). Just before anything is sent, the pid's start time is checked against the one the user confirmed, so a pid reused while the dialog was open is left alone. Another user's process needs an administrator: after a second confirmation, one `osascript -e 'do shell script "/bin/kill …" with administrator privileges'` for all of them, built from integers only. **Sample Process…** runs `/usr/bin/sample <pid> 3` into a temporary folder and opens the report.
11. **CLI and Settings:** `oriel top [--sort cpu|memory|disk|network] [--limit <n>] [--json]` prints the busiest processes from two samples a second apart, with `ps` for other users and nettop only for `--sort network`; 20 rows by default (1–1,000); bad options exit 64. Settings → Activity Monitor (`activity.*`): `interval` (2 s), `defaultTab`, `historyMinutes` (1, 5, 15 or 30, 5 by default; at most 300 samples a process), `onlyMyProcesses` (hides system and other users' processes, and `ps` never runs), and the heavy-use limits; the window remembers its view, its details pane and each tab's sort.

No permission (§8.1), no private API, no Accessibility. Other users' disk use, energy, threads, arguments and open files are not available without root, their CPU is to 10 ms, and an idle one refreshes every ~6 s. Per-process traffic misses connections that open and close between two samples; group totals add up resident sets, which counts shared memory twice. Cost: §9.

### 7.12 Color Picker

A `UtilityModule` (package `ColorPicker`, on by default). **Pick Color** (command `pickColor`, ⌃⇧C, `oriel://color/pick`) starts the loupe; **Color Picker** (`openColorPicker`, no default shortcut, `oriel://color`) opens the panel, or closes it.

1. **Picking:** `NSColorSampler`, the system loupe. macOS draws it and hands over only the clicked color, so it needs no Screen Recording. The color arrives in its display's color space and is converted once, with ColorSync, to extended sRGB, whose components may leave 0…1, so a Display P3 red keeps its exact value (1.093, −0.227, −0.150) instead of being clipped. One pick at a time. Every pick goes into Recent; with Copy the color as soon as it is picked (`colorPicker.copiesOnPick`, on) it is also copied in the default format, and the panel opens on the Color tab.
2. **Color math** (pure): sRGB and Display P3 share the transfer curve and D65, so P3 ↔ sRGB is a matrix on linear light through XYZ (CSS Color 4's matrices, checked against ColorSync to 0.002); OKLab and OKLCH use Ottosson's matrices; HSL, HSB and naive CMYK use the clipped color. A color is inside sRGB when every component is within half an 8-bit step of 0…1.
3. **Formats,** in this order: HEX, HEX + Alpha, `rgb()`, `rgba()`, HSL, HSB, OKLCH, SwiftUI `Color(red:green:blue:)`, `NSColor(srgbRed:…)`, `UIColor(red:…)`, then `rgb()` in percent, CMYK and Display P3 (`color(display-p3 …)`, only while it differs from sRGB). The first ten copy with 1–9 and 0 on the Color tab; ⌘C copies the default (`colorPicker.defaultFormat`, HEX). HEX, RGB, HSL, HSB and CMYK can only say sRGB and write the clipped color; OKLCH and Display P3 write the exact one; for a color outside sRGB the code formats switch to their Display P3 initializers, titled "· P3", and a badge says *Outside sRGB*. HEX and RGB leave alpha to HEX + Alpha and RGBA. Numbers use a full stop; HEX is uppercase unless Settings says otherwise. Every format reads back (`ColorParser`, which also reads typed and pasted colors); numbers no color can have are refused and every component stays finite, so no format can trap.
4. **Panel** (AppKit, rule 4): a non-activating `FloatingPanel` at `.floating` level, moved by its background, its frame autosaved. It becomes key when it opens, so the number keys and ⌘C work at once, and otherwise only for a field (`becomesKeyOnlyIfNeeded`), so a click on a format or a swatch never takes the keyboard from the app in front. Unlike Clipboard History it stays open when another app is clicked, because a color tool is kept beside the work; Esc, ⌘W, its × or the command close it, and ⌘, opens its Settings. Three tabs (⌘1–⌘3): **Color**, a large swatch whose HEX is a field for typing or pasting any color, Add to Palette and Check Contrast, the format rows (a click copies) and Recent; **Palettes**, renamed, reordered and dragged between, taking drops from Recent, other apps (`NSColor`) and text, with export; **Contrast**, text and background colors (typed, dropped, or picked with an eyedropper each; ⇅ swaps), the **WCAG 2.2** ratio with Pass or Fail for AA and AAA for normal text, large text and UI components (SC 1.4.3, 1.4.6, 1.4.11), cut rather than rounded to two decimals and compared exactly, so 4.499:1 fails AA, translucent text blended over a background that counts as opaque, a live sample, and **APCA Lc** labelled "WCAG 3 draft (APCA)". Deleting a palette or a color can be undone (⌘Z, or the footer) until the next change or until the panel closes.
5. **Storage:** `~/Library/Application Support/Oriel/ColorPicker/<bundle ID>/library.json`, so the Debug build keeps its own library. The `ColorStore` actor writes it atomically after each change, off the main thread; saves are chained and carry a revision, so an older save never lands after a newer one. Version 1 holds the history, the palettes and the contrast pair, each color in extended sRGB. Reading is forgiving: a file without a version is version 0, colors may be hex strings, missing ids, names and keys are filled in, and an unreadable entry is skipped, not the file. A file that is not JSON is set aside (`library-unreadable-<time>.json`) and the library starts afresh; a file from a newer Oriel is left untouched and nothing is saved over it that session.
6. **Export** (⋯ → Export as…, through `NSSavePanel`, written off the main thread): JSON (each color's name, HEX, sRGB, alpha and Display P3), CSS variables (with an `@supports (color: color(display-p3 1 1 1))` block that gives wide colors their P3 value; names become unique ASCII slugs) and an Apple color list (`NSColorList.write(to:)`, `.clr`).
7. **Settings and rules** (`colorPicker.*`): `defaultFormat` (HEX), `uppercaseHex` (on), `historySize` (20; 10, 20, 50 or 100), `copiesOnPick` (on); the pane also shows the shortcut, the counts and Clear Recent Colors. Nothing runs while the panel is closed, and the only delays are one-shot, so there are no timers. Copies go through `SharedUI.Pasteboard`, so they reach Clipboard History; logs carry no colors. There is no CLI verb: the `oriel://` routes cover scripting.

### 7.13 Screen Ruler

A `UtilityModule` (package `ScreenRuler`, on by default). **Screen Ruler** (command `openScreenRuler`, ⌃⇧M, `oriel://ruler`) lays it over every display; pressing it again closes it.

1. **Overlay:** one borderless, see-through `NSPanel` per screen at `.screenSaver` level, on every Space and over full-screen apps, its root layer tinted at alpha 1/255 so it stays hit-testable, as Capture's live overlay is; it is the ruler's own and does not import Capture. Oriel is activated for cursor updates, and the previous app is reactivated on close. Every ⌘ key is taken while it is open, so ⌘Q cannot quit mid-measurement; another app activating, or the displays changing, closes it.
2. **Geometry:** everything is in global CoreGraphics points, each window mapped to its view through `ScreenGeometry`. Pixels are the display's backing pixels, the screenshot's. Measurements snap to the grid of the unit in use: whole points, or whole pixels (half points on a 2× display).
3. **Dimensions** (the default mode): arms run from the pointer to the nearest edge left, right, up and down, each with its length, and the `W × H` of the box the edges make, which sits exactly on them. An edge is a boundary between neighbouring pixels whose colors differ by more than the tolerance in any channel (`EdgeMap`); comparing neighbours rather than the starting pixel means a gradient's gentle steps are not edges, and noise below the tolerance is ignored. `[` and `]` change the tolerance by 1 % (⇧: 5 %), from 0 to 50 % of a channel's 255, and Settings keeps it. A click pins the box under the pointer; a box drawn around something shrinks to the outermost edges inside it (PixelSnap's fit), off the main thread; the arrows move the point measured from.
4. **Measure Area:** a dragged rectangle on one display reads `W × H` in the chosen unit, the other unit, and its position from the display's top-left corner. ⇧ makes it square; eight handles resize it, a drag inside moves it, the arrows nudge it (⇧ by ten) and ⌥-arrows resize it. When the screen could be read, dragged edges snap to detected edges within 5 points; ⌘ while dragging turns that off. A double-click inside, or Return, copies and closes.
5. **Guides:** a click adds a vertical or horizontal guide (Space flips, H and V choose) on the pointer's grid line; a guide can be dragged, moved with the arrows and removed (⌫, a right-click, ⌘⌫ for all). Along the pointer's row and column the gaps between neighbouring lines are drawn and numbered, and ⌘C copies the gap the pointer is in. Guides last for the session.
6. **The still picture:** taken once, when the ruler opens, of each display at its native pixel size through ScreenCaptureKit (`SCContentFilter(display:excludingApplications:)` with Oriel left out, so the ruler never measures itself; `SCScreenshotConfiguration` in SDR, no cursor), and only when Screen Recording is granted, which it reads through `PermissionChecking` (`CGPreflightScreenCaptureAccess`, which never prompts). Each picture becomes 8-bit sRGB RGBA off the main thread and is kept only while the ruler is open: about 4 bytes a pixel, 59 MB for a 5K display. Until it is read, Dimensions says "Reading the screen…". Without Screen Recording, Measure Area and Guides work on the transparent overlay and Dimensions explains why it cannot find edges; Return there closes the ruler and asks for the permission. Screen Recording is not a required permission of the module. Content that changes after the ruler opened is measured as it was.
7. **Keys:** Tab, ⇧Tab and 1–3 switch mode; U switches points and pixels for the session; ⌘C copies the measurement ("320 × 240 pt") and stays; Return copies and closes, and a toast says what; Esc closes. A glass hint bar at the bottom of the display under the pointer names the mode, what to do and its keys, and moves to the top when the pointer comes near. `RulerKeymap` reads letters and brackets from the characters typed, so they follow the keyboard layout; `RulerSession` is a pure state machine for every mouse and key event, and `RulerSceneBuilder` builds what each display draws as values, which the overlay draws with Core Animation shapes and badges.
8. **Settings and rules** (`screenRuler.*`): `defaultMode` (Dimensions), `unit` (points), `guideColor` (`#FF2D55`, Line color, for guides and measurements), `tolerance` (5 %); the pane shows whether Screen Recording is allowed. Nothing runs while the ruler is closed, and the only delay is the one-shot "Copied" flash. Copies go through `SharedUI.Pasteboard`. There is no CLI verb.

### 7.14 Window Tiling

A `UtilityModule` (package `WindowTiling`, on by default) that moves the focused window of the app in front to a part of its screen, from Rectangle-like shortcuts and from the status menu's **Window Tiling** submenu.

1. **Actions:** 22 `ToolCommand`s (group tools, `showsInMenu` false, ids prefixed `tile`), with their shortcuts in Settings → Shortcuts.

   | Ids | Default | Frame |
   |---|---|---|
   | `tileLeftHalf`, `tileRightHalf`, `tileTopHalf`, `tileBottomHalf` | ⌃⌥←, ⌃⌥→, ⌃⌥↑, ⌃⌥↓ | a half; pressed again on the window it just placed, ⅔, then ⅓, then ½ (a setting) |
   | `tileTopLeft`, `tileTopRight`, `tileBottomLeft`, `tileBottomRight` | ⌃⌥U, ⌃⌥I, ⌃⌥J, ⌃⌥K | a quarter |
   | `tileFirstThird`, `tileCenterThird`, `tileLastThird` | ⌃⌥D, ⌃⌥F, ⌃⌥G | a third; top to bottom on a portrait display |
   | `tileFirstTwoThirds`, `tileLastTwoThirds` | ⌃⌥E, ⌃⌥T | two thirds |
   | `tileMaximize` | ⌃⌥↩ | the visible frame |
   | `tileAlmostMaximize` | none | centered, 90 % of the visible frame (60–95 %, a setting) |
   | `tileMaximizeHeight` | ⌃⌥⇧↑ | full height, same x and width |
   | `tileCenter` | ⌃⌥C | same size, centered |
   | `tileSmaller`, `tileLarger` | ⌃⌥-, ⌃⌥= | 5 % of the screen per step in each direction; edges shared with the screen stay, otherwise the center does; never past the screen or below 25 % of it |
   | `tileNextDisplay`, `tilePreviousDisplay` | ⌃⌥⌘→, ⌃⌥⌘← | the next display left to right, then top to bottom, wrapping; a tiled window takes its layout along, any other keeps its size and its share of the free space, shrunk to fit |
   | `tileRestore` | ⌃⌥⌫ | the frame from before Window Tiling's run of actions on that window |

2. **Geometry** (pure, table-tested): displays come from `NSScreen.frame` and `visibleFrame` (no menu bar, no Dock) on the main actor and are flipped into Accessibility's global coordinates (top-left of the primary display, y down) with `ScreenGeometry`. A layout is a share of the visible frame less the gap; each inner edge gets half a gap, so neighbours are one gap apart and as far from the screen's edges. Edges are rounded to whole points, so two halves meet exactly on odd widths and negative coordinates. Each layout carries anchors (`TilePlacement`): which of its edges a window that cannot take the size keeps (a right half its right edge, a center third its middle).
3. **Moving** (`WindowArranger`): one `AXUIElementCopyMultipleAttributeValues` round trip reads the focused window (`kAXFocusedWindowAttribute`, else `kAXMainWindowAttribute`) with its role, subrole, frame, full-screen and minimized state and whether position and size are settable; then it sets the size, the position, reads the frame back, sets the size again if it did not take (an app that caps a window at its screen allows the new size only once the window is on the new display), reads back, and when the size still differs (minimum or maximum sizes, terminals snapping to whole characters) moves the window to where that size lines up with the anchors on its display's visible frame (`TileFitting`). Full-screen windows and sheets are skipped with a short toast; a window that is not an `AXWindow`, or whose position cannot be set, gets "This window can't be moved or resized".
4. **`AXEnhancedUserInterface`:** assistive apps turn it on, and while it is on Chromium and Electron apps animate every frame change, so a move lands late and short. Rectangle and Amethyst turn it off for the move (studied, not copied); Window Tiling does the same on the app element and turns it back on right after, only when it was on.
5. **Restore** (`TileHistory`, keyed by the window's AX element through `CFEqual` and `CFHash`, without the private `_AXUIElementGetWindow`): each record keeps the restore frame, the last action and cycle step, and both the frame asked for and the frame read back. A window still at either (2 pt tolerance) continues its run, so cycling advances and Restore returns to the frame from before the first action; a window the user moved starts a new run. A restore frame whose title bar would show on no display (an unplugged one) is centered on the window's current display. At most 64 windows are kept, the least recently arranged dropped first; turning the tool off forgets them all. A window exactly at the ½ layout with no record goes straight to ⅔.
6. **Concurrency (rule 6):** `WindowMover` is the tool's own AX actor, on its own `DispatchSerialQueue`, with a 0.25 s messaging timeout on every element; the main actor only reads `NSScreen`, the settings and the frontmost app's pid, and gets back a `TilingOutcome`. When Oriel itself is in front, `OwnWindowTiler` runs the same `WindowArranger` on the main thread through `OwnWindowAccess` (the key window's `NSWindow` frame in Accessibility's coordinates), with a history of its own, since an AX request to itself would run AppKit off the main thread (§7.1.1); `AXWindowAccess` refuses Oriel's pid. Key presses are handled in order, each from where the last left the window. It is separate from the switcher's `AXClient`, which belongs to the switcher's runtime: Window Tiling must work with the switcher off and needs only the focused window.
7. **Permissions:** `requiredPermissions` is Accessibility, checked live with `AXIsProcessTrusted()` at each action. Without it a shortcut shows a non-activating notice near the bottom of the screen for 8 s, "Window Tiling needs Accessibility", naming the pane for the running macOS, with Open System Settings; never a modal alert. An Accessibility error after the check shows the same notice.
8. **Feedback and menu:** a move is announced to VoiceOver by the action's name; a key that does nothing (no window in front, nothing to restore, already as large as the screen, one display) beeps as macOS does; skips, and an app that does not answer within the timeout, get a toast. `menuItems` adds the Window Tiling submenu while the tool is on: the actions in seven groups, with template glyphs drawn from the same geometry and the user's current shortcuts as key equivalents; Next and Previous Display are dimmed with one display. The status menu never activates Oriel, so the app in front stays in front.
9. **Settings and rules** (`tiling.*`): `gap` (0–32 pt in steps of 2, 0), `cyclesSizes` (on), `almostMaximizeFraction` (0.9, from 0.6 to 0.95); out-of-range values are clamped on read. The pane shows Accessibility's state and the shortcuts. Between key presses the tool does nothing: no observers, taps, timers or caches besides the history (rule 3); the notice's dismissal is a one-shot sleep.
10. **Limits:** with Stage Manager on, its strip of recent apps is expected to lie inside `visibleFrame`, so a left half may cover it (not checked); windows of apps that refuse Accessibility, and full-screen windows, cannot be tiled; there is no snapping by dragging, and no CLI verb or `oriel://` route, since opening a URL would bring Oriel to the front and tile the wrong window.

### 7.15 Video editor

Part of `Packages/Recording` (`VideoEditor/`). **Open Video…** (command `openVideoEditor`, no default shortcut, `oriel://video/open`, the status menu's library section) asks for any movie, starting in the recordings folder; the finished-recording panel's **Edit…** (⌘E) opens its movie and closes the panel; a movie dropped on an editor window opens in its place when that window has nothing to lose, otherwise in a window of its own. There is one window per movie.

1. **Opening** reads the movie once (`MovieInfo`: duration, size with rotation, frame rate from the shortest frame, sound, codec), the click sidecar next to it (§7.4) and any QuickTime chapters it already has, which become markers.
2. **Window** (AppKit, rule 4): a unified toolbar (Open, Auto Zoom, Add Zoom, Add Chapter, Copy Text, Export, Inspector) over an `NSSplitViewController` whose second item is an inspector. On the left: the preview (`AVPlayerLayer` on black), the transport bar (go to start, J, play or pause, L, the playhead's time, what the trim keeps, the timeline's zoom) and the timeline, one custom `NSView` with a ruler, the filmstrip with the trim handles dimming what is cut, a zoom lane and a chapter lane; the playhead is a layer of its own, so playback moves it without redrawing the rest. The inspector has Auto Zoom (level, hold), the selected zoom (start, end, level, and a focus picker on a frame of the movie) and the chapters (an editable list, Add, Delete, Copy for YouTube, Save as Text…). Only Settings is SwiftUI.
3. **Playback:** `AVPlayer` through the zoom composition. A periodic time observer (1/60 s) moves the playhead; AVFoundation calls it while the movie plays and when time jumps, never while it is paused (rule 3), and it is removed when the window closes. Playback stays inside the trim. J, K and L shuttle (each further J or L doubles the speed, up to 8×, as far as the movie allows reverse and fast play); ← and → step a frame at the movie's own rate, ⇧← and ⇧→ a second; Home and End go to the in and out points, then the very start and end; scrubbing seeks within 0.1 s while the mouse moves and exactly when it is released. ⌘=, ⌘- and ⌘0 zoom and fit the timeline.
4. **Filmstrip:** `AVAssetImageGenerator.images(for:)` in the background, at twice the strip's height, for the visible tiles without an image; at most 240 images are kept. Times that fail with a tolerance are asked for again with zero tolerance, and a tile without an image of its own shows the nearest earlier one, which a screen recording holds anyway (`docs/os-quirks.md`).
5. **Edits:** `VideoEdit` is a value, the trim, the zoom segments (in order, never overlapping) and the chapter markers, with every rule in pure, tested code. `VideoEditorSession` makes each change one undo step (whole snapshots, 200 levels, a drag or a slider move coalesced into one) and knows whether closing would lose edits; the window then asks *Close without exporting?* (Export…, Close, Cancel). Edits are kept only while the window is open: there is no project file. The movie itself is never changed.
6. **Auto Zoom** (pure, `AutoZoom`): every click of the sidecar is zoomed into. The zoom-in (0.5 s) ends 0.2 s before the click; the view holds for *hold* (0.5–5 s, 1.5 s by default, `recording.autoZoomHold`) after a group's last click and zooms out in 0.5 s. Clicks closer than *hold* + 1.95 s (two transitions, the lead and a gap too short to zoom out and back in) share one segment, which pans from one to the next (at most 0.6 s, arriving 0.1 s before the click) only when the next click is outside the middle 60 % of the zoomed view. Focus points are clamped so the view stays inside the frame; the scale changes geometrically and every move eases with smootherstep (6x⁵ − 15x⁴ + 10x³), so it starts and ends at rest. Auto Zoom replaces all zooms as one undo step; zooms can also be added at the playhead (Z, or a double-click in the zoom lane), moved, resized, removed and given their own level (1.5–3×, 2 by default, `recording.autoZoomLevel`) and focus.
7. **Zoom rendering:** one `AVVideoComposition` built from `AVVideoComposition.Configuration` with a custom `AVVideoCompositing` compositor (`ZoomCompositor`) and one instruction carrying the immutable `ZoomPlan`. Each frame is turned upright, cropped to what the plan shows at its time (always inside the frame, so there are no black borders) and scaled to the render size with Core Image, colour management off, so pixels that are only moved keep their values, and high-quality downsampling, so small text stays legible. While anything is zoomed, frames come at the movie's rate (24–60 fps), so a zoom glides across a still screen where a screen recording has no frames; otherwise they follow the source. The same composition serves the preview (at most 1,920 pixels across), the export and the GIF. The Core Image filter-handler API was not used, because its render size is private, and `AVMutableVideoComposition` is deprecated as of 26.0 (`docs/os-quirks.md`).
8. **Export** (⌘E): a save panel with the choices below it (MPEG-4 or QuickTime; HEVC, offered when the Mac has an HEVC encoder, or H.264; Original, 1080p or 720p, only the sizes that differ; or a GIF with its width and 10, 12 or 15 fps), then a sheet with progress and Cancel. `TrimmedMovie` makes the kept part a composition whose timeline starts at 0; `AVAssetReader` reads its frames through the zoom composition and its sound mixed to 48 kHz stereo; `AVAssetWriter`, with the macOS 26 receiver API (`inputReceiver(for:)`, `start()`; the older `add`, `startWriting` and `append` are deprecated in 27), encodes H.264 High or HEVC at about 0.12 or 0.072 bits per pixel per frame (7.5 Mbit/s for 1080p30 H.264), a key frame at least every 2 s, BT.709, and AAC at 160 kbit/s, with the chapter track; three child tasks feed video, sound and chapters, so the writer interleaves them. Everything goes to a hidden file next to the destination, which replaces it only when complete; a cancelled or failed export removes it and the writer's own scratch file (`docs/os-quirks.md`). The movie being edited cannot be the destination. A GIF goes through `GIFExporter`, which now also takes an asset and a composition, within `GIFFramePlan`'s limits. No callback API is used (S8). The last choices are kept (`recording.editorExportFormat`, `recording.editorExportCodec`, `recording.editorExportSize`); a GIF keeps using `recording.gifMaxWidth` and `recording.gifFrameRate`.
9. **Chapters and Copy Text from Frame:** M adds a marker at the playhead; the list renames and deletes them (a double-click on a marker starts renaming); ↑ and ↓ jump between them. `ChapterList` turns the markers into chapters that cover the export from 0:00 without gaps: the chapter running at the in point becomes the first, a chapter called *Start* is added when none is there, markers less than 1 s apart are merged and one at the very end is dropped. The movie gets a QuickTime chapter track of 3GPP timed text (`tx3g`), one sample per chapter, disabled for playback, tagged with the user's first preferred language and listed by the video track as its chapters (`addTrackAssociation(withTrackOf:type: .chapterList)`), which QuickTime Player and ffmpeg read from `.mp4` and `.mov`. Copy for YouTube and Save as Text… give `00:00 Start` lines, explaining YouTube's rules (at least three chapters, each at least 10 s) when they are not met. **Copy Text from Frame** (⇧⌘C in the editor; Copy Text in the finished-recording panel) reads the exact frame at the playhead (zero tolerance, full size, without the zoom) with the app's `TextRecognizing` in fast mode, copies the lines through `SharedUI.Pasteboard`, so Clipboard History keeps them, and shows them in a small panel where part can be selected and copied; "No text found in this frame" when there is none.

No new permission: mouse monitors need none, and OCR and exports need nothing. The only periodic callback is the player's time observer during playback; thumbnails, exports and OCR are one-shot work, off the main thread. Exports always re-encode; the finished panel's Trim stays a lossless passthrough.

### 7.16 Settings sync (iCloud)

Settings → General → Sync: **Sync settings through iCloud** (`app.syncSettings`, off by default) keeps a user's settings the same on each of their Macs.

1. **What syncs** (`SettingsSyncPolicy`, by name): shortcuts (`shortcuts.*`), the tools that are on (`app.enabledModules`) and the settings under the prefixes `capture.`, `recording.`, `editor.`, `translation.`, `clipboard.`, `switcher.`, `disk.`, `activity.`, `colorPicker.`, `screenRuler.` and `tiling.`. A name containing folder, directory, path, bookmark, location, last used, last opened or last scan stays on each Mac, as do `clipboard.openedPasteboardSettings` and `disk.explainedFolderAccess`, upload destinations (`upload.*`, whose credentials are in that Mac's keychain), the other `app.*` settings such as one-time notices, and the sync bookkeeping (`sync.*`). Secrets never reach `SettingsStore` (rule 7), so they cannot sync.
2. **How:** each Mac publishes one snapshot of its synced settings (`SettingsSnapshot`: each setting's stored JSON and when it last changed on that Mac, a random device ID, `sync.deviceID`, and the computer's name) and reads the others' snapshots. Per setting, the newest change wins (`SettingsMerge`). A setting a Mac never changed counts as changed at `distantPast`, so a Mac that turns sync on adopts what the others have, and the first Mac to turn it on (`sync.seeded`) seeds the others with its settings. Changes that come from another Mac are marked (`userInfo["origin"] == "sync"`), so they are not sent back; a synced change of the tools starts or stops them (§6.3).
3. **Where:** iCloud key-value storage (`NSUbiquitousKeyValueStore`), the store meant for preferences, when the app carries the `com.apple.developer.ubiquity-kvstore-identifier` entitlement, which it checks with `SecTaskCopyValueForEntitlement`. A Developer ID app gets that entitlement only with a provisioning profile that has iCloud, which Oriel's signing does not have yet (§16). Until then, a folder in iCloud Drive: `Oriel/Settings/<device>.json`, one file per Mac, so iCloud never reconciles two versions of one file, written and read through `NSFileCoordinator` (a coordinated read downloads a file still in iCloud), with an `NSFilePresenter` on the folder reporting other Macs' files. With neither, the toggle is dimmed.
4. **Events, not polling (rule 3):** a local change goes out two seconds after the last one, a one-shot delay that each change restarts; other Macs' changes are read when iCloud reports them, when Oriel becomes active and after wake. While sync is off it observes nothing.
5. **UI:** the toggle, the status ("Synced with 1 other Mac at 14:02", "iCloud Drive is off…") and Sync Now.
6. **Limits:** values sync, not data, so histories, pins, palettes, glossaries and caches stay on each Mac. A setting both Macs change while offline goes to the later change. With iCloud Drive, macOS may ask once whether Oriel may use it (`NSFileProviderDomainUsageDescription`, Appendix D). Uninstall (§15 item 8) leaves the Mac's file in iCloud Drive.

### 7.17 App Intents (Shortcuts and Spotlight)

| Intent | What it does |
|---|---|
| **Take a Screenshot** | Area, window or screen (Mode). Returns the PNG, and runs the after-capture action as usual. |
| **Translate Area** | The user selects text on the screen; returns the translation (To: a language code, empty for the default). |
| **Translate Text in an Image** | No window: on-device OCR and the default provider on an image file; returns the translation. |
| **Focus Window** | A `WindowEntity` from the switcher's list on every Space, searchable; needs Accessibility. |
| **Run Oriel Command** | Any app action but Quit, or any command of a feature or of a tool that is on (`CommandEntity`, `CommandQuery`). Tools added later appear without new intents. |

- Four App Shortcuts (`OrielShortcuts`) offer Take a Screenshot, Translate Area, Focus Window and Run Oriel Command in Spotlight and the Shortcuts app ("Take a screenshot with Oriel").
- The intents run inside Oriel's process; `IntentContext` holds the running `AppController`, set at launch.
- They live in the app target, at its default main-actor isolation: `@Parameter` properties cannot be declared in a `nonisolated` type, while entities, queries and enums are `nonisolated`; a window's identifier is an `Int`, because `UInt32` is not an `EntityIdentifierConvertible` (`docs/os-quirks.md`).
- The metadata is extracted at build time into `Metadata.appintents`: 5 intents, 2 entities, 4 App Shortcuts.

---

## 8. macOS APIs, permissions and security

### 8.1 Permissions (TCC)

| Permission | Needed by | Check / request | Notes |
|---|---|---|---|
| Accessibility | Switcher (AX, event tap, focus), the Dock's previews and counts (reading the Dock, §7.1.12), scrolling capture (posting scrolls), click overlays, Clipboard History (posting ⌘V to paste; key-downs that time a clipboard check), Window Tiling (moving and resizing other apps' windows, §7.14), Focus Window (§7.17); optional for Esc ending Translate Under Cursor in other apps and for ⌥⌘ opening a click-through pin without a pointer move | `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])`; re-check on app activation, never on a timer; Window Tiling checks `AXIsProcessTrusted()` at each action | Tied to the code signature: use one stable Apple Development certificate on every dev machine, Developer ID for releases |
| Screen & System Audio Recording | Thumbnails/preview, the switcher's and the Dock's (optional), capture (Capture Text and Instant Capture too), recording, window titles via CGWindowList, Translate Under Cursor (§7.7.8), Screen Ruler's edge finding (optional, §7.13) | `CGPreflightScreenCaptureAccess()` / `CGRequestScreenCaptureAccess()` | Periodic re-confirmation on 15+; a relaunch is usually needed after granting |
| Microphone | Recording with mic | `AVCaptureDevice.requestAccess(for: .audio)` + `NSMicrophoneUsageDescription` | Entitlement `com.apple.security.device.audio-input` |
| Camera | Camera bubble | `NSCameraUsageDescription` | Entitlement `com.apple.security.device.camera` |
| Paste from Other Apps | Clipboard History reading other apps' copies (§7.9) | `NSPasteboard.general.accessBehavior` (macOS 15.4+): `.alwaysAllow` granted, `.alwaysDeny` denied, `.default` and `.ask` not yet; a read of another app's copy makes macOS ask and list Oriel | Pasteboard privacy, not a TCC service Oriel checks; System Settings anchor `Privacy_Pasteboard`; Oriel's own copies need nothing |
| Full Disk Access | Disk Space Analyzer's scans of private data (optional, §7.10): other apps' data, Mail, Messages, Safari | Never checked (rule 8): a scan keeps why each folder was closed and offers **Full Disk Access…** (`?Privacy_AllFiles`) for those macOS protects (EPERM); for those only their owner may open (EACCES), which it does not change, **Read as Administrator…** (§7.10 item 17) | Without it those folders are counted as protected by macOS; after granting it, quit and reopen Oriel and scan again |
| Files and Folders | Disk Space Analyzer reading Desktop, Documents, Downloads, removable and network volumes and File Provider (cloud) folders; settings sync's folder in iCloud Drive (§7.16) | macOS asks the first time one is read, showing `NSDesktopFolderUsageDescription`, `NSDocumentsFolderUsageDescription`, `NSDownloadsFolderUsageDescription`, `NSRemovableVolumesUsageDescription`, `NSNetworkVolumesUsageDescription` or `NSFileProviderDomainUsageDescription` (Appendix D); the analyzer says so once before the first scan of the home folder | A refused folder is counted as unreadable; System Settings → Privacy & Security → Files and Folders changes the answer |
| iCloud Drive | Settings sync (§7.16) | iCloud Drive turned on (`~/Library/Mobile Documents/com~apple~CloudDocs` exists); macOS may ask once, as above | iCloud key-value storage would need the `ubiquity-kvstore-identifier` entitlement and an iCloud provisioning profile, which Oriel does not have (§16) |
| Administrator password | Activity Monitor signalling another user's process (§7.11); Disk Space Analyzer thinning local snapshots when macOS refuses the user, and Read as Administrator without its helper (§7.10) | macOS's own prompt, through `osascript … with administrator privileges`, each time; Oriel never sees the password | Not a TCC service |
| Disk Space Analyzer's helper (optional) | Read as Administrator without a password each time (§7.10 item 17) | `SMAppService.daemon(plistName:)`: **Install Helper…** registers it; the user switches it on in System Settings → General → Login Items & Extensions, with an administrator's password, once; `status` is read when the window opens and when Oriel comes to the front | Not a TCC service; registered again after an update; Remove Helper and Uninstall Oriel unregister it |
| Input Monitoring, Automation | Not needed | — | Keep it that way |
| Network | Providers, uploads | — | Not sandboxed; plain-HTTP local endpoints need `NSAllowsLocalNetworking` in ATS |

Activity Monitor needs no permission: `sysctl` and libproc read the user's own processes, `/bin/ps` is setuid root, and nettop needs none. Color Picker needs none either (the system loupe hands over only the clicked color), nor do the video editor and the file translation window.

Hardened Runtime entitlements: only `device.audio-input` and `device.camera`. No sandbox, no `disable-library-validation`, no JIT. Settings sync adds no iCloud entitlement (§7.16).

### 8.2 Onboarding

A permissions window lists each permission, what it unlocks and its live status (re-checked on activation), with deep links `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`, `?Privacy_ScreenCapture` and `?Privacy_Pasteboard`. "Continue without" leads to degraded modes (icons-only switcher, no capture). The tools link to their own panes when they need one: Disk Space Analyzer to `?Privacy_AllFiles`, Screen Ruler and Translate Under Cursor to `?Privacy_ScreenCapture`, Window Tiling's notice to the Accessibility pane. Never read or write `TCC.db`; macOS 27 removes app access to it anyway.

### 8.3 MDM (optional)

If the fleet is managed: a PPPC profile with `Accessibility` allowed for the app's code requirement and `ScreenCapture` set to let standard users approve; the `forceBypassScreenCaptureAlert` key (macOS 15.1+) in a configuration profile to suppress the periodic prompt.

### 8.4 Security practices

IPC socket 0600 with UID check; credentials only in the Keychain; logs mark user content (`privacy: .private`) and never contain OCR text, titles or translations unless debug logging is on; no telemetry; shareable links use unguessable keys. Upload sign-ins are OAuth 2 with PKCE in `ASWebAuthenticationSession`, and their tokens, like WebDAV passwords and S3 secret keys, are Keychain items; SFTP uses the user's own SSH keys and known hosts, never a password (§7.8). Smart Redact, Activity Monitor and Disk Space Analyzer log counts, pids and paths (`.private`), never what they read.

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
| Switcher model work on opening, 200 windows, any preset | < 10 ms p95 in the debug build (`OpeningCostTests`; measured 0.1–0.8 ms) |
| Activity Monitor, window open, 2 s interval | < 20 ms of CPU a sample, `ps` included, about 1 % of one core (`aSampleIsCheap`) |
| Activity Monitor, window closed | Nothing: no sampling and no child processes |
| Camera background effect | Segmentation at most 15 times a second; off for the rest of a recording when it averages over 45 ms, the Mac runs hot or Low Power Mode is on |

Nothing samples while Activity Monitor's window is closed: its `SamplingSession` starts with the window and ends with it (rule 3, §7.11 item 1). Measured in release builds on the dev Mac while other builds ran: a sample's own work is 1.4–2.7 ms; a full `ps` run costs 5–6 ms of CPU in `ps` and a busy-only one about 1.9 ms; at the 2 s interval on the CPU tab a sample averaged 11.5 ms of CPU with `ps` included (7–23 ms), about 0.6 % of one core and about 5 mW of Oriel's own energy; a window update on the main thread takes 4–13 ms. The 1 s interval roughly doubles the cost, and Debug builds are three to five times slower.

The other new tools cost nothing while closed. A Disk Space Analyzer scan keeps about 56 bytes a node plus names while its window is open (200,000 files in 10,000 folders: 21,021 nodes, about 1.3 MB, the footprint up 7 MB, scanned in 0.10–0.13 s warm), so a disk with millions of folders needs a few hundred megabytes until the window closes. Screen Ruler keeps about 4 bytes a pixel per display while it is open (59 MB for a 5K display). Translate Under Cursor costs one full-display screenshot per rest, about 20–60 ms of GPU work, and nothing while the pointer moves. Segmenting a 1280 × 720 camera frame took 4.3–4.5 ms of CPU (9–11 ms wall), about 7 % of one core at 15 a second before compositing, which was not measured.

Techniques: event-driven everything; lazy tile-size thumbnails with at most four captures in flight; `SCShareableContent` refreshed only on change; thumbnails drawn as `CALayer.contents` (`CGImage`/IOSurface) with no `NSImage` round-trips; view recycling and memory-pressure purge; QoS `.userInteractive` for tap work, `.userInitiated` for thumbnails/OCR, `.utility` for history indexing, Activity Monitor's sampling and uploads (the user is waiting for the link); `os_signpost` around hotkey→panel, capture→overlay and OCR→translate→render; recording capped by preset fps with `queueDepth = 5`. Tooling: Instruments (Time Profiler, Allocations, Leaks, Energy/Power Profiler, Swift Executors and Task instruments), `powermetrics --samplers tasks -i 1000 -n 60`, `footprint`, `leaks`, `XCTMetric` tests for the pure pipelines.

---

## 10. UI/UX architecture

### 10.1 App shell

`LSUIElement = YES` (no Dock icon). The status menu is rebuilt each time it opens, every item with its shortcut: Permissions… while a required permission is missing; the tools' own items (Show Window Switcher, Pause Clipboard History, the Window Tiling submenu); Capture Area / Window / Screen / Scrolling / Previous Area / with Timer, Instant Capture, Capture Text, Start Step Capture (Finish Step Capture while one runs); Record Area / Window / Screen (Stop Recording while one runs); Translate Area, Translate Under Cursor (Stop Translating Under Cursor while it is on), Translate File…; the tools' windows (Disk Space Analyzer, Activity Monitor, Pick Color, Color Picker, Screen Ruler); Clipboard History (⌥V), Capture History, Translation History, Open Image in Editor…, Open Video…; Pinned (each pin's submenu with its commands and state, Stop Click-Through on All Pins while one lets clicks through, and Close All Pins); Settings…, Quit Oriel. A command appears in its section while its feature or tool runs, unless `showsInMenu` is false (§6.5). Settings is a SwiftUI window with a sidebar, like System Settings: General (startup, Tools, Sync, permissions), the tools' panes (Window Switcher, Clipboard History, Disk Space Analyzer, Activity Monitor, Color Picker, Screen Ruler, Window Tiling), Capture, Recording, Translation, Editor, Upload, Shortcuts (the app's actions and the features' commands, then each tool that is on), Permissions, Advanced (with Diagnostics), About. System appearance is followed automatically with semantic colors and SF Symbols. Started by the user, Oriel opens Settings (onboarding instead, until it is done), so a launch shows more than an icon; started by macOS at login (the launch event's `keyAELaunchedAsLogInItem`), or to open a file or URL (`NSApplication.launchIsDefaultUserInfoKey` false), it stays in the menu bar. Opening it again while it runs shows Settings. Closing a window never quits it: only Quit Oriel does.

### 10.2 Liquid Glass

Glass (`NSGlassEffectView`, no tint) is used for floating chrome only: switcher, Quick Access Overlay, recording control bar, translation toolbar. The editor canvas and screenshots themselves stay opaque. Under Reduce Transparency / Increase Contrast an opaque `windowBackgroundColor` with a 1 px separator is applied live; do not rely on the glass view to do this itself.

### 10.3 Switcher auto-size

Input: window count *n*, the screen's visible frame, the style and the maximum panel fraction (default 80 % × 60 %). Choose rows *r* and tile width *w* that maximize *w* subject to `cols = ceil(n/r)`, `cols·w + gaps ≤ maxW`, `r·(w/aspect + titleH) + gaps ≤ maxH`, `w ∈ [minTile, maxTile]`; if `minTile` does not fit, scroll rows. With a shortcut grouped by app (§7.1.11) every thumbnail-grid row carries a 22 pt label band and every title-list group a 26 pt header row, and the key-hint line adds a footer; all three are part of the fit. Pure and table-tested.

### 10.4 Capture UX patterns adopted

Lightshot's speed (hotkey → drag → inline mini-toolbar, no mandatory editor: Instant Capture, §7.5); CleanShot's Quick Access Overlay, pins, backgrounds and history; Snagit's numbered steps, step capture, Smart Move and Simplify and OCR-searchable library; Monosnap's pluggable destinations (§7.8). Pinned screenshots are floating `NSPanel`s with opacity, zoom, click-through with four ways back, and a lock (§7.2 item 13).

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
- [ ] Started by the user, Oriel opens Settings; at login, or for a file or URL, it does not. **Verify:** `xcodebuild -project Oriel.xcodeproj -scheme Oriel -destination 'platform=macOS' test -only-testing:OrielTests/LaunchChecksTests`
- [ ] Closing every window leaves Oriel running with the switcher and shortcuts working; only Quit Oriel quits it. **Verify:** manual (`docs/qa-checklists.md` item 39).

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
- [ ] Oriel's own process is never asked through AX; AppKit lists, focuses, closes and minimizes its windows, and quitting from the switcher never quits Oriel. **Verify:** `swift test --package-path Packages/WindowSwitcher --filter OwnWindowsTests`
- [ ] With Oriel's windows opened and closed, the switcher lists them and Oriel keeps running. **Verify:** manual (`docs/qa-checklists.md` items 39–40).
- [ ] The Dock's previews and counts: reading its items, which windows each icon stands for (an app run twice by launch order), where counts and the preview go on each edge, when the preview shows and goes, and the settings that keep the module running with the switcher off. **Verify:** `swift test --package-path Packages/WindowSwitcher --filter DockTests`
- [ ] The real Dock lists its icons with frames on screen, read only. **Verify:** `ORIEL_TCC_TESTS=1 swift test --package-path Packages/WindowSwitcher --filter DockSystemTests`
- [ ] Resting on a Dock icon shows the app's windows and a click switches; counts sit on the icons of apps with two or more windows and follow the Dock's changes. **Verify:** manual (`docs/qa-checklists.md` items 45–46).

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

### 13.9 Commands, settings sync and App Intents
- [ ] Tools and features declare commands; the app registers their shortcuts, menu items, URLs and Settings → Shortcuts rows, a tool's only while it is on; no two actions or commands share an id, a default shortcut or a route. **Verify:** `make test` (`ModuleRegistryCommandTests`, `AppActionTests`, `AllCommandsTests`); `swift test --package-path Packages/OrielCore --filter ToolCommandTests`
- [ ] Clipboard History's ⌥V and `oriel://clipboard` survive the move to a command. **Verify:** `swift test --package-path Packages/ClipboardHistory --filter ClipboardHistoryModuleTests`
- [ ] Settings sync: the policy, the merge rule and a two-Mac round trip through an in-memory store. **Verify:** `swift test --package-path Packages/OrielCore --filter SettingsSyncTests`; `make test` (`SettingsSyncServiceTests`)
- [ ] Settings sync between two real Macs through iCloud Drive. **Verify:** manual (`docs/qa-checklists.md`).
- [ ] App Intents are in the app's metadata (5 intents, 2 entities, 4 App Shortcuts). **Verify:** `Metadata.appintents/extract.actionsdata` after `make build`.
- [ ] The intents run from the Shortcuts app and Spotlight. **Verify:** manual (`docs/qa-checklists.md`).

### 13.10 Switcher presets
- [ ] Presets set and read the filters and grouping; grouping, groups and the first selection are pure functions. **Verify:** `swift test --package-path Packages/WindowSwitcher --filter 'PresetTests|GroupingTests'`
- [ ] Shortcuts saved before presets load with the preset they amount to. **Verify:** `--filter PresetTests`
- [ ] Header bands, header rows and the hint line in the auto-size. **Verify:** `--filter GroupedLayoutTests`
- [ ] ⌘/⌥/⌃+Q quits the selected item's app, also grouped and in app icons; plain Q searches. **Verify:** `--filter GroupingTests`
- [ ] The model work of opening stays under 10 ms p95 with 200 windows in the debug build, for every preset. **Verify:** `--filter OpeningCostTests`
- [ ] Hotkey → first frame p95 < 50 ms with a grouped shortcut on the installed app. **Verify:** Instruments (Time Profiler, the switcher's signposts) with 60+ windows.

### 13.11 Capture additions
- [ ] History indexing reads new and older captures once in the background, tall captures in tiles, and search shows why an entry matched. **Verify:** `swift test --package-path Packages/Capture --filter 'HistorySearchTests|HistoryStoreTests'`
- [ ] Pin opacity, zoom, click-through and its ways back, lock and border are pure and tested, and the Pinned menu offers Stop Click-Through on All Pins. **Verify:** `--filter 'PinStateTests|PinsMenuTests'`
- [ ] A click-through pin takes clicks again with ⌥⌘ held over it, from its corner button and from the Pinned menu. **Verify:** manual (`docs/qa-checklists.md`), with and without Accessibility.
- [ ] The desktop icons and widgets are picked by owner and layer, and the wallpaper stays. **Verify:** `--filter DesktopClutterTests`
- [ ] With Hide desktop icons and widgets on, Capture Area and Capture Screen show the wallpaper without icons or widgets, and Finder's settings are unchanged (`defaults read com.apple.finder CreateDesktop` as before). **Verify:** manual (TCC).
- [ ] Capture Text keeps line breaks and reading order (columns, tables, right-to-left rows), joins hyphenated words by the dictionary, and the command, CLI arguments and JSON report are as specified. **Verify:** `--filter 'TextLayoutTests|TextPreviewTests|CaptureTextTests'`
- [ ] `oriel capture text --rect 100,100,400,300 --json` prints the text and each line in points. **Verify:** run on the installed app with Screen Recording granted (TCC).
- [ ] The Step Capture state machine, reordering, undo merging and every exporter (PNG size, PDF pages, text and bookmarks, Markdown links and files, HTML with embedded images) are tested in temporary directories. **Verify:** `--filter 'StepSessionTests|StepExportTests|StepImageTests'`
- [ ] A session with a click marker, Finish, reorder, retake, annotate and drop back, and the four exports. **Verify:** manual (`docs/qa-checklists.md`).
- [ ] No timers and no new dependencies. **Verify:** `make lint` (the `no_polling` rule); `rg -n "url:" Packages/*/Package.swift` returns nothing.

### 13.12 Editor additions
- [ ] Instant Capture's panel covers the selection on the right display and its toolbar stays on screen (below, above, inside; negative origins, mixed scales, pixel grid). **Verify:** `swift test --package-path Packages/Editor --filter InstantPlacementTests`
- [ ] Instant Capture's keys pick only its tools, Esc ends a drag before closing, Open in Editor hands over the session with its history. **Verify:** `--filter InstantCaptureTests`
- [ ] Instant Capture appears right after the selection, 1:1 over it, and Copy, Save, Upload, Open in Editor and Esc work on screen. **Verify:** manual (`docs/qa-checklists.md`).
- [ ] Every background preset pads the image; aspects grow one side only; alignment places the card; inset and frame grow the card; social sizes export at exactly their pixels. **Verify:** `--filter BackgroundLayoutTests`
- [ ] Radial gradients, inset edge colour, window frame, pictures with blur, shadow settings and tone-down render; background commands are one undo step each; saved backgrounds keep their picture; previews are cached. **Verify:** `--filter BackgroundRenderingTests`
- [ ] Steps: letters and Roman labels, sequences that restart or continue, renumbering per sequence, styles on the selection, pointers and their tip, nudging. **Verify:** `--filter StepTests`
- [ ] Smart Redact finds every category and none of the look-alikes, merges neighbours, hides a PEM block, applies as one undo step, reads the text once. **Verify:** `--filter RedactionTests`
- [ ] Smart Redact's boxes cover the matched text in the system font, Helvetica and Menlo. **Verify:** `--filter TextSpanCoverageTests`
- [ ] Hole fill: flat backgrounds exact, gradients within one level, edge holes, no streaks. **Verify:** `--filter HoleFillerTests`
- [ ] Simplify's bars, ink colours, masks, line grouping; Smart Move lifts, moves and deletes without leaving copies. **Verify:** `--filter 'TextAndMaskTests|SmartMoveTests'`
- [ ] `.oriel` version 2 round-trips every kind and its images; version 1 documents open and look the same. **Verify:** `--filter OrielBundleTests`
- [ ] Smart Redact, Simplify and Smart Move on real screenshots with Vision OCR. **Verify:** manual (`docs/qa-checklists.md`).

### 13.13 Recording and the video editor
- [ ] The click sidecar's format (versioned, refuses newer versions, drops invalid clicks) and the click log's normalization and segment timeline are pure and tested. **Verify:** `swift test --package-path Packages/Recording --filter 'ClickSidecarTests|ClickLogTests'`
- [ ] Auto Zoom: merging, panning only outside the view's middle, easing, focus clamping, the movie's ends; the zoom plan and the transform math for several output sizes. **Verify:** `--filter 'AutoZoomTests|ZoomSegmentTests|ZoomTransformTests'`
- [ ] Chapters: list building, YouTube timestamps, and a chapter track written to MP4 and MOV and read back with AVAsset's chapter metadata groups. **Verify:** `--filter 'ChapterListTests|EditedMovieExportTests'`; `ffprobe -show_chapters` on an export lists the chapters.
- [ ] Export on synthetic movies: trim (duration), MP4/H.264 and MOV/HEVC at 720p (size, codec, container), zoom pixels and frames across a still screen, sound mixed to one stereo AAC track, a trimmed zoomed GIF, progress, replacing a file but never the source, cancelling leaves nothing behind. **Verify:** `--filter EditedMovieExportTests`
- [ ] Copy Text from Frame reads the frame at the exact time (a fake recognizer names the frame's colour). **Verify:** `--filter FrameReaderTests`
- [ ] The editor's model: trim rules, chapters, zoom moves and resizes, undo/redo and coalescing, unexported changes, the keyboard map, the timeline's zoom and scroll, J/K/L. **Verify:** `--filter 'VideoEditTests|VideoEditorSessionTests|VideoEditorShortcutsTests|TimelineMappingTests|ShuttleTests|TimecodeTests'`
- [ ] The camera background effect on synthetic frames (replace, blur, mirror, mask), its gate and its governor. **Verify:** `--filter 'CameraBackgroundTests|CameraBackgroundRendererTests'`
- [ ] No polling. **Verify:** `make lint` (the `no_polling` rule covers the package)
- [ ] A real recording's clicks land in its sidecar within 0.1 s of where the video shows them, and Auto Zoom follows them. **Verify:** manual (`docs/qa-checklists.md`), with Screen Recording.
- [ ] Blur camera background keeps a 1080p30 recording with the bubble under budget on Apple silicon and turns off under load. **Verify:** manual, Activity Monitor or `top -pid <Oriel>` during a recording with the bubble, with Camera.
- [ ] QuickTime Player and IINA show an exported movie's chapters. **Verify:** manual.

### 13.14 Translation additions
- [ ] Translate Under Cursor: debounce, dedupe, cache, dismissal and abandoned reads are a pure state machine tested on a clock the test sets. **Verify:** `swift test --package-path Packages/OrielTranslation --filter CursorRestMachineTests`
- [ ] The line or paragraph under a point is chosen from OCR boxes; cut-off text is read again from a larger area; the tooltip stays on screen. **Verify:** `--filter 'CursorTextPickerTests|CursorGeometryTests'`
- [ ] The mode end to end with a pretend screen, OCR and provider: one capture per rest, one translation per text, no reads after Stop, losing Screen Recording stops it. **Verify:** `--filter CursorTranslationControllerTests`
- [ ] Without Screen Recording the mode explains and does not start; commands have their ids, ⌃⇧U and routes. **Verify:** `--filter TranslationCommandTests`
- [ ] File-type routing, segmenting (text, Markdown, HTML, rich text), subtitle parsing and writing, chunking and exports. **Verify:** `--filter 'DocumentKindTests|SegmenterTests|SubtitleFileTests|DocumentChunkerTests|DocumentExporterTests|SegmentPresentationTests'`
- [ ] Real files are read: Latin-1 text, Markdown, WebVTT, RTF, DOCX, PNG with OCR, a PDF with a text page and a scanned page. **Verify:** `--filter DocumentReaderTests`
- [ ] File jobs: chunks within provider limits, a failure partway keeps results and Resume sends only what is missing, a stop during reading is resumed, images get their overlay, subtitles keep timing, the glossary reaches every chunk. **Verify:** `--filter FileTranslationTests`
- [ ] Glossary matching, placeholder round trip with mangled tokens and raw fallback, CSV/TSV import and export, pair rules and persistence with migration. **Verify:** `--filter 'GlossaryMatcherTests|GlossaryProtectionTests|GlossaryCSVTests|GlossaryLibraryTests'`
- [ ] Provider glossaries with stubbed requests: DeepL create, reuse, replace, re-create and unsupported pairs; Google project glossary on v3 and the fallback to Basic; Apple tokens; prompts with only the terms that occur. **Verify:** `--filter 'DeepLGlossaryTests|ProviderGlossaryTests|SegmentPromptTests'`
- [ ] Translate Under Cursor on real text in Safari, Preview and a full-screen app; the badge; Esc with Accessibility. **Verify:** manual (`docs/qa-checklists.md`), with Screen Recording.
- [ ] A text PDF, a scanned PDF, a .docx and an .srt translate and export; the SRT plays in QuickTime with the original timing. **Verify:** manual (`docs/qa-checklists.md`).
- [ ] DeepL creates the glossary in the account and the translation uses it; a Google Cloud glossary named in a project is used. **Verify:** manual, with DeepL and Google keys.

### 13.15 Upload destinations
- [ ] Request building for every destination: WebDAV `PUT`/`MKCOL`/`PROPFIND`, Dropbox upload, session and shared-link calls with `Dropbox-API-Arg` escaping, Google multipart and resumable bodies, S3 `PUT` with its payload hash. **Verify:** `swift test --package-path Packages/Upload --filter 'WebDAVTests|DropboxTests|GoogleDriveTests|S3DestinationTests'`
- [ ] PKCE matches RFC 7636 appendix B; authorization URLs, code exchange, refresh (once at a time, kept, forgotten on `invalid_grant`), revocation and callback parsing. **Verify:** `--filter 'PKCETests|OAuthTests|TokenRefreshTests'`
- [ ] sftp batch generation with quoting, refused paths and options, the command line, and stderr → errors; uploads and tests through a fake runner. **Verify:** `--filter SFTPTests`
- [ ] Name templates, URL templates and link formats. **Verify:** `--filter 'UploadNameTemplateTests|UploadLinkTemplateTests'`
- [ ] Destinations survive a round trip, tolerate missing fields and unknown kinds; the 0.1 S3 setting and secret become the default destination once, and a bootstrap import updates it. **Verify:** `--filter UploadDestinationStoreTests`
- [ ] Shared folder: whole copies, numbered names, no partial files, refusals, and the bookmark after a rename. **Verify:** `--filter SharedFolderTests`
- [ ] Image files lose GPS, EXIF and TIFF metadata but keep their orientation; captures are fresh PNGs. **Verify:** `--filter PayloadPreparerTests`
- [ ] No timers and no dependencies. **Verify:** `make lint`; `rg -n "url:" Packages/Upload/Package.swift` returns nothing.
- [ ] An upload to each kind of destination works and copies the link; Cancel stops it; errors read well. **Verify:** manual (`docs/qa-checklists.md`), with real accounts and servers.
- [ ] Dropbox signs in with `db-<app key>://2/token` without a registered redirect URI; Google with an iOS client and its reversed client ID. **Verify:** manual, with a Dropbox app and a Google Cloud client.

### 13.16 Disk Space Analyzer
- [ ] Aggregation of smaller files, hard-link dedupe, clones, purgeable and cloud-only files, exclusions, hidden files, volume crossing, the compact tree (totals, paths, firmlinks, edits, compaction, search). **Verify:** `swift test --package-path Packages/DiskAnalyzer --filter 'DirectoryDigestTests|ScanTreeTests'`
- [ ] The scanner on temporary folders: nested folders, hard links, symbolic links, an unreadable folder (`chmod 000`), cancellation, progress, a refresh after a change, and both readers giving the same tree. **Verify:** `--filter ScanEngineTests`
- [ ] The squarified treemap and the sunburst angles, hit testing and merging. **Verify:** `--filter 'TreemapLayoutTests|SunburstLayoutTests'`
- [ ] Filters and sorting, duplicate grouping and selection, and the protected-path rules. **Verify:** `--filter 'FileFilterTests|DuplicateGrouperTests|SafetyRulesTests'`
- [ ] The purgeable math, the startup volume's accounting, CSV export, snapshots and their diffs, the `tmutil` output parser and the administrator command's quoting. **Verify:** `--filter 'VolumeUsageTests|ExportAndHistoryTests|SystemTextTests'`
- [ ] Copies with progress and free names, moves on one volume and through copy-check-remove, Trash and Undo (with a Trash of the test's own), deleting a link, refusals, per-item failures and cancel. **Verify:** `--filter FileOperatorTests`
- [ ] The FSEvents stream reports a change made by another process; the duplicate finder, clone facts, space hogs (in a home folder of the test's own) and volume crossing on real files. **Verify:** `--filter 'ScanWatcherTests|SystemHelperTests'`
- [ ] The commands, the CLI verbs and their parsing, the snapshot store, and the window's model (plans, navigation, search, renumbered trees). **Verify:** `--filter 'DiskAnalyzerModuleTests|HistoryAndCommandLineTests|AnalyzerModelTests'`; `swift test --package-path Packages/IPC --filter CommandParserTests`
- [ ] No polling. **Verify:** `make lint` (the `no_polling` rule covers the package)
- [ ] Why a folder could not be read (`EACCES`, `EPERM`, other), kept on the node and counted again from the tree. **Verify:** `--filter 'ScanEngineTests|ElevatedReadTests'`
- [ ] macOS's own volumes: what is left out and entered, anchors through edits and compaction, a scan into the macOS folder, Preboot as a block, refreshes leave them, the lists and Duplicates leave them out, `ATTR_VOL_SPACEUSED` below the container's use. **Verify:** `--filter MacOSVolumesTests`
- [ ] Read as Administrator: its request as arguments and back, its listing as the user (an unreadable folder, JSON round trip) and the graft into a scan; the app's executable lists folders and exits. **Verify:** `--filter ElevatedReadTests`; `xcodebuild -project Oriel.xcodeproj -scheme Oriel -destination 'platform=macOS' test -only-testing:OrielTests/ElevatedReadEntryTests`
- [ ] Oriel's helper over XPC: listings through an anonymous listener, another app's signature refused, a request it does not understand, idling out; the requirement, the label, macOS's states and when it starts. **Verify:** `--filter PrivilegedReaderTests`
- [ ] The built app carries the helper's launchd property list, named after its bundle ID. **Verify:** `xcodebuild -project Oriel.xcodeproj -scheme Oriel -destination 'platform=macOS' test -only-testing:OrielTests/LaunchDaemonTests`
- [ ] Install Helper, the approval in System Settings, reading after every scan without a password, Remove Helper and Uninstall work on the installed app. **Verify:** manual (`docs/qa-checklists.md` item 44).
- [ ] A scan of Macintosh HD adds up to Finder's used space with the macOS folder (or "macOS (system)" with the setting off); the permission prompts appear once with Oriel's texts; the notes say why folders are closed, Full Disk Access removes the protected-by-macOS note for personal data and Read as Administrator reads the owner-only folders (QA items 42–43); Move to Trash, Undo, Delete Immediately, a move to an external drive, Eject, Remove Download, Remove Snapshots and `oriel disk scan ~/Downloads` work on the installed app. **Verify:** manual (`docs/qa-checklists.md`).
- [ ] Clean Up's judgment: the catalog and its order, the folders it judges by place, name and contents, the leftovers inside (older versions, temporary profiles, caches), what makes it more cautious (refusals, the cloud, repositories, personal files, processes, running apps, who may remove it), versions in names and Apple Intelligence's prompt. **Verify:** `--filter CleanupAdvisorTests`
- [ ] Clean Up of a folder of the open scan comes from the scan, and of any other folder from a scan of its own; a change measures again the space hogs whose folders it touched; Downloads offers its installers. **Verify:** `--filter 'AnalyzerModelTests|CleanupAdvisorTests'`
- [ ] What Clean Up reads from a folder of the test's own: the scan's facts, CACHEDIR.TAG, the Time Machine exclusion, removability, and a process with a file open inside, in either spelling of the path. **Verify:** `--filter CleanupInspectorTests`
- [ ] Clean Up on the installed app: the advice and its methods for `~/.gradle/caches`, a Chrome-headless folder and `/Library/Developer/CoreSimulator/Caches`, the Trash with Undo, CoreSimulator's command, Apple Intelligence's reading of an unknown folder, and Clean Up from Space Hogs' rows. **Verify:** manual (`docs/qa-checklists.md` item 47).

### 13.17 Activity Monitor
- [ ] CPU % from tick and time deltas (wrap, resets, reused pids, mixed readers), the memory breakdown, the ps and nettop parsers (names with spaces, dots and commas; header-ordered columns), IOKit and sysctl dictionaries, the process tree and helper grouping, filters, search and sorting, the signal safety rules, the ring buffer and heavy-use detection are pure and tested. **Verify:** `swift test --package-path Packages/ActivityMonitor`
- [ ] Sampling happens only in `SamplingSession` and stops with it; nothing keeps running. **Verify:** `make lint` (the `no_polling` rule covers the package); `swift test --package-path Packages/ActivityMonitor --filter theSessionSamplesUntilItIsStopped`
- [ ] A sample costs well under 1 % of a core at 2 s. **Verify:** `swift test --package-path Packages/ActivityMonitor --filter aSampleIsCheap` (under 20 ms of CPU per sample, `ps` included; release-build figures in §9)
- [ ] Signals reach only the process the user confirmed; protected pids are refused; children are stopped on timeout and cancellation. **Verify:** `--filter 'SignalPolicyTests|ChildProcessTests'`
- [ ] `oriel top` parses and answers usage errors. **Verify:** `swift test --package-path Packages/IPC --filter CommandParserTests`; `swift test --package-path Packages/ActivityMonitor --filter ActivityMonitorModuleTests`
- [ ] The window opens from the menu bar and `oriel://activity`; tabs, views, search, sorting, the details, Quit, Force Quit, Send Signal, quitting as an administrator, Sample Process, Reveal and Copy work on the installed app. **Verify:** manual (`docs/qa-checklists.md`).
- [ ] `oriel top --sort network --json` answers through the installed CLI. **Verify:** manual.

### 13.18 Color Picker
- [ ] Color conversions (sRGB ↔ HSL, HSB, CMYK, OKLCH, Display P3), every format and its parsing, WCAG 2.2 ratios and thresholds, APCA, the library (history cap, palettes), persistence and migration, and palette export are pure and tested. **Verify:** `swift test --package-path Packages/ColorPicker`
- [ ] The panel's number keys, ⌘C, tabs, drops, typed colors and Undo. **Verify:** `--filter ColorPanelControllerTests`
- [ ] No polling, and no required permission. **Verify:** `make lint` (the `no_polling` rule); `--filter ColorPickerModuleTests`
- [ ] ⌃⇧C picks the clicked color, copies it and opens the panel. **Verify:** manual (`docs/qa-checklists.md`).

### 13.19 Screen Ruler
- [ ] Edge finding (solid blocks, gradients, noise, Retina), fitting, snapping, units and formatting, multi-display coordinates, the area editor, guides, the keymap and the session's state machine are pure and tested. **Verify:** `swift test --package-path Packages/ScreenRuler`
- [ ] No polling, and no required permission. **Verify:** `make lint` (the `no_polling` rule); `--filter ScreenRulerModuleTests`
- [ ] The screen is captured at its pixel size without Oriel's windows. **Verify:** `ORIEL_TCC_TESTS=1 swift test --package-path Packages/ScreenRuler --filter theScreenIsCapturedAtItsPixelSize` (TCC, dev Mac)
- [ ] ⌃⇧M measures on two displays of different scales; Dimensions finds edges with Screen Recording and explains itself without it. **Verify:** manual (`docs/qa-checklists.md`).

### 13.20 Window Tiling
- [ ] Every layout's frame on the built-in display, and on every arrangement (left of, right of, above and below the main display, portrait, an odd width, the Dock bottom, left and right) inside the visible frame, on whole points, with neighbours meeting exactly and the gap honoured. **Verify:** `swift test --package-path Packages/WindowTiling --filter 'TileLayoutTests|DisplayGeometryTests'`
- [ ] Cycling, display order and moves, size steps and restore plans. **Verify:** `--filter TilingPlannerTests`
- [ ] Minimum and maximum sizes, snapping and windows larger than the screen keep the layout's edge and stay on screen. **Verify:** `--filter 'TileFittingTests|WindowArrangerTests'`
- [ ] Restore bookkeeping: runs, moves by hand, LRU. **Verify:** `--filter TileHistoryTests`
- [ ] The AX sequence (size, position, size again, read back, line up), skipped windows and `AXEnhancedUserInterface`, against simulated windows. **Verify:** `--filter WindowArrangerTests`
- [ ] Commands have the assigned ids and defaults, unique, out of the menu list; the menu shows them with key equivalents; feedback per outcome; no permission → notice. **Verify:** `--filter 'TilingCommandsTests|WindowTilingModuleTests'`
- [ ] No timers and no AX outside the AX actor. **Verify:** `rg -n "Timer|DispatchSource" Packages/WindowTiling/Sources` returns nothing; `rg -ln "AXUIElement(Copy|Set|Perform|IsAttribute)" Packages/WindowTiling/Sources` lists only `System/AXWindowAccess.swift`.
- [ ] Reads the front app's focused window for real. **Verify:** `ORIEL_TCC_TESTS=1 swift test --package-path Packages/WindowTiling --filter SystemAccessTests` (read-only)
- [ ] Oriel's own window in front is arranged through AppKit on the main thread, never by the AX actor. **Verify:** `--filter OwnWindowTilerTests`
- [ ] Tiles real windows on the installed app. **Verify:** manual (`docs/qa-checklists.md`).

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
| OAuth redirects not yet confirmed: Dropbox accepting `db-<app key>://2/token` without a registered redirect URI (known from its SDKs, not documented), and Google accepting an iOS-type client from a macOS app | Medium / Medium (no Dropbox or Drive uploads) | QA with a real Dropbox app and Google Cloud client; the fallback is a loopback redirect (`http://127.0.0.1:<port>/`) with a one-shot local listener |
| Google ends the sign-in after 7 days while a consent screen is in Testing | High / Low | Publish the consent screen (`drive.file` needs no review, though Google may ask for brand verification); Settings says "Sign in again" |
| iCloud key-value storage needs the `ubiquity-kvstore-identifier` entitlement, which a Developer ID app gets only with an iCloud provisioning profile | High / Low | Settings sync uses a folder in iCloud Drive until then; the app switches to key-value storage by itself once the entitlement is there (§7.16) |
| Window Tiling in Electron and Chromium apps: with `AXEnhancedUserInterface` on they animate frame changes and land late and short; some apps refuse Accessibility or apply a size asynchronously | Medium / Low | Turn the attribute off for the move and back on; set the size twice and read back; 2 pt tolerance; "This window can't be moved or resized" |
| Tool shortcuts collide with other apps' (⌃⌥ with arrows and letters, ⌃⇧C, ⌃⇧M, ⌃⇧O, ⌃⇧U, ⌃⇧2) | Medium / Low | Settings → Shortcuts flags ⚠︎ when Carbon refuses a combination; a tool's shortcuts are free while it is off; `AllCommandsTests` keeps Oriel's own unique |
| `ps` and nettop output formats are not API, and kernel counters (rusage wake-ups, Rosetta timebase) differ by chip | Medium / Low (dashes in Activity Monitor) | Parsers tested on captured output skip what they cannot read; `hw.tbfrequency` for ticks; interrupt wake-ups on Apple silicon |
| Smart Redact misses text OCR cannot read, and blur or pixelate is not cryptographic redaction | Medium / High (a leaked secret) | Strength scales with the text's height; generous boxes; the review asks the user to check the result; a solid-bar effect is open (§17) |
| Disk Space Analyzer's accounting: APFS clones counted at full size, and the helper volumes are told apart by sharing the startup container's size | High / Low | The inspector shows what deleting an item really frees; Preboot, whose cryptex images are clones, is one block of its `ATTR_VOL_SPACEUSED`; Other space absorbs the difference |
| The camera background effect costs more than measured on a real camera (edges, hair, glasses, cold cores) | Medium / Medium | `SegmentationGovernor` turns it off for the recording above 45 ms, when hot or in Low Power Mode; Apple silicon outside Rosetta only |
| Apple Translation drops or translates the `[[N]]` glossary tokens | Medium / Low | Each segment is checked, and one with a lost or mangled token is translated again without tokens |

---

## 17. Additional features

Everything this section listed for after 1.0, for 1.x and 2.x, is built in 0.1.0 (`docs/reports/03-roadmap-and-tools.md`), and so are two tools it did not list.

| Listed for | Item | Built as |
|---|---|---|
| 1.x | Capture history with OCR-indexed search | Indexing in the background, tall captures read in tiles, snippets that show why a capture matched (§7.2 item 12) |
| 1.x | Pinned screenshots with opacity and click-through | Opacity, zoom, click-through with four ways back, lock, border and shadow (§7.2 item 13) |
| 1.x | Background tool for social-ready shots | Fills and pictures, shadow, inset, window frame, social sizes, saved presets (§7.5 item 2) |
| 1.x | Hide desktop icons during capture | Hide desktop icons and widgets (§7.2 item 9) |
| 1.x | "Copy Text" OCR mode | Capture Text, ⌃⇧O (§7.2 item 10) |
| 1.x | Numbered-step and step-capture sequences | Step styles and series (§7.5 item 3); Step Capture (§7.2 item 11) |
| 1.x | Smart Redact (emails, phone numbers, keys found by OCR and data detectors, on device) | Smart Redact, ⇧⌘R (§7.5 item 4) |
| 1.x | More upload destinations (WebDAV, SFTP, shared folder, Dropbox and Drive via OAuth) | Six kinds of destination (§7.8) |
| 1.x | Lightshot-style instant mode | Instant Capture, ⌃⇧2 (§7.5 item 1) |
| 1.x | Switcher presets (active-app-only, app-grouped, per-display, quit-app) | Presets, grouping by app and the key-hint line (§7.1.11) |
| 2.x | Video editor beyond trim: zoom and pan to clicks, webcam background blur, chapters | The video editor with Auto Zoom and chapters (§7.15); clicks kept for Auto Zoom and Blur camera background (§7.4) |
| 2.x | Snagit-style Smart Move and Simplify via Vision segmentation | §7.5 item 5 |
| 2.x | "Translate under cursor" live mode | Translate Under Cursor, ⌃⇧U (§7.7.8) |
| 2.x | File drag-in translation | Translate File… and file drops (§7.7.9) |
| 2.x | Per-project glossary | Glossary projects for every provider (§7.7.10) |
| 2.x | Video-frame OCR | Copy Text from Frame (§7.15 item 9) |
| 2.x | Color picker with contrast checker | Color Picker, ⌃⇧C (§7.12) |
| 2.x | Screen ruler | Screen Ruler, ⌃⇧M (§7.13) |
| 2.x | Window tiling hotkeys | Window Tiling (§7.14) |
| 2.x | App Intents for capture, translate and focus | Five intents and four App Shortcuts (§7.17) |
| 2.x | iCloud KVS settings sync | Settings sync through iCloud Drive, and through key-value storage once the app has the entitlement (§7.16) |
| — | Not listed | Disk Space Analyzer (§7.10), Activity Monitor (§7.11), and tools and features that declare their own commands (§6.3, §6.5) |
| — | Asked for during testing (`docs/reports/06-dock-and-clean-up.md`) | Dock previews and window counts (§7.1.12); Clean Up in Disk Space Analyzer (§7.10 item 19) |

**What remains for later,** from the gaps the report records:

- **Upload:** a menu of destinations on the Upload buttons (`destinationMenu(_:)` exists but is unused), Upload in the finished-recording panel (`upload(fileAt:)` has no caller yet), `oriel upload <file> [--to <destination>]`, S3 multipart uploads beyond 5 GB, the new kinds in the bootstrap file, and a loopback redirect should Dropbox refuse its custom one.
- **Recording:** video editor edits that persist, in a project file beside the movie.
- **Capture:** the annotated image returning to its step without a drop or a paste, and a Step Capture session that survives quitting Oriel.
- **Editor:** a solid-bar redaction beside blur and pixelate; magnifier callouts and stickers (§7.5).
- **Translation:** Translate Under Cursor capturing only its area (`SCScreenshotConfiguration.sourceRect`) rather than the whole display; its translations and file translations in the history; DeepL's v3 glossaries, which can be edited; the glossary pop-up in the overlay's toolbar; rich formatting rebuilt in file exports.
- **Tools:** CLI verbs for Color Picker (`oriel color convert`, `oriel color contrast`; the model supports both) and Window Tiling, with `oriel://` routes that do not bring Oriel to the front; a key that reads the screen again in Screen Ruler; Remove Download for File Provider domains, if an API appears; dragging items out of Disk Space Analyzer; stopping a scan in the app when `oriel disk scan` gives up; pausing Activity Monitor's sampling while its window is covered.
- **Settings sync:** iCloud key-value storage, once Oriel is signed with an iCloud provisioning profile (§7.16).
- The non-goals of §1.5, VoiceOver polish and localization, stand.

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
│   ├── Sources/                     # AppDelegate, Shell/ (status menu, ModuleRegistry, FeatureHub), Onboarding/, Settings/, Bootstrap/, System/, Sync/, Intents/
│   ├── Resources/                   # Assets.xcassets (app icon: window with a projecting bay), Localizable.xcstrings (en only)
│   ├── Info.plist
│   └── Oriel.entitlements
├── CLI/Sources/main.swift           # oriel command (argument parsing by hand; no swift-argument-parser)
├── Packages/
│   ├── OrielCore/  PrivateAPIs/  Permissions/  Hotkeys/  SharedUI/  IPC/
│   ├── WindowSwitcher/  Capture/  Recording/  Editor/
│   ├── OCR/  OrielTranslation/  Upload/
│   └── ClipboardHistory/  DiskAnalyzer/  ActivityMonitor/  ColorPicker/  ScreenRuler/  WindowTiling/
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

Every package uses `// swift-tools-version: 6.2` (the first version with `.defaultIsolation`), `platforms: [.macOS("26.0")]`, `swiftLanguageModes: [.v6]`, one library product named after the package (`OrielCore` also exports `OrielTestSupport` for test targets), a `Tests/<Name>Tests` target, and `swiftSettings: [.defaultIsolation(MainActor.self)]` only for UI packages (`SharedUI`, `WindowSwitcher`, `Capture`, `Recording`, `Editor`, `Upload`, `ClipboardHistory` and the tools `DiskAnalyzer`, `ActivityMonitor`, `ColorPicker`, `ScreenRuler`, `WindowTiling`); service packages keep nonisolated defaults and use actors. In a main-actor package, pure model types and their extensions are declared `nonisolated` (an extension in another file is main-actor again otherwise), and protocols that services and fakes conform to are `nonisolated protocol` (`docs/os-quirks.md`).

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
excluded: [Spikes, build, .build, .claude, Packages/*/.build]   # swift test writes generated sources into each package's .build
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
# --strict turns every warning into an error, so the warning levels are the real limits: set where a reviewer
# would object in an app of this size, instead of SwiftLint's defaults (50-line functions, 250-line types).
function_body_length: { warning: 80, error: 150 }
type_body_length: { warning: 450, error: 800 }
file_length: { warning: 800, error: 1200 }
cyclomatic_complexity: { warning: 16, error: 30, ignores_case_statements: true }
function_parameter_count: { warning: 7, error: 10 }
large_tuple: { warning: 3, error: 4 }
nesting: { type_level: 2 }
identifier_name:
  min_length: { warning: 2, error: 1 }
  excluded: [x, y, i, j, id, dx, dy, ok, to]
```

`.swiftformat`
```
--swiftversion 6.0
--indent 4
--maxwidth 140
--wraparguments before-first
--stripunusedargs closure-only
--exclude Spikes,build,.build,.claude
```

In a git worktree nested in the main checkout (`.claude/worktrees/…`), SwiftFormat also reads the parent's `.swiftformat`, whose `.claude` exclusion then covers the whole worktree; lint such a worktree with `swiftformat --config .swiftformat --lint .` (`docs/os-quirks.md`).

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
6. Never call AX on the main thread in hot paths; use the AX actor with messaging timeout 0.25 s. Never send an AX
   request to Oriel's own process: macOS answers it inside Oriel on the calling thread, so AppKit runs off the main
   thread (docs/os-quirks.md). Oriel's own windows go through AppKit.
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
        LSApplicationCategoryType: public.app-category.utilities   # Finder's Kind and the archive's App Category
        NSMicrophoneUsageDescription: "Oriel records your microphone only during screen recordings you start."
        NSCameraUsageDescription: "Oriel shows your camera only in the recording overlay you enable."
        # Disk Space Analyzer (PLAN §7.10): macOS asks the first time a scan reads one of these
        NSDesktopFolderUsageDescription: "Oriel reads your Desktop folder only when you scan it or manage its files in Disk Space Analyzer."
        NSDocumentsFolderUsageDescription: "Oriel reads your Documents folder only when you scan it or manage its files in Disk Space Analyzer."
        NSDownloadsFolderUsageDescription: "Oriel reads your Downloads folder only when you scan it or manage its files in Disk Space Analyzer."
        NSRemovableVolumesUsageDescription: "Oriel reads removable volumes only when you scan one or manage its files in Disk Space Analyzer."
        NSNetworkVolumesUsageDescription: "Oriel reads network volumes only when you scan one or manage its files in Disk Space Analyzer."
        NSFileProviderDomainUsageDescription: "Oriel reads your cloud storage folders only when you scan them in Disk Space Analyzer, and keeps synced settings in an Oriel folder in iCloud Drive when you turn on settings sync."
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
    postBuildScripts:
      # Disk Space Analyzer's privileged helper (PrivilegedReader): its launchd property list, named after the bundle ID
      # so a Debug build's helper never takes the release's name. Code signing comes after this phase and seals it.
      - name: Embed the disk reader's launchd property list
        script: |
          set -euo pipefail
          plist="$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH/Library/LaunchDaemons/$PRODUCT_BUNDLE_IDENTIFIER.disk-reader.plist"
          mkdir -p "$(dirname "$plist")"
          sed -e "s/BUNDLE_IDENTIFIER/$PRODUCT_BUNDLE_IDENTIFIER/g" -e "s/EXECUTABLE_NAME/$EXECUTABLE_NAME/g" \
            "$SRCROOT/App/LaunchDaemons/disk-reader.plist" > "$plist"
          plutil -lint -s "$plist"
        inputFiles:
          - $(SRCROOT)/App/LaunchDaemons/disk-reader.plist
        outputFiles:
          - $(TARGET_BUILD_DIR)/$(CONTENTS_FOLDER_PATH)/Library/LaunchDaemons/$(PRODUCT_BUNDLE_IDENTIFIER).disk-reader.plist
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

# 01 — Implementation report (phases 1–8, release 0.1.0)

2026-10-29 · macOS 27.0.1 (26A434) · Xcode 27.1 (27A9275) · stands in for the phase-1 to phase-8 reports, because the phases were built in one pass at your request; the Phase 3 and Phase 6 checkpoints fold into the review of this report.

## Result

- Every feature in PLAN §1 is implemented in its package and wired into the app (`App/Sources/Shell/FeatureHub.swift`): the window switcher, capture with the Quick Access Overlay, pins, history and scrolling capture, screen recording, the editor, OCR and translation, S3 upload, the CLI and the `oriel://` URLs. An audit of §7, §10 and §15 against the code before the release found eight parts missing or not connected; they were added (last section).
- Version 0.1.0, the first release, is built, signed with Developer ID, notarized and stapled: `dist/Oriel.app` and `dist/Oriel-0.1.0.dmg` (release section below).
- `make generate build test lint universal-check` passes: 591 package tests and 17 app tests, no compiler warnings, SwiftLint `--strict` and SwiftFormat clean, both slices in the app and the CLI, and `--self-test` loading all 13 packages natively and under Rosetta. The TCC-gated keychain tests (OrielCore, OrielTranslation, bootstrap import) and the screen-capture test also pass with `ORIEL_TCC_TESTS=1`; the event-tap test was not run.
- 30 of the 40 checklist items are ticked, each after its Verify command passed here. The others need a person at the Mac (below).

## What exists

| Package | What it does | Source lines | Test lines |
|---|---|---|---|
| OrielCore | Protocols and models, settings, Keychain, logging, geometry, capabilities, DI; `OrielTestSupport` with `.requiresTCC` | 831 | 211 |
| PrivateAPIs | 12 SkyLight/HIServices symbols through `dlsym`, all optional | 333 | 59 |
| Permissions | Accessibility, Screen Recording, microphone and camera state, re-read on events, without timers | 148 | 79 |
| Hotkeys | Carbon hotkeys, the event tap, the shortcut recorder, Sticky Keys | 578 | 156 |
| SharedUI | Glass and opaque panels, HUD buttons, toasts, pasteboard, image files | 397 | 60 |
| IPC | Unix-socket server and client, the CLI parser | 339 | 133 |
| WindowSwitcher | Window store (AX + CGWindowList + SkyLight), switcher and preview panels, search, focus engine, ⌘⇥ takeover, gestures, exceptions, display placement, `windows.*` verbs | 6,160 | 2,227 |
| Capture | Freeze-frame and live selection with loupe and snapping, timer, headless captures, Quick Access, pins and the Pinned menu, history with OCR search, scrolling capture | 5,634 | 1,081 |
| Recording | `SCRecordingOutput` sessions with pause segments, audio, camera bubble, click and keystroke overlays, trim, GIF | 2,797 | 1,141 |
| Editor | Document model; arrows, shapes, pen, text, steps, blur, pixelate, spotlight, crop and background; renderer, undo, Quick Look, `.oriel` bundles, PNG/JPEG/HEIC/PDF export | 4,779 | 1,670 |
| OCR | Vision text recognition, geometry, language detection | 273 | 279 |
| OrielTranslation | Providers for Apple Translation, OpenAI-compatible servers (local models and OpenAI), Foundation Models, Anthropic, Google (with v3 glossaries) and DeepL; streaming overlay, side panel, history, usage limits, pack download | 6,509 | 2,439 |
| Upload | SigV4 signer (checked against AWS's published example), S3-compatible uploads, settings | 439 | 75 |
| App + CLI | Status menu, settings, onboarding, module registry, IPC router, bootstrap import, launch checks, uninstaller; the `oriel` tool | 1,980 + 66 | 261 |

The foundation, the app shell and Upload were written in the main session; Recording, Editor, OCR with OrielTranslation, WindowSwitcher and Capture were written in parallel and merged after review. A last pass added the Verify scripts and tests (`scripts/verify-*.sh`, `idle-cpu.sh`, `perf-capture.sh`, `ShortcutRecorderTests`, `BootstrapImportTests`, `InfoPlistTests`) and two Debug-only verbs for them, `oriel debug record` and `oriel debug perf-capture`.

## Measured here

| What | Result | Budget |
|---|---|---|
| Capture Area, request to overlay on screen (`scripts/perf-capture.sh`, 20 runs, Debug build) | p50 85.5 ms, p95 92.5 ms | p95 < 120 ms |
| Idle CPU, release build (`scripts/idle-cpu.sh`, 600 samples) | 0.00 % average, peak 0.1 % (2 of 599 samples), no idle wake-ups | 0.0 % |
| 10 s recording (`scripts/verify-recording.sh`) | 10.125 s, playable, 1 video and 1 audio track | 10 ± 0.2 s |
| Recording paused from 3 s to 5 s (`--pause`) | one movie, 8.128 s, playable, audio | 8 ± 0.2 s |
| `oriel capture area --rect 100,100,400,300` on the 2× display | 800 × 600 px | selection × scale |
| `oriel debug capabilities --json` | arch, Rosetta, Apple Intelligence, packs, private symbols, permissions | all six |

The screen was locked while these were measured. Captures and recordings work then and show the lock screen, so the numbers above are real; anything that needs Accessibility to see windows is not (next section).

## Not verified here, and how to finish

| Checklist item | Why not | How |
|---|---|---|
| Permissions reflect live state (13.1) | The `rg` half passes; the other half is toggling a permission by hand | With Settings → Permissions open, turn Accessibility off and on in System Settings; the row follows without reopening |
| Launch at login (13.1) | Would add a login item to your Mac | Settings → General → Open Oriel at login, then System Settings → General → Login Items |
| `windows list` matches the fixtures; focus across Spaces (13.2) | Accessibility lists no windows while the screen is locked (docs/os-quirks.md) | `ORIEL_TCC_TESTS=1 bash scripts/verify-windows.sh --other-space` (the script ran up to that point) |
| ⌘⇥ restored after quit and `kill -9` (13.2) | Needs a switcher shortcut on ⌘⇥ and turns the system's ⌘⇥ off for a while | Bind ⌘⇥ in Settings → Window Switcher, then `ORIEL_TCC_TESTS=1 bash scripts/verify-cmdtab-restore.sh` |
| Reduce Transparency switches live (13.2) | The unit tests pass; the check by eye remains | Toggle System Settings → Accessibility → Display → Reduce transparency with the switcher open |
| Gestures on recorded sequences (13.2) | The tests use synthetic three-, two-, four- and five-finger sequences; real recordings need a trackpad session | Record sequences into `Tests/Fixtures/gestures/` and replay them in `GestureRecognizerTests` |
| Window capture leaves Oriel's overlays out (13.3) | No image-diff test yet; it needs an unlocked screen | A `.requiresTCC` test that shows a magenta panel and checks it is absent from a capture |
| Offline EN→JA with Wi-Fi off (13.5) | Would turn off your Wi-Fi | `oriel translate area --rect … --to ja --provider apple --json` with Wi-Fi off |
| Tap install on a clean macOS 26 VM (13.7) | No VM, no tap yet | After the tap exists, per §13.7 |

Beyond the checklist, none of the windows (onboarding, Settings, the switcher, the overlays, the editor, the translation overlay) has been looked at on screen, and the XCUITest bundle is still a placeholder (Automation Mode needs an admin password). Before 1.0, walk through `docs/qa-checklists.md` (PLAN §14.6) on the installed app.

## Deviations from PLAN.md (amended in 2.3 where they change the plan)

- Package dependencies differ from §6.2: Recording gets its region from the app and does not link Capture; OrielTranslation and Upload use SharedUI. PrivateAPIs is Swift-only and loads no MultitouchSupport symbol, because the event tap's gesture events were enough.
- The CLI has two more Debug-only verbs, `debug record` and `debug perf-capture`, which exist for the Verify scripts.
- `perf-capture.sh` times from the capture request (fetching the shareable content) to the overlay being ordered in, the span of the existing signpost; the Carbon callback before it is not included.
- The gesture tests replay synthetic sequences instead of recorded ones (above).
- Google's Cloud Translation v3, which glossaries need, takes no API keys, so a Google provider with a glossary uses a service account key (PLAN 2.5, §7.7.2).
- Platform differences found along the way are rows in `docs/os-quirks.md`, among them Vision's language labels, Foundation Models' context size, the AVFoundation deprecations, GIF memory, LaunchServices picking a stale copy and TCC's one entry per bundle ID.

## Release 0.1.0

- Built from the commit tagged `v0.1.0` by `source scripts/apple-credentials.env && make release-dry-run`: the gate (lint, all tests, universal check), the archive (build number = commit count), the Developer ID export, then notarization of the app and of the disk image, each stapled. The tag's message lists the notarization submissions and the disk image's SHA-256.
- The §13.7 checks pass: `codesign --verify --deep --strict`; the only entitlements are `device.audio-input` and `device.camera`; both binaries carry both slices; `stapler validate` passes for the app and the dmg; `spctl` accepts both as *Notarized Developer ID*, signed by the team's Developer ID Application certificate (4XVYLW8RXS). The app signs as `com.codertapsu.oriel`, the CLI as `com.codertapsu.oriel.cli`, both with the hardened runtime.
- Nothing was published: the file host and the tap do not exist yet (PLAN §15).

## What you need to do

1. **Install and grant permissions.** Open `dist/Oriel-0.1.0.dmg`, drag Oriel to Applications, open it; the welcome window asks for Accessibility and Screen & System Audio Recording (quit and reopen after the second). Details in `docs/USER_GUIDE.md`.
2. **Replace the placeholders before 1.0:** `<ORG>` and `<FILEHOST>`.
3. **Renew the Developer ID Application certificate before 1 February 2027.** It expires then, together with the original Developer ID CA that issued it. Builds notarized before then keep working; new releases need the new certificate (Xcode → Settings → Accounts).
4. **For the Mac App Store** (`docs/APP_STORE.md`): this Oriel cannot pass review (Accessibility, private APIs, no sandbox); a separate sandboxed "Oriel Capture" edition could. That needs an App Store Connect record and the Apple Distribution and Mac Installer Distribution certificates, which this Mac does not have.
5. **Optional, for UI tests:** `sudo automationmodetool enable-automationmode-without-authentication`, then `ORIEL_UI_TESTS=1 make test`.

## Found in pre-release testing: the Accessibility grant that did not apply

- **Symptom.** With Oriel switched on in System Settings → Privacy & Security → Device Control and Data Access (macOS 27's name for Accessibility), Oriel still reported Accessibility as missing, and the window switcher never started.
- **Cause.** macOS keeps one Accessibility entry per bundle ID, holding the code requirement of the build that asked first. An Apple Development-signed Debug build had asked first under the same bundle ID, so the notarized Developer ID build failed the requirement: tccd logged `Failed to match existing code requirement for subject com.yourcompany.oriel and service kTCCServiceAccessibility`, and `AXIsProcessTrusted()` stayed false even after a relaunch. Screen Recording, camera and microphone, which the Developer ID build asked for first, worked.
- **Made worse by** permission state that refreshed only when Oriel was activated, which a menu-bar app rarely is when the user comes back from System Settings.
- **Fixed.** The release is `com.codertapsu.oriel`. Debug builds are `com.codertapsu.oriel.debug`, listed as "Oriel Debug", with their own permissions, settings and keychain items, and only one of the two runs at a time (CLAUDE.md rule 14). Permissions are re-read when any app comes to the front and when macOS posts `com.apple.accessibility.api`. The permission list names the pane for the running macOS and says to remove Oriel with − and add it again when its switch is on but not honoured.
- **Not verifiable here.** Only you can grant a permission. Settings → Permissions should turn green within a moment of switching Oriel on, without reopening Oriel (Screen Recording excepted: macOS asks to quit and reopen).

## Found in the pre-release audit: the parts of the plan that were missing

An audit of PLAN §1, §7, §10 and §15 against the code, requirement by requirement, found eight parts of the plan missing or not connected, a race in Move to Applications and no CI workflow. All of them are in 0.1.0:

| Planned | Now |
|---|---|
| A "live" toggle for video (§7.2 item 2) | Settings → Capture → **Freeze the screen while selecting**. Off, the overlay is see-through and hit-testable, has no loupe, and the pick is captured once the overlay has gone, from freshly fetched shareable content, so every window of Oriel's is left out. |
| Capture with Timer (§7.2 item 3) | The countdown and the Timer setting existed, but nothing started a timed capture. Now: status menu, a configurable shortcut, `oriel://capture/timer`, and `--delay <1–60>` on the CLI's capture verbs. Countdown first, then the area overlay, so a menu opened meanwhile is in the shot. |
| Record a window (Phase 7) | **Record Window**: pick a window on the overlay; the window's frame is recorded, keeping Oriel's click rings, keystrokes and camera bubble in the video. Menu, shortcut, `oriel://record/window`. |
| Pinned in the status menu (§10.1) | **Pinned** lists each pin with a thumbnail, to bring it to the front, and Close All Pins; dimmed while nothing is pinned. |
| Quick Look from the editor (§7.5) | ⌘Y or the eye in the action bar: the flattened image as a temporary PNG, removed when the panel lets go of the window or the window closes. |
| The switcher's display, configurable (§7.1.3) | Settings → Window Switcher → **Show on**: under the pointer (default), with the active window (from the cached list, no Accessibility call), or the main display. "Current screen" filters follow it. |
| Google v3 for glossaries (§7.7.2) | Google's v3 takes no API keys (its authentication page says so), so a Google provider with a glossary uses a service account key: an RS256 JWT exchanged for an OAuth token, cached until a minute before expiry, then `translateText` with `glossaryConfig`. Settings: Glossary field, Add Service Account Key… (Keychain). `bootstrap.json`: `glossary`, `serviceAccountKey`. Without a glossary nothing changes. |
| A warning for local models on Intel (§7.7.7, §11) | Settings → Translation flags an OpenAI-compatible endpoint on this Mac when the Mac has an Intel processor; the one-time Intel notice says it too. |
| Move to Applications (§15.6) | The moved copy was launched while the old one still ran, saw it, handed over and quit, and the old one then quit too. Now the old copy launches it with `--replacing <pid>`, starts nothing and quits; the moved copy waits for that process to end before it starts. |
| CI (§15.7) | `.github/workflows/ci.yml`: lint, Debug build, tests and the universal check with ad hoc signing (`XCODEBUILD_FLAGS` in the Makefile). The same commands passed here with ad hoc signing; the repository has no GitHub remote, so it has not run on GitHub. |

**Also fixed:** Release builds warned "weak reference will always be nil" at the timer's countdown. The Cancel button's target is a weak reference to the countdown, which nothing else held while it waited, so an optimized build could free it and Cancel would do nothing. The countdown now creates and holds itself for as long as it runs (`CountdownPanel.run(seconds:)`), and Release builds have no compiler warnings.

**Tests added:** live and frozen backdrops, the Pinned menu's titles and thumbnails, the CLI's `--delay` and its timeout, the new actions' URLs and shortcuts, Quick Look's preview file, the switcher's display choice, the handover arguments, the Intel warning, and for Google: PKCS #8 and PKCS #1 keys, key-file checks and redaction, the signed JWT (verified with the public key), token caching and renewal, a refused key, v3 requests with and without a known source language, glossary names, availability and Test Connection. Every RSA key is made during the test; none is checked in.

**Not verifiable here, and how to check** (also in `docs/qa-checklists.md`, "First look"):

| What | Why not | How |
|---|---|---|
| Everything on screen: the live overlay, the timer with a menu, Record Window's movie, the Pinned menu, Quick Look, the Show on setting, the new Settings controls | Needs a person at the Mac (and two displays for Show on) | First look, steps 2–14 |
| Google glossaries against Google | Needs a Cloud project, a glossary and a service account; the request shapes are checked against stubs and Google's documentation | First look, step 12 |
| The Intel warning on Intel | Needs an Intel Mac; the decision is unit-tested | Settings → Translation with an endpoint on `localhost` |
| Move to Applications from the disk image | The alert has to be answered | First look, step 2 |
| CI on GitHub | No GitHub remote; the runner image must have Xcode 27.1 (`ORIEL_CI_RUNNER` and `ORIEL_CI_XCODE` override the runner and the version) | Push to GitHub and open a pull request |

**Still open from the plan:** the Phase 0 spike trials S1–S7 and S9 (only S0 and S8 have write-ups; the others were folded into building the features, so their measured gates were never run); the §9 budgets beyond idle CPU and capture latency; the macOS 26 VM run, the 48-hour soak and a manual QA pass; the UI tests (Automation Mode); the tap and the file host (`<ORG>`, `<FILEHOST>`); and the ten checklist items in the table above.

## Review outcome

2026-10-29. You reviewed 0.1.0 and asked for two additions, Clipboard History and the automatic copy of every capture (`docs/reports/02-clipboard-history.md`), which ship in 0.1.0 too. After testing the installed build 26 you confirmed the seven checklist items that needed a person: in 13.1 the live permission state and Open at login, in 13.2 `oriel windows list`, focusing a window on another Space and ⌘⇥ coming back, in 13.5 offline English → Japanese, and 13.8 Clipboard History. This review closes the Phase 3 and Phase 6 checkpoints. The tests and measurements still open (the image-diff helper, recorded gestures, UI tests, the §9 budgets and the spike trials) wait until you have used 0.1.0 for a while.

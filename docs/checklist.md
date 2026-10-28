# Implementation and verification checklist

Conventions: run from the repo root; tick only when **Verify** passes; `make` targets are in Appendix C.

## 13.0 Global

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

## 13.1 Foundation
- [x] `project.yml`: app, CLI and test targets; `ARCHS = arm64 x86_64`; `MACOSX_DEPLOYMENT_TARGET = 26.0`; Swift 6 mode; strict concurrency. **Verify:** `xcodebuild -project Oriel.xcodeproj -scheme Oriel -configuration Release -showBuildSettings | grep -E ' ARCHS | MACOSX_DEPLOYMENT_TARGET | SWIFT_STRICT_CONCURRENCY | SWIFT_VERSION '` (Release, because Debug narrows `ARCHS` to the active architecture)
- [x] `Info.plist`: `LSUIElement`, `LSMinimumSystemVersion = 26.0`, mic/camera usage strings, `oriel` URL scheme. **Verify:** `plutil -lint App/Info.plist` and a unit test reading the built bundle.
- [x] `--self-test` loads every module, prints capability flags, exits 0. **Verify:** `build/Release/Oriel.app/Contents/MacOS/Oriel --self-test`
- [x] `PrivateAPIs` resolves symbols via `dlsym` and never crashes when one is missing. **Verify:** unit test with an injected resolver returning nil for each symbol.
- [ ] Permissions center reflects live state without timers. **Verify:** `rg "Timer\.scheduledTimer|DispatchSource\.makeTimerSource" Packages/Permissions` returns nothing; manual toggle test.
- [ ] Launch at login via `SMAppService`. **Verify:** `SMAppService.mainApp.status == .enabled` after toggling; visible in System Settings → Login Items.
- [x] Bootstrap import populates Settings and the Keychain and deletes the file. **Verify:** `--filter BootstrapImportTests`
- [x] Diagnostics shows arch, Rosetta, Apple Intelligence, packs, private symbols, permissions. **Verify:** `oriel debug capabilities --json` lists all six keys.
- [x] No dependencies. **Verify:** `rg -n "dependencies:" Packages/*/Package.swift` shows only local `path:` entries; `rg -n "url:" Packages/*/Package.swift` returns nothing.

## 13.2 Window switcher
- [x] `WindowStore` builds the list from AX + CGWindowList + SkyLight with a fake `WindowSource` in tests. **Verify:** `swift test --package-path Packages/WindowSwitcher --filter WindowStoreTests`
- [x] Filter, ordering, search and layout are pure functions with table tests. **Verify:** `--filter 'LayoutTests|SearchTests|FilterTests'`
- [x] State machine covers hold/release, keep-open, cancel, Sticky Keys. **Verify:** `--filter SwitcherStateMachineTests`
- [ ] `oriel windows list --json` matches the fixture set. **Verify:** `ORIEL_TCC_TESTS=1 scripts/verify-windows.sh`
- [ ] `oriel windows focus <id>` focuses the right window on another Space. **Verify:** the script reads the frontmost window via AX afterwards.
- [ ] Cmd-Tab takeover is restored after quit and after `kill -9`. **Verify:** `scripts/verify-cmdtab-restore.sh` (TCC)
- [x] Idle: 10 minutes at 0.0 % CPU. **Verify:** `scripts/idle-cpu.sh` (uses `top -l 600 -s 1 -pid $PID -stats cpu,idlew`)
- [ ] Reduce Transparency switches to opaque live. **Verify:** image-diff test with forced accessibility flags + manual.
- [x] Exceptions exclude apps by bundle ID. **Verify:** unit test.
- [ ] Gesture recognizer rejects four-finger and two-finger sequences. **Verify:** unit test on recorded sequences in `Tests/Fixtures/gestures/`.
- [x] `ShortcutRecorderView` rejects reserved combos and flags conflicts. **Verify:** `--filter ShortcutRecorderTests`
- [x] Carbon engine registers/unregisters and fires. **Verify:** `swift test --package-path Packages/Hotkeys --filter CarbonHotkeyEngineTests`

## 13.3 Capture
- [x] `ScreenGeometry` conversions correct for multi-display, mixed-scale layouts. **Verify:** `--filter ScreenGeometryTests`
- [x] Area capture pixel dimensions = selection × scale. **Verify:** `oriel capture area --rect 100,100,400,300 --to file --path /tmp/a.png && sips -g pixelWidth -g pixelHeight /tmp/a.png` (TCC)
- [ ] Window capture excludes our overlays. **Verify:** image-diff test (TCC).
- [x] Hotkey → overlay p95 < 120 ms. **Verify:** `scripts/perf-capture.sh` (signposts).
- [x] Stitcher output correct on synthetic sequences (sticky header, repeated rows, end detection). **Verify:** `swift test --package-path Packages/Capture --filter StitcherTests`

## 13.4 Editor
- [x] Every tool creates/edits/deletes items; undo/redo restores exact documents. **Verify:** `--filter EditorDocumentTests`
- [x] Renderer output stable at 1× and 2×. **Verify:** image-diff tests.
- [x] PNG/JPEG/HEIC/PDF export round-trips (UTType and dimensions). **Verify:** `--filter ExportTests`

## 13.5 Translation
- [x] Each provider tested with `URLProtocol` stubs (request shape, headers, streaming parse, error mapping). **Verify:** `swift test --package-path Packages/OrielTranslation`
- [x] Segment JSON contract tolerates extra prose and missing ids. **Verify:** `--filter SegmentParserTests`
- [x] Keychain round-trip; keys never logged. **Verify:** unit test + `rg -n "apiKey" Packages | rg -v Keychain` review.
- [x] Apple provider availability states map to UI. **Verify:** unit test with a fake availability adapter.
- [x] Font fitting never overflows at ≥ minimum size. **Verify:** `--filter FontFitTests`
- [ ] Offline EN→JA works with packs installed and Wi-Fi off. **Verify:** `oriel translate area --rect … --to ja --provider apple --json` (TCC, manual).

## 13.6 Recording
- [x] 10 s recording has duration ±0.2 s and the audio tracks enabled. **Verify:** `scripts/verify-recording.sh` (TCC)
- [x] Pause-by-segment yields one playable file. **Verify:** `scripts/verify-recording.sh --pause` (TCC)
- [x] GIF frame count and width limits. **Verify:** unit test on a generated asset.

## 13.7 Release
- [x] Notarized, stapled DMG. **Verify:**
```bash
codesign --verify --deep --strict --verbose=2 dist/Oriel.app
codesign -d --entitlements :- dist/Oriel.app            # only device.audio-input and device.camera; no app-sandbox
lipo -archs dist/Oriel.app/Contents/MacOS/Oriel         # x86_64 arm64
lipo -archs dist/Oriel.app/Contents/Helpers/oriel      # x86_64 arm64
xcrun stapler validate "dist/Oriel-${VERSION}.dmg"
spctl -a -t open --context context:primary-signature -vv "dist/Oriel-${VERSION}.dmg"
```
- [ ] Installs through the tap on a clean macOS 26 VM with no Gatekeeper prompt. **Verify:** manual, recorded in `docs/qa-checklists.md`.

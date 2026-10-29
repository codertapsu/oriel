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
- [x] Permissions center reflects live state without timers. **Verify:** `rg "Timer\.scheduledTimer|DispatchSource\.makeTimerSource" Packages/Permissions` returns nothing; manual toggle test. Checked by you on the installed 0.1.0 (build 26), 2026-10-29.
- [x] Launch at login via `SMAppService`. **Verify:** `SMAppService.mainApp.status == .enabled` after toggling; visible in System Settings → Login Items. Checked by you on the installed 0.1.0 (build 26), 2026-10-29.
- [x] Bootstrap import populates Settings and the Keychain and deletes the file. **Verify:** `--filter BootstrapImportTests`
- [x] Diagnostics shows arch, Rosetta, Apple Intelligence, packs, private symbols, permissions. **Verify:** `oriel debug capabilities --json` lists all six keys.
- [x] No dependencies. **Verify:** `rg -n "dependencies:" Packages/*/Package.swift` shows only local `path:` entries; `rg -n "url:" Packages/*/Package.swift` returns nothing.

## 13.2 Window switcher
- [x] `WindowStore` builds the list from AX + CGWindowList + SkyLight with a fake `WindowSource` in tests. **Verify:** `swift test --package-path Packages/WindowSwitcher --filter WindowStoreTests`
- [x] Filter, ordering, search and layout are pure functions with table tests. **Verify:** `--filter 'LayoutTests|SearchTests|FilterTests'`
- [x] State machine covers hold/release, keep-open, cancel, Sticky Keys. **Verify:** `--filter SwitcherStateMachineTests`
- [x] `oriel windows list --json` matches the fixture set. **Verify:** `ORIEL_TCC_TESTS=1 scripts/verify-windows.sh` Checked by you on the installed 0.1.0 (build 26), 2026-10-29.
- [x] `oriel windows focus <id>` focuses the right window on another Space. **Verify:** the script reads the frontmost window via AX afterwards. Checked by you on the installed 0.1.0 (build 26), 2026-10-29.
- [x] Cmd-Tab takeover is restored after quit and after `kill -9`. **Verify:** `scripts/verify-cmdtab-restore.sh` (TCC) Checked by you on the installed 0.1.0 (build 26), 2026-10-29.
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
- [x] Offline EN→JA works with packs installed and Wi-Fi off. **Verify:** `oriel translate area --rect … --to ja --provider apple --json` (TCC, manual). Checked by you on the installed 0.1.0 (build 26), 2026-10-29.

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

## 13.8 Clipboard History
- [x] Classification, colors, the index (repeat copies, pins, reordering, Undo, limits), search, paste composition and the panel model are pure and tested. **Verify:** `swift test --package-path Packages/ClipboardHistory`
- [x] The store is encrypted at rest, survives a restart and sets an unreadable history aside. **Verify:** `swift test --package-path Packages/ClipboardHistory --filter ClipboardStoreTests`
- [x] No polling and no concealed reads. **Verify:** `make lint` (the `no_polling` rule covers the package); `swift test --package-path Packages/ClipboardHistory --filter 'PasteboardWatcherTests|PasteboardReaderTests'`
- [x] Copies in other apps appear once Paste from Other Apps allows it; ⌥V opens the panel over the app in front; Return pastes into VS Code, Chrome and Messages. **Verify:** manual (`docs/qa-checklists.md`), with Accessibility and Paste from Other Apps. Checked by you on the installed 0.1.0 (build 26), 2026-10-29.

## 13.9 Commands, settings sync and App Intents
- [x] Tools and features declare commands; the app registers their shortcuts, menu items, URLs and Settings → Shortcuts rows, a tool's only while it is on; no two actions or commands share an id, a default shortcut or a route. **Verify:** `make test` (`ModuleRegistryCommandTests`, `AppActionTests`, `AllCommandsTests`); `swift test --package-path Packages/OrielCore --filter ToolCommandTests`
- [x] Clipboard History's ⌥V and `oriel://clipboard` survive the move to a command. **Verify:** `swift test --package-path Packages/ClipboardHistory --filter ClipboardHistoryModuleTests`
- [x] Settings sync: the policy, the merge rule and a two-Mac round trip through an in-memory store. **Verify:** `swift test --package-path Packages/OrielCore --filter SettingsSyncTests`; `make test` (`SettingsSyncServiceTests`)
- [ ] Settings sync between two real Macs through iCloud Drive. **Verify:** manual (`docs/qa-checklists.md`).
- [x] App Intents are in the app's metadata (5 intents, 2 entities, 4 App Shortcuts). **Verify:** `Metadata.appintents/extract.actionsdata` after `make build`.
- [ ] The intents run from the Shortcuts app and Spotlight. **Verify:** manual (`docs/qa-checklists.md`).

## 13.10 Switcher presets
- [x] Presets set and read the filters and grouping; grouping, groups and the first selection are pure functions. **Verify:** `swift test --package-path Packages/WindowSwitcher --filter 'PresetTests|GroupingTests'`
- [x] Shortcuts saved before presets load with the preset they amount to. **Verify:** `--filter PresetTests`
- [x] Header bands, header rows and the hint line in the auto-size. **Verify:** `--filter GroupedLayoutTests`
- [x] ⌘/⌥/⌃+Q quits the selected item's app, also grouped and in app icons; plain Q searches. **Verify:** `--filter GroupingTests`
- [x] The model work of opening stays under 10 ms p95 with 200 windows in the debug build, for every preset. **Verify:** `--filter OpeningCostTests`
- [ ] Hotkey → first frame p95 < 50 ms with a grouped shortcut on the installed app. **Verify:** Instruments (Time Profiler, the switcher's signposts) with 60+ windows.

## 13.11 Capture additions
- [x] History indexing reads new and older captures once in the background, tall captures in tiles, and search shows why an entry matched. **Verify:** `swift test --package-path Packages/Capture --filter 'HistorySearchTests|HistoryStoreTests'`
- [x] Pin opacity, zoom, click-through and its ways back, lock and border are pure and tested, and the Pinned menu offers Stop Click-Through on All Pins. **Verify:** `--filter 'PinStateTests|PinsMenuTests'`
- [ ] A click-through pin takes clicks again with ⌥⌘ held over it, from its corner button and from the Pinned menu. **Verify:** manual (`docs/qa-checklists.md`), with and without Accessibility.
- [x] The desktop icons and widgets are picked by owner and layer, and the wallpaper stays. **Verify:** `--filter DesktopClutterTests`
- [ ] With Hide desktop icons and widgets on, Capture Area and Capture Screen show the wallpaper without icons or widgets, and Finder's settings are unchanged (`defaults read com.apple.finder CreateDesktop` as before). **Verify:** manual (TCC).
- [x] Capture Text keeps line breaks and reading order (columns, tables, right-to-left rows), joins hyphenated words by the dictionary, and the command, CLI arguments and JSON report are as specified. **Verify:** `--filter 'TextLayoutTests|TextPreviewTests|CaptureTextTests'`
- [ ] `oriel capture text --rect 100,100,400,300 --json` prints the text and each line in points. **Verify:** run on the installed app with Screen Recording granted (TCC).
- [x] The Step Capture state machine, reordering, undo merging and every exporter (PNG size, PDF pages, text and bookmarks, Markdown links and files, HTML with embedded images) are tested in temporary directories. **Verify:** `--filter 'StepSessionTests|StepExportTests|StepImageTests'`
- [ ] A session with a click marker, Finish, reorder, retake, annotate and drop back, and the four exports. **Verify:** manual (`docs/qa-checklists.md`).
- [x] No timers and no new dependencies. **Verify:** `make lint` (the `no_polling` rule); `rg -n "url:" Packages/*/Package.swift` returns nothing.

## 13.12 Editor additions
- [x] Instant Capture's panel covers the selection on the right display and its toolbar stays on screen (below, above, inside; negative origins, mixed scales, pixel grid). **Verify:** `swift test --package-path Packages/Editor --filter InstantPlacementTests`
- [x] Instant Capture's keys pick only its tools, Esc ends a drag before closing, Open in Editor hands over the session with its history. **Verify:** `--filter InstantCaptureTests`
- [ ] Instant Capture appears right after the selection, 1:1 over it, and Copy, Save, Upload, Open in Editor and Esc work on screen. **Verify:** manual (`docs/qa-checklists.md`).
- [x] Every background preset pads the image; aspects grow one side only; alignment places the card; inset and frame grow the card; social sizes export at exactly their pixels. **Verify:** `--filter BackgroundLayoutTests`
- [x] Radial gradients, inset edge colour, window frame, pictures with blur, shadow settings and tone-down render; background commands are one undo step each; saved backgrounds keep their picture; previews are cached. **Verify:** `--filter BackgroundRenderingTests`
- [x] Steps: letters and Roman labels, sequences that restart or continue, renumbering per sequence, styles on the selection, pointers and their tip, nudging. **Verify:** `--filter StepTests`
- [x] Smart Redact finds every category and none of the look-alikes, merges neighbours, hides a PEM block, applies as one undo step, reads the text once. **Verify:** `--filter RedactionTests`
- [x] Smart Redact's boxes cover the matched text in the system font, Helvetica and Menlo. **Verify:** `--filter TextSpanCoverageTests`
- [x] Hole fill: flat backgrounds exact, gradients within one level, edge holes, no streaks. **Verify:** `--filter HoleFillerTests`
- [x] Simplify's bars, ink colours, masks, line grouping; Smart Move lifts, moves and deletes without leaving copies. **Verify:** `--filter 'TextAndMaskTests|SmartMoveTests'`
- [x] `.oriel` version 2 round-trips every kind and its images; version 1 documents open and look the same. **Verify:** `--filter OrielBundleTests`
- [ ] Smart Redact, Simplify and Smart Move on real screenshots with Vision OCR. **Verify:** manual (`docs/qa-checklists.md`).

## 13.13 Recording and the video editor
- [x] The click sidecar's format (versioned, refuses newer versions, drops invalid clicks) and the click log's normalization and segment timeline are pure and tested. **Verify:** `swift test --package-path Packages/Recording --filter 'ClickSidecarTests|ClickLogTests'`
- [x] Auto Zoom: merging, panning only outside the view's middle, easing, focus clamping, the movie's ends; the zoom plan and the transform math for several output sizes. **Verify:** `--filter 'AutoZoomTests|ZoomSegmentTests|ZoomTransformTests'`
- [x] Chapters: list building, YouTube timestamps, and a chapter track written to MP4 and MOV and read back with AVAsset's chapter metadata groups. **Verify:** `--filter 'ChapterListTests|EditedMovieExportTests'`; `ffprobe -show_chapters` on an export lists the chapters. Checked with ffprobe on 2026-10-30.
- [x] Export on synthetic movies: trim (duration), MP4/H.264 and MOV/HEVC at 720p (size, codec, container), zoom pixels and frames across a still screen, sound mixed to one stereo AAC track, a trimmed zoomed GIF, progress, replacing a file but never the source, cancelling leaves nothing behind. **Verify:** `--filter EditedMovieExportTests`
- [x] Copy Text from Frame reads the frame at the exact time (a fake recognizer names the frame's colour). **Verify:** `--filter FrameReaderTests`
- [x] The editor's model: trim rules, chapters, zoom moves and resizes, undo/redo and coalescing, unexported changes, the keyboard map, the timeline's zoom and scroll, J/K/L. **Verify:** `--filter 'VideoEditTests|VideoEditorSessionTests|VideoEditorShortcutsTests|TimelineMappingTests|ShuttleTests|TimecodeTests'`
- [x] The camera background effect on synthetic frames (replace, blur, mirror, mask), its gate and its governor. **Verify:** `--filter 'CameraBackgroundTests|CameraBackgroundRendererTests'`
- [x] No polling. **Verify:** `make lint` (the `no_polling` rule covers the package)
- [ ] A real recording's clicks land in its sidecar within 0.1 s of where the video shows them, and Auto Zoom follows them. **Verify:** manual (`docs/qa-checklists.md`), with Screen Recording.
- [ ] Blur camera background keeps a 1080p30 recording with the bubble under budget on Apple silicon and turns off under load. **Verify:** manual, Activity Monitor or `top -pid <Oriel>` during a recording with the bubble, with Camera.
- [ ] QuickTime Player and IINA show an exported movie's chapters. **Verify:** manual.

## 13.14 Translation additions
- [x] Translate Under Cursor: debounce, dedupe, cache, dismissal and abandoned reads are a pure state machine tested on a clock the test sets. **Verify:** `swift test --package-path Packages/OrielTranslation --filter CursorRestMachineTests`
- [x] The line or paragraph under a point is chosen from OCR boxes; cut-off text is read again from a larger area; the tooltip stays on screen. **Verify:** `--filter 'CursorTextPickerTests|CursorGeometryTests'`
- [x] The mode end to end with a pretend screen, OCR and provider: one capture per rest, one translation per text, no reads after Stop, losing Screen Recording stops it. **Verify:** `--filter CursorTranslationControllerTests`
- [x] Without Screen Recording the mode explains and does not start; commands have their ids, ⌃⇧U and routes. **Verify:** `--filter TranslationCommandTests`
- [x] File-type routing, segmenting (text, Markdown, HTML, rich text), subtitle parsing and writing, chunking and exports. **Verify:** `--filter 'DocumentKindTests|SegmenterTests|SubtitleFileTests|DocumentChunkerTests|DocumentExporterTests|SegmentPresentationTests'`
- [x] Real files are read: Latin-1 text, Markdown, WebVTT, RTF, DOCX, PNG with OCR, a PDF with a text page and a scanned page. **Verify:** `--filter DocumentReaderTests`
- [x] File jobs: chunks within provider limits, a failure partway keeps results and Resume sends only what is missing, a stop during reading is resumed, images get their overlay, subtitles keep timing, the glossary reaches every chunk. **Verify:** `--filter FileTranslationTests`
- [x] Glossary matching, placeholder round trip with mangled tokens and raw fallback, CSV/TSV import and export, pair rules and persistence with migration. **Verify:** `--filter 'GlossaryMatcherTests|GlossaryProtectionTests|GlossaryCSVTests|GlossaryLibraryTests'`
- [x] Provider glossaries with stubbed requests: DeepL create, reuse, replace, re-create and unsupported pairs; Google project glossary on v3 and the fallback to Basic; Apple tokens; prompts with only the terms that occur. **Verify:** `--filter 'DeepLGlossaryTests|ProviderGlossaryTests|SegmentPromptTests'`
- [ ] Translate Under Cursor on real text in Safari, Preview and a full-screen app; the badge; Esc with Accessibility. **Verify:** manual (`docs/qa-checklists.md`), with Screen Recording.
- [ ] A text PDF, a scanned PDF, a .docx and an .srt translate and export; the SRT plays in QuickTime with the original timing. **Verify:** manual (`docs/qa-checklists.md`).
- [ ] DeepL creates the glossary in the account and the translation uses it; a Google Cloud glossary named in a project is used. **Verify:** manual, with DeepL and Google keys.

## 13.15 Upload destinations
- [x] Request building for every destination: WebDAV `PUT`/`MKCOL`/`PROPFIND`, Dropbox upload, session and shared-link calls with `Dropbox-API-Arg` escaping, Google multipart and resumable bodies, S3 `PUT` with its payload hash. **Verify:** `swift test --package-path Packages/Upload --filter 'WebDAVTests|DropboxTests|GoogleDriveTests|S3DestinationTests'`
- [x] PKCE matches RFC 7636 appendix B; authorization URLs, code exchange, refresh (once at a time, kept, forgotten on `invalid_grant`), revocation and callback parsing. **Verify:** `--filter 'PKCETests|OAuthTests|TokenRefreshTests'`
- [x] sftp batch generation with quoting, refused paths and options, the command line, and stderr → errors; uploads and tests through a fake runner. **Verify:** `--filter SFTPTests`
- [x] Name templates, URL templates and link formats. **Verify:** `--filter 'UploadNameTemplateTests|UploadLinkTemplateTests'`
- [x] Destinations survive a round trip, tolerate missing fields and unknown kinds; the 0.1 S3 setting and secret become the default destination once, and a bootstrap import updates it. **Verify:** `--filter UploadDestinationStoreTests`
- [x] Shared folder: whole copies, numbered names, no partial files, refusals, and the bookmark after a rename. **Verify:** `--filter SharedFolderTests`
- [x] Image files lose GPS, EXIF and TIFF metadata but keep their orientation; captures are fresh PNGs. **Verify:** `--filter PayloadPreparerTests`
- [x] No timers and no dependencies. **Verify:** `make lint`; `rg -n "url:" Packages/Upload/Package.swift` returns nothing.
- [ ] An upload to each kind of destination works and copies the link; Cancel stops it; errors read well. **Verify:** manual (`docs/qa-checklists.md`), with real accounts and servers.
- [ ] Dropbox signs in with `db-<app key>://2/token` without a registered redirect URI; Google with an iOS client and its reversed client ID. **Verify:** manual, with a Dropbox app and a Google Cloud client.

## 13.16 Disk Space Analyzer
- [x] Aggregation of smaller files, hard-link dedupe, clones, purgeable and cloud-only files, exclusions, hidden files, volume crossing, the compact tree (totals, paths, firmlinks, edits, compaction, search). **Verify:** `swift test --package-path Packages/DiskAnalyzer --filter 'DirectoryDigestTests|ScanTreeTests'`
- [x] The scanner on temporary folders: nested folders, hard links, symbolic links, an unreadable folder (`chmod 000`), cancellation, progress, a refresh after a change, and both readers giving the same tree. **Verify:** `--filter ScanEngineTests`
- [x] The squarified treemap and the sunburst angles, hit testing and merging. **Verify:** `--filter 'TreemapLayoutTests|SunburstLayoutTests'`
- [x] Filters and sorting, duplicate grouping and selection, and the protected-path rules. **Verify:** `--filter 'FileFilterTests|DuplicateGrouperTests|SafetyRulesTests'`
- [x] The purgeable math, the startup volume's accounting, CSV export, snapshots and their diffs, the `tmutil` output parser and the administrator command's quoting. **Verify:** `--filter 'VolumeUsageTests|ExportAndHistoryTests|SystemTextTests'`
- [x] Copies with progress and free names, moves on one volume and through copy-check-remove, Trash and Undo (with a Trash of the test's own), deleting a link, refusals, per-item failures and cancel. **Verify:** `--filter FileOperatorTests`
- [x] The FSEvents stream reports a change made by another process; the duplicate finder, clone facts, space hogs (in a home folder of the test's own) and volume crossing on real files. **Verify:** `--filter 'ScanWatcherTests|SystemHelperTests'`
- [x] The commands, the CLI verbs and their parsing, the snapshot store, and the window's model (plans, navigation, search, renumbered trees). **Verify:** `--filter 'DiskAnalyzerModuleTests|HistoryAndCommandLineTests|AnalyzerModelTests'`; `swift test --package-path Packages/IPC --filter CommandParserTests`
- [x] No polling. **Verify:** `make lint` (the `no_polling` rule covers the package)
- [ ] A scan of Macintosh HD adds up to Finder's used space with "macOS (system)"; the permission prompts appear once with Oriel's texts; Full Disk Access removes the unreadable-folders note; Move to Trash, Undo, Delete Immediately, a move to an external drive, Eject, Remove Download, Remove Snapshots and `oriel disk scan ~/Downloads` work on the installed app. **Verify:** manual (`docs/qa-checklists.md`).

## 13.17 Activity Monitor
- [x] CPU % from tick and time deltas (wrap, resets, reused pids, mixed readers), the memory breakdown, the ps and nettop parsers (names with spaces, dots and commas; header-ordered columns), IOKit and sysctl dictionaries, the process tree and helper grouping, filters, search and sorting, the signal safety rules, the ring buffer and heavy-use detection are pure and tested. **Verify:** `swift test --package-path Packages/ActivityMonitor`
- [x] Sampling happens only in `SamplingSession` and stops with it; nothing keeps running. **Verify:** `make lint` (the `no_polling` rule covers the package); `swift test --package-path Packages/ActivityMonitor --filter theSessionSamplesUntilItIsStopped`
- [x] A sample costs well under 1 % of a core at 2 s. **Verify:** `swift test --package-path Packages/ActivityMonitor --filter aSampleIsCheap` (under 20 ms of CPU per sample, `ps` included; release-build figures in §9)
- [x] Signals reach only the process the user confirmed; protected pids are refused; children are stopped on timeout and cancellation. **Verify:** `--filter 'SignalPolicyTests|ChildProcessTests'`
- [x] `oriel top` parses and answers usage errors. **Verify:** `swift test --package-path Packages/IPC --filter CommandParserTests`; `swift test --package-path Packages/ActivityMonitor --filter ActivityMonitorModuleTests`
- [ ] The window opens from the menu bar and `oriel://activity`; tabs, views, search, sorting, the details, Quit, Force Quit, Send Signal, quitting as an administrator, Sample Process, Reveal and Copy work on the installed app. **Verify:** manual (`docs/qa-checklists.md`).
- [ ] `oriel top --sort network --json` answers through the installed CLI. **Verify:** manual.

## 13.18 Color Picker
- [x] Color conversions (sRGB ↔ HSL, HSB, CMYK, OKLCH, Display P3), every format and its parsing, WCAG 2.2 ratios and thresholds, APCA, the library (history cap, palettes), persistence and migration, and palette export are pure and tested. **Verify:** `swift test --package-path Packages/ColorPicker`
- [x] The panel's number keys, ⌘C, tabs, drops, typed colors and Undo. **Verify:** `--filter ColorPanelControllerTests`
- [x] No polling, and no required permission. **Verify:** `make lint` (the `no_polling` rule); `--filter ColorPickerModuleTests`
- [ ] ⌃⇧C picks the clicked color, copies it and opens the panel. **Verify:** manual (`docs/qa-checklists.md`).

## 13.19 Screen Ruler
- [x] Edge finding (solid blocks, gradients, noise, Retina), fitting, snapping, units and formatting, multi-display coordinates, the area editor, guides, the keymap and the session's state machine are pure and tested. **Verify:** `swift test --package-path Packages/ScreenRuler`
- [x] No polling, and no required permission. **Verify:** `make lint` (the `no_polling` rule); `--filter ScreenRulerModuleTests`
- [ ] The screen is captured at its pixel size without Oriel's windows. **Verify:** `ORIEL_TCC_TESTS=1 swift test --package-path Packages/ScreenRuler --filter theScreenIsCapturedAtItsPixelSize` (TCC, dev Mac)
- [ ] ⌃⇧M measures on two displays of different scales; Dimensions finds edges with Screen Recording and explains itself without it. **Verify:** manual (`docs/qa-checklists.md`).

## 13.20 Window Tiling
- [x] Every layout's frame on the built-in display, and on every arrangement (left of, right of, above and below the main display, portrait, an odd width, the Dock bottom, left and right) inside the visible frame, on whole points, with neighbours meeting exactly and the gap honoured. **Verify:** `swift test --package-path Packages/WindowTiling --filter 'TileLayoutTests|DisplayGeometryTests'`
- [x] Cycling, display order and moves, size steps and restore plans. **Verify:** `--filter TilingPlannerTests`
- [x] Minimum and maximum sizes, snapping and windows larger than the screen keep the layout's edge and stay on screen. **Verify:** `--filter 'TileFittingTests|WindowArrangerTests'`
- [x] Restore bookkeeping: runs, moves by hand, LRU. **Verify:** `--filter TileHistoryTests`
- [x] The AX sequence (size, position, size again, read back, line up), skipped windows and `AXEnhancedUserInterface`, against simulated windows. **Verify:** `--filter WindowArrangerTests`
- [x] Commands have the assigned ids and defaults, unique, out of the menu list; the menu shows them with key equivalents; feedback per outcome; no permission → notice. **Verify:** `--filter 'TilingCommandsTests|WindowTilingModuleTests'`
- [x] No timers and no AX outside the AX actor. **Verify:** `rg -n "Timer|DispatchSource" Packages/WindowTiling/Sources` returns nothing; `rg -ln "AXUIElement(Copy|Set|Perform|IsAttribute)" Packages/WindowTiling/Sources` lists only `System/AXWindowAccess.swift`.
- [ ] Reads the front app's focused window for real. **Verify:** `ORIEL_TCC_TESTS=1 swift test --package-path Packages/WindowTiling --filter SystemAccessTests` (read-only)
- [ ] Tiles real windows on the installed app. **Verify:** manual (`docs/qa-checklists.md`).

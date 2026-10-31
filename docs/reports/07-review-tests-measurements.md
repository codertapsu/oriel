# 07 — Review, headless tests, measurements and the remaining items (release 0.1.0)

2026-10-31 · macOS 27.0.1 (26A434) · Xcode 27.1 · the three items deferred until you had installed build 71: a fresh-eyes review of the recent code, the headless half of the tests and measurements, and read-only numbers from the Oriel you are using. Then, after your answer (QA item 39 is right), every item the review left, the design changes included, and build 109. Then, after you installed it, the idle measurements of a freshly started Oriel, the last items, and a fresh build 112. Then, after you checked build 112, the Full Disk Access note, the Dock icon you asked for, and a fresh build 114.

## Result

- **Review:** three reviewers each read one area from scratch: the Dock (9 findings), Clean Up (8, plus 4 minor ones), and the earlier own-window, helper, scan and launch work (7). Every finding was checked again before anything changed. All 24 are now dealt with: 20 at once, with the 4 minor ones, and the 4 that needed design changes or your answer after it. The fixes are in 28 commits with tests.
  - **Security, the most serious:** any process running as you could make the root helper list any folder, with sizes and dates, through `oriel disk scan`. So could another account's Oriel on this Mac, or a debuggable build signed by your team. Now the CLI never uses the helper, the helper answers administrators only, and a release accepts only Developer ID builds closed to debuggers.
  - **Clean Up could recommend removing what may be yours:** "older versions" of dated folders in Downloads or Pictures, or of `~/.pyenv/versions`; cache-named folders inside a project's libraries; and a whole project with a virtual environment in its root. Under "Keep it" it could also put a removal first, and `~/Desktop/temp` was "Safe". Now nothing like that is recommended, and under "Look before you remove it" and "Keep it" the recommended choice only shows the folder.
- **Tests:** an image-diff helper, the switcher's Reduce Transparency test, timing tests against the plan's budgets, a gesture recorder, UI tests and a Screen Recording test. The glass test found a bug, fixed: the opaque fallback kept its light or dark color when the appearance changed while a panel existed.
- **Measurements:** within budget except memory, which turned out to be the allocator's, not Oriel's (below).
- **The remaining items, after your answer:**
  - **Done:** QA item 39 is ticked. Hard links, Other space and File Types after an edit are fixed, three design changes. Settings no longer opens over an intent that launches Oriel, and the Dock's last cases are handled.
  - **The memory:** looked into; no leak.
  - **The two timing tests still to write:** one found OCR of a dense page six times slower than it needs to be, now fixed.
- **Idle, after you installed build 109:** 55 MB, 0.016 % of a core and 0.36 wake-ups a second, every idle budget met (below).
- **After you checked build 112:** items 45–47 are ticked. With Full Disk Access, Disk Space Analyzer's notes no longer ask for it. Oriel is in the Dock while one of its windows is open, and goes back to the menu bar when the last one closes. ⌘Q and the Dock's Quit close its windows, and only Quit Oriel in the menu-bar menu quits it (below).
- **Build 114:** `dist/Oriel-0.1.0.dmg`, from the moved `v0.1.0` tag, notarized and stapled. The tag message holds its SHA-256 and notarization IDs.
- **Checks:** `make lint test universal-check` passes.
  - 1,843 tests: 39 app tests and 1,804 in the 19 packages, 11 of them new since build 112 and 100 since build 71.
  - Recording's export tests stalled once, in the first run for build 114: every thread waited on AVFoundation for half an hour. Run again, all 204 passed in 3 seconds.
  - No compiler warnings; SwiftLint `--strict` and SwiftFormat are clean.
  - Both slices build, and `--self-test` passes natively and under Rosetta.

## Measurements

Against PLAN §9. The timing tests run off screen in the unoptimized test build; your Oriel was sampled from outside every 30 s (`proc_pid_rusage`, `footprint` every 10 minutes) from 16:24 to 17:36, while you used it.

| Budget | Target | Measured | How |
|---|---|---|---|
| Idle CPU, 10 min | 0.0 % | 0.009–0.039 % in quiet stretches (rounds to 0.0); 0.12–0.15 % with light use; 4.4 % in the 10 minutes you used it hard | sampling |
| Idle wake-ups | < 1/s | 0.33–0.40/s quiet: one every 3 s, about 0.1 ms of CPU each, source not traced; 0.8/s with light use | sampling |
| Idle footprint | < 60 MB | **102 MB** with only Settings open (the session had peaked at 245 MB), then **202 MB** with no window open after a burst of use that peaked at 654 MB | `footprint` |
| OCR, 1,000 × 600 px | < 400 ms | 140 ms median in both modes; the first request, which loads Vision's models, 285–299 ms | `RecognitionBudgetTests` |
| Selection change → redraw | < 8 ms | 0.23 ms median, 0.31 ms p95, with 60 or 200 tiles: highlights, AppKit's display pass, the commit and drawing the two tiles | `RedrawBudgetTests` |
| Thumbnail cache | ≤ 48 MB | 47 MB through 20 sessions of 150 windows; the images still in memory are exactly the cache's | `ThumbnailChurnTests` |
| Apple Translation, 1,500 characters | < 1 s | not measured: no language pack from English is installed on this Mac | `AppleTranslationBudgetTests`, skipped |
| OCR grouping, 500 lines | a small part of OCR's 400 ms | **320 ms**, most of the budget, optimized or not, before this work; 50–60 ms now | `GroupingBudgetTests` |
| Stitching, per frame | well under the 250 ms a scroll step waits | 1.9 ms optimized, as the app is built; 220–230 ms in the unoptimized test build | `StitchingBudgetTests` |

For comparison over the same 30 s, idle apps woke 0–53 times: Finder 53, ControlCenter 33, Oriel 10, and most system agents none. Energy stayed at 0–1.4 mW.

The memory, looked into after your answer without touching your Oriel:
- **Nothing in Oriel keeps the scan.** Disk Space Analyzer's window, built off screen with a scan, gone through every view and closed, frees its controller, its window and its views, and the model drops the tree (`WindowLifecycleTests`, now a regression test).
- **The allocator keeps freed memory.** A 414,000-node tree dropped in a test process gives its arrays back at once, but about a third of its small blocks stay with the allocator. It reuses them for the next tree and keeps them even through `malloc_zone_pressure_relief`. macOS compresses them while they are cold.
- **So the 202 MB is mostly memory the allocator keeps, not data Oriel holds.** The 60 MB budget is for a freshly started Oriel left alone, which installing the new build gives you. I can sample it then.

## Review: what was fixed

| Area | Fixed |
|---|---|
| Helper (security) | `oriel disk scan` no longer reaches the helper. The helper accepts only clients whose effective user is an administrator (`mbr_check_membership`); for any other account Oriel shows it as unavailable, so a standard user's Oriel never registers, uses or removes the Mac-wide daemon. A Developer ID build also requires the other end to be signed with Developer ID and have no `get-task-allow`: the plain Release build in `build/` now fails the requirement, and the notarized one passes. Debug keeps its own identity and helper (rule 14). |
| Helper (behaviour) | The window asks macOS for the helper's state before every read and before re-registering, and Settings tells it when it installs or removes the helper, so Remove Helper is no longer undone. A read that runs out of time is not sent again. The helper reads on its own thread and stops when Oriel hangs up, and re-registering waits for the asynchronous unregister. A refresh keeps what was read as an administrator and recounts the closed folders. |
| Clean Up | Older versions are offered only for tools that keep a folder per version (Gradle, JetBrains' caches, and a new rule for the IDEs' settings). Leftovers go after the folder's own methods, and under "Look before you remove it" and "Keep it", including raised caution such as cloud storage, the first choice only shows the folder. Never offered: caches inside folders of code or in a project with a repository, an app's or a library's contents on their own, or what the scan left out or could not read. Your own folders are judged before names. `/tmp` and `/var/tmp` are kept. A Python environment matches only by its bare layout, and repositories are a tool's own only where its rule matched by path. Repositories are found in worktrees and in scans without hidden files. Every file a process has open counts (no cap of 200), through symbolic links too, and the check runs again after the confirmation. The folder is looked up in the scan only then. A newer check replaces an older one's scan and results. A folder that is gone says so. A single item is named in the confirmation. Space Hogs re-measures after the tree's edits. |
| Dock | Copies of one app (Xcode and Xcode-beta, a copy on a disk image) are told apart by their bundles, compared as files, and an icon whose copy is not running shows nothing. The preview stays on a magnified icon. Space changes re-read the Dock, and a read of a hidden or sliding Dock keeps the last good layout. A short re-read no longer cuts the icons' settle short. A Dock that restarts is asked again once it has finished launching, and a reader that has stopped never starts again. Children get the 0.25 s timeout. The switcher hides the preview outside the event tap's callback. A preview is rebuilt only when its windows change. |
| Elsewhere | Tiling keeps Oriel's windows within their minimum and maximum sizes. A file or URL that launches Oriel is opened once it has started instead of being dropped. The glass fallback follows Dark Mode. |

## After your answer: the remaining items

QA item 39 is ticked in the checklist. Its login half, no window at login, also answered the first launch question.

| Item | Done |
|---|---|
| Hard links (design change) | The tree keeps the hard-link registry while the scan is open, so a refresh or Read as Administrator counts a link of a file counted elsewhere as a further link. A file whose counted link goes (deleted, moved, removed by Oriel) is counted at another once that link's folder is read again. Read as Administrator's listings report each link's device and inode (`ElevatedRead.version` 2). Tested by refreshing either folder, both and deep, a deleted counted link, a moved folder in the worst order, and Oriel's own removal. |
| Other space | Summed again after every refresh and administrator read, with the summary's counts and closed folders from the tree, so a volume's scan still adds up to its used space. |
| File Types (design change, found on the way) | It showed the kinds as first scanned after any edit, because a folder's small files were one aggregate without their kinds. The tree now records the kinds each aggregate sums, compactly beside the nodes: 4–5 bytes a node on a tree of folders of mixed kinds, against the node's 56. File Types and the count of further hard links are summed again from the tree after every refresh, administrator read and removal. A removal leaves Other space as it was, since the Trash, read again just after, would otherwise show the items there for a moment. Clean Up now counts small files by their kinds too, so a folder of many small documents raises its "likely your own files" caution. |
| Found on the way | Read as Administrator replaced nothing: a folder a refresh found closed kept its old contents, and root's listing was added on top (5 MB gone + 3 MB found = 8 MB). It now replaces them. The Trash is read again after Oriel's own Move to Trash and Undo, which file-system events leave out. |
| Settings at launch (design change) | Settings opens half a second after a launch the user made and gives way to an App Intent, URL or file that arrives first (`LaunchWindow`), so a Shortcut or Spotlight intent that launches Oriel is not covered by it. |
| Dock (design change for an app hiding it) | A hover whose icon is not where the counts think brings a Dock that moved to another display back into line. After an app comes forward, the Dock is read again, and a Dock found hidden with the pointer away puts the counts aside until it is out. The Dock's own window can't tell: it covers the whole display at the Dock's level either way, as your Dock's window list showed. A list the Dock replaces is found again, once until one answers. The switcher installs its outside-click monitor after the tap callback, only for a session still open. |
| Memory | Above: no leak in Oriel; the allocator keeps freed memory. |
| The 3-second wake-up | Oriel's code has no timer, repeating delay or polling loop outside the allowed sessions. The rhythm comes from events or from the frameworks, costs about 2 ms of CPU a minute and stays within budget; naming its source would take a trace of a debuggable build. |
| Timing tests still to write | Stitching 20 frames (1.9 ms a frame optimized). OCR grouping of 500 lines found a real slowdown: each line's language was read by a recognizer made for it, one after another, 320 ms for a dense page, most of OCR's budget. The lines are now read in chunks on every core, one recognizer a chunk: 50–60 ms. |

## After you installed build 109

Build 109, freshly started at 19:22 and left alone, sampled from outside from 19:41 to 19:56:

| Budget | Target | Measured |
|---|---|---|
| Idle footprint | < 60 MB | **55.0–55.6 MB**; `footprint` reads 55 MB |
| Idle CPU, 10 min | 0.0 % | 0.016 % of a core: 143 ms in 14.5 minutes |
| Idle wake-ups | < 1/s | 0.36/s, and 0.002/s that woke the processor package; 5 threads |

Every idle budget is met. The 102 MB and 202 MB of your earlier session came after heavy use, and the allocator keeps freed memory for reuse. The process's own peak, 164 MB, was the Settings window it opened at launch, which you closed.

The 3-second wake-up comes in the fresh process too: 10 every 30 seconds, about 0.1 ms of CPU each. A six-second stack sample of the idle process showed:
- the main thread and AppKit's event thread waiting in their run loops the whole time;
- the one sample of work in libdispatch's manager thread, handling a kernel event, the path an XPC message or a framework's timer takes.

Oriel's code has no timer, repeating delay or loop outside the sessions rule 3 allows, and the 3-second delays it does have run only while the color panel or Translate Under Cursor is open. So it is the frameworks', within budget. Naming it would take a system-wide trace, which needs an administrator's password.

The last items, built after you installed build 109:

| Item | Done |
|---|---|
| The summary's other counts | The files only in the cloud, their content size, and the entries a listing could not read are summed from the tree after every refresh, administrator read and removal, like File Types. Small cloud-only files are recorded with their folder's aggregate, only when there are any (4–7 bytes); unreadable entries are kept per folder, sparsely. Read as Administrator's format is now version 4. |
| Every further hard link | The registry keeps every folder holding a further link of a file, not just one, oldest first, so a file whose counted link and one other both go is counted at the third. A folder read as an administrator, which a refresh cannot read again, is passed over for the next. A file with several links takes 132 bytes in the registry instead of 63; such files are few. |
| `.bin` files | They counted as Archives, because macOS takes the extension for MacBinary. Firmware, model weights and other binary data now count as Other. |

## After you checked build 112

You confirmed QA items 45–47; they are ticked. Then:

| Item | Done |
|---|---|
| The note after Full Disk Access (your item 44) | With Full Disk Access granted and Oriel reopened, the scan still said "macOS protects 69 folders… After granting Full Disk Access, quit and reopen Oriel, then scan again." Those 69 are folders System Integrity Protection keeps from every app. The note could not tell them from the ones Full Disk Access opens, because asking macOS whether Oriel has it would break rule 8. Now the scan tells: only Full Disk Access opens Safari's, Mail's and Messages' folders in your home folder, so a scan that read one of them has it. Then the window's note, the inspector and a folder's own note say those folders are closed to every app, Full Disk Access and administrators included, with no button. A scan that was refused those folders, or held none of them, keeps the advice. |
| Oriel in the Dock | While any of Oriel's windows is open, Oriel is a regular app. That covers Settings, Disk Space Analyzer, Activity Monitor, an editor and the histories, minimized ones included. It has a Dock icon with the running dot, its menus in the menu bar, and its windows in the Window menu and the Dock icon's menu. Resting on its icon shows its windows next to it, in the same preview as other apps'. When the last window closes, the icon goes, Oriel stays in the menu bar, and the app you were in gets the keyboard back. Capture overlays, pins, the clipboard panel and the tools' floating panels never put it in the Dock. |
| Quitting | Closing windows never quits Oriel. ⌘Q in its menu bar is now **Close All Windows**, and **Quit** in the Dock icon's menu closes the windows too, leaving Oriel in the menu bar. **Quit Oriel** in the menu-bar menu quits it. Some other requests quit it as well, because blocking them would stop a log-out or a permission's restart: logging out, restarting and shutting down (macOS gives a reason with those), Quit & Reopen in System Settings after granting a permission, scripts and other apps. |

How it works:
- **The Dock icon:** `DockPresence` follows AppKit's window notifications. One turn after a window opens, closes, is minimized or comes back, it sets the activation policy, so every module's windows count without changing them.
- **The menu bar:** an app made regular while it is already active is reported to keep the menu bar of the app before it. To avoid that, `OrielApplication` holds each activation back one turn, so Oriel is regular before it comes forward.
- **Clicking the Dock icon:** brings Oriel's windows forward, restores a minimized one when none shows, and opens Settings only when none is open. Before, it always opened Settings.
- **The app lists in Settings:** the Window Switcher's Exceptions and Clipboard History's ignored apps offer the apps that are running. Oriel is one of those while its Settings is open, so both leave it out.

## Still open

- **Needs your Mac:**
  - the UI tests (Automation Mode), the overlay test (Screen Recording) and the gesture recordings;
  - Apple Translation's budget (a language pack);
  - the switcher's first frame and capture latency on screen (Instruments);
  - the macOS 26 and Intel runs.
- **The 3-second wake-up:** the frameworks', within budget (above).
- **The Dock icon, on your Mac:**
  - the Dock's Quit is told apart by its sender, which I could not try without using your Dock: if Quit in Oriel's Dock menu still quits Oriel, the Dock is not the sender on this macOS;
  - a window opened from an Oriel panel that has the keyboard (Translate's panel, then its history) may still leave the menu bar showing the app before (`docs/os-quirks.md`).

## Tests added

| Test | What it checks | Runs |
|---|---|---|
| `Snapshot` in `OrielTestSupport`, `SnapshotTests` | Renders a view to an image in a window that is never shown, and compares it with PNG references per channel. References are named per macOS major version (`name@macOS27.png`), and tests skip on another macOS. `ORIEL_RECORD_SNAPSHOTS=1` records them; a mismatch writes the image and a diff (PLAN §14.4) | always |
| `GlassSnapshotTests` | The switcher's background turns opaque with Reduce Transparency and Increase Contrast (forced, the system's settings untouched), back to glass, and follows Dark Mode | always |
| The four budget tests | Above | always; translation only with a pack |
| `GestureRecorderTests`, `RecordedGestureTests` | Records eight real trackpad gestures to `Tests/Fixtures/gestures/`, then replays them: three-finger swipes open the switcher, four-finger, two-finger and vertical ones never do | recorder with `ORIEL_RECORD_GESTURES=1`; replay once there are fixtures |
| `SettingsUITests`, `OnboardingUITests`, `EditorUITests` | Settings opens at launch and each pane opens; closing it leaves Oriel running. Onboarding shows first and its button closes it. An image handed to Oriel opens in the editor with its tools | `ORIEL_UI_TESTS=1`; not run |
| `OverlayExclusionTCCTests` | Capture Window's picture of a window leaves an overlay panel over it out, and the freeze leaves the process's own windows out | `ORIEL_TCC_TESTS=1`; not run |
| `WindowLifecycleTests` | Closing Disk Space Analyzer's window frees it, its views and the scan | always |
| `GroupingBudgetTests`, `StitchingBudgetTests` | The last two timing tests §14.4 asks for; a bound follows the build where Debug is far slower | always |
| `LaunchWindowTests`, `SwitcherControllerTests` | Settings at launch opens after its delay unless a request came first; a switcher session opened and closed at once leaves no outside-click monitor | always |
| `DockPresenceTests`, `QuitRequestTests`, `StandardWindowsTests` | An open window puts Oriel in the Dock and the last one takes it out; hidden, it keeps its icon. Oriel runs as `OrielApplication`. Nothing in the menu bar quits, and ⌘Q is Close All Windows. Only a quit event from the Dock without a reason closes the windows; the end of the session, System Settings, other senders and no event at all quit. Which windows count, and that one never shown is not open | always |
| `FullDiskAccessEvidenceTests` | A read Safari folder means Full Disk Access, a refused Mail folder means none, and a scan without them cannot tell | always |
| Hard links (every holder), Other space, File Types, the cloud-only and error counts, Read as Administrator, Clean Up's kinds, `.bin`, the Dock | In `ScanEngineTests`, `ScanTreeTests`, `DirectoryDigestTests`, `ElevatedReadTests`, `AnalyzerModelTests`, `CleanupInspectorTests`, `SystemTextTests` and `DockTests`; each failed on the old code, and the kinds' memory test fails above 8 bytes a node | always |

Two OS findings from writing them are in `docs/os-quirks.md`: Settings' title follows the pane shown, so the UI tests find it by its sidebar, and Core Animation draws a flipped view upside down and a view outside a window not at all. Three more from the fixes: `setFrame` ignores a window's size limits, a launch to open a file delivers it before `applicationDidFinishLaunching`, and a synchronous XPC method blocks the connection's invalidation handler. Two from the Dock icon: the reported menu bar of an app made regular while active, and a sender attribute that a test cannot set. One from the gate: AVFoundation's exports stalled once.

## How it meets the rules

- **Rule 2:** no private API. `mbr_check_membership`, code requirements, libproc and `realpath` are public.
- **Rule 3:** no timer. The Dock's reads after a Space change or an app coming forward and Settings' half-second wait at launch are one-shot delays the next event replaces; the helper's read thread lives for one request. The Dock icon follows window notifications, one turn after each.
- **Rule 6:** every Dock element gets the 0.25 s timeout before it is asked anything, and nothing is sent to Oriel: its own icon's preview lists its windows through AppKit.
- **Rule 8:** Full Disk Access is never asked about; what the scan could read tells.
- **Rules 9 and 10:** no dependency, entitlement, deployment target or ARCHS change; SharedUI's tests use the in-repo test support. `make universal-check` ran anyway.
- **Rule 14:** the Debug build keeps its own helper and the plain requirement.

## Deviations from PLAN.md (amended in plan 2.11)

- **§7.10 item 17:** the helper no longer reads for the CLI, answers administrators only, and a release requires Developer ID without `get-task-allow`.
- **§7.10 item 19:** Clean Up's recommendations and leftovers changed as above. Downloads recommends Old Files and offers its installers below it.
- **§7.1.12:** copies of one app, Space changes, magnified icons and the read schedule.
- **§14.4:** describes the helper and the timing tests as built, stitching and OCR grouping included.
- **§9:** gains the measured figures and what the memory turned out to be.
- **§7.10 items 3 and 5:** hard links across the scan's life, Other space after every edit, administrator reads that replace, and the Trash after Oriel's own moves.
- **§7.6, §10.1:** OCR reads its lines' languages on every core; Settings at launch waits half a second for a request.
- **§10.1, §7.1.12:** Oriel is in the Dock while one of its windows is open, with its windows in its icon's preview. ⌘Q and the Dock's Quit close its windows, and its Dock icon brings them forward.
- **§7.10 item 6:** the notes tell Full Disk Access from the scan.

## What you need to do

1. **Install build 114.** Quit Oriel from its menu-bar menu, open `dist/Oriel-0.1.0.dmg`, drag **Oriel** to **Applications** and choose **Replace**; Settings → About shows build 114. The helper's answers have not changed since build 112.
2. **QA:**
   - **Item 42 (your item 44):** with Full Disk Access granted, scan Macintosh HD again. The note says the folders left are kept from every app, with no button.
   - **Item 48 (new):** Oriel in the Dock, its icon's preview, ⌘Q, the Dock's Quit, ⌘H, and Quit & Reopen in System Settings.
   - **Item 44:** `oriel disk scan` no longer reads owner-only folders, and Remove Helper stays removed with the window open.
   - **A Shortcut that runs one of Oriel's actions while Oriel is not running:** Settings does not open over it.
3. **Memory:** measured on build 109 (above). Build 114 adds only window notifications to what runs while Oriel is idle.
4. **Optional runs on your Mac:**
   - The UI tests: `automationmodetool enable-automationmode-without-authentication` once (administrator), then `ORIEL_UI_TESTS=1 make test`.
   - The overlay test: `ORIEL_TCC_TESTS=1 swift test --package-path Packages/Capture --filter OverlayExclusionTCCTests`, which shows two windows for about a second.
   - The gestures: quit Oriel, run `ORIEL_RECORD_GESTURES=1 swift test --package-path Packages/WindowSwitcher --filter GestureRecorderTests`, and swipe as asked.
   - Apple Translation's budget: install a language pack (System Settings → General → Language & Region → Translation Languages) and run `swift test --package-path Packages/OrielTranslation --filter AppleTranslationBudgetTests`.

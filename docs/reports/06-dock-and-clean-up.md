# 06 — Dock previews and window counts, Clean Up (release 0.1.0)

2026-10-30 · macOS 27.0.1 (26A434) · Xcode 27.1 · what you asked for while testing build 66: the Dock's previews and window counts, a safer way to clean up folders in Disk Space Analyzer, and the small polish, built in one pass, then a clean build; after your answers to this report's questions (2026-10-31), Clean Up in Space Hogs' rows as well. The tests, measurements and review deferred from the earlier list come once you have installed it.

## Result

- **Dock previews.** Rest the pointer on an app's Dock icon and its windows appear next to it as the switcher's thumbnail tiles, most recently used first: click one to switch, hover it to close, minimize or make it full screen. They show after 250 ms, at once from icon to icon, and go 350 ms after the pointer leaves both the icon and the panel. A click elsewhere, another app coming forward or the switcher opening dismisses them.
- **Window counts on Dock icons: feasible only drawn.** No app can set another app's Dock badge: the Dock's `AXStatusLabel` cannot be set (checked on this Mac), and LaunchServices changes another app's information only for Apple's own processes, through a private entitlement Oriel cannot have. So Oriel draws the counts in a transparent window over the Dock that the mouse goes through. They show on apps with two or more windows, as white digits on a dark capsule at the icon's lower corner away from the screen's edge, clear of the app's own badge.
  - **Placement:** they stay put on your Dock (left, always shown, no magnification). They step aside while the Dock moves its icons.
  - **Dock settings:** while the Dock hides itself, they show only when it is out. With magnification on, they step aside while the pointer is in the Dock.
  - **Full screen:** they are not shown over full-screen apps.
- **Settings:** both are on by default in Settings → Window Switcher → Dock, and keep working while the switcher itself is off.
- **Clean Up** (a folder's right-click menu, the inspector, and every row of Space Hogs) checks a folder before anything goes; a folder that is not in the open scan, such as a space hog's, is read first. It gives one of four verdicts (Safe to clean up, Clean up with care, Look before you remove it, Keep it), says what the folder is and what Oriel found for and against, and lists the ways to get its space back with the recommended one chosen. What it removes goes to the Trash through the usual confirmation, with Undo. For a folder Oriel's catalog does not know, Apple Intelligence's on-device model says what it probably is. It can only make the advice more careful. After Clean Up or any removal, the space hogs whose folders it touched are measured again.
- **Polish:** the Info.plist names Oriel's App Category (Utilities), which the release archive reported missing.
- **Checks:** `make generate build test lint universal-check` passes.
  - 1,743 tests: 29 app tests and 1,714 in the 19 packages, 47 of them new.
  - No compiler warnings; SwiftLint `--strict` and SwiftFormat are clean.
  - Both slices build, and `--self-test` passes natively and under Rosetta.
  - `ORIEL_TCC_TESTS=1` read the real Dock: 28 icons, 25 apps, 7 running, on the left.
- Still 0.1.0. `dist/Oriel-0.1.0.dmg` is build 71, from the moved `v0.1.0` tag, notarized and stapled. The tag message holds its SHA-256 and notarization IDs.

## Clean Up: the approaches weighed

You asked for the safest and most effective way. Each approach was judged on two questions: could it lose something that cannot be rebuilt, and does it free the space people actually lose.

| Approach | Safety | Effectiveness | Used |
|---|---|---|---|
| Select and delete, as before | Depends entirely on the user knowing the folder | Frees anything | Kept, behind the confirmation |
| A catalog of known folders (what it is, whether it comes back, the right method) | High: deterministic, reviewed, tested | High for the usual space hogs (Xcode, simulators, Gradle, npm, browsers' caches) | **Yes, first** |
| Judging an unknown folder by its place, name, contents and the marks tools leave (`CACHEDIR.TAG`, kept out of Time Machine) | Good when it defaults to caution | Covers what no catalog lists | **Yes, second** |
| Checks of what is true now: processes using it, its app running, Git repositories, personal files, cloud storage, who may remove it | Raises safety; never lowers it | Prevents breaking an app mid-write | **Yes, always** |
| The owning tool's own command (`simctl`, `go clean`, `brew cleanup`, `docker system prune`) | Highest for what only the tool understands, or what belongs to root | Complete | **Yes**: Oriel runs CoreSimulator's two commands itself; the others are offered to copy |
| Apple Intelligence, on the device (FoundationModels) | It can be wrong, so it must never decide | Good at naming unfamiliar folders | **Yes, as an explainer only:** it reads names and sizes, never file contents, nothing leaves the Mac, and it can only make the advice more careful |
| A cloud model (Claude, GPT…) | It would send folder and file names, which are personal, off the Mac; it needs a key and a network; it is as fallible | Better reasoning | **No:** privacy, and a deletion decision should not depend on a network |
| Deleting at once | Irreversible | — | **Never:** everything goes to the Trash, with Undo |

What was built follows the table. The advice comes from rules: the same folder always gets the same advice, and every rule has a test. The recommended method is the narrowest that frees the space: older versions' folders rather than the whole cache, leftovers rather than the profile, the tool's command where only it can do it. Whatever is in use is left out.

On this Mac, read-only:

| Folder | Size | Advice | Recommended |
|---|---|---|---|
| `~/.gradle/caches` | 18.02 GB | Safe to clean up (catalog; `CACHEDIR.TAG`) | The caches of Gradle 9.1.0, 9.3.1, 9.4.1 and 9.6.1, 9.8 GB; 9.8.1 stays. Alternative: all of it, after `./gradlew --stop` |
| `~/Library/Application Support/Google/Chrome-headless` | 15.7 GB | Safe to clean up (judged) | 625 temporary profiles that ChromeDriver or Puppeteer runs left behind |
| `/Library/Developer/CoreSimulator/Caches` | 7.04 GB | Safe to clean up (catalog; root's) | Have CoreSimulator remove them: `xcrun simctl runtime dyld_shared_cache remove --all` |
| `~/Library/Application Support/Google` | 17.09 GB | Keep it (an app's data; Chrome had files open) | Older Android Studio versions' settings, 478 MB, and 3.47 GB of caches not in use |

Gathering each folder's facts took 0.06–0.18 s, including the check of every process's open files. Apple Intelligence answered a made-up unknown folder in 2.8 s. It named the folder's app and said removing it could lose data, which turns the advice careful.

## How it works

| Part | What it does |
|---|---|
| `DockAccessibility` | The Dock's AX actor: its own serial queue, the 0.25 s timeout (rule 6). It observes the Dock's list for `AXSelectedChildrenChanged` (hover) and for icons added or removed, and reads each icon (title, URL, frame, running) in one round trip. The Dock supports no moved or resized notification, so it is read again after the events that move icons: one-shot delays, a kqueue watch on its preferences file, screen changes, the pointer leaving it. |
| `DockWindowMap`, `DockBadgeLayout`, `DockPreviewLayout`, `DockHoverMachine` | Pure and tested. Which windows an icon stands for (an app run twice: by launch order), where a count goes on each edge, the preview's grid and place, and when it shows and goes. |
| `DockBadgeOverlay`, `DockPreviewPanel`, `DockController` | The counts' window: Dock level + 1, ignores the mouse, every Space but full-screen ones. The preview: a non-activating panel with the switcher's tiles and thumbnails. The controller ties them to the switcher's store. |
| `CleanupInspector`, `FolderUsers`, `CleanupApps` | The facts, off the main thread: the scan's sizes, dates, kinds, repositories and caches; the folder's names, tags and permissions; the processes using it (libproc, for your own processes); the apps its path names. |
| `CleanupCatalog`, `CleanupAdvisor`, `VersionedNames` | The judgment, pure: 48 rules for known folders, then place, name and contents, then the checks that can only make it more cautious. Leftovers inside any folder are offered as well. |
| `CleanupExplainer` | Apple Intelligence (FoundationModels). It is shown only where the model is available, and Settings → Disk Space Analyzer → Safety turns it off. |
| `CleanupSheetController` | The sheet: verdict, findings, the model's reading, the methods. The window carries out the choice and checks again for processes using the items just before they go. |

## How it meets the rules

- **Rule 2:** no private API. The Dock's AX attributes and notifications, libproc and FoundationModels are public.
- **Rule 3:** no timer. Delays are one-shot. The click and pointer monitors run only while a preview shows; the preferences watch is a kqueue event source.
- **Rule 4:** the overlay, the preview and the Clean Up sheet are AppKit; only the Settings rows are SwiftUI.
- **Rule 5:** Apple Intelligence is behind its availability gate, and its UI is hidden when the model is unavailable. FoundationModels is part of macOS 26.0, the floor, so it needs no `#available`.
- **Rule 6:** every Dock request runs in its actor, never on the main thread and never to Oriel.
- **Rules 9 and 10:** `project.yml` changed (the category), so `make universal-check` ran. No dependency, entitlement, deployment target or ARCHS change.
- **Settings:** `switcher.dockPreviews`, `switcher.dockWindowCounts` and `disk.explainsFolders` sync like the other preferences.

## Deviations from PLAN.md (amended in plan 2.10)

- PLAN 2.9 had no Dock features. §7.1.12 is new, and the switcher's module now also runs for them while the switcher itself is off, without its event tap or Cmd-Tab takeover.
- §7.10 gains item 19, Clean Up. Its list of public APIs gains libproc and FoundationModels.
- Trash planned from paths (Space Hogs, Clean Up) now reads their folders again afterwards. The smaller files a scan sums up were not removed from the tree before.
- Space Hogs' rows offer Clean Up (§7.10 item 13), and its sizes are measured again after a change touches their folders.

## Not verified here, and how to finish

Nothing on your screen was driven, and nothing was removed:

- **Dock on screen:** the hover-to-preview flow, clicks and the counts over real icons. The positions come from the Dock's own frames, which the test read; the rest is QA items 45–46. Also untested: Dock magnification and hiding, other displays, full-screen Spaces.
- **Clean Up's sheet:** its actions on the installed app, including running CoreSimulator's command, which would have removed this Mac's simulator caches (QA item 47).

## Your answers (2026-10-31)

1. Apps with one window show no count: as built.
2. The count stays at the icon's lower corner.
3. Space Hogs' rows offer Clean Up: each row's **Clean Up…** checks its folder (Installers in Downloads checks Downloads, which now offers its installers), and the rows found by name (`node_modules`, `.build`) have a **Clean Up** menu of the folders found. Built in build 71.

## What you need to do

1. Quit the running Oriel. Open `dist/Oriel-0.1.0.dmg`, drag **Oriel** to **Applications** and choose **Replace**. Settings → About shows build 71.
2. Run QA items 45–47 (`docs/qa-checklists.md`).

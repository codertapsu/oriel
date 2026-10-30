# 04 — Fixes after the first days of use (release 0.1.0)

2026-10-30 · macOS 27.0.1 (26A434) · Xcode 27.1 · three issues reported on build 58, fixed in one pass, then a clean build.

## Result

- **Oriel no longer goes away after its window is closed.** It was not quitting: it crashed. All nine crash reports, from a pre-release build and builds 20, 26 and 58, are the same EXC_BREAKPOINT on the switcher's AX queue. Once an Oriel window (Settings, a tool) had made Oriel one of the switcher's apps, the switcher asked Oriel itself for its windows through Accessibility. macOS answers a request a process sends to itself inside that process, on the calling thread, so AppKit walked Oriel's views off the main thread and trapped on Swift's main-actor check in `ThumbnailView`. The switcher never asks Oriel through AX now: AppKit lists, focuses, closes and minimizes Oriel's windows on the main thread, so they are still in the switcher. Window Tiling had the same flaw, with an Oriel window in front and a tiling shortcut pressed, and is fixed the same way. Nothing ever quit the app on a window closing; only Quit Oriel quits it, and the switcher's Quit never quits Oriel.
- **Oriel opens its window when you start it.** Started by you, it opens Settings (onboarding instead, until that is done). Started by macOS at login, or to open a file or URL, it stays in the menu bar. Opening it again while it runs brings Settings back, as before.
- **Disk Space Analyzer reads everything macOS lets it, and says why the rest is closed.** Full Disk Access lifts macOS's privacy protection, not a folder's permissions: with it granted, folders only macOS or another user may open (`EACCES`: Spotlight's index, the file-system event log, much of `/private/var/db`, other users' homes, 72 of them within three levels of `/private/var` and `/Library` on the dev Mac) could still not be read, and the window kept offering Full Disk Access for them. Now each closed folder carries why. **Read as Administrator…** reads the owner-only folders with an administrator's rights after macOS's password prompt. The startup disk's scan reads macOS's own volumes into a folder named **macOS**: `/System`, `/usr`, `/bin`, `/sbin`, the swap files (VM) and Update, with Preboot as one block, 3.5 s more on the dev Mac and within 1 % of `df`. Hidden files and folders were and are included.
- **A wrong size, found on the way:** the old "macOS (system)" block was four times the whole container's use (1.64 TB on a 494 GB disk), because on APFS `statfs` gives every volume the container's use. Volumes are measured as `df` does now (`ATTR_VOL_SPACEUSED`), and an earlier `docs/os-quirks.md` row that said otherwise is corrected.
- `make generate build test lint universal-check` passes: 1,688 tests (28 app tests and 1,660 in the 19 packages, 27 of them new), no compiler warnings, SwiftLint `--strict` and SwiftFormat clean, both slices, `--self-test` loading all 19 packages natively and under Rosetta. Built from nothing, the release showed one warning that incremental builds had hidden, in a test of the last round (`SettingsSyncTests` mutated a captured variable from a notification block); the test is fixed, and nothing that ships changed.
- Still 0.1.0. `dist/Oriel-0.1.0.dmg` is build 63, from the moved `v0.1.0` tag, notarized and stapled; the tag message holds its SHA-256 and notarization IDs.

## What was built

| Where | What |
|---|---|
| WindowSwitcher | `AXClient` refuses Oriel's pid (`ownPID`), app elements and remote tokens alike. `OwnWindows`: Oriel's standard windows (titled, normal level, not panels, so never the switcher's own panel, overlays, pins or floating panels) as `AXWindowRecord`s, the focused one, focus, close, minimize and full screen through AppKit. `OwnWindowObserver` posts `windowsChanged` and `focusedWindowChanged` from `NSWindow` notifications in place of AX observers. `SystemWindowSource` routes Oriel's pid to them; `quit(pid:)` refuses Oriel |
| WindowTiling | `OwnWindowAccess` (`WindowAccessing` on `NSWindow`, frames in Accessibility's coordinates through `ScreenGeometry`) and `OwnWindowTiler`, the same `WindowArranger` on the main thread with a history of its own; the module sends Oriel's pid there; `AXWindowAccess` refuses it |
| App | `LaunchChecks.opensWindow(launch:)`: `NSApplication.launchIsDefaultUserInfoKey` and the launch event's `keyAELaunchedAsLogInItem`, read in `applicationDidFinishLaunching`, the only moment the launch event is current; `AppController.start(opensWindow:)`. `main()` runs Read as Administrator's listing mode first when its argument is first |
| DiskAnalyzer: why | `UnreadableReason` (`needsAdministrator` for `EACCES`, `protectedByMacOS` for `EPERM`, other), flags on the node, counts and samples per reason in `ScanSummary` (recounted from the tree after a change); a banner, an inspector section and a folder note per reason, each with what helps; the CLI report and `--json` (`administratorOnlyFolders`, `protectedFolders`), the file-operation errors, the pre-scan note and Settings → Full Disk Access say the same |
| DiskAnalyzer: Read as Administrator | `ElevatedRead`: the request as arguments (threshold, hidden files, crossing, exclusions, folders), run as root through `AdminCommand` (`osascript … with administrator privileges`, every argument quoted); the listing mode reads with the scan's own `DirectoryReader` and `DirectoryDigest`, prints one JSON document and exits; `apply` grafts the listings where the folders were, marked `readAsAdministrator`, and the model sums the totals, the summary and the volume's blocks again. Refreshes leave those folders as read; Duplicates leaves them out; removals and moves are refused |
| DiskAnalyzer: macOS's volumes | `MacOSVolumes` and a tree *anchor* (`ScanTree.anchors`: paths below it start at `/`, kept through edits and compaction); the system volume read with its firmlinks, automount triggers, `/.nofollow`, `/.resolve`, `/.vol` and foreign mounts left out, VM and Update entered, Preboot one block of `ATTR_VOL_SPACEUSED`; everything there flagged `macOSVolume`, refused for removal, left out of Old Files, Duplicates and Biggest Files unless the macOS folder is shown, never refreshed. Settings → **Count macOS's own files one by one** (on). `VolumeService.spaceUsed`, `helperVolumeMounts`; the system block (setting off) is measured the same way |
| SafetyRules | Everything directly at the top of the startup volume is refused (`/.file`, `/pkg`) |
| Tests | `OwnWindowsTests` (3), `OwnWindowTilerTests` (5), `MacOSVolumesTests` (9), `ElevatedReadTests` (7, one of them with 8 kinds of wrong arguments), new cases in `ScanEngineTests`, `SafetyRulesTests` and `LaunchChecksTests`, and `ElevatedReadEntryTests`, which runs the app's own executable in listing mode on a test folder |

## How it meets the rules

- **Rule 6** gained a sentence: never send an AX request to Oriel's own process (CLAUDE.md and its copy in PLAN Appendix B). All of Oriel's AX code is in the two AX actors, and both refuse Oriel's pid.
- **Rule 8:** nothing probes Full Disk Access. The analyzer classifies the errors a scan gets; it cannot tell privacy protection from System Integrity Protection without probing, so the note names both.
- **Rule 3:** no timer. Oriel's own windows are followed through `NSWindow` notifications.
- **Rule 2:** no private symbol was added. `getattrlist`, `ATTR_VOL_SPACEUSED`, `keyAELaunchedAsLogInItem` and `launchIsDefaultUserInfoKey` are public.
- **Read as Administrator's root process** is Oriel's own signed executable, started by macOS's password prompt with everything it needs on its command line. It reads directories and prints, and nothing else: no file is opened or written as root, no link is followed, nothing is left running. The password never reaches Oriel.
- **Rule 13:** the credentials file was only sourced inside `bash -c` for the release; nothing printed its values.

## Deviations from PLAN.md (amended in plan 2.8)

- PLAN 2.7 counted macOS as one block from `statfs`; it is now read file by file in the macOS folder by default, Preboot excepted, and every volume is measured with `ATTR_VOL_SPACEUSED` (§7.10 item 2). The os-quirks row behind the old way was wrong and is corrected.
- PLAN 2.7 read every relevant app through AX (§7.1.1), Oriel included; Oriel's own windows now come from AppKit, in the switcher and in Window Tiling (§7.14 item 6).
- Settings now opens at launch (§10.1).

## Not verified here, and how to finish

Nothing was driven on your screen, and no administrator password was entered. QA items 39–43 in `docs/qa-checklists.md` cover:

- the switcher and Window Tiling with Oriel's windows, opened and closed, and Oriel staying up (items 39–41);
- Settings opening at launch, and not at login: `keyAELaunchedAsLogInItem` is Apple's documented marker, but whether macOS 27 sets it for an `SMAppService.mainApp` login item was not seen (item 39);
- Read as Administrator end to end: the password prompt, the root listing and the graft. The listing mode, the request and the graft are tested as the user; the root process may or may not inherit Oriel's Full Disk Access (macOS decides which process is responsible), so privacy-protected folders inside owner-only ones may come back as protected by macOS (item 42);
- the macOS folder in the charts and lists, and the setting turned off (item 43).

Also unverified: whether a Shortcuts action that launches Oriel counts as a default launch, which would open Settings next to it.

## Open questions

1. **Read as Administrator asks every time.** What it read lasts until the next scan. Reading those folders on every scan without asking would need a privileged helper (`SMAppService.daemon`), approved once in System Settings, which is a larger piece. Is asking each time acceptable?
2. **Biggest Files** leaves macOS's files out unless you open the macOS folder, so the list stays about what you can remove. Would you rather see the swap files and the like there too?
3. **Settings at every launch.** Should there be a setting to start Oriel without its window, beyond login?

## What you need to do

1. Quit the running Oriel, if any. Open `dist/Oriel-0.1.0.dmg`, drag **Oriel** to **Applications** and choose **Replace**. Your permissions carry over (same bundle ID and signature). Settings → About shows build 63.
2. If you granted Full Disk Access while Oriel was running, quit and reopen it once.
3. Run QA items 39–43.

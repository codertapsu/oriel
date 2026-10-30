# 05 — Read as Administrator asks once; macOS's files in Biggest Files (release 0.1.0)

2026-10-30 · macOS 27.0.1 (26A434) · Xcode 27.1 · the answers to the open questions of `docs/reports/04-first-use-fixes.md`, built in one pass, then a clean build.

## Result

- **Read as Administrator asks for a password once.** The first time, Oriel offers its helper: **Install Helper…** registers it and opens System Settings → General → Login Items & Extensions, where you switch Oriel on under Allow in the Background and macOS asks for an administrator's password, once. From then on, every complete scan reads the folders only an administrator can open by itself, with no prompt, and so does `oriel disk scan`. **Just This Scan** keeps the password prompt for one scan, and builds without the helper use it. Settings → Disk Space Analyzer → Read as Administrator shows the helper's state, turns the reading in every scan off and removes the helper; Uninstall Oriel removes it too.
- **Biggest Files lists macOS's own files at the top level**, such as the swap files and Preboot's large files, with everyone else's. Old Files still leaves them out unless you open the macOS folder, since the sealed system's unused files are nothing to remove, and Duplicates still never compares them.
- The third question, whether Settings should be skippable at launch, had no answer, so that is unchanged.
- `make generate build test lint universal-check` passes: 1,696 tests (29 app tests and 1,667 in the 19 packages, 8 of them new), no compiler warnings, SwiftLint `--strict` and SwiftFormat clean, both slices, `--self-test` loading all 19 packages natively and under Rosetta.
- Still 0.1.0. `dist/Oriel-0.1.0.dmg` is build 66, from the moved `v0.1.0` tag, notarized and stapled, with the helper's property list inside; the tag message holds its SHA-256 and notarization IDs.

## How the helper works

It is Apple's supported way for an app to run something as root: a launchd daemon in the app bundle, registered with `SMAppService` and allowed by an administrator in System Settings, which macOS then starts on demand.

| Part | What it does |
|---|---|
| `App/LaunchDaemons/disk-reader.plist` and a build phase | Writes `Contents/Library/LaunchDaemons/<bundle ID>.disk-reader.plist`: the label and Mach service `<bundle ID>.disk-reader`, `BundleProgram` Oriel's own executable, `AssociatedBundleIdentifiers` the app. Named after the bundle ID, so the Debug build's helper never takes the release's name (rule 14). Code signing seals it |
| `PrivilegedReaderDaemon` | `main()` checks first whether launchd started this executable as root for the helper (the job's label in `XPC_SERVICE_NAME`); if so it only listens on the Mach service and nothing else of Oriel starts |
| `PrivilegedReaderListener`, `PrivilegedReaderService` | Accept a connection only from a client whose code signature is Oriel's (its identifier, its team, an Apple-issued certificate); answer one request, list these folders, with `ElevatedRead.read` and the scan's rules, as JSON; exit when the last connection closes, so nothing stays running |
| `PrivilegedReader` | The app's side: the helper's state, install, remove, open Login Items, and the XPC request, which also requires the daemon's signature to be Oriel's (`CodeIdentity`). An update replaces the executable launchd starts, and `SMAppService`'s header says a daemon may then not launch until it is registered again, so Oriel registers it again the first time it is used after an update, and once more when it does not answer |
| The window | **Read as Administrator…** goes through the helper when it is allowed; otherwise it offers Install Helper… (or Open Login Items, when it waits for approval), Just This Scan and Cancel. When Oriel comes back to the front after System Settings, it notices the helper is allowed and reads the folders. A complete scan reads them through the helper by itself (`disk.readsAsAdministrator`, on) |
| Tests | `PrivilegedReaderTests`: the XPC conversation through an anonymous listener in the test process, another app's signature refused, a request it does not understand, idling out, and the pure parts; `LaunchDaemonTests` checks the property list in the built app. Nothing in the tests registers anything with macOS |

## How it meets the rules

- **Security.** The helper reads directories and replies, nothing else: it opens no file, writes nothing and follows no link, as the password route already did. Only Oriel, as signed by its team, can talk to it, Hardened Runtime keeps code from being injected into Oriel, and Oriel checks it is talking to its own helper. An administrator has to allow it once, in System Settings. It runs only while answering.
- **Rule 3:** no timer and no polling. The helper's state is read when the window opens and when Oriel comes to the front; the helper exits when idle and launchd starts it on demand.
- **Rule 2:** no private API. `SMAppService`, `NSXPCConnection.setCodeSigningRequirement` and the Security calls are public.
- **Rules 9 and 10:** the build phase changes the project, so `make universal-check` ran; no dependency, entitlement, deployment target or ARCHS change.
- **Rule 14:** the Debug build's helper has its own label and property list.
- **Settings sync:** `disk.helperBuild` is this Mac's own and does not sync.

## Deviations from PLAN.md (amended in plan 2.9)

- PLAN 2.8's permissions table said Oriel used no helper tool; it now has one, optional, for Read as Administrator (§7.10 item 17, §8.1).
- PLAN 2.8 left macOS's files out of Biggest Files unless the macOS folder was shown (§7.10 item 18).

## Not verified here, and how to finish

Nothing was registered with macOS here, and no password was entered: registering would have added a background item to this Mac. QA item 44 covers what needs your Mac:

- registering, the approval in System Settings, launchd starting the helper as root, and the XPC request to it. The conversation itself is tested in the test process, with the same listener and service;
- whether the approval survives an update's re-registration, or macOS asks you to allow it again;
- whether the helper, started by launchd rather than by Oriel, has Oriel's Full Disk Access. If not, privacy-protected folders inside owner-only ones come back as protected by macOS;
- a Debug build cannot register the helper, since macOS wants a notarized app for that; it uses the password prompt.

## What you need to do

1. Quit the running Oriel. Open `dist/Oriel-0.1.0.dmg`, drag **Oriel** to **Applications** and choose **Replace**. Settings → About shows build 66.
2. Run QA item 44, and item 43 for Biggest Files.

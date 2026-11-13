# Oriel

Oriel is an internal macOS menu-bar utility with nine tools:

- **Window switcher**: every window, including minimized, hidden and other-Space ones, with previews, search, presets, up to nine shortcuts and a command-line tool; an app's windows next to its Dock icon, and the number of windows on Dock icons.
- **Snipping tool**: area, window and screen capture, Capture Text, Instant Capture, Step Capture, screen recording, scrolling capture, an annotation editor with Smart Redact, and a video editor with Auto Zoom and chapters; every capture also goes to the clipboard, and uploads go to S3, WebDAV, SFTP, a shared folder, Dropbox or Google Drive.
- **Screenshot translation**: on-device OCR, then Apple Translation (offline), a local LLM or a cloud provider, for an area, the text under the pointer or a whole file, with glossaries.
- **Clipboard History**: everything you copy (text, images, files and more), encrypted on the Mac, searchable on ⌥V and pasted straight into the app you are in.
- **Disk Space Analyzer**: where the space on each drive goes, macOS's own files and the folders only an administrator can read included, in a sunburst, a treemap and lists, and safe ways to get it back, with Clean Up checking a folder before anything goes.
- **Activity Monitor**: every process's CPU, memory, energy, disk and network use, measured only while its window is open.
- **Color Picker**: any color on screen in every format, with palettes and a WCAG contrast checker.
- **Screen Ruler**: distances, areas and guides on screen, snapped to the edges it finds.
- **Window Tiling**: halves, thirds, quarters and more for the window in front, from the keyboard.

Settings sync through iCloud, and App Intents put Oriel's actions in the Shortcuts app and Spotlight. It is written in Swift 6 (AppKit and SwiftUI) as a Universal binary, Developer ID signed and notarized, not sandboxed, with no runtime dependencies. A second edition of the same code, sandboxed and without the window switcher, Window Tiling and Activity Monitor, is prepared for the Mac App Store: free, with Oriel Pro as a one-time purchase (PLAN §18, §19). The design, decisions and roadmap are in [docs/PLAN.md](docs/PLAN.md), and progress is tracked in [docs/checklist.md](docs/checklist.md).

**Status:** 1.0.0, the first release, after the 0.1.0 builds reviewed on the maintainer's Mac: all nine tools are built and wired into the app, and the Mac App Store edition is ready for App Store Connect. What is verified and what still needs a person at the Mac is in [docs/reports/01-implementation.md](docs/reports/01-implementation.md); for Clipboard History and the automatic copy of every capture, in [docs/reports/02-clipboard-history.md](docs/reports/02-clipboard-history.md); for the roadmap features of PLAN §17, Disk Space Analyzer, Activity Monitor and the other new tools, in [docs/reports/03-roadmap-and-tools.md](docs/reports/03-roadmap-and-tools.md); for the fixes after the first days of use, in [docs/reports/04-first-use-fixes.md](docs/reports/04-first-use-fixes.md); for Read as Administrator's helper, in [docs/reports/05-administrator-helper.md](docs/reports/05-administrator-helper.md); for the Dock's previews and counts and Clean Up, in [docs/reports/06-dock-and-clean-up.md](docs/reports/06-dock-and-clean-up.md); for the fixes from a fresh-eyes review, the headless tests, the measurements and Oriel's Dock icon, in [docs/reports/07-review-tests-measurements.md](docs/reports/07-review-tests-measurements.md); for the App Store edition, Oriel Pro and the feature tour, in [docs/reports/08-app-store-edition.md](docs/reports/08-app-store-edition.md); and for App Review's first review and its fixes, in [docs/reports/09-app-review.md](docs/reports/09-app-review.md).

## Documentation

| Document | For |
|---|---|
| [docs/USER_GUIDE.md](docs/USER_GUIDE.md) | Using Oriel: permissions, shortcuts, every tool, the CLI, troubleshooting |
| [docs/BUILDING.md](docs/BUILDING.md) | Building, signing, notarizing and packaging `Oriel.app` by hand, step by step, and installing it |
| [docs/RELEASING.md](docs/RELEASING.md) | The scripted release: one command from a tagged commit to a notarized DMG |
| [docs/APP_STORE.md](docs/APP_STORE.md) | The Mac App Store edition: what is ready, what App Review checks, what it leaves out |
| [docs/APP_STORE_CONNECT.md](docs/APP_STORE_CONNECT.md) | Registering Oriel in App Store Connect, step by step: agreements, devices, the app record, Oriel Pro, the listing, upload, TestFlight, submission |
| [docs/APPLE_ACCOUNT.md](docs/APPLE_ACCOUNT.md) | The Apple Developer membership, certificates, passwords and profiles: what expires when, and how to renew each |
| [docs/PLAN.md](docs/PLAN.md), [docs/checklist.md](docs/checklist.md) | Design, decisions, roadmap and the verification checklist |
| [docs/os-quirks.md](docs/os-quirks.md), [docs/provenance.md](docs/provenance.md) | OS behaviour found along the way; where each private-API signature came from |
| [docs/qa-checklists.md](docs/qa-checklists.md) | The manual checks for a new build, step by step, and the record of each run |

## System requirements

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

## Install

From the notarized disk image: open `dist/Oriel-<version>.dmg` (built by `make release-dry-run`, see [docs/BUILDING.md](docs/BUILDING.md)), drag Oriel to Applications, open it, and grant the permissions the welcome window asks for.

From source on a development Mac. This exports a Developer ID build into /Applications and launches it; local builds are not quarantined, so Gatekeeper does not prompt.

```bash
make install
```

From the private Homebrew tap, once Oriel has a release destination ([docs/RELEASING.md](docs/RELEASING.md)):

```bash
brew tap <ORG>/oriel git@github.com:<ORG>/homebrew-oriel.git
brew install --cask oriel
brew upgrade --cask oriel     # later updates
```

## Development

You need Xcode 27.1 or later (Swift 6.4, macOS 27 SDK) and `brew install xcodegen swiftlint swiftformat`. The Xcode project is generated from `project.yml` and is not committed.

```bash
make generate          # xcodegen generate
make build             # Debug build
make run               # Debug build, then launch it (quits a running copy first)
make test              # app tests and every package's tests
make lint              # swiftlint --strict and swiftformat --lint .
make universal-check   # Universal Release build, lipo check, native and Rosetta self-test
make install           # Developer ID build into /Applications, then launch it
```

CI (`.github/workflows/ci.yml`) runs lint, the build, the tests and the universal check on every pull request, signing ad hoc. Releases are built, notarized and verified on this Mac with the `scripts/apple-credentials.env` file shared with the other desktop apps: `source scripts/apple-credentials.env && make release-dry-run`. See [docs/RELEASING.md](docs/RELEASING.md).

- `ORIEL_TCC_TESTS=1 make test` also runs the tests that need Accessibility or Screen Recording grants (dev Mac or macOS 26 VM only).
- `ORIEL_UI_TESTS=1 make test` also runs the XCUITest bundle. It needs macOS Automation Mode, which asks for an admin password unless `automationmodetool enable-automationmode-without-authentication` has been run once.
- The checklist's on-device checks are scripts: `scripts/idle-cpu.sh`, and, with `ORIEL_TCC_TESTS=1`, `scripts/verify-windows.sh [--other-space]`, `scripts/verify-cmdtab-restore.sh`, plus `scripts/verify-recording.sh [--pause]` and `scripts/perf-capture.sh`, which need a running Debug build (`make run`). Each one says at the top what it needs and what it does to the desktop.

Working rules for Claude Code are in [CLAUDE.md](CLAUDE.md).

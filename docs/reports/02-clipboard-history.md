# 02 — Clipboard History and automatic screenshot copy (release 0.1.0)

2026-10-29 · macOS 27.0.1 (26A434) · Xcode 27.1 · the two requests made after reviewing the first 0.1.0 build, built in one pass.

## Result

- **Screenshots go to the clipboard.** Every interactive capture, in every mode (area, window, screen, scrolling, previous area, all displays, timer), is copied to the clipboard as soon as it is taken, whatever the after-capture action: Settings → Capture → **Copy every capture to the clipboard**, on by default. Quick Access keeps its Copy button. Because Oriel's own copies go straight into Clipboard History, a capture is there even when Quick Access is closed with Esc.
- **Clipboard History** is a new tool, on by default (General → Tools). It keeps text, formatted text, links, colors, images, files and any other data, encrypted on this Mac. **⌥V** (Settings → Shortcuts) opens a panel over the app the user is in: search, a type filter, a preview of the selected item, and **Paste to *App*** (Return or a double-click) into that app's focused field. It can delete one item or many with Undo, reorder by drag and drop or ⌥⌘↑/↓, pin, paste as plain text, paste the first nine with ⌘1–⌘9, paste several items at once and clear the history. Settings has **Remove items from the history after pasting them** (off by default), limits on items, days and disk space, pause, and the apps it ignores.
- `make generate build test lint universal-check` passes: 677 tests (656 in packages, 60 of them Clipboard History's, and 21 app tests), with no compiler warnings, SwiftLint `--strict` and SwiftFormat clean, both slices, and `--self-test` loading all 14 packages natively and under Rosetta.
- Both ship in 0.1.0. `dist/Oriel-0.1.0.dmg` is built from the `v0.1.0` tag, notarized and stapled, and the tag message holds its SHA-256 and notarization IDs.

## What was built

| Where | What |
|---|---|
| `Packages/ClipboardHistory` (new; 44 files, 4,313 source lines, 843 test lines) | The module: `PasteboardWatcher` (change detection without timers), `PasteboardReader` (off the main thread, with privacy markers checked before any data), `ClipboardClassifier` (kinds, titles, the content hash that merges repeat copies), `ClipboardIndex` (pins, reordering, Undo, limits, all pure), `ClipboardStore` (AES-GCM files, key in the Keychain), OCR indexing of images, the AppKit panel, pasting with ⌘V, the SwiftUI Settings pane |
| `SharedUI.Pasteboard` | Every write Oriel makes to the general pasteboard goes through it and is announced (`Pasteboard.writes()`). The About and Advanced panes and the recording panel's Copy now use it too |
| Capture | The **Copy every capture to the clipboard** setting; `deliver` copies first (labelled "Screenshot" for the history) and does not copy twice when the after-capture action or ⌘C is Copy |
| OrielCore, Permissions | `PermissionKind.pasteboard` (Paste from Other Apps, through `NSPasteboard.accessBehavior`, deep link `Privacy_Pasteboard`); `KeychainStore.data(service:account:)`, which tells a missing item from a locked keychain; `ModuleID.clipboardHistory`; `AppPaths.clipboardHistory` |
| App | `AppAction.showClipboardHistory` (⌥V, `oriel://clipboard`, status menu); its shortcut is registered only while the tool is on; Settings → Clipboard History; Pause/Resume in the status menu; a tool that arrives in an update is turned on once; Uninstall removes the key |
| CLI | `oriel debug clipboard [--json]`: the state, never the contents |

The panel was rendered off screen in light and dark, with text, a link, a color, code, a screenshot and files selected, and with no matches. That caught one bug: a large image or a long file name could grow the panel past the screen. Preview views now yield to the panel's fixed size.

## How it meets the rules

- **No polling (rule 3).** macOS has no pasteboard-change notification; none exists in the 27.0.1 shared cache. The watcher compares `changeCount` after mouse-ups and key-downs anywhere, app switches, wake, and the panel opening. It checks 150 ms and 1 s after the last event with one-shot sleeps, and does nothing while idle. Key-downs are watched only with Accessibility, and their keys are never read (PLAN §7.9 item 3).
- **Paste from Other Apps.** macOS 27 asks the user before an app reads what another app copied, unless the app is set to Allow in Privacy & Security → Paste from Other Apps. `NSPasteboard.accessBehavior` says which. Clipboard History reads while it is Allow, or while macOS has never asked (macOS then asks once and lists Oriel). It stops while macOS would ask every time, counts the copies it missed, and says so in the panel and Settings. The first time the user lets a copy through, Oriel opens that pane once (PLAN §7.9 item 4, `docs/os-quirks.md`).
- **Secrets (rule 7).** Clipboards hold passwords and tokens, so everything is sealed with AES-GCM under a key in the Keychain, and the folder is excluded from backups. Copies marked concealed or transient by password managers (nspasteboard.org) are never read, and Keychain Access, Passwords, 1Password, Bitwarden and KeePassXC are ignored by default. Logs never contain copied content.
- **AppKit for panels (rule 4).** The panel is a non-activating `FloatingPanel` that takes keyboard input, so the app the user was in stays active and its field gets the paste. Only Settings is SwiftUI.
- **No private API, no new dependency.** CryptoKit and Carbon's `UCKeyTranslate` (the key that types "v" in the current layout) are public system frameworks.

## Deviations from PLAN.md and CLAUDE.md (amended in plan 2.6)

1. **CLAUDE.md rule 8** listed three ways to check a permission. Paste from Other Apps can only be checked with `NSPasteboard.accessBehavior`, so rule 8 (and its copy in PLAN Appendix B) now names it. This is a change to a hard rule: revert those two lines if you would rather decide it differently.
2. `PermissionKind` gains `.pasteboard`, although it is pasteboard privacy rather than a TCC service Oriel checks, so that it appears in onboarding and Settings → Permissions with the others.
3. PLAN §17 had clipboard history among the 2.x tools; it is §7.9 now.
4. Both requests ship in 0.1.0 rather than in a release of their own, at your request. The `v0.1.0` tag moved to the commit that includes them, which supersedes the first 0.1.0 build (build 20).

## Not verified here, and how to finish

Nothing that reads the real clipboard or posts ⌘V was run here. Reading would have made macOS ask about "Oriel Debug" on your screen, and ⌘V would have typed into whatever app was in front. `docs/qa-checklists.md` item 14 covers these, with the installed app:

1. The first copy in another app: macOS asks, Oriel opens Paste from Other Apps once, and with Oriel set to Allow every copy is kept (`oriel debug clipboard` shows `access: allowed`). Check whether the setting applies at once or only after reopening Oriel; the pane suggests the latter can happen.
2. Pasting into VS Code, a Messenger chat and Chrome's search field with Return, a double-click and ⌘1–⌘9, and typing in the panel's search field with your usual input source (Vietnamese Telex too).
3. ⌥V on your keyboard layout. On a US layout it types "√", which Oriel now takes; pick another shortcut if you type it.
4. A screenshot followed by Esc on Quick Access is first in the history.

## Open questions

- Is ⌥V the default you want, given that it takes "√"? ⌃⌥V or ⇧⌘V are free on most Macs.
- The defaults are 500 items, 30 days and 500 MB. Screenshots take most of the space, so the 500 MB usually decides; the oldest history items go first. Settings shows the size used.
- "Remove items after pasting" leaves pinned items alone, since pinning means "keep". Should it remove them too?

## What you need to do

Install `dist/Oriel-0.1.0.dmg` and run `docs/qa-checklists.md` item 14. Settings → About shows build 26; build 20 is the first 0.1.0 build, without these changes.

## Review outcome

2026-10-29. You tested build 26 and kept everything as built: ⌥V stays the shortcut, the limits stay 500 items, 30 days and 500 MB, and Remove items after pasting still leaves pinned items alone. Item 13.8 is ticked.

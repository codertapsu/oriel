# Manual QA checklists

## First look at a new build (about 20 minutes)

On the installed app, screen unlocked, after granting Accessibility and Screen & System Audio Recording (quit and reopen after the second):

1. **Install.** Open the dmg on a Mac that did not build it: no Gatekeeper warning; the welcome window lists the permissions and **Done** closes it.
2. **Move to Applications.** With no Oriel in Applications, open Oriel straight from the mounted dmg and choose **Move to Applications**: a moment later exactly one Oriel runs, from /Applications (`pgrep -lf Oriel`), with its menu-bar icon.
3. **Menu bar.** The bay-window icon opens a menu with every action and its shortcut (Capture with Timer, Record Window and Pinned among them); Settings opens on General.
4. **Switcher.** Hold ⌥, press ⇥ repeatedly, release: the selected window comes forward. Type to search, Esc cancels, a minimized window comes back when chosen, and a window on another Space switches Spaces. With two displays, set Settings → Window Switcher → Show on to "Display with the active window": the switcher opens on the display of the app in front, wherever the pointer is.
5. **Capture Area (⌃⇧4).** The screen freezes; drag, nudge with the arrows, press Return. The Quick Access Overlay appears; try Copy, Save, Pin (it floats; menu → Pinned lists it and brings it to the front; Close All Pins closes it) and Copy Text on a capture with text.
6. **Live capture.** Turn off Settings → Capture → Freeze the screen while selecting, play a video, Capture Area: the video keeps playing while you drag, there is no loupe, and the shot shows the frame at Return, without the overlay's dimming. Turn the setting back on.
7. **Capture with Timer** (menu): open a menu in another app during the countdown; the area selection then shows it, and so does the shot. The countdown's Cancel button stops it.
8. **Editor.** Annotate from the overlay: add an arrow, text, a blur and a crop; undo and redo; ⌘Y shows the result in Quick Look (Esc closes it); ⌘E exports a PNG; ⌘S saves an `.oriel` file that opens again from Finder.
9. **Window and screen (⌃⇧5, ⌃⇧3); scrolling (⌃⇧6)** on a long Safari page: one tall image without repeated rows.
10. **Recording (⌃⇧R).** Select an area, record 5 s with the control bar's pause in the middle, stop: the finished panel plays it, trims it and exports a GIF. Then **Record Window** (menu): click a window, record a few seconds with a click or two, stop: the movie shows that window's area, with the click rings.
11. **Translate Area (⌃⇧T)** on English text with Japanese as the target: blocks fill in over the text; ⌥ peeks at the original; with no language pack, Oriel offers the download.
12. **Google glossary** (needs a Google Cloud project with a glossary): Settings → Translation → Google → enter the glossary, **Add Service Account Key…** with the key's JSON file; Test Connection reports the glossary's entries, and a translation uses its terms.
13. **Settings.** Every pane opens; change a shortcut in Shortcuts and use it; Advanced → Diagnostics → Copy as JSON.
14. **Clipboard History.** Copy text in Safari: macOS asks whether Oriel may paste from Safari; choose Allow. Oriel opens Paste from Other Apps once; set Oriel to Allow. Then copy text in Safari, an image in Preview, a file in Finder, `#FF8800` and a link. In VS Code, press ⌥V: the panel opens over VS Code with "Paste to Code" and the newest copy selected; each preview shows its kind. Return pastes into the editor; ⌥V again, ⌘2 pastes the second item; in a Messenger chat and in Chrome's search field Return pastes too. Search finds the text inside the copied image. Pin an item (⌘P), drag it within Pinned, delete one (⌘⌫) and Undo; ⌥⌘↓ moves an item. Copy in 1Password: nothing new appears. Capture Area, then Esc on Quick Access: ⌥V lists the screenshot first. Turn on Settings → Clipboard History → Remove items from the history after pasting them: a pasted item leaves the list, a pinned one stays. `oriel debug clipboard --json` shows `access: allowed` and the counts.
15. **CLI.** Advanced → Command-line tool → Install, then `oriel windows list`, `oriel capture area --rect 100,100,400,300 --to clipboard` and `oriel capture area --rect 100,100,400,300 --delay 3 --to clipboard` (a countdown first) in Terminal.
16. **Quit** from the menu; ⌘⇥ and the shortcuts belong to the system again.

## Release QA script (PLAN §14.6)

60+ windows across four Spaces and two displays; full-screen Safari video; Electron apps (Slack, VS Code); a Java app; a VM app on the exception list; Sticky Keys on; Reduce Transparency on; Screen Recording denied; Accessibility revoked mid-session; sleep/wake; display unplug while the switcher is open; 48 h soak with memory sampling (`footprint` every 10 min).

## Runs

Record every run here, including the clean macOS 26 VM install through the tap (PLAN §13.7): date, Oriel version, Mac and macOS build, result per item, and anything that failed.

| Date | Oriel version | Mac / macOS build | Result | Notes |
|---|---|---|---|---|

# Oriel user guide

Oriel lives in the menu bar (the bay-window icon) and has no Dock icon. It has three tools:

- the **window switcher**, which finds the right window, including minimized, hidden and other-Space ones;
- the **snipping tool**: screenshots, screen recordings, an annotation editor, pins and history;
- **screenshot translation**: select text anywhere on screen and read it in another language.

## Installing

1. Open `Oriel-<version>.dmg` and drag **Oriel** to **Applications**.
2. Open Oriel from Applications. If you open it from the disk image instead, it offers to move itself; accept.
3. A welcome window lists the permissions. Grant what you want to use, then press **Done** or **Continue without**:

| Permission | Needed for | Without it |
|---|---|---|
| Accessibility (required; on macOS 27 the pane is called **Device Control and Data Access**) | Window switcher, taking over ⌘⇥, scrolling capture, keystrokes in recordings | The switcher cannot list or focus windows |
| Screen & System Audio Recording | Screenshots, recordings, window thumbnails, text to translate | No capture; the switcher shows icons and titles only |
| Microphone | Your voice in recordings | Recordings without the microphone |
| Camera | The camera bubble in recordings | No camera bubble |

After granting Screen Recording, quit Oriel (menu → Quit Oriel) and open it again. macOS asks from time to time whether Oriel may still record the screen; that is the system, not Oriel, and only a management (MDM) profile can switch it off.

To start Oriel at login, open Settings → General → **Open Oriel at login**.

## Global shortcuts

All of them can be changed in Settings → Shortcuts. Click a field, type the new combination; Esc cancels and Delete clears it. These shortcuts need no permission.

| Action | Default |
|---|---|
| Capture Area | ⌃⇧4 |
| Capture Window | ⌃⇧5 |
| Capture Screen | ⌃⇧3 |
| Scrolling Capture | ⌃⇧6 |
| Record Area (press again to stop) | ⌃⇧R |
| Translate Area | ⌃⇧T |
| Capture Previous Area, Capture with Timer, Capture All Displays, Record Window, Record Screen, Capture History | none |

The window switcher has its own shortcuts in Settings → Switcher; the default is ⌥⇥.

## Window switcher

Hold ⌥ and press ⇥ to open the switcher with the most recently used windows; keep pressing ⇥ (⇧⇥ goes back) and let go of ⌥ to switch.

- **While it is open:** arrows move; typing searches titles and app names; Return switches; Esc cancels; 1–9 select a window and switch to it at once; Space switches while the search field is empty.
- **Acting on a window:** with ⌘, ⌥ or ⌃ held, W closes it, M minimizes it, F toggles full screen and Q quits the app; plain letters always go to the search. Hovering a thumbnail shows the same buttons.
- **Badges** show minimized, hidden, full-screen and other-Space windows ("Space 2"). A large preview of the selected window appears behind the switcher.
- **Styles:** thumbnails, app icons, or a compact list of titles. Each of up to nine shortcuts can have its own style and filters (this app only, this Space, this screen, include minimized or hidden).
- **Keep open:** a shortcut can stay open after you let go, so you choose with the arrows and Return. It is always on while Sticky Keys is on.
- **⌘⇥ takeover:** in Settings → Switcher, bind a shortcut to ⌘⇥ to replace the system app switcher; it is restored when Oriel quits.
- **Three-finger swipe:** swipe sideways to switch. In System Settings → Trackpad → More Gestures, move "Swipe between full-screen applications" to four fingers first.
- **Exceptions:** per app (by bundle ID), either hide its windows from the switcher, or let ⌥⇥ pass through to it while it is in front. Virtual machines and remote desktops pass through by default, so ⌥⇥ reaches the guest.
- **Where it opens:** Settings → Window Switcher → Show on: the display under the pointer (the default), the display with the active window, or the main display. "This screen" filters mean that display.
- If focusing a window on another Space does nothing, turn on System Settings → Desktop & Dock → "When switching to an application, switch to a Space with open windows".

## Screenshots

- **Capture Area (⌃⇧4):** the screen freezes; drag a rectangle, or click a window to select exactly that window's area. A loupe shows the pixels under the pointer with their colour. Arrows nudge the selection by a point (⇧ for ten); ⌥+arrows resize it; hold Space while dragging to move it; edges snap to windows. Return captures, ⌘C copies straight away, ⌘S saves straight away, Esc cancels.
- **Capture Window (⌃⇧5):** hover a window and click it. The capture is the window itself, with its shadow if you want.
- **Capture Screen (⌃⇧3):** click a display.
- **Capture with Timer:** counts down (Settings → Capture → Timer: 3, 5 or 10 seconds), then opens the area selection, so a menu you open during the countdown stays in the shot. The countdown's Cancel button stops it.
- **Capture Previous Area** captures the last area again without asking; **Capture All Displays** captures every display in one image. Both, and the timer, are in the menu and can have a shortcut.
- **Video:** the frozen screen keeps menus and hover states, but stops a video. Turn off Settings → Capture → **Freeze the screen while selecting**, and the screen keeps playing while you select; Oriel captures it when you finish. Open menus close when the selection starts, and there is no loupe.

After a capture, the **Quick Access Overlay** appears in a corner. It offers Copy, Save, Annotate (opens the editor), Translate, Pin (keeps the image floating above everything), Upload and Copy Text (OCR). You can also drag the thumbnail into any app. It goes away after a few seconds, or stays while the pointer is over it. Settings → Capture chooses what happens after a capture, the folder and file name, the format (PNG, JPEG, HEIC), sounds and history.

**Scrolling capture (⌃⇧6):** select the scrolling area. Oriel scrolls it and stitches the frames into one tall image. If an app ignores scrolling, choose manual mode and scroll yourself.

**Pins** float above everything: drag to move, scroll to change the opacity, and use the buttons on hover to lock one or let clicks through. Menu → **Pinned** lists them: choose one to bring it to the front, or Close All Pins.

**History** (menu → Capture History) keeps recent captures, searchable by the text in them.

## Editor

Choose Annotate in the overlay, or menu → Open Image in Editor….

- **Tools, by key:** V select, A arrow, L line, R rectangle, O ellipse, P pen, H highlighter, T text, N numbered steps, B blur, X pixelate, S spotlight, C crop. The background tool adds padding, a gradient and a shadow.
- **Keyboard:** ⌘Z and ⇧⌘Z undo and redo, ⌘C copies the result, ⌘E exports (PNG, JPEG, HEIC, PDF), ⌘S saves an editable `.oriel` file, ⌘Y shows the result in Quick Look (or click the eye), and Delete removes the selected item.

## Screen recording

- **Starting:** Record Area (⌃⇧R) asks for an area; Record Window asks you to click a window and records the area it covers (it does not follow the window if you move it); Record Screen records the display under the pointer.
- **The control bar** shows the elapsed time, pause and stop; pressing the shortcut again also stops.
- **Settings → Recording:** quality (Standard, High, Small), system audio, microphone, camera bubble, click rings and the keystroke display.
- **When it is done**, a panel lets you play, trim, export a GIF, reveal the file or copy it.

## Translation

Translate Area (⌃⇧T): select text on screen and the translation is drawn over the original, block by block, as it arrives; blocks still waiting have a dashed outline. Hold ⌥ to peek at the original, and click a block to copy its translation.

- **The toolbar** switches provider (or ⌘1…⌘9) and target language, swaps languages, copies everything, opens the side panel with source and translation side by side, and offers **AI Vision**, which sends the image itself to a vision-capable model, for stylized or vertical text.
- **Providers:** Apple Translation (on-device, offline once the language pack is downloaded; Oriel offers to download it), a local LLM (Ollama, LM Studio, llama.cpp — any OpenAI-compatible endpoint), Apple's Foundation Models (Apple silicon with Apple Intelligence on), OpenAI, Anthropic, Google Translate and DeepL.
- **Settings → Translation** sets up each provider: endpoint, model, API key (kept in your keychain) and **Test connection**. It also sets the default target language, usage limits and history.
- **Google glossaries:** enter a Cloud Translation glossary under Google, by its full name (`projects/…/locations/…/glossaries/…`) or by its ID (looked for in `us-central1` of the key's project), then **Add Service Account Key…**: the JSON key file from the Google Cloud console, which goes into your keychain. Glossaries need Cloud Translation Advanced, which does not accept API keys; without a glossary Google uses the API key as before. Test connection reads the glossary.
- **Intel Macs:** a model running on the Mac itself (an endpoint on `localhost`) is very slow on an Intel processor, and Settings says so; Apple Translation or a model server on another Mac is much faster.

## Upload

In Settings → Upload, enter an S3-compatible bucket: AWS S3, MinIO, Cloudflare R2 or Backblaze B2. **Upload** in the overlay or the editor then sends the image and copies a link. The secret key is kept in your keychain, and object names are random, so links cannot be guessed.

## Command line

Settings → Advanced → Command-line tool → **Install** adds `oriel` to `~/.local/bin`, or to `/usr/local/bin` after asking for your password. Oriel must be running.

```bash
oriel windows list [--json] [--space current|all] [--app <bundle-id>]
oriel windows focus <window-id> | --title <text>
oriel windows close|minimize <window-id>
oriel capture area|window|screen [--rect x,y,w,h] [--delay <seconds>] [--to clipboard|file|editor] [--path <file>]
oriel translate area [--rect x,y,w,h] [--to <language>] [--provider <id>] [--json]
oriel debug capabilities --json
```

`--delay` (1 to 60 seconds) shows a countdown before capturing.

Oriel also opens URLs: `oriel://capture/area`, `oriel://capture/window`, `oriel://capture/screen`, `oriel://capture/scrolling`, `oriel://capture/previous`, `oriel://capture/timer`, `oriel://capture/all`, `oriel://record/area`, `oriel://record/window`, `oriel://record/screen`, `oriel://record/stop`, `oriel://translate/area`, `oriel://history`, `oriel://settings`. For example: `open oriel://capture/area`.

## Shared team configuration

A `bootstrap.json` in `~/Library/Application Support/Oriel/` is imported on the next launch and then deleted. Its format is in `docs/bootstrap.example.json`. It holds the translation providers, the default provider and the upload destination, keys included, which go into the keychain. A Google provider can also have `"glossary"` and `"serviceAccountKey"` (the key file's JSON object pasted in as it is). Settings → Advanced → **Reload shared configuration** imports it again. A managed `BootstrapURL` preference can point at an internal HTTPS copy instead.

## Troubleshooting

| Problem | What to do |
|---|---|
| A shortcut does nothing | Settings → Shortcuts shows ⚠︎ when another app owns the combination. Pick another. |
| The switcher shows no windows or cannot switch | Grant Accessibility (Settings → Permissions). If Oriel is already switched on in System Settings → Privacy & Security → Device Control and Data Access (Accessibility before macOS 27) but Settings → Permissions still says it is missing, select Oriel there, remove it with −, and add it again with +: the switch belonged to another copy of Oriel. |
| Captures are black or show only the desktop | Grant Screen Recording, then quit and reopen Oriel. |
| Translation says the language pack is missing | Accept the download Oriel offers, or download it in System Settings → General → Language & Region → Translation Languages. |
| A local model does not answer | Check that Ollama/LM Studio is running and the endpoint in Settings → Translation (e.g. `http://localhost:11434/v1`); use Test connection. |
| Diagnostics for a bug report | Settings → Advanced → Diagnostics → Copy as JSON, or `oriel debug capabilities --json`. |

To remove Oriel completely, use Settings → Advanced → **Uninstall Oriel…**. It removes settings, history, saved keys, the login item and the CLI link.

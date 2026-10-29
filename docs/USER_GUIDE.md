# Oriel user guide

Oriel lives in the menu bar (the bay-window icon) and has no Dock icon. It has nine tools:

- the **window switcher**, which finds the right window, including minimized, hidden and other-Space ones;
- the **snipping tool**: screenshots, screen recordings, an annotation editor, a video editor, pins and history;
- **screenshot translation**: select text anywhere on screen, rest the pointer on it, or drop in a whole file, and read it in another language;
- **Clipboard History**: everything you copy, searchable on ⌥V and pasted straight into the app you are in;
- **Disk Space Analyzer**: where the space on your drives goes, and safe ways to get it back;
- **Activity Monitor**: what every app and process on your Mac is using;
- **Color Picker**: any color on screen in every format, with palettes and a contrast checker;
- **Screen Ruler**: measure anything on screen, to the pixel;
- **Window Tiling**: arrange the window you are in from the keyboard.

Settings → General → Tools turns the window switcher, Clipboard History and the last five on and off. A tool that is off uses no memory, keyboard tap or observers, and leaves its shortcuts to other apps.

## Installing

1. Open `Oriel-<version>.dmg` and drag **Oriel** to **Applications**.
2. Open Oriel from Applications. If you open it from the disk image instead, it offers to move itself; accept.
3. A welcome window lists the permissions. Grant what you want to use, then press **Done** or **Continue without**:

| Permission | Needed for | Without it |
|---|---|---|
| Accessibility (required; on macOS 27 the pane is called **Device Control and Data Access**) | Window switcher, taking over ⌘⇥, scrolling capture, keystrokes in recordings, pasting from Clipboard History, Window Tiling, Focus Window in the Shortcuts app | The switcher cannot list or focus windows; Clipboard History copies instead of pasting; Window Tiling shows a message instead of moving the window |
| Screen & System Audio Recording | Screenshots, recordings, window thumbnails, text to translate, Translate Under Cursor, the Screen Ruler finding edges | No capture; the switcher shows icons and titles only; the Screen Ruler measures without finding edges |
| Microphone | Your voice in recordings | Recordings without the microphone |
| Camera | The camera bubble in recordings, and its background blur | No camera bubble |
| Paste from Other Apps | Clipboard History keeping what you copy in other apps (macOS lists Oriel here after it has asked once) | Clipboard History keeps only Oriel's own copies, such as screenshots |
| Full Disk Access (optional, not in the welcome window: Disk Space Analyzer offers it when a scan could not read some folders) | Disk Space Analyzer counting every folder, other apps' data, Mail, Messages and Safari included | Those folders are counted as "couldn't be read" |

After granting Screen Recording, quit Oriel (menu → Quit Oriel) and open it again. macOS asks from time to time whether Oriel may still record the screen; that is the system, not Oriel, and only a management (MDM) profile can switch it off.

Some questions come up only when you use a tool. The first time Disk Space Analyzer reads your Desktop, Documents or Downloads folder, an external or network drive or a cloud folder, macOS asks whether Oriel may (see [Disk Space Analyzer](#disk-space-analyzer)), and settings sync may ask once to use iCloud Drive. Activity Monitor and Color Picker need no permission at all.

To start Oriel at login, open Settings → General → **Open Oriel at login**.

## Global shortcuts

All of them can be changed in Settings → Shortcuts, where each tool's commands are listed under its name while the tool is on. Click a field, type the new combination; Esc cancels and Delete clears it. These shortcuts need no permission.

| Action | Default |
|---|---|
| Capture Area | ⌃⇧4 |
| Capture Window | ⌃⇧5 |
| Capture Screen | ⌃⇧3 |
| Scrolling Capture | ⌃⇧6 |
| Instant Capture | ⌃⇧2 |
| Capture Text | ⌃⇧O |
| Record Area (press again to stop) | ⌃⇧R |
| Translate Area | ⌃⇧T |
| Translate Under Cursor (press again to stop) | ⌃⇧U |
| Clipboard History | ⌥V |
| Pick Color | ⌃⇧C |
| Screen Ruler (press again to close) | ⌃⇧M |
| Window Tiling | ⌃⌥ with an arrow, a letter, Return, Delete, - or =, and ⌃⌥⌘ with ← or → (see [Window Tiling](#window-tiling)) |
| Capture Previous Area, Capture with Timer, Capture All Displays, Start Step Capture, Record Window, Record Screen, Open Video…, Translate File…, Capture History, Disk Space Analyzer and its Scan Folder…, Activity Monitor, Color Picker, Almost Maximize | none |

The window switcher has its own shortcuts in Settings → Window Switcher; the default is ⌥⇥. ⌥V types "√" on a US keyboard, and some keyboard layouts use ⌥ for letters; if you need ⌥V for typing, give Clipboard History another shortcut. A tool's shortcuts are free for other apps while the tool is turned off.

## Window switcher

Hold ⌥ and press ⇥ to open the switcher with the most recently used windows; keep pressing ⇥ (⇧⇥ goes back) and let go of ⌥ to switch.

- **While it is open:** arrows move; typing searches titles and app names; Return switches; Esc cancels; 1–9 select a window and switch to it at once; Space switches while the search field is empty.
- **Acting on a window:** with ⌘, ⌥ or ⌃ held, W closes it, M minimizes it, F toggles full screen and Q quits the app; plain letters always go to the search. A line under the windows shows these keys (Settings → Window Switcher → Appearance turns it off). Hovering a thumbnail shows the same buttons.
- **Badges** show minimized, hidden, full-screen and other-Space windows ("Space 2"). A large preview of the selected window appears behind the switcher.
- **Styles:** thumbnails, app icons, or a compact list of titles. Each of up to nine shortcuts can have its own style and filters (this app only, this Space, this screen, include minimized or hidden).
- **Presets:** each shortcut in Settings → Window Switcher shows what it lists, chosen next to its keys: **All windows**, **Active app's windows**, **Windows grouped by app** or **This display's windows**. Open the row to fine-tune it (Spaces, minimized and hidden windows); a mix no preset names shows as Custom.
- **Grouped by app:** each app's windows sit together under the app's name, apps in the order you last used them. A quick ⌥⇥ still switches to the window you used before.
- **Keep open:** a shortcut can stay open after you let go, so you choose with the arrows and Return. It is always on while Sticky Keys is on.
- **⌘⇥ takeover:** in Settings → Window Switcher, bind a shortcut to ⌘⇥ to replace the system app switcher; it is restored when Oriel quits.
- **Three-finger swipe:** swipe sideways to switch. In System Settings → Trackpad → More Gestures, move "Swipe between full-screen applications" to four fingers first.
- **Exceptions:** per app (by bundle ID), either hide its windows from the switcher, or let ⌥⇥ pass through to it while it is in front. Virtual machines and remote desktops pass through by default, so ⌥⇥ reaches the guest.
- **Where it opens:** Settings → Window Switcher → Show on: the display under the pointer (the default), the display with the active window, or the main display. "This screen" filters mean that display.
- If focusing a window on another Space does nothing, turn on System Settings → Desktop & Dock → "When switching to an application, switch to a Space with open windows".

## Screenshots

- **Capture Area (⌃⇧4):** the screen freezes; drag a rectangle, or click a window to select exactly that window's area. A loupe shows the pixels under the pointer with their colour. Arrows nudge the selection by a point (⇧ for ten); ⌥+arrows resize it; hold Space while dragging to move it; edges snap to windows. Return captures, ⌘C copies straight away, ⌘S saves straight away, Esc cancels.
- **Capture Window (⌃⇧5):** hover a window and click it. The capture is the window itself, with its shadow if you want.
- **Capture Screen (⌃⇧3):** click a display.
- **Capture with Timer:** counts down (Settings → Capture → Timer: 3, 5 or 10 seconds), then opens the area selection, so a menu you open during the countdown stays in the shot. The countdown's Cancel button stops it.
- **Capture Previous Area** captures the last area again without asking; **Capture All Displays** captures every display in one image. The timer and Capture Previous Area are in the menu, Capture All Displays opens with `oriel://capture/all`, and all three can have a shortcut.
- **Video:** the frozen screen keeps menus and hover states, but stops a video. Turn off Settings → Capture → **Freeze the screen while selecting**, and the screen keeps playing while you select; Oriel captures it when you finish. Open menus close when the selection starts, and there is no loupe.
- **Capture Text (⌃⇧O):** drag over text anywhere on screen, or click a window to read all of it. Oriel reads it on this Mac and copies it with its line breaks, and a short message shows the start of what was copied, or says that no text was found. Columns are read one after the other, tables row by row with tabs between the cells (so they paste into a spreadsheet), and a word split by a hyphen at the end of a line is joined again. Hold **⇧** as you let go to correct the text in a small window first, then press **Copy** (⌘Return); Settings → Capture → **Open captured text for editing** makes that the default, and ⇧ then copies straight away. The first time after Oriel opens, reading can take a few seconds while macOS loads its text recognition.
- **Instant Capture (⌃⇧2):** drag over an area and draw on it where it is: the capture stays in place with a toolbar beside it, and the app you were in stays in front. The tools have the editor's keys (V select, P pen, A arrow, L line, R rectangle, O ellipse, H highlighter, T text, N step, B blur, X pixelate), and the colour button sets the colour and width. **Return** or **⌘C** copies the result and closes; **⌘S** saves it; **Upload** sends it when a destination is set up; **⌘E** opens it in the full editor with everything you drew, Undo included; **Esc** closes without keeping it.
- **Hide desktop icons and widgets** (Settings → Capture, off by default): captures of an area or a screen show your wallpaper without the desktop's icons and widgets, and so does the frozen screen while you select. Finder is not changed. Window captures, recordings and translation are not affected.

Every capture is copied to the clipboard straight away (Settings → Capture → **Copy every capture to the clipboard**, on by default), so you can paste it at once, and it is kept in [Clipboard History](#clipboard-history) however you close the overlay. After a capture, the **Quick Access Overlay** appears in a corner. It offers Copy (copies it again, say after you copied something else), Save, Annotate (opens the editor), Translate, Pin (keeps the image floating above everything), Upload and Copy Text (OCR). You can also drag the thumbnail into any app. It goes away after a few seconds, or stays while the pointer is over it. Settings → Capture chooses what happens after a capture, the folder and file name, the format (PNG, JPEG, HEIC), sounds and history.

**Scrolling capture (⌃⇧6):** select the scrolling area. Oriel scrolls it and stitches the frames into one tall image. If an app ignores scrolling, choose manual mode and scroll yourself.

**Pins** float above everything. Drag a pin to move it, scroll or pinch over it to zoom, and hold **⌥** while scrolling to change its opacity. With the pin in front, the number keys set the opacity (1 is 10 %, 0 is 100 %), ⌘+, ⌘− and ⌘0 zoom, the arrows move it, ⌘C copies, ⌘S saves and ⌘W closes. Its context menu has an opacity slider, Click-Through, Lock Position, Border and Shadow, zoom, Copy, Save, Annotate and Close. **Click-through** lets your clicks go to the window under the pin, for tracing or comparing. To get the pin back, click the round button at its corner, hold **⌥⌘** with the pointer over it (it outlines itself and takes clicks until you let go), or use menu → **Pinned**: each pin has a submenu with the same commands, and **Stop Click-Through on All Pins** appears while any pin lets clicks through. Pinned also brings a pin to the front, and closes all of them.

**History** (menu → Capture History) keeps recent captures, searchable by the text in them, even in long scrolling captures. While you search, each capture shows the words it was found by, in their sentence. Text is read in the background after each capture; captures from before are read the first time you open the history.

## Step Capture

For guides and bug reports: menu → **Start Step Capture**. A small bar appears at the top of the screen. From now on every capture, with any shortcut or mode, becomes the next numbered step, and Quick Access stays closed; **Add Step** on the bar captures an area. With **Mark clicks** on, a red ring marks where you clicked last before each capture.

Choose **Finish** (or menu → **Finish Step Capture**) to see the steps in a window: give each a title and a note, drag them into order, delete one with ⌫, **Retake** one, or **Annotate** it in the editor; when you are done in the editor, drag the result onto the step, or copy it (⌘C) and paste it onto the step (⌘V). Undo works for all of these. **Export** makes one tall image, a PDF with a page per step, Markdown with a folder of images, or a single web page. The steps are deleted when you close the window, so export them first; Oriel asks if you have not.

**Cancel** on the bar ends Step Capture and deletes its steps, after asking. Closing the bar with × does not end it: the next captures are still steps, and Finish Step Capture is in the menu.

## Clipboard History

Oriel keeps what you copy: text, formatted text, links, colors, images, files and other data. Press **⌥V** (Settings → Shortcuts), or choose Clipboard History in the menu, to open it over the app you are in.

- **Find:** type to search everything you copied, including the text inside copied images; the menu next to the search field shows one type (Pinned, Text, Images, Files, Links, Colors). ↑ and ↓ move, ⇧↑ and ⇧↓ select several.
- **Preview:** click an item to see it in full on the right: the whole text, the image, the color in HEX, RGB and HSL, a link with Open Link, or the files with Show in Finder.
- **Paste:** **Return**, a double-click or **Paste to *App*** pastes the item into the field you were typing in (VS Code, a Messenger chat, a Chrome search box…). **⌥Return** pastes text without its formatting (or with it, when Settings says plain text). **⌘1**–**⌘9** paste the first nine items. **⌘C** or **Copy** only puts the item on the clipboard. Several selected items paste as their texts on separate lines.
- **Organize:** **⌘P** pins an item (pinned items stay at the top and are never removed by the limits); drag items to reorder them, or into Pinned to pin them; **⌥⌘↑/↓** move the selection; **⌘⌫** or the bin deletes it, and **Undo** (⌘Z) brings it back until the panel closes. The ⋯ menu pauses the history and clears it (pinned items stay). Drag an item into another app to drop it there.
- **Esc** clears the search, then closes; clicking elsewhere closes too.

Every screenshot is copied to the clipboard as well (Settings → Capture → Copy every capture to the clipboard), so it is in Clipboard History even if you close Quick Access with Esc.

**Two permissions make it complete.** Pasting into another app needs **Accessibility** (without it, Oriel copies the item and you press ⌘V). Keeping what you copy *in other apps* needs **Paste from Other Apps**: the first time you copy in another app, macOS asks whether Oriel may paste from it; choose Allow, then set Oriel to **Allow** in System Settings → Privacy & Security → Paste from Other Apps (Oriel opens it for you once), so macOS stops asking. Until then, only Oriel's own copies, such as screenshots, are kept, and the panel says how many copies it missed.

**Privacy.** The history stays on this Mac, encrypted, with the key in your keychain. Copies that password managers mark as concealed are never kept, nor anything copied in Keychain Access, Passwords, 1Password, Bitwarden or KeePassXC; Settings → Clipboard History edits that list. Settings also sets how many items to keep (500 by default), for how long (30 days) and how much space they may take (500 MB; the oldest go first, pinned items stay), removes items once pasted if you like, and pauses or clears the history. Settings → General → Tools turns Clipboard History off altogether.

## Editor

Choose Annotate in the overlay, or menu → Open Image in Editor….

- **Tools, by key:** V select, A arrow, L line, R rectangle, O ellipse, P pen, H highlighter, T text, N numbered steps, B blur, X pixelate, S spotlight, C crop. The background button adds padding, a backdrop and a shadow (below).
- **Keyboard:** ⌘Z and ⇧⌘Z undo and redo, ⌘C copies the result, ⌘E exports (PNG, JPEG, HEIC, PDF), ⌘S saves an editable `.oriel` file, ⌘Y shows the result in Quick Look (or click the eye), ⇧⌘R starts Smart Redact, and Delete removes the selected item.

**Backgrounds.** The background button opens the backgrounds; each tile shows your screenshot on that background. Below them:

- **Fill:** Clear, Solid, Linear and Radial gradients (pick the two colours; Linear has an angle), or Picture: your **Desktop Picture** or **Choose…** any image, with a blur. Oriel reads the desktop picture only from folders that need no permission; if yours is in Desktop, Documents or Downloads, choose it as an image instead.
- **Layout:** padding; **inset**, a margin in the colour of the screenshot's edges; **aspect**: Auto, 16:9, 4:3, 1:1, 4:5, 9:16, 3:2, the sizes social networks ask for (X 1200 × 675, LinkedIn 1200 × 627, Instagram 1080 × 1080 and 1080 × 1350) or a custom size, which the export then has exactly; **position** places the screenshot when the aspect leaves room.
- **Card:** corner radius, a light or dark **window frame** with the three lights, and the shadow's blur, opacity and offset.
- **My backgrounds:** **+** saves the current background with its padding; right-click a saved one to delete it.

**Numbered steps.** Choose the step tool (N) and click: steps number themselves. The step options next to the width set the shape (circle or square), the labels (1 2 3, A B C, a b c, I II III) and a pointer. With the pointer on, drag from what the step points at to where the number should sit; drag the tip of a selected step to aim it again. **Restart at 1** starts a new series, and the stepper starts it at any number, say to go on from a previous screenshot. Deleting a step renumbers the rest of its series. The arrow keys move the selected steps; the toolbar's colour and width set their colour and size.

**Smart Redact, Simplify and Smart Move** read the screenshot on your Mac; nothing leaves it.

- **Smart Redact (⇧⌘R, the crossed-out eye):** finds keys and tokens, card numbers, bank accounts (IBAN), email addresses, phone numbers, IP addresses and links in the text, and outlines them. Switch categories off (links start off), choose Blur or Pixelate, then **Redact**; it is one step to undo. Check the result: text that OCR cannot read (very small, stylized or low-contrast) is not found.
- **Simplify (the lines button):** turns every line of text into a bar in its colour and, if you like, tones the rest down, for a clean diagram.
- **Smart Move (the wand):** lifts blocks of text, objects and regions out of the screenshot, so you can drag, resize or delete them; Oriel fills in where they were. It works best on flat backgrounds, such as app windows.

An `.oriel` file saved by this version does not open in the earlier 0.1.0 build (build 26); files saved by that build open as before.

## Screen recording

- **Starting:** Record Area (⌃⇧R) asks for an area; Record Window asks you to click a window and records the area it covers (it does not follow the window if you move it); Record Screen records the display under the pointer.
- **The control bar** shows the elapsed time, pause and stop; pressing the shortcut again also stops.
- **Settings → Recording:** quality (Standard, High, Small), system audio, microphone, camera bubble, click rings and the keystroke display.
- **When it is done**, a panel plays the movie and offers **Edit…** (⌘E, the [video editor](#video-editor)), **Trim**, **Export** (a GIF, or a constant-frame-rate copy for video editors), **Copy Text** (the text in the frame shown), **Show in Finder** and **Copy**.
- **Clicks for Auto Zoom:** with Settings → Recording → **Remember clicks for Auto Zoom** on (the default), each recording's clicks are saved next to it in a small file named after it (`….oriel-clicks.json`). Keep the two together when you move the movie.
- **Camera background:** with the camera bubble on, **Portrait effect** shows whether macOS's own background blur is on, and **Video Effects…** opens its controls while a recording shows the bubble. On a Mac with Apple silicon, **Blur camera background** has Oriel blur the room behind you in the bubble, or replace it with a color; it steps aside while the Portrait effect is on, and turns itself off for the rest of a recording if the Mac gets too busy or hot.

## Video editor

Choose **Open Video…** in the menu (or open `oriel://video/open`), press **Edit…** after a recording, or drop a movie on an editor window.

- **Watch and move around:** Space plays and pauses. **J**, **K** and **L** play backward, stop and play forward; press J or L again to go faster. **←** and **→** move one frame, **⇧←** and **⇧→** one second, **Home** and **End** go to the in and out points, and pressed again to the very start and end. Click or drag in the timeline to move the playhead; scroll sideways along it, and pinch, ⌘-scroll or press **⌘=** and **⌘-** to zoom it (**⌘0** shows it all).
- **Trim:** press **I** and **O** at the playhead, or drag the yellow handles; **⌥I** and **⌥O** clear them. What you leave out is dimmed.
- **Zoom in on clicks:** **Auto Zoom** (toolbar or inspector) zooms in on each click of a recording made with Remember clicks on, follows nearby clicks, and zooms back out; set its **Level** and **Hold** first, then press it again to redo it. **Z**, or a double-click in the zoom lane, adds a zoom at the playhead. Drag a zoom to move it and its ends to resize it; in the inspector, set its start, end and level, and drag the area in the picture to choose where it looks. **Delete** removes the selected zoom.
- **Chapters:** **M** adds one at the playhead; rename it in the inspector's list (or double-click its marker), **Delete** removes it, **↑** and **↓** go to the previous and next. Exported movies keep their chapters for QuickTime Player and IINA. **Copy for YouTube** copies them as timestamps for a video description (YouTube wants at least three, each at least 10 seconds long, and the inspector says when they are not).
- **Copy Text from Frame:** **⇧⌘C** (or the toolbar's Copy Text) reads the text in the frame at the playhead, copies it, and shows it so you can copy part of it.
- **Export:** **⌘E** saves an MPEG-4 or QuickTime movie (HEVC or H.264, at the original size, 1080p or 720p) or a GIF, with the trim, zooms and chapters. Undo and redo with ⌘Z and ⇧⌘Z. The editor never changes the movie itself; the edits last until you close the window, and Oriel asks before closing one that you have not exported.

## Translation

Translate Area (⌃⇧T): select text on screen and the translation is drawn over the original, block by block, as it arrives; blocks still waiting have a dashed outline. Hold ⌥ to peek at the original, and click a block to copy its translation.

- **The toolbar** switches provider (or ⌘1…⌘9) and target language, swaps languages, copies everything, opens the side panel with source and translation side by side, and offers **AI Vision**, which sends the image itself to a vision-capable model, for stylized or vertical text.
- **Providers:** Apple Translation (on-device, offline once the language pack is downloaded; Oriel offers to download it), a local LLM (Ollama, LM Studio, llama.cpp — any OpenAI-compatible endpoint), Apple's Foundation Models (Apple silicon with Apple Intelligence on), OpenAI, Anthropic, Google Translate and DeepL.
- **Settings → Translation** sets up each provider: endpoint, model, API key (kept in your keychain) and **Test connection**. It also sets the default target language, the glossary, usage limits and history.
- **Google glossaries:** enter a Cloud Translation glossary under Google, by its full name (`projects/…/locations/…/glossaries/…`) or by its ID (looked for in `us-central1` of the key's project), then **Add Service Account Key…**: the JSON key file from the Google Cloud console, which goes into your keychain. Glossaries need Cloud Translation Advanced, which does not accept API keys; without a glossary Google uses the API key as before. Test connection reads the glossary. A glossary project can name a Cloud glossary too ([Glossaries](#glossaries)).
- **Intel Macs:** a model running on the Mac itself (an endpoint on `localhost`) is very slow on an Intel processor, and Settings says so; Apple Translation or a model server on another Mac is much faster.

### Translate Under Cursor

Press **⌃⇧U** (or menu → Translate Under Cursor), then rest the pointer on text anywhere: a moment later its translation appears below it, with the languages and provider. Move along the text and it stays; move to other text and rest again for that one. A text already in your language shows nothing.

- While it is on, a small icon in the menu bar says so; its menu turns it off. **Esc** or **⌃⇧U** turns it off too (Esc in other apps needs Accessibility).
- It translates the whole paragraph under the pointer; Settings → Translation → Translate Under Cursor can make it the line only, which suits menus and tables.
- Clicking or typing hides the translation until you move the pointer again; scrolling reads the new text.
- It uses the provider and glossary Translate Area would use, and each text is sent once: coming back to it shows the translation at once.
- It reads the screen, so it needs **Screen & System Audio Recording**; without it Oriel says so and offers System Settings.

### Translating files

Menu → **Translate File…**, or drop a file on the Translation side panel or the Translate File window: images, PDFs, text and Markdown, Word (.docx and .doc), RTF and RTFD, OpenDocument text, web pages (.html) and SRT or WebVTT subtitles.

- The window shows each paragraph (or subtitle, or block of an image) with its translation beside it, filling in as it is translated; PDFs page by page, scanned pages through on-device OCR. An image shows its translation drawn over it; switch to Original to compare.
- Change the provider, language or glossary at the top to translate again. **Stop** (⌘.) keeps what is done; **Resume** carries on.
- **Copy All**, ⌘C on selected rows, and **Export**: text, Markdown (keeping headings, lists and code), Markdown with the original above each translation, SRT or WebVTT with the original timing, or the translated image as PNG.
- Long files go out in parts that each provider accepts. Before sending more than 100,000 characters to a provider that may charge for it, Oriel asks. Only the text leaves the Mac, and only for providers that are not on it.

### Glossaries

A glossary keeps names and terms translated the same way. Settings → Translation → Glossary → **Edit Glossaries…**:

1. Add a glossary (+), give it a name, and add a language pair: from English into Japanese, say, or from "Any language" for names that never change.
2. Add terms: the term, its translation, a note if it helps, and Match Case for terms like "Apple". Or **Import…** a CSV or TSV file with the columns source, target, note and case_sensitive (a header in any order, or none).
3. Choose it under **Use glossary** in Settings, the side panel or the file window.

How each provider uses it: DeepL with its own glossaries (Oriel creates and updates them in your DeepL account); language models get the terms that occur in the text; Apple Translation and Google without a Cloud glossary keep the terms with placeholders, which works for most text but cannot adjust the grammar around a term. For Google with a service account key, name a Cloud Translation glossary in the project: export the terms as **CSV for Google Cloud**, put the file in a Cloud Storage bucket, create the glossary in the Google Cloud console, and enter its name or ID.

## Upload

**Upload** in Quick Access, the editor and Instant Capture sends the image to your default destination and copies its link. Set destinations up in Settings → Upload: **Add Destination**, fill it in, **Test Connection**, and choose which one **Upload to** uses. Each destination has its own file name and link format.

| Destination | What you need |
|---|---|
| S3-compatible storage (AWS S3, MinIO, Cloudflare R2, Backblaze B2) | The endpoint, bucket, access key and secret key |
| WebDAV (Nextcloud, ownCloud, a NAS) | The WebDAV address, such as `https://cloud.example.com/remote.php/dav/files/you`, and a user name and password (for Nextcloud, an app password). Missing folders are made |
| SFTP | A server you can already reach with `ssh` using a key. Oriel never uses a password |
| Shared folder | A folder on this Mac or a connected server share, NAS or synced folder (iCloud Drive, Dropbox) |
| Dropbox | A Dropbox app of your own and its app key |
| Google Drive | An OAuth client of your own (type iOS) and its client ID |

- **File name:** `{name}` (the window's title, or the file's name), `{date}`, `{time}` and `{random}`; `/` makes a folder. `{random}/{name}`, the default for most destinations, puts every upload in a folder with a random name, so nobody can guess one link from another.
- **Link:** for WebDAV, SFTP and a shared folder, **Public URL** is the address a web server gives the files, such as `https://files.example.com/{path}`; without one Oriel copies the file's own address. Dropbox links can open Dropbox's page, the file itself or a download; Google Drive links the Drive page or a direct download. **Copy the link as** pastes the link alone, as Markdown or as HTML.
- **While it uploads,** a panel at the bottom of the screen shows the progress; its ⓧ cancels. If something goes wrong, the panel says what to do; select its text to copy a command.
- **Passwords, secret keys and sign-ins** stay in your login keychain. Deleting a destination removes them and signs out of Dropbox or Google Drive.

**SFTP with a key.** In Terminal: `ssh-keygen -t ed25519` if you have no key, `ssh-copy-id you@host` to put it on the server, then `ssh you@host` once to accept the server's key. Oriel reads `~/.ssh/config`, so a `Host` alias works, and connects only to servers in `~/.ssh/known_hosts`. A key with a passphrase works once it is in the agent: `ssh-add --apple-use-keychain ~/.ssh/id_ed25519`, with `UseKeychain yes` in `~/.ssh/config`.

**Dropbox.** At dropbox.com/developers/apps choose **Create App**, **Scoped access** and **App folder** (or Full Dropbox). On its **Permissions** tab tick `files.content.write`, `sharing.write` and `sharing.read`, then **Submit**. Copy the **App key** from its Settings tab into Oriel and **Sign In…**. With App folder, uploads land in Apps → your app's name → the folder you set.

**Google Drive.** In the Google Cloud console make a project and enable the **Google Drive API**. Under **Google Auth Platform**, set up the consent screen for External users and add yourself as a test user. Under **Clients**, create an OAuth client of type **iOS** with the bundle ID `com.codertapsu.oriel`, copy its client ID into Oriel and **Sign In…**. Oriel uploads into an "Oriel" folder it makes in My Drive; to use a folder of your own, paste its ID or link and set **Access** to All of Google Drive. While your app's consent screen is in Testing, Google signs you out after 7 days; publish it to stay signed in.

## Disk Space Analyzer

Disk Space Analyzer shows where the space on your drives goes and helps you get it back safely. Choose **Disk Space Analyzer** in the menu (or open `oriel://disk`); it has no shortcut until you give it one in Settings → Shortcuts. `oriel://disk/scan` opens it with a folder picker. Nothing runs while its window is closed.

- **See your drives:** the sidebar lists every volume with a bar of used, purgeable and free space, your cloud folders (iCloud Drive, Google Drive, Dropbox, OneDrive, Box) and the folders you scanned before. Select one for its details; external drives have **Eject**.
- **Scan:** **Scan** (⌘R) reads the selected volume or folder; **Choose Folder…** (⌘O) scans any folder. Progress shows as it goes; **Stop** (⌘.) keeps what was read. Scanning Macintosh HD counts macOS itself as one "macOS (system)" block and what no file accounts for (snapshots, overhead) as "Other space", so the total matches Finder.
- **Look around:** **Sunburst** and **Treemap** show the biggest consumers as the biggest areas; hover for a name and size. In the sunburst, click a folder to open it and the center to go up; in the treemap, click to select and double-click a folder to open it. Return opens the selected folder and ⌘↑ goes up in every view. **List** is an outline with size bars. The breadcrumbs above go back to any folder. ⌘1–⌘8 switch views.
- **Find what to remove:** **Biggest Files** lists the largest files, filtered by kind and size; **Old Files** lists files you have not used for a year (or another span), using Spotlight's "last opened" date where it knows it; **Duplicates** finds copies with the same content and marks all but the newest or oldest; **File Types** breaks the space down by kind; **Space Hogs** measures caches, Xcode data, simulators, backups, installers, `node_modules` and the Trash, and says what each is and whether it comes back by itself. Type in the search field (⌘F) to find items by name, and right-click a column header for more columns.
- **Act on it:** select one or more items (⌘ or ⇧ to add), then use the toolbar, the right-click menu or the inspector (⌥⌘I): Open, Reveal in Finder, Quick Look (Space), Copy to…, Move to…, Move to Trash (⌘⌫) or Delete Immediately (⌥⌘⌫). Oriel always says how many items and how much space before it removes or moves anything. **Move to Trash** can be undone with ⌘Z, or with Put Back in the Trash; **Delete Immediately** asks twice and cannot be undone. Moving to another drive copies, checks the copy and only then removes the original. Progress shows in a sheet with **Stop**.
- **What it will not touch:** macOS, the top of a drive, your home folder and its own folders, the Library folders apps rely on, the top of iCloud Drive or another cloud folder, anything inside an app (remove the whole app), the apps that come with macOS, and Oriel. The inspector says why when an item is refused.
- **What grew:** Oriel remembers a summary of each scan (names and sizes only). Scan the same folder again and a note says how much it grew since, with **Show Changes…** pointing at the folders responsible. Right-click the background for **Export as CSV…**.

**Purgeable space** is space macOS frees by itself when it needs it: local Time Machine snapshots, iCloud files that are safely in iCloud, and caches apps mark as purgeable. Finder counts it as used, but large downloads and copies can use it. To free it now, select Macintosh HD: **Remove Snapshots…** removes local Time Machine snapshots (macOS may ask for an administrator's password; your backups on the backup disk stay), **Remove Download** in a scan of iCloud Drive frees the local copies of files that stay in iCloud, **Open Trash** shows what is waiting to be emptied, and **Storage Settings…** opens macOS's own storage tools.

**Cloud storage:** a scan of a cloud folder shows how much is downloaded on this Mac and how much is only in the cloud; it never downloads anything. macOS does not tell apps how much of your plan is used, so Oriel links to the provider's storage page instead.

**Permissions.** Disk Space Analyzer needs no permission to start. The first time a scan reads Desktop, Documents, Downloads, iCloud Drive, a cloud folder, an external or network drive, or another app's data, macOS asks whether Oriel may; choose Allow to count it. What you keep private is counted as "folders that couldn't be read". For a complete picture, choose **Grant Full Disk Access…** in the window, switch Oriel on in System Settings → Privacy & Security → Full Disk Access, quit and reopen Oriel, and scan again.

**Settings → Disk Space Analyzer:** exclusions (folders, or names such as `node_modules`), the size from which files are listed one by one (1 MB; smaller ones are counted together per folder), hidden files, going into other volumes inside a folder, keeping the scan up to date while the window is open, remembering scans (and forgetting them), Spotlight's "last opened" dates, and asking before moving to the Trash.

## Activity Monitor

See what your Mac is doing: every app, background service and process, with its CPU, memory, energy, disk and network use, and the Mac's totals underneath. Choose **Activity Monitor** in the menu, or open `oriel://activity`; give it a shortcut in Settings → Shortcuts. It measures only while its window is open.

- **Tabs:** CPU, Memory, Energy, Disk and Network (⌘1 to ⌘5) each have their own columns and order. Click a column header to sort; right-click a header to show or hide columns.
- **Views:** the View menu shows All Processes, My Processes, System Processes, Other User Processes, Apps, Active Processes (those that used the processor, disk or network in the last update), All Processes, Hierarchically, or Apps with Their Helpers, where each app's row adds up the processes that work for it.
- **Search** (⌘F) finds processes by name, user, bundle ID, path or PID.
- **Heavy use:** a process over a limit (by default 80 % CPU for 10 seconds, or 2 GB of memory) has a flame beside its name and an orange value. The strip above the list names the three processes using the most of the tab's measure; click one to select it. Change the limits in Settings → Activity Monitor.
- **Details** (⌘I, Info, or Return): the selected process's live CPU and memory graphs, its parent (click it), user, start time, Kind (Apple or Intel), path, code signature and, for your own processes, its command line and open files and connections.
- **Quit** (⌥⌘Q, or the toolbar's Quit Process) asks first: Quit lets an app save its work, Force Quit ends it at once. **Send Signal**, in the context menu and the More menu, sends TERM, INT, HUP, KILL, STOP, CONT, USR1 or USR2 after saying what it does. Oriel leaves kernel_task, launchd, WindowServer, loginwindow and itself running. Another user's process, or a system one, needs an administrator: Oriel asks again, then macOS asks for the password.
- **Sample Process…** records three seconds of one of your processes' call stacks and opens the report. **Reveal in Finder** and **Copy** are in the same menus; ⌘C copies the selected rows.
- **What macOS shares:** for your own processes, everything; for other users' processes and system services, CPU and real memory (read with `/bin/ps`), not disk, energy, threads or open files. Settings → Activity Monitor → **Show only my processes** hides the others and never runs `ps`. Energy is shown as power, in watts.

## Color Picker

Press **⌃⇧C** anywhere: the system loupe appears. Move it over any pixel and click; Esc cancels. The color is copied straight away, as HEX unless you choose another format in Settings → Color Picker, and the Color Picker panel opens with it. The loupe needs no permission. **Color Picker** in the menu (or `oriel://color`) opens the panel without picking.

- **Color:** the color, large, with its HEX on it. Click the HEX to type or paste any color (`#F80`, `rgb(255 136 0)`, `hsl(32, 100%, 50%)`, `oklch(0.74 0.18 56)`, `color(display-p3 1 0 0)`, even `NSColor(srgbRed: …)`) and press Return. Below are all its formats: HEX, HEX + Alpha, RGB, RGBA, HSL, HSB, OKLCH, SwiftUI, NSColor, UIColor, RGB %, CMYK and Display P3. Click one to copy it, press its number (1–9, 0), or press **⌘C** for your default. **Recent** keeps your last picks (20 by default); right-click one to copy it, use it for contrast, add it to a palette or remove it.
- **Wide colors:** on a Display P3 screen you can pick colors sRGB cannot show. The panel then says *Outside sRGB*: HEX, RGB, HSL, HSB and CMYK give the nearest sRGB color, while Display P3, OKLCH and the code formats keep the exact one (the code formats use the Display P3 initializers).
- **Palettes:** **Add to Palette** puts the color in a palette, or makes a new one. In the Palettes tab, the + tile adds the current color; drag swatches to reorder them or into another palette, double-click a palette's name to rename it, and use ⋯ to move, export (JSON, CSS variables, or a `.clr` color list for the system Colors panel and design apps) or delete it. Click a color to select it and give it a name; exports use the names. Deleted something by mistake? **Undo** in the footer (⌘Z) brings it back until you close the panel.
- **Contrast:** choose a text and a background color: type them, drop a swatch on them, use **Check Contrast** on the Color tab, or pick either from the screen with its eyedropper; ⇅ swaps them. The tab shows the **WCAG 2.2** contrast ratio and whether it passes AA and AAA for normal text, large text (24 pt, or 18.7 pt bold) and UI components, a live sample, and **APCA**'s Lc, the method drafted for WCAG 3, as extra information. ⌘C copies the ratio with the colors.
- The panel floats above your windows without taking the keyboard from the app you are in, and stays open until you close it (Esc, ⌘W, or its ×). Drag its background to move it; it reopens where you left it. ⌘1–⌘3 switch tabs and ⌘, opens its settings.
- **Settings → Color Picker:** the format ⌘C and picking copy, uppercase HEX, whether picking copies at once, and how many recent colors to keep.

## Screen Ruler

Press **⌃⇧M** to lay a ruler over every display; press it again, or Esc, to close it. The bar at the bottom shows the mode and its keys.

- **Dimensions** (the default): move the pointer, and lines run from it to the nearest edges left, right, up and down, with the distances and the size of the space between the edges ("320 × 48 pt"). **Click** to keep that box on the screen; click it again to let it go. **Drag a box** around a button or an icon and it shrinks to fit it exactly. Arrows move the measuring point one point (or pixel) at a time. If the lines stop short on noise, shadows or gradients, press `]` to raise the edge tolerance; press `[` to find fainter edges.
- **Measure Area** (Tab): drag a rectangle to read its width and height in points and pixels and its position. Hold **⇧** for a square. Drag the handles to resize, drag inside to move, use the arrows to nudge (⇧ for ten, ⌥ to resize). Edges snap to what is on the screen; hold ⌘ to drag freely. Double-click inside, or press Return, to copy and close.
- **Guides** (Tab again): click to add a guide line; **Space** switches between vertical and horizontal. Drag a guide to move it, or select one and use the arrows; ⌫ or a right-click removes it, ⌘⌫ removes all. The distances between the guides are shown along the pointer.
- **Everywhere:** **⌘C** copies the measurement ("320 × 240 pt"), **Return** copies it and closes, **U** switches between points and pixels (on a Retina display a point is two pixels), 1–3 pick a mode, and Esc closes.
- **Screen Recording:** Dimensions finds edges in a still picture of the screen, taken when the ruler opens, which needs **Screen & System Audio Recording**. Without it, Measure Area and Guides work as usual, and Dimensions explains what is missing: press Return there to grant it. Content that changes after the ruler opened (a video, a scrolled page) is measured as it was; close and reopen the ruler.
- **Settings → Screen Ruler:** the mode and unit it opens with, the color of its lines, and the edge tolerance.

## Window Tiling

Arrange the window you are working in without reaching for the mouse. Every shortcut acts on the focused window of the app in front.

| Arrange | Default |
|---|---|
| Left, right, top or bottom half | ⌃⌥←, ⌃⌥→, ⌃⌥↑, ⌃⌥↓ |
| Top left, top right, bottom left, bottom right quarter | ⌃⌥U, ⌃⌥I, ⌃⌥J, ⌃⌥K |
| First, center or last third | ⌃⌥D, ⌃⌥F, ⌃⌥G |
| First or last two thirds | ⌃⌥E, ⌃⌥T |
| Maximize | ⌃⌥↩ |
| Maximize height | ⌃⌥⇧↑ |
| Center | ⌃⌥C |
| Make smaller, make larger | ⌃⌥-, ⌃⌥= |
| Next display, previous display | ⌃⌥⌘→, ⌃⌥⌘← |
| Restore | ⌃⌥⌫ |
| Almost maximize | none; give it one in Settings → Shortcuts |

- **Halves cycle:** press a half again and the window takes two thirds of the screen, then one third, then a half again. Turn this off in Settings → Window Tiling.
- **Restore** puts the window back where it was before you started arranging it, however many layouts you tried in between. If you move the window by hand and then arrange it again, Restore goes back to where you moved it.
- **Other displays:** a tiled window keeps its layout on the next display (the left half stays the left half); any other window keeps its size and place, and shrinks if the display is smaller. On a portrait display, thirds stack from top to bottom.
- **The menu:** the menu bar icon's **Window Tiling** menu lists every layout with a small picture and its shortcut.
- **Settings → Window Tiling:** a gap between windows and along the screen's edges (none to 32 points), Almost Maximize's size (60–95 %, 90 % to start), and the cycling.
- **Windows that won't fit:** a window with a minimum size, or a terminal that snaps to whole lines, keeps the layout's edge (a right half stays against the right edge) and stays on the screen. Full-screen windows and sheets are left alone, with a short message.
- **Permission:** Window Tiling needs Accessibility. Without it, a shortcut shows a message with **Open System Settings**; switch Oriel on in Privacy & Security → Accessibility (on macOS 27: Device Control and Data Access).

## Sync settings

Settings → General → **Sync settings through iCloud** keeps your shortcuts, the tools you have turned on and most preferences the same on each Mac that runs Oriel. Folders, upload destinations, passwords and API keys stay on each Mac, and so do your histories, pins, palettes and glossaries. Turn it on first on the Mac whose settings you want to keep; the other Macs then adopt them. After that, the latest change on any Mac wins, and **Sync Now** syncs at once. Oriel keeps the settings in an **Oriel** folder in iCloud Drive (one small file per Mac), so iCloud Drive must be on; macOS may ask once whether Oriel may use it.

## Shortcuts app

Oriel adds actions to the Shortcuts app and to Spotlight:

- **Take a Screenshot:** area, window or screen; passes the image on.
- **Translate Area** and **Translate Text in an Image:** pass the translation on.
- **Focus Window:** choose a window from a list; needs Accessibility.
- **Run Oriel Command:** anything in the menu, such as a window layout, the color picker or Clipboard History.

Example: a shortcut that takes a screenshot of the screen and saves it to a folder, or one that translates every image you drop on it. In Spotlight, type "Take a screenshot with Oriel".

## Command line

Settings → Advanced → Command-line tool → **Install** adds `oriel` to `~/.local/bin`, or to `/usr/local/bin` after asking for your password. Oriel must be running.

```bash
oriel windows list [--json] [--space current|all] [--app <bundle-id>]
oriel windows focus <window-id> | --title <text>
oriel windows close|minimize <window-id>
oriel capture area|window|screen [--rect x,y,w,h] [--delay <seconds>] [--to clipboard|file|editor] [--path <file>]
oriel capture text [--rect x,y,w,h] [--json]      # the text in an area, on stdout; nothing is copied
oriel translate area [--rect x,y,w,h] [--to <language>] [--provider <id>] [--json]
oriel top [--sort cpu|memory|disk|network] [--limit <n>] [--json]   # the busiest processes now
oriel disk volumes [--json]                       # capacity, used, free and purgeable space of every volume
oriel disk scan <path> [--top <n>] [--json]       # the largest items in a folder or volume; changes nothing
oriel debug capabilities --json
oriel debug clipboard [--json]      # Clipboard History's state, never what was copied
```

`--delay` (1 to 60 seconds) shows a countdown before capturing. Without `--rect`, `capture text` asks you to select the area; `--json` adds every line with its place on screen in points, and no text found is exit status 1. `top` shows 20 processes unless `--limit` says otherwise (up to 1,000). `disk scan` takes a path starting with `/` or `~`, lists 10 items unless `--top` says otherwise, and waits up to ten minutes. A tool that is turned off answers that it is off.

Oriel also opens URLs: `oriel://capture/area`, `oriel://capture/window`, `oriel://capture/screen`, `oriel://capture/scrolling`, `oriel://capture/previous`, `oriel://capture/timer`, `oriel://capture/all`, `oriel://capture/instant`, `oriel://capture/text`, `oriel://capture/steps`, `oriel://record/area`, `oriel://record/window`, `oriel://record/screen`, `oriel://record/stop`, `oriel://video/open`, `oriel://translate/area`, `oriel://translate/cursor`, `oriel://translate/file`, `oriel://clipboard`, `oriel://history`, `oriel://disk`, `oriel://disk/scan`, `oriel://activity`, `oriel://color`, `oriel://color/pick`, `oriel://ruler`, `oriel://settings`. For example: `open oriel://capture/area`. A tool's URLs work while the tool is turned on.

## Shared team configuration

A `bootstrap.json` in `~/Library/Application Support/Oriel/` is imported on the next launch and then deleted. Its format is in `docs/bootstrap.example.json`. It holds the translation providers, the default provider and an S3 upload destination, keys included, which go into the keychain; the destination becomes the default in Settings → Upload, or updates the one an earlier import made. A Google provider can also have `"glossary"` and `"serviceAccountKey"` (the key file's JSON object pasted in as it is). Settings → Advanced → **Reload shared configuration** imports it again. A managed `BootstrapURL` preference can point at an internal HTTPS copy instead.

## Troubleshooting

| Problem | What to do |
|---|---|
| A shortcut does nothing | Settings → Shortcuts shows ⚠︎ when another app owns the combination. Pick another. A tool's shortcuts work only while the tool is on (General → Tools). |
| The switcher shows no windows or cannot switch | Grant Accessibility (Settings → Permissions). If Oriel is already switched on in System Settings → Privacy & Security → Device Control and Data Access (Accessibility before macOS 27) but Settings → Permissions still says it is missing, select Oriel there, remove it with −, and add it again with +: the switch belonged to another copy of Oriel. |
| Captures are black or show only the desktop | Grant Screen Recording, then quit and reopen Oriel. |
| Clipboard History keeps only screenshots | Set Oriel to Allow in System Settings → Privacy & Security → Paste from Other Apps (it is listed there once macOS has asked about it); if it already is, quit and reopen Oriel. `oriel debug clipboard` shows `access: allowed` when it works. |
| Return in Clipboard History copies but does not paste | Grant Accessibility: macOS drops the ⌘V that Oriel posts without it. |
| Capture Text found no text | Select a larger area around the text; very small or low-contrast text may not be readable. A click on a window reads all of it. |
| A pin ignores clicks | It is click-through. Hold ⌥⌘ over it, click the button at its corner, or choose menu → Pinned → Stop Click-Through on All Pins. |
| Desktop icons still show | The setting applies to captures of an area or a screen, not to recordings, translation, Instant Capture or `oriel capture … --rect`. |
| Smart Redact or Smart Move finds nothing | Smart Redact finds only text OCR can read. Vision's object detection is made for photos and often finds nothing in an app window; blocks of text still work. |
| Auto Zoom is greyed out | The movie has no saved clicks: it was recorded with Remember clicks for Auto Zoom off, or its `.oriel-clicks.json` file was not moved with it. You can still add zooms with Z. |
| Translation says the language pack is missing | Accept the download Oriel offers, or download it in System Settings → General → Language & Region → Translation Languages. |
| A local model does not answer | Check that Ollama/LM Studio is running and the endpoint in Settings → Translation (e.g. `http://localhost:11434/v1`); use Test connection. |
| Translate Under Cursor shows nothing, or does not start | It needs Screen & System Audio Recording (quit and reopen Oriel after granting it). The text may already be in your language, or too small for OCR; zoom in, or translate the line only. Esc in other apps needs Accessibility; ⌃⇧U or its menu-bar icon always turns it off. |
| A file is refused for translation | Oriel reads the kinds listed in [Translating files](#translating-files); convert others to PDF or text. For a PDF with a password, export an unprotected copy in Preview. |
| Glossary terms are ignored by Google | Google uses a project's Cloud glossary only with a service account key and only for the glossary's own language pair. |
| Upload says to set up a destination | Settings → Upload → Add Destination; the first one becomes the default. |
| SFTP: "doesn't know the host key" or "refused your SSH key" | Run `ssh host` once in Terminal and accept the key; install your key with `ssh-copy-id`, and put a key with a passphrase in the agent (`ssh-add --apple-use-keychain`). |
| Dropbox or Google Drive: "Sign in again" | Settings → Upload → the destination → Sign Out, then Sign In…. For Google, publish the consent screen to stop the 7-day sign-outs. |
| "N folders couldn't be read" in Disk Space Analyzer | Grant Full Disk Access (the button in the note), quit and reopen Oriel, and scan again. If only Desktop, Documents or a cloud folder is empty, allow Oriel in System Settings → Privacy & Security → Files and Folders. |
| Macintosh HD shows a large "Other space", or the files add up to more than the drive uses | Other space is what no file shows: local snapshots, other volumes in the same container, folders Oriel could not read. APFS copies (clones) share their space but are counted per file; the inspector's "Freed if deleted" shows what removing one really frees. |
| Activity Monitor shows dashes for other users' processes | They are measured with `/bin/ps` on the CPU, Memory and Energy tabs; wait a second. Disk use and energy are shared only for your own processes. |
| A process cannot be quit | Oriel says why: it belongs to macOS (kernel_task, launchd, WindowServer, loginwindow), it is Oriel, or it has already ended. Another user's process needs an administrator's password. |
| The Screen Ruler's lines stop at every pixel, or Dimensions says it needs Screen Recording | Raise the edge tolerance with `]` (or in Settings → Screen Ruler). Switch Oriel on in Privacy & Security → Screen & System Audio Recording, then quit and reopen Oriel. |
| A picked color's HEX differs from the app's own value | The app shows its value in another color space; Oriel's HEX is sRGB. If the panel says *Outside sRGB*, use the Display P3 or OKLCH value. |
| A tiling shortcut beeps, or a window ends up the wrong size | It beeps when no window has the focus, there is nothing to restore, the window is already as large as the screen, or there is only one display. Some apps do not let Accessibility move their windows. For Chrome or an Electron app, press the shortcut again. |
| Sync settings is dimmed or says iCloud Drive is off | Turn on iCloud Drive in System Settings → Apple Account → iCloud. |
| Diagnostics for a bug report | Settings → Advanced → Diagnostics → Copy as JSON, or `oriel debug capabilities --json`. |

To remove Oriel completely, use Settings → Advanced → **Uninstall Oriel…**. It removes settings, history, saved keys, the login item and the CLI link. With settings sync on, also delete the **Oriel** folder in iCloud Drive.

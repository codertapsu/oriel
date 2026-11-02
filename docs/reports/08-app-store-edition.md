# 08 — The App Store edition, Oriel Pro and the feature tour (release 1.0.0)

2026-11-02 · macOS 27.2 (26B123) · Xcode 27.1 · what you decided after the App Store analysis: two editions, the App Store edition keeping `com.codertapsu.oriel`, Oriel Pro at US$10.00 with Family Sharing off, the Free/Pro split as proposed, Oriel's pages on the Codertapsu site, and the notarization keychain profile. Then a feature tour, the App Store preparation, the docs and a fresh build. Plan 2.12 describes all of it (§18, §19).

## Result

- **Two editions from one tree** (PLAN §18). A second app target, `OrielAppStore`, builds the Mac App Store edition with `APP_STORE`, in its own configurations (Debug-AppStore, Release-AppStore) and scheme ("Oriel App Store"). It is sandboxed and has the release's bundle ID. It leaves out the window switcher, Window Tiling, Activity Monitor, private APIs, the CLI and root, and the shared packages adapt where the sandbox requires it, asking `Sandbox.isActive` (PLAN §19.1):
  - scrolling capture is manual;
  - captures are saved to the chosen folder through a security-scoped bookmark, else to Pictures/Oriel;
  - Disk Space Analyzer asks once for each drive or folder it scans;
  - uploads have no SFTP;
  - Clipboard History copies instead of pasting;
  - Read as Administrator, local snapshots and the simulator clean-up are hidden.

  The Developer ID edition is unchanged apart from what is listed under [For the Developer ID edition](#for-the-developer-id-edition).
- **Oriel Pro** (PLAN §19.2–§19.4). It is one non-consumable, `com.codertapsu.oriel.pro`, US$10.00, not family shareable, sold through StoreKit 2 with no server.
  - **The listener:** transactions are read from launch on, and each one is decided from itself.
  - **Purchase and restore:** Settings → Oriel Pro shows the price, buys, notes a pending purchase and restores; it works offline.
  - **Declared by the features:** every feature and tool declares its Pro features. A Pro command asks first, from a shortcut, a menu, a URL or an intent, and asking opens Settings → Oriel Pro on that feature.
  - **Marked while locked:** Settings, menus and the tour mark what is Pro. Turning a Pro option off always works, and the free tier deletes nothing.
- **Feature tour** (PLAN §19.5). It has a welcome page, then a page for each feature and for each tool of the edition. Each page is declared by its feature or tool, and shows:
  - the command's current shortcut;
  - Try It;
  - Settings…;
  - the highlights, Pro ones marked;
  - the permissions it uses, with their state.

  It opens once after the first onboarding, and from Feature Tour… in the menu, Help → Oriel Feature Tour and `oriel://tour`. Help also links the support page.
- **Consent before text leaves the Mac** (PLAN §19.6, Guidelines 5.1.2(i)). Before the first translation through a provider off the Mac, Oriel asks once per provider, in an alert above its overlays. Settings → Translation shows the answer and takes it back. Apple Translation, Apple Intelligence and servers on the Mac never ask. Shortcuts and the CLI fail instead of asking.
- **Privacy manifest** (PLAN §19.7). It declares no tracking and no collected data, plus reasons for UserDefaults, file timestamps and disk space.
- **Website.** Oriel's privacy policy, support page and terms of use are live at <https://codertapsu-web.web.app/oriel/privacy>, [/oriel/support](https://codertapsu-web.web.app/oriel/support) and [/oriel/terms](https://codertapsu-web.web.app/oriel/terms). The generator gained per-app overrides, because its terms text assumed InkMirror's subscriptions; every existing page still builds byte for byte the same. In `codertapsu-web` there are two commits on `main`, deployed with `firebase deploy --only hosting` and pushed.
- **Notarization keychain profile.** `codertapsu-notary` is in your login keychain, made from the credentials file's values without printing them, and Apple validated it. The release scripts sign in with it first and fall back to the variables (`scripts/release/notary-auth.sh`). It serves every app of the team.
- **Version 1.0.0, build 134.** After the first draft of this report you chose 1.0.0.
  - The Developer ID edition is fresh, notarized and verified; the details are in the tag `v1.0.0`.
  - The App Store edition's Release is built from the same commit and passes the App Review checks. Its archive waits for one step in your account: your team has no registered device yet, and automatic signing needs one (What you need to do, step 3).

## The split

As you approved it, tool by tool (PLAN §19.2):

| Feature or tool | Free | Oriel Pro |
|---|---|---|
| Screenshots | Area, window, screen and timer captures, Quick Access, pins, Capture Text, the latest 20 captures in the history | Scrolling, Instant and Step Capture; pin lock, click-through and opacity; the whole history and its search; a clean desktop |
| Upload | — | Every destination |
| Editor | Every drawing tool, blur, pixelate, crop; PNG and JPEG | Smart Redact, Simplify, Smart Move, backgrounds, numbered steps, the spotlight; `.oriel` documents, HEIC and PDF |
| Screen recording | Screen, window or area with audio; trim; MP4 | Video editor, camera bubble, click highlights and keystrokes, GIF and constant-frame-rate exports |
| Translation | Translate Area with Apple Translation and Apple Intelligence | The other providers, Translate Under Cursor, files, glossaries, AI Vision |
| Clipboard History | The last 100 items from the past 7 days, 5 pins | Everything kept, unlimited pins, text in images, ⌘1–⌘9 |
| Disk Space Analyzer | Scans, the views, Biggest Files, File Types, Space Hogs, Trash with Undo | Clean Up, Duplicates, Old Files, what grew, CSV |
| Color Picker | Picking; HEX, RGB(A), HSL | The other formats, palettes, contrast |
| Screen Ruler | Dimensions, Measure Area | Guides, kept measurements, tolerance and color |
| App | — | Settings sync |

A new tool brings its own Pro features and tour page: the package declares them, and the catalog and the tour pick them up.

## For the Developer ID edition

Pro is unlocked at launch, so nothing is gated, and the app shows no PRO badges. What you will notice:

- Settings has an **Oriel Pro** pane, which says the edition includes every Pro feature.
- The menu has **Feature Tour…**, and the menu bar has a **Help** menu while Oriel is in the Dock.
- **The first translation through DeepL, Google, OpenAI, Anthropic or a server on another Mac asks once** whether Oriel may send it the text. I made both editions ask, so you see what App Store users see. Say if you would rather the Developer ID edition never asked.

## Fixes along the way

- **A snapshot test failed on macOS 27.2.** 27.2 (installed on Oct 31 at 23:57, after build 114) resolves Dark Mode's `separatorColor` up to 6 levels differently. The switcher's opaque-fill snapshot failed on its border alone. It now allows 8 levels; a fill that stayed light would be 100+ off. Recorded in `docs/os-quirks.md`.
- **The Developer ID scheme's tests built the App Store target too.** Both made an `Oriel.app`. Now only the App Store archive is `Oriel.app`.
- **Security-scoped access leaked.** It was started again on every scan and upload, and each start holds a kernel sandbox extension. It now starts once per folder and launch.
- **PLAN's Appendices C and D were behind.** They had fallen behind the App Store edition commit, and are again copies of the Makefile and `project.yml`.

## Tests added

- **App Store edition, inside its sandbox** (9 tests):
  - it runs sandboxed;
  - no helper, CLI or private symbol;
  - it never asks for Accessibility;
  - the privacy manifest;
  - the tour lists only its tools and promises nothing the sandbox rules out;
  - Oriel.storekit's product, a purchase unlocking, a refund locking, a relaunch finding the purchase.
- **Core and Licensing:** `ProAccessTests` (5) and `ProEntitlementTests` (5).
- **Each tool's free limits:**
  - `HistoryProTests` and `ClipboardProTests` (4);
  - `RulerProTests` (3);
  - `ColorPickerProTests`, `EditorProTests` (2) and `DiskAnalyzerProTests`;
  - `TranslationProTests` (2) and `ProviderConsentTests` (3).
- **App:**
  - `ProCatalogTests`: unique ids, every feature described, every gate in the catalog;
  - `FeatureTourTests` (3);
  - the Help menu in `DockPresenceTests`.
- **The gate:** `make lint test universal-check appstore-check` passed before the docs commit. It ran 1,883 tests: the Developer ID app's 43, the App Store edition's 9 and the packages' 1,831. SwiftLint and SwiftFormat were clean, and both Release builds passed. The release ran the gate again, and the tag records that run.

## How it meets the rules

- **Rule 2:** the App Store edition links no PrivateAPIs. `scripts/verify-appstore.sh` and an edition test look for the symbol names.
- **Rule 3:** the transaction listener is an async sequence. No timer was added.
- **Rule 4:** the tour is SwiftUI, of the onboarding kind; CLAUDE.md's rule 4 now names it.
- **Rule 5:** the StoreKit 2 APIs used are all older than macOS 26.0.
- **Rule 7:** the notary password moved into the keychain. The Pro hint in UserDefaults is no secret: StoreKit decides.
- **Rule 8:** nothing reads TCC.db.
- **Rules 9 and 10:** no outside dependency, no deployment-target change and no ARCHS change. Licensing is a local package. `make universal-check` ran.
- **Rule 12:** no names that differ only by case.
- **Rule 13:** the credentials file was only sourced, never printed.
- **Rule 14:** the App Store edition's Debug builds are `com.codertapsu.oriel.appstore.debug`.
- **New rule 15:** the App Store edition's constraints, and how a Pro feature is declared.

## Deviations from PLAN.md (amended in plan 2.12)

- **D3, §1.5, §2.3:** two editions. The Mac App Store and sandboxing are no longer non-goals. D15 records Oriel Pro.
- **§7.16:** key-value storage in the App Store edition, with no iCloud Drive fallback.
- **§8.1:** the App Store edition's entitlements.
- **§15:** notarization signs in through the keychain profile (item 4); the App Store edition's checks, archive and upload (item 9).
- **New sections:** §13.21, §18 and §19.
- **Appendices:** A shows the new folders, B is CLAUDE.md, and C and D are copies of the Makefile and `project.yml` again.
- **Docs:** `docs/APP_STORE.md` is rewritten as the store checklist for this edition. `docs/RELEASING.md` gains the App Store pipeline and the certificate and password renewals.

## Version, store name and history

These were the open questions of this report's first draft.

1. **Version 1.0.0.** Both editions are 1.0.0, build 134, which supersedes the 0.1.0 builds. The release tag is `v1.0.0`; the `v0.1.0` tag, which never reached GitHub, is gone, and `v1.0.0`'s message lists the 0.1.0 builds it supersedes.
2. **The store name.** Suggested: **Oriel: Screenshot & Translate** (29 of 30 characters), with the subtitle **Record, annotate, extract text**. The name under the icon stays Oriel. `docs/APP_STORE.md` step 3 has the reasoning, two fallbacks and keywords. Only App Store Connect can say whether a name is free.
3. **History.** The 20 commits since build 114 were tidied before the build:
   - the feature tour's `FeatureGuide` moved from the core commit into the tour's;
   - `make appstore-archive` now numbers its build like the Developer ID release;
   - every commit was built on its own, both schemes and the packages it touches with their tests.

   `main`, `v1.0.0` and `codertapsu-web`'s two commits are pushed.

## What you need to do

1. **Install build 134.**
   - Quit Oriel from its menu-bar menu, open `dist/Oriel-1.0.0.dmg`, drag **Oriel** to **Applications** and choose **Replace**. Settings → About shows 1.0.0 (134).
   - Try **Feature Tour…** and Settings → Oriel Pro, then run QA item 52 (consent) with a provider off the Mac.
2. **App Store Connect,** following `docs/APP_STORE.md`:
   - the Paid Apps agreement, tax and banking;
   - the app record;
   - Oriel Pro: non-consumable, `com.codertapsu.oriel.pro`, US$10.00, **Family Sharing off**;
   - the listing with the privacy and support URLs;
   - App Privacy: **Data Not Collected**.
3. **The first App Store build:**
   - **Register this Mac in your team, once.** Your team has no devices, and automatic signing needs one for the development profile an archive is signed with; `make appstore-archive` stopped there. In Xcode, open the OrielAppStore target → **Signing & Capabilities** with **Automatically manage signing** on, and register the Mac when Xcode reports the missing device. Or add it at developer.apple.com → **Devices**, with this Mac's Provisioning UDID, `00006040-000211A13AEA801C` (`docs/APP_STORE_CONNECT.md` step 3.2). The attempt may already have turned on iCloud for the App ID, which the edition needs anyway; nothing else was created.
   - Then `make appstore-archive` (or Xcode → scheme **Oriel App Store** → Product → Archive) makes `dist/Oriel-AppStore.xcarchive`, build 134, signed through your team account in Xcode. The first time, Xcode turns on iCloud for the App ID and makes the profiles.
   - Once the app record and Oriel Pro exist, open the archive (double-click) and choose Organizer → Distribute App → App Store Connect → Upload.
   - Test in TestFlight with QA items 49–53, then submit with Oriel Pro attached.
4. **Before 2027-02-01:** a new Developer ID Application certificate (`docs/RELEASING.md` → Renewing certificates and passwords). Then update `APPLE_SIGNING_IDENTITY` in each app's credentials file if its name changed, and delete the old certificate.

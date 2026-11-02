# Oriel in the Mac App Store

The Mac App Store edition is the same app, sandboxed, built by the `OrielAppStore` target (PLAN §18, §19). It has the release's bundle ID, `com.codertapsu.oriel`, leaves out the tools the sandbox cannot run (the window switcher, Window Tiling and Activity Monitor), and is free, with **Oriel Pro** as a one-time in-app purchase. This document is the checklist for getting it into the store. PLAN §19 explains how the edition works; `docs/RELEASING.md` → The App Store edition covers archiving and uploading each version.

## What the repository already has

| Item | Where |
|---|---|
| The target, its configurations and scheme | `project.yml`: `OrielAppStore`; Debug-AppStore and Release-AppStore; scheme **Oriel App Store** |
| Entitlements | `App/AppStore/OrielAppStore.entitlements` (Release): sandbox, network client, user-selected files and their bookmarks, Pictures, microphone, camera, iCloud key-value storage. `OrielAppStoreDebug.entitlements` is the same without iCloud, which needs a provisioning profile |
| Info.plist | `App/AppStore/Info.plist`: export compliance (`ITSAppUsesNonExemptEncryption` false), the Utilities category, the purpose strings |
| Privacy manifest | `App/Resources/PrivacyInfo.xcprivacy` (PLAN §19.7) |
| Oriel Pro | `Packages/Licensing`, product ID `com.codertapsu.oriel.pro`; `App/StoreKit/Oriel.storekit` for testing in Xcode |
| Checks | `make appstore-check` (`scripts/verify-appstore.sh`: both slices, no private symbol, no helper or CLI, the sandbox, export compliance, the manifest) and the edition's tests in `make test` |
| Privacy policy, support page, terms of use | <https://codertapsu-web.web.app/oriel/privacy>, [/oriel/support](https://codertapsu-web.web.app/oriel/support), [/oriel/terms](https://codertapsu-web.web.app/oriel/terms) |

## One-time setup in your Apple account

These steps need the Account Holder or an Admin of team `4XVYLW8RXS`; nothing in the repository can do them.

### 1. Agreements, tax and banking

App Store Connect → **Business**: accept the **Paid Apps** agreement and complete the bank account and tax forms. Until then Oriel Pro cannot be sold, and outside Xcode's StoreKit testing the product does not load, so Settings → Oriel Pro shows the button without a price.

### 2. The App ID

`com.codertapsu.oriel` already exists for Developer ID. The first `make appstore-archive` (or Product → Archive in Xcode) with automatic signing turns on the capabilities the entitlements ask for and makes the App Store profiles.

An archive is signed for development first and for the App Store when it is uploaded, and a development profile needs a registered device. The team had none on 2026-11-02, so the first archive stops with "Your team has no devices from which to generate a provisioning profile". Register this Mac once: in Xcode, the OrielAppStore target → **Signing & Capabilities**, with **Automatically manage signing** on, offers it when it reports the missing device; or add it at developer.apple.com → **Devices**, with the Provisioning UDID from System Information → Hardware. To do it by hand instead: developer.apple.com → Certificates, Identifiers & Profiles → **Identifiers** → `com.codertapsu.oriel` → turn on **iCloud** (key-value storage needs no container); **In-App Purchase** is on for every App ID.

### 3. The app record

App Store Connect → **Apps** → **+** → **New App**: macOS, primary language English (U.S.), bundle ID `com.codertapsu.oriel`, SKU such as `oriel-mac`, and the name:

| Field | Suggested | Why |
|---|---|---|
| Name (30 characters) | **Oriel: Screenshot & Translate** (29) | Keeps the brand first and names what sets it apart; App Store names are unique, so a descriptive name is also likelier to be free |
| If it is taken | **Oriel: Capture & Translate**, or **Oriel Screen Toolkit** | Same idea, shorter |
| Subtitle (30 characters) | **Record, annotate, extract text** (30) | The other half of what it does, without repeating the name's words |
| Keywords (100 characters) | `screen capture,screen recorder,ocr,annotate,clipboard history,color picker,ruler,disk space` | Words the name and subtitle do not already cover |

Only App Store Connect knows whether a name is free: names can be reserved by apps that are not on sale. On 2026-11-02 no Mac app was called plain "Oriel" (an iPad app is called "Bouygues Oriel"). The name under the icon stays **Oriel** (`CFBundleDisplayName`), whatever the store name.

### 4. Oriel Pro

In the app record → **Monetization** → **In-App Purchases** → **+**:

| Field | Value |
|---|---|
| Type | Non-Consumable |
| Reference name | Oriel Pro |
| Product ID | `com.codertapsu.oriel.pro` (it must match `ProStore.productID`) |
| Price | US$10.00 |
| Family Sharing | **Off**. Once turned on, it cannot be turned off again |
| Display name and description | "Oriel Pro" · "Every Pro feature of every tool, with one purchase." |
| Review | A screenshot of Settings → Oriel Pro, and a note: "Unlocks the Pro features listed in Settings → Oriel Pro. Restore Purchases is in the same pane." |

The first version of the app must go to review with the in-app purchase attached (step 5 of the release steps).

### 5. App information and price

- **Price:** Free, in Pricing and Availability; choose the territories.
- **Category:** Utilities (the bundle's `LSApplicationCategoryType`), and Productivity as the secondary one.
- **Age rating:** answer the questionnaire; Oriel has no such content and no web browser, so expect 4+.
- **URLs:** privacy policy <https://codertapsu-web.web.app/oriel/privacy>, support <https://codertapsu-web.web.app/oriel/support>.
- **License agreement:** keep Apple's standard EULA; Oriel's terms add to it. End the description with "Terms of Use: https://codertapsu-web.web.app/oriel/terms".
- **Copyright:** 2026 Hoàng Duy Khánh.

### 6. App Privacy

App Store Connect → **App Privacy**: **Data Not Collected**. Oriel sends the developer nothing. Text goes to a translation provider only when the user chooses one and allows it, under their own account and key; captures go only to the upload destinations they set up; preferences go to their iCloud only if they turn sync on. The privacy policy and the manifest say the same.

### 7. The listing

- Subtitle (30 characters), description, keywords and promotional text. Describe only this edition: no window switcher, Window Tiling or Activity Monitor (Guidelines 2.3.1).
- Screenshots: at least one at 1280 × 800, 1440 × 900, 2560 × 1600 or 2880 × 1800. Suggested: the capture overlay, the editor, a translation drawn over a page, Clipboard History, Disk Space Analyzer, the feature tour, Settings → Oriel Pro.
- App Review information: a contact, and the notes below.

## Each version

`docs/RELEASING.md` → The App Store edition: archive, upload from the Organizer, test in TestFlight, submit. App Store builds are not notarized: App Review stands in for it.

### Notes for App Review

Paste and adapt:

> Oriel is a menu-bar utility: after it opens, its icon is in the menu bar at the top right, and Help → Oriel Feature Tour shows each tool. Screen & System Audio Recording is used only for the screenshots, recordings, on-screen translations and Screen Ruler measurements the user starts. The microphone and camera are used only in recordings, if the user turns them on. Translation runs on the Mac with Apple Translation and Apple Intelligence; the other providers (DeepL, Google Translate, OpenAI, Anthropic or the user's own server) need the user's own API key and ask the user's permission before the first request. Oriel Pro is a non-consumable in-app purchase; Settings → Oriel Pro lists what it adds and has Restore Purchases. Oriel has no account and no server.

### Rejections to pre-empt

| Guideline | What it rejects | Where Oriel stands |
|---|---|---|
| 2.5.1 | Private APIs, even as strings | The edition links no PrivateAPIs; `make appstore-check` looks for the names |
| 2.4.5 | Entitlements without a feature, files outside the container without the user's choice, launching at login unasked, root, helpers | Each entitlement has its feature (network: providers and uploads; user-selected files and bookmarks: the save folder, Disk Space Analyzer's grants, shared folders, opened images and files; Pictures: the default save folder; microphone and camera: recordings; iCloud: settings sync). Open at login is off until the user turns it on. No helper, daemon or CLI |
| 3.1.1 | Unlocking features without in-app purchase; no Restore | Pro is sold only through StoreKit; Restore Purchases is in Settings → Oriel Pro |
| 5.1.1 | Missing purpose strings or privacy policy | The purpose strings are in the Info.plist; the policy is linked in App Store Connect and in the app |
| 5.1.2(i) | Sharing personal data with third-party AI without permission | Oriel asks before the first request to each provider off the Mac (PLAN §19.6) |
| 2.3.1 | Metadata describing what the app does not do | The listing describes this edition only |

## What the App Store edition leaves out, and why

| Left out | Why |
|---|---|
| The window switcher, Window Tiling | They need Accessibility, which cannot be granted to a sandboxed app |
| Activity Monitor | It reads and signals other processes, and runs `/bin/ps` and `nettop`, which the sandbox refuses |
| Automatic scrolling capture, the keystroke display, pasting from Clipboard History | They need Accessibility: the user scrolls, keystrokes are hidden, and choosing an item copies it for ⌘V |
| The CLI and its socket, Read as Administrator and its helper, Move to Applications, Uninstall | Guidelines 2.4.5: no code outside the bundle, no root |
| SFTP uploads, local snapshots, simulator clean-up | `/usr/bin/sftp`, `~/.ssh`, `tmutil` and `xcrun` are outside the sandbox |
| Private APIs | Guidelines 2.5.1 |

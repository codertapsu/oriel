# Oriel in the Mac App Store

The Mac App Store edition is the same app, sandboxed, built by the `OrielAppStore` target (PLAN §18, §19). It has the release's bundle ID, `com.codertapsu.oriel`, leaves out the tools the sandbox cannot run (the window switcher, Window Tiling and Activity Monitor), and is free, with **Oriel Pro** as a one-time in-app purchase. This document says what the edition is, what is ready in the repository and what App Review checks. [APP_STORE_CONNECT.md](APP_STORE_CONNECT.md) is the step-by-step procedure for the store. PLAN §19 explains how the edition works, and `docs/RELEASING.md` → The App Store edition covers archiving and uploading each version.

## What the repository already has

| Item | Where |
|---|---|
| The target, its configurations and scheme | `project.yml`: `OrielAppStore`; Debug-AppStore and Release-AppStore; scheme **Oriel App Store** |
| Entitlements | `App/AppStore/OrielAppStore.entitlements` (Release): sandbox, network client, user-selected files and their bookmarks, Pictures, Movies, microphone, camera, iCloud key-value storage. `OrielAppStoreDebug.entitlements` is the same without iCloud, which needs a provisioning profile |
| Info.plist | `App/AppStore/Info.plist`: export compliance (`ITSAppUsesNonExemptEncryption` false), the Utilities category, the purpose strings |
| Privacy manifest | `App/Resources/PrivacyInfo.xcprivacy` (PLAN §19.7) |
| Oriel Pro | `Packages/Licensing`, product ID `com.codertapsu.oriel.pro`; `App/StoreKit/Oriel.storekit` for testing in Xcode |
| Checks | `make appstore-check` (`scripts/verify-appstore.sh`: both slices, no private symbol, no helper or CLI, the sandbox, export compliance, the manifest) and the edition's tests in `make test` |
| Privacy policy, support page, terms of use | <https://codertapsu-web.web.app/oriel/privacy>, [/oriel/support](https://codertapsu-web.web.app/oriel/support), [/oriel/terms](https://codertapsu-web.web.app/oriel/terms) |

## Getting it into the store

[APP_STORE_CONNECT.md](APP_STORE_CONNECT.md) is the step-by-step procedure, with every screen and field and Oriel's value for each. In short:

1. **Business:** the Account Holder accepts the Paid Apps agreement, then completes the tax forms, then adds the bank account.
2. **Register this Mac** as one of the team's devices: App Store archives are signed for development first, and the team had no device on 2026-11-02.
3. **Archive:** `make appstore-archive` at the release tag. Xcode registers the App ID with iCloud and makes the profiles.
4. **Create the app record** in App Store Connect → Apps → **+** → **New App**:
   - macOS;
   - name **Oriel: Screenshot & Translate** (fallbacks: Oriel: Capture & Translate, Oriel Screen Toolkit);
   - English (U.S.);
   - bundle ID `com.codertapsu.oriel`;
   - SKU `oriel-mac`.
5. **App Information:**
   - subtitle **Record, annotate, extract text**;
   - categories Utilities and Productivity;
   - age rating 4+;
   - the privacy policy URL.

   Then the price, **Free**, and App Privacy, **Data Not Collected**.
6. **Oriel Pro:**
   - non-consumable, `com.codertapsu.oriel.pro`, US$10.00;
   - Family Sharing left off; once on, it can never be turned off;
   - display name "Oriel Pro", description "Every Pro feature, one purchase.";
   - a review screenshot and notes.
7. **The 1.0.0 version page:**
   - screenshots, at one of 1280 × 800, 1440 × 900, 2560 × 1600 or 2880 × 1800;
   - promotional text, description and keywords;
   - support URL, copyright;
   - App Review information, manual release.
8. **Upload** with `make appstore-upload` or from Xcode's Organizer, **test** in TestFlight (QA items 49–53), then **submit** the version and Oriel Pro together.

Certificates, the membership and their renewals are in [APPLE_ACCOUNT.md](APPLE_ACCOUNT.md).

## Each version

`docs/RELEASING.md` → The App Store edition: archive, upload (`make appstore-upload` or the Organizer), test in TestFlight, submit. App Store builds are not notarized: App Review stands in for it.

### Notes for App Review

The text to paste is in [APP_STORE_CONNECT.md](APP_STORE_CONNECT.md) step 10, with the description, keywords and the other fields of the version page.

### Rejections to pre-empt

| Guideline | What it rejects | Where Oriel stands |
|---|---|---|
| 2.5.1 | Private APIs, even as strings | The edition links no PrivateAPIs; `make appstore-check` looks for the names |
| 2.4.5 | Entitlements without a feature; the user's files saved in the container, out of their sight; files outside the container without the user's choice; launching at login unasked; root, helpers | Each entitlement has its feature (network: providers and uploads; user-selected files and bookmarks: the save folders, Disk Space Analyzer's grants, shared folders, opened images and files; Pictures: the default capture folder; Movies: the default recordings folder; microphone and camera: recordings; iCloud: settings sync). Captures and recordings go to Pictures/Oriel and Movies/Oriel, or to folders the user chooses; the container holds only app data. Open at login is off until the user turns it on. No helper, daemon or CLI |
| 3.1.1 | Unlocking features without in-app purchase; no Restore | Pro is sold only through StoreKit; Restore Purchases is in Settings → Oriel Pro |
| 5.1.1 | Missing purpose strings or privacy policy | The purpose strings are in the Info.plist; the policy is linked in App Store Connect and in the app |
| 5.1.1(iv) | A custom message before a permission request whose button pushes to allow it ("Grant", "Allow") | The welcome window and Settings → Permissions say Continue, mark nothing required, and Done closes the window whatever was allowed (rejected for "Grant" on 2026-11-12) |
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

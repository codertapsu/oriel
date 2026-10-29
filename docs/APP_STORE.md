# Oriel and the Mac App Store

## The short answer

**Oriel as built cannot be published in the Mac App Store**, and the plan does not intend to (PLAN §1.5, D3). Oriel is distributed with Developer ID, notarized, which needs no review and has none of the restrictions below (`docs/BUILDING.md`).

What blocks it is not a missing setting but how the window switcher works:

| Oriel needs | App Store rule it breaks |
|---|---|
| Private SkyLight and HIServices functions to list windows on other Spaces, focus a single window and take over Cmd-Tab (`Packages/PrivateAPIs`) | Guideline 2.5.1: apps may only use public APIs. Resolving them with `dlsym` does not help: the symbol names are in the binary. |
| An active event tap that consumes keystrokes (the switcher's shortcuts), synthetic scroll events (automatic scrolling capture), control of other apps' windows through Accessibility | Guideline 2.4.5(i): Mac App Store apps must be sandboxed. These calls are either unavailable in the App Sandbox or are a review risk even when the user grants Accessibility. |
| The `oriel` command-line tool linked into `/usr/local/bin`, using an administrator password | 2.4.5(ii) and (v): an App Store app must be self-contained, may not install code in shared locations and may not ask for root privileges. |

The capture, editor, recording, OCR and translation tools use public APIs only, and could ship in the App Store as a separate, sandboxed app. The plan kept that door open on purpose: no package except WindowSwitcher depends on PrivateAPIs (PLAN §2.3). The rest of this document is the step-by-step path to that edition, called **Oriel Capture** below.

## What an App Store edition contains

| Feature | In Oriel Capture? |
|---|---|
| Screenshots (area, window, screen, timer), Quick Access Overlay, pins, history | Yes. ScreenCaptureKit works in the sandbox; the user still grants Screen Recording. Apple also offers `SCContentSharingPicker`, which needs no standing permission, for window and screen capture. |
| Editor and exports | Yes. Saving outside the container goes through `NSSavePanel` (user-selected files) or a security-scoped bookmark to the chosen default folder. |
| Screen recording, system audio, microphone, camera bubble, click rings | Yes, with the microphone and camera entitlements. |
| Keystroke HUD | No: global key monitoring is what the sandbox and review restrict. |
| Scrolling capture | Manual mode only (the user scrolls); automatic mode posts synthetic events. |
| OCR and translation (Apple Translation, Foundation Models, cloud and local LLM providers) | Yes, with the network client entitlement. Local endpoints over plain HTTP need an ATS exception, which review may question; prefer HTTPS. |
| S3 upload | Yes. |
| Window switcher, Cmd-Tab takeover, trackpad gestures | No. |
| `oriel` CLI and IPC socket | No: drop it, and keep the App Intents for Shortcuts instead (PLAN §7.17). |
| Launch at login (`SMAppService`) | Yes, but only if the user turns it on (2.4.5(iii)). |
| Bootstrap import | From the app's container or a managed `BootstrapURL`; there is no shared Application Support folder. |

## Step by step

### 1. Developer account and identifiers

1. Use the same Apple Developer Program team (`4XVYLW8RXS`).
2. developer.apple.com → Certificates, Identifiers & Profiles → **Identifiers** → **+** → App IDs → App. Register a new bundle ID, for example `com.codertapsu.oriel.capture`. Use a different ID from the Developer ID app, so both can be installed side by side. No extra capabilities are needed.
3. App Store Connect (appstoreconnect.apple.com) → **Apps** → **+** → New macOS App. Pick the bundle ID, name (e.g. "Oriel Capture"), primary language and SKU.

### 2. Certificates and profile

| Certificate | Purpose | On this Mac today |
|---|---|---|
| Apple Distribution | Signs the app for the App Store | Present (`security find-identity -v -p codesigning`) |
| Mac Installer Distribution (formerly "3rd Party Mac Developer Installer") | Signs the `.pkg` that is uploaded | **Missing**: create it in Xcode → Settings → Accounts → Manage Certificates → **+** |

Then create a provisioning profile: Profiles → **+** → Distribution → **Mac App Store Connect**, for the new bundle ID and the Apple Distribution certificate. Download it and double-click it to install. Alternatively, let Xcode manage signing for that target.

### 3. A second target in `project.yml`

Add a target (and a scheme) next to `Oriel`, built from the same packages minus WindowSwitcher, PrivateAPIs and IPC:

```yaml
  OrielCapture:
    type: application
    platform: macOS
    sources: [App/Sources, App/Resources]        # with the switcher, CLI and IPC code behind #if !APP_STORE
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.codertapsu.oriel.capture
        SWIFT_ACTIVE_COMPILATION_CONDITIONS: "$(inherited) APP_STORE"
        CODE_SIGN_STYLE: Automatic
        CODE_SIGN_IDENTITY: "Apple Distribution"
        ENABLE_APP_SANDBOX: YES
    entitlements:
      path: App/OrielCapture.entitlements
      properties:
        com.apple.security.app-sandbox: true
        com.apple.security.network.client: true                 # translation providers, uploads
        com.apple.security.files.user-selected.read-write: true # save panels, the chosen default folder
        com.apple.security.files.bookmarks.app-scope: true      # remember that folder
        com.apple.security.device.audio-input: true             # microphone in recordings
        com.apple.security.device.camera: true                  # camera bubble
    dependencies:
      - package: OrielCore
      - package: Permissions
      - package: SharedUI
      - package: Hotkeys          # Carbon hot keys work in the sandbox; the event tap is not used
      - package: Capture
      - package: Recording
      - package: Editor
      - package: OCR
      - package: OrielTranslation
      - package: Upload
```

### 4. Code changes for the sandbox

- Compile out everything that references `WindowSwitcherModule`, `PrivateAPIs`, `IPCServer`, `CLIInstaller` and `EventTapEngine` with `#if !APP_STORE`. The App Store binary must not contain the private symbol names at all, not even as strings.
- In Capture, offer only manual scrolling capture under `APP_STORE`. In Recording, hide the keystroke HUD.
- Replace the default save folder with one the user picks once in an `NSOpenPanel`, kept as a security-scoped bookmark.
- History, recordings and the bootstrap file move to the container; `AppPaths` already resolves `applicationSupportDirectory`, which the sandbox redirects into it.
- Keychain items are per app in the sandbox, and nothing else changes for `KeychainStore`.
- Add to the target's Info.plist: `ITSAppUsesNonExemptEncryption = NO` (Oriel uses only the system's HTTPS, which is exempt), and an `LSApplicationCategoryType` such as `public.app-category.productivity`.

### 5. Privacy manifest

Add `App/Resources/PrivacyInfo.xcprivacy` to the App Store target. Declare no tracking, no collected data, and the "required reason" APIs Oriel uses:

| API category | Why Oriel uses it | Reason code |
|---|---|---|
| `NSPrivacyAccessedAPICategoryUserDefaults` | Its own settings | `CA92.1` |
| `NSPrivacyAccessedAPICategoryFileTimestamp` | Sorting history and recordings in its container | `C617.1` |
| `NSPrivacyAccessedAPICategorySystemBootTime` | Measuring elapsed time (recording timer, timeouts) | `35F9.1` |

Check the current list in Apple's "Describing use of required reason API" documentation before submitting; it changes. In App Store Connect → App Privacy, answer "Data Not Collected". Translation text goes only to the provider the user configures, at the user's request; say so in the privacy policy.

### 6. Store listing

Fill in, in App Store Connect:

- the description and keywords;
- a support URL and a privacy policy URL (both required);
- the category and the age rating questionnaire;
- at least one screenshot at 1280×800, 1440×900, 2560×1600 or 2880×1800;
- the 1024×1024 icon, which comes from the asset catalog in the build.

### 7. Archive, validate and upload

**With Xcode:** choose the `OrielCapture` scheme, then Product → **Archive**. In the Organizer, choose **Validate App**, fix whatever it reports, then **Distribute App** → **App Store Connect** → **Upload**. Xcode signs with Apple Distribution and the installer certificate and uses the profile.

**From the command line:** archive the scheme, then export with an `ExportOptions-AppStore.plist`:

```xml
<dict>
    <key>method</key>          <string>app-store-connect</string>
    <key>destination</key>     <string>upload</string>
    <key>teamID</key>          <string>4XVYLW8RXS</string>
    <key>signingStyle</key>    <string>automatic</string>
</dict>
```

```bash
xcodebuild archive -project Oriel.xcodeproj -scheme OrielCapture -configuration Release \
  -destination 'generic/platform=macOS' -archivePath build/OrielCapture.xcarchive
xcodebuild -exportArchive -archivePath build/OrielCapture.xcarchive \
  -exportOptionsPlist ExportOptions-AppStore.plist -exportPath dist/appstore -allowProvisioningUpdates \
  -authenticationKeyPath AuthKey_XXXXXXXXXX.p8 -authenticationKeyID XXXXXXXXXX -authenticationKeyIssuerID <issuer-uuid>
```

The API key comes from App Store Connect → Users and Access → Integrations → App Store Connect API (Developer role). With `destination` set to `export` instead, you get a `.pkg` to upload with Apple's **Transporter** app.

App Store builds are not notarized separately: App Review replaces notarization.

### 8. TestFlight

Each uploaded build appears in App Store Connect → TestFlight after processing, which takes minutes to an hour. Add internal testers (team members) to try it before review. Mac TestFlight builds install through the TestFlight app.

### 9. Submit for review

Create the version in App Store Connect, select the build, and write review notes. Explain that Screen Recording is used only for screenshots and recordings the user starts, that the microphone and camera are optional for recordings, and which network services translation can call. Then submit. First reviews usually take one to three days.

### 10. Common rejections to pre-empt

- **2.5.1**: a private symbol name anywhere in the binary. Check with `strings`, for example `strings -a OrielCapture | grep -E 'SLS|SLPS|_AXUIElement|CGSSetSymbolic'`, which must print nothing.
- **2.4.5**: an entitlement that is not used, writing outside the container without user consent, launching at login without the user turning it on.
- **5.1.1**: missing or vague purpose strings (`NSMicrophoneUsageDescription`, `NSCameraUsageDescription`), or no privacy policy.
- **4.2**: an app that does too little. Oriel Capture is a full screenshot, recording and translation tool, so this should not apply.

## Effort

Expect roughly one to two weeks for the second target, the `#if APP_STORE` gates, bookmarks for the save folder, the privacy manifest and the listing, plus review time. The Developer ID app stays as it is, and both editions build from the same packages.

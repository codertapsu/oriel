# Registering Oriel in App Store Connect

The complete procedure for putting Oriel's Mac App Store edition (PLAN §18, §19) into the store: from the Apple Developer account to a submitted version with Oriel Pro attached. It is written so that you, or a developer new to the project, can repeat it without other help. Each field gives the value Oriel uses and Apple's rule for it.

- What the App Store edition is and why it differs: [APP_STORE.md](APP_STORE.md).
- Certificates, the membership and their renewals: [APPLE_ACCOUNT.md](APPLE_ACCOUNT.md).
- Building and releasing each version: [RELEASING.md](RELEASING.md).

Labels are as of November 2026, and Apple renames buttons now and then. When App Store Connect and this guide disagree, App Store Connect is right; update this guide. Apple's help pages are linked in [References](#references).

## The order, and where things stand

| # | Step | Who can do it | Where | State on 2026-11-02 |
|---|---|---|---|---|
| 1 | The membership is active | Account Holder | developer.apple.com/account | Check the date there ([APPLE_ACCOUNT.md](APPLE_ACCOUNT.md)) |
| 2 | Paid Apps agreement, tax forms, bank account | Account Holder | App Store Connect → Business | To do |
| 3 | Register this Mac as one of the team's devices | Account Holder or Admin | Certificates, Identifiers & Profiles → Devices | **To do**: blocks the archive. The values are ready in step 3.2 |
| 4 | App ID `com.codertapsu.oriel` with iCloud | Xcode, automatically | Certificates, Identifiers & Profiles | Happens with the first archive after step 3 |
| 5 | Signed archive of 1.0.0 (134) | Anyone on the team | This Mac | Waits for step 3 |
| 6 | Create the app record | Account Holder, Admin, App Manager | App Store Connect → Apps → + | To do (web only) |
| 7 | App Information: subtitle, category, age rating, privacy policy | Account Holder, Admin, App Manager | App Information | To do |
| 8 | Pricing and Availability | Account Holder, Admin, App Manager | Pricing and Availability | To do |
| 9 | App Privacy | Account Holder, Admin, App Manager | App Privacy | To do |
| 10 | Oriel Pro, the in-app purchase | Account Holder, Admin, App Manager, Developer, Marketing | Monetization → In-App Purchases | To do |
| 11 | The 1.0.0 version page: screenshots, text, review information | Account Holder, Admin, App Manager, Marketing | macOS App → 1.0.0 | To do |
| 12 | Upload the build | Anyone with the archive and the team in Xcode | Xcode Organizer | After 5 and 6 |
| 13 | Test in TestFlight | Account Holder, Admin, App Manager | TestFlight | After 12 |
| 14 | Submit for review, with Oriel Pro | Account Holder, Admin, App Manager | The version page | After 7–13 |

Only steps 2 and 6 cannot be done from this Mac at all: Apple offers no API to accept agreements or create an app record.

## 1. Before you start

**You need:**

- **An active Apple Developer Program membership** for team `4XVYLW8RXS`; see [APPLE_ACCOUNT.md](APPLE_ACCOUNT.md) to check and renew it. An expired membership hides Certificates, Identifiers & Profiles and blocks every submission.
- **The Account Holder's Apple Account.** The team is an individual membership, so the Account Holder is you, and you can do every step.
- **A Mac with Xcode 27.1 or later** and the team's account added in Xcode → Settings → Accounts. Check with `defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier`, which lists the team when it is there.
- **The repository at the release tag** (`git checkout v1.0.0`), clean.
- **Oriel's web pages**, which App Store Connect asks for:
  - privacy policy: <https://codertapsu-web.web.app/oriel/privacy>
  - support: <https://codertapsu-web.web.app/oriel/support>
  - terms of use: <https://codertapsu-web.web.app/oriel/terms>

  They come from the `codertapsu-web` repository's `apps.json`.
- **Screenshots** of the App Store edition (step 11). Prepare them before step 11, from a TestFlight or Debug-AppStore build.

**Roles,** if more people join the team later (App Store Connect → Users and Access):

| Role | Can |
|---|---|
| Account Holder | Everything, and alone: sign agreements, approve bank accounts, create Developer ID certificates, renew the membership |
| Admin | Everything in App Store Connect except agreements; manage users |
| App Manager | App records, in-app purchases, versions, TestFlight, submissions |
| Developer | Upload builds, manage in-app purchases, see TestFlight |
| Marketing | Metadata, screenshots, in-app purchase text |

## 2. Agreements, tax and banking

App Store Connect → **Business** (<https://appstoreconnect.apple.com/business>). Only the Account Holder can sign. The order matters: agreement, then tax forms, then bank account.

### 2.1 The Paid Apps agreement

1. Open **Business** → **Agreements**.
2. The **Free Apps** agreement is active with the membership. In the **Paid Apps** row, click **View and Agree to Terms**, read it, tick the box and click **Agree**. Apple notes that accepting it cannot be undone.
3. The row then waits for the tax forms and the bank account. It becomes **Active** once both are processed, which can take a day or more.

Without an active Paid Apps agreement, Oriel Pro cannot be sold. Outside Xcode's StoreKit testing the product does not load either, so Settings → Oriel Pro shows its button without a price.

### 2.2 Tax forms

1. **Business** → **Tax Forms** → **Add Tax Info**.
2. Every developer completes a U.S. tax form. Answer the questions; they lead to the right form. For an individual outside the United States this is usually a **W-8BEN** (Certificate of Foreign Status of Beneficial Owner).
3. Enter your legal name exactly as on your identity documents, your permanent residence address, your country of citizenship and your foreign tax identifying number, then sign electronically and submit.
4. Some countries add a local tax form (VAT, GST); App Store Connect asks for it if yours does.
5. Changing a submitted form later is possible for some forms in App Store Connect; for others, contact Apple.

This is not tax advice. If you are unsure which treaty, if any, applies to you, ask a tax adviser before signing.

### 2.3 Bank account

1. **Business** → **Bank Accounts** → **Add Bank Account**.
2. Choose the bank's country, then fill in the bank details it asks for, typically the SWIFT/BIC code and the account number.
3. Enter the **account holder's name exactly as the bank has it**, and the address the bank has for you.
4. Choose the currency the account receives, check everything and confirm.

If an Admin or Finance user enters the account, the Account Holder must approve it in App Store Connect before Apple processes it.

## 3. Identifiers, devices and signing

This happens in Certificates, Identifiers & Profiles (<https://developer.apple.com/account/resources>) and mostly through Xcode. Read it to understand what Xcode does, and do step 3.2 by hand.

### 3.1 How the App Store edition is signed

| Stage | Signed with | Profile | Made by |
|---|---|---|---|
| Archive (`make appstore-archive`) | Apple Development certificate | Mac Team Provisioning Profile for `com.codertapsu.oriel`, a development profile, which lists registered devices | Xcode, automatic signing |
| Upload (`make appstore-upload`, or Organizer → Distribute App) | Apple Distribution certificate; the uploaded package with Mac Installer Distribution | Mac App Store profile for `com.codertapsu.oriel` | Xcode, at upload |
| Release | Apple re-signs it | — | Apple |

The Developer ID certificate plays no part here; it signs only the Developer ID edition.

### 3.2 Register this Mac (once per Mac)

A development profile needs at least one registered device. The team had none on 2026-11-02, so every archive stops with "Communication with Apple failed: Your team has no devices from which to generate a provisioning profile". `xcodebuild -allowProvisioningDeviceRegistration` does not register the Mac it runs on (`docs/os-quirks.md`), so register it in the browser:

1. Open <https://developer.apple.com/account/resources/devices/add> (Certificates, Identifiers & Profiles → **Devices** → **+**).
2. **Platform:** macOS.
3. **Device Name:** something you will recognise, such as `MacBook Pro M4 Pro (dev)`.
4. **Device ID (UDID):** the Mac's Provisioning UDID. For the development MacBook Pro it is **`00006040-000211A13AEA801C`**. For another Mac, read it with `system_profiler SPHardwareDataType | grep "Provisioning UDID"`, or in System Information → Hardware → Provisioning UDID.
5. Click **Continue**, check the details and click **Register**.

A team can register 100 Macs per membership year. A device you remove still counts until the membership renews, so register only Macs that build Oriel.

Xcode can do the same from its editor: open `Oriel.xcodeproj`, choose the scheme **Oriel App Store** and the target **OrielAppStore** → **Signing & Capabilities**, with **Automatically manage signing** on. When it reports the missing device, follow its offer to register this Mac. The browser route above is the one that always works.

### 3.3 The App ID

The first archive after step 3.2 lets Xcode register `com.codertapsu.oriel` as an explicit App ID, with the capabilities the entitlements ask for:
- **iCloud**, for key-value storage (settings sync);
- **In-App Purchase**, which every App ID has.

Xcode then makes the Mac Team Provisioning Profile. Nothing else is needed: the sandbox, network, files, Pictures, Movies, microphone and camera entitlements need no portal capability.

To check, or to do it by hand, open <https://developer.apple.com/account/resources/identifiers>.
- **If `com.codertapsu.oriel` is listed,** open it and check that **iCloud** is ticked. Key-value storage needs no iCloud container; the CloudKit option can stay off.
- **If it is missing:**
  1. Click **+** → **App IDs** → **App** → **Continue**.
  2. Description: `Oriel`.
  3. Bundle ID: **Explicit**, `com.codertapsu.oriel`.
  4. Tick **iCloud** under Capabilities, then click **Continue** and **Register**.

### 3.4 The signed archive

With the Mac registered, from the repository at the release tag:

```bash
git checkout v1.0.0          # the tag of the version you submit; the tree must be clean
make appstore-archive        # Release-AppStore, both slices, build number = commit count
```

This writes `dist/Oriel-AppStore.xcarchive`. It runs `xcodebuild archive -allowProvisioningUpdates`, which lets Xcode sign in to the developer portal with the account in Xcode. That is how it makes the App ID, the profile and, if needed, an Apple Development certificate.

Check the archive:

```bash
APP=dist/Oriel-AppStore.xcarchive/Products/Applications/Oriel.app
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" -c "Print :CFBundleVersion" "$APP/Contents/Info.plist"   # 1.0.0, 134
lipo -archs "$APP/Contents/MacOS/Oriel"                                 # x86_64 arm64
codesign -d --entitlements - --xml "$APP" | plutil -p - | grep -E "sandbox|ubiquity"   # the sandbox and iCloud
```

`make appstore-check` builds the same Release unsigned and checks it for App Review (`scripts/verify-appstore.sh`); the release gate runs it for every release.

## 4. Create the app record

App Store Connect → **Apps** (<https://appstoreconnect.apple.com/apps>). The app record can be created only here. App Store Connect refuses to create it until the Account Holder has accepted the latest agreement in Business. The Paid Apps agreement may still be pending.

1. Click **+** (top left) → **New App**.
2. Fill in the dialog:

   | Field | Value | Rules |
   |---|---|---|
   | Platforms | **macOS** only | One record can hold several platforms that share a bundle ID; Oriel is Mac only |
   | Name | **Oriel: Screenshot & Translate** | 2–30 characters. A name can be used by one app per localization across the whole store. If it is taken: **Oriel: Capture & Translate**, then **Oriel Screen Toolkit**. It can change with a later version |
   | Primary Language | **English (U.S.)** | Can be changed at any time |
   | Bundle ID | **Oriel – com.codertapsu.oriel** | The list shows the explicit App IDs of step 3.3. **It cannot change once a build is uploaded** |
   | SKU | **oriel-mac** | Letters, numbers, hyphens, periods and underscores, not starting with a hyphen, period or underscore. Never shown to customers. **It cannot change once the app is added** |
   | User Access | **Full Access** | Limited Access only matters with more users |

3. Click **Create**. App Store Connect opens the new record, with the version **1.0 Prepare for Submission** under macOS App; you set the version number to 1.0.0 in step 11.
4. Note the app's **Apple ID**, App Information → General Information → Apple ID, a number. It goes into the record of this app in [Appendix A](#appendix-a-oriels-values).

**If something goes wrong:**
- "The app name you entered is already being used": choose the next name above.
- The bundle ID is not in the list: step 3.3 has not happened yet; archive once, or register it by hand.
- "You can't add an app until the Account Holder signs the latest agreement": step 2.1.

## 5. App Information

In the record: **General** → **App Information**.

| Field | Value | Notes |
|---|---|---|
| Name | Oriel: Screenshot & Translate | From step 4; localizable |
| Subtitle | **Record, annotate, extract text** | 30 characters at most (this is 30) |
| Category: Primary | **Utilities** | Matches the bundle's `LSApplicationCategoryType`, `public.app-category.utilities` |
| Category: Secondary | **Productivity** | Optional |
| Content Rights | **No**, the app does not contain, show or access third-party content | Oriel works on what is on the user's own screen and files; translation and upload services are the user's own accounts |
| Age Rating | **4+**, from the questionnaire below | Required |
| License Agreement | Apple's standard EULA | Oriel's terms add to it; the description links them |
| Privacy Policy URL | <https://codertapsu-web.web.app/oriel/privacy> | Required for macOS apps; localizable |

**The age rating questionnaire** (Age Rating → **Set Up Age Ratings**):

1. **In-app controls and capabilities.** Select none. Oriel has:
   - no parental controls or age assurance;
   - no unrestricted web access: it is not a browser, and links open in the user's browser;
   - no user-generated content shared with others;
   - no messaging or chat;
   - no advertising.

   Click **Next**.
2. **Content descriptions.** Answer **None** (or **No**) for every question: violence, sexual content, profanity, horror, drugs, gambling and contests, medical or wellness topics, and the rest. Click **Next**.
3. **Age Categories and Override.** Choose **Not Applicable**: no override, and not Made for Kids.
4. Click **Save**, and check that the calculated rating, global and per region, is **4+**.

## 6. Pricing and Availability

In the record: **Pricing and Availability**.

1. **Price Schedule** → **Add Pricing** (or **Set Up Price**): base country or region **United States (USD)**, price **Free**, then **Next** and **Confirm**. Oriel itself is free; Oriel Pro is sold inside it (step 10).
2. **Availability** → **Set Up Availability**: **All countries or regions** (the default), then **Confirm**.
3. **Tax Category**: leave the default, App Store software.

## 7. App Privacy

In the record: **App Privacy**.

1. **Privacy Policy** → **Edit**: <https://codertapsu-web.web.app/oriel/privacy> → **Save**.
2. **Data Collection** → **Get Started**.
3. To "Do you or your third-party partners collect data from this app?" answer **No, we do not collect data from this app** → **Save**.
4. Click **Publish**: answers count only once they are published. The product page then shows **Data Not Collected**.

Why "No" is right: Apple counts data as collected when it leaves the device in a way that lets you or your partners keep or access it beyond answering the request at hand. Oriel sends its developer nothing: it has no account, no server, no analytics and no ads.
- **Translation:** text goes to a provider the user chooses, after the user allows it (PLAN §19.6), directly from their Mac under their own account and key.
- **Uploads:** captures go only to storage the user set up.
- **Settings sync:** preferences go to the user's own iCloud.

The privacy manifest (`App/Resources/PrivacyInfo.xcprivacy`) declares no collected data either. The answer is for the whole app, across platforms. If Oriel ever adds analytics, crash reporting or an account, these answers and the manifest must change first.

## 8. Oriel Pro, the in-app purchase

In the record: **Monetization** → **In-App Purchases**.

### 8.1 Create it

1. Click **+**.
2. **Type:** **Non-Consumable**: bought once, kept forever, restorable.
3. **Reference Name:** **Oriel Pro**. Up to 64 characters, internal only, and editable at any time.
4. **Product ID:** **`com.codertapsu.oriel.pro`**. Letters, numbers, hyphens, periods and underscores, up to 100 characters. It must equal `ProStore.productID` in `Packages/Licensing`. **It cannot be edited after saving, and can never be used again in this app, even after deletion.**
5. Click **Create**.

### 8.2 Fill it in

On the in-app purchase's page:

| Section | Value | Rules |
|---|---|---|
| Availability | **All countries or regions** (the app's) | — |
| Price Schedule | **Add Pricing** → base country **United States** → **USD 10.00** → **Next** → check the prices App Store Connect proposes for the other regions → **Confirm** | Customers see the price in their currency |
| App Store Localization: English (U.S.) | Display Name **Oriel Pro**; Description **Every Pro feature, one purchase.** | Display name 2–30 characters; description at most 45 (this is 32). Changes go through review |
| Review Information: Screenshot | A screenshot of Settings → Oriel Pro, at 1280 × 800, 1440 × 900, 2560 × 1600 or 2880 × 1800, PNG or JPEG without transparency | Only App Review sees it. It can be replaced, not removed |
| Review Information: Review Notes | The text below | At most 4000 characters |
| Family Sharing | **Leave it off** | **Once turned on, it can never be turned off** |
| Tax Category | Leave **Match to parent app** | — |
| Image | None | Optional; only to promote the purchase on the product page (1024 × 1024, JPG or PNG, 72 dpi, RGB, flattened, no rounded corners) |

Review notes for Oriel Pro:

> Oriel Pro is a non-consumable in-app purchase. It unlocks the Pro features listed in Settings → Oriel Pro: click Oriel's icon in the menu bar → Settings… → Oriel Pro. Restore Purchases is in the same pane. Without Oriel Pro every tool works; each Pro feature is marked PRO and opens this pane.

When every section is complete, the status reads **Ready to Submit**.

**The first in-app purchase must be submitted with a new app version** (step 14). Later in-app purchases can go to review alone, once the app has an approved version.

## 9. Screenshots

The version page (step 10) needs at least one screenshot; up to 10 can be added. Accepted sizes for Mac, 16:10:
- 1280 × 800
- 1440 × 900
- 2560 × 1600
- 2880 × 1800

Use JPEG or PNG, **without transparency**.

**Suggested set**, from a TestFlight or Debug-AppStore build of the App Store edition, never the Developer ID one:
1. the capture overlay;
2. the editor with an annotated capture;
3. a translation drawn over a page;
4. Clipboard History;
5. Disk Space Analyzer;
6. the feature tour;
7. Settings → Oriel Pro.

Show only what this edition has: no window switcher, Window Tiling or Activity Monitor.

**Making them the right size:**
1. Capture a 16:10 region with Oriel itself or ⇧⌘4. On a Retina display, a selection of 1440 × 900 points gives 2880 × 1800 pixels.
2. Check: `sips -g pixelWidth -g pixelHeight shot.png`.
3. Scale an exact 16:10 image: `sips -z 1800 2880 shot.png --out shot-2880.png`. `-z` takes height then width; an image that is not 16:10 is distorted, so crop it first.
4. Remove transparency by writing JPEG: `sips -s format jpeg -s formatOptions 90 shot-2880.png --out shot-2880.jpg`.

## 10. The 1.0.0 version page

In the record: **macOS App** → the version in **Prepare for Submission**.

| Field | Value | Rules |
|---|---|---|
| Version | **1.0.0** | Must equal the build's `CFBundleShortVersionString` (`MARKETING_VERSION` in `project.yml`) |
| Screenshots | Step 9 | 1–10; Mac sizes above |
| Promotional Text | Below | At most 170 characters; can change without review |
| Description | Below | At most 4000 characters, plain text, no HTML |
| Keywords | **`screen capture,screen recorder,ocr,annotate,clipboard history,color picker,ruler,disk space`** | At most 100 bytes (this is 91); terms longer than two characters, separated by commas; no app or company names, nor words already in the name |
| Support URL | <https://codertapsu-web.web.app/oriel/support> | Required; must show real contact details |
| Marketing URL | <https://codertapsu-web.web.app/> | Optional |
| Copyright | **2026 Hoàng Duy Khánh** | The year rights were obtained, then the owner; App Store Connect adds © |
| Build | **1.0.0 (134)**, after step 11 | — |
| In-App Purchases and Subscriptions | **Oriel Pro** (step 14) | — |
| App Review Information: Sign-in required | **Off** | Oriel has no account |
| App Review Information: Contact | Your first and last name, phone in international format (**+84** and the number), and the support email | Required; not shown to customers |
| App Review Information: Notes | Below | At most 4000 bytes |
| Version Release | **Manually release this version** | Then nothing goes live until you click Release. Automatic and scheduled release are the other choices |

"What's New in This Version" does not exist for the first version; every later version needs it (at most 4000 characters).

**Promotional Text** (151 characters):

> Capture, record and translate anything on your screen, then mark it up. Plus clipboard history, disk space analysis, a color picker and a screen ruler.

**Description:**

```text
Oriel puts the tools you reach for every day in your Mac's menu bar: screenshots, screen recording, an image editor, on-screen translation, clipboard history, a disk space analyzer, a color picker and a screen ruler. Every tool starts from Oriel's menu or its own shortcut, and a feature tour shows what each one does.

SCREENSHOTS
• Capture an area, a window or a whole screen; the screen freezes while you choose, with a loupe for exact pixels.
• Copy, save, annotate, pin or read the text of every capture from the thumbnail in the corner.
• Capture Text: drag over any text on screen and Oriel copies it, read on your Mac.

EDITOR
• Arrows, shapes, text, highlights, blur, pixelate and crop; export PNG or JPEG.

SCREEN RECORDING
• Record an area, a window or a screen with system audio and your microphone, then trim it.

TRANSLATION
• Select text anywhere on screen and read its translation drawn over the original.
• Apple Translation and Apple Intelligence translate on your Mac.

CLIPBOARD HISTORY
• Everything you copy, encrypted on your Mac: search it, preview it and use it again.

DISK SPACE ANALYZER
• See where the space on your drives goes, and move what you no longer need to the Trash, with Undo.

COLOR PICKER AND SCREEN RULER
• Pick any pixel's color as HEX, RGB or HSL, and measure anything on screen in points or pixels.

ORIEL PRO
Every tool works for free. Oriel Pro, one purchase with no subscription, adds the advanced half of each: scrolling, instant and step capture, pin tools and the whole capture history; Smart Redact, backgrounds, numbered steps and HEIC and PDF export; the video editor, the camera bubble and GIF export; more translation providers, translation under the pointer, file translation and glossaries; the whole clipboard history; Clean Up, duplicates and old files; every color format, palettes and the contrast checker; ruler guides; uploads; and settings sync through iCloud. Settings → Oriel Pro lists it all, and Pro stays unlocked on every Mac where you use your Apple Account.

PRIVACY
Oriel works on your Mac. It has no account, no servers, no ads and no analytics. Text goes to a translation provider only if you choose one and allow it, and captures go only to storage you set up.

Terms of Use: https://codertapsu-web.web.app/oriel/terms
```

**App Review notes:**

> Oriel is a menu-bar utility: after it opens, its icon is in the menu bar at the top right, and Help → Oriel Feature Tour shows each tool. Screen & System Audio Recording is used only for the screenshots, recordings, on-screen translations and Screen Ruler measurements the user starts. The microphone and camera are used only in recordings, if the user turns them on. Translation runs on the Mac with Apple Translation and Apple Intelligence; the other providers (DeepL, Google Translate, OpenAI, Anthropic or the user's own server) need the user's own API key and ask the user's permission before the first request. Oriel Pro is a non-consumable in-app purchase; Settings → Oriel Pro lists what it adds and has Restore Purchases. Oriel has no account and no server.
>
> Entitlements: com.apple.security.assets.pictures.read-write saves screenshots to ~/Pictures/Oriel (Capture Area from the menu-bar menu, drag, then Command-S, or Save in the thumbnail); com.apple.security.assets.movies.read-write saves screen recordings to ~/Movies/Oriel (Record Area, then Control-Shift-R again to stop). Settings → Capture and Settings → Recording show those folders and let the user choose others.

## 11. Upload the build

The app record (step 4) must exist and the archive (step 3.4) must be there. Each upload needs a build number not used before for that version. Oriel's is the commit count, so a rebuild after a new commit is always new.

**With Xcode** (the usual way):

1. Double-click `dist/Oriel-AppStore.xcarchive`. Xcode opens the **Organizer** on it (Window → Organizer → Archives).
2. Select the archive (Oriel 1.0.0 (134)) → **Distribute App**.
3. Choose **App Store Connect** → **Distribute**. Older Xcode versions ask **Upload**, then **Next**.
4. If Xcode asks about options:
   - keep **Upload your app's symbols** on;
   - turn **Manage Version and Build Number** off, so the build stays 134;
   - choose **Automatically manage signing**.
5. Xcode signs with Apple Distribution and the Mac App Store profile, making them the first time, then validates and uploads. Fix whatever validation reports, archive again and repeat.

**From the command line**, with the same signing:

```bash
make appstore-archive      # at the release commit, clean tree: dist/Oriel-AppStore.xcarchive
make appstore-upload       # signs for the App Store with the account in Xcode and uploads it
```

`make appstore-upload` runs

```bash
xcodebuild -exportArchive -archivePath dist/Oriel-AppStore.xcarchive \
  -exportOptionsPlist ExportOptions-AppStore.plist -exportPath dist/AppStore -allowProvisioningUpdates
```

`ExportOptions-AppStore.plist` sets:
- method `app-store-connect` and destination `upload`;
- automatic signing for team `4XVYLW8RXS`;
- `manageAppVersionAndBuildNumber` false, so the build number stays the commit count;
- `uploadSymbols` true.

The log ends with "Uploaded package is processing" and "Upload succeeded".

To check the App Store signing without uploading, export a signed package instead. Copy the plist with `destination` set to `export`, and pass it as `-exportOptionsPlist`; `dist/AppStore/Oriel.pkg` is then signed by the Mac Installer Distribution certificate. Check it with `pkgutil --check-signature dist/AppStore/Oriel.pkg`. Apple's **Transporter** app can upload that package too.

**After the upload:**
- The build shows as **Processing** under TestFlight → macOS. Apple emails you when it is ready, usually within an hour.
- Export compliance is already answered by `ITSAppUsesNonExemptEncryption = false` in the Info.plist, so App Store Connect asks nothing.

## 12. Test in TestFlight

1. **TestFlight** → **Internal Testing** → **+**: a group named `Team`. Add yourself; internal testers must be users of the team in App Store Connect. Turn on automatic distribution, so each processed build reaches the group.
2. Install **TestFlight** from the Mac App Store, sign in with the same Apple Account and install Oriel from it.
3. **Before installing**, quit the Developer ID Oriel and move it out of /Applications. Both editions are `com.codertapsu.oriel`, must not run together, and install to the same place. macOS may ask for permissions again, because the App Store edition is signed by Apple.
4. Run QA items 49–53 in `docs/qa-checklists.md`. Buying Oriel Pro in TestFlight costs nothing.
5. Afterwards, reinstall the Developer ID edition from its disk image if this is your everyday Mac.

## 13. Submit for review

1. On the 1.0.0 version page, under **In-App Purchases and Subscriptions**, click **Select In-App Purchases or Subscriptions**. Tick **Oriel Pro** and click **Done**.

   The other way, from Oriel Pro's page: **Add for Review**, choosing the macOS app version.
2. Under **Build**, choose **1.0.0 (134)**.
3. Click **Add for Review** (top right). App Store Connect lists anything still missing; complete it.
4. In the draft submission, check that it holds **both** the 1.0.0 version and Oriel Pro, then click **Submit for Review**. They must go in the same submission, because the first in-app purchase needs a new version.
5. The statuses run: **Waiting for Review**, then **In Review**, then:
   - **Pending Developer Release**, since release is manual: click **Release This Version** when you want it on sale;
   - or **Rejected**.

   First reviews usually take one to three days, and Oriel Pro is reviewed with the app.
6. **If it is rejected**, App Review explains why under the version (App Review → messages).
   - Reply there if it is a misunderstanding.
   - Otherwise fix the cause and build again: a new commit gives a new build number.
   - Upload, choose the new build on the version page and submit again.

### When App Review rejects or asks

App Review's messages are under the submission: App Store Connect → the app → **App Review** (in the sidebar, under Distribution) → the submission. Each issue names a guideline. Answer each one under **Reply**, fix what needs fixing, and submit again.

1. **A question only** ("describe how and where the app uses the following entitlements"): reply with the steps that show it; no new build is needed. If the same submission also needs a fix, say so in the reply and upload the new build.
2. **A fix:**
   1. Fix it on `main` and run the gate (`make lint test universal-check appstore-check`).
   2. Commit; the build number is the new commit count.
   3. `make appstore-archive`, then upload the archive (step 11).
   4. On the version page, under **Build**, remove the old build and choose the new one.
3. **Reply** under the rejection: what changed, with steps App Review can follow. Then click **Add for Review** and **Submit for Review**, with the in-app purchase still in the submission.

The first review, of 1.0.0 build 134 on 2026-11-12, and its answers are in `docs/reports/09-app-review.md`.

## 14. After approval, and for later versions

- **Releasing:** with manual release, click **Release This Version**. The app appears in the store within about a day.
- **A new version:**
  1. You choose the version number; set `MARKETING_VERSION` in `project.yml`.
  2. Cut the release (`docs/RELEASING.md`), then `make appstore-archive` at the tag.
  3. In App Store Connect: **macOS App** → **+ Version**, the same number, and **What's New** (required).
  4. Choose the new build, then add it for review and submit.

  Oriel Pro needs no new review unless its text changes.
- **Changing the store name or subtitle:** only with a new version.

## Appendix A: Oriel's values

| Item | Value |
|---|---|
| Team | Khanh Hoang, `4XVYLW8RXS`, individual membership |
| Bundle ID | `com.codertapsu.oriel` (Debug builds: `com.codertapsu.oriel.appstore.debug`, never uploaded) |
| App name in the store | Oriel: Screenshot & Translate (fallbacks: Oriel: Capture & Translate, Oriel Screen Toolkit) |
| Name under the icon | Oriel |
| Subtitle | Record, annotate, extract text |
| SKU | oriel-mac |
| Apple ID of the app record | (write it here after step 4) |
| Primary language | English (U.S.) |
| Categories | Utilities; Productivity |
| Age rating | 4+ |
| Price | Free |
| In-app purchase | Oriel Pro, non-consumable, `com.codertapsu.oriel.pro`, US$10.00, Family Sharing off |
| Privacy | Data Not Collected; privacy policy <https://codertapsu-web.web.app/oriel/privacy> |
| Support | <https://codertapsu-web.web.app/oriel/support> |
| Terms | <https://codertapsu-web.web.app/oriel/terms> |
| Copyright | 2026 Hoàng Duy Khánh |
| Version and build | 1.0.0 (134), tag `v1.0.0` |
| Archive | `dist/Oriel-AppStore.xcarchive` from `make appstore-archive` |
| Registered device | MacBook Pro M4 Pro, Provisioning UDID `00006040-000211A13AEA801C` (to register; step 3.2) |

## References

Apple's pages this guide follows (checked on 2026-11-02):

- Add a new app: <https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app>
- App information: <https://developer.apple.com/help/app-store-connect/reference/app-information/app-information>
- Platform version information: <https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information>
- Screenshot specifications: <https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications>
- Set an app age rating: <https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating>
- Manage app privacy: <https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/>, and what counts as collected: <https://developer.apple.com/app-store/app-privacy-details/>
- Create in-app purchases: <https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/create-consumable-or-non-consumable-in-app-purchases>
- In-app purchase information: <https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information>
- Family Sharing for in-app purchases: <https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/turn-on-family-sharing-for-in-app-purchases/>
- Submit an in-app purchase: <https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase>
- Agreements: <https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/>; tax: <https://developer.apple.com/help/app-store-connect/manage-tax-information/provide-tax-information/>; banking: <https://developer.apple.com/help/app-store-connect/manage-banking-information/enter-banking-information/>

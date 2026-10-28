# Building, signing, notarizing and packaging Oriel by hand

This guide does by hand what `scripts/release/release-macos.sh` does in one command, so every step can be run, checked and understood on its own. The result is the same:

- `dist/Oriel.app`: a Universal (Apple silicon + Intel) app, signed with a Developer ID Application certificate, hardened runtime on, notarized by Apple, with the notarization ticket stapled.
- `dist/Oriel-<version>.dmg`: a signed disk image holding that app and an `/Applications` shortcut, itself notarized and stapled.

The quick ways are at the end: `make install` for your own Mac, `make release-dry-run` for a full release build. `docs/RELEASING.md` covers cutting a tagged release.

## 1. What you need

| Item | How to get it | How to check |
|---|---|---|
| A Mac on macOS 26 or later (27 recommended) | — | `sw_vers` |
| Xcode 27.1 or later (Swift 6.4, macOS 27 SDK) | App Store or developer.apple.com/download. Open it once, then `sudo xcodebuild -license accept` | `xcodebuild -version`, `xcode-select -p` (must point inside Xcode.app) |
| XcodeGen, SwiftLint, SwiftFormat | `brew install xcodegen swiftlint swiftformat` | `xcodegen --version` |
| Rosetta, for the Intel self-test | `softwareupdate --install-rosetta --agree-to-license` | `arch -x86_64 /usr/bin/true && echo ok` |
| A paid Apple Developer Program membership | developer.apple.com/programs | — |
| A **Developer ID Application** certificate (to distribute outside the App Store) | Xcode → Settings → Accounts → your team → Manage Certificates → **+** → Developer ID Application | `security find-identity -v -p codesigning` lists `Developer ID Application: <Name> (<TEAMID>)` |
| An **Apple Development** certificate (for Debug builds) | Same place → Apple Development | Listed by the same command |
| An **app-specific password** for notarization | appleid.apple.com → Sign-In and Security → App-Specific Passwords (it looks like `abcd-efgh-ijkl-mnop`; it is *not* your Apple ID password) | — |

The team ID (`4XVYLW8RXS` today) appears in `project.yml` (`DEVELOPMENT_TEAM`) and in `ExportOptions.plist` (`teamID`). Change both if you build for another team.

### Notarization credentials

The release scripts read four variables from `scripts/apple-credentials.env`, the same file the team's other desktop apps use:

```bash
cp scripts/apple-credentials.env.example scripts/apple-credentials.env   # then fill it in
chmod 600 scripts/apple-credentials.env
source scripts/apple-credentials.env
```

| Variable | Value |
|---|---|
| `APPLE_SIGNING_IDENTITY` | Exactly as `security find-identity` prints it: `Developer ID Application: <Name> (<TEAMID>)` |
| `APPLE_ID` | The Apple ID used for notarization |
| `APPLE_PASSWORD` | The app-specific password |
| `APPLE_TEAM_ID` | The 10-character team ID |

The file is git-ignored. Never commit it, paste it into a chat or an issue, or print it in a terminal you share. The commands below use `"$APPLE_ID"` and friends so that no value is ever typed in full.

## 2. Get the code and generate the project

```bash
git clone <repository-url> oriel && cd oriel
make generate          # xcodegen generate: writes Oriel.xcodeproj from project.yml
```

`Oriel.xcodeproj` is generated and git-ignored: change `project.yml`, never the project. `make generate` runs before every build target, so you rarely call it yourself.

## 3. Day-to-day: build, run, test

```bash
make build             # Debug build (Apple Development signing, your Mac's architecture only)
make run               # Debug build, then launch it (quits a running copy first)
make test              # app tests + every package's tests (no permission-dependent tests)
ORIEL_TCC_TESTS=1 make test   # also the tests that need Accessibility / Screen Recording
make lint              # swiftlint --strict and swiftformat --lint
make universal-check   # Universal Release build, both slices checked, self-test native and under Rosetta
```

Debug builds land in Xcode's DerivedData; `make run` finds and opens the right one. They are a separate app to macOS: bundle ID `com.codertapsu.oriel.debug`, listed as **Oriel Debug** in System Settings, with their own permissions, settings and keychain items, so granting a Debug build never touches the installed Oriel (docs/os-quirks.md). Only one of the two runs at a time. Without the team's certificates (on another Mac, or in CI), sign ad hoc: `make build XCODEBUILD_FLAGS="CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM="` (also for `test` and `universal-check`); such a build is fine for development, but macOS treats every rebuild as a new app for permissions. `Oriel.app/Contents/MacOS/Oriel --self-test` prints the architecture, the linked packages, the private symbols found and the permission state, then exits.

## 4. A release build, step by step

Run everything from the repository root. The version used below is the one in `project.yml`:

```bash
VERSION=$(sed -n -E 's/^ +MARKETING_VERSION: *"?([^"]*)"?.*$/\1/p' project.yml); echo "$VERSION"
```

### Step 1 — Set the version

Edit `MARKETING_VERSION` in `project.yml` (e.g. `"0.1.0"`), then `make generate`. The build number (`CFBundleVersion`) is the commit count, so it only ever grows:

```bash
BUILD=$(git rev-list --count HEAD)
```

### Step 2 — Quality gate

```bash
make lint test universal-check
```

Don't sign and notarize a build that fails its own tests: notarization cannot be taken back.

### Step 3 — Archive

```bash
rm -rf build/Oriel.xcarchive dist/Oriel.app
xcodebuild archive -project Oriel.xcodeproj -scheme Oriel -configuration Release \
  -destination 'generic/platform=macOS' -archivePath build/Oriel.xcarchive \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO CURRENT_PROJECT_VERSION="$BUILD"
```

The archive contains the Release app with both architectures. The embedded command-line tool (`Contents/Helpers/oriel`) has `SKIP_INSTALL=YES`, so the archive holds exactly one product, the app.

### Step 4 — Export for Developer ID

```bash
xcodebuild -exportArchive -archivePath build/Oriel.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath dist
```

`ExportOptions.plist` says `method = developer-id`, `signingStyle = manual`, `signingCertificate = Developer ID Application` and `teamID`. The export re-signs the app and its embedded CLI with your Developer ID certificate, a secure timestamp and the hardened runtime. It also removes `com.apple.security.get-task-allow`, which plain builds keep so that Instruments can attach and which notarization rejects. The result is `dist/Oriel.app`.

### Step 5 — Check the signature before Apple does

```bash
codesign --verify --deep --strict --verbose=2 dist/Oriel.app      # "valid on disk", "satisfies its Designated Requirement"
codesign -dvv dist/Oriel.app 2>&1 | grep -E 'Authority=Developer ID Application|Timestamp|flags'
codesign -d --entitlements - --xml dist/Oriel.app | plutil -p -   # only device.audio-input and device.camera
codesign -dvv dist/Oriel.app/Contents/Helpers/oriel 2>&1 | grep -E 'Identifier|Timestamp|flags'
lipo -archs dist/Oriel.app/Contents/MacOS/Oriel                   # x86_64 arm64
lipo -archs dist/Oriel.app/Contents/Helpers/oriel                 # x86_64 arm64
plutil -extract CFBundleShortVersionString raw dist/Oriel.app/Contents/Info.plist
```

Everything here must look right before you submit. Look for a `flags=0x10000(runtime)` line, a `Timestamp=` line, the Developer ID authority, no `get-task-allow` and no `app-sandbox` entitlement, and two architectures in both executables.

### Step 6 — Notarize the app

`notarytool` takes a zip, a dmg or a pkg, not a bundle:

```bash
ditto -c -k --keepParent dist/Oriel.app dist/Oriel.zip
xcrun notarytool submit dist/Oriel.zip \
  --apple-id "$APPLE_ID" --password "$APPLE_PASSWORD" --team-id "$APPLE_TEAM_ID" --wait
```

It prints a submission `id`, uploads, waits (usually 1–5 minutes) and ends with `status: Accepted`. If it says `Invalid`, ask why:

```bash
xcrun notarytool log <submission-id> --apple-id "$APPLE_ID" --password "$APPLE_PASSWORD" --team-id "$APPLE_TEAM_ID"
```

### Step 7 — Staple the ticket to the app

```bash
xcrun stapler staple dist/Oriel.app
xcrun stapler validate dist/Oriel.app        # "The validate action worked!"
rm dist/Oriel.zip
```

The stapled ticket travels inside the app, so a copy dragged out of the disk image opens without asking Apple's servers, which matters offline.

### Step 8 — Build the disk image

```bash
rm -rf dist/dmgroot "dist/Oriel-$VERSION.dmg" && mkdir dist/dmgroot
ditto dist/Oriel.app dist/dmgroot/Oriel.app          # ditto keeps the signature and the ticket
ln -s /Applications dist/dmgroot/Applications
hdiutil create -volname Oriel -srcfolder dist/dmgroot -ov -format ULFO "dist/Oriel-$VERSION.dmg"
rm -rf dist/dmgroot
```

`ULFO` is lzfse-compressed and read-only, the format Finder opens fastest.

### Step 9 — Sign the disk image

```bash
codesign --sign "$APPLE_SIGNING_IDENTITY" --timestamp "dist/Oriel-$VERSION.dmg"
codesign --verify --strict "dist/Oriel-$VERSION.dmg"
```

### Step 10 — Notarize and staple the disk image

```bash
xcrun notarytool submit "dist/Oriel-$VERSION.dmg" \
  --apple-id "$APPLE_ID" --password "$APPLE_PASSWORD" --team-id "$APPLE_TEAM_ID" --wait
xcrun stapler staple "dist/Oriel-$VERSION.dmg"
xcrun stapler validate "dist/Oriel-$VERSION.dmg"
```

### Step 11 — Ask Gatekeeper, the way a user's Mac will

```bash
spctl -a -vvv -t open --context context:primary-signature "dist/Oriel-$VERSION.dmg"
spctl -a -vvv -t exec dist/Oriel.app
```

Both must say `accepted` with `source=Notarized Developer ID`. This is the check that catches a Gatekeeper failure on your Mac, not on someone else's.

### Step 12 — Record the checksum

```bash
shasum -a 256 "dist/Oriel-$VERSION.dmg"
```

The Homebrew cask's `sha256` must be this value (Appendix A.5 of the plan).

## 5. Installing on a MacBook

**From the disk image** (the notarized build from step 10):

1. Double-click `Oriel-<version>.dmg` and drag **Oriel** onto **Applications**.
2. Eject the disk image and open Oriel from Applications. It has no Dock icon; look for its window icon in the menu bar. If you open it straight from the disk image, it offers to move itself to Applications. Accept: permissions granted to a copy elsewhere are lost when it moves.
3. The welcome window lists the permissions. **Accessibility** (window switcher, Cmd-Tab, scrolling capture) is the important one; **Screen & System Audio Recording** enables screenshots, recordings and thumbnails; Microphone and Camera are optional. After granting Screen Recording, quit and reopen Oriel.
4. Optional: Settings → Advanced → Command-line tool → Install, to get `oriel` in your Terminal.

On the target Mac, `spctl -a -vv /Applications/Oriel.app` should report `Notarized Developer ID`.

**From source, on your own Mac:**

```bash
make install        # Developer ID export into /Applications, signature verified, then launched
```

It is not notarized, and doesn't need to be, because a build made on the same Mac is never quarantined.

**Through Homebrew** once the private tap exists: `brew tap <org>/oriel …`, then `brew install --cask oriel`, and later `brew upgrade --cask oriel`.

## 6. The one-command versions

```bash
source scripts/apple-credentials.env
make release-dry-run                     # steps 2–12 on the working tree, publishes nothing
SKIP_UPLOAD=1 RELEASE_TAG=v0.1.0 bash scripts/release/release-macos.sh   # the same for a tagged commit
```

The script runs the same commands with checks between them: version against the tag, identity against the team, Apple accepting the credentials, a clean tree, both slices, the signer, `get-task-allow`. It stops at the first failure, before anything is submitted.

## 7. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `'Developer ID Application: …' is not in the login keychain` | The certificate, or its private key, is missing on this Mac. Create it in Xcode → Settings → Accounts, or import the `.p12` you exported from another Mac. |
| `errSecInternalComponent` while signing | The keychain is locked, typically over SSH. Run `security unlock-keychain ~/Library/Keychains/login.keychain-db`. |
| `notarytool` says `Invalid` | Read the log (step 6). Usual causes: a binary without the hardened runtime, `get-task-allow` (you notarized a plain build instead of the export), nested code not signed, or no secure timestamp. |
| `notarytool` rejects the credentials (HTTP 401) | `APPLE_PASSWORD` must be an app-specific password; regenerate it if it was revoked. Check the team ID. |
| `stapler staple` fails with error 65 right after `Accepted` | The ticket has not reached Apple's CDN yet. Wait a minute and retry. |
| "Apple could not verify Oriel is free of malware" on another Mac | The app or the dmg was not stapled, or was modified after signing. Re-run steps 7–11. |
| Oriel is switched on in System Settings, but Settings → Permissions says Accessibility is missing | macOS keeps one entry per bundle ID, signed by the build that asked first; a copy signed differently fails it. Select Oriel in System Settings → Privacy & Security → Device Control and Data Access (Accessibility before macOS 27), remove it with −, add `/Applications/Oriel.app` with +, or run `tccutil reset Accessibility com.codertapsu.oriel` and grant it again. To see the reason, run `/usr/bin/log stream --level debug --predicate 'subsystem == "com.apple.TCC"'` while Oriel starts and look for `Failed to match existing code requirement`. |
| `lipo` shows only `arm64` | You built Debug (`ONLY_ACTIVE_ARCH=YES`) or overrode `ARCHS`. Release builds set both architectures explicitly. |
| `arch -x86_64 … --self-test` fails with "Bad CPU type" | Rosetta is not installed (section 1). |
| The CLI is missing from `Contents/MacOS` | Correct: on a case-insensitive disk (the macOS default) `Contents/MacOS/oriel` would be the app's own executable `Oriel`, so the CLI lives in `Contents/Helpers/oriel`. |
| `open oriel://…` or a `.oriel` file starts an old copy (from `build/`, DerivedData or `dist/`) | Every built copy registers the URL scheme and the document type with LaunchServices. `make install` registers the installed copy for you; by hand, run `lsregister -u <old copy>` for each stray one and `lsregister -f /Applications/Oriel.app` (`lsregister` lives in `/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/`). `lsregister -dump \| grep 'path:.*Oriel.app'` lists the registered copies. |

# Releasing Oriel

Oriel releases are built, signed, notarized and verified on the maintainer's Mac by one script, `scripts/release/release-macos.sh`. It works the same way as the macOS legs of Gitweaver and Mother Claude and reads the same credentials file. Nothing is signed in CI, so CI holds no signing secrets: `.github/workflows/ci.yml` builds and tests every pull request with ad hoc signing (`make … XCODEBUILD_FLAGS="CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM="`).

A release is one notarized, stapled `dist/Oriel-<version>.dmg`. Oriel has no updater (PLAN D3), so there is no update archive and no manifest; the fleet updates through Homebrew (PLAN §15.6). The Mac App Store edition (PLAN §18) is released separately, through Xcode and App Store Connect: see [The App Store edition](#the-app-store-edition).

## One-time setup

1. **A Developer ID Application certificate** for team `4XVYLW8RXS` (the `DEVELOPMENT_TEAM` in `project.yml`) in the login keychain. `security find-identity -v -p codesigning` lists it. The current certificate chains to Apple's original Developer ID CA and expires on 2027-02-01 (PLAN §16).
2. **The credentials file.** `scripts/apple-credentials.env` is the same file the other desktop apps use: copy it from one of them, or start from `scripts/apple-credentials.env.example`. It holds `APPLE_SIGNING_IDENTITY`, `APPLE_ID`, `APPLE_PASSWORD` (an app-specific password, not the Apple ID password) and `APPLE_TEAM_ID`. It is git-ignored. Never commit it, and never paste its values into a chat, an issue or a commit message.
3. **The notary keychain profile.** `xcrun notarytool store-credentials codertapsu-notary --apple-id <Apple ID> --team-id 4XVYLW8RXS` asks for the app-specific password and keeps it in the login keychain. The release scripts sign in to the notary service with it whenever it exists (`scripts/release/notary-auth.sh`; another name through `NOTARY_PROFILE=…`), and fall back to the variables above when it does not. The profile serves every app of the team. `xcrun notarytool history --keychain-profile codertapsu-notary` checks it.
4. **Tooling:** Xcode 27.1 or later, `brew install xcodegen swiftlint swiftformat`, and Rosetta (`softwareupdate --install-rosetta --agree-to-license`) for the x86_64 self-test.

## The version

It lives in one place, `MARKETING_VERSION` in `project.yml`; the app's and the CLI's Info.plist take it from there. The build number (`CFBundleVersion`) is the commit count at archive time, so it only grows and can be rebuilt from the tag.

## Rehearse

```bash
source scripts/apple-credentials.env
make release-dry-run
```

This runs the release script on the working tree as it is (`SKIP_UPLOAD=1 ALLOW_DIRTY=1`, at `project.yml`'s version). It notarizes for real and publishes nothing. Expect 5–15 minutes, most of it spent waiting for Apple's notary service.

## Cut a release

```bash
# 1. Bump MARKETING_VERSION in project.yml, commit, and tag that commit.
git tag v0.2.0
# 2. Build, notarize and verify the tag.
source scripts/apple-credentials.env
SKIP_UPLOAD=1 RELEASE_TAG=v0.2.0 bash scripts/release/release-macos.sh
```

`SKIP_UPLOAD=1` stays required until Oriel has somewhere to publish (see below). After a failure past the build, `SKIP_BUILD=1` reuses `dist/Oriel.app`.

## What the script checks, in order

| Step | It stops when |
|---|---|
| Preflight | `project.yml`'s version is not the tag's; the identity is missing from the keychain, is not a Developer ID Application identity, or belongs to another team; Apple rejects the credentials; the tree is dirty or HEAD is not the tag (unless `ALLOW_DIRTY=1`); there is nowhere to publish (unless `SKIP_UPLOAD=1`) |
| Quality gate | `make lint test universal-check appstore-check` fails: both editions' tests, both slices, and the App Store edition's checks (`scripts/verify-appstore.sh`) |
| Archive and export | `scripts/release/export-app.sh` cannot produce the Universal, Developer ID-signed `dist/Oriel.app` |
| The app | `Contents/MacOS/Oriel` or `Contents/Helpers/oriel` lacks a slice, the signer is not `APPLE_SIGNING_IDENTITY`, or `get-task-allow` survived the export |
| Notarize the app | `scripts/release/notarize.sh` zips and submits it; the result is not Accepted (Apple's log is printed), or the stapled ticket does not validate |
| The dmg | `scripts/release/make-dmg.sh` builds it from the stapled app and signs it; it is then notarized and stapled the same way |
| Verify | `spctl -t open` rejects the dmg, or `spctl -t exec` rejects the app |

The app is stapled before it goes into the dmg, so the copy a user drags to /Applications opens without asking Apple's servers.

## Where releases go: not decided yet

Gitweaver and Mother Claude upload to a draft GitHub release in a release repository, and a person publishes it. PLAN §15 instead puts the dmg on an internal file host behind a private Homebrew tap, because Oriel is internal and Homebrew cannot download from a private GitHub release without a token. Until one of the two is chosen, the script stops after verifying and prints the dmg's SHA-256 for the cask.

## The App Store edition

The App Store edition (PLAN §18, §19) is signed by Apple, not with Developer ID, so the release script does not build it; its gate does run `make appstore-check`. Setting up App Store Connect once (the agreements, the app record, Oriel Pro, the listing) is in `docs/APP_STORE.md`. Then, for each version:

1. Cut the release as above, so the tag, the version and the build number (the commit count) are the Developer ID release's.
2. `make appstore-archive`, or in Xcode: scheme **Oriel App Store**, **Product → Archive**. Xcode signs the archive for team `4XVYLW8RXS` with automatic signing; the first time, it registers the App ID's iCloud capability and makes the App Store provisioning profiles, which needs the team's account in Xcode → Settings → Accounts and this Mac registered as one of the team's devices (`docs/APP_STORE.md` step 2).
3. Xcode → **Window → Organizer** → the archive → **Distribute App** → **App Store Connect** → **Upload**. Xcode validates it first; fix what it reports and archive again.
4. In App Store Connect, the build appears under **TestFlight** after processing (minutes to an hour). Test it there, Oriel Pro included: TestFlight purchases are free and use the sandbox.
5. Add the build to the version, with Oriel Pro, and **Submit for Review**. The first submission must include the in-app purchase.

## Renewing certificates and passwords

Each of these serves every app of the team (Oriel, Gitweaver, Mother Claude); renew it once and update each project's credentials file.

| What | When | How |
|---|---|---|
| Developer ID Application certificate | Before it expires; the current one, chained to Apple's original Developer ID CA, expires on 2027-02-01 | Keychain Access → **Certificate Assistant → Request a Certificate from a Certificate Authority** (saved to disk); developer.apple.com → Certificates → **+** → Developer ID Application, upload the request, download and open the certificate. Check that `security find-identity -v -p codesigning` lists it, set `APPLE_SIGNING_IDENTITY` in each credentials file if its name changed, run `make release-dry-run`, then delete the old certificate and its private key from the login keychain so builds cannot pick it. Export the new one with its key (a `.p12`) to keep a backup and to set up another Mac. |
| App-specific password | When it is revoked, or the Apple ID password changes | appleid.apple.com → **Sign-In and Security → App-Specific Passwords**; update `APPLE_PASSWORD` in each credentials file and run the `store-credentials` command above again. |
| Apple Development and Apple Distribution certificates | Xcode renews them | Automatic signing makes them as needed; a Mac that builds Debug or archives the App Store edition needs the team's account in Xcode. |

## Installing on this Mac

`make install` exports a Developer ID build and installs it in /Applications, quitting a running copy first. It is not notarized and does not need to be, because a build made on this Mac carries no quarantine attribute. `INSTALL_DIR=…` installs somewhere else; `NO_OPEN=1` leaves a running copy alone and does not launch the new one.

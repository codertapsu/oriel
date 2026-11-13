# The Apple Developer account: credentials and renewals

What Oriel's builds depend on in the Apple Developer account, when each piece expires, and how to renew it, step by step. Gitweaver and Mother Claude use the same team and credentials file, so renewing something once covers them too; [Other projects](#other-projects) lists what each needs updated.

- Registering the App Store edition: [APP_STORE_CONNECT.md](APP_STORE_CONNECT.md).
- Using these credentials in a release: [RELEASING.md](RELEASING.md).

## Inventory

Read on this Mac on 2026-11-02, and the membership in the browser on 2026-11-13. Re-read it with [the commands below](#checking-what-you-have).

| Credential | Used for | Valid until | Renew | Lives in |
|---|---|---|---|---|
| Apple Developer Program membership, team `4XVYLW8RXS` (Khanh Hoang, individual) | Everything below, and the App Store | **2027-01-25**, the renewal date in developer.apple.com/account → Membership details; not readable from this Mac. App Store Connect's agreements end the day before | Yearly, by the Account Holder ([below](#renewing-the-membership)) | Your Apple Account |
| **Developer ID Application**: Khanh Hoang (4XVYLW8RXS), from the *previous* Developer ID authority | Signing the Developer ID edition, which notarization requires | **2027-02-01**, the day that authority expires; it cannot sign after | Replace with a G2 certificate before then, then yearly ([below](#replacing-the-developer-id-application-certificate)) | Login keychain, with its private key |
| Apple Development: Khanh Hoang (2HY96CNG4K) | Debug builds; App Store archives | 2027-06-01 | Xcode ([below](#apple-development-and-apple-distribution)) | Login keychain |
| Apple Distribution: Khanh Hoang (4XVYLW8RXS) | Signing App Store uploads | 2027-06-03 | Xcode | Login keychain |
| Mac Installer Distribution: 3rd Party Mac Developer Installer: Khanh Hoang (4XVYLW8RXS) | Signing the package Xcode uploads to App Store Connect | 2027-11-03 | Xcode, which made it at the first upload (2026-11-03) | Login keychain |
| App-specific password for notarization | `notarytool`, as `APPLE_PASSWORD` | No expiry; revoked when the Apple Account password changes, or by hand | [below](#the-app-specific-password-and-the-notary-profile) | `scripts/apple-credentials.env` and the profile below |
| Keychain profile `codertapsu-notary` | Notarization in the release scripts | As long as its password | Store it again with a new password | Login keychain |
| Provisioning profiles for the App Store edition | Archive and upload | One year; Xcode replaces them | Xcode, automatically | `~/Library/Developer/Xcode/UserData/Provisioning Profiles` |
| Registered devices | Development profiles, which App Store archives need | Until removed; slots free up only at renewal | — | Certificates, Identifiers & Profiles → Devices |

The Developer ID edition needs no provisioning profile; only the App Store edition does.

## Checking what you have

The signing identities, with their names:

```bash
security find-identity -v -p codesigning
```

Each certificate's dates and issuing authority, including several with the same name:

```bash
for name in "Developer ID Application" "Apple Development" "Apple Distribution"; do
  security find-certificate -a -c "$name" -p | awk '/BEGIN CERT/{n++} {print > ("/tmp/cert-" n ".pem")}'
  for f in /tmp/cert-*.pem; do openssl x509 -in "$f" -noout -subject -issuer -enddate; echo; done
  rm -f /tmp/cert-*.pem
done
```

In the issuer, a Developer ID certificate with `OU=Apple Certification Authority` comes from the previous authority, which expires on 2027-02-01. One with `OU=G2` comes from the current one.

The notary profile:

```bash
xcrun notarytool history --keychain-profile codertapsu-notary > /dev/null && echo ok
```

The membership date is only in the browser: <https://developer.apple.com/account> → Membership details → **Renewal date**. On 2026-11-13 it was January 25, 2027, as was the **Device reset date**. App Store Connect → Business showed the Paid Apps and Free Apps agreements active until 24 January 2027, the day before. After renewing, check there that they run to the new date, and accept any new terms.

## Renewing the membership

Apple's rules (<https://developer.apple.com/support/renewal/>):

- **Who:** for an individual membership, the person who enrolled, signed in with the Apple Account used to enroll. For an organization, only the Account Holder.
- **When:** "you can renew manually starting 30 days before the expiration date of your existing membership or any time after it expires." Renewing early changes nothing: the new year starts when the current one ends.
- **Auto-renew:** set in Membership details, but only in some regions (Apple lists the United States, United Kingdom, Canada, Germany and Australia among them). Where it is offered, the card on file is charged on the expiry date.
  - If the membership was bought in the Apple Developer app, it renews as an App Store subscription: manage it in your Apple Account's subscriptions.

**Steps:**

1. In the 30 days before the expiry date, sign in at <https://developer.apple.com/account>.
2. Open **Membership details** and click **Renew Membership**. Where auto-renew is offered, turn it on there instead.
3. Pay the yearly fee. The confirmation email and Membership details show the new expiry date; put it in your calendar for next year.

**If it lapses** (Apple's words):

- "your apps will no longer be available for download and you won't be able to submit new apps or updates or access Certificates, Identifiers & Profiles."
- "your apps will still function for users who have already installed or downloaded them."
- Developer ID: "If your membership expires, users can still download, install, and run your applications that are signed with Developer ID. However, once your Developer ID certificate expires, you must be an Apple Developer Program member to get new Developer ID certificates." Notarizing new builds also stops.
- Renewing after expiry brings free apps back "within 24 hours". Paid apps come back after you accept the Paid Applications agreement again in App Store Connect. Nothing needs resubmitting.
- Registered devices are removed 180 days after expiry.

## Replacing the Developer ID Application certificate

**Why it is urgent:** the Developer ID certificate on this Mac comes from Apple's *previous* Developer ID Certification Authority.
- Apple: "The original Developer ID Certification Authority expires on February 1, 2027. After that date, certificates issued from the original authority can no longer be used for signing."
- Its replacement comes from the current authority, G2, and "Certificates issued from G2 are valid for one year and must be renewed annually." From now on this is a yearly task.

**What it does not affect:** releases already shipped keep working. Apple: "As long as your Developer ID certificate was valid when you compiled your app, then users can download and run your app, even after the expiration date of the certificate. However, you'll need a new certificate to sign updates and new applications." Oriel's releases are signed with a secure timestamp and notarized.

**Who:** only the Account Holder can create Developer ID certificates. A team can hold up to five Developer ID Application certificates at once, so the new one can be made and tested while the old one still works.

### Creating it: with Xcode (simplest)

1. Xcode → **Settings** → **Accounts** → your Apple Account → team **Khanh Hoang** → **Manage Certificates…**.
2. Click **+** at the bottom left → **Developer ID Application**.
3. Xcode makes the private key in your login keychain, asks Apple for the certificate (from G2) and installs it. Click **Done**.

### Creating it: in the browser

1. **Make a certificate signing request:**
   1. Keychain Access → **Keychain Access** menu → **Certificate Assistant** → **Request a Certificate From a Certificate Authority…**.
   2. Fill in the form:
      - **User Email Address:** your Apple Account email.
      - **Common Name:** `Khanh Hoang`.
      - **CA Email Address:** empty.
      - **Request is:** **Saved to disk**.
   3. Click **Continue** and save `CertificateSigningRequest.certSigningRequest`. The private key stays in your login keychain.
2. Open <https://developer.apple.com/account/resources/certificates/add>.
3. Under **Software**, choose **Developer ID Application** → **Continue**.
4. When asked for the Developer ID Certificate Intermediary, choose **G2 Sub-CA (Xcode 11.4.1 or later)**. Apple warns that any other option may issue a certificate from the expiring authority.
5. Upload the signing request → **Continue** → **Download**.
6. Double-click the downloaded `developerID_application.cer`; Keychain Access installs it next to its private key.

### Afterwards: one identity, the release rehearsed, a backup kept

1. **Check:** `security find-identity -v -p codesigning` now lists **two** `Developer ID Application: Khanh Hoang (4XVYLW8RXS)`. With two identities of the same name, signing by that name is ambiguous. The release scripts use the name from `APPLE_SIGNING_IDENTITY`, and Xcode's export uses it too.
2. **Back up the old certificate:**
   1. Keychain Access → **login** → **My Certificates**.
   2. Find the old certificate: the one whose expiry is 2027-02-01 and whose issuer reads `Apple Certification Authority`.
   3. Right-click → **Export…** → `.p12` with a strong password.
   4. Store it outside the repository, in a password manager or an encrypted volume. `*.p12` is git-ignored, but keep it out of the tree anyway.
3. **Delete the old certificate,** and its private key, from the login keychain. `security find-identity -v -p codesigning` should then list one Developer ID Application identity: the new one, issuer `OU=G2`.
4. **Back up the new one** the same way (step 2). That `.p12` is also how a second Mac gets the identity.
5. **Rehearse a release:** `source scripts/apple-credentials.env && make release-dry-run`. It signs, notarizes and verifies, and publishes nothing.
6. **Check what was signed:** `codesign -dv --verbose=4 dist/Oriel.app 2>&1 | grep Authority`. The first Authority line is the new certificate, and the second `Developer ID Certification Authority`.
7. `APPLE_SIGNING_IDENTITY` in the credentials file keeps working if the name is unchanged; it is the same for a certificate of the same team. Change it only if the name differs.
8. **Put the new expiry date,** one year out, in your calendar a month ahead.

## Apple Development and Apple Distribution

They are valid for one year: Apple Development until 2027-06-01 and Apple Distribution until 2027-06-03. Xcode looks after them.
- **Renew:** in the month before expiry, Xcode → Settings → Accounts → the team → **Manage Certificates…** → **+** → **Apple Development** or **Apple Distribution**. Automatic signing also makes a new one when it needs one, as `make appstore-archive` does with `-allowProvisioningUpdates`.
- **Clean up:** delete the expired one from the login keychain afterwards. Several of the same type with different names do not conflict; Xcode chooses.
- **Revoking:** only revoke a certificate (developer.apple.com → Certificates) whose private key may have leaked.

**Mac Installer Distribution**, which signs the package uploaded to App Store Connect, is made by Xcode at the first upload. When the account allows, it is managed by Apple, so there is nothing to renew by hand.

## The app-specific password and the notary profile

Notarization signs in with the keychain profile `codertapsu-notary`, which holds your Apple Account, the team and an app-specific password. The release scripts fall back to `APPLE_ID`, `APPLE_PASSWORD` and `APPLE_TEAM_ID` in `scripts/apple-credentials.env`. Apple revokes **every** app-specific password when the Apple Account password changes.

**Renewing:**

1. <https://account.apple.com> → **Sign-In and Security** → **App-Specific Passwords** → **+**, label `notarytool`. Copy the password; it is shown once.
2. Put it in `APPLE_PASSWORD` in each project's `scripts/apple-credentials.env`. Never commit the file or paste its values anywhere (CLAUDE.md rule 13).
3. Store the profile again:

   ```bash
   bash -c 'source scripts/apple-credentials.env && xcrun notarytool store-credentials codertapsu-notary \
     --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_PASSWORD"'
   ```

   `notarytool` checks the credentials with Apple and saves them; it prints no secret.
4. Check: `xcrun notarytool history --keychain-profile codertapsu-notary > /dev/null && echo ok`.
5. Revoke the old password on the same page if it still exists.

## Devices and provisioning profiles

- **Devices:** App Store archives are signed for development first, and a development profile needs at least one registered device.
  - The development MacBook Pro M4 Pro (Provisioning UDID `00006040-000211A13AEA801C`) is the one to register (APP_STORE_CONNECT.md step 3.2).
  - Another Mac: `system_profiler SPHardwareDataType | grep "Provisioning UDID"`, then Certificates, Identifiers & Profiles → **Devices** → **+**.
  - Slots: 100 Macs per membership year; removing a device frees its slot only at renewal.
- **Profiles:** Xcode makes them as needed with automatic signing: the Mac Team Provisioning Profile for archives, and the Mac App Store profile at upload. When one expires or the certificates change, the next archive or upload with `-allowProvisioningUpdates` replaces it. Nothing needs downloading by hand.

## The credentials file

`scripts/apple-credentials.env` is git-ignored and shared with the other desktop apps; start from `scripts/apple-credentials.env.example`.

| Variable | What | Changes when |
|---|---|---|
| `APPLE_SIGNING_IDENTITY` | The Developer ID Application identity's name | Its name changes; usually never |
| `APPLE_ID` | Your Apple Account email | Never |
| `APPLE_PASSWORD` | The app-specific password | You make a new one |
| `APPLE_TEAM_ID` | `4XVYLW8RXS` | Never |

The scripts read it only after `source scripts/apple-credentials.env`, in the shell that runs them. Nothing prints it.

## Other projects

| Project | Uses | After a renewal |
|---|---|---|
| Oriel | Developer ID Application, the notary profile or the password, Apple Development and Distribution | As above |
| Gitweaver, Mother Claude | Developer ID Application and the same credentials file | Update `APPLE_PASSWORD` in their copy if it changed. Their builds pick the new certificate once the old one is gone, then rehearse their release the same way |
| InkMirror (iOS), whose profiles are on this Mac | Apple Development and Distribution, if it is signed by this team | Xcode renews them; nothing for Developer ID |

## The yearly calendar

| When | What | Who |
|---|---|---|
| From 2026-12-26, 30 days before 2027-01-25, then yearly | Renew the membership; then check the agreements in App Store Connect → Business | Account Holder |
| **Before 2027-02-01** | Replace the Developer ID Application certificate with a G2 one, delete the old, rehearse a release | Account Holder |
| A month before each G2 certificate's expiry, yearly | Renew the Developer ID Application certificate | Account Holder |
| Before 2027-06-01 and 2027-06-03, then yearly | Apple Development and Apple Distribution, through Xcode | Anyone on the team |
| Before 2027-11-03, then yearly | Mac Installer Distribution, through Xcode | Anyone on the team |
| Whenever the Apple Account password changes | A new app-specific password; store the notary profile again | You |

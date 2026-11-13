# 09 — App Review's first review of the App Store edition (release 1.0.0)

2026-11-13 · macOS 27.2 (26B123) · Xcode 27.1 · App Review rejected the App Store edition, 1.0.0 build 134, on 2026-11-12: submission `20f64cbb-45d2-4c25-a567-a4a96cdc4000`, reviewed on a 14-inch MacBook Pro. This report covers what Apple said, read in App Store Connect with Apple's two screenshots; what changed in build 141; the reply; and the resubmission of build 141 the same day. Plan 2.13 records it.

## What App Review said

| # | Guideline | Apple's words | Apple's screenshot |
|---|---|---|---|
| 1 | 5.1.1(iv) Privacy | "A custom message appears before the permission request, and to proceed users press a "Grant" button. Use words like "Continue" or "Next" on the button instead." | The welcome window: Screen & System Audio Recording marked *required*, and **Grant…** beside it and beside Microphone and Camera |
| 2 | 2.4.5(i) Performance | "The app saves user data to the app's container, which is not user accessible … It would be appropriate to save user files to a location selected by or available to users, using standard Save dialogs." | Settings → Recording: "Save recordings to /Users/johnapple/Library/Containers/com.cod…/Library/Application Support/Oriel/Recordings/" |
| 3 | 2.4.5(i) Performance | "describe how and where the app uses the following entitlements … com.apple.security.assets.pictures.read-write". "You will not need to upload a new binary to provide this information." | — |

Oriel Pro stayed **Ready for Review**: it waits for the version.

## What changed

**1. The welcome window and Settings → Permissions** (both editions):
- The button that leads to macOS's request says **Continue**, and **Open System Settings…** for a permission the user turned down.
- No permission is marked *required*; a permission not yet allowed shows a plain circle, not an orange warning.
- The welcome window says what each permission is for, and that the tools without one still work. It no longer opens Privacy & Security for you, and **Done** closes it whatever was allowed.
- Only Settings says where a permission can be changed, and as information: "You can change this in System Settings → …".
- The in-context notices stay as they are. Capture, Translate Under Cursor and Screen Ruler show them after you try a tool that lacks a permission, and they offer System Settings, which is what Apple's message recommends.

**2. Recordings** (App Store edition):
- They are saved to **Movies/Oriel**, through the new `com.apple.security.assets.movies.read-write` entitlement, and Settings → Recording shows "Movies/Oriel".
- **Choose…** keeps the chosen folder as a security-scoped bookmark. Before, it kept a bare path, which the sandbox would not open after a relaunch.
- In the sandbox, the Movies and Pictures folders FileManager names are links inside the container, so a path through them looks like the container. The defaults now resolve them to `~/Movies/Oriel` and `~/Pictures/Oriel`.
- The Developer ID edition keeps its recordings folder.

**3. Captures and history** (App Store edition):
- Captures still go to Pictures/Oriel, now at its real path.
- The capture history, which lives in the container, no longer offers **Show in Finder**; **Save to Folder** puts a capture in the user's folder.

## Tests

- `PermissionListTests`: the button before a request says Continue, and Open System Settings… for a refused permission.
- `PermissionKindTests`: every Settings hint starts "You can change this in System Settings → Privacy & Security → …", and none says "grant".
- `RecordingOptionsTests`: the App Store edition records into Movies/Oriel, and a bare path is not used in the sandbox.
- `AppStoreEditionTests.itSavesTheUsersFilesOutsideItsContainer`, inside the sandbox:
  - both the Pictures and Movies entitlements are there;
  - the recordings folder resolves to `…/Movies/Oriel`, outside the container.
- The gate: `make lint test universal-check appstore-check` passed with 1,887 tests (four of them new) and no failures. There were no compiler warnings outside tests, both Release builds passed, and the App Store edition passed its checks.

## The reply to App Review

Posted under the rejection in App Store Connect on 2026-11-13 at 19:28, after choosing build 141:

> Hello,
>
> Thank you for the review. Build 141 fixes both issues, and here is where the Pictures and Movies entitlements are used.
>
> Guideline 5.1.1(iv): the welcome window has no Grant button anymore. It describes what each permission is for, the button that leads to the macOS permission request says "Continue", no permission is marked as required, and "Done" closes the window whatever the user allowed. Settings → Permissions uses the same wording.
>
> Guideline 2.4.5(i), user files in the container: screen recordings are now saved to ~/Movies/Oriel (Settings → Recording → "Save recordings to" shows Movies/Oriel). "Choose…" lets the user pick another folder with the standard Open panel, and Oriel keeps access to it with a security-scoped bookmark. Screenshots are saved to ~/Pictures/Oriel, or to the folder the user chooses in Settings → Capture. The capture history, which Oriel keeps in its container as its own data, no longer offers "Show in Finder"; "Save to Folder" saves a capture to the user's folder.
>
> Guideline 2.4.5(i), entitlements:
> • com.apple.security.assets.pictures.read-write: screenshots are saved to ~/Pictures/Oriel. To see it, choose Capture Area from Oriel's menu-bar menu (or press Control-Shift-4), drag over an area and press Command-S, or click Save in the thumbnail that appears in the corner. The PNG is in ~/Pictures/Oriel, and Settings → Capture → Files → "Save to" shows Pictures/Oriel.
> • com.apple.security.assets.movies.read-write, added in build 141: screen recordings are saved to ~/Movies/Oriel. To see it, choose Record Area from the menu-bar menu (or press Control-Shift-R), drag over an area, record a few seconds and press Control-Shift-R again. The movie is in ~/Movies/Oriel.
>
> Best regards,
> Khanh Hoang

## The resubmission

On 2026-11-13, following `docs/APP_STORE_CONNECT.md` → "When App Review rejects or asks", which now describes each screen as it appeared:

1. **Archive and upload.**
   - `make appstore-archive` from the release commit, which `v1.0.0` names, with a clean tree. Then `xcodebuild -exportArchive` with a temporary export-options file (destination upload) signed it for the App Store and uploaded it: "Upload succeeded" at 19:24.
   - That command and its options are now `make appstore-upload` and `ExportOptions-AppStore.plist`.
   - The archive is kept, with its symbols, in `~/Library/Developer/Xcode/Archives/2026-11-13/`.
2. **TestFlight:** 1.0.0 (141) went from Processing to **Ready to Submit** within two minutes.
3. **The version page:**
   - Under **Build**, 1.0.0 (134) was deleted and 1.0.0 (141) added.
   - The review notes gained the entitlements paragraph that `docs/APP_STORE_CONNECT.md` step 10 now has: where Oriel uses `com.apple.security.assets.pictures.read-write` and `com.apple.security.assets.movies.read-write`, and how to see it.
   - **App Sandbox Information** stays empty: it lists only temporary-exception and special entitlements, and Oriel has none.
   - **Save** turned the version to **Prepare for Submission**.
4. **The reply** above, posted at 19:28 with **Reply to App Review**.
5. **Update Review**, then **Resubmit to App Review**. The submission, the version 1.0 with 1.0.0 (141) and Oriel Pro were **Waiting for Review** at 19:29.
6. **The Developer ID edition:**
   - It was rebuilt as 1.0.0 (141) by the release script, then notarized and stapled.
   - `v1.0.0` moved from build 134 to build 141; its message has the disk image's checksum and the notarization IDs.
   - It gets the new welcome window.

## What remains

1. **App Review's decision.** It comes by email and in App Store Connect, usually within a few days.
2. **If approved:** release is manual, so the version waits in **Pending Developer Release**. Click **Release This Version** to put it on sale (`docs/APP_STORE_CONNECT.md` step 14).
3. **If rejected or asked again:** follow `docs/APP_STORE_CONNECT.md` → "When App Review rejects or asks", and record the round here or in a new report.

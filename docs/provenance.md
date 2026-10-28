# Private-API provenance

Every private symbol Oriel uses goes through `Packages/PrivateAPIs`, is resolved with `dlsym` and is optional. Each one gets a row here before it is first used, saying where its signature came from and which macOS builds it was verified on. Acceptable sources are an `nm`/`dyld_info` dump of the framework, Apple documentation, or the behaviour of a named open-source project that was studied but not copied (PLAN §0.3, D5).

| Symbol | Image | Signature | Source | Verified on (macOS build) | Notes |
|---|---|---|---|---|---|
| `_AXUIElementGetWindow` | HIServices | `AXError (AXUIElementRef, CGWindowID *)` | Signature as widely published in reverse-engineered headers; how lwouis/alt-tab-macos and koekeishiya/yabai use it was studied, not copied | 27.0.1 (26A434): resolves | AX window element → `CGWindowID` |
| `_AXUIElementCreateWithRemoteToken` | HIServices | `AXUIElementRef (CFDataRef token)`, returns +1 | AltTab's handling of windows on other Spaces studied: a 20-byte token of pid, 4 zero bytes, `'coco'` and the element id, little-endian | 27.0.1: resolves | Unit-tested token layout |
| `SLSMainConnectionID` | SkyLight | `int (void)` | yabai and AltTab behaviour | 27.0.1: resolves | |
| `SLSGetActiveSpace` | SkyLight | `uint64_t (int connection)` | yabai and AltTab behaviour | 27.0.1: returns a non-zero id | |
| `SLSCopyManagedDisplaySpaces` | SkyLight | `CFArrayRef (int connection)`, returns +1 | yabai and AltTab behaviour; keys `Display Identifier`, `Current Space`, `Spaces`, `id64`, `type` (4 = full screen) | 27.0.1: resolves | Parser ignores unknown shapes |
| `SLSCopySpacesForWindows` | SkyLight | `CFArrayRef (int connection, int mask, CFArrayRef windowIDs)`, returns +1; mask 0x7 = all | AltTab behaviour | 27.0.1: resolves | |
| `_SLPSSetFrontProcessWithOptions` | SkyLight | `CGError (ProcessSerialNumber *, CGWindowID, uint32_t mode)`; mode 0x200 = user generated | yabai's window focusing studied | 27.0.1: resolves | Exercised once Accessibility is granted (S2) |
| `SLPSPostEventRecordTo` | SkyLight | `CGError (ProcessSerialNumber *, uint8_t record[0xF8])`; bytes 0x04 = 0xF8, 0x3A = 0x10, window id at 0x3C, 0xFF over 0x20–0x2F, 0x08 = 1 then 2 | yabai's "make key window" record studied | 27.0.1: resolves | |
| `GetProcessForPID` | HIServices (deprecated public Process Manager API) | `OSStatus (pid_t, ProcessSerialNumber *)` | Apple's own (deprecated) header | 27.0.1: resolves | Resolved by name so its deprecation can never break the build |
| `CGSGetSymbolicHotKeyValue` | SkyLight | `CGError (int hotKey, unichar *equivalent, unichar *keyCode, CGSModifierFlags *modifiers)`; read into zeroed 64-bit buffers | Signature as published in reverse-engineered CGS headers | 27.0.1: id 1 = ⌘⇥ (key 48, 0x100000), id 2 = ⌘⇧⇥ (0x120000), found by enumeration | Appendix F item 4 |
| `CGSSetSymbolicHotKeyEnabled` | SkyLight | `CGError (int hotKey, bool enabled)` | As above | 27.0.1: resolves | Restored on quit, crash and launch (S4) |
| `CGSIsSymbolicHotKeyEnabled` | SkyLight | `bool (int hotKey)` | As above | 27.0.1: ids 1 and 2 report enabled | |

Outside the app, one test helper resolves two of these symbols the same way, with `dlsym` and the signatures above: `scripts/support/symbolic-hotkey.swift` reads `CGSIsSymbolicHotKeyEnabled` and, as a safety net, calls `CGSSetSymbolicHotKeyEnabled(id, true)` for `scripts/verify-cmdtab-restore.sh`. It links no private framework.

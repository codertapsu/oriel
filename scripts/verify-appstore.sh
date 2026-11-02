#!/usr/bin/env bash
# verify-appstore.sh — checks a built App Store edition (PLAN §19) for what App Review rejects or the sandbox forbids:
# both slices, no private API names (Guidelines 2.5.1), no root helper daemon and no embedded CLI (2.4.5), the sandbox in
# its entitlements, and the export-compliance answer in its Info.plist.
#
#   bash scripts/verify-appstore.sh build/Release-AppStore/Oriel.app
set -euo pipefail

APP="${1:?usage: verify-appstore.sh <path to Oriel.app>}"
EXE="$APP/Contents/MacOS/Oriel"
fail() { echo "error: $*" >&2; exit 1; }

[ -x "$EXE" ] || fail "$EXE is missing"
archs="$(lipo -archs "$EXE")"
case "$archs" in *arm64*x86_64*|*x86_64*arm64*) ;; *) fail "not universal: $archs" ;; esac
echo "    ✓ both slices: $archs"

for symbol in SLSMainConnectionID SLSCopyManagedDisplaySpaces SLSCopySpacesForWindows SLSGetActiveSpace \
  CGSSetSymbolicHotKeyEnabled CGSGetSymbolicHotKeyValue CGSIsSymbolicHotKeyEnabled \
  _AXUIElementGetWindow _AXUIElementCreateWithRemoteToken; do
  if LC_ALL=C grep -a -q "$symbol" "$EXE"; then fail "the executable names the private symbol $symbol"; fi
done
echo "    ✓ no private symbol"

# Disk Space Analyzer's Read as Administrator is compiled in but unreachable: every entry point checks Sandbox.isActive
# (DiskAnalyzerModel.canReadAsAdministrator, tested in the edition), so no daemon ships and nothing asks for a password.
[ ! -e "$APP/Contents/Library/LaunchDaemons" ] || fail "it embeds a launchd daemon"
[ ! -e "$APP/Contents/Helpers/oriel" ] || fail "it embeds the oriel CLI"
echo "    ✓ no root helper, no CLI"

entitlements="App/AppStore/OrielAppStore.entitlements"
[ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "$entitlements")" = "true" ] \
  || fail "$entitlements does not turn the sandbox on"
echo "    ✓ sandboxed ($entitlements)"

[ "$(/usr/libexec/PlistBuddy -c 'Print :ITSAppUsesNonExemptEncryption' "$APP/Contents/Info.plist")" = "false" ] \
  || fail "ITSAppUsesNonExemptEncryption is not false"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" = "com.codertapsu.oriel" ] \
  || fail "the bundle ID is not com.codertapsu.oriel"
echo "    ✓ Info.plist: com.codertapsu.oriel, export compliance answered"

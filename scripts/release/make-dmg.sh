#!/usr/bin/env bash
#
# make-dmg.sh — wrap an exported, stapled Oriel.app in a signed dmg: the app plus an /Applications
# symlink, compressed with lzfse (PLAN §15.5).
#
# Usage:
#   bash scripts/release/make-dmg.sh dist/Oriel.app dist/Oriel-0.1.0.dmg
#
# Required env: APPLE_SIGNING_IDENTITY.
set -euo pipefail

APP="${1:?usage: make-dmg.sh <Oriel.app> <output.dmg>}"
DMG="${2:?usage: make-dmg.sh <Oriel.app> <output.dmg>}"
: "${APPLE_SIGNING_IDENTITY:?set APPLE_SIGNING_IDENTITY — run: source scripts/apple-credentials.env}"

ROOT="$(dirname "$DMG")/dmgroot"
rm -rf "$ROOT" "$DMG"
mkdir -p "$ROOT"
# ditto, not cp: it keeps the signature, the stapled ticket and the extended attributes intact.
ditto "$APP" "$ROOT/$(basename "$APP")"
ln -s /Applications "$ROOT/Applications"

echo "==> hdiutil create $DMG"
hdiutil create -quiet -volname Oriel -srcfolder "$ROOT" -ov -format ULFO "$DMG"
rm -rf "$ROOT"

echo "==> sign the dmg"
codesign --sign "$APPLE_SIGNING_IDENTITY" --timestamp "$DMG"
codesign --verify --strict "$DMG"

#!/usr/bin/env bash
#
# export-app.sh — archive the Universal Release build and export it, signed for Developer ID
# distribution, to dist/Oriel.app. Shared by release-macos.sh and scripts/install.sh.
#
# The export, not a plain `xcodebuild build`, is what can be notarized. Release builds keep
# com.apple.security.get-task-allow so Instruments can attach (PLAN §15.3), and notarization rejects
# it; the export re-signs the app and its embedded CLI without it, with a secure timestamp.
#
# Usage:
#   bash scripts/release/export-app.sh
#
#   BUILD_NUMBER=...   CFBundleVersion. Defaults to the commit count, which only grows and can be
#                      reproduced from the tag.
#   EXPORT_DIR=...     where Oriel.app goes. Defaults to dist; make install uses build/install, so
#                      installing never replaces a notarized release.
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD)}"
EXPORT_DIR="${EXPORT_DIR:-dist}"
ARCHIVE="build/Oriel.xcarchive"
APP="$EXPORT_DIR/Oriel.app"

# Delete the previous products first. A failed archive leaves the last good app in dist/, and
# packaging that ships a stale binary under a version number it does not contain.
rm -rf "$ARCHIVE" "$APP"

echo "==> xcodegen generate"
xcodegen generate --quiet

echo "==> archive (Release, arm64 + x86_64, build $BUILD_NUMBER)"
xcodebuild archive -quiet -project Oriel.xcodeproj -scheme Oriel -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$ARCHIVE" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

echo "==> export for Developer ID (ExportOptions.plist)"
xcodebuild -exportArchive -quiet -archivePath "$ARCHIVE" -exportOptionsPlist ExportOptions.plist -exportPath "$EXPORT_DIR"

[ -d "$APP" ] || {
  echo "error: the export did not produce $APP." >&2
  exit 1
}
echo "==> exported: $APP $(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")" \
  "(build $(plutil -extract CFBundleVersion raw "$APP/Contents/Info.plist"))"

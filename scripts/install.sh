#!/usr/bin/env bash
#
# install.sh — `make install`: export a Developer ID build and install it on this Mac.
#
# It is not notarized and does not need to be: a build made on this Mac carries no quarantine
# attribute, so Gatekeeper never assesses it (PLAN §15.6). Anything for another Mac goes through
# scripts/release/release-macos.sh.
#
# Usage:
#   bash scripts/install.sh
#
#   INSTALL_DIR=...   install somewhere other than /Applications
#   NO_OPEN=1         leave a running copy alone and do not launch the new one
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

INSTALL_DIR="${INSTALL_DIR:-/Applications}"
EXPORT_DIR="build/install"   # not dist/, which holds the notarized release

EXPORT_DIR="$EXPORT_DIR" bash scripts/release/export-app.sh

if [ "${NO_OPEN:-}" != "1" ]; then
  # `open` on an app that is already running activates the old process instead of the new build.
  pkill -x Oriel 2>/dev/null || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -x Oriel >/dev/null || break
    sleep 0.2
  done
fi

echo "==> install to $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
rm -rf "${INSTALL_DIR:?}/Oriel.app"
ditto "$EXPORT_DIR/Oriel.app" "$INSTALL_DIR/Oriel.app"
codesign --verify --deep --strict --verbose=2 "$INSTALL_DIR/Oriel.app"

# Every built copy (Debug, Release, this export) registers the oriel:// scheme and the .oriel document type.
# Drop the export and register the installed copy, so links and documents open the app that was just installed.
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"$LSREGISTER" -u "$EXPORT_DIR/Oriel.app" 2>/dev/null || true
"$LSREGISTER" -f "$INSTALL_DIR/Oriel.app"

[ "${NO_OPEN:-}" = "1" ] || open "$INSTALL_DIR/Oriel.app"

#!/usr/bin/env bash
#
# notarize.sh — notarize an .app or a .dmg with the Apple ID from scripts/apple-credentials.env,
# staple the ticket to it, and prove the staple took.
#
# An .app goes up as a zip, because notarytool does not take a bundle, but the ticket is stapled to
# the .app itself: the copy a user drags out of the dmg then opens without asking Apple's servers.
#
# Usage:
#   bash scripts/release/notarize.sh dist/Oriel.app
#   bash scripts/release/notarize.sh dist/Oriel-0.1.0.dmg
#
# Required env: APPLE_ID, APPLE_PASSWORD (app-specific), APPLE_TEAM_ID.
set -euo pipefail

TARGET="${1:?usage: notarize.sh <Oriel.app | Oriel.dmg>}"
: "${APPLE_ID:?set APPLE_ID — run: source scripts/apple-credentials.env}"
: "${APPLE_PASSWORD:?set APPLE_PASSWORD (an app-specific password, not your Apple ID password)}"
: "${APPLE_TEAM_ID:?set APPLE_TEAM_ID — run: source scripts/apple-credentials.env}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

case "$TARGET" in
  *.app)
    SUBMIT="$WORK/$(basename "$TARGET" .app).zip"
    ditto -c -k --keepParent "$TARGET" "$SUBMIT"
    ;;
  *.dmg) SUBMIT="$TARGET" ;;
  *)
    echo "error: notarize.sh takes an .app or a .dmg (got $TARGET)." >&2
    exit 1
    ;;
esac

echo "==> notarize $(basename "$TARGET") (notarytool --wait; usually 1-5 minutes)"
# The verdict is read back from the output instead of trusted to the exit code, and the log that
# explains a rejection can only be fetched by submission id, so both are kept.
set +e
xcrun notarytool submit "$SUBMIT" \
  --apple-id "$APPLE_ID" --password "$APPLE_PASSWORD" --team-id "$APPLE_TEAM_ID" --wait 2>&1 | tee "$WORK/submit.log"
SUBMIT_EXIT="${PIPESTATUS[0]}"
set -e
ID="$(sed -n -E 's/^ *id: *//p' "$WORK/submit.log" | tail -1)"
STATUS="$(sed -n -E 's/^ *status: *//p' "$WORK/submit.log" | tail -1)"
if [ "$SUBMIT_EXIT" != "0" ] || [ "$STATUS" != "Accepted" ]; then
  echo "error: notarizing $(basename "$TARGET") ended as '${STATUS:-no status}' (exit $SUBMIT_EXIT)." >&2
  if [ -n "$ID" ]; then
    echo "       Apple's log for $ID:" >&2
    xcrun notarytool log "$ID" \
      --apple-id "$APPLE_ID" --password "$APPLE_PASSWORD" --team-id "$APPLE_TEAM_ID" >&2 || true
  fi
  exit 1
fi

echo "==> staple the ticket to $(basename "$TARGET")"
xcrun stapler staple -q "$TARGET"
xcrun stapler validate -q "$TARGET" || {
  echo "error: $(basename "$TARGET") is not stapled — Gatekeeper would have to reach Apple to open it." >&2
  exit 1
}

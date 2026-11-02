#!/usr/bin/env bash
#
# notary-auth.sh — sourced by notarize.sh and release-macos.sh: how notarytool signs in, as the array
# NOTARY_AUTH. The keychain profile NOTARY_PROFILE (codertapsu-notary unless set; made once with
# `xcrun notarytool store-credentials`, docs/RELEASING.md) keeps the app-specific password in the
# login keychain. Without it, APPLE_ID, APPLE_PASSWORD and APPLE_TEAM_ID from
# scripts/apple-credentials.env sign in.
# shellcheck disable=SC2034  # NOTARY_AUTH and NOTARY_SOURCE are for the scripts that source this one

NOTARY_PROFILE="${NOTARY_PROFILE:-codertapsu-notary}"
if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  NOTARY_AUTH=(--keychain-profile "$NOTARY_PROFILE")
  NOTARY_SOURCE="the keychain profile $NOTARY_PROFILE"
else
  : "${APPLE_ID:?set APPLE_ID, or make the keychain profile $NOTARY_PROFILE (docs/RELEASING.md)}"
  : "${APPLE_PASSWORD:?set APPLE_PASSWORD (an app-specific password, not your Apple ID password)}"
  : "${APPLE_TEAM_ID:?set APPLE_TEAM_ID — run: source scripts/apple-credentials.env}"
  NOTARY_AUTH=(--apple-id "$APPLE_ID" --password "$APPLE_PASSWORD" --team-id "$APPLE_TEAM_ID")
  NOTARY_SOURCE="APPLE_ID, APPLE_PASSWORD and APPLE_TEAM_ID"
fi

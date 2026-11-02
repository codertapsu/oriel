#!/usr/bin/env bash
#
# release-macos.sh — one command to cut an Oriel release on this Mac: preflight, quality gate,
# archive, export, notarize and staple the app, wrap it in a dmg, notarize and staple that, verify.
#
# Artifacts are built locally by design, as Gitweaver's and Mother Claude's are, with the same
# scripts/apple-credentials.env (docs/RELEASING.md). Oriel has no updater (PLAN D3), so a release is
# one dmg: no update archive, no manifest.
#
# The app is notarized and stapled before it goes into the dmg, and the dmg after that. Stapling only
# the dmg leaves the copy a user drags to /Applications without a ticket of its own, so its first
# launch depends on Apple's servers answering; stapling only the app leaves the dmg unverifiable.
#
# Usage:
#   source scripts/apple-credentials.env        # git-ignored; see the .example
#   SKIP_UPLOAD=1 RELEASE_TAG=v0.1.0 bash scripts/release/release-macos.sh
#
#   SKIP_UPLOAD=1 ...   build, notarize and verify, then stop. Required until Oriel has a release
#                       destination (PLAN §15); `make release-dry-run` sets it.
#   SKIP_BUILD=1  ...   reuse dist/Oriel.app (no gate, no archive)
#   ALLOW_DIRTY=1 ...   build uncommitted work or another commit (rehearsals only)
#
# Required env: APPLE_SIGNING_IDENTITY, APPLE_ID, APPLE_PASSWORD, APPLE_TEAM_ID.
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

TAG="${RELEASE_TAG:?set RELEASE_TAG (e.g. RELEASE_TAG=v0.1.0)}"
case "$TAG" in
  v[0-9]*) ;;
  *) echo "error: RELEASE_TAG '$TAG' does not look like a version tag (expected v0.1.0 or similar)." >&2; exit 1 ;;
esac
VERSION="${TAG#v}"

: "${APPLE_SIGNING_IDENTITY:?set APPLE_SIGNING_IDENTITY — run: source scripts/apple-credentials.env}"
: "${APPLE_ID:?set APPLE_ID — run: source scripts/apple-credentials.env}"
: "${APPLE_PASSWORD:?set APPLE_PASSWORD (an app-specific password, not your Apple ID password)}"
: "${APPLE_TEAM_ID:?set APPLE_TEAM_ID — run: source scripts/apple-credentials.env}"

[ "$(uname -s)" = "Darwin" ] || {
  echo "error: Oriel is released from a Mac." >&2
  exit 1
}

APP="dist/Oriel.app"
DMG="dist/Oriel-$VERSION.dmg"

# ---------------------------------------------------------------------------
# 1. Preflight. Everything cheap that can invalidate the release happens BEFORE
#    the notarizations, because notarization cannot be taken back.
# ---------------------------------------------------------------------------
echo "==> preflight: project.yml's MARKETING_VERSION is $VERSION"
PROJECT_VERSION="$(sed -n -E 's/^ +MARKETING_VERSION: *"?([^"]*)"?.*$/\1/p' project.yml)"
[ "$PROJECT_VERSION" = "$VERSION" ] || {
  echo "error: project.yml says ${PROJECT_VERSION:-nothing}, the tag says $VERSION." >&2
  echo "       Bump MARKETING_VERSION in project.yml, commit, then tag." >&2
  exit 1
}

echo "==> preflight: the signing identity is in the keychain and belongs to project.yml's team"
# Captured, then matched: under pipefail, `security … | grep -q` can fail on a match, because grep
# exits early and the writer dies of SIGPIPE.
IDENTITIES="$(security find-identity -v -p codesigning)"
case "$IDENTITIES" in
  *"\"$APPLE_SIGNING_IDENTITY\""*) ;;
  *)
    echo "error: '$APPLE_SIGNING_IDENTITY' is not in the login keychain." >&2
    echo "       Available identities:" >&2
    echo "$IDENTITIES" | sed 's/^/         /' >&2
    exit 1
    ;;
esac
TEAM="$(sed -n -E 's/^ +DEVELOPMENT_TEAM: *([A-Z0-9]+).*$/\1/p' project.yml)"
[ "$APPLE_TEAM_ID" = "$TEAM" ] || {
  echo "error: APPLE_TEAM_ID is not project.yml's DEVELOPMENT_TEAM ($TEAM). The archive is signed for" >&2
  echo "       one team and would be notarized under another." >&2
  exit 1
}
case "$APPLE_SIGNING_IDENTITY" in
  "Developer ID Application: "*"($TEAM)") ;;
  *)
    # An Apple Development identity builds fine and then fails notarization, a slow way to find out.
    echo "error: APPLE_SIGNING_IDENTITY must be a 'Developer ID Application' identity of team $TEAM." >&2
    exit 1
    ;;
esac

echo "==> preflight: Apple accepts the notarization credentials"
xcrun notarytool history --apple-id "$APPLE_ID" --password "$APPLE_PASSWORD" --team-id "$APPLE_TEAM_ID" \
  >/dev/null || {
  echo "error: notarytool rejected APPLE_ID / APPLE_PASSWORD / APPLE_TEAM_ID. APPLE_PASSWORD must be an" >&2
  echo "       app-specific password (appleid.apple.com -> Sign-In and Security)." >&2
  exit 1
}

echo "==> preflight: the working tree is clean, and is $TAG"
# A release built from uncommitted work, or from a commit other than the tag's, cannot be reproduced
# from its tag, and nobody can tell later which of the two the users actually got.
TAG_COMMIT="$(git rev-parse -q --verify "refs/tags/$TAG^{commit}" || true)"
HEAD_COMMIT="$(git rev-parse HEAD)"
if [ -n "$(git status --porcelain)" ] || [ "$TAG_COMMIT" != "$HEAD_COMMIT" ]; then
  if [ "${ALLOW_DIRTY:-}" = "1" ]; then
    echo "    WARNING: ALLOW_DIRTY=1 — this build is not reproducible from $TAG"
  elif [ -z "$TAG_COMMIT" ]; then
    echo "error: there is no tag $TAG here. Tag before building: git tag $TAG" >&2
    exit 1
  elif [ "$TAG_COMMIT" != "$HEAD_COMMIT" ]; then
    echo "error: HEAD is not $TAG. Build the tag, not whatever the branch has moved to:" >&2
    echo "         git checkout $TAG" >&2
    exit 1
  else
    git status --short | sed 's/^/      /'
    echo "error: uncommitted changes. Commit them, or set ALLOW_DIRTY=1 if you mean it." >&2
    exit 1
  fi
fi

# Before the build, not after it: a release with nowhere to go is a two-second check here and a
# wasted build and two notarizations later.
if [ "${SKIP_UPLOAD:-}" != "1" ]; then
  echo "error: Oriel has no release destination yet (PLAN §15: the file host and the Homebrew tap)." >&2
  echo "       Run with SKIP_UPLOAD=1 to build, notarize and verify the dmg in dist/." >&2
  exit 1
fi

if [ "${SKIP_BUILD:-}" = "1" ]; then
  echo "==> SKIP_BUILD=1 — reusing $APP (it was gated when it was built)"
  [ -d "$APP" ] || {
    echo "error: there is no $APP to reuse." >&2
    exit 1
  }
else
  echo "==> the full quality gate (make lint test universal-check appstore-check)"
  make lint test universal-check appstore-check
  bash scripts/release/export-app.sh
fi

# The version, both slices of both executables, the signer and the entitlements, proven rather than
# assumed: each of them can be wrong in a build that still signs, notarizes and installs.
echo "==> the app: its version, both slices, the Developer ID signature, release entitlements"
APP_VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")"
[ "$APP_VERSION" = "$VERSION" ] || {
  echo "error: $APP reports version $APP_VERSION, not $VERSION." >&2
  exit 1
}
for exe in "$APP/Contents/MacOS/Oriel" "$APP/Contents/Helpers/oriel"; do
  ARCHS="$(lipo -archs "$exe" 2>/dev/null || echo '?')"
  echo "    ${exe#"$APP/"}: $ARCHS"
  for slice in x86_64 arm64; do
    case " $ARCHS " in
      *" $slice "*) ;;
      *) echo "error: $exe has no $slice slice (found: $ARCHS)." >&2; exit 1 ;;
    esac
  done
done
codesign --verify --deep --strict "$APP"
case "$(codesign -dvv "$APP" 2>&1)" in
  *"Authority=$APPLE_SIGNING_IDENTITY"*) ;;
  *)
    echo "error: $APP is not signed by '$APPLE_SIGNING_IDENTITY'." >&2
    exit 1
    ;;
esac
case "$(codesign -d --entitlements - --xml "$APP" 2>/dev/null)" in
  *get-task-allow*)
    echo "error: $APP still carries get-task-allow; notarization would reject it." >&2
    exit 1
    ;;
esac

# ---------------------------------------------------------------------------
# 2. Notarize + staple the app, wrap it, then notarize + staple the dmg.
# ---------------------------------------------------------------------------
bash scripts/release/notarize.sh "$APP"
bash scripts/release/make-dmg.sh "$APP" "$DMG"
bash scripts/release/notarize.sh "$DMG"

echo "==> verify (this is the check that catches a Gatekeeper failure here rather than on a user's Mac)"
spctl -a -vvv -t open --context context:primary-signature "$DMG" 2>&1 | sed 's/^/    /'
# The app as well, and fatally: `-t exec` is the question Gatekeeper asks when somebody opens it.
spctl -a -vvv -t exec "$APP" 2>&1 | sed 's/^/    /'

echo
echo "macOS release built for $TAG, notarized, stapled and verified:"
echo "  $DMG"
echo "  sha256 $(shasum -a 256 "$DMG" | cut -d ' ' -f 1)"
echo
echo "Publishing is not wired up yet: PLAN §15 still lacks the file host and the tap."

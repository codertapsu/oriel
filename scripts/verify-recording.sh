#!/usr/bin/env bash
#
# verify-recording.sh — PLAN §13.6: a 10 s recording lasts 10 ± 0.2 s and has its audio track; with --pause,
# pausing from 3 s to 5 s still yields one playable movie, of 8 ± 0.2 s.
#
# Records the main display through `oriel debug record`, so a Debug build of Oriel must be running (make run)
# with Screen Recording, and Settings → Recording → System audio on (the default). The movie stays in Oriel's
# recordings folder, and the finished-recording panel opens as after any recording.
#
# Usage:
#   ORIEL_TCC_TESTS=1 bash scripts/verify-recording.sh [--pause]
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/support/common.sh"
require_tcc

ARGUMENTS=(--seconds 10)
EXPECTED=10
if [ "${1:-}" = "--pause" ]; then
  ARGUMENTS+=(--pause-at 3 --resume-at 5)
  EXPECTED=8
fi

CLI="$(oriel_cli)"
INFO="$(helper movie-info)"

echo "==> oriel debug record ${ARGUMENTS[*]}"
MOVIE="$("$CLI" debug record "${ARGUMENTS[@]}")" || fail "the recording did not finish: $MOVIE"
echo "    $MOVIE"
REPORT="$("$INFO" "$MOVIE")"
echo "    $REPORT"

DURATION="$(echo "$REPORT" | json_value duration)"
within "$DURATION" "$EXPECTED" 0.2 || fail "the movie lasts $DURATION s, not $EXPECTED ± 0.2 s"
echo "    ✓ $DURATION s"
[ "$(echo "$REPORT" | json_value playable)" = "true" ] || fail "the movie is not playable"
echo "    ✓ playable"
[ "$(echo "$REPORT" | json_value videoTracks)" = "1" ] || fail "the movie has no single video track"
[ "$(echo "$REPORT" | json_value audioTracks)" -ge 1 ] || fail "the movie has no audio track (is System audio on?)"
echo "    ✓ video and audio tracks"

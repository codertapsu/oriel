#!/usr/bin/env bash
#
# verify-windows.sh — PLAN §13.2: `oriel windows list --json` lists a known set of windows, and
# `oriel windows focus <id>` brings the right one to the front; with --other-space, one on another Space.
#
# Opens three windows in a fixture app ("Oriel fixture 1" to "3", the third minimized), checks the list,
# focuses fixture 2 and reads the focused window back through Accessibility (from the fixture itself when
# this terminal has no Accessibility). With --other-space it asks you to move fixture 1 to another Space
# first.
#
# Needs Oriel running with Accessibility and the screen unlocked: while it is locked, Accessibility lists no
# windows (docs/os-quirks.md).
#
# Usage:
#   ORIEL_TCC_TESTS=1 bash scripts/verify-windows.sh [--other-space]
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/support/common.sh"
require_tcc

TAB="$(printf '\t')"
CLI="$(oriel_cli)"
FIXTURE="$(helper window-fixture)"
LIST="$(helper window-list)"
FOCUSED="$(helper focused-window)"

"$FIXTURE" >"$WORK/fixture.log" 2>&1 &
FIXTURE_PID=$!
disown "$FIXTURE_PID" # no "Terminated" notice when the trap kills it
trap 'kill "$FIXTURE_PID" 2>/dev/null || true; rm -rf "$WORK"' EXIT
for _ in $(seq 1 50); do
  grep -q '^ready' "$WORK/fixture.log" && break
  sleep 0.1
done
grep -q '^ready' "$WORK/fixture.log" || fail "the fixture app did not start: $(cat "$WORK/fixture.log")"
sleep 1 # Oriel learns about new windows from Accessibility notifications

fixture_windows() {
  "$CLI" windows list --json --space all | "$LIST" "$FIXTURE_PID"
}

window_line() {
  echo "$LISTED" | awk -F"$TAB" -v title="$1" '$4 == title'
}

focus_and_check() {
  local title="$1" id front
  id="$(window_line "$title" | cut -f1)"
  [ -n "$id" ] || fail "$title is not listed"
  "$CLI" windows focus "$id" >/dev/null
  sleep 0.5
  if front="$("$FOCUSED")"; then
    [ "$front" = "$FIXTURE_PID$TAB$title" ] || fail "after focusing $title, Accessibility reports '$front'"
  else
    grep -q "^focused $title\$" "$WORK/fixture.log" || fail "$title did not become the key window"
  fi
  echo "    ✓ $title is focused"
}

echo "==> oriel windows list --json --space all"
LISTED="$(fixture_windows)"
[ -n "$LISTED" ] || fail "no fixture window is listed (is the screen locked, or Accessibility missing?)"
echo "$LISTED" | sed 's/^/    /'
for index in 1 2 3; do
  [ -n "$(window_line "Oriel fixture $index")" ] || fail "Oriel fixture $index is missing"
done
[ "$(window_line "Oriel fixture 3" | cut -f2)" = "minimized" ] || fail "Oriel fixture 3 is not reported as minimized"
[ "$(window_line "Oriel fixture 1" | cut -f2)" = "visible" ] || fail "Oriel fixture 1 is reported as minimized"
echo "    ✓ all three fixtures, the third minimized"

echo "==> oriel windows focus"
focus_and_check "Oriel fixture 2"
focus_and_check "Oriel fixture 3"

if [ "${1:-}" = "--other-space" ]; then
  echo "Move 'Oriel fixture 1' to another Space (Mission Control: drag it onto another desktop),"
  read -r -p "come back to this Space, then press Return. " _
  LISTED="$(fixture_windows)"
  [ "$(window_line "Oriel fixture 1" | cut -f3)" = "other-space" ] || fail "Oriel fixture 1 is not reported on another Space"
  focus_and_check "Oriel fixture 1"
fi

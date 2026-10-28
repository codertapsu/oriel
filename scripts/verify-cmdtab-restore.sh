#!/usr/bin/env bash
#
# verify-cmdtab-restore.sh — PLAN §7.1.4, §13.2: while a switcher shortcut takes over ⌘⇥, the system app
# switcher is off; it is back after Oriel quits, and after `kill -9` once Oriel has been opened again.
#
# Needs a switcher shortcut bound to ⌘⇥ (Settings → Window Switcher) and Accessibility for Oriel. The script
# quits, opens and kills Oriel several times; ⌘⇥ is Oriel's or nobody's meanwhile, and it always ends with the
# system's ⌘⇥ on.
#
# Usage:
#   ORIEL_TCC_TESTS=1 bash scripts/verify-cmdtab-restore.sh [/path/to/Oriel.app]   # /Applications/Oriel.app
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/support/common.sh"
require_tcc

APP="${1:-/Applications/Oriel.app}"
[ -d "$APP" ] || fail "$APP does not exist"
CLI="$APP/Contents/Helpers/oriel"
HOTKEY="$(helper symbolic-hotkey)"
COMMAND_TAB=1

# Whatever happens, the system's ⌘⇥ is on when the script ends.
trap '[ "$("$HOTKEY" "$COMMAND_TAB")" = "enabled" ] || "$HOTKEY" "$COMMAND_TAB" on >/dev/null; rm -rf "$WORK"' EXIT

state() {
  "$HOTKEY" "$COMMAND_TAB"
}

wait_for_exit() {
  local _
  for _ in $(seq 1 50); do
    pgrep -x Oriel >/dev/null || return 0
    sleep 0.2
  done
  fail "Oriel did not quit"
}

# `windows list` answers once the switcher has started, that is, once it has turned back on what a killed run
# left off and taken ⌘⇥ over again.
launch() {
  local _
  open -a "$APP"
  for _ in $(seq 1 75); do
    "$CLI" windows list --json >/dev/null 2>&1 && break
    sleep 0.2
  done
  "$CLI" windows list --json >/dev/null 2>&1 || fail "Oriel's window switcher did not start"
  [ "$(state)" = "disabled" ] || fail "Oriel did not take over ⌘⇥: bind a switcher shortcut to ⌘⇥ in Settings → Window Switcher"
}

if pgrep -x Oriel >/dev/null; then
  pkill -TERM -x Oriel
  wait_for_exit
fi
[ "$(state)" = "enabled" ] || fail "the system's ⌘⇥ is off before Oriel runs; turn it on (System Settings → Keyboard → Keyboard Shortcuts)"

echo "==> quit"
launch
echo "    Oriel owns ⌘⇥"
pkill -TERM -x Oriel
wait_for_exit
[ "$(state)" = "enabled" ] || fail "⌘⇥ is still off after Oriel quit"
echo "    ✓ the system's ⌘⇥ is back after quitting"

echo "==> kill -9"
launch
pkill -KILL -x Oriel
wait_for_exit
echo "    after kill -9 the system's ⌘⇥ is $(state) (nothing can run in a killed process)"
launch
echo "    Oriel opened again and owns ⌘⇥"
pkill -TERM -x Oriel
wait_for_exit
[ "$(state)" = "enabled" ] || fail "⌘⇥ is still off after kill -9, a new launch and a quit"
echo "    ✓ the system's ⌘⇥ is back after kill -9 and the next launch"

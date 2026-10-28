#!/usr/bin/env bash
#
# idle-cpu.sh — PLAN §9, §13.2: an idle Oriel uses 0.0 % CPU (nothing polls; CLAUDE.md rule 3).
#
# Samples the running Oriel once a second with top(1) and passes when the average CPU of every sample but the
# first (which has no baseline) rounds to 0.0 %. Leave the Mac alone while it runs: no captures, no switcher,
# no recording. A locked screen is a fair idle state.
#
# Usage:
#   bash scripts/idle-cpu.sh               # 600 samples, ten minutes
#   SAMPLES=60 bash scripts/idle-cpu.sh    # a quicker look
#   ORIEL_PID=1234 bash scripts/idle-cpu.sh   # when more than one copy is running
set -euo pipefail

SAMPLES="${SAMPLES:-600}"
PID="${ORIEL_PID:-}"
if [ -z "$PID" ]; then
  PIDS="$(pgrep -x Oriel || true)"
  [ -n "$PIDS" ] || { echo "Oriel is not running." >&2; exit 2; }
  [ "$(echo "$PIDS" | wc -l | tr -d ' ')" = "1" ] || { echo "Several copies of Oriel are running; set ORIEL_PID." >&2; exit 2; }
  PID="$PIDS"
fi

echo "==> sampling Oriel (pid $PID) for $SAMPLES s"
top -l "$SAMPLES" -s 1 -pid "$PID" -stats pid,cpu,idlew | awk -v pid="$PID" -v samples="$SAMPLES" '
  $1 == pid {
    seen++
    if (seen == 1) { first = $3; next }
    count++; total += $2; last = $3
    if ($2 > peak) peak = $2
    if ($2 > 0) busy++
  }
  END {
    if (count < samples - 1) { printf "FAIL: Oriel quit after %d samples\n", seen; exit 1 }
    average = total / count
    # IDLEW counts idle wake-ups since launch, so the run added last - first.
    printf "    average %.2f %%, peak %.1f %%, %d of %d samples above 0.0 %%, %d idle wake-ups in %d s\n",
      average, peak, busy, count, last - first, count
    if (average < 0.05) { print "    ✓ idle at 0.0 %"; exit 0 }
    print "FAIL: the average is above 0.0 %"; exit 1
  }'

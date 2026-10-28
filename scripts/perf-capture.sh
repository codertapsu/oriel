#!/usr/bin/env bash
#
# perf-capture.sh — PLAN §9, §13.3: the Capture Area overlay is on screen within 120 ms at the 95th percentile.
#
# Asks a running Debug build of Oriel (make run, with Screen Recording) to present and cancel the area overlay
# a number of times (`oriel debug perf-capture`), timing the span of the "Capture to overlay" signpost: from
# fetching the shareable content to the overlay being ordered in. The overlay flashes once per run; leave the
# Mac alone meanwhile. Debug is the slower build, so a pass here should hold for Release. To look at the
# signposts themselves, record a run in Instruments (os_signpost, subsystem com.codertapsu.oriel, category
# capture).
#
# Usage:
#   ORIEL_TCC_TESTS=1 bash scripts/perf-capture.sh [runs]     # 20 runs by default
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/support/common.sh"
require_tcc

RUNS="${1:-20}"
BUDGET_MS=120
CLI="$(oriel_cli)"

echo "==> oriel debug perf-capture --runs $RUNS"
REPORT="$("$CLI" debug perf-capture --runs "$RUNS" --json)" || fail "the measurement failed: $REPORT"
P50="$(echo "$REPORT" | json_value p50)"
P95="$(echo "$REPORT" | json_value p95)"
printf '    p50 %.1f ms, p95 %.1f ms (budget %d ms)\n' "$P50" "$P95" "$BUDGET_MS"
awk -v p95="$P95" -v budget="$BUDGET_MS" 'BEGIN { exit !(p95 < budget) }' || fail "p95 is over the budget"
echo "    ✓ within budget"

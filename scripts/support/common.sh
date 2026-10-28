# common.sh — sourced by the verify scripts (PLAN §13). Sets ROOT and WORK (a scratch folder that is removed
# on exit), finds the oriel CLI and builds the Swift helpers next to this file. Written for macOS's bash 3.2.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d -t oriel-verify)"
trap 'rm -rf "$WORK"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# Accessibility, Screen Recording and the login keychain are only granted on the dev Mac and the macOS 26 VM.
require_tcc() {
  if [ "${ORIEL_TCC_TESTS:-}" != "1" ]; then
    echo "This check needs TCC permissions: run it with ORIEL_TCC_TESTS=1 on the dev Mac or the macOS 26 VM." >&2
    exit 2
  fi
}

# The CLI of the Debug build, else the installed one; ORIEL_CLI overrides. Any copy talks to whichever Oriel
# is running, but the debug verbs answer only when that is a Debug build.
oriel_cli() {
  if [ -n "${ORIEL_CLI:-}" ]; then
    echo "$ORIEL_CLI"
    return
  fi
  local products candidate
  products="$(xcodebuild -project "$ROOT/Oriel.xcodeproj" -scheme Oriel -configuration Debug -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2; exit}')"
  for candidate in "$products/Oriel.app/Contents/Helpers/oriel" /Applications/Oriel.app/Contents/Helpers/oriel; do
    if [ -x "$candidate" ]; then
      echo "$candidate"
      return
    fi
  done
  echo "No oriel CLI found: run make build, or set ORIEL_CLI." >&2
  return 1
}

# helper <name>: compiles scripts/support/<name>.swift once per run and prints the binary's path.
helper() {
  local binary="$WORK/$1"
  if [ ! -x "$binary" ]; then
    xcrun swiftc -O -o "$binary" "$ROOT/scripts/support/$1.swift" >&2
  fi
  echo "$binary"
}

# json_value <keypath>: one value from the JSON on stdin (plutil reads JSON).
json_value() {
  plutil -extract "$1" raw -o - -
}

# Succeeds when the two numbers differ by at most the tolerance.
within() {
  awk -v value="$1" -v expected="$2" -v tolerance="$3" 'BEGIN { d = value - expected; if (d < 0) d = -d; exit !(d <= tolerance) }'
}

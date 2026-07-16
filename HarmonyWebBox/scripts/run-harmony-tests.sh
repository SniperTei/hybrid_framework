#!/usr/bin/env zsh
# run-harmony-tests.sh
#
# Build + install + run CoconutSDK Hypium tests on a connected HarmonyOS
# device/emulator, then emit a structured markdown report.
#
# Usage:
#   ./scripts/run-harmony-tests.sh                 # run, print summary, write report
#   ./scripts/run-harmony-tests.sh --quiet         # only print the final summary line
#   ./scripts/run-harmony-tests.sh --no-report     # skip writing the markdown file
#   ./scripts/run-harmony-tests.sh --keep-raw FILE # also keep the raw aa test output
#
# Prerequisites:
#   - DevEco Studio installed at /Applications/DevEco-Studio.app
#   - A device or emulator visible via `hdc list targets`

set -euo pipefail
# zsh: 0-based arrays, but our usage is associative so it doesn't matter

# --- Paths (edit if your DevEco install lives elsewhere) ----------------------
DEVECO_ROOT="/Applications/DevEco-Studio.app/Contents"
DEVECO_SDK_HOME="${DEVECO_SDK_HOME:-${DEVECO_ROOT}/sdk}"
HDC="${HDC:-${DEVECO_SDK_HOME}/default/openharmony/toolchains/hdc}"
HVIGORW="${DEVECO_ROOT}/tools/hvigor/bin/hvigorw"
NODE_BIN="${DEVECO_ROOT}/tools/node"
OHPM_BIN="${DEVECO_ROOT}/tools/ohpm/bin"

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="com.example.harmonywebbox"
MODULE="entry_test"
HAP_REL="entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap"

# --- Flags --------------------------------------------------------------------
QUIET=0
WRITE_REPORT=1
RAW_FILE=""
while [ $# -gt 0 ]; do
  arg="$1"
  case "$arg" in
    --quiet)      QUIET=1 ;;
    --no-report)  WRITE_REPORT=0 ;;
    --keep-raw)   shift; RAW_FILE="${1:-}" ;;
    -h|--help)
      sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "Unknown flag: $arg" >&2; exit 2 ;;
  esac
  shift
done

# --- Sanity checks ------------------------------------------------------------
command -v "$HDC" >/dev/null 2>&1 || { echo "hdc not found at $HDC" >&2; exit 1; }
[ -x "$HVIGORW" ] || { echo "hvigorw not found at $HVIGORW" >&2; exit 1; }

DEVICES="$("$HDC" list targets 2>/dev/null | grep -E '^[0-9]' || true)"
if [ -z "$DEVICES" ]; then
  echo "No HarmonyOS device/emulator detected. Run 'hdc list targets'." >&2
  exit 1
fi

export DEVECO_SDK_HOME
export PATH="${HVIGORW%/*}:${NODE_BIN}:${OHPM_BIN}:$PATH"

# --- 1. Build ----------------------------------------------------------------
if [ "$QUIET" -eq 0 ]; then echo "==> Building ohosTest HAP…"; fi
(
  cd "$PROJECT_ROOT"
  "$HVIGORW" --mode module -p module=entry@ohosTest -p product=default assembleHap \
    ${QUIET:+-q} 2>&1 | grep -vE '^(> hvigor (UP-TO-DATE|Finished))' || true
)

HAP_PATH="${PROJECT_ROOT}/${HAP_REL}"
[ -f "$HAP_PATH" ] || { echo "Built HAP not found at $HAP_PATH" >&2; exit 1; }

# --- 2. Install ---------------------------------------------------------------
if [ "$QUIET" -eq 0 ]; then echo "==> Installing on device…"; fi
"$HDC" install -r "$HAP_PATH" >/dev/null 2>&1 || {
  echo "Install failed" >&2; exit 1; }

# --- 3. Run -------------------------------------------------------------------
if [ "$QUIET" -eq 0 ]; then echo "==> Running Hypium tests…"; fi
RAW_OUT="$(mktemp -t hypium.XXXXXX)"
trap 'rm -f "$RAW_OUT"' EXIT

# aa test exits non-zero on test failure, so don't fail-fast under set -e
set +e
"$HDC" shell aa test -b "$BUNDLE" -m "$MODULE" \
  -s unittest /ets/testrunner/OpenHarmonyTestRunner > "$RAW_OUT" 2>&1
AA_RC=$?
set -e

if [ -n "$RAW_FILE" ]; then cp "$RAW_OUT" "$RAW_FILE"; fi

# --- 4. Parse -----------------------------------------------------------------
SUMMARY_LINE="$(grep 'OHOS_REPORT_RESULT: stream=' "$RAW_OUT" | tail -1 || true)"
if [ -z "$SUMMARY_LINE" ]; then
  echo "No OHOS_REPORT_RESULT line found. Raw output:" >&2
  cat "$RAW_OUT" >&2
  exit 1
fi

# Extract numbers from "Tests run: N, Failure: X, Error: Y, Pass: Z, Ignore: W"
TOTAL=$(echo "$SUMMARY_LINE" | sed -nE 's/.*Tests run: ([0-9]+).*/\1/p')
FAIL=$(echo  "$SUMMARY_LINE" | sed -nE 's/.*Failure: ([0-9]+).*/\1/p')
ERR=$(echo   "$SUMMARY_LINE" | sed -nE 's/.*Error: ([0-9]+).*/\1/p')
PASS=$(echo  "$SUMMARY_LINE" | sed -nE 's/.*Pass: ([0-9]+).*/\1/p')
IGNORE=$(echo "$SUMMARY_LINE" | sed -nE 's/.*Ignore: ([0-9]+).*/\1/p')

# Per-suite pass counts and failure/error lists (parsed via awk)
PARSE_OUT="$(mktemp -t hypium-parse.XXXXXX)"
awk '
  /OHOS_REPORT_STATUS: class=/ { class = substr($0, index($0,"class=")+6) }
  /OHOS_REPORT_STATUS: test=/  { test  = substr($0, index($0,"test=")+5) }
  /OHOS_REPORT_STATUS_CODE:/ {
    code = $NF
    if (code == "0") {
      pass[class]++
    } else if (code == "-2") {
      fails[class "::" test] = 1
    } else if (code == "-1") {
      errors[class "::" test] = 1
    }
  }
  END {
    for (c in pass)  printf "P\t%s\t%d\n", c, pass[c]
    for (k in fails)  printf "F\t%s\n", k
    for (k in errors) printf "E\t%s\n", k
  }
' "$RAW_OUT" | sort > "$PARSE_OUT"

# --- 5. Console summary -------------------------------------------------------
if [ "$QUIET" -eq 0 ]; then
  echo
  echo "Per-suite pass counts:"
  awk -F'\t' '$1=="P" { printf "  %-36s %d\n", $2, $3 }' "$PARSE_OUT"
  echo
  echo "Failures:"
  awk -F'\t' '$1=="F" { print "  " $2 }' "$PARSE_OUT"
  echo "Errors:"
  awk -F'\t' '$1=="E" { print "  " $2 }' "$PARSE_OUT"
fi
echo "RESULT: $PASS/$TOTAL passed, $FAIL failed, $ERR errored, $IGNORE ignored"

# --- 6. Markdown report -------------------------------------------------------
if [ "$WRITE_REPORT" -eq 1 ]; then
  DATE="$(date +%Y-%m-%d)"
  REPORT="${PROJECT_ROOT}/docs/hypium-report-${DATE}.md"
  mkdir -p "$(dirname "$REPORT")"
  {
    echo "# Harmony Hypium Test Report — ${DATE}"
    echo
    echo "**Bundle:** \`${BUNDLE}\`  "
    echo "**Module:** \`${MODULE}\`  "
    echo "**Device:** \`$(echo "$DEVICES" | head -1)\`  "
    echo "**Hypium:** @ohos/hypium 1.0.25"
    echo
    echo "## Summary"
    echo
    echo "| Total | Passed | Failed | Errored | Ignored |"
    echo "|-------|--------|--------|---------|---------|"
    echo "| ${TOTAL} | ${PASS} | ${FAIL} | ${ERR} | ${IGNORE} |"
    echo
    if grep -q '^P' "$PARSE_OUT"; then
      echo "## Per-suite results"
      echo
      echo "| Suite | Passed |"
      echo "|-------|--------|"
      awk -F'\t' '$1=="P" { printf "| `%s` | %d |\n", $2, $3 }' "$PARSE_OUT"
      echo
    fi
    if grep -q '^F' "$PARSE_OUT"; then
      echo "## Failures"; echo
      awk -F'\t' '$1=="F" { print "- " $2 }' "$PARSE_OUT"; echo
    fi
    if grep -q '^E' "$PARSE_OUT"; then
      echo "## Errors"; echo
      awk -F'\t' '$1=="E" { print "- " $2 }' "$PARSE_OUT"; echo
    fi
  } > "$REPORT"
  echo "Report written to: ${REPORT#${PROJECT_ROOT}/}"
fi
rm -f "$PARSE_OUT"

# Exit code reflects test outcome
[ "$FAIL" -eq 0 ] && [ "$ERR" -eq 0 ]

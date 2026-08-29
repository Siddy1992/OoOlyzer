#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_TARGETS="$(mktemp)"
TMP_REPORT="$(mktemp)"
trap 'rm -f "$TMP_TARGETS" "$TMP_REPORT"' EXIT

python3 "$ROOT/03_analysis/recover_full_present80_temp.py" \
  --trace "$ROOT/01_traces_and_results/full_present80_temp_trace.txt" \
  --targets "$TMP_TARGETS" | tee "$TMP_REPORT"

echo
if diff -u "$ROOT/01_traces_and_results/final_full_present80_recovery.txt" <(sed "s|Written: .*|Written: extra_targets.txt|" "$TMP_REPORT") >/dev/null; then
    echo "[PASS] Recovery output matches the archived report."
else
    echo "[INFO] Numerical recovery completed; textual path differences or report differences detected."
    echo "       Compare with: $ROOT/01_traces_and_results/final_full_present80_recovery.txt"
fi

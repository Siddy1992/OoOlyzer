#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

REPS=${REPS:-$(json_get "$ARTIFACT_ROOT/configs/present_template.json" experiment.repetitions)}
NIBBLES=${NIBBLES:-"0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15"}
FULL="0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15"

mkdir -p "$ARTIFACT_ROOT/results/present_key" "$ARTIFACT_ROOT/m5out/present_key" "$ARTIFACT_ROOT/build/present_key"
for n in $NIBBLES; do
  echo "PRESENT key nibble $n secret"
  REPS="$REPS" "$ARTIFACT_ROOT/scripts/run_present_template_case.sh" "$n" secret
  for g in $(seq 0 15); do
    echo "PRESENT key nibble $n guess $(printf '%X' "$g")"
    REPS="$REPS" "$ARTIFACT_ROOT/scripts/run_present_template_case.sh" "$n" reference "$g"
  done
done

if [ "$NIBBLES" != "$FULL" ]; then
  echo "partial run complete; set NIBBLES to all 0..15 for key recovery"
  exit 0
fi

"$PYTHON" "$ARTIFACT_ROOT/scripts/merge_present_template.py" \
  --root "$ARTIFACT_ROOT/results/present_key" \
  --out "$ARTIFACT_ROOT/results/present_key/merged"

"$PYTHON" "$ARTIFACT_ROOT/scripts/recover_present_template.py" \
  --meta "$ARTIFACT_ROOT/results/present_key/merged/template_meta.csv" \
  --leak "$ARTIFACT_ROOT/results/present_key/merged/gem5_physreg_leak.csv" \
  --json "$ARTIFACT_ROOT/results/present_key/recovery.json"

"$PYTHON" "$ARTIFACT_ROOT/scripts/verify_results.py" --case present-key

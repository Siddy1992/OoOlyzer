#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

"$ARTIFACT_ROOT/scripts/clean_present_key.sh"
rm -f \
  "$ARTIFACT_ROOT/configs/present_first_round_recovery.json" \
  "$ARTIFACT_ROOT/configs/present_key.json" \
  "$ARTIFACT_ROOT/docs/PRESENT_FIRST_ROUND_RECOVERY.md" \
  "$ARTIFACT_ROOT/scripts/recover_present_first_round.py" \
  "$ARTIFACT_ROOT/scripts/run_present_first_round_recovery.sh" \
  "$ARTIFACT_ROOT/scripts/build_present_recovery_case.sh" \
  "$ARTIFACT_ROOT/scripts/run_present_recovery_case.sh" \
  "$ARTIFACT_ROOT/scripts/extract_present_first_round.py" \
  "$ARTIFACT_ROOT/scripts/build_present_recovery_common.sh" \
  "$ARTIFACT_ROOT/scripts/test_present_first_round_rank.py" \
  "$ARTIFACT_ROOT/scripts/present_key_rank.py" \
  "$ARTIFACT_ROOT/scripts/make_present_recovery_harness.py"
rm -rf "$ARTIFACT_ROOT/benchmarks/present_key_recovery"

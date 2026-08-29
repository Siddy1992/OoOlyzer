#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
for m in 1 2 3; do
    MODE=$m PRF=36 "$ARTIFACT_ROOT/scripts/run_pini_case.sh"
done
"$PYTHON" "$ARTIFACT_ROOT/scripts/verify_results.py" --case pini-baseline

#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
CFG=$ARTIFACT_ROOT/configs/pini.json
if [ -z "${PRFS:-}" ]; then
    PRFS=$("$PYTHON" - "$CFG" <<'PY'
import json,sys
print(' '.join(map(str,json.load(open(sys.argv[1]))['sweep_prfs'])))
PY
)
fi
for p in $PRFS; do
    for m in 1 2 3; do
        PRF=$p MODE=$m "$ARTIFACT_ROOT/scripts/run_pini_case.sh"
    done
done
"$PYTHON" "$ARTIFACT_ROOT/scripts/consolidate_pini.py"
"$PYTHON" "$ARTIFACT_ROOT/scripts/verify_results.py" --case pini-sweep

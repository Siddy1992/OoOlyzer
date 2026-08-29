#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
"$ARTIFACT_ROOT/scripts/run_present.sh"
"$ARTIFACT_ROOT/scripts/run_toffoli.sh"
"$ARTIFACT_ROOT/scripts/run_pini_baseline.sh"

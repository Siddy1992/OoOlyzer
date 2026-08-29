#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
rm -rf "$ARTIFACT_ROOT/m5out/present_key" \
       "$ARTIFACT_ROOT/m5out/present_key_recovery" \
       "$ARTIFACT_ROOT/results/present_key" \
       "$ARTIFACT_ROOT/results/present_key_recovery" \
       "$ARTIFACT_ROOT/build/present_key" \
       "$ARTIFACT_ROOT/build/present_recovery"

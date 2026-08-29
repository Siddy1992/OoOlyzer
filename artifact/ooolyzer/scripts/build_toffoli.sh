#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
OUT=${1:-$ARTIFACT_ROOT/build/toffoli32.elf}
mkdir -p "$(dirname "$OUT")"
"$RISCV_GCC" -march=rv32im -mabi=ilp32 -nostdlib -nostartfiles -static -g -O0 \
  -Wl,-e,_start -Wl,--no-relax -Wl,--build-id=none \
  -o "$OUT" \
  "$ARTIFACT_ROOT/benchmarks/toffoli/harness.S" \
  "$ARTIFACT_ROOT/benchmarks/toffoli/toffoli.S"
file "$OUT"

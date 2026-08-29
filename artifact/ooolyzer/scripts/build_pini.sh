#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

MODE=${MODE:-3}
ITERATIONS=${ITERATIONS:-64}
OUT=${OUT:-$ARTIFACT_ROOT/build/pini_m${MODE}.elf}

case "$MODE" in
    1) EXPECTED_TAGS=14 ;;
    2) EXPECTED_TAGS=16 ;;
    3) EXPECTED_TAGS=30 ;;
    *) echo "invalid PINI mode: $MODE" >&2; exit 2 ;;
esac

mkdir -p "$(dirname "$OUT")"
"$RISCV_GCC" -march=rv32im -mabi=ilp32 -nostdlib -nostartfiles -static \
  -Wl,-e,_start -Wl,--build-id=none \
  -DTEST_MODE="$MODE" -DITERATIONS="$ITERATIONS" \
  -o "$OUT" "$ARTIFACT_ROOT/benchmarks/pini/pini_basic.S"

tagged=$("$RISCV_NM" -n "$OUT" | awk '$3 ~ /^PINI__/ {n++} END {print n+0}')
if [[ "$tagged" -ne "$EXPECTED_TAGS" ]]; then
    echo "unexpected PINI tag count for mode $MODE: got $tagged, expected $EXPECTED_TAGS" >&2
    exit 1
fi
printf 'PINI mode %s: %s tagged PCs\n' "$MODE" "$tagged"

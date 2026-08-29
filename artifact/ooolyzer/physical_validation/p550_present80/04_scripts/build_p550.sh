#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/02_experiment/bin"

CC="${CC:-gcc}"
"$CC" -O2 -Wall -Wextra -march=rv64gc -mabi=lp64d \
  "$ROOT/02_experiment/src/victim_full_present80_temp_p550.c" \
  "$ROOT/02_experiment/src/RISCV_masked_PRESENT_64.S" \
  -o "$ROOT/02_experiment/bin/victim_full_present80_temp_p550"

echo "Built: $ROOT/02_experiment/bin/victim_full_present80_temp_p550"

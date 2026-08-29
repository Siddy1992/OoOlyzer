#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
status=0

echo "== OoOLyzer gem5 configuration =="
echo "PROJECT_ROOT=$PROJECT_ROOT"
echo "GEM5_ROOT=$GEM5_ROOT"
echo "GEM5=$GEM5"
echo "Expected default build directory: $PROJECT_ROOT/gem5/build/RISCV"
echo "Simulator CPU: RISC-V RV32 O3 (DerivO3CPU / CPUTypes.O3)"
echo "Negative control only: CPUTypes.TIMING"
echo

for x in "$PYTHON" "$RISCV_GCC" "$RISCV_NM" "$RISCV_OBJDUMP"; do
    if ! command -v "$x" >/dev/null 2>&1; then
        echo "missing: $x"
        status=1
    fi
done

if [ ! -f "$GEM5" ]; then
    echo "missing gem5 executable: $GEM5"
    echo "See docs/GEM5_SETUP.md."
    echo "If gem5 is elsewhere, export GEM5_ROOT=/path/to/gem5 or GEM5=/path/to/gem5.opt"
    status=1
elif [ ! -x "$GEM5" ]; then
    echo "not executable: $GEM5"
    echo "run: chmod u+x $GEM5"
    status=1
else
    "$GEM5" --version | head -1 || true
fi
exit "$status"

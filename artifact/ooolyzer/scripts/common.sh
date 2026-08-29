#!/usr/bin/env bash
set -euo pipefail
ARTIFACT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PROJECT_ROOT=${PROJECT_ROOT:-$(cd "$ARTIFACT_ROOT/../.." && pwd)}
GEM5_ROOT=${GEM5_ROOT:-$PROJECT_ROOT/gem5}
GEM5=${GEM5:-$GEM5_ROOT/build/RISCV/gem5.opt}
RISCV_GCC=${RISCV_GCC:-riscv64-unknown-elf-gcc}
RISCV_NM=${RISCV_NM:-riscv64-unknown-elf-nm}
RISCV_OBJDUMP=${RISCV_OBJDUMP:-riscv64-unknown-elf-objdump}
PYTHON=${PYTHON:-python3}
TOOL=$ARTIFACT_ROOT/tool/ooolyzer.py
export ARTIFACT_ROOT PROJECT_ROOT GEM5_ROOT GEM5 RISCV_GCC RISCV_NM RISCV_OBJDUMP PYTHON TOOL

json_get() {
    "$PYTHON" - "$1" "$2" <<'PY'
import json,sys
p=sys.argv[2].split('.')
x=json.load(open(sys.argv[1]))
for k in p:
    x=x[k]
print(str(x).lower() if isinstance(x,bool) else x)
PY
}

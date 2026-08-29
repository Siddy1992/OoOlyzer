#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

NIB=${1:?nibble 0..15 required}
MODE=${2:?secret or reference required}
GUESS=${3:--1}
REPS=${REPS:-3}
TAG=nib$(printf '%02d' "$NIB")
if [ "$MODE" = secret ]; then
  PROF=secret
else
  PROF=g$(printf '%02x' "$GUESS")
fi
BD=$ARTIFACT_ROOT/build/present_key/$TAG/$PROF
RD=$ARTIFACT_ROOT/results/present_key/$TAG/$PROF
ASM=$BD/harness.S
META=$RD/template_meta.csv
ELF=$BD/present_key.elf

mkdir -p "$BD" "$RD"
args=(--nibble "$NIB" --reps "$REPS" --mode "$MODE" --asm "$ASM" --meta "$META")
if [ "$MODE" = reference ]; then
  args+=(--guess "$GUESS")
fi
"$PYTHON" "$ARTIFACT_ROOT/scripts/make_present_template_case.py" "${args[@]}"

"$RISCV_GCC" \
  -march=rv32im \
  -mabi=ilp32 \
  -nostdlib \
  -nostartfiles \
  -static \
  -g \
  -O0 \
  -Wl,-e,_start \
  -Wl,--no-relax \
  -Wl,--build-id=none \
  -o "$ELF" \
  "$ASM" \
  "$ARTIFACT_ROOT/benchmarks/present/RISCV_masked-PRESENT.S"

# The harness supplies its own _start and intentionally does not initialize gp.
# Reject a binary if any _start address load was nevertheless relaxed to gp-relative form.
start_disasm=$("$RISCV_OBJDUMP" -d --disassemble=_start "$ELF")
if printf '%s\n' "$start_disasm" | grep -Eq '(^|[[:space:],])gp([[:space:],]|$)'; then
  echo "error: gp-relative instruction found in _start; linker relaxation must remain disabled" >&2
  printf '%s\n' "$start_disasm" >&2
  exit 1
fi

file "$ELF"

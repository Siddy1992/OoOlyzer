#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
CFG=$ARTIFACT_ROOT/configs/pini.json
G5CFG=$ARTIFACT_ROOT/configs/gem5_pini.py
MODE=${MODE:-${1:-3}}
PRF=${PRF:-$(json_get "$CFG" gem5.prf)}
ROB=${ROB:-$(json_get "$CFG" gem5.rob)}
IQ=${IQ:-$(json_get "$CFG" gem5.iq)}
WIDTH=${WIDTH:-$(json_get "$CFG" gem5.width)}
CLK=${CLK:-$(json_get "$CFG" gem5.clk)}
ITERATIONS=${ITERATIONS:-$(json_get "$CFG" iterations)}
ELF=$ARTIFACT_ROOT/build/pini_m${MODE}.elf
MODE="$MODE" ITERATIONS="$ITERATIONS" OUT="$ELF" "$ARTIFACT_ROOT/scripts/build_pini.sh"
OD=$ARTIFACT_ROOT/m5out/pini/prf${PRF}/m${MODE}
RID=$ARTIFACT_ROOT/results/pini/prf${PRF}
PREFIX=$RID/m${MODE}
rm -rf "$OD"
mkdir -p "$OD" "$RID"
"$GEM5" --outdir="$OD" --debug-flags=O3PipeView,Rename,IEW,Commit,FreeList,ExecAll \
  --debug-file=trace.out "$G5CFG" --binary "$ELF" --prf "$PRF" --rob "$ROB" \
  --iq "$IQ" --width "$WIDTH" --clk "$CLK"
"$PYTHON" "$TOOL" --trace "$OD/trace.out" --config "$CFG" --elf "$ELF" \
  --nm "$RISCV_NM" --out-prefix "$PREFIX" --json "${PREFIX}_analysis.json"

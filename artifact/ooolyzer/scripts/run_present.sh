#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
CFG=$ARTIFACT_ROOT/configs/present.json
G5CFG=$ARTIFACT_ROOT/configs/gem5_present_toffoli.py
ELF=${PRESENT_ELF:-$ARTIFACT_ROOT/bin/present32.elf}
if [ "${REBUILD:-0}" = 1 ]; then
    ELF=$ARTIFACT_ROOT/build/present32.elf
    "$ARTIFACT_ROOT/scripts/build_present.sh" "$ELF"
fi
PRF=$(json_get "$CFG" gem5.prf)
ROB=$(json_get "$CFG" gem5.rob)
IQ=$(json_get "$CFG" gem5.iq)
WIDTH=$(json_get "$CFG" gem5.width)
CLK=$(json_get "$CFG" gem5.clk)
L1I=$(json_get "$CFG" gem5.l1i)
L1D=$(json_get "$CFG" gem5.l1d)
L2=$(json_get "$CFG" gem5.l2)
MEM=$(json_get "$CFG" gem5.mem)
FLAGS=Rename,FreeList,IEW,Commit,IQ,LSQ,Scoreboard,Writeback,Exec,ExecFetchSeq
OD=$ARTIFACT_ROOT/m5out/present/o3
RID=$ARTIFACT_ROOT/results/present
rm -rf "$OD"
mkdir -p "$OD" "$RID"
"$GEM5" --outdir="$OD" --debug-flags="$FLAGS" --debug-file=trace.out \
  "$G5CFG" --binary "$ELF" --prf "$PRF" --rob "$ROB" --iq "$IQ" --width "$WIDTH" \
  --clk "$CLK" --l1i "$L1I" --l1d "$L1D" --l2 "$L2" --mem "$MEM"
"$PYTHON" "$TOOL" --trace "$OD/trace.out" --config "$CFG" \
  --json "$RID/present_ril.json" --top 30
"$PYTHON" "$TOOL" --trace "$OD/trace.out" --config "$CFG" --filter-conflicts \
  --json "$RID/present_conflicts.json" --top 40
"$PYTHON" "$TOOL" --trace "$OD/trace.out" --config "$CFG" --loose \
  --json "$RID/present_loose.json" --top 10

IOD=$ARTIFACT_ROOT/m5out/present/inorder
rm -rf "$IOD"
mkdir -p "$IOD"
"$GEM5" --outdir="$IOD" --debug-flags=Rename,FreeList,Exec,ExecFetchSeq,Commit \
  --debug-file=trace.out "$G5CFG" --binary "$ELF" --inorder --clk "$CLK" \
  --l1i "$L1I" --l1d "$L1D" --l2 "$L2" --mem "$MEM"
"$PYTHON" "$TOOL" --trace "$IOD/trace.out" --config "$CFG" --filter-conflicts \
  --json "$RID/present_inorder.json" --top 10 || true
"$PYTHON" "$ARTIFACT_ROOT/scripts/verify_results.py" --case present

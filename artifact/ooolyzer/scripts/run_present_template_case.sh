#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

NIB=${1:?nibble 0..15 required}
MODE=${2:?secret or reference required}
GUESS=${3:--1}
CFG=$ARTIFACT_ROOT/configs/present_template.json
G5CFG=$ARTIFACT_ROOT/configs/gem5_present_toffoli.py
REPS=${REPS:-$(json_get "$CFG" experiment.repetitions)}
PRF=$(json_get "$CFG" gem5.prf)
ROB=$(json_get "$CFG" gem5.rob)
IQ=$(json_get "$CFG" gem5.iq)
WIDTH=$(json_get "$CFG" gem5.width)
CLK=$(json_get "$CFG" gem5.clk)
L1I=$(json_get "$CFG" gem5.l1i)
L1D=$(json_get "$CFG" gem5.l1d)
L2=$(json_get "$CFG" gem5.l2)
MEM=$(json_get "$CFG" gem5.mem)
TAG=nib$(printf '%02d' "$NIB")
if [ "$MODE" = secret ]; then
  PROF=secret
else
  PROF=g$(printf '%02x' "$GUESS")
fi
BD=$ARTIFACT_ROOT/build/present_key/$TAG/$PROF
RD=$ARTIFACT_ROOT/results/present_key/$TAG/$PROF
OD=$ARTIFACT_ROOT/m5out/present_key/$TAG/$PROF
ELF=$BD/present_key.elf

rm -rf "$OD"
mkdir -p "$OD" "$RD"
REPS="$REPS" "$ARTIFACT_ROOT/scripts/build_present_template_case.sh" "$NIB" "$MODE" "$GUESS"

"$GEM5" --outdir="$OD" --debug-flags=Rename,Exec,ExecFetchSeq --debug-file=trace.out \
  "$G5CFG" --binary "$ELF" --prf "$PRF" --rob "$ROB" --iq "$IQ" --width "$WIDTH" \
  --clk "$CLK" --l1i "$L1I" --l1d "$L1D" --l2 "$L2" --mem "$MEM"

"$PYTHON" "$TOOL" --trace "$OD/trace.out" --config "$CFG" \
  --row-csv "$RD/gem5_physreg_leak.csv" \
  --event-csv "$RD/gem5_physreg_events.csv" \
  --json "$RD/analysis.json"

expected=$((16 * REPS))
meta_rows=$(grep -Ec '^[0-9]+,' "$RD/template_meta.csv")
leak_rows=$(( $(wc -l < "$RD/gem5_physreg_leak.csv") - 1 ))
if [ "$meta_rows" -ne "$expected" ] || [ "$leak_rows" -ne "$expected" ]; then
  echo "row count mismatch for nibble $NIB $PROF: meta=$meta_rows leak=$leak_rows expected=$expected" >&2
  exit 1
fi

if [ "${KEEP_PRESENT_KEY_TRACES:-0}" != 1 ]; then
  rm -f "$OD/trace.out"
fi

#!/usr/bin/env bash
# Place in the gem5 root (e.g. ~/ooolyzer_s_p/gem5_pini/). Run from there.
#
# Layout expected (all relative to this script):
#   build/RISCV/gem5.opt
#   configs/ooolyzer_se.py            (the SE config; PINI profile is its default)
#   configs/pini_iew_d3.json          (d=3 marker map + pairs; see note below)
#   ooolyzer/ooolyzer.py              (the COMBINED RIL+IEW tool, run with --mode iew)
#   Makefile.pini  main_pini3.c  pini_hpc3.c   (the d=3 PINI gadget sources)
#
# The PINI binary lives in THIS folder (NOT ../riscv_codes). ELF default ./pini_test
# (override as $1). If it is missing it is BUILT HERE at -O2.
#   *** -O2 is mandatory: -O0 spills the shares to the stack and serialises the
#       share-processing instructions, and the IEW co-residency signal vanishes. ***
set -euo pipefail
cd "$(dirname "$0")"

GEM5=build/RISCV/gem5.opt
ELF="${1:-./pini_test}"
CONFIG=configs/pini_iew_d3.json
OOO=ooolyzer/ooolyzer.py
# Same superset of flags as run_present.sh; the IEW-essential subset is
# Exec,ExecFetchSeq,Commit (the Commit stream the RIL detector never needs).
FLAGS=Rename,FreeList,IEW,Commit,IQ,LSQ,Scoreboard,Writeback,Exec,ExecFetchSeq

# --- build the d=3 PINI gadget at -O2 if the default ELF is absent -----------
if [[ ! -f "$ELF" && "$ELF" == "./pini_test" ]]; then
  echo "== building pini_test (d=3 HPC2, -O2 to expose ILP) =="
  make -f Makefile.pini SRCS="main_pini3.c pini_hpc3.c" \
       CFLAGS="-march=rv32im -mabi=ilp32 -O2 -static"
  echo "   (sanity-run on any rv32 sim should print: pini_and3_hpc2 x8: OK)"
fi

echo "== gem5 O3 trace (PINI profile: PRF 192 / ROB 256 / IQ 64 / 2.5 GHz) =="
"$GEM5" --debug-flags="$FLAGS" --debug-file=trace.out --outdir=m5out_pini \
        configs/ooolyzer_se.py --binary "$ELF"

echo "== parse sanity (expect marker hits = 9 x iterations, commit lines > 0) =="
python3 "$OOO" --mode iew --trace m5out_pini/trace.out --config "$CONFIG" | head -8

echo "== full IEW report (Sec 4.8 IEW-Induced Dispatch Leakage on PINI) =="
python3 "$OOO" --mode iew --trace m5out_pini/trace.out \
        --config "$CONFIG" --json pini_iew.json

echo "== in-order negative control (co-residency + inversions should drop to 0) =="
"$GEM5" --debug-flags=Exec,ExecFetchSeq,Commit \
        --debug-file=trace_inorder.out --outdir=m5out_pini_inorder \
        configs/ooolyzer_se.py --binary "$ELF" --inorder
python3 "$OOO" --mode iew --trace m5out_pini_inorder/trace_inorder.out \
        --config "$CONFIG" --json pini_iew_inorder.json || true

echo "== done. O3 vs in-order contrast is the reproduction; see pini_iew*.json =="

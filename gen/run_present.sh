#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
GEM5=build/RISCV/gem5.opt
ELF="${1:-../riscv_codes/present32.elf}"
FLAGS=Rename,FreeList,IEW,Commit,IQ,LSQ,Scoreboard,Writeback,Exec,ExecFetchSeq

echo "== gem5 O3 trace (PRESENT profile: PRF 192 / ROB 256 / 2.5 GHz) =="
"$GEM5" --debug-flags="$FLAGS" --debug-file=trace.out --outdir=m5out_present \
        configs/ooolyzer_se.py --binary "$ELF"
python3 ooolyzer/ooolyzer.py --trace m5out_present/trace.out --stats
python3 ooolyzer/ooolyzer.py --trace m5out_present/trace.out \
        --config configs/present.json --json present_ril.json --top 30
python3 ooolyzer/ooolyzer.py --trace m5out_present/trace.out \
        --config configs/present.json --filter-conflicts --json present_conflicts.json --top 40
echo "== in-order negative control =="
"$GEM5" --debug-flags=Rename,FreeList,Exec,ExecFetchSeq,Commit \
        --debug-file=trace_inorder.out --outdir=m5out_present_inorder \
        configs/ooolyzer_se.py --binary "$ELF" --inorder
python3 ooolyzer/ooolyzer.py --trace m5out_present_inorder/trace_inorder.out \
        --config configs/present.json --filter-conflicts --top 10 || true

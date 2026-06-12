#!/usr/bin/env bash

set -euo pipefail
cd "$(dirname "$0")"
GEM5=build/RISCV/gem5.opt
ELF="${1:-../riscv_codes/toffoli32.elf}"
FLAGS=Rename,FreeList,IEW,Commit,IQ,LSQ,Scoreboard,Writeback,Exec,ExecFetchSeq

echo "== gem5 O3 trace (Case Study 1 stress profile: PRF 36 / ROB 64 / 2 GHz) =="
"$GEM5" --debug-flags="$FLAGS" --debug-file=trace.out --outdir=m5out_toffoli \
        configs/ooolyzer_se.py --binary "$ELF" --prf 36 --rob 64 --iq 16 --clk 2GHz

echo "== parse sanity =="
python3 ooolyzer/ooolyzer.py --trace m5out_toffoli/trace.out --stats
echo "== full RIL report =="
python3 ooolyzer/ooolyzer.py --trace m5out_toffoli/trace.out \
        --config configs/toffoli.json --json toffoli_ril.json --top 20
echo "== complementary-share pairs only (expect c_s0<->c_s1 = x12<->x15) =="
python3 ooolyzer/ooolyzer.py --trace m5out_toffoli/trace.out \
        --config configs/toffoli.json --filter-conflicts --json toffoli_conflicts.json --top 20
echo "== in-order negative control =="
"$GEM5" --debug-flags=Rename,FreeList,Exec,ExecFetchSeq,Commit \
        --debug-file=trace_inorder.out --outdir=m5out_toffoli_inorder \
        configs/ooolyzer_se.py --binary "$ELF" --inorder
python3 ooolyzer/ooolyzer.py --trace m5out_toffoli_inorder/trace_inorder.out \
        --config configs/toffoli.json --filter-conflicts --top 10 || true

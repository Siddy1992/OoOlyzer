#!/usr/bin/env bash
# OoOLyzer artifact -- REPLAY (no gem5 required).
# Runs the OoOLyzer analysis on the pre-generated, bundled traces.
# Requirements: python3 only (stdlib: argparse, json, re, gzip).
set -euo pipefail
cd "$(dirname "$0")"
OOO=tools/ooolyzer.py
T=traces
C=configs

echo "######################################################################"
echo "# 0) self-tests (no trace needed)                                    #"
echo "######################################################################"
python3 "$OOO" --selftest
echo

echo "######################################################################"
echo "# 1) PRESENT  -- RIL key-recovery channel (Sec 4.3-4.7)              #"
echo "######################################################################"
echo "--- O3: complementary-share conflicts (the exploitable channel) ---"
python3 "$OOO" --trace "$T/present_o3.out.gz" --config "$C/present.json" \
        --filter-conflicts --json present_conflicts.json --top 40
echo "--- in-order control: RIL conflicts should vanish (rename stream empty) ---"
python3 "$OOO" --trace "$T/present_inorder.out.gz" --config "$C/present.json" \
        --filter-conflicts --top 10 || true
echo

echo "######################################################################"
echo "# 2) TOFFOLI -- RIL known-answer (complementary shares -> HD = 32)   #"
echo "######################################################################"
python3 "$OOO" --trace "$T/toffoli_o3.out.gz" --config "$C/toffoli.json" \
        --filter-conflicts --json toffoli_conflicts.json --top 20
echo "--- in-order control ---"
python3 "$OOO" --trace "$T/toffoli_inorder.out.gz" --config "$C/toffoli.json" \
        --filter-conflicts --top 10 || true
echo

echo "######################################################################"
echo "# 3) PINI -- IEW-Induced Dispatch Leakage (Sec 4.8 / App A.4)        #"
echo "######################################################################"
echo "--- O3: cross-domain co-residency on the d=3 HPC2 gadget ---"
python3 "$OOO" --mode iew --trace "$T/pini_o3.out.gz" --config "$C/pini_iew_d3.json" \
        --json pini_iew.json
echo "--- in-order control: co-residency + inversions should drop to 0 ---"
python3 "$OOO" --mode iew --trace "$T/pini_inorder.out.gz" --config "$C/pini_iew_d3.json" \
        --json pini_iew_inorder.json || true
echo
echo "Done. JSON outputs written to this directory. See README.md for expected numbers."

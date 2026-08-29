#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRACE="$ROOT/01_traces_and_results/full_present80_temp_trace.txt"
REPORT="$ROOT/01_traces_and_results/final_full_present80_recovery.txt"
TARGETS="$ROOT/01_traces_and_results/extra_targets.txt"
VICTIM="$ROOT/02_experiment/bin/victim_full_present80_temp_p550"
RECOVER="$ROOT/03_analysis/recover_full_present80_temp.py"

BASELINE_PASSES="${BASELINE_PASSES:-1}"
ADAPTIVE_ROUNDS="${ADAPTIVE_ROUNDS:-3}"
ADAPTIVE_PASSES_PER_ROUND="${ADAPTIVE_PASSES_PER_ROUND:-2}"
CPU="${CPU:-0}"

mkdir -p "$ROOT/01_traces_and_results"
rm -f "$TRACE" "$REPORT" "$TARGETS"

echo "# bitpos rep ref0 ref1 secret expected" | tee "$TRACE"
echo "[+] Starting baseline full 80-bit collection"

for pass in $(seq 1 "$BASELINE_PASSES"); do
    echo "# BASELINE PASS $pass" | tee -a "$TRACE"
    for b in $(seq 79 -1 0); do
        echo "[+] Baseline bitpos $b pass $pass"
        echo "# Baseline bitpos $b pass $pass" | tee -a "$TRACE"
        taskset -c "$CPU" "$VICTIM" "$b" | tee -a "$TRACE"
        echo "# Cooling after bitpos $b" | tee -a "$TRACE"
        sleep 45
    done
    echo "# Long cooling after baseline pass $pass" | tee -a "$TRACE"
    sleep 180
done

for round in $(seq 1 "$ADAPTIVE_ROUNDS"); do
    echo "[+] Recovery analysis before adaptive round $round"
    python3 "$RECOVER" --trace "$TRACE" --targets "$TARGETS" | tee "$REPORT"

    if [ ! -s "$TARGETS" ]; then
        echo "[+] No extra targets found. Stopping."
        break
    fi

    echo "[+] Adaptive round $round targets:"
    cat "$TARGETS"

    for pass in $(seq 1 "$ADAPTIVE_PASSES_PER_ROUND"); do
        echo "# ADAPTIVE ROUND $round PASS $pass" | tee -a "$TRACE"
        while read -r b; do
            [ -z "$b" ] && continue
            echo "[+] Adaptive round $round pass $pass bitpos $b"
            echo "# Adaptive round $round pass $pass bitpos $b" | tee -a "$TRACE"
            taskset -c "$CPU" "$VICTIM" "$b" | tee -a "$TRACE"
            echo "# Cooling after adaptive bitpos $b" | tee -a "$TRACE"
            sleep 75
        done < "$TARGETS"
        echo "# Long cooling after adaptive round $round pass $pass" | tee -a "$TRACE"
        sleep 240
    done
done

echo "[+] Final recovery"
python3 "$RECOVER" --trace "$TRACE" --targets "$TARGETS" | tee "$REPORT"
echo "[+] Trace : $TRACE"
echo "[+] Report: $REPORT"

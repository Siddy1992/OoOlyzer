#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRACE="$ROOT/01_traces_and_results/full_present80_temp_trace.txt"
TARGETS="$ROOT/01_traces_and_results/extra_targets.txt"
VICTIM="$ROOT/02_experiment/bin/victim_full_present80_temp_p550"
PASSES="${PASSES:-3}"
CPU="${CPU:-0}"

if [ ! -f "$TARGETS" ]; then
    echo "$TARGETS missing. Run recovery first."
    exit 1
fi

for pass in $(seq 1 "$PASSES"); do
    echo "# EXTRA PASS $pass" | tee -a "$TRACE"
    while read -r b; do
        [ -z "$b" ] && continue
        echo "# EXTRA measuring bitpos $b pass $pass" | tee -a "$TRACE"
        taskset -c "$CPU" "$VICTIM" "$b" | tee -a "$TRACE"
        echo "# Cooling after bitpos $b pass $pass" | tee -a "$TRACE"
        sleep 75
    done < "$TARGETS"
    echo "# Long cooling after extra pass $pass" | tee -a "$TRACE"
    sleep 240
done

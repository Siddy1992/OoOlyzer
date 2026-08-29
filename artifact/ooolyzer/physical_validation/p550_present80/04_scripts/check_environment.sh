#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

T1=/sys/devices/platform/soc/50b00000.pvt/hwmon/hwmon1/temp1_input
T2=/sys/devices/platform/soc/52360000.pvt/hwmon/hwmon2/temp1_input

echo "== Host =="
uname -a || true
printf 'Architecture: '; uname -m || true
printf 'GCC: '; gcc --version | head -n1 || true
printf 'Python: '; python3 --version || true
printf 'taskset: '; command -v taskset || true

echo
echo "== Temperature sensors expected by the harness =="
for p in "$T1" "$T2"; do
    if [ -r "$p" ]; then
        echo "[OK] $p -> $(cat "$p")"
    else
        echo "[MISSING/UNREADABLE] $p"
    fi
done

echo
echo "== Prebuilt binary =="
file "$ROOT/02_experiment/bin/victim_full_present80_temp_p550" || true

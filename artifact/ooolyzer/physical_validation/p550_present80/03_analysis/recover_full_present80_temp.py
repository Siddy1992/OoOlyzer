#!/usr/bin/env python3
from collections import defaultdict
from pathlib import Path
import argparse

ROOT = Path(__file__).resolve().parents[1]

parser = argparse.ArgumentParser(description="Recover PRESENT-80 bits from P550 temperature trace")
parser.add_argument("--trace", type=Path, default=ROOT / "01_traces_and_results" / "full_present80_temp_trace.txt")
parser.add_argument("--targets", type=Path, default=ROOT / "01_traces_and_results" / "extra_targets.txt")
args = parser.parse_args()

TRACE = args.trace
TARGET_FILE = args.targets
TARGET_FILE.parent.mkdir(parents=True, exist_ok=True)

rows = defaultdict(list)
expected_bits = {}

with TRACE.open() as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        p = line.split()
        if len(p) != 6:
            continue

        bitpos = int(p[0])
        ref0 = float(p[2])
        ref1 = float(p[3])
        sec  = float(p[4])
        exp  = int(p[5])

        rows[bitpos].append((ref0, ref1, sec))
        expected_bits[bitpos] = exp

def median(v):
    v = sorted(v)
    n = len(v)
    if n == 0:
        return 0.0
    return v[n//2] if n % 2 else 0.5 * (v[n//2 - 1] + v[n//2])

def trimmed(v, frac=0.25):
    v = sorted(v)
    n = len(v)
    k = int(n * frac)
    if n - 2*k >= 9:
        return v[k:n-k]
    return v

recovered = {}
confidence = {}
failed = []

print("bitpos n used med0 med1 meds sep d0 d1 rec exp ok conf")
print("----------------------------------------------------------------------------")

for bitpos in sorted(rows.keys(), reverse=True):
    raw = rows[bitpos]

    filt = [x for x in raw if abs(x[1] - x[0]) >= 0.04]
    if len(filt) < max(10, len(raw)//3):
        filt = raw

    m0 = median(trimmed([x[0] for x in filt]))
    m1 = median(trimmed([x[1] for x in filt]))
    ms = median(trimmed([x[2] for x in filt]))

    sep = abs(m1 - m0)
    d0 = abs(ms - m0)
    d1 = abs(ms - m1)

    rec = 1 if d1 < d0 else 0
    exp = expected_bits.get(bitpos, 0)
    conf = abs(d0 - d1)

    recovered[bitpos] = rec
    confidence[bitpos] = conf

    ok = "OK" if rec == exp else "FAIL"
    if rec != exp:
        failed.append(bitpos)

    print(f"{bitpos:6d} {len(raw):3d} {len(filt):4d} "
          f"{m0:6.3f} {m1:6.3f} {ms:6.3f} "
          f"{sep:5.3f} {d0:6.3f} {d1:6.3f} "
          f"{rec:3d} {exp:3d} {ok:4s} {conf:6.3f}")

rec_key = [0] * 10
exp_key = [0] * 10
correct = 0
total = 0

for bitpos in range(80):
    rec = recovered.get(bitpos, 0)
    exp = expected_bits.get(bitpos, 0)

    byte_index = 9 - (bitpos // 8)
    bit_index = bitpos % 8

    if rec:
        rec_key[byte_index] |= (1 << bit_index)
    if exp:
        exp_key[byte_index] |= (1 << bit_index)

    if bitpos in recovered:
        total += 1
        if rec == exp:
            correct += 1

print("----------------------------------------------------------------------------")
print("Recovered key:", "".join(f"{x:02X}" for x in rec_key))
print("Expected key :", "".join(f"{x:02X}" for x in exp_key))
print(f"Correct bits : {correct}/{total}")
print("Failed bit positions:", failed)

# Limit each adaptive round to the 30 most urgent bits:
# failed first, then low confidence.
priority = []

for b in failed:
    priority.append((0, confidence.get(b, 0.0), b))

for b, conf in confidence.items():
    if b not in failed and conf < 0.035:
        priority.append((1, conf, b))

priority = sorted(priority, key=lambda x: (x[0], x[1]))
targets = [b for _, _, b in priority[:30]]

with TARGET_FILE.open("w") as f:
    for b in targets:
        f.write(str(b) + "\n")

print("Next adaptive targets:", targets)
print("Written:", TARGET_FILE)

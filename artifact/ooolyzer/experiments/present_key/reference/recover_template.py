#!/usr/bin/env python3
import csv
import math
from collections import defaultdict

META = "template_meta.csv"
LEAK = "gem5_physreg_leak.csv"

secret_key = None
meta = {}

with open(META) as f:
    for line in f:
        line = line.strip()

        if not line:
            continue

        if line.startswith("# secret_key="):
            secret_key = line.split("=")[1].strip()
            continue

        if line.startswith("row_id"):
            continue

        p = line.split(",")

        row_id = int(p[0])
        meta[row_id] = {
            "nib": int(p[1]),
            "mode": int(p[2]),
            "guess": int(p[3]),
            "var": int(p[4]),
            "rep": int(p[5]),
            "pt": p[6],
        }

profiles = defaultdict(list)

with open(LEAK) as f:
    r = csv.DictReader(f)

    for row in r:
        row_id = int(row["row_id"])

        if row_id not in meta:
            continue

        m = meta[row_id]

        leaks = [
            float(row["leak1"]),
            float(row["leak2"]),
            float(row["leak3"]),
            float(row["leak4"]),
        ]

        profiles[(m["nib"], m["mode"], m["guess"], m["var"])].append(leaks)

def mean_vec(vs):
    if not vs:
        return [0.0, 0.0, 0.0, 0.0]

    out = [0.0, 0.0, 0.0, 0.0]

    for v in vs:
        for i in range(4):
            out[i] += v[i]

    return [x / len(vs) for x in out]

def dist_profile(nib, guess):
    d = 0.0

    for var in range(16):
        sec = mean_vec(profiles[(nib, 0, -1, var)])
        ref = mean_vec(profiles[(nib, 1, guess, var)])

        for i in range(4):
            diff = sec[i] - ref[i]
            d += diff * diff

    return math.sqrt(d)

recovered = []

print("nibble best_key distance second_key second_distance confidence expected")
print("-----------------------------------------------------------------------")

for nib in range(16):
    scores = []

    for guess in range(16):
        d = dist_profile(nib, guess)
        scores.append((d, guess))

    scores.sort()

    best_d, best_g = scores[0]
    second_d, second_g = scores[1]

    recovered.append(best_g)

    exp = "NA"
    if secret_key:
        exp = secret_key[:16][nib]

    print(
        f"{nib:6d} {best_g:8X} {best_d:10.5f} "
        f"{second_g:10X} {second_d:15.5f} "
        f"{second_d - best_d:10.5f} {exp}"
    )

rec_key = "".join(f"{x:X}" for x in recovered)

print("-----------------------------------------------------------------------")
print("Recovered first-round key:", rec_key)

if secret_key:
    exp_key = secret_key[:16]
    print("Expected  first-round key:", exp_key)

    ok = sum(a.upper() == b.upper() for a, b in zip(rec_key, exp_key))
    print(f"Correct nibbles: {ok}/16")


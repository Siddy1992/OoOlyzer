#!/usr/bin/env python3
import argparse
import csv
import json
import math
from collections import defaultdict


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--meta', required=True)
    p.add_argument('--leak', required=True)
    p.add_argument('--json')
    a = p.parse_args()

    secret_key = None
    meta = {}
    with open(a.meta) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith('# secret_key='):
                secret_key = line.split('=', 1)[1].strip()
                continue
            if line.startswith('row_id'):
                continue
            q = line.split(',')
            meta[int(q[0])] = {
                'nib': int(q[1]), 'mode': int(q[2]), 'guess': int(q[3]),
                'var': int(q[4]), 'rep': int(q[5]), 'pt': q[6]
            }

    profiles = defaultdict(list)
    with open(a.leak) as f:
        for row in csv.DictReader(f):
            rid = int(row['row_id'])
            if rid not in meta:
                continue
            m = meta[rid]
            v = [float(row[f'leak{i}']) for i in range(1, 5)]
            profiles[(m['nib'], m['mode'], m['guess'], m['var'])].append(v)

    def mean_vec(vs):
        if not vs:
            return [0.0] * 4
        return [sum(x[i] for x in vs) / len(vs) for i in range(4)]

    def distance(nib, guess):
        d = 0.0
        for var in range(16):
            sec = mean_vec(profiles[(nib, 0, -1, var)])
            ref = mean_vec(profiles[(nib, 1, guess, var)])
            for i in range(4):
                z = sec[i] - ref[i]
                d += z * z
        return math.sqrt(d)

    recovered = []
    details = []
    print('nibble best_key distance second_key second_distance confidence expected')
    print('-----------------------------------------------------------------------')
    for nib in range(16):
        scores = sorted((distance(nib, g), g) for g in range(16))
        best_d, best_g = scores[0]
        second_d, second_g = scores[1]
        recovered.append(best_g)
        exp = secret_key[:16][nib] if secret_key else 'NA'
        details.append({
            'nibble': nib, 'best_key': best_g, 'distance': best_d,
            'second_key': second_g, 'second_distance': second_d,
            'confidence': second_d - best_d, 'expected': exp,
        })
        print(f'{nib:6d} {best_g:8X} {best_d:10.5f} {second_g:10X} '
              f'{second_d:15.5f} {second_d-best_d:10.5f} {exp}')

    rec_key = ''.join(f'{x:X}' for x in recovered)
    print('-----------------------------------------------------------------------')
    print('Recovered first-round key:', rec_key)
    expected = secret_key[:16] if secret_key else None
    ok = None
    if expected:
        matches = sum(a.upper() == b.upper() for a, b in zip(rec_key, expected))
        ok = matches == 16
        print('Expected  first-round key:', expected)
        print(f'Correct nibbles: {matches}/16')

    result = {'recovered_first_round_key': rec_key, 'expected_first_round_key': expected,
              'match': ok, 'nibbles': details}
    if a.json:
        with open(a.json, 'w') as f:
            json.dump(result, f, indent=2)
    if ok is False:
        raise SystemExit(1)


if __name__ == '__main__':
    main()

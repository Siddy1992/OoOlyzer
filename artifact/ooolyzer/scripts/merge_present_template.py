#!/usr/bin/env python3
import argparse
import csv
from pathlib import Path


def merge_file(src, writer, offset):
    with open(src) as f:
        r = csv.DictReader(f)
        for row in r:
            row['row_id'] = str(int(row['row_id']) + offset)
            writer.writerow([row[k] for k in r.fieldnames])


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--root', required=True)
    p.add_argument('--out', required=True)
    a = p.parse_args()
    root = Path(a.root)
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)

    secret = None
    meta_out = out / 'template_meta.csv'
    leak_out = out / 'gem5_physreg_leak.csv'
    event_out = out / 'gem5_physreg_events.csv'

    with open(meta_out, 'w', newline='') as mf, open(leak_out, 'w', newline='') as lf, open(event_out, 'w', newline='') as ef:
        mw = csv.writer(mf)
        lw = csv.writer(lf)
        ew = csv.writer(ef)
        mw.writerow(['row_id','target_nibble','mode','key_guess','var_nibble','rep','pt'])
        lw.writerow(['row_id','leak1','leak2','leak3','leak4','events','renames','writes','strict_pairs'])
        ew.writerow(['row_id','channel','phys','prev_arch','curr_arch','prev_val','curr_val','hd'])

        for nib in range(16):
            profiles = [('secret', 0)] + [(f'g{g:02x}', g + 1) for g in range(16)]
            for prof, pidx in profiles:
                d = root / f'nib{nib:02d}' / prof
                offset = nib * 100000 + pidx * 1000

                with open(d / 'template_meta.csv') as f:
                    for line in f:
                        line = line.strip()
                        if line.startswith('# secret_key='):
                            key = line.split('=', 1)[1]
                            if secret is None:
                                secret = key
                            elif secret != key:
                                raise SystemExit('inconsistent secret key metadata')
                            continue
                        if not line or line.startswith('row_id'):
                            continue
                        row = next(csv.reader([line]))
                        row[0] = str(int(row[0]) + offset)
                        mw.writerow(row)

                merge_file(d / 'gem5_physreg_leak.csv', lw, offset)
                merge_file(d / 'gem5_physreg_events.csv', ew, offset)

    if secret:
        text = meta_out.read_text()
        meta_out.write_text(f'# secret_key={secret}\n' + text)
    print(meta_out)
    print(leak_out)


if __name__ == '__main__':
    main()

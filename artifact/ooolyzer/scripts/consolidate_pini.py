#!/usr/bin/env python3
import csv,json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
out=root/'results'/'pini'/'basic_prf_sweep.csv'
rows=[]
for d in sorted((root/'results'/'pini').glob('prf*'), key=lambda p:int(p.name[3:])):
    p=int(d.name[3:])
    s={m:json.load(open(d/f'm{m}_summary.json')) for m in (1,2,3)}
    rows.append({
        'prf':p,
        'm1_local':s[1]['local_violations'],
        'm2_cross':s[2]['cross_composition_violations'],
        'm3_cross':s[3]['cross_composition_violations'],
        'm3_prf_hd1':s[3]['prf_hd1_violation_rows']
    })
out.parent.mkdir(parents=True,exist_ok=True)
with open(out,'w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=['prf','m1_local','m2_cross','m3_cross','m3_prf_hd1'])
    w.writeheader(); w.writerows(rows)
print(out)

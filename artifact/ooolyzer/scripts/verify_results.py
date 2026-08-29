#!/usr/bin/env python3
import argparse,csv,json,math,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]

def load_json(p):
    return json.load(open(p))

def pair_map(data):
    return {'-'.join(map(str,r['arch_pair'])):r for r in data.get('dominant_pairs',[])}

def close(a,b,tol=0.015):
    return abs(float(a)-float(b)) <= tol

def check_present():
    cfg=load_json(root/'configs'/'present.json')['expected']
    full=load_json(root/'results'/'present'/'present_ril.json')
    conf=load_json(root/'results'/'present'/'present_conflicts.json')
    ok=True
    if len(full['candidates']) != cfg['strict_candidates']:
        print('present strict candidates:',len(full['candidates']),'expected',cfg['strict_candidates']); ok=False
    if len(conf['candidates']) != cfg['conflict_candidates']:
        print('present conflict candidates:',len(conf['candidates']),'expected',cfg['conflict_candidates']); ok=False
    loose_path=root/'results'/'present'/'present_loose.json'
    if loose_path.exists() and len(load_json(loose_path)['candidates']) != cfg['loose_candidates']:
        print('present loose candidates:',len(load_json(loose_path)['candidates']),'expected',cfg['loose_candidates']); ok=False
    rep=cfg.get('representative',{})
    if rep:
        found=False
        for c in conf['candidates']:
            if c['phys']==rep['phys'] and c['arch_old']==rep['arch_old'] and c['arch_new']==rep['arch_new'] and c['hd']==rep['hd'] and c['val_old']==int(rep['val_old'],16) and c['val_new']==int(rep['val_new'],16):
                found=True; break
        if not found:
            print('present representative P74 event not found'); ok=False
    got=pair_map(conf)
    for key,exp in cfg['channels'].items():
        r=got.get(key)
        if not r:
            print('present missing pair',key); ok=False; continue
        if r['count']!=exp['count'] or r['hd_max']!=exp['hd_max'] or not close(r['hd_mean'],exp['hd_mean']):
            print('present pair',key,'got',r,'expected',exp); ok=False
    ip=root/'results'/'present'/'present_inorder.json'
    if ip.exists() and len(load_json(ip).get('candidates',[])) != cfg['inorder_conflicts']:
        print('present in-order conflict count mismatch'); ok=False
    return ok

def check_toffoli():
    cfg=load_json(root/'configs'/'toffoli.json')['expected']
    conf=load_json(root/'results'/'toffoli'/'toffoli_conflicts.json')
    got=pair_map(conf); ok=True
    for key,exp in cfg['channels'].items():
        r=got.get(key)
        if not r:
            print('toffoli missing pair',key); ok=False; continue
        if r['count']!=exp['count'] or r['hd_max']!=exp['hd_max'] or not close(r['hd_mean'],exp['hd_mean']):
            print('toffoli pair',key,'got',r,'expected',exp); ok=False
    ip=root/'results'/'toffoli'/'toffoli_inorder.json'
    if ip.exists() and len(load_json(ip).get('candidates',[])) != cfg['inorder_conflicts']:
        print('toffoli in-order conflict count mismatch'); ok=False
    return ok


def check_present_key():
    path=root/'results'/'present_key'/'recovery.json'
    if not path.exists():
        print('present-key result missing'); return False
    got=load_json(path)
    exp=load_json(root/'results'/'reference'/'present_key.json')
    if got.get('recovered_first_round_key') != exp['first_round_key']:
        print('present-key recovered',got.get('recovered_first_round_key'),'expected',exp['first_round_key']); return False
    return bool(got.get('match'))

def check_pini_baseline():
    exp=load_json(root/'configs'/'pini.json')['expected_baseline']; ok=True
    for m in ('1','2','3'):
        got=load_json(root/'results'/'pini'/'prf36'/f'm{m}_summary.json')
        for k,v in exp[m].items():
            if got.get(k)!=v:
                print('pini M'+m,k,'got',got.get(k),'expected',v); ok=False
    return ok

def check_pini_sweep():
    ref=list(csv.DictReader(open(root/'results'/'reference'/'pini_prf_sweep.csv')))
    got=list(csv.DictReader(open(root/'results'/'pini'/'basic_prf_sweep.csv')))
    return ref==got

p=argparse.ArgumentParser(); p.add_argument('--case',required=True,choices=['present','toffoli','present-key','pini-baseline','pini-sweep']); a=p.parse_args()
fn={'present':check_present,'toffoli':check_toffoli,'present-key':check_present_key,'pini-baseline':check_pini_baseline,'pini-sweep':check_pini_sweep}[a.case]
ok=fn()
print(a.case+':', 'match' if ok else 'mismatch')
sys.exit(0 if ok else 1)

#!/usr/bin/env python3
from __future__ import annotations
import argparse,bisect,csv,itertools,json,math,re,subprocess
from collections import Counter,defaultdict
from dataclasses import dataclass,field
from pathlib import Path
from typing import *
from pini_model import model_info

REN_PROCESS_RE=re.compile(r'Processing instruction \[sn:(\d+)\].*?PC \((0x[0-9a-fA-F]+)',re.I)
REN_DEST_RE=re.compile(r'Renaming arch reg\s+(\d+)\s+\(([^)]+)\)\s+to physical reg\s+(\d+)',re.I)
EXEC_RE=re.compile(r'^\s*(\d+):.*?:\s*(0x[0-9a-fA-F]+)\s+@\S+.*?D=(0x[0-9a-fA-F]+)',re.I)
FETCH_RE=re.compile(r'(?:FetchSeq|CPSeq)=(\d+)')
COMMIT_RE=re.compile(r'^\s*(\d+):.*?\.commit.*?\[sn:(\d+)\]',re.I)

@dataclass
class Inst:
    sn:int; pc:int; arch:int; phys:int; tick:int; value:int; tag:tuple|None; tag_name:str|None
    iteration:int=-1

@dataclass
class Event:
    model:str; kind:str; members:list[Inst]; phys:int|None=None
    scope:str=''; boundary:str=''; trace_obs:int|None=None
    formal_status:str=''; min_support:str=''; valid_supports:str=''; witness:str=''
    static_count:int=0; mi_x_l:float=0.0; key_informative:bool=False


def nm_tags(elf,nm='riscv64-unknown-elf-nm'):
    out=subprocess.check_output([nm,'-n',elf],text=True,errors='replace')
    tags={}; names={}
    for ln in out.splitlines():
        p=ln.split()
        if len(p)<3: continue
        try: addr=int(p[0],16)
        except: continue
        name=p[-1]
        if name.startswith('PINI__'):
            t=parse_tag(name)
            if t: tags[addr]=t; names[addr]=name
    return tags,names

def parse_tag(name):
    p=name.split('__')
    if len(p)>=4 and p[0]=='PINI': return ('basic',p[1],p[2],'__'.join(p[3:]))
    return None

def parse_trace(path,tags,names,width=32):
    allocs=defaultdict(list); execs={}; commits=set(); stats=defaultdict(int); cur=None
    with open(path,'r',errors='replace') as f:
      for line in f:
        stats['lines']+=1
        if '.rename' in line:
          m=REN_PROCESS_RE.search(line)
          if m: cur=(int(m.group(1)),int(m.group(2),16)); stats['rename_proc']+=1; continue
          m=REN_DEST_RE.search(line)
          if m and cur:
            sn,pc=cur; arch=int(m.group(1)); cls=m.group(2); phys=int(m.group(3))
            if 'int' in cls.lower(): allocs[phys].append((sn,pc,arch)); stats['rename_dest']+=1
            cur=None
          continue
        if '.commit' in line:
          m=COMMIT_RE.search(line)
          if m: commits.add(int(m.group(2))); stats['commit']+=1
        if 'D=0x' in line:
          m=EXEC_RE.search(line); s=FETCH_RE.search(line)
          if m and s:
            execs[int(s.group(1))]=(int(m.group(1)),int(m.group(2),16),int(m.group(3),16)&((1<<width)-1)); stats['exec']+=1
    streams={}; tagged=[]
    for phys,lst in allocs.items():
      seq=[]
      for sn,pc,arch in lst:
        if sn not in execs or sn not in commits:
          seq.append(None); continue
        tick,epc,val=execs[sn]
        if epc!=pc: seq.append(None); stats['pc_mismatch']+=1; continue
        tg=tags.get(pc); nm=names.get(pc)
        ins=Inst(sn,pc,arch,phys,tick,val,tg,nm)
        seq.append(ins)
        if tg: tagged.append(ins)
      streams[phys]=seq
    return streams,tagged,stats

def assign_iterations(tagged,kind):
    anchor=('basic','G1','R','S01')
    anchors=sorted(x.sn for x in tagged if x.tag==anchor)
    if not anchors: raise RuntimeError(f'No anchor tag {anchor} found in committed trace')
    for x in tagged:
        x.iteration=bisect.bisect_right(anchors,x.sn)-1
    return len(anchors)

def stage_order(s):
    if s=='G1': return 0
    if s=='LIN': return 1 if s=='LIN' else 0
    if s=='G2': return 2
    if s.startswith('G') and s[1:].isdigit(): return int(s[1:])
    return 99

def scope_for(members,kind):
    st=[]
    for x in members:
      if x.tag: st.append(x.tag[1])
    u=[]
    for s in st:
      if s not in u: u.append(s)
    if len(u)<=1: return 'LOCAL',('LOCAL_'+u[0] if u else 'LOCAL')
    u=sorted(u,key=stage_order)
    return 'CROSS_COMPOSITION','BOUNDARY_'+'_'.join(u)

def detect_prf(streams,kind,keep_cross_iter=False):
    """Construct strict PRF_HD1 observations.

    `streams[p]` preserves every rename allocation position for physical
    register p; unavailable/squashed/unselected allocations are represented
    by None.  Zipping adjacent positions therefore accepts (old,new) only
    when there is NO intervening allocation to p.  This is stronger than
    merely requiring no intervening committed write and prevents a synthetic
    old->new transition across transient reuse.
    """
    ev=[]
    for p,seq in streams.items():
      for a,b in zip(seq,seq[1:]):
        if a is None or b is None or a.tag is None or b.tag is None: continue
        if a.arch==b.arch: continue
        if not keep_cross_iter and a.iteration!=b.iteration: continue
        e=Event('PRF_HD1','PRF_REUSE',[a,b],phys=p)
        e.trace_obs=(a.value^b.value)&1
        e.scope,e.boundary=scope_for([a,b],kind); ev.append(e)
    return ev

def detect_complete(tagged,kind,keep_cross_iter=False):
    g=defaultdict(list)
    for x in tagged: g[x.tick].append(x)
    ev=[]
    for tk,ms in g.items():
      if len(ms)<2: continue
      if not keep_cross_iter and len({x.iteration for x in ms})>1: continue
      e=Event('COMPLETE_SUM1','SAME_CYCLE_COMPLETE',sorted(ms,key=lambda x:x.sn))
      e.trace_obs=sum(x.value&1 for x in e.members)
      e.scope,e.boundary=scope_for(e.members,kind); ev.append(e)
    return ev

def key_of(x):
    if not x.tag:return None
    _,stage,dom,name=x.tag
    return (stage,dom,name)

def obs_signature(model,keys,sem):
    if model=='PRF_HD1': return sem[keys[0]]^sem[keys[1]]
    if model=='COMPLETE_SUM1': return sum(sem[k] for k in keys)
    raise ValueError(model)

def formal_type(kind,model,keys):
    INPUT,RAND,DOM,SEM=model_info(kind)
    supports=[(),('D0',),('D1',),('D0','D1')]
    seen=[{} for _ in supports]; witnesses={}
    valid=[True]*len(supports)
    # For each full input, calculate the full random-marginalized distribution once.
    for bits in itertools.product((0,1), repeat=len(INPUT)):
      inp=dict(zip(INPUT,bits)); cnt=Counter()
      for rbits in itertools.product((0,1), repeat=len(RAND)):
        rnd=dict(zip(RAND,rbits)); sem=SEM(inp,rnd)
        try: o=obs_signature(model,keys,sem)
        except KeyError as ex: return 'NO_MODEL','NONE','',f'missing semantic key {ex}'
        cnt[o]+=1
      sig=tuple(sorted(cnt.items(),key=lambda x:repr(x[0])))
      for i,sup in enumerate(supports):
        if not valid[i]: continue
        vars=[]
        for d in sup: vars.extend(DOM[d])
        k=tuple(inp[v] for v in vars)
        if k not in seen[i]: seen[i][k]=(sig,bits)
        elif seen[i][k][0]!=sig:
          valid[i]=False
          witnesses[sup]=(seen[i][k][1],bits,seen[i][k][0],sig)
    val=[supports[i] for i,v in enumerate(valid) if v]
    def lab(s): return '{}' if not s else '{'+','.join(s)+'}'
    mins=[]
    if val:
      m=min(map(len,val)); mins=[s for s in val if len(s)==m]
    status='PINI_COMPATIBLE' if any(len(s)<=1 for s in val) else 'PINI_VIOLATION'
    wit=''
    if status=='PINI_VIOLATION':
      wit='D0 fails='+repr(witnesses.get(('D0',),''))+' || D1 fails='+repr(witnesses.get(('D1',),''))
    return status,';'.join(lab(s) for s in mins),';'.join(lab(s) for s in val),wit

def type_id(e):
    return (e.model,tuple(key_of(x) for x in e.members))

def write_csv(path,rows,fields):
    with open(path,'w',newline='') as f:
      w=csv.DictWriter(f,fieldnames=fields); w.writeheader(); w.writerows(rows)

def run_pini_mode(a):
    kind=a.pini_kind
    tags,names=nm_tags(a.elf,a.nm)
    streams,tagged,stats=parse_trace(a.trace,tags,names,width=a.width)
    niter=assign_iterations(tagged,kind)
    lo=a.pini_skip_iters; hi=niter if a.pini_max_iters is None else min(niter,lo+a.pini_max_iters)
    keep=[x for x in tagged if lo<=x.iteration<hi]
    keep_sn={x.sn for x in keep}
    # Keep all stream positions so strict adjacency remains strict; non-selected entries become None.
    filt={p:[x if (x is not None and x.sn in keep_sn) else None for x in seq] for p,seq in streams.items()}
    events=detect_prf(filt,kind,a.pini_include_cross_iteration)
    if a.pini_complete: events+=detect_complete(keep,kind,a.pini_include_cross_iteration)
    groups=defaultdict(list)
    for e in events: groups[type_id(e)].append(e)
    formal_cache={}; mi_cache={}
    for tid,es in groups.items():
      if len(es)<a.pini_min_recurrence:
        for e in es: e.formal_status='BELOW_RECURRENCE'
        continue
      model,keys=tid
      formal_cache[tid]=formal_type(kind,model,keys)
      for e in es:
        e.formal_status,e.min_support,e.valid_supports,e.witness=formal_cache[tid]
        e.static_count=len(es)
    pref=Path(a.out_prefix); pref.parent.mkdir(parents=True,exist_ok=True)
    inst_rows=[]
    for x in sorted(keep,key=lambda q:q.sn):
      inst_rows.append(dict(iteration=x.iteration,sn=x.sn,pc=f'0x{x.pc:x}',arch=x.arch,phys=x.phys,tick=x.tick,value=x.value,tag=x.tag_name))
    write_csv(str(pref)+'_instructions.csv',inst_rows,['iteration','sn','pc','arch','phys','tick','value','tag'])
    evt_rows=[]
    for i,e in enumerate(events):
      ks=[key_of(x) for x in e.members]
      evt_rows.append(dict(event_id=f'E{i:06d}',model=e.model,kind=e.kind,scope=e.scope,boundary=e.boundary,phys='' if e.phys is None else e.phys,
        iteration_min=min(x.iteration for x in e.members),iteration_max=max(x.iteration for x in e.members),sn_old=e.members[0].sn,sn_new=e.members[-1].sn,
        tick_old=e.members[0].tick,tick_new=e.members[-1].tick,arch_old=e.members[0].arch,arch_new=e.members[-1].arch,
        tag_old=e.members[0].tag_name,tag_new=e.members[-1].tag_name,trace_obs=e.trace_obs,static_count=e.static_count,
        formal_status=e.formal_status,min_support=e.min_support,valid_supports=e.valid_supports,mi_x_l=f'{e.mi_x_l:.12g}',key_informative=int(e.key_informative),semantic_keys=repr(ks)))
    ef=str(pref)+'_events.csv'; write_csv(ef,evt_rows,list(evt_rows[0].keys()) if evt_rows else ['event_id'])
    vio=[r for r in evt_rows if r.get('formal_status')=='PINI_VIOLATION']
    write_csv(str(pref)+'_violations.csv',vio,list(evt_rows[0].keys()) if evt_rows else ['event_id'])
    type_rows=[]
    for tid,es in groups.items():
      model,keys=tid; f=formal_cache.get(tid,('BELOW_RECURRENCE','','',''))
      type_rows.append(dict(model=model,semantic_keys=repr(keys),count=len(es),scope=es[0].scope,boundary=es[0].boundary,
        formal_status=f[0],min_support=f[1],mi_x_l='0',key_informative=0,
        arch_distinct=int(any(e.members[0].arch!=e.members[-1].arch for e in es))))
    type_rows.sort(key=lambda r:(r['formal_status']!='PINI_VIOLATION',-r['count']))
    write_csv(str(pref)+'_types.csv',type_rows,list(type_rows[0].keys()) if type_rows else ['model'])
    violations=[e for e in events if e.formal_status=='PINI_VIOLATION']
    cross=[e for e in violations if e.scope=='CROSS_COMPOSITION']; local=[e for e in violations if e.scope=='LOCAL']
    prf=[e for e in violations if e.model=='PRF_HD1']; comp=[e for e in violations if e.model=='COMPLETE_SUM1']
    distinct_prf=[r for r in type_rows if r['model']=='PRF_HD1' and r['count']>=a.pini_min_recurrence]
    summ={
      'kind':kind,'static_tagged_pcs':sum(1 for t in tags.values() if t[0]==kind),'dynamic_iterations_seen':niter,'skip_iters':lo,'analyzed_iterations':max(0,hi-lo),
      'dynamic_tagged_insts':len(keep),'all_events':len(events),'formal_violations':len(violations),'cross_composition_violations':len(cross),'local_violations':len(local),
      'prf_hd1_violation_rows':len(prf),'complete_sum1_violation_rows':len(comp),'distinct_prf_transition_types':len(distinct_prf),
      'parse_stats':dict(stats)
    }
    Path(str(pref)+'_summary.json').write_text(json.dumps(summ,indent=2))
    lines=['=== OoOLyzer PINI Definition-5 analysis ===']+[f'{k}: {v}' for k,v in summ.items() if k!='parse_stats']
    Path(str(pref)+'_summary.txt').write_text('\n'.join(lines)+'\n')
    print('\n'.join(lines))
    return summ

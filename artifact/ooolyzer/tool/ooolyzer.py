#!/usr/bin/env python3
"""OoOLyzer trace analyzer for RISC-V gem5 O3 traces.

RIL uses JSON share maps for masked PRESENT and Toffoli.
PINI uses the controlled PINI1 workload and a JSON analysis configuration.
"""

import argparse
import json
import re
import sys
import gzip
from collections import defaultdict

from pini_ext import run_pini_mode
from present_template import run_present_template

# Trace parsing
RENAME_PROC_RE = re.compile(
    r'\[sn:(?P<sn>\d+)\].*?\bwith PC \((?P<pc>0x[0-9a-fA-F]+)', re.IGNORECASE)
RENAME_DEST_RE = re.compile(
    r'^\s*(?P<tick>\d+):.*?Renaming arch reg (?P<arch>\d+)\s*\((?P<cls>[^)]*)\)\s*'
    r'to physical reg (?P<phys>\d+)', re.IGNORECASE)
EXEC_VAL_RE = re.compile(
    r'^\s*(?P<tick>\d+):.*?:\s*(?P<pc>0x[0-9a-fA-F]+)\s+@\S+.*?'
    r'D=(?P<val>0x[0-9a-fA-F]+)', re.IGNORECASE)
FETCHSEQ_RE = re.compile(r'FetchSeq=(\d+)')
CPSEQ_RE = re.compile(r'CPSeq=(\d+)')

MARK_PREFIX = 0xC0DE0000
MARK_MASK = 0xFFFF0000
COMMIT_RE = re.compile(
    r'^\s*(?P<tick>\d+):.*?\.commit.*?\[sn:(?P<sn>\d+)\]', re.IGNORECASE)


def _open(path):
    if str(path).endswith(".gz"):
        return gzip.open(path,"rt",errors="replace")
    return open(path,"r",errors="replace")


def hd(a, b, width=32):
    return bin((a ^ b) & ((1 << width) - 1)).count("1")


def lane_diffs(a, b, width=32):
    x = (a ^ b) & ((1 << width) - 1)
    return [i for i in range(width) if (x >> i) & 1]


def parse_trace(path, int_only=True):
    """allocs: phys -> [ {sn,arch,pc} ] in rename (allocation) order;
       exec_vals: sn -> (tick, pc, value)."""
    allocs = defaultdict(list)
    exec_vals = {}
    stats = {"lines": 0, "rename_proc": 0, "rename_dest": 0, "exec": 0,
             "used_fetchseq": 0, "used_cpseq": 0}
    cur_sn, cur_pc = None, None
    with _open(path) as fh:
        for line in fh:
            stats["lines"] += 1
            if ".rename" in line:
                m = RENAME_PROC_RE.search(line)
                if m:
                    stats["rename_proc"] += 1
                    cur_sn, cur_pc = int(m.group("sn")), m.group("pc")
                    continue
                m = RENAME_DEST_RE.search(line)
                if m:
                    if int_only and "int" not in m.group("cls").lower():
                        continue
                    if cur_sn is not None:
                        stats["rename_dest"] += 1
                        allocs[int(m.group("phys"))].append(
                            {"sn": cur_sn, "arch": int(m.group("arch")),
                             "pc": cur_pc})
                        cur_sn = None
                continue
            if "D=0x" in line:
                m = EXEC_VAL_RE.search(line)
                if not m:
                    continue
                fs = FETCHSEQ_RE.search(line)
                cp = CPSEQ_RE.search(line)
                if fs:
                    sn = int(fs.group(1)); stats["used_fetchseq"] += 1
                elif cp:
                    sn = int(cp.group(1)); stats["used_cpseq"] += 1
                else:
                    continue
                stats["exec"] += 1
                exec_vals[sn] = (int(m.group("tick")), m.group("pc"),
                                 int(m.group("val"), 16))
    return allocs, exec_vals, stats


def build_streams(allocs, exec_vals, stats, width=32):
    """phys -> ordered list of allocation records, each:
       {sn, arch, pc, committed, tick?, value?}."""
    stats["joined"] = 0
    stats["pc_mismatch"] = 0
    stats["squashed_allocs"] = 0
    streams = {}
    for p, lst in allocs.items():
        seq = []
        for a in lst:
            sn = a["sn"]
            rec = {"sn": sn, "arch": a["arch"], "pc": a["pc"], "committed": False}
            if sn in exec_vals:
                etick, pc_e, val = exec_vals[sn]
                if pc_e == a["pc"]:
                    rec.update(committed=True, tick=etick,
                               value=val & ((1 << width) - 1))
                    stats["joined"] += 1
                else:
                    stats["pc_mismatch"] += 1
                    stats["squashed_allocs"] += 1
            else:
                stats["squashed_allocs"] += 1
            seq.append(rec)
        streams[p] = seq
    return streams


def detect_ril(streams, tau_max=None, min_hd=1, width=32, strict=True):
    """Allocation-anchored. STRICT: two committed writes must be consecutive
    allocations with no allocation (committed or squashed) between them."""
    cands = []
    for p, seq in streams.items():
        last = None          # index of previous committed allocation
        skipped = 0          # non-committed allocations seen since `last`
        for e in seq:
            if not e["committed"]:
                skipped += 1
                continue
            if last is not None:
                a, b = last, e
                interv = skipped
                if not (strict and interv > 0) and a["arch"] != b["arch"]:
                    dt = b["tick"] - a["tick"]
                    if tau_max is None or dt <= tau_max:
                        h = hd(a["value"], b["value"], width)
                        if h >= min_hd:
                            cands.append({
                                "phys": p, "hd": h, "dticks": dt,
                                "intervening": interv,
                                "arch_old": a["arch"], "arch_new": b["arch"],
                                "val_old": a["value"], "val_new": b["value"],
                                "pc_old": a["pc"], "pc_new": b["pc"],
                                "sn_old": a["sn"], "sn_new": b["sn"],
                                "lanes": lane_diffs(a["value"], b["value"], width)})
            last = e
            skipped = 0
    cands.sort(key=lambda c: (-c["hd"], c["dticks"]))
    return cands


def annotate(cands, config):
    if not config:
        return cands
    arch_map = {int(k): v for k, v in config.get("arch_map", {}).items()}
    conflicts = {frozenset(p) for p in config.get("conflicts", [])}
    reused = {int(k): v for k, v in config.get("reused_registers", {}).items()}
    labels = set(arch_map.values())
    for c in cands:
        lo = arch_map.get(c["arch_old"]) or reused.get(c["arch_old"])
        ln = arch_map.get(c["arch_new"]) or reused.get(c["arch_new"])
        c["label_old"], c["label_new"] = lo, ln
        c["is_configured_conflict"] = (lo in labels and ln in labels
                                       and frozenset((lo, ln)) in conflicts)
    return cands


def pair_summary(cands):
    agg = defaultdict(lambda: {"count": 0, "hd_sum": 0, "hd_max": 0})
    for c in cands:
        k = tuple(sorted((c["arch_old"], c["arch_new"])))
        a = agg[k]
        a["count"] += 1; a["hd_sum"] += c["hd"]; a["hd_max"] = max(a["hd_max"], c["hd"])
    rows = [{"arch_pair": k, **v, "hd_mean": v["hd_sum"] / v["count"]}
            for k, v in agg.items()]
    rows.sort(key=lambda r: (-r["hd_sum"], -r["hd_max"]))
    return rows


def report_text(cands, pairs, stats, mode, top=20):
    def lbl(c, w):
        x = c.get("label_" + w); return f"({x})" if x else ""
    print(f"enforcement: {mode}")
    print(f"parse: {stats['lines']} lines | rename proc {stats['rename_proc']} "
          f"dest {stats['rename_dest']} | exec {stats['exec']} | "
          f"committed-writes {stats['joined']} | "
          f"squashed/unjoined allocs {stats['squashed_allocs']} "
          f"(pc-mismatch {stats['pc_mismatch']})")
    if stats["rename_dest"] == 0 or stats["joined"] == 0:
        print("required trace stream is empty")
    print(f"\nRIL candidates: {len(cands)}")
    print("\nDominant arch-register pairs (by summed HD):")
    print(f"  {'pair':>14}  {'count':>6}  {'hd_max':>6}  {'hd_mean':>7}")
    for r in pairs[:top]:
        a, b = r["arch_pair"]
        print(f"  x{a:<5}-x{b:<6}  {r['count']:>6}  {r['hd_max']:>6}  {r['hd_mean']:>7.2f}")
    print(f"\nTop {top} candidates:")
    for c in cands[:top]:
        flag = " *CONFLICT*" if c.get("is_configured_conflict") else ""
        iv = "" if c["intervening"] == 0 else f" [+{c['intervening']} squashed between]"
        print(f"  P{c['phys']:<4} x{c['arch_old']}{lbl(c,'old')}->"
              f"x{c['arch_new']}{lbl(c,'new')} HD={c['hd']:>2} dt={c['dticks']:>7} "
              f"{c['val_old']:#010x}->{c['val_new']:#010x} {c['pc_old']}->{c['pc_new']}"
              f"{iv}{flag}")


def to_json(cands, pairs, stats, mode):
    return {"enforcement": mode, "stats": stats,
            "dominant_pairs": [{"arch_pair": list(r["arch_pair"]), "count": r["count"],
                                "hd_max": r["hd_max"], "hd_mean": r["hd_mean"]}
                               for r in pairs],
            "candidates": cands}


def parse_markers(path):
    """markers: id -> [ {sn,tick,pc} ] in trace order; commit_ticks: sn -> earliest."""
    markers = defaultdict(list)
    commit_ticks = {}
    stats = {"lines": 0, "exec": 0, "marker_hits": 0, "commit_lines": 0}
    with _open(path) as fh:
        for line in fh:
            stats["lines"] += 1
            if ".commit" in line:
                m = COMMIT_RE.search(line)
                if m:
                    stats["commit_lines"] += 1
                    sn = int(m.group("sn")); tk = int(m.group("tick"))
                    if sn not in commit_ticks or tk < commit_ticks[sn]:
                        commit_ticks[sn] = tk
                continue
            if "D=0x" in line:
                m = EXEC_VAL_RE.search(line)
                if not m:
                    continue
                stats["exec"] += 1
                val = int(m.group("val"), 16) & 0xFFFFFFFF
                if (val & MARK_MASK) != MARK_PREFIX:
                    continue
                mid = val & 0xFFFF
                if mid == 0:                       # lui half of the li / marker -- skip
                    continue
                fs = FETCHSEQ_RE.search(line) or CPSEQ_RE.search(line)
                if not fs:
                    continue
                stats["marker_hits"] += 1
                markers[mid].append({"sn": int(fs.group(1)),
                                     "tick": int(m.group("tick")),
                                     "pc": m.group("pc")})
    return markers, commit_ticks, stats


def resolve(markers, commit_ticks, name2id):
    out = {}
    for name, mid in name2id.items():
        recs = []
        for r in markers.get(mid, []):
            recs.append({"sn": r["sn"], "exec": r["tick"], "pc": r["pc"],
                         "commit": commit_ticks.get(r["sn"])})
        out[name] = recs
    return out


def detect_iew(resolved, pairs, delta=1):
    """For each (m1,m2) pair, zip occurrences in order; per instance test
       execution-order inversion (vs commit order) and [exec,commit] overlap."""
    cands = []
    for m1, m2 in pairs:
        a_list, b_list = resolved.get(m1, []), resolved.get(m2, [])
        for k in range(min(len(a_list), len(b_list))):
            a, b = a_list[k], b_list[k]
            ev = {"pair": (m1, m2), "iter": k,
                  "exec1": a["exec"], "exec2": b["exec"],
                  "commit1": a["commit"], "commit2": b["commit"],
                  "pc1": a["pc"], "pc2": b["pc"],
                  "inversion": False, "coresident": False, "overlap": 0}
            if a["commit"] is not None and b["commit"] is not None:
                prog_1_first = a["commit"] < b["commit"]
                exec_1_first = a["exec"] < b["exec"]
                if prog_1_first != exec_1_first:
                    ev["inversion"] = True
                    ev["note"] = (f"{m2} executed BEFORE {m1}"
                                  if b["exec"] < a["exec"]
                                  else f"{m1} executed BEFORE {m2}")
                lo = max(a["exec"], b["exec"])
                hi = min(a["commit"], b["commit"])
                ov = hi - lo
                if ov >= delta:
                    ev["coresident"] = True
                    ev["overlap"] = ov
            else:
                ev["note"] = (f"{m2} executed BEFORE {m1}"
                              if b["exec"] < a["exec"]
                              else f"{m1} executed BEFORE {m2}")
            cands.append(ev)
    cands.sort(key=lambda c: (not c["inversion"], -c["overlap"]))
    return cands


def report_iew(cands, stats, name2id):
    print("IEW report")
    print(f"parse: {stats['lines']} lines | exec {stats['exec']} | "
          f"marker hits {stats['marker_hits']} | commit lines {stats['commit_lines']}")
    if stats["marker_hits"] == 0:
        print("no markers found")
    if stats["commit_lines"] == 0:
        print("no commit records found")
    print(f"\nconfigured markers: {name2id}")
    print(f"IEW candidates: {len(cands)}")
    inv = [c for c in cands if c["inversion"]]
    cor = [c for c in cands if c["coresident"]]
    print(f'  execution-order inversions : {len(inv)}   ("final executed BEFORE contributor")')
    print(f"  co-residency overlaps      : {len(cor)}")
    print()
    for c in cands:
        flags = []
        if c["inversion"]:  flags.append("INVERSION")
        if c["coresident"]: flags.append(f"CORESIDENT(ov={c['overlap']})")
        flag = ("  *" + ",".join(flags) + "*") if flags else ""
        print(f"  it{c['iter']:<2} {c['pair'][0]:>5} vs {c['pair'][1]:<5} "
              f"exec=({c['exec1']},{c['exec2']}) commit=({c['commit1']},{c['commit2']})"
              f"  {c.get('note','')}{flag}")


def to_json_iew(cands, stats, name2id):
    return {"mode": "iew", "stats": stats, "markers": name2id,
            "candidates": [{**c, "pair": list(c["pair"])} for c in cands]}


SELFTEST_TRACE = """\
  72800: core.rename: [tid:0] Processing instruction [sn:10] with PC (0x1100=>0x1104).(0=>1).
  73000: core.rename: [tid:0] Renaming arch reg 20 (integer) to physical reg 137 (137).
  74000: core: T0 : 0x1100 @sbox+10  : and s4, s4, s2 : IntAlu :  D=0x0000000044444444  FetchSeq=10
  75000: core.rename: [tid:0] Processing instruction [sn:11] with PC (0x1180=>0x1184).(0=>1).
  75500: core.rename: [tid:0] Renaming arch reg 29 (integer) to physical reg 137 (137).
  76000: core: T0 : 0x1180 @sbox+90  : and t4, t4, t2 : IntAlu :  D=0x0000000022222222  FetchSeq=11
  77000: core.rename: [tid:0] Processing instruction [sn:12] with PC (0x1190=>0x1194).(0=>1).
  77500: core.rename: [tid:0] Renaming arch reg 19 (integer) to physical reg 200 (200).
  78000: core: T0 : 0x1190 @sbox+a0  : xor s3, s3, s5 : IntAlu :  D=0x000000000000000f  FetchSeq=12
  79000: core.rename: [tid:0] Processing instruction [sn:13] with PC (0x11a0=>0x11a4).(0=>1).
  79500: core.rename: [tid:0] Renaming arch reg 19 (integer) to physical reg 200 (200).
  80000: core: T0 : 0x11a0 @sbox+b0  : xor s3, s3, s5 : IntAlu :  D=0x00000000000000f0  FetchSeq=13
  81000: core.rename: [tid:0] Processing instruction [sn:20] with PC (0x1200=>0x1204).(0=>1).
  81100: core.rename: [tid:0] Renaming arch reg 20 (integer) to physical reg 60 (60).
  81200: core: T0 : 0x1200 @sbox : and s4,s4,s2 : IntAlu :  D=0x00000000ffffffff  FetchSeq=20
  81300: core.rename: [tid:0] Processing instruction [sn:21] with PC (0x1208=>0x120c).(0=>1).
  81400: core.rename: [tid:0] Renaming arch reg 7 (integer) to physical reg 60 (60).
  81600: core.rename: [tid:0] Processing instruction [sn:22] with PC (0x1210=>0x1214).(0=>1).
  81700: core.rename: [tid:0] Renaming arch reg 29 (integer) to physical reg 60 (60).
  81800: core: T0 : 0x1210 @sbox : and t4,t4,t2 : IntAlu :  D=0x0000000000000000  FetchSeq=22
"""


def selftest_ril():
    import tempfile, os
    fd, path = tempfile.mkstemp(suffix=".trace")
    os.write(fd, SELFTEST_TRACE.encode()); os.close(fd)
    allocs, ev, stats = parse_trace(path)
    os.unlink(path)
    streams = build_streams(allocs, ev, stats)
    cfg = {"arch_map": {"20": "avar0", "29": "avar1"},
           "conflicts": [["avar0", "avar1"]]}

    ok = True
    strict = annotate(detect_ril(streams, strict=True), cfg)
    r137 = [c for c in strict if c["phys"] == 137]
    if not (len(r137) == 1 and r137[0]["hd"] == 16
            and r137[0]["is_configured_conflict"] and r137[0]["intervening"] == 0):
        ok = False; print("FAIL P137:", r137)
    if any(c["phys"] == 200 for c in strict):
        ok = False; print("FAIL P200 same-arch flagged.")
    if any(c["phys"] == 60 for c in strict):
        ok = False; print("FAIL P60 strict should suppress:",
                          [c for c in strict if c['phys'] == 60])
    loose = annotate(detect_ril(streams, strict=False), cfg)
    r60 = [c for c in loose if c["phys"] == 60]
    if not (len(r60) == 1 and r60[0]["intervening"] == 1
            and r60[0]["is_configured_conflict"]):
        ok = False; print("FAIL P60 loose:", r60)

    print("RIL parse stats:", stats)
    print("RIL SELFTEST:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


SELFTEST_TRACE_IEW = """\
  110: core: T0 : 0x2004 @g+4  : addi s11,s11,1 : IntAlu : D=0x00000000c0de0001  FetchSeq=11
  120: core: T0 : 0x2024 @g+24 : addi s11,s11,-15 : IntAlu : D=0x00000000c0de00f0  FetchSeq=12
  130: core: T0 : 0x2044 @g+44 : addi s11,s11,16 : IntAlu : D=0x00000000c0de0010  FetchSeq=13
  140: core: T0 : 0x2064 @g+64 : addi s11,s11,-15 : IntAlu : D=0x00000000c0de00f1  FetchSeq=14
  200: core.commit: [tid:0] Committing instruction with [sn:11] PC (0x2004=>0x2008).
  205: core.commit: [tid:0] Committing instruction with [sn:13] PC (0x2044=>0x2048).
  210: core.commit: [tid:0] Committing instruction with [sn:12] PC (0x2024=>0x2028).
  215: core.commit: [tid:0] Committing instruction with [sn:14] PC (0x2064=>0x2068).
"""


def selftest_iew():
    import tempfile, os
    fd, path = tempfile.mkstemp(suffix=".trace")
    os.write(fd, SELFTEST_TRACE_IEW.encode()); os.close(fd)
    markers, commits, stats = parse_markers(path)
    os.unlink(path)
    name2id = {"z01": 1, "z10": 16, "f0": 240, "f1": 241}
    resolved = resolve(markers, commits, name2id)

    ok = True
    # commit order: z01(200), z10(205), f0(210), f1(215)
    # exec order:   z01(110), f0(120),  z10(130), f1(140)
    # pair (z10,f0): program z10(205) before f0(210), but f0 executed (120)
    #                before z10 (130) -> INVERSION + CO-RESIDENT.
    cands = detect_iew(resolved, [["z10", "f0"], ["z01", "f1"]], delta=1)
    c = next((x for x in cands if x["pair"] == ("z10", "f0")), None)
    if not (c and c["inversion"] and c["coresident"]):
        ok = False; print("FAIL z10/f0 inversion:", c)
    if c and "f0 executed BEFORE z10" not in c.get("note", ""):
        ok = False; print("FAIL z10/f0 direction:", c.get("note"))
    c2 = next((x for x in cands if x["pair"] == ("z01", "f1")), None)
    if c2 and c2["inversion"]:
        ok = False; print("FAIL z01/f1 should not invert:", c2)

    print("IEW parse stats:", stats)
    print("IEW SELFTEST:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


def selftest():
    r = selftest_ril()
    print()
    i = selftest_iew()
    print()
    both = (r == 0 and i == 0)
    print("COMBINED SELFTEST:", "PASS" if both else "FAIL")
    return 0 if both else 1


def run_ril(a, cfg):
    allocs, ev, stats = parse_trace(a.trace)
    streams = build_streams(allocs, ev, stats, width=a.width)
    if a.stats:
        print(json.dumps(stats, indent=2)); return None
    mode = "loose (no intervening committed write)" if a.loose \
        else "strict (no intervening allocation, incl. transient)"
    cands = annotate(detect_ril(streams, tau_max=a.tau_max, min_hd=a.min_hd,
                                width=a.width, strict=not a.loose), cfg)
    if a.filter_conflicts:
        cands = [c for c in cands if c.get("is_configured_conflict")]
    pairs = pair_summary(cands)
    report_text(cands, pairs, stats, mode, top=a.top)
    return to_json(cands, pairs, stats, mode)


def run_iew(a, cfg):
    if not cfg or "markers" not in cfg:
        sys.exit("IEW mode needs --config with a 'markers' map and 'pairs'.")
    name2id = {k: int(v) for k, v in cfg.get("markers", {}).items()}
    pairs = [tuple(p) for p in cfg.get("pairs", [])]
    delta = cfg.get("delta", a.delta)
    markers, commits, stats = parse_markers(a.trace)
    resolved = resolve(markers, commits, name2id)
    cands = detect_iew(resolved, pairs, delta=delta)
    report_iew(cands, stats, name2id)
    return to_json_iew(cands, stats, name2id)


def _cfg_value(cfg, section, key, default=None):
    x = cfg.get(section, {}) if cfg else {}
    return x.get(key, default)


def _apply_pini_config(a, cfg):
    x = cfg.get("analysis", {}) if cfg else {}
    a.pini_kind = x.get("kind", a.pini_kind)
    a.width = int(x.get("width", a.width))
    a.pini_skip_iters = int(x.get("skip_iters", a.pini_skip_iters))
    max_iters = x.get("max_iters", a.pini_max_iters)
    a.pini_max_iters = None if max_iters is None else int(max_iters)
    a.pini_min_recurrence = int(x.get("min_recurrence", a.pini_min_recurrence))
    if "complete" in x:
        a.pini_complete = bool(x["complete"])
    if "include_cross_iteration" in x:
        a.pini_include_cross_iteration = bool(x["include_cross_iteration"])


def main():
    ap = argparse.ArgumentParser(description="OoOLyzer trace analyzer")
    ap.add_argument("--mode", choices=["auto", "ril", "iew", "both", "pini", "present-template"], default="auto")
    ap.add_argument("--trace")
    ap.add_argument("--config")
    ap.add_argument("--json")
    ap.add_argument("--loose", action="store_true")
    ap.add_argument("--tau-max", type=int, default=None)
    ap.add_argument("--min-hd", type=int, default=1)
    ap.add_argument("--width", type=int, default=32)
    ap.add_argument("--filter-conflicts", action="store_true")
    ap.add_argument("--top", type=int, default=20)
    ap.add_argument("--stats", action="store_true")
    ap.add_argument("--delta", type=int, default=1)
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--elf")
    ap.add_argument("--nm", default="riscv64-unknown-elf-nm")
    ap.add_argument("--out-prefix", default="pini_ooolyzer")
    ap.add_argument("--pini-kind", choices=["basic"], default="basic")
    ap.add_argument("--pini-skip-iters", type=int, default=1)
    ap.add_argument("--pini-max-iters", type=int, default=None)
    ap.add_argument("--pini-min-recurrence", type=int, default=1)
    ap.add_argument("--pini-complete", action="store_true")
    ap.add_argument("--pini-include-cross-iteration", action="store_true")
    ap.add_argument("--row-csv")
    ap.add_argument("--event-csv")
    a = ap.parse_args()

    if a.selftest:
        return selftest()
    if not a.trace:
        ap.error("--trace is required")

    cfg = json.load(open(a.config)) if a.config else {}
    mode = a.mode
    if mode == "auto":
        mode = _cfg_value(cfg, "analysis", "mode", "ril")
    if mode not in ("ril", "iew", "both", "pini", "present-template"):
        ap.error(f"unsupported analysis mode: {mode}")

    if mode == "pini":
        _apply_pini_config(a, cfg)
        if not a.elf:
            ap.error("PINI analysis requires --elf")
        summary = run_pini_mode(a)
        if a.json:
            json.dump(summary, open(a.json, "w"), indent=2)
        return 0

    if mode == "present-template":
        run_present_template(a, cfg)
        return 0

    out = {}
    if mode in ("ril", "both"):
        j = run_ril(a, cfg)
        if j is not None:
            out["ril"] = j
    if mode in ("iew", "both"):
        if mode == "both":
            print()
        out["iew"] = run_iew(a, cfg)

    if a.json and out:
        payload = out if mode == "both" else next(iter(out.values()))
        json.dump(payload, open(a.json, "w"), indent=2)
    return 0


if __name__ == "__main__":
    sys.exit(main())

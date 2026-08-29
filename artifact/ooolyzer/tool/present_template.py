#!/usr/bin/env python3
import csv
import gzip
import json
import re
from collections import defaultdict

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


def _open(path):
    if str(path).endswith('.gz'):
        return gzip.open(path, 'rt', errors='replace')
    return open(path, 'r', errors='replace')


def _channel_map(cfg):
    out = {}
    channels = cfg.get('template', {}).get('channels', {})
    for name, pair in channels.items():
        ch = int(name[1:]) if name.upper().startswith('L') else int(name)
        a, b = int(pair[0]), int(pair[1])
        out[(a, b)] = ch
        out[(b, a)] = ch
    return out


def _marker_info(value, cfg):
    tcfg = cfg.get('template', {})
    width = int(tcfg.get('width', 32))
    value &= (1 << width) - 1
    mask = int(str(tcfg.get('marker_mask', '0xffff0000')), 0)
    row_mask = int(str(tcfg.get('row_mask', '0x0000ffff')), 0)
    start = int(str(tcfg.get('row_start', '0xca010000')), 0)
    end = int(str(tcfg.get('row_end', '0xca040000')), 0)
    tag = value & mask
    if tag == start:
        return 'start', value & row_mask
    if tag == end:
        return 'end', value & row_mask
    return None, None


def analyze_template(trace, cfg, row_csv=None, event_csv=None):
    tcfg = cfg.get('template', {})
    width = int(tcfg.get('width', 32))
    maskv = (1 << width) - 1
    cmap = _channel_map(cfg)

    current_arch = defaultdict(lambda: -1)
    last_arch = defaultdict(lambda: -1)
    last_value = defaultdict(int)
    has_last = defaultdict(bool)
    sn_dest = {}
    seen_writes = set()

    row_active = False
    current_row = None
    leak = [0, 0, 0, 0]
    event_count = 0
    rename_count = 0
    write_count = 0
    pair_count = 0

    rows = []
    events = []
    stats = {
        'lines': 0,
        'rename_proc': 0,
        'rename_dest': 0,
        'exec_dest': 0,
        'duplicate_exec': 0,
        'row_start': 0,
        'row_end': 0,
        'rows': 0,
    }

    cur_sn = None
    cur_pc = None

    def reset_row(row):
        nonlocal row_active, current_row, leak, event_count, rename_count, write_count, pair_count
        current_row = row
        leak = [0, 0, 0, 0]
        event_count = 0
        rename_count = 0
        write_count = 0
        pair_count = 0
        row_active = True

    def emit_row():
        nonlocal row_active
        rows.append({
            'row_id': current_row,
            'leak1': leak[0],
            'leak2': leak[1],
            'leak3': leak[2],
            'leak4': leak[3],
            'events': event_count,
            'renames': rename_count,
            'writes': write_count,
            'strict_pairs': pair_count,
        })
        row_active = False

    with _open(trace) as fh:
        for line in fh:
            stats['lines'] += 1

            if '.rename' in line:
                m = RENAME_PROC_RE.search(line)
                if m:
                    cur_sn = int(m.group('sn'))
                    cur_pc = m.group('pc')
                    stats['rename_proc'] += 1
                    continue

                m = RENAME_DEST_RE.search(line)
                if m:
                    if 'int' not in m.group('cls').lower():
                        continue
                    if cur_sn is None:
                        continue
                    arch = int(m.group('arch'))
                    phys = int(m.group('phys'))
                    sn_dest[cur_sn] = (arch, phys, cur_pc)
                    current_arch[phys] = arch
                    stats['rename_dest'] += 1
                    if row_active:
                        rename_count += 1
                    cur_sn = None
                continue

            if 'D=0x' not in line:
                continue

            m = EXEC_VAL_RE.search(line)
            if not m:
                continue
            sm = FETCHSEQ_RE.search(line) or CPSEQ_RE.search(line)
            if not sm:
                continue
            sn = int(sm.group(1))
            if sn not in sn_dest:
                continue
            if sn in seen_writes:
                stats['duplicate_exec'] += 1
                continue
            seen_writes.add(sn)

            arch, phys, _ = sn_dest[sn]
            value = int(m.group('val'), 16) & maskv
            stats['exec_dest'] += 1

            mkind, row = _marker_info(value, cfg)
            if mkind == 'start':
                stats['row_start'] += 1
                reset_row(row)
                continue
            if mkind == 'end':
                stats['row_end'] += 1
                if row_active:
                    emit_row()
                continue

            curr_arch = current_arch[phys]
            if row_active:
                write_count += 1

            if row_active and has_last[phys]:
                prev_arch = last_arch[phys]
                ch = cmap.get((prev_arch, curr_arch))
                if ch is not None:
                    h = ((last_value[phys] ^ value) & maskv).bit_count()
                    leak[ch - 1] += h
                    event_count += 1
                    pair_count += 1
                    events.append({
                        'row_id': current_row,
                        'channel': ch,
                        'phys': phys,
                        'prev_arch': prev_arch,
                        'curr_arch': curr_arch,
                        'prev_val': f'0x{last_value[phys]:0{width // 4}x}',
                        'curr_val': f'0x{value:0{width // 4}x}',
                        'hd': h,
                    })

            last_arch[phys] = curr_arch
            last_value[phys] = value
            has_last[phys] = True

    stats['rows'] = len(rows)

    if row_csv:
        with open(row_csv, 'w', newline='') as f:
            w = csv.DictWriter(f, fieldnames=[
                'row_id', 'leak1', 'leak2', 'leak3', 'leak4',
                'events', 'renames', 'writes', 'strict_pairs'])
            w.writeheader()
            w.writerows(rows)

    if event_csv:
        with open(event_csv, 'w', newline='') as f:
            w = csv.DictWriter(f, fieldnames=[
                'row_id', 'channel', 'phys', 'prev_arch', 'curr_arch',
                'prev_val', 'curr_val', 'hd'])
            w.writeheader()
            w.writerows(events)

    return {
        'mode': 'present-template',
        'policy': 'last physical write, matching the original template tracker',
        'stats': stats,
        'rows': rows,
        'event_count': len(events),
    }


def run_present_template(args, cfg):
    result = analyze_template(args.trace, cfg, args.row_csv, args.event_csv)
    s = result['stats']
    print(f"rows: {s['rows']}  rename: {s['rename_dest']}  writes: {s['exec_dest']}  events: {result['event_count']}")
    if args.json:
        with open(args.json, 'w') as f:
            json.dump(result, f, indent=2)
    return result

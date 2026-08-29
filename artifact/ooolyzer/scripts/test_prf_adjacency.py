#!/usr/bin/env python3
"""Regression test for the strict PINI PRF_HD1 adjacency rule."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tool"))
from pini_ext import Inst, detect_prf

TAG0 = ("basic", "G1", "D0", "A0B0")
TAG1 = ("basic", "G1", "D1", "P0_10")

def I(sn, arch, phys, tag):
    x = Inst(sn=sn, pc=0x1000 + 4*sn, arch=arch, phys=phys,
             tick=100*sn, value=sn & 1, tag=tag, tag_name=str(tag))
    x.iteration = 0
    return x

a = I(1, 10, 74, TAG0)
b = I(2, 11, 74, TAG1)
x_untagged = I(9, 12, 74, None)

# Adjacent allocations: exactly one direct transition.
ev = detect_prf({74: [a, b]}, "basic")
assert len(ev) == 1, f"expected one adjacent event, got {len(ev)}"

# A squashed/unjoined/intervening allocation is preserved as None and must
# break adjacency.  No a->b transition is legal.
ev = detect_prf({74: [a, None, b]}, "basic")
assert len(ev) == 0, f"intervening allocation incorrectly bridged: {ev}"

# An intervening committed write (even if untagged) must also break adjacency.
ev = detect_prf({74: [a, x_untagged, b]}, "basic")
assert len(ev) == 0, f"intervening write incorrectly bridged: {ev}"

print("PASS: PRF_HD1 requires adjacent allocations; intervening allocations/writes break the pair")

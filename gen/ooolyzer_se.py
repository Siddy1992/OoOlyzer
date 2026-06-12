#!/usr/bin/env python3
"""
ooolyzer_se.py - SE-mode RV32 gem5 config for OoOLyzer trace generation (gem5 25.1).

Runs a static RV32(I/IM) ELF on an out-of-order RISC-V core with a configurable
microarchitecture, or on an in-order core for the negative control. gem5 is NOT
rebuilt for RV32 -- the XLEN is a runtime ISA parameter set per-core below.

Debug flags are passed on the gem5 COMMAND LINE (not here). For the PINI / IEW
experiment the essential streams are Exec + ExecFetchSeq + Commit; a superset
that also serves the RIL tool is shown here:

  $GEM5/build/RISCV/gem5.opt \
      --debug-flags=Rename,FreeList,IEW,Exec,ExecFetchSeq,Writeback,Commit,O3PipeView,IQ,LSQ,Scoreboard \
      --debug-file=pini.out --outdir=m5out \
      gem5-config/ooolyzer_se.py --binary ./pini_test

In-order negative control (inversions should vanish):

  $GEM5/build/RISCV/gem5.opt \
      --debug-flags=Exec,ExecFetchSeq,Commit \
      --debug-file=pini_inorder.out --outdir=m5out_inorder \
      gem5-config/ooolyzer_se.py --binary ./pini_test --inorder

Defaults reproduce the masked PRESENT case-study core (PRF 192 / ROB 256 /
IQ 64 / 2.5 GHz). The same config drives the d=2 PINI gadget unchanged.
"""

import argparse

from gem5.components.boards.simple_board import SimpleBoard
from gem5.components.cachehierarchies.classic.private_l1_private_l2_cache_hierarchy import (
    PrivateL1PrivateL2CacheHierarchy,
)
from gem5.components.memory.single_channel import SingleChannelDDR3_1600
from gem5.components.processors.simple_processor import SimpleProcessor
from gem5.components.processors.cpu_types import CPUTypes
from gem5.isas import ISA
from gem5.resources.resource import BinaryResource
from gem5.simulate.simulator import Simulator

parser = argparse.ArgumentParser(description="OoOLyzer RV32 SE config (PINI/IEW)")
parser.add_argument("--binary", required=True, help="path to static RV32(I/IM) ELF")
parser.add_argument("--clk", default="2.5GHz")
parser.add_argument("--rob", type=int, default=256, help="ROB entries")
parser.add_argument("--iq", type=int, default=64, help="issue-queue entries")
parser.add_argument("--prf", type=int, default=192, help="physical registers (int and fp)")
parser.add_argument("--width", type=int, default=4, help="pipeline width (fetch..commit)")
parser.add_argument("--l1i", default="32KiB")
parser.add_argument("--l1d", default="32KiB")
parser.add_argument("--l2", default="512KiB")
parser.add_argument("--mem", default="512MiB")
parser.add_argument("--inorder", action="store_true",
                    help="negative control: in-order TimingSimpleCPU")
args = parser.parse_args()

cpu_type = CPUTypes.TIMING if args.inorder else CPUTypes.O3
processor = SimpleProcessor(cpu_type=cpu_type, isa=ISA.RISCV, num_cores=1)

# --- Force RV32 on every ISA object of every core (gem5 default is RV64) ------
for core in processor.get_cores():
    for isa_obj in core.core.isa:
        isa_obj.riscv_type = "RV32"

# --- Tune the O3 microarchitecture (best-effort; names drift across versions)-
# Each knob is applied defensively: valid names take effect, unknown ones are
# reported and skipped. Where a name is missing, the build default is used
# (the IQ default is already 64, matching the PRESENT profile).
if not args.inorder:
    desired = {
        "numROBEntries":    args.rob,
        "numIQEntries":     args.iq,
        "numPhysIntRegs":   args.prf,
        "numPhysFloatRegs": args.prf,
        "fetchWidth":       args.width,
        "decodeWidth":      args.width,
        "renameWidth":      args.width,
        "dispatchWidth":    args.width,
        "issueWidth":       args.width,
        "wbWidth":          args.width,
        "commitWidth":      args.width,
    }
    for core in processor.get_cores():
        o3 = core.core
        for name, val in desired.items():
            try:
                setattr(o3, name, val)
            except Exception as e:
                print(f"[ooolyzer] skip {name}={val}: {e}")

memory = SingleChannelDDR3_1600(size=args.mem)
cache = PrivateL1PrivateL2CacheHierarchy(
    l1i_size=args.l1i, l1d_size=args.l1d, l2_size=args.l2,
)
board = SimpleBoard(
    clk_freq=args.clk,
    processor=processor,
    memory=memory,
    cache_hierarchy=cache,
)
board.set_se_binary_workload(BinaryResource(local_path=args.binary))

print(f"[ooolyzer] core={'in-order' if args.inorder else 'O3'} "
      f"binary={args.binary} prf={args.prf} rob={args.rob} iq={args.iq} clk={args.clk}")
sim = Simulator(board=board)
sim.run()
print("OoOLyzer run finished:", sim.get_last_exit_event_cause())

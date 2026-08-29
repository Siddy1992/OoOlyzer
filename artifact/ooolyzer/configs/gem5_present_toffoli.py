#!/usr/bin/env python3
import argparse
from gem5.components.boards.simple_board import SimpleBoard
from gem5.components.cachehierarchies.classic.private_l1_private_l2_cache_hierarchy import PrivateL1PrivateL2CacheHierarchy
from gem5.components.memory.single_channel import SingleChannelDDR3_1600
from gem5.components.processors.simple_processor import SimpleProcessor
from gem5.components.processors.cpu_types import CPUTypes
from gem5.isas import ISA
from gem5.resources.resource import BinaryResource
from gem5.simulate.simulator import Simulator

p = argparse.ArgumentParser()
p.add_argument('--binary', required=True)
p.add_argument('--clk', default='2.5GHz')
p.add_argument('--rob', type=int, default=256)
p.add_argument('--iq', default='64')
p.add_argument('--prf', type=int, default=192)
p.add_argument('--width', type=int, default=4)
p.add_argument('--l1i', default='32KiB')
p.add_argument('--l1d', default='32KiB')
p.add_argument('--l2', default='512KiB')
p.add_argument('--mem', default='512MiB')
p.add_argument('--inorder', action='store_true')
a = p.parse_args()

processor = SimpleProcessor(cpu_type=CPUTypes.TIMING if a.inorder else CPUTypes.O3,
                            isa=ISA.RISCV, num_cores=1)
for core in processor.get_cores():
    for isa in core.core.isa:
        isa.riscv_type = 'RV32'

if not a.inorder:
    params = {
        'numROBEntries': a.rob,
        'numPhysIntRegs': a.prf,
        'numPhysFloatRegs': a.prf,
        'fetchWidth': a.width,
        'decodeWidth': a.width,
        'renameWidth': a.width,
        'dispatchWidth': a.width,
        'issueWidth': a.width,
        'wbWidth': a.width,
        'commitWidth': a.width,
    }
    if str(a.iq).lower() != 'default':
        params['numIQEntries'] = int(a.iq)
    for core in processor.get_cores():
        for name, value in params.items():
            try:
                setattr(core.core, name, value)
            except Exception:
                pass

cache = PrivateL1PrivateL2CacheHierarchy(l1i_size=a.l1i, l1d_size=a.l1d, l2_size=a.l2)
memory = SingleChannelDDR3_1600(size=a.mem)
board = SimpleBoard(clk_freq=a.clk, processor=processor, memory=memory, cache_hierarchy=cache)
board.set_se_binary_workload(BinaryResource(local_path=a.binary))
sim = Simulator(board=board)
sim.run()

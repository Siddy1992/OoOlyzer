#!/usr/bin/env python3
import argparse
import m5
from m5.objects import AddrRange, DDR3_1600_8x8, DerivO3CPU, MemCtrl, Process, RiscvISA, Root, SEWorkload, SrcClockDomain, System, SystemXBar, VoltageDomain

p = argparse.ArgumentParser()
p.add_argument('--binary', required=True)
p.add_argument('--prf', type=int, default=36)
p.add_argument('--rob', type=int, default=128)
p.add_argument('--iq', default='default')
p.add_argument('--width', type=int, default=4)
p.add_argument('--clk', default='2.5GHz')
p.add_argument('--mem-size', default='512MB')
a = p.parse_args()

system = System()
system.clk_domain = SrcClockDomain(clock=a.clk, voltage_domain=VoltageDomain())
system.mem_mode = 'timing'
system.mem_ranges = [AddrRange(a.mem_size)]
system.cpu = DerivO3CPU()
try:
    system.cpu.isa = [RiscvISA(riscv_type='RV32', enable_rvv=False)]
except Exception:
    for isa in system.cpu.isa:
        if hasattr(isa, 'riscv_type'):
            isa.riscv_type = 'RV32'

system.cpu.numPhysIntRegs = a.prf
system.cpu.numROBEntries = a.rob
if str(a.iq).lower() != 'default' and 'numIQEntries' in getattr(system.cpu, '_params', {}):
    system.cpu.numIQEntries = int(a.iq)
for name in ('fetchWidth','decodeWidth','renameWidth','dispatchWidth','issueWidth','wbWidth','commitWidth'):
    if name in getattr(system.cpu, '_params', {}):
        setattr(system.cpu, name, a.width)

system.membus = SystemXBar()
system.cpu.icache_port = system.membus.cpu_side_ports
system.cpu.dcache_port = system.membus.cpu_side_ports
system.cpu.createInterruptController()
system.system_port = system.membus.cpu_side_ports
system.mem_ctrl = MemCtrl()
system.mem_ctrl.dram = DDR3_1600_8x8()
system.mem_ctrl.dram.range = system.mem_ranges[0]
system.mem_ctrl.port = system.membus.mem_side_ports
system.workload = SEWorkload.init_compatible(a.binary)
proc = Process()
proc.cmd = [a.binary]
system.cpu.workload = proc
system.cpu.createThreads()
root = Root(full_system=False, system=system)
m5.instantiate()
m5.simulate()

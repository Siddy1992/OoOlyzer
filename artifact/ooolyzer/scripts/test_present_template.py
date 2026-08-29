#!/usr/bin/env python3
import importlib.util
from pathlib import Path

p = Path(__file__).with_name('make_present_template_case.py')
spec = importlib.util.spec_from_file_location('ptcase', p)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

for nib in range(16):
    exp = (m.ROUND0 >> (4 * (15 - nib))) & 0xf
    for var in range(16):
        for rep in range(3):
            sec, _ = m.row_state(nib, 0, -1, var, rep)
            ref, _ = m.row_state(nib, 1, exp, var, rep)
            if sec != ref:
                raise SystemExit(f'matched template mismatch at nib={nib} var={var} rep={rep}')
print('PRESENT template input matching: PASS')
# Regression check for the bare-metal startup/linker-relaxation bug.
import tempfile
with tempfile.TemporaryDirectory() as td:
    asm = Path(td) / 'harness.S'
    rows = m.generate(0, 1, 'secret')
    m.write_asm(asm, rows)
    text = asm.read_text()
    if not any('.option norelax' in line for line in text.splitlines()[:4]):
        raise SystemExit('generated PRESENT template harness is missing .option norelax')
print('PRESENT template norelax guard: PASS')

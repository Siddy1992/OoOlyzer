# Troubleshooting

## PRESENT key-profiling page-table fault near `0xfffffffffffff...`

### Status

Fixed in this artifact revision.

### Cause

The first-round profiling benchmark is generated as a bare-metal RV32 program with its own `_start`. It uses `la` to obtain addresses for `_stack_top`, `row_data`, `shares0`, and `shares1`, but it does not run a C runtime and therefore does not initialize `gp`. A relaxed GNU RISC-V link could convert one of those address loads to a `gp`-relative form, yielding an invalid small/negative virtual address in gem5 SE mode.

### Fix carried by this package

- `scripts/make_present_template_case.py` emits `.option norelax`.
- `scripts/build_present_template_case.sh` uses `-nostdlib`, `-Wl,-e,_start`, `-Wl,--no-relax`, and `-Wl,--build-id=none`.
- The build script disassembles `_start` and aborts if a `gp` operand is present.
- `riscv64-unknown-elf-objdump` is checked by `scripts/check_env.sh`.
- The same no-relax protection is applied to the source rebuild paths for the baseline PRESENT and Toffoli custom-start harnesses.

No change to gem5 or to `benchmarks/present/RISCV_masked-PRESENT.S` is required for this fix.

### Verify one case

```bash
cd artifact/ooolyzer
rm -rf build/present_key/nib00/secret \
       m5out/present_key/nib00/secret \
       results/present_key/nib00/secret

REPS=1 ./scripts/run_present_template_case.sh 0 secret
```

For `REPS=1`, the result directory should contain `template_meta.csv`, `gem5_physreg_leak.csv`, `gem5_physreg_events.csv`, and `analysis.json`, with 16 data rows in the row-level outputs.

To inspect `_start` manually:

```bash
riscv64-unknown-elf-objdump -d --disassemble=_start \
  build/present_key/nib00/secret/present_key.elf
```

The address loads should be PC-relative and no `gp` operand should be present.

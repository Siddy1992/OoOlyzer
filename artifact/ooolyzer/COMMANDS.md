# Commands

From `artifact/ooolyzer`:

```bash
./scripts/check_env.sh
python3 tool/ooolyzer.py --selftest
```

PRESENT:

```bash
./scripts/run_present.sh
```

Toffoli:

```bash
./scripts/run_toffoli.sh
```

PINI baseline:

```bash
./scripts/run_pini_baseline.sh
```

PINI sweep:

```bash
./scripts/run_pini_sweep.sh
```

All baseline simulator experiments:

```bash
./scripts/run_all.sh
```

## PRESENT first-round key profiling

Check matched secret/reference inputs:

```bash
python3 scripts/test_present_template.py
```

Run one target nibble:

```bash
REPS=3 ./scripts/run_present_template_case.sh 0 secret
```

Build and inspect only the corrected bare-metal harness:

```bash
REPS=1 ./scripts/build_present_template_case.sh 0 secret
riscv64-unknown-elf-objdump -d --disassemble=_start \
  build/present_key/nib00/secret/present_key.elf
```

The build itself fails if `_start` contains a `gp`-relative operand.

Run all 16 nibbles and rank the first-round key:

```bash
./scripts/run_present_key.sh
```

Keep raw traces for debugging:

```bash
KEEP_PRESENT_KEY_TRACES=1 ./scripts/run_present_template_case.sh 0 secret
```

Remove only key-profiling data:

```bash
./scripts/clean_present_key.sh
```

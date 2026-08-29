# Artifact evaluation notes

## Main claims covered

The package supports the simulator-side claims used in the paper:

- strict and conflict-filtered RIL counts for masked PRESENT;
- the four PRESENT share-mixing channels and their Hamming-distance statistics;
- the in-order negative control;
- the masked Toffoli known-answer transition counts;
- controlled first-order PINI baseline results for M1, M2, and M3;
- the 36--192 physical-register PINI sweep.

## Suggested evaluation order

```bash
./scripts/check_env.sh
python3 tool/ooolyzer.py --selftest
./scripts/run_toffoli.sh
./scripts/run_pini_baseline.sh
./scripts/run_present.sh
```

The Toffoli and PINI baseline runs are useful initial checks before the longer PRESENT trace.

## Expected-result checks

Each run ends with `scripts/verify_results.py`. A zero exit status means the generated report matches the reference values in the artifact.

## Rebuilding binaries

PRESENT and Toffoli use the supplied reference ELFs by default. Set `REBUILD=1` to compile from source. PINI is built from source for each mode.

## gem5 location

The default is `../../gem5/build/RISCV/gem5.opt`. Override with `GEM5_ROOT` or `GEM5` if needed.

## PRESENT first-round key experiment

The first-round key experiment does not require a patched gem5 tree. The artifact reconstructs the original row-level physical-register tracker from standard gem5 debug records. The supplied harness uses the current RV32 masked PRESENT S-box and matched masking randomness across secret/reference rows.

A short evaluator check is:

```bash
python3 scripts/test_present_template.py
NIBBLES="0" REPS=1 ./scripts/run_present_key.sh
```

The first command also checks that generated profiling harnesses retain the `.option norelax` guard. During the second command, the build script performs a post-link `_start` disassembly check and stops before gem5 if an unexpected `gp`-relative address is present.

The complete run is:

```bash
./scripts/run_present_key.sh
```

Expected complete result: `123456789ABCDEF0`, 16/16 nibbles.

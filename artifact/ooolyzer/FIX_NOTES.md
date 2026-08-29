# Artifact fix notes

This revision fixes a bare-metal RISC-V linker-relaxation failure in the generated masked-PRESENT first-round key-profiling harness.

## Failure mode

The generated program defines its own `_start` and does not initialize `gp`. GNU RISC-V relaxation could rewrite an `la` address load into a `gp`-relative instruction. In gem5 SE mode this could appear as a page-table fault at an invalid small/negative virtual address, including the observed `0xfffffffffffff814` failure.

## Corrections

1. `scripts/make_present_template_case.py` now emits `.option norelax` before the generated text section.
2. `scripts/build_present_template_case.sh` now links with `-nostdlib`, `-Wl,-e,_start`, `-Wl,--no-relax`, and `-Wl,--build-id=none`.
3. The same build script disassembles `_start` with `riscv64-unknown-elf-objdump` and aborts if a `gp` operand is present.
4. `scripts/common.sh` and `scripts/check_env.sh` now include `riscv64-unknown-elf-objdump`.
5. Baseline PRESENT and Toffoli source-rebuild paths are hardened with the same no-relax policy because they also use custom `_start` routines with `la` address loads.
6. `scripts/test_present_template.py` includes a regression check that generated harnesses contain `.option norelax`.

No gem5 source change and no change to `benchmarks/present/RISCV_masked-PRESENT.S` are required.

## Recommended first verification

```bash
cd artifact/ooolyzer
./scripts/check_env.sh
python3 scripts/test_present_template.py

rm -rf build/present_key/nib00/secret \
       m5out/present_key/nib00/secret \
       results/present_key/nib00/secret

REPS=1 ./scripts/run_present_template_case.sh 0 secret
```

The run should complete without the previous page-table fault. The build stage itself will stop before gem5 if `_start` contains an unexpected `gp`-relative instruction.

# OoOLyzer artifact

This combined package contains **two distinct verification tracks**:

1. **gem5/OoOLyzer simulator verification** for masked PRESENT, masked Toffoli, controlled PINI1, the PRF sweep, and the PRESENT first-round profiling experiment; and
2. a **separate SiFive P550 physical-board temperature validation** under `physical_validation/p550_present80/`.

The P550 experiment is intentionally kept separate from the gem5 workflow. It was executed on a physical SiFive P550 board and must be verified through its archived temperature traces, analysis-only reproduction, or a physical rerun on a compatible P550 platform. It is **not** run by `scripts/run_all.sh` and should not be interpreted as a gem5 result. See `docs/P550_PHYSICAL_VALIDATION.md`.

The PRESENT and Toffoli sources, fixed RV32 binaries, and share mappings are carried forward from the earlier OoOLyzer artifact. They are analyzed by the current `tool/ooolyzer.py`. The old PINI/HPC2 workload is not included. The PINI experiment in this package is the controlled `G1 -> LIN -> G2` experiment used by the current paper. Source provenance is recorded in `docs/WORKLOAD_PROVENANCE.md`.

## Directory layout and gem5 location

**gem5 is a separate dependency and is not included in this artifact.** The following layout is a recommended example because it matches the scripts' built-in default path resolution:

```text
working_directory/
├── gem5/
│   └── build/
│       └── RISCV/
│           └── gem5.opt
└── artifact/
    └── ooolyzer/
        ├── benchmarks/
        │   ├── present/
        │   ├── toffoli/
        │   └── pini/
        ├── bin/
        ├── configs/
        ├── docs/
        ├── scripts/
        ├── tool/
        ├── build/
        ├── m5out/
        ├── results/
        └── physical_validation/
            └── p550_present80/
```

With this layout, if the artifact is at:

```text
/path/to/working_directory/artifact/ooolyzer/
```

the default gem5 executable resolved by `scripts/common.sh` is:

```text
/path/to/working_directory/gem5/build/RISCV/gem5.opt
```

Therefore no gem5 environment variable is required for this example layout.

The artifact does **not** require this exact directory structure. If gem5 is installed elsewhere, set its location explicitly:

```bash
export GEM5_ROOT=/path/to/gem5
```

The expected executable is then:

```text
$GEM5_ROOT/build/RISCV/gem5.opt
```

Alternatively, point directly to the executable:

```bash
export GEM5=/path/to/gem5/build/RISCV/gem5.opt
```

`GEM5` takes precedence over `GEM5_ROOT`. Full gem5 build instructions and the CPU model used by each experiment are in `docs/GEM5_SETUP.md`.

`build/`, `m5out/`, and `results/` are populated by the run scripts.

## Updating an existing artifact directory

If this package is overlaid on an earlier `artifact/ooolyzer` directory, run the following once after extraction:

```bash
chmod +x scripts/*.sh scripts/*.py tool/*.py configs/*.py
./scripts/prune_present_key_legacy.sh
```

This removes only obsolete first-round profiling scripts/data from earlier artifact revisions. It does not remove `m5out/present`, `m5out/toffoli`, `m5out/pini`, or their result directories.

## Software

The evaluated setup uses:

- gem5 25.1.0.0, RISC-V build,
- Python 3,
- a RISC-V bare-metal GNU toolchain providing `riscv64-unknown-elf-gcc`, `riscv64-unknown-elf-nm`, and `riscv64-unknown-elf-objdump`.

### Standard gem5 checkout

**gem5 is not included in this ZIP.** A separate gem5 checkout and RISC-V build are required. The evaluated simulator version is gem5 25.1.0.0. The default expected build folder is `gem5/build/RISCV/`, containing `gem5.opt`.

The main experiments use a **single-core out-of-order RISC-V RV32 CPU**. PRESENT and Toffoli select `CPUTypes.O3`; PINI uses `DerivO3CPU`. The in-order PRESENT/Toffoli negative control alone uses `CPUTypes.TIMING`. See `docs/GEM5_SETUP.md` for the exact configuration.

To create the recommended example layout, start from `working_directory/`:

```bash
cd /path/to/working_directory
git clone https://github.com/gem5/gem5.git
cd gem5
git checkout v25.1.0.0
scons build/RISCV/gem5.opt -j"$(nproc)"
```

Then place the extracted artifact at:

```text
/path/to/working_directory/artifact/ooolyzer/
```

If the built binary is not executable:

```bash
chmod u+x build/RISCV/gem5.opt
```

If the recommended example layout is used, check the environment directly:

```bash
cd /path/to/working_directory/artifact/ooolyzer
chmod +x scripts/*.sh scripts/*.py configs/*.py tool/*.py
./scripts/check_env.sh
```

For a different directory layout, set `GEM5_ROOT` or `GEM5` first. For example:

```bash
export GEM5_ROOT=/path/to/gem5
cd /path/to/ooolyzer
chmod +x scripts/*.sh scripts/*.py configs/*.py tool/*.py
./scripts/check_env.sh
```

## JSON-driven analysis

The analyses use JSON configuration files:

```text
configs/present.json
configs/toffoli.json
configs/pini.json
configs/present_template.json
```

For PRESENT and Toffoli, the JSON contains the architectural-register share map and conflict relation used by RIL analysis. `present_template.json` describes the row-level first-round profiling experiment. For PINI, the JSON selects the PINI analysis mode, iteration window, observation models, baseline backend parameters, and PRF sweep. The Boolean PINI1 semantics used by the support test are implemented in `tool/pini_model.py`.

The analyzer selects the mode from `analysis.mode` when `--mode` is not supplied.

## Quick checks

```bash
python3 tool/ooolyzer.py --selftest
python3 tool/pini_model.py
python3 scripts/test_prf_adjacency.py
python3 scripts/test_present_template.py
```

The first command tests the RIL/IEW parsing logic. The second checks the PINI model implementation.

## Masked PRESENT

The exact binary from the earlier artifact is included at `bin/present32.elf`. It is used by default to avoid toolchain-dependent changes in code layout. The source is under `benchmarks/present/`.

Run the OoO trace, strict analysis, conflict-filtered analysis, loose accounting, and in-order negative control:

```bash
./scripts/run_present.sh
```

To rebuild from source first:

```bash
REBUILD=1 ./scripts/run_present.sh
```

The direct analyzer calls used by the script are equivalent to:

```bash
python3 tool/ooolyzer.py \
  --trace m5out/present/o3/trace.out \
  --config configs/present.json \
  --json results/present/present_ril.json

python3 tool/ooolyzer.py \
  --trace m5out/present/o3/trace.out \
  --config configs/present.json \
  --filter-conflicts \
  --json results/present/present_conflicts.json
```

Expected paper-level results:

```text
strict RIL candidates     51,707
conflict-filtered             344
loose accounting           52,002
in-order conflicts               0

x19/x28  d0/d1   count 153   HDmax 23   HDmean 9.59
x7/x18   c0/c1   count 124   HDmax 14   HDmean 7.91
x20/x29  a0/a1   count  66   HDmax 13   HDmean 7.77
x6/x9    b0/b1   count   1   HDmax 18   HDmean 18.00
```

The verifier also checks the representative `P74: x29 -> x20` transition with values `0x0000c144 -> 0x00007fb9` and HD 13.

### First-round key profiling

The artifact also contains a row-level profiling experiment for the 64-bit first-round key. It uses the same RV32 masked PRESENT S-box source and the four share-pair channels L1--L4. Secret and reference rows use matched masking randomness for each `(nibble, plaintext class, repetition)` tuple. The correct reference therefore recreates the same masked S-box input as the secret row.

The original profiling experiment used a small C++ tracker in the gem5 rename/write path. A copy is retained under `experiments/present_key/reference/leak_tracker.hh` for provenance. It is not required by this artifact. `tool/ooolyzer.py` implements the same row accounting offline from ordinary `Rename`, `Exec`, and `ExecFetchSeq` debug records, so a standard gem5 checkout is sufficient.

For tractable trace size, the supplied RV32 profiling harness enters the first masked S-box directly after constructing the exact round-0 masked input state. This preserves the first-round secret/reference comparison while avoiding tracing the remaining 30 rounds. Each secret or key-reference profile contains 48 rows with the default three repetitions. A target nibble therefore uses one secret profile and 16 reference profiles.

Run the full 16-nibble experiment with:

```bash
./scripts/run_present_key.sh
```

The generated first-round harness is a custom bare-metal `_start` and does not initialize `gp`. To prevent GNU linker relaxation from converting `la` pseudo-instructions into invalid `gp`-relative accesses, the artifact emits `.option norelax`, links with `-Wl,--no-relax`, and automatically disassembles `_start` after each build. A `gp`-relative instruction in `_start` is treated as a build error before gem5 is launched. See `docs/TROUBLESHOOTING.md`.

Expected final key:

```text
123456789ABCDEF0
```

Raw traces are removed after each nibble by default. Set `KEEP_PRESENT_KEY_TRACES=1` when debugging. A partial run can be requested with, for example, `NIBBLES="0 1" ./scripts/run_present_key.sh`. The complete procedure is documented in `docs/PRESENT_KEY_RECOVERY.md`.

## Masked Toffoli known-answer validation

The exact binary from the earlier artifact is included at `bin/toffoli32.elf`; source is under `benchmarks/toffoli/`.

```bash
./scripts/run_toffoli.sh
```

To rebuild:

```bash
REBUILD=1 ./scripts/run_toffoli.sh
```

Expected conflict-pair results:

```text
x10/x13  a_s0/a_s1   1,999 transitions   HD 32 exactly
x11/x14  b_s0/b_s1   1,999 transitions   HD 32 exactly
x12/x15  c_s0/c_s1   3,998 transitions   mean HD 14, max 16
```

The in-order control should contain no conflict-filtered RIL candidates.

## Controlled PINI1 baseline

The controlled PINI source is `benchmarks/pini/pini_basic.S`. Its tags are emitted as ELF symbols and interpreted by `tool/pini_ext.py`; the run and support-test settings are in `configs/pini.json`.

Run the three baseline modes:

```bash
./scripts/run_pini_baseline.sh
```

Equivalent individual runs are:

```bash
MODE=1 PRF=36 ./scripts/run_pini_case.sh
MODE=2 PRF=36 ./scripts/run_pini_case.sh
MODE=3 PRF=36 ./scripts/run_pini_case.sh
```

The analyzer is invoked with the JSON configuration, for example:

```bash
python3 tool/ooolyzer.py \
  --trace m5out/pini/prf36/m3/trace.out \
  --config configs/pini.json \
  --elf build/pini_m3.elf \
  --out-prefix results/pini/prf36/m3 \
  --json results/pini/prf36/m3_analysis.json
```

Expected baseline:

```text
M1  tagged 448  formal  96  local  96  cross   0  PRF  32  complete  64  PRF types  1
M2  tagged 512  formal 128  local  96  cross  32  PRF  32  complete  96  PRF types  2
M3  tagged 960  formal 256  local 128  cross 128  PRF 128  complete 128  PRF types 13
```

`PRF_HD1` is constructed only from adjacent allocation positions in the same physical-register stream. An intervening allocation, including an unavailable or squashed allocation, breaks the pair.

## PINI physical-register sweep

```bash
./scripts/run_pini_sweep.sh
```

or a shorter subset:

```bash
PRFS="36 56 192" ./scripts/run_pini_sweep.sh
```

The full sweep writes:

```text
results/pini/basic_prf_sweep.csv
```

and is checked against `results/reference/pini_prf_sweep.csv`.

## SiFive P550 physical-board temperature validation

The merged artifact also contains:

```text
physical_validation/p550_present80/
```

This is a **separate physical experiment executed on a SiFive P550 board**. It does not use gem5 and is not part of the simulator `run_all.sh` path.

Start by inspecting the archived physical trace and recovery output:

```text
physical_validation/p550_present80/01_traces_and_results/full_present80_temp_trace.txt
physical_validation/p550_present80/01_traces_and_results/final_full_present80_recovery.txt
```

The two temperature sensors central to that experiment are:

```text
/sys/devices/platform/soc/50b00000.pvt/hwmon/hwmon1/temp1_input
/sys/devices/platform/soc/52360000.pvt/hwmon/hwmon2/temp1_input
```

Analysis-only verification of the archived trace can be performed without the board:

```bash
cd physical_validation/p550_present80
./04_scripts/reproduce_recovery.sh
```

A full physical rerun requires a SiFive P550-based Linux system exposing the required sensor channels and should be treated as a statistical experimental reproduction rather than a bit-for-bit replay. Full instructions are in `docs/P550_PHYSICAL_VALIDATION.md` and `physical_validation/p550_present80/README.md`.

## Output files

PRESENT and Toffoli produce JSON reports under `results/present/` and `results/toffoli/`.

PINI produces, for each mode:

```text
*_instructions.csv
*_events.csv
*_violations.csv
*_types.csv
*_summary.json
*_summary.txt
*_analysis.json
```

Raw gem5 traces are written under `m5out/` and are not bundled in the archive.

## Verification

The run scripts call the verifier automatically. It can also be run directly:

```bash
python3 scripts/verify_results.py --case present
python3 scripts/verify_results.py --case toffoli
python3 scripts/verify_results.py --case present-key
python3 scripts/verify_results.py --case pini-baseline
python3 scripts/verify_results.py --case pini-sweep
```

The expected values are stored in `results/reference/` and in the `expected` fields of the JSON workload configurations.

## Artifact scope

This package covers masked PRESENT structural attribution and first-round profiling, the masked Toffoli known-answer validation, the controlled PINI1 experiment, and a separately packaged SiFive P550 physical temperature-validation track. The P550 track has its own verification procedure and is not part of the simulator runs. The package intentionally does not include the older PINI/HPC2 workload from the previous artifact.

## Controlled PINI build modes

The controlled PINI source uses the preprocessor symbol `TEST_MODE`:

- mode 1: `G1`
- mode 2: `G1 -> LIN`
- mode 3: `G1 -> LIN -> G2`

`scripts/build_pini.sh` sets this symbol from `MODE` and checks that the resulting ELF contains 14, 16, or 30 tagged PINI PCs, respectively. This check prevents a mode-selection error from silently turning all three runs into the complete mode-3 program.

# gem5 setup for the OoOLyzer simulator experiments

## gem5 is not bundled with this artifact

The OoOLyzer simulator experiments require a separate gem5 source checkout. The evaluated version is **gem5 25.1.0.0** with the **RISC-V** target enabled.

The `ooolyzer` artifact directory and the gem5 source tree may be placed anywhere on the system. However, the following example layout matches the artifact's built-in default path resolution and therefore works without setting `GEM5` or `GEM5_ROOT`:

```text
working_directory/
├── gem5/
│   └── build/
│       └── RISCV/
│           └── gem5.opt
└── artifact/
    └── ooolyzer/
        ├── benchmarks/
        ├── configs/
        ├── scripts/
        ├── tool/
        ├── build/
        ├── m5out/
        ├── results/
        └── physical_validation/
            └── p550_present80/
```

For this layout, `scripts/common.sh` resolves:

```text
ARTIFACT_ROOT=/path/to/working_directory/artifact/ooolyzer
PROJECT_ROOT=/path/to/working_directory
GEM5_ROOT=/path/to/working_directory/gem5
GEM5=/path/to/working_directory/gem5/build/RISCV/gem5.opt
```

This layout is only a convenience. For any other directory arrangement, set the gem5 location explicitly.

The most portable setup is to point the artifact to the gem5 source tree explicitly:

```bash
export GEM5_ROOT=/absolute/path/to/gem5
```

The expected executable is:

```text
$GEM5_ROOT/build/RISCV/gem5.opt
```

Alternatively, point directly to the executable:

```bash
export GEM5=/absolute/path/to/gem5/build/RISCV/gem5.opt
```

The direct `GEM5` setting takes precedence in the run scripts. If neither variable is set, `scripts/common.sh` uses its convenience default and looks for a nearby `gem5` tree.

## Obtain and build the evaluated gem5 version

From any directory where the gem5 source tree should be stored:

```bash
git clone https://github.com/gem5/gem5.git
cd gem5
git checkout v25.1.0.0
scons build/RISCV/gem5.opt -j"$(nproc)"
```

A working compiler toolchain, Python 3, SCons, and the normal gem5 build dependencies must already be installed on the host. Follow the gem5 dependency instructions for the host distribution if `scons` reports a missing package.

Confirm the build:

```bash
./build/RISCV/gem5.opt --version
```

The expected major artifact version is:

```text
gem5 version 25.1.0.0
```

If needed:

```bash
chmod u+x build/RISCV/gem5.opt
```

## CPU model used by this artifact

The security experiments use a **single-core out-of-order RISC-V CPU executing RV32 binaries**.

### Masked PRESENT and Toffoli

`configs/gem5_present_toffoli.py` creates:

```python
SimpleProcessor(
    cpu_type=CPUTypes.O3,
    isa=ISA.RISCV,
    num_cores=1,
)
```

and explicitly sets:

```python
isa.riscv_type = 'RV32'
```

Thus, the relevant CPU option is **O3** (`CPUTypes.O3`).

The only exception is the negative-control execution, where the script passes `--inorder` and the configuration selects:

```python
CPUTypes.TIMING
```

### PINI

`configs/gem5_pini.py` directly creates:

```python
DerivO3CPU()
```

with:

```python
RiscvISA(riscv_type='RV32', enable_rvv=False)
```

Thus, the PINI experiment also uses gem5's **out-of-order O3 CPU**, specifically `DerivO3CPU`.

## Backend parameters

The artifact configures the O3 backend from the JSON experiment files. The important parameters include:

- physical integer registers (`numPhysIntRegs`),
- ROB entries (`numROBEntries`),
- issue-queue entries when explicitly requested (`numIQEntries`),
- fetch/decode/rename/dispatch/issue/writeback/commit width,
- CPU clock frequency.

For the controlled PINI baseline and PRF sweep, the intended baseline configuration is:

```text
CPU model     : DerivO3CPU
ISA           : RISC-V RV32
ROB           : 128
width         : 4
clock         : 2.5 GHz
IQ            : gem5 default unless explicitly overridden
PRF           : experiment dependent (36 for the stressed baseline; sweep 36..192)
```

The exact values are read from `configs/pini.json` and passed by the run scripts.

## Artifact-side environment check

After building gem5, set its path and run the environment check from the artifact directory:

```bash
export GEM5_ROOT=/absolute/path/to/gem5
cd /absolute/path/to/ooolyzer
./scripts/check_env.sh
```

The script prints the resolved gem5 repository and executable paths and checks that the RISC-V cross-toolchain is available.

Typical successful path resolution is:

```text
GEM5_ROOT=/absolute/path/to/gem5
GEM5=/absolute/path/to/gem5/build/RISCV/gem5.opt
```

## Minimal simulator verification

Before starting the longer experiments:

```bash
python3 tool/ooolyzer.py --selftest
python3 tool/pini_model.py
python3 scripts/test_prf_adjacency.py
python3 scripts/test_present_template.py
```

Then a useful short gem5 check is:

```bash
MODE=1 PRF=36 ./scripts/run_pini_case.sh
```

The full simulator-side evaluation can then be run as described in `ARTIFACT_EVALUATION.md`.

# SiFive P550 Masked PRESENT-80 Temperature-Recovery Artifact

> **Merged-artifact location:** `physical_validation/p550_present80/` inside the main OoOLyzer artifact. This directory is a separate physical-board validation track and is not run by the gem5/OoOLyzer simulator scripts.

## Start here: inspect the archived trace and result first

This experiment was **executed on a SiFive P550 board**. The archived measurement trace and the corresponding recovery output are already included, so the experimental evidence can be inspected **without rerunning the board experiment**.

The two most important files are:

```text
01_traces_and_results/full_present80_temp_trace.txt
01_traces_and_results/final_full_present80_recovery.txt
```

To inspect them directly:

```bash
less 01_traces_and_results/full_present80_temp_trace.txt
less 01_traces_and_results/final_full_present80_recovery.txt
```

The archived recovery output reports:

```text
Recovered key: 753C9106545A76F2A259
Expected key : A73C910F55C826B4E17D
Correct bits : 60/80
```

`01_traces_and_results/extra_targets.txt` contains the bit positions selected by the adaptive re-measurement procedure.

### Trace format

Each data row in `full_present80_temp_trace.txt` has the form:

```text
bitpos rep ref0 ref1 secret expected
```

where `ref0`, `ref1`, and `secret` are measured temperature deltas for the two bit-forced reference executions and the secret-key execution, respectively.

---

## Experimental platform: SiFive P550 board

The physical experiment was performed on a **SiFive P550-based board**. The victim program was pinned to a CPU using `taskset` during the measurement runs (CPU 0 by default in the supplied scripts).

The supplied executable is an RV64 Linux binary, and the source can be rebuilt natively on the P550 platform.

---

## Temperature sensors used in the experiment

The experiment is explicitly **temperature-based**, and the following two temperature-sensor channels are central to the measurement procedure:

### Temperature sensor 1

```text
/sys/devices/platform/soc/50b00000.pvt/hwmon/hwmon1/temp1_input
```

### Temperature sensor 2

```text
/sys/devices/platform/soc/52360000.pvt/hwmon/hwmon2/temp1_input
```

These exact sysfs paths are defined in the P550 victim source.

For each temperature sample, the harness reads both channels. When both are available, it averages the two readings. If only one channel is readable, it uses the available channel. The victim then forms a temperature delta by comparing averaged readings taken before and after the masked PRESENT workload.

The source uses:

```text
AVG_READS  = 9
AVG_GAP_US = 200000
```

so each averaged temperature observation uses nine sensor reads separated by 200 ms.

A board-side sanity check for these sensors is provided by:

```bash
./04_scripts/check_environment.sh
```

---

## What this artifact demonstrates

This package contains the SiFive P550 experiment for masked PRESENT-80 temperature-based key-recovery validation.

This experiment is a **controlled / profiling validation**, not a blind 80-bit key-recovery attack. For each master-key bit position, the victim constructs two reference keys (`ref0` and `ref1`) by forcing that bit to 0 or 1 while retaining the remaining key bits, and compares the secret execution's temperature response with those references. The embedded expected bit is used only to evaluate recovery accuracy.

The archived run recovers **60 of 80 key bits**.

---

## Artifact layout

```text
OoOLyzer_P550_PRESENT80_artifact/
├── README.md
├── MANIFEST.sha256
│
├── 01_traces_and_results/             # LOOK HERE FIRST
│   ├── README.md
│   ├── full_present80_temp_trace.txt  # archived P550 temperature trace
│   ├── final_full_present80_recovery.txt # archived recovery output
│   └── extra_targets.txt              # adaptive target list
│
├── 02_experiment/
│   ├── src/
│   │   ├── victim_full_present80_temp_p550.c
│   │   └── RISCV_masked_PRESENT_64.S
│   └── bin/
│       └── victim_full_present80_temp_p550
│
├── 03_analysis/
│   └── recover_full_present80_temp.py
│
├── 04_scripts/
│   ├── check_environment.sh
│   ├── build_p550.sh
│   ├── reproduce_recovery.sh
│   ├── run_full_attack.sh
│   └── run_extra_passes.sh
│
└── 05_metadata/
    ├── PLATFORM_AND_SENSORS.md
    └── environment.txt
```

---

## Reproduce the archived recovery result without the P550 board

For analysis-only verification of the supplied result, run:

```bash
./04_scripts/reproduce_recovery.sh
```

This re-runs the recovery algorithm on the archived trace in `01_traces_and_results/` and compares the generated output with the archived report.

Expected summary:

```text
Recovered key: 753C9106545A76F2A259
Expected key : A73C910F55C826B4E17D
Correct bits : 60/80
```

No P550 board or temperature sensors are required for this analysis-only reproduction.

---

## Re-run the physical experiment on the SiFive P550 board

### 1. Verify the P550 environment and both temperature sensors

```bash
./04_scripts/check_environment.sh
```

Both temperature sensor paths listed above should ideally appear as `[OK]`.

### 2. Rebuild the victim on the P550

```bash
./04_scripts/build_p550.sh
```

Equivalent native compilation:

```bash
gcc -O2 -Wall -Wextra -march=rv64gc -mabi=lp64d \
    02_experiment/src/victim_full_present80_temp_p550.c \
    02_experiment/src/RISCV_masked_PRESENT_64.S \
    -o 02_experiment/bin/victim_full_present80_temp_p550
```

### 3. Execute the complete controlled temperature experiment

```bash
./04_scripts/run_full_attack.sh
```

The script performs a baseline pass over the 80 key-bit positions and then adaptive re-measurement rounds. It writes the new trace, target list, and output directly into:

```text
01_traces_and_results/
```

The victim is pinned to CPU 0 by default. Another CPU can be selected, for example:

```bash
CPU=1 ./04_scripts/run_full_attack.sh
```

---

## Recovery rule

For each bit position, the analysis computes robust location estimates for the `ref0`, `ref1`, and secret temperature deltas. It predicts bit 1 when the secret median is closer to the `ref1` median than to `ref0`:

```text
d0 = |median(secret) - median(ref0)|
d1 = |median(secret) - median(ref1)|
recovered_bit = 1 if d1 < d0 else 0
```

Rows with `|ref1-ref0| >= 0.04` are preferred; if too few remain, all rows for that bit are used. A 25% trimming step is applied when enough samples remain. Confidence is `|d0-d1|`.

Adaptive targets prioritize failed bits first, followed by correctly recovered but low-confidence bits (`confidence < 0.035`), capped at 30 positions per round.

---

## Interpretation boundary

Because the C harness contains a fixed `SECRET_KEY` and synthesizes the two bit-forced references from that key, the `60/80` result should be described as a **controlled/profiling temperature-based key-recovery validation on the SiFive P550 board**, rather than as a blind recovery of an otherwise unknown 80-bit key.

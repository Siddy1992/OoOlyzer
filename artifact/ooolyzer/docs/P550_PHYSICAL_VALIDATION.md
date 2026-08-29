# SiFive P550 physical-board validation track

The directory:

```text
physical_validation/p550_present80/
```

contains the separate **physical SiFive P550 temperature experiment**. It is intentionally not part of the gem5 execution path and is not launched by `scripts/run_all.sh`.

## How this part should be verified

This experiment should be evaluated differently from the gem5/OoOLyzer simulator experiments.

### Level 1: inspect the archived physical evidence

Start with:

```text
physical_validation/p550_present80/01_traces_and_results/full_present80_temp_trace.txt
physical_validation/p550_present80/01_traces_and_results/final_full_present80_recovery.txt
```

These are the archived temperature measurements and the corresponding recovery output from the SiFive P550 execution.

The archived output reports:

```text
Recovered key: 753C9106545A76F2A259
Expected key : A73C910F55C826B4E17D
Correct bits : 60/80
```

### Level 2: reproduce the analysis from the archived trace

This check does not require a P550 board:

```bash
cd physical_validation/p550_present80
./04_scripts/reproduce_recovery.sh
```

The expected final message is:

```text
[PASS] Recovery output matches the archived report.
```

This verifies the recovery software against the supplied physical trace.

### Level 3: physically rerun the measurement

A new trace requires a **SiFive P550-based Linux board** exposing the temperature sensors expected by the harness.

The two sensor channels central to the experiment are:

```text
/sys/devices/platform/soc/50b00000.pvt/hwmon/hwmon1/temp1_input
/sys/devices/platform/soc/52360000.pvt/hwmon/hwmon2/temp1_input
```

Check the platform first:

```bash
cd physical_validation/p550_present80
./04_scripts/check_environment.sh
```

Then rebuild and execute:

```bash
./04_scripts/build_p550.sh
./04_scripts/run_full_attack.sh
```

A physical rerun should be treated as a statistical/experimental reproduction rather than a bit-for-bit replay: thermal state, ambient conditions, cooling intervals, Linux activity, CPU affinity, board revision, and sensor exposure can change the exact measurements.

## Important interpretation boundary

The P550 experiment is a **controlled/profiling temperature-based key-recovery validation**. It is not a blind recovery of a completely unknown PRESENT-80 key because the harness constructs bit-forced reference executions for comparison.

See `physical_validation/p550_present80/README.md` and `05_metadata/PLATFORM_AND_SENSORS.md` for the complete procedure.

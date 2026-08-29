# Archived P550 Trace and Results

**Start in this directory.** These files contain the archived output of the temperature experiment executed on the **SiFive P550 board**.

## 1. Raw/collected temperature trace

```text
full_present80_temp_trace.txt
```

Each non-comment row is:

```text
bitpos rep ref0 ref1 secret expected
```

The `ref0`, `ref1`, and `secret` fields are temperature deltas produced using the two P550 temperature-sensor channels documented in `../05_metadata/PLATFORM_AND_SENSORS.md`.

## 2. Recovery output

```text
final_full_present80_recovery.txt
```

The archived summary is:

```text
Recovered key: 753C9106545A76F2A259
Expected key : A73C910F55C826B4E17D
Correct bits : 60/80
```

## 3. Adaptive targets

```text
extra_targets.txt
```

This file contains the bit positions prioritized for additional measurements by the recovery script.

## Reproduce the analysis

From the artifact root:

```bash
./04_scripts/reproduce_recovery.sh
```

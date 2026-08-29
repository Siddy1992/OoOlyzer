# Platform and Temperature Sensors

## Physical platform

The archived physical measurement experiment in this artifact was executed on a **SiFive P550 board** running Linux on RV64.

The supplied run scripts pin the victim process to a CPU with `taskset`; CPU 0 is the default.

## Temperature sensor channels

The temperature experiment uses the following two sysfs sensor channels, as hard-coded in `02_experiment/src/victim_full_present80_temp_p550.c`:

```text
Sensor 1:
/sys/devices/platform/soc/50b00000.pvt/hwmon/hwmon1/temp1_input

Sensor 2:
/sys/devices/platform/soc/52360000.pvt/hwmon/hwmon2/temp1_input
```

These two temperature channels are central to the experiment: the victim reads them before and after repeated masked PRESENT execution and uses their temperature change as the measured signal.

### Sensor aggregation

For an individual instantaneous reading:

- when both sensor paths are readable, their values are averaged;
- when only one sensor is readable, the available sensor is used;
- if neither sensor is readable, the measurement is invalid.

For a pre- or post-workload temperature estimate, the harness averages **9 readings**, separated by **200 ms** (`AVG_READS=9`, `AVG_GAP_US=200000`).

The workload measurement returns:

```text
temperature_delta = post_workload_average - pre_workload_average
```

These deltas become the `ref0`, `ref1`, and `secret` values recorded in `01_traces_and_results/full_present80_temp_trace.txt`.

## Check on a P550 board

Run:

```bash
./04_scripts/check_environment.sh
```

The script prints the host architecture and checks whether both exact sensor paths are readable.

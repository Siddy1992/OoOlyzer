# Workload provenance

The masked PRESENT and masked Toffoli assembly sources, harnesses, JSON share mappings, and fixed RV32 ELF binaries originate from the earlier OoOLyzer artifact supplied with this package. The source files and ELF binaries are included unchanged.

The older PINI/HPC2 workload is not included. The PINI workload in this artifact is the controlled first-order PINI1 composition used in the current evaluation.

## PRESENT first-round profiling

The row-level profiling design is based on the earlier `victim_masked_present_physreg_template.c`, `leak_tracker.hh`, and `recover_gem5_physreg_template.py` workflow. These files are retained under `experiments/present_key/reference/`. The runnable artifact does not install the tracker into gem5. It generates matched-mask RV32 first-S-box profiles and reconstructs the tracker state offline from standard gem5 debug records.

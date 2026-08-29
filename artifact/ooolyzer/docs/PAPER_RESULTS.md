# Paper-result map

## Masked PRESENT

`./scripts/run_present.sh` checks:

- 51,707 strict RIL candidates before semantic filtering;
- 344 conflict-filtered candidates;
- channel counts 153, 124, 66, and 1 for `d0/d1`, `c0/c1`, `a0/a1`, and `b0/b1`;
- the representative P74 `a1 -> a0` transition with HD 13;
- the in-order negative control;
- the loose-accounting count of approximately 52,002.

The 64-bit first-round key-ranking equation is implemented in `scripts/present_key_rank.py`. See `PRESENT_KEY_RECOVERY.md` for the required profiling-record format.

## Masked Toffoli

`./scripts/run_toffoli.sh` checks:

- 1,999 `a_s0/a_s1` transitions with HD 32;
- 1,999 `b_s0/b_s1` transitions with HD 32;
- 3,998 `c_s0/c_s1` transitions with mean HD 14 and maximum HD 16.

## Controlled PINI1

`./scripts/run_pini_baseline.sh` checks the M1/M2/M3 baseline counts.
`./scripts/run_pini_sweep.sh` checks the 36--192 physical-register sweep.

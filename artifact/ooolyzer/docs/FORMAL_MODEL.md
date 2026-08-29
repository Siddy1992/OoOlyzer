# Formal model used by the OoOLyzer PINI artifact

## First-order PINI support test

For the controlled two-share experiment,

- `d = 2`
- `t = 1`
- `t1 = 1`
- `t2 = 0`

one internal observation with no output-share probe must be simulatable from
one of `{}`, `{D0}`, or `{D1}`.  The analyzer also evaluates `{D0,D1}` only to
identify the minimum support when all admissible first-order supports fail.

A row is labeled `PINI_VIOLATION` only when its modeled observation has
minimum support `{D0,D1}`.  This is a violation under the explicitly extended
OoO observation model, not a contradiction of the PINI theorem in its original
probing model.

## Canonical d=2 PINI1 multiplication

For one fresh random bit `r`:

```text
s01  = b1 XOR r
p001 = (a0 XOR 1) AND r
p101 = a0 AND s01
z01  = p001 XOR p101 = r XOR a0*b1
c0   = a0*b0 XOR z01

s10  = b0 XOR r
p010 = (a1 XOR 1) AND r
p110 = a1 AND s10
z10  = p010 XOR p110 = r XOR a1*b0
c1   = a1*b1 XOR z10
```

Hence `c0 XOR c1 = (a0 XOR a1)(b0 XOR b1)`.

## `PRF_HD1`: strict physical-register transition model

For physical register `P`, OoOLyzer accepts

```text
P <- V_old
P <- V_new
```

as one `PRF_HD1` candidate only when the two joined destination writes occupy
**adjacent allocation positions in P's rename stream**.  Therefore:

- there is no intervening committed write to `P`; and
- there is no intervening transient/squashed/unjoined allocation to `P`.

The parser deliberately preserves such intervening allocations as stream
positions that break the pair.  The regression test
`scripts/test_prf_adjacency.py` checks both cases.

The one-bit dynamic sample is

```text
L = (V_old XOR V_new) & 1
```

using destination values obtained from gem5 execution records joined to the
rename allocations.  Symbolic PINI semantics are used separately for the
simulator-support distribution test.

## `COMPLETE_SUM1`

When enabled, tagged values completing at the same backend tick form an
explicit one-bit aggregate model.  This is a model-level completion
observation; it is **not** evidence of a literal analog shared writeback bus.

## Scope versus support

`LOCAL`/`CROSS_COMPOSITION` records where an observation is formed.  For the
controlled chain, cross observations may span `G1/LIN`, `LIN/G2`, or `G1/G2`.
This is independent of the support decision: a cross observation is not
automatically a PINI violation.

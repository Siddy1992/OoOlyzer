// =====================================================================
// toffoli.S  -  two-share masked Toffoli gate  (a,b,c) -> (a,b,c+ab)
// Target: RV32IM.  Leaf function (uses only a0-a5, t0).
//
// GD23 arithmetic:  c0' = c0 ^ a0b0 ^ a0b1 ,  c1' = c1 ^ a1b1 ^ a1b0
//   so c0'^c1' = c ^ ab  (correct two-share masking).
//
// Register mapping = OoOLyzer Case Study 1 (variable . share):
//   a0 = x10 : a.0     a3 = x13 : a.1     (variable a's two shares)
//   a1 = x11 : b.0     a4 = x14 : b.1     (variable b's two shares)
//   a2 = x12 : c.0     a5 = x15 : c.1     (variable c's two shares, accumulated)
//   t0 = x5  : cross-product temporary (the RIL hotspot)
//
// Conflict pairs to watch: {a.0,a.1}=x10/x13, {b.0,b.1}=x11/x14, {c.0,c.1}=x12/x15.
// The dominant predicted event is the output-share transition c.0 -> c.1
// (x12 -> x15) when the renamer reuses one physical register for both.
//
// NOTE: domain-separated masking WITHOUT GD23 index-shifting. The cross-domain
// ANDs (a.0 & b.1, a.1 & b.0) recombine operands directly; a shift-protected
// variant is a future addition.
// =====================================================================

    .text
    .balign 4
    .global toffoli
toffoli:
    # --- domain A : c.0 += a.0*b.0 + a.0*b.1 ---
    and  t0, a0, a1        # t0 = a.0 & b.0      (same-domain product)
    xor  a2, a2, t0        # c.0 ^= a.0 b.0
    and  t0, a0, a4        # t0 = a.0 & b.1      (CROSS-domain operands)
    xor  a2, a2, t0        # c.0 ^= a.0 b.1

    # --- domain B : c.1 += a.1*b.1 + a.1*b.0 ---
    and  t0, a3, a4        # t0 = a.1 & b.1      (same-domain product)
    xor  a5, a5, t0        # c.1 ^= a.1 b.1
    and  t0, a3, a1        # t0 = a.1 & b.0      (CROSS-domain operands)
    xor  a5, a5, t0        # c.1 ^= a.1 b.0

    li   t0, 0             # clear temporary
    ret

// =====================================================================
// harness.S  -  minimal bare-metal SE-mode driver for masked PRESENT
// Target: RV32IM, syscall-emulation (gem5 SE mode)
//
// Calling convention expected by masked_present (from RISCV_masked-PRESENT.S):
//   a0 = &shares0   state share 0   ([0] = low 32 bits, [4] = high 32 bits)
//   a1 = &shares1   state share 1
//   a2 = &RK_H0     high round-key words, share 0   (32 entries)
//   a3 = &RK_H1     high round-key words, share 1   (32 entries)
//   a4 = &RK_L0     low  round-key words, share 0   (32 entries)
//   a5 = &RK_L1     low  round-key words, share 1   (32 entries)
//
// Plaintext  P      = shares0 ^ shares1
// Round key  RK_hi  = RK_H0 ^ RK_H1 ,  RK_lo = RK_L0 ^ RK_L1
//
// Values below are FIXED for deterministic trace generation. The SCA phase
// will replace this data section with a parameterized / randomized generator.
// =====================================================================

    .option norelax
    .text
    .balign 4
    .global _start
_start:
    la   sp, _stack_top
    andi sp, sp, -16            // 16-byte align (defensive)

    la   a0, shares0
    la   a1, shares1
    la   a2, RK_H0
    la   a3, RK_H1
    la   a4, RK_L0
    la   a5, RK_L1

    jal  ra, masked_present

    // exit(0) — gem5 SE mode emulates the RISC-V Linux exit syscall (93)
    li   a7, 93
    li   a0, 0
    ecall
1:  j    1b                     // never reached

// ---------------------------------------------------------------------
    .section .data
    .balign 4

// 64-bit state, two shares.  word0 = low half, word1 = high half.
shares0:  .word 0xDEADBEEF, 0x01234567     // share 0 (the mask)
shares1:  .word 0x0BADF00D, 0x89ABCDEF     // share 1 = P ^ mask

// 32 round keys, each split high/low and into two shares.
// Fixed pseudo-pattern for the smoke test; real schedule comes later.
    .balign 4
RK_H0:  .rept 32
        .word 0x12345678
        .endr
RK_H1:  .rept 32
        .word 0x9ABCDEF0
        .endr
RK_L0:  .rept 32
        .word 0x0F0F0F0F
        .endr
RK_L1:  .rept 32
        .word 0xF0F0F0F0
        .endr

// ---------------------------------------------------------------------
    .section .bss
    .balign 16
_stack:     .space 8192
_stack_top:

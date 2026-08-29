// =====================================================================
// harness.S  -  SE-mode driver for the masked Toffoli gate (RV32IM).
//
// Loops the Toffoli ITERS times. Each iteration reloads the six share words
// so every call is identical (known-answer) and keeps the register file
// churning, which - with a small physical register file (--prf 36) - drives
// the rename reuse that OoOLyzer detects as RIL.
//
// shares[] layout (words): a.0, b.0, c.0, a.1, b.1, c.1
//   plaintext a = a.0^a.1, b = b.0^b.1, c = c.0^c.1
// =====================================================================

    .equ ITERS, 2000

    .option norelax
    .text
    .balign 4
    .global _start
_start:
    la   sp, _stack_top
    andi sp, sp, -16
    la   s0, shares            # s0 (x8): base pointer  (not touched by toffoli)
    li   s1, ITERS             # s1 (x9): counter        (not touched by toffoli)
1:
    lw   a0, 0(s0)             # a.0
    lw   a1, 4(s0)             # b.0
    lw   a2, 8(s0)             # c.0
    lw   a3, 12(s0)            # a.1
    lw   a4, 16(s0)            # b.1
    lw   a5, 20(s0)            # c.1
    jal  ra, toffoli
    addi s1, s1, -1
    bnez s1, 1b

    li   a7, 93                # exit(0)
    li   a0, 0
    ecall
2:  j    2b

    .section .data
    .balign 4
shares:
    .word 0xA5A5A5A5           # a.0
    .word 0x0F0F0F0F           # b.0
    .word 0x12345678           # c.0
    .word 0x5A5A5A5A           # a.1   (a = a.0^a.1 = 0xFFFFFFFF)
    .word 0xF0F0F0F0           # b.1   (b = b.0^b.1 = 0xFFFFFFFF)
    .word 0x87654321           # c.1   (c = c.0^c.1 = 0x95511559)

    .section .bss
    .balign 16
_stack:     .space 4096
_stack_top:

    .file   "pini_hpc2.S"
    .option norvc                 # canonical insns -> clean gem5 traces
    .section .text
    .align 2

    .macro MARK id
    li   s11, (0xC0DE0000 + \id)
    .endm

    .globl pini_and2_hpc2
    .type  pini_and2_hpc2, @function
pini_and2_hpc2:
    addi sp, sp, -16
    sw   s11, 12(sp)              # s11 is callee-saved (used as marker reg)

    lw   t0, 0(a0)               # a0 (share 0 of a)
    lw   t1, 4(a0)               # a1 (share 1 of a)
    lw   t2, 0(a1)               # b0
    lw   t3, 4(a1)               # b1
    mv   t4, a3                   # r  (fresh, symmetric)

    # ---- domain 0 : z01 producer ----
    MARK 0x01
    not  t5, t0                  # ~a0
    and  t5, t5, t4              # (~a0) & r
    xor  t6, t3, t4              # b1 ^ r        (b1 masked before entering dom0)
    and  t6, t0, t6              # a0 & (b1 ^ r)
    xor  t6, t5, t6              # z01

    # ---- domain 0 : final update of c0 ----
    MARK 0xF0
    and  t5, t0, t2              # a0 & b0
    xor  t5, t5, t6              # c0 = a0&b0 ^ z01
    sw   t5, 0(a2)

    # ---- domain 1 : z10 producer ----
    MARK 0x10
    not  t5, t1                  # ~a1
    and  t5, t5, t4              # (~a1) & r
    xor  t6, t2, t4              # b0 ^ r
    and  t6, t1, t6              # a1 & (b0 ^ r)
    xor  t6, t5, t6              # z10

    # ---- domain 1 : final update of c1 ----
    MARK 0xF1
    and  t5, t1, t3              # a1 & b1
    xor  t5, t5, t6              # c1 = a1&b1 ^ z10
    sw   t5, 4(a2)

    lw   s11, 12(sp)
    addi sp, sp, 16
    ret
    .size pini_and2_hpc2, .-pini_and2_hpc2

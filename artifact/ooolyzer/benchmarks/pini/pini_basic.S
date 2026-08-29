#ifndef TEST_MODE
#define TEST_MODE 3
#endif
#ifndef ITERATIONS
#define ITERATIONS 64
#endif
    .section .text
    .globl _start
_start:
    li a7, 0x13579bdf       # PRNG state
    li a6, ITERATIONS
loop:
    # xorshift32 to vary input shares and R0/R1
    slli a5,a7,13; xor a7,a7,a5
    srli a5,a7,17; xor a7,a7,a5
    slli a5,a7,5;  xor a7,a7,a5
    # D0 inputs s0=A0,s1=B0,s7=D0,s8=E0; D1 t0=A1,t1=B1,a0=D1,a1=E1
    andi s0,a7,1; srli a5,a7,1; andi t0,a5,1
    srli a5,a7,2; andi s1,a5,1; srli a5,a7,3; andi t1,a5,1
    srli a5,a7,4; andi s7,a5,1; srli a5,a7,5; andi a0,a5,1
    srli a5,a7,6; andi s8,a5,1; srli a5,a7,7; andi a1,a5,1
    srli a5,a7,8; andi a2,a5,1   # R0
    srli a5,a7,9; andi a3,a5,1   # R1

    # PINI1 G1: c=a*b, canonical Algorithm-2 specialization to d=2.
    .globl PINI__G1__R__S01
PINI__G1__R__S01: xor a4,t1,a2
    .globl PINI__G1__D0__NOT_A0
PINI__G1__D0__NOT_A0: xori s2,s0,1
    .globl PINI__G1__D0__P0_01
PINI__G1__D0__P0_01: and s3,s2,a2
    .globl PINI__G1__D0__P1_01
PINI__G1__D0__P1_01: and s4,s0,a4
    .globl PINI__G1__R__Z01
PINI__G1__R__Z01: xor a5,s3,s4
    .globl PINI__G1__D0__A0B0
PINI__G1__D0__A0B0: and s5,s0,s1
    .globl PINI__G1__D0__C0
PINI__G1__D0__C0: xor s6,s5,a5
    .globl PINI__G1__R__S10
PINI__G1__R__S10: xor a4,s1,a2
    .globl PINI__G1__D1__NOT_A1
PINI__G1__D1__NOT_A1: xori t2,t0,1
    .globl PINI__G1__D1__P0_10
PINI__G1__D1__P0_10: and t3,t2,a2
    .globl PINI__G1__D1__P1_10
PINI__G1__D1__P1_10: and t4,t0,a4
    .globl PINI__G1__R__Z10
PINI__G1__R__Z10: xor a5,t3,t4
    .globl PINI__G1__D1__A1B1
PINI__G1__D1__A1B1: and t5,t0,t1
    .globl PINI__G1__D1__C1
PINI__G1__D1__C1: xor t6,t5,a5
#if TEST_MODE >= 2
    .globl PINI__LIN__D0__Y0
PINI__LIN__D0__Y0: xor s9,s6,s7
    .globl PINI__LIN__D1__Y1
PINI__LIN__D1__Y1: xor a2,t6,a0
#endif
#if TEST_MODE >= 3
    # G2 multiplies Y by E using fresh R1. D0/D1 destinations remain separated.
    .globl PINI__G2__R__S01
PINI__G2__R__S01: xor a4,a1,a3
    .globl PINI__G2__D0__NOT_A0
PINI__G2__D0__NOT_A0: xori s2,s9,1
    .globl PINI__G2__D0__P0_01
PINI__G2__D0__P0_01: and s3,s2,a3
    .globl PINI__G2__D0__P1_01
PINI__G2__D0__P1_01: and s4,s9,a4
    .globl PINI__G2__R__Z01
PINI__G2__R__Z01: xor a5,s3,s4
    .globl PINI__G2__D0__A0B0
PINI__G2__D0__A0B0: and s5,s9,s8
    .globl PINI__G2__D0__C0
PINI__G2__D0__C0: xor s6,s5,a5
    .globl PINI__G2__R__S10
PINI__G2__R__S10: xor a4,s8,a3
    .globl PINI__G2__D1__NOT_A1
PINI__G2__D1__NOT_A1: xori t2,a2,1
    .globl PINI__G2__D1__P0_10
PINI__G2__D1__P0_10: and t3,t2,a3
    .globl PINI__G2__D1__P1_10
PINI__G2__D1__P1_10: and t4,a2,a4
    .globl PINI__G2__R__Z10
PINI__G2__R__Z10: xor a5,t3,t4
    .globl PINI__G2__D1__A1B1
PINI__G2__D1__A1B1: and t5,a2,a1
    .globl PINI__G2__D1__C1
PINI__G2__D1__C1: xor t6,t5,a5
#endif
    addi a6,a6,-1
    bnez a6,loop
    li a0,0; li a7,93; ecall

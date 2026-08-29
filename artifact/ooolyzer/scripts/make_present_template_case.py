#!/usr/bin/env python3
import argparse
from pathlib import Path

SECRET_KEY = '123456789ABCDEF01122'
ROUND0 = int(SECRET_KEY[:16], 16)
START = 0xCA010000
END = 0xCA040000


def rng32(state):
    state = (1664525 * state + 1013904223) & 0xffffffff
    return state, state


def seed_rng(nib, var, rep):
    s = 0x12345678
    s ^= (nib * 0x9E3779B9) & 0xffffffff
    s ^= (var * 0x27D4EB2D) & 0xffffffff
    s ^= (rep * 0x165667B1) & 0xffffffff
    return s & 0xffffffff


def force_nibble(k64, nib, guess):
    shift = 4 * (15 - nib)
    k64 &= ~(0xf << shift)
    k64 |= (guess & 0xf) << shift
    return k64


def row_state(nib, mode, guess, var, rep):
    pt = (var & 0xf) << (4 * (15 - nib))
    pt_h = (pt >> 32) & 0xffffffff
    pt_l = pt & 0xffffffff

    st = seed_rng(nib, var, rep)
    st, sh00 = rng32(st)
    st, sh01 = rng32(st)
    sh10 = sh00 ^ pt_h
    sh11 = sh01 ^ pt_l

    k64 = ROUND0 if mode == 0 else force_nibble(ROUND0, nib, guess)
    rk_h = (k64 >> 32) & 0xffffffff
    rk_l = k64 & 0xffffffff

    st, rk_h0 = rng32(st)
    st, rk_l0 = rng32(st)
    rk_h1 = rk_h0 ^ rk_h
    rk_l1 = rk_l0 ^ rk_l

    # State at entry to the first S-box, matching masked_present's round-0
    # share-wise AddRoundKey in the RV32 implementation.
    sh01 ^= rk_h0
    sh11 ^= rk_h1
    sh00 ^= rk_l0
    sh10 ^= rk_l1

    return [x & 0xffffffff for x in (sh00, sh01, sh10, sh11)], pt


def generate(nib, reps, mode, guess=None):
    rows = []
    row_id = 0
    if mode == 'secret':
        imode = 0
        iguess = -1
    else:
        imode = 1
        if guess is None or not 0 <= guess <= 15:
            raise ValueError('reference mode needs guess 0..15')
        iguess = guess
    for var in range(16):
        for rep in range(reps):
            state, pt = row_state(nib, imode, iguess, var, rep)
            rows.append((row_id, nib, imode, iguess, var, rep, pt, state))
            row_id += 1
    return rows

def write_meta(path, rows):
    with open(path, 'w') as f:
        f.write(f'# secret_key={SECRET_KEY}\n')
        f.write('row_id,target_nibble,mode,key_guess,var_nibble,rep,pt\n')
        for row_id, nib, mode, guess, var, rep, pt, _ in rows:
            f.write(f'{row_id},{nib},{mode},{guess},{var},{rep},{pt:016X}\n')


def write_asm(path, rows):
    with open(path, 'w') as f:
        f.write('''    .option norelax\n    .text\n    .balign 4\n    .global _start\n_start:\n    la sp, _stack_top\n    andi sp, sp, -16\n    la s6, row_data\n    li s7, 0\n    li s0, %d\n1:\n    la a0, shares0\n    la a1, shares1\n    lw t0, 0(s6)\n    sw t0, 0(a0)\n    lw t0, 4(s6)\n    sw t0, 4(a0)\n    lw t0, 8(s6)\n    sw t0, 0(a1)\n    lw t0, 12(s6)\n    sw t0, 4(a1)\n    lw t6, 16(s6)\n    jal ra, sbox\n    lw t6, 20(s6)\n    addi s6, s6, 24\n    addi s7, s7, 1\n    blt s7, s0, 1b\n    li a7, 93\n    li a0, 0\n    ecall\n2:  j 2b\n\n    .section .data\n    .balign 4\nrow_data:\n''' % len(rows))
        for row_id, _, _, _, _, _, _, state in rows:
            start = START | row_id
            end = END | row_id
            vals = state + [start, end]
            f.write('    .word ' + ', '.join(f'0x{x:08x}' for x in vals) + '\n')
        f.write('''\n    .section .bss\n    .balign 16\nshares0: .space 8\nshares1: .space 8\n_stack: .space 16384\n_stack_top:\n''')


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--nibble', type=int, required=True)
    p.add_argument('--reps', type=int, default=3)
    p.add_argument('--mode', choices=['secret','reference'], required=True)
    p.add_argument('--guess', type=int)
    p.add_argument('--asm', required=True)
    p.add_argument('--meta', required=True)
    a = p.parse_args()
    if not 0 <= a.nibble <= 15:
        p.error('--nibble must be 0..15')
    rows = generate(a.nibble, a.reps, a.mode, a.guess)
    Path(a.asm).parent.mkdir(parents=True, exist_ok=True)
    Path(a.meta).parent.mkdir(parents=True, exist_ok=True)
    write_asm(a.asm, rows)
    write_meta(a.meta, rows)
    label = 'secret' if a.mode == 'secret' else f'g{a.guess:X}'
    print(f'nibble {a.nibble} {label}: {len(rows)} rows')


if __name__ == '__main__':
    main()

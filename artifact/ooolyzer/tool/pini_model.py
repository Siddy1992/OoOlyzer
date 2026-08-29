#!/usr/bin/env python3
BASIC_INPUT_VARS = ('A0','A1','B0','B1','D0','D1','E0','E1')
BASIC_RAND_VARS = ('R0','R1')
BASIC_DOMAIN_VARS = {
    'D0': ('A0','B0','D0','E0'),
    'D1': ('A1','B1','D1','E1'),
}


def pini1(a0, a1, b0, b1, r, prefix, sem):
    s01 = b1 ^ r
    na0 = a0 ^ 1
    p001 = na0 & r
    p101 = a0 & s01
    z01 = p001 ^ p101
    q0 = a0 & b0
    c0 = q0 ^ z01

    s10 = b0 ^ r
    na1 = a1 ^ 1
    p010 = na1 & r
    p110 = a1 & s10
    z10 = p010 ^ p110
    q1 = a1 & b1
    c1 = q1 ^ z10

    sem.update({
        (prefix,'R','S01'): s01,
        (prefix,'D0','NOT_A0'): na0,
        (prefix,'D0','P0_01'): p001,
        (prefix,'D0','P1_01'): p101,
        (prefix,'R','Z01'): z01,
        (prefix,'D0','A0B0'): q0,
        (prefix,'D0','C0'): c0,
        (prefix,'R','S10'): s10,
        (prefix,'D1','NOT_A1'): na1,
        (prefix,'D1','P0_10'): p010,
        (prefix,'D1','P1_10'): p110,
        (prefix,'R','Z10'): z10,
        (prefix,'D1','A1B1'): q1,
        (prefix,'D1','C1'): c1,
    })
    return c0, c1


def semantics_basic(inp, rnd):
    sem = {}
    c0, c1 = pini1(inp['A0'], inp['A1'], inp['B0'], inp['B1'], rnd['R0'], 'G1', sem)
    y0 = c0 ^ inp['D0']
    y1 = c1 ^ inp['D1']
    sem[('LIN','D0','Y0')] = y0
    sem[('LIN','D1','Y1')] = y1
    pini1(y0, y1, inp['E0'], inp['E1'], rnd['R1'], 'G2', sem)
    return sem


def model_info(kind):
    if kind != 'basic':
        raise ValueError(kind)
    return BASIC_INPUT_VARS, BASIC_RAND_VARS, BASIC_DOMAIN_VARS, semantics_basic


def selftest():
    for a0 in (0,1):
        for a1 in (0,1):
            for b0 in (0,1):
                for b1 in (0,1):
                    for r in (0,1):
                        sem = {}
                        c0, c1 = pini1(a0,a1,b0,b1,r,'G',sem)
                        if (c0 ^ c1) != ((a0 ^ a1) & (b0 ^ b1)):
                            return False
    return True


if __name__ == '__main__':
    raise SystemExit(0 if selftest() else 1)

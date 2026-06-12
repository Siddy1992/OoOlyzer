#include <stdint.h>
#include <stdio.h>

/* gadget from pini_hpc2.S */
void pini_and2_hpc2(const uint32_t a[2], const uint32_t b[2],
                    uint32_t c[2], uint32_t r);

/* deterministic stream -> reproducible gem5 runs; r is one fresh symmetric word */
static uint32_t st = 0x9e3779b9u;
static uint32_t rnd(void) {
    uint32_t x = st; x ^= x << 13; x ^= x >> 17; x ^= x << 5; st = x; return x;
}

#ifndef ITERS
#define ITERS 8
#endif

int main(void) {
    int fails = 0;
    volatile uint32_t sink = 0;
    for (int i = 0; i < ITERS; i++) {
        uint32_t a[2] = { rnd(), rnd() };
        uint32_t b[2] = { rnd(), rnd() };
        uint32_t r    = rnd();           /* ONE fresh, symmetric random word */
        uint32_t c[2] = { 0, 0 };
        pini_and2_hpc2(a, b, c, r);
        uint32_t got = c[0] ^ c[1];
        uint32_t exp = (a[0] ^ a[1]) & (b[0] ^ b[1]);
        if (got != exp) fails++;
        sink ^= got;
    }
    printf("pini_and2_hpc2 x%d: %s (sink=%08x)\n",
           ITERS, fails ? "FAIL" : "OK", (unsigned)sink);
    return fails ? 1 : 0;
}

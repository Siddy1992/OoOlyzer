
#include <stdint.h>

#if defined(__riscv)
#define MARKV(id, val) __asm__ __volatile__(            \
    "lui s11, 0xC0DE0\n\t"                               \
    "xor t5, %1, %1\n\t"                                 \
    "addi t5, t5, %0\n\t"                                \
    "or  s11, s11, t5"                                   \
    :: "i"(id), "r"(val) : "s11", "t5")
#else                               /* host build: no-op (for math verification) */
#define MARKV(id, val) ((void)(val))
#endif

#define ZIJ(ai, bj, rij)  ( (~(ai) & (rij)) ^ ((ai) & ((bj) ^ (rij))) )

void pini_and3_hpc2(const uint32_t a[3], const uint32_t b[3],
                    uint32_t c[3], const uint32_t r[3])
{
    uint32_t a1 = a[0], a2 = a[1], a3 = a[2];
    uint32_t b1 = b[0], b2 = b[1], b3 = b[2];
    uint32_t r12 = r[0], r13 = r[1], r23 = r[2];

    /* ---- domain 1 (touches a1 only) ---- */
    uint32_t z12 = ZIJ(a1, b2, r12); MARKV(0x12, z12);
    uint32_t z13 = ZIJ(a1, b3, r13); MARKV(0x13, z13);
    uint32_t c1  = (a1 & b1) ^ z12 ^ z13; MARKV(0xF1, c1);

    /* ---- domain 2 (touches a2 only) ---- */
    uint32_t z21 = ZIJ(a2, b1, r12); MARKV(0x21, z21);
    uint32_t z23 = ZIJ(a2, b3, r23); MARKV(0x23, z23);
    uint32_t c2  = (a2 & b2) ^ z21 ^ z23; MARKV(0xF2, c2);

    /* ---- domain 3 (touches a3 only) ---- */
    uint32_t z31 = ZIJ(a3, b1, r13); MARKV(0x31, z31);
    uint32_t z32 = ZIJ(a3, b2, r23); MARKV(0x32, z32);
    uint32_t c3  = (a3 & b3) ^ z31 ^ z32; MARKV(0xF3, c3);

    c[0] = c1; c[1] = c2; c[2] = c3;
}

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

extern void masked_present(uint32_t *shares0, uint32_t *shares1,
                           uint32_t *rk_h0, uint32_t *rk_h1,
                           uint32_t *rk_l0, uint32_t *rk_l1);

volatile uint64_t gem5_sbox_call_count = 0;

static uint32_t rng_state;

static uint32_t rng32(void) {
    rng_state = 1664525u * rng_state + 1013904223u;
    return rng_state;
}

static void seed_rng(int nib, int var, int rep) {
    uint32_t s = 0x12345678u;
    s ^= (uint32_t)(nib * 0x9E3779B9u);
    s ^= (uint32_t)(var * 0x27D4EB2Du);
    s ^= (uint32_t)(rep * 0x165667B1u);
    rng_state = s;
}

static inline void gem5_row_start(uint32_t row_id) {
    uint64_t marker = 0xC0FFEE0100000000ULL | row_id;
    asm volatile("mv t6, %0" :: "r"(marker) : "t6", "memory");
}

static inline void gem5_row_end(uint32_t row_id) {
    uint64_t marker = 0xC0FFEE0400000000ULL | row_id;
    asm volatile("mv t6, %0" :: "r"(marker) : "t6", "memory");
}

static const uint8_t present_sbox[16] = {
    0xC, 0x5, 0x6, 0xB,
    0x9, 0x0, 0xA, 0xD,
    0x3, 0xE, 0xF, 0x8,
    0x4, 0x7, 0x1, 0x2
};

static void present80_key_schedule(uint8_t key[10],
                                   uint32_t rk_h[32],
                                   uint32_t rk_l[32]) {
    for (int round = 0; round < 32; round++) {
        rk_h[round] =
            ((uint32_t)key[0] << 24) |
            ((uint32_t)key[1] << 16) |
            ((uint32_t)key[2] << 8) |
            ((uint32_t)key[3]);

        rk_l[round] =
            ((uint32_t)key[4] << 24) |
            ((uint32_t)key[5] << 16) |
            ((uint32_t)key[6] << 8) |
            ((uint32_t)key[7]);

        uint8_t old[10];
        for (int i = 0; i < 10; i++)
            old[i] = key[i];

        for (int i = 0; i < 80; i++) {
            int src = (i + 61) % 80;
            int src_byte = src / 8;
            int src_bit = 7 - (src % 8);

            int dst_byte = i / 8;
            int dst_bit = 7 - (i % 8);

            uint8_t bit = (old[src_byte] >> src_bit) & 1u;

            if (bit)
                key[dst_byte] |= (1u << dst_bit);
            else
                key[dst_byte] &= ~(1u << dst_bit);
        }

        uint8_t top = key[0] >> 4;
        top = present_sbox[top];
        key[0] = (key[0] & 0x0F) | (top << 4);

        int rc = round + 1;
        key[7] ^= (uint8_t)(rc >> 1);
        key[8] ^= (uint8_t)(rc << 7);
    }
}

static void force_round0_nibble(uint32_t rk_h[32],
                                uint32_t rk_l[32],
                                int nib,
                                int guess) {
    uint64_t k64 = ((uint64_t)rk_h[0] << 32) | rk_l[0];
    int shift = 4 * (15 - nib);

    k64 &= ~((uint64_t)0xFULL << shift);
    k64 |= ((uint64_t)(guess & 0xF) << shift);

    rk_h[0] = (uint32_t)(k64 >> 32);
    rk_l[0] = (uint32_t)(k64 & 0xFFFFFFFFu);
}

static void run_one(uint32_t row_id,
                    int target_nibble,
                    int mode,
                    int guess,
                    int var,
                    int rep,
                    uint32_t base_rk_h[32],
                    uint32_t base_rk_l[32]) {
    seed_rng(target_nibble, var, rep);

    uint64_t pt64 = 0;
    int shift = 4 * (15 - target_nibble);
    pt64 |= ((uint64_t)(var & 0xF) << shift);

    uint32_t pt_h = (uint32_t)(pt64 >> 32);
    uint32_t pt_l = (uint32_t)(pt64 & 0xFFFFFFFFu);

    uint32_t shares0[2];
    uint32_t shares1[2];

    shares0[0] = rng32();
    shares0[1] = rng32();

    shares1[0] = shares0[0] ^ pt_h;
    shares1[1] = shares0[1] ^ pt_l;

    uint32_t rk_h[32], rk_l[32];
    uint32_t rk_h0[32], rk_h1[32], rk_l0[32], rk_l1[32];

    for (int r = 0; r < 32; r++) {
        rk_h[r] = base_rk_h[r];
        rk_l[r] = base_rk_l[r];
    }

    if (mode == 1)
        force_round0_nibble(rk_h, rk_l, target_nibble, guess);

    for (int r = 0; r < 32; r++) {
        rk_h0[r] = rng32();
        rk_l0[r] = rng32();

        rk_h1[r] = rk_h0[r] ^ rk_h[r];
        rk_l1[r] = rk_l0[r] ^ rk_l[r];
    }

    gem5_sbox_call_count = 0;

    gem5_row_start(row_id);

    masked_present(shares0, shares1,
                   rk_h0, rk_h1,
                   rk_l0, rk_l1);

    gem5_row_end(row_id);

    printf("%u,%d,%d,%d,%d,%d,%016llX\n",
           row_id,
           target_nibble,
           mode,
           guess,
           var,
           rep,
           (unsigned long long)pt64);
}

int main(int argc, char **argv) {
    int reps = 3;
    int target_only = 0;

    if (argc >= 2)
        reps = atoi(argv[1]);

    if (argc >= 3)
        target_only = atoi(argv[2]);

    uint8_t key[10] = {
        0x12, 0x34, 0x56, 0x78, 0x9A,
        0xBC, 0xDE, 0xF0, 0x11, 0x22
    };

    uint32_t rk_h[32], rk_l[32];
    uint8_t key_copy[10];

    for (int i = 0; i < 10; i++)
        key_copy[i] = key[i];

    present80_key_schedule(key_copy, rk_h, rk_l);

    printf("# secret_key=");
    for (int i = 0; i < 10; i++)
        printf("%02X", key[i]);
    printf("\n");

    printf("row_id,target_nibble,mode,key_guess,var_nibble,rep,pt\n");

    int start = 0;
    int end = 15;

    if (target_only >= 0 && target_only <= 15) {
        start = target_only;
        end = target_only;
    }

    uint32_t row_id = 0;

    for (int nib = start; nib <= end; nib++) {
        for (int var = 0; var < 16; var++) {
            for (int rep = 0; rep < reps; rep++) {
                run_one(row_id++, nib, 0, -1, var, rep, rk_h, rk_l);
            }
        }

        for (int guess = 0; guess < 16; guess++) {
            for (int var = 0; var < 16; var++) {
                for (int rep = 0; rep < reps; rep++) {
                    run_one(row_id++, nib, 1, guess, var, rep, rk_h, rk_l);
                }
            }
        }
    }

    return 0;
}


#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>

#define TEMP1 "/sys/devices/platform/soc/50b00000.pvt/hwmon/hwmon1/temp1_input"
#define TEMP2 "/sys/devices/platform/soc/52360000.pvt/hwmon/hwmon2/temp1_input"

#define REPEAT 24
#define OUTER_REPEAT 6000
#define COOL_SEC 8
#define SETTLE_SEC 2
#define AVG_READS 9
#define AVG_GAP_US 200000

extern void masked_present(uint32_t *shares0, uint32_t *shares1,
                           uint32_t *rk_h0, uint32_t *rk_h1,
                           uint32_t *rk_l0, uint32_t *rk_l1);

/*
 * Full 80-bit PRESENT key.
 * key[0] is MSB byte, key[9] is LSB byte.
 */
static const uint8_t SECRET_KEY[10] = {
    0xA7, 0x3C, 0x91, 0x0F, 0x55,
    0xC8, 0x26, 0xB4, 0xE1, 0x7D
};

static const uint8_t PRESENT_SBOX[16] = {
    0xC, 0x5, 0x6, 0xB,
    0x9, 0x0, 0xA, 0xD,
    0x3, 0xE, 0xF, 0x8,
    0x4, 0x7, 0x1, 0x2
};

static double read_one(const char *p) {
    FILE *f = fopen(p, "r");
    if (!f) return -1000.0;
    double x = 0.0;
    fscanf(f, "%lf", &x);
    fclose(f);
    return x / 1000.0;
}

static double read_temp_once(void) {
    double a = read_one(TEMP1);
    double b = read_one(TEMP2);

    if (a < -100.0 && b < -100.0) return -1000.0;
    if (a < -100.0) return b;
    if (b < -100.0) return a;

    return (a + b) / 2.0;
}

static double read_temp_avg(void) {
    double s = 0.0;
    int n = 0;

    for (int i = 0; i < AVG_READS; i++) {
        double t = read_temp_once();
        if (t > -100.0) {
            s += t;
            n++;
        }
        usleep(AVG_GAP_US);
    }

    if (n == 0) return -1000.0;
    return s / n;
}

static uint64_t xorshift64(uint64_t *st) {
    uint64_t x = *st;
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    *st = x;
    return x;
}

static uint32_t rnd32(uint64_t *st) {
    return (uint32_t)xorshift64(st);
}

/*
 * bitpos: 79 is MSB of key[0], 0 is LSB of key[9].
 */
static void force_key_bit(uint8_t key[10], int bitpos, int bitval) {
    int byte_index = 9 - (bitpos / 8);
    int bit_index  = bitpos % 8;

    if (bitval)
        key[byte_index] |= (uint8_t)(1U << bit_index);
    else
        key[byte_index] &= (uint8_t)~(1U << bit_index);
}

static int get_key_bit(const uint8_t key[10], int bitpos) {
    int byte_index = 9 - (bitpos / 8);
    int bit_index  = bitpos % 8;
    return (key[byte_index] >> bit_index) & 1;
}

/*
 * PRESENT-80 key schedule.
 * Generates 32 round keys, each 64-bit.
 */
static void present80_roundkeys(const uint8_t master[10],
                                uint32_t rk_h[32],
                                uint32_t rk_l[32]) {
    uint8_t k[10];
    memcpy(k, master, 10);

    for (int round = 0; round < 32; round++) {
        rk_h[round] = ((uint32_t)k[0] << 24) |
                      ((uint32_t)k[1] << 16) |
                      ((uint32_t)k[2] << 8)  |
                      ((uint32_t)k[3]);

        rk_l[round] = ((uint32_t)k[4] << 24) |
                      ((uint32_t)k[5] << 16) |
                      ((uint32_t)k[6] << 8)  |
                      ((uint32_t)k[7]);

        if (round == 31) break;

        /*
         * Rotate 80-bit key left by 61.
         */
        uint8_t old[10];
        memcpy(old, k, 10);
        memset(k, 0, 10);

        for (int src = 0; src < 80; src++) {
            int src_byte = src / 8;
            int src_bit  = 7 - (src % 8);
            int bit = (old[src_byte] >> src_bit) & 1;

            int dst = (src + 61) % 80;
            int dst_byte = dst / 8;
            int dst_bit  = 7 - (dst % 8);

            if (bit)
                k[dst_byte] |= (uint8_t)(1U << dst_bit);
        }

        /*
         * S-box on bits 79..76, i.e., high nibble of k[0].
         */
        uint8_t top = k[0] >> 4;
        k[0] = (uint8_t)((PRESENT_SBOX[top] << 4) | (k[0] & 0x0F));

        /*
         * XOR round counter r=round+1 into bits 19..15.
         */
        uint8_t rc = (uint8_t)(round + 1);
        for (int j = 0; j < 5; j++) {
            int bit = (rc >> j) & 1;
            int pos = 15 + j;

            int byte_index = 9 - (pos / 8);
            int bit_index  = pos % 8;

            if (bit)
                k[byte_index] ^= (uint8_t)(1U << bit_index);
        }
    }
}

static void share64(uint64_t value, uint64_t *rng,
                    uint32_t sh0[2], uint32_t sh1[2]) {
    uint32_t lo = (uint32_t)(value & 0xffffffffULL);
    uint32_t hi = (uint32_t)(value >> 32);

    sh0[0] = rnd32(rng);
    sh0[1] = rnd32(rng);

    sh1[0] = sh0[0] ^ lo;
    sh1[1] = sh0[1] ^ hi;
}

static void mask_roundkeys(uint32_t rk_h[32], uint32_t rk_l[32],
                           uint64_t *rng,
                           uint32_t rk_h0[32], uint32_t rk_h1[32],
                           uint32_t rk_l0[32], uint32_t rk_l1[32]) {
    for (int r = 0; r < 32; r++) {
        rk_h0[r] = rnd32(rng);
        rk_h1[r] = rk_h0[r] ^ rk_h[r];

        rk_l0[r] = rnd32(rng);
        rk_l1[r] = rk_l0[r] ^ rk_l[r];
    }
}

static double measure_case(const uint8_t key[10], uint64_t *rng) {
    uint32_t shares0[2], shares1[2];

    uint32_t rk_h[32], rk_l[32];
    uint32_t rk_h0[32], rk_h1[32], rk_l0[32], rk_l1[32];

    uint64_t plaintext = 0x0000000000000000ULL;

    present80_roundkeys(key, rk_h, rk_l);

    sleep(COOL_SEC);

    double t0 = read_temp_avg();

    for (int i = 0; i < OUTER_REPEAT; i++) {
        share64(plaintext, rng, shares0, shares1);
        mask_roundkeys(rk_h, rk_l, rng, rk_h0, rk_h1, rk_l0, rk_l1);

        masked_present(shares0, shares1, rk_h0, rk_h1, rk_l0, rk_l1);
    }

    sleep(SETTLE_SEC);

    double t1 = read_temp_avg();

    return t1 - t0;
}

int main(int argc, char **argv) {
    setvbuf(stdout, NULL, _IOLBF, 0);

    if (argc != 2) {
        fprintf(stderr, "Usage: %s <bitpos-0-to-79>\n", argv[0]);
        return 1;
    }

    int bitpos = atoi(argv[1]);
    if (bitpos < 0 || bitpos > 79) {
        fprintf(stderr, "Invalid bit position. Use 0..79.\n");
        return 1;
    }

    uint8_t ref0_key[10];
    uint8_t ref1_key[10];
    uint8_t sec_key[10];

    memcpy(ref0_key, SECRET_KEY, 10);
    memcpy(ref1_key, SECRET_KEY, 10);
    memcpy(sec_key,  SECRET_KEY, 10);

    force_key_bit(ref0_key, bitpos, 0);
    force_key_bit(ref1_key, bitpos, 1);

    uint64_t rng = 0x123456789abcdefULL ^
                   (uint64_t)time(NULL) ^
                   ((uint64_t)bitpos << 32);

    printf("# bitpos rep ref0 ref1 secret expected\n");

    for (int r = 0; r < REPEAT; r++) {
        double ref0 = measure_case(ref0_key, &rng);
        double ref1 = measure_case(ref1_key, &rng);
        double sec  = measure_case(sec_key,  &rng);

        int exp = get_key_bit(SECRET_KEY, bitpos);

        printf("%d %d %.6f %.6f %.6f %d\n",
               bitpos, r, ref0, ref1, sec, exp);
    }

    return 0;
}

#pragma once

#include <array>
#include <cstdint>
#include <fstream>

namespace gem5_o3_leak
{
inline bool initialized = false;
inline bool row_active = false;

inline uint64_t current_row = 0;
inline uint64_t event_count = 0;
inline uint64_t rename_count = 0;
inline uint64_t write_count = 0;
inline uint64_t strict_pair_count = 0;

inline std::array<int, 1024> current_arch_for_phys;
inline std::array<int, 1024> last_writer_arch_for_phys;
inline std::array<uint64_t, 1024> last_value_for_phys;
inline std::array<bool, 1024> has_last_write;

inline std::array<uint64_t, 4> leak_sum;

inline std::ofstream out;
inline std::ofstream evout;

static inline void ensureInit()
{
    if (initialized)
        return;

    current_arch_for_phys.fill(-1);
    last_writer_arch_for_phys.fill(-1);
    last_value_for_phys.fill(0);
    has_last_write.fill(false);
    leak_sum.fill(0);

    out.open("gem5_physreg_leak.csv");
    out << "row_id,leak1,leak2,leak3,leak4,events,renames,writes,strict_pairs\n";

    evout.open("gem5_physreg_events.csv");
    evout << "row_id,channel,phys,prev_arch,curr_arch,prev_val,curr_val,hd\n";

    initialized = true;
}

static inline int channelForPair(int a, int b)
{
    if ((a == 9  && b == 6)  || (a == 6  && b == 9))  return 0; // s1 <-> t1
    if ((a == 18 && b == 7)  || (a == 7  && b == 18)) return 1; // s2 <-> t2
    if ((a == 19 && b == 28) || (a == 28 && b == 19)) return 2; // s3 <-> t3
    if ((a == 20 && b == 29) || (a == 29 && b == 20)) return 3; // s4 <-> t4
    return -1;
}

static inline int hw64(uint64_t x)
{
    return __builtin_popcountll(x);
}

static inline bool isMarker(uint64_t v)
{
    return (v & 0xFFFFFF0000000000ULL) == 0xC0FFEE0000000000ULL;
}

static inline void emitRow()
{
    ensureInit();

    out << current_row << ","
        << leak_sum[0] << ","
        << leak_sum[1] << ","
        << leak_sum[2] << ","
        << leak_sum[3] << ","
        << event_count << ","
        << rename_count << ","
        << write_count << ","
        << strict_pair_count << "\n";

    out.flush();
}

static inline void resetRow(uint64_t row)
{
    ensureInit();

    current_row = row;
    leak_sum.fill(0);
    event_count = 0;
    rename_count = 0;
    write_count = 0;
    strict_pair_count = 0;
    row_active = true;
}

static inline void handleMarker(uint64_t v)
{
    uint64_t type = (v >> 32) & 0xFFULL;
    uint64_t row  = v & 0xFFFFFFFFULL;

    if (type == 1) {
        resetRow(row);
    } else if (type == 4) {
        if (row_active) {
            emitRow();
            row_active = false;
        }
    }
}

static inline void onRename(int arch, int phys)
{
    ensureInit();

    if (phys < 0 || phys >= (int)current_arch_for_phys.size())
        return;

    if (row_active)
        rename_count++;

    current_arch_for_phys[phys] = arch;
}

static inline void onIntWrite(int phys, uint64_t old_val, uint64_t new_val)
{
    ensureInit();

    if (phys < 0 || phys >= (int)current_arch_for_phys.size())
        return;

    if (isMarker(new_val)) {
        handleMarker(new_val);
        return;
    }

    int curr_arch = current_arch_for_phys[phys];

    if (row_active)
        write_count++;

    if (row_active && has_last_write[phys]) {
        int prev_arch = last_writer_arch_for_phys[phys];
        int ch = channelForPair(prev_arch, curr_arch);

        if (ch >= 0 && ch < 4) {
            uint64_t hd =
                (uint64_t)hw64(last_value_for_phys[phys] ^ new_val);

            leak_sum[ch] += hd;
            event_count++;
            strict_pair_count++;

            evout << current_row << ","
                  << ch + 1 << ","
                  << phys << ","
                  << prev_arch << ","
                  << curr_arch << ","
                  << "0x" << std::hex << last_value_for_phys[phys] << ","
                  << "0x" << std::hex << new_val << ","
                  << std::dec << hd << "\n";

            evout.flush();
        }
    }

    last_writer_arch_for_phys[phys] = curr_arch;
    last_value_for_phys[phys] = new_val;
    has_last_write[phys] = true;
}
}


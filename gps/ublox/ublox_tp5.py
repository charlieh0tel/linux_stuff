#!/usr/bin/env python3

import struct


def pack_u16(n):
    return struct.pack("<H", n)

def pack_s16(n):
    return struct.pack("<h", n)

def pack_u32(n):
    return struct.pack("<I", n)

def pack_s32(n):
    return struct.pack("<i", n)


# CFG-TP5

CFG_TP5_FLAG_ACTIVE = (1<<0)
CFG_TP5_FLAG_LOCK_GNSS_FREQ = (1<<1)
CFG_TP5_FLAG_LOCKED_OTHER_SET = (1<<2)
CFG_TP5_FLAG_IS_FREQ = (1<<3)
CFG_TP5_FLAG_IS_LENGTH = (1<<4)
CFG_TP5_FLAG_IS_ALIGN_TO_TOW = (1<<5)
CFG_TP5_FLAG_RISING_EDGE = (1<<6)
CFG_TP5_FLAG_GRID_UTC = (0<<7)
CFG_TP5_FLAG_GRID_GPS = (1<<7)
CFG_TP5_FLAG_GRID_GLONASS = (2<<7)
CFG_TP5_FLAG_GRID_BEIDOU = (3<<7)
CFG_TP5_FLAG_GRID_GALILEO = (4<<7)
CFG_TP5_FLAG_SYNC_LOCKONLY=(0<<11)
CFG_TP5_FLAG_SYNC_BACK=(1<<11)


buf = bytearray(32)
flags = (CFG_TP5_FLAG_ACTIVE | CFG_TP5_FLAG_LOCK_GNSS_FREQ |
         CFG_TP5_FLAG_IS_LENGTH |
         CFG_TP5_FLAG_IS_ALIGN_TO_TOW | CFG_TP5_FLAG_RISING_EDGE |
         CFG_TP5_FLAG_GRID_UTC | CFG_TP5_FLAG_SYNC_LOCKONLY)

buf[0] = 0                             # tpIdx
buf[1] = 1                             # version
buf[2] = 0                             # reserved
buf[3] = 0                             # reserved
buf[4:6] = pack_s16(25)                # ant cable delay [ns]
buf[6:8] = pack_s16(0)                 # rf group delay [ns]
buf[8:12] = pack_u32(1_000_000)        # freq [Hz] or period [us]
buf[12:16] = pack_u32(1_000_000)       # lock freq [Hz] or period [us]
buf[16:20] = pack_u32(500_000)         # pulse length [us] or duty cycle [2^-32]
buf[20:24] = pack_u32(500_000)         # lock pulse length [us] or duty cycle [2^-32]
buf[24:28] = pack_s32(0)               # user delay [ns]
buf[28:32] = pack_u32(flags)           # flags

u = struct.unpack_from('<BBHhhLLLLlL', buf, 0)
print(u)
print()


# UBX-CFG-TP5 class and id:
print("ubxtool -c 0x06,0x31,", end='')
print(",".join("0x{:02x}".format(int(b)) for b in buf))



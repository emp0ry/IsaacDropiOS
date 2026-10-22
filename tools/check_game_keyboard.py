#!/usr/bin/env python3
"""Read-only validation of the specific user-owned game keyboard binding."""
import pathlib
import struct
import sys
import uuid

data = pathlib.Path(sys.argv[1]).read_bytes()
assert struct.unpack_from('<I', data)[0] == 0xFEEDFACF
segments = []
image_uuid = None
cursor = 32
for _ in range(struct.unpack_from('<I', data, 16)[0]):
    command, size = struct.unpack_from('<II', data, cursor)
    if command == 0x19:
        va, length, offset, file_size = struct.unpack_from('<QQQQ', data, cursor+24)
        segments.append((va, offset, file_size))
    if command == 0x1B:
        image_uuid = str(uuid.UUID(bytes=data[cursor+8:cursor+24])).upper()
    cursor += size
assert image_uuid == 'F4357753-A25F-30EE-BACF-63709F902895'

def file_offset(va):
    return next(offset+va-base for base, offset, size in segments if base <= va < base+size)

base = 0x100000000
for rva in (0x51CC, 0x52BC):
    assert struct.unpack_from('<I', data, file_offset(base+rva))[0] == 0xA9BC5FF8
hid_table = file_offset(base+0x945AD4)
print('Native key values:', {hid: struct.unpack_from('<i', data, hid_table+hid*4)[0] for hid in (40,44,88)})
assert struct.unpack_from('<i', data, hid_table+44*4)[0] == 32
assert struct.unpack_from('<i', data, hid_table+40*4)[0] == -1
assert struct.unpack_from('<i', data, hid_table+88*4)[0] == 335
print('Game keyboard verified: supported UUID, native key handlers, HID Space 44 -> native Space 32')

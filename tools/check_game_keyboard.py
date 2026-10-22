#!/usr/bin/env python3
"""Read-only validation of the specific user-owned game keyboard binding."""
import pathlib
import re
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

source = (pathlib.Path(__file__).resolve().parents[1] / 'src/ISDNativeInput.mm').read_text()
ctrl = source.split('static bool KeyboardDropCodeMatches',1)[1].split('static bool RestartCodeMatches',1)[0]
signatures = re.findall(r'MatchWords\(image\+(0x[0-9a-f]+),\{([^}]+)\}\)', ctrl)
assert len(signatures) == 4
for address, words in signatures:
    expected = tuple(int(word,16) for word in words.split(','))
    assert struct.unpack_from('<'+'I'*len(expected),data,file_offset(base+int(address,16))) == expected
table = file_offset(base+0xa94958)
methods = struct.unpack_from('<'+'Q'*39,data,table)
assert tuple(word & 0xffffffff for word in methods[9:12]) == (0x8a7fec,0x8a8098,0x8a8150)
assert all(0x4000 <= (word & 0xffffffff) < 0x904000 for word in methods)
keyboard_name = b'N4KAGE5Input14DeviceKeyboardE\0'
assert data[file_offset(base+0x95f479):][:len(keyboard_name)] == keyboard_name
assert struct.unpack_from('<Q',data,table-16)[0] == 0
assert struct.unpack_from('<Q',data,table-8)[0] & 0xffffffff == 0xa94a90
print('Ctrl ABI verified: native short/hold callers, manager frame layout, keyboard RTTI and all 39 methods')

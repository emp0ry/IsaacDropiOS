#!/usr/bin/env python3
"""Read-only presentation ABI check against the user's supported game binary."""
from pathlib import Path
import re
import struct
import sys
import uuid

data = Path(sys.argv[1]).read_bytes()
assert struct.unpack_from('<I', data)[0] == 0xFEEDFACF
segments = []
image_uuid = None
cursor = 32
for _ in range(struct.unpack_from('<I', data, 16)[0]):
    command, size = struct.unpack_from('<II', data, cursor)
    if command == 0x19:
        address, length, offset, file_size = struct.unpack_from('<QQQQ', data, cursor + 24)
        segments.append((address, offset, file_size))
    if command == 0x1B:
        image_uuid = str(uuid.UUID(bytes=data[cursor + 8:cursor + 24])).upper()
    cursor += size
assert image_uuid == 'F4357753-A25F-30EE-BACF-63709F902895'

def check(rva, expected):
    address = 0x100000000 + rva
    offset = next(offset + address - base for base, offset, size in segments
                  if base <= address and address + len(expected) * 4 <= base + size)
    assert struct.unpack_from('<' + 'I' * len(expected), data, offset) == expected, hex(rva)

header = (Path(__file__).resolve().parents[1] / 'include/IsaacPresentationState.hpp').read_text()
signatures = re.findall(r'\{(0x[0-9a-f]+),\{([^}]+)\}\}', header)
assert len(signatures) == 10
for rva, words in signatures:
    check(int(rva, 16), tuple(int(word, 16) for word in words.split(',')))
# Verify the Game renderer's object addresses as well as the callees. The
# boss/large sprite and separate fullscreen ANM2 are not the cutscene object.
check(0x88eaa4, (0x91409688, 0x9136c100, 0x97f39a26, 0x91409e88))
check(0x88eabc, (0x91473e88, 0x911c2116, 0xaa1603e0, 0x97fe67ac))
print(f'Presentation ABI passed: UUID, {len(signatures)} state/render signatures, independent post-HUD object addresses')

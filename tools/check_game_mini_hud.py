#!/usr/bin/env python3
"""Read-only check of the user-owned game's Mini HUD draw/ref ABI."""
import pathlib
import re
import struct
import sys
import uuid


def check(binary):
    data = pathlib.Path(binary).read_bytes()
    assert struct.unpack_from('<II', data) == (0xFEEDFACF, 0x0100000C)
    segments, image_uuid = [], None
    cursor = 32
    for _ in range(struct.unpack_from('<I', data, 16)[0]):
        command, size = struct.unpack_from('<II', data, cursor)
        assert size >= 8 and cursor + size <= len(data)
        if command == 0x19:
            va, length, offset, file_size = struct.unpack_from('<QQQQ', data, cursor+24)
            segments.append((va, offset, file_size))
        elif command == 0x1B:
            image_uuid = str(uuid.UUID(bytes=data[cursor+8:cursor+24])).upper()
        cursor += size
    assert image_uuid == 'F4357753-A25F-30EE-BACF-63709F902895'

    def at(rva, fmt):
        va = 0x100000000 + rva
        offset = next(offset+va-base for base, offset, size in segments
                      if base <= va and va+struct.calcsize(fmt) <= base+size)
        return struct.unpack_from(fmt, data, offset)

    # Check exactly the same instruction signatures used by the live adapter.
    source = (pathlib.Path(__file__).resolve().parents[1] / 'src/ISDMiniHUD.mm').read_text()
    signatures = re.findall(r'Words\(base,(\w+),std::array<uint32_t,(\d+)>\{([^}]+)\}\)', source)
    assert len(signatures) == 6
    aliases={'NativeDraw':0x8b49d4,'CopyImageRef':0x16b0c,'ReleaseImageRef':0x145cc}
    for address, count, words in signatures:
        rva = aliases[address] if address in aliases else int(address, 16)
        expected = tuple(int(word, 16) for word in words.split(','))
        assert len(expected) == int(count)
        assert at(rva, '<'+'I'*len(expected)) == expected, hex(rva)
    # Native Mini branch builds a 16x16 destination from a 32x32 source.
    assert at(0x6ef92c, '<II') == (0x1e261000, 0x1e261001)
    # Default GL sampler is nearest (0x2600); native nonzero filter selects
    # linear (0x2601). Preserve the separate magnification argument.
    assert at(0x8db53c, '<I')[0] == 0x5284c002
    assert at(0x8db54c, '<I')[0] == 0x5284c002
    assert at(0x945abc, '<II') == (0, 0)
    for table in (0xa915d0, 0xa92350, 0xa93030):
        # File fixups encode additional bits in the high half of a pointer.
        assert at(table+0x80, '<Q')[0] & 0xffffffff == 0x8db6dc
        assert at(table+0x40, '<Q')[0] & 0xffffffff == 0x8b49d4
        words=at(table-16,'<'+'Q'*40)
        assert words[0]==0 and words[1]
        assert all(0x4000 <= (word&0xffffffff) < 0x904000 for word in words[2:])
        # Exactly 38 virtual functions precede the next RTTI object.
        assert at(table+0x130,'<Q')[0]&0xffffffff == 0x10000174
    # Regression: the rejected asynchronous GL_LINEAR experiment must not
    # remain reachable through the full-source replacement.
    for forbidden in ('OpenGLES/', 'glBindTexture(', 'glTexParameteri(',
                      'SetSampling', 'SetFilter',
                      'vm_write(', 'memcpy(reinterpret_cast'):
        assert forbidden not in source, forbidden
    assert '__builtin_return_address(0)' in source
    assert 'caller==Base+MiniReturn' in source
    assert 'kCAFilterNearest' in source
    print('Mini HUD verified: native 32x32 -> 16x16 caller, all 38 image methods/RTTI, ref ABI; no sampler/GL mutations')


if __name__ == '__main__':
    check(sys.argv[1])

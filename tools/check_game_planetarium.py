#!/usr/bin/env python3
"""Read-only checks of the supported, user-owned Isaac Planetarium/HUD ABI."""
import pathlib
import re
import struct
import sys
import uuid


def check(binary):
    data = pathlib.Path(binary).read_bytes()
    assert struct.unpack_from('<II', data) == (0xFEEDFACF, 0x0100000C)
    segments, image_uuid, cursor = [], None, 32
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

    def at(rva, count=1):
        va = 0x100000000 + rva
        offset = next(offset+va-base for base, offset, size in segments
                      if base <= va and va+count*4 <= base+size)
        return struct.unpack_from('<'+'I'*count, data, offset)

    source = (pathlib.Path(__file__).resolve().parents[1] / 'src/ISDPlanetarium.mm').read_text()
    signatures = re.findall(r'Words\(base,(\w+),std::array<uint32_t,(\d+)>\{([^}]+)\}\)', source)
    assert len(signatures) == 9
    aliases = {'GetChance': 0x6d03a4, 'IsAvailable': 0x73fab0,
               'HasCollectible': 0x4eeb74, 'AchievementsBlocked': 0x88b5b0}
    for address, count, words in signatures:
        rva = aliases[address] if address in aliases else int(address, 16)
        expected = tuple(int(word, 16) for word in words.split(','))
        assert len(expected) == int(count)
        assert at(rva, len(expected)) == expected, hex(rva)
    # Planetarium getter calls only player ownership/trinket queries, challenge
    # config retrieval, and clamp. The generation caller rolls RNG separately.
    calls = []
    for pc in range(0x6d03a4, 0x6d05d4, 4):
        word, = at(pc)
        assert word & 0xfffffc1f != 0xd63f0000  # no unverified indirect call
        if word & 0xfc000000 == 0x94000000:
            imm = word & 0x3ffffff
            if imm & (1 << 25):
                imm -= 1 << 26
            calls.append(pc+imm*4)
    assert calls == [0x569f48, 0x88b548, 0x569d48, 0x569d48, 0x569d48, 0x569d48, 0x8ae70c]
    for forbidden in ('vm_write(', 'vm_protect(', 'mprotect(', 'MSHook', 'Isaac.Spawn',
                      'RandomInt', 'RandomFloat', '0x76f970', '0x57062c'):
        assert forbidden not in source, forbidden
    assert source.index('if (!initial && _floor==floor) return YES') < source.index('_base+GetChance)(game)')
    print('Planetarium verified: native chance/availability/ownership/HUD ABI; getter has no RNG call; snapshot guard precedes getter')


if __name__ == '__main__':
    check(sys.argv[1])

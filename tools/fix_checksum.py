#!/usr/bin/env python3
"""Fill in the SNES header checksum (LoROM header at $7FC0)."""
import sys
p = sys.argv[1]
d = bytearray(open(p, 'rb').read())
h = 0x7FC0
d[h + 0x1C:h + 0x20] = b'\xff\xff\x00\x00'
s = sum(d) & 0xFFFF
d[h + 0x1E] = s & 0xFF
d[h + 0x1F] = s >> 8
c = s ^ 0xFFFF
d[h + 0x1C] = c & 0xFF
d[h + 0x1D] = c >> 8
open(p, 'wb').write(d)
print('checksum %04X' % s)

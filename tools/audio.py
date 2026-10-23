#!/usr/bin/env python3
"""Extract the PCM audio track from a mednafen QuickTime recording.

usage: audio.py movie.mov out.wav  -> also prints loudness per 1/10 s
"""
import struct, sys, wave

def atoms(d, start, end):
    p = start
    while p + 8 <= end:
        size, typ = struct.unpack('>I4s', d[p:p + 8])
        hdr = 8
        if size == 1:
            size = struct.unpack('>Q', d[p + 8:p + 16])[0]
            hdr = 16
        if size == 0:
            size = end - p
        yield typ.decode('latin1'), p + hdr, p + size
        p += size

CONTAINERS = {'moov', 'trak', 'mdia', 'minf', 'stbl', 'edts', 'dinf'}

def find_tracks(d):
    tracks = []
    def walk(s, e, cur):
        for typ, a, b in atoms(d, s, e):
            if typ == 'trak':
                t = {}
                tracks.append(t)
                walk(a, b, t)
            elif typ in CONTAINERS:
                walk(a, b, cur)
            elif typ == 'hdlr':
                cur.setdefault('handler', d[a + 8:a + 12].decode('latin1'))
            elif typ in ('stsd', 'stco', 'co64', 'stsc', 'stsz', 'mdhd'):
                cur[typ] = (a, b)
    walk(0, len(d), None)
    return tracks

def main():
    d = open(sys.argv[1], 'rb').read()
    tr = [t for t in find_tracks(d) if t.get('handler') == 'soun']
    if not tr:
        print('no audio track')
        return
    t = tr[0]
    a, b = t['stsd']
    # sample description: after version/flags + count(4) -> size(4) fmt(4)
    fmt = d[a + 12:a + 16].decode('latin1')
    desc = a + 8
    # QuickTime sound description v0/v1: channels at +24, bits at +26, rate (16.16) at +32
    ver = struct.unpack('>H', d[desc + 16:desc + 18])[0]
    ch = struct.unpack('>H', d[desc + 24:desc + 26])[0]
    bits = struct.unpack('>H', d[desc + 26:desc + 28])[0]
    rate = struct.unpack('>I', d[desc + 32:desc + 36])[0] >> 16
    if 'stco' in t:
        a, b = t['stco']
        n = struct.unpack('>I', d[a + 4:a + 8])[0]
        offs = list(struct.unpack('>%dI' % n, d[a + 8:a + 8 + 4 * n]))
    else:
        a, b = t['co64']
        n = struct.unpack('>I', d[a + 4:a + 8])[0]
        offs = list(struct.unpack('>%dQ' % n, d[a + 8:a + 8 + 8 * n]))
    a, b = t['stsc']
    n = struct.unpack('>I', d[a + 4:a + 8])[0]
    stsc = [struct.unpack('>III', d[a + 8 + 12 * i:a + 20 + 12 * i]) for i in range(n)]
    # samples per chunk for each chunk
    spc = []
    for ci in range(len(offs)):
        cnum = ci + 1
        val = None
        for (first, per, _desc) in stsc:
            if cnum >= first:
                val = per
        spc.append(val)
    frame_bytes = ch * bits // 8
    pcm = bytearray()
    for off, cnt in zip(offs, spc):
        pcm += d[off:off + cnt * frame_bytes]
    if fmt == 'twos':  # big endian -> little endian
        for i in range(0, len(pcm), 2):
            pcm[i], pcm[i + 1] = pcm[i + 1], pcm[i]
    w = wave.open(sys.argv[2], 'wb')
    w.setnchannels(ch)
    w.setsampwidth(bits // 8)
    w.setframerate(rate)
    w.writeframes(bytes(pcm))
    w.close()
    # loudness report
    import array
    s = array.array('h', bytes(pcm))
    step = rate // 10 * ch
    levels = []
    for i in range(0, len(s), step):
        blk = s[i:i + step]
        if not blk:
            break
        levels.append(int((sum(v * v for v in blk) / len(blk)) ** 0.5))
    print('format', fmt, 'rate', rate, 'ch', ch, 'bits', bits, 'seconds %.1f' % (len(s) / ch / rate))
    print('rms per 0.1s:', ' '.join(str(v) for v in levels))

main()

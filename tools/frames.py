#!/usr/bin/env python3
"""Extract PNG frames from a mednafen QuickTime recording (-qtrecord.vcodec png).

usage: frames.py movie.mov outdir [every_n] [--sheet]
Writes outdir/fNNNN.png for every Nth frame, and optionally a contact sheet.
"""
import io, os, sys
from PIL import Image

def iter_pngs(data):
    pos = 0
    sig = b'\x89PNG\r\n\x1a\n'
    end = b'IEND\xaeB`\x82'
    while True:
        s = data.find(sig, pos)
        if s < 0:
            return
        e = data.find(end, s)
        if e < 0:
            return
        yield data[s:e + len(end)]
        pos = e + len(end)

def main():
    mov, out = sys.argv[1], sys.argv[2]
    every = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].isdigit() else 30
    os.makedirs(out, exist_ok=True)
    frames = []
    for i, png in enumerate(iter_pngs(open(mov, 'rb').read())):
        if i % every == 0:
            im = Image.open(io.BytesIO(png)).convert('RGB')
            # mednafen doubles 256x224 -> 512x448; shrink back to native size
            if im.size == (512, 448):
                im = im.resize((256, 224), Image.NEAREST)
            p = os.path.join(out, 'f%05d.png' % i)
            im.save(p)
            frames.append((i, im))
    print('frames extracted:', len(frames), 'last index', frames[-1][0] if frames else None)
    if '--sheet' in sys.argv and frames:
        cols = 4
        w, h = frames[0][1].size
        sel = frames[-16:]
        rows = (len(sel) + cols - 1) // cols
        sheet = Image.new('RGB', (cols * w, rows * h))
        for k, (i, im) in enumerate(sel):
            sheet.paste(im, ((k % cols) * w, (k // cols) * h))
        sheet.save(os.path.join(out, 'sheet.png'))

main()

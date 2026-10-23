import sys
from PIL import Image, ImageDraw
from snesgfx import rgb
import tiles, levels, palettes

data, entries, attrs, breaks, canv = tiles.build_metatiles()
ECOL = {1: (255, 80, 80), 2: (255, 60, 60), 3: (255, 120, 60), 4: (255, 200, 0), 5: (255, 160, 0), 6: (255, 100, 160),
        7: (255, 0, 255), 8: (255, 0, 255), 9: (255, 0, 0), 10: (0, 255, 255), 11: (0, 255, 0), 12: (0, 255, 255),
        13: (0, 255, 255), 14: (180, 180, 255)}

def render(L, info, idx, scale_down=2):
    name, earth, back, depth = levels.MISSION_INFO[idx]
    pals = {2: palettes.EARTH[earth], 3: palettes.STONE, 4: palettes.METAL, 5: palettes.CITY, 6: palettes.MISC}
    bgc = rgb(palettes.BACK[back][11])
    img = Image.new('RGB', (levels.W * 16, levels.H * 16), bgc)
    cache = {}
    for y in range(levels.H):
        for x in range(levels.W):
            m = L.t[y][x]
            if m == 0:
                if info.get('surface') and y < info['surface']:
                    img.paste(rgb(palettes.BACK['city'][2]), (x * 16, y * 16, x * 16 + 16, y * 16 + 16))
                continue
            if m not in cache:
                c, pal = canv[m]
                t = Image.new('RGBA', (16, 16))
                for yy in range(16):
                    for xx in range(16):
                        v = c.p[yy][xx]
                        if v:
                            t.putpixel((xx, yy), rgb(pals[pal][v]) + (255,))
                cache[m] = t
            img.paste(cache[m], (x * 16, y * 16), cache[m])
    d = ImageDraw.Draw(img)
    for (t, p, x, y) in L.ents:
        col = ECOL.get(t, (255, 255, 255))
        if t >= 16:
            d.rectangle((x - 5, y - 12, x + 5, y - 2), outline=(255, 255, 255), fill=(60, 200, 60))
        else:
            d.rectangle((x - 6, y - 30, x + 6, y - 1), outline=(0, 0, 0), fill=col)
    sx, sy = info['start']
    d.rectangle((sx * 16 + 2, sy * 16 - 16, sx * 16 + 14, sy * 16 + 15), fill=(60, 120, 255), outline=(255, 255, 255))
    return img.resize((img.width // scale_down, img.height // scale_down), Image.LANCZOS)

if __name__ == '__main__':
    out = sys.argv[1]
    which = [int(a) for a in sys.argv[2:]] or range(10)
    for i in which:
        L, info = levels.generate(i)
        probs, n = levels.validate(L, info)
        print('mission', i + 1, levels.MISSION_INFO[i][0], 'reachable', n, 'ents', len(L.ents), 'PROBLEMS' if probs else 'ok', probs)
        render(L, info, i).save('%s/map%02d.png' % (out, i + 1))

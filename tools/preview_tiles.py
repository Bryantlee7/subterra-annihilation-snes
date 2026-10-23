import sys
from PIL import Image
from snesgfx import Canvas, rgb
import tiles, palettes

pals = {2: palettes.EARTH[sys.argv[2] if len(sys.argv) > 2 else 'surface'], 3: palettes.STONE, 4: palettes.METAL,
        5: palettes.CITY, 6: palettes.MISC, 7: palettes.BACK['city']}
data, entries, attrs, breaks, canv = tiles.build_metatiles()
img = Image.new('RGB', (8 * 18, ((len(canv) + 7) // 8) * 18), (255, 0, 255))
for i, (c, pal) in enumerate(canv):
    for y in range(16):
        for x in range(16):
            v = c.p[y][x]
            img.putpixel(((i % 8) * 18 + x, (i // 8) * 18 + y), rgb(pals[pal][v]) if v else (40, 0, 40))
img = img.resize((img.width * 3, img.height * 3), Image.NEAREST)
img.save(sys.argv[1] + '_mt.png')
d2, e2, n, big = tiles.build_bg2()
print('bg2 chars', n, 'metatile chars bytes', len(data))
im2 = Image.new('RGB', (256, 512))
for y in range(512):
    for x in range(256):
        im2.putpixel((x, y), rgb(pals[7][big.p[y][x]]))
im2.save(sys.argv[1] + '_bg2.png')
print('font bytes', len(tiles.build_font()))

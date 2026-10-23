"""Background graphics: BG1 16x16 metatiles, BG2 parallax backdrop, BG3 font."""
import math
import random
from snesgfx import Canvas, chars_of, enc4, enc2

# ------------------------------------------------------------ attributes
SOLID, DESTRUCT, PLATFORM, LADDER, HAZARD, DOOR, EXIT, EMPABLE = 1, 2, 4, 8, 16, 32, 64, 128

def noise(c, rnd, x0, y0, x1, y1, weights):
    """Fill rect with colors chosen by weight dict {color: weight}."""
    cols = list(weights.keys())
    ws = list(weights.values())
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            c.set(x, y, rnd.choices(cols, ws)[0])

def speck(c, rnd, n, color, size=1):
    for _ in range(n):
        x, y = rnd.randrange(16), rnd.randrange(16)
        c.rect(x, y, x + size - 1, y + size - 1, color)

def pebbles(c, rnd, n, dark, light):
    for _ in range(n):
        x, y = rnd.randrange(1, 14), rnd.randrange(1, 14)
        c.rect(x, y, x + 1, y + 1, light)
        c.set(x + 1, y + 1, dark)
        c.set(x + 2, y + 1, dark)

# ------------------------------------------------------------ painters
def p_air(c, r): pass

def p_dirt(c, r):
    noise(c, r, 0, 0, 15, 15, {3: 6, 2: 3, 4: 2})
    speck(c, r, 6, 5)
    speck(c, r, 5, 1)
    pebbles(c, r, 2, 6, 7)

def p_dirt_top(c, r):
    p_dirt(c, r)
    for x in range(16):
        h = 2 + r.randrange(3)
        for y in range(h):
            c.set(x, y, 9 if y < h - 1 else 8)
        if r.random() < 0.3:
            c.set(x, h, 8)

def p_rock(c, r, crack=False, crystal=False):
    noise(c, r, 0, 0, 15, 15, {11: 5, 10: 2, 12: 2})
    # boulder outlines
    for (x0, y0, x1, y1) in ((0, 0, 8, 6), (9, 0, 15, 8), (0, 7, 6, 15), (7, 9, 15, 15)):
        c.rect(x0, y0, x1, y0, 12)
        c.rect(x0, y0, x0, y1, 12)
        c.rect(x0, y1, x1, y1, 10)
        c.rect(x1, y0, x1, y1, 10)
        c.set(x0 + 1, y0 + 1, 13)
    if crack:
        x, y = 3, 1
        for _ in range(16):
            c.set(x, y, 1)
            x += r.choice((0, 1, 1)); y += 1
            if x > 14 or y > 14: break
        x, y = 13, 3
        for _ in range(10):
            c.set(x, y, 1)
            x -= 1; y += r.choice((0, 1))
            if x < 1: break
    if crystal:
        for (cx, cy) in ((4, 4), (11, 10), (5, 12)):
            for i in range(4):
                c.set(cx, cy - i, 15 if i % 2 else 14)
                c.set(cx + 1, cy - i + 1, 14)
            c.set(cx, cy - 4, 15)

def p_bedrock(c, r, alt=False):
    noise(c, r, 0, 0, 15, 15, {3: 5, 2: 3, 4: 1})
    blocks = ((0, 0, 9, 7), (10, 0, 15, 5), (10, 6, 15, 15), (0, 8, 9, 15)) if not alt else \
             ((0, 0, 5, 9), (6, 0, 15, 6), (6, 7, 15, 15), (0, 10, 5, 15))
    for (x0, y0, x1, y1) in blocks:
        c.rect(x0, y0, x1, y0, 4)
        c.rect(x0, y0, x0, y1, 4)
        c.rect(x0, y1, x1, y1, 1)
        c.rect(x1, y0, x1, y1, 1)
        c.set(x0 + 1, y0 + 1, 5)

def p_street(c, r):
    noise(c, r, 0, 2, 15, 15, {7: 6, 6: 3})
    c.rect(0, 0, 15, 0, 14)
    c.rect(0, 1, 15, 1, 9)
    c.rect(2, 6, 7, 6, 8)
    speck(c, r, 4, 1)

def p_sidewalk(c, r):
    noise(c, r, 0, 0, 15, 15, {10: 8, 9: 1})
    c.rect(0, 0, 15, 0, 15)
    c.rect(0, 15, 15, 15, 9)
    c.rect(15, 0, 15, 15, 9)
    c.rect(7, 1, 7, 14, 9)

def p_concrete(c, r):
    noise(c, r, 0, 0, 15, 15, {12: 8, 11: 2, 13: 1})
    c.rect(0, 15, 15, 15, 11)
    c.rect(15, 0, 15, 15, 11)
    c.rect(0, 0, 15, 0, 13)
    speck(c, r, 3, 11)

def p_shaft_wall(c, r):
    noise(c, r, 0, 0, 15, 15, {11: 8, 6: 2})
    c.rect(0, 7, 15, 7, 6)
    c.rect(0, 15, 15, 15, 6)
    c.rect(4, 0, 4, 6, 6)
    c.rect(12, 8, 12, 14, 6)

def p_brick(c, r):
    noise(c, r, 0, 0, 15, 15, {12: 6, 13: 1, 11: 1})
    for y in (3, 7, 11, 15):
        c.rect(0, y, 15, y, 1)
    for i, y in enumerate((0, 4, 8, 12)):
        off = 4 if i % 2 else 0
        for x in (off + 0, off + 8):
            c.rect(x % 16, y, x % 16, y + 2, 1)
        c.rect(0, y, 15, y, c.get(0, y))

def p_bldg(c, r, lit):
    c.rect(0, 0, 15, 15, 3)
    c.rect(0, 0, 0, 15, 2)
    c.rect(15, 0, 15, 15, 4)
    for wx in (2, 9):
        on = lit and r.random() < 0.75
        col = r.choice((6, 7)) if on else 5
        c.rect(wx, 3, wx + 4, 11, 1)
        c.rect(wx + 1, 4, wx + 3, 10, col)
        if on:
            c.set(wx + 1, 4, 15)
        else:
            c.set(wx + 3, 5, 4)
        c.rect(wx, 12, wx + 4, 12, 4)

def p_bldg_wall(c, r):
    c.rect(0, 0, 15, 15, 3)
    for y in (3, 7, 11, 15):
        c.rect(0, y, 15, y, 2)
    c.rect(0, 0, 0, 15, 2)

def p_roof(c, r):
    p_bldg_wall(c, r)
    c.rect(0, 0, 15, 3, 14)
    c.rect(0, 0, 15, 0, 15)
    c.rect(0, 3, 15, 4, 1)
    c.rect(0, 4, 15, 4, 13)

def p_neon(c, r, a, b):
    """Neon sign: a glowing cocktail glass (a) or a star (b) in a frame."""
    c.rect(0, 0, 15, 15, 2)
    c.rect(1, 1, 14, 14, 1)
    if a == 8:
        # cocktail glass
        for i in range(5):
            c.set(3 + i, 3 + i, a)
            c.set(12 - i, 3 + i, a)
        c.rect(3, 3, 12, 3, a)
        c.rect(7, 8, 8, 11, a)
        c.rect(5, 12, 10, 12, a)
        c.set(10, 4, b)
    else:
        # star
        pts = [(7.5, 2.5), (9, 6.5), (13, 6.5), (10, 9), (11.5, 13), (7.5, 10.5), (3.5, 13), (5, 9), (2, 6.5), (6, 6.5)]
        for i in range(len(pts)):
            x0, y0 = pts[i]
            x1, y1 = pts[(i + 1) % len(pts)]
            c.capsule(x0, y0, x1, y1, 0.5, a)
        c.set(7, 7, b)
        c.set(8, 7, b)

def p_sign_down(c, r):
    c.rect(0, 0, 15, 15, 1)
    c.rect(1, 1, 14, 14, 13)
    c.rect(1, 1, 14, 1, 10)
    c.rect(1, 14, 14, 14, 10)
    c.rect(1, 1, 1, 14, 10)
    c.rect(14, 1, 14, 14, 10)
    for i in range(5):
        c.rect(4 + i, 5 + i, 11 - i, 5 + i, 11)
    c.rect(7, 3, 8, 5, 11)

def p_bldg_door(c, r):
    c.rect(0, 0, 15, 15, 3)
    c.rect(2, 2, 13, 15, 4)
    c.rect(3, 3, 12, 15, 1)
    c.rect(4, 4, 7, 15, 5)
    c.rect(8, 4, 11, 15, 5)
    c.set(7, 10, 6); c.set(8, 10, 6)

def p_grate(c, r):
    c.rect(0, 0, 15, 0, 6)
    c.rect(0, 1, 15, 2, 4)
    c.rect(0, 3, 15, 3, 2)
    for x in range(1, 16, 3):
        c.set(x, 1, 2); c.set(x, 2, 3)

def p_platform(c, r):
    c.rect(0, 0, 15, 0, 6)
    c.rect(0, 1, 15, 3, 5)
    c.rect(0, 4, 15, 4, 3)
    c.rect(0, 5, 15, 5, 1)
    for x in (1, 14):
        c.rect(x, 6, x + 1, 9, 4)
        c.rect(x, 10, x + 1, 10, 2)
    for x in range(3, 13, 4):
        c.set(x, 2, 8)

def p_girder(c, r):
    c.rect(0, 0, 15, 2, 7)
    c.rect(0, 0, 15, 0, 15)
    c.rect(0, 13, 15, 15, 7)
    c.rect(0, 15, 15, 15, 1)
    for i in range(0, 16, 8):
        c.capsule(i + 0.5, 3, i + 7.5, 12.5, 0.8, 14)
        c.capsule(i + 7.5, 3, i + 0.5, 12.5, 0.8, 14)

def p_beam_v(c, r):
    c.rect(5, 0, 10, 15, 14)
    c.rect(5, 0, 5, 15, 15)
    c.rect(10, 0, 10, 15, 7)
    for y in (3, 11):
        c.set(7, y, 1); c.set(8, y, 1)

def p_pipe_h(c, r):
    c.rect(0, 5, 15, 10, 14)
    c.rect(0, 6, 15, 6, 15)
    c.rect(0, 10, 15, 10, 7)
    c.rect(0, 4, 15, 4, 1)
    c.rect(0, 11, 15, 11, 1)
    c.rect(12, 3, 14, 12, 5)
    c.rect(12, 3, 12, 12, 6)

def p_pipe_v(c, r):
    c.rect(5, 0, 10, 15, 14)
    c.rect(6, 0, 6, 15, 15)
    c.rect(10, 0, 10, 15, 7)
    c.rect(4, 0, 4, 15, 1)
    c.rect(11, 0, 11, 15, 1)
    c.rect(3, 12, 12, 14, 5)
    c.rect(3, 12, 12, 12, 6)

def p_vent(c, r):
    c.rect(1, 2, 14, 13, 3)
    c.rect(1, 2, 14, 2, 5)
    c.rect(1, 13, 14, 13, 1)
    for y in range(4, 12, 2):
        c.rect(3, y, 12, y, 1)
        c.rect(3, y + 1, 12, y + 1, 4)

def p_machine(c, r):
    c.rect(0, 0, 15, 15, 4)
    c.rect(0, 0, 15, 0, 6)
    c.rect(0, 0, 0, 15, 5)
    c.rect(15, 0, 15, 15, 2)
    c.rect(0, 15, 15, 15, 2)
    c.rect(3, 3, 12, 8, 2)
    c.rect(4, 4, 11, 7, 13)
    c.set(5, 5, 12); c.set(6, 5, 12); c.set(8, 6, 12)
    c.rect(3, 11, 4, 12, 10)
    c.rect(6, 11, 7, 12, 11)
    c.rect(9, 11, 12, 12, 9)

def p_metal_wall(c, r):
    c.rect(0, 0, 15, 15, 3)
    c.rect(0, 0, 15, 0, 5)
    c.rect(0, 0, 0, 15, 4)
    c.rect(15, 0, 15, 15, 2)
    c.rect(0, 15, 15, 15, 2)
    c.rect(1, 7, 14, 7, 2)
    c.rect(1, 8, 14, 8, 4)
    for (x, y) in ((2, 2), (13, 2), (2, 12), (13, 12)):
        c.set(x, y, 6); c.set(x + 1, y + 1, 1)

def p_metal_floor(c, r):
    c.rect(0, 0, 15, 15, 4)
    c.rect(0, 0, 15, 1, 6)
    c.rect(0, 2, 15, 2, 5)
    c.rect(0, 15, 15, 15, 2)
    for x in range(1, 16, 4):
        for y in range(5, 14, 4):
            c.set(x, y, 6); c.set(x + 1, y + 1, 3)

def p_hazard(c, r):
    for y in range(16):
        for x in range(16):
            c.set(x, y, 8 if ((x + y) // 4) % 2 == 0 else 9)
    c.rect(0, 0, 15, 0, 6)
    c.rect(0, 15, 15, 15, 1)

def p_lamp(c, r):
    c.rect(7, 0, 8, 4, 2)
    c.rect(4, 5, 11, 7, 4)
    c.rect(4, 5, 11, 5, 6)
    c.rect(5, 8, 10, 9, 8)
    c.rect(6, 10, 9, 10, 8)

def p_screen(c, r):
    c.rect(0, 1, 15, 14, 2)
    for (x0, y0) in ((1, 2), (8, 2), (1, 8), (8, 8)):
        c.rect(x0, y0, x0 + 6, y0 + 4, 1)
        c.rect(x0 + 1, y0 + 1, x0 + 5, y0 + 3, 13)
        for i in range(r.randrange(1, 4)):
            c.rect(x0 + 1, y0 + 1 + i, x0 + 1 + r.randrange(1, 5), y0 + 1 + i, 12)

def p_bars(c, r):
    c.rect(0, 0, 15, 1, 4)
    c.rect(0, 14, 15, 15, 4)
    for x in range(1, 16, 4):
        c.rect(x, 0, x + 1, 15, 5)
        c.rect(x + 1, 0, x + 1, 15, 3)

def p_scaffold(c, r):
    c.capsule(0.5, 0.5, 15.5, 15.5, 1.0, 7)
    c.capsule(15.5, 0.5, 0.5, 15.5, 1.0, 14)
    c.rect(0, 0, 1, 15, 14)
    c.rect(14, 0, 15, 15, 7)

def p_fence(c, r):
    for y in range(16):
        for x in range(16):
            if (x + y) % 6 == 0 or (x - y) % 6 == 0:
                c.set(x, y, 4)
    c.rect(0, 0, 15, 0, 5)

def p_crate(c, r):
    c.rect(0, 0, 15, 15, 14)
    c.rect(0, 0, 15, 1, 15)
    c.rect(0, 14, 15, 15, 7)
    c.rect(0, 0, 1, 15, 15)
    c.rect(14, 0, 15, 15, 7)
    c.capsule(2, 2, 14, 14, 0.9, 7)
    c.capsule(14, 2, 2, 14, 0.9, 7)
    c.rect(0, 0, 15, 0, 1)
    c.rect(0, 15, 15, 15, 1)

def p_streetlight(c, r):
    c.rect(7, 4, 8, 15, 3)
    c.rect(2, 2, 12, 4, 4)
    c.rect(2, 2, 12, 2, 6)
    c.rect(3, 5, 9, 5, 8)

def p_pole(c, r):
    c.rect(7, 0, 8, 15, 3)
    c.rect(7, 0, 7, 15, 5)

# MISC palette tiles
def p_ladder(c, r, top=False):
    for x in (2, 12):
        c.rect(x, 0, x + 1, 15, 3)
        c.rect(x, 0, x, 15, 4)
        c.rect(x + 1, 0, x + 1, 15, 2)
    for y in (1, 5, 9, 13):
        c.rect(4, y, 11, y, 3)
        c.rect(4, y + 1, 11, y + 1, 2)
    if top:
        c.rect(0, 0, 15, 2, 7)
        c.rect(0, 0, 15, 0, 1)
        c.rect(0, 3, 15, 3, 5)

def p_door(c, r, light):
    c.rect(0, 0, 15, 15, 6)
    c.rect(0, 0, 1, 15, 5)
    c.rect(14, 0, 15, 15, 5)
    c.rect(2, 0, 2, 15, 7)
    c.rect(4, 0, 4, 15, 5)
    c.rect(11, 0, 11, 15, 5)
    c.rect(6, 5, 9, 10, 1)
    c.rect(7, 6, 8, 9, light)

def p_door_open(c, r):
    c.rect(0, 0, 1, 15, 5)
    c.rect(14, 0, 15, 15, 5)
    c.rect(1, 0, 1, 15, 7)

def p_laser(c, r):
    c.rect(6, 0, 9, 15, 11)
    c.rect(7, 0, 8, 15, 12)
    for y in range(0, 16, 3):
        c.set(7 + (y % 2), y, 13)

def p_laser_off(c, r):
    for y in range(0, 16, 4):
        c.set(7, y, 11)

def p_emitter(c, r):
    c.rect(2, 0, 13, 13, 4)
    c.rect(2, 0, 13, 0, 6)
    c.rect(2, 13, 13, 13, 2)
    c.rect(5, 12, 10, 15, 2)
    c.rect(6, 13, 9, 15, 11)

def p_electric(c, r):
    c.rect(0, 0, 15, 15, 9)
    c.rect(0, 0, 15, 2, 4)
    c.rect(0, 0, 15, 0, 6)
    y = 6
    for x in range(16):
        c.set(x, y, 8)
        y = 5 + (x * 7 + 3) % 4
    for x in range(0, 16, 5):
        c.rect(x, 12, x + 2, 13, 11)

def p_exit(c, r):
    """Exit lift: green light beam with down-pointing chevrons."""
    c.rect(0, 0, 15, 15, 1)
    c.rect(1, 0, 14, 15, 5)
    c.rect(3, 0, 12, 15, 1)
    for x in (4, 11):
        c.rect(x, 0, x, 15, 10)
    for k, y0 in enumerate((1, 9)):
        for i in range(4):
            c.set(5 + i, y0 + i, 10)
            c.set(10 - i, y0 + i, 10)
        c.rect(7, y0 + 3, 8, y0 + 4, 10)

def p_slime(c, r):
    for x in range(16):
        h = 6 + int(1.5 * math.sin(x * 0.8))
        c.rect(x, h, x, 15, 14)
        c.set(x, h, 15)
        if x % 5 == 2:
            c.set(x, h - 2, 15)

# id, name, palette, attributes, painter, break-to name
METATILES = [
    ('AIR', 0, 0, p_air, None),
    ('STREET', 3, SOLID, p_street, None),
    ('SIDEWALK', 3, SOLID, p_sidewalk, None),
    ('CONCRETE', 3, SOLID, p_concrete, None),
    ('BLDG_WIN', 5, 0, lambda c, r: p_bldg(c, r, True), None),
    ('BLDG_DARK', 5, 0, lambda c, r: p_bldg(c, r, False), None),
    ('BLDG_WALL', 5, 0, p_bldg_wall, None),
    ('ROOF', 5, PLATFORM, p_roof, None),
    ('NEON_A', 5, 0, lambda c, r: p_neon(c, r, 8, 9), None),
    ('NEON_B', 5, 0, lambda c, r: p_neon(c, r, 10, 11), None),
    ('GRATE', 4, PLATFORM, p_grate, None),
    ('HAZARD', 4, SOLID, p_hazard, None),
    ('DIRT', 2, SOLID | DESTRUCT, p_dirt, 'AIR'),
    ('DIRT2', 2, SOLID | DESTRUCT, p_dirt, 'AIR'),
    ('DIRT_TOP', 2, SOLID | DESTRUCT, p_dirt_top, 'AIR'),
    ('ROCK', 2, SOLID | DESTRUCT, p_rock, 'ROCK_CRACK'),
    ('ROCK_CRACK', 2, SOLID | DESTRUCT, lambda c, r: p_rock(c, r, crack=True), 'AIR'),
    ('BEDROCK', 3, SOLID, p_bedrock, None),
    ('BEDROCK2', 3, SOLID, lambda c, r: p_bedrock(c, r, True), None),
    ('LADDER', 6, LADDER, p_ladder, None),
    ('LADDER_TOP', 6, LADDER | PLATFORM, lambda c, r: p_ladder(c, r, True), None),
    ('PLATFORM', 4, PLATFORM, p_platform, None),
    ('GIRDER', 4, PLATFORM, p_girder, None),
    ('BEAM_V', 4, 0, p_beam_v, None),
    ('PIPE_H', 4, 0, p_pipe_h, None),
    ('PIPE_V', 4, 0, p_pipe_v, None),
    ('VENT', 4, 0, p_vent, None),
    ('MACHINE', 4, SOLID, p_machine, None),
    ('METAL_WALL', 4, SOLID, p_metal_wall, None),
    ('METAL_FLOOR', 4, SOLID, p_metal_floor, None),
    ('LAMP', 4, 0, p_lamp, None),
    ('DOOR_KEY', 6, SOLID | DOOR, lambda c, r: p_door(c, r, 8), 'DOOR_OPEN'),
    ('DOOR_EMP', 6, SOLID | DOOR | EMPABLE, lambda c, r: p_door(c, r, 9), 'DOOR_OPEN'),
    ('DOOR_EXIT', 6, SOLID | DOOR, lambda c, r: p_door(c, r, 10), 'DOOR_OPEN'),
    ('DOOR_OPEN', 6, 0, p_door_open, None),
    ('LASER', 6, HAZARD | EMPABLE, p_laser, 'LASER_OFF'),
    ('LASER_OFF', 6, 0, p_laser_off, None),
    ('EMITTER', 4, SOLID, p_emitter, None),
    ('ELECTRIC', 4, SOLID | HAZARD, p_electric, None),
    ('EXIT', 6, EXIT, p_exit, None),
    ('CRYSTAL', 2, SOLID | DESTRUCT, lambda c, r: p_rock(c, r, crystal=True), 'AIR'),
    ('SLIME', 6, HAZARD, p_slime, None),
    ('SCREEN', 4, 0, p_screen, None),
    ('BARS', 4, 0, p_bars, None),
    ('SCAFFOLD', 4, 0, p_scaffold, None),
    ('SHAFT_WALL', 3, 0, p_shaft_wall, None),
    ('SIGN_DOWN', 5, 0, p_sign_down, None),
    ('BLDG_DOOR', 5, 0, p_bldg_door, None),
    ('FENCE', 4, 0, p_fence, None),
    ('CRATE', 4, SOLID | DESTRUCT, p_crate, 'AIR'),
    ('BRICK', 3, SOLID | DESTRUCT, p_brick, 'AIR'),
    ('STREETLIGHT', 4, 0, p_streetlight, None),
    ('POLE', 4, 0, p_pole, None),
]
MT = {name: i for i, (name, *_rest) in enumerate(METATILES)}

def build_metatiles():
    """Returns (chr bytes for BG1, entries[], attrs[], breaks[], canvases)."""
    sheet = Canvas(128, 256)  # 16 chars x 32 rows of 8x8 = 512 chars
    entries, attrs, breaks, canv = [], [], [], []
    for m, (name, pal, attr, painter, brk) in enumerate(METATILES):
        c = Canvas(16, 16)
        painter(c, random.Random(1000 + m))
        base = (m % 8) * 2 + (m // 8) * 32
        sheet.blit(c, (base % 16) * 8, (base // 16) * 8, transparent=False)
        entries.append(base | (pal << 10))
        attrs.append(attr)
        breaks.append(MT[brk] if brk else m)
        canv.append((c, pal))
    n_rows = ((len(METATILES) + 7) // 8) * 2
    chars = chars_of(sheet)[: n_rows * 16]
    data = b''.join(enc4(ch) for ch in chars)
    return data, entries, attrs, breaks, canv

# ------------------------------------------------------------ BG2 backdrop
def dedupe_tiles(canvas, max_chars, first_char=0):
    """Return (chr bytes, tilemap entries) for a canvas, with H/V flip reuse."""
    seen = {}
    chars = []
    entries = []
    for ch in chars_of(canvas):
        key = tuple(tuple(r) for r in ch)
        found = None
        for (fh, fv) in ((0, 0), (1, 0), (0, 1), (1, 1)):
            k = key
            if fh: k = tuple(tuple(reversed(r)) for r in k)
            if fv: k = tuple(reversed(k))
            if k in seen:
                found = (seen[k], fh, fv)
                break
        if found is None:
            idx = len(chars)
            seen[key] = idx
            chars.append(ch)
            found = (idx, 0, 0)
        idx, fh, fv = found
        entries.append(((idx + first_char) & 0x3FF) | (fh << 14) | (fv << 15) | (7 << 10))
    assert len(chars) <= max_chars, ('too many bg2 chars', len(chars))
    return b''.join(enc4(c) for c in chars), entries, len(chars)

def skyline():
    rnd = random.Random(7)
    c = Canvas(256, 160)
    # sky bands, dithered at the edges
    bands = [(0, 1), (40, 2), (80, 3), (120, 4)]
    for y in range(160):
        col = 1
        for (y0, cc) in bands:
            if y >= y0: col = cc
        for x in range(256):
            v = col
            for (y0, cc) in bands[1:]:
                if y0 - 4 <= y < y0 and (x + y) % 2 == 0 and (y0 - y) <= 2:
                    v = cc
            c.set(x, y, v)
    c.disc(200, 34, 11, 9)
    c.disc(196, 31, 3, 4)
    for _ in range(26):
        x, y = rnd.randrange(256), rnd.randrange(70)
        if math.hypot(x - 200, y - 34) > 14:
            c.set(x, y, 9 if rnd.random() < 0.5 else 8)
    # far buildings - widths are multiples of 8 to encourage reuse
    x = 0
    while x < 256:
        w = rnd.choice((16, 24, 32))
        h = rnd.choice((40, 56, 64, 72))
        top = 160 - h
        c.rect(x, top, x + w - 1, 159, 5)
        for wy in range(top + 4, 156, 8):
            for wx in range(x + 2, x + w - 2, 4):
                if rnd.random() < 0.18:
                    c.set(wx, wy, 7 if rnd.random() < 0.7 else 8)
        x += w
    # near buildings
    x = 8
    while x < 256:
        w = rnd.choice((24, 32, 40))
        h = rnd.choice((48, 64, 88, 104))
        top = 160 - h
        c.rect(x, top, x + w - 1, 159, 6)
        c.rect(x, top, x + w - 1, top, 5)
        if rnd.random() < 0.5:
            c.rect(x + w // 2 - 1, top - 12, x + w // 2, top - 1, 6)
            c.set(x + w // 2, top - 13, 9)
        for wy in range(top + 6, 156, 8):
            for wx in range(x + 3, x + w - 3, 5):
                if rnd.random() < 0.35:
                    col = 7 if rnd.random() < 0.75 else 8
                    c.rect(wx, wy, wx + 1, wy + 2, col)
        x += w + rnd.choice((8, 16, 24))
    return c

def cave_block(kind, rnd):
    c = Canvas(16, 16)
    if kind in ('rock', 'rock2', 'rock3'):
        noise(c, rnd, 0, 0, 15, 15, {11: 6, 10: 3, 12: 1})
        for _ in range(3):
            x, y = rnd.randrange(14), rnd.randrange(14)
            c.rect(x, y, x + 2, y, 12)
            c.rect(x, y + 1, x + 2, y + 1, 10)
    elif kind == 'pipe_h':
        noise(c, rnd, 0, 0, 15, 15, {11: 6, 10: 3})
        c.rect(0, 5, 15, 10, 14)
        c.rect(0, 6, 15, 6, 15 if False else 14)
        c.rect(0, 5, 15, 5, 13)
        c.rect(0, 10, 15, 10, 13)
        c.rect(0, 4, 15, 4, 10)
        c.rect(0, 11, 15, 11, 10)
        c.rect(6, 4, 8, 11, 13)
    elif kind == 'pipe_v':
        noise(c, rnd, 0, 0, 15, 15, {11: 6, 10: 3})
        c.rect(5, 0, 10, 15, 14)
        c.rect(5, 0, 5, 15, 13)
        c.rect(10, 0, 10, 15, 13)
        c.rect(4, 0, 4, 15, 10)
        c.rect(11, 0, 11, 15, 10)
    elif kind == 'beam':
        noise(c, rnd, 0, 0, 15, 15, {11: 6, 10: 3})
        c.rect(4, 0, 11, 15, 12)
        c.rect(4, 0, 4, 15, 13)
        c.rect(11, 0, 11, 15, 10)
        for y in (2, 10):
            c.rect(6, y, 9, y + 1, 10)
    elif kind == 'lamp':
        noise(c, rnd, 0, 0, 15, 15, {11: 6, 10: 3})
        c.rect(4, 0, 11, 15, 12)
        c.rect(4, 0, 4, 15, 13)
        c.rect(11, 0, 11, 15, 10)
        c.rect(5, 6, 10, 9, 15)
        c.rect(6, 7, 9, 8, 15)
    return c

def cave_backdrop():
    rnd = random.Random(99)
    blocks = {k: cave_block(k, random.Random(hash(k) % 1000)) for k in
              ('rock', 'rock2', 'rock3', 'pipe_h', 'pipe_v', 'beam', 'lamp')}
    c = Canvas(256, 128)
    grid = [[rnd.choice(('rock', 'rock2', 'rock3')) for _ in range(16)] for _ in range(8)]
    for x in range(16):
        grid[2][x] = 'pipe_h'
    for y in range(8):
        grid[y][5] = 'beam' if y != 2 else 'pipe_h'
        grid[y][13] = 'pipe_v' if y != 2 else 'pipe_h'
    grid[5][5] = 'lamp'
    for y in range(8):
        for x in range(16):
            c.blit(blocks[grid[y][x]], x * 16, y * 16, transparent=False)
    return c

def build_bg2():
    """BG2 tilemap 32x64: rows 0-19 skyline, rows 20-63 cave pattern (period 16)."""
    sky = skyline()
    cave = cave_backdrop()
    big = Canvas(256, 512)
    big.blit(sky, 0, 0, transparent=False)
    for i in range(3):
        big.blit(cave, 0, 160 + i * 128, transparent=False)
    data, entries, n = dedupe_tiles(big.crop(0, 0, 256, 512), 512)
    return data, entries, n, big

# ------------------------------------------------------------ font
FONT = {
    ' ': ["", "", "", "", "", "", ""],
    '!': ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
    '"': [".#.#.", ".#.#.", "", "", "", "", ""],
    '#': [".#.#.", "#####", ".#.#.", ".#.#.", "#####", ".#.#.", ""],
    '$': ["..#..", ".####", "#.#..", ".###.", "..#.#", "####.", "..#.."],
    '%': ["##..#", "##.#.", "..#..", ".#...", "#..##", "...##", ""],
    '&': [".##..", "#..#.", ".##..", "#.#.#", "#..#.", ".##.#", ""],
    "'": ["..#..", "..#..", "", "", "", "", ""],
    '(': ["...#.", "..#..", ".#...", ".#...", ".#...", "..#..", "...#."],
    ')': [".#...", "..#..", "...#.", "...#.", "...#.", "..#..", ".#..."],
    '*': ["", "#.#.#", ".###.", "#####", ".###.", "#.#.#", ""],
    '+': ["", "..#..", "..#..", "#####", "..#..", "..#..", ""],
    ',': ["", "", "", "", "", "..#..", ".#..."],
    '-': ["", "", "", "#####", "", "", ""],
    '.': ["", "", "", "", "", "", "..#.."],
    '/': ["....#", "...#.", "..#..", ".#...", "#....", "", ""],
    '0': [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
    '1': ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
    '2': [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
    '3': ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
    '4': ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
    '5': ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
    '6': ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
    '7': ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
    '8': [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
    '9': [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
    ':': ["", "..#..", "", "", "", "..#..", ""],
    ';': ["", "..#..", "", "", "", "..#..", ".#..."],
    '<': ["...#.", "..#..", ".#...", "#....", ".#...", "..#..", "...#."],
    '=': ["", "", "#####", "", "#####", "", ""],
    '>': [".#...", "..#..", "...#.", "....#", "...#.", "..#..", ".#..."],
    '?': [".###.", "#...#", "....#", "...#.", "..#..", "", "..#.."],
    '@': [".###.", "#...#", "#.###", "#.#.#", "#.###", "#....", ".###."],
    'A': [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    'B': ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
    'C': [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
    'D': ["###..", "#..#.", "#...#", "#...#", "#...#", "#..#.", "###.."],
    'E': ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    'F': ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
    'G': [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
    'H': ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    'I': [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
    'J': ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
    'K': ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
    'L': ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    'M': ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
    'N': ["#...#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"],
    'O': [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    'P': ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
    'Q': [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
    'R': ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    'S': [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    'T': ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    'U': ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    'V': ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
    'W': ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
    'X': ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
    'Y': ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
    'Z': ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
    '[': [".###.", ".#...", ".#...", ".#...", ".#...", ".#...", ".###."],
    '\\': ["#....", ".#...", "..#..", "...#.", "....#", "", ""],
    ']': [".###.", "...#.", "...#.", "...#.", "...#.", "...#.", ".###."],
    '^': ["..#..", ".#.#.", "#...#", "", "", "", ""],
    '_': ["", "", "", "", "", "", "#####"],
}

def glyph_canvas(ch, bg):
    c = Canvas(8, 8, bg)
    rows = FONT[ch]
    for y, row in enumerate(rows):
        for x, p in enumerate(row):
            if p == '#':
                c.set(x + 1, y, 2)
    # drop shadow
    for y in range(7, -1, -1):
        for x in range(7, -1, -1):
            if c.get(x, y) == 2:
                if c.get(x + 1, y + 1) == bg:
                    c.set(x + 1, y + 1, 3)
    return c

def special_glyphs(bg):
    """HUD glyphs, placed after the 64 text glyphs."""
    out = []
    # 0: health segment full, 1: empty, 2: half
    for kind in ('full', 'empty', 'half'):
        c = Canvas(8, 8, bg)
        c.rect(0, 1, 6, 6, 3)
        if kind == 'full':
            c.rect(1, 2, 5, 5, 2)
        elif kind == 'half':
            c.rect(1, 2, 2, 5, 2)
        else:
            c.rect(1, 2, 5, 5, bg)
        out.append(c)
    # 3: solid block (for boxes), 4: arrow right, 5: heart, 6: key, 7: skull
    c = Canvas(8, 8, 2); out.append(c)
    c = Canvas(8, 8, bg)
    for i in range(4):
        c.rect(2 + i, i, 2 + i, 6 - i, 2)
    out.append(c)
    heart = ["........", ".##.##..", "#######.", "#######.", ".#####..", "..###...", "...#....", "........"]
    key = ["........", ".##.....", "#..####.", ".##..#.#", "........", "........", "........", "........"]
    skull = [".#####..", "#######.", "#..#..#.", "#######.", ".#####..", ".#.#.#..", "........", "........"]
    for art in (heart, key, skull):
        c = Canvas(8, 8, bg)
        for y, row in enumerate(art):
            for x, p in enumerate(row):
                if p == '#':
                    c.set(x, y, 2)
        out.append(c)
    # 8..15: automap shading (2x2 cells handled at runtime) - reserved
    return out

def build_font():
    """BG3 2bpp chars: 0-63 opaque glyphs (ASCII 32-95), 64-71 opaque HUD
    glyphs, 128-191 transparent glyphs, 192-199 transparent HUD glyphs."""
    chars = []
    for bg in (1, 0):
        for code in range(32, 96):
            chars.append(glyph_canvas(chr(code), bg))
        sp = special_glyphs(bg)
        chars.extend(sp)
        while len(chars) % 128:
            chars.append(Canvas(8, 8, bg))
    return b''.join(enc2(c.p) for c in chars)


# ------------------------------------------------------------ title logo
def build_logo(title, first_char):
    """Big neon title, 256x48, CITY palette (BG palette 5). Two lines if long."""
    words = title.split()
    if len(title) > 14 and len(words) > 1:
        # split into two balanced lines
        best = None
        for i in range(1, len(words)):
            a, b = ' '.join(words[:i]), ' '.join(words[i:])
            score = max(len(a), len(b))
            if best is None or score < best[0]:
                best = (score, a, b)
        lines = [best[1], best[2]]
    else:
        lines = [title]
    c = Canvas(256, 48)
    longest = max(len(l) for l in lines)
    scale = 3 if longest <= 13 else 2
    gh = 7 * scale
    total_h = len(lines) * gh + (len(lines) - 1) * 4
    y0 = (48 - total_h) // 2
    for li, line in enumerate(lines):
        w = len(line) * 6 * scale - scale
        x0 = (256 - w) // 2
        y = y0 + li * (gh + 4)
        for ci, ch in enumerate(line):
            rows = FONT.get(ch, FONT[' '])
            for gy, row in enumerate(rows):
                for gx, p in enumerate(row):
                    if p == '#':
                        for sy in range(scale):
                            for sx in range(scale):
                                px = x0 + ci * 6 * scale + gx * scale + sx
                                py = y + gy * scale + sy
                                # vertical neon gradient: white core top, cyan, deep blue
                                frac = (gy * scale + sy) / gh
                                col = 15 if frac < 0.2 else (11 if frac < 0.5 else 10)
                                c.set(px, py, col)
    # glow outline in pink, then dark edge
    c.outline(8)
    c.outline(1)
    data, entries, n = dedupe_tiles(c, 512 - first_char, first_char)
    entries = [(e & ~(7 << 10)) | (5 << 10) for e in entries]
    return data, entries, n

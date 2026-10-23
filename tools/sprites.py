"""Sprite art for Underground Labyrinth.

Characters are built from separate parts (head, torso, gun arm, legs) so that
parts can be shot off. Facing right; feet-center is the character origin.
Produces 512 OBJ characters plus constants for the assembler.
"""
import math
from snesgfx import Canvas, LETTERS, chars_of, enc4

L = LETTERS

# ---------------------------------------------------------------- allocator
class SpriteSheet:
    """16 x 32 grid of 8x8 chars (two OBJ name tables)."""
    def __init__(self):
        self.grid = Canvas(128, 256)
        self.next_block = 0          # 16x16 blocks, 8 per row, 16 rows
        self.small = []              # free 8x8 tiles
        self.names = {}              # name -> tile number (0..511)
        self.order = []

    def _block_tile(self, b):
        bx, by = b % 8, b // 8
        return by * 32 + bx * 2

    def big(self, name, canvas):
        assert canvas.w == 16 and canvas.h == 16, name
        b = self.next_block
        self.next_block += 1
        assert b < 128, 'out of sprite blocks'
        t = self._block_tile(b)
        self.grid.blit(canvas, (t % 16) * 8, (t // 16) * 8, transparent=False)
        self.names[name] = t
        self.order.append((name, t, 16))
        return t

    def tiny(self, name, canvas):
        assert canvas.w == 8 and canvas.h == 8, name
        if not self.small:
            t = self._block_tile(self.next_block)
            self.next_block += 1
            self.small = [t, t + 1, t + 16, t + 17]
        t = self.small.pop(0)
        self.grid.blit(canvas, (t % 16) * 8, (t // 16) * 8, transparent=False)
        self.names[name] = t
        self.order.append((name, t, 8))
        return t

    def chr_bytes(self):
        out = bytearray()
        for ch in chars_of(self.grid):
            out += enc4(ch)
        return bytes(out)

def A(rows):
    return Canvas.art(rows)

# ------------------------------------------------------------------ heads
PLAYER_HEAD = A([
    "..kkkk..",
    ".kmllmk.",
    "kmllmmmk",
    "kmmkvVVk",
    "kmmvVwVk",
    "kdmmvvvk",
    ".kddmmk.",
    "..kkkk..",
])
PLAYER_HEAD_DMG = A([
    "..kkkk..",
    ".kmllmk.",
    "kmllmkkk",
    "kmmkSSSk",
    "kmmkSkRk",
    "kdmmkSsk",
    ".kddmrk.",
    "..kkkk..",
])
GUARD_HEAD = A([
    "..kkkk..",
    ".kddddk.",
    ".kdddddk",
    ".kSSSkkk",
    ".kSSvSk.",
    ".kSSSSk.",
    "..ksSk..",
    "...kk...",
])
SOLDIER_HEAD = A([
    "..kkkk..",
    ".kmmmmk.",
    "kmllmmmk",
    "kddddddk",
    ".kSvSSk.",
    ".kSSSsk.",
    "..ksSk..",
    "...kk...",
])
BERET_HEAD = A([
    "........",
    ".kkkkk..",
    "kVVVVVk.",
    "kvvvvVVk",
    ".kSkSSk.",
    ".kSSSSk.",
    "..ksSk..",
    "...kk...",
])
CAPTIVE_HEAD = A([
    "..kkkk..",
    ".kvvvvk.",
    "kvvvvvvk",
    "kvSSkSk.",
    "kvSSSSk.",
    ".kSSSsk.",
    "..kssk..",
    "...kk...",
])
FRIEND_HEAD = A([
    "..kkkk..",
    ".kVVVVk.",
    "kVVVVVVk",
    "kkVSSkSk",
    "kVkSSSSk",
    "kVkSSSk.",
    ".k.ksk..",
    "....k...",
])
ROBOT_HEAD = A([
    "..kkkk..",
    ".kGllGk.",
    "kGllllGk",
    "kmkkkkmk",
    "kkVVvVkk",
    "kmkkkkmk",
    ".kmmmmk.",
    "..kddk..",
])

# ----------------------------------------------------------------- torsos
PLAYER_TORSO = A([
    "................",
    "......kkkk......",
    "....kkdmmlkk....",
    "...kOOdmmllOk...",
    "..kOOOdmmllOOk..",
    "..kOoOdmlwlOOk..",
    "..kkkkdmmllkkk..",
    "....kddmmmlk....",
    "....kdmmmmmk....",
    "....kdmllmmk....",
    "....kddmmmdk....",
    "....kOkOkOkk....",
    "....kddddddk....",
    "................",
    "................",
    "................",
])
# shoulder plate shot off: exposed, scorched undersuit
PLAYER_TORSO_DMG = A([
    "................",
    "......kkkk......",
    "....kkdmmlkk....",
    "....kkdmmllOk...",
    "...krddmmllOOk..",
    "...kdRdmlwlOOk..",
    "...kkkdmmllkkk..",
    "....kddmmmlk....",
    "....kdmmrmmk....",
    "....kdmllmmk....",
    "....kddmmmdk....",
    "....kOkOkOkk....",
    "....kddddddk....",
    "................",
    "................",
    "................",
])
HUMAN_TORSO = A([
    "................",
    "......kkkk......",
    ".....kdssdk.....",
    "....kdmmmmlk....",
    "...kdmmmmmllk...",
    "...kdmmOmmllk...",
    "...kdmmmmmmlk...",
    "....kdmmmmlk....",
    "....kdmmmmmk....",
    "....kddmmmmk....",
    "....kddmmmdk....",
    "....kooOoook....",
    "....kddddddk....",
    "................",
    "................",
    "................",
])
ROBOT_TORSO = A([
    "................",
    "................",
    "....kkkkkkkk....",
    "...kGllllllGk...",
    "...klmmmmmmlk...",
    "...klmOkkOmlk...",
    "...klmkSSkmlk...",
    "...klmkSwkmlk...",
    "...klmOkkOmlk...",
    "...klmmmmmmlk...",
    "...kdddddddddk..",
    "....kOkOkOkOk...",
    "....kddddddk....",
    "................",
    "................",
    "................",
])
PLAYER_BACKARM = A([
    "..kkk...",
    ".kddmk..",
    ".kddmk..",
    ".kddk...",
    ".kdmk...",
    ".kddk...",
    ".kgGk...",
    "..kk....",
])

# ------------------------------------------------------------------- legs
# Leg poses: per leg (hip, knee, foot) in 16x16 legs-canvas coordinates.
HIP_B, HIP_F = (7, 3.5), (9, 3.5)
POSES = {
    'stand':  [((6.5, 9), (6, 13)), ((9.5, 9), (10, 13))],
    'walk1':  [((5, 9), (3, 13)), ((11, 8.5), (12.5, 13))],
    'walk2':  [((7.5, 8.5), (6, 11.5)), ((9, 9), (9, 13))],
    'walk3':  [((11, 8.5), (12.5, 13)), ((5, 9), (3, 13))],
    'walk4':  [((9, 9), (9, 13)), ((7.5, 8.5), (6, 11.5))],
    'jump':   [((5, 7.5), (4, 11)), ((12, 7), (11, 11.5))],
    'crouch': [((4.5, 12), (5, 13.5)), ((12.5, 11), (12, 13.5))],
    'climb1': [((6, 8), (6, 11)), ((10, 9.5), (10, 13))],
    'climb2': [((6, 9.5), (6, 13)), ((10, 8), (10, 11))],
}
CROUCH_HIP = 8  # hips sit this much lower when crouched

def legs(pose, r, back, front, shade_b, shade_f, boot, knee_pad=None, joints=None, hip_shift=0):
    c = Canvas(16, 16)
    (kb, fb), (kf, ff) = POSES[pose]
    for (hip, knee, foot, col, sh) in ((HIP_B, kb, fb, back, shade_b), (HIP_F, kf, ff, front, shade_f)):
        hx, hy = hip[0], hip[1] + hip_shift
        c.capsule(hx, hy, knee[0], knee[1], r, col, sh)
        c.capsule(knee[0], knee[1], foot[0], foot[1], r * 0.9, col, sh)
        # boot: sole sits on row 15
        fx, fy = foot
        c.rect(int(fx - 1.5), int(fy), int(fx + 2.5), 14, boot)
        if joints is not None:
            c.disc(knee[0], knee[1], 1.2, joints)
    if knee_pad is not None:
        c.disc(kf[0] + 0.5, kf[1], 1.3, knee_pad)
    # hips / belt
    c.rect(5, 2 + hip_shift, 10, 4 + hip_shift, back)
    c.rect(6, 2 + hip_shift, 9, 3 + hip_shift, front)
    c.outline(L['k'])
    return c

def player_legs(pose):
    return legs(pose, 1.9, L['d'], L['m'], L['d'], L['d'], L['g'], knee_pad=L['O'],
                hip_shift=CROUCH_HIP if pose == 'crouch' else 0)

def human_legs(pose):
    return legs(pose, 1.5, L['d'], L['m'], L['d'], L['d'], L['k'] if False else L['g'],
                hip_shift=CROUCH_HIP if pose == 'crouch' else 0)

def robot_legs(pose):
    return legs(pose, 1.1, L['d'], L['m'], L['d'], L['d'], L['G'], joints=L['O'])

# ------------------------------------------------------------------- arms
# Aim directions: 0 forward, 1 up, 2 diagonal up, 3 diagonal down
AIMS = [(1, 0), (0, -1), (0.7071, -0.7071), (0.7071, 0.7071)]
ELBOWS = [(1, 4), (3, 1), (3, 2.5), (1, 4)]
HANDS = [(4, 3), (3, -4), (4, -2), (4, 5)]
SHOULDER = (1, -22)  # relative to character origin (feet center)

def arm(aim, sleeve, sleeve_shade, hand, gun_len, gun_r, armored):
    while True:
        try:
            return _arm(aim, sleeve, sleeve_shade, hand, gun_len, gun_r, armored)
        except AssertionError:
            gun_len -= 1
            assert gun_len > 4

def _arm(aim, sleeve, sleeve_shade, hand, gun_len, gun_r, armored):
    c = Canvas(32, 32)
    sx, sy = 16, 16
    ex, ey = sx + ELBOWS[aim][0], sy + ELBOWS[aim][1]
    hx, hy = sx + HANDS[aim][0], sy + HANDS[aim][1]
    dx, dy = AIMS[aim]
    # gun body (behind hand): from slightly behind the hand to the muzzle
    bx0, by0 = hx - dx * 2, hy - dy * 2
    mx, my = hx + dx * gun_len, hy + dy * gun_len
    c.capsule(bx0, by0, mx, my, gun_r, L['G'], L['g'])
    # stock / magazine nub
    c.capsule(hx + dx * 2, hy + dy * 2, hx + dx * 2 + dy * 2.5, hy + dy * 2 - dx * -2.5, 0.9, L['g'])
    # arm
    r = 1.9 if armored else 1.5
    c.capsule(sx, sy, ex, ey, r, sleeve, sleeve_shade)
    c.capsule(ex, ey, hx, hy, r * 0.9, sleeve, sleeve_shade)
    if armored:
        c.disc(sx, sy, 2.2, L['O'])  # shoulder pad
    c.disc(hx, hy, 1.3, hand)
    c.outline(L['k'])
    x0, y0, x1, y1 = c.bbox()
    assert x1 - x0 < 16 and y1 - y0 < 16, ('arm too big', aim, x1 - x0, y1 - y0)
    out = c.crop(x0, y0, 16, 16)
    # offsets relative to the shoulder
    return out, (x0 - sx, y0 - sy), (round(mx - sx), round(my - sy))

def cannon_arm(aim):
    c = Canvas(32, 32)
    sx, sy = 16, 16
    dx, dy = AIMS[aim]
    ex, ey = sx + ELBOWS[aim][0], sy + ELBOWS[aim][1]
    hx, hy = sx + HANDS[aim][0], sy + HANDS[aim][1]
    c.capsule(sx, sy, ex, ey, 1.4, L['m'], L['d'])
    mx, my = hx + dx * 6, hy + dy * 6
    c.capsule(hx - dx, hy - dy, mx, my, 2.0, L['l'], L['m'])
    c.disc(mx - dx, my - dy, 1.0, L['V'])
    c.disc(sx, sy, 1.6, L['O'])
    c.outline(L['k'])
    x0, y0, x1, y1 = c.bbox()
    assert x1 - x0 < 16 and y1 - y0 < 16, ('cannon', aim, x1 - x0, y1 - y0)
    return c.crop(x0, y0, 16, 16), (x0 - sx, y0 - sy), (round(mx - sx), round(my - sy))

# ----------------------------------------------------------------- robots
CRAWLER = [A([
    "................",
    "................",
    "................",
    "................",
    "................",
    "......kkkkk.....",
    "....kkGllllkk...",
    "...kGlllmmmlVk..",
    "..kGlmmmmmmmVVk.",
    "..kmmmOkOkOmmmk.",
    "..kddddddddddk..",
    "...kkkkkkkkkk...",
    "...kgk.kgk.kgk..",
    "..kgk..kgk..kgk.",
    "..kk...kk....kk.",
    "................",
]), A([
    "................",
    "................",
    "................",
    "................",
    "................",
    "......kkkkk.....",
    "....kkGllllkk...",
    "...kGlllmmmlVk..",
    "..kGlmmmmmmmVVk.",
    "..kmmmkOkOkmmmk.",
    "..kddddddddddk..",
    "...kkkkkkkkkk...",
    "....kgk.kgk.kgk.",
    "....kgk..kgkkgk.",
    "....kk....kkkk..",
    "................",
])]
CRAWLER_TOP = A([
    "........",
    "...kk...",
    "..kVVk..",
    "...kk...",
    "...kk...",
    "..kGGk..",
    ".kGllGk.",
    "..kkkk..",
])
DRONE = [A([
    "................",
    "..kkkk....kkkk..",
    ".kGGGGk..kGGGGk.",
    "..kkkk.kk.kkkk..",
    "......kGlk......",
    "....kkGlllkk....",
    "...kGllmmmllk...",
    "..kGlmkVVkmmlk..",
    "..kGlmkVwkmmlk..",
    "..kdmmmkkmmmdk..",
    "...kddmmmmddk...",
    "....kkddddkk....",
    "......kkkk......",
    "................",
    "................",
    "................",
]), A([
    "................",
    "...kk......kk...",
    "..kGGk....kGGk..",
    "...kk..kk..kk...",
    "......kGlk......",
    "....kkGlllkk....",
    "...kGllmmmllk...",
    "..kGlmkvVkmmlk..",
    "..kGlmkVVkmmlk..",
    "..kdmmmkkmmmdk..",
    "...kddmmmmddk...",
    "....kkddddkk....",
    "......kkkk......",
    "................",
    "................",
    "................",
])]
DRONE_GUN = A([
    "..kkkk..",
    ".kgGGgk.",
    ".kgGGgkk",
    "..kgggGk",
    "...kkkk.",
    "........",
    "........",
    "........",
])

def heavy_body():
    c = Canvas(32, 16)
    c.rect(5, 1, 26, 14, L['m'])
    c.rect(5, 1, 26, 2, L['l'])
    c.rect(5, 12, 26, 14, L['d'])
    c.rect(5, 1, 6, 14, L['l'])
    c.rect(25, 1, 26, 14, L['d'])
    # visor
    c.rect(19, 4, 24, 6, L['k'])
    c.rect(20, 5, 23, 5, L['V'])
    c.set(22, 5, L['w'])
    # hazard stripes
    for i in range(8, 17, 2):
        c.rect(i, 9, i, 10, L['O'])
        c.rect(i + 1, 9, i + 1, 10, L['k'])
    # shoulder housing
    c.rect(2, 3, 5, 9, L['G'])
    c.rect(2, 3, 5, 3, L['l'])
    # rivets
    for x in (8, 14):
        c.set(x, 4, L['d'])
    # corner rounding
    for (x, y) in ((5, 1), (26, 1), (5, 14), (26, 14)):
        c.set(x, y, 0)
    c.outline(L['k'])
    return c

def heavy_legs(frame):
    c = Canvas(32, 16)
    feet = [((10, 1), (8, 8), (7, 12)), ((21, 1), (23, 8), (24, 12))]
    if frame == 1:
        feet = [((10, 1), (11, 7), (11, 11)), ((21, 1), (20, 8), (19, 12))]
    for (hip, knee, foot) in feet:
        c.capsule(hip[0], hip[1], knee[0], knee[1], 2.4, L['m'], L['d'])
        c.capsule(knee[0], knee[1], foot[0], foot[1], 2.2, L['m'], L['d'])
        c.disc(knee[0], knee[1], 1.6, L['O'])
        c.rect(foot[0] - 4, foot[1] + 1, foot[0] + 4, 14, L['G'])
        c.rect(foot[0] - 4, 14, foot[0] + 4, 14, L['g'])
    c.rect(8, 0, 23, 2, L['d'])
    c.outline(L['k'])
    return c

# ---------------------------------------------------------- objects
def generator(frame):
    c = Canvas(16, 32)
    c.rect(2, 2, 13, 29, L['m'])
    c.rect(2, 2, 3, 29, L['l'])
    c.rect(12, 2, 13, 29, L['d'])
    c.rect(1, 0, 14, 3, L['G'])
    c.rect(1, 27, 14, 31, L['G'])
    c.rect(1, 31, 14, 31, L['g'])
    # coils
    for y in range(6, 25, 3):
        c.rect(3, y, 12, y, L['r'] if frame < 2 else L['d'])
    # core window
    if frame < 2:
        c.rect(5, 8, 10, 22, L['S'] if frame == 0 else L['s'])
        c.rect(7, 10, 8, 20, L['w'] if frame == 0 else L['S'])
    else:
        c.rect(5, 8, 10, 22, L['k'])
        c.set(6, 12, L['g']); c.set(9, 17, L['g'])
    c.rect(6, 25, 9, 26, L['V'] if frame == 0 else L['v'])
    c.outline(L['k'])
    return c

def terminal(frame):
    c = Canvas(16, 16)
    c.rect(1, 1, 14, 15, L['d'])
    c.rect(1, 1, 14, 1, L['m'])
    c.rect(2, 2, 13, 9, L['k'])
    if frame < 2:
        col = L['S'] if frame == 0 else L['s']
        for y in (3, 5, 7):
            c.rect(3, y, 3 + (5 + y + frame * 3) % 9, y, col)
        c.rect(3, 12, 4, 13, L['V'])
        c.rect(6, 12, 7, 13, L['O'])
    else:
        c.rect(3, 3, 12, 8, L['k'])
        c.set(5, 5, L['g']); c.set(9, 6, L['g'])
        c.rect(3, 12, 4, 13, L['v'])
    c.rect(9, 11, 13, 14, L['g'])
    c.rect(10, 12, 12, 12, L['G'])
    c.outline(L['k'])
    return c

def terminal_base():
    c = Canvas(16, 16)
    c.rect(5, 0, 10, 13, L['m'])
    c.rect(5, 0, 5, 13, L['l'])
    c.rect(10, 0, 10, 13, L['d'])
    c.rect(2, 12, 13, 15, L['G'])
    c.rect(2, 12, 13, 12, L['l'])
    for y in (3, 7):
        c.rect(6, y, 9, y, L['k'])
    c.set(7, 10, L['V'])
    c.outline(L['k'])
    return c

def elevator_piece(kind):
    c = Canvas(8, 8)
    c.rect(0, 0, 7, 5, L['m'])
    c.rect(0, 0, 7, 0, L['l'])
    c.rect(0, 5, 7, 5, L['d'])
    for x in range(0, 8, 4):
        c.rect(x + 1, 2, x + 2, 3, L['O'])
        c.rect(x + 3, 2, x + 3, 3, L['k'])
    if kind == 'l':
        c.rect(0, 0, 0, 5, L['k'])
    if kind == 'r':
        c.rect(7, 0, 7, 5, L['k'])
    c.rect(0, 6, 7, 7, 0)
    c.rect(0, 6, 7, 6, L['k'])
    return c

# --------------------------------------------------------------- pickups
GLYPHS = {
    'plus': ["..#..", "..#..", "#####", "..#..", "..#.."],
    'bullets': ["#.#.#", "#.#.#", "#.#.#", "#####", "#####"],
    'cell': [".###.", "#...#", "#.#.#", "#...#", ".###."],
    'bolt': ["...##", "..##.", ".####", ".##..", "##..."],
    'rail': ["#....", ".#...", "..###", ".#...", "#...."],
    'nade': [".##..", "#####", "#####", "#####", ".###."],
    'key': [".##..", "#..##", ".##.#", "...#.", "....."],
    'chip': ["#.#.#", "#####", "#####", "#####", "#.#.#"],
}

def pickup(box_d, box_m, box_l, sym, glyph):
    c = Canvas(16, 16)
    c.rect(2, 3, 13, 14, box_m)
    c.rect(2, 3, 13, 4, box_l)
    c.rect(2, 13, 13, 14, box_d)
    c.rect(4, 5, 11, 12, L['k'])
    g = GLYPHS[glyph]
    for y, row in enumerate(g):
        for x, ch in enumerate(row):
            if ch == '#':
                c.set(5 + x + 1, 6 + y + 1, sym)
    c.outline(L['k'])
    return c

# --------------------------------------------------------------- effects
def explosion(f):
    import random
    rnd = random.Random(40 + f)
    c = Canvas(16, 16)
    rad = [3.5, 6.0, 7.2, 7.6][f]
    layers = [(rad, L['d']), (rad * 0.8, L['m']), (rad * 0.55, L['l']), (rad * 0.3, L['w'])]
    if f == 3:
        layers = [(rad, L['g']), (rad * 0.8, L['G']), (rad * 0.45, L['d'])]
    for (r, col) in layers:
        for y in range(16):
            for x in range(16):
                d = math.hypot(x + 0.5 - 8, y + 0.5 - 8)
                if d <= r * (0.85 + rnd.random() * 0.3):
                    c.set(x, y, col)
    if f == 3:
        for _ in range(18):
            c.set(rnd.randrange(16), rnd.randrange(16), 0)
    return c

SMALL = {
    'bullet': ["........", "........", "...ww...", "..wllO..", "..wllO..", "...OO...", "........", "........"],
    'ebullet': ["........", "........", "...RR...", "..RwwR..", "..RwwR..", "...RR...", "........", "........"],
    'plasma0': ["...OO...", "..OwwO..", ".OwwwwO.", "OwwOOwwO", "OwwOOwwO", ".OwwwwO.", "..OwwO..", "...OO..."],
    'plasma1': ["..o..o..", "o.OOOO.o", ".OwwwwO.", ".OwOOwO.", ".OwOOwO.", ".OwwwwO.", "o.OOOO.o", "..o..o.."],
    'eplasma': ["...ll...", "..lwwl..", ".lwwwwl.", "lmwwwwml", "lmwwwwml", ".lmwwml.", "..lmml..", "...ll..."],
    'emp0': ["..v..v..", "...VV...", "v.VwwV.v", ".VwwwwV.", ".VwwwwV.", "v.VwwV.v", "...VV...", "..v..v.."],
    'emp1': ["v......v", ".V.VV.V.", "..VwwV..", ".VwwwwV.", ".VwwwwV.", "..VwwV..", ".V.VV.V.", "v......v"],
    'rail_h': ["........", "........", "SSSSSSSS", "wwwwwwww", "wwwwwwww", "SSSSSSSS", "........", "........"],
    'rail_v': ["..SwwS..", "..SwwS..", "..SwwS..", "..SwwS..", "..SwwS..", "..SwwS..", "..SwwS..", "..SwwS.."],
    'rail_d': [".....Sww", "....Swws", "...SwwS.", "..SwwS..", ".SwwS...", "SwwS....", "wwS.....", "wS......"],
    'muzzle0': ["........", "..l.....", "..lll...", ".lwwwll.", ".lwwwll.", "..lll...", "..l.....", "........"],
    'muzzle1': ["...l....", "l..ll...", ".lwwwl..", "lwwwwwll", "lwwwwwll", ".lwwwl..", "l..ll...", "...l...."],
    'spark0': ["........", "...l....", "...l....", ".llwll..", "...l....", "...l....", "........", "........"],
    'spark1': ["........", ".l...l..", "..l.l...", "...w....", "..l.l...", ".l...l..", "........", "........"],
    'smoke0': ["........", "..gGG...", ".gGGGg..", ".GGGGGg.", ".gGGGGg.", "..ggGg..", "........", "........"],
    'smoke1': [".g..g...", "gGg.Gg..", ".gG.gGg.", "..g..g..", ".Gg.....", "gGg..gG.", ".g...g..", "........"],
    'stun': ["...V....", "..Vw.V..", ".V..Vw..", "V.....V.", "..wV....", ".V..V...", "....wV..", "...V...."],
}
DEBRIS = {
    'blood0': ["........", "........", "...R....", "..RRr...", "..Rrr...", "...r....", "........", "........"],
    'blood1': ["........", "........", "........", "...R....", "...r....", "........", "........", "........"],
    'splat': ["........", "........", "........", "........", "........", "....R...", ".rRRrRr.", "rrRrrRrr"],
    'rock0': ["........", "...kk...", "..kmlk..", ".kdmmlk.", ".kddmmk.", "..kddk..", "...kk...", "........"],
    'rock1': ["........", "........", "..kkk...", ".kmlmk..", ".kdmdk..", "..kkk...", "........", "........"],
    'metal0': ["........", "..kk....", ".kOOk...", ".kOoOkk.", "..kkoOk.", "....kk..", "........", "........"],
    'metal1': ["........", "........", "..kkkk..", ".kOOOOk.", "..kooook", "...kkkk.", "........", "........"],
    'chunk': ["........", "..kkk...", ".kmllk..", ".kdmmlk.", ".kddmmk.", "..kddk..", "...kk...", "........"],
}
UI = {
    'marker': ["...ww...", "..wVVw..", ".wVVVVw.", "wVVwwVVw", "wVVwwVVw", ".wVVVVw.", "..wVVw..", "...ww..."],
    'target': ["RR....RR", "R.RRRR.R", ".RR..RR.", ".R.RR.R.", ".R.RR.R.", ".RR..RR.", "R.RRRR.R", "RR....RR"],
    'alert': ["...OO...", "..kOOk..", "..kOOk..", "..kOOk..", "...kk...", "...OO...", "...OO...", "........"],
    'arrow': ["...OO...", "...OO...", "...OO...", "...OO...", "OOOOOOOO", ".OOOOOO.", "..OOOO..", "...OO..."],
}
GRENADE = [A(["........", "...kk...", "..kmmk..", ".kmllmk.", ".kdmmmk.", ".kddmmk.", "..kkkk..", "........"]),
           A(["........", "..kkk...", ".kmlmk..", ".kmlmmk.", "..kdmmk.", "..kddk..", "...kk...", "........"])]
GRENADE_PIN = None

def build():
    sh = SpriteSheet()
    exports = {}
    tables = {}

    # --- player
    for p in ['stand', 'walk1', 'walk2', 'walk3', 'walk4', 'jump', 'crouch', 'climb1', 'climb2']:
        sh.big('PL_LEGS_' + p.upper(), player_legs(p))
    sh.big('PL_TORSO', PLAYER_TORSO)
    sh.big('PL_TORSO_DMG', PLAYER_TORSO_DMG)
    pl_arm = []
    for a in range(4):
        cv, ofs, muz = arm(a, L['m'], L['d'], L['g'], 9, 1.4, True)
        sh.big('PL_ARM%d' % a, cv)
        pl_arm.append((ofs, muz))
    sh.tiny('PL_HEAD', PLAYER_HEAD)
    sh.tiny('PL_HEAD_DMG', PLAYER_HEAD_DMG)
    sh.tiny('PL_BACKARM', PLAYER_BACKARM)

    # --- human enemies (palette 1/2) and captives (palette 7)
    for p in ['stand', 'walk1', 'walk2', 'walk3', 'walk4', 'crouch']:
        sh.big('HU_LEGS_' + p.upper(), human_legs(p))
    sh.big('HU_TORSO', HUMAN_TORSO)
    hu_arm = []
    for a in range(4):
        cv, ofs, muz = arm(a, L['m'], L['d'], L['S'], 8, 1.1, False)
        sh.big('HU_ARM%d' % a, cv)
        hu_arm.append((ofs, muz))
    sh.tiny('HU_HEAD_GUARD', GUARD_HEAD)
    sh.tiny('HU_HEAD_SOLDIER', SOLDIER_HEAD)
    sh.tiny('HU_HEAD_BERET', BERET_HEAD)
    sh.tiny('HU_HEAD_CAPTIVE', CAPTIVE_HEAD)
    sh.tiny('HU_HEAD_FRIEND', FRIEND_HEAD)

    # --- security robot (palette 3)
    for p in ['stand', 'walk1', 'walk2', 'walk3', 'walk4']:
        sh.big('RB_LEGS_' + p.upper(), robot_legs(p))
    sh.big('RB_TORSO', ROBOT_TORSO)
    rb_arm = []
    for a in range(4):
        cv, ofs, muz = cannon_arm(a)
        sh.big('RB_ARM%d' % a, cv)
        rb_arm.append((ofs, muz))
    sh.tiny('RB_HEAD', ROBOT_HEAD)

    # --- heavy robot
    hb = heavy_body()
    sh.big('HV_BODY_L', hb.crop(0, 0, 16, 16))
    sh.big('HV_BODY_R', hb.crop(16, 0, 16, 16))
    for f in range(2):
        hl = heavy_legs(f)
        sh.big('HV_LEGS%d_L' % f, hl.crop(0, 0, 16, 16))
        sh.big('HV_LEGS%d_R' % f, hl.crop(16, 0, 16, 16))
    cv, ofs, muz = cannon_arm(0)
    hv_arm = (ofs, muz)
    sh.big('HV_CANNON', cv)

    # --- small robots
    sh.big('CR_BODY0', CRAWLER[0])
    sh.big('CR_BODY1', CRAWLER[1])
    sh.tiny('CR_TOP', CRAWLER_TOP)
    sh.big('DR_BODY0', DRONE[0])
    sh.big('DR_BODY1', DRONE[1])
    sh.tiny('DR_GUN', DRONE_GUN)

    # --- objects
    for f in range(3):
        g = generator(f)
        sh.big('GEN%d_TOP' % f, g.crop(0, 0, 16, 16))
        sh.big('GEN%d_BOT' % f, g.crop(0, 16, 16, 16))
    for f in range(3):
        sh.big('TERM%d' % f, terminal(f))
    sh.big('TERM_BASE', terminal_base())
    sh.tiny('ELEV_L', elevator_piece('l'))
    sh.tiny('ELEV_M', elevator_piece('m'))
    sh.tiny('ELEV_R', elevator_piece('r'))

    # --- pickups (palette 6)
    sh.big('PK_HEALTH', pickup(L['G'], L['w'], L['w'], L['R'], 'plus'))
    sh.big('PK_MG', pickup(L['o'], L['O'], L['O'], L['O'], 'bullets'))
    sh.big('PK_PLASMA', pickup(L['d'], L['m'], L['l'], L['l'], 'cell'))
    sh.big('PK_EMP', pickup(L['v'], L['V'], L['V'], L['V'], 'bolt'))
    sh.big('PK_RAIL', pickup(L['s'], L['S'], L['S'], L['S'], 'rail'))
    sh.big('PK_GRENADE', pickup(L['d'], L['m'], L['m'], L['l'], 'nade'))
    sh.big('PK_KEY', pickup(L['v'], L['V'], L['w'], L['V'], 'key'))
    sh.big('PK_CHIP', pickup(L['o'], L['O'], L['w'], L['O'], 'chip'))

    # --- effects (palette 4)
    for f in range(4):
        sh.big('FX_EXPL%d' % f, explosion(f))
    for k, rows in SMALL.items():
        sh.tiny('FX_' + k.upper(), A(rows))
    sh.tiny('FX_GRENADE0', GRENADE[0])
    sh.tiny('FX_GRENADE1', GRENADE[1])
    # debris (palette 5)
    for k, rows in DEBRIS.items():
        sh.tiny('DB_' + k.upper(), A(rows))
    for k, rows in UI.items():
        sh.tiny('UI_' + k.upper(), A(rows))

    tables['pl_arm'] = pl_arm
    tables['hu_arm'] = hu_arm
    tables['rb_arm'] = rb_arm
    tables['hv_arm'] = hv_arm
    return sh, tables

def write_inc(sh, tables, path):
    lines = ['; generated by tools/sprites.py - sprite tile numbers (9-bit)']
    for name, t, size in sh.order:
        lines.append('SPR_%s = $%03X' % (name, t))
    lines.append('')
    sx, sy = SHOULDER
    for key in ('pl_arm', 'hu_arm', 'rb_arm'):
        ofs_x = [o[0] + sx for o, m in tables[key]]
        ofs_y = [o[1] + sy for o, m in tables[key]]
        muz_x = [m[0] + sx for o, m in tables[key]]
        muz_y = [m[1] + sy for o, m in tables[key]]
        h = lambda vs: ', '.join('$%04X' % (v & 0xFFFF) for v in vs)
        lines.append('.define %s_OX %s' % (key.upper(), h(ofs_x)))
        lines.append('.define %s_OY %s' % (key.upper(), h(ofs_y)))
        lines.append('.define %s_MX %s' % (key.upper(), h(muz_x)))
        lines.append('.define %s_MY %s' % (key.upper(), h(muz_y)))
    (o, m) = tables['hv_arm']
    # heavy cannon shoulder sits at (+6, -22) relative to heavy origin
    lines.append('HV_ARM_OX = $%04X' % ((o[0] + 6) & 0xFFFF))
    lines.append('HV_ARM_OY = $%04X' % ((o[1] - 22) & 0xFFFF))
    lines.append('HV_MUZ_X = $%04X' % ((m[0] + 6) & 0xFFFF))
    lines.append('HV_MUZ_Y = $%04X' % ((m[1] - 22) & 0xFFFF))
    open(path, 'w').write('\n'.join(lines) + '\n')

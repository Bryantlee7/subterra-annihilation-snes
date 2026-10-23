"""Shared helpers: canvases of palette indices, SNES tile encoding, colors."""
import math
import random

def rgb(h):
    """'#rrggbb' -> (r, g, b)"""
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

def bgr555(c):
    r, g, b = c
    return ((b >> 3) << 10) | ((g >> 3) << 5) | (r >> 3)

def pal_bytes(colors):
    """list of 16 '#rrggbb' -> 32 bytes"""
    out = bytearray()
    for c in colors:
        v = bgr555(rgb(c))
        out += bytes((v & 255, v >> 8))
    return bytes(out)

# Letters used in sprite ASCII art -> palette index. Every sprite palette
# assigns its own colors to these slots, so art can be shared between them.
LETTERS = {'.': 0, 'k': 1, 'd': 2, 'm': 3, 'l': 4, 'o': 5, 'O': 6, 'v': 7,
           'V': 8, 's': 9, 'S': 10, 'g': 11, 'G': 12, 'r': 13, 'R': 14,
           'w': 15}

class Canvas:
    def __init__(self, w, h, fill=0):
        self.w, self.h = w, h
        self.p = [[fill] * w for _ in range(h)]

    @classmethod
    def art(cls, rows, letters=LETTERS):
        h = len(rows)
        w = len(rows[0])
        c = cls(w, h)
        for y, row in enumerate(rows):
            assert len(row) == w, 'bad art row width %d: %r' % (len(row), row)
            for x, ch in enumerate(row):
                c.p[y][x] = letters[ch]
        return c

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.p[y][x]
        return 0

    def set(self, x, y, v):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.p[y][x] = v

    def rect(self, x0, y0, x1, y1, v):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, v)

    def blit(self, other, ox, oy, transparent=True):
        for y in range(other.h):
            for x in range(other.w):
                v = other.p[y][x]
                if v or not transparent:
                    self.set(ox + x, oy + y, v)

    def crop(self, x0, y0, w, h):
        c = Canvas(w, h)
        for y in range(h):
            for x in range(w):
                c.p[y][x] = self.get(x0 + x, y0 + y)
        return c

    def flip_h(self):
        c = Canvas(self.w, self.h)
        for y in range(self.h):
            c.p[y] = list(reversed(self.p[y]))
        return c

    def replace(self, a, b):
        c = self.copy()
        for row in c.p:
            for i, v in enumerate(row):
                if v == a:
                    row[i] = b
        return c

    def copy(self):
        c = Canvas(self.w, self.h)
        c.p = [list(r) for r in self.p]
        return c

    def outline(self, color=1):
        """Draw `color` on empty pixels 4-adjacent to filled pixels."""
        add = []
        for y in range(self.h):
            for x in range(self.w):
                if self.p[y][x] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        v = self.get(x + dx, y + dy)
                        if v not in (0, color):
                            add.append((x, y))
                            break
        for x, y in add:
            self.p[y][x] = color

    def bbox(self):
        xs = [x for y in range(self.h) for x in range(self.w) if self.p[y][x]]
        ys = [y for y in range(self.h) for x in range(self.w) if self.p[y][x]]
        if not xs:
            return None
        return min(xs), min(ys), max(xs), max(ys)

    def capsule(self, x0, y0, x1, y1, r, v, shade=None):
        """Thick line from (x0,y0) to (x1,y1) with radius r. If shade is
        given, pixels on the left/top edge use it."""
        minx, maxx = int(min(x0, x1) - r - 1), int(max(x0, x1) + r + 1)
        miny, maxy = int(min(y0, y1) - r - 1), int(max(y0, y1) + r + 1)
        dx, dy = x1 - x0, y1 - y0
        L2 = dx * dx + dy * dy
        for y in range(miny, maxy + 1):
            for x in range(minx, maxx + 1):
                px, py = x + 0.5, y + 0.5
                t = 0 if L2 == 0 else max(0, min(1, ((px - x0) * dx + (py - y0) * dy) / L2))
                cx, cy = x0 + t * dx, y0 + t * dy
                d = math.hypot(px - cx, py - cy)
                if d <= r:
                    col = v
                    if shade is not None:
                        # perpendicular side
                        nx, ny = px - cx, py - cy
                        if nx + ny * 0.3 < -r * 0.25:
                            col = shade
                    self.set(x, y, col)

    def disc(self, cx, cy, r, v):
        for y in range(int(cy - r - 1), int(cy + r + 2)):
            for x in range(int(cx - r - 1), int(cx + r + 2)):
                if math.hypot(x + 0.5 - cx, y + 0.5 - cy) <= r:
                    self.set(x, y, v)

def chars_of(c):
    """Split canvas into 8x8 character pixel lists, row-major."""
    out = []
    for ty in range(c.h // 8):
        for tx in range(c.w // 8):
            out.append([[c.p[ty * 8 + y][tx * 8 + x] for x in range(8)] for y in range(8)])
    return out

def enc4(ch):
    b = bytearray(32)
    for y in range(8):
        for x in range(8):
            v = ch[y][x]
            bit = 7 - x
            if v & 1: b[y * 2] |= 1 << bit
            if v & 2: b[y * 2 + 1] |= 1 << bit
            if v & 4: b[16 + y * 2] |= 1 << bit
            if v & 8: b[16 + y * 2 + 1] |= 1 << bit
    return bytes(b)

def enc2(ch):
    b = bytearray(16)
    for y in range(8):
        for x in range(8):
            v = ch[y][x]
            assert v < 4
            bit = 7 - x
            if v & 1: b[y * 2] |= 1 << bit
            if v & 2: b[y * 2 + 1] |= 1 << bit
    return bytes(b)

def to_image(c, palette_rgb, scale=1):
    from PIL import Image
    im = Image.new('RGB', (c.w, c.h))
    for y in range(c.h):
        for x in range(c.w):
            v = c.p[y][x]
            im.putpixel((x, y), rgb(palette_rgb[v]) if v else (255, 0, 255))
    if scale != 1:
        im = im.resize((c.w * scale, c.h * scale), Image.NEAREST)
    return im

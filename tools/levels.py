"""Level generator for the 10 missions.

Each map is 128x64 metatiles (2048x1024 px). The underground is an ant-colony
style maze: chambers on several depth layers, joined by winding tunnels,
ladder shafts and elevators. A spanning tree guarantees connectivity; extra
edges create loops (alternate routes) and degree-1 chambers become dead ends.
"""
import random
from collections import deque
from tiles import MT, METATILES, SOLID, DESTRUCT, PLATFORM, LADDER, HAZARD, DOOR, EXIT

W, H = 128, 64
ATTR = [a for (_n, _p, a, _f, _b) in METATILES]

# entity types (keep in sync with src/defs.inc - generated)
ET = dict(GUARD=1, SOLDIER=2, DEFENDER=3, CRAWLER=4, DRONE=5, SECBOT=6, HEAVY=7,
          BOSS=8, COMMANDER=9, CAPTIVE=10, FRIEND=11, GENERATOR=12, TERMINAL=13,
          ELEVATOR=14, PK_HEALTH=16, PK_MG=17, PK_PLASMA=18, PK_EMP=19, PK_RAIL=20,
          PK_GRENADE=21, PK_KEY=22, PK_CHIP=23)
FLYING = {ET['DRONE']}

OBJ = dict(EXIT=0, COLLECT=1, DESTROY=2, BOSS=3, EMP=4, RESCUE=5, TIMED=6, KILL=7, FRIEND=8)

class Node:
    def __init__(self, i, j, x, floor, rx, h):
        self.i, self.j = i, j
        self.x, self.floor, self.rx, self.h = x, floor, rx, h
        self.edges = []
        self.room = False

    def __repr__(self):
        return 'N(%d,%d @%d,%d)' % (self.i, self.j, self.x, self.floor)

class Level:
    def __init__(self, seed):
        self.r = random.Random(seed)
        self.t = [[MT['DIRT']] * W for _ in range(H)]
        self.ents = []
        self.nodes = {}
        self.locked_marks = []   # tunnel cells that should become doors

    # -------------------------------------------------------------- basics
    def get(self, x, y):
        if 0 <= x < W and 0 <= y < H:
            return self.t[y][x]
        return MT['BEDROCK']

    def set(self, x, y, v):
        if 1 <= x < W - 1 and 1 <= y < H - 1:
            self.t[y][x] = v

    def setany(self, x, y, v):
        if 0 <= x < W and 0 <= y < H:
            self.t[y][x] = v

    def solid(self, x, y):
        return ATTR[self.get(x, y)] & SOLID

    def is_air(self, x, y):
        return self.get(x, y) == MT['AIR']

    def fill_earth(self, rock=0.12, crystal=0.0, bedrock_blobs=4, top=0):
        r = self.r
        for y in range(top, H):
            for x in range(W):
                self.t[y][x] = MT['DIRT'] if r.random() < 0.6 else MT['DIRT2']
        # rock blobs
        for _ in range(int(W * H * rock / 30)):
            cx, cy = r.randrange(W), r.randrange(top, H)
            rad = r.uniform(1.5, 3.5)
            for y in range(int(cy - rad), int(cy + rad) + 1):
                for x in range(int(cx - rad), int(cx + rad) + 1):
                    if (x - cx) ** 2 + (y - cy) ** 2 <= rad * rad and y >= top:
                        self.setany(x, y, MT['CRYSTAL'] if r.random() < crystal else MT['ROCK'])
        for _ in range(bedrock_blobs):
            cx, cy = r.randrange(W), r.randrange(top + 4, H)
            rad = r.uniform(2, 4)
            for y in range(int(cy - rad), int(cy + rad) + 1):
                for x in range(int(cx - rad), int(cx + rad) + 1):
                    if (x - cx) ** 2 + (y - cy) ** 2 <= rad * rad and y >= top:
                        self.setany(x, y, MT['BEDROCK'] if (x + y) % 3 else MT['BEDROCK2'])

    def border(self, top=True):
        for x in range(W):
            if top:
                self.setany(x, 0, MT['BEDROCK'])
            self.setany(x, H - 1, MT['BEDROCK'])
            self.setany(x, H - 2, MT['BEDROCK2'])
        for y in range(H):
            if not top and self.t[y][0] == MT['AIR']:
                continue
            for x in (0, 1, W - 2, W - 1):
                if top or y > 18:
                    self.setany(x, y, MT['BEDROCK'] if (y + x) % 2 else MT['BEDROCK2'])

    # -------------------------------------------------------------- graph
    def make_nodes(self, layers, cols=8, x0=8, dx=16, jitter=3):
        r = self.r
        for j, fy in enumerate(layers):
            for i in range(cols):
                x = x0 + i * dx + r.randint(-jitter, jitter)
                x = max(5, min(W - 6, x))
                floor = fy + r.randint(-1, 1)
                rx = r.randint(3, 6)
                h = r.randint(4, 6)
                self.nodes[(i, j)] = Node(i, j, x, floor, rx, h)
        self.cols, self.layers = cols, len(layers)

    def spanning_tree(self, start=(0, 0), loops=0.2, vert_bias=0.5):
        r = self.r
        seen = {start}
        stack = [start]
        edges = set()
        while stack:
            cur = stack[-1]
            i, j = cur
            nb = [(i + di, j + dj) for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1))
                  if (i + di, j + dj) in self.nodes and (i + di, j + dj) not in seen]
            if not nb:
                stack.pop()
                continue
            # weight vertical moves
            ws = [vert_bias if n[1] != j else 1.0 for n in nb]
            n = r.choices(nb, ws)[0]
            seen.add(n)
            edges.add(tuple(sorted((cur, n))))
            stack.append(n)
        # extra loop edges
        for (i, j) in list(self.nodes):
            for (di, dj) in ((1, 0), (0, 1)):
                n = (i + di, j + dj)
                if n in self.nodes and tuple(sorted(((i, j), n))) not in edges and r.random() < loops:
                    edges.add(tuple(sorted(((i, j), n))))
        self.edges = sorted(edges)
        for a, b in self.edges:
            self.nodes[a].edges.append(b)
            self.nodes[b].edges.append(a)

    # -------------------------------------------------------------- carving
    def carve_chamber(self, n):
        for dy in range(1, n.h + 1):
            y = n.floor - dy
            frac = (dy - 1) / n.h
            half = n.rx * (1 - frac ** 2.2) ** 0.5
            for x in range(int(round(n.x - half)), int(round(n.x + half)) + 1):
                self.set(x, y, MT['AIR'])
        # flat floor guaranteed
        for x in range(n.x - n.rx, n.x + n.rx + 1):
            if not self.solid(x, n.floor) and not (ATTR[self.get(x, n.floor)] & (PLATFORM | LADDER)):
                self.set(x, n.floor, MT['DIRT'])

    def carve_room(self, n, w=None, h=None, door=None):
        """Rectangular facility room with metal shell."""
        n.room = True
        w = w or n.rx
        h = h or max(4, n.h)
        n.rx, n.h = w, h
        x0, x1 = n.x - w, n.x + w
        y0, y1 = n.floor - h, n.floor
        for y in range(y0 - 1, y1 + 1):
            for x in range(x0 - 1, x1 + 2):
                edge = y == y0 - 1 or x == x0 - 1 or x == x1 + 1
                if y == y1:
                    self.set(x, y, MT['METAL_FLOOR'])
                elif edge:
                    self.set(x, y, MT['METAL_WALL'])
                else:
                    self.set(x, y, MT['AIR'])
        # decor along the back wall
        r = self.r
        for x in range(x0 + 1, x1, 3):
            k = r.random()
            y = n.floor - 3
            if k < 0.25:
                self.set(x, y, MT['SCREEN'])
            elif k < 0.4:
                self.set(x, y, MT['VENT'])
            elif k < 0.5:
                self.set(x, n.floor - h, MT['LAMP'])

    def carve_tunnel(self, a, b, height=3, door=None, collapsed=False):
        """Horizontal tunnel from node a to node b (a left of b)."""
        if a.x > b.x:
            a, b = b, a
        r = self.r
        x0 = a.x
        x1 = b.x
        y = a.floor
        target = b.floor
        cells = []
        x = x0
        last_step = 0
        while x <= x1:
            # step floor toward the target height, at most every 3 tiles
            remaining = x1 - x
            need = target - y
            if need and (abs(need) >= remaining // 3 or r.random() < 0.25) and x - last_step >= 3:
                y += 1 if need > 0 else -1
                last_step = x
            elif not need and r.random() < 0.06 and x - last_step >= 4 and remaining > 8:
                y += r.choice((-1, 1))
                last_step = x
            cells.append((x, y))
            x += 1
        for (x, fy) in cells:
            for k in range(1, height + 1):
                cur = self.get(x, fy - k)
                if collapsed:
                    if cur == MT['AIR']:
                        continue
                    self.set(x, fy - k, MT['ROCK'] if r.random() < 0.3 else MT['DIRT'])
                else:
                    self.set(x, fy - k, MT['AIR'])
            # ensure floor
            f = self.get(x, fy)
            if not (ATTR[f] & (SOLID | PLATFORM)):
                self.set(x, fy, MT['DIRT'])
        # wall crossings for doors: first metal wall cells on each side
        if door:
            self.locked_marks.append((cells, door))
        return cells

    def carve_shaft(self, top, bot, kind='ladder'):
        """Vertical connection from node `top` (upper) down to node `bot`."""
        r = self.r
        lo = max(top.x - top.rx + 1, bot.x - bot.rx + 1)
        hi = min(top.x + top.rx - 1, bot.x + bot.rx - 1)
        if lo > hi:
            x = (top.x + bot.x) // 2
        else:
            x = r.randint(lo, hi)
        width = 1 if kind == 'ladder' else 2
        for xx in range(x, x + width):
            for y in range(top.floor - 2, bot.floor):
                self.set(xx, y, MT['AIR'])
        if kind == 'ladder':
            self.set(x, top.floor, MT['LADDER_TOP'])
            for y in range(top.floor + 1, bot.floor):
                self.set(x, y, MT['LADDER'])
            # the ladder starts at the top floor; above it is air
        elif kind == 'drop':
            self.set(x, top.floor, MT['LADDER_TOP'])
            for y in range(top.floor + 1, bot.floor):
                self.set(x, y, MT['LADDER'])
            self.set(x + 1, top.floor, MT['AIR'])
        elif kind == 'elevator':
            self.set(x, top.floor, MT['AIR'])
            self.set(x + 1, top.floor, MT['AIR'])
            for y in range(top.floor, bot.floor):
                self.set(x - 1, y, MT['BEAM_V'] if self.get(x - 1, y) == MT['AIR'] else self.get(x - 1, y))
            travel = bot.floor - top.floor
            # elevator starts at the bottom; param = travel in tiles
            self.ents.append((ET['ELEVATOR'], travel, (x + 1) * 16, bot.floor * 16))
        # connect the bottom of the shaft to the lower chamber if needed
        if not (bot.x - bot.rx <= x <= bot.x + bot.rx):
            step = 1 if bot.x > x else -1
            xx = x
            while xx != bot.x:
                for k in range(1, 4):
                    self.set(xx, bot.floor - k, MT['AIR'])
                xx += step
        # and the top to the upper chamber floor
        if not (top.x - top.rx <= x <= top.x + top.rx):
            step = 1 if top.x > x else -1
            xx = x
            while xx != top.x:
                for k in range(1, 4):
                    self.set(xx, top.floor - k, MT['AIR'])
                xx += step
        return x

    def place_doors(self):
        """Put door columns where tunnels cross metal room walls."""
        for cells, door in self.locked_marks:
            for (x, fy) in cells:
                pass
        # done during carving instead (see apply_door)

    def door_column(self, x, fy, kind):
        for k in range(1, 4):
            self.set(x, fy - k, MT[kind])
        if not self.solid(x, fy):
            self.set(x, fy, MT['METAL_FLOOR'])
        # solid lintel so the player can't hop over
        if not self.solid(x, fy - 4):
            self.set(x, fy - 4, MT['METAL_WALL'])

    # -------------------------------------------------------------- decor
    def decorate(self, beams=True, lamps=True, pipes=0.0):
        r = self.r
        g = self.t
        for y in range(1, H - 1):
            for x in range(W):
                if g[y][x] in (MT['DIRT'], MT['DIRT2']) and g[y - 1][x] == MT['AIR']:
                    g[y][x] = MT['DIRT_TOP']
        if beams:
            for y in range(2, H - 2):
                for x in range(2, W - 2):
                    # 3-tall gap with solid floor and ceiling -> occasional beams
                    if (g[y][x] == MT['AIR'] and g[y - 1][x] == MT['AIR'] and g[y - 2][x] == MT['AIR']
                            and ATTR[g[y + 1][x]] & SOLID and ATTR[g[y - 3][x]] & SOLID
                            and not ATTR[g[y + 1][x]] & LADDER and r.random() < 0.06):
                        for k in range(3):
                            g[y - k][x] = MT['BEAM_V']
                        if lamps and r.random() < 0.5 and g[y - 2][x + 1] == MT['AIR']:
                            g[y - 2][x + 1] = MT['LAMP']
        if pipes:
            for y in range(2, H - 2):
                for x in range(2, W - 2):
                    if g[y][x] == MT['AIR'] and ATTR[g[y - 1][x]] & SOLID and r.random() < pipes:
                        run = 0
                        while g[y][x + run] == MT['AIR'] and ATTR[g[y - 1][x + run]] & SOLID and run < 8:
                            g[y][x + run] = MT['PIPE_H']
                            run += 1

    # -------------------------------------------------------------- entities
    def add(self, kind, tx, ty, param=0):
        """Entity standing on the floor tile row ty+1 (feet at bottom of tile ty)."""
        self.ents.append((ET[kind], param, tx * 16 + 8, (ty + 1) * 16))

    def node_spot(self, n, off=0):
        x = n.x + off
        x = max(n.x - n.rx + 1, min(n.x + n.rx - 1, x))
        # find air above a supporting floor near the chamber floor
        for y in range(n.floor - 1, n.floor - n.h - 1, -1):
            if not self.solid(x, y) and not self.solid(x, y - 1) and (
                    ATTR[self.get(x, y + 1)] & (SOLID | PLATFORM)):
                return x, y
        return n.x, n.floor - 1

def standable(L, x, y):
    a0 = ATTR[L.get(x, y)]
    a1 = ATTR[L.get(x, y - 1)]
    if a0 & SOLID or a1 & SOLID:
        return False
    below = ATTR[L.get(x, y + 1)]
    return bool(below & (SOLID | PLATFORM) or a0 & LADDER or below & LADDER)

def passable(L, x, y, dig=False, doors=True):
    a = ATTR[L.get(x, y)]
    if a & SOLID:
        if doors and a & DOOR:
            return True
        if dig and a & DESTRUCT:
            return True
        return False
    return True

def reach(L, start, dig=False, elev_cols=()):
    """Approximate player reachability (tile positions of the feet tile)."""
    seen = set()
    q = deque([start])
    seen.add(start)
    def free(x, y):
        return passable(L, x, y, dig) and passable(L, x, y - 1, dig)
    def support(x, y):
        b = ATTR[L.get(x, y + 1)]
        a = ATTR[L.get(x, y)]
        if dig:
            pass
        return bool((b & (SOLID | PLATFORM) and not (b & DOOR)) or a & LADDER or b & LADDER) or x in elev_cols
    def land(x, y):
        # fall until supported
        while y < H - 2 and free(x, y + 1) and not support(x, y):
            y += 1
        return (x, y)
    while q:
        x, y = q.popleft()
        nxt = []
        for dx in (-1, 1):
            if free(x + dx, y):
                nxt.append(land(x + dx, y))
        # ladders / elevators
        a = ATTR[L.get(x, y)]
        b = ATTR[L.get(x, y + 1)]
        if (a & LADDER or x in elev_cols) and free(x, y - 1):
            nxt.append((x, y - 1))
        if (b & LADDER or x in elev_cols) and y + 1 < H - 1 and passable(L, x, y + 1, dig, True):
            nxt.append((x, y + 1))
        # jumps: up to 3 tiles high, up to 3 across
        if support(x, y):
            for dy in range(1, 4):
                if not free(x, y - dy):
                    break
                for dx in (-1, 1):
                    for k in range(1, 4):
                        xx = x + dx * k
                        if not free(xx, y - dy):
                            break
                        nxt.append(land(xx, y - dy))
            # running jump across gaps at same height
            for dx in (-1, 1):
                for k in range(1, 5):
                    xx = x + dx * k
                    if not free(xx, y - 1):
                        break
                    if support(xx, y) and free(xx, y):
                        nxt.append((xx, y))
        for p in nxt:
            if p not in seen and 0 < p[0] < W - 1 and 0 < p[1] < H - 1:
                seen.add(p)
                q.append(p)
    return seen

# ===================================================================== missions
def tree_dist(L, start):
    dist = {start: 0}
    q = deque([start])
    while q:
        c = q.popleft()
        for n in L.nodes[c].edges:
            if n not in dist:
                dist[n] = dist[c] + 1
                q.append(n)
    return dist

def standard_underground(L, layers, start=(0, 0), loops=0.2, rooms=(), room_doors=None,
                         elevator_rate=0.15, drop_rate=0.2, cols=8, collapsed_layer=None, skip=()):
    L.make_nodes(layers, cols=cols)
    for k in skip:
        del L.nodes[k]
    L.spanning_tree(start=start, loops=loops)
    r = L.r
    for key, n in L.nodes.items():
        if key in rooms:
            L.carve_room(n, w=r.randint(4, 6), h=4)
        else:
            L.carve_chamber(n)
    # horizontal tunnels first, so shafts cut cleanly through their floors
    for a, b in L.edges:
        if a[1] == b[1]:
            L.carve_tunnel(L.nodes[a], L.nodes[b])
    for a, b in L.edges:
        if a[1] == b[1]:
            continue
        na, nb = L.nodes[a], L.nodes[b]
        top, bot = (na, nb) if na.floor < nb.floor else (nb, na)
        k = r.random()
        if collapsed_layer is not None and min(a[1], b[1]) == collapsed_layer:
            # this layer boundary is caved in: rubble fills the shaft
            x = L.carve_shaft(top, bot, 'ladder')
            for y in range(top.floor + 1, bot.floor - 3):
                L.set(x, y, MT['ROCK'] if (y % 3) else MT['DIRT'])
            continue
        kind = 'elevator' if k < elevator_rate else ('drop' if k < elevator_rate + drop_rate else 'ladder')
        L.carve_shaft(top, bot, kind)
    # re-carve rooms' interiors over shafts/tunnels that hit walls: add door frames
    for key in rooms:
        n = L.nodes[key]
        x0, x1 = n.x - n.rx - 1, n.x + n.rx + 1
        for x in (x0, x1):
            for y in range(n.floor - n.h - 1, n.floor):
                pass

def finalize_doors(L, rooms, kind, sides=(-1, 1)):
    """Hang a door wherever a tunnel opens into a room's side wall."""
    n_doors = 0
    for key in rooms:
        n = L.nodes[key]
        for side in sides:
            x = n.x - n.rx - 1 if side < 0 else n.x + n.rx + 1
            # find the opening: a run of 3 non-solid tiles above a solid floor
            for fy in range(n.floor - n.h, n.floor + 3):
                if (L.solid(x, fy) and all(not L.solid(x, fy - k) for k in (1, 2, 3))
                        and not any(ATTR[L.get(x, fy - k)] & LADDER for k in (1, 2, 3))):
                    L.door_column(x, fy, kind)
                    n_doors += 1
                    break
    return n_doors

def place_enemies(L, roster, count, avoid, min_dist=14, flying_ok=True, extra_nodes=None):
    r = L.r
    keys = list(L.nodes.keys())
    placed = 0
    tries = 0
    while placed < count and tries < count * 40:
        tries += 1
        kind = r.choices(list(roster.keys()), list(roster.values()))[0]
        n = L.nodes[r.choice(keys)]
        if abs(n.x - avoid[0]) + abs(n.floor - avoid[1]) < min_dist:
            continue
        x, y = L.node_spot(n, r.randint(-n.rx + 1, n.rx - 1))
        if not standable(L, x, y):
            continue
        if ET[kind] in FLYING:
            y -= 2
            if L.solid(x, y) or L.solid(x, y - 1):
                y += 2
        if any(abs(e[2] - (x * 16 + 8)) < 24 and abs(e[3] - (y + 1) * 16) < 24 for e in L.ents):
            continue
        L.add(kind, x, y, r.randint(0, 255))
        placed += 1

def place_pickups(L, kinds, avoid=None):
    """Dead-end chambers get pickups first, then random chambers."""
    r = L.r
    dead = [k for k, n in L.nodes.items() if len(n.edges) == 1]
    others = [k for k in L.nodes if k not in dead]
    r.shuffle(dead)
    r.shuffle(others)
    pool = [k for k in dead + others if k != (0, 0)]
    used = 0
    for kind in kinds:
        n = L.nodes[pool[used % len(pool)]]
        used += 1
        x, y = L.node_spot(n, r.randint(-2, 2))
        L.add(kind, x, y)

def exit_at(L, n, locked, others=()):
    """Exit lift: a 2-wide pit sunk into a chamber floor, lined with hazard
    stripes. When locked, an exit door seals the top of the pit."""
    rest = [L.nodes[k] for k in others if k in L.nodes]
    rest += sorted(L.nodes.values(), key=lambda m: -(m.floor * 4 + m.x // 8))
    for node in [n] + rest:
        fy = node.floor
        xs = list(range(node.x + node.rx - 2, node.x - node.rx, -1))
        for x in xs:
            box_ok = all(L.solid(xx, y) and not (ATTR[L.get(xx, y)] & (LADDER | DOOR))
                         for xx in range(x - 1, x + 3) for y in range(fy, fy + 5))
            above_ok = all(not L.solid(xx, fy - 1) and not L.solid(xx, fy - 2) for xx in (x, x + 1))
            if not (box_ok and above_ok):
                continue
            for y in range(fy, fy + 4):
                L.set(x - 1, y, MT['METAL_WALL'])
                L.set(x + 2, y, MT['METAL_WALL'])
            L.set(x - 1, fy, MT['HAZARD'])
            L.set(x + 2, fy, MT['HAZARD'])
            for xx in (x, x + 1):
                L.set(xx, fy, MT['DOOR_EXIT'] if locked else MT['AIR'])
                L.set(xx, fy + 1, MT['EXIT'])
                L.set(xx, fy + 2, MT['EXIT'])
                L.set(xx, fy + 3, MT['METAL_FLOOR'])
            return x, fy + 2
    raise RuntimeError('no room for exit')

# ----------------------------------------------------------------- surface
def build_surface(L, ground=16):
    """City block across the top of the map; street at row `ground`."""
    r = L.r
    for y in range(0, ground):
        for x in range(W):
            L.setany(x, y, MT['AIR'])
    for x in range(W):
        L.setany(x, ground, MT['STREET'] if x % 9 else MT['SIDEWALK'])
        L.setany(x, ground + 1, MT['CONCRETE'])
        L.setany(x, ground + 2, MT['CONCRETE'])
    # buildings: facades (non-solid) with roofs (one-way platforms)
    x = 6
    specs = []
    while x < W - 10:
        w = r.randint(5, 9)
        h = r.randint(4, 10)
        specs.append((x, w, h))
        x += w + r.randint(2, 5)
    for (x0, w, h) in specs:
        top = ground - h
        for y in range(top, ground):
            for x in range(x0, x0 + w):
                k = r.random()
                L.setany(x, y, MT['BLDG_WIN'] if k < 0.45 else (MT['BLDG_DARK'] if k < 0.8 else MT['BLDG_WALL']))
        for x in range(x0, x0 + w):
            L.setany(x, top, MT['ROOF'])
        # mid floors as platforms every 4 rows -> climbable interior
        for y in range(top + 4, ground - 1, 4):
            for x in range(x0 + 1, x0 + w - 1):
                L.setany(x, y, MT['GRATE'])
        # entrance door + neon sign
        dx = x0 + w // 2
        L.setany(dx, ground - 1, MT['BLDG_DOOR'])
        if h >= 5 and r.random() < 0.7:
            L.setany(x0 + r.randrange(w), ground - 3, MT['NEON_A'] if r.random() < 0.5 else MT['NEON_B'])
        # ladder up the side for access to the roof
        lx = x0 + (0 if r.random() < 0.5 else w - 1)
        for y in range(top, ground):
            L.setany(lx, y, MT['LADDER'])
        L.setany(lx, top, MT['LADDER_TOP'])
    # street lights
    for x in range(3, W - 3, 11):
        if L.get(x, ground - 1) == MT['AIR'] and L.get(x, ground - 2) == MT['AIR']:
            L.setany(x, ground - 1, MT['POLE'])
            L.setany(x, ground - 2, MT['POLE'])
            L.setany(x, ground - 3, MT['STREETLIGHT'])
    return specs

def surface_entrance(L, x, ground, bottom_node):
    """Maintenance shaft from the street down into the first chamber."""
    L.setany(x - 1, ground - 3, MT['SIGN_DOWN'])
    L.setany(x, ground, MT['LADDER_TOP'])
    for y in range(ground + 1, bottom_node.floor):
        L.set(x, y, MT['LADDER'])
        L.set(x + 1, y, MT['SHAFT_WALL'] if y < ground + 4 else MT['AIR'])
        L.set(x - 1, y, MT['SHAFT_WALL'] if y < ground + 4 else L.get(x - 1, y))
    # connect bottom of shaft to node
    step = 1 if bottom_node.x > x else -1
    xx = x
    while xx != bottom_node.x:
        for k in range(1, 4):
            L.set(xx, bottom_node.floor - k, MT['AIR'])
        xx += step

# ================================================================ mission defs
MISSIONS = []

def mission(fn):
    MISSIONS.append(fn)
    return fn

def common_pickups(L, mg=3, plasma=2, emp=1, rail=1, nade=2, health=3):
    place_pickups(L, ['PK_HEALTH'] * health + ['PK_MG'] * mg + ['PK_PLASMA'] * plasma +
                  ['PK_EMP'] * emp + ['PK_RAIL'] * rail + ['PK_GRENADE'] * nade)

@mission
def m1(L):
    """STREET LEVEL: the city surface, then down into the first tunnels."""
    ground = 16
    L.fill_earth(rock=0.08, bedrock_blobs=2, top=ground + 3)
    build_surface(L, ground)
    L.border(top=False)
    # underground: 3 layers, 6 columns, on the right side mostly
    standard_underground(L, layers=[30, 42, 55], start=(0, 0), loops=0.25, cols=8, elevator_rate=0.1)
    # shaft from street near x=40 into node (2,0)
    target = L.nodes[(2, 0)]
    sx = target.x
    surface_entrance(L, sx, ground, target)
    # clear any building facade over the shaft top
    for y in range(ground - 2, ground):
        if L.get(sx, y) != MT['AIR'] and L.get(sx, y) != MT['SIGN_DOWN']:
            L.setany(sx, y, MT['AIR'])
    L.decorate()
    start = (3, ground - 1)
    goal = L.nodes[(7, 2)]
    ex = exit_at(L, goal, locked=False, others=[(6, 2), (7, 1), (5, 2)])
    L.add('GUARD', 20, ground - 1); L.add('GUARD', 34, ground - 1)
    L.add('DRONE', 60, ground - 5); L.add('GUARD', 75, ground - 1)
    L.add('SOLDIER', 90, ground - 1); L.add('DRONE', 105, ground - 6); L.add('GUARD', 118, ground - 1)
    place_enemies(L, {'GUARD': 3, 'CRAWLER': 3, 'SOLDIER': 1}, 12, (sx, 30))
    common_pickups(L, mg=3, plasma=2, emp=1, rail=1, nade=3, health=3)
    return dict(start=start, exit=ex, obj='EXIT', count=0, surface=ground)

@mission
def m2(L):
    """THE NEST: collect 3 data chips, then the exit door unlocks."""
    L.fill_earth(rock=0.12, bedrock_blobs=4)
    L.border()
    standard_underground(L, layers=[8, 20, 32, 44, 57], start=(0, 0), loops=0.2)
    L.decorate()
    dist = tree_dist(L, (0, 0))
    far = sorted(dist, key=lambda k: -dist[k])
    goal = L.nodes[far[0]]
    ex = exit_at(L, goal, locked=True, others=far[1:6])
    chips = [k for k in far[1:] if len(L.nodes[k].edges) == 1 and k != (0, 0)][:3]
    extra = [k for k in far[1:] if k not in chips and k != (0, 0)]
    while len(chips) < 3:
        chips.append(extra.pop(0))
    for k in chips:
        x, y = L.node_spot(L.nodes[k])
        L.add('PK_CHIP', x, y)
    n0 = L.nodes[(0, 0)]
    start = L.node_spot(n0, -1)
    place_enemies(L, {'GUARD': 3, 'CRAWLER': 4, 'SOLDIER': 2, 'DRONE': 1}, 22, start)
    common_pickups(L)
    return dict(start=start, exit=ex, obj='COLLECT', count=3)

@mission
def m3(L):
    """DEEP DIG: the tunnels collapsed; blast through with grenades."""
    L.fill_earth(rock=0.2, bedrock_blobs=3)
    L.border()
    standard_underground(L, layers=[8, 20, 34, 46, 57], start=(0, 0), loops=0.25, collapsed_layer=1)
    # thick rubble band between layer 1 and 2
    r = L.r
    for y in range(24, 28):
        for x in range(2, W - 2):
            if L.get(x, y) == MT['AIR'] or L.get(x, y) == MT['LADDER']:
                L.set(x, y, MT['ROCK'] if r.random() < 0.35 else MT['DIRT'])
    L.decorate()
    n0 = L.nodes[(0, 0)]
    start = L.node_spot(n0, -1)
    goal = L.nodes[(7, 4)]
    ex = exit_at(L, goal, locked=False, others=[(6, 4), (7, 3), (5, 4)])
    place_enemies(L, {'GUARD': 2, 'CRAWLER': 5, 'SOLDIER': 2, 'DRONE': 2}, 22, start)
    # plenty of grenades above the rubble
    for k in [(1, 0), (3, 0), (5, 1), (6, 0), (2, 1)]:
        x, y = L.node_spot(L.nodes[k], 1)
        L.add('PK_GRENADE', x, y)
    common_pickups(L, nade=2)
    return dict(start=start, exit=ex, obj='EXIT', count=0, dig=True)

@mission
def m4(L):
    """POWER GRID: destroy 4 generators feeding the security grid."""
    L.fill_earth(rock=0.15, bedrock_blobs=5)
    L.border()
    rooms = [(2, 1), (6, 1), (1, 3), (5, 3)]
    standard_underground(L, layers=[8, 20, 32, 44, 57], start=(0, 0), loops=0.25, rooms=rooms)
    L.decorate(pipes=0.03)
    for k in rooms:
        n = L.nodes[k]
        L.add('GENERATOR', n.x, n.floor - 1)
    dist = tree_dist(L, (0, 0))
    far = sorted([k for k in dist if k not in rooms], key=lambda k: -dist[k])
    ex = exit_at(L, L.nodes[far[0]], locked=True, others=far[1:6])
    n0 = L.nodes[(0, 0)]
    start = L.node_spot(n0, -1)
    place_enemies(L, {'GUARD': 2, 'SECBOT': 3, 'CRAWLER': 3, 'SOLDIER': 2, 'DRONE': 2}, 24, start)
    common_pickups(L, plasma=4, nade=3)
    return dict(start=start, exit=ex, obj='DESTROY', count=4)

@mission
def m5(L):
    """THE SENTINEL: a heavy armored robot guards the descent."""
    L.fill_earth(rock=0.18, bedrock_blobs=4)
    L.border()
    standard_underground(L, layers=[8, 20, 32, 44], start=(0, 0), loops=0.2)
    # boss arena across the bottom
    r = L.r
    for y in range(52, 61):
        for x in range(30, 110):
            L.set(x, y, MT['AIR'])
    for x in range(28, 112):
        L.set(x, 61, MT['METAL_FLOOR'])
        L.set(x, 51, MT['METAL_WALL'])
    for y in range(51, 62):
        L.set(29, y, MT['METAL_WALL'])
        L.set(110, y, MT['METAL_WALL'])
    for x in (45, 70, 95):
        for k in range(3):
            L.set(x + k, 57, MT['PLATFORM'])
    # entrance shaft from the bottom layer node nearest the middle
    entry = L.nodes[(4, 3)]
    top = entry
    x = entry.x
    L.set(x, entry.floor, MT['LADDER_TOP'])
    for y in range(entry.floor + 1, 61):
        L.set(x, y, MT['LADDER'])
    L.decorate()
    L.add('BOSS', 95, 60)
    n0 = L.nodes[(0, 0)]
    start = L.node_spot(n0, -1)
    place_enemies(L, {'GUARD': 2, 'CRAWLER': 3, 'SOLDIER': 3, 'SECBOT': 2, 'DRONE': 2}, 18, start)
    common_pickups(L, plasma=4, rail=2, nade=3, health=4)
    for xx in (35, 104):
        L.add('PK_HEALTH', xx, 60)
    L.add('PK_PLASMA', 60, 60)
    return dict(start=start, exit=None, obj='BOSS', count=1)

@mission
def m6(L):
    """BLACKOUT: EMP four security terminals to open the blast doors."""
    L.fill_earth(rock=0.12, bedrock_blobs=4)
    L.border()
    rooms = [(1, 0), (5, 1), (2, 2), (6, 3), (3, 4)]
    standard_underground(L, layers=[8, 20, 32, 44, 57], start=(0, 0), loops=0.3, rooms=rooms)
    L.decorate(pipes=0.03)
    r = L.r
    terms = rooms[:4]
    finalize_doors(L, terms, 'DOOR_EMP', sides=(-1,))
    for k in terms:
        n = L.nodes[k]
        L.add('TERMINAL', n.x + 1, n.floor - 1)
    # laser gates across some tunnels
    laser_spots = 0
    for (a, b) in L.edges:
        if a[1] == b[1] and r.random() < 0.35:
            na, nb = L.nodes[a], L.nodes[b]
            x = (na.x + nb.x) // 2
            for y in range(1, H - 1):
                if L.is_air(x, y) and L.solid(x, y - 1) and not L.solid(x, y + 2) and L.is_air(x, y + 1):
                    # find floor
                    fy = y
                    while fy < H - 1 and not L.solid(x, fy):
                        fy += 1
                    if fy - y <= 4 and L.solid(x, y - 1):
                        L.set(x, y - 1, MT['EMITTER'])
                        for yy in range(y, fy):
                            L.set(x, yy, MT['LASER'])
                        laser_spots += 1
                        break
    dist = tree_dist(L, (0, 0))
    far = sorted([k for k in dist if k not in rooms], key=lambda k: -dist[k])
    ex = exit_at(L, L.nodes[far[0]], locked=True, others=far[1:6])
    n0 = L.nodes[(0, 0)]
    start = L.node_spot(n0, -1)
    place_enemies(L, {'SECBOT': 4, 'DRONE': 3, 'CRAWLER': 2, 'SOLDIER': 2, 'HEAVY': 1}, 24, start)
    common_pickups(L, emp=8, plasma=3)
    return dict(start=start, exit=ex, obj='EMP', count=4)

@mission
def m7(L):
    """PRISONERS: free three captured miners held in the tunnels."""
    L.fill_earth(rock=0.14, crystal=0.25, bedrock_blobs=5)
    L.border()
    standard_underground(L, layers=[8, 20, 32, 44, 57], start=(0, 0), loops=0.2)
    L.decorate()
    dist = tree_dist(L, (0, 0))
    far = sorted(dist, key=lambda k: -dist[k])
    picks = [far[1], far[len(far) // 3], far[len(far) // 2]]
    for k in picks:
        n = L.nodes[k]
        x, y = L.node_spot(n, 1)
        L.add('CAPTIVE', x, y)
        # guards next to each captive
        gx, gy = L.node_spot(n, -2)
        if standable(L, gx, gy) and abs(gx - x) > 1:
            L.add('SOLDIER', gx, gy)
    ex = exit_at(L, L.nodes[far[0]], locked=True, others=far[3:9])
    n0 = L.nodes[(0, 0)]
    start = L.node_spot(n0, -1)
    place_enemies(L, {'GUARD': 3, 'SOLDIER': 3, 'CRAWLER': 2, 'DRONE': 2, 'SECBOT': 1}, 22, start)
    common_pickups(L, health=4)
    return dict(start=start, exit=ex, obj='RESCUE', count=3)

@mission
def m8(L):
    """COLLAPSE: the tunnels are caving in - reach the lift before time runs out."""
    L.fill_earth(rock=0.2, bedrock_blobs=6)
    L.border()
    standard_underground(L, layers=[8, 20, 32, 44, 57], start=(0, 0), loops=0.35, elevator_rate=0.25)
    L.decorate()
    n0 = L.nodes[(0, 0)]
    start = L.node_spot(n0, -1)
    ex = exit_at(L, L.nodes[(7, 4)], locked=False, others=[(6, 4), (7, 3), (5, 4)])
    place_enemies(L, {'CRAWLER': 4, 'DRONE': 3, 'SOLDIER': 2}, 16, start)
    common_pickups(L, health=3, nade=3)
    return dict(start=start, exit=ex, obj='TIMED', count=0, timer=210)

@mission
def m9(L):
    """COMMAND POST: take down the enemy commander."""
    L.fill_earth(rock=0.15, bedrock_blobs=5)
    L.border()
    rooms = [(3, 2), (4, 2), (6, 4), (1, 3)]
    standard_underground(L, layers=[8, 20, 32, 44, 57], start=(0, 0), loops=0.3, rooms=rooms)
    L.decorate(pipes=0.04)
    post = L.nodes[(6, 4)]
    L.add('COMMANDER', post.x + 2, post.floor - 1)
    L.add('DEFENDER', post.x - 2, post.floor - 1)
    L.add('DEFENDER', post.x - 4, post.floor - 1)
    for k in rooms[:2]:
        n = L.nodes[k]
        L.add('DEFENDER', n.x, n.floor - 1)
    n0 = L.nodes[(0, 0)]
    start = L.node_spot(n0, -1)
    place_enemies(L, {'SOLDIER': 5, 'GUARD': 2, 'SECBOT': 2, 'DRONE': 2, 'DEFENDER': 2, 'HEAVY': 1}, 26, start)
    common_pickups(L, health=4, rail=2)
    return dict(start=start, exit=None, obj='KILL', count=1)

@mission
def m10(L):
    """THE FACILITY: find the keycard and rescue your friend."""
    L.fill_earth(rock=0.1, bedrock_blobs=3)
    L.border()
    rooms = [(0, 1), (3, 1), (6, 1), (2, 2), (5, 2), (1, 3), (4, 3), (7, 3)]
    standard_underground(L, layers=[8, 20, 32, 44, 57], start=(0, 0), loops=0.3, rooms=rooms, elevator_rate=0.2,
                         skip=[(7, 4)])
    L.decorate(pipes=0.05)
    r = L.r
    # facility walls: replace remaining dirt with brick/metal for a built look
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            if L.t[y][x] in (MT['DIRT'], MT['DIRT2'], MT['DIRT_TOP']):
                L.t[y][x] = MT['BRICK'] if (x // 3 + y // 2) % 4 else MT['CONCRETE']
    finalize_doors(L, [(3, 1), (5, 2), (7, 3)], 'DOOR_EMP', sides=(1,))
    # the cell: a locked metal block at the bottom right, reached from node (6,4)
    n64 = L.nodes[(6, 4)]
    fy = n64.floor
    for y in range(fy - 6, fy + 1):
        for x in range(112, 126):
            L.set(x, y, MT['METAL_WALL'])
    for y in range(fy - 4, fy):
        for x in range(114, 125):
            L.set(x, y, MT['AIR'])
    for x in range(112, 126):
        L.set(x, fy, MT['METAL_FLOOR'])
    for x in range(n64.x, 113):
        for k in range(1, 4):
            L.set(x, fy - k, MT['AIR'])
        if not L.solid(x, fy):
            L.set(x, fy, MT['METAL_FLOOR'])
    L.door_column(113, fy, 'DOOR_KEY')
    for x in range(116, 124, 2):
        L.set(x, fy - 4, MT['LAMP'] if x % 4 else MT['SCREEN'])
    L.add('FRIEND', 121, fy - 1)
    # keycard far from the cell
    dist = tree_dist(L, (0, 0))
    cand = [k for k in dist if k[1] >= 2 and abs(k[0] - 6) >= 3]
    kk = max(cand, key=lambda k: dist[k])
    x, y = L.node_spot(L.nodes[kk])
    L.add('PK_KEY', x, y)
    n0 = L.nodes[(0, 0)]
    start = L.node_spot(n0, -1)
    place_enemies(L, {'SECBOT': 4, 'SOLDIER': 4, 'DEFENDER': 2, 'DRONE': 3, 'HEAVY': 2, 'GUARD': 2}, 30, start)
    common_pickups(L, health=5, plasma=3, emp=5, rail=2, nade=3)
    return dict(start=start, exit=None, obj='FRIEND', count=1)

MISSION_INFO = [
    # name, earth palette, backdrop palette, base depth (m)
    ('STREET LEVEL', 'surface', 'city', 0),
    ('THE NEST', 'surface', 'cave', 40),
    ('DEEP DIG', 'clay', 'cave', 120),
    ('POWER GRID', 'granite', 'cool', 210),
    ('THE SENTINEL', 'magma', 'hot', 300),
    ('BLACKOUT', 'ice', 'cool', 380),
    ('PRISONERS', 'amethyst', 'purple', 460),
    ('COLLAPSE', 'moss', 'green', 540),
    ('COMMAND POST', 'coal', 'cave', 620),
    ('THE FACILITY', 'facility', 'facility', 700),
]

def generate(idx, seed=None):
    L = Level(seed if seed is not None else 1234 + idx * 77)
    info = MISSIONS[idx](L)
    return L, info

def validate(L, info):
    """Every objective entity and the exit must be reachable from the start."""
    elev_cols = set()
    for e in L.ents:
        if e[0] == ET['ELEVATOR']:
            ex = e[2] // 16
            elev_cols.update({ex - 1, ex})
    seen = reach(L, tuple(info['start']), dig=info.get('dig', False), elev_cols=elev_cols)
    problems = []
    targets = []
    if info.get('exit'):
        targets.append(('exit', info['exit']))
    for e in L.ents:
        if e[0] in (ET['PK_CHIP'], ET['GENERATOR'], ET['TERMINAL'], ET['CAPTIVE'], ET['FRIEND'],
                    ET['BOSS'], ET['COMMANDER'], ET['PK_KEY']):
            targets.append(('ent%d' % e[0], (e[2] // 16, e[3] // 16 - 1)))
    for name, (x, y) in targets:
        ok = any((x + dx, y + dy) in seen for dx in (-2, -1, 0, 1, 2) for dy in (-1, 0, 1))
        if not ok:
            problems.append((name, x, y))
    return problems, len(seen)

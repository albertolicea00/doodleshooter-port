#!/usr/bin/env python3
"""Generate the port's own maps (not part of the original game) in the same
JSON layout the reference extractor writes for District and Mexico.

Every collider is an axis-aligned box. Walls, floors and stairs are drawn as
those boxes; props are drawn as cylinders, cones and balls over a box collider
so the maps do not look like stacked cubes. Faces are merged into one mesh per
ink colour. Stairs are solid step blocks so the navigation mesh and the
player's step-up both work. Run: python3 tools/make-maps.py
"""
import json
import math
import random
from pathlib import Path

OUTPUT = Path(__file__).resolve().parent.parent / 'native/data'
# The first six inks are the original's; the pen colours after them are port additions.
BLUE, RED, DARK, ORANGE, GREEN, PINK, YELLOW, LIME, PURPLE, TEAL = range(10)
FACES = [((1, 0, 0), [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]), ((-1, 0, 0), [(0, 0, 1), (0, 1, 1), (0, 1, 0), (0, 0, 0)]),
         ((0, 1, 0), [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)]), ((0, -1, 0), [(0, 0, 1), (0, 0, 0), (1, 0, 0), (1, 0, 1)]),
         ((0, 0, 1), [(1, 0, 1), (1, 1, 1), (0, 1, 1), (0, 0, 1)]), ((0, 0, -1), [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)])]


class Map:
    def __init__(self, key, half, start, wall=8.0):
        self.key, self.half, self.start = key, half, list(start)
        self.boxes, self.meshes, self.decor = [], {}, False
        self.spawns, self.snipers, self.pickups, self.arena, self.rings = [], [], [], [], []
        self.box(0, -1, 0, half * 2, 1, half * 2)
        for x, z, w, d in [(0, -half, half * 2, 1), (0, half, half * 2, 1), (-half, 0, 1, half * 2), (half, 0, 1, half * 2)]:
            self.box(x, 0, z, w, wall, d)

    def collider(self, x, y, z, w, h, d):
        self.boxes.append({'min': [x - w / 2, y, z - d / 2], 'max': [x + w / 2, y + h, z + d / 2], 'no_grapple': False, 'no_shoot': False, 'breakable': -1})

    def box(self, x, y, z, w, h, d, ink=BLUE, solid=True, fill=False):
        """Box centred on x/z with its base at y. Scattered props are tinted like the round ones."""
        low, high = [x - w / 2, y, z - d / 2], [x + w / 2, y + h, z + d / 2]
        if solid:
            self.collider(x, y, z, w, h, d)
        mesh = self.meshes.setdefault((ink, fill, self.decor), {'vertices': [], 'normals': []})
        for normal, corners in FACES:
            for i in (0, 2, 1, 0, 3, 2):
                mesh['vertices'] += [round(low[a] + (high[a] - low[a]) * corners[i][a], 3) for a in range(3)]
                mesh['normals'] += normal

    def tri(self, ink, fill, points, normals):
        """One triangle with per-corner normals, wound clockwise seen from outside as Godot expects.
        Round props are tinted: hatched in their colour even where the light hits them."""
        a, b, c = points
        u, v = [b[i] - a[i] for i in range(3)], [c[i] - a[i] for i in range(3)]
        cross = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
        if sum(cross[i] * (normals[0][i] + normals[1][i] + normals[2][i]) for i in range(3)) > 0:
            points, normals = [a, c, b], [normals[0], normals[2], normals[1]]
        mesh = self.meshes.setdefault((ink, fill, True), {'vertices': [], 'normals': []})
        for point, normal in zip(points, normals):
            mesh['vertices'] += [round(value, 3) for value in point]
            mesh['normals'] += [round(value, 3) for value in normal]

    def cyl(self, x, y, z, r, h, ink=BLUE, solid=True, top=None, sides=10, fill=False, collide=None):
        """Upright cylinder, or a cone when `top` is 0, with its base at y. The collider is a box `collide` wide."""
        top = r if top is None else top
        if solid:
            width = collide or max(r, top) * 1.7
            self.collider(x, y, z, width, h, width)
        slope = (r - top) / h
        for i in range(sides):
            ring = []
            for angle in (math.tau * i / sides, math.tau * (i + 1) / sides):
                length = math.hypot(1, slope)
                ring.append(([x + math.cos(angle) * r, y, z + math.sin(angle) * r], [x + math.cos(angle) * top, y + h, z + math.sin(angle) * top],
                             [math.cos(angle) / length, slope / length, math.sin(angle) / length]))
            (b0, t0, n0), (b1, t1, n1) = ring
            self.tri(ink, fill, [b0, b1, t1], [n0, n1, n1])
            if top > 0:
                self.tri(ink, fill, [b0, t1, t0], [n0, n1, n0])
                self.tri(ink, fill, [[x, y + h, z], t0, t1], [[0, 1, 0]] * 3)

    def ball(self, x, y, z, r, ink=GREEN, solid=False, squash=1.0, fill=False, segments=8, rings=5):
        """Ball or flattened blob with its lowest point at y."""
        if solid:
            self.collider(x, y, z, r * 1.5, r * 2 * squash * 0.9, r * 1.5)
        def point(ring, segment):
            lat, lon = math.pi * (ring / rings - 0.5), math.tau * segment / segments
            unit = [math.cos(lat) * math.cos(lon), math.sin(lat), math.cos(lat) * math.sin(lon)]
            normal = [unit[0], unit[1] / squash, unit[2]]
            length = math.sqrt(sum(value * value for value in normal))
            return [x + unit[0] * r, y + (unit[1] + 1) * r * squash, z + unit[2] * r], [value / length for value in normal]
        for ring in range(rings):
            for segment in range(segments):
                (a, na), (b, nb), (c, nc), (d, nd) = point(ring, segment), point(ring, segment + 1), point(ring + 1, segment + 1), point(ring + 1, segment)
                if ring > 0:
                    self.tri(ink, fill, [a, b, c], [na, nb, nc])
                if ring < rings - 1:
                    self.tri(ink, fill, [a, c, d], [na, nc, nd])

    # ---- props ----
    def tree(self, x, z, height=6.0, leaf=GREEN):
        """Round tree: the trunk blocks shots and the canopy can be stood on."""
        self.cyl(x, 0, z, 0.6, height, DARK, collide=1.2)
        self.collider(x, height, z, 5.2, 1.6, 5.2)
        self.collider(x, height + 1.6, z, 3.2, 1.4, 3.2)
        self.ball(x, height - 1.2, z, 3.0, leaf, squash=0.5, rings=6)
        self.ball(x, height + 0.7, z, 2.1, leaf, squash=0.55, rings=6)

    def pine(self, x, z, height=7.0, leaf=GREEN):
        self.cyl(x, 0, z, 0.35, height * 0.45, DARK, collide=1.0)
        for i in range(3):
            self.cyl(x, height * (0.22 + i * 0.24), z, 2.3 - i * 0.6, height * 0.36, leaf, solid=False, top=0, sides=8)

    def palm(self, x, z, height=7.0):
        self.cyl(x, 0, z, 0.42, height, ORANGE, top=0.28, sides=8, collide=1.0)
        self.ball(x, height - 0.5, z, 2.6, LIME, squash=0.3)
        self.ball(x, height + 0.2, z, 1.4, GREEN, squash=0.45)
        for dx, dz in [(0.45, 0.1), (-0.3, 0.4), (-0.1, -0.45)]:
            self.ball(x + dx, height - 0.75, z + dz, 0.24, DARK, fill=True, segments=6, rings=4)

    def bush(self, x, z, size=1.0, leaf=GREEN):
        """Soft cover: hides whoever stands in it but stops nothing."""
        self.ball(x, 0, z, 1.1 * size, leaf, squash=0.7)
        self.ball(x + 0.8 * size, 0, z + 0.4 * size, 0.75 * size, leaf, squash=0.75)
        self.ball(x - 0.6 * size, 0, z - 0.6 * size, 0.6 * size, LIME if leaf == GREEN else GREEN, squash=0.8)

    def rock(self, x, z, size=1.0):
        self.ball(x, -0.15 * size, z, size, DARK, solid=True, squash=0.6, segments=7, rings=4)

    def barrel(self, x, z, ink=RED):
        self.cyl(x, 0, z, 0.55, 1.3, ink)
        for y in (0.25, 0.95):
            self.cyl(x, y, z, 0.6, 0.1, DARK, solid=False, fill=True)

    def flower(self, x, z, ink=YELLOW):
        self.cyl(x, 0, z, 0.04, 0.55, LIME, solid=False, sides=4, fill=True)
        self.ball(x, 0.45, z, 0.17, ink, fill=True, segments=6, rings=4)

    def grass(self, x, z):
        for dx, dz, height in [(0, 0, 0.6), (0.14, 0.08, 0.42), (-0.12, 0.1, 0.5), (0.02, -0.14, 0.36)]:
            self.cyl(x + dx, 0, z + dz, 0.06, height, LIME, solid=False, top=0, sides=3, fill=True)

    def lamp(self, x, z, height=5.0):
        self.cyl(x, 0, z, 0.13, height, DARK, sides=6, collide=0.4)
        self.cyl(x, 0, z, 0.3, 0.35, DARK, solid=False, sides=8)
        self.ball(x, height - 0.1, z, 0.4, YELLOW, fill=True, segments=8, rings=5)

    def traffic_cone(self, x, z):
        self.box(x, 0, z, 0.7, 0.07, 0.7, DARK, solid=False, fill=True)
        self.cyl(x, 0.07, z, 0.27, 0.75, ORANGE, solid=False, top=0.05, sides=8, fill=True)

    def mushroom(self, x, z, size=1.0, ink=RED):
        self.cyl(x, 0, z, 0.16 * size, 0.5 * size, PINK, solid=False, sides=6)
        self.ball(x, 0.4 * size, z, 0.5 * size, ink, squash=0.45, fill=True, segments=8, rings=4)

    def pencil(self, x, z, height=7.0, ink=YELLOW):
        """A giant pencil stuck in the ground eraser first."""
        self.cyl(x, 0, z, 0.52, 0.7, PINK, sides=8, collide=0.95)
        self.cyl(x, 0.7, z, 0.54, 0.3, DARK, solid=False, sides=8, fill=True)
        self.cyl(x, 1.0, z, 0.5, height - 2.4, ink, sides=6, collide=0.95)
        self.cyl(x, height - 1.4, z, 0.5, 1.0, ORANGE, solid=False, top=0.16, sides=6)
        self.cyl(x, height - 0.4, z, 0.16, 0.4, DARK, solid=False, top=0, sides=6, fill=True)

    def cactus(self, x, z, height=3.0):
        self.cyl(x, 0, z, 0.4, height, GREEN, sides=8, collide=0.8)
        self.ball(x, height - 0.4, z, 0.4, GREEN, segments=8, rings=4)
        for side, base in ((1, 0.45), (-1, 0.3)):
            self.cyl(x + side * 0.85, height * base + 0.3, z, 0.22, height * 0.38, GREEN, solid=False, sides=6)
            self.box(x + side * 0.45, height * base + 0.25, z, 0.9, 0.3, 0.3, GREEN, solid=False)
        self.ball(x, height + 0.3, z, 0.16, PINK, fill=True, segments=6, rings=4)

    def tent(self, x, z, ink=GREEN):
        self.cyl(x, 0, z, 2.6, 2.5, ink, solid=False, top=0, sides=4)
        self.collider(x, 0, z, 2.6, 1.5, 2.6)

    def hay(self, x, z):
        self.cyl(x, 0, z, 0.95, 1.1, YELLOW)

    def pot(self, x, z, ink=ORANGE, plant=True):
        self.cyl(x, 0, z, 0.38, 0.8, ink, top=0.55, sides=8, collide=0.9)
        if plant:
            self.ball(x, 0.7, z, 0.6, LIME, squash=0.8, segments=7, rings=4)

    def bollard(self, x, z, ink=YELLOW):
        self.cyl(x, 0, z, 0.26, 0.9, ink, sides=8, collide=0.55)
        self.ball(x, 0.72, z, 0.28, ink, segments=7, rings=4)

    def tires(self, x, z, count=3):
        for i in range(count):
            self.cyl(x, i * 0.36, z, 0.62, 0.3, DARK, solid=False, fill=True)
        self.collider(x, 0, z, 1.1, count * 0.36, 1.1)

    def bin(self, x, z, ink=GREEN):
        self.cyl(x, 0, z, 0.42, 1.0, ink, top=0.5, sides=8, collide=0.9)
        self.cyl(x, 1.0, z, 0.54, 0.1, DARK, solid=False, sides=8, fill=True)

    def clear(self, x, z, radius, gap, keep):
        """True when a prop of `radius` leaves `gap` to every ground-level solid and `keep` to every gameplay point."""
        for b in self.boxes[1:]:
            if b['min'][1] < 2.5 and b['min'][0] - radius - gap < x < b['max'][0] + radius + gap and b['min'][2] - radius - gap < z < b['max'][2] + radius + gap:
                return False
        if math.hypot(self.start[0] - x, self.start[2] - z) < radius + keep + 3.0:
            return False
        return all(math.hypot(p[0] - x, p[2] - z) > radius + keep for p in self.spawns + self.pickups + self.arena + self.snipers + self.rings)

    def scatter(self, seed, count, place, radius=0.6, solid=True, area=None):
        """Place up to `count` props at repeatable random spots. Solid props keep
        a 2.2 m lane to every other solid, so enemies can always path around them."""
        rng = random.Random(f'{self.key}-{seed}')
        x0, z0, x1, z1 = area or (-self.half + 2.5, -self.half + 2.5, self.half - 2.5, self.half - 2.5)
        placed = 0
        for attempt in range(count * 60):
            if placed == count:
                break
            x, z = round(rng.uniform(x0, x1), 1), round(rng.uniform(z0, z1), 1)
            if self.clear(x, z, radius, 2.2 if solid else 0.15, 3.0 if solid else 0.0):
                self.decor = True
                place(x, z, rng)
                self.decor = False
                placed += 1

    def stairs(self, x, y, z, dx, dz, height, width, ink=BLUE, run=0.8):
        """Solid steps starting at x/z and climbing `height` along the dx/dz axis; returns the top landing point."""
        steps = max(1, round(height / 0.4))
        rise = height / steps
        for i in range(steps):
            cx, cz = x + dx * run * (i + 0.5), z + dz * run * (i + 0.5)
            self.box(cx, y, cz, run if dx else width, rise * (i + 1), width if dx else run, ink)
        return x + dx * run * steps, z + dz * run * steps

    def ring(self, x, y, z):
        self.rings.append([x, y, z])
        self.box(x, y - 0.25, z, 0.5, 0.5, 0.5, ORANGE, solid=False)

    def write(self):
        solids = self.boxes[5:]
        for label, points in [('start', [self.start]), ('spawn', self.spawns), ('arena', self.arena), ('pickup', self.pickups), ('sniper', self.snipers)]:
            for p in points:
                for b in solids:
                    if all(b['min'][a] - 0.4 < p[a] + (0.5 if a == 1 else 0) < b['max'][a] + (0.4 if a != 1 else 0) for a in range(3)):
                        raise SystemExit(f'{self.key}: {label} point {p} is inside {b["min"]}..{b["max"]}')
        children = [{'name': 'Mesh', 'position': [0, 0, 0], 'quaternion': [0, 0, 0, 1], 'scale': [1, 1, 1], 'visible': True, 'mesh': mesh,
                     'ink': ink, 'fill': fill, 'shade': [0.5, 0] if tint else [1, 0], 'children': []} for (ink, fill, tint), mesh in sorted(self.meshes.items())]
        for arena in (False, True):
            data = {'key': self.key, 'arena': arena, 'player_start': self.start, 'spawns': self.spawns, 'snipers': self.snipers, 'pickups': self.pickups,
                    'arena_spawns': self.arena, 'rings': self.rings, 'boxes': self.boxes, 'children': children, 'breakables': [], 'movers': []}
            (OUTPUT / f'{self.key}{"_arena" if arena else ""}.json').write_text(json.dumps(data, separators=(',', ':')))
        print(self.key, len(self.boxes), 'colliders')


def castle():
    m = Map('castle', 50, (0, 0, 38), wall=11)
    # Wall walk at y=5 along all four walls, corner towers above it.
    for x, z, w, d in [(0, -47, 94, 5), (0, 47, 94, 5), (-47, 0, 5, 84), (47, 0, 5, 84)]:
        m.box(x, 0, z, w, 5, d)
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.box(sx * 44, 5, sz * 44, 10, 5, 10, DARK)
            m.snipers.append([sx * 44, 10, sz * 44])
            for bx, bz in [(-4, -4), (4, -4), (-4, 4), (4, 4)]:
                m.box(sx * 44 + bx, 10, sz * 44 + bz, 1.6, 1.4, 1.6, DARK)
    m.stairs(-22, 0, -43, 1, 0, 5, 3)
    m.stairs(22, 0, 43, -1, 0, 5, 3)
    m.stairs(-43, 0, 22, 0, -1, 5, 3)
    m.stairs(43, 0, -22, 0, 1, 5, 3)
    # Central keep with a long south stair, parapet and a red banner tower.
    m.box(0, 0, -6, 18, 8, 18)
    m.stairs(0, 0, 19, 0, -1, 8, 5, run=0.8)
    for bx in (-8, -4, 4, 8):
        m.box(bx, 8, -14.2, 1.6, 1.3, 1.6)
        m.box(bx, 8, 2.2, 1.6, 1.3, 1.6)
    for bz in (-10, -6, -2):
        m.box(-8.2, 8, bz, 1.6, 1.3, 1.6)
        m.box(8.2, 8, bz, 1.6, 1.3, 1.6)
    m.box(0, 8, -9, 4, 6, 4, RED)
    m.box(0, 14, -9, 0.3, 4, 0.3, DARK)
    m.box(1.1, 16.4, -9, 2, 1.4, 0.1, RED, solid=False)
    # Gatehouse, well, market stalls and crates in the courtyard.
    for sx in (-1, 1):
        m.box(sx * 9, 0, 41, 6, 7, 7, DARK)
        m.box(sx * 26, 0, 14, 5, 0.9, 2.2, ORANGE)
        m.box(sx * 26, 0.9, 14, 5.6, 0.2, 2.8, RED)
        m.box(sx * 30, 0, -22, 2.2, 2.2, 2.2, ORANGE)
        m.box(sx * 30, 2.2, -22, 1.6, 1.6, 1.6, ORANGE)
        m.box(sx * 18, 0, 30, 2, 2, 2, ORANGE)
        m.box(sx * 34, 0, 34, 3, 1.4, 3, GREEN)
    m.cyl(22, 0, -32, 1.9, 1.1, DARK, sides=12, collide=3.4)
    m.cyl(22, 1.1, -32, 1.5, 0.02, TEAL, solid=False, sides=12, fill=True)
    for sx in (-1, 1):
        m.cyl(22 + sx * 1.7, 1.1, -32, 0.12, 1.8, ORANGE, solid=False, sides=6)
    m.box(22, 2.9, -32, 4.2, 0.2, 0.9, RED, solid=False)
    m.box(-20, 0, -30, 8, 3.2, 5)
    m.box(-20, 3.2, -30, 9, 0.4, 6, RED)
    m.snipers.append([0, 8, -3])
    m.spawns += [[-38, 0, 28], [38, 0, 28], [-38, 0, -8], [38, 0, -8], [-14, 0, -38], [14, 0, -38], [-38, 0, 8], [38, 0, 8], [-30, 0, 38], [30, 0, 38], [0, 0, -26], [-12, 0, 26]]
    m.pickups += [[0, 8, -2], [-30, 0, 0], [30, 0, 0], [0, 0, -30], [0, 5, -47], [-47, 5, 0], [47, 5, 0], [0, 0, 28], [22, 0, -26], [-20, 3.6, -30]]
    m.arena += [[-38, 0, 28], [38, 0, 28], [-38, 0, -30], [38, 0, -30], [0, 8, -3], [0, 5, -47], [-47, 5, 10], [47, 5, -10], [0, 0, 34], [-14, 0, -38], [14, 0, -38], [-30, 0, 4], [30, 0, 4], [-44, 10, -44], [44, 10, 44]]
    for p in [(0, 15, 12), (-26, 11, -26), (26, 11, -26), (-26, 11, 26), (26, 11, 26)]:
        m.ring(*p)
    # Pennants on the towers, then courtyard clutter: barrels, hay, trees, torches, pots and flowers.
    for i, (sx, sz) in enumerate([(-1, -1), (1, -1), (-1, 1), (1, 1)]):
        m.cyl(sx * 40.4, 11.4, sz * 40.4, 0.1, 3.4, DARK, solid=False, sides=5)
        m.box(sx * 40.4 + 0.9, 13.6, sz * 40.4, 1.7, 1.0, 0.08, [YELLOW, PURPLE, TEAL, PINK][i], solid=False, fill=True)
    inks = [RED, YELLOW, TEAL, PURPLE, ORANGE]
    m.scatter('trees', 7, lambda x, z, r: m.tree(x, z, 5 + r.randrange(3), r.choice([GREEN, LIME])), 1.4)
    m.scatter('barrels', 12, lambda x, z, r: m.barrel(x, z, r.choice(inks)))
    m.scatter('hay', 8, lambda x, z, r: m.hay(x, z), 1.0)
    m.scatter('torches', 8, lambda x, z, r: m.lamp(x, z, 3.6), 0.3)
    m.scatter('pots', 9, lambda x, z, r: m.pot(x, z, r.choice([ORANGE, TEAL, PURPLE])), 0.5)
    m.scatter('rocks', 6, lambda x, z, r: m.rock(x, z, r.uniform(0.7, 1.2)), 1.0)
    m.scatter('bushes', 16, lambda x, z, r: m.bush(x, z, r.uniform(0.7, 1.2), r.choice([GREEN, LIME])), 1.2, solid=False)
    m.scatter('flowers', 46, lambda x, z, r: m.flower(x, z, r.choice([YELLOW, PINK, PURPLE, RED])), 0.2, solid=False)
    m.scatter('grass', 60, lambda x, z, r: m.grass(x, z), 0.2, solid=False)
    m.write()


def harbor():
    m = Map('harbor', 52, (0, 0, 42))
    inks = [BLUE, RED, ORANGE, GREEN, BLUE, PINK]
    # Container yard: rows of 12 x 2.8 x 2.6 boxes stacked one to three high.
    stacks = {(-36, -30): 2, (-21, -30): 1, (-6, -30): 3, (9, -30): 1, (24, -30): 2, (39, -30): 1,
              (-36, -17): 1, (-21, -17): 3, (9, -17): 2, (24, -17): 1, (39, -17): 3,
              (-36, -4): 2, (-6, -4): 1, (9, -4): 3, (39, -4): 1,
              (-21, 9): 1, (-6, 9): 2, (24, 9): 2, (39, 9): 1}
    n = 0
    for (x, z), count in stacks.items():
        for level in range(count):
            m.box(x, level * 2.8, z, 12, 2.8, 2.6, inks[n % len(inks)])
            n += 1
        if count == 3:
            m.snipers.append([x, 8.4, z])
    # Steps onto single containers so the stacks can be climbed without the grapple.
    m.stairs(-28.2, 0, -30, 1, 0, 2.8, 2.6, DARK, run=0.17)
    m.stairs(17.2, 0, -17, 1, 0, 2.8, 2.6, DARK, run=0.17)
    m.stairs(-13.8, 0, -4, 1, 0, 2.8, 2.6, DARK, run=0.17)
    m.stairs(-28.8, 0, 9, 1, 0, 2.8, 2.6, DARK, run=0.17)
    # Gantry crane: four legs, a walkable beam and a hanging container.
    for x in (-24, 24):
        for z in (20, 28):
            m.box(x, 0, z, 2, 14, 2, DARK)
    m.box(0, 14, 24, 52, 2, 10, DARK)
    m.box(4, 8.5, 24, 12, 2.8, 2.6, RED)
    m.box(4, 11.3, 24, 0.3, 2.7, 0.3, DARK, solid=False)
    m.snipers.append([-12, 16, 24])
    # Warehouse with roof stairs, and a moored ship along the north quay.
    m.box(-38, 0, 37, 22, 6, 14)
    m.stairs(-22.2, 0, 41, -1, 0, 6, 3, run=0.32)
    m.box(-38, 6, 37, 6, 1.2, 4, DARK)
    m.box(6, 0, -44.5, 56, 4, 9, DARK)
    m.box(22, 4, -44.5, 12, 4, 7)
    m.box(24, 8, -44.5, 5, 2.5, 4, RED)
    m.box(-8, 4, -44.5, 2, 9, 2, ORANGE)
    m.stairs(-18, 0, -38.5, 1, 0, 4, 3, DARK, run=0.5)
    for x in (-40, -20, 0, 20, 40):
        m.bollard(x, 47)
    for x, z in [(-8, 34), (10, 36), (30, 34), (14, -10), (-22, -4)]:
        m.box(x, 0, z, 2, 2, 2, ORANGE)
    m.spawns += [[-46, 0, -10], [46, 0, 24], [-46, 0, 20], [46, 0, -10], [-14, 0, -23], [30, 0, -23], [0, 0, 3], [-30, 0, 16], [32, 0, 16], [16, 0, 44], [-12, 0, 44], [46, 0, 44]]
    m.pickups += [[-6, 8.4, -30], [0, 16, 24], [-38, 6, 34], [22, 8, -42], [0, 0, 16], [30, 0, 3], [-28, 0, -10], [16, 0, -23], [-46, 0, 0], [46, 0, 36]]
    m.arena += [[-46, 0, -10], [46, 0, 24], [-46, 0, 20], [46, 0, -10], [-6, 8.4, -30], [39, 8.4, -17], [9, 8.4, -4], [0, 16, 24], [-38, 6, 33], [19, 8, -44], [0, 0, 3], [16, 0, 44], [-12, 0, 44], [30, 0, -23], [-14, 0, -23]]
    for p in [(0, 12, 6), (-20, 11, -10), (26, 11, -4), (-30, 10, 24), (30, 19, 24), (6, 12, -36)]:
        m.ring(*p)
    # Ship funnel and lifebuoys, then dockside clutter: drums, tyres, cones, lamps, buoys and coiled rope.
    m.cyl(24, 10.5, -44.5, 1.1, 3.2, YELLOW, solid=False, top=0.9)
    m.cyl(24, 13.7, -44.5, 0.95, 0.5, DARK, solid=False, fill=True)
    for x in (-14, 0, 12):
        m.cyl(x, 4, -40.6, 0.55, 0.16, RED, solid=False, fill=True)
    yard = [TEAL, YELLOW, RED, PURPLE, LIME]
    m.scatter('drums', 16, lambda x, z, r: m.barrel(x, z, r.choice(yard)))
    m.scatter('tyres', 9, lambda x, z, r: m.tires(x, z, 2 + r.randrange(3)), 0.7)
    m.scatter('lamps', 8, lambda x, z, r: m.lamp(x, z, 6.0), 0.3)
    m.scatter('bollards', 10, lambda x, z, r: m.bollard(x, z, r.choice([YELLOW, RED])), 0.35)
    m.scatter('crates', 10, lambda x, z, r: m.box(x, 0, z, 1.5, 1.5, 1.5, r.choice(yard)), 0.9)
    m.scatter('buoys', 7, lambda x, z, r: (m.ball(x, 0, z, 0.75, r.choice([RED, YELLOW]), solid=True, fill=True), m.cyl(x, 1.4, z, 0.08, 0.9, DARK, solid=False, sides=5)), 0.7)
    m.scatter('cones', 26, lambda x, z, r: m.traffic_cone(x, z), 0.4, solid=False)
    m.scatter('rope', 14, lambda x, z, r: (m.cyl(x, 0, z, 0.8, 0.14, ORANGE, solid=False), m.cyl(x, 0.14, z, 0.55, 0.14, ORANGE, solid=False)), 0.9, solid=False)
    m.scatter('paint', 22, lambda x, z, r: m.cyl(x, 0, z, r.uniform(0.6, 1.4), 0.02, r.choice([YELLOW, TEAL, LIME]), solid=False, fill=True), 1.4, solid=False)
    m.write()


def pyramid():
    m = Map('pyramid', 54, (0, 0, 44))
    # Stepped pyramid: five terraces 2.4 high with a stair flight on every side of every level.
    cz = -6
    for level, size in enumerate([46, 37, 28, 19, 10]):
        y = level * 2.4
        m.box(0, y, cz, size, 2.4, size, ORANGE if level % 2 else BLUE)
        edge = size / 2 + 3.2
        m.stairs(0, y, cz + edge, 0, -1, 2.4, 4, DARK, run=0.533)
        m.stairs(0, y, cz - edge, 0, 1, 2.4, 4, DARK, run=0.533)
        m.stairs(edge, y, cz, -1, 0, 2.4, 4, DARK, run=0.533)
        m.stairs(-edge, y, cz, 1, 0, 2.4, 4, DARK, run=0.533)
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.box(sx * 3.6, 12, cz + sz * 3.6, 1, 3.4, 1, DARK)
    m.box(0, 15.4, cz, 9.4, 0.8, 9.4, RED)
    m.snipers += [[0, 12, cz], [20, 2.4, cz + 20], [-20, 2.4, cz - 20]]
    # Obelisks, two sphinxes guarding the south approach, and broken walls.
    for x, z in [(-34, 34), (34, 34), (-40, -40), (40, -40)]:
        m.box(x, 0, z, 2.4, 11, 2.4, DARK)
        m.cyl(x, 11, z, 1.7, 2.2, YELLOW, top=0, sides=4, collide=1.4)
    for sx in (-1, 1):
        m.box(sx * 14, 0, 34, 5, 3.2, 12)
        m.box(sx * 14, 3.2, 29.5, 3.6, 3.4, 3.6)
        m.box(sx * 14, 0, 26.5, 5, 1.2, 3)
        m.snipers.append([sx * 14, 3.2, 36])
        for i, h in enumerate([3.4, 2.2, 3.0, 1.2, 2.6]):
            m.box(sx * 42, 0, -22 + i * 6.4, 1.2, h, 5)
        m.box(sx * 30, 0, -34, 9, 2.6, 1.2)
        m.box(sx * 38, 0, 12, 3, 1.6, 3, GREEN)
        m.box(sx * 30, 0, 22, 2, 2, 2, ORANGE)
    m.spawns += [[-48, 0, 44], [48, 0, 44], [-48, 0, 0], [48, 0, 0], [-48, 0, -46], [48, 0, -46], [0, 0, -46], [-24, 0, 44], [24, 0, 44], [-48, 0, 24], [48, 0, 24], [-20, 0, -44]]
    m.pickups += [[0, 12, cz + 2.5], [0, 0, 26], [-34, 0, 26], [34, 0, 26], [-48, 0, -10], [48, 0, -10], [0, 0, -44], [20, 2.4, cz - 20], [-20, 2.4, cz + 20], [-14, 3.2, 38]]
    m.arena += [[-48, 0, 44], [48, 0, 44], [-48, 0, -46], [48, 0, -46], [0, 12, cz + 2.5], [20, 2.4, cz + 20], [-20, 2.4, cz - 20], [16, 4.8, cz - 16], [-16, 4.8, cz + 16], [0, 0, -46], [-48, 0, 0], [48, 0, 0], [24, 0, 44], [-24, 0, 44], [14, 3.2, 38]]
    for p in [(0, 20, cz), (-26, 12, 16), (26, 12, 16), (-26, 12, -28), (26, 12, -28), (0, 9, 30)]:
        m.ring(*p)
    # A golden cap on the shrine, then palms, cacti, urns, fallen column drums, rocks and dry grass.
    m.cyl(0, 16.2, cz, 3.2, 2.6, YELLOW, solid=False, top=0, sides=4)
    m.scatter('palms', 12, lambda x, z, r: m.palm(x, z, 6 + r.randrange(3)), 1.0)
    m.scatter('cacti', 12, lambda x, z, r: m.cactus(x, z, r.uniform(2.2, 3.6)), 1.1)
    m.scatter('urns', 14, lambda x, z, r: m.pot(x, z, r.choice([TEAL, ORANGE, PURPLE, YELLOW]), plant=False), 0.5)
    m.scatter('columns', 9, lambda x, z, r: (m.cyl(x, 0, z, 0.7, r.uniform(1.2, 4.2), r.choice([ORANGE, BLUE]), sides=10), m.cyl(x, 0, z, 0.9, 0.3, DARK, solid=False)), 0.9)
    m.scatter('rocks', 12, lambda x, z, r: m.rock(x, z, r.uniform(0.7, 1.5)), 1.2)
    m.scatter('torches', 6, lambda x, z, r: m.lamp(x, z, 3.2), 0.3)
    m.scatter('scrub', 18, lambda x, z, r: m.bush(x, z, r.uniform(0.5, 0.9), LIME), 1.0, solid=False)
    m.scatter('grass', 70, lambda x, z, r: m.grass(x, z), 0.2, solid=False)
    m.scatter('blooms', 24, lambda x, z, r: m.flower(x, z, r.choice([PINK, YELLOW, PURPLE])), 0.2, solid=False)
    m.write()


def station():
    m = Map('station', 52, (0, 0, 42))
    # Two platforms 1.2 high with steps at the ends and middle, and canopies on pillars.
    for z in (-15, 15):
        m.box(0, 0, z, 84, 1.2, 8)
        side = 1 if z > 0 else -1
        for x in (-30, 0, 30):
            m.stairs(x, 0, z + side * 5.2, 0, -side, 1.2, 5, DARK, run=0.4)
        m.stairs(-43.2, 0, z, 1, 0, 1.2, 6, DARK, run=0.4)
        m.stairs(43.2, 0, z, -1, 0, 1.2, 6, DARK, run=0.4)
        for cx in (-22, 22):
            for px in (-9, 9):
                m.cyl(cx + px, 1.2, z + side * 2.6, 0.32, 3.8, DARK, sides=8, collide=0.6)
            m.box(cx, 5, z + side * 1.4, 24, 0.4, 6.4, RED)
            m.snipers.append([cx, 5.4, z + side * 1.4])
        for x in (-34, -12, 12, 34):
            m.box(x, 1.2, z + side * 2.4, 2.4, 0.5, 0.7, ORANGE)
    # Rails and two trains with gaps to run through; roofs are walkable.
    for z in (-7.2, -5.2, 5.2, 7.2):
        m.box(0, 0, z, 100, 0.15, 0.25, DARK, solid=False)
    for z, cars, ink in [(-6.2, (-34, -18, 14, 30), BLUE), (6.2, (-26, -10, 22, 38), GREEN)]:
        for x in cars:
            m.box(x, 0.5, z, 14, 3.4, 3.2, ink)
            m.box(x, 3.9, z, 13, 0.3, 2.6, DARK)
            for wx in (-5, 5):
                m.box(x + wx, 0, z, 2.4, 0.5, 2.8, DARK)
    # Footbridge over the tracks, reached by stairs on both platforms.
    m.box(0, 6.6, 0, 5, 0.6, 30, DARK)
    for z in (-15, 15):
        side = 1 if z > 0 else -1
        m.stairs(-15.4, 1.2, z + side * 0.2, 1, 0, 6, 3.6, DARK, run=0.86)
        m.box(0, 1.2, z + side * 0.2, 5, 6, 3.6, DARK)
        for bz in (-1.9, 1.9):
            m.box(0, 7.2, bz * 7 * 0 + z * 0.6 + bz * 0, 0.2, 1, 0.2, DARK, solid=False)
    for x in (-2.4, 2.4):
        m.box(x, 7.2, 0, 0.2, 1.0, 26, DARK)
    # Station hall on the north side, clock tower, kiosks and luggage.
    m.box(-6, 0, -43, 62, 9, 12)
    m.box(-6, 9, -43, 20, 3, 8, RED)
    m.stairs(28.4, 0, -40, -1, 0, 9, 4, DARK, run=0.36)
    m.box(40, 0, -42, 7, 17, 7, DARK)
    m.box(40, 17, -42, 8.4, 1.2, 8.4, RED)
    m.box(40, 12.5, -38.4, 3.2, 3.2, 0.2, YELLOW, solid=False, fill=True)
    m.box(40, 13.9, -38.25, 0.16, 1.2, 0.1, DARK, solid=False, fill=True)
    m.box(40.45, 13.9, -38.25, 1.0, 0.16, 0.1, DARK, solid=False, fill=True)
    m.cyl(40, 18.2, -42, 4.6, 3.4, PURPLE, solid=False, top=0, sides=4)
    for x, z, ink in [(-36, 32, PINK), (36, 32, GREEN), (-18, 44, ORANGE), (20, 44, ORANGE)]:
        m.box(x, 0, z, 4, 3, 4, ink)
        m.box(x, 3, z, 5, 0.3, 5, RED)
    for x, z in [(-8, 30), (10, 28), (-28, -30), (44, 2), (-44, -2), (2, 0.4)]:
        m.box(x, 0, z, 1.6, 1.6, 1.6, ORANGE)
    m.spawns += [[-47, 0, 40], [47, 0, 40], [-47, 0, 26], [47, 0, 26], [-47, 0, -30], [47, 0, -28], [-47, 0, 0], [47, 0, 10], [0, 0, 46], [-26, 0, 38], [26, 0, 38], [-10, 0, -30]]
    m.pickups += [[0, 7.2, 0], [-22, 5.4, 16.4], [22, 5.4, -16.4], [-34, 4.2, -6.2], [38, 4.2, 6.2], [0, 0, 34], [14, 9, -42], [10, 1.2, 15], [-26, 1.2, -15], [44, 0, -30]]
    m.arena += [[-47, 0, 40], [47, 0, 40], [-47, 0, -30], [47, 0, -28], [0, 7.2, 0], [-22, 5.4, 16.4], [22, 5.4, -16.4], [14, 9, -42], [-34, 4.2, -6.2], [38, 4.2, 6.2], [20, 1.2, 15], [-20, 1.2, -15], [0, 0, 46], [-47, 0, 0], [47, 0, 10]]
    for p in [(-12, 10, 0), (14, 10, 0), (0, 12, -26), (30, 14, -30), (-30, 9, 30), (30, 9, 30)]:
        m.ring(*p)
    # Train wheels and headlights, signals, then lamps, bins, planters, luggage, trees and cones.
    for z, cars, ink in [(-6.2, (-34, -18, 14, 30), YELLOW), (6.2, (-26, -10, 22, 38), YELLOW)]:
        for x in cars:
            for side in (-1, 1):
                m.box(x, 3.0, z + side * 1.62, 11, 0.5, 0.06, ink, solid=False, fill=True)
    for x, z in [(-46, -9.6), (46, 9.6), (-46, 2.8), (46, -2.8)]:
        m.cyl(x, 0, z, 0.14, 4.2, DARK, sides=6, collide=0.4)
        m.ball(x, 4.0, z, 0.3, RED, fill=True, segments=7, rings=4)
        m.ball(x, 3.3, z, 0.3, LIME, fill=True, segments=7, rings=4)
    bags = [RED, YELLOW, TEAL, PURPLE, PINK, LIME]
    yard = (-50, 20.5, 50, 49)
    m.scatter('trees', 7, lambda x, z, r: m.tree(x, z, 5 + r.randrange(2), r.choice([GREEN, LIME])), 1.4, area=yard)
    m.scatter('lamps', 12, lambda x, z, r: m.lamp(x, z, 5.5), 0.3)
    m.scatter('bins', 10, lambda x, z, r: m.bin(x, z, r.choice([GREEN, TEAL, YELLOW])), 0.5)
    m.scatter('planters', 10, lambda x, z, r: m.pot(x, z, r.choice([ORANGE, PURPLE])), 0.5)
    m.scatter('luggage', 16, lambda x, z, r: (m.box(x, 0, z, 1.2, 0.8, 0.7, r.choice(bags)), m.box(x + 0.1, 0.8, z, 0.8, 0.5, 0.6, r.choice(bags), solid=False)), 0.8)
    m.scatter('barrels', 8, lambda x, z, r: m.barrel(x, z, r.choice([TEAL, YELLOW, RED])))
    m.scatter('bushes', 16, lambda x, z, r: m.bush(x, z, r.uniform(0.7, 1.1), r.choice([GREEN, LIME])), 1.2, solid=False, area=yard)
    m.scatter('cones', 16, lambda x, z, r: m.traffic_cone(x, z), 0.4, solid=False)
    m.scatter('flowers', 36, lambda x, z, r: m.flower(x, z, r.choice([YELLOW, PINK, PURPLE])), 0.2, solid=False, area=yard)
    m.scatter('grass', 40, lambda x, z, r: m.grass(x, z), 0.2, solid=False, area=yard)
    m.write()


def forest():
    m = Map('forest', 54, (0, 0, 44), wall=6)
    # Trees: a dark trunk under a round two-tier canopy; trunks block shots, canopies can be stood on.
    trees = [(-40, 36), (-28, 40), (-44, 18), (-34, 8), (-46, -6), (-38, -22), (-44, -40), (-26, -44), (-20, 26), (-16, 6), (-24, -10),
             (-10, -30), (40, 36), (28, 42), (46, 20), (34, 12), (44, -4), (36, -20), (46, -38), (28, -44), (18, 28), (20, -8), (10, -34),
             (4, 26), (-6, -44), (8, -16), (-30, 24), (30, -32)]
    for i, (x, z) in enumerate(trees):
        m.tree(x, z, 5 + (i * 7) % 4, LIME if i % 3 == 1 else GREEN)
    # Cabin with a porch, a watchtower with stairs, a stream with a bridge, logs and boulders.
    m.box(-6, 0, 2, 12, 4.4, 9)
    m.box(-6, 4.4, 2, 13.4, 0.5, 10.4, RED)
    m.box(-6, 4.9, 2, 7, 1.2, 5, RED)
    m.box(-6, 0, 8.2, 12, 0.4, 3.4, ORANGE)
    m.stairs(2.4, 0, 2, -1, 0, 4.4, 3, DARK, run=0.2)
    for x, z in [(22, 14), (28, 14), (22, 20), (28, 20)]:
        m.box(x, 0, z, 0.7, 9, 0.7, DARK)
    m.box(25, 9, 17, 8, 0.5, 8, ORANGE)
    m.stairs(25, 0, 30.2, 0, -1, 9, 3, DARK, run=0.4)
    for x in (21.4, 28.6):
        m.box(x, 9.5, 17, 0.3, 1.1, 8, DARK)
    m.snipers += [[25, 9.5, 16], [-6, 6.1, 2], [-16, 11, 6]]
    for x in range(-50, 51, 10):
        m.box(x, 0, -24, 10, 0.12, 5, BLUE, solid=False)
    m.box(0, 0, -24, 6, 1.0, 8, ORANGE)
    m.stairs(0, 0, -19.2, 0, -1, 1.0, 5, ORANGE, run=0.4)
    m.stairs(0, 0, -28.8, 0, 1, 1.0, 5, ORANGE, run=0.4)
    for x, z, w, d in [(12, 38, 7, 1.3), (-14, 36, 1.3, 7), (36, -10, 6, 1.3), (-32, -32, 1.3, 6), (14, -42, 7, 1.3)]:
        m.box(x, 0, z, w, 1.2, d, ORANGE)
    for x, z, size in [(-22, 16, 3), (16, 4, 2.4), (-4, -12, 3.4), (38, 26, 2.6), (-40, -12, 3), (24, -26, 2.8), (-12, 44, 2.2)]:
        m.collider(x, 0, z, size, size * 0.7, size)
        m.ball(x, -size * 0.2, z, size * 0.7, DARK, squash=0.64, segments=7, rings=4)
    m.spawns += [[-49, 0, 46], [49, 0, 46], [-49, 0, 0], [49, 0, 4], [-49, 0, -46], [49, 0, -46], [-18, 0, -48], [18, 0, -48], [-49, 0, 28], [49, 0, -14], [-12, 0, 30], [12, 0, -4]]
    m.pickups += [[25, 9.5, 18], [-6, 6.1, 3], [0, 1.0, -24], [-30, 0, 0], [34, 0, 0], [0, 0, 16], [-20, 0, -40], [20, 0, -40], [-44, 0, 30], [44, 0, 30]]
    m.arena += [[-49, 0, 46], [49, 0, 46], [-49, 0, -46], [49, 0, -46], [25, 9.5, 16], [-6, 6.1, 2], [0, 1.0, -24], [-49, 0, 0], [49, 0, 4], [-18, 0, -48], [18, 0, -48], [-12, 0, 30], [12, 0, -4], [34, 0, 0], [-30, 0, 0]]
    for p in [(0, 12, 22), (-24, 12, -4), (22, 13, -14), (-36, 12, 30), (38, 12, -30), (6, 11, -36)]:
        m.ring(*p)
    # Cabin chimney, a campfire, then pines, stumps, rocks, mushrooms, undergrowth and flowers.
    m.cyl(-9.5, 4.9, 0.5, 0.6, 2.6, DARK, solid=False, sides=6)
    for i in range(6):
        m.rock(10 + math.cos(i * 1.05) * 1.3, 14 + math.sin(i * 1.05) * 1.3, 0.35)
    m.cyl(10, 0, 14, 0.5, 1.1, YELLOW, solid=False, top=0, sides=6, fill=True)
    m.cyl(10, 0, 14, 0.8, 0.5, ORANGE, solid=False, top=0.2, sides=6, fill=True)
    m.scatter('pines', 22, lambda x, z, r: m.pine(x, z, r.uniform(6, 10), r.choice([GREEN, GREEN, TEAL])), 0.6)
    m.scatter('stumps', 10, lambda x, z, r: m.cyl(x, 0, z, 0.6, r.uniform(0.5, 1.0), ORANGE, sides=8), 0.6)
    m.scatter('rocks', 12, lambda x, z, r: m.rock(x, z, r.uniform(0.6, 1.4)), 1.2)
    m.scatter('toadstools', 8, lambda x, z, r: (m.mushroom(x, z, 3.0, r.choice([RED, PURPLE])), m.collider(x, 0, z, 0.9, 1.4, 0.9)), 0.8)
    m.scatter('bushes', 44, lambda x, z, r: m.bush(x, z, r.uniform(0.7, 1.4), r.choice([GREEN, LIME, GREEN])), 1.3, solid=False)
    m.scatter('mushrooms', 40, lambda x, z, r: m.mushroom(x, z, r.uniform(0.6, 1.2), r.choice([RED, YELLOW, PURPLE])), 0.4, solid=False)
    m.scatter('flowers', 70, lambda x, z, r: m.flower(x, z, r.choice([YELLOW, PINK, PURPLE, RED])), 0.2, solid=False)
    m.scatter('grass', 110, lambda x, z, r: m.grass(x, z), 0.2, solid=False)
    m.write()


def school():
    m = Map('school', 52, (0, 0, 44))
    # U-shaped school: a long north block and two wings around a yard, flat roofs reached by stairs.
    m.box(0, 0, -40, 80, 8, 14)
    m.box(-33, 0, -18, 14, 8, 30)
    m.box(33, 0, -18, 14, 8, 30)
    m.stairs(-22.8, 0, -4.6, 0, -1, 8, 3, DARK, run=0.5)
    m.stairs(22.8, 0, -4.6, 0, -1, 8, 3, DARK, run=0.5)
    m.box(-22.8, 0, -29.5, 3, 8, 7, DARK)
    m.box(22.8, 0, -29.5, 3, 8, 7, DARK)
    m.box(0, 8, -42, 12, 5, 8, RED)
    m.box(0, 13, -42, 0.4, 5, 0.4, DARK)
    m.box(1.3, 16.6, -42, 2.2, 1.4, 0.1, RED, solid=False)
    for x in range(-34, 35, 8):
        m.box(x, 2.6, -32.9, 3.6, 2.6, 0.2, ORANGE, solid=False)
    for z in range(-30, -5, 8):
        m.box(-25.9, 2.6, z, 0.2, 2.6, 3.6, ORANGE, solid=False)
        m.box(25.9, 2.6, z, 0.2, 2.6, 3.6, ORANGE, solid=False)
    m.snipers += [[0, 8, -36], [-33, 8, -8], [33, 8, -8], [3, 13, -42]]
    # Yard: rows of desks dragged outside, a flagpole plinth and planters.
    for row, z in enumerate((-22, -16, -10)):
        for x in (-12, -6, 0, 6, 12):
            m.box(x, 0, z, 2.4, 0.9, 1.2, ORANGE if (row + x) % 2 else BLUE)
    m.box(0, 0, -28, 4, 1.2, 4, DARK)
    for sx in (-1, 1):
        m.box(sx * 18, 0, 2, 6, 1.1, 2, GREEN)
    # Sports court with hoops, a school bus, a playground frame and bike racks.
    m.box(-28, 0, 24, 26, 0.1, 16, GREEN, solid=False)
    for x in (-40.5, -15.5):
        m.cyl(x, 0, 24, 0.25, 4, DARK, sides=6, collide=0.5)
        m.box(x + (0.9 if x < -28 else -0.9), 3.2, 24, 1.4, 1.2, 2.2, RED)
        m.cyl(x + (1.9 if x < -28 else -1.9), 3.1, 24, 0.5, 0.08, ORANGE, solid=False, fill=True)
    m.cyl(-28, 0.1, 24, 3.2, 0.02, YELLOW, solid=False, sides=14, fill=True)
    m.box(-28, 0.1, 24, 0.2, 0.03, 16, YELLOW, solid=False, fill=True)
    m.box(28, 0.6, 30, 16, 3.4, 4, ORANGE)
    m.box(28, 4.0, 30, 15, 0.3, 3.4, DARK)
    for wx in (-5.5, 5.5):
        m.box(28 + wx, 0, 30, 2.4, 0.6, 3.6, DARK)
    for x, z in [(22, 12), (30, 12), (22, 18), (30, 18)]:
        m.cyl(x, 0, z, 0.26, 4.4, PINK, sides=6, collide=0.5)
    m.box(26, 4.4, 15, 9, 0.4, 7, PINK)
    m.stairs(26, 0, 22.3, 0, -1, 4.4, 3, PINK, run=0.36)
    for x in (-6, -2, 2, 6):
        m.box(x, 0, 34, 0.3, 1.1, 3, DARK)
    for x, z in [(42, 2), (-44, 4), (10, 26), (-8, 16), (44, 44)]:
        m.box(x, 0, z, 2, 2, 2, ORANGE)
    m.spawns += [[-47, 0, 46], [47, 0, 46], [-47, 0, 10], [47, 0, 10], [-12, 0, 46], [14, 0, 46], [-47, 0, 34], [47, 0, 22], [-18, 0, -28], [18, 0, -28], [0, 0, 8], [-22, 0, 40]]
    m.pickups += [[0, 8, -36], [-33, 8, -20], [33, 8, -20], [26, 4.8, 15], [28, 4.3, 30], [0, 0, -4], [-28, 0, 24], [0, 0, 22], [-44, 0, 44], [40, 0, 40]]
    m.arena += [[-47, 0, 46], [47, 0, 46], [-47, 0, 10], [47, 0, 10], [0, 8, -36], [-33, 8, -8], [33, 8, -8], [26, 4.8, 15], [28, 4.3, 30], [-18, 0, -28], [18, 0, -28], [0, 0, 8], [-28, 0, 24], [14, 0, 46], [-12, 0, 46]]
    for p in [(0, 12, -18), (-18, 11, 4), (18, 11, 4), (0, 10, 26), (-36, 12, 10), (38, 12, 14)]:
        m.ring(*p)
    # Bus wheels and stripe, hopscotch squares, then giant pencils, trees, bins, balls, lamps and flower beds.
    for wx in (-5.5, 5.5):
        for side in (-1, 1):
            m.cyl(28 + wx, 0.05, 30 + side * 1.9, 0.62, 0.02, DARK, solid=False, sides=10, fill=True)
    for side in (-1, 1):
        m.box(28, 1.6, 30 + side * 2.02, 15, 0.4, 0.05, DARK, solid=False, fill=True)
    for i in range(7):
        m.box(8 + (i % 2) * 1.1 * (1 if i % 3 else 0), 0.02, 36 + i * 1.1, 1.0, 0.02, 1.0, [YELLOW, PINK, TEAL, LIME][i % 4], solid=False, fill=True)
    pens = [YELLOW, LIME, PURPLE, TEAL, RED, PINK]
    m.scatter('pencils', 12, lambda x, z, r: m.pencil(x, z, r.uniform(5, 9), r.choice(pens)), 0.6)
    m.scatter('trees', 10, lambda x, z, r: m.tree(x, z, 5 + r.randrange(3), r.choice([GREEN, LIME])), 1.4)
    m.scatter('bins', 8, lambda x, z, r: m.bin(x, z, r.choice([GREEN, TEAL, YELLOW])), 0.5)
    m.scatter('lamps', 8, lambda x, z, r: m.lamp(x, z, 5.0), 0.3)
    m.scatter('bags', 12, lambda x, z, r: (m.box(x, 0, z, 0.9, 1.0, 0.6, r.choice(pens)), m.ball(x, 0.85, z, 0.42, r.choice(pens), squash=0.6)), 0.6)
    m.scatter('erasers', 8, lambda x, z, r: (m.box(x, 0, z, 2.2, 1.0, 1.2, PINK), m.box(x, 1.0, z, 2.2, 0.35, 1.2, TEAL, solid=False)), 1.2)
    m.scatter('balls', 18, lambda x, z, r: m.ball(x, 0, z, r.uniform(0.25, 0.4), r.choice([ORANGE, YELLOW, RED, PURPLE]), fill=True, segments=8, rings=5), 0.4, solid=False)
    m.scatter('bushes', 22, lambda x, z, r: m.bush(x, z, r.uniform(0.7, 1.1), r.choice([GREEN, LIME])), 1.2, solid=False)
    m.scatter('cones', 14, lambda x, z, r: m.traffic_cone(x, z), 0.4, solid=False)
    m.scatter('flowers', 50, lambda x, z, r: m.flower(x, z, r.choice([YELLOW, PINK, PURPLE, RED])), 0.2, solid=False)
    m.scatter('grass', 50, lambda x, z, r: m.grass(x, z), 0.2, solid=False)
    m.write()


def military():
    m = Map('military', 54, (0, 0, 46), wall=7)
    # Barracks rows, a command bunker with a roof ramp, and four guard towers.
    for x in (-34, -20):
        for z in (-34, -18):
            m.box(x, 0, z, 10, 4, 12, GREEN)
            m.box(x, 4, z, 10.8, 0.4, 12.8, DARK)
    m.stairs(-27, 0, -9.6, 0, -1, 4.4, 2.6, DARK, run=0.2)
    m.box(22, 0, -32, 22, 5, 16, DARK)
    m.box(22, 5, -32, 8, 2.2, 6, GREEN)
    m.stairs(8.6, 0, -30, 1, 0, 5, 4, DARK, run=0.18)
    m.box(22, 2.4, -23.9, 6, 1.0, 0.2, ORANGE, solid=False)
    for sx, sz in [(-1, -1), (1, -1), (-1, 1), (1, 1)]:
        x, z = sx * 46, sz * 44
        for px, pz in [(-2, -2), (2, -2), (-2, 2), (2, 2)]:
            m.box(x + px, 0, z + pz, 0.6, 8, 0.6, DARK)
        m.box(x, 8, z, 6, 0.5, 6, GREEN)
        m.box(x, 11, z, 6.6, 0.4, 6.6, DARK)
        for px, pz in [(-2.7, 0), (2.7, 0)]:
            m.box(x + px, 8.5, z + pz, 0.3, 1.1, 6, GREEN)
        m.stairs(x - sx * 3.0, 0, z - sz * 10.2, 0, sz, 8, 2.4, DARK, run=0.36)
        m.snipers.append([x, 8.5, z])
    # Tank, helipad, sandbag walls, fuel drums, crates and a radio mast.
    m.box(-14, 0.5, 20, 9, 2, 5, GREEN)
    m.box(-14, 2.5, 20, 4.4, 1.4, 3.6, GREEN)
    m.box(-9.4, 3.0, 20, 5.2, 0.5, 0.5, DARK)
    for z in (17.2, 22.8):
        for wx in (-3.6, -1.2, 1.2, 3.6):
            m.cyl(-14 + wx, 0.1, z + (0.52 if z > 20 else -0.52), 0.5, 0.02, YELLOW, solid=False, sides=8, fill=True)
    for z in (17.2, 22.8):
        m.box(-14, 0, z, 9.6, 1.1, 1.0, DARK)
    m.box(24, 0, 20, 18, 0.25, 18, DARK)
    m.box(24, 0.25, 20, 10, 0.05, 1.6, ORANGE, solid=False)
    m.box(24, 0.25, 20, 1.6, 0.05, 10, ORANGE, solid=False)
    for x, z, w, d in [(-4, 34, 10, 1.4), (8, 28, 1.4, 8), (-30, 6, 12, 1.4), (-8, -4, 1.4, 10), (10, 2, 10, 1.4), (38, -6, 1.4, 12), (-40, 30, 8, 1.4), (0, -20, 12, 1.4)]:
        m.box(x, 0, z, w, 1.3, d, ORANGE)
    for i, (x, z) in enumerate([(4, -8), (5.6, -8), (4.8, -9.4), (-36, 18), (-34.4, 18), (40, 34), (41.6, 34)]):
        m.collider(x, 0, z, 1.2, 1.7, 1.2)
        m.cyl(x, 0, z, 0.62, 1.7, YELLOW if i % 3 == 1 else RED, solid=False)
        m.cyl(x, 0.8, z, 0.66, 0.12, DARK, solid=False, fill=True)
    for x, z in [(-24, 36), (14, 40), (36, 4), (-44, -6), (2, 12)]:
        m.box(x, 0, z, 2.4, 2.4, 2.4, GREEN)
    m.box(0, 0, -42, 1, 18, 1, DARK)
    m.box(0, 18, -42, 3.4, 0.4, 3.4, RED)
    m.ball(0, 18.4, -42, 1.3, YELLOW, squash=0.5)
    m.ball(22, 7.2, -34, 1.4, TEAL, squash=0.55)
    m.cyl(24, 0.26, 20, 4.2, 0.02, YELLOW, solid=False, sides=16)
    m.snipers.append([22, 7.2, -32])
    m.spawns += [[-36, 0, 46], [36, 0, 46], [-50, 0, 14], [50, 0, 14], [-50, 0, -22], [50, 0, -18], [-10, 0, -48], [10, 0, -48], [-50, 0, 30], [48, 0, 30], [-12, 0, 6], [12, 0, 12]]
    m.pickups += [[22, 7.2, -30], [-34, 4.4, -34], [-20, 4.4, -18], [24, 0.3, 20], [-14, 3.9, 20], [0, 0, 24], [0, 0, -10], [-27, 0, -26], [40, 0, -44], [-40, 0, 40]]
    m.arena += [[-36, 0, 46], [36, 0, 46], [-50, 0, 14], [50, 0, 14], [-50, 0, -22], [50, 0, -18], [22, 5, -37], [-34, 4.4, -34], [-20, 4.4, -18], [24, 0.3, 20], [-10, 0, -48], [10, 0, -48], [-12, 0, 6], [12, 0, 12], [-46, 8.5, -44]]
    for p in [(0, 12, 6), (-27, 11, -26), (22, 13, -14), (24, 12, 20), (-14, 10, 34), (0, 22, -34)]:
        m.ring(*p)
    # Tents, missiles on stands, drums, tyres, floodlights, pines, scrub and painted cones.
    m.scatter('tents', 7, lambda x, z, r: m.tent(x, z, r.choice([GREEN, LIME, TEAL])), 1.9)
    m.scatter('missiles', 7, lambda x, z, r: (m.cyl(x, 0, z, 0.45, 3.2, GREEN, sides=8, collide=0.9), m.cyl(x, 3.2, z, 0.45, 1.1, YELLOW, solid=False, top=0, sides=8, fill=True), m.cyl(x, 0, z, 0.8, 0.5, DARK, solid=False, top=0.45, sides=4)), 0.7)
    m.scatter('drums', 16, lambda x, z, r: m.barrel(x, z, r.choice([RED, YELLOW, TEAL, GREEN])))
    m.scatter('tyres', 10, lambda x, z, r: m.tires(x, z, 2 + r.randrange(3)), 0.7)
    m.scatter('lights', 8, lambda x, z, r: m.lamp(x, z, 6.5), 0.3)
    m.scatter('pines', 12, lambda x, z, r: m.pine(x, z, r.uniform(6, 9)), 0.6)
    m.scatter('rocks', 8, lambda x, z, r: m.rock(x, z, r.uniform(0.7, 1.3)), 1.1)
    m.scatter('scrub', 26, lambda x, z, r: m.bush(x, z, r.uniform(0.6, 1.1), r.choice([GREEN, LIME])), 1.2, solid=False)
    m.scatter('cones', 20, lambda x, z, r: m.traffic_cone(x, z), 0.4, solid=False)
    m.scatter('grass', 70, lambda x, z, r: m.grass(x, z), 0.2, solid=False)
    m.write()


if __name__ == '__main__':
    castle()
    harbor()
    pyramid()
    station()
    forest()
    school()
    military()

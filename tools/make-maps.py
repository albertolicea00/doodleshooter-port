#!/usr/bin/env python3
"""Generate the port's own maps (not part of the original game) in the same
JSON layout the reference extractor writes for District and Mexico.

Every piece is an axis-aligned box: one collider plus its faces merged into a
mesh per ink colour. Stairs are solid step blocks so the navigation mesh and
the player's step-up both work. Run: python3 tools/make-maps.py
"""
import json
from pathlib import Path

OUTPUT = Path(__file__).resolve().parent.parent / 'native/data'
BLUE, RED, DARK, ORANGE, GREEN, PINK = range(6)
FACES = [((1, 0, 0), [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]), ((-1, 0, 0), [(0, 0, 1), (0, 1, 1), (0, 1, 0), (0, 0, 0)]),
         ((0, 1, 0), [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)]), ((0, -1, 0), [(0, 0, 1), (0, 0, 0), (1, 0, 0), (1, 0, 1)]),
         ((0, 0, 1), [(1, 0, 1), (1, 1, 1), (0, 1, 1), (0, 0, 1)]), ((0, 0, -1), [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)])]


class Map:
    def __init__(self, key, half, start, wall=8.0):
        self.key, self.half, self.start = key, half, list(start)
        self.boxes, self.meshes = [], {}
        self.spawns, self.snipers, self.pickups, self.arena, self.rings = [], [], [], [], []
        self.box(0, -1, 0, half * 2, 1, half * 2)
        for x, z, w, d in [(0, -half, half * 2, 1), (0, half, half * 2, 1), (-half, 0, 1, half * 2), (half, 0, 1, half * 2)]:
            self.box(x, 0, z, w, wall, d)

    def box(self, x, y, z, w, h, d, ink=BLUE, solid=True):
        """Box centred on x/z with its base at y."""
        low, high = [x - w / 2, y, z - d / 2], [x + w / 2, y + h, z + d / 2]
        if solid:
            self.boxes.append({'min': low, 'max': high, 'no_grapple': False, 'no_shoot': False, 'breakable': -1})
        mesh = self.meshes.setdefault(ink, {'vertices': [], 'normals': []})
        for normal, corners in FACES:
            for i in (0, 2, 1, 0, 3, 2):
                mesh['vertices'] += [round(low[a] + (high[a] - low[a]) * corners[i][a], 3) for a in range(3)]
                mesh['normals'] += normal

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
                     'ink': ink, 'fill': False, 'shade': [1, 0], 'children': []} for ink, mesh in sorted(self.meshes.items())]
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
    for wx, wz, w, d in [(0, -1.4, 3.4, 0.6), (0, 1.4, 3.4, 0.6), (-1.4, 0, 0.6, 2.2), (1.4, 0, 0.6, 2.2)]:
        m.box(22 + wx, 0, -32 + wz, w, 1.1, d, DARK)
    m.box(-20, 0, -30, 8, 3.2, 5)
    m.box(-20, 3.2, -30, 9, 0.4, 6, RED)
    m.snipers.append([0, 8, -3])
    m.spawns += [[-38, 0, 28], [38, 0, 28], [-38, 0, -8], [38, 0, -8], [-14, 0, -38], [14, 0, -38], [-38, 0, 8], [38, 0, 8], [-30, 0, 38], [30, 0, 38], [0, 0, -26], [-12, 0, 26]]
    m.pickups += [[0, 8, -2], [-30, 0, 0], [30, 0, 0], [0, 0, -30], [0, 5, -47], [-47, 5, 0], [47, 5, 0], [0, 0, 28], [22, 0, -26], [-20, 3.6, -30]]
    m.arena += [[-38, 0, 28], [38, 0, 28], [-38, 0, -30], [38, 0, -30], [0, 8, -3], [0, 5, -47], [-47, 5, 10], [47, 5, -10], [0, 0, 34], [-14, 0, -38], [14, 0, -38], [-30, 0, 4], [30, 0, 4], [-44, 10, -44], [44, 10, 44]]
    for p in [(0, 15, 12), (-26, 11, -26), (26, 11, -26), (-26, 11, 26), (26, 11, 26)]:
        m.ring(*p)
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
        m.box(x, 0, 47, 1, 1, 1, DARK)
    for x, z in [(-8, 34), (10, 36), (30, 34), (14, -10), (-22, -4)]:
        m.box(x, 0, z, 2, 2, 2, ORANGE)
    m.spawns += [[-46, 0, -10], [46, 0, 24], [-46, 0, 20], [46, 0, -10], [-14, 0, -23], [30, 0, -23], [0, 0, 3], [-30, 0, 16], [32, 0, 16], [16, 0, 44], [-12, 0, 44], [46, 0, 44]]
    m.pickups += [[-6, 8.4, -30], [0, 16, 24], [-38, 6, 34], [22, 8, -42], [0, 0, 16], [30, 0, 3], [-28, 0, -10], [16, 0, -23], [-46, 0, 0], [46, 0, 36]]
    m.arena += [[-46, 0, -10], [46, 0, 24], [-46, 0, 20], [46, 0, -10], [-6, 8.4, -30], [39, 8.4, -17], [9, 8.4, -4], [0, 16, 24], [-38, 6, 33], [19, 8, -44], [0, 0, 3], [16, 0, 44], [-12, 0, 44], [30, 0, -23], [-14, 0, -23]]
    for p in [(0, 12, 6), (-20, 11, -10), (26, 11, -4), (-30, 10, 24), (30, 19, 24), (6, 12, -36)]:
        m.ring(*p)
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
        m.box(x, 11, z, 1.4, 1.6, 1.4, ORANGE)
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
                m.box(cx + px, 1.2, z + side * 2.6, 0.6, 3.8, 0.6, DARK)
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
    m.box(40, 12.5, -38.4, 3, 3, 0.2, ORANGE, solid=False)
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
    m.write()


def forest():
    m = Map('forest', 54, (0, 0, 44), wall=6)
    # Trees: a dark trunk with two green canopy blocks; trunks block shots, canopies can be stood on.
    trees = [(-40, 36), (-28, 40), (-44, 18), (-34, 8), (-46, -6), (-38, -22), (-44, -40), (-26, -44), (-20, 26), (-16, 6), (-24, -10),
             (-10, -30), (40, 36), (28, 42), (46, 20), (34, 12), (44, -4), (36, -20), (46, -38), (28, -44), (18, 28), (20, -8), (10, -34),
             (4, 26), (-6, -44), (8, -16), (-30, 24), (30, -32)]
    for i, (x, z) in enumerate(trees):
        height = 5 + (i * 7) % 4
        m.box(x, 0, z, 1.2, height, 1.2, DARK)
        m.box(x, height, z, 5.2, 1.6, 5.2, GREEN)
        m.box(x, height + 1.6, z, 3.2, 1.4, 3.2, GREEN)
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
        m.box(x, 0, z, size, size * 0.7, size, DARK)
    m.spawns += [[-49, 0, 46], [49, 0, 46], [-49, 0, 0], [49, 0, 4], [-49, 0, -46], [49, 0, -46], [-18, 0, -48], [18, 0, -48], [-49, 0, 28], [49, 0, -14], [-12, 0, 30], [12, 0, -4]]
    m.pickups += [[25, 9.5, 18], [-6, 6.1, 3], [0, 1.0, -24], [-30, 0, 0], [34, 0, 0], [0, 0, 16], [-20, 0, -40], [20, 0, -40], [-44, 0, 30], [44, 0, 30]]
    m.arena += [[-49, 0, 46], [49, 0, 46], [-49, 0, -46], [49, 0, -46], [25, 9.5, 16], [-6, 6.1, 2], [0, 1.0, -24], [-49, 0, 0], [49, 0, 4], [-18, 0, -48], [18, 0, -48], [-12, 0, 30], [12, 0, -4], [34, 0, 0], [-30, 0, 0]]
    for p in [(0, 12, 22), (-24, 12, -4), (22, 13, -14), (-36, 12, 30), (38, 12, -30), (6, 11, -36)]:
        m.ring(*p)
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
        m.box(x, 0, 24, 0.5, 4, 0.5, DARK)
        m.box(x + (0.9 if x < -28 else -0.9), 3.2, 24, 1.4, 1.2, 2.2, RED)
    m.box(28, 0.6, 30, 16, 3.4, 4, ORANGE)
    m.box(28, 4.0, 30, 15, 0.3, 3.4, DARK)
    for wx in (-5.5, 5.5):
        m.box(28 + wx, 0, 30, 2.4, 0.6, 3.6, DARK)
    for x, z in [(22, 12), (30, 12), (22, 18), (30, 18)]:
        m.box(x, 0, z, 0.5, 4.4, 0.5, PINK)
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
        m.box(-14, 0, z, 9.6, 1.1, 1.0, DARK)
    m.box(24, 0, 20, 18, 0.25, 18, DARK)
    m.box(24, 0.25, 20, 10, 0.05, 1.6, ORANGE, solid=False)
    m.box(24, 0.25, 20, 1.6, 0.05, 10, ORANGE, solid=False)
    for x, z, w, d in [(-4, 34, 10, 1.4), (8, 28, 1.4, 8), (-30, 6, 12, 1.4), (-8, -4, 1.4, 10), (10, 2, 10, 1.4), (38, -6, 1.4, 12), (-40, 30, 8, 1.4), (0, -20, 12, 1.4)]:
        m.box(x, 0, z, w, 1.3, d, ORANGE)
    for x, z in [(4, -8), (5.6, -8), (4.8, -9.4), (-36, 18), (-34.4, 18), (40, 34), (41.6, 34)]:
        m.box(x, 0, z, 1.2, 1.7, 1.2, RED)
    for x, z in [(-24, 36), (14, 40), (36, 4), (-44, -6), (2, 12)]:
        m.box(x, 0, z, 2.4, 2.4, 2.4, GREEN)
    m.box(0, 0, -42, 1, 18, 1, DARK)
    m.box(0, 18, -42, 3.4, 0.4, 3.4, RED)
    m.snipers.append([22, 7.2, -32])
    m.spawns += [[-36, 0, 46], [36, 0, 46], [-50, 0, 14], [50, 0, 14], [-50, 0, -22], [50, 0, -18], [-10, 0, -48], [10, 0, -48], [-50, 0, 30], [48, 0, 30], [-12, 0, 6], [12, 0, 12]]
    m.pickups += [[22, 7.2, -30], [-34, 4.4, -34], [-20, 4.4, -18], [24, 0.3, 20], [-14, 3.9, 20], [0, 0, 24], [0, 0, -10], [-27, 0, -26], [40, 0, -44], [-40, 0, 40]]
    m.arena += [[-36, 0, 46], [36, 0, 46], [-50, 0, 14], [50, 0, 14], [-50, 0, -22], [50, 0, -18], [22, 5, -37], [-34, 4.4, -34], [-20, 4.4, -18], [24, 0.3, 20], [-10, 0, -48], [10, 0, -48], [-12, 0, 6], [12, 0, 12], [-46, 8.5, -44]]
    for p in [(0, 12, 6), (-27, 11, -26), (22, 13, -14), (24, 12, 20), (-14, 10, 34), (0, 22, -34)]:
        m.ring(*p)
    m.write()


if __name__ == '__main__':
    castle()
    harbor()
    pyramid()
    station()
    forest()
    school()
    military()

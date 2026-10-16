"""Build the locations as low-poly cartoon GLBs.

    blender --background --factory-startup --python blender/build_world.py [-- --preview DIR] [-- --only office,street]

All layout numbers in this file are GODOT coordinates (x right, y up, z toward
the viewer / "south"). The wrappers convert to Blender (x, -z, y) so the
positions written here are the same numbers the .tscn scenes use for spawns,
interactables and NPCs. Yaw is degrees about Godot +Y (same sign as Blender Z).

Naming: "-col" suffix = mesh + trimesh collision, "-colonly" = invisible
collision, "Arch_" prefix = architecture (no outline in the toon kit).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402

import lib  # noqa: E402

# ---------------------------------------------------------------- godot-space wrappers

_count = {}


def nm(base, col=False, arch=False, only=False):
    n = _count.get(base, 0)
    _count[base] = n + 1
    name = ("Arch_" if arch else "") + base + ("_%d" % n if n else "")
    if only:
        return name
    return name + ("-col" if col else "")


def P(g):
    return (g[0], -g[2], g[1])


def S(g):
    return (g[0], g[2], g[1])


class Frame:
    """A local frame on the floor: origin (x, z) and yaw. Local +z is 'front'."""

    def __init__(self, x=0.0, z=0.0, yaw=0.0, y=0.0):
        self.x, self.z, self.yaw, self.y = x, z, yaw, y
        self.c = math.cos(math.radians(yaw))
        self.s = math.sin(math.radians(yaw))

    def at(self, lx, ly, lz):
        return (self.x + lx * self.c + lz * self.s, self.y + ly, self.z - lx * self.s + lz * self.c)

    def sub(self, lx, lz, yaw=0.0):
        p = self.at(lx, 0, lz)
        return Frame(p[0], p[2], self.yaw + yaw, self.y)


WORLD = Frame()


def box(base, size, pos, color, f=WORLD, yaw=0.0, tilt=0.0, col=False, arch=False, bevel=0.02, **kw):
    return lib.rbox(nm(base, col, arch), S(size), P(f.at(*pos)), color, bevel=bevel,
                    rot=(tilt, 0, f.yaw + yaw), **kw)


def fbox(base, size, lx, lz, color, f=WORLD, y0=0.0, **kw):
    """Box standing on y0."""
    return box(base, size, (lx, y0 + size[1] * 0.5, lz), color, f=f, **kw)


def cyl(base, r, h, pos, color, f=WORLD, segs=12, r2=None, col=False, tilt=0.0, yaw=0.0, **kw):
    return lib.cyl(nm(base, col), r, h, P(f.at(*pos)), color, segs=segs, radius2=r2,
                   rot=(tilt, 0, f.yaw + yaw), **kw)


def ball(base, r, pos, color, f=WORLD, scale=(1, 1, 1), segs=10, rings=7, smooth=False, **kw):
    # scale is godot (x, y, z)
    return lib.ball(nm(base), r, P(f.at(*pos)), color, scale=(scale[0], scale[2], scale[1]), segs=segs,
                    rings=rings, smooth=smooth, rot=(0, 0, f.yaw), **kw)


def col(base, size, pos, f=WORLD, yaw=0.0):
    return lib.collider(nm(base, only=True), S(size), P(f.at(*pos)), rot=(0, 0, f.yaw + yaw))


def fcol(base, size, lx, lz, f=WORLD, y0=0.0, yaw=0.0):
    return col(base, size, (lx, y0 + size[1] * 0.5, lz), f=f, yaw=yaw)


def marker(name, pos, yaw=0.0):
    lib.empty(name, P(pos), rot=(0, 0, yaw))


# ---------------------------------------------------------------- palette

C = dict(
    white="#f4f1ea", offwhite="#ece6d8", cream="#efe6d2", grey="#8a8f98", dark="#2a2d34", black="#16171b",
    steel="#b9c0ca", glass="#bfe6ff", screen="#7fd3ff", green="#4fb35a", leaf="#3f9e4d", leaf2="#62c26a",
    pot="#d9774b", wood="#b9824f", darkwood="#6e3d27", gold="#e8b739", teal="#4fae9f", navy="#2d3b55",
    red="#d8434b", orange="#f08a2c", yellow="#ffd34d", pink="#f07aa0", purple="#8b5bd6", sky="#6fb7e8",
    asphalt="#3c3e45", sidewalk="#c9c1b2", curb="#9b968c", tile="#eef1f2", line2="#33a23d",
)


# ---------------------------------------------------------------- shared props

def plant(f, lx, lz, big=True, collide=True):
    h = 0.55 if big else 0.32
    cyl("pot", 0.30 if big else 0.18, h, (lx, h / 2, lz), C["pot"], f=f, r2=0.24 if big else 0.15, segs=10)
    s = 1.0 if big else 0.55
    for i, (dx, dy, dz, r) in enumerate(((0, 0.9, 0, 0.42), (0.18, 1.25, 0.1, 0.32), (-0.2, 1.2, -0.08, 0.3), (0.02, 1.55, 0, 0.24))):
        ball("leaf", r * s, (lx + dx * s, dy * s, lz + dz * s), C["leaf"] if i % 2 else C["leaf2"], f=f, segs=7, rings=5)
    if collide:
        fcol("plant", (0.6 * s, 1.2 * s, 0.6 * s), lx, lz, f=f)


def office_chair(f, color=None):
    color = color or C["navy"]
    fbox("chair_seat", (0.52, 0.10, 0.50), 0, 0, color, f=f, y0=0.44, bevel=0.04)
    box("chair_back", (0.50, 0.58, 0.08), (0, 0.90, 0.24), color, f=f, bevel=0.04, tilt=-6)
    cyl("chair_post", 0.035, 0.38, (0, 0.25, 0), C["grey"], f=f, segs=8)
    cyl("chair_base", 0.30, 0.05, (0, 0.06, 0), C["dark"], f=f, segs=5)
    fcol("chair", (0.5, 0.9, 0.5), 0, 0, f=f)


def monitor(f, lx, lz, glow=0.7, screen=None):
    box("mon_stand", (0.08, 0.22, 0.06), (lx, 0.88, lz - 0.02), C["dark"], f=f)
    box("mon_bezel", (0.64, 0.40, 0.05), (lx, 1.13, lz), C["black"], f=f, bevel=0.015)
    box("mon_screen", (0.57, 0.33, 0.01), (lx, 1.13, lz + 0.026), screen or C["screen"], f=f, bevel=0.0, glow=glow)


def desk(f, kind="plain"):
    """Desk centred at f; the sitter is at local +z facing -z."""
    fbox("desk_top", (1.6, 0.06, 0.8), 0, 0, C["white"], f=f, y0=0.71, bevel=0.015)
    for sx in (-1, 1):
        fbox("desk_leg", (0.05, 0.71, 0.74), sx * 0.76, 0, C["grey"], f=f)
    fbox("desk_modesty", (1.48, 0.40, 0.03), 0, -0.36, C["grey"], f=f, y0=0.25)
    monitor(f, 0, -0.22, screen="#9fe0ff" if kind != "taeyang" else "#2b3240", glow=0.8 if kind != "taeyang" else 0.0)
    fbox("keyboard", (0.46, 0.025, 0.15), 0, 0.10, C["dark"], f=f, y0=0.77, bevel=0.008)
    fbox("mouse", (0.06, 0.03, 0.10), 0.36, 0.12, C["dark"], f=f, y0=0.77, bevel=0.012)
    fcol("desk", (1.6, 0.77, 0.8), 0, 0, f=f)
    if kind == "mine":
        # The pile. It only grows.
        for i in range(7):
            fbox("paper", (0.32, 0.035, 0.24), -0.56 + random.uniform(-0.03, 0.03), -0.05 + random.uniform(-0.03, 0.03),
                 C["white"] if i % 2 else "#fff7c9", f=f, y0=0.77 + i * 0.035, yaw=random.uniform(-14, 14), bevel=0.004)
        cyl("energy_drink", 0.035, 0.14, (0.55, 0.84, -0.12), "#ff4fa3", f=f, segs=8)
        cyl("energy_drink", 0.035, 0.14, (0.63, 0.84, -0.02), "#ffde3a", f=f, segs=8)
        cyl("cactus_pot", 0.06, 0.08, (0.66, 0.81, -0.28), C["pot"], f=f, segs=8)
        ball("cactus", 0.07, (0.66, 0.92, -0.28), "#7a9a52", f=f, scale=(1, 1.5, 1), segs=7, rings=5)
        box("photo", (0.16, 0.13, 0.02), (-0.30, 0.85, -0.30), C["gold"], f=f, tilt=-10)
        box("photo_pic", (0.13, 0.10, 0.005), (-0.30, 0.85, -0.288), "#9fd0ff", f=f, tilt=-10)
    elif kind == "sora":
        # Immaculate. Award. Labelled stapler.
        cyl("trophy_base", 0.06, 0.05, (0.58, 0.79, -0.2), C["dark"], f=f)
        cyl("trophy_cup", 0.06, 0.14, (0.58, 0.89, -0.2), C["gold"], f=f, r2=0.03, glow=0.2)
        fbox("stapler", (0.06, 0.05, 0.18), -0.55, 0.0, C["pink"], f=f, y0=0.77)
        cyl("mug", 0.045, 0.1, (-0.4, 0.82, -0.15), C["white"], f=f, segs=10)
    elif kind == "taeyang":
        fbox("sticky", (0.08, 0.08, 0.005), 0.0, -0.20, C["yellow"], f=f, y0=1.0, bevel=0.0)
        plant(f.sub(0.55, -0.2), 0, 0, big=False, collide=False)
    else:
        cyl("mug", 0.045, 0.1, (0.55, 0.82, -0.1), random.choice([C["white"], C["red"], C["sky"]]), f=f, segs=10)
        for i in range(random.randint(0, 3)):
            fbox("paper", (0.30, 0.03, 0.22), -0.55, 0.0, C["white"], f=f, y0=0.77 + i * 0.03, yaw=random.uniform(-10, 10), bevel=0.004)


def cluster(cx, cz, kinds=("plain", "plain", "plain", "plain")):
    """2x2 desks facing each other across a divider. kinds: NW, NE, SW, SE."""
    seats = [(-0.8, -0.4, 180), (0.8, -0.4, 180), (-0.8, 0.4, 0), (0.8, 0.4, 0)]
    for (dx, dz, yaw), kind in zip(seats, kinds):
        f = Frame(cx + dx, cz + dz, yaw)
        desk(f, kind)
        if kind != "taeyang":
            office_chair(f.sub(0, 0.62))
        else:
            office_chair(f.sub(0.15, 0.75, yaw=25), color="#55627a")
    fbox("divider", (3.3, 0.55, 0.05), cx, cz, C["teal"], y0=0.74, bevel=0.015)


def glass_wall(x0, z0, x1, z1, door=None, h=3.0):
    """Glass partition from (x0,z0) to (x1,z1). door=(a, b) gap along the wall, in metres from start."""
    L = math.hypot(x1 - x0, z1 - z0)
    yaw = -math.degrees(math.atan2(z1 - z0, x1 - x0))
    f = Frame(x0, z0, yaw)
    segs = [(0.0, L)]
    if door:
        segs = [(0.0, door[0]), (door[1], L)]
        fbox("door_head", (door[1] - door[0], 0.25, 0.10), (door[0] + door[1]) / 2, 0, C["dark"], f=f, y0=2.25)
        fbox("glass", (door[1] - door[0], h - 2.5, 0.02), (door[0] + door[1]) / 2, 0, C["glass"], f=f, y0=2.5, alpha=0.22, bevel=0)
    for a, b in segs:
        n = max(1, int(round((b - a) / 1.5)))
        for i in range(n + 1):
            fbox("glass_post", (0.07, h, 0.07), a + (b - a) * i / n, 0, C["dark"], f=f)
        fbox("glass", (b - a, h, 0.02), (a + b) / 2, 0, C["glass"], f=f, alpha=0.20, bevel=0)
        fbox("glass_rail", (b - a, 0.08, 0.06), (a + b) / 2, 0, C["dark"], f=f, y0=0.0)
        fbox("glass_band", (b - a, 0.10, 0.025), (a + b) / 2, 0, "#ffffff", f=f, y0=1.2, alpha=0.6, bevel=0)
        fcol("glasswall", (b - a, h, 0.12), (a + b) / 2, 0, f=f)


def skyline(seed, z_near, z_far, x_span, ground=-45.0, night=False, count=46):
    """Distant city blocks joined into one mesh."""
    rnd = random.Random(seed)
    parts = []
    cols = ["#7d8ea6", "#9aa8bb", "#6c7a90", "#b4bfcc", "#8796ab", "#a6b5c7"] if not night else \
        ["#2b3350", "#323b5c", "#262c45", "#3a4466"]
    win = "#fff1b8" if night else "#d6efff"
    for i in range(count):
        w = rnd.uniform(8, 18)
        d = rnd.uniform(8, 16)
        x = rnd.uniform(-x_span, x_span)
        z = rnd.uniform(z_near, z_far)
        top = rnd.uniform(5, 55) if not night else rnd.uniform(4, 40)
        h = top - ground
        c = rnd.choice(cols)
        parts.append(lib.rbox(nm("Arch_sky"), S((w, h, d)), P((x, ground + h / 2, z)), c, bevel=0.0))
        # window bands facing the viewer (+z side)
        bands = int(h / 4.5)
        for j in range(bands):
            if rnd.random() < (0.55 if night else 0.8):
                y = ground + 3 + j * 4.5
                if y > top - 2:
                    break
                parts.append(lib.rbox(nm("Arch_skywin"), S((w * 0.86, 1.4, 0.2)), P((x, y, z + d / 2 + 0.05)), win,
                                      bevel=0.0, glow=1.2 if night else 0.0))
        if rnd.random() < 0.3:
            parts.append(lib.rbox(nm("Arch_skytop"), S((w * 0.4, 3, d * 0.4)), P((x, top + 1.5, z)), c, bevel=0.0))
    for p in parts:
        lib.apply_transform(p)
    return lib.join(parts, "Arch_Skyline")


# ---------------------------------------------------------------- OFFICE

def build_office():
    random.seed(14)
    W, D, H = 24.0, 18.0, 3.2  # x [-12,12], z [-9,9]
    # floor, ceiling, walls
    fbox("Floor", (W, 0.2, D), 0, 0, "#9fb0c4", y0=-0.2, col=True, arch=True, bevel=0)
    fbox("Aisle", (2.4, 0.01, 14), 0.75, 1.0, "#8b9db3", arch=True, bevel=0)
    fbox("Aisle", (20, 0.01, 1.6), -0.5, 2.25, "#8b9db3", arch=True, bevel=0)
    fbox("Ceiling", (W, 0.12, D), 0, 0, "#f3f1ea", y0=H, col=True, arch=True, bevel=0)
    wall = "#efe8d8"
    fbox("WallW", (0.3, H, D), -12.15, 0, wall, col=True, arch=True, bevel=0)
    fbox("WallE", (0.3, H, D), 12.15, 0, wall, col=True, arch=True, bevel=0)
    # south wall with elevator opening at x [-9.2, -6.8]
    fbox("WallS", (12 + 6.8, H, 0.3), (12 + -6.8) / 2, 9.15, wall, col=True, arch=True, bevel=0)
    fbox("WallS", (2.8, H, 0.3), (-12 - 9.2) / 2, 9.15, wall, col=True, arch=True, bevel=0)
    fbox("WallS", (2.4, H - 2.4, 0.3), -8.0, 9.15, wall, y0=2.4, arch=True, bevel=0)
    fbox("Skirting", (W, 0.12, 0.04), 0, 8.99, "#c9bfa7", arch=True, bevel=0)
    # north window wall z=-9 with balcony door gap x [2, 4]
    for a, b in ((-12.0, 2.0), (4.0, 12.0)):
        fbox("Sill", (b - a, 0.5, 0.3), (a + b) / 2, -9.15, "#d7cfbc", col=True, arch=True, bevel=0)
    fbox("Header", (W, 0.35, 0.3), 0, -9.15, "#d7cfbc", y0=H - 0.35, arch=True, bevel=0)
    for x in [-12 + i * 2.0 for i in range(13)]:
        if 2.0 <= x <= 4.0:
            continue
        fbox("Mullion", (0.12, H, 0.2), x, -9.1, C["dark"])
    fbox("Mullion", (0.14, H, 0.22), 2.0, -9.1, C["dark"])
    fbox("Mullion", (0.14, H, 0.22), 4.0, -9.1, C["dark"])
    for a, b in ((-12.0, 2.0), (4.0, 12.0)):
        fbox("WinGlass", (b - a, H - 0.85, 0.03), (a + b) / 2, -9.1, C["glass"], y0=0.5, alpha=0.16, bevel=0)
        fcol("WinWall", (b - a, H, 0.4), (a + b) / 2, -9.15)
    fbox("BalconyDoorFrame", (2.0, 0.15, 0.22), 3.0, -9.1, C["dark"], y0=2.4)
    fbox("WinGlass", (2.0, H - 2.55, 0.03), 3.0, -9.1, C["glass"], y0=2.55, alpha=0.16, bevel=0)
    fbox("DoorMat", (1.6, 0.02, 0.9), 3.0, -8.4, "#7a5a3a", bevel=0.01)

    # ceiling light panels
    for x in (-9, -4.5, 0, 4.5, 9):
        for z in (-6, -1.5, 3, 7):
            fbox("CeilLight", (1.6, 0.04, 0.6), x, z, "#fffdf2", y0=H - 0.04, glow=2.0, bevel=0)

    # pillars
    for x, z in ((-4.0, 2.25), (1.0, 2.25), (6.5, 2.25)):
        fbox("Pillar", (0.6, H, 0.6), x, z, "#e3dccb", col=True, bevel=0.02)
        fbox("PillarBand", (0.62, 0.25, 0.62), x, z, C["teal"], y0=1.6, bevel=0.01)

    # open-plan clusters
    cluster(-6.5, 0.0)
    cluster(-1.5, 0.0)
    cluster(3.5, 0.0)
    cluster(-6.5, 4.5)
    cluster(-1.5, 4.5)
    cluster(3.5, 4.5, kinds=("sora", "taeyang", "plain", "mine"))
    marker("Mk_JonaidDesk", (4.3, 0, 5.52), 0)

    # Park's glass box (NW): x [-12,-5], z [-9,-3]
    glass_wall(-5.0, -9.0, -5.0, -3.0)
    glass_wall(-12.0, -3.0, -5.0, -3.0, door=(4.6, 5.9))
    fbox("ParkCarpet", (6.6, 0.015, 5.7), -8.5, -6.0, "#8d3b3b", bevel=0)
    pf = Frame(-8.5, -6.6, 0)  # Park sits at -z side facing +z (toward the door)
    fbox("ParkDesk", (2.6, 0.10, 1.1), 0, 0, C["darkwood"], f=pf, y0=0.74, bevel=0.03)
    fbox("ParkDeskBody", (2.5, 0.74, 0.9), 0, -0.05, "#5a3020", f=pf, bevel=0.02)
    fcol("ParkDesk", (2.6, 0.85, 1.1), 0, 0, f=pf)
    fbox("ParkPlate", (0.5, 0.10, 0.08), 0, 0.5, C["gold"], f=pf, y0=0.84, glow=0.1)
    monitor(Frame(-8.5, -6.85, 180), 0, 0, glow=0.6)
    office_chair(Frame(-8.5, -7.6, 180), color="#3a1f18")
    box("ParkChairWing", (0.7, 0.9, 0.12), (-8.5, 1.15, -7.95), "#3a1f18", bevel=0.05)
    fbox("Bookshelf", (2.4, 2.2, 0.45), -8.5, -8.7, C["darkwood"], col=True)
    for i, c in enumerate([C["red"], C["navy"], C["gold"], C["green"], C["red"], C["navy"], "#e2e2e2", C["gold"]]):
        fbox("Book", (0.18, 0.32, 0.30), -9.5 + i * 0.27, -8.6, c, y0=1.15 + (i % 2) * 0.55, bevel=0.01)
    cyl("Trophy", 0.12, 0.35, (-7.6, 1.95, -8.6), C["gold"], r2=0.05, glow=0.15)
    fbox("PuttMat", (0.7, 0.02, 3.2), -11.0, -5.6, "#47a35a", bevel=0)
    cyl("PuttCup", 0.06, 0.01, (-11.0, 0.03, -6.9), C["black"], segs=10)
    ball("GolfBall", 0.04, (-11.0, 0.05, -4.4), "#ffffff", segs=8, rings=6)
    box("Motto", (1.6, 0.8, 0.05), (-11.95 + 0.04, 1.8, -6.0), C["gold"], yaw=90)
    box("MottoPaper", (1.45, 0.65, 0.02), (-11.95 + 0.08, 1.8, -6.0), "#fffaf0", yaw=90)
    plant(WORLD, -5.6, -8.4)
    fbox("ParkSofa", (0.8, 0.45, 1.8), -11.4, -4.0, "#3a1f18", col=True, bevel=0.08)
    marker("Mk_ParkChair", (-8.5, 0, -7.55), 0)

    # meeting room (NE): x [6,12], z [-9,-3]
    glass_wall(6.0, -9.0, 6.0, -3.0)
    glass_wall(6.0, -3.0, 12.0, -3.0, door=(1.0, 2.3))
    fbox("MeetTable", (3.2, 0.08, 1.3), 9.0, -6.2, C["white"], y0=0.72, bevel=0.03)
    fbox("MeetTableBase", (0.5, 0.72, 0.5), 9.0, -6.2, C["grey"])
    fcol("MeetTable", (3.2, 0.8, 1.3), 9.0, -6.2)
    for i in range(3):
        office_chair(Frame(8.0 + i, -5.2, 0), color="#d3d7de")
        office_chair(Frame(8.0 + i, -7.2, 180), color="#d3d7de")
    fbox("MeetTV", (2.0, 1.15, 0.08), 11.85, -6.2, C["black"], y0=1.0, yaw=90)
    fbox("MeetTVScreen", (1.85, 1.0, 0.01), 11.80, -6.2, "#3b6db3", y0=1.07, yaw=90, glow=0.5)

    # print corner (west wall)
    cf = Frame(-11.2, 2.5, 90)  # copier faces +x
    fbox("Copier", (1.15, 1.0, 0.8), 0, 0, "#dfe2e6", f=cf, col=True, bevel=0.04)
    fbox("CopierLid", (1.15, 0.12, 0.8), 0, 0, "#b9bec6", f=cf, y0=1.0, bevel=0.03)
    fbox("CopierPanel", (0.36, 0.06, 0.22), 0.3, 0.32, "#45c2ff", f=cf, y0=1.0, glow=0.8, bevel=0.01)
    for i in range(3):
        fbox("CopierTray", (1.0, 0.02, 0.02), 0, 0.41, C["grey"], f=cf, y0=0.25 + i * 0.22, bevel=0)
    fbox("CopierOut", (0.35, 0.05, 0.5), 0.75, 0, "#b9bec6", f=cf, y0=0.75, bevel=0.01)
    fbox("Shredder", (0.5, 0.75, 0.4), -11.55, 4.2, C["dark"], col=True, bevel=0.03)
    fbox("ShredderSlot", (0.36, 0.02, 0.05), -11.55, 4.2, C["black"], y0=0.75, bevel=0)
    for i in range(4):
        fbox("PaperBox", (0.45, 0.28, 0.32), -11.6, 5.3 + (i % 2) * 0.05, "#f0e2c0", y0=(i // 2) * 0.28, yaw=random.uniform(-8, 8), col=(i < 2))
    fbox("StampTable", (1.4, 0.06, 0.7), -11.4, 0.4, C["wood"], y0=0.72, bevel=0.02)
    for sx in (-0.6, 0.6):
        fbox("StampTableLeg", (0.06, 0.72, 0.06), -11.4, 0.4 + sx, C["grey"])
    fcol("StampTable", (0.7, 0.8, 1.4), -11.4, 0.4)
    cyl("Inkpad", 0.08, 0.03, (-11.35, 0.79, 0.1), "#c5303a", segs=10)
    cyl("Dojang", 0.025, 0.09, (-11.35, 0.82, 0.55), "#d2a85a", segs=8)

    # pantry (east wall)
    fbox("Counter", (0.8, 0.92, 4.0), 11.55, 2.4, C["white"], col=True, bevel=0.02)
    fbox("CounterTop", (0.85, 0.05, 4.05), 11.55, 2.4, "#56606e", y0=0.92, bevel=0.01)
    fbox("CoffeeMachine", (0.45, 0.55, 0.42), 11.6, 1.2, C["black"], y0=0.97, bevel=0.04)
    fbox("CoffeeMachineFace", (0.02, 0.18, 0.25), 11.36, 1.2, C["red"], y0=1.25, bevel=0, glow=0.6)
    cyl("CoffeeCup", 0.04, 0.08, (11.45, 1.05, 1.2), C["white"], segs=8)
    fbox("Microwave", (0.5, 0.32, 0.4), 11.6, 2.4, "#cfd3d8", y0=0.97, bevel=0.02)
    fbox("SnackBasket", (0.4, 0.12, 0.3), 11.55, 3.4, C["wood"], y0=0.97, bevel=0.02)
    for i, c in enumerate((C["red"], C["yellow"], C["orange"], C["pink"])):
        fbox("Snack", (0.1, 0.14, 0.04), 11.45 + (i % 2) * 0.12, 3.35 + (i // 2) * 0.1, c, y0=1.03, bevel=0.01)
    fbox("WaterCooler", (0.38, 1.0, 0.38), 11.6, 5.0, C["white"], col=True, bevel=0.04)
    cyl("WaterBottle", 0.16, 0.5, (11.6, 1.28, 5.0), "#7cc7ff", segs=12, alpha=0.65)
    fbox("Fridge", (0.75, 1.8, 0.75), 11.55, -0.2, "#e8ecef", col=True, bevel=0.05)

    # balcony (outside the north wall): x [-1, 7], z [-13, -9]
    fbox("BalconyFloor", (8.0, 0.2, 4.2), 3.0, -11.1, "#b8b3a8", y0=-0.2, col=True, arch=True, bevel=0)
    fbox("BalconySlabEdge", (8.2, 0.35, 0.2), 3.0, -13.25, "#a19c91", y0=-0.35, bevel=0)
    for x in [-1.0 + i * 0.5 for i in range(17)]:
        fbox("RailBar", (0.04, 1.05, 0.04), x, -13.1, C["dark"], bevel=0)
    for z in [-13.1 + i * 0.5 for i in range(9)]:
        fbox("RailBar", (0.04, 1.05, 0.04), -1.0, z, C["dark"], bevel=0)
        fbox("RailBar", (0.04, 1.05, 0.04), 7.0, z, C["dark"], bevel=0)
    fbox("RailTop", (8.1, 0.06, 0.1), 3.0, -13.1, C["dark"], y0=1.05)
    fbox("RailTop", (0.1, 0.06, 4.1), -1.0, -11.05, C["dark"], y0=1.05)
    fbox("RailTop", (0.1, 0.06, 4.1), 7.0, -11.05, C["dark"], y0=1.05)
    fcol("Rail", (8.2, 1.4, 0.2), 3.0, -13.1)
    fcol("Rail", (0.2, 1.4, 4.2), -1.0, -11.0)
    fcol("Rail", (0.2, 1.4, 4.2), 7.0, -11.0)
    cyl("Ashtray", 0.16, 0.95, (5.6, 0.475, -12.4), C["steel"], segs=10, col=True)
    cyl("AshtrayTop", 0.2, 0.06, (5.6, 0.97, -12.4), C["dark"], segs=10)
    for i in range(5):
        cyl("Butt", 0.01, 0.04, (5.5 + i * 0.05, 1.01, -12.38 + (i % 2) * 0.05), "#f2e3c6", segs=6, tilt=80)
    fbox("ACUnit", (0.9, 0.65, 0.35), 0.0, -12.6, "#eceae4", col=True, bevel=0.03)
    cyl("ACFan", 0.24, 0.03, (0.0, 0.33, -12.42), C["dark"], segs=12, tilt=90)
    fbox("Stool", (0.35, 0.42, 0.35), 4.6, -12.5, C["red"], bevel=0.04)
    plant(WORLD, 6.4, -12.5, big=False)
    plant(WORLD, -0.4, -9.8, big=False)

    # elevator (south wall)
    fbox("ElevFrame", (2.8, 2.6, 0.12), -8.0, 9.02, "#9aa1ab", bevel=0.02)
    fbox("ElevDoor", (0.98, 2.25, 0.06), -8.5, 8.95, C["steel"], bevel=0.01)
    fbox("ElevDoor", (0.98, 2.25, 0.06), -7.5, 8.95, C["steel"], bevel=0.01)
    fbox("ElevSeam", (0.02, 2.25, 0.07), -8.0, 8.94, C["dark"], bevel=0)
    fbox("ElevIndicator", (0.7, 0.22, 0.04), -8.0, 8.96, C["black"], y0=2.32, bevel=0.01)
    fbox("ElevIndicatorGlow", (0.5, 0.12, 0.01), -8.0, 8.935, C["orange"], y0=2.37, glow=1.5, bevel=0)
    fbox("ElevButtons", (0.16, 0.35, 0.04), -6.45, 8.97, "#9aa1ab", y0=1.0, bevel=0.01)
    cyl("ElevButton", 0.035, 0.02, (-6.45, 1.25, 8.94), C["orange"], tilt=90, glow=1.2, segs=10)
    fcol("ElevBack", (2.4, 2.4, 0.2), -8.0, 9.2)
    fbox("Welcome", (2.0, 0.04, 1.2), -8.0, 7.9, "#3d5f8e", bevel=0.01)

    # south wall furniture
    for i in range(5):
        fbox("Filing", (0.55, 1.3, 0.62), -3.6 + i * 0.6, 8.65, "#a9b0ba", col=True, bevel=0.02)
        for j in range(4):
            fbox("Drawer", (0.46, 0.02, 0.02), -3.6 + i * 0.6, 8.33, C["dark"], y0=0.25 + j * 0.3, bevel=0)
    fbox("Whiteboard", (2.6, 1.3, 0.06), 3.2, 8.95, "#fbfbf8", y0=1.0, bevel=0.02)
    fbox("WhiteboardFrame", (2.7, 0.06, 0.1), 3.2, 8.92, C["grey"], y0=0.95)
    for i, c in enumerate((C["red"], C["navy"], C["green"])):
        fbox("Scribble", (0.9 - i * 0.2, 0.04, 0.01), 2.6 + i * 0.3, 8.91, c, y0=1.8 - i * 0.25, bevel=0)
    cyl("WallClock", 0.32, 0.06, (11.97, 2.35, 4.4), C["white"], tilt=90, yaw=90, segs=16)
    cyl("WallClockRim", 0.35, 0.05, (11.99, 2.35, 4.4), C["dark"], tilt=90, yaw=90, segs=16)
    box("Poster", (1.0, 1.4, 0.04), (11.97, 1.7, -1.8), C["navy"], yaw=90)
    box("PosterArt", (0.8, 0.8, 0.02), (11.94, 1.85, -1.8), C["gold"], yaw=90)
    box("Poster", (1.0, 1.4, 0.04), (-11.97, 1.7, 6.5), C["red"], yaw=90)
    box("PosterArt", (0.8, 0.8, 0.02), (-11.94, 1.85, 6.5), "#ffffff", yaw=90)
    plant(WORLD, 11.3, 8.4)
    plant(WORLD, -11.3, 8.4)
    plant(WORLD, -4.6, -2.4)
    plant(WORLD, 5.5, -2.4)

    # outside: skyline seen from 14F
    skyline(1, -30, -140, 110)
    fbox("Arch_Ground", (400, 0.5, 400), 0, 0, "#6d7a6a", y0=-46, bevel=0)

    marker("Mk_Elevator", (-8.0, 0, 7.8), 180)


# ---------------------------------------------------------------- STREET

def building(x0, x1, height, color, z_front=-4.0, depth=12.0, glow_win=0.0, win="#ffe9a8"):
    w = x1 - x0
    cx = (x0 + x1) / 2
    fbox("Bldg", (w - 0.2, height, depth), cx, z_front - depth / 2, color, arch=True, bevel=0)
    for j in range(int((height - 5) / 3.2)):
        y = 5.2 + j * 3.2
        for i in range(max(1, int(w / 2.6))):
            x = x0 + 1.3 + i * 2.6
            if x > x1 - 0.8:
                break
            lit = random.random() < 0.55
            fbox("Arch_Win", (1.5, 1.6, 0.08), x, z_front + 0.04, win if lit else "#3b4660", y0=y,
                 glow=glow_win if lit else 0.0, bevel=0)
    fbox("Ledge", (w - 0.1, 0.25, 0.4), cx, z_front + 0.15, "#d8d2c4", y0=4.4, bevel=0.02)


def storefront(x0, x1, interior, awning, z_front=-4.0, sign="#ffffff", sign_glow=1.5):
    w = x1 - x0
    cx = (x0 + x1) / 2
    fbox("ShopGlass", (w - 0.6, 3.2, 0.06), cx, z_front + 0.03, interior, y0=0.2, glow=0.9, alpha=0.85, bevel=0)
    for x in (x0 + 0.3, x1 - 0.3):
        fbox("ShopPost", (0.25, 4.4, 0.3), x, z_front + 0.1, C["dark"])
    fbox("ShopSign", (w - 0.4, 0.9, 0.25), cx, z_front + 0.2, sign, y0=3.45, glow=sign_glow, bevel=0.03)
    box("Awning", (w - 0.4, 0.08, 1.6), (cx, 3.2, z_front + 0.8), awning, tilt=-14, bevel=0.02)
    fcol("Shopfront", (w, 4.4, 0.4), cx, z_front + 0.1)


def street_lamp(x, z):
    cyl("LampPole", 0.07, 5.2, (x, 2.6, z), "#3e4450", segs=8, col=True)
    box("LampArm", (0.08, 0.08, 1.3), (x, 5.15, z - 0.6), "#3e4450")
    box("LampHead", (0.35, 0.14, 0.6), (x, 5.05, z - 1.15), "#3e4450", bevel=0.03)
    box("LampGlow", (0.28, 0.03, 0.5), (x, 4.97, z - 1.15), "#ffe2a0", glow=4.0, bevel=0)


def tree(x, z):
    fbox("Planter", (1.2, 0.35, 1.2), x, z, "#8e8778", col=True, bevel=0.03)
    fbox("Soil", (1.05, 0.02, 1.05), x, z, "#5a4632", y0=0.35, bevel=0)
    cyl("Trunk", 0.11, 2.6, (x, 1.6, z), "#6b4a2e", segs=7)
    for i, (dx, dy, dz, r) in enumerate(((0, 3.3, 0, 1.0), (0.5, 3.0, 0.3, 0.7), (-0.5, 3.1, -0.2, 0.75), (0.1, 3.9, 0.1, 0.65))):
        ball("Canopy", r, (x + dx, dy, z + dz), C["leaf"] if i % 2 else "#4aa957", segs=7, rings=5)


def car(x, z, yaw, color):
    f = Frame(x, z, yaw)
    fbox("CarBody", (1.8, 0.65, 4.2), 0, 0, color, f=f, y0=0.3, bevel=0.15, segs=2)
    fbox("CarCabin", (1.6, 0.6, 2.2), 0, -0.2, "#bfe2f5", f=f, y0=0.95, bevel=0.15, taper=(0.9, 0.8))
    fbox("CarRoof", (1.45, 0.08, 1.6), 0, -0.25, color, f=f, y0=1.53, bevel=0.04)
    for sx in (-0.85, 0.85):
        for sz in (-1.35, 1.35):
            cyl("Wheel", 0.34, 0.26, (sx, 0.34, sz), C["black"], f=f, tilt=90, yaw=90, segs=10)
    for sx in (-0.6, 0.6):
        fbox("Headlight", (0.35, 0.14, 0.04), sx, 2.1, "#fff6c8", f=f, y0=0.65, glow=1.0, bevel=0.01)
        fbox("Taillight", (0.35, 0.12, 0.04), sx, -2.1, C["red"], f=f, y0=0.68, glow=1.0, bevel=0.01)
    fcol("Car", (1.9, 1.6, 4.3), 0, 0, f=f)


def build_street():
    random.seed(7)
    # ground
    # sidewalk z [-4, 2.2] with a hole at x [60.5, 63.5], z [-3.35, 0.9] for the subway stairs
    for x0, x1, z0, z1 in ((-15, 60.5, -4, 2.2), (63.5, 75, -4, 2.2), (60.5, 63.5, -4, -3.35), (60.5, 63.5, 0.9, 2.2)):
        fbox("Sidewalk", (x1 - x0, 0.2, z1 - z0), (x0 + x1) / 2, (z0 + z1) / 2, C["sidewalk"], y0=-0.2, col=True,
             arch=True, bevel=0)
    for x in range(-14, 76, 2):
        if 60 <= x <= 64:
            continue
        fbox("Arch_Joint", (0.03, 0.01, 6.2), x, -0.9, "#b4ac9d", bevel=0)
    fbox("Curb", (90, 0.18, 0.35), 30, 2.3, C["curb"], y0=-0.02, arch=True, bevel=0.02)
    fbox("Road", (90, 0.2, 10), 30, 7.5, C["asphalt"], y0=-0.32, col=True, arch=True, bevel=0)
    for x in range(-12, 76, 6):
        fbox("Arch_Lane", (3.0, 0.01, 0.15), x, 7.5, "#f2f2f2", y0=-0.12, bevel=0)
    fbox("Arch_LaneY", (90, 0.01, 0.12), 30, 7.2, "#f0c419", y0=-0.12, bevel=0)
    fbox("Arch_LaneY", (90, 0.01, 0.12), 30, 7.4, "#f0c419", y0=-0.12, bevel=0)
    for i in range(8):
        fbox("Arch_Zebra", (0.5, 0.01, 9.6), 50 + i * 1.0, 7.5, "#f5f5f5", y0=-0.115, bevel=0)
    fbox("FarSidewalk", (90, 0.2, 4), 30, 14.5, C["sidewalk"], y0=-0.2, arch=True, bevel=0)
    # keep the player on the near sidewalk
    fcol("CurbWall", (90, 2.0, 0.3), 30, 2.25)
    fcol("EndWall", (0.3, 4, 8), -10.5, -1)
    fcol("EndWall", (0.3, 4, 8), 70.5, -1)

    # north side buildings (z_front = -4)
    # Hansung tower x [-10, 8]
    fbox("Hansung", (18, 60, 14), -1, -11, "#9fb8d0", arch=True, bevel=0)
    for j in range(17):
        fbox("Arch_HansungBand", (17.6, 1.9, 0.1), -1, -3.98, "#5d7fa3", y0=5.5 + j * 3.2, glow=0.25, bevel=0)
    fbox("Lobby", (12, 4.3, 0.08), -1, -3.96, "#cfeeff", y0=0, glow=0.7, alpha=0.8, bevel=0)
    fbox("Canopy", (8, 0.3, 3.0), -1, -2.6, "#2a3d55", y0=3.6, bevel=0.03)
    for x in (-4.7, 2.7):
        fbox("CanopyPost", (0.18, 3.6, 0.18), x, -1.3, C["dark"])
    cyl("RevolvingDoor", 1.2, 2.6, (-1, 1.3, -4.1), "#dff4ff", segs=16, alpha=0.5)
    fbox("CanopySign", (5.0, 0.7, 0.12), -1, -1.08, "#2a3d55", y0=3.9, bevel=0.02)
    fcol("HansungFront", (18, 6, 0.4), -1, -4.1)
    fcol("RevolvingDoor", (2.4, 2.6, 1.3), -1, -3.5)
    fbox("EntranceMat", (3, 0.02, 2), -1, -3.0, "#2f3542", bevel=0)
    marker("Mk_HansungDoor", (-1, 0, -2.6), 0)

    building(8, 18, 16, "#e6b88a", glow_win=1.0)
    storefront(8.3, 17.7, "#ffcf80", C["orange"], sign="#ffd36b")  # chicken + beer
    building(18, 28, 20, "#c9d6c4", glow_win=1.0)
    storefront(18.3, 27.7, "#f3fff7", "#3fae6b", sign="#ffffff", sign_glow=2.0)  # HAPPY MART 24
    for i, x in enumerate((19.8, 25.6)):
        cyl("MartTable", 0.45, 0.05, (x, 0.72, -2.4), "#3fae6b", segs=12)
        cyl("MartTableLeg", 0.04, 0.7, (x, 0.35, -2.4), C["grey"], segs=6)
        fcol("MartTable", (1.0, 0.8, 1.0), x, -2.4)
        for dx in (-0.7, 0.7):
            fbox("MartChair", (0.42, 0.45, 0.42), x + dx, -2.4, "#3fae6b", bevel=0.04)
    marker("Mk_MartDoor", (23.0, 0, -3.1), 0)
    building(28, 38, 24, "#8f7fb8", glow_win=1.0)
    storefront(28.3, 37.7, "#ff7ad9", C["purple"], sign="#ff4fbf", sign_glow=3.0)  # noraebang
    building(38, 47, 14, "#d9c7a8", glow_win=1.0)
    storefront(38.3, 46.7, "#9fe9ff", C["sky"], sign="#9fe9ff", sign_glow=2.0)  # phone shop
    building(47, 58, 18, "#b6c3d4", glow_win=1.0)
    storefront(47.3, 57.7, "#fff1c4", C["red"], sign="#ff5a5a", sign_glow=2.0)  # pharmacy / bakery
    building(58, 72, 26, "#9aa5b8", glow_win=1.0)
    fbox("Wall58", (14, 4.4, 0.3), 65, -4.0, "#7e889b", col=True, bevel=0)

    # pojangmacha (orange tent) on the sidewalk
    tf = Frame(42.5, -2.2, 0)
    for dx in (-1.6, 1.6):
        for dz in (-1.1, 1.1):
            fbox("TentPole", (0.06, 2.4, 0.06), dx, dz, C["grey"], f=tf)
    fbox("TentRoof", (3.6, 0.15, 2.6), 0, 0, "#ff7a1a", f=tf, y0=2.4, bevel=0.05)
    for dz in (-1.15, 1.15):
        fbox("TentWall", (3.3, 2.2, 0.03), 0, dz, "#ff8f2e", f=tf, y0=0.15, alpha=0.55, bevel=0)
    fbox("TentWall", (0.03, 2.2, 2.3), -1.65, 0, "#ff8f2e", f=tf, y0=0.15, alpha=0.55, bevel=0)
    fbox("TentTable", (1.6, 0.06, 0.8), 0.1, 0, "#d24b2a", f=tf, y0=0.7)
    fbox("TentTableLeg", (1.4, 0.7, 0.6), 0.1, 0, "#a6391f", f=tf)
    for dx in (-0.45, 0.6):
        cyl("Soju", 0.04, 0.2, (dx, 0.86, 0.1), "#4fcf7a", f=tf, segs=8, alpha=0.85)
    for dx, dz in ((-0.6, 0.65), (0.6, 0.65), (-0.6, -0.65), (0.6, -0.65)):
        cyl("TentStool", 0.17, 0.42, (dx, 0.21, dz), C["red"], f=tf, segs=8)
    ball("TentBulb", 0.09, (0, 2.2, 0), "#fff1a0", f=tf, glow=5.0, segs=8, rings=6)
    fcol("Tent", (3.6, 2.5, 2.6), 0, 0, f=tf)

    # street furniture
    for x in (4, 16, 28, 40, 52, 64):
        street_lamp(x, 1.7)
    for x in (10, 22, 34, 47.5, 56):
        tree(x, 1.2)
    for x, n in ((14.5, 4), (31.5, 3), (53.5, 5)):
        for i in range(n):
            ball("TrashBag", 0.32, (x + (i % 3) * 0.45, 0.28 + (i // 3) * 0.35, 1.6 + (i % 2) * 0.3),
                 "#3b4a3b" if i % 2 else "#e9e9e0", scale=(1, 0.85, 1), segs=8, rings=6)
        fcol("Trash", (1.6, 0.8, 1.0), x + 0.45, 1.7)
    sc = Frame(36.2, 0.8, 70)
    fbox("ScooterBody", (0.35, 0.5, 1.2), 0, 0, C["red"], f=sc, y0=0.3, bevel=0.08)
    fbox("ScooterBox", (0.5, 0.45, 0.5), 0, -0.45, "#f5f5f5", f=sc, y0=0.8, bevel=0.04)
    for dz in (-0.5, 0.5):
        cyl("ScooterWheel", 0.2, 0.1, (0, 0.2, dz), C["black"], f=sc, tilt=90, yaw=90, segs=10)
    fcol("Scooter", (0.6, 1.2, 1.4), 0, 0, f=sc)
    # bus stop
    bs = Frame(6.5, 1.4, 0)
    fbox("BusRoof", (3.2, 0.1, 1.2), 0, 0, "#2a3d55", f=bs, y0=2.4, bevel=0.02)
    fbox("BusBack", (3.2, 2.2, 0.05), 0, -0.55, C["glass"], f=bs, y0=0.2, alpha=0.4, bevel=0)
    fbox("BusBench", (2.4, 0.08, 0.4), 0, -0.3, C["wood"], f=bs, y0=0.45)
    for dx in (-1.55, 1.55):
        fbox("BusPost", (0.06, 2.4, 0.06), dx, -0.55, C["dark"], f=bs)
    fcol("BusStop", (3.2, 2.4, 0.4), 0, -0.45, f=bs)

    # cars parked / stuck in traffic
    for x, zz, c in ((2, 4.4, C["red"]), (12, 4.4, "#f1f1f1"), (24, 4.4, C["sky"]), (38, 4.4, C["yellow"]),
                     (-6, 10.4, C["navy"]), (18, 10.4, "#2f2f35"), (31, 10.4, C["green"]), (62, 10.4, "#f1f1f1")):
        car(x, zz, 90 if zz < 7 else -90, c)

    # subway entrance (x ~ 62, on the sidewalk)
    se = Frame(62.0, -1.2, 0)
    fbox("EntWallL", (0.3, 4.5, 4.2), -1.35, 0, "#cfd4d9", f=se, y0=-3.4, col=True, bevel=0.02)
    fbox("EntWallR", (0.3, 4.5, 4.2), 1.35, 0, "#cfd4d9", f=se, y0=-3.4, col=True, bevel=0.02)
    fbox("EntWallBack", (3.0, 4.5, 0.3), 0, -2.0, "#cfd4d9", f=se, y0=-3.4, col=True, bevel=0.02)
    fcol("EntOpening", (2.4, 2.0, 0.2), 0, 2.1, f=se)
    for i in range(10):
        fbox("Step", (2.4, 0.3, 0.42), 0, 1.6 - i * 0.38, "#9ea4ab", f=se, y0=-0.3 - i * 0.3, bevel=0.01)
    fbox("StairPit", (2.4, 0.1, 4.0), 0, 0, "#1a1d24", f=se, y0=-3.4, bevel=0)
    for dx in (-1.35, 1.35):
        fbox("EntPost", (0.12, 2.8, 0.12), dx, 1.9, C["dark"], f=se)
        fbox("EntPost", (0.12, 2.8, 0.12), dx, -1.9, C["dark"], f=se)
    fbox("EntRoof", (3.1, 0.12, 4.3), 0, 0, C["glass"], f=se, y0=2.8, alpha=0.5, bevel=0.02)
    fbox("EntRoofFrame", (3.2, 0.1, 0.12), 0, 2.1, C["dark"], f=se, y0=2.78)
    fbox("EntSign", (2.6, 0.6, 0.14), 0, 2.2, "#2d6e3a", f=se, y0=2.95, bevel=0.03)
    cyl("EntLineDot", 0.24, 0.05, (-0.95, 3.25, 2.29), C["line2"], f=se, tilt=90, segs=14, glow=1.0)
    fbox("EntRailing", (0.06, 0.06, 3.6), -1.1, 0, C["steel"], f=se, y0=0.9)
    marker("Mk_SubwayEntrance", (62.0, 0, 1.0), 180)

    # opposite side of the road
    random.seed(11)
    x = -12
    for w, h, c in ((12, 30, "#7e8db0"), (10, 18, "#c9a38a"), (14, 40, "#8ea7b5"), (9, 14, "#d3c39c"),
                    (12, 22, "#9b8cc2"), (10, 34, "#7f98a6"), (13, 20, "#c99c9c"), (12, 28, "#8aa58f")):
        fbox("FarBldg", (w - 0.3, h, 10), x + w / 2, 21.5, c, arch=True, bevel=0)
        for j in range(int((h - 2) / 3.2)):
            for i in range(int(w / 2.6)):
                if random.random() < 0.5:
                    fbox("Arch_FarWin", (1.4, 1.5, 0.08), x + 1.3 + i * 2.6, 16.45, "#ffe9a8", y0=1.5 + j * 3.2,
                         glow=1.2, bevel=0)
        if random.random() < 0.6:
            fbox("FarSign", (w * 0.6, 1.2, 0.2), x + w / 2, 16.3, random.choice(["#ff4f8b", "#4fd2ff", "#ffd34f", "#7cff6b"]),
                 y0=4.5, glow=2.5, bevel=0.03)
        x += w
    skyline(3, -40, -160, 140, ground=-1, night=True, count=30)
    skyline(4, 40, 160, 140, ground=-1, night=True, count=30)

    marker("Mk_FromOffice", (-1.0, 0, -2.0), 0)
    marker("Mk_FromStation", (62.0, 0, 1.6), 90)


# ---------------------------------------------------------------- STATION

def build_station():
    random.seed(3)
    H = 3.8
    # concourse z [-14,-4], platform z [-4, 7.6], tracks z [7.6, 12]
    fbox("Floor", (46, 0.2, 21.6), 0, -3.2, "#ded9cc", y0=-0.2, col=True, arch=True, bevel=0)
    for x in range(-22, 23, 2):
        fbox("Arch_FloorLine", (0.03, 0.01, 21.6), x, -3.2, "#cbc5b6", bevel=0)
    fbox("Ceiling", (46, 0.2, 26), 0, -1.0, "#5b6068", y0=H, col=True, arch=True, bevel=0)
    for x in range(-20, 21, 5):
        fbox("CeilStrip", (3.0, 0.05, 0.3), x, -8.5, "#fffbea", y0=H - 0.06, glow=2.5, bevel=0)
        fbox("CeilStrip", (3.0, 0.05, 0.3), x, 0.5, "#fffbea", y0=H - 0.06, glow=2.5, bevel=0)
        fbox("CeilStrip", (3.0, 0.05, 0.3), x, 5.0, "#fffbea", y0=H - 0.06, glow=2.5, bevel=0)
    fbox("WallN", (46, H, 0.3), 0, -14.15, C["tile"], col=True, arch=True, bevel=0)
    fbox("WallStripe", (46, 0.25, 0.02), 0, -13.99, C["line2"], y0=1.4, bevel=0)
    fbox("WallW", (0.3, H + 2, 26), -23.15, -1, C["tile"], col=True, arch=True, bevel=0)
    fbox("WallE", (0.3, H + 2, 26), 23.15, -1, C["tile"], col=True, arch=True, bevel=0)
    # dividing wall between concourse and platform, with the gate opening x [-5, 5]
    for a, b in ((-23, -5), (5, 23)):
        fbox("GateWall", (b - a, H, 0.3), (a + b) / 2, -4.0, C["tile"], col=True, arch=True, bevel=0)
        fbox("WallStripe", (b - a, 0.25, 0.02), (a + b) / 2, -4.16, C["line2"], y0=1.4, bevel=0)
        fbox("WallStripe", (b - a, 0.25, 0.02), (a + b) / 2, -3.84, C["line2"], y0=1.4, bevel=0)
    fbox("GateHeader", (10, 1.0, 0.3), 0, -4.0, C["tile"], y0=H - 1.0, arch=True, bevel=0)

    # stairs up to the street (north end of the concourse), decorative
    sf = Frame(0, -9.8, 0)
    for i in range(11):
        fbox("UpStep", (3.4, 0.25, 0.4), 0, -i * 0.38, "#a4aab2", f=sf, y0=i * 0.25, bevel=0.01)
    fbox("UpStepWallL", (0.25, 3.0, 4.4), -1.85, -1.9, C["tile"], f=sf, y0=0, arch=True, bevel=0)
    fbox("UpStepWallR", (0.25, 3.0, 4.4), 1.85, -1.9, C["tile"], f=sf, y0=0, arch=True, bevel=0)
    fbox("Daylight", (3.4, 0.05, 2.0), 0, -3.4, "#ffe7b8", f=sf, y0=H - 0.1, glow=3.0, bevel=0)
    fcol("UpStairs", (3.4, 4, 4.4), 0, -2.0, f=sf)
    for dx in (-1.9, 1.9):
        fcol("UpStairSide", (0.3, 4, 4.4), dx, -2.0, f=sf)

    # ticket machines + kiosk + map
    for i in range(3):
        fbox("TicketMachine", (0.9, 1.7, 0.6), -14 + i * 1.1, -13.6, "#cfd6de", col=True, bevel=0.04)
        fbox("TicketScreen", (0.6, 0.45, 0.02), -14 + i * 1.1, -13.29, "#5fd0ff", y0=1.05, glow=1.0, bevel=0)
    fbox("Kiosk", (3.0, 1.1, 1.2), 12.0, -12.0, "#f6c445", col=True, bevel=0.04)
    fbox("KioskTop", (3.2, 0.1, 1.4), 12.0, -12.0, C["red"], y0=2.5, bevel=0.02)
    for dx in (-1.4, 1.4):
        fbox("KioskPost", (0.08, 1.4, 0.08), 12.0 + dx, -12.6, C["dark"], y0=1.1)
    fbox("RouteMap", (4.0, 1.8, 0.06), 7.0, -13.97, "#ffffff", y0=0.9, bevel=0.02)
    for i, c in enumerate((C["line2"], "#2f6fd6", "#f08a2c", "#8b5bd6")):
        fbox("RouteLine", (3.4, 0.06, 0.01), 7.0, -13.93, c, y0=1.3 + i * 0.3, bevel=0)

    # turnstiles at z=-4 (gaps to walk through)
    for x in (-4.6, -2.3, 0.0, 2.3, 4.6):
        fbox("Gate", (0.4, 1.0, 1.6), x, -4.0, "#b9c1cb", col=True, bevel=0.05)
        fbox("GateTop", (0.42, 0.04, 1.62), x, -4.0, C["dark"], y0=1.0, bevel=0.01)
        fbox("GateLight", (0.12, 0.05, 0.12), x, -4.65, C["line2"], y0=1.02, glow=2.0, bevel=0.01)
    marker("Mk_Gates", (0, 0, -4.0), 0)

    # platform furniture
    for x in (-15, -5, 5, 15):
        fbox("Pillar", (0.7, H, 0.7), x, 1.8, C["tile"], col=True, bevel=0.02)
        fbox("PillarBand", (0.72, 0.4, 0.72), x, 1.8, C["line2"], y0=1.6, bevel=0.01)
    for x in (-10, 10, -19, 19):
        fbox("Bench", (2.2, 0.08, 0.55), x, -2.9, C["wood"], y0=0.45, bevel=0.02)
        fbox("BenchBack", (2.2, 0.5, 0.06), x, -3.2, C["wood"], y0=0.55, bevel=0.02)
        for dx in (-0.9, 0.9):
            fbox("BenchLeg", (0.06, 0.45, 0.5), x + dx, -2.9, C["dark"])
        fcol("Bench", (2.2, 0.9, 0.7), x, -3.0)
    marker("Mk_Bench", (10, 0, -2.6), 180)
    fbox("Vending", (1.0, 1.9, 0.75), -20.5, -3.2, C["red"], col=True, bevel=0.05)
    fbox("VendingFace", (0.8, 1.2, 0.02), -20.5, -2.82, "#ffe9e9", y0=0.55, glow=1.2, bevel=0)
    for x in (-12, 12):
        cyl("Bin", 0.25, 0.8, (x, 0.4, -3.4), C["steel"], segs=10, col=True)
    # timetable boards on both faces of the gate header
    for z in (-4.19, -3.81):
        fbox("BoardBody", (4.2, 0.9, 0.08), 0, z, C["black"], y0=2.85, bevel=0.03)

    # screen doors along z=7.6
    fbox("SafetyStrip", (44, 0.01, 0.5), 0, 7.0, "#f2c230", bevel=0)
    for i in range(-4, 5):
        x = i * 5.0
        fbox("PSDFrame", (5.0, 0.35, 0.3), x, 7.6, "#a6adb7", y0=2.25, bevel=0.02)
        fbox("PSDPanel", (1.6, 2.2, 0.06), x - 1.7, 7.6, C["glass"], alpha=0.35, bevel=0.01)
        fbox("PSDPanel", (1.6, 2.2, 0.06), x + 1.7, 7.6, C["glass"], alpha=0.35, bevel=0.01)
        fbox("PSDDoor", (0.9, 2.2, 0.05), x - 0.45, 7.62, "#dff4ff", alpha=0.55, bevel=0.01)
        fbox("PSDDoor", (0.9, 2.2, 0.05), x + 0.45, 7.62, "#dff4ff", alpha=0.55, bevel=0.01)
        fbox("PSDEdge", (0.04, 2.2, 0.07), x, 7.61, C["line2"], glow=0.8, bevel=0)
        fbox("PSDLamp", (0.4, 0.08, 0.05), x, 7.43, C["orange"], y0=2.32, glow=1.5, bevel=0)
    fcol("PSD", (44, 3, 0.3), 0, 7.6)
    marker("Mk_PlatformDoor", (0, 0, 6.6), 180)

    # tracks
    fbox("TrackBed", (46, 0.2, 4.6), 0, 10.0, "#3a3d44", y0=-1.3, arch=True, bevel=0)
    for dz in (9.2, 10.8):
        fbox("Rail", (46, 0.12, 0.1), 0, dz, "#c9ced6", y0=-1.1, bevel=0)
    for x in range(-22, 23, 1):
        fbox("Arch_Sleeper", (0.25, 0.08, 2.6), x, 10.0, "#5b4a3a", y0=-1.15, bevel=0)
    fbox("PlatformEdge", (46, 1.3, 0.1), 0, 7.85, "#9aa0a8", y0=-1.3, arch=True, bevel=0)
    fbox("TrackWall", (46, H + 1.3, 0.3), 0, 12.4, C["tile"], y0=-1.3, arch=True, bevel=0)
    for x in (-15, -5, 5, 15):
        fbox("Ad", (4.0, 2.2, 0.05), x, 12.22, random.choice(["#ffcf4f", "#ff7aa8", "#7fd8ff", "#a3e37a"]), y0=0.3, glow=0.6, bevel=0.02)
    fbox("StationNameBar", (40, 0.45, 0.05), 0, 12.22, C["line2"], y0=2.7, bevel=0)

    marker("Mk_FromStreet", (0, 0, -8.6), 180)


# ---------------------------------------------------------------- TRAIN (exterior, slides in along x)

def build_train():
    random.seed(5)
    L = 19.5
    body = "#d9dde2"
    fbox("TrainBody", (L, 2.9, 3.0), 0, 0, body, y0=0.15, bevel=0.15, segs=2)
    fbox("TrainRoof", (L - 0.4, 0.25, 2.6), 0, 0, "#bfc4cb", y0=3.05, bevel=0.1)
    fbox("TrainStripe", (L + 0.02, 0.25, 3.02), 0, 0, C["line2"], y0=1.0, bevel=0.0)
    fbox("TrainStripe2", (L + 0.02, 0.08, 3.02), 0, 0, "#2b2f36", y0=2.9, bevel=0.0)
    for i in range(4):
        x = -7.5 + i * 5.0
        for side in (-1, 1):
            z = side * 1.51
            fbox("TrainDoor", (1.3, 2.2, 0.04), x, z, "#c4c9cf", y0=0.25, bevel=0.01)
            fbox("TrainDoorWin", (0.5, 0.9, 0.02), x - 0.32, z + side * 0.02, "#2c3e57", y0=1.25, bevel=0)
            fbox("TrainDoorWin", (0.5, 0.9, 0.02), x + 0.32, z + side * 0.02, "#2c3e57", y0=1.25, bevel=0)
        if i < 3:
            for side in (-1, 1):
                fbox("TrainWin", (3.2, 1.0, 0.03), x + 2.5, side * 1.51, "#2c3e57", y0=1.35, bevel=0.02, glow=0.25)
    for side in (-1, 1):
        fbox("TrainCab", (0.4, 2.6, 2.8), side * (L / 2 + 0.1), 0, body, y0=0.2, bevel=0.12)
        fbox("TrainWindshield", (0.05, 1.0, 2.2), side * (L / 2 + 0.31), 0, "#22344d", y0=1.6, bevel=0.02)
        for dz in (-0.9, 0.9):
            fbox("TrainLamp", (0.05, 0.18, 0.35), side * (L / 2 + 0.31), dz, "#fff4c8" if side > 0 else C["red"], y0=0.7,
                 glow=3.0, bevel=0.01)
    fbox("TrainUnder", (L - 1, 0.5, 2.4), 0, 0, C["dark"], y0=-0.35, bevel=0.02)


# ---------------------------------------------------------------- HOME

def build_home():
    random.seed(21)
    H = 2.9
    floor = "#c99b68"
    wall = "#f3e6cf"
    # apartment x [-6, 7], z [-9, 6.5]; entry at z [4.6, 6.5], x [-1.2, 1.2]
    fbox("Floor", (13, 0.2, 14.06), 0.5, -1.97, floor, y0=-0.2, col=True, arch=True, bevel=0)
    fbox("GenkanFloor", (2.4, 0.2, 1.5), 0.0, 5.8, "#8a8f98", y0=-0.32, col=True, arch=True, bevel=0)
    for x in [-5.5 + i * 0.6 for i in range(22)]:
        fbox("Arch_Board", (0.02, 0.005, 13.6), x, -2.2, "#b8875a", bevel=0)
    fbox("Ceiling", (13, 0.1, 15.5), 0.5, -1.25, "#fbf7ee", y0=H, col=True, arch=True, bevel=0)
    fbox("WallW", (0.25, H, 15.5), -6.1, -1.25, wall, col=True, arch=True, bevel=0)
    fbox("WallE", (0.25, H, 15.5), 7.1, -1.25, wall, col=True, arch=True, bevel=0)
    fbox("WallN", (13.4, 0.9, 0.25), 0.5, -9.1, wall, col=True, arch=True, bevel=0)
    fbox("WallN", (13.4, 0.3, 0.25), 0.5, -9.1, wall, y0=H - 0.3, arch=True, bevel=0)
    fcol("WinN", (13.4, H, 0.3), 0.5, -9.15)
    # living-room window onto the night city
    fbox("WinGlass", (13.0, H - 1.2, 0.03), 0.5, -9.1, "#9fc6e8", y0=0.9, alpha=0.18, bevel=0)
    for x in (-5, -2.5, 0, 2.5, 5):
        fbox("WinMullion", (0.08, H - 1.2, 0.1), x, -9.05, "#ffffff", y0=0.9)
    fbox("Curtain", (1.4, H - 0.4, 0.08), -5.2, -8.9, "#e9a7b4", y0=0.2, bevel=0.03)
    fbox("Curtain", (1.4, H - 0.4, 0.08), 6.2, -8.9, "#e9a7b4", y0=0.2, bevel=0.03)
    # entry wall (south) with the front door
    fbox("WallS", (4.8, H, 0.25), -3.6, 6.6, wall, col=True, arch=True, bevel=0)
    fbox("WallS", (5.8, H, 0.25), 4.1, 6.6, wall, col=True, arch=True, bevel=0)
    fbox("WallS", (2.4, H - 2.2, 0.25), 0.0, 6.6, wall, y0=2.2, arch=True, bevel=0)
    fbox("FrontDoor", (1.1, 2.15, 0.1), 0.0, 6.5, "#7b5136", bevel=0.03, col=True)
    fbox("DoorLock", (0.12, 0.3, 0.05), 0.42, 6.42, C["black"], y0=1.0, bevel=0.01)
    fbox("DoorLockGlow", (0.08, 0.16, 0.01), 0.42, 6.39, "#5fd0ff", y0=1.1, glow=1.5, bevel=0)
    cyl("DoorKnob", 0.04, 0.08, (-0.4, 1.0, 6.42), C["gold"], tilt=90, segs=8)
    # 현관: the shoe step
    fbox("GenkanStep", (2.4, 0.12, 0.08), 0.0, 5.06, "#a8743f", y0=-0.12, bevel=0.01)
    fbox("ShoeCabinet", (0.45, 1.1, 1.3), -1.0, 5.75, C["white"], col=True, bevel=0.03)
    for i, c in enumerate((C["black"], "#f2efe6", C["pink"], C["sky"])):
        fbox("Shoe", (0.12, 0.08, 0.28), 0.3 + i * 0.18, 5.9, c, y0=-0.12, bevel=0.03)
    # entry corridor walls
    fbox("HallWall", (0.2, H, 1.9), -1.3, 5.55, wall, col=True, arch=True, bevel=0)
    fbox("HallWall", (0.2, H, 1.9), 1.3, 5.55, wall, col=True, arch=True, bevel=0)

    # living room (west): couch, TV, coffee table, rug
    fbox("Rug", (3.4, 0.02, 2.4), -3.0, -2.0, "#c6d8b6", bevel=0.01)
    cf = Frame(-5.4, -2.0, 90)  # couch against west wall, facing +x
    fbox("CouchBase", (2.6, 0.42, 0.95), 0, 0, "#7f9c8f", f=cf, bevel=0.08)
    fbox("CouchBack", (2.6, 0.5, 0.25), 0, -0.36, "#728f82", f=cf, y0=0.42, bevel=0.08)
    for dx in (-1.25, 1.25):
        fbox("CouchArm", (0.25, 0.6, 0.95), dx, 0, "#728f82", f=cf, bevel=0.08)
    for dx in (-0.62, 0.62):
        fbox("Cushion", (1.15, 0.14, 0.75), dx, 0.05, "#8fae9f", f=cf, y0=0.42, bevel=0.06)
    fcol("Couch", (2.7, 1.0, 1.0), 0, 0, f=cf)
    fbox("CoffeeTable", (1.3, 0.06, 0.7), -3.3, -2.0, C["wood"], y0=0.38, bevel=0.02)
    fbox("CoffeeTableLegs", (1.1, 0.38, 0.5), -3.3, -2.0, "#8f6037", bevel=0.01)
    fcol("CoffeeTable", (1.3, 0.45, 0.7), -3.3, -2.0)
    cyl("Remote", 0.03, 0.18, (-3.1, 0.44, -1.9), C["black"], tilt=90, segs=6)
    fbox("TVStand", (2.2, 0.45, 0.45), -0.6, -2.0, C["white"], yaw=90, col=True, bevel=0.03)
    fbox("TV", (1.9, 1.1, 0.07), -0.75, -2.0, C["black"], y0=0.5, yaw=90, bevel=0.02)
    fbox("TVScreen", (1.78, 0.98, 0.01), -0.79, -2.0, "#33405c", y0=0.56, yaw=90, glow=0.3, bevel=0)
    plant(WORLD, -5.5, -8.3)
    # family photo wall
    for i, (dz, c) in enumerate(((-3.6, "#9fd0ff"), (-2.4, "#ffd36b"), (-1.2, "#ffb3c6"), (-0.2, "#b9e3a8"))):
        box("Frame", (0.05, 0.55, 0.7), (-5.95, 1.6 + (i % 2) * 0.15, dz), C["darkwood"])
        box("FramePic", (0.02, 0.45, 0.6), (-5.92, 1.6 + (i % 2) * 0.15, dz), c)
    # drying rack (very important)
    rf = Frame(-3.0, 2.9, 0)
    for dx in (-0.7, 0.7):
        fbox("RackLeg", (0.04, 1.0, 0.5), dx, 0, C["steel"], f=rf, tilt=0)
    for i in range(4):
        fbox("RackBar", (1.45, 0.03, 0.03), 0, -0.2 + i * 0.13, C["steel"], f=rf, y0=0.98)
    for i, c in enumerate(("#ffffff", "#9fc6ff", "#ffcf6b", "#ff9fb3")):
        fbox("Laundry", (0.3, 0.4, 0.02), -0.5 + i * 0.33, -0.2 + (i % 4) * 0.13, c, f=rf, y0=0.58, bevel=0.01)
    fcol("Rack", (1.5, 1.0, 0.6), 0, 0, f=rf)

    # kitchen + dining (east wall, z [-4.6, 0.6])
    fbox("KitchenCounter", (0.7, 0.9, 5.2), 6.65, -2.0, C["white"], col=True, bevel=0.02)
    fbox("KitchenTop", (0.75, 0.05, 5.25), 6.65, -2.0, "#7d8794", y0=0.9, bevel=0.01)
    fbox("Sink", (0.5, 0.02, 0.8), 6.6, -3.7, "#b9c0ca", y0=0.95, bevel=0.01)
    fbox("Stove", (0.55, 0.02, 0.7), 6.6, -2.5, C["black"], y0=0.95, bevel=0.01)
    cyl("Pot", 0.18, 0.2, (6.6, 1.06, -2.5), C["red"], segs=12)
    # the rice cooker
    cyl("RiceCooker", 0.2, 0.26, (6.6, 1.08, -1.2), "#f7f3f0", segs=14)
    cyl("RiceCookerLid", 0.21, 0.08, (6.6, 1.25, -1.2), C["pink"], segs=14, r2=0.17)
    fbox("RiceCookerLight", (0.02, 0.05, 0.08), 6.39, -1.2, "#5fd0ff", y0=1.05, glow=2.0, bevel=0)
    marker("Mk_RiceCooker", (6.6, 1.0, -1.2), 0)
    fbox("UpperCabinets", (0.4, 0.8, 5.2), 6.85, -2.0, C["white"], y0=1.6, bevel=0.02)
    fbox("Fridge", (0.8, 1.9, 0.8), 6.6, 1.5, "#dfe6ec", col=True, bevel=0.05)
    fbox("KimchiFridge", (0.8, 0.95, 0.75), 6.6, 2.6, "#e9c7d2", col=True, bevel=0.05)
    fbox("DiningTable", (1.6, 0.06, 0.9), 4.0, -2.0, C["wood"], y0=0.72, bevel=0.02)
    for dx in (-0.7, 0.7):
        for dz in (-0.35, 0.35):
            fbox("TableLeg", (0.06, 0.72, 0.06), 4.0 + dx, -2.0 + dz, "#8f6037")
    fcol("DiningTable", (1.6, 0.8, 0.9), 4.0, -2.0)
    for dx in (-0.45, 0.45):
        for dz, yaw in ((-0.75, 0), (0.75, 180)):
            df = Frame(4.0 + dx, -2.0 + dz, yaw)
            fbox("DinChair", (0.42, 0.06, 0.42), 0, 0, C["wood"], f=df, y0=0.44)
            fbox("DinChairBack", (0.42, 0.45, 0.05), 0, -0.2, C["wood"], f=df, y0=0.5)
    cyl("Lamp", 0.3, 0.25, (4.0, 2.1, -2.0), "#ffe6a8", segs=12, r2=0.12, glow=1.5)

    # bedroom: x [1, 7], z [-9, -5], door gap x [1.6, 2.6]
    fbox("BedroomWall", (0.2, H, 4.0), 1.0, -7.0, wall, col=True, arch=True, bevel=0)
    fbox("BedroomWall", (0.6, H, 0.2), 1.3, -5.0, wall, col=True, arch=True, bevel=0)
    fbox("BedroomWall", (4.4, H, 0.2), 4.8, -5.0, wall, col=True, arch=True, bevel=0)
    fbox("BedroomWall", (1.0, H - 2.15, 0.2), 2.1, -5.0, wall, y0=2.15, arch=True, bevel=0)
    fbox("Bed", (1.9, 0.45, 2.2), 4.6, -7.6, "#f5f1ea", col=True, bevel=0.06)
    fbox("BedFrame", (2.0, 0.3, 2.3), 4.6, -7.6, C["darkwood"], bevel=0.03)
    fbox("Blanket", (1.95, 0.12, 1.5), 4.6, -7.25, "#8fb8e8", y0=0.45, bevel=0.05)
    for dx in (-0.45, 0.45):
        fbox("Pillow", (0.7, 0.14, 0.4), 4.6 + dx, -8.4, "#ffffff", y0=0.45, bevel=0.06)
    fbox("Headboard", (2.0, 0.9, 0.1), 4.6, -8.75, C["darkwood"], y0=0.2, bevel=0.03)
    fbox("Nightstand", (0.45, 0.5, 0.4), 6.1, -8.5, C["wood"], col=True, bevel=0.02)
    fbox("AlarmClock", (0.18, 0.12, 0.08), 6.1, -8.45, C["red"], y0=0.5, bevel=0.03)
    fbox("AlarmFace", (0.12, 0.06, 0.01), 6.1, -8.40, "#ff5555", y0=0.53, glow=2.0, bevel=0)
    fbox("Wardrobe", (0.6, 2.1, 1.6), 1.45, -7.4, C["white"], col=True, bevel=0.03)
    marker("Mk_Bed", (4.6, 0, -6.0), 0)
    # kids' room door (closed, decorated)
    fbox("KidsDoor", (1.0, 2.1, 0.08), -6.0 + 0.06, 1.2, "#f7d9a8", yaw=90, bevel=0.02)
    for i, c in enumerate((C["red"], C["yellow"], C["sky"])):
        box("Drawing", (0.02, 0.25, 0.3), (-5.88, 1.3 + i * 0.28, 1.0 + (i % 2) * 0.3), c, bevel=0)

    skyline(9, -30, -140, 100, ground=-35, night=True, count=40)
    fbox("Arch_Ground", (300, 0.5, 300), 0, 0, "#1e2433", y0=-36, bevel=0)
    marker("Mk_FrontDoor", (0, 0, 5.2), 180)
    marker("Mk_Hana", (0, 0, 3.4), 0)


# ---------------------------------------------------------------- main

BUILDERS = {
    "office": build_office,
    "street": build_street,
    "station": build_station,
    "train": build_train,
    "home": build_home,
}

PREVIEWS = {
    "office": [("top", (0, -0.1, 60), (0, 0, 0), dict(ortho=34)), ("persp", (8, 14, 9), (-1, 0, 1), dict(lens=24))],
    "street": [("persp", (-6, 10, 5), (14, 0, 1), dict(lens=24)), ("top", (30, 0, 80), (30, 0, 0), dict(ortho=90))],
    "station": [("persp", (-12, 14, 4), (2, -2, 1), dict(lens=22)), ("top", (0, 0, 60), (0, 0, 0), dict(ortho=50))],
    "train": [("persp", (-8, 14, 4), (0, 0, 1.5), dict(lens=30))],
    "home": [("persp", (6, 8, 7), (-1, -2, 0), dict(lens=22)), ("top", (0.5, 0, 40), (0.5, 0, 0), dict(ortho=18))],
}


def main():
    args = lib.script_args()
    preview_dir = args[args.index("--preview") + 1] if "--preview" in args else None
    only = args[args.index("--only") + 1].split(",") if "--only" in args else list(BUILDERS.keys())
    for loc in only:
        lib.reset()
        _count.clear()
        BUILDERS[loc]()
        lib.bake_all_outlines()
        lib.export_glb("%s.glb" % loc)
        if preview_dir:
            os.makedirs(preview_dir, exist_ok=True)
            for tag, cam, look, kw in PREVIEWS[loc]:
                # previews use blender coords: convert the godot-space camera
                lib.preview(os.path.join(preview_dir, "%s_%s.png" % (loc, tag)), P(cam) if tag != "top" else
                            (cam[0], cam[1], cam[2]), P(look) if tag != "top" else (look[0], look[1], look[2]),
                            res=(1280, 720), **kw)


main()

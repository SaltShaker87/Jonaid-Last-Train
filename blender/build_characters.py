"""Build the cast as rigged, animated low-poly cartoon GLBs.

    blender --background --factory-startup --python blender/build_characters.py [-- --preview DIR] [-- --only jonaid]

Each character is a stack of chunky parts rigidly weighted to one bone each
(no weight painting), sharing one skeleton layout and one set of hand-keyed
animations. Output: assets/models/<id>.glb with actions:
Idle, Walk, Run, Bow, Talk, Angry, Smoke, Type, Sit, SitType, Freakout.

Bone axes (all bones roll 0): for bones that point down (arms, legs) +X
rotation swings the limb backward; for bones that point up (spine, head)
+X bends forward. Z rotation on a down-pointing bone swings it sideways:
left arm outward is -Z, right arm outward is +Z.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import lib  # noqa: E402

# ---------------------------------------------------------------- cast

BASE = dict(
    leg=0.80, torso=0.46, head_r=0.31, shoulder=0.27, belly=0.0, girth=1.0,
    skin="#f1c9a5", hair="#1b1716", hair_style="side_part",
    jacket="#3b3f4a", shirt="#f2f0ea", tie="#c8323c", pants="#2f323a", shoes="#18181b",
    glasses=None, tired=False, eyebags=False, lanyard=False, mustache=False, flush=False,
    brows="worried", mouth="frown", lips=None, apron=None, earrings=False, props=(),
)

CAST = {
    "jonaid": dict(
        jacket="#414858", pants="#30343d", tie="#d13a43", shoulder=0.29,
        glasses="#121214", tired=True, eyebags=True, lanyard=True,
        brows="worried", mouth="frown", props=("cigarette",),
    ),
    "park": dict(
        jacket="#25252b", pants="#25252b", tie="#c79a2a", shirt="#fbf6e9", shoulder=0.31,
        belly=0.13, girth=1.12, skin="#e9b28c", hair_style="combover", glasses="#0d0d0d",
        mustache=True, flush=True, brows="angry", mouth="shout", head_r=0.33,
    ),
    "sora": dict(
        jacket="#e3cba6", pants="#3c3a46", shirt="#ffffff", tie=None, shoulder=0.23,
        head_r=0.30, skin="#f6d3b6", hair="#2b1913", hair_style="bob", lanyard=True,
        brows="smug", mouth="smirk", lips="#c2334a", earrings=True, leg=0.78,
    ),
    "hana": dict(
        jacket="#ee8fa6", pants="#56688e", shirt="#fff4e6", tie=None, shoulder=0.23,
        head_r=0.30, skin="#f6d3b6", hair="#2b1913", hair_style="ponytail", apron="#ffd25a",
        shoes="#f2efe6", brows="normal", mouth="flat", lips="#c94a5c", leg=0.77,
        props=("ladle",),
    ),
    "choi": dict(
        jacket="#1d2742", pants="#1d2742", tie="#86202e", leg=0.88, torso=0.50, shoulder=0.28,
        hair="#a2a2a8", hair_style="slick", glasses="#c8a24a", brows="stern", mouth="flat",
        skin="#ecc19f", head_r=0.28,
    ),
}

# ---------------------------------------------------------------- skeleton


def bone_layout(s):
    leg, torso, sh = s["leg"], s["torso"], s["shoulder"]
    hip_z = leg
    chest = hip_z + torso
    arm_up = 0.25 * (torso / 0.46)
    arm_lo = 0.23 * (torso / 0.46)
    thigh = leg * 0.45
    shin = leg * 0.43
    b = {
        "root": ((0, 0, 0), (0, 0, 0.25), None),
        "hips": ((0, 0, hip_z), (0, 0, hip_z + 0.14), "root"),
        "spine": ((0, 0, hip_z + 0.14), (0, 0, chest), "hips"),
        "head": ((0, 0, chest), (0, 0, chest + 0.5), "spine"),
    }
    for side, sx in (("L", 1), ("R", -1)):
        sz = chest - 0.04
        b["upper_arm." + side] = ((sx * sh, 0, sz), (sx * (sh + 0.03), 0, sz - arm_up), "spine")
        b["forearm." + side] = ((sx * (sh + 0.03), 0, sz - arm_up), (sx * (sh + 0.04), 0, sz - arm_up - arm_lo), "upper_arm." + side)
        b["hand." + side] = ((sx * (sh + 0.04), 0, sz - arm_up - arm_lo), (sx * (sh + 0.04), 0, sz - arm_up - arm_lo - 0.12), "forearm." + side)
        hx = 0.115
        b["thigh." + side] = ((sx * hx, 0, hip_z), (sx * hx, 0, hip_z - thigh), "hips")
        b["shin." + side] = ((sx * hx, 0, hip_z - thigh), (sx * hx, 0, 0.09), "thigh." + side)
        b["foot." + side] = ((sx * hx, 0, 0.09), (sx * hx, -0.16, 0.04), "shin." + side)
    return b


def build_armature(name, layout):
    arm_data = bpy.data.armatures.new(name + "_Armature")
    arm = bpy.data.objects.new(name + "_Rig", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm_data.edit_bones
    for bname, (head, tail, _par) in layout.items():
        e = eb.new(bname)
        e.head = head
        e.tail = tail
        e.roll = 0.0
    for bname, (_h, _t, par) in layout.items():
        if par:
            eb[bname].parent = eb[par]
            eb[bname].use_connect = False
    bpy.ops.object.mode_set(mode='OBJECT')
    for pb in arm.pose.bones:
        pb.rotation_mode = 'XYZ'
    return arm


# ---------------------------------------------------------------- body parts

class Kit:
    """Collects parts and the bone each one is rigidly bound to."""

    def __init__(self):
        self.parts = []
        self.props = []

    def add(self, ob, bone):
        vg = ob.vertex_groups.new(name=bone)
        vg.add(list(range(len(ob.data.vertices))), 1.0, 'REPLACE')
        self.parts.append(ob)
        return ob

    def prop(self, ob, bone):
        vg = ob.vertex_groups.new(name=bone)
        vg.add(list(range(len(ob.data.vertices))), 1.0, 'REPLACE')
        self.props.append(ob)
        return ob


def shell(name, r, center, color, scale, cuts, segs=18, rings=12):
    """Ellipsoid trimmed by planes (keep the side the normal points to)."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    for co, no in cuts:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector(co), plane_no=Vector(no).normalized(), clear_inner=True)
    boundary = [e for e in bm.edges if e.is_boundary]
    if boundary and len(cuts) == 1:  # a single planar cut fills cleanly
        bmesh.ops.holes_fill(bm, edges=boundary, sides=0)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(lib.mat(color))
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = center
    return ob


def build_body(cid, s, L):
    k = Kit()
    hip_z = s["leg"]
    chest = hip_z + s["torso"]
    sh = s["shoulder"]
    g = s["girth"]
    belly = s["belly"]
    r = s["head_r"]
    hc = chest + 0.07 + r * 0.92  # head centre
    skin = s["skin"]

    def face_y(x, dz, out=0.0):
        """Front surface of the head ellipsoid (y scale 0.92) at offsets."""
        q = 1.0 - (x / r) ** 2 - (dz / r) ** 2
        return -0.92 * r * math.sqrt(max(q, 0.0)) - out

    # --- torso
    depth = 0.30 * g + belly
    k.add(lib.rbox("pelvis", (0.40 * g, 0.27 * g, 0.22), (0, 0, hip_z + 0.02), s["pants"], bevel=0.06, smooth=True), "hips")
    jacket_h = s["torso"] + 0.10
    k.add(lib.rbox("jacket", (2 * sh - 0.02, depth, jacket_h), (0, -belly * 0.5, hip_z + jacket_h * 0.5 - 0.08),
                   s["jacket"], bevel=0.08, segs=3, taper=(1.08, 0.92), smooth=True), "spine")
    front = -belly - depth * 0.5
    # shirt V + tie
    k.add(lib.rbox("shirt", (0.06, 0.02, 0.22), (0, front + 0.005, chest - 0.13), s["shirt"], bevel=0.008,
                   taper=(3.2, 1.0), smooth=True), "spine")
    if s["tie"]:
        k.add(lib.rbox("tie", (0.06, 0.025, 0.30), (0, front - 0.006, chest - 0.20), s["tie"], bevel=0.01,
                       taper=(0.75, 1.0), smooth=True), "spine")
        k.add(lib.rbox("tie_knot", (0.06, 0.03, 0.05), (0, front - 0.008, chest - 0.035), s["tie"], bevel=0.012, smooth=True), "spine")
    else:
        # open collar: a little triangle of skin
        k.add(lib.rbox("collar_skin", (0.04, 0.02, 0.09), (0, front + 0.002, chest - 0.06), skin, bevel=0.008,
                       taper=(2.4, 1.0), smooth=True), "spine")
    for bz in (hip_z + 0.05, hip_z - 0.04):
        k.add(lib.ball("button", 0.018, (0.0, front - 0.004, bz), "#121214", segs=8, rings=5), "spine")
    if s["lanyard"]:
        for sx in (1, -1):
            k.add(lib.rbox("lanyard", (0.022, 0.012, 0.26), (sx * 0.085, front - 0.004, chest - 0.12), "#2f6fd6",
                           bevel=0.004, rot=(0, sx * 18, 0)), "spine")
        k.add(lib.rbox("badge", (0.10, 0.014, 0.13), (0.0, front - 0.032, chest - 0.28), "#ffffff", bevel=0.01), "spine")
        k.add(lib.rbox("badge_band", (0.10, 0.016, 0.035), (0.0, front - 0.034, chest - 0.235), "#2f6fd6", bevel=0.006), "spine")
        k.add(lib.ball("badge_face", 0.022, (0.0, front - 0.040, chest - 0.29), "#f1c9a5", segs=8, rings=6,
                       scale=(1, 0.3, 1.2)), "spine")
    if s["apron"]:
        k.add(lib.rbox("apron", (2 * sh - 0.10, 0.02, s["torso"] + 0.30), (0, front - 0.012, hip_z + 0.02),
                       s["apron"], bevel=0.02, taper=(0.75, 1.0), smooth=True), "spine")
        k.add(lib.rbox("apron_pocket", (0.20, 0.022, 0.10), (0, front - 0.022, hip_z - 0.04), "#ffb53d", bevel=0.012), "spine")
    # neck + shoulders
    k.add(lib.cyl("neck", 0.075, 0.14, (0, 0, chest + 0.02), skin, segs=10), "spine")
    for side, sx in (("L", 1), ("R", -1)):
        k.add(lib.ball("shoulder", 0.125, (sx * sh, -belly * 0.3, chest - 0.06), s["jacket"], scale=(1.0, 1.0, 0.85)), "spine")

    # --- arms
    for side, sx in (("L", 1), ("R", -1)):
        ua_h, ua_t, _ = L["upper_arm." + side]
        fa_h, fa_t, _ = L["forearm." + side]
        hd_h, _hd_t, _ = L["hand." + side]
        mid = (Vector(ua_h) + Vector(ua_t)) * 0.5
        ln = (Vector(ua_t) - Vector(ua_h)).length
        k.add(lib.rbox("sleeve_up", (0.16, 0.16, ln + 0.04), mid, s["jacket"], bevel=0.05, smooth=True), "upper_arm." + side)
        k.add(lib.ball("elbow", 0.078, ua_t, s["jacket"]), "upper_arm." + side)
        mid = (Vector(fa_h) + Vector(fa_t)) * 0.5
        ln = (Vector(fa_t) - Vector(fa_h)).length
        k.add(lib.rbox("sleeve_lo", (0.145, 0.145, ln), mid, s["jacket"], bevel=0.045, smooth=True), "forearm." + side)
        k.add(lib.cyl("cuff", 0.068, 0.035, (fa_t[0], fa_t[1], fa_t[2] + 0.015), s["shirt"], segs=10), "forearm." + side)
        hand_c = (hd_h[0], hd_h[1] - 0.005, hd_h[2] - 0.075)
        k.add(lib.ball("hand", 0.10, hand_c, skin, scale=(0.85, 0.75, 1.1)), "hand." + side)
        k.add(lib.ball("thumb", 0.042, (hand_c[0] - sx * 0.04, hand_c[1] - 0.05, hand_c[2] + 0.03), skin), "hand." + side)

    # --- legs
    for side, sx in (("L", 1), ("R", -1)):
        th_h, th_t, _ = L["thigh." + side]
        sn_h, sn_t, _ = L["shin." + side]
        mid = (Vector(th_h) + Vector(th_t)) * 0.5
        ln = (Vector(th_t) - Vector(th_h)).length
        k.add(lib.rbox("thigh", (0.18 * g, 0.20 * g, ln + 0.06), mid, s["pants"], bevel=0.055, smooth=True), "thigh." + side)
        k.add(lib.ball("knee", 0.085 * g, th_t, s["pants"]), "thigh." + side)
        mid = (Vector(sn_h) + Vector(sn_t)) * 0.5
        ln = (Vector(sn_t) - Vector(sn_h)).length
        k.add(lib.rbox("shin", (0.16, 0.17, ln), mid, s["pants"], bevel=0.05, smooth=True), "shin." + side)
        k.add(lib.rbox("shoe", (0.16, 0.32, 0.11), (sx * 0.115, -0.05, 0.055), s["shoes"], bevel=0.05, segs=3,
                       taper=(0.9, 0.8), smooth=True,
                       material=lib.mat(s["shoes"], rough=0.35)), "foot." + side)

    # --- head
    f = r / 0.25  # face features were authored for a 0.25 head
    k.add(lib.ball("head", r, (0, 0, hc), skin, scale=(1.0, 0.92, 1.0), segs=18, rings=12), "head")
    for sx in (1, -1):
        k.add(lib.ball("ear", 0.065 * f, (sx * r * 0.97, 0.02, hc - 0.03 * f), skin, scale=(0.45, 0.8, 1.0)), "head")
    nose_dz = -0.12 * r
    k.add(lib.ball("nose", 0.05 * f, (0, face_y(0, nose_dz) - 0.012 * f, hc + nose_dz), "#e6a98a" if skin != "#e9b28c" else "#d98f6e",
                   scale=(1.0, 1.0, 0.85)), "head")
    if s["flush"]:
        for sx in (1, -1):
            k.add(lib.ball("cheek", 0.055 * f, (sx * 0.48 * r, face_y(0.48 * r, -0.25 * r) + 0.01, hc - 0.25 * r), "#e8796b",
                           scale=(1.0, 0.4, 0.7)), "head")
    # eyes
    ex, ez = 0.38 * r, 0.04 * r
    e = 0.23 * r
    for sx in (1, -1):
        ey = face_y(ex, ez) + 0.012
        k.add(lib.ball("eye", e, (sx * ex, ey, hc + ez), "#ffffff", scale=(1.0, 0.55, 1.15)), "head")
        k.add(lib.ball("pupil", e * 0.48, (sx * ex * 0.97, ey - e * 0.5, hc + ez - e * 0.15), "#141418", segs=10, rings=6,
                       scale=(1.0, 0.5, 1.0)), "head")
        if s["tired"]:
            k.add(lib.ball("lid", e * 1.08, (sx * ex, ey - 0.004, hc + ez + e * 0.50), skin, scale=(1.05, 0.6, 0.62)), "head")
        if s["eyebags"]:
            k.add(lib.ball("bag", e * 0.95, (sx * ex, ey + 0.004, hc + ez - e * 1.05), "#b3899a", scale=(1.0, 0.45, 0.42)), "head")
        # brows
        bz = 0.40 * r
        tilt = {"worried": -14, "angry": 18, "smug": 0, "normal": 0, "stern": 8}[s["brows"]]
        if s["brows"] == "smug" and sx == 1:
            tilt, bz = -8, bz + 0.02
        k.add(lib.rbox("brow", (0.11 * f, 0.025 * f, 0.026 * f), (sx * ex, face_y(ex, bz) - 0.012 * f, hc + bz),
                       s["hair"] if s["hair_style"] != "combover" else "#141212", bevel=0.01,
                       rot=(0, sx * tilt, 0)), "head")
    if s["glasses"]:
        gy = face_y(ex, ez) - 0.035 * f
        gw, gh, t = 0.15 * f, 0.135 * f, 0.014 * f
        gm = lib.mat(s["glasses"], rough=0.4)
        for sx in (1, -1):
            cx = sx * ex
            k.add(lib.rbox("glass_t", (gw, t, t), (cx, gy, hc + ez + gh / 2), "", bevel=0.004, material=gm), "head")
            k.add(lib.rbox("glass_b", (gw, t, t), (cx, gy, hc + ez - gh / 2), "", bevel=0.004, material=gm), "head")
            k.add(lib.rbox("glass_o", (t, t, gh), (cx + sx * gw / 2, gy, hc + ez), "", bevel=0.004, material=gm), "head")
            k.add(lib.rbox("glass_i", (t, t, gh), (cx - sx * gw / 2, gy, hc + ez), "", bevel=0.004, material=gm), "head")
            k.add(lib.rbox("glass_arm", (t, r * 0.95, t), (sx * (r * 0.9), gy + r * 0.48, hc + ez + gh / 2 - 0.01), "",
                           bevel=0.004, material=gm), "head")
        k.add(lib.rbox("glass_bridge", (ex * 2 - gw, t, t), (0, gy, hc + ez + 0.01), "", bevel=0.004, material=gm), "head")
    # mouth
    mz = -0.47 * r
    my = face_y(0, mz) - 0.004
    mouth_col = s["lips"] or "#6b2a2a"
    if s["mouth"] == "shout":
        k.add(lib.ball("mouth", 0.07 * f, (0, my + 0.01 * f, hc + mz), "#5a1820", scale=(1.0, 0.35, 0.7)), "head")
        k.add(lib.rbox("teeth", (0.08 * f, 0.01 * f, 0.022 * f), (0, my - 0.012 * f, hc + mz + 0.03 * f), "#ffffff", bevel=0.005), "head")
    elif s["mouth"] == "smirk":
        k.add(lib.rbox("mouth", (0.10 * f, 0.02 * f, 0.022 * f), (0.01 * f, my, hc + mz), mouth_col, bevel=0.008, rot=(0, -12, 0)), "head")
    elif s["mouth"] == "frown":
        for sx in (1, -1):
            k.add(lib.rbox("mouth", (0.06 * f, 0.02 * f, 0.02 * f), (sx * 0.026 * f, my, hc + mz - 0.006 * f), mouth_col, bevel=0.007,
                           rot=(0, sx * 16, 0)), "head")
    else:
        k.add(lib.rbox("mouth", (0.09 * f, 0.02 * f, 0.02 * f), (0, my, hc + mz), mouth_col, bevel=0.007), "head")
    if s["mustache"]:
        for sx in (1, -1):
            k.add(lib.rbox("stache", (0.10 * f, 0.04 * f, 0.04 * f), (sx * 0.05 * f, my - 0.012 * f, hc + mz + 0.045 * f), "#141212", bevel=0.015,
                           rot=(0, sx * -14, 0)), "head")
    if s["earrings"]:
        for sx in (1, -1):
            k.add(lib.ball("earring", 0.022 * f, (sx * r * 0.98, 0.0, hc - 0.12 * f), "#e9b949", segs=8, rings=6), "head")

    # --- hair
    hs, hcol = s["hair_style"], s["hair"]
    if hs == "side_part":
        k.add(shell("hair", r, (0, 0.01, hc + 0.005), hcol, (1.07, 1.03, 1.07),
                    [((0, -r, 0.40 * r), (0, 0.85 * r, 2 * r))]), "head")
        # salaryman quiff: a fat wave swept to one side, sunk into the cap
        k.add(lib.ball("quiff", r * 0.62, (-0.10 * r, -0.42 * r, hc + 0.70 * r), hcol, scale=(1.35, 0.95, 0.62),
                       rot=(-18, 0, -12)), "head")
        k.add(lib.ball("quiff_tip", r * 0.30, (0.42 * r, -0.62 * r, hc + 0.62 * r), hcol, scale=(1.2, 0.8, 0.7),
                       rot=(0, 25, 0)), "head")
    elif hs == "slick":
        k.add(shell("hair", r, (0, 0.01, hc + 0.005), hcol, (1.06, 1.04, 1.06),
                    [((0, -r, 0.50 * r), (0, 0.95 * r, 2 * r))]), "head")
        k.add(lib.ball("slick_ridge", r * 0.55, (0, -0.30 * r, hc + 0.78 * r), hcol, scale=(1.5, 1.2, 0.55)), "head")
    elif hs == "combover":
        k.add(shell("hair_ring", r, (0, 0.01, hc), hcol, (1.06, 1.04, 1.04),
                    [((0, 0, 0.10 * r), (0, 0, -1)), ((0, 0, -0.45 * r), (0, 0, 1)), ((0, -0.25 * r, 0), (0, 1, 0))]), "head")
        # three heroic strands: strips of a shell hugging the scalp, combed sideways
        for dy in (-0.32 * r, 0.0, 0.32 * r):
            strip = shell("strand", r, (0, 0.0, hc), hcol, (1.025, 1.0, 1.025),
                          [((0, 0, 0.55 * r), (0, 0, 1)), ((0, dy - 0.06 * r, 0), (0, 1, 0)), ((0, dy + 0.06 * r, 0), (0, -1, 0))])
            strip.rotation_euler = (0, 0, math.radians(14))
            k.add(strip, "head")
    elif hs == "bob":
        k.add(shell("hair", r, (0, 0.02, hc - 0.02), hcol, (1.13, 1.08, 1.12),
                    [((0, -0.50 * r, 0), (0, 1, -0.15)), ((0, 0, -0.80 * r), (0, 0, 1))]), "head")
        k.add(shell("hair_top", r, (0, 0.0, hc + 0.005), hcol, (1.08, 1.04, 1.08),
                    [((0, -r, 0.45 * r), (0, 0.9 * r, 2 * r))]), "head")
        k.add(lib.rbox("bangs", (r * 1.5, 0.08, 0.10), (0.0, face_y(0, 0.62 * r) - 0.01, hc + 0.62 * r), hcol, bevel=0.035,
                       segs=3, rot=(-10, 0, 0), smooth=True), "head")
    elif hs == "ponytail":
        k.add(shell("hair", r, (0, 0.01, hc + 0.005), hcol, (1.07, 1.04, 1.07),
                    [((0, -r, 0.42 * r), (0, 0.6 * r, 2 * r))]), "head")
        k.add(lib.ball("bun_band", 0.05, (0, r * 0.98, hc + 0.25 * r), "#e2475f"), "head")
        k.add(lib.ball("ponytail", 0.11, (0, r * 1.15, hc - 0.05), hcol, scale=(0.9, 0.8, 1.5)), "head")

    # --- props (separate meshes so Godot can toggle them)
    hR = L["hand.R"][0]
    if "cigarette" in s["props"]:
        cig = lib.cyl("Prop_Cigarette", 0.008, 0.09, (hR[0] + 0.03, hR[1] - 0.09, hR[2] - 0.06), "#f5f5f0",
                      segs=8, rot=(90, 0, 0))
        tip = lib.cyl("Prop_CigaretteTip", 0.0085, 0.012, (hR[0] + 0.03, hR[1] - 0.14, hR[2] - 0.06), "#ff6a1f",
                      segs=8, rot=(90, 0, 0), glow=4.0)
        lib.apply_transform(cig)
        lib.apply_transform(tip)
        cig = lib.join([cig, tip], "Prop_Cigarette")
        k.prop(cig, "hand.R")
    if "ladle" in s["props"]:
        handle = lib.cyl("Prop_Ladle", 0.012, 0.42, (hR[0] - 0.01, hR[1] - 0.03, hR[2] + 0.05), "#c9c9cf", segs=8)
        bowl = lib.ball("Prop_LadleBowl", 0.07, (hR[0] - 0.01, hR[1] - 0.03, hR[2] + 0.30), "#c9c9cf",
                        scale=(1, 1, 0.55))
        lib.apply_transform(handle)
        lib.apply_transform(bowl)
        k.prop(lib.join([handle, bowl], "Prop_Ladle"), "hand.R")
    return k


def bind(k, arm, name):
    for ob in k.parts + k.props:
        lib.apply_transform(ob)
    body = lib.join(k.parts, name + "_Body")
    for ob in [body] + k.props:
        ob.parent = arm
        mod = ob.modifiers.new("Armature", 'ARMATURE')
        mod.object = arm
    return body


# ---------------------------------------------------------------- animation

BONES = ["root", "hips", "spine", "head", "upper_arm.L", "forearm.L", "hand.L", "upper_arm.R", "forearm.R", "hand.R",
         "thigh.L", "shin.L", "foot.L", "thigh.R", "shin.R", "foot.R"]


def key_pose(arm, frame, pose):
    for b in BONES:
        pb = arm.pose.bones[b]
        p = pose.get(b, {})
        pb.rotation_euler = (math.radians(p.get("rx", 0)), math.radians(p.get("ry", 0)), math.radians(p.get("rz", 0)))
        pb.location = (p.get("lx", 0.0), p.get("ly", 0.0), p.get("lz", 0.0))
        pb.keyframe_insert("rotation_euler", frame=frame)
        pb.keyframe_insert("location", frame=frame)


def merge(*poses):
    out = {}
    for p in poses:
        for b, v in p.items():
            out.setdefault(b, {}).update(v)
    return out


def mirror(pose):
    """Swap L/R and flip the sideways/twist channels."""
    out = {}
    for b, v in pose.items():
        nb = b.replace(".L", ".TMP").replace(".R", ".L").replace(".TMP", ".R")
        nv = dict(v)
        for ch in ("ry", "rz"):
            if ch in nv:
                nv[ch] = -nv[ch]
        if "lx" in nv:
            nv["lx"] = -nv["lx"]
        out[nb] = nv
    return out


ARMS_DOWN = {"upper_arm.L": {"rz": -5}, "upper_arm.R": {"rz": 5}, "forearm.L": {"rx": -10}, "forearm.R": {"rx": -10}}


def walk_keys(amp=1.0, run=False):
    a = amp
    lean = 14 if run else 5
    fore = -75 if run else -18
    bob = 0.06 if run else 0.03
    contact = {
        "hips": {"ly": -bob, "ry": 6 * a},
        "spine": {"rx": lean, "ry": -8 * a},
        "head": {"rx": -lean * 0.6},
        "thigh.L": {"rx": -32 * a}, "shin.L": {"rx": 6},
        "thigh.R": {"rx": 26 * a}, "shin.R": {"rx": 22 * a}, "foot.R": {"rx": -10},
        "upper_arm.L": {"rx": 26 * a, "rz": -6}, "forearm.L": {"rx": fore * 0.6},
        "upper_arm.R": {"rx": -30 * a, "rz": 6}, "forearm.R": {"rx": fore},
    }
    passing = {
        "hips": {"ly": bob * 0.8},
        "spine": {"rx": lean},
        "head": {"rx": -lean * 0.6},
        "thigh.L": {"rx": 4}, "shin.L": {"rx": 4},
        "thigh.R": {"rx": -12 * a}, "shin.R": {"rx": (85 if run else 48) * a}, "foot.R": {"rx": 10},
        "upper_arm.L": {"rx": 2, "rz": -6}, "forearm.L": {"rx": fore * 0.8},
        "upper_arm.R": {"rx": -2, "rz": 6}, "forearm.R": {"rx": fore * 0.8},
    }
    n = 14 if run else 20
    q = n // 4
    return [(0, contact), (q, passing), (2 * q, mirror(contact)), (3 * q, mirror(passing)), (n, contact)]


def idle_keys(slump=6):
    a = merge(ARMS_DOWN, {"spine": {"rx": slump}, "head": {"rx": 3}})
    b = merge(ARMS_DOWN, {"spine": {"rx": slump + 3}, "hips": {"ly": -0.012}, "head": {"rx": 7, "rz": 3},
                          "upper_arm.L": {"rz": -7}, "upper_arm.R": {"rz": 7}})
    return [(0, a), (30, b), (60, a)]


def bow_keys():
    up = merge(ARMS_DOWN, {"spine": {"rx": 2}})
    down = {"spine": {"rx": 72}, "head": {"rx": 8}, "hips": {"lz": 0.06},
            "upper_arm.L": {"rx": -55, "rz": 8}, "upper_arm.R": {"rx": -55, "rz": -8},
            "forearm.L": {"rx": -20}, "forearm.R": {"rx": -20}}
    return [(0, up), (8, down), (28, down), (38, up)]


def talk_keys():
    a = merge(ARMS_DOWN, {"upper_arm.R": {"rx": -40, "rz": 10}, "forearm.R": {"rx": -70}, "hand.R": {"ry": 20},
                          "head": {"rx": -4, "ry": 6}, "spine": {"rx": 3}})
    b = merge(ARMS_DOWN, {"upper_arm.R": {"rx": -55, "rz": 22}, "forearm.R": {"rx": -50}, "hand.R": {"ry": -20},
                          "upper_arm.L": {"rx": -25, "rz": -18}, "forearm.L": {"rx": -55},
                          "head": {"rx": 4, "ry": -6}, "spine": {"rx": 5}})
    return [(0, a), (14, b), (28, a)]


def angry_keys():
    base = {"spine": {"rx": 10}, "upper_arm.R": {"rx": -120, "rz": 12}, "forearm.R": {"rx": -60},
            "upper_arm.L": {"rx": 10, "rz": -40}, "forearm.L": {"rx": -110}, "head": {"rx": -10}}
    a = merge(base, {"hand.R": {"rx": 15}, "head": {"ry": 10}, "hips": {"ly": 0.0}})
    b = merge(base, {"hand.R": {"rx": -15}, "upper_arm.R": {"rx": -130}, "head": {"ry": -10}, "hips": {"ly": -0.03},
                     "thigh.L": {"rx": -25}, "shin.L": {"rx": 45}})
    return [(0, a), (5, b), (10, a), (15, b), (20, a)]


def smoke_keys():
    hold = merge(ARMS_DOWN, {"upper_arm.R": {"rx": -22, "rz": -6}, "forearm.R": {"rx": -70}, "spine": {"rx": 4},
                             "upper_arm.L": {"rz": -4, "rx": 8}})
    puff = merge(hold, {"upper_arm.R": {"rx": -48, "rz": -22}, "forearm.R": {"rx": -128}, "head": {"rx": 3}})
    exhale = merge(hold, {"head": {"rx": -16}, "spine": {"rx": -2}})
    return [(0, hold), (18, puff), (36, puff), (52, hold), (64, exhale), (88, exhale), (100, hold)]


def type_keys():
    base = {"spine": {"rx": 12}, "head": {"rx": 10},
            "upper_arm.L": {"rx": -38, "rz": 8}, "upper_arm.R": {"rx": -38, "rz": -8},
            "forearm.L": {"rx": -55}, "forearm.R": {"rx": -55}}
    a = merge(base, {"forearm.L": {"rx": -62}, "forearm.R": {"rx": -50}})
    b = merge(base, {"forearm.L": {"rx": -50}, "forearm.R": {"rx": -62}})
    return [(0, a), (3, b), (6, a), (9, b), (12, a)]


SIT = {"hips": {"ly": -0.36, "lz": 0.05}, "thigh.L": {"rx": -88}, "thigh.R": {"rx": -88},
       "shin.L": {"rx": 88}, "shin.R": {"rx": 88}, "spine": {"rx": 4},
       "upper_arm.L": {"rx": -22, "rz": -4}, "upper_arm.R": {"rx": -22, "rz": 4},
       "forearm.L": {"rx": -50}, "forearm.R": {"rx": -50}}


def sit_keys():
    a = SIT
    b = merge(SIT, {"spine": {"rx": 7}, "head": {"rx": 5}})
    return [(0, a), (40, b), (80, a)]


def sit_type_keys():
    return [(f, merge(SIT, {k: v for k, v in p.items() if k not in ("hips",)})) for f, p in type_keys()]


def freakout_keys():
    a = {"hips": {"ly": 0.10}, "spine": {"rx": -8, "ry": 12}, "head": {"rx": -18, "ry": -22},
         "upper_arm.L": {"rx": -165, "rz": -25}, "upper_arm.R": {"rx": -130, "rz": 35},
         "forearm.L": {"rx": -30}, "forearm.R": {"rx": 10},
         "thigh.L": {"rx": -30}, "shin.L": {"rx": 50}, "thigh.R": {"rx": 10}}
    b = {"hips": {"ly": -0.02}, "spine": {"rx": 6, "ry": -12}, "head": {"rx": -10, "ry": 22},
         "upper_arm.L": {"rx": -130, "rz": -35}, "upper_arm.R": {"rx": -165, "rz": 25},
         "forearm.L": {"rx": 10}, "forearm.R": {"rx": -30},
         "thigh.R": {"rx": -30}, "shin.R": {"rx": 50}, "thigh.L": {"rx": 10}}
    return [(0, a), (5, b), (10, a)]


ANIMS = {
    "Idle": idle_keys,
    "Walk": lambda: walk_keys(1.0),
    "Run": lambda: walk_keys(1.25, run=True),
    "Bow": bow_keys,
    "Talk": talk_keys,
    "Angry": angry_keys,
    "Smoke": smoke_keys,
    "Type": type_keys,
    "Sit": sit_keys,
    "SitType": sit_type_keys,
    "Freakout": freakout_keys,
}


def build_actions(arm, cid):
    arm.animation_data_create()
    made = []
    for name, fn in ANIMS.items():
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        arm.animation_data.action = act
        for frame, pose in fn():
            key_pose(arm, frame, pose)
        made.append(act)
    arm.animation_data.action = bpy.data.actions["Idle"]
    for pb in arm.pose.bones:
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    return made


# ---------------------------------------------------------------- main

def build(cid, offset_x=0.0, with_anims=True):
    s = dict(BASE)
    s.update(CAST[cid])
    L = bone_layout(s)
    arm = build_armature(cid, L)
    k = build_body(cid, s, L)
    bind(k, arm, cid)
    if with_anims:
        build_actions(arm, cid)
    arm.location.x = offset_x
    return arm


def main():
    args = lib.script_args()
    preview_dir = args[args.index("--preview") + 1] if "--preview" in args else None
    only = args[args.index("--only") + 1].split(",") if "--only" in args else list(CAST.keys())
    for cid in only:
        lib.reset()
        arm = build(cid)
        lib.export_glb("%s.glb" % cid, animations=True)
        if preview_dir:
            os.makedirs(preview_dir, exist_ok=True)
            arm.animation_data.action = bpy.data.actions["Idle"]
            lib.preview(os.path.join(preview_dir, "%s_front.png" % cid), (1.6, -3.4, 1.5), (0, 0, 1.0), lens=45, frame=0)
            for anim, f in (("Walk", 0), ("Walk", 5), ("Run", 0), ("Bow", 14), ("Smoke", 25), ("Freakout", 2),
                            ("Sit", 0), ("Angry", 5)):
                arm.animation_data.action = bpy.data.actions[anim]
                lib.preview(os.path.join(preview_dir, "%s_%s_%d.png" % (cid, anim, f)), (3.6, -2.4, 1.3), (0, 0, 0.9),
                            lens=40, frame=f, res=(480, 480))
    if preview_dir and len(only) > 1:
        lib.reset()
        for i, cid in enumerate(only):
            build(cid, offset_x=(i - (len(only) - 1) / 2) * 1.1, with_anims=False)
        lib.preview(os.path.join(preview_dir, "lineup.png"), (0.6, -6.5, 1.6), (0, 0, 1.0), lens=38, res=(1280, 640))


main()

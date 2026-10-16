"""Shared helpers for the Blender build scripts.

Every build script runs headless:
    blender --background --factory-startup --python blender/<script>.py

Conventions
- Blender is Z-up, characters face -Y. glTF export converts to Godot's Y-up
  (Blender (x, y, z) -> Godot (x, z, -y)), so -Y front becomes Godot +Z,
  which is Godot's model-front convention.
- Colors are written as sRGB hex and converted to linear here.
- Objects named "*-col" get visible mesh + trimesh collision on Godot import,
  "*-colonly" get collision only (mesh hidden).
- Objects whose name starts with "Arch_" are architecture (floors, walls,
  ceilings); the Godot toon kit skips outlines on them.
- Every mesh gets an "OutlineN" color attribute holding smoothed normals, so
  the Godot outline shader can push a hull out without cracking at hard edges.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS = os.path.join(ROOT, "assets", "models")


def script_args():
    a = sys.argv
    return a[a.index("--") + 1:] if "--" in a else []


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATS.clear()


# ---------------------------------------------------------------- materials

def srgb_to_linear(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


_MATS = {}


def mat(color, glow=0.0, rough=0.9, alpha=1.0, name=None):
    """Flat cartoon material. glow > 0 makes it emissive (signs, lamps)."""
    key = (color, glow, rough, alpha, name)
    if key in _MATS:
        return _MATS[key]
    lin = srgb_to_linear(color)
    m = bpy.data.materials.new(name or "M_%s%s%s" % (color.lstrip("#"), "_glow" if glow else "", "_clear" if alpha < 1 else ""))
    m.diffuse_color = (*lin, alpha)  # workbench preview colour
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*lin, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = 0.0
    if glow > 0:
        bsdf.inputs["Emission Color"].default_value = (*lin, 1.0)
        bsdf.inputs["Emission Strength"].default_value = glow
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        for attr, val in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
            try:
                setattr(m, attr, val)
            except Exception:
                pass
    _MATS[key] = m
    return m


# ---------------------------------------------------------------- mesh building

def _collection(name=None):
    if name is None:
        return bpy.context.scene.collection
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(c)
    return c


def _finish(name, bm, material, loc, rot, smooth, coll=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    me.materials.append(material)
    ob = bpy.data.objects.new(name, me)
    _collection(coll).objects.link(ob)
    ob.location = loc
    ob.rotation_euler = Euler([math.radians(a) for a in rot])
    return ob


def rbox(name, size, loc, color, bevel=0.03, segs=2, rot=(0, 0, 0), taper=None, smooth=False,
         glow=0.0, alpha=1.0, coll=None, material=None):
    """Rounded box. size is full extents. taper=(sx, sy) scales the top face."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    if taper:
        for v in bm.verts:
            if v.co.z > 0:
                v.co.x *= taper[0]
                v.co.y *= taper[1]
    if bevel > 0:
        b = min(bevel, min(size) * 0.45)
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=b, segments=segs, affect='EDGES', profile=0.5,
                        clamp_overlap=True)
    return _finish(name, bm, material or mat(color, glow=glow, alpha=alpha), loc, rot, smooth, coll)


def ball(name, radius, loc, color, scale=(1, 1, 1), segs=14, rings=9, rot=(0, 0, 0), smooth=True,
         glow=0.0, coll=None, material=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=radius)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    return _finish(name, bm, material or mat(color, glow=glow), loc, rot, smooth, coll)


def cyl(name, radius, depth, loc, color, segs=12, rot=(0, 0, 0), radius2=None, smooth=True, glow=0.0,
        alpha=1.0, coll=None, material=None, cap=True):
    """Cylinder (or cone when radius2 differs) standing on Z, centred at loc."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=segs, radius1=radius,
                          radius2=radius if radius2 is None else radius2, depth=depth)
    ob = _finish(name, bm, material or mat(color, glow=glow, alpha=alpha), loc, rot, smooth, coll)
    if smooth:
        # Keep caps flat-looking: mark cap faces flat.
        for p in ob.data.polygons:
            if abs(p.normal.z) > 0.9:
                p.use_smooth = False
    return ob


def poly_prism(name, points, height, loc, color, rot=(0, 0, 0), coll=None, material=None):
    """Extrude a 2D outline (list of (x, y)) up by height."""
    bm = bmesh.new()
    verts = [bm.verts.new((x, y, 0)) for x, y in points]
    face = bm.faces.new(verts)
    if face.normal.z < 0:
        face.normal_flip()
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    top = [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=(0, 0, height), verts=top)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish(name, bm, material or mat(color), loc, rot, False, coll)


def collider(name, size, loc, rot=(0, 0, 0)):
    """Invisible box collision."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    return _finish(name + "-colonly", bm, mat("#ff00ff", name="M_Collider"), loc, rot, False)


def empty(name, loc, rot=(0, 0, 0)):
    ob = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = Euler([math.radians(a) for a in rot])
    return ob


def parent(child, par):
    mw = child.matrix_world.copy()
    child.parent = par
    child.matrix_world = mw
    return child


def apply_transform(ob):
    me = ob.data
    me.transform(ob.matrix_basis)
    ob.matrix_basis = Matrix.Identity(4)


def join(objs, name):
    """Join mesh objects into the first one."""
    objs = [o for o in objs if o is not None]
    target = objs[0]
    with bpy.context.temp_override(active_object=target, object=target,
                                   selected_objects=objs, selected_editable_objects=objs):
        bpy.ops.object.join()
    target.name = name
    target.data.name = name
    return target


# ---------------------------------------------------------------- outline normals

def bake_outline_normals(ob):
    """Store position-welded smooth normals in an 'OutlineN' color attribute."""
    if ob.type != 'MESH':
        return
    me = ob.data
    acc = {}
    for p in me.polygons:
        for vi in p.vertices:
            key = tuple(round(c, 4) for c in me.vertices[vi].co)
            acc[key] = acc.get(key, Vector()) + p.normal * p.area
    if "OutlineN" in me.color_attributes:
        me.color_attributes.remove(me.color_attributes["OutlineN"])
    attr = me.color_attributes.new(name="OutlineN", type='FLOAT_COLOR', domain='CORNER')
    for loop in me.loops:
        key = tuple(round(c, 4) for c in me.vertices[loop.vertex_index].co)
        n = acc.get(key, Vector((0, 0, 1)))
        n = n.normalized() if n.length > 1e-6 else Vector((0, 0, 1))
        # glTF converts positions/normals to Y-up but not colours, so store
        # the normal already in Godot's frame: (x, z, -y).
        attr.data[loop.index].color = (n.x * 0.5 + 0.5, n.z * 0.5 + 0.5, -n.y * 0.5 + 0.5, 1.0)
    me.color_attributes.active_color = attr


def bake_all_outlines():
    for ob in bpy.data.objects:
        if ob.type == 'MESH' and not ob.name.endswith("-colonly"):
            # Normals live in object space; apply scale so they stay right.
            bake_outline_normals(ob)


# ---------------------------------------------------------------- export

def export_glb(filename, animations=False):
    os.makedirs(MODELS, exist_ok=True)
    path = os.path.join(MODELS, filename)
    kw = dict(
        filepath=path,
        export_format='GLB',
        use_selection=False,
        export_apply=True,
        export_yup=True,
        export_animations=animations,
        export_animation_mode='ACTIONS',
        export_force_sampling=True,
        export_frame_range=False,
        export_anim_slide_to_zero=True,
        export_vertex_color='NAME',
        export_vertex_color_name="OutlineN",
        export_all_vertex_colors=False,
        export_lights=False,
        export_cameras=False,
        export_extras=False,
        export_skins=True,
        export_morph=False,
        export_image_format='NONE',
    )
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    kw = {k: v for k, v in kw.items() if k in props}
    bpy.ops.export_scene.gltf(**kw)
    print("[export] %s" % path)
    return path


# ---------------------------------------------------------------- preview renders

def preview(path, cam_loc, look_at, lens=40, res=(960, 720), frame=None, ortho=None):
    """Workbench render for eyeballing shapes from a headless run."""
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'MATERIAL'
    scene.display.shading.show_cavity = True
    scene.display.shading.show_object_outline = True
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.film_transparent = False
    world = scene.world or bpy.data.worlds.new("W")
    scene.world = world
    cam = bpy.data.objects.get("PreviewCam")
    if cam is None:
        cam = bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
        scene.collection.objects.link(cam)
    cam.data.lens = lens
    if ortho:
        cam.data.type = 'ORTHO'
        cam.data.ortho_scale = ortho
    else:
        cam.data.type = 'PERSP'
    cam.location = cam_loc
    d = Vector(look_at) - Vector(cam_loc)
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    cam.data.clip_end = 500
    scene.camera = cam
    hidden = []
    for ob in bpy.data.objects:
        if ob.name.endswith("-colonly") or ob.name.startswith("Arch_Ceiling"):
            ob.hide_render = True
            hidden.append(ob)
    if frame is not None:
        scene.frame_set(frame)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    for ob in hidden:
        ob.hide_render = False
    print("[preview] %s" % path)


def remove_preview_cam():
    cam = bpy.data.objects.get("PreviewCam")
    if cam:
        bpy.data.objects.remove(cam)

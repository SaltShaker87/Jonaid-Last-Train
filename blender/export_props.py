"""
Blender prop pipe — GDD §17 content pipe + §16 art pass.
Palette: espresso, antique gold, ivory, oxblood, subway gray.
Fluorescent office / tungsten home. DO NOT COPY stays readable (Godot Label3D
over an ivory plate; Blender keeps an oxblood stamp bar as proxy).

Usage:
  /Applications/Blender.app/Contents/MacOS/Blender --background --python blender/export_props.py

Output: assets/models/*.glb with SOCKET_* empties. Godot places from
tools/place_manifest.json, graybox fallback otherwise.
Fictional Hansung only. No real badges/marks.
"""
import os
import bpy

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "models")
os.makedirs(OUT, exist_ok=True)

PAL = {
    "espresso": (0.14, 0.11, 0.09),
    "suit": (0.23, 0.22, 0.25),
    "gold": (0.85, 0.66, 0.25),
    "ivory": (0.91, 0.87, 0.77),
    "oxblood": (0.45, 0.08, 0.10),
    "subway": (0.55, 0.56, 0.58),
    "subway_dark": (0.32, 0.33, 0.35),
    "glass_blue": (0.55, 0.68, 0.78),
    "water": (0.25, 0.45, 0.60),
    "tungsten": (1.0, 0.85, 0.62),
    "cool": (0.90, 0.95, 1.0),
    "tire": (0.05, 0.05, 0.05),
    "skin": (0.93, 0.78, 0.66),
    "hair": (0.08, 0.07, 0.07),
    "couch": (0.52, 0.36, 0.28),
    "wood": (0.42, 0.30, 0.20),
}

def clear():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for coll in (bpy.data.meshes, bpy.data.materials):
        for x in list(coll):
            try:
                coll.remove(x)
            except Exception:
                pass

def mat(name, rgb, emission=None, emission_strength=0.0, roughness=0.8, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        if "Roughness" in bsdf.inputs:
            bsdf.inputs["Roughness"].default_value = roughness
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = metallic
        if emission is not None and "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = emission_strength
    return m

def bevel(obj, width=0.02, segments=2):
    try:
        mod = obj.modifiers.new("ArtBevel", 'BEVEL')
        mod.width = width
        mod.segments = segments
        mod.limit_method = 'ANGLE'
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
        # Shade smooth for hero props; flat faces stay crisp via angle limit.
        for poly in obj.data.polygons:
            poly.use_smooth = True
    except Exception as e:
        print("bevel skip", obj.name, e)

def box(name, size, loc, material=None, bevel_w=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = (size[0], size[1], size[2])
    bpy.ops.object.transform_apply(scale=True)
    if material:
        o.data.materials.append(material)
    if bevel_w > 0:
        bevel(o, bevel_w)
    return o

def cyl(name, r, h, loc, material=None):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, location=loc)
    o = bpy.context.active_object
    o.name = name
    if material:
        o.data.materials.append(material)
    return o

def sphere(name, r, loc, material=None):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc)
    o = bpy.context.active_object
    o.name = name
    if material:
        o.data.materials.append(material)
    return o

def socket(name, loc=(0, 0, 0)):
    bpy.ops.object.empty_add(location=loc)
    e = bpy.context.active_object
    e.name = "SOCKET_" + name
    return e

def export(name):
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True)
    print("exported", path)

def select_all():
    bpy.ops.object.select_all(action='SELECT')

# --- hero props (dressed) ---

def build_copier():
    clear()
    body_m = mat("CopierBody", PAL["subway"], roughness=0.6)
    dark_m = mat("CopierDark", PAL["espresso"], roughness=0.7)
    glass_m = mat("CopierGlass", PAL["glass_blue"], roughness=0.2)
    gold_m = mat("CopierGold", PAL["gold"], metallic=0.6, roughness=0.35)
    body = box("CopierBody", (1.15, 0.95, 1.25), (0, 0.62, 0), body_m, 0.03)
    box("CopierTop", (1.05, 0.10, 1.05), (0, 1.14, 0), dark_m, 0.015)
    box("CopierGlass", (0.85, 0.025, 0.65), (-0.05, 1.20, 0), glass_m)
    # Paper tray with ivory stack (the map goes here).
    box("PaperTray", (0.7, 0.10, 0.5), (0, 0.35, 0.68), dark_m, 0.01)
    box("PaperStack", (0.6, 0.08, 0.42), (0, 0.44, 0.68), mat("Paper", PAL["ivory"], roughness=0.9))
    # Jam door ajar + gold latch + button row.
    jam = box("JamDoor", (0.06, 0.55, 0.75), (0.60, 0.62, 0), dark_m, 0.01)
    jam.rotation_euler = (0, 0.25, 0)
    box("JamLatch", (0.04, 0.08, 0.12), (0.64, 0.70, 0.25), gold_m)
    for i in range(3):
        box(f"CopierBtn{i}", (0.08, 0.03, 0.08), (-0.35 + i * 0.15, 1.20, -0.42), gold_m if i == 1 else dark_m)
    # Fluorescent status strip (cool emission).
    box("CopierStrip", (0.9, 0.04, 0.04), (0, 1.02, 0.64), mat("Strip", PAL["cool"], emission=PAL["cool"], emission_strength=2.0, roughness=0.4))
    socket("copier", (0, 0, 1.0))
    select_all()
    export("copier")

def build_tank():
    clear()
    stand_m = mat("TankStand", PAL["espresso"], roughness=0.7)
    glass_m = mat("TankGlass", PAL["glass_blue"], roughness=0.15)
    glass_m.blend_method = 'BLEND'
    water_m = mat("TankWater", PAL["water"], roughness=0.3)
    gold_m = mat("BubblesGold", (0.95, 0.55, 0.20), roughness=0.5)
    # Stand + glass + water with more presence.
    box("TankBase", (1.7, 0.12, 0.9), (0, 0.06, 0), stand_m, 0.01)
    box("TankGlass", (1.7, 1.05, 0.9), (0, 0.65, 0), glass_m, 0.02)
    box("TankWater", (1.58, 0.72, 0.78), (0, 0.55, 0), water_m)
    # Gravel bed + plant.
    box("Gravel", (1.58, 0.08, 0.78), (0, 0.22, 0), mat("Gravel", (0.35, 0.30, 0.25), roughness=0.95))
    cyl("Plant", 0.03, 0.45, (-0.5, 0.45, 0), mat("Plant", (0.25, 0.5, 0.30), roughness=0.8))
    # Chairman Bubbles: body + tail + eye. Quiet, no jump scare.
    body = sphere("Bubbles", 0.10, (0.25, 0.60, 0.05), gold_m)
    body.scale = (1.3, 0.9, 0.8)
    bpy.ops.object.transform_apply(scale=True)
    tail = box("BubblesTail", (0.10, 0.12, 0.02), (0.10, 0.60, 0.05), gold_m)
    tail.rotation_euler = (0, 0, 0.5)
    sphere("BubblesEye", 0.018, (0.33, 0.63, 0.11), mat("Eye", (0.02, 0.02, 0.02), roughness=0.3))
    # Filter + prime bulb + tungsten tank light.
    box("FilterBox", (0.28, 0.45, 0.28), (-0.62, 0.55, 0), mat("Filter", PAL["subway_dark"], roughness=0.7), 0.01)
    sphere("PrimeBulb", 0.07, (-0.62, 0.85, 0.18), mat("Bulb", PAL["gold"], roughness=0.4))
    box("TankLight", (1.5, 0.05, 0.15), (0, 1.20, 0), mat("TankLight", PAL["tungsten"], emission=PAL["tungsten"], emission_strength=2.5, roughness=0.4))
    # Plug + cord path (the filter has a plug — GDD).
    box("Plug", (0.10, 0.08, 0.06), (0.9, 0.15, 0.3), mat("Plug", PAL["espresso"]))
    socket("tank", (0, 0, 0.7))
    select_all()
    export("tank")

def build_couch():
    clear()
    fabric_m = mat("CouchFabric", PAL["couch"], roughness=0.95)
    dark_m = mat("CouchDark", PAL["espresso"], roughness=0.85)
    cushion_m = mat("Cushion", (0.62, 0.45, 0.34), roughness=0.95)
    box("CouchSeat", (2.5, 0.45, 1.25), (0, 0.35, 0), fabric_m, 0.04)
    box("CouchBack", (2.5, 0.95, 0.32), (0, 0.72, -0.58), fabric_m, 0.04)
    box("CouchArmL", (0.32, 0.72, 1.25), (-1.28, 0.52, 0), fabric_m, 0.04)
    box("CouchArmR", (0.32, 0.72, 1.25), (1.28, 0.52, 0), fabric_m, 0.04)
    # Two cushions + throw blanket (anime-night dressing) + short legs.
    box("CushionL", (1.05, 0.18, 0.95), (-0.58, 0.62, 0.05), cushion_m, 0.05)
    box("CushionR", (1.05, 0.18, 0.95), (0.58, 0.62, 0.05), cushion_m, 0.05)
    throw_m = mat("Throw", PAL["oxblood"], roughness=0.95)
    throw = box("Throw", (0.8, 0.06, 1.0), (0.6, 0.72, 0.1), throw_m, 0.03)
    throw.rotation_euler = (0, 0.15, 0)
    for x, z in ((-1.1, 0.45), (1.1, 0.45), (-1.1, -0.45), (1.1, -0.45)):
        cyl("CouchLeg", 0.04, 0.12, (x, 0.06, z), dark_m)
    socket("couch", (0, 0, 1.0))
    select_all()
    export("couch")

def build_sedan():
    # Legally distinct black sedan. No badges. Espresso-black + gold trim hint.
    clear()
    paint_m = mat("SedanPaint", (0.07, 0.07, 0.08), roughness=0.3, metallic=0.4)
    glass_m = mat("SedanGlass", (0.25, 0.30, 0.38), roughness=0.15, metallic=0.2)
    tire_m = mat("Tire", PAL["tire"], roughness=0.9)
    hub_m = mat("Hub", PAL["subway"], roughness=0.4, metallic=0.6)
    light_m = mat("Headlight", PAL["tungsten"], emission=PAL["tungsten"], emission_strength=3.0, roughness=0.3)
    tail_m = mat("Taillight", PAL["oxblood"], emission=PAL["oxblood"], emission_strength=2.0, roughness=0.3)
    box("SedanLower", (4.5, 0.65, 1.85), (0, 0.62, 0), paint_m, 0.06)
    box("SedanBelt", (4.45, 0.18, 1.88), (0, 0.98, 0), paint_m, 0.04)
    cabin = box("SedanCabin", (2.3, 0.62, 1.62), (-0.2, 1.35, 0), glass_m, 0.08)
    box("SedanRoof", (1.9, 0.08, 1.5), (-0.2, 1.68, 0), paint_m, 0.03)
    # Gold side trim (rental-desk luxury hint, not a badge).
    box("SideTrim", (4.0, 0.05, 0.02), (0, 0.78, 0.94), mat("Trim", PAL["gold"], metallic=0.7, roughness=0.3))
    box("SideTrim2", (4.0, 0.05, 0.02), (0, 0.78, -0.94), mat("Trim", PAL["gold"], metallic=0.7, roughness=0.3))
    box("HeadlightL", (0.12, 0.14, 0.35), (2.26, 0.72, 0.55), light_m)
    box("HeadlightR", (0.12, 0.14, 0.35), (2.26, 0.72, -0.55), light_m)
    box("TaillightL", (0.10, 0.12, 0.35), (-2.26, 0.75, 0.55), tail_m)
    box("TaillightR", (0.10, 0.12, 0.35), (-2.26, 0.75, -0.55), tail_m)
    for x, z in ((1.45, 0.95), (1.45, -0.95), (-1.45, 0.95), (-1.45, -0.95)):
        w = cyl("Wheel", 0.36, 0.26, (x, 0.36, z), tire_m)
        w.rotation_euler = (1.5708, 0, 0)
        hub = cyl("Hub", 0.16, 0.27, (x, 0.36, z), hub_m)
        hub.rotation_euler = (1.5708, 0, 0)
    socket("sedan", (0, 0, 1.6))
    select_all()
    export("sedan")

def build_lightbox():
    clear()
    frame_m = mat("LBFrame", PAL["espresso"], roughness=0.6)
    glow_m = mat("LBGlow", PAL["ivory"], emission=PAL["ivory"], emission_strength=1.8, roughness=0.5)
    stamp_m = mat("Stamp", PAL["oxblood"], roughness=0.6)
    box("LBBase", (1.5, 0.12, 1.05), (0, 0.06, 0), frame_m, 0.015)
    box("LBGlow", (1.3, 0.05, 0.9), (0, 0.14, 0), glow_m)
    box("LBFrameN", (1.5, 0.06, 0.06), (0, 0.16, 0.50), frame_m)
    box("LBFrameS", (1.5, 0.06, 0.06), (0, 0.16, -0.50), frame_m)
    # Stamp bar + corner ticks so the prohibition reads even in thumbnail.
    box("StampBar", (0.95, 0.03, 0.20), (0, 0.18, 0.22), stamp_m)
    box("StampBar2", (0.95, 0.03, 0.04), (0, 0.18, -0.18), stamp_m)
    socket("lightbox", (0, 0, 0.8))
    select_all()
    export("lightbox")

def build_cabinet():
    clear()
    wood_m = mat("CabinetWood", PAL["wood"], roughness=0.7)
    gold_m = mat("CabinetGold", PAL["gold"], metallic=0.5, roughness=0.4)
    sad_m = mat("SadShelf", PAL["subway"], roughness=0.8)
    box("CabinetBody", (2.1, 2.05, 0.65), (0, 1.02, 0), wood_m, 0.02)
    box("CabinetTop", (2.2, 0.08, 0.72), (0, 2.08, 0), wood_m, 0.015)
    # Good cabinet (gold rail) vs sad shelf.
    box("GoodShelf", (1.9, 0.06, 0.55), (-0.0, 1.45, 0.02), gold_m)
    box("GoodRail", (1.9, 0.05, 0.05), (0, 1.55, 0.28), gold_m)
    box("SadShelf", (1.9, 0.06, 0.55), (0, 0.62, 0.02), sad_m)
    # Quiet filter box + noodles cup (sad shelf dressing) + grace hook.
    box("QuietFilter", (0.4, 0.3, 0.3), (-0.6, 1.65, 0.05), mat("FilterBox", PAL["subway_dark"], roughness=0.7), 0.01)
    cyl("Noodles", 0.09, 0.12, (0.6, 0.71, 0.05), mat("Noodles", PAL["oxblood"], roughness=0.8))
    hook = cyl("GraceHook", 0.03, 0.16, (0.85, 1.65, 0.35), gold_m)
    hook.rotation_euler = (1.2, 0, 0)
    socket("cabinet", (0, 0, 0.7))
    select_all()
    export("cabinet")

def build_heads():
    # Five expression heads: neutral / tired / warm-worry / shake / borrowed.
    # Godot drives brows+tint live; these are Blender reference sculpts + fallback.
    clear()
    skin_m = mat("Skin", PAL["skin"], roughness=0.65)
    hair_m = mat("Hair", PAL["hair"], roughness=0.9)
    names = ["Neutral", "Tired", "Worry", "Shake", "Borrowed"]
    for i, nm in enumerate(names):
        x = float(i - 2) * 0.7
        h = sphere(f"Head_{nm}", 0.21, (x, 0.3, 0), skin_m)
        cap = sphere(f"Hair_{nm}", 0.215, (x, 0.36, -0.02), hair_m)
        cap.scale = (1.0, 0.7, 1.0)
        bpy.ops.object.transform_apply(scale=True)
        # Brow tilt increases with index (matches Salaryman._update_face).
        for sx in (-0.07, 0.07):
            b = box(f"Brow_{nm}_{'L' if sx < 0 else 'R'}", (0.09, 0.018, 0.015), (x + sx, 0.38, 0.19), hair_m)
            b.rotation_euler = (0, 0, 0.12 * i * (-1.0 if sx < 0 else 1.0))
    socket("heads", (0, 0, 0.5))
    select_all()
    export("heads")

def build_busts():
    # Four boss busts: Park (square+gold), Choi (tall+oxblood), Sora, Hana.
    clear()
    specs = [
        ("Park", (0.16, 0.16, 0.18), PAL["gold"], 0.9),
        ("Choi", (0.20, 0.18, 0.20), PAL["oxblood"], 0.82),
        ("Sora", (0.55, 0.38, 0.30), PAL["ivory"], 0.62),
        ("Hana", (0.50, 0.40, 0.35), PAL["ivory"], 0.60),
    ]
    for i, (nm, suit, trim, w) in enumerate(specs):
        x = float(i - 1.5) * 1.1
        box(f"Bust_{nm}_Torso", (w, 0.7, 0.45), (x, 0.45, 0), mat(f"Suit_{nm}", suit, roughness=0.85), 0.02)
        box(f"Bust_{nm}_Trim", (0.10, 0.4, 0.03), (x, 0.45, 0.24), mat(f"Trim_{nm}", trim, roughness=0.5))
        sphere(f"Bust_{nm}_Head", 0.19, (x, 1.0, 0), mat(f"Skin_{nm}", PAL["skin"], roughness=0.65))
        sphere(f"Bust_{nm}_Hair", 0.195, (x, 1.06, -0.02), mat(f"Hair_{nm}", PAL["hair"], roughness=0.9))
    socket("busts", (0, 0, 0.5))
    select_all()
    export("busts")

if __name__ == "__main__":
    for fn in (build_copier, build_tank, build_couch, build_sedan, build_lightbox, build_cabinet, build_heads, build_busts):
        try:
            fn()
        except Exception as e:
            print("FAILED", fn.__name__, e)
    print("DONE ->", OUT)

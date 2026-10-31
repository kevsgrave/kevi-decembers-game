"""Builds four kid-friendly Jeff models in different art styles and renders previews.

Styles: 1 Toy (matches the guest kids), 2 Blocky (classic Roblox R15),
3 Cartoon (toon shaded with ink outlines), 4 Plush (stitched felt doll).

Run: blender -b --python jeff_styles.py -- <out_dir>
Each style is one collection; part objects are named after their R15 segment
(e.g. "Toy_Head_hair") so they can be rigged for Roblox later.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

if "OUT_DIR" in globals():
    OUT = OUT_DIR
else:
    OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.dirname(os.path.abspath(__file__))
HQ = globals().get("HQ", False)
Q = 2 if HQ else 1  # mesh density / resolution multiplier
os.makedirs(OUT, exist_ok=True)


def lin(hexstr):
    h = hexstr.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


# ---------------------------------------------------------------- materials
_mats = {}


def mat(key, color, rough=0.6, emit=0.0, coat=0.0, sheen=0.0, bump=0.0):
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = lin(color)
    b.inputs["Roughness"].default_value = rough
    if coat:
        b.inputs["Coat Weight"].default_value = coat
        b.inputs["Coat Roughness"].default_value = 0.15
    if sheen:
        b.inputs["Sheen Weight"].default_value = sheen
        b.inputs["Sheen Roughness"].default_value = 0.35
        b.inputs["Sheen Tint"].default_value = (1, 1, 1, 1)
    if emit:
        b.inputs["Emission Color"].default_value = lin(color)
        b.inputs["Emission Strength"].default_value = emit
    if bump:
        tc = nt.nodes.new("ShaderNodeTexCoord")
        nz = nt.nodes.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = 180.0
        nz.inputs["Detail"].default_value = 4.0
        bp = nt.nodes.new("ShaderNodeBump")
        bp.inputs["Strength"].default_value = bump
        bp.inputs["Distance"].default_value = 0.02
        nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
        nt.links.new(nz.outputs["Fac"], bp.inputs["Height"])
        nt.links.new(bp.outputs["Normal"], b.inputs["Normal"])
    m.diffuse_color = lin(color)
    _mats[key] = m
    return m


def toon(key, color, shade=None):
    """Two-band cel shading (EEVEE): lit colour and a cooler shadow colour."""
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        if n.type != "OUTPUT_MATERIAL":
            nt.nodes.remove(n)
    out = [n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"][0]
    dif = nt.nodes.new("ShaderNodeBsdfDiffuse")
    s2r = nt.nodes.new("ShaderNodeShaderToRGB")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    c = lin(color)
    sh = lin(shade) if shade else (c[0] * 0.55, c[1] * 0.5, c[2] * 0.68, 1)
    ramp.color_ramp.elements[0].color = sh
    ramp.color_ramp.elements[1].position = 0.12
    ramp.color_ramp.elements[1].color = c
    # small highlight band
    e = ramp.color_ramp.elements.new(0.75)
    e.color = tuple(min(1.0, v * 1.12) for v in c[:3]) + (1,)
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(dif.outputs[0], s2r.inputs[0])
    nt.links.new(s2r.outputs["Color"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], em.inputs["Color"])
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    m.diffuse_color = c
    _mats[key] = m
    return m


def ink():
    if "Ink outline" in _mats:
        return _mats["Ink outline"]
    m = bpy.data.materials.new("Ink outline")
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = lin("#15101E")
    b.inputs["Roughness"].default_value = 1.0
    b.inputs["Emission Color"].default_value = lin("#15101E")
    b.inputs["Emission Strength"].default_value = 1.0
    m.use_backface_culling = True
    m.diffuse_color = lin("#15101E")
    _mats["Ink outline"] = m
    return m


# ---------------------------------------------------------------- builder
class Model:
    def __init__(self, name, origin):
        self.name = name
        self.origin = Vector(origin)
        self.coll = bpy.data.collections.new(f"Jeff_{name}")
        bpy.context.scene.collection.children.link(self.coll)
        self.root = bpy.data.objects.new(f"Jeff_{name}", None)
        self.coll.objects.link(self.root)
        self.root.location = self.origin
        self.objs = []

    def _fin(self, o, seg, material, smooth=True):
        for c in o.users_collection:
            c.objects.unlink(o)
        self.coll.objects.link(o)
        o.name = f"{self.name}_{seg}"
        if material is not None:
            o.data.materials.append(material)
        if smooth and o.type == "MESH":
            for p in o.data.polygons:
                p.use_smooth = True
        # parent to root while keeping world transform
        mw = o.matrix_world.copy()
        o.parent = self.root
        o.matrix_world = mw
        self.objs.append(o)
        return o

    def _place(self, o, loc, scale, rot):
        o.location = self.origin + Vector(loc)
        o.scale = scale
        if isinstance(rot, (tuple, list)):
            o.rotation_euler = [math.radians(a) for a in rot]
        else:
            o.rotation_mode = "QUATERNION"
            o.rotation_quaternion = rot
        bpy.context.view_layer.update()

    def sphere(self, seg, loc, scale, material, rot=(0, 0, 0), segs=32):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=segs * Q, ring_count=max(8, segs * Q // 2), radius=1)
        o = bpy.context.active_object
        self._place(o, loc, scale, rot)
        return self._fin(o, seg, material)

    def box(self, seg, loc, size, material, rot=(0, 0, 0), bevel=0.06, segs=3):
        bpy.ops.mesh.primitive_cube_add(size=1)
        o = bpy.context.active_object
        self._place(o, loc, size, rot)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        if bevel:
            m = o.modifiers.new("Bevel", "BEVEL")
            m.width = bevel
            m.segments = segs * Q
            m.limit_method = "NONE"
            m.harden_normals = False
        o = self._fin(o, seg, material)
        if bevel:
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.shade_auto_smooth(angle=math.radians(40)) if hasattr(bpy.ops.object, "shade_auto_smooth") else None
        return o

    def cone(self, seg, loc, r1, r2, depth, material, rot=(0, 0, 0), scale=(1, 1, 1), verts=24):
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth)
        o = bpy.context.active_object
        self._place(o, loc, scale, rot)
        return self._fin(o, seg, material, smooth=verts > 8)

    def cyl(self, seg, loc, r, depth, material, rot=(0, 0, 0), scale=(1, 1, 1), verts=32):
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts * Q, radius=r, depth=depth)
        o = bpy.context.active_object
        self._place(o, loc, scale, rot)
        o = self._fin(o, seg, material)
        bpy.context.view_layer.objects.active = o
        if hasattr(bpy.ops.object, "shade_auto_smooth"):
            bpy.ops.object.shade_auto_smooth(angle=math.radians(40))
        return o

    def torus(self, seg, loc, major, minor, material, rot=(0, 0, 0), scale=(1, 1, 1)):
        bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=40 * Q,
                                         minor_segments=12 * Q)
        o = bpy.context.active_object
        self._place(o, loc, scale, rot)
        return self._fin(o, seg, material)

    def line(self, seg, pts, width, material, res=3):
        cu = bpy.data.curves.new("line", "CURVE")
        cu.dimensions = "3D"
        cu.bevel_depth = width
        cu.bevel_resolution = res * Q
        cu.resolution_u = 12 * Q
        cu.use_fill_caps = True
        sp = cu.splines.new("BEZIER")
        sp.bezier_points.add(len(pts) - 1)
        for bp, p in zip(sp.bezier_points, pts):
            bp.co = self.origin + Vector(p)
            bp.handle_left_type = bp.handle_right_type = "AUTO"
        o = bpy.data.objects.new("line", cu)
        bpy.context.scene.collection.objects.link(o)
        for s in bpy.context.selected_objects:
            s.select_set(False)
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        bpy.ops.object.convert(target="MESH")
        o = bpy.context.active_object
        return self._fin(o, seg, material)

    def outline(self, thickness=0.022):
        """Inverted-hull ink outline on every mesh of the model."""
        for o in self.objs:
            if o.type != "MESH" or o.get("no_outline"):
                continue
            o.data.materials.append(ink())
            m = o.modifiers.new("Outline", "SOLIDIFY")
            m.thickness = thickness
            m.offset = 1.0
            m.use_flip_normals = True
            m.use_rim = False
            m.material_offset = len(o.data.materials) - 1
            m.use_even_offset = True


def on_sphere(c, r, az, el, out=0.0):
    """Point on a (possibly scaled) sphere's front (-Y) surface; az/el in degrees."""
    a, e = math.radians(az), math.radians(el)
    d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    rr = Vector(r) if isinstance(r, (tuple, list, Vector)) else Vector((r, r, r))
    p = Vector((d.x * rr.x, d.y * rr.y, d.z * rr.z))
    n = Vector((d.x / rr.x, d.y / rr.y, d.z / rr.z)).normalized()
    return Vector(c) + p + n * out, n


def facing(n):
    """Quaternion that points local -Y along normal n (decals flattened on Y)."""
    return Vector(n).to_track_quat("-Y", "Z")


# ---------------------------------------------------------------- palette
SKIN = "#F6F3EF"
HOODIE = "#EEECF4"
PANTS = "#2A2A36"
SHOE = "#1C1B22"
SOLE = "#F2F0F5"
HAIR = "#17151D"
RING = "#3A2E47"     # soft grey-purple ring around the wide eyes
MOUTH = "#8E2A44"    # berry grin, not blood red


# ---------------------------------------------------------------- 1 TOY
def build_toy(origin):
    m = Model("Toy", origin)
    S = mat("Toy skin", SKIN, rough=0.35, coat=0.3)
    H = mat("Toy hoodie", HOODIE, rough=0.55, coat=0.15)
    P = mat("Toy pants", PANTS, rough=0.55, coat=0.15)
    SH = mat("Toy shoe", SHOE, rough=0.4, coat=0.3)
    SO = mat("Toy sole", SOLE, rough=0.5)
    HR = mat("Toy hair", HAIR, rough=0.45, coat=0.1)
    W = mat("Toy eye white", "#FFFFFF", rough=0.15, coat=0.6)
    RG = mat("Toy eye ring", RING, rough=0.4)
    PU = mat("Toy pupil", "#0B0B10", rough=0.15)
    SHN = mat("Toy shine", "#FFFFFF", emit=2.0)
    MO = mat("Toy mouth", MOUTH, rough=0.35, coat=0.4)
    STR = mat("Toy string", "#C9C5D6", rough=0.6)

    for side, x in (("Left", 0.2), ("Right", -0.2)):
        m.sphere(f"{side}UpperLeg", (x, 0, 0.47), (0.17, 0.17, 0.3), P)
        m.sphere(f"{side}Foot", (x, -0.07, 0.11), (0.2, 0.29, 0.12), SH)
        m.sphere(f"{side}Foot_sole", (x, -0.07, 0.05), (0.205, 0.295, 0.06), SO)
    m.sphere("LowerTorso", (0, 0, 0.82), (0.36, 0.28, 0.2), P)
    m.sphere("UpperTorso", (0, 0, 1.12), (0.46, 0.36, 0.46), H)
    m.sphere("UpperTorso_hem", (0, 0, 0.8), (0.47, 0.37, 0.12), H)
    m.sphere("UpperTorso_pocket", (0, -0.28, 0.96), (0.26, 0.1, 0.13), H)
    m.torus("UpperTorso_hood", (0, 0.1, 1.52), 0.26, 0.11, H, rot=(-20, 0, 0), scale=(1.15, 1, 1))
    for x in (0.08, -0.08):
        m.line("UpperTorso_string", [(x, -0.3, 1.46), (x * 1.1, -0.36, 1.3), (x * 1.2, -0.36, 1.18)], 0.016, STR)
        m.sphere("UpperTorso_tip", (x * 1.2, -0.36, 1.16), (0.03, 0.03, 0.04), STR, segs=12)
    for side, sx in (("Left", 1), ("Right", -1)):
        m.sphere(f"{side}UpperArm", (sx * 0.54, 0, 1.17), (0.15, 0.15, 0.31), H, rot=(0, -sx * 30, 0))
        m.torus(f"{side}UpperArm_cuff", (sx * 0.67, 0, 0.95), 0.11, 0.05, H, rot=(0, -sx * 30, 0))
        m.sphere(f"{side}Hand", (sx * 0.72, 0, 0.85), (0.13, 0.12, 0.13), S)

    hc, hr = Vector((0, 0, 2.02)), 0.62
    m.sphere("Head", hc, (hr, hr * 0.96, hr * 0.98), S, segs=48)
    # hair: back/top cap + spiky clumps + bangs
    m.sphere("Head_hair", hc + Vector((0, 0.1, 0.1)), (hr * 1.06, hr * 0.98, hr * 0.98), HR, segs=48)
    import random
    rnd = random.Random(3)
    for i in range(14):
        az = -150 + i * (300 / 13)
        p, n = on_sphere(hc + Vector((0, 0.1, 0.1)), hr * 1.0, az + 180, 30 + rnd.uniform(-10, 25))
        q = n.to_track_quat("Z", "Y")
        o = m.cone("Head_spike", p, 0.16, 0.0, 0.42, HR, rot=q)
    for i, az in enumerate((-48, -30, -12, 8, 26, 44)):
        p, n = on_sphere(hc, hr * 1.01, az, 46 + (4 if i % 2 else 0))
        tip = p + Vector((math.sin(math.radians(az)) * 0.05, -0.12, -0.22 - (0.04 if i % 2 else 0)))
        m.line("Head_bang", [p + Vector((0, 0.03, 0.06)), (p + tip) / 2 + Vector((0, -0.04, 0)), tip], 0.07, HR)
    # side locks framing the face
    for sx in (1, -1):
        p, n = on_sphere(hc, hr * 1.0, sx * 70, 20)
        m.line("Head_lock", [p + Vector((0, 0.05, 0.15)), p + Vector((sx * 0.06, -0.05, -0.2)),
                             p + Vector((sx * 0.02, -0.12, -0.45))], 0.075, HR)
    # wide eyes
    for sx in (1, -1):
        p, n = on_sphere(hc, hr, sx * 23, 6, out=0.0)
        q = facing(n)
        m.sphere("Head_eyering", p, (0.175, 0.04, 0.19), RG, rot=q)
        p2, _ = on_sphere(hc, hr, sx * 23, 6, out=0.02)
        m.sphere("Head_eye", p2, (0.145, 0.04, 0.16), W, rot=q)
        p3, _ = on_sphere(hc, hr, sx * 21, 5, out=0.045)
        m.sphere("Head_pupil", p3, (0.045, 0.02, 0.05), PU, rot=q, segs=16)
        p4, _ = on_sphere(hc, hr, sx * 19 + 3, 9, out=0.06)
        m.sphere("Head_shine", p4, (0.018, 0.01, 0.018), SHN, rot=q, segs=12)
    # wide grin
    pts = [on_sphere(hc, hr, a, e, out=0.005)[0] for a, e in
           ((-50, -6), (-36, -18), (-18, -26), (0, -28), (18, -26), (36, -18), (50, -6))]
    m.line("Head_grin", pts, 0.028, MO)
    for sx in (1, -1):
        a = on_sphere(hc, hr, sx * 50, -6, out=0.005)[0]
        b = on_sphere(hc, hr, sx * 53, 1, out=0.005)[0]
        m.line("Head_grin_curl", [a, b], 0.024, MO)
    return m


# ---------------------------------------------------------------- 2 BLOCKY
def build_blocky(origin):
    m = Model("Blocky", origin)
    S = mat("Blocky skin", SKIN, rough=0.5)
    H = mat("Blocky hoodie", HOODIE, rough=0.7)
    HD = mat("Blocky hoodie dark", "#D9D6E2", rough=0.7)
    P = mat("Blocky pants", PANTS, rough=0.7)
    SH = mat("Blocky shoe", SHOE, rough=0.6)
    HR = mat("Blocky hair", HAIR, rough=0.55)
    W = mat("Blocky eye white", "#FFFFFF", rough=0.3)
    RG = mat("Blocky eye ring", RING, rough=0.6)
    PU = mat("Blocky pupil", "#0B0B10", rough=0.3)
    MO = mat("Blocky mouth", MOUTH, rough=0.5)
    STR = mat("Blocky string", "#A9A5B6", rough=0.7)

    for side, x in (("Left", 0.25), ("Right", -0.25)):
        m.box(f"{side}UpperLeg", (x, 0, 0.62), (0.46, 0.48, 0.8), P, bevel=0.04)
        m.box(f"{side}Foot", (x, -0.03, 0.12), (0.48, 0.56, 0.24), SH, bevel=0.05)
    m.box("LowerTorso", (0, 0, 1.12), (0.98, 0.48, 0.26), H, bevel=0.04)
    m.box("UpperTorso", (0, 0, 1.6), (1.0, 0.5, 0.78), H, bevel=0.05)
    m.box("UpperTorso_pocket", (0, -0.26, 1.33), (0.56, 0.04, 0.26), HD, bevel=0.015)
    m.box("UpperTorso_hood", (0, 0.2, 2.0), (0.86, 0.3, 0.2), HD, bevel=0.06)
    for x in (0.12, -0.12):
        m.box("UpperTorso_string", (x, -0.27, 1.8), (0.04, 0.03, 0.3), STR, bevel=0.01)
    for side, sx in (("Left", 1), ("Right", -1)):
        m.box(f"{side}UpperArm", (sx * 0.74, 0, 1.6), (0.46, 0.48, 0.78), H, bevel=0.05)
        m.box(f"{side}Hand", (sx * 0.74, 0, 1.08), (0.4, 0.42, 0.26), S, bevel=0.05)

    hz = 2.48
    m.box("Head", (0, 0, hz), (0.78, 0.78, 0.78), S, bevel=0.16, segs=5)
    # chunky blocky hair
    m.box("Head_hair", (0, 0.06, hz + 0.33), (0.86, 0.78, 0.22), HR, bevel=0.04)
    m.box("Head_hair_back", (0, 0.36, hz + 0.02), (0.86, 0.14, 0.78), HR, bevel=0.04)
    for sx in (1, -1):
        m.box("Head_hair_side", (sx * 0.42, 0.12, hz + 0.08), (0.1, 0.56, 0.66), HR, bevel=0.03)
        m.box("Head_hair_lock", (sx * 0.42, -0.24, hz - 0.12), (0.1, 0.14, 0.42), HR, bevel=0.03)
    for i, x in enumerate((-0.3, -0.1, 0.1, 0.3)):
        m.box("Head_bang", (x, -0.37, hz + 0.24 - (0.05 if i % 2 else 0)), (0.2, 0.1, 0.18 + (0.06 if i % 2 else 0)),
              HR, rot=(0, 15 * (1 if i % 2 else -1), 0), bevel=0.02)
    import random
    rnd = random.Random(7)
    for i in range(7):
        x = -0.32 + i * 0.107
        m.box("Head_spike", (x, rnd.uniform(-0.15, 0.3), hz + 0.48), (0.2, 0.22, 0.2), HR,
              rot=(rnd.uniform(-25, 25), rnd.uniform(-25, 25), rnd.uniform(0, 45)), bevel=0.02)
    # flat face decals on the front face (y = -0.39)
    fy = -0.392
    for sx in (1, -1):
        m.cyl("Head_eyering", (sx * 0.17, fy, hz + 0.05), 0.13, 0.012, RG, rot=(90, 0, 0), scale=(1, 1.1, 1))
        m.cyl("Head_eye", (sx * 0.17, fy - 0.008, hz + 0.05), 0.105, 0.012, W, rot=(90, 0, 0), scale=(1, 1.1, 1))
        m.cyl("Head_pupil", (sx * 0.155, fy - 0.016, hz + 0.04), 0.035, 0.012, PU, rot=(90, 0, 0))
    pts = [(-0.3, fy, hz - 0.1), (-0.22, fy, hz - 0.2), (-0.1, fy, hz - 0.255), (0, fy, hz - 0.265),
           (0.1, fy, hz - 0.255), (0.22, fy, hz - 0.2), (0.3, fy, hz - 0.1)]
    m.line("Head_grin", [(x, y - 0.012, z) for x, y, z in pts], 0.026, MO)
    return m


# ---------------------------------------------------------------- 3 CARTOON (toon + ink)
def build_cartoon(origin):
    m = Model("Cartoon", origin)
    S = toon("Toon skin", "#FBF8F3", "#B9B0C9")
    H = toon("Toon hoodie", "#F1EEF7", "#ABA2C2")
    P = toon("Toon pants", "#2E2C3C", "#1A1826")
    SH = toon("Toon shoe", "#22202B", "#121018")
    SO = toon("Toon sole", "#E9E6F0", "#A39DB5")
    HR = toon("Toon hair", "#1C1824", "#0E0B13")
    W = toon("Toon eye white", "#FFFFFF", "#DAD6E6")
    PU = toon("Toon pupil", "#0B0B10", "#0B0B10")
    MO = toon("Toon mouth", "#4A1830", "#2E0E1E")
    TE = toon("Toon teeth", "#FFFDF6", "#D9D2C6")
    STR = toon("Toon string", "#C9C3DA", "#8E87A4")

    # long skinny legs, big sneakers
    for side, x in (("Left", 0.16), ("Right", -0.16)):
        m.cone(f"{side}UpperLeg", (x, 0, 0.58), 0.1, 0.13, 0.86, P)
        m.sphere(f"{side}Foot", (x, -0.1, 0.12), (0.17, 0.3, 0.13), SH)
        m.sphere(f"{side}Foot_sole", (x, -0.1, 0.05), (0.175, 0.305, 0.05), SO)
    # baggy hoodie: wider at the hem
    m.cone("UpperTorso", (0, 0, 1.38), 0.42, 0.3, 0.8, H, scale=(1, 0.72, 1))
    m.sphere("UpperTorso_shoulders", (0, 0, 1.74), (0.37, 0.25, 0.14), H)
    m.torus("LowerTorso_hem", (0, 0, 0.99), 0.39, 0.06, H, scale=(1, 0.74, 1))
    m.sphere("UpperTorso_pocket", (0, -0.27, 1.17), (0.24, 0.05, 0.11), H)
    m.torus("UpperTorso_hood", (0, 0.06, 1.84), 0.22, 0.09, H, rot=(-25, 0, 0), scale=(1.1, 1, 1))
    for x in (0.07, -0.07):
        o = m.line("UpperTorso_string", [(x, -0.24, 1.8), (x * 1.3, -0.3, 1.6), (x * 1.5, -0.31, 1.48)], 0.013, STR)
        o["no_outline"] = True
    # floppy long sleeves, hands poking out
    for side, sx in (("Left", 1), ("Right", -1)):
        m.cone(f"{side}UpperArm", (sx * 0.45, 0, 1.38), 0.08, 0.13, 0.78, H, rot=(0, -sx * 14, 0))
        m.sphere(f"{side}Hand", (sx * 0.56, -0.02, 0.92), (0.1, 0.09, 0.12), S)
        for f in (-1, 0, 1):
            m.sphere(f"{side}Hand_finger", (sx * 0.56 + f * 0.04, -0.03, 0.8), (0.028, 0.028, 0.06), S, segs=12)

    # tall egg head
    hc, hr = Vector((0, 0, 2.38)), (0.5, 0.46, 0.58)
    m.sphere("Head", hc, hr, S, segs=48)
    # wild spiky hair: big shell + long sharp spikes fanning out
    m.sphere("Head_hair", hc + Vector((0, 0.08, 0.12)), (0.53, 0.48, 0.56), HR, segs=48)
    import random
    rnd = random.Random(11)
    for i in range(16):
        az = 180 - 150 + i * (300 / 15)
        el = 25 + rnd.uniform(-5, 40)
        p, n = on_sphere(hc + Vector((0, 0.08, 0.12)), (0.5, 0.45, 0.53), az, el)
        q = (n + Vector((0, 0.3, 0.2))).normalized().to_track_quat("Z", "Y")
        m.cone("Head_spike", p, 0.12, 0.0, 0.5 + rnd.uniform(0, 0.25), HR, rot=q, verts=12)
    for i, az in enumerate((-36, -16, 6, 26)):
        p, n = on_sphere(hc, hr, az, 50)
        tip = p + Vector((math.sin(math.radians(az)) * 0.12, -0.14, -0.32))
        m.cone("Head_bang", (p + tip) / 2, 0.09, 0.0, (tip - p).length + 0.05, HR,
               rot=(tip - p).normalized().to_track_quat("Z", "Y"), verts=12)
    for sx in (1, -1):
        p, n = on_sphere(hc, hr, sx * 72, 15)
        tip = p + Vector((sx * 0.06, -0.08, -0.55))
        m.cone("Head_lock", (p + tip) / 2, 0.1, 0.0, (tip - p).length, HR,
               rot=(tip - p).normalized().to_track_quat("Z", "Y"), verts=12)
    # huge round eyes with tiny pupils
    for sx in (1, -1):
        p, n = on_sphere(hc, hr, sx * 24, 6, out=0.0)
        m.sphere("Head_eye", p, (0.15, 0.05, 0.175), W, rot=facing(n))
        p3, n3 = on_sphere(hc, hr, sx * 21, 3, out=0.06)
        m.sphere("Head_pupil", p3, (0.035, 0.015, 0.035), PU, rot=facing(n3), segs=16)["no_outline"] = True
    # big toothy grin: dark mouth with a row of teeth
    mouth_pts = [(a, e) for a, e in ((-44, -16), (-30, -26), (-14, -31), (0, -32), (14, -31), (30, -26), (44, -16))]
    for i, (a, e) in enumerate(mouth_pts):
        p, n = on_sphere(hc, hr, a, e, out=0.0)
        m.sphere("Head_mouth", p, (0.075, 0.03, 0.06 if 0 < i < 6 else 0.04), MO, rot=facing(n))["no_outline"] = True
    for a in (-30, -15, 0, 15, 30):
        p, n = on_sphere(hc, hr, a, -24, out=0.02)
        m.box("Head_tooth", p, (0.05, 0.02, 0.045), TE, rot=facing(n), bevel=0.008)["no_outline"] = True
    line = [on_sphere(hc, hr, a, e + 4, out=0.012)[0] for a, e in mouth_pts]
    m.line("Head_mouthline", [on_sphere(hc, hr, -50, -8, out=0.012)[0]] + line + [on_sphere(hc, hr, 50, -8, out=0.012)[0]],
           0.012, ink())["no_outline"] = True
    m.outline(0.026)
    return m


# ---------------------------------------------------------------- 4 PLUSH
def build_plush(origin):
    m = Model("Plush", origin)
    S = mat("Plush felt skin", "#F7F1E8", rough=1.0, sheen=1.0, bump=0.35)
    H = mat("Plush fleece hoodie", "#EAE6F2", rough=1.0, sheen=1.0, bump=0.5)
    P = mat("Plush corduroy pants", "#33323F", rough=1.0, sheen=0.15, bump=0.5)
    HR = mat("Plush yarn hair", "#1D1A24", rough=0.9, sheen=0.0, bump=0.6)
    W = mat("Plush felt eye", "#FFFFFF", rough=1.0, sheen=0.6, bump=0.3)
    RG = mat("Plush thread ring", RING, rough=1.0, sheen=0.4, bump=0.8)
    BT = mat("Plush button", "#101014", rough=0.25, coat=0.8)
    TH = mat("Plush red thread", "#A3304F", rough=0.9, sheen=0.4)
    SEAM = mat("Plush seam", "#CFC9D9", rough=1.0)
    TAG = mat("Plush tag", "#E46F88", rough=0.8, sheen=0.5)

    for side, x in (("Left", 0.22), ("Right", -0.22)):
        m.sphere(f"{side}UpperLeg", (x, 0, 0.3), (0.2, 0.2, 0.3), P)
        m.sphere(f"{side}Foot", (x, -0.08, 0.1), (0.21, 0.25, 0.12), P)
    m.sphere("UpperTorso", (0, 0, 0.88), (0.5, 0.42, 0.48), H)
    m.torus("UpperTorso_seam", (0, 0, 0.88), 0.49, 0.012, SEAM, rot=(90, 0, 0), scale=(1.02, 1, 0.98))
    m.sphere("UpperTorso_pocket", (0, -0.36, 0.72), (0.24, 0.08, 0.13), H)
    m.torus("UpperTorso_hood", (0, 0.12, 1.28), 0.27, 0.11, H, rot=(-20, 0, 0), scale=(1.15, 1, 1))
    m.box("UpperTorso_tag", (0.5, 0.0, 0.75), (0.02, 0.12, 0.08), TAG, rot=(0, 0, 0), bevel=0.01)
    for side, sx in (("Left", 1), ("Right", -1)):
        m.sphere(f"{side}UpperArm", (sx * 0.55, 0, 0.88), (0.17, 0.17, 0.3), H, rot=(0, -sx * 40, 0))
        m.sphere(f"{side}Hand", (sx * 0.71, 0, 0.66), (0.14, 0.14, 0.13), S)

    hc, hr = Vector((0, 0, 1.78)), (0.7, 0.6, 0.6)
    m.sphere("Head", hc, hr, S, segs=48)
    m.torus("Head_seam", hc, 0.6, 0.012, SEAM, rot=(90, 0, 0), scale=(1.17, 1.0, 1.0))
    # yarn hair: soft fat tufts
    m.sphere("Head_hair", hc + Vector((0, 0.1, 0.12)), (0.72, 0.6, 0.55), HR, segs=48)
    import random
    rnd = random.Random(5)
    for i in range(12):
        az = 180 - 160 + i * (320 / 11)
        p, n = on_sphere(hc + Vector((0, 0.1, 0.12)), (0.7, 0.58, 0.53), az, 35 + rnd.uniform(-10, 25))
        q = n.to_track_quat("Z", "Y")
        m.cone("Head_tuft", p, 0.15, 0.04, 0.32, HR, rot=q)
    for i, az in enumerate((-40, -20, 0, 20, 40)):
        p, n = on_sphere(hc, hr, az, 40)
        m.sphere("Head_bang", p + Vector((0, -0.03, -0.04)), (0.13, 0.09, 0.15), HR,
                 rot=(15, 0, -az * 0.6))
    # embroidered eyes with button pupils
    for sx in (1, -1):
        p, n = on_sphere(hc, hr, sx * 22, 6)
        m.sphere("Head_eyering", p, (0.19, 0.03, 0.19), RG, rot=facing(n))
        p2, _ = on_sphere(hc, hr, sx * 22, 6, out=0.015)
        m.sphere("Head_eye", p2, (0.155, 0.03, 0.155), W, rot=facing(n))
        p3, n3 = on_sphere(hc, hr, sx * 21, 5, out=0.04)
        m.cyl("Head_button", p3, 0.055, 0.025, BT, rot=n3.to_track_quat("Z", "Y"))
    # running-stitch grin (dashes, no cross stitches)
    arc = [(a, -24 - 10 * math.cos(math.radians(a * 2))) for a in range(-48, 49, 12)]
    for a, e in arc:
        p0, _ = on_sphere(hc, hr, a - 4, e + (2 if abs(a) > 30 else 0), out=0.004)
        p1, _ = on_sphere(hc, hr, a + 4, e + (2 if abs(a) > 30 else 0), out=0.004)
        m.line("Head_stitch", [p0, p1], 0.018, TH)
    return m


# ---------------------------------------------------------------- scene
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)
for c in list(bpy.data.collections):
    if c.name.startswith("Jeff_"):
        bpy.data.collections.remove(c)
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
sc.view_settings.view_transform = "Standard"
sc.view_settings.look = "None"
try:
    sc.eevee.taa_render_samples = 256 if HQ else 48
    if HQ:
        sc.eevee.use_raytracing = True
        sc.eevee.use_fast_gi = True
        sc.eevee.shadow_ray_count = 2
        sc.eevee.shadow_step_count = 12
    sc.eevee.use_shadows = True
except Exception:
    pass
sc.world = sc.world or bpy.data.worlds.new("World")
sc.world.use_nodes = True
bg = sc.world.node_tree.nodes["Background"]
bg.inputs[0].default_value = lin("#3A2F5C")
bg.inputs[1].default_value = 0.9

SPACING = 3.2
builders = [("Toy", build_toy), ("Blocky", build_blocky), ("Cartoon", build_cartoon), ("Plush", build_plush)]
models = []
for i, (name, fn) in enumerate(builders):
    models.append(fn(((i - 1.5) * SPACING, 0, 0)))

# ground disc under each
GROUND = mat("Pedestal", "#5B4A8A", rough=0.8)
for mo in models:
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=0.95, depth=0.12, location=mo.origin + Vector((0, 0, -0.06)))
    g = bpy.context.active_object
    g.name = f"Pedestal_{mo.name}"
    g.data.materials.append(GROUND)


def light(name, kind, loc, energy, rot, size=3, color=(1, 1, 1)):
    ld = bpy.data.lights.new(name, kind)
    ld.energy = energy
    ld.color = color
    if kind == "AREA":
        ld.size = size
    lo = bpy.data.objects.new(name, ld)
    sc.collection.objects.link(lo)
    lo.location = loc
    lo.rotation_euler = [math.radians(a) for a in rot]
    return lo


light("Key", "AREA", (5, -8, 8), 3200, (48, 0, 30), 10, (1.0, 0.97, 0.92))
light("Fill", "AREA", (-7, -7, 4), 1100, (65, 0, -45), 10, (0.85, 0.85, 1.0))
light("Rim", "AREA", (0, 10, 6), 2200, (-55, 0, 0), 14, (0.8, 0.7, 1.0))
sun = light("Sun", "SUN", (0, 0, 10), 1.6, (40, 0, 25))

cd = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cd)
sc.collection.objects.link(cam)
sc.camera = cam

ONLY = "skip" if globals().get("SKIP_RENDER") else os.environ.get("ONLY")
# lineup: 3/4-ish front view of all four
cd.lens = 50
sc.render.resolution_x, sc.render.resolution_y = 2000 * Q, 900 * Q
cam.location = (1.2, -15.5, 3.2)
tgt = Vector((0, 0, 1.25))
cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
if ONLY in (None, "lineup"):
    sc.render.filepath = os.path.join(OUT, "lineup_raw.png")
    bpy.ops.render.render(write_still=True)

# per-style portraits (3/4 view) and a back-3/4 view
cd.lens = 70
sc.render.resolution_x, sc.render.resolution_y = 800 * Q, 1000 * Q
for mo in models:
    if ONLY and mo.name != ONLY:
        continue
    for other in models:
        hide = other is not mo
        for o in [other.root] + other.objs:
            o.hide_render = hide
        bpy.data.objects[f"Pedestal_{other.name}"].hide_render = hide
    for tag, off in (("front", Vector((2.8, -7.6, 2.2))), ("back", Vector((-4.6, 6.6, 2.6)))):
        cam.location = mo.origin + off
        t = mo.origin + Vector((0, 0, 1.3))
        cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(OUT, f"jeff_{mo.name.lower()}_{tag}.png")
        bpy.ops.render.render(write_still=True)
for other in models:
    for o in [other.root] + other.objs:
        o.hide_render = False

if not ONLY:
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "jeff_styles.blend"))
print("DONE")
result = {"out": OUT, "files": sorted(os.listdir(OUT))}

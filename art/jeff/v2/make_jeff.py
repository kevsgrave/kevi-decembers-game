"""Builds a Roblox-style Jeff (classic blocky avatar look, all-ages: no knife, no blood),
rigs it with a 15-part R15 armature, renders previews and exports an FBX.

Run: blender -b --python make_jeff.py -- <out_dir>
Or from Blender's Python: exec(open(path).read(), {"OUT_DIR": <dir>, "HQ": True})
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


# ---------------------------------------------------------------- Roblox-style Jeff
# Units are Roblox studs (1 Blender unit = 1 stud), feet at z = 0, facing -Y.
import random
import bmesh
from mathutils import Matrix

HEAD_C = Vector((0, 0, 4.66))
HEAD_R = 0.64
HEAD_H = 1.22


def on_head(az, z, out=0.0):
    """Point and outward normal on the cylindrical head's front at azimuth az (deg), height z."""
    a = math.radians(az)
    n = Vector((math.sin(a), -math.cos(a), 0))
    return Vector((0, 0, z)) + n * (HEAD_R + out), n


def strand(m, seg, pts, r0, r1, material):
    """Tapered round hair strand along a bezier path (radius r0 at the root, r1 at the tip)."""
    cu = bpy.data.curves.new("strand", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 1.0
    cu.bevel_resolution = 4 * Q
    cu.resolution_u = 10 * Q
    cu.use_fill_caps = True
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(len(pts) - 1)
    for i, (bp, p) in enumerate(zip(sp.bezier_points, pts)):
        t = i / (len(pts) - 1)
        bp.co = m.origin + Vector(p)
        bp.handle_left_type = bp.handle_right_type = "AUTO"
        bp.radius = r0 + (r1 - r0) * (t ** 1.3)
    o = bpy.data.objects.new("strand", cu)
    bpy.context.scene.collection.objects.link(o)
    for s in bpy.context.selected_objects:
        s.select_set(False)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    return m._fin(bpy.context.active_object, seg, material)


def head_patch(m, seg, top, bottom, az0, az1, out, thick, material, cols=48):
    """Flat decal mesh wrapped on the head between two curves; top/bottom map t in [0,1] -> z."""
    me = bpy.data.meshes.new(seg)
    bm = bmesh.new()
    rows = []
    for i in range(cols + 1):
        t = i / cols
        az = az0 + (az1 - az0) * t
        zt, zb = top(t), bottom(t)
        rows.append([bm.verts.new(on_head(az, z, out)[0]) for z in (zt, zb)])
    for i in range(cols):
        a, b = rows[i], rows[i + 1]
        bm.faces.new((a[0], b[0], b[1], a[1]))
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(seg, me)
    o.location = m.origin
    bpy.context.scene.collection.objects.link(o)
    sol = o.modifiers.new("Thick", "SOLIDIFY")
    sol.thickness = thick
    sol.offset = -1
    o = m._fin(o, seg, material)
    for s in bpy.context.selected_objects:
        s.select_set(False)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.modifier_apply(modifier="Thick")
    return o


def rib_mat(key, color):
    """Knit-rib fabric: vertical ridges from a sine of (x + y), so they wrap all four sides."""
    if key in _mats:
        return _mats[key]
    m = mat(key, color, rough=0.9, sheen=0.3)
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = "ADD"
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = 2 * math.pi / 0.09
    sin = nt.nodes.new("ShaderNodeMath")
    sin.operation = "SINE"
    bp = nt.nodes.new("ShaderNodeBump")
    bp.inputs["Strength"].default_value = 0.6
    bp.inputs["Distance"].default_value = 0.02
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    nt.links.new(sep.outputs[0], add.inputs[0])
    nt.links.new(sep.outputs[1], add.inputs[1])
    nt.links.new(add.outputs[0], mul.inputs[0])
    nt.links.new(mul.outputs[0], sin.inputs[0])
    nt.links.new(sin.outputs[0], bp.inputs["Height"])
    nt.links.new(bp.outputs["Normal"], b.inputs["Normal"])
    return m


def ribs(m, seg, center, size, material):
    """Ribbed knit band (ridges come from the rib material)."""
    m.box(seg, center, size, material, bevel=0.06)


def _unused_ribs(m, seg, center, size, material, pitch=0.085, depth=0.022):
    cx, cy, cz = center
    sx, sy, sz = size
    for face in ("front", "back", "left", "right"):
        if face in ("front", "back"):
            n = int(sx / pitch)
            y = cy + (-1 if face == "front" else 1) * (sy / 2)
            for i in range(n):
                x = cx - sx / 2 + pitch * (i + 0.5)
                m.cyl(seg + "_rib", (x, y, cz), depth, sz * 0.96, material, verts=8)
        else:
            n = int(sy / pitch)
            x = cx + (1 if face == "right" else -1) * (sx / 2)
            for i in range(n):
                y = cy - sy / 2 + pitch * (i + 0.5)
                m.cyl(seg + "_rib", (x, y, cz), depth, sz * 0.96, material, verts=8)


def build_jeff(origin=(0, 0, 0)):
    m = Model("Jeff", origin)
    SKIN = mat("Jeff skin", "#F3F0EC", rough=0.38, coat=0.15)
    HOOD = mat("Jeff hoodie", "#E7E5EC", rough=0.85, sheen=0.4, bump=0.25)
    HOOD2 = mat("Jeff hoodie shade", "#D3D0DA", rough=0.85, sheen=0.4, bump=0.25)
    RIB = rib_mat("Jeff rib knit", "#77737F")
    ZIP = mat("Jeff zipper", "#4A4752", rough=0.35, coat=0.3)
    METAL = mat("Jeff zip pull", "#B9B6C2", rough=0.25, coat=0.6)
    STRING = mat("Jeff drawstring", "#3E3B46", rough=0.7)
    TIP = mat("Jeff aglet", "#C9C6D1", rough=0.3, coat=0.5)
    PANTS = mat("Jeff pants", "#24232B", rough=0.8, sheen=0.25, bump=0.3)
    SHOE = mat("Jeff shoe", "#2B2A33", rough=0.45, coat=0.3)
    SOLE = mat("Jeff sole", "#DCDAE2", rough=0.6)
    LACE = mat("Jeff laces", "#E9E7EE", rough=0.6)
    HAIR = mat("Jeff hair", "#141219", rough=0.38, coat=0.25)
    HAIR2 = mat("Jeff hair light", "#24212D", rough=0.4, coat=0.25)
    RING = mat("Jeff eye ring", "#3B3045", rough=0.55)
    WHITE = mat("Jeff eye white", "#FFFFFF", rough=0.15, coat=0.6)
    PUPIL = mat("Jeff pupil", "#0C0B10", rough=0.7)
    SHINE = mat("Jeff shine", "#FFFFFF", emit=2.5)
    MOUTH = mat("Jeff mouth", "#3A1828", rough=0.5)
    TEETH = mat("Jeff teeth", "#FFFDF7", rough=0.3, coat=0.4)
    LIP = mat("Jeff grin line", "#5A2A3E", rough=0.5)
    TONGUE = mat("Jeff tongue", "#D7708C", rough=0.45)

    # ---- legs and sneakers
    for side, sx in (("Left", 1), ("Right", -1)):
        x = sx * 0.5
        m.box(f"{side}UpperLeg", (x, 0, 1.6), (0.98, 0.98, 0.84), PANTS, bevel=0.07)
        m.box(f"{side}LowerLeg", (x, 0, 0.84), (0.97, 0.97, 0.7), PANTS, bevel=0.07)
        m.box(f"{side}LowerLeg_hem", (x, 0, 0.53), (1.0, 1.0, 0.1), PANTS, bevel=0.05)
        m.box(f"{side}Foot", (x, -0.08, 0.27), (0.96, 1.16, 0.4), SHOE, bevel=0.17, segs=4)
        m.box(f"{side}Foot_toe", (x, -0.5, 0.2), (0.9, 0.36, 0.26), SHOE, bevel=0.12, segs=4)
        m.box(f"{side}Foot_sole", (x, -0.1, 0.06), (1.02, 1.26, 0.12), SOLE, bevel=0.05)
        m.box(f"{side}Foot_tongue", (x, -0.18, 0.47), (0.42, 0.42, 0.06), SHOE, rot=(-12, 0, 0), bevel=0.03)
        for j in range(3):
            m.box(f"{side}Foot_lace", (x, -0.4 + j * 0.12, 0.43 + j * 0.025), (0.46, 0.05, 0.035), LACE, bevel=0.015)

    # ---- hoodie body
    m.box("LowerTorso", (0, 0, 2.3), (1.98, 0.98, 0.4), PANTS, bevel=0.1)
    m.box("UpperTorso", (0, 0, 3.22), (2.0, 1.0, 1.56), HOOD, bevel=0.16, segs=4)
    ribs(m, "LowerTorso_band", (0, 0, 2.38), (2.04, 1.04, 0.26), RIB)
    # zipper down the middle with a pull tab
    m.box("UpperTorso_zip", (0, -0.505, 3.15), (0.07, 0.03, 1.5), ZIP, bevel=0.012)
    for i in range(26):
        m.box("UpperTorso_zipteeth", (0, -0.52, 2.5 + i * 0.056), (0.11, 0.02, 0.024), ZIP, bevel=0.006)
    m.box("UpperTorso_zippull", (0.045, -0.54, 3.72), (0.07, 0.025, 0.16), METAL, bevel=0.015)
    # kangaroo pocket split by the zip, with slanted openings
    for sx in (1, -1):
        m.box("UpperTorso_pocket", (sx * 0.4, -0.515, 2.78), (0.66, 0.04, 0.5), HOOD2, bevel=0.03)
        m.box("UpperTorso_pocketlip", (sx * 0.7, -0.54, 2.82), (0.05, 0.03, 0.48), HOOD, rot=(0, -sx * 18, 0), bevel=0.012)
        m.box("UpperTorso_pockettop", (sx * 0.4, -0.54, 3.03), (0.56, 0.03, 0.04), HOOD, bevel=0.012)
    # raglan seams from collar to underarm
    for sx in (1, -1):
        for y in (-0.505, 0.505):
            m.line("UpperTorso_seam", [(sx * 0.35, y, 3.98), (sx * 0.65, y, 3.75), (sx * 0.98, y, 3.5)], 0.012, HOOD2)
    # hood: bunched collar around the neck plus the hood lying on the back
    m.torus("UpperTorso_collar", (0, 0.04, 4.03), 0.5, 0.16, HOOD, scale=(1.18, 0.95, 0.7))
    m.box("UpperTorso_hood", (0, 0.42, 3.82), (1.25, 0.28, 0.62), HOOD2, rot=(8, 0, 0), bevel=0.13, segs=4)
    m.torus("UpperTorso_hoodrim", (0, 0.5, 3.9), 0.5, 0.06, HOOD, rot=(80, 0, 0), scale=(1.15, 1, 0.9))
    for sx in (1, -1):
        m.line("UpperTorso_drawstring", [(sx * 0.22, -0.56, 4.0), (sx * 0.25, -0.6, 3.75), (sx * 0.27, -0.6, 3.5)], 0.022, STRING)
        m.cyl("UpperTorso_aglet", (sx * 0.27, -0.6, 3.44), 0.03, 0.1, TIP)

    # ---- arms: sleeves, ribbed cuffs, hands
    for side, sx in (("Left", 1), ("Right", -1)):
        x = sx * 1.5
        m.box(f"{side}UpperArm", (x, 0, 3.58), (1.0, 1.0, 0.86), HOOD, bevel=0.1, segs=4)
        m.box(f"{side}UpperArm_shoulder", (x, 0, 3.88), (1.0, 1.0, 0.24), HOOD, bevel=0.2, segs=5)
        m.box(f"{side}LowerArm", (x, 0, 2.93), (0.99, 0.99, 0.5), HOOD, bevel=0.06)
        ribs(m, f"{side}LowerArm_cuff", (x, 0, 2.57), (0.94, 0.94, 0.24), RIB)
        m.box(f"{side}Hand", (x, 0, 2.17), (0.8, 0.8, 0.56), SKIN, bevel=0.16, segs=4)
        m.box(f"{side}Hand_thumb", (x - sx * 0.05, -0.38, 2.28), (0.22, 0.2, 0.3), SKIN, bevel=0.09, segs=4)

    # ---- head: classic rounded cylinder
    m.cyl("Head_neck", (0, 0, 4.1), 0.3, 0.3, SKIN)
    hd = m.cyl("Head", HEAD_C, HEAD_R, HEAD_H, SKIN, verts=64)
    bv = hd.modifiers.new("Round", "BEVEL")
    bv.width = 0.24
    bv.segments = 8 * Q
    bv.limit_method = "ANGLE"
    zc = HEAD_C.z

    # eyes: soft dark ring, big white, small pupil, highlights
    for sx in (1, -1):
        az = sx * 21
        p, n = on_head(az, zc + 0.1, 0.004)
        q = n.to_track_quat("Z", "Y")
        m.cyl("Head_eyering", p, 0.175, 0.01, RING, rot=q, scale=(1, 1.08, 1))
        p, _ = on_head(az, zc + 0.1, 0.014)
        m.cyl("Head_eye", p, 0.135, 0.01, WHITE, rot=q, scale=(1, 1.08, 1))
        p, _ = on_head(az - sx * 2.5, zc + 0.08, 0.026)
        m.cyl("Head_pupil", p, 0.042, 0.01, PUPIL, rot=q)
        p, _ = on_head(az - sx * 4 + 3, zc + 0.13, 0.034)
        m.cyl("Head_shine", p, 0.016, 0.006, SHINE, rot=q, verts=16)

    # big wide grin: dark mouth, a row of teeth along the top, little tongue, smile corners
    U = 52.0
    corner = zc - 0.2
    top = lambda t: corner - 0.07 * (1 - (2 * t - 1) ** 2)
    bot = lambda t: corner - 0.30 * (1 - (2 * t - 1) ** 2) ** 0.85
    head_patch(m, "Head_mouth", top, bot, -U, U, 0.004, 0.006, MOUTH)
    tooth_bot = lambda t: top(t) - 0.085 * (1 - (2 * t - 1) ** 2) ** 0.5
    head_patch(m, "Head_teeth", top, tooth_bot, -U * 0.92, U * 0.92, 0.008, 0.006, TEETH)
    for i in range(1, 12):
        t = i / 12
        az = -U * 0.92 + 2 * U * 0.92 * t
        p, n = on_head(az, (top(0.04 + 0.92 * t) + tooth_bot(0.04 + 0.92 * t)) / 2, 0.012)
        m.box("Head_toothgap", p, (0.012, 0.006, 0.09 * (1 - (2 * t - 1) ** 2) ** 0.5 + 0.01), MOUTH,
              rot=n.to_track_quat("-Y", "Z"), bevel=0)
    tongue_top = lambda t: bot(0.3 + 0.4 * t) + 0.1 * (1 - (2 * t - 1) ** 2)
    tongue_bot = lambda t: bot(0.3 + 0.4 * t) + 0.012
    rim = [on_head(-U + 2 * U * t, top(t) + 0.004, 0.01)[0] for t in (0, 0.15, 0.32, 0.5, 0.68, 0.85, 1)]
    m.line("Head_grinline", rim, 0.014, LIP)
    for sx in (1, -1):
        a, _ = on_head(sx * U, corner, 0.01)
        b, _ = on_head(sx * (U + 5), corner + 0.07, 0.01)
        c, _ = on_head(sx * (U + 4), corner + 0.12, 0.01)
        m.line("Head_dimple", [a, b, c], 0.012, LIP)

    # ---- hair: smooth crown plus long tapered strands, side-swept bangs
    crown_c = Vector((0, 0.06, zc + 0.36))
    m.sphere("Head_hair", crown_c, (0.74, 0.74, 0.52), HAIR, segs=48)
    m.box("Head_hairback", (0, 0.36, zc - 0.05), (1.32, 0.36, 1.1), HAIR, bevel=0.16, segs=4)
    rnd = random.Random(21)

    def scalp(az, el):
        a, e = math.radians(az), math.radians(el)
        return crown_c + Vector((0.72 * math.sin(a) * math.cos(e), -0.72 * math.cos(a) * math.cos(e), 0.5 * math.sin(e)))

    # back and sides: fall straight to the neck with a slight outward flick
    for i in range(30):
        az = 62 + i * (236 / 29) + rnd.uniform(-3, 3)
        el = rnd.uniform(20, 55)
        r = scalp(az, el)
        a = math.radians(az)
        out = Vector((math.sin(a), -math.cos(a), 0))
        length = rnd.uniform(0.95, 1.25)
        p1 = r + out * 0.12 + Vector((0, 0, -0.15))
        p2 = r + out * 0.2 + Vector((0, 0, -length * 0.6))
        p3 = r + out * 0.28 + Vector((0, 0, -length))
        strand(m, "Head_strand", [r, p1, p2, p3], rnd.uniform(0.13, 0.17), 0.02, HAIR if i % 4 else HAIR2)
    # bangs: swept across the forehead toward his left (+X), stopping above the eyes
    for i in range(11):
        az = -58 + i * 9.5 + rnd.uniform(-2, 2)
        r = scalp(az, rnd.uniform(48, 62))
        sweep = 0.22 + 0.04 * i
        tip_z = zc + 0.36 - 0.05 * (i / 10) + rnd.uniform(-0.03, 0.03)
        a = math.radians(az + 14)
        tip = Vector((math.sin(a) * 0.72 + sweep * 0.25, -math.cos(a) * 0.72 - 0.06, tip_z))
        mid = (r + tip) / 2 + Vector((0, -0.12, 0.04))
        strand(m, "Head_bang", [r, mid, tip], rnd.uniform(0.12, 0.15), 0.025, HAIR if i % 3 else HAIR2)
    # one long lock down the left side of the face, and a shorter one on the right
    for sx, ln in ((1, 0.95), (-1, 0.75)):
        r = scalp(sx * 58, 40)
        strand(m, "Head_lock", [r, r + Vector((sx * 0.06, -0.05, -0.3)), r + Vector((sx * 0.07, -0.02, -ln))],
               0.15, 0.03, HAIR)
    return m


SEGMENTS = ["Head", "UpperTorso", "LowerTorso",
            "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
            "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"]
BONES = {
    "LowerTorso": ((0, 0, 2.1), (0, 0, 2.5), None),
    "UpperTorso": ((0, 0, 2.5), (0, 0, 4.0), "LowerTorso"),
    "Head": ((0, 0, 4.0), (0, 0, 5.4), "UpperTorso"),
    "LeftUpperArm": ((1.5, 0, 3.85), (1.5, 0, 3.2), "UpperTorso"),
    "LeftLowerArm": ((1.5, 0, 3.2), (1.5, 0, 2.45), "LeftUpperArm"),
    "LeftHand": ((1.5, 0, 2.45), (1.5, 0, 1.9), "LeftLowerArm"),
    "RightUpperArm": ((-1.5, 0, 3.85), (-1.5, 0, 3.2), "UpperTorso"),
    "RightLowerArm": ((-1.5, 0, 3.2), (-1.5, 0, 2.45), "RightUpperArm"),
    "RightHand": ((-1.5, 0, 2.45), (-1.5, 0, 1.9), "RightLowerArm"),
    "LeftUpperLeg": ((0.5, 0, 2.05), (0.5, 0, 1.2), "LowerTorso"),
    "LeftLowerLeg": ((0.5, 0, 1.2), (0.5, 0, 0.45), "LeftUpperLeg"),
    "LeftFoot": ((0.5, 0, 0.45), (0.5, -0.5, 0.1), "LeftLowerLeg"),
    "RightUpperLeg": ((-0.5, 0, 2.05), (-0.5, 0, 1.2), "LowerTorso"),
    "RightLowerLeg": ((-0.5, 0, 1.2), (-0.5, 0, 0.45), "RightUpperLeg"),
    "RightFoot": ((-0.5, 0, 0.45), (-0.5, -0.5, 0.1), "RightLowerLeg"),
}


def rig(m):
    """Join parts per R15 segment and parent each rigidly to its bone, like a Roblox R15 avatar."""
    parts = {s: [] for s in SEGMENTS}
    for o in m.objs:
        seg = o.name[len(m.name) + 1:].split("_")[0].split(".")[0]
        parts[seg].append(o)
    arm_data = bpy.data.armatures.new("Jeff_Rig")
    arm = bpy.data.objects.new("Jeff_Rig", arm_data)
    m.coll.objects.link(arm)
    arm.location = m.origin
    for s in bpy.context.selected_objects:
        s.select_set(False)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for bname, (h, t, parent) in BONES.items():
        b = arm_data.edit_bones.new(bname)
        b.head, b.tail = Vector(h), Vector(t)
        if parent:
            b.parent = arm_data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()
    for seg, objs in parts.items():
        if not objs:
            continue
        for o in objs:
            mw = o.matrix_world.copy()
            o.parent = None
            o.matrix_world = mw
        for s in bpy.context.selected_objects:
            s.select_set(False)
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.object.convert(target="MESH")
        if len(objs) > 1:
            bpy.ops.object.join()
        o = bpy.context.active_object
        o.name = o.data.name = f"Jeff_{seg}"
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        pb = arm.pose.bones[seg]
        bone_world = arm.matrix_world @ pb.matrix @ Matrix.Translation((0, pb.bone.length, 0))
        mw = o.matrix_world.copy()
        o.parent = arm
        o.parent_type = "BONE"
        o.parent_bone = seg
        o.matrix_parent_inverse = bone_world.inverted()
        o.matrix_world = mw
    bpy.data.objects.remove(m.root)
    return arm


# ---------------------------------------------------------------- scene + outputs
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)
for c in list(bpy.data.collections):
    if c.name.startswith("Jeff"):
        bpy.data.collections.remove(c)
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
sc.view_settings.view_transform = "AgX" if HQ else "Standard"
try:
    sc.view_settings.look = "AgX - Medium High Contrast" if HQ else "None"
except Exception:
    pass
sc.eevee.taa_render_samples = 256 if HQ else 32
if HQ:
    sc.eevee.use_raytracing = True
    sc.eevee.use_fast_gi = True
sc.world = sc.world or bpy.data.worlds.new("World")
sc.world.use_nodes = True
bg = sc.world.node_tree.nodes["Background"]
bg.inputs[0].default_value = lin("#3A2F5C")
bg.inputs[1].default_value = 0.7

model = build_jeff()
arm = rig(model)

bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=2.4, depth=0.2, location=(0, 0, -0.1))
ped = bpy.context.active_object
ped.name = "Pedestal"
ped.data.materials.append(mat("Pedestal", "#5B4A8A", rough=0.7))


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


light("Key", "AREA", (8, -12, 12), 9000, (45, 0, 32), 12, (1.0, 0.96, 0.9))
light("Fill", "AREA", (-11, -9, 6), 3200, (65, 0, -50), 12, (0.82, 0.84, 1.0))
light("Rim", "AREA", (-2, 13, 9), 7000, (-55, 0, 0), 14, (0.78, 0.66, 1.0))
light("Sun", "SUN", (0, 0, 10), 1.2, (40, 0, 25))

cd = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cd)
sc.collection.objects.link(cam)
sc.camera = cam
cd.lens = 70
sc.render.resolution_x, sc.render.resolution_y = 800 * Q, 1000 * Q


def shot(name, off, tgt_z=2.75):
    cam.location = Vector(off)
    cam.rotation_euler = (Vector((0, 0, tgt_z)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)


if not globals().get("SKIP_RENDER"):
    shot("jeff_front.png", (6.2, -15.5, 5.0))
    shot("jeff_face.png", (1.6, -7.4, 4.9), tgt_z=4.6)
    shot("jeff_back.png", (-9.5, 13.0, 5.6))
    pb = arm.pose.bones
    for b in pb:
        b.rotation_mode = "XYZ"
    pb["LeftUpperArm"].rotation_euler = (math.radians(80), 0, 0)
    pb["LeftLowerArm"].rotation_euler = (math.radians(10), 0, 0)
    pb["RightUpperArm"].rotation_euler = (math.radians(80), 0, 0)
    pb["RightLowerArm"].rotation_euler = (math.radians(10), 0, 0)
    pb["Head"].rotation_euler = (math.radians(-6), 0, math.radians(-12))
    pb["UpperTorso"].rotation_euler = (math.radians(-8), 0, 0)
    bpy.context.view_layer.update()
    shot("jeff_pose.png", (6.2, -15.5, 5.0))
    for b in pb:
        b.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()

for s in bpy.context.selected_objects:
    s.select_set(False)
arm.select_set(True)
for c in arm.children:
    c.select_set(True)
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "Jeff.fbx"), use_selection=True,
                         object_types={"ARMATURE", "MESH"}, add_leaf_bones=False, bake_anim=False,
                         apply_scale_options="FBX_SCALE_ALL")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "jeff.blend"))
result = {"out": OUT, "files": sorted(os.listdir(OUT)), "parts": [o.name for o in arm.children]}
print("DONE")

"""Builds the final Toy-style Jeff (the style picked from jeff_styles.py), rigs it
with an R15-named armature like the guest kids, renders previews and exports an FBX.

Run: blender -b --python make_jeff_toy.py -- <out_dir>
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


# ---------------------------------------------------------------- palette
SKIN = "#F6F3EF"
HOODIE = "#EEECF4"
PANTS = "#2A2A36"
SHOE = "#1C1B22"
SOLE = "#F2F0F5"
HAIR = "#17151D"
RING = "#3A2E47"     # soft grey-purple ring around the wide eyes
MOUTH = "#8E2A44"    # berry grin, not blood red


# ---------------------------------------------------------------- Toy Jeff (polished)
import random
from mathutils import Matrix


def build_jeff(origin=(0, 0, 0)):
    m = Model("Jeff", origin)
    S = mat("Jeff skin", SKIN, rough=0.32, coat=0.25)
    H = mat("Jeff hoodie", HOODIE, rough=0.55, coat=0.12)
    HD = mat("Jeff hoodie shade", "#D8D4E4", rough=0.6, coat=0.1)
    P = mat("Jeff pants", PANTS, rough=0.5, coat=0.15)
    SH = mat("Jeff shoe", SHOE, rough=0.35, coat=0.35)
    SO = mat("Jeff sole", SOLE, rough=0.5)
    LACE = mat("Jeff lace", "#E9E6F0", rough=0.6)
    HR = mat("Jeff hair", HAIR, rough=0.55)
    HRS = mat("Jeff hair sheen", "#2C2836", rough=0.4, coat=0.2)
    W = mat("Jeff eye white", "#FFFFFF", rough=0.12, coat=0.6)
    RG = mat("Jeff eye ring", RING, rough=0.45)
    PU = mat("Jeff pupil", "#0B0B10", rough=0.12, coat=0.5)
    SHN = mat("Jeff shine", "#FFFFFF", emit=2.5)
    MO = mat("Jeff mouth", MOUTH, rough=0.3, coat=0.4)
    CHK = mat("Jeff cheek", "#E9C9D3", rough=0.7)
    STR = mat("Jeff string", "#C9C5D6", rough=0.6)

    # legs, shoes with laces and soles
    for side, x in (("Left", 0.2), ("Right", -0.2)):
        m.sphere(f"{side}UpperLeg", (x, 0, 0.47), (0.17, 0.17, 0.3), P)
        m.torus(f"{side}UpperLeg_cuff", (x, 0, 0.24), 0.15, 0.04, P)
        m.sphere(f"{side}Foot", (x, -0.07, 0.12), (0.2, 0.29, 0.12), SH)
        m.sphere(f"{side}Foot_sole", (x, -0.07, 0.055), (0.21, 0.30, 0.06), SO)
        for j, z in enumerate((0.19, 0.205)):
            m.cyl(f"{side}Foot_lace", (x, -0.2 + j * 0.06, z), 0.012, 0.18, LACE, rot=(0, 90, 0))
    m.sphere("LowerTorso", (0, 0, 0.82), (0.36, 0.28, 0.2), P)
    # hoodie
    m.sphere("UpperTorso", (0, 0, 1.12), (0.46, 0.36, 0.46), H)
    m.torus("UpperTorso_hem", (0, 0, 0.78), 0.4, 0.075, H, scale=(1.02, 0.8, 1))
    m.sphere("UpperTorso_pocket", (0, -0.29, 0.95), (0.27, 0.1, 0.12), HD)
    m.sphere("UpperTorso_pocketlip", (0, -0.335, 1.0), (0.24, 0.04, 0.03), H)
    m.torus("UpperTorso_hood", (0, 0.12, 1.52), 0.27, 0.12, H, rot=(-22, 0, 0), scale=(1.15, 1, 1))
    m.sphere("UpperTorso_hoodback", (0, 0.3, 1.38), (0.3, 0.13, 0.2), HD)
    for x in (0.08, -0.08):
        m.line("UpperTorso_string", [(x, -0.3, 1.46), (x * 1.1, -0.365, 1.3), (x * 1.25, -0.37, 1.16)], 0.016, STR)
        m.sphere("UpperTorso_tip", (x * 1.25, -0.37, 1.14), (0.028, 0.028, 0.045), STR, segs=12)
    for side, sx in (("Left", 1), ("Right", -1)):
        m.sphere(f"{side}UpperArm", (sx * 0.54, 0, 1.17), (0.15, 0.15, 0.31), H, rot=(0, -sx * 30, 0))
        m.torus(f"{side}UpperArm_cuff", (sx * 0.67, 0, 0.95), 0.11, 0.05, H, rot=(0, -sx * 30, 0))
        m.sphere(f"{side}Hand", (sx * 0.72, 0, 0.85), (0.13, 0.12, 0.13), S)
        m.sphere(f"{side}Hand_thumb", (sx * 0.68, -0.09, 0.88), (0.045, 0.045, 0.06), S, rot=(0, -sx * 30, 0), segs=16)

    # head
    hc, hr = Vector((0, 0, 2.02)), 0.62
    m.sphere("Head", hc, (hr, hr * 0.96, hr * 0.98), S, segs=48)
    m.sphere("Head_neck", (0, 0, 1.55), (0.14, 0.14, 0.1), S)
    # hair: matte cap, soft chunky clumps on the back/top, pointed bangs, side locks
    cap_c = hc + Vector((0, 0.09, 0.1))
    m.sphere("Head_hair", cap_c, (hr * 1.05, hr * 0.99, hr * 0.97), HR, segs=48)
    m.sphere("Head_hair_nape", hc + Vector((0, 0.24, -0.16)), (hr * 0.9, hr * 0.62, hr * 0.62), HR, segs=40)
    rnd = random.Random(3)
    for i in range(11):
        az = 180 - 105 + i * (210 / 10)
        el = 25 + rnd.uniform(-5, 30)
        p, n = on_sphere(cap_c, hr * 0.98, az, el)
        d = (n + Vector((0, 0.35, 0.25))).normalized()
        m.cone("Head_clump", p + d * 0.08, 0.19, 0.035, 0.36 + rnd.uniform(0, 0.1), HR if i % 3 else HRS,
               rot=d.to_track_quat("Z", "Y"))
    for i in range(4):  # crown tufts
        az = -60 + i * 40
        p, n = on_sphere(cap_c, hr * 0.98, az + 180, 70)
        d = (n + Vector((rnd.uniform(-0.3, 0.3), 0.1, 0.2))).normalized()
        m.cone("Head_tuft", p + d * 0.05, 0.13, 0.025, 0.3, HR, rot=d.to_track_quat("Z", "Y"))
    bangs = ((-50, 44, 0.30), (-32, 50, 0.36), (-14, 52, 0.30), (4, 53, 0.38), (22, 51, 0.31), (40, 48, 0.35), (55, 40, 0.28))
    for az, el, ln in bangs:
        p, n = on_sphere(hc, hr * 1.02, az, el)
        d = (Vector((math.sin(math.radians(az)) * 0.25, -0.55, -1.0))).normalized()
        m.cone("Head_bang", p + d * (ln / 2 - 0.06), 0.11, 0.02, ln, HR, rot=d.to_track_quat("Z", "Y"))
    for sx in (1, -1):
        p, n = on_sphere(hc, hr * 1.0, sx * 72, 18)
        d = Vector((sx * 0.12, -0.25, -1)).normalized()
        m.cone("Head_lock", p + d * 0.2, 0.13, 0.025, 0.55, HR, rot=d.to_track_quat("Z", "Y"))
    # wide eyes with soft ring, small pupils and two shines
    for sx in (1, -1):
        p, n = on_sphere(hc, hr, sx * 23, 6)
        q = facing(n)
        m.sphere("Head_eyering", p, (0.18, 0.04, 0.195), RG, rot=q)
        p2, _ = on_sphere(hc, hr, sx * 23, 6, out=0.02)
        m.sphere("Head_eye", p2, (0.15, 0.04, 0.165), W, rot=q)
        p3, _ = on_sphere(hc, hr, sx * 21, 5, out=0.05)
        m.sphere("Head_pupil", p3, (0.048, 0.02, 0.054), PU, rot=q, segs=20)
        p4, _ = on_sphere(hc, hr, sx * 19.5, 7.5, out=0.068)
        m.sphere("Head_shine", p4, (0.018, 0.01, 0.018), SHN, rot=q, segs=12)
        p5, _ = on_sphere(hc, hr, sx * 22.5, 3.5, out=0.068)
        m.sphere("Head_shine", p5, (0.009, 0.006, 0.009), SHN, rot=q, segs=10)
        # soft cheeks
        p6, n6 = on_sphere(hc, hr, sx * 40, -16, out=-0.005)
        m.sphere("Head_cheek", p6, (0.08, 0.02, 0.05), CHK, rot=facing(n6), segs=20)
    # big friendly grin, slightly thicker in the middle, with curled corners
    pts = [on_sphere(hc, hr, a, e, out=0.006)[0] for a, e in
           ((-50, -5), (-37, -17), (-19, -25), (0, -27.5), (19, -25), (37, -17), (50, -5))]
    m.line("Head_grin", pts, 0.032, MO)
    for sx in (1, -1):
        a = on_sphere(hc, hr, sx * 50, -5, out=0.006)[0]
        b = on_sphere(hc, hr, sx * 52, 2, out=0.006)[0]
        c = on_sphere(hc, hr, sx * 49, 5, out=0.006)[0]
        m.line("Head_grin_curl", [a, b, c], 0.026, MO)
    return m


SEGMENTS = ["Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftHand", "RightUpperArm",
            "RightHand", "LeftUpperLeg", "LeftFoot", "RightUpperLeg", "RightFoot"]
BONES = {
    "LowerTorso": ((0, 0, 0.66), (0, 0, 0.9), None),
    "UpperTorso": ((0, 0, 0.9), (0, 0, 1.5), "LowerTorso"),
    "Head": ((0, 0, 1.5), (0, 0, 2.7), "UpperTorso"),
    "LeftUpperArm": ((0.4, 0, 1.4), (0.68, 0, 0.95), "UpperTorso"),
    "LeftHand": ((0.68, 0, 0.95), (0.78, 0, 0.74), "LeftUpperArm"),
    "RightUpperArm": ((-0.4, 0, 1.4), (-0.68, 0, 0.95), "UpperTorso"),
    "RightHand": ((-0.68, 0, 0.95), (-0.78, 0, 0.74), "RightUpperArm"),
    "LeftUpperLeg": ((0.2, 0, 0.72), (0.2, 0, 0.22), "LowerTorso"),
    "LeftFoot": ((0.2, 0, 0.22), (0.2, -0.25, 0.08), "LeftUpperLeg"),
    "RightUpperLeg": ((-0.2, 0, 0.72), (-0.2, 0, 0.22), "LowerTorso"),
    "RightFoot": ((-0.2, 0, 0.22), (-0.2, -0.25, 0.08), "RightUpperLeg"),
}


def rig(m):
    """Join parts per R15 segment and parent each to its bone (rigid, like the guest kids)."""
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
        for o in objs:
            mw = o.matrix_world.copy()
            o.parent = None
            o.matrix_world = mw
        for s in bpy.context.selected_objects:
            s.select_set(False)
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.object.convert(target="MESH")  # apply bevel modifiers
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
sc.view_settings.view_transform = "Standard"
sc.eevee.taa_render_samples = 256 if HQ else 32
if HQ:
    sc.eevee.use_raytracing = True
    sc.eevee.use_fast_gi = True
sc.world = sc.world or bpy.data.worlds.new("World")
sc.world.use_nodes = True
bg = sc.world.node_tree.nodes["Background"]
bg.inputs[0].default_value = lin("#3A2F5C")
bg.inputs[1].default_value = 0.9

model = build_jeff()
arm = rig(model)

bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=0.95, depth=0.12, location=(0, 0, -0.06))
ped = bpy.context.active_object
ped.name = "Pedestal"
ped.data.materials.append(mat("Pedestal", "#5B4A8A", rough=0.8))


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


light("Key", "AREA", (5, -8, 8), 2600, (48, 0, 30), 10, (1.0, 0.97, 0.92))
light("Fill", "AREA", (-7, -7, 4), 1000, (65, 0, -45), 10, (0.85, 0.85, 1.0))
light("Rim", "AREA", (0, 10, 6), 2000, (-55, 0, 0), 14, (0.8, 0.7, 1.0))
light("Sun", "SUN", (0, 0, 10), 1.4, (40, 0, 25))

cd = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cd)
sc.collection.objects.link(cam)
sc.camera = cam
cd.lens = 70
sc.render.resolution_x, sc.render.resolution_y = 800 * Q, 1000 * Q


def shot(name, off, tgt_z=1.3):
    cam.location = Vector(off)
    cam.rotation_euler = (Vector((0, 0, tgt_z)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)


if not globals().get("SKIP_RENDER"):
    shot("jeff_toy_front.png", (2.8, -7.6, 2.2))
    shot("jeff_toy_back.png", (-4.6, 6.6, 2.6))
    shot("jeff_toy_face.png", (0.9, -4.2, 2.2), tgt_z=1.95)
    # pose test: arms up "boo!" to show the rig works
    pb = arm.pose.bones
    for side, sx in (("Left", 1), ("Right", -1)):
        pb[f"{side}UpperArm"].rotation_mode = "XYZ"
        pb[f"{side}UpperArm"].rotation_euler = (math.radians(-60), 0, math.radians(sx * 0))
        pb[f"{side}UpperArm"].rotation_euler = (0, 0, 0)
    pb["LeftUpperArm"].rotation_mode = pb["RightUpperArm"].rotation_mode = "XYZ"
    pb["LeftUpperArm"].rotation_euler = (math.radians(-40), 0, math.radians(-110))
    pb["RightUpperArm"].rotation_euler = (math.radians(-40), 0, math.radians(110))
    pb["Head"].rotation_mode = "XYZ"
    pb["Head"].rotation_euler = (math.radians(-8), 0, math.radians(10))
    pb["UpperTorso"].rotation_mode = "XYZ"
    pb["UpperTorso"].rotation_euler = (math.radians(-10), 0, 0)
    bpy.context.view_layer.update()
    shot("jeff_toy_pose.png", (2.8, -7.6, 2.2))
    for b in pb:
        b.rotation_euler = (0, 0, 0)
        b.rotation_quaternion = (1, 0, 0, 0)
    bpy.context.view_layer.update()

# FBX for Roblox Studio
for s in bpy.context.selected_objects:
    s.select_set(False)
arm.select_set(True)
for c in arm.children:
    c.select_set(True)
bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, "Jeff_Toy.fbx"), use_selection=True,
                         object_types={"ARMATURE", "MESH"}, add_leaf_bones=False, bake_anim=False,
                         apply_scale_options="FBX_SCALE_ALL")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "jeff_toy.blend"))
result = {"out": OUT, "files": sorted(os.listdir(OUT)), "objects": [o.name for o in arm.children]}
print("DONE")

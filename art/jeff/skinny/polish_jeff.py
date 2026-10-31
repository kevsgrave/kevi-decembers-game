"""Polishes the slim (Boy-package) Jeff in art/jeff/jeff.blend in place.

Keeps the rig, bone names and the scare animation untouched. Replaces the blocky hair and the
pixel-step grin with smoother shapes, softens bevels and gives every material some surface detail.
All-ages: no blood, the grin is a dark plum mouth with teeth.

Run with the slim jeff.blend open in Blender:
    exec(open(r"<path>/polish_jeff.py").read(), {"HQ": True})
or headless: blender -b jeff.blend --python polish_jeff.py
"""
import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

HQ = globals().get("HQ", False)
rig = bpy.data.objects["Jeff_Rig"]
head_obj = bpy.data.objects["Jeff_Head"]
COLL = head_obj.users_collection[0]
old_pose = rig.data.pose_position
rig.data.pose_position = "REST"
bpy.context.view_layer.update()

HC = Vector((2.7, 3.0, 4.65))  # head centre at rest
FRONT_Y = 2.4                  # head front face


def lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c) + (1.0,)


# ------------------------------------------------------------------ materials
def bsdf(m):
    return m.node_tree.nodes["Principled BSDF"]


def add_bump(m, scale, strength, kind="noise"):
    nt = m.node_tree
    if any(n.label == "polish_bump" for n in nt.nodes):
        return
    b = bsdf(m)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    bp = nt.nodes.new("ShaderNodeBump")
    bp.label = "polish_bump"
    bp.inputs["Strength"].default_value = strength
    bp.inputs["Distance"].default_value = 0.02
    if kind == "noise":
        tx = nt.nodes.new("ShaderNodeTexNoise")
        tx.inputs["Scale"].default_value = scale
        tx.inputs["Detail"].default_value = 6.0
        nt.links.new(tc.outputs["Object"], tx.inputs["Vector"])
        nt.links.new(tx.outputs["Fac"], bp.inputs["Height"])
    else:  # vertical knit ribs that wrap all four sides
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        add = nt.nodes.new("ShaderNodeMath")
        add.operation = "ADD"
        mul = nt.nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        mul.inputs[1].default_value = 2 * math.pi / scale
        sin = nt.nodes.new("ShaderNodeMath")
        sin.operation = "SINE"
        nt.links.new(tc.outputs["Object"], sep.inputs[0])
        nt.links.new(sep.outputs[0], add.inputs[0])
        nt.links.new(sep.outputs[1], add.inputs[1])
        nt.links.new(add.outputs[0], mul.inputs[0])
        nt.links.new(mul.outputs[0], sin.inputs[0])
        nt.links.new(sin.outputs[0], bp.inputs["Height"])
    nt.links.new(bp.outputs["Normal"], b.inputs["Normal"])


def tune(name, color=None, rough=None, coat=0.0, sheen=0.0):
    m = bpy.data.materials[name]
    b = bsdf(m)
    if color:
        b.inputs["Base Color"].default_value = lin(color)
        m.diffuse_color = lin(color)
    if rough is not None:
        b.inputs["Roughness"].default_value = rough
    b.inputs["Coat Weight"].default_value = coat
    b.inputs["Coat Roughness"].default_value = 0.2
    b.inputs["Sheen Weight"].default_value = sheen
    b.inputs["Sheen Roughness"].default_value = 0.4
    return m


tune("Hoodie", "#EDEBF0", 0.85, sheen=0.5)
add_bump(bpy.data.materials["Hoodie"], 90, 0.1)
tune("HoodieTrim", "#BDBAC4", 0.9, sheen=0.4)
add_bump(bpy.data.materials["HoodieTrim"], 0.05, 0.22, kind="ribs")
tune("Pants", "#23222B", 0.8, sheen=0.3)
add_bump(bpy.data.materials["Pants"], 110, 0.25)
tune("PaleSkin", "#F4F1EC", 0.42, coat=0.12)
tune("Black", "#141219", 0.38, coat=0.25)
tune("Shoes", "#26252E", 0.4, coat=0.35)
tune("Teeth", "#FFFDF6", 0.3, coat=0.4)
tune("Mouth", "#3A1828", 0.55)
tune("EyeWhite", None, 0.12, coat=0.5)


def new_mat(name, color, rough=0.5, coat=0.0, emit=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = bsdf(m)
    b.inputs["Base Color"].default_value = lin(color)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Coat Weight"].default_value = coat
    if emit:
        b.inputs["Emission Color"].default_value = lin(color)
        b.inputs["Emission Strength"].default_value = emit
    m.diffuse_color = lin(color)
    return m


HAIR = bpy.data.materials["Black"]
HAIR2 = new_mat("HairSheen", "#26222F", 0.35, coat=0.3)
LIP = new_mat("GrinLine", "#5A2A3E", 0.5)
PUP = bpy.data.materials["Black"]
SHINE = new_mat("EyeShine", "#FFFFFF", 0.2, emit=2.0)

# ------------------------------------------------------------------ helpers


def attach(o, bone):
    bpy.context.view_layer.update()
    for c in list(o.users_collection):
        c.objects.unlink(o)
    COLL.objects.link(o)
    pb = rig.pose.bones[bone]
    bw = rig.matrix_world @ pb.matrix @ Matrix.Translation((0, pb.bone.length, 0))
    mw = o.matrix_world.copy()
    o.parent = rig
    o.parent_type = "BONE"
    o.parent_bone = bone
    o.matrix_parent_inverse = bw.inverted()
    o.matrix_world = mw
    return o


def kill(prefix):
    for o in [o for o in bpy.data.objects if o.name.startswith(prefix)]:
        bpy.data.objects.remove(o, do_unlink=True)


def smooth(o):
    for p in o.data.polygons:
        p.use_smooth = True


def lock(name, root, tip, w, thick, material, bone="Head", bend=Vector((0, 0, 0))):
    """A tapered, slightly flattened hair lock from root to tip (curved by `bend`)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 1.0
    cu.bevel_resolution = 4
    cu.resolution_u = 12
    cu.use_fill_caps = True
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(2)
    mid = (root + tip) / 2 + bend
    for i, (bp, p) in enumerate(zip(sp.bezier_points, (root, mid, tip))):
        bp.co = p
        bp.handle_left_type = bp.handle_right_type = "AUTO"
        bp.radius = (1.0, 0.85, 0.5)[i]
    o = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(o)
    o.data.bevel_depth = w
    for s in bpy.context.selected_objects:
        s.select_set(False)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.active_object
    o.name = name
    # flatten across the lock (along the head's surface normal) for a ribbon-like strand
    d = (tip - root).normalized()
    side = d.cross(Vector((0, 0, 1)))
    if side.length < 1e-3:
        side = Vector((1, 0, 0))
    o.data.materials.append(material)
    smooth(o)
    if thick != 1.0:
        n = (root - HC)
        n = (n - d * n.dot(d)).normalized()
        c = root
        for v in o.data.vertices:
            rel = v.co - c
            v.co = c + rel + n * (rel.dot(n) * (thick - 1.0))
    return attach(o, bone)


def flat_patch(name, x0, x1, top, bottom, y, depth, material, cols=40):
    """Flat shape on the head's front face between two curves top(t), bottom(t), t in [0,1]."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    rows = []
    for i in range(cols + 1):
        t = i / cols
        x = x0 + (x1 - x0) * t
        rows.append((bm.verts.new((x, y, top(t))), bm.verts.new((x, y, bottom(t)))))
    for i in range(cols):
        a, b = rows[i], rows[i + 1]
        bm.faces.new((a[0], a[1], b[1], b[0]))
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    sol = o.modifiers.new("Thick", "SOLIDIFY")
    sol.thickness = depth
    sol.offset = 0
    o.data.materials.append(material)
    for s in bpy.context.selected_objects:
        s.select_set(False)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.modifier_apply(modifier="Thick")
    return attach(o, "Head")


def tube(name, pts, r, material, bone="Head"):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = 3
    cu.use_fill_caps = True
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(len(pts) - 1)
    for bp, p in zip(sp.bezier_points, pts):
        bp.co = Vector(p)
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    o = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(o)
    for s in bpy.context.selected_objects:
        s.select_set(False)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(material)
    smooth(o)
    return attach(o, bone)


# ------------------------------------------------------------------ softer blocks
for o in bpy.data.objects:
    if o.name.startswith("Jeff_") and o.type == "MESH":
        for md in o.modifiers:
            if md.type == "BEVEL":
                md.segments = 5 if HQ else 4
                md.harden_normals = False
        if any(md.type == "BEVEL" for md in o.modifiers):
            smooth(o)
            if hasattr(o.data, "use_auto_smooth"):
                o.data.use_auto_smooth = True
hb = [m for m in head_obj.modifiers if m.type == "BEVEL"][0]
hb.width = 0.22
hb.segments = 8

# ------------------------------------------------------------------ hair
rnd = random.Random(8)
kill("Jeff_HairSpike")
kill("Jeff_HairBang")
kill("Jeff_HairStrand")
kill("Jeff_HairLock")
cap = bpy.data.objects["Jeff_HairCap"]
[m for m in cap.modifiers if m.type == "BEVEL"][0].width = 0.13
for n in ("Jeff_HairBack", "Jeff_HairSideL", "Jeff_HairSideR", "Jeff_HairBackTip"):
    md = [m for m in bpy.data.objects[n].modifiers if m.type == "BEVEL"][0]
    md.width = max(md.width, 0.07)

top_z = 5.42
# crown: soft locks lying on top, swept back from a slight part, so the top looks messy, not blocky
i = 0
for row, y in enumerate((2.55, 2.85, 3.15, 3.45)):
    for x in (2.15, 2.45, 2.75, 3.05, 3.3):
        jitter = Vector((rnd.uniform(-0.08, 0.08), rnd.uniform(-0.06, 0.06), 0))
        root = Vector((x, y, top_z + 0.05)) + jitter
        sx = 1 if x >= 2.7 else -1
        tip = root + Vector((sx * rnd.uniform(0.18, 0.32), rnd.uniform(0.25, 0.45), rnd.uniform(0.06, 0.18)))
        lock(f"Jeff_HairLockTop{i:02d}", root, tip, rnd.uniform(0.11, 0.14), 0.6,
             HAIR if i % 4 else HAIR2, bend=Vector((0, 0, 0.06)))
        i += 1
# bangs: a fringe of tapered locks over the forehead, longer toward his left side, eyes stay clear
for j in range(9):
    t = j / 8
    x = 2.1 + 1.2 * t
    ln = 0.3 + 0.18 * math.sin(t * math.pi * 1.5 + 0.4) + 0.12 * t + rnd.uniform(-0.04, 0.04)
    root = Vector((x, FRONT_Y + 0.12, 5.38))
    tip = Vector((x + 0.06 + 0.05 * t, FRONT_Y - 0.06, 5.3 - ln))
    tip.z = max(tip.z, 5.0)
    lock(f"Jeff_HairBang{j:02d}", root, tip, 0.13, 0.35, HAIR if j % 3 else HAIR2,
         bend=Vector((0, -0.08, 0.02)))
# side locks that frame the face down to the jaw
for sx, xs in ((-1, 2.08), (1, 3.32)):
    for k in range(3):
        root = Vector((xs + sx * 0.05, FRONT_Y + 0.12 + k * 0.25, 5.25))
        tip = Vector((xs + sx * 0.1, FRONT_Y + 0.02 + k * 0.28, 4.1 + k * 0.08 + rnd.uniform(-0.05, 0.05)))
        lock(f"Jeff_HairLockSide{'L' if sx < 0 else 'R'}{k}", root, tip, 0.14, 0.55, HAIR,
             bend=Vector((sx * 0.06, -0.03, 0)))
# back: long locks hanging to the neck with a little flick
for k in range(9):
    x = 2.1 + k * 0.15
    root = Vector((x, 3.62, 5.3))
    tip = Vector((x + rnd.uniform(-0.05, 0.05), 3.85 + rnd.uniform(0, 0.08), 3.8 + rnd.uniform(-0.06, 0.08)))
    lock(f"Jeff_HairLockBack{k}", root, tip, 0.15, 0.55, HAIR if k % 3 else HAIR2, bend=Vector((0, 0.08, 0)))

# ------------------------------------------------------------------ face: smooth grin, no blood
for p in ("Jeff_GrinLine", "Jeff_GrinTop", "Jeff_GrinTeeth", "Jeff_GrinCurl", "Jeff_Mouth", "Jeff_Teeth",
          "Jeff_ToothGap", "Jeff_GrinDimple", "Jeff_EyeShine"):
    kill(p)
X0, X1 = 2.24, 3.16
CZ = 4.5
top = lambda t: CZ - 0.07 * (1 - (2 * t - 1) ** 2)
bot = lambda t: CZ - 0.27 * (1 - (2 * t - 1) ** 2) ** 0.8
flat_patch("Jeff_Mouth", X0, X1, top, bot, FRONT_Y - 0.008, 0.008, bpy.data.materials["Mouth"])
tbot = lambda t: top(t) - 0.075 * (1 - (2 * t - 1) ** 2) ** 0.45
flat_patch("Jeff_Teeth", X0 + 0.05, X1 - 0.05, lambda t: top(0.05 + 0.9 * t) - 0.004,
           lambda t: tbot(0.05 + 0.9 * t), FRONT_Y - 0.016, 0.006, bpy.data.materials["Teeth"])
for g in range(1, 11):
    t = g / 11
    u = 0.05 + 0.9 * t
    x = X0 + 0.05 + (X1 - X0 - 0.1) * t
    h = top(u) - tbot(u)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, FRONT_Y - 0.021, (top(u) + tbot(u)) / 2))
    o = bpy.context.active_object
    o.name = f"Jeff_ToothGap{g:02d}"
    o.scale = (0.012, 0.006, max(0.01, h * 0.9))
    o.data.materials.append(bpy.data.materials["Mouth"])
    attach(o, "Head")
tube("Jeff_GrinLine", [(X0 + (X1 - X0) * t, FRONT_Y - 0.016, top(t) + 0.004) for t in (0, 0.12, 0.3, 0.5, 0.7, 0.88, 1)],
     0.012, LIP)
for sx, x in ((-1, X0), (1, X1)):
    tube(f"Jeff_GrinDimple{'L' if sx < 0 else 'R'}",
         [(x, FRONT_Y - 0.016, CZ), (x + sx * 0.05, FRONT_Y - 0.016, CZ + 0.06), (x + sx * 0.035, FRONT_Y - 0.016, CZ + 0.11)],
         0.011, LIP)
POCK = new_mat("HoodiePocket", "#DCD9E2", 0.85)
pk = bpy.data.objects["Jeff_Pocket"]
pk.data.materials.clear()
pk.data.materials.append(POCK)
PM = new_mat("PupilMatte", "#0B0A0F", 0.7)
for n in ("Jeff_PupilL", "Jeff_PupilR"):
    bpy.data.objects[n].data.materials.clear()
    bpy.data.objects[n].data.materials.append(PM)
# eyes: second, smaller shine for a livelier look; pupils matte so they read black
bpy.data.materials["Black"].node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.38
for s, ex in (("L", 2.44), ("R", 2.96)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.016, depth=0.01,
                                        location=(ex + 0.05, FRONT_Y - 0.045, 4.69), rotation=(math.radians(90), 0, 0))
    o = bpy.context.active_object
    o.name = f"Jeff_EyeShine{s}"
    o.data.materials.append(SHINE)
    attach(o, "Head")

rig.data.pose_position = old_pose
bpy.context.view_layer.update()

sc = bpy.context.scene
sc.view_settings.view_transform = "AgX"
try:
    sc.view_settings.look = "AgX - Medium High Contrast"
except Exception:
    pass
if HQ:
    sc.eevee.taa_render_samples = 128
    sc.eevee.use_raytracing = True
    sc.eevee.use_fast_gi = True
result = {"objects": len([o for o in bpy.data.objects if o.name.startswith("Jeff_")])}
print("POLISHED", result)

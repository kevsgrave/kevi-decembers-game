"""Builds the 15 pajama guest kids in Blender.

Outlines come from Freestyle at render time; the meshes carry no outline shell.

Run inside Blender (background is fine). Each kid gets its own collection with
R15-style body-part meshes parented to an R15-named armature, so the models can
be posed, animated and imported into Roblox Studio.
"""
import math
import bpy
from mathutils import Matrix, Vector

KIDS = [
    # name, species, fur, fur2 (muzzle/inner), ears, pj, pj2 (trim), pattern, cap, tail, nose
    ("Pip", "Bunny", "#F2E8DC", "#F7B8C8", "long", "#9FD3F5", "#FFFFFF", "dots", False, "puff", "#F28CA8"),
    ("Bramble", "Bear Cub", "#A87452", "#E3C4A0", "round", "#7FBF6A", "#F5E9C9", "plaid", False, "stub", "#3A2A22"),
    ("Mochi", "Kitten", "#F3A65A", "#FFF1DE", "pointy", "#C9A7F0", "#FFF6C2", "stars", True, "long", "#F28CA8"),
    ("Biscuit", "Puppy", "#E8C49A", "#FFF3E2", "floppy", "#F59C9C", "#FFFFFF", "stripes", True, "stub", "#3A2A22"),
    ("Ember", "Fox", "#E8763A", "#FFF6EC", "pointy", "#4F7FD6", "#FFD866", "stripes", False, "bushy", "#2B2020"),
    ("Clover", "Fawn", "#C98E5C", "#F6E2C8", "fawn", "#F7D46B", "#FFFFFF", "dots", True, "puff", "#3A2A22"),
    ("Nibbles", "Mouse", "#B8B4C4", "#F5B9C8", "mouse", "#8FD9C2", "#FFFFFF", "plaid", False, "thin", "#F28CA8"),
    ("Bandit", "Raccoon", "#8C8A93", "#E9E6EE", "round", "#E84E5A", "#FFFFFF", "stripes", True, "ringed", "#2B2B2B"),
    ("Dumpling", "Panda", "#F7F7F5", "#2E2E33", "round", "#F2A9D0", "#FFFFFF", "dots", False, "stub", "#2B2B2B"),
    ("Truffle", "Piglet", "#F6B8C3", "#F28FA3", "pig", "#7FD0E8", "#FFFFFF", "stars", False, "curl", "#E07890"),
    ("Lily", "Frog", "#8ED36B", "#E6F7C7", "frog", "#FFB066", "#FFF3D6", "dots", True, "none", "#5A9C45"),
    ("Cotton", "Lamb", "#FAF6EE", "#F0D9C6", "floppy", "#A0B4F2", "#FFFFFF", "stars", False, "puff", "#C98E8E"),
    ("Gumtree", "Koala", "#A3A6AD", "#F2F2F2", "koala", "#9BD6A0", "#FFFFFF", "plaid", False, "none", "#3C3C42"),
    ("Peanut", "Hamster", "#F0C27B", "#FFF4E0", "hamster", "#B9A2E8", "#FFE680", "stripes", True, "none", "#F28CA8"),
    ("Maple", "Red Panda", "#C8552E", "#FFF8F0", "pointy", "#6CC3B9", "#FFFFFF", "plaid", False, "ringed", "#2B2020"),
]

SEGMENTS = ["Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftHand", "RightUpperArm",
            "RightHand", "LeftUpperLeg", "LeftFoot", "RightUpperLeg", "RightFoot"]


def lin(hexstr):
    h = hexstr.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


_mats = {}


def mat(key, color, rough=0.75, pattern=None, color2=None, emit=0.0):
    k = (key, color, pattern, color2)
    if k in _mats:
        return _mats[k]
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = rough
    if emit:
        bsdf.inputs["Emission Color"].default_value = lin(color)
        bsdf.inputs["Emission Strength"].default_value = emit
    if pattern:
        tc = nt.nodes.new("ShaderNodeTexCoord")
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.inputs[6].default_value = lin(color)
        mix.inputs[7].default_value = lin(color2)
        if pattern == "stripes":
            tex = nt.nodes.new("ShaderNodeTexWave")
            tex.bands_direction = "Z"
            tex.inputs["Scale"].default_value = 3.0
            nt.links.new(tc.outputs["Object"], tex.inputs["Vector"])
            ramp = nt.nodes.new("ShaderNodeValToRGB")
            ramp.color_ramp.interpolation = "CONSTANT"
            ramp.color_ramp.elements[1].position = 0.55
            nt.links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
            nt.links.new(ramp.outputs["Color"], mix.inputs[0])
        elif pattern in ("dots", "stars"):
            tex = nt.nodes.new("ShaderNodeTexVoronoi")
            tex.inputs["Scale"].default_value = 7.0 if pattern == "dots" else 5.0
            tex.inputs["Randomness"].default_value = 0.0 if pattern == "dots" else 0.6
            nt.links.new(tc.outputs["Object"], tex.inputs["Vector"])
            ramp = nt.nodes.new("ShaderNodeValToRGB")
            ramp.color_ramp.interpolation = "CONSTANT"
            ramp.color_ramp.elements[0].color = (1, 1, 1, 1)
            ramp.color_ramp.elements[1].color = (0, 0, 0, 1)
            ramp.color_ramp.elements[1].position = 0.18 if pattern == "dots" else 0.12
            nt.links.new(tex.outputs["Distance"], ramp.inputs["Fac"])
            nt.links.new(ramp.outputs["Color"], mix.inputs[0])
        elif pattern == "plaid":
            tex = nt.nodes.new("ShaderNodeTexChecker")
            tex.inputs["Scale"].default_value = 4.0
            tex.inputs["Color1"].default_value = (1, 1, 1, 1)
            tex.inputs["Color2"].default_value = (0.35, 0.35, 0.35, 1)
            nt.links.new(tc.outputs["Object"], tex.inputs["Vector"])
            nt.links.new(tex.outputs["Fac"], mix.inputs[0])
            mix.inputs[0].default_value = 0.5
        nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = lin(color)
    m.diffuse_color = lin(color)
    _mats[k] = m
    return m


class Kid:
    def __init__(self, coll, origin):
        self.coll = coll
        self.origin = Vector(origin)
        self.parts = {s: [] for s in SEGMENTS}

    def _link(self, obj, seg, material):
        for c in obj.users_collection:
            c.objects.unlink(obj)
        self.coll.objects.link(obj)
        obj.data.materials.append(material)
        self.parts[seg].append(obj)
        return obj

    def sphere(self, seg, loc, scale, material, rot=(0, 0, 0), segs=32):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=segs // 2, radius=1,
                                             location=self.origin + Vector(loc))
        o = bpy.context.active_object
        o.scale = scale
        o.rotation_euler = [math.radians(a) for a in rot]
        bpy.ops.object.shade_smooth()
        return self._link(o, seg, material)

    def cone(self, seg, loc, r1, r2, depth, material, rot=(0, 0, 0), scale=(1, 1, 1)):
        bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=r1, radius2=r2, depth=depth,
                                        location=self.origin + Vector(loc))
        o = bpy.context.active_object
        o.scale = scale
        o.rotation_euler = [math.radians(a) for a in rot]
        bpy.ops.object.shade_smooth()
        return self._link(o, seg, material)

    def torus(self, seg, loc, major, minor, material, rot=(0, 0, 0), scale=(1, 1, 1)):
        bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=32,
                                         minor_segments=12, location=self.origin + Vector(loc))
        o = bpy.context.active_object
        o.scale = scale
        o.rotation_euler = [math.radians(a) for a in rot]
        bpy.ops.object.shade_smooth()
        return self._link(o, seg, material)

    def line(self, seg, pts, width, material):
        cu = bpy.data.curves.new("line", "CURVE")
        cu.dimensions = "3D"
        cu.bevel_depth = width
        cu.bevel_resolution = 3
        cu.use_fill_caps = True
        sp = cu.splines.new("BEZIER")
        sp.bezier_points.add(len(pts) - 1)
        for bp, p in zip(sp.bezier_points, pts):
            bp.co = self.origin + Vector(p)
            bp.handle_left_type = bp.handle_right_type = "AUTO"
        o = bpy.data.objects.new("line", cu)
        bpy.context.scene.collection.objects.link(o)
        bpy.context.view_layer.objects.active = o
        for s in bpy.context.selected_objects:
            s.select_set(False)
        o.select_set(True)
        bpy.ops.object.convert(target="MESH")
        o = bpy.context.active_object
        return self._link(o, seg, material)


def build_kid(spec, origin, coll):
    (name, species, fur, fur2, ears, pj, pj2, pattern, cap, tail, nose) = spec
    k = Kid(coll, origin)
    F = mat(f"{species} fur", fur)
    F2 = mat(f"{species} fur2", fur2)
    PJ = mat(f"{name} pajamas", pj, pattern=pattern, color2=pj2)
    TRIM = mat(f"{name} trim", pj2, rough=0.6)
    EYE = mat("Eye black", "#0B0B10", rough=0.15)
    SHINE = mat("Eye shine", "#FFFFFF", rough=0.2, emit=1.5)
    NOSE = mat(f"{species} nose", nose, rough=0.35)
    BLUSH = mat("Blush", "#FF9DB0", rough=0.8)
    SLIP = mat(f"{name} slippers", pj2 if pj2 != "#FFFFFF" else "#F4F0FF", rough=0.9)
    DARK = mat(f"{species} dark", "#3B3A42" if species != "Red Panda" else "#5A2A1C")

    # Legs and slippers
    for side, x in (("Left", 0.2), ("Right", -0.2)):
        k.sphere(f"{side}UpperLeg", (x, 0, 0.45), (0.17, 0.17, 0.3), PJ)
        k.torus(f"{side}UpperLeg", (x, 0, 0.2), 0.16, 0.05, TRIM)
        k.sphere(f"{side}Foot", (x, -0.06, 0.1), (0.2, 0.28, 0.12), SLIP)
        k.sphere(f"{side}Foot", (x, -0.18, 0.18), (0.09, 0.09, 0.07), mat("Pompom", "#FFFFFF"))
    # Hips and torso
    k.sphere("LowerTorso", (0, 0, 0.78), (0.4, 0.31, 0.25), PJ)
    k.sphere("UpperTorso", (0, 0, 1.12), (0.45, 0.35, 0.45), PJ)
    k.torus("UpperTorso", (0, -0.02, 1.5), 0.21, 0.07, TRIM, scale=(1.15, 1, 1))
    for i, z in enumerate((1.32, 1.12, 0.92)):
        t = (z - 1.12) / 0.45
        y = -0.35 * math.sqrt(max(0.0, 1 - t * t)) - 0.01
        k.sphere("UpperTorso", (0, y, z), (0.045, 0.025, 0.045), TRIM, segs=16)
    # Arms
    for side, sx in (("Left", 1), ("Right", -1)):
        k.sphere(f"{side}UpperArm", (sx * 0.53, 0, 1.17), (0.14, 0.14, 0.3), PJ, rot=(0, -sx * 35, 0))
        k.torus(f"{side}UpperArm", (sx * 0.67, 0, 0.97), 0.11, 0.045, TRIM, rot=(0, -sx * 35, 0))
        k.sphere(f"{side}Hand", (sx * 0.73, 0, 0.87), (0.14, 0.13, 0.14), F)
    # Head
    k.sphere("Head", (0, 0, 2.15), (0.78, 0.7, 0.72), F, segs=48)
    if species not in ("Frog",):
        if species in ("Fox", "Red Panda", "Puppy", "Bear Cub", "Fawn", "Kitten", "Raccoon", "Koala", "Hamster", "Lamb"):
            k.sphere("Head", (0, -0.6, 1.95), (0.33, 0.16, 0.2), F2)
    if species == "Piglet":
        k.sphere("Head", (0, -0.72, 2.02), (0.17, 0.08, 0.12), F2)
        for sx in (1, -1):
            k.sphere("Head", (sx * 0.06, -0.795, 2.02), (0.025, 0.01, 0.035), NOSE, segs=12)
    if species == "Raccoon":
        k.sphere("Head", (0, -0.5, 2.2), (0.66, 0.2, 0.17), DARK)
    if species == "Red Panda":
        for sx in (1, -1):
            k.sphere("Head", (sx * 0.27, -0.6, 2.36), (0.12, 0.05, 0.06), F2, segs=16)
            k.sphere("Head", (sx * 0.27, -0.56, 1.93), (0.1, 0.06, 0.16), DARK, rot=(0, sx * -20, 0), segs=16)
    if species == "Fawn":
        for (x, z) in ((0.42, 2.55), (-0.38, 2.6), (0.12, 2.75), (-0.1, 2.72)):
            k.sphere("Head", (x, -0.42, z), (0.06, 0.03, 0.05), mat("Fawn spot", "#FFF3DE"), segs=12, rot=(-40, 0, 0))
    # Eyes
    for sx in (1, -1):
        if species == "Panda":
            k.sphere("Head", (sx * 0.29, -0.58, 2.17), (0.24, 0.12, 0.28), DARK, rot=(0, sx * -25, sx * 15))
        k.sphere("Head", (sx * 0.27, -0.645, 2.2), (0.17, 0.06, 0.2), EYE, rot=(0, 0, sx * 18))
        k.sphere("Head", (sx * 0.27 + 0.06, -0.695, 2.29), (0.045, 0.02, 0.045), SHINE, segs=16)
        k.sphere("Head", (sx * 0.27 - 0.05, -0.69, 2.13), (0.022, 0.01, 0.022), SHINE, segs=12)
        k.sphere("Head", (sx * 0.47, -0.53, 2.0), (0.1, 0.03, 0.06), BLUSH, rot=(0, 0, sx * 38), segs=16)
    # Nose and mouth
    has_muzzle = species not in ("Frog", "Bunny", "Mouse", "Panda", "Piglet")
    if species != "Piglet":
        ny = -0.77 if has_muzzle else -0.7
        k.sphere("Head", (0, ny, 2.06), (0.07, 0.04, 0.05), NOSE, segs=16)
    my = -0.765 if has_muzzle else -0.69
    k.line("Head", [(-0.07, my, 1.94), (0, my - 0.005, 1.91), (0.07, my, 1.94)], 0.012, EYE)
    # Ears
    if ears == "long":
        for sx in (1, -1):
            k.sphere("Head", (sx * 0.22, 0.05, 3.1), (0.12, 0.07, 0.45), F, rot=(0, sx * 10, 0))
            k.sphere("Head", (sx * 0.22, 0.0, 3.1), (0.07, 0.04, 0.36), F2, rot=(0, sx * 10, 0))
    elif ears == "round":
        for sx in (1, -1):
            k.sphere("Head", (sx * 0.5, 0.05, 2.7), (0.2, 0.09, 0.2), DARK if species == "Panda" else F)
            if species != "Panda":
                k.sphere("Head", (sx * 0.5, -0.0, 2.7), (0.12, 0.06, 0.12), F2)
    elif ears == "pointy":
        for sx in (1, -1):
            k.cone("Head", (sx * 0.45, 0.05, 2.72), 0.21, 0.0, 0.42, F, rot=(0, sx * 28, 0), scale=(1, 0.5, 1))
            k.cone("Head", (sx * 0.44, 0.0, 2.7), 0.12, 0.0, 0.28, F2, rot=(0, sx * 28, 0), scale=(1, 0.4, 1))
    elif ears == "floppy":
        ear_mat = mat(f"{species} ear", "#C99A6A" if species == "Puppy" else "#F0D9C6")
        for sx in (1, -1):
            k.sphere("Head", (sx * 0.7, 0.0, 2.25), (0.15, 0.08, 0.36), ear_mat, rot=(0, -sx * 20, 0))
        if species == "Lamb":
            for (x, z) in ((0, 2.8), (0.22, 2.74), (-0.22, 2.74), (0.11, 2.86), (-0.11, 2.86)):
                k.sphere("Head", (x, -0.15, z), (0.16, 0.16, 0.14), F, segs=20)
    elif ears == "mouse":
        for sx in (1, -1):
            k.sphere("Head", (sx * 0.56, 0.08, 2.7), (0.3, 0.08, 0.3), F)
            k.sphere("Head", (sx * 0.56, 0.02, 2.7), (0.21, 0.05, 0.21), F2)
    elif ears == "koala":
        for sx in (1, -1):
            k.sphere("Head", (sx * 0.7, 0.05, 2.45), (0.3, 0.1, 0.28), F)
            k.sphere("Head", (sx * 0.7, 0.0, 2.45), (0.2, 0.07, 0.19), F2)
    elif ears == "fawn":
        for sx in (1, -1):
            k.sphere("Head", (sx * 0.72, 0.02, 2.45), (0.1, 0.05, 0.25), F, rot=(0, sx * 62, 0))
            k.sphere("Head", (sx * 0.71, -0.02, 2.45), (0.06, 0.03, 0.18), F2, rot=(0, sx * 62, 0))
    elif ears == "pig":
        for sx in (1, -1):
            k.cone("Head", (sx * 0.42, -0.05, 2.75), 0.18, 0.0, 0.32, F, rot=(-25, sx * 25, 0), scale=(1, 0.5, 1))
    elif ears == "hamster":
        for sx in (1, -1):
            k.sphere("Head", (sx * 0.46, 0.02, 2.72), (0.14, 0.06, 0.14), F)
            k.sphere("Head", (sx * 0.46, -0.02, 2.72), (0.09, 0.04, 0.09), F2)
    elif ears == "frog":
        for sx in (1, -1):
            k.sphere("Head", (sx * 0.32, -0.15, 2.72), (0.2, 0.2, 0.18), F)
    # Tails (on the LowerTorso)
    if tail == "puff":
        k.sphere("LowerTorso", (0, 0.32, 0.78), (0.13, 0.12, 0.13), mat("Tail puff", "#FFFFFF"))
    elif tail == "stub":
        k.sphere("LowerTorso", (0, 0.3, 0.8), (0.09, 0.08, 0.09), F)
    elif tail == "long":
        k.line("LowerTorso", [(0, 0.28, 0.75), (0.1, 0.55, 0.85), (0.3, 0.6, 1.15)], 0.06, F)
    elif tail == "thin":
        k.line("LowerTorso", [(0, 0.28, 0.72), (-0.15, 0.6, 0.65), (-0.35, 0.7, 0.85)], 0.025, F2)
    elif tail == "bushy":
        k.sphere("LowerTorso", (0.12, 0.5, 0.82), (0.17, 0.3, 0.17), F, rot=(30, 0, 20))
        k.sphere("LowerTorso", (0.2, 0.74, 0.95), (0.12, 0.13, 0.12), F2)
    elif tail == "ringed":
        for i in range(5):
            k.sphere("LowerTorso", (0, 0.32 + i * 0.1, 0.75 + i * 0.07), (0.13, 0.08, 0.13),
                     DARK if i % 2 else F, rot=(35, 0, 0), segs=20)
    elif tail == "curl":
        k.torus("LowerTorso", (0, 0.36, 0.84), 0.08, 0.025, F, rot=(0, 90, 0))
    # Nightcap
    if cap:
        cap_mat = mat(f"{name} cap", pj, pattern=pattern, color2=pj2)
        k.torus("Head", (0, 0.06, 2.72), 0.38, 0.07, TRIM, rot=(-12, 0, 0))
        k.cone("Head", (-0.12, 0.12, 3.08), 0.4, 0.06, 0.75, cap_mat, rot=(-12, -22, 0))
        k.sphere("Head", (-0.27, 0.17, 3.47), (0.1, 0.1, 0.1), mat("Pompom", "#FFFFFF"), segs=20)
    return k


BONES = {
    # name: (head, tail, parent)
    "LowerTorso": ((0, 0, 0.62), (0, 0, 0.9), None),
    "UpperTorso": ((0, 0, 0.9), (0, 0, 1.5), "LowerTorso"),
    "Head": ((0, 0, 1.5), (0, 0, 2.6), "UpperTorso"),
    "LeftUpperArm": ((0.38, 0, 1.4), (0.68, 0, 0.95), "UpperTorso"),
    "LeftHand": ((0.68, 0, 0.95), (0.8, 0, 0.75), "LeftUpperArm"),
    "RightUpperArm": ((-0.38, 0, 1.4), (-0.68, 0, 0.95), "UpperTorso"),
    "RightHand": ((-0.68, 0, 0.95), (-0.8, 0, 0.75), "RightUpperArm"),
    "LeftUpperLeg": ((0.2, 0, 0.7), (0.2, 0, 0.2), "LowerTorso"),
    "LeftFoot": ((0.2, 0, 0.2), (0.2, -0.25, 0.08), "LeftUpperLeg"),
    "RightUpperLeg": ((-0.2, 0, 0.7), (-0.2, 0, 0.2), "LowerTorso"),
    "RightFoot": ((-0.2, 0, 0.2), (-0.2, -0.25, 0.08), "RightUpperLeg"),
}


def finish_kid(k, label):
    arm_data = bpy.data.armatures.new(f"{label}_Rig")
    arm = bpy.data.objects.new(f"{label}_Rig", arm_data)
    k.coll.objects.link(arm)
    arm.location = k.origin
    bpy.context.view_layer.objects.active = arm
    for s in bpy.context.selected_objects:
        s.select_set(False)
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for bname, (h, t, parent) in BONES.items():
        b = arm_data.edit_bones.new(bname)
        b.head, b.tail = Vector(h), Vector(t)
        if parent:
            b.parent = arm_data.edit_bones[parent]
            b.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()
    for seg, objs in k.parts.items():
        if not objs:
            continue
        for s in bpy.context.selected_objects:
            s.select_set(False)
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        o = bpy.context.active_object
        o.name = f"{label}_{seg}"
        o.data.name = o.name
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        pb = arm.pose.bones[seg]
        bone_world = arm.matrix_world @ pb.matrix @ Matrix.Translation((0, pb.bone.length, 0))
        mw = o.matrix_world.copy()
        o.parent = arm
        o.parent_type = "BONE"
        o.parent_bone = seg
        o.matrix_parent_inverse = bone_world.inverted()
        o.matrix_world = mw
    return arm


def build_all(columns=5, spacing=(2.4, 3.2)):
    rigs = []
    for i, spec in enumerate(KIDS):
        label = f"{spec[0]}_{spec[1].replace(' ', '')}"
        coll = bpy.data.collections.new(label)
        bpy.context.scene.collection.children.link(coll)
        col, row = i % columns, i // columns
        origin = ((col - (columns - 1) / 2) * spacing[0], row * spacing[1], 0)
        k = build_kid(spec, origin, coll)
        rigs.append(finish_kid(k, label))
    return rigs

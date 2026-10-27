"""Builds all 15 guest kids, renders previews, exports FBX files and saves guests.blend.

Run from Blender: blender -b guests.blend --python render_all.py
"""
import math
import os

import bpy
from mathutils import Vector

D = os.path.dirname(os.path.abspath(__file__))
exec(compile(open(os.path.join(D, "make_guests.py")).read(), "make_guests", "exec"))

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
sc.view_settings.view_transform = "Standard"
sc.eevee.taa_render_samples = 64
sc.world = sc.world or bpy.data.worlds.new("World")
sc.world.use_nodes = True
bg = sc.world.node_tree.nodes["Background"]
bg.inputs[0].default_value = lin("#2A2D45")
bg.inputs[1].default_value = 0.8

rigs = build_all(columns=5, spacing=(2.4, 3.2))
# Character-sheet layout: 3 rows of 5, rows stacked vertically so none hide another
for i, rig in enumerate(rigs):
    rig.location = ((i % 5 - 2) * 2.6, 0, -(i // 5) * 4.3)
bpy.context.view_layer.update()


def light(name, kind, loc, energy, rot, size=3):
    ld = bpy.data.lights.new(name, kind)
    ld.energy = energy
    if kind == "AREA":
        ld.size = size
    lo = bpy.data.objects.new(name, ld)
    sc.collection.objects.link(lo)
    lo.location = loc
    lo.rotation_euler = [math.radians(a) for a in rot]
    return lo


light("Key", "AREA", (4, -7, 7), 2500, (50, 0, 30), 10)
light("Fill", "AREA", (-6, -6, 4), 900, (60, 0, -40), 10)
light("Rim", "AREA", (0, 14, 7), 1500, (-50, 0, 0), 12)

cd = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cd)
sc.collection.objects.link(cam)
sc.camera = cam

os.makedirs(os.path.join(D, "renders"), exist_ok=True)

# Lineup: all 15 on one character sheet
cd.type = "ORTHO"
cd.ortho_scale = 14.5
cam.location = (0, -20, -2.5)
cam.rotation_euler = (math.radians(90), 0, 0)
sc.render.resolution_x, sc.render.resolution_y = 1600, 1500
sc.render.filepath = os.path.join(D, "renders", "lineup.png")
bpy.ops.render.render(write_still=True)

# Portraits: 3/4 view of each kid
cd.type = "PERSP"
cd.lens = 70
sc.render.resolution_x, sc.render.resolution_y = 800, 1000
for rig, spec in zip(rigs, KIDS):
    hidden = [r for r in rigs if r is not rig]
    for r in hidden:
        for c in [r] + list(r.children):
            c.hide_render = True
    o = rig.location
    cam.location = o + Vector((3.2, -8.2, 2.6))
    direction = (o + Vector((0, 0, 1.7))) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(D, "renders", f"{spec[0].lower()}_{spec[1].lower().replace(' ', '_')}.png")
    bpy.ops.render.render(write_still=True)
    for r in hidden:
        for c in [r] + list(r.children):
            c.hide_render = False

# FBX per kid, centred at the origin
os.makedirs(os.path.join(D, "fbx"), exist_ok=True)
for rig, spec in zip(rigs, KIDS):
    home = rig.location.copy()
    rig.location = (0, 0, 0)
    bpy.context.view_layer.update()
    for s in bpy.context.selected_objects:
        s.select_set(False)
    rig.select_set(True)
    for c in rig.children:
        c.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(D, "fbx", f"{spec[0]}_{spec[1].replace(' ', '')}.fbx"),
        use_selection=True, object_types={"ARMATURE", "MESH"}, add_leaf_bones=False,
        bake_anim=False, apply_scale_options="FBX_SCALE_ALL")
    rig.location = home
bpy.context.view_layer.update()

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(D, "guests.blend"), compress=True)

# Bed preview: one kid tucked in, lying on its back (not saved to the .blend)
rig = rigs[1]
for r in rigs[:1] + rigs[2:]:
    for c in [r] + list(r.children):
        c.hide_render = True
bed_origin = Vector((0, -12, 0))


def box(name, loc, size, color):
    bpy.ops.mesh.primitive_cube_add(location=bed_origin + Vector(loc))
    b = bpy.context.active_object
    b.name = name
    b.scale = size
    bev = b.modifiers.new("Bevel", "BEVEL")
    bev.width = 0.08
    bev.segments = 4
    b.data.materials.append(mat(name, color))
    bpy.ops.object.shade_smooth()
    return b


box("Bed frame", (0, 0, 0.35), (1.2, 2.1, 0.35), "#B07A52")
box("Mattress", (0, 0, 0.85), (1.1, 2.0, 0.18), "#F7F3EA")
box("Headboard", (0, 2.1, 1.3), (1.25, 0.12, 1.0), "#B07A52")
box("Pillow", (0, 1.3, 1.2), (0.85, 0.45, 0.18), "#FFFFFF")
box("Blanket", (0, -0.85, 1.58), (1.16, 1.15, 0.47), "#7FA8E8")
rig.location = bed_origin + Vector((0, -1.2, 1.58))
rig.rotation_euler = (math.radians(-90), 0, 0)
cam.location = bed_origin + Vector((2.6, -5.0, 6.0))
direction = (bed_origin + Vector((0, 0.4, 1.4))) - cam.location
cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
cd.lens = 45
sc.render.resolution_x, sc.render.resolution_y = 1280, 900
sc.render.filepath = os.path.join(D, "renders", "in_bed.png")
bpy.ops.render.render(write_still=True)
print("DONE")

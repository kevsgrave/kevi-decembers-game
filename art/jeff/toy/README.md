# Jeff (Toy style)

The style picked from `../styles/` (option 1, Toy). Glossy chibi to match the guest kids.

- `jeff_toy_sheet.jpg`: front, face close-up, back, and a posed rig test.
- `jeff_toy.blend`: model plus an R15-named armature (`Jeff_Rig`). Each body part is one mesh
  (`Jeff_Head`, `Jeff_LeftUpperArm`, ...) parented rigidly to its bone, like the guest kids.
- `Jeff_Toy.fbx`: armature + meshes, for Roblox Studio once approved. Do not import it into Studio
  until the designer has validated the model.
- `make_jeff_toy.py`: rebuilds everything. Headless: `blender -b --python make_jeff_toy.py -- <out_dir>`.

# Jeff art style options

Four kid-friendly Jeff models in different styles, for picking the look of the monster line.

| # | Style | Notes |
|---|-------|-------|
| 1 | Toy | Glossy vinyl chibi, same proportions as the guest kids |
| 2 | Blocky | Classic Roblox R15 body, flat face decals |
| 3 | Cartoon | Toon (cel) shading with ink outlines, lanky proportions |
| 4 | Plush | Felt doll with embroidered eyes, button pupils and a stitched grin |

- `jeff_styles_compare.jpg`: front 3/4 views side by side. `jeff_styles_backs.jpg`: back views.
- `jeff_styles.blend`: all four models (one collection each). `fbx/`: one FBX per style.
- `jeff_styles.py`: builds everything. In Blender's Python console:
  `g = {"OUT_DIR": r"<this folder>", "HQ": True}; exec(open(r"<this folder>\jeff_styles.py").read(), g)`
  Or headless: `blender -b --python jeff_styles.py -- <out_dir>`.

Part names follow R15 segments (`Toy_Head_hair`, `Blocky_LeftUpperArm`, ...) so the picked style can be rigged next.
The Cartoon style's cel shading and outlines are EEVEE-only; Roblox will need its own outline approach.

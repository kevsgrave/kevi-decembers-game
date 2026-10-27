# Kevi & Decembers Roblox game

## Claude Code plugins

`.claude/settings.json` makes Claude Code offer the game's plugins on any PC that opens this repo.

- Ponytail and claude-obsidian install automatically after you trust the folder.
- claude-skills is registered as a marketplace, but no bundles are on yet. Add the ones you want to `enabledPlugins`, for example `"product-skills@claude-code-skills": true`.

## Graphify (once per PC)

Graphify is a separate program, so each PC installs it once:

```bash
uv tool install graphifyy
graphify install --project
```

Then run `/graphify .` in Claude Code.

## Obsidian notes

Keep the claude-obsidian vault inside this repo (for example a `wiki/` folder) so your notes travel with it.

## Jumpscare RNG (v1)

The place file is `JumpscareRNG.rbxl` (save it from Studio with File > Save to File As). The scripts are also kept as source here:

- `src/ServerScriptService/GameServer.server.luau`: plot claiming, Fear, egg hatch into the inventory, placing monsters, timed scares, bedroom tier reroll, rebirth.
- `src/StarterPlayerScripts/HUD.client.luau`: Fear counter, rebirth button, popups.
- `src/StarterPlayerScripts/MonsterAnimator.client.luau`: plays Jeff's scare when the server signals one.
- `tools/build_plot.luau`: rebuilds the map from the Studio command bar (empty plot in Workspace, claimed contents in `ServerStorage.PlotTemplate`).
- `src/ReplicatedStorage/JeffRig.luau` + `JeffAnim.luau`: Jeff built from `art/monsters/jeff/jeff.blend`, with his scare played on each client. Regenerate `JeffAnim.luau` with:

```bash
blender -b art/monsters/jeff/jeff.blend --python tools/export_jeff.py -- src/ReplicatedStorage/JeffAnim.luau
```

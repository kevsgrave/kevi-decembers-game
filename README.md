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

The place file is `JumpscareRNG.rbxl`. The scripts are kept as source here, laid out the way the LihFolk vault's worked builds do:

- `src/ReplicatedStorage/Shared/Config.luau`: odds, payouts, prices and rebirth math. The server rolls from it and the client only displays it. It checks itself at startup (odds total 100%).
- `src/ReplicatedStorage/Shared/Net.luau`: creates every remote in one place (from the vault).
- `src/ReplicatedStorage/Shared/JeffRig.luau` + `JeffAnim.luau`: Jeff built from `art/monsters/jeff/jeff.blend`, his scare played on each client.
- `src/ServerScriptService/Server/Main.server.luau`: the only server Script.
- `src/ServerScriptService/Server/GameService.luau`: plot claiming, hatching into the saved inventory, placing monsters, scares, bedroom tier rerolls, rebirth.
- `src/ServerScriptService/Server/PlayerData.luau`, `DataTemplate.luau`, `RateLimiter.luau`: session-locked saving and rate limits (from the vault's "Saved Inventory End to End").
- `src/StarterPlayerScripts/HUD.client.luau`: Fear counter, rebirth button with a confirm step, popups.
- `src/StarterPlayerScripts/MonsterAnimator.client.luau`: plays Jeff's scare when the server signals one.
- `tools/build_plot.luau`: rebuilds the map from the Studio command bar (empty plot in Workspace, claimed contents in `ServerStorage.PlotTemplate`).

Saving in Studio needs Game Settings > Security > Enable Studio Access to API Services. Without it, Studio sessions play unsaved and say so. Studio saves use separate `STUDIO_` keys, so tests never touch live data.

Regenerate `JeffAnim.luau` after changing Jeff in Blender:

```bash
blender -b art/monsters/jeff/jeff.blend --python tools/export_jeff.py -- src/ReplicatedStorage/Shared/JeffAnim.luau
```

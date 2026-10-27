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

## Obsidian vault

The game's notes live in `vault/`, a claude-obsidian vault that travels with the repo.

- Open it in Obsidian with **Open folder as vault** and pick the `vault` folder inside your repo clone.
- Start at `wiki/overview.md`. Every design topic, monster and open question has its own page.
- New monster: create a note in `wiki/entities/monsters/` and insert the **Monster** template.
- Drop new source material (monster lists, screenshots) in `vault/inbox/` and ask Claude to ingest it.
- Pull before you edit and push after, so both PCs stay in sync.

# SCARE THEM: UI and map rebuild

Rebuilt from the owner's references in `docs/references/style/`. Built and checked in Studio's edit mode only, so **nobody has played it yet**.

## Screenshots

| Shot | What it shows |
|---|---|
| `ui-shop-and-hud.jpg` | **A preview built with the real style code and sample data.** The HUD and shop only build for a real player, so they can't be shown live in edit mode |
| `ui-hud-on-plot.jpg` | The same kind of preview over a plot that was temporarily dressed. The dressing has been removed |
| `map-overview.jpg`, `map-hub.jpg`, `map-graveyard.jpg`, `map-mansion.jpg` | The real map |

## What changed

- **Screens:** HUD, shop, index and inventory, eggs, forge, rebirth, settings, tutorial and tracker guides all use `Style.luau` and `Panels.luau`.
- **Map:** the whole map is rebuilt from parts, with no meshes in Workspace: checkered grass, teal water, chunky trees, the ring of 8 plots, the hub stations, 20 dig spots and 4 islands (Graveyard, Mansion, Dark Woods, Ruins).
- **Theme:** pumpkins, jack-o-lanterns, the witch hut, scarecrow, cauldron and Halloween night are gone. It's now mist, twisty trees, gravestones, ghosts, lanterns and a daytime sky.
- **Rule change:** hatching, shop buying and fusing no longer check the player's distance, because the panels open from the HUD. See `docs/spec/OVERRIDES.md`.

## Checks

- All 8 test modules pass: Config 64 lines, Content 43, Progress 47, Shop 44, Tutorial 44, Scare 44, Inventory 50, Plot 111.
- `GameService` loads and all 11 client scripts compile.
- Roblox's pathfinder finds a route from spawn to all 8 plots, the 4 stations and the 20 dig spots. That is a calculation, not an avatar walking there.
- The same check found trees standing on two dig spots. The builder now removes them, and `PlotTests` covers it.

## Not done

- Furniture, kids and Jeff are still their existing meshes, so they don't fully match the new style.
- The Mansion island is sparse and the Mansion is a simple open building. Better buildings belong to the Town and Buildings phase.
- `MapKit` is unused but still in `ServerStorage`.
- From very high up, the sea still fades to a grey band at the horizon.

## Play-test checklist (Play, F5)

- [ ] The first egg can be hatched from the Eggs button, and the tutorial pill and arrows point at the right things.
- [ ] Shop, Index, Inventory, Rebirth, Settings, Eggs and Forge each open, close and work.
- [ ] Prompts at the shop stall, forge, rebirth hall and book all work.
- [ ] You can walk to your plot and over the bridges to all 4 islands, and a tracker's dig spot can be dug.
- [ ] Scares still pay Fear, and text is readable at phone size (use the device emulator).

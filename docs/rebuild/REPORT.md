# SCARE THEM: UI and map rebuild

Rebuilt from the owner's references in `docs/references/style/`. Built and checked in Studio's edit mode only, so **nobody has played it yet**.

## Polish pass (second round)

Built from the owner's fuse machine reference, `docs/references/style/fuse-machine.png`. Screenshots are in `polish/`. The status lines in them are sample text; the live values only appear in Play. Moving parts only move in Play too, so the screenshots show them still.

- **Stations:** the Fuse Machine, Shop, Egg Hatchery, Rebirth Portal, Book of Frights and a new Dig Camp are detailed machines and stalls, each with a floating gradient title and a live status line. Plot gates got glowing strips and lanterns.
- **Ghosts:** 11 original designs built from parts, with expressions, plus outfits for the station keepers. They bob, sway and blink; those over the plaza, the plot gates and the islands also wander with soft trails. The stone ones don't move.
- **Map:** a proper mansion, a bigger graveyard, a cabin and campfire in the Dark Woods, a colonnade, crystal and aqueduct in the Ruins, better bridges and edged paths, more plants and props, 4 islets, a lighthouse and a boat.
- **Horizon:** softened, and only a thin line from the ground. From high up a grey band still shows past the edge of the water.
- **Size:** about 16,000 instances and 6,200 parts in Workspace, up from about 9,000 instances. Streaming is on, but this hasn't been tested on a phone.

Fusing's first recipe needs 4 monsters, so the Fuse Machine shows `0/4`, not the `0/3` in the reference.

## Screenshots of the first round

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
- [ ] Ghosts bob and blink, the fan, dish and egg ring turn, and glows pulse. The frame rate stays smooth.
- [ ] Status lines show real values: shop countdown, fuse count, rebirth cost, index count, and the tracker distance at the Dig Camp.
- [ ] The Dig Camp prompt opens the shop.
- [ ] Scares still pay Fear, and text is readable at phone size (use the device emulator).

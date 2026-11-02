# Phase 2 report: world, plots and rooms (2026-11-01, updated 2026-11-02)

Built in SCARE THEM in Edit mode. **Not play-tested:** auto-assign, leaving and visiting have only been tested as logic and by reading the code, and only you can run Play.

## Owner decision: plots are auto-assigned (WaddleWorks, 2026-11-02)

The master prompt and Phase 2 prompt ask for a claim station. The owner tried that idea and chose auto-assign instead, so **this decision overrides them**. Don't add claim stations back.

- When a player's save loads, the server gives them the first free plot and teleports them to it. They also respawn there.
- If all 8 plots are taken, they visit with a message and get the next plot that frees up.
- The "claim plot" step in the master prompt's tutorial (Section 12, step 1, and Phase 5's "claim plot" step) is no longer needed. The tutorial starts at the crawl-hole scare.
- The acceptance check "can claim one plot only" now means each player is given exactly one plot.

## What changed

| Area | Change |
|---|---|
| Ownership | `PlotClaims` tracks who owns which plot, with no yields, so two players can't get one plot |
| Leaving | Your plot empties, the sign goes back to "Free plot", and the next waiting visitor gets it |
| Visitors | Anyone can walk around any plot. Using another player's case or crawl hole does nothing except show a message |
| Lock signs | Locked bays now say how many rebirths they still need |
| Rebirth station | New in the hub, parts plus the existing stone pillars. The prompt opens the same confirm dialog as the HUD button |
| Fusing station | Sign at the existing cauldron: "Fusing - opening soon". Fusing itself is Phase 7 |
| Ghosts | 13 floating ghosts made of parts, over the plaza and at each gate |
| Floors | `PlotLayout` and `Balance` now define floors, bedroom numbers and heights. Floor 2 is not built until Phase 7 |

No new meshes or generated assets went in. I built with Parts and existing `MapKit` models only.

Already there and kept: hidden neutral spawn in the hub, 8 plots, blue studded floors, pink carpet aisles, night sky, pumpkins and graves, egg shrine and odds board, shop stall, 3 rooms per side, 3 unlocked at the start, display left and window right, crawl holes, owner signs.

## Test results

| Test | Result |
|---|---|
| `PlotTests`, 104 checks | All passed |
| `ConfigTests`, 53 checks | All passed |
| Eight owners at once, no two owners, ninth player refused, double ownership refused, race for one plot, release and reassign | Passed, on the ownership logic only, no real players |
| Glass left and window right from the aisle, on all six bays | Passed, measured |
| Pathfinding (radius 2, height 5, no jumping): spawn to all 8 gates, each gate to inside the plot, full length of an aisle, spawn to egg board, shop, fusing and rebirth | All found a route, but with plots empty. Rooms exist only after a plot is assigned, so walking around them is in your manual test |
| Auto-assign and cleanup on leave | Code read only, needs your test below |

## Screenshots

Plot 1 was temporarily dressed as owned for these, then cleared. The rooms show no kids or monsters, because those only appear in Play. `gate-free.jpg` and `hub.jpg` were re-shot after the pads were removed. Green pads and "claim here" labels visible in the background of `rebirth.jpg`, `fusing.jpg`, `shop.jpg` and `egg-area.jpg` are gone from the game.

| File | Shows |
|---|---|
| `hub.jpg` | Whole hub and nearby plots |
| `egg-area.jpg` | Egg shrine, odds board |
| `shop.jpg`, `fusing.jpg`, `rebirth.jpg` | The three stations |
| `gate-free.jpg` | Unowned plot |
| `gate-owned.jpg` | Owned plot with owner sign |
| `aisle.jpg` | Aisle with bays on both sides |
| `bedroom-front.jpg` | Display left, window right, crawl hole |
| `bedroom-inside.jpg` | Room interior and nightlight |
| `locked-bays.jpg` | Locked bays and their signs |

## Known problems

1. **Rooms aren't really dim.** The nightlight itself is low (0.5), but the map's night ambient light fills the room, so the walls read as bright pink and purple (`bedroom-inside.jpg`). A fix would darken room walls or lower the ambient light, which changes the look of the rooms or the whole map, so it's your call.
2. **Server size is not 8.** `Players.MaxPlayers` reads 60 and scripts can't change it. Set it in Creator Hub under the place's settings. A ninth player could join and only visit until then.
3. **Players can't physically walk through the crawl hole.** It is 3.5 wide and 3 high. The scare fires from the prompt outside. Phase 4 needs to decide how entering works.
4. **Visitors still see prompts** on other players' cases. They do nothing except show the message. Hiding them needs client code, not added here.
5. **The rebirth HUD button works from anywhere.** The station is an extra way in, not the only one. Rebirth rules are Phase 7.
6. **The rebirth dialog still says Fear goes back to 0**, and it does. Keeping leftover Fear, the default you left in place, arrives in Phase 7.
7. **Phone and tablet HUD sizing** is still fixed pixels, Phase 8.

## Manual test

Save the place first. Stop Play between tests.

**One player**

1. Press Play. Within a moment you should arrive on a plot with your name on its sign. Output should show `[Config] Balance is valid: 42 confirmed, 110 provisional`, with no red errors.
2. Bays 1 to 3 are open; 4 to 6 are boarded with signs saying 1, 2 and 3 more rebirths.
3. Reset your character. You should come back on your plot.
4. Do a crawl-hole scare, walk around the rooms, hatch an egg at the hub, place the monster, wait for a scare, and pick it back up.
5. Use the Rebirth Station prompt, then Cancel on the dialog. Check that it opens.

**Two or more players** (Test tab, Local Server, 2 or more players)

6. Each player should get a different plot, with the right name on each sign.
7. Player 2 walks into player 1's plot and tries their case and a crawl hole. They should see the "isn't your plot" message, and nothing should change for player 1.
8. Close player 1. Their plot should empty and the sign should read "Free plot".

**Checks from the command bar**

```
print(require(game.ServerStorage.PlotTests)())
```

The last line should say `ALL PASSED`. Run it outside Play, because it expects empty plots.

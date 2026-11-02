# Phase 2 report: world, plots and rooms (2026-11-01)

Built in SCARE THEM in Edit mode. **Not play-tested:** claiming, leaving and visiting have only been tested as logic and by reading the code, and only you can run Play.

## What changed

| Area | Change |
|---|---|
| Claiming | Plots are no longer auto-assigned. Each plot has a green pad at its gate with a `Claim Plot` prompt, which works with E or touch. The server checks that the save has loaded, the rate limit, your distance and that the plot is free |
| Leaving | Your plot empties, the sign goes back to "Free plot", and the pad returns for the next player |
| Visitors | Anyone can walk around any plot. Using another player's case or crawl hole does nothing except show a message |
| Lock signs | Locked bays now say how many rebirths they still need |
| Rebirth station | New in the hub, parts plus the existing stone pillars. The prompt opens the same confirm dialog as the HUD button |
| Fusing station | Sign at the existing cauldron: "Fusing - opening soon". Fusing itself is Phase 7 |
| Ghosts | 13 floating ghosts made of parts, over the plaza and at each gate |
| Floors | `PlotLayout` and `Balance` now define floors, bedroom numbers and heights. Floor 2 is not built until Phase 7 |

No new meshes or generated assets went in. I built with Parts and existing `MapKit` models only.

Already there and kept: hidden neutral lobby spawn, 8 plots, blue studded floors, pink carpet aisles, night sky, pumpkins and graves, egg shrine and odds board, shop stall, 3 rooms per side, 3 unlocked at the start, display left and window right, crawl holes, owner signs.

## Test results

| Test | Result |
|---|---|
| `PlotTests`, 112 checks | All passed |
| `ConfigTests`, 53 checks | All passed |
| Eight claims at once, no two owners, ninth player refused, double claim refused, race for one plot, release and reclaim | Passed, on the claim logic only, no real players |
| Glass left and window right from the aisle, on all six bays | Passed, measured |
| Pathfinding (radius 2, height 5, no jumping): spawn to all 8 pads, each pad through the gate, full length of an aisle, spawn to egg board, shop, fusing and rebirth | All found a route, but with plots empty. Rooms exist only after claiming, so walking around them is in your manual test |
| Cleanup on leave | Code read only, needs your test below |

Two bugs turned up in the screenshots and are fixed: the claim pads were buried in the carpet, and floating ghosts blocked the shop sign and odds board.

## Screenshots

Plot 1 was temporarily dressed as claimed for these, then cleared. The rooms show no kids or monsters, because those only appear in Play.

| File | Shows |
|---|---|
| `hub.jpg` | Whole hub and nearby plots |
| `egg-area.jpg` | Egg shrine, odds board |
| `shop.jpg`, `fusing.jpg`, `rebirth.jpg` | The three stations |
| `gate-free.jpg` | Unclaimed plot with claim pad |
| `gate-owned.jpg` | Claimed plot with owner sign |
| `aisle.jpg` | Aisle with bays on both sides |
| `bedroom-front.jpg` | Display left, window right, crawl hole |
| `bedroom-inside.jpg` | Room interior and nightlight |
| `locked-bays.jpg` | Locked bays and their signs |

## Known problems

1. **Rooms aren't really dim.** The nightlight itself is low (0.5), but the map's night ambient light fills the room, so the walls read as bright pink and purple (`bedroom-inside.jpg`). A fix would darken room walls or lower the ambient light, which changes the look of the rooms or the whole map, so it's your call.
2. **Server size is not 8.** `Players.MaxPlayers` reads 60 and scripts can't change it. Set it in Creator Hub under the place's settings. A ninth player could join and only visit until then.
3. **Players can't physically walk through the crawl hole.** It is 3.5 wide and 3 high. The scare fires from the prompt outside. Phase 4 needs to decide how entering works.
4. **Visitors still see prompts** on other players' cases. They do nothing except show the message. Hiding them needs client code, not added here.
5. **No voluntary release.** A plot is released only when its owner leaves. Not requested for this phase, so I left it out.
6. **The rebirth HUD button works from anywhere.** The station is an extra way in, not the only one. Rebirth rules are Phase 7.
7. **The rebirth dialog still says Fear goes back to 0**, and it does. Keeping leftover Fear, the default you left in place, arrives in Phase 7.
8. **Phone and tablet HUD sizing** is still fixed pixels, Phase 8.

## Manual test

Save the place first. Stop Play between tests.

**One player**

1. Press Play. You should start in the hub with no plot, and Output should show `[Config] Balance is valid: 42 confirmed, 112 provisional`, with no red errors.
2. Walk to a plot's gate. The pad should glow and read "Free plot: claim here". Use the prompt.
3. Your name should appear on the sign, rooms should appear, and the pad should disappear. Bays 1 to 3 are open; 4 to 6 are boarded with signs saying 1, 2 and 3 more rebirths.
4. Try another plot's pad. You should see "You already have a plot".
5. Do a crawl-hole scare, hatch an egg at the hub, place the monster, wait for a scare, and pick it back up.
6. Use the Rebirth Station prompt, then Cancel on the dialog. Check that it opens.

**Two or more players** (Test tab, Local Server, 2 or more players)

7. Both players start in the hub with no plot.
8. Player 1 claims a plot. Player 2 uses that plot's pad if it is still visible, or at least sees that it's gone.
9. Player 2 claims a different plot. Both signs should be correct.
10. Player 2 walks into player 1's plot and tries their case and a crawl hole. They should see the "isn't your plot" message, and nothing should change for player 1.
11. Both try the same free plot at the same moment if you can. Only one should win, and the other sees "Someone just claimed this plot".
12. Close player 1. Their plot should empty, the sign should read "Free plot", and the pad should return. Player 2 can't take it while they own a plot.

**Checks from the command bar**

```
print(require(game.ServerStorage.PlotTests)())
```

The last line should say `ALL PASSED`. If it fails on an empty plot, you may have run it during Play, or left a plot dressed.

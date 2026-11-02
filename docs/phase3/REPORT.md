# Phase 3 report: spec adoption, saves, inventory, hotbar, placement (2026-11-02)

Built in SCARE THEM in Edit mode. **Not play-tested:** the rules below are tested on throwaway save tables, and the panel, hotbar and real saving need you to press Play.

## Spec change

The ULTIMATE package in `docs/spec/` is now the build spec. `docs/spec/OVERRIDES.md` lists your decisions that override it: auto-assign, the ring map, GOD 0.001%, keeping leftover Fear, Jeff as a stand-in.

## Numbers that changed (all still provisional)

| Value | Was | Now |
|---|---|---|
| Starting Fear | 250 | 500 (exactly one Starter Egg, until the tutorial voucher exists) |
| Live egg | Spooky Egg, 250, all six rarities | Starter Egg, 500: Common 78, Rare 21, Epic 1 |
| First rebirth | 5,000 | 50,000, then x3 each time |
| Rebirth multiplier | +0.5 | +0.25 |
| Manual scare cooldown | 3s | 8s |
| Inventory | 50 | 250 |
| Secret payout | 15,000-30,000 | 20,000-35,000 |

Defined but not live yet: 6 more eggs, mutation and size numbers, 14 accessories, shop prices and per-player stock. **The game now plays slower**, because earning and rebirth costs changed. That's the package's tuning and needs your playtest.

The 42 species are in `Balance.monsters` as data, each checked to pay inside its rarity band. Hatches stay Jeff until original models exist.

## What changed in the game

| Area | Change |
|---|---|
| Fixed payouts | **A monster now pays its own fixed amount on every scare**, set when hatched, instead of rerolling. The case shows the real number |
| Inventory | Rules are in a new `Inventory` module on the saved data: one monster per room, no locked rooms, no monster in two rooms |
| Inventory panel | New button and I key: every monster with rarity word, Fear per scare, where it is, Hold and favorite buttons, and sorting by income, rarity, name or newest |
| Hotbar | Now a separate, saved view of up to 9 monsters. Hold in the panel to bring any monster to it. It no longer makes a Tool per monster, which would have been up to 250 |
| Placing | **You must now hold the monster you want to place.** Before, the game picked one for you. A message explains if you hold nothing |
| Case label | Name, rarity word, Fear per scare and seconds per scare |
| Save schema v3 | Adds the saved hotbar and favorites. v1 and v2 saves migrate with progress kept |
| Damaged saves | A damaged monster row now refuses the save rather than losing the monster. A monster somehow placed twice is repaired to one room |

Already there and kept: session locking, retries, Studio-only `STUDIO_` saves, refusing newer or corrupt saves, and saving on leave and shutdown.

The save also has fields for lifetime Fear, species index, tutorial, accessories, cases, trackers, settings and receipts. Later phases fill most of them.

## Test results

| Test | Result |
|---|---|
| `InventoryTests`, 46 checks | All passed |
| `ConfigTests`, 63 checks | All passed, now with 24 broken tables |
| `PlotTests`, 104 checks | All passed |
| Locked room, occupied case, wrong owner, double placement, moving monsters, two requests at once | Passed, on the rules only |
| Rejoin, through JSON like a real save | Passed, keeps everything including tutorial, accessories, cases, trackers and settings |
| v1 and v2 migrations, newer and NaN saves refused | Passed |
| Server modules load, panel and HUD compile | Passed |
| Real data store, real disconnects, the panel on screen | **Not tested, needs Play** |

I tested in Edit mode, as your rules require, so the panel hasn't been seen on screen. Its layout may need a tweak.

## Known limits

1. **Rebirth still wipes Fear**, and the dialog says so. Keeping leftovers comes with the rebirth phase. With a 50,000 cost, you'll feel this more now.
2. **The case's Fear per scare** counts bedroom tier and rebirth only. Size, mutation and accessories join it in Phase 4.
3. **Automatic and manual scares** otherwise work as before. Phase 4 covers the scheduler, reactions and the timing mini-game.
4. **If saving fails mid-session** the game retries and warns in Output. It doesn't yet lock spending or warn the player, as the package asks.
5. **Inventory filters and compare** from the package are not built, only sorting. Favorites save and show, but protect nothing until fusion exists.
6. **Rooms still read bright**, the crawl hole is still too small to walk through, and server size still needs setting to 8. All from Phase 2.

## Manual test

Save the place first. Turn on Game Settings > Security > Enable Studio Access to API Services, or nothing saves. Stop Play between tests.

**Inventory and placing**

1. Press Play. Output should show `[Config] Balance is valid: 42 confirmed, 167 provisional`, with no red errors. You should have 500 Fear.
2. The hub egg should read "Starter Egg - 500 Fear", with odds of Common 78, Rare 21, Epic 1.
3. Hatch it. A monster should appear on your hotbar.
4. Without holding anything, press E at a case. You should see "Hold a monster first".
5. Select it on the hotbar and press E at a case. It leaves the hotbar and the case shows name, rarity word, Fear per scare and seconds.
6. Watch two scares. The payout should be the same base each time, multiplied by that room's tier.
7. Press E again to pick it up. Move it to another room. Earnings should stop while it's in your hand.
8. Press I or the Inventory button. Check the panel fits your screen, the sort button changes order, the star saves a favorite, and Hold puts a monster in your hand.
9. Try the panel in Studio's device emulator at a phone size.

**Saving**

10. With some monsters placed, stop Play and press Play again. Fear, monsters, placements and favorites should all be back, with the same payouts.
11. If you had a save from before, check it loaded with everything kept.

**Two players** (Test tab, Local Server, 2 players)

12. Player 2 tries player 1's case and crawl hole. They should see the "isn't your plot" message.
13. Close player 1 and rejoin. Their monsters should come back on whichever plot they get.

**Checks from the command bar**

```
print(require(game.ServerStorage.InventoryTests)())
```

The last line should say `ALL PASSED`.

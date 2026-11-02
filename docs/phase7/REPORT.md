# Phase 7 report: fusion, mutations, rebirth, floors (2026-11-02)

Built in SCARE THEM in Edit mode. **Not play-tested:** the rules are tested on throwaway saves, and the two floors were checked in screenshots, but none of it has been played.

**Test with plain Play in Studio (F5).** Only that uses the separate `STUDIO_` test saves.

## What changed

| Area | Change |
|---|---|
| Fusing | The cauldron's prompt opens a panel showing what can fuse. It lists exactly which monsters would be used and what comes out, with a Fuse then Confirm step |
| Fusion rules | 4 Normal make 1 Large, 3 Large make 1 Mega, 3 Mega make 1 MASSIVE. Same species, rarity, size and mutation required. Placed and favorited monsters are never used |
| All or nothing | Every ingredient is checked before anything changes. A refused fusion leaves the save exactly as it was |
| The new monster | A new id, the best base payout among those used, a size multiplier, and a slightly bigger model: x1.07, x1.13, x1.2 |
| Mutations | Fear eggs roll one on hatching: Golden 2%, Haunted 0.9%, Creepy 0.35%, Cursed 0.13%, UnHoly 0.02%. Chances show with each egg's odds and live in `Balance`. The tutorial and tracker eggs don't mutate |
| Mutation look | A coloured glow and sparks on the monster, and the mutation's name on the case and reveal. They pay their multiplier: x1.2 to x2.5 |
| Index badges | The Index records your best size and every mutation you've had |
| Rebirth | **You now keep your leftover Fear**, as you decided. Cost 50,000, then x3 each time. +0.25 multiplier, one more room, a 3-second cooldown, and a confirm dialog showing the cost, what you keep and the new room |
| Floors | **Floor 2 appears at the sixth room, floor 3 at the twelfth, up to 18 rooms.** Each floor is a blue deck, pink aisle, low wall, corner pillars and six more rooms. Screenshots: `floors-outside.jpg`, `floor2-aisle.jpg` |
| Getting upstairs | Purple lift pads rather than stairs: at the far end of each aisle to go up, and at the near end of the floor above to come down. Visitors can use them too |

No new meshes or assets. Decks, pads and glows are parts and Roblox's built-in particle. Rooms reuse your existing furniture.

## Decisions I made

1. **Lift pads instead of stairs.** A floor is 32 studs up, and stairs that long would fill the aisle. The package mentions stairs, so tell me if you'd rather have them.
2. **Three floors, 18 rooms** is the cap (`floorCap`), so 15 rebirths. It's one number to raise.
3. **Fusing needs the same rarity as well as species.** All hatches are Jeff for now, so otherwise a Common could fuse with a SPOOKY.
4. **The new monster keeps the best payout** among those used, and the panel uses your strongest first, so fusing never lowers a payout.

## Test results

| Test | Result |
|---|---|
| `ProgressTests`, 47 checks | All passed |
| `ShopTests` 44, `TutorialTests` 44, `ScareTests` 44, `InventoryTests` 50, `PlotTests` 107, `ConfigTests` 63 | All passed |
| All three recipes | Passed, with new ids and ingredients gone once |
| Refused fusions: wrong count, duplicates, not owned, different rarity, mutation or size, favorite, placed, already MASSIVE | Each leaves the save identical |
| Repeating a fusion request | Does nothing |
| Rebirth costs and rooms | Match the package's schedule to 328,050,000 and room 12 |
| Rebirth spending | Keeps the rest and all monsters |
| Rebirth refusals | 20 requests in 2 seconds give at most one. Not enough Fear charges nothing |
| Rebirth cap | Stops after 15 |
| 1,000,000 mutation rolls | Golden 2.001, Haunted 0.911, Creepy 0.342, Cursed 0.131, UnHoly 0.021 |
| Income math | Every factor multiplies once |
| Rejoin | Size, mutation, rebirth and index badges all kept |
| Floor 2 rooms, in a temporary preview | Correct height, furnished, and a walkable aisle by pathfinding |
| Lifts, a real floor 2 scare, fusing panel, glow on screen | **Not tested, needs Play** |

## Known limits

1. **Jeff's walk on upper floors** hasn't been seen. The route is worked out from each room's own walls, so it should follow, but this is the first thing to check.
2. **Performance with many floors** hasn't been measured. Each floor adds six furnished rooms per player, and 8 players with 3 floors each is a lot. This is Phase 8's test.
3. **The size difference is subtle on purpose**, as your notes ask. MASSIVE is 20% bigger.
4. **Mutations come only from eggs.** The package's Moon Fragment crafting isn't built, because it's an extra rather than part of your notes.
5. **Rebirth has no distance check.** The HUD button works from anywhere, as well as the station.
6. **Older monsters stay Normal with no mutation.** Only new hatches can mutate.
7. **Earlier items:** rooms read bright, and server size and the mesh setting still need you.

## Manual test

Save the place, then use plain Play (F5). Stop Play between tests.

**Test helpers**, Studio only, set in the command bar before pressing Play. `TestGrantFear` sets your Fear on every join.

```
game.ServerStorage:SetAttribute("TestProfileKey", "prog1")
```

```
game.ServerStorage:SetAttribute("TestGrantFear", 5000000)
```

```
game.ServerStorage:SetAttribute("TestForceMutation", "Golden")
```

Clear them afterward: the key to `""`, the others to `nil`. Clear `TestGrantFear` before testing that rebirth's Fear persists.

1. Output should show `[Config] Balance is valid: 42 confirmed, 180 provisional`, with no red errors.

**Rebirth and floors**

2. Note your Fear and press Rebirth. The dialog should show the cost, what you keep and the new room. Confirm: Fear drops by exactly 50,000, monsters stay, and the fourth room opens.
3. Press Rebirth repeatedly: the cooldown should stop it, with one rebirth at a time.
4. Rebirth up to six rooms (costs 50k, 150k, 450k). **Floor 2 should appear above your plot** with its pillars.
5. At the far end of your aisle, use the purple pad to go up. Check the deck, locked rooms and signs, then come back down.
6. Rebirth once more: room 7 opens upstairs. Place a monster there and **watch through its window: Jeff should walk in, pop and pay.** This is the most important new check.
7. Do a manual scare upstairs. You should come back out onto the upper deck, not fall.
8. Stop and Play again: floors, rooms and the monster upstairs should all come back.
9. Visit in a Local Server: a second player should be able to use your lift, but not your cases.

**Fusion**

10. Buy Starter Eggs until you have 4 Commons. Open the cauldron: it should show the 4, what's used and the result.
11. Press Fuse, then Confirm. You should get 1 Large with the best payout and a bigger model, and the 4 gone.
12. Favorite one of 4 matching monsters, or place one: the panel should count only the free ones.
13. Press Confirm repeatedly as fast as you can: one fusion only.
14. Check the payout: the case should show `x1.5 Large`, and Fear should match.

**Mutations** (with the helper on)

15. Hatch a Fear egg: the reveal shows Golden, and the case shows the glow, sparks and `x1.2`.
16. The Promise Egg should stay unmutated even with the helper on.
17. Try a fusion mixing Golden and plain: they should appear as separate groups.
18. Check the Index tab for Jeff's badges.

**Income math.** Place a Golden Large Rare at 2 rebirths in a Gold room, for example. The case line should list each factor and the total, and each scare should pay exactly that.

**Rollback.** Stop Play mid-way through any of these, then Play again. You should never lose ingredients without getting the result, or pay for a rebirth without getting it.

**Phone sizes.** Check the fusing panel, rebirth dialog and egg rows fit and can be tapped.

**Checks from the command bar**

```
print(require(game.ServerStorage.ProgressTests)())
```

The last line should say `ALL PASSED`.

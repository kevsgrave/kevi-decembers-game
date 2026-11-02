# Phase 8 report and final acceptance check (2026-11-02)

Built in SCARE THEM in Edit mode. **Nobody has play-tested any of Phases 3 to 8 yet, and the game is not ready to publish.** The blockers are at the end of the acceptance table.

**Test with plain Play in Studio (F5).** Only that uses the separate `STUDIO_` test saves. Real servers, including a Team Test, use real saves.

## What changed

| Area | Change |
|---|---|
| Roster | All 42 original species are ready to hatch, each with a name, concept, fixed payout and scare direction. **It's switched off** (`content.hatchRoster`), so hatches stay Jeff until you decide |
| Placeholders | Until a species has a model, it appears as a labelled shape made of parts, with its own colour and shape, gliding the same route and growing for a moment to scare |
| Replacing a placeholder | Put a model named after the species id in `ServerStorage.MonsterModels`. It takes over with no code change, though it only gets the placeholder's glide until it has real animation |
| Reduced scares | A new Settings button. On: no lunge, and the kid sits up with a "?" instead of hopping and shaking. Rooms follow their owner's setting. Saved |
| Volume | Music and effects settings, saved. **They have nothing to control yet**, because no sounds are in the game |
| Audio | Hooks for scare, soft scare, payout, hatch, purchase and music. The list is empty until you approve sounds |
| Phones and tablets | Fixed-size pieces shrink to 60% on small screens. The left-hand buttons space out by screen height. On touch screens, Fear moves to the top right, clear of the thumbstick and jump button, and the tutorial caption moves under it |
| Performance | Scares more than 220 studs from your camera aren't animated |
| Robux | **None. No product IDs exist, so there's no Robux interface and nothing to buy.** Receipt handling is ready and tested, for guaranteed Fear packs only. No paid randomness, game passes or gifting |

## Test results

All 442 automated checks passed: Config 63, Content 43, Progress 47, Shop 44, Tutorial 44, Scare 44, Inventory 50, Plot 107. All 11 client scripts compile and the server scripts load. These run on throwaway data in Edit mode. They can't show how anything looks or feels, or how it behaves with real players and real saves.

I couldn't get a screenshot of the placeholders because Studio's viewport stopped rendering for captures. They're built and pass their checks, but nobody has seen them.

## Acceptance checklist (master prompt, Section 16)

Key: **Logic passes** means automated checks pass, but it hasn't been played. **Not met** means it fails today.

| # | Requirement | Status | Notes |
|---|---|---|---|
| 1 | Fresh player joins an 8-player server, gets one plot | **Not met** | Auto-assign logic passes, by your decision. Server size reads 60, not 8. You need to set it |
| 2 | 3 usable rooms, 6 bays, display left, window right, hidden spawn | Logic passes | Measured on all six bays. Not played |
| 3 | Manual scare through the crawl hole pays the configured Fear | Logic passes | A scripted crawl, as your default allowed. The crawl itself hasn't been seen |
| 4 | Tutorial can't soft-lock, egg is 80/20, goes to inventory | Logic passes | Save and rejoin at every step. Arrows not seen. Real disconnects not tried |
| 5 | Select from inventory, place by E or touch, no duplicates, not others' cases | Logic passes | Not played. Touch not tried |
| 6 | Timed scare, harmless reaction, paid once, room resets and rerolls | Logic passes | Timing and pay-once tested with a fake clock. The visuals, especially on upper floors, haven't been seen |
| 7 | Case shows name, rarity word, Fear per scare, tier validator passes | Logic passes | Uses the 0.001% GOD assumption, as you accepted |
| 8 | Picking up stops earnings, server checks distance and owner | Logic passes, one gap | Rebirth has no distance check, because the HUD button works anywhere |
| 9 | Free Rare box once, equip, correct multiplier | Logic passes | Not played |
| 10 | Shop rotates at 300s, stock can't go negative, purchase survives rejoin, trackers lead to a reward once | Logic passes | Stock is per player, per the package. Shelf rule changed, see Phase 6 report |
| 11 | Fusion 4/3/3, transactional, distinct ids | Logic passes | Not played |
| 12 | Five mutations are working, config-backed categories | Logic passes | Glow not seen |
| 13 | Rebirth confirms, spends correctly, one room, multiplier, floor 2 after room 6 | Logic passes | Floor 2 checked in a preview. Lifts not used |
| 14 | Everything persists across rejoin and concurrent sessions | **Partly unproven** | Save round trips pass, and your real save loaded and migrated once. Concurrent sessions haven't been tried |
| 15 | Studio test profiles never touch live saves, and failed loads block unsaved purchases | **Not fully met** | True for plain Play only. A Team Test or published server uses real saves, which is what happened on your first test. Failed loads kick the player, except Studio's own unsaved mode |
| 16 | UI works on phone, tablet and desktop, and reduced scares works and saves | **Not verified** | Built, but no panel has ever been seen on screen at any size |
| 17 | No copied monsters or unlicensed assets, premium not faked | **Not met** | Jeff is still live, and your notes base him on Jeff the Killer. One texture is by a third party, see `ASSETS.md`. Premium isn't faked, because there isn't any |
| 18 | 8-player stress and reconnect tests have written outcomes | **Not done** | Needs real play. I can't run Play, by your rule |

## Known limitations

**Blocking publish**

1. Nothing has been play-tested.
2. Jeff has to be replaced or renamed and remodelled.
3. Server size has to be 8.

**Performance risk, the biggest unknown**

A Jeff is 99 parts, and each working room has two of them, animated on clients. Worked out from real pieces:

| Server | Instances in Workspace |
|---|---|
| Empty | About 5,900 |
| 8 players, 6 working rooms each | About 22,700 |
| 8 players, 18 working rooms each | About 58,900 |

The last row is a late-game worst case, and could be too heavy for phones. Streaming and the 220-stud cutoff help, but only a real test will tell. Placeholders are only 3 parts, so moving off Jeff helps a lot. If it's too heavy, the fixes are lowering `floorCap` or simplifying rooms.

**Other limits**

- **No sounds at all**, until you approve some.
- **Reduced scares only softens what exists.** A visitor's own setting doesn't change another owner's kid reactions.
- **The dig hold and arrow** are as noted in the Phase 6 report.
- **If saving fails mid-session**, the game retries but doesn't warn the player or block spending.
- **Provisional numbers:** 183 values are unbalanced guesses from the package. Nothing has been tuned against real earnings.
- **Not built, from the package:** quests, events, passes and products, gifting, index milestones, inventory filters, Moon Fragments. The map and building ideas are the next phase.

## Decisions for you

**1. Jeff and the roster.** Your Phase 8 text says not to copy Jeff the Killer, so he can't ship. Two ways forward:

- **Turn the roster on with placeholders now** (my recommendation, once you've looked at them). Everything works and Jeff leaves new hatches. It's plainer until models arrive. Existing Jeffs stay until a decision on old saves.
- **Keep Jeff while testing** and switch later.

To see them, run this before pressing Play. It works only in Studio:

```
game.ServerStorage:SetAttribute("TestRoster", true)
```

**2. A starter set for real models.** The package suggests launching with 12 polished monsters, then growing to 42. I'd start with these, spread across rarities and all easy to read as silhouettes:

| Rarity | Species |
|---|---|
| Common | Sock Goblin, Boo Balloon, Pumpkin Peeker |
| Rare | Lantern Jaw, Shiver Jack, Blanket Mimic |
| Epic | Lullaby Lurker, Mirror Minnow |
| Legendary | Crowned Candle, Nightmare Astronaut |
| Mythic | The Wardrobe King |
| SPOOKY | The Mourning Bell |

I'd show you previews first, as your rule asks, and generating may cost credits.

**3. Four species to look at before modelling.** Their concepts sit close to the characters your notes say not to copy, so I left them out of the starter set. They're my judgment, not a legal check:

| Species | Concept | Too close to |
|---|---|---|
| Grinling Hound | Hound with a crooked smile | Smile Dog |
| Plush Prowler | Plush beast with springy hands | Huggy Wuggy |
| Fuzzy Fury | Huge puffy horned monster | Sulley |
| Dream Snatcher | Sleepy star-cat | CatNap |

**4. Sounds.** See `ASSETS.md`. I can't hear audio, so you need to listen and pick.

**5. Game name.** Settled by the owner on 2026-11-02: **SCARE THEM**.

## Manual test

Save the place, then use plain Play (F5). Stop Play between tests.

**Everything first.** The Phase 3 to 7 checklists in `docs/phase3` to `docs/phase7` are all still unrun, and these matter most.

**Phase 8**

1. Output should show `[Config] Balance is valid: 42 confirmed, 183 provisional`, with no red errors.
2. Set `TestRoster` as above, with a fresh `TestProfileKey`. Hatch several eggs. You should see named placeholders with labels in the case, gliding in and growing to scare, and paying their listed amounts. The Index should fill in.
3. Fuse 4 of one placeholder species, and check it's bigger.
4. Turn on Reduced scares in Settings. Scares should have no lunge or hop, and the kid shows "?". Rejoin: it should stay on.
5. Change the volumes and rejoin: they should stay, though nothing plays yet.
6. **Phone and tablet:** in the device emulator, try a phone and a tablet in both orientations. Check Fear, the left buttons, tutorial caption, every panel and the timing bar. Fear should be top right on touch devices.
7. **Performance:** in a Local Server with as many players as your PC can manage, rebirth up to several floors, then check Studio's frame rate. Write down what you see.
8. **8-player test:** this needs real people on a published copy, using real saves. Do it last, and try leaving and rejoining mid-scare.

Clear the test attributes afterward: set `TestProfileKey` to `""` and the others to `nil`.

**Checks from the command bar**

```
print(require(game.ServerStorage.ContentTests)())
```

The last line should say `ALL PASSED`.

## What's next

By your choice, the **Town and Buildings phase** follows this one: the package's map and building ideas on your ring map, starting with previews of the four hub buildings. See `docs/spec/OVERRIDES.md`.

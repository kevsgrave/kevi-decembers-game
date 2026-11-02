# Phase 4 report: automatic scares, bedroom tier rolls, manual scare (2026-11-02)

Built in SCARE THEM in Edit mode. **Not play-tested:** timing and payout math are tested with a fake clock, but the crawl, the timing bar and the floating text haven't been seen running.

**Test with plain Play in Studio (F5).** Only that uses the separate `STUDIO_` test saves. A published game or a Team Test uses real saves.

## What changed

| Area | Change |
|---|---|
| Scheduler | One central scheduler runs every room instead of one thread per room: Sleeping, Scaring, Paying, Resetting, Sleeping |
| Timing | Scares keep their exact rarity interval: Common 15s, Rare 10s, Epic 8s, Legendary and Mythic 5s, SPOOKY 3.5s, Secret 3s. A server stall can't cause a burst of payouts |
| Payout formula | One formula for pay and display: base x room x size x mutation x accessory x rebirth, rounded. Size, mutation and accessory stay at x1 until their phases give them values |
| Exactly once | A scare pays only if, at that moment, the monster is still placed, the owner still has the plot, and a kid is in bed. Removing the monster stops the room at once |
| Case | Third line shows how the number is made, like `300 base x1.5 Gold x2 Rebirth` |
| HUD | "about X Fear / sec" estimate. Fear itself still arrives per scare |
| Floating text | `+X Fear` over the room window, and "Gold room! x1.5" when a better room rolls. Visitors can see it too |
| Manual scare | **Short scripted crawl**, your default: E at the hole, fade, you're moved inside, a timing bar runs, tap BOO!, the kid reacts, you're moved back out |
| Manual pay | Exactly 100 x rebirth multiplier, plus +10% for Good or +20% for Perfect. **The bedroom tier no longer multiplies it**, per the spec |
| Manual rules | 8s cooldown and a distance check. The server times the tap itself. Rooms with a monster working refuse manual scares, so one kid can't pay twice. Leaving or dying mid-crawl pays nothing and frees you |

The kid's reaction, the room reroll, Jeff's walk and pop through the window, and the tier sign already existed and now run from the scheduler.

No new models or assets. The new on-screen items are text and interface built in code.

## Test results

| Test | Result |
|---|---|
| `ScareTests`, 44 checks | All passed |
| `InventoryTests`, 50, `PlotTests`, 104, `ConfigTests`, 63 | All passed |
| All seven rarities pay once per interval over 10 cycles | Passed |
| No monster, picked up mid-scare, picked up later, re-placed, owner left | No earnings or double pays |
| 500s server stall | One scare, not a hundred |
| Invalid scare, broken room | Pays nothing; other rooms keep running |
| Formula with every factor, manual scare, timing zones | Passed |
| Room odds, 1,000,000 seeded rolls | Normal 73.93, Silver 20.00, Gold 5.01, Platinum 1.01, Diamond 0.052, GOD 0.0015 (15 rolls; expected about 10) |
| Server modules load, client scripts compile | Passed |
| Crawl, bar, floating text on screen, real kid reaction timing | **Not tested, needs Play** |

## Known limits

1. **Rooms still read bright** even though the nightlight is low. You haven't decided on darkening the walls, so I left them.
2. **The crawl is a fade and a move**, not a crawl animation. Characters are held in place on the server while inside.
3. **Once all your open rooms hold monsters, you can't manual scare.** That's the package's rule to prevent double pay. Pick one up if you want to.
4. **Hatches are still Jeff**, so the scare is Jeff's for every rarity. Each species' own scare comes with original models.
5. **No sounds yet**, and no reduced-scares setting. Both are Phase 8.
6. **The EditableMesh warning** on bed humps still needs the setting in Game Settings > Security.
7. **Rebirth still wipes Fear** until the rebirth phase. Server size still needs setting to 8.

## Manual test

Save the place, then use plain Play (F5). Stop Play between tests.

**Automatic scares**

1. Output should show `[Config] Balance is valid: 42 confirmed, 175 provisional`, with no red errors.
2. Hatch and place a monster. The case should show name and rarity, Fear per scare and seconds, and a line like `300 base`. The HUD should show "about X Fear / sec".
3. Watch through the window. Jeff sneaks in and pops, the kid reacts, `+X Fear` floats up, and a fresh kid appears.
4. Time a few scares. Common should be 15s apart, Rare 10s, Epic 8s.
5. Check that Fear goes up by exactly the case's number each scare. The tier sign can change, and the number changes with it.
6. Pick the monster up mid-walk. No more Fear should arrive and the HUD rate should drop.
7. Place it back, then stop Play. Press Play again: it should resume working and paying.

**Manual scare**

8. At an empty room's hole, press E on "Crawl In". The screen fades and you appear inside, with a timing bar.
9. Tap BOO! (button, E or Space) in the green zone: "Perfect!" and +120 Fear. In yellow: "Good!" and +110. Elsewhere or no tap: +100.
10. You should end up back outside and able to walk. The kid reacts and a new one appears.
11. Try again at once: "Catch your breath" with seconds left.
12. Try a room with a monster in it: it should refuse with a message.
13. If you can, reset your character while inside. You should respawn normally with no Fear added.
14. Check the bar and BOO! button at a phone size in the device emulator.

**Two players** (Test tab, Local Server, 2 players; these use test saves too)

15. Player 2 watches player 1's room and sees the scare and floating text, and earns nothing.
16. Player 2 tries player 1's crawl hole: the "isn't your plot" message.
17. Close player 1 mid-scare. Their plot should empty with no errors in Output.

**Checks from the command bar**

```
print(require(game.ServerStorage.ScareTests)())
```

The last line should say `ALL PASSED`.

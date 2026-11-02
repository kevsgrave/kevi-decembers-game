# Phase 6 report: rotating shop, accessory boxes, secret egg trackers (2026-11-02)

Built in SCARE THEM in Edit mode. **Not play-tested:** the shop and tracker rules are tested on throwaway saves with a fake clock, but the shop panel, arrow and dig haven't been seen running.

**Test with plain Play in Studio (F5).** Only that uses the separate `STUDIO_` test saves.

## What changed

| Area | Change |
|---|---|
| Shop | The stall's prompt opens the shop. Your first visit still gives the free Rare box, once ever |
| Rotation | Every 300 seconds of server time. The lineup is worked out from the time, so every server shows the same stock with nothing to store. The panel and the stall's sign show a countdown |
| Stock | Each player has their own stock, per the package: Rare 3, Epic 2, Legendary 1, Secret 1, Tracker 1. It's saved, so a rejoin can't refill it. It resets with each rotation |
| Purchases | Stock, Fear and the item change together with no gap, so requests can't interleave. Prices and items only come from config. The client names an item and the rotation it was looking at, so a slow purchase can't buy from a shop that has changed |
| Boxes | All four tiers on sale, each showing its items, chances and multipliers before you buy |
| Case visuals | Each of the 14 accessories has its own small shape on the case lid, made of parts. Rarer ones glow |
| Trackers | Buy one, press Use under Items, and the server picks a private spot from 18 hidden dig spots. An arrow, distance and timer lead you there |
| Digging | A glowing mound appears only on your screen. Hold to dig. The server checks it's your own dig and that you're really standing there |
| Buried Moon Egg | Saved under Items with its odds shown. Hatching uses it up and adds the monster together, with the same reveal |
| Abandoned digs | The policy: after 15 minutes, or if a spot is removed, your tracker goes back to your Items, so a paid tracker is never lost. Disconnecting keeps the same spot |

No new meshes or assets. The new world objects are invisible dig spots, shapes made of parts, and a local mound made of a part.

## A change from the package

The package asks for 3 to 5 offers per rotation, **and** chances of Epic 60%, Legendary 20%, Secret 3% and Tracker 2%. With only 5 items, those conflict: filling to 3 makes Rare, Epic and Legendary show almost every time. Legendary appeared about 90% of the time and the lineup changed only 23% of the time.

I kept the chances, because rarer stock appearing less often is your original rule. The minimum is now 1 offer (`shop.offersMin` in `Balance`). So **about a third of rotations have only the Rare box**. To fill the shelf, the fix is more items, or changing `offersMin`, which also makes Legendary common.

## Test results

| Test | Result |
|---|---|
| `ShopTests`, 44 checks | All passed |
| `TutorialTests` 44, `ScareTests` 44, `InventoryTests` 50, `PlotTests` 106, `ConfigTests` 63 | All passed |
| Double purchase on the last one, 50 requests at once | Only the stock sells, with no extra charge |
| Rejoin | Stock doesn't refill, and purchases are kept |
| Slow purchase from the old shop, future rotation, made-up item, item not on sale, not enough Fear | All refused with no charge |
| 20,000 rotations | Lineup changes 68% of the time. Epic 59.7%, Legendary 19.9%, Secret 3.0%, Tracker 2.0% |
| Another player digging your egg, replaying a dig, digging before activating or after expiry | All give nothing |
| Disconnect mid-dig | Same spot on return |
| Expired dig or removed spot | Tracker comes back and can be reused |
| Pathfinding to the 18 dig spots from the ring road nearest each | All reachable |
| Accessory on a case | Checked in a screenshot, `case-accessory.jpg`, with the room temporarily placed and then removed |
| Shop panel, arrow, mound, real dig | **Not tested, needs Play** |

## Known limits

1. **The hold to dig is timed on the client.** The server checks ownership and distance, not the 2 seconds. A cheater could skip the wait, but not the walk or the ownership check.
2. **The arrow points straight at the spot**, not along paths, so it can point across obstacles. Pathfinding says all spots can be reached.
3. **Saving failing mid-session** still doesn't block spending. A purchase is saved right after it happens, with a short delay between saves.
4. **Accessory looks are simple shapes**, ready to swap for models once you've approved them.
5. **The HUD doesn't show the shop clock.** It's on the stall's sign and in the panel.
6. **Prices are provisional.** Nothing here has been balanced against real earnings.

## Manual test

Save the place, then use plain Play (F5). Stop Play between tests.

**Test helpers.** Run these in the command bar before pressing Play, to start with Fear to spend and a tracker. They only work in Studio, never on real servers. Each join sets your Fear to that amount and adds one more tracker.

```
game.ServerStorage:SetAttribute("TestProfileKey", "shop1")
```

```
game.ServerStorage:SetAttribute("TestGrantFear", 5000000)
```

```
game.ServerStorage:SetAttribute("TestGrantTracker", true)
```

**Clear all three afterward**, by setting the key to `""` and the other two to `nil`.

1. Output should show `[Config] Balance is valid: 42 confirmed, 179 provisional`, with no red errors.

**Shop**

2. Press E at the stall. The panel shows items, chances, your stock and a countdown. The stall's sign counts down too.
3. Wait for a rotation. "New stock is in!" should appear and your stock resets.
4. Open a second Local Server client: both should show the same lineup and countdown.

**Last-stock races and replays**

5. Buy Rare boxes until "Sold out". Click Buy as fast as you can on the last one: you should get exactly your stock, and Fear should drop by exactly that.
6. Stop and press Play again in the same rotation: stock should not refill, and your boxes should still be there.
7. Open the panel, wait for the countdown to pass 0:00, and quickly press Buy before it refreshes: "The shop just changed", and no charge.
8. Test a laggy purchase: in Studio's Network settings, add incoming replication lag, then click Buy several times. You should get one purchase per answered request, and never more than your stock.

**Accessories**

9. Open a box and equip it. The case should show its shape and a higher payout. Remove it and the shape goes. Rejoin and the shape returns.

**Trackers** (they appear in about 2% of rotations, so use the helper)

10. Go to Items and press Use on your tracker. An arrow, distance and timer appear.
11. Stop and press Play mid-way: same spot, same timer.
12. Follow it. Within about 60 studs, a glowing mound appears. Hold to dig: "You dug up a Buried Moon Egg!"
13. Hatch it from Items and check the reveal.
14. Check a second player can't see your mound, in a Local Server.
15. Let one expire, or wait 15 minutes: "trail went cold", and the tracker returns to Items.

**Phone sizes.** In the device emulator, check the shop panel, Items rows and tracker readout fit and can be tapped.

**Checks from the command bar**

```
print(require(game.ServerStorage.ShopTests)())
```

The last line should say `ALL PASSED`.

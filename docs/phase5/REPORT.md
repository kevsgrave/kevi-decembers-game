# Phase 5 report: eggs, guided tutorial, accessory basics (2026-11-02)

Built in SCARE THEM in Edit mode. **Not play-tested:** the tutorial logic, odds and rewards are tested on throwaway saves, but the arrows, panels and reveal haven't been seen on screen.

**Test with plain Play in Studio (F5).** Only that uses the separate `STUDIO_` test saves.

## What changed

| Area | Change |
|---|---|
| Egg shrine | Its prompt now opens an egg panel listing the five Fear eggs with price and rarity odds before you spend |
| Hatching | Server roll, spend and reward happen together. A retry of the same request can't hatch twice, and the button waits for the answer. The monster goes to your inventory, never into a case |
| Reveal | Short shaking egg, then name, rarity word, Fear per scare and seconds. The result is decided first, so skipping can't change it |
| Promise Egg | Free, exactly 80% Epic / 20% Legendary, once only, offered only at its tutorial step |
| Tutorial | Scare a kid, hatch the Promise Egg, select it, place it, watch a scare, claim the free box at the shop, open it, equip it, see the multiplier, finish. There is no claim step, because plots are auto-assigned |
| Guidance | Caption with step number, a gold arrow that always stays on screen, a beam from you to the target, and a highlight on the target. Interface steps point at the hotbar or Inventory button |
| Soft-lock safety | The step is worked out from what your save holds, not a counter. A disconnect, respawn or doing things out of order can't lose your place. Steps only move on when the server sees the real action |
| How to play | After finishing, this button re-reads the steps. It only shows text, so it can't repeat a reward |
| Free box | The shop stall has a Claim Free Box prompt, once ever. The rest of the shop is Phase 6 |
| Boxes and accessories | Inventory panel's new Items tab: open boxes with each item's chance shown. Press F at a case to equip one. One per case, one case per accessory, and removing or swapping loses nothing. The multiplier really pays, and the case line shows it |
| Index | New tab listing all 42 species, hidden as "???" until found, with progress |

No new models or assets. The only new world object is an invisible prompt spot at the shop counter.

**The numbers are unchanged, but all five Fear eggs are now on sale**, at 500, 6,000, 60,000, 600,000 and 6,000,000 Fear. You still start with 500 Fear as well as the free egg, as a safety margin.

## Test results

| Test | Result |
|---|---|
| `TutorialTests`, 44 checks | All passed |
| `ScareTests` 44, `InventoryTests` 50, `PlotTests` 105, `ConfigTests` 63 | All passed |
| Full tutorial in order | Passed |
| Save and rejoin at every step, through JSON like a real save | Resumes the same step, ending with exactly one monster and one accessory |
| Doing things out of order, picking the monster up mid-tutorial | Goes back a step, never stuck |
| Promise Egg and free box once only, including after a rejoin | Passed |
| 200,000 Promise Eggs | Close to 80% Epic, exact at the edges |
| Every egg only rolls what it discloses | Passed |
| Boxes, equip rules, payout rises with the accessory, damaged saves repaired | Passed |
| Server modules load, client scripts compile | Passed |
| Arrows, panels, reveal, phone sizes, real disconnects | **Not tested, needs Play** |

## Known limits

1. **The Index can't fill up yet.** Hatches are all Jeff, so the 42 species stay "???" until original models exist. It says so on screen. Mutations don't roll yet either; that's Phase 7.
2. **The tutorial doesn't physically stop you** doing other things, such as hatching a Starter Egg early. It adapts, and only the guidance is forced.
3. **With all 8 plots taken**, a visitor waits at the first step until one frees up. Server size is still not set to 8.
4. **Accessories don't show on the case as a model yet.** Their effect shows on the case's line. Visual attachments are Phase 6.
5. **Index milestone rewards, egg previews as models and multi-hatch** are not built.
6. **Manual scares still refuse rooms with a monster working**, the rule you left in place.
7. **Earlier items:** rooms read bright, rebirth wipes Fear until Phase 7, and the mesh setting is off.

## Manual test

Save the place, then use plain Play (F5). Stop Play between tests.

**A fresh run.** To start from an empty save without touching your others, run this once in the command bar, then press Play. Clear it afterward by setting it to `""`.

```
game.ServerStorage:SetAttribute("TestProfileKey", "tut1")
```

1. Output should show `[Config] Balance is valid: 42 confirmed, 177 provisional`, with no red errors.
2. Step 1: an arrow, a beam and a highlight lead to a crawl hole. Turn your camera away; the arrow should stay on screen and point back. Do the scare.
3. Step 2: follow the arrow to the shrine and press E. The panel shows the Promise Egg as FREE at the top with 80/20, and the five Fear eggs with odds. Hatch the Promise Egg and try skipping the reveal.
4. Step 3: the arrow points at the hotbar. Select the monster.
5. Step 4: place it at the highlighted case. Deselecting first should send you back to step 3.
6. Step 5: watch a scare. Fear rises and the next step appears.
7. Step 6: go to the shop and claim the box. Try claiming again: it should refuse.
8. Step 7: press I, go to Items and open the box. Each item's chance is shown.
9. Step 8: press F at a case and equip it. The case's line should show the accessory multiplier and a higher payout.
10. Step 9: the caption shows the multiplier. Press Finish. "How to play" should appear; try it, then check Fear and items didn't change.

**Disconnect at every step.** Use a new `TestProfileKey`. At each of steps 1 to 9, stop Play and press Play again. If it says your progress is still saving, wait up to 2 minutes. Check that:

- You resume the same step, or the next if you'd finished it.
- You get no second Promise Egg or box.
- Reset your character at a few steps too. The tutorial should carry on.

**Eggs**

11. Try an egg you can't afford. The button should say how much you need, and Fear shouldn't change.
12. Press Hatch quickly several times. You should get one hatch per request.
13. Walk away with the panel open and press Hatch: "Come back to the egg shrine".

**Accessories and Index**

14. Equip an accessory, press Remove, and swap between cases. Check nothing is lost and the case number follows.
15. Rejoin. Accessories should still be on their cases.
16. Open the Index tab: "0 / 42", Jeff listed as the stand-in, and species as "???".

**Phone sizes.** In the device emulator, try a phone and a tablet, in landscape and portrait. Check the caption, arrow, Finish button, egg panel, reveal, inventory tabs and timing bar all fit and can be tapped.

**Checks from the command bar**

```
print(require(game.ServerStorage.TutorialTests)())
```

The last line should say `ALL PASSED`.

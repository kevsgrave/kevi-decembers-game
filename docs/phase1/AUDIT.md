# Phase 1 audit (2026-11-01)

Compares the place **SCARE THEM** (PlaceId 95107016076006, the working copy), the repo, the master prompt and the playtest notes.

**How this was checked:** Studio in Edit mode only. I read the hierarchy, measured the geometry and read the code. **Nothing here has been play-tested**, so "in the code" means the logic exists, not that it was seen working.

## Studio vs repo

All 17 scripts in SCARE THEM matched `jumpscare-rng-v1` (07932ac) exactly, compared by length and hash with line endings and trailing whitespace normalised. `tools/MapBuilder.luau` matches `ServerStorage.MapBuilder`.

These live only in the place, not in the repo: the map (Workspace), `ServerStorage.PlotTemplate`, `Furniture`, `KidModels`, `MapKit`, and the generated materials. `tools/build_plot.luau` and `MapBuilder` rebuild parts of the map, but the generated meshes exist only in the place file, so **saving the place is the only backup of them**.

## Playtest checklist (27/28 Oct): what is really there

| Item | Note says | Found | Evidence |
|---|---|---|---|
| Bigger bedrooms | done | Present | `RoomFloor` is 28x28 in all six |
| Display glass on the left | done | Present | Measured from the aisle in all six: glass 7 studs left, window 5 right, on both sides of the aisle |
| Hidden spawn | done | Present | `SpawnLocation` neutral, transparency 1, no decal; `Plot.SpawnPoint` invisible |
| Claimable empty plot | done | **Partly** | Plots are empty with "Free plot" signs, but they are auto-assigned on save load. There is no claim station, and the master prompt asks for one |
| Name and cash on case | done | In the code | `ShowcaseLid.Info` has MonsterName and Cash |
| Reference art style | first pass | Present | Blue plot floor with 5 stud textures, pink carpet |
| Hatch to inventory, E to place | done | In the code | `hatch`, `syncTools`, `useShowcase`; no touch or gamepad path beyond prompts |
| Dim nightlight | done | Present | Lamp PointLight brightness 0.5, range 10 |
| Jeff only, Blender scare | done | In the code | `JeffRig`, `JeffAnim`; `art/monsters/jeff/jeff.blend` exists locally but `art/` is untracked |
| Bedroom models | not done | **Further than the note says** | `Furniture` has 20 models, `RoomStyles` refurnishes by tier. Not updated in the note |
| Dedicated egg area | not done | **Partly** | Hub has `EggShrine`, `Egg` and `EggOdds`. Only one egg type, no separate area |
| Session-locked saves, Studio test keys | done | In the code | `PlayerData` lease and `STUDIO_` keys. Studio falls back to an unsaved session; not run against real DataStores here |
| Inventory is saved data | done | In the code | Tools rebuilt from `Monsters` |
| One self-checking config | done | Present, now stronger | Now `Balance` + `ConfigValidator` |
| Egg shows odds first | done | In the code | `EggOdds` is filled at server start; Edit shows only "Odds" |
| Rarity as a word | done | In the code | `showInfo` |
| Rebirth confirm and rate limit | done | In the code | `HUD`, `allowRebirth` |
| Server distance checks | done | In the code | `near()` in hatch, showcase, manual scare. Rebirth has none, because no rebirth station exists |
| Agents stay in Edit mode | done | Followed | |
| Phone and tablet UI | not done | Not done | HUD uses fixed pixel sizes |
| Tone-down setting | not done | Not done | The saved field now exists, nothing uses it |
| Maturity questionnaire | not done | Not done | Owner action |

## Master prompt vs the game

**Live and matching:** 8 plots, 6 bays with 3 unlocked, glass-left layout, hidden spawn, crawl-hole manual scare at 100 base, rarity payouts and timings, bedroom odds and multipliers, one rebirth = one room, server-owned rolls.

**Differences to fix in later phases:**

| Gap | Phase |
|---|---|
| Auto-assign instead of a claim station; no station for shop, fusing, rebirth or index | 2 |
| One floor only; no floor 2 | 2, 7 |
| `Players.MaxPlayers` reads 60; the spec says 8 (a place setting, owner or Phase 2) | 2 |
| Placement uses bedroom index, not a named slot ID (workable, needs a decision) | 3 |
| No index UI; hatches now record species but nothing shows them | 3 |
| **Payout rerolls every scare.** The spec fixes it per monster. `BaseFear` is now saved but not yet paid from | 4 |
| Payout ignores size, mutation and accessory multipliers | 4 |
| Manual scare multiplies by the bedroom tier, which the spec doesn't ask for, and shares the automatic rebirth curve | 4 |
| No sounds anywhere in the place | 4, 8 |
| No tutorial, tutorial egg or free box | 5 |
| One egg; the other four are defined with `live = false` | 5 |
| Shop sign says "opening soon"; no shop, boxes or trackers | 6 |
| No fusion or mutations | 7 |
| **Rebirth wipes all Fear.** The spec's provisional rule keeps what's left after the cost | 7 |
| Rebirth stops at 6 rooms | 7 |
| Roster is Jeff only; Secret can't roll in the live egg | 8 |
| Reduced-scares setting, audio sliders, responsive HUD | 8 |
| Robux purchases and receipt processing | 8 |
| 8-player stress and reconnect tests | 8 |

## Decisions for the owner

1. **"Jeff" and the monster list.** `Monster Names.md` lists Jeff the Killer, Smile Dog and others, and notes several are copyrighted. The master prompt says to make original characters and not reuse franchise names. The in-game name is `start.monsterKind` in `Balance`, so renaming is one line. Whether to keep it is your call before publishing.
2. **GOD odds.** The note says `.001` with no % sign. Set to 0.001% as the master prompt says. If it should be something else, change GOD and Normal together in `Balance`.
3. **Rebirth and Fear.** The live game wipes Fear on rebirth, the master prompt's rule keeps the rest. Phase 7 follows the master prompt unless you say otherwise.

## Confirmed vs provisional

`Balance.luau` tags every number; 42 are confirmed by the notes and 109 are provisional. `Config.Status` holds the tag and note for each value.

**Confirmed:** 8 players and plots; manual base 100; six rarity bands and timings; bedroom multipliers and the Diamond, Platinum, Gold and Silver odds; tutorial egg 80/20; fusion 4/3/3; start 3 of 6 rooms, one room per rebirth; shop rotation 300s; one free box.

**Provisional:** GOD odds and Normal's remainder; Secret payout and speed; all ordinary egg prices and odds; manual cooldown; rate limits; inventory cap; mutation multipliers and odds; size multipliers and model scale; rebirth cost and multiplier; floor cap; accessory names, multipliers and odds; shop prices, chances and stock; tracker price and expiry; starting Fear.

## Test results

Ran in Studio on unparented copies, then again on the synced scripts. Lune is not installed and the rules forbid starting Play, so this replaced the Lune or Play test.

- `ConfigTests`: all 53 checks passed, including 21 intentionally broken tables, each reporting its own fault.
- `GameService`, `DataTemplate` and the rest of the server modules load with no errors, on copies with a fresh `Shared`.
- Sample startup error:
  ```
  [Config] Balance has 2 problem(s), fix them before the game can start:
    - bedroomTiers: odds total 101%, expected 100%
    - eggs.SpookyEgg.price: -5 is outside 0 to 1000000000000000
  ```
- Old and new `Config` compared: every value the live game reads is identical, including rolls across the whole bedroom range and rebirth math up to 12 rebirths.
- `DataTemplate` self-checks pass, including a v1 save migrating to v2 with its progress intact.

## Manual test for the owner

1. Press Play. Output should show `[Config] Balance is valid: 42 confirmed, 109 provisional`, and no red errors.
2. Hatch an egg, place the monster and wait for a scare. It should all work as before.
3. Rebirth with enough Fear. It should behave as before.
4. Stop Play. In the command bar run `print(require(game.ServerStorage.ConfigTests)())`. The last line should say `ALL PASSED`.
5. To see the startup error: in `ReplicatedStorage.Shared.Balance`, change Silver's chance to 21, press Play, read the red error, and undo it.

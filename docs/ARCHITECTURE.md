# Scare Sim architecture

The place **SCARE THEM** is the working copy. `src/` holds its scripts as source. The design spec is in `docs/spec/`, and `docs/spec/OVERRIDES.md` lists the owner's decisions that override it.

## Source and import tree

There is no Rojo project file. Scripts reach Studio by being copied into the matching Instance (`.server.luau` = Script, `.client.luau` = LocalScript, plain `.luau` = ModuleScript).

| Repo | Studio | What it does |
|---|---|---|
| `src/ReplicatedStorage/Shared/Balance.luau` | `ReplicatedStorage.Shared.Balance` | Every balance value, tagged confirmed or provisional |
| `.../Shared/ConfigValidator.luau` | `...Shared.ConfigValidator` | Strips tags, refuses bad data at startup |
| `.../Shared/Config.luau` | `...Shared.Config` | What game code reads, plus colours |
| `.../Shared/Remotes.luau` | `...Shared.Remotes` | Remote list and argument checks |
| `.../Shared/Net.luau` | `...Shared.Net` | Creates remotes |
| `.../Shared/JeffRig.luau`, `JeffAnim.luau`, `BedHump.luau` | `...Shared.*` | Monster and bed visuals |
| `src/ServerScriptService/Server/Main.server.luau` | `ServerScriptService.Server.Main` | The only server Script |
| `.../Server/GameService.luau` | `...Server.GameService` | Plots, hatching, placing, scares, rebirth |
| `.../Server/PlayerData.luau`, `DataTemplate.luau` | `...Server.*` | Session-locked saves, schema, migrations |
| `.../Server/RateLimiter.luau` | `...Server.RateLimiter` | Token buckets |
| `.../Server/GuestKids.luau`, `RoomStyles.luau`, `PlotFrame.luau` | `...Server.*` | Guests, room looks, plot space |
| `.../Shared/PlotLayout.luau` | `...Shared.PlotLayout` | Bedroom numbers, floors and heights |
| `.../Server/PlotClaims.luau` | `...Server.PlotClaims` | Who owns which plot |
| `.../Server/Inventory.luau` | `...Server.Inventory` | Rules for owned monsters, hotbar and placing |
| `.../Server/ScareScheduler.luau` | `...Server.ScareScheduler` | One scheduler for every room's scares |
| `.../Shared/Payout.luau` | `...Shared.Payout` | The Fear formula |
| `.../Shared/Tutorial.luau` | `...Shared.Tutorial` | The tutorial steps and rules |
| `src/ServerStorage/ConfigTests.luau`, `PlotTests.luau`, `InventoryTests.luau`, `ScareTests.luau`, `TutorialTests.luau` | `ServerStorage.*` | Tests, command bar only |
| `src/StarterPlayerScripts/*.client.luau` | `StarterPlayer.StarterPlayerScripts.*` | HUD, scare animation, bed humps |
| `tools/MapBuilder.luau` | `ServerStorage.MapBuilder` | Rebuilds the map from the command bar |
| not in the repo | `Workspace` (including `Stations`), `ServerStorage.PlotTemplate`, `Furniture`, `KidModels`, `MapKit` | Saved only in the place |

Startup order: `Main` requires `Config` (Balance is validated here, and a failure stops the game), starts `GameService` (creates live remotes), then starts `PlayerData`.

## Changing a number

Edit `Balance.luau`. Wrap the value in `C()` if the design notes settle it, `P()` if it's a default anyone can change. An untagged number or boolean stops the game at startup.

Used by the live game so far: starting Fear, all egg prices and odds, the accessory items, rarities, bedroom tiers, manual base and cooldown, inventory cap, hotbar size, max Fear, rate limits, room counts and rebirth cost and multiplier. The rest waits for its phase: shop and trackers (6), mutations, fusion and floors (7), the 42-species roster (when original models exist).

## Server validation convention

Every request from a client, whether a remote or a ProximityPrompt, checks in this order and stops at the first failure:

1. **Rate limit:** `RateLimiter` bucket with limits from `Balance.limits`.
2. **Arguments:** `Remotes.checkArgs(name, ...)`: exact count, right types, finite numbers, bounded strings and lists. Prompts have no arguments, so they skip this.
3. **Save loaded:** `PlayerData.Get(player)`. No profile means no action.
4. **Ownership:** the target belongs to this player's plot or inventory.
5. **Distance:** the server measures character to target itself, because prompt range is client-side.
6. **State:** room unlocked, monster not already placed, cooldown over, one-time reward unclaimed.
7. **Price:** read from config on the server, never from the client.
8. **Commit with no yield** between the checks and the change, so a double request can't spend once and receive twice.
9. **Tell the client:** return `ok, message` from a Function, or fire a Popup. Reasons stay generic.

Client requests with several steps carry a request id (the last `id` argument in `Remotes`), so a retry can't grant twice. The server picks prices, odds and rewards; clients only name what they want.

## Remotes

`Remotes.luau` is the source of truth. Live remotes are created by `Remotes.createLive(Net)`. A planned remote is created only when its phase flips it to `live`.

| Remote | Kind | Direction | Arguments | Status |
|---|---|---|---|---|
| Popup | Event | server to client | message | live |
| Rebirth | Function | client to server | none | live |
| GetInventory | Function | client to server | none | live |
| HoldMonster | Event | client to server | monsterUid | live |
| FavoriteMonster | Event | client to server | monsterUid, on | live |
| InventoryChanged | Event | server to client | state | live |
| ManualCue | Event | server to client | state | live |
| ManualTap | Event | client to server | none | live |
| HatchEgg | Function | client to server | eggId, requestId | live |
| TutorialStep | Event | server to client | state | live |
| TutorialDone | Event | client to server | none | live |
| OpenBox | Function | client to server | boxUid | live |
| EquipAccessory | Function | client to server | slotId, accessoryUid | live |
| UnequipAccessory | Function | client to server | slotId | live |
| OpenCase | Event | server to client | state | live |
| ShopChanged | Event | server to client | state | Phase 6 |
| BuyShopItem | Function | client to server | itemId, requestId | Phase 6 |
| ActivateTracker | Function | client to server | trackerUid | Phase 6 |
| Dig | Function | client to server | digId | Phase 6 |
| FuseMonsters | Function | client to server | monsterUids, requestId | Phase 7 |
| SetSetting | Event | client to server | key, value | Phase 8 |

Plots are assigned by the server, so they need no remote. Placing, picking up, starting a manual scare and claiming the free box are ProximityPrompts (server-side `Triggered`), so they need none either.

## Scares and payouts

`ScareScheduler.luau` runs every room from one loop: `Sleeping -> Scaring -> Paying -> Resetting -> Sleeping`. It takes time as an argument and never yields, so it can be tested with a fake clock. Taking a room out of the scheduler is what stops it paying.

`Payout.luau` is the one formula, used for both paying and display: `round(base x room x size x mutation x accessory x rebirth)`. Manual scares have their own: `round(100 x manual rebirth multiplier x timing bonus)`, with no bedroom tier.

Manual scares are a server-run session: fade, move inside, timing bar, pay once, kid reacts, move out. The character is anchored throughout. The client only says it tapped; the server times the tap against its own clock. Rooms with a monster working refuse manual scares.

Clients get payouts from bedroom attributes (`PayoutSeq`, `PayoutAmount`, `Tier`, `State`), so visitors see them too.

## Tutorial

`Tutorial.luau` works out the current step from what the save holds: monsters, placements, and the `ManualDone`, `EggUsed`, `ScareSeen`, `FreeBoxClaimed` and `Complete` flags. There's no counter to get out of step, so disconnects and doing things out of order are safe. `GameService.tutorialChanged` sends the step and its target after anything that could change it. `Step` in the save is only a record. "How to play" is client-only text, so it can't repeat a reward.

## Inventory and hotbar

`Inventory.luau` holds the rules and works only on a player's save table, with no yields, so requests can't interleave. `GameService` checks who is asking and how far away they are, then calls it, then calls `inventoryChanged` to update the hotbar and the panel.

- **Inventory:** `Monsters` in the save, up to `economy.inventoryCap`. The panel (`InventoryPanel.client.luau`) shows a copy from the server.
- **Hotbar:** `Hotbar` in the save, up to `economy.hotbarSlots` uids, shown as Backpack Tools. Tools are only a view and are rebuilt from the save, so deleting one loses nothing.
- **Placing:** the server reads the Tool actually in the player's hand. The client never names what to place.

## Plots and floors

Plots are **auto-assigned, by the owner's decision (overrides the master prompt's claim station)**. When a player's save loads, `GameService` gives them the first free plot. If all are taken they visit, and they get the next plot that frees up. `PlotClaims` tracks ownership: `Unclaimed -> Claimed -> Released`, with no yields, so two players can't get one plot. Leaving releases the plot and empties `Contents`.

`PlotLayout` maps bedroom numbers to floors: 1-6 is floor 1, 7-12 is floor 2, and odd bays are on the left. Saves key placements by bedroom number, so a slot stays stable on any plot. A floor is meant to be a copy of `PlotTemplate.Bedrooms` lifted by `PlotLayout.floorHeight(floor)`, renumbered with `bedroomIndex`. Floor 2 is built in Phase 7; `Config.BEDROOM_COUNT` still caps the game at 6 rooms.

`MapBuilder.stations()` adds the rebirth station, fusing sign and ghosts without rebuilding the hub or plots. Re-running it replaces only what it made.

## Saved data, schema version 3

Defined in `DataTemplate.luau`. Store `JumpscareRNG_PlayerData_v1`, key `U_<userId>`, or `STUDIO_<userId>` in Studio so tests never touch live saves. A newer or corrupt save is refused, never overwritten with defaults.

| Field | Shape | Used by the game yet |
|---|---|---|
| `SchemaVersion` | number | yes |
| `Fear` | whole number, 0 to max | yes |
| `TotalFearEarned` | whole number | written |
| `Rebirths` | number | yes |
| `NextUid` | number, next `m<n>` | yes |
| `Monsters` | uid to `{Kind, Tier, BaseFear, Size, Mutation?, Provenance, Favorited?}` | Kind, Tier, BaseFear, Favorited; Size and Mutation later |
| `Placed` | bedroom index as a string to uid | yes |
| `Hotbar` | list of uids | yes |
| `Index` | species id to true | written |
| `Boxes`, `Accessories`, `Eggs` | uid to definition id | Phases 5, 6 |
| `CaseAccessories` | bedroom index to accessory uid | Phase 5 |
| `Trackers` | uid to `{State, DigId?}` | Phase 6 |
| `Tutorial` | `{Step, Complete, FreeBoxClaimed}` | Phase 5 |
| `Settings` | `{ReducedScares, MusicVolume, SfxVolume}` | Phase 8 |
| `Receipts` | purchase id to true | Phase 8 |

**Migration v1 to v2** (runs when a save loads): keeps everything; each monster gets `BaseFear` at the middle of its rarity band, `Size = "Normal"` and `Provenance = "migrated"`; `TotalFearEarned` starts at the current Fear; `Index` is filled from owned monsters.

**Migration v2 to v3:** adds `Hotbar`, filled from unplaced monsters when the save loads.

Add new versions as new steps; never edit a released one.

Once a save is written as v2, a server still running v1 refuses it, so don't mix old and new builds in live servers.

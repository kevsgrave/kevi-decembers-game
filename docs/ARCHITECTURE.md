# Scare Sim architecture

The place **SCARE THEM** is the working copy. `src/` holds its scripts as source.

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
| `src/ServerStorage/ConfigTests.luau` | `ServerStorage.ConfigTests` | Config tests, command bar only |
| `src/StarterPlayerScripts/*.client.luau` | `StarterPlayer.StarterPlayerScripts.*` | HUD, scare animation, bed humps |
| `tools/MapBuilder.luau` | `ServerStorage.MapBuilder` | Rebuilds the map from the command bar |
| not in the repo | `Workspace`, `ServerStorage.PlotTemplate`, `Furniture`, `KidModels`, `MapKit` | Saved only in the place |

Startup order: `Main` requires `Config` (Balance is validated here, and a failure stops the game), starts `GameService` (creates live remotes), then starts `PlayerData`.

## Changing a number

Edit `Balance.luau`. Wrap the value in `C()` if the design notes settle it, `P()` if it's a default anyone can change. An untagged number or boolean stops the game at startup.

Used by the live game so far: starting Fear, Spooky Egg price and odds, rarities, bedroom tiers, manual base and cooldown, inventory cap, max Fear, rate limits, room counts and rebirth cost and multiplier. The rest waits for its phase: other eggs (5), accessories (5, 6), shop and trackers (6), mutations, fusion and floors (7).

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
| ClaimPlot | Function | client to server | plotId | Phase 2 |
| PlaceMonster | Function | client to server | slotId, monsterUid | Phase 3 |
| PickUpMonster | Function | client to server | slotId | Phase 3 |
| SetHeldMonster | Event | client to server | monsterUid | Phase 3 |
| InventoryChanged | Event | server to client | state | Phase 3 |
| ManualScare | Function | client to server | slotId | Phase 4 |
| RoomChanged | Event | server to client | state | Phase 4 |
| HatchEgg | Function | client to server | eggId, requestId | Phase 5 |
| TutorialStep | Event | server to client | state | Phase 5 |
| ClaimFreeBox | Function | client to server | none | Phase 5 |
| OpenBox | Function | client to server | boxUid, requestId | Phase 5 |
| EquipAccessory | Function | client to server | slotId, accessoryUid | Phase 5 |
| UnequipAccessory | Function | client to server | slotId | Phase 5 |
| ShopChanged | Event | server to client | state | Phase 6 |
| BuyShopItem | Function | client to server | itemId, requestId | Phase 6 |
| ActivateTracker | Function | client to server | trackerUid | Phase 6 |
| Dig | Function | client to server | digId | Phase 6 |
| FuseMonsters | Function | client to server | monsterUids, requestId | Phase 7 |
| SetSetting | Event | client to server | key, value | Phase 8 |

Claiming, hatching, placing and manual scares are ProximityPrompts today (server-side `Triggered`, no remote). Their phases decide whether to keep the prompt or move to the remote above.

## Saved data, schema version 2

Defined in `DataTemplate.luau`. Store `JumpscareRNG_PlayerData_v1`, key `U_<userId>`, or `STUDIO_<userId>` in Studio so tests never touch live saves. A newer or corrupt save is refused, never overwritten with defaults.

| Field | Shape | Used by the game yet |
|---|---|---|
| `SchemaVersion` | number | yes |
| `Fear` | whole number, 0 to max | yes |
| `TotalFearEarned` | whole number | written |
| `Rebirths` | number | yes |
| `NextUid` | number, next `m<n>` | yes |
| `Monsters` | uid to `{Kind, Tier, BaseFear, Size, Mutation?, Provenance}` | Kind and Tier; `BaseFear` paid from Phase 4 |
| `Placed` | bedroom index as a string to uid | yes |
| `Index` | species id to true | written |
| `Boxes`, `Accessories`, `Eggs` | uid to definition id | Phases 5, 6 |
| `CaseAccessories` | bedroom index to accessory uid | Phase 5 |
| `Trackers` | uid to `{State, DigId?}` | Phase 6 |
| `Tutorial` | `{Step, Complete, FreeBoxClaimed}` | Phase 5 |
| `Settings` | `{ReducedScares, MusicVolume, SfxVolume}` | Phase 8 |
| `Receipts` | purchase id to true | Phase 8 |

**Migration v1 to v2** (runs when a save loads): keeps everything; each monster gets `BaseFear` at the middle of its rarity band, `Size = "Normal"` and `Provenance = "migrated"`; `TotalFearEarned` starts at the current Fear; `Index` is filled from owned monsters. Add new versions as new steps; never edit a released one.

Once a save is written as v2, a server still running v1 refuses it, so don't mix old and new builds in live servers.

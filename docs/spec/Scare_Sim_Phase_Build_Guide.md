# SCARE SIM — DEVELOPMENT PHASES AND VERIFIABLE BUILD PROMPTS

Use the **complete master prompt** as permanent context for the agent, then paste one of the numbered task prompts below if your agent needs focused implementation. Each prompt refers to the embedded Game Design Bible and is an action request to **create working code and assets**, not an invitation to outline them. Completion checks are human playtest instructions, not permission for an agent to start/stop Roblox Play mode.

**Nonnegotiables every phase:** no copyrighted copied monsters; server-authoritative transactions; preserve existing good code; responsive GUI; Studio testing isolated from production; never fake product IDs, assets or completed work; changes must be integrated with all previously built systems.

## Phase 0 — Audit and validated configuration

**Paste into agent:** "Inspect the actual Roblox Studio/Rojo project, build an inventory of existing Instances/scripts/meshes/asset IDs and compare it against Scare Sim Bible. Do not trust historic playtest checkboxes as proof. Create/repair shared definition tables for all 42 species, 7 rarities, 7 egg types, room probabilities, 5 mutations, 4 size tiers, market stock, passes, products, room templates, quests and event definitions. Create a validation module proving every weighted outcome totals exactly 100% (including the 0.001%-assumed GOD chance), all monster payouts lie within original rarity ranges, IDs are unique, and every content reference is valid. Do not enter Play mode. Produce a truthful missing asset manifest."

**Acceptance:** validation fails clearly on wrong odds, invalid price, duplicate species; user can locate every definition; Studio test save environment is distinct.

## Phase 1 — Full Moonfall overworld map and eight plots

**Paste:** "Construct the actual Moonfall hub, giant moon fountain, roads, exactly eight free-roam physical plots (4 west, 4 east), all six hub stations and four exploration zones from the Game Bible, with low-poly original geometry and readable wayfinding. Implement unclaimed/claim/release plot assignment and rebuild from persistent owner floor templates. Make plots visibly empty until claimed, hide spawn pad, bright blue plot floor, pink carpet aisles. For every bay on both corridor sides: as seen from aisle, glass case on LEFT and bedroom window on RIGHT. First floor has six physically roomy bedroom bays, first three enabled; upper floor shell after sixth room. Ensure walkability, low collision and mobile rendering."

**Acceptance:** 8 claim slots, proper 3+3 bays, no inverted frontage, physical hotel view windows, 2 users claim separate plots, released plots restore cleanly.

## Phase 2 — Persistent inventory, automatic scares and payout ledger

**Paste:** "Implement profile migration/session locking and authoritative Fear wallet. Model 42 definitions and unique monsters; implement owned inventory, favorites, one worker per case and place/remove by E/touch/gamepad with distance and owner checks. Implement room guest `Sleeping→Scaring→Paying→Resetting` machine and shared tick scheduler, 7 rarity scare speeds, fixed per-species payout, case name+rarity+Fear label, guest reactions, chance-based new bedroom tier, factorized final payout. Save everything. Use styled placeholder rigs if missing official meshes, but real scare animation and functioning economy must run."

**Acceptance:** a test-granted Common/Epic worker yields precise 15s/8s payouts (not frame-based auto grant), multiple rooms work, no double payment when moving/removing, source 6+1 rarity labels correct, room odds validated.

## Phase 3 — Full first-time tutorial and manual scares

**Paste:** "Implement server-tracked first-time tutorial with exact arrow/highlight sequence from Bible: claim → crawl to manual scare base 100 → redeem voucher → special 80% Epic/20% Legendary egg → inventory → equip/hold → place case → witness auto payout → free Rare box → open/equip → confirm increased payout. Resume mid-step after rejoin, detect failure/respawn and recover; replay cannot duplicate rewards. Manual scare uses timed cue and 8s server cooldown, later scales via rebirth. Add starter UX and settings for gentle scares."

**Acceptance:** no softlocks with insufficient Fear, rejoin any step resumes, accidental double-click no extra eggs, exactly one free box, no extra fear from same automatic/manual scare.

## Phase 4 — Hatchery, full roster, collection index and mutation rolls

**Paste:** "Build 5 regular egg machines with exactly the Bible's proposed Fear prices and rarity odds, one voucher egg, one tracker egg; list each possible species with true individual odds and current mutation subroll percentages. Hatch to saved inventory only. Create all 42 original species as planned assets or explicit replacement-ready primitive rigs (not copyright lookalikes), 7 rarity reveal treatments, index silhouettes/gallery and milestone rewards. Add favorite/lock and indexed species counts. Enforce full capacity, atomic wallet expense + grant, and correct stop conditions for optional auto hatch."

**Acceptance:** first-time hatch increments index, duplicate species gets a unique instance, guaranteed chances pass validation, animation skip doesn't change result, negative/duplicate purchase requests fail.

## Phase 5 — Five-minute market, accessory boxes and case equipment

**Paste:** "Build Midnight Market with server-authoritative synchronized 300s rotation, actual per-player stock, guaranteed basic Rare shelf and configurable scarce higher shelves, price and numeric chance displays, inventory box-opening, original accessory models, and 1 accessory slot on each case. Equipping changes payout and can be unequipped without loss or duplication. Prevent purchases across stale rotations. Provide shop mobile UI and accurate countdown."

**Acceptance:** 2 clients see same rotation, different personal quantities, one bought box only, stock reset after actual UTC epoch, equipped Rare accessory boosts active worker and persists.

## Phase 6 — Fusion, permanent mutations and guaranteed craft alternatives

**Paste:** "Implement Fusion Forge with 4 Normal→Large, 3 Large→Mega, 3 Mega→MASSIVE of same species and same mutation; inventory protection and exact confirmation. Slight model scaling, size labels and multiplier updates. Implement 5 named permanent mutations with visual FX, documented sources and deterministic Moon Fragment crafting in Observatory. No accidental overwrite or loss; no random chance for deterministic crafting. Save upgrades and inspect formula."

**Acceptance:** consumed monsters removed exactly once and new size grants once, favorite/placed invalid, mutation stats/visuals survive rejoin, mutating doesn't silently delete another mutation.

## Phase 7 — Explorer Tracker and map side quests

**Paste:** "Build Cemetery/Woods/Playground/Clocktower with approved dig location nodes and world map UI. Create rare market trackers, per-player activation, waypoint arrow with distance, owner-only glowing mound, 2s server-validated dig, and saved Buried Moon Egg grant. Persist incomplete expeditions and don't allow stolen/replayed claims. Add original lore notes and a deterministic exploration quest, plus teleport pads unlocked after visit."

**Acceptance:** tracker correctly points to reachable node, other players cannot collect it, disconnect during dig doesn't burn entitlement or duplicate egg, reward odds valid.

## Phase 8 — Rebirth floors and room upgrades/decor

**Paste:** "Implement rebirth costs based on configurable 50k×3^current, preview changes and confirmation, permanent 1+0.25×rebirth multiplier and exactly 1 added room per rebirth. Preserve inventories/rooms. Rebirth 3 fills first six and reveals new floor shell, rebirth 4 enables floor-2 room-1. Implement reusable 3+3 upper floor templates, foyer themes and 3 modest room improvement categories with capped 30% total extra bonus, plus optional cosmetic decor placement."

**Acceptance:** room counts 3→4→5→6→7; multiplier on auto/manual; floor stair path accessible; room upgrade math correct; decorations cannot clip interaction points.

## Phase 9 — Quests, events, social play and complete UI

**Paste:** "Implement Book of Frights rewards, 3 feasible daily quests, weekly contribution ledger, achievements, 5 town event types with fair/nonrandom rewards, 8-player sightseeing and read-only visitor case inspection. Build full HUD, inventory, case inspector, hatch odds, market timer, forge, index, map, quest UI and accessibility settings according to Bible. Integrate animated onboarding and reduce-scaring mode across VFX, camera and audio."

**Acceptance:** no premium-only normal quest, no client-submitted fake objective, UI works on phone/tablet/gamepad/PC, other player's plot remains read-only; 8-player event doesn't lag badly.

## Phase 10 — Monetization, gifting and platform rules

**Paste:** "Create pass/premium shop UI for the Bible's proposed eight passes and six guaranteed products, but disable real purchase flows until actual creator-supplied product/pass IDs exist. Correctly check pass ownership via MarketplaceService; process developer-product receipts idempotently with durable ledger and safe retries; implement optional gifting of equivalent guaranteed entitlements only using supported official flow. Never claim to transfer actual gamepass ownership without compatible API. Keep all paid random systems disabled by default, or implement true numerical final-item odds, actual policy/eligibility restrictions and compatible alternatives for ineligible players if specifically enabled. Show actual localized marketplace prices, not hardcoded promotional claims."

**Acceptance:** missing IDs produce no charge prompt, duplicated receipt id cannot grant twice, purchased entitlements persist, disabled-region users never access restricted paid-random mechanics, not falsely branded as free stock.

## Phase 11 — Complete art pass, sound and 8-player optimization

**Paste:** "Replace all generic primitives with distinctive, original authored low-poly scenery, 42 finalized character models, original animation actions and sound bank if actual asset-generation/Studio tools permit. If permissions/assets are missing, do not claim completion: create detailed asset-manifest with placeholders still functional. Implement content LOD, StreamingEnabled safe handling, single server scheduler, VFX pools, server throttling, mobile memory controls, camera/audio intensity settings. Run static test tools where available; human handles Studio playtest."

**Acceptance:** original assets/placeholder status clearly distinguished, 8 plots with multi-floors responsive, no disconnected VFX loops, no unsupported/unlicensed assets.

## Phase 12 — Release QA, migration and publishing handoff

**Paste:** "Perform code static analysis and produce exhaustive, executable manual test plan covering fresh user, tutorial retry, 2- and 8-player ownership, payout math and 0.001 GOD tier, eggs, stock cutoff, tracker recovery, mutation/fusion atomicity, full room progression, datastore failure, server hop, receipt idempotency, PC/mobile/gamepad UI and reduced scares. Reconcile all TODOs and unresolved blockers, prepare final project manifest, GameConfig dictionary, rights/license asset list, rollback/migration plan, age-content questionnaire reminder and exact creator publication steps. Never claim Studio playtests were performed if you were limited to Edit mode."

**Acceptance:** owner can verify every required feature and locate all code; no fake premium IDs, no lost/duplicated rewards; failing items explicitly reported.

## Quick order of implementation priorities

1. **Must work before anything else:** plot + 3 rooms + manual scare + tutorial egg + saved inventory + case + automatic payout + room reroll.
2. **Complete source-based feature parity:** 7 rarities, five normal eggs, shop, accessories, trackers, fusion, five mutations, rebirth floors, full tutorial.
3. **Enhanced game identity:** map zones, 42 original monster concepts, decorations, museum, quests and events.
4. **Commercial hardening:** cross-device UI, receipts, moderation rules, gift equivalents, performance testing and publishing handoff.

The original Obsidian archive contains source concepts, not a ready-to-publish place file. Final proof always comes from actually creating/integrating and testing a Roblox Studio project.

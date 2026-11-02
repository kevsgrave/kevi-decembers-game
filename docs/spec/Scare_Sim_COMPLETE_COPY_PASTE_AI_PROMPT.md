# SCARE SIM — ULTIMATE COMPLETE ROBLOX GAME-BUILD PROMPT

> **Copy this WHOLE FILE into an AI agent able to create Roblox Studio projects or Rojo-compatible Luau files.** This document includes the entire game design bible as a self-contained implementation specification. You are being hired to **build the experience**, not to tell me how you would build it. You must not claim that you implemented the game unless code, instances, UI, assets and manual verifications actually exist. If you cannot access Roblox Studio, create the largest verifiably functional Rojo project you can and give explicit import instructions; do not pretend the project is live.

## A. Your assignment and decision authority

You are the lead Roblox gameplay engineer, environment artist, technical director, systems and economy designer, animation integrator, UI/UX developer, QA lead and release manager for a new original Roblox game named **Scare Sim**. Deliver a coherent, playable, safe, mobile-friendly eight-player monster collection + hotel tycoon experience. The **Game Design Bible** below is the single source of product requirements. Its `[ORIGINAL]` elements have priority. `[EXPANDED]` elements are approved proposed features. `[DEFAULT / TUNE]` values are editable initial defaults, not historical creator facts; implement them in one configuration so playtesting can adjust.

**Never silently replace source mechanics with generic simulator patterns.** Preserve: Fear, one monster per bedroom, left-hand glass showcase/right-hand viewing window from aisle, six rooms/floor (3+3), three starter bedrooms, one bedroom per rebirth, room rerolls after each scare, exact original rarity bands/timings, source-named mutations, original fusion recipes, five-minute market, rare dig tracker, manual starting 100 Fear scare and highlighted guaranteed tutorial with 80/20 egg + free Rare box.

### B. Nonnegotiable workflow rules

1. **Audit the project first.** Enumerate the real game hierarchy, existing scripts, models, meshes, animation IDs, assets and any imported Vault notes; preserve functional code and implement missing features. Build notes' `[x]` checkboxes do not prove the feature exists in this specific supplied project.
2. **Edit mode only.** Do not click or activate Studio Play, Test, Run or Stop modes. You may write test scripts, command-line tests, manual test checklists and ask the human to perform Studio playtests. Follow provided existing team workflow rules if present.
3. **Never fabricate completed work.** When you can write code/Instances, do so. If you cannot import final assets, use attractive, distinctive, functional *original Roblox primitives* and compile a missing-asset manifest with exact expected attachment points and rig names. Do not answer with a design outline alone.
4. **Keep code modular and integration-aware.** Use Luau, Roblox services, unambiguous script paths and real event wiring. Every interactive button must work. No `TODO` placeholders for required features, fake purchases, empty panels, or client-validated currency.
5. **Safe networking.** Server authoritative for Fear and every collectible, income, spawn, roll, room quality, shop and premium grant. Clients request actions and render presentation. Implement rate limiting, type/finite checks, ownership, cooldown, distance from actual avatar, transaction/idempotency and valid server state.
6. **Persistence from day one.** Save unique monster instances, slots, progression, shop-purchased assets, quests, collectibles, gifts and premium ledger with session-lock safe profiles, migrations, throttled updates, retries and isolated Studio testing saves.
7. **Legal/original IP.** Do not copy creepypasta-specific imagery, Pixar/Poppy Playtime/Sonic characters, sound files or meshes. The source reference names are inspiration only. Create the **42 ORIGINAL roster species specified** in the design bible, not recognizable lookalikes.
8. **All platform handling.** Desktop E key, mobile contextual interaction and gamepad navigation, adaptable UI, accessible contrast, mild scare controls, low graphics mode, no jump-scare dependence. Gameplay appropriate for the content maturity level actually disclosed by the owner.
9. **Accurate monetization.** Paid random content and indirect Robux-funded randomized outcomes require actual final item probability disclosures and per-user eligibility as described in current Roblox policy. Default premium products are deterministic. Never invent gamepass, product or asset IDs. Use Roblox APIs actually supported in the current SDK. Gifting a benefit is not the same as transferring gamepass ownership.
10. **Don't stop at a pretty map.** The finished game needs actual monster earnings, random guest-room tiers, inventories, eggs, fusion, mutation, five-minute shop, trackers, rebirth floors, tutorial, UI, quests, events, saves and monetization guards. Follow the phases until all feasible work is implemented; list any real blockers precisely.

## C. Required implementation structure

Create an organized experience using these folders or adapt an existing higher-quality Rojo architecture. Use one GameConfig with separate `Definitions` and `BalancedTuning`, all probability tables validated at startup.

```text
ReplicatedStorage/
  Shared/
    GameConfig.luau
    MonsterDefinitions.luau
    EggDefinitions.luau
    AccessoryDefinitions.luau
    FloorAndRoomDefinitions.luau
    QuestAndEventDefinitions.luau
    Calculators.luau                 # pure payout formulas, timing/rounding
    Validation.luau                  # validate 100% probabilities, ID references, bounds
    NetworkSchema.luau
  Remotes/                           # exact typed remote channels
  ClientAssets/                      # licensed/creator-owned models, animation refs, icons
ServerScriptService/
  Bootstrap.server.luau
  Services/
    ProfileService.luau
    EconomyService.luau
    PlotService.luau
    RoomService.luau
    MonsterService.luau
    InventoryService.luau
    EggService.luau
    ScareService.luau
    ManualScareService.luau
    MarketService.luau
    AccessoryService.luau
    FusionService.luau
    MutationService.luau
    TrackerService.luau
    RebirthService.luau
    MuseumService.luau
    QuestService.luau
    EventService.luau
    DecorService.luau
    MonetizationService.luau
    GiftService.luau
    SettingsService.luau
    SecurityService.luau
ServerStorage/
  Templates/
    MonsterRigs; GuestRigs; RoomModules; PlotModules; VFX
StarterPlayer/StarterPlayerScripts/
  ClientBootstrap.client.luau
  Controllers/
    HUDController, InventoryController, EggController,
    MarketController, PlotAndCaseController, ScareFXController,
    ManualScareController, TrackerController, MuseumController,
    QuestController, EventController, DecorController,
    TutorialController, RebirthController, SettingsController
StarterGui/
  UI/                                # screens, templates, scaling constraints
Workspace/
  Moonfall/                          # plaza, destinations, path and scenery
  PlotSlots/                         # 8 distinct physical claim slots
  WorldInteractions/
```

**State machines** to implement, rather than simultaneous loose scripts:

- `Plot`: Unclaimed → Claimed(ownerUserId, serverSlotId) → Released. Rehydrate claimed plot from *owner's saved template state*, not last occupant's assets.
- `Room`: Locked | Sleeping → Scaring → PayingCommitted → Resetting → Sleeping; exit/pickup cancels invalid future payout.
- `Case`: Empty | Occupied(monsterUuid); 0/1 active monster and 0/1 attached accessory; no temporary duplicate assignments.
- `Hatch`: Preview/eligible → Requested → ServerDebited+Awarded → Notify → Animation, with one outcome and one charge per unique action.
- `Market`: StockEpoch → ValidatedPurchase → Reserved → Debited+Awarded → Acknowledged; personal quantity per epoch.
- `Fusion`: SelectedValidInputs → Confirmed → AtomicConsume+Create → OutputSaved → UIUpdate.
- `Mutation`: ValidatedMonster+Fragments → DeterministicApply → LedgerSaved.
- `Dig`: AvailableTracker → ReservedPersonalDig → Located → ClaimedAndEggGranted → Closed; persist unfinished reservations.
- `Rebirth`: Eligibility → Confirmed → AtomicWalletSpend+Progression → RoomCreated → UIUpdated.
- `Tutorial`: server-validated step proofs → idempotent reward flags → completion; rejoin resumes without duplicating egg/box.
- `Premium`: receipt pending → durable entitlement grant → dedup ledger → final acknowledged transaction.

**Rendering/performance:** Use a shared server scheduler or batched time manager instead of a Heartbeat connection for every monster. Avoid replicating continuous per-frame income ticks; grant only completed cycles and send periodic summarized HUD updates. Move background animations to the client when they cannot impact payouts. Reuse room templates and assets; precompile distance LOD; keep UI 30–60 FPS on entry mobile devices.

### D. Required real output at each phase

Each phase deliver: (1) created/modified files and Roblox paths, (2) real working implementation description, (3) major assumptions and configurable values, (4) concrete manual test steps for a human to run in Studio, (5) known limitations with exact blockers, (6) next phase integration notes. **Continue to the next phase without waiting for approval** if tools/time allow. If necessary, deliver an importable Rojo structure rather than abandoning the work.

Use the companion phase guide for step-by-step delivery, but this file is self-contained. Do not skip to microtransactions before the basic core loop is polished. Follow the full design bible exactly for map locations, 42 monsters, eggs, stock, UI screens, progression, cosmetics and monetization table.

### E. Completion requirements — actual end-to-end evidence

1. A fresh player joins and sees Moonfall Plaza plus **eight unclaimed plots**. They claim one. Guests cannot own/use another person's case.
2. Their plot materializes 3 usable rooms with 3 visibly locked bays. A case is **left** and its window **right** from both sides of aisle. Bedrooms are large with dim nightlights.
3. Tutorial arrows and highlighted world props lead to 100-base manual scare, free tutorial egg voucher with EXACT 80 Epic / 20 Legendary table, resulting inventory item, manual placement and observable real first passive scare payout.
4. Once-only FREE Rare accessory box awarded, opened and physically equipped to a case; income changes by the shown multiplier. Replaying/rejoining grants nothing twice.
5. At least one functional original monster per main rarity performs an appropriate and correctly timed scare animation; completion targets 42 original species and all 7 rarity presentations.
6. Bedroom tier reset independently rolls the exact configured 100% table; payout respects tier including GOD ×16. Can reliably test GOD via *test-only controlled RNG*, never production player remote.
7. Starter/Creepy/Moon/Haunted/Nightmare eggs show full possible outcomes+odds, cost exactly Fear, and create unique saved inventory instances. Tutorial and Buried eggs use their own tables.
8. Player fills all three starter cases and sees income from each, can remove/place safely, favoriting blocks fusion, and double-clicks cannot duplicate monsters.
9. Fuse 4 Normal → Large, 3 Large → Mega, 3 Mega → MASSIVE; data and sizing persist after rejoin.
10. Original 5 mutations have distinct visuals, multipliers and a deterministic recipe; mutation/size and accessory multiplier formula is exact and inspectable.
11. Market changes on true 300-second schedule, rarity and stock logic works, bought items persist, personal stock quantities decrement, server rejects stale purchases.
12. Tracker leads to valid safe dig point, only owner can claim egg, and rejoin resumes a pending expedition.
13. Rebirth price is clear, server funds correctly deducted, one new room opens each time and previous assets stay; floor 2 shell revealed after room 6 and room 7 works.
14. Map has the 8 plots, Hatchery, Market, Forge, Observatory, Museum, Hall of Rebirth, Cemetery, Woods, Playground and Clocktower, with original decorative assets and navigable paths.
15. Quest board, index rewards, small events, cosmetic room customization and player tours provide actual active tasks while rooms keep earning.
16. Gamepass UI is not fake; disabled unavailable product IDs do not purchase. Premium entitlements only granted by supported verified APIs and are still present after rejoin.
17. The game is playable on desktop, mobile and gamepad, with reduced-scare settings and proper safe areas.
18. Test two players concurrently; verify different plot ownership, server-authoritative income, no trading, no griefing, no room duplication and no live production data used by Studio test.
19. Stress 8 simultaneous full plots, fast teleports, reconnects mid-hatch, rapid repeat remotes, and partial save failures without duplicated Fear/monsters/paid items.
20. Produce a final project manifest, test checklist, known limitation list, content-to-asset map and a packaging/publishing manual. Don't claim publication or completed production assets without actual project access.

---

# F. FULL PRODUCT SPECIFICATION — THIS IS THE SOURCE TO IMPLEMENT

# SCARE SIM — ULTIMATE GAME DESIGN BIBLE

**Version:** Expanded Creative Blueprint v2.0 • **Intended platform:** Roblox (Luau / Roblox Studio) • **Design status:** Full proposed release design, **not an implemented game**.

> **Source legend:** **[ORIGINAL]** = directly supported by the supplied 21-note Obsidian vault. **[EXPANDED]** = creative addition made to complete/improve the design. **[DEFAULT / TUNE]** = proposed starting values that must be playtested, not facts previously decided by the creator. A coding agent should implement the specification, but preserve these distinctions for future edits.

## 1. Executive vision — what Scare Sim is

**Tagline:** *Collect the monsters. Run the scares. Build the weirdest haunted attraction in Moonfall.*

A colorful, slightly unsettling but non-graphic, spooky-cute multiplayer collection/tycoon for eight Roblox players per server. Every player claims an empty plot in the Halloween town of **Moonfall** and develops an ever-taller corridor of bedrooms. Each bedroom has a window where visitors can see a sleepy guest and a glass case where its one assigned monster sits. Monsters perform personalized automatic scares, generating **Fear** on validated scare completion. Fear finances eggs, rotating accessory boxes, exploration tools, rebirths and upgrades. The game works as a relaxing idle collector, but active players can manually scare, investigate the town, dig up hidden eggs, complete quests and join cooperative midnight events.

### Product pillars

1. **The scare is the spectacle.** The bedroom reaction, unique animation, transparent case, numbers popping out, and surprising room-tier reveal are more memorable than a generic conveyor belt of currency.
2. **Every monster matters.** Original silhouettes, distinctive scare acting, a readable rarity, fixed baseline earning rate, mutations, sizes, and index entries create collection attachment.
3. **Short-term activity + long-term prestige.** A player always has a clear next egg, free quest, rotating shop, accessory, fusion, room unlock or cosmetic collection goal.
4. **An attractive social map.** Easy-to-read hub, eight visitable plots, dramatic two-story-plus silhouettes, and separate adventure zones. Multiplayer is friendly sightseeing rather than theft.
5. **Respectful, transparent progression.** The free path reaches every main loop. Paid products are primarily time-savers, cosmetic options or guaranteed rewards; no surprise paid outcomes or coercive popups.

### 60-second pitch

Spawn in a bright, haunted night town. Claim a plot. Sneak through a crawl hole and pull a manual scare for your first Fear. Hatch a monster and place it in your glass case next to a bedroom. Watch your monster's unique animation surprise a sleeping guest; the bedroom rerolls to Normal/Silver/Gold/Platinum/Diamond/GOD and pays its exact boosted Fear amount. Use income to buy better eggs, rare accessory boxes, monster trackers and upgrades. Fuse 4 of a species to Large, 3 Large to Mega and 3 Mega to MASSIVE. Hunt mutations, grow to six bedrooms, rebirth for multipliers and additional floors, then decorate your horror hotel and show friends your collection.

### Strong source-backed rules not to accidentally change

- **[ORIGINAL]** Fear is the main currency. One monster per bedroom. Hatching puts the monster in **saved inventory** first, not automatically in a case.
- **[ORIGINAL]** 8 players/server; plots are claimable and empty before being claimed; guests can roam into other plots, **but no trading**. Gifting premium packs/benefits is envisioned.
- **[ORIGINAL]** Start at **3 bedrooms**. Each rebirth adds **one bedroom** and a Fear multiplier. Each floor holds 6 rooms, **three left and three right**; after the first six unlock a new floor becomes visible.
- **[ORIGINAL]** Facing any bedroom from the aisle, the **glass monster case is on its LEFT**, the bedroom viewing **window on its RIGHT**. Enlarge bedrooms; keep dim nightlights; hide the spawn pad. Show monster name, its rarity as a word, and Fear/scare under the display.
- **[ORIGINAL]** Monster rarities are Common, Rare, Epic, Legendary, Mythic, SPOOKY, plus a more elusive Secret category. Each main rarity has its original cycle speed and guaranteed payout band (Section 6).
- **[ORIGINAL]** Size fusion: **4 Normal → Large; 3 Large → Mega; 3 Mega → MASSIVE**, with subtle mesh-size growth.
- **[ORIGINAL]** Mutations: **Golden, Haunted, Creepy, Cursed, UnHoly**.
- **[ORIGINAL]** Bedroom rolls and multipliers from the vault appear in Section 7, including an ambiguous GOD odds notation.
- **[ORIGINAL]** A **300-second rotating shop** sells limited accessory boxes (Rare, Epic, Legendary, Secret) and very rare hidden-egg trackers for Fear.
- **[ORIGINAL]** Manual scaring uses a crawl hole with starting payout **100 Fear**, scaling with rebirths.
- **[ORIGINAL]** Forced highlighted-arrow tutorial includes a special **80% Epic / 20% Legendary egg**, then a once-only **FREE Rare accessory box**.
- **[ORIGINAL]** Playtest notes mention a temporary monster called **Jeff** with a Blender scare animation; the referenced asset is not in the supplied archive. Do not silently assume it is present. Replace any recognizably copyrighted character for publication with an independently designed monster.

## 2. Comparison-derived improvements — borrow the logic, not the copyrighted content

| Comparable Roblox genre/game | Design lesson | Original Scare Sim implementation |
|---|---|---|
| Pet Simulator-style collectors | Egg reveals, collecting index, rarity chase, clear upgrades | Detailed monster index, region-specific egg machines, fusion and collection milestones |
| Grow a Garden-style economies | Five-minute shop check-ins, scarce rotating offers, mutations, ambient world events | Moonfall Black Market stock and scheduled weather that changes the attraction's atmosphere |
| Steal a Brainrot-style bases | Passive workers visibly earn, rebirth expands slots, friends admire bases | Case workers with unique scares, prestige floors and public plot tours **without stealing/trading** |
| Theme Park Tycoon-style creativity | Personal venues express owners' style | Bedroom themes, foyer/corridor decor, signs, floors, lighting and cosmetic collection rewards |
| Light, accessible Roblox horror | Strong audio/visual identity, curiosity and surprises | Cartoon scare scenes, secrets, a reduced-scare option, and exploration that never requires gore |

**Do not recreate another game's exact assets, monsters, branded names, UI, layout or business presentation.** Keep the useful loops and make the content original.

## 3. Map design — Moonfall at launch

### 3.1 Overworld geography [EXPANDED]

**Theme:** Roblox-studded low-poly architecture, periwinkle/bright-blue owned platforms, glossy pink carpet center aisles, purple-black twilight sky, pumpkin-orange warm accents, bluish moonlight, ghostly pale teal particles. Warm, inviting enough for children and stylized enough for social screenshots. No hyper-real blood, realistic torture or harmful content.

**Proposed world footprint:** ~1,250 × 1,500 studs, adjustable for StreamingEnabled. **Proposed plot footprint:** ~235 × 268 studs; each plot's first floor uses two facing rows of 3 bedroom bays separated by a pink-carpet aisle. Treat dimensions as initial prototyping targets, not strict building limits. Maintain room viewing sightlines and prevent plots clipping when floors rise.

**Overworld layout:** 8 plots, four along the western side of a central lantern-lit avenue and four along the eastern side. All plot entrances face toward the avenue. A large central roundabout is **Moonfall Plaza**. A beginner can reach each shop with an obvious sign and in-world path; advanced zones branch from the northern, southern and side roads. Use consistent map signage and a tap-to-waypoint map menu. Plot entrances show owner display name, total floors, featured monster, and optional public tour sign.

```text
                            [CLOCKTOWER RUINS]
                                   |  north road
     [PLOT W1]   |                  |                | [PLOT E1]
     [PLOT W2]   |          [MOONFALL PLAZA]        | [PLOT E2]
     [PLOT W3]   |    eggs / shop / fusion / index  | [PLOT E3]
     [PLOT W4]   |                  |                | [PLOT E4]
                           southern festival road
                                  / \
                    [PUMPKIN CEMETERY] [MISTY WOODS]
                                  |
                         [ABANDONED PLAYGROUND]
```

**Traversal target:** fresh spawn to claim station 10–20 seconds; claimed plot to shop 15–25 seconds on foot; outer adventure zones 20–45 seconds. These are intended UX targets to verify in playtests, not measured times. Add free unlocked map teleport pads after visiting each destination once, so advanced players never spend most of their session walking.

### 3.2 Location-by-location content

| Location | Look and landmark | Purpose | Hidden content |
|---|---|---|---|
| **Moonfall Plaza** | Giant smiling moon statue above an animated fountain; glowing stone path; hanging lanterns | Neutral spawn, directional signs, socializing, event timer, screenshot backdrop | Collect 5 moon shards for an index cosmetic |
| **The Hatchery** | Row of themed egg incubators, glass hatch preview chambers, odds board | Purchase Fear eggs, preview contents and individual chances, skip/replay cosmetic animation | First egg mural unveils a lore clue |
| **The Midnight Market** | Witchy market stall with a giant real-time 05:00 clock and movable shelves | Rotating accessory boxes, trackers, occasional cosmetic props | Traveling merchant once per hour, always with a non-random offer |
| **Fusion Forge** | Purple-glowing gear rings, interactive size pedestal | 4→1 / 3→1 fusion, preview resulting stats; protect/favorite locks | Unique sound/visual for MASSIVE crafting |
| **Mutation Observatory** | Dome, telescope, floating green runes and glass tubes | Inspect mutations; earn-ahead nonrandom mutation crafting pathway | Temporary weather event indicator |
| **Book of Frights Museum** | Gallery of silhouette portraits and moving case dioramas | Collection index, lore, milestone rewards, comparison tools | Unlock gallery wing after index milestones |
| **Hall of Rebirth** | Spiral moon staircase and giant portal at plaza rear | Explain cost, preview next bedroom/floor and confirm rebirth | History wall of player's prestige milestones |
| **Pumpkin Cemetery** | Cartoon tombstones, smiling jack-o-lanterns, glowing dirt | Low-level tracker dig sites, daily pumpkin hunt, quiet soundscape | Secret pumpkin door/cosmetic |
| **Misty Woods** | Twisted blue trees, fireflies, winding mushrooms, fog | Mid-level tracker search and photo quests | Ancient stump puzzle |
| **Abandoned Playground** | Silly, squeaky carousel and deserted playsets (not graphic) | Active scare minigame events, later tracker locations | Collect clockwork parts for a free decor set |
| **Clocktower Ruins** | Huge tilting clock and floating gears above town | High-level exploration quest chain, occasional late-game hidden eggs | Weekly nonrandom mystery quest |
| **Eight player plots** | Bright blue base slab, pink carpet, readable lit labels, increasingly tall hotel | Core passive earnings, public visits, upgrades and decorating | Player-selectable lobby theme and featured display |

### 3.3 Plot floor plan (especially important)

**Every floor:** six bays total. The center walking aisle is ~24 studs wide, with a pink carpet. Bays each provide a **monster display pedestal/case** to the left and **bedroom window** to the right of the room's frontage **as seen from the aisle**. Do not accidentally invert the visual relationship for the rooms on the opposing side. Recommended bay envelope ~66–72 studs longitudinally and ~85–96 studs deep; bedroom interior about twice the width/depth of the earliest playtest model. Put doors/maintenance access off the visitor route so the display window remains legible. Keep physical character paths at least 8 studs clear and ensure glass reflections never hide the monster.

**First floor room theming [EXPANDED]:** Room 1 *Moonlight Nursery* (gentle stars), Room 2 *Rainy Attic* (roof taps), Room 3 *Toybox Dreams* (jumpy shadows), Room 4 *Mirror Room* (reflection tricks), Room 5 *Midnight Train* (tiny toy railway), Room 6 *Clockwork Bedroom* (stuttering clock). Every room has a sleeping guest NPC, a bed and dim nightlight, reactive props, a visible window, a left-side glass case and a crawl access point where compatible. Guest variants are original stylized human/animal avatars and pajama-wearing critters with comedic, nonviolent reactions; optionally prefer animal/puppet guests to keep the rating mild.

**Upper floors [EXPANDED]:** Floor 2 *The Forgotten Hotel* (dusty purple, talking wallpaper); Floor 3 *Dream Observatory* (cosmic bedrooms and star windows); Floor 4 *Cursed Carnival* (toy clown decor, animated curtains); Floor 5 *Storm Manor* (lightning silhouettes); Floor 6+ *The Rift Suites* (unusual geometry). Each continues the rule of 3 bedrooms left/3 right. Floor skins are visual; the random rolled room quality tier remains separate from floor theme.

**Unlock visibility:** start with 3 active rooms, 3 clearly locked outlines on Floor 1. Rebirths 1,2,3 unlock rooms 4,5,6. Immediately after room 6 is unlocked, an upper-floor shell/stair indicator becomes visible. Rebirth 4 unlocks room 7 (Floor 2, Room 1). Repeat one extra active room per rebirth. The player never loses unlocked room slots on another server. Build at least 3 actual floors for the initial release, with expandable floor templates; the design supports 6 floors as content grows.

### 3.4 Environmental storytelling and aesthetic quality

Use short in-world dialogue from friendly town NPCs: **Auntie Gloom** (Hatchery), **Mr. Rattle** (Market), **Professor Moth** (Mutation Observatory), **Bellkeeper** (Rebirth Hall), **Mina the Mapmaker** (navigation). Let each have a personality and optional 1–2-line lore snippets. Place a whimsical town-wide clock that triggers a Midnight Rush event. Add a music mix with percussion soft enough for idle play. All effects have lower-intensity alternatives. Objects should have LOD and collision simplification.

## 4. The complete player journey

### Session 0–3 minutes: acquisition

Player arrives at neutral hidden spawn in Moonfall Plaza, sees a short nonblocking introduction, then giant arrows lead to the claim station. On the unclaimed plot only the exterior ground/base and claim beacon exist—**not an already built, owned attraction**. Claimed plot materializes its level-appropriate floor layout. Tutorial leads player to crawl into a room, perform a safe comedic scare for **100 Fear base**, and receive a **one-use tutorial egg voucher** (avoids grind-soft-lock). The special tutorial egg is 80% Epic/20% Legendary, not the normal Starter egg. Hatched monster is added to inventory and selected. Player places it using E/tap at owned glass case. First real automatic scare awards Fear; the guest resets and the bedroom quality rerolls. Market NPC awards exactly one free Rare accessory box, player opens and equips it and sees Fear/scare improve. UI celebrates tutorial completion.

### Session 3–15 minutes: multiple workers

Player hatches inexpensive Starter eggs, fills the 3 starting rooms, learns the rotating shop, discovers a new species, checks the Book of Frights, and completes 1–2 simple quests. A first rebirth cost indicator gives a finite target; player optionally performs manual scares with timing bonuses while passive scares operate. First rebirth adds a fourth room and a multiplier without wiping the hard-earned monster collection.

### Session 15–60 minutes: personal strategy

Player focuses on rare monsters vs many cheaper monsters, chooses accessory allocation, discovers mutation variants, tries a fusion, explores the cemetery and uses a tracker if one is obtained. They reach sixth room and uncover the second-floor build shell. A small cooperative event rewards participation instead of speed-clicking. Their plot starts looking distinct from other players' plots.

### Long-term sessions

Prestige new floors, fill the index with variants, craft MASSIVE monsters, unlock museum exhibits, collect room skins, earn weekly event cosmetics and complete exploration secrets. Late-game depth comes from **species collection + size + mutation + room quality + cases + themes + extra floors**, not endless arbitrary currencies or harsh rebirth deletion.

## 5. Core interaction model and controls

| Action | PC | Touch | Gamepad | Server rules |
|---|---|---|---|---|
| Claim plot | E on claim beacon | large Claim prompt | interact | player owns no other plot; beacon unclaimed |
| Manual scare | E in crawl-hole then short timing interaction | crawl/scare buttons | interact | owned or designated tutorial room; distance and cooldown validated |
| Hatch egg | E on egg machine or HUD Egg tab | tap egg/confirm | interact/confirm | wallet/eligibility/inventory validated; odds disclosed |
| Place/remove monster | equip hotbar entry and E at glass case | select then case Place/Remove | interact | own plot; empty/unlocked slot; instance not elsewhere |
| Inspect case | click case/name badge | tap badge | interact/options | any visitor may inspect; only owner edits |
| Shop purchase | E/Shop HUD, click buy | tap | UI navigation | stock, affordability, and 300s rotation validated |
| Tracker search/dig | activate tracker then E near mound | arrow + Dig | interact | target owner, position and completion validated |
| Fuse/mutate | kiosk or HUD with confirmation | touch UI | UI navigation | must own eligible materials; atomic transaction |
| Rebirth | Hall/Rebirth HUD, confirmation | touch UI | UI navigation | required Fear, rate limit, plot progression valid |
| Teleport to visited location | Map button | Map button | map radial | only discovered destination, no exploit teleport into locked spots |

**Camera:** default Roblox third person; gentle focus-in on individual scares if explicitly enabled, never forced for visitors; disable camera jolts in low-intensity setting. Full responsive interface and gamepad focus rules. Interaction prompts should show *why* a slot is locked, not just fail silently.

## 6. Monsters — economy and full launch roster

### 6.1 Core monster rules [ORIGINAL unless starred]

- Monsters are hired workers that perform a unique scare animation over and over. **One monster per room**. Monster rarity determines a **fixed per-scare Fear amount within the source band's range** and the base scare period. Each instance retains immutable species ID and granted base value. A monster always pays its stated value when a successful scare completes, multiplied by listed modifiers—not a random amount per scare.
- Rarity labels include explicit text as well as colors; Secret is exceptionally rare. Each monster can be **favorited/locked [EXPANDED]** to prevent accidental fusion or sell actions.
- A collection index tracks first discovery of each species. A visible showcase presents name, rarity, final payout per scare, scare duration, mutation and size.
- **Secret frequency and base payout were unspecified**; the marked values below are **suggested defaults**.

| Rarity | Original seconds/scare | Original guaranteed base range per scare | Proposed signature treatment |
|---|---:|---:|---|
| Common | 15 | 25–400 Fear | bright, simple expressive animations |
| Rare | 10 | 200–800 Fear | comic shadow interactions |
| Epic | 8 | 400–1,500 Fear | more theatrical FX |
| Legendary | 5 | 800–2,500 Fear | layered props and distinct stingers |
| Mythic | 5 | 1,200–5,000 Fear | dramatic large-scale room illusion |
| SPOOKY | 3.5 | 8,000–15,000 Fear | whole-bedroom visual sequences |
| Secret | **3*** | **20,000–35,000*** | very rare full-scene effects |

### 6.2 Entire original launch roster — 42 unique species [EXPANDED]

Each entry has an actual *conceptual art direction*, a starter base Fear value and a distinct scare action. **Do not copy characters from Roblox games, Poppy Playtime, Pixar, Sonic or creepypasta artworks.** The vault lists copyrighted references as inspiration and one early prototype; these new characters are independent, not close lookalikes.

| Monster | Tier | Base Fear/scare | Identity + signature scare |
|---|---|---:|---|
| **Sock Goblin** | Common | 50 | Tiny stitched gremlin with runaway socks; **sniffs sock then springs from drawer** |
| **Dust Bopper** | Common | 85 | Dustball creature with jelly legs; **bounces out from under bed** |
| **Boo Balloon** | Common | 125 | Floating balloon ghost with painted face; **inflates until its face pops into view** |
| **Puddle Imp** | Common | 165 | Rain puddle imp in boots; **slides out of a puddle to squeak** |
| **Pumpkin Peeker** | Common | 210 | Miniature animated jack-o-lantern; **opens glowing eyes from a shelf** |
| **Curtain Crawler** | Common | 270 | Friendly six-armed cloth creature; **swings out of curtains** |
| **Wobble Wisp** | Common | 335 | Neon flame orb with drowsy eyes; **splits into tiny ghost sparks** |
| **Mothling** | Common | 390 | Big moth with moon wings and antennae; **flutters across the nightlight** |
| **Grinling Hound** | Rare | 225 | Patchwork hound with a crooked lantern smile; **pokes a harmless shadow-paw in the window** |
| **Lantern Jaw** | Rare | 300 | Walking lantern with chatterbox teeth; **clacks its hinged lantern mouth** |
| **Shiver Jack** | Rare | 365 | Tall scarf-wearing scarecrow prankster; **leans sideways out of wardrobe** |
| **Clockwork Clown** | Rare | 440 | Wind-up toy clown with square spring limbs; **spins a jack-in-the-box** |
| **Blanket Mimic** | Rare | 525 | Blanket with bright glowing button eyes; **forms a giant blanket puppet** |
| **Paper Shadow** | Rare | 615 | Origami silhouette with impossible folds; **unfolds across the wall** |
| **Mossy Howler** | Rare | 700 | Forest goblin with a bell collar; **howls into a floating teacup** |
| **Sneakwood** | Rare | 790 | Root creature with wooden mask; **sprouts from a bedpost** |
| **Plush Prowler** | Epic | 450 | Round-shouldered plush beast with mismatched colors; **extends springy mitten hands** |
| **Dream Snatcher** | Epic | 590 | Sleepy star-cat with a tiny crescent tail; **leaps through dream clouds** |
| **Goggle Gremlin** | Epic | 755 | Triple-eyed mechanical goblin with copper goggles; **flashes a surprise telescope face** |
| **Lullaby Lurker** | Epic | 910 | Musical marionette with a bell-shaped hood; **plays a quirky two-note music-box riff** |
| **Mirror Minnow** | Epic | 1,090 | Floating aquarium-fish ghost with mirror scales; **appears in a mirrored reflection** |
| **Fuzzy Fury** | Epic | 1,270 | Huge puffy monster with tiny feet and colorful horns; **unfurls enormous fluffy mane** |
| **Hallway Marionette** | Epic | 1,480 | Porcelain hallway puppet on glowing strings; **tiptoes upside-down on strings** |
| **Velvet Beast** | Legendary | 850 | Horned velvet guardian with embroidered moon patches; **opens a stage curtain revealing glowing eyes** |
| **Moonbite Mutt** | Legendary | 1,125 | Spectral long-legged wolf with crystal collar; **silhouette crosses the full moon** |
| **Jester of Static** | Legendary | 1,460 | Television-faced royal jester; **switches channels to reveal a comic face** |
| **Crowned Candle** | Legendary | 1,800 | Wax creature wearing a floating crown; **snuffs lights then relights every candle** |
| **Nightmare Astronaut** | Legendary | 2,150 | Patchwork astronaut filled with stars; **taps helmet from behind a window** |
| **Static Phantom** | Legendary | 2,475 | Ribbonlike phantom of crackling purple static; **separates into dancing afterimages** |
| **The Wardrobe King** | Mythic | 1,400 | Regal cedar wardrobe with many little doors; **opens a hundred harmless glowing doors** |
| **The Starved Clock** | Mythic | 2,050 | Animated grandfather clock made of floating numbers; **rewinds time then chimes at wrong hour** |
| **Madame Eclipse** | Mythic | 2,950 | Masked celestial showwoman in crescent cape; **casts an eclipse shadow puppet** |
| **Dread Leviathan** | Mythic | 3,850 | Long ribbon-serpent made of storm clouds; **swims through a cloud wall** |
| **The Pale Conductor** | Mythic | 4,900 | Ghostly orchestra conductor with spiderlike baton; **conducts a silent ghost choir** |
| **The Hollow Monarch** | SPOOKY | 8,200 | Towering hollow porcelain monarch with orbiting masks; **makes every mask turn toward the guest** |
| **The Night Parade** | SPOOKY | 9,700 | One collectible monster: a tiny ghost marching band; **band marches across the ceiling** |
| **The Mourning Bell** | SPOOKY | 11,200 | Floating gothic bell with cartoon eye; **releases a soft ripple of shadow** |
| **The Candle Eater** | SPOOKY | 13,200 | Lantern-winged moth giant with a hollow mask; **inhales all room candle flames** |
| **The Inkwell Witch** | SPOOKY | 14,850 | Spinning ink spirit in paper dress; **paints a door that briefly opens** |
| **Zero Hour** | Secret | 21,000 | Transparent clock-shaped anomaly, no copyrighted analogues; **stops all room clocks for one beat** |
| **The Unseen Host** | Secret | 26,500 | Empty tuxedo with floating invitation cards; **bows and reveals impossible backstage doorway** |
| **The Last Lantern** | Secret | 34,000 | Ancient living lighthouse lantern with constellation eyes; **beams a moving starfield through the room** |

**Release art plan [DEFAULT / TUNE]:** 42 are a *content target*, not a claim that 42 3D models currently exist. To avoid placeholder forever, produce a playable first wave of 12 polished monsters and scale to 42 before a full-content release. Every entry needs: low-poly original mesh; texture/material palette; single primary idle; scare animation; case pose; reveal card; rarity VFX; single clear audio stinger; silhouette index icon; mobile LOD. Use a small coherent rig family to save animation time, but no two monsters should share an identical visible scare without variation.

### 6.3 Monster personality and ability perks [EXPANDED, optional horizontal depth]

Every species has a **Scare Style** badge: Peek, Prank, Shadow, Sound, Dream, or Illusion. The badge changes the scare animation timing, audio and cosmetic room reaction, **not** the guaranteed base Fear payout. A future optional **Scare Combo** system can give a modest +3% bonus (max +9%) when consecutive *adjacent* rooms use three different styles; no exclusive pay-only styles, and keep the bonus separately displayed. Launch can ship without this perk if it adds complexity before the first three rooms work.

### 6.4 Mutations (named from vault, bonuses proposed)

| Mutation | Payout multiplier | Original visible difference | Acquisition [DEFAULT / TUNE] |
|---|---:|---|---|
| Normal/no mutation | ×1.00 | base appearance | all eggs |
| Golden | ×1.20 | warm gold trims and sparkles | optional rare egg result / Mutation Lab |
| Haunted | ×1.40 | hovering wisps, pale-blue afterimages | optional rare egg result / event quest |
| Creepy | ×1.65 | shadow ribbon aura with unusual eyes | optional rare egg result / Mutation Lab |
| Cursed | ×2.00 | violet glyphs, shifting mist | high-level eggs / deterministic crafting |
| UnHoly | ×2.50 | dramatic cracked-starlight halo; nonreligious stylization | ultra-rare eggs / late-game earned recipe |

**Safeguards:** one permanent mutation per monster, one temporary world-event aura at a time, and separate slots for size/accessory. No overwriting or accidental loss. Permanent mutations are preserved in fusion only if every ingredient has the same mutation; the forge shows this rule before accepting materials. Mutation Lab is a **guaranteed, non-random** alternative unlocked via quests and nonpurchasable `Moon Fragments` (crafting material, not a second wallet). Earn Moon Fragments through exploration/quest milestones; numbers are provisional: Golden 5, Haunted 10, Creepy 18, Cursed 30, UnHoly 55; use actual measured accumulation before release. Apply a mutation only to Normal-state monsters or perform a clearly priced **replace** operation; never secretly erase an expensive mutation.

### 6.5 Fusion (exact recipe from vault)

| Result | Inputs | Equivalent base normal monsters | Visual model scale* | Proposed size payout |
|---|---|---:|---:|---:|
| Normal | hatched | 1 | ×1.00 | ×1.00 |
| **Large** | 4 Normal, same species and mutation | 4 | ×1.07 | ×1.50 |
| **Mega** | 3 Large, same species and mutation | 12 | ×1.13 | ×2.25 |
| **MASSIVE** | 3 Mega, same species and mutation | 36 | ×1.20 | ×3.50 |

\*Scale changes are illustrative, and intentionally small enough to fit every glass case. Badge text, particle ring and idle pose convey bigger status more than geometric size. Fusing consumes ingredients atomically; results are new owned instances with their own unique ID, inherited mutation, size and species. Case-equipped/locked monsters cannot be consumed. Full confirmation lists all IDs/materials and cost (default **0 Fear**, because original notes only state duplicate requirements).

## 7. Bedroom tiers — exactly preserve original rarity idea

The *guest bedroom's quality* is rolled server-side **after each successful scare, for the next guest**. The roll changes the room's trim, nightlight, visible quality name and Fear multiplier for the next scare. The player can watch it through the right-side window. This is independent of monster rarity and independent of floor decor theme.

| Bedroom tier | Multiplier | Probability from notes / interpretation | Visible room treatment |
|---|---:|---:|---|
| Normal | ×1.00 | **73.949%** remainder | calm blue nighttime decor |
| Silver | ×1.20 | **20%** | silver star decals and cold lamp |
| Gold | ×1.50 | **5%** | warm glowing picture frames |
| Platinum | ×2.00 | **1%** | lavender crystal trim |
| Diamond | ×4.00 | **0.05%** | bright cyan celestial windows |
| GOD | ×16.00 | **0.001%** **[assumption]** | cinematic celestial constellation for 2–3 sec |

**Ambiguity:** the Obsidian note writes GOD `.001` without `%`. This plan interprets it as **0.001%** so the table totals 100.000%; confirm before shipping. This is *not* a reliable claim about what the creator originally meant. Do not offer paid rerolling of bedroom tiers. Run deterministic server-side RNG using precise weights and display current tier. A timed bonus, VIP, luck pass or weather cannot secretly rewrite these room probabilities.

### Room scene loop

1. Room state: `Sleeping`. The case has one active owned monster. Guest idles with low nightlight.
2. Timer advances according to *that monster's rarity* after placement; a projected payout is displayed; monster scare begins only if still placed and the room is active.
3. Monster performs its unique scare animation with sound. Guest startles comically (drops pillow, hides behind blanket, squeaks, etc.); watchable from the window. Reduced-scare mode uses gentle FX.
4. Server commits **one** Fear payout for this completed scare; one floating number and small progress fill. No duplicate payout on resync/rejoin.
5. Guest vanishes with a harmless poof. New guest spawns; room *rerolls* tier on the server, shows the rarity text, and restarts its timer.
6. If the monster is picked up mid-cycle, cancel/pause and do not pay for an unfinished cycle. No two scripts should award the same cycle.

**Payout formula (central config):**

```text
Automatic Fear/scare = round(
    speciesBaseFear
    × rolledBedroomTier
    × sizeMultiplier
    × permanentMutationMultiplier
    × equippedAccessoryMultiplier
    × rebirthMultiplier
    × roomUpgradeMultiplier
    × optionalStyleSynergyMultiplier
    × temporaryWorldEventMultiplier
)
```

Original concepts are species payout, room tier, size, mutation, accessory and rebirth; room upgrades, synergy and event bonus are explicitly **new optional layers** with modest caps. Show an inspect panel listing every factor. Rebirth multiplier suggested `1 + 0.25 × rebirthCount`, with a balance review after R10. Use a consistent rounding rule and cap any single phase's experimental bonuses if overflow/performance problems appear, rather than silently making player numbers incorrect. For manual scare: `round(100 × rebirthMultiplier × manualSkillBonus)` with `manualSkillBonus` in [1.0, 1.2] when players earn a perfect timing score. Keep manual distinct from automatic.

## 8. Egg economy — five regular eggs, one tutorial egg, hidden tracker eggs

All egg odds are **CONFIGURATION PROPOSALS** and must be visible before buying. For each egg, individual possible monster odds are `tierChance / eligibleSpeciesCount` unless an explicit species-weight table overrides; the UI must show **numerical odds per final species**, not only by rarity, whenever applicable under Roblox monetization rules. Paid eggs, or eggs bought with currency available for Robux, require eligibility checks and complete disclosures. **Recommended safer launch configuration: Fear is earned only through play, all standard Fear eggs are earned-only, and Robux packs have guaranteed nonrandom content.** The original note's option for premium eggs can be revisited by implementing compliant paid-random handling.

| Egg | Price (Fear)* | Tier odds (must total 100%) | Intended time |
|---|---:|---|---|
| **Starter Egg** | 500 | Common 78%, Rare 21%, Epic 1% | 0–10 min |
| **Creepy Egg** | 6,000 | Rare 65%, Epic 30%, Legendary 5% | early |
| **Moon Egg** | 60,000 | Epic 65%, Legendary 30%, Mythic 5% | early-middle |
| **Haunted Egg** | 600,000 | Legendary 65%, Mythic 33%, SPOOKY 2% | middle |
| **Nightmare Egg** | 6,000,000 | Mythic 85%, SPOOKY 14.9%, Secret 0.1% | late |
| **Tutorial Promise Egg** | one-use voucher | **Epic 80%, Legendary 20%** | tutorial only |
| **Buried Moon Egg** | earned via tracker | Mythic 85%, SPOOKY 14%, Secret 1%* | tracker adventure |

\*Design starting values. A tracker does not directly charge Robux and the rare egg is an earned reward; if trackers are ever sold for Robux or Robux-purchased currency, restrictions and odds disclosures apply to the entire acquisition chain. Set each result instance's base payout to the defined species value and then optionally roll one permanent mutation using explicitly displayed odds. **Proposed egg mutation subroll** across all standard Fear eggs: none 96.60%, Golden 2.00%, Haunted 0.90%, Creepy 0.35%, Cursed 0.13%, UnHoly 0.02% = 100%. For the tutorial egg, recommend **no mutation roll** to avoid surprising tutorial variability. If the mutation subroll and species pull combine into a paid random outcome, correctly show the joint outcomes and overall odds, not just broad totals.

**Hatch presentation:** pause to focus on the incubator, 1.5–2.5 sec skippable animation, species name, rarity text, payout/scare and mutation/size icons. Hatching is not an automatically assigned worker. Provide single hatch baseline and optional 3x hatch earned by progression; if buying auto-hatch, it still stops on inventory full, insufficient Fear or ineligible items.

**Duplicate value:** duplicates serve fusion; no forced-selling mechanic. Provide voluntary sell-for-Fear only if added after careful playtest (default OFF) because it risks deleting inputs for size progression. Favorites protected. Inventory has free starting 250 capacity, with earnable storage expansions; no permanent paywall on collection progress.

## 9. Rotating shop and accessories

**[ORIGINAL]** All non-tutorial accessory boxes are sold in the **five-minute Fear shop**; rarer stock appears less frequently. Trackers are exceptionally rare. The market must be a compelling reason to revisit, but not a punitive streak trap.

### Shop refresh rules [DEFAULT / TUNE]

- **Stock cycle:** exact `300` seconds from a server-authoritative global epoch. Show an actual synchronized countdown in market UI, HUD and physical stall clock.
- **Assortment:** 3–5 shelf slots per rotation, with Rare box always guaranteed as a useful basic purchase; 2–4 additional rolls for Epic, Legendary, Secret, and a tracker. Rarity defines stock appearance, not hidden misleading timers.
- **Limited quantity:** each offer has a **per-player allotment for that rotation** (e.g. Rare 3, Epic 2, Legendary 1, Secret 1, tracker 1). Players in different time zones/lag conditions are not punished by global first-come depletion. The **lineup** is shared and visually synchronized; inventory remaining is personal. Visually describe this as 'Your stock'.
- **Proposed price defaults:** Rare box 2,500 Fear; Epic box 30,000; Legendary box 350,000; Secret box 3,000,000; tracker 800,000. With limited income early, ensure tutorial's free Rare box makes the mechanic immediately visible.
- **Proposed shelf appearance:** Rare 100%; Epic 60%; Legendary 20%; Secret 3%; tracker 2% **per eligible shelf check**. Actual arrangement must guarantee 3–5 distinct active offers and be independently probability-tested; do not treat these independent percentages as a 100%-sum egg table.
- Reservation on server: decrement allotment + deduct Fear + grant owned item as one validated transaction. No purchase after the rotation expires and no dupes from multiple remotes.

### Accessory boxes and case slots

| Box | Example original accessory | Typical multiplier* | Identity |
|---|---|---:|---|
| Rare | Bone Charm, Squeaky Bat, Cobweb Banner, Lantern Tag | ×1.10–1.25 | small hanging case ornaments |
| Epic | Enchanted Chime, Ghost Camera, Moon Mirror, Trick Lantern | ×1.30–1.50 | animated accessories with subtle FX |
| Legendary | Clockwork Halo, Phantom Projector, Shadow Organ | ×1.60–1.85 | impressive viewing-case machinery |
| Secret | Rift Hourglass, Heart of Midnight, Living Moon | ×2.00–2.40 | elaborate rare model/FX |

\*Values are proposed starting bands, fixed per item. Accessories belong to the **display case equipment slot**, boosting the monster currently placed there. They can be moved to another owned case by unequipping. A monster removed from its case does not own the accessory (but UI can show 'last equipped'). This harmonizes the original notes which describe both monster and showcase accessory placement. **One equipped accessory per case** at launch; optional cosmetic-only ornament slots can be unlimited within performance budget. Equipping must be atomic to prevent one accessory applying to two cases. Tutorial grants exactly one free Rare box with server-side permanent once-only flag.

**Box odds [DEFAULT / TUNE]:** for a given tier, choose equally among its eligible original accessory items as configured; show each item's percentage in full. If any box can be reached with Robux-purchasable currency, it becomes paid random and needs eligibility enforcement. No direct sell of a hidden-odds random box.

## 10. Tracker expedition and exploration [ORIGINAL seed + EXPANDED details]

**Original:** Rare shop tracker guides player by arrow to a secret buried egg. **Proposed polished flow:**

1. Activate purchased Tracker from inventory. Player receives a ghostly arrow, distance meter and clue card (*"Follow the flickering lanterns beyond the old stones"*).
2. Server generates an individual dig location from a vetted node list in Pumpkin Cemetery, Misty Woods, Playground or Clocktower Ruins. Hide the specific selection from other players; show special particles only to the owner.
3. Follow compass; on approach, a faint pulse and small glowing mound appear. The arrow should never point off-map or through an impassable wall; if navigation is blocked, use waypoint hops.
4. Hold E/tap Dig for ~2 seconds, then play a short skill-less shovel/brush animation (avoid an unnecessary RNG fail state).
5. Reveal a Buried Moon Egg, return it to saved inventory and award an exploration quest completion. Hatching uses disclosed odds and a short reveal.
6. If player leaves mid-expedition, **resume the same reserved target on rejoin** rather than burning the tracker. If a marker is invalid after update, migrate to a new safe node without duplicating the reward.
7. Trackers cannot be stolen or gifted between players, and another player cannot trigger the owner's dig. Server checks actual distance and active tracker state.

**Explorer extras:** daily rotating nonrandom clue location; optional camera photo-quest (approach a landmark and tap 'Document', not external device capture); small lore collectible set; a map with unlocked nodes and observed rare encounters. Exploration must not interrupt income at a player's occupied rooms.

## 11. Manual scaring mini-game [EXPANDED wrapper, original base payout]

**Entry:** crawl-hole next to an eligible bedroom, especially for first-time players. The player controls a harmless cartoon prank—peek from wardrobe, tap a wall, wiggle a shadow puppet—and times a visible cue for a satisfying guest startle. Recommended 3–5 second mini-sequence, base **100 Fear**, optional +0/10/20% skill bonus by timing result, default **8-second server cooldown**. Rebirth scales the 100 base using the same indicated prestige multiplier. A manually scared room does **not** award an extra automatic payout from that same action; keep automatic worker and manual timing controllers distinct. If room is occupied by an automatic worker, manual action pauses/restarts safely or is restricted to dedicated vacant/tutorial rooms to avoid double award.

**Scare Streak [EXPANDED, optional]:** 5 successfully timed manual scares grant a tiny one-time 200 Fear bonus and a fun emote; streak expires after inactivity, never stacks infinitely or uses premium boosts. Could be introduced after the main loop is polished; keep it small so manual grinding does not eclipse monster collecting.

## 12. Rebirth, floors and long-term pace

**Source:** Rebirth requires enough Fear, adds one bedroom and a Fear income multiplier. **Recommended release interpretation:** pay a rising **wallet cost** but keep existing monsters, equipment, collection, unlocked rooms, purchased entitlements and plot decorations. You do **not** wipe the inventory or hotel; that would conflict with building a collector/tycoon identity. State this plainly in confirmation UI and let owner adjust if a harsher prestige model is desired.

| Rebirth being purchased | Proposed Fear cost | Unlocked bedrooms total | Revealed expansion | Permanent multiplier |
|---|---:|---:|---|---:|
| 0 (start) | — | 3 | Floor 1 rooms 1–3 | ×1.00 |
| 1 | 50,000 | 4 | Floor 1 room 4 | ×1.25 |
| 2 | 150,000 | 5 | Floor 1 room 5 | ×1.50 |
| 3 | 450,000 | 6 | Floor 1 room 6 + reveal Floor 2 shell | ×1.75 |
| 4 | 1,350,000 | 7 | Floor 2 room 1 | ×2.00 |
| 5 | 4,050,000 | 8 | Floor 2 room 2 | ×2.25 |
| 6 | 12,150,000 | 9 | Floor 2 room 3 | ×2.50 |
| 7 | 36,450,000 | 10 | Floor 2 room 4 | ×2.75 |
| 8 | 109,350,000 | 11 | Floor 2 room 5 | ×3.00 |
| 9 | 328,050,000 | 12 | Floor 2 room 6 + reveal Floor 3 | ×3.25 |

**General formula:** cost for next rebirth `50,000 × 3^(currentRebirths)`, rounded to nearest whole Fear. Total unlocked rooms `3 + rebirthCount`. For 6 rooms/floor, active floor = `ceil(unlockedRooms / 6)`. **This is provisional and needs median earning data playtests before launch**, especially after multipliers and SPOOKY pets are in circulation. Add a clearly labeled next-rebirth preview showing cost, rooms, exact wallet remaining, new multiplier and floor cosmetic.

**Optional prestige goals:** milestone cosmetics at R3 (silver foyer), R6 (animated entrance gates), R9 (clocktower banner), R15 (Rift Floor skin); never lock the first 6-room floor or regular market behind Robux.

## 13. Room upgrades and player expression [EXPANDED]

The core source has no room-upgrade tree beyond room tier, case accessory and rebirth. To add agency without undermining RNG, create three **simple permanent upgrade categories** bought with Fear and saved by stable room slot:

| Upgrade | Effect | Levels/cost | Scope/notes |
|---|---|---|---|
| **Nightlight Rig** | +2% per level to that room's payout, max +10% | 5 levels; scaling price based on first room's earning | clear visible glow; not a tier reroll |
| **Scare Soundboard** | cosmetic new reaction audio + small +2%/level payout, max +10% | 5 levels | muted variants respected |
| **Stage Props** | +2%/level payout, max +10% | 5 levels | special props show in room; no paid exclusive |

If implemented, combine upgrade bonuses as **one capped multiplier**, e.g. `1 + min(0.30, 0.02 × totalUpgradeLevels)` to avoid 3 independent exponential multipliers. This creates useful Fear sinks without negating the rare GOD bedroom mechanic. Each upgrade has an exact cost visible in the case inspector, with no duplicated remote spending. Start prices around 10×–30× the current room's baseline payout and increase for later levels; prices MUST be stable and precomputed from configuration, not manipulated by the client.

**Decor system:** earn-only wall textures, nightlights, hallway carpet variants, bedroom story themes, entry gate skins, window trims, pumpkin and ghost placement, quote boards and exterior signs. Cosmetics cannot obstruct required prompts, sightlines or other players; free basic choices should be substantial. Save a compact item/position catalog with hard placement boundaries and a strict maximum number of replicated decorative objects. Guests can leave reaction stickers in a private 'Scare Review' book: *"My pillow flew away! 5/5 stars"*—fun progression flavor without needing complex NPC pathfinding.

## 14. Collection index, achievements and quests [EXPANDED]

**Book of Frights:** 42-species launch index with silhouettes for unknown species, detailed discovered species art, name, permanent best size seen, mutations seen, current owned count, total scare count and favorite action. The index tracks a species when legitimately granted, not client-reported. Collection rewards at 5/15/30/42 species discovered: an egg voucher (nonrandom based on access rules, or a deterministic cosmetic), entrance skin, exclusive *cosmetic* ghost trail and Moonfall Museum statue. Do not make Secret a requirement for basic tutorial completion.

**Daily Scare Board:** 3 quests/day per player, appropriate to level, each explicitly rewards Fear, a Moon Fragment or a cosmetic. Sample tasks: complete 10 auto scares; place two different rarity monsters; successfully do 3 manual scares; witness a Gold+ room; visit Misty Woods; open one earned box. Never require a Robux purchase, premium item or Secret tier to complete normal dailies. Reroll impossible tasks for free.

**Weekly Town Ledger:** cooperative milestone (aggregate 500/2,000/8,000 scares across participating server sessions with sensible resets), personal contributions count even in small servers; give all participants a base reward and tiers for personal contribution, not exclusive first-place items. One weekly event cosmetic path. Server cannot permanently trust client-supplied contribution values.

**Achievements:** First Scare, First Worker, 6-Room Hotel, First Large, First MASSIVE, First Mutation, Tracker Archaeologist, Diamond Witness, Moonfall Curator, Rebirth 10, 100k Fear Earned, 1m Fear Earned. Achievements award sensible cosmetic or earnable loot, not an excessively stacked currency multiplier.

## 15. Live events, weather and seasonal operations [EXPANDED]

| Event | Frequency target* | What players see | Reward/mechanical change |
|---|---|---|---|
| **Moonlight Rush** | every 30 min, lasts 5 min | full moon brightens, ghosts appear over plaza | +10% temporary auto Fear income; clearly tagged and capped |
| **Fog Parade** | every 45–60 min, lasts 6 min | harmless fog ghosts move through avenue | locate 5 fixed event ghosts for Moon Fragments |
| **Clocktower Glitch** | every 60–90 min, lasts 5 min | giant clock reverses, paper shadows dance | complete a short cooperative route, get nonrandom cosmetic token |
| **Pumpkin Rain** | several short daily windows | foam pumpkins fall onto marked safe pads | pick up 10 for a guaranteed limited decor item |
| **The Midnight Festival** | weekly short event | stage opens in plaza, special music, NPC dialogue | seasonal questline + new earnable skin; no exclusive baseline income requirement |

\*Never promise these as production schedule until implemented and observed. Use server-approved UTC schedule and a shared authoritative event start/end. Avoid an operator-only admin event as a mandatory way to get fundamental mutations. Admin-spawned spectacles may be fun, but no progression should depend on a developer showing up. Temporary weather effects must not silently grant an actual named permanent mutation unless the event's exact chance/acquisition flow is documented and saved.

**First seasonal event suggestion: Moonfall Harvest** (3-week content cadence): 3 new monster **skins** for existing species, haunted lantern decor set, a nonrandom scavenger hunt, one temporary plaza restyle, one new Tracker zone and a free cosmetic reward track. Avoid launching with a second currency if Fear + fragments already provide enough choices.

## 16. Monetization — specific gamepasses, guaranteed packs, transparent prices

### Design philosophy and 2026 Roblox compatibility

**All prices below are proposed creator-side numbers, NOT verified live prices or actual product IDs.** A pass is a **one-time purchase**; a Developer Product is **repeatable**. Check 2026 Roblox marketplace/policy and locale/regional eligibility, and do not display fake checkout buttons until the corresponding product ID exists. Keep core gameplay free, keep all basic species obtainable via playing, keep ads and upsells nonintrusive, and allow easy gamepass shop closing. Never sell a deceptive fake countdown or 'limited' stock that is unlimited.

**Important:** because the game contains random eggs/boxes, any random outcome that can be acquired directly or indirectly with Robux may be a **paid random item** and is subject to full final-item percentage disclosure and `PolicyService:GetPolicyInfoForPlayerAsync()` / `ArePaidRandomItemsRestricted` checks. A paid luck booster that changes paid-random outcome probabilities must update **actual disclosed odds**. Best initial product plan: **do not sell Fear for Robux**, do not sell paid random eggs, and sell only guaranteed specified contents. If optional paid eggs are eventually enabled, implement regional blocks/alternatives, required disclosures, and owner review first.

### Recommended gamepasses [EXPANDED, initial pricing hypothesis]

| Pass | Draft Robux price | Exact entitlement | Nonpaying player's path / safeguard |
|---|---:|---|---|
| **VIP Lantern Club** | 399 | VIP nameplate/gradient, exclusive decorative hallway theme, subtle ghost trail, +10% automatic Fear (not 2x stacked) | all core content and normal cosmetics still earnable |
| **2× Fear** | 349 | ×2 automatic and manual Fear earnings, itemized in earnings panel | base earn rates balanced so game remains playable without pass; no extra rooms |
| **Auto Hatch** | 249 | toggle repeatedly hatches selected affordable Fear egg with spending confirmations and stop limits | earn basic 3x hatch + use manual hatching freely; optional long-term auto hatch unlock via achievement |
| **Fast Hatch** | 99 | shortens/skips cosmetic hatch reveal; cannot reroll result | skip reveal free after initial tutorials, pass mainly batch convenience |
| **Monster Storage +250** | 179 | 250 extra inventory slots beyond earnable capacity | earn free slots by upgrades; enforce memory/UI capacity |
| **Nightfall Sprint** | 149 | moderate movement speed + cosmetic shadow footsteps in safe overworld | teleport waypoints and exploration accessible free; avoid PvP advantage |
| **Haunted Decor Kit** | 129 | guaranteed purple chandelier set, black carpet and gargoyle sign (cosmetic) | many free decor recipes |
| **Extra Preset Slots** | 99 | save 5 more case loadouts for quick swaps (not extra active room slots) | 2 free loadout presets; no effect on server ownership restrictions |

**Stacking rule:** Only income gamepass is 2× Fear; VIP's 10% is separate and shown in the payout inspector. If testing reveals excess inflation, use multiplicative formula with explicit balancing caps. No pass changes bedroom GOD tier odds or wins another player's rewards.

### Developer products [EXPANDED — repeatable, guaranteed]

| Product | Proposed Robux | Guaranteed result | Why it fits |
|---|---:|---|---|
| **Starter Scare Bundle** | 79 | specified Epic-species voucher (player chooses from 2 predetermined Epic species) + original cosmetic lantern | helpful but not mandatory; contents visible before purchase |
| **Fusion Helper Kit** | 129 | one specified Rare monster duplicate + original costume set | no randomness and no replacing actual duplicate crafting requirements |
| **Premium Room Decor Set** | 59 | a named themed decor bundle | pure customization |
| **Named Monster Showcase Pack** | 199 | one **explicitly named** Legendary monster at stated base Fear, normal mutation/size | deterministic purchase, no paid RNG |
| **Friend Gift — Lantern Bundle** | 79 | one named cosmetic gift-equivalent entitlement to selected friend, subject to supported gifting flow | genuine gifting without falsely transferring a pass |
| **Event Supporter Pack** | 149 | specified cosmetic trail/sign + one guaranteed event decoration | supports game development without gated main progression |

**Do not promise buying a gamepass for a friend transfers true pass ownership.** Gift a documented equivalent account entitlement, or use only officially supported gifting mechanisms. Developer product grants must use receipt processing with idempotent, server-persisted receipt ledger. If recipient isn't online, durable pending gift delivery must be implemented before launch. No money spent on disappearing rewards. Premium purchases must not occur for users whose data profile is unavailable.

### Optional later monetization (not launch blockers)

A subscription with cosmetic drops and +5% convenience could exist, but only after the standalone game is retention-proven and proper renewal/eligibility flows are implemented. Similarly, timed event monetization should **never** guarantee unique power that free users cannot eventually earn. Do not use pay-to-gamble rerolls, multiple overlapping purchase nags or an unbounded paid boost ladder.

## 17. UI/UX specification — screen-by-screen

**Overall style:** rounded dark-violet panels with neon mint/pink outlines, high-contrast cream text, legible font, restrained motion, rarity words not colors alone, clear close buttons, true focus ordering, safe area support on 16:9 and narrow phones.

| UI/surface | Exact visible fields, actions and behavior |
|---|---|
| **Main HUD** | Fear wallet, compact earned/sec estimate, rooms active/total, floor, current rebirth and next price, minimal 5-min shop clock, buttons Inventory / Eggs / Shop / Index / Map / Rebirth / Settings |
| **Case nameplate** | monster name, rarity word, numeric current Fear/scare, cycle duration, mutation and size text, accessory icon; owner sees Place/Remove/Inspect, visitor Inspect only |
| **Monster inventory** | 250 slots free, cards with species image, base reward, rarity, size, mutation, deploy location, Favorite lock, filters/sort (income/rank/name/newest), selection/hotbar and compare |
| **Egg preview** | price, **all potential individual monsters and numerical percentages**, mutation subroll probabilities, collection progress, buy/confirm; hatching pause/reveal with skip |
| **Shop** | accurate server rotation countdown, offer quantities labeled 'Your stock', price in Fear, item content, full accessory odds, Buy disabled when invalid, optional Robux store separate tab |
| **Forge** | choose species+size, 4 or 3 ingredient slots, show EXACT consumed instances and resulting size/stats, favorite safeguard, Confirm + Cancel |
| **Mutation Observatory** | current mutation, exact permanent bonus, allowed source, earned Moon Fragments, guaranteed recipe requirements, preview before overwrite |
| **Bedroom inspector** | owner, guest theme, current tier/odds, case worker, exact factor breakdown, expected Fear/scare and Fear/min, staged cosmetic upgrade levels, status (Sleeping/Scaring/Resetting) |
| **Book of Frights** | silhouettes, discovery count (x/42), variants found, rewards, lore, shareable UI card not external link |
| **Rebirth** | next cost, current wallet, new room number/floor, before/after multiplier, exact retained progress, long-press/confirm to prevent accidents |
| **Map** | schematic 8 owned plot icons, services, explored zones, clear waypoint/teleport button, current event hotspot |
| **Quest Journal** | 3 daily tasks, weekly progression, exact requirements and deterministic rewards, claim state, no premium quests |
| **Event HUD** | short notification, real UTC-based end timer, mission contribution and award conditions; hide outside event |
| **Settings** | separate Music / SFX sliders, reduced scares, camera shake toggle, flashing FX toggle, motion/low-graphics toggle, UI scale, color-blind-friendly rarity labels |
| **Tutorial overlay** | highlighted actual in-world object, arrow or beam, 1-step text, progress indicator, owner-confirmed next step, rejoin-safe recovery, option to replay without rewards |
| **Pass store** | clearly labeled Robux pricing from actual MarketplaceService info, exact entitlements, owned/not-owned state, cancel, parental-friendly language; no false 'sale ends' |

**Notification rules:** income numbers may batch visibly when many rooms fire at once without changing actual authoritative credits. A Diamond/GOD pull gets a tasteful centered alert with rarity label and optional camera focus; other players receive a subtle opt-in announcement, not a full-screen jump scare. UI reacts to server results; never assumes the client request succeeded.

## 18. Sound, FX, cinematic direction

- **Night ambience:** wind chimes, occasional crow calls, playful distant clock, bubbly synth pads. Day/night remains a stylized **night** baseline; a regular 'moon phase' adjusts sky tint every 15–20 minutes without making rooms too bright.
- **Scares:** unique family of short stingers per style; guests recoil with comic squash-and-stretch, pillow bounce, shadow puppetry. No loud surprise blast or seizure-like strobe. Randomize small animation offsets to prevent 8×18 monster cases animating in lockstep.
- **Rarity:** normal simple bounce; higher rarity longer decorated reveal; secret has a special 2–3 sec sequence but always skippable. Reduce particle density based on distance/client graphic settings.
- **Mutation VFX:** Golden glints, Haunted translucent tails, Creepy shadow ribbons, Cursed violet drifting runes, UnHoly fractured moon halo. Ensure silhouettes remain clearly identifiable and effects don't obstruct neighboring cases.
- **Scare intensity:** settings default to relatively mild. Reduced-scares mode lowers sound peaks/camera shake, removes flashes and replaces stingers with gentle chimes. Never use real assault/screaming distress as the core appeal.
- **Original assets only:** every character, icon, audio, mesh, font license and animation must be created/licensed appropriately. The original Obsidian screenshots and `.blend` mentioned in notes were not included in the archive; do not promise exact reconstruction without them.

## 19. Multiplayer/social rules

Eight players per server; all plots can be explored without a loading screen, but **only the owner** may place, collect, fuse, buy for or rebirth their own profile. No trading; avoid introducing theft, PvP or public stealing because it undermines the source design. Visitors can inspect cases, cheer with emotes, take a public tour, and earn a tiny **one-time daily visitor quest** at most; they never earn someone else's production income. Owner may toggle plot tour on/off (off only restricts inner nonessential guest route; shops remain public). Friend co-op events give nonexclusive rewards. Future gifting must grant actual server-owned entitlements, not unsupported pass transfers.

**Leaderboard proposal:** all-time Fear earned, highest rebirth, index count and highest documented per-scare payout, with opt-out display for privacy. Never expose real personal information. Prefer leaderboards based on committed server values, not client submissions.

## 20. Data models and production systems (for coding agent)

### Authoritative profile shape (example)

```text
Profile v2:
 schemaVersion; userId; fearWallet; lifetimeFear; rebirths;
 unlockedRoomCount; claimedPlotSlot (current server only; not save slot binding);
 inventoryCapacity; monstersById: {uuid -> speciesId,sizeTier,mutation,baseFear,origin,createdAt,favorited};
 roomStateBySlot: {slotId -> monsterUuid, accessoryUuid, upgrades, cosmeticTheme};
 accessoriesById: {uuid -> accessoryId,origin}; ownedEggs; ownedBoxes; ownedTrackers;
 trackerExpeditions: {expeditionId, targetNodeId, state, reservedRewardId};
 mutationFragments; indexDiscovered; indexBestSizes; indexMutationsSeen;
 achievements; dailyQuests; weeklyQuests; museumRewardsClaimed;
 tutorialStep; tutorialCompleted; freeBoxClaimed;
 visitedMapDestinations; ownedDecor; placedDecor; savedCaseLoadouts;
 settings; premiumEntitlements; processedReceiptIds; pendingGifts;
 eventParticipation; streaks; lastSaveTimestamp
```

**Critical distinction:** `claimedPlotSlot` is a server runtime assignment, not a persistent claim to whichever numbered plot happens to be in a different server. Save attraction layout/slot IDs and rebuild at whichever physical plot the owner claims. Never assume user can own another player's slot by writing a client attribute.

### Service responsibility list

`ProfileService` session-safe datastore, migration, retry, save, schema validation; `EconomyService` server payouts/spends/ledger; `PlotService` claiming & rebuild; `RoomService` guest cycle & rarity; `ScareService` scheduler & manual; `MonsterService` species/instances & FX metadata; `EggService` drop tables & deterministic tutorial voucher; `InventoryService` placement/locks; `FusionService` atomic recipes; `MutationService` crafting/rolls; `MarketService` global rotation and per-player stock; `AccessoryService` box opening/equip; `TrackerService` personal reserved dig node and completion; `RebirthService` cost & unlock; `QuestService` dailies/weeklies; `EventService` ambient and live events; `MuseumService` index; `DecorService` cosmetics & placement validation; `PurchaseService` MarketplaceService receipt confirmation, owned pass sync and gifting equivalents; `SecurityService` remote input, distance, limits. All tables validated once at boot, all remotes rate-limited, all server objects owned by one service.

### Save/transaction safety requirements

- Use DataStore `UpdateAsync`/session-lock safe patterns with schema migrations and independent **Studio-test** namespace. Critical actions are internally transactional with idempotency keys: payouts, hatch, shop purchase, craft, case place/removal, rebirth, and Robux receipt processing.
- If persistence fails, lock spending/premium entitlements and clearly warn before player earns unsavable rewards. Save on important transitions when reasonable, autosave on cadence, and handle server shutdown without assuming the final save always succeeds. Use a reconciliable ledger for paid grants.
- Authoritative timestamps/rotation IDs from the server; random outcomes generated server-side, not requested from LocalScript. No client may set Fear, owned species, rarity, mutation, paid passes, shop stock or roll outcomes.
- Validate ownership, actual server distance from avatar to an Instance, unlocked case ID, ingredient inventory, affordability, nonnegative finite values and cooldown for every action. Test adversarial duplicate requests, disconnects and server hopping.
- Bounded replicated instance counts with StreamingEnabled, LOD, VFX pooling and distance-based animation throttling. With 8 plots × 3+ floors × 6 cases, avoid one expensive Heartbeat listener per room.

## 21. Comprehensive content and launch production checklist

**Art deliverables:** full town street grid, 8 plots, six stylized bedroom prototypes, extra floor theme kits, 42 monster silhouettes and finished release models (12 first slice), full egg model kit, case glass/counters, sleeping guest variants, accessory physical models, forge/observatory/market/clocktower, trackers/mounds, UI icon atlas, VFX variants, Audio bank with per-rarity and per-style audio. Rights-cleared models/animations only.

**Engineering deliverables:** replicated map, robust persistent profile, plot claim & ownership gates, monster inventory, secure hatching, server scare cycles, exact payout breakdown, validated room RNG, first-person and third-person viewing, 3→6 rooms, upper-floor unlock, auto & manual, five-min market, accessory equip, fusion, mutations and deterministic crafting, trackers and dig, tutorial, quests/index, events/weather, mobile/tablet/gamepad UI, reduced scares, purchase/grant handling, receipt persistence, 8-player stress checks.

**Analytics target proposals [not verified player facts]:** first successful manual scare under 2 minutes; first monster placed under 4 minutes; first rebirth in roughly 20–40 minutes for median new players; median session 12–20 minutes; 95% of players have a clear next action in HUD; 0 client-authorized payout/rolls; 0 lost legitimate paid receipts. Balance targets require instrumented tests, not blind assumptions.

**Original gaps:** original screenshots in `Map.md` are merely embeds absent from the provided .7z; Blender asset `art/monsters/jeff/jeff.blend` absent; other LihFolk vault absent; no actual Roblox Studio project provided; no live IDs, pricing, texture or animation assets have been supplied. The design may build proxies, but must not invent paths/asset IDs or claim any proprietary content has been imported.

## 22. Requirements and decisions open to creator review

1. Confirm whether `.001` in the GOD bedroom note means **0.001%** (default here) or **0.1%** / a fractional probability; recalculate Normal if changed.
2. Confirm exact room wall/case measurements and whether external map screenshots are later available; preserve room frontage left/right logic.
3. Confirm whether to launch 12 polished monsters then update to 42, or delay launch until the entire 42 are complete.
4. Decide whether rebirth spends wallet currency (this blueprint) or triggers some additional reset; do not change silently.
5. Confirm whether premium *random* eggs are worth added moderation and eligibility complexity. Current safer plan favors earned eggs and guaranteed Robux items.
6. Verify prices, egg odds, mutation chance, shop appearances and ability bonuses through live testing; all current figures are **provisional**, clearly disclosed in config.
7. Decide whether the optional Scare Style synergy and Stage Props room upgrades increase meaningful choices or create excessive UI. They can be turned off while preserving the source game.

**Definition of complete:** a new player can start, finish tutorial, hatch and place a monster, watch real consistent payouts and room rerolls, buy and equip accessories, explore/dig, fuse/mutate, rebirth into next floors, customize their attraction, join cooperative events, rejoin with everything accurately restored, and use all supported platforms—without client exploits or fake premium purchases. No game can truthfully be called "fully built" until that implementation is created and verified inside Studio.

## 23. External game-design and platform documentation references

The comparison ideas are broad observations and not a request to copy other games. Reference information reviewed while preparing this blueprint:

- [Roblox Creator Hub — Paid Random Items](https://create.roblox.com/docs/production/monetization/paid-random-items): individual numerical odds disclosure, region restrictions via `PolicyService`, and implications for Robux-purchased currencies.
- [Roblox Creator Hub — Game Passes](https://create.roblox.com/docs/production/monetization/passes) and [Developer Products](https://create.roblox.com/docs/production/monetization/developer-products): one-time vs repeatable purchases.
- [Roblox Creator Hub — Monetization](https://create.roblox.com/docs/production/monetization): respectful, truthful offers and policy limitations.
- [Roblox — Theme Park Tycoon 2](https://www.roblox.com/games/2686403484/Theme-Park-Tycoon-2): player-constructed attractions and cosmetic personalization.
- [BIG Games — Pet Simulator 99 systems index](https://db.biggames.io/wiki): collecting, rank, rebirth and progression-system inspiration.
- [Grow a Garden Wiki — Seed Shop](https://growagarden.fandom.com/wiki/Seed_Shop): rotating-stock presentation concept.

This information is reference-only; verify live platform documentation again before the monetization system goes into production.


---

# G. START WORK NOW — REQUIRED FIRST RESPONSE/WORK OUTPUT

Inspect the project and provided files. In your first work cycle, produce a real directory/Instance inventory, validate shared configuration, and implement a playable three-room vertical slice: unclaimed → claim → tutorial manual scare → tutorial egg → inventory → place → automatic scare → room reroll → saved Fear and placement. Then follow the phase guide to complete the full game. If operating only as a text-only assistant, give the complete initial file tree with working Luau files for the first slice, and clearly tell the user which parts require Studio access—do not misrepresent chat text as a completed game.

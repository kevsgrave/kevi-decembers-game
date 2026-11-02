# Owner decisions that override the package

The files in this folder are the build spec (adopted 2026-11-02). Where they disagree with this list, **this list wins**. They were written without seeing the real game.

| Decision | Package says | What we do | Decided |
|---|---|---|---|
| Plots | Claim station with arrows, claim beacon | **Auto-assigned** when the save loads. No claim stations. The tutorial has no claim step, so it starts at the crawl-hole scare | 2026-11-02 |
| Map | "Moonfall": 4 plots west, 4 east along an avenue, 235 x 268 stud plots | **Keep the existing ring of 8 plots** and hub in SCARE THEM. Don't rebuild as Moonfall | 2026-11-02 |
| GOD odds | Open question, defaults to 0.001% | **0.001%**, unless the owner says otherwise | 2026-11-01, default accepted |
| Rebirth and Fear | Spends a wallet cost | **Keeps the leftover Fear** after the cost, along with all monsters and items | 2026-11-01, default accepted |
| Name | "Scare Sim" | **SCARE THEM** | 2026-11-02 |
| Art style | Moonfall art direction, Halloween night | **The owner's references in `docs/references/style/`**: chunky bright studded UI and a brick map. Mostly general spooky, not Halloween: no pumpkins, jack-o-lanterns, witch hut, scarecrow or cauldron | 2026-11-02 |
| Panels open from the HUD | Hatch, shop and fuse actions check the player is at the station | **Those three distance checks are gone**, because the HUD buttons open those panels from anywhere. Rate limits, ownership, state and price checks all stay. Digging keeps its distance check | 2026-11-02 |
| Jeff | Original roster, no copied characters | **Jeff is a stand-in only**, until original models exist. Hatches stay Jeff until the owner flips `content.hatchRoster`, with a payout rolled inside the rarity band. The 42 species then hatch as labelled placeholders until each has a model | 2026-11-02 |

**Next, by the owner's choice (2026-11-02): a Town and Buildings phase after Phase 8.** It brings the package's map and building ideas onto the ring map, not Moonfall: hub buildings first (Hatchery, Market, Forge, Hall of Rebirth), as generated models with previews approved before they go into Studio, then zones, room and floor themes, then upgrades, decor, NPCs, the map and teleports.

Also not started: quests, events and other package extras.

Working rules that carry on: Edit mode only and never start Play; no new meshes or models into Studio without showing the owner previews first; one phase at a time on the owner's go.

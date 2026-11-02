# Publish checklist (2026-11-02)

**Don't publish yet.** Work down this list when you're ready. Steps marked "owner" are ones only you can do, in Studio or on Creator Hub.

## Before anything else

- [ ] Owner: save the place. Everything since Phase 1 exists only in Studio until you do, plus the code in git.
- [ ] Merge `claude/project-thread-8oewdy` when you're happy, so the repo's main work isn't on a side branch.
- [ ] Back up `art/`. It isn't in git.

## Must pass

- [ ] Run every manual test in `docs/phase3` to `docs/phase8` with plain Play (F5). None have been run. Fix what they find.
- [ ] Replace Jeff: turn on `content.hatchRoster` or add original models, and decide what happens to Jeffs already in saves.
- [ ] Check each species you use against the do-not-copy list, especially the four named in `REPORT.md`.
- [ ] Clear the rights items in `ASSETS.md`.
- [ ] Owner: set the server size to 8 in Creator Hub, under the place's settings. Scripts can't set it. It reads 60.
- [ ] Owner: decide the bed humps' mesh setting in Game Settings > Security. Output logs "EditableMesh is not accessible" while it's off.
- [ ] Owner: check who `shinandco` is. They joined the live editing session, and collaborators can change the place.
- [ ] Clear test attributes on `ServerStorage`: `TestProfileKey`, `TestGrantFear`, `TestGrantTracker`, `TestForceMutation`, `TestRoster`. They only work in Studio, but shouldn't ship set.
- [ ] Run all eight test modules from the command bar, and check each says `ALL PASSED`: `ConfigTests`, `ContentTests`, `InventoryTests`, `PlotTests`, `ProgressTests`, `ScareTests`, `ShopTests`, `TutorialTests`.

## Real-world tests

- [ ] 8 real players on a private copy. Check plots, visits, and the frame rate on a phone. Write down the results.
- [ ] Leave and rejoin mid-scare, mid-purchase, mid-fusion and mid-dig.
- [ ] Join the same account from two servers at once. The session lock should stop one.
- [ ] Performance with several players on 2 or 3 floors. If it's too heavy, lower `floorCap`.
- [ ] Real phone and tablet, not just the emulator.

These use real saves, because they aren't plain Play. Your own save will change.

## Balance and content

- [ ] Play through the early game and tune `Balance.luau`. All 183 provisional values are untested guesses.
- [ ] Decide on sounds, see `ASSETS.md`.
- [ ] Decide the room walls. They read bright.
- [ ] Do the Town and Buildings phase, if you want it in the first release.

## On Creator Hub

- [ ] Owner: complete the content maturity questionnaire. This game has scary themes aimed at kids, so answer carefully.
- [ ] Owner: set the name, description, icon and thumbnails. The name is SCARE THEM.
- [ ] Owner: set the genre, supported devices and privacy.
- [ ] Owner: check current Roblox rules on odds disclosure before adding anything paid. Fear eggs are earned-only, and show their odds.

## If you add Robux later

- [ ] Create real products on Creator Hub, and add their ids to `Balance.premium.products`. With none set, nothing can be bought.
- [ ] The current code supports guaranteed Fear packs only. Anything random needs odds disclosure and eligibility rules first.
- [ ] Don't promise to transfer a game pass. Roblox doesn't support it.
- [ ] Test a purchase with a small real amount, and check a retry can't grant twice.

## After publishing

- [ ] Keep old and new builds apart: a server on old code refuses saves written by newer code.
- [ ] Watch for players kicked with "Your save could not be read".

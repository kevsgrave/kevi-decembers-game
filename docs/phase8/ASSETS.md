# Asset manifest and rights check (2026-11-02)

Every asset the place uses, from a scan of Workspace, ServerStorage, MaterialService and Lighting. There are no Sound or Animation objects. **Before publishing, you need to confirm you have the rights to everything marked below.** I can list what's used, but I can't tell you what you're licensed for.

## Needs your attention

| Asset | Where | Issue |
|---|---|---|
| **Jeff** (`art/monsters/jeff/jeff.blend`, baked into `JeffAnim`) | Every hatch today | Your notes base him on Jeff the Killer, and your Phase 8 text says not to copy him. **Must be replaced before publishing** |
| **Texture 6372755229**, "Grid" by meow_pizza | The stud pattern on plots, paths and bedrooms | A third party's free Creator Store item, from before this work. Check you're happy using it, or replace it with your own |
| **Sky ids** 6196665106, 6412503613, 6444320592, 6444884337, 6444884785 | Lighting | Not traced. They may be Roblox's defaults, so check they are |
| **`art/` folder** | Local only | Untracked in git, so your only copy of `jeff.blend` and the renders isn't backed up |

## Generated assets

These came from generation tools during the build, according to the build notes. I haven't traced each id back to its source, so confirm that on your account. Each model has a mesh id and a texture id.

| Group | Item: ids |
|---|---|
| **Materials** (48 maps) | 101523643183976, 101704740379425, 101790096099570, 101878333301227, 101966268740100, 102760154879527, 103554160081762, 103590079901680, 103701169833092, 104746354881881, 104865289714732, 105802401997934, 106785636302228, 107196712204411, 107226059584642, 108592899389808, 108873421148070, 111135743914679, 116725846104477, 121617965337359, 126034913194488, 126398661259168, 127161398353378, 127565396901652, 129724227462708, 130353769845820, 130437991821872, 131084064038126, 131720047528783, 131722798012721, 137030855651179, 70815743200582, 71595945320050, 73438396617865, 76234293297933, 78796695640271, 78863904648465, 79529252056172, 80647946448379, 87265303885778, 87599914118410, 89415726003118, 89755353212923, 89957725647234, 92175131044095, 94853606331394, 97095675302823, 98643482262870 |
| **Furniture** | CozyBed: 103460777104312, 75749465590405. CozyBookshelf: 119659973049230, 121119521007697. CozyDesk: 124631818274150, 138842949733500. CozyNightstand: 121641593108727, 78893579616003. CozyRockingHorse: 136041448337164, 75839057785590. CozyToyChest: 120827844554961, 96819687323105. FancyArmchair: 128586854351640, 78737556034097. FancyBed: 100400751133022, 123901741921724. FancyDresser: 107531113494556, 94028031726645. FancyFloorLamp: 128484797396153, 84530376651534. FancyVanity: 122133906433482, 139835087425512. FancyWardrobe: 130241916012225, 90725611061415. LuxuryBed: 120000482755497, 135333545796778. LuxuryChandelier: 111126124401627, 78497274969104. LuxuryChest: 123600165559918, 129311723931291. LuxuryMirror: 112749350104446, 135815868811714. LuxuryPainting: 119258484735957, 88257193315032. LuxurySideTable: 83259159324088, 87954492760862. LuxuryThrone: 104430240702233, 120689450208977. LuxuryWardrobe: 111326520471854, 130942324273065 |
| **Guest kids** | KidBear: 123299487224462, 92302301305602. KidBunny: 115818762678793, 116604093609530. KidFawn: 135044752767967, 90663424150571 |
| **Map kit** | Barn: 107914174598749, 123804767017539. Bench: 102498667573091, 96693406127535. Bridge: 116479962940011, 134797418777614. Cauldron: 110273585981622, 91371727720567. Crypt: 134607497205927, 74821658651107. Dock: 116079119948806, 72733698542268. EggShrine: 84695626027401, 97644250104648. Fence: 104132185086944, 125075610043438. FlowerBox: 71805042548593, 87021260758309. Gazebo: 120804339396516, 88359812971638. GiantMushroom: 113646012956975, 72961977076369. Graves: 124980862201350, 131787772846247. HayBales: 112334904409186, 77533304895668. IronGate: 101000051610881, 133027930821075. Lamp: 124274489879149, 78223941245093. LeafyTree: 100368044346669, 133722204091929. Mansion: 125028497352567, 95200156791816. Mushrooms: 84550581700815, 98929582288045. PineTree: 124880843098015, 85620886469426. Planter: 125057568641023, 79589908729570. PlotArch: 109817616081761, 113079780629705. Pumpkins: 121780405745017, 82180670058273. Rocks: 100073101335310, 123696448043853. Roof: 123978194304974, 83470948493681. Scarecrow: 114650687668341, 72183123930421. ShopStall: 124356970869571, 127310682013564. SpookyEgg: 129249313079429, 98757353264898. SpookyTree: 119647004966846, 130771693245455. StonePillar: 118467721953580, 89442770170725. Wagon: 111120992612702, 72224445847858. WallLantern: 129194953734767, 71791113973536. Well: 84826026540718, 86192275196685. Windmill: 72543746994557, 99206308806399. WitchHut: 122161959951135, 93090798392049 |
| **Built-in** | Chimney smoke uses Roblox's own `sparkles_main.dds` particle |

## Made of parts, nothing to license

Upper floors, lift pads, plot decks, ghosts, the rebirth station, accessory shapes, mutation glows, monster placeholders, dig mounds, and every interface panel.

## Sound candidates: none added, your approval needed

The game has no sounds. Fill in an id in `src/ReplicatedStorage/Shared/Sounds.luau` and that sound starts working. **I can't hear audio, so please listen on the Creator Store before choosing.**

I'd only use sounds from a clear licensed source. Pro Sound Effects' library on the Creator Store is the safest I found.

| Slot | Candidate | Notes |
|---|---|---|
| `scare` / `scareSoft` | [Whoosh By Howling Wind 6](https://create.roblox.com/store/asset/9120697984) (9120697984), Pro Sound Effects | 5.2 seconds, so longer than ideal. Might suit a ghostly swell more than a pop |
| `payout`, `hatch`, `buy` | None chosen | My searches returned only user uploads like "coin" with unclear rights, so I didn't list them. Search Pro Sound Effects for chimes |
| `music` | None chosen | Results were DistroKid tracks with non-spooky names. Tracks through DistroKid may also have their own terms, so check first |

## Monster models

`ServerStorage.MonsterModels` doesn't exist yet. Any model named after a species id, placed there after your approval, replaces its placeholder. Species ids are in `docs/spec/Monster_Roster.csv`.

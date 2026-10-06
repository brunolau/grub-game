# PROPOSAL_A_FAITHFUL.md - "the Prehistorik 3 that never was"

Expansion proposal, angle A: stay as close as possible to the original's design language. More of what made the
1993 game great, new worlds it could have had, bosses in its style, and co-op and versus modes that feel like a 1994
sequel built on the same engine and the same buttons. New UI is kept to a minimum.

Status: proposal. Nothing is implemented. Inputs: `docs/spec/GAMEPLAY.md` (12 = our adaptation), `docs/spec/PHYSICS.md`,
`docs/LEVEL_DESIGN.md`, `docs/ARCHITECTURE.md`, `docs/ASSET_MANIFEST.md`, the research in this folder
(`RESEARCH_COOP.md`, `RESEARCH_VERSUS.md`, `TECH_AUDIT.md`), and the scouted art and audio under
`.tools/asset_candidates/expansion` and `.tools/asset_candidates/{audio,characters,environment}`.

Units are the project's own:
- **tick**: 1/24.2753 s; 22 ticks make one "designer second".
- **px**: logical pixels; 1 cell = 16 px.
- **v16**: 1/16 px per tick.
- **Hero reach** (LEVEL_DESIGN 12): jump 3 tiles up; running gap 4 tiles (5 with a run-up to the right); a head bounce
  with jump held rises 105 px (about 6 tiles).

---

## 0. The proposal on one page

| Question | Answer |
|---|---|
| What is the expansion? | **Book II: The Far Shore**: a second campaign of **exactly 20 levels** in 5 new worlds (Sunbaked Canyon, Tar Fen, Coral Coast, Idol Ruins, Sky Spire). It is built like Book I: 11 map stops, 6 linked sub-stages, 2 Feast Land bonus stages behind hidden warps, a single-screen final boss and a playable ending. Beginner plays worlds 5-7 and Expert all five. An Expert wall sits before the ruins. |
| Bosses | **5 new**: Tusker the Boar King, Old Mangrove, Inkjaw the Grotto Squid, the Twin Idols, and the Storm Roc. **1 returning**: the Brute, as the original brought its gorilla back. Old Mangrove is the **Rooted Guardian**, the original's third boss type (GAMEPLAY 6.2), which 1.0 never built. The Twin Idols are the Colossus type doubled. The Storm Roc is beaten with the original's **glider dive**. Every boss also has a co-op form that needs both heroes, the Brute and the Colossus included. |
| Something new (solo too) | 1. **The Bone Belt**: the club is never lost, and one special weapon rides on the belt. This is also the rule that keeps 20 more levels provable. 2. **The spear**: a 5th weapon that sticks in soft walls as a foothold. 3. **Vines**: the climb frames are already in the hero sheet. 4. **Rafts and currents**. 5. **Tar, geysers and the rising tide**. 6. **Cave Paintings**: a 20-piece meta-goal that unlocks versus arenas. |
| Weapon rule | With the Belt, **one club route per (stage, difficulty) proves every weapon**: anyone can swap to the club. Book II needs **36 recorded solo routes instead of 155**. Book I's 15 files and 72 routes do not change. |
| Co-op | Exactly 2 players; the engine supports 4. **One paging camera** for both, with walls at the screen edges. Lives are a **shared tribe pool**. A downed hero comes back through an **Egg Hatch**. Score and letters are shared, and each hero gets medals at the tally. The **enemy structure changes** through **co-op trait bits** on every enemy record, the same way Expert works today: `shell`, `bond`, `daze`, `heavy`, `lone`, `grab`, `leech`, `split`. There are also 7 co-op-only enemies. Every co-op stage has **at least 2 solo-proof gates on the main path** plus a team exit, and every boss has its co-op form. The co-op layouts are separate `<id>_coop.lvl` files, so every solo file stays byte-identical. |
| Deathmatch | Same-device **Versus** for 2-4 players, bots included. The flagship is **Food Fight**: hits, stomps and falls knock food out of you, and the most food at the gong wins. Launch modes: Food Fight, Last Caveman Standing, **Letter Snatch** (the original's bonus letters as capture-the-flag) and Hot Rock. **10 single-screen arenas**: 6 at launch, 4 unlocked by Cave Paintings. The tally companion hands out the awards. |
| New UI | A book select (two entries), a two-slot join panel, P2 hearts mirrored top-right, one belt-weapon icon, edge arrows, a second map page with a painting slab, and the versus screens. Nothing else. |
| Licences | All CC0: Pixel-boy's RPG Battle, Ninja Adventure and Western packs, the anchor pack, Sunny Land, Emcee Flesher, and the CC0 audio picks. **Angle A ships no CC-BY file.** |

---

## 1. What "faithful" means here: the 1994 test

Every idea below was held to one question: *would a 1994 sequel on the same engine, with the same one-strike-button
controls, have done it?*

**What we keep, unchanged:**
- the paging camera, 20 x 11 screens and the tick physics;
- heads are always springboards, and a bounce never hurts either side;
- **only bosses throw things** (GAMEPLAY 5.1); ordinary enemies stay simple behaviour archetypes driven by parameters;
- hidden spots everywhere (3 kinds, flood-fill opening), the letters G-R-U-B-S, cutlery feasts, giant bonuses that fall
  from 112 px, skulls, grenades;
- bosses drop the fire-starter that lights the exit totem;
- checkpoints, gates and secret rooms, level codes, the world map, the tally with its companion, and the Beginner wall;
- linked sub-stages, Feast Land warps, a single-screen final boss, and a playable ending with credits.

**What we add.** The test is whether the original already holds the part:
- vines: the climb frames are in the hero sheet;
- rafts: a moving platform with a current;
- tar: the soft-surface tile property;
- the rising tide: Cinder Shaft run upward;
- geysers: springs on a timer;
- the Rooted Guardian: the original's third boss type;
- the glider dive as a boss attack;
- code stones turned into Cave Paintings.

**Considered and left out** (section C.7): swimming, mounts, shops and upgrades, mine carts, split screen, voiced
dialogue, and CC-BY audio (crowd cheers).

---

## A. Campaign - Book II: The Far Shore

### A.1 Structure, story, map

- **Entry.** Title -> Play -> Solo / Co-op / Versus. Solo and Co-op continue to **Book I: The First Feast** (the 15
  shipped stages, untouched) or **Book II: The Far Shore**, then to Beginner or Expert.
  - Book II is open from the start. Beginner players never finish Book I (the Expert wall), so locking Book II behind
    Book I would shut them out.
  - Each book has its own saves, level codes, high-score table and level select. The save is keyed by
    (book, mode, difficulty).
- **Story.** It is told in two still pictures and the signs, the original's own way.
  - At the homecoming feast the **Storm Roc** swoops down and carries the **Great Roast** off over the sea.
  - The hero lashes logs into a raft and follows a trail of falling crumbs across five lands.
  - Every boss has eaten a share of the roast and coughs up the fire-starter for the next exit totem.
  - On top of the Sky Spire the Roc drops the roast, and the ending is the long raft voyage home.
- **Map.** The world map gains a second 1280 x 360 page, "The Far Shore", east of the home islands. A dotted raft route
  leads to five islands:
  - a red mesa (world 5);
  - a tar delta with a giant mangrove (world 6);
  - a coral coast with sea stacks (world 7);
  - an idol isle behind a temple gate (world 8; the gate is the Beginner wall picture: *"Only an expert eater may climb
    to the Roc!"*);
  - a spire rising into a storm cloud (world 9).

  The page is built like the shipped map, from anchor terrain and props on the sea, using the new gradient-mapped
  atlases plus Western cacti, temple props and sky terrain. A small stone slab in the lower-right corner holds the 20
  Cave Painting slots (C.6). As in Book I, only main levels are map stops, and the Feast Land stages have none.
- **Registry.** The engine needs one new meta key, `campaign` (default `first`; Book II files say
  `campaign = far_shore`).
  - `Levels.get_campaign()`, `next_level`, the map and the route test's `CAMPAIGN` filter by it.
  - Book I's files stay byte-identical: they get the default, so Book II never shows up after the Way Home.
- **Carried state inside Book II**, exactly as in Book I: score, lives, letters (a fresh G-R-U-B-S set placed in
  worlds 5-7) and the weapon (now hand + belt, C.1). The glider is removed at the tally.
- **Stretch: "Grand Feast"** (Expert only). Book I and Book II in one run, with the Way Home leading to the raft. The
  Belt rule (C.1) is what makes this provable. It is the first thing cut if scope must shrink (F.5).

### A.2 The 20 levels

Difficulty uses one scale for both books (Book I for reference: 1-1 = 1, 1-2 = 2, 2-1 = 3, 2-2 = 4, 3-1 = 5,
3-2 = 6, 4-1 = 7, 4-2 = 8, 4-2b = 9). B = Beginner and Expert, E = Expert only.

| # | Id | Name | World / biome | Kind | Mode | Signature mechanic | Diff. |
|---|---|---|---|---|---|---|---|
| 1 | `w5_l1` | Red Mesa Trail | 5 canyon | main | B | **Bone Belt and spear** taught (signs); spear footholds in soft palisade walls; long sand slopes with **Rollers**; rattlers in holes | 3 |
| 2 | `w5_l2` | Rattlesnake Gulch | 5 canyon | main, `tally=false` | B | **Vines** up the gulch walls; hatches into snake burrows (diggers); rolled vines that a strike unrolls (shortcuts); **warp to Feast Land D** high on a soft wall | 4 |
| 3 | `w5_l2b` | Tusker's Wallow | 5 canyon | sub, boss | B | **Boss: Tusker the Boar King** in a mud wallow (first tar) | 4 |
| 4 | `w6_l1` | Bubbling Fen | 6 swamp | main | B | **Tar** floors, **rafts** on slow currents, lily pads as drop platforms, gnat zones (flies + water bucket) | 5 |
| 5 | `w6_l2` | Spore Hollow | 6 mushroom cave | main, `tally=false` | B | darkness lit by glowing caps (dark zones), mushroom caps as springs, spore **geysers**, Puffcap snappers | 5 |
| 6 | `w6_l2b` | Heart of the Mangrove | 6 swamp (inside a hollow tree) | sub, boss | B | **rising tide of tar** (Cinder Shaft run upward) with vines, then **Boss: Old Mangrove** | 6 |
| 7 | `w7_l1` | Shell Beach | 7 coast | main | B | rafts on the surf current, blowhole geysers, leaping fish, gull harriers; **warp to Feast Land E** on a sea stack | 5 |
| 8 | `w7_l2` | Sea Caves | 7 coast cave | main, `tally=false` | B | dark caves, driftwood drop floes over water, octopus lurkers, soft coral walls for the spear | 6 |
| 9 | `w7_l2b` | Squid Grotto | 7 coast | sub, boss | B | **Boss: Inkjaw** (pool, islands, ink darkness, rafts in phase 3). **Last Beginner stage** | 7 |
| 10 | `w8_l1` | Overgrown Steps | 8 ruins | main, `tally=false` | E | stair puzzles of **rising columns**, vines, **Guards** (shield lizards), **Mimic** chests | 7 |
| 11 | `w8_l1b` | Brute's Temple | 8 ruins | sub, boss | E | **Boss: the Brute returns** (enraged), with pillars his ground pound raises | 7 |
| 12 | `w8_l2` | Hall of Idols | 8 ruins interior | main, `tally=false` | E | a maze of gates and one-screen secret rooms, darkness, spike pits, Guards in narrow halls | 8 |
| 13 | `w8_l2b` | Idol Court | 8 ruins | sub, boss | E | **Boss: the Twin Idols** (single fixed screen) | 8 |
| 14 | `w9_l1` | Cloudbreak Climb | 9 sky | main, `tally=false` | E | a vertical climb: vines, steam-vent geysers, drop clouds, harriers | 8 |
| 15 | `w9_l1b` | Thunderhead Glide | 9 sky | sub | E | a **glider crossing** through a storm (the original's 3b), lightning telegraphs, dive-scoring harriers | 8 |
| 16 | `w9_l2` | The Roc's Spire | 9 sky peak | main | E | the gauntlet: alternating gusts (crouch to brace), crumbling drop clouds, everything learned | 9 |
| 17 | `w9_l3` | Storm Nest | 9 sky | main (single screen, 20 x 12) | E | **Final boss: the Storm Roc**; the Great Roast is the trophy | 10 |
| 18 | `bonus_d` | Feast Land D: Honey Falls | feast | bonus (from 5-2) | B | honey = tar in candy skin, soda geysers, honeycomb walls full of spots | 2 |
| 19 | `bonus_e` | Feast Land E: Pudding Lagoon | feast | bonus (from 7-1) | B | wafer rafts on a syrup current under a rain of fruit | 3 |
| 20 | `ending_b` | The Long Raft Home | coast / village | ending | E | a playable credits voyage on a raft past every island; landing on the home beach shows THE END and the feast picture | 2 |

**Count:**
- 11 main levels (map stops): 5-1, 5-2, 6-1, 6-2, 7-1, 7-2, 8-1, 8-2, 9-1, 9-2, 9-3;
- 6 sub-stages: 5-2b, 6-2b, 7-2b, 8-1b, 8-2b, 9-1b;
- 2 bonus stages and 1 ending.

That makes **20 level files**. Beginner plays 11 of them (worlds 5-7 and both Feast Lands); Expert plays all 20.

Placements across the books:
- **Letters G-R-U-B-S**: 5-2 (G), 6-1 (R), 6-2 (U), 7-1 (B), 7-2 (S). They are all in Beginner range, as in Book I.
- **Cutlery**: one full set per world.
- **Weapon pick-ups**:
  - the spear in 5-1;
  - the hammer in 6-1;
  - the axe in 7-1;
  - the swirling axe in 8-1;
  - the spear again in 9-1.

  Each sits on or near the main path. None is ever needed (C.1).
- **Expert-only enemies**: the original's per-record Expert bit, in every level.

### A.3 Level notes, world by world

**World 5 - Sunbaked Canyon** (the re-entry world: wide open, bright, forgiving).
- **5-1 Red Mesa Trail.**
  - Opens on the beach where the raft lands. The first sign teaches the Belt: "Your club never leaves you. Press SWAP."
  - The spear lies at the first checkpoint, in front of a palisade wall (`&`) with a code stone above it.
  - The second half is a run down long sand slopes where **Rollers** (curled lizards) come down at you. Head bounces
    over them reach mesa-top secrets.
- **5-2 Rattlesnake Gulch** is vertical: vines up the walls, and snake burrows behind hatches (the original's hatches
  from Echo Caverns).
  - **Rolled vines** lie on ledges. One strike unrolls them, opening shortcuts for the next attempt, the way P2 used
    breakable blocks.
  - The **Feast Land D warp** sits on a ledge in the gulch wall, reachable only up two spear footholds. This is the
    "aha" use of the new weapon.
- **5-2b Tusker's Wallow**: a short approach, then the walled arena (B.1).

**World 6 - Tar Fen** (slower, stickier, darker).
- **6-1 Bubbling Fen** teaches **tar**: you sink in and only tap-jump, so routes go around it or over it on **rafts**.
  - Currents are slow. A strike while standing on a raft paddles it.
  - Gnat zones bring back the original's flies, washed off by the water bucket.
  - The hammer lies on a raft that drifts past a secret.
- **6-2 Spore Hollow** is a mushroom cave in near darkness, using the original's darkness triggers. Glowing caps mark
  the way: caps are springs, and spore geysers lift drop platforms.
  - **Puffcaps** (Snapper skin) bite from the dark. Their windup glow is the telegraph.
- **6-2b Heart of the Mangrove** goes up inside the hollow trunk while tar rises 1 px per tick behind you. This is
  Cinder Shaft run upward, with vines, roots and burrowing bugs. An `autoscroll_stop` zone at the top opens into Old
  Mangrove's chamber (B.2).

**World 7 - Coral Coast** (a breather after the swamp, then the hardest Beginner stretch).
- **7-1 Shell Beach** has surf currents that carry rafts between sand bars, blowholes that throw rafts and heroes onto
  sea stacks, leaping fish (the original's "swordfish from the water"), and gulls.
  - The **Feast Land E warp** is on the tallest sea stack, reached by a blowhole and a vine.
- **7-2 Sea Caves**: drift-log drop floes over dark water (Crystal Grotto's floes in a new skin), octopus Lurkers on
  the ceilings, and soft coral walls (`&`) for spear steps.
- **7-2b Squid Grotto**: Inkjaw (B.3). Clearing it ends the Beginner run with the expert-wall picture.

**World 8 - Idol Ruins** (Expert; the castle world of the original's level 9).
- **8-1 Overgrown Steps** is a temple stair puzzle built from **rising columns** (earthquake pillars) that move when
  you step on trigger plates. On top of that:
  - **Guards**: shield lizards that turn slowly toward you;
  - **Mimic** chests among real ones;
  - vines through the ruined roof;
  - the swirling axe.
- **8-1b Brute's Temple**: the original reused its gorilla as the penultimate boss, and we bring the Brute back
  enraged (B.4).
- **8-2 Hall of Idols** is the original's gate-and-secret-room craft at full strength: a maze of gate doors
  (`objects/gate` with `lock=`), each a one-screen room, plus darkness, spike pits and Guards in 3-row-high halls
  where you cannot bounce over them.
- **8-2b Idol Court**: the Twin Idols (B.5).

**World 9 - Sky Spire** (Expert; the climb to the Roc).
- **9-1 Cloudbreak Climb**: vertical. Vines, steam-vent geysers and drop clouds; harriers and darts hunt in the
  updrafts. The spear returns for footholds in soft cloud-rock.
- **9-1b Thunderhead Glide** is a glider crossing like the original's intermediate stage.
  - Take the glider, run up, and cross a storm where lightning marks its column 22 ticks ahead.
  - Dive-attack harriers for the 1 000 / 5 000 / 10 000 ladder.
- **9-2 The Roc's Spire** is the exam: alternating gusts (Blizzard Pass's crouch-to-brace), crumbling clouds, tar
  pockets, Guards and Rollers, with a checkpoint before every section.
- **9-3 Storm Nest** is the single screen of the Storm Roc (B.6), like the original's final level.
- **The Long Raft Home** is the ending stage: a raft on a gentle current passing the five islands. Credits sit on
  floating signs, food rains from the Roc's broken hoard, and the home beach shows THE END. If all 20 Cave Paintings
  are found, the last picture is the mural of the feast.

### A.4 Difficulty curve (both books on one scale)

| Book | Beginner part (play order -> difficulty) | Expert-only part |
|---|---|---|
| I | 1-1 **1**, 1-2 **2**, 2-1 **3**, 2-2 / 2-2b **4**, 3-1 / 3-1b **5**, 3-2 **6** | 4-1 **7**, 4-2 **8**, 4-2b **9**, Way Home |
| II | 5-1 **3**, 5-2 / 5-2b **4**, 6-1 **5**, 6-2 **5**, 6-2b **6**, 7-1 **5**, 7-2 **6**, 7-2b **7** | 8-1 / 8-1b **7**, 8-2 / 8-2b **8**, 9-1 / 9-1b **8**, 9-2 **9**, 9-3 **10**, Raft Home |

Bonus stages and endings sit off the curve (Feast Land D 2, E 3, ending 2).

- Book II starts where Book I's world 2 sits (difficulty 3). Players who skip Book I get a re-warm, and veterans get
  new toys at once.
- The **Beginner run ends at 7** (Inkjaw), one step above Book I's Beginner end (Crystal Grotto, 6).
- The **Expert run peaks at 10**, one step above the Colossus.
- 7-1 is a deliberate dip after the swamp boss, as Book I's 3-1 is after the Brute.

### A.5 Enemies of Book II

Following the original, Book II mostly gives **new species on the 13 existing behaviours**, and adds **three new
behaviours** written in the same spirit: one parameterised state machine each, no projectiles, heads safe to bounce
on.

| Archetype (GAMEPLAY 5.2) | Book II species (sprite source) |
|---|---|
| 0 Dropper | slime blobs (RPG Battle `slime`, 2 palettes) in the fen; crabs are a gap, so the coast uses sea snails (shipped `turtle_b` with an anchor shell item composited on) |
| 2 Dangler | cave bats (RPG Battle `bat`) in the gulch; octopus on a kelp thread (Ninja Adventure `Octopus` 2x) in the sea caves |
| 3 Lurker | scarabs (shipped `insect`) in the ruins; octopus (Ninja Adventure `RedOctopus` 2x) on sea-cave ceilings |
| 4 Swinger | swinging bats (shipped `bat_b`) in the gulch and the sea caves; the swing stays rare, as in the original |
| 5 Stinger | swamp mosquitoes (shipped `insect_b`, recoloured) |
| 6 Harrier | desert eagle (Sunny Land eagle 2x), gull (shipped `pterodactyl` recoloured white), ruin ghost (RPG Battle `ghost`), sky pterodactyls |
| 7 Dart | eagle dive, storm pterodactyl (shipped `pterodactyl_b`) |
| 8 Hopper | swamp frogs (Sunny Land frog 2x), temple raptors (shipped `mini_rex_b`) |
| 9 Walker / Flyer | tortoises (shipped `turtle`), grubs (Ninja Adventure `Larva` 2x), jellyfish flyers (RPG `slime` recoloured to translucent blue) |
| 10 Digger | burrow snakes (RPG Battle `snake`, red and green), mangrove bugs (shipped `lizard`) |
| 11 Leaper | leaping fish (Ninja Adventure `Fish` / `FishRed` 2x), cloud drakes (shipped `dragon_b`) |
| 12 Charger | desert tribesman (shipped `rival`, recoloured); the heavy charger is the shipped `rex_b` (the RPG `boar` at 1x is boss-sized and is kept for Tusker) |
| Snapper | rattler in a hole (RPG `snake`), cave bear (Western `bear`: idle, claw = bite, hurt, death), Puffcap (RPG `mushroom`, spore burst = bite), shipped `plant` |
| **13 Roller** (new) | RPG Battle `dino`: walks; within 6 tiles it curls (14 ticks, a visible tuck) and rolls at the hero. It follows slopes, speeds up downhill (+4 v16 per tick, cap 96), bounces off walls and is **dizzy 33 ticks** after a wall (hittable, as are walkers). A head bounce on the ball is safe, as on any head. Parameters: `range`, `speed`, `dizzy` |
| **14 Guard** (new) | RPG Battle `reptile` (it has a GUARD animation; armour recoloured to bone and stone): patrols, holds its shield toward the hero and **turns only every 33 ticks** (`turn` param). Front hits glance off with the Colossus clank and spark; back hits count. Solo answer: bounce over it and strike before it turns. This teaches the pincer that co-op then demands |
| **15 Mimic** (new) | RPG Battle `mimic`: looks exactly like a container (`skin=chest`). Within 2 tiles it opens with a 10-tick shudder and bites (Snapper rules). Killed, it drops a treasure. The original's cruel-joke tradition (the skull) as an enemy |

All three new archetypes live in `scripts/enemies/` (enemies module). Each declares its doze rule
(ARCHITECTURE 11.1), and Book I never spawns them.

### A.6 Art and audio per world (every world has real, CC0 art)

| World | Terrain (2 sets) | Parallax | Props | Enemies / boss | Music (CC0) |
|---|---|---|---|---|---|
| 5 Canyon | `canyon/terrain` = gradient map of `volcano/terrain` (proven: `_style_tests/terrain_canyon.png`); `canyon/terrain_mesa` = gradient map of `cave/terrain_stone` to red sandstone | layer0 sky band of RPG Battle backdrop 17 (paint out its towers); layer1/3 Emcee Flesher desert layers gradient-mapped warm; layer2 Western `rock-background.png` mesa strip at 2x | Western cactus 1-3, rocks 1-6, tumbleweed, skull, bones, dead trees; shipped `skull_big`, `bone_pile` | above + **Tusker** = RPG `boar` (1x, outline to `#272018`, palette 2 for rage) | Wolfgang_ "Desert Theme" (5-1), Spring Spring "Suez Crisis Remade" (5-2), nene "Boss Battle #1" (Tusker) |
| 6 Fen | `swamp/terrain` = gradient of `jungle/terrain` (`terrain_swamp.png`); `mushroom/terrain` (`terrain_mushroom.png`) for Spore Hollow; tar floor and tar liquid recoloured from the water strip | RPG backdrop 12 (forest), night variant gradient-mapped; shipped jungle layers 1-3 gradient-mapped to swamp (real separate planes) | shipped jungle props recoloured (moss fringe, vines, trunks), Ninja Adventure TilesetNature reeds at 2x, glowing caps = RPG `mushroom` frame | above + **Old Mangrove** = Ninja Adventure `GiantBamboo` 2x gradient-mapped to bark, plus a root fist composited from shipped `root_arch` + `boulder` | Junkala Super Action stage 7 (6-1), Wolfgang_ "Haunted House" (6-2), Tallbeard "Pixel War 1" (6-2b climb), nene "Boss Battle #2" (boss) |
| 7 Coast | `coast/terrain` = gradient of `cave/terrain` (`terrain_coral.png`); `coast/terrain_sand` = the shipped `feast/terrain_biscuit` (it is literally a sand set) | the anchor pack's own unused sea-cliff `background-1.png`; RPG backdrop 5 (beach) sky band | RPG Battle shells and feathers, anchor turtle shell, shipped jungle palms and rocks | above + **Inkjaw** = Ninja Adventure `SquidGreen` 2x, `SquidRed` for rage | Spring Spring "Sandy Seaside" (7-1), Tallbeard "Deep Blue" (7-2), nene "Boss Battle #4" (boss) |
| 8 Ruins | `ruins/terrain` = gradient of `cave/terrain_stone` (`terrain_temple.png`); `ruins/terrain_jade` = gradient of `jungle/terrain` to mossy jade | RPG backdrops 21 / 22 (ruins, temple; towers painted out); shipped jungle layer3 recoloured | shipped village `stone_tablet`, `carved_block`, `palisade`, cave skulls; anchor coloured crests as wall glyphs; RPG goblet and laurel as treasures | Guards, Mimics, ghosts + **Brute** (shipped `brute_enraged`) + **Twin Idols** = shipped `colossus.png`, mirrored and gradient-mapped jade / sandstone | Junkala Super Action stage 9 (8-1), Tallbeard "Penultimate" (8-2), shipped boss music (Brute), Spring Spring "Egyptian Fortress Boss" (Idols) |
| 9 Sky | `sky/terrain` = gradient of `ice/terrain` (`terrain_sky.png`); `sky/terrain_rock` = `ice/terrain_rock` recoloured to slate | shipped ice sky + clouds recoloured; Superpowers Backgrounds sky islands (15 / 39) at 4x as the farthest layer only | shipped ice props recoloured (dead trees), anchor feathers and wings, RPG Battle FX for lightning | harriers, darts, eagles, drakes + **Storm Roc** = shipped `pterodactyl.png` at 2x, gradient-mapped to storm slate with a gold crest | Wolfgang_ "Upbeat Overworld" (9-1), Spring Spring "Typhoon's Theme" (9-1b), Junkala Retro Sports "stage_final" (9-2), nene "Boss Battle #3" (Roc) |
| Feast D / E | shipped `feast/*` sets; honey = tar recoloured amber; syrup = water recoloured | shipped `feast` parallax | shipped feast props | shipped enemies in feast mode | shipped `bonus` track (the original had one bonus tune) |
| Ending | shipped `jungle/terrain_grass` + `coast/terrain_sand` | anchor sea cliffs | shipped village props | none | Spring Spring "Tropical Fantasy" (1.0 staging) |

**Gaps and how they are filled.** All fills are compositing or recolouring of CC0 inputs, the way 1.0 built its
sheets.

| Gap | Fill |
|---|---|
| Hero poses for new moves | already exist or are assembled from existing frames: **climb** = frames 44-47 (in every hero sheet); **carry a partner** = victory frames 48-49 (arms up) with the partner drawn on top; **being tossed** = roll frames 24-26 (a tumbling ball); **paddle** = attack frames; **egg** = `egg_kid` roll frames (an egg) recoloured to the player's colour |
| Spear hero sheet | anchor item 12 (spear) composited into `hero_spear.png`, exactly how 1.0 built the axe and boomerang sheets |
| Raft | shipped `platform_wood` x2 + anchor log item + rope pixels; wafer skin from the biscuit tile |
| Crab | dropped: sea snails instead |
| Mammoth (co-op Mammoth Calf, D.4) | RPG `boar` palette 2, recoloured shaggy brown with lengthened tusks |
| Lightning and storm | RPG Battle FX bursts and shock rings recoloured, plus shipped `particles_rain` |
| Old Mangrove's fist | composite of shipped `root_arch` + `boulder` with a code-drawn 3-segment root arm |
| Parallax for coast and sky | anchor `background-1.png` + the farthest layers only from 4x Superpowers backgrounds |
| Cave Painting fragments and mural | shipped `stone_tablet` + anchor crest icons; the mural is drawn from shipped sprites in ochre silhouette on a rock slab |
| Belt icon | the shipped thrown-weapon frames (`projectile_axe` etc.) and a club cut from the hero sheet, at 1x |

**New sound effects** (all CC0, from the scouted staging):

| Event | Sound |
|---|---|
| Belt swap | Junkala `interaction6` |
| Spear stick | Spring Spring `snd_enemyland` |
| Vine climb | Junkala `ladder1loop` |
| Raft | Skippy Fish `water` / `waterReentry`, rubberduck splashes |
| Geyser | Basto `heavy_splash` + BMacZero bubbles |
| Tar | Spring Spring `glug` |
| Egg hatch | Junkala `powerup2` |
| Lift / toss | MoxieCat `lift` / `throw` |
| Plate | Kenney `switch_002` |
| Drum | Junkala `Blip5` |
| Countdown | kheetor countdown |
| Round / match win | Junkala `fanfare1` / celestialghost8 "Victory" |
| Co-op join | ctske `square_partyjoin` |

Every new file goes through `CREDITS.md`, `docs/THIRD_PARTY.md` and the manifest, as today. Loop fixes listed by the
audio scout (82 ms lead silence on "Typhoon's Theme", seam checks on nene #3) are done before import.

---

## B. Bosses

### B.0 Rules every boss follows (the 1.0 fairness rules, extended)

- **Telegraphs**: every attack shows itself **10 or more ticks** ahead. This is pinned per boss by a test like
  `tests/test_enemies_colossus.gd`.
- **Hit cooldown**: hits count once per `BOSS_HIT_COOLDOWN` (22 ticks). There is no stun-lock; attack clocks keep
  running through hurt poses.
- **Head bounces**: landing on a boss's head or top always bounces the hero and harms nobody (the original's rule).
- **Book II rule: every boss can be beaten with the club.** Specials only make it easier. This rule is what lets the
  Belt (C.1) prove the bosses with one route.
- **Defeat**: the boss bursts into 64 bonus items plus the fire-starter (the final boss gives the trophy instead).
  Boss music plays while the bar shows.
- **Co-op**: hit points are at most x1.25; the cooldown already stops two heroes from doubling the damage. Each co-op
  form has a mechanic that **one hero cannot perform**:
  - a twin-hit window shorter than the solo minimum; or
  - a guard that always faces the nearest hero; or
  - a grab that only the partner can break.

  A solo search in the co-op arena (D.5) proves it.

Hit points are given in club hits (club power 25; a charged hit counts 4). The archetype 6.2 and 6.3 bosses count
1 per hit, as in the original.

### B.1 Tusker, the Boar King (5-2b Tusker's Wallow)

- **Sprite**: RPG Battle `boar`, 239 x 178 cells at native 1x, so the body is about 75 x 55 logical px, twice the
  hero's height.
  - Its idle, walk, charge, spin-ball, hit and death frames all exist. Palette 2 is the rage phase.
  - Outline recoloured to `#272018`.
- **Arena**: one walled screen (`zones/arena`, `|` walls).
  - Two mesa banks 3 rows up at the sides (cols 1-4 and 15-18), where a hero can stand over a charge.
  - A 6-cell **tar wallow** in the middle that slows everyone, Tusker included.
- **Phase 1** (hp above 60 %), **Paw and Charge**:
  - Telegraph: it paws for 22 ticks (dust puffs, snort).
  - It then charges at 96 v16 (6 px/tick).
  - Hitting a wall leaves it **dizzy for 44 ticks**. Crossing the wallow slows it to 2 px/tick and leaves it
    **stuck for 22 ticks**.
- **Phase 2** (60-30 %), **Spin Ball**:
  - Telegraph: a 14-tick squeal while it curls.
  - It rolls as a ball and bounces off the walls in two arcs. A high hop follows, and its landing shakes the screen;
    crouch to stand firm (the original's earthquake rule).
  - It is dizzy for 33 ticks when it uncurls.
- **Phase 3** (below 30 %), **Stampede**: every wall impact shakes 3 rocks loose (shipped `boss_rock` physics). A dust
  trickle marks each rock's column 14 ticks before it falls. Its idle time shortens.
- **Weak point**: the head, only while it is dizzy or stuck. While it charges, the tusks make a hit glance off.
- **Hit points**: Beginner 150 (6 hits); Expert 225 (9 hits).
- **Solo**: lure it into the walls and the wallow, then strike. Bounce over the charge, or stand on a bank.
- **Co-op form**:
  - **Aggro**: it charges whoever hit it last.
  - **Rump weak point**: while dizzy it swings to face the nearest hero (shell rule), so only the partner, standing
    behind, can hit its weak spot: the leafy rump.
  - **Phase 3 brace**: a charge is stopped dead only by **two heroes crouching side by side** in its path (the
    Mammoth Calf rule, D.4). That stun lasts 66 ticks. One crouching hero is trampled.
  - Hit points 190 / 280.

### B.2 Old Mangrove, the Rooted Guardian (6-2b Heart of the Mangrove)

This is the original's tree-stump archetype (GAMEPLAY 6.2), listed as a stretch goal in 12.1 and never built.

- **Sprite**:
  - **Body**: Ninja Adventure `GiantBamboo` (62 x 62 frames: idle, attack, charge, hit) at 2x, gradient-mapped to
    mossy mangrove bark. It is set into the right wall the way the Colossus is.
  - **Fist**: a root knuckle composited from shipped `props/jungle/root_arch` and `objects/boulder`, on a
    code-drawn 3-segment root arm.
  - **Leaves**: shipped `enemy_ember skin=leaf`.
  - **Minions**: shipped `lizard` diggers, the original's "bugs".
- **Arena**: the chamber at the top of the rising-tar climb. Floor at row 10; the Guardian fills cols 15-18; two
  one-way root ledges on the left at rows 7 and 4.
- **Three stages** (the original's 10 / 7 / 7 structure; any weapon counts as 1):
  1. **Face**.
     - The fist punches along the floor in bursts of 3-8. Before each burst the arm draws back for 10 ticks with a
       creak.
     - Every punch shakes the screen and shoves the hero 2 px, and one leaf falls from 150 px above.
     - **The resting fist is a springboard**, as in the original: landing on it launches the hero, unharmed, to the
       face at row 4.
  2. **Upper hand**. A second root sweeps the upper ledge; the ledge shakes for 14 ticks first. The hand then
     **rests on the ledge for 44 ticks**: hit it with a high strike from the lower ledge.
  3. **Fist**.
     - Faster bursts (8 punches), and bugs burrow up. Every shake sends the bugs back down, as in the original.
     - The fist is hittable for **20 ticks after each burst** while it is stuck in the floor. The original gave
       6 ticks; we widen it for fairness.
- **Hits**: Beginner 4 / 3 / 3; Expert 6 / 5 / 5.
- **Co-op form**:
  - **Stages 1 and 2 merge**: the face and the hand must both be struck **within the twin window** (12 ticks on
    Expert, 24 on Beginner). One hero rides the fist springboard to the face; the other waits on the upper ledge
    for the hand.
  - **Pinning**: a hero standing on the resting fist **pins** it, so it cannot punch until it flings him off after
    66 ticks. This helps the other hero.
  - **Stage 3**: the fist's knuckle armour turns toward the nearest hero, so its wrist must be struck from the far
    side (pincer).

### B.3 Inkjaw, the Grotto Squid (7-2b Squid Grotto)

- **Sprite**: Ninja Adventure `SquidGreen` (76 x 79 frames: idle, walk, attack, attack loop, shoot, hit) at 2x,
  outline recoloured. `SquidRed` is the rage phase.
  - **Ink blob**: `boss_rock` physics with a black-violet recolour of `projectile_rock`.
  - **Ink darkness**: the existing dark-zone palette fade.
  - **Slams**: the attack frames, plus the shipped `fx/ring` and a water splash.
- **Arena**: one screen with a deadly water pool across the floor.
  - Three rock islands (cols 2-5, 8-11 and 14-17, row 9).
  - Two one-way hanging-root ledges at row 6 above the gaps.
  - The squid surfaces in one of the two gaps (cols 6-7 or 12-13). **22 ticks of bubbles** mark which one.
- **Phase 1, Surface and Slam**:
  - Telegraph: a tentacle is raised over the neighbouring island for 12 ticks, and its shadow shows where it lands.
  - The slam is a deadly box for 4 ticks and shakes the screen.
  - The squid stays up for 44 ticks.
  - **Weak point**: the top of its head. Reach it with a high strike from an island edge, a bounce (safe), or a
    thrown weapon.
- **Phase 2, Ink**:
  - Adds a spit: its jaws open 10 ticks first, then an ink blob arcs at the hero.
  - A hit costs a bone (the boss rule) **and dims the screen to the night palette for 66 ticks**. This is the
    original's darkness trigger turned into an attack.
  - The bubbles at the surfacing gap stay bright in the dark.
- **Phase 3, Whirlpool** (red, below 30 %):
  - The middle island sinks, and two log **rafts** circle the pool on a current.
  - The squid surfaces beside a raft and slams it: the raft dips and shakes, but nobody is thrown off.
  - Fight from the raft; a strike on the water side paddles it.
- **Hit points**: Beginner 150 (6); Expert 225 (9).
- **Co-op form, Tentacle Lock**:
  - On surfacing it crosses **two** tentacles over its head (solo: one, the one facing the hero).
  - A strike on a tentacle makes it flinch for 16 ticks (Expert) or 24 (Beginner).
  - The head opens for 33 ticks only while **both** flinch. That means one hero on each island flanking the gap,
    striking on a count of three.
  - In phase 3, one hero paddles the raft into position while the other strikes.

### B.4 Brute's Temple: the Brute returns (8-1b)

Brought back as the original brought its gorilla back for its castle level.

- **Sprite**: shipped `brute_enraged.png`, no new art. Expert 250 hp (10 hits), speed class 3, as the 2-2b Expert
  fight.
- **New arena twist**: two stone columns (`objects/column`) in the temple court. Each **ground pound raises one and
  sinks the other**, with a rumble 22 ticks ahead, so the arena reshapes itself. A raised column is a perch above his
  leaps and a wall against his rush.
- **Co-op form**: B.7.

### B.5 The Twin Idols (8-2b Idol Court)

- **Sprite**: the shipped `colossus.png`, the fossil-rex statue that lives in a wall.
  - The left idol is a **mirrored** copy gradient-mapped to jade (the Moon Idol); the right one is sandstone gold
    (the Sun Idol).
  - All poses are reused: idle, spit, slam, hurt, rage, broken.
  - Falling masonry = `projectile_stalactite` recoloured to sandstone.
- **Arena**: one fixed screen, like the original's final level.
  - The idols sit in both walls at floor level.
  - A 2-row altar block stands in the centre (cols 8-11).
  - A ledge at row 6 stands in front of each idol's jaws.
- **Pattern**: the two share one brain.
  - One idol is **Awake**: its eyes glow and it spits rocks at the hero. The jaws show for 10 ticks first, and each
    rock bounces twice (the Colossus rules).
  - The other is **Asleep** and armoured. It drops masonry over the hero, rattling 14 ticks before each piece falls.
  - Every 4th hit both **rage** for 40 ticks (armoured), and then they swap roles.
- **Weak point**: the open jaws of the awake idol.
  - Reach them with a high strike from its ledge, a forward strike when it slams low, or any thrown weapon.
  - Unlike the Colossus, the club works here (the Book II rule).
- **Hits**: Expert 7 per idol (14 in total, 1 per hit). The boss bar shows two halves.
- **Co-op form, Twin Hit**:
  - **Both idols wake together**, and each spits at the hero on its own side.
  - An idol only cracks if its twin is hit **within 12 ticks**. One hero stands on each ledge: "3-2-1-now".
  - A rage swaps their targets, so the masonry hunts the hero on the far side.

### B.6 The Storm Roc (9-3 Storm Nest, final boss)

- **Sprite**: the shipped `pterodactyl.png` at 2x (288 x 240 cells; body about 104 x 44 logical px), gradient-mapped
  to storm slate with a gold crest. It already has fly, perch, rise, dive, screech, hit and dead.
  - **Feathers**: anchor items 43-46 as a new `feather` skin of the leaf hazard.
  - **Lightning**: RPG Battle FX recoloured white-yellow.
- **Arena**: one 20 x 12 screen at the spire top.
  - A stick **nest** (one-way, cols 6-13, row 8).
  - A stone floor at row 10 with a 4-cell runway on each side.
  - Two drop clouds at row 5.
- **Phase 1, Gale**:
  - It perches on the nest rim and raises its wings for 14 ticks (a whoosh), then beats them. The wind blows left
    or right for 66 ticks, using the blizzard wind code: **crouch to brace**.
  - Feathers fall like the leaves.
  - Its head can be reached from the nest with a high strike, or by bouncing.
  - After 3 gusts it takes off.
- **Phase 2, Dive**:
  - It circles the hero using the harrier loop, screeches for 14 ticks, then dives at his position (the dart rule).
  - A miss **buries its beak** in the nest or the floor for 44 ticks, and its head is open.
- **Phase 3, Storm** (below 1/3):
  - Lightning strikes cells that a darkening cloud marks **22 ticks** ahead. Struck nest sticks burn for 66 ticks.
  - The Roc climbs above the view and comes down only to swoop.
  - **The original's hang-glider is placed on the nest.** Take off along the runway (24 ticks at speed, the original
    rule), climb on lift and **dive onto its back**. The original's dive ladder (1 000 / 5 000 / 10 000) counts the
    three hits; the third dive brings it down.
- **Defeat**: it tumbles into the sea, and the Great Roast falls onto the nest. The roast is the trophy (a warp to the
  ending).
- **Hit points**: phases 1-2 take 200 (8 club hits); phase 3 takes 3 dives. Expert only.
- **Co-op form**:
  - **Phase 1**: a wing shield faces the nearest hero (pincer on the nest).
  - **Phase 2, Snatch**: a dive **grabs** the hero it targeted and climbs at 2 px/tick.
    - The partner frees him by hitting the Roc's head (bounce off the nest rim and high-strike, or throw) within
      3 s; otherwise the grabbed hero becomes an egg, with no life lost.
    - A rescue stuns the Roc for 66 ticks, and both heroes can strike.
  - **Phase 3, Pilot and Spotter**:
    - There is one glider; the pilot cannot strike (the original rule) and dives.
    - After each dive the Roc tumbles low over the nest for 24 ticks. A dive only counts if the hero on the nest
      strikes its tail feathers within those 24 ticks.

### B.7 Co-op forms of the two shipped bosses

- **The Brute** (2-2b Brute's Den, and 8-1b):
  - **Aggro**: he targets whoever hit him last.
  - **Arm guard**: his arm guard faces his target and blocks throws and head strikes from that side, so **only the
    partner can reach the head**.
  - **Grab**, below 50 %: he seizes his target and squeezes out one bone per 44 ticks. The grabbed hero shortens it
    by wriggling (Left/Right); the partner frees him with a head hit.
  - The ground pound shakes both heroes; crouch to stand firm, as now.
  - Hit points x1.25 (Beginner 190, Expert 310).
- **The Wall Colossus** (4-2b):
  - A stone **visor** covers its face. Two Stone Plates at the hall's sides lift it while a hero stands on the
    plate whose chain is active.
  - Rocks are spat at the plate holder, and stalactites rattle over the thrower, so both heroes are busy.
  - It is still thrown-weapons only, and the co-op checkpoint places **two** axes.
  - Each rage moves the active chain to the other plate, so the roles swap.
  - Hit points 24 -> 30.
  - The fairness tests of `test_enemies_colossus.gd` run per hero.

---

## C. Something new (for everyone, solo included)

### C.1 The Bone Belt, the weapon rule that keeps 20 more levels provable

**The problem.** Today a run keeps one weapon (a pick-up replaces it), and every (stage, difficulty, weapon a run can
bring) cell needs a recorded route (LEVEL_DESIGN 10). Book I has 72 such routes for 15 stages.

**The cost under today's rule.** Book II's stages could be entered holding any of five weapons (club, hammer, axe,
swirling axe, spear):
- 11 Beginner-and-Expert levels x 2 difficulties + 9 Expert-only levels = **31 (stage, difficulty) cells**;
- x 5 weapons = **155 routes**.

**The rules.**
1. **The club is never lost.** The hero has two weapon places, the hand and the belt. One of them always holds the
   club; the other holds at most one *special* (hammer, axe, swirling axe or spear).
2. **Pick-ups.** A special goes into the hand and the club onto the belt. A special already owned is replaced and
   gone, as in the original. Taking a club item while holding a special swaps them.
3. **Swap** is one new action, `swap`.
   - Default keys: keyboard **V** (next to Z / X / C) and **U** (next to J / K / L); pad **LB**; touch: the spare
     **Y stone**, which already exists in `ui/touch_buttons.png` (cells 7 / 15).
   - It swaps the hand and the belt on the tick it is pressed, unless a strike is running; it works in the air.
   - Feedback: a star puff and a blip. Lock-out: 8 ticks.
   - It does not touch movement, so a swap on any tick leaves the hero's motion exactly as it would be without it.
4. **Carrying.** Hand and belt carry through deaths and levels, as the weapon does today. A level started from a code
   or the level select begins with the club and an empty belt (as today). The "restart level" entry snapshot stores
   both.
5. **HUD**: one 16 px icon next to the hearts showing what a swap would bring. It shows only while a special is owned.
   The hero sprite already shows the weapon in hand (4 sheets, 5 with the spear), so nothing more is needed.
6. **Book II design rule**: nothing on a main path needs a particular weapon, and every boss falls to the club (B.0).
   Specials open shortcuts, secrets and paintings, and make fights easier.

**The proof arithmetic.**
- **Recorded**: one **club route per cell** (31), plus **one featured route per world** (5) that uses that world's
  special for its secret or boss. That is **36 recorded solo routes instead of 155**.
- **Generated, not recorded**: an "arrived with a special" replay per cell (31). The test ORs one `swap` press into
  the first tick of the club route.
  - Swapping never changes movement, so the hero's path is the club route's path.
  - One generated replay covers every special: after the swap the hero holds the club whatever sits on the belt.
- **The campaign test** plays Book II with whatever the run carries. When the hero holds a special it swaps on the
  stage's first tick and plays the club route.
- Route names follow today's scheme: `w5_l1.inputs`, `w5_l1.expert.inputs`, `w5_l1.spear.inputs` (featured).

**Consequences for the existing campaign (Book I).**
- **Files and routes unchanged.** The 15 level files and all 72 routes stay as they are. No recorded route presses
  `swap`, so they all replay tick for tick. The new input bit is zero in every existing route file, and the digest
  guard of TECH_AUDIT 4.12 proves it.
- **No new Book I proofs.** The Belt makes the Book I per-weapon matrix redundant; it stays as regression evidence.
  If a Book I stage ever changes, its club route alone is the proof of record.
- **Fairness holds.** A Book I player can now always fall back to the club. Every Book I stage already has a club
  route, because the level select starts with the club.
- **The Colossus is unchanged.** It is still thrown-weapons only, with the axe at its checkpoint.
- **One visible change**: the belt icon appears once a special is picked up. Options offers **"Classic weapons"**
  (Book I only), which hides the icon and ignores `swap`, so Book I plays exactly like 1.0.
- **Save**: Save v2 stores `belt` beside `weapon`, migrated as empty.
- **Co-op**: each hero has his own belt, so **every co-op route is club / club**. No team weapon and no weapon-pair
  matrix are needed.
- **Grand Feast**: the Book I -> Book II marathon becomes provable with no extra recording.

**Engine cost**: S-M.
- player: hand/belt state, swap, sheet swap;
- core: the `swap` action and bindings, `Game.belt` and Save v2;
- ui: the icon and the touch Y stone;
- integration: swap-prefix replays in `test_campaign_routes.gd`.

### C.2 The spear (fifth weapon)

- **Rules**:
  - Thrown; power 20; 6-tick recovery.
  - Flies flat at 12 px/tick for 16 ticks, then falls (+32 v16 per tick).
  - Like the axe it passes through ordinary walls (the original's rule) and opens hidden spots. The shared limit of 4
    in flight applies.
- **New**: it **sticks in soft walls**, a new tile char `&`. These are set-A ground cells drawn with the inset panel
  (tile 15) and flagged soft: bark, palisade, packed earth, soft coral, cloud-rock.
  - A stuck spear is a **one-way foothold**, 16 px wide, at its height. It lasts 132 ticks and blinks for the last 22.
  - Each hero has at most 2 stuck; a third pulls out the oldest.
- **Why it fits**: the original's hero climbs by bouncing on heads. The spear lets him make his own step with the same
  single strike button and no new move.
- **Limits by design**: soft walls exist only where the designer puts them (secrets, the Feast Land D warp,
  paintings). The validator keeps them out of reach of co-op gates (D.5).
- **Engine cost**: M.
  - player: `Defs.Weapon` appended, `hero_spear` projectile, sheet;
  - world: the `&` tile flag;
  - objects: the stuck-spear foothold as a `PlatformBase`.
  - Book I has no `&` cells and no spear item.

### C.3 Vines

- **Object**: `objects/vine length=<cells> rolled=<bool>` hangs from a ledge or ceiling. Art: shipped `vine_a` /
  `vine_b` stacked, recoloured per biome; a coiled `rolled` look is cut from `vine_branch`.
- **Climbing**:
  - **Grab**: Up while the hero's feet column is within 6 px of the vine.
  - **Speed**: Up 2 px/tick; Down 3 px/tick.
  - **Top**: Up at the top steps onto the ledge.
  - **Jump** lets go: -128 v16 (rises 36 px) plus 32 v16 toward the held direction.
  - **Drop**: Down + Jump.
- **No strikes while climbing**: hands are full, the original's glider rule. A hit knocks the hero off as an ordinary
  hurt.
- **Rolled vines** lie coiled on an upper ledge. One strike on the coil unrolls the vine down its length. This is a
  shortcut opener in solo, like P2's breakable blocks, and the "way back" gift in co-op (D.2).
- **Why it fits**: the climb animation (frames 44-47, back view) is already in every hero sheet. The anchor artist
  drew it, and 1.0 left it unused.
- **Engine cost**: M (a new CLIMB state in `Player`, a PHYSICS appendix entry, the object). No Book I file contains a
  vine.

### C.4 Rafts and currents

- **Raft**: `objects/raft width=3|4 skin=log|wafer` floats on `~` liquid.
- **Currents**: `zones/current rect=... dir=l|r|u|d speed=1..3` moves rafts and floating items inside the zone.
  - Outside a current a raft slows by 1 px/tick every 8 ticks.
  - Banks (solid cells) stop it.
  - Riding uses the platform rules (PHYSICS 11.4): the hero inherits the raft's motion.
- **Paddling**: a forward strike while standing on a raft pushes it backward by 16 v16, up to 3 px/tick. A raft
  dips 2 px under each rider (visual).
- **Water stays deadly**, as in the original: falling off is a pit death. In co-op it is an egg.
- **Why it fits**: it is the original's moving platform with a new driver, and gives water levels without swimming.
- **Used in**: 6-1, 7-1, 7-2b phase 3, Feast Land E, the Long Raft Home, and the Tide Pool arena.
- **Engine cost**: M (objects: raft; world: current zone; the doze rule for drifting rafts).

### C.5 Tar, geysers and the rising tide

- **Tar floor** `:`: a ground cell whose surface sits 6 px lower. The engine's lowered-surface ("soft ground")
  profile already exists in `TileGrid`.
  - Walking is capped at 32 v16 (2 px/tick).
  - Jump thrust lasts only 3 ticks, so tap jumps rise about 30 px.
  - Crouch and strikes work normally.
  - Ground enemies are slowed the same way, and dropped items stop dead on it.
  - `liquid = tar` gives deadly tar pits (the water strip recoloured).
- **Geysers**: `objects/geyser period=<ticks> power=<v16> delay=<ticks> skin=mud|blowhole|steam|soda`.
  - Bubbles for **22 ticks** (the telegraph, with sound), then spouts for 12 ticks.
  - The spout launches heroes, enemies, rafts and drop platforms above it, using the spring launch code.
  - Harmless: a spring with a timer.
- **Rising tide**: `scroll = rising`, the inverse of Cinder Shaft.
  - The view rises 1 px per tick, with a band of the level's liquid at its bottom edge.
  - It waits for the first input, like the 4-1 descent.
  - Touching the band kills (in co-op it makes an egg).
- **Why it fits**: soft surfaces, springs and auto-scroll are all original systems; these are their new combinations.
- **Engine cost**: S for tar (world tile flag + player caps), S-M for the geyser (objects), M for rising scroll
  (world: `LevelCamera` + level).

### C.6 Cave Paintings (the new meta-goal)

- **The items**: 20 fragments, `items/painting index=0..19`, one hidden in every Book II level.
  - Hiding places: behind `$` walls, up spear steps, at the top of vines, or as the content of a big spot. Never on
    the main path.
  - Each is worth 5 000 points and counts for the completion percentage.
  - They are saved per profile across modes (`Save.add_painting`), like the code stones.
- **The map slab**: the Far Shore map's stone slab fills slot by slot. **Every 5 fragments unlock one versus arena**:
  Mesa Ring, Tar Pit, Tide Pool and Cloud Top (E.4).
- **The ending**: with all 20, the Long Raft Home ends on the mural picture.
- **Party switch**: Options has "unlock all arenas", for groups who only want versus.
- **Why it fits**: the original hid its level codes as digit sprites in the maps, and we kept them as code stones.
  Paintings give that hunt a goal, and they link the campaign to versus.
- **Engine cost**: S (objects: the item; core: the save key; ui: the map slab).

### C.7 Considered and rejected for angle A

| Idea | Why not |
|---|---|
| Swimming | the original's water kills; there is no swim art, and it would mean a whole new physics state |
| Mounts / dino riding | there is no rider pose (the art gap list) and it needs a second movement model; it breaks "one hero, one move set" |
| Shops, currency, upgrades | not in the original's design language; the score is the only currency |
| Mine carts | the only art (OPP2017) is off-style and needs 2x plus an outline recolour; possible later as a single traversal stage |
| A second strike button | swap is a mode switch, not a second attack; every strike stays on one button |
| Split screen | see RESEARCH_COOP 5.4: half views break the 20-column paging design |

---

## D. Co-op

### D.1 Rules of the two-hero game

| Topic | Rule |
|---|---|
| Players | **2**, designed, tested and shipped for two. The engine holds 4 (TECH_AUDIT 4.1); 3-4-player co-op stays a possible later "party" setting without designed gates |
| Heroes | the same physics, boxes and strike scripts. P2 is a palette swap through a per-slot LUT shader (no baked sheets: TECH_AUDIT 5.3). Default colours from the staged `hero_colours`: P1 the original yellow loincloth, P2 blue. A "P1 / P2" tag and colour arrow appear when the heroes overlap |
| Body contact | heroes pass through each other sideways. Only heads are solid: landing on a partner uses the stomp test, so heads are platforms and springboards. There is no friendly fire |
| Camera | **one shared paging camera** (TECH_AUDIT option B). It pages when the front hero reaches column 16, and stops when the rear hero reaches column 1 or the front hero is back at column 5. The view edges are walls. Vertically, the camera follows the grounded heroes. **Look** claims the camera. Gates, arenas and auto-scroll take both heroes. A hero off-screen for 3 s (Expert) or 5 s (Beginner) becomes an egg: no life is lost |
| Lives | one **tribe pool** (starts like solo: the counter shows 2). A life is lost only on a **team wipe**: both heroes dead or in eggs at once. Then both respawn at the checkpoint, and enemies reset as now. 1UPs and the 250 000-point lives feed the pool |
| Revive: **Egg Hatch** | a downed hero tumbles (the death toss), then floats inside an egg near his partner (the `egg_kid` roll frames in his colour). The egg drifts after the partner; its owner can nudge it. **The partner hatches it with any hit or a head bounce.** The hatched hero has 2 hearts (Beginner) or 1 (Expert), 44 ticks of blinking, and loses his own "since last death" tally list. A checkpoint hatches every egg. On Expert an unhatched egg flies back to the checkpoint after 10 s. **Down + Look held 1 s** turns a hero into an egg on purpose, to be carried through a hard stretch |
| Score | **one tribe score** (HUD centre-left as today, one co-op high-score table). At the tally the companion catches each hero's items in his own pile, then hands out medals: Most Food, Best Bounce Chain, Hatchling (eggs hatched), Strongman (boosts and tosses), Clumsiest (as a joke). Options: "Rival score" (two scores, same levels) |
| Shared state | letters G-R-U-B-S, the feast kit (any hero's 3 pieces feast both), the checkpoint, the exit unlock, completion, paintings |
| Per hero | hearts, bones (bones picked up at full energy fly to the partner), hand + belt, glider |
| Exit | **team exit**: the level ends when both heroes are at the exit totem (an egg on screen counts) |
| Gates | Down on a gate takes both heroes; a partner more than a screen away arrives as an egg |

### D.2 Co-op moves and objects

All of them are built on the original's own primitives: heads, springs, columns, hidden spots and gates.

| Move / object | Rules | Built on | Cost |
|---|---|---|---|
| **Shoulder Hop** | landing on the partner's head with jump held bounces -224 v16, as on an enemy (rises 105 px from his head, so the feet reach about 140 px, 8.7 tiles). Without jump held: a small hop | `Overlap` stomp test, `PlayerBase.bounce` | S |
| **Totem Ride** | landing on the partner without jump held means standing on his head: the carrier is a moving platform (PHYSICS 11.4). His jumps are halved. The rider can strike (a high strike reaches about 4-5 tiles over the floor) or jump off (about 6 tiles) | `PlatformBase` ride rules, in the `PartyDriver` after both heroes have moved | M |
| **Caveman Toss** | the carrier presses Up + strike: the rider flies with -224 v16 up and 80 v16 forward (about 9 tiles across, or 8.5 up). He keeps air control and can strike in flight. Pose: roll frames | hero CARRY / THROWN flags | M |
| **Stone Plate** | `objects/plate target=<name> mode=hold\|timed\|latch count=1\|2`. While pressed it drives a column (`objects/column` gains a `hold` mode: rises while pressed, sinks 1 tile per 4 ticks when released). A plate is placed 8+ tiles from its door | the step-on tile + `objects/column` | S-M |
| **Twin Drums** | `objects/drum pair=<name>`: two drum stones (hidden-spot hittables) must be struck within the twin window (12 / 24 ticks). They open a column or a gate | `HittableBase` | S |
| **Bone See-saw** | `objects/seesaw`: a hard landing (a fall of 4+ tiles) on the high end launches whoever stands on the low end, up to about 10 tiles. Enemies on the low end are thrown off | `PlatformBase`, the hard-landing rule | M |
| **Heave Boulder** | `objects/boulder_heavy` (shipped `boulder.png` at 1x): it moves 1 tile per 6 ticks only while **two** heroes push on the same side. It fills a gap, blocks a tar flow or presses a plate | column-style tile mover | M |
| **Drop gifts** (the way back) | every boost ledge holds a gift that only the upper hero can release: a **rolled vine** (C.3), a **flower pot** that becomes a spring when clubbed off the edge (`objects/flower_pot`), or a plate for the partner | vine, `objects/spring`, plate | S |
| **x2 tablet** | a stone tablet carved with two cavemen (a shipped `stone_tablet` composite) marks every co-op gate and every two-player secret. Diegetic, not a HUD element | `objects/sign` skin | S |

### D.3 The enemy structure for co-op: trait bits (the "Expert bit" of co-op)

The original gave every enemy record an Expert-only bit, and we answer the owner's request the same way. **Every
enemy record in a co-op file may carry one co-op trait** (`coop=shell|bond|daze|heavy|lone|grab|leech|split`, plus
`bond=<name>` for pairs). The trait changes how that enemy must be beaten.

The traits only exist in co-op files (the validator refuses them in solo files). In every co-op stage, **at least a
third of the enemy records carry a trait**, and the enemies that guard main-path chokepoints always do (D.5).

**Base rules for every enemy in co-op** (from RESEARCH_COOP 4.1 and TECH_AUDIT 3.8):
- **Target**: the nearest hatched hero (ties go to P1).
- **Despawn**: only when far from both heroes.
- **Zone spawners**: alternate between the heroes inside, with `max` x1.5.
- **Active cap**: 12, unchanged.
- **Stolen hearts**: each hero's stolen heart bursts as bones to the team.
- **Resets**: only on a team wipe.
- **Hit points**: unchanged; two heroes already deal double damage.

| Archetype | Co-op base behaviour | Co-op trait used in layouts | Why one hero cannot do it |
|---|---|---|---|
| 0 Dropper | drops land beside each hero in turn | `bond`: drops come in pairs, one by each hero; `split`: a tar blob splits into two halves running apart when hit, and both must die within the window or they merge | the pair is out of one hero's reach in the window |
| 1 Decoration | none | - | - |
| 2 Dangler | unchanged; its thread can be struck (cuts it) | `grab` (**Snatcher bat**): grabs a hero touching it from below and reels him up its thread toward a pit-side perch; the partner cuts the thread | a grabbed hero cannot strike |
| 3 Lurker | drops when any hero is in range; chases the nearest | `leech`: lands on a hero's back and drains one bone per 44 ticks. Only the partner can club it off; alone it falls off after 220 ticks | an ability that only works on the partner |
| 4 Swinger | unchanged | `bond` pair swinging in opposition (rare) | two kills in one window |
| 5 Stinger | dives at its target | `lone`: dives at the hero **farther from his partner** | staying together is the defence |
| 6 Harrier | its loop is relative to its target; it changes target every loop | `bond` pair circling in opposite directions, one reachable only from a Totem Ride | two kills in one window, one of them high |
| 7 Dart | aims at the nearest hero at launch | none | - |
| 8 Hopper | hops at its target | `daze` (**Raptor**): hops back out of reach when any hero within 48 px starts a strike, and jumps low throws. A head bounce **dazes** it for 12 ticks (Expert) or 14 (Beginner); only a dazed raptor can be hurt | a lone hero needs about 15 ticks from his bounce to a damaging strike (PHYSICS 8.1), longer than the daze |
| 9 Walker / Flyer | unchanged | `shell`: the shell faces the nearest hero every tick, so front hits glance | one hero is always "in front" |
| 10 Digger | rises beside each hero in turn | `lone` | as for the Stinger |
| 11 Leaper | leaps at its target | `bond`: twin leapers from pits on opposite sides | two pits too far apart for one hero |
| 12 Charger | runs at its target | `heavy` (**Mammoth Calf**): front hits glance; it is stopped only by **two crouching heroes side by side** in its path, which dazes it for 44 ticks with its head open; one crouching hero is trampled (hurt, thrown back) | needs two braced bodies |
| Snapper | bites the nearest; the bite tests every hero | `daze`-like bait: during the 20-tick recovery after a lunge its stem is open, from the side opposite the lunge only | the baited hero is the one recovering |
| 13 Roller (new) | rolls at the nearest | `bond` pairs on two slopes | two kills in one window |
| 14 Guard (new) | solo turn delay 33 ticks | `shell`: turns **every tick** to the nearest hero (the **Shellback**) | the pincer |
| 15 Mimic (new) | bites the nearest | none (a solo joke stays a solo joke) | - |

### D.4 Co-op-only enemies (7)

These are trait + archetype combinations with their own skins. They exist only in `*_coop.lvl` files.

| Enemy | Archetype + trait | Sprite | Where |
|---|---|---|---|
| Shellback | Guard + `shell` | RPG Battle `reptile`, armour recoloured bone | ruins, canyon, Book I ice (penguin-shield variant: shipped `turtle_b` with a shell) |
| Raptor | Hopper + `daze` | shipped `mini_rex_b` | jungle, ice, ruins |
| Snatcher | Dangler / Stinger + `grab` | shipped `bat_b` (dangler), `pterodactyl_b` (swooping, coast and sky) | caves, coast, sky |
| Leech | Lurker + `leech` | Ninja Adventure `Larva` 2x, recoloured | caves, fen |
| Mammoth Calf | Charger + `heavy` | RPG `boar` palette 2, recoloured shaggy with longer tusks | ice (Frost Summit's lake), canyon |
| Tar Splitter | Dropper + `split` | RPG `slime` (2 palettes = the two halves) | fen, Feast Land D (honey) |
| Shaman | new patroller | anchor `dragon-man` NPC (idle loop; motion in code) | ruins, volcano |

The **Shaman** casts bone shields on enemies within 4 tiles (they glance until he dies) and flees along his
platform from the nearest hero. He has to be pinned from both sides.

### D.5 Making cooperation required (not just possible)

1. **Every co-op stage file has at least 2 co-op gates on the main path.** Sub-stages need 1 plus their boss. On top
   of that come the team exit and the boss's co-op form.
2. **Gate kinds**:
   - **boost ledge**: 7 tiles (112 px; 8 tiles on Expert), with an x2 tablet;
   - **plate door**;
   - **twin drums**;
   - **see-saw**;
   - **heave boulder**;
   - **toss gap**: 8-9 tiles of deadly liquid;
   - **keeper door**: `objects/column trigger=keepers:<name>` rises when every enemy named `<name>` is dead. The
     keepers carry `shell`, `bond` or `daze` and stand in a hall **3 rows high**, so nobody can bounce over them.
     The original's head-bounce rule would otherwise let a hero skip any enemy.
3. **Solo-impossibility checks** (validator, world module, `--coop`):
   - no bounceable enemy, spring, hidden spot (club pogo), vine, glider or soft wall `&` within reach of a boost
     ledge (an enemy bounce rises 105 px from its head);
   - plates 8+ tiles from their doors;
   - twin and daze windows shorter than the solo minimum. That minimum is measured by a search with the reference
     hero, the same tooling the route proofs use.
4. **Fairness**:
   - each gate has an easy role (stand, crouch, be the bait) and a harder one (the jump, the toss, the timed strike);
   - every one-way move has a way back (a drop gift);
   - the Beginner windows are 24 ticks;
   - each gate takes under about 30 s once understood;
   - a failure costs an egg, never a life, while the partner stands.

### D.6 Book I in co-op (the 15 shipped levels)

Each shipped stage gets a **`<id>_coop.lvl`** (`kind = coop`, `coop_of = <id>`): a copy of the solo map with its own
edits (TECH_AUDIT 4.10). The solo files stay byte-identical, so their routes cannot move, and the single-player
registry never sees `kind = coop`. The co-op campaign is the solo campaign with every stop replaced by its `coop_of`
file. Traits and gates follow D.3-D.5.

| Stage | Main-path co-op gates | Trait enemies | x2 secrets |
|---|---|---|---|
| 1-1 Vine Bridges | (1) the springy flower becomes a 7-tile ledge: Shoulder Hop, then the upper hero clubs a flower pot down (teaches the hop and the gift); (2) a plate door on the canopy road. Signs teach eggs at the first checkpoint | two Shellback turtles before the exit (taught by a sign) | a High Cache: hidden spots 7 tiles up, reached from a Totem Ride |
| 1-2 Canopy Village | (1) the first tree house is reached only by Totem Ride + jump; (2) a see-saw in the trunk room | bonded flying-squirrel leapers; a Snatcher bat on the bat bounce | the Feast Land A warp behind twin drums |
| 2-1 Echo Caverns | (1) paired plates on two hatches (one holds, one drops); (2) a keeper door guarded by two Raptors | Leeches under the dark section; `lone` swinging bats | a secret-room gate needing a toss |
| 2-2 Bone Gorge | (1) a see-saw on the rising stepping stones; (2) the lift pillar driven by a plate. Both glide the gorge (two gliders) | a Mammoth Calf on the gorge floor | - |
| 2-2b Brute's Den | a keeper door into the den (two bonded diggers); **the co-op Brute** (B.7) | - | - |
| 3-1 Frost Summit | (1) a Mammoth Calf on the frozen lake (brace together); (2) a cliff climb by boost ledge with a rolled vine back | bonded chargers | a High Cache on the cliff |
| 3-1b Blizzard Pass | a keeper hall of Shellback penguins, 3 rows high, in the gusts; the lee leapfrog (a crouching hero shelters the other) over the last gaps | `lone` chargers | - |
| 3-2 Crystal Grotto | (1) a toss over icy water; (2) twin drums that freeze a floe bridge (a column) | Raptors, twin leapers from the water pits | the Feast Land C warp on a boost ledge |
| 4-1 Cinder Shaft | (1) both inside the auto-scroll: a heave boulder that must be pushed off a ledge to plug a lava vent before the view passes; (2) a toss across a lava stratum | `lone` stingers in the ember rain | - |
| 4-2 Obsidian Keep | (1) leapfrog plate doors (A holds for B, B holds for A); (2) twin drums that stop a spike column | Shamans shielding the keep guards | - |
| 4-2b Colossus Hall | **the visor Colossus** (B.7); two axes at the checkpoint | - | - |
| Feast Land A / B / C | the warp item sits on a boost ledge; a giant roast spot pays its giant bonus only when both strike it in the window | relay bounces: alternating heroes extend the bounce ladder to x10 / x12 | everything |
| Way Home | the village gate is barred; one hero must be lifted to the lookout to open it; team exit at the end | none | - |

### D.7 Book II in co-op (designed with co-op from the first sketch)

Every Book II stage is authored as two files on the same skeleton: `w5_l1.lvl` and `w5_l1_coop.lvl`. Small
differences inside a file use the `solo` / `coop` entity flags. The new mechanics each get a co-op twist.

| Level | Co-op signature (gates on the main path) |
|---|---|
| 5-1 Red Mesa Trail | spear relay: A sticks a spear foothold, B stands on it to boost A (Shoulder Hop from a foothold); Shellback snakes guard a keeper gully |
| 5-2 Rattlesnake Gulch | one climbs a vine while the other holds a plate that keeps a sand gate open; the upper hero unrolls the second vine (the gift) |
| 5-2b Tusker's Wallow | co-op Tusker: rump pincer, two-hero brace (B.1) |
| 6-1 Bubbling Fen | **carry over tar**: only a Totem Ride crosses the deep tar pocket without sinking (the carrier is slowed, the rider is dry); a two-man raft: one paddles, one clears Leeches; Tar Splitters |
| 6-2 Spore Hollow | a torch-free darkness section where geysers launch whoever stands on the see-saw end; twin drums made of mushroom caps |
| 6-2b Heart of the Mangrove | rising tar for two: a heave boulder must be pushed onto a vent before the tar reaches it; co-op Old Mangrove (B.2) |
| 7-1 Shell Beach | a blowhole toss (the geyser launches the carrier and his rider together; the rider jumps off at the apex to a 10-tile stack); bonded leaping fish |
| 7-2 Sea Caves | a plate that holds a sea gate while the partner rides a driftwood floe through; Snatcher gulls over a pit |
| 7-2b Squid Grotto | the Tentacle Lock (B.3) |
| 8-1 Overgrown Steps | column stairs that only rise while **both** plates are held (`count=2`), then a heave boulder holds one while the heroes cross; Shellback guards |
| 8-1b Brute's Temple | co-op Brute with pillars (B.4, B.7) |
| 8-2 Hall of Idols | a gate maze where every room door is a plate held from the other room; keeper halls with Shamans |
| 8-2b Idol Court | the Twin Hit (B.5) |
| 9-1 Cloudbreak Climb | see-saw + geyser combos to 10-tile clouds; `lone` harriers |
| 9-1b Thunderhead Glide | two gliders; bonded harrier pairs that must both be dive-hit within 24 ticks |
| 9-2 The Roc's Spire | leapfrog in the gusts: a crouching hero shelters his partner from the wind (the lee, RESEARCH_COOP T10), plus a final toss gap |
| 9-3 Storm Nest | the Snatch rescue and Pilot and Spotter (B.6) |
| Feast Land D / E | roasts for two, relay bounces; the warp on a boost ledge |
| The Long Raft Home | one raft for two; the home beach is the team exit |

### D.8 Joining, controls, HUD, difficulty

- **Join**: Title -> Co-op opens a small carved panel with two slots.
  - **Press jump on any device** to take a slot. Left / right picks a colour; holding strike for 1 s means "ready".
  - P2 can also join or leave from the world map or the pause menu. Mid-level, that restarts from the checkpoint in
    the other layout (curtain; score kept), because the co-op layout holds different entities.
  - A lost pad pauses the game with "Reconnect, or continue alone".
- **Keyboard** (positional bindings, rebindable per slot). The join panel runs a key test: each player holds left +
  jump + strike, and all lights must stay lit.

  | Layout | P1 | P2 |
  |---|---|---|
  | Two hands each (default) | move W A S D, strike F, jump G, look R, swap T | move arrows, strike `.`, jump `/`, look `,`, swap `;` |
  | One hand each (the original's scheme: Up jumps) | W A S D, strike Space, swap Q | arrows, strike Right Ctrl (or Num 0), swap Right Shift |

  Left + Right together is look in both layouts.
- **Pads**: one pad per slot, with the solo layout (A jump, X / B strike, Y / RB look, LB swap).
- **Touch**: phones get one touch player (P2 on a pad). Tablets of 9 inches or more get **table mode**:
  - mirrored clusters at each end, in the player colours: a three-way pad and jump / strike / swap stones of 56 art
    px or more;
  - marked experimental until tested.
- **HUD** (the minimum):
  - P1 panel top-left exactly as today;
  - P2 hearts mirrored top-right;
  - tribe lives and score where they are today; letters as today;
  - edge arrows with a stone countdown for a hero off-screen.
- **Difficulty**:

  | Setting | Co-op Beginner | Co-op Expert |
  |---|---|---|
  | Twin windows | 24 ticks | 12 ticks |
  | Raptor daze | 14 ticks | 12 ticks |
  | Leash (off-screen time before the egg) | 5 s | 3 s |
  | Hatch hearts | 2 | 1 |
  | Unhatched egg | never returns | returns to the checkpoint after 10 s |
  | `lone` trait | off | on |
  | Boss grabs | off | on |

  The Beginner wall is unchanged. An optional assist, "Helper mode", makes P2 immune to enemy contact (eggs come only
  from pits); it does not change the gates.

---

## E. Deathmatch: Versus (same device, 2-4 players)

### E.1 The combat kit (all from the existing frame data; campaign values untouched)

**Attacks:**
- the forward strike: the fast poke, damaging from tick 5;
- the high strike: anti-air;
- the stomp: beats the crouch-charge;
- the crouch-charged strike: a launch, x4;
- thrown weapons: ranged, deflectable.

**Versus-only rules** (RESEARCH_VERSUS 2.3):
- **Clang**: two front boxes meeting push both apart with the Colossus clank; a charged strike wins.
- **Deflect**: a strike bats an axe back, now owned by the striker.
- **Stomp**: costs by the original's **bounce-multiplier ladder** (1-2-3-4-6-8 for a chain), and squashes the victim
  for 8 ticks.
- **Heads**: always springboards.
- **Thrown weapons stop at solid cells** in versus and lie there as pick-ups. **Spears stick in `&` walls** and stay
  there as steps for anyone.
- **Hurt timing**: 12 ticks stunned + 30 immune. The immunity ends when the victim strikes.
- **Hit-stop**: 2-4 ticks.

**Weapons**: everyone starts with the club, and the **Belt applies**. Specials come from pterodactyl crates, go
straight onto the belt, and are temporary: lost on a KO, or after 3 throws.

**Other:**
- Body bumps nudge rivals apart.
- Spawn rotation cancels the left-right physics asymmetry.

### E.2 Modes

| # | Mode | Rules in brief | Why it is this game |
|---|---|---|---|
| 1 | **Food Fight** (flagship, default) | rounds of 90 s (60 s with 2 players). A hit spills 1 + carried/5; a charged hit spills 1 + carried/2 and launches; a stomp spills by the ladder 1-2-3-4-6-8; a hazard spills everything (half bursts out, half is lost) and the victim respawns after 48 ticks. Food comes from **visible hidden spots that refill** (15 s), one big spot whose giant bonus **bonks heads**, and pterodactyl crates. The last 15 s are a **Feast Rush**: every spot refills and a second giant bonus falls. A tie is settled by the **Golden Drumstick**. First to 3 rounds wins | the original's scoring is the fight: club the world, food bursts, the bounce ladder, giants from the sky. Nobody is eliminated, and the leader carries the most and so loses the most |
| 2 | **Last Caveman Standing** (the literal deathmatch) | 3 hearts. A hit costs 1, a charged hit 2 plus a launch, a stomp 1, a hazard means out. **A lost heart bursts into 6 bones** that anyone can grab (the original's "stolen heart"). At 60 s a **themed sudden death** starts (E.4). Eliminated players ride **Grudge Pterodactyls** along the top and drop rocks (squawk 10 ticks first; a rock dazes, costs no heart). First to 5 rounds wins | hearts, bones and the stolen-heart rule are the original's energy system |
| 3 | **Letter Snatch** | 8-12 visible spots: five hold **G-R-U-B-S** (shuffled each round), the others food, a puff or a **skull**. Letters you hold float over your head. A hit drops your newest letter (charged: 2; hazard: all). A dropped letter left on the ground for 8 s burrows into a spot. **Holding all five for 44 ticks** brings down the 100 000 jackpot: round won. Most letters at 120 s wins | the original's bonus letters and hidden spots as capture-the-flag; whoever is about to win is plain to see, so the room turns on him |
| 4 | **Hot Rock** | a glowing ember sticks to one player and passes on any touch, hit or stomp (no pass-back for 44 ticks). The holder moves at most 96 v16. The fuse is 12-20 s and bubbles faster at the end; the holder pops (the death toss). Last one standing wins | one sentence to explain; perfect for kids, touch and bots; a palate cleanser |
| 5 | King of the Feast (second wave) | hold the giant roast for 20 counts; the carrier cannot strike (the glider rule); a hit drops it | needs the co-op carry code first |
| 6 | Egg Heist (second wave, 2v2) | carry a giant egg to your nest; a mother rex chases slow carriers | needs team bots |

- **Party Mix** picks a mode and an arena per round.
- **Presets**:
  - *Classic*: club only, no crates. The original's purity.
  - *Feast*: the default.
  - *Mayhem*: crates every 8 s, skull spots.
- **Variants** (rule toggles):
  - Hammer Time;
  - Big Bounce;
  - One-Bonk;
  - Lights Out: the night palette, with heroes glowing;
  - Gusty: random wind.

### E.3 Items (crates and spots)

Pterodactyl crates drop every 20 s (shipped pterodactyl + crate), down marked lanes, in sight of everyone:
- **food**: the shipped tiers, worth 1 / 2 / 5 / 10 in Food Fight;
- **specials**: hammer, axe, swirling axe, spear;
- **cutlery pieces**: three pieces make an 8 s **Feast** in which your touch knocks 3 food out of anyone and you are
  immune; the shake warns 7 ticks before the end;
- the **skull** (whoever touches it spills everything);
- the **grenade** (every rival spills 5).

There is no hidden rubber-banding: crate contents never depend on rank. The visible comeback tools:
- spills that grow with what you carry;
- a crown on the leader, whose hits spill 2 extra;
- a leaf shield for a player 2 rounds behind;
- the Grudge Pterodactyls.

### E.4 Arenas: 10 single screens (6 at launch, 4 unlocked by Cave Paintings)

Every arena is 20 x 11 cells (floor row 10, plus fill), locked camera (TECH_AUDIT option E), row 0 left free for the
HUD corners and the round sundial. Tiers are 3 rows apart; 5+ rows need a spring, a geyser or a head. Gaps are at most
5 cells, spawns rotate, and every lethal event is telegraphed 10+ ticks ahead.

| # | Arena | Biome | Edges | Signature | Sudden death (LCS) | Default mode |
|---|---|---|---|---|---|---|
| 1 | Vine Ring | jungle | wrap left-right | springs to wrapped ledges; a crown island reachable only off a rival's head | **Stampede**: chargers along the floor every 3 s, dust 22 ticks ahead | Food Fight |
| 2 | Echo Hollow | cave | wrap top-bottom (a shaft) | darkness pulse every 20 s (heroes glow), `$` walls that grow back | **Cave-in**: blocks fall from the top row inward | Letter Snatch |
| 3 | Frozen Pond | ice | open sides into icy water | ice floor, drop floes, gusts: ring-outs | **Whiteout**: gusts grow every 5 s | Last Caveman Standing |
| 4 | Cinder Pit | volcano | walls, lava below | obsidian slabs, an ember lane | **Lava rise**: 1 row per 44 ticks | Last Caveman Standing |
| 5 | Colossus Hall | keep | walls | the Wall Colossus as a neutral: every 10 s it spits at the **crowned leader** (jaws 10 ticks ahead) | stalactite storm | Food Fight / Hot Rock |
| 6 | Sky Picnic | Feast Land | wrap top-bottom, **no deaths** (kid-safe) | springs, icing clouds, a cake island | **Syrup flood** | Food Fight / Hot Rock |
| 7 | Mesa Ring (5 paintings) | canyon | walls | soft palisade walls (spear steps), Rollers crossing the floor | **Rockfall** from the mesa rim | Letter Snatch |
| 8 | Tar Pit (10) | swamp | walls | tar floor, two geysers, side mounds | **Tar rise** (the rising-tide code) | Last Caveman Standing / Food Fight |
| 9 | Tide Pool (15) | coast | walls | two rafts circling on a current over water, blowholes | **Rising tide** | Hot Rock |
| 10 | Cloud Top (20) | sky | wrap top-bottom | drop clouds, alternating gusts (crouch to brace) | **Lightning**: marked cells, 22 ticks ahead | Food Fight |

Sketches in the level format (`J` = spring, `G` = geyser, `D` = drop cloud, `:` = tar floor, `*` = big spot,
`?` = small spot, `|` = invisible wall). Each is to be checked with `tools/validate_levels.gd` and a bot walk.

**Vine Ring** (jungle, wraps left-right):

```
     col 01234567890123456789
row  0   ....................   HUD row: nothing to stand on
row  1   ....................
row  2   .......#?**?#.......   crown island: two small spots, the big-spot pair (its giant falls in from above the screen)
row  3   .......######.......
row  4   ....................
row  5   ----............----   wrap ledges: one 8-cell ledge across the seam
row  6   ....................
row  7   .....----..----.....   twin bridges, 3 rows over the floor, a 2-cell gap between them
row  8   ....................
row  9   ..J..............J..   springs (-224): rise 105 px, the wrap ledges are on the way down
row 10   ####?##########?####   floor with two small spots; it wraps too
row 11   ####################
```

Routes in Vine Ring:
- floor to bridge: a plain jump (48 px);
- spring to the wrap ledge;
- wrap ledge to the crown: a running jump (48 px up, 3 cells across);
- bridge to the crown is 5 rows (80 px): **only off someone's head**. The prize sits where you need a rival to reach
  it.

**Tar Pit** (swamp, walled):

```
     col 01234567890123456789
row  0   |..................|   HUD row
row  1   |..................|
row  2   |..................|
row  3   |..................|
row  4   |...====....====...|   log perches (one-way), 6 rows over the tar
row  5   |..................|
row  6   |..................|
row  7   |#?##..........##?#|   side mounds, 3 rows over the tar, small spots in their tops
row  8   |####..........####|
row  9   |####...G..G...####|   geysers: period 88 ticks, 22 ticks of bubbling, power -224
row 10   |####:::::**:::####|   tar floor (tap jumps only, about 30 px); the big spot is under the tar
row 11   |##################|
```

Rules of Tar Pit:
- From the tar nobody can jump back onto a mound (48 px). **The geysers are the only way out**, so a knock into the
  tar is a trap and a timing game.
- The big spot sits in the slowest place in the arena: its giant bonus lands in the tar, and the scramble for it is
  in slow motion.

**Cloud Top** (sky, wraps top-bottom; falling out of the bottom re-enters at the top):

```
     col 01234567890123456789
row  0   |..................|   HUD row; heroes falling through the bottom reappear here
row  1   |..................|
row  2   |..DDD........DDD..|   high drop clouds (fall 22 ticks after you land, come back)
row  3   |..................|
row  4   |..................|
row  5   |......#?**?#......|   cloud bank with spots and the big-spot pair
row  6   |......######......|
row  7   |..................|
row  8   |-----........-----|   side clouds (one-way)
row  9   |..................|
row 10   |...----....----...|   low clouds; nothing below them but the wrap
row 11   |..................|
```

### E.5 Bots: yes, at launch, for all four launch modes

- **A bot is an input producer** (TECH_AUDIT 4.9). Each tick it writes the same flags a player would.
  - It reads the previous tick's state.
  - It has its own `SimRng` seeded from the match seed and the slot. It never draws from `Sim.rng` and never knows
    what a spot contains.
  - So a bot match replays tick for tick, headless, like a route proof.
- **Navigation**: a graph per arena, baked offline. Nodes are standable spans. Links: walk, drop, hatch, jumps with k
  held ticks (from `PHYSICS_REFERENCE.json`), spring, geyser (timed by its period), vine, and wrap. **Every link is
  verified by simulating the real hero.** Rafts are moving nodes. Tide Pool and Tar Pit are the hardest: if their
  bots slip, those two arenas ship as human-only first.
- **Goals**, chosen every 6 ticks by utility: food, letters, the ember (flee / pass), spots, the leader, safety. Combat
  micro-rules come from the triangle: high strike against stompers, stomp against crouchers, charge at range, deflect
  axes.
- **Levels**:

  | Level | Reaction | Behaviour |
  |---|---|---|
  | Rookie | 10 ticks | never charges or deflects |
  | **Hunter** (default) | 6 ticks | stomps and charges |
  | Chief | 3 ticks | stomp chains; deflects 50 %; never frame-perfect |

- **Tests**:
  - 4 Hunters finish a round on every arena without getting stuck;
  - no hit lands within 48 ticks of a spawn;
  - win rates per spawn point stay within a band (the asymmetry check).

  The tests run headless in the slow suite.

### E.6 Match flow and results

1. **Lobby**: a carved panel with four slots. **Press jump on any device**, pick a colour, then *Add CPU* (level) or
   ready by holding strike. The lobby music is Spring Spring's Melon-Field character-select loop, written for a
   versus game.
2. **Rules**: mode, preset, rounds, time, crates, variants. Whoever pressed Start controls this screen.
3. **Arena**: thumbnails, Random or Party Mix. Locked arenas show their painting count.
4. **Round**: heroes burst out of spots. "3, 2, 1, GRUB!" plays as the kheetor countdown beeps plus `fanfare2`; no
   adult voice, to keep the 1994 sound. The round ends on a gong (`fanfare1`).
5. **Deciding moment**: the last 3 s replay at half speed. Food Fight shows the biggest spill instead. It is
   skippable. The simulation is deterministic, so the replay is an input log plus a snapshot.
6. **Scoreboard**: about 5 s. Round wins are drumsticks thrown onto each player's plate.
7. **Results**: a podium, and **the tally companion** (shipped `npc/companion`) hands out 1-3 awards per player:
   - Glutton: most food eaten;
   - Butterfingers: most dropped;
   - Pogo Stick: most head bounces;
   - Chain Gang: longest stomp chain;
   - Clang Master: most clangs;
   - Batter Up: axes deflected;
   - Lava Lover: hazard deaths;
   - Spot Hunter: spots opened;
   - Head Case: bonked by a giant bonus;
   - Comeback Caveman: won a round from last place.

   **Rematch** is the default button.
8. **Music**:
   - battle: Junkala Retro Sports stage_3, Tallbeard "Out of Time";
   - sudden death: Wolfgang_ "8-Bit Battle Loop";
   - match win: celestialghost8 "Victory".

### E.7 Controls for 2-4 on one device

- **Keyboard**: two players at most, as two halves. Same layouts as D.8; "Up jumps" is off in versus because
  Up + strike is the high strike.
- **Pads**: up to four, one slot each. Only direction + jump + strike (+ swap) are needed, so a sideways half
  controller works.
- **Touch**: one touch player on a phone, two on a tablet (mirrored corner clusters, 56 art px targets, a slider with
  crouch on slide-down, swipe-up on strike = high strike). Bots fill any empty slots.
- **Mixed**: any mix works. For example, keyboard halves for P1 and P2, pads for P3 and P4, or one tablet player
  against three bots.
- **Readability for 4**:
  - colours P1 yellow, P2 blue, P3 pink, P4 green (white on non-jungle arenas), from the staged `hero_colours`;
  - P1-P4 tags and colour arrows (`_style_tests/mp_ui_test.png`) at round start and whenever heroes overlap;
  - hit sparks in the attacker's colour;
  - four corner panels: a face icon (the recoloured Ninja Adventure caveman portraits), belly / hearts, and letters.

---

## F. Production estimate

### F.1 What has to be built

Sizes are in weeks of one engineer or designer, and are rough. Owners follow ARCHITECTURE 1.1.

**Engine and systems:**

| Package | Owner(s) | Size |
|---|---|---|
| **Wave 0: the N = 1 identity refactor**: PlayerSet, PlayerRun, GameInput slots and generated `pN_*` actions, contact order, N views and doze rectangles, the shake guard, death routing, digest freeze and guard test, multi-stream routes and the recorder (TECH_AUDIT 6.1) | core lead, with a time-boxed waiver | **L, 4** (blocking) |
| Bone Belt: `swap` action, hand/belt state, belt icon, Save v2, swap-prefix replays | player, core, ui, integration | S-M, 1 |
| Spear + soft walls `&` | player, world, objects | M, 1.5 |
| Vines (CLIMB state, rolled vines) | player, objects | M, 1.5 |
| Rafts + currents | objects, world | M, 1.5 |
| Tar, geysers, rising scroll | world, objects, player | M, 2 |
| Book II registry (`campaign` meta), book select, Far Shore map page, painting slab, Book II codes, Expert-wall picture | core, ui, objects | M, 2 |
| New archetypes: Roller, Guard, Mimic | enemies | M, 2 |
| 5 new bosses (B.1-B.3, B.5, B.6) + the Brute's temple columns | enemies | **L, 10** |
| Co-op core: group camera + edge walls + leash, eggs, team wipe, team exit and gate, PartyDriver hop / ride / toss | world, player | **L, 5** |
| Co-op objects: plate, column `hold` / `keepers`, drums, see-saw, heave boulder, flower pot, x2 tablet | objects | M, 3 |
| Co-op traits on all archetypes, 7 co-op-only enemies, co-op forms of 7 bosses | enemies | **L, 6** |
| Versus core: VersusReferee (PvP kit), arena format, crates, 4 modes, sudden deaths, Grudge Pterodactyls | world, core, objects | **L, 6** |
| Bots: nav-graph baker, HeroBot, 3 levels, headless tests | core | **L, 4** |
| UI: join panels, co-op and versus HUD panels, per-slot pause and options, key test, touch duo, versus lobby / rules / arena / scoreboard / results, tally medals | ui | L, 5 |
| Validator and tools: co-op solo-impossibility checks, arena checks, `--coop` previews | world | M, 2 |
| **Engine total** | | **about 57** |

**Content:**

| Package | Size |
|---|---|
| 20 Book II solo levels, including their club routes | 20 x 1 = **20** |
| 20 Book II co-op files | 20 x 0.5 = 10 |
| 15 Book I co-op files | 15 x 0.6 = 9 |
| 10 arenas + nav graphs | 10 x 0.3 = 3 |
| Two-player routes recorded with the recorder, then replayed | 4 |
| **Content total** | **about 46** |

**Art** (all compositing, recolouring and paint-outs):

| Package | Size |
|---|---|
| 5 x 2 terrain atlases and the tar strip | 1 |
| 5 parallax sets (tower paint-outs, gradient maps) | 1.5 |
| Enemy sheets: outline swap, recolours (about 14) | 1.5 |
| 5 boss sheets (Old Mangrove's fist and the Roc's 2x recolour are the hard ones) | 2 |
| `hero_spear` + egg / carry / toss frames + palette LUTs | 1 |
| UI pieces, map page, mural, x2 tablet, crests | 1 |
| **Art total** | **about 8** |

**Audio**: about 25 picks loudness-matched and loop-trimmed: about 1.5.

**QA, performance and the release pass**: about 6.

**Total: about 120 weeks of work.** After wave 0, about 6 module engineers, 3 designers and 1 artist can run in
parallel, which gives about **5-6 months of calendar time**.

### F.2 Content and proof counts

| Item | Count |
|---|---|
| New level files (solo) | **20** (11 main, 6 sub, 2 bonus, 1 ending) |
| Co-op level files | 35 (20 new + 15 Book I) |
| Arenas | 10 |
| New bosses / returning | 5 / 1, plus co-op forms for all 7 bosses (8 fights: the Brute twice, the Colossus, the 5 new ones) |
| New enemy archetypes / co-op-only enemies / co-op traits | 3 / 7 / 8 |
| Recorded solo routes, Book II | 36 (31 club + 5 featured), instead of 155 under today's rule |
| Generated swap-prefix replays | 31 (not recorded) |
| Recorded co-op routes, club / club | 57 (Book I: 11 Beginner + 15 Expert cells; Book II: 11 + 20) |
| Book I solo routes changed | **0** of 72 |
| Bot tests | 10 arenas x 4 launch modes |

The default `gd.sh test` suite should stay under about 5 minutes. The new route replays and bot matches go into the
existing `campaign_routes` slow module and a new `versus_bots` module.

### F.3 Order of work

1. **Wave 0** (one engineer, blocking). Exit criterion: an empty digest diff on all 72 routes, doze on and off;
   575 + new tests green; a bare two-hero level runs from two scripted streams.
2. **Wave 1**, in parallel:
   - Bone Belt + spear: lets the Book II designers start with the real weapon rule;
   - the co-op core (camera, eggs, hop / ride / toss);
   - the versus core;
   - the Book II systems (vines, rafts, tar, geysers, rising scroll).
3. **Wave 2**:
   - designers build worlds 5-7 (solo first, then the co-op file on the same skeleton);
   - the enemies module builds the archetypes and Tusker / Old Mangrove / Inkjaw;
   - bots;
   - the first 6 arenas.
4. **Wave 3**:
   - worlds 8-9, the Idols and the Roc;
   - the Book I co-op retrofits;
   - the paintings and the 4 unlockable arenas.
5. **Wave 4**: two-player route recording, performance on the A53 (two-hero `--perf` runs per world), touch table
   mode, the release pass.

### F.4 Riskiest parts

1. **Single-player drift in wave 0.** Hidden once-per-tick side effects can move single-player: the shake timer, the
   static platform guard, the event-driven respawn, feast music. *Mitigation*: the digest diff after every step and
   the permanent digest-guard test (TECH_AUDIT 4.12). The belt swap is a new input bit that is zero in every old
   route, and the digest proves that too.
2. **Co-op gates that one hero can cheese, or that a weak partner cannot do.** The head-bounce rule lets a hero skip
   any enemy, and spears, vines and spots add reach. *Mitigation*: keeper halls 3 rows high, the solo-impossibility
   validator, Beginner windows, egg-not-life failure, and every gate playtested with a mixed-skill pair.
3. **The group camera on vertical and auto-scroll levels** (Canopy Village, Cinder Shaft, Heart of the Mangrove).
   *Mitigation*: the camera follows grounded heroes only, and eggs are free.
4. **Performance on the Cortex-A53.** The 1.0 tick is already over its desktop proxy budget, and each extra hero adds
   about 100 µs on desktop (about 1-1.5 ms on the A53). *Mitigation*: 2-player co-op is the mobile target, 4-player
   versus arenas are small (fewer than 30 entities), and a hero performance pass comes before 4-player is enabled on
   mobile.
5. **Bots on moving geometry** (rafts, geysers, wrap). *Mitigation*: nav links verified by simulation, and
   human-only arenas as the fallback.
6. **Content volume**: 55 level files and about 93 recorded routes. *Mitigation*: Book II solo and co-op files share
   one skeleton, the club-only proof rule, and the multi-stream recorder.
7. **Boss art compositing quality** (Old Mangrove's root arm, the Roc's 2x recolour). *Mitigation*: style tests
   before code (as in `_style_tests`). The Idols and the Brute reuse shipped sheets.
8. **Input on one device**: keyboard ghosting, Android pad ids that change on reconnect, two touch players.
   *Mitigation*: the key test, the re-join dialog, and tablet table mode marked experimental.

### F.5 What to cut first if the scope must shrink (in order)

1. The **Grand Feast** marathon.
2. **Tablet table mode** for two touch players (keep one touch player plus pads).
3. Second-wave versus modes: already outside the launch scope.
4. **Bots for Tide Pool and Tar Pit** (human-only there).
5. **Unlockable arenas 4 -> 2** (Mesa Ring and Tar Pit stay).
6. **Rafts**. Replace them with ride platforms (`objects/platform mode=ride`) over water in 6-1, 7-1 and the ending.
   Inkjaw's phase 3 becomes sinking islands. This saves a system but loses the swamp and coast identity.
7. **Brute's Temple (8-1b)**: fold the rematch into the end of 8-1. Book II becomes 19 levels.
8. **Feast Land E**. Book II becomes 18 levels.
9. **Co-op gates in Book I's bonus stages and the Way Home**: keep the team exit only.

**Never cut**:
- the wave-0 N = 1 proof;
- the Egg Hatch;
- the Bone Belt (without it Book II needs about 155 routes);
- Food Fight;
- the co-op forms of the bosses.

---

## Appendix: new ids and format keys (for the contract owners)

| Kind | Id / key | Owner |
|---|---|---|
| Enemies | `enemies/roller`, `enemies/guard`, `enemies/mimic`, `enemies/shaman`; params `coop=<trait>`, `bond=<name>` | enemies |
| Bosses | `bosses/tusker`, `bosses/mangrove`, `bosses/squid`, `bosses/idols`, `bosses/roc` (Brute and Colossus gain co-op behaviour) | enemies |
| Objects | `objects/vine`, `objects/raft`, `objects/geyser`, `objects/plate`, `objects/drum`, `objects/seesaw`, `objects/boulder_heavy`, `objects/flower_pot`, `objects/hero_start slot=n`; `objects/column` gains `hold` and `trigger=keepers:<name>`; `objects/exit` / `objects/gate` team rules in co-op | objects |
| Items | `items/painting index=0..19`, `items/weapon kind=spear` | objects |
| Zones | `zones/current` (`dir`, `speed`) | world |
| Tiles | `&` soft wall (spear sticks), `:` tar floor | world |
| Meta | `campaign` (`first` / `far_shore`), `scroll = rising`, `liquid = tar`, `kind = coop` + `coop_of`, `kind = arena` (+ `players`, `round_time`, `items`) | world, core |
| Input | action `swap` (+ per-slot `pN_*` actions); route key letter for swap in input files | core |
| Specs | PHYSICS.md appendix "Book II and party rules" (belt, spear, climb, raft, tar, geyser, rising scroll, hop / ride / toss, egg, versus hurt table). Sections 1-15 do not change | specs |

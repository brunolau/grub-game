# DESIGN.md - Club & Grub 2.0 "The Far Shore": the binding expansion design

Status: **binding design** for the 2.0 expansion. Author: lead designer (expansion workflow), 2026-10-06; revised
2026-10-07 after gate G1 (phases 0-1 built, G1 passed on every automated criterion, phase 2 under way). Every number
marked *(tune)* is a starting value for playtests; every other number is derived from `docs/spec/PHYSICS.md`,
`docs/LEVEL_DESIGN.md` 12 or the research documents and is binding until a playtest changes it through this document.
What the builders resolved in code and the lead designer decided after G1 is listed in "Appendix: G1 and phase-2
resolutions" (markers **[Gn]**); the phase-3 targets of worlds 6-9, Feast Land E and the Long Raft Home are A.6.
Revised again 2026-10-08 at the start of phase 3: the orchestrator's phase-3 decisions (the idle partner, boss co-op
forms by actions, boss weak points clear of the HUD, bonded-pair placement, cut 2) and the lead designer's decisions
on the G2 reports are G33-G43 of the same appendix.

Inputs: `PROPOSAL_A_FAITHFUL.md` (the spine), `PROPOSAL_B_COOP.md`, `PROPOSAL_C_BOLD.md`, `RESEARCH_COOP.md`,
`RESEARCH_VERSUS.md`, `TECH_AUDIT.md`, the art and audio staging under `.tools/asset_candidates/`. The production plan
is `docs/expansion/PLAN.md`.

Units: **tick** = 1/24.2753 s (22 ticks = one "designer second"; 1 s = 24 ticks, 3 s = 73, 5 s = 121, 10 s = 243,
15 s = 364, 60 s = 1 457, 90 s = 2 185); **px** = logical pixel (1 cell = 16 px); **v16** = 1/16 px per tick. Hero
reach (LEVEL_DESIGN 12): standing jump 3 tiles, running gap 4 tiles (5 with a run-up to the right), head bounce with
Up held 105 px (6 tiles). Gravity 16 v16/tick, terminal fall 192 v16. Club power 25.

Order of authority is unchanged (ARCHITECTURE header): PHYSICS > GAMEPLAY > ASSET_MANIFEST > ARCHITECTURE. The
per-tick rules of every new system below are specified in `docs/spec/PHYSICS.md` Appendix C, the feature rules in
`docs/spec/GAMEPLAY.md` 13 and the level-building rules in `docs/LEVEL_DESIGN.md` 15 (plan step P0.2); the
ambiguities resolved on the way are listed in "Appendix: P0.2 spec resolutions" at the end (markers [Rn] in the
text). A playtest change of a *(tune)* value is made here first, then in those specs.

---

## 0. The expansion on one page

| Question | Answer |
|---|---|
| What ships | **Club & Grub 2.0**, a free update of the same app. Title > Play > **Solo / Co-op / Versus**. Solo and Co-op continue to **Book I: The First Feast** (the 15 shipped levels) or **Book II: The Far Shore** (20 new levels). |
| Book II | 20 level files counted the way 1.0 counts its 15: **11 map stops + 6 linked sub-stages + 2 Feast Lands + 1 playable ending**, in five new worlds: 5 Sunbaked Canyon, 6 Tar Fen, 7 Coral Coast, 8 Idol Ruins, 9 Sky Spire. Beginner plays worlds 5-7 (11 files); Expert plays all 20. Expert wall before world 8. |
| Bosses | **6 new**: Tusker the Boar King, Old Mangrove (the Rooted Guardian, the original's third boss type that 1.0 never built), Inkjaw the Grotto Squid, the Twin Idols, the Storm Roc, and the final **Rival Chieftains** Gorm and Gulla, who fight with our own co-op moves. The Brute and the Wall Colossus get co-op forms. Every boss has a solo form (club-beatable) and a co-op form that one hero cannot beat. |
| New for everyone | The **Weapon Belt** (the club is never lost; one special rides on the belt; a new Swap button), the **spear** (sticks in bark boards as a step), **vines**, **tar**, **geysers**, **rafts and currents**, the **rising tide**, **Chomper the rex** (a mount that eats enemies), three new enemy behaviours (Roller, Guard, Mimic), and **30 Cave Paintings** that unlock versus content. |
| Co-op | **Exactly 2 players**, local (keyboard halves, pads, one touch player; the tablet table mode stays a hidden prototype [G37]). One shared **tribe camera**, **Egg Hatch** revive, **tribe lives** (a life is lost only when both are down). A co-op version of all 35 stages, each its own `<id>_coop.lvl`. **The enemy structure changes**: every enemy record in a co-op file may carry a co-op trait (shell, bond, daze, heavy, lone, grab, leech, split) and 7 co-op-only enemies exist; every co-op stage has at least two gates on the main path that one hero cannot pass, proven by a search. Duo verbs: **Shoulder Hop, Totem Ride, Batter Up, Brace Wall**. |
| Versus | Same device, **2-4 players**, bots fill empty slots. Flagship **Grub Stack**: food you grab stacks on your head, hits knock it off, stomps steal it, a cookpot banks it. Launch modes: Grub Stack, **Last Caveman Standing**, **Hot Rock**, **Clubball**. **10 single-screen arenas** (8 at launch, 2 unlocked by paintings). Deterministic bots (Rookie / Hunter / Chief). |
| Single-player 1.0 | Book I solo plays exactly as 1.0.0: its 15 level files and 72 route files stay byte-identical and replay tick for tick, proven by per-tick digests and a permanent guard test. Book I solo keeps the 1.0 weapon rule (no belt). |
| Art and audio | Everything **CC0**. The anchor artist's own CC0 packs (RPG Battle System, Ninja Adventure, Western FPS 2D) plus recolours and composites of shipped art. No CC-BY file ships. |
| Proofs | One club route per (Book II stage, difficulty) proves every weapon (fresh-club rule + belt-invariance test): **31 solo routes** instead of 155. **57 two-stream co-op routes**. Solo-impossibility search on every co-op gate. Headless bot matches on every (arena, mode). |

**Owner decisions** (this design applies the recommended default of each; a different answer changes only the named
parts):

| # | Decision | Recommended default (applied) | Alternative and its cost |
|---|---|---|---|
| 1 | What "20 more levels" counts | 20 level files counted the way 1.0 counts its 15 (17 stages + 2 Feast Lands + 1 ending) | 20 playable stages: +3 files (+~4 ew, +6 routes) |
| 2 | Weapon rule in Book I solo | exactly 1.0 (no belt, Swap ignored) | belt and Swap in Book I too: routes still replay (none presses Swap); one extra invariance check |
| 3 | Book II availability | open from the start | unlocked by finishing Book I in that mode (shuts Beginner-only players out) |
| 4 | Co-op player count | exactly 2 | a 3-4 player "party" co-op later, without designed gates |
| 5 | Licences | CC0 only; no CC-BY file (the Gregor Quendel crowd cheer and Wolfgang_'s CC-BY themes stay out) | accept CC-BY files with attribution in CREDITS and the credits roll |
| 6 | Versus announcer | no adult voice: beeps and chiptune jingles | the Kenney CC0 voice lines ("round one", "sudden death") in versus only |
| 7 | Release form | a free 2.0.0 update of the same app, 1.0 saves migrated | a separate product or paid add-on |

**Why A is the spine** (scores in PLAN.md 1): it is the most faithful, the cheapest with the art that really exists,
and the easiest to prove. From B we take the co-op-native final boss (Rival Chieftains on hero physics), the role
vocabulary of the co-op enemies, the Tar Pulleys and Mesa Rodeo arenas, Chomper's two seats, the drift hash of co-op
files and the duo route macros. From C we take the fresh-club belt with its invariance test, Batter Up and Brace
Wall, the bark-board spear, Grub Stack, Clubball and the scouting egg. Rejected (section C.10): B's "one map, two
keys" and Carry & Throw, C's three-mount stable, stage clocks, low gravity, zip-lines, bola and co-op overlays.

---

## A. Campaign - Book II: The Far Shore

### A.1 Entry, story, map, registry

- **Entry.** Title > Play > Solo / Co-op / Versus. Solo and Co-op open a **book select** with two carved slabs, then
  Beginner / Expert, then the world map of that book. **Book II is open from the start** (Beginner players never
  finish Book I because of the expert wall; locking Book II behind it would shut them out). Each (mode, book,
  difficulty) has its own save slot, high-score table and level select. Book II has level codes (solo only, as Book
  I); co-op continues from the save.
- **Story** (two still pictures composed in-engine from shipped sprites, plus signs and the map banner, the 1.0 way):
  at the homecoming feast after the Way Home, the two chieftains of the **Tar Tribe**, Gorm and Gulla, swoop down on
  their **Storm Roc** and carry off the **Great Roast**. Grub (P1, the 1.0 hero) and his cousin Munch (P2, blue) lash
  logs into a raft and follow the trail of crumbs across five lands. Every boss has eaten a share of the roast and
  coughs up the fire-starter for the next exit totem. The Roc is brought down above the clouds; the chieftains make
  their last stand at the pyre on the spire top; the ending is the long raft voyage home. In solo, Munch waves from
  the map and from the tally companion's side.
- **Map.** A second 1280 x 360 map page, `ui/world_map_far_shore.png`, east of the home islands: the 1.0 sea and sky
  with five islands (a red mesa, a tar delta with a giant mangrove, a coral coast with sea stacks, an idol isle behind
  a temple gate, a spire into a storm cloud), joined by a dotted raft route. A stone slab in the lower-right corner
  holds the Cave Painting slots (C.9). As in Book I, only `main` levels are map stops.
- **Registry.** New meta key `book` (int, default 1; Book II files say `book = 2`). `Levels.get_campaign(difficulty,
  book)`, `next_level`, the map and the route tests filter by it. Book I files get the default and stay
  byte-identical. Co-op files (`kind = coop`) and arenas (`kind = arena`) never appear in a solo registry query.
- **Carried state inside Book II**: score, lives, letters (a fresh G-R-U-B-S set in worlds 5-7), and hand + belt
  (C.1). The glider is removed at the tally, as in Book I.

### A.2 The 20 levels

Difficulty on one scale for both books (Book I: 1-1 = 1, 1-2 = 2, 2-1 = 3, 2-2 = 4, 3-1 = 5, 3-2 = 6, 4-1 = 7,
4-2 = 8, 4-2b = 9). Mode: **B** = Beginner and Expert, **E** = Expert only (`min_difficulty = expert`).

| # | Id | Name | World | Kind | Mode | Signature mechanic | Diff. |
|---|---|---|---|---|---|---|---|
| 1 | `w5_l1` | Red Mesa Trail | 5 Sunbaked Canyon | main, order 110 | B | **Belt + Swap** and the **spear** taught; bark boards on palisade walls; long sand slopes with **Rollers** | 3 |
| 2 | `w5_l2` | Rattlesnake Gulch | 5 | main, order 115, `tally = false`, `bonus = bonus_d` | B | vertical gulch: **vines** and rolled vines; rattlers in burrows; warp to Feast Land D up two spear steps | 4 |
| 3 | `w5_l2b` | Tusker's Wallow | 5 | sub | B | **Boss: Tusker the Boar King** in a mud wallow | 4 |
| 4 | `w6_l1` | Bubbling Fen | 6 Tar Fen | main, order 120 | B | **tar** floors, **rafts** on slow currents, **Chomper the rex** tamed and ridden across the tar flats | 5 |
| 5 | `w6_l2` | Spore Hollow | 6 (mushroom cave) | main, order 125, `tally = false` | B | darkness lit by glowing caps, mushroom springs, spore **geysers**, Puffcap snappers | 5 |
| 6 | `w6_l2b` | Heart of the Mangrove | 6 (inside a hollow tree) | sub | B | **rising tide of tar** up the trunk on vines, then **Boss: Old Mangrove** | 6 |
| 7 | `w7_l1` | Shell Beach | 7 Coral Coast | main, order 130, `bonus = bonus_e` | B | surf currents and rafts, blowhole geysers, leaping fish, Chomper over urchin beds; warp to Feast Land E on a sea stack | 5 |
| 8 | `w7_l2` | Sea Caves | 7 (coast cave) | main, order 135, `tally = false` | B | dark caves, driftwood drop floes over deadly water, octopus lurkers, bark boards on drift-logs | 6 |
| 9 | `w7_l2b` | Squid Grotto | 7 | sub | B | **Boss: Inkjaw**; **last Beginner stage** (expert-wall picture) | 7 |
| 10 | `w8_l1` | Overgrown Steps | 8 Idol Ruins | main, order 140 | E | stair puzzles of **rising columns** on trigger plates, **Guards**, **Mimic** chests, vines through the roof | 7 |
| 11 | `w8_l2` | Hall of Idols | 8 (ruins interior) | main, order 145, `tally = false` | E | a maze of gates and one-screen secret rooms, darkness, spike pits, Guards in 4-row halls | 8 |
| 12 | `w8_l2b` | Idol Court | 8 | sub | E | **Boss: the Twin Idols** (one fixed screen) | 8 |
| 13 | `w9_l1` | Cloudbreak Climb | 9 Sky Spire | main, order 150, `tally = false` | E | vertical climb: vines, steam geysers, drop clouds, harriers in updrafts | 8 |
| 14 | `w9_l1b` | Thunderhead Glide | 9 | sub | E | **glider crossing** through a storm; lightning marks its column 22 ticks ahead; dive-scoring harriers | 8 |
| 15 | `w9_l2` | The Roc's Spire | 9 | main, order 155, `tally = false` | E | the gauntlet: alternating gusts (crouch to brace), crumbling clouds, tar pockets, Guards and Rollers | 9 |
| 16 | `w9_l2b` | Storm Nest | 9 | sub | E | **Boss: the Storm Roc** on the nest (beaten with the glider dive) | 9 |
| 17 | `w9_l3` | Chieftains' Pyre | 9 | main, order 160 | E | a short climb past the Tar Tribe camp, then **final boss: the Rival Chieftains**; the Great Roast is the trophy | 10 |
| 18 | `bonus_d` | Feast Land D: Honey Falls | feast | bonus (from 5-2) | B | honey floors (tar in candy skin), soda geysers, honeycomb walls full of spots | 2 |
| 19 | `bonus_e` | Feast Land E: Pudding Lagoon | feast | bonus (from 7-1) | B | wafer rafts on a syrup current under a rain of fruit | 3 |
| 20 | `ending_b` | The Long Raft Home | coast / village | ending | E | playable credits on a raft past every island; the home beach shows THE END (the mural if all 30 paintings are found) | 2 |

Linking: `w5_l2 -> w5_l2b`, `w6_l2 -> w6_l2b`, `w7_l2 -> w7_l2b`, `w8_l2 -> w8_l2b`, `w9_l1 -> w9_l1b`,
`w9_l2 -> w9_l2b` (`tally = false` on the first half, as 1.0). `w9_l3` drops `items/trophy` (the Great Roast), which
leads to `ending_b`. Map stops: 11, `order` 110-160 as listed (Book I uses 10-80, so the two books never collide).

Placements across the book:
- **Letters G-R-U-B-S**: 5-2 G, 6-1 R, 6-2 U, 7-1 B, 7-2 S (all in Beginner range, as in Book I).
- **Cutlery**: one full feast kit per world.
- **Specials**: spear in 5-1 (at the first checkpoint, before a bark board with a painting above it), hammer in 6-1,
  axe in 7-1, swirling axe in 8-1, spear again in 9-1. None is ever needed (C.1 rule 6).
- **Cave Paintings**: one per level (C.9).
- **Expert-only enemies**: the per-record `expert` flag in every level, as 1.0.

### A.3 Level notes (what each designer must hit)

The exact phase-3 targets of worlds 6-9, Feast Land E and the Long Raft Home (sizes, meta, codes, checkpoints, enemy
budgets, signs, painting places, co-op gates) are in A.6.

**World 5 - Sunbaked Canyon** (the re-entry world: wide, bright, forgiving).
- **5-1 Red Mesa Trail** (about 220 x 30 cells). Opens on the beach where the raft lands. The first sign teaches the
  belt ("Your club never leaves you. Press SWAP.") before the first enemy. The spear lies at the first checkpoint in
  front of a palisade with a bark board; a painting sits two boards up. The second half runs down long sand slopes
  where Rollers curl and roll at the hero; head bounces over them reach mesa-top secrets.
- **5-2 Rattlesnake Gulch** (about 80 x 90, vertical). Vines up the walls; snake burrows behind hatches; **rolled
  vines** on ledges that one strike unrolls (shortcuts for the next attempt). The Feast Land D warp sits on a ledge
  reachable only by two spear steps - the "aha" use of the new weapon, optional by design.
- **5-2b Tusker's Wallow**: a short approach, a checkpoint, then the walled arena (B.1).

**World 6 - Tar Fen** (slower, stickier, darker).
- **6-1 Bubbling Fen** (about 230 x 40). Teaches **tar** (you sink in and only tap-jump) and **rafts** on slow
  currents (a forward strike on a raft paddles it). At the second checkpoint **Chomper** is stuck behind a rock fall:
  three head bounces in a row tame him (C.8); the second half crosses tar flats on his back (he wades `:` at full
  speed and eats the slime walkers). Gnat zones bring back the flies and the water bucket. The hammer lies on a raft
  that drifts past a secret.
- **6-2 Spore Hollow** (about 200 x 60). A mushroom cave in near darkness (dark zones); glowing caps mark the way;
  caps are springs; spore geysers lift drop platforms. Puffcaps (snapper skin) bite from the dark; their wind-up glow
  is the telegraph.
- **6-2b Heart of the Mangrove** (about 40 x 120). Up the hollow trunk while tar rises 1 px per tick behind you
  (`scroll = rising`), with vines, roots and burrowing bugs; an `autoscroll_stop` zone at the top opens into Old
  Mangrove's chamber (B.2).

**World 7 - Coral Coast** (a breather after the swamp, then the hardest Beginner stretch).
- **7-1 Shell Beach** (about 240 x 40). Surf currents carry rafts between sand bars, blowholes throw rafts and heroes
  onto sea stacks, leaping fish, gulls. A Chomper pen before the urchin beds (floor spikes `^` he walks over). The
  Feast Land E warp is on the tallest sea stack (blowhole + vine).
- **7-2 Sea Caves** (about 200 x 60). Driftwood drop floes over dark water, octopus lurkers on the ceilings, bark
  boards on drift-logs for spear steps.
- **7-2b Squid Grotto**: Inkjaw (B.3). Clearing it ends the Beginner run with the expert-wall picture: *"Only an
  expert eater may climb to the Roc!"*

**World 8 - Idol Ruins** (Expert; the castle world).
- **8-1 Overgrown Steps** (about 200 x 60). A temple stair puzzle of **rising columns** that move when you step on
  trigger plates; Guards that turn slowly toward you; Mimic chests among real ones; vines through the ruined roof;
  the swirling axe.
- **8-2 Hall of Idols** (about 180 x 70). The original's gate-and-secret-room craft at full strength: a maze of gates
  (`objects/gate` with `lock=`), each a one-screen room, plus darkness, spike pits and Guards in 4-row halls where
  nobody can bounce over them (the Guard art is 54 px tall [G4]).
- **8-2b Idol Court**: the Twin Idols (B.4).

**World 9 - Sky Spire** (Expert; the climb to the Roc).
- **9-1 Cloudbreak Climb** (about 60 x 150, vertical). Vines, steam geysers, drop clouds; harriers and darts in the
  updrafts; bark boards in soft cloud-rock; the spear returns.
- **9-1b Thunderhead Glide** (about 250 x 20). Take the glider, run up, cross a storm; lightning marks its column 22
  ticks ahead; dive-attack harriers for the 1 000 / 5 000 / 10 000 ladder.
- **9-2 The Roc's Spire** (about 220 x 50). The exam: alternating gusts (Blizzard Pass's crouch-to-brace),
  crumbling drop clouds, tar pockets, Guards and Rollers, a checkpoint before every section.
- **9-2b Storm Nest**: the Storm Roc (B.5).
- **9-3 Chieftains' Pyre** (about 60 x 40). A short climb past the Tar Tribe camp, a checkpoint, then the final fight
  (B.6).
- **Feast Land D** (honey floors use the tar rules in a candy skin; soda geysers; honeycomb walls full of spots) and
  **Feast Land E** (wafer rafts on a syrup current, fruit rain): food-made and enemy-light, as Feast Land A-C.
- **The Long Raft Home**: a raft on a gentle current past the five islands; credits on floating signs; food rains
  from the Roc's broken hoard; no failure state; the home beach is the exit.

### A.4 Difficulty curve

| Book | Beginner part (play order -> difficulty) | Expert-only part |
|---|---|---|
| I | 1-1 **1**, 1-2 **2**, 2-1 **3**, 2-2 / 2-2b **4**, 3-1 / 3-1b **5**, 3-2 **6** | 4-1 **7**, 4-2 **8**, 4-2b **9**, Way Home |
| II | 5-1 **3**, 5-2 / 5-2b **4**, 6-1 **5**, 6-2 **5**, 6-2b **6**, 7-1 **5**, 7-2 **6**, 7-2b **7** | 8-1 **7**, 8-2 / 8-2b **8**, 9-1 / 9-1b **8**, 9-2 / 9-2b **9**, 9-3 **10**, Raft Home |

Book II re-enters at world 2's level (3): newcomers get a re-warm, veterans get new toys at once. 7-1 is a deliberate
dip after the swamp boss. The Beginner run ends at 7, one above Book I's; Expert peaks at 10.

### A.5 Enemies of Book II

Mostly **new species on the 13 existing behaviours** (skins), plus **three new behaviours** in the same spirit: one
parameterised state machine each, no projectiles (only bosses throw things), heads always safe to bounce on.

| Archetype (GAMEPLAY 5.2) | Book II species (sprite source, section F.1) |
|---|---|
| 0 Dropper | slime blobs (RPG `slime`, 2 palettes) in the fen; sea snails on the coast (shipped `turtle_b` + anchor shell item 18) |
| 2 Dangler | cave bats (RPG `bat`) in the gulch; octopus on a kelp thread (Ninja `Monster/Octopus` 2x) in the sea caves |
| 3 Lurker | scarabs (shipped `insect`) in the ruins; octopus (Ninja `Monster/RedOctopus` 2x) on sea-cave ceilings |
| 4 Swinger | swinging bats (shipped `bat_b`), rare as in the original |
| 5 Stinger | swamp mosquitoes (shipped `insect_b`, recoloured) |
| 6 Harrier | desert eagle (Sunny Land eagle 2x), gull (shipped `pterodactyl` recoloured white), ruin ghost (RPG `ghost`), storm pterodactyls |
| 7 Dart | eagle dive, storm pterodactyl (shipped `pterodactyl_b`) |
| 8 Hopper | swamp frogs (Sunny Land frog 2x), temple raptors (shipped `mini_rex_b`) |
| 9 Walker / Flyer | tortoises (shipped `turtle`), grubs (Ninja `Monster/Larva` 2x), jelly flyers (RPG `slime` recoloured translucent blue) |
| 10 Digger | burrow snakes (RPG `snake`, red and green), mangrove bugs (shipped `lizard`) |
| 11 Leaper | leaping fish (Ninja `Animal/Fish` 2x, plus a red recolour), cloud drakes (shipped `dragon_b`) |
| 12 Charger | desert tribesmen (shipped `rival`, Tar Tribe palette); heavy charger = shipped `rex_b` |
| Snapper | rattler in a hole (RPG `snake`), cave bear (Western FPS bear: idle, claw = bite, hurt, death), Puffcap (RPG `mushroom`, spore burst = bite), shipped `plant` |
| **13 Roller** (new, `enemies/roller`) | RPG `dino` (rolls into a ball). Walks; within `range` [6] tiles it curls (14-tick visible tuck) and rolls at the hero; follows slopes, +4 v16/tick downhill (cap 96); bounces off a wall and is **dizzy 33 ticks** (hittable); a head bounce on the ball is safe. Params `range`, `speed` [64], `dizzy` [33] |
| **14 Guard** (new, `enemies/guard`) | RPG `reptile` (GUARD animation; armour recoloured bone and stone). Patrols, holds its shield toward the hero and **turns only every `turn` [33] ticks**. Front hits glance with the Colossus clank and spark; back hits count. Solo answer: bounce over it and strike before it turns. Teaches the pincer that co-op then demands |
| **15 Mimic** (new, `enemies/mimic`) | the shipped container chest (`sprites/objects/chest.png`) with pixel-edited tells (a shudder, eyes in the lid gap, fangs) [G24]: waiting, it is drawn exactly as `objects/container skin=chest`, never mirrored. A hero on its floor within 2 tiles makes it shudder 10 ticks, then it bites (snapper rules); dies to a strike from behind or a head bounce + strike; killed, it drops a treasure. The original's cruel joke (the skull) as an enemy |

The three new archetypes live in `scripts/enemies/`, declare their doze rule (ARCHITECTURE 11.1), and Book I never
spawns them.

### A.6 Phase-3 briefs: worlds 6-9, Feast Land E, the Long Raft Home

Exact targets for D6, D7, D8 and D9 (PLAN 6.1; world 5 and Feast Land D are D5's from the slice). The numbers below
are binding; the layouts are the designers'. A designer who needs to change a number asks the lead designer in
`build/engine_requests/` first. Everything not named follows A.2-A.5, B, D.8-D.10, `docs/LEVEL_DESIGN.md` 15 and the
per-level recipe of PLAN 6.2.

**Rules for every brief.**
- Sizes are targets within +/-15 %. Checkpoints as listed: one before the first lethal use of each new mechanic and
  never more than about 60 s of Beginner play apart; the co-op file adds one behind every gate (a team wipe resets
  plates, drums, columns and keepers).
- Enemy budget "B / +E": records placed on both difficulties / extra records flagged `expert`. In an Expert-only
  stage every record is unflagged and the number is the total.
- Signs: the listed keys go into the designer's own locale file; at most 3 board lines, about 60 characters [G27]; the
  quoted text is the suggested English. A sign stands before the mechanic, never where it can kill.
- Solo files never hold `objects/plate`, `drum`, `boulder_heavy`, `pulley`, `flower_pot`, `x2_tablet` or
  `hero_start` (the validator refuses them): a solo "trigger plate" is a 1.0 `objects/column trigger=c,r,w,h`
  dressed with a plate prop. `objects/seesaw`, geysers, vines, boards, rafts and mounts are fine in solo.
- Feast kit: all three `items/feast_piece` in the stage named, the third shortly before a dense enemy stretch.
- Paintings (C.9) off the main path; one that needs a special or a side path gets a featured route
  `<id>.painting.inputs` (header `belt=<special>` when the special must ride on the belt).
- Co-op file (D.8, LEVEL_DESIGN 15.7): the gates listed, each with its `objects/x2_tablet`, a drop gift where one hero
  ends above the other and a checkpoint behind; traits on at least a third of the records and on every chokepoint
  guard; specials in pairs. A co-op file may leave out solo records that would hand a lone hero a bounce at a height
  gate or hit a role holder (D5 did so in 5-1 [G22]); the trait share counts what remains. A gate marked
  **(search decides)** is replaced by its named fallback when `test_coop_gates` does not refuse it.
- Height gates keep every booster (spring, geyser, vine, bark board, platform path, bounceable enemy, glider, pen)
  out of the static reach (10 cells across, 11 rows below the ledge top; boards 12 cells from any gate).
- **Bonds** (every "bonded ... pairs" below) [G36]: no bond whose members one thrown special (axe, swirling axe, spear:
  they pass walls and fly about 520 px) can hit in one throw from any strike spot of either member - separate them by
  height, or use another trait (`lone`, `daze`); the search's `pair_solo_min` of 0 is a build error. The trait lists
  below are suggestions under that rule.
- **The idle partner** [G33]: a hero whose player pressed nothing for 243 ticks counts for no co-op rule, so in a
  two-stream route no role waits 243+ ticks without input (a plate holder crouches: Down held is input).

| Stage | By | Size (cols x rows) | `terrain_a` / `terrain_b` | `background` | `music` | `liquid` | `bonus_tier` | Codes B / E | Checkpoints |
|---|---|---|---|---|---|---|---|---|---|
| `w6_l1` Bubbling Fen | D6 | 230 x 40 | swamp/terrain / swamp/terrain_bark | swamp | level_fen | tar | 1 | FENS / T4R5 | 4 |
| `w6_l2` Spore Hollow | D6 | 200 x 60 | swamp/terrain_mushroom / swamp/terrain | mushroom | level_spore | tar | 1 | SP0R / GL0W | 4 |
| `w6_l2b` Heart of the Mangrove | D6 | 40 x 120 | swamp/terrain_bark / swamp/terrain | mangrove | level_mangrove_climb | tar | 1 | R00T / MNGR | 3 + 1 before the chamber |
| `w7_l1` Shell Beach | D7 | 240 x 40 | coast/terrain_sand / coast/terrain | coast | level_coast | water | 1 | SHEL / SURF | 4 |
| `w7_l2` Sea Caves | D7 | 200 x 60 | coast/terrain_cave / coast/terrain | sea_cave | level_sea_caves | water | 1 | KELP / 1NKY | 4 |
| `w7_l2b` Squid Grotto | D7 | 60 x 20 | coast/terrain_cave / coast/terrain | sea_cave | level_sea_caves | water | 1 | SQU1 / JAWZ | 1 (before the arena) |
| `bonus_e` Pudding Lagoon | D7 | 200 x 30 | feast/terrain_pudding / feast/terrain_biscuit | feast | bonus_lagoon | syrup | 2 | - | 2 |
| `w8_l1` Overgrown Steps | D8 | 200 x 60 | ruins/terrain / ruins/terrain_jade | ruins | level_ruins | water | 2 | - / STEP | 4 |
| `w8_l2` Hall of Idols | D8 | 180 x 70 | ruins/terrain / ruins/terrain_carved | temple | level_idol_hall | water | 2 | - / 1D0L | 5 |
| `w8_l2b` Idol Court | D8 | 50 x 15 | ruins/terrain_carved / ruins/terrain | temple | level_idol_hall | - | 2 | - / TW1N | 1 |
| `w9_l1` Cloudbreak Climb | D9 | 60 x 150 | sky/terrain / sky/terrain_rock | sky | level_sky_climb | - | 2 | - / CL1M | 5 |
| `w9_l1b` Thunderhead Glide | D9 | 250 x 20 | sky/terrain_rock / sky/terrain | storm | level_storm_glide | - | 2 | - / ST0R | 2 |
| `w9_l2` The Roc's Spire | D9 | 220 x 50 | sky/terrain_rock / sky/terrain | storm | level_spire | tar | 2 | - / SP1R | 5 |
| `w9_l2b` Storm Nest | D9 | 50 x 15 | sky/terrain_rock / sky/terrain | storm | level_spire | - | 2 | - / R0CS | 1 |
| `w9_l3` Chieftains' Pyre | D9 | 60 x 40 | sky/terrain_rock / ruins/terrain_carved | pyre | level_pyre | tar | 2 | - / PYR3 | 2 |
| `ending_b` The Long Raft Home | D9 | 180 x 25 | coast/terrain_sand / jungle/terrain_grass | coast | ending_raft | water | 2 | - / RAFT | 0 |

Biomes: worlds 6 `swamp`, 7 `coast`, 8 `ruins`, 9 `sky`, `bonus_e` `feast`, `ending_b` `village`. Boss stages push
their boss music while the bar shows (the boss script). `-` under `liquid` = the default (no deadly liquid used).
The codes are unique across both books (D5 picks those of `w5_l2` / `w5_l2b` from the rest of 0-9 A-Z).

**World 6 - Tar Fen (D6).**
- **6-1 Bubbling Fen** (difficulty 5; letter R; painting 3; the hammer). (1) The landing shore: sign
  `SIGN_W6_TAR` "Tar holds your feet. Tap Jump to hop." before the first `:` field (6+ cells, flat, no enemy), a
  one-row step out of it (hoppable), later a tar pit walled 2 rows high with a vine as the way out. (2) The raft
  reach: sign `SIGN_W6_RAFT` "Strike forward on a raft to paddle."; a log raft on a current (`speed=1`, to the right)
  over 12-16 cells of open tar, then 8-10 cells without current that must be paddled; checkpoint 1 behind it. The
  hammer lies on the jetty of a side basin beside a raft (items do not ride rafts [G40]); the side current carries
  the raft to a stump that stops it: **painting 3** sits behind a `$` wall in that stump, reachable only by striking
  from the raft (featured route). (3) Checkpoint 2, then wild Chomper (`objects/mount
  kind=rex pen=fen wild`) pacing in front of a rock fall, a 2-row stump beside him to start the bounce chain; sign
  `SIGN_W6_REX` "Bounce on his head three times in a row." and, after him, `SIGN_W6_RIDE` "Down + Jump: get off."
  (4) The tar flats: 50-60 cells of `:` with slime walkers and frogs, mounted rules (gaps <= 4 cells, steps <= 3 rows,
  4 rows of air, no sprite platform); **the flats stay passable on foot** (slowly): Chomper is the reward, not a key.
  Letter R on a stump top over the flats (a mounted hop or a head bounce). (5) Checkpoint 3, the water bucket, then a
  gnat thicket (`zones/flies`) to the exit totem on firm ground. Enemies 16 / +6: slime droppers
  (`dropper skin=slime`), slime walkers, frogs (`hopper skin=frog`), mosquitoes (`stinger skin=mosquito`), one
  `snapper skin=plant`; Expert adds grubs (`walker skin=larva`), mosquitoes and one heavy charger (`charger
  skin=rex_b`) on the flats. **Co-op**: (a) **"sunk raft"** Batter Up gap - 8 cells (Beginner) / 9 (Expert) of `~` tar
  between two banks at one height, 4 rows of air, a landing area 2+ cells deep, no raft on that stretch; (b)
  **"thorns"** Chomper two seats (search decides; fallback: a 7 / 8-row boost ledge onto a mangrove root with a flower
  pot on a 2-row stump) - the flats end in a 6+-cell thorn bed (`^`) with tar before it (no run-up), under a 4-row
  ceiling with three `enemies/leech` that drop on riders: only a gunner's strikes clear them. Traits: Tar Splitters
  on the flats, `dropper coop=split skin=slime` blobs, bonded frog pairs.
- **6-2 Spore Hollow** (difficulty 5; letter U; painting 4; the world's feast kit). `dark = true` (or `zones/dark`)
  with glow props marking the way (`swamp/props/glowcaps`, `glowcap_big`: the lights of [G21]). (1) Sign `SIGN_W6_CAPS`
  "Glowing caps are springs." before the first spring cap (`objects/spring` with a cap prop). (2) Spore geysers
  (`objects/geyser skin=steam`, period 88) lifting drop platforms to upper shelves; sign `SIGN_W6_GEYSER` "Stand on the
  vent when it bubbles." (3) Puffcap snappers (`snapper skin=puffcap`) in the dark: their wind-up glow is the
  telegraph; never one at a landing spot. (4) The feast kit in the middle third, the third piece before the densest
  Puffcap / cave-bat stretch. **Painting 4** inside the big spot (`look=inset`) of the darkest side chamber, marked by
  a lone `glowcap_big`, up a spring cap off the main path. Letter U on a shelf reached by a geyser-lifted platform.
  Enemies 16 / +6: Puffcaps, cave bats (`dangler skin=cave_bat`), frogs, mangrove bugs (`digger skin=lizard`); Expert
  adds Puffcaps and bats. **Co-op**: (a) **"seesaw"** - a mushroom see-saw (`len=5`, high end 1 row over the floor), a
  cap ledge 4+ rows over the high end within 3 cells to drop from, the target 9 rows over the low end (glowcaps mark
  it), a rolled vine on top as the gift; (b) **"caps"** twin drums - two drums (`bond=caps`, glowing-cap skin) at
  least 10 cells and 4 rows apart, out of one axe's flight line, opening a stalk column `trigger=drums:caps`. Traits:
  Raptors in the hollow, bonded Puffcap pairs, `lone` mosquitoes.
- **6-2b Heart of the Mangrove** (difficulty 6; painting 5; boss B.2). `scroll = rising` with `rise_speed = 16`
  (`.expert` 20); sign `SIGN_W6_TIDE` "The tar is rising. Climb!" at the start. The trunk: vines (bottoms 1-2 rows over
  the ledges), root ledges, mangrove bugs; every climb leaves 4.5 rows of spare for a Beginner who stops 73 ticks;
  checkpoints every 25-30 rows of climb (the band restarts 6 rows under each). **Painting 5** at the top of a side vine
  3-4 cells off the climb (a detour of about 3 s, inside the spare). An `autoscroll_stop` zone below the chamber; a
  checkpoint; then Old Mangrove's chamber exactly as GAMEPLAY 13.6 (20 x 12, floor row 10, the Guardian in cols
  15-18 of the right wall, root ledges at rows 7 and 5 (the upper one ending at col 5), an 11-row camera lock whose
  last row is the floor, so the face and the resting hand stay clear of the HUD [G35]). Enemies 10 / +4 on the climb (bugs, cave bats, one Puffcap
  per 30 rows). **Co-op**: (a) **"vent"** heave boulder - a deadly tar vent (`objects/geyser deadly`) across the climb
  and a heave boulder on a ledge above it, 3+ cells of floor behind the pushed side, 2+ rows of air; give the push
  (6 ticks per tile for two heroes) its own 4.5 rows of spare; (b) the co-op Old Mangrove (B.2).

**World 7 - Coral Coast (D7).**
- **7-1 Shell Beach** (difficulty 5, the deliberate dip; letter B; painting 6; the axe; the world's feast kit;
  `bonus = bonus_e`). (1) Sand bars and surf: rafts on currents (`speed` 1-2) between bars; sign `SIGN_W7_SURF` "Ride
  the rafts. Water is deadly." (2) Blowholes (`objects/geyser skin=blowhole`) that throw rafts and heroes onto sea
  stacks; sign `SIGN_W7_BLOWHOLE` "A bubbling blowhole throws you up." (3) Leaping fish (`leaper skin=fish`) and gulls
  (`harrier skin=gull`) over the open water. (4) Checkpoint 3, a Chomper pen (`objects/mount kind=rex pen=beach`, tame)
  before the urchin beds (`^` floors he walks over, 4 rows of air, no sprite platform, a safe cell at each end of a
  bed for a dismount or a throw-off), the feast kit on the far side.
  The axe lies on a sand bar after the first raft reach. The **Feast Land E warp** (`items/warp`) on the tallest sea
  stack, reached by blowhole + vine. **Painting 6** on a drift-log stack two bark boards up (boards 3 rows apart on one
  face; featured route with `belt=spear`). Letter B on a sea stack reached by a blowhole. Enemies 18 / +6: fish, gulls,
  sea snails (`dropper skin=sea_snail`), tortoises (`walker skin=turtle`); Expert adds gulls and fish (red,
  `skin=fish_b`). **Co-op**: (a) **"stack"** Batter Up lob - a sea-stack shoulder 7 rows over a 3-row rock (10 rows
  over the beach), its face 2-3 cells from the curl spot, 9 rows of air over the curl spot; the warp stack's blowhole
  11+ cells away; (b) **"urchins"** Chomper two seats (search decides; fallback: a leapfrog plate door between two
  dunes) - the urchin bed 6+ cells with no run-up, two Snatcher gulls (`snatcher kind=stinger`) diving at the riders:
  the gunner swats them. Traits: bonded fish pairs from two pools, Snatcher gulls with a `perch` by the water, bonded
  sea-snail pairs.
- **7-2 Sea Caves** (difficulty 6; letter S; painting 7). `dark = true` in the deep half, glow anemones and coral
  (`coast/props/glow_*`) on the way. (1) Driftwood drop floes (`objects/drop_platform`, driftwood skin) over dark water
  - sign `SIGN_W7_FLOE` "Driftwood sinks. Keep moving."; (2) octopus lurkers on the ceilings (`lurker skin=octopus_b`)
  over the floe lines - never over the only floe of a crossing; (3) octopus on kelp threads (`dangler skin=octopus`);
  (4) bark boards on drift-logs for spear steps (shortcuts and the letter, never the main path). Letter S up two
  spear steps or a geyser; **painting 7** at the top of a kelp vine in a side shaft. Enemies 18 / +6: octopi, jelly
  flyers (`flyer skin=jelly`), sea snails, cave bats; Expert adds lurkers and jellies. **Co-op**: (a) **"seagate"**
  leapfrog plate doors - plate `pa` holds a sea gate (`rise_while=pa`, 8+ tiles away) while the partner rides the floe
  line through it; beyond, plate `pb` holds the second corridor's door for the holder (two corridors); (b) **"dark
  gap"** Batter Up line drive over 8 / 9 cells of dark water. Traits: Snatcher gulls over a pit (`grab`, perch at the
  pit), Leeches under the dark section, bonded octopus pairs.
- **7-2b Squid Grotto** (difficulty 7; painting 8; boss B.3; the last Beginner stage). An approach of 30-40 cells
  (driftwood floes, 4 / +2 enemies), **painting 8** behind a `$` wall in the approach, a checkpoint, then the arena of
  GAMEPLAY 13.6 (islands at cols 2-5, 8-11, 14-17 on surface row 9, root ledges at row 6). **Co-op**: the Tentacle Lock
  (B.3); the approach holds no gate.
- **Feast Land E: Pudding Lagoon** (`bonus_e`, difficulty 3; painting 18). Wafer rafts (`objects/raft skin=wafer
  width=4`) on a syrup current (`speed` 1-2) through deadly syrup, custard floors (`:`, the tar rules in pudding skin)
  on the jelly islands, a fruit rain (`zones/food_rain skin=fruit`) over every raft reach; spots everywhere; 4 jelly
  flyers (`flyer skin=jelly`), no Expert extras. The warp back (`items/warp`) on the last island. **Painting 18** in a
  big spot on a side island a raft passes only on a side current. Co-op: team exit only; a giant roast spot for two and
  Relay Bounce (D.9).

**World 8 - Idol Ruins (D8; Expert only).**
- **8-1 Overgrown Steps** (difficulty 7; painting 9; the swirling axe; the world's feast kit). (1) Sign
  `SIGN_W8_STEPS` "Step on the stone plate to raise the stair." - stair puzzles of rising columns on 1.0 trigger
  rectangles dressed as plates (three stairs, each 3-5 columns, `rise` 2-4); (2) Guards (`enemies/guard`) on terraces,
  sign `SIGN_W8_GUARD` "Its shield turns slowly. Strike its back."; (3) Mimic chests among real ones (`enemies/mimic`
  beside `objects/container skin=chest`), sign `SIGN_W8_MIMIC` "Not every chest is a chest." placed after the first
  Mimic has been seen shuddering from a safe distance; (4) vines through the ruined roof to an upper gallery. The swirling
  axe in a real chest at checkpoint 2; **painting 9** in a real chest between two Mimics on the roof gallery (up the
  vines). Enemies 22: Guards, Mimics (3), scarabs (`lurker skin=insect`), ruin ghosts (`harrier skin=ghost`), temple
  raptors (`hopper skin=mini_rex_b`). **Co-op**: (a) **"stairs"** - the stair columns rise while plates `pa` and `pb`
  are both pressed; a heave boulder (3+ cells of floor behind it) pushed onto `pa` holds it for good; one hero holds
  `pb` while the other climbs and holds `pc` at the top, which keeps a side door open for him (two corridors); (b)
  **"hall"** keeper door - two Shellbacks (`enemies/shellback speed=0`) in a hall exactly 4 rows high, bait 30 px in
  front, the striker's way in behind them. Traits: Shellbacks, Raptors (`daze`), `shell` Guards.
- **8-2 Hall of Idols** (difficulty 8; painting 10). A maze of one-screen rooms joined by `objects/gate` with `lock=`
  (6-8 rooms, 2-3 of them secret rooms), darkness, spike pits, Guards in 4-row halls; sign `SIGN_W8_GATES` "Press
  Down on an arch to go through." **Painting 10** in the secret room behind the third gate. Enemies 24: Guards, ghosts,
  scarabs, swinging bats (`swinger skin=bat_b`), raptors. **Co-op**: (a) **"rooms"** leapfrog plate doors between two
  rooms (each door held from the other room; two corridors); (b) **"shamans"** keeper door - a Shaman and two `shell`
  Guards as keepers (`keeper=<name>`) in a 4-row hall: the Shaman flees, two heroes pin him. Traits: Shamans,
  Shellbacks, bonded ghost pairs.
- **8-2b Idol Court** (difficulty 8; painting 11; boss B.4). An approach of 20-30 cells with **painting 11** behind
  `$`, a checkpoint, then the fixed screen of GAMEPLAY 13.6 (idols in both walls, a 2-wall-column x 7-row footprint
  each - one `bosses/idols` record just left of the right wall at floor level, the Moon Idol finds the left wall; an
  11-row lock whose last row is the floor keeps the open jaws 65 px under the view's top, clear of the HUD [G35]; the
  2-row altar at cols 8-11; ledges at row 6 in front of the jaws). **Co-op**: the
  Twin Hit (B.4; leave `hp` out, the co-op file gets 8 per idol by itself).

**World 9 - Sky Spire (D9; Expert only).**
- **9-1 Cloudbreak Climb** (difficulty 8; painting 12; the spear). Vertical: vines, steam geysers, drop clouds
  (`drop_platform`, cloud skin), harriers and darts in updrafts (`harrier skin=eagle`, `dart skin=storm_ptero`), bark
  boards in soft cloud-rock. The spear at checkpoint 1; **painting 12** two bark boards up (3 rows apart on one face)
  off the climb. Enemies 20. **Co-op**: (a) **"seesaw"** - a see-saw on a cloud shelf, the drop ledge 4+ rows over the
  high end reached by the path itself (no geyser or vine within the static reach of the target), the target cloud 9
  rows over the low end, a rolled vine as the gift; (b) **"pulley"** - two ride platforms 4+ cells apart between two
  cloud stacks, `range=6`, the target cloud level with the risen platform's top. Traits: `lone` harriers, bonded
  harrier pairs, a Snatcher bat. Spears in pairs.
- **9-1b Thunderhead Glide** (difficulty 8; painting 13). The glider on a runway at the start (24 ticks at speed to
  take off); lightning (`zones/lightning`, period 66) over the crossing, never two bolts on the only safe cell in a row;
  dive-attack harriers for the 1 000 / 5 000 / 10 000 ladder; sign `SIGN_W9_LIGHTNING` "A dark cloud marks where
  lightning strikes." **Painting 13** on a high cloud only a glider on lift reaches. Enemies 14. Checkpoint 2 on a
  landing cloud with a second glider. **Co-op**: (a) **"stormwall"** keeper door - a cloud column whose keepers are a
  bonded harrier pair circling in opposite directions 10+ cells apart, each reachable by a glider dive (two gliders
  on the runway).
- **9-2 The Roc's Spire** (difficulty 9; painting 14; the world's feast kit). The exam: alternating gusts (`wind` with
  negative values, `wind_loop`), a crouching spot before every gap (sign `SIGN_W9_GUST` "Crouch to stand firm in the
  wind."); crumbling drop clouds; tar pockets (`:`); Guards and Rollers; a checkpoint before every section (five).
  **Painting 14** in the big spot past the last gust gap, off the path on a cloud above it. Enemies 24. **Co-op**: (a)
  **"lee"** lee leapfrog [G21] over three gust gaps of up to 3 cells whose gusts never pause (no lull in `wind_loop`
  there), strong enough that a lone hero falls short (search decides; fallback: a Brace corridor); (b) **"drive"**
  Batter Up line drive over the final gap (8 / 9 cells); (c) a Brace corridor: a Bull Rex on a cloud bridge in a 4-row
  hall. Traits: Bull Rex, `shell` Guards, bonded Roller pairs on two slopes.
- **9-2b Storm Nest** (difficulty 9; painting 15; boss B.5). An approach of 20-30 cells, **painting 15** behind `$`, a
  checkpoint, the arena of GAMEPLAY 13.6 (nest one-way at cols 6-13 row 8, floor row 10 with a 4-cell runway each
  side, two drop clouds at row 5; the `bosses/roc` record standing on the nest; **place no glider** - the phase-3
  gliders appear on the nest by themselves, one per hero). **Co-op**: Snatch rescue and Pilot and Spotter (B.5).
- **9-3 Chieftains' Pyre** (difficulty 10; painting 16; final boss B.6). A short climb (about 25 rows above the
  arena) past the Tar Tribe camp (`sky/props/tribe_*`, `tent`, `pyre`): tribesmen (`charger skin=rival_tar`) and one Guard;
  **painting 16** in the big spot of the chieftains' tent; a checkpoint; then the arena of GAMEPLAY 13.6 (the Great
  Roast on an altar 3 tiles up at the centre, one-way; a see-saw and two plates on the floor; ledges 3 rows up and
  nothing standable higher, so a chieftain is never drawn under the boss bar [G35]; the floor open to both side
  walls, where the Roc perches are; the arena zone's rect includes the side walls). The
  chieftains run on hero physics over a bot graph core-B bakes for `w9_l3` / `w9_l3_coop`, so every ledge, the pyre
  and the altar must be reachable by a hero's jump; Gorm's record on the floor, Gulla's on the pyre (enemies-C's
  `wf8_enemies-C_to_D9.txt`). The trophy leads to `ending_b`. **Co-op**: the boss form only (both chieftains, the 66-tick egg race).
- **The Long Raft Home** (`ending_b`, difficulty 2; painting 19; no failure state). One `objects/raft rails width=4
  skin=log` on a current (`speed=1`) from the start to the home beach: the credits ride on floating signs at reading
  speed (paddling halves the trip); `zones/food_rain skin=food` stretches from the Roc's broken hoard; the five islands
  pass as props on sand bars (`props/coast/isle_{mesa,mangrove,stacks,idols,spire}`, back props on the surface row); no enemy, no cell at the
  raft's surface row before the beach, no vine within reach of the raft route (a hero who grabs one leaves the rails). **Painting 19** in a big spot in the underside of a rock arch 3 rows over the
  raft path (a high strike from the raft as it passes; missing it fails nothing). The beach is the exit: the docked
  raft's rails open towards it and the riders walk off [G45] (a team exit
  in co-op; one raft for two). One route, `ending_b.inputs` (Expert).

---

## B. Bosses

### B.0 Rules every boss follows

- **Telegraphs**: every attack shows itself **10 or more ticks** ahead, pinned per boss by a
  `tests/test_enemies_<boss>.gd` like `test_enemies_colossus.gd`.
- **Hit cooldown** `BOSS_HIT_COOLDOWN` (22 ticks) per boss: no stun-lock, attack clocks keep running through hurt
  poses, and two heroes cannot double the damage.
- **Head bounces** on a boss always bounce the hero and harm nobody.
- **Book II rule: every boss falls to the club.** Specials only make it easier. (Book I's Colossus keeps its
  thrown-only rule and the axe at its checkpoint.)
- **Defeat**: 64 bonus items plus the key item (fire-starter, or the trophy). Boss music while the bar shows. The
  key item can never be lost: it is thrown from over standable ground, and one that sinks comes back on standable
  ground [G30] [G52].
- **Co-op form**: hit points at most x1.25 and **one rule that one player cannot satisfy** [G34]. Wherever the design
  allows, the partner's own **actions** satisfy it - hits by two different heroes (a twin hit, two flinches, the tail
  strike of the hero who did not dive), a grab only the partner's hit breaks, a brace that needs two crouching
  bodies. A rule about where heroes stand (a guard that faces the nearer hero, an idol whose half holds a hero, the
  partner near the mate, the pin) counts only **active** heroes: an idle hero (D.3 [G33]) is nobody. A rule that needs
  two heroes' own hits is exempt from the `solo_min - 4` cap of D.4 (no single player can meet it at any speed): its
  window is the difficulty value. The solo search of D.8 - one hero with every weapon and an idle hatched partner
  placed anywhere he could be hatched - must fail to beat each co-op form; the boss test asserts it.
- **Weak points clear of the HUD** [G35]: the HUD band of a boss fight is the HUD as ui built it for phase 3
  (`Hud.band_rects`): the top row across the whole width, 31 px deep on a phone or tablet (27 on a computer), and
  under it, in the boss bar's columns (from 53 px left of the view's centre to 38 px right of it), down to 48 px; in
  co-op the letters give way and P2's panel moves up into the row while a boss bar shows. Every rectangle a counted
  hit must touch lies wholly inside the locked view, in every pose in which it can be struck, with its top at least
  **24 px below the band** over its columns: **55 px** under the view's top, **72 px** in the boss bar's columns. With
  the floor on the last row of an 11-row lock that is at most 105 px (88 px in the bar's columns) over the floor's
  top. Camera locks and arena geometry keep it so; each boss test pins it on its arena (`Hud.weak_point_problem`).
  Book I's solo boss rooms are frozen and exempt.

Hit points are in club hits (25 each; a charged hit counts 4). Archetype 6.2 / 6.3 bosses count 1 per hit.

### B.1 Tusker, the Boar King (`w5_l2b` Tusker's Wallow)

- **Art**: RPG `boar` (239 x 178 cells; idle, walk, charge, spin-ball, hit, death) at native 1x - body about
  75 x 55 px, twice the hero's height. Outline to `#272018`, tusks lengthened by pixel edit, palette 2 for rage.
- **Arena** (as built [G38]): one walled screen (`zones/arena`, `|` walls); mesa banks 3 cells wide and 3 rows up at
  cols 1-3 and 16-18; a 4-cell mud wallow (`:` tar floor in mud skin) at cols 8-11 that slows everyone, Tusker
  included (with 4-cell banks and a 6-cell wallow the 76 px boar never got its feet out of the mud).
- **Phase 1** (hp > 60 %), **Paw and Charge**: paws 22 ticks (dust, snort), charges at 96 v16. Into a wall: **dizzy
  44 ticks**. Across the wallow: slowed to 2 px/tick and **stuck 22 ticks**.
- **Phase 2** (60-30 %), **Spin Ball**: 14-tick squeal while it curls, rolls and bounces off the walls in two arcs,
  then a high hop whose landing shakes the screen (crouch to stand firm); dizzy 33 ticks when it uncurls.
- **Phase 3** (< 30 %), **Stampede**: every wall impact shakes 3 rocks loose (`boss_rock` physics), each marked by a
  dust trickle 14 ticks ahead; shorter idles.
- **Weak point**: the head while dizzy or stuck; tusks glance during a charge.
- **Hit points**: Beginner 150 (6 hits), Expert 225 (9).
- **Co-op form** (187 / 280 [R8]): it charges whoever hit it last (at first the nearest active hero); while dizzy or
  stuck it swings to face the nearer **active** hero [G33], so only the partner behind can strike the **leafy rump**
  (the co-op weak point). In phase 3 its charges no longer crash: it skids and turns 2 tiles before a wall, and only a
  **Brace Wall** (D.4) of two crouching active heroes stops it dead (dazed 66 ticks, flanks open); a charge across the
  wallow may still stick it, rump open from behind only [G38]. One crouching hero is trampled.

### B.2 Old Mangrove, the Rooted Guardian (`w6_l2b` Heart of the Mangrove)

The original's tree-stump archetype (GAMEPLAY 6.2; 12.1 stretch goal).
- **Art**: body = Ninja `Boss/GiantBamboo` (62 x 62 frames: idle, attack, charge, hit) at 2x, gradient-mapped to
  mossy bark, set into the right wall like the Colossus. Fist = composite of shipped `props/jungle/root_arch` and
  `objects/boulder` on a 3-segment root arm cut from `vine_branch`. Leaves = `enemy_ember skin=leaf`. Minions =
  shipped `lizard` diggers.
- **Arena**: the chamber at the top of the tar climb; floor row 10 (the last row of an 11-row camera lock); the
  Guardian fills cols 15-18; one-way root ledges on the left at rows 7 and 5, the upper one ending at col 5 (it was
  row 4: the hand resting on it and a face 112-141 px over the floor were drawn under the HUD [G35]).
- **Stage 1 Face**: the fist punches along the floor in bursts of 3-8 (10-tick draw-back with a creak); each punch
  shakes and shoves 2 px and drops one leaf from 150 px. **The resting fist is a springboard** that launches the hero
  unharmed to the face, whose weak rectangle lies 76-105 px over the floor (55 px or more under the view's top
  [G35]; so low that a jump strike from the floor beside the trunk also reaches it - the springboard is the easy way,
  not the only one). Defeated, it throws the fire-starter from in front of its trunk, not from inside the wall [G30]; with
  the phase-3 chamber it lands on the lower root ledge (reachable from the floor below; D6).
- **Stage 2 Upper hand**: a second root sweeps along the upper ledge's top (14-tick ledge shake), then **rests on the
  ledge's edge 44 ticks** (sunk 12 px onto it): high-strike it from the lower ledge. A hero standing on the lower
  ledge under the sweep is grazed; crouching there he stays under it (enemies-B as built, phase 3).
- **Stage 3 Fist**: bursts of 8, bugs burrow up (every shake sends them down); the fist is hittable **20 ticks after
  each burst** while stuck in the floor.
- **Hits** (any weapon counts 1): Beginner 4 / 3 / 3, Expert 6 / 5 / 5.
- **Co-op form**: stages 1 and 2 merge - the face and the hand must both be struck **within the twin window** (D.4)
  by **two different heroes** (one hero's two hits never twin), so the window is 24 / 12 ticks, not capped by the
  measured solo minimum [G34]: one hero rides the fist springboard to the face, the other waits on the lower ledge
  under the resting hand. An **active** hero standing on the resting fist **pins** it (no punch until it flings him
  off after 66 ticks; an idle body pins nothing [G33]). Stage 3: the knuckle armour turns to the nearer active hero,
  so the wrist must be struck from the far side.

### B.3 Inkjaw, the Grotto Squid (`w7_l2b` Squid Grotto)

- **Art**: Ninja `Boss/SquidGreen` (76 x 79 frames: idle, walk, attack, attack loop, shoot, hit) at 2x, outline
  recoloured; `SquidRed` for the rage phase. Tentacle = chain of segments cut from the RPG `octopus.png` arm,
  recoloured to the squid palette. Ink blob = shipped `projectile_rock` recoloured black-violet. Slams = attack frames
  + shipped `fx/ring` + `fx/splash`.
- **Arena**: one screen; deadly water across the floor; rock islands at cols 2-5, 8-11, 14-17 (row 9); one-way
  root ledges at row 6 over the gaps. Inkjaw surfaces in gap 6-7 or 12-13; **22 ticks of bubbles** mark which.
- **Phase 1 Surface and Slam**: a tentacle rises over the next island for 12 ticks (its shadow marks the landing),
  slams (deadly box 4 ticks, shake); the squid stays up 44 ticks. Weak point: the top of its head (high strike from
  an island edge, a bounce, or a throw).
- **Phase 2 Ink**: adds a spit (jaws open 10 ticks, then an arcing ink blob). A hit costs a bone **and dims the
  screen to the night palette for 66 ticks**; the surfacing bubbles stay bright.
- **Phase 3 Whirlpool** (< 30 %, red): the middle island sinks; two log **rafts** circle the pool on a current; the
  squid surfaces beside a raft and slams it (the raft dips and shakes, nobody is thrown off). Fight from the raft;
  paddle with a strike on the water side.
- **Hit points**: Beginner 150 (6), Expert 225 (9).
- **Co-op form, Tentacle Lock** (187 / 280 [R8]): on surfacing it crosses **two** tentacles over its head. A strike makes
  a tentacle flinch 16 ticks (Expert) / 24 (Beginner); the head opens for 33 ticks only while **both** flinch, struck
  by **two different heroes** - one hero on each flanking island, striking on a count of three (the count-in plays
  while an active hero stands at each side). A slot-bound rule: the flinch is not capped by the measured solo
  minimum [G34]. Phase 3 keeps the solo rule: one hero paddles the raft into position while the other strikes.

### B.4 The Twin Idols (`w8_l2b` Idol Court)

- **Art**: shipped `colossus.png`, the left idol **mirrored** and gradient-mapped to jade (Moon Idol), the right to
  sandstone gold (Sun Idol); all six poses reused. Masonry = `projectile_stalactite` recoloured sandstone.
- **Arena**: one fixed screen; the idols sit in both walls at floor level; a 2-row altar block in the centre
  (cols 8-11); a ledge at row 6 in front of each idol's jaws.
- **Pattern**: one shared brain. One idol is **Awake** (eyes glow; spits rocks, jaws 10 ticks ahead, each rock
  bounces twice - the Colossus rules); the other is **Asleep** and armoured, and drops masonry over the hero
  (14-tick rattle). Every 4th hit both **rage** for 40 ticks (armoured), then swap roles.
- **Weak point**: the open jaws of the awake idol - high strike from its ledge, forward strike when it slams low, or
  any thrown weapon. The club works here (Book II rule).
- **Hits**: Expert 7 per idol (14 in all); the boss bar shows two halves.
- **Co-op form, Twin Hit**: both idols wake together, each spits at the active hero on its own side (an idol whose
  half holds no active hero sleeps, armoured [G33]); an idol cracks only if its twin is struck within the twin window
  **by the other hero** (one hero's axe and club never twin; window 24 / 12 ticks, slot-bound [G34]). A rage swaps
  their targets. The open jaws stay 65 px under the view's top, clear of the HUD [G35].

### B.5 The Storm Roc (`w9_l2b` Storm Nest)

- **Art**: shipped `pterodactyl.png` at 2x (288 x 240 cells; body about 104 x 44 px), gradient-mapped to storm slate
  with a gold crest (pixel edit), **re-packed 4 x 4 to stay under the 2048 px texture limit**. It already has fly,
  perch, rise, dive, screech, hit, dead. Feathers = anchor items 43-46 as a `feather` skin of the leaf hazard.
  Lightning = RPG fx recoloured white-yellow.
- **Arena**: one 20 x 12 screen at the spire top: a stick nest (one-way, cols 6-13, row 8), a stone floor at row 10
  with a 4-cell runway on each side, two drop clouds at row 5.
- **Phase 1 Gale**: perches on the nest rim, raises its wings 14 ticks (whoosh), beats them: wind left or right for
  66 ticks (blizzard wind code; crouch to brace); feathers fall like leaves. Its head is reachable from the nest by a
  high strike or a bounce. After 3 gusts it takes off.
- **Phase 2 Dive**: circles the hero (harrier loop), screeches 14 ticks, dives at his position (dart rule); a miss
  **buries its beak** in the nest or floor for 44 ticks: head open.
- **Phase 3 Storm** (< 1/3): lightning strikes cells a darkening cloud marks **22 ticks** ahead (struck nest sticks
  burn 66 ticks); the Roc climbs above the view and comes down only to cruise and swoop. It cruises over one
  runway half, never over the nest nor in the boss bar's columns, with its feet about 61 px over the floor, so its
  back's top stays 55 px under the view's top [G46] (the halves alternate, the right one first; its wing reaches
  11-26 px over the nest's ends, so a hero on the nest's last cells is brushed - a bone; the arena locks 11 rows). **The hang-glider lies on the nest**: take off along the runway
  (24 ticks at speed, the original rule), climb on lift and **dive onto its back**; the dive ladder (1 000 / 5 000 /
  10 000) counts the three hits; the third dive brings it down.
- **Hit points**: phases 1-2 take 200 (8 club hits); phase 3 takes 3 dives. Expert only.
- **Defeat**: it tumbles into the clouds and coughs up the fire-starter for the summit totem.
- **Co-op form**: phase 1 - a wing shield faces the nearer active hero [G33] (pincer on the nest). Phase 2 **Snatch** - a dive
  grabs the hero it targeted and climbs at 2 px/tick; the partner frees him by hitting the Roc's head within 3 s (73
  ticks), otherwise the grabbed hero becomes an egg (no life lost); a rescue stuns the Roc 66 ticks. Phase 3 **Pilot
  and Spotter** - the pilot dives (and cannot strike, the glider rule); after each dive the Roc tumbles low over the
  nest for 24 ticks, and a dive counts only if a hero **other than the pilot** strikes its tail feathers within those
  24 ticks (slot-bound [G34]). Each hero has his own glider on the nest.

### B.6 The Rival Chieftains, Gorm and Gulla (`w9_l3` Chieftains' Pyre, final boss)

- **Art**: shipped `rival.png` (hero-sized, full move set: idle, walk, jump, fall, land, roll, crouch, attack, hurt,
  death) in two palette swaps - tar-black with bone war paint (Gorm), ochre with red (Gulla) - with bone headdresses
  composited from the anchor dino-skull items 57-58. Their revive egg = `egg_kid` roll frames in their palettes. Two
  boss bars (two rows of pips).
- **How they move**: **on hero physics, driven by the versus bot brain** (E.7). Each chieftain is a boss shell around
  the hero simulation fed every tick by a `HeroBot` input producer with its own seeded `SimRng`. They walk, jump,
  strike and bounce exactly as we do - readable and fair, and the bots pay twice. **Fallback** (PLAN cut list): a
  Brute-style state machine on the same sprite with the same phases.
- **Arena**: one screen around the pyre; the Great Roast on an altar 3 tiles up at the centre; a see-saw and two
  plates on the floor; ledges 3 rows up; nothing standable higher (a chieftain on a 6-tile altar stood under the boss
  bar [G35]).
- **Energy**: 4 pips each (one pip = 1 hit, hit cooldown per chieftain).
- **Phases** (every attack telegraphed with a shout pop-up "HUP!" and a 14-tick crouch):
  - **P1 Raiders**: they flank, strike and stomp heads; they pick the hero farther from his partner (lone rule).
  - **P2 Totem Chief** (from 2 pips each): they **stack** (the bottom walks, the top strikes high) and the bottom
    **bats** the curled top across the arena at a hero (Batter Up); a batted chief lies dazed 30 ticks where he lands.
  - **P3 Roast Thieves** (last pip each): one grabs the Great Roast and runs for the Roc perch at the arena edge; he
    cannot strike while carrying; a hit makes him drop it; if he reaches the perch the roast returns to the altar and
    he regains one pip.
  - **Egg revive**: a chieftain knocked to 0 becomes an egg; his partner runs to hatch it with a head bounce unless
    the heroes smash it first (3 hits).
- **Solo**: they tag in one at a time (the other waits on the pyre and tags in at half energy); a knocked-out
  chieftain's egg hatches after 132 ticks unless smashed; P2 bats are aimed at the hero, so the dazed chieftain is the
  solo opening.
- **Co-op**: both fight at once; their egg hatches in 66 ticks, so one hero must smash the egg while the other keeps
  the surviving chieftain away - our own revive rule turned against us. A smash counts only while an **active** hero
  other than the smasher stands within 64 px of the mate (an idle body keeps nobody away [G33]).
- **Defeat**: they hand back the Great Roast (the trophy) -> `ending_b`.

### B.7 Co-op forms of the two shipped bosses (in `w2_l2b_coop` and `w4_l2b_coop` only)

- **The Brute** (hp 64 -> 80): targets whoever hit him last (before the first hit: the nearest active hero [G33]); his
  arm guard faces his target and blocks throws and head strikes from that side, so **only the partner can reach the
  head** (a Totem Ride rider reaches it with a forward strike - a ride needs an active carrier, D.4). Below 50 % the **Grab**: after a 22-tick chest beat his hands open 8 ticks; a target within 30 px in front
  is squeezed (1 bone per 44 ticks); wriggling (alternate Left / Right) shortens the hold by 4 ticks per press; a
  partner's head hit frees him and staggers the Brute 19 ticks. The ground pound shakes both (crouch to stand firm).
- **The Wall Colossus** (hp 24 -> 30): a stone **visor** covers the face; two stone plates at the hall's sides lift it
  while an active hero stands on the plate whose chain glows (the co-op copy of the hall keeps the face clear of the
  HUD [G35]). Rocks are spat at the plate holder, stalactites rattle over the
  thrower. Still thrown weapons only; the co-op checkpoint places **two** axes. Each rage (the 1st hit and every 4th)
  moves the live chain to the other plate: the roles swap. The fairness tests of `test_enemies_colossus.gd` run per
  hero.
- Solo: both bosses are exactly the 1.0 bosses.

---

## C. Something new (solo too)

### C.1 The Weapon Belt and the fresh-club rule

**Rules.**
1. A hero has two weapon places, the **hand** and the **belt**. One of them always holds the **club**; the other holds
   at most one **special** (hammer, axe, swirling axe, spear).
2. **Pick-up**: a special goes into the hand and the club onto the belt; an owned special is replaced and gone (no
   item is spawned). A club item while holding a special swaps them.
3. **Swap** is one new action, `swap` (input flag `IN_SWAP`, route key letter `S`). It swaps hand and belt on the tick
   it is pressed unless a strike is running (attack gate); it works in the air; star puff + blip; lock-out 8 ticks
   *(tune)*. It never changes movement.
4. **Fresh club**: every Book II stage and every co-op stage (Book I co-op included) **starts with the club in hand**;
   the special waits on the belt (meta `belt = fresh`, the default when `book = 2` or `kind = coop`). Hand and belt
   are kept through deaths and from stage to stage. A stage started from a code or the level select begins with the
   club and an empty belt.
5. **HUD**: one 16 px icon next to the hearts shows what a swap brings; it shows only while a special is owned.
6. **Design rule**: nothing on a Book II main path or co-op gate needs a special; every boss falls to the club.
   Specials open shortcuts, secrets and paintings and make fights easier.
7. **Book I solo keeps the 1.0 rule** (one weapon, carried, replaced on pick-up; `belt = carry`, Swap ignored). Its
   files, rules and 72 routes are untouched. (Owner decision 2 may enable the belt there later; every Book I stage
   already has a club route.)

**Why the proof matrix collapses.** With rule 4 every Book II stage begins in the same state whatever the run
carries; the special changes nothing in the simulation until Swap is pressed. One club route per (stage, difficulty)
proves the stage for every belt. A permanent **belt-invariance test** replays every Book II and co-op route with each
special on the belt and demands identical per-tick digests (the belt slot excluded from the hash). Book II: **31
recorded solo routes** (11 Beginner cells + 20 Expert cells) instead of 155; co-op: club / club only.

**Keys**: single-player keyboard **V** (next to Z / X / C) and **`;`** (next to J / K / L); pad **LB**; touch: the
spare **Y stone** of `ui/touch_buttons.png` (cells 7 / 15). Shared-keyboard layouts in D.11.

### C.2 The spear and bark boards

- **Spear** (`items/weapon kind=spear`, `projectiles/hero_spear`): thrown flat at 12 px/tick for 8 ticks, then
  drops (+16 v16/tick); power 25; 6-tick recovery; at most **2 per hero** in flight or stuck (a third pulls out the
  oldest). Like the axe it passes ordinary walls and opens hidden spots.
- **Bark board** (`objects/bark_board`, one cell on a wall face, designer-placed on trees, palisades, drift-logs and
  cloud-rock): a spear that hits it **sticks** and becomes a **16 px one-way platform** at its height for 220 ticks,
  blinking the last 22, then falls.
- **Why it fits**: the hero climbs by bouncing on heads; the spear lets him make his own step with the same one strike
  button. Boards exist only where the designer wants them (secrets, the Feast Land D warp, paintings); the co-op
  validator keeps them out of reach of every co-op gate (D.8).

### C.3 Vines

- `objects/vine length=<cells> rolled=<bool>` hangs from a ledge or ceiling (shipped `vine_a` / `vine_b` stacked,
  recoloured per biome; the coil is cut from `vine_branch`).
- Grab: Up (without Down: Down + Up is the "let go" chord everywhere [G8]) while the feet column is within 6 px of
  the vine. Climb Up 2 px/tick, Down 3 px/tick (climb frames 44-47, already in every hero sheet). Up at the top steps
  onto the ledge (a landing: 6 ticks before the next jump). Jump lets go: -128 v16 plus 32 v16 toward the held
  direction. Down + Jump drops. A climber is held by his vine: a raft, spear step, lift or drop cloud passing him
  does not catch him, so a vine can be climbed from any of them.
- No strikes while climbing (the glider rule); a hit knocks the hero off as an ordinary hurt.
- **Rolled vines** lie coiled on an upper ledge; one strike on the coil unrolls it: a shortcut opener in solo and the
  "way back" gift in co-op (D.5).

### C.4 Tar and geysers

- **Tar floor** `:` (new tile character, terrain set A in a tar skin): a ground cell whose surface sits 6 px lower
  (the existing lowered-surface profile of `TileGrid`). Walking capped at 32 v16 (2 px/tick); jump thrust only 2
  ticks (a hop of 33 px; air control capped at 32 v16 too) [R2]; crouch and strikes normal; ground enemies slowed the same way; dropped items stop dead.
  The tar rules end at the next landing anywhere or when anything but his own hop throws him up (a geyser, see-saw,
  dismount, Batter Up, hatch, a bounce, a pogo, a hurt) [G8]: a geyser placed on a tar floor gets a hero out of a tar
  pit with full air control.
  Chomper ignores the slowdown. `liquid = tar` draws `~` as deadly tar; `liquid = honey` / `syrup` are the Feast Land
  skins of the same rule.
- **Geysers** `objects/geyser period=<ticks> delay=<ticks> power=<v16> skin=mud|blowhole|steam|soda`: bubble 22
  ticks (the telegraph, with sound), then spout 12 ticks; the spout launches heroes, enemies, rafts and drop
  platforms with the spring code (default -224). Harmless: a spring with a timer.

### C.5 Rafts and currents

- `objects/raft width=3|4 skin=log|wafer` floats on `~`. `zones/current rect=c,r,w,h dir=l|r|u|d speed=1..3` (px per
  tick) moves rafts and floating items. Outside a current a raft slows by 1 px/tick every 8 ticks; banks stop it.
  Riding uses the platform rules (PHYSICS 11.4).
- **Paddling**: a forward strike while standing on a raft pushes it backward by 16 v16, up to 3 px/tick. A raft dips
  2 px under each rider (visual only).
- Water stays deadly (no swimming); in co-op a fall is an egg.
- Used in 6-1, 7-1, 7-2b (phase 3), Feast Land E, the Long Raft Home.

### C.6 The rising tide

`scroll = rising` (with `rise_speed` [16 v16 = 1 px/tick], `.expert` variant allowed): the view rises at that speed
with a band of the level's liquid at its bottom edge; it waits for the first input, like the 4-1 descent;
`zones/autoscroll_stop` ends it; a checkpoint resets the band to 6 rows under itself. Touching the band kills (in
co-op it makes an egg while the partner lives). While the band rises the view follows each hero's footing (the
ground he last stood on), never a jump's apex, and never comes down [G42]. Used in 6-2b and the Tar Pulleys / Cinder
Pit sudden deaths.

### C.7 New enemy behaviours

Roller, Guard and Mimic (A.5). Their co-op rules are in D.6.

### C.8 Chomper, the rex you ride

- `objects/mount kind=rex pen=<name>` with its pen `objects/rex_pen name=<name>` (shipped `rex.png` at 1x, orange; Expert
  foes keep the grey `rex_b`). Wild in 6-1: **three head bounces in a row** tame him. Later stages keep him in pens.
  **Stage-local**: a mount never travels between stages (no entry-state variation, no extra proofs).
- **Mount**: land on the saddle from above (the stomp test means "sit" on a mount). **Dismount**: Down + Jump.
- **Mounted**: walk up to 64 v16 (4 px/tick); Jump = rex hop -160 v16 (about 55 px); **Strike = bite**: a box 0..40 px
  in front, knee to head; an enemy with hp < 50 is **eaten** and pays its score plus a food bonus (the game is about
  eating). Chomper walks over floor spikes `^` and wades tar floors `:` at full speed (deep `~` still kills).
- **The glider contract**: no strikes with your own weapon while driving; a hit **removes the mount** (he bolts to his
  pen and returns after 132 ticks) and costs no energy; no gates or hatches while mounted; mounted corridors need 4
  rows of air (rex + rider stand about 55 px tall).
- **Two seats (co-op)**: the first hero to sit drives (move, hop, bite); a partner who lands on Chomper's back becomes
  the **gunner** - he cannot move but strikes and throws both ways with his own belt (Left / Right turns him). A hit
  throws both off.
- Used in 6-1, 7-1 and the Mesa Rodeo arena. Mount physics is an integer table (`MountTuning`) pinned by a reference
  test like `PHYSICS_REFERENCE.json`; mount speed is far under the 18 px/tick doze reach.

### C.9 Cave Paintings (the meta-goal)

- `items/painting index=0..29`: **30 fragments** - one in every Book II level (20; at the same index in its solo and
  co-op file, possibly in a different hiding place) and one behind an **x2 secret** in ten Book I co-op files (1-1,
  1-2, 2-1, 2-2, 3-1, 3-1b, 3-2, 4-1, 4-2, Way Home). 5 000 points each; they count for completion; saved per profile
  across modes (`Save.add_painting`), like code stones.
- Hiding places: behind `$` walls, up spear steps, at the top of vines, inside a big spot, behind x2 gates. Never on the
  main path.
- **Unlocks** (shown on the Far Shore map slab and in the Versus menu): 5 = Mesa Rodeo arena; 10 = eight loincloth
  patterns for P1-P4; 15 = variants Big Bounce, Lights Out, Giant Rain; 20 = Cloud Top arena; 25 = variant Spear Party
  and a golden loincloth palette; 30 = the mural that ends The Long Raft Home. Options > Versus > "Unlock everything"
  exists for parties.

### C.10 Considered and rejected

| Idea (source) | Why not in 2.0 |
|---|---|
| Swimming (all) | water kills in the original; a second physics model; no swim art |
| Raptor and pterodactyl mounts, auto-run stages (C) | three physics tables and new art for one fantasy; Chomper alone delivers it |
| Day / night, tide clocks, sun and moon blocks, low gravity, zip-lines, ropes (C, B) | stage clocks add state to every proof and drift from the original's feel; vines, rafts, geysers and the rising tide give the new worlds their identity |
| Bola, sling (C, B) | one new special (the spear) is enough; each needs a hero sheet and art that does not exist |
| Carry & Throw of rocks, eggs, torches (B) | Down + Strike would steal the low strike; solo keys are not needed because co-op content lives in its own files |
| "One map, two keys" (B) | it bends every solo Book II level around co-op geometry; separate co-op files on the same skeleton keep solo levels pure |
| Co-op overlays merged at load (C) | a merge step in the loader is a new failure mode; full co-op files with a drift hash are simpler |
| Golden Egg escort, Hatchery screen (C, B) | Cave Paintings give the same hunt with one item and no carry state |
| Split screen | half of 640 x 360 breaks the 20-column paging design (RESEARCH_COOP 5.4) |
| Shops, upgrades, a second strike button | not the original's language; the score is the only currency |

---

## D. Co-op: the tribe

### D.1 Rules of the two-hero game

| Topic | Rule |
|---|---|
| Players | **exactly 2**, designed, tested and proven for two. The engine holds 4 (versus). |
| Heroes | same physics, boxes and strike scripts. P2 is a palette swap through a per-slot 16 x 1 LUT shader (no baked sheets). Default colours: P1 the original yellow loincloth, P2 blue (from `hero_colours/`). A "P1" / "P2" tag and a colour arrow show at stage start and whenever the heroes overlap |
| Body contact | heroes pass through each other sideways; only heads are solid (landing on a partner uses the stomp test). No friendly fire: strikes and throws pass through partners except where a co-op move says otherwise |
| Shared | score (tribe score), lives (tribe pool), letters G-R-U-B-S, feast kit (any hero's 3 pieces feast both), checkpoint, exit unlock, completion, paintings |
| Per hero | hearts, bones (bones picked up at full energy fly to the partner), hand + belt, glider |
| Exit | **team exit**: the stage ends when both heroes are at the exit totem (an egg on screen counts, and so does an idle hero on screen: an absent partner never blocks the exit [G33]) |
| Gates | Down on a gate takes both heroes; a partner more than a screen away arrives as an egg |
| Joining / leaving | from the join panel, the world map or the pause menu; mid-stage it restarts from the checkpoint in the other layout (score kept), because co-op files hold different entities |

### D.2 The tribe camera

One shared paging camera (TECH_AUDIT option B): it pages when the front hero reaches column 16 (column 4 going
left) and the rear hero is not at the margin; it stops when the front hero is back at column 5 or the rear hero
reaches column 1. The view edges are walls for the leader. Vertically it follows the **grounded** heroes, so a
falling hero never drags the view; while both stand with their feet at most 9 rows apart the view keeps both whole
(a hero on a boost ledge is never leashed) [G13]. Holding **Look** claims the camera. A hero off the view (also above
or below it while his partner holds it) gets an edge arrow with a stone countdown and becomes an **egg** after 3 s
(Expert, 73 ticks) / 5 s (Beginner, 121 ticks) - no life lost.
Gates, boss arenas and camera-lock rooms take both heroes. Auto-scroll (4-1) and the rising tide: the deadly edge
eggs a hero while his partner lives. No zoom, no split screen.

### D.3 Lives and the Egg Hatch

- **Tribe lives**: one pool, starting like solo (the counter shows 2). A life is lost only on a **team wipe** (both
  heroes dead or in eggs at once); then both respawn at the checkpoint (spread by slot) and enemies reset as today.
  1UPs and every 250 000 points feed the pool. A single co-op death never resets the world, a boss or a gate.
- **Egg Hatch**: a downed hero plays the death toss, then floats inside an egg (`egg_kid` roll frames in his colour)
  that drifts after his partner; its owner nudges it Left / Right. **The partner hatches it with any hit, a thrown
  weapon or a head bounce.** The hatched hero gets 2 hearts (Beginner) / 1 (Expert), 44 ticks of blinking, and loses
  his own "since last death" tally list. A checkpoint touched by either hero hatches every egg. Expert: an egg not
  hatched within 10 s (243 ticks) flies to the checkpoint and waits there.
- **An egg is no springboard** [G1]: the head bounce that hatches an egg is the small enemy bounce (-64, a 10 px
  rise) whether Up is held or not.
- **The idle partner** [G33] (orchestrator decision of phase 3): a hatched hero is **idle** while his own player has
  given no input for **243 ticks** (10 s), or none at all since he entered the level (a level start, a join, a restart
  at the checkpoint: an untouched partner never counts, not even in the first 10 s). Only his own input - any key or
  button held, an egg's nudge included - resets the count; being hatched, carried, bumped, launched or respawned, a
  checkpoint or a team wipe never does. Once 243 quiet ticks have passed he is drawn **dozing** ("Zzz" over his head)
  until his next input. An idle hero counts for **no co-op rule**: plates and pulleys do not weigh him, a see-saw
  landing of his launches nobody, he lights no x2 tablet, starts no count-in, is no bait and no brace, shelters
  nobody, and no duo move uses him - a hero holding Up or not passes through his head (no Shoulder Hop, no Totem Ride:
  a ride ends on the tick the carrier or the rider becomes idle). A boss counts only active heroes (B.0). He is still
  a body: he stands, is launched by geysers and see-saw ends, rides platforms, can be targeted and hurt by enemies,
  goes down and is leashed into an egg off the view. Eggs count for nothing, as before. So one player can never use his
  partner's egg or idle body as a step, a weight or a bait; a human partner who must wait long at a plate crouches
  (Down held is input). Boost ledges stay 8 rows over every floor within reach [G28] (the corner catch: feet entering
  a ledge's top cell from the side land on top).
- **The egg scouts**: every unopened hidden spot whose cell lies within 32 px (2 tiles) of an egg's box glints with a
  four-point star while the egg is there, so the downed player keeps helping. An egg never touches plates, items or
  enemies, so it can never solve a gate.
- **Voluntary egg**: Down + Look held 1 s turns a hero into an egg on purpose, to be carried through a hard stretch.
- **Helper mode** (Options): P2 cannot be hurt by enemies (only pits and liquids egg him). Gates are unchanged.

### D.4 Duo moves

| Move | Rule | Easy role / hard role |
|---|---|---|
| **Shoulder Hop** | landing on an **active** partner's head (D.3 [G1]) with Up (jump) held bounces -224 v16, as on an enemy: rises 105 px from his head, feet reach about 140 px (8.7 tiles) over the floor. Co-op ledges for it are 8 tiles on both difficulties [G28] | stand still / one held jump |
| **Totem Ride** | landing on an **active** partner without Up held [G33]: stand on his head (the carrier is a moving platform, PHYSICS 11.4, resolved in the party driver after both heroes moved). The carrier's jump impulses are halved. The rider can strike (a high strike reaches about 4-5 tiles over the floor), jump off (Up: 6 tiles from a still carrier, 8.5-9.5 tiles when timed 1-5 ticks after the carrier's jump [R6]; the rider's jump is measured against the carrier's rise, so the halved hop never sheds him [G7]), or drop (Down + Jump). No ride on a curled or mounted partner (the hop still works on a curled one) | walk / strike |
| **Batter Up** | Down + Swap (co-op and versus only) curls the hero into a ball (roll frames 24-26) for up to 66 ticks. The partner's strike in contact launches him: **forward = line drive** (xvel +/-144, yvel -128: 9 tiles to the same height), **high = lob** (xvel +/-32, yvel -240: about 7 tiles up, 4 across), **low = grounder** (rolls at 6 px/tick for 32 ticks: 12 tiles), a charged strike x1.5 (each component clamped to +/-288 v16, the doze limit [R17]). The ball breaks `$` blocks (one hit), opens spots it touches, knocks small enemies (hp < 50, power 25). It uncurls on landing (the 6-tick landing rule) or against a wall. A curled hero is hurt by enemies as usual *(tune all)* | curl / aim and strike |
| **Brace Wall** | two active heroes crouching within 16 px of each other in a heavy's path are a wall: a `heavy` enemy (or Tusker's phase 3) stops dead and is dazed 44 ticks with its head open; a lone croucher is trampled (hurt, thrown back). Reuses crouch-bracing (wind, earthquakes) | crouch / crouch and line up |
| **Egg Hatch** | D.3 | be carried / strike the egg |

All windows (twin drums, bonds, twin hits) are **24 ticks on Beginner / 12 on Expert**, and never longer than the
measured solo minimum minus 4 ticks (D.8); a level record caps its own window with `window=<ticks>` once the search
measured it [G2]. A rule that needs **two different heroes' own hits** (the twin boss hits, Inkjaw's flinches, the
Roc's tail strike) is exempt from that cap: no single player meets it at any speed, so its window is the difficulty
value [G34]. These are the values phase-3 content is built with: G1 passed on its automated criteria, and the
human pair playtests that may shorten them move to P4.5 [G3] (a shorter window keeps every gate solo-impossible).
Every window has an audible count-in (Junkala `Blip5` x3, 8 ticks apart, then "go"), which counts active heroes only;
nothing needs two inputs on the same tick. Every launch move moves at most 18 px/tick or calls
`notify_hero_teleported` (doze rule).

### D.5 Co-op objects

| Id | Rule | Built on |
|---|---|---|
| `objects/plate name= count=1\|2 mode=hold\|timed:<ticks>\|latch` | pressed while the weight on it (active heroes - an idle one weighs nothing [G33]; Chomper counts 2 while an active hero drives him, a riderless mount 0) >= `count`; drives columns by name. Anchored at its left cell; a column rises while **all** its plates are pressed, so a leapfrog uses two doors (two corridors), never one door opened from both sides [G9] | the step-on test |
| `objects/column` + `rise_while=<plate>[,...]` / `sink_while=` | the 1.0 rising column driven by plates: rises or sinks 1 tile per 4 ticks while held, returns when released. A plate stands **8+ tiles** from its door. A block whose next cell is solid is a **door** (the cells it leaves become air: a portcullis into a ceiling slot) [G9] | `objects/column` |
| `objects/column trigger=keepers:<name>` | the **keeper door**: rises when every enemy tagged `keeper=<name>` is dead [R10]. Keepers carry `shell`, `bond` or `daze` and stand in a hall **4 rows high** (the Guard and Shellback art is 54 px tall), so nobody can bounce over them [G4]; keepers meant for a pincer stand still (`speed=0`) [G5] | `objects/column` |
| `objects/drum bond=<name>` | struck drums of one bond must all be hit within the window, then they open a column (`trigger=drums:<bond>`) or gate (`needs=<bond>`) [R10] | `HittableBase` |
| `objects/seesaw len=<cells>` | a hard landing (4+ tiles fall) on the high end launches whoever stands on the low end: launch = -(landing yvel + 32), +64 on a hard landing, cap -288 (about 10 tiles). Enemies on the low end are thrown off; an idle hero's landing flips it and launches nobody [G33] | `PlatformBase`, the hard-landing rule |
| `objects/boulder_heavy` | moves 1 tile per 6 ticks only while **two** heroes push the same side; fills a gap, plugs a vent, presses a plate | column-style tile mover |
| `objects/pulley a=<platform> b=<platform>` | two linked ride platforms; the heavier side (weight as plates: active heroes) sinks 2 px/tick, the other rises | `PlatformBase` |
| Drop gifts: rolled vine (C.3), `objects/flower_pot` | every boost ledge holds a gift only the upper hero can release: a rolled vine, or a flower pot that becomes a spring (-224) where it lands when clubbed off the edge. **The pot spring reaches 6 rows from the floor it takes root on** [G6]; the way back from an 8-row boost ledge is a rolled vine [G28] (a pot's raised root within reach would be a step for a lone hero: a 98-105 px rise plus the corner catch) | vine, `objects/spring` |
| `objects/x2_tablet gate=<name>` | a stone tablet carved with two cavemen marks every co-op gate and every co-op secret (diegetic, not HUD). Every co-op gate has one; the validator pairs them | `objects/sign` skin |
| `objects/hero_start slot=2` | P2 start (ignored in solo) | marker |
| `objects/exit`, `objects/gate` | team rules in co-op (D.1) | existing |

### D.6 The enemy structure for co-op: traits

The original gave every enemy record an Expert bit; co-op gets its twin. **Every enemy record in a co-op file may
carry one co-op trait** (`coop=shell|bond|daze|heavy|lone|grab|leech|split`, plus `bond=<name>` for pairs). Traits
exist only in `kind = coop` files (the validator refuses them elsewhere). In every co-op stage **at least a third of
the enemy records carry a trait**, and every enemy guarding a main-path chokepoint does.

**Base rules for every enemy in co-op**: target = the nearest hatched hero (ties to P1; an idle hero may be chased and
hurt - he is a body), sticky for `TARGET_HOLD_TICKS`; but every **trait** rule that asks where heroes are (the
nearer hero a shield faces, the bait, the pair `lone` watches, a count-in) counts only **active** heroes [G33];
despawn only when far from both; zone spawners alternate between the heroes inside (slot order),
`max` x1.5 rounded down; active cap 12 unchanged; each hero's stolen heart bursts as bones for the team; resets only
on a team wipe; hit points unchanged (two heroes already deal double damage).

| Trait (role) | Rule | Why one hero cannot do it |
|---|---|---|
| `shell` (guard) | the shield faces the nearer **active** hero **every tick** [G33]; front hits glance (clank and spark) | one hero is always "in front" (a parked idle partner is no bait); the partner hits the back |
| `bond` (bond) | linked records (`bond=<name>`): when one dies, the others must die within the window or the dead one regrows | targets are placed out of one hero's reach in the window, never where one thrown special hits two of them [G36] |
| `daze` (daze-gate) | hops back out of reach when any hero within 48 px starts a strike and jumps low throws; a head bounce **dazes** it 12 ticks (Expert) / 14 (Beginner); only a dazed one can be hurt, and only by a hero **other than the one whose bounce dazed it** [G47] | the bouncer's own hits glance (in a 4-row hall one hero strikes 8 ticks after his own bounce, so a timing rule alone failed) |
| `heavy` (heavy) | front hits glance; stopped only by a **Brace Wall**, which dazes it 44 ticks with its head open | needs two braced bodies |
| `lone` (pack) | keeps away while the active heroes are within 64 px of each other; otherwise targets the **straggler**, the active hero farther from the view centre [R9] | staying together is the defence |
| `grab` (grabber) | seizes a hero who touches it from below or that it dives on and reels / carries him toward a pit-side perch at 1 px/tick; the partner frees him with any hit on it | a grabbed hero cannot strike |
| `leech` (grabber) | lands on a hero's back and drains one bone per 44 ticks; only the partner can club it off (alone it falls off after 220 ticks) | a hero cannot hit his own back |
| `split` (bond on the fly) | a hit splits it into two halves that run apart; both must die within the window or they merge back | the halves run in opposite directions |

| Archetype | Co-op base behaviour | Traits used in layouts |
|---|---|---|
| 0 Dropper | drops land beside each hero in turn | `bond` (pairs, one by each hero), `split` (tar blobs) |
| 1 Decoration | none | - |
| 2 Dangler | unchanged; a club box over its thread cuts it: it falls off harmless and is gone without points until a team wipe (the Snatcher bat keeps its thread) | `grab` (Snatcher bat) |
| 3 Lurker | drops when any hero is in range, chases the nearest | `leech` |
| 4 Swinger | unchanged | `bond` (pairs swinging in opposition, rare) |
| 5 Stinger | dives at its target | `lone`, `grab` (Snatcher gull / pterodactyl) |
| 6 Harrier | loop relative to its target, retargets every loop | `bond` (pairs circling in opposite directions, one reachable only from a Totem Ride), `lone` |
| 7 Dart | aims at the nearest hero at launch | none |
| 8 Hopper | hops at its target | `daze` (Raptor) |
| 9 Walker / Flyer | unchanged | `shell` (Shellback turtle), `bond` (flyer pairs on opposite ledges) |
| 10 Digger | rises beside each hero in turn | `lone` |
| 11 Leaper | leaps at its target | `bond` (twin leapers from two pits) |
| 12 Charger | runs at its target | `heavy` (Bull Rex), `lone` |
| Snapper | bites the nearest; the bite tests every hero (no stem rule: bait-and-bite is dropped [G10], confirmed at phase 3 [G40]) | `bond` (twin rattlers, 5-2) |
| 13 Roller | rolls at the nearest | `bond` pairs on two slopes |
| 14 Guard | solo turn delay 33 ticks | `shell` (turns every tick: the Shellback guard) |
| 15 Mimic | bites the nearer; its back faces the far hero | none (a solo joke stays a solo joke) |

### D.7 Co-op-only enemies (7)

Presets of archetype + trait with their own skins; each is a scene of its own so designers can place it by id. They
exist only in `*_coop.lvl` files.

| Id | Archetype + trait | Sprite | Where |
|---|---|---|---|
| `enemies/shellback` | Guard + `shell` | RPG `reptile` (armour recoloured bone); Book I variant `skin=turtle_b` (walker + `shell`) | ruins, canyon; Book I jungle, ice, keep |
| `enemies/raptor` | Hopper + `daze` | shipped `mini_rex_b` (its `dizzy` frames 16-19 show the daze) | jungle, ice, ruins, fen |
| `enemies/snatcher` | Dangler or Stinger + `grab` | shipped `bat_b` (dangler); shipped `pterodactyl_b` recoloured as a gull (stinger) | caves, coast, sky |
| `enemies/leech` | Lurker + `leech` | Ninja `Monster/Larva` 2x, recoloured | caves, fen, sea caves |
| `enemies/bull_rex` | Charger + `heavy` | shipped `rex_b` | ice lake, gorge, canyon |
| `enemies/tar_splitter` | Walker + `split` (the falling tar blobs are `enemies/dropper coop=split skin=slime`) | RPG `slime` (the two palettes are the two halves) | fen, Feast Land D (honey skin) |
| `enemies/shaman` | new patroller | anchor `characters/npc/dragon-man` (idle loop; motion in code) | keep, ruins |

The Book I Shellback (`skin=turtle|turtle_b`) is a Walker with the shell trait (walker speed and score, no Guard
clock); the bone-armoured sheet stays a Guard. The **Shaman** casts bone shields on every other enemy within 64 px
(4 tiles) on both axes - never on Shamans or bosses, and only in a co-op party - (they glance until he dies) and
flees along his platform from the nearer hero within 64 px; cornered (a wall, his platform's edge or his limit ahead)
he hops over that hero (45 px high, harmless during the hop). So one hero rarely corners him and two pin him [G11].

### D.8 Making cooperation required (and proving it)

1. **Gate count**: every co-op `main` file has **at least 2 co-op gates on the main path** (the final-boss stage 9-3:
   its boss form); every co-op `sub` file has at least 1 gate or its boss's co-op form (a boss's own objects, such as
   the visor Colossus's chain plates, are no gate and carry no tablet [G49]); bonus stages and endings need
   only the team exit (the Way Home adds its lookout gate). Every gate is marked by an
   `objects/x2_tablet gate=<name>`.
2. **Gate kinds**: boost ledge (8 tiles over every floor within reach on both difficulties [G28], Shoulder Hop or a
   timed Totem launch [R6]), Batter Up gap
   (8 tiles Beginner / 9 Expert of deadly liquid [R17], or a 7-tile lob ledge), plate door, twin drums, see-saw, heave boulder, pulley, keeper door, Brace
   Wall corridor (a `heavy` in a 4-row-high hall, so nobody can bounce over it), Chomper two-seat stretch.
3. **Solo-impossibility checks** (validator `--coop` + `tests/test_coop_gates.gd`, a slow module run by name:
   `bash .tools/gd.sh test coop_gates` [G13]): for every x2 gate, a bounded search
   with the reference hero (the route tools' simulator), alone, with every weapon including every special from the
   belt and Chomper where a pen is in the stage, must **fail** to reach the gate's far marker. Static rules first: no
   bounceable enemy, spring, geyser, hidden spot column (club pogo), vine, glider, bark board or see-saw within reach of
   a boost ledge (an enemy bounce rises 105 px); plates 8+ tiles from their doors; Guard and keeper halls 4 rows high.
   The search (world-B's v2, phase 2) plays the gate's columns with the file's real entities and the partner a lone
   player has - an egg drifting after him, or his idle hatched partner placed anywhere the partner could be hatched,
   who counts for no co-op rule (no weight, no bait, no carrier) [G33] - and throws every special as movement [G28].
4. **Windows**: every twin window is `min(24 B / 12 E, measured solo minimum - 4)` (the daze is slot-bound since
   [G47]: 14 B / 12 E, not capped). The solo minimum is
   measured by the search (one hero striking one target and throwing a special at the other included: an axe crosses
   12 columns in about 15 ticks). A bond whose two members one thrown special hits in one throw measures 0 and is a
   build error, not a short window [G36]. Rules that need two heroes' own hits are not capped (D.4 [G34]).
5. **Fairness**: each gate has an easy role and a hard role; every one-way move has a way back (a drop gift); each gate
   takes under about 30 s once understood; a failure costs an egg, never a life, while the partner stands.

### D.9 Book I in co-op (15 files `<id>_coop.lvl`)

Each shipped stage gets `levels/<id>_coop.lvl` (`kind = coop`, `coop_of = <id>`, `coop_base_hash = <sha of the solo
file>`): a copy of the solo map with its own edits. The validator warns when the solo file's hash changes, so the two
never drift silently. Co-op files carry no passwords. Specials are placed in pairs where the solo file places weapons.

| Stage | Main-path co-op gates | Trait enemies | x2 secret (painting) |
|---|---|---|---|
| 1-1 Vine Bridges | (1) the springy flower becomes an 8-tile Shoulder Hop ledge, and the upper hero clubs a rolled vine down (teaches hop and gift) [G28]; (2) a leapfrog plate door on the canopy road. Signs teach the egg and the x2 tablet at the first checkpoint | two Shellback turtles before the exit (taught by a sign) | High Cache 7 tiles up, Totem Ride high strike (#20) |
| 1-2 Canopy Village | (1) the first tree house only by Totem Ride + jump (a 5-row Totem ledge: a gate since a ride needs an active carrier [G33]); (2) a pulley in the trunk room (a counterweight hop up the shaft [G48]). The Feast Land A warp sits in a cage behind twin drums | bonded leapers in two pits (the solo file's dragon leapers) | treetop cache, 8 rows up, by a charged Batter Up lob (#21) [G48] |
| 2-1 Echo Caverns | (1) paired plates on two hatches (one holds, one drops); (2) a keeper door guarded by two Shellback turtles in a 4-row hall (Raptors need the slot-bound daze of G47 [G48]) | Leeches under the dark section; `lone` stingers | a secret-room wall of `$` opened by a Batter Up line drive (#22) |
| 2-2 Bone Gorge | (1) a see-saw on the rising stepping stones; (2) the lift pillar driven by a plate. Two gliders over the gorge with bonded harrier pairs | a Bull Rex on the gorge floor (Brace Wall) | x2 ledge over the lift pillar (#23) |
| 2-2b Brute's Den | a keeper door into the den (two bonded diggers); **the co-op Brute** (B.7) | - | - |
| 3-1 Frost Summit | (1) a Bull Rex on the frozen lake (bracing on ice slides both heroes - the joke of the level); (2) the cliff climb by Shoulder Hop steps with a rolled vine back | bonded chargers, Shellback turtles on the slopes | x2 ice cave (#24) |
| 3-1b Blizzard Pass | (1) a keeper hall of Shellback turtles, 4 rows high, in the gusts; (2) lee leapfrog: a crouching hero shelters the hero behind him from the wind over the last gaps | Snatcher pterodactyls riding the gusts | x2 lee ledge (#25) |
| 3-2 Crystal Grotto | (1) a Batter Up line drive over 9 tiles of icy water (8 on Beginner: a `beginner` floe column on the near lip); (2) twin drums, one on each bank, that freeze a floe bridge (a column) so the batter can follow - both gates at the leaper lake [G44] | Raptors, twin leapers from the water pits | the Feast Land C warp on a boost ledge; crystal cache (#26) |
| 4-1 Cinder Shaft | (1) both inside the auto-scroll: a heave boulder pushed off a ledge plugs a lava vent before the view passes; (2) a Batter Up lob across a lava stratum | `lone` stingers in the ember rain | x2 shelf (#27) |
| 4-2 Obsidian Keep | (1) leapfrog plate doors (A holds for B, B holds for A); (2) twin drums that raise a portcullis on the ramparts for good (spikes are no door) [G44] | Shamans shielding the keep guards; Raptors | x2 keep tower (#28) |
| 4-2b Colossus Hall | **the visor Colossus** (B.7); two axes at the checkpoint | - | - |
| Feast Land A / B / C | team exit only; a giant roast spot pays its giant bonus only when both strike it within the window; **Relay Bounce**: alternate bounces by both heroes on one enemy extend the 1-2-3-4-6-8 ladder to x10 and x12 | - | - |
| Way Home | the village gate is barred: one hero is lifted to the lookout gallery 8 rows over the road (Shoulder Hop) and steps on its latch plate, 9+ cells from the door, to open it [G44]; team exit | - | x2 lookout (#29) |

Paintings 0-19 are the Book II ones (one per level, in `A.2` order).

### D.10 Book II in co-op (20 files `<id>_coop.lvl` on the same skeleton)

Authored together with the solo file: the designer builds the solo file, proves it, copies it to `<id>_coop.lvl`
and adds the co-op gates, traits and the P2 start.

| Level | Co-op signature (main-path gates) |
|---|---|
| 5-1 Red Mesa Trail | teaching stage: an 8-tile Shoulder Hop ledge with a rolled-vine gift [G28]; a leapfrog plate door; a keeper gully of two Shellback guards |
| 5-2 Rattlesnake Gulch | one climbs a vine while the other holds a plate that keeps a sand gate open; the upper hero unrolls the second vine (the gift); twin rattlers (bonded snappers) |
| 5-2b Tusker's Wallow | co-op Tusker: rump pincer, Brace Wall in phase 3 (B.1) |
| 6-1 Bubbling Fen | Chomper with two seats: the driver wades the tar flats, the gunner clears Leeches; a Batter Up gap where the raft sank; a raft for two (one paddles, one fights); Tar Splitters (A.6) |
| 6-2 Spore Hollow | a mushroom see-saw in the dark (a hard landing launches the partner to a 10-tile cap); twin drums made of glowing caps; Raptors |
| 6-2b Heart of the Mangrove | rising tar for two: a heave boulder must be pushed onto a vent before the tar reaches it; co-op Old Mangrove (B.2) |
| 7-1 Shell Beach | a Batter Up lob from a 3-row rock onto a sea stack 10 tiles over the beach (the blowholes stay out of the gate's reach); bonded leaping fish; Chomper gunner over the urchin beds (A.6) |
| 7-2 Sea Caves | a plate that holds a sea gate while the partner rides a driftwood floe through (leapfrog); a Batter Up line drive over dark water; Snatcher gulls over a pit; Leeches (A.6) |
| 7-2b Squid Grotto | the Tentacle Lock (B.3) |
| 8-1 Overgrown Steps | column stairs that rise only while both plates are held, then a heave boulder holds one plate while the heroes cross; Shellback guards in 4-row halls |
| 8-2 Hall of Idols | a gate maze where every room door is a plate held from the other room; keeper halls with Shamans |
| 8-2b Idol Court | the Twin Hit (B.4) |
| 9-1 Cloudbreak Climb | a see-saw to a cloud 9 rows over its low end (geysers lift the heroes elsewhere on the climb, never within a gate's reach); a pulley between two cloud stacks; `lone` harriers (A.6) |
| 9-1b Thunderhead Glide | two gliders; bonded harrier pairs that must both be dive-hit within the window, the keepers of a storm-cloud wall (A.6) |
| 9-2 The Roc's Spire | lee leapfrog in the gusts; a Batter Up line drive over the final gap; Bull Rex on a cloud bridge |
| 9-2b Storm Nest | Snatch rescue and Pilot and Spotter (B.5) |
| 9-3 Chieftains' Pyre | both chieftains at once, the 66-tick egg race (B.6) |
| Feast Land D / E | roasts for two, Relay Bounce; team exit only |
| The Long Raft Home | one raft for two; the home beach is the team exit |

### D.11 Joining, controls, HUD, difficulty

- **Join** ("the Tribe Gathering"): Title > Co-op opens a carved panel with two slots. **Press Jump on any device** to
  take a slot; Left / Right picks a colour; hold Strike 1 s = ready. A lost pad pauses ("Reconnect, or continue
  alone"). Menu music Tallbeard "Connected"; join sting ctske "party join".
- **Keyboard** (bound by physical key position, rebindable per slot). The join panel runs a key test: each player
  holds Left + Jump + Strike + Swap and all lights must stay lit (ghosting check).

  | Layout | P1 | P2 |
  |---|---|---|
  | **Classic: WASD + numpad** (owner requirement 2026-10-06; the default for versus on one keyboard, offered first in co-op too) | move W A S D, jump Space, strike **Left Ctrl**, swap E, look Q | move Num 8 / Num 4 / Num 5 / Num 6 (up / left / down / right), jump Num 0, strike Num Enter, swap Num +, look Num `.` |
  | Two hands each (keyboards without a numpad: laptops) | move W A S D, strike F, jump G, look R, swap T | move arrows, strike `.`, jump `/`, look `,`, swap `;` |
  | One hand each (the original's Up-jumps scheme) | W A S D (W jumps), strike Space, swap E, look Q | arrows (Up jumps), strike Right Ctrl, swap Right Shift, look Num 0 |

  The classic layout is the old-school shared-keyboard deathmatch setup: each player keeps one hand on a cluster at
  opposite ends of the keyboard (thumb on Space / Num 0 for jump, little finger on Left Ctrl / Num Enter for strike).
  **P1 strikes with Left Ctrl, not Left Shift** [G12]: on Windows a numpad key pressed with NumLock on while Shift is
  held makes the system wrap it in a synthetic Shift release and re-press, which would cut P1's held strike (and
  start new ones) whenever P2 moves; Godot reports those synthetic events exactly like real ones, so no filter can be
  proven and Shift is no alias. Bindings keep no key side, so Right Ctrl also strikes for P1 in this layout (nobody
  else uses it). Device note for P4.3: on macOS with two input sources Ctrl + Space is the system's "previous input
  source" shortcut; a player can rebind P1's strike in the options. The layout works **whatever the NumLock state**:
  the numpad is bound by physical key, and Windows with NumLock off still reports the numpad's physical keys
  (verified on Godot 4.7.2 / Windows 11), so no navigation-key aliases are needed; the key test says "Num Lock" if a
  key does not arrive. The join panel / versus lobby offers the three
  layouts as presets, shows the keys on a keyboard picture, and both players can navigate the menus from their own
  cluster (P1: W / S / Space / Q, P2: Num 8 / Num 5 / Num 0 / Num `.`). The ghosting key test holds Left + Jump +
  Strike + Swap for BOTH players at once.

  Left + Right together is Look in every layout. In a party, slot 0 uses its own generated `p1_*` actions, so the
  halves never feed two heroes.
- **Pads**: one per slot, the solo layout (A jump, X / B strike, Y / RB look, **LB swap**, Start pause); rumble only on
  that slot's pad.
- **Touch**: phones and tablets get one touch player (P2 on a pad). The tablet **table mode** (mirrored clusters at
  each end in the player colours, stones of 56 art px) is cut for 2.0 (PLAN cut 2, applied by the orchestrator): it
  stays an experimental prototype, hidden from the release menus [G37].
- **Talk without voice**: a double tap of Look shows an emote bubble over the hero (Ninja Adventure emotes "!", "?",
  heart, angry).
- **HUD**: P1 panel top-left exactly as today; P2 hearts and belt icon mirrored top-right; tribe lives and score where
  they are today; letters as today; edge arrows with a stone countdown for a hero off the view.
- **Tally**: one tribe score; the companion catches each hero's items in his own pile and hands out medals - Most Food,
  Best Bounce Chain, Hatchling (eggs hatched), Slugger (Batter Up launches), Strongman (plates held, boulders pushed),
  Clumsiest (as a joke). Options: "Rival score" (two scores on the same stages).
- **Difficulty**:

  | Setting | Co-op Beginner | Co-op Expert |
  |---|---|---|
  | Twin windows | 24 ticks (or solo minimum - 4) | 12 ticks (or solo minimum - 4) |
  | Raptor daze | 14 ticks (only the other hero hurts it [G47]) | 12 ticks |
  | Leash before the egg | 5 s (121 ticks) | 3 s (73 ticks) |
  | Hatch hearts | 2 | 1 |
  | Unhatched egg | follows forever | returns to the checkpoint after 10 s |
  | `lone` trait | off (acts as plain targeting) | on |
  | Boss grabs | off | on |
  | Boost ledges | 8 tiles [G28] [G39] | 8 tiles |
  | Idle partner | 243 ticks without input [G33] | 243 ticks |

  The Beginner wall is unchanged in both books.

---

## E. Versus: same-device deathmatch (2-4 players)

### E.1 Pillars

1. **Nobody sits out long**, **everyone sees the score** (it stacks on the heroes' heads), **the leader is the biggest
   target** (structural, visible comeback - no hidden rubber-banding).
2. **Built from this game's verbs**: clubbing scenery for food, head bounces and their 1-2-3-4-6-8 ladder, charged
   strikes, giant bonuses falling from the sky, the feast.
3. **Short rounds** (60-90 s), matches of 5-8 minutes, **Rematch** as the default button.
4. **Bots** so one person, a parent and a child, or three friends can fill four slots.

Versus runs only in arena files (`kind = arena`) with its own rule tables (`VersusTuning`); campaign values are
untouched.

### E.2 Combat kit

- **Attacks** (existing frame data): forward strike (damaging from tick 5), high strike (anti-air), low strike, stomp,
  the crouch-charged strike (a launch), thrown specials.
- **Hit**: the victim loses one unit of the mode's currency, is knocked away from the attacker (xvel +/-64, yvel -128);
  a **charged hit launches** (xvel +/-128 with ice-like sliding, yvel -160); hammer x1.5 horizontal; swirling axe pops
  up (yvel -160).
- **Clang**: two front boxes meeting in the same tick push both 16 px apart with the Colossus clank and spark; a
  charged strike wins the clang.
- **Deflect**: a strike bats a thrown special back, now owned by the striker, 2 px/tick faster.
- **Stomp**: the stomper bounces as on an enemy; the victim is squashed 8 ticks (no jump, no strike) and pays by the
  bounce ladder 1-2-3-4-6-8 for a chain. A blinking (immune) head is a free springboard. **A stomp is a landing** [G15]:
  a hero who stood on ground or a platform on the previous tick does not stomp a head that rises into his feet (a
  rival pogoing under a one-way bridge 3 rows up pokes his head 2 px through it).
- **Curl** (Down + Swap): a turtle stance (roll frames) that ignores stomps and strikes from above, but **a rival can bat
  a curled hero** like a Batter Up ball - into lava if he is unlucky. Teammates bat each other as in co-op.
- **Hurt timing**: 12 ticks stunned + 30 immune (immunity ends when the victim strikes or throws); hit-stop 2 ticks,
  4 on a charged or deciding hit.
- **Thrown specials stop at solid cells** and lie there as pick-ups - on the top of a floor cell, or in the open cell
  in front of a wall's face, never inside a wall [G17]; spears stick in bark boards as steps for anyone.
  In wrap arenas a special wraps once and vanishes after 40 ticks.
- **Body bump**: overlapping heroes are nudged 1 px/tick apart; running into each other at 4+ px/tick knocks both back.
- **Weapons**: everyone starts every round with the club; specials come from pterodactyl crates straight onto the belt
  and are **temporary** (lost on a knock-out or after 3 axe / 2 swirling-axe / 3 spear throws).
- **Spawns** rotate every round (the physics is left-right asymmetric); 48 ticks of spawn shield that ends on the first
  strike or throw.

### E.3 Flagship: Grub Stack

*"Everything you grab stacks on your head. Biggest stack at the gong wins."*

- **Setup**: 2-4 players, free-for-all or 2v2; club for everyone, an empty head; no hearts - nobody dies from hits;
  hazards cost a respawn after 48 ticks.
- **The stack**: every food item you pick up lands on your head as a picture in a wobbling tower: small food 1, big food
  2, treasure 5, giant bonus 10. Above 8 pictures the tower shows 5s and 10s, so it never leaves the screen. The tower
  **is** the score, readable at a glance; the **crown** sits on the tallest.
- **Weight**: 10+ on your head caps walking at 64 v16 (4 px/tick); 20+ caps it at 48 v16 and jump impulses at 3/4
  *(tune)*. The leader is slower and a bigger springboard.
- **Losing food**: a hit knocks **1 + stack/5** pieces off the top (they fly out with the shipped dropped-item physics,
  198 ticks, blinking); a charged hit **1 + stack/2** and a launch; a thrown special 1 + stack/8; a **stomp steals**:
  the stomper takes the ladder count (1, 2, 3, 4, 6, 8) straight onto **his own** stack (the pieces arc head to head);
  a hazard spills everything (half bursts out, half is lost). The victim cannot pick up during his 12 stun ticks.
- **The Cookpot** (one per arena; two on 4-player arenas, on contested ground): crouch inside it to **bank** one piece
  per 4 ticks. Banked food is safe; a banking hero is crouched, and a stomp on him steals double. Final score =
  banked + stack.
- **Food sources**: visible hidden spots that refill 15 s after they are emptied (sparkle 2 s before); one big spot (3
  hits by anyone; its giant bonus falls from 7 rows up and **bonks the head** it lands on); pterodactyl crates every
  20 s on marked lanes (shadow 22 ticks ahead): **one crate holds all of** food, a special, one cutlery piece,
  sometimes a skull or a grenade (the referee's per-mode table: Last Caveman Standing a heart instead of food, Hot
  Rock no food); one crate per period over all lanes, on a free lane; one hit opens it [G18].
- **Items**: *Feast* (fork + knife + spoon, each from crates, dropped on a hit): 8 s (194 ticks) in which your touch
  knocks 3 pieces off anyone and hits cannot touch you; the shake warns 7 ticks before the end. *Skull*: whoever picks
  it up spills everything. *Grenade*: every rival spills 5.
- **Feast Rush**: the last 15 s - a bell, every spot refills at once, a second giant bonus drops and the **pot lids
  close**: no banking, everything on heads.
- **Round**: 90 s (2 185 ticks; 60 s with 2 players); first to 3 round wins. Tie: the **Golden Drumstick** falls in the
  middle; first to grab it wins.
- **Teams (2v2)**: one shared pot, separate stacks; a teammate's head is a free springboard; friendly hits only bump.

### E.4 The other modes

| Mode | Rules | Launch |
|---|---|---|
| **Last Caveman Standing** | the literal deathmatch: 3 hearts; hit = 1 heart, charged = 2 + launch, stomp = 1 + squash, hazard = out. **A lost heart bursts into 6 bones** anyone can grab (6 bones heal a heart, max 3). Last alive wins the round; first to 5. At 60 s the arena's **themed sudden death** starts (E.6). Eliminated players ride **Grudge Pterodactyls** along the top and drop a rock with Strike (one per 3 s, 10-tick squawk first; a rock dazes 12 ticks, costs no heart). Option *Stock*: 3 lives with respawn | yes |
| **Hot Rock** | a glowing ember sticks to one player and passes on any touch, hit or stomp; whoever passed it is immune to it for 44 ticks; the holder walks up to 96 v16 (faster than the others' 80) [R7]; the fuse is 12-20 s (`Sim.rng`, round seed) and bubbles faster in the last 3 s; the holder pops (the death toss). Last one standing; first to 3 | yes |
| **Clubball** | 1v1, 2v1 or 2v2 on Coconut Cove: a coconut (gravity 16 v16, bounces at 3/4 and comes to rest within six bounces [G19], rolls) and a goal mouth 3 rows high at each end. The strike direction is the shot (front frames only): forward = drive, high = lob, low = grounder, charged = smash (x1.5); boxes on the ball in one tick add up, and one swing shoots it at most once. Every strike within 44 ticks of the last adds +16 v16, up to 12 px/tick (rallies escalate; a smash keeps its own speed); a coconut faster than 8 px/tick knocks a hero down (12 stun ticks) and rebounds at half speed; heads bounce it; a curled teammate can be batted as a "missile". First to 5 goals or most after 3 min; sudden death "golden coconut"; the ball resets to the middle 66 ticks after a goal | yes |
| King of the Feast | carry the giant roast to fill 20 counts of 22 ticks; the carrier cannot strike, walks at most 64 v16; a hit drops it; your count never falls back below 5 left | second wave |
| Letter Snatch | 8-12 visible spots, five hold G-R-U-B-S (shuffled); held letters float over your head; a hit drops your newest; hold all five for 44 ticks = round won | second wave |
| Egg Heist (2v2) | carry a giant egg to your nest ledge; teammates boost and bat each other; the egg cracks after a fall of 6+ rows; a mother rex chases a carrier who holds it 8 s | second wave (team bots) |

- **Party Mix** picks mode and arena per round. **Presets**: *Classic* (club only, no crates), *Feast* (default),
  *Mayhem* (crates every 8 s, skull spots, a random variant per round).
- **Variants**: Hammer Time, Axe Rain, Big Bounce, One-Bonk, Slippery, Lights Out (night palette, heroes glow), Gusty,
  Giant Rain, Spear Party (some unlocked by paintings, C.9).
- **Handicap card** in the lobby: hearts 1-5 (LCS) or stack guard x0.5 / x1 / x1.5 (Grub Stack), or Auto (a player
  two rounds behind gets a leaf shield that absorbs one hit).

### E.5 Arenas: 10 single screens (8 at launch, 2 unlocked)

Every arena is **20 x 12 cells** (floor row 10, fill row 11), camera locked; row 0 holds nothing to stand on (HUD corners
and the round sundial); wider or taller screens show a decorated frame, never gameplay. Tiers 3 rows apart; 5+ rows only
by spring, geyser, see-saw or a head; clear gaps of at most 5 cells; mirrored layouts with spawns rotated every round;
4-8 visible hidden spots; one signature hazard telegraphed 10+ ticks ahead; geometry a bot graph can describe (no 1-row
squeezes, no pixel-perfect jumps on main routes). Files `levels/arena_<name>.lvl`. An arena plays a mode with bots only
when its bot set is green there; otherwise meta `bots` leaves that mode out and it is human-only (PLAN cut 4 [G50]).

| # | Arena | Biome | Edges | Signature | Sudden death | Default mode |
|---|---|---|---|---|---|---|
| 1 | **Totem Ring** | jungle | wrap left-right | a totem with the cookpot on top; springs to the wrap ledges; the big spot in the totem's base, its giant falls onto the totem top [G31] | **Stampede**: chargers along the floor every 3 s, dust 22 ticks ahead | Grub Stack (also Last Caveman Standing, Hot Rock) |
| 2 | **Echo Hollow** | cave | wrap top-bottom (a shaft: the floor's 4-cell hole drops onto the central ledge) | darkness pulse every 20 s (3 s of night, heroes glow), `$` walls that grow back after 15 s, a dangler as a neutral springboard (not built at G2 [G31]; the referee's `dark_pulse`, `regrow` and neutral-enemy rules since phase 3 [G43]) | **Cave-in**: blocks fall from the top row inward, one per 11 ticks | Hot Rock (also Grub Stack, Last Caveman Standing) |
| 3 | **Floe Rink** | ice | open sides into icy water | ice floor, two see-saw floes (land on your end to fling whoever stands on the other out over the water), alternating gusts; until the bots ride a tilted see-saw, two fixed floes instead and the gusts carry the signature [G51] | **Whiteout**: gusts grow every 5 s | Last Caveman Standing |
| 4 | **Cinder Pit** | volcano | walls (no lava at the ends [G31]), a 4-cell lava pit in the middle | obsidian slabs over the pit, one crate lane over the whole arena; the ember lane is the referee's `ember_lane` since phase 3 [G43] | **Lava rise**: 1 row per 44 ticks with a rumble | Last Caveman Standing (also Hot Rock, Grub Stack) |
| 5 | **Tar Pulleys** | swamp | walls, tar pit | two pulley lifts over tar: step on your lift to yank a rival's side up to the island - or down to the tar | **Tar rise** | Grub Stack |
| 6 | **Coconut Cove** | coast | walls with goal mouths | the Clubball pitch: rims, a lob bridge, two low ledges; in other modes the goal mouths are ring-outs into the surf (leaving through one is a hazard; the referee's ring-out rule since phase 3 [G43]) | **High tide** (the rising-tide code) | Clubball |
| 7 | **Sky Picnic** | Feast Land | wrap top-bottom, **no deaths** (kid-safe) | springs, icing clouds, a cake island | **Syrup flood** (safe: it only slows) | Hot Rock / Grub Stack |
| 8 | **Colossus Hall** | volcano keep | walls | the Wall Colossus as a neutral (no hits, no bar; its body a picture): every 10 s it spits at the **crowned leader** - in Last Caveman Standing the hero with the most hearts, a tie: no spit (jaws 10 ticks ahead) [G43] | **Stalactite storm** | Grub Stack (also Last Caveman Standing; no Hot Rock, no Clubball) |
| 9 | Mesa Rodeo (5 paintings; built only after arenas 1-8 are green [G37]) | canyon | walls | Chomper is released from his pen at every multiple of 30 s of round time while he waits penned (rumble 22 ticks ahead: his picture shakes, no screen shake) and stays out for riders; the rider bites rivals (spill 3); a stomp on the rider unseats him (no stun) and Chomper stays out for the stomper; only a hit sends him back to his pen [G20]; regrowing cover blocks | **Rockslide** from the mesa rims | Last Caveman Standing |
| 10 | Cloud Top (20 paintings; built only after arenas 1-8 are green [G37]) | sky | wrap top-bottom | drop clouds, alternating gusts (crouch to brace), steam geysers | **Lightning**: marked cells, 22 ticks ahead | Grub Stack |

Sketches (`?` small spot, `*` big spot, `J` spring -224, `-` / `=` one-way platform of set A / B, `P` cookpot, `L` /
`R` pulley lifts, `G` goal zone, `B` coconut drop point, `%` rim rock, `~` liquid, `1`-`4` spawns). Each must pass
`tools/validate_levels.gd` (`kind = arena`) and the bot graph bake. Totem Ring, Cinder Pit, Echo Hollow and Coconut
Cove are drawn **as built at G2** (DA, `levels/arena_<name>.lvl`; balance by V4.b: 12 seeds x 4 rounds, four Hunters,
wins per spawn within +/-15 points of the fair share) [G31]; Tar Pulleys is the design sketch.

**Totem Ring** (wraps left-right; modes `grub_stack`, `last_caveman`, `hot_rock`):

```
     col 01234567890123456789
row  0   ....................   HUD row: nothing to stand on
row  1   ....................
row  2   ....................
row  3   .........P..........   cookpot on the totem top (room for one banker)
row  4   .........%%.........   totem top, 3 rows over the bridges
row  5   ---......?%......---   wrap ledge (6 cells across the seam); spot in the totem face (head height from the left bridge)
row  6   ....3.P..%%....4....   spawns 3 / 4 on the outer bridge ends; the second pot mid left bridge
row  7   ....-----%?-----....   bridges either side, 3 rows over the floor; spot level with the right bridge (low strike)
row  8   .........%%.........
row  9   .J.....2.*%.1.....J.   springs at cols 1 / 18; spawns 1 / 2 by the totem; the BIG SPOT in the totem's base (9, 9)
row 10   ####?##########?####   floor wraps; floor spots at cols 4 / 15
row 11   ####################
```

The first sketch had the big spot on the right floor (cols 12-13): spawn 1 won 58-60 % of 48 Grub Stack rounds. The
hit test reaches one column past the club (PHYSICS 8.3) and the totem is two cells wide, so every totem spot is struck
from both sides; the giant falls 7 rows onto the totem top beside the cookpot. Measured: Grub Stack 13 points worst,
Last Caveman Standing 6, Hot Rock 8 (no crate lane: a whole-arena lane put Hot Rock at 15). DA's G1 changes stand [G14]:
springs one cell further out and floor spots one cell in (every strike ends in a hop or a pogo), the second cookpot in
the middle of the left bridge, spawns 1 / 2 on the floor by the totem (out of every drop, jump and spring link of the
first 48 ticks), 3 / 4 on the outer bridge ends. Food knocked out of a spot under a bridge arcs onto that bridge.

**Cinder Pit** (walled; modes `last_caveman`, `hot_rock`, `grub_stack`; `objects/crate_lane rect=1,1,18,10`):

```
     col 01234567890123456789
row  0   ....................
row  1   ....................
row  2   ....................
row  3   ....3.P......P.4....   spawns 3 / 4 and the cookpots on the high slabs
row  4   ...?====....====?...   high obsidian slabs, spots flush in their outer ends
row  5   ....................
row  6   ....................
row  7   .......?=*==?.......   central slab over the pit: spots in its ends, the big spot (9, 7)
row  8   ....................
row  9   ..J...2......1...J..   springs to the high slabs; spawns 1 / 2 on the islands
row 10   #####?##....##?#####   two floor islands with spots; a 4-cell lava pit in the middle
row 11   ########~~~~########
```

With lava at both ends (the first sketch) a spring stood one cell from lava and rounds ended after about 300 ticks
(spawn 3 won 0 of 48, the right side 86 %); with walls and one crate lane: Last Caveman Standing 8, Hot Rock 4, Grub
Stack 8 points worst. Slabs are `=` of `terrain_b = volcano/terrain_obsidian`.

**Echo Hollow** (wraps top-bottom; modes `hot_rock`, `grub_stack`, `last_caveman`):

```
     col 01234567890123456789
row  0   ....................   nothing above row 4: a plain jump never reaches the top seam
row  1   ....................
row  2   ....................
row  3   ......P......P......   cookpots on the upper ledges
row  4   ...?====....====?...   upper ledges, spots flush in their outer ends
row  5   ....................
row  6   .3................4.   spawns 3 / 4 on the side shelves
row  7   ?===....=**=....===?   side shelves with spots in the wall ends; the big spot's two cells mid central ledge
row  8   ....................
row  9   .....2........1.....   spawns 1 / 2 on the floor
row 10   ##?#####....#####?##   floor spots; the 4-cell hole wraps to the top and drops onto the central ledge
row 11   ########....########
```

Rising past the top seam (a stomp bounce) comes in at the bottom harmlessly (floors are one-way for the feet,
PHYSICS 11.2). The big spot is two cells side by side (cols 9 / 10, phase 3): each counts its own 3 hits, the first
used up drops the giant over itself and opens its twin (one giant per refill). One cell decided Grub Stack (col 9: the
left floor spawn led, col 10: the right one; 15 points worst); the pair measures Grub Stack 8, Hot Rock 8, Last
Caveman Standing 12. Not built at G2: the darkness pulse, the regrowing `$` walls and the dangler springboard - the
referee's `dark_pulse`, `regrow` and neutral enemies since phase 3 [G43].

**Tar Pulleys** (walled; the design sketch):

```
     col 01234567890123456789
row  0   ....................   HUD row
row  1   ....................   log beam with the pulley wheels (prop)
row  2   .........P..........   cookpot on the island
row  3   ........#**#........   mud island with the big spot
row  4   ........####........
row  5   ....................
row  6   ##?..LLL....RRR..?##   side ledges with spots; lifts L and R at rest (balanced)
row  7   ###..............###
row  8   ....................
row  9   ...J............J...   springs on the banks (-224, up to the side ledges)
row 10   ####~~~~~~~~~~~~####   4-cell banks and a 12-cell tar pit
row 11   ####~~~~~~~~~~~~####
```

L and R hang from one rope: the heavier lift sinks 2 px/tick down to row 9, one row over the tar, while the other rises
to row 3, level with the island. Riding the high lift is the only way onto the island; a rival who jumps onto the low
lift yanks you down.

**Coconut Cove** (Clubball only until the goal mouths become ring-outs in other modes; `zones/goal rect=0,7,1,3
team=1` and `rect=19,7,1,3 team=2`; `objects/coconut 9 9 dx=8`):

```
     col 01234567890123456789
row  0   ....................
row  1   ....................
row  2   ....................
row  3   ....................
row  4   ?%....--------....%?   rims (stand on top; a spot in each rim's outer top) and the lob bridge
row  5   %%................%%
row  6   %%................%%   rims straight (the sketch's extra row-6 cell made a 14-cell "gap" warning)
row  7   G.....--....--.....G   goal mouths 3 rows high under the rims; two low ledges
row  8   G..................G
row  9   G1..3....B.....4..2G   spawns on the beach (cols 1 / 4 left, 15 / 18 right); the coconut drops in at x 160
row 10   ###?############?###   beach spots at cols 3 / 16
row 11   ####################
```

Routes: floor -> low ledge (3 rows) -> bridge (3 rows) -> rim (4 cells across). Keepers stand on the rims and volley
down; the bridge is where lobs are won. Clubball measured 38 % / 62 % (left / right team) over 48 rounds; E.5's
"sides rotate per round" was world-B's open item [G31] and is built in phase 3 (`VersusClubball.swapped`: odd rounds
swap the goal mouths and kick-off spawns). V4.b's +/-15 points then hold per team: a team that wins more than 65 % of
the seeded rounds whichever side it plays is a referee or bot bias to fix, never a reason to drop the bots (cut 4 is
for a failing graph [G50]).

### E.6 Themed sudden deaths

Per biome: Stampede (jungle), Cave-in (cave), Whiteout (ice), Lava rise (volcano), Tar rise (swamp), High tide (coast),
Syrup flood (feast, slows only), Stalactite storm (keep), Rockslide (canyon), Lightning (sky). Every one telegraphs 10+
ticks ahead. They start at 60 s in Last Caveman Standing and are available as an event toggle in the other modes.

### E.7 Bots (at launch, for all four launch modes)

- A bot is an **input producer** (`InputSlot.BOT`): each tick it writes the flags a human would, decided from the
  previous tick's state, with its own `SimRng` seeded from the match seed and the slot. It never draws from `Sim.rng`
  and never knows what a spot or crate contains. A bot match replays tick for tick and runs headless as a test.
- **Navigation**: a graph per arena baked offline (`tools/bots/`): nodes are standable spans; links are walk, drop,
  hatch, jumps with k held ticks (from `PHYSICS_REFERENCE.json`), spring, geyser (timed), see-saw, pulley, wrap. **Every
  link is verified by simulating the real hero**, like the route proofs. Moving geometry (lifts, floes) is a moving
  node.
- **Goals**, chosen every 6 ticks by utility: food, spots, the cookpot (bank when the stack is tall), the leader,
  the ember (flee or pass), the coconut (Clubball bots predict its landing with the deterministic ball physics and
  stand goal-side of it), safety. Combat micro-rules from the triangle: high strike against a jumper above within
  26 px, crouch-charge against an approaching rival, stomp a croucher, deflect specials, bat curled rivals toward
  hazards.
- **Levels**: Rookie (reacts in 10 ticks, never charges or deflects), **Hunter** (default; 6 ticks; stomps and
  charges), Chief (3 ticks; stomp chains; deflects half the time; never frame-perfect). Difficulty is reaction and
  decisions, never cheating.
- The same `HeroBot` drives the Rival Chieftains (B.6).

### E.8 Match flow and results

1. **Lobby**: four slots, press Jump on any device; colour and loincloth pattern; team toggle; *Add CPU* (level);
   handicap card; hold Strike = ready. Music: Spring Spring "Melon Field" character-select loop.
2. **Rules**: mode, preset, rounds, round time, crates, weapons, variants (whoever pressed Start controls it; the last
   rules are remembered).
3. **Arena**: thumbnails, Random, Party Mix; locked arenas show their painting count.
4. **Round**: heroes burst out of spots on "3, 2, 1, GRUB!" (kheetor countdown beeps + Junkala `fanfare2`; no adult
   voice); play; gong (Junkala `fanfare1`).
5. **Deciding moment**: the last 3 s (Grub Stack: the biggest steal) replayed at half speed from the input log and a
   start snapshot; skippable.
6. **Scoreboard** (about 5 s): round wins as drumsticks thrown onto each player's plate.
7. **Results**: the heroes painted on a cave wall in victory poses; the tally companion hands out 1-3 awards each -
   Leaning Tower (tallest stack), Pickpocket (most stolen by stomps), Glutton (most eaten), Butterfingers (most
   dropped), Chain Gang (longest stomp chain), Clang Master, Slugger (most curled rivals batted), Home Run (longest
   Clubball shot), Hot Potato, Lava Lover, Head Case (bonked by a giant bonus), Comeback Caveman, Pacifist. **Rematch**
   is the default button. Match-win jingle celestialghost8 "Victory"; results loop Spring Spring melon win; CC0
   applause bed (eXpl0it3r).

### E.9 Controls and readability for 2-4 on one device

- Every player needs only direction + Jump + Strike + Swap; Look doubles as the emote / taunt in versus.
- **Keyboard**: two players at most, the D.11 layouts; the **classic WASD + numpad layout is the versus default**
  (old-school one-keyboard deathmatch: P1 on W A S D + Space / Left Ctrl, P2 on the numpad 8 4 5 6 + 0 / Enter;
  Left Ctrl, not Left Shift [G12]).
  Must be proven by a scripted two-player versus match driven only by those keys. **Pads**: up to four, a sideways
  half-controller works.
  **Touch**: one touch player on a phone or a tablet (swipe up on strike = high strike); the two-player table mode is a
  hidden prototype in 2.0 [G37]. Any mix:
  keyboard halves for P1-P2 and pads for P3-P4, or one tablet player against three bots.
- **Telling four cavemen apart**: P1 yellow, P2 blue, P3 pink, P4 green (white on jungle arenas); loincloth patterns;
  P1-P4 tags and colour arrows at round start and whenever heroes overlap; hit sparks in the attacker's colour; four
  corner panels (a 28 px head painted from the 1.0 HUD head and the Ninja portrait, recoloured per player - the
  panels are one arena row tall and the Ninja portrait exists only at its integer 2x, which serves the lobby, the
  join panel and the results [G25]; stack or hearts, held special); the round sundial top centre; the crown on the
  leader; bubbles for heroes above the view.

---

## F. Assets, audio and production

### F.1 Art map (every need -> a staged pack or a stated edit; all CC0)

Path prefixes: **RB** = `.tools/asset_candidates/expansion/superpowers-rpg-battle-system/`, **NA** =
`.tools/asset_candidates/expansion/pixelboy-ninja-adventure-full/Ninja Adventure - Asset Pack/`, **WF** =
`.tools/asset_candidates/expansion/superpowers-western-fps-2d/`, **AP** =
`.tools/asset_candidates/environment/superpowers-prehistoric-platformer/` (the anchor), **SH** = shipped `assets/`.
Global edits: every imported sprite's near-black outline -> `#272018`; Ninja art at integer 2x only; nearest-neighbour
only; every sheet at most 2048 px on a side (re-pack, as the Brute was).

| Need | Source | Edit |
|---|---|---|
| Terrain, canyon (`canyon/terrain`, `canyon/terrain_mesa`) | SH `tiles/volcano/terrain.png`; SH `tiles/cave/terrain_stone.png` | gradient maps (proven: `_style_tests/terrain_canyon.png`); same 40-tile layout and collision table |
| Terrain, swamp + mushroom (`swamp/terrain`, `swamp/terrain_mushroom`) | SH `tiles/jungle/terrain.png`; SH `tiles/jungle/terrain_grass.png` | gradient maps (`terrain_swamp.png`, `terrain_mushroom.png`) |
| Terrain, coast (`coast/terrain`, `coast/terrain_sand`) | SH `tiles/cave/terrain.png`; SH `tiles/feast/terrain_biscuit.png` | gradient maps (`terrain_coral.png`; biscuit toward sand) |
| Terrain, ruins (`ruins/terrain`, `ruins/terrain_jade`) | SH `tiles/cave/terrain_stone.png`; SH `tiles/jungle/terrain.png` | gradient maps (`terrain_temple.png`; mossy jade) |
| Terrain, sky (`sky/terrain`, `sky/terrain_rock`) | SH `tiles/ice/terrain.png`; SH `tiles/ice/terrain_rock.png` | gradient maps (`terrain_sky.png`; slate) |
| Tar floor `:` and liquids `tar` / `honey` / `syrup` | SH `tiles/common/water.png`; a set-A ground tile | recolours (black-violet, amber, pink); tar floor = surface tiles 0-2 recoloured with a 6 px lowered top |
| Parallax, canyon | RB `backgrounds/17.png`; WF `background-elements/rock-background.png`; `emceeflesher-rocky-desert-landscape` layers | crop the horizon band, **paint out the two towers**; mesa strip at 2x as mid layer; Emcee layers gradient-mapped warm, far layers only |
| Parallax, swamp / mushroom cave | RB `backgrounds/12.png`; SH `backgrounds/jungle/layer1-3`; SH `backgrounds/cave/*` | band crop + night variant; jungle layers gradient-mapped murky teal; cave layers gradient-mapped purple |
| Parallax, coast / sea caves | AP `background-elements/background-1.png` (sea cliffs); RB `backgrounds/5.png`; SH `backgrounds/cave/*` | band crop; cave layers recoloured teal |
| Parallax, ruins | RB `backgrounds/21.png`, `22.png`; SH `backgrounds/jungle/layer3_forest.png`; SH `backgrounds/cave/layer0_wall.png` | band crop, **paint out towers**; recolours sandstone |
| Parallax, sky | SH `backgrounds/ice/layer0_sky.png`, `layer1_far_peaks.png`; `environment/superpowers-backgrounds` sky islands 15 / 39; AP `cloud-1.png` | recolours; Superpowers islands at 4x **farthest layer only** |
| Props | WF cactus-1..3, rock-1..6, rolling-bush, skull, bone, tree-1/-2, branch; SH `tiles/jungle/props/*`, `tiles/village/props/*`; RB `item/*` shells and feathers; NA `Backgrounds/Tilesets/TilesetNature.png` reeds (2x) | 1x as is; recolours per biome |
| New enemy sheets | RB `monster/{dino,reptile,mimic,snake,slime,mushroom,bat,ghost}`; NA `Actor/Monster/{Octopus,RedOctopus,Larva}`, `Actor/Animal/Fish`; `characters/ansimuz-sunny-land-series` eagle, frog; WF `animals/` bear | outline swap; RPG at 1x; Ninja and Sunny Land at 2x; reptile armour recoloured bone / stone; jelly = slime recoloured translucent blue; sea snail = SH `turtle_b` + AP shell item 18 |
| Co-op-only enemies | SH `mini_rex_b`, `bat_b`, `pterodactyl_b`, `rex_b`, `turtle_b`; NA `Monster/Larva`; RB `slime`, `reptile`; AP `characters/npc/dragon-man` | gull = `pterodactyl_b` recoloured white; Larva recoloured |
| Tusker | RB `monster/boar/sprite-sheet-239x178.png` (+ `-2-` palette for rage) | outline swap, tusks lengthened |
| Old Mangrove | NA `Actor/Boss/GiantBamboo` (Idle, Attack, Charge, Hit) 2x; SH `props/jungle/root_arch.png`, `objects/boulder.png`, `vine_branch.png` | gradient map to bark; fist and 3-segment root arm composited |
| Inkjaw | NA `Actor/Boss/SquidGreen`, `SquidRed` 2x; RB `monster/octopus.png`; SH `fx/projectile_rock.png` | tentacle segments cut from the octopus arm, recoloured; ink blob recolour |
| Twin Idols | SH `bosses/colossus.png`; SH `fx/projectile_stalactite.png` | mirrored copy; gradient maps jade and sandstone |
| Storm Roc | SH `enemies/pterodactyl.png` at 2x; AP items 43-46 (feathers); RB `fx/*` | gradient map storm slate, gold crest; **re-pack 4 x 4** (1152 x 960); lightning recolour |
| Rival Chieftains | SH `enemies/rival.png`; AP items 57-58 (dino skulls); SH `enemies/egg_kid.png` | two palette swaps; headdress composite; egg recolours |
| Co-op Colossus visor and plates | SH `objects/carved_block.png`; AP `tileset-1.png` crest icons | visor cut from the carved block; plate = flattened slab + crest |
| Hero colours P2-P4 | `.tools/asset_candidates/expansion/hero_colours/` (mapping proofs) | shipped as **16 x 1 LUTs per slot** for a palette-swap shader, not baked sheets |
| Hero poses | SH `sprites/player/hero*.png` (52 frames) | climb = 44-47; curl = roll 24-26; ride (rider) = crouch 21; carried-by-glider = glide 50-51; cheer = victory 48-49; none needs new drawing |
| `hero_spear` sheet + spear pick-up / projectile | AP item 12 (spear) | composited into the hero sheet the way 1.0 built `hero_axe` |
| Egg (revive) | SH `enemies/egg_kid.png` roll frames | per-slot LUT |
| Chomper with riders | SH `enemies/rex.png` (1x) + hero crouch frame 21 | saddle strap pixel edit; second-seat composite; riders take the slot LUT |
| Raft | SH `objects/platform_wood.png` x2 + AP log item; wafer skin from SH `feast/terrain_biscuit` | composite + rope pixels |
| Vine, rolled vine | SH `props/jungle/vine_a.png`, `vine_b.png`, `vine_branch.png` | stacked; coil cut; recoloured per biome |
| Bark board | SH jungle terrain tile 15 (inset panel) | recoloured bark, one cell |
| Geyser spout | SH `fx/splash_water.png`, `fx/particles_smoke.png` | stacked frames; recolours mud / blowhole / steam / soda |
| Plate, drum, see-saw, heave boulder, pulley, flower pot, x2 tablet, rex pen | SH `objects/carved_block.png`, `objects/barrel.png`, `objects/platform_wood.png`, `objects/boulder.png`, `items/bone.png`, `tiles/village/props/flower_pot.png`, `stone_tablet.png`, `palisade.png`; WF `background-elements/skull.png`, `barrel.png` | plate = flattened carved block; drum = barrel with a hide top + crest; see-saw = plank + bone ends + skull pivot; pulley wheel = barrel end recoloured wood + 2 px rope; x2 tablet = stone tablet + two hero silhouettes in ochre; pen = palisade |
| Cave Paintings + mural, map slab | SH `village/props/stone_tablet.png`; AP crest icons; shipped sprites as ochre silhouettes | composites |
| Far Shore map page | SH `ui/world_map_background.png`; new terrain atlases; WF cacti; ruin props | gradient-mapped islands + props, 1280 x 360 |
| Belt icon | SH `items/weapon_club.png`, `weapon_hammer.png`, `weapon_axe.png`, `weapon_boomerang.png` + the spear item | 1x |
| Join / HUD / versus UI | NA `Actor/Character/Caveman/Faceset.png` (portrait), NA `Ui/Emote/*`, NA `Ui/Input` prompts; AP crests; RB `item/26.png` (goblet), `item/64.png` (laurel); SH `ui/icons.png` arrows; SH `npc/companion.png` | recolours per player (as `_style_tests/mp_ui_test.png`) |
| Versus objects | cookpot = SH `objects/pot.png` over AP `fire.png`; coconut = NA `Items/Food/Nut.png` at 2x recoloured brown; crate = SH `objects/crate.png` under SH `pterodactyl`; goal mouth = SH `village/props/palisade.png`; Grudge Pterodactyl = SH `pterodactyl` + rider in the slot LUT | composites |

Gaps deliberately designed around (no art exists): mammoth, sabre-tooth, triceratops, giant crab, eagle boss, stone
golem boss, animated yeti, swim poses, in-style rope / zip-line / balloon / mine cart.

**As built in phase 2 [G24]** (reasons in art-B's WORLD6-9 hand-overs, "Decisions", and art-A's manifest 17.x):
the Mimic is the shipped container chest with pixel-edited tells (the RPG mimic is three times bigger and in another
style); Old Mangrove's root arm is cut from a Ninja Adventure log (`vine_branch` is 6 px thin); the sea snail wears
the RPG spiral shell (AP item 18 is a turtle shell); the ruins backdrop is built from the new temple tiles and the
shipped jungle layers (RPG backdrops 21 / 22 are perspective castle paintings that do not cut into a side band); the
Storm Roc's gold crest became a gold head and beak (a mask edit that reads at every angle); lightning is one
stackable bolt segment (`bosses/roc_lightning.png`); the versus corner panels use 28 px heads [G25]. Three atlases
beyond the ten above: `swamp/terrain_bark` (inside the hollow mangrove), `coast/terrain_cave` (wet sea-cave rock),
`ruins/terrain_carved` (exit-totem stone, temple plinths, the Totem Ring's totem); two Feast Land atlases:
`feast/terrain_honeycomb` (Feast Land D) and `feast/terrain_pudding` (Feast Land E). Sizes to design with (scale
boards in `.tools/asset_candidates/expansion/_handover/mocks/`): octopi about 1 x 1 tile, leaping fish 1 x 0.5, the
ruin ghost about 2.5 x 2.5, each Twin Idol Colossus-sized (a 2-column wall and 7 rows), the Storm Roc about
6.5 x 3 tiles (logical 103 x 44). The 30 Cave Paintings have two pictures each: `ui/paintings.png` (one ochre figure
per index) and a 24 x 16 piece of `ui/mural.png`, so the 30 finds assemble the mural that ends the Long Raft Home.
Phase 3 (art, `docs/art/expansion/phase3_art.png`, ASSET_MANIFEST 17): the Long Raft Home's five islands are
set-piece props `props/coast/isle_{mesa,mangrove,stacks,idols,spire}` (each world's terrain and props on a sand bar,
placed as back props on the water's surface row), the home beach `props/coast/feast_table` / `feast_spit` (the empty
spit of the stolen Great Roast), the railed raft's fence `objects/raft_rails.png` (closed / open towards a bank,
G45; objects-B draws it); Feast Land E's custard is `tiles/feast/syrup_floor.png` (a `:` cell in a feast + syrup
level); `swamp/terrain_bark` carries bark grain for Old Mangrove's trunk; the Storm Roc's feathers are storm slate
with a gold tip and its gust swirl a 3-frame loop downwind; Mesa Rodeo / Cloud Top proposals and the arena side
frames `ui/arena/frame_*.png` wait for cut 3 and a drawing script (E.5).

### F.2 Audio map (all CC0; staged under `.tools/asset_candidates/{audio,expansion/audio}/`)

| Context | Pick | Fix before import |
|---|---|---|
| 5-1 / 5-2 | Wolfgang_ "Desert Theme" (`desertbounce-trimmed`) / Spring Spring "Suez Crisis Remade" | desert theme 1.6 LU short of target under the TP cap: limit |
| 6-1 / 6-2 / 6-2b climb | Junkala Super Action stage_7 / Wolfgang_ "Haunted House" / Tallbeard "Pixel War 1" | - (Haunted House's 120 ms tail is the last beat's staccato rest: the master is 112 beats at 150 BPM; kept) |
| 7-1 / 7-2 | Spring Spring "Sandy Seaside" / Tallbeard "Deep Blue" | - |
| 8-1 / 8-2 | Junkala Super Action stage_9 / Tallbeard "Penultimate" | - |
| 9-1 / 9-1b / 9-2 / 9-3 approach | Wolfgang_ "Upbeat Overworld" / Spring Spring "Typhoon's Theme" v3 / Junkala Retro Sports stage_final / Junkala Super Action stage_6 | trim Typhoon's 82 ms lead and the stray downbeat at its end (the loop is the region between the two downbeats) |
| Bosses | Tusker nene "Boss Battle #1"; Mangrove nene #2; Inkjaw nene #4; Twin Idols Spring Spring "Egyptian Fortress Boss"; Storm Roc nene #6; Chieftains nene #3 | nene tracks cut to one loop region of at most 90 s (two variations where the render has them: #3 79.4 s, #4 84.2 s; #1 / #2 / #6 are one 24-32-bar loop, 50-53 s); #3's seam is the render's own; Egyptian master is hot (vol -12) |
| Feast Land D / E, ending_b | shipped `bonus` context / Tallbeard "Box Jump" / Spring Spring "Tropical Fantasy" + shipped credits | - |
| Co-op menu, join | Tallbeard "Connected"; ctske `square_partyjoin` | trim 84 ms lead |
| Versus lobby, battle, sudden death | Spring Spring melon charselect; Junkala Retro Sports stage_3, Tallbeard "Out of Time", "Go (No Vocal)"; sudden death: Junkala Chiptune Heroes "dangerous encounter A (faster)" (a designed 32-beat loop, 19.7 s) - Wolfgang_ "8-Bit Battle Loop" cannot loop (22.7 ms short, a dropout at the seam) | "Go" cut to its exact bars; its +2.0 dBTP needs no limiter (the AudioTable volume keeps it under -1 dBTP) |
| Stingers | countdown kheetor + Junkala Blip5 / fanfare2; round gong Junkala fanfare1 (`Sfx.ROUND_GONG`); round win Junkala fanfare1 / MintoDog "Stage Clear Short"; match win celestialghost8 "Victory"; results Spring Spring melon win; sudden death Junkala alarm_loop1 + refereewhistle | trim Victory's 1.06 s tail |
| Lightning bolt (`Sfx.LIGHTNING_STRIKE`: `zones/lightning`, Cloud Top, the Storm Roc's phase 3) | MoxieCat "lightningstrike" (an 8-bit noise crash) | trim to 1.5 s (a realistic thunder clashes with the chiptune mix) |
| New effects | swap Junkala interaction6; spear stick Spring Spring snd_enemyland; vine Junkala ladder1loop; raft / splash Skippy Fish water + waterReentry, Basto heavy_splash; geyser BMacZero bubbles-single2 + heavy_splash; tar Spring Spring glug; egg down Junkala neutral2; hatch Junkala powerup2; Shoulder Hop / Totem Ride Junkala interaction16; curl MoxieCat dashcharge; bat hit artisticdude swish-7..9 + MoxieCat dashwoosh; brace Spring Spring snd_enemyland; plate Kenney switch_002; drum Junkala Blip5; see-saw Spring Spring snd_sproing; boulder / pulley Kenney creak1 / creak3; daze Junkala nagger2; Chomper bite shipped dino_voice + food_chomp; cookpot bank Junkala powerup8; crate drop Kronbits Retro Swooosh 02; Hot Rock fuse Junkala Blip5 -> alarm_loop1; crowd eXpl0it3r applause, qubodup Well Done | loudness to the 1.0 rules (`tools/audio_loudness.py`: music -18 LUFS, effects -14, TP <= -1 dBTP) |

No CC-BY file ships (owner decision 5); nothing was auditioned by ear, so one human listen-through precedes the lock
(P4.4; the list is at the end of audio's `AUDIO_BATCH2.md`). **Music budget** [G26]: every 2.0 music file at most the
largest 1.0 track (3.55 MB) and 110 s; the 2.0 music files together at most their count times the 1.0 average per
track (30 files: 44.4 MB). Batch 2 ships 41.4 MB (the game's music grows from 31.1 to 72.5 MB); the Android package
gets a tighter number only if P4.2 asks for one (q0.4 re-encodes of the twelve largest tracks save about 8 MB).
Tallbeard "Penultimate" (8-2) and "Go" are cut to their exact bars; Spore Hollow, Cloudbreak Climb and the storm
glide are limited 1.2-1.4 dB (the canyon rule).

### F.3 Licences and files

Every new asset goes through `docs/ASSET_MANIFEST.md`, `CREDITS.md` and `docs/THIRD_PARTY.md` exactly as 1.0. CC0
only; never NC / ND / SA / GPL art, rips or unlicensed AI output; never Prehistorik / Titus assets, names, maps or data;
no code from `.tools/ref`.

### F.4 Production summary (details in PLAN.md)

About **130 engineer-weeks** (plus or minus 30 %): phase 0 contracts and the N = 1 identity refactor (single owner,
blocking), phase 1 systems, phase 2 entities / bosses / UI / art, phase 3 content and route proofs, phase 4 QA and the
2.0 release.

| Proof | Count |
|---|---|
| Book I solo routes changed | **0** of 72 (15 files byte-identical) |
| Book II solo club routes | 31 (11 Beginner + 20 Expert cells) + about 6 featured secret / painting routes |
| Belt-invariance replays | 4 specials x every Book II and co-op route (generated, not recorded) |
| Co-op two-stream routes | 57 (Book I 11 + 15, Book II 11 + 20) |
| Solo-impossibility searches | every x2 gate (about 60) |
| Boss tests | 6 new bosses + 2 co-op forms |
| Bot matches | every (arena, launch mode) pair the arena supports |

---

## Appendix: new ids, keys and actions (for the phase-0 contract owner)

| Kind | Additions |
|---|---|
| Input | action `swap` (flag `IN_SWAP`, route key `S`); per-slot generated `p1_*`..`p4_*` actions; Settings `[bindings_p1]`..`[bindings_p4]` |
| Meta | `book` (1 / 2); `belt = fresh\|carry`; `kind = coop` + `coop_of`, `coop_base_hash`; `kind = arena` + `players`, `round_time`, `modes`, `bots` [G50], `wrap = none\|lr\|tb`, `sudden`; `liquid = tar\|honey\|syrup`; `scroll = rising` + `rise_speed`; biomes `canyon`, `swamp`, `coast`, `ruins`, `sky` |
| Tiles | `:` tar floor (set A, lowered surface, slow) |
| Entity params | `coop=<trait>`, `bond=<name>` (enemies, drums); `slot=n` (hero_start); `rise_while=` / `sink_while=` / `trigger=keepers:<name>` (column) |
| Enemies | `enemies/roller`, `guard`, `mimic`; co-op: `shellback`, `raptor`, `snatcher`, `leech`, `bull_rex`, `tar_splitter`, `shaman` |
| Bosses | `bosses/tusker`, `mangrove`, `squid`, `idols`, `roc`, `chieftain` (two instances, `mate=<name>`); Brute and Colossus gain co-op behaviour |
| Objects | `objects/vine`, `bark_board`, `geyser`, `raft`, `mount`, `rex_pen`, `plate`, `drum`, `seesaw`, `boulder_heavy`, `pulley`, `flower_pot`, `x2_tablet`, `hero_start`; versus: `cookpot`, `coconut`, `crate_lane`, `spawn_point`; team rules on `exit` / `gate` |
| Items | `items/painting index=0..29`; `items/weapon kind=spear` |
| Zones | `zones/current`; versus `zones/goal team=1\|2` |
| Projectiles | `projectiles/hero_spear` |
| Specs | PHYSICS.md appendix "Party and Book II rules" (belt and swap, spear, climb, tar, geyser, raft, rising scroll, mount, hop / ride / curl / bat / brace, egg, versus hurt table); GAMEPLAY.md 13 "Expansion 2.0". Sections 1-12 do not change |
| Added by P0.2 | `Defs.Weapon.SPEAR = 4` (name `spear`); meta `wind_loop` (and negative `wind` values); `objects/geyser deadly`; `objects/bark_board face`; `objects/raft rails`; `objects/mount wild`; `objects/plate w`; `objects/pulley range`; `objects/column trigger=drums:<bond>` and static `rise=0` columns; `objects/gate needs=<bond>`; `objects/x2_tablet far=c,r` and `secret`; `objects/spawn_point index`; enemy params `keeper=<name>`, `perch=c,r` (grab), `snatcher kind=dangler\|stinger`; `items/weapon temp=true` (versus); zones `zones/lightning`, `zones/food_rain`; tile flag TAR (`:`); `PlayerBase.launch()`, the hero timer `shield`; the route header `# route:` (LEVEL_DESIGN.md 15.9); reference data `docs/spec/PARTY_REFERENCE.json` |

---

## Appendix: P0.2 spec resolutions

Ambiguities and inconsistencies of this document found while writing the specs (PLAN P0.2), with the resolution
the specs implement. The text above carries the marker where it changed.

| # | Topic | Problem | Resolution (spec) |
|---|---|---|---|
| R1 | Spear recovery | "6-tick recovery" can mean L = 6 or 6 ignored ticks; `Defs.Weapon` has no spear | L = 6 as the axe (5 ignored-input ticks, FIRE held throws every 12); `Defs.Weapon.SPEAR = 4`, name `spear` (PHYSICS C.3) |
| R2 | Tar hop | 3 impulse ticks give a 47-48 px hop, not "about 30 px"; with full air control a tar hop covers 64 px, faster than wading | 2 impulse ticks (33 px) and the airborne `ACCEL` limit 32 after a take-off from tar *(tune)*; `Tuning.TAR_JUMP_IMPULSE_TICKS` must be 2 and `TAR_AIR_CAP = 32` added (PHYSICS C.5) |
| R3 | Vents | 6-2b and 4-1 co-op plug a "vent" with a heave boulder; no vent object exists | `objects/geyser deadly`: a deadly spout; a boulder resting on any geyser plugs it (PHYSICS C.6) |
| R4 | Alternating gusts | the 1.0 wind only pushes left and its script cannot repeat (9-2, Floe Rink, Cloud Top, the Roc's gale) | negative `wind` pushes right (the WIND primitive unchanged); meta `wind_loop` repeats the script (PHYSICS C.6) |
| R5 | Missing ids | lightning (9-1b, Roc phase 3, Cloud Top) and the fruit / food rain (Feast Land E, the Long Raft Home) have no entity | `zones/lightning` (mark 22 ticks, bolt 4) and `zones/food_rain` (the ember-rain zone with food) |
| R6 | Totem Ride reach | from a still carrier the rider's jump reaches 98 px (6 tiles), below a 7-tile boost ledge; TECH_AUDIT 4.4 put stacking in `PLATFORMS` from previous-tick positions | the rider's jump starts from the carrier's rising speed (the 11.4 platform rule): timed 1-5 ticks after the carrier's halved jump it reaches 139-152 px, so "Shoulder Hop or Totem Ride" holds for 7-8 tiles; the plain Totem ledge is 5 tiles. The ride is resolved by the `PartyDriver` after both heroes moved (PLAN P1.6), not in `PLATFORMS` (PHYSICS C.10) |
| R7 | Hot Rock | "walks at most 96 v16" is no limit (the walk cap is 80) | the holder's cap is raised to 96: the ember carrier is the faster one (RESEARCH_VERSUS 3.4) |
| R8 | Co-op boss hit points | 190 exceeds x1.25 of 150 (187.5) | 187 (still 8 club hits: a boss dies at 0 hp); Expert 280 stays; Roc phases 1-2 250; Idols 8 per idol; Old Mangrove's co-op stages (not given) 5 + 3 twin hits Beginner, 7 + 6 Expert *(tune)* |
| R9 | `lone` | "the hero farther from his partner" is the same distance for both heroes | keeps away while the heroes are within 64 px of each other; else targets the hero farther from the view centre (ties: the higher slot); the Chieftains' P1 uses the same rule |
| R10 | Keepers and drums | "every enemy named `<name>`" clashes with the unique `name=`; drums "open a column or gate" without a link | enemies take a group tag `keeper=<name>`; a drum bond opens `objects/column trigger=drums:<bond>` or unlocks `objects/gate needs=<bond>` |
| R11 | GAMEPLAY.md 13 | GAMEPLAY.md already had a section 13 ("Items still [INFERRED]") | "Expansion 2.0" is section 13; the old list is section 14 (nothing referenced its number) |
| R12 | Raptor daze | 14 / 12 ticks against the rule "below the measured solo minimum minus 4" with the estimate "about 15 ticks" (cap 11) | 14 / 12 are upper bounds; each record uses `min(14 B / 12 E, solo_min - 4)`, measured by `test_coop_gates`, tuned at G1 |
| R13 | See-saw | "a hard landing (4+ tiles fall) launches ... +64 on a hard landing" is circular | every landing on the high end launches `-(yvel + 32)`, 64 more on a hard landing (PHYSICS 6.5), cap -288; a result weaker than -64 only lifts (GAMEPLAY 13.9.7) |
| R14 | Swap and Jump | every 1.0 input is level-triggered; Jump and Up are one flag (`IN_UP`), so "Up climbs" and "Jump lets go" collide on vines | Swap is the only edge-triggered input (a held Swap does not repeat); on a vine Up climbs, a direction + Up leaps off, Down + Up drops (PHYSICS C.1, C.4) |
| R15 | Hatch blinking | "44 ticks of blinking" with `hit_timer = 44` would also stun for 22 | a new hero timer `shield` (44, blinking, full control) and a -64 pop (PHYSICS C.12) |
| R16 | Versus hurt | "12 stunned + 30 immune" on the 1.0 `hit_timer` | `hit_timer = 43`, stunned while >= 31 (PHYSICS C.14) |
| R17 | Batter Up | an uncharged line drive covers 153 px: a 9-tile gap leaves 9 px; a charged lob (-360) breaks the 18 px/tick doze rule | gaps 8 tiles Beginner / 9 Expert (curl spot at the edge or a charged drive); every launch component clamped to +/-288 v16 |
| R18 | Ledge height per difficulty | one co-op file serves both difficulties but boost ledges differ (7 / 8 tiles) | build at 7 rows plus an `expert`-flagged static `objects/column rise=0` of one row (LEVEL_DESIGN 15.7.3) |
| R19 | Shoulder Hop | "as on an enemy" lets a hero hop off an airborne partner | kept; chained duo moves reach 12-13 tiles, so co-op paths are contained by 13+ rows (LEVEL_DESIGN 15.7.2) |
| R20 | TECH_AUDIT bubble | TECH_AUDIT 4.5 / 4.7 describe a bubble (touch revive, 1 heart, 48-tick leash) | superseded by this document's egg (hit / throw / bounce, 2 / 1 hearts, 121 / 73-tick leash) |
| R21 | Far marker | D.8 needs "the gate's far marker", which no id carries | `objects/x2_tablet far=c,r` (and `secret` for x2 secrets) |
| R22 | Grub Stack pieces | "1 + stack/5 pieces" with food worth 1 / 2 / 5 / 10 | the stack is an integer count of units; spills count units and fly out split into 10s, 5s and 1s |
| R23 | Rising tide start | where the band starts and how the camera behaves are not given | 6 rows under the start point (as after a checkpoint); the view never scrolls down and keeps the band's top row on screen (PHYSICS C.8) |
| R24 | Brace daze | D.4 dazes a heavy 44 ticks, B.1 the co-op Tusker 66 | both: 44 for `heavy` enemies, 66 for the co-op Tusker (boss rule) |
| R25 | Unstated geometry | mount box and saddle, egg drift, curl box, spear box, raft height, validator "within reach" | starting values marked *(tune)* in PHYSICS C (mount box 58 x 35 from the manifest, saddle 26 px; egg 2 / 6 px per tick; reach = 10 cells across, 11 rows down) |

---

## Appendix: G1 and phase-2 resolutions

Gate G1 (2026-10-07) passed on every automated criterion: `w5_l1` with its club routes and belt invariance,
`w5_l1_coop` and `w1_l1_coop` with two-stream routes (deterministic, doze- and device-independent), all ten x2 gates
refused by the single-hero search, Totem Ring Grub Stack with two classic-keyboard humans and two Rookie bots, the
flows through the real UI, single-player identical. The human pair playtests did not take place. Below: the
orchestrator's resolutions after G1, the lead designer's decisions on every deviation the builders and slice
designers reported (`build/engine_requests/wf7_*` / `wf8_*_to_lead_designer.txt`), and what phase 2 built where the
specs were silent. The text above carries the marker; the per-tick wording is in PHYSICS Appendix C (P-C), the feature
rules in GAMEPLAY 13 (G) and the building rules in LEVEL_DESIGN 15 (LD). G28-G32 are the G2 integration's; G33-G43
are the orchestrator's phase-3 decisions and the lead designer's decisions on the G2 reports (2026-10-08; the rulings
went to the owners as `build/engine_requests/wf9_lead_design_to_*.txt`); G44-G53 are the lead designer's rulings on
the reports of phase 3.

| # | Topic | Problem / report | Resolution (where) |
|---|---|---|---|
| G1 | Egg as a springboard | G1 verifier: a partner falling onto an egg with Up bounced -224 (a Shoulder Hop), and where the view cannot rise the clamp pins the egg over the active hero's head - one player reached a boost ledge alone (1 of 1200 random tries; with the idle hatched body 18 / 13 of 1200) | **orchestrator**: the hatch bounce is -64 whether Up is held or not; the Shoulder Hop needs an **active** partner (his own slot gave input since he last hatched or spawned); Up passes through an idle partner's head; a Totem Ride on an idle partner still starts (98 px, below every boost ledge) (D.3, D.4, P-C.10, P-C.12; player-A `land_on_partner`, world-A `PartyDriver.is_active`) |
| G2 | Window per record | "min(24 B / 12 E, solo_min - 4)" needs a per-record value | enemy records take `window=<ticks>`: effective = min(difficulty value, `window`), a bond uses the smallest of its members, one value serves both difficulties; designers set it from the solo minimum `test_coop_gates` measures. Count-in of enemy windows: three blips 8 ticks apart, then "go", while every member has a hatched hero within 48 px on both axes and they are not all one hero, once per arrival; drums: while a hatched hero stands within 40 px of every drum (D.4, G 13.9.3, LD 15.4) |
| G3 | Window and daze values | G1 was to tune them in pair playtests, which did not happen | **kept**: windows 24 B / 12 E, Raptor daze 14 B / 12 E, Mimic daze 22, Inkjaw flinch 24 B / 16 E. Phase-3 content is built with them; the human pair playtests move to P4.5. Windows can only shrink (never above `solo_min - 4`), so a later tuning keeps every gate solo-impossible (D.4, G 13.11) |
| G4 | Keeper and Guard halls | 3 rows let a hero bounce over the 54 px Guard / Shellback art | **4 rows** (orchestrator, since phase 1; `PartyTuning.KEEPER_HALL_ROWS`) everywhere: D.5, D.8, D.9, D.10, A.2-A.3, G 13.9.7, LD 15.7 |
| G5 | Stationary keepers | a walker with `left = right = 0` still sways about 30 px, so bait and back-strike distances are fickle (DB1) | **accepted** (orchestrator): keepers meant for a pincer stand still (`speed=0`); bait about 30 px in front, striker about 40 px behind (LD 15.7.3) |
| G6 | Flower-pot reach | the pot spring (-224, 105 px) cannot reach a 7 / 8-row boost ledge from the dip under its face (DB1) | **orchestrator**: the pot reaches **6 rows from the floor it takes root on** (19 px to spare; a 7-row ledge is 3 px under the apex: neither a way back to rely on nor a barrier); under a 7- or 8-row boost ledge the pot lands on a raised spot of 1-2 rows (D.5, G 13.9.7, LD 15.7.3) |
| G7 | Totem rider, batted ball | read literally, "the ride ends if R.yvel < -16" sheds the rider of a rising carrier after one tick (no R6 Totem launch); a line drive slid on after landing | **accepted as built** (player-A): the ride ends when `R.yvel - totem_carry_yvel < -16` (his jump measured against the carry); no Totem Ride on a curled or mounted partner (the hop still works on a curled one); a line drive or a lob stops where it lands (`xvel = 0`): its 153 px are where the hero stands (P-C.10, P-C.11) |
| G8 | Vine and tar rules | lock-outs, the tar hop on tar, impulses out of tar, climbing from platforms, Down + Up (player-B) | **confirmed**: the top step is a landing and a drop / letting go below `bottom + 16` arms `no_jump = 6`; the grab tick only attaches; Down + Up never grabs; a climber is held by his vine (no sprite platform catches him); the tar hop on tar lands on tick 16 (32 / 32 px); the tar rules end on any outside impulse; a geyser on a tar floor sits on the lowered surface and launches a wading hero with full air control (C.3, C.4, P-C.4, P-C.5, P-C.6, LD 15.3 / 15.5) |
| G9 | Co-op object conventions | plate anchor, door rule, see-saw geometry, two-corridor leapfrog, tablet lights, team gate, spear tested at its spawn (objects-A, DB1, D5) | **confirmed as built** (D.5, G 13.9.7, LD 15.7.3 / 15.7.8) |
| G10 | Snapper bait-and-bite | D.6's built-in rule (stem open 20 ticks after a lunge, only from the far side) as a base behaviour turns every snapper of every co-op file into a gate - including Book I copies where a wall backs the plant - and would change the recorded G1 routes | **dropped**: snappers keep the 1.0 rules in co-op (target the nearest, the bite tests every hero); twin rattlers use `bond`. Built instead: a co-op party's club cuts a dangler's thread; zone spawners alternate between the heroes inside, `max` x1.5 (D.6, G 13.9.4) |
| G11 | Co-op enemies as built | Mimic, Shaman, Bull Rex, Snatcher, Tar Splitter, Book I Shellback were open in detail (enemies-A) | **accepted**: GAMEPLAY 13.5 / 13.9.5 / 13.9.6 carry the built numbers (D.7) |
| G12 | Classic one-keyboard layout | Left Shift held while P2 uses the numpad with NumLock on makes Windows send synthetic Shift releases / presses: P1 strikes by himself | **orchestrator**: P1's strike is **Left Ctrl**; Shift is no alias (no test can prove the fake events filtered: Godot reports them like real ones); all else unchanged; NumLock off needs no aliases (D.11, E.9, G 13.9.1) |
| G13 | Co-op camera and leash | an off-screen death of a partner above / below the view; an anchor beyond the 12.2 curve; a hero on a high ledge out of the view; the search's run time | **accepted** (orchestrator): in a co-op party a hero above or below the camera rows is leashed, not downed (the pit rule still applies); an anchor beyond 131 px is followed at 16 px/tick; the view keeps every standing hero whole while their feet are at most 9 rows apart (world-A); `test_coop_gates` is a slow module run by name (P-C.12, P-C.13, LD 15.7.6 / 15.7.7, PLAN V7) |
| G14 | Totem Ring | DA moved the springs, the floor spots, the big spot, the second pot and the spawns | **accepted** (orchestrator): the as-built sketch in E.5; arenas are 20 x 12 |
| G15 | Versus stomp without a landing | a hero standing on a one-way bridge stomped (and robbed) a rival whose pogo poked his head 2 px through it (DA); the referee mirrors the 1.0 enemy bounce (stomp flag, `yvel >= 0`) | **decided: a stomp is a landing** - a hero who had ground or a platform under his feet on the previous tick does not stomp. Asked of world-B (`wf8_lead-designer_to_world-B.txt`); until it lands, arena designers keep pogo spots out from under one-way tiers near spawns (E.2, P-C.14, LD 15.8) |
| G16 | Book II warp | `w5_l2` has both `bonus = bonus_d` and `next = w5_l2b` (core-A) | **confirmed as built**: the 1.0 rule "a warp ends the source stop with a tally, then the level after it" applies as written - warping from 5-2 skips Tusker's Wallow, as warping from 3a skipped 3b in the original. Tusker and painting 2 stay a replay of 5-2 away (G 13.1) |
| G17 | Versus thrown specials in walls | a spear stopping in a `#` wall lay inside the rock (player-B) | **accepted and extended**: a stopped special lies on the top of the cell it entered when the cell above is open, else in the open cell in front of the wall's face, from where it drops (never inside a wall). The axe and the swirling axe follow the same rule (asked of player-A) (E.2, P-C.14) |
| G18 | Crates | what one crate holds and how lanes share the period (objects-B) | **accepted**: one crate holds all of food, a special, a cutlery piece and sometimes a skull or a grenade (the referee's per-mode table); one crate per period over all lanes, on a free lane (`Sim.rng`); a lane holds one crate; one hit opens it (E.3, G 13.10.3) |
| G19 | Coconut | 13.10.6's bounce never came to rest (each bounce returned about 12 v16 faster); multi-tick front boxes shot a ball 2-3 times (objects-B) | **accepted**: gravity also runs on the bounce tick (the bounces die within six); front frames only shoot; boxes in one tick add up; one shot per swing per hero; the striker is not knocked down by his own shot for 8 ticks; heads of immune heroes still bounce it; a slow ball passes through bodies (E.4, G 13.10.6) |
| G20 | Mesa Rodeo | release clock and the rodeo were open (objects-B) | **accepted**: released at every multiple of 728 round ticks while penned; the rider stomped off (no stun) leaves Chomper out for the stomper; only a hit sends him to his pen; in an arena a hero in his 30 immune ticks may sit down (the versus stun threshold) (E.5, P-C.9) |
| G21 | World-A additions | the lee, the tribe camera's standing window, one fly swarm per hero, the egg scouts' star, current streaks, lightning targeting, food rain, live `wind_loop`, lights in the dark | **accepted** as written in P-C.6 / P-C.13 and G 13.3 / 13.9.2; designers use them per A.6 |
| G22 | Slice designers' variants | DB1: R18 the other way round (the ledge at Expert height, a `beginner`-flagged static block in the dip), the two-corridor leapfrog, no drums in 1-1; D5: the spear and painting on a mesa spire instead of a palisade, three co-op gates in 5-1, the long-climb Rollers as one bond, four solo records left out of the co-op file | **accepted** (LD 15.7.1, 15.7.3); the search's bond-window cap for members far apart stays open for phase 3 (world-B) |
| G23 | Lee leapfrog | DESIGN named it (3-1b, 9-2) but no spec defined it | built by world-A as P-C.6 "Lee" (64 px downwind, 16 px vertical *(tune)*); a gust gap of a co-op file keeps a crouching spot within 64 px downwind of its far edge |
| G24 | Art as built | the Mimic, Mangrove's arm, the sea snail's shell, the ruins backdrop, the Roc's crest, lightning (art-B) | **accepted** (A.5, F.1) |
| G25 | Versus corner panels | the Ninja portrait exists only at 2x (76 px), the panels are one row tall (art-A) | **accepted**: 28 px heads in the corners, the 2x portrait in the lobby, join panel and results (E.9) |
| G26 | Audio batch 2 | Haunted House's tail, Typhoon's end, the nene loop regions, the sudden-death loop, the lightning and gong rows, the music budget (audio) | **accepted** (F.2); the music context of every Book II stage is binding in LD 15.2 |
| G27 | Sign texts | boards wrap; long texts covered heroes and the HUD (objects-A, the G1 verifier) | at most 3 board lines (`SignBoard.MAX_LINES`, about 60 characters); one idea per sign (LD 15.6) |
| G28 | Boost-ledge height (G2 integration) | world-B's search v2 rides an idle partner (98 px) and the corner catch lands feet entering a ledge's top cell from the side: a 7-row ledge is solo-solvable; w1_l1_coop 'hop' (6 rows over the step at the tablet) and w5_l1_coop 'hop' fell to it; D5 / world-B asked for the rule | **8 rows over every floor within reach, both difficulties**; the way back is a rolled vine whose coil is 11+ cells from the gate's `far` cell (the validator counts a coil as a booster); a flower pot serves only a ledge with no raised root within reach. w5_l1_coop (D5) and w1_l1_coop (rebuilt at G2: the ledge face where the old step stood, the routes re-recorded through the gate) follow it; the search refuses both on both difficulties (D.4, D.8, LD 15.5 / 15.7.6 / 15.7.8) |
| G29 | Raft boarding (G2 integration) | a hero falling onto a raft faster than about 4 px/tick died in the liquid cell before the ride test caught him (D6) | **fixed**: `Raft.catch_sinking` - the deck catches a hero whose own move carried his feet past it; banks one row over the liquid stay a design choice, not a workaround (P-C.7) |
| G30 | Boss drops in a wall (G2 integration) | Old Mangrove's drops came out of its face, inside the bark wall: a fire-starter without sideways speed stayed there (D6) | **fixed**: `BossBase._drop_origin()`; Old Mangrove drops on the floor in front of its trunk; `w6_l2b` uses the plain default drop (B.2) |
| G31 | Arenas as built (G2 integration, DA) | Totem Ring's big spot gave spawn 1 58 % of Grub Stack rounds; Cinder Pit with lava ends; Echo Hollow had no sketch; Coconut Cove's rims | **accepted as built**: Totem Ring big spot in the totem's base (9, 9), modes grub_stack / last_caveman / hot_rock; Cinder Pit walls at both ends, one crate lane; Echo Hollow wrap tb, tiers at row 4 or lower; Coconut Cove Clubball only, straight rims, `zones/goal` (now a scene). Not built yet (phase 3, world-B): Echo Hollow's darkness pulse, regrowing `$` walls and dangler springboard; the Cove's goal mouths as ring-outs in other modes; Clubball sides rotating per round (E.5, LD 15.8) |
| G32 | Rising scroll and jumps (G2 integration, D6) | in a `scroll = rising` level the camera chases a jump's apex and never sinks: a jump that does not land higher kills | **design rule** (no engine change at G2): in a rising climb every jump lands higher - one-way ledges 3 rows apart in one jump column (6-2b) (LD 15.5; the camera follow-up is [G42], built in phase 3, which retires this rule) |
| G33 | The idle partner (orchestrator, phase 3) | G1's "active" rule (input since the last hatch) left the boss rules, plates, bait and the Totem Ride counting a partner nobody plays: one active hero beat the co-op Twin Idols with his idle partner parked on the far half (16 -> 0 hit points, g2_verify); the co-op Tusker could be struck on the rump the same way; an idle carrier gave a lone player a 98 px step (the 5-row Totem ledge fell) | **orchestrator**: a co-op hero is **idle** while his own slot held no input flag for 243 ticks (10 s), or none since he entered the level (level start, join, restart: no 10-s grace); reset only by his own input (an egg's nudge counts), never by a hatch, carry, bump, launch, respawn, checkpoint or team wipe; drawn dozing (Zzz) once 243 quiet ticks passed. An idle hero counts for **no co-op rule**: plate and pulley weight (a mount weighs 2 only with an active driver), see-saw launches, x2 tablet lights, count-ins, trait "nearer hero" rules (shell, keeper bait, lone, Mimic, Shaman), braces, the lee, twin windows, boss position rules, and - lead designer - **no duo move**: no Shoulder Hop and no Totem Ride on or by him (his head is passed through; a ride ends when carrier or rider becomes idle). The team exit counts an idle hero on the view as present (as an egg); checkpoints stay physical. Plain enemy targeting may pick him. Shared query: `PlayerBase.is_idle()` / `counts_for_coop()` (party). The searches place the idle partner anywhere he could be hatched (D.1, D.3, D.4, D.5, D.6, D.8, B.0, P-C.10, P-C.12, G 13.9, LD 15.7) **Built in phase 3**: party (`PlayerBase.is_idle` / `counts_for_coop`, `LevelBase.nearest_coop_hero`, the Zzz, no duo move on or by an idle hero), objects-A (plates, pulleys, see-saw, tablet, drums, boulder, Chomper), enemies-B / enemies-C (every boss rule), world-B (the search's idle partner). **Open**: enemies-A's `coop_traits.gd` (the shell's and keepers' facing, `lone`, the bond / split count-ins) still reads every hatched hero - no enemies-A owner in phase 3; the gate search parks the idle partner by trait enemies, so a gate it refuses stays refused once the fix lands. |
| G34 | Boss co-op forms by actions (orchestrator + lead designer) | position rules ("on its half", "the nearer hero", "a hero other than the striker") are satisfiable by a parked body; a twin capped at `solo_min - 4` left Old Mangrove 6 ticks for a pair although one hero can never twin it (enemies-B #1 / #2) | **decided**: wherever the design allows, two heroes' own actions satisfy the co-op rule: Mangrove twin and Inkjaw flinches by two different heroes (as built), the Twin Idols' twin struck by the OTHER hero (new), the Roc's tail strike by a hero other than the pilot (as built), the Brute's last hitter, the Brace Wall; position rules count only active heroes (Tusker, Mangrove pin and knuckle, Idols' halves, Roc wing shield, Chieftains' hold-off, Brute's first target, Colossus plates). A slot-bound rule is **exempt from the solo_min cap**: Mangrove twin 24 B / 12 E, Inkjaw flinch 24 B / 16 E, Idols twin 24 B / 12 E. Every boss search adds an idle hatched partner (B.0, B.2-B.7, D.4, G 13.6, G 13.9.3, PLAN V3.d) Built in phase 3 by enemies-B and enemies-C (tests `test_enemies_<boss>.gd`: one hero's two hits never twin; the single-hero searches with an idle partner placed anywhere). |
| G35 | Boss weak points under the HUD (orchestrator, G2 report) | Old Mangrove's face was drawn behind the GRUBS letters and cut by the view's top in `w6_l2b` (g2_verify) | **orchestrator**: every rectangle a counted hit must touch lies wholly in the locked view, in every strikable pose, at least 24 px (logical; 48 art px) below the HUD band over its columns. The band is the fight HUD ui built in phase 3 (`Hud.band_rects`: in co-op the letters give way and P2's panel moves up while a boss bar shows): the top row, 31 px deep on touch devices (27 on a computer), and the boss bar's columns (53 px left to 38 px right of the view's centre) down to 48 px - so a weak point's top is 55 px under the view's top, 72 px in the bar's columns (with the floor on the last row of an 11-row lock: at most 105 / 88 px over the floor). ui's clearance constant moves from 24 art to 24 logical px. Measured: Old Mangrove's face 112-141 px over the floor - at most 105 (`MANGROVE_FACE_RISE` <= 70); its hand resting on a row-4 ledge - the upper ledge goes to row 5 (ending at col 5), the lower stays at row 7; the Chieftains on a 6-tile altar in the bar's columns - the altar 3 tiles up. The Twin Idols' open jaws (65 px), Tusker, Inkjaw, the Roc (84 px over its nest) and the Brute are clear; the visor Colossus' co-op hall is checked like the Idols. Each boss test pins it with `Hud.weak_point_problem` (B.0, B.2, B.4, B.6, B.7, A.6, G 13.6, LD 15.6) |
| G36 | Bonded pairs (orchestrator, G2 report) | a bond whose members one thrown special hits in one throw measures `pair_solo_min` 0 (D6: bonded frog / Puffcap pairs on flat floors cannot be built; axes and spears pass walls and fly about 520 px) | **orchestrator**: never place such a pair - separate the members by height so that no throw line from any strike spot of one member crosses the other, or use another trait (`lone`, `daze`); a 0 from the search is a build error, not a short window; A.6's "bonded ... pairs" are suggestions under this rule (A.6, D.6, D.8, LD 15.7.5) Built in phase 3 by world-B: `CoopSearch.pair_solo_min` and the validator name such a bond or drum pair as an error. |
| G37 | Cut list (orchestrator, phase 3) | the schedule of phase 3 | **cut 2 applied**: the tablet table mode stays an experimental, hidden prototype (touch = one touch player + pads; P4.3 drops its device test); **cut 3 conditional**: Mesa Rodeo and Cloud Top are built only once Floe Rink, Tar Pulleys, Sky Picnic and Colossus Hall are done and their bot tests green (0, D.11, E.5, E.9, G 13.9.1, G 13.10.1, PLAN 7 / 9) |
| G38 | Tusker's arena and the co-op phase 3 (G2 report, enemies-B / D5) | B.1's 4-cell banks and 6-cell wallow kept the 76 px boar in the mud; the co-op phase-3 charge still sticks in the wallow (g2_verify) | **accepted as built**: banks 3 cells wide at cols 1-3 / 16-18, 3 rows up; a 4-cell wallow at cols 8-11. A co-op phase-3 charge across the wallow may still stick (rump open from behind only, facing the nearer active hero [G33]); at the walls only a Brace Wall stops it (B.1, G 13.6) |
| G39 | Boost ledges on Beginner (G2 report, D5) | G28 made boost ledges 8 rows on both difficulties, but GAMEPLAY 13.9.10, D.10 (5-1) and `PartyTuning.BOOST_LEDGE_TILES_BEGINNER` still said 7 | **confirmed**: 8 rows over every floor within reach on both difficulties; R18's Expert-only column is retired; the Beginner constant becomes 8 (core-A); the way back is a rolled vine (D.10, D.11, G 13.9.10, LD 15.7.3) |
| G40 | Confirmations of the G2 reports | snapper co-op bait-and-bite, the versus stomp, 6-1's hammer on a raft, Inkjaw's phase-3 slam reading, the bosses' telegraph lengths | **confirmed**: bait-and-bite stays dropped [G10] (co-op snappers keep the 1.0 rules; twin rattlers use `bond`); a versus stomp is a landing [G15], built and tested by world-B (`test_a_stomp_is_a_landing`); items do not ride rafts, so 6-1's hammer lies on a jetty beside the raft (A.6, objects-B #3); Inkjaw's phase-3 slam shakes and hurts nobody, the rafts overlap by 9 px; the telegraphs as pinned by the boss tests (D.6, A.6, LD 15.8) |
| G41 | The lee gap (G2 report) | the validator has no lee-gap check; a lee gate is proven only if the search runs the wind | **kept as a gate kind**: gust gaps of up to 3 cells whose gusts never pause, a crouching spot within 64 px downwind of each far edge; only an active croucher shelters (a crouch is input) [G33]; the search decides, the fallback is a Brace corridor (9-2) - and the fallback is used if world-B's search world does not run the level's wind; the validator warning stays optional (LD 15.5, LD 15.7.3) Built in phase 3 by world-B: the search world runs the level's `wind` / `wind_loop` (`SearchWind`), so a lee gate can be proven; the validator warns on a gust gap without a crouching spot. |
| G42 | The rising-scroll camera (G2 report, follows G32) | G32 made "every jump lands higher" a building rule because the view chases a jump's apex and never sinks; a jump in place on a climb ledge (to strike a bat) is then an unfair death | **engine change, built in phase 3 by world-A** (`LevelCamera.footing_mode`; `tests/test_world_book2.gd` `test_the_rising_view_follows_the_footing_not_a_jump`): in a `scroll = rising` level the view rises for a hero's footing (his feet on the last tick he had ground, a platform, a carrier or a vine under them), never for a jump's apex; it still never moves down and rises at least with the band. G32's building rule is retired: a jump in place on a climb ledge is fair; a climb never steps down more than 2 rows under the highest footing reached (P-C.8, LD 15.5). 6-2b's routes are re-recorded on it (D6) |
| G43 | Arenas as built and Colossus Hall (G2 report, DA) | E.5 still drew the G1 sketches; Colossus Hall's "crowned leader" does not exist outside Grub Stack | **written in**: E.5 draws Totem Ring, Cinder Pit, Echo Hollow and Coconut Cove as built [G31] and LD 15.8 carries DA's lessons; Colossus Hall plays Grub Stack (the crowned leader) and Last Caveman Standing (the hero with the most hearts; a tie: no spit), no Hot Rock or Clubball; the statue is a neutral picture that takes no hits (E.5, LD 15.8) |
| G44 | Book I co-op as built (DB3, phase 3) | 3-2's two gates, 4-2's "spike column" and the Way Home lookout needed a concrete form | **accepted**: 3-2 puts both gates at the leaper lake (the line drive over 9 cells, 8 on Beginner through a `beginner` floe column on the near lip; drums on both banks freeze the floe bridge for the batter), each with its own tablet and `far`; the Feast Land C warp and painting 26 share the 8-row crystal cache; 4-2's drum bond raises a portcullis for good; the Way Home lookout is a gallery 8 rows over the road with a latch plate 9+ cells from the door, also the x2 secret of painting 29 (D.9) |
| G45 | Railed raft at the beach (D9b, phase 3) | with `rails` a rider is fenced to the raft for good, so "the home beach is the exit" of `ending_b` could not be built; a railed rider fell into the water at the bow (the halved-width ride overlap) | **decided**: when a railed raft is stopped by a bank, its fence opens on that side over the bank's floor and the riders walk off (their floor contact unrails them); the ride test carries a railed rider over the whole fenced width - objects-B (A.6, P-C.7) |
| G46 | The Storm Roc's phase-3 cruise (enemies-C, phase 3) | the glider dive's target, the Roc's back, cruised at the nest's centre with its feet 40 px over the nest top: its top 44 px under the view's top - inside the boss bar's columns and 11 px short of the HUD row's clearance; a lower cruise over the nest would run into heroes standing on it | **decided**: in phase 3 the Roc cruises over one runway half only (out of the boss bar's columns and off the nest by a cell), its feet about 61 px over the floor (29 over the nest top), so its back's top is 55 px under the view's top; heroes on the floor keep 26 px under it; it swoops and climbs out as before; the co-op tumble over the nest is clear already (B.5, G 13.6) Built in phase 3 by enemies-C (`roc.gd`: the halves alternate, the right one first; `tests/test_enemies_roc.gd` pins the back with `Hud.weak_point_problem`). |
| G47 | The daze trait is slot-bound (integration's coop_gates run, phase 3) | the search measured that one hero strikes a Raptor he dazed himself 8 ticks after his bounce in a 4-row hall (`w2_l1_coop` 'den'), so the daze would have to shrink to 4 ticks - unplayable for a pair and fragile wherever Raptors keep a hall | **decided** (the orchestrator's actions principle, G34): a dazed `daze` enemy can be hurt only by a hero of another slot than the one whose head bounce dazed it - the bouncer's hits glance; so a lone player (an idle partner never strikes) can never kill it, and the daze keeps 14 B / 12 E, not capped by the solo minimum; `window=` on daze records is no longer needed. enemies-A builds it (`coop_traits.gd`), world-B's search and integration's window check treat the daze as slot-bound (D.6, D.8, D.11, G 13.9.5, LD 15.4) |
| G48 | Book I co-op as built (DB1, phase 3) | 2-1's Raptor keepers could not be a gate with a daze capped at the measured solo minimum (8 - 4 = 4 ticks); 1-2's tree house, pulley, warp cage, leapers and treetop cache needed concrete forms | **accepted**: 2-1's 'den' keeps two Shellback turtles as keepers (Raptors may return there once the slot-bound daze of G47 is built); 1-2's tree house is the 5-row Totem ledge (a gate only with G33's active carrier; a rolled vine of 5 is the carrier's way up), the trunk-room pulley a counterweight hop (A on the counterweight pan, B hops while the lift rises, a ledge 11 rows over the shaft floor, a rolled vine back for A), the Feast Land A warp in a cage whose door the drum bond 'nest' raises (drums 15 columns and 6 rows apart), the bonded leapers two dragon leapers in two pits one row under the deck top, the treetop cache 8 rows up for a charged lob (a 7-row lob ledge falls to one player since G28); 2-1's x2 secret the Deep Pantry behind 8 cells of black water. Feast Lands A / B: the giant-roast twin rule (G 13.9.8) was built in phase 3 by objects-A (party); `bonus_a_coop`'s routes are re-recorded with twin strikes (DB1) (D.9) |
| G49 | Boss objects are no gates (DB3, phase 3) | the validator counts the visor Colossus's chain plates (B.7) as a co-op mechanism that needs an x2 tablet and warns that they drive no column, so `w4_l2b_coop` cannot validate; a dummy tablet would be a "gate" the search refuses that is no gate | **decided**: in a co-op file the `objects/plate` records inside the `zones/arena` of a `bosses/colossus` record that drive no column are the boss's chains (the left-most and the right-most are the two the boss reads), not a gate mechanism: no x2 tablet, no "drives no column" warning; fewer than two of them is a validator error (the co-op form would be lost without a word). A boss stage's co-op form stands in for its gate (D.8 #1). world-B builds the validator rule (LD 15.7.4) |
| G50 | Human-only arenas: the switch of cut 4 (DA, phase 3) | PLAN cut 4 ("an arena whose bot graph fails ships human-only") had no switch: `test_versus_bots` plays every `levels/arena_*.lvl` in every mode of its `modes`, so a failing arena could only stay out of `levels/` | **decided**: arena meta `bots = <mode list>` or `none` (default: every mode of `modes`) names the modes in which bots play that arena. The validator accepts a subset of `modes` (or `none`); `test_versus_bots` plays only those (a skip line for the others); the versus setup offers the arena in another mode only while every seat is human (no CPU seat; Party Mix and a bot-filled match skip it); the G3 table lists a mode left out as "human-only (cut 4)", neither green nor red. Until the switch is built (world-B validator, core-B test, ui-A / core-A setup), an arena whose bot set is not green stays out of `levels/` (DA) (E.5, LD 15.2, LD 15.8) |
| G51 | Floe Rink's floes and the bots (DA, phase 3) | core-B's baker keeps one link state per rider mover, so after a see-saw's first flip a bot on it finds no link and stands there (idle 250-2300 ticks on every Floe Rink layout with both plank ends safe); DA's bot-safe stopgap lays the whole plank over the icy water, so a hero landing on the high end is tipped into it within 2 ticks | **decided**: no arena part kills the hero who uses it as meant without a 10-tick telegraph (LD 15.8): an arena see-saw keeps both ends over standable ground, never a liquid cell. Until core-B bakes a rider mover's links for every state (or a bot stranded on a mover walks off it), Floe Rink ships without see-saws: two fixed floes where the planks were (any standable ice over the water, placed by DA), the alternating gusts towards the open sides as its signature (the Whiteout grows them); the fling floes of E.5 return when the bots ride them. A layout whose bot set is still red stays out of `levels/` (G50) (E.5, LD 15.8) |
| G52 | Inkjaw's fire-starter lost in the water (D7, phase 3) | the squid dies surfaced in a gap; `BossBase.defeat()` throws the fire-starter from over that gap's water, and a sunk key item returns to that same point and falls in again - the exit of 7-2b can never open | **decided**: a boss's key item is never lost - Inkjaw throws it from over the island nearest to where it died (its `_drop_origin()`, as Old Mangrove's [G30]), and a key item that sinks anywhere comes back on standable ground (enemies-B). D7 may close the grotto's outer 1-cell water strips (cols 1 and 18 become island ground: islands 1-5 and 14-18); the gaps 6-7 / 12-13, the middle island and phase 3 stay as G 13.6 draws them (B.0, G 13.6) |
| G53 | The idle doorstop (world-B's search, phase 3) | a plate door "never moves into a hatched hero (it waits)": a lone player hatches his idle partner with 4 px of his body over a hatch slab's column, presses the plate, and the risen slab cannot close while the body stands there - `w2_l1_coop` 'hatches' falls to one player on both difficulties (the search found it on Expert) | **decided** (G33's "counted by no co-op rule" extended to bodies): an idle hero **blocks no mover** - a plate door, column, slab or heave boulder that would wait for a hero does not wait for an idle one; it moves as if he were not there and pushes him out of the cells it fills, unharmed, sideways to the nearer free side (up onto its top when neither is free). Active heroes keep the 1.0 wait. Single-player is untouched (nobody is idle there). objects-A builds it (`RisingColumn`, `HeavyBoulder`); no content change needed (P-C.10, G 13.9.7, LD 15.7.9) |

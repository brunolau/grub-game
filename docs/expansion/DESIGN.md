# DESIGN.md - Club & Grub 2.0 "The Far Shore": the binding expansion design

Status: **binding design** for the 2.0 expansion. Author: lead designer (expansion workflow), 2026-10-06; revised
2026-10-07 after gate G1 (phases 0-1 built, G1 passed on every automated criterion, phase 2 under way). Every number
marked *(tune)* is a starting value for playtests; every other number is derived from `docs/spec/PHYSICS.md`,
`docs/LEVEL_DESIGN.md` 12 or the research documents and is binding until a playtest changes it through this document.
What the builders resolved in code and the lead designer decided after G1 is listed in "Appendix: G1 and phase-2
resolutions" (markers **[Gn]**); the phase-3 targets of worlds 6-9, Feast Land E and the Long Raft Home are A.6.
Revised again 2026-10-08 at the start of phase 3: the orchestrator's phase-3 decisions (the idle partner, boss co-op
forms by actions, boss weak points clear of the HUD, bonded-pair placement, cut 2) and the lead designer's decisions
on the G2 reports are G33-G43 of the same appendix. Revised a fourth time 2026-10-08 after the failed gate G3: the
orchestrator's decisions of the follow-up round (heavy keepers hurt only in a braced daze and one hit per strike in
co-op files, the idle warning and "crouch" plate signs, refusals that name their evidence, cut 3 applied, co-op boss
fights of 45-90 s) and the lead designer's painting ladder, review of the designers' deviations and rulings on the
builders' reports are G57-G69. Revised a fifth time 2026-10-09 for phase 4 (QA and release 2.0.0): gate G3 is passed
(G70-G83 are the records of the three rounds that got it there); the orchestrator's phase-4 rulings Q1-Q7 are
G84-G90 - the ward shown on the enemy, no dead end beside an idle partner, the ward's short grace, version 2.0.0 for
Windows, nothing public from an agent, the human checks; D.12 lists every *(tune)* value as 2.0 ships it [G91]; and
the main body of section D now says what the game does since G71-G83 (the ward, slot-bound bonds, the launch hold,
the coil and the shield, the stages as built) where it still said what was planned. What only people can check -
pair playtests, the music, keyboards, pads, an Android device - is `docs/expansion/HUMAN_CHECKS.md` [G90].

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
| Versus | Same device, **2-4 players**, bots fill empty slots. Flagship **Grub Stack**: food you grab stacks on your head, hits knock it off, stomps steal it, a cookpot banks it. Launch modes: Grub Stack, **Last Caveman Standing**, **Hot Rock**, **Clubball**. **8 single-screen arenas** (cut 3 applied: Mesa Rodeo and Cloud Top are not in 2.0 [G60]). Deterministic bots (Rookie / Hunter / Chief). |
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
vocabulary of the co-op enemies, the Tar Pulleys and Mesa Rodeo arenas (Mesa Rodeo is cut from 2.0 [G60]), Chomper's two seats, the drift hash of co-op
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
  ceiling with three `enemies/leech` that drop on riders: only a gunner's strikes clear them. **As built** (D6) [G62]:
  the fallback 'root' - Old Root 8 rows over the floor in front of it, a Shoulder Hop up and a rolled vine back (a pot
  on a 2-row stump would be a raised root within reach [G28]); a lone rider crossed the thorn bed in 24 ticks and the
  Leeches only drain bones, so the two seats are no gate - Chomper keeps them after the root. Traits: Tar Splitters
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
  the gunner swats them. **As built** (D7) [G62], rebuilt at G3b [G70]: 'stack' - the shoulder 7 rows over the rock's 3-row step
  (the rock itself 2 rows: a lone hero's hop jump caught the shoulder from the 4-row step of the solo rock); the
  fallback 'dune' - a dune twelve rows high (8 over its upper coral shelf; ten at G3) with two corridors,
  plate A before it holding the lower corridor's door for the partner, plate B beyond it the upper corridor's door
  for the holder, each 8+ cells from its door, both on one view; the urchin beds and the pen are not in the co-op copy
  (a mount crosses a bed with one rider, so the two seats were no gate). Traits: bonded fish pairs from two pools,
  Snatcher gulls with a `perch` by the water, bonded sea-snail pairs (as built: Shellback tortoises and `lone` gulls -
  one throw line crosses both fish pools [G36]).
- **7-2 Sea Caves** (difficulty 6; letter S; painting 7). `dark = true` in the deep half, glow anemones and coral
  (`coast/props/glow_*`) on the way. (1) Driftwood drop floes (`objects/drop_platform`, driftwood skin) over dark water
  - sign `SIGN_W7_FLOE` "Driftwood sinks. Keep moving."; (2) octopus lurkers on the ceilings (`lurker skin=octopus_b`)
  over the floe lines - never over the only floe of a crossing; (3) octopus on kelp threads (`dangler skin=octopus`);
  (4) bark boards on drift-logs for spear steps (shortcuts and the letter, never the main path). Letter S up two
  spear steps or a geyser; **painting 7** at the top of a kelp vine in a side shaft. Enemies 18 / +6: octopi, jelly
  flyers (`flyer skin=jelly`), sea snails, cave bats; Expert adds lurkers and jellies. **Co-op**: (a) **"seagate"**
  leapfrog plate doors - plate `pa` holds a sea gate (`rise_while=pa`, 8+ tiles away) while the partner rides the floe
  line through it; beyond, plate `pb` holds the second corridor's door for the holder (two corridors). **As built**
  (D7) [G62]: the two corridors are a lower and an upper tunnel through a sea wall on the drift-log ledge (the upper one
  up two driftwood shelves), both doors on one view, each plate 8+ cells from its door - solid ground where the
  holder waits, since a driftwood floe sinks under whoever waits on it; the floe lines lie before and after the wall;
  (b) **"dark gap"** Batter Up line drive over 8 / 9 cells of dark water (as built: a latch plate on the far shore
  raises a stepping stone for the batter). Traits: Snatcher gulls over a pit (`grab`, perch at the
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
  cloud stacks; as built (D9a) `range=3`, both lifts flush with the cloud shelf and a co-op one-way cloud ledge 3 rows
  over the risen lift (6 over the shelf), from which the rider reaches the slate block and unrolls the vine: a
  range-6 pulley parts rider and counterweight by 12 rows, and the view (anchored on the standing counterweight)
  loses the rider's lift, which then carries nobody (LD 15.7.3). The co-op drop-cloud stair has a twin cloud beside
  every step (the two climb side by side). Traits: `lone` harriers, bonded harrier pairs, a Snatcher bat. Spears in
  pairs.
- **9-1b Thunderhead Glide** (difficulty 8; painting 13). The glider on a runway at the start (24 ticks at speed to
  take off); lightning (`zones/lightning`, period 66) over the crossing, never two bolts on the only safe cell in a row;
  dive-attack harriers for the 1 000 / 5 000 / 10 000 ladder; sign `SIGN_W9_LIGHTNING` "A dark cloud marks where
  lightning strikes." **Painting 13** on a high cloud only a glider on lift reaches. Enemies 14. Checkpoint 2 on a
  landing cloud with a second glider. **Co-op**: (a) **"stormwall"** keeper door - a cloud column whose keepers are a
  bonded harrier pair circling in opposite directions 10+ cells apart, each reachable by a glider dive (two gliders
  on the runway). As built (D9a): the keepers perch (range 0) 14 columns apart, 3 rows over the last landing cloud,
  struck with clubs from the cloud (no standing spot beside them, so no throw line hits both, G36; the bond window
  12 E against a solo minimum of 46). A sub-stage, so its one gate is enough (D.8 #1, as 3-1b). **Found open in the
  follow-up round** [G66]: a woken Harrier follows its target, so one hero led the first keeper to the second's
  perch and clubbed both 8 ticks apart (the 46 was the walk between perches that stayed put) - a keeper Harrier now
  never takes off.
- **9-2 The Roc's Spire** (difficulty 9; painting 14; the world's feast kit). The exam: alternating gusts (`wind` with
  negative values, `wind_loop`), a crouching spot before every gap (sign `SIGN_W9_GUST` "Crouch to stand firm in the
  wind."); crumbling drop clouds; tar pockets (`:`); Guards and Rollers; a checkpoint before every section (five).
  **Painting 14** in the big spot past the last gust gap, off the path on a cloud above it. Enemies 24. **Co-op**: (a)
  ~~"lee" lee leapfrog [G21]~~ - retired as a gate [G55] (the lee helps only the second hero; the gusts and a lee sign
  stay, and the Brace corridor of (c) is the third gate); (b) **"drive"**
  Batter Up line drive over the final gap (8 / 9 cells); (c) a Brace corridor: a Bull Rex on a cloud bridge in a 4-row
  hall. Traits: Bull Rex, `shell` Guards, bonded Roller pairs on two slopes.
- **9-2b Storm Nest** (difficulty 9; painting 15; boss B.5). An approach of 20-30 cells, **painting 15** behind `$`, a
  checkpoint, the arena of GAMEPLAY 13.6 (nest one-way at cols 6-13 row 8, floor row 10 with a 4-cell runway each
  side, two drop clouds at row 5; the `bosses/roc` record standing on the nest; **place no glider** - the phase-3
  gliders appear on the nest by themselves, one per hero). **Co-op**: Snatch rescue and Pilot and Spotter (B.5).
- **9-3 Chieftains' Pyre** (difficulty 10; painting 16; final boss B.6). A short climb (about 25 rows above the
  arena) past the Tar Tribe camp (`sky/props/tribe_*`, `tent`, `pyre`): tribesmen (`charger skin=rival_tar`) and one Guard;
  **painting 16** in the big spot of the chieftains' tent; a checkpoint; then the arena of GAMEPLAY 13.6 (the Great
  Roast on an altar 3 tiles up at the centre, one-way; no see-saw and no plates (as built by D9b: plates are refused
  in a solo file and a see-saw would throw a body into the crown); ledges 3 rows up and nothing standable higher, so a chieftain is never drawn under the boss bar [G35]; the floor open to both side
  walls, where the Roc perches are; the arena zone's rect includes the side walls). The
  chieftains run on hero physics over a bot graph core-B bakes for `w9_l3` / `w9_l3_coop`, so every ledge, the pyre
  and the altar must be reachable by a hero's jump; Gorm's record on the floor, Gulla's on the pyre (enemies-C's
  `wf8_enemies-C_to_D9.txt`). The trophy leads to `ending_b`. **Co-op**: the boss form only (both chieftains, the 66-tick egg race).
- **The Long Raft Home** (`ending_b`, difficulty 2; painting 19; no failure state). One `objects/raft rails width=4
  skin=log` on a current (`speed=1`) from the start to the home beach: the credits ride on floating signs at reading
  speed (paddling halves the trip); `zones/food_rain skin=food` stretches from the Roc's broken hoard; the five islands
  pass as props on sand bars (`props/coast/isle_{mesa,mangrove,stacks,idols,spire}`, back props on the surface row); no enemy, no cell at the
  raft's surface row before the beach, no vine within reach of the raft route (a hero who grabs one leaves the rails). **Painting 19** in a big spot in the underside of a rock arch 3 rows over the
  raft path, over a calm pool where the current rests and the raft stands still (a high strike from the raft; a
  sign says to paddle on when ready; missing it fails nothing - D9b as built). The beach is the exit: the docked
  raft's rails open towards it and the riders walk off [G45] to the welcome totem one cell up the sand (col 173; a
  team exit in co-op; one raft for two - moved from its stand-in jetty plank in the G3 follow-up round, routes
  re-recorded; the last current ends one cell short of the bank so the raft comes to rest and its rails open). One route, `ending_b.inputs` (Expert).

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
  Book I's solo boss rooms are frozen and exempt. A boss after its lethal blow (the death leap or fall) has no weak
  point, and a leap that carries a weak point out of that zone and lands (the co-op Brute's very high jump) is a pose
  in which it **cannot be struck**: hits on it glance and it is no weak point until the boss lands [G56]; a weak point
  that rests, attacks or can be struck out of the zone still breaks G35.
- **Co-op balance targets** [G61] (orchestrator; they hold until the human pair playtests of P4.5): every co-op fight
  lasts **45-90 s** (1 093-2 185 ticks) for a competent pair and costs **at most 6 hurts** on its Expert route.
  Measured on the recorded two-stream routes of the stage (a rehearsed pair, so the floor of a competent pair's time)
  from the boss bar's appearance (`Events.boss_started`) to the lethal blow (`Events.boss_defeated`), counting both
  heroes' hurts (`Events.hero_hurt`). A form outside the band is retuned in its **co-op form only** (the solo boss and
  its routes stay): pace first - idles, openings, rage cadence, how often the co-op rule can be met - within the rules
  above (telegraphs >= 10 ticks, no stun-lock, the co-op rule and its slot-bound windows); hp above x1.25 only with
  the lead designer's consent in the request file; then the co-op routes are re-recorded and the boss test pins the
  route's fight length and hurts (the route headers' `fight_ticks:1093..2185` and, on Expert, `max_hurts:6`).
  Baseline of the G3 routes and the forms as retuned in the follow-up round (bosses, wf10), both measured by the lead
  designer on the recorded routes (`build/lead_design/boss_probe.gd`; seconds at 24.28 ticks per second; hurts in the
  fight):

| Co-op form (stage) | G3 Beginner: fight, hurts | G3 Expert: fight, hurts | G3 verdict | wf10 as built: Beginner / Expert | Solo Expert (reference) |
|---|---|---|---|---|---|
| Brute (2-2b) | 141 ticks (6 s), 0 | 241 (10 s), 0 | far too short: longer | 1 207 (50 s), 0 / 2 005 (83 s), 0 | - (Book I, frozen) |
| visor Colossus (4-2b) | - | 3 324 (137 s), 0 | too long: shorter | - / 1 735 (71 s), 0 | - (Book I, frozen) |
| Tusker (5-2b) | 1 142 (47 s), 0 | 1 159 (48 s), 0 | in the band | unchanged | 903 (37 s), 0 |
| Old Mangrove (6-2b) | 2 814 (116 s), 0 | 4 120 (170 s), 0 | too long: shorter | 1 486 (61 s), 3 / 1 714 (71 s), 2 (the Beginner route as party re-recorded it for the rising view of [G65]; 1 269 (52 s), 0 on the bosses' recording - the same co-op form) | 3 300 (136 s), 0 |
| Inkjaw (7-2b) | 2 755 (113 s), 9 | 4 195 (173 s), **18** | too long and too many hurts: easier, shorter | 1 281 (53 s), 1 / 1 298 (53 s), 5 | 1 459 (60 s), 1 |
| Twin Idols (8-2b) | - | 470 (19 s), 1 | too short: harder | - / 1 158 (48 s), 4 | 3 228 (133 s), 1 |
| Storm Roc (9-2b) | - | 1 512 (62 s), **7** | one hurt over: a little easier | - / 1 486 (61 s), 2 | 1 517 (62 s), 2 |
| Rival Chieftains (9-3) | - | 189 (8 s), 0 | far too short: longer | - / 1 432 (59 s), 4 | 592 (24 s), 5 (419 (17 s), 3 at G3: the solo route was re-recorded in the follow-up round - [G54]'s hero-side guard, a head under the crown is no step into rock, moved the hero-physics fight; the solo form of the boss is unchanged) |

  Every co-op form is inside the band since the follow-up round [G61]; what changed is written in each boss's co-op
  form below ("wf10"). The route headers pin the limit on the **whole stage** (`max_hurts:6` counts the approach too):
  the Expert stages cost 1 (Brute), 0 (Colossus), 0 (Tusker), 2 (Old Mangrove), 6 (Inkjaw: 5 in the fight and 1 in
  the approach), 5 (Twin Idols), 3 (Storm Roc) and 5 (Rival Chieftains) hurts. Re-measured unchanged after the power
  cut on the resumed tree (the same probe, `build/lead_design/boss_probe_resume.log`); later in that run only 6-2b's
  Beginner route moved (party's re-recording for [G65]: the fight 61 s and 3 hurts, inside the band - its climb is
  [G65]'s open item).
  **Re-measured in phase 4 on the release tree** (`build/lead_design/wf12/pair_probe.gd`, every two-stream route;
  the Levels phase of G3c had re-recorded 21 co-op routes): Brute 1 207 ticks (50 s), 0 hurts in the fight on
  Beginner / 2 005 (83 s), 0 on Expert; visor Colossus 1 735 (71 s), 0; Tusker 1 142 (47 s), 0 / 1 159 (48 s), 0;
  Old Mangrove 1 587 (65 s), 2 / 1 714 (71 s), 2; Inkjaw 1 281 (53 s), 1 / 1 281 (53 s), 1 (its Expert route was
  re-recorded in the Levels phase: 2 hurts in the whole stage, where it had sat on its limit of 6); Twin Idols
  1 158 (48 s), 4; Storm Roc 1 486 (61 s), 2; Rival Chieftains 1 432 (59 s), 4. All eight forms are inside the band
  on both difficulties, and on 6-2b's Beginner route no hero goes down in the climb any more ([G65]'s item). What a
  pair of people needs is `HUMAN_CHECKS.md` [G90].

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
  so the wrist must be struck from the far side. The co-op chamber (`w6_l2b_coop`, D6) makes the lower ledge's last
  two cells **rotten bark** (hatch cells `_`, marked by glowcaps): nothing reaches the stuck fist from the ledge in
  its 20 ticks, so the striker waits there, crouches when it sticks and clubs the wrist side on the way down while
  his partner baits from the other side. The solo chamber keeps a whole ledge. **wf10** [G61]: co-op stage hits
  3 twins + 2 fist hits (Beginner) / 4 + 3 (Expert), down from R8's 5 + 3 / 7 + 6; in stage 1 the hand and the fist
  keep time - the hand's ledge shake waits until the fist has rested 44 ticks, and a resting fist bursts again only
  after the hand has come and gone, so every hand cycle is a twin chance announced by the fist coming to rest.

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
  **wf10** [G61]: while the lock holds (phases 1-2) the squid stays up 66 ticks (44 solo), and the co-op Expert form
  has 225 hp (the solo Expert's; R8's 280 cost a pair 18 hurts in 173 s); Beginner keeps 187.

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
  their targets. The open jaws stay 65 px under the view's top, clear of the HUD [G35]. **wf10** [G61] (harder: a pair
  beat them in 19 s): after a twin crack both jaws stay shut (hits glance) until the idols have spat again, and both
  rage after every 2nd twin crack (not every 4th) for 88 ticks, armoured, before their targets cross.

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
  24 ticks (slot-bound [G34]). Each hero has his own glider on the nest. As built the co-op gliders appear at the
  nest's middle (+-24 px): a spotter who crosses it (or stands under a glider) takes his glider and cannot strike
  until a hit throws it off; `w9_l2b_coop`'s sign (SIGN_W9_COOP_ROC) teaches "one glides, one, no glider,
  strikes". Open for P4.5 pair playtests: if pairs trip over it, the co-op gliders move to the nest's end of the
  pilot's runway half (enemies-C). **wf10** [G61]: in the co-op form a gust drops a third as many feathers (two heroes
  under it took 7 hurts, four of them feathers).

### B.6 The Rival Chieftains, Gorm and Gulla (`w9_l3` Chieftains' Pyre, final boss)

- **Art**: shipped `rival.png` (hero-sized, full move set: idle, walk, jump, fall, land, roll, crouch, attack, hurt,
  death) in two palette swaps - tar-black with bone war paint (Gorm), ochre with red (Gulla) - with bone headdresses
  composited from the anchor dino-skull items 57-58. Their revive egg = `egg_kid` roll frames in their palettes. Two
  boss bars (two rows of pips).
- **How they move**: **on hero physics, driven by the versus bot brain** (E.7). Each chieftain is a boss shell around
  the hero simulation fed every tick by a `HeroBot` input producer with its own seeded `SimRng`. They walk, jump,
  strike and bounce exactly as we do - readable and fair, and the bots pay twice. **Fallback** (PLAN cut list): a
  Brute-style state machine on the same sprite with the same phases.
- **Arena**: one screen around the pyre; the Great Roast on an altar 3 tiles up at the centre; ledges 3 rows up (no
  see-saw, no plates - D9b as built); nothing standable higher (a chieftain on a 6-tile altar stood under the boss
  bar [G35]); a crown of rock 6 rows over the floor stops jumping bodies, and a hero on a chieftain's head under it
  slides off rather than into the rock [G54].
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
  other than the smasher stands within 64 px of the mate (an idle body keeps nobody away [G33]). **wf10** [G61] (a pair
  knocked both out in 8 s): 5 pips each (x1.25); a counted hit on either sends **both reeling** 110 ticks (blows on
  them glance), so the pips fall one at a time; after a blow, stomp or batted ball of theirs lands the pair **crows**
  330 ticks, during which nothing of theirs hurts. The crow must be **seen** [G64]: while it runs each fighting
  chieftain carries a gloating speech bubble over his head - "HA!" in block letters, its tail 24 px over the head,
  just over the line of the "HUP!" telegraph so that it never covers one; never the anger mark - that dims on every
  other pair of ticks over the crow's last 22 ticks; an egg shows none. Drawing only (`Chieftain.CrowMark`).
- **Defeat**: they hand back the Great Roast (the trophy) -> `ending_b`.

### B.7 Co-op forms of the two shipped bosses (in `w2_l2b_coop` and `w4_l2b_coop` only)

- **The Brute** (hp 64 -> 80): targets whoever hit him last (before the first hit: the nearest active hero [G33]); his
  arm guard faces his target and blocks throws and head strikes from that side, so **only the partner can reach the
  head** (a Totem Ride rider reaches it with a forward strike - a ride needs an active carrier, D.4). Below 50 % the **Grab**: after a 22-tick chest beat his hands open 8 ticks; a target within 30 px in front
  is squeezed (1 bone per 44 ticks); wriggling (alternate Left / Right) shortens the hold by 4 ticks per press; a
  partner's head hit frees him and staggers the Brute 19 ticks. The ground pound shakes both (crouch to stand firm).
  His very high jump (about 119 px, the 1.0 move) and his death leap leave the den's view: from take-off to landing
  his head takes no counted hit (a throw glances as off the arm guard), and after the lethal blow it takes none at
  all - in both poses it is no weak point [G56]. **wf10** [G61] (a pair beat him in 6-10 s with charged blows): every
  counted head hit takes one club hit's worth (25), charged or not, whatever the weapon (the co-op den's 187 / 312 hp
  are 8 / 13 club hits, x5/4 of the solo den's 150 / 250), and then he **covers his
  head** (every blow glances) and watches until his next chest beat (the jump's taunt or the Grab's beat - the 1.0
  telegraphs), when it uncovers; a partner's blow during a Grab still frees the held hero at once.
- **The Wall Colossus** (hp 24 -> 30): a stone **visor** covers the face; two stone plates at the hall's sides lift it
  while an active hero stands on the plate whose chain glows (the co-op copy of the hall keeps the face clear of the
  HUD [G35]). Rocks are spat at the plate holder, stalactites rattle over the
  thrower. Still thrown weapons only; the co-op checkpoint places **two** axes. Each rage (the 1st hit and every 4th)
  moves the live chain to the other plate: the roles swap. The fairness tests of `test_enemies_colossus.gd` run per
  hero. **wf10** [G61] (137 s at hp 30): the co-op form has hp x2/3 of the solo form (24 -> 16; below B.0's cap) and
  its idle pauses shorten only for its last two hits
  (the phase thresholds count hits taken, 14 and 22, as the x5/4 form reached them).
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
  In a co-op file the coil is struck **from its own level** only - by a hero whose feet are at most one row
  under the ledge it lies on: a hit from the floor below (the hop jump with a high strike reaches 123 px) or a
  thrown weapon from down there passes it [G67].

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
ground he last stood on), never a jump's apex, and never comes down [G42]; it keeps the highest footing 4.5 rows
under its top, so a climbing hero is never drawn behind the HUD band, and the drawn view looks up for a jumper's head
(drawing only) so that he never jumps out of the picture [G65]. Used in 6-2b and the Tar Pulleys / Cinder Pit sudden
deaths.

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
  throws both off. Two seats are a co-op set piece, **not a gate**: one rider crosses whatever the mount crosses
  (6-1 and 7-1 built the named fallbacks [G62]).
- Used in 6-1 and 7-1 (solo; the co-op 7-1 has no pen [G62]); the Mesa Rodeo arena is cut [G60]. Mount physics is an integer table (`MountTuning`) pinned by a reference
  test like `PHYSICS_REFERENCE.json`; mount speed is far under the 18 px/tick doze reach.

### C.9 Cave Paintings (the meta-goal)

- `items/painting index=0..29`: **30 fragments** - one in every Book II level (20; at the same index in its solo and
  co-op file, possibly in a different hiding place) and one behind an **x2 secret** in ten Book I co-op files (1-1,
  1-2, 2-1, 2-2, 3-1, 3-1b, 3-2, 4-1, 4-2, Way Home). 5 000 points each; they count for completion; saved per profile
  across modes (`Save.add_painting`), like code stones.
- Hiding places: behind `$` walls, up spear steps, at the top of vines, inside a big spot, behind x2 gates. Never on the
  main path.
- **Unlocks** (shown on the Far Shore map slab and in the Versus menu) [G60]: 5 = four loincloth patterns for P1-P4
  (checks, dots, tiger, pinstripes); 10 = four more (diamonds, waves, sash, trim); 15 = variants Big Bounce, Lights
  Out, Giant Rain; 20 = variant Spear Party; 25 = the golden loincloth palette; 30 = the mural that ends The Long Raft
  Home. No arena is locked (cut 3 applied: the 5 and 20 rewards were the Mesa Rodeo and Cloud Top arenas; nothing that
  is open from the start became locked). Options > Versus > "Unlock everything" exists for parties.

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
**An idle hero is no anchor** [G76]: the camera follows the heroes who **count** (hatched and not idle, D.3) - a
partner whose pad lies untouched holds no view. When the pair parts, the idle one is the hero the leash eggs, never
the one who plays; and the tribe is wiped when its **last counting hero** goes down (an egg beside an idle partner
would wait for ever).
**No dead end beside an idle partner** [G86]: the same holds when the partner puts the pad down AFTER the egg was
made - while a hero is an egg and no hatched hero counts, a clock runs, and after 73 ticks (3 s,
`PartyTuning.IDLE_WIPE_TICKS` *(tune)*) the tribe is wiped to its checkpoint, as when both are down. Any input of a
hatched hero clears the clock; the "Zzz" over the dozing hero is its warning.

### D.3 Lives and the Egg Hatch

- **Tribe lives**: one pool, starting like solo (the counter shows 2). A life is lost only on a **team wipe** (both
  heroes dead or in eggs at once; the last hero who counts going down beside an idle partner [G76]; an egg that has
  waited 73 ticks beside a hatched partner who is idle [G86]); then both respawn at the checkpoint (spread by slot)
  and enemies reset as today.
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
  checkpoint or a team wipe never does. **A held key is input on every tick it is held** [G58], so a partner who
  crouches on a plate (Down held) stays active however long he waits. From his **170th** quiet tick a **"Zzz soon"
  warning bubble** shows over him (3 s of warning, drawing only; as built one small "z" in a thought bubble that
  pulses, faster in its last second) [G58]; once 243 quiet ticks have passed he is drawn
  **dozing** ("Zzz" over his head) until his next input. Every co-op sign that teaches a hold plate says **"Crouch on
  a plate to hold it"** [G58]. An idle hero counts for **no co-op rule**: plates and pulleys do not weigh him, a see-saw
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
| **Brace Wall** | two active heroes crouching within 16 px of each other in a heavy's path are a wall: a `heavy` enemy (or Tusker's phase 3) stops dead and is dazed 44 ticks with its head open - the only time anyone can hurt a heavy [G57]; a lone croucher is trampled (hurt, thrown back). Reuses crouch-bracing (wind, earthquakes) | crouch / crouch and line up |
| **Egg Hatch** | D.3 | be carried / strike the egg |

All windows (twin drums, bonds, splits, twin hits) are **24 ticks on Beginner / 12 on Expert**; a level record caps
its own window with `window=<ticks>` [G2]. **Every window is slot-bound** [G72]: a bond, a keeper pair, a drum pair
and the halves of a split are met only by hits credited to two different heroes who both count - one hero's two
hits never meet one, however he times or throws them - and the boss rules that need **two different heroes' own
hits** (the twin boss hits, Inkjaw's flinches, the Roc's tail strike) were so from the start [G34]. The first
design's cap, "never longer than the measured solo minimum minus 4 ticks" (D.8 #4), was the proof before that rule
and is no proof obligation since: no gate rests on a window's length any more. So the lengths are a matter of feel
only. They are the values 2.0 ships with (D.12 [G91]): G1 passed on its automated criteria, no human pair playtest
took place during production [G3], and the pair checks of `HUMAN_CHECKS.md` [G90] may shorten or lengthen them.
Every window has an audible count-in (Junkala `Blip5` x3, 8 ticks apart, then "go"), which counts active heroes only;
nothing needs two inputs on the same tick. Every launch move moves at most 18 px/tick or calls
`notify_hero_teleported` (doze rule).

### D.5 Co-op objects

| Id | Rule | Built on |
|---|---|---|
| `objects/plate name= count=1\|2 mode=hold\|timed:<ticks>\|latch` | pressed while the weight on it (active heroes - an idle one weighs nothing [G33]; Chomper counts 2 while an active hero drives him, a riderless mount 0) >= `count`; drives columns by name. Anchored at its left cell; a column rises while **all** its plates are pressed, so a leapfrog uses two doors (two corridors), never one door opened from both sides [G9] | the step-on test |
| `objects/column` + `rise_while=<plate>[,...]` / `sink_while=` | the 1.0 rising column driven by plates: rises or sinks 1 tile per 4 ticks while held, returns when released. A plate stands **8+ tiles** from its door. A block whose next cell is solid is a **door** (the cells it leaves become air: a portcullis into a ceiling slot) [G9] | `objects/column` |
| `objects/column trigger=keepers:<name>` | the **keeper door**: rises when every enemy tagged `keeper=<name>` is dead [R10]. Keepers carry `shell`, `bond` or `daze` (or are a `heavy` [G57]) and stand in a hall **4 rows high** (the Guard and Shellback art is 54 px tall), so nobody can bounce over them [G4]; keepers meant for a pincer stand still (`speed=0`) [G5], a keeper Harrier holds its perch [G66]. **A closed door passes nobody** [G75]: a hero of a co-op party whom an enemy, a partner, a mover, a knock-back or a gust carries into a closed door or any wall is put back on the side he came from (a one-cell door is a door again) | `objects/column` |
| `objects/drum bond=<name>` | struck drums of one bond must all be hit within the window, then they open a column (`trigger=drums:<bond>`) or gate (`needs=<bond>`) [R10]. Slot-bound [G72]: the drums must be lit by two different heroes who both count - one hero's second strike or throw lights nothing | `HittableBase` |
| `objects/seesaw len=<cells>` | a hard landing (4+ tiles fall) on the high end launches whoever stands on the low end: launch = -(landing yvel + 32), +64 on a hard landing, cap -288 (about 10 tiles). Enemies on the low end are thrown off; an idle hero's landing flips it and launches nobody [G33] | `PlatformBase`, the hard-landing rule |
| `objects/boulder_heavy` | moves 1 tile per 6 ticks only while **two** heroes push the same side; fills a gap, plugs a vent, presses a plate | column-style tile mover |
| `objects/pulley a=<platform> b=<platform>` | two linked ride platforms; the heavier side (weight as plates: active heroes) sinks 2 px/tick, the other rises | `PlatformBase` |
| Drop gifts: rolled vine (C.3), `objects/flower_pot` | every boost ledge holds a gift only the upper hero can release: a rolled vine (its coil unrolls only for a hit from its own ledge's level [G67], by a hero who **stands** there: his feet and the ground he last stood on at most one row under the ledge - not the top of a jump from below [G81]), or a flower pot that becomes a spring (-224) where it lands when clubbed off the edge. **The pot spring reaches 6 rows from the floor it takes root on** [G6]; the way back from an 8-row boost ledge is a rolled vine [G28] (a pot's raised root within reach would be a step for a lone hero: a 98-105 px rise plus the corner catch) | vine, `objects/spring` |
| `objects/x2_tablet gate=<name>` | a stone tablet carved with two cavemen marks every co-op gate and every co-op secret (diegetic, not HUD). Every co-op gate has one; the validator pairs them. **Every tablet has a ward** [G73]: from its cell to its `far` cell and 12 cells beyond on both sides (`ward=<left>,<right>` overrides the margins), over all rows, no enemy gives a hero of a co-op party lift, rest, carry or a pogo - a stomp there counts against the enemy and leaves the hero falling, with a dust puff and a thud; that enemy does not hurt him during that fall, nor for 12 ticks after he lands (`PartyTuning.WARD_GRACE_TICKS` *(tune)*) - after them standing inside it costs a heart like any touch [G87]. **The enemy shows the ward** [G85]: an enemy whose feet column is in a ward wears the **ward mark** - chalk-white tribal stripes, drawn only, for a co-op party only - and a sign at the first ward of co-op 1-1 and 5-1 teaches it ("Marked beasts are no steps - use your partner's shoulders!"). As built nine tablets carry `ward=` (grown until the validator named no high ground at a ward's edge [G83]): 1-1 'hop' 34,12; 1-2 'treehouse' 12,62; 2-2 'seesaw' 45,12 and 'lift' 26,12; 4-1 'cliff' 12,29; 5-2 'sandgate' 12,21; 7-1 'stack' 38,12; 8-1 'stairs' 23,12; 9-1 'pulley' 12,17. **A spring is a launch** [G71]: a pad, cap or flower pot lifts a hero of a co-op party 105 px over its top and never more, and until he lands no jump, strike hop or pogo adds to any launch (the launch hold) | `objects/sign` skin |
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
on a team wipe; hit points unchanged (two heroes already deal double damage). **One hit per strike** [G57]: in a
co-op file one strike damages a given enemy at most once - a club swing for every tick its boxes stay out, a thrown
special for its whole flight, a ball for its flight (a head bounce never damaged anything) - so `hp` counts strikes
(the 1.0 test hit on every tick a box overlapped). The death rule is the 1.0 one - an enemy dies when its hp drops
**below** zero - so the club strikes it takes are `hp` / 25 rounded down, plus one: hp 10 or 20 one strike, hp 25
two, hp 60 three, a 100-hp keeper **five**; a crouch-charged strike counts as four [G63]. A later tick of a swing on
an enemy that swing already hurt is **used up** without damage: the hero's side stays the 1.0 side (the pogo off it,
the clank, one target per box per tick), and a living body shields what stands behind it until it is dead [G63].
Bosses keep their hit cooldown; solo files keep the 1.0 test.

**Two rules lie over every trait** (the causes closed by rule, D.8 #6). **The ward** [G73]: inside the ward of an
x2 tablet (D.5) no enemy - trait or none, keeper or not - gives a hero of a co-op party lift, rest, carry or a
pogo; his stomp still counts against it (a `daze` record is dazed, the bounce chain grows), it does not hurt him
during that fall nor for 12 ticks after he lands [G87], and while its feet column is in a ward it wears the ward
mark [G85]. Near a gate an enemy is something to fight, never something to climb. **Every window is slot-bound**
[G72]: a bond, a keeper pair, a drum pair and a split are met only by hits credited to two different heroes who
both count; a hit is its striker's, the thrower's for a thrown weapon, a mount's rider's, and a batted hero's own.
**What kills past a trait** [G92]: a `heavy` and the last member of a bond or split refuse every death that is no
accepted weapon hit (a feast's touch, a kill-all, a grenade, a mount's bite, a glider dive); as built a `shell` or
`daze` record does **not** - a feasting hero kills it by touch. Decided: every keeper and every `shell` and `daze`
record refuses them too; until that is built no feast piece may lie before a `shell` or `daze` keeper hall - the
first piece of 8-1 does today, over its 'hall'.

| Trait (role) | Rule | Why one hero cannot do it |
|---|---|---|
| `shell` (guard) | the shield faces the nearer **active** hero **every tick** [G33]; front hits glance (clank and spark). **Over a shield there is no behind** [G82]: it is hurt only by a hero who stands clear of its body on the side its shield does not face - the striker's place, or the thrower's for a thrown weapon, whichever way the weapon flies; a hero on its head or inside its body (in a ward he falls through it) is in front | one hero is always "in front", from every place he can reach (a parked idle partner is no bait); the partner hits the back |
| `bond` (bond) | linked records (`bond=<name>`): when one dies, the others must die within the window or the dead one regrows. Slot-bound [G72]: the deaths of a bond must be credited to two different heroes who both count - one hero's hit on the last living member glances, and no kill-all, grenade, feast, mount bite or glider dive kills it | one hero takes one member and never the last, however he times or throws (the first design placed the members out of one hero's reach in the window and off every single throw line [G36]; a throw at the far member and a strike on the near one as it lands beat that at three gates) |
| `daze` (daze-gate) | hops back out of reach when any hero within 48 px starts a strike and jumps low throws; a head bounce **dazes** it 12 ticks (Expert) / 14 (Beginner); only a dazed one can be hurt, and only by a hero **other than the one whose bounce dazed it** [G47] | the bouncer's own hits glance (in a 4-row hall one hero strikes 8 ticks after his own bounce, so a timing rule alone failed) |
| `heavy` (heavy) | stopped only by a **Brace Wall**, which dazes it 44 ticks with its head open; it can be **damaged only while so dazed** - every other hit glances: front, back, from above, thrown, a ball, a bounce [G57] - and it dies of nothing else meanwhile (no kill-all, grenade, feast or mount bite, glider dive [G63]) | needs two braced bodies (a jump over it to its back no longer helps: it charged under a jumping hero in a 4-row hall) |
| `lone` (pack) | keeps away while the active heroes are within 64 px of each other; otherwise targets the **straggler**, the active hero farther from the view centre [R9] | staying together is the defence |
| `grab` (grabber) | seizes a hero who touches it from below or that it dives on and reels / carries him toward a pit-side perch at 1 px/tick; the partner frees him with any hit on it. Never in a ward [G73]: there its touch is the plain hurt, and it lets go of a hero it carries on the tick he enters one (a carry by an enemy is a lift) | a grabbed hero cannot strike |
| `leech` (grabber) | lands on a hero's back and drains one bone per 44 ticks; only the partner can club it off (alone it falls off after 220 ticks) | a hero cannot hit his own back |
| `split` (bond on the fly) | a hit splits it into two halves that run apart; both must die within the window or they merge back. The swing that split it never hurts the record's own half again (it may still hit the spawned half once): that half takes a new strike [G63] | the halves run in opposite directions, one swing no longer clears both, and the two halves must fall to two different heroes [G72]: a lone hero never clears a Tar Splitter - he walks past it |

| Archetype | Co-op base behaviour | Traits used in layouts |
|---|---|---|
| 0 Dropper | drops land beside each hero in turn | `bond` (pairs, one by each hero), `split` (tar blobs) |
| 1 Decoration | none | - |
| 2 Dangler | unchanged; a club box over its thread cuts it: it falls off harmless and is gone without points until a team wipe (the Snatcher bat keeps its thread) | `grab` (Snatcher bat) |
| 3 Lurker | drops when any hero is in range, chases the nearest | `leech` |
| 4 Swinger | unchanged | `bond` (pairs swinging in opposition, rare) |
| 5 Stinger | dives at its target | `lone`, `grab` (Snatcher gull / pterodactyl) |
| 6 Harrier | loop relative to its target, retargets every loop; with `keeper=` it never takes off (a flying keeper holds its perch [G66]) | `bond` (pairs circling in opposite directions, one reachable only from a Totem Ride - never as a gate's members: a follower can be led [G66]), `lone` |
| 7 Dart | aims at the nearest hero at launch | none |
| 8 Hopper | hops at its target | `daze` (Raptor) |
| 9 Walker / Flyer | unchanged | `shell` (Shellback turtle), `bond` (flyer pairs on opposite ledges) |
| 10 Digger | rises beside each hero in turn | `lone` |
| 11 Leaper | leaps at its target | `bond` (twin leapers from two pits) |
| 12 Charger | runs at its target | `heavy` (Bull Rex), `lone` |
| Snapper | bites the nearest; the bite tests every hero (no stem rule: bait-and-bite is dropped [G10], confirmed at phase 3 [G40]) | `bond` (twin rattlers, 5-2) |
| 13 Roller | rolls at the nearest | as built `shell` (the long climb of 5-1 [G22]); the `bond` pairs on two slopes of the first design were not built (the slopes of 5-1 and 9-2 lie on one throw line [G36]) |
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
| `enemies/bull_rex` | Charger + `heavy` (hurt only while dazed by a Brace Wall [G57]) | shipped `rex_b` | ice lake, gorge, canyon |
| `enemies/tar_splitter` | Walker + `split` (the falling tar blobs are `enemies/dropper coop=split skin=slime`) | RPG `slime` (the two palettes are the two halves) | fen, Feast Land D (honey skin) |
| `enemies/shaman` | new patroller | anchor `characters/npc/dragon-man` (idle loop; motion in code) | keep, ruins |

The Book I Shellback (`skin=turtle|turtle_b`) is a Walker with the shell trait (walker speed and score, no Guard
clock); the bone-armoured sheet stays a Guard. The **Shaman** casts bone shields on every other enemy within 64 px
(4 tiles) on both axes - never on Shamans or bosses, and only in a co-op party - (they glance until he dies) and
flees along his platform from the nearer hero within 64 px; cornered (a wall, his platform's edge or his limit ahead)
he hops over that hero (45 px high, harmless during the hop). As built he flees at 48 v16 and a hero walks 80, so
one hero catches him from behind; two pin him sooner [G11]. A Shaman is never a gate on his own - his shielded
keepers carry a keeper hall.

**As built at G3** (the 35 co-op files): `enemies/shellback` keeps the halls of 3-1b ('hut') and 8-1 ('hall'), and
the shell trait rides on 25 walker turtles and tortoises, the flyers over 9-1b's crossings, three Rollers of 5-1 and
the two Guards of 8-2 ('shamans'); `enemies/raptor` in 3-2, 4-2 and 8-1; `enemies/snatcher` as a bat in 1-2 and a
gull in 7-2 (3-1b's gust-riding Snatchers were not built); `enemies/leech` in 2-1 and 6-1, the leech trait also on
the lurkers of 7-2, 7-2b, 8-2 and 8-2b; `enemies/bull_rex` in 2-2, 3-1 ('lake', hp 100) and 9-2 ('brace');
`enemies/tar_splitter` and split tar blobs in 6-1 only (Feast Land D has no enemy); `enemies/shaman` in 4-2 and 8-2.
The rules that changed them after their first build: a Shellback is hurt only from behind [G82] - so a hole in a
hall's crust is no way in for one hero - and 5-1's gully is kept by a **bond** of two tortoises instead; a
Snatcher never seizes in a ward [G73]; a Tar Splitter falls only to two heroes [G72]; a Bull Rex is hurt only in a
braced daze [G57].

### D.8 Making cooperation required (and proving it)

1. **Gate count**: every co-op `main` file has **at least 2 co-op gates on the main path** (the final-boss stage 9-3:
   its boss form); every co-op `sub` file has at least 1 gate or its boss's co-op form (a boss's own objects, such as
   the visor Colossus's chain plates, are no gate and carry no tablet [G49]); bonus stages and endings need
   only the team exit (the Way Home adds its lookout gate). Every gate is marked by an
   `objects/x2_tablet gate=<name>`.
2. **Gate kinds**: boost ledge (8 tiles over every floor within reach on both difficulties [G28], Shoulder Hop or a
   timed Totem launch [R6]; no lower ledge is a gate - a lone hero's hop jump climbs 5 rows [G69]), Batter Up gap
   (8 tiles Beginner / 9 Expert of deadly liquid [R17], or a 7-tile lob ledge), plate door, twin drums, see-saw, heave boulder, pulley, keeper door, Brace
   Wall corridor (a `heavy` in a 4-row-high hall, hurt only while a Brace Wall dazes it [G57] - a heavy runs under a
   jumping hero, so the hall alone bars nothing). ~~Chomper two-seat stretch~~ - retired as a gate kind [G62]: one rider
   crosses whatever the mount crosses; the two seats stay a set piece.
3. **Solo-impossibility checks** (validator `--coop` + `tests/test_coop_gates.gd`, a slow module run by name:
   `bash .tools/gd.sh test coop_gates` [G13]): for every x2 gate, a bounded search
   with the reference hero (the route tools' simulator), alone, with every weapon including every special from the
   belt and Chomper where a pen is in the stage, must **fail** to reach the gate's far marker. Static rules first: no
   bounceable enemy, spring, geyser, hidden spot column (club pogo), vine, glider, bark board or see-saw within reach of
   a boost ledge (an enemy bounce rises 105 px); plates 8+ tiles from their doors; Guard and keeper halls 4 rows high.
   (As the rules of #6 left them: the **enemy** half of that static rule is the ward's [G73] - inside a tablet's ward
   an enemy may stand anywhere, and the validator names high ground at a ward's edge instead; a spring may stand near
   a height gate whose ledge is 8+ rows over the pad's top [G71]; a coil counts where a hero can **stand** level with
   it [G81]; the hittable half - the clean foot of [G67] - is unchanged.)
   The search (world-B's v2, phase 2) plays the gate's columns with the file's real entities and the partner a lone
   player has - an egg drifting after him, or his idle hatched partner placed anywhere the partner could be hatched,
   who counts for no co-op rule (no weight, no bait, no carrier) [G33] - and throws every special as movement [G28].
   **"Refused" names its evidence** [G59]: per gate and difficulty the table says **refused (exhaustive)** - the
   search's frontier emptied below its bound, or the static reach rule shows that no chain of feet cells reaches the
   far marker - or **refused (bounded)** - the raised bound (at least 660 resting points, uncached) was hit AND every
   continuous-play probe of the gate's type failed (hop-over, charge-under, idle-bait, thrown-special and plate
   probes; LEVEL_DESIGN 15.7.6) - or **open** when any search, probe or replay reached the far marker. A search that
   stopped at its bound without its probes proves nothing: such a gate is **unproven**.
4. **Windows**: 24 ticks on Beginner / 12 on Expert (the Raptor's daze 14 / 12), and **slot-bound** [G72] [G47]: two
   different heroes who both count must meet one, so a window's length is feel, not proof. The first design capped
   every twin window at `min(24 B / 12 E, measured solo minimum - 4)`, measured by the search (one hero striking one
   target and throwing a special at the other included: an axe crosses 12 columns in about 15 ticks), and made a bond
   on one throw line a build error [G36]. One hero then threw at the far member and struck the near one as the throw
   landed - the gap between two hits in flight is his to choose - and three gates fell at G3b; the cap and the
   build error are no proof obligations since. `window=<ticks>` on a record still shortens its window [G2], the
   search reads a bond's solo minimum as "never", and rules that need two heroes' own hits were never capped (D.4
   [G34]).
5. **Fairness**: each gate has an easy role and a hard role; every one-way move has a way back (a drop gift); each gate
   takes under about 30 s once understood; a failure costs an egg, never a life, while the partner stands.
6. **The causes closed by rule** (after the G3b verifier put one hero past 12 of the 45 gates in continuous play;
   G71-G79). Rebuilding gate by gate failed twice, so the engine closes what a lone hero used, for a hero of a co-op
   party only: **a spring is a launch** [G71] (no jump on top of a pad: 105 px over its top, not 256); **bonds are
   slot-bound** [G72] (a bond, a keeper pair, a drum pair or a split is met only by two different heroes who both
   count - the `solo_min - 4` cap of #4 and the one-throw-line error [G36] are no longer proof obligations); **the
   ward** [G73] (around every x2 tablet no enemy gives lift, rest, carry or a pogo); **a closed door passes nobody**
   [G75]; **an idle hero is no anchor** [G76]. Two causes stay building rules: **the long drop** [G74] (a standing
   place h rows over a gate's ledge lies more than 10 + h / 2 cells from it, or the ledge is roofed) and **the gust
   jump** [G79] (in a windy file a gap gate is 12 cells, or its far lip is raised). Two more causes, found by the
   round's own explorer inside the bar, are closed by rule since the G3c integration: **a coil is opened by a hero
   who stands on its level** [G81] (the top of a jump from a place below is not the coil's level) and **over a
   shield there is no behind** [G82] (a `shell` is hurt only by a hero who stands clear of it on its far side; a
   special thrown from on top of it or from inside it glances). How the Levels phase built the wards and the gust
   gap is [G83]. Both rules are the G3c integrator's and are confirmed by the orchestrator for the release [G84].
   Phase 4 tightened two of the rules without touching a gate: the ward's pass ends 12 ticks after the hero lands
   [G87], and an egg beside a partner who goes idle is wiped to the checkpoint after 73 ticks [G86].
   **One opening outside the bar is known** [G92]: a feast's touch kills a `shell` or `daze` keeper, and a kit
   carried in from the stage before opens 8-1 'hall' for one hero (measured on the real level). Decided: such a
   keeper dies only of an accepted weapon hit - not built in the phase; until it is, the level remedy is to move
   8-1's first feast piece behind the hall's door.
   **The proof of a gate is three things** [G77], and the bar is fixed: (a) the solo search refuses it - exhaustive,
   or bounded with every probe (#3); (b) every route of the evidence set - the replayable routes by which a gate
   once fell, versioned under `tools/` - says "not reached"; (c) the continuous-play explorer, versioned under
   `tools/`, opens it in none of two seeded passes of 300 s per gate row over the whole level. A replayable route
   is red whatever the search says; nothing wider than the three is asked. **As passed at G3c**: 45 gates in 76
   rows (31 gates on both difficulties, 14 Expert-only) - 53 refused exhaustively, 23 bounded with every probe; 0 of
   the 33 evidence routes reach their far cell; 152 explorer passes, none reached (`bash tools/world_coop_gates.sh`,
   about 50 minutes, run alone). What a tool cannot judge - whether a pair of people finds each gate fair, readable
   and worth its 30 seconds, and what an expert told to cheat still finds - is `HUMAN_CHECKS.md` [G90].

### D.9 Book I in co-op (15 files `<id>_coop.lvl`)

Each shipped stage gets `levels/<id>_coop.lvl` (`kind = coop`, `coop_of = <id>`, `coop_base_hash = <sha of the solo
file>`): a copy of the solo map with its own edits. The validator warns when the solo file's hash changes, so the two
never drift silently. Co-op files carry no passwords. Specials are placed in pairs where the solo file places weapons.

| Stage | Main-path co-op gates | Trait enemies | x2 secret (painting) |
|---|---|---|---|
| 1-1 Vine Bridges | (1) the springy flower becomes an 8-tile Shoulder Hop ledge, and the upper hero clubs a rolled vine down (teaches hop and gift) [G28]; (2) a leapfrog plate door on the canopy road. Signs teach the egg and the x2 tablet at the first checkpoint | two Shellback turtles before the exit (taught by a sign) | High Cache 7 tiles up, Totem Ride high strike (#20) |
| 1-2 Canopy Village | (1) as built (DB1 [G69]): 'treehouse' - the first tree house stands 8 rows over the root mound, a Shoulder Hop or a timed Totem launch up and a rolled vine back (the 5-row Totem ledge of the first design is inside a lone hero's hop jump); (2) as built (DB1 [G68]): 'shaft' - an 8-row Shoulder Hop ledge in the trunk room; the hero up there crouches on a plate and a stone lifts his partner (the pulley's counterweight hop of [G48] parted the pair by 14 rows). The Feast Land A warp sits in a cage behind twin drums | two dragon leapers in two pits (no bond: a leaper's record never dies [G68]) | treetop cache, 8 rows up, by a charged Batter Up lob (#21) [G48] |
| 2-1 Echo Caverns | (1) paired plates on two hatches (one holds, one drops); (2) a keeper door guarded by two Shellback turtles in a 4-row hall (Raptors need the slot-bound daze of G47 [G48]) | Leeches under the dark section; `lone` stingers (as built the Expert bat over plate A is left out and one Expert turtle is a plain walker [G68]) | a secret-room wall of `$` opened by a Batter Up line drive (#22) |
| 2-2 Bone Gorge | (1) a see-saw on the rising stepping stones; (2) the lift pillar driven by a plate. Two gliders over the gorge with bonded harrier pairs | a Bull Rex on the gorge floor (Brace Wall) | x2 ledge over the lift pillar (#23) |
| 2-2b Brute's Den | a keeper door into the den (two bonded diggers); **the co-op Brute** (B.7) | - | - |
| 3-1 Frost Summit | (1) a Bull Rex on the frozen lake (bracing on ice slides both heroes - the joke of the level); (2) the cliff climb by Shoulder Hop steps with a rolled vine back | bonded chargers, Shellback turtles on the slopes | x2 ice cave (#24) |
| 3-1b Blizzard Pass | (1) a keeper hall of Shellback turtles, 4 rows high, in the gusts; (2) ~~lee leapfrog~~ - no gate [G55]: a sign teaches the lee at the crevasse; the sub-stage keeps its one gate | Snatcher pterodactyls riding the gusts (not built in phase 3) | x2 ledge (#25) over the shelter ridge, 8 rows up, as built: a Shoulder Hop taken in a lull of 70+ ticks (the partner crouches through the gusts 2 cells from the ledge, the hopper rises straight up clear of its underside); the solo file's two ridge chargers are left out of the co-op copy (a sleeping springboard in reach); gate 'lee' is refused by the search on both difficulties and both two-stream routes collect #25 (a lee helps nobody here [G55]) |
| 3-2 Crystal Grotto | (1) a Batter Up line drive over 9 tiles of icy water (8 on Beginner: a `beginner` floe column on the near lip); (2) twin drums, one on each bank, that freeze a floe bridge (a column) so the batter can follow - both gates at the leaper lake [G44] | Raptors, twin leapers from the water pits | the Feast Land C warp on a boost ledge; crystal cache (#26) |
| 4-1 Cinder Shaft | (1) both inside the auto-scroll: a heave boulder pushed off a ledge plugs a lava vent before the view passes; (2) as built (DB3, reviewed and accepted [G62]): a Shoulder Hop onto the 8-row exit cliff ('cliff'), a rolled vine back (its coil 8 rows up, 12 cells from the far cell) - a lob onto 8 rows meets the chamber's ceiling and a 7-row lob ledge falls to one player [G48] | `lone` stingers in the ember rain (the zigzag and strata stingers stay plain: those steps part the pair by a row; the pair descends a ledge apart, never under or over each other, while [G54] is open) | x2 shelf (#27) |
| 4-2 Obsidian Keep | (1) leapfrog plate doors (A holds for B, B holds for A); (2) twin drums that raise a portcullis on the ramparts for good (spikes are no door) [G44] | Shamans shielding the keep guards; Raptors | x2 keep tower (#28) |
| 4-2b Colossus Hall | **the visor Colossus** (B.7); two axes at the checkpoint, the second hung 3 rows up so one hero cannot take both; as built (DB3) a rock ledge two rows high between the chain plates replaces the obsidian slab, so the thrower dodges only the ceiling drops and the holder hops the rocks [G49] | - | - |
| Feast Land A / B / C | team exit only; a giant roast spot pays its giant bonus only when both strike it within the window; **Relay Bounce**: alternate bounces by both heroes on one enemy extend the 1-2-3-4-6-8 ladder to x10 and x12 | - | - |
| Way Home | the village gate is barred: one hero is lifted to the lookout gallery 8 rows over the road (Shoulder Hop) and steps on its latch plate, 9+ cells from the door, to open it [G44]; team exit | - | x2 lookout (#29) |

Paintings 0-19 are the Book II ones (one per level, in `A.2` order).

**The wards as built** (both books; measured on the level files by `build/lead_design/wf12/wards.py`, which
reproduces the G3c verifier's figure). 23 of the 35 co-op files carry x2 tablets - 53 of them: 43 gates and 10 x2
secrets, two of which ('icecave' of 3-1, 'lee' of 3-1b) are named and searched like gates, the 45 names of the gate
table - and their wards cover **1 786 of 3 977 columns, 44.9 %** (34.4 % of all co-op columns): **4-1 and
5-2 from end to end** (46 and 64 columns; narrow, tall files with a tablet at each end and a `ward=` to the map's
edge), 1-2 84 %, 9-1 80 %, 6-2b 73 % (the ward of 'vent' reaches up the trunk towards Old Mangrove's hall), 8-1
66 %, 2-2b 60 % (the ward of 'den' covers the tunnel into the Brute's den), the others 20-55 %; the twelve files
without a tablet - the Feast Lands, the boss sub-stages of 4-2b, 5-2b, 7-2b, 8-2b, 9-2b, the final stage 9-3 and
the Long Raft Home - have none. A ward is "over all rows", so in the tall files it covers whole towers. Inside those
columns stand 186 of the 396 enemy records of the co-op files: that many beasts wear the ward mark where they are
placed [G85], and a pair has no head bounce there - in 1-1 the hopper fight at the crate lost its pogo to the 12
columns `ward=34,12` added [G83]. One trait enemy lost its trait to a ward as well: the Snatcher bat of 1-2 (column
63, its perch at 73) hangs inside the ward of 'treehouse' (columns 15-95), where a Snatcher never seizes [G73] - in
2.0 it only hurts; the Snatcher gull of 7-2 (column 30) stands clear of both wards of its stage and seizes as
designed. Whether a pair misses the bounce and the grab, and whether the mark reads at a glance, is
`HUMAN_CHECKS.md` [G90].

### D.10 Book II in co-op (20 files `<id>_coop.lvl` on the same skeleton)

Authored together with the solo file: the designer builds the solo file, proves it, copies it to `<id>_coop.lvl`
and adds the co-op gates, traits and the P2 start.

| Level | Co-op signature (main-path gates) |
|---|---|
| 5-1 Red Mesa Trail | teaching stage: an 8-tile Shoulder Hop ledge with a rolled-vine gift [G28] ('hop'); a leapfrog plate door ('plates'); a keeper gully under the plain ('gully'), as built kept by a **bond** of two tortoises - each hero clubs one inside the window, sign "Twin tortoises: club one each at once, or one grows back!" (the first design's pincer on two Shellback guards fell to one hero who dropped through the crust onto a keeper and threw from on top of it [G82]). The sign of the ward mark stands before 'hop' [G85] |
| 5-2 Rattlesnake Gulch | a vertical leapfrog ('sandgate'): one climbs a vine while the other holds a plate that keeps a sand gate open; the upper hero unrolls the second vine (the gift); twin rattlers, the bonded keepers of the hall door ('rattlers'). Its two wards cover the whole file [G83] |
| 5-2b Tusker's Wallow | co-op Tusker: rump pincer, Brace Wall in phase 3 (B.1) |
| 6-1 Bubbling Fen | a Batter Up gap where the raft sank ('sunk'); as built, Old Root, an 8-tile Shoulder Hop ledge with a rolled-vine gift ('root', A.6's fallback [G62]); then Chomper with two seats (no gate): the driver wades the tar flats, the gunner clears Leeches; a raft for two (one paddles, one fights); Tar Splitters (A.6) |
| 6-2 Spore Hollow | a mushroom see-saw in the dark ('seesaw': a drop from the cap ledge onto the high end throws the partner to the upper passage 9 rows over the low end; rock roofs the cap ledge [G83]); twin drums made of glowing caps, 16 cells and 7 rows apart ('caps'); `lone` bugs and mosquitoes (the Raptors and bonded Puffcap pairs of the first design were not built) |
| 6-2b Heart of the Mangrove | rising tar for two: a heave boulder must be pushed onto two deadly tar vents before the tar reaches the room ('vent'); co-op Old Mangrove (B.2) |
| 7-1 Shell Beach | a Batter Up lob from the rock's 3-row step onto a sea stack 10 tiles over the beach, 7 over the step ('stack'; the blowholes stay out of the gate's reach) [G70]; as built, leapfrog plate doors through a dune ('dune', A.6's fallback for the two-seat Chomper over the urchin beds, which are not in the co-op copy [G62]); Shellback tortoises and `lone` gulls (A.6) |
| 7-2 Sea Caves | leapfrog plate doors in a sea wall ('seagate'): plate A holds the lower tunnel's door for the partner, plate B beyond holds the upper tunnel's for the holder (as built on the drift-log ledge, the floes before and after it [G62]); a Batter Up line drive over dark water ('dark_gap'); a Snatcher gull over the floe channel; Leeches (A.6) |
| 7-2b Squid Grotto | the Tentacle Lock (B.3) |
| 8-1 Overgrown Steps | a keeper hall exactly 4 rows high with two Shellbacks ('hall': one baits, the other drops in behind through the lintel's hole and clubs the backs); column stairs ('stairs'): the pair heaves a boulder onto plate A, one holds plate B while the other climbs the three stair columns and holds plate C on the summit, which lifts the door of a vine shaft for the holder; a temple Raptor before the exit |
| 8-2 Hall of Idols | leapfrog plate doors between the entrance hall and the spike room ('rooms'); a closed keeper hall of a Shaman and two shell Guards under four hatches ('shamans'): the pair pins the Shaman, then one baits each Guard while the other drops in behind it |
| 8-2b Idol Court | the Twin Hit (B.4) |
| 9-1 Cloudbreak Climb | a see-saw to a cloud 9 rows over its low end (geysers lift the heroes elsewhere on the climb, never within a gate's reach); a pulley between two cloud stacks; `lone` harriers (A.6) |
| 9-1b Thunderhead Glide | two gliders; a bonded pair of perched storm pterodactyls, the keepers of a storm-cloud wall, each high-struck from the cloud within the window ('stormwall', A.6; keeper Harriers hold their perch [G66]) |
| 9-2 The Roc's Spire | the gusts with the lee as a comfort (no lee gate [G55]); a Bull Rex in a sunken hall 4 rows high that only a Brace Wall stops ('brace'); a **charged** Batter Up line drive over the final gap of 13 cells of tar ('drive'): the batted hero steps on a latch plate, a cloud slab sinks into a bridge over 9 of the 13 cells and the partner hops the last 4 in a lull [G79] [G83] |
| 9-2b Storm Nest | Snatch rescue and Pilot and Spotter (B.5) |
| 9-3 Chieftains' Pyre | both chieftains at once, the 66-tick egg race (B.6) |
| Feast Land D / E | roasts for two, Relay Bounce; team exit only |
| The Long Raft Home | one raft for two; the home beach is the team exit |

**After G3b and G3c** (the rulings G71-G83): the stages kept their gates, and thirteen files changed to hold them
against one hero in continuous play. As built: nine tablets carry `ward=` (D.5; 1-1's 'hop' is 34,12 - its hollow
block and the pool's ledge are high ground before the tablet [G73] [G83]); 7-1's warp stack stands six columns
left, 16 cells from the 'stack' shoulder (the long drop [G74]); 9-2's final gap ('drive') is 13 cells with a slab
of 9 - a lone hero's gust jump crossed its 9 cells on both difficulties [G79]; a stalactite and a rock roof stand
over the cap ledges of 2-2 and 6-2 'seesaw', and the foot of 2-2's x2 bone ledge is clear (built before the coil
rule [G81], kept); 5-1's gully is a bond [G82]; `bond=` is gone from 3-2's zone-spawner leapers. 21 co-op routes
that took lift from an enemy inside a ward, stacked a jump on a spring, let one hero meet a bond or leaned on an
idle partner's view were re-recorded on those files; all 57 replay.

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
  | Twin windows (slot-bound [G72]; a record's `window=` may shorten one) | 24 ticks | 12 ticks |
  | Raptor daze | 14 ticks (only the other hero hurts it [G47]) | 12 ticks |
  | Leash before the egg | 5 s (121 ticks) | 3 s (73 ticks) |
  | Hatch hearts | 2 | 1 |
  | Unhatched egg | follows forever | returns to the checkpoint after 10 s |
  | `lone` trait | off (acts as plain targeting) | on |
  | Boss grabs | off | on |
  | Boost ledges | 8 tiles [G28] [G39] | 8 tiles |
  | Idle partner | 243 ticks without input [G33] | 243 ticks |
  | Egg beside an idle partner | the tribe is wiped to its checkpoint after 73 ticks [G86] | 73 ticks |
  | Ward: margin / grace after a stomp that gave nothing | 12 cells / 12 ticks [G73] [G87] | 12 cells / 12 ticks |

  The Beginner wall is unchanged in both books.

### D.12 The values 2.0 ships with [G91]

Every value this design marks *(tune)* was a starting value for playtests. No human playtest took place during
production - G1's pair playtests moved to P4.5 [G3], and P4.5 is done by people with the finished build
(`HUMAN_CHECKS.md` [G90]) - so **2.0.0 ships every one of them at the value below: what the tree holds on the
release day.** `docs/spec/test_spec_docs.py` pins every `Class.NAME = n` of this table against its constant. A
check that fails changes the value here first, then in GAMEPLAY 13.11 / PHYSICS C.16 and in its constant (PLAN
2.5). The last column says what must be run again after a change: **gates** = `bash tools/world_coop_gates.sh` (the
three proofs; about 50 minutes, alone) and `tools/sp_identity.sh`; **routes** = the route replays of that mode
(`bash .tools/gd.sh test coop_routes` / `book2_routes`); **bots** = `bash tools/g3_versus_bots.sh`.

| Value | Constant = what 2.0 ships | Rests on it | After a change |
|---|---|---|---|
| Twin window: bonds, splits, drums, twin boss hits (Beginner / Expert) | `PartyTuning.WINDOW_TICKS_BEGINNER = 24`, `PartyTuning.WINDOW_TICKS_EXPERT = 12`; count-in `PartyTuning.COUNT_IN_BEEPS = 3` blips `PartyTuning.COUNT_IN_SPACING_TICKS = 8` ticks apart | feel only - every window is slot-bound [G72] | routes |
| Raptor daze (Beginner / Expert); Mimic daze | `PartyTuning.DAZE_TICKS_BEGINNER = 14`, `PartyTuning.DAZE_TICKS_EXPERT = 12`; `EnemyTuning.MIMIC_DAZE_TICKS = 22` | feel only - the daze is slot-bound [G47] | routes |
| Daze hop; split run | `EnemyTuning.DAZE_HOP_XVEL = 64`, `EnemyTuning.DAZE_HOP_YVEL = -96`; `EnemyTuning.SPLIT_RUN_XVEL = 48` for `EnemyTuning.SPLIT_RUN_TICKS = 22` ticks | feel | routes |
| Brace Wall: gap between the crouchers; a heavy's daze (the co-op Tusker's is 66) | `PartyTuning.BRACE_GAP_PX = 16`, `PartyTuning.BRACE_DAZE_TICKS = 44` | the pair's strikes of a brace gate must fit one daze [G63] | gates, routes |
| Idle partner; its "Zzz soon" warning | `PartyTuning.IDLE_TICKS = 243`, `PartyTuning.IDLE_WARN_TICKS = 170` | every gate's proof (the idle partner of the solo search counts for nothing [G33]) | gates, routes |
| Egg beside an idle partner: the wipe | `PartyTuning.IDLE_WIPE_TICKS = 73` | no gate [G86] | the party tests |
| Ward margin (nine tablets carry their own `ward=`, D.5) | `PartyTuning.WARD_MARGIN_CELLS = 12` | every height and gap gate [G73] [G83] | gates, routes |
| Ward grace after a stomp that gave nothing | `PartyTuning.WARD_GRACE_TICKS = 12` | no gate rests on a body as a barrier [G87] | gates (the evidence routes replay against it), routes |
| Leash before the egg (Beginner / Expert) | `PartyTuning.LEASH_EGG_TICKS_BEGINNER = 121`, `PartyTuning.LEASH_EGG_TICKS_EXPERT = 73` | feel; the idle hero is the one it takes [G76] | routes |
| Hatch hearts (Beginner / Expert), hatch blinking, Expert egg return, voluntary egg | `PartyTuning.HATCH_HEARTS_BEGINNER = 2`, `PartyTuning.HATCH_HEARTS_EXPERT = 1`, `PartyTuning.HATCH_BLINK_TICKS = 44`, `PartyTuning.EGG_RETURN_TICKS_EXPERT = 243`, `PartyTuning.VOLUNTARY_EGG_HOLD_TICKS = 24` | feel | routes |
| Egg drift (near / far), nudge; Totem drop lock | `PartyTuning.EGG_DRIFT_PX = 2`, `PartyTuning.EGG_DRIFT_FAST_PX = 6`, `PartyTuning.EGG_NUDGE_PX = 1`; `PartyTuning.TOTEM_DROP_LOCK_TICKS = 12` | feel | routes |
| Curl; Batter Up: line drive, lob, grounder, charged x 3 / 2 | `PartyTuning.CURL_MAX_TICKS = 66`; `PartyTuning.BAT_LINE_DRIVE_XVEL = 144`, `PartyTuning.BAT_LINE_DRIVE_YVEL = -128`; `PartyTuning.BAT_LOB_XVEL = 32`, `PartyTuning.BAT_LOB_YVEL = -240`; `PartyTuning.BAT_GROUNDER_XVEL = 96` for `PartyTuning.BAT_GROUNDER_TICKS = 32` ticks; `PartyTuning.BAT_CHARGED_NUM = 3` / `PartyTuning.BAT_CHARGED_DEN = 2` | the width of every Batter Up gap (8 / 9 cells, 13 on 9-2) and the 7-row lob ledge | gates, routes |
| Lee: reach downwind, vertical | 64 px, 16 px (`PartyTuning.LEE_REACH_PX`, `LEE_DY_PX`) | feel - the lee is no gate [G55] | routes of 3-1b and 9-2 |
| Enemy target hold | `PartyTuning.TARGET_HOLD_TICKS = 22` | feel | routes |
| Roller walk, sense rows, uncurl; Guard patrol; Shaman speed | `EnemyTuning.ROLLER_WALK_SPEED = 32`, `EnemyTuning.ROLLER_SENSE_ROWS = 4`, `EnemyTuning.ROLLER_ROLL_MAX_TICKS = 154`; `EnemyTuning.GUARD_SPEED = 24`; `EnemyTuning.SHAMAN_SPEED = 48` | feel | routes (solo and co-op) |
| Swap lock-out; vine re-grab lock; tar hop impulse ticks and air cap; geyser period and deadly spout height; lightning bolt | `Tuning.SWAP_LOCKOUT_TICKS = 8`; `Tuning.VINE_REGRAB_LOCK_TICKS = 12`; `Tuning.TAR_JUMP_IMPULSE_TICKS = 2`, `Tuning.TAR_AIR_CAP = 32`; `Tuning.GEYSER_PERIOD = 88`, `Tuning.GEYSER_DEADLY_H = 64`; `ObjTuning.LIGHTNING_BOLT_TICKS = 4` | the Book II solo routes | routes (Book II), gates |
| Chomper: food bonus, wild pace | `MountTuning.FOOD_BONUS = 500`, `MountTuning.WILD_PACE_V16 = 16` | feel | routes of 6-1 |
| Co-op boss fights | 45-90 s (1 093-2 185 ticks) on the recorded routes, at most 6 hurts on the Expert route [G61] (B.0's table) | the route headers pin the band | the boss tests, routes |
| Last Caveman Standing: the hard cap after the sudden death starts; drawn rounds that end a match | `VersusTuning.SUDDEN_DEATH_CAP_TICKS = 1457`; `VersusTuning.DRAW_ROUNDS_TO_END = 3` | every round and every match ends [G78] | `bash .tools/gd.sh test versus_rules`, bots |
| Grub Stack weight; the giant bonus's bonk | `VersusTuning.STACK_HEAVY = 10` (walk cap `VersusTuning.STACK_HEAVY_WALK_CAP = 64`), `VersusTuning.STACK_HEAVIER = 20` (walk cap `VersusTuning.STACK_HEAVIER_WALK_CAP = 48`, jump impulses 3 / 4); `VersusTuning.GIANT_BONK_DAZE_TICKS = 12` | feel; the bots' fairness sets | bots |
| Versus bumps: body knock, teammate bump | `VersusTuning.BODY_KNOCK_XVEL = 64`, `VersusTuning.BODY_KNOCK_YVEL = -64`; `VersusTuning.TEAMMATE_BUMP_XVEL = 32` | feel | bots |
| Hot Rock: first pick, re-pick; coconut roll loss | `VersusTuning.HOT_ROCK_FIRST_PICK_TICKS = 66`, `VersusTuning.HOT_ROCK_REPICK_TICKS = 66`; `VersusTuning.BALL_ROLL_LOSS = 2` | feel; Coconut Cove's bot sets | bots |
| Spawn fairness of an (arena, mode) | within +/- `VersusTuning.BOT_WIN_RATE_SPREAD_PERCENT = 15` points per spawn, claimed on at least 384 rounds [G80] | the release's fairness claim | `bash tools/bots/fair.sh <tag> <arena> <mode> 0 96` |

Not in the table because they are no single number: the variants and the sudden-death cadences of E.4 / E.6
(`VersusTuning`, each telegraphed 10+ ticks ahead) and the boss fill-ins of section B (`EnemyTuning`; each boss test
pins its telegraphs, its escapability and its fight band). They ship as the tree holds them, under the same rule.

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
  rival pogoing under a one-way bridge 3 rows up pokes his head 2 px through it). **A stomp comes from above**
  [G93]: the stomper's feet are higher than his victim's - two heroes who fall side by side at one height stomp
  nobody (under the 1.0 body test each stomped the other and the pair climbed out of the arena's top).
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
| **Last Caveman Standing** | the literal deathmatch: 3 hearts; hit = 1 heart, charged = 2 + launch, stomp = 1 + squash, hazard = out. **A lost heart bursts into 6 bones** anyone can grab (6 bones heal a heart, max 3). Last alive wins the round; first to 5. At 60 s the arena's **themed sudden death** starts (E.6). **A hard cap** [G78]: 60 s after the sudden death started the round ends whoever stands - the side with more heroes standing, then more lives (Stock), then the **fewest hurts taken** wins; level sides draw, and **three drawn rounds in a row end the match** on its standings (`VersusTuning.DRAW_ROUNDS_TO_END` = 3 *(tune)*, every mode) [G78]. Eliminated players ride **Grudge Pterodactyls** along the top and drop a rock with Strike (one per 3 s, 10-tick squawk first; a rock dazes 12 ticks, costs no heart). Option *Stock*: 3 lives with respawn | yes |
| **Hot Rock** | a glowing ember sticks to one player and passes on any touch, hit or stomp; whoever passed it is immune to it for 44 ticks; the holder walks up to 96 v16 (faster than the others' 80) [R7]; the fuse is 12-20 s (`Sim.rng`, round seed) and bubbles faster in the last 3 s; the holder pops (the death toss). Last one standing; first to 3 | yes |
| **Clubball** | 1v1, 2v1 or 2v2 on Coconut Cove: a coconut (gravity 16 v16, bounces at 3/4 and comes to rest within six bounces [G19], rolls) and a goal mouth 3 rows high at each end. The strike direction is the shot (front frames only): forward = drive, high = lob, low = grounder, charged = smash (x1.5); boxes on the ball in one tick add up, and one swing shoots it at most once. Every strike within 44 ticks of the last adds +16 v16, up to 12 px/tick (rallies escalate; a smash keeps its own speed); a coconut faster than 8 px/tick knocks a hero down (12 stun ticks) and rebounds at half speed; heads bounce it; a curled teammate can be batted as a "missile". First to 5 goals or most after 3 min; sudden death "golden coconut"; the ball resets to the middle 66 ticks after a goal; a coconut that comes to rest inside a wall is lost and drops in again the same way [G93] | yes |
| King of the Feast | carry the giant roast to fill 20 counts of 22 ticks; the carrier cannot strike, walks at most 64 v16; a hit drops it; your count never falls back below 5 left | second wave |
| Letter Snatch | 8-12 visible spots, five hold G-R-U-B-S (shuffled); held letters float over your head; a hit drops your newest; hold all five for 44 ticks = round won | second wave |
| Egg Heist (2v2) | carry a giant egg to your nest ledge; teammates boost and bat each other; the egg cracks after a fall of 6+ rows; a mother rex chases a carrier who holds it 8 s | second wave (team bots) |

- **Party Mix** picks mode and arena per round. **Presets**: *Classic* (club only, no crates), *Feast* (default),
  *Mayhem* (crates every 8 s, skull spots, a random variant per round).
- **Variants**: Hammer Time, Axe Rain, Big Bounce, One-Bonk, Slippery, Lights Out (night palette, heroes glow), Gusty,
  Giant Rain, Spear Party (some unlocked by paintings, C.9).
- **Handicap card** in the lobby: hearts 1-5 (LCS) or stack guard x0.5 / x1 / x1.5 (Grub Stack), or Auto (a player
  two rounds behind gets a leaf shield that absorbs one hit).

### E.5 Arenas: 8 single screens (cut 3 applied [G60])

Every arena is **20 x 12 cells** (floor row 10, fill row 11), camera locked; row 0 holds nothing to stand on (HUD corners
and the round sundial); wider or taller screens show a decorated frame, never gameplay. Tiers 3 rows apart; 5+ rows only
by spring, geyser, see-saw or a head; clear gaps of at most 5 cells; mirrored layouts with spawns rotated every round;
4-8 visible hidden spots; one signature hazard telegraphed 10+ ticks ahead; geometry a bot graph can describe (no 1-row
squeezes, no pixel-perfect jumps on main routes). Files `levels/arena_<name>.lvl`. An arena plays a mode with bots only
when its bot set is green there; otherwise meta `bots` leaves that mode out and it is human-only (PLAN cut 4 [G50]).

| # | Arena | Biome | Edges | Signature | Sudden death | Default mode |
|---|---|---|---|---|---|---|
| 1 | **Totem Ring** | jungle | wrap left-right | a totem with the cookpot on top; springs to the wrap ledges; the big spot in the totem's base, its giant falls onto the totem top [G31] | **Stampede**: chargers along the floor every 3 s, dust 22 ticks ahead | Grub Stack (also Last Caveman Standing, Hot Rock) |
| 2 | **Echo Hollow** | cave | wrap top-bottom (a shaft: the floor's 4-cell hole drops onto the central ledge) | darkness pulse every 20 s (3 s of night, heroes glow; the referee's `dark_pulse` since phase 3 [G43]). The regrowing `$` walls and the dangler springboard of the first design are **dropped** [G60]: every placement broke spawn fairness in Grub Stack (not built at G2 [G31]; the referee's `regrow` and neutral-enemy rules stay unused) | **Cave-in**: blocks fall from the top row inward, one per 11 ticks | Hot Rock (also Grub Stack, Last Caveman Standing) |
| 3 | **Floe Rink** | ice | open sides into icy water | ice floor, two see-saw floes (land on your end to fling whoever stands on the other out over the water), alternating gusts; until the bots ride a tilted see-saw, two fixed floes instead and the gusts carry the signature [G51] | **Whiteout**: gusts grow every 5 s | **Grub Stack only** [G60] (`modes = grub_stack`, with bots: no Last Caveman Standing or Hot Rock layout came within +/-15) |
| 4 | **Cinder Pit** | volcano | walls (no lava at the ends [G31]), a 4-cell lava pit in the middle | obsidian slabs over the pit, one crate lane over the whole arena; the ember lane is the referee's `ember_lane` since phase 3 [G43] | **Lava rise**: 1 row per 44 ticks with a rumble | Last Caveman Standing (also Hot Rock, Grub Stack) |
| 5 | **Tar Pulleys** | swamp | walls, tar pit | two pulley lifts over tar: step on your lift to yank a rival's side up to the island - or down to the tar | **Tar rise** | Grub Stack (also Hot Rock, Last Caveman Standing). Since the G3 follow-up round **with bots in Grub Stack and Hot Rock** (`bots = grub_stack,hot_rock`: core-B's pulley links turned those sets green [G60]); **Last Caveman Standing is human-only** there (G50 per mode: its set is red on spawn fairness - the right-hand pair meets first) |
| 6 | **Coconut Cove** | coast | walls with goal mouths | the Clubball pitch: rims, a lob bridge, two low ledges; in other modes the goal mouths are ring-outs into the surf (leaving through one is a hazard; the referee's ring-out rule since phase 3 [G43]) | **High tide** (the rising-tide code) | Clubball |
| 7 | **Sky Picnic** | Feast Land | wrap top-bottom, **no deaths** (kid-safe) | springs, icing clouds, a cake island | **Syrup flood** (safe: it only slows) | Hot Rock / Grub Stack (no Last Caveman Standing) |
| 8 | **Colossus Hall** | volcano keep | walls | the Wall Colossus as a neutral (no hits, no bar; its body a picture): every 10 s it spits at the **crowned leader** - in Last Caveman Standing the hero with the most hearts, a tie: no spit (jaws 10 ticks ahead) [G43] | **Stalactite storm** | Grub Stack (also Last Caveman Standing; no Hot Rock, no Clubball) |
| 9 | ~~Mesa Rodeo~~ - **cut, not in 2.0** (cut 3 applied [G60]; its 5-painting reward is now four loincloth patterns, C.9); the design is kept for a later version | canyon | walls | Chomper is released from his pen at every multiple of 30 s of round time while he waits penned (rumble 22 ticks ahead: his picture shakes, no screen shake) and stays out for riders; the rider bites rivals (spill 3); a stomp on the rider unseats him (no stun) and Chomper stays out for the stomper; only a hit sends him back to his pen [G20]; regrowing cover blocks | **Rockslide** from the mesa rims | Last Caveman Standing |
| 10 | ~~Cloud Top~~ - **cut, not in 2.0** (cut 3 applied [G60]; its 20-painting reward is now the Spear Party variant, C.9) | sky | wrap top-bottom | drop clouds, alternating gusts (crouch to brace), steam geysers | **Lightning**: marked cells, 22 ticks ahead | Grub Stack |

Sketches (`?` small spot, `*` big spot, `J` spring -224, `-` / `=` one-way platform of set A / B, `P` cookpot, `L` /
`R` pulley lifts, `G` goal zone, `B` coconut drop point, `%` rim rock, `~` liquid, `1`-`4` spawns). Each must pass
`tools/validate_levels.gd` (`kind = arena`) and the bot graph bake. Totem Ring, Cinder Pit, Echo Hollow and Coconut
Cove are drawn **as built at G2** (DA, `levels/arena_<name>.lvl`; balance by V4.b: 12 seeds x 4 rounds, four Hunters,
wins per spawn within +/-15 points of the fair share) [G31]; Sky Picnic, Colossus Hall, Floe Rink and Tar Pulleys as
built in phase 3 (every sketch equals its file: `docs/spec/test_spec_docs.py` compares them).

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
Caveman Standing 12. Phase 3 (DA): the darkness pulse is built (`dark_pulse = 486`: 73 ticks of night every 486; it
changes only the picture - the bot sets are tick-identical, Hot Rock 8, Grub Stack 8, LCS 12). The regrowing `$`
walls and the dangler springboard are NOT in the arena: every placement measured handed the right floor spawn Grub
Stack (21-33 points worst; variants `build/da/variants/arena_echo_*.lvl`); the referee's `regrow` and neutral enemies
wait for a layout that keeps them away from the floor spawns' first moves [G43].

**Sky Picnic** (wraps top-bottom, kid-safe: no deadly cell; modes `hot_rock`, `grub_stack` - no Last Caveman
Standing on the kid-safe arena; sudden death `syrup_flood`):

```
     col 01234567890123456789
row  0   ....................   nothing to stand on; a plain jump never reaches the top seam
row  1   ....................
row  2   ....................
row  3   ....4.P......P.3....   spawns 4 / 3 and the pots on the icing clouds
row  4   ...?====....====?...   icing clouds (one-way), spots flush in their outer ends
row  5   ....................
row  6   ....................
row  7   ........?##?........   the cake island; small spots flush in its top corners (8 / 11)
row  8   ........####........
row  9   ..J...1......2...J..   springs (cols 2 / 17) to the clouds' outer ends; spawns 1 / 2 on the floor
row 10   #######*....*#######   a big spot in each lip of the hole (7 / 12): its giant falls onto its own lip
row 11   ########....########
```

As it stands since phase 4 (versus [G80]): until then the big spot was two cells in the island's top (9 / 10), the
small floor spots sat at cols 5 / 14 and the spawn numbers were the mirror image; both floor Hunters dug the big
spot from the floor, the giant fell onto the island, and the right floor climbs the island with a standing jump
where the left needs a run-up - spawn 1 took 42.7 % of 384 Grub Stack rounds. Measured on the arena as drawn (four
Hunters, 384 rounds twice, wins by spawn 1 / 2 / 3 / 4): Grub Stack 22.1 / 24.5 / 31.0 / 22.4 % and 23.2 / 26.3 /
30.2 / 20.3 % (worst +6.0); Hot Rock 26.3 / 26.0 / 22.1 / 25.5 % and 25.0 / 26.0 / 26.8 / 22.1 % (worst -2.9) -
on the rules before the stomp rule of [G93]; with it the sets are played again (the versus builder's report).

**Colossus Hall** (walled; modes `grub_stack`, `last_caveman` [G43]; sudden death `stalactites`):

```
     col 01234567890123456789
row  0   ....................
row  1   ....................
row  2   ....................
row  3   .....3.P....P.4.....   spawns 3 / 4 and the pots on the upper slabs
row  4   ...?=====..=====?...   upper slabs (one-way), spots flush in their outer ends
row  5   ....................
row  6   ....................
row  7   ........%*%%........   the carved altar (rows 7-9); the big spot (9, 7), plain stone either side
row  8   ........%%%%........
row  9   ..J...2.%%%%.1...J..   springs to the slabs' outer ends; spawns 1 / 2 on the floor; `bosses/colossus 19 9`
row 10   #####?########?#####   floor spots 5 / 14; the statue's picture over cols 13-19 rows 4-9 blocks nothing
row 11   ####################
```

The neutral statue spits every 243 round ticks at the crowned leader / the hero with the most hearts (a tie: no
spit). The big spot stays one cell: a two-cell spot left a hero stranded in the sliver between the floor node and
the altar's face (a navigator case of core-B). Measured: Grub Stack 4-8 points worst, LCS 10-11.

**Floe Rink** (open sides into icy water; `modes = grub_stack` [G51]; gusts `wind = 0:-24,121:24`, `wind_loop =
242` - the first gust blows right; sudden death `whiteout`):

```
     col 01234567890123456789
row  0   ....................
row  1   ....................
row  2   ....................
row  3   .....P.3....4.P.....   pots and spawns 3 / 4 on the upper ledges (one-way rock)
row  4   ...?====....====?...   spots flush in the ledges' outer ends
row  5   ....................
row  6   ....................
row  7   ........=**=........   the central floe (one-way rock), the big spot as two cells (9 / 10)
row  8   ....................
row  9   ......2......1......   spawns 1 / 2 on the floor
row 10   ~%%~%##?####?##%~%%~   ice floor cols 5-14 (`ice_a = 1`); fixed rock floes cols 1-2 / 17-18 [G51]; icy water 0, 3, 16, 19
row 11   ~%%~############~%%~
```

Measured: Grub Stack 2 points worst (25 / 23 / 25 / 27 %), worst idle 48 ticks. Last Caveman Standing (E.5's first
default) reached no layout within +/-15 points (17-50 over ten variants: an open ice rink with four Hunters is decided
in the first seconds), Hot Rock was worse; so **Floe Rink ships Grub Stack only** (`modes = grub_stack`, bots on)
[G60] - the orchestrator's decision: no human-only Last Caveman Standing either (an open ice rink decides it in the
first seconds whatever the layout).

**Tar Pulleys** (walled; modes `grub_stack`, `last_caveman`, `hot_rock`; as built by DA and shipped at G3 with
`bots = none` [G50]: its pulley lifts never return to rest and the bots' links were baked for the rest state only.
[G60] gave it bots only on green pulley links, and they came in the follow-up round: core-B bakes a lift's links at
every still state of its pulley, for every weight class (2 666 links), and with the bots forced on Grub Stack
(19 / 38 / 23 / 21 % per spawn) and Hot Rock (21 / 33 / 23 / 23 %) are green; Last Caveman Standing (6 / 29 / 48 /
15 %) is red on spawn fairness alone. So the file says `bots = grub_stack,hot_rock` and Last Caveman Standing is
human-only there. A fixed-lift stand-in would lose its only idea, so none is built):

```
     col 01234567890123456789
row  0   ....................   HUD row; the log beam with the pulley wheels is a prop
row  1   ....................
row  2   ........P..P........   two cookpots on the island (cols 8 / 11)
row  3   ........%*%%........   the mud island (set B) with the big spot (9, 3), plain mud at col 10
row  4   ........%%%%........
row  5   .2................1.   spawns 2 / 1 on the side ledges
row  6   ##?..LLL....RRR..?##   side ledges, spots in their inner ends; lifts L (cols 5-7) and R (12-14) at rest
row  7   ###..............###
row  8   ....................
row  9   .3.J............J.4.   spawns 3 / 4 on the banks; springs (cols 3 / 16) up to the side ledges or a lift
row 10   ##?##~~~~##~~~~##?##   banks with spots (cols 2 / 17); a mud stump (cols 9-10) between two 4-cell tar gaps
row 11   #####~~~~##~~~~#####
```

L and R hang from one rope: the heavier lift sinks 2 px/tick down to row 9, one row over the tar, while the other rises
to row 3, level with the island (`objects/pulley range=3`). The island is a 3-row jump from a lift at rest or a walk
off the high lift; a rival who jumps onto the low lift yanks you down; equal weights stay where they are.

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
for a failing graph [G50]). Measured in phase 3: the side that defends the RIGHT goal wins 69 % (the start
positions 2 + 4) - world-B traced it to the coconut, whose x step floors (`Tuning.floor16`), so every speed that is
not a multiple of 16 carries the ball 1 px per tick farther left (mirrored shots rest 120 / 152 px apart): the ball
drifts to the left goal. The fix is a symmetric x step and rebound in `coconut.gd` (objects-B, no owner in phase
3); until it lands the cell stays red with that cause, and Clubball keeps its bots.

### E.6 Themed sudden deaths

Per biome: Stampede (jungle), Cave-in (cave), Whiteout (ice), Lava rise (volcano), Tar rise (swamp), High tide (coast),
Syrup flood (feast, slows only), Stalactite storm (keep), Rockslide (canyon), Lightning (sky). Every one telegraphs 10+
ticks ahead. They start at 60 s in Last Caveman Standing and are available as an event toggle in the other modes.
No sudden death is the round's end by itself: two players who keep out of its reach never ended a Colossus Hall
round, so Last Caveman Standing has the hard cap of E.4 [G78] and the HUD's sundial counts its 60 s down; the
round banner of a round the cap ended reads "TIME!" over its result. **Nobody stays outside the arena's sides**
[G93]: a hero whom a Cave-in block squeezes out of the map's side on an arena without a left-right wrap is knocked
out as by a hazard.

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
- **Fairness is claimed on enough rounds** [G80]: win rates per spawn stay within +/-15 % (PLAN 8 V4.b); the bot
  module's 48-round sets are a regression pin, and a claim for an (arena, mode) is made on at least 384 rounds.
  Measured so: Totem Ring's Grub Stack is inside (worst +5.7); Sky Picnic's was not at G3 (spawn 1: 42.7 %, +17.7 -
  the cake island is a standing jump from the right floor and a run-up from the left) and no bot change hid it:
  phase 4 moved its big spot into the two lips of the floor's hole, and the best spawn now takes 31.0 % of 384
  rounds (+6.0; 30.2 % on a second set) [G80] - measured before the stomp rule of [G93], after which every set is
  played again.

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
6. **Scoreboard** (about 5 s): round wins as drumsticks thrown onto each player's plate. A drawn round scores for
   nobody; three drawn rounds in a row end the match on its standings - the side with the most round wins, or a
   drawn match when no single side leads [G78].
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
with a gold tip and its gust swirl a 3-frame loop downwind; the Mesa Rodeo / Cloud Top proposals are not drawn (cut 3
applied [G60]) and the arena side frames `ui/arena/frame_*.png` wait for a drawing script (E.5).

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
| Lightning bolt (`Sfx.LIGHTNING_STRIKE`: `zones/lightning` in 9-1b, the Storm Roc's phase 3) | MoxieCat "lightningstrike" (an 8-bit noise crash) | trim to 1.5 s (a realistic thunder clashes with the chiptune mix) |
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
| Solo-impossibility proofs | every x2 gate - 45 gates in 76 rows at G3 - by the three proofs [G77]: the search (53 exhaustive, 23 bounded with every probe [G59]), 33 evidence routes that say "not reached", two explorer passes of 300 s per row |
| Boss tests | 6 new bosses + 2 co-op forms |
| Bot matches | every (arena, launch mode) pair the arena supports |

### F.5 The release: 2.0.0

- **Version 2.0.0; Windows is the release target** [G88]: the exe, the zip and the Inno Setup installer
  (`tools/build_windows.ps1`, `tools/build_installer.ps1`, docs/BUILD.md 3). Android, macOS and iOS stay "easy to
  port": their export presets must load in the editor and docs/PORTING.md must be true for 2.0 (two heroes, the
  touch player, pads with new ids on reconnect, the performance budget with a party); an export is made only where
  its toolchain is already in the project, and nothing is installed outside the project for the release.
- **Nothing goes public from an agent** [G89]: no git commit, tag or push and no GitHub release is made by a
  workflow agent. The agents prepare the files and the release text; the orchestrator commits; the owner of the
  game decides on the public release.
- **What only a human can check is not faked** [G90]: mixed-skill pair playtests of every co-op stage and gate, an
  expert told to cheat, the versus modes with people, key ghosting on real keyboards, pads and the reconnect
  dialog, one listen-through of every music pick, an Android device with the `--perf` steps. They are
  `docs/expansion/HUMAN_CHECKS.md`: exact steps, what to look for, one line a person can tick, and the file and
  value to change when a check fails. Everything a tool can measure about them is measured before the release and
  written beside the check. 2.0.0 is built and proven without them; they decide what a 2.0.1 tunes (D.12).

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
went to the owners as `build/engine_requests/wf9_lead_design_to_*.txt`); G44-G56 are the lead designer's rulings on
the reports of phase 3; G57-G62 are the orchestrator's decisions after the failed gate G3 (2026-10-08, the G3
verifier's `wf9_g3_verify_to_*.txt`) and the lead designer's records of them, the painting ladder and the review of
the designers' deviations (sent as `build/engine_requests/wf10_lead_design_to_*.txt`); G63-G69 are the lead
designer's rulings on the builders' reports of that follow-up round (the same files, later entries); G70 is the
G3b integrator's record of the gates he rebuilt under G67 and G69 after the lead designer had closed - no new
ruling, the as-built state and two building facts found on the way; G71-G78 are the orchestrator's rulings R1-R8
after the G3b verifier put ONE hero past 12 of the 45 x2 gates by continuous play (2026-10-09,
`build/engine_requests/wf10_g3b_verify_to_*.txt`) - they close its five causes by rule instead of gate by gate - as
the lead designer recorded them with the as-decided details (sent as `build/engine_requests/wf11_lead_design_to_*.txt`);
G79 is the lead designer's own finding on the way, a sixth cause; G80 records the versus builder's
fairness measurement of that round. G81-G83 are the G3c integrator's records - the coil, the shield, the Levels phase
and the gate job as built - with which gate G3 was passed (2026-10-09, HEAD 1e025e9). G84-G90 are the orchestrator's
phase-4 rulings Q1-Q7 as the lead designer recorded them with the as-decided details (sent as
`build/engine_requests/wf12_lead_design_to_all.txt`), and G91 is the lead designer's register of the values 2.0
ships with. G92 is the lead designer's own measurement of the phase - a feast is a key to a `shell` keeper door,
which the gate proofs do not see - with the rule decided and not yet built; G93 records the three rules the versus
builder's soak asked of the referee.

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
| G33 | The idle partner (orchestrator, phase 3) | G1's "active" rule (input since the last hatch) left the boss rules, plates, bait and the Totem Ride counting a partner nobody plays: one active hero beat the co-op Twin Idols with his idle partner parked on the far half (16 -> 0 hit points, g2_verify); the co-op Tusker could be struck on the rump the same way; an idle carrier gave a lone player a 98 px step (the 5-row Totem ledge fell) | **orchestrator**: a co-op hero is **idle** while his own slot held no input flag for 243 ticks (10 s), or none since he entered the level (level start, join, restart: no 10-s grace); reset only by his own input (an egg's nudge counts), never by a hatch, carry, bump, launch, respawn, checkpoint or team wipe; drawn dozing (Zzz) once 243 quiet ticks passed. An idle hero counts for **no co-op rule**: plate and pulley weight (a mount weighs 2 only with an active driver), see-saw launches, x2 tablet lights, count-ins, trait "nearer hero" rules (shell, keeper bait, lone, Mimic, Shaman), braces, the lee, twin windows, boss position rules, and - lead designer - **no duo move**: no Shoulder Hop and no Totem Ride on or by him (his head is passed through; a ride ends when carrier or rider becomes idle). The team exit counts an idle hero on the view as present (as an egg); checkpoints stay physical. Plain enemy targeting may pick him. Shared query: `PlayerBase.is_idle()` / `counts_for_coop()` (party). The searches place the idle partner anywhere he could be hatched (D.1, D.3, D.4, D.5, D.6, D.8, B.0, P-C.10, P-C.12, G 13.9, LD 15.7) **Built in phase 3**: party (`PlayerBase.is_idle` / `counts_for_coop`, `LevelBase.nearest_coop_hero`, the Zzz, no duo move on or by an idle hero), objects-A (plates, pulleys, see-saw, tablet, drums, boulder, Chomper), enemies-B / enemies-C (every boss rule), world-B (the search's idle partner). **Built at G3** (integration, 2026-10-08, enemies-A's file): `coop_traits.gd` - the `shell` shield faces `LevelBase.nearest_coop_hero` (no counting hero: it keeps its facing), `lone` and the bond / split count-ins count `counts_for_coop()` heroes only; the Shellback (`guard.gd`), the Mimic and the Shaman's flight read the nearer ACTIVE hero too (single-player: `nearest_coop_hero` is `target_hero`); tests `test_enemies_coop` (idle partner no shell bait, no count-in, no `lone` company), `test_integration_g3_idle` rows green; D8's idle-bait replays now leave both Guards and both Shellbacks alive; every keeper gate refused by the search. The record of the phase-3 state follows. **Open (until G3)**: enemies-A's `coop_traits.gd` (the shell's and keepers' facing, `lone`, the bond / split count-ins) still reads every hatched hero - no enemies-A owner in phase 3. The gate search parks the idle partner in front of and behind every keeper and `shell` enemy (world-B's `Searcher.bait_spots`) and refuses every shell keeper hall, but its bound does not reach the whole chain: D8's direct replays (`build/d8/bot_idle_bait*.gd`) open w8_l1_coop 'hall' and w8_l2_coop 'shamans' with one player - the idle partner placed in front of each keeper, the striker behind it - and fail without the bait. So the shell keeper halls (also w2_l1_coop 'den', w3_l1b_coop 'hut', w5_l1_coop 'gully') are **open on the engine** until `coop_traits.gd` faces the shell to `LevelBase.nearest_coop_hero` (keep the facing when there is none); the designs stand - they hold the moment that line lands. world-B's `test_search_idle_bait_keeper_replays_follow_g33_shell_facing` replays the idle-bait kill at every shell keeper of the gate table (KNOWN lines today) and asserts its failure once the fix lands. |
| G34 | Boss co-op forms by actions (orchestrator + lead designer) | position rules ("on its half", "the nearer hero", "a hero other than the striker") are satisfiable by a parked body; a twin capped at `solo_min - 4` left Old Mangrove 6 ticks for a pair although one hero can never twin it (enemies-B #1 / #2) | **decided**: wherever the design allows, two heroes' own actions satisfy the co-op rule: Mangrove twin and Inkjaw flinches by two different heroes (as built), the Twin Idols' twin struck by the OTHER hero (new), the Roc's tail strike by a hero other than the pilot (as built), the Brute's last hitter, the Brace Wall; position rules count only active heroes (Tusker, Mangrove pin and knuckle, Idols' halves, Roc wing shield, Chieftains' hold-off, Brute's first target, Colossus plates). A slot-bound rule is **exempt from the solo_min cap**: Mangrove twin 24 B / 12 E, Inkjaw flinch 24 B / 16 E, Idols twin 24 B / 12 E. Every boss search adds an idle hatched partner (B.0, B.2-B.7, D.4, G 13.6, G 13.9.3, PLAN V3.d) Built in phase 3 by enemies-B and enemies-C (tests `test_enemies_<boss>.gd`: one hero's two hits never twin; the single-hero searches with an idle partner placed anywhere). |
| G35 | Boss weak points under the HUD (orchestrator, G2 report) | Old Mangrove's face was drawn behind the GRUBS letters and cut by the view's top in `w6_l2b` (g2_verify) | **orchestrator**: every rectangle a counted hit must touch lies wholly in the locked view, in every strikable pose, at least 24 px (logical; 48 art px) below the HUD band over its columns. The band is the fight HUD ui built in phase 3 (`Hud.band_rects`: in co-op the letters give way and P2's panel moves up while a boss bar shows): the top row, 31 px deep on touch devices (27 on a computer), and the boss bar's columns (53 px left to 38 px right of the view's centre) down to 48 px - so a weak point's top is 55 px under the view's top, 72 px in the bar's columns (with the floor on the last row of an 11-row lock: at most 105 / 88 px over the floor). ui's clearance constant moves from 24 art to 24 logical px. Measured: Old Mangrove's face 112-141 px over the floor - at most 105 (`MANGROVE_FACE_RISE` <= 70); its hand resting on a row-4 ledge - the upper ledge goes to row 5 (ending at col 5), the lower stays at row 7; the Chieftains on a 6-tile altar in the bar's columns - the altar 3 tiles up. The Twin Idols' open jaws (65 px), Tusker, Inkjaw, the Roc (84 px over its nest) and the Brute are clear; the visor Colossus' co-op hall is checked like the Idols. Each boss test pins it with `Hud.weak_point_problem` (B.0, B.2, B.4, B.6, B.7, A.6, G 13.6, LD 15.6) |
| G36 | Bonded pairs (orchestrator, G2 report) | a bond whose members one thrown special hits in one throw measures `pair_solo_min` 0 (D6: bonded frog / Puffcap pairs on flat floors cannot be built; axes and spears pass walls and fly about 520 px) | **orchestrator**: never place such a pair - separate the members by height so that no throw line from any strike spot of one member crosses the other, or use another trait (`lone`, `daze`); a 0 from the search is a build error, not a short window; A.6's "bonded ... pairs" are suggestions under this rule (A.6, D.6, D.8, LD 15.7.5) Built in phase 3 by world-B: `CoopSearch.pair_solo_min` and the validator name such a bond or drum pair as an error. |
| G37 | Cut list (orchestrator, phase 3) | the schedule of phase 3 | **cut 2 applied**: the tablet table mode stays an experimental, hidden prototype (touch = one touch player + pads; P4.3 drops its device test); **cut 3 conditional**: Mesa Rodeo and Cloud Top are built only once Floe Rink, Tar Pulleys, Sky Picnic and Colossus Hall are done and their bot tests green (0, D.11, E.5, E.9, G 13.9.1, G 13.10.1, PLAN 7 / 9). **Superseded by [G60]**: cut 3 is applied - Mesa Rodeo and Cloud Top are not in 2.0. |
| G38 | Tusker's arena and the co-op phase 3 (G2 report, enemies-B / D5) | B.1's 4-cell banks and 6-cell wallow kept the 76 px boar in the mud; the co-op phase-3 charge still sticks in the wallow (g2_verify) | **accepted as built**: banks 3 cells wide at cols 1-3 / 16-18, 3 rows up; a 4-cell wallow at cols 8-11. A co-op phase-3 charge across the wallow may still stick (rump open from behind only, facing the nearer active hero [G33]); at the walls only a Brace Wall stops it (B.1, G 13.6) |
| G39 | Boost ledges on Beginner (G2 report, D5) | G28 made boost ledges 8 rows on both difficulties, but GAMEPLAY 13.9.10, D.10 (5-1) and `PartyTuning.BOOST_LEDGE_TILES_BEGINNER` still said 7 | **confirmed**: 8 rows over every floor within reach on both difficulties; R18's Expert-only column is retired; the Beginner constant becomes 8 (core-A); the way back is a rolled vine (D.10, D.11, G 13.9.10, LD 15.7.3) **Built at G3** (integration): `PartyTuning.BOOST_LEDGE_TILES_BEGINNER = 8`, pinned by `test_core_expansion` (and `PartyTuning.IDLE_TICKS = 243`, G33). No code reads it (the validator and the search measure ledges themselves); every co-op file already followed the 8-row rule. |
| G40 | Confirmations of the G2 reports | snapper co-op bait-and-bite, the versus stomp, 6-1's hammer on a raft, Inkjaw's phase-3 slam reading, the bosses' telegraph lengths | **confirmed**: bait-and-bite stays dropped [G10] (co-op snappers keep the 1.0 rules; twin rattlers use `bond`); a versus stomp is a landing [G15], built and tested by world-B (`test_a_stomp_is_a_landing`); items do not ride rafts, so 6-1's hammer lies on a jetty beside the raft (A.6, objects-B #3); Inkjaw's phase-3 slam shakes and hurts nobody, the rafts overlap by 9 px; the telegraphs as pinned by the boss tests (D.6, A.6, LD 15.8) |
| G41 | The lee gap (G2 report) | the validator has no lee-gap check; a lee gate is proven only if the search runs the wind | **kept as a gate kind**: gust gaps of up to 3 cells whose gusts never pause, a crouching spot within 64 px downwind of each far edge; only an active croucher shelters (a crouch is input) [G33]; the search decides, the fallback is a Brace corridor (9-2) - and the fallback is used if world-B's search world does not run the level's wind; the validator warning stays optional (LD 15.5, LD 15.7.3) Built in phase 3 by world-B: the search world runs the level's `wind` / `wind_loop` (`SearchWind`), so a lee gate can be proven; the validator warns on a gust gap without a crouching spot. **Superseded by [G55]**: the lee is no gate. |
| G42 | The rising-scroll camera (G2 report, follows G32) | G32 made "every jump lands higher" a building rule because the view chases a jump's apex and never sinks; a jump in place on a climb ledge (to strike a bat) is then an unfair death | **engine change, built in phase 3 by world-A** (`LevelCamera.footing_mode`; `tests/test_world_book2.gd` `test_the_rising_view_follows_the_footing_not_a_jump`): in a `scroll = rising` level the view rises for a hero's footing (his feet on the last tick he had ground, a platform, a carrier or a vine under them), never for a jump's apex; it still never moves down and rises at least with the band. G32's building rule is retired: a jump in place on a climb ledge is fair; a climb never steps down more than 2 rows under the highest footing reached (P-C.8, LD 15.5). 6-2b's routes are re-recorded on it (D6) |
| G43 | Arenas as built and Colossus Hall (G2 report, DA) | E.5 still drew the G1 sketches; Colossus Hall's "crowned leader" does not exist outside Grub Stack | **written in**: E.5 draws Totem Ring, Cinder Pit, Echo Hollow and Coconut Cove as built [G31] and LD 15.8 carries DA's lessons; Colossus Hall plays Grub Stack (the crowned leader) and Last Caveman Standing (the hero with the most hearts; a tie: no spit), no Hot Rock or Clubball; the statue is a neutral picture that takes no hits (E.5, LD 15.8) |
| G44 | Book I co-op as built (DB3, phase 3) | 3-2's two gates, 4-2's "spike column" and the Way Home lookout needed a concrete form | **accepted**: 3-2 puts both gates at the leaper lake (the line drive over 9 cells, 8 on Beginner through a `beginner` floe column on the near lip; drums on both banks freeze the floe bridge for the batter), each with its own tablet and `far`; the Feast Land C warp and painting 26 share the 8-row crystal cache; 4-2's drum bond raises a portcullis for good; the Way Home lookout is a gallery 8 rows over the road with a latch plate 9+ cells from the door, also the x2 secret of painting 29 (D.9) |
| G45 | Railed raft at the beach (D9b, phase 3) | with `rails` a rider is fenced to the raft for good, so "the home beach is the exit" of `ending_b` could not be built; a railed rider fell into the water at the bow (the halved-width ride overlap) | **decided**: when a railed raft is stopped by a bank, its fence opens on that side over the bank's floor and the riders walk off (their floor contact unrails them); the ride test carries a railed rider over the whole fenced width - objects-B (A.6, P-C.7) **Built at G3** (integration, objects-B's files): a railed raft carries its rider over the whole fence (`PlatformBase._carries_fenced`, `Raft._carries_fenced`: no bow strip), and a raft at rest against a bank opens its fence 4 tiles over that bank (`Raft._fence_left` / `_fence_right_excl`); `test_objects_book2` `test_a_railed_raft_carries_to_the_bow_and_opens_at_a_bank`. `ending_b` still has the jetty totem (D9b's file; moving it onto the beach is the open content step). **G3 follow-up** (content, wf10): the welcome totem stands one cell up the beach (col 173), the routes are re-recorded; the fence opens only for a raft AT REST, so the last current ends one cell short of the bank (a current over the docked raft's anchor kept it moving and the fence shut) - the raft drifts its last pixel and rests; a 7 px strip between the closed fence's line and the deck's end still carries nobody once the fence is open (a rider who stops there drowns) - the ride test must carry him over the whole deck up to the bank's edge (P-C.7; objects-B asked in `wf10_content_to_objects-B.txt`). **Fixed in the follow-up round** (party, `raft.gd` `_carries_fenced`): a railed rider is carried over the whole deck, x in [centre - 8 * width, centre + 8 * width), so a rider who stops in the docked deck's last 7 px stands (content's repro on a snapshot of the tree: grounded, nobody drowns - the Long Raft Home has no failure state again); the walk-off moved by one tick and content re-recorded `ending_b.inputs` (2 892 ticks). In the same change the raft's drag clock gets its slept ticks back when it wakes (D6's wf9 report: a dozing raft's clock stood still), so a raft's home needs no one-cell eddy any more (LD 15.5); that changes the game with dozing - a raft paddled after a doze used to drag on other ticks - and moved six Book II solo routes, which party re-recorded with D6's and D7's bots (`w6_l1` Beginner, Expert and painting, `w7_l1` Beginner, Expert and warp; headers kept); Book I has no raft. Tests: `test_world_book2` `test_a_docked_railed_raft_carries_its_rider_over_the_whole_deck`, `test_a_rafts_drag_clock_counts_the_ticks_it_dozed`, `test_a_beached_rafts_clock_stands_still_asleep_as_awake` (party's proof). |
| G46 | The Storm Roc's phase-3 cruise (enemies-C, phase 3) | the glider dive's target, the Roc's back, cruised at the nest's centre with its feet 40 px over the nest top: its top 44 px under the view's top - inside the boss bar's columns and 11 px short of the HUD row's clearance; a lower cruise over the nest would run into heroes standing on it | **decided**: in phase 3 the Roc cruises over one runway half only (out of the boss bar's columns and off the nest by a cell), its feet about 61 px over the floor (29 over the nest top), so its back's top is 55 px under the view's top; heroes on the floor keep 26 px under it; it swoops and climbs out as before; the co-op tumble over the nest is clear already (B.5, G 13.6) Built in phase 3 by enemies-C (`roc.gd`: the halves alternate, the right one first; `tests/test_enemies_roc.gd` pins the back with `Hud.weak_point_problem`). |
| G47 | The daze trait is slot-bound (integration's coop_gates run, phase 3) | the search measured that one hero strikes a Raptor he dazed himself 8 ticks after his bounce in a 4-row hall (`w2_l1_coop` 'den'), so the daze would have to shrink to 4 ticks - unplayable for a pair and fragile wherever Raptors keep a hall | **decided** (the orchestrator's actions principle, G34): a dazed `daze` enemy can be hurt only by a hero of another slot than the one whose head bounce dazed it - the bouncer's hits glance; so a lone player (an idle partner never strikes) can never kill it, and the daze keeps 14 B / 12 E, not capped by the solo minimum; `window=` on daze records is no longer needed. enemies-A builds it (`coop_traits.gd`), world-B's search and integration's window check treat the daze as slot-bound (D.6, D.8, D.11, G 13.9.5, LD 15.4) **Built at G3** (integration, enemies-A's file): `CoopTraits` remembers the bouncer's slot and hits of that slot glance while dazed (`test_enemies_coop` `test_the_daze_is_slot_bound`; `CoopSearch.daze_slot_bound()` now reads true, so daze records are slot-bound in the search). |
| G48 | Book I co-op as built (DB1, phase 3) | 2-1's Raptor keepers could not be a gate with a daze capped at the measured solo minimum (8 - 4 = 4 ticks); 1-2's tree house, pulley, warp cage, leapers and treetop cache needed concrete forms | **accepted**: 2-1's 'den' keeps two Shellback turtles as keepers (Raptors may return there once the slot-bound daze of G47 is built); 1-2's tree house is the 5-row Totem ledge (a gate only with G33's active carrier; a rolled vine of 5 is the carrier's way up), the trunk-room pulley a counterweight hop (A on the counterweight pan, B hops while the lift rises, a ledge 11 rows over the shaft floor, a rolled vine back for A), the Feast Land A warp in a cage whose door the drum bond 'nest' raises (drums 15 columns and 6 rows apart), the bonded leapers two dragon leapers in two pits one row under the deck top, the treetop cache 8 rows up for a charged lob (a 7-row lob ledge falls to one player since G28); 2-1's x2 secret the Deep Pantry behind 8 cells of black water. Feast Lands A / B: the giant-roast twin rule (G 13.9.8) was built in phase 3 by objects-A (party); `bonus_a_coop`'s routes are re-recorded with twin strikes (DB1) (D.9) **Follow-up round** [G68]: 1-2's trunk-room gate is no pulley any more (a 7-row pulley parted the pair by 14 rows) - 'shaft' is an 8-row boost ledge with a plate on it that drives a lift stone; its leapers are no bond. |
| G49 | Boss objects are no gates (DB3, phase 3) | the validator counts the visor Colossus's chain plates (B.7) as a co-op mechanism that needs an x2 tablet and warns that they drive no column, so `w4_l2b_coop` cannot validate; a dummy tablet would be a "gate" the search refuses that is no gate | **decided**: in a co-op file the `objects/plate` records inside the `zones/arena` of a `bosses/colossus` record that drive no column are the boss's chains (the left-most and the right-most are the two the boss reads), not a gate mechanism: no x2 tablet, no "drives no column" warning; fewer than two of them is a validator error (the co-op form would be lost without a word). A boss stage's co-op form stands in for its gate (D.8 #1). world-B builds the validator rule (LD 15.7.4) Built in phase 3 by world-B (validator); `w4_l2b_coop` landed clean with its route (DB3). |
| G50 | Human-only arenas: the switch of cut 4 (DA, phase 3) | PLAN cut 4 ("an arena whose bot graph fails ships human-only") had no switch: `test_versus_bots` plays every `levels/arena_*.lvl` in every mode of its `modes`, so a failing arena could only stay out of `levels/` | **decided**: arena meta `bots = <mode list>` or `none` (default: every mode of `modes`) names the modes in which bots play that arena. The validator accepts a subset of `modes` (or `none`); `test_versus_bots` plays only those (a skip line for the others); the versus setup offers the arena in another mode only while every seat is human (no CPU seat; Party Mix and a bot-filled match skip it); the G3 table lists a mode left out as "human-only (cut 4)", neither green nor red. Until the switch is built (world-B validator, core-B test, ui-A / core-A setup), an arena whose bot set is not green stays out of `levels/` (DA) (E.5, LD 15.2, LD 15.8) **Built at G3** (integration): `test_versus_bots` skips an (arena, mode) outside `bots` with a "human-only (cut 4)" line (and awaits a frame per round, sharded by `VERSUS_BOTS_SHARD`, `tools/g3_versus_bots.sh`); `VersusMatch.bot_modes` / `cpu_seated` - Random and Party Mix skip a humans-only arena / mode while a CPU is seated. **Tar Pulleys ships human-only** (`bots = none`: its displaced pulley lifts strand the bots, wf9_da_to_core_b.txt #1). Coconut Cove's Clubball bias was the ball's floored x step: `Coconut.physics_step` now moves |xvel| / 16 signed and reflects x towards zero (mirrored shots rest at mirrored x, `test_objects_versus`); the cell reads 48 / 52 %. |
| G51 | Floe Rink's floes and the bots (DA, phase 3) | core-B's baker keeps one link state per rider mover, so after a see-saw's first flip a bot on it finds no link and stands there (idle 250-2300 ticks on every Floe Rink layout with both plank ends safe); DA's bot-safe stopgap lays the whole plank over the icy water, so a hero landing on the high end is tipped into it within 2 ticks | **decided**: no arena part kills the hero who uses it as meant without a 10-tick telegraph (LD 15.8): an arena see-saw keeps both ends over standable ground, never a liquid cell. Until core-B bakes a rider mover's links for every state (or a bot stranded on a mover walks off it), Floe Rink ships without see-saws: two fixed floes where the planks were (any standable ice over the water, placed by DA), the alternating gusts towards the open sides as its signature (the Whiteout grows them); the fling floes of E.5 return when the bots ride them. A layout whose bot set is still red stays out of `levels/` (G50) (E.5, LD 15.8). **In 2.0** [G60]: Floe Rink ships Grub Stack only, with its fixed floes. |
| G52 | Inkjaw's fire-starter lost in the water (D7, phase 3) | the squid dies surfaced in a gap; `BossBase.defeat()` throws the fire-starter from over that gap's water, and a sunk key item returns to that same point and falls in again - the exit of 7-2b can never open | **decided**: a boss's key item is never lost - Inkjaw throws it from over the island nearest to where it died (its `_drop_origin()`, as Old Mangrove's [G30]), and a key item that sinks anywhere comes back on standable ground (enemies-B). D7 may close the grotto's outer 1-cell water strips (cols 1 and 18 become island ground: islands 1-5 and 14-18); the gaps 6-7 / 12-13, the middle island and phase 3 stay as G 13.6 draws them (B.0, G 13.6) **Built at G3** (integration, enemies-B's file): `Squid._drop_origin()` - the drops leave from a cell over the island ground nearest to its spot, so a sunk fire-starter returns onto ground (`test_enemies_squid` `test_the_key_item_is_thrown_from_over_the_nearest_island`); the four w7_l2b routes pass `test_book2_routes` / `test_coop_routes` with it. |
| G53 | The idle doorstop (world-B's search, phase 3) | a plate door "never moves into a hatched hero (it waits)": a lone player hatches his idle partner with 4 px of his body over a hatch slab's column, presses the plate, and the risen slab cannot close while the body stands there - `w2_l1_coop` 'hatches' falls to one player on both difficulties (the search found it on Expert) | **decided** (G33's "counted by no co-op rule" extended to bodies): an idle hero **blocks no mover** - a plate door, column, slab or heave boulder that would wait for a hero does not wait for an idle one; it moves as if he were not there and pushes him out of the cells it fills, unharmed, sideways to the nearer free side (up onto its top when neither is free). Active heroes keep the 1.0 wait. Single-player is untouched (nobody is idle there). objects-A builds it (`RisingColumn`, `HeavyBoulder`); no content change needed (P-C.10, G 13.9.7, LD 15.7.9) **Built in phase 3** by objects-A (party): `ObjTuning.hero_in_cell` counts only heroes who count, `ObjTuning.push_idle_out` moves an idle body out (`tests/test_objects_idle.gd`); world-B's `probe_hatches.gd` and `test_search_idle_doorstop_route_follows_g53` pin it. |
| G54 | A head under the crown (D9b, phase 3) | G35 keeps the Chieftains' altar 3 rows up under a crown whose underside is 6 rows over the floor; a hero standing on or bouncing off a chieftain who stands on a ledge or the altar has his head 22 px inside the crown's rock - juggled there for 170 ticks, or lifted into the rock and leashed (both seen on hero physics) | **decided**: a body is never a step into rock. When standing on, riding or bouncing off a head (an enemy's, a boss body's or a hero's) would put a hero's box into a solid cell, he slides off that head instead (to the side away from the rock, else the nearer side) and the bounce is cut to the free room under the ceiling; no corner slip ever lifts a hero into a solid cell. Single-player is untouched (no Book I head stands under a ceiling closer than a hero's height). player-A (the hero side) and enemies-C (the chieftain bodies) build it; the altar and the crown stay (B.6, P-C.10) **Open at the end of phase 3**: player-A did not build the hero-side guards (the Totem / body ride, the head-bounce clamp, the corner slip - each needs its own replay proof to keep 1.0 identical); D9b's routes avoid the case. On the auto-scroll's zigzag ledges of `w4_l1_coop` a falling hero is lifted onto his partner's head into the ledge above; DB3's route keeps the partner a ledge behind (24 ticks), never under or over him (a co-op copy may also make such an overhanging ledge one-way or shift it; the solo file stays frozen). **Built in the follow-up round** (party; in the tree since 18:37 on 2026-10-08, before the power cut): the hero-side guards of `player_base.gd` - `bounce`, `land_on_partner`, `carry_totem`: a bounce, a Shoulder Hop, a Totem Ride or a carry whose place would put the hero's box into a solid cell is refused or cut to the free room, and he slides off the head to the free side (at most 64 px, `G54_SLIDE_MAX_PX`) - with `tests/test_player_g54.gd` (the 9-3 crown, the 4-1 zigzag ledges, a carrier jumping under rock, the 1.0 bounce unchanged where there is room; 9 / 9 in the lead designer's run on the resumed tree). By party's A/B over all 158 route digests Book I solo is untouched (`tools/sp_identity.sh` IDENTICAL: no Book I route meets a guard) and 11 Book II / co-op routes moved from their first guard on; they were re-recorded by the round's owners - `w9_l3.inputs` (the solo Chieftains: a head under the crown), `w2_l2b_coop` (both), `w7_l2b_coop.expert`, `w9_l3_coop` (bosses), `w3_l1_coop` (both), `w6_l1_coop.expert`, `w9_l2_coop` (enemies-A), `w5_l1_coop.expert` (content) - except `w3_l2_coop.inputs`, which party claimed and which was **open at the lead designer's close**. DB3's and D9b's route workarounds are no longer needed but stay valid. |
| G55 | The lee is no gate (DB2, phase 3) | the lee shelters only a hero standing within 64 px downwind of an active croucher, and the croucher must already stand past the gap - so the FIRST hero crosses unsheltered, in a lull or with a tailwind, and a lone hero can do the same; with gusts that never pause nobody crosses first | **decided**: the lee gap is retired as a gate kind (G21's lee leapfrog stays a co-op comfort, taught by a sign; G41's search question is moot). 3-1b keeps its one gate (the Shellback keeper hall), 9-2 its line drive and Brace corridor. DB2's lesson for Brace corridors is in LD 15.7.3: the heroes enter while the heavy is not pressing at their way in, on a flat braced floor (D.9, D.10, A.6, LD 15.7.3) |
| G56 | The co-op Brute's leaps and the HUD (DB2, phase 3) | w2_l2b_coop's routes broke G35 in the settled den view for 11 ticks: the head flew from 211 to 92 (view top 112) - under the HUD band, then cut off by the view. DB2 first read it as the very high jump (`BRUTE_HIGH_JUMP_YVEL` -224, about 119 px); its probe then showed the death leap after the lethal blow (`BRUTE_DEFEAT_YVEL` -240, state DYING) - `boss_defeated` is emitted only when that leap tops out, so the route check still tested the head. No geometry can help (a 180-px view that shows the den floor allows a 44 px rise, 27 in the bar's columns; the Brute's rise ignores ceilings) | **decided** (G35's "in every pose in which it can be struck"): (1) **a boss after its lethal blow has no weak point** - every boss, every form: it takes no hit while dying, so its weak rects are empty from the lethal blow on (the Brute: `get_head_rect()` empty while DYING); (2) in the co-op form the Brute's head is also **no weak point from the high jump's take-off to its landing** - a club cannot reach it there and a thrown special glances as off the arm guard (no damage, no last-hitter change); `get_head_rect()` returns an empty rect in that pose, so `Hud.weak_point_rects` and the route check see none. Both moves stay the 1.0 moves (height, hang time, landing shake), the solo Brute plays as in 1.0, DB2's routes stand (DB2 also moved the co-op Brute's limits to 43 / 58 so the head stays inside the den view at both limits). The exemption (2) covers only a leap that lands within about a second; a weak point that rests, attacks or can be struck out of the clear zone still breaks G35. enemies-C builds it in `brute.gd` and pins both poses in `test_enemies_brute.gd` (B.0, B.7, G 13.6) **Built at G3** (integration, enemies-C's and ui's files): `Brute.get_head_rect()` is empty while DYING (every form) and in the co-op form from the high jump's take-off to its landing; `Hud.weak_point_rects` returns none for a boss at hp <= 0 (every boss); `test_enemies_brute` pins both poses; `w2_l2b_coop`'s routes pass the G35 check. |
| G57 | Heavy keepers and one hit per strike (orchestrator, G3 verifier #1-3) | `w9_l2_coop` 'brace' (Expert) fell to ONE hero: the woken Bull Rex charged left and ran UNDER the jumping hero (a 4-row hall is no bar to a short heavy), he landed behind it and its back accepted the club - 7 of 180 continuous-play timings reached the far cell, 22 killed the keeper. And one club strike hit on EVERY tick its box overlapped (`EnemyBase.take_hit` kept no per-strike memory: hp 100 -> 75 -> 50 -> 25 -> 0 -> -25 in ticks 68-72), so `hp` protected no keeper: copies with hp 50 / 100 fell the same way, and `w3_l1_coop` 'lake' lost its Bull Rex keeper to one hero in 21 of 180 timings on both difficulties | **orchestrator**: (1) an enemy with the `heavy` trait - the Bull Rex and every heavy keeper - can be **damaged only while staggered by a Brace Wall** (two active heroes braced, D.4): while that daze lasts (44 ticks) hits from any side count; every other hit glances - front, back, from above, a thrown special, a ball, a head bounce. (2) **In co-op files one strike damages a given enemy at most once** - one hit per strike instance: a club swing for every tick its boxes stay out, a thrown special for its whole flight, a Batter Up ball for its flight (as before), a head bounce - so `hp` counts strikes (a 100-hp keeper takes five club strikes: hp / 25 + 1, the 1.0 death rule [G63]; the first record of this row said four). Bosses keep `BOSS_HIT_COOLDOWN`. Solo files - Book I and Book II - keep the 1.0 hit test: single-player is untouched (`tools/sp_identity.sh` IDENTICAL). enemies-A builds both (`EnemyBase` / `coop_traits.gd`, co-op parties only); whoever changes the behaviour re-records every route it breaks (D9a's `w9_l2_coop`, DB2's `w3_l1_coop`, any co-op route that killed a multi-hit enemy with one swing); world-B re-runs 'brace' and 'lake' under [G59] with the hop-over and charge-under probes. Designers: a heavy is a brace gate wherever it stands - give every Bull Rex a flat floor where a pair can brace in its charge path (LD 15.7.3); one daze may not be enough for its `hp` (it wakes, turns and charges again) (D.4, D.6, D.7, D.8, P-C.10, G 13.9.3-13.9.6, LD 15.7.3, LD 15.7.5) **Built in the follow-up round** (enemies-A, wf10, `enemy_base.gd` / `coop_traits.gd`, co-op parties only): a heavy accepts a weapon hit only while `CoopTraits.dazed` (the Brace Wall's daze; an idle partner never braces) and dies of nothing else meanwhile - no kill-all, grenade, feast or mount bite, glider dive (`CoopTraits.refuses_death`); a glancing blow still gives the striker his pogo. One hit per strike: `EnemyBase._repeats_strike`, keyed per slot by `CoopTraits.strike_key`. The G3 verifier's solo attacks now fail (`brace_try.gd`: 0 kills, 0 far-cell wins, G3 22 / 7; `heavy_try.gd` 'lake' 0 kills on both difficulties, G3 21); re-recorded: `w9_l2_coop` (a real Brace Wall now - the old route clubbed the keeper's back), `w3_l1_coop` (both; five hits in one 44-tick daze), `w2_l2_coop`, `w4_l2_coop`, `w6_l1_coop` (Beginner); `w6_l1_coop.expert` still red when enemies-A reported (a split Tar Splitter's halves under one hit per strike). The search verdicts for 'brace' / 'lake' are world-B's (G59). |
| G58 | The idle partner's warning (orchestrator, G3 verifier #4) | signs said "Stand on a plate to hold its door open" (SIGN_COOP_W1_PLATES and others), but a holder who stood still 243 ticks became idle, the plate let go and the door shut on his partner; the Zzz showed only after the plate had released; D.3's "a human partner who must wait long at a plate crouches" was said nowhere in the game | **orchestrator**: `IDLE_TICKS` stays **243**. **Held keys count**: a flag held is the hero's own input on every tick it is held (as built: `PlayerBase.note_own_input` resets on `GameInput.get_flags(slot) != 0`), so a partner crouching on a plate (Down held) stays active however long he waits. A **"Zzz soon" warning bubble** shows over a hatched living hero from his **170th** quiet tick until the 243rd, then the Zzz: 73 ticks (3 s) of warning; drawing only (the simulation never reads it; an untouched partner gets it on the same count). **Every co-op sign that teaches a hold plate says to crouch** ("Crouch on a plate to hold it"). party (player-A, `hero_party.gd`) draws the bubble (`PartyTuning.IDLE_WARN_TICKS = 170`, core-A; a private constant until it lands); each locale file's owner rewords its plate signs (`coop_b1.po`, `coop_b2.po`, `coop_b3.po`, `w5.po`, `w7.po`, `w8.po`) (D.3, P-C.10, P-C.16, G 13.9.2, LD 15.6, LD 15.7.9) **Built in the follow-up round**: the held key already was input on every tick (now pinned by `test_player_idle` `test_a_held_key_is_input_on_every_tick_it_is_held` and `test_a_partner_crouching_on_a_plate_holds_it_and_one_who_just_stands_lets_go_at_243`); party draws the warning (`hero_party.gd`, `IdleMark` mode WARNING: one small "z" in a thought bubble with two trail dots, pulsing, twice as fast in its last second - it reads as "about to doze", not as the doze; `test_the_zzz_soon_bubble_shows_from_the_170th_quiet_tick_and_the_zzz_from_the_243rd`, `test_an_untouched_partner_shows_the_same_bubble_from_his_170th_tick`, `test_the_warning_bubble_is_a_picture_only_an_egg_shows_none`; 21 / 21 in the lead designer's run); `IDLE_WARN_TICKS` = 170 is a private constant of `hero_party.gd` - `PartyTuning.IDLE_WARN_TICKS` waits for a core-A owner (none ran in the round); every plate sign of the list says "crouch" (`coop_b1.po` by DB1 before the power cut; the ten of `coop_b2` / `coop_b3` / `w5` / `w7` / `w8` and the pulley sign of `w9.po` by party in the resumed run - "Crouch on one lift to weigh it down. Your partner hops his up!"; `docs/spec/test_spec_docs.py` asserts each); the route proofs check the idle rule on every tick of every two-stream route (integration, `RouteTestCase._check_party_idle`: no living, hatched hero's quiet ticks reach 243; all 52 files pass, the longest quiet stretch 209 ticks). **At G3b** (the integrator, for the core-A owner who did not run): `PartyTuning.IDLE_WARN_TICKS` = 170 is in the table beside `IDLE_TICKS`; `test_core_expansion` pins it and its equality with `HeroParty.IDLE_WARN_TICKS`, which draws the bubble. |
| G59 | What "refused" means (orchestrator, G3 verifier) | the cached "76 / 76 refused" was a 220-resting-point bound: 68 of 76 searches stopped AT the bound (64 of 76 still did at 660), so "refused" mostly meant "not found yet"; an uncached 3x bound reached `w9_l2_coop` 'brace' | **orchestrator**: a refusal names its evidence. Per gate and difficulty the gate table prints one verdict: **refused (exhaustive)** - the search's frontier emptied below its bound (every resting point it can reach was expanded: `w4_l1_coop` 'cliff' at 11 of 660), or the static reach rule shows that no chain of feet cells reaches `far`; **refused (bounded)** - the raised bound (at least 660 resting points, uncached) was hit AND every continuous-play probe of the gate's type failed (no world reset between moves, the real hero and entities, swept over timings): **hop-over** (jumps and bounces over or onto every keeper, Guard and heavy of a hall), **charge-under** (a heavy woken and baited to run under a jumping hero, who lands behind it and strikes), **idle-bait** (the idle partner parked in front of and behind every keeper and shell enemy, on every plate, in every door's and boulder's way), **thrown-special and plates** (every special thrown from every spot the lone hero reaches at drums, bond members and keepers; every plate door raced against its real column - off the plate and through before it closes - and every `timed:` clock); **open** - any search, probe or replay reached `far` (red, cause named). A bounded verdict without its probes is **unproven** - neither green nor red. The probes per gate type are LD 15.7.6. world-B builds the probes and the verdict lines (`tests/test_coop_gates.gd`, `tools/world_coop_gates.sh`); integration's G3 table carries them (D.8, PLAN V3.c, LD 15.7.6) |
| G60 | Cut 3 applied; the painting ladder; Echo Hollow, Floe Rink, Tar Pulleys (orchestrator + lead designer) | [G37] kept Mesa Rodeo and Cloud Top conditional; G3 shipped 8 arenas; Echo Hollow's regrowing `$` walls and dangler springboard broke spawn fairness in every placement; Floe Rink's Last Caveman Standing reached no fair layout; Tar Pulleys' displaced lifts strand the bots; the 5- and 20-painting rewards were those two arenas | **orchestrator**: **cut 3 applied** - Mesa Rodeo and Cloud Top are not in 2.0 (8 arenas); Echo Hollow drops its regrowing walls and its dangler springboard (the darkness pulse is its signature; the referee's `regrow` and neutral-enemy rules stay unused); **Floe Rink ships Grub Stack only** (`modes = grub_stack`, with bots); **Tar Pulleys** gets bots only if core-B's pulley links (a lift's links baked for every state it can stand in) make its bot tests green in its modes, otherwise it ships human-only (`bots = none`, as at G3). **Lead designer - the painting ladder** (PLAN cut 3: "those painting unlocks become variants and colours"; nothing new to draw, nothing open from the start becomes locked, a reward every 5 paintings): **5** = four loincloth patterns (checks, dots, tiger, pinstripes); **10** = four more (diamonds, waves, sash, trim); **15** = Big Bounce, Lights Out, Giant Rain (unchanged); **20** = the Spear Party variant; **25** = the golden loincloth palette; **30** = the mural (unchanged). Reward ids: `patterns`, `loincloths`, `variants`, `spear_party`, `gold`, `mural`. core-A builds the table (`UnlockTable.REWARDS`, `Tuning.PAINTING_UNLOCK_*`, `Save.UNLOCK_*`, no locked arena in `VersusMatch`), art-A the pattern tags (`hero_palettes.json`: the first four `paintings_5`) and the slab's reward icons, ui-B the reward texts (C.9, E.5, G 13.7, G 13.10.8, G 13.10.9, LD 15.1, LD 15.8, PLAN 9) **State at the end of the follow-up round**: cut 3 is applied in the documents, in the arena files (content: Echo Hollow and Floe Rink say so in their comments, graphs re-baked with the same nodes and links, their sets green) and in the G3 table (integration: 8 / 8 arenas). **The painting ladder is not built**: no core-A, art-A or ui agent ran in the round and integration's task named its own files only - the game still lists the two cut arenas as its 5- and 20-painting rewards (they unlock nothing that exists); `docs/spec/test_spec_docs.py` skips its two code checks as pending and the G3 table prints them as "not built". **Tar Pulleys**: core-B's pulley links are in (links at every still state of the pulley for every weight class, the links that pass a lift's column carry the states they hold in, the bake runs in frames - the crash was the engine's callback queue; 2 666 links). With the bots forced on (48 rounds per set, core-B's numbers on a snapshot): Grub Stack 19 / 38 / 23 / 21 % and Hot Rock 21 / 33 / 23 / 23 % are green, Last Caveman Standing 6 / 29 / 48 / 15 % is red on spawn fairness only (the right-hand pair meets first; no bot idles past 10 s any more). So under [G50] the arena may ship `bots = grub_stack,hot_rock` with Last Caveman Standing human-only - and it does: content landed the file with that meta and its re-baked graph (8 nodes, 2 666 links) at 22:41 on 2026-10-08; the table's row and the versus flow are integration's to regenerate. **The painting ladder, built at G3b** (the integrator, for the core-A, art-A and ui owners who did not run): `UnlockTable.REWARDS` is `patterns` 5, `loincloths` 10, `variants` 15, `spear_party` 20, `gold` 25, `mural` 30 (`Tuning.PAINTING_UNLOCK_*`, `Save.UNLOCK_*`); no reward names an arena and `VersusMatch.LOCKED_ARENAS` is empty, so every arena card is open on a fresh profile; `hero_palettes.json` tags checks, dots, tiger and pinstripes `paintings_5` and the other four `paintings_10` (the pipeline's `build_hero_palettes.py` too); `ui/unlock_icons.png` and the marks carved into `ui/painting_slab.png` are, in ladder order, a checked loincloth, the fringed loincloth, the spring, the spear, a plain loincloth painted gold, the hand (`build_far_shore.py`, registry and manifest rows regenerated); `locale/en.po` has UI_REWARD_PATTERNS "Four new loincloths", UI_REWARD_LOINCLOTHS "Four more loincloths", UI_REWARD_SPEAR_PARTY "Spear Party", UI_REWARD_GOLD "Golden loincloth" and no Mesa Rodeo / Cloud Top text. A development save that still holds the ids `mesa_rodeo` / `cloud_top` loads; they are no rewards and open nothing. Tests: `test_core_unlocks`, `test_core_save`, `test_core_versus_match`, `test_core_expansion`, `test_ui_overlays`, `test_ui_screens`, `test_ui_versus` (the arena screen: no card locked, none shows a painting count), `docs/spec/test_spec_docs.py` `CutThreeApplied` (no skip left). |
| G61 | Co-op boss balance (orchestrator, until the human playtests) | windowed route replays (G3 verifier #5): the co-op Twin Idols last about 25 s (the solo Expert fight about 2.5 min), the co-op Inkjaw Expert route takes 18 hurts, the co-op Old Mangrove about 3 min | **orchestrator**: until the P4.5 pair playtests every co-op boss fight lasts **45-90 s** (1 093-2 185 ticks) for a competent pair and costs **at most 6 hurts** on its Expert route; the co-op Twin Idols get harder, the co-op Inkjaw (Expert) easier. **Lead designer**: measured on the recorded two-stream routes from `Events.boss_started` to `Events.boss_defeated`, both heroes' `hero_hurt`; the baseline of every co-op form is the table in B.0 - only Tusker is inside the band today (the Brute, the Twin Idols and the Rival Chieftains are too short, the visor Colossus, Old Mangrove and Inkjaw too long, Inkjaw and the Roc over 6 hurts). A form is retuned in its co-op form only (the solo boss and its routes stay), pace first, within B.0; hp above x1.25 only with the lead designer's consent; the boss test pins the re-recorded route's fight length and hurts. enemies-B (Tusker, Old Mangrove, Inkjaw) and enemies-C (Twin Idols, Storm Roc, Rival Chieftains, Brute, visor Colossus) tune; the stage designers re-record the co-op boss routes (B.0, G 13.6, G 13.11) **Built in the follow-up round** (bosses, wf10; solo forms untouched, `tools/sp_identity.sh` IDENTICAL by their report): the co-op Brute, visor Colossus, Old Mangrove, Inkjaw, Twin Idols, Storm Roc and Rival Chieftains retuned (B.1-B.7 "wf10"), Tusker unchanged; ten co-op boss routes re-recorded with `fight_ticks:1093..2185` (and `max_hurts:6` on Expert) in their headers. Re-measured by the lead designer with `build/lead_design/boss_probe.gd` on the new routes: every fight 47-83 s, Expert hurts 0-5 (B.0 table). R8's co-op hit points of Old Mangrove (7 + 6 Expert) and Inkjaw (280 Expert) are superseded. |
| G62 | Content deviations from D.9 / D.10 / A.6 (lead designer's review, G3 follow-up) | four co-op gates differ from their brief: DB3's 4-1 'cliff' (a Shoulder Hop where D.9 named a Batter Up lob); D6's 6-1 'root' (A.6's "thorns" fallback with a rolled vine instead of a flower pot on a 2-row stump); D7's 7-1 'dune' (A.6's "urchins" fallback; the urchin beds and Chomper's pen left out of the co-op copy) and 7-2 'seagate' (leapfrog plates in a sea wall with two tunnels on the drift-log ledge; the partner does not ride a floe through the gate) | **all four accepted**: **'cliff'** - a 7-row lob ledge falls to one player [G48] and a charged lob's 171 px arc onto 8 rows meets the chamber's ceiling, whose opening would drop a lone hero from the lava gallery onto the cliff; an 8-row Shoulder Hop ledge with a rolled vine back is the standard boost ledge [G28]; the search's frontier empties at 11 resting points (refused, exhaustive [G59]). **'root'** - a flower pot on a 2-row stump under an 8-row ledge is a raised root within reach, which [G28] forbids (the ledge would stand 6 rows over the stump), so a rolled vine is the only way back the rules allow. **'dune'** - A.6's named fallback, rightly taken: a mount crosses a 6-cell spike bed with one rider in about 24 ticks (D6 measured it on the thorns), so the two seats were no gate; a co-op copy has its own edits (D.9), and Chomper keeps his two seats in co-op 6-1. **'seagate'** - the two-corridor leapfrog of 1-1 / 5-1 [G9] with both doors on one view and each plate 8+ cells from its door (DB3's leash lesson, LD 15.7.8), on solid ledge where the holder can wait (a driftwood floe sinks under whoever waits on it); the floe lines stay before and after the wall. **Chomper two seats is retired as a gate kind** (D.8 #2, LD 15.7.3): one rider crosses whatever the mount crosses. Proof status [G59]: 'cliff' refused exhaustive (Expert, its only difficulty); 'root', 'dune' and 'seagate' stopped at the 660 bound on both difficulties - **unproven** until world-B's idle-bait and plate probes (and for 'root' the hop probes) fail (A.6, C.8, D.8, D.9, D.10, LD 15.7.3) **After DB1's probes** [G67]: 'cliff' and 'root' (and 7-1's 'stack') give the second hero a rolled vine at the ledge's edge; a lone hero's hop jump with a high strike reaches such a coil from the floor below (123 px), which no search macro played - so their verdicts, the exhaustive 'cliff' included, hold only once the coil rule of [G67] is in the tree (a coil is struck from its own level) or the search plays the hop jump. The review stands: the deviations follow the standard boost ledge, and the standard is what [G67] repairs. **At G3b**: the coil rule is in the tree and the search plays the hop jump - 'cliff' (4-1) and 'root' are refused (exhaustive) on that tree; 'dune' and 'stack' of 7-1 were **open** to the hop jump (the dune's top stood 6 rows over the upper coral shelf, the shoulder 6 rows over the rock's step) and are rebuilt [G70]. |
| G63 | One hit per strike as built (enemies-A's report, G3 follow-up) | the builder of [G57] asked four things: (1) the record gave a 100-hp keeper four club strikes, but the 1.0 death rule is "dies when hp drops below zero", so it takes five; (2) what a later tick of a swing does to an enemy that swing already hurt - (a) it is used up without damage (built), or (b) it passes through to whatever stands behind (measured: fixes one route, breaks five recorded ones and takes the pogo off a tough enemy away); (3) an unbraced heavy also had to refuse every death that is no weapon hit, or a lone player with a grenade or a feast opens its door; (4) one swing used to split a Tar Splitter and kill both halves | **decided**: (1) **the 1.0 death rule stays** in co-op files (GAMEPLAY 5.1: below zero; no second rule): club strikes = `hp` / 25 rounded down + 1 - hp 10 or 20 one, hp 25 (also every record without `hp=`: about a fifth of the co-op enemy records) two, hp 60 three, hp 100 five; a crouch-charged strike counts as four. The documents said four and are corrected. (2) **(a) stays**: a repeat tick is used up without damage - the hero's side is the 1.0 side on every tick (the pogo off the enemy, the clank, one target per box per tick), a living body shields what stands behind it until it is dead, and the tree's routes are recorded on it; (b) is not built. (3) **accepted**: a heavy that no Brace Wall has dazed dies of nothing - no kill-all, grenade, feast or mount bite, glider dive (`CoopTraits.refuses_death`). (4) **accepted as the trait's meaning**: the swing whose hit split a `split` record never hurts that record's half again (it may still hit the spawned half once); the record's half takes a new strike, so the pair takes a half each and a lone hero no longer clears a splitter with one swing. Route consequence: `w6_l1_coop.expert` (D6's, a splitter fight) needs the pair together at the splitters; its `eggs:0` is the designer's own pin, not a rule (a third of the co-op route headers carry no eggs key), so a re-recording that keeps `wipes:0`, both x2 gates and the 5 checkpoints may carry `eggs:1` with a note line. No code change asked (D.6, P-C.10, G 13.9.4, G 13.9.5, LD 15.7.3, LD 15.7.5) **Outcome**: `w6_l1_coop.expert` was re-recorded by enemies-A in the resumed run as a clean recording, its header unchanged (`wipes:0,eggs:0,x2_gates:2,min_checkpoints:5`; 2 833 ticks, 0 hurts) - no `eggs:1` was needed. How the pair fights a splitter under (2) is LD 15.7.5: side by side, both strike on the same tick - the first box splits the record, the partner's box kills the record's half on that tick, the first hero's box takes the spawned half on the next; a lone striker did not finish an Expert splitter in the builder's runs (the record's half runs 66 px away and the 12-tick window closes; the proof that he cannot is the search's). `test_enemies_coop` grew to 46 rows with two end-to-end rows on the real hero scene (a swing at a Bull Rex's back glances on every box tick; a real pair braces a 100-hp keeper, a crouch-charged swing takes exactly 100 and the next swing kills it inside the daze). |
| G64 | The Chieftains' crow has no picture (bosses' report, G3 follow-up) | [G61]'s co-op Rival Chieftains crow 330 ticks after one of their blows lands - nothing of theirs hurts meanwhile - but they keep fighting and nothing shows it: the mercy reads as luck | **decided**: the crow must show (B.0: a fight shows every rule it has). **Drawing only** - no simulation, digest or route change: while the crow runs each living chieftain carries a gloating bubble over his head ("Ha!" drawn with primitives like the Zzz letters, or the emote bubble's heart; never the anger mark - they ease off), blinking out over its last 22 ticks so the pair sees the window close. The bosses' owner builds it in `chieftain.gd` with a test row (visible exactly while the co-op crow runs, never in the solo form). Not a G3 blocker: the rule is fair without the picture (B.6, G 13.6) **Built in the follow-up round** (bosses, the resumed run; `chieftain.gd` class `CrowMark`, primitives only): a pale speech bubble with "HA!" in block letters, its tail 24 px over the head - just over the line of the "HUP!" pop-up, accepted there: a telegraph is never covered - up on every tick of the crow (`is_crowing()`: co-op form, fighting, alive, not an egg), dimmed to a quarter on every other pair of ticks over the last 22 (`CROW_BLINK_TICKS`), gone when the crow ends; `test_enemies_chieftain` `test_coop_the_crow_shows_a_gloating_bubble` and `test_the_solo_pair_never_shows_the_crow_bubble`; the per-tick digests of `w9_l3_coop.inputs` did not move and `tools/sp_identity.sh` is IDENTICAL by the builder's report; the lead designer looked at the windowed frames (`build/screenshots/bosses11_crow/`) and re-measured the fight unchanged (1 432 ticks, 4 hurts). How it reads to a pair is a P4.5 playtest question. |
| G65 | The rising view keeps the hero under the HUD band (orchestrator's item for party; G3 verifier #5; follows G42) | [G42] followed a hero's footing by the 1.0 ground rule, which moves only for a footing on view row 3 or higher and stops a row later - so on the 6-2b climb a hero stood with his head behind the HUD band and jumped out of the view's top (party measured the recorded routes: head under the band on 721-1 091 hero-ticks of the about 1 000-tick climb, feet over the view's top on 70-133; the verifier: "only his feet show behind the hearts"). The lead designer first answered "G42 as designed, no change"; the orchestrator's item supersedes that | **decided** (the lead designer's requirements, party's rule): [G42]'s guarantees stay - the view follows footing, never a jump's apex; it never moves down; it rises at least with the band; a jump in place lands in view. (1) **Footing room** (simulation): the highest footing of the tribe is kept **72 px (4.5 rows)** under the view's top (`LevelCamera.FOOTING_ROOM_PX`), the view rising towards that by the fast curve of 12.2 (1-16 px per tick: after a landing 3 rows up the head is under the band within 2 ticks). It buys: a hero who stands, walks or climbs has his whole body under the band (6 px of air over his head); the feet of a standing jump stay in view; 6.5 rows stay under the footing, so a step down of **6 rows** lands in view - LD 15.5's 2-row rule becomes 6 rows (a room of 8 rows, which would also keep a jumper's head under the band, was tried first and put the ledge under 6-2b's painting nook out of the view that never sinks: an off-screen death). (2) **Head peek** (drawing only; no rule reads it): the drawn view looks up over the simulated one so that the highest head stays 33 px under the drawn top (`HEAD_ROOM_PX`), by at most 4 rows (`HEAD_PEEK_MAX_PX` = 64), never above the level's top and never so far that the lowest feet leave the picture - so a jumping hero's head is under the band too and a 105 px launch keeps its feet in the picture. A partner more than 6 rows under the leader's footing is out of the view (the leash's and the band's case: an egg). (C.6, P-C.8, G 13.4, LD 15.5) **Built in the follow-up round** (party, the resumed run; `level_camera.gd` `_follow_footing` / `head_peek`, `level.gd` `_head_peek`; the drawn view comes back at 240 px per second). Party's measurement on the four 6-2b routes, hero-ticks while the band rises, before -> after: head in the 31 px band 764 of 951 -> 469 in the simulated view (none of them standing; the ticks after a landing and the jumps) and **0 in the drawn view** (solo Beginner; Expert 721 of 831 -> 469 / 0); co-op 1 091 of 2 010 -> 429 simulated / 174 drawn (Beginner), 1 063 of 2 048 -> 428 / 160 (Expert); feet over the view's top 133 / 112 / 70 / 0 -> 0 on all four. **Where it falls short of the requirements**: in co-op the look-up stops at the lower partner's feet, so a leader's jump can still pass the band while his partner stands low in the view (the 160-174 drawn ticks); a 105 px launch puts the feet over the simulated view's top for its apex ticks (in the picture, never leashed or killed for it). Routes: the two solo routes and `w6_l2b_coop.expert` replay unchanged; `w6_l2b_coop.inputs` was re-recorded (2 660 ticks, the fight inside [G61]'s band). Tests: `test_world_tribe` (`test_the_footing_room_and_what_it_buys`, `test_the_head_peek_is_a_bounded_look_up_of_the_drawn_view` and eight more), `test_world_book2` (`test_a_rising_climb_keeps_the_hero_under_the_hud_band_and_his_jumps_in_view`, `test_six_rows_down_from_the_highest_footing_is_still_in_view` and four more) - the builder's proof; `test_world_tribe` 25 / 25 in the lead designer's run on the resumed tree. **Not accepted as final in co-op - open**: on the rule as built the Beginner reference pair of 6-2b loses P2 to the leash three times in the climb (`w6_l2b_coop.inputs` as re-recorded: stage ticks 780, 952 and 1 183 - the bosses' finding, re-measured by the lead designer; 0 before the rule, 0 on the Expert file) - D6's climb keeps P2 one ledge behind P1, how a pair climbs, and with the leader's footing pinned 72 px under the top the partner is left under the view. **Ruling**: a camera rule must not cost a pair a hero that the old rule did not - in a party the view does not rise for the highest footing beyond the point where the lowest hatched hero's footing would lie more than 10 rows (160 px) under its top, the leader's room shrinking instead, down to 4 rows; only footings farther apart than one view holds let the view go with the leader; the leader's head is then the drawn view's business, and the band, not the camera, hurries a straggler. Asked of party (`wf10_lead_design_to_party.txt` #5) with the proof: the route re-recorded on D6's unchanged climb with no leash down and `eggs:0` in its header. Until then PHYSICS C.8 marks the clause as decided and not built. **The clause as built** (party, after the lead designer closed; `LevelCamera.FOOTING_KEEP_LOW_PX` = 160, `FOOTING_LEAD_MIN_PX` = 64, `_follow_footing`; `test_world_tribe` 25 / 25, `test_world_book2` 31 / 31): a pair up to six rows apart shares the rising view. **Still open at G3b - the proof, not the rule**: both `w6_l2b_coop` routes replay unchanged under the clause, and the Beginner one still loses P2 to the leash three times in the climb (stage ticks 780, 951, 1 182): its pilot keeps P2 nine to ten rows behind P1 on the vine stretches, which no 11-row view holds, so the clause never acts there; three pilot variants of party's gave the same three. The header carries no `eggs:0`. What is missing is a pilot whose P2 stays within six rows of P1 (or the pair playtests of P4.5 showing that a human pair does) - the Expert file has no down. |
| G66 | A flying keeper holds its perch (world-B's G59 probe, G3 follow-up) | `w9_l1b_coop` 'stormwall' (Expert) is **open**: its keepers are two bonded Harriers perched 14 columns apart (`range=0`), but a Harrier's way-points are relative to its target, so the first, once woken, follows a lone hero to the second's perch; he clubs both 8 ticks apart - inside the 12-tick bond window - the keeper door rises and he reaches the far cell in 235 ticks, his partner an egg throughout (the hop-over probe in continuous play; `pair_solo_min` had measured the walk between perches that stay put: 46) | **decided**: (1) **a flying keeper holds its perch** - a Harrier record with `keeper=<name>` (co-op files only) never takes off: when a hero comes within its `range` it turns to him and screeches (drawing and sound only) and stays on its anchor, struck where it sits, its body hurting on touch; a Harrier without `keeper=` is the 1.0 Harrier, so single-player is untouched. Not "its loop laid around its perch": a circling keeper swoops through head height, where a thrown special reaches it. (2) **Building rule**: the members of a keeper door or of a bonded gate must not be **led** - no archetype that follows its target (harrier, stinger, hopper, charger, leaper, lurker, digger) is a keeper or a gate's bond member unless the engine pins it (a keeper Harrier stays perched; a Bull Rex keeper is a brace gate [G57]); walkers, Guards and Shellbacks stand with `speed=0`. Every other keeper of the tree is such a ground enemy. enemies-A builds (1) in `harrier.gd` and re-records `w9_l1b_coop.inputs` if it moves; world-B keeps the gate open (red) until then, re-runs it with its probes and is asked for a validator warning for "a keeper that can be led"; the file-side fallback, should the probes still open it, is two `enemies/flyer` keepers on a fixed beat (the next owner of the file) (A.6, D.5, D.8, D.10, P-C.10, G 13.9.5, G 13.9.7, LD 15.7.3, LD 15.7.5) **Built in the follow-up round** (enemies-A, the resumed run; `harrier.gd` `_hold_perch`: a record with `keeper=` stays on its spawn point with no speed, faces its target and shows the screech pose for 22 ticks, `EnemyTuning.HARRIER_KEEPER_SCREECH_TICKS`): `test_enemies_coop` `test_a_keeper_harrier_holds_its_perch_and_a_plain_one_follows` and `test_one_hero_cannot_club_both_stormwall_keepers_within_the_window` (48 / 48 in the lead designer's run); `w9_l1b_coop.inputs` is unchanged and still replays to its tally (the pair strikes the keepers where they sit; by the builder's proof its per-tick digests did not move, both new rows fail on the old Harrier, world-B's trace no longer reaches the far cell, and the search does not reach it either - 855 resting points, the bond window 12 against a solo minimum of 46; `tools/sp_identity.sh` IDENTICAL). The gate's verdict under [G59] - exhaustive, or bounded with its probes - is world-B's re-run, not posted when the lead designer closed, so the table may still show 'stormwall' open. The bonded Harrier pair over 2-2's gorge follows its target too; it guards no door (a trait, not a gate), so rule (2) does not touch it. |
| G67 | The lone hero's real reach; a rolled vine unrolls from its own level (DB1's probes, G3 follow-up) | DB1's one-player bots on `w1_l2_coop` found moves the solo search does not play, each through a gate it had just refused (bounded at 660): the **hop jump** - Up held from the 8th tick of a low strike starts the whole jump inside the strike's hop (the 1.0 jump handler runs in the air): feet 73 px up, 77-80 with a high strike on the way, against 60-64 for a standing jump; the **pogo jump** - the same strike on ONE hittable at his feet (an inset spot, a block, an enemy) is a club pogo with a fresh jump on top: feet 114 px, over the 112 px corner catch of an 8-row ledge; the hop jump with a high strike reaches **123 px** and **unrolls the rolled vine** at the edge of an 8-row boost ledge from the floor below (coil cell 112-128 px up; a plain jump with a high strike, 107 px, does not) - the drop gift of the standard boost ledge [G28]; a swirling axe thrown from a deck 13 cells away unrolled an 8-row ledge's coil through the trunk wall; and a Harrier that follows its target through scenery is a springboard anywhere (a bounce with Up: 220 px over the shaft floor) | **decided**: the moves are 1.0 hero physics and stay (single-player identity). (1) **The coil rule**: in a co-op file a rolled vine unrolls only for a hit **from its own level** - the striking hero's feet (the thrower's for a thrown weapon, the ball's for a batted hero) are at most one row (16 px) under the top of the vine's anchor cell, the ledge it lies on; any other hit passes the coil (not consumed). Every drop gift is safe at once, no level changes, and the pairs' routes - which club the coil from the ledge - do not move. Solo files keep "any hit unrolls" (`w5_l2` holds the only solo rolled vine). Not the recipe change (no rolled vine within 123 px over a floor): no 8-row boost ledge can meet it and eleven co-op files with 13 rolled vines would need a new way up and new routes. (2) **Building rules**: no hittable (a hidden or inset spot, a breakable block) and no enemy record on the floor within 7 cells of a height gate's foot - one is enough for the pogo jump (the old rule forbade two stacked); no Harrier, nor any flyer that follows its target through scenery, within two views of a height gate ([G66]'s "must not be led", extended to springboards); LD 15.7.2 carries the lone hero's real numbers. (3) **The search** gets the moves (world-B, asked by DB1): the hop jump and its strikes as macros, a pogo-jump probe at every hittable and enemy within reach of a height gate, rolled-vine coils as probe targets, a lure probe for followers; under [G59] a "refused (bounded)" of a boost, Totem or lob ledge counts only with them. The vine's owner builds (1) in `vine.gd`. **Not built in the follow-up round**: objects-B has no agent in it and party, asked, declined - the file is outside its globs and the rule touches the proofs of eleven co-op routes. **Open at the lead designer's close**: until (1) is in the tree every gate whose way back is a rolled vine at a ledge's edge is under doubt for a player who knows the hop jump - 1-1, 1-2 'treehouse', 2-2, 3-1, 4-1 'cliff', 5-1, 5-2, 6-1 'root', 6-2, 7-1 'stack' and 9-1 in co-op - whatever their search verdicts read (C.3, D.5, D.8, P-C.4, G 13.3, LD 15.7.2, LD 15.7.3, LD 15.7.6) **Built at G3b** (the integrator, for the vine's owner): (1) `vine.gd` - `Vine.coil_rule_on` (a `kind = coop` file, or any level a co-op party plays), `Vine.hit_from_its_level` (the hitting hero's feet y `<= top + COIL_LEVEL_PX`, 16; the thrower's for a thrown weapon, the ball's own for a batted hero), `unroll` / `take_hit` return false for any other hit and the box goes on; `HeroParty._ball_touch_hittables` no longer uses up a ball's touch that a coil passed, so a lobbed hero still unrolls it once he is level with it. Proof: `test_objects_book2` `test_in_a_coop_file_the_coil_unrolls_only_for_a_hit_from_its_own_level` and `test_a_hop_jump_strike_from_the_floor_below_opens_a_solo_coil_and_never_a_coop_one` (the real hero on an 8-row ledge: 15 trials each; in the solo file the strike unrolls the coil and he climbs it); DB1's regression probe of 'treehouse' prints "refused (21 trials)" (17 of 21 reached before); the routes of the eleven files replay with the rule (`test_coop_routes`), `tools/sp_identity.sh` IDENTICAL. (3) world-B's search plays the hop jump and its strikes since the round's last hour; with them it found six gates of five files open - none through a coil - which [G70] rebuilds by the rules of (2). |
| G68 | Book I co-op as built, second part (DB1, G3 follow-up) | DB1's three missing files needed changes beyond [G48]: 1-2's trunk-room pulley could not be played (a 7-row pulley parts the pair by 14 rows and puts the pan off the view), the Shoulder Hop ledge with a rolled vine that replaced it fell to one player three ways [G67], a Harrier of the solo file carried a lone hero up the shaft, the bonded leapers never sealed (a leaper is a zone spawner whose record never dies, so its copies regrew for ever), and the tablet's far cell put the next gate's Snatcher and drums into this gate's search box; in 2-1 two Shellback beats 6 px apart under the low ledge left a pair no way past, and the Expert bat hung over the plate holder's head | **all accepted**: 1-2 gate 'shaft' is an 8-row boost ledge [G28] whose upper hero crouches on a plate that drives a lift stone (`objects/column rise=8 rise_while=shaft`) for his partner - 2-2's plate-driven pillar on a standard boost ledge; the lift is the drop gift, the holder crouches [G58], an idle partner weighs nothing [G33] and nothing in the shaft can be clubbed or bounced on (the trunk room's inset spot moved to the big branch); a hanging vine leads on. It supersedes [G48]'s counterweight hop. The Harrier is left out ([G22], [G67]); the two leapers are plain - **no bond on a zone-spawner archetype** (LD 15.7.5; D.6's "twin leapers" stays a suggestion only where the engine can seal it); the tablet names the far cell behind the trunk top so that the gate box holds this gate's plate and stone. 2-1: the Expert turtle beside the plateau's Shellback is a plain walker and the Expert bat over plate A is left out [G22]; 9 of the 27 Expert records carry a trait, the third the validator asks for. The G59 verdicts of DB1's gates are world-B's tool's, reported by DB1 (D.9, LD 15.7.5) |
| G69 | Totem ledges of 5-6 rows are no gates (DB1's probes, G3 follow-up) | LD 15.7.2 called a 5-row ledge "the easy Totem ledge (a gate: one player cannot ride his parked partner)" and D.9 built 1-2's first tree house on one. But a lone hero's hop jump [G67] lifts his feet 73 px, 82 with a high strike on the way, and the corner catch of a 5-row ledge begins at 64 px, of a 6-row ledge at 80: the 5-row ledge is climbed and the 6-row one stands on 2 px (DB1's 15 tries did not catch it, and nobody ships a gate on 2 px). At such a ledge the rolled vine's coil also falls to a plain jump with a high strike (feet 50 px up) | **decided**: **every height gate is 8 rows** over every floor within reach (catch from 112 px, 30 over the 82) - the boost ledge of [G28], reached by a Shoulder Hop (140 px) or a timed Totem launch (139-152 px); the Totem ledge of 5-6 rows is retired as a gate kind and stays a co-op comfort or a secret's approach. A 7-row lob ledge (catch from 96 px) holds only over a clean foot [G67] and is the search's to prove. **Accepted**: DB1 rebuilt 1-2 'treehouse' as an 8-row boost ledge (the root mound's top two rows removed, the rolled vine 8 cells long); the sign's Totem launch still makes it. Its way back is a rolled vine, so it is under [G67]'s doubt like every other until the coil rule is built (D.8, D.9, LD 15.7.2, LD 15.7.3) |
| G70 | The six gates the hop jump opened, as rebuilt (G3b integration, 2026-10-09; recorded by the integrator - the lead designer had closed) | world-B's search, playing the lone hero's moves of [G67] in the round's last hour, found **nine rows open** - six gates of five co-op files, none through a rolled vine's coil: `ending_coop` 'lookout' (E: a low strike under the tablet found the road's two hidden spots - a pogo jump of 130 px, onto the 8-row gallery), `w3_l1_coop` 'cliff' (B, E: the same on a cracked block of the cliff room's wall, 128 px, onto the clifftop), `w7_l1_coop` 'dune' (B, E: the dune's top stood 10 rows over the beach but 6 over its own upper coral shelf - a hop jump) and 'stack' (B, E: the shoulder 6 rows over the rock's step), `w9_l1_coop` 'pulley' (E: a hop jump from the shelf onto the shaft's one-way cloud ledge 6 rows up) and `w9_l2_coop` 'drive' (E: from the painting's cloud onto the slate stack 6 rows over it, and from its top a step onto the raised bridge slab; world-B could not confirm this one in continuous play) | **rebuilt in the level files by the rules of [G67] (2) and [G69]** - the hero's moves are 1.0 physics and stay, no engine rule was added: 'lookout' - the two spots lie 12 cells from the gallery's end; 'cliff' - the cliff room's cracked blocks are an open doorway (as 1-2's bark [G68]) and its roast spot lies at the room's far end; 'dune' - two rows higher (12 over the beach, **8 over the upper shelf**); 'stack' - the rock one row lower (2 rows, its step 3): the shoulder is a **7-row lob ledge** over a clean foot, the vine one cell longer; 'pulley' - the cloud ledge one row higher (7 over the shelf, 4 over the raised lift B); 'drive' - the slate stack 5 rows higher (11 over the painting's cloud, whose painting spot is a pogo's foot), so nothing a lone hero stands on is within a jump of the raised slab. **Two building facts** (LD 15.7.3): (1) a ledge's height counts **from every standing place** under or beside it - a rock's step, a shelf, a terrace, a cloud - not from the lowest floor; (2) a **one-way cell catches like a corner**: a falling hero whose feet are anywhere inside it is landed on it, so a one-way ledge is climbed from 16 px under its top (the 6-row cloud ledge fell to the 82 px hop jump; widening it across the shaft did not help, the seventh row did). **Proof**: the search, uncached, on the final tree (the G3b table, `coop_gates_verdicts.txt`): **76 / 76 gates refused - 51 exhaustive, 25 bounded with every probe of their kind**; the six rebuilt gates exhaustive but 'pulley' (bounded at 660 resting points, 295 queued; hop-over 0 / 120, idle-bait 0 / 61, thrown-special 0 / 126, egg 0 / 8). Routes: `ending_coop`, both `w3_l1_coop` and `w9_l2_coop` replay unchanged; both `w7_l1_coop` routes are re-recorded with D7's bot (the step's height in one line) and `w9_l1_coop` with D9a's (its geyser ride now measures "higher than he started" from the floor under the hero - with the new timing it began on his partner's head and then stood 427 ticks idle); headers, determinism and belt invariance green, validator `--strict` clean on the five files. Not done: no static validator rule for the clean foot or for one-way ledges - the search is the proof; the designers' generators under `build/` do not know the changes (A.6, D.8, D.9, D.10, LD 15.7.2, LD 15.7.3, LD 15.7.6) |
| G71 | A spring is a launch (orchestrator's R1; G3b verifier, cause B) | a low strike begun ON a spring pad with Up held from its hop: the pad fires at the hop's apex (`yvel` 0, so no fall has armed `no_jump`) and the 1.0 jump handler adds the jump table to the pad's -224 - feet **256 px** (16 rows) up, against 115 px for a plain jump onto the pad and 82 for the hop jump; the same in the real game on both difficulties (`build/g3bv/spring.gd`, `spring_real.gd`). Every `objects/spring` - pad, cap, flower pot - was a 16-row launcher: `w2_l2_coop` 'seesaw' fell over its 9-row bone wall on both difficulties, and the explorer reached `w6_l2_coop` 'seesaw' and 'caps' and `w2_l2_coop` 'lift' the same way (not replayable from a fresh process) | **orchestrator**: for a hero of a co-op party a spring pad, cap or flower-pot spring fires as a **launch** - no jump table on top of it; solo play keeps the 1.0 behaviour. **As decided** (lead designer): (1) every `objects/spring`, whatever its skin, gives a hero of a co-op party (P-C.0 #2: `Game.mode == COOP` and `hero_count() > 1`; the search's world is one) `yvel = power` with the launch's bookkeeping (`fall_ticks = 0`, `no_jump` armed, off any platform, the bounce's depth correction and his `xvel` kept), and **from that tick until he next has ground, a platform, a carrier or a vine under him no jump starts and none goes on** - no jump-table impulse and no strike-hop impulse, only gravity. `no_jump = 6` alone is not the rule. (2) **The measurement is the rule**: a -224 pad lifts his feet 105 px over the pad's top - at most **115 px** over the floor it stands on - from every start: walking on, falling on, jumping on with Up held, a low or a high strike begun on it or a step beside it with Up held from any tick, the hop jump, the pogo jump off a hittable beside it. **Measured on party's first build** (the bounce plus `no_jump = 6`; the verifier's `spring.gd`, `build/lead_design/spring_after.log`): the stack fell from 256 to **142 px** - the jump table was gone, but a SECOND low strike (Down and Fire held on for 10-11 ticks) added its hop of -48 seven ticks into the rise; 142 px is over the top of an 8-row ledge (the lead designer first read it as a pad firing above its own top line - wrong: the bounce already starts there). **As built** (party, `PlayerBase.launch_hold`): from the tick a spring throws a co-op hero until he next has ground, a platform, a carrier, a vine or a saddle under him there is no jump table, no strike hop and no pogo. **Measured** (the same tool on that build, `build/lead_design/spring_after2.log`, and party's rows for every start of (2), `test_player_gate_rules`): the stack rises **115 px**, what a plain jump onto the cap rises; single-player on the same pad keeps its 1.0 stack. (3) Single-player, a party of one and versus keep the 1.0 bounce (identity; the arenas' bot graphs are baked on it). (4) Asked of party with it: the same measurement for `PlayerBase.launch` itself (a low strike begun on a geyser vent at its spout tick) - a launch that can be topped gets the same hold in a co-op party. **Answered** (party): it could - a -224 geyser gave a standing hero 105 px, a hop inside the vent box at the spout tick 120 px and strikes begun on the vent 180 px (eleven rows). So in a co-op party every `launch()` - geyser, see-saw, vine leap, bat, dismount, hatch pop - holds the flight the same way, and a geyser puts a co-op hero's feet on the vent's floor first: 105 px from every start; a solo hero of Book II keeps 120 / 180 (identity). It is the round's widest change for the co-op routes: no strike hop and no pogo in the flight after any launch. Building rule: a spring near a height gate is allowed when the gate's ledge stands 8+ rows over the **pad's top**. Routes that stack a jump on a pad break by design and are re-recorded in the Levels phase (C.0, D.5, P-C.0, G 13.9.7, LD 15.7.2, LD 15.7.3, LD 15.7.6) |
| G72 | Bonds are slot-bound (orchestrator's R2; G3b verifier, cause C) | `pair_solo_min` timed a RUN between the strike spots and [G36] forbade one throw through both members - but one hero throws a special at the far member and strikes the near one as it lands: the gap between two hits in flight is his to choose. `w5_l2_coop` 'rattlers' (both difficulties: the bonded keeper Snappers, 602 / 698 ticks), `w9_l1b_coop` 'stormwall' (Expert: the perched keeper pair) and `w4_l2_coop` 'drums' (Expert: two axes thrown in one jump between the drums) fell to one hero | **orchestrator**: a bond - bonded enemies, keeper pairs, drum pairs, every "two within a window" rule - is met only by hits credited to **two different heroes who both count**; two hits of one hero's slot never meet it, however they are timed or thrown; a hit credited to an idle hero, an egg or a downed hero counts for nobody. **As decided, and as enemies builds it** (`coop_traits.gd`, `objects/drum`): (1) **Credit**: a hit belongs to the slot of the hero whose strike it is - his club box, his mount's bite, the thrower of a thrown weapon for its whole flight, and for a batted hero **the ball itself**, not his batter (a lone hero who bats his idle partner into a member has not found a second slot); it is credited only while that hero counts on the tick it lands (`counts_for_coop()`: hatched and not idle), else to nobody. (2) **The windowed records** - the members of a named `bond`, the halves of a `split`, the drums of a `bond=` pair: a weapon hit credited to nobody **glances** (the clank and the spark of every glance), and the death that would leave the whole group dead **without two different counting slots among its deaths** does not happen - a weapon hit on the last living member glances, and no kill-all, grenade, feast, mount bite or glider dive kills it. So one hero kills one member and never the last; the dead one regrows (the halves merge) when its window closes, and "every keeper dead" still means "the bond was met" for a keeper door. (3) The window values, the count-in and the regrow are unchanged; the daze was slot-bound already [G47]. (4) **What falls away**: `pair_solo_min` and the `window = min(24 B / 12 E, solo_min - 4)` cap are no longer proof obligations (the keys stay valid and still shorten a window), a pair on one throw line is no build error [G36], and "keepers must not be led" [G66] is a courtesy to the pair, not a proof. `split` is a window rule and is bound with the others: a lone hero no longer clears a Tar Splitter at all - he walks past it; the pair's way, a half each [G63], is two slots already. Never in single-player, a party of one or versus (D.6, D.8, P-C.10, G 13.9.3, G 13.9.5, LD 15.7.5, LD 15.7.6) **Built in the round** (enemies-A; `coop_traits.gd` `credit_hero` / `credit_slot` / `_wasted_kill` / `refuses_kill`, `enemy_base.gd`, `spawner_enemy.gd`, `drum.gd` `struck_by`): as decided, and beyond it, accepted - a **first** death is never refused, whoever it is credited to (a grenade may open a window that nobody can then meet; it closes by the regrow), while nobody's weapon hits always glance; **drums**: a hit on a lit drum adds its slot, so the bond succeeds once both heroes have drummed inside the window, whoever struck which, and the last dark drum stays dark for the hero who alone struck every lit one; a **leak of the split closed**: a dead half that was a zone spawner's copy (the sky blobs of 6-1) used to be freed at the view's edge, leaving the other half to one hero - it now stays until its window is decided. Not unified, and it stays so: the bosses' twin rules and the giant-roast twin still credit a batted ball to its batter (the stricter reading for a pair, no opening for one hero). **Proof** (the builder's): `test_enemies_coop` 59 / 59 - in the real level scene with two real heroes one hero's two spears 6 ticks apart leave the keeper door of 5-2 'rattlers' shut and one spear each opens it; the same at 9-1b 'stormwall' and at the drums of 4-2; the three tests fail with the rule switched off; the verifier's class-C routes say "not reached" (rattlers, both difficulties; the drums find) and "DIED" (stormwall) - the lead designer's replay of the evidence set on the same tree agrees; `tools/sp_identity.sh` IDENTICAL. **One route breaks** of 57 co-op (route, difficulty) replays: `w6_l1_coop.inputs` (Beginner: P1 took both halves of the second Splitter 23 ticks apart) - re-recorded in the Levels phase with a half each. One file matter found on the way: `w3_l2_coop` 'pits' bonds two leaper records that are zone spawners, which nobody can ever meet [G68] - its owner drops the bond. |
| G73 | The ward (orchestrator's R3; G3b verifier, causes A and E) | a head bounce with Up lifts a hero's feet 105 px over an enemy's head, and the hero chooses the enemy: one he wakes 22 columns away and leads to the gate (7-1 'dune': the lone gull, 581 ticks club only, also in the real game; 1-1 'hop': the Expert hopper; 6-1 'root': a leech), one that leaps or hangs at the gap (3-2 'drive' and 'floes': the leaper, 230 ticks; 7-2 'dark_gap': the lurker), a perched keeper as a fixed pad (9-1b 'stormwall'), the Bull Rex's head as a seat into its door (9-2 'brace'). [G67] (2)'s "no enemy within 7 cells of the foot, no Harrier within two views" was checked by nothing and broken by 22 columns, and rebuilding gate by gate had failed twice | **orchestrator**: every `objects/x2_tablet` has a **ward** - the columns from its own cell to its `far=` cell, widened by `PartyTuning.WARD_MARGIN_CELLS` on both sides (default 12; `ward=<left>,<right>` per tablet), over all rows - and inside it, for a hero of a co-op party, **no enemy gives lift, rest or carry**; the stomp still counts against the enemy, the hero is not hurt by that enemy during that fall, keepers are enemies, a partner's shoulders, mounts, rafts, lifts and the level's own objects are untouched, and a light cue tells the player the head gave nothing. **As decided** (lead designer): (1) **Geometry**: margins in cells, left = towards column 0; clipped to the level; fixed at load - a lit or a passed gate keeps its ward, and a `secret` tablet has one too. A hero is in a ward when the cell column of his **feet point** lies in one: his column, not the enemy's. (2) **A stomp in a ward** (on foot, gliding or mounted): nothing of the hero changes - velocity, position, fall count, jump state; no Up bounce, no small bounce, no glider bump, no cut bounce [G54] - he falls on through the body. The enemy takes the stomp exactly as elsewhere, **once**: `on_bounced` (a `daze` record is dazed, the multiplier chain counts), a glider's dive and the multiplier pop-up; no bounce event is sent - he did not bounce. **The pass**: from that tick **until their boxes part** that enemy's body neither hurts him nor is stomped by him again - he falls through it and may land inside it without paying a heart for a stomp made in good faith; its projectiles and every other enemy act as always, and no gate rests on a body as a barrier (a hurt's immune ticks pass any body already). The lead designer had first ruled a clock (12 ticks after the landing); party's form - one remembered head per hero (`Player._ward_head`), forgotten when the boxes part or the enemy dies or sleeps - is simpler and is the rule. (3) **No rest, no carry**: no enemy is ground, a platform or a carrier for him there - he stands on no head or back, and a ride an enemy carries into a ward ends at its edge. (4) **No pogo off an enemy**: a club box that hits an enemy leaves the striker's velocity alone; the hit itself is unchanged. (5) **Untouched**: boss bodies (a boss's stomp rules are its fight's, B.0), a partner's shoulders, mounts as mounts, rafts, lifts, see-saws, geysers, springs [G71], vines, and every hittable - a spot or a block still gives its pogo. (6) **The cue** (drawing and sound only): a dust puff at the head and the landing thud (`fx/dust`, `Sfx.LAND`: assets we have) instead of the bounce ring and its boing. (7) Never in single-player, a party of one or versus. **The check** (lead designer: `replay.gd trace=20` on all 21 evidence routes at HEAD 082c788, `build/lead_design/traces/`): the hero's column at every head bounce of the cause-A and cause-E routes lies inside the default ward - 3-2 'drive' 88-102 in 81..118 and 'floes' 86-102 in 75..122, 6-1 'root' 165 in 150..189, 7-1 'dune' 185 in 167..209 (all four files, the real-game one too), 7-2 'dark_gap' 132-137 in 121..158, 9-1b 'stormwall' 197 and 212-213 in 184..234, 9-2 'brace' 107-113 in 81..128 - **but one**: 1-1 'hop' takes its three Up bounces at columns 87-88 and its ward begins at 88. Its high ground - the hollow block of columns 90-97 whose top leads to the boost ledge - begins 10 cells before the tablet. **Ruled**: `ward=22,12` on that tablet (columns 78..129) and the building rule **the margin counts from the gate's high ground** (LD 15.7.4). **Proven needed**: on the tree with the ward built and declared in the search's world the verifier's explorer still opened 'hop' (Expert) under the default ward - seed 2, 164 s: three Up bounces on the led hopper at columns 80 and 83, on the pool's one-way ledge left of the ward's edge, then the hollow block's top and the boost ledge; 1 666 ticks, replayed in a fresh process (`build/lead_design/evidence/w1_l1_coop.hop.expert.pool_ledge_default_ward.txt`; seed 1 found nothing in 300 s). Columns 80-85 lie inside the ruled 78..129; the route is the 24th of the evidence set [G77]. 9-2 'drive' is no head bounce at all [G79]. **What a designer may now place** (LD 15.7.3): [G67] (2)'s "no enemy record within 7 cells of the foot" is dropped inside the ward; "no Harrier within two views" shrinks to the ward's edge - the high ground 12+ cells inside it, and the barrier closed above where a free flyer can be brought to the edge; the hittable half of [G67] (2) stays whole. Routes that take lift from an enemy inside a ward break by design and are re-recorded (D.5, D.8, D.10, P-C.10, G 13.9.4, G 13.9.7, LD 15.4, LD 15.7.3, LD 15.7.4, LD 15.7.6) **Built in the round** (party; `X2Tablet.ward_columns` - one static rule for the entity and every tool - `LevelBase.set_ward` / `in_ward` / `get_wards`, `Player._ward_stomp`, `_ward_heads`): as decided, the heads that gave nothing kept in a list, so a hero falling through two bodies counts each once; a ridden mount's stomp gives it no lift in a ward either (the ward tested at the driver's feet). **Ruled on party's report**: the `grab` trait is a carry - a Snatcher does not seize a hero whose feet column is in a ward (its touch there is the plain hurt) and lets go of one it carries when he enters one; a `perch=` never lies beyond a gate's barrier (the trait's owner builds it). **Known cost**: the ward is "over all rows", so in the tall files (1-2, 4-1, 5-2, 9-1, the climb of 6-2b) it covers whole towers and the pair has no head bounce there - whether they miss it is a P4.5 playtest question. **Proof** (party: `test_player_gate_rules`, each rule measured in co-op and in single-player - in a ward the fall with a body under him is the free fall tick for tick, outside it and in single-player the 1.0 bounce; the lead designer's replay of the evidence set on that tree): every cause-A route says "not reached" or "DIED", the real-game 'dune' route too **As built at G3c** (the integrator's record, 2026-10-09): the `grab` rule is in `coop_traits.gd` (`_warded`: no seize of a hero whose feet column is in a ward, a carried hero let go on the tick it enters one, with the freed hero's 44 immune ticks; `test_enemies_coop` `test_grab_never_seizes_in_a_ward_and_lets_go_at_its_edge`, red with the rule switched off). The `ward=` values in the files are wider than first ruled - 1-1 'hop' `ward=34,12`, not 22,12, and eight more tablets carry a key: [G83]. **Changed in phase 4**: the pass no longer lasts for as long as the boxes overlap - it ends at most 12 ticks after the hero lands [G87] - and the enemy itself shows the ward before anyone stomps it [G85] |
| G74 | The stack and the long drop (orchestrator's R4; G3b verifier, cause D) | `w7_l1_coop` 'stack' (both difficulties): the warp stack's blowhole and its 15-row kelp vine lift a lone hero to the stack's top (206-208,7), 10 rows over the gate's shoulder (219+,17) and 11 columns from it - a running jump lands on it (386 ticks, club only, no enemy). The search's `climb` move is 96 ticks of Up and a node must be a rest, so nothing above a vine longer than about 10 rows was ever searched | **orchestrator**: the warp stack must not be a launch place onto the gate's shoulder - out of a running jump's reach, or the shoulder roofed; the search learns the long climb [G77]. **As decided**: the **long drop** rule (LD 15.7.3) - a running jump from a standing place `h` rows above a ledge carries 7.2 cells plus about 0.44 per row (measured on the reference hero model, `build/lead_design/long_drop.py`: Right held, Up for 5 ticks, 5 px a tick - on the flat 115 px; 5 rows down 150 px, 9.4 cells; 10 rows 185 px, 11.6 cells - the route's 11 columns; 15 rows 13.4; 20 rows 15.6), so every standing place a lone hero can reach `h` rows above a gate's ledge lies **more than 10 + h / 2 cells** from it (10 rows: 15 cells - 2.8 cells and more of margin for the hop jump's higher apex; in a file with a `wind` script 12 + 0.6 h, a tailwind's 6 px a tick), or the ledge is **roofed**: solid at most 3 rows over its whole top and closed towards that place. D7's file moves or lowers the warp stack (with its blowhole, vine and warp item) or roofs the shoulder - the levels owner's choice; both 7-1 co-op routes are re-recorded if they move. The proof is [G77]'s: the search with a hero at rest on a vine as a node, the two 'stack' evidence routes, the explorer (D.10, LD 15.7.2, LD 15.7.3, LD 15.7.6) **As built at G3c**: 7-1's warp stack - blowhole, kelp vine, warp, secret zone, back wall - stands six columns left (columns 200-202): 16 cells from the 'stack' shoulder at 10 rows, over the rule's 15; the checkpoint under it moved to column 204 and the tablet carries `ward=38,12`. Both 7-1 routes replay unchanged; the search (with the long climb) refuses the row exhaustively on both difficulties and the explorer is silent |
| G75 | A closed door passes nobody (orchestrator's R5; G3b verifier, cause E) | `w9_l2_coop` 'brace' (Expert): standing on the Bull Rex's head as it presses at its keeper door (36 cut bounces [G54]) the hero is carried into the one-cell door column (`objects/column 114,37 size=1,4`) and the corner slip puts him out on its far side - the Rex alive, the door shut (721 ticks) | **orchestrator**: a hero pushed into a closed keeper door, a column or any solid by an enemy, a partner or a mover is put back on the side he came from - never through. **As decided**: for a hero of a co-op party, whenever anything but his own walk puts his box into a solid (a tile, a closed door, column or slab, a block) - an enemy's shove or carry, a head he stands on or slides off [G54], a partner's bat or carrier, a mover's push [G53], a knock-back, the corner slip - he is put back on **the side of that solid on which his feet point lay at the end of the last tick his box was free of it**: the nearest free x on that side, y kept, then he falls as usual. Never the far side, whatever is nearer; where that side is closed too the existing crush rule decides between that side and the solid's top. A one-cell keeper door is allowed again. Inside the ward [G73] the head that carried him gives nothing in the first place, so the proof asked of party is a rule test **without** the ward (a hero shoved and carried into a one-cell column from both sides, 20+ approaches) as well as the evidence route saying "not reached". Single-player keeps the 1.0 corner slip (D.5, P-C.10, G 13.9.7, LD 15.7.3) **Built in the round** (party; `Player._hold_the_side`, in the hero's POST): his body cell is his feet column in the wall-probe row; a tick that ends with it in a wall he entered from another column, or that took him across a wall cell, puts him back at his last free x and stops the speed that carried him in; a wall entered in his own column is left to the 1.0 corner slip. **The cause, corrected**: no enemy pushed the hero of the 'brace' route - the level's gust crept him 1 px a tick past the wall probe while he steered away, the step's edge under the door landed his feet in its column and the corner slip carried him out the far side - so the rule also holds his own walk where the 1.0 probe lets it into a wall. **Proof** (party): the evidence route with the wards switched off ends "not reached" (put back at x 1 823 at tick 697); 50 approaches into a one-cell column - both sides, five carry speeds, five key states - 0 through in co-op, 36 of 50 in single-player; a 22 px knock across a door; walking, jumping and ledges unchanged |
| G76 | An idle hero is no anchor (orchestrator's R6; G3b verifier, cause D in the real game) | the tribe camera's vertical anchor is the hero who last had ground, and an idle hatched partner standing below has ground on every tick - so the lone climber of 7-1's warp stack was the one the leash took (121 / 73 ticks: tick 285 / 237 of the replay). A player was egged because his partner had put the pad down, and the same anchor kept a lone hero off a gate for the wrong reason | **orchestrator**: a hero who is idle by the idle rule (243 ticks [G33]) is no camera anchor and is the one the leash takes: the camera follows the heroes who count, and if the pair parts beyond the leash the idle one becomes the egg. **As decided**: (1) the tribe camera - the horizontal rule, the anchor, the standing window, the look-around refusal, the edge walls - runs on the heroes of `H` who **count** (`counts_for_coop()`: hatched and not idle); with one hero counting it is the single-hero camera of 12.1-12.5 on him exactly; when no hatched hero counts it is `H` as before (as built: the view stays with them all). (2) The leash itself is unchanged (121 B / 73 E ticks outside the view; the edge arrow and its stone countdown are shown for an idle hero as for anyone): since the view follows who counts, the hero left outside is the idle one. (3) **The idle hero's egg** is an egg like any other - it drifts to the partner (Beginner) or flies to the checkpoint after 243 ticks (Expert), hatches by a box, a stomp or a checkpoint and pops out idle (P-C.12); it costs nothing and counts for nothing. (4) A hero who wakes counts from that tick; his leash count, if he is outside the view, runs on - he is never favoured over the hero who kept playing. (5) **The wipe** (lead designer, asked of party): a team wipe happens when the **last counting hero** goes down - "every other hero is down, an egg, dead **or idle**" - because a player who went down beside a hatched idle partner was an egg nobody could hatch (a co-op run whose second pad is never touched ended there for good); the toss plays out, a life is paid, both respawn at the checkpoint. A player is never egged because his partner put the pad down, and never stranded by it either (D.2, D.3, P-C.12, P-C.13, G 13.9.2, LD 15.7.7, LD 15.7.9) **Built in the round** (party; `LevelCamera._drop_idle`, `PartyDriver._leash` / `_wipe_check`): as decided, with one difference on purpose - when NO hatched hero counts the camera reads every hatched hero as before (two players who ride a raft for ten seconds without a key are both idle; a view that stood still would egg both). **The wipe as built**: on the tick a hero who counted goes down (or his toss ends) and no other hero counts; an idle hero's own down wipes nothing, nor does a hero who goes idle beside an egg - that egg waits until the pad is touched (the pause menu is the way out; a wipe there would cost a pair a life for ten quiet seconds on a ride: accepted, a P4 note). Tests: `test_world_tribe` (+4), `test_world_party` (+5: the view waits 242 quiet ticks and goes on the 243rd; an idle partner 16 rows below never costs the climber his body). Found on the way and fixed: the level's doze index filed an entity dozing left of the map under the numbers it used for "not filed". **Changed in phase 4**: the egg of a hero who plays no longer waits for ever beside a partner who goes idle AFTER it was made - the tribe is wiped after `IDLE_WIPE_TICKS` [G86] |
| G77 | The proof of a gate is three things (orchestrator's R7) | G3b's table was green in every row - 76 / 76 refused, also uncached at 3x the bound (59 exhaustive, 17 bounded with every probe) - and one hero passed 19 rows in continuous play the search never tries: every move starts from a reset world (a woken follower is never led), no strike begins on a spring, a vine longer than one move is dropped, `pair_solo_min` knows one throw, and the reset is not exact (six rows count "replays missed"; `Sim.tick` and the total-tick clock are taken as found, so "exhaustive" was exhaustive over a world that drifts). The bar of [G59] had moved with every round | **orchestrator**: the proof of a gate is three things, and the bar is **fixed** - a gate is judged by it and by nothing wider. Per gate row (gate x difficulty): **(a) the solo search refuses it** - exhaustive, or bounded with every probe of its kind [G59] - on an exact reset (tick base 0, the total-tick clock put back per run; a run that missed replays says so and is bounded) and with the long climb (a hero at rest on a vine is a node [G74]); **(b) every route of the evidence set says "not reached"**, each replayed in a fresh process - the set is versioned under `tools/` and only grows: the verifier's 21 routes and the lead designer's three (the two gust routes of [G79] and the 'hop' route under the default ward [G73]) today: 24; **(c) the continuous-play explorer opens it in none of two seeded passes of 300 s** over the whole level - versioned under `tools/`, with the lure, ride, strike-on-spring, long-climb and second-throw moves and the exact reset. A replayable route is **red** whatever (a) says; a find that does not replay from a fresh process is no evidence either way and is kept as a seed. The gate table shows the three per row and is green only with all three. What the bar does **not** ask: a wider search bound, further probes, human attempts - a route found outside it is a new evidence route for the next round, not a moved bar. The lead designer adds one requirement inside (a): where a file has a `wind` script the search plays its phases [G79] (D.8, PLAN 8 V3.c, LD 15.7.6) **State at the lead designer's close** (2026-10-09, the working tree with R1, R2, R3, R5 and R6 built and the ward declared in the search's world; every route of the evidence set replayed in a fresh process, `build/lead_design/after3/`): **20 of the 24 say "not reached" or "DIED"**; four still reach, each of them level-file work of the Levels phase - 7-1 'stack' on Expert (the warp stack [G74]; its Beginner route already fails on the launch hold of [G71]), 1-1 'hop' from the pool's ledge until `ward=22,12` is in the file [G73], and 9-2 'drive' on both difficulties by the gust jump [G79]. Proofs (a) and (c) on the final tree are world-B's and the integrator's run, not the lead designer's **Built in the round** (world-B, its first report): the explorer, the replay and the evidence set versioned under `tools/coop_explore/` (`replay_evidence.sh`, `explore_gates.sh`; finds that no fresh process replays kept apart as seeds); the search's world declares every tablet's ward with the tablet's own function; **the wind's phases** - in a file with a looping wind script every move of an unchanged resting point is played once per entry of the script, with three gust-jump moves (no direction held, then Up alone) - the probes run in the first phase only; a search run's total-tick clock starts at 100 000 in every process (at 0 the one-hit-per-strike key of [G57] read "no key" for a strike begun in the first tick), `Sim.tick` at 0; bonds are read from the engine as slot-bound (solo minimum "never"). The validator: `ward=` parsed and checked, a per-gate listing of the ward, the clean foot and the one-way catch as errors, a warning for high ground at a ward's edge (nine gates; cleared by `ward=` or a comment, LD 15.7.4), a keeper on a one-shot archetype an error, the one-throw line a note **As built at G3c** (world-B's close and the integrator's run): the search world's tick base is **17 952** in every run and every process, not 0 (`CoopSearch.TICK_BASE`: a common multiple of the cycle lengths the levels use - 34, 66, 88, the wind loop 352 - so every cycle stands where tick 0 would have it and no geyser is 'before its delay'; on base 0 the search opened 6-2b 'vent' with a run-jump through vents that had not started); a route file names the base it was recorded on (`tick0=`). The evidence set is **33 routes**: the verifier's 21, the lead designer's 3 and 9 finds of this round's explorer, one per red row that had none (`tools/coop_explore/evidence/`); one of them (9-2 'drive' on Beginner) is for a file not played on that difficulty and is printed as a note, no row. The gate table is 45 gates in 76 rows (31 on both difficulties, 14 Expert-only). `tools/g3.sh` runs the three proofs as its `coop_gates` job through `tools/world_coop_gates.sh` - first and alone, because a pass is 300 s of wall time - and prints `n / 76 gate rows GREEN by the three proofs` with the red rows and their route files: [G83] |
| G78 | Versus rounds end (orchestrator's R8) | a Last Caveman Standing round has no clock: two players (or bots) who keep out of the sudden death's reach never end it - a Colossus Hall round did not end | **orchestrator**: a Last Caveman Standing round has a hard cap after its sudden death starts (`VersusTuning`, default 60 s); at the cap the hero with fewer hurts taken wins, then a draw. **As decided, and as versus builds it**: `VersusTuning.SUDDEN_DEATH_CAP_TICKS` = **1 457** (60 s *(tune)*; 0 = no cap), armed once when the round's sudden death starts; on that tick the round ends whoever stands. **Who wins**: among the sides still standing (a team in 2v2, else a hero) the side with more heroes standing, then with more lives left (option Stock: a hazard takes a life without a hurt), then with the **fewest hurts taken this round** - one per heart lost, a charged hit two; bones that heal a heart take none back and a handicap's extra hearts do not count; still level: **a draw**, nobody scores the round. **HUD**: Last Caveman Standing shows no sundial until the cap is armed; from then the HUD's sundial counts the cap's 60 s down - the timer the HUD has, with its last-seconds treatment - the round ends on the gong, and the HUD's round banner names the winner or its "Draw" as after any round (no reason line: that would be a new string). Bots need no new rule. Versus only (E.4, E.6, E.8, P-C.14, G 13.10.4, G 13.11) **Built in the round** (versus; `referee.gd` `cap_at` / `cap_winners` / `hurts_of` / `cap_ticks_left`): the cap is armed in `start_sudden_death()`, once per round; on the cap's own tick the last-one-standing rule is asked first (a knock-out that leaves one side is a win by standing); a hurt is a heart actually lost - a hit 1, a charged hit 2, a stomp 1, an arena hit 1, a Chomper's bite 1, One-Bonk every heart he had; none for a hit the leaf shield took, a Grudge rock's daze or a hazard's knock-out; the sundial's number turns red from 10 s (`HudVersus.DIAL_WARN_SECONDS`) - the HUD's own warning, no new string. **What the cap found**: without it a round of heroes who never move ran for ever on Colossus Hall, Echo Hollow and every rotation of Totem Ring - the last because its stampede ran along the totem's top, 6 rows over the floor (the charger's line was the first ground under the view's middle column; fixed in the round: the view's lowest surface, `sudden_death.gd`, so Totem Ring's two floor spawns are run down at about 1 500 ticks and only its two bridge spawns still need the cap); with it every such round ends at 2 914 ticks of play (`test_versus_rules` 88 / 88, `test_two_heroes_who_never_move_end_every_last_caveman_arena_by_the_cap`). **The match** (lead designer, on versus's report that two players who never move draw round after round): **three drawn rounds in a row end the match on its standings** - the side with the most round wins takes it, level sides share a drawn match (`VersusTuning.DRAW_ROUNDS_TO_END` = 3 *(tune)*, 0 = never; every mode). **Built** (`VersusMatch.draws_in_a_row`, `VersusMatch.ended_by_draws`, `leaders()`): a round with a winner resets the count; a match that draws ended names the side with the most round wins and nobody when no single side leads (the results screen's "Draw!" was there already - no new string); `test_three_drawn_rounds_in_a_row_end_the_match_on_its_standings`, `test_two_who_never_move_draw_a_match_after_three_capped_rounds` (Colossus Hall, the match's own spawn rotation) **Changed in phase 4** (versus): the round a cap ends says why - the round banner reads "TIME!" (`UI_VS_TIME`, a new string after all) with the result as its second line, for as long as the result line would have stayed; `VersusReferee.ended_by_cap()` is true from that gong. Drawing only |
| G79 | The gust jump (the lead designer's trace of the evidence routes: a sixth cause) | `w9_l2_coop` 'drive' was filed under cause A (a Roller's head), but its route's two Up bounces put the hero back on the floor where he stood; he then waits for the level's tailwind (`wind = 0:0,110:112,176:0,286:-112`, `wind_loop = 352`) and crosses the 9 cells of tar in a jump at 6 px a tick. A jump begun from the **slide** - no direction key held while the gust carries him, then Up alone - keeps the gust's speed for the whole flight: 27 ticks at 6 px are **162 px, 10.1 cells**, against 115 px, 7.2 cells, for the best running jump in calm air (the reference hero model). The lead designer's routes take no lift from any enemy and reach the far cell in a fresh process on **both** difficulties (`build/lead_design/evidence/w9_l2_coop.drive.expert.gust_no_lift.txt`: tick 326; `...beginner...`: tick 324; 0 head bounces, one hurt while he waits); with every enemy as placed 343 of 6 336 timing variants on each difficulty of one jump-the-Roller plan cross (`build/lead_design/wind/scan3_d1.log`, `scan3_d0.log`). The ward [G73] does not close it, and the search never saw it: it restarts the wind script at every move, so a gust that begins 286 ticks into the loop is never played | **decided**: the move is the level's own - the solo file's gust gaps are crossed exactly this way - and stays for every hero. (1) **Building rule** (LD 15.7.3 "Gust gaps"): in a file with a `wind` script a gap gate is measured against the gust jump - **12 cells** on the flat towards the side a tailwind blows (10.1 and a margin; the calm rule of 8 B / 9 E cells stands on a 7.2-cell jump), or the far lip raised 2 rows over the near one for its first 3 cells (a gust jump is 32 px up for about 16 of its 27 ticks: 6 cells), or the near lip roofed. (2) `w9_l2_coop` 'drive' is **open on both difficulties** - 20 of the 76 rows with it, Beginner being a row the verifier's explorer had left closed - and is rebuilt by its levels owner to (1), the charged line drive still carrying the ball across. (3) world-B's search plays the wind's phases (a node's signature carries the phase of a looping script, or every move is tried at each phase), and the two routes join the evidence set of [G77] (b), which is 24 routes with the 'hop' route of [G73]. Among the co-op files only `w9_l2_coop` and `w3_l1b_coop` carry wind, and 3-1b's two tablets lead into its wind (C.4, C.6, D.8, D.10, P-C.6, G 13.3, LD 15.7.2, LD 15.7.3, LD 15.7.6) **As built at G3c** (the levels owner): the gap is **13 cells** of tar (columns 203-215, the near lip under the slate stack's edge); the slab bridges 9 of them, the latch plate stands at 219-220, the batter hops the last 4 in a lull, the drive is a charged one, and the cloud hall's Roller (196,34) is left out (its roll ended in the tar at the lip and knocked the batter in). Why a partial bridge: [G83]. The search refuses the Expert row exhaustively with the wind's phases; the file is not played on Beginner |
| G80 | Versus fairness as measured (versus's report of the round) | PLAN 8 V4.b asks win rates per spawn within +/-15 % "over the seeded set" - 12 seeds x 4 rounds, where a fair spawn's share has a standard deviation of 6 points. Two Grub Stack sets of four Hunters sat on the edge: Totem Ring (worst -14.6) and Sky Picnic (worst +14.6). Measured over 384 rounds each (`build/versus/fair.sh`): Totem Ring 23.4 / 25.3 / 30.7 / 20.6 % - worst +5.7; Sky Picnic 42.7 / 17.4 / 14.1 / 25.8 % - worst **+17.7**: spawn 1 (the right floor) takes the round's first giant bonus because the cake island is climbed with a standing jump from the right floor and only with a run-up from the left (1.0 physics, the same for players) | **decided**: Totem Ring stays. **Sky Picnic's Grub Stack is outside the band by measurement** and ships with this record - over a match the spawns rotate; it is no G3 blocker. Not fixed by a bot change (the builder's trial brought Sky Picnic to 8.3 and re-rolled Cinder Pit and Echo Hollow to red in the module: withdrawn); the fix is the arena file's - the first giant must not land where one floor half gets first: the big cells struck and paid on the floor halves themselves - and it is P4's (target: worst <= 10 over 384 rounds). **The bar** (PLAN 8 V4.b): the module's 48-round sets stay the deterministic regression pin; a fairness claim for an (arena, mode) is made on at least 384 rounds (E.5, E.7, PLAN 8 V4.b, G 13.11) **Changed in phase 4** (versus; `levels/arena_sky_picnic.lvl`, its bot graph re-baked): the one twin big spot on the cake island became a big spot in each lip of the floor's hole - each giant falls onto its own lip - the two small floor spots moved to the island's top corners, and the spawn numbers are mirrored; collision, pots, springs and clouds are unchanged. Measured by the versus builder with four Hunters: over 384 Grub Stack rounds the best spawn takes 31.0 % and the worst 22.1 % (30.2 / 20.3 % on a second set of 384) - worst +6.0 points, inside the band and under the target of 10. These sets were played on the rules before the stomp rule of [G93], which re-rolls every bot set; the sets with it are the builder's report #2 and were not in at the lead designer's close |
| G81 | The coil is opened by a hero who stands on its level (a seventh cause; world-B's explorer inside the bar, the levels owner's ask of the vine's owner) | [G67] (1) read "a hit from its own level" as the hitting hero's feet on the tick the hit lands and nothing else. A hero who is not on the coil's ledge meets that for a few ticks at the top of a jump or of a bounce, and a special thrown then unrolls the coil from any distance a special flies. The explorer of [G77] opened three gates of two files that way, each a route that replays in a fresh process: 2-2 'seesaw' on both difficulties (the cap lifts him onto the bone shelf 3 rows under the wall's top; a jump from the shelf, a swirling axe at its top, the coil 8 columns away unrolls; 568 ticks, no head bounce, no hurt), 6-2 'seesaw' on both (the same from the cap ledge) and - honestly met from an x2 secret's ledge one row under the terrace - 2-2 'lift'. Every see-saw gate has the shape by its recipe (a drop ledge within a jump of the target's level) | **G3c integrator** (no owner of the vine ran; the levels owner's option (b)): "its own level" means **standing there**. In a co-op file a coil unrolls only when the hitting hero's feet are at most one row under its ledge [G67] **and the ground he last had under his feet is no lower** - `last_ground_y <= top + 16`, the field every landing writes, a hero standing on a floor, a platform or a partner's head every tick, a saddle every tick and a respawn. The top of a jump, a bounce or a launch from below is not the coil's level; the strike hop and the jump of a hero who stands on the ledge keep it, and a hero who walked off the ledge loses it by the feet rule as before. **A batted ball is its own delivery**: the ball's feet at the level are enough, and the batted hero must count (a dozing partner batted at a coil unrolls nothing - the slot rule's "a hit of a hero who does not count is nobody's" [G72]). Solo files keep "any hit unrolls". The two roofs the levels owner built meanwhile (2-2: a stalactite over the cap and the bone shelf; 6-2: the hall's rock over the cap ledge) stay as built, and 2-2 'lift' keeps its cleared foot. Building rule: a ledge within one row of a gate's coil - an x2 secret's too - needs the clean foot of [G67] (2); the validator reads gate tablets only (open, P4) (PHYSICS C.4, LD 15.7.3) **Built** (`scripts/objects/vine.gd` `hit_from_its_level`): `test_objects_book2` +2 - the rule row by row, and the real hero's jump from a shelf 3 rows under a coil's ledge: his feet are at its level for some ticks and on none of them is he a hitter from it in a co-op file, on all of them in a solo file. The 57 co-op route runs replay unchanged with the rule (the designers' bots unroll after landing) |
| G82 | Over a shield there is no behind (the levels owner's ask of the trait's owner; world-B's explorer routes of 5-1 'gully') | one hero killed both keeper Shellbacks of `w5_l1_coop` 'gully' on both difficulties, his idle partner parked by the door: he dropped through the crust's hole onto the keeper at 164,21 - inside the ward he falls through its body [G73] and stands in it - or stood on the head of the one at 155,21, one column outside the ward, and threw a special **the way its shield looked**. The front test of the Guard reads a thrown weapon by its flight alone ("flying into its face"), so a weapon that starts on or in the body and flies with the facing counted as a hit in the back (traced by the integrator on the level file of before the rebuild: the keeper faces him on every tick, the killing hit lands with no club box out - power 80 at tick 828, power 20 at tick 1083). The levels owner rebuilt the gully as a bond; four more shell keeper halls (2-1 'den', 3-1b 'hut', 8-1 'hall', 8-2 'shamans') stood on the explorer's silence | **G3c integrator** (no owner of the traits ran): a `shell` is hurt only by a hero who is **behind** it. The hero of a hit is its striker, or the thrower of a thrown weapon for its whole flight; the hit glances when his feet point lies within the columns of the record's body box - he stands **on** it or **in** it - or on the side its shield faces, whichever way the weapon flies; the Guard's own front test still holds beside it. A batted ball is judged by its own place and flight, a hit no hero made by its flight. So "one hero is always in front and only his partner can hit its back" (D.6) is true from every place. A party of one meets a plain Guard, unchanged. 5-1 'gully' stays the bond of two tortoises it was rebuilt as (its routes are recorded on it; sign `SIGN_W5_COOP_GULLY`: "Twin tortoises: club one each at once, or one grows back!") - D.10's "pincer" there is a bond (PHYSICS C.10, LD 15.7.5) **Built** (`scripts/enemies/coop_traits.gd` `_shell_faces_hitter`): `test_enemies_coop` `test_a_shell_is_hurt_only_by_a_hero_who_is_behind_it` (both forms; on the head and in the body at six offsets, both flight directions, the club; the thrower in front; the partner behind hits) - red without the rule; both explorer routes of the gully, replayed on the level file of before the rebuild, reached the far cell without the rule and end "dead" with it (`build/g3c_integrate/shell_trace*.log`). The 57 co-op route runs replay unchanged |
| G83 | The Levels phase and the gate job as built (the G3c integrator's rulings on the levels owner's four questions and world-B's three) | the lead designer had closed before the Levels phase ended; its owner asked: the `ward=` values that `--strict` needs are wider than ruled and the validator reads no comment; 9-2's slab cannot bridge the whole rebuilt gap; the gully became a bond; a Roller was left out. world-B asked: the tick base, a `secret` tablet's ledge without a clean-foot rule, and the gully | **G3c integrator**: (1) **`ward=` until no top is named** - a comment clears nothing; a margin grows until `tools/validate_levels.gd -- --strict` is silent, and a comment above the tablet says what the wider ward costs the pair. In the files: 1-1 'hop' 34,12; 1-2 'treehouse' 12,62; 2-2 'lift' 26,12 and 'seesaw' 45,12; 4-1 'cliff' 12,29; 5-2 'sandgate' 12,21; 7-1 'stack' 38,12; 8-1 'stairs' 23,12; 9-1 'pulley' 12,17. Cost: in 1-1 the columns 66-77 are new (the hopper fight at the crate lost its pogo; the route replays key for key), elsewhere the added columns were other tablets' wards already. (2) **A slab bridge over a gust gap spans at most 9 cells from the near lip**: the shared view lets a pair stand 290 px apart and a plate stands 8 tiles from its column, so the batted hero cannot reach a plate behind a longer slab; 9-2 'drive' is 13 cells with a slab of 9, a hop of 4 and a charged drive [G79]. (3) The gully as a bond: accepted, and the class is closed by rule [G82]. (4) The cloud hall's Roller of 9-2 left out: accepted [G22]. (5) The tick base 17 952 and the 33-route evidence set: accepted as the bar's as-built values [G77]. (6) The coil met in mid-air: closed by rule [G81]. (7) `bond=` on a zone-spawner record is a validator **error** now (3-2 'pits', the one file that carried it, has plain leapers). **Left for phase 4**, none a row of the gate: a validator rule for the clean foot of an x2 secret's ledge beside a coil and for "a plate more than 17 cells from the near lip of the gap its column bridges"; the gate's own ledge named by the high-ground line when a ward's edge comes close (1-2); gust routes for the new 9-2 lip in the evidence set (the old ones aim at the old lip - that row stands on the search and the explorer); the bosses' twin rules and the giant roast still credit a batted ball to its batter (the stricter direction; not unified with [G72]); the wards of 2-2b and 6-2b reach into their boss arenas, where boss bodies are not warded (LD 15.7.3, 15.7.4) **Recorded and built**: the nine keys are in the level files (`--strict`: 0 errors, 0 warnings in 120 files); `tools/g3.sh` runs the gate job as the three proofs; the validator's error and its test row; the as-built numbers of the run are PLAN.md 6 "The G3c integration" |
| G84 | The coil rule and the shield rule are confirmed (orchestrator's Q1, phase 4) | [G81] (a coiled vine unrolls only for a hero on its level) and [G82] (a shell enemy is hurt only from behind) are rules of the simulation that the G3c integrator ruled himself, because no owner of the vine or of the traits ran in that round; a rule of the game is the orchestrator's or the lead designer's to make | **orchestrator**: both are **confirmed** as the game's rules for 2.0, as built. Nothing changes in code, level files or proofs: the 57 co-op route runs and the three proofs of gate G3 were made on them. What the Levels phase built before the rules stays - the stalactite and the rock roof over the cap ledges of 2-2 and 6-2 'seesaw', the cleared foot of 2-2's x2 bone ledge, 5-1's gully as a bond of two tortoises (D.5, D.6, D.8, D.10, P-C.4, P-C.10, LD 15.7.3, LD 15.7.5) |
| G85 | The ward must be readable: the enemy shows it (orchestrator's Q2; the G3c verifier's measurement) | the ward [G73] changes what the solo game taught - a head is a springboard - around every x2 tablet, and the G3c verifier measured how much ground that is: the wards cover 44 % of the columns of the 23 co-op files that have tablets, 4-1 and 5-2 from end to end (reproduced by the lead designer on the level files: 1 786 of 3 977 columns, 44.9 %; 186 of the 396 enemy records of the co-op files stand in one). The only cue was a dust puff and a thud AFTER the stomp: a pair learned the rule by falling through a beast it meant to bounce on | **orchestrator**: the rule stays, **the enemy shows it**. An enemy standing in a ward wears a **ward mark** - drawn only: chalk-white tribal stripes or a like sign in the game's style, readable at 320 x 180 - on while its feet column is in a ward for a co-op party, never in solo play; the first ward of co-op 1-1 and of co-op 5-1 gets a sign that teaches it in one line; the stomp cue stays. **Pure presentation: no simulation value may change through it.** **As decided** (lead designer, `wf12_lead_design_to_all.txt`): (1) **Who wears it**: every enemy a hero could stomp outside a ward - a record or a spawner's copy that is visible, alive and targetable, asleep or awake, keepers and trait enemies included; not bosses or boss parts (boss bodies are not warded), not projectiles, decorations, mounts or the neutral enemies of an arena. (2) **When**: on every drawn frame on which the cell column of the enemy's feet point lies in a ward (`LevelBase.in_ward` of that column) and the level is played by a co-op party; it goes on and off as the enemy crosses a ward's edge and needs no hero near. (3) **What**: not a HUD element; it must not read as a hurt flash (white modulate), as a Shaman's bone shield or as a daze, and it must hold on the pale sheets (snow turtles, ghosts, the slime's light half): a dark edge or a second tone; no per-entity shader material beyond the draw-call budget of ARCHITECTURE 11. (4) **The mark is the enemy's column, the rule is the hero's**: a hero is in a ward by his own feet column [G73], so within about one body width of a ward's edge a marked head may still bounce him and an unmarked one may give nothing. Accepted - every ward's edge lies 12+ cells from its gate's high ground, so nothing at an edge decides a gate - and a line of `HUMAN_CHECKS.md`. (5) **The sign**: "Marked beasts are no stepping stones - use your partner's shoulders" at the first ward of `w1_l1_coop` (before 'hop': its ward begins at column 66) and of `w5_l1_coop` (before 'hop': column 68), a few columns inside the ward with a marked beast in view; where the board cannot hold the line in its 3 lines, the short form "Marked beasts are no steps - use your partner's shoulders". (6) The stomp cue of [G73] #6 stays: the dust puff and the thud (D.5, D.6, D.9, D.10, P-C.10, G 13.9.4, G 13.9.7, LD 15.7.4) **As built** (party; `scripts/fx/ward_mark.gd` `WardMark`, `EnemyBase._refresh_visual` / `wears_ward_mark` / `is_ward_marked`, `LevelBase.ward_marks`, set only by a level that a co-op party plays): chalk war paint - chevron bands of chalk white (246, 240, 222) between two lines of dark ink (46, 39, 31), a band every 26 art px, kept 2 px off the silhouette's rim and drawn only on opaque texels of the enemy's own sprite. It is **one shared material** put on the sprite and taken off again (like the hero palettes): no art file, no extra node, no canvas item, no per-entity material - at most one more draw state per sheet that is on the view both marked and unmarked. **Who wears it, as built**: an enemy that is awake, alive, tangible and whose touch counts, of kind ENEMY - exactly the enemies the hero's contact test would stomp; an enemy still asleep outside the view wears none (it gives no bounce either, as in 1.0), which is narrower than (1) and accepted: nothing on the view is asleep. The texts are `SIGN_COOP_W1_WARD` and `SIGN_W5_COOP_WARD` in `locale/en.po`, both **the short form** of (5): "Marked beasts are no steps - use your partner's shoulders!" (58 characters, 3 board lines) - the ruled line takes 4 board lines on a sign (`SignBoard.text_lines`, with or without its "!"), one more than `SignBoard.MAX_LINES`, and `tests/test_ui_signs.gd` fails every sign over 3; the two sign records are the levels owner's. **The census of the mark** (party, `build/party/wf12/mark_census.gd`: the first standing frame of each of the 55 enemy sheets painted as the shader paints it): the paint covers 21.4-32.2 % of the body on every sheet; 50 sheets are "strong" (the chalk at least 0.30 brighter or darker than what it covers, two or more bands); on 3 the chalk is nearly the body's own tone and the two ink lines carry the mark (bear_b, sea_snail, octopus); 2 hold one thin band (fish, fish_b); the weakest of the strong are the gull, the ghost, the rexes, the cave bat and turtle_b. **Measured by its builder**: it adds **no draw call** - a co-op view with 6 marked and 6 unmarked beasts of 6 sheets takes 19 canvas draw calls with the mark and 19 with it switched off (every enemy sprite is a draw call of its own already); an enemy that cannot be touched now - a hanging lurker, a digger under the ground, a leaper in its hole - wears none until it can; all 57 co-op route runs replay to the same per-tick digests as on HEAD 1e025e9 (140 060 ticks, 0 files differ), `tools/sp_identity.sh` IDENTICAL, `tests/test_world_ward_mark.gd` (5 tests: co-op yes and solo never, on and off at the ward's first and last px, the same 200-tick fight with and without the mark equal on every tick). **Does it read** (party, off-screen screenshots at 640 x 360): bold white slashes on dark and saturated sheets; **weaker on pale ones** (the white gull, the white ghost, the snow turtle, the grey Bull Rex: the two ink lines alone carry it) and **weak on the smallest bodies** (the bat, the Raptor: one band crosses a 30 px body); and it is a pattern, not a symbol - nothing in the picture says "no bounce" until a sign was read, so the teaching rests on the two signs. Each of these is a line of `HUMAN_CHECKS.md`. **Ruled on party's finding** (lead designer): **no sign inside a ward tells a pair to bounce on a beast** (LD 15.7.4) - `SIGN_W5_ROLLER` ("Rollers roll at you. Bounce on one to reach the mesa tops!") stands at column 71 of `w5_l1_coop`, inside the ward of 'hop', beside a Roller that is marked: the levels owner drops that record from the co-op copy. Of the 59 signs that stand inside a ward it is the only one that teaches a bounce on an enemy (`build/lead_design/wf12/signs.py`; `SIGN_W6_REX` of 6-1 is the taming of Chomper, a mount, which no ward touches) |
| G86 | No dead end beside an idle partner (orchestrator's Q3; the G3c verifier) | [G76] wipes the tribe on the tick a hero who counted goes down beside an idle hatched partner, but as built "a hero who goes idle beside an egg wipes nothing - that egg waits until the pad is touched (the pause menu is the way out)": a player in an egg whose partner put the pad down AFTER he went down floated there for ever, in a game that otherwise never strands anybody | **orchestrator**: if every hero who counts is an egg or down and the only hatched hero is idle, the party is wiped to its checkpoint after `PartyTuning.IDLE_WIPE_TICKS` (default **73**, 3 s *(tune)*), as when both are down. **As decided** (lead designer): (1) **The state**, read at the end of a tick by the wipe check: a hero of the party is an egg (a hero in his death toss does not count yet - the toss decides first, as before), a hero is hatched, and **no hatched hero counts** (each is idle by [G33]). (2) **The clock**: one counter per party, +1 on every tick that ends in that state and 0 on every tick that does not - any input of a hatched hero, a hatch, a checkpoint, a wipe, the level's end; when it reaches `IDLE_WIPE_TICKS` the team is wiped exactly as when both are down (P-C.12: the curtain, one life from the tribe pool, the level reset, both hatched at the checkpoint). 0 switches the rule off. (3) **Whose egg**: the clock runs only while the egg belongs to a hero **whose player plays** - his own input clock is under `IDLE_TICKS` (a nudge of the egg and any held key are input) - so the wipe is the stuck player's way out, and two pads lying on the table never cost a life by themselves: "every hero who counts is an egg or down", read by the input clock. (4) The "Zzz" over the dozing partner is the warning [G58]; no new picture, sound or string. (5) [G76] stays whole: a counting hero's down beside an idle partner still wipes at once, and an idle hero's own egg wipes nothing while his partner plays. **The cost, accepted**: a pair with one hero in an egg that rides out a long quiet stretch without a key - 243 ticks to doze and 73 more, 13 s - loses a life; the egg's player ends it with any key only if his partner wakes. Whether 73 is right is a line of `HUMAN_CHECKS.md` (D.2, D.3, D.11, D.12, P-C.12, G 13.9.2, LD 15.7.9) **As built** (party; `PartyDriver.idle_wipe_ticks`, `_idle_dead_end`, read in `_wipe_check` at the end of every tick): as decided, with (3) - the dead end is "some hero is an egg whose own player plays (his `idle` is false), every hatched hero is idle, no death toss is running"; each such tick adds one, every other tick - a hatched hero's key, a hatch, a toss, the egg's own player leaving his pad - puts the clock back to 0; at `IDLE_WIPE_TICKS` the team is wiped; `IDLE_WIPE_TICKS <= 0` switches the rule off. The wipe at once of [G76] is unchanged (`_last_counting_went_down`). Tests of `tests/test_world_party.gd`: `test_an_egg_beside_an_idle_partner_is_wiped_after_the_idle_wipe_ticks`, `test_the_idle_wipe_clock_is_cleared_by_a_key_a_hatch_and_a_toss`, `test_two_pads_on_the_table_never_cost_a_life`. The test of "his player plays" is `PlayerBase.idle` false - the idle rule's own verdict - and not the bare counter: a partner who never touched his pad since he entered the level has a small counter and is idle all the same (accepted: the better test). For a hatched hero who simply puts the pad down the wipe comes on his 315th quiet tick (243 + 72). Measured by its builder on a real Level, Beginner and Expert: two pads on the table for 535 ticks - clock 0, no life; the egg of a partner who never played beside a player who rests - nothing; red with the rule switched off. Nothing on the screen counts the 3 s down (no cue in 2.0.0: a line of the check list). No two-stream route holds an idle hero beside an egg: all 57 co-op route runs replay to the same per-tick digests with the rule in |
| G87 | The ward's grace is short (orchestrator's Q4; the G3c verifier) | [G73]'s pass - after a stomp in a ward that enemy "neither hurts him nor is stomped by him again until their boxes part" - sheltered a hero for as long as he stood inside a body: the gully's lone hero stood in a keeper Shellback and threw from there [G82], and a pair could park a hero inside a keeper to wait out its mate | **orchestrator**: the "not hurt by that enemy" of a stomp in a ward lasts for **that fall** and at most `PartyTuning.WARD_GRACE_TICKS` (default **12** *(tune)*) after his feet touch ground; standing inside a keeper is no shelter. **As decided** (lead designer): (1) the pass holds while he is in that fall - no ground, platform, carrier, vine or saddle under him, the list of the launch hold [G71] - and for at most `WARD_GRACE_TICKS` ticks from the first tick he has one; it still ends earlier when their boxes part or the enemy dies, sleeps or stops being targetable. (2) After it the contact test of that hero and that enemy is the normal one: its body hurts him (the immune ticks of the hurt then let him walk out), and a new landing on it from above is a new ward stomp - nothing given, the stomp counted once more, a new pass. (3) **Why 12**: at the walk cap of 5 px a tick he covers 60 px, more than the widest keeper's body (the 54 px Guard and Shellback art), so a hero who lands and walks on never pays and one who stays does. (4) [G82] is unchanged: on a shell's head or inside its body a hero is in front, whatever he throws. It is a rule of the simulation: the co-op routes and the evidence routes replay against it, and the gate proofs are re-run on it (D.5, D.6, D.11, D.12, P-C.10, G 13.9.4, G 13.9.7, LD 15.7.4) **As built** (party; `PlayerBase.ward_grace_step` / `ward_grace_over`, `Player._ward_since`, the same clock on a ridden mount in `objects/mount`): one clock per stomped head - "falling" while that fall lasts, 0 on the first tick on which he is grounded, on a platform, mounted, carried or climbing, then +1 a tick; past `WARD_GRACE_TICKS` the head is forgotten although the boxes still overlap, and that same contact pass finds the body as any body: the hurt comes on the **13th tick after the landing**. A mount standing in a keeper is no shelter either (its stomp is its rider's, so is its grace). The rule can be switched back for a measurement (`PlayerBase.ward_grace_ticks` negative = "until the boxes part", written by tests only). Tests of `tests/test_player_gate_rules.gd`: `test_the_wards_grace_ends_twelve_ticks_after_the_landing`, `test_a_hero_who_lands_in_a_keeper_and_walks_on_never_pays`, `test_a_mount_standing_in_a_keeper_is_no_shelter_either`. A stomp made from standing (a hero on a ledge whose feet are in the upper half of a body that walks under him) is a ward stomp like any other: nothing given, counted once, a 12-tick pass, then the next one. **What it moved** (party): of the 57 co-op route runs none - the same per-tick digests as before both phase-4 rules (140 060 ticks) - and of the 33 evidence routes two, which now end earlier and dead because the lone hero stood inside a warded body: `w5_l1_coop.gully.expert.wf11_explorer` (DIED at tick 987; before: not reached at 1 178) and `w9_l1b_coop.stormwall.expert` (DIED at 415; before: not reached at 876); none reaches its far cell. The lead designer's replay of the 57 runs on that tree (`build/lead_design/wf12/pair_probe.gd`, run 2 against run 1) gives the same stage ticks, hurts and gate times in every line |
| G88 | Version 2.0.0; Windows is the release target (orchestrator's Q5) | PLAN P4.6 asks for "exports (Windows, Android, macOS, iOS presets)"; the Android SDK, a Mac and Xcode are not in the project, and installing toolchains on the build machine is not a workflow's decision | **orchestrator**: the release is **2.0.0** and **Windows** is its target - the exe, the zip and the Inno Setup installer. Android, macOS and iOS stay "easy to port": their export presets must load and docs/PORTING.md must be true for 2.0; they are exported only where the toolchain is already in the project. Nothing is installed outside the project. The lead designer's part: the specs say 2.0.0 where they name a version, and the device steps that need those platforms are `HUMAN_CHECKS.md` (F.5, PLAN 7 P4.6) |
| G89 | Nothing goes public from an agent (orchestrator's Q6) | the repository is public (github.com/brunolau/grub-game) and a release, a tag or a push cannot be taken back | **orchestrator**: no agent commits, tags, pushes or makes a GitHub release. The agents prepare the files and the release text; the orchestrator commits; the owner of the game decides on the public release (F.5) |
| G90 | What only a human can check is not faked (orchestrator's Q7) | P4.3-P4.5 ask for things no tool can do: mixed-skill pair playtests of every co-op stage, an expert told to cheat, a listen-through of every music pick, key ghosting on real keyboards, pads, an Android device. Since G1 they were moved from gate to gate [G3] and no record said so in one place | **orchestrator**: none of it is faked or declared done by a script. It goes into `docs/expansion/HUMAN_CHECKS.md` as exact steps with what to look for, and everything a tool CAN measure about it is measured now and written beside the check. **As written** (lead designer): one line per check that a person can tick, in the order a pair plays - stage by stage and gate by gate for both books, then the expert told to cheat, the versus modes, keyboards, pads, the music with its track list, the Android device - each with the file and the value to change if it fails (D.12 says what must be re-proven after that change). The measurements beside the checks: the ward coverage and the marked beasts per stage, the co-op boss fight lengths of the recorded routes, the windows and the daze against the reference pair's own gaps where a tool reads them, the track lengths, the bots' fairness sets, the desktop `--perf` numbers. 2.0.0 is proven without the human checks; they decide what a later version tunes (D.8, D.9, D.12, F.5, G 13.11, PLAN 7 P4.5) **As written at the lead designer's close**: the file's sections are P (the tribe's rules), C (the 35 co-op stages: a play-through line each and a line for each of the 45 gates), X (the expert told to cheat), V (versus), K (keyboards), G (pads), M (the music: all 51 tracks), L (the look-over), D (devices) and W (the Windows build and a real 1.0 save). **The tools named beside the checks**: the lead designer's `build/lead_design/wf12/pair_probe.gd` (the 57 recorded two-stream route runs: per stage its length and hurts, per gate the ticks from the tablet to the far cell - the recorded pair needs 1 to 34 s per gate), `wards.py` (the wards) and `music.py` (the track lengths: 44.7 minutes for one pass); the audit owner's `tools/audit_assets.py --audio` and `--sheets` (loudness, loop seams, the art's pixel sizes: his lines L1-L7 and A1-A5 are in sections M and L); the gate job, the bot sets and the route tests of PLAN 6-8. `docs/spec/test_spec_docs.py` keeps the list honest against the tree: a line for every gate, arena cell and music file, every quoted constant at its value, every named file present, no box ticked |
| G91 | The values 2.0 ships with (lead designer, phase 4) | every *(tune)* value was "a starting value for playtests", the playtests of G1 and of P4.5 never took place inside production, and the values were spread over this document, GAMEPLAY 13.11, PHYSICS C.16 and five tuning files; "final values written into DESIGN.md and the specs" (PLAN P4.5) needs one place that says what ships | **decided**: 2.0.0 ships every *(tune)* value at what the tree holds on the release day, and **D.12 is the register**: the value, its constant, what rests on it (a gate's proof or only the feel) and what must be run again after a change. `docs/spec/test_spec_docs.py` reads every `Class.NAME = n` of D.12 and compares it with the constant, so a tuning change that skips this document turns the spec test red. New in phase 4: `PartyTuning.IDLE_WIPE_TICKS` = 73 [G86] and `PartyTuning.WARD_GRACE_TICKS` = 12 [G87]; unchanged since they were ruled: `WARD_MARGIN_CELLS` 12 [G73], `SUDDEN_DEATH_CAP_TICKS` 1 457 and `DRAW_ROUNDS_TO_END` 3 [G78], the windows 24 / 12 and the daze 14 / 12 [G3], `IDLE_TICKS` 243 and `IDLE_WARN_TICKS` 170 [G33] [G58]. The words "starting value" in GAMEPLAY 13.11 and PHYSICS C.16 now read "ships as" (D.12, G 13.11, P-C.16) |
| G92 | A feast is no key to a keeper door (the lead designer's measurement in phase 4; the expert's cheat "the 8-1 feast piece") | a hero's touch kills while his feast burns - `enemy.kill(&"feast")` in the contact pass, before any trait is asked - and the traits refuse a death that is no accepted weapon hit only for a `heavy` [G63] and for the last member of a bond or a split [G72]. A `shell` or `daze` keeper is not protected. The feast kit is run state and is carried from stage to stage, and the three proofs of [G77] start every gate without one. **Measured on the real level** (`build/lead_design/wf12/feast_probe.gd`: `w8_l1_coop`, Expert, a co-op party of two with P2 idle, the run's kit preset to pieces 2 and 3 - on 7-1 the three pieces lie side by side at columns 206, 210 and 213 - and P1 placed by teleport, so the rule and not a route): the piece of 8-1 at cell 51,38, on the terrace over the keeper hall, starts the feast (658 of 660 ticks left); P1 stands in each keeper Shellback for 4 ticks - both dead; `keepers_done` true, the keeper door of 'hall' rises 4 of 4, its doorway is air. The control without a feast: both keepers live and each touch costs P1 a heart. So one player who plans two stages ahead opens 8-1 'hall' alone; it is the only hall in reach in 2.0.0 - Book I and 8-2 hold no kit piece, 5-1's gully is a bond, 9-2's Bull Rex a heavy, no kill-all or grenade item lies in a co-op file and no mount or glider comes near a shell keeper | **decided** (lead designer): in a co-op party an enemy that carries `keeper=`, and every `shell` and `daze` record, **dies only of a weapon hit its trait accepts** - a feast's touch, a kill-all, a grenade, a mount's bite and a glider dive do not kill it, exactly as a `heavy` and a bond's last member refuse them already; the feaster walks through it unhurt as through anything else. Single-player, a party of one and versus are untouched. **Not built at the lead designer's close**: it is a rule of the simulation (`CoopTraits.refuses_death`; then the gate job, `tools/sp_identity.sh` and the co-op routes) and no owner of the traits ran in the phase - sent to the orchestrator and all as `build/engine_requests/wf12_lead_design_to_orchestrator.txt`. **The remedy without the engine**, for the levels owner if 2.0.0 is not to wait: the record `items/feast_piece 51 38 index=0` of `levels/w8_l1_coop.lvl` moves behind the hall's door (beyond column 58), so that no feast can burn in the hall; then that file's gate rows and its route. **The bar stands**: [G77] judges a gate by the three proofs and "a route found outside it is a new evidence route for the next round, not a moved bar" - gate G3 stays passed, and this is that next round's first entry; whether 2.0.0 ships before it is closed is the orchestrator's decision. Building rule meanwhile (LD 15.7.5): no feast piece between a stage's start and the door of a `shell` or `daze` keeper hall. It is line X-03 of `HUMAN_CHECKS.md` (D.6, D.8, P-C.10, G 13.9.5, LD 15.7.5) |
| G93 | What the versus soak found: three rules of the referee (versus builder, phase 4; accepted by the lead designer) | PLAN P4.1 asks a soak of 1 000 seeded rounds per mode. The versus builder's `tools/bots/soak.sh` (CPUs of all three levels on 2, 3 and 4 seats of every (mode, arena), a real `VersusMatch` with the default rules, the mode's rules checked on every tick) played 4 020 rounds and 5 562 673 ticks on the G3c rules with no engine error and no score against a mode's rules, and found three things: (1) two heroes falling side by side with overlapping bodies at the same height stomp EACH OTHER on one tick (the 1.0 body test: falling at 8 px a tick or more, any contact is a stomp, whoever is on top), each is lifted and bounces, both are immune springboards from then on, and the pair climbs out of the top of the arena for 8 s until the off-screen rule kills both (4 of 1 008 Grub Stack rounds); (2) a Cave-in block that settles in the edge column beside a hero lets the 1.0 collision slide him through it and out of the map, where no step leads back - on Echo Hollow he falls through the top-bottom seam until the gong, in play, out of every threat's reach; (3) a fast shot can end INSIDE the block over a goal mouth of Coconut Cove - the coconut at rest with its centre in a wall cell, in play, where no strike reaches it, and a golden coconut has no clock: the game never ends (2 of 1 002) | **accepted as built** (versus; `referee.gd` `_stomp_step` / `_squeezed_out`, `clubball.gd` `_wedged_step`; versus only): (1) **a stomp comes from above** - the stomper's feet are higher than his victim's; with level feet nobody stomps and nobody bounces, both fall on; one pixel higher is above (no tolerance band: a band would bring the mutual stomp back at its edge). It is the versus twin of "a stomp is a landing" [G15]. (2) **Nobody stays outside the arena's sides** - a hero in play whose feet are left or right of the arena view while the round runs, on an arena whose sides do not wrap, is knocked out as by a hazard (cause "crush", the Cave-in's own); it is the net under the block - no hero's own step and no knock-back takes him there, and it never fired in the 4 020 default rounds. (3) **A wedged coconut is lost** - at rest with its centre in a wall cell for `VersusClubball.WEDGED_TICKS` = 24 ticks in a row it leaves play and drops in again after `VersusTuning.BALL_RESET_TICKS`, as a coconut lost in the water does; nobody scores, a golden coconut stays golden. The constant is a net and no *(tune)* value: it stays in `clubball.gd`, outside D.12. Left for after 2.0.0: the causes - the block that pushes a hero through the map's edge, the flight that ends inside a wall (objects'). `tests/test_versus_rules.gd` 90 -> 96, each rule red without it. Rule (1) changes every hero-on-hero stomp, so every bot set re-rolls: the numbers of that re-proof are the builder's report (`build/engine_requests/wf12_versus_to_lead_design.txt` #2). **Also seen in the soak, no anomaly**: 37 of 1 008 Grub Stack rounds went to the Golden Drumstick, and on Tar Pulleys it falls onto the top of the pulley block, where the CPUs needed up to 1 214 ticks (50 s) to pick it up; 6 of 1 005 Last Caveman Standing rounds were draws and none reached the hard cap; no CPU stood idle longer than 179 ticks (E.2, E.4, E.6, P-C.14, G 13.10.2, G 13.10.6, PLAN 7 P4.1) |

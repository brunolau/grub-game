# PROPOSAL_C_BOLD.md - "Part Two: The Great Roast", the bold expansion

Proposal C of the expansion workflow (angle: **bold and new**). Status: design proposal, no code. It answers the
owner's request: 20 more levels, more bosses, something new for the game, a co-op mode in which the enemies and levels
**need** two players, and a same-device deathmatch that is genuinely fun.

Read with: `docs/expansion/RESEARCH_COOP.md` (co-op catalogue, the source of most co-op building blocks),
`docs/expansion/RESEARCH_VERSUS.md` (versus survey and combat kit), `docs/expansion/TECH_AUDIT.md` (the N-player
refactor, wave 0), `docs/spec/PHYSICS.md`, `docs/spec/GAMEPLAY.md` 12, `docs/LEVEL_DESIGN.md`, `docs/ARCHITECTURE.md`.
Where this proposal takes a different position from the research documents, it says so and gives the reason.

Units as everywhere in the project: tick = 1/24.2753 s ("22 ticks = one designer second"), px = logical pixel
(1 tile = 16 px), v16 = 1/16 px per tick. Gravity is 16 v16 per tick, terminal fall 192 v16 (12 px/tick), a held jump
rises 60 px, a head bounce with Up rises 105 px (PHYSICS.md 6, 9). Every new number below is marked *(tune)* when it is
a starting value for playtests rather than a derived one.

Engine cost scale: **S** = a few days inside one module, no contract change; **M** = a new object, state or AI with its
own tests; **L** = touches several modules or contracts, or needs new art.

Sections keep the brief's letters A-F; **C comes before B** because the bosses use the new systems.

---

## 0. The pitch in one page

**Part Two: The Great Roast.** At the end of the Way Home the tribe holds its feast - and a storm drake, sent by the
rival Sun Tribe, snatches the Great Roast, the everlasting drumstick of the village. The hero (and, in co-op, his
blue-loinclothed cousin) follows it east across the sea: **Coral Coast, Red Canyon, Tar Swamp, Sky Peaks and the Sun
Temple**, 20 new levels with 5 new bosses and a mini-boss.

Five ideas carry the expansion:

| # | Idea | One line |
|---|---|---|
| 1 | **The Weapon Belt** | the club is always on the belt, one special weapon rides on the back, one button swaps; every new stage starts with the club in hand, so a new stage needs **one** route proof per difficulty instead of one per weapon. Two new specials turn combat into traversal: the **Spear** sticks into bark boards as a step, the **Bola** ties an enemy into a bundle you can stand on |
| 2 | **Dino Rides** | a Raptor (speed, stampede auto-runs), a Rex (heavy: wades tar, bites enemies into food) and a Pterodactyl (flap flight). Mounts obey the hang-glider's contract (a hit removes the mount, never energy). In co-op every mount has **two seats**: driver and gunner |
| 3 | **Living stages** | tides that rise and fall on a clock, day and night that swap enemies and sun/moon blocks, rising tar and storm clouds to race, a stampede that chases the hero sideways, ropes, vines and zip-lines |
| 4 | **Co-op built from the club** | **Batter Up**: a hero curls into a ball and his partner clubs him across a gap like a coconut; **Brace Wall**: two crouching heroes stop a charging boss; pincer enemies, twin-window enemies, spirit revive, tribe lives. Every boss has a co-op form that two players must share |
| 5 | **Brawl: Grub Stack** | the versus flagship: food you grab stacks on your head (your score is a tower everyone can see), stomps steal from the top, tall towers make you slow, a contested cookpot banks food, the last 15 s are a Feast Rush. Plus **Clubball** (2v2 sport with a coconut), Last Caveman Standing and Hot Rock, with bots |

And one thread through all three modes: **Golden Eggs**. Every new level hides one; it is carried (no strikes, lower
jumps) and cracks if dropped from high, so bringing it to the exit is a small escort mission. Eggs hatch in the
**Hatchery** on the world map and unlock versus arenas, colours and the true ending. The same carry rules power the
co-op lantern, the versus Egg Heist and King-of-the-Feast style modes.

What stays: the 24.2753 Hz integer simulation, the hero's physics, the paging camera, the club, head bounces, hidden
spots, G-R-U-B-S, Beginner / Expert and the expert wall. Water still kills (no swimming: see 2.7). Part One plays
tick for tick as in 1.0.0; every recorded route keeps replaying unchanged.

---

## A. Campaign: 20 new levels

### A.1 Story and world map

- **Part One** stays as shipped. The Way Home still ends with THE END; a short post-credits scene follows (the feast,
  the drake, the stolen roast, "to be continued"). The 1.0 level files are not edited: Part Two attaches through the
  level registry and Flow (a new `part = 2` campaign table), so their route proofs cannot move.
- **Beginner players** reach Part Two too. The expert wall after 3-2 keeps its line ("To enter you must be an expert
  eater!") and now adds a raft on the shore: *"...but a raft goes east."* Beginner continues with World 5; Expert
  plays World 4, the Colossus and the Way Home first.
- **Part Two map**: the shipped world map is a sea with islands and a dotted route (`docs/media/map.png`); it
  continues east. A raft icon carries the hero marker from the jungle shore to a coral atoll (World 5), then to the
  red mainland (6), the delta swamp (7), the floating rocks above the canyon (8) and the temple on the summit (9).
  Island art is the shipped map art, recoloured per biome; the Hatchery nest sits on the atoll.
- **Second expert wall** before World 9 (the temple gate): *"Only expert eaters may enter the Sun Temple."* Beginner's
  Part Two ends with the Storm Drakes: the roast is back, the riders flee to the temple, and a Beginner ending card
  invites the player to try Expert - the original game's structure, kept.
- **Final ending** (Expert): the Sun Guardian falls, the Chieftain Twins give the roast back and the two tribes share
  the feast (ending screens; in co-op the two heroes fight over the last drumstick in the picture).
- Level select and level codes work for Part Two exactly as for Part One (a stage started from its code or the
  level select begins with the club; co-op continues from the save, no co-op codes - TECH_AUDIT 4.10).

### A.2 Structure, difficulty curve, Beginner / Expert, bonus stages and warps

**Count**: 20 new level files = 13 stages (9 main + 4 linked sub-stages) + 5 boss stages + 2 Feast Land bonus stages.
This is the counting of 1.0.0 (whose 15 files include Brute's Den, Colossus Hall, three bonus stages and the ending).

**Curve**: a 1-10 scale on which 1.0.0's 1-1 is 1, 3-2 is 5, 4-2 Obsidian Keep is 8 and the Colossus 8.5. Part Two
re-enters at about 4 (a returning Beginner comes from 3-2, an Expert from the Colossus; the first two stages re-teach
the core and introduce the belt), and ends at 9.5.

**Beginner / Expert**: Beginner plays worlds 5-8 (17 levels, last one the Storm Drakes); Expert plays all 20; World 9
is Expert-only (`min_difficulty = expert`). Inside every level, Expert adds enemies with the `expert` flag and tighter
clocks through `.expert` meta variants (`tide.expert`, `rise_speed.expert`, `autorun_speed.expert`).

**Bonus stages and warps**: two new Feast Lands behind hidden warps, as in 1.0: Feast Land D behind a Bola-bundle
climb in 5-2, Feast Land E behind a mushroom-spring shaft in 7-1b. Each returns to the stage after its source level
(GAMEPLAY 1.1 route logic).

### A.3 The 20 levels

Ids follow the 1.0 pattern (`w5_l1`, `w5_l1b` ...). Every stage hides one Golden Egg (2.6); a boss drops its egg.
"Co-op" names the signature co-op moment of the stage's co-op overlay (section D.6).

| # | Id | Name | Biome | Signature mechanic | Curve | Modes | Co-op signature |
|---|---|---|---|---|---|---|---|
| 1 | `w5_l1` | Shell Beach | coast | **Tide clock**: every 40 s *(tune)* the sea rises 3 rows for 15 s (surf foam 66 ticks ahead); low tide opens sandbars and tide-pool hidden spots, high tide floats shell rafts to the palm crowns. Teaches **Swap** and gives the **Spear** (found in a wreck) | 4 | B, E | Stone Plate holds a sluice shut so the partner crosses the pool at high tide; Shoulder Hop to palm-crown spots |
| 2 | `w5_l1b` | Coral Ropes | coast | **Swing ropes** between sea stacks over the surf, **vines** up the cliff faces, ink-spitting octopi; spear boards on drift-logs | 4.5 | B, E | **Batter Up** introduced: a line drive across the surf breaks the cliff wall that frees the partner's rope |
| 3 | `w5_l2` | Kraken Grotto | coast cave | Dark sea cave with glowing jellies, **shell rafts** on a cave river (ride platforms); the **Bola** (tie a jelly, step on the bundle); warp to **Feast Land D** up a bundle climb | 5 | B, E | **Glow Lantern** carry: the bearer lights a 4-tile circle and cannot strike, the partner fights in the light |
| 4 | `w5_l2b` | Kraken's Maw | coast | **Boss 3: the Kraken** (B.1) | 5 | B, E | paired tentacle slams, tentacle grab and rescue |
| 5 | `bonus_d` | Feast Land D: Coconut Raft | feast / coast | a raft of logs sails over fruit punch past palm islands full of spots; coconuts drop from the palms (giant bonuses) | - | B, E | Relay Bounce chains on punch-bowl crabs; giant coconuts for two |
| 6 | `w6_l1` | Stampede Mesa | canyon | **Auto-run**: a stampede's dust wall chases from the left (3 px/tick on foot); tumbleweed rollers; a **Raptor** pen at one third, then 5 px/tick on the mount | 5.5 | B, E | **Tandem Raptor**: the driver jumps the gap while the gunner clubs the overhead boulder in the same breath |
| 7 | `w6_l2` | Hoodoo Heights | canyon, vertical | climb a forest of rock towers: spear boards on dead trees, **zip-lines** down between towers, **updraft geysers**, eagle harriers | 6 | B, E | Pulley lifts and a bone see-saw; *(stretch)* the **Liana belay** (D.5) |
| 8 | `w6_l2b` | Tusker's Corral | canyon | **Boss 4: Old Tusker, the Boar King** (B.2) | 6 | B, E | **Brace Wall**: only two crouching heroes stop his charge |
| 9 | `w7_l1` | Firefly Bog | swamp, night | **Day / night clock**: dusk at the start, night falls; will-o-wisps wake at night, frogs sleep (and become springboards), lantern flowers show hidden spots; at dawn **sun bridges** turn solid | 6 | B, E | a firefly jar lights the way (lantern carry); Twinbond snakes in the reeds |
| 10 | `w7_l1b` | Sunken Hollows | mushroom cave | **Mushroom caps** in three colour-coded spring strengths; splitter slimes; spore puffers (a spore cloud jolts a standing hero like an earthquake, crouch to resist); warp to **Feast Land E** | 6.5 | B, E | the **mushroom see-saw** (a hard landing on one cap launches the partner) |
| 11 | `w7_l2` | Tar Pits | swamp, rising | **Rising tar** vertical race (`scroll = rise`); the **Rex** wades the shallow tar crust and bites enemies into food; vines up the sides | 7 | B, E | **Boulder Shove** (two heroes) plugs a tar vent and slows the rise; tandem Rex |
| 12 | `w7_l2b` | Croaker's Throne | swamp | **Boss 5: Old Croaker, the Bog Toad** (B.3) | 7 | B, E | **Gut Punch**: one hero is swallowed, the other strikes the glowing belly |
| 13 | `w8_l1` | Cloud Nests | sky | **Pterodactyl** flight across pterosaur nests (flap, glide, dive); harrier flocks; the Golden Egg sits in the biggest nest | 7 | B, E | **Pilot and Gunner** on one ptero |
| 14 | `w8_l1b` | Featherfall Drift | sky | **Low-gravity pollen** clouds (jumps twice as high, falls slow), drifting one-way clouds, glider **thermals** | 7 | B, E | Batter Up lobs between floating islands; Twin Drums on two islands |
| 15 | `bonus_e` | Feast Land E: Honey Clouds | feast / sky | honeycomb clouds and dripping syrup; honey floors make a hero stick for 6 ticks after landing *(tune)* | - | B, E | honey pots for two (twin window) |
| 16 | `w8_l2` | Thunder Spire | sky, rising | **Rising storm** vertical race up a spire; lightning strikes the tallest dead tree on a clock (cloud shadow and crackle 22 ticks ahead) | 7.5 | B, E | Shoulder Hops up the spire's chimneys while the storm rises |
| 17 | `w8_l2b` | Storm Eyrie | sky | **Boss 6: the Storm Drakes** (B.4) - the Beginner finale | 8 | B, E | the **mated pair**: hit both within the window or they heal each other |
| 18 | `w9_l1` | Sundial Steps | temple | **Sun gongs**: strike a gong to flip day and night; **sun blocks** are solid by day, **moon blocks** by night; mimic chests; ends with the **Chieftain Twins** mini-boss (B.6) | 8.5 | E | **Twin gongs** 17 columns apart must be struck within the window |
| 19 | `w9_l2` | Sun Citadel | temple | the gauntlet: crusher totems, Shellback guards, spear boards, ropes, sun beams that sweep on a clock, mirror plates | 9 | E | mirror plates: one holds the beam off, the other runs |
| 20 | `w9_l2b` | Hall of the Sun | temple | **Final boss: the Sun Guardian** (B.5); drops the Great Roast (trophy) -> ending | 9.5 | E | **pincer**: the shield always faces the nearer hero, the far one strikes the sun core |

Notes per stage (what the level designer must hit):

- **Shell Beach** is the re-entry tutorial: a sign for Swap before the first enemy, a spear board within two screens of
  the wreck, the first tide shown from a safe dune. Tide water is the shipped `~` water (deadly); the tide never rises
  where a hero can be trapped without a 3-row escape (validator rule, 6.3).
- **Stampede Mesa**: the dust wall kills (pit rule); the stage waits for the first input like Cinder Shaft; the
  Raptor pen is a checkpoint, and losing the Raptor in the run drops the speed back to 3 px/tick for 4 s *(tune)* so
  a hit is survivable.
- **Hoodoo Heights** is the vertical counterpart of Canopy Village: a 96-column tall map with zip-lines as the way
  *down* between towers and geysers as the way *up*.
- **Firefly Bog** runs one night of 1 760 ticks (72 s) between two dusks *(tune)*; every route must work in both
  phases (the route proof starts at a fixed phase; the clock is part of the deterministic state).
- **Tar Pits** rises at 1 px/tick (Expert 20 v16) from a checkpoint; a checkpoint resets the tar to 6 rows below it.
- **Sundial Steps** gives the player the clock: a gong strike flips the phase after a 22-tick blink of every
  sun/moon block, so the hero is never crushed (a block that would close on a hero waits until he leaves).

### A.4 Art per world (every world has real, free art)

All terrain is gradient-mapped from the 8 shipped 40-tile atlases (same layout and collision table), proven at 640 x 360
in `.tools/asset_candidates/expansion/_style_tests/` (`terrain_<biome>.png`, `biome_all.png`). Outlines of imported
sprites are recoloured to the anchor's #272018. Licences: CC0 unless marked.

| World | Terrain / backdrop | Props and objects | Enemies (skin source) | Boss / mount | Gaps and how they are filled |
|---|---|---|---|---|---|
| 5 Coral Coast | `terrain_coral` (gradient map of `jungle/terrain`); RPG-battle beach backdrop, horizon band cropped for the far layer; shipped jungle mid layer recoloured | shipped `platform_wood` + anchor log item = shell rafts and drift-logs; anchor turtle shell (item 18) as a raft prop; anchor spear (item 12) for the pick-up | shipped `turtle` (walker), Ninja Adventure small octopus and mollusc at 2x (spitter, walker), RPG-battle slime recoloured as jellies (dangler / bola target), shipped `bat_b` | Kraken = Ninja Adventure `Boss/SquidRed` at 2x + tentacle chain from `Boss/DragonGreen` segments recoloured coral | no underwater art -> there is no underwater play; tide foam = shipped splash FX |
| 6 Red Canyon | `terrain_canyon`; RPG-battle canyon backdrop 17 (paint out the two small towers) + Western FPS mesa strip at 2x as the mid layer + Emcee Flesher desert far layers (gradient-mapped warmer) | Western FPS cactus 1-3, rocks 1-6, tumbleweed, skull, bone, dead trees (spear boards = a bark panel drawn on `tree-1`); zip-line rope = 2 px line + anchor bone pegs | RPG-battle snake red and green (Twinbond pairs), RPG-battle dino/salamander (rolls into a ball = Roller), Sunny Land eagle at 2x (harrier, co-op snatcher), Western bear (stationary "cave bear" snapper), shipped `rival` (charger) | Old Tusker = RPG-battle boar, native 1x, recoloured shaggy brown, tusks lengthened, bone crown; Raptor mount = shipped `mini_rex` at 2x (as the Brute was made) | no mammoth or sabre-tooth: not used. Piglets = Ninja Adventure `Animal/WildBoar` at 2x |
| 7 Tar Swamp | `terrain_swamp` and `terrain_mushroom`; RPG-battle forest night backdrop, gradient-mapped; shipped jungle layers darkened for the near parallax | anchor vines, shipped `plant_b` props; mushroom caps from RPG-battle mushroom's cap frame as spring art; tar = `~` with a new `liquid = tar` skin (water body recoloured black-violet) | RPG-battle slime (splitter, two palettes), RPG-battle mushroom (spore puffer), RPG-battle bat, RPG-battle ghost (night-only wisp), Sunny Land frog (hopper), shipped `plant_b` (snapper) | Old Croaker = Ninja Adventure `Boss/GiantFrog` at 2x; Rex mount = shipped `rex.png` (1x, 152 x 112 cells, already sized for a rider) | no rideable dinosaur art -> rider composite: hero crouch frame 21 on a drawn saddle (scout recommendation) |
| 8 Sky Peaks | `terrain_sky` (cloud tops); RPG-battle sky backdrops + Superpowers Backgrounds sky islands (15 / 39) at 4x as the farthest layer only | anchor feathers / wings (43-46) as pollen and thermal markers; shipped springs; storm cloud band = recoloured `volcano_shaft` smoke band | shipped `pterodactyl` / `_b` (harrier, dart), Sunny Land eagle at 2x, RPG-battle bat | Storm Drakes = RPG-battle dragon, native 1x, both palettes (Thunder and Gale); Ptero mount = shipped `pterodactyl` at 2x | eagle boss missing -> not needed (the drakes are animated, side-view, native density) |
| 9 Sun Temple | `terrain_temple`; RPG-battle ruins / temple backdrop 21 (paint out the towers) | OPP2017 jungle-temple tiles as back-wall decor (CC0), Pixel Adventure 1 Rock Head (CC0) recoloured to a stone totem crusher, anchor six coloured crests as sun / moon block faces, mirror = anchor orb | RPG-battle reptile (Shellback: its GUARD animation; metal recoloured to bone), RPG-battle mimic (chest that bites), OPP2017 stone golem pieces (splitter variant), anchor `dragon-man` / `hunter` NPCs (Sun Priests: stationary spear throwers, idle loop + projectile) | Sun Guardian = RPG-battle giant (385 x 318 cells: idle, attack, attack2, hit), gradient-mapped to sandstone, sun-gem and sun-disk shield added; Chieftain Twins = shipped `rival.png` at 2x with masks composited from the anchor NPC heads | no animated golem or chief -> compositing as listed |
| Feast D / E | shipped feast atlases recoloured (punch, honey); RPG-battle beach band for D, sky band for E | Ninja Adventure food items and RPG-battle breads as new food pictures (food indices beyond 47 need a manifest row) | punch-bowl crabs = Ninja Adventure small crab-like monster at 2x; bees = shipped `insect` | - | - |

**Hero art for the new verbs** (assembled from the 52 shipped frames, as 1.0 did for its attack poses):

| Verb | Frames used | Edit |
|---|---|---|
| ride a mount | crouch 21 | saddle drawn per mount; legs masked |
| hang (rope, zip-line, Pterodactyl claws) | glide 50-51 (hanging under the glider) | glider sprite simply not drawn |
| climb vines | climb 44-47 (exists, back view) | none |
| carry overhead (egg, lantern, partner) | victory 48-49 (arms up) | club masked out, object composited |
| curl (Batter Up ball, versus turtle stance) | roll 24-26 | none |
| spirit (co-op downed) | death toss 39 | palette-shader "spirit" ramp per slot, 1 px wobble |
| new weapons (spear, bola) | the 52-frame sheet | two new weapon sheets composited the way 1.0 made `hero_axe.png` (loaded only when the weapon is on a belt, 3.5 below) |

### A.5 Audio per world (from the expansion audio staging, all CC0 unless marked)

| Context | Pick (alternate) |
|---|---|
| Coral Coast | Spring Spring "Sandy Seaside" (Tallbeard "Deep Blue" for Kraken Grotto) |
| Red Canyon | Wolfgang_ "Desert Theme" (Spring Spring "Suez Crisis Remade" for Hoodoo Heights) |
| Tar Swamp | Junkala Super Action stage_7 (Wolfgang_ "Haunted House" for night and the Hollows) |
| Sky Peaks | Wolfgang_ "Upbeat Overworld" (Spring Spring "Typhoon's Theme" for Thunder Spire) |
| Sun Temple | Junkala Super Action stage_9 (Tallbeard "Penultimate") |
| Feast D / E | Spring Spring "tropicalfantasy" / Tallbeard "Box Jump" |
| Bosses | nene Boss Battle #1 Kraken, #4 Tusker, #6 Croaker, #2 Drakes, #3 Sun Guardian; Centurion "Chipped urgency" (intro + loop) for the Chieftain Twins. The nene tracks are 3.3-3.6 min: re-encode at q0.4 or cut to two loops to stay inside the ~30 MB music budget |
| New effects | swap: Junkala interaction6; spear sticks: Kenney RPG creak3; bola: Spring Spring throw1 + Junkala interaction19; mount hop: Junkala interaction16 + Spring Spring enemyland; rope: Kenney creak1 + artisticdude light swishes; Batter Up: heavy swish + MoxieCat dashwoosh; curl: MoxieCat dashcharge; revive: Junkala powerup2; tide: rubberduck splash + bubbles; egg crack: Spring Spring crush |

### A.6 Enemy rosters of the new worlds (solo and co-op)

New solo archetypes (enemies module; each also has a co-op rule in D.3):

| Id | Behaviour | Where | Built on | Cost |
|---|---|---|---|---|
| `enemies/roller` | curls and rolls down slopes and along floors; a head bounce stops it, it uncurls for 44 ticks (hittable) | canyon (salamander), tumbleweed variant is intangible to strikes and only jumped | walker + item-like bounce | M |
| `enemies/splitter` | hit once -> two halves run apart; halves die in one hit (solo) | swamp slimes, temple golem pieces | dropper walker + spawn | M |
| `enemies/puffer` | stationary; every 88 ticks *(tune)* puffs a spore cloud (22-tick swell): a standing hero inside is jolted 16 px up like the earthquake rule, a crouching one is not | Sunken Hollows | snapper + shake jolt | S |
| `enemies/mimic` | a treasure chest (looks like `objects/container`); bites when a hero comes within 2 tiles from the front; dies to a hit from behind or a head bounce + strike | Sun Temple, one in Feast E as a joke | snapper with a facing test | S |
| `enemies/shellback` | patrols; the shield faces the hero (turn time 8 ticks solo *(tune)*), front hits glance with the Colossus clank; hit from behind, or jump over and strike before it turns | Sun Temple (solo), every world in co-op (D.3) | walker + `accepts_hit_from()` (TECH_AUDIT 4.8) | S |
| `enemies/crusher` | a stone totem that rises 3 rows and slams down on a cycle (eyes glow 14 ticks before the slam); its flat top is a platform; a slam shakes the screen | Sun Citadel | `objects/column` motion + hazard | S |
| `enemies/wisp` | night-only flyer (`phase=night`); drifts in a figure-8; harmless by day (not drawn, not targetable) | Firefly Bog | flyer + clock flag | S |
| `enemies/priest` | stationary spear thrower; throws a slow spear (12 ticks wind-up flash) that sticks in walls as a 9-s step | Sun Temple | snapper + hero spear projectile reused | S |

Skins only (existing archetypes, new pictures): octopus spitter = `dart` with a horizontal path, jellies =
`dangler`, eagles = `harrier`, cave bear = `snapper`, frogs = `hopper`, punch-bowl crabs = `dropper`, piglets = `dropper`.

---

## C. Something new: six systems for everyone

Ordered by how much they change play. Each: rules, why it fits Prehistorik 2's feel, engine cost.

### C.1 The Weapon Belt (and the rule that keeps 20 levels provable)

**The problem.** Today a stage must be proven with every weapon a run can bring into it (LEVEL_DESIGN 10): 72 route
files for 15 stages. Part Two comes after all four weapons are in play and adds two more; per-weapon proofs would
mean up to 6 routes x 2 difficulties x 20 levels = 240 solo routes, and co-op weapon pairs multiply that again.

**Rules.**

1. The belt holds the **club** (always there, cannot be lost) and **one special** (hammer, axe, swirling axe, spear,
   bola, or nothing). The **active** weapon is what Strike uses.
2. **Swap** (new action) toggles club <-> special, instantly, on the ground or in the air, not during a strike's
   attack gate. A 2-tick *(tune)* draw lock stops strike-swap-strike from beating the hammer's 6-tick recovery.
3. Picking up a weapon item puts it in the special slot **and makes it active** (exactly 1.0's effect on the active
   weapon). Picking up the club item makes the club active and keeps the special. The previous special is replaced,
   not dropped (no spawned item, so no change of registration serials in Part One).
4. **Part Two stages start with the club in hand** (meta `belt = fresh`, the default of format-2 files); the special
   rides on the hero's back. Part One stages keep `belt = carry` (absent key = 1.0 rule): the hero enters with the
   weapon that was active.
5. A Part Two stage must be finishable with the club alone. It may *require* a thrown weapon only where it supplies one
   in the stage (the Colossus precedent: an axe at the checkpoint). Bosses must be beatable with the club alone.

**Why the proof matrix collapses.** With rule 4 every Part Two stage begins in the same state whatever the run carries:
club active, special inert. The special changes nothing in the simulation until Swap is pressed (the sheet on the
back is cosmetic). So **one route per (stage, difficulty)** proves the stage for every belt. A new permanent test,
`belt invariance`, replays every Part Two route with each of the 6 possible specials in the slot and demands identical
per-tick digests (the digest of TECH_AUDIT 4.12): 6 automatic replays, no extra route files. Count: 17 stages x 2
difficulties + 3 Expert-only = **37 solo routes** for Part Two, instead of up to 240. Optional routes for special-only
secrets (a spear-board shortcut, an egg reached by bola bundles) are recorded like today's `.secret` routes.

**Consequences for Part One (the 15 shipped levels).**

- Their files are not touched and all 72 routes replay tick for tick: route files never contain the new Swap key, a
  pick-up still sets the active weapon exactly as 1.0 set `Game.weapon`, and nothing is spawned or dropped.
- The new freedom (swap to the club and back) is already covered: every Part One stage has a proven club route, and
  a swap only moves the hero between states that 1.0's proofs cover per weapon.
- The spear and bola can never be active in a Part One stage (Part Two comes later; level select starts with the
  club). Co-op uses `belt = fresh` everywhere (D.6), Part One included.
- Visible change: a belt icon on the HUD (active weapon big, special small) and a Swap prompt. An option *Classic
  weapons* hides Swap in Part One for purists.
- Contract: `Game.weapon` keeps its frozen meaning (the active weapon, an alias of `runs[0].weapon` after wave 0);
  `PlayerRun.special` is appended; `Events.weapon_changed` fires on swap as on a pick-up.

**The two new specials.**

| Weapon | Rules | Fit | Cost |
|---|---|---|---|
| **Spear** | thrown flat at 12 px/tick for 8 ticks, then drops (+16 v16 per tick); power 25; at most 2 in flight or stuck. Into an enemy: a normal hit. Into a **bark board** (`objects/peg_board`, a wooden panel the designer places on trees, drift-logs and walls): it sticks horizontally and becomes a **one-tile one-way platform** for 220 ticks (9 s), blinking for the last 22, then falls. Into any other wall: clatters, drops and returns to the belt after 66 ticks. Anchor item 12 is the pick-up | a hunter's tool; like the head bounce, it turns an attack into a foothold. Boards are designer-placed, so a spear never breaks a climb the designer did not plan | M (projectile + a timed `PlatformBase`; counts against the 16-platform budget, hence the cap of 2) |
| **Bola** | thrown in the axe's arc; power 0 against hp; any non-boss enemy with hp < 75 it touches is **tied into a bundle** for 132 ticks (flashes the last 22): the bundle falls with item physics and lands as a solid 1 x 1 block (a sprite platform) - a step, a bridge plug, a shield. A bundle that falls into a pit or liquid kills its enemy (score). At most 2 bundles. On bosses it ties a limb: Old Tusker trips mid-charge (dazed 44 ticks), a Storm Drake loses its next swoop | turns enemies into scenery to stand on - the same idea as "heads are springboards", one step further | M (enemy "bundled" state in `EnemyBase` + a platform proxy) |

### C.2 Dino Rides (mounts)

**Rules (all mounts).**

- A mount waits at a **pen** (`objects/mount kind=raptor|rex|ptero`). The hero mounts by landing on its saddle from
  above (the stomp test of PHYSICS 2.2, which on a mount means "sit" instead of "bounce"); Down + Jump dismounts.
- **The glider contract** (GAMEPLAY 8.4): while mounted the hero cannot strike with his own weapon; a hit **removes the
  mount** (it bolts off screen and returns to its pen after 132 ticks) and costs **no energy**; the mount is gone at
  the stage's end. Pits, spikes and liquids still kill unless the mount's row below says otherwise.
- Mounts are **stage-local** (never carried between stages), so they add no route matrix.
- Each mount has its own tuning table (`MountTuning`, owned by the player module), integer and deterministic, and
  moves at most 12 px per tick, inside the doze reach argument (ARCHITECTURE 11.1: 18 px per tick).
- **Two seats** (co-op, D.4): the second hero who lands on an occupied mount takes the **gunner** seat: he cannot
  steer but can strike and throw with his own belt; the driver moves and uses the mount's own attack.

| Mount | Movement *(tune)* | Own attack | Special rule | Stages |
|---|---|---|---|---|
| **Raptor** (shipped `mini_rex` at 2x) | accelerates 16 v16/tick to 112 v16 (7 px/tick); jump impulse chosen for an 80 px apex and a 9-tile running gap; skids like the hero on ice | none (head bounces kill small enemies outright instead of bouncing) | runs in auto-run stages at the scroll speed + 2 px/tick | Stampede Mesa, Thunder Spire (a pen half-way) |
| **Rex** (shipped `rex.png`, 1x) | walk 48 v16 (3 px/tick); jump apex 32 px (2 tiles) | **Bite** (Strike): a box 0..40 px in front, knee to head; an enemy with hp < 50 is **eaten** and pays its score plus a food bonus (the game is about eating); a landing from 4+ rows is a **stomp quake**: ground enemies on screen are dazed 44 ticks, standing heroes jolted (existing shake) | walks over floor spikes `^` and wades `liquid = tar` rows marked shallow (`tar_depth = 1`) | Tar Pits, Firefly Bog (Expert pen) |
| **Pterodactyl** (shipped `pterodactyl` at 2x) | Jump = **flap**: yvel = -96 (rises about 36 px); gravity 8 v16/tick, fall capped at 4 px/tick; air speed 64 v16 (4 px/tick); 6 flaps, then it must touch ground or a nest for 22 ticks to rest | **Dive** (Down): claws first at 8 px/tick, a stomp that kills small enemies | wind and updrafts move it; the hero dangles from its claws (hang pose 50-51) | Cloud Nests, Storm Eyrie (optional, Expert) |

**Why it fits.** Prehistorik 2 already has one vehicle, the hang-glider, with a take-off run, a skill ceiling and a
gentle failure (a hit removes it). Mounts are three more vehicles under that same contract; the hero's physics never
changes. Riding dinosaurs is also the oldest caveman fantasy the original never delivered.

**Cost.** L: player module (mounted state, input hand-over, `MountTuning`, three physics tables, seat logic), objects
(`objects/mount` pens), art (three rider composites), route proofs for the mount stages, a test pinning each mount's
jump table like `PHYSICS_REFERENCE.json` pins the hero's.

### C.3 Ropes, vines and zip-lines

| Object | Rules *(tune)* | Built on |
|---|---|---|
| `objects/vine` (rect of climbable cells) | Up at a vine grabs it; climb Up / Down at 2 px/tick (climb frames 44-47); Left / Right + Jump leaps off sideways (a normal jump); a strike is not possible while climbing; enemies can share the vine (a lurker sliding down it) | a zone + a hero CLIMB state |
| `objects/rope` (`length` px, anchor at the top) | a hero who jumps into the rope's lower half grabs it (hang pose 50-51); the rope swings on the **integer pendulum table the swinger enemy already uses**; Left / Right on the swing direction pumps it one amplitude step per half cycle up to its maximum; Jump releases with the rope's current velocity (table difference, converted to v16); Up / Down climbs the rope | `enemies/swinger` pendulum math, hero HANG state |
| `objects/zipline` (`from=c,r to=c,r`) | the hero jumps into the line, hangs and slides down it, accelerating 4 v16/tick to 96 v16 (6 px/tick); Jump or Down lets go; an enemy on the line is knocked off; the line is one-way (downhill) | a path platform (`PlatformBase` ride rules with the hero hanging) |

Why it fits: the hero sheet already contains a climb cycle the original never used and a hanging pose; Prehistorik's
danglers and swingers already move on threads, so the world's physics already "has ropes". Cost: M (objects + two hero
states that only these objects enter, so Part One code paths are untouched).

### C.4 Moving stages: auto-run and the rising race

- **`scroll = autorun`**: the view moves right at `autorun_speed` v16 (default 48 = 3 px/tick), changed by
  `zones/scroll_speed rect=... speed=...`; the left edge is deadly (drawn as stampede dust, the Cinder Shaft smoke band
  turned on its side); the right edge is the normal level edge. It waits for the first input, like Cinder Shaft.
  `zones/autoscroll_stop` ends it at the end of the run. While no hero is mounted in a mount section, the speed falls
  back to the on-foot value for 4 s *(tune)*, so losing the mount to a hit is survivable.
- **`scroll = rise`**: the view rises at `rise_speed` (default 16 v16 = 1 px/tick) and a deadly band follows at the
  bottom edge, drawn as the rising liquid (tar, lava, storm cloud); the mirror of Cinder Shaft's sinking view.
- Why it fits: the original already has one auto-scrolling stage (the tree descent); two more directions make the
  stages feel different without touching the hero. A vertical *climb* race is the most-requested shape the original
  lacks.
- Cost: M (world module camera modes; the deadly edge reuses the auto-scroll rules of PHYSICS 12 and GAMEPLAY 7.11).
  In co-op the tribe camera is replaced by the scroll and a hero left behind becomes a spirit (D.2).

### C.5 Stage clocks: tide, day and night, sun and moon

One `LevelClock` (world module) driven by `Sim.tick`, so every clock is deterministic and part of the digest:

- **Tide** (`objects/tide rows=c,r,w,h period=... high=...`): sets the `~` cells of its rows on and off with
  `TileGrid.set_cell` (the call breakable blocks use), with foam 66 ticks ahead. Water is still deadly; the tide moves
  *where* water is.
- **Day / night** (`clock = day:1760,night:1760` meta, `clock_start`): the night palette exists (`zones/dark`); any
  entity may carry `phase=day|night`: off-phase entities are not drawn, not targetable and do not tick their AI
  (frogs asleep become springboards, wisps wake). Hidden spots with `phase=night` glint only at night.
- **Sun and moon blocks** (`objects/phase_block phase=sun|moon size=w,h`): solid in their phase; 22 ticks of blinking
  before a change; a block never closes on a hero (it waits a tick at a time).
- **Gongs** (`objects/gong`, a hittable): flip the phase on a strike (Sundial Steps, the Sun Guardian).

Why it fits: the original has darkness switches (GAMEPLAY 7.10) and a scripted blizzard; a clock just schedules them.
Cost: M.

### C.6 Golden Eggs and the Hatchery (the meta-goal)

- Each of the 20 levels holds **one Golden Egg** (anchor cracked-egg item 55 recoloured gold; boss stages: the boss
  drops it): 20 in all; the Hatchery counts each egg once per save, whatever the difficulty.
- **Carry rules** (one carry system shared with co-op and versus): the egg is held overhead (victory frames); no
  strikes, jump impulses at 3/4, walk at 4 px/tick; a hit drops it (it bounces like a giant bonus and can be picked up
  again); a fall of 6+ rows while carried or loose **cracks** it and it returns to its pedestal after 66 ticks.
  Reaching the exit with it banks it. Gates and checkpoints keep it; a death returns it to its pedestal.
- **Hatchery** (world map screen): banked eggs hatch into baby dinos that wander the nest. Every 4 eggs unlock
  something: 4 = hero colours 5-8; 8 = the *Sun Dial* versus arena; 12 = the *Big Bounce* and *Lights Out* variants;
  16 = the Ptero Joust mode (if shipped) and co-op headgear; 20 = the true ending painting and a cosmetic golden club.
  Options > Brawl > *Unlock everything* exists for parties.
- Why it fits: Prehistorik's secrets are about greed and risk (spots, letters, warps); an egg you must protect is a
  greedy risk that changes how you play the stage. Cost: S-M (item + carry state + Save field + one UI screen).

### C.7 Deliberately not proposed

- **Swimming**: water is death in the original and in 1.0; swimming would add a second physics model and slow the
  game down. The tide, rafts and the Kraken give the coast its sea without it.
- **Reversed gravity**: hero collision is built on one-way floors, a head probe and a feet point (PHYSICS 2-6);
  upside-down play would double the physics spec. Low-gravity pollen (`zones/low_gravity`: gravity 8 v16/tick,
  terminal 96 v16) and updraft geysers (`zones/updraft power=...`, glider thermals) deliver the "gravity trick" with
  two constants in a zone, and only inside Part Two.
- **A sixth hero physics class**: all heroes share one physics in every mode (co-op principle 9 of RESEARCH_COOP).

---

## B. Bosses

Six new fights (five bosses and a mini-boss) plus co-op versions of the Brute and the Colossus. Every boss follows the
1.0 fairness rules pinned by `tests/test_enemies_colossus.gd`: every attack telegraphed 10+ ticks ahead, no stun-lock,
the hit cooldown of 22 ticks per boss (`BOSS_HIT_COOLDOWN`), beatable with the club alone (C.1 rule 5). A boss hit
costs one bone (GAMEPLAY 6). Co-op versions have about +25 % hp and **one rule that only two heroes can satisfy**; the
validator's solo search (D.7) must fail to beat each co-op version alone.

### B.1 The Kraken - Kraken's Maw (`w5_l2b`)

- **Sprite**: Ninja Adventure `Boss/SquidRed` (front-facing: idle, walk, attack, shoot, hit) at 2x, outline
  #272018; tentacles are chains of `Boss/DragonGreen` body segments recoloured coral with the squid's own arm tip as
  the last segment; ink = shipped explosion puffs recoloured.
- **Arena**: one locked screen. Sea (`~`) in rows 9-10; three shell rafts (ride platforms bobbing 4 px) on row 8 at
  columns 2-5, 8-11 and 14-17; two rock ledges on row 5 at the sides. The Kraken rises behind the water at the back
  (columns 7-12); its head is out of club reach except when it lowers.
- **hp**: 48 (co-op 60).
- **Phase 1 - Slam**: a tentacle rises behind a raft (ripples and a shadow on the raft, 14 ticks), slams across it
  (a hero there: thrown, one bone) and lies there for 30 ticks: **its tip is the weak point**. The raft dips one row
  while it is pinned.
- **Phase 2 - Ink** (hp < 33): the shoot animation glows 12 ticks, an ink blob arcs to a raft and leaves a slick
  (braking as on ice x2 for 132 ticks). After every third tentacle hit the head **droops to the water line** for 44
  ticks: a head bounce, or a thrown weapon into the eye, counts double.
- **Phase 3 - Whirlpool** (hp < 17): the rafts circle on a loop (2 px/tick); two tentacles slam at once.
- **Solo**: hop rafts, strike tips, punish the droop.
- **Co-op**: tentacles slam **in pairs on the two outer rafts** (12 columns apart) and are hurt only when **both tips
  are struck within the twin window** (12 ticks Expert / 24 Beginner); otherwise both regrow. A slam on an empty raft
  sweeps sideways and **grabs** the hero who hit last, lifting him over the water: the partner strikes the grabbing
  tip to free him (after 88 ticks he is dropped into the sea and becomes a spirit). The droop becomes **bounce and
  bonk**: one hero's head bounce pops the eye open for 22 ticks, and only the partner's strike on the open eye counts
  (x3).

### B.2 Old Tusker, the Boar King - Tusker's Corral (`w6_l2b`)

- **Sprite**: RPG-battle `monster/boar` (239 x 178 cells: idle, walk, charge, spin-ball, hit, death; two palettes) at
  native 1x - about 2.5 times the hero's height; recoloured shaggy brown, tusks lengthened, a bone crown; palette 2 for
  the enraged phase. Piglets: Ninja Adventure `WildBoar` at 2x.
- **Arena**: a 20 x 11 corral, fence `|` walls, two rock pillars (2 x 3 tiles, six hits each, regrow per phase) at
  columns 5 and 14, two one-way ledges at row 7.
- **hp**: 64 (co-op 80).
- **Phase 1 - Charge**: paws the ground 22 ticks (dust, snort, head lowered), charges at 9 px/tick toward its target's
  side. Its body is 3 rows tall: a held jump (60 px) clears it. Into a pillar or the fence: **dazed 44 ticks**
  (stars), its **back and hindquarters** are the weak point; the tusks glance with a clank.
- **Phase 2 - Spin-ball** (hp < 40): curls (14-tick roll-up), bounces around the corral three times in arcs 4 rows
  high (a shadow marks each landing 10 ticks ahead), unrolls dizzy for 30 ticks.
- **Phase 3 - Stampede** (hp < 20): two piglets drop in and Tusker charges twice in a row; every spin-ball landing
  shakes the screen (crouch to keep footing - the earthquake rule).
- **Bola**: a bola on its legs trips the next charge (dazed 44 ticks): a reward for carrying it.
- **Solo**: bait the charge into a pillar or the fence.
- **Co-op**: the co-op corral has **springy fences and no pillars** - charges bounce back and never daze. The only
  stop is the **Brace Wall**: two heroes crouching (braced) within one tile of each other in his path stop him dead;
  he rears up dazed 44 ticks with both flanks open. A lone braced hero is trampled (thrown, one bone). The 22-tick paw
  gives the pair time to line up. In phase 2 a **charged strike bats the spin-ball** into the fence (dazed); phase-3
  piglets go for the hero farther from his partner (lone-wolf rule).

### B.3 Old Croaker, the Bog Toad - Croaker's Throne (`w7_l2b`)

- **Sprite**: Ninja Adventure `Boss/GiantFrog` (idle, jump, tongue, charge, hit; `GiantFrog2` as the damaged palette)
  at 2x; the tongue is a pink strip built from the sprite's own tongue frame in 16-px pieces.
- **Arena**: tar pit (`liquid = tar`) in rows 9-10, mud banks at columns 0-4 and 15-19, four lily-pad drop platforms,
  Croaker on a log in the middle (columns 8-11). Night palette, cosmetic fireflies.
- **hp**: 56 (co-op 70).
- **Tongue lash**: the throat swells 12 ticks, low (knee height: jump) or high (head height: crouch) - two readable
  swell shapes; the tongue stays out 16 ticks: **strike its tip** -> Croaker gags 30 ticks with the mouth open (a
  thrown weapon into the mouth counts double).
- **Belly flop**: crouches 22 ticks with a growing shadow, lands on one side; the pads there sink for 66 ticks.
- **Inhale** (hp < 37): wind toward the mouth at up to 3 px/tick for 44 ticks (crouch to brace - the blizzard rule);
  a hero who reaches the mouth is swallowed and spat out 66 ticks later with one heart less.
- **Tar spit** (hp < 19): two splitter slimes per spit.
- **Solo**: tongue tips, mouth throws during the gag, brace through the inhale.
- **Co-op - Gut Punch**: tongue hits only stun (no damage). The inhale targets the nearer hero; a **swallowed** hero
  (hidden, frozen, safe) pushes Left / Right to move a glowing bulge on the belly; for 66 ticks Croaker is full (no
  tongue, no jumps) and only the partner's strike **on the glowing bulge** hurts it (x3) and makes it cough the hero
  out unharmed. If the partner fails, the swallowed hero is spat out with one heart less. Two roles that swap every
  cycle: the bait and the puncher.

### B.4 The Storm Drakes - Storm Eyrie (`w8_l2b`, the Beginner finale)

- **Sprite**: RPG-battle `monster/dragon` (258 x 209 cells: idle, rise, claw, roar/breath, hit), native 1x, in both
  palettes: **Thunder** (solo) and its mate **Gale** (co-op). Lightning = a drawn bolt strip + recoloured explosion.
- **Arena**: a locked sky screen: cloud one-way tiers on rows 4, 7 and 10 with gaps (a fall is a pit death), two
  springs; the drake flies a figure-eight of waypoints (harrier logic) through the upper half.
- **hp**: 64 (co-op 2 x 48).
- **Swoop**: wings up and a screech for 14 ticks, then a dive along one tier (its shadow line on the cloud shows which).
- **Breath** (hp < 43): roars 18 ticks, then a stream sweeps one tier horizontally: change tiers.
- **Lightning** (hp < 22): a cloud darkens for 22 ticks, a bolt strikes it and the cloud is gone for 66 ticks (a drop
  platform).
- **Weak point**: after every swoop it **perches** on a cloud for 33 ticks, head low: strike the head (a bounce on its
  back is a safe springboard, no damage, as on the Brute).
- **Expert option**: a Pterodactyl pen at the arena's side; mounted, the hero can chase the drake in the air.
- **Co-op - the mated pair**: Thunder and Gale perch **at the same time on opposite sides** (columns 2 and 17); a hit
  on one makes the other screech and **heal it** unless both heads are struck within the twin window. Gale's breath is
  a gale (wind as in Blizzard Pass: crouch to brace) while Thunder throws lightning, so the pair splits roles each
  round: one braces against the wind and guards, the other dodges the bolts and strikes.

### B.5 The Sun Guardian - Hall of the Sun (`w9_l2b`, final boss, Expert)

- **Sprite**: RPG-battle `monster/giant` (caped mace-and-shield brute, 385 x 318 cells: idle, attack, attack2, hit) at
  native 1x, gradient-mapped to sandstone (metal recoloured to stone and bone, per the scout), a glowing amber
  **sun-gem** on the forehead and a sun-disk shield added; shockwaves = recoloured dust and ring FX.
- **Arena**: the temple hall, 20 x 11, two roof windows with sun beams, a **gong** on each side ledge (row 6, columns
  1 and 18) that flips day and night (C.5).
- **hp**: 72 (co-op 90).
- **Phase 1 - Mace**: raises the mace 18 ticks (shadow), slams: a shockwave rolls both ways along the floor at 4
  px/tick (jump it). The mace stays stuck 30 ticks and its handle is a **slope platform**: run up it and strike the
  **sun-gem** (weak point). Shield bash: the shield turns to the nearer hero and he steps forward; hits on it clank.
- **Phase 2 - Sun beam** (hp < 48): the gem glows 22 ticks, then a beam sweeps the floor at knee height (jump it).
  By night (strike a gong) the beam cannot fire, but the mace leaves burning moon-fire on the floor for 66 ticks.
  The player chooses the hazard.
- **Phase 3 - Sky stones** (hp < 24): stomps shake the hall; sun stones rattle 14 ticks in the ceiling and fall (the
  stalactite rule of the Colossus).
- **Solo**: bait the slam, run up the mace, use the gongs to pick the safer phase.
- **Co-op - pincer**: the shield **always faces the nearer hero**, and while it is raised a crack in the cape opens on
  the guardian's back - the **sun core**, the only co-op weak point (the gem only stuns). The far hero strikes the core
  while the near one draws the shield. Phase 2: the gongs become **twin gongs** (17 columns apart, struck within the
  window to flip). Phase 3: the guardian **grabs** the hero who hit it last and squeezes one bone per 44 ticks; a hit
  on the core drops him.

### B.6 Mini-boss: the Chieftain Twins - end of Sundial Steps (`w9_l1`)

- **Sprite**: shipped `rival.png` (full caveman set: idle, walk, jump, fall, land, roll, crouch, attack, hurt, death) at
  2x (how the Brute was made) in a sun-orange and a moon-blue palette, with masks composited from the anchor pack's
  `dragon-man` and `hunter` NPC heads.
- **hp**: 2 x 24. Arena: a walled 20 x 11 terrace.
- **They play our co-op against us**: a **Shoulder Hop** off each other to reach the hero's ledge; a **Totem Stack**
  whose top twin throws spears; **Batter Up** (one curls 18 ticks, the other winds up 10 ticks and bats him across the
  terrace at the hero); and **revive**: a knocked-out twin becomes a spirit that the other revives by bouncing on it -
  unless the hero strikes the spirit first, which pops it for good.
- **Solo**: separate them (apart by more than 8 columns they hesitate and call each other), then race to the spirit.
- **Co-op**: their revive window is shorter (44 ticks) and the spirit flees the nearer hero, so one hero guards the
  spirit's path while the other keeps the second twin busy.
- First thing to cut if the boss budget shrinks (F.3).

### B.7 The Brute and the Wall Colossus in co-op

- **Brute (Brute's Den, co-op overlay)**: hp 64 -> 80. It **faces the hero who hit it last** and holds its arm guard
  over the head while it faces a hero within 4 tiles (the existing guard pose blocks club and thrown weapons from
  that side). With one hero it would always face him: the co-op Brute is unbeatable alone, by design. The partner
  behind it has the open head. Under 50 % it adds the **Grab** (squeezes one bone per 44 ticks; a head hit drops him).
  A stacked rider (Totem Stack) reaches the head with a forward strike - a second answer next to the high strike and
  the thrown axe.
- **Wall Colossus (Colossus Hall, co-op overlay)**: a stone **visor** covers its face; it lifts while a hero stands on
  the matching **Stone Plate** at one side of the hall. Rocks are spat at the plate holder and stalactites rattle over
  the thrower, so both are busy. Only thrown weapons hurt the head (unchanged); the checkpoint places **two axes**.
  Every rage pose (the 1st hit and every 4th) moves the active chain to the other side: the roles swap. Fairness tests
  per hero.

---

## D. Co-op: the tribe

### D.1 Player count, camera, joining

- **Two players**, designed and tested; the engine is built for four (TECH_AUDIT), and 3-4 heroes on co-op levels are
  a later "party" option without co-op gates. Two heroes keep every gate pairwise, fit one keyboard and one tablet, and
  keep the 20 x 11 view readable (RESEARCH_COOP 6.1).
- **Camera**: the **tribe camera** (TECH_AUDIT 4.5 option B, RESEARCH_COOP 5.2): one shared paging camera on the
  group, edge walls for the leader, Look claims the camera, no zoom, no split screen. Auto-run and rising stages
  replace it with their scroll. Mounts in co-op are **tandem** (both heroes on one mount, D.4), which keeps the pair
  inside one view where the camera moves fastest.
- **Leash**: a hero off-screen for 3 s (Expert) / 5 s (Beginner) becomes a **spirit** (D.2) next to his partner - no
  life lost.
- **Joining**: Title -> Play -> Solo / **Co-op** / Brawl. The Tribe Gathering screen: press Jump on any device to take a
  slot, key test lights for shared keyboards, colour, ready. Joining or leaving mid-stage restarts the stage from the
  checkpoint in the other layout (co-op stages hold different entities). The co-op campaign has its own save,
  progress and high-score table.
- **Colours**: P1 the shipped yellow loincloth, P2 blue, P3 pink, P4 green (white on jungle-heavy stages), from the
  scout's `hero_colours` mapping but drawn by a **palette-swap shader** (TECH_AUDIT 5.3: baking sheets would cost
  17.7 MB per colour), always with a "P1"-"P4" tag and a colour arrow above the head when heroes overlap.
- **Talking without voice chat**: double-tap Look shows an emote bubble above the hero (Ninja Adventure emotes: "!",
  "?", heart, angry) - for "come here", "wait", "sorry".

### D.2 Lives, revive, score

- **Tribe lives**: one shared pool, starting like solo (the counter shows 2); a life is lost only on a **team wipe**
  (both heroes down at once). Both then respawn at the checkpoint, enemies reset as today.
- **Spirit revive** (this proposal's version of RESEARCH_COOP R1; the egg is taken by the Golden Eggs): a hero who dies
  while the partner stands plays the death toss, then floats back as a **spirit** in his colour that follows the
  partner and can be nudged Left / Right. The partner revives him by **bouncing on the spirit** (easiest), striking it,
  or touching a checkpoint. Revived: 2 hearts (Beginner) / 1 heart (Expert), 44 ticks of blinking; his own
  "since last death" tally list is lost. Expert: a spirit not revived within 10 s drifts to the checkpoint and waits.
- **The spirit has a job**: hidden spots within 2 tiles of a spirit **glint**. The downed player keeps playing as a
  scout; he cannot touch plates, items or enemies, so he can never solve a gate.
- **Voluntary spirit**: hold Down + Look for 1 s to become a spirit and be carried through a stretch you cannot do
  (NSMB's bubble lesson).
- **Score**: one shared **tribe score**, one co-op high-score table. The tally adds per-hero medals: *Glutton* (most
  food), *Pogo* (longest bounce chain), *Slugger* (Batter Up launches), *Guardian* (spirits revived), *Butterfingers*
  (eggs dropped). A *Rival* switch (Options) splits the score for families that want competition on co-op stages.
- Bones picked up at full energy fly to the partner; a placed heart stays when the picker is full (original rule), so
  the partner can take it.

### D.3 Every existing enemy archetype in co-op

Shared rules (from TECH_AUDIT 4.1 / 4.8): an enemy's target is the nearest living hero (ties to the lower slot),
despawn needs every hero far away, zone spawners trigger on any hero, the active cap stays 12, ordinary hp stays (two
heroes already double the damage), and the world resets only on a team wipe. Co-op-only entities carry the `coop`
flag (skipped before spawn in solo, so no registration serial moves).

| Archetype (GAMEPLAY 5.2) | Co-op change of the shipped enemy | Co-op-only variant (art) | Why the variant needs two |
|---|---|---|---|
| 0 Dropper | drops alternate between the heroes inside the zone; `max` x1.5 | **Pack Drop** (shipped `egg_kid_b`): drops in bonded pairs, one beside each hero | the pair must die within the twin window (C3 Twinbond) |
| 1 Decoration | none | - | - |
| 2 Dangler | none; its thread can be clubbed | **Snatcher Bat** (RPG-battle bat): grabs a hero touching it from below and reels him up toward ceiling spikes at 1 px/tick | the grabbed hero cannot strike; the partner must hit the bat (high strike, throw or Shoulder Hop) |
| 3 Lurker | drops when any hero is in range, chases the hero it lands nearest | **Leech** (shipped `insect_b`): lands on a hero's back and drains one bone per 44 ticks | a hero cannot hit his own back; the partner clubs it off (it falls off alone after 220 ticks) |
| 4 Swinger | none | **Pendulum Stone**: a swinging stone a hero can ride, started only by a strike on its rope peg high on the wall | the rider cannot reach the peg; the partner starts it |
| 5 Stinger | dives at its target | **Hive Stinger** (shipped `insect`): targets the hero farther from his partner | stay together or be picked off (lone-wolf pattern) |
| 6 Harrier | circles its target, switches target every loop | **Harrier Pair** (Sunny Land eagles): circle at 6 tiles up, out of solo reach | only a Totem Stack rider's high strike or a Batter Up lob reaches them |
| 7 Dart | aims at its target at launch | - (darts aim at the lone wolf on Expert) | - |
| 8 Hopper | hops at its target | **Dodger** (RPG-battle dino; RESEARCH_COOP's "Raptor", renamed to keep the name free for the mount): hops back from any wind-up within 48 px, jumps low throws | a head bounce dazes it 12 ticks (Expert) / 14 (Beginner), shorter than one hero's bounce-then-strike (about 15 ticks): the partner strikes (C2 Daze and Club) |
| 9 Walker / Flyer | none | **Shellback** (RPG-battle reptile with its GUARD animation): the shield turns *instantly* to the nearer hero | one hero is always in front; the other hits the back (C1 pincer) |
| 10 Digger | rises around the hero the spawner picked | **Tunnel King**: surfaces only under a hero who stands still for 22 ticks | the bait stands still; the partner strikes in its 120-tick walk |
| 11 Leaper | leaps toward its target | **Twin Leapers** (RPG-battle snake red + green): two pits, bonded | both die within the twin window |
| 12 Charger | rushes its target | **Tusker Calf** (shipped `rex_b`, grey): too heavy to hit from the front | stopped and dazed only by a **Brace Wall** of two crouching heroes |
| Snapper | bites the nearest hero in range; its bite tests every hero | **Big Snapper** (shipped `plant` at 2x): lunges, then its stem is exposed for 20 ticks | the bait is the one recovering from the lunge; the partner hits the stem |
| New: roller, splitter, puffer, mimic, crusher, wisp, priest (A.6) | roller: a curled roller is batted like a Batter Up ball; splitter: halves must die within the twin window (bond on the fly); mimic: bites the nearer, its back faces the far hero; crusher: a hero standing on its top rides it up (a lift for the partner) | - | - |

### D.4 The co-op toolset (who does what)

Built on the research catalogue (RESEARCH_COOP 3), with this proposal's additions marked **new**. Every gate has an
easy role and a harder role; the pair picks.

| Move / object | Rules | Easy role / hard role | Cost |
|---|---|---|---|
| **Shoulder Hop** | land on the partner's head with Up held: the enemy bounce (-224, rises 105 px; feet reach ~8.7 tiles over the floor). Co-op ledges for it are 6-8 tiles high (solo reach 3) | stand still / one held jump | S |
| **Totem Stack** | land without Up: ride the partner's head (the platform ride test); the carrier's jumps are halved; the rider strikes from up there | walk / strike | M |
| **Batter Up** (**new**) | Down + Swap (co-op and Brawl only) curls the hero into a ball (roll frames 24-26) for up to 66 ticks; the partner's strike launches him: forward = line drive (about 9 tiles flat), high = lob (about 7 up, 4 across), low = grounder (rolls 12 tiles along the floor), charged = x1.5; the ball breaks `$` blocks, opens spots it hits, knocks small enemies off; it uncurls on landing or on a wall (6 ticks no-jump, the landing rule) *(tune all)*. It replaces the research's Caveman Toss: same reach, but built on the club - the game's name | curl / aim and strike | M |
| **Brace Wall** (**new**) | two heroes crouching within one tile of each other count as a wall: heavy chargers stop and are dazed 44 ticks; a lone croucher is trampled. Reuses crouch-bracing (wind, earthquakes) | crouch / crouch and line up | S |
| **Tandem seats** (**new**) | every mount (and the co-op glider in Bone Gorge) seats two: driver steers and uses the mount's attack, gunner strikes and throws with his own belt; a hit throws both off | gunner (strike only) / driver | M (on top of C.2) |
| **Stone Plate** | holds a door or column open while pressed (`objects/plate`, drives `objects/column` in a new `hold` mode); 8+ tiles from its door | stand / run | S-M |
| **See-saw** (bone plank / mushroom caps) | a hard landing (4+ rows) on one end launches the partner on the other: up to ~10 tiles | stand / drop from high | M |
| **Pulley Lift** | two platforms on one rope: one goes down, the other comes up | ride / walk the long way | M |
| **Boulder Shove** | a 2 x 2 boulder moves one tile per 6 ticks only while **both** push on the same side | both hold a direction | M |
| **Twin Drums / Twin Gongs** | two hittables struck within the twin window | big targets / timing | S |
| **Glow Lantern** | in black caves a carried lantern lights 4 tiles; the bearer cannot strike (carry rules C.6); hand it over by walking into the partner | carry / fight | M |
| **x2 tablet** | a stone tablet with two carved cavemen marks every co-op gate and co-op secret | - | S |
| **Liana belay** (**new**, stretch) | on a few climbs the heroes are tied by a liana of 6 tiles; a crouching (braced) hero on the ground catches a falling partner at the liana's length; the hanging hero climbs the liana back (climb frames). Unbraced, the anchor is dragged 2 px/tick toward the edge | anchor (crouch) / climb | L |

All windows are 12 ticks (Expert) / 24 (Beginner) with an audible count-in; nothing needs two inputs on the same tick.
Heroes pass through each other sideways and never hurt each other; only heads are solid. Every boost has a way back
(a spring flower the upper hero clubs down, a cut log bridge, a lift lever - RESEARCH_COOP T8).

### D.5 New co-op-only objects and puzzles, in one list

`objects/plate`, `objects/seesaw`, `objects/pulley`, `objects/boulder`, `objects/twin_drum`, `objects/lantern`,
`objects/x2_tablet`, `objects/spring_flower` (a potted spring the upper hero knocks down: the way back),
`objects/liana` (stretch), and the co-op behaviour parameters on existing ids (`bond=<name>`, `target=lone`,
`turn=instant`). Puzzle patterns used across the stages: leapfrog plates (A holds for B, B holds for A), lift and gift
(boost up, drop the spring), bait and strike (shellbacks, snappers, dodgers), the "3-2-1-now" twin windows, the escort
(lantern, egg), the launch (Batter Up, see-saw).

### D.6 Co-op versions of the 15 shipped levels

**Format: co-op overlays.** TECH_AUDIT 4.10 suggests a full co-op file per stage. This proposal suggests a lighter
form for the 15 shipped stages: an **overlay** `levels/coop/<id>.coop.lvl` (`kind = coop`, `coop_of = <id>`) holding
only the difference - `[patch]` rectangles that replace tile blocks, extra `[legend]` / `[entities]` lines, and
`remove=<name>` for solo entities that must go. The loader merges it when `Game.mode == COOP`; the validator checks the
merged level. The 1.0 files stay byte-identical, overlays stay small enough to review, and a solo change shows up as a
merge conflict instead of silently drifting. (If the merge turns out fragile in practice, the fallback is the audit's
full copy - the overlay compiles to it.) Co-op uses `belt = fresh` on every stage (both heroes start with the club),
so one two-stream route per (stage, difficulty) proves it.

| Stage | Co-op overlay: gates that need two (and co-op secrets) |
|---|---|
| 1-1 Vine Bridges | tutorial of the tribe: x2 tablet and signs; the springy-flower climb becomes a 7-row Shoulder Hop ledge with a spring flower to knock down; a Stone Plate at the lake gate; the spirit revive explained; a High Cache on the canopy road (Totem Stack high strike) |
| 1-2 Canopy Village | Pulley Lift in the trunk room; Pack Drop pairs in the tree village; the Feast Land A warp behind Twin Drums |
| 2-1 Echo Caverns | Glow Lantern through two black chambers; paired plates on the hatches; Leeches on the ceilings |
| 2-2 Bone Gorge | the rising stones become a bone See-saw; the glider over the gorge seats two (pilot and gunner) and the gorge gets Harrier Pairs only the gunner can clear |
| 2-2b Brute's Den | co-op Brute (B.7) |
| 3-1 Frost Summit | Shellback penguins (`turtle_b`), a Tusker Calf on the frozen lake (Brace Wall) |
| 3-1b Blizzard Pass | leapfrog in the lee: a crouching hero shelters the one behind him from the wind (RESEARCH_COOP T10) |
| 3-2 Crystal Grotto | tipping floes (a drop floe tips if one hero stands on one end), Dodgers, the Feast Land C warp behind a Batter Up wall |
| 4-1 Cinder Shaft | both heroes in the auto-scroll; Batter Up lobs across lava strata; an ember pot carried under the ember rain |
| 4-2 Obsidian Keep | leapfrog plate doors; spike switches on Twin Drums |
| 4-2b Colossus Hall | visor Colossus (B.7) |
| Feast Land A / B / C | giant roasts for two (both strike within the window), Relay Bounce: alternate bounces on one enemy extend the multiplier to x10 and x12 |
| Way Home | the walk home side by side; the exit counts both heroes; a medal for whoever reaches the elder first |

### D.7 How the 20 new levels use co-op, and how co-op gates are proven

- Every Part Two stage is authored as **solo file + co-op overlay at the same time**, with at least two co-op gates and
  one x2 secret (the signature moments are in the A.3 table); every boss has its co-op form (section B).
- Mount stages are tandem in co-op; auto-run and rising stages keep both heroes in the scroll (a hero who falls behind
  becomes a spirit at once).
- **Solo-impossibility check** (world module, `tools/validate_levels.gd --coop`): for every gate marked by an x2 tablet,
  a breadth-first search with the reference hero proves that one hero cannot pass: no bounceable enemy, spring, glider
  path, spear board or bola-able enemy within reach of a boost ledge; no column of hidden spots that allows a club-pogo
  hover; plates far enough from their doors; windows shorter than the measured solo minimum. The carried specials of
  the belt are part of the search (a spear board or a bundle step must not open a co-op gate).
- **Twin windows against thrown weapons**: one hero can strike one target and throw at the other (an axe crosses
  12 columns in about 15 ticks). The search measures that strike-then-throw time for every twin gate and boss pair;
  a window must stay below it, so where the measured minimum is under 24 ticks the Beginner window is that minimum
  minus 4 ticks instead of 24 (Kraken tips, Storm Drakes, twin gongs).
- **Co-op route proofs**: one two-stream route per (stage, difficulty) (`8:R|L` format, recorded with the
  `--record` harness of TECH_AUDIT 4.11 by two people on pads), belt invariance per slot, and the doze proof replayed
  with two heroes.

---

## E. Brawl: the same-device deathmatch

### E.1 What makes it entertaining (design pillars)

1. **Nobody sits out** (no long elimination), **everyone sees the score** (it is on the heroes' heads), and **the
   leader is the biggest target** (structural comeback).
2. **Steal moments**: the loudest laughs in local versus come from reversals; our signature verb, the head bounce,
   becomes theft.
3. **Built from this game's verbs**: clubbing scenery for food, stomps and their 1-2-3-4-6-8 ladder, charged strikes,
   giant bonuses falling from the sky, the feast.
4. **Short rounds** (60-90 s), matches of 5-8 minutes, Rematch as the default button.
5. **Bots** so one person, a parent and a child, or three friends can fill four slots.

The combat kit is RESEARCH_VERSUS 2.3 (versus-only rules, campaign values untouched): **clang** when two strikes meet,
**deflect** (a strike bats a thrown weapon back), heads are always springboards, versus hurt timing 12 stunned + 30
immune ticks (immunity ends when the victim acts), hit-stop 2-4 ticks, thrown weapons stop at solid cells. This
proposal adds: **curl** (Down + Swap: a turtle stance that ignores stomps and strikes from above but can be batted like
a ball - into lava, if you are unlucky) and the **bola** (ties a rival for 22 ticks: free to bat).

### E.2 Flagship: **Grub Stack**

*"Everything you grab stacks on your head. Biggest stack at the gong wins."*

- **Setup**: 2-4 players (free-for-all or 2v2), club for everyone, an empty head. No hearts: nobody dies from hits;
  hazards cost a respawn (48 ticks) and the whole stack.
- **The stack**: each food item you pick up lands on your head as a picture in a wobbling tower (small food 1, big
  food 2, treasure 5, giant bonus 10; above 8 pictures the tower shows bigger pictures for 5s and 10s, so it never
  leaves the screen). The tower **is** the score: everyone reads the race at a glance, the crown sits on top of the
  tallest.
- **Weight** (versus-only tuning): 10+ on your head: walk capped at 4 px/tick; 20+: 3 px/tick and jumps at 3/4 *(tune)*.
  The leader is slower and a bigger springboard.
- **Losing food**: a hit knocks **1 + stack/5** pieces off the top (they fly out with the shipped dropped-item physics:
  198 ticks, blinking at the end); a charged hit **1 + stack/2** and a launch; a **stomp steals**: the stomper takes the
  bounce-ladder count (1, 2, 3, 4, 6, 8 for a chain of stomps without touching ground) straight onto **his own** stack -
  the pieces arc from head to head; a hazard spills everything (half bursts out at the spot, half is gone). The victim
  cannot pick up for his 12 stun ticks.
- **The Cookpot** (one per arena, two on 4-player arenas, on contested ground): crouch inside it to **bank** one
  piece per 4 ticks. Banked food is safe; banking leaves you crouched (a stomp on a banking player steals double).
  Final score = banked + stack. Carry or bank: the strategy layer, and a clear goal for bots.
- **Food sources**: visible hidden spots that refill 15 s after they are emptied (sparkle 2 s before); one big spot
  (3 hits by anyone, the giant bonus falls from 7 rows above and **bonks the head** it lands on); pterodactyl crates
  every 20 s (a special weapon for 20 s or 2-3 throws, one cutlery piece, sometimes a skull); in some arenas a neutral
  critter carrying 3 food.
- **Items**: *Feast* (fork + knife + spoon from crates, dropped on a hit): 8 s in which your touch knocks 3 pieces off
  anyone and hits cannot touch you. *Skull*: whoever picks it up spills everything. *Bola, spear, axe, hammer,
  swirling axe* as crate weapons.
- **Feast Rush**: the last 15 s: a bell, every spot refills at once, a second giant bonus drops, and the **pot lids
  close** - no banking, everything on heads, everything at stake.
- **Round end**: highest total at 90 s (2 185 ticks; 60 s with 2 players) wins the round; first to 3 round wins.
  Tie: the **Golden Drumstick** falls in the middle; first to grab it wins.
- **Teams (2v2)**: one shared pot, separate stacks; a teammate's head is a free springboard; friendly hits only bump.

Why this one: it is Club & Grub - you club the world for food and eat it - and every reversal is visible (a fountain
of food out of the leader's tower and into the stomper's). It is fair to mixed skill: a newcomer scores by clubbing
spots, an expert by stomp chains, charged launches into lava and well-timed banking.

### E.3 The other modes

| Mode | Rules | Launch |
|---|---|---|
| **Clubball** | a sport for 1v1, 2v1 or 2v2: a coconut (gravity 16 v16, bounces at 3/4, rolls) and a cave-mouth goal 3 rows high at each end. The strike direction is the shot: forward = drive, high = lob, low = grounder, charged = smash (x1.5); every strike within 44 ticks of the last adds +16 v16 up to 12 px/tick (rallies escalate, as in Lethal League); a ball faster than 8 px/tick knocks a hero down (12 stun ticks); heads bounce the ball. First to 5 goals, or most after 3 min; sudden death "golden coconut". The ball resets to the middle 66 ticks after a goal | yes |
| **Last Caveman Standing** | the classic deathmatch (RESEARCH_VERSUS 3.2): 3 hearts, a lost heart bursts into 6 bones anyone can grab, last alive wins the round, first to 5. Themed sudden death at 60 s (stampede, cave-in, whiteout, lava rise, tide, rising tar). Eliminated players fly **Grudge Pterodactyls** and drop rocks | yes |
| **Hot Rock** | bomb tag (RESEARCH_VERSUS 3.4): a glowing ember passes on any touch, hit or stomp; a 12-20 s fuse; the holder pops. The mode for kids, touch screens and two players | yes |
| **Ptero Joust** | everyone on a Pterodactyl (C.2); in a collision the rider whose feet are higher wins (the stomp rule); the loser falls, his ptero flees to a perch, he re-mounts any free ptero; a hero on foot can still high-strike a rider from below. Knock-offs score | second wave (after mounts exist) |
| **Egg Heist** | 2v2 capture the Golden Egg (C.6 carry rules: no strikes while carrying, cracks after a 6-row fall); nests on raised ledges; a mother rex chases a carrier who holds it longer than 8 s | second wave (team bots) |

**Party Mix** rotates mode and arena per round; presets *Classic* (club only, no crates), *Feast* (default), *Mayhem*
(crates every 8 s, skull spots, a random variant per round). Variants: Hammer Time, Axe Rain, Big Bounce, Slippery,
Lights Out, Gusty, Giant Rain, Bola Party (everyone has the bola).

### E.4 Arenas: 8 at launch, 2 stretch

Every arena is **20 x 11 cells**, camera locked, floor in row 10, row 0 holds nothing to stand on (HUD), tiers 3 rows
apart, clear gaps of at most 5 cells, mirrored layouts with spawns rotated every round (the physics is left-right
asymmetric), one signature hazard telegraphed 10+ ticks ahead, visible spots, and geometry a bot navigation graph can
describe (no 1-row squeezes, no pixel-perfect jumps on main routes). Wider screens show a decorated frame, never
gameplay.

| # | Arena | Biome | Edges | Signature | Default mode |
|---|---|---|---|---|---|
| 1 | **Totem Ring** | jungle | wrap left-right | a totem pillar with the Cookpot on top; springs to the wrap ledges | Grub Stack |
| 2 | **Mesa Corral** | canyon (new) | walls with goal mouths | rope bridge lob lane; stampede sudden death | Clubball |
| 3 | **Cinder Bowl** | volcano | walls, lava pits | lava rises 1 row per 44 ticks in sudden death | Last Caveman Standing |
| 4 | **Echo Pit** | cave | wrap top-bottom | darkness pulses every 20 s (heroes glow); regrowing breakable walls as cover | Grub Stack |
| 5 | **Floe Rink** | ice | open sides into icy water | ice floor, drop floes, alternating gusts: knock-backs slide into ring-outs | Last Caveman Standing |
| 6 | **Shell Lagoon** | coast (new) | walls | the tide floods the low floor every 30 s; shell rafts; spear boards on the palm | Hot Rock |
| 7 | **Lantern Bog** | swamp (new) | wrap left-right | day / night every 20 s: lily pads sink by night, frogs (springboards) by day | Grub Stack |
| 8 | **Cloud Nest** | sky (new) | wrap top-bottom, no pits | low-gravity pollen in the middle, thermals at the sides | Hot Rock (Ptero Joust later) |
| 9 | *Colossus Hall* (stretch) | volcano keep | walls | the Wall Colossus as a neutral that spits at the leader | Grub Stack |
| 10 | *Sun Dial* (stretch, Hatchery unlock) | temple (new) | walls | a gong flips sun / moon blocks: the arena changes shape | any |

**Totem Ring** (`?` small spot, `*` big spot, `J` spring -224, `-` one-way, `P` Cookpot on the totem top):

```
      col 01234567890123456789
 row  0   ....................   HUD row: nothing to stand on
 row  1   ....................
 row  2   ....................
 row  3   .........P..........   the Cookpot stands on the totem top (room for one banker)
 row  4   .........##.........   totem top, 3 rows above the bridges
 row  5   ---......#?......---   wrap ledge (6 cells across the seam); spot in the totem face (high strike from the right bridge)
 row  6   .........##.........
 row  7   ....-----##-----....   bridges either side, 3 rows above the floor
 row  8   .........?#.........   spot at body height (forward strike from the floor, left side)
 row  9   ..J......##......J..   springs: rise 105 px onto the wrap ledges
 row 10   ###?#**#########?###   floor wraps left-right; the big spot's giant falls from row 3 onto the left bridge
 row 11   ####################
```

Routes: floor to bridge by a jump (48 px); bridge to totem top by a jump (48 px); floor to wrap ledge by spring;
the totem splits the floor, the wrap joins it. The banker on top can be stomped from the ledges' arc.

**Mesa Corral** (Clubball; `G` = goal zone, `B` = ball drop point, `%` canyon rim):

```
      col 01234567890123456789
 row  0   ....................
 row  1   ....................
 row  2   ....................
 row  3   ....................
 row  4   %%....--------....%%   rims (stand on top) and the rope-bridge lob lane
 row  5   %%................%%
 row  6   %%%..............%%%
 row  7   G.....--....--.....G   goal mouths 3 rows high under the rims; two low ledges
 row  8   G..................G
 row  9   G........B.........G   the coconut falls in at column 9 (rotates sides per round)
 row 10   ####################
 row 11   ####################
```

Routes: floor -> low ledge (3 rows) -> bridge (3 rows) -> rim (4 cells across): keepers stand on the rims and
volley down; the bridge is where lobs are won.

**Cinder Bowl** (Last Caveman Standing; `~` lava):

```
      col 01234567890123456789
 row  0   ....................
 row  1   ....................
 row  2   ....................
 row  3   ....................
 row  4   ...-----....-----...   high slabs
 row  5   ....................
 row  6   ....................
 row  7   .......------.......   central slab over the pit
 row  8   ....................
 row  9   ..J..............J..   springs to the high slabs
 row 10   ~~######....######~~   two floor islands; a 4-cell lava pit in the middle, lava at both ends
 row 11   ~~######~~~~######~~
```

All sketches are proposals: each must pass `tools/validate_levels.gd` (`kind = arena`) and the bot graph bake.

### E.5 Bots

- A bot is an **input producer** (TECH_AUDIT 4.9): each tick it writes the same flags a human slot would; no physics
  shortcut, no hidden information; it decides from the previous tick's state with its own seeded `SimRng`, so a bot
  match replays tick for tick and runs headless as a test.
- **Navigation graph per arena**, baked offline by a tool: nodes are standable spans, links are walks, drops, jumps
  with k held ticks (from the jump tables of `PHYSICS_REFERENCE.json`), springs and wraps - each link verified by
  simulating the real hero, as the route proofs do.
- **Behaviour**: a utility choice every 6 ticks (grab food, open a spot, bank, chase the leader, flee, charge);
  combat micro-rules from the versus triangle (high strike at a jumper above within 26 px, crouch-charge against an
  approaching rival, stomp a croucher, deflect axes). Clubball bots predict the coconut's landing with the deterministic
  ball physics and position goal-side of it.
- **Levels**: Rookie (reacts in 10 ticks, never charges or deflects), **Hunter** (default, 6 ticks, stomps and charges),
  Chief (3 ticks, stomp chains, deflects half the time - never frame-perfect).
- Launch for Grub Stack, Clubball, Last Caveman Standing and Hot Rock. Tests: 4 Hunter bots finish a round on every
  arena without getting stuck; win rate per spawn point inside a band (the asymmetry check).

### E.6 Match flow and results

1. **Brawl** -> **lobby** (4 slots: press Jump on any device; colour; team; *Add CPU* with level; handicap card:
   hearts 1-5 or stack guard x0.5 / x1 / x1.5).
2. **Rules**: mode, preset, rounds, time, crates, weapons, variants (remembered).
3. **Arena**: thumbnails, Random, Party Mix.
4. **Round**: heroes burst out of spots on a "3, 2, 1, GRUB!" count-in (kheetor countdown beeps), play, gong.
5. **Deciding moment**: the last 3 s (or the biggest steal of a Grub Stack round) replay at half speed from the input
   log - the simulation is deterministic, so a replay is a re-run. Skippable.
6. **Scoreboard** (5 s): round wins as drumsticks thrown onto each player's plate.
7. **Results**: the heroes painted onto a cave wall, podium pose (victory frames), the tally companion hands out 1-3
   awards each: *Leaning Tower* (tallest stack), *Pickpocket* (most stolen by stomps), *Home Run* (longest Clubball
   shot), *Butterfingers*, *Chain Gang* (longest stomp chain), *Clang Master*, *Batter Up* (most bats of a curled
   rival), *Lava Lover*, *Comeback Caveman*, *Pacifist*. **Rematch** is the default button.

Audio: lobby = Spring Spring Melon Field character-select loop; battle = Junkala Retro Sports stage_3, Tallbeard "Out
of Time" / "Go (No Vocal)"; sudden death = Wolfgang_ "8-Bit Battle Loop" or Junkala "dangerous encounter"; round win =
Junkala fanfare1 / MintoDog "Stage Clear Short"; match win = celestialghost8 "Victory"; crowd = CC0 applause (qubodup,
eXpl0it3r); the CC-BY Gregor Quendel cheers only if attribution is accepted.

### E.7 Controls for 2-4 players on one device

Every player needs only direction + Jump + Strike (+ Swap); Look is not needed in a locked arena, so it doubles as the
emote / taunt.

| Device | Layout (rebindable per slot, stored as `[bindings_pN]`) |
|---|---|
| Keyboard, left half | W A S D (W also jumps: the original's Up-jumps scheme), **Space** strike (thumb), **E** swap, **Q** look / emote |
| Keyboard, right half | arrow keys (Up also jumps), **Right Ctrl** strike, **Right Shift** swap, **/** look / emote (laptop alternative: **.** strike, **,** swap) |
| Gamepad (any number) | A jump, X / B strike, **LB** swap, Y / RB look, Start pause; a sideways half-controller works (direction + 2 buttons) |
| Phone | one touch player (pad + jump + strike; tap the weapon icon to swap); others on pads or bots |
| Tablet (9"+) | "table mode": two mirrored corner clusters, 56 art px targets, play area in the middle; up to 2 touch players |

These defaults keep the original's one-strike-button, Up-jumps scheme for shared keyboards (only 2-3 keys per player
beside the arrows / WASD), which is kinder to ghosting keyboards than TECH_AUDIT 4.3's five-key halves; the join
screen runs the key test (all of each player's keys held, all lights must stay lit) and suggests a pad otherwise.

---

## F. Production estimate

### F.1 What has to be built

Sizes in **engineer-weeks (ew)** for one AI engineer working in this code base under the module ownership of
ARCHITECTURE 1.1, including tests and route proofs. Rough, for planning.

| Area | Work | Owner | ew |
|---|---|---|---|
| **Wave 0** (blocking) | the N-player refactor of TECH_AUDIT 6.1: PlayerRun, input slots, PlayerSet, target / every / P1 idioms, digest guard | core (one engineer, waiver) | 3.5 |
| Belt | `PlayerRun.special`, Swap action and input bit, HUD icon, `belt` meta, belt-invariance test | core, player, ui | 1.5 |
| New weapons | spear + `objects/peg_board`, bola + bundled state + platform proxy, two hero sheets | player, enemies, objects, art | 2 + art |
| Carry system | one carry state for egg, lantern, partner seat, versus roast / egg | player | 1.5 |
| Mounts | mount framework, three tables, pens, tandem seats, proofs | player, objects | 4 |
| Ropes, vines, zip-lines | three objects, CLIMB / HANG states | objects, player | 2.5 |
| Camera modes | `autorun`, `rise`, deadly edges | world | 1.5 |
| Stage clocks | LevelClock, tide, day / night flags, phase blocks, gongs | world, objects | 2.5 |
| Low gravity, updrafts | two zones, PHYSICS addendum, traces | world, player | 1 |
| Golden Eggs | egg item, pedestal, Save field, Hatchery screen | objects, core, ui | 1.5 |
| Level format 2 | new meta keys, `liquid = tar`, biomes, co-op overlay merge, validator incl. the solo-impossibility search | world | 3 |
| Co-op core | PartyDriver: Shoulder Hop, Totem Stack, Batter Up, Brace Wall, spirit, leash, team wipe, team exit and gates; tribe camera | player, world | 5.5 |
| Co-op objects | plate, see-saw, pulley, boulder, twin drum, lantern, x2 tablet, spring flower | objects | 3 |
| Co-op enemy variants | 12 variants (D.3) + target / lone-wolf rules + co-op Brute and Colossus | enemies | 5.5 |
| New solo enemies | 8 archetypes (A.6), about 20 skins | enemies | 4 |
| New bosses | Kraken, Tusker, Croaker, Drakes, Sun Guardian (2 ew each incl. fairness tests and co-op forms), Chieftain Twins 1.5 | enemies | 11.5 |
| Part Two levels | 13 stages (1 ew each), 5 boss stages (0.5), 2 bonus stages (0.5): solo file, signs, 37 routes | level designers | 16.5 |
| Co-op overlays | 35 overlays (15 shipped + 20 new), about 70 two-stream routes | level designers, QA | 14 |
| Brawl | VersusReferee, Grub Stack, Clubball, Last Caveman Standing, Hot Rock, crates, cookpot, coconut, goals, sudden deaths | core, world, objects | 5.5 |
| Bots | HeroBot, nav-graph baker, three levels, Clubball logic, headless bot tests | core | 4 |
| Arenas | 8 arenas + graphs | level designers | 2.5 |
| UI | Tribe Gathering, HUD panels and belt icon, pause per slot, options P1-P4 + key test, touch duo, Hatchery, Part Two map, Brawl lobby / rules / arena / scoreboard / results / awards | ui | 5.5 |
| Art | palette shader and colours (1), three mount composites (1.5), two weapon sheets (1.5), carry / curl / spirit / hang poses (1), five terrain gradient maps and backdrop clean-up (2), about 20 enemy recolours and outline swaps (2), six boss builds (3), props and objects (2), map extension and UI art (1.5) | art | 15.5 |
| Audio | picks, loop trims, loudness (`tools/audio_loudness.py`), CREDITS / THIRD_PARTY rows | art | 2 |
| QA, performance | two-hero `--perf` runs per world, A53 checks, campaign flows (Part One + Two, solo + co-op), release | integration | 4 |
| **Total** | | | **about 123 ew** (+ 5 ew for stretch items: Liana belay, Ptero Joust, Egg Heist) |

With the six module owners and three level designers working in parallel after wave 0, that is roughly five months
of calendar time. The critical path: wave 0 -> carry + PartyDriver + mounts -> level authoring -> recorded routes.
Brawl can start in parallel as soon as wave 0 lands.

### F.2 Riskiest parts

1. **Single-player drift in wave 0** (TECH_AUDIT 5.1): hidden once-per-tick side effects. Mitigation: the per-tick
   digest diff after every step, the permanent digest guard, and this proposal's rule that Part One files and routes
   are never edited.
2. **Mount feel and proofs**: three new physics tables must feel as deliberate as the hero. Mitigation: start with the
   Raptor (simplest), pin every mount's jump table in a reference test, cap mount speed at 12 px/tick (doze reach).
3. **Solo-impossibility of co-op gates** once the belt, mounts and bola exist: a clever soloist could open a gate.
   Mitigation: the search includes every carried special; gates sit outside spear boards and bola targets; playtests
   with an expert told to cheat.
4. **Performance on the Cortex-A53**: two heroes (+1-1.5 ms per tick there, TECH_AUDIT 5.2), a mount and a clock on a
   tick that is already over budget. Mitigation: hero performance pass before Part Two content; mounts and clocks
   do no per-tick work while dozing; a two-hero `--perf` run per world as acceptance.
5. **Art volume**: six boss builds, three mount composites, two weapon sheets and 20+ recolours must all look like the
   anchor. Mitigation: everything is a composite or gradient map of staged CC0 art (A.4), reviewed against
   `biome_all.png`; nothing is drawn from scratch beyond small edits (saddles, tusks, a bolt strip).
6. **Bots that are fun**: Rookie must lose gracefully, Chief must not feel unfair. Mitigation: simple arenas, reaction
   and decision delays instead of cheats, headless balance runs.
7. **Content volume**: 55 level artefacts and about 110 new route proofs. Mitigation: the belt rule (37 solo routes
   instead of up to 240), overlays instead of full co-op files, the recorder for two-stream routes.

### F.3 What to cut first if the scope must shrink (in this order)

1. **Ptero Joust and Egg Heist** (second-wave Brawl modes).
2. **Liana belay** (stretch co-op mechanic).
3. **Chieftain Twins** mini-boss (Sundial Steps ends at a plain temple gate).
4. **Rex mount** (Tar Pits keeps the rising race on foot; Firefly Bog loses its Expert pen).
5. **Tide** (Shell Beach and Shell Lagoon use fixed water; day / night stays).
6. **Two arenas** (8 -> 6: keep Totem Ring, Mesa Corral, Cinder Bowl, Echo Pit, Floe Rink, Lantern Bog).
7. **Co-op overlays of the bonus stages and the Way Home** become "two heroes, no gates".
8. **Feast Land E** (the warp in 7-1b becomes a secret room): 19 levels - only if the owner accepts it.

Never cut: the wave-0 identity proof, the belt rule (it is what makes 20 levels provable), the tribe camera, spirit
revive and tribe lives, the co-op forms of the bosses, Grub Stack and the bots.

---

## Appendix 1 - New ids, keys and actions (for the contract owners)

| Kind | Additions |
|---|---|
| Input action (core) | `swap`; single-player defaults by key position: **V** and **;** (beside the Z X C and J K L clusters of jump / strike / look), gamepad **LB**, touch: tap the weapon icon; shared-keyboard defaults in E.7. One new bit in the input flags; route files gain a key letter for it (never present in 1.0 routes) |
| Level meta (world) | `format = 2`; `part = 2`; `belt = fresh\|carry`; `scroll = autorun\|rise` + `autorun_speed`, `rise_speed` (with `.expert`); `clock`, `clock_start`; `liquid = tar\|sea`; `tar_depth`; biomes `coast`, `canyon`, `swamp`, `sky`, `temple`; `kind = coop` + `coop_of`; `kind = arena` + `players`, `round_time`, `modes` |
| Entity flags | `coop`, `solo`, `versus` (skipped before spawn like `expert`); `phase=day\|night`; `bond=<name>`; `target=lone`; `turn=slow\|instant` |
| Enemies | `enemies/roller`, `splitter`, `puffer`, `mimic`, `shellback`, `crusher`, `wisp`, `priest`, co-op: `snatcher`, `leech`, `dodger`, `tunnel_king`, `calf` |
| Bosses | `bosses/kraken`, `bosses/tusker`, `bosses/croaker`, `bosses/drake` (`mate=<name>` in co-op), `bosses/guardian`, `bosses/twins` |
| Objects | `objects/mount`, `peg_board`, `rope`, `vine`, `zipline`, `tide`, `phase_block`, `gong`, `plate`, `seesaw`, `pulley`, `boulder`, `twin_drum`, `lantern`, `x2_tablet`, `spring_flower`, `liana`; versus: `cookpot`, `coconut`, `crate_spawner` |
| Items | `items/golden_egg`; weapon kinds `spear`, `bola` |
| Zones | `zones/scroll_speed`, `zones/low_gravity`, `zones/updraft`, `zones/goal` (versus) |
| Projectiles | `projectiles/hero_spear`, `projectiles/hero_bola` |

## Appendix 2 - How this proposal differs from the research documents

| Topic | Research | This proposal | Why |
|---|---|---|---|
| Revive | Egg Hatch (RESEARCH_COOP R1) | spirit revive with a scouting job | the egg is the meta-goal here; a downed player who can still help (glinting spots) is never bored |
| Launch move | Caveman Toss (carry and throw) | **Batter Up** (curl and club) | same reach, but built on the club, shared with Brawl (batting a curled rival) and the boss fights |
| Co-op levels | full co-op files (TECH_AUDIT 4.10) | overlays of the solo file | small, reviewable deltas; the shipped files stay byte-identical; compiles to the audit's form if needed |
| Weapon matrix | team weapon in co-op (TECH_AUDIT 5.6) | the Weapon Belt with `belt = fresh` for Part Two and all of co-op | one route per (stage, difficulty) for everything new, solo and co-op |
| Versus flagship | Food Fight | **Grub Stack** (Food Fight + the visible head tower, stomp steals, weight, the cookpot) | the same proven core with a score everybody can see and a strategic bank |
| Second versus mode | Last Caveman Standing | Clubball at launch beside it | a sport mode reads instantly, plays 2v2, and turns the three strike directions into three shots |
| Shared keyboard | five-key halves (TECH_AUDIT 4.3) | the original's Up-jumps, one-strike scheme | fewer simultaneous keys per player on ghosting keyboards |

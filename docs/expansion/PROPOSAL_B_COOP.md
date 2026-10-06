# PROPOSAL_B_COOP.md - "Second Helping": the co-op-first expansion of Club & Grub

Status: expansion proposal, angle B ("co-op first"). No code. Author: expansion designer (proposal_coop), 2026-10-06.

Inputs: `docs/expansion/RESEARCH_COOP.md` (mechanic ids T1-T11, C1-C7, R1-R4, S1-S3, X1-X3, enemy ids N1-N9 are
used below without re-explaining them), `RESEARCH_VERSUS.md`, `TECH_AUDIT.md` (PlayerSet, PartyDriver, wave 0,
digest guard), `docs/spec/GAMEPLAY.md` 12, `docs/spec/PHYSICS.md`, `docs/LEVEL_DESIGN.md`, `docs/ARCHITECTURE.md`,
`docs/ASSET_MANIFEST.md`, and the art / audio scouting staged in `.tools/asset_candidates/expansion/`.

Units: ticks (24.2753 per second; 22 ticks = one "designer second"), logical px (1 tile = 16 px), v16 = 1/16 px per
tick. Hero numbers are those of `LEVEL_DESIGN.md` 12: safe standing jump 3 tiles, running gap 4 tiles (5 with a
run-up to the right), head bounce with Up 105 px (about 6.5 tiles). Costs: **S** = days inside one module, **M** =
a new object / state / AI with its own tests, **L** = several modules, contracts or new art.

---

## 0. The proposal on one page

| Question | Answer |
|---|---|
| Shape | **Club & Grub: Second Helping** adds **Book II, "The Far Shore"**: 20 new levels in five new worlds (5 Tar Swamp, 6 Red Canyon, 7 Cloud Peaks, 8 Coral Coast, 9 Gloomstone Temple) after the four of 1.0, with its own world map, two bonus stages and an epilogue. Beginner plays worlds 5-8; Expert adds world 9, the final boss and the epilogue, mirroring Book I. |
| The design rule | **One map, two keys.** Every new level is drawn for two heroes. Every co-op gate has a co-op key (the partner) and a solo key from the same object family (a rock on the plate, a vine up the ledge, a rope over the gap). Keys are entities flagged `coop` / `solo` like today's `expert`, so the map is shared and only the keys change. |
| New for everyone | Six systems: **Carry & Throw** (rocks, eggs, torches - and, in co-op, your partner), **Vines & Ropes**, **Chomper the rex you ride** (two seats), **the Weapon Belt + sling**, **Tides & Rafts**, **Dino Eggs and the Hatchery** (a meta-goal that unlocks versus content). |
| Weapon rule | **The club is always on the belt.** One special weapon (hammer, axe, swirling axe or the new sling) rides beside it; a tap on Look swaps. Every new level starts with the club in hand, so **one club route proves a level for every run**. Applies to Book II and to all co-op; solo Book I keeps its 1.0 rule and its 72 route proofs untouched. |
| Co-op | Exactly **2 players** (engine for 4); one shared **tribe camera** (group paging, edge walls, leash); **Egg Hatch** revive and **tribe lives**; shared score with per-hero medals; the duo verbs Shoulder Hop / Totem Stack / Caveman Toss are part of Carry & Throw. |
| Enemy structure | **The enemy tribe co-ops too.** Co-op levels use seven enemy roles - guards, bonds, daze-gates, grabbers, heavies, packs, and the plain foes - so about a third of the enemies on every co-op path can only be beaten together. Each needs-two enemy has a listed solo stand-in. |
| Bosses | **6 new**: Twin-Headed Tar Serpent, Old Tusker, Storm Wyrm, Kraken Mother, Stone Warden, and the final **Rival Chieftains** (two rival cavemen who use our co-op moves against us). The Brute and the Wall Colossus get co-op versions. Each boss has a solo phase set and a co-op phase set that needs both heroes. |
| Versus | Grows out of co-op: **Food Fight** (flagship) where a dazed rival can be lifted and thrown, plus Last Caveman Standing, Hot Rock and King of the Feast at launch, with Egg Heist (2v2) later. **10 single-screen arenas** (8 at launch), each built around a co-op toy turned weapon (pulleys over tar, a rex rodeo, see-saw floes, a plate temple). Deterministic bots. |
| Single-player 1.0 | Book I solo files stay byte-identical; every one of the 72 routes replays tick for tick (wave 0 of `TECH_AUDIT.md`, per-tick digests, `tests/test_core_players.gd`). |
| Cost | About **100 engineer-weeks** (plus or minus 30 %). The critical path is wave 0, then the co-op core, then level authoring; level authoring is the biggest bucket and runs in parallel. Section 7.4 lists the cut order. |

---

## 1. Pillars of a co-op-first expansion

1. **Built for two, fair for one ("one map, two keys").** Geometry is designed around the duo verbs: ledges 6-8
   tiles high, gaps of 8-10 tiles, plates 8+ tiles from their doors. A solo player meets the same geometry with a
   solo key that is slower or riskier but never harder to execute than a 1.0 jump. A co-op player never sees the
   solo key, because it does not spawn.
2. **Every gate has an easy role** (RESEARCH_COOP 1.2 #1): stand on the plate, crouch as the step, be the bait,
   ride and press strike. The pair chooses who does what.
3. **The enemy tribe co-ops too.** Co-op enemies are not stronger, they are *organised*: shields that face the
   nearer hero, pairs that must die together, packs that hunt the hero who strays. Cooperation is required because
   the enemies cooperate. The final boss makes it explicit: two rival chieftains with our own moves.
4. **Carry is the one new verb.** Lifting, carrying and throwing is one hero state with one input (Down + Strike to
   lift, Strike to throw). The partner is just the heaviest thing you can carry. This keeps the hero's control set at
   the original's four inputs (direction, jump, strike, look).
5. **The club always suffices.** Every main path, gate and boss can be done with the club. Specials (belt
   weapons) open optional "tool secrets" and give comfort. This is what keeps 20 more levels provable.
6. **Versus is co-op with the safety off.** Every co-op verb is also a versus verb (toss a rival, yank his pulley,
   unseat his rex), and every versus arena is built around a co-op object.
7. **N = 1 is the identity.** Nothing in this proposal runs in solo Book I. Every multiplayer path collapses to the
   1.0 code for a party of one (TECH_AUDIT 2).

---

## 2. Campaign (A)

### 2.1 Structure and unlocks

- Title > **Play** > Solo / Co-op / Versus > **Book I "The Long Hunt"** (the 15 levels of 1.0) / **Book II "The Far
  Shore"** (the 20 new levels) > Beginner / Expert > world map.
- Book II unlocks in a mode when Book I has been finished in that mode by any save namespace (Beginner: 3-2 Crystal
  Grotto cleared; Expert: Way Home walked). A couple who finished Book I solo can start Book II in co-op at once.
  Book II level codes (code stones, as in Book I) work from the code-entry screen at any time.
- Every Book II level is **one file** that holds the solo and the co-op key sets (`coop` / `solo` entity flags).
  The 15 Book I levels get **separate co-op files** `<id>_coop.lvl` (section 4.10), because their solo files must
  stay byte-identical.
- New level meta: `book = 2` (default 1). `Levels.get_campaign(difficulty, book)` and the map read it.

### 2.2 Story and the new map

The Way Home ended with a feast. Book II opens on feast night: the tribe's **Great Egg**, which glows before it
hatches, is snatched by the two chieftains of the **Tar Tribe**, who paddle off to the Far Shore. Grub (P1, the
1.0 hero) and his cousin **Munch** (P2, the blue palette) follow on a log raft. Each world boss stands on the trail
of the thieves; the chieftains wait at the Gloomstone Temple; the epilogue carries the egg home, where it hatches
during the credits. In solo, Munch appears on the map and at the tally, cheering (the tally companion's slot) - the
story is the same.

Story is told the 1.0 way: a few still panels composed in the engine from existing sprites before 5-1, before 9-3
and after the trophy, plus the world map banner.

**Map.** A second map backdrop `ui/world_map_far_shore.png` (1280 x 360, the size of the 1.0 map): the 1.0 sea and
sky, with five islands built by gradient-mapping the 1.0 island art to the new biomes and stamping in the new
props (mesas and cacti, cloud stacks, coral and palms, the temple). The route is a dotted raft line from the 1.0
village at the left edge. Markers reuse `ui/icons.png` like Book I. Under every marker three small egg pips show
the Dino Eggs found there (3.6).

### 2.3 The five worlds

| World | Biome / terrain | Backdrop (parallax) | Everyone's new system | Co-op signature | Boss | Music (level / boss) |
|---|---|---|---|---|---|---|
| 5 Tar Swamp | swamp: gradient map of the jungle terrain atlases (`_style_tests/terrain_swamp.png`, proven); liquid `tar` (recoloured water strip) | RPG-battle forest backdrops 11 / 12 (night) cropped to a far band + 1.0 jungle layers gradient-mapped to murky teal | **Carry & Throw** | plates and Totem Stack | Twin-Headed Tar Serpent | Junkala Super Action stage_7, Tallbeard "Pixel War 1" / nene Boss Battle #1 |
| 6 Red Canyon | canyon: `terrain_canyon` gradient map (proven) | RPG-battle desert 3 and canyon 17 (medieval towers painted out) far; Emcee Flesher CC0 rock layers gradient-mapped warm for the middle; Western mesa strip | **Chomper the rex**; pulleys | pulley counterweights, two-seat rex, brace | Old Tusker | Wolfgang_ "Desert Theme", Spring Spring "Suez Crisis Remade" / Spring Spring "Great Boss" |
| 7 Cloud Peaks | sky: `terrain_sky` gradient map (proven) | RPG-battle sky backdrops; Superpowers Backgrounds sky islands at 4x for the farthest layer only | **Vines & Ropes**; gusts | leapfrog in the lee (T10), tandem glider (T7) | Storm Wyrm | Wolfgang_ "Upbeat Overworld", Spring Spring "Typhoon's Theme" / nene #2 |
| 8 Coral Coast | coral: `terrain_coral` gradient map (proven) | RPG-battle beach backdrops 5 (+ night) far; jungle layers recoloured to palms | **Tides & Rafts** | weight rafts, twin clams | Kraken Mother | Tallbeard "Deep Blue", Spring Spring "Sandy Seaside" / nene #4 |
| 9 Gloomstone Temple (Expert) | temple: `terrain_temple` gradient map (proven) | RPG-battle ruins 21 / 22 and temple 23 (towers painted out); 1.0 cave wall layer recoloured for interiors | **torches** (a carryable light, part of Carry & Throw) | torch-bearer (T11), plate leapfrog, split arenas | Stone Warden; Rival Chieftains | Junkala Super Action stage_9, Tallbeard "Penultimate" / Spring Spring "Egyptian Fortress Boss", nene #3 (final) |

### 2.4 The 20 levels

"Gates" = mandatory co-op gates on the critical path (each with its solo key). Difficulty uses a 1-10 scale on which
Book I reads roughly 1-1 = 1, 1-2 = 2, 2-1 = 3, 2-2 = 4, 3-1 = 4.5, 3-2 = 5, 4-1 = 6, 4-2 = 7 (designer estimate).

| # | Id | Name | Kind | Signature mechanic (everyone) | Co-op signature -> solo key | Gates | Diff | Mode |
|---|---|---|---|---|---|---|---|---|
| 1 | `w5_l1` | Gloop Landing | main | Carry & Throw tutorial: lift rocks, throw them at foes, set them on plates | plate leapfrog (T4), 7-tile Shoulder Hop ledge (T1) -> rock on the plate, spring flower | 3 | 5 | B+E |
| 2 | `w5_l2` | Sinking Bog | main | lily pads that sink into tar while ridden; see-saw logs; spore puffers | see-saw launch by the partner (T5), Splitter slimes (N9) -> a rock dropped on the see-saw, plain slimes | 3 | 5.5 | B+E |
| 3 | `w5_l2b` | Serpent's Wallow | sub | boss arena in the bog | **Twin-Headed Tar Serpent** | boss | 5.5 | B+E |
| 4 | `w6_l1` | Mesa Pulleys | main | pulley lifts with counterweights; eagles; taming Chomper at the end | partner as counterweight (T6), Snatcher eagles (N4) -> rocks as counterweights, harriers | 3 | 6 | B+E |
| 5 | `w6_l1b` | Stampede Gulch | sub | riding Chomper: bite, stampede dash through `$` walls, rex hops | two-seat rex: driver + gunner against dart flocks -> fewer darts, all biteable | 2 | 6 | B+E |
| 6 | `w6_l2` | Rockslide Quarry | main | boulders that roll down slopes; quarry see-saws | two-hero Boulder Shove (T9), brace against Boulderbacks (N7) -> Chomper pushes, a lever | 4 | 6.5 | B+E |
| 7 | `w6_l2b` | Old Tusker's Mesa | sub | boss arena on a mesa top | **Old Tusker** | boss | 7 | B+E |
| 8 | `w7_l1` | Vine Spires | main | climbing vines, rope swings, gusts | leapfrog in the lee (T10), Caveman Toss (T3) to cloud tops -> rope routes, crawl ledges | 3 | 7 | B+E |
| 9 | `w7_l2` | Thunder Nests | main | lightning that strikes marked high points; nests; glider runs | tandem glider pilot + gunner (T7), Harrier pairs -> solo glider with dive stomps | 3 | 7.5 | B+E |
| 10 | `w7_l2b` | Wyrm's Eyrie | sub | boss arena on cloud tiers | **Storm Wyrm** | boss | 7.5 | B+E |
| 11 | `w8_l1` | Tidepool Terraces | main | tides that rise and fall; rafts; paddling with the club | weight rafts (one rider only) + toss across, twin clam drums (X1) -> a raft that takes one, a single clam | 4 | 7.5 | B+E |
| 12 | `w8_l2` | Whalebone Wreck | main | inside a giant whale skeleton: bubble jets, a dark belly, rib pulleys | Leeches (N5) and torch-bearer preview -> lurkers, wall sconces for the torch | 3 | 8 | B+E |
| 13 | `w8_l2b` | Kraken Grotto | sub | boss arena in a flooded grotto (last Beginner stage) | **Kraken Mother** | boss | 8 | B+E |
| 14 | `w9_l1` | Torchlit Halls | main | darkness and carried torches; braziers open doors; mimic chests | torch-bearer + fighter (T11), Shieldtail pincers (C1) -> sconces, Shieldtails that drop their guard to attack | 4 | 8.5 | E |
| 15 | `w9_l2` | Hall of Plates | main | crushers (stone heads that slam on a rhythm), rising columns | paired plates (`count=2`), twin-strike drums -> rocks, timed plates | 5 | 9 | E |
| 16 | `w9_l2b` | Warden's Vault | sub | boss arena under the temple | **Stone Warden** | boss | 9 | E |
| 17 | `w9_l3` | Chieftains' Pyre | main | short climb to the altar, then the final fight | **Rival Chieftains** | boss | 10 | E |
| 18 | `bonus_d` | Feast Land D: Syrup Springs | bonus | springs and syrup pools; gummy foes to juggle | Relay Bounce chains (S2), giant roasts for two (R4) -> single roasts | 0 | - | B+E |
| 19 | `bonus_e` | Feast Land E: Cloud Cake | bonus | liquorice ropes over cake clouds | x2 cake tops by toss -> rope routes | 0 | - | B+E |
| 20 | `ending_b` | Hatching Day | ending | raft home on the tide, then carry the Great Egg to the feast fire; credits | carry the egg together (both heroes under it) -> carry it alone, slowly | 0 | 2 | E |

Count: 11 main stops (`order` 110-210), 5 boss sub-stages + 1 ride sub-stage, 2 bonus stages, 1 epilogue = 20.
Beginner plays 15 of them (worlds 5-8 and both bonus stages) and meets the **Temple Wall** after 8-2b ("The
Gloomstone Temple admits only expert eaters"), like the 1.0 expert wall.

### 2.5 Level notes

- **5-1 Gloop Landing** (about 220 x 40 cells). The Book II tutorial. Signs teach, in this order: lift (Down +
  Strike next to a rock), throw, set down, a rock on a plate; then the x2 tablet (4.5) and, in co-op, the egg
  revive and the Shoulder Hop. Two plate doors in leapfrog layout, one 7-tile ledge. Snakes (snapper skin), frogs
  (hopper skin), slimes (walkers); a Shellback turtle guards the second plate in co-op.
- **5-2 Sinking Bog** (about 200 x 60). Lily pads are drop platforms that sink 1 px per tick while ridden and
  rise when left (a pad sinks twice as fast under two heroes or a hero with a rock - co-op pairs spread out or
  stack). See-saw logs throw a hero up to tree stumps. Mushroom puffers breathe spore clouds (telegraph: they swell
  for 14 ticks). Splitter slimes in co-op. The **warp to Feast Land D** sits on a hidden stump top: in co-op a toss
  reaches it, in solo a vine behind a breakable wall (`$`).
- **5-2b Serpent's Wallow**: a short boardwalk run-in, a checkpoint, then the arena (section 5.1).
- **6-1 Mesa Pulleys** (about 230 x 70, terraced). Pulley lifts climb the mesas; each lift is balanced by weight
  (a hero or a rock counts 1). Eagles hunt the hero who stands alone on a lift. At the end Chomper, a young rex,
  is stuck behind a rock fall: three head bounces in a row tame him (3.3).
- **6-1b Stampede Gulch** (about 250 x 30, mostly flat). The rex ride: Tar Tribe raiders (chargers) stampede from
  behind every few screens, `$` walls are smashed by the stampede dash, rex hops clear 4-tile steps. Ends at a
  corral where Chomper waits for later levels (mount pens, 3.3).
- **6-2 Rockslide Quarry** (about 220 x 50). Boulders roll down slopes from chutes (telegraph: rumble and dust 22
  ticks ahead); a 2 x 2 shove boulder can block a chute. Boulderback salamanders curl and roll at heroes; two
  braced heroes stop them. Solo keys: Chomper's pen near each shove boulder (the rex counts as two pushers), and a
  lever that drops a chute gate.
- **6-2b Old Tusker's Mesa**: section 5.2.
- **7-1 Vine Spires** (about 80 x 120, vertical). Vines to climb, ropes to swing between cloud stacks, gusts that
  push off the ledges. In co-op the widest cloud gaps are toss gaps and the gust ledges are leapfrog ledges; solo
  keys are ropes and crawl-height overhangs. **Warp to Feast Land E** on a cloud top (co-op toss / solo hidden
  rope).
- **7-2 Thunder Nests** (about 240 x 60). Lightning strikes marked high points (a spark crown flickers 22 ticks
  before), so high routes are timed. The middle third is a glider run between nests: in co-op the tandem glider
  (pilot steers, gunner strikes), in solo the 1.0 glider with dive stomps. Harrier pairs circle the nests.
- **7-2b Wyrm's Eyrie**: section 5.3.
- **8-1 Tidepool Terraces** (about 230 x 50). The tide rises and falls on a fixed rhythm (a conch blows 22 ticks
  ahead). Rafts float on it; a raft carries one hero (two sink it), so in co-op one rides and the other is tossed
  across. Twin clams are drums (X1). Leaping fish (leaper skin), shellbacks on the sand.
- **8-2 Whalebone Wreck** (about 200 x 70). The skeleton's ribs are pulleys, bubble jets lift heroes in the tide
  pools, and the dark belly previews the torch: a torch-bearer cannot strike, so in co-op the partner guards him
  against Leeches; in solo the torch can be set in wall sconces to free the hands.
- **8-2b Kraken Grotto**: section 5.4. Last Beginner stage.
- **9-1 Torchlit Halls** (about 200 x 60, Expert). Dark halls lit only around a carried torch; braziers lit by a
  torch open doors. Mimic chests look like treasure chests (`objects/container skin=crate`) but bite. Shieldtails
  guard doorways.
- **9-2 Hall of Plates** (about 220 x 50, Expert). Crushers slam on a visible rhythm; paired plates (`count=2`) open
  doors; rising columns build stairs; twin-strike drums. The densest co-op stage (5 gates); solo keys are rocks and
  timed plates.
- **9-2b Warden's Vault**: section 5.5.
- **9-3 Chieftains' Pyre** (about 60 x 40, Expert). A short climb past the Tar Tribe's camp to the altar, a
  checkpoint, then the final fight (section 5.6). The trophy is the Great Egg itself; touching it leads to the
  epilogue.
- **Feast Land D / E**: food-made, enemy-light, as Feast Land A-C. D: springs and syrup pools (pink liquid),
  gummy walkers for long Relay Bounce chains. E: liquorice ropes over cake clouds (feast terrain + the sky
  backdrop). Both: giant roasts for two (R4) and one x2 egg.
- **Hatching Day** (about 150 x 24, Expert). The raft drifts home on a gentle tide (no failure state), then the
  heroes carry the Great Egg to the feast fire. In co-op both heroes stand under it (a two-hand carry that only
  moves when both walk the same way); solo carries it alone at 3 px per tick. Villagers from 1.0 cheer; the egg
  hatches into a baby rex (a rex palette) during the credits.

### 2.6 Difficulty curve

| Stage | 5-1 | 5-2 | 5-2b | 6-1 | 6-1b | 6-2 | 6-2b | 7-1 | 7-2 | 7-2b | 8-1 | 8-2 | 8-2b | 9-1 | 9-2 | 9-2b | 9-3 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Difficulty | 5 | 5.5 | 5.5 | 6 | 6 | 6.5 | 7 | 7 | 7.5 | 7.5 | 7.5 | 8 | 8 | 8.5 | 9 | 9 | 10 |
| Co-op gates | 3 | 3 | - | 3 | 2 | 4 | - | 3 | 3 | - | 4 | 3 | - | 4 | 5 | - | - |

Book II starts where Book I's Beginner campaign ends (3-2 = 5) and climbs past 4-2 (7). Each world introduces its
system in a safe first level and combines it with the earlier ones in the second. Beginner variants keep the
geometry and thin the enemies (`expert` flags as in 1.0); co-op windows are 24 ticks on Beginner and 12 on Expert.

### 2.7 Bonus stages, warps and secrets

- Warps: 5-2 -> Feast Land D, 7-1 -> Feast Land E (the 1.0 warp rule: the warp ends the source level with a tally
  after the bonus stage). Both warps sit behind a two-key secret.
- Every Book II stage hides **3 Dino Eggs** (3.6): a *trail egg* off the obvious line, a *secret egg* behind a
  hidden spot or secret zone, and a *tribe egg* behind an x2 gate in co-op or a **tool secret** in solo (a gong
  only the sling reaches, a granite chest only the hammer cracks). The 11 main stages and 6-1b hold 3 each (36),
  the five boss sub-stages 1 each in their run-in (5), the bonus stages 1 each (2), the epilogue none: **43 eggs**
  in Book II. The Book I co-op files add 2 per stage file (9 stages: 18) and 1 per Feast Land (3): **64** in all.
- Code stones (level passwords) as in Book I, solo only.

### 2.8 Art per world, and how the gaps are filled

All sources are CC0 (scouting: Superpowers RPG Battle System and Western FPS 2D by Pixel-boy, the anchor's artist;
Ninja Adventure by Pixel-boy & AAA; Sunny Land; Pixel Adventure 1; OPP2017). Pixel Adventure 2 (CC-BY copy) and
Admurin are **not** used. Every recolour swaps the outline to `#272018`.

| Need | Source | Treatment |
|---|---|---|
| Terrain of the five biomes | 1.0 terrain atlases (anchor) | gradient maps, same 40-tile layout and collision table (proven in `_style_tests/terrain_*.png`) |
| Far backdrops | RPG-battle 640 x 480 battle backdrops; Superpowers Backgrounds sky islands (4x, farthest layer only) | crop the horizon band to 360 px, mirror for a seamless loop (the 1.0 pipeline); paint out the small towers in canyon 17 and ruins 21 |
| Middle / near layers | 1.0 jungle, cave and volcano layers; Emcee Flesher desert layers | gradient maps (the way 1.0 made ice, volcano and feast from jungle) |
| Props | Western FPS 2D (cactus, rocks, tumbleweed, skull, bone, bush); 1.0 props recoloured; village props | native 1x; recolours |
| Swamp foes | RPG snake (green), slime (two palettes), mushroom; Sunny Land frog at 2x | outline swap |
| Canyon foes | RPG snake (red), dino/salamander (rolls into a ball); Sunny Land eagle at 2x | outline swap, warm recolour |
| Sky foes | RPG bat, ghost (as a cloud spirit); 1.0 pterodactyls | recolour |
| Coast foes | 1.0 turtles; Ninja fish at 2x (leaper skin); RPG octopus (static, decoration) | recolour |
| Temple foes | RPG reptile (shield guard; armour recoloured to bone and bark), mimic chest, ghost; Pixel Adventure 1 Rock Head as the crusher (recoloured stone) | recolour |
| Bosses | RPG boar, dragon, giant (all native 1x, animated); Ninja DragonGreen segments and SquidGreen at 2x; 1.0 `rival.png` | section 5 per boss |
| Hero palettes P2-P4 | `hero_colours/` proofs (blue, pink, green, alt white) | shipped as a palette-swap shader with a 16 x 1 LUT per slot (TECH_AUDIT 5.3: baked sheets would cost 17.7 MB each) plus a loincloth pattern per player |
| New hero poses | the 52 frames of `hero*.png` | carry = `attack_up` arms with the item composited above the head; ride = `crouch` (21) on the rex; rope hang = `glide` (50-51) without the glider; climb = the unused `climb` (44-47); tossed = `roll` (24-26); cheer = `victory` (48-49) |
| The egg of the Egg Hatch revive | `egg_kid` `roll` frames (the dropper's egg) | recoloured per player |
| Mount | 1.0 `rex.png` (1x) + hero `crouch` frame | composite (the scouting's recommended mount) |
| Co-op objects | 1.0 `platform_wood`, columns, anchor items (bone 21 = see-saw plank, egg shells 55-56, crests), RPG items (goblet 26, laurel 64) | composites |
| UI | anchor crests (player badges), Ninja Caveman portraits recoloured per player, Ninja keyboard / pad prompts, `ui/icons.png` arrows | as in `_style_tests/mp_ui_test.png` |
| Gaps with no art | raft, rope knot, pulley wheel, tandem glider, tar liquid, lily pad, brazier, crusher face | composites: raft = `platform_wood` + anchor log; tandem glider = `glider.png` widened by repeating its middle columns (whole pixels, no scaling); tar = water strip recolour; lily pad = `platform_wood` recoloured + the `leaf` prop; brazier = the 1.0 fire / torch items on a stone tablet; no new drawing beyond pixel edits |

Gaps the scouting reported (mammoth, sabre-tooth, triceratops, golem, eagle boss, yeti) are **designed around**, not
drawn: no boss needs them.

**Audio** (all CC0 picks from the staging; the CC-BY Wolfgang_ and crowd packs are not needed): world and boss music
as in 2.3; Feast Land D / E: 1.0 bonus loops and Tallbeard "Box Jump"; Hatching Day: Junkala Super Action stage_6.
Co-op: join sting ctske "party join", co-op menu Tallbeard "Connected", revive Junkala powerup2, lift / throw
MoxieCat "lift" / "throw", carry grunt Spring Spring "uff", see-saw Spring Spring "sproing", rope Kenney RPG creak +
artisticdude light swish, splash Basto heavy splash, tide conch = Junkala fanfare2 pitched down. Versus: lobby
Spring Spring Melon "charselect", battle Junkala Retro Sports stage_3 and Tallbeard "Out of Time" / "Go (No Vocal)",
sudden death Wolfgang_ "8-Bit Battle Loop", countdown kheetor beeps, round win Junkala fanfare1, match win
celestialghost8 "Victory", crowd eXpl0it3r applause. The nene boss tracks are 3.3-3.6 min long: give them loop
regions of about 60-90 s to stay inside the 1.0 music budget.

---

## 3. Something new for everyone (C)

Six systems. All are used solo and in co-op; none runs in solo Book I.

### 3.1 Carry & Throw (the one new verb)

**Rules**
- **Carryables**: `objects/rock` (a 1-cell boulder), `objects/egg_pot`, `objects/torch`, `objects/ember_pot`,
  the Great Egg, and in co-op **the partner**; in versus a dazed rival.
- **Lift**: Down + Strike while the hero's front touches a carryable (or stands on it) lifts it over the head in 6
  ticks. Away from carryables Down + Strike is still the low strike (designers keep floor spots one cell away from
  rocks). A partner who lands on your head without Up held is lifted at once (Totem Stack, T2).
- **Carrying**: no strikes (the 1.0 glider rule). Heavy items (rock, egg, partner) cap walking at 64 v16 (4 px per
  tick) and cut the jump to a hop of about one tile (`Tuning.CARRY_JUMP_IMPULSES`, tuned in play). The torch is
  light: normal walking and jumping.
- **Throw**: Strike throws forward (xvel 80 v16 + half the hero's own, yvel -112), Up + Strike lobs high (xvel 32,
  yvel -192, about 5 tiles up), Down + Strike sets it down in front. A partner is thrown with the Caveman Toss
  numbers (T3: -256 up, 80 forward, about 10 tiles across or 8 up).
- **Thrown rocks**: power 25 (one club hit) against enemies, open hidden spots like a thrown weapon, press plates and
  see-saws where they land, bounce once and rest. A rock lost in a pit or liquid reappears on its pile after 66
  ticks. Being hurt drops what you carry.
- **The rider** (co-op): strikes from the carrier's head (a high strike reaches about 5 tiles over the floor),
  jumps off with Up (95 px, about 6 tiles), or is thrown.

**Why it fits.** Cavemen lift boulders; it is the most physical verb the genre has, it needs no new button, and it
turns the original's head bounce family into a full toolset: bounce off a head (1.0), ride a head, be thrown from
a head. It gives the solo key for almost every co-op gate (a rock instead of a partner).

**Engine cost: M-L.** A `CarryableBase` (objects, item physics of 1.0 bonuses + plate / see-saw contact), hero
states CARRY / RIDE / THROWN (player), the hero-on-hero part in the `PartyDriver` (TECH_AUDIT 4.4, PLATFORMS phase,
riding resolved after both heroes moved), two composite poses per palette. Every move is capped at 16 px per tick
so the doze reach argument holds; the toss calls `notify_hero_teleported` for safety.

### 3.2 Vines & Ropes

**Rules**
- `objects/vine len=<tiles>` (drawn with the 1.0 `vine_a` / `vine_b` props): Up while overlapping it grabs;
  climb at 2 px per tick with the unused `climb` frames; Left / Right + Up jumps off; Down at the bottom lets go.
  No strikes while climbing. Two heroes may share a vine.
- `objects/rope len=<tiles>` hanging from an anchor: grabbed by touching it in the air (rope hang pose); swings as
  an integer pendulum (the lookup table of the 1.0 `swinger` enemy); Left / Right pump; Up releases with the swing's
  tangential speed, capped at 96 v16 across and -160 up (about 8 tiles of reach from the top of a 4-tile rope).

**Why it fits.** Jungle vines are the caveman genre's ladder, and the hero sheet already carries a climb animation
from 1.0 marked "optional mechanic". Ropes are the solo key for toss gaps.

**Engine cost: M.** Two objects, two hero states (CLIMB, SWING); the swing reuses the swinger table; route proofs
need ropes to be deterministic (integer angle steps, no floats).

### 3.3 Chomper, the rex you ride

**Rules**
- `objects/mount kind=rex` (`rex.png`, orange palette; Expert foes keep the grey `rex_b`). Wild in 6-1: three head
  bounces in a row tame him. Later levels keep him in **pens** (`objects/rex_pen`), so a mount never travels between
  levels (no entry-state variation, no extra proofs).
- Mounted: walk up to 96 v16 (6 px per tick); Up = rex hop (yvel -192, about 4.8 tiles); Strike = **bite** (kills a
  small enemy in front and pays its score as food - Chomper eats, the game is about eating); running at full speed
  for 24 ticks (the glider's take-off rule) starts the **stampede dash**, which smashes `$` walls and knocks
  heavies back; Down dismounts. A hit bucks the rider off without losing a heart; Chomper runs back to his pen and
  returns after 132 ticks. Head bounces work from the saddle. No gates, no hatches while mounted.
- **Two seats** (co-op): the first hero to mount drives (move, hop, bite, dash); a partner who lands on the rex's
  back becomes the **gunner**: he cannot move but strikes and throws both ways (Left / Right turns him).

**Why it fits.** Riding a dinosaur is the genre's oldest dream; it is a ground twin of the 1.0 glider (a vehicle
with its own physics and a take-off run), and the bite turns enemies into food like the cutlery feast.

**Engine cost: L.** A mount entity with its own ground physics (hero integrator with a mount table), rider attach
and dismount, two-seat composite art (rex + one or two seated heroes per palette via the shader), route proofs for
the mounted sections, and a fairness test that the rex never crushes the rider into a ceiling (rex + rider stand
about 55 px tall: mounted corridors need 4 rows of air).

### 3.4 The Weapon Belt and the sling - the rule that keeps 20 more levels provable

**The problem.** 1.0 proves every (stage, difficulty, weapon a run can bring) cell: 72 route files for 15 stages.
Twenty more stages with five weapons would need about 175 solo routes, and per-hero weapons in co-op about 875.

**The rule.**
1. The hero wears a belt with two slots: **the club, always**, and **one special** (hammer, axe, swirling axe, sling).
2. Picking up a special puts it on the belt *and* in the hand (exactly like a 1.0 pick-up); a second special
   replaces the first.
3. **Tap Look** (pressed and released within 6 ticks) swaps the hand between the club and the special. Holding
   Look longer pans the camera as in 1.0 (and in co-op claims the camera). Touch: tap the look button.
4. **Every level starts with the club in hand**; the special waits on the belt. Specials are kept through deaths
   and from level to level, as weapons are in 1.0.
5. **Design rule:** every main path, co-op gate and boss is beatable with the club. A boss that only thrown weapons
   hurt (the Colossus type) puts its special next to its checkpoint, as 1.0 does. Specials unlock only optional
   **tool secrets** (eggs, food caches): a high gong only the sling reaches, granite chests only the hammer cracks,
   rope bridges only an axe cuts, a crystal above a pit only the swirling axe curves up to.
6. **Proof rule:** one route per (level, difficulty, mode), recorded with the club and an empty belt. Because the
   level starts with the club in hand whatever the belt holds, the hero of every run is physically the hero of that
   route until the player chooses to swap: the club route proves the level for every entry state. Tool secrets get
   short extra routes for the egg tests.

**The sling** (new special; anchor items slingshot 17 + stone 7 composited into a hero sheet like 1.0's weapons):
a flat stone at 16 px per tick for 8 ticks, then 2 px per tick per tick of drop; power 15; recovery 4 ticks; two
in flight at most; **ricochets once** off a solid cell (x reversed) - the tool for gongs round corners. In versus a
sling stone dazes for 6 ticks and can be batted back.

**Where it applies.** Book II solo and co-op, and co-op Book I (co-op has no 1.0 proofs to protect). Solo Book I
keeps the 1.0 rule: one weapon, carried, replaced on pick-up, and its 72 proofs.

**Consequences for the existing campaign.**
- Solo Book I: none. Its files, rules and routes are untouched.
- Co-op Book I: the `_coop` files place specials where the solo files place weapons, in pairs (one per hero); the
  Colossus checkpoint gets two axes. Each co-op Book I stage is proven with club / club only.
- A later "belt in Book I" option is cheap to check: every 1.0 stage already has a club route, the Colossus club
  route picks up its axe (which, under the belt, goes into the hand exactly as today), so the 72 routes replay
  under belt rules if no route taps Look for under 7 ticks - one test (`test_campaign_routes` with a belt flag)
  decides it. Not proposed for the expansion's first release.
- Matrix (section 4.12): about 96 new campaign routes instead of 175 + 875.

**Engine cost: M.** Belt state on `PlayerRun`, the Look tap / hold split (input timing in the hero, not in
`GameInput`), a HUD belt icon per hero, the sling projectile with one ricochet, one hero sheet (+ the slot shader).

### 3.5 Tides & Rafts

**Rules**
- `zones/tide rect=c,r,w,h rows=<n> period=<ticks> hold=<ticks>`: the liquid surface inside the rectangle rises and
  falls by whole rows, one row per 22 ticks, on a fixed script. A conch blows and bubbles rise 22 ticks before every
  change. Implemented with `LevelBase.set_cell` on `~` rows, so collision and drawing stay the 1.0 tile rules.
  Water stays deadly - cavemen cannot swim (the hero's panic on falling in is the running joke), as in 1.0.
- `objects/raft len=<tiles>`: floats on the surface (its top follows the liquid row), drifts with `dx`, sinks 4 px
  per unit of weight on board (hero, rock = 1) and goes under at weight `sink` [2]. A forward strike from a raft
  **paddles**: the raft moves 1 px per tick the other way for 22 ticks.
- `objects/bubble_jet`: a column of rising bubbles that carries a hero up like a ride-mode platform.

**Why it fits.** Water was only a pit in the original; tides keep that rule and give it rhythm, the way the blizzard
gave the wind rhythm. Paddling with the club is the kind of joke Prehistorik makes with its weapons.

**Engine cost: M.** A tide zone (scripted rows, doze-safe because it lives in WORLD), a raft (a `PlatformBase` that
follows the liquid row and reads its riders' weight), a bubble jet (platform variant).

### 3.6 Dino Eggs and the Hatchery (meta-goal)

**Rules**
- `items/dino_egg index=0..2` (anchor egg-shell items 55-56 as the picture): 43 in Book II, 21 in the co-op Book I
  files, 64 in all (2.7). Collected eggs are saved per save namespace and summed into one **profile hatchery**
  (`Save` profile section), so solo and co-op both feed it.
- **Hatchery screen** (from the map and the Versus menu): the eggs sit in a nest and hatch at milestones. Rewards
  never lock anything the base game needs: versus arenas 9 and 10 (at 15 and 30 eggs), versus variants (one per 5
  eggs: Big Bounce, Slippery, Lights Out, Giant Rain, Hammer Time, Skull Surprise), extra hero colours and loincloth
  patterns for P1-P4, a golden palette at all 64.

**Why it fits.** It is the original's "hit everything, find everything" spirit (hidden spots, code stones, the
G-R-U-B-S letters) given a long-term purpose, and it bridges the campaign to versus.

**Engine cost: S-M.** One item, save fields, the hatchery screen, the unlock table.

---

## 4. Co-op (D)

### 4.1 Players, devices, joining

- **Exactly two players** in co-op, designed, tested and proven for two. The engine holds up to four heroes
  (arrays, TECH_AUDIT 4.1) for versus; three- or four-player co-op is not offered (crowded 20-column view,
  pairwise gates, RESEARCH_COOP 6.1).
- **Join** on the Tribe Gathering screen ("press jump to join"), on the world map or from the pause menu. Joining or
  leaving mid-level restarts from the active checkpoint in the other key set (score and progress kept), because the
  entity sets differ.
- **Devices** (any mix): keyboard halves, gamepads by device id, touch.
  - Shared keyboard (TECH_AUDIT 4.3, keys bound by physical position, rebindable per slot): **P1** W A S D, jump G,
    strike F, look R; **P2** arrow keys, jump `/`, strike `.`, look `,`. "Up jumps" is on for both. A key test on the
    join screen lights every held key so ghosting keyboards are caught (both players hold left + jump + strike).
  - Gamepads: the solo layout per pad; rumble per pad; a lost pad pauses ("Reconnect, or continue alone").
  - Phones: one touch player, the other on a pad. Tablets (9 inches and up): an **experimental duo layout** with
    mirrored clusters at each end of the screen (56 art px targets).
- **Colours**: P1 Grub (original yellow-orange), P2 Munch (blue), P3 Nibble (pink), P4 Gobble (green, or white on
  jungle maps) - the scouted palettes - each with a loincloth pattern (plain, stripes, spots, zigzag) and a "P1".."P4"
  arrow in `font_hud` when heroes overlap, so colour is never the only cue.
- **Helper mode** (Options): P2 cannot be hurt by enemies (only pits egg him) - for a child or a first-timer. Gates
  are unchanged.

### 4.2 Camera: the tribe camera

TECH_AUDIT option B / RESEARCH_COOP 5.2, adopted as is: one viewport; the focus is the box of all hatched heroes;
the view pages when the front hero reaches column 16 (or 4 going left) and stops when the front hero is back at
column 5 or the rear hero reaches column 1; the view edges are walls for the leader; vertical scrolling follows the
grounded heroes only, so a falling hero never drags the view. A hero off-view gets an edge arrow with a stone
count-down and becomes an egg after 5 s (Beginner) / 3 s (Expert) - no life lost. Holding Look claims the camera
(the anchor). Gates, arenas and camera-lock rooms take both heroes (a far partner arrives as an egg). Auto-scroll
(4-1) eggs a hero who touches the deadly top edge while his partner lives. No zoom, no split screen.

### 4.3 Lives, eggs, revive

- **Egg Hatch** (R1): a hero who dies while his partner stands plays the death toss, then appears in an egg carried
  near the partner by a small friendly pterodactyl. The egg owner nudges it left / right. The partner hatches it
  with any weapon hit, a thrown rock or a head bounce. Beginner: the egg follows forever, hatch with 2 hearts.
  Expert: hatch with 1 heart; an egg not hatched within 10 s flies to the checkpoint and waits there. A checkpoint
  touched by either hero hatches every egg. **Voluntary egg**: Down + Look held for 1 s (a weak player can be
  carried through a hard stretch).
- **Tribe lives** (R2): one pool (the counter starts at 2, as solo); a life is lost only on a **team wipe** (both
  heroes dead or egged). Then both respawn at the checkpoint (spread by slot), enemies reset as in 1.0. A single
  co-op death never resets the world, a boss or a gate.
- Per hero: hearts, bones, belt; shared: score, lives, letters, feast kit, checkpoint, exit unlock, eggs.
- Bones picked up at full energy fly to the partner (R3). The level ends when both heroes reach the exit (an egg on
  screen counts as present).

### 4.4 Score

- **Tribe score** (S1): one shared score, its own co-op high-score table. At the tally each hero gets medals: Most
  Food, Best Bounce Chain, Hatchling (eggs hatched for the partner), Strongman (tosses, boosts, plates held),
  Clumsiest (deaths, as a joke).
- **Relay Bounce** (S2): alternating bounces by both heroes on one enemy extend the 1-2-3-4-6-8 ladder to x10 and
  x12 (at 12 and 14 alternating bounces).
- **Rival switch** (S3, off by default): two scores on the same co-op levels for sibling rivalry.

### 4.5 The duo toolset and the co-op objects

Hero-on-hero (all in Carry & Throw, 3.1): **Shoulder Hop** (land on the partner's head with Up held: bounce -224,
feet reach about 140 px = 8.7 tiles), **Totem Stack** (land without Up: ride; the rider's high strike reaches about
5 tiles), **Caveman Toss** (the carrier's Strike), **Lift** (Down + Strike next to a crouching partner). No
friendly fire, no sideways body blocking; heads are the only solid contact.

Co-op objects (owners: objects; every one tests heroes in `CONTACT_ITEMS` with a per-slot mask; every one also has
a solo use):

| Id | Rule | Co-op key | Solo key (same object family) |
|---|---|---|---|
| `objects/plate name= count=1\|2 mode=hold\|timed:<ticks>` | pressed while weight >= `count` (hero or rock = 1) | the partner stands on it | a rock; `mode=timed` plates in solo layouts |
| `objects/column ... rise_while=<plate>[,..] / sink_while=` | the 1.0 rising column, driven by plates (rises / sinks 1 tile per 4 ticks, returns when released) | door held by the partner | door held by a rock |
| `objects/seesaw len=` | launch = -(landing yvel + 32), +64 on a hard landing, cap -288 (T5) | the partner lands on the high end | a rock lobbed onto the high end (cap -224) |
| `objects/pulley a= b=` | two linked platforms; the heavier side sinks 1 px per tick (T6) | the partner rides down | rocks as counterweight |
| `objects/boulder push=2` | a 2 x 2 tile boulder that moves 1 tile per 6 ticks while pushers' weight >= 2 (T9) | both heroes push | Chomper (weight 2), or a lever |
| `objects/drum bond= window=24/12` | struck drums of one bond must all be hit within the window (X1) | one drum each | `solo` layouts place one drum |
| `objects/x2_tablet gate=` | a carved sign that marks a co-op gate: two cavemen in co-op, a caveman with a rock (or vine) in solo | - | - |
| `objects/exit team=true` | (default in co-op) both heroes at the exit | - | - |
| `objects/gate` | party travel: Down takes both heroes | - | 1.0 behaviour |
| `objects/hero_start slot=n` | start of P2-P4 | - | ignored |
| `objects/glider_tandem` | pilot steers, gunner strikes (T7) | two heroes | `solo` layouts place `items/glider` |
| `objects/brazier name=` | lit by touching it with a torch; drives columns | torch-bearer + fighter | sconce to park the torch |

### 4.6 Enemy structure for co-op: seven roles

Co-op levels are not solo levels with a second hero. Their enemy rosters are built from seven roles, and about a
third of the enemies on every co-op critical path are **needs-two** roles (2-6), placed at chokepoints so they
cannot be skipped (they guard a plate, a door, a one-tile corridor or a ledge).

| Role | Rule | Defeated by | Built on |
|---|---|---|---|
| 1. Plain foes | every 1.0 archetype with co-op targeting (4.7) | either hero | `target_hero()` (TECH_AUDIT 4.1) |
| 2. **Guards** | a shield that always faces the nearer hero; front hits glance off with the Colossus clank (C1) | one baits, the other hits the back | `EnemyBase.accepts_hit_from(hero)` |
| 3. **Bonds** | linked enemies; the first kill starts a 24 / 12 tick window or the first one regrows (C3, N3, N9) | both strike on a "now" | `bond=<name>` on any enemy |
| 4. **Daze-gates** | dodge strikes; a head bounce dazes them for less time than one hero needs to bounce and strike (C2) | one bounces, the other strikes | hopper + `on_bounced` |
| 5. **Grabbers** | seize the lone hero and carry or squeeze him (N4, N5) | the partner frees him | stinger / lurker + attach |
| 6. **Heavies** | too strong to hit from the front; stopped only by two braced (crouching) heroes side by side (N7) | brace together, then strike the dazed head | charger + crouch test |
| 7. **Packs** | members share a `pack` id and split their targets (each takes the hero its pack hunts least); some hunt the hero farthest from his partner (N6, "lone wolf") | stay together, or pincer | `_choose_target()` hook |

### 4.7 Every existing archetype in co-op

Applies to the co-op Book I files and to Book II in co-op. "Solo stand-in" is what the same anchor holds in solo
(Book II files list both with `solo` / `coop` flags).

| Archetype (GAMEPLAY 5.2) | Co-op behaviour (all co-op levels) | Needs-two variant (role) | Solo stand-in |
|---|---|---|---|
| 0 Dropper | drops alternate between the heroes inside the zone; each walker goes for its own hero; `max` x1.5 | **Pack Drop**: a bonded pair, one at each hero (3) | plain dropper |
| 1 Decoration | unchanged | - | - |
| 2 Dangler | unchanged; its thread is a hit target | **Snatcher Bat**: grabs a hero who touches it from below and reels him up its thread (5) | dangler |
| 3 Lurker | drops when any hero is in range, chases the one it lands nearest | **Leech**: lands on a hero's back, drains a bone per 44 ticks; only the partner can club it off (alone it falls off after 220 ticks) (5) | lurker |
| 4 Swinger | unchanged | swing stones that carry a rider, timed by a partner striking the rope peg (object, not an enemy) | swinger |
| 5 Stinger | faces and dives at its target | **Hive Stinger**: hunts the hero farthest from his partner (7) | stinger |
| 6 Harrier | its waypoint loop is relative to its target; it switches target every loop | **Harrier pair**: bonded, circling in opposite directions, reachable from a Totem Stack (3) | one harrier |
| 7 Dart | aims at its target at launch | darts come in pairs, one per hero | single dart |
| 8 Hopper | hops at its target | **Raptor**: hops back from wind-ups within 48 px, jumps low throws; a head bounce dazes it 14 (B) / 12 (E) ticks (4) | hopper, hp 25 |
| 9 Walker | unchanged patrol | **Shellback**: turns every tick to face the nearer hero; only back hits count (2) | walker, hp 50 (two hits) |
| 9 Flyer | unchanged patrol | bonded flyer pairs on opposite ledges (3) | flyer |
| 10 Digger | rises around the hero the spawner picked | **Tunnel King**: surfaces only under a hero who stands still for 22 ticks; the partner must strike it during its 120-tick walk (4) | digger |
| 11 Leaper | leaps toward its target | **Twin Leapers** from two pits, bonded (3) | one leaper |
| 12 Charger | runs at its target | **Pack Raider** (rival palette): lone-wolf rusher that circles and growls while both heroes stand within 4 tiles (7); **Heavy** (`rex_b`): only a double brace stops it (6) | charger |
| Snapper | bites the nearest hero in range; the bite tests both heroes | **Big Snapper**: bait and bite (C4) - its stem is exposed only during the 20-tick lunge recovery, which the bitten hero spends knocked back (2) | snapper |

### 4.8 New enemies of Book II

Everyone-enemies (solo and co-op):

| Id | Base | Skin source | Behaviour |
|---|---|---|---|
| `enemies/snapper skin=snake_*` | snapper | RPG snake (green, red) | coils 12 ticks, lunges |
| `enemies/puffer` | snapper | RPG mushroom | swells 14 ticks, breathes a spore cloud (hazard projectile, 2 tiles, lives 44 ticks) |
| `enemies/hopper skin=frog` | hopper | Sunny Land frog (2x) | as 1.0 |
| `enemies/roller` | charger | RPG salamander | curls into a ball (12-tick wind-up) and rolls along slopes; bounces off walls once |
| `enemies/harrier skin=eagle` | harrier | Sunny Land eagle (2x) | as 1.0 |
| `enemies/wisp` | flyer | RPG ghost | patrols through walls (ignores tiles); hit only while visible (fades every 66 ticks) |
| `enemies/leaper skin=fish` | leaper | Ninja fish (2x) | leaps out of water and tar |
| `enemies/shieldtail` | walker | RPG reptile | guards (front hits glance) and drops the guard for a 12-tick axe swing; solo players strike in the swing's recovery |
| `enemies/mimic` | snapper | RPG mimic chest | looks like a crate container; bites when struck or approached; 3 hits; drops a treasure |
| `objects/crusher` | hazard | Pixel Adventure 1 Rock Head (stone recolour) | slams on a visible rhythm (blinks 14 ticks before) |

Needs-two enemies of Book II (co-op only, each with its solo stand-in on the same anchor): **Shieldtail pincer**
(a Shieldtail that never drops its guard toward the second hero; solo: the everyone-Shieldtail), **Splitter**
(RPG slime that splits into two halves that must die within the window or merge; solo: two-hit slime),
**Boulderback** (salamander heavy, braced by two; solo: roller), **Snatcher eagle** (solo: harrier), **Leech**
(solo: lurker), **Raider pack** (solo: chargers).

### 4.9 The Brute and the Wall Colossus in co-op

- **Brute (2-2b co-op file)**: hp 64 -> 80. It targets **the hero who hit it last** (aggro swap): it watches,
  guards and leaps at that hero, its guard arm faces him (blocking his throws), so the partner has the open head.
  Below 40 hp it adds the **Grab**: after a 22-tick chest beat its hands open for 8 ticks; a target within 30 px in
  front is seized and squeezed (1 bone per 44 ticks); wriggling (alternate Left / Right) shortens the hold by 4
  ticks per press; a hit on the head by the partner frees him and staggers the Brute 19 ticks. The ground pound
  shakes both heroes (crouch to stand firm, as in 1.0). A Totem Stack rider reaches the head with a forward strike.
- **Wall Colossus (4-2b co-op file)**: hp 24 -> 30; a stone **visor** covers the head. Two wall plates at the hall's
  sides lift it on their side while held; only one plate is live at a time (it glows). Rocks are spat at the plate
  holder, stalactites rattle over the thrower, so both heroes are busy. Thrown weapons only, as in 1.0; the
  checkpoint holds **two** axes. Every rage pose (the 1st hit and every 4th after) switches the live plate: the
  roles swap. The fairness tests of `tests/test_enemies_colossus.gd` (telegraphs of 10+ ticks, no stun-lock) run
  per hero.
- Solo: both bosses are the 1.0 bosses, untouched.

### 4.10 The 15 shipped levels in co-op

**Format.** Each Book I stage gets `levels/<id>_coop.lvl` (`kind = coop`, `coop_of = <id>`, `book = 1`): a copy of
the solo file in which the co-op content is authored, geometry edits allowed. The single-player registry never lists
`kind = coop`; the co-op campaign replaces every stop by its `coop_of` file (TECH_AUDIT 4.10). The copy records
`coop_base_hash` of its solo file; the validator warns when the solo file changes, so the two never drift silently.
Co-op files carry no passwords; co-op continues from the save.

**What every co-op file gets**: `objects/hero_start slot=1`; the co-op enemy roster (4.7: about a third
needs-two at chokepoints); 2-4 mandatory co-op gates; Dino Eggs (2 in each of the 9 stage files, one of them behind
an x2 secret; 1 in each Feast Land; none in the two boss rooms and Way Home); belt specials in pairs where the solo
file places weapons; a team exit.

| Stage | Mandatory co-op gates (spots that need two) | Needs-two enemies | Eggs / secrets |
|---|---|---|---|
| 1-1 Vine Bridges | (1) the first cliff becomes a 7-tile Shoulder Hop ledge with a flower the top hero clubs down as a spring (T8); (2) a plate on the near lake shore holds a log bridge up (column of `-`), with a second plate on the far shore - leapfrog; signs teach the egg revive and the x2 tablet | Shellback turtles on the canopy road | x2 treetop cache by Totem Stack high strike |
| 1-2 Canopy Village | (1) Totem Stack to the tree-house latch (a high strike 5 tiles up); (2) the trunk room's lift becomes a pulley pair; (3) the Feast Land A warp sits behind twin drums instead of the bat bounce | Twinbond monkeys (Pack Drop), Snatcher Bat | drum-gated warp; axe pair |
| 2-1 Echo Caverns | (1) the dark zone needs a torch-bearer (T11: the bearer cannot strike); (2) paired plates hold two hatches shut while the other crosses; (3) gates to the secret rooms are team gates | Leeches, Tunnel King | Feast Land B warp behind an over-the-pit wall (X3, a tossed hero strikes it in flight); hammer pair |
| 2-2 Bone Gorge | (1) see-saw on the rising stepping stones; (2) the gorge glider run with the tandem glider (gunner clears harriers) | Heavy (`rex_b`) braced on the gorge floor, Harrier pair | x2 ledge over the lift pillar |
| 2-2b Brute's Den | co-op Brute (4.9) | - | - |
| 3-1 Frost Summit | (1) the cliff climb becomes Shoulder Hop steps (6 tiles each) with flower drops; (2) a Heavy on the frozen lake (bracing on ice slides both heroes, the joke of the level) | Shellbacks on the slopes, Pack Raiders instead of chargers | x2 ice cave |
| 3-1b Blizzard Pass | (1) leapfrog in the lee (T10): 2-3 tile gaps that only open in a crouching partner's lee at peak gust; (2) a plate-held windbreak wall | Snatcher pterodactyls riding the gusts | x2 lee ledge |
| 3-2 Crystal Grotto | (1) see-saw floes (a drop floe that tips under uneven weight); (2) the Feast Land C warp behind a crystal drum pair | Raptors (`mini_rex_b`), Twin Leapers | swirling-axe pair |
| 4-1 Cinder Shaft | (1) Caveman Toss across two lava strata too far apart for one jump; (2) an ember pot carried down to light a brazier that opens a hatch (the egg rule makes a miss cheap) | Hive Stingers | x2 shelf |
| 4-2 Obsidian Keep | (1) leapfrog plate doors; (2) spike switches on twin drums; (3) a paired plate (`count=2`) that holds a rising column bridge | Raptors, Shellbacks | x2 keep tower |
| 4-2b Colossus Hall | visor Colossus (4.9) | - | - |
| Feast Land A / B / C | none mandatory: giant roasts for two (R4), Relay Bounce chains (S2), x2 cake top | - | 1 egg each |
| Way Home | team exit; the villagers cheer both heroes | - | - |

### 4.11 How the 20 new levels use co-op ("one map, two keys" in the format)

- One file per level. Co-op keys and needs-two enemies carry `coop`; solo keys and stand-ins carry `solo`; both are
  skipped before spawn in the other mode (no serial, no RNG draw - TECH_AUDIT 2 #2).
- `key=<gate>` names the gate a key belongs to; every `objects/x2_tablet gate=<gate>` must have at least one `coop`
  and one `solo` key in the file (validator).
- Co-op gates per level: 2.4 / 2.6. Every gate follows RESEARCH_COOP 1.2: an easy role, a way back (T8), a 30-second
  loop once understood, windows not frame-perfect sync.

A plate leapfrog with its two keys (sketch in the level format):

```
[legend]
T = objects/x2_tablet gate=g1
P = objects/plate name=g1_near
Q = objects/plate name=g1_far
r = objects/rock solo key=g1
S = enemies/shellback skin=turtle_b left=-2 right=2 coop
s = enemies/walker skin=turtle_b left=-2 right=2 hp=50 solo

[entities]
# a 1 x 3 stone door 13 cells past the near plate: its presser cannot reach it before it closes
objects/column 24 9 name=g1_door size=1,3 sink_while=g1_near,g1_far

[tiles]
..T..r....P.............D....Q..s.S.....
########################################
```

Co-op: A holds P, B walks through, B holds Q, A walks through, the pincer on the Shellback follows. Solo: carry the
rock to P (the door sinks), walk through, the door stays open behind you while the rock sits there; the walker
needs two hits.

### 4.12 Proof: solo-proof gates, co-op routes, the route matrix

- **Solo-impossibility check** (validator + a search tool): for every x2 gate region in co-op mode, a bounded search
  with the reference hero (the route tools' simulator) must fail to pass the gate alone with every weapon: no
  bounceable enemy, spring, glider or carryable within reach (an enemy bounce rises 105 px), no column of hidden spots
  for a club-pogo hover, plates at least 8 tiles from their doors, windows shorter than the measured solo minimum.
- **Co-op route proofs**: two-stream input files (`8:R|L`, TECH_AUDIT 4.11), replayed tick-exactly, recorded with
  the recorder (two people with pads) or authored with **duo macros** in the route tools (P2's stream shadows P1's
  with an offset, except at gates, where named macros such as `hop g1`, `hold g1_near`, `toss g3` insert the
  rehearsed inputs).
- **Matrix** (club only, thanks to the belt):

| Set | Levels | Beginner | Expert | Routes |
|---|---|---|---|---|
| Book I solo (1.0) | 15 | - | - | 72 existing, untouched |
| Book I co-op (`_coop`) | 15 | 11 | 15 | 26 two-stream |
| Book II solo | 20 | 15 | 20 | 35 |
| Book II co-op | 20 | 15 | 20 | 35 two-stream |
| Tool secrets and egg tests | - | - | - | about 40 short routes |
| Versus | 10 arenas | - | - | 2 bot-match replays per arena |

About 136 new routes (96 full campaign routes), against about 175 solo + 875 co-op without the belt.

---

## 5. Bosses (B)

### 5.0 Common rules

- Every boss is a `BossBase` with the 1.0 rules: hits count once per `BOSS_HIT_COOLDOWN` (22 ticks) **per boss**,
  so two heroes do not double the damage; every attack is telegraphed 10+ ticks ahead (the Colossus fairness rule);
  no stun-lock; a defeat bursts into 64 bonuses plus the key item (fire-starter, or the trophy).
- Each boss has two **phase sets** chosen by the mode: `solo` (fair for one hero, club-beatable) and `coop`
  (needs both heroes). Co-op hp is at most +25 %; the challenge comes from the co-op rules.
- Each gets `tests/test_enemies_<boss>.gd`: telegraph lengths, escapability of every attack from the standing spots,
  no stun-lock, the club beats it in solo, and **the co-op weak window is shorter than the solo minimum** (proving the
  co-op set needs two).
- Boss art at native 1x where the scouted sheet is boss-sized (boar, dragon, giant) - finer than the pixel-doubled
  1.0 bosses; Ninja sheets at 2x (their 1 px outline becomes the anchor's 2 px).

### 5.1 Twin-Headed Tar Serpent "Gloopmaw" (5-2b Serpent's Wallow)

- **Sprite**: Ninja Adventure `DragonGreen` Head / Body1 / Body2 / BodyEnd at 2x, recoloured tar-black with bog
  green and amber eyes. Two head instances; the necks are chains of body segments drawn along an arc from each pit;
  tar splashes are `fx/splash` recoloured.
- **Arena** (one screen, 20 x 11, camera locked): two tar pits at columns 2-4 and 15-17, a mud island columns 6-13
  on the floor row, a lily-pad drop platform over each pit, side ledges 3 rows up, a see-saw log at the island's
  centre.
- **Energy**: 6 pips (24 hp, 4 per pip).
- **Attacks**:
  - *Lunge*: the head rears back 12 ticks (eyes flash) and strikes across the island; after the lunge it **lies on
    the island** 20 (Beginner) / 14 (Expert) ticks - the weak window.
  - *Tar spit*: cheeks puff 10 ticks, an arcing blob lands and lingers as a puddle (touch costs a bone) for 44 ticks.
  - *Dive and resurface* (from 4 pips): the heads sink; a trail of bubbles on the tar shows where they rise 22 ticks
    ahead; they may swap pits.
  - *Tail sweep* (from 4 pips): bubbles in the island's middle for 14 ticks, then the tail sweeps the island at hop
    height.
- **Weak points**: each head's crown, while it lies on the island after a lunge. Heads are safe springboards
  (boss bounce) to the side ledges.
- **Solo**: only one head attacks at a time; the other sleeps with its eyes above the tar. Each head hit counts.
- **Co-op**: both heads attack together, one lunging at each hero (pack targeting). The heads are **bonded**: a hit
  counts only if the other head is hit within 24 / 12 ticks; otherwise the hit head regrows with a hiss. Their
  lunge recoveries are synchronised at opposite ends of the island, so the heroes split and call "now". From 2 pips a
  lunge can **grab** a hero and drag him toward the tar over 66 ticks; a hit on that head frees him.
- **Drops**: 64 bonuses + fire-starter.

### 5.2 Old Tusker (6-2b Old Tusker's Mesa)

- **Sprite**: RPG-battle `boar` sheet (239 x 178 cells; idle, walk, charge, spin-ball, hit, death) at native 1x,
  recoloured: the leafy mane to dry ochre, tusks lengthened and bone-white by pixel edit. About 75 x 55 logical px,
  larger than the 1.0 rex.
- **Arena**: one screen with `|` walls, a mesa ledge at each side 4 rows up, a 2 x 2 shove boulder in the middle.
- **Energy**: 8 pips (80 hp).
- **Attacks**:
  - *Charge*: paws the ground 18 ticks (dust, snort), rushes at 6 px per tick toward the far side.
  - *Spin-ball*: curls up in 12 ticks (green swirl), rolls and bounces off the walls 2-3 times; its back is a
    springboard.
  - *Tusk toss*: a hero within 30 px in front is flicked up after an 8-tick dip of the head (costs a bone).
  - *Quake* (from 4 pips): rears up 14 ticks and slams: shake (crouch to stay grounded) and rocks fall from the mesa
    rims (stalactite rules).
- **Weak point**: the rump; tusks and mane glance off with a clank.
- **Solo**: a charge ends in a crash against the arena wall: dazed 56 (Beginner) / 44 (Expert) ticks lying on its
  side - strike the rump. After a spin-ball it is dizzy 30 ticks.
- **Co-op**: it **never crashes**: it skids and turns two tiles before a wall. It turns to face the nearer hero
  every tick (a guard at boss scale): one baits in front out of tusk range, the other hits the rump, after which it
  whirls round to the hitter (aggro swap) and the roles swap. A charge can also be stopped dead by **two braced
  heroes** side by side in its path (Heavy rule): it is dazed 44 ticks. One braced hero alone is trampled. A rolling
  spin-ball unrolls dizzy if both heroes strike it within the window.
- **Drops**: 64 bonuses + fire-starter. Story: beaten, she lets the heroes pass and guards Chomper's pen.

### 5.3 Storm Wyrm "Skyfang" (7-2b Wyrm's Eyrie)

- **Sprite**: RPG-battle `dragon` sheet (258 x 209 cells; idle, rise, claw, roar / breath, hit) at native 1x,
  recoloured slate and teal with a yellow belly.
- **Arena**: one screen of cloud tiers 3 rows apart; a nest 8 tiles up at the right (out of solo jump reach); two
  ropes hang from the nest's rim; a see-saw on the lowest cloud. Gusts alternate direction every 132 ticks.
- **Energy**: 6 pips.
- **Attacks**:
  - *Dive claw*: rises off the top of the screen with a screech (16 ticks), its shadow marks the landing spot on a
    cloud for 12 ticks, then it dives.
  - *Lightning breath*: roar pose 14 ticks with sparks at the mouth, then a horizontal band two rows high sweeps one
    tier (drop or climb a tier).
  - *Wing gust*: three beats push heroes toward the open edge (crouch to brace, the blizzard rule).
- **Weak point**: the head, while its claws are stuck in a cloud or while it perches on the nest.
- **Solo**: after every dive its claws stick in the cloud 30 ticks - high strike or throw at the head. Climbing a
  rope to the nest gives a second, riskier answer while it perches (the ropes are `solo` keys: in co-op they are
  not there). Phase 3 (last 2 pips): the clouds dissolve and
  the hero gets the glider; each **glider dive stomp** (the 1.0 glider dive attack) on its back counts one hit.
- **Co-op**: its claws never stick. After every second dive it **perches on the nest**, reachable only by a Shoulder
  Hop, the see-saw or a toss - one hero boosts the other. While it perches it **snatches** the hero left on the
  lowest tier and carries him toward the screen edge (3 s, then he is egged); a hit on its tail frees him. Phase 3:
  the **tandem glider**: the pilot flies, only the gunner can strike its wings and head.
- **Drops**: 64 bonuses + fire-starter.

### 5.4 Kraken Mother (8-2b Kraken Grotto)

- **Sprite**: Ninja Adventure `SquidGreen` (idle, walk, attack, attack loop, shoot, hit; 76 x 79 frames) at 2x
  (about 76 x 79 logical), recoloured coral red and purple; tentacles are chains of sucker discs cut from the
  RPG-battle octopus.
- **Arena**: one screen; water across the floor with two rafts; a rock shelf 3 rows up at each side; the tide rises
  and falls 2 rows on the Kraken's command.
- **Energy**: 6 pips.
- **Attacks**:
  - *Tentacle slam*: bubbles mark the spot 14 ticks ahead, a tentacle rises and slams across a raft or shelf.
  - *Ink*: an arcing blob that leaves a dark cloud (local darkness, 66 ticks) where it lands.
  - *Tide pulse*: a conch-like bellow 22 ticks ahead, then the water rises 2 rows for 88 ticks (shelves and rafts
    stay safe).
  - *Grab*: a tentacle seizes a hero within reach and drags him toward the beak over 88 ticks (1 bone per 44 ticks).
- **Weak point**: the head and beak, only while surfaced.
- **Solo**: after every tide pulse the Kraken surfaces onto the shelf for 30 ticks; there is no grab.
- **Co-op**: it surfaces **only to eat**: when a tentacle drags a hero to the beak, the head rises and stays up while
  it eats. The partner strikes the head (each hit also loosens the grip; the third frees the hero). One hero
  volunteers to be bait - the bravest role in the game - and a hero who is not freed within 88 ticks is egged.
- **Drops**: 64 bonuses + fire-starter. **First boss to cut** (7.4).

### 5.5 Stone Warden (9-2b Warden's Vault)

- **Sprite**: RPG-battle `giant` sheet (385 x 318 cells; idle, raise, swing with arcs, slam, charge, hit, guard)
  at native 1x (about 130 x 70 logical px), gradient-mapped: armour to carved grey stone with moss, cape to
  red-ochre hide, mace to a stone club, shield to a stone disc with a carved face.
- **Arena**: one screen; a wall plate at each end (columns 1-2 and 17-18); a centre plate and a rock pile flagged
  `solo`; two rising columns that can split the room; ceiling crushers (Rock Head recolour) for phase 3.
- **Energy**: 8 pips (96 hp).
- **Attacks**:
  - *Mace sweep*: raises the mace 14 ticks (a glint), sweeps low in front (jump it).
  - *Overhead slam*: 18-tick wind-up, the slam sends a shockwave along the floor (jump) and shakes the screen.
  - *Shield bash*: walks forward behind the shield, pushing heroes back.
  - *Crushers* (phase 3): ceiling crushers blink 14 ticks, then fall over the plates.
- **Weak point**: the glowing core in its back. The shield always faces the nearer hero.
- **Solo**: after an overhead slam the mace sticks in the floor 52 (B) / 40 (E) ticks; the Warden cannot turn, so the
  hero jumps over (its head is a safe springboard) and strikes the core. Phase 2 (from 5 pips): it grows a stone
  **shell**; carrying the rock onto the centre plate pulls the shell off for 66 ticks.
- **Co-op**: the mace never sticks; the pincer is the way in (one baits, one hits the core; the Warden turns to the
  hitter). Phase 2: the shell comes off only while **both wall plates** are held at once (16 columns apart) - and
  then for 66 ticks, so both heroes sprint in from opposite ends. The Warden raises the split columns to separate
  them before they can reach the plates (rumble 22 ticks ahead); a Shoulder Hop gets one hero over a column.
- **Drops**: 64 bonuses + fire-starter.

### 5.6 The Rival Chieftains, Gorm and Gulla (9-3 Chieftains' Pyre, final)

- **Sprite**: 1.0 `rival.png` (hero-sized, full move set: idle, walk, jump, fall, land, roll, crouch, attack, hurt,
  death) in two palette swaps (tar-black with bone war paint, ochre with red), a bone headdress composited from the
  anchor's dino skull items. Two boss bars (two rows of pips).
- **How they move**: **on hero physics, driven by the versus bot brain.** Each chieftain is a boss shell around the
  hero simulation, fed each tick by a `HeroBot` input producer (6.6) with its own seeded RNG. They move, jump and
  strike exactly as we do - readable, fair, and the production synergy that makes the versus bots pay twice. Fallback
  if this proves too costly: a Brute-style state machine on the same sprite.
- **Arena**: one screen around the pyre; the Great Egg on an altar 6 tiles up at the centre; a see-saw and two plates
  on the floor; ledges 3 rows up.
- **Energy**: 4 pips each.
- **Phases and attacks** (all telegraphed with a shout pop-up, "HUP!", and a 14-tick crouch):
  - *P1 Raiders*: they flank the hero who strays from his partner (pack targeting), strike, stomp heads.
  - *P2 Totem Chief* (from 2 pips each): they **stack** - the bottom walks, the top strikes high - and the bottom
    **tosses** the top onto a hero; a tossed chief lies dazed 30 ticks where he lands.
  - *P3 Egg Thieves*: they grab the Great Egg and play keep-away (the carrier cannot strike; a hit makes him drop it).
  - **Egg revive**: a chieftain knocked to 0 becomes an egg; his partner runs to hatch it with a head bounce unless
    the heroes smash it first (3 hits).
- **Solo**: the chieftains tag in one at a time (the other waits on the pyre and tags in at half energy); P2 tosses
  are aimed at the hero, so the dazed chieftain is the solo opening; a knocked-out chieftain's egg hatches after 132
  ticks unless smashed.
- **Co-op**: both fight at once; the egg revive takes only 66 ticks, so one hero must smash the egg while the other
  keeps the surviving chieftain away from it - our own revive rule turned against us.
- **Drops**: the Great Egg as the trophy (leads to Hatching Day).

---

## 6. Deathmatch (E)

### 6.1 Shape

Versus takes RESEARCH_VERSUS as its base (round structure, hurt table, comeback rules, bots) and adds the co-op
verbs. It runs only in arena files (`kind = arena`) with its own rule table; campaign code and constants are
untouched. 2-4 players on one device, free-for-all or 2v2; bots fill empty slots.

### 6.2 Combat kit

From RESEARCH_VERSUS 2.3, unchanged: forward / high / low strikes, the crouch-charged strike as a launch, **clang**
(two strikes meet: both pushed 16 px apart, the Colossus clank), **deflect** (a strike bats a thrown axe or sling
stone back), **stomps** with the 1-2-3-4-6-8 ladder, heads always springboards, versus hurt timing 12 stunned + 30
immune ticks (immunity ends when the victim acts), thrown weapons stop at solid cells and stick as pick-ups,
2-4 tick hit-stop.

Added by this proposal:

- **Lift and toss a rival**: a rival who is stunned or squashed can be lifted (Down + Strike in contact). He wriggles
  free after 22 ticks, 4 ticks sooner per alternate Left / Right press. Strike throws him with the Caveman Toss arc:
  he spills half of his food in the air, and a throw into a hazard is a knock-out. The comedy move of the mode.
- **Rocks** lie on piles in most arenas: thrown, they daze for 8 ticks and spill 1.
- **Co-op toys as weapons**: pulleys, see-saws, plates, rafts and Chomper act on rivals exactly as on partners
  (6.4).
- **Teams**: in 2v2 every co-op verb works between teammates (boost, ride, toss, egg revive in elimination modes);
  friendly strikes only bump.

### 6.3 Modes

| Mode | One-line rule | Key numbers | Launch |
|---|---|---|---|
| **Food Fight** (flagship) | most food at the gong wins the round; every hit, stomp, toss or fall knocks food out of you | rounds 90 s (60 s with 2 players), first to 3; spill: hit 1 + carried/5, charged 1 + carried/2 and a launch, stomp by the ladder, toss half, hazard everything; visible spots refill 15 s after they empty; one big spot (giant bonus bonks heads); pterodactyl crates every 20 s; last 15 s **Feast Rush**; tie: Golden Drumstick | yes |
| **Last Caveman Standing** | 3 hearts, elimination; a lost heart bursts into 6 bones anyone can grab | first to 5 rounds; themed sudden death from 60 s; the eliminated fly **Grudge Pterodactyls** and drop rocks (12-tick daze, no damage) | yes |
| **Hot Rock** | a glowing ember sticks to one player; it passes on any touch, and the holder can **throw** it (Carry & Throw) | fuse 12-20 s, ticking in the last 3; the passer is immune to it for 44 ticks; the holder pops and is out | yes |
| **King of the Feast** | carry the giant roast to fill 20 counts; the carrier cannot strike | a hit drops it; your count is kept but never below 5 left (Shine Thief floor) | yes |
| **Egg Heist** (2v2) | carry the giant egg to your nest ledge; your nest gate opens only while a teammate holds your plate; teammates boost and toss each other | first team to 3 eggs; the egg cracks after a fall of 6+ rows; a mother rex chases a carrier who holds it 8 s | wave 2 (needs team bots) |

- **Party Mix**: a playlist that picks mode and arena per round. **Presets**: Classic (club only, no crates, no
  handicap), Feast (default), Mayhem (crates every 8 s, skull spots, a random variant per round). Variants are
  unlocked by Dino Eggs (3.6) beyond a base set (Big Bounce, Slippery).
- **Themed sudden death** per biome: Stampede (jungle), Cave-in (cave), Whiteout (ice), Lava rise (volcano), Tar rise
  (swamp), Rockslide (canyon), Cloudburst - tiers dissolve one by one (sky), High Tide (coast), Crusher Ceiling
  (temple). Every one telegraphs 10+ ticks ahead.

### 6.4 Arenas

Ten arenas of 20 x 11 cells (floor on row 10, row 0 free for the HUD, camera locked; wider screens show a decorated
frame). Tiers 3 rows apart; 5+ rows only by spring, head or toy; gaps of 5 cells at most; mirrored layouts with
rotating spawn points (the physics is left-right asymmetric); 4-8 visible hidden spots; one signature hazard; one
**co-op toy** each. Eight at launch, two unlocked by eggs.

| # | Arena | Biome | Edges | Co-op toy turned weapon | Sudden death | Default mode |
|---|---|---|---|---|---|---|
| 1 | Vine Ring | jungle | wrap left-right | springs and a top island reached only off someone's head (RESEARCH_VERSUS 4.2 sketch) | Stampede | Food Fight |
| 2 | Echo Hollow | cave | wrap top-bottom | hatches, rock piles; darkness pulses every 20 s (heroes glow) | Cave-in | Hot Rock |
| 3 | Seesaw Floes | ice | open sides into icy water | two see-saw floes: land on your end to fling whoever stands on the other - out over the water | Whiteout | Last Caveman Standing |
| 4 | Cinder Pit | volcano | walls, lava below | rock piles to throw; ember rain zone | Lava rise | Last Caveman Standing |
| 5 | Tar Pulleys | swamp | walls, tar pit | two pulley lifts over tar: step on your lift to yank the rival's side up to the big spot - or down to the tar | Tar rise | Food Fight |
| 6 | Mesa Rodeo | canyon | walls | Chomper leaves his pen every 30 s; a rider bites (spill 3) and dashes; a stomp on the rider unseats him | Rockslide | King of the Feast |
| 7 | Cloud Swing | sky | wrap top-bottom | ropes and alternating gusts; brace in a rival's lee | Cloudburst | Food Fight |
| 8 | Plate Temple | temple | walls | four plates: holding one raises a spike row on the far side (telegraphed 14 ticks) or opens a nest gate (Egg Heist) | Crusher Ceiling | Egg Heist / Food Fight |
| 9 | Tide Pool | coast | open sides | the tide covers the lower tier every 15 s; rafts; paddle a rival out to sea | High Tide | Last Caveman Standing (15 eggs) |
| 10 | Colossus Hall | volcano keep | walls | the Wall Colossus spits at the leader; a plate lifts its visor to aim it at whoever stands opposite | stalactite rain | Food Fight (30 eggs) |

**Tar Pulleys** (`levels/arena_tar_pulleys.lvl`, to be validated with `tools/validate_levels.gd`):

```
     col 01234567890123456789
row  0   ....................   HUD row: nothing to stand on
row  1   ....................   log beam with the pulley wheels (prop)
row  2   ....................
row  3   ........#**#........   mud island: two big-spot cells (giant falls in from above the screen)
row  4   ........####........
row  5   ....................
row  6   ##?..LLL....RRR..?##   side ledges with small spots; lifts L and R at rest (balanced)
row  7   ###..............###
row  8   ....................
row  9   ...J............J...   springs on the banks (-224: up to the side ledges)
row 10   ####~~~~~~~~~~~~####   4-cell banks and a 12-cell tar pit
row 11   ####~~~~~~~~~~~~####
```

L and R hang from one rope: the heavier lift (heroes and rocks, 1 each) sinks 1 row per 4 ticks down to row 9, one
row over the tar, while the other rises up to row 3, level with the island. Riding the high lift is the only way
onto the island; a rival who jumps onto the low lift yanks you down. Two players on one lift sink it at once.

**Mesa Rodeo** (`levels/arena_mesa_rodeo.lvl`):

```
     col 01234567890123456789
row  0   ....................   HUD row: nothing to stand on
row  1   ....................
row  2   ....................   crates fall on lanes 3 and 16
row  3   ....................
row  4   ....................
row  5   ##?..............?##   high mesas, 5 rows over the floor: spring, or a hop off a rider's head
row  6   ###..............###
row  7   ......---..---......   one-way rock shelves, 3 rows over the floor
row  8   ....................
row  9   ....J.$.PPPP.$.J....   springs, regrowing cover blocks ($, back after 15 s), the rex pen (P)
row 10   ####################   floor: Chomper's run, wall to wall
row 11   ####################
```

Every 30 s the pen opens (rumble 22 ticks ahead) and Chomper trots out; the first hero on his back rides until
unseated. The stampede dash smashes the cover blocks. The mesas are the safe high ground - reached by spring or by
bouncing off the rider's head, which also unseats him.

### 6.5 Items

Pterodactyl crates fall on marked lanes (shadow 22 ticks ahead): food, a **temporary** belt special (lost on a
knock-out or after 3 axe / 2 swirling-axe / 6 sling shots), one cutlery piece (three = an 8 s feast in which your
touch spills 3), a skull (spills everything), a grenade (every rival spills 5), a rock. No crate content depends on
rank. Visible spots and the big spot as in Food Fight.

### 6.6 Bots

Yes, at launch, for Food Fight, Last Caveman Standing, Hot Rock and King of the Feast (team bots for Egg Heist in
wave 2). A bot is an **input producer** (`InputSlot.BOT`): each tick it writes the flags a human would, decided
from the previous tick's state with its own seeded `SimRng` (never `Sim.rng`), so every match replays tick for tick
and runs headless as a test. It navigates by a **graph per arena** baked offline (walk, drop, hatch, jumps with
1-11 held ticks, spring, wrap, rope, pulley, lift) where every link is verified by simulating the real hero, like the
route proofs. Levels: **Rookie** (reaction 10 ticks, never charges or deflects), **Hunter** (default, reaction 6,
stomps and charges), **Chief** (reaction 3, stomp chains, deflects half the time, never frame-perfect). Difficulty is
reaction and decisions, never cheating. The same `HeroBot` drives the Rival Chieftains (5.6). Tests: four Hunters
finish a round on every arena without getting stuck; no hit within 48 ticks of a spawn; win rates per spawn point
within a band.

### 6.7 Match flow and results

1. **Versus lobby**: four slots, "press jump to join" on any device; palette and pattern; team toggle; Add CPU with a
   level; handicap card (hearts 1-5, belly guard x0.5 / x1 / x1.5, Auto).
2. **Rules**: mode, preset, rounds, round time, crates, weapons, variants (whoever pressed Start controls it; the last
   rules are remembered).
3. **Arena select**: thumbnails, Random, Party Mix.
4. **Round**: heroes burst out of spots, "3, 2, 1, GRUB!" (countdown beeps), play, gong.
5. **Deciding moment**: the last 3 s replayed at half speed (the simulation is deterministic: an input log plus a
   start snapshot); in Food Fight the biggest spill of the round. Skippable.
6. **Scoreboard** (5 s): round wins as drumsticks tossed onto each player's plate.
7. **Results**: a podium; the tally companion hands out 1-3 awards per player - Glutton, Butterfingers, Pogo
   Stick, Chain Gang, Clang Master, Batter Up, **Strongman** (most tosses), **Rodeo Star** (longest ride), **Hot
   Potato**, Lava Lover, Head Case, Comeback Caveman, Pacifist. **Rematch** is the default button.

### 6.8 Controls for 2-4 on one device

- Every player needs only direction + jump + strike (+ look, unused in versus), so a sideways half-controller works.
- Two players on one keyboard with the halves of 4.1; a third and fourth player on pads. Keyboard halves, pads and
  touch mix freely.
- Phone: one touch player, the rest on pads or bots. Tablet: up to two touch players (mirrored corner clusters, 56
  art px targets; swipe up on strike = high strike).
- HUD: four corner panels (portrait in the player colour, belly or hearts, held items), round timer (a sundial) at the
  top centre, off-screen bubbles for heroes above the view, attacker-coloured hit sparks, the crown on the leader.

---

## 7. Production (F)

### 7.1 What has to be built

Estimates are engineer-weeks for an AI engineer including tests and proofs; they are planning numbers, not
commitments (plus or minus 30 %).

| Area | Work | Owner | Size | Weeks |
|---|---|---|---|---|
| **Engine, wave 0** | N-player identity refactor of TECH_AUDIT 6.1 (PlayerSet, PlayerRun aliases, input slots, PartyDriver hook, mechanical conversion of 202 touch points, digests, `test_core_players.gd`) | core lead with a waiver | L | 4 |
| Co-op core | PartyDriver (ride, toss, egg revive, team wipe), tribe camera, input slots at runtime + join screen, Save v2 namespaces + Book II campaign, Flow co-op / Book II, HUD two panels, pause per slot, options P2 bindings + key test, palette shader | core, player, world, ui | L | 10 |
| Route tooling | two-stream harness, recorder, duo macros, solo-impossibility search | core, QA | M | 2.5 |
| New systems | Carry & Throw 2, Vines & Ropes 1.5, Chomper 2.5, Belt + sling 1.5, Tides & Rafts 1.5, torches / braziers / light 1, Dino Eggs + hatchery 1 | player, objects, world, ui | L | 11 |
| Co-op objects | plate, column hold modes, see-saw, pulley, boulder, drum, x2 tablet, team gate / exit, hero start, tandem glider | objects | M | 3.5 |
| Enemies | co-op targeting and the 7 roles (guard, bond, daze, grab, heavy, pack hooks); 9 needs-two variants; 10 Book II everyone-enemies | enemies | L | 5.5 |
| Bosses | Serpent 1.5, Old Tusker 1.5, Storm Wyrm 2, Kraken 1.5, Stone Warden 1.5, Chieftains 2.5, co-op Brute 0.5, co-op Colossus 0.75 | enemies | L | 12 |
| Levels | 20 Book II levels (layout, both key sets, eggs, 2 solo + 2 co-op routes each where playable): about 4 days each | level designers | L | 16 |
| Levels | 15 Book I co-op files (gates, roster, eggs, 1-2 co-op routes): about 2.5 days each | level designers | M | 7.5 |
| Versus | referee (PvP hits, clang, deflect, stomp, lift-and-toss), 4 launch modes, lobby / rules / arena select / scoreboard / results / awards / replay | world, core, ui | L | 7.5 |
| Arenas | 10 arenas, about 1.5 days each | level designers | M | 3 |
| Bots | nav-graph baker with simulated links, HeroBot, three levels, headless bot tests | core | L | 4 |
| Art | 5 terrain gradient maps 0.5, 5 parallax sets 2, hero poses + mount composites + LUTs 1.5, about 14 enemy sheets 2, 6 boss sheets 2.5, about 20 object sprites 1.5, UI (join, panels, belt, hatchery, versus screens, Book II map, Temple Wall picture) 2 | art | L | 12 |
| Audio | about 16 music tracks and 25 effects from the staged picks: loop fixes, loudness (`tools/audio_loudness.py`), `AudioTable`; one human listen-through | art / core | S | 1.5 |
| Integration | campaign flows (both books, both modes), A53 performance pass for two heroes, release checks | QA, core | M | 4 |
| **Total** | | | | **about 104** |

Calendar: wave 0 (4 weeks, blocking) -> co-op core and new systems in parallel by module (about 6 weeks with six
module owners) -> level authoring and bosses in parallel (the long pole, 16 + 7.5 + 12 weeks spread over several
designers and the enemies owner) -> integration. With six engineers and three level designers working in parallel,
about 5-6 months.

### 7.2 Order of work

1. **Wave 0** and its proof (empty digest diff, 575 + new tests green, a bare two-hero level).
2. **Co-op core + Carry & Throw + plates**: enough to build 5-1 and 1-1 co-op as the vertical slice (one new level
   and one retrofit, both modes, routes proven). Playtest with real pairs before anything else is authored.
3. Belt, vines and ropes, Chomper, tides, torches, eggs - each with a showcase test level (`levels/test_*`).
4. Worlds 5-8 and the Book I co-op files in parallel; bosses as each world needs them.
5. Versus (referee, modes, arenas, bots) in parallel from step 2 on; the Chieftains after the bots.
6. World 9, the epilogue, the hatchery, integration and performance.

### 7.3 Riskiest parts

1. **Silent drift of solo Book I during wave 0** (TECH_AUDIT 5.1: the shake timer, the static platform guard, the
   event-driven respawn, feast music). Mitigation: per-tick digests of every route before and after every step, the
   permanent digest-guard test, one owner for wave 0.
2. **Co-op gates that can be cheesed alone** (or a solo key that also opens the co-op gate). Mitigation: the
   solo-impossibility search on every x2 gate, carryables excluded from co-op gate regions by the validator, and
   pair playtests of the vertical slice before content production.
3. **Two-stream route authoring at scale** (61 co-op campaign routes). Mitigation: the recorder (two people with
   pads produce tick-exact proofs) and duo macros; budgeted in route tooling.
4. **New physics that must stay deterministic and doze-safe**: ropes, the mount, the toss. Mitigation: integer
   tables only (the swinger's pendulum), every move capped at 16 px per tick, `notify_hero_teleported` on toss and
   egg moves, the two-hero doze proof.
5. **Performance on the Cortex-A53**: about +100 us per extra hero on desktop (+1-1.5 ms on the A53) against a tick
   budget that 1.0 already misses. Mitigation: a hero performance pass before co-op ships on mobile; co-op on
   low-end Android marked experimental until the `--perf` campaign runs pass with two heroes.
6. **The Chieftains on hero physics with a bot brain**: elegant but new. Mitigation: build them after the versus
   bots exist; fallback to a Brute-style state machine.
7. **Art volume and consistency**: six bosses, five biomes, about 14 enemy sheets. Mitigation: everything comes from
   two Pixel-boy packs plus recolours; style proofs like `_style_tests/biome_*.png` before each world's production.
8. **Shared-keyboard ghosting and tablet duo touch**: mitigated by the key test and by marking the tablet layout
   experimental.

### 7.4 What to cut first if the scope must shrink

| Order | Cut | Replacement | Saves |
|---|---|---|---|
| 1 | Egg Heist, team bots, arenas 9-10 | Party Mix of the four launch modes | about 3 weeks |
| 2 | Kraken Mother | 8-2b becomes a co-op rematch with the enraged Brute in a tide arena (`brute_enraged`, tide rules) | 1.5 weeks + art |
| 3 | Tandem glider | two 1.0 gliders in co-op; Storm Wyrm phase 3 uses glider dive stomps for both | 1 week |
| 4 | Rafts (keep the tide) | drop platforms and bubble jets on tidal water | 1 week |
| 5 | Tablet duo touch | pads for P2 on mobile | 1 week |
| 6 | Chief bot level, deciding-moment replay | Rookie and Hunter only; a still frame of the deciding hit | 1.5 weeks |
| 7 | Hatchery screen | eggs as a counter on the map with an unlock list in Extras | 0.5 week |
| 8 | Chieftains on hero physics | Brute-style state machine on `rival.png` | 1 week |
| 9 | Bonus stages D and E as separate files | warps lead to Feast Land A-C variants | 1.5 weeks (and the level count drops to 18) |

Never cut: wave 0 and its proof, the egg revive, the tribe camera, Carry & Throw with the toss, plates, co-op
versions of all 35 levels, at least four new bosses with co-op phase sets, Food Fight and Last Caveman Standing,
Rookie and Hunter bots.

---

## 8. Open questions for playtests

1. Is "Down + Strike next to a carryable" clear enough, or does it steal low strikes? (Fallback: lift on Down held
   4 ticks while touching.)
2. Look tap (6 ticks) for the belt: does it delay looking noticeably? (Fallback: tap twice.)
3. Co-op windows (24 / 12 ticks) and the Raptor daze (14 / 12): tune with real pairs of mixed skill.
4. Does the Kraken's "volunteer bait" role feel heroic or punishing?
5. Chomper's size in tight corridors (4 rows of air): enough mounted sections, or too constraining?
6. Lift-and-toss in versus: funny or frustrating? (Fallback: tosses spill a quarter, never knock out.)
7. Should Book II unlock earlier for new co-op couples (for example after world 2 of Book I)?

---

## Appendix A - level format and catalogue additions

| Addition | Where | Meaning |
|---|---|---|
| meta `book` | `[meta]` | 1 (default) or 2; campaign and map per book |
| `kind = coop`, `coop_of`, `coop_base_hash` | `[meta]` | Book I co-op files (4.10) |
| `kind = arena`, `players`, `round_time`, `items` | `[meta]` | versus arenas |
| `liquid = tar` | `[meta]` | tar look of `~` (deadly, as water) |
| entity flags `solo`, `coop`, `versus` | entity lines | spawn only in that mode (skipped before spawn) |
| entity param `key=<gate>` | entity lines | the gate a key belongs to (validator pairs co-op and solo keys) |
| entity param `bond=<name>`, `pack=<name>` | enemies | bonds (window rule) and packs (target split) |
| new objects | 4.5, 3.x | `plate`, `seesaw`, `pulley`, `boulder`, `drum`, `x2_tablet`, `hero_start`, `glider_tandem`, `brazier`, `rock`, `egg_pot`, `torch`, `ember_pot`, `vine`, `rope`, `raft`, `bubble_jet`, `mount`, `rex_pen`, `crusher`, `item_spawner` (arenas) |
| new column params | `objects/column` | `rise_while=` / `sink_while=` plate names |
| new zones | `zones/tide` | scripted liquid rows |
| new items | `items/dino_egg index=0..2`, `items/weapon kind=sling` | eggs; the sling |
| new enemies | 4.7, 4.8 | `shellback`, `raptor`, `leech`, `snatcher`, `pack_raider`, `heavy`, `splitter`, `tunnel_king`, `puffer`, `roller`, `wisp`, `shieldtail`, `mimic` |
| new bosses | 5.1-5.6 | `bosses/serpent`, `bosses/tusker`, `bosses/wyrm`, `bosses/kraken`, `bosses/warden`, `bosses/chieftain` |
| route files | `tools/autoplay/routes/` | Book II: `<id>[.expert].inputs` and `<id>.coop[.expert].inputs`; Book I co-op: `<id>_coop[.expert].inputs`; two-stream format of TECH_AUDIT 4.11 |
| validator | `tools/validate_levels.gd` | key pairing per x2 gate, no carryable in co-op gate regions, `hero_start` slots, mode-flagged entities never carry `tile=`, limits per mode, `coop_base_hash` drift warning, arena checks (2-4 starts, 20 x 11 + fill) |

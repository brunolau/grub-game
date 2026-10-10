# PLAN.md - production plan for Club & Grub 2.0 "The Far Shore"

Status: binding plan for the workflows that build `docs/expansion/DESIGN.md`. Author: lead designer, 2026-10-06.
Nothing is implemented yet. Baseline: 1.0.0, `bash .tools/gd.sh test` = 575 passed, 58 files (TECH_AUDIT 1).

Read with: `DESIGN.md` (what to build), `TECH_AUDIT.md` (the N-player refactor, sections 3-6), `docs/ARCHITECTURE.md`
(ownership 1.1, contract rules 1.2). Where this plan names a file glob, that glob is the owner's exclusive write area
for that phase; nobody else edits it.

---

## 0. The plan on one page

| Phase | What | Who | Calendar | Effort |
|---|---|---|---|---|
| **0 Contracts** (blocking) | freeze the single-player evidence; the N = 1 identity refactor; every new constant, id, key, input, save field and hook as a contract; specs appendices | **one contract owner** (core lead, time-boxed waiver) + the lead designer for specs; art may start in parallel | ~5 weeks | ~6.5 ew |
| **1 Systems** | co-op core, Book II systems, versus core with Grub Stack, input / join / HUD, bot infrastructure, co-op objects, first art kit | 15 parallel owners (table 4.1) | ~6 weeks | ~45 ew |
| Gate **G1** | vertical slice: `w5_l1` solo + co-op, `w1_l1_coop`, Totem Ring Grub Stack with bots; pair playtests | all | | |
| **2 Entities, bosses, UI** | new enemies and traits, 6 bosses + 2 co-op forms, LCS / Hot Rock / Clubball, bots per mode, versus screens, map page, all art and music | parallel owners (table 4.1) | ~7 weeks | ~38 ew |
| Gate **G2** | every id of DESIGN's appendix exists with tests; every boss proven solo and refused by the solo search in co-op; 4 modes x 3 arenas with bots | | | |
| **3 Content and proofs** | 20 Book II levels (solo + co-op files), 15 Book I co-op files, 8 arenas + bot graphs (cut 3 applied), all routes | 8 level designers + integration | ~9 weeks (starts in phase 2 for worlds 5-6) | ~37.5 ew |
| Gate **G3** | content complete, every route and bot test green | | | |
| **4 QA and release 2.0** | full runs, performance on the A53, devices, audio listen, licences, exports | integration, core, all owners on call | ~4 weeks | ~5 ew |
| **Total** | | | **~6-7 months** | **~130 ew (plus or minus 30 %)** |

Critical path: P0 -> player-A party moves + world-A PartyDriver / tribe camera -> G1 -> worlds 5-7 content -> co-op
route recording -> G3. Versus and bosses run beside it.

---

## 1. Proposal scores and verdict

Scores 1-10; **risk: 10 = safest**.

| Criterion | A Faithful | B Co-op first | C Bold |
|---|---|---|---|
| Fun | 7 | 8 | 9 |
| Faithfulness to the feel | 10 | 7 | 5 |
| Co-op required and enjoyable | 8 | 9 | 8 |
| Versus entertainment | 7 | 8 | 9 |
| Feasibility in this engine with the art that exists | 9 | 6 | 5 |
| Provability (route proofs) | 9 | 7 | 8 |
| Risk | 8 | 6 | 4 |
| **Total / 70** | **58** | **51** | **48** |

- **A - the spine.** Book II structure on the original's own template (linked sub-stages, Feast Land warps, expert
  wall, single-screen final, playable ending), co-op traits as the twin of the Expert bit, separate co-op files, keeper
  halls 3 rows high against bounce cheese, the Bone Belt that cuts 155 routes to 31, bosses built on art that exists
  (boar, GiantBamboo, SquidGreen, the Colossus mirrored, the pterodactyl at 2x). Weak on "something new" and on versus
  sparkle; fixed by grafts from B and C.
- **B - grafts taken**: the Rival Chieftains (a final boss that uses our own co-op moves, driven by the versus bot
  brain), the seven co-op enemy roles as vocabulary, Tar Pulleys and Mesa Rodeo arenas, Chomper's two seats, the
  `coop_base_hash` drift warning, duo route macros, Helper mode. **Rejected**: "one map, two keys" (bends solo levels
  around co-op geometry), Carry & Throw (Down + Strike steals the low strike), torches, tides, the Kraken / Serpent /
  Wyrm / Warden roster (art risk on front-facing segment chains).
- **C - grafts taken**: the fresh-club belt with its belt-invariance digest test, **Batter Up** and **Brace Wall**,
  the bark-board spear, **Grub Stack** (visible head tower, stomp steals, cookpot) as the versus flagship, **Clubball**,
  the scouting egg. **Rejected**: three mounts (only Chomper stays), stage clocks, low gravity, zip-lines, ropes,
  bola, co-op overlays merged at load.

---

## 2. Ground rules for every phase

1. **Ownership.** ARCHITECTURE 1.1 stays in force; this plan adds sub-owners inside modules (exact globs per phase).
   A file has exactly one owner per phase. Godot `.uid` / `.import` files travel with their file.
2. **Contracts.** `scripts/core/**`, `scripts/base/**`, `tests/test_case.gd`, `tests/run_tests.gd` keep the frozen
   rules of ARCHITECTURE 1.2. After phase 0, a module that needs a new shared member files a request with core-A (or
   the base file's owner) and keeps a private constant meanwhile. `Defs.Phase` values are never changed; party work
   runs in drivers registered after the heroes.
3. **Book I is frozen.** The 15 Book I level files and the 72 route files under `tools/autoplay/routes/` are never
   edited by anyone (guard: V1.d).
4. **Every change set ends green**: `bash .tools/gd.sh test` plus the single-player digest diff (V1) whenever
   `scripts/**`, `scenes/**` or `project.godot` changed. Godot only through `bash .tools/gd.sh` (read its header).
5. **Tuning lives in one place**: hero / party / versus constants in `Tuning`, `PartyTuning`, `VersusTuning` (core);
   enemy constants in `EnemyTuning` (enemies); mount constants in `MountTuning` (player). A playtest change of a value
   marked *(tune)* is recorded in DESIGN.md by the lead designer.
6. **Art and audio**: CC0 only (DESIGN F.3). Every imported file gets its manifest row, CREDITS and THIRD_PARTY entry
   from art-A before the code that uses it is merged. Staging stays under `.tools/asset_candidates/`.

---

## 3. Phase 0 - contracts and the N = 1 identity (single owner, blocking)

**Owner**: the **contract owner** (core lead) with a time-boxed waiver to edit the base files of player, enemies,
objects and world (TECH_AUDIT 6.1); module owners review. **Specs**: the lead designer. **Art** (art-A, art-B) may
start the world 5 kit and the LUTs in parallel (no code).

| Step | Work | Done when |
|---|---|---|
| P0.1 Freeze the evidence | `sim_bench.gd --make-snapshot=res://build/mp_baseline`, then `--digest --tight` with and without `--no-doze` into `build/mp_digest_before*` (TECH_AUDIT 4.12); fix `sim_bench_runner.gd:427` (`_doze_bounds` does not exist); commit digest fixtures for three routes to `tests/fixtures/sp_digest/` and a sha256 list of the 15 Book I level files and 72 route files to `tests/fixtures/book1_hashes.txt` | digests reproducible twice in a row; `--dump` works |
| P0.2 Specs (lead designer) | `docs/spec/PHYSICS.md` appendix "Party and Book II rules" (belt and swap, spear and spear step, climb, tar floor, geyser, raft and current, rising scroll, mount table, Shoulder Hop / Totem Ride / curl / bat / Brace, egg, team wipe, tribe camera, versus hurt table); `docs/spec/GAMEPLAY.md` 13 "Expansion 2.0"; a "Co-op and Book II" chapter in `docs/LEVEL_DESIGN.md` (gates, x2 tablets, traits, keeper halls, solo-impossibility rules, arena rules, route headers) | reviewed by the contract owner; numbers equal DESIGN.md |
| P0.3 Shared constants and events | `Defs`: `MAX_PLAYERS = 4`, `GameMode`, `InputSlotKind`, `IN_SWAP`, `CoopTrait`, `hitter_slot()`. `Tuning` appends; new `PartyTuning` and `VersusTuning` with every DESIGN value; `Events`: `hero_*` twins (hero first), `hero_down`, `hero_revived`, `party_wiped`, `hero_ko`, `round_*`, `painting_found`; `Sfx` event and music context names for every DESIGN F.2 row | `test_core_tuning` / `test_core_*` green |
| P0.4 Run state and save | `scripts/core/player_run.gd` (hearts, bones, hand, belt, glider, stats); `Game.runs / party / mode / book`; the frozen `Game` fields as aliases of `runs[0]` (same write and signal order); `Save.VERSION = 2`: namespaces (mode x book x difficulty), `belt`, paintings, unlocks, migration of 1.0 saves to (single, book 1) | `test_core_game_state`, `test_core_save` + migration test green; digest diff empty |
| P0.5 Input | `GameInput` slots (`slot_flags`, `get_flags`, `set_scripted_slot`, per-slot latches and touch), `InputSlot`, generated `p1_*`..`p4_*` actions, `vibrate_slot`; action `swap` in `project.godot` (V, `;`, pad LB, touch Y stone) - **sampled into `IN_SWAP` but ignored by Book I solo**; route key `S` in `keys_to_flags`; Settings `[bindings_p1]`..`[bindings_p4]` | `flags == get_flags(0)` every tick of every route; `test_core_input_map`, `test_core_bindings` green |
| P0.6 PlayerSet and the mechanical conversion | `LevelBase`: `heroes`, `start_positions`, `target_hero`, `contact_order`, views, union `on_screen`, N-rectangle doze, shake once-per-tick guard, `hero_death_finished`, `respawn_hero`, `notify_hero_teleported`; per-hero platform carry guard; conversion of the 202 touch points of TECH_AUDIT 3 to the target / every / P1 idioms **with no multiplayer behaviour**; `Audio.hold_music` / `release_music` | digest diff empty (doze on and off) |
| P0.7 Level format 2 and registry | `LevelText`, `LevelRegistry`, `TileGrid`: every key of the DESIGN appendix (`book`, `belt`, `kind = coop / arena` + their keys, `coop_of`, `coop_base_hash`, `liquid = tar / honey / syrup`, `scroll = rising` + `rise_speed`, biomes); the `:` tar-floor tile (collision); mode-aware queries (`get_campaign(difficulty, book)`, co-op campaign = `coop_of` substitution, arena list); co-op and arena files never in solo queries | `test_core_level_text`, `test_core_tile_grid` green; the 15 Book I files load to the same grid hash |
| P0.8 Hooks for parallel work | additive public members (bodies minimal, documented): `PlayerBase` (`slot`, `run`, `carried_on_tick`, egg / down API, curl API, mount seat API), empty component calls in `player.gd` for `hero_belt.gd`, `hero_climb.gd`, `hero_mount.gd`, `hero_party.gd`; `EnemyBase` (`last_hit_slot`, `last_hit_tick`, `_on_hit_by`, `accepts_hit_from`, `_choose_target`, `coop_trait`, bond registry); `BossBase.last_hitter`; `PlatformBase` per-hero ride + rider weight; `LevelBase.register_party_driver()`; `ARCHITECTURE.md` updated: 1.1 ownership (sections 4.1 and 6.1 of this plan), 3.x new members, 6.2 catalogue rows for every new id with params, 7 format 2 | every module owner signs off the hook list |
| P0.9 Harness and guards | `parse_inputs_multi`, `run_party_inputs`, `--record=<file>` (debug builds), flow commands (`play 8:R\|L`, `weapon <w> <slot>`, roots `hero2`..), the `# route:` header reader (`level=`, `difficulty=`, `players=`, `ends=`, `expect=`), skeletons of `tests/test_book2_routes.gd`, `tests/test_coop_routes.gd`, `tests/test_coop_gates.gd` (empty tables, passing), the belt-invariance runner; permanent guards `tests/test_core_players.gd` and `tests/test_core_book1_frozen.gd` | guards fail on a deliberately drifted copy and pass on the tree |
| P0.10 Exit | `levels/test_core_party.lvl`: two heroes move independently from two scripted streams | empty digest diff on all 72 routes, doze on and off; 575 + new tests green; waiver closed |

**What must exist before anyone else starts** (the contract list): P0.3 constants and events, P0.4 run state and
save schema, P0.5 input and the `S` route key, P0.6 PlayerSet, P0.7 format and catalogue, P0.8 hooks, P0.9 harness
and guards, P0.2 specs. Nothing in phases 1-3 may change these without a contract request to core-A.

---

## 4. Phase 1 - systems (parallel)

### 4.1 Owners and write areas (phase 1 and onward unless changed)

| Owner | Exclusive globs |
|---|---|
| **core-A** (flow, save, registry, input, audio table) | `project.godot`; `scripts/core/**` except `scripts/core/bots/**`, `scripts/core/autoplay.gd`, `scripts/core/dev/**`; `scripts/base/sim_entity.gd`; `scenes/main.tscn`, `scenes/core/**`; `assets/audio/**/*.import`; `tests/test_core_*.gd` except `tests/test_core_bots*.gd`; `docs/ARCHITECTURE.md`, `README.md`, `docs/BUILD.md`, `docs/PORTING.md`, `tools/build_*` |
| **core-B** (bots) | `scripts/core/bots/**`, `tools/bots/**`, `tests/test_core_bots*.gd`, `tests/test_versus_bots.gd` |
| **integration** (core) | `scripts/core/autoplay.gd`, `scripts/core/dev/**`, `tools/autoplay/*.flow`, `tools/autoplay/*.inputs` (not `routes/`), `tests/test_campaign_routes.gd`, `tests/test_route_tools.gd`, `tests/test_integration_*.gd`, `tests/test_levels_*.gd`, `tests/test_fidelity_*.gd`, `tests/test_book2_routes.gd`, `tests/test_coop_routes.gd`, `tests/test_coop_gates.gd`, `tests/fixtures/**`, `levels/test_integration*.lvl`, `levels/test_core_*.lvl` |
| **player-A** (hero core, party moves) | `scripts/player/player.gd`, `scripts/player/hero_anim.gd`, `scripts/player/hero_party.gd`, `scripts/player/hero_palette.gd`, `scripts/base/player_base.gd`, `scenes/player/**`, `scripts/projectiles/hero_projectile.gd`, `scenes/projectiles/hero_axe.tscn`, `scenes/projectiles/hero_boomerang.tscn`, `tests/test_player_*.gd` except player-B's, `levels/test_player_*.lvl` except player-B's |
| **player-B** (belt, spear, climb, mount) | `scripts/player/hero_belt.gd`, `scripts/player/hero_climb.gd`, `scripts/player/hero_mount.gd`, `scripts/player/mount_tuning.gd`, `scripts/projectiles/hero_spear.gd`, `scenes/projectiles/hero_spear.tscn`, `tests/test_player_belt.gd`, `tests/test_player_climb.gd`, `tests/test_player_mount.gd`, `levels/test_player_book2.lvl` |
| **world-A** (camera, party, zones) | `scripts/base/level_base.gd`; `scripts/world/**` except world-B's; `scripts/zones/**`, `scenes/zones/**`, `scenes/world/**`, `resources/world/**`; `tests/test_world_*.gd` except `tests/test_world_validator.gd`; `levels/test_world_*.lvl` except `levels/test_world_arena*.lvl` |
| **world-B** (versus referee, validator, solo search) | `scripts/world/versus/**`, `scripts/world/level_validator.gd`, `scripts/world/coop_search.gd`, `tools/validate_levels.gd`, `tools/world_*`, `tools/coop_search.gd`, `tests/test_world_validator.gd`, `tests/test_versus_rules.gd`, `levels/test_world_arena*.lvl` |
| **enemies-A** (lead: bases, archetypes, traits) | `scripts/base/enemy_base.gd`, `scripts/base/boss_base.gd`, `scripts/base/projectile_base.gd`; `scripts/enemies/**`, `scenes/enemies/**`; `scripts/projectiles/enemy_*.gd`, `scenes/projectiles/enemy_*.tscn`; `tests/test_enemies_*.gd` except the boss tests of enemies-B / C; `levels/test_enemies_*.lvl` except theirs |
| **enemies-B** (bosses I, phase 2) | `scripts/bosses/{tusker,mangrove,squid}.gd`, `scenes/bosses/{tusker,mangrove,squid}.tscn`, `scripts/projectiles/boss_ink.gd`, `scenes/projectiles/boss_ink.tscn`, `tests/test_enemies_{tusker,mangrove,squid}.gd`, `levels/test_enemies_{tusker,mangrove,squid}.lvl` |
| **enemies-C** (bosses II + co-op forms, phase 2) | `scripts/bosses/{idols,roc,chieftain,brute,colossus}.gd`, `scenes/bosses/{idols,roc,chieftain,brute,colossus}.tscn`, `scripts/projectiles/boss_*.gd` except `boss_ink.gd`, `scenes/projectiles/boss_*.tscn` except `boss_ink.tscn`, `tests/test_enemies_{idols,roc,chieftain,colossus,bosses,brute}.gd`, `levels/test_enemies_{idols,roc,chieftain,brute,colossus}.lvl` |
| **objects-A** (lead: bases, co-op objects, items) | `scripts/base/{collectible_base,hittable_base,hazard_base,checkpoint_base,level_exit_base,platform_base}.gd`; every existing file of `scripts/objects/**`, `scripts/items/**`, `scenes/objects/**`, `scenes/items/**`; new `scripts/objects/{plate,drum,seesaw,boulder_heavy,pulley,flower_pot,x2_tablet,hero_start}.gd` + scenes; `scripts/fx/**`, `scenes/fx/**`; `tests/test_objects_*.gd` except objects-B's; `levels/test_objects_*.lvl` except objects-B's |
| **objects-B** (Book II and versus objects) | `scripts/objects/{vine,bark_board,spear_step,geyser,raft,mount,rex_pen,cookpot,coconut,crate_lane,spawn_point}.gd` + `scenes/objects/` of the same names; `scripts/items/painting.gd`, `scenes/items/painting.tscn`; `tests/test_objects_book2.gd`, `tests/test_objects_versus.gd`; `levels/test_objects_book2.lvl`, `levels/test_objects_versus.lvl` |
| **ui-A** (screens) | `scripts/ui/{title,mode_select,book_select,join,world_map,tally,expert_wall,the_end,credits,code_entry,game_over,unlocks}.gd`, `scripts/ui/versus_*.gd`, the `scenes/ui/` scenes of the same names, `tests/test_ui_screens.gd`, `tests/test_ui_versus.gd` |
| **ui-B** (overlays, options, locale) | every other file of `scripts/ui/**` and `scenes/ui/**` (hud, hud_boss_bar, pause_menu, options, options_panel, touch_controls, glyphs, prompts, ui_kit and widgets), `resources/ui/**`, `locale/en.po`, `tests/test_ui_{overlays,options,locale,signs}.gd` |
| **art-A** (lead: hero, objects, UI, records) | `docs/ASSET_MANIFEST.md`, `CREDITS.md`, `docs/THIRD_PARTY.md`, `assets/licenses/**`, `docs/art/**`; `assets/sprites/{player,objects,items,npc,fx}/**`, `assets/ui/**`, `assets/tiles/feast/**`, `assets/tiles/common/**` |
| **art-B** (worlds and creatures) | `assets/tiles/{canyon,swamp,coast,ruins,sky}/**`, `assets/backgrounds/{canyon,swamp,coast,ruins,sky}/**`, new files in `assets/sprites/enemies/**` and `assets/sprites/bosses/**`; hands manifest / credit rows to art-A through `.tools/asset_candidates/expansion/_handover/` |
| **audio** (art sub-owner) | new files in `assets/audio/music/**`, `assets/audio/sfx/**` (not the `.import` files); loudness numbers handed to core-A for `AudioTable` and to art-A for the manifest |
| **lead designer** | `docs/spec/**`, `docs/LEVEL_DESIGN.md`, `docs/expansion/**` |

Level-designer globs start in phase 3 (section 6.1).

### 4.2 Phase 1 work

| Step | Owner | Work | Depends on |
|---|---|---|---|
| P1.1 | core-A | Flow: Play > Solo / Co-op / Versus, book select plumbing, `start_coop_game`, `start_versus` + round loop skeleton, join / leave restarts at the checkpoint, pad reconnect pause; mode-aware registry use in Flow; feast music refcount in multiplayer; `VersusMatch`; `AudioTable` batch 1 (effects) | P0 |
| P1.2 | core-B | `HeroBot` input producer (`InputSlot.BOT`, own `SimRng`), nav-graph baker `tools/bots/bake_nav.gd` with every link verified by simulating the real hero, graph format in `resources/bots/`; a bot walks `levels/test_world_arena_flat.lvl` | P0 |
| P1.3 | integration | belt-invariance runner live on the test levels; recorder proven (two pads -> tick-exact replay); `campaign.flow` / `campaign_beginner.flow` updated for the new title path (Book I routes untouched); `campaign_b2.flow`, `campaign_coop.flow` skeletons | P0 |
| P1.4 | player-A | slot plumbing, palette LUT shader (`hero_palette.gd`), edge walls, egg / down state (hero side), voluntary egg, Shoulder Hop, Totem Ride (rider side), curl and the batted-ball flight, Brace flag, versus hurt reactions (12 stunned + 30 immune), emote bubble; hero performance pass for the A53 | P0 |
| P1.5 | player-B | belt and swap (hand / belt, fresh-club rule, 8-tick lock-out), spear throw and spear-step request, CLIMB state (vines), tar-floor response, mount driver / gunner states with `MountTuning` and a reference jump-table test | P0 |
| P1.6 | world-A | tribe camera (`tick_group` / `snap_group`, leash -> egg), `party_driver.gd` (Totem Ride resolution after both heroes moved, Batter Up launch from a partner's strike, hatch, team wipe, bones to partner, team exit and gate travel, Relay Bounce), zone masks and team rules, `scroll = rising`, `zones/current`, tar-floor drawing, liquids `tar` / `honey` / `syrup` | P0 |
| P1.7 | world-B | arena loading (`kind = arena`, locked camera, wrap left-right / top-bottom), `scripts/world/versus/referee.gd` (gather-then-apply PvP hits, clang, deflect, stomp ladder, curl and bat rules, KO, respawn, spawn shield), **Grub Stack** rules and the stack display; validator rules (traits only in co-op files, x2 tablet pairing, plate distances, hall heights, gate counts, `coop_base_hash` drift warning, arena checks); `coop_search.gd` v1 (static rules + bounded single-hero search on the route tools' simulator) | P0 |
| P1.8 | enemies-A | `scripts/enemies/coop_traits.gd` (shell, bond, daze, heavy, lone, grab, leech, split) + bond registry; trait tests and two-hero contact tests of the Brute and the Colossus (converted in P0.6, solo behaviour unchanged) in `tests/test_enemies_coop.gd` on `levels/test_enemies_coop.lvl` | P0 |
| P1.9 | objects-A | per-hero item effects, shared checkpoint (hatches eggs), team exit / gate, `plate`, column `rise_while` / `sink_while` / `keepers`, `drum`, `seesaw`, `boulder_heavy`, `pulley`, `flower_pot`, `x2_tablet`, `hero_start`, `items/weapon kind=spear`; `levels/test_objects_coop.lvl` | P0 |
| P1.10 | objects-B | `vine` (+ rolled), `bark_board`, `spear_step`, `geyser`, `raft`, `mount` + `rex_pen` (unmounted rex AI, bolt home), `items/painting`; `levels/test_objects_book2.lvl` | P0, P1.5 hooks |
| P1.11 | ui-A | mode select, book select, join panel (press Jump to join, colour, ready, key test) | P1.1 |
| P1.12 | ui-B | HUD P2 panel, belt icon, edge arrows; pause per slot; options P1-P4 bindings + keyboard test; the three shared-keyboard presets of DESIGN D.11 with **classic WASD + numpad as the versus default** (NumLock on and off verified on Windows, a test that drives a two-player match from those physical keys only); touch Y-stone swap and the table-mode prototype; **locale sub-catalogues** (`locale/levels/<lang>/*.po` loaded beside the language file, not offered as languages) | P0 |
| P1.13 | art-A / art-B / audio | P1-P4 LUTs and loincloth patterns, `hero_spear`, egg recolours, co-op object sprites, belt icon, x2 tablet; the full **world 5 kit** (terrain, parallax, props, Roller / Guard / snake sheets, Tusker); effects batch of DESIGN F.2 | none (staging) |
| P1.14 | designers D5 (world 5), DB1 (Book I co-op 1-2), DA (arenas) | drafts of `w5_l1` + `w5_l1_coop`, `w1_l1_coop`, `arena_totem_ring` for the slice | P1.1-P1.10 |

**Gate G1 - vertical slice** (all owners): `w5_l1` with its Beginner club route; `w5_l1_coop` and `w1_l1_coop` with
two-stream routes; `arena_totem_ring` playing Grub Stack with two humans and two Rookie bots; belt invariance green on
`w5_l1`; the solo search refuses every x2 gate of the two co-op files. Then **pair playtests** with mixed-skill pairs
on every co-op gate type; window and daze values are tuned and written into DESIGN.md before content production.

**G1 outcome (2026-10-07, commit 7d1306a)**: passed on every automated criterion (1135 tests, single-player
identical, the slice through the real UI). The pair playtests did not take place: the window and daze values stay at
their starting values for phase-3 content and the playtests move to P4.5 (they can only shorten windows, which keeps
every gate solo-impossible). The orchestrator's resolutions and the lead designer's decisions are DESIGN.md "Appendix:
G1 and phase-2 resolutions"; the phase-3 briefs of worlds 6-9, Feast Land E and the Long Raft Home are DESIGN.md A.6.

---

## 5. Phase 2 - entities, bosses, versus modes, UI, art

| Step | Owner | Work |
|---|---|---|
| P2.1 | enemies-A | `roller`, `guard`, `mimic`; co-op-only `shellback`, `raptor`, `snatcher`, `leech`, `bull_rex`, `tar_splitter`, `shaman`; every Book II skin (A.5) as art lands |
| P2.2 | enemies-B | Tusker, Old Mangrove, Inkjaw (ink projectile), each with solo and co-op forms and a `test_enemies_<boss>.gd`: telegraphs >= 10 ticks, escapability, no stun-lock, club beats the solo form, the co-op weak window is shorter than the measured solo minimum |
| P2.3 | enemies-C | Twin Idols and Storm Roc first; co-op Brute and visor Colossus (fairness tests per hero); then the Rival Chieftains on hero physics fed by `HeroBot` (needs P2.5); fallback state machine kept behind a flag until the bot version passes its tests |
| P2.4 | world-B | Last Caveman Standing (hearts, bones, Grudge Pterodactyls), Hot Rock, Clubball (goal zones, escalation), themed sudden deaths, crates, Party Mix / presets / variants; `tests/test_versus_rules.gd` scripted matches |
| P2.5 | core-B | bot behaviours Rookie / Hunter / Chief for the four modes, Clubball ball prediction, the boss interface for the Chieftains; `tests/test_versus_bots.gd` |
| P2.6 | core-A | round loop and deciding-moment replay (input log + start snapshot), painting unlock table, Book II campaign plumbing (codes, expert wall), `AudioTable` batch 2 (music, loop regions) |
| P2.7 | objects-B | `cookpot`, `coconut`, `crate_lane`, `spawn_point`; Chomper's arena pen timer |
| P2.8 | ui-A | Far Shore map page and painting slab, expert-wall picture for Book II, versus lobby / rules / arena select / scoreboard / results / awards, co-op tally medals, unlocks screen |
| P2.9 | ui-B | versus HUD (four corner panels, sundial, crown, colour arrows), Rival-score option, Helper mode option |
| P2.10 | art-B | worlds 6-9 kits; boss sheets (Mangrove composite, Inkjaw + tentacle, Idols, Roc 2x re-pack, Chieftains); arena dressing |
| P2.11 | art-A / audio | map page, slab, mural, portraits, versus screens, Feast Land D / E skins; music batch with loop fixes and loudness |
| P2.12 | player-A / player-B | tuning from playtests; A53 hero performance pass |

**Gate G2**: every id of the DESIGN appendix exists with tests; each boss is beaten solo by a scripted route on its
test level and its co-op form is refused by the solo search; the four launch modes run with Hunter bots on three
arenas; G1 still green.

**G2 integration (2026-10-07)**: rulings in DESIGN.md G28-G32. Numbers: default suite 1 517 tests green in 274 s
(the route replays moved to slow modules, V7); slow modules green - `campaign_routes` 18, `book2_routes` 6 (17 route
runs), `coop_routes` 6 (12 two-stream runs), `coop_gates` (18 gate searches, all refused) and `versus_bots` (2, every
(arena, mode) with four Hunters); `tools/sp_identity.sh` IDENTICAL; validator `--strict` clean on all 74 level files;
smoke clean; `campaign.flow` passes headless (116 checks). Proven: every appendix id has its scene and a test (`tests/test_integration_appendix.gd` reads the appendix); Tusker,
Old Mangrove and Inkjaw lose to recorded club routes on their test levels (Tusker and Old Mangrove also inside the
Book II routes of 5-2b and 6-2b), and every boss's co-op form - the six new ones, the Brute and the visor Colossus -
is refused by its single-hero search; Grub Stack, Last Caveman Standing and Hot Rock with four Hunters on the Totem
Ring, Echo Hollow and Cinder Pit and Clubball on Coconut Cove (the only Clubball arena of E.5) pass V4.b; the G1
slice is green again (w1_l1_coop's 'hop' rebuilt to the 8-row rule, G28); worlds 5-6 of D5 / D6 pass their solo,
co-op and gate tests; windowed flows through the real UI: `tools/autoplay/g2_book2.flow`, `g2_coop_b2.flow`,
`g2_versus.flow`, `g1_coop.flow`, `g1_versus.flow`. Open at G2: the Twin Idols, the Storm Roc and the Rival
Chieftains are beaten in their tests by a closed-loop pilot or injected strikes, not yet by a recorded route on their
test levels (enemies-C, before D8 / D9 build 8-2b, 9-1b and 9-3).

---

## 6. Phase 3 - content and proofs

**Phase 3 start (2026-10-08)**: the orchestrator's decisions (the idle partner, boss co-op forms by actions, boss weak
points clear of the HUD, bonded-pair placement, cut 2 applied, cut 3 conditional) and the lead designer's decisions
on the G2 reports are DESIGN.md G33-G43; the rulings went to every owner as `build/engine_requests/wf9_lead_design_to_*.txt`.
The lead designer's rulings on the reports of phase 3 (designers' as-built forms, the daze and the lee, boss key items,
idle doorstops, human-only arenas, the co-op Brute's leap) are G44-G56; `docs/spec/test_spec_docs.py` pins them
against the code and skips, with the request named, each one whose owner has not built it yet.

### 6.1 Level-designer write areas

| Designer | Exclusive globs |
|---|---|
| D5 (world 5 + Feast Land D) | `levels/w5_*.lvl`, `levels/bonus_d*.lvl`, `tools/autoplay/routes/w5_*.inputs`, `tools/autoplay/routes/bonus_d*.inputs`, `locale/levels/en/w5.po` |
| D6 (world 6) | `levels/w6_*.lvl`, `tools/autoplay/routes/w6_*.inputs`, `locale/levels/en/w6.po` |
| D7 (world 7 + Feast Land E) | `levels/w7_*.lvl`, `levels/bonus_e*.lvl`, `tools/autoplay/routes/w7_*.inputs`, `tools/autoplay/routes/bonus_e*.inputs`, `locale/levels/en/w7.po` |
| D8 (world 8) | `levels/w8_*.lvl`, `tools/autoplay/routes/w8_*.inputs`, `locale/levels/en/w8.po` |
| D9 (world 9 + ending) | `levels/w9_*.lvl`, `levels/ending_b*.lvl`, `tools/autoplay/routes/w9_*.inputs`, `tools/autoplay/routes/ending_b*.inputs`, `locale/levels/en/w9.po` |
| DB1 (Book I co-op, worlds 1-2, Feast Lands A-B) | `levels/w1_*_coop.lvl`, `levels/w2_*_coop.lvl`, `levels/bonus_a_coop.lvl`, `levels/bonus_b_coop.lvl`, the matching `tools/autoplay/routes/*_coop*.inputs`, `locale/levels/en/coop_b1.po` |
| DB2 (Book I co-op, worlds 3-4, Feast Land C, Way Home) | `levels/w3_*_coop.lvl`, `levels/w4_*_coop.lvl`, `levels/bonus_c_coop.lvl`, `levels/ending_coop.lvl`, the matching route files, `locale/levels/en/coop_b2.po` |
| DA (arenas) | `levels/arena_*.lvl`, `resources/bots/arena_*.json` (baked with core-B's tool) |

The Book I solo files `levels/{w1_l1,...,ending}.lvl` and their 72 routes belong to nobody: frozen.

### 6.2 The per-level recipe (Book II)

1. Build the solo file (`book = 2`); validator clean (`--strict`); preview at the base view and 2400 x 1080.
2. Record the Beginner and Expert club routes with a `# route:` header; `test_book2_routes` green; belt invariance green.
3. Record featured routes for special-only secrets and the painting where it needs a special.
4. Copy to `<id>_coop.lvl` (`kind = coop`, `coop_of`, `coop_base_hash`), add P2's start, co-op gates with x2 tablets,
   traits (>= 1/3 of records, every chokepoint guard), paired specials; validator `--coop` clean;
   `test_coop_gates` green (every gate refused by the solo search - exhaustively, or bounded with every probe of its
   kind; a bound alone is "unproven", V3.c / DESIGN.md G59). Since the G3 follow-up round: every `heavy` stands on
   a flat floor a pair can brace on (it is hurt only in a braced daze), and enemy `hp` is set as strikes - `hp` / 25 +
   1 club strikes in a co-op file (DESIGN.md G57 / G63, LEVEL_DESIGN 15.7.5).
5. Record the two-stream co-op routes (two people with pads through `--record`, or duo macros) per difficulty;
   `test_coop_routes` green. A plate holder crouches (a hero 243 ticks without input is idle and holds nothing; plate
   signs say "crouch", G58); the pair stays together at heavies and Tar Splitters (G57 / G63); a co-op boss route
   carries `fight_ticks:1093..2185` and, on Expert, `max_hurts:6` in its header (G61).
6. Signs: keys `SIGN_W5_*` in the designer's locale file.

Order: worlds 5-7 and both Feast Lands first (Beginner content and the first three bosses), then worlds 8-9 and the
ending. DB1 / DB2 work in parallel from the start of phase 3 (their boss co-op forms land in phase 2). DA builds the
arenas and bakes graphs as soon as P2.4 / P2.5 land; each arena ships only when its bot test is green (otherwise it
ships human-only, see cut list 4).

Integration keeps `test_book2_routes` / `test_coop_routes` / `test_coop_gates` and the end-to-end campaign tests
(Book II per difficulty, co-op Book I and II per difficulty, headless twins of the new flows) green throughout.

**Gate G3**: 20 Book II files + 35 co-op files + 8 arenas (cut 3 applied [G60]); 31 solo club routes, about 6 featured
routes, 57 two-stream co-op routes, belt invariance on all, every x2 gate refused by the search - exhaustively, or
bounded with every probe of its kind (DESIGN.md G59; a bounded search alone is "unproven") - every (arena, mode) bot
test green or the mode human-only (cut 4), every co-op boss fight inside DESIGN.md G61's band.

**G3 integration (2026-10-08, `bash tools/g3.sh`, run dir `build/g3/run_g3final2`)**: content 20 / 20 Book II files,
35 / 35 co-op files, 31 / 31 solo route cells, 6 / 6 featured routes, paintings 20 / 20, x2 gates 76 / 76 (9-3 and the
boss sub-stages gated by their co-op form, G49), 8 / 8 launch arenas (Tar Pulleys human-only, G50; Mesa Rodeo and
Cloud Top not built, cut 3); co-op route cells **51 / 57** - `w1_l2_coop`, `w2_l1_coop` and `bonus_b_coop` (DB1) have no
two-stream route on either difficulty. Proofs: default suite 1 657 / 1 657 (313-433 s, V7); `campaign_routes` 18 / 18;
`book2_routes` 8 / 8 with its G3 switches ON (every Expert cell; the Beginner run plays 10 stages - Feast Land E by
7-1's warp - to the expert wall, the Expert run 18 to The End); `coop_routes` 9 / 10 (the one red test lists DB1's three
files; every other co-op route passes V3.a / V3.b / V3.e / G35, the co-op Book II runs reach the expert wall and The
End, the Book I runs stop PENDING at `w1_l2_coop`); `coop_gates` 76 / 76 refused on the G33 / G47 engine
(`tools/world_coop_gates.sh`, 12 workers, 382 s); `versus_bots` green in 8 shards (`tools/g3_versus_bots.sh`): 15 launch
cells plus the test arenas, Coconut Cove's Clubball 48 / 52 % after the coconut's symmetric x step; `tools/sp_identity.sh`
IDENTICAL; validator `--strict` 0 errors on 120 files (2 optional lee warnings in `w3_l1b_coop`); smoke clean; the
campaign flows headless (`campaign` 116 checks, `campaign_beginner` 14, `campaign_b2` 155, `campaign_coop` 234 with
Book I PENDING); windowed with screenshots looked at: `tools/autoplay/g3_versus.flow` (every bot cell through the real
versus UI, 96 checks, 149 screenshots), `campaign_b2.flow` (155 checks, 187 screenshots, both difficulties to the
expert wall and The End), `campaign_coop.flow` (234 checks, 233 screenshots; Book I PENDING at `w1_l2_coop`); the
Windows build
(`tools/build_windows.ps1`: suite, export, smoke - 78 levels, 0 errors). Built by the integrator for owners who did not
run in phase 3 (DESIGN appendix "Built at G3"): G33 / G47 (`coop_traits.gd`), G39, G45 + the rails picture, G50
(`test_versus_bots`, `VersusMatch`), G52, G56, the gate.gd doze re-decision (V3.e), the bench's boss bot slots, the
flow runner's boss bot slots, the coconut, w5_l1_coop's bond (G36), w9_l2's feast kit order (a kit carried from 8-1
completed it early in the Expert campaign), bonus_a_coop's route. **Gate G3 is not reached**: the three DB1 co-op files
need their routes; open besides: G54 (a head as a step into rock), the raft's drag clock while dozing, the 5-1 spear
route for the Feast Land D warp (D5), Floe Rink's see-saw floes (G51) and Tar Pulleys' CPUs (core-B).

**G3 verification and the follow-up round (2026-10-08)**: the G3 verifier (`build/engine_requests/wf9_g3_verify_*`)
failed the gate on more than the DB1 routes: one hero passes `w9_l2_coop` 'brace' and kills `w3_l1_coop`'s 'lake'
keeper (a Bull Rex runs under a jumping hero; one strike hit on every tick), and the cached "76 / 76 refused" was a
node bound. The orchestrator's decisions of the follow-up round are DESIGN.md G57-G61 - heavy keepers hurt only while
brace-dazed and one hit per strike in co-op files (G57), the idle warning and "crouch" plate signs (G58), refusals
that name their evidence (G59), cut 3 applied with the lead designer's painting ladder, Echo Hollow without its
walls and dangler, Floe Rink Grub Stack only, Tar Pulleys' bots only on green pulley links (G60), and co-op boss
fights of 45-90 s with at most 6 hurts on Expert (G61, baseline in DESIGN B.0: only Tusker is inside the band at G3);
the lead designer's review of the designers' deviations is G62 (all four accepted; Chomper two seats is no gate kind).
The rulings went to the owners as `build/engine_requests/wf10_lead_design_to_*.txt`.

**The follow-up round as the lead designer left it (2026-10-08; a power cut at about 19:40 stopped the round, which
resumed from commit 22db9d8)**. Built and proven: G57 (enemies-A: a heavy takes damage only in a braced daze and dies
of nothing else, one hit per strike in co-op files; `test_enemies_coop` 44 / 44 in the lead designer's run, 46 rows since; the G3
verifier's solo attacks on 'brace' and 'lake' fail; the co-op routes it broke are re-recorded, `w6_l1_coop.expert`
with its header unchanged); G58 (party's "Zzz soon" bubble from the 170th quiet tick, `test_player_idle` 21 / 21;
every plate sign of the list says "crouch"; integration's route proofs check the idle rule on every tick); G59's
verdict lines (world-B, `CoopSearch.gate_verdict`) and their table (integration, `tools/g3.sh`); cut 3 in the arena
files and the table (8 / 8), and Tar Pulleys with bots in Grub Stack and Hot Rock on core-B's pulley links (Last
Caveman Standing human-only there); G61 (bosses: every co-op fight 47-83 s on its recorded route, the Expert stages 0-6
hurts, re-measured unchanged by the lead designer after the resume; the route headers pin the band); G54's hero-side
guards (`test_player_g54` 9 / 9 in the lead designer's run) and the docked raft's 7 px strip (party). Rulings of the resumed run, DESIGN.md G63-G69: the 1.0 death rule
stays, so an enemy takes `hp` / 25 + 1 club strikes (a 100-hp keeper five, not four), a repeat tick of a swing is
used up, the splitting swing never hurts the record's half again (G63); the Rival Chieftains' crow carries a "HA!"
bubble, built by bosses, `test_enemies_chieftain` 27 / 27 (G64); the rising view keeps the highest footing 72 px
under its top and the drawn view looks up for a jumper's head, so 6-2b's solo climber is never drawn behind the HUD band (G65,
party's rule on the lead designer's requirements; LD 15.5's step-down rule becomes 6 rows); a flying keeper holds its
perch (G66); the lone hero's real reach - the hop jump, the pogo jump, a 123 px strike reach - and the coil rule: in
a co-op file a rolled vine unrolls only for a hit from its own level (G67, on DB1's one-player probes); DB1's 1-2
'shaft' (an 8-row boost ledge with a plate-driven lift stone, no pulley) and his other deviations accepted (G68);
every height gate is 8 rows - a Totem ledge of 5-6 rows is inside a lone hop jump, and 1-2 'treehouse' is rebuilt
as a boost ledge (G69).
**Open when the lead designer closed** (each named in its DESIGN row): **the coil rule of G67 is not built** (the
vine has no owner in the round; party, asked, declined: not its file) - until it is, the rolled-vine drop gift of eleven co-op files can
be struck down from the floor below by a player who knows the hop jump, and the search does not play that move yet,
so the verdicts of those height gates say less than they read; world-B's G59 probes found
`w9_l1b_coop` 'stormwall' **open** (one hero leads the first keeper Harrier to the second and kills both inside the
bond window) - G66's perch rule is built since (enemies-A; `test_enemies_coop` 48 / 48 in the lead designer's
run, the pair's route unchanged), but world-B's re-run of the gate had not been posted; G65's co-op clause -
the rising view must wait for the lower partner - is decided and not built: as built 6-2b's Beginner reference
pair loses its second hero to the leash three times in the climb (`w6_l2b_coop.inputs`, 0 before the rule); world-B's full verdict table (exhaustive
/ bounded + probes / open / unproven per gate) had not been posted, so G62's 'root', 'dune' and 'seagate' are still
"unproven"; the painting ladder of G60 is not built (no core-A, art-A or ui agent ran: the game still names the two
cut arenas as rewards); `w3_l2_coop.inputs` (Beginner), which [G54]'s guard moved, was still being re-recorded by
party; `PartyTuning.IDLE_WARN_TICKS` waits for a core-A owner (a private constant of `hero_party.gd` meanwhile). Gate G3 is therefore **not reached** by the lead designer's record; the verdict is the
G3b integrator's and verifier's.

**The G3b integration (2026-10-09, after every other agent of the round had closed)**. world-B's final table had
reached the lead designer after he closed: 40 gates refused (exhaustive), 27 refused (bounded), **9 rows open** - six
gates of five co-op files, all through the lone hero's moves of G67 (the hop jump, the pogo jump), none through a
coil. Built by the integrator, for the owners who did not run:
- **the coil rule of G67** (`scripts/objects/vine.gd`; a ball's touch in `hero_party.gd`): in a co-op file a rolled
  vine unrolls only for a hit from its own level; `test_objects_book2` +2 rows (the real hero's hop jump with a high
  strike from the floor 8 rows under the ledge opens a solo coil and never a co-op one), DB1's regression probe of
  1-2 'treehouse' "refused (21 trials)", the routes of the eleven rolled-vine files replay;
- **the six open gates, rebuilt in their level files** by the building rules of G67 / G69 (DESIGN.md **G70**; no
  engine rule): `ending_coop` 'lookout', `w3_l1_coop` 'cliff', `w7_l1_coop` 'dune' and 'stack', `w9_l1_coop` 'pulley',
  `w9_l2_coop` 'drive'; the two 7-1 co-op routes and the 9-1 co-op route re-recorded with their designers' bots, the
  others replay unchanged;
- **the painting ladder of G60** (core-A's `unlock_table.gd`, `tuning.gd`, `save.gd`, `versus_match.gd`; art-A's
  pattern tags, `ui/unlock_icons.png` and the slab's carved marks; ui's `en.po` and `unlocks.gd`; their tests);
- `PartyTuning.IDLE_WARN_TICKS` (G58); `Spawner` keeps the scripts of every scene its cache drops until the engine
  shuts down (integration's finding of the round: Godot 4.7.2 leaks a script that dies while the script language
  runs - the shipped game printed leak errors at exit after co-op 4-2 into 4-2b; `test_core_level_base`);
- `tests/test_world_validator.gd`'s search-reset row moved its test coil one row down (the coil rule);
  `tools/autoplay/g3_versus.flow` walks a human into the open at the start of Last Caveman Standing on Colossus
  Hall (both humans spawn under a ledge that no stalactite of the sudden death passes: two heroes who never move
  there never end the round - a question for the pair playtests of P4.5, not changed in the game);
  `docs/ARCHITECTURE.md` 9.1 names the slow modules and slow tests of the round.

**Gate G3: REACHED** on the tree of 2026-10-09 (`G3_TAG=g3b_final1 bash tools/g3.sh --require --shards=12
--jobs=16`, table `build/g3/run_g3b_final1/g3_table.txt`): content complete (20 Book II files, 35 co-op files, 31 / 31
solo and 57 / 57 co-op route cells, 6 featured routes, 20 paintings, 76 x2 gates, 8 arenas, 21 of 22 versus cells
with CPUs - Tar Pulleys' Last Caveman Standing human-only); the default suite 1 675 / 1 675 in 176 s on its own
clock, the slow tests 15 / 15; `test_campaign_routes` 18 / 18, `test_book2_routes` 8 / 8, `test_coop_routes` 10 / 10;
**76 / 76 gates refused, uncached: 51 exhaustive, 25 bounded with every probe of their kind**, none open, none
unproven (`coop_gates_verdicts.txt`); the bot sets 32 / 32 over 21 cells; `tools/sp_identity.sh` IDENTICAL;
`docs/spec/test_spec_docs.py` 85 / 85 with no ruling pending its owner; the five flows pass headless with a clean
exit (Book I both difficulties, Book II both difficulties with both Feast Lands, the co-op campaigns of both books,
the harness exit). Beside the table: the four campaign flows and `g3_versus.flow` (the 17 cells CPUs play) also pass
**windowed** (off-screen, muted; 14 / 116 / 157 / 367 / 108 checks, 849 screenshots under `build/screenshots/g3b_*`,
no leak report at exit) and `g3_versus.flow` headless (108 checks); `tools/validate_levels.gd` - 120 files, 0
errors, and `--coop` over the 36 co-op files 0 errors with all 76 gates refused (the two warnings of both runs are
3-1b's lee comfort; `--coop` now asks only for the difficulties a file is played in, as the gate test does - it had
searched Expert-only files on Beginner); `tools/build_windows.ps1` - a clean import, the suite 1 675 / 1 675 in
161 s on the then idle machine (V7's 5 minutes), the release exe exported and booted (smoke: 0 errors, 78 levels,
no developer level, development switches ignored).
**Still open after G3** (none of them a row of the gate; each for phase 4): G65's proof - the Beginner reference
route of 6-2b in co-op still loses P2 to the leash three times in the climb (its pilot, DESIGN G65);
`w7_l2b_coop.expert.inputs` sits exactly on its `max_hurts:6`; two bot sets sit on the edge of the fairness band
(Sky Picnic and Totem Ring, Grub Stack); the Colossus Hall stalemate above; a freed entity can stay filed in
`LevelBase`'s doze index (seen only in the search world, worked around there, not reproduced in the game); no static
validator rule for G67's clean foot or G70's one-way ledges (the search is their proof); the human pair playtests
of P4.5.

**The G3b verification (2026-10-09, the adversarial verifier's record; `build/engine_requests/wf10_g3b_verify_to_*.txt`)**.
**Gate G3 is NOT passed.** Everything the table of `run_g3b_final1` ran was re-run and is green (run dir
`build/g3/run_g3bv_a` beside an uncached search of all 76 gate rows at 3x the bounds, one gate per process: 59
exhaustive, 17 bounded with every probe, none open - `build/g3bv/deep_verdicts_3x.txt`), and none of 60 one-player
replays of the eight co-op bosses beats one. But the search's refusals are refusals of its own moves: a
continuous-play explorer in the same search world (`build/g3bv/explore.gd`: nothing reset between moves, the whole
level, 300 s per gate row) brings **one hero to the far cell of 12 of the 45 gates - 19 of the 76 rows, in 9 of the
23 gated files** - each a route that replays in a fresh process (`build/g3bv/evidence/`,
`bash build/g3bv/verify_evidence.sh`), 'dune' of 7-1 also in the real game with P2's slot quiet. By cause:
(A) an Up bounce on an enemy he wakes, leads or meets at the gate - `w7_l1_coop` 'dune' (the lone gull 22 columns
back; the rebuilt dune holds against the hop jump only), `w1_l1_coop` 'hop' (Expert), `w3_l2_coop` 'drive' and
'floes', `w6_l1_coop` 'root', `w7_l2_coop` 'dark_gap' (Expert), `w9_l2_coop` 'drive', `w9_l1b_coop` 'stormwall';
(B) the hop jump begun on a spring: 256 px, 16 rows, off every pad and cap - `w2_l2_coop` 'seesaw';
(C) a bond broken by two hits in flight (a special thrown at the far member, the near one hit as it lands) -
`w5_l2_coop` 'rattlers', 'stormwall', and the drum bond of `w4_l2_coop` 'drums';
(D) a climb the search cannot play (a vine longer than its 96-tick move) - `w7_l1_coop` 'stack' from the warp stack;
(E) through a closed one-cell keeper door from the keeper's head - `w9_l2_coop` 'brace'.
Four more rows were reached once and do not replay (the search world's reset is not exact: `w6_l2_coop` 'seesaw'
and 'caps', `w2_l2_coop` 'lift', 'drums'); the other 53 rows did not fall to 600 explorer-seconds on two seeds. The remedies are rulings
(the big bounce of a lone hero, a spring as a launch, slot-bound bonds, one-cell doors) and designers' files, not a
verifier's edits: nothing but `tools/g3.sh` was changed (a run that leaves proofs out no longer prints "REACHED").
The next G3 needs every route of `build/g3bv/evidence` to fail and the explorer beside the search in the gate test.

**The causes by rule (2026-10-09, the round after G3b; the lead designer's record)**. Rebuilding gates one by one had
failed twice, so the orchestrator closed the causes by rule (R1-R8, recorded as DESIGN.md G71-G78 with the as-decided
details): (B) a spring is a launch for a hero of a co-op party (G71); (C) bonds, keeper pairs, drum pairs and splits
are slot-bound (G72); (A, E) the ward - around every x2 tablet no enemy gives lift, rest, carry or a pogo (G73); (D)
the long drop as a building rule and 7-1's warp stack out of reach of the 'stack' shoulder (G74); (E) a closed door
passes nobody (G75); an idle hero is no camera anchor and is the one the leash takes (G76); a Last Caveman Standing
round ends at a hard cap (G78); and the proof of a gate is three things, a fixed bar (G77, V3.c below). The lead
designer traced all 21 evidence routes on the tree before the rules (`build/lead_design/traces/`): every head bounce
of the cause-A and cause-E routes lies inside its tablet's ward by the default margin of 12 cells but one -
`w1_l1_coop` 'hop' takes its lift at columns 87-88 and its ward began at 88, so that tablet carries `ward=22,12` (the
margin counts from the gate's high ground); with the ward built, the verifier's explorer opened 'hop' under the
default margin from the pool's ledge at columns 80-83 (seed 2, 164 s;
`build/lead_design/evidence/w1_l1_coop.hop.expert.pool_ledge_default_ward.txt`) - the override is needed. And one row
was no head bounce at all: **a sixth cause (F), the gust jump** (G79) - `w9_l2_coop` 'drive' falls on BOTH
difficulties to a lone hero who waits for the level's tailwind and jumps its 9 cells of tar from the slide (10.1
cells), touching no enemy's head (`build/lead_design/evidence/w9_l2_coop.drive.{expert,beginner}.gust_no_lift.txt`,
each replayed in a fresh process: far cell at tick 326 / 324). No rule of the round closes it: the gap is rebuilt (12
cells or a raised far lip), the search plays the wind's phases, and the evidence set is 24 routes (with that 'hop'
route). With it one hero passed **20 of the 76 rows** on the G3b tree. At the lead designer's close, on the tree with
the engine rules built, 20 of the 24 routes say "not reached" or "DIED" in fresh processes
(`build/lead_design/after3/`); the four that still reach are the level-file work of the Levels phase: 7-1 'stack'
(Expert), 1-1 'hop' until its `ward=22,12`, and 9-2 'drive' on both difficulties.

**The G3c integration (2026-10-09, after every other agent of the round had closed)**. At world-B's close the three
proofs stood at 64 of 76 rows green and 12 red, each red row with a route that replays; nine of the twelve were
finds of the round's own explorer, and two causes among them had no rule: a coil's "own level" was met in
mid-air (a special thrown at the top of a jump from a ledge below unrolled it - 2-2 and 6-2 'seesaw'), and one
hero killed both keeper Shellbacks of 5-1 'gully' with a special thrown from on top of them or from inside them.
The Levels phase closed all twelve in the level files (13 files: the wards of nine tablets widened until the
validator named no top, a stalactite and a rock roof over the two see-saw cap ledges, the foot of 2-2's x2 bone
ledge cleared, the gully's keepers a slot-bound bond of two tortoises, 7-1's warp stack six columns left, 9-2's
drive gap 13 cells with a slab of 9) and re-recorded 21 co-op routes. Built by the integrator, for the owners who
did not run, and recorded as DESIGN.md **G81-G83**:
- **the coil is opened by a hero who stands on its level** (G81; `scripts/objects/vine.gd`): the hitter's feet and
  the ground he last stood on are at most one row under the coil's ledge; a batted ball is its own delivery and
  must count. `test_objects_book2` +2 (the real hero's jump from a shelf 3 rows under the ledge is never a hit
  from its level in a co-op file, always in a solo file);
- **over a shield there is no behind** (G82; `scripts/enemies/coop_traits.gd`): a `shell` is hurt only by a hero
  who stands clear of its body on the side its shield does not face - the thrower's place decides for a thrown
  weapon. `test_enemies_coop` +1, red without the rule; both explorer routes of the gully, replayed on the level
  file of before the rebuild, reach the far cell without the rule and end dead with it;
- **the `grab` trait in a ward** (G73, decided by the lead designer, built now): a Snatcher does not seize a hero
  whose feet column is in a ward and lets go of one it carries at the ward's edge. `test_enemies_coop` +1, red
  with the ward switched off;
- `bond=` on a zone-spawner record is a validator error (3-2 'pits' is clean); the slow list holds 17 tests (V7);
- **`tools/g3.sh` runs the gate job as the three proofs** (V3.c "As wired"), has a row for the co-op bosses
  (V3.d), plays `g3_versus.flow` headless and the five play flows windowed; the versus builder's fairness tool
  and the flow's generator are versioned (`tools/bots/fair.sh`, `tools/autoplay/gen_versus_flow.py`);
- every wf11 request file has its reply (`build/engine_requests/wf11_*`); the lead designer's open questions of the
  Levels phase are ruled in G83 (the wards as built, the partial bridge of 9-2, the gully as a bond, the Roller
  left out, the tick base 17 952, the 33-route evidence set).
The 57 co-op route runs replay unchanged with the three rules (`test_coop_routes` 10 / 10), and
`tools/sp_identity.sh` is IDENTICAL.

**Gate G3: REACHED** on the tree of 2026-10-09 (`G3_TAG=g3c_final1 bash tools/g3.sh --require`, exit 0; table
`build/g3/run_g3c_final1/g3_table.txt`; its `validate` and `smoke` rows were added to the same run dir by a second
call with `--only=validate,smoke`, after those two jobs had been written into the script, and `spec_docs` and
`inventory` ran there once more after this record was written; the first call's table is kept as
`g3_table.first.txt`). Content complete: 20
Book II files, 35 co-op files, 31 / 31 solo and 57 / 57 co-op route cells, 6 featured routes, 20 paintings, 76 x2
gate rows, 8 arenas, 21 of 22 versus cells with CPUs (Tar Pulleys' Last Caveman Standing human-only). Proofs:
- **coop_gates: 76 / 76 gate rows GREEN by the three proofs**, every row searched and explored afresh on the final
  tree (three scripts of the simulation had changed, so no kept result was valid): (a) 76 searches, 53 refused
  (exhaustive) and 23 refused (bounded with every probe), none open, none unproven - 4.9 hours of search on 6
  workers, the dearest row 1 550 s (9-2 'brace', a windy file: every move in each of the wind's 4 phases); (b) 0
  of 33 evidence routes reach their far cell, each replayed in a fresh process; (c) 152 explorer passes of 300 s,
  none reached - 201.3 million ticks, 0.88 to 1.93 million a pass (median 1.30), 332 994 replays with 0 off their
  state. The job ran alone: 3 050 s (`coop_gates_verdicts.txt`, `coop_gates_r7_rows.txt` in the run dir);
- **co-op bosses: 8 / 8 forms refuse one hero with an idle partner** (V3.d: four in the default suite, four among
  the slow tests);
- the default suite 1 740 / 1 740 in 234 s on its own clock beside the gate's other jobs, no test over 10 s on no
  slow list; the slow tests 17 / 17; `test_campaign_routes` 18 / 18, `test_book2_routes` 8 / 8,
  `test_coop_routes` 10 / 10 (57 route runs and the four campaign runs); `test_core_bots` 57 / 57,
  `test_integration_totem_ring` 1 / 1, `test_levels_w4` 3 / 3;
- the bot sets 48 / 48 over 21 cells in 8 shards (every Last Caveman Standing round inside the cap of G78);
- `tools/sp_identity.sh` IDENTICAL; `docs/spec/test_spec_docs.py` 101 / 101 with no ruling pending its owner;
  `tools/validate_levels.gd -- --strict` 120 files, 0 errors, 0 warnings; the headless boot check 0 errors, 0
  warnings, 120 levels listed;
- the flows, each with a clean exit: headless `campaign` 116 checks, `campaign_beginner` 14, `campaign_b2` 157
  (Book II solo on both difficulties, both Feast Lands), `campaign_coop` 367 (co-op Books I and II, both
  difficulties), `g3_versus` 108 (the 17 cells CPUs play), `harness_exit` 6; and the five play flows again
  **windowed** (off-screen, muted) with the same check counts - 993 s, 89 s, 1 830 s, 3 840 s and 1 113 s, 862
  screenshots under `build/screenshots/g3w_*_g3c_final1`.
Beside the table: `tools/build_windows.ps1` - a clean import, the suite on the then idle machine (1 740 / 1 740 in 161 s; V7's
5 minutes), the release exe exported and booted (0 errors, 0 warnings, 78 levels, no developer level, development switches ignored); the build is in `pre2_preview\2.0-g3`.
**Still open after G3** (none of them a row of the gate; each for phase 4): Sky Picnic's Grub Stack spawn bias
(+17.7 points over 384 rounds, G80: the arena file's); the validator has no rule for the clean foot of an x2
secret's ledge beside a coil, nor for a plate out of the batted hero's reach, and names a gate's own ledge when a
ward's edge comes close (G83); the evidence routes of the rebuilt gates (7-1 'stack', 9-2 'drive', the two
see-saws) aim at the old geometry, so those rows stand on the search and the explorer; the bosses' twin rules and
the giant roast credit a batted ball to its batter (not unified with G72); the wards of 2-2b and 6-2b reach into
their boss arenas; a ward covers its columns on every floor of a tall file (the pair has no head bounce there:
accepted without a playtest); the gate job takes 51 minutes on 12 cores, not the 40 asked for; the designers'
route recorders of the round are unversioned under `build/levels/`; no "TIME!" banner at the cap of G78; R6 with
an idle partner below a climber is proven on a real Level, not replayed through the game's screens; the human
pair playtests of P4.5 (9-2's charged drive across the partial bridge among them).

---

## 7. Phase 4 - QA and release 2.0

| Step | Owner | Work |
|---|---|---|
| P4.1 | integration | full headless runs: Book I solo (both difficulties, unchanged), Book II solo, co-op Book I and II, both difficulties; versus soak (bots, 1 000 seeded rounds per mode, headless) |
| P4.2 | core-A / player-A | performance: `--perf` with a two-hero route per world, 4-player arenas; on the Cortex-A53 device: 2-player co-op must meet the 1.0 budget class; 4 heroes on mobile only where the check passes (else capped at 2 there) |
| P4.3 | ui-B / core-A | devices: shared keyboards (ghosting key test), pads on Windows / Android (reconnect dialog); touch targets >= 56 art px (the tablet table mode is cut 2, applied: a hidden prototype, not tested) |
| P4.4 | audio / art-A | one human listen-through of every music pick; loop seams; licence audit of every new file (manifest, CREDITS, THIRD_PARTY); style review against `_style_tests/biome_all.png` |
| P4.5 | lead designer | mixed-skill pair playtests of every co-op stage, including the gate types G1 could not playtest (window and daze values, Batter Up, the lee); an expert told to cheat; final *(tune)* values written into DESIGN.md and the specs |
| P4.6 | core-A | version 2.0.0, Save v2 migration test on real 1.0 saves, exports (Windows, Android, macOS, iOS presets), `test_core_release` filters, smoke run of the exported build, README / BUILD notes |

**The phase-4 record of the lead designer (2026-10-09; P4.5, the rulings and the specs)**. The orchestrator's
phase-4 rulings Q1-Q7 are DESIGN.md **G84-G90**, sent to every owner with the as-decided details as
`build/engine_requests/wf12_lead_design_to_all.txt`: the coil rule and the shield rule of the G3c integrator are
confirmed (G84); the ward stays and **the enemy shows it** - a ward mark on every enemy whose feet column is in a
ward, for a co-op party only, drawing only, and a teaching sign at the first ward of co-op 1-1 and 5-1 (G85); **no
dead end beside an idle partner** - `PartyTuning.IDLE_WIPE_TICKS` 73 (G86); **the ward's grace is short** -
`PartyTuning.WARD_GRACE_TICKS` 12 (G87); version 2.0.0 with Windows as the release target (G88); nothing public
from an agent (G89); what only people can check is not faked (G90). The lead designer's own: **G91**, DESIGN.md
D.12 - the register of every *(tune)* value as 2.0.0 ships it, each constant pinned against the tree by
`docs/spec/test_spec_docs.py` - **G92**, below, and **G93**: the three rules the versus builder's soak of P4.1
(4 020 seeded rounds, 5 562 673 ticks, no engine error) asked of the referee - a stomp comes from above, nobody
stays outside the arena's sides, a wedged coconut is lost - accepted as built, with Sky Picnic's Grub Stack inside
the fairness band since its big spot moved into the two lips of the hole (best spawn 31.0 % of 384 rounds, G80)
and a "TIME!" banner on a round the hard cap ends (G78).
- **The main body says what the game does.** DESIGN.md D.2-D.11 carried the first design where the appendix had
  long ruled otherwise; D.4, D.5, D.6, D.7, D.8, D.9, D.10 and D.11 now state the ward (with the nine `ward=` keys
  as built), the slot-bound windows, the launch hold, the closed door, the coil and the shield, the stages as built
  (5-1's gully a bond, 9-2's charged drive over 13 cells, 8-1 and 8-2 as their files are), and F.5 the release.
  GAMEPLAY.md 13.9 / 13.11 and PHYSICS.md C.0 / C.10 / C.12 / C.16 lost "starting value", "phase-3 content" and the
  `solo_min - 4` cap as a proof; LEVEL_DESIGN.md 15.7.4-15.7.9 and 15.10 carry the building rules of G85-G87 and G92.
- **P4.5 is not done, and nothing pretends it is.** No pair of people played. The step is
  `docs/expansion/HUMAN_CHECKS.md`: 262 checks, one line each, unticked, each with what to look for and the file and
  value to change if it fails - the tribe's rules (17), the 35 co-op stages with a play-through line each and a line
  for each of the 45 gates (122), the expert told to cheat (13), versus (14), keyboards with the key sets of the WASD
  + numpad layout (11), pads and the reconnect dialog (7), the music with all 51 tracks (58), the look-over (6),
  devices - an Android phone with the release owner's `--perf` steps, printed as untested - (10), the Windows build
  with a real 1.0 save (4). The spec test fails when a
  gate, an arena cell or a music file of the tree has no line, when a quoted constant is not the tree's, when a
  named file is missing or when a box is ticked.
- **What a tool could measure was measured** (the tools are scratch files of the phase under
  `build/lead_design/wf12/`, named in the check list so that the numbers can be made again): **the wards** cover
  1 786 of the 3 977 columns of the 23 co-op files with tablets, 44.9 % - 4-1 and 5-2 from end to end - and 186 of
  the 396 enemy records of the co-op files stand in one (`wards.py`; it reproduces the G3c verifier's 44 %); the
  Snatcher bat of 1-2 hangs inside a ward and therefore never seizes. **The recorded pair** (`pair_probe.gd`, all 57
  two-stream route runs replayed on the release tree): 22 Beginner stages in 38:15 and 35 Expert stages in 57:55
  of playing time, 26 and 62 hurts, no hero down, no wipe; per gate 1 to 34 s from the tablet to the far cell - five gates over the
  30 s target even for the rehearsed pair (1-2 'shaft' 34 s on Beginner, 8-1 'stairs' 34 s, 7-1 'stack' 33 s, 6-2
  'seesaw' 32 s on Expert, 3-1b 'hut' 30 s on Beginner); the eight co-op boss fights 47-83 s with 0-4 hurts in the
  fight (DESIGN.md B.0). **The music**: 51 tracks, 44.7 minutes for one pass (`music.py`), with the audit owner's
  loudness and loop-seam numbers (`tools/audit_assets.py --audio`: all 51 at -18.0 LUFS as played, no seam harder
  than the music's own waveform). A debug `start_level ... players=2` flow gives only P1 a device (measured), so
  the check list sends a pair through the campaigns in order. **The two rules of the phase move no recorded
  route**: the same probe on the tree with the ward's grace built gives the same stage ticks, hurts and gate times
  in all 57 runs, and party's per-tick digests of the 57 runs are the same before and after both rules (140 060
  ticks); of the 33 evidence routes two end earlier and dead, none reaches. Of the 59 signs that stand inside a
  ward one teaches a bounce on a beast that is now marked (`signs.py`: 5-1's Roller sign) - ruled out of the co-op
  copy (G85).
- **G92 - one hero opens 8-1 'hall' with a carried feast kit** (the cheat "the 8-1 feast piece", taken as far as a
  tool reaches). A feast's touch kills before any trait is asked and only a `heavy` and a bond's last member refuse
  such a death; the kit is carried from stage to stage. On the real level with P2 idle, the run's kit preset to two
  pieces and P1 placed by teleport (`feast_probe.gd`: the rule, not a route) the piece on the terrace over the
  hall starts the feast, both keeper Shellbacks die of his touch and the keeper door rises; without the feast
  nothing dies. The three proofs start a gate without a carried kit and stay green: the bar of V3.c is not moved
  and gate G3 stands. Decided: in a co-op party a keeper and every `shell` and `daze` record dies only of a weapon
  hit its trait accepts. **Not built** (no owner of the traits in the phase;
  `build/engine_requests/wf12_lead_design_to_orchestrator.txt`); the remedy without the engine is to move 8-1's
  first feast piece behind the hall's door. Until one of the two is in the tree the spec test lists it as "not
  built".
- **Open at the lead designer's close**: G92 above; the human checks themselves; three "not built" lines of the
  spec test, each waiting for a file that is not the lead designer's - G92, the two ward signs in `w1_l1_coop` and
  `w5_l1_coop`, and the Roller sign still in `w5_l1_coop` (`build/engine_requests/wf12_lead_design_to_levels.txt`);
  the desktop `--perf` runs with two and four heroes were not made in the phase (ten Godot processes side by
  side: the numbers would be noise), and the device steps of section D are the release owner's, untested (no
  Android toolchain in the project, G88); a 1.0 profile that had rebound V, `;` or pad LB shares that input with
  the new Swap until core fixes `Settings.load_settings` (the release owner's red test); the mark is by the enemy's column and the rule by the hero's, so within a body's width of a
  ward's edge the two can differ (accepted, G85); a pair with one hero in an egg whose partner rests 13 s loses a
  life (the cost of G86, a line of the check list); a weighted second pad makes one person a pair (G58 says a held
  key is input: a question for the owner, line X-05).

**The phase as built by the other owners (2026-10-09; their reports, each re-proven in the release record below)**.
Party built Q2, Q3 and Q4 (`scripts/fx/ward_mark.gd`: one shared material on the enemy's own sprite, drawing only;
`PartyDriver._wipe_check`; `Player._ward_heads_check`) - no co-op route replays differently, two evidence routes end
earlier and dead. The levels owner placed the two ward signs (the short text: the ruled line takes four board
lines), replaced 5-1's Roller sign, played the expert's cheat list on the real game and closed the two gates that
fell - 8-1 'hall' to a carried feast kit (G92) and 9-1b 'stormwall' to a glider over the map's top (G96). World-B
built the four validator rules left in G83, made the gate job one plan and one pool (46 min 37 s alone, 51 before;
"about 40" is not reachable without weakening proof (c)), grew the evidence set to 37 routes and versioned the
recorders of every co-op route (`tools/autoplay/recorders/`: 41 of 52 re-record byte for byte, 8 record another
finishing route, 3 of D5's no longer finish). Versus rebuilt Sky Picnic's spots (G80), added the "TIME!" banner, the
soak (`tools/bots/soak.sh`) and two nets of the referee (G93). The audit made P4.4 a tool the build runs
(`tools/audit_assets.py`, 67 tests: 869 files, 869 ledger rows - 803 CC0 1.0, 2 SIL OFL 1.1, 49 licence texts, 15
own work - 45 source packs, 0 gaps; `tools/audit_assets.py --audio`: all 51 tracks at -18.0 LUFS as played). The
release owner set 2.0.0, proved five real 1.0.0 profiles (`tests/data/saves_1_0/`: nothing lost, an untouched copy
`save.v1.json` before the first write), kept five development files out of every export and prepared the installer
and the release text. The performance engineer measured two and four heroes on the quiet machine (ARCHITECTURE
11.5, `bash tools/perf.sh`: a tick of one hero 180-260 us on average, of two heroes 236-443, of four with three
Hunters 353-532 plus 376-517 of the CPUs' thinking), made the bots' route search faster without a decision changing,
and capped a versus match on a phone at two heroes (G94). The lead designer recorded Q1-Q7 as G84-G90, the register
D.12 (G91), G92 and G93, and wrote `HUMAN_CHECKS.md`.

**The release record (2026-10-10, the release integrator; after every other agent of the phase had closed)**.
What the release round changed, and why:
- **A 1.0 key binding is never shared with a new 2.0 action** (`Settings._drop_shared_defaults`): a real 1.0
  profile that had put Jump on V and Look on pad LB loaded with those inputs on Swap as well; now the player's
  binding wins and Swap keeps what is left of its defaults. The release owner's red test is green
  (`tests/test_core_save_1_0.gd` 17 / 17).
- **Three nets of the versus referee** (G95), after which both soak commands pass: two heroes clash heads once
  per airtime (the stomp ladder that climbed out of the arena), a coconut nobody strikes for 15 s drops in again
  (the game without an end on a goal's roof), and a Golden Drumstick nobody takes within the hard cap ends its
  round drawn with "TIME!" (the tie-break the CPUs never decided under Mayhem). The first is no rare thing - a
  second clash in 176 of 1 008 Grub Stack rounds of the soak - and re-rolled 14 of the 21 bot sets; every 48-round
  pin holds and the 384-round claims were made again (Sky Picnic's Grub Stack +8.1 and +4.4, Totem Ring's +3.9).
- **Echo Hollow's fairness was measured for the first time and is not inside the band** (G97, open): Grub Stack
  gives the right floor spawn 40.1 % and 46.1 % of 384 rounds, Last Caveman Standing gives the left shelf 39.1 %
  and 40.1 %; it was so before the release round (41.1 / 46.6 % with the head clash off), and seven variants of
  the file - spawn numberings, the big spot moved - did not bring both modes inside. Not fixed.
- **The versus lobby names the device's seat cap** (G94): "This device seats 2 players." instead of two cards
  that did nothing.
- **The glider flight over 9-1b's wall is evidence route 38** (G96): a real-game route file may name its
  checkpoint (`checkpoint=`) and a carried feast kit (`kit=`); replayed, the flight ends on the roof today and in
  the far cell on the file before the roof.
- **A tool run no longer writes into the player's own folder** (`.tools/gd.sh`; found while the preview folder
  was prepared, after the table): every run of the project rotated the engine's log into `%APPDATA%\ClubAndGrub`,
  the boot check (`gd.sh smoke`, a row of `tools/g3.sh` - in this run too, at 00:58) loaded and saved the real
  `settings.cfg` there, and two tests left a temporary file. `test`, `smoke`, `play` and `script` runs now get
  `APPDATA` pointed at their own folder; proven on the suite (1 798 / 1 798), `test core_bots` (61 / 61), a windowed
  flow, the validator and the boot check, with the real folder's files compared before and after (unchanged). The
  saves there (`save.json`, last written 2026-10-09 03:19) were written by no tool run of the round.
- **The shared runner no longer queues a pool behind an import that is done** (`.tools/gd.sh`: the gate first,
  the question again, then the wait), and Python byte code and `.bak` fixtures ask for no import; the G3 test pins
  the gate job's real shape; the documents say what the tree does (the withdrawn stomp rule is out of E.2, C.14
  and G 13.10.2; the validator's rules, the signs and the two closed gates are in LEVEL_DESIGN 15.7; HUMAN_CHECKS
  has 264 lines, with X-02, X-03, V-08, V-10 and W-02 rewritten, V-15 and V-16 new and the measured numbers of
  section D); every `wf12` request has its reply (17 answered in the round;
  `docs/spec/test_spec_docs.py` 120 / 120, no ruling pending an owner).

**P4.1 on the final tree** - one call, `G3_TAG=p4_final1 bash tools/g3.sh --require` (2026-10-10 00:07 - 01:58,
6 637 s; table `build/g3/run_p4_final1/g3_table.txt`; the wrapper shell of the call was stopped 20 s after its
start to free it from the tool's one-hour limit - the script, its pool and every process of it ran on untouched),
with the soak (made on the same scripts at 23:38 - 23:50, before the call), the audit and the build:
- **Gate G3: REACHED**, every proof green, the content complete (20 Book II files, 35 co-op files, 31 / 31 solo and
  57 / 57 co-op route cells, 6 featured routes, 20 paintings, 76 x2 gate rows, 8 arenas, 21 of 22 versus cells).
- **coop_gates: 76 / 76 gate rows GREEN by the three proofs**, every row made afresh (two scripts of core changed):
  (a) 53 refused (exhaustive), 23 refused (bounded with every probe), none open; (b) 0 of **38** evidence routes
  reach their far cell, each replayed in a fresh process; (c) 152 explorer passes of 300 s, none reached - 198.5
  million ticks, 0.88 to 1.94 million a pass (median 1.28: the strength of G3c). The job ran alone: 2 786 s.
- **Book I solo, both difficulties**: `test_campaign_routes` 18 / 18 (the 72 route files of 1.0, frozen);
  **Book II solo**: `test_book2_routes` 8 / 8; **co-op Books I and II, both difficulties**: `test_coop_routes`
  10 / 10 (57 route runs and the four campaign runs, 601 s). `tools/sp_identity.sh`: **IDENTICAL**.
- **Every campaign flow**, each with a clean exit: headless `campaign` 116 checks, `campaign_beginner` 14,
  `campaign_b2` 157, `campaign_coop` 367, `g3_versus` 108, `harness_exit` 6; and the five play flows again
  **windowed** (off-screen, muted) with the same check counts - 992 s, 90 s, 1 830 s, 3 841 s and 1 067 s.
- The default suite **1 798 / 1 798** in 255 s on its own clock beside the table's other jobs (172 s alone: inside
  V7's five minutes), no failure; the slow tests 17 / 17; `test_core_bots` 61 / 61, `test_integration_totem_ring`
  1 / 1, `test_levels_w4` 3 / 3; the bot sets 56 / 56 in 8 shards; co-op bosses 8 / 8 refuse one hero;
  `docs/spec/test_spec_docs.py` 120 / 120; `tools/validate_levels.gd -- --strict` 120 files, 0 errors, 0 warnings;
  the headless boot check 0 errors, 0 warnings.
- **The versus soak** (not a job of the table): `bash tools/bots/soak.sh p4 1000 16` - 4 020 rounds, 5 530 005
  ticks, no anomaly, no engine error, **RESULT PASS**; `bash tools/bots/soak.sh mix 250 16 rules=mix` - 1 014
  rounds, 1 555 998 ticks, **RESULT PASS** (at the versus builder's close the first failed by design with five
  anomaly lines and the second with three).
- **The asset audit**: `python tools/audit_assets.py` - ASSET AUDIT: PASS (0 gaps), 869 files; its 67 tests green.

**The 2.0.0 build** (`tools\build_windows.ps1`, then `tools\build_installer.ps1 -SkipBuild -TestInstall`; 2026-10-10
01:58 - 02:03, on the tree of commit ab50b07, the tree of the table above):
the import clean; the asset audit PASS; the suite inside the script 1 798 / 1 798 in 172 s; the release exe `Club & Grub 2.0.0.0`
exported and booted off-screen and muted (0 errors, 0 warnings, 78 levels, no developer level, development switches
ignored); 2 591 files inside the exe, 1 368 of them project files, no development file; the zip holds the exe and the
50 licence files, byte for byte (`tools/audit_assets.py --shipped`).
The installer was compiled and its throwaway twin (its own AppId) installed for the current user, smoke-checked
(`Club & Grub 2.0.0 (release build)`, 0 errors, 0 warnings) and uninstalled with nothing left; the game itself is
not installed on this machine, and the script's 12 recorded facts about a real installation (registry, files, Start
menu, desktop, the save and settings files in `%APPDATA%\ClubAndGrub` with their hashes) were the same before and
after. SHA-256:
- `build\windows\ClubAndGrub.exe` (192 123 344 bytes) `8f24637253bd120c69cb5b88995578612fd7c12f9b13df5e7d118b7743a6889a`
- `build\ClubAndGrub-2.0.0-windows.zip` (116 585 816 bytes) `5a500667dcf0b72390f7cab0ed8c7d030e46eb588bcdd78d99ab540a2abed28c`
- `build\ClubAndGrub-2.0.0-setup.exe` (104 627 713 bytes) `238ad100a7632cf843ed06d7ffee274c70c7b3912093defc4a28913bf9f68926`
The player's preview folder `Desktop\pre2_preview` holds that build at its top level (the exe, `licenses\`, the
setup, the zip, a `Play.cmd` that keeps its saves in `appdata\` beside it, `READ ME.txt`); the 1.0.0 files that lay
there were moved into `1.0.0\`; `2.0-slice\` and `2.0-g3\` are as they were. **Nothing was committed, tagged,
pushed or published by an agent** (G89): the release text is the end of `docs/RELEASE_NOTES_2.0.md`.

**Open at the release** (none of them a row of the gate):
- **No human check was done** (G90): `HUMAN_CHECKS.md`, 264 unticked lines - the pair playtests of P4.5, the music
  listen-through, real keyboards, pads, an Android device, the install over a real 1.0.0.
- **Echo Hollow's spawn fairness** (G97): Grub Stack outside the +/-15 band over 384 rounds, Last Caveman Standing on
  its edge; the 384-round claims of the other 11 cells CPUs play were not made.
- **Not built**: the engine's rule of G92 (a keeper refuses a feast's touch; 8-1 is closed by its level file); a
  ceiling at the map's top and a validator rule for a glider behind a gate (G96; 9-1b is roofed); the causes under
  the referee's five nets (the 1.0 body test between two heroes, the coconut's flight over a block's corner, the
  Cave-in block that pushes a hero through the map's edge, bots that go for the Golden Drumstick first); a versus
  lobby that draws only the seats a device has; per-row keys of the gate job (one saved simulation script still
  makes all 76 rows new: 47 minutes).
- **Left as they are, with the reason in their ruling**: 1-1 Beginner has no enemy record in its first ward before
  the gate; 5-1 'gully' has one keeper three columns outside its ward, unmarked (G96); the mark follows the enemy's
  column and the rule the hero's (G85); a ward covers its columns on every floor of a tall file; the weak cases of
  the mark on pale sheets and one-band bodies (line L-06); nothing on the screen counts the 73 ticks of G86.
- **Not measured**: any device (every Cortex-A53 figure is the desktop's times 10-15; the mobile cap of G94 is that
  estimate); the 1.0 budget class on the proxy is not met (the tick is 1.2-1.7 times the 150 us proxy with one hero,
  1.6-3.0 with two); the ticking-entity budget of 48 is exceeded in `w2_l1_coop` (49) and on Cinder Pit (60).
  Android, macOS and iOS: the presets load and pack, nothing was exported or run (no toolchain in the project, G88).
- **The real user folder**: `tools\build_windows.ps1`'s own import, test and export runs still write the engine's
  log file into `%APPDATA%\ClubAndGrub\logs` (only the exported exe's smoke run is isolated there); the
  `settings.cfg` in that folder holds the defaults, and whether it held more before the boot checks of the phase
  loaded and saved it cannot be told from the tree.
- **Tools and records**: three of D5's macro recorders no longer finish; `docs/art/pipeline/build_manifest.py` no
  longer reproduces sections 1-16 of the manifest; two licence texts carry the title of their first page only; the
  registry labels the project's 15 own files "CC0 1.0" where the ledger says "own work" (the owner's decision);
  the upgrade over a real 1.0.0 installation and the all-users install were not exercised (no agent installs under
  the real AppId).
- Of the list "Still open after G3" in section 6: Sky Picnic's bias, the validator's three rules, the evidence
  routes of the rebuilt gates, the unversioned recorders and the "TIME!" banner are closed; the bosses' twin rules
  and the giant roast, the wards of 2-2b and 6-2b in their boss arenas, a ward on every floor of a tall file, the
  gate job's 47 minutes and R6 replayed through the game's screens stand as they were.

---

## 8. Verification rules

**V1 - Single-player tick identity (every change set touching code).**
a. `sim_bench.gd --snapshot=res://build/mp_baseline --digest --tight` with and without `--no-doze` into
   `build/mp_digest_after*`; `diff -r` against `build/mp_digest_before*` must be **empty** for all 72 routes.
b. `bash .tools/gd.sh test` green (575 shipped tests replay every Book I route tick-exact through Flow, golden traces,
   fidelity tables, the doze proof).
c. `tests/test_core_players.gd`: `heroes == [player]`, `GameInput.get_flags(0) == GameInput.flags` every tick,
   `Game.hearts` aliases `runs[0]`, three representative routes match committed per-tick digest fixtures.
d. `tests/test_core_book1_frozen.gd`: sha256 of the 15 Book I level files and 72 route files equal the fixtures.
e. The digest line is frozen for a party of one; multiplayer fields are appended only when `hero_count() > 1`.

**V2 - Book II solo proofs.**
a. One club route per (stage, difficulty): `<id>.inputs` (Beginner) and `<id>.expert.inputs` (an Expert-only stage
   has just `<id>.inputs`, as in Book I), each with a `# route:` header, replayed through Flow by `tests/test_book2_routes.gd`; any engine warning fails it.
b. Belt invariance: every route replayed with hammer, axe, swirling axe and spear on the belt gives identical per-tick
   digests (the belt slot excluded from the hash).
c. End-to-end: Book II played headless per difficulty with what the run carries; every painting 0-19 is collected by
   some route.

**V3 - Co-op proofs.**
a. One two-stream route per (co-op stage, difficulty): `<id>_coop.inputs` / `<id>_coop.expert.inputs`
   (`# players: 2`), replayed by `tests/test_coop_routes.gd`; ends at the team exit (or the boss trophy).
b. Determinism: each co-op route replayed twice -> identical digests; with and without dozing -> identical; with a
   different device assignment -> identical.
c. Requiredness: `tests/test_coop_gates.gd` runs the solo-impossibility search on every `objects/x2_tablet gate=`:
   a single reference hero with every weapon, every belt special and Chomper where present must **fail** to reach the
   gate's far marker; window and daze values must be below the measured solo minimum minus 4 ticks. The partner a lone
   player has is modelled: an egg drifting after him, or his idle hatched partner placed anywhere he could be hatched,
   who counts for no co-op rule (DESIGN.md D.3 [G33]); a bond one thrown special hits twice in one throw is a build
   error (G36). **A refusal names its evidence** (orchestrator after G3, DESIGN.md G59): per gate and difficulty the
   table says **refused (exhaustive)** - the frontier emptied below the bound, or the static reach rule - or **refused
   (bounded)** - the raised bound of at least 660 resting points, uncached, AND every continuous-play probe of the
   gate's kind failed (hop-over, charge-under, idle-bait, thrown-special and plates; LEVEL_DESIGN 15.7.6) - or
   **open** (reached by a search, probe or replay; red). A search that stopped at its bound without its probes is
   **unproven**, never "refused". In the gate table (`tools/g3.sh`, integration, the follow-up round) the test prints
   the search's own line per gate - `GATE <level> <difficulty> <gate>: <verdict> (<evidence>)` - and the coop_gates
   row counts the gates once by name: "n/N gates refused: e exhaustive, b bounded + probes", green only when e + b =
   N; unproven gates leave the row **open** (named; neither green nor red, but G3 is not reached), an open gate, a
   crashed shard or a shifted gate table is red; every verdict is kept in `<run dir>/coop_gates_verdicts.txt`.
   **The fixed bar** (the orchestrator's R7 after G3b; DESIGN.md G77): a gate row is proven by **three things** and
   judged by nothing wider -
   (1) **the solo search refuses it**, as above: exhaustive, or bounded with every probe - on an exact reset (tick
       base 0, the total-tick clock put back per run; a run that missed replays is bounded and says so), with the
       long climb (a hero at rest on a vine is a node) and, in a file with a `wind` script, the wind's phases (G79);
       as built the base is the same in every run and process but not 0: 17 952, a common multiple of the levels'
       cycle lengths, so that no geyser is "before its delay" at a move's start (DESIGN.md G77 "As built at G3c");
   (2) **every route of the evidence set says "not reached"** - the replayable routes by which a gate once fell
       (the G3b verifier's 21, the two gust routes of G79 and the 'hop' route of G73: 24), versioned under `tools/`, each replayed in a fresh
       process; the set only grows (33 at the close of the round: nine finds of its own explorer joined,
       `tools/coop_explore/evidence/`);
   (3) **the continuous-play explorer** - versioned under `tools/`, with the lure, ride, strike-on-spring,
       long-climb and second-throw moves and an exact world reset - **opens it in none of two seeded passes of
       300 s** per gate row over the whole level.
   A replayable route is red whatever the search prints; a find that does not replay from a fresh process is a
   seed, not a verdict. The coop_gates row of the gate table shows the three per row, is green only when all three
   hold for all 76 rows, and names the open rows otherwise. No wider bound, further probe or human attempt is part
   of the bar: a route found outside it joins the evidence set for the next round. The causes the G3b routes used
   are closed by rule (G71-G76) or by a building rule (G74, G79), and the window checks named above ("below the
   measured solo minimum minus 4 ticks", the one-throw build error of G36) are no longer proof obligations: a bond
   is slot-bound (G72). Two causes the round's own explorer found inside the bar are closed by rule as well: a
   coil is opened only by a hero who stands on its level (G81), and a `shell` is hurt only by a hero behind it
   (G82).
   **As wired** (the G3c integration): the `coop_gates` job of `tools/g3.sh` is `tools/world_coop_gates.sh` - the
   search workers and the explorer's two passes of every row side by side, then the evidence set, then the test,
   which reads all three back - and it runs **first and alone**: a pass is 300 s of wall time, so every process
   that shares the cores takes ticks from it (each row prints the ticks its passes played). The row of the table
   reads "n / 76 gate rows GREEN by the three proofs (R7): (a) e exhaustive, b bounded + probes; (b) the evidence
   step's line; (c) the explorer step's line"; a RED row is printed with its three proofs and its route file, an
   unproven row (a proof that did not run) is open work. Kept results are keyed by the level file and the
   simulation's code: any change of a script, scene or resource of the simulation makes every row stale (51
   minutes for the whole job on this 12-core desktop; a rerun on an unchanged tree reads everything back in a few
   minutes).
d. Bosses: each `test_enemies_<boss>.gd` asserts the co-op form is not beatable by the single-hero search - one hero
   plus an idle hatched partner placed anywhere he could be hatched (G33) - runs the fairness checks per hero, and pins
   every weak point at least 72 px under the locked view's top (DESIGN.md B.0 [G35]). The gate table has a row for
   it since G3c ("co-op bosses (V3.d)": the eight forms by test name - Brute, Tusker, Inkjaw and Mangrove in the
   default suite, the Rival Chieftains, the Colossus, the Twin Idols and the Storm Roc among the slow tests).
e. `test_core_doze.gd` extended: a two-hero route with and without dozing; no dozing entity within reach of any hero
   or inside any view.

**V4 - Versus proofs.**
a. `tests/test_versus_rules.gd`: scripted multi-stream matches for every rule (clang, deflect, stomp ladder, each spill
   formula, cookpot banking and lids, Feast Rush, Hot Rock pass and 44-tick immunity, Clubball goals and escalation,
   every sudden death telegraphed >= 10 ticks, respawn shield).
b. `tests/test_versus_bots.gd` (slow module): four Hunter bots finish a round on every (arena, supported mode) with no
   bot idle more than 10 s; no hit lands within 48 ticks of a spawn; win rates per spawn point within +/-15 % over
   the seeded set; a match log replays to identical digests. The module's 48-round sets (12 seeds x 4 rounds) are
   the deterministic regression pin; a fairness claim for an (arena, mode) - after an arena or a bot change, and
   for the release - is made on at least 384 rounds (DESIGN.md G80: at 48 rounds a fair spawn's share has a
   standard deviation of 6 points; Sky Picnic's Grub Stack measured +17.7 there and is P4's to bring inside) with
   `bash tools/bots/fair.sh <tag> <arena> <mode> 0 96` (the versus builder's tool, versioned at G3c).
c. Rounds end (the orchestrator's R8; DESIGN.md G78): `tests/test_versus_rules.gd` proves that a Last Caveman
   Standing round between heroes who never meet ends at the hard cap - `VersusTuning.SUDDEN_DEATH_CAP_TICKS`, 1 457
   ticks after its sudden death starts - with the side that took the fewest hurts as the winner, else a draw; no
   bot round of (b) outlasts it.

**V5 - Performance**: two-hero `--perf` runs per world and four-hero arena runs stay inside the budgets agreed at
G1 (ARCHITECTURE 11); the A53 device check gates 4-player versus on mobile.

**V6 - Assets**: every new file has its manifest row, CREDITS and THIRD_PARTY entry and a CC0 source; no sheet wider
or taller than 2048 px; `test_core_release` export filters green.

**V7 - Suite budget**: the default `bash .tools/gd.sh test` stays under about 5 minutes; `campaign_routes`, `book2`,
`coop` and `versus` slow modules run at every gate and before every merge that touches their area. A slow module is
listed in `SLOW_FILES` of `tests/run_tests.gd`: a run without a filter skips it with a skip line; it runs by name
(`bash .tools/gd.sh test coop_gates`) or with `GD_TIMEOUT=4000 bash .tools/gd.sh test --slow`. Slow modules today:
`test_coop_gates` (G1: 66-81 s for the slice's ten gates; since world-B's search v2 about 1.5 minutes per gate and
difficulty - 18 at G2 - so `COOP_GATES_SHARD=<i>/<n>` splits it over n processes), `test_versus_bots` (V4.b, about
12 minutes at G2) and, since the G2 integration, the route replays `test_campaign_routes`, `test_book2_routes` and
`test_coop_routes` (V7's `campaign_routes`, `book2` and `coop`; together about 3.5 minutes at G2 and growing with every
phase-3 route). The default run keeps the Book I guards (V1.c, V1.d); `tools/sp_identity.sh` replays every Book I route.
Since the G3 follow-up round (integration; the default run had grown to about 410 s): `test_core_bots` (every test of
it bakes a nav graph or needs one baked; `test_core_bots_modes` stays in the default run), `test_integration_totem_ring`
and `test_levels_w4` are slow modules too, and **single slow tests** of files that stay in the default run are listed
in `SLOW_TESTS` of `tests/run_tests.gd` (the real solo searches of `test_world_validator`, the single-hero searches
of the co-op bosses, every campaign code through a level start, a stage played in real time): skipped with a skip
line each under the rule of the slow modules, run by `--slow`, by a filter naming their file's module, or alone by
`GD_TIMEOUT=1200 bash .tools/gd.sh test --slow-tests` (a job of `tools/g3.sh` at every gate); a listed name its file
no longer has fails the run. A test goes on that list only if it shares no costly fixture with the quick tests of its
file - otherwise the whole file is a slow module. `tools/g3.sh` also runs the lead designer's
`docs/spec/test_spec_docs.py` (job `spec_docs`: a failure is red; every test skipped as "pending owner change: ..."
is listed as "not built: ..." - open work, so those texts stay one line) and `tools/autoplay/harness_exit.flow` (a
harness run must leave the engine without leak reports). Since the G3c integration `SLOW_TESTS` also holds
`test_hero_bot_bodies_move_on_hero_physics` (16.5 s alone, versus' measurement) and
`test_search_hop_jump_reaches_six_rows_not_seven` (12-15 s, two real searches): 17 slow tests; and `tools/g3.sh`
plays `tools/autoplay/g3_versus.flow` beside the campaign flows, and the five play flows a second time
**windowed** (`gd.sh play`: a real window, off-screen and muted - jobs `wflow_<flow>`).

---

## 9. Cut list (in this order, if the schedule slips)

| # | Cut | Replacement | Saves |
|---|---|---|---|
| 1 | Second-wave versus modes (King of the Feast, Letter Snatch, Egg Heist) | already outside launch | - |
| 2 | Tablet table mode (two touch players) - **APPLIED at the start of phase 3** (orchestrator): an experimental, hidden prototype | one touch player + pads | ~1 ew |
| 3 | Unlockable arenas Mesa Rodeo and Cloud Top - built only once the four remaining launch arenas are done and their bot tests green (orchestrator, phase 3) - **APPLIED after G3** (orchestrator, DESIGN.md G60): not in 2.0 | 8 arenas; those painting unlocks become variants and colours (the ladder of DESIGN.md C.9: 5 and 10 loincloth patterns, 20 Spear Party, 25 gold) | ~1 ew |
| 4 | Bots on an arena whose graph fails | that arena ships human-only in that mode: arena meta `bots` leaves the mode out (DESIGN.md G50; the bot test skips it, no CPU seat there); until the switch is built the arena stays out of `levels/` | per arena |
| 5 | Chief bot level, deciding-moment replay | Rookie + Hunter; a still frame of the deciding hit | ~1.5 ew |
| 6 | Shaman (co-op enemy) | Shellbacks in those halls | ~0.5 ew |
| 7 | Chomper the rex | 6-1 crosses the tar flats by raft; 7-1's urchin beds become drop floes (Mesa Rodeo is cut already, cut 3) | ~3 ew + art |
| 8 | Rival Chieftains on hero physics | Brute-style state machine on `rival.png`, same phases | ~1 ew |
| 9 | Clubball | three launch modes; Coconut Cove stays as an arena for them | ~1.5 ew |
| 10 | Rafts and currents | `objects/platform mode=ride` over water in 6-1, 7-1, Feast Land E, the ending; Inkjaw's phase 3 becomes sinking islands | ~1.5 ew |
| 11 | Co-op x2 gates in Book I's Feast Lands and Way Home | team exit only; painting 29 moves to a 4-2 co-op secret | ~0.5 ew |
| 12 | (owner approval only) Feast Land E | Book II becomes 19 files | ~1 ew |

**Never cut**: the phase-0 identity proof and the digest guards; Book I byte-identity; the fresh-club belt and its
invariance test; the tribe camera, Egg Hatch and tribe lives; Shoulder Hop, Totem Ride, Batter Up and Brace Wall;
plates and keeper doors; a co-op file for all 35 stages with at least two gates per main stage; the co-op forms of all
bosses; the six new bosses (the Chieftains may fall back to cut 8); Grub Stack, Last Caveman Standing and Hot Rock;
Rookie and Hunter bots; CC0-only assets.

---

## 10. Effort by area (engineer-weeks, plus or minus 30 %)

| Area | ew |
|---|---|
| Phase 0: identity refactor 4, format / catalogue / hooks / harness 1.5, specs 1 | 6.5 |
| Belt + swap + spear + bark boards | 2.5 |
| Vines, tar, geysers, rising scroll, rafts and currents | 5 |
| Chomper (riding, mount entity, tests) | 3 |
| Co-op core (tribe camera, PartyDriver, eggs, duo moves, team rules) | 6 |
| Co-op objects | 3.5 |
| Enemies: 3 archetypes, 8 traits, 7 co-op-only enemies, skins | 8 |
| Bosses: Tusker 1.5, Mangrove 2, Inkjaw 2, Idols 1.5, Roc 2, Chieftains 2.5, co-op Brute 0.5, co-op Colossus 0.75 | 12.75 |
| Versus: referee, combat kit, 4 modes, sudden deaths, crates, stack display | 7 |
| Bots: baker, HeroBot, 3 levels, Clubball prediction, tests | 4.5 |
| UI: book select, join, HUD, options, touch, map page, versus screens, tally medals | 6 |
| Validator, solo search, route tooling | 3 |
| Flow, save, registry, audio table, unlocks, replay | 3 |
| Content: Book II solo 16, Book II co-op 8, Book I co-op 7.5, arenas + graphs 3, route recording 3 | 37.5 |
| Art: terrains, parallax, ~16 enemy sheets, 6 boss builds, hero / object / UI pieces | 10 |
| Audio: picks, loop fixes, loudness | 1.5 |
| QA, performance, devices, release | 5 |
| **Total** | **~125-135** |

---

## 11. Top risks and their mitigations

| Risk | Mitigation |
|---|---|
| Silent single-player drift during phase 0 (shake counter, static carry guard, event-driven respawn, feast music) | one owner, small steps, empty digest diff after each, permanent guards V1.c-d |
| Co-op gates one hero can cheese (head bounces, spears, vines, axes thrown across twin targets) | keeper halls 4 rows high (G4), heavies hurt only in a braced daze and one hit per strike (G57), refusals that name their evidence (G59), static validator rules, the single-hero search including belt specials and Chomper, windows below the measured solo minimum, an expert told to cheat in playtests |
| Co-op gates a weak partner cannot do | an easy role at every gate, Beginner windows, eggs instead of lives, Helper mode, pair playtests at G1 before content |
| Tribe camera on vertical and scrolling stages (5-2, 6-2b, 9-1, Book I 1-2 and 4-1) | vertical follow on grounded heroes only, leash -> egg (free), slice tests on 6-2b's rising scroll early |
| Cortex-A53 budget (+1-1.5 ms per extra hero on a tick 1.0 already misses) | hero performance pass in phase 1, 2-player co-op as the mobile target, small arenas, 4 heroes on mobile only past the device check |
| Bots on moving geometry (lifts, floes, wrap) and fun bot levels | links verified by simulation, Rookie / Hunter first, human-only fallback per arena |
| Chieftains on hero physics | built after bots, fallback state machine behind a flag |
| Content volume (55 level files, ~95 recorded routes) | one skeleton per Book II level for solo and co-op, the fresh-club rule, the recorder and duo macros, eight designers in parallel |
| Boss compositing quality (Mangrove's root arm, Roc 2x re-pack, Inkjaw's tentacles) | style proofs before code; the Idols and the Chieftains reuse shipped sheets |
| One-device input (ghosting, Android pad ids, two touch players) | key test, reconnect dialog, table mode experimental and first to cut |
| Hot-spot files (`player.gd`, `test_campaign_routes.gd`, `en.po`, `ASSET_MANIFEST.md`) | component files with hooks from P0.8, route headers instead of a central ROUTES table for new routes, locale sub-catalogues per designer, one manifest owner with a hand-over folder |

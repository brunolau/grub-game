# TECH_AUDIT.md - engine audit for local multiplayer (co-op campaign + same-device deathmatch)

Status: audit and refactor plan, no code changed. Author: tech audit (expansion workflow), 2026-10-06.
Scope: every place where Club & Grub 1.0.0 assumes exactly one hero, one input stream, one view and one set of run
state; the plan to go to N local heroes (N <= 4) while single-player stays **tick-identical**; risks; who does what.

Read with: `docs/ARCHITECTURE.md` (4.2 order of operations, 11 dozing/perf), `docs/spec/PHYSICS.md` (3, 10, 12),
`docs/spec/GAMEPLAY.md` 12. Line numbers below are those of the 1.0.0 tree as audited on 2026-10-06.

---

## 0. Summary

**Baseline.** `bash .tools/gd.sh test` on the audited tree: `TESTS: 575 passed, 0 failed, 58 file(s), 137.94 s -
RESULT: PASS` (one expected warning from `test_world_zones.gd`). This is the regression guard of section 4.12.

**Single-player touch points found (rows of section 3 that need a change; "keep" rows are listed but not counted):**

| # | System | Touch points |
|---|---|---|
| 3.1 | Sim clock, phases, RNG | 4 |
| 3.2 | Input (GameInput, bindings, touch, glyphs, rumble) | 18 |
| 3.3 | Hero registry and spawn (`LevelBase.player`, `@`) | 9 |
| 3.4 | Hero (`PlayerBase` / `Player`) couplings | 17 |
| 3.5 | Run state (`Game` autoload) | 11 |
| 3.6 | Camera, view, `on_screen` | 19 |
| 3.7 | Doze manager | 7 |
| 3.8 | Enemies (`EnemyBase` + 11 archetypes) | 19 |
| 3.9 | Bosses (`BossBase`, Brute, Colossus) | 9 |
| 3.10 | Projectiles | 4 |
| 3.11 | Items | 12 |
| 3.12 | Objects (hazards, checkpoints, exits, platforms, springs, gates, columns, signs, villagers) | 11 |
| 3.13 | Zones | 5 |
| 3.14 | Death, respawn, game over, time limit, shake | 9 |
| 3.15 | Flow, tally, save, codes, menus | 11 |
| 3.16 | HUD and UI overlays | 6 |
| 3.17 | Events bus and audio | 5 |
| 3.18 | Autoplay harness, flows, perf probe, sim bench | 13 |
| 3.19 | Tests and helpers | 6 |
| 3.20 | Level format and content pipeline | 7 |
| | **Total** | **202** |

Each touch point is counted once, in the system where its fix lives (cross-references are not counted twice).
Raw grep volume behind it: 65 lines reading `level.player` / `Game.level.player` in `scripts/` (plus 43 in
`tests/`), 18 calls of `EnemyBase._target_hero()`, 42 reads of hero-owned run state through `Game.*` (hearts, bones,
glider, weapon), 25 readers of `on_screen`, 23 view queries, 69 `set_scripted` / `clear_scripted` sites (harness
and tests).

**Approach (section 4).** Additive contract, "N = 1 is the identity":
- `LevelBase` gets a **PlayerSet** (`heroes[]` in slot order, `player` stays = slot 0), `target_hero()`,
  `contact_order()`, several views, N hero rectangles in the doze manager; every per-hero loop over a set of one
  executes exactly today's calls in today's order with today's arguments.
- Per-hero run state moves into **`PlayerRun`** objects (`Game.runs[]`); the frozen `Game.hearts / bones / weapon /
  has_glider` become property aliases of `runs[0]`. Shared team state (score, lives pool, letters, feast kit,
  checkpoint, exit, completion, tally) stays in `Game`.
- **`GameInput` slots**: `flags` stays slot 0 and is sampled exactly as today; slots 1..3 come from per-slot device
  assignments (keyboard halves, pads by device id, touch regions, bots, scripts) with generated `pN_*` actions.
- Heroes keep self-registering the four hero phases; slot order = registration order (P1 first, spawned exactly
  where the single hero is spawned today). Hero-versus-hero work (stacking, revive, PvP hits) runs in a
  `PartyDriver` registered after the heroes, so the frozen `Defs.Phase` list is not touched.
- Co-op camera: **group paging camera with view-edge walls and a catch-up bubble** (single viewport, cheapest);
  versus: locked single-screen arenas (group camera for larger ones). Split screen only as a desktop stretch.
- Routes: multi-stream input files (`8:R|L`), `GameInput.set_scripted_slot()`, a recorder; single-stream files and
  `parse_inputs()` unchanged.
- Proof: the 575-test suite plus **per-tick state digests** of every route (`sim_bench.gd --digest`) taken on a frozen
  snapshot before the refactor and diffed after every step; a digest-guard test keeps it enforced afterwards.

**Top risks (section 5).** (1) Silent single-player drift through hidden "once per tick" side effects - the hero
decrements the level's shake counter (`player.gd:937`, `:1035`), the static platform carry guard
(`platform_base.gd:17`), `Events.player_death_finished` driving the respawn, feast music push/pop. (2) Doze
correctness with several heroes and with the new fast moves (throw, bubble, leash teleports) - the 128 px reach
argument of ARCHITECTURE 11.1 is per hero and breaks for a thrown partner. (3) Performance on the Cortex-A53: the
1.0.0 tick already misses its desktop proxy budget (avg 132-272 us vs 150 us); each extra hero costs about +100 us
desktop (~+1-1.5 ms on the A53); split screen doubles the 60-draw-call budget. (4) Input on one device: Godot
InputMap actions cannot tell two pads apart without per-device actions, all keyboards are device 0, membrane
keyboards ghost, Android pad ids change on reconnect, two touch players fit only on tablets. (5) The route-proof
matrix explodes (stage x difficulty x weapon pair), and the contract freeze of ARCHITECTURE 1.2 forces an additive,
single-owner first wave.

---

## 1. Baseline and method

- Suite: `bash .tools/gd.sh test` -> 575 passed, 0 failed, 58 files, 137.94 s (run of 2026-10-06 for this audit).
- Method: systematic greps (appendix A) over `scripts/`, `tests/`, `tools/`, `scenes/`, `project.godot` for
  `level.player`, `Game.level.player`, `Kind.PLAYER`, `_target_hero`, `GameInput.*`, `set_scripted`, every `Game.<field>`
  and `Game.<method>`, `on_screen`, `get_view_rect`, `is_in_view`, `get_camera_cell`, `lock_camera`, `snap_camera`,
  `Events.player_*`, `Audio.push_music`, `tick_shake_timer`, `_carried_on_tick`, `Sim.rng`; then a read of every hit
  in context (Sim, GameInput, Game, LevelBase, Level, LevelCamera, PlayerBase, Player, EnemyBase, BossBase, both
  bosses, every archetype, every object/item/zone, Flow, HUD, pause, touch, Autoplay, flow runner, sim bench, the
  route test).
- "Keep" rows: the code is hero-agnostic or already per-hero; listed so nobody re-audits them.

---

## 2. The invariant: N = 1 is the identity

Every change of section 4 must satisfy all of these for a party of one (the single-player game):

1. **Same calls, same order, same arguments.** A loop `for hero in level.contact_order()` over `[player]` performs
   exactly the body that `level.player` did before; no extra `Overlap.*` call (its `stomp` / `depth` are static
   results, `overlap.gd:13-15`), no extra `Sim.rng` draw, no extra spawn (spawns take registration serials), no
   extra `Events` emission that something in the tick listens to.
2. **Same registration serials.** No entity is spawned before or instead of today's entities; P1 is spawned where
   the single hero is spawned today (`level.gd:526-530`, after every level entity); P2..P4 after P1, only in
   multiplayer. Mode-flagged entities that do not apply are skipped *before* `spawn()` (as `expert` / `beginner` are,
   `level.gd:493`, `:505`), so they take no serial.
3. **Same RNG stream.** Bots and cosmetic multiplayer extras never draw from `Sim.rng` (their own `SimRng`s, like
   `fx_base.gd:52`).
4. **Same frozen API meaning.** ARCHITECTURE 1.2 freezes public names and meanings: `LevelBase.player`,
   `GameInput.flags`, `Game.hearts` ... keep meaning "P1 / the hero". New members are appended; `Defs.Phase` values are
   frozen (no phase can be inserted between `CONTACT_ENEMIES` and `CONTACT_ITEMS`).
5. **Multiplayer branches are data-driven, not mode-sniffing inside hot paths where avoidable**: a set of one makes the
   loop collapse; where a rule differs (off-screen death vs bubble, team exit), branch on `level.hero_count() > 1`
   once, and keep the single-player branch byte-for-byte the old code.

---

## 3. Audit: every single-player assumption, by system

Columns: where, what is assumed, the change (section numbers point to the design in section 4).

### 3.1 Sim clock, phases, RNG (4)

| Where | Assumption | Change |
|---|---|---|
| `scripts/core/sim.gd:294` | `GameInput.sample()` samples one stream per tick | samples every slot (slot 0 first, unchanged), 4.3 |
| `scripts/core/defs.gd:15-29` | the four hero phases (`WEAPONS`, `PLAYER`, `CONTACT_ENEMIES`, `POST`) belong to one hero; values frozen | N heroes register the same phases; party steps run in a `PartyDriver` registered after the heroes, 4.4 |
| `scripts/core/sim.gd:31-32` | one `Sim.rng` | stays the only in-tick RNG; multiplayer-only draws (ember rain per hero, versus spawners) are fine, bots never draw from it, 4.9 |
| `scripts/core/sim.gd:14-16`, `level_base.gd:94-97` | end-of-tick handlers (shake, doze, on_screen) written for one hero | made N-aware inside the same handler (3.6, 3.7, 3.14); no new handler order |
| keep: `sim.gd:295-296` | snapshot of `sim_prev` for all awake entities | heroes are ordinary entities |
| keep: `player.gd:603`, `:1090`, `:1097` | `Sim.tick %` for cosmetics | per-hero cosmetics stay tick-driven |

### 3.2 Input (18)

| Where | Assumption | Change |
|---|---|---|
| `scripts/core/game_input.gd:21` | one `flags` mask | `slot_flags: PackedInt32Array` (4); `flags` == slot 0, 4.3 |
| `game_input.gd:23` | one `prev_flags` | per slot (`prev_slot_flags`) |
| `game_input.gd:25`, `:215-232` | one "last used device family" + `device_changed` | per slot device + `slot_device_changed(slot, device)`; `device` stays slot 0 |
| `game_input.gd:29`, `:57-68` | presses latched from InputMap actions that match every device (`device: -1`) | per-slot latches keyed by event type + `event.device` |
| `game_input.gd:30`, `:95-114` | one touch mask, `set_touch(action, pressed)` | `set_touch_slot(slot, action, pressed)`; `set_touch` = slot 0 |
| `game_input.gd:31-32`, `:119-136` | one scripted `Callable` | `set_scripted_slot(slot, source)`; `set_scripted` = slot 0, `clear_scripted` clears all |
| `game_input.gd:72-81` | `sample()` builds one value | builds slot 0 exactly as now, then slots 1..N-1 |
| `game_input.gd:203-212` | `_poll()` reads unprefixed actions of all devices | slot 0 unchanged; other slots read generated `p2_*..p4_*` actions bound to their device |
| `game_input.gd:184-185` | one touch overlay decision | per slot (only slots assigned to TOUCH) |
| `game_input.gd:189-196` | `vibrate()` rumbles **every** connected pad | `vibrate_slot(slot, ...)` rumbles that slot's pad only |
| `game_input.gd:50-55` | focus loss clears one latch / touch set | clears all slots |
| `project.godot:80-161` (`[input]`) | one action set; arrows **and** WASD both move, Z/K jump, Space/X/J attack (all `"device":-1`) | keep for single-player; per-slot action sets generated at runtime (keyboard halves, pad by id), 4.3 |
| `scripts/core/settings.gd:180-246`, `[bindings]` | one binding profile per action | per-slot profiles `[bindings_p2]..[bindings_p4]`, same token format |
| `scripts/player/player.gd:339` | the hero reads `GameInput.flags` | reads `GameInput.get_flags(slot)` (slot 0 = `flags`) |
| `scripts/world/level.gd:631` | auto-scroll waits for `GameInput.flags != 0` | any slot's flags |
| `scripts/ui/touch_controls.gd:205-234`, `:69` | one overlay feeding one hero | one overlay per touch slot with its own screen region, 4.3 |
| `scripts/ui/ui_prompts.gd:24`, `:43`, `:59`, `ui_glyphs.gd:6`, `options_panel.gd:320` | one glyph set | glyphs per slot (join screen, HUD prompts per player) |
| `scripts/core/scene_flow.gd:297` | `pause` from any device, owner unknown | record the pausing slot (`Flow.pause_slot`) for give-up / menu focus |
| keep: `scene_flow.gd:518`, `:533`, `:671`, `:698` | `GameInput.enabled` toggled around transitions | global flag applies to every slot |

### 3.3 Hero registry and spawn (9)

| Where | Assumption | Change |
|---|---|---|
| `scripts/base/level_base.gd:23-24` | `player: PlayerBase` - the hero | `heroes: Array[PlayerBase]` in slot order; `player` = slot 0, 4.1 |
| `level_base.gd:135-136` | registering a `Kind.PLAYER` sets `player` | `heroes[hero.slot] = hero`; slot 0 also sets `player` |
| `level_base.gd:153-154` | unregister clears `player` | clears its slot |
| `level_base.gd:26` | one `start_pos` | `start_positions[slot]`; `start_pos` = slot 0 |
| `scripts/world/level.gd:480-485` | `_place_start()` uses `starts[0]` | P1 from `@`, P2..P4 from `objects/hero_start slot=n`, fallback `@` + 24 px steps, 4.10 |
| `level.gd:526-530` | spawns one `player/player` | spawn P1 here unchanged, then P2..PN with `{"slot": n}` |
| `scripts/world/level_validator.gd:365-372` | exactly one `@` | stays; validate `hero_start` slots, arena needs 2..4 starts |
| `scripts/core/debug_level.gd:82-88`, `:111` | debug level spawns and follows one hero | spawn party, follow P1 |
| `tools/world_render_level.gd:165`, `:335-337` | renders one hero at `@` | also draw `hero_start` markers |
| keep: `world/level_data.gd:174-183`, `core/spawner.gd:103-109`, `tests/test_core_level_base.gd:20` | list of starts; hero scene cached; one PLAYER in a bare level | unchanged |

### 3.4 Hero: `PlayerBase` / `Player` couplings (17)

| Where | Assumption | Change |
|---|---|---|
| `scripts/base/player_base.gd:121-153` (`hurt` body) | energy and glider live in `Game` | `run.lose_bone()` / `run.lose_heart()` / `run.scatter_energy()` / `run.set_glider()`, 4.2 |
| `player_base.gd:203-205` | `Events.feast_changed(ticks)` without hero | also emit `Events.hero_feast_changed(hero, ticks)` |
| `player_base.gd:209-213` | `Game.set_glider` | `run.set_glider` |
| `scripts/player/player.gd:84`, `:89-90`, `:1070-1072` | sheet from `Game.weapon` / `Game.weapon_changed` (P1's signal swaps every hero) | `run.weapon` / `run.weapon_changed`; palette per slot (5.3) |
| `player.gd:126`, `:354`, `:370`, `:732`, `:920`, `:1103` | glider carried = `Game.has_glider` | `run.has_glider` |
| `player.gd:150-164` | `Game.lose_bone / scatter_energy / lose_heart / has_glider` | `run.*` |
| `player.gd:197-201` | death toss drifts toward the middle of **the** view | the view this hero is drawn in (group view; per-view in split screen) |
| `player.gd:216`, `:1065-1067` | `Audio.push_music(FEAST)` per feast, pop when the context is FEAST | feast music through a refcount ("while any hero feasts"), 3.17 |
| `player.gd:228` | `Game.set_glider` | `run.set_glider` |
| `player.gd:264-282` (`_weapon_pass`) | every `HERO_PROJECTILE` is this hero's | test only projectiles whose `owner_slot == slot` (set for P1 too: same set, same order) |
| `player.gd:319`, `:595` | `Game.weapon` | `run.weapon` |
| `player.gd:636-659` (`_throw`) | `MAX_THROWN` counts all hero projectiles; spawn has no owner | count own projectiles; spawn param `owner=slot` |
| `player.gd:817-832` (`_left_the_playfield`) | off-screen death against the one camera cell / view (PHYSICS 10.3) | single-player unchanged; multiplayer: bubble / leash instead of `off_screen` death, 4.7 |
| `player.gd:937`, `:1035` | the hero calls `level.tick_shake_timer()` once per tick (8i, death step) | with N heroes it would run N times: guard in `LevelBase.tick_shake_timer()` "once per `Sim.total_ticks`" (first caller wins - in single-player the only caller) |
| `player.gd:1037` | `Events.player_death_finished` (no hero) makes the level respawn | keep the emit; multiplayer routes the death to `level.hero_death_finished(self)`, 4.7 |
| `player.gd:359-361` | x step committed inside the level only | multiplayer: also inside the group view (edge walls), 4.5 |
| `scenes/player/player.tscn:4-12` | one look (4 weapon sheets) | per-slot palette (shared `ShaderMaterial` per slot), 5.3 |
| keep: `player.gd:91-92`, `:1075-1076` | every hero cheers on `exit_reached` | fine |
| keep: `player.gd:969-995`, `:998-1006` | contact pass and bounce are per hero | hero-vs-hero handled by the party driver |

### 3.5 Run state: `Game` autoload (11)

| Where | Assumption | Change |
|---|---|---|
| `scripts/core/game_state.gd:42-52` | `hearts`, `bones`, `weapon`, `has_glider` are the hero's | storage in `runs[slot]`; the four fields become property aliases of `runs[0]`, 4.2 |
| `game_state.gd:38-40` | one `score`, one `lives` | co-op: team score + team lives pool stay here, per-player stats in runs; versus: per-player in `VersusMatch` |
| `game_state.gd:36` | `difficulty` is the only run mode | add `mode` (`Defs.GameMode`), `party` (1..4); defaults = single-player |
| `game_state.gd:87-107` (`new_game`) | resets one hero | resets every run of the party |
| `game_state.gd:112-131` (`begin_level`) | resets P1 energy + glider; one entry snapshot | all runs; entry snapshot holds each run's weapon |
| `game_state.gd:140-163` (`restore_level_entry`) | one weapon restored | per run |
| `game_state.gd:197-246` | energy methods act on the hero | delegate to `runs[0]` (identical order of field writes and signals) |
| `game_state.gd:275-285` | `set_weapon` / `set_glider` for the hero | delegate to `runs[0]`; per-slot setters on `PlayerRun` |
| `game_state.gd:305-310` (`on_respawn`) | refills P1, drops P1 glider, clears tally | team wipe: every run; single revive: that run only |
| `game_state.gd:10-33` (signals) | no slot in `energy_changed`, `weapon_changed`, `glider_changed` | keep for P1; add `run_*_changed(slot, ...)` |
| `game_state.gd:63-66`, `:297-300` | one checkpoint | shared team checkpoint + slot offsets at respawn (4.7) |
| keep: `game_state.gd:45-48`, `:251-271`, `:53-54`, `:68-79`, `:166-177` | letters, feast kit, exit unlock, completion, tally; extra life every 250 000 into the pool | shared team state in co-op (versus does not use `Game.score`) |

### 3.6 Camera, view, `on_screen` (19)

| Where | Assumption | Change |
|---|---|---|
| `scripts/world/level_camera.gd:135-155` (`tick`) | follows one hero | single-player path untouched; `tick_group(heroes)` for N > 1, 4.5 |
| `level_camera.gd:160-185` (`snap`) | placed for one hero | `snap_group(heroes)` |
| `level_camera.gd:267-301` (`_follow_x`) | paging on one hero's column, `xvel`, `looking`, `facing` | group paging on the span of the living heroes |
| `level_camera.gd:305-327` | smooth follow on one hero | group variant |
| `level_camera.gd:331-376` (`_follow_y`) | row window of one hero, home row | group variant (anchor hero + spread rule) |
| `scripts/world/level.gd:214-216` | `snap_camera()` snaps on `player` | snap on the party |
| `level.gd:630-634` | `_camera_step()` ticks on `player` | `hero_count() == 1 ? tick(player) : tick_group(heroes)` |
| `level.gd:122-149` | one `Camera2D`, one parallax / weather view | unchanged for group camera; split screen needs SubViewports (option C, 4.5) |
| `scripts/base/level_base.gd:189-202` | one view rect, one camera cell, `is_in_view` = that rect | add `get_view_count()`, `get_view_rect_at(i)`; `is_in_view` = any view |
| `level_base.gd:205-228` | one camera lock | shared lock (arenas, rooms) - rule "lock when the party is inside", 3.13 |
| `level_base.gd:451-460` | `on_screen` = box meets the one view | any view (identical for one view) |
| `scripts/base/enemy_base.gd:183-184` | targetable only if drawn in **the** view | any view |
| `scripts/base/projectile_base.gd:66-72` | removed when not drawn in the view | any view |
| `scripts/projectiles/boss_stalactite.gd:47-48`, `enemy_ember.gd:63-70` | gone below the bottom of the view | below every view |
| `scripts/base/platform_base.gd:54` | ride test only while on screen | any view |
| `scripts/enemies/charger.gd:32`, `:65` | wake distance in view sizes; off-screen timer | view size of the group view; any view |
| `scripts/enemies/leaper.gd:46`, `:87`; `dropper.gd:55` | wake by the view; spawn above the view top | any view; the view the target hero is in |
| `scripts/core/scene_flow.gd:761-772` | iris closes on P1 | on the party centre (or the hero who reached the exit) |
| `scripts/ui/hud.gd:155-186` | HUD row / boss bar fade when P1 is under them | any hero |
| keep: `collectible_base.gd:151-155`, `boss_base.gd:188`, `level.gd:335-338` | cosmetic bob; unlock at boss defeat; test view size | unchanged |
| see 3.12 / 3.13: `gate.gd:130-139`, `arena_zone.gd:19-31`, `camera_lock_zone.gd:8-14` | camera lock / snap after one hero's gate travel or zone entry | counted there |

### 3.7 Doze manager (7)

| Where | Assumption | Change |
|---|---|---|
| `scripts/base/level_base.gd:70-80` | one hero rectangle (`_dz_hero_*`, `_doze_hero`) | `PackedInt32Array` of 4 ints per hero + per-hero last feet point |
| `level_base.gd:473-478` (`_on_tick_started`) | re-decide when **the** hero moved | when any hero moved (or any view) |
| `level_base.gd:513-555` (`_doze_update`) | builds one hero rect; full pass when it crosses a grid line | one rect per living hero; full pass when any crosses |
| `level_base.gd:566-573` (`_doze_far`) | far from the view and from one hero | far from every view and every hero rect |
| `level_base.gd:394-397` | full decision after a respawn | also after every multiplayer teleport (bubble, leash, revive, gate party travel, throw) via `notify_hero_teleported(hero)` |
| `scripts/core/tuning.gd:303-312` (`DOZE_HERO_REACH_PX` 128) | a hero moves at most 18 px/tick between decision and contact | a thrown partner, a boost or a bubble can move farther: either cap those moves at 18 px/tick or call `notify_hero_teleported` on every tick they exceed it |
| `tests/test_core_doze.gd:246-330` | proof with one hero | add a two-hero route replayed with and without dozing |
| keep: every `_doze_area()` / `_can_doze()` override (`enemy_base.gd:154-165`, `spawner_enemy.gd:46-47`, `collectible_base.gd:134-139`, `checkpoint_base.gd:42-47`, `level_exit_base.gd:82-87`, `gate.gd:77-82`, `rising_column.gd:78-83`, `spring.gd:35-40`, `sign_board.gd:118-123`, `zone_base.gd`, `hittable_base.gd:68-73`) | areas are hero-independent | the contract text in `sim_entity.gd:96-106` says "the hero": reword to "every hero" |

### 3.8 Enemies (19)

| Where | Assumption | Change |
|---|---|---|
| `scripts/base/enemy_base.gd:410-414` (`_target_hero`) | the target is `level.player` | `level.target_hero(self)`: nearest living, non-bubbled hero (ties -> lower slot), sticky for `EnemyTuning.TARGET_HOLD_TICKS`; N = 1 returns exactly today's value, 4.1 |
| `enemy_base.gd:382-387` (`_should_wake`) | anchor near the one view | any view (`is_in_view`) |
| `enemy_base.gd:393-402` (`_should_sleep`) | far from the one hero | far from every living hero |
| `enemy_base.gd:550-554` (`_shows_food`) | drawn as food when P1 feasts | when any hero feasts (co-op feast feeds the party, 4.8) |
| `enemy_base.gd:216-222` (`on_glider_stomp`) | points to the run | attribute to the stomping hero's stats (team score unchanged) |
| `enemy_base.gd:239-263` (`kill`) | points to the run, `killer` unused for credit | credit `hitter_slot(killer)` (versus kills, co-op stats) |
| `enemy_base.gd:190-203` (`take_hit`) | `source` = hero or ownerless projectile | `last_hit_slot`, `last_hit_tick`; hook `_on_hit_by(slot, power)` for co-op rules (two-hero hits), 4.8 |
| `enemy_base.gd:208-212` (`on_bounced`) | one bouncer | per-slot bounce bookkeeping hook (co-op "tandem bounce") |
| `scripts/enemies/charger.gd:28-34`, `:51-53` | wakes by the hero's distance, rushes toward him | target hero |
| `dart.gd:47-56` | dives at the hero | target hero |
| `digger.gd:41-44`, `:54`, `:81` | zone trigger by the hero, faces him | trigger by any hero in the zone; target hero |
| `dropper.gd:43-44`, `:53-58`, `:75`, `:96` | zone trigger by the hero; drops 192 px beside him above the view | any hero triggers; drop beside the triggering hero |
| `harrier.gd:41-52` | hovers around the hero, rises when he strikes | target hero |
| `hopper.gd:48-61` | range check to the hero | target hero |
| `leaper.gd:45-46`, `:60`, `:69` | faces the hero | target hero |
| `lurker.gd:53-54`, `:66`, `:71-73` | drops when the hero is in range, chases him | target hero |
| `snapper.gd:44-52`, `:81-85` | senses the hero; **its bite tests only the target hero** | sense the target; bite tests every hero in contact order |
| `spawner_enemy.gd:61-70` | triggered by the target hero | any hero triggers (`_triggered(hero)` per hero) |
| `stinger.gd:38-52` | dives at the hero | target hero |
| keep: `walker`, `flyer`, `patroller`, `swinger`, `dangler`, `hanger_enemy`, `decoration` | no hero reads | unchanged |
| keep: `enemy_base.gd:290-291`, `:617-618` | 12 active slots for one screen | shared by the party; review `MAX_ACTIVE_ENEMIES` only if split screen is built |

### 3.9 Bosses (9)

| Where | Assumption | Change |
|---|---|---|
| `scripts/base/boss_base.gd:109-134` (`poll_weapon_hit`) | projectiles of anyone, then **P1's** club box; pogo to P1 | all projectiles (reverse order, as now), then every hero's club box in slot order; return the power and set `last_hitter`; pogo to that hero |
| `boss_base.gd:139-145` (`_glance`) | P1's box | every hero's box |
| `scripts/bosses/brute.gd:128-135` | wakes by the target hero's distance | any hero in range |
| `brute.gd:139-141`, `:344-359` (`_on_head_hit`) | the hit is credited to the target hero; `Game.has_glider` | use `last_hitter` (glider removal, stagger direction) |
| `brute.gd:144-169` | AI against one hero | AI against the target; contacts against all (next row) |
| `brute.gd:363-376` (`_contact`) | body / head / fist tested against the target only | every hero in contact order |
| `brute.gd:182` | anger from the target's strike | any striking hero in range |
| `scripts/bosses/colossus.gd:115-121` | wakes by the target hero | any hero |
| `colossus.gd:143-144` | body touch tested against the target only | every hero |
| keep: `boss_base.gd:164-165` (`touch_hero(hero)`), `colossus.gd:255-266` (`_room`) | per-hero call; room from the arena | unchanged |
| keep: `boss_base.gd:93-102`, `:171-194`, `:197-207` | fight start / defeat / reset | shared fight; arena entry in 3.13; reset only on a team wipe (a single co-op down never resets the boss, 4.7) |

### 3.10 Projectiles (4)

| Where | Assumption | Change |
|---|---|---|
| `scripts/base/projectile_base.gd:77-83` (`_test_hero`) | enemy projectiles test `level.player` | every hero in contact order; first hit consumes |
| `projectile_base.gd:10-21`, `scripts/projectiles/hero_projectile.gd:21-24` | hero projectiles have no owner | `owner_slot` from spawn params (versus: they also test rival heroes, 4.9) |
| `scripts/projectiles/enemy_ember.gd:36-40` (`rain`) | falls 150 px above the hero | above the hero that is inside the rain zone (`rain_slot` param) |
| `enemy_ember.gd:74-79` | falling-ember count for one hero's rain | per zone / per slot cap |
| keep: `boss_rock.gd:60`, `boss_stalactite.gd:52` | `_on_hit_hero` cosmetics | unchanged |

### 3.11 Items (12)

| Where | Assumption | Change |
|---|---|---|
| `scripts/base/collectible_base.gd:121-128` | contact with `level.player` | every hero in contact order; first overlapping hero collects |
| `collectible_base.gd:167-189` (`collect`) | points / tally / completion to the run | team totals unchanged; per-slot stats (`run.picked`, versus score) |
| `scripts/items/heart.gd:13` | `Game.add_heart` | `hero.run.add_heart()` |
| `items/bone.gd:16` | `Game.add_bones` | `hero.run.add_bones()` |
| `items/one_up.gd:13` | `Game.add_lives` | co-op: team pool (keep); versus: stock of the collector |
| `items/glider.gd:15-18` | `Game.has_glider` | `hero.run.has_glider` |
| `items/weapon.gd:39-40` | `Game.set_weapon` | `hero.run.set_weapon` (route matrix: 5.6) |
| `items/feast_piece.gd:13-15` | the collector feasts | co-op: every living hero feasts (team kit) |
| `items/warp.gd:14-18`, `items/trophy.gd:13-17` | one hero's control is frozen, level completes | freeze every hero; co-op: same (team completes) |
| `items/item_effects.gd:21-32` (`skull`) | reads `Game.hearts / bones` | `hero.run` |
| `items/code_stone.gd:31-32` | password of (level, difficulty) | co-op continues from the save, no co-op codes (4.10) |
| `scripts/world/fly_swarm.gd:89-94`, `zones/flies_zone.gd:16-19`, `items/water_bucket.gd` | the swarm circles P1 | swarm per hero (cosmetic) |
| keep: `items/item_effects.gd:38-68` (`kill_all`, `grenade`), `fire_starter.gd:14`, `letter.gd:23-26`, `random_bonus.gd`, `item_contents.gd` | on-screen enemies (any view), shared unlock, jackpot above the collector (letters are a team pool), `Sim.rng` | unchanged |

### 3.12 Objects (11)

| Where | Assumption | Change |
|---|---|---|
| `scripts/base/hazard_base.gd:30-37` | touches `level.player` | every hero |
| `scripts/base/checkpoint_base.gd:27-33`, `:50-60` | activated by the hero, stores **his** feet point | any hero activates; shared checkpoint; respawn slots spread from it, 4.7 |
| `scripts/base/level_exit_base.gd:45-51`, `:60-67` | the hero touching it ends the level | single-player unchanged; co-op team rule (every living hero inside, or the first waits), 4.8 |
| `scripts/base/platform_base.gd:17`, `:57`, `:77` | **static** `_carried_on_tick`: "the hero" rides at most one platform per tick | per-hero guard (`hero.carried_on_tick`); identical for one hero |
| `platform_base.gd:52-78` (`_ride_test`) | ride test against `level.player` | every hero (slot order); `ridden` = any |
| `scripts/objects/moving_platform.gd:45-47`, `drop_platform.gd:33-55` | `ridden` means "the hero is on it" | any hero; drop platforms may count riders (weight puzzles) |
| `scripts/objects/spring.gd:43-66` | launches `level.player` | every hero |
| `scripts/objects/gate.gd:61-66`, `:86-94`, `:97-115` | one hero presses Down; `Game.has_glider` | per hero; party travel, 4.8 |
| `gate.gd:117-140` (`_arrive`) | teleports `level.player`, **not** the hero that entered | store the entering hero(es); teleport them; `notify_hero_teleported` |
| `scripts/objects/rising_column.gd:57-67`, `:113-124` | triggered by the hero; carries only him up | any hero triggers; carries every hero on top |
| `scripts/objects/npc.gd:66-73`, `sign_board.gd:105-112` | faces / shows for P1 (in the tick) | nearest hero / any hero near |
| keep: `hittable_base.gd:92-107`, `hidden_spot.gd`, `breakable_block.gd`, `container.gd`, `scenery_hittable.gd` | hit by any weapon; `strike_dir` from source | unchanged |

### 3.13 Zones (5)

| Where | Assumption | Change |
|---|---|---|
| `scripts/zones/zone_base.gd:20-22`, `:45-58` | `inside: bool` for one hero; enter / exit hooks for him | `inside_mask` (bit per slot); hooks per hero plus `_on_first_entered` / `_on_last_exited`; `inside` = mask != 0 |
| `zones/arena_zone.gd:19-31` | first hero entry locks the camera and starts the fight | co-op: lock on first entry and pull the others in behind a curtain (or lock when all are in) |
| `zones/camera_lock_zone.gd:8-14` | lock / unlock on one hero | lock on first, unlock on last |
| `zones/ember_rain_zone.gd:32-42` | rains on P1 while inside | per hero inside |
| `zones/message_zone.gd:29-46` | hint for the hero inside | shown while any hero is inside (first-entered / last-exited hooks) |
| keep: `secret_zone.gd:10-14`, `dark_zone.gd:15-16`, `autoscroll_stop_zone.gd:8-9`, `kill_zone.gd:7-8` | counted once / shared effects / kills the hero who entered (per hero once 3.13 row 1 is in; co-op turns it into a bubble through 4.7) | unchanged |

### 3.14 Death, respawn, game over, time limit, shake (9)

| Where | Assumption | Change |
|---|---|---|
| `scripts/base/level_base.gd:100-101`, `:426-431` | `Events.player_death_finished` -> `Game.lose_life()` -> respawn or game over | single-player unchanged; multiplayer via `hero_death_finished(hero)`: down / bubble, team wipe, versus respawn, 4.7 |
| `level_base.gd:381-398` (`respawn_player`) | resets every entity and puts the hero back | team wipe only; per-hero `respawn_hero(hero)` without world reset for co-op revive / versus |
| `level_base.gd:372-374` (`get_respawn_pos`) | one point | `get_respawn_pos_for(slot)` (checkpoint + slot offset on floor) |
| `scripts/world/level.gd:293-301`, `:666-676` | one pending respawn behind the curtain | team-wipe curtain; per-hero respawns without curtain (bubble) |
| `level.gd:119`, `:159-161` | death jingle on any hero death if lives remain | team wipe only (a co-op down plays a short cue) |
| `level_base.gd:330-340` (`tick_time_limit`) | counts while P1 lives; kills P1 at 0 | counts while any hero lives; kills every hero (team) |
| `level_base.gd:437-443` | shake nudge lifts P1 | every hero |
| `scripts/core/scene_flow.gd:383-395` (`restart_level`) | a dying P1 costs a life first | any hero in a death toss / team rule |
| `scripts/ui/pause_menu.gd:108-116`, `:236-238` | "restart from checkpoint" kills P1 | the pausing slot's hero (co-op: team give-up = team wipe) |
| see 3.4: `level_base.gd:292-295` | `tick_shake_timer()` called once per tick by the hero | the once-per-tick guard lives here, counted in 3.4 |

### 3.15 Flow, tally, save, codes, menus (11)

| Where | Assumption | Change |
|---|---|---|
| `scripts/core/scene_flow.gd:333-355` | `start_new_game(difficulty)` / `continue_game` | `start_coop_game(difficulty, party)`, `start_versus(match)` |
| `scene_flow.gd:400-437`, `:440-477` | results recorded per difficulty | per (mode, difficulty) |
| `scene_flow.gd:652-655` | one HUD, one touch overlay, one pause menu | HUD with player panels; one touch overlay per touch slot |
| `scripts/core/save.gd:100-152` | unlocks, results, high score keyed by difficulty | `Save.VERSION = 2`, mode namespaces (`single`, `coop`), migration in `_migrate` |
| `scripts/core/level_registry.gd` (`get_campaign`, passwords) | one campaign per difficulty | mode-aware campaign (co-op variants), versus arena list |
| `scripts/ui/code_entry.gd` | codes per difficulty | co-op continues from the save (no co-op codes), 4.10 |
| `scripts/ui/mode_select.gd:69-71`, `title.gd:269-270` | Start -> difficulty only | Start -> Solo / Co-op / Versus -> join screen |
| `scripts/ui/tally.gd:44-47`, `:80`, `:247` | one score, one tally list | team tally + per-player lines |
| `scripts/ui/world_map.gd:108` | one lives / score line | team line + party portraits |
| `scripts/ui/game_over.gd:53-57`, `the_end.gd:51` | one score / high score | per mode |
| (new) | no join / device assignment screen | `scenes/ui/join.tscn` (press to join, device per slot, colour) |
| keep: `scene_flow.gd:364-376` (`start_level`) | begins the level | unchanged API; `Game` carries party and mode |

### 3.16 HUD and UI overlays (6)

| Where | Assumption | Change |
|---|---|---|
| `scripts/ui/hud.gd:121-127` | binds P1's `Game` signals (score, lives, energy, letters) | P1 panel unchanged; panels for slots 1..3 on `run_*_changed(slot)` |
| `hud.gd:204-211` (`refresh`) | one hero's values | every panel |
| `hud.gd` layout (`_build_left`, `_build_hearts`) | one left panel | P1 top-left (today), P2 top-right mirrored, P3 / P4 bottom corners; shared letters / score centre |
| `scripts/ui/pause_menu.gd:228-235` | header shows the one score | team score + party; options for the pausing slot |
| `scripts/ui/options_panel.gd` (bindings) | one profile | profile tabs P1..P4, "keyboard test" for ghosting |
| (new) versus screens | none | round intro, scoreboard, match result (`scripts/ui/versus_*.gd`) |
| see 3.2 / 3.6: `touch_controls.gd`, `hud.gd:155-186` | one overlay; fades under P1 | counted there (duo layout, any-hero fade) |

### 3.17 Events bus and audio (5)

| Where | Assumption | Change |
|---|---|---|
| `scripts/core/events.gd:15-31` | hero signals carry no hero (`player_hurt`, `player_died`, `player_death_finished`, `player_landed`, `player_jumped`, `player_struck`, `player_bounced`, `glider_state_changed`) | keep (emitted for every hero, as today for the one); append `hero_*` twins with the hero first (`hero_hurt(hero, kind, source)` ...) |
| `events.gd:67` | `feast_changed(ticks)` no hero | `hero_feast_changed(hero, ticks)` |
| `events.gd` (new) | no party events | `hero_down`, `hero_revived`, `hero_ko(victim, killer, cause)`, `party_wiped`, `round_*` |
| `scripts/core/audio_manager.gd` push / pop (`player.gd:216`, `:1066-1067`) | one feast at a time | `Audio.hold_music(context, holder)` / `release_music(context, holder)` refcount; single-player keeps push / pop |
| ARCHITECTURE 11 audio budget (10 SFX voices) | one hero's footsteps / swings | per-hero SFX throttling (same event within 2 ticks from two heroes -> one voice) |

### 3.18 Autoplay harness, flows, perf probe, sim bench (13)

| Where | Assumption | Change |
|---|---|---|
| `scripts/core/autoplay.gd:181-215` (`parse_inputs`) | one stream per file | unchanged; new `parse_inputs_multi(text) -> Array[PackedInt32Array]`, 4.11 |
| `autoplay.gd:338`, `:362-368` | `set_scripted(_flags_for_tick)` | per-slot sources |
| `autoplay.gd:251-255`, `:329` (`--weapon`) | one weapon | `--weapon=club,axe` per slot; `--players=n` |
| `autoplay.gd:380-388` (trace) | one hero per tick in `trace.json` | extra columns per slot when the party > 1 |
| (new) `autoplay.gd` | no recorder | `--record=<file>` writes the played multi-stream input |
| `scripts/core/dev/autoplay_flow.gd:132`, `:195`, `:198` | one scripted stream | per slot |
| `autoplay_flow.gd:203-207` (`play`, `play_file`, `weapon`) | single-stream play, one weapon | `play 8:R|L`, `weapon axe 2` |
| `autoplay_flow.gd:417-418` | trace of P1 | per slot |
| `autoplay_flow.gd:544`, `:563-571` | root `hero`, `enemy` = nearest to P1 | `hero` = P1, `hero2..hero4` roots |
| `autoplay_flow.gd:192`, `:537` (`input device`) | the hero reads every device | `input device <slot>` |
| `scripts/core/dev/perf_probe.gd:189-191`, `:293-294` | worst-tick position of P1 | P1 + party size in the report |
| `scripts/core/dev/sim_bench_runner.gd:247-251`, `:283-285` | one input stream per route | multi-stream routes |
| `sim_bench_runner.gd:387-428` (`_digest_line`) | hashes P1 only (and skips `Kind.PLAYER`) | **frozen for a party of one**; extra heroes appended only when `hero_count() > 1` (4.12) |

Pre-existing defect found: `sim_bench_runner.gd:427` reads `level._doze_bounds`, which does not exist in
`level_base.gd` (the fields are `_dz_view_*` / `_dz_hero_*`): `--dump=<level>:<tick>` fails at runtime. Fix it in
the same core change that touches the digest.

### 3.19 Tests and helpers (6)

| Where | Assumption | Change |
|---|---|---|
| `tests/test_case.gd:153-162` (`run_inputs`) | one stream | `run_party_inputs([[ticks, "R|L"], ...])` helper |
| `tests/test_case.gd:177-179` | `clear_scripted()` resets one source | resets every slot |
| `tests/test_campaign_routes.gd:1517-1542` (`_run`), `:900-924`, `:769-787` | one stream; replays read `level.player` | `_run_party`; ROUTES entries with `players` |
| `test_campaign_routes.gd:55-59`, `:77-320`, `:580-612` | weapon matrix per (stage, difficulty, weapon) | co-op matrix rule (5.6) |
| `tests/test_core_doze.gd:246-330` | one-hero proof | + party proof |
| (new) | no invariant test for the set of one | `tests/test_core_players.gd` (4.12) |
| keep: 43 `level.player` reads in 11 test files (`test_enemies_colossus.gd` 11, `test_route_tools.gd` 8, `test_campaign_routes.gd` 7 ...) | P1 | `player` keeps meaning P1 |

### 3.20 Level format and content pipeline (7)

| Where | Assumption | Change |
|---|---|---|
| `scripts/core/level_text.gd:209-214` (`applies_to`) | spawn filters by difficulty only | add mode flags `solo` / `coop` / `versus` (skipped before spawn) |
| `scripts/core/level_registry.gd:101-106` (`meta_value`) | variants `.beginner` / `.expert` | add `.coop` (and `.coop.expert` precedence) |
| `scripts/world/level_data.gd:168-171` (`build_grid`) | `legend_tiles(legend)` ignores flags | forbid `tile=` on mode-flagged legend entries (validator), or make the grid mode-aware |
| ARCHITECTURE 7.3 `kind` | `main` `sub` `bonus` `ending` `test` | add `coop` (variant of a stage, `coop_of = <id>`) and `arena`; the single-player registry, which only lists `main` / `sub` / `bonus` / `ending`, never sees them |
| `level_validator.gd` limits | 150 enemies, 70 items, 80 hittables, 16 platforms per level | per mode |
| validator: passwords unique across levels and modes | two modes | co-op files carry no passwords |
| `levels/*.lvl` | one `@` | `objects/hero_start slot=2..4` in `[entities]` |

---

## 4. Refactor design

### 4.1 PlayerSet (on `LevelBase`, world-owned base; additive)

```
## Heroes in slot order (slot 0 = P1 = `player`). Never null entries inside 0..hero_count()-1 while playing.
var heroes: Array[PlayerBase] = []
## Feet points where each slot starts (slot 0 = `start_pos`).
var start_positions: Array[Vector2i] = []
func hero_count() -> int
func get_hero(slot: int) -> PlayerBase
## The hero an enemy at `from` reacts to: N == 1 -> `player` if not dead, else null (exactly the old
## `_target_hero()`); N > 1 -> nearest hero that is not dead / down / bubbled (|dx| + |dy|, ties -> lower slot).
func target_hero(from: SimEntity) -> PlayerBase
## Heroes in the order contested contacts test them this tick: slot order in co-op, rotated by Sim.tick % N in
## versus (fairness). Preallocated rotations; no allocation per call.
func contact_order() -> Array[PlayerBase]
func any_hero_dead_or_down() -> bool
func get_view_count() -> int
func get_view_rect_at(index: int) -> Rect2i
func hero_death_finished(hero: PlayerBase) -> void    # multiplayer death routing (4.7)
func respawn_hero(hero: PlayerBase, pos: Vector2i) -> void
func notify_hero_teleported(hero: PlayerBase) -> void  # doze decision (4.6)
```

`PlayerBase` additions (player-owned, additive): `slot: int` (spawn param `slot`, default 0), `run: PlayerRun`,
`carried_on_tick: int` (replaces the static platform guard), `down: bool`, `bubble: bool`, `carrying` / `carried_by`,
`is_down()`, `revive(by)`, `is_party_targetable()`.

Rule for every reader of "the hero" (sections 3.8-3.13): replace by one of three idioms - **target**
(`level.target_hero(self)`), **every** (`for hero in level.contact_order()`), **P1** (`level.player`, UI that is
genuinely P1). All three reduce to today's code for a party of one.

### 4.2 Per-player versus shared state

`PlayerRun` (new core class, `scripts/core/player_run.gd`): `slot`, `hearts`, `bones`, `weapon`, `has_glider`,
stats (`score`, `kills`, `deaths`, `revives`, `picked`), versus `stocks`; methods with the exact bodies of today's
`Game` methods (`lose_heart`, `lose_bone`, `add_bones`, `add_heart`, `scatter_energy`, `set_weapon`, `set_glider`,
`is_full_energy`, `reset_energy`) and signals `energy_changed`, `weapon_changed`, `glider_changed`.

`Game` (core): `runs: Array[PlayerRun]` (4, always allocated), `party: int = 1`, `mode: int = Defs.GameMode.SINGLE`.
The frozen fields become GDScript properties of `runs[0]`:

```
var hearts: int:
	get: return runs[0].hearts
	set(value): runs[0].hearts = value
```

and the frozen methods delegate (`func lose_heart() -> bool: return runs[0].lose_heart()`), with `runs[0]` also
emitting the legacy `Game.energy_changed` / `weapon_changed` / `glider_changed` right where `Game` emits them today.
Field writes and signal order are unchanged; the HUD and tests that read or assign `Game.hearts` keep working.

| State | Single | Co-op | Versus |
|---|---|---|---|
| hearts, bones, glider, weapon, feast | hero / `Game` alias | per hero (`PlayerRun`) | per hero |
| score | `Game.score` | team `Game.score` (saved, extra lives) + per-hero stat for the tally | per hero (`VersusMatch`) |
| lives | `Game.lives` | team pool `Game.lives` (a team wipe costs one) | stocks per hero |
| letters G-R-U-B-S, feast kit | `Game` | team pool; a full kit feeds every living hero | off (arena items instead) |
| checkpoint, exit unlock, completion, secrets, tally list | `Game` | team | n/a |
| difficulty, level, warp return | `Game` | team | arena id, round |

### 4.3 Input devices

- `InputSlot` (core, `scripts/core/input_slot.gd`): `kind` = `ALL_DEVICES` (single-player slot 0, today's path),
  `KEYBOARD_LEFT`, `KEYBOARD_RIGHT`, `KEYBOARD_FULL`, `PAD` (+ `device_id`), `TOUCH` (+ screen region), `BOT`,
  `SCRIPT`.
- Per-slot actions are generated at runtime (`InputMap.add_action(&"p2_jump", 0.5)` etc.) from the slot's binding
  profile; pad events get `device = device_id`, so `Input.is_action_pressed(&"p2_jump")` sees only that pad. Keyboard
  halves get disjoint physical keys. Defaults (rebindable, stored as `[bindings_p2]`...):
  - P1 left half: move W A S D, jump G (and W while "Up jumps"), attack F, look R.
  - P2 right half: move arrows, jump `/` (and Up while "Up jumps"), attack `.`, look `,`.
  - In a party, the single-player cross-bindings (arrows on P1) are not used: slot 0 also switches to its own
    generated `p1_*` set, so the halves never feed two heroes. Single-player never generates actions.
- Latching: `_input(event)` maps the event to its slot (key -> keyboard half by physical keycode, joypad -> slot by
  `event.device`, touch -> slot by region) and latches there, so sub-tick taps survive per player.
- `sample()`: slot 0 first, byte-for-byte today's code when `party == 1`; then slots 1..N-1. Bots (`BOT`) compute
  their flags here from the state at the end of the previous tick (deterministic, replayable; their own `SimRng`
  seeded from match seed + slot).
- Join screen: "press any button" assigns the device to the next free slot; `Input.joy_connection_changed` during
  play pauses and opens the re-join dialog (Android pad ids change on reconnect).
- Touch: phones - one touch player (the others on pads); tablets >= 9" - duo layout, each half with a compact
  stick + 2 buttons. `vibrate_slot()` rumbles only that slot's pad.
- Menus keep `ui_*` from any device (anyone can navigate); the pause menu focus follows the pausing slot.

### 4.4 Order of operations with several heroes (deterministic)

Registration order: level entities (file order) -> P1 -> P2 -> ... -> PN -> `PartyDriver` (multiplayer only) ->
runtime spawns. So inside every phase heroes run in slot order and after the level's own entities, as the one hero
does today.

| `Defs.Phase` | Single-player (today) | With N heroes |
|---|---|---|
| `FX` | puffs | unchanged |
| `WEAPONS` | hero: own projectiles + last tick's club box vs enemies, then hittables; one target per box | each hero, slot order, **own** projectiles only (`owner_slot`); an enemy killed by P1 is not targetable for P2 in the same tick. Versus: `PartyDriver` then gathers every remaining box / projectile vs rival heroes and applies all hits at once (trades are simultaneous) |
| `ENEMIES` | AI on `_target_hero()`; bosses poll P1's box | AI on `target_hero()`; bosses poll all boxes in slot order, `last_hitter` |
| `PROJECTILES`, `ITEMS` | move | unchanged |
| `PLATFORMS` | platforms move, ride test with P1 (static guard) | ride test for each hero in slot order (per-hero guard); then `PartyDriver`: hero-on-hero stacking from previous-tick positions (carrier's `sim_pos - sim_prev`), carry / throw starts |
| `PLAYER` | input, state, handler, integrate, tiles, timers (`tick_shake_timer`) | each hero in slot order with its slot flags; shake timer once per tick (guard); multiplayer edge walls in the x commit |
| `CONTACT_ENEMIES` | P1 vs first overlapping enemy | each hero in slot order. Versus: `PartyDriver` resolves stomps on rival heads (gather, then apply) |
| `CONTACT_ITEMS` | each item / checkpoint / exit / hazard / enemy shot / zone tests P1 | each tests the heroes in `contact_order()`; collectibles: first overlapping hero wins; zones: per-hero mask. `PartyDriver`: revive touches, plate counts |
| `WORLD` | cool-downs, wind, darkness | unchanged |
| `CAMERA` | `LevelCamera.tick(player)` | `tick(player)` for one, `tick_group(heroes)` otherwise |
| `POST` | `hit_timer`, death toss, time limit | each hero in slot order; time limit team rule; `PartyDriver`: bubble drift, down timers, team-wipe check |
| end of tick | shake nudge P1, doze, on_screen vs one view | nudge every hero; doze with N rects; on_screen vs every view |

Fairness: in co-op fixed slot order is fine (both are on the same team). In versus, contested pick-ups and
simultaneous body contacts use `contact_order()` rotated by `Sim.tick % N`; PvP hits are gathered then applied, so no
slot wins a trade by order.

### 4.5 Camera for 2+ heroes on a paging camera

| Option | How | Sim / code cost | Render cost | Feel | Mobile |
|---|---|---|---|---|---|
| A. Leader + leash | page on P1 (or the hero ahead); others clamped to the view, teleported to the leader after 2 s off-view | low: `tick_group` = `tick` on the leader + clamp | none | P2 feels dragged | fine |
| **B. Group paging + edge walls + bubble (recommended for co-op)** | page right when the rightmost hero reaches the start column **and** the leftmost is not at the left margin; stop when the rightmost is back at column 5 or the leftmost reaches column 1 (left mirrored). Heroes cannot leave the view sideways (x commit clamped to view +/- 8 px). Vertical: row window on the anchor (lowest slot alive and grounded), the other follows; a hero out of the view for 48 ticks (or below it) turns into a bubble that drifts to the anchor | low: one new method in `LevelCamera`, clamp in `Player` x commit, bubble state; integer, deterministic | none | classic couch co-op; forces staying together, which the co-op design wants anyway | fine |
| C. Dynamic split (merge when close) | two SubViewports, each with its own camera; merge when the span fits | high: every view consumer (the 19 rows of 3.6) per view; `MAX_ACTIVE_ENEMIES` and doze per view | tile layers and parallax drawn twice: ~50-70 draw calls (budget 60), fill rate x2 | heroes free | too costly on the A53, each half of a phone is ~10 columns |
| D. Fixed vertical split | always two panes | as C | as C | each pane 10 columns: breaks the 20-column design rule (LEVEL_DESIGN 13) | no |
| E. Locked arena (versus) | arena fits one 20 x 11 view; `lock_camera(arena rect)` | none | none | best for deathmatch | fine |

Recommendation: B for the co-op campaign, E for versus arenas (B for the few larger arenas), C only as a later
desktop-only option. The auto-scroll stage (4-1) keeps its rule: the deadly top edge turns a hero into a bubble in
co-op instead of killing him.

### 4.6 Doze and `on_screen` with N heroes / views

- Hero rectangles: one per living hero (bubbles excluded - they never touch anything). Grid snapping and change
  detection per rectangle; a full pass when any crosses a grid line.
- `_on_tick_started` re-decides when any hero or any view moved since the last decision.
- Every multiplayer move faster than the 18 px/tick the reach argument assumes (throw, boost launch, bubble drift
  catch-up, leash / revive teleport, party gate travel) calls `notify_hero_teleported(hero)`, which forces a
  decision before the next phase - the same mechanism the respawn uses (`level_base.gd:394-397`).
- `on_screen` = in any view; a dozing entity is outside every view by construction (the union of view regions is
  inside the doze region).
- Proof extension: `test_core_doze.gd` replays a two-hero route with and without dozing and checks per tick that no
  dozing entity is within reach of any hero or inside any view.

### 4.7 Death, down, revive, team wipe

- Single-player: unchanged (`player_death_finished` -> `lose_life` -> curtain respawn or game over).
- Co-op: a hero who would die becomes **down** (bubble): no collisions, drifts toward the nearest living partner,
  revived by a partner's touch (or club tap) with 1 heart, at the cost of the bubble's slow return. If every hero is
  down / dead at once: **team wipe** - one life from the team pool, `respawn_player()` as today (world reset), every
  hero placed at the checkpoint spread by slot (`get_respawn_pos_for(slot)`: checkpoint, then 24 px steps toward
  the floor side that is free). Pool empty -> game over. Instant-death tiles (pits, spikes, lava) also produce a bubble
  while a partner lives.
- Versus: death toss as today, then per-hero respawn at the free spawn farthest from rivals after
  `VersusTuning.RESPAWN_TICKS`, no world reset; stocks / KO credit per hero (last hitter within 3 s).
- The world never resets for one co-op death: enemies, bosses and platforms keep their state (a boss is reset only by
  a team wipe).

### 4.8 Co-op entity interfaces (what enemies / objects / bosses can build on)

Contract additions that the design documents can rely on; all default to today's behaviour:

| Interface | Owner | Use |
|---|---|---|
| `PlayerBase.slot`, `LevelBase.hero_count()`, `heroes`, `contact_order()`, `target_hero()` | player / world | everything |
| `hitter_slot(source) -> int` (PlayerBase -> slot, hero projectile -> `owner_slot`, else -1) | core (`Defs` static) | attribution, two-hero hit rules |
| `EnemyBase.last_hit_slot`, `last_hit_tick`, hook `_on_hit_by(slot, power)`, `accepts_hit_from(hero) -> bool` (default true) | enemies | "shielded from the front" (one lures, one hits from behind), "twin hit" (two different slots within W ticks), heavy enemies only a boosted / charged hit breaks |
| `EnemyBase._choose_target()` hook (default `level.target_hero(self)`) | enemies | aggro-split enemies (stick to the hero who hit them last; the other hits) |
| `BossBase.last_hitter`, weak points that open only while a switch is held | enemies | two-weak-point bosses, "hold the lever while I hit" |
| Hero stacking (`PartyDriver`, PLATFORMS phase): stand on a partner's head (ride rules of PHYSICS 11.4 with the partner as the platform), boost jump off a partner's head (`Tuning.BOUNCE_YVEL_UP`, 105 px), carry (Down + Fire next to a partner), throw (Fire while carrying) | player (hero side) + world (driver) | ledges out of solo reach, throw a partner over a gap |
| Pressure plate (`objects/plate count=n`), held lever (`objects/lever`), team gate (`objects/gate team=true`), team exit (`objects/exit team=true`), seesaw (`objects/seesaw`), rope winch | objects | "two needed" puzzles; all test heroes in `CONTACT_ITEMS` and keep a per-slot mask |
| Revive (`PartyDriver`, `CONTACT_ITEMS`) | world | down / bubble rescue |
| Zone hooks `_on_first_entered` / `_on_last_exited`, `inside_mask` | world | arenas, camera rooms, team triggers |

### 4.9 Versus infrastructure

- Arena files: `levels/arena_<name>.lvl`, `kind = arena`, `players = 2..4`, `round_time` (s), `stocks`,
  `items` (spawn table); `@` = P1, `objects/hero_start slot=n` for the others; `objects/item_spawner` (period,
  table) driven by `Sim.rng` seeded per round (`seed = match_seed * 31 + round`), so a round is a pure function of
  the inputs.
- `VersusMatch` (core, held by `Game.match`): players, colours, devices, rules (stocks / time / first to N KOs),
  per-round results, KO feed.
- `VersusReferee` (world, the `PartyDriver` in arena mode): PvP hits (club box / own projectiles vs rival heroes -
  `Overlap.weapon` / `weapon_entity`, gather then apply), stomps on rival heads (stun + steal a bone), KO credit,
  round timer, sudden death, respawn placement.
- Flow: `start_versus(match)` -> `start_round(arena, n)` (curtain) -> round end -> `versus_scoreboard` screen -> next
  round / match result. No save progress; high scores per arena optional.
- Bots: `InputSlot.BOT` with a deterministic `HeroBot` (reads the previous tick's state in `GameInput.sample()`); bot
  inputs are recorded like human inputs, so any match can be replayed tick for tick.

### 4.10 Level format extensions

- Mode flags on entities: `solo`, `coop`, `versus` (like `expert` / `beginner`; skipped before spawn, no serial).
  Meta variants `key.coop`. Validator: no `tile=` on a mode-flagged legend entry.
- Co-op levels: the co-op layouts need geometry of their own (boost ledges, plates, team gates), so each co-op stage
  is its own file `levels/<id>_coop.lvl` (`kind = coop`, `coop_of = <id>`); the 15 existing single-player files
  stay byte-identical (their route proofs cannot move), and a new `kind` keeps the co-op files out of every
  single-player registry query (`get_campaign`, `next_level`, the map). New stages are authored as a solo file and a
  co-op file. The co-op campaign is the solo campaign with every stop replaced by its `coop_of` file; co-op continues
  from the save (no co-op passwords). Mode flags (`coop` / `solo`) stay available for small differences inside one
  file (new stages whose co-op version only adds a plate or a start).
- Hero starts: `objects/hero_start slot=2..4` (invisible marker; ignored in single-player).

### 4.11 Route harness for two (or four) input streams

- Format: one file, run-length entries with one key set per slot separated by `|`:
  ```
  # players: 2   weapon: club
  8:R|R,10:RU|,4:DF|DF
  ```
  A missing part = idle; a file without `|` and without the `players` header is a single-player route and goes
  through today's `parse_inputs()` (no change to any existing route). Names:
  `<id>_coop[.expert][.<weapon>].inputs` (team weapon, 5.6; `<w1>-<w2>` only if per-hero weapons are chosen).
- Replay: `GameInput.set_scripted_slot(slot, callable)` per stream; `test_case.gd` gets `run_party_inputs`; the route
  test gets `_run_party` and ROUTES entries with `players: 2`, the same `expect` checks plus per-slot ones.
- Recording: `--record=<file>` (Autoplay, debug builds) appends every slot's sampled flags on `Sim.tick_started` and
  writes the multi-stream file at the end - two people play a stage with pads in the windowed game and the result is
  a tick-exact proof. Bots are recorded the same way.
- Flows: `play 8:R|L`, `play_file`, `weapon <name> [slot]`, roots `hero2..hero4`, `input device <slot>`.
- Bench and digests replay multi-stream routes the same way.

### 4.12 Single-player stays tick-identical - how it is proven

1. **Freeze the evidence before touching code** (one person, once):
   ```
   bash .tools/gd.sh script res://scripts/core/dev/sim_bench.gd -- --make-snapshot=res://build/mp_baseline
   bash .tools/gd.sh script res://scripts/core/dev/sim_bench.gd -- --snapshot=res://build/mp_baseline --digest --tight --out=res://build/mp_digest_before
   bash .tools/gd.sh script res://scripts/core/dev/sim_bench.gd -- --snapshot=res://build/mp_baseline --digest --tight --no-doze --out=res://build/mp_digest_before_nodoze
   ```
   One digest per route and mode: per tick the tick, RNG state, score, P1 feet point and a hash over the run state,
   camera and every non-FX entity (`sim_bench_runner.gd:387-428`).
2. **After every refactor step**: the same commands into `mp_digest_after*`, `diff -r` must be empty, plus
   `bash .tools/gd.sh test` (575 green: every route tick-exact through Flow, golden traces, fidelity tables, the doze
   proof). A non-empty diff names the route, the first tick and (with `--dump=<level>:<tick>`, once its defect is
   fixed) the entity.
3. **The digest itself is frozen for a party of one**: `_digest_line` keeps its exact array for `hero_count() == 1`;
   multiplayer fields (heroes 2..N, runs, party driver) are appended only when the party is larger.
4. **Same order, same RNG**: the digest contains `Sim.rng.get_state()` every tick, so an extra or missing draw shows
   at the tick it happens; serial-order changes show as entity-hash changes.
5. **Permanent guard** (new, core): `tests/test_core_players.gd` asserts for a single-player level `heroes == [player]`,
   `GameInput.get_flags(0) == GameInput.flags` every tick, `Game.hearts` aliasing `runs[0]`, and replays three
   representative routes (`w1_l1.inputs`, `w2_l2b.inputs` with the Brute, `w4_l1.boomerang.inputs` auto-scroll)
   comparing each tick's digest hash with fixtures committed from the baseline (`tests/fixtures/sp_digest/*.txt`) -
   so later multiplayer work cannot drift single-player unnoticed.
6. **Multiplayer determinism** (new): every co-op route replayed twice -> identical digests; with and without
   dozing -> identical; with a different device assignment -> identical (devices never reach the sim).

---

## 5. Risks

### 5.1 Determinism (highest)

| Risk | Where | Mitigation |
|---|---|---|
| Shake counter decremented once per hero per tick | `player.gd:937`, `:1035` -> `level_base.gd:292-295` | once-per-tick guard (first caller wins; single-player has one caller) |
| Static carry guard shared by heroes | `platform_base.gd:17`, `:57`, `:77` | per-hero field |
| Static `Overlap.stomp` / `depth` read after another hero's test | `overlap.gd:13-15`; readers `player.gd:980-981`, `brute.gd:367-369`, `spring.gd:59-60` | read into locals immediately after each call (as `player.gd` does); review new code for it |
| Event-driven sim step | `Events.player_death_finished` -> `level_base.gd:426-431` | keep for single-player; direct call for multiplayer |
| Spawn serials shift | extra heroes / driver / mode-flagged entities | spawn after P1 only; filter before spawn |
| Feast music refcount | `player.gd:216`, `:1065-1067` | `Audio.hold_music/release_music` in multiplayer |
| Gate teleports the wrong hero | `gate.gd:117-140` uses `level.player` | store the entering hero |
| Doze with fast hero moves | `tuning.gd:303-312` | `notify_hero_teleported`, two-hero doze proof |
| Bots / cosmetics drawing from `Sim.rng` | new code | own `SimRng`s; digest shows RNG state |

### 5.2 Performance budget (Cortex-A53, ARCHITECTURE 11)

- Today (desktop windowed, ARCHITECTURE 11.4): 132-272 us average per tick, p99 353-870 us; the desktop proxy budget
  (150 / 500 us) is already missed; the hero is ~75 us over his four phases, fixed per-tick work ~50 us. At the
  documented 10-15x the A53 runs about 1.3-4 ms per tick against a 2 ms budget.
- Each extra hero: ~75 us (his phases) + ~10-20 us (every self-testing entity runs N coarse overlap rejects, ~40
  awake) + ~5 us (group camera) + ~5 us (doze rectangles) = **~+100 us desktop (+40 %)**, about +1-1.5 ms on the
  A53. 2 heroes: ~2.3-5.5 ms per tick there; 4 heroes: ~4-9 ms (a tick lands in ~40 % of the 60 Hz frames, with
  catch-up up to 4 ticks).
- Doze: with the group camera both heroes are inside one view, so the awake set grows little (their reach rectangles
  overlap); with split screen it can double (45 -> ~90 ticking, budget 48).
- Rendering: group camera adds 1-2 sprites per hero (hero + glider) and one material per palette - negligible;
  split screen doubles tile and parallax draws (~50-70 per frame vs 60).
- Plan: 2-player co-op on low-end Android, 3-4 players desktop / higher-end devices (versus arenas are cheap: < 30
  entities); a hero performance pass (animation / box update / visual refresh) before 4-player is enabled on mobile;
  `--perf` campaign runs with a two-hero route per world as acceptance.

### 5.3 Memory

- Hero sheets: 4 x 1408 x 784 RGBA (`assets/sprites/player/hero*.png`) = ~17.7 MB VRAM, shared by every hero
  instance (same resources). Player colours by a palette-swap shader (one shared `ShaderMaterial` + a 16 x 1 LUT per
  slot): +0 MB. Pre-baked recoloured sheets would cost +17.7 MB per extra colour (+53 MB for 4 players) against the
  96 MB-per-level texture budget - do not bake.
- Per hero: nodes and state well under 1 MB; `PlayerRun` objects trivial; versus arenas are small.

### 5.4 Mobile and device input

- Touch: two players fit only on tablets (duo layout); phones need pads for P2+. Touch targets >= 56 art px
  (ARCHITECTURE 11) make the duo layout tight on 8" tablets.
- Android pad ids change on reconnect; Bluetooth pads can sleep mid-level -> pause + re-join dialog.
- Shared keyboards: all keyboards are device 0 in Godot (two USB keyboards cannot be told apart); membrane keyboards
  ghost with 3+ simultaneous keys in some combinations -> defaults on separate key groups, a keyboard test in the
  options, pads recommended.
- `GameInput.vibrate` today rumbles every pad (`game_input.gd:193-194`).

### 5.5 Contracts and content

- ARCHITECTURE 1.2 freezes public signatures and lets only the owner of a base file add members: the PlayerSet
  touches six owners' base files at once, so wave 0 needs one engineer with an agreed temporary waiver (section 6).
- `Defs.Phase` values are frozen: party steps live in `PartyDriver` registration order, not in new phases.

### 5.6 Route-proof matrix

Single-player already has one route per (stage, difficulty, weapon a run can bring): 72 files for 15 stages. Co-op
with per-hero weapons would need (stage x difficulty x weapon pair) - up to 16 pairs per stage. Options for the
game designers: co-op weapons are a team pick-up (both heroes switch together: same matrix as solo), or co-op stages
reset to the club at each world (one pair per stage). Recommendation: team weapon in co-op, so the matrix stays one
route per (stage, difficulty, weapon) and every co-op route is recorded with two real players.

---

## 6. Ownership and sequencing

### 6.1 Wave 0 - one engineer, first, blocking (the "N = 1 identity" contract)

Done by one person (core lead, with a time-boxed waiver to edit the base files of player / enemies / objects /
world; module owners review), in small steps, each proven by the digest diff + full suite (4.12):

1. Freeze evidence (4.12 step 1); fix `sim_bench_runner.gd:427`; digest frozen for a party of one.
2. `Defs` appends: `MAX_PLAYERS`, `GameMode`, `InputSlotKind`, `hitter_slot()`; `Tuning` appends (bubble, revive,
   leash timings); `Events` `hero_*` twins and party signals.
3. `PlayerRun`, `Game.runs` / `party` / `mode`, property aliases, delegating methods.
4. `GameInput` slots (`slot_flags`, `get_flags`, `set_scripted_slot`, per-slot latch/touch), `InputSlot`, generated
   `pN_*` actions, Settings per-slot binding storage.
5. `LevelBase` PlayerSet (heroes, starts, `target_hero`, `contact_order`, views, union `on_screen`, N-rect doze,
   shake guard, death routing hooks, `notify_hero_teleported`).
6. Mechanical conversion of every "the hero" reader of section 3 to the target / every / P1 idioms (bases, Player,
   archetypes, bosses, objects, zones) - **with no multiplayer behaviour yet**; `Audio.hold_music` API.
7. Harness: `parse_inputs_multi`, `run_party_inputs`, recorder, flow commands; `tests/test_core_players.gd` with the
   digest fixtures.

Exit criterion: empty digest diff on every route (doze on and off), 575 + new tests green, a bare two-hero level
runs (both heroes move independently from two scripted streams).

### 6.2 Wave 1 - parallel, by module (ownership per ARCHITECTURE 1.1)

| Owner | Files | Work |
|---|---|---|
| core | `scripts/core/**` (scene_flow, save, level_registry, level_text, audio_manager, game_input, autoplay, dev/*), `project.godot`, `tests/test_core_*`, `tools/autoplay/**` | Flow modes (`start_coop_game`, `start_versus`, rounds), Save v2 + migration, mode-aware registry, feast music refcount, `VersusMatch`, bots (`HeroBot` input), recorder, flows, bench MP fields, perf acceptance runs |
| player | `scripts/player/**`, `scenes/player/**`, `scripts/base/player_base.gd`, `scripts/projectiles/hero_*.gd`, `tests/test_player_*` | slot runs, owned projectiles, per-hero `MAX_THROWN`, palette shader per slot, edge walls, down / bubble / revive states, stand-on / boost / carry / throw (hero side), versus hit reactions (stun, knock-back) |
| enemies | `scripts/enemies/**`, `scripts/bosses/**`, `enemy_base.gd`, `boss_base.gd`, `projectile_base.gd`, enemy / boss projectiles, `tests/test_enemies_*` | targeting and sleep rules, attribution hooks, bosses' multi-hero contacts and boxes, then the new co-op enemies and bosses of the design docs |
| objects | `scripts/objects/**`, `scripts/items/**`, `scripts/fx/**`, the six object bases, `tests/test_objects_*` | per-hero item effects, shared checkpoint, team exit / gate, per-hero platform guard, springs, columns, plates / levers / seesaw, `hero_start`, versus item spawner and arena items |
| world | `scripts/world/**`, `scripts/zones/**`, `scripts/base/level_base.gd`, `tools/validate_levels.gd`, `tests/test_world_*` | party spawn, group camera (`tick_group` / `snap_group`), multi-view plumbing, zone masks, arena / camera-lock team rules, `PartyDriver` (stacking, revive, team wipe) and `VersusReferee`, validator (`kind = arena`, starts, mode flags) |
| ui | `scripts/ui/**`, `scenes/ui/**`, `locale/**`, `tests/test_ui_*` | join screen, mode select, HUD player panels, pause per slot, options P2-P4 + keyboard test, touch duo layout, tally contributions, versus screens |
| level designers | `levels/*.lvl` | co-op variants (`<id>_coop.lvl`, `kind = coop`), 20 new stages (solo + co-op), arenas |
| integration / QA | `tests/test_campaign_routes.gd`, `tests/test_integration_*`, `tools/autoplay/routes/**` | co-op ROUTES table, recorded two-player routes, bot match replays, perf acceptance |

Critical path: wave 0 -> (player bubble / stacking + world group camera / PartyDriver) -> co-op level authoring ->
recorded co-op routes. Versus (arenas, referee, screens) can run in parallel with co-op once wave 0 is in.

---

## Appendix A - greps used (reproducible)

```
rg -n "level\.player|Game\.level\.player" scripts tests tools
rg -n "Kind\.PLAYER|PlayerBase" scripts
rg -n "_target_hero\(" scripts
rg -n "GameInput\.|set_scripted|clear_scripted|is_scripted|expand_runs|keys_to_flags" scripts tests
rg -n "Game\.(has_glider|set_glider|weapon|set_weapon|hearts|bones|lose_heart|lose_bone|add_bones|add_heart|scatter_energy|lives|lose_life|add_lives|score|add_score|letters|collect_letter|feast_kit|collect_feast_piece|set_checkpoint|has_checkpoint|checkpoint_pos|on_respawn|exit_unlocked|unlock_exit)" scripts
rg -n "on_screen" scripts
rg -n "get_view_rect\(\)|is_in_view\(|get_camera_cell\(\)|lock_camera\(|unlock_camera\(|snap_camera\(" scripts
rg -n "Events\.(player_[a-z_]+|feast_changed|glider_state_changed|level_respawned|exit_reached|gate_used)" scripts
rg -n "tick_shake_timer|_carried_on_tick|push_music|pop_music|Sim\.rng" scripts
```

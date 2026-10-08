# ARCHITECTURE.md - the binding module contract of Club & Grub

Godot 4.7.2, GDScript only, statically typed. This document and the files it calls **CONTRACT FILES** are the
only coordination between the six engineering modules (core, player, enemies, objects, world, ui), the level
designers and QA. If your code needs something that is not here, do not invent a private channel: build it inside
your own files, or report the missing API to the core owner.

Order of authority when two documents disagree:

1. `docs/spec/PHYSICS.md` (+ `PHYSICS_REFERENCE.json`) for every per-tick rule of the hero, tiles and camera.
2. `docs/spec/GAMEPLAY.md` for features, scoring, enemies, bosses, flow.
3. `docs/ASSET_MANIFEST.md` for every fact about files under `assets/` (frames, pivots, tile indices, audio).
4. This document for structure: who owns what, which API exists, the level file format, how things are wired.
5. The doc comments in the contract files are the exact, current signature reference (this document summarises).

Legal rule (hard): original game. No Prehistorik 2 / Titus assets or level data, no rips, no code copied from the
reference clones in `.tools/ref` (describe, never copy).

---

## 1. Ownership

### 1.1 Table (exact path globs)

A file belongs to exactly one owner. **Only the owner creates or edits it.** Godot writes a `.uid` file next to
every script and an `.import` file next to every asset: they travel with their file and have the same owner.

| Owner | Paths |
|---|---|
| **core** | `project.godot`, `default_bus_layout.tres`, `export_presets.cfg`, `.gitignore`, `.gitattributes`, `.editorconfig`; `scripts/core/**`; `scripts/base/sim_entity.gd`; `scenes/main.tscn`; `scenes/core/**`; `assets/audio/**/*.import` (settings only); `tests/run_tests.gd`, `tests/test_case.gd`, `tests/test_core_*.gd`; `levels/test_example.lvl`, `levels/test_core_*.lvl`; `docs/ARCHITECTURE.md`; build and release tooling: `tools/build_*`, `README.md`, `docs/BUILD.md`, `docs/PORTING.md`; integration (section 8.1): `levels/test_integration*.lvl`, `tests/test_integration_*.gd`, `tools/autoplay/**` |
| **player** | `scripts/player/**`; `scenes/player/**`; `scripts/base/player_base.gd`; `scenes/projectiles/hero_*.tscn`; `scripts/projectiles/hero_*.gd`; `tests/test_player_*.gd`; `levels/test_player_*.lvl` |
| **enemies** | `scripts/enemies/**`; `scenes/enemies/**`; `scripts/bosses/**`; `scenes/bosses/**`; `scenes/projectiles/enemy_*.tscn`, `scenes/projectiles/boss_*.tscn`; `scripts/projectiles/enemy_*.gd`, `scripts/projectiles/boss_*.gd`; `scripts/base/enemy_base.gd`, `scripts/base/boss_base.gd`, `scripts/base/projectile_base.gd`; `tests/test_enemies_*.gd`; `levels/test_enemies_*.lvl` |
| **objects** | `scripts/objects/**`; `scenes/objects/**`; `scripts/items/**`; `scenes/items/**`; `scripts/fx/**`; `scenes/fx/**`; `scripts/base/collectible_base.gd`, `scripts/base/hittable_base.gd`, `scripts/base/hazard_base.gd`, `scripts/base/checkpoint_base.gd`, `scripts/base/level_exit_base.gd`, `scripts/base/platform_base.gd`; `tests/test_objects_*.gd`; `levels/test_objects_*.lvl` |
| **world** | `scripts/world/**`; `scenes/world/**`; `scripts/zones/**`; `scenes/zones/**`; `resources/world/**`; `scripts/base/level_base.gd`; `tools/validate_levels.gd`, `tools/world_*`; `tests/test_world_*.gd`; `levels/test_world_*.lvl` |
| **ui** | `scripts/ui/**`; `scenes/ui/**`; `resources/ui/**`; `locale/**`; `assets/fonts/*.import` (settings only); `tests/test_ui_*.gd` |
| level designers | `levels/*.lvl` except `levels/test_*.lvl` |
| art (read-only for engineers) | `assets/**` except the `.import` files listed above; `docs/ASSET_MANIFEST.md`; `docs/art/**`; `CREDITS.md` |
| specs (read-only) | `docs/spec/**` |

`build/` (ignored by git and by Godot) is scratch space for everyone: screenshots, exports, test user data.

**2.0 "The Far Shore" (from phase 1 of `docs/expansion/PLAN.md` on).** The six modules above are split into the
sub-owners of PLAN.md 4.1; each glob below is that owner's exclusive write area (a file has exactly one owner per
phase; `.uid` / `.import` files travel with their file). During phase 0 the contract owner (core lead) held a
time-boxed waiver to edit the base files of every module; it closed with PLAN P0.10 (the exit level
`levels/test_core_party.lvl`, the guards of section 9.1, the identity proof): from phase 1 on every file has exactly
the owner below. The 15 Book I level files and the 72 route files under `tools/autoplay/routes/` belong to nobody:
they are frozen (`tests/fixtures/book1_hashes.txt`, guarded by `tests/test_core_book1_frozen.gd`).

| Owner | Exclusive globs |
|---|---|
| **core-A** (flow, save, registry, input, audio table) | `project.godot`; `scripts/core/**` except `scripts/core/bots/**`, `scripts/core/autoplay.gd`, `scripts/core/dev/**`; `scripts/base/sim_entity.gd`; `scenes/main.tscn`, `scenes/core/**`; `assets/audio/**/*.import`; `tests/test_core_*.gd` except `tests/test_core_bots*.gd`; `docs/ARCHITECTURE.md`, `README.md`, `docs/BUILD.md`, `docs/PORTING.md`, `tools/build_*` |
| **core-B** (bots) | `scripts/core/bots/**`, `tools/bots/**`, `tests/test_core_bots*.gd`, `tests/test_versus_bots.gd` |
| **integration** (core) | `scripts/core/autoplay.gd`, `scripts/core/dev/**`, `tools/autoplay/*.flow`, `tools/autoplay/*.inputs` (not `routes/`), `tests/test_campaign_routes.gd`, `tests/test_route_tools.gd`, `tests/test_integration_*.gd`, `tests/test_levels_*.gd`, `tests/test_fidelity_*.gd`, `tests/test_book2_routes.gd`, `tests/test_coop_routes.gd`, `tests/test_coop_gates.gd`, `tests/fixtures/**`, `levels/test_integration*.lvl`, `levels/test_core_*.lvl`; `tools/sp_identity.sh` |
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

Level designers (phase 3, PLAN.md 6.1):

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

The contract rules of 1.2 hold for every owner: after phase 0 a module that needs a new shared member files a request
with core-A (or the base file's owner) and keeps a private constant meanwhile; `Defs.Phase` values never change and
party work runs in drivers registered after the heroes (`LevelBase.register_party_driver`).

### 1.2 Rules for contract files

Contract files are `scripts/core/**`, `scripts/base/**`, `tests/test_case.gd`, `tests/run_tests.gd`.

- **Public signatures are frozen**: names, parameter types and order, return types, signals, public fields and
  the meaning documented in their comments. Nobody renames, removes or re-types them.
- The owner of a `scripts/base/*.gd` file may replace **bodies**, add private members (leading underscore) and add
  new public members. The bodies shipped with the skeleton are minimal but working on purpose (other modules test
  against them); a replacement must keep the documented behaviour.
- Need a new shared constant, signal, phase, event name or setting? It is added by **core** only. Until then keep a
  private constant in your module and list the request in your final report.
- No module edits another module's files, `project.godot` or `assets/`. Fix cross-module problems by reporting them.

---

## 2. Project configuration (`project.godot`)

| Setting | Value | Why |
|---|---|---|
| Name / version / main scene | `Club & Grub`, `1.0.0`, `res://scenes/main.tscn` | boot scene hands over to `scenes/ui/title.tscn` when it exists |
| User data dir | `user://` = `%APPDATA%/ClubAndGrub` (custom user dir) | stable across renames; save.json, settings.cfg |
| Renderer | `gl_compatibility` on desktop and mobile | maximum device coverage |
| Base viewport | **640 x 360 art px** = 320 x 180 logical px x `Tuning.ART_SCALE` (2) | ASSET_MANIFEST 1 |
| Default window | 1280 x 720, resizable | integer scale 2 |
| Stretch | mode `viewport`, aspect `expand`, scale mode `integer` | crisp pixels at every size; wider or taller screens show **more level**, never black bars |
| Texture filter | Nearest; `snap_2d_transforms_to_pixel = true` | pixel art |
| Fonts | antialiasing, hinting, subpixel positioning off | pixel fonts |
| Orientation | sensor landscape | phones |
| Physics ticks | 60 (engine default) - **not used by gameplay** | the simulation has its own 24.2753 Hz clock, section 4 |
| Autoloads (in this order) | `Settings`, `Save`, `Events`, `Game`, `Levels`, `GameInput`, `Sim`, `Audio`, `Flow`, `Autoplay` | section 3 |
| Input actions | `move_left`, `move_right`, `move_up`, `move_down`, `jump`, `attack`, `look`, `pause`, plus `ui_accept` / `ui_cancel` redefined with a gamepad button; other `ui_*` actions keep Godot's defaults (keys, d-pad, stick). 2.0: `swap` (the weapon belt, sampled into `Defs.IN_SWAP`, ignored by Book I solo) | every action has keyboard and gamepad events; touch feeds the same actions. Party slots read generated `p1_*`..`p4_*` copies (3.7); single-player never generates them |
| 2D physics layer names | 1 world, 2 player, 3 enemies, 4 items, 5 objects, 6 hazards, 7 platforms, 8 hero_weapons, 9 enemy_projectiles, 10 triggers | cosmetic use only, section 5.5 |
| Audio buses | `Master` <- `Music`, `Master` <- `SFX` <- `UI`; a hard limiter (ceiling -0.5 dB) on `Master` | `default_bus_layout.tres`; per-file volumes are measured (ASSET_MANIFEST 13.4) |
| GDScript warnings | `untyped_declaration` = warn | all code is statically typed |

Default bindings:

| Action | Keyboard | Gamepad |
|---|---|---|
| move_left / right / up / down | arrows, A D W S | d-pad, left stick (dead zone 0.5) |
| jump | Z, K (and Up / W while "Up jumps" is on) | A (south) |
| attack | Space, X, J | X (west), B (east) |
| look | C, L, keypad 5 | Y (north), RB |
| pause | Escape, P | Start |
| swap (2.0) | V, `;` (route key `S`) | LB (dead zone 0.5); touch: the Y stone |
| ui_accept / ui_cancel | Enter, keypad Enter, Space / Escape | A, Start / B (Start pauses in play and confirms the focused pause-menu entry) |
| fullscreen (desktop only, not rebindable) | Alt+Enter, Alt+keypad Enter, F11 | - |

Party keyboards (2.0, DESIGN.md D.11): the shared setting `controls/party_keyboard` = `classic` (WASD + numpad, the
versus default) | `two_hands` | `one_hand` gives P1 the left and P2 the right half of one keyboard
(`InputSlot.default_keys`); P3 / P4 use pads. Per-slot changes are stored in `[bindings_p1]`..`[bindings_p4]` (3.6).

The fullscreen shortcut works on every screen, the pause menu included (`Settings._input`, process mode always):
it flips `video/fullscreen` exactly like Options > Fullscreen (the Options row follows) and saves the settings at
once. The key press goes no further, so Alt+Enter never also "accepts" a menu entry.

**The visible area is not constant.** With integer scaling the root viewport is `window / s` art px where
`s = max(1, floor(min(window_w / 640, window_h / 360)))`: exactly 640 x 360 at 1280x720, 1920x1080, 2560x1440,
but 800 x 360 on a 2400x1080 phone and about 682 x 512 on a 4:3 tablet. Consequences:

- ui: anchor everything to corners / edges / centre and respect the display safe area; never assume 640 x 360.
- world: derive visible columns and rows from the real viewport every time it changes (section 8.5).
- nobody: hard-code `640`, `360`, `320` or `180`. Use `Tuning.VIEW_W / VIEW_H` only as the design reference.

Exports (`export_presets.cfg`, `docs/BUILD.md`): presets `Windows Desktop` (one self-contained .exe), `macOS`
(universal), `Android` (arm64-v8a + armeabi-v7a) and `iOS`. Level files are plain text, not Godot resources, so
every preset includes `levels/*.lvl` (plus `CREDITS.md`, `assets/licenses/*`) and excludes the development files:
`tests/*`, `tools/*`, `docs/*`, `build/*`, `levels/test_*.lvl`, the debug level, `resources/ui/*.py` (font
generator) and **every folder named `dev`** (`*/dev/*`: put previews and other development-only scenes there; the
autoplay flow runner `scripts/core/dev/autoplay_flow.gd` lives in one). Nothing a shipped scene needs may live in such
a folder. `tests/test_core_release.gd` checks the filters; a smoke run of an exported build reports any
development file it finds inside itself (section 9.2).

---

## 3. Core contract (already implemented; call it today)

Every item below exists in the repository with full doc comments. Signatures in the files are authoritative.

### 3.1 `SimEntity` (`scripts/base/sim_entity.gd`) - base of every gameplay object

`extends Node2D`. Fields: `sim_pos: Vector2i` (feet point, logical px), `sim_prev`, `xvel`, `yvel` (v16),
`facing` (+1 / -1), `box_w`, `box_h`, `box_xo`, `sim_active`, `on_screen`, `spawn_params`, `spawn_pos`.

Override: `get_kind() -> int` (a `Defs.Kind`), `_sim_phases() -> PackedInt32Array`, `_sim_tick(phase: int)`,
`_apply_params(params: Dictionary)`, `_on_level_reset()`.
Use: `spawn_setup(pos, params)` (called by the level before the node enters the tree), `teleport(pos)`,
`get_box()`, `set_box(Vector3i(w, h, xo))`, `box_left()`, `box_top()`, `cell_col()`, `cell_row()`,
`param_int / param_bool / param_str`.

Registration with `Sim` and with the level, and the per-frame interpolation of `position`, happen in
`_notification`, which Godot delivers to every script level: **subclasses may override `_ready`, `_enter_tree`,
`_exit_tree`, `_process` freely and need not call `super`** for those. Never write `position`.

Dozing (section 11): `is_dozing()`; override `_doze_area() -> Rect2i` and `_can_doze() -> bool` (optional hooks
`_on_doze()`, `_on_doze_wake()`), call `_doze_note()` when the entity may have become idle and `_doze_wake_now()`
before anything makes its ticks matter again (a hit, an opening). The contract is in the comment block of
`sim_entity.gd`; collectibles, enemies, hittables, checkpoints, exits, zones, signs, springs, gates and rising
columns implement it.

### 3.2 `TileGrid` (`scripts/core/tile_grid.gd`) - collision grid

`TileGrid.from_rows(rows, ice_a, ice_b, letter_tiles)`, `floor_at / side_at / flags_at / ceiling_at / profile_at
(col, row)`, `has_profile`, `surface_offset(col, row, x)`, `get_char`, `set_char`, `set_props`, `set_flag_bits`,
`width_px`, `height_px`, `x_max_excl`, constants `FLOOR_*`, `SIDE_*`, `CEILING_*`, `FLAG_*`, `PROFILE_*`, `CH_*`.
Semantics are those of PHYSICS.md 11.1 with one documented change: the original `HEIGHT` byte is a `profile` id
(our slopes are 45 degrees and half-gradient). `has_profile()` = "HEIGHT is non-zero"; apply the rules of
PHYSICS.md 11.2 unchanged. Flat floor cells at the foot of a slope get `PROFILE_FLAT_GLUE` automatically.
2.0 (level format 2, 7.11): `CH_TAR` (`:`, the tar floor: '#' with `PROFILE_TAR` = `PROFILE_LOWERED_BASE + 6` and
the TAR material), a fifth per-cell table `material_at(col, row)` (`MATERIAL_NONE`, `MATERIAL_TAR`) and
`is_tar(col, row)`; `LEGEND_CHARS` includes `:`. A format-1 level builds exactly the 1.0 tables (fixture
`tests/fixtures/book1_grid_hashes.txt`). P2.12 (player-B's A53 pass): `has_tar() -> bool` (any `:` cell, one native
search; `set_char` keeps it current) - HeroClimb asks it once per level load.

### 3.3 `Overlap` (`scripts/core/overlap.gd`) - the sprite-overlap test of PHYSICS.md 2.2

`Overlap.body(a, b, hero) -> bool` (sets `Overlap.stomp`, `Overlap.depth`), `Overlap.weapon(box, x_offset,
target)`, `Overlap.weapon_entity(projectile, target)`, `Overlap.test(...)` (raw), `Overlap.rects(a, b)`,
`Overlap.point_in(rect, x, y)`. Argument order: hero first in hero-vs-enemy and hero-vs-platform tests, the item
first in item-vs-hero tests, the weapon first in weapon tests. **All sprite contacts use this class; no Area2D,
no `Rect2i.intersects`, no physics queries.**

### 3.4 `Events` autoload - gameplay event bus (signals only)

Hero: `player_spawned`, `player_hurt(kind, source)`, `player_died(cause)`, `player_death_finished`,
`player_landed(hard, shake)`, `player_jumped`, `player_struck(strike, weapon)`, `player_bounced(target,
multiplier)`, `glider_state_changed(carrying, gliding)`.
Enemies: `enemy_hit`, `enemy_killed(enemy, points, cause)`, `boss_started`, `boss_energy_changed(boss, pips,
max_pips)`, `boss_defeated`.
Items / objects: `item_collected(item_id, index, points, pos)`, `hittable_hit`, `hidden_spot_opened`,
`secret_found`, `checkpoint_activated`, `exit_unlocked`, `exit_reached(exit_kind)`, `gate_used`.
Level: `shake_requested(amount)`, `feast_changed(ticks)`, `darkness_changed`, `popup_requested(kind, value, pos)`,
`wind_changed`, `time_left_changed(seconds)` (the level's time limit shows another second; -1 = no limit),
`message_requested(source, text)` (a `zones/message` hint for the HUD; empty text withdraws it),
`level_started`, `level_completed`, `pause_changed`, `level_respawned`, `game_over`.

Use the bus for fan-out to HUD, audio, FX, statistics. **Nothing the simulation depends on goes through it**:
state changes are direct method calls on the base-class APIs, so the order of operations stays deterministic.

2.0 (emitted right after their 1.0 signal, hero first): `hero_hurt(hero, kind, source)`, `hero_died(hero, cause)`,
`hero_death_finished(hero)`, `hero_landed(hero, hard, shake)`, `hero_jumped(hero)`, `hero_struck(hero, strike,
weapon)`, `hero_bounced(hero, target, multiplier)`, `hero_glider_state_changed(hero, carrying, gliding)`,
`hero_feast_changed(hero, ticks)`. Party: `hero_down(hero, cause)` (an egg, `PlayerBase.go_down`), `hero_revived(hero,
by)` (`PlayerBase.hatch`), `party_wiped`, `hero_ko(victim, killer, cause)`. Versus rounds: `round_countdown(round_index,
count)`, `round_started(round_index)`, `round_feast_rush_started(round_index)`, `round_sudden_death_started(round_index,
kind)`, `round_ended(round_index, winner_slots: PackedInt32Array)`. Meta: `painting_found(index)`. The 1.0 signals
keep meaning "the hero" and are still emitted for every hero.

### 3.5 `Game` autoload - run state

Fields: `difficulty`, `score`, `lives`, `hearts`, `bones`, `letters`, `feast_kit`, `weapon`, `has_glider`,
`exit_unlocked`, `level_id`, `level: LevelBase`, `warp_return_level`, `has_checkpoint`, `checkpoint_pos`,
`spots_total / spots_opened`, `items_total / items_collected`, `secrets_found`, `tally_item_ids / _indices /
_points`.
Methods: `new_game(difficulty)`, `begin_level(id, carry_progress)`, `add_score(points)`, `add_lives`,
`lose_life() -> bool`, `add_bones(n) -> int`, `add_heart() -> bool`, `lose_heart() -> bool` (true = dead),
`lose_bone() -> bool`, `scatter_energy() -> int`, `collect_letter(i) -> bool`, `collect_feast_piece(i) -> bool`,
`set_weapon`, `set_glider`, `unlock_exit`, `set_checkpoint(pos)`, `on_respawn()`, `add_completion_totals(spots,
items)`, `count_spot_opened()`, `count_item_collected()`, `completion_percent()`, `add_tally_item`, `clear_tally`,
`tally_count`, `is_full_energy`, `restore_level_entry() -> bool` (the run as `begin_level` found it: score,
letters, feast kit, weapon, counters, tally; lives only downwards - used by `Flow.restart_level`, so a restart
neither costs nor earns anything).
Signals: `score_changed`, `lives_changed`, `energy_changed(hearts, bones)`, `letters_changed(mask)`,
`letters_completed`, `feast_kit_changed`, `weapon_changed`, `glider_changed`, `completion_changed(percent)`,
`extra_life_awarded`, `checkpoint_changed`, `run_started`.
Scores are displayed points. Extra life every 250 000, cap 99. A hit at 0 hearts kills.

2.0 (PLAN.md P0.4): `runs: Array[PlayerRun]` (`Defs.MAX_PLAYERS`, always allocated, never replaced), `mode`
(`Defs.GameMode`, default SINGLE), `party` (1..4, default 1), `book` (1 / 2, default 1); `start_run(difficulty, mode =
SINGLE, party = 1, book = 1)` (`new_game(d)` = `start_run(d)`), `get_run(slot) -> PlayerRun`. `hearts`, `bones`,
`weapon` and `has_glider` are properties of `runs[0]`, and the frozen energy / weapon / glider methods delegate to it:
the field writes and the signal order of 1.0 are unchanged (`energy_changed` ... are emitted for slot 0 at the same
moment). Every slot reports through `run_energy_changed(slot, hearts, bones)`, `run_weapon_changed(slot, weapon)`,
`run_belt_changed(slot, belt)`, `run_glider_changed(slot, carrying)`. `begin_level`, `on_respawn` and
`restore_level_entry` also cover slots 1..party - 1. Shared team state (score, lives pool, letters, feast kit,
checkpoint, exit, completion, tally) stays in `Game`. A player's look lives in his run: `PlayerRun.palette` (a palette
name of `assets/sprites/player/palettes/hero_palettes.json`, `&""` = the slot default) and `PlayerRun.pattern` (a
loincloth pattern index, -1 = the slot default), written by the join panel / lobby, read by the hero's palette, the
HUD and the versus screens; `reset_run` keeps them.
P1.1 (core-A): `versus_match: VersusMatch` (the match being played or set up; `match` is a keyword), `party_runs() ->
Array[PlayerRun]` (slots 0..party - 1), `set_party(mode, party)` (a join or leave during a run: score, lives and kept
runs stay, a joining slot starts like a new run's hero and reports through `run_*_changed`). `begin_level` zeroes the
party's statistics when a co-op stage starts afresh (`carry_progress` false); single-player never.
P2.6 (core-A): `tally_item_slots: PackedInt32Array` (who picked each tally item, parallel to the three tally arrays;
`add_tally_item(id, index, points, slot = 0)`; saved in the level entry; always 0 in single-player) and `helper_mode:
bool` (Options > Co-op Helper mode, DESIGN.md D.3: copied from Settings `coop/helper_mode` by Flow when a co-op run
starts or a partner joins - the simulation reads this, never Settings; false in single-player, versus and every
recorded route; `start_run` clears it; the rule is player-A's). Settings: `coop/rival_score`, `coop/helper_mode`
(both false).
`PlayerRun` (`scripts/core/player_run.gd`, `RefCounted`): `slot`, `hearts`, `bones`, `weapon` (the hand), `belt`
(`BELT_EMPTY` = -1), `has_glider`, stats `score`, `kills`, `deaths`, `revives`, `picked`, `stocks`; the 1.0 bodies of
`add_bones`, `add_heart`, `lose_heart`, `lose_bone`, `scatter_energy`, `is_full_energy`, `reset_energy`,
`set_weapon` (0..`Defs.Weapon.SPEAR`), `set_glider`; belt primitives `set_belt`, `swap_belt() -> bool`, `special() ->
int`, `take_fresh_club()`; `emit_energy / emit_weapon / emit_belt / emit_glider`, `reset_run`, `reset_stats`; signals
`energy_changed`, `weapon_changed`, `belt_changed`, `glider_changed`.
Medal and award counters (P1.1; DESIGN.md D.11 co-op tally, E.8 versus results; the module that sees the deed adds to
them, nothing in the simulation reads them): `food`, `best_chain`, `hurts`, `bats`, `plates`, `pushes`, `hits`,
`stolen`, `dropped`, `best_stack`, `clangs`, `best_shot`, `passes`, `hazards`, `bonks`, `comeback` (written by
`VersusMatch.finish`); `note_chain(n)`, `note_stack(units)`, `note_shot(px)` keep the longest; `STATS` (every counter,
`get_stat(name)`), tables `COOP_MEDALS` (most_food, best_bounce_chain, hatchling, slugger, strongman, clumsiest) and
`VERSUS_AWARDS` (leaning_tower ... pacifist, `fewest` = the lowest wins) of `{id, stats}`; `award_value(award)`,
`static award_winners(runs, award) -> PackedInt32Array` (ties share; nobody wins with nothing done),
`static medals(runs, table = COOP_MEDALS) -> {id: slots}`. P2.6: `to_dict() -> Dictionary` / `from_dict(data)` (every
field - energy, hand, belt, glider, every `STATS` counter, the look - as plain data, no signal; the deciding-moment
replay keeps a round's start and end with them).

`VersusMatch` (`scripts/core/versus_match.gd`, RefCounted, P1.1; DESIGN.md E.3-E.8, TECH_AUDIT.md 4.9): seats
(`seats[slot]: VersusMatch.Seat` with `kind` SeatKind EMPTY / HUMAN / BOT, `input`, `bot_level`, `team` 0 / 1 / 2,
`palette`, `pattern`, handicap `hearts` / `stack_guard` / `auto_handicap`, `ready`; `seat_human(input, slot = -1)`,
`seat_bot(level, slot = -1)`, `unseat`, `is_seated`, `is_bot`, `get_seat`, `player_count`, `human_count`,
`seated_slots`, `compact_seats`, `is_team_match`, `teammates`, `can_start`, `ready_all`, signal `seats_changed`);
rules (`mode` Defs.VersusMode, `preset` Preset CLASSIC / FEAST / MAYHEM, `rounds_to_win`, `round_seconds`, `crates`,
`weapons`, `variants`, `sudden_death`, `stock`, `arena` = an id or `ARENA_RANDOM` / `ARENA_PARTY_MIX`, `rules_owner`;
`round_wins_needed(mode)`, `round_ticks(mode)` (0 = no clock), `crate_period_ticks`, `has_variant`, `rules_to_dict` /
`rules_from_dict`, `remember_rules` (Settings `versus/last_rules`), `static from_settings()`); arenas
(`static available_arenas(players, mode)` without the locked `LOCKED_ARENAS` until their Save reward,
`static arena_modes(id)`, `arena_for_round(i)`, `mode_for_round(i, arena)` - picks from the match's own SimRng, never
Sim.rng); the match (`match_seed`, `round_index`, `round_open`, `round_arena`, `round_mode`, `round_wins`, `history`
[{arena, mode, winners}], `bots` (the HeroBot per bot seat); `begin_match(seed)`, `begin_round(arena)`, `round_seed()`
= VersusTuning.round_seed, `bot_seed(slot)`, `spawn_index(slot)` (1-based, rotates every round), `record_round(winners)
-> bool`, `is_over`, `leaders`, `rematch`, `finish(runs)` (Comeback Caveman), `hand_out_awards(runs) -> {slot:
Array[StringName]}` (1-3 each)); `static var bot_factory` (a test / tool flags source replacing HeroBot), `HERO_BOT_PATH`.
P2.6 (core-A): `replay: VersusReplay` (the recording of the current / last round, made by `Flow.start_round`);
`VARIANT_NAMES` (the E.4 variant names; world-B's `VersusRules.VARIANTS` applies them), `static variant_choices() ->
[{name, open, paintings}]` (the rules screen: a closed variant shows the paintings it still needs), `static
open_variants(names)`; `begin_match` drops closed, unknown and repeated variants from the remembered rules; `static
arena_paintings_needed(id) -> int` (0 = open; the arena screen's count); `available_arenas` also asks
`UnlockTable.is_arena_open`.
`VersusReplay` (`scripts/core/versus_replay.gd`, RefCounted, P2.6; DESIGN.md E.8 step 5): the deciding moment of one
round - the input log (`log_tick(tick, flags)`, `flags_at(tick, slot)`, `ticks`; bots are logged like humans), the
start snapshot (`arena`, `seed_value`, `players`, `round_index`, `round_mode`, `round_wins`, `start_runs`;
`apply_start_state(match)`), the end snapshot (`finish(tick, runs)`, `end_runs`), the biggest steal (`note_tick(tick,
runs)` from `PlayerRun.stolen`: `steal_tick`, `steal_units`, ties = the later one) and the window (`window() ->
Vector2i(first, last)`: the `DECIDING_TICKS` = 73 before the gong; Grub Stack: the 73 ending `STEAL_LEAD_OUT_TICKS` =
24 after the biggest steal; `shows_steal()`, `can_replay()`); `REPLAY_SPEED` 0.5; `static begin(match, arena, seed,
runs)`, `static snapshot_runs(runs, n)`, `static restore_runs(snapshots, runs)`. Never draws from Sim.rng.
`UnlockTable` (`scripts/core/unlock_table.gd`, static data, P2.6; DESIGN.md C.9, GAMEPLAY.md 13.2 / 13.7): the Cave
Painting table every module asks - `PAINTING_LEVELS` (index -> solo level: 0-19 Book II in A.2 order, 20-29 the Book I
co-op secrets), `COOP_ONLY_FROM`, `painting_level(i)`, `is_coop_only(i)`, `painting_file(i, mode)` (`<id>_coop` in
co-op; "" where a mode cannot find it), `paintings_of(level_id)`; `REWARDS` (the ladder 5 / 10 / 15 / 20 / 25 / 30:
`id` = Save.UNLOCK_*, `paintings`, `text` key, and what it opens - `arenas`, `variants`, `patterns` (the `unlock` tags of
hero_palettes.json), `palettes`, `mural`), `reward(id)`, `paintings_needed(id)`, `is_open(id)` (= Save.is_unlocked),
`open_rewards()`, `rewards_between(before, after)`, `next_reward() -> {id, missing}`, `reward_of_arena / _variant /
_palette / _pattern`, `is_arena_open`, `is_variant_open`, `is_palette_open`, `is_pattern_open`, `is_mural_open`.

### 3.6 `Settings` and `Save` autoloads - persistence (`user://`, versioned)

`Settings` (`settings.cfg`, ConfigFile, `VERSION = 1`): `get_value / get_bool / get_float / get_int`,
`set_value(key, value)` (applies at once, emits `changed`), `rebind(action, events)`, `reset_bindings()`,
`reset()`, `load_settings()`, `save()`, `set_storage_dir()`. Keys: `audio/master`, `audio/music`, `audio/sfx`
(linear 0..1), `video/fullscreen`, `video/vsync`, `video/screen_shake`, `video/flash`, `controls/up_jumps`,
`controls/touch_always`, `controls/touch_opacity`, `controls/touch_scale`, `controls/touch_layout` (`standard` |
`swapped`, the mirrored left-handed layout), `controls/vibration`,
`camera/smooth_follow`, `game/locale`, `game/last_difficulty`.

Bindings (options screen): only the game actions `Defs.GAME_ACTIONS` are rebindable; `ui_*` keep Godot's
defaults. `get_bindings(action, device)` (device `Defs.Device.KEYBOARD` / `GAMEPAD`, slot order),
`get_default_bindings(action)`, `is_bindable(event)` (key press, pad button, stick / trigger past 0.5),
`set_binding(action, event, slot) -> StringName` (replaces that slot of the same device family; an event another
game action used is swapped into that action's slot - the returned action name - so no event is ever on two
actions), `reset_binding(action)`, `reset_bindings()`, `has_custom_bindings()`, `event_label(event)` (short English
name such as "Z", "Pad A", "Left Stick Up"), `event_device(event)`, `normalize_event / encode_event /
decode_event`. Keys bind by physical position. Changed actions are saved as text tokens in `[bindings]`
(`jump=PackedStringArray("key:88", "joy_button:0")`); unchanged actions follow the project defaults; invalid
entries are ignored. `changed` reports bindings as key `Settings.BINDINGS_KEY` with the action name as value.

`Save` (`save.json`, `VERSION = 1`, atomic write with backup, never blocks the game): `load_game()`,
`save_game()`, `reset()`, `has_progress()`, `is_level_unlocked(id, difficulty)`, `unlock_level`,
`get_unlocked_levels`, `record_level_result(id, difficulty, score, percent)`, `get_level_result`,
`get_high_score`, `submit_score`, `is_game_completed`, `set_game_completed`, `add_code_stone`, `has_code_stone`,
`add_stat`, `get_stat`, `set_storage_dir()`. There are no mid-level saves and no continues (GAMEPLAY.md 12.4).

2.0 Settings: per-slot binding profiles in `[bindings_p1]`..`[bindings_p4]` (same tokens and exchange rules as
`[bindings]`; `SLOT_BINDINGS_SECTION`, `slot_bindings_section(slot)`), `get_slot_bindings(slot, action, device = -1,
half = -1)`, `rebind_slot`, `set_slot_binding(slot, action, event, index = 0, half = -1) -> StringName`,
`reset_slot_binding(slot, action, half = -1)`, `reset_slot_bindings(slot = -1)`, `has_custom_slot_bindings(slot)`; key
`controls/party_keyboard` (`PARTY_KEYBOARD_KEY`, `classic` | `two_hands` | `one_hand`; `party_keyboard_layout()`;
classic by default: the versus default, offered first in co-op). P1.1: key `versus/last_rules` (Dictionary,
VersusMatch.rules_to_dict).
2.0 Save (`VERSION = 2`, a 1.0 file migrates into (single, book 1); a 2.0 file written again by 1.0 is merged):
progress per namespace `Save.space(mode, book, difficulty)` (`"single/book1/beginner"`, `get_spaces()`, consts
`SPACE_MODES`, `BOOKS`) with the twins `is_level_unlocked_in`, `unlock_level_in`, `get_unlocked_levels_in`,
`record_level_result_in`, `get_level_result_in`, `get_high_score_in`, `submit_score_in`, `is_game_completed_in`,
`set_game_completed_in` (the 1.0 methods act on (single, book 1)); carried weapons `get_belt_in(space, slot) -> {hand,
belt}`, `set_belt_in(space, slot, hand, belt)`; profile-wide Cave Paintings `add_painting(index) -> bool`,
`has_painting`, `painting_count`, `get_paintings()`; unlocks `is_unlocked(reward)`, `unlock(reward)`,
`set_unlock_everything(on)`, `is_unlock_everything()` (`UNLOCK_*`, `UNLOCK_PAINTINGS`, `UNLOCK_EVERYTHING_REWARDS`).
P2.6: signal `reward_unlocked(reward)` - `add_painting` announces each reward its painting opened (once, in ladder
order; never one already open by `unlock()` or "Unlock everything"): the HUD / map "new reward" notice.
save.json v2: `{version, high_score, code_stones, stats, paintings, unlocks{all, rewards}, spaces{<key>: {unlocked,
results, completed, high_score, belt}}}`.

### 3.7 `GameInput` autoload - input abstraction

`GameInput.flags` is the bit mask of `Defs.IN_FIRE | IN_DOWN | IN_UP | IN_LEFT | IN_RIGHT | IN_LOOK`, sampled
once per tick by `Sim`, with presses latched (PHYSICS.md 15.4). `Tuning.STATE_LUT[flags & Defs.IN_STATE_MASK]` is
the state table of PHYSICS.md 4.3. API: `is_held(mask)`, `just_pressed(mask)` (cosmetic only), `prev_flags`,
`enabled`, `device` (`Defs.Device`), signal `device_changed`, `set_touch(action, pressed)`, `clear_touch()`,
`set_scripted(callable)`, `clear_scripted()`, `keys_to_flags("RU")`, `expand_runs(runs)`, `get_glyph_set()`,
`wants_touch_controls()`, `vibrate(ms)`.
**Gameplay code never calls `Input.*` and never handles InputEvents.** UP flag = `jump`, or `move_up` (always
while the setting `controls/up_jumps` is on, otherwise only together with `attack`).

2.0 slots (PLAN.md P0.5): four input slots; `flags` / `prev_flags` are slot 0 and are sampled exactly as in 1.0.
`slot_flags`, `prev_slot_flags`, `slot_devices` (PackedInt32Array x4), `slots: Array[InputSlot]`, signal
`slot_device_changed(slot, device)`, `get_flags(slot)`, `get_prev_flags(slot)`, `is_slot_held`, `slot_just_pressed`,
`get_slot`, `assign_slot(slot, InputSlot)`, `reset_slots()`, `is_party_input()`, `static slot_action(slot, action)`
(`&"pN_action"`), `set_touch_slot(slot, action, pressed)`, `set_scripted_slot(slot, source)`,
`clear_scripted_slot(slot)`, `is_slot_scripted(slot)`, `event_slot(event) -> int`, `vibrate_slot(slot, ms, strength)`,
`SLOT_ACTION_DEADZONE`. `clear_scripted` / `clear_touch` cover every slot; `is_scripted()` is true when any slot is.
The `swap` action sets `Defs.IN_SWAP` (64, outside `IN_STATE_MASK`); `keys_to_flags("S")` = `IN_SWAP`.
`InputSlot` (`scripts/core/input_slot.gd`): `kind` (`Defs.InputSlotKind`), `device_id`, `region`, `source`;
factories `all_devices()`, `keyboard(kind)`, `pad(device_id)`, `touch(region)`, `bot(source)`; `KeyboardLayout`
(`CLASSIC`, `TWO_HANDS`, `ONE_HAND`) with the default keys of DESIGN.md D.11 (`default_keys`, `default_events`,
`default_pad_events`, `project_events`, `default_half`).
P1.1: the presets as data - `InputSlot.MENU_ACTIONS`, `menu_keys(layout, half, ui_action)` (classic P1 W / S / Space /
Q, P2 Num 8 / Num 5 / Num 0 / Num .), `NUMPAD_KEYS`, `uses_numpad(layout, half)`, `is_numpad_key(key)`;
`GameInput.keyboard_presets()` (static: per layout `layout`, `id`, `name`, `left` / `right` {action: keys},
`menu_left` / `menu_right` {ui action: keys}, `numpad`), `keyboard_layout()`, `set_keyboard_layout(layout)`,
`set_menu_clusters(on)` / `has_menu_clusters()` (both clusters' menu keys added to Godot's ui_* actions while a party
screen shows; off removes exactly them), `event_half(event)`, `join_input_for_event(event) -> InputSlot` (a Jump of a
keyboard half or a pad: "press Jump to join"), `find_input(input) -> int`, `current_device_input(partner)` (the single
player's device as a party input). NumLock: Godot 4.7.2 on Windows reports the numpad's physical keycode (`KEY_KP_*`,
from the scancode) with NumLock off too - only `keycode` becomes the navigation key - so the classic layout's physical
bindings need no alias (verified with the NumLock-off WM_KEYDOWN messages posted into a running window,
`scenes/core/dev/key_probe.tscn`, a dev probe that logs every key event; excluded from exports by `*/dev/*`).
P2.6 (resolution after G1): the classic layout's P1 strike is **Left Ctrl** (was Left Shift; P1 W A S D, Space jump,
E swap, Q look and P2's numpad are unchanged). Windows with NumLock on wraps a numpad key pressed while Shift is held
in a synthetic Shift release and re-press, which cut P1's held strike whenever P2 moved; Godot reports the synthetic
events exactly like real ones (physical `KEY_SHIFT`, left location - only the message timing and the NumLock state,
which Godot does not expose, differ), and a real `SendInput` sequence could not be recorded on the build desktop (the
probe never got the foreground), so no filter can be proven and Shift is not kept as an alias. Ctrl has no such
quirk. Bindings keep no key side, so Right Ctrl also strikes for P1 in this layout (nobody else uses it there). Note
for P4.3 (devices): on macOS with two input sources Ctrl + Space is the system's "previous input source" shortcut
(P1's charged jump); the options rebind P1's strike if that bites. Revisiting the alias needs a real recording: on the
P4.3 device check a person runs the key probe, holds Left Shift with NumLock on and presses Num 4 - the log stamps
each event with its frame and usec. The one sign Godot does carry is that a numpad key Windows treats as shifted
arrives with a navigation keycode (`KEY_LEFT` with physical `KEY_KP_4`) right after the synthetic release, in the same
frame; a filter built on that would also swallow a real Shift release made in the same frame as a numpad press with
NumLock off, so it may only ship with a test replaying such a recorded sequence (the resolution's condition).
`tests/test_core_input_presets.gd` proves the Ctrl strike survives the modelled synthetic sequence.
`GameInput.get_scripted_slot(slot) -> Callable`
(P2.6: the script driving a slot, Callable() for none; Flow gives it back after a replay).

### 3.8 `Levels` autoload - level registry

Scans `res://levels/*.lvl`; no hand-maintained list. `has_level`, `all_ids`, `get_level_path`, `get_level_meta`,
`get_value(id, key, default, difficulty)` (applies `.beginner` / `.expert` variants), `get_campaign(difficulty)`,
`first_level`, `is_available`, `next_level`, `has_locked_successor`, `parent_level(id, difficulty)` (the map stop a
linked `sub` level belongs to: its result is recorded there and the campaign continues after it),
`find_by_password(code)` (case-insensitive; the look-alike letters O and I are read as 0 and 1, see
`normalize_code`), `get_password`, `rescan()`. Syntax lives in `LevelText` (`scripts/core/level_text.gd`): `split_sections`, `parse_value`,
`parse_key_values`, `parse_meta`, `parse_params`, `parse_legend_line`, `parse_legend`, `legend_tiles`,
`parse_entity_line`, `cell_to_feet`, `applies_to`, `to_list`, `to_int_list`, `to_rect_px`, `problems`, `quiet`.

2.0 (level format 2, 7.11; PLAN.md P0.7). Registry: `FORMAT_VERSION` stays 1 (the 1.0 files); `FORMAT_2`, `FORMATS`;
`KIND_COOP`, `KIND_ARENA`; `BOOK_1`, `BOOK_2`. Every campaign query works inside the book of the level it is asked
about; the 1.0 calls without a book are Book I, so the Book I files answer exactly as in 1.0 whatever lies beside
them: `get_campaign(difficulty, book = 1)`, `first_level(book = 1)`; `next_level`, `has_locked_successor`,
`parent_level` follow the level's book. `kind = coop` and `kind = arena` files never appear in a solo query (not in a
campaign, not as the level that links to a sub-stage, never behind a code). New: `get_book(id)` (0 = unknown),
`get_level_kind(id)`, `get_belt_rule(id, difficulty = -1)` (`fresh` | `carry`), `is_solo_level`, `is_coop_level`,
`is_arena`, `get_coop_base(coop_id)` (its `coop_of`), `get_coop_level(solo_id)` (its co-op file, "" when none; a co-op
file answers itself), `get_coop_campaign(difficulty, book = 1)` (the stops replaced by their co-op files),
`level_for_mode(id, Defs.GameMode) -> StringName` (the file Flow starts for a level in a mode), `get_arenas(players =
0, mode = &"")`. A co-op file continues where its solo level continues (`next_level` returns co-op files; stops
without one are passed over) and records its result at the solo map stop (`parent_level` returns the solo id: co-op
progress is kept per solo stop in the co-op save namespace). LevelText: `FORMAT_1`, `FORMAT_2`, `FORMATS`, `BOOK_1`,
`BOOK_2`, `BOOKS`, `BELT_FRESH`, `BELT_CARRY`, `BELTS`, `KIND_COOP`, `KIND_ARENA`, `META_KEYS_2`, `STRING_KEYS`
(`coop_base_hash` always stays text), `default_belt(book, kind)`, `meta_book(meta)`, `meta_belt(meta, difficulty =
-1)`.

### 3.9 `Audio` autoload - sound by event name, music by context

`Audio.play_sfx(Sfx.CLUB_SWING)`, `play_sfx(event, variant, volume_offset_db)`, `start_loop / stop_loop /
stop_all_loops`, `play_music(Sfx.MUSIC_JUNGLE)`, `play_jingle(context, then_context)`, `push_music(context)` /
`pop_music()` (feast, boss: the interrupted track **continues where it was**), `stop_music`, `get_music_context`,
`get_music_position`, `stop_all_sfx`, `get_bus_volume`, `set_suspended(on)` / `is_suspended()` (Flow calls it
while the app is in the background: music and loops halt in place, effects are dropped), `shutdown`, signal
`music_changed`; `preload_sfx()` (every effect is loaded at boot: a first load inside a tick stalled it),
`preload_music(context)` and `retain_music(contexts)` (the level loads the tracks that may start inside a tick -
feast, boss - and releases every other track once its own music runs). Event and context names are the constants of `Sfx` (`scripts/core/sfx.gd`); files and
volumes are in `AudioTable`. **No other module loads or plays an audio file.** Calls are allowed inside a tick;
nothing is read back. In headless runs (tests, CI) streams are loaded and all state is tracked, but nothing is
actually started and jingles end at once.

2.0: `hold_music(context, holder: Object, fade_seconds = 0.2)`, `release_music(context, holder: Object, fade_seconds =
0.4)`, `is_music_held_by(context, holder) -> bool` (shared music such as the feast while any hero feasts; freed
holders do not count; `play_music`, `play_jingle`, `stop_music` and `shutdown` clear the holds; a context released
while another track was pushed over it leaves the stack, so the track it interrupted comes back after that one).
`Sfx` gains the 33 effect names of `Sfx.EXPANSION_SFX` (DESIGN.md F.2 and `CLANG`, the versus clang) and the 30 music
contexts of `Sfx.EXPANSION_MUSIC`. AudioTable batch 1 (P1.1) gives every one of them a row: the audio owner's files
for all effects and the G1 slice's music (canyon, co-op menu, lobby, battle A, round / match jingles, results); the
other contexts play a 1.0 track of the same mood marked `"temp": true` (`AudioTable.is_temp(name)`, `temp_names()` =
the work list of batch 2, P2.6) until their file lands. Callers never change when a row does.
P2.6 (batch 2 plumbing): a music row may carry `"loop_start"` (seconds into the file where the loop restarts; the
intro before it plays once, the loop runs to the end of the file - the audio owner cuts each file at its loop end,
Ogg cannot end a loop early; missing = the whole file loops; a file keeps one loop flag and one loop start in every
row): `AudioTable.loop_start(context)`, Audio sets the stream's `loop_offset` (WAV: `loop_begin`), resume points and
the silent clock wrap into the region (`static Audio.loop_position(elapsed, length, loop_start)`).
`Audio.set_effects_muted(on)` / `are_effects_muted()`: effects and loops are dropped (playing loops stop), music is
untouched - Flow mutes them while it fast-forwards a replay. `MUSIC_VERSUS_SUDDEN_DEATH` is pushed by Flow on
`Events.round_sudden_death_started` for the rest of the round. Batch 2 (the audio owner's files, P2.11): every 2.0 music
context plays its own file (whole-file loops, the regions cut out of the renders; the sudden death is F.2's runner-up),
`AudioTable.temp_names()` is empty; two more effect names: `Sfx.LIGHTNING_STRIKE` (zones/lightning's bolt) and
`Sfx.ROUND_GONG` (E.8's gong, played by `Flow.end_round` once per round).

### 3.10 `Flow` autoload - scenes, transitions, pause

Screens are scenes by naming convention: screen `tally` = `res://scenes/ui/tally.tscn`. Names: `title`,
`mode_select`, `code_entry`, `options`, `world_map`, `tally`, `game_over`, `expert_wall`, `the_end`, `credits`.
Gameplay is `res://scenes/world/level.tscn`, which reads `Flow.pending_level_id`.

`goto_screen(screen, transition, args)`, `goto_title()`, `start_new_game(difficulty)`, `continue_game(level_id,
difficulty)`, `show_world_map(level_id)`, `start_level(level_id, transition, carry_progress)`,
`restart_level()` (the run returns to its level-entry state through `Game.restore_level_entry`; a death toss in
progress still costs its life, or ends the run), `complete_level(exit_kind)`, `finish_tally()`, `game_over()`,
`set_paused / toggle_pause /
is_paused`, `quit_game()`, `shutdown_and_quit(exit_code)` (the only way to quit: `auto_accept_quit` is off),
`get_overlay(layer)`, `has_screen`, `has_gameplay()`, `play_covered(action, transition)`,
`get_transition_cover()`, fields `current_screen`, `args`, `pending_level_id`, `busy`, `instant_transitions`,
`transition_speed`, `pause_on_focus_loss`, signals `screen_changed`, `transition_covered`, `transition_finished`.

Transitions (GAMEPLAY.md 11.1; `TransitionCover` on layer `LAYER_TRANSITION`): `FADE` between menus, `CURTAIN`
into gameplay (two panels close from the sides, then open from the centre out; also game over, warps, sub-stages),
`IRIS` at the end of a level (closes on the middle of the hero, rests as a spotlight, shuts; opens from the
centre). While a cover hides a level the clock stands still (`Sim.frozen`): a level starts ticking only when the
player can see it. **Everything that moves the hero behind a curtain without changing the scene** - the respawn
after a death (world: `respawn_player()`), gates (objects), warps inside a level - calls
`Flow.play_covered(action, Defs.Transition.CURTAIN)`: it may be called from inside a tick; `action` runs once,
between two ticks, while the screen is fully covered (no tick is lost or added, so it stays deterministic) and may
itself start a scene change (`Flow.game_over()`), which then takes over the cover.

Focus and background (all platforms, essential on phones): when the app loses focus or goes to the background,
Flow pauses running gameplay (`set_paused(true)`, so the pause menu shows), suspends all sound
(`Audio.set_suspended`) and writes the settings; `GameInput` releases touch buttons and latches. Sound returns
with the focus; gameplay stays paused until the player resumes. The Android back button pauses running gameplay
and acts as `ui_cancel` everywhere else (menus need no platform code).

Flow owns three overlay CanvasLayers and, when a level starts, instantiates into them (if the scenes exist):
`scenes/ui/hud.tscn` (layer 10), `scenes/ui/touch_controls.tscn` (20), `scenes/ui/pause_menu.tscn` (30). The
level scene contains no UI. The `pause` action is handled by Flow (toggle + `Events.pause_changed`).
A screen that does not exist is skipped or replaced by the boot placeholder; a missing level scene is replaced by
the debug level (section 9.3). The route logic of GAMEPLAY.md 1.1 (tally, linked sub-stage without tally, warp to
and from bonus stages, trophy, Beginner wall, ending) is implemented in `complete_level` and `finish_tally`.
A trophy that leads to an epilogue records the result of its map stop at once (the stop has no tally of its own);
a bonus stage entered without its source level's warp (debug level select) returns to the title after its tally,
never to The End.
2.0: `pause_slot` (the slot whose device paused, from `GameInput.event_slot`; 0 otherwise, reset on unpause);
`restart_level` charges a life only when `LevelBase.all_heroes_dead_or_down()`; the iris centres on the party when
`hero_count() > 1`.
P1.1 (core-A; GAMEPLAY.md 13.1 / 13.9.1 / 13.10.1). Screens `book_select`, `join`, `unlocks`, `versus_lobby`,
`versus_rules`, `versus_arena`, `versus_scoreboard` (args `round_index`, `winners`), `versus_results` (args `winners`,
`awards`). Front end: `open_play(Defs.GameMode)` (Solo -> book select; Co-op -> `begin_party_setup()` + join panel;
Versus -> lobby), `choose_book(book)` (-> mode select), `start_selected_game(difficulty)` (what the difficulty screen
calls), fields `play_mode`, `play_book` (the title resets them, and a party's input to single-player). Runs:
`start_new_game(d)` stays the 1.0 game (Book I solo); `start_book_game(d, book = 1, at_level = "")`,
`start_coop_game(d, party = 2, book = 1, at_level = "")` (slots nobody joined get the left / right keyboard half, then
pads); `continue_game` starts the level's book. Mode-aware campaign: `level_to_play(id)` (co-op: a solo id's
`<id>_coop` file; single-player and versus never change an id) is applied by `start_level` and `warm_up`; the route
logic of `complete_level` / `finish_tally` reads a co-op file's solo kind; results, unlocks (solo map-stop ids), the
high-score table, completion and the carried belts (Book II / co-op) go to `save_space()` = `Save.space(Game.mode,
Game.book, difficulty)` (a Book I solo run writes exactly what 1.0 wrote, plus its namespace high score);
`show_world_map` args add `book` and `mode` (in co-op `level_id` is the solo stop). Joining: `party_size()`,
`join_player(input, slot = -1) -> int` (co-op 2, the versus lobby 4 seats; the single player keeps his device as P1;
plays `Sfx.PARTY_JOIN`), `leave_player(slot) -> bool` (later players move up; back to one player = single-player
input; the last player of a running campaign cannot leave), `finish_join()`, signal `party_changed(size)`; mid-stage
a join or leave restarts the stage behind the curtain in the other layout (`Levels.level_for_mode`) at the checkpoint
the player had reached (each hero at `get_respawn_pos_for(slot)` before tick 1), score kept (`Game.set_party`).
Pads: `notify_pad_connection(device, connected)` (Input.joy_connection_changed): a pad seat lost during play pauses with
`pause_slot` = that slot, signal `pad_lost(slot)`; the next pad that connects takes the oldest lost seat
(`pad_reconnected(slot)`); `lost_pad_slots()`, `continue_alone(slot)` (co-op: he leaves; versus: a bot takes over).
Versus: `open_versus_lobby()`, `add_bot(level)`, `start_versus(match = null, seed = -1) -> bool` (compacts the seats,
remembers the rules, `Game.start_run(.., VERSUS, players)`, humans' inputs, round 0), `start_round()` (the round's arena
behind the curtain, `Sim.rng` seeded with `round_seed()` after loading and before tick 1, every bot seat fed by its
HeroBot - created once per match by path, `reset_round(round_seed)` each round), `end_round(winners)` (the referee's gong:
records the round, emits `Events.round_ended` once, then scoreboard / next round / results), `next_round()`,
`rematch()`, `leave_versus(to_title = false)`. The countdown, round clock, sudden death and the gong are the referee's
(world-B, `scripts/world/versus/referee.gd`).
P2.6 (core-A). **Deciding moment** (DESIGN.md E.8 step 5): every round is recorded into `Game.versus_match.replay`
(VersusReplay: after each tick's sampling the flags of every hero, after each tick the steals; the handlers are
connected only while a round plays, never in single-player). `end_round` finishes the recording, records the round,
emits `round_ended`, then - with `deciding_moment` on (default; off in headless runs, tests switch it on) - calls
`play_deciding_moment() -> bool`: the round's level stops at once (`Sim.frozen`), behind the curtain the match's round
state and every run go back to the round's start, every hero's slot is fed from the log (`GameInput.
set_scripted_slot`; scripts that drove a slot before come back afterwards), the arena loads again with the round seed,
the ticks before the window run at once with the effects muted, and the window plays at half speed (`Sim.time_scale`,
a 2.0 member of Sim: only the pacing changes). Signals `replay_started(round_index, first, last, steal)` and
`replay_finished(skipped)`; `is_replaying()`, `replay_window()`, `skip_replay()` (any Jump / Strike / accept / cancel /
pause / tap skips; the pause key never pauses a replay). At the window's last tick or on a skip the round's end comes
back (match state, the runs' statistics - not counted twice) and the scoreboard (or the results) follows; a title, a
lobby, a rematch or a new round cancels a replay. The replay is the round tick for tick (`tests/test_core_replay.gd`).
**Book II plumbing**: `stop_after_warp(level_id, difficulty)` - a bonus stage's warp ends its source stop and the
campaign continues at the stop after it, passing over the stop's linked sub-stage (GAMEPLAY.md 1.1 "warping from 3a
skips 3b"; Book II 5-2 -> Feast Land D -> 6-1; Book I's warp stops have no sub-stage: unchanged), `finish_tally` uses
it after a warp; the expert wall gets args `{book, mode}`, THE END `ending_args()` = `{book, mode, mural}` (`mural`: Book
II with every painting found, UnlockTable.is_mural_open); `level_select(mode, book, difficulty) -> [{level_id, code,
unlocked, result}]` (the code entry's list per book, the co-op continue; co-op lists the stops with a co-op file and
no codes). Codes of both books are found by `Levels.find_by_password` and started by `continue_game` (the level's
book). Co-op endings: a co-op file plays the route of its solo level (trophy -> the co-op epilogue, ending -> THE END
with the co-op namespace completed). **Sudden death**: `Events.round_sudden_death_started` pushes
`Sfx.MUSIC_VERSUS_SUDDEN_DEATH` in a versus level. **Round music** (P2.6 polish): when a round's arena is loaded Flow
plays `VersusMatch.round_music(arena music, round_index)` - an arena whose `music` is one of `VersusMatch.BATTLE_MUSIC`
(DESIGN.md F.2's battle A / B / C) starts the match with it and each later round takes the next of the three; other
music stays; the deciding moment plays the replayed round's own track. Sound only.

### 3.11 `LevelBase` (`scripts/base/level_base.gd`) - what everybody may ask the running level

Reach it through `Game.level` (null outside gameplay). Fields: `level_id`, `meta`, `grid: TileGrid`,
`player: PlayerBase`, `start_pos`, `shake`, `shake_offset`, `wind`, `scroll_flags`, `dark`, `completed`,
`active_enemies`.
Registry: `get_kind(kind) -> Array[SimEntity]` (live list in spawn order; read-only), `find_named(name)`.
View: `get_view_rect() -> Rect2i` (logical px), `get_camera_cell()`, `is_in_view(entity, margin)`,
`lock_camera(rect)`, `unlock_camera()`, `is_camera_locked()`, `get_camera_lock()`, `snap_camera()`.
Spawning: `spawn(id, pos, params) -> Node`, `spawn_fx(id, pos, params)`, `get_container(category)`.
Tiles: `set_cell(col, row, ch)`, `get_cell(col, row)`, `set_cell_look(col, row, atlas_index)`.
Effects: `request_shake(amount)`, `tick_shake_timer()`, `set_darkness(on)`, `set_wind(value)`.
Time limit (meta `time`): field `time_left` (ticks, -1 = none), signal `time_left_changed(seconds)` (also sent as
`Events.time_left_changed` for the HUD), `set_time_limit(seconds)`, `tick_time_limit()` (phase POST; kills the hero
with cause `&"time"` at zero), `get_time_left_seconds()` (-1 = none).
Flow: `start_play(seed)`, `complete(exit_kind)`, `get_respawn_pos()`, `respawn_player()` (also restores the darkness
the level had when the active checkpoint was touched, or at the start; `get_respawn_darkness()`), `reset_entities()`.
Built in: step 18 of the tick (shake nudge on odd ticks), `on_screen` flags for every entity after each tick,
respawn-or-game-over on `Events.player_death_finished`, pop-ups on `Events.popup_requested`.

2.0 PlayerSet (PLAN.md P0.6, TECH_AUDIT.md 4.1). Every reader of "the hero" uses one of three idioms, each the 1.0
code for a party of one: **target** `level.target_hero(self)`, **every** `for hero in level.contact_order()`, **P1**
`level.player`. Members: `heroes: Array[PlayerBase]` (index = slot, slot 0 = `player`), `start_positions` (index =
slot; the loader fills it from '@', `objects/hero_start slot=n` and an arena's `objects/spawn_point index=n`), `hero_count()`, `get_hero(slot)`, `contact_order()` (slot order; rotated by `Sim.tick % N` in versus; no
allocation), `target_hero(from)` (party: the nearest `is_party_targetable()` hero, ties to the lower slot),
`nearest_coop_hero(from)` (phase 3, the IDLE rule: the same choice among the heroes that `counts_for_coop()`, null when
none - for co-op POSITION rules such as a `shell` shield, a boss's "nearer hero"; `target_hero` in a party of one),
`any_hero_dead_or_down()`, `all_heroes_dead_or_down()`, `any_hero_feasting()`, `get_start_pos_for(slot)`,
`get_respawn_pos_for(slot)` (24 px spread per slot, PHYSICS.md C.12), `spawn_party_heroes()` (slots 1..party - 1,
after P1). Views: `get_view_count()`, `get_view_rect_at(i)`, `get_view_rect_of(entity)`, `get_views_bounds()`;
`is_in_view` and `on_screen` mean "any view". Doze: one rectangle per hero and view. `tick_shake_timer_by(hero)`
(once per tick for a party), `hero_death_finished(hero)` (party death routing; neutral default: a team wipe after the
last toss, `Events.party_wiped`, the 1.0 life-and-respawn rule), `respawn_hero(hero, pos)` (no world reset),
`notify_hero_teleported(hero)` (party only: an immediate doze decision); `complete()` freezes every hero of a party.
2.0 hooks (PLAN.md P0.8): `register_party_driver(driver: SimEntity)` - world-A's PartyDriver is added after the heroes
(registration order: level entities -> P1 -> P2 .. -> driver -> runtime spawns, so `Defs.Phase` stays); a driver with
`handle_hero_death(hero) -> bool` answers `hero_death_finished` first; `party_driver` (null in single-player).
`get_tagged(param, value) -> Array[SimEntity]` - the group registry of the spawn parameters `TAG_PARAMS`
(`bond=<name>`: linked enemies and drums; `keeper=<name>`: the enemies a keeper door waits for); live, read-only.
P1.6 (world-A): `get_party_frame() -> Rect2i` (the authentic 20 x 11-cell view of the tribe camera),
`get_edge_walls() -> Vector2i` (the co-op edge walls, ZERO = none), `pull_party_into(rect, trigger_hero)` (a locked
view takes the party), `team_wipe()`, `party_spread_point(base, place) -> Vector2i`; `Level` adds
`get_tribe_camera()`, `get_rising_tide()`, `stop_rising()`. The Level registers world-A's `PartyDriver`
(`scripts/world/party_driver.gd`) for `Game.mode == COOP` with 2+ heroes: `weapon_pass(hero)`,
`handle_hero_death(hero)` (a toss that ends while a partner plays makes an egg, no life lost; the team wipe after the
last toss is unchanged), `exit_touched(exit, hero)`, `is_at_exit(hero)`, `team_at_exit()`, `travel_party(user, from,
to)`, `hatch_all(by)`, `bones_to_partner(hero, n)`, `relay_bounce_count(enemy, hero, count)`,
`static relay_multiplier(count)`, `carrier_of` / `rider_of` / `partner_of`. `CurrentZone` (`zones/current`):
`find_at(level, pos)`, `drift_at(level, pos)`; `RisingTide` (`scroll = rising`). Flow (P1.1) restarts a stage for a
join or leave and then puts every hero at `get_respawn_pos_for(slot)` with `respawn_hero` and `snap_camera()`.
Phase 2 (world-A): `PartyDriver.is_active(hero)`, `PartyDriver.active_mask` (the ACTIVE partner of the G1 egg
resolution: an egg is no springboard, PHYSICS.md C.12); `Level.get_egg_scout() -> EggScout`
(`scripts/world/egg_scout.gd`, the egg scouts' glint, `EggScout.spots_near_eggs`), `Level.get_lights() -> LevelLights`
(`scripts/world/level_lights.gd`, lights in the dark on Book II levels, arenas and in parties),
`Level.attract_flies(amount, hero = null)` / `get_fly_count(slot = -1)` (one fly swarm per hero); `zones/lightning`
(`LightningZone`: `rect`, `period` [66], `delay` [0], `mark` [22]; plays `Sfx.LIGHTNING_STRIKE`) and `zones/food_rain`
(`FoodRainZone`: `rect`, `period`, `skin = food | fruit`) exist (`scenes/zones/lightning.tscn`, `food_rain.tscn`); meta
`wind_loop` is live (the wind script restarts every `wind_loop` ticks; 0 = the 1.0 script); CurrentZone draws its
streaks and WorldWeather gust streaks outside the ice biome (presentation only). The tribe camera keeps every grounded
hero whole on the view while one view can hold them (`PartyTuning.CAM_KEEP_HEAD_PX`, PHYSICS.md C.13).
The co-op **lee** (PHYSICS.md C.6): `LevelBase.lee_mask` (a bit per slot, written by the PartyDriver in `WEAPONS`;
always 0 outside a co-op party), `LevelBase.wind_for(hero) -> int` (the wind that hero's `WIND` step feels: the
level's `wind`, or 0 in a lee), `PartyDriver.in_lee(order, hero, wind_sign)`; the reach is
`PartyTuning.LEE_REACH_PX` 64 downwind of the croucher's feet and `LEE_DY_PX` 16 up or down *(tune)*.

### 3.12 `PlayerBase` (`scripts/base/player_base.gd`)

Readable state (names of PHYSICS.md 0): `state`, `input_flags`, `ice`, `on_platform`, `grounded`, `jump_ticks`,
`fall_ticks`, `no_jump`, `last_ground_y`, `drop_timer`, `charge`, `swing_lock`, `attack_gate`, `hit_timer`,
`feast`, `glide`, `idle_timer`, `looking`, `dead`, `control_enabled`, and the club box of the current tick:
`club_box_active`, `club_box: Rect2i`, `club_box_xo`, `club_origin`, `club_power`.
Queries: `is_grounded`, `is_crouching`, `is_low`, `is_gliding`, `is_striking`, `is_immune`, `is_feasting`.
Calls: `hurt(source, kind) -> bool`, `kill(cause)` (causes `&"enemy"`, `&"spikes"`, `&"liquid"`, `&"pit"`,
`&"crush"`, `&"off_screen"`, `&"give_up"`, `&"time"`; both are ignored once `LevelBase.completed`, while the exit
iris closes), `bounce(yvel, depth)`, `ride_platform(platform, dx, dy)`,
`apply_shake_nudge(px)`, `start_feast(ticks)`, `set_glider(carrying)`, `respawn_at(pos)`,
`set_control_enabled(on)`, `notify_weapon_hit()`.

2.0 (PLAN.md P0.6 / P0.8; every member keeps its default for a single-player hero): `slot` (spawn parameter `slot`,
0 = P1; sets `run`), `run: PlayerRun` (= `Game.runs[slot]`; the hero calls `run.*` where 1.0 called `Game.*`),
`carried_on_tick` (the per-hero platform guard), `is_down()`, `is_party_targetable()` (targeting and harm),
`counts_for_coop()` / `is_idle()` (phase 3, the IDLE-PARTNER rule, DESIGN.md D.3 [G33]: alive, hatched and not idle -
no input of his own slot for `IDLE_TICKS` = `PartyTuning.IDLE_TICKS` = 243 ticks or none since he entered the level;
the query of every co-op RULE; `note_own_input(flags)` counts it first thing in his WEAPONS phase, co-op only;
`input_idle_ticks` / `gave_input` / `idle`), `braces_with(partner)` (the
Brace Wall test of C.10: both crouch on the ground within `PartyTuning.BRACE_GAP_PX`; read by `heavy` enemies and
bosses). Egg (PHYSICS.md C.12): `down`,
`go_down(cause)` (an egg at once: not dead, no control, `Events.hero_down`), `hatch(by, hearts)` (`shield` =
`PartyTuning.HATCH_BLINK_TICKS`, the -64 pop, `Events.hero_revived`); `hurt` and `kill` ignore an egg. Hatch shield:
`shield` (ticks; enemy contact skipped, `is_immune()` true; in versus the spawn shield, C.14). `leash` (co-op ticks
off the view, counted by the party component, read by the HUD's edge arrow). Versus (C.14, set by world-B's referee,
counted down by the party component): `hit_stop` (ticks without a PLAYER phase), `squash` (ticks with UP and FIRE
ignored); a rival's hit is `hurt(source, Defs.HurtKind.RIVAL)`, which `hero_party.on_hurt` takes (hit_timer
`VersusTuning.HURT_TIMER_TICKS`). States outside the 4.3 table: `Defs.HeroState.CLIMB` (`hero_climb`), `CURL`
(`hero_party`), `RIDING` (`hero_mount`). Curl (C.11): `curl` (`CURL_NONE`, `CURL_CURLED`,
`CURL_BALL`), `is_curled()`, `bat(xvel, yvel, batter)`, `ball_batter`. Mount seat (C.9): `mount`, `mount_seat`
(`SEAT_NONE`, `SEAT_DRIVER`, `SEAT_GUNNER`), `is_mounted()`, `sit_on_mount(mount, seat)`, `leave_mount()`. Launch
(C.0 #4): `launch(xvel, yvel)` (each given component clamped to +/- `PartyTuning.LAUNCH_AXIS_CAP` = 288 v16,
`LAUNCH_KEEP` keeps one; `no_jump` armed). x fence (edge walls C.13, raft rails C.7): `fence_x(left, right_excl)`
(intersects, lasts until the hero's next x step), `fence_allows(x)`, `clear_fence()`. `respawn_at` clears egg,
shield, leash, hit-stop, squash, curl, seat and fence.
**Player components** (`scripts/player/`, PLAN.md P0.8): `Player.hero_belt: HeroBelt` (player-B, Swap and the belt),
`hero_climb: HeroClimb` (player-B, vines), `hero_mount: HeroMount` (player-B, the rider's side of Chomper),
`hero_party: HeroParty` (player-A, egg, curl, bat, hatch, edge walls, versus hurts). Each has `hero`, `active` (false:
none runs for a Book I solo hero) and `setup(level)` (called from `_ready`, decides `active`), `update(level) ->
bool` (true = it ran the rest of the PLAYER phase itself), `tick_timers()`, `on_hurt(source, kind) -> bool` (true =
it took the hit), `on_respawn()`; `HeroParty` also `weapon_pass(level)` and `post_step(level)`. Order in the hero's
phases: WEAPONS `hero_party.weapon_pass` before his box and throws meet enemies; PLAYER after 8b `hero_party.update`,
`hero_mount.update`, `hero_belt.update`, after 8c `hero_climb.update`; 8i the components' `tick_timers`; POST
`hero_party.post_step` after the hit timer; `hurt` asks `hero_mount`, `hero_climb`, `hero_party` after the immunity
checks.
P1.4 (player-A; every member keeps its 1.0 default for a single-player hero): Totem Ride and duo moves (C.10, called
by world-A's PartyDriver): `totem_carrier`, `totem_rider`, `totem_drop_lock`, `totem_carry_yvel`, `is_riding_totem()`,
`is_carrying_totem()`, `holds_up()`, `can_land_on_partner()`, `land_on_partner(partner)` -> `HEAD_NONE` / `HEAD_HOP` /
`HEAD_RIDE` / `HEAD_HATCH`, `shoulder_hop(partner, depth)`, `start_totem_ride(carrier)`, `carry_totem() -> bool`,
`end_totem_ride()`, `drop_from_totem()`, `throw_off_totem_rider()`. Brace: `brace_partner() -> PlayerBase`,
`is_braced()`; heavy enemies implement `brace_stop(hero, partner) -> bool`, asked by `Player._contact_pass` before a
croucher's hurt. x commit: `x_commit_allows(x)` (level bounds; Player adds the co-op edge walls). Movement limits (tar
C.5, versus weight C.14): `walk_cap`, `air_cap`, `jump_impulse_ticks`, `jump_impulse_quarters`, world-B's
`walk_cap_override` / `jump_scale_3_4` (setters onto them); `respawn_at` restores all. `death_origin`, `death_cause`
(set by `kill`: the co-op egg appears where the toss started). Hook order: a versus hit-stop skips the hero's PLAYER
phase before 8b (`HeroParty.hold_hit_stop`); the party component's update runs right after 8b. Not contract members:
`Player` signal `emoted(kind)`, `apply_palette()`; `HeroParty` `Emote`, `show_emote(kind)`, `palette()`; `HeroPalette`
(`scripts/player/hero_palette.gd`): `resolve(slot, run, biome, versus)`, `material_for(colour, pattern, use_cloth)`,
`ui_colour(colour, role)`, `apply_image(...)`. Credit: `Defs.hitter_slot` of a hero flying as a batted ball (`curl ==
CURL_BALL` with a `ball_batter`) is the batter's slot.

### 3.13 `EnemyBase`, `BossBase`

`EnemyBase`: `max_hp`, `hp`, `score_index`, `skin`, `contact_hurts`, `tangible`, `awake`, `dead`, `one_shot`,
`bounce_count`, `dive_count`, `stole_heart`, `flash`; `_ai_tick()` (override), `is_targetable()`,
`take_hit(power, source) -> bool`, `on_bounced(hero) -> int`, `on_glider_stomp(hero)`, `on_hurt_hero(hero)`,
`get_points()`, `kill(cause, killer)`, `burst_into_items(count)`, `wake()`, `sleep()`, signal `died`.
`BossBase extends EnemyBase` (kind `BOSS`): `arena`, `fighting`, `hit_cooldown`, `hp_per_pip`, `music`,
`thrown_only`; `get_pips()`, `get_max_pips()`, `start_fight()`, `poll_weapon_hit(weak_point) -> int`,
`apply_boss_hit(power)`, `touch_hero(hero) -> bool`, `defeat(drops)`.

2.0 `EnemyBase` (PLAN.md P0.6 / P0.8, TECH_AUDIT.md 4.8): `_target_hero()` answers the hook `_choose_target()` (default
`level.target_hero(self)`; override for aggro rules); `_should_sleep` far from every hero; `_shows_food` while any
hero feasts; `kill` credits `Game.runs[Defs.hitter_slot(killer)].kills`. Hit bookkeeping: `last_hit_slot`,
`last_hit_tick` (set by `take_hit`); `accepts_hit_from(source) -> bool` (default true; false = the hit glances:
consumed, no damage, `_on_hit_refused(source)`), `_on_hit_by(slot, power)` (before the hit points drop). Format-2
parameters: `coop_trait` (`coop=<trait>`, a `Defs.CoopTrait`), `bond` (`bond=<name>`), `keeper` (`keeper=<name>`),
`bond_mates()`; the groups are `LevelBase.get_tagged`. 2.0 `BossBase`: `poll_weapon_hit` tests every hero's club box
in contact order (the hero who hit pogos) and sets `last_hitter` (the hero of the counted hit; also `last_hit_slot` /
`last_hit_tick`); `_wakes_for(hero)` / `_wakes_for_any(target)`.
P1.8 (enemies-A, additive): `EnemyBase.coop_traits() -> CoopTraits` (null without a trait); protected helpers
`_hit_from_front(source)` and `_show_glance(source)` (the default `_on_hit_refused` shows the clank and the spark:
`Sfx.CLUB_HIT_SCENERY` + `fx/hit_stars`). In a party (`hero_count() > 1`) `_choose_target` keeps the nearest hatched
hero for `PartyTuning.TARGET_HOLD_TICKS` (GAMEPLAY.md 13.9.4); a `lone` record on Expert answers
`CoopTraits.lone_target()`. `CoopTraits` (`scripts/enemies/coop_traits.gd`): `party_on()`, `window_ticks()`,
`bond_members(level, name)`, `bond_done(level, name)`, `keepers_done(level, name)`, `lone_target()`, fields `kind`,
`dazed`, `held`, `host`, `split`, `mate`, `sealed`; it plays `Sfx.DAZE` and `Sfx.BRACE`. Keeper and Guard halls are
`PartyTuning.KEEPER_HALL_ROWS` = 4 rows (64 px: the Guard and Shellback art is 54 px tall). The world-5 rattler is
`enemies/snapper skin=snake` (no new id); `enemies/shellback` = a Guard with the shell preset.
P2.1 (enemies-A, additive): `wear_bone_shield()` / `bone_shielded() -> bool` (the co-op Shaman's bone shield: every hit
glances while a living, awake Shaman stands within `PartyTuning.SHAMAN_SHIELD_TILES` on both axes; only a co-op
party's Shaman sets it; it holds through the tick he dies in; `accepts_hit_from` refuses every hit while it is on),
`_on_coop_copy(source)` (hook on the half a `split` record spawns: a sky dropper keeps falling / walking),
`_credit_points(source, points)` (the co-op "Rival score" share in `PlayerRun.score`, before `Game.add_score` in
`kill()` and `on_glider_stomp()`; single-player untouched). `CoopTraits` adds `window_cap` (level parameter `window`),
`group_window()`, `daze_window()`, static `capped_window(base, params)` (tools), `count_in` (the window count-in on the
group's leader: `PartyTuning.COUNT_IN_BEEPS` x `Sfx.COUNT_IN`, `PartyTuning.COUNT_IN_SPACING_TICKS` apart, then
`Sfx.DRUM`), `carries` (grab: the heroes seized). P2.1 (enemies-A, resumed run): `_ground_step` caps a grounded
enemy's step on a `:` tar cell at `Tuning.TAR_WALK_CAP` (PHYSICS.md C.5; its xvel is kept); the Guard has the protected
hook `_bears_shield()` (false = a preset patrolling as a plain Walker); EnemySkin also knows art-B's boss sheets of
worlds 7-9 (`inkjaw` [+`_rage`], `inkjaw_parts`, `idol_sun`, `idol_moon`, `idols_parts`, `roc`, `roc_parts`,
`roc_lightning`, `chieftain_gorm`, `chieftain_gulla`, `chieftain_egg`).

### 3.14 `ProjectileBase`

`from_hero`, `power`, `yacc`, `life`, `hurt_kind`, `spent`; `consume()`. Parameters `from_hero`, `power`, `xvel`,
`yvel`, `yacc`, `life`. Moves in phase `PROJECTILES` without tile collision; removed when not drawn in the
previous frame. Enemy projectiles test the hero themselves in `CONTACT_ITEMS`.
2.0: `owner_slot` (spawn parameter `owner`, the thrower's slot; a hero tests only his own throws); enemy projectiles
test every living hero in contact order (the first they hurt uses them up); "gone below the view" means below every
view (`LevelBase.get_views_bounds()`).

### 3.15 `CollectibleBase`, `HittableBase`, `HazardBase`, `CheckpointBase`, `LevelExitBase`, `PlatformBase`

- `CollectibleBase`: `item_id`, `index`, `points`, `counts_for_completion`, `dropped`, `life`, `age`, `collected`,
  `reappears_on_respawn`, `pickup_sfx`; `can_be_collected()`, `collect(hero) -> bool`, override `_apply(hero) ->
  bool` and `_move_tick()`.
- `HittableBase`: `cell`, `hits_left`, `opened`, `cooldown`, `spot_kind`, `counts_for_completion`;
  `is_hit_by(origin) -> bool` (the rule of PHYSICS.md 8.3 #2), `take_hit(power, source) -> bool`, `open()`,
  override `_on_hit`, `_on_opened`.
- `HazardBase`: `deadly`, `hurt_kind`, `death_cause`, `armed`; `touch(hero)`, override `_move_tick()`.
- `CheckpointBase`: `active`; `activate(hero)`, `deactivate()`, override `_on_active_changed()`.
- `LevelExitBase`: `locked`, `exit_kind`, `used`; `is_open()`, `use(hero)`, override `_on_open_changed()`.
- `PlatformBase`: `dx`, `dy`, `ridden`; override `_move_tick()` (set `dx` / `dy`); the ride test of
  PHYSICS.md 11.4 is built in. `sim_pos` is the bottom-centre, the standing surface is `sim_pos.y - box_h`, and
  a riding hero rests at `top + 1`.
- 2.0: these bases test every hero in `LevelBase.contact_order()` (collectibles: the first hero who collects wins;
  `collect()` counts `run.picked`). `PlatformBase`: the ride test runs per hero (`_ride_test_hero`, guard
  `PlayerBase.carried_on_tick`); `rider_mask` (bit per slot carried in the last ride test), `rider_count()`,
  `rider_weight()` (`PartyTuning.PLATE_WEIGHT_HERO` per hero + the hook `_extra_weight()`) for pulleys and weight
  rules.

### 3.16 Small shared classes

`Defs` (enums `Difficulty`, `Weapon`, `Phase`, `Kind`, `HurtKind`, `HeroState`, `Device`, `Transition`; input
bits; action names; groups; z indices; CanvasLayer numbers; physics layer bits; scroll flags), `Tuning` (section
4.4), `Sfx`, `AudioTable`, `Spawner` (section 6), `SimRng`, `LevelText`.

2.0 (PLAN.md P0.3 - P0.8; appended only, every 1.0 value unchanged):
- `Defs`: `Weapon.SPEAR = 4` (name `spear`); `MAX_PLAYERS = 4`; `GameMode { SINGLE, COOP, VERSUS }`
  (`game_mode_name`); `InputSlotKind { NONE, ALL_DEVICES, KEYBOARD_LEFT, KEYBOARD_RIGHT, KEYBOARD_FULL, PAD, TOUCH,
  BOT, SCRIPT }`; `CoopTrait { NONE, SHELL, BOND, DAZE, HEAVY, LONE, GRAB, LEECH, SPLIT }` (`COOP_TRAIT_NAMES`,
  `coop_trait_name`, `coop_trait_from_name`); `VersusMode { GRUB_STACK, LAST_CAVEMAN, HOT_ROCK, CLUBBALL,
  KING_OF_THE_FEAST, LETTER_SNATCH, EGG_HEIST }` (`VERSUS_MODE_NAMES`, `versus_mode_name`, `versus_mode_from_name`);
  `BotLevel { ROOKIE, HUNTER, CHIEF }`; `IN_SWAP = 64`, `ACT_SWAP = &"swap"` (the 9th `GAME_ACTIONS` entry);
  `SCROLL_RISING = 8` (`scroll = rising`); `hitter_slot(source) -> int` (a hero -> his slot, a hero projectile -> its
  `owner_slot`, anything else -> -1; duck-typed so tools that run before the autoloads compile `Defs`);
  `HeroState.CLIMB = 9`, `CURL = 10`, `RIDING = 11` (states outside the 4.3 table, PHYSICS.md C.4 / C.11 / C.9;
  `Tuning.STATE_LUT` never yields them); `HurtKind.RIVAL = 4` (a versus hit, C.14).
- `Tuning`: a 5th (spear) entry in `WEAPON_POWER` / `WEAPON_LOCK` / `WEAPON_THROWN`; the Book II hero and world rules
  of DESIGN.md C and the core rows of PHYSICS.md C.16 (`SWAP_LOCKOUT_TICKS`, `SPEAR_*` incl. the box and
  `SPEAR_FALL_MAX`, `BARK_BOARD_*`, `VINE_*` incl. `VINE_HAND_REACH_PX`, `VINE_REGRAB_LOCK_TICKS`,
  `VINE_TOP_STEP_PX`, `TAR_SURFACE_DROP_PX`, `TAR_WALK_CAP`, `TAR_AIR_CAP`, `TAR_JUMP_IMPULSE_TICKS` (2 [R2]),
  `GEYSER_*` incl. `GEYSER_PERIOD`, `GEYSER_PERIOD_MIN`, the vent and deadly boxes, `RAFT_*` incl.
  `RAFT_SPEED_CAP`, `RAFT_HEIGHT_PX`, `RAFT_FLOAT_DEPTH_PX`, `CURRENT_SPEED_*`, `RISE_SPEED`, `RISE_CHECKPOINT_ROWS`,
  `TELEGRAPH_MIN_TICKS`, `PAINTING_*`).
- `PartyTuning` (`scripts/core/party_tuning.gd`): every co-op number of DESIGN.md D (party, tribe camera, leash,
  lives and the Egg Hatch, duo moves, windows, co-op objects, traits, boss co-op hit points, gates) and the
  PartyTuning rows of PHYSICS.md C.16 (`TOTEM_*`, `CURL_BOX_*`, `EGG_*`, `PULL_IN_BEHIND_PX`, `TARGET_HOLD_TICKS`,
  `LONE_KEEP_AWAY_PX`, `PLATE_WEIGHT_BOULDER`, `PULLEY_RANGE_ROWS`), plus
  `RESPAWN_SPREAD_PX`, `MOVE_MAX_PX_PER_TICK`, `LAUNCH_AXIS_CAP`, `HATCH_POP_YVEL` and the helpers `window_ticks`,
  `leash_egg_ticks`, `hatch_hearts`, `egg_return_ticks`, `daze_ticks`, `boost_ledge_tiles`, `lone_trait_on`,
  `boss_grabs_on`, `seesaw_launch`, `bat_charged`, `boss_coop_hp_max`.
- `VersusTuning` (`scripts/core/versus_tuning.gd`): every versus number of DESIGN.md E (combat kit, the modes, arenas,
  sudden deaths, bots, match flow) and the VersusTuning rows of PHYSICS.md C.16 (`HURT_TIMER_TICKS` 43,
  `STUN_HIT_TIMER_MIN` 31, `CLANG_PUSH_EACH_PX`, `STOMP_IMMUNE_TICKS`, `TEAMMATE_BUMP_XVEL`, `CURL_GLANCE_ABOVE_PX`,
  `BODY_KNOCK_XVEL` / `_YVEL`, `HOT_ROCK_FIRST_PICK_TICKS`, `HOT_ROCK_REPICK_TICKS`, `BALL_ROLL_LOSS`,
  `GIANT_BONK_DAZE_TICKS`, `ARENA_FILE_ROWS`) with the helpers `round_seed`, `stack_round_ticks`, `spill`, `stomp_steal`,
  `stack_walk_cap`, `bot_reaction_ticks`. P2.6 (objects-B's coconut, GAMEPLAY.md 13.10.6): the shots `BALL_DRIVE_XVEL`
  144 / `BALL_DRIVE_YVEL` -128, `BALL_LOB_XVEL` 32 / `BALL_LOB_YVEL` -240, `BALL_GROUNDER_XVEL` 96, the floor bounce
  `BALL_BOUNCE_MIN_YVEL` 32 and the head bounce `BALL_HEAD_BOUNCE_MIN_YVEL` -96.
- `PlayerRun` (3.5), `InputSlot` (3.7). `Sfx`: `EXPANSION_SFX`, `EXPANSION_MUSIC` (3.9). `VersusMatch` (3.5).
  P1.1: `Defs.CURL_BALL_STATE` (= `PlayerBase.CURL_BALL`, for `hitter_slot`: a batted ball credits its batter);
  `PartyTuning.KEEPER_HALL_ROWS = 4` (64 px halls: the Guard and Shellback art is 54 px tall).
- Owners' tables of PHYSICS.md C.16: `EnemyTuning` (enemies), `MountTuning` (player-B,
  `scripts/player/mount_tuning.gd`), `ObjTuning` (objects).
- Bots (core-B, `scripts/core/bots/`, PLAN.md P1.2 / P2.5): `HeroBot` (an `InputSlot.BOT` producer: `new(slot, level,
  match_seed, mode)`, `produce(tick)`, `reset_round(seed)`, `install()` / `uninstall()`; its own SimRng, never
  Sim.rng; reaction by `Defs.BotLevel` 10 / 6 / 3 ticks), `BotNavigator`, `NavGraph` (format: the header of
  `scripts/core/bots/nav_graph.gd`; files `res://resources/bots/<level_id>.json`), `NavBaker` + `NavSim` (every link
  verified by simulating `scenes/player/player.tscn`), `GrubStackBrain`. Baker: `bash .tools/gd.sh script
  res://tools/bots/bake_nav.gd -- [ids] [--check] [--verify]`. Flow creates one HeroBot per bot seat and match (3.10).

---

## 4. Simulation rules

### 4.1 Fixed tick

- One simulation tick = one original tick: `Tuning.TICK_HZ = 1193182 / 49152 = 24.2753 Hz` (PHYSICS.md 1.2).
- The `Sim` autoload runs ticks from `_process` with an accumulator, at most `Tuning.MAX_CATCHUP_TICKS` (4) per
  rendered frame; the rest is dropped. The accumulator is cleared when the app loses or regains focus.
- **No gameplay in `_process`, `_physics_process`, timers, tweens or animation callbacks.** Everything that
  changes game state runs inside `_sim_tick(phase)`. `_process` is for visuals only.
- `Sim.start(seed)` / `Sim.stop()` are called by the level (`LevelBase.start_play`) and by Flow. Pausing the tree
  pauses the simulation; `Sim.frozen` (set by Flow while a transition covers the level) holds the clock without
  catching up afterwards. Tests and the autoplay harness use `Sim.step(n)`, which ignores both.
- `Sim.tick` = ticks since `start()`; `Sim.total_ticks` never resets (use it for once-per-tick guards);
  `Sim.alpha` = interpolation factor for rendering.
- `Sim.suspend(entity)` / `Sim.resume(entity)` take a registered entity out of the tick and put it back at its
  place in the registration order (the level's doze manager uses them, section 11). Both, and `unregister`, are
  exact in the middle of a phase: an entity taken out is not called again, one put back runs in this phase when
  its place comes after the entity being called, every other entity is called exactly once.
  `Sim.get_phase_runs(phase)` counts started phases (a dozing entity restores per-tick counters with it);
  `get_entity_count()` = registered, `get_awake_count()` = ticking.

### 4.2 Order of operations (PHYSICS.md 3)

Each tick: `GameInput.sample()`, snapshot `sim_prev = sim_pos` of every entity, then the phases in order; inside
a phase entities run in registration (spawn) order. An entity spawned during a tick starts on the next tick; an
entity freed during a tick is skipped at once.

| `Defs.Phase` | Original step | Who registers | What happens |
|---|---|---|---|
| `FX` | 1 | objects (fx) | cosmetic puffs |
| `WEAPONS` | 2 | player | weapon pass: every hero projectile, then the club box created on the previous tick, against `Kind.ENEMY` in slot order (`is_targetable()`, `take_hit`), then - if no enemy was hit - against `Kind.HITTABLE` (`is_hit_by`, `take_hit`). One target per box. A club hit while `yvel != 0` sets `yvel = -80` |
| `ENEMIES` | 3 | enemies | `EnemyBase._sim_tick` (wake / sleep / `_ai_tick`); bosses poll the hero's weapons here |
| `PROJECTILES` | 4 | `ProjectileBase` | hero and enemy projectiles move |
| `ITEMS` | 5, 6 | objects | dropped items and bones move, hazards move, score pop-ups rise (placed items count their age and bob at the start of their `CONTACT_ITEMS` step: one call per tick) |
| `PLATFORMS` | 7 | objects | platforms move, then the ride test (`PlayerBase.ride_platform`) |
| `PLAYER` | 8a-8i | player | delete the club box, read `GameInput.flags`, state, handler, integrate x then y, tile collision, glider, timers (`charge`, `swing_lock`, `drop_timer`, `feast`, and `Game.level.tick_shake_timer()`) |
| `CONTACT_ENEMIES` | 9a | player | hero versus every `Kind.ENEMY` that `is_targetable()` (and `contact_hurts`), only while `hit_timer == 0` |
| `CONTACT_ITEMS` | 9b | objects, enemies, world | each collectible, checkpoint, exit, hazard, enemy projectile and zone tests **itself** against the hero |
| `WORLD` | 10-12 | objects, world | hittable cool-downs, gates, rising columns, wind script, darkness fades |
| `CAMERA` | 13 | world | camera follow (PHYSICS.md 12) |
| `POST` | 14-17 | player, world | `hit_timer` decrement (hero: once per tick here), death sequence, level state |
| after the last phase | 18 | `LevelBase` (built in) | screen-shake step (nudge on odd ticks), the doze decisions for the next tick, then the `on_screen` flag of every ticking entity (a dozing one is off the view: false) |

Hero-versus-enemy resolution (phase `CONTACT_ENEMIES`, PHYSICS.md 9 / 10.1), for the first enemy that overlaps
with `Overlap.body(hero, enemy, hero)`:

1. `hero.is_feasting()` -> `enemy.kill(&"feast", hero)`.
2. `Overlap.stomp` and `hero.yvel >= 0`, not gliding -> `hero.bounce(Tuning.BOUNCE_YVEL_UP if UP held else
   Tuning.BOUNCE_YVEL, Overlap.depth)`, `var m := enemy.on_bounced(hero)`, `Events.player_bounced.emit(enemy, m)`.
3. Gliding and `Overlap.stomp` -> `yvel = Tuning.GLIDER_BUMP_YVEL`; with `yvel > 32` before the bump also
   `enemy.on_glider_stomp(hero)`.
4. Otherwise -> `if hero.hurt(enemy): enemy.on_hurt_hero(hero)`.

Bosses are `Kind.BOSS`: both passes skip them; a boss calls `poll_weapon_hit()` / `touch_hero()` itself.

### 4.3 Units and coordinates

- Positions: integer **logical px** (the original 320-wide screen), feet point = bottom-centre, +y down.
  Velocities: **v16** (1/16 px per tick). Timers: ticks. No floats, no `Vector2`, no seconds in gameplay state.
- Integrate with `pos += Tuning.floor16(v)`. Never `/ 16`, never `int(v / 16.0)`. Tile snaps with
  `Tuning.tile_top(y)` / `& ~15`, never `%` (negative values). A shift with a negative *constant* operand is a
  parse error in 4.7: always shift through `Tuning.floor16` / `Tuning.shr`.
- One tile = 16 logical px = 32 art px. Canvas units are **art px**: `canvas = logical * Tuning.ART_SCALE`. The
  multiplication happens in exactly two places: `SimEntity._update_visual` and the world module's tile map /
  camera. Sprite offsets inside an entity scene are authored in art px (manifest pivots).
- Pixel snapping: `SimEntity` rounds the interpolated position to whole art px; the camera rounds its final
  position to whole art px. Do not move sprites by fractions.

### 4.4 `Tuning` - the single source of truth for feel

`scripts/core/tuning.gd` holds every constant of PHYSICS.md Appendix A and the shared numbers of GAMEPLAY.md, in
original units, each with its source section, plus the helpers `floor16`, `shr`, `tile_top`, `to_cell`, `in_cell`,
`unsigned_below`, `accel_step`, `friction_step`, `cam_v_speed`, `bounce_multiplier`, `ticks_to_seconds`,
`seconds_to_ticks`, `v16_to_px_per_second`, `to_art`, `to_logical`. **No physics or timing literal may appear in
any other script**, with one documented exception: numbers that only one module uses (its own AI timings, item
physics, cosmetic cadences) live in that module's tuning table - `EnemyTuning` (`scripts/enemies/enemy_tuning.gd`)
and `ObjTuning` (`scripts/objects/obj_tuning.gd`) - each with its source mark, and nowhere else. A number another
module needs moves to `Tuning` (e.g. `V16_PER_PX`, `ANIM_TICKS_PER_SECOND`, the glider tilt and stall constants).
`tests/test_core_tuning.gd` checks the file against `PHYSICS_REFERENCE.json`.

The hero's contact boxes are the ORIGINAL frame boxes (`Tuning.HERO_BOX_*`, e.g. stand 32 x 35, x_offset 15); our
art fits inside them. `HERO_ART_BOX_*` exist for a QA comparison only.

### 4.5 Determinism

- Same level, same seed, same input flags per tick => identical state on every platform. Required for the golden
  traces and for autoplay screenshots.
- Randomness inside a tick comes from `Sim.rng` only (`next_int`, `range_int`, `chance`). No `randf`, `randi`,
  `RandomNumberGenerator`, `Time`, `OS` clock or frame delta in gameplay.
- Never iterate a `Dictionary` or `get_nodes_in_group()` to decide gameplay order; use `LevelBase.get_kind()`.
- Never depend on the order in which `_ready` runs across scenes, on signals emitted by the engine, on physics
  callbacks or on animation track callbacks.
- Animations: frame = function of tick counters (advance per tick, PHYSICS.md 15.1 #6). `AnimationPlayer` /
  `AnimatedSprite2D` may be used for purely cosmetic nodes only.

---

## 5. Scenes, nodes, layers

### 5.1 Entity scene template

```
<Name> (Node2D, script extends a base class of section 3)   # root at the FEET POINT
  Sprite (Sprite2D)      # centered = false, offset = -(pivot) from the manifest, hframes / vframes from the manifest
  ... further cosmetic children (extra sprites, GPUParticles2D, AudioStream-less)
```

- The root is the feet point. `Sprite` is the main picture; flip with `Sprite.flip_h = facing < 0` (pivots are
  horizontally centred). Enemies, items and objects name their main sprite exactly `Sprite`.
- No `CollisionShape2D`, `Area2D`, `CharacterBody2D`, `RigidBody2D`, `VisibleOnScreenNotifier2D` for gameplay.
- Scene root script class names: `Player`, and for the others `<Thing>` in PascalCase matching the file
  (`walker.tscn` -> `scripts/enemies/walker.gd` -> `class_name Walker`). Prefix when a name would collide with an
  engine class.
- Textures are referenced by scenes with `res://assets/...` paths; do not copy or re-export art.

### 5.2 Level scene tree (world module) and z order

```
Level (Node2D, extends LevelBase)              scenes/world/level.tscn - at the origin, never transformed
  Parallax (Node2D)                 z -100     backgrounds/<set>/layerN, repeat, scroll factors from the manifest
  BackTiles (TileMapLayer)          z  -50     [backwall] tiles
  PropsBack (Node2D)                z  -40     props/... layer=back
  Tiles (TileMapLayer)              z    0     terrain, 32 px cells
  Objects (Node2D)                  z   10     categories "objects", "zones"   (platforms set z 12 themselves)
  Items (Node2D)                    z   20     category "items"
  Enemies (Node2D)                  z   30     categories "enemies", "bosses"
  PlayerLayer (Node2D)              z   40     category "player"
  Projectiles (Node2D)              z   50     category "projectiles"
  Fx (Node2D)                       z   60     category "fx"
  Flies (Node2D)                    z   60     the cosmetic fly swarm (GAMEPLAY.md 7.9)
  PropsFront (Node2D)               z   70     props/... layer=front
  FrontTiles (TileMapLayer)         z   80     liquids, tiles with FLAG_FOREGROUND
  Weather (Node2D)                  z   75     snowfall while the wind blows (cosmetic)
  Camera (Camera2D)
  Darkness (CanvasModulate)
```

Constants: `Defs.Z_*`. `LevelBase.get_container(category)` returns the container for an id category. Base classes
set their own `z_index` in `_init`; containers keep `z_index = 0` and `z_as_relative = true`, so do not rely on
tree order for depth. Every container stays at position (0, 0), scale 1.

### 5.3 CanvasLayers

| Layer (`Defs.LAYER_*`) | Content | Owner |
|---|---|---|
| 0 (default) | level scene / full-screen UI screens | world / ui |
| 10 `LAYER_HUD` | `scenes/ui/hud.tscn` | ui (instantiated by Flow) |
| 20 `LAYER_TOUCH` | `scenes/ui/touch_controls.tscn` | ui (instantiated by Flow) |
| 30 `LAYER_MENU` | `scenes/ui/pause_menu.tscn`, dialogs | ui (instantiated by Flow) |
| 100 `LAYER_TRANSITION` | curtain / iris / fade | core |
| 120 `LAYER_DEBUG` | debug overlays | anyone, debug builds only |

### 5.4 Groups

| Group (`Defs.GROUP_*`) | Members |
|---|---|
| `sim_entities` | every `SimEntity` (automatic) |
| `level` | the active `LevelBase` (automatic) |
| `hud` | root of `hud.tscn` |
| `touch_controls` | root of `touch_controls.tscn` |

Groups are for tooling and UI lookups. Gameplay uses `Game.level.get_kind()`.

### 5.5 Physics layers and masks

Gameplay never touches the physics server. The named layers exist for **cosmetic** Area2D / particle collision /
ray checks only, and for editor clarity:

| Bit (`Defs.PHYS_*`) | Name | A cosmetic body on this layer represents |
|---|---|---|
| 1 | world | terrain (the world module MAY add a TileSet physics layer here for particles; optional) |
| 2 | player | the hero |
| 3 | enemies | enemies and bosses |
| 4 | items | collectibles |
| 5 | objects | hittables, checkpoints, exits |
| 6 | hazards | hazards |
| 7 | platforms | platforms |
| 8 | hero_weapons | club box, thrown weapons |
| 9 | enemy_projectiles | boss projectiles |
| 10 | triggers | zones |

Convention if you add one: `collision_layer` = your own bit only; `collision_mask` = the bits you listen to;
`monitorable = false` unless something must detect you. Nothing may depend on these for game logic.

---

## 6. Entities: naming convention and catalogue

### 6.1 Convention

An entity id is `<category>/<name>` and is the scene `res://scenes/<category>/<name>.tscn`. `Spawner`
(`scripts/core/spawner.gd`) resolves, caches and instantiates; `LevelBase.spawn(id, pos, params)` places it.
There is **no registry file**: adding an entity = adding its scene. A level that names an id whose scene does not
exist logs one warning for that id and continues without it.

Categories and owners: `player` (player), `enemies`, `bosses` (enemies), `projectiles` (`hero_*` player,
`enemy_*` / `boss_*` enemies), `objects`, `items`, `fx` (objects), `zones` (world). Ids starting with `props/` are
scenery images `res://assets/tiles/<biome>/props/<name>.png` drawn by the world loader (no scene).

Parameters arrive as `spawn_params` (String keys; values typed by `LevelText.parse_value`: int, float, bool or
String; lists are comma-separated Strings). Read them in `_apply_params(params)`; every parameter has a default.
Keys handled for every entity: `name` (lookup with `find_named`), `facing=l|r`, `expert` / `beginner` (spawn
only in that mode), `dx`, `dy` (logical px offset), `tile` (legend only, section 7.5).

### 6.2 Catalogue (ids level designers may use; the owning module must implement exactly these)

Units: `ticks`, `px` = logical px, `v16`, `tiles`. Defaults in brackets.

**Enemies** (all accept `skin=<sheet name>`, `hp` [25], `score` 0..11 [per type]; a club hit is 25, the enemy
dies when hp drops **below** 0, so hp 0..24 = one hit, 25..49 = two):

| Id | Archetype (GAMEPLAY 5.2) | Default skin | Parameters |
|---|---|---|---|
| `enemies/dropper` | 0 sky dropper, zone spawner | `egg_kid` | `zone=c,r,w,h` trigger [10 tiles around], `pause` [44], `speed` v16 [32], `max` alive [2] |
| `enemies/dangler` | 2 yo-yo dangler (2.0, co-op party: a hero's club box over its thread cuts it - it falls off, harmless, gone without points until a team wipe, GAMEPLAY.md 13.9.4; `EnemyTuning.THREAD_CUT_W` = 4 px) | `bat` | `depth` px [48], `speed` px/tick [2] |
| `enemies/lurker` | 3 ceiling dropper -> chaser | `insect` | `range` tiles [4], `pause` [22] |
| `enemies/swinger` | 4 pendulum | `bat_b` | `radius` px [40] |
| `enemies/stinger` | 5 sentry diver | `insect` | `range` tiles [6], `speed` px/tick [3] |
| `enemies/harrier` | 6 clever flyer | `pterodactyl` | `range` tiles [8] |
| `enemies/dart` | 7 kamikaze diver (one-shot) | `pterodactyl_b` | `range` tiles [8], `speed` px/tick [4] |
| `enemies/hopper` | 8 hopper | `mini_rex` | `range` tiles [6], `pause` [22], `jump_x` px/tick [3], `jump_y` px/tick [8] |
| `enemies/walker` | 9 patroller, ground | `turtle` | `left` [-3], `right` [3] tiles relative to the anchor, `speed` v16 [32] |
| `enemies/flyer` | 9 patroller, air | `bat` | `left`, `right`, `speed` as walker |
| `enemies/digger` | 10 burrower, zone spawner | `lizard` | `zone=c,r,w,h`, `pause` [44], `speed` v16 [32] |
| `enemies/leaper` | 11 arc leaper | `dragon` | `speed` v16 [48], `pause` [66] |
| `enemies/charger` | 12 edge rusher (one-shot) | `rival` | `speed` v16 [64] |
| `enemies/snapper` | stationary biter | `plant` | `range` px [42] |
| `enemies/decoration` | 1 decoration (intangible) | - | `prop=<biome>/<name>` |

**Bosses**: `bosses/brute` (`arena=<zone name>`, `left`, `right` absolute columns, `hp` [64], `speed` class 0..4
[2], `enraged` flag, `drops` [`fire_starter`]); `bosses/colossus` (`arena`, `hp` [24], `drops`
[`trophy,trophy,trophy,trophy`]; thrown weapons only, 1 hit point per hit).

**Projectiles** (spawned by code, never placed in a level): `projectiles/hero_axe`,
`projectiles/hero_boomerang` (player; `from_hero=true`, `power`, `xvel`, `yvel`, `yacc`),
`projectiles/boss_rock`, `projectiles/boss_stalactite`, `projectiles/enemy_ember` (`skin=ember|leaf`).

**Items** (all accept `dropped`, `fan=<n>` for the throw direction, `points` override):

| Id | Parameters | Effect |
|---|---|---|
| `items/food` | `index` 0..47 | score from the manifest table (100 - 1 000) |
| `items/treasure` | `index` 0..15 | 2 000 / 5 000 / 8 000 |
| `items/giant_bonus` | `index` 0..6 | 10 000 - 60 000 |
| `items/letter` | `index` 0..4 (G R U B S) | `Game.collect_letter`; completing the word drops `items/jackpot` from 112 px above the hero |
| `items/jackpot` | - | 100 000 |
| `items/feast_piece` | `index` 0..2 | `Game.collect_feast_piece`; complete = `hero.start_feast()` |
| `items/fire_starter` | - | `Game.unlock_exit()` |
| `items/heart`, `items/one_up`, `items/bone` | - | `Game.add_heart()` (stays when full), `Game.add_lives(1)`, `Game.add_bones(1)` |
| `items/skull` | - | `hero.hurt(self, Defs.HurtKind.TRAP)`, bones scattered, shake |
| `items/kill_all`, `items/grenade` | - | every on-screen enemy `kill(&"kill_all")` / `burst_into_items()`; reappear on respawn |
| `items/weapon` | `kind=club|hammer|axe|boomerang` | `Game.set_weapon`; reappears on respawn |
| `items/glider` | - | `hero.set_glider(true)`; reappears on respawn |
| `items/water_bucket` | - | food score, clears the flies |
| `items/warp`, `items/trophy` | trophy: `skin=cup|roast` [roast in a `book = 2` file, else cup] (2.0: the Great Roast of 9-3) | `Game.level.complete(&"warp")` / `complete(&"trophy")` |
| `items/code_stone` | `index` 0..3 | shows character `index` of the level's password; `Save.add_code_stone("<level>:<index>")` |
| `items/random_bonus` | `tier` 0..2 [level `bonus_tier`] | becomes a random bonus item using `Sim.rng` |

Content tokens (parameter `contents` of spots, containers, bosses): `<item name>[:<index or kind>]` joined by
commas, e.g. `food:3,treasure:8,heart,weapon:axe`; `giant` = `giant_bonus`; `random` = `items/random_bonus`.

**Objects**:

| Id | Parameters |
|---|---|
| `objects/checkpoint` | - |
| `objects/exit` | `locked` [false], `kind=exit|warp|trophy` [exit] |
| `objects/hidden_spot` | `kind=small|big` [small]; small: `count` 1..64 [3] items thrown, one per hit; big: `hits` 1..128 [3], then one giant bonus from 112 px above; `contents` [random]; `look=plain|inset|block` [plain] for solid cells; `prop=<biome>/<name>` look for air cells |
| `objects/breakable_block` | `hits` 1..64 [2], `skin=auto|dirt|cave|ice|obsidian` [auto by biome], `contents` [none]; on the last hit calls `Game.level.set_cell(col, row, ".")` |
| `objects/container` | `skin=barrel|crate|pot|chest` [crate] (2.0 `chest`: the lid opens, the chest stays - the Mimic's look), `contents` [random], `hits` [1] |
| `objects/platform` | `dir` 0..7 [2] (0 up, clockwise), `speed` px/tick [2], `travel` ticks [44], `mode=always|ride` [always], `skin=wood|ice|stone|small|cloud|driftwood` [by biome: ice -> ice, volcano / ruins -> stone, sky -> cloud, coast -> driftwood, else wood; 2.0 adds cloud and driftwood] |
| `objects/drop_platform` | `delay` ticks [0], `skin` (as `objects/platform`) |
| `objects/column` | `size=w,h` tiles (block whose bottom-left cell is the anchor), `rise` tiles, `trigger=c,r,w,h`, `shake` [7] |
| `objects/gate` | `name`, `dest=<name of a gate or marker>`, `lock=c,r` (camera cell of a single-screen room, optional), `skin=arch|hole|none` [arch]; used with Down while standing on it; not with the glider |
| `objects/marker` | `name` (invisible destination) |
| `objects/spring` | `power` v16 [-224] (optional, not in the original), `skin=flower|cap` [flower] (2.0) |
| `objects/sign` | `text=<translation key>` (2.0: at most `SignBoard.MAX_LINES` = 3 board lines; boards keep clear of every hero, the HUD row and the P2 panel, one at a time) |
| `objects/npc` | `kind=elder\|kid\|warrior` [elder], `turn` [true] (cosmetic villager: idle loop, faces a hero standing near; never hurts, not hittable, counted nowhere) |

**Zones** (world; all take `rect=c,r,w,h` in tiles): `zones/secret` (`name`), `zones/arena` (`name`, `music`
[boss], locks the camera to the rect and wakes the boss whose `arena` equals `name`), `zones/camera_lock`,
`zones/dark` (`on` [true]), `zones/kill`, `zones/autoscroll_stop`, `zones/message` (`text`), `zones/ember_rain`
(`period` ticks [22], `skin=ember|leaf` [ember]: while the hero is inside, a `projectiles/enemy_ember` falls toward
him every `period` ticks; the volcano shaft of GAMEPLAY.md 12.1), `zones/flies` (`count` [5]: dirty ground; every
visit adds flies to the cosmetic swarm around the hero, at most `Tuning.MAX_FLIES`; `items/water_bucket` and a
respawn clear them, GAMEPLAY.md 7.9).

**FX** (objects; cosmetic, free themselves): `fx/dust`, `fx/star_puff`, `fx/hit_stars` (2.0: `row=<n>` - versus hit
sparks in a player's colour, row n of `sprites/fx/hit_stars_players.png` in `UiPlayers.PALETTE_COLOURS` order; without
it the 1.0 sheet; presentation only), `fx/poof`,
`fx/explosion`, `fx/explosion_big`, `fx/ring`, `fx/splash` (`kind=water|lava`), `fx/debris`
(`kind=rock|wood|ice|leaf`, `count`), `fx/popup` (`kind=score|multiplier|one_up|heart`, `value`; rises 1 px per
tick for 44 ticks).

**Player**: `player/player` (spawned by the level at `@`, never listed in a level file).

#### 6.2.1 Catalogue additions of 2.0 (level format 2, 7.11; DESIGN.md appendix, LEVEL_DESIGN.md 15.4)

Rules in GAMEPLAY.md 13 and PHYSICS.md Appendix C; owners in 1.1. The ids below are in the validator's catalogue
(`LevelValidator.CATALOGUE`); until an owner builds its scene the validator warns "no scene" (warning only).

Every enemy and boss also takes the co-op parameters (only in `kind = coop` files):
`coop=shell|bond|daze|heavy|lone|grab|leech|split` (`EnemyBase.coop_trait`), `bond=<name>` (linked records;
`EnemyBase.bond`), `keeper=<name>` (the group a keeper door waits for; `EnemyBase.keeper`), `perch=c,r` (the
pit-side perch of a `grab` record).

| Id | What (GAMEPLAY 13) | Parameters |
|---|---|---|
| `enemies/roller` | walks; curls 14 ticks and rolls at a hero in range; dizzy after a wall | `range` tiles [6], `speed` v16 [64], `dizzy` ticks [33], `left` / `right` [-3 / 3] |
| `enemies/guard` | patrols with a shield that turns only every `turn` ticks; front hits glance | `turn` [33], `left` / `right` [-3 / 3] |
| `enemies/mimic` | a chest that bites within 2 cells; dies from behind or after a head bounce; drawn as the `objects/container skin=chest` closed chest (box 24 x 18) | `contents` [`treasure`], `range` px [42] |
| `enemies/shellback` | co-op only: Guard + `shell`; `skin=turtle\|turtle_b` is the Book I variant: a Walker + `shell` (walker speed [32], score [0], no Guard clock) | as `guard` (+ `speed`) |
| `enemies/raptor` | co-op only: Hopper + `daze` | as `hopper` |
| `enemies/snatcher` | co-op only: Dangler or Stinger + `grab` | `kind=dangler\|stinger` (dangler: `bat_b`; stinger: the gull once art-B's sheet lands, else `pterodactyl_b`), `depth`, `speed`, `range` |
| `enemies/leech` | co-op only: Lurker + `leech` | as `lurker` |
| `enemies/bull_rex` | co-op only: Charger + `heavy` | `speed` |
| `enemies/tar_splitter` | co-op only: the Walker form + `split` (the falling blobs are `enemies/dropper coop=split skin=slime`) | `left`, `right`, `speed` |
| `enemies/shaman` | co-op only: patroller that shields enemies within 64 px (a co-op party only: the bone shield) | `left`, `right`, `speed` [48] |
| every `coop=bond\|split\|daze` record (`enemies/raptor`, `enemies/tar_splitter` ...) | the co-op window | `window` ticks: a cap - effective = min(the difficulty's value, `window`); a bond uses its smallest |

**Bosses** (one fixed arena each, GAMEPLAY 13.6): `bosses/tusker`, `bosses/mangrove`, `bosses/squid`, `bosses/idols`,
`bosses/roc` (`arena=<zone name>`, `hp`, `drops` [`fire_starter`]); `bosses/chieftain` (two records, `name=` and
`mate=<the other's name>`, `arena`, `drops` [`trophy`] on the second). The Brute and the Colossus gain their co-op
forms (DESIGN.md B.7) in `w2_l2b_coop` / `w4_l2b_coop`, with the same parameters.

**Projectiles**: `projectiles/hero_spear` (player-B; `owner`, thrown flat 12 px/tick, sticks in bark boards).

**Items**: `items/painting` (`index` 0..29: 0-19 the Book II levels, 20-29 the Book I co-op files; profile-wide,
`Save.add_painting`); `items/weapon` gains `kind=spear` and the flag `temp` (versus: a temporary special that goes onto
the belt). Content tokens: `weapon:spear`, `painting:<index>`.

**Objects** (`*` = arenas only; "co-op" = co-op files):

| Id | Parameters |
|---|---|
| `objects/vine` | `length` cells [4], `rolled` [false]; the anchor cell's top is the vine's top |
| `objects/bark_board` | `face=l\|r` [the side with air]; placed in a wall cell (`tile=#` in its legend entry) |
| `objects/spear_step` | spawned by a bark board when a spear sticks (never placed) |
| `objects/geyser` | `period` ticks [88, at least 34], `delay` [0], `power` v16 [-224], `skin=mud\|blowhole\|steam\|soda`, `deadly` |
| `objects/raft` | `width=3\|4` [3], `skin=log\|wafer`, `rails`; placed on the top `~` row |
| `objects/mount` | `kind=rex`, `pen=<name>`, `wild` |
| `objects/rex_pen` | `name` |
| `objects/plate` (co-op) | `name`, `count=1\|2` [1], `mode=hold\|timed:<ticks>\|latch` [hold], `w` cells [2] |
| `objects/drum` (co-op) | `bond=<name>`, `skin=drum|cap` [drum] |
| `objects/seesaw` (co-op, arenas) | `len` cells [5], `skin=wood|mushroom|floe` [wood] |
| `objects/boulder_heavy` (co-op) | - (2 x 2 cells, anchored at its bottom-left cell) |
| `objects/pulley` (co-op, arenas) | `a=<platform name>`, `b=<platform name>`, `range` rows [3] |
| `objects/flower_pot` (co-op) | - (on a ledge's edge cell: the drop gift) |
| `objects/x2_tablet` (co-op) | `gate=<name>`, `far=c,r` (the cell beyond the gate), `secret` (marks an x2 secret) |
| `objects/hero_start` (co-op) | `slot=2..4` (player number; a loader marker, never spawned, ignored in single-player) |
| `objects/spawn_point` * | `index=2..4` (`@` is spawn 1; the loader also reads its cell as that player's start, `LevelBase.start_positions`, unless an `objects/hero_start` names him) |
| `objects/cookpot` * | - |
| `objects/coconut` * | - (Clubball's drop point) |
| `objects/crate_lane` * | `rect=c,r,w,h` (pterodactyl crates) |
| `objects/column` (+) | `rise_while=<plate>[,...]`, `sink_while=<plate>[,...]`, `trigger=keepers:<name>` (every enemy tagged `keeper=<name>` dead), `trigger=drums:<bond>` (that drum bond struck in its window); `rise=0` with `expert` = a static Expert-only block |
| `objects/gate` (+) | `needs=<bond>` (locked until that drum bond succeeds); co-op: the team rules (both heroes travel) |
| `objects/exit` (+) | co-op: the team exit (GAMEPLAY 13.9) |

**Zones**: `zones/current` (`rect`, `dir=l|r|u|d`, `speed` 1..3 px/tick), `zones/lightning` (`rect`, `period`,
`delay` [0], `mark` [22]), `zones/food_rain` (`rect`, `period`, `skin`: the ember rain with food), `zones/goal` *
(`rect`, `team=1|2`; `GoalZone`, `scenes/zones/goal.tscn` since G2: data only - `Coconut.goal_team()` reads it, the
Clubball referee falls back on the file records with the same rectangle).

2.0 hooks added at the G2 integration: `BossBase._drop_origin()` (where the level's `drops` come out; default
`_burst_origin()`, so every 1.0 boss is unchanged; Old Mangrove drops on the floor in front of its trunk) and
`Raft.catch_sinking(level, hero)` (called by the hero's tile collision on a liquid floor cell only: a hero whose own
move carried his feet past a raft's deck rides it instead of drowning; a level without rafts kills as before).

---

## 7. The level file format (format 1; format 2 of 2.0 in 7.11)

### 7.1 Files

- One level = one text file `levels/<id>.lvl`, UTF-8, LF line endings, at most 256 x 192 tiles, at least 20 x 12.
- `<id>` is lower_snake_case and equals the `id` key. Campaign ids: `w<world>_l<stage>` (`w1_l1` ... `w4_l2`),
  sub-stages `w2_l2b`, bonus stages `bonus_a`, `bonus_b`, `bonus_c`, ending `ending`. Developer levels start
  with `test_` and are never exported.
- The registry finds files by scanning the folder. There is no index file to edit.

### 7.2 Syntax

```
# comment line (first non-blank character is '#'); blank lines are ignored
[section]            # lower-case name in square brackets, alone on its line
key = value          # in [meta]
```

- Sections may appear in any order; a repeated section is concatenated. Unknown sections are ignored with a
  validator warning.
- Outside `[tiles]` lines are trimmed. There are **no inline comments**.
- Inside `[tiles]` every line is a row and every character is a cell: nothing is trimmed, `#` is a tile, a space
  is air. Completely empty lines are skipped. `[` and `]` are not tile characters.
- Values (`LevelText.parse_value`): `true` / `false` -> bool; integers without leading zeros -> int; decimals with
  a point and no exponent -> float; `"quoted"` -> String without quotes; everything else -> the trimmed String.
  Lists are comma-separated without spaces (`16,2,6,3`). Keys starting with `password` are always Strings.
- Parameters are whitespace-separated tokens `key=value`; a bare word is a flag (`expert` = `expert=true`).
  Values must not contain spaces.

### 7.3 `[meta]` - header

| Key | Type | Default | Meaning |
|---|---|---|---|
| `format` | int | required | `1` |
| `id` | String | required | equals the file name |
| `name` | String | `id` | display name (later a translation key) |
| `kind` | `main` `sub` `bonus` `ending` `test` | `main` | `sub` = linked second half; `test` = developer level |
| `order` | int | - | world-map order of `main` levels (10, 20, ...); levels without it are not on the map |
| `world`, `stage` | int | 0 | for the world map and the level intro |
| `biome` | `jungle` `cave` `ice` `volcano` `feast` `village` | `jungle` | prop folder, debris and breakable-block look |
| `terrain_a`, `terrain_b` | atlas path under `assets/tiles` without extension | required, `terrain_a` | e.g. `jungle/terrain_grass`; the two terrain sets `#` / `%` draw from |
| `ice_a`, `ice_b` | 0..3 | 0 | slipperiness of every floor of that set (PHYSICS.md 7) |
| `liquid` | `water` `lava` `ice_water` | `water` | picture of `~` cells |
| `background` | `jungle` `cave` `ice` `volcano` `volcano_shaft` `feast` `none` | by biome | parallax set |
| `music` | a `Sfx.MUSIC_*` context name | by biome | e.g. `level_jungle` |
| `time` | int seconds | 0 | time limit; 0 = none (the original has none). When > 0 the HUD shows it and running out costs a life |
| `password_beginner`, `password_expert` | 4 characters `0-9A-Z` | "" | level code per mode (code-entry screen, code stones) |
| `next` | level id | "" | explicit next level; empty = next `main` level by `order` (a `sub` level: the one after its main level) |
| `tally` | bool | true | false = first half of a linked pair: the exit leads to `next` without a tally |
| `bonus` | level id | "" | bonus stage the warp item of this level leads to |
| `min_difficulty` | `beginner` `expert` | `beginner` | `expert` = not playable in Beginner (Beginner wall) |
| `scroll` | `normal` `vertical` `autoscroll` | `normal` | `vertical` = no horizontal follow; `autoscroll` = 1 px/tick down (PHYSICS.md 12) |
| `low_band` | bool | false | scroll flag bit 0: alternative vertical band, no hard-landing hop |
| `home_row` | int | -1 | camera home row (PHYSICS.md 12.2 #6); -1 = none |
| `fast_vscroll` | bool | true when `background` is not `none` | which vertical camera curve to use |
| `dark` | bool | false | level starts dark |
| `wind` | `tick:value,tick:value,...` | "" | wind script (PHYSICS.md 13.1): value from that tick on |
| `bonus_tier` | 0..2 | by world | table used by `items/random_bonus` |
| `author`, `notes` | String | - | ignored |

**Difficulty variants.** Any key may be followed by `.beginner` or `.expert` (`time.expert = 120`); the variant
overrides the plain key in that mode (`Levels.get_value(id, key, default, difficulty)`).

### 7.4 `[tiles]` - the grid

One character per 16 x 16 logical px cell. Row 0 is the top row; rows may be shorter than the widest row (padded
with air). Fixed legend (`TileGrid.CH_*`; collision is implemented in `TileGrid` and is binding):

| Char | Meaning | FLOOR | SIDE | Ceiling | Notes |
|---|---|---|---|---|---|
| `.` or space | air | - | - | - | |
| `#` | solid ground, terrain set A | floor (ice_a) | wall | solid | auto-tiled |
| `%` | solid ground, terrain set B | floor (ice_b) | wall | solid | auto-tiled |
| `;` | invisible solid | floor | wall | solid | nothing drawn (under breakable blocks) |
| `-` | one-way platform, set A | floor (ice_a) | - | - | jump through from below |
| `=` | one-way platform, set B | floor (ice_b) | - | - | |
| `_` | hatch | hatch | - | - | floor that crouching / crawling drops through |
| `/` | slope rising to the right, 45 degrees | floor | - | - | surface offsets 15..0 |
| `\` | slope rising to the left, 45 degrees | floor | - | - | offsets 0..15 |
| `1` `2` | gentle slope rising to the right: low half, high half | floor | - | - | offsets 15..8, 7..0 |
| `3` `4` | gentle slope rising to the left: high half, low half | floor | - | - | offsets 0..7, 8..15 |
| `^` | floor spikes | deadly | - | - | |
| `!` | ceiling spikes | - | - | deadly | |
| `~` | liquid (meta `liquid`) | deadly | deadly | - | no swimming; animated |
| `\|` | invisible wall | - | wall | - | arena limits |
| `+` | invisible kill cell | deadly | deadly | - | |
| `@` | hero start (exactly one) | air | | | feet at the bottom-centre of the cell |
| `?` `*` `$` | shortcut entities, section 7.5 | | | | |
| letters | entities from `[legend]` | air unless `tile=` | | | |

Rules:

- A slope cell must stand directly on a solid cell (`#` or `%`); it takes that cell's terrain set and ice level.
  Read left to right, a hill is `./##\.` on one row and a gentle ramp is `.12##34.`. Slopes are never walls.
- All floors are one-way from below unless the cell is also a ceiling (`#`, `%`, `;`), exactly as PHYSICS.md 11.1.
- Liquids and spikes are deadly tiles handled by the hero's tile collision; they are not entities.
- Level bounds: the hero's x is limited to `8 <= x < min(4088, cols * 16 - 8)`; falling more than one tile below
  the last row is a pit death. Close the left and right ends with solid columns or `|` unless a pit is intended.

Visual auto-tiling (world module; atlas indices of ASSET_MANIFEST 10.1). "Solid-like" = `#` or `%`; cells outside
the map count as solid-like; for the left / right tests slope characters also count as solid-like.

| Cell | Tile |
|---|---|
| `#` / `%` directly under a slope | `/` 19, `\` 20, `1` 21, `2` 22, `3` 24, `4` 25 |
| `#` / `%`, nothing solid-like above | 0 if only the right neighbour is solid-like, 2 if only the left, else 1 |
| `#` / `%`, solid-like above, not below | 16 / 18 / 17 by the same left-right rule (26 instead of 17 when `hash % 4 == 0`) |
| `#` / `%`, solid-like above and below | 8 if the left neighbour is open, else 10 if the right is open, else 9 (23 when `hash % 8 == 0`) |
| `-` / `=` | 27 left end, 29 right end, 28 otherwise (an end = neighbour is neither one-way nor solid-like) |
| `_` | 28 of set A (use `[overrides]` for a distinct look) |
| `/` `\` `1` `2` `3` `4` | 5, 6, 11, 12, 13, 14 of the set of the cell below |
| `^` / `!` | 38 / 39 of set A |
| `~` | liquid strip: frames 0-5 (4 ticks per frame) when the cell above is not `~`, else 6 (7 when `hash % 4 == 0`) |
| `;` `\|` `+` `@` | nothing |

`hash = ((col * 73856093) ^ (row * 19349663)) & 0x7FFFFFFF`. `LevelBase.set_cell()` re-tiles the changed cell and
its eight neighbours.

### 7.5 `[legend]` - entities placed in the grid

```
<char> = <entity id> [key=value ...] [flag ...]
```

`<char>` is one letter `A-Z` / `a-z`, or one of `?`, `*`, `$`. Every occurrence of the character in `[tiles]`
spawns the entity with its **feet point at the bottom-centre of that cell** (`LevelText.cell_to_feet`): put an
enemy letter in the air cell just above the floor it stands on. The cell itself is air, unless the entry has
`tile=<fixed legend char>` (e.g. a hidden spot inside the ground: `tile=#`).

Built-in entries (a level may redefine them):

```
? = objects/hidden_spot kind=small count=3 tile=#
* = objects/hidden_spot kind=big hits=3 tile=#
$ = objects/breakable_block hits=2 tile=;
```

Props use the same mechanism: `b = props/jungle/bush_big layer=back` (`layer=back|front` [back], `flip`). Props
are anchored bottom-centre in the cell; the ceiling pieces listed in ASSET_MANIFEST 10.4 (`stalactite`, `drips`,
`drip_cap`, `icicle`, `vine_a`, `vine_b`, `moss_fringe`) are anchored top-centre at the top of the cell.

### 7.6 `[entities]` - entities with free positions

```
<entity id> <col> <row> [key=value ...] [flag ...]
```

`col` / `row` may be decimals (`18.5 2`); the feet point is the bottom-centre of that (fractional) cell. Use this
section for zones, things between cells, and anything that needs a rectangle or a name:

```
zones/arena 40 10 name=brute_pit rect=36,2,24,12 music=boss
bosses/brute 52 11 arena=brute_pit left=38 right=58 hp=64
objects/gate 12 9 name=cave_in dest=cave_out
objects/gate 70 30 name=cave_out dest=cave_in lock=64,22
```

### 7.7 Hidden bonuses, checkpoints, secrets, boss arenas

- **Hidden spots**: `?` / `*` or a legend letter with `objects/hidden_spot`. Solid look: the cell is `tile=#` and
  looks like ordinary terrain (`look=inset` draws atlas tile 15, `look=block` tile 7, until opened). Scenery
  look: `prop=<biome>/<name>` on an air cell. `contents` lists what a small spot throws out (cycled) or what a
  big spot drops; `random` uses the level's bonus tier. Spots that touch (8-neighbourhood) open together
  (GAMEPLAY.md 4.4); each counts for the completion percentage.
- **Breakable blocks**: `$`; solid until broken; walls of secret passages are columns of `$`.
- **Checkpoints**: `objects/checkpoint`. The first is optional; a level without any respawns at `@`.
- **Exit**: exactly one `objects/exit` per level (bonus stages and warps: `items/warp`; final boss:
  `items/trophy` dropped by the boss). `locked=true` requires `items/fire_starter` (placed, or dropped by a boss).
- **Secret areas**: `zones/secret name=<id> rect=c,r,w,h`; counted once when the hero's feet enter the rectangle.
- **Boss arena**: `zones/arena` + a boss with the same `arena` name, plus `|` walls for the arena limits. The
  Wall Colossus level must place `items/weapon kind=axe` next to its checkpoint (GAMEPLAY.md 12.1).
- **Completion totals** = number of hittables with `counts_for_completion` + number of map-placed items with
  points; the loader reports them with `Game.add_completion_totals()`.

### 7.8 `[backwall]` and `[overrides]` (visual only)

```
[backwall]
<col> <row> <w> <h> [set=a|b] [deco=<0..100>]
[overrides]
<col> <row> <set a|b> <atlas index> [layer=back|main|front]
```

A backwall rectangle draws atlas tile 35 behind every cell of the rectangle that is not `#` / `%` (`deco` percent
of the cells use 36 / 37 instead, chosen by `hash`). An override draws an explicit atlas tile in a cell without
touching collision (pillar caps 3 / 4, fringes 30-33, decor).

### 7.9 Validation (world module, `tools/validate_levels.gd`)

A level is valid when: `format` is 1; `id` equals the file name; size within 20..256 x 12..192; every row
character is a fixed legend character or defined in `[legend]`; exactly one `@`; every slope stands on `#` / `%`;
every entity id has a known category and (warning only) an existing scene; every `dest`, `arena`, `next`, `bonus`
reference resolves; exactly one exit path (a missing exit is only a warning in a `kind = test` level); `music` is
a known context; passwords are unique across levels and
modes; at most 150 enemies, 70 placed items, 80 hittables, 16 platforms; the start cell is air above a floor.
The validator prints `file:line: message` and exits non-zero on errors.

### 7.10 Complete example

`levels/test_example.lvl` (36 x 14 tiles) is a complete, valid level that uses every section; the test suite
loads it. Excerpt (some header keys, legend entries and the three empty top rows are left out here - read the
file for the full text):

```
[meta]
format = 1
id = test_example
name = "Example Meadow"
kind = test
biome = jungle
terrain_a = jungle/terrain_grass
terrain_b = jungle/terrain
background = jungle
music = level_jungle
password_beginner = "C1UB"
...
[legend]
T = enemies/walker skin=turtle left=-3 right=3 speed=16 hp=25 score=0
H = enemies/hopper skin=mini_rex range=6 expert
C = objects/checkpoint
E = objects/exit locked=false
...
[tiles]
..................d.................
.................---_...............
....................................
..........f.f..............L........
.........-----.....P......===.......
....................................
...................../##\...........
.@..b..S.T...g..C.../####\..H.$d..E.
########?####*####~~################
##################~~################
####################################
[entities]
zones/secret 17 3 name=sky_ledge rect=16,2,6,3
items/heart 18.5 2
[backwall]
21 9 4 2 set=a deco=25
[overrides]
22 9 a 3
```

### 7.11 Level format 2 (2.0 "The Far Shore")

Format 2 is format 1 plus new `[meta]` keys, one tile character and the ids of 6.2.1; the syntax (7.2) is unchanged
and a format-1 file loads exactly as in 1.0 (the 15 Book I files build the same collision grids:
`tests/fixtures/book1_grid_hashes.txt`). New files say `format = 2` (LEVEL_DESIGN.md 15.1); the validator warns about
format-2 keys or the tar floor in a format-1 file. Ids: Book II `w5_l1` ... `w9_l3`, `bonus_d`, `bonus_e`,
`ending_b`; co-op files `<id>_coop` for every one of the 35 stages; arenas `arena_<name>`.

New `[meta]` keys (LevelText.META_KEYS_2; each may take `.beginner` / `.expert` variants):

| Key | Type | Default | Meaning |
|---|---|---|---|
| `book` | int `1` / `2` | `1` | the book whose campaign, map and codes the file belongs to (every 1.0 file: 1) |
| `belt` | `fresh` / `carry` | `fresh` for `book = 2` and `kind = coop`, else `carry` | `fresh`: every stage starts with the club in hand (PHYSICS.md C.2); `carry`: the 1.0 weapon rule (`LevelText.default_belt`, `Levels.get_belt_rule`) |
| `kind` | + `coop`, `arena` | | `coop`: the co-op version of `coop_of`; `arena`: a versus arena. Neither appears in a solo registry query, arenas in no campaign |
| `coop_of` | level id | required for `coop` | the solo level (its campaign stop) |
| `coop_base_hash` | sha256 hex (always a String) | required for `coop` | the solo file's hash when the co-op file was made (drift warning: world-B) |
| `players` | int `2`..`4` | required for `arena` | most players the arena is built for |
| `round_time` | int seconds | `90` | arena round length |
| `modes` | list of `Defs.VERSUS_MODE_NAMES` | required for `arena` | the versus modes the arena supports |
| `wrap` | `none` / `lr` / `tb` | `none` | arena edges joined left-right or top-bottom |
| `sudden` | `stampede` `cave_in` `whiteout` `lava_rise` `tar_rise` `high_tide` `syrup_flood` `stalactites` `rockslide` `lightning` | by biome (world-B) | the arena's themed sudden death |
| `liquid` | + `tar`, `honey`, `syrup` | | look of `~` and of `:` (deadly as water) |
| `scroll` | + `rising` | | the rising tide (PHYSICS.md C.8; `Defs.SCROLL_RISING`) |
| `rise_speed` | int v16 per tick | `16` | speed of the rising band (1 px/tick) |
| `wind` | `tick:value,...` | | values may be negative (wind to the right, PHYSICS.md C.6) |
| `wind_loop` | int ticks | `0` | the wind script restarts every that many ticks |
| `biome` | + `canyon`, `swamp`, `coast`, `ruins`, `sky` | | the Book II worlds (terrain `<biome>/terrain`; their backdrop and music defaults come with their art and AudioTable rows: set `music` explicitly) |

New tile (TileGrid, 3.2):

| Char | Meaning | FLOOR | SIDE | Ceiling | Notes |
|---|---|---|---|---|---|
| `:` | tar floor, set A | floor (ice_a), surface 6 px lower (`PROFILE_TAR`) | wall | solid | `material_at` = `MATERIAL_TAR`: heroes wade and hop (PHYSICS.md C.5), ground enemies are slowed, dropped items stop; drawn in the level's `liquid` skin (world-A) |

Registry rules (3.8): campaigns per book (`get_campaign(difficulty, book)`); the co-op campaign = the solo campaign of
the book with every stop replaced by its co-op file (`get_coop_campaign`, `get_coop_level`, `level_for_mode`); a co-op
file continues with the co-op file of its solo level's successor and records its result at the solo stop; co-op files
have no codes (a code never leads into one); arenas: `get_arenas(players, mode)`. Validation (7.9, plus): `format`
1 or 2; the new keys and values; a co-op file needs `coop_of` (an existing level) and `coop_base_hash` (64 hex
digits), an arena `players` and `modes`; an arena needs no exit; the new ids and parameters of 6.2.1. The content
rules of co-op and versus files (traits only in co-op files, x2 tablet pairing, plate distances, hall heights, drift,
arena geometry, spawns) are world-B's (PLAN.md P1.7).

Excerpt of a Book II co-op file:

```
[meta]
format = 2
id = w5_l1_coop
kind = coop
book = 2
coop_of = w5_l1
coop_base_hash = 3f1c...e9   (64 hex digits)
biome = canyon
terrain_a = canyon/terrain
music = level_canyon
[legend]
R = enemies/roller coop=shell keeper=gate1
[tiles]
...
.@.....R....::::...
###################
[entities]
objects/hero_start 3 9 slot=2
objects/x2_tablet 20 9 gate=ledge far=30,3
```

---

## 8. Module contracts

Every module: owns its `tests/test_<module>_*.gd`; consumes only the APIs of section 3 and the ids of section 6;
never references another module's script classes or scene internals.

### 8.1 core

Responsibilities: the skeleton implementations (done: curtain and iris transitions with `Flow.play_covered`, music
resume position for `pop_music`, rebinding API and persistence of bindings, focus / background handling, export
presets for Windows / macOS / Android / iOS), `Tuning` additions requested by other modules, keeping `test_core_*`
green; build and release tooling (`tools/build_windows.ps1`, `README.md`, `docs/BUILD.md`, `docs/PORTING.md`).
Provides: everything in section 3 except the base files owned by others. Consumes: nothing from other modules
(only scenes by naming convention).

Integration (core): `levels/test_integration.lvl` (jungle, 120 x 40: every system once) and
`levels/test_integration_boss.lvl` (the Brute arena) were `kind = main` with `order` 10 / 20 (the playable stand-in
campaign of debug builds) until the level designers' `w1_l1` ... arrived; they are now `kind = test`, linked by
`next = test_integration_boss`, so the world map shows only the real campaign. `tools/autoplay/full_loop.flow`
enters the pair with `start_level` after the title, mode select and world map. Exports exclude them with every
`levels/test_*.lvl`. Their input scripts (`tools/autoplay/integration_level.inputs`, `integration_boss.inputs`) are
replayed tick for tick by `tests/test_integration_levels.gd` and by the flow scripts of section 9.2.

The campaign (integration): eight map stops in `order` 10..80 - `w1_l1`, `w1_l2`, `w2_l1`, `w2_l2` (+ sub-stage
`w2_l2b`, the Brute), `w3_l1` (+ `w3_l1b`), `w3_l2`, and for Expert only `w4_l1`, `w4_l2` (+ `w4_l2b`, the Wall
Colossus, whose trophy leads to the `ending` stage). The warps of `w1_l2`, `w2_l1` and `w3_l2` lead to `bonus_a`,
`bonus_b` and `bonus_c`; a Beginner run ends at the expert wall after `w3_l2`. `tests/test_campaign_routes.gd` is
the data-driven route suite: its `ROUTES` table describes every file of `tools/autoplay/routes/` (level, modes, how
it ends, what follows, what it must achieve) and replays each one through Flow and the real level scene; its two
campaign tests play the whole game in one run per mode with everything a run carries, and are the headless twins
of `tools/autoplay/campaign.flow` (Expert, title to credits) and `campaign_beginner.flow` (code to the expert
wall). A run keeps its weapon from level to level, and a swing locks the hero for the weapon's recovery, so a route
recorded with the club drifts with another weapon: every (stage, difficulty, weapon a run can bring) cell has a route
of its own (`<id>[.expert].<weapon>.inputs`), `test_every_weapon_a_run_can_bring_has_a_route` derives the cells from
where the weapons lie and demands exactly one route each, and both campaigns (headless and the flows) play every
stage with the route of the weapon the run really carries - no weapon is ever handed over. Every route replay also
fails on any engine warning or error. Route-building aids: `CAMPAIGN_PROBE` / `CAMPAIGN_ADAPT` / `CAMPAIGN_REPAIR`
there, the sync / adapt jobs of `tests/test_route_tools.gd`, the repair and Colossus-bot aids of
`tests/test_enemies_colossus.gd`.

**2.0 route proofs (integration, PLAN.md P0.9 and 8 V2 / V3).** New routes describe themselves: the first line of
the file is a `# route:` header (`docs/LEVEL_DESIGN.md` 15.9, read by `Autoplay.parse_route_header`) instead of a
`ROUTES` entry; a header route is no 1.0 route (`test_every_route_file_is_described` skips it). Party routes hold one
key set per player (`8:R|R,10:RU|,4:DF|DF`, `Autoplay.parse_inputs_multi`). The tables are found, not written:
`tests/test_book2_routes.gd` takes every header route of a Book II solo level, `tests/test_coop_routes.gd` every
`players=2` route of a co-op file, `tests/test_coop_gates.gd` every `objects/x2_tablet gate=` of a co-op file (it
calls world-B's `scripts/world/coop_search.gd` `search_gate(level_id, difficulty, gate) -> {"reached", "bound",
"windows", "detail"}`; a gate without the search fails). Each header route is replayed through Flow by the bench
(`sim_bench_runner.gd` `replay()`, the code of the identity proof) by `RouteTestCase`
(`tests/test_integration_route_case.gd`): its run (a party of `players`, the level's book, its `belt`), how it ends,
what follows, every `expect` key (`Autoplay.ROUTE_EXPECT_KEYS`: the 1.0 keys plus `painting`, `wipes`, `eggs`,
`hatches`, `x2_gates`), no engine warning; the belt invariance (every club route with the hammer, axe, swirling axe
and spear on every belt, identical digests) and, for co-op routes, determinism (twice, without dozing, on other
devices). The fixture routes `tests/fixtures/routes/*.inputs` play `levels/test_core_party.lvl` (the bare two-hero
level of the phase-0 exit) and prove the harness in `tests/test_integration_harness.gd`.

### 8.2 player

Responsibilities: `Player extends PlayerBase` reproducing PHYSICS.md sections 4-11 and 13 tick for tick; the
state table; strikes, club boxes, charge, thrown weapons; the hero-side of bounces, damage, death, respawn;
hang-glider; animation from the manifest (`assets/sprites/player/hero*.png`, 176 x 112 cells, pivot (88, 96)).

Must provide:

- `scenes/player/player.tscn`: root `Player` (script `scripts/player/player.gd`, `class_name Player`), children
  `Sprite` (Sprite2D, hframes 8, vframes 7, `centered = false`, `offset = (-88, -96)`), `GliderSprite`.
- `_sim_phases()` = `WEAPONS`, `PLAYER`, `CONTACT_ENEMIES`, `POST`, implemented as in section 4.2.
- Real bodies for every `PlayerBase` method, keeping the documented effects; `club_box*` fields valid after the
  `PLAYER` phase of the tick that created the box; `Events.player_*` emitted; `Events.player_death_finished`
  after `Tuning.DEATH_ANIM_TICKS`.
- `scenes/projectiles/hero_axe.tscn`, `hero_boomerang.tscn` (scripts extend `ProjectileBase`, `from_hero = true`),
  at most `Tuning.MAX_THROWN` in flight.
- Texture swap on `Game.weapon_changed`; sounds through `Audio.play_sfx(Sfx.*)`.

May consume: `GameInput.flags`, `Game`, `Game.level` (`grid`, `wind`, `scroll_flags`, `get_view_rect`,
`get_camera_cell`, `get_kind`, `spawn`, `spawn_fx`, `tick_shake_timer`, `request_shake`), `EnemyBase`,
`HittableBase`, `Overlap`, `Tuning`, `Sim`, `Audio`, `Events`.

### 8.3 enemies

Responsibilities: shared enemy rules in `EnemyBase` (slots, hits, flash, knock-back, death arc, bone burst,
feast swap, Expert flag); one script per archetype of GAMEPLAY.md 5.2; every enemy id of section 6.2 with every
skin of ASSET_MANIFEST 4; both bosses (GAMEPLAY.md 6.1, 6.3) with energy bars through `Events.boss_*`; boss
projectiles and falling embers.

Must provide: `scenes/enemies/<name>.tscn` for all 15 enemy ids, `scenes/bosses/brute.tscn`,
`scenes/bosses/colossus.tscn`, `scenes/projectiles/boss_rock.tscn`, `boss_stalactite.tscn`, `enemy_ember.tscn`.
Enemy ground physics uses `Game.level.grid` (`TileGrid.is_ground`, gravity `Tuning.ENEMY_GRAVITY`).
May consume: `PlayerBase` (read state, `hurt`, `bounce`, `notify_weapon_hit`), `Game.level`, `Overlap`, `Sim.rng`,
`Tuning`, `Audio`, `Events`, item ids through `Game.level.spawn`.

### 8.4 objects

Responsibilities: every item, object and fx id of section 6.2: collectibles and their effects, dropped-item
physics (gravity, half-height bounces, 198 tick life, blink), hidden spots with flood-fill opening, breakable
blocks, containers, movers and droppers, rising columns, gates, checkpoints, exits, springs, hazards, power-ups
(feast kit, grenade, kill-all, skull, weapons, glider), score pop-ups and all particles / puffs.

Must provide: the scenes for all ids; bodies of the six base files it owns. Tile changes go through
`Game.level.set_cell` / `set_cell_look`. May consume: `PlayerBase`, `EnemyBase` (`kill`, `burst_into_items`),
`Game`, `Game.level`, `Overlap`, `Sim.rng`, `Tuning`, `Audio`, `Events`.

### 8.5 world

Responsibilities: `scenes/world/level.tscn` (root `Level extends LevelBase`, tree of section 5.2); the loader
(sections through `LevelText`, collision through `TileGrid.from_rows`, visuals by the auto-tiling table); the
TileSets built from the 40-index atlases (code-generated or `.tres` under `resources/world/`); liquids; back
walls; props; parallax (`assets/backgrounds`, scroll factors and 1600 px loops from the manifest); the camera of
PHYSICS.md 12 on tile cells with render interpolation; level bounds; entity spawning (legend + `[entities]`,
difficulty flags, hero at `@`); zones; wind script; darkness; completion totals; music start
(`Audio.play_music(meta.music)`); `tools/validate_levels.gd`.

Must provide: real bodies / overrides for `get_view_rect`, `get_camera_cell`, `get_container`, `set_cell`,
`set_cell_look`, `lock_camera`, `unlock_camera`, `snap_camera`, `set_darkness`, `respawn_player` (curtain:
wrap the base body in `Flow.play_covered(..., Defs.Transition.CURTAIN)`, section 3.10), and the scenes for all
zone ids.

Camera with a variable view (PHYSICS.md 15.3): `cols = ceil(view_w / 16)`, `rows = floor(view_h / 16)`. Right
page starts at screen column `>= cols - 4` and stops at column 5; left page starts at `<= 4` and stops at
`cols - 5`; vertical thresholds and targets scale by `rows / 11`. When the level is smaller than the view in an
axis the camera is centred on the level in that axis. `Settings "camera/smooth_follow"` switches to the comfort
camera of PHYSICS.md 12.6; `"video/screen_shake" = false` suppresses the view offset only.

May consume: `Spawner`, `LevelText`, `TileGrid`, `Levels`, `Game`, `Sim`, `Audio`, `Events`, `Settings`, `Flow`
(`pending_level_id`, `complete_level`), `PlayerBase` (read state, `respawn_at`).

### 8.6 ui

Responsibilities: every screen of section 3.10 and the three overlays; HUD (lives, score, hearts, letters, the boss
bar under the hearts (HudBossBar: its fill spans the boss's own hit points; the signal API still carries pips),
score pop-ups are FX not HUD) laid out from ASSET_MANIFEST 12 with safe-area margins; title + attract,
mode select, code entry / continue, options (volumes, fullscreen, bindings, touch layout, accessibility), pause
menu (resume, restart from checkpoint = `Game.level.player.kill(&"give_up")`, restart level, options, quit),
level intro, world map, tally (GAMEPLAY.md 3.7), game over, Beginner wall, the end, credits (CREDITS.md wording),
touch controls, input-glyph switching, localisation-ready strings (`tr()`).

Must provide: `scenes/ui/<screen>.tscn` for the ten screen names, `scenes/ui/hud.tscn`, `pause_menu.tscn`,
`touch_controls.tscn`. 2.0 (P1.11, ui-A) adds `book_select`, `join` (the Tribe Gathering), `versus_lobby`,
`versus_scoreboard` and `versus_results`; the title's Play > Solo / Co-op / Versus choice lives inside the title (no
screen of its own). P2.8 (ui-A) adds `versus_rules` (args `{"owner": slot}`, sets `Game.versus_match.rules_owner`),
`versus_arena` (then `Flow.start_versus()`; "back" from either = `Flow.open_versus_lobby()`, seats kept) and `unlocks`
(args `{"back": screen}`: the lobby or the title). P2.6 (core-A) gives the screens: `UnlockTable` (the painting homes and
the reward ladder), `VersusMatch.variant_choices()` / `arena_paintings_needed(id)` (locked content shows its painting
count), `Flow.level_select(mode, book, difficulty)` (the code entry per book, the co-op continue), the expert wall's
args `{book, mode}` and THE END's `{book, mode, mural}`, the deciding-moment signals `Flow.replay_started` /
`replay_finished` (HUD banner, `Flow.skip_replay()` for a touch button), `Save.reward_unlocked(reward)` (the "new
reward" notice) and `Game.tally_item_slots` (the co-op tally's two piles). Rules:

- UI reads state from `Game`, `Levels`, `Save`, `Settings`, `Flow.args` and reacts to `Game.*` / `Events.*`
  signals. It never reaches into the level, the hero or enemies (exception: the documented give-up call).
- Navigation only through `Flow`. The world map ends with `Flow.start_level(Flow.args["level_id"])`; the tally
  ends with `Flow.finish_tally()`.
- Touch buttons call `GameInput.set_touch(Defs.ACT_*, pressed)`; show the overlay when
  `GameInput.wants_touch_controls()`; switch glyphs on `GameInput.device_changed`.
- Pause menu and overlays set `process_mode = PROCESS_MODE_ALWAYS` (or `WHEN_PAUSED`) and show on
  `Events.pause_changed`. Every menu is fully usable with keyboard, gamepad and touch.
- UI sounds: `Audio.play_sfx(Sfx.MENU_*)`. UI may use tweens, timers and `_process` freely (it is not gameplay).
- Fonts: `resources/ui/font_hud.fnt`, `font_title.fnt`, `font_digits_big.fnt` (generated from the manifest's font
  sheets by `resources/ui/make_bitmap_fonts.py`) are the shared bitmap fonts; objects' score pop-ups draw with
  `font_hud.fnt` too. The sheets under `assets/fonts/` are imported with importer `skip`: load the `.fnt` files.

### 8.7 Definition of Done (every module)

1. `godot --headless --path . --import` prints no error; a headless boot prints no error and no warning.
2. `tests/run_tests.gd` passes completely (all modules' tests, not only your own).
3. Your module has tests for its rules. player: the golden traces and tables of `PHYSICS_REFERENCE.json`
   (walk, stop, reverse, standing / variable / running jumps, falls, hurt, strikes, charge, walls, ledge drops)
   pass tick for tick. enemies: every archetype's movement and the shared rules. objects: every item effect,
   spot kinds, flood fill, platforms. world: loader on `test_example`, auto-tiling table, camera page timing
   (`camera.walk_right` of the reference), validator. ui: every screen instantiates and can be left by input.
4. Every id of section 6.2 that you own exists and spawns in `test_example` (or your own `levels/test_<module>_*`)
   without warnings.
5. Autoplay screenshots of your feature were taken and looked at (section 9.2).
6. No file outside your globs was changed; no physics literal outside `Tuning`; code follows section 10.
7. The performance budget of section 11 holds in your part.

---

## 9. Verification tools

### 9.1 Tests

```
godot --headless --path . --import                                   # once after checkout / new class_name
godot --headless --path . -s res://tests/run_tests.gd                # all tests; exit code 0 = pass
godot --headless --path . -s res://tests/run_tests.gd -- --filter=player --verbose
```

(`godot` = `.tools/godot/Godot_v4.7.2-stable_win64_console.exe`.) A test file is `tests/test_<module>_<topic>.gd`
with `extends TestCase` and methods `test_*`. A test fails on a failed assertion, on zero assertions, or on any
engine error logged while it runs. Helpers: `assert_true / false / eq / ne / almost_eq / null / not_null /
ints_eq`, `fail`, `expect_errors(n)`, `load_reference()` (PHYSICS_REFERENCE.json), `add_node`,
`make_level(rows)`, `make_flat_level(cols, rows, ground_row)`, `place(level, entity, pos, params)`,
`run_inputs([[ticks, "KEYS"], ...])`, and for several heroes (2.0) `run_party_inputs([[ticks, "KEYS|KEYS"], ...])
-> Array[PackedInt32Array]` (one key set per player slot, an empty part = idle; returns the streams played).
`tests/test_core_level_base.gd` shows how to test entities in a bare `LevelBase` without the world module. Tests
never write real user data (redirected to `build/test_user`). The runner prints the seconds of every file. **Slow
modules** (PLAN.md 8 V7; `SLOW_FILES` in `tests/run_tests.gd`: `test_coop_gates.gd` since G1, core-B's
`test_versus_bots.gd` since phase 2, and since the G2 integration the route replays `test_campaign_routes.gd`,
`test_book2_routes.gd` and `test_coop_routes.gd`) are skipped, each with a
`skip` line and a closing `SKIPPED:` line, unless the run has `-- --slow` (`GD_TIMEOUT=4000 bash .tools/gd.sh test
--slow`; or each by name in parallel - `COOP_GATES_SHARD=<i>/<n>` splits `test_coop_gates`) or a filter that names the
module - its whole name after `test_` (`bash .tools/gd.sh test coop_gates`); a
filter that only touches it (`coop`, `gates`) runs the other matching files and skips the slow one, so a module's quick
check never pays for the slow search (P2.6 sign-off; `run_tests.discover_files` is the rule, `tests/
test_core_runner.gd` keeps it). They run at every gate and before every merge that touches co-op files or the solo
search. The default run took about 4 minutes at G1 (1 135 tests) and 7.5 minutes before the G2 integration moved the
route replays out (about 4.5 minutes after it); gd.sh's default `GD_TIMEOUT` of 300 s is close: a full run passes
`GD_TIMEOUT=600`. **Isolation between files** (P2.6): the runner puts back the global clock state a
file left behind - `Sim.frozen` (a Flow transition that a failing test never awaited), a `Sim.time_scale` other than
1 (a deciding-moment replay), a paused tree - before the next file, with a `note: <file> left ... - reset` line
(`run_tests.reset_leaks`), so one file's failure no longer fails the next file's timing tests (seen in phase 2: a red
boss test left the clock frozen and `test_fidelity_clock.gd` counted 0 ticks).

**Permanent guards of 2.0** (PLAN.md 8 V1, core): `tests/test_core_players.gd` - on a single-player level the
PlayerSet is the 1.0 hero, `GameInput.get_flags(0) == GameInput.flags` and the free slots read nothing on every
tick, `Game.hearts / bones / weapon / has_glider` are `runs[0]`'s, and `w1_l1.inputs`, `w2_l2b.inputs`,
`w4_l1.boomerang.inputs` replay (through the bench's `replay()`) to the per-tick digests of the 1.0 baseline in
`tests/fixtures/sp_digest/`; it also holds the phase-0 exit test (two heroes of `levels/test_core_party.lvl` move
independently from two streams). `tests/test_core_book1_frozen.gd` - the sha256 (CR removed) of the 15 Book I level
files and the 72 route files equal `tests/fixtures/book1_hashes.txt`, which still names exactly the Book I files.
Both prove themselves on drifted copies under `build/`: `CORE_PLAYERS_FIXTURES=<dir>` / `CORE_PLAYERS_SNAPSHOT=<dir>`
(`<dir>/levels`, `<dir>/routes`) and `BOOK1_FROZEN_ROOT=<dir>` point them at a copy, which must fail when one byte or
one tick differs. `tools/sp_identity.sh` stays the full proof (every route, dozing on and off).

### 9.2 Autoplay harness (visual QA)

```
godot --path . -- --autoplay=test_example --inputs=40:R,12:RU,30:R,8:F --shots=10 [--fast] [--out=name]
godot --path . -- --autoplay-scene=res://scenes/ui/title.tscn --inputs=60: --shots=20
```

Boot check (works headless): `godot --headless --path . -- --smoke=3` runs the game normally for 3 seconds and
exits with code 0 only when no error and no warning was logged.

Release builds: every switch above is a development tool and works only in debug builds (editor binary, debug
templates). A release export ignores all of them except `--smoke`, the boot check of the build scripts, which only
shortens the session (capped at 120 s); in an exported build it also logs an error for every development file
found inside the package. `ClubAndGrub.exe --log-file smoke.log -- --smoke=3` (see `docs/BUILD.md`).

Plays a run-length input script (`ticks:KEYS`, keys `L R U D F K`) in a level with a fixed seed and writes
`build/screenshots/<out>/tick_NNNNN.png` (base-resolution frames) plus `trace.json` (hero x, y, xvel, yvel, state
per tick). Needs a window (not `--headless`). Exit code 0 / 2 (bad arguments) / 3 (scene missing) / 4 (a flow
check failed). All options are documented at the top of `scripts/core/autoplay.gd`. Saves and settings of every
harness run go to `build/autoplay_user` (`--user-dir=<path>`, `--fresh-user` empties it first): the harness never
touches the player's real data. Transitions are instant unless `--transitions` is given.

**Flow scripts** (`--flow=<file>`) drive the whole game like a player, across scene changes: the game boots
normally, and the script presses menu actions and keys, plays gameplay input (`play` / `play_file`), waits for
conditions, checks state (`expect game.lives == 1`, `expect events.player_died == 1`, `expect
save.is_level_unlocked(test_integration_boss,0) == true`) and saves named screenshots. The syntax is documented at
the top of `scripts/core/dev/autoplay_flow.gd` (a `dev` folder: not exported). The flows in `tools/autoplay/`:

```
bash .tools/gd.sh play --flow=tools/autoplay/full_loop.flow --fast --fresh-user        boot -> ... -> the end -> title
bash .tools/gd.sh play --flow=tools/autoplay/game_over.flow --fast --fresh-user        pause menu give-up -> game over
bash .tools/gd.sh play --flow=tools/autoplay/code_and_options.flow --fast --fresh-user  code entry, quit, options
bash .tools/gd.sh play --flow=tools/autoplay/options_persist.flow --fast               (afterwards) options persisted
bash .tools/gd.sh play --flow=tools/autoplay/robustness.flow --fast --fresh-user --transitions
                      timed transitions, mashed menus and pause, focus loss, window sizes, restart rules, codes
```

Flow scripts can also resize the window (`window 1600 720` gives the 800 x 360 view of a wide phone) and take the
focus away from the game (`focus out` / `focus in`), so view sizes and the background rules are checked in a window. `pad <button>` sends gamepad events (buttons, d-pad,
left stick, as a pad reports them) and `input device` lets the hero read the devices instead of the script, for
keyboard-free paths through menus and play.
A stage that has just started waits for its first `play` (or `input device`), with `--fast` and in real time alike:
in real time the runner holds the new stage's clock (Sim.manual) from Flow.screen_changed(&"level") - before its
first tick, at EVERY stage start of a run - until the `play` starts, so a real-time run (`--perf`, a showcase) replays
a route tick for tick like a `--fast` one (tests/test_integration_flows.gd proves the real-time trace equals the
`--fast` trace). A `play` ends when another stage takes over (sub-stage, bonus stage, epilogue), and `weapon <name>`
hands the hero a weapon. Engine errors logged while a flow runs (push_error, SCRIPT ERROR, failed engine checks) fail
it, as in the test runner (warnings are printed); `expect_errors <n>` announces errors a flow provokes on purpose.
Phase-3 commands: `wait_ms <ms>` (real time), `section <name>` (an independent part that starts at the title;
Flow.goto_title when the game is elsewhere - a part that stops is cut short and the run goes on at the next
`section`, still failing with exit 4) and `need <level id | route path> ...` (a skeleton flow - a `# skeleton:` line -
skips to the next section when the content has not landed and reports the part PENDING; any other flow fails).
The campaign flows:

```
GD_TIMEOUT=1800 bash .tools/gd.sh play --flow=tools/autoplay/campaign.flow --fast --fresh-user     Expert, all levels
bash .tools/gd.sh play --flow=tools/autoplay/campaign_beginner.flow --fast --fresh-user            code -> expert wall
GD_TIMEOUT=3600 bash .tools/gd.sh play --flow=tools/autoplay/campaign_b2.flow --fast --fresh-user   Book II solo,
                    Beginner (expert wall) then Expert (The End)
GD_TIMEOUT=5400 bash .tools/gd.sh play --flow=tools/autoplay/campaign_coop.flow --fast --fresh-user  co-op Books I
                    and II, both difficulties (four sections)
```

Their headless twins: `test_book2_routes` / `test_coop_routes` `test_the_*_campaign_in_one_run`
(RouteTestCase.play_campaign). Gate G3 in one command: `bash tools/g3.sh` (every slow module - coop_gates sharded,
versus_bots sharded by `tools/g3_versus_bots.sh` - the default suite, sp_identity, the campaign flows headless and the
content inventory `tests/test_integration_g3.gd` -> the G3 table; header in the file).

**Headless flows and the view** (P2.6 investigation, core-A): a flow run headless (`scripts/core/dev/
headless_flow.gd`) must give every level the view of a window. The headless display server keeps a window of its own
size (`root.size = 1280 x 720` does not stick), so with stretch aspect `expand` each level gets a 640 x 640 art-px
viewport - a 320 x 320 logical view instead of 320 x 180. A taller view wakes enemies earlier (they wake by the view), so a route recorded in a window diverges: `w1_l2.warp.inputs` leaves the windowed trace at tick 937
(a bounce the windowed hero never makes), the hero never reaches the 1-2 warp and `campaign.flow` stops waiting for
`bonus_a` (it was never a Flow bug: `Flow.complete_level` is not even called). The fix is the tool's - on every
`Flow.screen_changed(&"level")` call `Game.level.set_view_size(Vector2i(640, 360))` (the screen change of a level comes
before its first tick); with it `campaign.flow` passes headless (116 checks, 30 259 ticks). `headless_flow.gd` does
exactly that since the G2 integration. Tests never depend on the
headless viewport: those that need a view set it themselves (`set_view_size`).

A plain `--autoplay=<id>` run plays its script in that one stage and ends when another stage takes over (its
screenshots are never overwritten by the next stage). Its clock stands still until the script's first tick, so the
level's tick 1 is the script's tick 1, as in the route tests and flow scripts. `--weapon=club|hammer|axe|boomerang`
starts the hero with that weapon (the per-weapon routes `<id>[.expert].<weapon>.inputs`), like the flow command
`weapon`; `--difficulty=expert` picks the Expert spawn set.

Several heroes (2.0, TECH_AUDIT.md 4.11): an input script may hold one key set per player separated by `|`
(`--inputs=8:R|L,4:|U`; key `S` = Swap); `--players=<n>` (default: the script's streams) starts a co-op run of that
party (versus in an arena), `--weapon=club,axe` names one weapon per player, and trace.json gets the rows of heroes
2.. under `party`. Flow scripts: `play 8:R|L` / `play_file` (a `# route:` header names the players),
`weapon <name> [<player>]`, `input device|script [<player>]` (one hero on the devices, the others scripted),
`start_level <id> [expert] [players=<n>]`, roots `hero2` .. `hero4` (`tools/autoplay/party.flow`). The script parse
is `Autoplay.parse_inputs_multi` (a script without `|` and without a players header is a 1.0 script, parsed exactly
as before), the writer `Autoplay.format_inputs`, the header reader `Autoplay.parse_route_header`.

**Recording** (`--record=<file>`, debug builds, also in a normal game without any other switch): the recorder
(`scripts/core/dev/input_recorder.gd`) appends every player slot's sampled flags on `Sim.tick_started` and writes one
file per stage played (`<file>`, then `<stem>.2.<ext>` ...) with a `# route:` header skeleton (level, difficulty,
players, how the stage ended): two people play a stage with pads in the windowed game and the file is a tick-exact
route (`bash .tools/gd.sh play --record=build/take1.inputs`, then play; a co-op stage once the co-op menus of P1.1
exist, or `--autoplay=<id> --players=2 --record=...`). Bots and scripts are recorded alike.

Tool scripts run with `-s` (`tests/run_tests.gd`, `tools/*.gd`) are compiled before the autoloads exist: a class
that uses an autoload (`SimEntity` and every entity script) cannot be named in such a script's own source (it
fails to compile for the whole run). Reach those classes through the scene tree or duck typing, as
`tests/run_tests.gd` and `tools/world_render_level.gd` do; test files are loaded later and are not affected.

### 9.3 Debug level

While `scenes/world/level.tscn` does not exist, Flow loads `scenes/core/debug_level.tscn`: a collision-only view
of any level file (flat colours, entity boxes, club box, list of scenes not built yet) that spawns every entity
whose scene exists and follows the hero with a plain camera. It lets player, enemies and objects run and
screenshot their work from day one. It is a development tool, not the loader; it is excluded from exports.

---

## 10. Coding conventions and error handling

### 10.1 GDScript

- Static typing everywhere: every variable, parameter and return type is declared (`var x: int = 0`,
  `func f(a: int) -> void`), typed loops (`for i: int in n`), typed arrays (`Array[SimEntity]`). No `Variant`
  fields unless a value really is polymorphic.
- Tabs for indentation, lines up to 120 columns, LF endings, UTF-8 (`.editorconfig`).
- Names: files and folders `snake_case`; classes `PascalCase`; functions and variables `snake_case`; constants
  `UPPER_SNAKE`; signals past-tense `snake_case`; private members `_leading_underscore`; booleans read as
  statements (`dead`, `is_open()`).
- Order inside a file: `class_name`, `extends`, doc comment, signals, enums, constants, public vars, private vars,
  built-in virtuals, public methods, private methods. Public members carry `##` doc comments.
- `class_name` for every script that others type against; autoload scripts have none (use the autoload name).
- No `preload` across module borders (use ids, groups and base classes). No `get_node` paths into another
  module's scene. No `await` inside `_sim_tick`.
- Sounds, music, input, scene changes, saving: only through `Audio`, `GameInput`, `Flow`, `Save` / `Settings`.
- Commit the `.uid` and `.import` files Godot generates next to your files. Never commit `.godot/` or `build/`.

### 10.2 Error handling

- **Programming errors** (wrong argument, impossible state): `push_error(...)` and return a safe value; never
  crash, never `assert()` in shipped paths (asserts are stripped in release builds).
- **Content errors** (bad level line, unknown entity id, missing scene or file): report once with file and line
  (`LevelText` collects them in `LevelText.problems`), skip that element and keep the level playable. The level
  validator is the place where content errors become failures.
- **User data errors** (missing, damaged, newer-version save or settings): fall back to backup, then to defaults;
  never block the game; never overwrite a file that could not be read with a newer version number.
- **Expected absence** (a scene of a module that is not built yet): use `Spawner.exists()` / `Flow.has_screen()`
  and degrade silently.
- A clean log is a requirement: no `push_error`, `push_warning` or script error during boot, level load and
  normal play. Use `print` only in tools, tests and the autoplay harness.
- Null checks at module borders: `Game.level`, `Game.level.player` and any spawned node may be null.

---

## 11. Performance budget (low-end Android: 4 x Cortex-A53, GLES 3.0, 2 GB RAM)

| Item | Budget |
|---|---|
| Frame time | 60 fps; CPU <= 8 ms and GPU <= 8 ms per frame at 800 x 360 internal resolution |
| Simulation | one tick <= 2 ms on the target device (24 ticks/s = under 5 % CPU); catch-up never more than 4 ticks. Desktop proxy (debug binary, `--perf` campaign flow): average <= 150 us and p99 <= 500 us per tick in every level |
| Active entities | <= 12 awake enemies; <= 32 dropped bonus items (`ObjTuning.MAX_DROPPED_ITEMS`, the original's 32 item slots) plus at most 4 key items (fire-starter, trophy, weapons: they never expire); <= 4 thrown weapons; <= 7 platforms on screen; <= 200 registered `SimEntity` per level, of which <= 48 tick at once (the others doze, 11.1) |
| Per-tick allocations | none in `_sim_tick` hot paths: no new `Array` / `Dictionary` / `String` formatting, no `get_nodes_in_group`, no `get_children`, no node creation except real spawns; reuse `Rect2i` / ints |
| Draw calls | <= 60 per frame; one TileMapLayer per layer; sprites share sheets; no per-entity shader materials (use `modulate` for flashes) |
| Overdraw | <= 4 parallax layers + 3 tile layers; particles <= 64 on screen, CPUParticles2D or hand-rolled sprites, no GPU particle collisions |
| Textures | nearest, lossless, no mipmaps; every texture <= 2048 px per side (the Brute sheets were re-packed to 2016 px, ASSET_MANIFEST); <= 96 MB of textures loaded per level; the terrain atlases and the liquid strip of a level share one texture built at load (`WorldTileSet.shared_atlas`), so the tile layers stay one batch per quadrant |
| Audio | <= 10 SFX voices + 2 music streams; OGG music streamed; no decoding in `_sim_tick` |
| Loading | a level loads in <= 2 s on the target device; entity scenes are cached by `Spawner`; the level loader calls `Spawner.retain_only(ids)` (scenes of the previous level are released with their textures), `Spawner.preload_ids(ids)` and `Spawner.preload_runtime()` (every fx / items / projectiles scene: nothing is loaded inside a tick). Menus and the world map load ahead what the next level start needs (`Flow.warm_up`, 11.2), so the first level of a session starts as fast as any other |
| Measuring | `--perf` (debug builds, with `--autoplay` or `--flow`, `scripts/core/dev/perf_probe.gd`): frame CPU / GPU time, draw calls, tick cost, entity counts (registered and ticking), memory and load times per level against this table, slow ticks with what they loaded, a leak snapshot at every title / map arrival; `--perf=layers` also attributes the draw calls to the layers of each level. Headless: `scripts/core/dev/sim_bench.gd` (11.3) |
| Memory | <= 300 MB resident on Android |
| Resolution independence | no assumption about the view size; UI anchored; touch targets >= 56 art px |
| Battery | no busy loops; `Engine.max_fps` stays 0 (vsync); the simulation stops when the app is paused |

### 11.1 Dozing: far, idle entities cost nothing per tick

A level registers every entity of its file at load (enemies sleep at their anchors, items bob in place), so most of
them are far from the action at any time. `LevelBase` runs a doze manager: an entity whose `_doze_area()` touches
neither the hero's box and feet point grown by `Tuning.DOZE_HERO_REACH_PX` (128) nor the view grown by
`Tuning.DOZE_VIEW_REACH_PX` (32, the enemy activation margin), and whose `_can_doze()` holds, is taken out of the
tick (`Sim.suspend`): no phase calls, no `sim_prev` snapshot, no `on_screen` test, no interpolation. Both
rectangles are rounded outwards to `Tuning.DOZE_GRID_PX` (64), so the manager only looks at every entity again when
one of them crosses a grid line; otherwise only the entities that reported a change (`_doze_note()`) are looked at.
Decisions are taken at the end of every tick (before the `on_screen` pass), at the start of a tick when the view or
the hero moved in between (a gate, a resized window), and after a respawn.

Dozing changes no outcome, by construction:

- `_can_doze()` holds only while every tick of the entity would change nothing as long as the hero and the view
  stay out of reach: a placed item only counts its age (restored on waking from `Sim.get_phase_runs`) and tests
  the overlap, which rejects feet points farther apart than `Tuning.OVERLAP_MAX_DX` / `_DY` (64 / 70); an asleep
  enemy waits for its box to meet the view grown by `ENEMY_SPAWN_MARGIN_PX`, read in phase `ENEMIES` with the view
  of the last decision (the camera moves only in phase `CAMERA` and in snaps, both followed by a decision); zones,
  spawner records, checkpoints, signs, springs, gates and rising columns test a point or an overlap in the same
  way; hittables tick only for their cool-down, and a hit or an opening wakes them first (`_doze_wake_now`, exact
  also in the middle of a phase).
- The hero reach of 128 px covers the overlap reach (70 px) plus his largest move between a decision and a contact
  test: 18 px per tick measured over every route, and a bounce lift of at most a hero box height earlier in the
  same phase. Teleports (gates, respawns, rising columns) are followed by a decision before the next phase that
  could see them.
- `tests/test_core_doze.gd` checks the Sim rules and the manager on bare levels, replays a real route with and
  without dozing tick for tick, and checks on every tick of it that no dozing entity is on screen or within the
  hero's reach and that the hero never moves farther in one tick than the reach allows. Every enemy archetype that
  replaces a wake hook must declare its doze rule (checked there too). `sim_bench.gd --digest [--no-doze]` compares
  the whole state of every route run, tick for tick.

`LevelBase.doze_enabled = false` switches it off (measurements only).

### 11.2 Background loading

While a menu screen or the world map shows, `Flow.warm_up(level_id)` loads what the next level start needs: the
level, HUD, touch and pause scenes, the hero, every effect / item / projectile scene and, for the level the map
shows, its entity scenes, terrain, liquid, backdrop, prop and `skin=` pictures and its music. Pictures, sounds and
fonts load on worker threads (`ResourceLoader.load_threaded_request`, at most 2 ms of main-thread work per frame
for looking up dependencies and collecting results). Scripts and scenes are put together on the main thread only
while a transition covers the screen (at most 400 ms per transition), never on a visible frame: this engine
version reported an object as leaked at exit for some scripts compiled on a worker thread, and a script compile
(up to 100 ms in a debug build) is too long for a visible frame. For the same reason a resource that is loaded
already (by a screen) is only kept, never requested on a thread again. What is left when the level starts, the level
loads itself as before - never inside a tick. Headless runs (tests, smoke checks) do not warm up; the exit waits
for running loads. Measured on the desktop debug build: the first level start (covered to started) went from about
700 ms to under 60 ms; the covered menu transitions before it take up to 465 ms (boot to title), 258 ms and 166 ms.

### 11.3 Headless bench

```
bash .tools/gd.sh script res://scripts/core/dev/sim_bench.gd -- --make-snapshot=res://build/perf_baseline
bash .tools/gd.sh script res://scripts/core/dev/sim_bench.gd -- --snapshot=res://build/perf_baseline --digest --tight
bash .tools/gd.sh script res://scripts/core/dev/sim_bench.gd -- --profile w2_l1.inputs      cost per phase and class
bash .tools/gd.sh script res://scripts/core/dev/sim_bench.gd -- --load-profile=w1_l1        first level start, step by step
```

It replays the route files of `tests/test_campaign_routes.gd` exactly as that test does (from a frozen snapshot of
the level and route files if asked), times every tick, writes a state digest per tick (`--digest`; compare two
runs with `diff`), profiles every `_sim_tick` call (`--profile`, through `Sim._profiler`) and compares with dozing
switched off (`--no-doze`). By default it renders one frame between two ticks with the engine's idle sleep, which
leaves the caches as cold as the windowed game does; `--tight` steps like the headless tests (fast, for digests).

2.0: besides the `ROUTES` table it plays every header route of the route folder (`--route-dir=<dir>` for another,
e.g. `res://tests/fixtures/routes/`) as its header says - a party of `players` heroes with one stream each, the
level's book, the header's `belt` - and checks every slot against its stream per tick. The digest of a party appends
heroes 2.. and their runs (hearts, bones, hand, glider; never the belt, PHYSICS.md C.2 rule 5) only when the level
holds more than one hero. `--belt-invariance` is the belt-invariance runner (PLAN.md 8 V2.b): every selected header
club route with an empty belt and with each special on every hero's belt must give identical digests (exit code 1
otherwise). Tests replay in their own process through the runner's `replay(file, mode, options) -> {lines, screen,
level_id, input_ticks, input_mismatches}`, `replay_stage()`, `belt_invariance()`, `live_routes()`,
`header_routes(dir)` and `first_difference(a, b)`.

```
bash .tools/gd.sh script res://scripts/core/dev/sim_bench.gd -- --belt-invariance --route-dir=res://tests/fixtures/routes/
bash tools/sp_identity.sh        single-player identity: every Book I route, dozing on and off, against the 1.0 evidence
```

### 11.4 Measured (desktop debug, Ryzen 9 7900X)

Tick cost per level measured by `--perf` in the windowed game before and after the final production pass (average
/ p99 / max in microseconds, all end-of-tick handlers of the harness included):

| Level | before avg / p99 / max | after avg / p99 / max |
|---|---|---|
| w1_l1 | 432 / 869 / 1705 | 245 / 645 / 1275 |
| w1_l2 | 473 / 916 / 1480 | 240 / 596 / 1101 |
| bonus_a | 315 / 803 / 1256 | 227 / 643 / 938 |
| w2_l1 | 404 / 991 / 1975 | 248 / 652 / 1044 |
| w2_l2 | 408 / 1464 / 2591 | 248 / 737 / 1005 |
| w2_l2b | 249 / 911 / 4340 | 272 / 870 / 5998 |
| bonus_b | - | 217 / 569 / 917 |
| w3_l1 | 317 / 843 / 1470 | 237 / 682 / 1328 |
| w3_l1b | 260 / 754 / 1676 | 225 / 612 / 1384 |
| w3_l2 | 338 / 826 / 1458 | 241 / 638 / 1254 |
| bonus_c | - | 232 / 649 / 950 |
| w4_l1 | 343 / 889 / 1430 | 230 / 586 / 1195 |
| w4_l2 | 300 / 980 / 2104 | 198 / 641 / 923 |
| w4_l2b | 216 / 557 / 4398 | 132 / 353 / 3139 |
| ending | 261 / 827 / 1080 | 173 / 680 / 999 |

"Before" is the release check's campaign flow on the original code (`build/release_check/perf_campaign.log`;
bonus_b and bonus_c were not on its route), "after" a flow that starts every level on its own and plays its
route (`start_level` + `play_file` of a flow script; a linked stage plays its own route). The headless bench with
one rendered frame and the engine's idle sleep between two ticks gives similar numbers; with a short sleep
(`--sleep=300`, warm caches) the averages are 103-143 us. On this machine the windowed game leaves the caches
cold between two ticks, which roughly doubles the cost of the same code; a Cortex-A53 is estimated 10-15 times
slower than this desktop. The budget of 150 / 500 us is not met yet: what is left is spread over the hero (about
75 us over its four phases), the fixed per-tick work (input, snapshot, doze decision, on_screen pass, camera:
about 50 us) and the 10-45 entities that tick near the action. The single spikes over 1 ms are boss bursts
(64 items spawned in one tick) and first-time scene instancing. Registered entities peak at 155 (w2_l1); at most 45 tick
at once (w2_l2b during the Brute's item burst; 44 in bonus_b); dropped items peak at 36 (w4_l2b: 32 bonus items
and 4 key items).

---

## 12. Decisions and deviations recorded here

- Base viewport 640 x 360 with `ART_SCALE` 2 (art density), stretch `viewport` + `expand` + integer scale: the
  authentic framing at 16:9, more level on other aspect ratios.
- The simulation clock is custom (24.2753 Hz); Godot physics ticks are unused.
- Slopes: 45 degrees and half-gradient profiles replace the original 1:3 gradient (art-driven); the hero rules are
  unchanged; slope feet get a "glue" profile so the step-down rule works.
- Hero contact boxes are the original frame boxes, not the smaller art-measured ones.
- Enemy activation lives in `EnemyBase` (every enemy is instantiated at load and sleeps), not in the loader.
- Passwords exist per level and mode but are fixed codes from the level files; progress is also saved.
- `time` exists in the format but defaults to 0 (no timer), as in the original.
- The "swirling axe" is skinned as a boomerang (`Defs.Weapon.BOOMERANG`).
- Losing focus pauses gameplay and suspends sound on every platform, not only on phones: with the window in the
  background the player cannot react, and a keyboard stops reporting releases.
- Transitions freeze the simulation clock instead of letting ticks run behind the cover.
- Release builds act on no development command-line switch except the smoke check.
- Module tuning tables (`EnemyTuning`, `ObjTuning`) hold the numbers only their module uses; `Tuning` keeps the
  physics appendix and every number shared between modules (section 4.4).
- Respawns and gates travel behind `Flow.play_covered` (clock frozen) instead of a curtain that runs on ticks.
- Debug builds had a development campaign made of the two integration levels until the real campaign arrived;
  they are now a linked pair of `kind = test` levels (section 8.1).
- "Restart level" (pause menu) puts the run back to the level entry (`Game.restore_level_entry`): score, letters,
  feast kit, weapon and counters as they were, lives only downwards, and a death toss in progress still costs its
  life. Otherwise every item of the level could be collected again and again (points and extra lives for free).
- The autoplay harness redirects saves and settings to `build/autoplay_user`.
- Campaign integration fixes (not in the original): a code is read with O = 0 and I = 1; a hero who touches a
  checkpoint in the air stores the checkpoint's own feet point (his own could lie over a gap); sprite platforms
  catch a hero falling at 8 px/tick or more 16 px deep (Tuning.PLATFORM_CATCH_*); ground enemies that enter a liquid
  are gone with a splash; a dropped item that rises into a solid ceiling is stopped under it (it used to rest
  inside the rock, a softlock for a boss's fire-starter); a boss bar always spans the boss's own hit points; menu
  entries take the focus only from a moving pointer.
- Windows ships as one .exe without ANGLE (OpenGL 3.3 is required; `docs/BUILD.md`).
- Final production pass (performance): far, idle entities doze (11.1) - no recorded route, golden trace or fidelity
  test moved; placed items count their age and bob in their `CONTACT_ITEMS` step instead of a separate `ITEMS`
  step; sprite frames and flips are written only when they change; tile repaints after `set_cell` are batched per
  frame; menus and the map load the next level start in the background (11.2); the activity budgets follow the
  measurements (registered 200 / ticking 48 entities, the original's 32 dropped-item slots plus key items).
- Alt+Enter and F11 toggle fullscreen on desktop (section 2).
- A scene change requested inside a tick (an exit, a game over) starts at the end of that tick, also with instant
  transitions (tests, autoplay): the tick runs to its end, as it always did with the timed transitions of the
  game. Before, an instant transition took the level out of the tree in the middle of the exit tick, so a headless
  replay could differ from the game in that one tick: route `w3_l2.inputs` (Beginner) now ends with 194 600 points
  instead of 193 000 in headless replays - the score the game with its timed transitions always gave.
- Release pass (fresh-eyes playtest), deviations from the original for readability, none of which moves a recorded
  route: the 4-1 auto-scroll waits for the player's first input after the start and after a respawn, and draws
  its deadly top edge as smoke; sign boards stay up for a read time (presentation only) and make the stage banner
  give way, which a waking boss does too; the crouch charge shows as a glow on the hero with a chime when full;
  a club or hammer on the Colossus' head glances off with a clank and a spark; a hero who dies in water or lava
  splashes, the death jingle plays before the respawn curtain and lava plays its ambience loop; world letters
  shimmer. The extra-life rule stays the original's (one per 250 000 points, at most 99 lives).
- Every route proof is played with the weapon it was recorded for, every (stage, difficulty, weapon a run can
  bring) cell has one, and both campaigns play the route of the weapon the run carries (8.1).
- 2.0 phase 0 (docs/expansion/PLAN.md 3): every contract addition is additive and keeps the 1.0 meaning for a party
  of one ("N = 1 is the identity", TECH_AUDIT.md 2); the proof is `tools/sp_identity.sh` (the per-tick digests of
  every Book I route, dozing on and off, against the evidence frozen before the first edit) plus the suite.
- Level format 2 keeps co-op content in separate `<id>_coop.lvl` files (DESIGN.md D.9): the TECH_AUDIT.md 4.10 entity
  flags `solo` / `coop` / `versus` and the `.coop` meta variant are not part of the format (the enemy parameter
  `coop=<trait>` uses the name `coop`).
- The tar floor's TAR flag is a fifth per-cell table (`TileGrid.material_at`) instead of a bit of the 1.0 flags byte,
  whose eight bits are all in use (the ceiling nibble included).
- The hero's 2.0 systems live in component files (`hero_belt.gd`, `hero_climb.gd`, `hero_mount.gd`,
  `hero_party.gd`) that `player.gd` calls through guarded hooks, so player-A and player-B work in parallel and a Book
  I solo hero runs only bool tests per tick.
- 2.0 route proofs replay through the bench runner (`sim_bench_runner.gd replay()`), the same code that proves
  single-player identity, so a route test and the identity proof can never disagree about what a tick is; the bench
  digest of a party never hashes the belt (PHYSICS.md C.2 rule 5), and the belt-invariance runner puts the belt on
  every hero after the stage started (just before tick 1), so no stage-start rule can undo it.
- The phase-0 exit level `test_core_party` never reaches its exit with a party: a team exit is phase-1 work, and the
  exit proof must not depend on it.
- Shared hero state that two phase-1 owners write and read in parallel is a contract member from phase 0 on, never a
  private field of one component: the states outside the 4.3 table (`Defs.HeroState.CLIMB` / `CURL` / `RIDING`, read
  by the hero's animation), the versus hit entry `hurt(source, Defs.HurtKind.RIVAL)` with `hit_stop` / `squash`
  (world-B's referee sets them, player-A's party component runs them), `leash` (player-A counts, ui-B's HUD shows),
  and a player's look `PlayerRun.palette` / `pattern` (ui-A picks, player-A and ui-B draw). The numbers of the
  PHYSICS.md C.16 rows that name `Tuning`, `PartyTuning` or `VersusTuning` live there (a module never keeps a copy).

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
| Name / version / main scene | `Club & Grub`, `0.1.0`, `res://scenes/main.tscn` | boot scene hands over to `scenes/ui/title.tscn` when it exists |
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
| Input actions | `move_left`, `move_right`, `move_up`, `move_down`, `jump`, `attack`, `look`, `pause`, plus `ui_accept` / `ui_cancel` redefined with a gamepad button; other `ui_*` actions keep Godot's defaults (keys, d-pad, stick) | every action has keyboard and gamepad events; touch feeds the same actions |
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
| ui_accept / ui_cancel | Enter, keypad Enter, Space / Escape | A, Start / B (Start pauses in play and confirms the focused pause-menu entry) |

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

### 3.2 `TileGrid` (`scripts/core/tile_grid.gd`) - collision grid

`TileGrid.from_rows(rows, ice_a, ice_b, letter_tiles)`, `floor_at / side_at / flags_at / ceiling_at / profile_at
(col, row)`, `has_profile`, `surface_offset(col, row, x)`, `get_char`, `set_char`, `set_props`, `set_flag_bits`,
`width_px`, `height_px`, `x_max_excl`, constants `FLOOR_*`, `SIDE_*`, `CEILING_*`, `FLAG_*`, `PROFILE_*`, `CH_*`.
Semantics are those of PHYSICS.md 11.1 with one documented change: the original `HEIGHT` byte is a `profile` id
(our slopes are 45 degrees and half-gradient). `has_profile()` = "HEIGHT is non-zero"; apply the rules of
PHYSICS.md 11.2 unchanged. Flat floor cells at the foot of a slope get `PROFILE_FLAT_GLUE` automatically.

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

### 3.7 `GameInput` autoload - input abstraction

`GameInput.flags` is the bit mask of `Defs.IN_FIRE | IN_DOWN | IN_UP | IN_LEFT | IN_RIGHT | IN_LOOK`, sampled
once per tick by `Sim`, with presses latched (PHYSICS.md 15.4). `Tuning.STATE_LUT[flags & Defs.IN_STATE_MASK]` is
the state table of PHYSICS.md 4.3. API: `is_held(mask)`, `just_pressed(mask)` (cosmetic only), `prev_flags`,
`enabled`, `device` (`Defs.Device`), signal `device_changed`, `set_touch(action, pressed)`, `clear_touch()`,
`set_scripted(callable)`, `clear_scripted()`, `keys_to_flags("RU")`, `expand_runs(runs)`, `get_glyph_set()`,
`wants_touch_controls()`, `vibrate(ms)`.
**Gameplay code never calls `Input.*` and never handles InputEvents.** UP flag = `jump`, or `move_up` (always
while the setting `controls/up_jumps` is on, otherwise only together with `attack`).

### 3.8 `Levels` autoload - level registry

Scans `res://levels/*.lvl`; no hand-maintained list. `has_level`, `all_ids`, `get_level_path`, `get_level_meta`,
`get_value(id, key, default, difficulty)` (applies `.beginner` / `.expert` variants), `get_campaign(difficulty)`,
`first_level`, `is_available`, `next_level`, `has_locked_successor`, `parent_level(id, difficulty)` (the map stop a
linked `sub` level belongs to: its result is recorded there and the campaign continues after it),
`find_by_password(code)`, `get_password`, `rescan()`. Syntax lives in `LevelText` (`scripts/core/level_text.gd`): `split_sections`, `parse_value`,
`parse_key_values`, `parse_meta`, `parse_params`, `parse_legend_line`, `parse_legend`, `legend_tiles`,
`parse_entity_line`, `cell_to_feet`, `applies_to`, `to_list`, `to_int_list`, `to_rect_px`, `problems`, `quiet`.

### 3.9 `Audio` autoload - sound by event name, music by context

`Audio.play_sfx(Sfx.CLUB_SWING)`, `play_sfx(event, variant, volume_offset_db)`, `start_loop / stop_loop /
stop_all_loops`, `play_music(Sfx.MUSIC_JUNGLE)`, `play_jingle(context, then_context)`, `push_music(context)` /
`pop_music()` (feast, boss: the interrupted track **continues where it was**), `stop_music`, `get_music_context`,
`get_music_position`, `stop_all_sfx`, `get_bus_volume`, `set_suspended(on)` / `is_suspended()` (Flow calls it
while the app is in the background: music and loops halt in place, effects are dropped), `shutdown`, signal
`music_changed`. Event and context names are the constants of `Sfx` (`scripts/core/sfx.gd`); files and
volumes are in `AudioTable`. **No other module loads or plays an audio file.** Calls are allowed inside a tick;
nothing is read back. In headless runs (tests, CI) streams are loaded and all state is tracked, but nothing is
actually started and jingles end at once.

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

### 3.13 `EnemyBase`, `BossBase`

`EnemyBase`: `max_hp`, `hp`, `score_index`, `skin`, `contact_hurts`, `tangible`, `awake`, `dead`, `one_shot`,
`bounce_count`, `dive_count`, `stole_heart`, `flash`; `_ai_tick()` (override), `is_targetable()`,
`take_hit(power, source) -> bool`, `on_bounced(hero) -> int`, `on_glider_stomp(hero)`, `on_hurt_hero(hero)`,
`get_points()`, `kill(cause, killer)`, `burst_into_items(count)`, `wake()`, `sleep()`, signal `died`.
`BossBase extends EnemyBase` (kind `BOSS`): `arena`, `fighting`, `hit_cooldown`, `hp_per_pip`, `music`,
`thrown_only`; `get_pips()`, `get_max_pips()`, `start_fight()`, `poll_weapon_hit(weak_point) -> int`,
`apply_boss_hit(power)`, `touch_hero(hero) -> bool`, `defeat(drops)`.

### 3.14 `ProjectileBase`

`from_hero`, `power`, `yacc`, `life`, `hurt_kind`, `spent`; `consume()`. Parameters `from_hero`, `power`, `xvel`,
`yvel`, `yacc`, `life`. Moves in phase `PROJECTILES` without tile collision; removed when not drawn in the
previous frame. Enemy projectiles test the hero themselves in `CONTACT_ITEMS`.

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

### 3.16 Small shared classes

`Defs` (enums `Difficulty`, `Weapon`, `Phase`, `Kind`, `HurtKind`, `HeroState`, `Device`, `Transition`; input
bits; action names; groups; z indices; CanvasLayer numbers; physics layer bits; scroll flags), `Tuning` (section
4.4), `Sfx`, `AudioTable`, `Spawner` (section 6), `SimRng`, `LevelText`.

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
| `ITEMS` | 5, 6 | objects | dropped items and bones move, placed items bob, hazards move, score pop-ups rise |
| `PLATFORMS` | 7 | objects | platforms move, then the ride test (`PlayerBase.ride_platform`) |
| `PLAYER` | 8a-8i | player | delete the club box, read `GameInput.flags`, state, handler, integrate x then y, tile collision, glider, timers (`charge`, `swing_lock`, `drop_timer`, `feast`, and `Game.level.tick_shake_timer()`) |
| `CONTACT_ENEMIES` | 9a | player | hero versus every `Kind.ENEMY` that `is_targetable()` (and `contact_hurts`), only while `hit_timer == 0` |
| `CONTACT_ITEMS` | 9b | objects, enemies, world | each collectible, checkpoint, exit, hazard, enemy projectile and zone tests **itself** against the hero |
| `WORLD` | 10-12 | objects, world | hittable cool-downs, gates, rising columns, wind script, darkness fades |
| `CAMERA` | 13 | world | camera follow (PHYSICS.md 12) |
| `POST` | 14-17 | player, world | `hit_timer` decrement (hero: once per tick here), death sequence, level state |
| after the last phase | 18 | `LevelBase` (built in) | screen-shake step (nudge on odd ticks), then the `on_screen` flag of every entity |

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
| `enemies/dangler` | 2 yo-yo dangler | `bat` | `depth` px [48], `speed` px/tick [2] |
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
| `items/warp`, `items/trophy` | - | `Game.level.complete(&"warp")` / `complete(&"trophy")` |
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
| `objects/container` | `skin=barrel|crate|pot` [crate], `contents` [random], `hits` [1] |
| `objects/platform` | `dir` 0..7 [2] (0 up, clockwise), `speed` px/tick [2], `travel` ticks [44], `mode=always|ride` [always], `skin=wood|ice|stone|small` [by biome] |
| `objects/drop_platform` | `delay` ticks [0], `skin` |
| `objects/column` | `size=w,h` tiles (block whose bottom-left cell is the anchor), `rise` tiles, `trigger=c,r,w,h`, `shake` [7] |
| `objects/gate` | `name`, `dest=<name of a gate or marker>`, `lock=c,r` (camera cell of a single-screen room, optional), `skin=arch|hole|none` [arch]; used with Down while standing on it; not with the glider |
| `objects/marker` | `name` (invisible destination) |
| `objects/spring` | `power` v16 [-224] (optional, not in the original) |
| `objects/sign` | `text=<translation key>` |
| `objects/npc` | `kind=elder\|kid\|warrior` [elder], `turn` [true] (cosmetic villager: idle loop, faces a hero standing near; never hurts, not hittable, counted nowhere) |

**Zones** (world; all take `rect=c,r,w,h` in tiles): `zones/secret` (`name`), `zones/arena` (`name`, `music`
[boss], locks the camera to the rect and wakes the boss whose `arena` equals `name`), `zones/camera_lock`,
`zones/dark` (`on` [true]), `zones/kill`, `zones/autoscroll_stop`, `zones/message` (`text`), `zones/ember_rain`
(`period` ticks [22], `skin=ember|leaf` [ember]: while the hero is inside, a `projectiles/enemy_ember` falls toward
him every `period` ticks; the volcano shaft of GAMEPLAY.md 12.1), `zones/flies` (`count` [5]: dirty ground; every
visit adds flies to the cosmetic swarm around the hero, at most `Tuning.MAX_FLIES`; `items/water_bucket` and a
respawn clear them, GAMEPLAY.md 7.9).

**FX** (objects; cosmetic, free themselves): `fx/dust`, `fx/star_puff`, `fx/hit_stars`, `fx/poof`,
`fx/explosion`, `fx/explosion_big`, `fx/ring`, `fx/splash` (`kind=water|lava`), `fx/debris`
(`kind=rock|wood|ice|leaf`, `count`), `fx/popup` (`kind=score|multiplier|one_up|heart`, `value`; rises 1 px per
tick for 44 ticks).

**Player**: `player/player` (spawned by the level at `@`, never listed in a level file).

---

## 7. The level file format (format 1)

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

Responsibilities: every screen of section 3.10 and the three overlays; HUD (lives, score, hearts, letters, boss
pips, score pop-ups are FX not HUD) laid out from ASSET_MANIFEST 12 with safe-area margins; title + attract,
mode select, code entry / continue, options (volumes, fullscreen, bindings, touch layout, accessibility), pause
menu (resume, restart from checkpoint = `Game.level.player.kill(&"give_up")`, restart level, options, quit),
level intro, world map, tally (GAMEPLAY.md 3.7), game over, Beginner wall, the end, credits (CREDITS.md wording),
touch controls, input-glyph switching, localisation-ready strings (`tr()`).

Must provide: `scenes/ui/<screen>.tscn` for the ten screen names, `scenes/ui/hud.tscn`, `pause_menu.tscn`,
`touch_controls.tscn`. Rules:

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
`run_inputs([[ticks, "KEYS"], ...])`. `tests/test_core_level_base.gd` shows how to test entities in a bare
`LevelBase` without the world module. Tests never write real user data (redirected to `build/test_user`).

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
focus away from the game (`focus out` / `focus in`), so view sizes and the background rules are checked in a window.

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
| Simulation | one tick <= 2 ms on the target device (24 ticks/s = under 5 % CPU); catch-up never more than 4 ticks |
| Active entities | <= 12 awake enemies, <= 20 active items, <= 4 thrown weapons, <= 7 platforms on screen, <= 150 registered `SimEntity` per level |
| Per-tick allocations | none in `_sim_tick` hot paths: no new `Array` / `Dictionary` / `String` formatting, no `get_nodes_in_group`, no `get_children`, no node creation except real spawns; reuse `Rect2i` / ints |
| Draw calls | <= 60 per frame; one TileMapLayer per layer; sprites share sheets; no per-entity shader materials (use `modulate` for flashes) |
| Overdraw | <= 4 parallax layers + 3 tile layers; particles <= 64 on screen, CPUParticles2D or hand-rolled sprites, no GPU particle collisions |
| Textures | nearest, lossless, no mipmaps; every texture <= 2048 px per side (see open risks: the Brute sheets are 2304 px wide); <= 96 MB of textures loaded per level |
| Audio | <= 10 SFX voices + 2 music streams; OGG music streamed; no decoding in `_sim_tick` |
| Loading | a level loads in <= 2 s on the target device; entity scenes are cached by `Spawner`; preload a level's ids with `Spawner.preload_ids` |
| Memory | <= 300 MB resident on Android |
| Resolution independence | no assumption about the view size; UI anchored; touch targets >= 56 art px |
| Battery | no busy loops; `Engine.max_fps` stays 0 (vsync); the simulation stops when the app is paused |

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
- Windows ships as one .exe without ANGLE (OpenGL 3.3 is required; `docs/BUILD.md`).

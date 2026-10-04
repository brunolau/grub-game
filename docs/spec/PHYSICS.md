# PHYSICS.md - exact player physics / controls / camera specification

How the hero of **Prehistorik 2** (Titus, 1993, DOS) moves, restated as an implementable rule set for
"Club & Grub" (Godot 4.7.2, GDScript). Companion of `docs/spec/GAMEPLAY.md`; this document owns every per-tick
number of the hero, the tile collision model, the camera, and the tick-rate decision.

This document describes *behaviour only*. No source code, data files, graphics or audio of the original game or of
any third-party project is copied here or may be copied into the project. The numbers are observed game mechanics
restated in our own words; the pseudo-rules below were written for this document.

---

## 0. Sources, citation keys, conventions

| Key | Source |
|---|---|
| `[B:file:function]` | Engine rewrite `cyxx/blues`, directory `p2/` (https://github.com/cyxx/blues), commit `d4b94bb` (2022-03-13), local clone `.tools/ref/blues`. The lead was verified: `p2/` is a complete rewrite of the Prehistorik 2 engine. No licence file: describe only. |
| `[P:path:function @addr]` | ASM-verified source port `missingno7/pre2_port` (https://github.com/missingno7/pre2_port), commit `b5000dc` (2026-07-16), local clone `.tools/ref/pre2_port`. Each routine was recovered from the GOG `PRE2.EXE` and compared against the original code running in a VM; `@addr` is the original code offset it quotes. No licence file: describe only. |
| `[SIM]` | Derived by running the rules of this document in a small integer simulation (flat ground). Re-derivable from sections 5, 6 and 11; the simulation is `docs/spec/reference_sim.py` and its output `docs/spec/PHYSICS_REFERENCE.json` (Appendix B). |
| `[GD]` | Checked on the project's Godot 4.7.2 binary. |
| `[GA]` | https://www.generationamiga.com/2026/07/24/prehistorik-2-now-runs-natively-on-windows-linux-and-macos/ |

Confidence marks:

- no mark: stated by `[B]` and/or `[P]` and not contradicted by the other;
- **`[B!=P]`**: the two sources disagree. The value to implement is given first; section 14 lists every case;
- **`[INFERRED]`**: not directly confirmed (deduction, or only one indirect source). Full list in section 14.3.

Where `[B]` and `[P]` disagree, `[P]` wins by default because it was diffed against the original machine code.

Units:

- **tick** = one game-logic frame.
- **px** = one pixel of the original 320x200 screen (our "logical pixel").
- **v16** = velocity in 1/16 px per tick (the engine's only fixed-point unit).
- `floor16(v)` = `v` divided by 16 rounded **towards minus infinity** (arithmetic shift right by 4).

Variable names used below are ours. Mapping to the sources:

| Ours | `[B]` name | `[P]` name / address |
|---|---|---|
| `xvel`, `yvel` | `x_velocity`, `data.p.y_velocity` | `xvel` 0x4F22, `yvel` 0x4F2A |
| `facing` (+1 / -1) | `data.p.hdir` | `facing` 0x4F25 |
| `ice` (0..3) | `x_friction` | `motion_mode` 0x4F24 |
| `jump_ticks` | `player_anim2_counter` | `fall_latch` 0x6BD1 |
| `fall_ticks` | `player_jumping_counter` | `fall_frames` 0x6BD2 |
| `no_jump` | `player_nojump_counter` | `fall_grace` 0x6BE0 |
| `last_ground_y` | `player_prev_y_pos` | `last_land_y` 0x6BCA |
| `drop_timer` | `player_action_counter` | `drop_gate` 0x6BE1 |
| `charge` | `player_club_powerup_duration` | `charge` 0x6BCE |
| `swing_lock` | `player_club_anim_duration` | `input_suppress` 0x6BCD |
| `attack_gate` | `player_anim_0x40_flag` | `anim_gate` 0x6BD0 |
| `hit_timer` | `objects_tbl[1].hit_counter` | `death_state` 0x4F2D |
| `glide` | `player_gravity_flag` | `low_gravity` 0x6BC7 |
| `on_platform` | `level_force_x_scroll_flag` | `unk_6BFE` |
| `idle_timer` | `player_moving_counter` | `idle_timer` 0x6BD3 |
| `shake` | `shake_screen_counter` | `camera_shake` 0x6BEA |
| `feast` | `player_hit_monster_counter` | word 0x6BE2 |
| `wind` | `snow.value` | `friction` / `wind` 0x6BF6 |

---

## 1. Timebase (tick rate) - DECISION

### 1.1 Evidence

1. The game reprograms timer channel 0 with divisor 0x4000: 1 193 182 / 16 384 = **72.826 Hz**
   `[B:game.c:timer_get_counter]` (the constant ratio), `[P:docs/pre2/run_status.md "Real-time pacing"]`.
2. The main loop ends every frame in a governor that busy-waits until the timer-interrupt counter has advanced by
   **3** since the previous frame `[P:docs/pre2/live_view_timing_design.md section 12]` (quotes the original loop at
   `@1C6F`), `[P:pre2/bridge/timing_fastforward.py]`.
   3 timer ticks = 3 x 13.7315 ms = **41.194 ms -> 24.275 ticks/s**.
3. VGA vertical-retrace waits (70.086 Hz) pace the menus and the map screen, but in gameplay `[P]` measured that the
   dominant busy-wait is the timer governor (52.4 %) with retrace waits at about 0 %
   `[P:docs/pre2/live_view_timing_design.md section 11 table]`, `[P:docs/pre2/timing_hook_design.md]`. A retrace wait
   that fits inside the 3-timer-tick budget cannot lengthen the frame `[INFERRED]`.
4. Measurements of the original code under `[P]`'s VM: "about 2.8 retraces per gameplay frame, about 25 fps"
   `[P:docs/pre2/enhanced_renderer_design.md section 0]` (70.086 / 24.275 = 2.887, matching point 2) and "about 21.8 Hz"
   in a slower configuration `[P:docs/pre2/run_status.md]`.
5. Other ports: `[P]`'s shipped runner uses 70 / 3 = 23.33 Hz `[P:scripts/play_native.py TICK_HZ]`, described publicly as
   "roughly 23 updates per second" `[GA]`. `[B]` sleeps a fixed 33 ms per frame for all three games it supports
   (30.3 Hz) `[B:level.c:level_wait]` - a rewrite convenience, about 25 % faster than the DOS original.
   PCGamingWiki reportedly lists a 24 fps cap (search-engine summary only; the page returned HTTP 403).
6. Gameplay timers in the data are multiples of 22 (44, 66, 88, 110, 132, 154, 198, 660), which suggests the
   designers counted "22 ticks = about 1 second" `[INFERRED]`.

### 1.2 Decision

**`TICK_HZ = 1193182 / 49152 = 24.275 Hz`, `TICK_DT = 41.194 ms`.** This is the nominal rate of the original
governor (point 2) and agrees with the measurement in point 4. It supersedes the 23.33 Hz note in `GAMEPLAY.md`
(the difference is 4 %). The value for *real 1993 hardware* is `[INFERRED]`: the governor only waits while fewer
than 3 timer ticks have passed, so a machine that needed more than 41 ms for a frame's work simply ran slower (the
exact slow-machine rate depends on where the reference tick is latched, which neither source documents).
`[P]`'s own notes disagree with each other about the resulting rate ("~25 fps", "~23 Hz", "~21.8 Hz", and a
70 / 3 = 23.33 Hz runner); only the 3-timer-tick loop itself is quoted from the disassembly.

`TICK_HZ` must be a single project constant so it can be tuned (23.33 .. 24.275) without touching any rule.

### 1.3 Conversions (at 24.275 Hz)

| Per-tick quantity | Per-second quantity |
|---|---|
| 1 tick | 0.041194 s |
| 1 px/tick | 24.275 px/s |
| 1 v16 | 1.5172 px/s |
| 1 px/tick^2 | 589.29 px/s^2 |
| 1 v16/tick^2 | 36.831 px/s^2 |

All "px/s" and "px/s^2" figures in this document use these factors. They are for orientation only: the simulation
must run in integer ticks and v16 (section 15), never in seconds.

---

## 2. Screen, world, coordinates, number formats

| Item | Value | Source |
|---|---|---|
| Screen | 320 x 200 px, 16 colours | `[B:main.c:main]` (default size), `[P:README.md]` |
| Playfield | 320 x 176 px = 20 x 11 tiles; status panel 24 px at the bottom | `[B:game.h PANEL_H, TILEMAP_SCREEN_H]`, `[P:scripts/play_native.py VIEWPORT_H]` |
| Tile | 16 x 16 px | `[B:level.c:level_draw_tile, level_get_player_tile_pos]` |
| Map | 256 columns x 12..173 rows; cell index = row * 256 + column | `[B:level.c:load_level_data_get_tilemap_size, level_get_tile]` |
| Axes | +x right, +y **down** | `[B:level.c:level_draw_objects]` |
| Hero position | (x, y) = integer px of the **bottom-centre "feet point"**. Standing on flat ground, y equals the top pixel row of the floor tile (a multiple of 16) | `[B:level.c:level_update_tile_attr1_helper]`, `[P:pre2/recovered/player_collision.py:collision_land @641F]` |
| Velocity | signed 16-bit v16 ("12.4"), x and y separately | `[P:docs/pre2/player_fsm_island.md "Player struct fields"]` |
| Integration | `x += floor16(xvel)`, `y += floor16(yvel)` once per tick. **There is no sub-pixel position**: the fraction is thrown away every tick | `[B:level.c:level_update_player (update_pos)]`, `[P:pre2/recovered/player.py:player_x_integrate @5A0F, player_y_integrate @5A36]` |
| Facing | +1 right, -1 left; sprites are mirrored for -1 | `[B:level.c:level_update_object_anim]` |

Consequences of `floor16` (important for feel, `[SIM]`):

| v16 | px moved that tick | v16 | px moved that tick |
|---|---|---|---|
| +1 .. +15 | 0 | -1 .. -16 | -1 |
| +16 .. +31 | 1 | -17 .. -32 | -2 |
| +68 | 4 | -68 | **-5** |
| +80 | 5 | -80 | -5 |

Leftward and upward motion is therefore up to 1 px/tick faster than the same v16 rightward/downward, except at exact
multiples of 16. This asymmetry is part of the original feel (sections 5.4, 6.4).

**Horizontal commit rule.** The x step is applied only if the new x satisfies `8 <= x < 4088` and
`x < (max_camera_column + 20) * 16`; otherwise x keeps its old value and `xvel` is left unchanged
`[B:level.c:level_update_player (update_pos)]`, `[P:pre2/recovered/player.py:player_x_integrate X_MIN, X_MAX, VIEW_TILES]`.
The y step is unconditional.

### 2.1 Hero boxes

The hero has **two** collision representations:

1. **Against tiles**: single points (section 11.2) - the feet point, a wall probe 9 px ahead, a head probe.
2. **Against sprites** (enemies, items, platforms): the bounding box of the *current animation frame*:
   `left = x - x_offset`, `right = left + width`, `bottom = y`, `top = y - height` `[B:level.c:level_objects_collide]`,
   `[P:pre2/recovered/combat_interaction.py:hitbox_overlap @8D7B]`.

Frame boxes of the original hero (width x height, x_offset), from `[B:staticres.c spr_size_tbl, spr_offs_tbl]`; use them
as targets when authoring our own frames:

| Pose | Box (w x h) | x_offset |
|---|---|---|
| Stand | 32 x 35 | 15 |
| Walk cycle (6 frames) | 24..40 x 34..37 | 12..20 |
| Jump rising | 32 x 38, then 40 x 31 | 16, 20 |
| Falling | 40 x 31 (48 x 31 after 12 ticks of falling) | 20 (24) |
| Crouch | 40 x 30..31 | 20 |
| Crawl cycle | 24..40 x 30..32 | 12..20 |
| Hurt | 48 x 32 | 24 |
| Riding test (platforms) | always 32 x 35 | 16 |

Recommendation for our art: stand/walk/jump box 32 x 35, crouch/crawl box 40 x 30, both with `x_offset = width / 2`.

### 2.2 Sprite-overlap test (used everywhere)

For two objects A and B (`[B:level.c:level_objects_collide]`, `[P:...:hitbox_overlap @8D7B]`). A is the first
argument: the hero in hero-vs-enemy and hero-vs-platform tests, the item in item-vs-hero tests, the weapon in weapon
tests.

1. Reject if `|A.x - B.x| >= 64` or `|A.y - B.y| >= 70`.
2. Let *low* be the object with the larger y and *high* the other (A is *low* on a tie). `top = low.y - low.height`.
   Reject if `top >= high.y`. (Only the lower object's height matters.)
3. Unless this is a weapon test: `depth = high.y - top`. The **stomp flag** is set when
   `hero.yvel >= 128`, **or** when `depth <= low.height / 2` and *low* is not the hero. `depth` is remembered.
   The flag is cleared at the start of every test `[P @8D81]` (`[B]` never clears it - a rewrite bug, `[B!=P]`).
4. Horizontal: compute both left edges (`left = x - x_offset`; the same `x_offset` is used for mirrored sprites).
   Let *L* be the object whose left edge is further left (on a tie: *low*), `w = L.width`.
   Unless this is a weapon test, `w = w / 2`. Overlap if `L.left + w > other.left`.

"Weapon test" = club box or thrown weapon against enemies/bosses (full widths, no stomp flag).
Body contacts are forgiving: only the left half of the left-most box counts.

---

## 3. Order of operations in one tick

`[B:level.c:do_level]`, `[P:pre2/native/loop.py:native_gameplay_frame, _frame_tail_after_trigger]`:

1. Dust-puff animation (cosmetic).
2. **Weapon pass**: every thrown weapon in flight, then the club box *created during the previous tick*, is tested
   against enemies, then (if nothing was hit) against hidden-bonus tiles. A club hit while `yvel != 0` sets
   `yvel = -80` (section 9).
3. Enemies and bosses update.
4. Thrown weapons move. 5. Bonus items / bones move. 6. Score pop-ups rise.
7. **Platforms** move, then test whether the hero rides them (section 11.4). May move the hero and set `on_platform`.
8. **Hero update**:
   a. delete the club box; b. read input, update `facing`; c. select the state (section 4);
   d. run the state handler (sections 5-8): changes velocities, animation, creates the club box;
   e. x integration (commit rule); f. y integration;
   g. tile collision (section 11.2): ground / airborne physics / ceiling / wall probe / hazard probes;
   h. glider overlay; i. decrement timers `charge`, `swing_lock`, `shake`, `drop_timer`, `feast` (each stops at 0)
   `[P:pre2/recovered/player.py:player_tick_timers @5A47]`.
9. **Hero vs enemies**, then **hero vs items** (section 10).
10. Item list refresh. 11. Gates (doors). 12. Rising columns.
13. **Camera follow** (section 12).
14. Draw. `hit_timer` of every drawn object is decremented here, once per tick `[B:level.c:level_draw_objects]`.
15. Level state: death / respawn / level end. 16. Extra-life check, wait for the tick.
17. Light fade, BONUS-letter and cutlery events. 18. **Screen-shake apply** (may nudge the hero, section 13.3).

Order matters: the airborne acceleration of step 8g happens *after* integration, and the club box of tick N hits on
tick N+1.

---

## 4. Controls and state selection

### 4.1 Inputs

Six level-triggered flags, sampled once per tick: **LEFT, RIGHT, UP, DOWN, FIRE, LOOK**
`[P:pre2/recovered/input_decode.py:decode_input @0DC1]`, `[B:game.c:update_input]`.
Everything is "held", nothing is edge-triggered: holding UP re-jumps, holding FIRE re-swings.

- UP is the jump (one-button joystick heritage). `[B]` offers a separate jump button as an option
  `[B:level.c:level_update_player (jump_button)]`; we map a jump button onto the UP flag.
- Original keys: cursor keys, Space or Enter = FIRE, keypad 5 = LOOK `[INFERRED]` (decoded from the scancode-flag
  offsets in `[P:input_decode.py _KBD_SOURCES]`, calibrated on F1; `[B:sys_sdl2.c:handle_keyevent]` uses the same
  arrows / Space / Enter).

### 4.2 Facing

Every tick, before the state is chosen: if RIGHT is held and LEFT is not, `facing = +1`; else if LEFT is held and
RIGHT is not, `facing = -1`; otherwise unchanged `[B:level.c:level_update_player]`,
`[P:pre2/recovered/player.py:player_fsm_frontend @58A7]`. Facing flips instantly, even in mid-air and mid-swing.

### 4.3 State table

The state is recomputed from the inputs every tick (the hero has no stored movement state)
`[B:staticres.c player_anim_lut]`, `[P:pre2/recovered/player.py:player_select_anim_id @5921, table @7B7F]` (identical
in both sources):

| Direction keys | none | FIRE | DOWN | DOWN+FIRE | UP | UP+FIRE | UP+DOWN | UP+DOWN+FIRE |
|---|---|---|---|---|---|---|---|---|
| none | 0 idle | 3 strike | 5 crouch | 7 low strike | 2 jump | 6 high strike | 0 | 0 |
| LEFT | 1 walk | 3 | 4 crawl | 7 | 2 | 6 | 1 | 0 |
| RIGHT | 1 walk | 3 | 4 crawl | 7 | 2 | 6 | **0** | 0 |
| LEFT+RIGHT | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

(The LEFT / RIGHT difference under UP+DOWN is in the original table.)

Overrides, applied in this order:

1. `swing_lock > 0`: all inputs count as released for the table (state 0). Held LEFT/RIGHT still counts for the
   acceleration primitive `[B:level.c:level_update_player]`, `[P:player_select_anim_id (suppress)]`.
2. `hit_timer >= 22`: state 8 (hurt) `[B:level.c:level_update_player]`, `[P:player_select_anim_id (depth >= 0x16)]`.
3. Carrying the hang-glider: glider state set (section 13.2).
4. `attack_gate` set (a strike is in progress): states 0, 1, 2, 4, 5 run the strike handler for the strike already
   in progress instead of their own `[B:level.c:level_update_player_anim_0/1/2/4/5]`,
   `[P:pre2/recovered/player.py:player_fsm_step (override tail @5F93)]`. States 3/6/7 always run the strike handler with
   their own number, so switching between strike types restarts the animation.

---

## 5. Horizontal movement

### 5.1 Primitives

| Name | Rule | Source |
|---|---|---|
| `ACCEL(limit)` | if LEFT or RIGHT is held: `xvel += (facing * 16) >> ice`; then clamp `xvel` to `[-limit, +limit]` (the clamp also applies when nothing is held) | `[B:level.c:level_update_player_hdir_x_velocity]`, `[P:player.py:player_accel @62B1]` |
| `FRICTION` | reduce `|xvel|` by `12 >> ice`, not below 0 | `[B:level.c:level_update_player_x_velocity]`, `[P:player.py:player_friction_sym @6333]` |
| `WIND` | `xvel -= wind >> 3`; then if `xvel < -96`, `xvel = -96`. With no wind this is only the **-96 floor on leftward speed** | `[B:level.c:level_update_screen_x_velocity]`, `[P:player.py:player_friction_dir @62EC, XVEL_FLOOR]` |

| Constant | v16 | px/tick | px/s or px/s^2 |
|---|---|---|---|
| Ground acceleration | 16 per tick | 1 px/tick^2 | 589.3 px/s^2 |
| Ground / air braking | 12 per tick | 0.75 px/tick^2 | 442.0 px/s^2 |
| Walk speed cap | 80 | 5 | 121.4 px/s |
| Crawl speed cap | 32 | 2 | 48.6 px/s |
| Jump-held air cap (nominal) | 48 | 3 | 72.8 px/s |
| Leftward floor | -96 | -6 | -145.7 px/s |

### 5.2 State handlers (velocity part)

| State | Per tick | Source |
|---|---|---|
| 0 idle | `WIND`; `FRICTION`; if airborne (`yvel != 0` and not `on_platform`): `WIND` once more when `jump_ticks > 4`, nothing else. On the ground: animation choice only (5.5) | `[B:level.c:level_update_player_anim_0]`, `[P:player.py:player_state_idle @5CDB]` |
| 1 walk | `idle_timer += 1` (max 255); `ACCEL(80)`; `WIND` | `[B:...anim_1]`, `[P:player_state_run @5EC4]` |
| 2 jump | section 6.1 | |
| 3/6/7 strike | `FRICTION`; `idle_timer += 1`; section 8 | `[B:...anim_3_6_7]`, `[P:player_state_attack @5F96]` |
| 4 crawl | `idle_timer = 0`; `drop_timer = 4`; `charge` (section 8.5); if `|xvel| <= 32`: `ACCEL(32)`, else run the idle handler | `[B:...anim_4]`, `[P:player_state_anim4 @5E62]` |
| 5 crouch | `drop_timer = 4`; `FRICTION`; `charge` | `[B:...anim_5]`, `[P:player_state_anim5 @5E96]` |
| 8 hurt | `WIND`; `FRICTION` | `[B:...anim_8]`, `[P:player_state_anim8 @5CCE]` |

**Airborne step.** Whenever the tile collision finds no ground (section 11.2) and the hero is not on a platform, it
additionally applies `ACCEL(80)` and gravity (section 6.2), in that order, *after* the position was integrated
`[B:level.c:level_update_player_decor, level_update_player_jump]`, `[P:player_collision.py:collision_airborne @63B5]`.

Notes:

- Walking has **no friction**: with a direction held only `ACCEL` runs. Braking happens only in states 0, 3, 5, 6, 7, 8.
- Crouch and crawl do not run `WIND` (immune to wind).
- Air control is full: in the air with a direction held and UP released, `ACCEL` runs twice per tick (handler +
  airborne step) = 32 v16/tick.
- With no direction held the idle handler brakes in the air exactly as on the ground (12 v16/tick).

### 5.3 Resulting ground motion `[SIM]`

| Manoeuvre | Result |
|---|---|
| Start from rest, direction held | xvel 16, 32, 48, 64, 80: top speed after **5 ticks** (0.21 s), 15 px covered |
| Release at full speed, moving right | 7 ticks (0.29 s) to stop; slides **12 px** (4, 3, 2, 2, 1, 0, 0) |
| Release at full speed, moving left | 7 ticks; slides **17 px** (5, 4, 3, 2, 2, 1, 0) |
| Reverse at full speed (hold the opposite key) | facing flips at once; 5 ticks to zero (10 px overshoot), 5 more to full speed: 10 ticks (0.41 s). No friction is added: it is `ACCEL` alone |
| Wall | section 11.2: the step is undone and `xvel = 0` |

### 5.4 Resulting air motion `[SIM]`

| Situation | px per tick |
|---|---|
| Direction held, UP released (walking off a ledge, or after releasing jump) | 5 either way (xvel +/-80) |
| UP held + RIGHT held | **4** (handler brakes 80 -> 68, move 4 px, airborne step restores 80) |
| UP held + LEFT held | **5** `[B!=P]` (same v16 -68, but `floor16` gives -5). `[B]` gives 3 - see 14.1 #1 |
| No direction held | brakes 12 v16 per tick to 0 |
| Reverse in mid-air, UP released | 32 v16 per tick: +80 to -80 in 5 ticks |
| Start moving in mid-air from xvel 0, UP released | 32 v16 per tick: 32, 64, 80 (x = 1, 4, 9, then 5 px/tick) |
| UP **held while falling** (`no_jump > 0`, so the idle handler runs) + direction | friction 12 then airborne +16: net only **+4 v16 per tick** from rest (16, 20, 24, ...); at full speed 4 px/tick right, 5 left |

Holding UP therefore weakens air control for the whole jump, not only for its rising part: a player who wants to
steer while falling must release UP.

### 5.5 Ground animations that depend on motion (cosmetic)

`[B:level.c:level_update_player_anim_0]`, `[P:player.py:player_state_idle @5CDB]`:

- `|xvel| >= 8`, no input, moving the way he faces: **skid** animation with a dust puff every 4th tick (in `[B]` only
  when facing left - `[B!=P]` #5). Moving against his facing: standing frame.
- `xvel == 0` and `idle_timer >= 30` and no LOOK input: **out-of-breath** animation; `idle_timer -= 3` per tick.
  `idle_timer` counts walking/striking ticks and is zeroed by crawling.
- `xvel == 0` otherwise: **look-around** if LOOK (or LEFT+RIGHT) is held (section 12.3), else stand / timed fidget.

---

## 6. Jumping, gravity, falling

### 6.1 Jump handler (state 2)

`[B:level.c:level_update_player_anim_2, level_update_player_anim_2_helper]`,
`[P:pre2/recovered/player.py:player_state_jump @5F30, _jump_body @5F41, JUMP_IMPULSE_TABLE @79CE]`:

1. If `no_jump > 0`: run the idle handler instead (no jump).
2. Otherwise - **regardless of whether the hero is on the ground**:
   - `on_platform = false`;
   - `n = jump_ticks`; `jump_ticks += 1`;
   - if `n < 9`: `yvel += IMPULSE[n]` with `IMPULSE = -65, -51, -35, -20, -10, -5, -2, -1, 0` (v16)
     `[B:level.c:level_update_player_anim_2_helper (table)]`;
     else: gravity (6.2);
   - horizontal: if `xvel`, **read as an unsigned 16-bit number**, is below 48: `ACCEL(48)`; otherwise `FRICTION`.
     So `0 <= xvel < 48` accelerates towards 48, `xvel >= 48` brakes, and **every negative xvel brakes**
     `[P:_jump_body @5F73 "jb (unsigned)"]`. `[B]` compares signed - `[B!=P]` #1;
   - `WIND` twice.

`jump_ticks` is reset to 0 only by a soft landing or by riding a platform (11.2, 11.4). The hero can therefore not
start a second jump in the air, but releasing and re-pressing UP *while still rising* continues the impulse table
where it stopped.

### 6.2 Gravity

`GRAVITY: yvel = min(yvel + 16, 192)` `[B:level.c:level_update_player_y_velocity]`,
`[P:player.py:player_gravity @6309]`. (Glider descent: +4, cap 24 - section 13.2.)

| Constant | v16 | px | per second |
|---|---|---|---|
| Gravity | 16 per tick | 1 px/tick^2 | 589.3 px/s^2 |
| Terminal fall speed | 192 | 12 px/tick | 291.3 px/s |
| Total jump impulse | -189 over 9 ticks | | |
| Peak rise speed (full hold) | -123 when integrated on tick 4 (-107 stored after that tick's gravity) | 8 px/tick on ticks 3-5 | 194 px/s |

Gravity is applied in **two** places:

- by the airborne step of the tile collision, every tick the hero has no ground (5.2);
- by the jump handler once `jump_ticks >= 9`, if UP is still held and `no_jump == 0`.

So while UP is held, from the 10th tick of a jump until the apex gravity is **doubled** (32 v16 per tick).

### 6.3 Airborne bookkeeping (in the tile collision)

After the airborne step `[B:level.c:level_update_player_jump, level_update_player_decor]`,
`[P:player_collision.py:collision_airborne @63B5, collision @5B31]`:

- if `yvel > 0`: `no_jump = 6`; falling sprite (a second, wider one once `fall_ticks >= 12`); `fall_ticks += 1`;
- if `yvel <= 0`: nothing.

### 6.4 Resulting jump `[SIM]`

Standing jump, UP held throughout (height above the take-off point, end of each tick):

| Tick | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 | 21 | 22 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Height px | 5 | 12 | 20 | 28 | 36 | 43 | 49 | 54 | 58 | 60 | 60 | 59 | 57 | 54 | 50 | 45 | 39 | 32 | 24 | 15 | 5 | 0 |
| yvel after tick | -49 | -84 | -103 | -107 | -101 | -90 | -76 | -61 | -45 | -13 | 19 | 35 | 51 | 67 | 83 | 99 | 115 | 131 | 147 | 163 | 179 | land |

- Apex **60 px** (3.75 tiles) at ticks 10-11 (0.41-0.45 s); airborne 21 ticks, lands on tick 22 (0.91 s).
- **Variable height** - UP held for k ticks, then released:

| k (ticks held) | 1 | 2 | 3 | 4 | 5..9 | 10 | 11 or more |
|---|---|---|---|---|---|---|---|
| Apex px | 15 | 33 | 48 | 56 | **64** | 61 | 60 |
| Ticks airborne | 10 | 16 | 20 | 22 | 23 | 22 | 21 |

  Releasing UP after 5-9 ticks gives the highest jump (64 px = exactly 4 tiles), because holding longer doubles gravity.
- **Distance on flat ground**, direction held from a running start:

| Technique | Right | Left |
|---|---|---|
| UP held all the way | 88 px (5.5 tiles) | 110 px (6.9 tiles) `[B!=P]`; 84 px in `[B]` |
| UP released after k = 5..9 ticks ("long jump"), lands on tick 24 | 115, 114, 113, 112, 111 px (k = 5..9; about 7 tiles) | 120 px (7.5 tiles) for every k |
| UP released after k = 1..4 ticks | 54, 83, 102, 111 px | 55, 85, 105, 115 px |
| Standing start, UP held | 81 px | 82 px |

  Going right, every tick spent in the jump handler costs 1 px (4 instead of 5 px/tick), so the longest rightward
  jump is the one released on tick 5.

- **No coyote time**: the tick the feet point leaves the floor, gravity makes `yvel = 16 > 0` and sets `no_jump = 6`.
  Pressing UP on that same tick still jumps (the handler runs before the collision); one tick later it does not.
- **Landing lock-out**: `no_jump` only counts down on grounded ticks (one per tick, 11.2). After any fall the hero
  must spend **6 ticks on the ground** (the landing tick and 5 more, 0.25 s) before the jump handler works again.
  Holding UP therefore gives a jump every 27 ticks (1.11 s): take-off on tick 1, landing on tick 22, take-off on tick 28.
  While UP is held during the lock-out the *idle* handler runs, so a held direction does not walk: the hero brakes
  (80, 68, 56, 44, 32, 20, 8 v16) and the next jump starts almost from rest. UP + RIGHT held continuously lands at
  x = 88, 177, 266 px (ticks 22, 49, 76) `[SIM]`.
- **No ledge grab, no wall jump, no double jump.** The hero is supported by one point, so he can overhang a ledge by
  half his width.
- **Jumping through floors from below**: floors never stop upward motion (11.1).
- Ceilings: 11.2.

### 6.5 Falling and landing

Free fall from rest: 0 px on the tick the floor is lost, then 1, 2, 3, ... 12 px per tick, then 12 px/tick; terminal
speed 12 ticks later (0.49 s, 78 px) `[SIM]`.

Landing rules `[B:level.c:level_update_tile_attr1_helper]`, `[P:player_collision.py:collision_land @641F]` (full
procedure in 11.2):

| Condition at touchdown | Effect |
|---|---|
| `fall_ticks <= 4` | soft landing: `yvel = 0`, nothing else |
| `fall_ticks > 4` | dust puff |
| ... and landed >= 32 px below `last_ground_y`, with `yvel >= 80` | counts as a drop |
| drop with `fall_ticks >= 20` and `yvel > 160` | screen shake 8 (section 13.3). Needs more than 162 px of fall after walking off a ledge: floors **11 tiles (176 px) or more** below `[SIM]` |
| drop with `fall_ticks > 10` | **hard landing**: `yvel = -32` (a 3 px hop: 4 ticks in the air, touching down again on the 5th tick after the hard landing, which re-arms `no_jump`), landing sprite. Needs more than 55 px of fall after walking off a ledge: floors **4 tiles (64 px) or more** below; 1-3 tiles are soft `[SIM]`. On levels whose scroll flag bit 0 is set the hop is skipped (he settles one tick later) |

`fall_ticks` counts ticks with `yvel > 0`, so the descent of a jump counts too: a full-hold jump already has
`fall_ticks = 11` when it comes back to its take-off height (soft only because the drop is 0 px), and the same jump
onto a floor 2 tiles (32 px) lower is a hard landing `[SIM]`.

Walking off a ledge at full speed (tick 1 = the tick the floor is lost) `[SIM]`:

| Floor below (tiles) | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Touchdown tick | 7 | 9 | 11 | 12 | 14 | 15 | 16 | 18 | 19 | 20 | 22 | 23 |
| yvel at touchdown (v16) | 96 | 128 | 160 | 176 | 192 | 192 | 192 | 192 | 192 | 192 | 192 | 192 |
| Landing | soft | soft | soft | hard | hard | hard | hard | hard | hard | hard | hard + shake | hard + shake |
| Horizontal travel past the edge at touchdown, direction held (px) | 30 | 40 | 50 | 55 | 65 | 70 | 75 | 85 | 90 | 95 | 105 | 110 |

---

## 7. Crouch, crawl, look, climbing, slopes, ice

- **Crouch** (DOWN): brakes with `FRICTION`, box about 5 px lower, `drop_timer = 4` (lets him fall through hatch tiles
  and enter gates, 11.1 / `GAMEPLAY.md` 7.5), charges the club (8.5), immune to wind and to the screen-shake nudge.
- **Crawl** (DOWN + direction): cap 32 v16 = 2 px/tick (48.6 px/s), acceleration 16 v16 per tick, no friction while
  below the cap; entering a crawl above 32 v16 slides (idle handler) until slow enough (from full speed: 68, 56, 44,
  32 v16, then a steady 2 px/tick). Side effects as crouch (`drop_timer`, charge), with two exceptions: the
  screen-shake nudge is skipped only in the crouch state itself, not while crawling, and the slide runs the idle
  handler and is therefore exposed to wind.
- Tiles never check the upper body for solidity (11.2), so crouching is **not** needed to pass under low ceilings; it
  only changes the sprite box (enemy contact) and which hazard rows are probed.
- **Look** (LOOK key, or LEFT+RIGHT, while standing still on the ground): camera pans in the facing direction (12.3).
  There is **no look up / look down**.
- **Climbing: none.** Neither source contains a ladder, rope or vine state; the state table of 4.3 is complete.
  Vertical travel is done with jumps, enemy bounces, moving platforms and the glider.
- **Slopes**: purely a height profile of floor tiles (11.1). Gradient 1 px per 3 px (5 px per tile). No sliding force,
  no speed change; the hero is snapped to the surface while walking up or down (11.2).
- **Slippery ground** `ice = 1, 2, 3`: both `ACCEL` and `FRICTION` are shifted right by `ice`:

| ice | Acceleration v16/tick | Braking v16/tick | Ticks 0 -> 80 | Ticks 80 -> 0 |
|---|---|---|---|---|
| 0 | 16 | 12 | 5 | 7 |
| 1 | 8 | 6 | 10 | 14 |
| 2 | 4 | 3 | 20 | 27 |
| 3 | 2 | 1 | 40 | 80 |

  The top speed stays 80. `ice` is set by the floor tile each grounded tick and **keeps its last value while
  airborne**, so a jump off ice has ice-grade air control `[B:level.c:level_update_tile_attr1_type_2..4]`,
  `[P:player_collision.py:collision_ground_handler idx 2-4]`.

---

## 8. Club attack

`[B:level.c:level_update_player_anim_3_6_7, level_update_objects_axe, level_collide_axe_monsters, level_collide_axe_bonuses]`,
`[B:staticres.c club_anim_tbl, club_anim_data, object_anim_tbl]`,
`[P:pre2/recovered/player.py:player_state_attack @5F96, _attack_render_sprite @6081, _attack_spawn @6017]`.

### 8.1 Timeline

Each strike plays a fixed frame script, one entry per tick; the last entry carries an "end" mark.

| Strike | Input | Script (frame x ticks) | Length |
|---|---|---|---|
| Forward | FIRE | wind-up back x2, overhead x2, **front x3** | 7 ticks (0.29 s) |
| High | UP+FIRE | low-back x3, back-up x3, **front-high x3** | 9 ticks (0.37 s) |
| Low | DOWN+FIRE | back x3, overhead x3, **front-low x3** | 9 ticks (0.37 s) |

Every tick of the script: `FRICTION` on `xvel` (the hero slides to a stop while striking), no jump impulse, no
handler gravity. `attack_gate` is set on every tick except the last, so the strike cannot be interrupted by movement
input (4.3). On the **last tick**:

- `swing_lock = L` (weapon value below; it is decremented at the end of the same tick, so inputs are ignored for
  **L - 1** further ticks);
- strike sound; hop: `yvel += -32` (forward), `0` (high), `-48` plus a dust puff (low) - skipped on a platform.
  The hop is real `[SIM]`: after a forward strike the hero rises 3 px and is airborne on strike ticks 7-10 (4 ticks,
  grounded again on tick 11); after a low strike he rises 6 px and is airborne on ticks 9-14 (6 ticks, grounded on
  tick 15). `no_jump` is re-armed when he comes down. Because of the hop the box of the **last** tick of a forward
  or low strike is tested (one tick later) while `yvel != 0`, so a hit with that box on the ground triggers the pogo
  of section 9 (`yvel = -80`), whereas a hit with the boxes of the earlier ticks (or with any box of the high
  strike, which has no hop) does not;
- thrown weapons spawn the projectile (8.4) and show no club box that tick; if `fall_ticks != 0` (descending in the
  air) no club box is produced that tick either.

| Weapon | Kind | Power | L | Recovery (ignored-input ticks) | Auto-repeat period, forward strike, FIRE held |
|---|---|---|---|---|---|
| 0 club | melee | 25 | 2 | 1 | 8 ticks (0.33 s) |
| 1 hammer | melee | 30 | 6 | 5 | 12 ticks |
| 2 axe | thrown | 20 | 6 | 5 | 12 ticks |
| 3 swirling axe | thrown | 30 | 12 | 11 | 18 ticks |

In frame-data terms (default club, forward strike): **start-up 4 ticks, active 3 ticks, recovery 1 tick**.
Counted from the first tick FIRE is held (tick 1) `[SIM]`:

| Strike | Front box created on ticks | Front box hit-tested on ticks (next tick's weapon pass) | Inputs ignored on | Next strike can start on | Period with FIRE held (club) |
|---|---|---|---|---|---|
| Forward | 5, 6, 7 | 6, 7, 8 | 8 | 9 | 8 ticks |
| High | 7, 8, 9 | 8, 9, 10 | 10 | 11 | 10 ticks |
| Low | 7, 8, 9 | 8, 9, 10 | 10 | 11 | 10 ticks |

So the earliest forward damage lands 5 ticks (0.21 s) after the press; the wind-up boxes (behind / above) are tested
on ticks 2-5.

### 8.2 Club box

Each tick of the script creates one club box from the hero's current frame. Its origin is
`(x + floor16(xvel) -/+ dx, y + floor16(yvel) - dy)` (dx mirrored when facing left) and its size is that of the club
sprite. The box is tested **once, in the weapon pass of the next tick** (section 3), with the weapon variant of the
overlap test (2.2). Default club, facing right, relative to the feet point (derived from `[B:staticres.c]` tables):

| Frame | x range | y range | Box origin (x, y) | Meaning |
|---|---|---|---|---|
| Forward: wind-up | -19 .. -3 | -35 .. -16 | (-11, -16) | behind the back |
| Forward: overhead | -19 .. +5 | -43 .. -25 | (-7, -25) | above the head |
| Forward: **front** | **+11 .. +35** | **-15 .. -2** | (+23, -2) | the strike: reaches 35 px ahead, low |
| High: low-back | -19 .. -3 | -19 .. -3 | (-11, -3) | |
| High: back-up | -16 .. 0 | -37 .. -21 | (-8, -21) | |
| High: **front-high** | **+10 .. +26** | **-43 .. -27** | (+18, -27) | reaches 26 px ahead at head height and above |
| Low: back | -16 .. 0 | -33 .. -18 | (-8, -18) | |
| Low: overhead (ticks 4-6) | -19 .. +5 | -43 .. -25 | (-7, -25) | same frame as the forward overhead |
| Low: **front-low** | **-3 .. +21** | **-5 .. +10** | (+9, +10) | reaches 10 px **below** the feet line |

The x range is the box used against enemies (left edge = origin.x - club x_offset, width of the club sprite); the y
range is origin.y - height .. origin.y. The origin (bottom anchor of the club sprite) is what the hidden-tile test of
8.3 uses. When facing left, mirror the origin's x; the enemy test then still subtracts the same (unmirrored)
x_offset from it, as for every sprite (2.2) - which makes no difference for the club and the hammer, whose x_offset is
exactly half their width, so their boxes mirror exactly.

The hammer has larger boxes (front: +2 .. +50 by -16 .. +10, origin (+26, +10)). For our art, author the boxes per
frame; these are the reference extents `[INFERRED]` for our sprites.

Wind-up frames are live too: the club can hit things behind and above the hero.

### 8.3 What a box can hit

In one weapon pass a box hits **at most one** target and is consumed by it `[B:level.c:level_update_objects_axe]`,
`[P:pre2/native/loop.py:_combat_source_pass]`:

1. The first enemy (in slot order) that is alive, not flagged invulnerable, and overlaps: `energy -= power`; dead if
   below 0, else it is pushed back by `enemy_xvel >> 2` px (four ticks' worth of its own movement). Because every tick
   of a strike makes a new box, an enemy standing in the strike can be hit on up to 3 consecutive ticks.
2. Otherwise the first hidden-bonus / breakable tile with `|tile_col - (box.x >> 4)| <= 1` and
   `|tile_row * 16 - (box.y - 16)| < 16` (box.x, box.y = box origin) `[B:level.c:level_collide_axe_bonuses]`.
3. Bosses test the box in their own update (`GAMEPLAY.md` section 6).

A club-box hit on an enemy or on a hidden tile (cases 1 and 2) while the hero's `yvel != 0` sets `yvel = -80`
(**pogo**, section 9). Thrown weapons never pogo.

### 8.4 Thrown weapons

Up to 4 in flight. Spawn at the hero with `xvel = +/-208` (13 px/tick, 315.6 px/s). Axe: `yvel = -64`, then +32 per
tick (arc). Swirling axe: `yvel = -32`, then -16 per tick (curves upward). No tile collision; removed on a hit or when
not drawn in the previous frame (off screen) `[B:level.c:level_update_objects_club_projectiles]`,
`[P:player.py:_attack_spawn @6017]`. Spawn origin: hero position `[B]` vs club-box position `[P]` (`[B!=P]` #9).

### 8.5 Charge (4x damage)

While crouching or crawling, each tick: if `charge <= 48`, `charge += 2`. `charge` is decremented by 1 at the end of
every hero update. While `charge > 0` every strike uses `power * 4` (100 / 120 / 80 / 120)
`[B:level.c:level_update_player_club_power]`, `[P:player.py:player_charge_6bce @5EB7, player_state_attack]`.
Net +1 per tick: after k crouched ticks `charge = k`, saturating at 48/49 (it alternates) from the 48th tick on; a
full charge lasts 48-49 ticks (2.0 s) after standing up `[SIM]`. (`[B]` charges twice per crouch tick - `[B!=P]` #4.)

The multiplier is re-evaluated on **every tick of the strike** (the power stored with each tick's box is the one
used when that box is tested), and the strike handler itself does not charge - not even the low strike, which is
entered with DOWN held. `charge` keeps running down during the swing, so `[SIM]`:

| Crouched ticks before a forward strike | 1-4 | 5 | 6 | 7 or more |
|---|---|---|---|---|
| Charged (x4) *front* boxes (strike ticks 5, 6, 7) | none (only wind-up boxes are x4) | tick 5 | ticks 5-6 | all three |

For the 9-tick high / low strikes the front boxes (ticks 7-9) need 7 / 8 / 9 crouched ticks. One crouched tick is
therefore **not** enough for a charged hit in front.

---

## 9. Bouncing

There are **no spring or trampoline tiles** in the engine (`GAMEPLAY.md` 7.2). All bounces are velocity overrides:

| Event | Condition | Result | Rise `[SIM]` | Source |
|---|---|---|---|---|
| **Enemy bounce** | hero overlaps an enemy, stomp flag set (2.2), `yvel >= 0`, not gliding | `yvel = -224` if UP held, else `-64`; `fall_ticks = 0`; `y -= depth`. The enemy is **not** damaged; its bounce counter rises (max 11) | 105 px / 10 px | `[B:level.c:level_update_player_collision]`, `[P:player_interaction.py:_loop1_hit_outcome @82C8]` |
| **Club pogo** | club box hits an enemy or a hidden tile while `yvel != 0` | `yvel = -80` | 15 px | `[B:level.c:level_update_objects_axe]`, `[P:loop.py:_combat_source_pass]` |
| Glider bump | gliding, stomp flag, `yvel <= 32` | `yvel = -96` | 21 px | `[P:...:_loop1_hit_outcome @82F0]` |
| Glider dive stomp | gliding, stomp flag, `yvel > 32` | `yvel = -96`; the 3rd stomp kills the enemy | 21 px | `[P:player_interaction.py:_stomp @82F7]` |
| Hard landing | 6.5 | `yvel = -32` | 3 px | |
| Hurt knock-up | 10.1 | `yvel = -128` | 36 px | |
| Boss heads / limbs | boss-specific | `-64` / `-128` (UP held), `-160` | 10 / 36 / 55 px | `[B:bosses.c:level_update_boss_gorilla_hit_player, level_update_boss_tree]` |

**Head-stomp rule in words**: a contact is a harmless bounce when the hero is not rising and either (a) his feet are
within the top half of the enemy's box, or (b) he is falling at 8 px/tick or faster (any contact counts). Every other
contact hurts. The big bounce (-224, 105 px) is 1.75x a jump; with UP held the hero keeps bouncing on the same enemy.
After a bounce `no_jump` is still armed, so the bounce cannot be extended by the jump table.

---

## 10. Damage, energy, lives, death, respawn

### 10.1 Getting hurt

Enemy contact is tested only while `hit_timer == 0` and only against enemies that were drawn in the previous frame
`[B:level.c:level_update_player_collision]`, `[P:player_interaction.py:loop1 @829F, _death @838A]`. If the contact is
not a bounce (section 9):

- hurt sound; `hit_timer = 44`; `attack_gate` cleared (strike cancelled); `glide = 0`;
- `yvel = -128` (rises 36 px);
- `xvel = -(xvel * 4)`: thrown back against his own motion. On the next tick the hurt handler applies the -96 floor
  and `FRICTION`, and because he is now airborne the airborne step clamps `xvel` to +/-80 from then on. Result on flat
  ground `[SIM]`: hit while moving right at full speed -> thrown **23 px left** (6, 5, 4, 3, 2, 2, 1); hit while moving
  left -> thrown **31 px right** (19 px in the first tick, then 4, 3, 2, 2, 1); hit while standing -> straight up.
  Back on the ground on the 17th tick;
- carrying the glider: lose the glider, no energy loss; otherwise `energy -= 1` and death if it goes below 0.

`hit_timer` counts down 1 per tick `[B:level.c:level_draw_objects]`:

| hit_timer | Ticks | Effect |
|---|---|---|
| 43 .. 22 | 22 (0.91 s) | state 8: hurt pose, **no control** (`WIND` + `FRICTION` only) |
| 21 .. 1 | 21 | control restored, still immune to enemies |
| whole 44 | 44 (1.81 s) | blinking (drawn 1 tick in 4); immune to enemy contact only - **not** to deadly tiles, pits, traps or boss projectiles |

Exact count: the hit sets 44 in step 9 of tick T and the draw step of the same tick already makes it 43. The hero
update sees 43..22 on ticks T+1..T+22 (22 stunned ticks; control returns on tick T+23), the contact test is skipped
on ticks T+1..T+43 (43 ticks) and runs again on tick **T+44**: two hits are at least 44 ticks apart `[SIM]`.

Other damage sources: trap item (hurt state, all energy scattered as collectable bones, no death), boss projectile
(-1 energy and 6 bones, death at 0 energy), boss body hits (knock-back `yvel = -128`, `xvel = +/-128` with `ice = 3`,
`hit_timer = 44`; each hit costs one sixth of an energy unit) - `GAMEPLAY.md` sections 5-6,
`[B:level.c:level_update_player_collision; bosses.c:level_update_objects_boss_hit_player]`.

### 10.2 Energy and lives

- Energy starts at **3** on every (re)spawn, maximum 3 `[B:level.c:level_reset]`. A hit at energy 0 kills, so the hero
  survives 3 hits and dies on the 4th `[B:level.c:level_update_player_collision]`, `[P:...:_death (dec, test sign)]`.
- 6 small pick-ups (bones) = +1 energy.
- Lives: counter starts at 2 (three attempts); dying with the counter at 0 is game over; +1 life per 25 000 internal
  points; cap 99 `[B:game.c:game_run; level.c:level_player_die, level_update_panel]`, `[P:player_interaction.py num 0xAE]`.

### 10.3 Instant death

Costs a life regardless of energy and of `hit_timer` `[B:level.c:level_update_tile_type_2, level_update_player_decor]`,
`[P:player_collision.py:_offcamera_trigger @65B3, _out_of_camera_range @5ACD]`:

- deadly floor (spikes), deadly side/body tile, deadly ceiling (11.1);
- feet row more than 11 rows from the camera row, or feet column more than 20 columns from the camera column;
- `y` more than one tile below the bottom of the map (pits);
- auto-scroll levels: `y` above the top of the screen.

### 10.4 Death sequence and respawn

`[B:level.c:level_player_death_animation, level_update_objects_anim]`,
`[P:pre2/native/level_state.py:native_4f6c @4F6C]`:

1. Within one tick of the death trigger (same tick for tile deaths, next tick for enemy hits): death sound, death
   pose, input ignored, tiles ignored.
2. **60 ticks** (2.47 s): each tick `x += 5` if the hero is in the left half of the screen, else `x -= 5`; vertical
   speed starts at 14 px/tick upward and decreases by 1 px/tick every tick down to 16 px/tick downward (rises 105 px in
   14 ticks, then falls off screen). Enemies and items keep animating.
3. Curtain closes. No lives left: game-over scene. Otherwise: level state re-initialised (enemies, platforms, columns,
   camera locks), hero placed at the **active checkpoint** (or the level start) with energy 3, zero velocity; camera
   re-initialised (12.5). Collected items and opened hidden spots stay as they were; weapon pick-ups, the glider
   pick-up and the bomb items reappear; the current weapon is kept; the glider is lost.

**Checkpoint**: touching a restart light stores the hero's current (x, y) as the respawn point and makes it the only
active light `[B:level.c:level_update_player_collision (num 228)]`, `[P:player_interaction.py num 0xE4]`.

---

## 11. Level collision model

### 11.1 Tile property tables

Every tile type (0..255) has four independent property bytes per level
`[B:resource.h struct level_t; resource.c:load_leveldat]`, `[P:player_collision.py table constants]`. "Solid" is not one
flag: floor, wall and ceiling behaviour are separate, so every face is authored independently.

**FLOOR** (tested at the feet point; `[B]` attributes1, `[P]` table 0x7F5E):

| Value | Behaviour |
|---|---|
| 0 | empty. Special case: if `yvel == 0` and the tile **below** has a non-zero HEIGHT with surface offset < 16, step down one row and land on it (keeps him glued to descending slopes) |
| 1 | floor, `ice = 0` |
| 2, 3, 4 | floor, `ice = 1, 2, 3` |
| 5 | **hatch**: floor only while `drop_timer == 0`; crouching/crawling falls through it |
| 6 | deadly (spikes) |
| 7 | nothing |

All floors are **one-way**: a floor tile does nothing while `yvel < 0`.

**SIDE** (tested at the wall probe and the body probes; `[B]` attributes0, `[P]` table 0x7E5E):

| Value | Behaviour |
|---|---|
| 0 | passable (may release cosmetic flies) |
| 1 | wall: undo this tick's x step, `xvel = 0`. Also the "inside a wall" flag of the ceiling corner-slip |
| 2 | deadly at any body row |
| 4 and others | not exercised by the original levels `[INFERRED]` |

**FLAGS** (`[B]` attributes2, `[P]` table 0x805E):

| Bits | Behaviour |
|---|---|
| low nibble 1 | **ceiling**: stops upward motion (head probe) |
| low nibble 2 | deadly ceiling |
| 0x10 | fly source (cosmetic) |
| 0x20 | "step-on" tile: shows its next tile picture while the feet are on it (cosmetic; bridges sag) |
| 0x40 | drawn in front of sprites |
| 0x80 | 3-frame animated tile |

**HEIGHT** (surface profile of floor tiles; `[B]` attributes3, `[P]` table 0x8E1D):

| Value | Surface offset below the tile top |
|---|---|
| 0 | 0 (flat) |
| 1..15 | that many px (lowered flat surface) |
| 0x10 + n | `n + (x mod 16) / 3` - descends to the right, 0..5 px |
| 0x20 + n | `n - (x mod 16) / 3` - ascends to the right |

`[B:level.c:level_get_tile_player_offset]`, `[P:player_collision.py:collision_slope_offset @661A]`.

**Hidden / breakable tiles** are a per-level list of up to 80 cells with a hit count and an alternate tile; the club
or a thrown weapon triggers them (8.3) and the cell changes to its alternate tile when exhausted - which is how walls
"break" `[B:level.c:level_handle_bonuses_found, level_update_found_bonus_tile]`. There are no ladders and no vanishing
tiles.

### 11.2 Hero-vs-tile procedure (step 8g of the tick)

`[B:level.c:level_update_player_decor, level_update_tile0, level_update_tile1, level_update_tile2]`,
`[P:pre2/recovered/player_collision.py:collision @5A96, _collision_worker @5B81]`. Let `col = x >> 4`,
`row = y >> 4` (after integration), `edge = +9, -9 or 0` by the sign of `xvel` (taken now, before any change below).

1. **Out of range** -> instant death (10.3).
2. `airborne = false`.
3. **Above the map** (`y <= -1`): airborne step (5.2), skip all tile tests.
4. **Floor**: look at FLOOR of tile (col, row), the tile containing the feet point.
   - 0: the step-down special case, else `airborne = true`.
   - 1..5 (5 only when `drop_timer == 0`, otherwise `ice = 0` and `airborne = true`): **LAND**:
     - `ice = 0`; if `yvel < 0`: `airborne = true`, stop here;
     - `glide = 0`; `y = y - (y mod 16)`;
     - `h = HEIGHT(col, row)`; if non-zero: `off = surface offset`; while falling (`floor16(yvel) > 0`) `off` is limited to
       `floor16(yvel)`; `y += off`;
       else if `HEIGHT(col, row - 1)` is non-zero and its offset < 16: `y += offset - 16` (walk up onto a slope);
     - landing rules of 6.5; on a hard landing stop here (`yvel = -32`, `fall_ticks = 0`);
     - **soft landing**: `yvel = 0`; `no_jump = max(no_jump - 1, 0)`; `jump_ticks = 0`; `last_ground_y = y`.
     - for FLOOR 2/3/4 set `ice` afterwards.
   - 6: instant death.
5. **Ceiling block** - only if `yvel <= 0` now (rising **or grounded**; skipped only while falling) and `row >= 2`
   `[P:player_collision.py:_collision_worker @5C0D]` (`[B]` requires `yvel < 0` - `[B!=P]` #12). Look at tile
   (col, row - 2).
   - FLAGS low nibble 1 and `yvel != 0`: **head bump**: `yvel = 0`; `y = (y - y mod 16) + 16` (pushed down to the
     next row boundary). The head therefore bumps when the feet are 16..31 px below the ceiling tile's bottom edge and
     ends 32 px below it. With `yvel == 0` nothing happens.
   - low nibble 2: instant death (also for a hero standing or walking under it).
   - **Corner slip**: if SIDE(col, row - 1) has bit 0 (the hero's own body tile is a wall) and `y > 0`: let `d = -1`
     if `xvel > 0` else `+1`; if SIDE(col + d, row - 1) is 0, `x += 2 * d`; else if SIDE(col - d, row - 1) is 0,
     `x -= 2 * d`. This slides him 2 px/tick out of a wall he is inside of, both while rising past a corner and while
     standing `[P:player_collision.py:collision_ceiling @5C16]`.
6. **Airborne result**: if `airborne`: on a platform -> grounded bookkeeping (`no_jump` decrement, `jump_ticks = 0`,
   `fall_ticks = 0`); otherwise the airborne step (5.2) and bookkeeping (6.3). If not airborne: `fall_ticks = 0`.
7. **Wall probe** - only if `y > 0`: tile ((x + edge) >> 4, row - 1), i.e. 9 px ahead in the 16 px above the feet row.
   SIDE 1: `x -= floor16(xvel)`, `xvel = 0` (uses the *current* xvel, which the airborne step may have changed since
   integration); SIDE 2: death.
8. **Body probes**: same column, rows `row - 2`, `row - 3`, ... while `sprite_height - 16 * k > 0` (standing 35 px:
   two rows; crouching 30 px: one row). Only SIDE 2 (deadly) acts here; **walls are not tested above the first row**.

Properties that follow:

- Effective hero half-width against walls: 9 px; walls are sensed only in the row just above the floor row.
- With `xvel == 0` the wall probe sits on the hero's own column and does nothing; a hero who ends up inside a wall
  tile (moving platform, gate exit) is moved out only by the corner slip of step 5, 2 px per tick, and not while falling.
- A 16 px step up blocks (wall probe); a 16 px step down onto a flat tile is a tiny fall (the snap-down only works
  onto HEIGHT-profiled tiles).
- Upper-body tiles do not block: low passages only need SIDE 0 in the bottom row.

### 11.3 Not present

Ladders, ropes, water volumes, conveyor belts, crumbling tiles, springs: none exist in either source.

### 11.4 Platforms (sprite objects)

`[B:level.c:level_update_objects_decors, level_update_objects_decors_helper]`,
`[P:pre2/recovered/terrain_entities.py:tick_terrain_entities @4907, _collision_4b05 @4B05]`. Up to 16 per level, 7 on
screen; processed **before** the hero update.

**Ride test** (per on-screen platform, only while hero `yvel > -16`, only one platform per tick): requires
`platform.y > hero.y`, and the overlap test (2.2, body variant) between the platform sprite and a 32 x 35 hero box whose
bottom is `hero.y + platform_dy` (when the platform moves down). On success:

- `on_platform = true`; `ice = 0`; `hero.x += platform_dx`;
- grounded bookkeeping (`no_jump` decrement, `jump_ticks = 0`, `last_ground_y = y`);
- `top = platform.y - platform.height`; if `hero.y > top`: `hero.y = top + 1`, `yvel = 1`; else `yvel = platform_dy * 16`.

While `on_platform`, the tile collision applies no gravity, the idle handler treats him as grounded, the low/forward
strike hop is skipped, look-around is disabled and the camera follows even at `xvel == 0`. Jumping clears the flag.
Platforms are one-way (rising through them is ignored because of the `yvel > -16` gate).

**Movers** (types 0-7): direction 0 up, 1 up-right, 2 right, 3 down-right, 4 down, 5 down-left, 6 left, 7 up-left;
the same px/tick on both axes. Speed changes by 1 px/tick each tick towards a signed target; once at the target it
travels for a set number of ticks, then the target is negated (ping-pong). A platform runs if it is already moving,
or its target is negative, or it is flagged always-on, or the hero rode it on the previous tick.

**Droppers** (type 8): state 0 waits; with the hero on it a per-platform delay counts down (immediately if it was
still returning); state 1 falls with speed +8 v16 per tick up to 192 (12 px/tick) until its position enters a floor
tile (FLOOR not 0 and not 6) or 3 rows below the map; state 2 rests until the hero has been off it for 22 ticks; then
it returns upward at 8 px/tick.

---

## 12. Camera

The camera position is a tile cell (column, row) plus a vertical fine offset 0..15 px; **horizontally the original
moves in whole tiles** `[B:level.c:level_adjust_x_scroll (dos_scrolling branch), level_adjust_y_scroll]`,
`[P:pre2/native/camera_scroll.py:native_camera_follow @5643]`. `[B]` by default replaces the horizontal part with a
smooth follow that is *not* original (12.6).

### 12.1 Horizontal (authentic)

`[B:level.c:level_adjust_x_scroll]`, `[P:camera_scroll.py:_h_follow @57A8, _h_init @57F6]`. Let
`sc = (x >> 4) - camera_column` (hero's screen column, 0..19 visible). State `dir` = idle / right / left.

- If `sc < 20` and not `on_platform` and `xvel == 0`: `dir = idle`; done (the view never moves while he stands still).
- `dir == idle`: decide a direction: moving right (`xvel > 0`) -> candidate right; moving left -> candidate left;
  `xvel == 0` -> right if `sc >= 10` else left. Candidate right starts when **`sc >= 16`**; candidate left starts when
  **`sc <= 4`**.
- `dir == right`: if `sc <= 5`, or the camera is at its right limit: `dir = idle`; else **camera_column += 1**.
- `dir == left`: if `sc >= 15`, or the camera column is 0: `dir = idle`; else **camera_column -= 1**.

So: a dead zone of columns 5..15 (px 80..255 of 320); when the hero crosses into the last 4 columns ahead of him the
view pages at **16 px/tick (388 px/s)** until he is in column 5 (going right) or 15 (going left), i.e. about three
quarters of the screen is look-ahead. A page takes about 16 ticks (0.66 s) while he keeps walking `[SIM]`.

Limits: `0 <= camera_column <= max_camera_column` (a per-level value; 236 inside gate rooms beyond the level width)
`[B:level.c:tilemap_end_xpos]`, `[P:pre2/views/camera_pan.py:apply_camera_pan @3435]`.

### 12.2 Vertical

`[B:level.c:level_adjust_y_scroll, level_adjust_vscroll_up/down; staticres.c vscroll_offsets_data]`,
`[P:camera_scroll.py:_v_follow @5663, _v_scroll_apply @56EA, _v_speed @5738]`. Let
`sr = (y >> 4) - camera_row` (0..10 visible), `active` a counter.

1. Auto-scroll levels (scroll flag bit 2): the camera moves down 1 px per tick; nothing else.
2. If `yvel == 0`: `active = 0`.
3. Pick a target row:

| Hero | Condition | Target row |
|---|---|---|
| airborne (`yvel != 0`) | `sr >= 9` | 3 |
| airborne | `sr <= 2` | 8 |
| grounded, normal level | `sr >= 10` | 9 |
| grounded, normal level | `sr <= 3` | 8 |
| grounded, level scroll flag bit 0 | `sr >= 8` | 7 |
| grounded, level scroll flag bit 0 | `sr <= 5` | 6 |

   If a row matched: store it, `active += 1`. If `active == 0`: done.
4. Move one step towards the state "`sr == target`": up if `target > sr`, down if `target < sr`, stop
   (`active = 0`) when equal or when the map edge is reached.
5. Step size = speed curve by pixel distance `d` between the hero's y and the target row line:

| d (px) | 0-5 | 6-23 | 24-50 | 51-63 | 64-72 | 73-79 | 80-85 | 86-88 | 89-91 | 92-93 | 94-95 | 96 | 97 | 98 | 99-131 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| px/tick | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 16 |

   (24..388 px/s.) Outside 0..131 no step is taken that tick `[B]`. (The original has no range check: the table is
   followed directly by the second curve below, so d = 132..263 would read that one. Unreachable in normal play,
   because the 16 px/tick top step outruns the 12 px/tick terminal fall.)

   **Second curve `[B!=P]` #14.** The game data holds a second 132-entry curve right behind the first one (the
   first is byte-identical in `[B:staticres.c vscroll_offsets_data]` and `[P:pre2/native/asset_tables.py
   SPEED_CURVE]`; the second exists only in `[P]`'s data). `[P]` uses the first curve only while the
   renderer flag "the visible tile grid contains non-opaque tiles" is 0, and the second one (through a pointer
   stored just in front of the first table) while it is set `[P:pre2/native/camera_scroll.py:_v_speed @5750/578A;
   pre2/recovered/frame_renderer.py:draw_grid @35A1]`:

| d (px) | 0-3 | 4-7 | 8-9 | 10-11 | 12 | 13 | 14 | 15 | 16-19 | 20-26 | 27-35 | 36-48 | 49-65 | 66-89 | 90-99 | 100-131 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| px/tick | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 |

   The flag is recomputed whenever the tile grid is redrawn: it is 1 if any of the 20 x 12 visible tiles has
   transparent pixels (an empty or partly transparent tile picture, through which the backdrop shows), 0 if all of
   them are fully opaque. So **screens on which a backdrop shows through the tile layer scroll vertically with the
   second, much faster curve** (10 px/tick instead of 2 at d = 20), and only screens whose tiles are all opaque use
   the first. In the original this saved full-screen redraws; for us it is simply the camera feel of the two kinds
   of screen. Which of the original levels fall into which class was not determined (it depends on their tile
   pictures) `[INFERRED]`.
   Implement: `fast = any visible tile is not fully opaque` (evaluate per tick, or author it as a per-level /
   per-zone flag), curve = second if `fast` else first. The exact tick on which the original flips the flag is
   `[INFERRED]`.
6. **Level "home row"** (`scrolling_top`, per level): while the hero's y is at or above `(home + 11) * 16`, the camera
   is pulled up whenever it is more than one row below `home`, and a downward step is refused while the camera row is
   below `home`. In effect the main floor of a level has a fixed camera height; the window logic only takes over
   below it `[B:level.c:level_adjust_y_scroll]`, `[P:camera_scroll.py:_v_scroll_apply]`.

Limits: `0 <= camera_row <= map_rows - 11`.

In words: standing, the feet stay between rows 4 and 9 of 11 with no motion at all inside that band; falling into
the bottom two rows scrolls until the feet are in row 3 (view opens downward); rising into the top three rows
scrolls until they are in row 8.

### 12.3 Look-around

While standing still on the ground (not on a platform) with LOOK or LEFT+RIGHT held: look pose; each tick the camera
moves one tile in the facing direction while `sc > 2` (facing right) or `sc < 17` (facing left), within the limits
`[P:pre2/recovered/player.py:player_state_idle @5D8A]`, `[B:level.c:level_update_player_anim_0]` (`[B]` only knows
LEFT+RIGHT - `[B!=P]` #6). The view stays there until he moves.

### 12.4 Locks and special cases

- Level scroll flag bit 1: no horizontal follow at all (vertical-only levels) `[B:level.c:level_update_scrolling]`.
- A gate can set a "no scroll" flag: the camera is placed at the gate's stored cell and neither axis follows until
  the next gate or respawn - this is the **screen lock** used for single-screen rooms and boss rooms
  `[B:level.c:level_update_gates]`, `[P:camera_scroll.py (gate flag 0x6BD9)]`.
- The final boss level is a single fixed screen `[B:level.c:level_update_tilemap (level 9)]`.
- Tree-boss room: an invisible barrier at x > 984 knocks the hero back (`yvel = -144`, `xvel = -160`, hurt)
  `[B:bosses.c:level_update_boss_tree]`.
- There is no camera easing in x, no velocity-based look-ahead and no zoom in the original.

### 12.5 Camera at spawn

Start at cell (0, 0), run the follow rules with a fixed 16 px vertical step until both axes are idle; then, if
horizontal follow is enabled and `sc >= 12`, move right up to 10 columns `[B:level.c:level_init_tilemap]`.

### 12.6 The non-original smooth follow in `[B]`

`[B:level.c:level_adjust_x_scroll]` (default branch): pixel-exact camera that keeps the hero between 128 px and
`width - 128` px of the view (a 64 px dead zone in a 320 px view), clamped to the level, even pixel positions only.
Documented here only as an optional comfort mode (15.6).

---

## 13. Other movement modifiers

### 13.1 Wind (blizzard stage)

`wind` is a per-level scripted value that ramps over time (0 on normal levels). Every `WIND` call subtracts
`wind >> 3` v16 from `xvel` and applies the -96 floor (5.1). Calls per tick: idle 1 (2 while airborne late in a
jump), walk 1, jump 2, hurt 1, crouch/crawl/strike 0 `[B:level.c:level_update_screen_x_velocity, level_draw_snow]`,
`[P:pre2/recovered/scroll_script.py:scroll_script_state @3922]`. Standing still resists any wind below 12 v16 per tick
because `FRICTION` runs after `WIND`. The exact ramp script differs between sources (`[B!=P]` #8).

### 13.2 Hang-glider

`[B:level.c:level_update_player (flying branch), level_update_player_anim_34, level_update_player_flying]`,
`[P:pre2/recovered/player.py:player_fsm_flying @596A, _flying_jump @5F13, player_gravity @6309]`.

- **Carrying on the ground**: walk as usual; **every** other state except jump and hurt (idle, crouch, crawl and the
  three strikes) runs the crouch handler - so no attacks, standing still brakes with `FRICTION` only (no `WIND`), and
  `drop_timer = 4` / charge are set all the time; the hurt state runs no handler at all in `[P]`. Jump impulses
  are halved (`impulse >> 1`, flooring: -33, -26, -18, -10, -5, -3, -1, -1, 0), and the glider jump handler checks
  neither `no_jump` nor the strike gate. Walking at
  `|xvel| >= 64` counts a run-up; after **24 ticks** pressing UP takes off: `glide = 1`, `y -= 3`, lift = 24.
- A fall faster than 160 v16 opens the glider automatically.
- **Gliding** (`glide` bit 0): gravity +4 v16 per tick, sink cap 24 v16 (1 px/tick = 24 px/s). The state handlers are
  skipped, so `xvel` has no friction; the airborne step still applies `ACCEL(80)` when a direction is held.
- **UP**: nose up (tilt 0..6, +1 per tick); while lift > 0: lift -= 1 and, once tilt >= 4, `yvel = -64` (climb 4 px/tick).
- **DOWN / neutral**: `[P]`: neutral = lift decays by 1 per tick, keeps gliding; DOWN = nose down, full gravity for
  that tick (dive), and at tilt <= 1 lift is refilled by `|floor16(xvel)|` per tick up to 5x that value. `[B]` has the
  DOWN and neutral branches swapped. **`[INFERRED]`**: `[P]` marks this branch "unwitnessed"; needs play-testing
  against the DOS game (`[B!=P]` #3).
- Landing keeps the glider (`glide = 0`); an enemy hit removes it (10.1).

### 13.3 Screen shake

`shake` is set to 4, 7, 8 or 9 by heavy landings, traps, columns, bosses and some items. It decreases by 1 per tick
(step 8i). In step 18, when `shake > 1` on odd ticks: `shake += 1`, the view is offset vertically by `shake` px, and
**the hero is lifted 3 px** unless he is in the crouch state (5) `[P:pre2/recovered/camera_shake.py:apply_camera_shake @4C30]`
(`[B:level.c:level_shake_screen]` lifts 12 px - `[B!=P]` #2). On even ticks and at `shake == 1` the offset is 0.
Net: the shake lasts about twice its value in ticks; a standing hero is put into the air every other tick (which
arms `no_jump`, so he cannot jump) unless he crouches.

### 13.4 Feast (invincibility)

`feast = 660` ticks (27.2 s): touching an enemy kills it instead of hurting `[B:level.c:level_update_player_bonuses,
level_update_player_collision]`. No change to movement.

### 13.5 Not present

Water / swimming, speed boosts, vehicles other than the glider, variable gravity zones: none in either source.

---

## 14. Source differences and open items

### 14.1 `[B!=P]` register (implement the first-named behaviour)

| # | Topic | `[P]` (original code) - **implement** | `[B]` (rewrite) | Impact |
|---|---|---|---|---|
| 1 | Jump handler horizontal test | `xvel` compared unsigned: negative speeds always brake (6.1) | signed: leftward speed clamped to -48 | jump-left 5 px/tick vs 3 px/tick; 110 px vs 84 px jump |
| 2 | Shake nudge | hero y -= 3 | y -= 12 | feel of earthquakes |
| 3 | Glider DOWN / neutral | neutral glides, DOWN dives and refills lift | swapped | glider control - **verify by play-test** |
| 4 | Crouch charge | +2 per tick | +4 per tick (crawl: +2 in both) | time to full charge 48 vs 16 ticks |
| 5 | Skid animation | facing sign == velocity sign (both directions) | only facing left | cosmetic |
| 6 | Look-around trigger | LOOK key or LEFT+RIGHT | LEFT+RIGHT only | controls |
| 7 | Stomp flag | cleared before each overlap test | never cleared | after the first stomp `[B]` treats side hits as bounces |
| 8 | Wind script | advances through script entries | stays on the first entry | blizzard strength over time |
| 9 | Thrown weapon spawn point | relative to the club box | relative to the hero | a few px |
| 10 | Idle fidget clock | 18.2 Hz counter | 72.8 Hz counter | cosmetic timing |
| 11 | Tick rate | 3 timer ticks (24.275 Hz); its runner uses 23.33 Hz | 30.3 Hz | everything (section 1) |
| 12 | Ceiling block runs when | `yvel <= 0` (rising or grounded) | `yvel < 0` (rising only) | deadly ceilings kill a standing hero; a hero inside a wall is slid out while standing |
| 13 | Dust puff on the last tick of a low strike | only when `tick_counter & 3 == 0` (same gate as the skid dust) | only when `tick_counter & 3 != 0` | cosmetic |
| 14 | Vertical camera speed curve | two curves; the fast second one while non-opaque tiles are visible (12.2) | first (slow) curve only | how quickly the view catches up vertically on screens with a visible backdrop |

### 14.2 Corrections to `GAMEPLAY.md`

- Tick rate: 24.275 Hz, not 23.33 (section 1).
- "While jump is held air speed is capped at 3 px/tick": the cap of 48 v16 is real but the airborne step re-adds 16
  every tick, so the travel is 4 px/tick right and 5 px/tick left (5.4).

### 14.3 `[INFERRED]` list

1. **Tick rate on real hardware** (24.275 Hz is the governor's nominal rate; not measured by us on DOSBox or a PC).
2. That the retrace wait does not lengthen the frame beyond 3 timer ticks.
3. Original key bindings (cursor keys, Space/Enter, keypad 5).
4. Glider DOWN / neutral behaviour and lift refill (13.2).
5. SIDE values other than 0, 1, 2 and FLOOR/ceiling handler indices never used by the original levels.
6. Club box extents as targets for *our* sprites (they are the original frame sizes; ours must be re-authored).
7. Fall heights quoted for hard landing / shake (4 tiles / 11 tiles) and all `[SIM]` trajectories: derived by
   simulating the rules (`reference_sim.py`), not measured in the original.
8. "22 ticks = 1 designer second".
9. Exact list of what reappears after a respawn (taken from `[B]`'s skip list plus `[P]`'s description; not play-tested).
10. Which behaviour the original shows when `[B]` and `[P]` disagree was decided by trust in `[P]`'s verification, not
    by our own observation of the DOS game (all rows of 14.1).
11. Exactly when the original switches between the two vertical camera curves of 12.2: the selecting flag is
    renderer state that is only refreshed on tile-grid redraws, and only `[P]` has the second curve at all.

---

## 15. Godot implementation notes

### 15.1 Fixed-tick strategy

1. **One simulation tick = one original tick.** Keep a project constant `TICK_HZ = 24.275` (`TICK_DT = 1 / TICK_HZ`).
   Do not use `Engine.physics_ticks_per_second` for it: it is an integer `[GD]` and would tie the game to Godot's
   physics servers, which we do not need.
2. Drive the simulation from **one** node (autoload `Sim` or the level root) in `_process(delta)` with an accumulator:
   add `delta`; while the accumulator is at least `TICK_DT`, run one tick and subtract. Clamp to 4 catch-up ticks per
   rendered frame and drop the rest (prevents a spiral after a hitch; on mobile, pause the accumulator when the app
   loses focus).
3. **All gameplay state is integer**: positions in logical px, velocities in v16, timers in ticks. Integrate with
   `pos += v >> 4`. GDScript's `>>` on a negative `int` **variable** floors at run time (`-68 >> 4 == -5`,
   `-1 >> 4 == -1`, `-16 >> 3 == -2`) `[GD]`; wrap it in a `floor16()` helper with a unit test so a future engine
   change cannot silently alter movement. Never use `/ 16` or `int(v / 16.0)` (both give -4 for -68: they truncate
   towards zero and change the feel); `floori(v / 16.0)` is an acceptable equivalent.
   **Trap `[GD]`:** a shift whose operand is a negative *constant expression* (`(-16) >> 1`, `const X = -96 >> 4`) is
   rejected by the 4.7.2 parser ("Invalid operands for bit shifting. Only positive operands are supported"), so
   always shift through the helper / a variable, never a literal. Also `-5 % 16 == -5` in GDScript: write tile snaps
   as `y & ~15` or with `posmod()`, never with `%`.
4. The "unsigned" test of 6.1 is `(xvel & 0xFFFF) < 48`, equivalent to `xvel >= 0 and xvel < 48`.
5. Run the systems in the order of section 3. The hero update must be: handler -> integrate x -> integrate y -> tile
   collision (with the airborne `ACCEL` + gravity inside it) -> timers. Reordering changes jump height and air speed.
6. **Render interpolation**: every simulated object keeps `prev_pos` and `pos`; visual nodes are placed at
   `prev_pos.lerp(pos, accumulator / TICK_DT)` every rendered frame, the camera likewise. Skip interpolation on
   teleports (respawn, gates). This gives smooth motion at 60/120 Hz while the logic stays at 24.275 Hz. Animation
   frames advance per tick, not per rendered frame.
7. Determinism: no `randf`/float time inside the tick; one seeded integer RNG. This allows input-recording tests that
   replay the trajectories of section 6.4 exactly (acceptance test: standing full-hold jump peaks at 60 px on tick 10
   and lands on tick 22; running right, released, slides 12 px, left 17 px).

### 15.2 Do not use CharacterBody2D for the hero

The original collision is a set of point probes with per-face, one-way semantics (11.2). `move_and_slide`, tile
physics layers and one-way collision margins cannot reproduce it (corner behaviour, pass-through floors, 9 px wall
probe, no upper-body walls). Implement 11.2 literally against a logical grid:

- store FLOOR / SIDE / FLAGS / HEIGHT as four custom data layers of the TileSet (or a per-tileset resource), read via
  `TileMapLayer.get_cell_tile_data()`; cache them into a `PackedByteArray` per level for speed;
- enemies, items and platforms use the box test of 2.2 (plain integer rectangles), not Area2D callbacks, so results do
  not depend on physics-server timing;
- Area2D/physics bodies may still be used for purely cosmetic things.

### 15.3 Resolution independence

- Simulate in logical px (1 unit = 1 original pixel). Art may be authored at an integer multiple `ART_SCALE` (2x, 4x);
  multiply only when positioning visuals.
- Base viewport: 320 x 180 logical px at 16:9 (20 x 11.25 tiles; the original shows 20 x 11) with the HUD overlaid
  instead of a 24 px strip; stretch mode `canvas_items`, aspect `expand`, so wider phones simply see more columns.
- All camera thresholds of section 12 are expressed relative to the visible tile counts: right trigger = last 4
  columns, stop at column 5; left trigger = first 5 columns, stop at `columns - 5`; vertical rows scale by
  `visible_rows / 11`.
- No platform-specific code: input through InputMap actions only.

### 15.4 Input

- Actions: `move_left`, `move_right`, `jump` (also bound to up), `crouch`, `attack`, `look`. Keyboard, gamepad
  (d-pad + left stick with a 0.5 dead zone, converted to the digital flags) and touch (virtual d-pad + two buttons)
  all feed the same six flags.
- Sample the flags once per tick. Because a tick is 41 ms, **latch** presses: a button pressed and released between
  two ticks must still count as held for one tick (set the flag on the press event, clear it after the tick if the
  button is no longer down). Without this, short taps on 120 Hz devices get lost.
- Keep the original level-triggered semantics (auto-repeat jump and strike). Do not add jump buffering or coyote
  time in the authentic profile; the original has a 6-tick *lock-out* instead (6.4).

### 15.5 Asymmetries: keep or mirror?

`floor16` and the -96 floor make left and right differ slightly (slide 17 vs 12 px, held jump 5 vs 4 px/tick, hurt
knock-back 23 px to the left vs 31 px to the right). For "feels identical" keep them: level design distances can be
validated in the same simulation. Expose one debug switch `symmetric_motion` (apply the rules to `abs(xvel)` and restore the sign) so QA
can compare; do not ship both.

### 15.6 Camera

Implement 12.1-12.5 exactly on tile cells, then interpolate the rendered camera between ticks (15.1 #6): the
16 px/tick page becomes a fast smooth pan instead of the choppy DOS scroll, with identical framing and timing.
Offer the smooth follow of 12.6 as an accessibility option only; it changes how much the player sees ahead.
Round the final camera position to whole screen pixels to avoid shimmer.

### 15.7 Constants

Keep every number of Appendix A in one `physics_constants.gd` (v16 / ticks, never px/s) so tuning and the
`TICK_HZ` decision stay in one place.

---

## Appendix A - constant sheet

| Constant | Value | Unit | Converted | Section |
|---|---|---|---|---|
| TICK_HZ | 24.275 | 1/s | 41.194 ms | 1 |
| Tile | 16 | px | | 2 |
| Playfield | 320 x 176 | px | 20 x 11 tiles | 2 |
| X bounds | 8 .. 4087 | px | | 2 |
| ACCEL step | 16 >> ice | v16/tick | 589.3 px/s^2 | 5.1 |
| FRICTION step | 12 >> ice | v16/tick | 442.0 px/s^2 | 5.1 |
| Walk cap | 80 | v16 | 121.4 px/s | 5.1 |
| Crawl cap | 32 | v16 | 48.6 px/s | 5.1 |
| Jump-held cap | 48 | v16 | 72.8 px/s | 6.1 |
| Leftward floor | -96 | v16 | -145.7 px/s | 5.1 |
| Jump impulses | -65, -51, -35, -20, -10, -5, -2, -1, 0 | v16, ticks 1-9 | sum -189 | 6.1 |
| Gravity | 16 | v16/tick | 589.3 px/s^2 | 6.2 |
| Terminal fall | 192 | v16 | 291.3 px/s | 6.2 |
| Glide gravity / cap | 4 / 24 | v16 | 147.3 px/s^2 / effectively 1 px/tick = 24.3 px/s (`floor16(24) = 1`) | 13.2 |
| no_jump after falling | 6 | ticks | 0.247 s | 6.4 |
| Soft / hard landing thresholds | fall_ticks 4 / 10 / 20; drop 32 px; yvel 80 / 160 | | | 6.5 |
| Hard-landing hop | -32 | v16 | | 6.5 |
| Wall probe | 9 | px ahead | | 11.2 |
| Head probe | row - 2 | tiles | 32 px clearance | 11.2 |
| Corner slip | 2 | px/tick | 48.6 px/s | 11.2 |
| Slope gradient | 1 / 3 | px/px | | 11.1 |
| Strike length | 7 / 9 / 9 | ticks | 0.29 / 0.37 s | 8.1 |
| Strike hop | -32 / 0 / -48 | v16 | | 8.1 |
| swing_lock | 2 / 6 / 6 / 12 | ticks | | 8.1 |
| Weapon power | 25 / 30 / 20 / 30 (x4 charged) | | | 8.1 |
| Thrown weapon | 208; -64 then +32/tick; -32 then -16/tick | v16 | 315.6 px/s | 8.4 |
| Charge | +2 per crouch tick while <= 48; -1 per tick; saturates at 48/49 | | lasts 48-49 ticks = 2.0 s | 8.5 |
| Enemy bounce | -64 / -224 (UP held) | v16 | rise 10 / 105 px | 9 |
| Club pogo | -80 | v16 | rise 15 px | 9 |
| Stomp speed rule | yvel >= 128 | v16 | 8 px/tick | 2.2 |
| Hurt | yvel -128; xvel = -4 * xvel | v16 | rise 36 px | 10.1 |
| hit_timer | 44 (stun while >= 22): 22 stunned ticks, 43 immune ticks, next hit possible 44 ticks later | ticks | 1.81 s (0.91 s) | 10.1 |
| Energy / lives | 3 (dies on the 4th hit) / 2 spare | | | 10.2 |
| Death animation | 60 | ticks | 2.47 s | 10.4 |
| drop_timer | 4 | ticks | | 7 |
| Camera H | trigger col >= 16 / <= 4; stop col 5 / 15; 16 px/tick | | 388 px/s | 12.1 |
| Camera V | target rows 3, 8, 9, 8 (7, 6); 1..16 px/tick; two speed curves (opaque screens / screens with visible backdrop) | | 24..388 px/s | 12.2 |
| Shake nudge | 3 | px every 2nd tick | | 13.3 |
| Feast | 660 | ticks | 27.2 s | 13.4 |
| Dropper platform | +8 v16/tick to 192; rest 22 ticks; return 8 px/tick | | | 11.4 |

## Appendix B - reference trajectories `[SIM]`

Use these as automated acceptance tests of the Godot implementation (flat floor, no wind, ice 0).

The machine-readable version is **`docs/spec/PHYSICS_REFERENCE.json`**, generated by
**`docs/spec/reference_sim.py`** (our own integer simulation of sections 4-11; run it with the project's Python to
regenerate the file, it self-checks against the table below). The JSON also contains per-tick arrays, the strike
timelines, the ledge-drop table, the horizontal camera page and five *golden traces* (scripted inputs with the full
hero state after every tick). Unit tests should load the JSON instead of copying numbers by hand.

| Test | Expected |
|---|---|
| Walk right from rest, x after ticks 1..6 | 1, 3, 6, 10, 15, 20 |
| Walk left from rest | -1, -3, -6, -10, -15, -20 |
| Release at xvel +80, x after ticks 1..7 | 4, 7, 9, 11, 12, 12, 12 |
| Release at xvel -80 | -5, -9, -12, -14, -16, -17, -17 |
| Reverse from +80 (hold left), x after ticks 1..10 | 4, 7, 9, 10, 10, 9, 7, 4, 0, -5 |
| Standing jump, UP held: height after ticks 1..22 | 5, 12, 20, 28, 36, 43, 49, 54, 58, 60, 60, 59, 57, 54, 50, 45, 39, 32, 24, 15, 5, 0 |
| Same, earliest next take-off | tick 28 |
| UP held k ticks: apex | k=1: 15, 2: 33, 3: 48, 4: 56, 5-9: 64, 10: 61, >=11: 60 |
| Running jump right, UP + RIGHT held: x at landing (tick 22) | +88 |
| Running jump left, UP + LEFT held | -110 |
| Running jump, UP released after 9 ticks, direction held: landing | +111 at tick 24 / -120 at tick 24 |
| Running jump right, UP released after k = 1..11 ticks: x at landing | 54, 83, 102, 111, 115, 114, 113, 112, 111, 105, 99 |
| Running jump left, UP released after k = 1..11 ticks: x at landing | -55, -85, -105, -115, -120, -120, -120, -120, -120, -115, -110 |
| Standing-start jump, UP + direction held: x at landing (tick 22) | +81 / -82 |
| UP held k ticks: landing tick | k=1: 11, 2: 17, 3: 21, 4: 23, 5-9: 24, 10: 23, >=11: 22 |
| Tap jump (k = 1): height after ticks 1..11 | 5, 9, 12, 14, 15, 15, 14, 12, 9, 5, 0 |
| Walk off a ledge: fall per tick, starting with the tick the floor is lost | 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 12, ... |
| Walk off a ledge onto a floor 1..12 tiles lower: touchdown tick | 7, 9, 11, 12, 14, 15, 16, 18, 19, 20, 22, 23 (hard from 4 tiles, shake from 11) |
| Hard-landing hop | +2, +1, 0, -1, -2 px on the five ticks after touchdown (rise 3 px), soft touchdown on the 5th |
| Impulse rise heights | -32: 3 px; -48: 6; -64: 10; -80: 15; -96: 21; -128: 36; -144: 45; -160: 55; -224: 105 |
| Hurt while moving right / left at full speed, nothing held: x per tick | -6, -5, -4, -3, -2, -2, -1 (total -23) / +19, +4, +3, +2, +2, +1 (total +31); lands on the 17th tick |
| Forward strike, FIRE held from tick 1: club-box frame per tick | wind-up, wind-up, overhead, overhead, front, front, front, none (tick 8), then repeats from tick 9 |
| Forward strike hop: height after ticks 7..11 | 2, 3, 3, 2, 0 |
| Crouch k ticks: `charge` after the tick | k for k <= 49, then 48, 49, 48, ... |
| Mid-air (falling), xvel 0, direction held, UP released: xvel after ticks 1..3 | 32, 64, 80 |
| Mid-air (falling), xvel 0, direction + UP held: xvel after ticks 1..5 | 16, 20, 24, 28, 32 |
| Walk right into a wall whose left edge is at x = W | feet stop at x = W - 10 (`xvel = 0`); facing left against a wall whose right edge is at W: x = W + 9 |
| Camera, hero walking right from screen column 10 | page decided on tick 18 (column 16), camera +1 column on ticks 19-34 (16 moves), idle from tick 35 with the hero in column 5 |

---

## Verification log

Adversarial re-verification of this document (2026-10-04). Every numeric claim was re-derived without using the
citations above: by re-reading the two reference sources (`.tools/ref/blues/p2/*.c`, commit `d4b94bb`;
`.tools/ref/pre2_port`, commit `b5000dc`), by comparing their embedded data tables byte for byte with a script, by
an independent integer simulation (`docs/spec/reference_sim.py`, which also generates
`docs/spec/PHYSICS_REFERENCE.json`), and by running small scripts on the project's Godot 4.7.2 binary.

Status values: **CONFIRMED** = found again in the source(s) named, or reproduced by the simulation;
**CORRECTED** (old -> new) = the text above was changed; **UNVERIFIABLE** = cannot be decided from the material we
are allowed to use (we have neither the original executable nor a running copy of the DOS game).

Data tables that are byte-identical in `[B]` and `[P]` (so they are not one author's transcription error): the nine
jump impulses, the 24-entry state table, all nine hero animation scripts (including the 7 / 9 / 9-tick strike
scripts and their end marks), the club / hammer / axe frame-offset table with the thrown-weapon velocities, the four
weapon records (lock, power, flags), the hero sprite sizes and offsets, and the first vertical camera curve.

### Timebase

| # | Claim | Status |
|---|---|---|
| 1 | Timer reload 0x4000 -> 72.826 Hz | CONFIRMED (`[B]` game.c timer ratio; `[P]` run_status.md) |
| 2 | Frame governor waits until 3 timer ticks have passed | CONFIRMED as a quoted disassembly in `[P]`'s notes (loop "while abs(counter - saved) < 3"); UNVERIFIABLE against the executable itself |
| 3 | `TICK_HZ` = 1193182 / 49152 = 24.2753 Hz, 41.194 ms | arithmetic CONFIRMED; the rate on real hardware is UNVERIFIABLE (`[P]`'s own notes say 25, 23, 21.8 and 23.33 Hz in different places) |
| 4 | "slow machines ... dropped to 4 timer ticks (18.2 Hz)" | CORRECTED: removed -> "ran slower, exact rate not derivable" (the loop does not quantise to 4 ticks) |
| 5 | `[B]` runs at 30.3 Hz | CONFIRMED (integer 1000 / 30 = 33 ms sleep) |
| 6 | Conversion factors of 1.3 and all px/s figures | CONFIRMED, except: peak rise speed "about 162 px/s" -> **194 px/s** (8 px/tick), glide cap "36.4 px/s" -> **24.3 px/s effective** (CORRECTED) |

### Horizontal movement

| # | Claim | Status |
|---|---|---|
| 7 | Acceleration 16 >> ice, braking 12 >> ice, caps 80 / 32 / 48, leftward floor -96 | CONFIRMED in both sources |
| 8 | 5 ticks and 15 px to top speed; 5 px/tick = 121.4 px/s | CONFIRMED (`[SIM]`) |
| 9 | Release: 7 ticks, 12 px right / 17 px left; reverse: 5 + 5 ticks, 10 px overshoot | CONFIRMED (`[SIM]`) |
| 10 | Ice table (10 / 14, 20 / 27, 40 / 80 ticks) | CONFIRMED (`[SIM]`) |
| 11 | Air: 5 px/tick with a direction, UP held 4 right / 5 left | CONFIRMED for the rules as written (`[SIM]`); that the original compares unsigned (5 px/tick left, not 3) rests on `[P]` only: UNVERIFIABLE |
| 12 | (new) UP held while *falling* reduces air acceleration to +4 v16 per tick | added (5.4) |
| 13 | Crawl "same side effects as crouch" | CORRECTED: the shake nudge still applies while crawling, and the entry slide is exposed to wind (section 7) |

### Jump, gravity, falling

| # | Claim | Status |
|---|---|---|
| 14 | Impulses -65, -51, -35, -20, -10, -5, -2, -1, 0 over 9 ticks | CONFIRMED in both sources |
| 15 | Gravity 16 per tick, terminal 192, doubled while UP is held from tick 10 | CONFIRMED in both sources |
| 16 | Standing jump table: apex 60 px on ticks 10-11, lands on tick 22 (21 airborne ticks) | CONFIRMED (`[SIM]`, identical per-tick heights and velocities) |
| 17 | Variable height: 15 / 33 / 48 / 56 / 64 (k = 5..9) / 61 / 60 px; airborne 10 / 16 / 20 / 22 / 23 / 22 / 21 | CONFIRMED (`[SIM]`) |
| 18 | Running jump, UP held: 88 px right, 110 px left; standing start 81 / 82 px | CONFIRMED (`[SIM]`) |
| 19 | "UP released after 5-9 ticks: 111 px right" | CORRECTED: 111 px is k = 9 only -> **115, 114, 113, 112, 111 px for k = 5..9**; left stays 120 px |
| 20 | No coyote time; 6 grounded lock-out ticks; a jump every 27 ticks | CONFIRMED in both sources and by `[SIM]`; added: a held direction brakes during the lock-out |
| 21 | Free fall 0, 1, ..., 12 px per tick; terminal after 12 ticks / 78 px | CONFIRMED (`[SIM]`) |
| 22 | Landing thresholds (fall_ticks 4 / 10 / 20, drop 32 px, yvel 80 / 160, hop -32) | CONFIRMED in both sources |
| 23 | Hard landing after "about 66 px", shake after "about 174 px" of fall | CORRECTED -> **more than 55 px (floors 4 tiles or more below)** and **more than 162 px (11 tiles or more)**; table added in 6.5 |
| 24 | Hard-landing hop "about 6 ticks in the air" | CORRECTED -> 3 px, **4 ticks** airborne, down on the 5th tick |
| 25 | Impulse rise heights 3 / 10 / 15 / 21 / 36 / 45 / 55 / 105 px | CONFIRMED (`[SIM]`); -48 -> 6 px added |

### Club attack

| # | Claim | Status |
|---|---|---|
| 26 | Strike length 7 / 9 / 9 ticks; forward = start-up 4, active 3, recovery 1 | CONFIRMED in both sources and by `[SIM]`; exact tick table added in 8.1 |
| 27 | Weapon power 25 / 30 / 20 / 30, swing_lock 2 / 6 / 6 / 12, repeat period 8 / 12 / 12 / 18 | CONFIRMED in both sources and by `[SIM]`; high / low strike period with the club is 10 ticks (added) |
| 28 | Club and hammer box extents | CONFIRMED (recomputed from the frame tables); box origins added in 8.2 |
| 29 | Strike hop "leaves the ground for about 5 ticks" | CORRECTED -> forward: 3 px, 4 ticks (ticks 7-10); low: 6 px, 6 ticks (ticks 9-14); added: the last-tick box triggers the pogo |
| 30 | Charge "saturating near 50", "lasts about 50 ticks" | CORRECTED -> saturates at 48 / 49, lasts 48-49 ticks |
| 31 | "even one crouched tick gives a charged strike" | CORRECTED (wrong): the multiplier is evaluated on every strike tick while `charge` runs down; a charged *front* box needs 5 crouched ticks (all three: 7; high / low strike: 7 to 9) |
| 32 | Pogo -80; thrown weapons 208 / (-64, +32) / (-32, -16), 4 in flight | CONFIRMED in both sources |
| 33 | Club box extents as targets for our own sprites | UNVERIFIABLE by nature (design guidance, `[INFERRED]`) |

### Damage, bounce, death

| # | Claim | Status |
|---|---|---|
| 34 | Hurt: `yvel = -128`, `xvel = -4 * xvel`, `hit_timer = 44`, stun while >= 22 | CONFIRMED in both sources |
| 35 | "44 ticks invulnerable (22 stunned)" | CONFIRMED with a precision added in 10.1: 22 stunned ticks, contact test skipped on 43 ticks, next hit possible 44 ticks after the previous one (`[SIM]`) |
| 36 | Knock-back 23 px left / 31 px right, back on the ground on the 17th tick, rise 36 px | CONFIRMED (`[SIM]`) |
| 37 | Energy 3, dies on the 4th hit; 2 spare lives | CONFIRMED in both sources |
| 38 | Enemy bounce -64 / -224 with UP, stomp rule (`yvel >= 128` or top half) | CONFIRMED in both sources |
| 39 | Death animation 60 ticks, +/-5 px/tick sideways, 14 px/tick up decreasing to 16 down, 105 px rise | CONFIRMED in both sources (`[B]` level.c death animation; `[P]` pre2/native/loop.py death bounce: 60 frames, start value 15, +/-5) |

### Collision

| # | Claim | Status |
|---|---|---|
| 40 | Feet point, wall probe 9 px ahead one row above the feet row, head probe two rows up, body probes deadly-only, floors one-way | CONFIRMED in both sources |
| 41 | Order: handler -> x -> y -> tile collision (airborne accel + gravity inside) -> timers | CONFIRMED in both sources |
| 42 | Ceiling block also runs when grounded (`yvel <= 0`) | CONFIRMED as `[P]`'s reading (`[B]`: rising only); which one the original does is UNVERIFIABLE |
| 43 | Stand box 32 x 35 with x_offset 16 | CORRECTED -> x_offset **15** (the other frame boxes CONFIRMED) |
| 44 | Overlap test (64 / 70 px gates, half width for body contacts) | CONFIRMED in both sources; tie rule and mirrored-offset note added |
| 45 | Tile property tables, slope profile 1 px per 3 px, hatch with drop_timer 4 | CONFIRMED in both sources |
| 46 | (new) rest positions against walls: 10 px from a wall on the right, 9 px from one on the left | added (Appendix B, `[SIM]`) |

### Camera

| # | Claim | Status |
|---|---|---|
| 47 | Horizontal paging: start at column >= 16 / <= 4, stop at column 5 / 15, 16 px/tick, idle while standing | CONFIRMED in both sources; a page = 16 camera moves (`[SIM]`) |
| 48 | Vertical target rows 3 / 8 / 9 / 8 (7 / 6), home-row rule, limits | CONFIRMED in both sources |
| 49 | Vertical speed curve (1..16 px/tick by distance) | CONFIRMED for the first curve (byte-identical in both sources). CORRECTED: the document knew only this curve -> a **second, faster curve** exists in `[P]` and is used whenever non-opaque tiles are visible (12.2, 14.1 #14); "no step outside 0..131" is `[B]`'s behaviour only. When exactly the original flips between the curves: UNVERIFIABLE |
| 50 | Look-around, screen locks, camera at spawn | CONFIRMED in the sources named |

### Other

| # | Claim | Status |
|---|---|---|
| 51 | State table of 4.3 including the LEFT / RIGHT asymmetry under UP + DOWN | CONFIRMED (byte-identical in both sources) |
| 52 | Order of operations in one tick (section 3) | CONFIRMED in both sources |
| 53 | Shake nudge 3 px (`[P]`) vs 12 px (`[B]`) | difference CONFIRMED; the original value is UNVERIFIABLE |
| 54 | Glider: "strikes are replaced by the crouch handler" | CORRECTED -> every state except walk, jump and hurt runs the crouch handler; the glider jump ignores `no_jump` (13.2). DOWN / neutral swap between the sources CONFIRMED; the original behaviour is UNVERIFIABLE |
| 55 | Feast 660 ticks, dropper platform numbers, wind rule, X bounds 8..4087 | CONFIRMED |
| 56 | Original key bindings | UNVERIFIABLE (consistent with the scancode offsets in `[P]`) |
| 57 | Register 14.1 rows 1-12 | each difference CONFIRMED to exist in the two sources; rows 13 and 14 added; which side matches the original is UNVERIFIABLE for all of them |
| 58 | GDScript `>>` floors negative values (`[GD]`) | CONFIRMED at run time on 4.7.2. CORRECTED: a negative *constant* operand is a parse error, and `%` is not a floor modulo (15.1 #3) |
| 59 | "22 ticks = 1 designer second" | UNVERIFIABLE (`[INFERRED]`, unchanged) |
| 60 | All `[SIM]` trajectories versus the DOS game | reproduced exactly by an independent implementation of the written rules; UNVERIFIABLE against the original (no play-test) |

# GAMEPLAY.md - complete gameplay / feature specification

Feature inventory of **Prehistorik 2** (Titus, 1993, DOS) that "Club & Grub" must reproduce, followed by the
adaptation plan for our original game.

This document describes *behaviour only*. No source code, level data, graphics or audio of the original game or of
any third-party project is copied here or may be copied into the project. Numbers are observed constants (game
mechanics), restated in our own words.

---

## 0. Sources, citation keys, conventions

| Key | Source |
|---|---|
| `[B:file:function]` | Engine rewrite `cyxx/blues`, directory `p2/` (https://github.com/cyxx/blues), local clones `.tools/ref/blues` and `.tools/ref/blues_gameplay`. No licence file in the repository: describe only, never copy. |
| `[P:path]` | ASM-verified source port `missingno7/pre2_port` (https://github.com/missingno7/pre2_port), local clone `.tools/ref/pre2_port`. Used for the parts `blues` does not implement (front end, codes, warp/tally logic, tick rate). Describe only. |
| `[MAN]` | Original manual text: http://lucasabandonware.free.fr/manuels/Prehistorik%202.txt |
| `[TD]` | Fan tech docs (level file format, enemy types): https://pre2.mine.nu/techdocs.htm |
| `[SEC]` | Fan site cheat page: https://pre2.mine.nu/secrets.htm |
| `[MAPS]` | Fan site map legend: https://pre2.mine.nu/maps.htm (text only; map images were NOT downloaded) |
| `[YT]` | 100% walkthrough description with level names: https://www.youtube.com/watch?v=crN1ueAfXwg |
| `[HG]` | https://www.hardcoregaming101.net/prehistorik-2/ |
| `[WP]` | https://en.wikipedia.org/wiki/Prehistorik_2 |
| `[TVT]` | https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/Prehistorik |
| `[CB]` | https://www.cheatbook.de/files/prehistorik2.htm |

`[INFERRED]` marks anything not directly confirmed by a source (deduction, or a source that is ambiguous).
The full list is repeated in section 13.

Conventions:

- **Level index** = 0-based internal number used by the engine (file `LEVEL1`..`LEVEL9`, `LEVELA`..`LEVELG` = index 0..15)
  `[B:level.c:load_level_data]`. **Level N** (1-based) = what players call it.
- **tick** = one game-logic frame. Per-tick numbers below are taken from the sources as-is.
  The original paces gameplay at 70 Hz / 3 = **23.33 ticks/s** `[P:scripts/play_native.py, TICK_HZ comment]`;
  `blues` runs the same logic at 30 ticks/s `[B:level.c:level_wait]`. The physics spec owns the conversion to
  seconds; this document only quotes per-tick values.
- **v16** = velocity in 1/16 pixel per tick (the engine's fixed-point unit) `[B:level.c:level_update_player]`.
- Screen: 320x200; playfield 320x176 (20x11 tiles of 16 px); status panel 24 px at the bottom
  `[B:game.h PANEL_H]`, `[P:pre2/recovered/hud.py]`.
- **Displayed score = internal score x 10** (the last digit is a fixed 0) `[B:level.c:level_draw_panel]`,
  `[P:pre2/recovered/hud.py:draw_hud]`. All point values below are *displayed* values.

---

## 1. Game structure

### 1.1 Stage list (play order)

16 level files exist: 10 main levels, 3 bonus stages, 2 linked sub-stages and 1 ending stage
`[B:level.c:load_level_data, next_level_tbl, level_update_player_collision]`, `[WP]` ("ten levels plus three bonus levels").
All maps are 256 tiles wide (usable width is a per-level value); heights differ `[TD]`.

| # (1-based) | Index / file | Name (walkthrough `[YT]` / code list `[CB]`) | Height (tiles) `[TD]` | Background set `[B:load_level_data]` | Music `[B:do_level]` | Goal / exit |
|---|---|---|---|---|---|---|
| 1 | 0 / LEVEL1 | Mountain Bridges / "Level 1" | 49 | 0 | MINES | traffic light |
| 2 | 1 / LEVEL2 | Mountain Caves / "Level 2" | 104 | 0 | MINES | traffic light. Hidden warp to bonus stage (index 12). Has drop-through hatches `[TD]` |
| 3a | 2 / LEVEL3 | Mountain Base / "Lvl. 3" | 49 | 0 | PRES | first boss (gorilla) `[TVT]`, `[TD]` ("level 3's ... bosses"), then lighter + traffic light -> continues in 3b. Hidden warp to bonus stage (index 11) |
| 3b | 13 / LEVELE | intermediate stage | 38 | 5 (unique) | MINES | traffic light -> tally for level 3 -> level 4. Hang-glider crossing `[INFERRED]` (video title "Intermediate level Hang-glider", https://www.youtube.com/watch?v=IpMSqD-bSiE) |
| 4 | 3 / LEVEL4 | Deep Jungle / "Jungle" | 45 | 1 | PRES | traffic light. Hidden warp to bonus stage (index 10) |
| 5 | 4 / LEVEL5 | Autumn Forest / "Tree Houses" | 128 | 1 | PRES | traffic light |
| 6 | 5 / LEVEL6 | The Tree Monster / "Tree Trunk" | 128 | 1 | MONSTER | auto-scrolling descent inside a hollow tree `[TVT]`, then a gate into the boss room: tree-stump boss |
| 7a | 6 / LEVEL7 | Snow Summit / "Snow level" | 128 | 2 | GLACE | traffic light -> continues in 7b |
| 7b | 15 / LEVELG | blizzard stage | 84 | 2 | GLACE | snowstorm with growing head wind `[B:load_level_data snow pattern 2]`; traffic light -> tally for level 7 -> level 8 |
| 8 | 7 / LEVEL8 | Underground Crystal Cave / "Ice Caves" | 86 | 3 | GLACE | traffic light. Last level available to Beginners |
| 9 | 8 / LEVEL9 | Mystery Castle / "Fortress" | 110 | 3 | MYSTERY | gorilla boss returns as penultimate boss `[TVT]`, `[TD]` ("level 9's bosses"). Expert only |
| 10 | 9 / LEVELA | Final Boss | 12 (single screen) | 0 | MONSTER | minotaur statue; collecting its trophy warps to the ending. Expert only |
| end | 14 / LEVELF | ending / credits stage | 173 | 0 | FINAL | playable epilogue; touching its lethal tiles shows THE END `[B:level.c:level_update_tile_type_2]`; described as "Final Boss + Credits" in `[YT]` |
| bonus | 10, 11, 12 / LEVELB, C, D | bonus stages ("Level Ate": candy and food land, giant roast in the background `[TVT]`) | 24, 51, 51 | 4 | KOOL | exit item returns to the main route |

Themes per `[TVT]` / `[HG]`: green fields and mountains -> caves -> jungle / autumn forest with tree houses ->
snow and ice ("the second-to-last setting") -> gothic castle with demon statues and spikes.

Route logic (verified against the original in `[P:pre2/native/level_state.py:native_level_end]`,
`[P:pre2/recovered/player_interaction.py:loop2_handler]`; partially in `[B:level.c:level_update_objects_anim]`):

- Normal exit (traffic light) of a main level: tally screen, then index + 1.
- Traffic light of index 2 leads to index 13 *without* a tally; the light in 13 gives the tally and leads to index 3.
  Same pairing for index 6 -> 15 -> tally -> index 7.
- "Warp item" (item id 311) in a main level with a bonus stage (index 1 -> 12, 2 -> 11, 3 -> 10): jumps straight
  into the bonus stage with a curtain transition, no tally, collected-item list carried over.
- Warp item inside a bonus stage: tally, then the level after the source level (so warping from 3a skips 3b).
- Warp item in index 9 (dropped by the minotaur): leads to the ending stage (index 14).
- Where the warp items are placed in the main levels and what they look like is `[INFERRED]` (level data not inspected).

### 1.2 Bosses (summary; details in section 6)

| Boss | Where | Source |
|---|---|---|
| Giant gorilla in a hooded jacket ("Kong") | end of level 3, again in level 9 | `[TVT]`, `[TD]`, `[B:bosses.c:level_update_boss_gorilla]` |
| Demonic tree stump with hands | bottom of level 6 | `[TVT]`, `[B:bosses.c:level_update_boss_tree]` |
| Minotaur statue fused into a castle wall (final) | level 10 | `[TVT]`, `[HG]`, `[B:bosses.c:level_update_boss_minotaur]` |

### 1.3 Difficulty modes

- Two modes, **BEGINNER** and **EXPERT**, chosen on the mode-select screen `[P:pre2/native/front_end.py:_native_menu_map]`, `[HG]`.
- Expert adds extra enemies: every enemy record has an "expert only" bit `[TD]`, `[B:level.c:level_update_objects_monsters]`.
- Beginner cannot enter level 9 or 10: instead a full-screen castle picture with the text "To enter you must be an
  expert eater!" is shown and the game returns to the menu `[TD]`, `[P:front_end.py:native_expert_eater]`, `[B:game.c:game_run]`.
- Each mode has its own set of level codes (section 1.4).

### 1.4 Level codes (passwords)

- One 4-character hexadecimal code per level and mode `[P:pre2/recovered/password.py]`, `[B:level.c:load_level_data_init_password_items]`.
- The code is **not** announced by the game: it is displayed inside the level as four digit sprites placed somewhere
  (often hidden) in the map; the digits are ordered left to right `[B:load_level_data_init_password_items]`, `[HG]`, `[TVT]`.
- Codes are derived from a machine fingerprint (BIOS checksum), so they differ between computers `[P:password.py]`, `[B:game.c:random_get_number3 comment]`;
  this explains the several different code lists on the web `[CB]`.
- Entry: title menu option 2 opens the "ENTER CODE" screen; a correct code selects both level and mode; a wrong code
  shows a short "wrong" pause; fire with no valid code returns to the menu `[P:front_end.py:_password_step, native_menu_flow]`.
- Built-in cheat: entering `DEAD`, `C0DE`, `F00D` and then `00NN` jumps to level NN (add hexadecimal 0A for Expert) `[SEC]`, `[P:password.py:is_cheat_sequence]`.

### 1.5 Lives, continues, game over, ending

- Start with 3 lives = the current one + 2 spare (the counter shows 2) `[MAN]`, `[B:game.c:game_run]`.
- No continues. After the last life: game-over scene, then back to the title menu with score 0 and level 1
  `[B:level.c:level_update_objects_anim]`, `[P:front_end.py:native_menu_flow]`. Level codes are the only way to resume.
- Ending: defeat the minotaur, grab a trophy, play through the ending stage, "THE END" picture, then (hidden extra)
  photographs of the development team `[B:game.c:do_theend_screen]`, `[WP]`, `[TD]` (LEVELH/LEVELI photo files).

### 1.6 Easter eggs (optional for us)

- If the system clock is 1996 or later the game opens with: "YEAAA... MY GAME IS STILL WORKING IN <year>. PROGRAMMED IN
  1992 ON AT 286 12MHZ. ENJOY OLDIES" `[B:game.c:do_programmed_in_1992_screen]`, `[TVT]`.
- Hidden credits screen and photo screen on key combinations (Ctrl+Alt+W / Ctrl+Alt+E) `[B:game.c:input_check_ctrl_alt_w/e]`, `[WP]`.

---

## 2. HUD

Status panel: a 320x24 strip under the playfield; it never scrolls and is not affected by level fades
`[P:pre2/recovered/hud.py]`, `[B:level.c:level_draw_panel]`. Glyphs are 16x12 px. Left to right:

| Element | Position (x, y in 320x200) | Behaviour | Source |
|---|---|---|---|
| Lives | x 40, y 185 | one digit, shows min(lives, 9); real cap is 99 | `[P:hud.py:draw_hud]`, `[P:player_interaction.py num 0xAE]`, `[MAN]` |
| Score | x 72..184, y 185 | 6 digits + a fixed trailing 0 (7 characters) | `[P:hud.py]` (`blues` optionally shows 8) |
| Energy | x 200, 216, 232, y 185 | 3 heart slots: filled hearts then empty hearts | `[P:hud.py HUD_MAX_HEARTS]`, `[B:level_draw_panel]` |
| B-O-N-U-S letters | x 264, 272, 280, 288, 296 at y 182, 178, 184, 181, 179 (staggered) | each letter appears when collected; all five blink for 44 ticks when the set is completed | `[P:hud.py HUD_BONUS_DI]`, `[B:level_draw_panel, level_update_player_bonuses]` |

Not on the panel but on screen:

- **Score pop-ups**: a sprite showing the value rises 1 px per tick for 44 ticks at the pick-up or kill position `[B:level.c:level_add_object75_score, level_update_objects_bonus_scores]`.
- **Multiplier pop-up** above the hero when bouncing on an enemy (section 3.3) `[MAN]`, `[B:level_update_player_collision]`.
- **"1UP" pop-up** when a life is gained `[B:level_update_panel]`.
- **Boss energy bar**: up to 8 small pips in the lower-left corner of the playfield (5 px apart, about 6 px above the
  panel), only while a boss is active `[B:bosses.c:level_update_objects_boss_energy]`. Exact screen anchoring `[INFERRED]`.
- Bones are **not** shown on the HUD; the 6-bone fraction of a heart is invisible state `[B:level_update_player_collision]`.
- No timer, no weapon icon, no level name on the HUD (none drawn by `[B:level_draw_panel]` / `[P:hud.py]`).

---

## 3. Scoring

### 3.1 Value ladder

All scores come from one 17-step ladder `[B:staticres.c:score_tbl]` (x10 for display):

100, 200, 300, 500, 600, 700, 750, 800, 1 000, 2 000, 5 000, 8 000, 10 000, 20 000, 30 000, 60 000, 100 000.

### 3.2 Items

Each collectible sprite maps to one ladder step `[B:staticres.c:score_spr_lut]`:

| Item class | Sprite range | Values | Notes |
|---|---|---|---|
| Small food (fruit, dairy, junk food ...) | 128..180 | 100 - 500 (one exception: the hand-held game console, 8 000 `[TD]` sprite 156) | most common pick-up |
| Bigger food, toys, tools, playing cards `[HG]` | 181..219 | 600 - 1 000 mostly | |
| Treasures (diamonds, "video games" `[WP]`) | scattered in 181..219 | 2 000, 5 000, 8 000 | |
| Giant bonuses (fall from the sky) | 111..117 | 60 000, 20 000, 30 000, 10 000, 10 000, 20 000, 30 000 | reward of "big" hidden spots (section 4.4) |
| BONUS fridge | 110 | 100 000 | reward for the 5 letters `[MAN]`, `[HG]` |

Which exact picture has which value inside a class is `[INFERRED]` apart from the cases cited.

### 3.3 Enemies

- Each enemy record carries a score index 0..11 = 100 .. 8 000 points `[TD]`, `[B:level.c:level_monster_die]`.
- **Head-bounce multiplier**: every bounce on a living enemy raises a counter; every second bounce shows a number above
  the hero; when the enemy is finally killed its score is paid 1, 2, 3, 4, 6 or 8 times (after 0-1, 2-3, 4-5, 6-7, 8-9, 10+
  bounces; the counter stops at 11) `[B:level_update_player_collision, level_monster_die]`, `[MAN]`.
  Bouncing never hurts the enemy.
- **Hang-glider dive**: 1st dive on an enemy 1 000, 2nd 5 000, 3rd 10 000 and the enemy dies `[MAN]`, `[B:level_update_player_collision]`.
- Bosses give no direct score; they explode into bonus items (section 6).

### 3.4 Bonus mechanics

- **End-of-level double**: at the tally every bonus collected *since the last death* is paid a second time
  `[MAN]`, `[B:level.c:level_completed_bonuses_animation, level_clear_items_spr_num_tbl]`. Dying clears that list.
- **BONUS letters**: 100 000-point fridge (section 4.3).
- **Cutlery feast**: enemies become food and die on touch, paying their score (section 8.3).
- **Grenade**: every on-screen enemy becomes 16 bonus items (section 8.3).

### 3.5 Completion percentage

Shown on the tally as "LEVEL COMPLETED nn%" `[B:level.c:level_completed_bonuses_animation_draw_score]`, `[P:pre2/recovered/tally_panel.py]`.

- percentage = (hidden spots opened + map-placed bonus items collected) x 100 / (hidden spots in the level + map-placed
  bonus items in the level) `[P:tally_panel.py:compute_percent]`, `[P:pre2/native/level_load.py:_count_decor]`.
- Counted items are sprites 110..117 and 128..219 that were placed in the map (dropped items do not count)
  `[B:load_level_data]`, `[P:player_interaction.py:_count_and_score]`.
- Quirk: in levels that own a linked stage or bonus stage (index 1, 2, 3, 6) the totals are doubled, and halved again
  when the linked stage loads and adds its own totals `[P:level_load.py:native_level_load_dgroup, _count_decor]`.
  Effect: 100% needs both halves; without the bonus stage levels 2 and 4 top out near 50%. Entering bonus stage
  index 10 resets the counters (off-by-one in the original). We will not reproduce this quirk (section 12).

### 3.6 Extra lives

- One extra life per 250 000 points, maximum 99 lives `[MAN]`, `[B:level.c:level_update_panel]`, `[P:player_interaction.py num 0xAE]`.
- 1UP item ("shrunken head") `[MAN]`.

### 3.7 End-of-level tally sequence

`[B:level.c:level_completed_bonuses_animation]`, `[P:tally_panel.py]`, `[P:pre2/docs scene_island.md]` (iris):

1. Circular iris closes on the hero; "level complete" jingle (BRAVO) starts; black screen with "SCORE nnnnnnn" and
   "LEVEL COMPLETED nn%".
2. The hero walks to the lower left. A large companion character with an animated face slides in from the right to the
   middle of the screen (identity `[INFERRED]`; the same figure cries on the game-over screen).
3. If anything was collected since the last death: the hero skids to a stop and every collected item drops from the top
   centre, one every 8 ticks, into the companion; each landing plays the pick-up sound and adds the item's value again.
4. Hero walks off to the right, companion leaves to the left; world map; next level.

The hang-glider is taken away at the tally `[MAN]`. Weapon, BONUS letters and cutlery pieces carry over to the next level
`[P:level_state.py:native_level_end]`.

---

## 4. Collectibles

Item ids below are sprite numbers used by the sources; our game uses its own ids. Dispatch table:
`[B:level.c:level_update_player_collision]`, cross-checked with `[P:pre2/recovered/player_interaction.py:loop2_handler]`.

### 4.1 Map-placed items

Up to 70 placed items per level `[B:resource.h MAX_LEVEL_ITEMS]`. Placed items bob up and down about 3 px
`[B:level.c:level_update_objects_items]`. At most 20 are active on screen at once.

| Item | Effect | Sound |
|---|---|---|
| Food / toys / treasures (128..219) | score (3.2); counted for % and tally | pick-up |
| Giant bonus (110..117) | score; counted | big pick-up |
| Letters B, O, N, U, S (92..96) | sets one letter bit (4.3) | pick-up |
| Fork, knife, spoon (three "utensil" ids) | all three -> feast mode (8.3) `[MAN]` | pick-up |
| Lighter (99) | turns every red traffic light in the level green `[MAN]` | pick-up |
| Heart (226) | +1 heart if below 3, otherwise stays in place | big pick-up |
| 1UP shrunken head (227) | +1 life (max 99) | big pick-up |
| Skull (220, 221) | hurt animation; ALL current energy is thrown out as bones (hearts x 6 + spare bones); hearts drop to 0 (not dead yet; next hit kills); screen shake `[MAN]`, `[YT]` | hurt |
| "Kill-all" (222) | every on-screen enemy dies normally (scores paid); strong shake | explosion |
| Grenade (223) | every on-screen enemy vanishes into 16 random bonus items `[MAN]` | explosion |
| Weapon pick-ups (4 ids) | switch weapon (8.1) | pick-up |
| Hang-glider (118..127) | carry the glider (8.4) | pick-up |
| Tap / shower (198) | scores like food and removes the flies circling the hero (7.9) | pick-up |
| Light-off / light-on triggers (234 / 233) | fade level palette to night / back to day (7.10) | hurt sound on "off" |
| Checkpoint light (281 off, 280 on) | section 7.6 | - |
| Traffic light (278 red, 279 green) | green = level exit | - |
| Warp / trophy (311) | bonus-stage warp or game end (1.1) | - |
| Code digits (283..298) | display only (1.4) | - |

### 4.2 Bones (energy fragments)

`[MAN]`, `[B:level_monster_die, level_update_player_collision (num <= 20), level_update_objects_bonuses]`:

- 1 heart = 6 bones. Collecting the 6th bone restores one heart (if below 3) with a heart pop-up.
- An enemy that has just hurt the hero "holds" the stolen heart: killing that enemy releases 6 bones.
- Skull and boss hits also scatter bones (4.1, 6).
- Bones fly out in a fan, fall with gravity, bounce (half height each bounce), slow down, live 198 ticks, blink for the
  last 15, cannot be picked up during their first 10 ticks.

### 4.3 BONUS letters

- Five letter items exist across the levels; collected letters are kept between levels and reset only on a new game
  `[P:level_state.py:native_level_end]`, `[P:front_end.py:native_menu_flow]`.
- Completing the word: letters blink on the panel (44 ticks), the set is cleared, and a 100 000-point fridge drops from
  112 px above the hero `[B:level.c:level_update_player_bonuses]`, `[MAN]`, `[HG]`.
- `[TVT]` claims BONUS "warps you to a bonus stage"; that is not what the DOS code does (it is the warp item, 1.1).

### 4.4 Hidden spots (clubbing scenery or the ground)

Up to 80 per level `[B:resource.h MAX_LEVEL_BONUSES]`. Each is a tile cell that looks like ordinary scenery until hit by
the club or a thrown weapon (hit test: within 1 tile horizontally, 16 px vertically). Every hit shows a small star puff.
Three kinds, selected by one byte `[TD]`, `[B:level.c:level_handle_bonuses_found]`, `[P:pre2/recovered/combat_interaction.py:bonus_hit_handler]`:

| Kind | Behaviour |
|---|---|
| **Small-bonus spot** (N = 1..64) | each hit (at most one per 6 ticks) throws out one random bonus item (from the 128..222 range, so it can also be a skull or a kill-all) away from the hero; after N items the spot is used up |
| **Breakable block** (1..64 hits) | each hit sprays 4 debris bits (look depends on the level: stars, dirt, ice chips); the final hit sprays more and removes the block - this is how secret passages and shortcuts open |
| **Big-bonus spot** (1..128 hits) | hits only puff until the counter runs out, then one giant bonus (111..117, random) falls from 112 px above the spot |

- When a spot is used up, its tile changes to the "opened" look and **all hidden cells touching it (8-neighbourhood,
  flood fill) open with it**, each counting for the completion percentage `[P:combat_interaction.py:_flood_collect]`.
- Hitting something with the club while airborne gives the hero a small upward kick (v16 -80), so repeated mid-air
  hits "hover" `[B:level.c:level_update_objects_axe]`.
- Manual: "Do not hesitate to hit everything with your club ... You might even find a secret passage!" `[MAN]`.

### 4.5 Dropped items

Items thrown out by hidden spots, grenades and bosses use the same physics as bones (gravity, bounce, 198-tick life,
blink) `[B:level.c:level_add_object23_bonus, level_update_objects_bonuses]`. A giant bonus that is still falling fast
when it touches the hero bounces off his head once (random direction, sometimes with a screen shake) before it can be
collected `[B:level_update_player_collision (food branch)]`.

### 4.6 Secret rooms

Reached through **gates** (7.5) or behind **breakable blocks** (4.4); gates may lock the camera to a single screen
`[TD]`, `[B:level.c:level_update_gates]`. Bonus stages are the large-scale version (section 9).

---

## 5. Enemies

### 5.1 Common rules

`[B:monsters.c]`, `[B:level.c:level_update_objects_monsters, level_update_monster_pos, level_monster_die, level_collide_axe_monsters, level_update_player_collision]`, `[TD]`.

- At most **12 active enemies**; up to 150 enemy records per level.
- **Spawn**: a record activates when its anchor comes within about 2 tiles of the visible area and a slot is free.
- **Despawn**: when not drawn and farther than one screen horizontally (or screen + 124 px vertically) from the hero.
  Ordinary records can re-activate when the hero returns; records that had already launched (divers, jumpers) and killed
  one-shot types are gone for good. Zone spawners (types 0, 10, 11, 12) keep producing enemies with a per-record pause.
  Exact respawn rules per type are `[INFERRED]` (flag handling in `blues` is ambiguous).
- **Hit points**: one byte per record. A weapon hit subtracts the weapon power (8.1); the enemy dies when the result
  drops below zero. Survivors flash and are pushed back a quarter of their speed.
- **Death**: knocked away from the hero in an arc and falls off screen, score pop-up(s). If it had hurt the hero it
  bursts into 6 bones instead.
- **Contact damage**: 1 heart, hero thrown back (v16 -128 upward, horizontal speed reversed x4), hurt pose for 22 ticks,
  44 ticks of blinking invulnerability. With the hang-glider: lose the glider instead of the heart `[MAN]`.
  Below 0 hearts: lose a life.
- **Head bounce**: landing on an enemy from above never damages either side: the hero bounces (v16 -224 with jump held,
  -64 otherwise) and the multiplier counter rises (3.3). Enemies are therefore springboards ("Goomba Springboard" `[TVT]`).
- **Ground physics** (types that use it): gravity 16 v16 per tick (max 256), small landing bounce, turn around at
  walls; "climber" variants walk up walls instead of turning.
- **Projectiles**: ordinary enemies have **no projectile system** in the DOS engine; only bosses throw things
  `[B:monsters.c]` (whole file), `[B:bosses.c]`. (Acorn-throwing squirrels mentioned by `[TVT]` belong to other versions.)
- Expert-only flag per record (1.3).

### 5.2 Behaviour archetypes

Type numbers and species examples from `[TD]`; behaviour from `[B:monsters.c:monster_func1_typeN / monster_func2_typeN]`.
Speeds in px per tick unless stated; "P" = per-record parameter.

| Type | Archetype | Behaviour | Killed by | Original examples |
|---|---|---|---|---|
| 0 | **Sky dropper (zone spawner)** | while the hero is inside a trigger rectangle, enemies appear above the screen 192 px left/right of him (alternating), wait a pause, fall, land, then walk toward the side the hero was on at 2 px/tick with gravity and wall turns | weapon | - |
| 1 | Decoration | static, intangible | - | spider webs |
| 2 | **Yo-yo dangler** | lowers on a thread to depth P at speed P, climbs back, repeats; thread is drawn | weapon | spiders |
| 3 | **Ceiling dropper -> chaser** | hangs intangible; when the hero is within P tiles horizontally (after a pause) it descends on a thread at 2 px/tick to the floor, then runs at 3 px/tick toward the hero and climbs walls | weapon | "spawning spiders" |
| 4 | **Pendulum** | lowers by radius P, then swings like a pendulum | weapon | pendulum spiders |
| 5 | **Sentry diver, levels out** | faces the hero; when he enters a box (P x P tiles) it dives diagonally at speed P; once level with him (within 8 px) it continues almost horizontally | weapon | bees (levels 3 and 7) |
| 6 | **Clever flyer** | activates within P tiles; flies at 3 px/tick per axis through a loop of about 9 waypoints defined relative to the hero's position (from 64-80 px to his right and 40 px up, across 50-60 px above his head, to 32 px to his left) so it circles and swoops; flies 5 px higher while he is swinging | weapon | "clever flying enemy" |
| 7 | **Kamikaze diver** | activates within P tiles; dives diagonally at speed P and never returns | weapon | - |
| 8 | **Hopper** | within range (P x P tiles) and after a pause: jumps toward the hero with take-off speed (P horizontal, P vertical; height = v(v+1)/2 px), lands, pauses, repeats | weapon | dinos, leopards, small worms |
| 9 | **Patroller** | moves between a left and right limit, accelerating 3 v16 per tick up to P, with smooth turn-arounds; either flies (ignores walls and gravity) or follows the ground including slopes | weapon | penguins on slopes |
| 10 | **Burrower (zone spawner)** | while the hero is in a trigger rectangle (and after a pause) it rises out of valid floor at one of 8 offsets around him (-120..+120 px), intangible while rising, walks at speed P for about 120 ticks, sinks back, repeats | weapon while walking | tree-boss minions ("bugs" `[TVT]`) |
| 11 | **Arc leaper** | spawns from a fixed point (random height offset up to 63 px) after a pause; leaps toward the hero with horizontal speed P and upward speed P, then sinks with soft gravity (8 v16 per tick) capped at P - a glide | weapon | flying squirrels |
| 12 | **Edge rusher** | triggers when the hero is below its anchor and about one screen away; runs in from the screen edge at speed P along the ground; removed after 154 ticks off screen | weapon | fast penguins, cavemen |

Other species named by secondary sources, archetype assignment `[INFERRED]`: bears / polar bears, red snakes used as
stationary hazards, swordfish jumping out of icy water (likely type 8 or 11), giant snails, monkeys, flying dinosaurs
`[TVT]`, https://onlineclassicgame.com/game/prehistorik-2.

### 5.3 Feast mode interaction

During feast mode (8.3) every active enemy is drawn as a food item and dies on touch, paying its score
`[B:level.c:level_update_objects_monsters (monster_spr_tbl), level_update_player_collision]`.

---

## 6. Bosses

Common: boss music (MONSTER) starts when the energy bar appears; a hit by a boss costs **one bone** (1/6 heart, which
flies out and can be picked up again), throws the hero back and gives 44 ticks of invulnerability
`[B:bosses.c:level_update_objects_boss_hit_player, level_update_objects_boss_energy]`. A defeated boss bursts into
**64 random bonus items** (which can include skulls `[YT]`) plus, for gorilla and tree, the **lighter** that turns the
exit light green `[B:bosses.c]`.

### 6.1 Gorilla ("Kong") - levels 3 and 9

`[B:bosses.c:level_update_boss_gorilla, level_update_boss_gorilla_helper2, level_update_boss_gorilla_hit_player]`; level parameters `[TD]`.

- **Arena**: part of the normal scrolling level; the boss moves between a left and right limit stored in the level.
  Per-level parameters: limits, speed class 0..4, hit points, start position. Level 9 is the tougher set-up `[INFERRED]`.
- **Body**: five linked parts (legs, torso, head, two arms). Arms hurt on contact; the **head is the only weak point**;
  an arm in guard pose blocks thrown weapons.
- **Energy bar**: hit points / 8 pips (max 8). Each weapon hit removes the weapon's power; hits count at most once per
  22 ticks.
- **Safe trick**: landing on the head bounces the hero (higher with jump held) without damage to either side.
- **Behaviour** (state machine):
  1. *Asleep / idle* until the hero is within 250 px (active only within 400 px and 250 px vertically).
  2. *Watch*: stands and breathes for up to 110 ticks. Swinging the club nearby raises an "anger" counter; anger above 3
     triggers the jump routine, 10 or more the attack routine. Under 60 hit points it skips watching.
  3. *Jump routine*: about 44 ticks of chest-beating (rushes if the hero comes within 75 px), a very high vertical jump
     that shakes the screen on landing, then at tick 88 a leap aimed at the hero's position (short hop if he is close,
     long flat leap if far). Under 40 hit points and close range it goes into the ground pound instead.
  4. *Attack routine*: hops toward the hero when farther than 100 px; punches when closer; at 25..35 px switches to the
     ground pound; if calm (anger 0) it hops backwards to make room.
  5. *Ground pound*: about 66 ticks of hammering the floor with continuous screen shake.
  6. *Stagger*: a hit stronger than 20 power (anything except an uncharged thrown axe) knocks it back and interrupts it for 19 ticks.
  7. *Defeat*: leaps up, vanishes, 64 bonuses + lighter.
- A successful hit with the glider equipped drops the glider.
- Timer handling of the attack routine in `blues` looks incomplete; exact durations `[INFERRED]`.

### 6.2 Tree stump - level 6

`[B:bosses.c:level_update_boss_tree]`, `[B:level.c:level_update_gates]`, `[B:monsters.c:monster_func2_type10]`.

- **Arena**: reached through a gate at the bottom of the descent; entering stops the auto-scroll. The stump fills the
  right side; the hero fights from the left. Walking into the trunk pushes him back and costs a bone.
- **Hit points**: three stages of 10, 7 and 7 hits (any weapon, 1 per hit). Energy bar shows 4, 2, 0 pips.
  The vulnerable part changes per stage (face first, then the upper hand, then the fist) `[INFERRED]` which sprite is which.
  A hit makes the fist retract for 6 ticks.
- **Attacks**:
  - *Fist*: punches along the ground in bursts (the first burst is 8 cycles, later ones random length; 3 ticks
    extended / 1 retracted), then rests 64..184 ticks. Every punch shakes the screen and shoves the hero 2 px. Being caught by the moving fist: thrown back and
    lose 3 bones; being *on top of* it: launched upward unharmed. The resting fist is a platform / springboard used to
    reach the face.
  - *Leaves*: each punch drops a leaf from 150 px above the hero (random offset up to 124 px), falling 1..4 px per tick
    while swaying; a touch costs a bone. Up to 5 at once.
  - *Minions*: burrower enemies (type 10) keep emerging; every shake sends them back underground `[TVT]` ("sends bugs").
- **Defeat**: 64 bonuses + lighter; minions stop.

### 6.3 Minotaur statue - level 10 (final)

`[B:bosses.c:level_update_boss_minotaur and helpers]`, `[B:level.c:level_update_tilemap (level 9 special case)]`, `[TVT]`.

- **Arena**: one fixed screen (20x11 tiles), no scrolling. The statue (about 96x112 px) is part of the right-hand wall
  and is animated by swapping whole tile blocks between 5 poses.
- **Hit points**: 24; bar shows 6 pips (4 hits each).
- **Vulnerability**: only **thrown weapons** count - any projectile that reaches the head zone (upper area, left of
  x = 235, above y = 80) scores exactly 1 hit regardless of power. The club and hammer cannot hurt it, so the level must
  offer an axe `[INFERRED]`.
- **Pattern**: breathing idle loops, alternating with attack loops:
  - spits a **rock** from mouth height (about x 200, y 88) to the left with random speed; it bounces along the floor
    (bonus-item physics, lives 132 ticks);
  - drops a **chandelier** from the ceiling at a random x in the left part of the room (lives 66 ticks) `[TVT]`.
  - Every hit makes it roar (sound) and stay in the hurt pose; the 1st hit and every 4th hit after it trigger a rage
    sequence with one rock and two chandeliers in quick succession.
- **Damage to hero**: rock or chandelier costs a full heart and scatters 6+ bones (comment in
  `[B:level.c:level_update_player_collision]`; the id comparison in `blues` does not match the spawned ids, so the exact
  path is `[INFERRED]`).
- **Defeat**: statue switches to the broken pose; 4 trophies fly out; touching one starts the ending.

---

## 7. Interactive objects and terrain

### 7.1 Tile properties

Four property bytes per tile type `[TD]`, handled in `[B:level.c:level_update_tile0, level_update_tile1, level_update_tile2, level_update_tile_attr1_*]`:

| Property | Behaviour |
|---|---|
| Solid sides | walls |
| Solid top | floor; **one-way**: can be jumped through from below unless the tile also has "solid bottom" |
| Solid bottom | ceiling: stops upward motion and nudges the hero 2 px sideways around corners |
| Slopes | height of the left corner 0..15 plus direction; gradient about 1 px per 3 px; enemies with ground physics follow them |
| Soft surface | hero sinks a few pixels into the tile top (bone piles in stage 3b) |
| Slippery x1 / x2 / x3 | acceleration and braking are halved per step (ice); x3 unused in the original |
| Hatch | solid floor that the hero drops through while crouching (level 2) |
| Deadly from top / side / bottom | instant loss of a life (spikes) `[MAN]` |
| Step-on | tile switches to its "pressed" picture while the hero stands on it |
| Foreground | drawn in front of sprites (hero and enemies hidden behind foliage, trunks) |
| Animated | 3-frame loop, 4 ticks per frame (2 in a heavy snowstorm) |
| Fly source | walking through releases a fly (7.9) |

Falling out of the bottom of the map, leaving the screen by more than a screen, or (in the auto-scroll level) leaving
through the top = lose a life `[B:level.c:level_update_player_decor]`, `[TD]`.

### 7.2 Springs / trampolines

There is **no dedicated spring object** in the DOS engine (none in `[B:resource.h]` structures or `[TD]`). The same role
is played by: enemy heads (5.1), the gorilla's head, the tree boss's fist (6.2), and the landing rebound (a fall of
more than 10 ticks ends with a small hop and a dust puff; very long falls shake the screen)
`[B:level.c:level_update_tile_attr1_helper]`.

### 7.3 Platforms

Up to 16 sprite platforms per level `[TD]`, `[B:level.c:level_update_objects_decors]`, `[P:pre2/recovered/terrain_entities.py]`:

- **Moving platform**: one of 8 directions; speed ramps by 1 px/tick per tick to its maximum, travels a set time, slows,
  reverses (ping-pong). Either always moving, or moving only while the hero rides it (stops at the end of the cycle
  after he steps off).
- **Drop platform**: after the hero stands on it for a delay (or at once), it falls with acceleration (8 v16 per tick,
  max 12 px/tick) carrying him until it hits solid ground or leaves the map; waits 22 ticks after he steps off, then
  rises back at 8 px/tick. `[TVT]`: "they fall faster than you".
- Riding: land from above only; the hero inherits the platform's motion.
- No vanishing/blinking platforms exist in the DOS engine.

### 7.4 Rising columns ("earthquake pillars")

Up to 15 per level `[TD]` ("shifting tile blocks"), `[B:level.c:level_update_columns]`: when the hero reaches a trigger
position, a block of tiles (w x h) rises one tile every 4 ticks for a set distance while the screen shakes. Used to
raise walls, bridges or stairs. During any screen shake the hero is jolted upward every other tick unless he crouches
`[B:level.c:level_shake_screen]`, `[MAN]` ("resist earthquakes").

### 7.5 Gates (doors, caves, secret passages)

Up to 20 per level `[TD]`, `[B:level.c:level_update_gates]`: stand on the gate tile and press **Down**; curtain
transition; the hero appears at the destination and the camera jumps to a stored position; a per-gate flag locks
scrolling (single-screen room). Not usable while carrying the glider. Two-way travel is done with two gates.

### 7.6 Checkpoints and exits

- **Restart light**: touching it turns it green and stores the position; only the last one touched is active
  `[MAN]`, `[B:level_update_player_collision (num 228)]`.
- **Respawn**: death animation, curtain, restart at the active light (or level start) with 3 hearts. Collected items
  stay collected, opened hidden spots stay open, enemies reset, the glider is lost, the weapon is kept, the tally list
  is cleared `[B:level.c:level_update_objects_anim, level_reset]`, `[P:pre2/native/level_state.py:native_4f6c]`.
- **Traffic light**: touching a green one ends the level. A red one needs the **lighter**, which lies in the level or
  is dropped by the boss `[MAN]`, `[WP]`.

### 7.7 Lifts and switches

No switch objects exist. "Lifts" are moving platforms (7.3); step-on tiles (7.1) are purely visual.

### 7.8 Water, spikes, pits

- Spikes: deadly tiles (7.1). Bottomless pits: lose a life `[MAN]`.
- Water: no swimming; treated as a pit / deadly surface `[INFERRED]` (`[TVT]` mentions swordfish leaping from icy water
  and no water mechanics exist in `[B:level.c]`).

### 7.9 Weather and ambience

- **Snow / wind**: stage 7b runs a script that raises snow density in three phases; density also acts as a wind force
  pushing the hero left every tick (double while jumping), limited to a leftward speed of 6 px/tick. **Crouching and
  crawling are immune to wind** `[B:level.c:level_draw_snow, level_update_screen_x_velocity, level_update_player_anim_4/5]`, `[MAN]`.
- **Flies**: up to 20 single-pixel flies chase the hero after he walks through "dirty" tiles; cosmetic; the tap item
  clears them `[B:level.c:level_update_tile_type_0, level_draw_flies]`, `[P:pre2/recovered/fireflies.py]`.
- **Spider threads**: drawn as dotted lines `[B:monsters.c:monster_add_orb]`.

### 7.10 Darkness

Two invisible-effect items fade the whole level palette to a dark "night" palette and back
`[B:level.c:level_update_light_palette]`. Which levels use them is `[INFERRED]` (probably the caves).

### 7.11 Auto-scroll

Level 6 scrolls down by itself 1 px per tick with horizontal scrolling off; touching the top edge or falling below the
screen kills `[TD]` (scroll mode bits), `[B:level.c:level_adjust_y_scroll, level_update_player_decor]`, `[TVT]`.

### 7.12 Camera

`[B:level.c:level_adjust_x_scroll, level_adjust_y_scroll]`, `[MAN]`:

- Original horizontal scroll is look-ahead paging: when the hero passes column 16 of 20 (or column 4 going left) the
  view slides one tile per tick until he is near the opposite side.
- Vertical: keeps the hero between rows 3 and 9 of 11 with speed proportional to distance (1..16 px/tick).
- Manual look: holding Left+Right together (or keypad 5) scrolls further in the facing direction.

---

## 8. Hero abilities, weapons and power-ups

### 8.1 Weapons

`[MAN]`, `[B:staticres.c:club_anim_tbl, club_anim_data]`, `[B:level.c:level_update_player_anim_3_6_7, level_update_objects_club_projectiles]`:

| Weapon | Kind | Power | Recovery after a swing | Notes |
|---|---|---|---|---|
| Club (default) | melee | 25 | 2 ticks | quick |
| Big Hammer | melee | 30 | 6 ticks | stronger, slower |
| Axe | thrown | 20 | 6 ticks | 13 px/tick forward, slight upward toss, then falls (2 px/tick^2); long range, weak |
| Big Swirling Axe ("flying blade" `[YT]`) | thrown | 30 | 12 ticks | 13 px/tick forward and curves **upward** with growing speed; strongest, slowest |

- Picking up a weapon item replaces the current weapon; it is kept through deaths and levels until game over.
- Thrown weapons: max 4 in flight; ignore walls; disappear on hitting an enemy, a hidden spot or leaving the screen.
- **Directional strikes**: attack alone = forward swing (with a tiny hop); Up+attack = overhead strike; Down+attack =
  low ground strike with a slightly bigger hop and dust `[MAN]`, `[B:staticres.c:player_anim_lut]`.
- **Crouch power**: crouching charges a short timer (about 50 ticks); while it runs every hit does **4x damage** `[MAN]`,
  `[B:level.c:level_update_player_club_power]`.
- No attacks while carrying the hang-glider `[MAN]`.

### 8.2 Movement set (summary; exact numbers belong to the physics spec)

`[B:level.c:level_update_player*]`, `[MAN]`:

- Walk/run: accelerate 16 v16 per tick to 80 (5 px/tick); brake 12 v16 per tick; ice divides both.
- Skid animation with dust when stopping from speed; **out-of-breath** animation after running 30+ ticks and stopping
  `[WP]`; idle fidget animation on a timer.
- Jump: variable height (about 15 px for a tap, about 60 px for a full hold, 9 ticks of thrust); gravity 16 v16 per
  tick, terminal 12 px/tick. While jump is held air speed is capped at 3 px/tick; releasing it allows 5 px/tick and
  softer fall - the manual's long-jump recipe: run, jump, release Up while falling.
- 6 ticks of no-jump after landing from a fall.
- Crouch (Down) and crawl (Down + direction, 2 px/tick): wind immunity, earthquake stability, 4x strike, hatch drop,
  gate entry.
- Head bounce on enemies (5.1). Mid-air club hits give lift (4.4).
- Hurt: thrown back, 44 ticks invulnerable. Death: flung upward and off screen (60 ticks), then curtain.

### 8.3 Timed and instant power-ups

| Power-up | Effect | Source |
|---|---|---|
| Fork + knife + spoon | **Feast**: 660 ticks during which enemies are food and die on touch; a screen shake warns 7 ticks before the end. This is the game's "invincibility" | `[MAN]`, `[B:level.c:level_update_player_bonuses]` |
| Grenade | on-screen enemies become 16 bonus items each | `[MAN]`, `[P:player_interaction.py num 0xAA]` |
| Kill-all item | on-screen enemies die and pay score | `[P:player_interaction.py num 0xA9]` |
| Heart | +1 heart (max 3) | `[MAN]` |
| 1UP | +1 life (max 99) | `[MAN]` |
| Bones | 6 = 1 heart | `[MAN]` |
| Lighter | unlocks the exit | `[MAN]` |

### 8.4 Hang-glider

`[MAN]`, `[B:level.c:level_update_player (flying branch), level_update_player_anim_34, level_update_player_flying]`:

- Take the glider item; run at speed 4+ px/tick for 24 ticks "until the wing inflates"; jump to take off.
- Gliding: gravity is a quarter of normal and sink speed is capped at 1.5 px/tick; forward speed builds "lift"; holding
  Up spends lift to climb 4 px/tick; without lift the nose-up glider stalls; Down dives.
- A long fall with the folded glider opens it automatically (above 10 px/tick).
- Landing keeps the glider; a hit removes it without costing energy; it is removed at level end.
- Dive attack: 1 000 / 5 000 / 10 000 and kill on the third dive.
- The flight model in `blues` is partly simplified; exact lift numbers `[INFERRED]`.

---

## 9. Bonus stages and special rooms

- Three bonus stages (index 10, 11, 12), one tileset: a land made of sweets and food with a giant roast in the
  background `[TVT]`, own music (KOOL), packed with bonus items. Heights 24, 51, 51 tiles `[TD]`.
- Entered by touching the hidden warp item in levels 2, 3a and 4; left through another warp item, which ends the
  source level with a tally (1.1). Lives can still be lost there; enemy presence `[INFERRED]`.
- Sub-stages 3b (glider crossing `[INFERRED]`) and 7b (blizzard) are mandatory second halves of their levels.
- Single-screen secret rooms via gates (4.6).
- Ending stage: a very tall playable epilogue with credits `[YT]`, `[B:level.c:level_update_tile_type_2]`; layout `[INFERRED]`.

---

## 10. Audio

### 10.1 Sound cues

11 sample slots, 8 kHz mono `[B:sound.c]`, `[TD]`; a single effect channel, so a new cue cuts off the previous one
(`mixer.c` in the `blues` repository root). Cue usage from the call sites in `[B:level.c]`, `[B:bosses.c]`:

| Slot | Used for |
|---|---|
| 0 | hammer swing; kill-all / grenade explosion |
| 1 | heavy hurt: skull, boss hit, boss projectile; "lights off" |
| 2 | enemy killed by a weapon; minotaur roar when hit |
| 3 | bounce on an enemy or boss head |
| 4 | big pick-up: giant bonus, heart, 1UP |
| 5 | club swing |
| 6 | empty |
| 7 | hero death |
| 8 | normal pick-up (food, bones, letters, cutlery, weapons, glider); boss hit by a weapon; each item counted at the tally |
| 9 | hero hurt by an enemy |
| 10 | axe throw (both axes) |

There are no separate cues for jumping, landing, walking, checkpoint or exit.

### 10.2 Music contexts

12 tracker modules `[B:sound.c:trk_names_tbl]`, `[B:level.c:do_level music_tbl]`, `[P:front_end.py]`, https://pre2.mine.nu/music.htm:

| Track | Context |
|---|---|
| PRESENTA | title picture and main menu |
| CODE | mode-select and code-entry screens |
| CARTE | world map |
| MINES | levels 1, 2 and stage 3b |
| PRES | levels 3a, 4, 5 |
| GLACE | levels 7a, 7b, 8 |
| MYSTERY | level 9 |
| MONSTER | level 6, level 10 and whenever a boss energy bar is on screen |
| KOOL | bonus stages |
| BRAVO | level-complete tally |
| BOULA | game over |
| FINAL | ending stage |

F3 toggles sound `[MAN]` (whether it mutes music, effects or both is `[INFERRED]`).

---

## 11. UX flow

### 11.1 Screen sequence

`[P:pre2/native/front_end.py]` (ASM-verified), `[B:game.c:game_run]`:

1. (Year 1996 or later: "oldies" joke screen, wait for fire.)
2. Publisher logo: fade in, hold about 1 s, fade out. Not skippable.
3. Title picture; title music starts; the game logo is revealed by a palette morph.
4. **Main menu picture** ("press 1 / 2"): `1` or fire = start, `2` = enter code. After about 4 s idle (270 retraces;
   `blues` uses 15 s) the **attract loop** runs: animated title (hero runs across chased by a dinosaur, then runs back
   chased by three), world map, then a recorded demo of level 1; any key returns to the menu.
5. **Mode select**: scrolling tiled backdrop, text "MODE" with BEGINNER / EXPERT toggled by the arrows, fire confirms;
   always starts at level 1. Or **Enter code**: "ENTER CODE" and four characters.
6. **World map**: a two-screen-wide map scrolls in (1 px per retrace) with a "you are here" hero marker at the level's
   location; fire or the end of the scroll continues; fade to black. Shown before every level; no selection on it.
7. **Gameplay**: opens with a centre-out curtain. Level start state: 3 hearts, no glider.
8. **Level end**: iris-in on the hero -> tally (3.7) -> map -> next level. Bonus warps and gates use the curtain instead.
9. **Death**: death toss -> curtain -> respawn at the checkpoint. No lives left -> **game over** scene: bouncing
   "GAME OVER" letters, the crying companion, three creatures circling him; ends on fire or after about 9 s; fade; back to
   step 4 with lives 2, letters and cutlery cleared, score 0.
10. **Beginner wall** before level 9: castle picture, wait for fire, back to step 4.
11. **Ending**: ending stage -> THE END picture -> (photos) -> step 4.

### 11.2 In-game keys

`[MAN]`, `[P:pre2/native/player.py]`, `[B:level.c:level_update_player]`:

| Input | Action |
|---|---|
| Left / Right | walk |
| Up | jump (the original has no separate jump button; `blues` adds one) |
| Down | crouch; enter gate; drop through hatch |
| Space / button A | strike |
| Left+Right together, keypad 5, button B | look ahead |
| P | pause (freezes the game; no pause menu; details `[INFERRED]`) |
| F1 | give up the current life and restart at the checkpoint |
| F2 | abandon the game, back to the menu |
| F3 | sound on/off |

Joystick supported `[MAN]`.

---

## 12. Adaptation plan for "Club & Grub"

Goal: same mechanics and feel, original content. Everything in sections 2-8 is in scope unless listed under
"Deliberate changes".

### 12.1 World and level structure (8 levels + 2 boss fights + bonus + epilogue)

| # | World | Level (working name) | Mirrors original | Signature mechanics |
|---|---|---|---|---|
| 1-1 | Jungle | Vine Bridges | level 1 | tutorial: club, hidden spots, head bounce, first checkpoint, traffic-light exit |
| 1-2 | Jungle | Canopy Village | level 5 | tall vertical map, tree houses, arc leapers, moving platforms, **axe pick-up**, warp to bonus stage A |
| 2-1 | Caves | Echo Caverns | level 2 | tall cave, hatches, danglers and ceiling droppers, darkness triggers, gates to secret rooms, **hammer pick-up**, warp to bonus stage B |
| 2-2 | Caves | Bone Gorge | levels 3a + 3b | glider crossing over a chasm, rising columns, then **BOSS 1: the Brute** (gorilla archetype); boss drops the fire-starter for the exit |
| 3-1 | Ice | Frost Summit | levels 7a + 7b | slippery ground, patrollers on slopes, edge rushers; second half is a blizzard with head wind (crouch to resist) |
| 3-2 | Ice | Crystal Grotto | level 8 | ice cave, drop platforms, leapers out of water pits, **swirling-axe pick-up**, warp to bonus stage C. Last level in Beginner |
| 4-1 | Volcano | Cinder Shaft | level 6 (descent) | auto-scrolling descent inside a volcanic chimney; falling embers reuse the leaf hazard; burrowers. Expert only |
| 4-2 | Volcano | Obsidian Keep | levels 9 + 10 | fortress with spikes and rising columns, ending in **BOSS 2: the Wall Colossus** (minotaur archetype, thrown weapons only; an axe is always provided at the checkpoint). Expert only |
| B | - | Feast Land A/B/C | bonus stages | one food-themed tileset, three short maps, no completion-percentage quirk |
| E | - | Way Home | ending stage | short playable credits roll, then "The End" |

Optional stretch: the tree-stump boss as a mid-boss at the bottom of 4-1 (re-themed as a lava-rock guardian with a
pounding fist); the behaviour spec in 6.2 is ready for it.

Stage flow, map screen between levels, Beginner/Expert split and the Beginner wall are kept.

### 12.2 Enemy stand-ins (behaviour only, any free prehistoric or animal sprite fits)

| Archetype (5.2) | Role name | Needs from the sprite | Suggested skins per world |
|---|---|---|---|
| 0 Sky dropper | "Dropper" | fall frame, walk cycle | monkey, crab, rock lizard, ember imp |
| 2 Yo-yo dangler | "Dangler" | one hanging pose | spider, bat on a vine, ice grub |
| 3 Ceiling dropper -> chaser | "Lurker" | hanging pose, run cycle | spiderling, gecko, cave beetle |
| 4 Pendulum | "Swinger" | one pose | spider, swinging monkey, lava drip |
| 5 Sentry diver | "Stinger" | hover, dive | wasp, bee, small pterosaur |
| 6 Clever flyer | "Harrier" | flap cycle | bird, bat, pterosaur |
| 7 Kamikaze diver | "Dart" | dive pose | dragonfly, hawk |
| 8 Hopper | "Hopper" | crouch, jump, land | small dinosaur, frog, sabre cat, worm |
| 9 Patroller (ground / air) | "Walker" / "Glider" | walk or fly cycle | snail, turtle, boar, penguin / bird |
| 10 Burrower | "Digger" | emerge, walk, sink | mole, worm, snake, lava bug |
| 11 Arc leaper | "Leaper" | leap, glide | flying squirrel, jumping fish, magma blob |
| 12 Edge rusher | "Charger" | fast run cycle | rival caveman, boar, wolf, penguin |
| 1 Decoration | - | static | webs, vines |
| Boss: Brute (6.1) | multi-part giant | body, head, two arms, 6 poses | giant ape, cave bear, yeti |
| Boss: Wall Colossus (6.3) | wall statue | 5 full poses | stone idol, lava golem |
| (stretch) Rooted Guardian (6.2) | stationary puncher | face, fist, 3 damage stages | tree stump, rock guardian |

Shared enemy rules to implement once: 12 active, spawn/despawn windows, hit points versus weapon power, flash and
knock-back, death arc, bone burst after stealing a heart, head-bounce multiplier, feast-mode food swap, Expert-only flag.

### 12.3 Collectible and scoring model

- Score ladder of 3.1 unchanged; three food tiers (100-500, 600-1 000, treasures 2 000-8 000), giant bonuses
  10 000-60 000, 100 000 for the five letters of our own word (working: G-R-U-B-S).
- Hidden spots: all three kinds with flood-fill opening; debris look per world.
- Bones (6 per heart), hearts (max 3), 1UP, extra life every 250 000, cap 99.
- Cutlery feast (660 ticks), grenade, kill-all, skull, fire-starter + exit totem, checkpoint torches.
- Head-bounce multiplier 1/2/3/4/6/8; glider dives 1 000 / 5 000 / 10 000.
- Tally: score, completion %, collected-since-last-death items paid again.

### 12.4 Deliberate changes

| Original | Ours | Reason |
|---|---|---|
| Machine-specific codes hidden in levels | automatic save of the highest level per mode + level select on the map; hidden "code stones" remain as collectible lore | portability, no keyboard on mobile |
| Up = jump, Space = strike, F1/F2/F3/P | separate jump and strike actions, remappable; pause menu with resume / restart from checkpoint / quit / audio | gamepad and touch |
| Completion % doubling quirk (3.5) | plain per-level percentage; bonus stage counted with its source level | clarity |
| No continues | keep (codes replaced by saves) | faithful difficulty |
| 23.33 Hz logic | fixed-step simulation with interpolation; speeds converted in the physics spec | smoothness |
| Paging camera | smooth look-ahead camera; manual look kept | modern displays |
| One sound at a time, no jump/landing cue | small mixer; add jump, land, checkpoint, exit, menu cues | production quality |
| 320x200, 24 px panel | 320x180 base scaled by integer factors; HUD as an overlay with safe-area margins | 16:9 screens, phones |
| Easter eggs tied to the PC clock | dropped | not relevant |
| A checkpoint touched in the air stores the hero's mid-air point | a touch in the air stores the checkpoint's own (floor) point | a point over a gap made every respawn fall into it again |
| A fast landing (8+ px/tick) can step across a sprite platform's 8 px contact band | the band reaches 16 px for a fast-falling hero | fairness: floes "not catching" the hero looked like a bug |
| Codes are compared character by character | O and I are read as 0 and 1 | the pixel font draws them alike |

---

## 13. Items still `[INFERRED]`

1. Content and theme of the intermediate stage 3b (glider crossing).
2. Exact arenas and per-level parameters of both gorilla fights; durations inside the gorilla attack routine.
3. Which sprite picture maps to which bonus value, and the look of the warp item, the kill-all item and the tally companion.
4. Species used per archetype and per level (only partly documented); species named only by secondary sources.
5. Per-type respawn rules of enemies (flag semantics in `blues` are ambiguous).
6. Damage path of the minotaur's rock and chandelier, and that level 10 supplies an axe.
7. Which tree-boss part is vulnerable in each stage.
8. Water behaviour (treated as a pit).
9. Pause details and what exactly F3 mutes.
10. Hang-glider lift numbers.
11. Which levels use the darkness triggers.
12. Placement of warp items in levels 2, 3a, 4 and whether bonus stages contain enemies.
13. Layout of the ending stage.
14. Screen anchoring of the boss energy bar.
15. Tick rate to use when converting per-tick values (23.33 Hz per `[P]`, 30 Hz in `blues`) - to be settled by the physics spec.

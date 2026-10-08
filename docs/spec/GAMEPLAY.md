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
The full list is repeated in section 14. Section 13 is the gameplay spec of version 2.0 (our own design, not the
original's).

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

- If the system clock is 1996 or later the game opens with a short message from the programmer, cheering that the
  game still runs in the current year and that it was programmed in 1992 on a 286 PC (paraphrased here; not used by
  Club & Grub) `[B:game.c:do_programmed_in_1992_screen]`, `[TVT]`.
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
  *Club & Grub*: a continuous bone-framed bar under the hearts, top-centre on every device (the touch buttons fill
  both bottom corners), its fill spanning the boss's own hit points (`scripts/ui/hud_boss_bar.gd`).
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
- **Club & Grub (the remake's Wall Colossus, `scripts/bosses/colossus.gd`, EnemyTuning COLOSSUS_* / ROCK_* /
  STALACTITE_*)**, tuned for fairness with telegraphs the original lacks:
  - idle loop of 84, 30, 30, 20, 20 ticks between attacks (the first rock leaves on the 94th tick of the fight);
    hits never stop the attacks: the idle clock runs on through hurt poses, and a hit landed during an attack is
    roared after it (no stun-lock);
  - **spit**: the open jaws show 10 ticks before the rock leaves; rock speeds 32..96 v16 (2-6 px per tick); a rock
    bounces twice, rolls 10 ticks and crumbles (none lies waiting on the slab);
  - **stalactites** (the chandeliers) rattle 14 ticks under the hall's rock ceiling before they fall, below the HUD
    row and the boss bar;
  - **hurt pose** and the boss's own hit cooldown: 26 ticks; the 1st hit and every 4th hit after it start the red
    **rage** pose (40 ticks, armoured: thrown weapons glance off it; its rock leaves 10 ticks in, stalactites drop at
    18 and 28);
  - a club or hammer on the head **glances off** with a clank and a spark (no damage), and a sign by the axe at the
    checkpoint says that only a thrown axe cracks the statue;
  - fairness is pinned by `tests/test_enemies_colossus.gd` (every attack shown 10+ ticks ahead, every rock speed
    jumpable from the slab, stalactites escapable, no stun-lock, both thrown weapons reach the head).

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
*Club & Grub*: the descent starts with the player's first input (at the level start and after a respawn), so a
newcomer reading the start sign is not carried off the top edge; the deadly top edge is drawn as a band of smoke
(`scripts/world/level.gd`). A route that moves on its first tick sinks exactly as in the original.

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

## 13. Expansion 2.0 "The Far Shore"

The gameplay spec of version 2.0: Book II (20 level files, 6 bosses, new mechanics), two-player co-op over all 35
stages and same-device versus for 2-4 players with bots. It restates `docs/expansion/DESIGN.md` (the binding design)
as implementable rules; per-tick physics is in `docs/spec/PHYSICS.md` Appendix C ("P-C.n" below), level building in
`docs/LEVEL_DESIGN.md` 15. Sections 1-12 do not change and remain the spec of Book I solo, which plays exactly as
1.0.0. Values marked *(tune)* are playtest starting values (register in 13.11); resolutions of DESIGN.md are marked
**[Rn]** (DESIGN.md "Appendix: P0.2 spec resolutions") and **[Gn]** (DESIGN.md "Appendix: G1 and phase-2
resolutions"). Time conversions: P-C.16.

### 13.1 Modes, books and the campaign

- **Front end**: Title > Play > **Solo / Co-op / Versus**. Solo and Co-op open the **book select** (two carved
  slabs: Book I "The First Feast" = the 15 shipped files, Book II "The Far Shore" = 20 new files), then Beginner /
  Expert, then that book's world map. Co-op opens the join panel first (13.9.1). **Book II is open from the start.**
- **Saves**: every (mode, book, difficulty) has its own highest level, level select and high-score table
  (`Save.VERSION = 2`; 1.0 saves migrate to (single, book 1)). Paintings and versus unlocks are per profile, across
  modes. Book II has level codes in solo (`password_beginner` / `password_expert`, unique across both books); co-op
  has no codes and continues from its save.
- **Registry**: meta `book` (default 1). `Levels.get_campaign(difficulty, book)`, `next_level`, the map and the route
  tests filter by it. Co-op campaign = the solo campaign of that book with every stop replaced by its `coop_of` file
  (`<id>_coop`). `kind = coop` and `kind = arena` files never appear in a solo query; arenas never in a campaign.
- **A Book II run** starts with score 0, lives 2, no letters, the club in hand and an empty belt. Carried from stage
  to stage: score, lives, letters (Book II has its own G-R-U-B-S set in worlds 5-7), hand and belt (P-C.2). The glider
  is taken away at the tally, as in Book I. Joining or leaving co-op mid-stage restarts the stage at its checkpoint
  in the other file (score kept), because the co-op file holds different entities.
- **Linking** (1.0 rules of 1.1 and LEVEL_DESIGN 3): `w5_l2 -> w5_l2b`, `w6_l2 -> w6_l2b`, `w7_l2 -> w7_l2b`,
  `w8_l2 -> w8_l2b`, `w9_l1 -> w9_l1b`, `w9_l2 -> w9_l2b` (`tally = false` on the first half). Warps: `w5_l2 ->
  bonus_d`, `w7_l1 -> bonus_e` (a warp in a bonus stage ends the source level with a tally, then the level after the
  source stop, 1.1). A warp from a linked first half skips its sub-stage: 5-2's warp -> Feast Land D -> the tally of
  the 5-2 stop -> the map of 6-1, passing Tusker's Wallow by, as warping from 3a skipped 3b in the original [G16].
  `w9_l3`'s final boss drops the trophy (the Great Roast), which leads to `ending_b`.
- **Expert wall**: a Beginner run ends after `w7_l2b`'s tally with the expert-wall picture "Only an expert eater may
  climb to the Roc!" and returns to the title (the 1.0 flow of 11.1 #10).
- **Ending**: `ending_b` "The Long Raft Home" has no failure state (no enemies; its raft has `rails`, P-C.7,
  so nobody leaves it over the water); food rains from the Roc's broken hoard; credits ride on floating signs; the home beach is the exit
  (team exit in co-op) -> THE END picture, or the cave mural when all 30 paintings are found -> credits -> title.

### 13.2 Book II stages

| # | Id | Name | Kind, order, links | Mode | Diff. | Painting | Letter | Special lying there |
|---|---|---|---|---|---|---|---|---|
| 1 | `w5_l1` | Red Mesa Trail | main 110 | B | 3 | 0 | - | spear (first checkpoint) |
| 2 | `w5_l2` | Rattlesnake Gulch | main 115, `tally = false`, `bonus = bonus_d` | B | 4 | 1 | G | - |
| 3 | `w5_l2b` | Tusker's Wallow | sub | B | 4 | 2 | - | - |
| 4 | `w6_l1` | Bubbling Fen | main 120 | B | 5 | 3 | R | hammer (on a drifting raft) |
| 5 | `w6_l2` | Spore Hollow | main 125, `tally = false` | B | 5 | 4 | U | - |
| 6 | `w6_l2b` | Heart of the Mangrove | sub | B | 6 | 5 | - | - |
| 7 | `w7_l1` | Shell Beach | main 130, `bonus = bonus_e` | B | 5 | 6 | B | axe |
| 8 | `w7_l2` | Sea Caves | main 135, `tally = false` | B | 6 | 7 | S | - |
| 9 | `w7_l2b` | Squid Grotto | sub; last Beginner stage | B | 7 | 8 | - | - |
| 10 | `w8_l1` | Overgrown Steps | main 140 | E | 7 | 9 | - | swirling axe |
| 11 | `w8_l2` | Hall of Idols | main 145, `tally = false` | E | 8 | 10 | - | - |
| 12 | `w8_l2b` | Idol Court | sub | E | 8 | 11 | - | - |
| 13 | `w9_l1` | Cloudbreak Climb | main 150, `tally = false` | E | 8 | 12 | - | spear |
| 14 | `w9_l1b` | Thunderhead Glide | sub | E | 8 | 13 | - | - |
| 15 | `w9_l2` | The Roc's Spire | main 155, `tally = false` | E | 9 | 14 | - | - |
| 16 | `w9_l2b` | Storm Nest | sub | E | 9 | 15 | - | - |
| 17 | `w9_l3` | Chieftains' Pyre | main 160 | E | 10 | 16 | - | - |
| 18 | `bonus_d` | Feast Land D: Honey Falls | bonus (from 5-2) | B | 2 | 17 | - | - |
| 19 | `bonus_e` | Feast Land E: Pudding Lagoon | bonus (from 7-1) | B | 3 | 18 | - | - |
| 20 | `ending_b` | The Long Raft Home | ending | E | 2 | 19 | - | - |

Mode B = Beginner and Expert, E = Expert only (`min_difficulty = expert`). Every world has one full feast kit; the
per-record `expert` flag works as in 1.0. Signature mechanics and per-level notes: DESIGN.md A.2-A.3. **No special is
ever needed** on a main path; specials open shortcuts, secrets and paintings (13.3).

### 13.3 The weapon belt, the spear and the new terrain (player view)

- **Belt** (P-C.2): two places, hand and belt; one always holds the club, the other at most one special (hammer,
  axe, swirling axe, spear). A picked special goes into the hand and the club onto the belt; an owned special is
  replaced and gone. **Swap** (keyboard V or `;`, pad LB, the touch Y stone) exchanges them on the tick it is pressed,
  not during a strike, also in the air; star puff and blip; 8 ticks before the next swap *(tune)*. Every Book II stage
  and every co-op stage starts with the club in hand (`belt = fresh`); hand and belt are kept through deaths. Book I
  solo keeps the 1.0 single weapon (`belt = carry`, Swap ignored).
- **HUD**: a 16 px icon right of the hearts shows what a swap brings (the belt item); hidden while no special is
  owned. Co-op: P2's icon mirrored top-right.
- **Spear** (P-C.3): thrown flat 12 px/tick for 8 ticks, then it drops; power 25; like the axe it passes walls and
  opens hidden spots; at most 2 per hero. A spear that hits a **bark board** sticks and is a 16 px one-way step for
  220 ticks (blinks the last 22). Boards exist only where designers put them (secrets, the Feast Land D warp,
  paintings).
- **Vines** (P-C.4): Up (without Down) grabs a vine within 6 px; climb up 2 px/tick, down 3; Up at the top steps onto
  the ledge (a landing); a direction + Jump leaps off; Down + Jump drops; no strikes on a vine; a hit knocks the hero
  off. A climber is held by his vine, so vines are climbed from rafts, spear steps and lifts [G8]. **Rolled vines** lie
  coiled on a ledge until one strike unrolls them (they stay unrolled).
- **Tar** `:` (P-C.5): the hero sinks 6 px, wades at 2 px/tick and only hops (33 px; on the tar itself the hop lands
  on tick 16, 32 px out); ground enemies are slowed the same way; dropped items stop dead. The tar rules end at his next
  landing or when anything but his own hop throws him up (a geyser, a bounce, a launch, a hurt) [G8]. `~` of
  `liquid = tar` kills like water. Honey (Feast Land D) and syrup (Feast Land E) are the same rules in candy skins.
- **Geysers** (P-C.6): bubble 22 ticks with a sound, then spout 12 ticks; the spout throws heroes, ground enemies,
  rafts and drop platforms up with the spring power (default -224, 105 px); a geyser on a tar floor gets a wading
  hero out with full air control. Harmless, except `deadly` vents (tar or lava), which a heave boulder can plug.
  Skins: mud, blowhole, steam, soda.
- **Rafts and currents** (P-C.7): rafts float on `~`; currents (1-3 px/tick) carry them; outside a current a raft
  slows by 1 px/tick every 8 ticks; banks stop it; a forward strike on a raft paddles it backward (up to 3 px/tick).
  Water stays deadly (no swimming).
- **Rising tide** (P-C.8): on `scroll = rising` stages a band of the level's liquid rises from 6 rows under the start
  (or the checkpoint) at `rise_speed` (default 1 px/tick) once the player moves; it kills on touch; the view never
  scrolls down and follows each hero's footing, never a jump's apex, so a jump in place lands in view [G42];
  `zones/autoscroll_stop` ends it.
- **Alternating gusts** (P-C.6): negative wind pushes right; `wind_loop` repeats a wind script (9-2, Floe Rink, Cloud
  Top); crouching braces as in 1.0; outside the ice biome the wind shows as gust streaks. **Co-op lee** [G23]: a hero
  up to 64 px downwind of a crouching partner feels no wind, and a jump taken in the lee stays sheltered until he
  lands - the "lee leapfrog" over gust gaps of up to 3 tiles, a co-op comfort, never a gate (the first hero over
  crosses unsheltered, as a lone hero can) [G55]. **Lightning** (`zones/lightning`, `period` [66]; 9-1b,
  Cloud Top): a darkening cloud marks a hero's column 22 ticks before the bolt (the target alternates between the
  heroes inside; eggs are never struck); a bolt hurts like an enemy (a glider is lost instead of a heart); cue
  `Sfx.LIGHTNING_STRIKE`. **Drop clouds / crumbling clouds / driftwood floes** are 1.0 drop platforms in new skins.
- **Food rain** (`zones/food_rain period skin=food|fruit`, Feast Land E, `ending_b`): the ember-rain zone of 4-1
  dropping collectable food (`food`: the level's `bonus_tier` cell; `fruit`: the fruit cells) instead of embers, one
  stream per hero inside; never hurts [R5].
- **Lights in the dark**: on a Book II level, an arena or in a party, the night palette of 7.10 keeps a warm glow
  around every hero and a teal glow around every prop whose picture name holds "glow"; Book I solo keeps the 1.0 look.

### 13.4 Chomper, the rex you ride

`objects/mount kind=rex pen=<name> [wild]` with its pen `objects/rex_pen name=<name>` (P-C.9 for the numbers).
- Wild in 6-1 (`wild`, stuck behind a rock fall): touching his side hurts; three head bounces in a row (no landing in
  between) tame him. Later stages keep him tame in pens. A mount never leaves its stage.
- Land on the saddle from above to ride; Down + Jump dismounts. Mounted: walk 4 px/tick, hop -160 (55 px), Strike =
  **bite** (0-40 px in front, knee to head): an enemy with `hp < 50` is **eaten** and pays its score plus 500
  *(tune)*; a bigger one takes 25. Chomper walks over floor spikes `^` and wades `:` at full speed; `~` still kills.
- The glider contract: no strikes with your own weapon while driving; a hit throws the rider off without costing a
  heart and the rex bolts to his pen, back after 132 ticks; no gates or hatches while mounted; mounted corridors
  need 4 rows of air.
- Co-op **two seats**: the first hero to sit drives (move, hop, bite); a partner who lands on his back is the
  **gunner** - he cannot move, but strikes and throws both ways with his own belt (Left / Right turn him). A hit throws
  both off. Used in 6-1, 7-1 and the Mesa Rodeo arena.

### 13.5 Book II enemies

Most Book II species are skins of the 13 shipped archetypes (DESIGN.md A.5: `skin=` of `enemies/*`). Three new
behaviours (each one parameterised state machine in `scripts/enemies/`, no projectiles, head always safe to bounce,
each declares its doze rule; Book I never spawns them). Defaults `hp` [25], `score` [per type].

| Id | Rule | Parameters |
|---|---|---|
| `enemies/roller` (13) | walks between `left` / `right` at 32 v16 *(tune)*; when its target is within `range` tiles horizontally and 4 rows vertically *(tune)* it **curls** (a 14-tick visible tuck, no motion) and **rolls** at the target's side at `speed`, following the ground and slopes, +4 v16 per tick while on a descending slope (cap 96); while rolling, weapon hits glance (clank) and its contact hurts; it rolls off ledges (gravity) and into liquids (gone); hitting a wall it stops and is **dizzy** `dizzy` ticks (hittable, harmless to bounce on), then uncurls (8 ticks) and walks; after 154 ticks of rolling it uncurls by itself *(tune)* | `range` [6], `speed` [64], `dizzy` [33], `left` / `right` [-3 / 3] |
| `enemies/guard` (14) | patrols between `left` / `right` at 24 v16 *(tune)*, faces its target and **turns only every `turn` ticks** (its facing is re-decided on its own `turn`-tick clock); a hit from the side it faces (the striker's x on that side, or a projectile flying into its face) **glances** (the Colossus clank and spark); hits from behind count. Solo answer: bounce over it and strike before it turns | `turn` [33], `left` / `right` [-3 / 3] |
| `enemies/mimic` (15) | box 24 x 18 (the chest container's); while waiting it is drawn exactly as `objects/container skin=chest`, never mirrored; faces the nearer hero; when a hero comes within 32 px horizontally and 16 px vertically ("on its floor": a hero jumping over it does not wake it) it shudders 10 ticks (telegraph), then bites with the snapper rules (`range` 42 px - the snapper's strip -, recovery, 22-tick rest); front hits glance; a head bounce dazes it 22 ticks *(tune)*, during which it neither turns nor bites and any hit counts; hits from behind count; killed, its `contents` fan out; score index 5 (700) [G11] | `contents` [`treasure`], `range` [42] |

### 13.6 Bosses

**Rules every boss follows** (DESIGN.md B.0):
- Every attack shows itself **10 or more ticks** ahead (pinned per boss by `tests/test_enemies_<boss>.gd`).
- `BOSS_HIT_COOLDOWN` 22 ticks per boss: a hit counts at most once per 22 ticks, whoever lands it (two heroes cannot
  double the damage); attack clocks keep running through hurt poses (no stun-lock).
- Head bounces bounce the hero (-64, -128 with Up) and harm nobody. Boss body contact costs one bone with the boss
  knock-back (10.1); boss projectiles and falling debris cost one heart and scatter 6 bones.
- **Book II: every boss falls to the club**; specials only make it easier. Hit points are hp: club 25 per hit, x4
  charged; Old Mangrove and the Twin Idols (archetypes 6.2 / 6.3) count 1 per hit of any weapon. A boss is defeated
  when its hp reaches 0 (`BossBase`), so 150 hp = 6 club hits.
- Defeat: 64 bonus items plus the key item (the fire-starter; the Chieftains: the trophy). Boss music while the bar
  shows.
- **Co-op form** (in `<id>_coop` files): hit points at most x1.25 of the solo form (rounded down) [R8] and one rule one
  player cannot satisfy [G34]: wherever the design allows, two heroes' own actions (hits by two different heroes, the
  partner's hit on a grab, a brace); a rule about where heroes stand counts only **active** heroes (13.9.2: an idle
  hero is nobody [G33]). A rule that needs two different heroes' hits is not capped by the measured solo minimum: its
  window is the difficulty value (13.9.3). It resets only on a team wipe; its test asserts that the single-hero search -
  one hero with every weapon plus an idle hatched partner placed anywhere he could be hatched - cannot beat it.
- **Weak points clear of the HUD** [G35]: the HUD band of a boss fight is the top row - 31 px deep on a phone or
  tablet, 27 on a computer; in co-op the letters give way and P2's panel moves up into it while a boss bar shows - and,
  in the boss bar's columns (53 px left to 38 px right of the view's centre), down to 48 px (`Hud.band_rects`). Every
  rectangle a counted hit must touch lies wholly inside the locked view, in every pose in which it can be struck, with
  its top at least 24 px below the band over its columns: 55 px under the view's top, 72 px in the bar's columns (with
  the floor on the last row of an 11-row lock, at most 105 / 88 px over the floor's top). Each boss test pins it on
  its arena (`Hud.weak_point_problem`); Book I's solo boss rooms are frozen and exempt.
- Arenas are `zones/arena` rooms with `|` walls; in co-op the lock pulls the partner in (P-C.13).

**Tusker, the Boar King** (`bosses/tusker`, `w5_l2b`). Arena (as built [G38]): one walled screen; mesa banks 3 cells
wide and 3 rows up at cols 1-3 and 16-18; a 4-cell mud wallow (`:` in a mud skin) at cols 8-11. Body about 75 x 55 px (box 64 x 48 *(tune)*); weak point
the head while dizzy or stuck (a high strike or a bounce and strike reaches it); the tusks glance during a charge.
hp: Beginner 150 (6 hits), Expert 225 (9); co-op 187 / 280 [R8].
- **Phase 1** (hp > 60 %): idle 44 ticks *(tune)*; **paws 22 ticks** (dust, snort) facing its target; **charges at
  96 v16**. Into a wall: **dizzy 44 ticks**. Into the wallow: slowed to 32 v16; at the wallow's centre it is **stuck
  22 ticks** (head open), then wades out and charges on.
- **Phase 2** (60-30 %): a **14-tick squeal** while it curls; rolls at 96 v16 and bounces off the walls in two arcs
  (`yvel` -128 at each wall *(tune)*), then a high hop (`yvel` -192 *(tune)*) whose landing shakes the screen (shake 8:
  crouch to stand firm); it uncurls **dizzy 33 ticks**.
- **Phase 3** (< 30 %): phase 1 with idles of 22 *(tune)*; every wall impact shakes **3 rocks** loose over arena
  columns at least 2 apart (`Sim.rng`), each marked by a dust trickle **14 ticks** before it falls (rock = the
  Colossus rock: bounces twice, rolls 10 ticks, crumbles).
- **Co-op**: it charges whoever hit it last (at first the nearest active hero); while dizzy or stuck it turns every
  tick to face the nearer **active** hero [G33] and its head glances: only the partner behind can strike the **leafy
  rump** (the co-op weak point). Phase 3: its charges skid and turn 32 px before a wall (no impact, no rocks, no
  dizziness); only a **Brace Wall** of two active heroes (P-C.10) stops it dead there: **dazed 66 ticks**, head and
  rump open; a charge across the wallow may still stick it (rump open from behind only) [G38]. One crouching hero is
  trampled.

**Old Mangrove, the Rooted Guardian** (`bosses/mangrove`, `w6_l2b`; the tree-stump archetype of 6.2). Arena: the
chamber at the top of the tar climb; floor row 10, the last row of an 11-row camera lock; the Guardian fills cols
15-18 of the right wall; one-way root ledges on the left at rows 7 and 5, the upper one ending at col 5 [G35] (the
hand resting on its end stays 60 px under the view's top, left of the boss bar's columns). Walking into the trunk pushes the hero back and costs a bone; the moving fist
throws him back and costs 3 bones; standing on the resting fist launches him unharmed (-160, -224 with Up
*(tune: the face must be reachable from the resting fist; pinned by the boss test)*). The face's weak rectangle lies
76-105 px over the floor (`MANGROVE_FACE_RISE` 70), clear of the HUD [G35]; a jump strike from the floor beside the
trunk reaches it too. The upper hand sweeps along the upper ledge's top and sinks 12 px onto its edge to rest: a hero
crouching on the lower ledge stays under the sweep. Hits (any weapon 1):
Beginner 4 / 3 / 3, Expert 6 / 5 / 5.
- **Stage 1 Face**: the fist punches along the floor in bursts of 3-8 (`Sim.rng`; the first burst 8), each punch
  after a **10-tick draw-back** with a creak, 3 ticks out and 1 back; each punch shakes (4), shoves the hero 2 px and
  drops one leaf from 150 px above him (up to 124 px aside, falling 1-4 px/tick while swaying, a touch costs a bone,
  at most 5). Between bursts the fist rests 64-184 ticks: the resting fist is the springboard to the face.
- **Stage 2 Upper hand**: a second root sweeps the upper ledge after a **14-tick ledge shake**, then **rests there
  44 ticks**: high-strike it from the lower ledge.
- **Stage 3 Fist**: bursts of 8; burrowing bugs (`lizard` diggers) rise around the hero, every shake sends them down;
  the fist is hittable **20 ticks after each burst** while stuck in the floor.
- **Co-op**: stages 1 and 2 merge - the face and the hand must both be struck within the twin window (13.9.3) by two
  different heroes (one hero's two hits never twin; slot-bound, so the window is 24 Beginner / 12 Expert, not capped
  by the measured solo minimum of 10 [G34]): a twin hit counts one; Beginner 5, Expert 7 twin hits *(tune)*, then
  stage 3 with Beginner 3, Expert 6. An **active** hero standing on the resting fist **pins** it (no punches) until it
  flings him off (launch -160) after **66 ticks**; an idle body pins nothing [G33]. Stage 3: the knuckle armour turns
  to the nearer active hero every tick, so the wrist must be struck from the far side (side by the hero's x against
  the stuck fist's centre). In `w6_l2b_coop` the lower ledge's last two cells (cols 7-8) are hatch cells (rotten
  bark): a striker crouches through them onto the stuck fist's wrist side; the solo chamber is unchanged.

**Inkjaw, the Grotto Squid** (`bosses/squid`, `w7_l2b`). Arena: one screen; deadly water across the floor; rock
islands at cols 2-5, 8-11, 14-17 (surface row 9; the outer islands may reach cols 1 / 18, closing the 1-cell water
strips at the walls [G52]); one-way root ledges at row 6 over the gaps. It surfaces in gap 6-7
or 12-13 (`Sim.rng`); **22 ticks of bubbles** mark which. Weak point: the top of its head (a high strike from an
island edge, a bounce from a ledge, a throw). hp: Beginner 150 (6), Expert 225 (9); co-op 187 / 280 [R8].
- **Phase 1 Surface and Slam**: a tentacle rises over the island next to its target for **12 ticks** (its shadow
  marks the landing), slams (a boss-body box for 4 ticks, shake 4); the squid stays up **44 ticks**, then dives for
  66 ticks *(tune)*.
- **Phase 2 Ink** (60-30 %): adds a spit - jaws open **10 ticks**, then an arcing ink blob (`xvel` +/-48 towards the
  target, `yvel` -96, +8 per tick *(tune)*); a blob costs a heart and 6 bones **and dims the screen to the night
  palette for 66 ticks**; the surfacing bubbles stay bright.
- **Phase 3 Whirlpool** (< 30 %, red): the middle island sinks (`~`); two log rafts (width 3) ride a current that
  reverses every 132 ticks *(tune)*; the squid surfaces beside a raft and slams it (it dips and shakes, nobody falls
  off). Fight from the raft; paddle with a forward strike on the water side.
- **Co-op Tentacle Lock**: on surfacing it crosses **two tentacles** over its head (the head is armoured); a strike
  makes a tentacle flinch **16 ticks (Expert) / 24 (Beginner)**; the head opens for **33 ticks** only while both
  flinch, struck by **two different heroes** - one hero on each flanking island (the count-in plays while an active
  hero stands at each side). Slot-bound, so the flinch is not capped by the measured solo minimum of 20 [G34].
  Phase 3 keeps the solo rule: one paddles, the other strikes.
- **Defeat**: the fire-starter is thrown from over the island nearest to where it died; a sunk key item comes back on
  standable ground [G52].
- Clearing it ends a Beginner run (13.1 expert wall).

**The Twin Idols** (`bosses/idols`, `w8_l2b`, Expert; the Colossus archetype 6.3, 1 per hit). Arena: one fixed screen
(an 11-row lock whose last row is the floor); the Moon Idol (left, mirrored) and the Sun Idol (right) sit in the
walls at floor level - their open jaws (95 px over the feet) lie 65 px under the view's top, clear of the HUD [G35]; a
2-row altar block at cols 8-11; a ledge at row 6 in front of each idol's jaws. Hits: **7 per idol** (14; the bar in two halves); co-op 8 per idol.
- One shared brain. The **Awake** idol (eyes glow) spits rocks with the Colossus rules (6.3: idle loop 84, 30, 30, 20,
  20; jaws open 10 ticks ahead; rocks 32-96 v16, bounce twice, roll 10 ticks, crumble). The **Asleep** idol is
  armoured and drops sandstone masonry over the hero (a **14-tick rattle**, the stalactite rules).
- Every 4th counted hit both **rage 40 ticks** (armoured; the Colossus rage timings), then they swap roles.
- Weak point: the open jaws of the awake idol - a high strike from its ledge, a forward strike when it slams low, any
  thrown weapon. The club works here.
- **Co-op Twin Hit**: both wake together, each spits at the active hero on its own half (an idol whose half holds no
  active hero sleeps, armoured [G33]); an idol cracks (the hit counts) only if its twin is struck within the twin window
  **by the other hero** (one hero's axe and club never twin; 24 Beginner / 12 Expert, slot-bound [G34]); a rage swaps
  their targets.

**The Storm Roc** (`bosses/roc`, `w9_l2b`, Expert). Arena: one 20 x 12 screen at the spire top: a stick nest (one-way,
cols 6-13, row 8), a stone floor at row 10 with a 4-cell runway each side, two drop clouds at row 5. hp: phases 1-2
take 200 (8 club hits; co-op 250), phase 3 takes **3 glider dives**. Weak point: the head (phases 1-2).
- **Phase 1 Gale**: perches on the nest rim, raises its wings **14 ticks** (whoosh) and beats: wind of 48 left or
  right *(tune)* for **66 ticks** (P-C.6; crouch to brace); feathers fall like leaves (a touch costs a bone). Its head
  is reachable from the nest by a high strike or a bounce. After 3 gusts it takes off.
- **Phase 2 Dive**: circles the hero (the harrier loop), **screeches 14 ticks**, dives at his position (the dart
  rule); a miss **buries its beak** in the nest or floor for **44 ticks**: head open. After 3 dives it perches again
  (phase 1) until its hp is at or below a third.
- **Phase 3 Storm** (hp <= 1/3): lightning strikes cells that a darkening cloud marks **22 ticks** ahead (struck nest
  sticks burn 66 ticks); the Roc climbs above the view and comes down only to cruise and swoop - it cruises over one
  runway half (never over the nest nor in the boss bar's columns; the halves alternate, the right one first), its feet
  about 61 px over the floor, so its back's top stays 55 px under the view's top [G46] with the arena's 11-row lock (a
  taller lock lowers the cruise as far as the view can sink); its wing brushes a hero on the nest's end cells (a bone). **The hang-glider lies on the nest** (it reappears after a death): take off along a runway (24 ticks at speed, 13.2 / 8.4), climb on lift and
  **dive onto its back**; the dive ladder (1 000 / 5 000 / 10 000) counts the three hits; the third brings it down.
- Defeat: it tumbles into the clouds and coughs up the fire-starter onto the nest.
- **Co-op**: phase 1 - a wing shield faces the nearer active hero (head hits from that side glance): a pincer on the
  nest [G33].
  Phase 2 **Snatch** - a dive that touches its target grabs him and climbs at 2 px/tick; the partner frees him by
  hitting its head within **73 ticks**, else the grabbed hero becomes an egg (no life lost); a rescue stuns the Roc
  **66 ticks**. Phase 3 **Pilot and Spotter** - each hero has his own glider on the nest; after each dive the Roc
  tumbles low over the nest for **24 ticks**, and a dive counts only if a hero other than the pilot strikes its tail
  feathers within those 24 ticks (slot-bound [G34]).

**The Rival Chieftains, Gorm and Gulla** (`bosses/chieftain` x2, `mate=<name>`, `w9_l3`, final boss).
- **On hero physics**: each chieftain is a boss shell around the hero simulation (PHYSICS 4-11, hero boxes), fed every
  tick by a `HeroBot` input producer with its own seeded `SimRng` (13.10.10). They walk, jump, strike and bounce as we
  do. Their club boxes and stomps hit heroes as a boss body (one bone, knock-back); their bodies are not solid. Every
  attack is announced by a "HUP!" pop-up and a **14-tick crouch**. **Fallback** (PLAN cut 8): a Brute-style state
  machine on the same sprite with the same phases.
- Arena: one screen around the pyre; the Great Roast on an altar 3 tiles up at the centre; ledges 3 rows up (no
  see-saw, no plates) and nothing standable higher; the camera locks the 11 rows over the floor (the floor's top 4 px
  show at the view's bottom) under a crown of rock 6 rows over the floor (a chieftain at the centre stands in the boss bar's
  columns: on a 3-row altar his body's top is 77 px under the view's top [G35]). **Energy: 4 pips each** (1 counted hit = 1 pip, hit cooldown per chieftain); two rows
  of pips.
- **P1 Raiders** (4-3 pips): flank, strike and stomp heads; they pick the hero farther from the view centre (the
  `lone` rule of 13.9.5).
- **P2 Totem Chief** (from 2 pips each): they stack (the bottom walks, the top strikes high) and the bottom **bats**
  the curled top across the arena at a hero (P-C.11); a batted chief lies **dazed 30 ticks** where he lands.
- **P3 Roast Thieves** (last pip each): one grabs the roast and runs for the Roc perch at the arena edge; he cannot
  strike while carrying; a hit makes him drop it; at the perch the roast returns to the altar and he regains one pip.
- **Egg revive**: a chieftain knocked to 0 becomes an egg; his mate hatches it with a head bounce unless the heroes
  smash it first (3 hits). The fight is won when both are out (smashed, or at 0 with no mate left to hatch them).
- **Solo**: they tag in one at a time; the other waits on the pyre and tags in with half energy (2 pips) when the
  active one falls; a knocked-out chieftain's egg hatches after **132 ticks** unless smashed (he then waits on the
  pyre with 1 pip). In P2 the waiting chief comes down only to bat his mate at the hero: the dazed chieftain is the
  solo opening.
- **Co-op**: both fight at once; their egg hatches in **66 ticks**, so one hero smashes the egg while the other keeps
  the surviving chieftain away: a smash counts only while an **active** hero other than the smasher stands within
  64 px of the mate (or of the mate's egg) on both axes [G33].
- Defeat: they hand back the Great Roast (the trophy) -> `ending_b`.

**Co-op forms of the 1.0 bosses** (`w2_l2b_coop`, `w4_l2b_coop` only; solo forms are exactly 1.0):
- **The Brute** (hp 64 -> 80): targets whoever hit him last (before the first hit: the nearest active hero [G33]); his
  arm guard faces his target and blocks throws and head strikes from that side, so only the partner reaches the head
  (a Totem Ride rider with a forward strike; a ride needs an active carrier). Below 50 %:
  the **Grab** - after a **22-tick chest beat** his hands open **8 ticks**; a target within 30 px in front is squeezed
  (one bone per 44 ticks); alternating Left / Right shortens the hold by 4 ticks per press; a partner's head hit frees
  him and staggers the Brute 19 ticks. The ground pound shakes both (crouch to stand firm). Grabs are off on Beginner
  (13.9.10). From the very high jump's take-off to its landing the head takes no counted hit (a throw glances as off
  the arm guard), and after the lethal blow none at all: the 1.0 leaps carry it out of the den's view, so it is no
  weak point there [G56]. (Every boss: no weak point after its lethal blow.)
- **The Wall Colossus** (hp 24 -> 30): a stone **visor** covers the face; two stone plates at the hall's sides lift it
  while an active hero stands on the plate whose chain glows (the co-op hall keeps the face clear of the HUD [G35]); rocks are spat at the plate holder, stalactites rattle over the
  thrower. Thrown weapons only, as in 1.0; the co-op checkpoint places **two** axes. Each rage (the 1st hit and every
  4th) moves the live chain to the other plate. The fairness tests of `test_enemies_colossus.gd` run per hero.

### 13.7 Cave Paintings

- `items/painting index=0..29`: indices 0-19 are the Book II levels in the order of 13.2 (one per level, at the same
  index in its solo and co-op file, possibly hidden elsewhere); 20-29 lie behind an x2 secret in the Book I co-op files
  of 1-1, 1-2, 2-1, 2-2, 3-1, 3-1b, 3-2, 4-1, 4-2, Way Home. Each pays 5 000 points and counts for completion; found
  ones are saved per profile across modes (`Save.add_painting`); one found before shows as an outline and pays its
  points again without counting twice.
- Never on a main path: behind `$` walls, up spear steps, at vine tops, inside a big spot, behind x2 gates.
- **Unlocks** (Far Shore map slab and the Versus menu): 5 = Mesa Rodeo arena; 10 = eight loincloth patterns for P1-P4;
  15 = variants Big Bounce, Lights Out, Giant Rain; 20 = Cloud Top arena; 25 = variant Spear Party and a golden
  loincloth palette; 30 = the mural that ends The Long Raft Home. Options > Versus > "Unlock everything" exists.

### 13.8 Audio

Every new cue and music context is the pick of DESIGN.md F.2 (CC0 only; loudness by the 1.0 rules); event and
context names are fixed in `Sfx` / `AudioTable` (PLAN P0.3). Gameplay emits a cue for: swap, spear stick, vine grab,
splash / raft, geyser bubble and spout, tar step, egg down, hatch, Shoulder Hop / Totem Ride, curl, bat hit, brace,
plate, drum (and the window count-in), see-saw, boulder / pulley, daze, Chomper bite, cookpot bank, crate drop, Hot
Rock fuse, lightning bolt (`Sfx.LIGHTNING_STRIKE`), the round gong (`Sfx.ROUND_GONG`). Boss music plays while a boss
bar shows (a boss pushes its own `boss_*` context; `zones/arena music=` only overrides); versus has its own lobby,
battle and sudden-death contexts. The level context of every Book II stage is fixed in LEVEL_DESIGN 15.2; a
sub-stage keeps its first half's music, a co-op file its solo file's.

### 13.9 Co-op: the tribe

#### 13.9.1 Players, joining, controls

- **Exactly 2 players**, local. P1 keeps the original yellow loincloth, P2 is blue; colours by a per-slot 16 x 1 LUT
  (no baked sheets). A "P1" / "P2" tag and a colour arrow show at stage start and whenever the heroes overlap.
- **Join** ("the Tribe Gathering"): Title > Co-op opens a panel with two slots: press Jump on any device to take one;
  Left / Right picks a colour; hold Strike 24 ticks = ready. A lost pad pauses ("Reconnect, or continue alone").
  Joining or leaving is possible from the panel, the world map or the pause menu; mid-stage it restarts the stage at
  the checkpoint in the other layout (13.1).
- **Keyboard layouts** (bound by physical key, rebindable per slot; DESIGN.md D.11): Classic WASD + numpad (the versus
  default, offered first: P1 W A S D, jump Space, **strike Left Ctrl** [G12], swap E, look Q; P2 Num 8 4 5 6, jump
  Num 0, strike Num Enter, swap Num +, look Num `.`), Two hands each (laptops), One hand each. Left Shift is not a P1
  key: with NumLock on, Windows wraps a numpad key pressed while Shift is held in synthetic Shift events. The key test
  holds Left + Jump + Strike + Swap for both players at once (ghosting check); NumLock off works for P2's numpad (the
  physical keys arrive; no aliases). Left + Right together is Look in every layout. In a party slot 0 uses its
  generated `p1_*` actions.
- Pads: one per slot, the solo layout (A jump, X / B strike, Y / RB look, LB swap, Start pause); rumble only on that
  slot's pad. Touch: one touch player on phones and tablets; the tablet **table mode** is cut for 2.0 (PLAN cut 2,
  applied): an experimental prototype hidden from the release menus [G37].
- **Emote**: a double tap of Look shows a bubble over the hero ("!", "?", heart, angry).

#### 13.9.2 Shared and per-hero state, lives, eggs

| Shared (the tribe) | Per hero |
|---|---|
| score (tribe score, extra lives every 250 000), lives (one pool, starting like solo: the counter shows 2), letters, feast kit (any hero's three pieces feast both), checkpoint, exit unlock, completion, secrets, paintings | hearts, bones, hand + belt, glider, "since last death" tally list, stats for the medals |

- Bones picked up at full energy fly to the partner when he is below full energy. A heart item a full hero touches
  stays for the partner.
- **Tribe lives**: a life is lost only on a **team wipe** (both heroes down, eggs or dead at once); then both respawn
  at the checkpoint, spread by slot, and the world resets as in solo (P-C.12). A single down never resets the world,
  a boss or a gate.
- **Egg Hatch** (P-C.12): a downed hero plays the death toss and floats in an egg (`egg_kid` roll frames in his
  colour) that drifts after his partner; its owner nudges it Left / Right. The partner hatches it with any hit, a
  thrown weapon or a head bounce; a checkpoint touched by either hero hatches every egg. The hatched hero gets 2 hearts
  (Beginner) / 1 (Expert) and 44 ticks of blinking. Expert: an egg not hatched within 243 ticks flies to the
  checkpoint and waits. **The egg scouts**: every unopened hidden spot whose cell lies within 32 px of an egg's box
  twinkles (a four-point star) while the egg is there. An egg never touches plates, items or enemies, so it can never
  solve a gate.
- **An egg is no springboard** [G1]: the head bounce that hatches an egg is -64 (10 px) with or without Up.
- **The idle partner** [G33] (P-C.10): a hatched hero is **idle** while his own player has given no input for 243
  ticks (10 s), or none since he entered the level (a level start, a join, a restart at the checkpoint). Only his own
  input resets it (an egg's nudge counts); a hatch, carry, bump, launch, respawn, checkpoint or team wipe never does.
  After 243 quiet ticks he is drawn dozing ("Zzz") until his next input. An idle hero counts for **no co-op rule**:
  no weight on plates and pulley lifts, no see-saw launch, no x2 tablet light, no count-in, no bait or "nearer hero"
  for a trait or a boss, no brace, no lee, no duo move - a hero passes through his head, Up held or not (no Shoulder
  Hop, no Totem Ride; a ride ends when carrier or rider becomes idle). He is still a body: enemies may target and hurt
  him, he is launched, rides platforms, goes down and is leashed. The **active** heroes are the hatched ones that are
  not idle (a Shoulder Hop also needs a partner who gave input since he last hatched). One player can never use an egg or an idle partner as a step, a
  weight or a bait; a human who must wait long on a plate crouches (Down held is input).
- **Flies** (7.9): the flies a hero gathers circle him (one swarm per hero); the water bucket washes only the hero
  who took it.
- **Voluntary egg**: Down + Look held 24 ticks. **Helper mode** (Options): P2 cannot be hurt by enemies (pits and
  liquids still egg him); gates unchanged.
- **Team exit**: the stage ends when both heroes touch the exit totem (an egg anywhere on the view counts as present,
  and so does an idle hero on the view [G33]: an absent partner never blocks the exit). Checkpoints stay physical: any
  hatched hero's touch activates one and hatches every egg.
- **Gates**: Down on a gate takes both heroes; a partner more than one view (320 px across or 176 px up / down) away
  arrives as an egg; eggs travel as eggs.
- **Camera**: one shared paging camera (P-C.13): the view edges are walls; the vertical follow uses the grounded hero,
  and while both heroes stand with their feet at most 9 rows apart the view keeps both whole; holding Look claims it;
  a hero off the view (above or below it too, while his partner holds it) gets an edge arrow with a stone countdown and
  becomes an egg after 121 ticks (Beginner) / 73 (Expert). No zoom, no split screen.

#### 13.9.3 Duo moves and windows

| Move | Rule (P-C.10, P-C.11) | Easy role / hard role |
|---|---|---|
| **Shoulder Hop** | land on an **active** partner's head with Up held: bounce -224, feet reach 140 px over the floor | stand still / one held jump |
| **Totem Ride** | land on an **active** partner without Up (not curled, not mounted): ride his head; his jumps are halved; the rider strikes (high strike 61-77 px over the floor), jumps off (Up; a jump timed 1-5 ticks after the carrier's reaches 8+ tiles - measured against the carrier's rise, so his halved hop never sheds the rider) or drops (Down + Jump) | walk / strike |
| **Batter Up** | Down + Swap curls a hero (up to 66 ticks); the partner's strike launches him: forward line drive 153 px, high lob 120 px up, low grounder 192 px, charged x1.5; a line drive or a lob stops where it lands; the ball breaks `$` blocks, opens spots it touches, knocks enemies with hp < 50 | curl / aim and strike |
| **Brace Wall** | two crouching active heroes within 16 px stop a `heavy` dead and daze it 44 ticks with its head open; a lone croucher is trampled | crouch / crouch and line up |
| **Egg Hatch** | 13.9.2 | be carried / strike the egg |

- **Windows** (twin drums, bonds, split halves, twin boss hits, the tentacle flinch): **24 ticks on Beginner, 12 on
  Expert**, and never longer than the measured solo minimum minus 4 ticks: `window = min(24 B / 12 E, solo_min - 4)`
  per placed gate or record (`tests/test_coop_gates.gd` measures `solo_min` with the single-hero search). A record
  sets its own cap with `window=<ticks>` (bond, split; a daze is slot-bound [G47]): effective = `min(difficulty value, window)`; a bond uses
  the smallest `window` of its members; one value serves both difficulties [G2]. A rule that needs **two different
  heroes' own hits** (Old Mangrove's twin, Inkjaw's flinches, the Twin Idols' twin, the Roc's tail strike) is exempt
  from the `solo_min - 4` cap: no single player meets it at any speed, so its window is the difficulty value [G34].
  Every window has an audible count-in (three blips 8 ticks apart, then "go"), counting **active** heroes only [G33]:
  drums while an active hero stands within 40 px of every drum; a bond whose members all live, or the two halves of a
  split, while each member has an active hero within 48 px on both axes and those are not all one hero - once per
  arrival (again only after the heroes left and came back), silent once the window is open. Nothing needs two inputs on the same tick. The values are kept for phase-3 content; the pair
  playtests of P4.5 may only shorten them [G3].
- Every launch moves at most 18 px/tick or teleports with `notify_hero_teleported` (the doze rule, P-C.15).

#### 13.9.4 Enemies in co-op: the base rules

- **Target** = the nearest hatched hero (`|dx| + |dy|`, ties -> P1), sticky for `TARGET_HOLD_TICKS` = 22 *(tune)*
  unless that hero stops being hatched; an idle hero may be chased and hurt (he is a body). Every **trait** rule that
  asks where the heroes are (the shield's nearer hero, a keeper's bait, `lone`'s pair, a count-in, the Shaman's and
  the Mimic's nearer hero) counts only active heroes [G33]. Despawn only when far from both heroes. Zone spawners (types 0, 10, 11, 12)
  alternate between the heroes inside their zone (slot order); their `max` is x1.5 (rounded down). The active cap stays 12. Each
  hero's stolen heart bursts as 6 bones for the team (an enemy that hurt both releases 12). Enemies reset only on a
  team wipe. Hit points are unchanged (two heroes already deal double damage).
- Per archetype:

| Archetype | Co-op base behaviour | Traits used in layouts |
|---|---|---|
| 0 Dropper | drops land beside each hero in turn | `bond` (pairs, one by each hero), `split` (tar blobs) |
| 1 Decoration | none | - |
| 2 Dangler | unchanged; a hero's club box over its thread (4 px wide, attach point to body) cuts it: the dangler falls off, harmless, and is gone without points until a team wipe (the Snatcher bat keeps its thread) | `grab` (Snatcher bat) |
| 3 Lurker | drops when any hero is in range, chases the nearest | `leech` |
| 4 Swinger | unchanged | `bond` (pairs swinging in opposition, rare) |
| 5 Stinger | dives at its target | `lone`, `grab` (Snatcher gull / pterodactyl) |
| 6 Harrier | loops relative to its target, re-targets every loop | `bond` (pairs circling in opposite directions, one reachable only from a Totem Ride), `lone` |
| 7 Dart | aims at the nearest hero at launch | none |
| 8 Hopper | hops at its target | `daze` (Raptor) |
| 9 Walker / Flyer | unchanged | `shell` (Shellback turtle), `bond` (flyer pairs on opposite ledges) |
| 10 Digger | rises beside each hero in turn | `lone` |
| 11 Leaper | leaps at its target | `bond` (twin leapers from two pits) |
| 12 Charger | runs at its target | `heavy` (Bull Rex), `lone` |
| Snapper | bites the nearest; the bite tests every hero (the 1.0 rules otherwise; the bait-and-bite stem rule is dropped [G10]) | `bond` (twin rattlers) |
| 13 Roller | rolls at the nearest | `bond` pairs on two slopes |
| 14 Guard | turn delay 33 as solo | `shell` (turns every tick: the Shellback guard) |
| 15 Mimic | bites the nearer; its back faces the far hero | none |

#### 13.9.5 Co-op traits

Every enemy record of a `kind = coop` file may carry one trait: `coop=shell|bond|daze|heavy|lone|grab|leech|split`
(plus `bond=<name>` for `bond`). The validator refuses traits in other files. In every co-op stage at least a third
of the enemy records carry a trait, and every enemy guarding a main-path chokepoint does.

| Trait | Rule | Why one hero cannot do it |
|---|---|---|
| `shell` | the shield faces the nearer active hero **every tick** (no active hero near: the nearest hatched one); a hit from that side (striker's x, or a projectile flying into the shield; `abs(dx) < 4` counts as front) glances with a clank and a spark; back hits count | one hero is always in front |
| `bond` | records with the same `bond=<name>`: when one dies a window opens; every other record of the bond must die before it closes, or the dead ones **regrow** at their anchors with full hp (a 22-tick regrow, harmless) | targets are out of one hero's reach within the window, and no thrown special hits two members in one throw [G36] |
| `daze` | when any active hero within 48 px (and 32 px vertically) starts a strike, it hops away from him (`xvel` +/-64, `yvel` -96 *(tune)*); it hops over a thrown weapon coming at it within 48 px (`yvel` -128); a head bounce **dazes** it 14 ticks (Beginner) / 12 (Expert); only a dazed one can be hurt, and only by a hero of another slot than the one whose bounce dazed it (his hits glance; slot-bound, so not capped by the solo minimum [G47]); other hits glance | the bouncer cannot hurt his own daze |
| `heavy` | front hits glance; it is stopped only by a **Brace Wall** (P-C.10), which dazes it 44 ticks with its head open (hits from any side count while dazed) | needs two braced bodies |
| `lone` | while the two active heroes are within 64 px of each other on both axes it keeps away (it does not dive, charge or rise; flyers circle 32 px wider); otherwise it targets the hero farther from the view centre (ties -> the higher slot) [R9]. Off on Beginner (plain targeting) | staying together is the defence |
| `grab` | a hero who touches it from below (his feet below its feet point) or whom it dives onto is **seized** instead of hurt: he cannot move or strike, and it carries him towards its perch (`perch=c,r`, a pit-side cell) at 1 px/tick, dropping him there; the partner frees him with any hit on it (the hit counts; the freed hero falls with 44 ticks of immunity) | a grabbed hero cannot strike |
| `leech` | it lands on a hero's back (instead of hurting) and drains one bone per 44 ticks; only the partner's weapon reaches it (the host's own boxes skip it); alone it falls off after 220 ticks | a hero cannot hit his own back |
| `split` | the first hit splits it (no damage) into two halves of `hp` 0 that run apart at 48 v16 for 22 ticks *(tune)*, then go on at their archetype's own speed in the run's direction (the spawned half wears the other palette and shows `squash`); both must die within the window, or the dead half regrows next to the living one and they merge back into the whole. The falling tar blobs of 6-1 are `enemies/dropper coop=split skin=slime` | the halves run in opposite directions |

- Keeper groups: enemies may carry `keeper=<name>` (a group tag; a door `objects/column trigger=keepers:<name>` opens
  when every enemy of the group is dead) [R10].

#### 13.9.6 Co-op-only enemies

Presets (archetype + trait + skin), each its own scene, only in `*_coop.lvl` files:

| Id | Archetype + trait | Skin | Where |
|---|---|---|---|
| `enemies/shellback` | Guard + `shell` (Book I variant `skin=turtle_b`: Walker + `shell`) | RPG `reptile`, armour bone | ruins, canyon; Book I jungle, ice, keep |
| `enemies/raptor` | Hopper + `daze` | `mini_rex_b` (dizzy frames 16-19) | jungle, ice, ruins, fen |
| `enemies/snatcher` | Dangler or Stinger + `grab` | `bat_b` / `pterodactyl_b` as a gull | caves, coast, sky |
| `enemies/leech` | Lurker + `leech` | Ninja `Larva` 2x | caves, fen, sea caves |
| `enemies/bull_rex` | Charger + `heavy` | `rex_b` | ice lake, gorge, canyon |
| `enemies/tar_splitter` | Dropper / Walker + `split` | RPG `slime` (two palettes = two halves) | fen, Feast Land D (honey skin) |
| `enemies/shaman` | new patroller | `characters/npc/dragon-man` | keep, ruins |

**Shaman** [G11]: patrols his platform at 48 v16 *(tune)*, fleeing from the nearer active hero within 64 px at about his
height (32 px vertically) by turning at once; at the edge of his platform he turns (never walks off); cornered while
fleeing (his limit, a wall or the edge right ahead) he hops over that hero (45 px high, 4 px per tick, harmless to
touch during the hop) and runs on; a walking hero (80 v16) still catches him from behind, so a Shaman alone is no
gate (two pin him sooner; his shielded keepers carry a hall). **Bone shield**: every other enemy
within 64 px on both axes, in a co-op party only (a party of one meets a plain patroller); Shamans and bosses are
never shielded; a bone floats over each shielded enemy, all its hits glance, and it holds through the tick he dies
in. hp [25], score index 5.

**As built** [G11]: the Book I Shellback (`skin=turtle|turtle_b`) is a Walker with the shell trait (walker speed 32
and score, no Guard clock); the bone sheet stays a Guard. **Bull Rex** wakes by the view (not the edge rusher's
trigger), runs at its target at `speed` [64], turns round when it overran its target by 48 px or at a wall; never
one-shot. **Snatcher**: `kind=stinger` after a carry flies back to where it seized the hero, then home to its anchor
(2 px/tick) and hovers; `kind=dangler` takes up its thread at its line again. **Tar Splitter** is the walker form.

#### 13.9.7 Co-op objects

| Id | Rule |
|---|---|
| `objects/plate name= count=1\|2 mode=hold\|timed:<ticks>\|latch w=<cells>` | `w` [2] cells of floor, anchored at its **left** cell and covering `w` cells to the right; **weight** = active heroes whose feet are over its cells, on its floor or up to 8 px above it and not rising (a screen shake does not release it) + 2 for a mount driven by an active hero + 2 for a heave boulder resting on it; enemies, eggs, idle heroes and a riderless mount weigh 0 [G33]. Pressed while weight >= `count`; `timed:T` stays pressed T ticks after the weight leaves (a stone clock shows it); `latch` stays pressed for good. It sinks 2 px (drawing) and clicks |
| `objects/column ... rise_while=<plate>[,...]` / `sink_while=` | the 1.0 column driven by plates: while **all** listed plates are pressed it rises (sinks) 1 tile per 4 ticks up to `rise`, and returns at the same rate when released; `shake` defaults to 0 for plate columns. A plate stands **8+ tiles** from its door. One door cannot be opened from both sides: a leapfrog uses two doors in two corridors [G9]. **Door rule**: a driven block (plates, keepers, drums) whose next cell in its direction of travel is solid is a door - the cells it leaves become air (a portcullis rising into a ceiling slot, a slab sinking into the floor); a block moving into air keeps the 1.0 pillar rule. A returning door never moves into an active hero: it waits; an idle hero is pushed out of its way, unharmed - an idle body is no doorstop [G53] |
| `objects/column trigger=keepers:<name>` | the **keeper door**: rises once when every enemy with `keeper=<name>` is dead. Keepers carry `shell`, `bond` or `daze` and stand in a hall **4 rows high** (the Guard and Shellback art is 54 px tall) [G4]; a keeper door is the bottom cells of a wall that continues above the hall, `rise` = 4 |
| `objects/column trigger=drums:<bond>`, `objects/gate needs=<bond>` | opened by a drum bond [R10] |
| `objects/drum bond=<name>` | a hittable (every weapon box, thrown weapon or ball, at most one hit per 6 ticks): the first hit lights it and opens the window; when every drum of the bond is lit within it, the bond succeeds for good (its column rises, its gate unlocks); otherwise all go dark and can be tried again |
| `objects/seesaw len=<cells> [facing]` | [5]; two end platforms 16 px apart in height around the pivot (the fulcrum at the anchor's feet point, the plank `len * 8` px each side, `facing` names the high end [r]; the low end lies 1 px over the floor, the high end one row higher). Two heroes on one see-saw play ping-pong (the launched hero's landing flips it back); an idle hero's landing flips it and launches nobody [G33]. A body landing on the **high end** (`yvel >= 16` at contact) flips it within 2 ticks and launches whoever stands on the low end with `max(-(yvel + 32) - (64 if hard landing), -288)` (6.5 hard landing; P-C.17 table: 1 tile -128, 4 tiles -272, 5+ tiles -288 = 171 px); a weaker result than -64 only lifts him. Enemies on the low end are thrown off the same way |
| `objects/boulder_heavy` | a 2 x 2-cell solid tile mover; it moves 1 tile once two active heroes have pushed the same side (grounded, walking into it) on 6 ticks in a row; it falls 1 tile per 2 ticks when unsupported (never onto an active hero: it waits; an idle one is pushed aside [G53]); weight 2 on a plate; it plugs a geyser vent it rests on (P-C.6) |
| `objects/pulley a=<platform> b=<platform> range=<rows>` | two linked sprite platforms; weight as plates; the heavier side sinks 2 px/tick and the other rises the same, each at most `range` [3] rows from its start; equal weights do not move |
| `objects/flower_pot` | stands on a ledge edge; a strike pushes it in the strike's direction (the striker's facing; a thrown weapon's or ball's flight); it slides to its floor's edge or a wall, falls at 2 px/tick and becomes a permanent `objects/spring` (-224) where it lands, 1-2 cells beyond the ledge's face (lost in a liquid, pit or spikes: back on its ledge after a team wipe; a landed spring stays through team wipes). **It reaches 6 rows from the floor it takes root on** (a 105 px rise from the spring's top, 10 px over the floor: 19 px to spare) [G6]. Every boost ledge holds a drop gift: a rolled vine or a flower pot |
| `objects/x2_tablet gate=<name> far=<col>,<row> [secret]` | a stone tablet carved with two cavemen marks every co-op gate and co-op secret (a sign skin, no HUD); `far` is the cell beyond the gate that the solo search must fail to reach (LEVEL_DESIGN 15.7.6); it lights its marks once an active hero stood in `far`, and stays lit |
| `objects/hero_start slot=2` | P2's start; ignored in solo |
| `objects/exit`, `objects/gate` | team exit and team gates (13.9.2) |

#### 13.9.8 Book I in co-op, Feast Lands, the ending

- Each shipped stage has `levels/<id>_coop.lvl` (`kind = coop`, `coop_of`, `coop_base_hash`); the gates, trait
  enemies and x2 secrets of each are DESIGN.md D.9; Book II co-op signatures D.10. Co-op files carry no passwords;
  specials lie in pairs where the solo file places one.
- **Feast Lands** (A-E in co-op): team exit only. A giant roast spot pays its giant bonus only when its last hit comes
  within the window after a hit by the other hero (otherwise it just puffs). **Relay Bounce**: the bounce counter of
  3.3 rises past 11 only on a bounce by the other hero than the previous one: 12-13 pay x10, 14-15 pay x12 (max 15).
- The Way Home adds its lookout gate; The Long Raft Home is one raft for two.

#### 13.9.9 HUD and tally

- HUD: P1's panel top-left exactly as today; P2's hearts and belt icon mirrored top-right; tribe lives and score where
  they are today; letters as today; edge arrows with a stone countdown for a hero off the view.
- Tally: one tribe score; the companion catches each hero's items in his own pile and hands out medals - Most Food,
  Best Bounce Chain, Hatchling (eggs hatched), Slugger (Batter Up launches), Strongman (plates held, boulders pushed),
  Clumsiest (as a joke). Option "Rival score": two scores on the same stages.

#### 13.9.10 Difficulty

| Setting | Co-op Beginner | Co-op Expert |
|---|---|---|
| Twin windows | 24 ticks (or solo minimum - 4) | 12 ticks (or solo minimum - 4) |
| Raptor daze | 14 ticks (slot-bound [G47]) | 12 ticks |
| Leash before the egg | 121 ticks | 73 ticks |
| Hatch hearts | 2 | 1 |
| Unhatched egg | follows forever | returns to the checkpoint after 243 ticks |
| `lone` trait | off (plain targeting) | on |
| Boss grabs (Brute Grab, Roc Snatch) | off | on |
| Boost ledges | 8 tiles [G39] | 8 tiles |
| Idle partner (counts for nothing) | 243 ticks without input | 243 ticks without input |

The Beginner wall is unchanged in both books.

### 13.10 Versus

#### 13.10.1 Pillars and match flow

- Same device, **2-4 players**; bots fill empty slots. Nobody sits out long, everyone sees the score (it stacks on
  the heroes' heads), the leader is the biggest target (no hidden rubber-banding). Rounds of 60-90 s, matches of 5-8
  minutes, **Rematch** is the default button. Versus runs only in arena files with its own rule tables
  (`VersusTuning`); campaign values are untouched.
- **Flow**: lobby (four slots, press Jump on any device; colour and loincloth pattern; team toggle; Add CPU with its
  level; handicap card; hold Strike = ready) -> rules (mode, preset, rounds, round time, crates, weapons, variants;
  whoever pressed Start controls them; the last rules are remembered) -> arena (thumbnails, Random, Party Mix; locked
  arenas show their painting count) -> round ("3, 2, 1, GRUB!", the heroes burst out of spots; a gong ends it) ->
  deciding moment (the last 3 s, Grub Stack: the biggest steal, replayed at half speed from the input log and a start
  snapshot; skippable) -> scoreboard (about 5 s; drumsticks onto each player's plate) -> next round or results.
- **Readability**: P1 yellow, P2 blue, P3 pink, P4 green (white on jungle arenas); loincloth patterns; P1-P4 tags and
  arrows at round start and whenever heroes overlap; hit sparks in the attacker's colour; four corner panels
  (portrait, stack or hearts, held special); the round sundial top centre; a crown on the leader; bubbles for heroes
  above the view. Look doubles as the emote / taunt.
- **Controls**: keyboard for two players at most (the 13.9.1 layouts; classic WASD + numpad is the versus default,
  proven by a scripted two-player match driven only by those keys); pads for up to four; touch for one player on a
  phone or a tablet (the two-player table mode is a hidden prototype in 2.0 [G37]).

#### 13.10.2 Combat kit

Existing attacks (forward strike damaging from tick 5, high strike as anti-air, low strike, stomp, the crouch-charged
strike, thrown specials) with the versus rules of P-C.14: hits knock away (+/-64, -128), a charged hit launches,
clang, deflect, the stomp ladder 1-2-3-4-6-8 with an 8-tick squash (a stomp is a landing: a hero standing on a tier
does not stomp a head that rises into his feet [G15]), the curl stance (and batting a curled rival into a hazard),
12 stunned + 30 immune ticks, hit-stop 2 (4), body bump, 48-tick spawn shield. Thrown specials that hit a wall lie in
front of its face, never inside it [G17]. Everyone starts every round with the club; specials come from pterodactyl
crates straight onto the belt and are temporary. Spawns rotate every round (the physics is left-right asymmetric).

**Currency per mode**: Grub Stack - stack units; Last Caveman Standing - hearts; Hot Rock - none (a hit only passes
the ember); Clubball - none (a hit only knocks back).

#### 13.10.3 Grub Stack (the flagship)

"Everything you grab stacks on your head. Biggest stack at the gong wins."
- 2-4 players, free-for-all or 2v2; club for everyone, an empty head; no hearts - nobody dies from hits; a hazard
  (pit, liquid, sudden death) costs a respawn after 48 ticks.
- **The stack** is an integer count of food units: small food 1, big food 2, treasure 5, giant bonus 10 (by the item's
  class, 3.2 / ASSET_MANIFEST). It shows as a wobbling tower of pictures; above 8 pictures the tower regroups into
  10s, 5s and 1s so it never leaves the screen. The **crown** sits on the tallest stack (ties: no crown).
- **Weight**: 10+ units slows walking to 64 v16; 20+ to 48 and jump impulses to 3/4 *(tune)* (P-C.14).
- **Losing food** (stack `s`, integer division): a hit knocks **1 + s/5** units off; a charged hit **1 + s/2** and the
  launch; a thrown special **1 + s/8**; a **stomp steals** the stomp ladder value (1, 2, 3, 4, 6, 8) straight onto the
  stomper's stack (the pieces arc head to head); a hazard spills everything (floor(s/2) bursts out, the rest is
  lost). Spilled units fly out as dropped food items (4.5 physics, 198 ticks, blinking), split greedily into 10s, 5s
  and 1s; at most the free dropped-item slots appear. The victim cannot pick anything up during his 12 stunned ticks.
  The handicap guard multiplies every spill (x0.5 / x1 / x1.5, rounded down, at least 1).
- **The cookpot** (`objects/cookpot`; one per arena, two on 4-player arenas, on contested ground): a hero crouching
  inside it **banks one unit per 4 ticks** from his stack; banked units are safe; a stomp on a banking hero steals
  double. **Final score = banked + stack.** 2v2: one shared pot per team.
- **Food sources**: visible hidden spots that refill **364 ticks** (15 s) after they are emptied (they sparkle 49
  ticks before); one big spot (3 hits by anyone) whose giant bonus falls from 7 rows up and **bonks** the head it lands
  on (the 4.5 bounce, plus a 12-tick daze *(tune)*); pterodactyl crates every **486 ticks** (20 s) on marked lanes
  (`objects/crate_lane`; a shadow 22 ticks ahead): **one crate holds all of** food, a special, one cutlery piece and
  sometimes a skull or a grenade (`Sim.rng`, round seed; the referee's per-mode table: Last Caveman Standing a heart
  instead of food, Hot Rock no food). One crate per period over all lanes, on a free lane; a lane holds one crate at a
  time; it falls onto the first floor under the lane's top row inside its rect; one hit opens it; its specials are
  temporary [G18].
- **Items**: *Feast* (fork + knife + spoon, each from crates, dropped on a hit): 194 ticks in which your touch knocks
  3 units off anyone and hits cannot touch you; a shake warns 7 ticks before the end. *Skull*: whoever picks it up
  spills everything (all of it bursts out). *Grenade*: every rival spills 5 (or all he has).
- **Feast Rush**: the last 364 ticks - a bell, every spot refills at once, a second giant bonus drops, the **pot lids
  close** (no banking).
- **Round**: 2 185 ticks (90 s; 1 457 with 2 players); first to 3 round wins. A tie: the **Golden Drumstick** falls in
  the middle; first to grab it wins.
- **Teams (2v2)**: shared pot, separate stacks; a teammate's head is a free springboard; friendly hits only bump.

#### 13.10.4 Last Caveman Standing

3 hearts each; a hit costs 1 heart, a charged hit 2 and the launch, a stomp 1 and the squash, a hazard knocks him
out. A hero at 0 hearts is out (death toss). **A lost heart bursts into 6 bones** anyone can grab (6 bones heal a
heart, max 3). Last one alive wins the round; first to 5. At 1 457 ticks (60 s) the arena's themed **sudden death**
starts (13.10.9). Eliminated players ride **Grudge Pterodactyls** along row 1 (4 px/tick, Left / Right) and drop a rock
with Strike (one per 73 ticks, a 10-tick squawk first; a rock dazes 12 ticks and costs no heart). Option *Stock*:
3 lives with a respawn after 48 ticks.

#### 13.10.5 Hot Rock

A glowing ember sticks to one player (picked by `Sim.rng` 66 ticks after the round starts *(tune)*) and passes to
the other hero on any body touch, hit or stomp; whoever passed it cannot receive it back for 44 ticks; its holder
walks up to 96 v16 (he is the faster one) [R7]. The fuse is 291-486 ticks (12-20 s, `Sim.rng`, round seed) and
bubbles faster in the last 73; then the holder pops (the death toss) and is out; after 66 ticks *(tune)* the ember
picks a new holder among the rest with a new fuse. Last one standing wins; first to 3.

#### 13.10.6 Clubball

1v1, 2v1 or 2v2 on Coconut Cove, club only (no crates).
- **The coconut** (`objects/coconut`, box 16 x 16): gravity 16 (cap 192); on a floor it bounces with
  `yvel = -(yvel * 3) >> 2` while `yvel >= 32`, else it rolls, losing 2 v16 per tick *(tune)*; gravity also runs on
  the bounce tick, so the bounces die down within six [G19]; walls and ceilings reflect it at 3/4; a coconut landing
  on a head it does not knock down bounces up at 3/4 (at least -96), an immune hero's head too. Order per tick and
  the prediction the bots share: P-C.14.
- **Shots**: only a **front** box shoots; it sets its velocity by the strike - forward **drive** (+/-144, -128), high
  **lob** (+/-32, -240), low **grounder** (+/-96 along the floor), charged **smash** x3/2; boxes on the ball in one
  tick add up (opposite drives cancel; nobody wins by slot order); one swing shoots it at most once (front boxes on
  consecutive ticks are one swing) - and every shot within 44 ticks of the previous one (anyone's) adds 16 to
  `|xvel|`, up to 192 (12 px/tick): rallies escalate; a faster shot (a smash, 216) keeps its own speed. Every
  component stays within +/-288. The striker is not knocked down by his own shot for 8 ticks. A curled hero flying as
  a ball passes his velocity to the coconut once per flight (credited to his batter); he flies on.
- A coconut faster than 8 px/tick on either axis that touches a hero knocks him down (12 stunned ticks, no
  immunity) and bounces back at half speed; a slower one passes through bodies.
- **Goals** (`zones/goal team=1|2`): a goal mouth 3 rows high at each end; the coconut's centre inside the other
  team's goal scores; it is reset to the drop point 66 ticks later, heroes back at their spawns. First to 5 goals, or
  the most after 4 370 ticks (3 min); a tie plays on with a "golden coconut" (next goal wins).

#### 13.10.7 Second-wave modes (not at launch)

King of the Feast (carry the giant roast to fill 20 counts of 22 ticks; the carrier cannot strike and walks at most
64 v16; a hit drops it; your count never falls back below 5 left), Letter Snatch (8-12 visible spots, five hold
G-R-U-B-S shuffled; held letters float over your head; a hit drops your newest; hold all five for 44 ticks), Egg
Heist (2v2: carry a giant egg to your nest ledge; it cracks after a fall of 6+ rows; a mother rex chases a carrier
who holds it 194 ticks).

#### 13.10.8 Presets, variants, handicap, Party Mix

- **Presets**: *Classic* (club only, no crates), *Feast* (default: crates every 486 ticks), *Mayhem* (crates every 194
  ticks, skull spots, a random variant per round).
- **Variants** *(tune all)*: Hammer Time (everyone holds the hammer; the club on the belt), Axe Rain (crates hold only
  axes, every 194 ticks), Big Bounce (head bounces with Up give -288), One-Bonk (every hit costs everything: a heart
  becomes the last heart, a stack spills all), Slippery (every floor `ice = 2`), Lights Out (night palette, heroes
  glow), Gusty (alternating wind 32 / -32 every 66 ticks), Giant Rain (a giant bonus falls every 364 ticks), Spear
  Party (everyone starts with a spear on the belt that never runs out).
- **Handicap card**: hearts 1-5 (LCS), stack guard x0.5 / x1 / x1.5 (Grub Stack), or Auto (a player two rounds behind
  gets a leaf shield that absorbs one hit).
- **Party Mix** picks mode and arena per round.

#### 13.10.9 Arenas and sudden deaths

Ten single-screen arenas, 8 at launch (DESIGN.md E.5; building rules LEVEL_DESIGN 15.8): Totem Ring (jungle, wrap
left-right, Grub Stack), Echo Hollow (cave, wrap top-bottom, Hot Rock), Floe Rink (ice, open sides, LCS), Cinder Pit
(volcano, LCS), Tar Pulleys (swamp, Grub Stack), Coconut Cove (coast, Clubball), Sky Picnic (Feast Land, wrap
top-bottom, **no deaths**, Hot Rock / Grub Stack), Colossus Hall (keep, Grub Stack and LCS only; the neutral Colossus
takes no hits and spits at the crowned leader every 243 ticks with its jaws open 10 ticks ahead - in LCS at the hero
with the most hearts, no spit on a tie [G43]), Mesa Rodeo (5 paintings; Chomper starts penned and is
released at every multiple of 728 round ticks while he waits penned, after a 22-tick rumble - his picture shakes and
the quake cue plays, no screen shake; once out he waits for a rider and stays out; his rider's bite bites rivals
(Grub Stack: spill 3); a stomp on the rider unseats him - thrown off, no stun - and Chomper stays out for the
stomper; only a hit sends him back to his pen for the next release [G20]), Cloud Top (20 paintings). Mesa Rodeo and
Cloud Top are built only once the other eight are done and green [G37]. Arenas are 20 x 12 cells (LEVEL_DESIGN 15.8);
the Totem Ring, Cinder Pit, Echo Hollow and Coconut Cove as built at G2 are drawn in DESIGN.md E.5 [G14] [G31]; the
modes each arena supports are its `modes` meta key. Arena signatures run by the referee (phase 3 [G43]; LEVEL_DESIGN
15.2 / 15.8): `dark_pulse` (night for the first 73 ticks of every period, heroes glow), `regrow` (a broken `$` block
grows back, a ghost first), `ember_lane` (embers down a lane, each glowing at its start first; a touch is an arena
hit), an arena `wind` synced to the round, neutral enemies (springboards that never hurt or die), ring-out goal mouths
outside Clubball, and Colossus Hall's neutral statue.

| Sudden death | Rule (every one telegraphed 10+ ticks ahead) *(tune all)* |
|---|---|
| Stampede (jungle) | a charger runs along the floor every 73 ticks; dust 22 ticks ahead |
| Cave-in (cave) | blocks fall from the top row inward, one per 11 ticks, each shadowed 11 ticks ahead |
| Whiteout (ice) | the wind grows by 8 every 121 ticks, alternating sides |
| Lava rise / Tar rise (volcano / swamp) | a deadly band rises 1 row per 44 ticks with a rumble (the rising-tide code) |
| High tide (coast) | the rising-tide code, `rise_speed` 8 |
| Syrup flood (feast) | a band rising 1 row per 44 ticks up to row 7 that only slows (the tar rules), never kills |
| Stalactite storm (keep) | a stalactite over a random column every 22 ticks, 14-tick rattle |
| Rockslide (canyon) | rocks from the mesa rims every 33 ticks, dust 14 ticks ahead |
| Lightning (sky) | a marked cell every 33 ticks, 22 ticks ahead |

They start at 1 457 ticks in Last Caveman Standing and are an event toggle in the other modes.

#### 13.10.10 Bots

- A bot is an input producer (`InputSlot.BOT`): each tick it writes the flags a human would, decided from the
  previous tick's state, with its own `SimRng` seeded from the match seed and its slot; it never draws from `Sim.rng`
  and never knows what a spot or crate contains. A bot match replays tick for tick and runs headless as a test.
- **Navigation**: a graph per arena baked offline (`tools/bots/`): nodes are standable spans; links are walk, drop,
  hatch, jumps with k held ticks (from `PHYSICS_REFERENCE.json`), spring, geyser (timed), see-saw, pulley, wrap; every
  link is verified by simulating the real hero; lifts and floes are moving nodes.
- **Goals**, re-chosen every 6 ticks by utility: food, spots, the cookpot (bank when tall), the leader, the ember (flee
  or pass), the coconut (predict its landing with the deterministic ball physics and stand goal-side), safety. Combat
  micro-rules: high strike against a jumper above within 26 px, crouch-charge against an approaching rival, stomp a
  croucher, deflect specials, bat curled rivals towards hazards.
- **Levels**: Rookie (reacts in 10 ticks, never charges or deflects), **Hunter** (default; 6 ticks; stomps and
  charges), Chief (3 ticks; stomp chains; deflects half the time; never frame-perfect). Difficulty is reaction and
  decisions, never cheating. The same `HeroBot` drives the Rival Chieftains.

#### 13.10.11 Results and awards

Results: the heroes painted on a cave wall in victory poses; the companion hands out 1-3 awards each - Leaning Tower
(tallest stack), Pickpocket (most stolen by stomps), Glutton (most eaten), Butterfingers (most dropped), Chain Gang
(longest stomp chain), Clang Master, Slugger (most curled rivals batted), Home Run (longest Clubball shot), Hot Potato,
Lava Lover, Head Case (bonked by a giant bonus), Comeback Caveman, Pacifist. **Rematch** is the default button.

### 13.11 The *(tune)* register

Every starting value below is used from phase 1 on. Co-op windows, dazes and boss timings were to be tuned in the
pair playtests at gate G1; G1 passed on its automated criteria without them, so **every value below stays at its
start for phase-3 content** and the mixed-skill pair playtests move to P4.5 [G3] (no G1 measurement asked for a
change; player-A's egg bounce, -64, is the only value G1 changed [G1]); windows can only shrink below
`solo_min - 4`, never exceed it. Versus values are tuned with the headless bot soak
(1 000 seeded rounds per mode: round length, win rate per spawn within +/-15 %) and human playtests. The lead designer
records every change in DESIGN.md, then here and in PHYSICS Appendix C.

| Value | Start | Tuned by |
|---|---|---|
| Swap lock-out | 8 ticks | belt playtests: no double swaps from one press |
| Tar hop impulse ticks / tar air cap | 2 / 32 v16 | 6-1 playtests: tar must feel slow, a 1-tile step out must work |
| Geyser period, deadly vent box, lightning bolt | 88 / 24 x 64 / 4 ticks | stage playtests |
| Vine re-grab lock | 12 ticks | vine-to-vine leaps |
| Totem drop lock, egg drift (2 / 6 px), egg nudge | 12 / 2-6 / 1 | P4.5 pair playtests (unchanged at G1) |
| Curl box, all Batter Up velocities | 24 x 20; P-C.11 | P4.5: gap and lob gates (no Batter Up gate in the G1 slice) |
| Twin windows / daze | 24 B / 12 E; 14 B / 12 E | P4.5 pair playtests; per record `window=`; a timing window always `<= solo_min - 4` (slot-bound rules - the daze [G47], twin boss hits - are not capped) |
| Lee reach | 64 px downwind, 16 px vertical | 3-1b / 9-2 co-op playtests |
| `TARGET_HOLD_TICKS` | 22 | co-op enemy feel |
| Roller walk / range / uncurl, Guard patrol, Mimic daze, Shaman speed, split run | 32 v16, 4 rows, 154; 24 v16; 22; 48 v16; 48 v16 for 22 | enemy tests and playtests |
| Mount food bonus, wild rex pace | 500; 16 v16 | 6-1 playtests |
| Boss fill-ins (Tusker idles and arcs, Mangrove launch and co-op stage hits, Inkjaw dive, blob arc and current, Roc wind) | 13.6 | each boss test (telegraphs, escapability, no stun-lock, club beats the solo form) |
| Versus weight, body bump, teammate bump, giant bonk daze | P-C.14; 12 ticks | bot soak, playtests |
| Hot Rock first pick and re-pick delay | 66 / 66 ticks | playtests |
| Coconut roll loss | 2 v16 per tick | Clubball bot tests |
| Variants and sudden-death cadences | 13.10.8-13.10.9 | playtests |

---

## 14. Items still `[INFERRED]`

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

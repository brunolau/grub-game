# LEVEL_DESIGN.md - building levels for Club & Grub

A practical guide for level designers. The binding definition of the format is `docs/ARCHITECTURE.md` section 7
(and the entity catalogue in section 6.2); this guide explains it by example and adds the numbers you need to
build fair jumps. Owner: world module.

Contents: 1 Workflow - 2 A level by example - 3 `[meta]` - 4 `[tiles]`: the legend - 5 Auto-tiling - 6 Placing
entities - 7 Entity catalogue - 8 Props - 9 Zones - 10 Secrets, checkpoints, exits, bosses - 11 `[backwall]` and
`[overrides]` - 12 Hero metrics in tiles - 13 What the player sees (camera) - 14 Checklist.

---

## 1. Workflow

1. Copy `levels/test_example.lvl` (or a showcase level) to `levels/<id>.lvl`. Campaign ids are `w<world>_l<stage>`
   (`w1_l1`), sub-stages `w2_l2b`, bonus stages `bonus_a`..`bonus_c`, the ending `ending`. Set `id` to the same
   name. The game finds the file by itself; there is no list to edit.
2. Draw the map in `[tiles]`, place entities with `[legend]` letters or `[entities]` lines.
3. Validate (every save):

   ```
   bash .tools/gd.sh script res://tools/validate_levels.gd                          all levels
   bash .tools/gd.sh script res://tools/validate_levels.gd -- levels/w1_l1.lvl      one file
   bash .tools/gd.sh script res://tools/validate_levels.gd -- --strict              warnings fail too
   ```

   Output is `file:line: error: message` (or `warning:`); exit code 0 means no errors. Errors make a level
   unplayable or wrong; warnings are legal but suspicious (unknown parameters, unused legend letters, entities
   whose scene is not built yet, a checkpoint floating in the air).
4. Preview the whole level as one picture:

   ```
   bash .tools/gd.sh script res://tools/world_render_level.gd -- w1_l1                 build/level_previews/w1_l1.png
   bash .tools/gd.sh script res://tools/world_render_level.gd -- w1_l1 --collision     + w1_l1_collision.png
   bash .tools/gd.sh script res://tools/world_render_level.gd -- --all --scale=0.5
   ```

   The collision picture colours solid cells red, one-way floors yellow, hatches orange, slopes along their
   surface, deadly cells magenta, invisible walls blue, ice cyan, draws entity boxes yellow, the hero start green
   and zone / camera-lock rectangles cyan with their names. `--difficulty=expert` shows the Expert spawn set.
5. Look at it in the game:

   ```
   bash .tools/gd.sh play --autoplay=w1_l1 --inputs=60:R,12:RU,40:R --shots=12 --fast
   bash .tools/gd.sh raw --path . -s res://tools/world_tour.gd -- --level=w1_l1              camera tour
   bash .tools/gd.sh raw --path . -s res://tools/world_tour.gd -- --level=w1_l1 --size=2400x1080
   ```

   The autoplay harness plays an input script (`ticks:KEYS`, keys `L R U D F K`) and writes screenshots to
   `build/screenshots/<level>/`. The camera tour moves the camera over the whole level without a hero and saves a
   screenshot at every stop (`--size=2400x1080` shows what a wide phone sees).

`levels/test_integration.lvl` is a complete, compact level that uses nearly everything (slopes, one-way floors,
water, every hidden-spot kind, containers, a spring, both platform kinds, spikes, eight enemies, a secret, a
checkpoint and an exit in a lower cavern); `levels/test_integration_boss.lvl` shows a working Brute arena (a walled
one-screen pit the hero drops into, a locked exit the Brute's fire-starter opens). Both are played through by
`tools/autoplay/full_loop.flow`. Sign and hint texts are translation keys: add them to `locale/en.po`.

The showcase levels `levels/test_world_showcase*.lvl` (jungle, cave, ice, volcano, volcano shaft, feast, village)
contain every terrain piece, slope, liquid, back wall and parallax set; `levels/test_world_zones.lvl` uses every
zone; `levels/test_world_parallax_loop.lvl` is a long run for checking the backdrop. Open them next to your level
when in doubt.

---

## 2. A level by example

```
# comment lines start with '#'. Blank lines are ignored. There are NO inline comments.
[meta]
format = 1
id = w1_l1
name = "Vine Bridges"
kind = main
order = 10
world = 1
stage = 1
biome = jungle
terrain_a = jungle/terrain_grass
terrain_b = jungle/terrain
background = jungle
music = level_jungle
password_beginner = "K4TZ"
password_expert = "7BRQ"

[legend]
T = enemies/walker skin=turtle left=-3 right=3
C = objects/checkpoint
E = objects/exit
f = items/food index=3
b = props/jungle/bush_big

[tiles]
....................................
..........f.f.......................
.........-----......................
....................................
.................../##\.............
.@..b....T......../####\.....C....E.
####################################
####################################

[entities]
zones/secret 10 0 name=treetop rect=9,0,6,3
items/heart 18.5 3
props/jungle/vine_a 27 0

[backwall]
21 2 4 2 set=a deco=25

[overrides]
22 4 a 3
```

(This map is too small to be valid - a level needs at least 20 x 12 tiles - but it shows every part.)

Rules of the text:

- Sections: `[meta]`, `[legend]`, `[tiles]`, `[entities]`, `[backwall]`, `[overrides]`, in any order. A repeated
  section is joined to the first. Unknown sections are ignored with a warning.
- Outside `[tiles]` lines are trimmed. Inside `[tiles]` every character is a cell: a space is air, `#` is ground
  (not a comment!), nothing is trimmed, completely empty lines are skipped.
- Values: `true` / `false`, integers, decimals with a point, `"quoted text"`, otherwise plain text. Lists have no
  spaces: `rect=9,0,6,3`. Parameters are `key=value` tokens; a bare word is a flag (`expert` means `expert=true`).
  Values never contain spaces.

---

## 3. `[meta]` - the header

| Key | Values | Default | What it does |
|---|---|---|---|
| `format` | `1` | required | file format version |
| `id` | lower_snake_case | required | must equal the file name |
| `name` | text | the id | shown in the level intro |
| `kind` | `main` `sub` `bonus` `ending` `test` | `main` | `sub` = linked second half (no map stop); `test` = developer level |
| `order` | 10, 20, ... | - | world-map order of `main` levels |
| `world`, `stage` | int | 0 | world map and intro |
| `biome` | `jungle` `cave` `ice` `volcano` `feast` `village` | `jungle` | default terrain, background and music; debris and block look |
| `terrain_a`, `terrain_b` | atlas under `assets/tiles` without `.png` | by biome / `terrain_a` | the sets `#` / `%` (and `-` / `=`) draw from |
| `ice_a`, `ice_b` | 0..3 | 0 | slipperiness of set A / B floors (3 = almost no grip) |
| `liquid` | `water` `lava` `ice_water` | `water` | look of `~` cells |
| `background` | `jungle` `cave` `ice` `volcano` `volcano_shaft` `feast` `none` | by biome | parallax set |
| `music` | music context | by biome | `level_jungle`, `level_cave`, `level_ice`, `level_volcano`, `level_shaft`, `level_grotto`, `bonus`, `secret`, `ending`, ... |
| `time` | seconds | 0 | time limit; 0 = none (the original has none); running out costs a life |
| `password_beginner`, `password_expert` | 4 characters 0-9 A-Z | "" | level codes; unique across all levels |
| `next` | level id | "" | explicit successor; empty = next `main` level by `order` (for a `sub` level: the `main` level after the one whose `next` leads to it; its tally result counts for that main level) |
| `tally` | bool | true | false = first half of a linked pair (exit leads to `next` without a tally) |
| `bonus` | level id | "" | bonus stage the `items/warp` of this level leads to |
| `min_difficulty` | `beginner` `expert` | `beginner` | `expert` hides the level from Beginner runs |
| `scroll` | `normal` `vertical` `autoscroll` | `normal` | `vertical` = no horizontal follow; `autoscroll` = the view sinks 1 px per tick |
| `low_band` | bool | false | alternative vertical camera band (rows 5..8 instead of 4..9) |
| `home_row` | row | -1 | the camera never sinks below this row while the hero is on the main floor above it |
| `fast_vscroll` | bool | true unless `background = none` | faster vertical camera (for screens where the backdrop shows) |
| `dark` | bool | false | the level starts in the night palette |
| `wind` | `tick:value,...` | "" | blizzard: wind value from that tick on, e.g. `0:0,200:24,600:48` |
| `bonus_tier` | 0..2 | world - 1 | bonus table of `random` contents |
| `author`, `notes` | text | - | ignored |

Defaults by biome: jungle -> `jungle/terrain_grass`, background `jungle`, music `level_jungle`; cave ->
`cave/terrain`, `cave`, `level_cave`; ice -> `ice/terrain`, `ice`, `level_ice`; volcano -> `volcano/terrain`,
`volcano`, `level_volcano`; feast -> `feast/terrain`, `feast`, `bonus`; village -> `jungle/terrain_grass`,
`jungle`, `ending`.

**Difficulty variants.** Any key may get `.beginner` or `.expert`: `time.expert = 120`, `wind.expert = 0:32`.
The variant wins in that mode.

Terrain atlases: `jungle/terrain_grass` (light meadow), `jungle/terrain` (deep green), `cave/terrain` (violet rock),
`cave/terrain_stone` (tan stone), `ice/terrain` (snow on ice), `ice/terrain_rock` (frost-blue rock),
`volcano/terrain` (orange rock), `volcano/terrain_obsidian` (dark keep), `feast/terrain` (sponge cake),
`feast/terrain_icing` (strawberry icing), `feast/terrain_biscuit` (biscuit / sand).

---

## 4. `[tiles]` - the legend

One character = one cell of 16 x 16 (game) pixels. Row 0 is the top. Rows may be shorter than the longest row
(the rest is air). A level is 20..256 cells wide and 12..192 high.

| Char | Meaning | Floor | Wall | Ceiling | Drawn as |
|---|---|---|---|---|---|
| `.` or space | air | - | - | - | nothing (backdrop) |
| `#` | ground, set A | yes | yes | yes | auto-tiled terrain of `terrain_a` |
| `%` | ground, set B | yes | yes | yes | auto-tiled terrain of `terrain_b` |
| `;` | invisible solid | yes | yes | yes | nothing (under breakable blocks) |
| `-` | one-way platform, set A | from above | - | - | thin platform, upper half of the cell |
| `=` | one-way platform, set B | from above | - | - | thin platform of set B |
| `_` | hatch | yes, but crouching drops through | - | - | thin platform of set A |
| `/` | 45 degree slope rising to the right | surface | - | - | slope of the set below |
| `\` | 45 degree slope rising to the left | surface | - | - | |
| `1` `2` | gentle slope rising to the right: low half, high half | surface | - | - | |
| `3` `4` | gentle slope rising to the left: high half, low half | surface | - | - | |
| `^` | floor spikes | deadly | - | - | spikes in the lower half of the cell |
| `!` | ceiling spikes | - | - | deadly | spikes in the upper half |
| `~` | liquid (`liquid` key) | deadly | deadly | - | animated surface, body below, in FRONT of actors |
| `\|` | invisible wall | - | yes | - | nothing (arena limits) |
| `+` | invisible kill cell | deadly | deadly | - | nothing |
| `@` | hero start (exactly one) | air | | | feet at the bottom-centre of the cell |
| `?` | small hidden spot (3 items) in ground | ground | | | looks like `#` |
| `*` | big hidden spot (giant bonus after 3 hits) | ground | | | looks like `#` |
| `$` | breakable block (2 hits) | invisible solid | | | the block sprite |
| letters | entities of `[legend]` | air, or `tile=` | | | the entity |

Collision facts worth knowing:

- Every floor is one-way from below unless the cell is also a ceiling (`#`, `%`, `;`). The hero jumps up through
  `-`, `=`, `_` and slopes.
- Walls are only felt in the row just above the feet: the hero is 2 rows tall, but a 1-row-high gap is enough to
  walk through. Do not build 1-row tunnels unless that squeeze is the point - he is drawn overlapping the ceiling.
- A ceiling 2 rows above the floor makes jumping impossible there (instant head bump); 3 rows allows a 16 px hop.
- Liquids and spikes kill at once. Falling more than one cell below the last row is a pit death; a `zones/kill`
  makes a pit anywhere.
- The hero's x stays within 8 px of the left edge and 8 px of the right edge. Close both ends with ground or `|`
  unless a pit is wanted.

---

## 5. Auto-tiling - what gets drawn

You only write `#` and `%`; the game picks the picture of every cell from its neighbours (ARCHITECTURE.md 7.4):
surface tiles where air is above (with left / right corners at open sides), wall edges where air is beside,
undersides where air is below, fill inside (with a detail variant here and there), and the matching "under slope"
piece below every slope. Outside the map counts as ground, so ground that touches the map edge continues without
an edge.

Do:

- Put every slope directly on `#` or `%` (the validator insists). The slope takes the set of the cell below.
- Build a hill as `./##\.` on one row over solid ground, a gentle ramp as `.12##34.`; the ground under them gets
  the right "under slope" pieces automatically.
- Stack one-way platforms from `-` (set A) or `=` (set B); the left and right end pieces are chosen by the
  neighbours. A platform that touches ground continues into it.
- Keep the two terrain sets apart (an island of `%` in a world of `#`, or a different area). Where they touch the
  join is visible because the pictures differ.
- Use `[overrides]` for pillar caps (3 / 4 on a 2-cell-wide pillar top), hanging fringes under ledges (30-33),
  framed blocks (7), inset panels (15), small rubble (34).

Don't:

- Don't put slopes on air, on platforms or on other slopes.
- Don't put `^` on air: spikes sit on the ground of the cell below (a dip in the floor: `##^^##` over `######`).
- Don't fill rooms with `;` to make walls - nothing is drawn there. Use `#`/`%`, and `;` only under breakable
  blocks.
- Don't expect `-` and `=` to join into one platform with matching pictures: each set draws its own ends.
- Don't place 1-cell-thick floating ground in many places: it uses the top piece only (no underside) and looks thin;
  2 rows show surface and underside.

---

## 6. Placing entities

**Legend letters** (`[legend]`): `<char> = <entity id> [key=value ...] [flag ...]`. The character is a letter
(`A-Z`, `a-z`) or `?`, `*`, `$` (which have built-in meanings you may redefine). Every occurrence in `[tiles]`
spawns the entity with its **feet at the bottom-centre of that cell** - so put an enemy letter in the air cell
just above the floor it stands on. The cell is air, unless the entry says `tile=<fixed char>` (a hidden spot
inside the ground: `tile=#`).

**Free positions** (`[entities]`): `<entity id> <col> <row> [key=value ...]`. `col` / `row` may be decimals
(`18.5 2` = half a cell to the right). Use this for zones, things between cells, and anything with a rectangle or
a name.

Parameters every entity understands:

| Parameter | Meaning |
|---|---|
| `name=<id>` | unique name (gates, markers, arenas); `Game.level.find_named()` finds it |
| `facing=l` / `facing=r` | initial facing |
| `expert` / `beginner` | spawn only in that mode |
| `dx=<px>`, `dy=<px>` | fine offset in game pixels (1 cell = 16) |
| `tile=<char>` | legend only: the cell's tile (`tile=#`, `tile=;`) |

Limits per level (and per mode): 150 enemies, 70 placed items, 80 hittables (hidden spots, breakable blocks,
containers), 16 platforms. The validator counts them.

Entities must not stand inside solid cells (the validator checks the cell just above the feet point); hidden spots,
breakable blocks, columns and the Wall Colossus are the exceptions.

---

## 7. Entity catalogue

Units: `ticks` (about 24 per second; 22 = one "designer second"), `px` = game pixels (1 cell = 16), `v16` =
1/16 px per tick, `tiles`. Defaults in brackets.

### Enemies

All enemies take `skin=<sheet>` (e.g. `turtle_b`), `hp` [25] and `score` 0..11 [per type]. A club hit is 25 and
the enemy dies when hp drops **below** 0: hp 0..24 = one hit, 25..49 = two, 50..74 = three.

| Id | What it does | Default skin | Parameters |
|---|---|---|---|
| `enemies/dropper` | falls from the sky inside a trigger zone, then walks | `egg_kid` | `zone=c,r,w,h` [10 tiles around], `pause` [44], `speed` v16 [32], `max` alive [2] |
| `enemies/dangler` | yo-yo on a thread | `bat` | `depth` px [48], `speed` px/tick [2] |
| `enemies/lurker` | hangs on the ceiling, drops, then chases | `insect` | `range` tiles [4], `pause` [22] |
| `enemies/swinger` | pendulum | `bat_b` | `radius` px [40] |
| `enemies/stinger` | hovers, dives at the hero | `insect` | `range` tiles [6], `speed` px/tick [3] |
| `enemies/harrier` | clever flyer | `pterodactyl` | `range` tiles [8] |
| `enemies/dart` | kamikaze diver, does not come back | `pterodactyl_b` | `range` tiles [8], `speed` px/tick [4] |
| `enemies/hopper` | hops towards the hero | `mini_rex` | `range` tiles [6], `pause` [22], `jump_x` px/tick [3], `jump_y` px/tick [8] |
| `enemies/walker` | patrols the ground, follows slopes | `turtle` | `left` [-3], `right` [3] tiles from its cell, `speed` v16 [32] |
| `enemies/flyer` | patrols in the air | `bat` | `left`, `right`, `speed` as walker |
| `enemies/digger` | burrows out of the ground in a zone | `lizard` | `zone=c,r,w,h`, `pause` [44], `speed` v16 [32] |
| `enemies/leaper` | leaps in arcs (out of pits) | `dragon` | `speed` v16 [48], `pause` [66] |
| `enemies/charger` | rushes to the edge, does not come back | `rival` | `speed` v16 [64] |
| `enemies/snapper` | stationary biter | `plant` | `range` px [42] |
| `enemies/decoration` | harmless scenery that moves | - | `prop=<biome>/<name>` |

Enemies sleep until their cell comes within about 2 cells of the view, at most 12 are awake at once, and they all
come back when the hero respawns (except darts and chargers that already left).

### Bosses

| Id | Parameters |
|---|---|
| `bosses/brute` | `arena=<zone name>`, `left`, `right` (absolute columns), `hp` [64], `speed` 0..4 [2], `enraged`, `drops` [`fire_starter`] |
| `bosses/colossus` | `arena`, `hp` [24], `drops` [`trophy,trophy,trophy,trophy`]; only thrown weapons hurt it |

### Items

All items take `dropped`, `fan=<n>`, `points=<n>` (override). Placed items with points count for the completion
percentage and are paid again at the tally.

| Id | Parameters | Effect |
|---|---|---|
| `items/food` | `index` 0..47 | 100 - 1 000 points (table in ASSET_MANIFEST 7) |
| `items/treasure` | `index` 0..15 | 2 000 (0-7), 5 000 (8-12), 8 000 (13-15) |
| `items/giant_bonus` | `index` 0..6 | 10 000 - 60 000 |
| `items/letter` | `index` 0..4 (G R U B S) | bonus word; all five drop the 100 000 jackpot |
| `items/jackpot` | - | 100 000 |
| `items/feast_piece` | `index` 0..2 | three pieces = feast mode (enemies die on touch) |
| `items/fire_starter` | - | unlocks a locked exit |
| `items/heart`, `items/one_up`, `items/bone` | - | +1 heart (stays when full), +1 life, +1 bone (6 = 1 heart) |
| `items/skull` | - | bad: all energy scattered as bones |
| `items/kill_all`, `items/grenade` | - | every enemy on screen dies / bursts into items; come back after a death |
| `items/weapon` | `kind=club\|hammer\|axe\|boomerang` | weapon; comes back after a death |
| `items/glider` | - | hang-glider; comes back after a death |
| `items/water_bucket` | - | food score, clears the flies |
| `items/warp` | - | to the `bonus` stage (in a bonus stage: back, ending the source level) |
| `items/trophy` | - | ends the game (normally dropped by the final boss) |
| `items/code_stone` | `index` 0..3 | shows one character of the level's password |
| `items/random_bonus` | `tier` 0..2 [level `bonus_tier`] | a random bonus item |

**Contents** (`contents=` of spots and containers, `drops=` of bosses): item names with an optional index or kind,
joined by commas: `food:3,treasure:8,heart,weapon:axe`. `giant` = `giant_bonus`, `random` = a random bonus.

### Objects

| Id | Parameters |
|---|---|
| `objects/checkpoint` | - (touching it stores the respawn point; the last one touched counts) |
| `objects/exit` | `locked` [false] (needs the fire-starter), `kind=exit\|warp\|trophy` [exit] |
| `objects/hidden_spot` | `kind=small\|big` [small]; small: `count` 1..64 [3] items, one per hit; big: `hits` 1..128 [3], then a giant bonus falls from 112 px above; `contents` [random]; `look=plain\|inset\|block` [plain] for ground cells; `prop=<biome>/<name>` look for air cells |
| `objects/breakable_block` | `hits` 1..64 [2], `skin=auto\|dirt\|cave\|ice\|obsidian` [by biome], `contents` [none] |
| `objects/container` | `skin=barrel\|crate\|pot` [crate], `contents` [random], `hits` [1] |
| `objects/platform` | `dir` 0..7 [2] (0 up, clockwise: 2 right, 4 down, 6 left), `speed` px/tick [2], `travel` ticks [44], `mode=always\|ride` [always], `skin=wood\|ice\|stone\|small` [by biome] |
| `objects/drop_platform` | `delay` ticks [0], `skin` |
| `objects/column` | `size=w,h` tiles (the bottom-left cell is the anchor), `rise` tiles, `trigger=c,r,w,h`, `shake` [7] |
| `objects/gate` | `name`, `dest=<gate or marker name>`, `lock=c,r` (camera cell of a one-screen room), `skin=arch\|hole\|none` [arch]; Down while standing on it; not with the glider |
| `objects/marker` | `name` (invisible gate destination) |
| `objects/spring` | `power` v16 [-224] |
| `objects/sign` | `text=<translation key>` |
| `objects/npc` | `kind=elder\|kid\|warrior` [elder], `turn` [true], `facing`: a friendly villager (ending stage) that plays its idle loop and turns to face the hero while he is near (`turn=false` keeps `facing`); harmless, not hittable, counted nowhere |

Hidden spots that touch each other (8 neighbours) open together and each counts for the completion percentage.
Walls of secret passages are columns of `$`.

---

## 8. Props (scenery)

`props/<biome>/<name>` draws a picture from `assets/tiles/<biome>/props/<name>.png` (list in ASSET_MANIFEST 10.4):
no collision, no gameplay. Parameters: `layer=back|front` [back] (front props hide the hero, like foliage), `flip`
(mirror). Props are anchored at the bottom-centre of their cell. The ceiling pieces `stalactite`, `drips`,
`drip_cap`, `icicle`, `vine_a`, `vine_b`, `moss_fringe` hang from the TOP of their cell: place them in the air
cell just below the ceiling. A tree is `tree_trunk` at the floor plus `tree_canopy_*` 1.25 rows higher
(`props/jungle/tree_trunk 23 10` + `props/jungle/tree_canopy_light 23 8.75`). Props of any biome may be used in any
level.

---

## 9. Zones

Zones are invisible rectangles: `zones/<kind> <col> <row> rect=c,r,w,h [name=...]` in `[entities]` (the
position is only an anchor; `rect` is in cells and is required). A zone reacts to the cell the hero **stands in**
(the cell just above his feet point): a rectangle over the air cells of a room catches him whether he walks or
jumps.

| Id | Parameters | Effect |
|---|---|---|
| `zones/secret` | `name` | a secret area, counted once when first entered (deaths do not reset it) |
| `zones/arena` | `name`, `music` [the boss's own] | boss room: the camera is held inside the rectangle and the boss whose `arena` equals the name starts fighting; released when the boss is beaten (or the hero dies) |
| `zones/camera_lock` | - | while inside, the camera stays inside the rectangle (a rectangle no larger than the view fixes the screen) |
| `zones/dark` | `on` [true] | entering switches the night palette on (`on=false`: off); it fades over one designer second |
| `zones/kill` | - | entering is a pit death |
| `zones/autoscroll_stop` | - | on `scroll = autoscroll` levels, entering stops the descent |
| `zones/message` | `text=<translation key>` | shows the text on the HUD's hint panel (under the HUD row) while the hero is inside |
| `zones/flies` | `count` [5] | dirty ground: every visit adds flies around the hero (cosmetic, at most 20); `items/water_bucket` washes them off |
| `zones/ember_rain` | `period` ticks [22], `skin=ember\|leaf` [ember] | while the hero is inside, an ember (or a leaf) falls toward him every `period` ticks; at most five fall at once and a touch costs a bone (the volcano shaft) |

Camera rectangles (`zones/camera_lock`, `zones/arena`, gates with `lock=`): one screen is 20 x 11 cells. Make the
rectangle 11 rows high with the floor the hero stands on as its bottom row - the view shows the top of the
rectangle, so a floor below it ends up at the bottom edge of the screen. A rectangle smaller than the view is
centred (on wide screens the room's surroundings show at the sides, and at the level's edges the view slides
inwards instead of showing outside the level); a larger one lets the camera follow inside it.

---

## 10. Secrets, checkpoints, exits, boss arenas

- **Exactly one way out**: one `objects/exit`. Bonus stages are left through `items/warp`; the final boss level has
  no exit, the boss drops the trophy. A `locked=true` exit needs an `items/fire_starter` somewhere (placed, in
  `contents`, or the Brute's default drop). The validator checks all of this.
- **Checkpoints** stand on the floor. The first one is optional; without any, the hero restarts at `@`. After a
  death, enemies, platforms and columns reset; collected items and opened spots stay.
- **Hidden spots**: `?` / `*` look like ground. With `look=inset` (atlas tile 15) or `look=block` (tile 7) they
  show a hint until opened. In the air: `prop=<biome>/<name>` (a bush, a rock) is the thing to hit. Thrown-out
  bonuses fly up and land on the first floor they meet: a one-way ledge right above a spot catches them (make
  that a reason to jump up, or keep ledges away), and a big spot's giant bonus falls from 7 rows above the spot.
- **Secret areas**: `zones/secret`, usually behind a wall of `$` or through a gate.
- **Boss arena**: `zones/arena name=pit rect=...` + `bosses/brute arena=pit left=.. right=..` + `|` walls at the
  arena limits; a walled one-screen pit the hero drops into works well (`levels/test_integration_boss.lvl`: without
  walls the hero can be knocked out of the locked view). The Brute's head is the only weak point: a high strike,
  or an axe thrown with a high strike, reaches it. The Wall Colossus level must place `items/weapon kind=axe` next
  to its checkpoint, and `bosses/colossus` goes in the floor-level air cell just left of the arena's right wall
  (its stone rim then covers the wall face).
- **Completion** = opened hidden spots + collected placed items with points, over their totals.

---

## 11. `[backwall]` and `[overrides]`

```
[backwall]
<col> <row> <w> <h> [set=a|b] [deco=<0..100>]
[overrides]
<col> <row> <a|b> <atlas index> [layer=back|main|front]
```

A back wall draws atlas tile 35 behind every cell of the rectangle that is not `#` / `%` (cave interiors, rooms
in a tree, the inside of a fortress); `deco` percent of its cells show the decorated tiles 36 / 37 instead. Back
walls are drawn slightly shaded so they read as "behind". Use them inside enclosed spaces - a back wall in the open
looks like a floating block.

An override draws one atlas tile in one cell without changing collision. `layer=main` (default) replaces the
automatic terrain tile, `back` draws behind the actors, `front` in front of them.

| Index | Tile | Index | Tile |
|---|---|---|---|
| 0 / 1 / 2 | surface left / middle / right | 16 / 17 / 18 | underside left / middle / right |
| 3 / 4 | pillar cap left / right (2-cell pillar top) | 19 / 20 | under 45 degree slope `/` / `\` |
| 5 / 6 | 45 degree slope `/` / `\` | 21 / 22 / 24 / 25 | under gentle `1` / `2` / `3` / `4` |
| 7 | framed block | 23 | fill with detail |
| 8 / 9 / 10 | wall left / fill / wall right | 26 | underside with detail |
| 11 / 12 / 13 / 14 | gentle `1` / `2` / `3` / `4` | 27 / 28 / 29 | one-way left / middle / right |
| 15 | fill with inset panel | 30 / 31 / 32 / 33 | hanging fringe left / middle / right / cap (air cell under a ledge) |
| 34 | small block (rubble, bottom-left) | 35 / 36 / 37 | back wall plain / crack / hole |
| 38 / 39 | floor spikes / ceiling spikes | | |

---

## 12. Hero metrics in tiles

From `docs/spec/PHYSICS_REFERENCE.json` (1 tile = 16 px, 24.3 ticks per second). Left and right differ slightly,
as in the original; design for the weaker direction.

| Move | Numbers | In tiles - design with |
|---|---|---|
| Walk | 5 px/tick (121 px/s) after 5 ticks; stops within 12 px (right) / 17 px (left) | 7.6 tiles per second |
| Standing jump, Up held | apex 60 px, 21 ticks in the air | **3 tiles** up is safe; 4 tiles (64 px) only with a perfect early release - treat as impossible |
| Tap jump | apex 15 px | 1 tile |
| Running jump, Up held | 88 px to the right, 110 px to the left (landing at the start height) | gaps up to **4 tiles** are safe both ways; **5 tiles** needs a run-up to the right |
| Running jump, Up released after 9 ticks | 111 px right, 120 px left, apex 64 px | 6 tiles - expert only; 7+ tiles is out of reach |
| Jump from standing still with Right | 81 px | 4 tiles at most from a standstill |
| Falls | no fall damage; terminal speed 12 px/tick after 12 ticks | any height is survivable |
| Landing | drops of 4+ tiles land hard (3 px hop, about 5 ticks without jumping); 11+ tiles also shake the screen | avoid enemies right where a long drop lands |
| Jump lock-out | after any fall the hero must stand 6 ticks before he can jump again | no instant re-jumps after drops |
| Ceiling | head bump when the ceiling is 2 rows above the floor | 3 rows of air for a jump under a roof |
| Crawl | 2 px/tick | 1-row tunnels can be crawled and walked |
| Bounce on an enemy | 10 px; with Up held 105 px | a head bounce with Up reaches **6 tiles** |

Strike reach (club; the box exists for 3 ticks at the end of the swing, starting 4-6 ticks after the button):

| Strike | Reach | Finds hidden spots in |
|---|---|---|
| Forward | 11..35 px in front, knee height (15..2 px above the feet) | the cells next to the club in the 2 rows above the floor |
| High (Up + strike) | 10..26 px in front, 27..43 px above the feet | the 2 rows at head height and above |
| Low (Down + strike) | -3..21 px in front, from 5 px above to 10 px below the feet | the floor cell in front of him (and the row he stands in) |

A hidden spot is hit when the club's tip is within one column of it and less than 16 px from it vertically. So:
spots in the floor are found with low strikes, spots in a wall at body height with forward strikes, spots at head
height with high strikes. Thrown weapons (axe, boomerang) fly 13 px/tick and also open spots.

---

## 13. What the player sees (camera)

- The authentic view is **20 x 11 cells**; wider phones see more columns (25 on 20:9), tablets more rows. Design
  every challenge to read within 20 x 11 cells; never rely on the extra space.
- Horizontally the camera **pages**: it stays still while the hero walks inside the middle, and when he reaches
  the last 4 columns ahead it scrolls one cell per tick until he is in column 5 again. Standing still never moves
  the view. Look-around (Look, or Left+Right) pans up to the hero being 2 columns from the edge.
- Vertically the hero's feet stay between rows 4 and 9 while he stands; falling into the bottom two rows scrolls the
  view down, rising into the top three scrolls it up. Speed grows with the distance.
- The camera never shows outside the level. A level smaller than the view is centred.
- Enemies wake up when their cell comes within about 2 cells of the view: do not place an enemy where it attacks
  from outside the screen.
- `zones/camera_lock` and gates with `lock=` hold the camera in one room; `zones/arena` does it for boss fights.

---

## 14. Checklist before you hand a level over

- [ ] The validator reports no errors (`--strict` for no warnings either).
- [ ] The preview (`--collision`) shows closed level ends, slopes on ground, no entity in a wall, checkpoints and the
      exit on the floor.
- [ ] Every jump is within the table of section 12 for the weaker direction; every 5-tile gap has a run-up.
- [ ] The exit is reachable; a locked exit has its fire-starter.
- [ ] Hidden spots, secrets and the completion items are where the strike table can find them.
- [ ] Expert and Beginner spawn sets make sense (`--difficulty=expert` preview).
- [ ] An autoplay run or a camera tour was looked at, on the base view and on `--size=2400x1080`.

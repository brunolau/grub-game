# LEVEL_DESIGN.md - building levels for Club & Grub

A practical guide for level designers. The binding definition of the format is `docs/ARCHITECTURE.md` section 7
(and the entity catalogue in section 6.2); this guide explains it by example and adds the numbers you need to
build fair jumps. Owner: world module.

Contents: 1 Workflow - 2 A level by example - 3 `[meta]` - 4 `[tiles]`: the legend - 5 Auto-tiling - 6 Placing
entities - 7 Entity catalogue - 8 Props - 9 Zones - 10 Secrets, checkpoints, exits, bosses - 11 `[backwall]` and
`[overrides]` - 12 Hero metrics in tiles - 13 What the player sees (camera) - 14 Checklist - 15 Co-op and Book II
(version 2.0).

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
  makes a pit anywhere. Liquids are pits for ground enemies too: a walker, hopper, charger or lurker whose feet
  enter a `~` cell is gone with a splash (no points) and comes back from its anchor later.
- Ceiling spikes (`!`) kill as soon as the hero's head probe (feet row - 2) reaches them: with the floor at row r,
  spikes in row r-4 kill after a rise of only 17 px, and every enemy hit knocks the hero up 36 px. Keep enemies
  away from the floor under ceiling spikes that are 4-5 rows up, or put the spikes 6+ rows above the floor.
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

Sprite platforms catch the hero from any fall speed: the ride test's 8 px contact band reaches 16 px below the
surface for a hero falling at 8 px/tick or faster (our fix; in the original a fast landing could pass through).
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
| `zones/ember_rain` | `period` ticks [22], `skin=ember\|leaf` [ember] | while the hero is inside, an ember (or a leaf) falls toward him every `period` ticks; at most five fall at once and a touch costs a bone (the volcano shaft). Embers appear 150 px above the hero and die on the first floor they meet, one-way slabs included: keep about 11 rows of open air above the places where the hero stands, or the rain never reaches him. A touch also shoves him about 36 px up and sideways with ice-like sliding, so waiting spots under the rain should be wide or against a wall (near the top edge of an auto-scrolling view the shove alone can kill) |

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
  death, enemies, platforms and columns reset; collected items and opened spots stay. A hero who touches a
  checkpoint while standing stores his own feet point as the respawn point; one who touches it in the air (jumping
  past it, falling onto it) stores the checkpoint's own point. Keep the floor around a checkpoint solid for about
  two cells on each side, and not on ice next to a gap.
- **The weapon a player brings**: a run keeps its weapon from level to level (the axe of 1-2 into 2-1, the hammer
  of 2-1 into worlds 2 and 3, the swirling axe of 3-2 into world 4), while a level started from its code or the
  level select begins with the club. A level must be fair with every weapon a player can hold on entry: nothing on a
  main path may need a melee hit (thrown weapons open spots and blocks too), and a boss must be beatable with each.
  Every (stage, difficulty, weapon) cell has its own route proof, `<id>[.expert].<weapon>.inputs`;
  `tests/test_campaign_routes.gd` demands one per cell and plays both campaigns with the carried weapon. To make a
  weapon route from the club route: `CAMPAIGN_ADAPT` / `CAMPAIGN_REPAIR` there, the `sync` job of
  `tests/test_route_tools.gd` (re-times a route so the new weapon's hero meets the club hero at every resting point),
  and `ARMS_REPAIR` of `tests/test_enemies_colossus.gd` for the auto-scrolling shaft. After any level change, re-run
  `bash .tools/gd.sh test campaign_routes`: it replays every weapon's routes of that level.
- **Hidden spots**: `?` / `*` look like ground. With `look=inset` (atlas tile 15) or `look=block` (tile 7) they
  show a hint until opened. In the air: `prop=<biome>/<name>` (a bush, a rock) is the thing to hit. Thrown-out
  bonuses fly up and land on the first floor they meet: a one-way ledge right above a spot catches them (make
  that a reason to jump up, or keep ledges away), and a big spot's giant bonus falls from 7 rows above the spot.
- **Secret areas**: `zones/secret`, usually behind a wall of `$` or through a gate.
- **Boss arena**: `zones/arena name=pit rect=...` + `bosses/brute arena=pit left=.. right=..` + `|` walls at the
  arena limits; a walled one-screen pit the hero drops into works well (`levels/test_integration_boss.lvl`: without
  walls the hero can be knocked out of the locked view). The Brute's head is the only weak point: a high strike,
  or an axe thrown with a high strike, reaches it. The Wall Colossus level must place `items/weapon kind=axe` next
  to its checkpoint (with a sign saying that only a thrown axe hurts it: a club or hammer on its head glances off
  with a clank and a spark), and `bosses/colossus` goes in the floor-level air cell just left of the arena's right
  wall (its stone rim then covers the wall face). Keep the arena's rock ceiling low enough that falling stalactites
  hang below the HUD row and the boss bar (Colossus Hall: rows 2-4 of rock over the hall). The tuning is in
  `docs/spec/GAMEPLAY.md` 6.3 and pinned by `tests/test_enemies_colossus.gd`.
- **Teaching signs**: every new mechanic gets an `objects/sign` (or a `zones/message` hint) where the player meets it,
  before it can kill him: the boards stay up for a read time and make the stage banner give way, so a sign right
  at the start is fine (Cinder Shaft does that: its descent waits for the player's first input). A pit of lava
  should show its lava: fill it to one row under the floor and put a `[backwall]` behind the open row, so the
  parallax backdrop does not show through.
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
- [ ] Its route files are in `tools/autoplay/routes/` and described in `ROUTES` of `tests/test_campaign_routes.gd`
      (level, modes, how it ends, what it must achieve); a new map stop also goes into `CAMPAIGN` and `MAP` there.
      (Book II, co-op and arena routes use the route header of 15.9 instead.)

---

## 15. Co-op and Book II

Building the 2.0 content: the 20 Book II files, the 35 co-op files and the 10 versus arenas. The design is
`docs/expansion/DESIGN.md`; the rules are `docs/spec/GAMEPLAY.md` 13 and `docs/spec/PHYSICS.md` Appendix C
("P-C.n"); the plan and the per-level recipe are `docs/expansion/PLAN.md` 6. Sections 1-14 still hold. **The 15 Book I
files and their 72 route files are frozen: never edit them** (a guard test checks their hashes).

### 15.1 Files and ids

- Book II: `w5_l1`, `w5_l2`, `w5_l2b`, `w6_l1`, `w6_l2`, `w6_l2b`, `w7_l1`, `w7_l2`, `w7_l2b`, `w8_l1`, `w8_l2`,
  `w8_l2b`, `w9_l1`, `w9_l1b`, `w9_l2`, `w9_l2b`, `w9_l3`, `bonus_d`, `bonus_e`, `ending_b` (kinds, orders, links,
  letters, specials and painting indices: GAMEPLAY 13.2).
- Co-op: `levels/<id>_coop.lvl` for every one of the 35 stages (`w1_l1_coop` ... `ending_b_coop`).
- Arenas: `levels/arena_<name>.lvl` (`arena_totem_ring`, `arena_echo_hollow`, `arena_floe_rink`, `arena_cinder_pit`,
  `arena_tar_pulleys`, `arena_coconut_cove`, `arena_sky_picnic`, `arena_colossus_hall`, `arena_mesa_rodeo`,
  `arena_cloud_top`).
- New files are `format = 2` (format-1 files load unchanged). Sign texts go into your own locale file
  (`locale/levels/en/<world>.po`, keys `SIGN_W5_*`), not into `locale/en.po`.
- **Briefs**: the exact phase-3 targets of worlds 6-9, Feast Land E and the Long Raft Home (size, meta, codes,
  checkpoints, enemy budget, signs, painting places, co-op gates) are `docs/expansion/DESIGN.md` A.6; what G1 and phase
  2 settled is DESIGN.md "Appendix: G1 and phase-2 resolutions" ([Gn]).

### 15.2 New `[meta]` keys

| Key | Values | Default | What it does |
|---|---|---|---|
| `book` | `1` `2` | `1` | which book's campaign, map and codes the file belongs to |
| `belt` | `fresh` `carry` | `fresh` when `book = 2` or `kind = coop`, else `carry` | `fresh`: the stage starts with the club in hand (P-C.2) |
| `kind` | + `coop`, `arena` | | `coop`: the co-op version of `coop_of`; `arena`: a versus arena. Neither ever appears in a solo campaign |
| `coop_of` | level id | required for `coop` | the solo file this co-op file belongs to (its campaign stop) |
| `coop_base_hash` | sha256 (hex) of the solo file | required for `coop` | the validator warns when the solo file changed since the co-op file was made |
| `players` | `2` .. `4` | required for `arena` | most players the arena is built for |
| `round_time` | seconds | `90` | arena round length (Grub Stack plays 60 with two players) |
| `modes` | list of `grub_stack` `last_caveman` `hot_rock` `clubball` ... | required for `arena` | modes the arena supports (each needs a green bot test) |
| `wrap` | `none` `lr` `tb` | `none` | arena edges joined left-right or top-bottom |
| `sudden` | `stampede` `cave_in` `whiteout` `lava_rise` `tar_rise` `high_tide` `syrup_flood` `stalactites` `rockslide` `lightning` | by biome | the arena's sudden death |
| `liquid` | + `tar` `honey` `syrup` | | look of `~` and `:` (all deadly as water) |
| `scroll` | + `rising` | | the rising tide (P-C.8) |
| `rise_speed` | v16 per tick | `16` | 16 = 1 px/tick; `.expert` variant allowed |
| `wind` | `tick:value,...` | | values may be negative (wind to the right) |
| `wind_loop` | ticks | `0` | the wind script restarts every that many ticks (alternating gusts) |
| `biome` | + `canyon` `swamp` `coast` `ruins` `sky` | | default terrain, backdrop and music of the new worlds |

New terrain atlases (same 40-tile layout and collision as every set): `canyon/terrain`, `canyon/terrain_mesa`,
`swamp/terrain`, `swamp/terrain_mushroom`, `swamp/terrain_bark` (walls inside the hollow mangrove, Old Mangrove's
chamber), `coast/terrain`, `coast/terrain_sand`, `coast/terrain_cave` (wet sea-cave rock: 7-2, 7-2b), `ruins/terrain`,
`ruins/terrain_jade`, `ruins/terrain_carved` (exit-totem stone, temple plinths, the Totem Ring's totem), `sky/terrain`,
`sky/terrain_rock`, and for the Feast Lands `feast/terrain_honeycomb` (wax and honey comb: Feast Land D) and
`feast/terrain_pudding` (custard under a caramel top: Feast Land E). Backdrop sets (`background`): `canyon`; `swamp`,
`mushroom`, `mangrove`; `coast`, `sea_cave`; `ruins`, `temple`; `sky`, `storm` (9-1b / 9-2 / 9-2b), `pyre` (9-3).
New props: `props/<biome>/<name>` of the five worlds (ASSET_MANIFEST 17) and `props/feast/<name>` (honey_drips_a,
honey_drips_b hanging, comb_chunk, honey_pot, jelly_pink, jelly_green, pudding, cherries, cream_swirl, wafer_sticks).
Sizes to design with: octopi about 1 x 1 tile, leaping fish 1 x 0.5, the ruin ghost about 2.5 x 2.5, each Twin Idol
Colossus-sized (a 2-column wall and 7 rows), the Storm Roc about 6.5 x 3 tiles.

**Music**: set `music` explicitly in every Book II file; these contexts are binding [G26]:

| Stage | `music` | Stage | `music` |
|---|---|---|---|
| `w5_l1` | `level_canyon` | `w8_l1` | `level_ruins` |
| `w5_l2`, `w5_l2b` | `level_gulch` | `w8_l2`, `w8_l2b` | `level_idol_hall` |
| `bonus_d` | `bonus` | `w9_l1` | `level_sky_climb` |
| `w6_l1` | `level_fen` | `w9_l1b` | `level_storm_glide` |
| `w6_l2` | `level_spore` | `w9_l2`, `w9_l2b` | `level_spire` |
| `w6_l2b` | `level_mangrove_climb` | `w9_l3` | `level_pyre` |
| `w7_l1` | `level_coast` | `ending_b` | `ending_raft` |
| `w7_l2`, `w7_l2b` | `level_sea_caves` | `bonus_e` | `bonus_lagoon` |

A sub-stage keeps its first half's music (as Book I's `w2_l2b` / `w4_l2b`), except 6-2b, whose rising-tar climb has
its own track; each boss pushes its own `boss_*` theme while its bar shows (the boss script; `zones/arena music=`
only overrides); a co-op file sets its solo file's music.

### 15.3 The new tile

| Char | Meaning | Floor | Wall | Ceiling | Drawn as |
|---|---|---|---|---|---|
| `:` | tar floor (set A ground, surface 6 px lower, slow: P-C.5) | yes | yes | yes | surface tiles of the set in the level's `liquid` skin (tar, honey, syrup, mud for Tusker) |

Wading out of tar onto level ground works; a step of one row out of tar can be hopped (the hop reaches 33 px from
the tar surface, 27 px above the ground around it), two rows cannot. A tar pit with walls 2+ rows high is a trap unless
a vine, a geyser or a partner gets the hero out. A geyser placed on the tar floor itself works: it sits on the lowered
surface, and its launch ends the tar rules, so the hero flies 105 px with full air control [G8]; so does a Shoulder
Hop off a partner standing in tar, or Chomper's dismount over tar flats.

### 15.4 New entities

**Enemies** (all take `skin`, `hp` [25], `score`, `expert`, and in co-op files `coop=<trait>`, `bond=<name>`,
`keeper=<name>`, `perch=c,r` for `grab`, `window=<ticks>` for `bond` / `split` / `daze` [G2]):

| Id | What it does | Parameters |
|---|---|---|
| `enemies/roller` | walks; curls 14 ticks and rolls at a hero in range; dizzy after a wall | `range` tiles [6], `speed` v16 [64], `dizzy` [33], `left` / `right` [-3 / 3] |
| `enemies/guard` | patrols with a shield that turns only every `turn` ticks; front hits glance | `turn` [33], `left` / `right` [-3 / 3] |
| `enemies/mimic` | a chest that bites a hero on its floor within 2 cells (32 px across, 16 px up or down: a hero jumping over it does not wake it); dies from behind or after a head bounce; drawn as the closed chest, never mirrored | `contents` [`treasure`], `range` px [42] |
| `enemies/shellback`, `raptor`, `snatcher`, `leech`, `bull_rex`, `tar_splitter`, `shaman` | the co-op-only presets (GAMEPLAY 13.9.6); **only in co-op files** | as their archetype; `snatcher kind=dangler\|stinger` |

`window=<ticks>` caps that record's window: effective = `min(24 B / 12 E (daze 14 / 12), window)`, a bond uses the
smallest `window` of its members, one value serves both difficulties. Set it after `test_coop_gates` measured the
record's `solo_min`: `window <= solo_min - 4`.

**Bosses**: `bosses/tusker`, `bosses/mangrove`, `bosses/squid`, `bosses/idols`, `bosses/roc` (each `arena=<zone>`,
`hp`, `drops` [`fire_starter`]), `bosses/chieftain` (two records, `name=` and `mate=<the other's name>`, `drops`
[`trophy`] on the second). Their arenas are fixed one-screen rooms (GAMEPLAY 13.6).

**Objects**:

| Id | Parameters |
|---|---|
| `objects/vine` | `length` cells [4], `rolled` [false]; the anchor cell's top is the vine's top |
| `objects/bark_board` | `face=l\|r` [the side with air]; place it in the wall cell (`tile=#` in a legend entry) |
| `objects/geyser` | `period` [88], `delay` [0], `power` v16 [-224], `skin=mud\|blowhole\|steam\|soda`, `deadly` |
| `objects/raft` | `width=3\|4` [3], `skin=log\|wafer`, `rails` (riders cannot leave it: `ending_b`); place it on the top `~` row |
| `objects/mount` | `kind=rex`, `pen=<name>`, `wild` |
| `objects/rex_pen` | `name` |
| `objects/plate` | `name`, `count=1\|2` [1], `mode=hold\|timed:<ticks>\|latch` [hold], `w` cells [2] |
| `objects/column` | + `rise_while=<plate>[,...]`, `sink_while=<plate>[,...]`, `trigger=keepers:<name>`, `trigger=drums:<bond>`; `rise=0` with `expert` makes a static Expert-only block |
| `objects/drum` | `bond=<name>` |
| `objects/seesaw` | `len` cells [5] |
| `objects/boulder_heavy` | - (2 x 2 cells, anchored at its bottom-left cell) |
| `objects/pulley` | `a=<platform name>`, `b=<platform name>`, `range` rows [3] |
| `objects/flower_pot` | - (on a ledge's edge cell) |
| `objects/x2_tablet` | `gate=<name>`, `far=c,r` (the cell beyond the gate), `secret` (marks an x2 secret) |
| `objects/hero_start` | `slot=2` (co-op files) |
| `objects/gate` | + `needs=<bond>` (locked until a drum bond succeeds) |
| `objects/spawn_point`, `objects/cookpot`, `objects/coconut`, `objects/crate_lane` | arenas only (15.8) |

**Items**: `items/painting index=0..29` (the index of the level, GAMEPLAY 13.7), `items/weapon kind=spear`.

**Zones**: `zones/current rect= dir=l|r|u|d speed=1..3` (pale streaks show it); `zones/lightning rect= period=
[delay] [mark]` (`period` [66], `mark` [22]; the clock counts the ticks a hero is inside, the target alternates
between the heroes inside); `zones/food_rain rect= period= [skin=food|fruit]` (one stream per hero inside); arenas:
`zones/goal rect= team=1|2`. Darkness as in 2-1 (`dark = true` or `zones/dark`): on Book II levels and in a party
every hero glows warm and every prop whose name holds "glow" (`swamp/props/glowcaps`, `glowcap_big`,
`coast/props/glow_*`, `ruins/props/brazier_glow`) glows teal - mark the way with them.

### 15.5 Book II metrics in tiles

| Thing | Numbers | Design with |
|---|---|---|
| Spear throw height | forward throw at the feet (hits a board in the row just above the floor), high throw at head height (the row two above the floor); a jump adds up to 60 px | boards in rows 1-2 above a floor are hit standing; higher ones need a jump-throw |
| Spear step | a one-way step on the **top edge of the board's cell**, 16 px wide, 220 ticks; at most 2 per hero | a board N rows above the floor gives a step N tiles up; 3 tiles is an easy jump; two steps 3 rows apart climb 6 tiles |
| Vine | grabbed with Up (not Down + Up) when the hands (32 px over the feet) reach it; climb 2 px/tick up, 3 down; leap off 36 px up and 47-83 px out; climbable from a raft, spear step or lift | a vine whose bottom hangs up to 2 rows over a floor is grabbed standing, up to 5 rows with a jump |
| Tar | wade 2 px/tick; hop 33 px | 15.3 |
| Geyser | -224: 105 px, the same as a spring or an Up bounce | a geyser lifts to a ledge up to 6 tiles above its vent, also from a tar floor (the way out of a tar pit) |
| Raft | current 1-3 px/tick; paddle up to 3 px/tick of its own; banks stop it | keep a raft's path free of cells at its surface row except the banks you want |
| Rising tide | 1 px/tick = one row per 16 ticks | a Beginner stopping 73 ticks (3 s) loses 4.5 rows: give every climb that much spare |
| Chomper | 4 px/tick; hop 55 px, 84 px far at full speed | mounted gaps <= 4 tiles, steps <= 3 rows, 4 rows of air in mounted corridors, no sprite platforms on mounted stretches |
| Gusts | negative `wind` pushes right; crouching braces; co-op: a hero up to 64 px downwind of a crouching partner (16 px up or down) feels no wind, and a jump taken there stays sheltered until he lands (the lee) | alternate with `wind_loop`; give a crouching spot before every gap; a co-op lee gap is at most 3 tiles with a crouching spot within 64 px downwind of its far edge |
| Lightning | the column is marked 22 ticks before the bolt; `period` [66]; it alternates between the heroes inside | never two bolts on the only safe cell in a row |

### 15.6 Book II rules

- **Fresh club, no special needed**: every Book II stage starts with the club in hand; nothing on a main path needs a
  special and every boss falls to the club. Specials open shortcuts, secrets and paintings (a spear-step secret, an
  axe-only spot) and make fights easier. The special of each world lies where GAMEPLAY 13.2 says.
- **One route proves every weapon**: record one club route per (stage, difficulty) (15.9); the belt-invariance test
  replays it with each special on the belt. A secret or painting that needs a special gets a featured route.
- **Paintings**: one per level (the index of GAMEPLAY 13.2), never on the main path (behind `$`, up spear steps, at a
  vine top, inside a big spot, behind an x2 gate in co-op). The co-op file has the same index, maybe elsewhere.
- **Letters** G-R-U-B-S in 5-2, 6-1, 6-2, 7-1, 7-2; one full feast kit per world.
- **Teaching**: a sign before every new mechanic, before it can kill (the belt sign "Your club never leaves you.
  Press SWAP." stands before the first enemy of 5-1).
- **Sign texts** [G27]: a sign's text takes at most **3 board lines** (`SignBoard.MAX_LINES`; about 60 characters;
  `SignBoard.text_lines(text)` measures it as the board wraps it). Boards keep clear of every hero and the HUD (the
  row, the boss bar, P2's panel and the versus corners) and show one at a time: two signs a few columns apart are
  fine, but give each idea one short sign. `tests/test_ui_signs.gd` guards `locale/en.po`; check your own `.po` the
  same way.
- **Boss arenas** as section 10, one walled screen each; the geometry of every arena is in GAMEPLAY 13.6.

### 15.7 Co-op files

#### 15.7.1 Making one

1. Prove the solo file first (validator `--strict`, routes green).
2. Copy it to `<id>_coop.lvl`; set `kind = coop`, `coop_of = <id>`, `coop_base_hash = <sha256 of the solo file>`;
   remove the passwords; keep `book`.
3. Add `objects/hero_start slot=2` next to `@` (P2 starts 24 px behind P1 at every respawn anyway).
4. Build the co-op gates (15.7.3) with their x2 tablets (15.7.4), the trait enemies (15.7.5), paired specials (where
   the solo file places a weapon item, place two), the painting and the x2 secret, signs for the egg and the tablet at
   the first checkpoint of 1-1 and 5-1. You may leave out solo records that would hand a lone hero a bounce at a
   height gate or hit a role holder (a plate holder, a baiter), and bond what the stage wants bonded (5-1 co-op:
   four records out, the long-climb Rollers one bond) [G22]; the trait share counts the records that remain.
5. Validator `--coop` clean; `tests/test_coop_gates.gd` green (every gate refused by the solo search); record the
   two-stream routes (15.9).

#### 15.7.2 Duo metrics in tiles

| Move | Numbers (P-C.10, P-C.11) | Design with |
|---|---|---|
| Shoulder Hop | feet reach 140 px over the floor (8.75 tiles); at or above 8 tiles for 10 ticks; only off an **active** partner - never off an egg (a hatch bounce is 10 px) or an idle hero [G1] | boost ledges 7 tiles (Beginner) / 8 (Expert); 11 rows of air over the hop spot |
| Totem Ride, rider's jump | from a still carrier 98 px (6 tiles); a jump 1-5 ticks after the carrier's: 139-152 px (8.5-9.5 tiles) | a 5-tile ledge is the easy Totem ledge; 7-8 tiles need the timed Totem launch or the hop |
| Totem Ride, rider's strikes | high strike 61-77 px, forward strike 36-49 px over the floor | targets 4-5 rows up for a rider; 5 rows of air where a rider is expected |
| Line drive | 153 px to the same height (rise 36 px), and the ball stops where it lands; charged 325 px | Batter Up gaps 8 tiles (Beginner; the curl spot within 25 px of the edge) / 9 tiles (Expert: within 9 px, or charged); 4 rows of air over the gap; a landing area 2+ cells deep |
| Lob | rise 120 px; at or above 7 tiles on ticks 12-19, 24-38 px out | lob ledges 7 rows up with their face 2-3 cells from the curl spot; 9 rows of air over the curl spot |
| Grounder | 192 px (12 tiles) along the floor in 32 ticks | rolls under low gaps, breaks `$` in its path |
| See-saw | launch 153 px (a 4-tile drop onto the high end) to 171 px (5+ tiles) | target ledges up to 9 rows over the low end |
| Duo reach in general | chained moves (a hop off a jumping partner, see-saw plus hop) reach 12-13 tiles | contain co-op paths with walls and roofs of 13+ rows where skipping would break the stage |

#### 15.7.3 Gates

Every co-op `main` file has **at least 2 co-op gates on the main path** (`w9_l3`: its boss form); every `sub` file at
least 1 gate or its boss's co-op form; bonus stages and endings only the team exit (the Way Home adds its lookout
gate). Every gate and every x2 secret has an `objects/x2_tablet` (15.7.4). Each gate has an easy role and a hard role,
a way back (a drop gift: a rolled vine reaching the lower floor, or a flower pot), takes under about 30 s once
understood, and costs at most an egg. Put a checkpoint behind every gate (a team wipe resets plates, drums, columns
and keepers).

| Kind | Recipe |
|---|---|
| **Boost ledge** | a ledge 7 rows (Beginner) / 8 rows (Expert) over a floor at least 3 cells wide under its face; build it at 7 and put an `expert`-flagged `objects/column rise=0` of one row on top for Expert - or the other way round: the ledge at 8 and a `beginner`-flagged static block filling the dip's bottom row for Beginner, when an Expert row on top would put the upper hero above the view (1-1 co-op) [G22]; 11 rows of air over the hop cells; a drop gift on top. **A flower pot reaches 6 rows from the floor it takes root on**: it lands 1-2 cells beyond the face, so under a 7- or 8-row boost ledge it must land on a raised spot of 1-2 rows (1-1 co-op: a one-row root; 5-1 co-op: a two-row rock); a 7-row ledge is 3 px under its apex - neither a way back to rely on nor a barrier [G6] |
| **Totem ledge** | a ledge 5 rows up (Totem jump or hop, both difficulties) |
| **Batter Up gap** | 8 (Beginner) / 9 (Expert) cells of `~` between two floors at the same height; or a 7-row lob ledge (15.7.2) |
| **Plate door** | `objects/plate` (`count=1 mode=hold`) at least **8 tiles** from its door (`objects/column rise_while=<plate>`); the holder must reach the far side another way: a second plate beyond the door for him (**leapfrog**: A holds for B, B holds for A - with **two doors in two corridors**, because a column rises only while all its plates are pressed: plate A opens the lower corridor for B, plate B beyond opens the upper corridor for A; 1-1 and 5-1 co-op [G9]), or a `timed:` plate |
| **Twin drums** | two or more `objects/drum bond=<name>` with a column `trigger=drums:<name>` (or a gate `needs=<name>`); place them so one hero needs at least 28 ticks (Beginner) / 16 (Expert) to strike both - in practice 10+ tiles apart and 4+ rows apart, out of one axe's flight line; the search decides |
| **See-saw** | `objects/seesaw` with its high end 1 row over the floor, a ledge 4+ rows above the high end within 3 cells to drop from, the target up to 9 rows over the low end; no enemy may fall onto it |
| **Heave boulder** | `objects/boulder_heavy` with 3+ cells of floor behind the pushed side and 2+ rows of air; it fills a 2-cell gap, plugs a vent (`objects/geyser deadly`) or presses a plate |
| **Pulley** | `objects/pulley` with two `objects/platform mode=ride` 4+ cells apart; the rider's target `range` rows above his platform's start |
| **Keeper door** | `objects/column trigger=keepers:<name>` behind a hall **exactly 4 rows high** (the Guard and Shellback art is 54 px tall); its keepers (`keeper=<name>`) carry `shell`, `bond` or `daze`. Keepers meant for a pincer stand still (`speed=0`: a walker with left = right = 0 still sways about 30 px); bait about 30 px in front, the striker's way in about 40 px behind [G5] |
| **Brace corridor** | a `heavy` (Bull Rex) in a 4-row-high hall between walls |
| **Chomper two seats** | a mounted stretch where only the gunner can clear the way (Leeches, a Snatcher) over ground a hero on foot cannot cross (spikes with no run-up) |
| **Lee gap** | gust gaps of up to 3 tiles whose gusts never pause, strong enough that a lone hero falls short; a crouching spot within 64 px downwind of each far edge (P-C.6 lee) [G23]; the search decides |

#### 15.7.4 x2 tablets

`objects/x2_tablet gate=<name> far=c,r` stands on the near side of every co-op gate (a gate is any of the kinds of
15.7.3); `secret` marks an x2 secret instead. `far` is a cell beyond the gate that the hero reaches only through it
(the solo search's goal). The validator pairs them: one tablet per gate name, every co-op mechanism (plate-driven or
drum or keeper column, boulder, pulley, see-saw, boost ledge, gap) inside some tablet's gate, names unique, `far` an
air cell above a floor.

#### 15.7.5 Traits and keeper halls

- At least **one third of the enemy records** of every co-op file carry a trait, and **every enemy guarding a
  main-path chokepoint** does. Traits only in `kind = coop` files.
- Trait choice per archetype: GAMEPLAY 13.9.4 (the "Traits used in layouts" column). Bonds: `bond=<name>` on every
  member, members placed out of one hero's reach within the window (as twin drums), and members of one bond within
  one view of each other (the search measures `solo_min` per bond; a bond spread over 60-80 columns makes it run for
  minutes and proves nothing). Cap a record's window with `window=<ticks>` once its `solo_min` is known (15.4) [G2].
  `grab` needs a `perch=c,r` next to a pit. `lone` is off on Beginner: do not make a gate out of it. Snappers have no
  co-op rule of their own (bait-and-bite was dropped [G10]): pair them with `bond`.
- **Keeper and Guard halls are exactly 4 rows high** (4 rows of air, a ceiling above; orchestrator resolution at
  phase 1: the Guard and Shellback art is 54 logical px tall): nobody can jump or bounce over a keeper to get past
  it. The search (15.7.6) still proves it, because a hero can land on a short enemy's head even there.

#### 15.7.6 Solo impossibility (validator `--coop` and `tests/test_coop_gates.gd`)

Static rules first (the validator), within **10 cells horizontally and 11 rows below** a boost ledge's top, a lob
ledge, a Totem ledge, and over a Batter Up gap: no enemy record that a hero can bounce on, no `objects/spring`,
`geyser` (other than a `deadly` vent), `seesaw` (other than the gate's own), `vine`, `bark_board`, `items/glider`,
`objects/platform` / `drop_platform` path, column of 2+ hittables stacked vertically (a club pogo ladder), mount pen.
No bark board within 12 cells of any gate. Plates at least 8 tiles from their doors. Keeper and Guard halls 4 rows
high. Then **the search**: for every x2 gate a bounded single-hero search on the route tools' simulator, starting at
the tablet and at the last checkpoint before it, with the club and every special from the belt and Chomper where a pen
is in the stage, must **fail** to reach the tablet's `far` cell within 1 457 ticks *(tune)*. It also measures
`solo_min` for every twin window and daze record: the window used is `min(24 B / 12 E, solo_min - 4)`.
`test_coop_gates` is a slow module (PLAN 8 V7): a plain `bash .tools/gd.sh test` skips it; run it by name with
`bash .tools/gd.sh test coop_gates` (or `GD_TIMEOUT=900 bash .tools/gd.sh test --slow`) after every change to a
co-op file and before you hand one over [G13]. A gate whose far cell no chain of feet cells reaches from the starts (a
jump rises at most 5 rows over the last ground) is refused without simulating. The search has no eggs and no
partner: the egg rule (an egg or an idle partner is no springboard, P-C.10 / P-C.12 [G1]) is what keeps them off a
boost ledge, so do not build a gate that only that rule holds shut.

#### 15.7.7 Two heroes on one camera

- Keep each gate inside one view: both heroes must see each other's role (20 x 11 cells).
- The view edges are walls and the vertical follow uses the grounded hero; a hero left off the view becomes an egg
  after 121 / 73 ticks (also above or below it: while a partner of the tribe holds the view, a hero out of its rows is
  leashed, not downed - PHYSICS C.12 / C.13). While both heroes stand (ground, a platform, a carrier or a vine under
  their feet), the view keeps both whole as long as their feet are at most 9 rows apart [G13]: **ledges up to 9 rows
  over the partner's floor stay on the view while both stand** (every boost, Totem and lob ledge does). Higher than
  that the upper hero has to come down or the lower one up before the leash runs out; keep drops where one hero may
  stand above the other within 9 rows, or have both drop together.
- Checkpoints: keep 2 free cells on each side (P2 respawns 24 px beside P1).
- Locked rooms (arenas, gates with `lock=`, camera locks) pull the partner in.

#### 15.7.8 Conventions confirmed after G1

What the phase-1 owners and the slice designers settled in code, confirmed by the lead designer after gate G1
(DESIGN.md "Appendix: G1 and phase-2 resolutions" G5-G9, G22; GAMEPLAY 13.9.7 carries the object rules).

- **Plate**: anchored at its LEFT cell, covering `w` cells to the right; a hero counts while his feet are over its
  cells, on its floor or up to 8 px above it and not rising. Columns rise while ALL their plates are pressed, so one
  door cannot be opened from both sides: a leapfrog uses **two corridors** (plate A opens the lower corridor for B,
  plate B beyond opens the upper corridor for A; 1-1 and 5-1 co-op).
- **Door rule** (`objects/column`): a driven block whose next cell in its direction of travel is solid is a door (the
  cells it leaves become air, a portcullis into a ceiling slot); into air it keeps the 1.0 pillar rule. Build a keeper
  door as the bottom cells of a wall that continues above the hall, `rise` = the hall height (4). A returning door
  waits instead of moving into a hero.
- **See-saw**: fulcrum at the anchor's feet point, plank `len * 8` px each side, `facing` names the high end; the low
  end lies 1 px over the floor, the high end one row higher, so "a ledge 4+ rows above the high end" is a ledge 5+
  rows over the floor (the -272 / 153 px launch of C.17). Two heroes on one see-saw play ping-pong.
- **Flower pot**: a strike pushes it in the strike's direction; it slides to its floor's edge or a wall, falls at
  2 px/tick and lands 1-2 cells beyond the ledge's face as a permanent spring of -224 (a 105 px rise from the
  spring's top, 10 px over the floor). **It reaches 6 rows from the floor it takes root on** (19 px to spare): place
  the ledge it is the way back to at most 6 rows above the pot's landing floor - under a 7- or 8-row boost ledge, on
  a raised spot of 1-2 rows (1-1 co-op: a one-row root, 5-1 co-op: a two-row rock). A 7-row ledge is 3 px under the
  apex: neither a way back to rely on nor a barrier (orchestrator resolution after G1; "a hop of 7 / 8 rows" is
  measured from the dip under the face).
- **Boost ledge, Expert row**: R18 may be built the other way round - the ledge at Expert height and a
  `beginner`-flagged `objects/column rise=0` filling the dip's bottom - when an Expert row on top would put the upper
  hero above the tribe camera's top edge (1-1 co-op). Both variants are proven per difficulty by the search.
- **Egg**: an egg or a just-hatched idle partner is no springboard (P-C.10 / P-C.12): a hatch bounce rises 10 px, a
  Shoulder Hop needs a partner whose player gave input since he hatched.
- **Keepers that wait**: Shellbacks / Guards meant for a pincer stand still (`speed=0`): a walker with left = right = 0
  still sways about 30 px, which makes the bait and back-strike distances fickle. Bait about 30 px in front, striker
  about 40 px behind.
- **Twin drums**: a hit on tick t0 opens a window of W ticks (24 B / 12 E, capped by `solo_min - 4`); the other drums
  must be hit on t0 .. t0 + W - 1. The count-in plays while a hatched hero stands within 40 px of every drum. The
  window values stay as they are for phase 3 (the pair playtests of P4.5 may only shorten them).
- **x2 tablet**: lights (frame 2) once a hatched hero stood in its `far` cell, and stays lit.
- **Team gate**: partners arrive spread behind the hero who entered (eggs when they were more than a view away); a
  gate with `lock=` pulls the party into the locked view. A mounted hero cannot use a gate; the exit totem dismounts.
- **Spear and boards**: a spear is tested against bark boards at its spawn position too, so a hero pressed against the
  board's wall, or standing on a spear step under a second board of the same face, sticks it (two steps 3 rows apart
  on one face climb 6 tiles, 15.5).
- **Solo search**: a gate whose far cell no chain of feet cells reaches from the starts (a jump rises at most 5 rows
  over the last ground, 15.7.6) is refused without simulating; the search starts at the tablet and at the last
  checkpoint **before it by column** - on a road travelled leftwards place the tablet so the near-side checkpoint
  wins (DB1).

### 15.8 Arenas

- **Size**: 20 x 12 cells (floor row 10, fill row 11), camera locked; row 0 holds nothing to stand on (HUD corners
  and the round sundial). Wider or taller screens show a decorated frame, never gameplay.
- **Shape**: tiers 3 rows apart; rises of 5+ rows only by spring, geyser, see-saw or a head; clear gaps of at most 5
  cells; mirrored layouts (spawns rotate every round); 4-8 visible hidden spots; one signature hazard telegraphed 10+
  ticks ahead; geometry a bot graph can describe (no 1-row squeezes, no pixel-perfect jumps on main routes).
- **Entities**: `@` is spawn 1, `objects/spawn_point index=2..4` the others (as many as `players`); one
  `objects/cookpot` (two on 4-player arenas, on contested ground); `objects/crate_lane rect= ` for pterodactyl crates;
  Clubball: `objects/coconut` (its drop point) and two `zones/goal team=1|2`, goal mouths 3 rows high. No exit, no
  checkpoint, no co-op objects except see-saws and pulleys, no traits.
- **Wrap**: `wrap = lr` joins the left and right edges (the floor must continue across the seam); `wrap = tb` joins top
  and bottom (no pits: the bottom row is the seam). Sky Picnic has no deadly cell at all.
- **Bots**: bake `resources/bots/arena_<name>.json` with `tools/bots/bake_nav.gd`; an arena ships in a mode only when
  its bot test is green (else human-only).
- **Validator** (`kind = arena`): the size, row 0, spawn count, cookpots, goals for `clubball`, no exit or
  checkpoint, `modes` and `sudden` known, tier and gap rules (warnings; a run that ends at a wall face is no gap).
- **What the Totem Ring taught** (DA at G1, DESIGN.md E.5 [G14]): every strike ends in a hop or a pogo, so keep spot
  stands and spawns out of a spring's reach (about 20 px); food knocked out of a spot under a bridge arcs onto that
  bridge; a hero pogoing off a spot under a one-way tier 3 rows up pokes his head 2 px through it. A stomp is a
  landing (P-C.14 [G15]), so a hero standing on the tier does not stomp him - until world-B's referee has that rule,
  keep spawns off the tiers above another spawn's first spot. Spawns go where no drop, jump or spring link of the
  bot graph lands in the first 48 ticks (the floor under the tiers near the middle). Every Rookie heads for the big
  spot at a round start (it values it as three small spots): put it on the side with fewer spots. The view-centre
  drop point of the Feast Rush giant and the Golden Drumstick (x 160, row 2) must be a place heroes can reach.
- **Names**: an arena's `name` is a msgid; ui-B adds it to `locale/en.po` under "Versus arenas" (one shared msgid
  serves "Colossus Hall", arena and stage).
- Layouts and sketches: DESIGN.md E.5 (Totem Ring as built, Tar Pulleys, Coconut Cove, Cinder Pit drawn there).

### 15.9 Route files and headers

New routes describe themselves in a header instead of a `ROUTES` entry. The header is the first line of the file:

```
# route: level=w5_l1 difficulty=beginner players=1 ends=exit after=tally expect=hurts:0,min_checkpoints:2,painting:0
```

| Key | Values |
|---|---|
| `level` | the level the route starts in (a co-op route names the `_coop` file) |
| `difficulty` | `beginner`, `expert` or `both` |
| `players` | `1` (default) or `2` |
| `ends` | `exit`, `warp`, `trophy` or `none` (a featured side route that stops anywhere) |
| `after` | `tally`, `level:<id>`, `expert_wall`, `the_end` |
| `belt` | the special on the belt at the start (`none` default; featured routes only) |
| `then`, `source`, `prefix` | as the 1.0 ROUTES keys (`prefix=<file>@<marker>`) |
| `expect` | comma-separated `key:value` checks of the route test; lists with `+` (`letters:1+3`), ranges with `..` (`ticks:1092..2185`). The 1.0 keys (`hurts`, `min_checkpoints`, `min_spots`, `min_secrets`, `letters`, `words`, `lives_gained`, `no_enemies`, `ticks`, `min_score`, `gates`, `glider`, `boss_hits`, `unlocked`, `pair_ticks`, `min_wind`, `secrets`) plus `painting:<index>`, `wipes:<max>`, `eggs:<max>`, `hatches:<min>`, `x2_gates:<min>` |

- **Names**: `<id>.inputs` (Beginner; the only route of an Expert-only stage), `<id>.expert.inputs`; featured routes
  `<id>.<tag>.inputs`; co-op `<id>_coop.inputs` / `<id>_coop.expert.inputs`. Book II and co-op routes never carry a
  weapon suffix: they are club routes, and the belt-invariance runner replays each with the hammer, the axe, the
  swirling axe and the spear on the belt and demands identical digests.
- **Body**: run-length entries `ticks:KEYS` with the keys `L R U D F K` and **`S` (swap)**; `S` held for one tick is
  one swap. Two players: one key set per slot separated by `|` (`8:R|R,10:RU|,4:DF|DF`); an empty part is idle. A
  file without `|` and without `players=2` is a single-player route and is parsed exactly as in 1.0.
- **Recording**: `--record=<file>` (debug builds) writes every slot's sampled flags and a header skeleton: two people
  play the stage with pads in the windowed game and the file is a tick-exact proof.
- Counts at G3: 31 solo club routes (11 Beginner + 20 Expert cells), about 6 featured routes, 57 co-op routes.

### 15.10 Checklist additions

- [ ] Book II: validator `--strict` clean; a club route per difficulty with a header; belt invariance green; the
      painting at its index and off the main path; signs before every new mechanic.
- [ ] Co-op: `coop_of` / `coop_base_hash` set; P2 start; 2+ gates on the main path (1 for a sub-stage), each with a
      tablet and a drop gift; a third of the enemies with traits, every chokepoint guard with one; keeper halls 4 rows
      high; flower pots landing at most 6 rows under the ledge they serve; `window=` set on capped records; validator
      `--coop` clean; `bash .tools/gd.sh test coop_gates` refuses every gate solo; co-op routes for both difficulties.
- [ ] Signs: every text at most 3 board lines (about 60 characters); the music context of the 15.2 table.
- [ ] Arena: 20 x 12, row 0 empty, spawns for `players`, cookpots, bot graph baked and its bot test green per mode.

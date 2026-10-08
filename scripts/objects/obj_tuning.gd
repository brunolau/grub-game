class_name ObjTuning
extends RefCounted
## Numbers of the objects / items / fx module that are not in [Tuning] yet (ARCHITECTURE.md 1.2: a module keeps
## private constants until core adopts them). Units as in Tuning: px = logical px, v16 = 1/16 px per tick, ticks.
##
## Marks: [G n] = GAMEPLAY.md section n, [P n] = PHYSICS.md section n, [M n] = ASSET_MANIFEST.md section n,
## [own] = a decision of this module (cosmetic timing, or a rule the specs leave open).

# =================================================================================================================
# Dropped items and bones [G 4.2] [G 4.5]
# =================================================================================================================
const DROP_GRAVITY: int = 9          ## v16 per tick; dropped items are lighter than the hero
const DROP_TERMINAL: int = 256       ## v16; the fall speed stays below this value
const DROP_BOUNCE_SHIFT: int = 1     ## a bounce keeps half of the impact speed (speed >> 1): about half the height
const DROP_GROUND_FRICTION: int = 8  ## v16 taken from |xvel| on every bounce
## An impact slower than this ends the bouncing and the item lies still. Without it the whole-pixel integration
## settles into an endless 6 px hop (landing speed 60). [own]
const DROP_REST_MAX_YVEL: int = 64
## Dropped bonus items alive at once; further ones are not created. The original has 32 slots for them, so a boss
## burst of Tuning.BOSS_BURST_ITEMS shows as many as fit (performance budget: ARCHITECTURE.md 11).
const MAX_DROPPED_ITEMS: int = 32
const BURST_XVEL: int = 48           ## first item of a fan burst (bones, grenade, boss), v16
const BURST_YVEL: int = -128         ## v16
const FAN_STEP: int = 16             ## every second item of a fan: 16 v16 narrower and 16 v16 higher
const FAN_CYCLE: int = 16            ## a fan repeats after this many items [own]
const BONE_SCATTER_DY: int = -48     ## scattered energy starts this far above the hero's feet
const SPOT_THROW_XVEL: int = 48      ## item thrown out of a small hidden spot, v16
const SPOT_THROW_YVEL: int = -112    ## v16
const SPOT_FACE_YVEL: int = -64      ## item pushed out of a wall or ceiling spot, v16 [own]
const SKY_DROP_XVEL_STEP: int = 16   ## several sky drops of one spot spread by this much, v16 [own]
const GIANT_BOUNCE_MIN_YVEL: int = 128  ## a giant bonus falling at least this fast bounces off the hero once
const GIANT_BOUNCE_XVEL: int = 32    ## sideways speed after that bounce, v16, random sign
const BONE_SPIN_FPS: int = 10        ## [M 7]

# =================================================================================================================
# Item values that have no table in the manifest [G 3.2] [G 4.1]
# =================================================================================================================
const WATER_BUCKET_POINTS: int = 500     ## "scores like food"
const RANDOM_SKULL_PER_95: int = 2       ## a thrown random bonus is a skull 2 times in 95 ...
const RANDOM_KILL_ALL_PER_95: int = 1    ## ... and a kill-all item once in 95
const RANDOM_ROLL: int = 95

# =================================================================================================================
# Screen shakes started by this module [P 13.3]
# =================================================================================================================
const SHAKE_SKULL: int = 7
const SHAKE_GIANT_BOUNCE: int = 7
const SHAKE_KILL_ALL: int = 9
const SHAKE_COLUMN: int = 7

# =================================================================================================================
# Objects
# =================================================================================================================
const PLATFORM_DEFAULT_DIR: int = 2      ## right [P 11.4]
const PLATFORM_DEFAULT_SPEED: int = 2    ## px per tick
const PLATFORM_DEFAULT_TRAVEL: int = 44  ## ticks at full speed before reversing
const DROPPER_BELOW_MAP_ROWS: int = 3    ## a dropper stops this many rows below the map [P 11.4]
const COLUMN_DEFAULT_RISE: int = 2       ## tiles
const COLUMN_TRIGGER_MARGIN: int = 4     ## default trigger: this many tiles around the block [own]
const SPRING_DEFAULT_POWER: int = -224   ## v16, the big enemy bounce [P 9]
const HIT_WOBBLE_TICKS: int = 6          ## scenery wobbles this long after a hit [own]
const BLOCK_HIT_DEBRIS: int = 4          ## debris bits per hit on a breakable block [G 4.4]
const BLOCK_BREAK_DEBRIS: int = 8        ## bits of the final hit
const SPOT_HIT_DEBRIS: int = 3           ## crumbs per hit on a hidden spot [own]
const SPOT_OPEN_DEBRIS: int = 6
const CONTAINER_DEBRIS: int = 6

# Terrain-atlas tiles used as hidden-spot looks [M 10.1]
const ATLAS_AUTO: int = -1
const ATLAS_BLOCK: int = 7
const ATLAS_INSET: int = 15

# =================================================================================================================
# Co-op objects of 2.0 [G 13.9.7] [P C] - the shared numbers are PartyTuning's; these are the objects module's own
# =================================================================================================================
## A party's hero counts as "standing on" a plate while his feet are at most this far above its floor (and he is not
## rising): a screen shake lifts a standing hero for a tick without releasing the plate. [own]
const PLATE_FEET_SLACK_PX: int = 8
const PLATE_DEFAULT_W: int = 2           ## cells [G 13.9.7]
const PLATE_SINK_PX: int = 2             ## a pressed plate is drawn this much lower [G 13.9.7]
const PLATE_BLINK_TICKS: int = 24        ## a timed plate blinks in its last second ... [M plate]
const PLATE_BLINK_FPS: int = 8           ## ... at this rate
## A plate / drum / keeper column never moves into a hero: a hero occupies the cells his feet point lies under, this
## far to each side of it and this high (the tile probes of PHYSICS.md 11.2 reach about as far). [own]
const HERO_BODY_HALF_W_PX: int = 7
const HERO_BODY_H_PX: int = 32
## Drums: the count-in (three blips 8 ticks apart, then "go") plays while a hatched hero stands within this many px
## of every drum of the bond. [G 13.9.3] [own reach] The spacing is core's, shared with the enemy bonds.
const COUNT_IN_SPACING_TICKS: int = PartyTuning.COUNT_IN_SPACING_TICKS
const COUNT_IN_REACH_PX: int = 40
## Lightning (`zones/lightning`, world-A; PHYSICS.md C.16 lists it here): a darkening cloud marks a column this many
## ticks before its bolt (the telegraph), the bolt lasts LIGHTNING_BOLT_TICKS, and a struck `skin=nest` one-way cell
## of the Storm Roc's nest burns LIGHTNING_BURN_TICKS. [G 13.3 / 13.6] *(tune)*
const LIGHTNING_MARK_TICKS: int = 22
const LIGHTNING_BOLT_TICKS: int = 4
const LIGHTNING_BURN_TICKS: int = 66
const DRUM_HIT_FPS: int = 16             ## [M drum]
## See-saw [G 13.9.7]: its two end platforms are SEESAW_STEP_PX apart in height; the low end's top lies
## SEESAW_LOW_TOP_PX over the floor, so a hero standing on the floor there is inside its ride band (he rides it), and
## the high end's top lies one row (+1 px) over the floor: a ledge N rows over the floor is a fall of N - 1 rows onto
## the high end (PHYSICS.md C.17 table). [own]
const SEESAW_DEFAULT_LEN: int = 5
const SEESAW_STEP_PX: int = 16
const SEESAW_LOW_TOP_PX: int = 1
const SEESAW_FLIP_TICKS: int = 2         ## it flips within 2 ticks
const SEESAW_LANDING_MIN_YVEL: int = 16  ## a body landing on the high end at this speed or faster flips it
const SEESAW_LIFT_ONLY_YVEL: int = -64   ## a launch weaker than this only lifts the hero on the low end
## Heave boulder [G 13.9.7]: falls 1 tile per 2 ticks when unsupported; a hero pushes it while his feet are at most
## this far from its face (the wall probe stops him WALL_PROBE + 1 px away). [own reach]
const BOULDER_FALL_TICKS: int = 2
const BOULDER_PUSH_REACH_PX: int = Tuning.WALL_PROBE + 3
const BOULDER_CELLS: int = 2             ## 2 x 2 cells
## Flower pot [G 13.9.7]: a strike pushes it at this speed (v16) in the strike direction; it slides to the ledge's
## edge (or a wall) and falls with the hero's gravity, keeping its speed, then becomes a spring where it lands
## (SPRING_DEFAULT_POWER: a 105 px rise from the spring's top, so designers count on a ledge 6 rows above the floor
## it took root on; 7 rows is 3 px under the apex - see FlowerPot).
const FLOWER_POT_PUSH_XVEL: int = 32     ## [own]
const FLOWER_POT_SMASH_TICKS: int = 4    ## smash frame, then the sprout [M flower_pot]
const FLOWER_POT_ANIM_FPS: int = 12      ## [M flower_pot]
const PULLEY_TURN_FPS: int = 12          ## [M pulley]
## Team gate: a partner farther than one view from the hero who entered arrives as an egg [G 13.9.2].
const GATE_PARTNER_RANGE_Y_PX: int = Tuning.VIEW_ROWS * Tuning.TILE


## True when the co-op party rules apply (PHYSICS.md C.0 #2): co-op mode with more than one hero. A party of one,
## single-player and versus never take the party branches of this module.
static func coop_rules(level: LevelBase) -> bool:
	return level != null and Game.mode == Defs.GameMode.COOP and level.hero_count() > 1


## Play the 2.0 cue `event` when its AudioTable row exists (core adds the rows with its audio batches), else
## `fallback` (a 1.0 cue; &"" = silence). Audio.play_sfx refuses an unknown event with an error.
static func play_cue(event: StringName, fallback: StringName = &"") -> void:
	if AudioTable.SFX.has(event):
		Audio.play_sfx(event)
	elif fallback != &"" and AudioTable.SFX.has(fallback):
		Audio.play_sfx(fallback)


## Number of set bits of a slot mask (bit `slot` per hero).
static func bit_count(mask: int) -> int:
	var count: int = 0
	while mask != 0:
		count += mask & 1
		mask >>= 1
	return count


## True when a hatched hero (alive, not an egg) occupies tile (col, row) by the body rule of HERO_BODY_HALF_W_PX /
## HERO_BODY_H_PX: the cells a tile mover must not move into. 2.0 G33 / G53: only a hero who COUNTS
## (PlayerBase.counts_for_coop) stops a mover - an IDLE co-op hero is no obstacle (the mover pushes him out of its
## cells, [method push_idle_out]). Single-player: counts_for_coop() is is_party_targetable() (nobody is idle there).
static func hero_in_cell(level: LevelBase, col: int, row: int) -> bool:
	if level == null:
		return false
	for hero: PlayerBase in level.contact_order():
		if not hero.counts_for_coop():
			continue
		if _body_in_cell(hero, col, row):
			return true
	return false


static func _body_in_cell(hero: PlayerBase, col: int, row: int) -> bool:
	var x: int = hero.sim_pos.x
	var y: int = hero.sim_pos.y
	if col < (x - HERO_BODY_HALF_W_PX) >> 4 or col > (x + HERO_BODY_HALF_W_PX) >> 4:
		return false
	return row <= (y - 1) >> 4 and row >= (y - HERO_BODY_H_PX) >> 4


## G53 (DESIGN.md G33 follow-up, the lead designer's ruling of phase 3): a tile mover (a plate / keeper / drum door, a
## column, a heave boulder) has just filled the cells `filled` of its block `block` (tile rects). Every hatched, living
## IDLE hero whose body (the hero_in_cell rule) overlaps a filled cell is pushed out of them, unharmed: sideways to the
## nearer side of the block where his body fits (no wall cell, no other part of a mover), else up onto the block's
## top. No damage, no reset of his idle timer; level.notify_hero_teleported follows (the doze reach). Nothing for an
## egg, a dead hero or a hero who counts (the mover waited for him).
static func push_idle_out(level: LevelBase, block: Rect2i, filled: Rect2i) -> void:
	if level == null or level.hero_count() <= 1:
		return
	for hero: PlayerBase in level.contact_order():
		if hero.dead or hero.down or not hero.idle:
			continue
		var hit: bool = false
		for row: int in range(filled.position.y, filled.end.y):
			for col: int in range(filled.position.x, filled.end.x):
				if _body_in_cell(hero, col, row):
					hit = true
					break
			if hit:
				break
		if not hit:
			continue
		var y: int = hero.sim_pos.y
		var left_x: int = block.position.x * Tuning.TILE - HERO_BODY_HALF_W_PX - 1
		var right_x: int = block.end.x * Tuning.TILE + HERO_BODY_HALF_W_PX
		var go_left: bool = hero.sim_pos.x - left_x <= right_x - hero.sim_pos.x
		var target: Vector2i = Vector2i(-1, -1)
		for attempt: int in 2:
			var x: int = left_x if go_left != (attempt == 1) else right_x
			if _body_fits(level, x, y):
				target = Vector2i(x, y)
				break
		if target.x < 0:
			# Neither side is free: up onto the block's top.
			target = Vector2i(clampi(hero.sim_pos.x, block.position.x * Tuning.TILE, block.end.x * Tuning.TILE - 1),
					block.position.y * Tuning.TILE)
		hero.teleport(target)
		hero.yvel = 0
		level.notify_hero_teleported(hero)


## True when a hero body (the hero_in_cell rule) with its feet at (x, y) touches no wall cell of the grid.
static func _body_fits(level: LevelBase, x: int, y: int) -> bool:
	var grid: TileGrid = level.grid
	for row: int in range((y - HERO_BODY_H_PX) >> 4, ((y - 1) >> 4) + 1):
		for col: int in range((x - HERO_BODY_HALF_W_PX) >> 4, ((x + HERO_BODY_HALF_W_PX) >> 4) + 1):
			if not grid.in_bounds(col, row) or grid.side_at(col, row) == TileGrid.SIDE_WALL:
				return false
	return true

# =================================================================================================================
# Effects (cosmetic) [M 9]
# =================================================================================================================
const MAX_POPUPS: int = 16           ## score pop-ups alive at once [G 2]
const POPUP_BLINK_TICKS: int = 8     ## a pop-up blinks during its last ticks [own]
const DEBRIS_DEFAULT_COUNT: int = 4
const DEBRIS_MAX_COUNT: int = 12
const DEBRIS_LIFE: int = 22
const DEBRIS_GRAVITY: int = 14       ## v16 per tick
const DEBRIS_XVEL: int = 56          ## fastest sideways speed of a piece, v16
const DEBRIS_YVEL: int = -96         ## base upward speed of a piece, v16
const DUST_LIFE: int = 8
## Vertical bob of a placed item in ART px over one cycle of 24 ticks (peak = Tuning.ITEM_BOB_PX logical px).
const BOB_ART: Array[int] = [0, 0, 1, 1, 2, 3, 4, 5, 5, 6, 6, 6, 6, 6, 5, 5, 4, 3, 2, 1, 1, 0, 0, 0]


## Start velocity (xvel, yvel) of item number `index` (0-based) of a fan burst whose first item starts with
## (`base_xvel`, `base_yvel`): items leave in pairs to both sides, every pair FAN_STEP narrower (crossing over to
## the other side once the speed passes zero) and FAN_STEP faster upward than the pair before. Bursts larger than
## FAN_CYCLE repeat the fan, every repeat a little wider, so that big bursts do not fly out of sight.
static func fan_velocity(index: int, base_xvel: int, base_yvel: int) -> Vector2i:
	var cycle: int = index / FAN_CYCLE
	var pair: int = (index % FAN_CYCLE) >> 1
	var side: int = 1 if base_xvel >= 0 else -1
	if (index & 1) == 1:
		side = -side
	var spread: int = absi(base_xvel) - pair * FAN_STEP + cycle * (FAN_STEP >> 1)
	return Vector2i(side * spread, base_yvel - pair * FAN_STEP)


## Frame of a one-shot or looping sheet animation after `age` ticks at `fps` frames per second.
static func anim_frame(age: int, fps: int) -> int:
	return age * fps / Tuning.ANIM_TICKS_PER_SECOND


## Ticks a one-shot animation of `frames` frames at `fps` lasts (rounded up).
static func anim_ticks(frames: int, fps: int) -> int:
	return (frames * Tuning.ANIM_TICKS_PER_SECOND + fps - 1) / fps

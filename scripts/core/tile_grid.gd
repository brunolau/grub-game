class_name TileGrid
extends RefCounted
## Logical collision grid of a level: the four tile property tables of PHYSICS.md 11.1.
##
## CONTRACT FILE (docs/ARCHITECTURE.md 3.2 and 7.4). Owner: core. This class is the ONLY definition of what a
## level-file tile character means physically; the world loader must build collision with [method from_rows] and
## the hero / enemies must query collision through the getters below (never through TileMapLayer or physics).
##
## Cells are 16 x 16 logical px. Out-of-range cells read as empty (FLOOR 0, SIDE 0, FLAGS 0, no profile, no material).
## Level format 2 (2.0) adds one character, the tar floor ':' (CH_TAR), and a fifth per-cell table, the material
## (MATERIAL_TAR = the TAR flag of PHYSICS.md C.5); a format-1 level builds exactly the 1.0 tables.
##
## Difference to the original engine: the HEIGHT byte is replaced by a `profile` id, because our art has 45 degree
## and half-gradient slopes instead of the original 1:3 gradient. `has_profile()` is the original's
## "HEIGHT is non-zero" test and `surface_offset()` the original's surface offset; the hero rules of
## PHYSICS.md 11.2 apply unchanged.

# --- FLOOR values (tested at the feet point) -----------------------------------------------------------------------
const FLOOR_EMPTY: int = 0
const FLOOR_SOLID: int = 1        ## floor, ice = 0
const FLOOR_ICE_1: int = 2        ## floor, ice = 1
const FLOOR_ICE_2: int = 3        ## floor, ice = 2
const FLOOR_ICE_3: int = 4        ## floor, ice = 3
const FLOOR_HATCH: int = 5        ## floor only while drop_timer == 0
const FLOOR_DEADLY: int = 6       ## spikes, liquids
const FLOOR_NOTHING: int = 7

# --- SIDE values (wall probe and body probes) ------------------------------------------------------------------------
const SIDE_OPEN: int = 0
const SIDE_WALL: int = 1
const SIDE_DEADLY: int = 2

# --- FLAGS bits ------------------------------------------------------------------------------------------------------
const FLAG_CEILING_MASK: int = 0x0F
const CEILING_NONE: int = 0
const CEILING_SOLID: int = 1      ## stops upward motion (head probe)
const CEILING_DEADLY: int = 2
const FLAG_FLY_SOURCE: int = 0x10 ## cosmetic
const FLAG_STEP_ON: int = 0x20    ## cosmetic: shows its pressed picture while the feet are on it
const FLAG_FOREGROUND: int = 0x40 ## drawn in front of sprites
const FLAG_ANIMATED: int = 0x80   ## animated tile

# --- Surface profiles (replace the original HEIGHT byte) --------------------------------------------------------------
const PROFILE_NONE: int = 0           ## flat, the original's HEIGHT == 0
const PROFILE_FLAT_GLUE: int = 1      ## flat (offset 0) but counts as profiled: lets the hero step down onto it
const PROFILE_UP_RIGHT_45: int = 2    ## '/'  rises to the right, offsets 15..0
const PROFILE_UP_LEFT_45: int = 3     ## '\'  rises to the left,  offsets 0..15
const PROFILE_UP_RIGHT_LOW: int = 4   ## '1'  gentle, low half,   offsets 15..8
const PROFILE_UP_RIGHT_HIGH: int = 5  ## '2'  gentle, high half,  offsets 7..0
const PROFILE_UP_LEFT_HIGH: int = 6   ## '3'  gentle, high half,  offsets 0..7
const PROFILE_UP_LEFT_LOW: int = 7    ## '4'  gentle, low half,   offsets 8..15
const PROFILE_LOWERED_BASE: int = 16  ## 16 + n: flat surface lowered by n px (1..15), "soft" ground

# --- Legend characters of the level file (docs/ARCHITECTURE.md 7.4) ---------------------------------------------------
const CH_AIR: String = "."
const CH_SOLID_A: String = "#"
const CH_SOLID_B: String = "%"
const CH_SOLID_INVISIBLE: String = ";"
const CH_ONEWAY_A: String = "-"
const CH_ONEWAY_B: String = "="
const CH_HATCH: String = "_"
const CH_SLOPE_UP_RIGHT: String = "/"
const CH_SLOPE_UP_LEFT: String = "\\"
const CH_GENTLE_UR_LOW: String = "1"
const CH_GENTLE_UR_HIGH: String = "2"
const CH_GENTLE_UL_HIGH: String = "3"
const CH_GENTLE_UL_LOW: String = "4"
const CH_SPIKES_FLOOR: String = "^"
const CH_SPIKES_CEILING: String = "!"
const CH_LIQUID: String = "~"
const CH_WALL_INVISIBLE: String = "|"
const CH_KILL: String = "+"
const CH_PLAYER_START: String = "@"
const CH_SPOT_SMALL: String = "?"
const CH_SPOT_BIG: String = "*"
const CH_BREAKABLE: String = "$"
## Tar floor (level format 2, PHYSICS.md C.5): set-A ground (floor, wall, ceiling as '#') whose flat surface lies
## Tuning.TAR_SURFACE_DROP_PX lower (profile PROFILE_TAR) and whose material is MATERIAL_TAR. Honey and syrup are
## its Feast Land skins (meta `liquid`); the rules are the same.
const CH_TAR: String = ":"
## Every fixed (non-letter) legend character.
const LEGEND_CHARS: String = ". #%;-=_/\\1234^!~|+@?*$:"

# --- Materials (level format 2): the TAR flag of PHYSICS.md C.5, kept beside the four 1.0 tables -----------------------
## Ordinary cell (every cell of a format-1 level).
const MATERIAL_NONE: int = 0
## Tar floor ':' : heroes wade (Tuning.TAR_WALK_CAP, TAR_AIR_CAP after a tar take-off, TAR_JUMP_IMPULSE_TICKS of
## jump thrust), ground enemies are slowed the same way, dropped items stop dead (PHYSICS.md C.5). Read it with
## [method is_tar].
const MATERIAL_TAR: int = 1
## Surface profile of the tar floor: a flat surface lowered by Tuning.TAR_SURFACE_DROP_PX (6) px.
const PROFILE_TAR: int = PROFILE_LOWERED_BASE + Tuning.TAR_SURFACE_DROP_PX

## Width in tiles.
var cols: int = 0
## Height in tiles.
var rows: int = 0
## Ice level 0..3 of terrain set A floors ('#', '-', slopes above '#').
var ice_a: int = 0
## Ice level 0..3 of terrain set B floors ('%', '=', slopes above '%').
var ice_b: int = 0

var _floor: PackedByteArray = PackedByteArray()
var _side: PackedByteArray = PackedByteArray()
var _flags: PackedByteArray = PackedByteArray()
var _profile: PackedByteArray = PackedByteArray()
var _chars: PackedByteArray = PackedByteArray()
## MATERIAL_* per cell (format 2; all MATERIAL_NONE in a format-1 level).
var _material: PackedByteArray = PackedByteArray()


## Create an empty (all air) grid.
func _init(p_cols: int = 0, p_rows: int = 0) -> void:
	resize(p_cols, p_rows)


## Reset to an all-air grid of the given size.
func resize(p_cols: int, p_rows: int) -> void:
	cols = maxi(p_cols, 0)
	rows = maxi(p_rows, 0)
	var count: int = cols * rows
	_floor.resize(count)
	_floor.fill(0)
	_side.resize(count)
	_side.fill(0)
	_flags.resize(count)
	_flags.fill(0)
	_profile.resize(count)
	_profile.fill(0)
	_chars.resize(count)
	_chars.fill(46)  # '.'
	_material.resize(count)
	_material.fill(MATERIAL_NONE)


## Build a grid from the rows of a level file's [tiles] section.
## `letter_tiles` maps a legend letter (one-character String) to the fixed tile character it stands on
## (its `tile=` parameter); letters without an entry are air. Rows shorter than the widest row are padded with air.
static func from_rows(
		tile_rows: PackedStringArray, p_ice_a: int = 0, p_ice_b: int = 0, letter_tiles: Dictionary = {}
) -> TileGrid:
	var width: int = 0
	for line: String in tile_rows:
		width = maxi(width, line.length())
	var grid: TileGrid = TileGrid.new(width, tile_rows.size())
	grid.ice_a = clampi(p_ice_a, 0, Tuning.ICE_MAX)
	grid.ice_b = clampi(p_ice_b, 0, Tuning.ICE_MAX)
	# Pass 1: characters (slopes look at the cell below, so all characters must be known first). Each distinct
	# character of the file is resolved once.
	var air: int = CH_AIR.unicode_at(0)
	var resolved: Dictionary = {}
	for row: int in tile_rows.size():
		var line: String = tile_rows[row]
		var base: int = row * width
		for col: int in line.length():
			var source: int = line.unicode_at(col)
			var code: int = resolved.get(source, -1)
			if code < 0:
				code = resolve_char(String.chr(source), letter_tiles).unicode_at(0)
				resolved[source] = code
			if code != air:
				grid._chars[base + col] = code
	# Pass 2: collision properties, then the slope-foot glue. The new grid is all air with every property 0, which
	# is exactly what both steps produce for an air cell, and only a solid-type floor can carry glue.
	for i: int in grid._chars.size():
		if grid._chars[i] != air:
			grid._apply_char(i % width, i / width)
	for i: int in grid._floor.size():
		var floor_value: int = grid._floor[i]
		if floor_value >= FLOOR_SOLID and floor_value <= FLOOR_ICE_3:
			grid._update_glue(i % width, i / width)
	return grid


## Fixed tile character a level-file character stands for: letters resolve through `letter_tiles`, the shortcut
## characters '@', '?', '*', '$' resolve to their built-in tile, unknown characters to air.
static func resolve_char(ch: String, letter_tiles: Dictionary = {}) -> String:
	if letter_tiles.has(ch):
		return resolve_char(str(letter_tiles[ch]))
	match ch:
		CH_PLAYER_START, " ":
			return CH_AIR
		CH_SPOT_SMALL, CH_SPOT_BIG:
			return CH_SOLID_A
		CH_BREAKABLE:
			return CH_SOLID_INVISIBLE
	if LEGEND_CHARS.contains(ch):
		return ch
	return CH_AIR


## True when (col, row) is inside the grid.
func in_bounds(col: int, row: int) -> bool:
	return col >= 0 and row >= 0 and col < cols and row < rows


## FLOOR value at a cell (0 outside the grid).
func floor_at(col: int, row: int) -> int:
	if col < 0 or row < 0 or col >= cols or row >= rows:
		return 0
	return _floor[row * cols + col]


## SIDE value at a cell (0 outside the grid).
func side_at(col: int, row: int) -> int:
	if col < 0 or row < 0 or col >= cols or row >= rows:
		return 0
	return _side[row * cols + col]


## FLAGS byte at a cell (0 outside the grid).
func flags_at(col: int, row: int) -> int:
	if col < 0 or row < 0 or col >= cols or row >= rows:
		return 0
	return _flags[row * cols + col]


## Ceiling nibble at a cell: CEILING_NONE, CEILING_SOLID or CEILING_DEADLY.
func ceiling_at(col: int, row: int) -> int:
	return flags_at(col, row) & FLAG_CEILING_MASK


## Surface profile id at a cell (PROFILE_NONE outside the grid).
func profile_at(col: int, row: int) -> int:
	if col < 0 or row < 0 or col >= cols or row >= rows:
		return 0
	return _profile[row * cols + col]


## The original's "HEIGHT(col, row) is non-zero".
func has_profile(col: int, row: int) -> bool:
	return profile_at(col, row) != PROFILE_NONE


## Surface offset in px below the top of cell (col, row) for a feet point at logical x (0..15). [P 11.1 HEIGHT]
func surface_offset(col: int, row: int, x: int) -> int:
	return profile_offset(profile_at(col, row), x)


## Surface offset of a profile id for a logical x.
static func profile_offset(profile: int, x: int) -> int:
	var local: int = x & 15
	match profile:
		PROFILE_UP_RIGHT_45:
			return 15 - local
		PROFILE_UP_LEFT_45:
			return local
		PROFILE_UP_RIGHT_LOW:
			return 15 - (local >> 1)
		PROFILE_UP_RIGHT_HIGH:
			return 7 - (local >> 1)
		PROFILE_UP_LEFT_HIGH:
			return local >> 1
		PROFILE_UP_LEFT_LOW:
			return 8 + (local >> 1)
	if profile > PROFILE_LOWERED_BASE and profile < PROFILE_LOWERED_BASE + 16:
		return profile - PROFILE_LOWERED_BASE
	return 0


## Material of a cell (MATERIAL_NONE outside the grid): MATERIAL_TAR for a tar floor ':'.
func material_at(col: int, row: int) -> int:
	if col < 0 or row < 0 or col >= cols or row >= rows:
		return MATERIAL_NONE
	return _material[row * cols + col]


## True when (col, row) is a tar floor ':' (PHYSICS.md C.5): a hero whose grounded feet tile is tar wades; ground
## enemies on it move at most Tuning.TAR_WALK_CAP; dropped items landing on it stop dead. False outside the grid.
func is_tar(col: int, row: int) -> bool:
	return material_at(col, row) == MATERIAL_TAR


## 2.0 (P2.12, player-B's A53 pass): true when any cell of the grid is a tar floor ':' (PHYSICS.md C.5) - one native
## search instead of a scan through material_at (HeroClimb asks once per level load whether the stage has tar).
## A set_char that changes a cell is seen at once.
func has_tar() -> bool:
	return _material.has(MATERIAL_TAR)


## True when a FLOOR value is a walkable floor for something that ignores hatches (enemies, dropped items,
## drop platforms: "FLOOR not 0 and not 6", PHYSICS.md 11.4).
static func is_ground(floor_value: int) -> bool:
	return floor_value >= FLOOR_SOLID and floor_value <= FLOOR_HATCH


## Ice level 0..3 a FLOOR value sets on the hero.
static func floor_ice(floor_value: int) -> int:
	if floor_value >= FLOOR_ICE_1 and floor_value <= FLOOR_ICE_3:
		return floor_value - FLOOR_SOLID
	return 0


## Fixed legend character stored at a cell ("." outside the grid).
func get_char(col: int, row: int) -> String:
	if col < 0 or row < 0 or col >= cols or row >= rows:
		return CH_AIR
	return String.chr(_chars[row * cols + col])


## Replace the tile at a cell by a fixed legend character and update the collision tables of the cell and of the
## neighbours that depend on it (slopes above, slope-foot glue). Used by breakable blocks and rising columns
## through [method LevelBase.set_cell].
func set_char(col: int, row: int, ch: String) -> void:
	if not in_bounds(col, row):
		return
	_chars[row * cols + col] = resolve_char(ch).unicode_at(0)
	_apply_char(col, row)
	if row > 0:
		_apply_char(col, row - 1)
	for r: int in range(row - 1, row + 3):
		for c: int in range(col - 1, col + 2):
			if in_bounds(c, r):
				_update_glue(c, r)


## Low-level setter for one cell (does not touch the stored legend character nor the material). For tests and
## special tiles.
func set_props(col: int, row: int, floor_value: int, side_value: int, flags_value: int, profile: int) -> void:
	if not in_bounds(col, row):
		return
	var i: int = row * cols + col
	_floor[i] = floor_value
	_side[i] = side_value
	_flags[i] = flags_value
	_profile[i] = profile


## Add (or clear) flag bits at a cell without changing the rest, e.g. FLAG_FOREGROUND from the loader.
func set_flag_bits(col: int, row: int, bits: int, enabled: bool) -> void:
	if not in_bounds(col, row):
		return
	var i: int = row * cols + col
	if enabled:
		_flags[i] = _flags[i] | bits
	else:
		_flags[i] = _flags[i] & ~bits


## Width of the level in logical px.
func width_px() -> int:
	return cols * Tuning.TILE


## Height of the level in logical px.
func height_px() -> int:
	return rows * Tuning.TILE


## Exclusive upper bound of the hero's x commit rule for this level (PHYSICS.md 2).
func x_max_excl() -> int:
	return mini(Tuning.X_MAX_EXCL, cols * Tuning.TILE - Tuning.X_MIN)


func _floor_for_set(set_b: bool) -> int:
	return FLOOR_SOLID + (ice_b if set_b else ice_a)


func _apply_char(col: int, row: int) -> void:
	var i: int = row * cols + col
	var ch: String = String.chr(_chars[i])
	var floor_value: int = FLOOR_EMPTY
	var side_value: int = SIDE_OPEN
	var flags_value: int = 0
	var profile: int = PROFILE_NONE
	var material: int = MATERIAL_NONE
	match ch:
		CH_SOLID_A:
			floor_value = _floor_for_set(false)
			side_value = SIDE_WALL
			flags_value = CEILING_SOLID
		CH_TAR:
			# Format 2: '#' with a surface 6 px lower and the TAR material (PHYSICS.md C.5).
			floor_value = _floor_for_set(false)
			side_value = SIDE_WALL
			flags_value = CEILING_SOLID
			profile = PROFILE_TAR
			material = MATERIAL_TAR
		CH_SOLID_B:
			floor_value = _floor_for_set(true)
			side_value = SIDE_WALL
			flags_value = CEILING_SOLID
		CH_SOLID_INVISIBLE:
			floor_value = FLOOR_SOLID
			side_value = SIDE_WALL
			flags_value = CEILING_SOLID
		CH_ONEWAY_A:
			floor_value = _floor_for_set(false)
		CH_ONEWAY_B:
			floor_value = _floor_for_set(true)
		CH_HATCH:
			floor_value = FLOOR_HATCH
		CH_SLOPE_UP_RIGHT:
			floor_value = _floor_for_set(get_char(col, row + 1) == CH_SOLID_B)
			profile = PROFILE_UP_RIGHT_45
		CH_SLOPE_UP_LEFT:
			floor_value = _floor_for_set(get_char(col, row + 1) == CH_SOLID_B)
			profile = PROFILE_UP_LEFT_45
		CH_GENTLE_UR_LOW:
			floor_value = _floor_for_set(get_char(col, row + 1) == CH_SOLID_B)
			profile = PROFILE_UP_RIGHT_LOW
		CH_GENTLE_UR_HIGH:
			floor_value = _floor_for_set(get_char(col, row + 1) == CH_SOLID_B)
			profile = PROFILE_UP_RIGHT_HIGH
		CH_GENTLE_UL_HIGH:
			floor_value = _floor_for_set(get_char(col, row + 1) == CH_SOLID_B)
			profile = PROFILE_UP_LEFT_HIGH
		CH_GENTLE_UL_LOW:
			floor_value = _floor_for_set(get_char(col, row + 1) == CH_SOLID_B)
			profile = PROFILE_UP_LEFT_LOW
		CH_SPIKES_FLOOR:
			floor_value = FLOOR_DEADLY
		CH_SPIKES_CEILING:
			flags_value = CEILING_DEADLY
		CH_LIQUID:
			floor_value = FLOOR_DEADLY
			side_value = SIDE_DEADLY
			flags_value = FLAG_ANIMATED
		CH_WALL_INVISIBLE:
			side_value = SIDE_WALL
		CH_KILL:
			floor_value = FLOOR_DEADLY
			side_value = SIDE_DEADLY
	# Keep loader-set cosmetic bits (foreground, fly source, step-on) when a cell is rewritten.
	flags_value |= _flags[i] & (FLAG_FLY_SOURCE | FLAG_STEP_ON | FLAG_FOREGROUND)
	_floor[i] = floor_value
	_side[i] = side_value
	_flags[i] = flags_value
	_profile[i] = profile
	_material[i] = material


## A flat floor at the foot of a slope becomes PROFILE_FLAT_GLUE so that the step-down rule of PHYSICS.md 11.1
## (FLOOR 0 special case) carries the hero off the slope without a one-pixel fall.
func _update_glue(col: int, row: int) -> void:
	var i: int = row * cols + col
	var profile: int = _profile[i]
	if profile != PROFILE_NONE and profile != PROFILE_FLAT_GLUE:
		return
	var glue: bool = false
	var floor_value: int = _floor[i]
	if floor_value >= FLOOR_SOLID and floor_value <= FLOOR_ICE_3 and floor_at(col, row - 1) == FLOOR_EMPTY:
		var left_up: int = profile_at(col - 1, row - 1)
		var right_up: int = profile_at(col + 1, row - 1)
		glue = left_up == PROFILE_UP_LEFT_45 or left_up == PROFILE_UP_LEFT_LOW \
				or right_up == PROFILE_UP_RIGHT_45 or right_up == PROFILE_UP_RIGHT_LOW
	_profile[i] = PROFILE_FLAT_GLUE if glue else PROFILE_NONE

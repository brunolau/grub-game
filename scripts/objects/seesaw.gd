class_name Seesaw
extends SimEntity
## `objects/seesaw len=<cells>` [5] (DESIGN.md D.5, GAMEPLAY.md 13.9.7 [R13], PHYSICS.md C.17): a plank on a
## fulcrum. The fulcrum stands at the anchor's feet point (the floor); the plank reaches `len` * 8 px to each side.
## Its two halves are sprite platforms (11.4 ride rules; children of this entity, [Seesaw.End]) whose standing
## surfaces are ObjTuning.SEESAW_STEP_PX (16) apart: the low end's top lies ObjTuning.SEESAW_LOW_TOP_PX (1 px) over
## the floor (a hero standing on the floor there rides it), the high end one row higher - so a ledge N rows over the
## floor is a walk-off fall of N - 1 rows onto the high end. `facing=r` (the default) puts the high end on the right,
## `facing=l` on the left. While a flip lifts an end, its riders rise with it.
##
## A hatched hero landing on the high end (caught by its ride test with a landing speed of at least
## ObjTuning.SEESAW_LANDING_MIN_YVEL) flips the plank within ObjTuning.SEESAW_FLIP_TICKS ticks and, on that tick,
## launches every hero riding the low end with PartyTuning.seesaw_launch(landing yvel, hard landing) =
## max(-(yvel + 32) - (64 if hard), -288): 1 tile -128, 4 tiles -272, 5+ tiles -288 (171 px) for walk-off falls. A
## result weaker than ObjTuning.SEESAW_LIFT_ONLY_YVEL (-64) only lifts him (he rides the rising end). Enemies whose
## feet stand on the low end are thrown off the same way. The landing speed is the speed of the move that brought
## the hero onto the plank: the ride test runs on the next tick, after his airborne step added gravity once, so it is
## `yvel - Tuning.GRAVITY` (at the terminal speed: from his fall ticks), and the landing is hard after more than
## Tuning.HARD_LANDING_MIN_FALL_TICKS_EXCL fall ticks before that move (PHYSICS.md 6.5).
##
## A team wipe (the level reset) puts the plank back in its level-file tilt. It never dozes.

## Sheet [M seesaw_plank]: one row per length 3 / 4 / 5 / 6 cells; columns left end down, left half down, level, right
## half down, right end down. The plank rests on the "half down" frames (16 px between the ends).
const COL_LEFT_DOWN: int = 1
const COL_LEVEL: int = 2
const COL_RIGHT_DOWN: int = 3
const PLANK_MIN_LEN: int = 3
const PLANK_MAX_LEN: int = 6
## The plank's underside rests on the fulcrum's top, 30 art px over the floor [M seesaw_pivot].
const PLANK_Y_ART: float = -30.0
const ID_DUST: StringName = &"fx/dust"


## One half of the plank: a sprite platform that moves to its seesaw's target height and reports landings.
class End:
	extends PlatformBase

	## The plank it belongs to, and its side (-1 left, +1 right).
	var seesaw: Seesaw = null
	var side: int = 1
	## Standing surface y it moves to (2 ticks per flip).
	var target_top: int = 0
	## rider_mask of the previous ride test (a hero not in it who is caught now has just landed).
	var prev_mask: int = 0

	func _move_tick() -> void:
		var top: int = sim_pos.y - box_h
		if top == target_top:
			return
		var step: int = ObjTuning.SEESAW_STEP_PX / ObjTuning.SEESAW_FLIP_TICKS
		dy = clampi(target_top - top, -step, step)

	func _ride_test() -> bool:
		prev_mask = rider_mask
		return super._ride_test()

	func _ride_test_hero(hero: PlayerBase) -> bool:
		var landing_yvel: int = hero.yvel
		var fall_ticks: int = hero.fall_ticks
		var was_on: bool = (prev_mask & (1 << hero.slot)) != 0
		if super._ride_test_hero(hero):
			if not was_on and seesaw != null:
				seesaw._on_landed(self, hero, landing_yvel, fall_ticks)
			return true
		# A flip lifts the end faster than the 8 px ride band follows: keep the riders it had (they rise with it).
		if dy < 0 and was_on and not hero.dead and not hero.down \
				and hero.yvel > Tuning.PLATFORM_RIDE_MIN_YVEL_EXCL and hero.carried_on_tick != Sim.total_ticks \
				and hero.sim_pos.y > top() and hero.sim_pos.y <= top() + box_h - dy \
				and absi(hero.sim_pos.x - sim_pos.x) < box_xo + Tuning.HERO_BOX_RIDE.z:
			hero.carried_on_tick = Sim.total_ticks
			hero.ride_platform(self, dx, dy)
			return true
		return false

	func top() -> int:
		return sim_pos.y - box_h

	func _on_level_reset() -> void:
		dx = 0
		dy = 0
		ridden = false
		rider_mask = 0
		prev_mask = 0


## Length in cells (`len`).
var length_cells: int = ObjTuning.SEESAW_DEFAULT_LEN
## +1 while the right end is high, -1 while the left end is.
var high_side: int = 1
## Ticks left of the current flip (0 = at rest).
var flip_ticks: int = 0
## Statistics / tests: flips so far, and the yvel of the last launch.
var flips: int = 0
var last_launch: int = 0

var left_end: End = null
var right_end: End = null
var _start_side: int = 1
var _plank: Sprite2D = null


func _init() -> void:
	z_index = Defs.Z_PLATFORMS


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.PLATFORMS])


func _apply_params(params: Dictionary) -> void:
	length_cells = maxi(int(params.get("len", length_cells)), 2)
	_start_side = -1 if facing < 0 else 1
	high_side = _start_side
	var half: int = length_cells * Tuning.TILE / 2
	set_box(Vector3i(half * 2, ObjTuning.SEESAW_STEP_PX + ObjTuning.SEESAW_LOW_TOP_PX + 8, half))
	# The ends are children: they enter the tree (and register with Sim and the level) right after the plank, so they
	# run after it in every phase.
	left_end = _make_end(-1, half)
	right_end = _make_end(1, half)
	_place_ends(true)
	_plank = get_node_or_null(^"Plank") as Sprite2D
	_show()


func _make_end(side: int, half: int) -> End:
	var end: End = End.new()
	end.seesaw = self
	end.side = side
	end.name = "LeftEnd" if side < 0 else "RightEnd"
	end.set_box(Vector3i(half, 8, half / 2))
	add_child(end)
	return end


## The surface y of the low and the high end.
func low_top() -> int:
	return sim_pos.y - ObjTuning.SEESAW_LOW_TOP_PX


func high_top() -> int:
	return low_top() - ObjTuning.SEESAW_STEP_PX


## The end that is high (or rising to be) now.
func high_end() -> End:
	return right_end if high_side > 0 else left_end


func low_end() -> End:
	return left_end if high_side > 0 else right_end


## Put both ends at their targets (`snap`: at once, as at the start and after a reset).
func _place_ends(snap: bool) -> void:
	var half: int = length_cells * Tuning.TILE / 2
	for end: End in [left_end, right_end]:
		end.target_top = high_top() if end.side == high_side else low_top()
		if snap:
			end.spawn_pos = Vector2i(sim_pos.x + end.side * (half >> 1), end.target_top + end.box_h)
			end.teleport(end.spawn_pos)


func _sim_tick(_phase: int) -> void:
	if flip_ticks > 0:
		flip_ticks -= 1
		_show()


## An end's ride test caught `hero`, who was not on it before, with `landing_yvel` / `fall_ticks` as they were.
func _on_landed(end: End, hero: PlayerBase, landing_yvel: int, fall_ticks: int) -> void:
	if end != high_end() or flip_ticks > 0 or not hero.is_party_targetable():
		return
	var contact: int = contact_yvel(landing_yvel, fall_ticks)
	if contact < ObjTuning.SEESAW_LANDING_MIN_YVEL:
		return
	var hard: bool = fall_ticks - 1 > Tuning.HARD_LANDING_MIN_FALL_TICKS_EXCL
	var launch: int = PartyTuning.seesaw_launch(contact, hard)
	last_launch = launch
	var low: End = low_end()
	var level: LevelBase = Game.level
	if level != null and launch <= ObjTuning.SEESAW_LIFT_ONLY_YVEL:
		for rider: PlayerBase in level.contact_order():
			if rider != hero and (low.rider_mask & (1 << rider.slot)) != 0 and rider.is_party_targetable():
				rider.launch(PlayerBase.LAUNCH_KEEP, launch)
		_throw_enemies(level, low, launch)
	high_side = -high_side
	flip_ticks = ObjTuning.SEESAW_FLIP_TICKS
	flips += 1
	_place_ends(false)
	ObjTuning.play_cue(Sfx.SEESAW, Sfx.BOUNCE)
	if level != null:
		level.spawn_fx(ID_DUST, Vector2i(low.sim_pos.x, sim_pos.y))
	_show()


## The speed (v16) of the move that brought a hero onto the plank, from his yvel and fall_ticks as the ride test found
## them (one airborne step after that move: gravity was added once, capped at the terminal speed).
static func contact_yvel(yvel: int, fall_ticks: int) -> int:
	if yvel < Tuning.TERMINAL:
		return yvel - Tuning.GRAVITY
	return mini(Tuning.GRAVITY * maxi(fall_ticks - 1, 0), Tuning.TERMINAL)


## Enemies standing on the low end are thrown off with the launch speed.
func _throw_enemies(level: LevelBase, low: End, launch: int) -> void:
	var left: int = low.sim_pos.x - low.box_xo
	var right: int = left + low.box_w
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var enemy: EnemyBase = entity as EnemyBase
		if enemy == null or enemy.dead or not enemy.awake:
			continue
		if enemy.sim_pos.x >= left and enemy.sim_pos.x < right \
				and absi(enemy.sim_pos.y - low.top()) <= ObjTuning.SEESAW_LOW_TOP_PX + 1:
			enemy.yvel = launch


func _on_level_reset() -> void:
	high_side = _start_side
	flip_ticks = 0
	_place_ends(true)
	_show()


func _show() -> void:
	if _plank == null:
		return
	var row: int = clampi(length_cells, PLANK_MIN_LEN, PLANK_MAX_LEN) - PLANK_MIN_LEN
	var col: int = COL_LEVEL
	if flip_ticks == 0:
		col = COL_LEFT_DOWN if high_side > 0 else COL_RIGHT_DOWN
	_plank.frame = row * _plank.hframes + col
	_plank.scale.x = float(length_cells) / float(clampi(length_cells, PLANK_MIN_LEN, PLANK_MAX_LEN))
	_plank.position = Vector2(0.0, PLANK_Y_ART)

class_name HittableBase
extends SimEntity
## Scenery that reacts to the club or a thrown weapon: hidden bonus spots, breakable blocks, containers
## (GAMEPLAY.md 4.4, PHYSICS.md 8.3 #2).
##
## CONTRACT FILE (docs/ARCHITECTURE.md 3.15). Owner: objects (bodies may be replaced; public signatures frozen).
## A hittable is anchored to ONE tile cell. The hero's weapon pass asks `is_hit_by(origin)` for every hittable in
## slot order after no enemy was hit, and calls `take_hit()` on the first match; that consumes the weapon box.

## Tile cell (column, row) this hittable occupies. Set from the spawn position: the cell containing the point
## 1 px above the feet point.
var cell: Vector2i = Vector2i.ZERO
## Hits (or items) left before it is used up (level parameters `count` / `hits`).
var hits_left: int = 1
## True once used up; it no longer reacts and counted for the completion percentage.
var opened: bool = false
## Ticks until it reacts again (Tuning.HIDDEN_SPOT_HIT_COOLDOWN after every hit).
var cooldown: int = 0
## Reported in Events.hidden_spot_opened: &"small", &"big", &"block", &"container".
var spot_kind: StringName = &"small"
## True when it counts as one of the level's hidden spots for the completion percentage.
var counts_for_completion: bool = true
## Hits (or items) it started with.
var hits_total: int = 1
## True for hidden cells (spots and breakable blocks): when one of them is used up by a hit, every unopened one
## that touches it (8-neighbourhood, and theirs in turn) opens with it (GAMEPLAY.md 4.4).
var joins_flood: bool = false
## True when it was opened by the flood fill of a touching cell instead of its own last hit: it counts for the
## completion percentage but pays out nothing.
var opened_by_flood: bool = false
## Direction (+1 / -1) of the strike that hit it last: the facing of the hero for the club, the flight direction
## for a thrown weapon. Things thrown out fly back against it.
var strike_dir: int = 1


func get_kind() -> int:
	return Defs.Kind.HITTABLE


func _init() -> void:
	z_index = Defs.Z_OBJECTS


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.WORLD])


func _apply_params(params: Dictionary) -> void:
	cell = Vector2i(sim_pos.x >> 4, (sim_pos.y - 1) >> 4)
	if params.has("hits"):
		hits_left = maxi(int(params["hits"]), 1)
	elif params.has("count"):
		hits_left = maxi(int(params["count"]), 1)
	hits_total = hits_left
	spot_kind = StringName(str(params.get("kind", spot_kind)))


func _sim_tick(phase: int) -> void:
	if phase == Defs.Phase.WORLD and cooldown > 0:
		cooldown -= 1


## The hidden-tile test of PHYSICS.md 8.3 #2 for a weapon box whose origin (bottom anchor) is `origin`:
## within 1 tile horizontally and less than 16 px vertically.
func is_hit_by(origin: Vector2i) -> bool:
	if opened:
		return false
	return absi(cell.x - (origin.x >> 4)) <= Tuning.HIDDEN_HIT_COLS \
			and absi(cell.y * Tuning.TILE - (origin.y - Tuning.TILE)) < Tuning.HIDDEN_HIT_PX


## A weapon hit it. Returns true when the weapon box is consumed (always while not opened; a hit during the
## cooldown is consumed without effect). Shows the star puff, calls `_on_hit`, and opens it when used up.
func take_hit(power: int, source: SimEntity) -> bool:
	if opened:
		return false
	if cooldown > 0:
		return true
	cooldown = Tuning.HIDDEN_SPOT_HIT_COOLDOWN
	hits_left -= 1
	if source is PlayerBase:
		strike_dir = source.facing
	elif source != null:
		strike_dir = -1 if source.xvel < 0 else 1
	Audio.play_sfx(Sfx.CLUB_HIT_SCENERY)
	if Game.level != null:
		Game.level.spawn_fx(&"fx/star_puff", get_hit_point())
	_on_hit(power, source)
	var used_up: bool = hits_left <= 0
	Events.hittable_hit.emit(self, used_up)
	if used_up:
		open()
		if joins_flood:
			_open_touching()
	return true


## Use it up now (also called for neighbours by the flood fill of GAMEPLAY.md 4.4): counts for completion,
## switches to the opened look, calls `_on_opened`.
func open() -> void:
	if opened:
		return
	opened = true
	if counts_for_completion:
		Game.count_spot_opened()
	Audio.play_sfx(Sfx.SPOT_OPENED)
	Events.hidden_spot_opened.emit(sim_pos, spot_kind)
	_on_opened()


## Where the star puff of a hit appears: the centre of the cell (logical px). Override for free-standing things.
func get_hit_point() -> Vector2i:
	return Vector2i(cell.x * Tuning.TILE + Tuning.TILE / 2, cell.y * Tuning.TILE + Tuning.TILE / 2)


## Reaction to one hit (throw out an item, spray debris). Override.
func _on_hit(_power: int, _source: SimEntity) -> void:
	pass


## Reaction to being used up (drop the giant bonus, remove the block, open touching spots). Override.
func _on_opened() -> void:
	pass


## The flood fill: open every unopened hidden cell connected to this one through touching cells. Runs once, when
## a hit used this one up; the cells it reaches are marked `opened_by_flood`.
func _open_touching() -> void:
	var level: LevelBase = Game.level
	if level == null:
		return
	var hittables: Array[SimEntity] = level.get_kind(Defs.Kind.HITTABLE)
	var frontier: Array[HittableBase] = [self]
	while not frontier.is_empty():
		var current: HittableBase = frontier.pop_back()
		for i: int in hittables.size():
			var other: HittableBase = hittables[i] as HittableBase
			if other == null or other.opened or not other.joins_flood:
				continue
			if absi(other.cell.x - current.cell.x) > 1 or absi(other.cell.y - current.cell.y) > 1:
				continue
			other.opened_by_flood = true
			other.open()
			frontier.append(other)

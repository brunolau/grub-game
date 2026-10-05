class_name ZoneBase
extends SimEntity
## Base of every `zones/*` entity (ARCHITECTURE.md 6.2): an invisible rectangle that reacts to the hero's FEET
## entering and leaving it. Owner: world.
##
## "Feet" is the cell the hero stands in: the pixel just above his feet point (x, y - 1), the same rule hidden
## spots use for their cell. A hero standing on the floor of row r + 1 is in row r, so a rectangle over the air
## cells of a room catches him whether he walks or jumps.
##
## Parameters: `rect=c,r,w,h` in tiles (required; a zone without a valid rect covers the cell of its anchor and
## reports the problem once), `name`. The test runs in phase CONTACT_ITEMS like every other "tests itself
## against the hero" entity; a dead hero is ignored. Subclasses override the two hooks.

## The zone in logical px.
var rect: Rect2i = Rect2i()
## Level-file parameter `name` (&"" when none).
var zone_name: StringName = &""
## True while the hero's feet are inside (as of the last test).
var inside: bool = false


func get_kind() -> int:
	return Defs.Kind.ZONE


func _init() -> void:
	z_index = Defs.Z_OBJECTS


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.CONTACT_ITEMS])


func _apply_params(params: Dictionary) -> void:
	zone_name = StringName(str(params.get("name", "")))
	rect = Rect2i(Tuning.tile_top(sim_pos.x), Tuning.tile_top(sim_pos.y - 1), Tuning.TILE, Tuning.TILE)
	var parts: PackedInt32Array = LevelText.to_int_list(params.get("rect", ""))
	if parts.size() == 4 and parts[2] > 0 and parts[3] > 0:
		rect = Rect2i(parts[0] * Tuning.TILE, parts[1] * Tuning.TILE, parts[2] * Tuning.TILE, parts[3] * Tuning.TILE)
	else:
		push_warning("%s at %s: missing or malformed rect=c,r,w,h; using the anchor cell" % [name, sim_pos])


func _sim_tick(phase: int) -> void:
	if phase != Defs.Phase.CONTACT_ITEMS:
		return
	var level: LevelBase = Game.level
	if level == null or level.player == null or level.player.dead:
		return
	var hero: PlayerBase = level.player
	var now: bool = Overlap.point_in(rect, hero.sim_pos.x, hero.sim_pos.y - 1)
	if now and not inside:
		inside = true
		_on_hero_entered(level, hero)
	elif not now and inside:
		inside = false
		_on_hero_exited(level, hero)
		_doze_note()


## Dozing (SimEntity, ARCHITECTURE.md 11): a zone the hero is not in only tests his feet point, which cannot enter
## the rectangle while he is far; one he is in ticks (it must notice him leaving).
func _doze_area() -> Rect2i:
	return rect


func _can_doze() -> bool:
	return not inside


func _on_level_reset() -> void:
	inside = false


## The hero's feet just entered the rectangle. Override.
func _on_hero_entered(_level: LevelBase, _hero: PlayerBase) -> void:
	pass


## The hero's feet just left the rectangle. Override.
func _on_hero_exited(_level: LevelBase, _hero: PlayerBase) -> void:
	pass

class_name CheckpointBase
extends SimEntity
## Restart point (GAMEPLAY.md 7.6, PHYSICS.md 10.4): touching it stores the hero's current position as the respawn
## point and makes it the only active one.
##
## CONTRACT FILE (docs/ARCHITECTURE.md 3.15). Owner: objects (bodies may be replaced; public signatures frozen).

## True while this is the active restart point.
var active: bool = false


func get_kind() -> int:
	return Defs.Kind.CHECKPOINT


func _init() -> void:
	z_index = Defs.Z_OBJECTS
	box_w = 24
	box_h = 27
	box_xo = 12


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.CONTACT_ITEMS])


func _sim_tick(phase: int) -> void:
	if phase != Defs.Phase.CONTACT_ITEMS or active:
		return
	# Any living hero activates it, the first in contact order (2.0, TECH_AUDIT.md 3.12: the checkpoint is the team's;
	# 1.0: the one hero). It stores his feet point.
	var level: LevelBase = Game.level
	if level == null:
		return
	for hero: PlayerBase in level.contact_order():
		if not hero.dead and Overlap.body(self, hero, hero):
			activate(hero)
			return


## Make this the active restart point: stores the HERO's feet point (not the checkpoint's), deactivates every
## other checkpoint, plays the cue. A hero who touches it in the air (jumping or falling past it) stores the
## checkpoint's own feet point instead, which the level designer put on the floor: the hero's point could lie
## above a gap beside the checkpoint, and every respawn would drop him into it again.
## Dozing (SimEntity, ARCHITECTURE.md 11): an inactive checkpoint only tests the overlap with the hero, which fails
## while he is far; the active one animates and ticks.
func _doze_area() -> Rect2i:
	return _doze_box()


func _can_doze() -> bool:
	return not active


func activate(hero: PlayerBase) -> void:
	var level: LevelBase = Game.level
	if level != null:
		for other: SimEntity in level.get_kind(Defs.Kind.CHECKPOINT):
			var checkpoint: CheckpointBase = other as CheckpointBase
			if checkpoint != null and checkpoint != self and checkpoint.active:
				checkpoint.deactivate()
	active = true
	Game.set_checkpoint(hero.sim_pos if _stands_on_floor(hero) else sim_pos)
	Audio.play_sfx(Sfx.CHECKPOINT)
	Events.checkpoint_activated.emit(self)
	_on_active_changed()


## True when the hero's feet rest on a floor of the grid (the surface of the cell under them).
func _stands_on_floor(hero: PlayerBase) -> bool:
	var level: LevelBase = Game.level
	if level == null or level.grid == null:
		return true
	var col: int = hero.sim_pos.x >> 4
	var row: int = hero.sim_pos.y >> 4
	if not TileGrid.is_ground(level.grid.floor_at(col, row)):
		return false
	return hero.sim_pos.y == row * Tuning.TILE + level.grid.surface_offset(col, row, hero.sim_pos.x)


## Another checkpoint took over.
func deactivate() -> void:
	if not active:
		return
	active = false
	_on_active_changed()
	_doze_note()


## Update the look (off / on animation, fire loop). Override.
func _on_active_changed() -> void:
	pass

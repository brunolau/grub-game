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
	if phase != Defs.Phase.CONTACT_ITEMS:
		return
	if active:
		# 2.0 co-op: the active checkpoint still hatches the eggs when a hatched hero touches it.
		if Game.mode == Defs.GameMode.COOP and Game.level != null and Game.level.hero_count() > 1:
			_touch_hatches(Game.level)
		return
	# Any living hero activates it, the first in contact order (2.0, TECH_AUDIT.md 3.12: the checkpoint is the team's;
	# 1.0: the one hero). It stores his feet point. An egg touches nothing.
	var level: LevelBase = Game.level
	if level == null:
		return
	for hero: PlayerBase in level.contact_order():
		if not hero.dead and not hero.down and Overlap.body(self, hero, hero):
			activate(hero)
			if Game.mode == Defs.GameMode.COOP and level.hero_count() > 1 and not hero.is_mounted():
				hatch_eggs(level)
			return


## Co-op (GAMEPLAY.md 13.9.2, PHYSICS.md C.12 (c)): while some hero is an egg, a hatched hero touching this (active)
## checkpoint hatches every egg in place (a mounted hero hatches nothing, C.9).
func _touch_hatches(level: LevelBase) -> void:
	if not level.any_hero_dead_or_down():
		return
	for hero: PlayerBase in level.contact_order():
		if hero.is_party_targetable() and not hero.is_mounted() and Overlap.body(self, hero, hero):
			hatch_eggs(level)
			return


## Hatch every egg of the party where it floats (PlayerBase.hatch with no hatcher: the checkpoint;
## PartyTuning.hatch_hearts of the difficulty) - through world-A's PartyDriver (`hatch_all`, which also restarts its
## egg clocks) when the level has one. Returns the number hatched.
func hatch_eggs(level: LevelBase) -> int:
	if level == null:
		return 0
	var driver: SimEntity = level.party_driver
	if driver != null and driver.has_method(&"hatch_all"):
		return int(driver.call(&"hatch_all", null))
	var hatched: int = 0
	for hero: PlayerBase in level.contact_order():
		if hero.is_down() and not hero.dead:
			hero.hatch(null, PartyTuning.hatch_hearts(Game.difficulty))
			hatched += 1
	return hatched


## Dozing (SimEntity, ARCHITECTURE.md 11): an inactive checkpoint only tests the overlap with the hero, which fails
## while he is far; the active one animates and ticks.
func _doze_area() -> Rect2i:
	return _doze_box()


func _can_doze() -> bool:
	return not active


## Make this the active restart point: stores the HERO's feet point (not the checkpoint's), deactivates every
## other checkpoint, plays the cue. A hero who touches it in the air (jumping or falling past it) stores the
## checkpoint's own feet point instead, which the level designer put on the floor: the hero's point could lie
## above a gap beside the checkpoint, and every respawn would drop him into it again.
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

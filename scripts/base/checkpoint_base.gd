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
	var level: LevelBase = Game.level
	if level != null and level.player != null and not level.player.dead \
			and Overlap.body(self, level.player, level.player):
		activate(level.player)


## Make this the active restart point: stores the HERO's feet point (not the checkpoint's), deactivates every
## other checkpoint, plays the cue.
func activate(hero: PlayerBase) -> void:
	var level: LevelBase = Game.level
	if level != null:
		for other: SimEntity in level.get_kind(Defs.Kind.CHECKPOINT):
			var checkpoint: CheckpointBase = other as CheckpointBase
			if checkpoint != null and checkpoint != self and checkpoint.active:
				checkpoint.deactivate()
	active = true
	Game.set_checkpoint(hero.sim_pos)
	Audio.play_sfx(Sfx.CHECKPOINT)
	Events.checkpoint_activated.emit(self)
	_on_active_changed()


## Another checkpoint took over.
func deactivate() -> void:
	if not active:
		return
	active = false
	_on_active_changed()


## Update the look (off / on animation, fire loop). Override.
func _on_active_changed() -> void:
	pass

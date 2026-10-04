class_name LevelExitBase
extends SimEntity
## Level exit (the original's traffic light, GAMEPLAY.md 7.6): touching it while open ends the level. A locked
## exit opens when the fire-starter is collected (Game.unlock_exit / Events.exit_unlocked).
##
## CONTRACT FILE (docs/ARCHITECTURE.md 3.15). Owner: objects (bodies may be replaced; public signatures frozen).

## True when the exit needs the fire-starter (level parameter `locked`, default false).
var locked: bool = false
## Reported to Flow.complete_level: &"exit" (default), &"warp" or &"trophy" (level parameter `kind`).
var exit_kind: StringName = &"exit"
## True once the hero used it.
var used: bool = false


func get_kind() -> int:
	return Defs.Kind.EXIT


func _init() -> void:
	z_index = Defs.Z_OBJECTS
	box_w = 20
	box_h = 44
	box_xo = 10


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.CONTACT_ITEMS])


func _apply_params(params: Dictionary) -> void:
	locked = bool(params.get("locked", locked))
	exit_kind = StringName(str(params.get("kind", exit_kind)))


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		if not Events.exit_unlocked.is_connected(_on_exit_unlocked):
			Events.exit_unlocked.connect(_on_exit_unlocked)
	elif what == NOTIFICATION_EXIT_TREE:
		if Events.exit_unlocked.is_connected(_on_exit_unlocked):
			Events.exit_unlocked.disconnect(_on_exit_unlocked)


func _sim_tick(phase: int) -> void:
	if phase != Defs.Phase.CONTACT_ITEMS or used or not is_open():
		return
	var level: LevelBase = Game.level
	if level != null and level.player != null and not level.player.dead \
			and Overlap.body(self, level.player, level.player):
		use(level.player)


## True when touching it ends the level.
func is_open() -> bool:
	return not locked or Game.exit_unlocked


## The hero touched the open exit: freeze his controls and complete the level.
func use(hero: PlayerBase) -> void:
	if used:
		return
	used = true
	hero.set_control_enabled(false)
	Audio.play_sfx(Sfx.EXIT_OPEN)
	if Game.level != null:
		Game.level.complete(exit_kind)


## Update the look (cold / locked / open flame). Override.
func _on_open_changed() -> void:
	pass


func _on_exit_unlocked() -> void:
	_on_open_changed()

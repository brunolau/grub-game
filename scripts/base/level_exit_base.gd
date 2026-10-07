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
## 2.0 co-op team exit (DESIGN.md D.1, GAMEPLAY.md 13.9.2): bit `slot` for every hero counted present on the last
## test (hatched heroes touching it, eggs on the view). 0 outside a co-op party. Read by the HUD / looks.
var present_mask: int = 0


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
	# The first living hero in contact order who touches it ends the level (2.0, TECH_AUDIT.md 3.12; 1.0: the one
	# hero). A co-op party: the team rule ([method _team_tick]).
	var level: LevelBase = Game.level
	if level == null:
		return
	if Game.mode == Defs.GameMode.COOP and level.hero_count() > 1:
		var driver: SimEntity = level.party_driver
		if driver != null and driver.has_method(&"exit_touched"):
			_driver_tick(level, driver)
		else:
			_team_tick(level)
		return
	for hero: PlayerBase in level.contact_order():
		if not hero.dead and not hero.down and Overlap.body(self, hero, hero):
			use(hero)
			return


## The co-op team exit through world-A's PartyDriver (`exit_touched` / `is_at_exit`): every tick, each hatched hero who
## touches the open totem or already waits there is reported; the driver freezes the arrivals and answers true once
## the whole team is present (the others arrived, or eggs on the view) - then the level ends.
func _driver_tick(level: LevelBase, driver: SimEntity) -> void:
	present_mask = 0
	var asks_arrived: bool = driver.has_method(&"is_at_exit")
	for hero: PlayerBase in level.contact_order():
		if hero.dead or hero.down:
			continue
		var arrived: bool = asks_arrived and bool(driver.call(&"is_at_exit", hero))
		if not arrived and not Overlap.body(self, hero, hero):
			continue
		if hero.is_mounted():
			hero.leave_mount()
		present_mask |= 1 << hero.slot
		if bool(driver.call(&"exit_touched", self, hero)):
			use(hero)
			return


## The co-op team exit without a PartyDriver (DESIGN.md D.1, GAMEPLAY.md 13.9.2): the stage ends when every hero is
## present - each hatched hero touching the totem, each egg anywhere on the view - and at least one hatched hero
## touches it; a hero in his death toss is not present (the totem waits). The first who arrived waits there.
func _team_tick(level: LevelBase) -> void:
	present_mask = 0
	var toucher: PlayerBase = null
	var everyone: bool = true
	for hero: PlayerBase in level.contact_order():
		if hero.down:
			if level.is_in_view(hero):
				present_mask |= 1 << hero.slot
			else:
				everyone = false
		elif not hero.dead and Overlap.body(self, hero, hero):
			present_mask |= 1 << hero.slot
			if toucher == null:
				toucher = hero
		else:
			everyone = false
	if everyone and toucher != null:
		use(toucher)


## True when touching it ends the level.
func is_open() -> bool:
	return not locked or Game.exit_unlocked


## The hero touched the open exit: freeze his controls and complete the level. 2.0: a mounted hero leaves his seat
## (PHYSICS.md C.9: touching the exit totem dismounts).
func use(hero: PlayerBase) -> void:
	if used:
		return
	used = true
	if hero.is_mounted():
		hero.leave_mount()
	hero.set_control_enabled(false)
	Audio.play_sfx(Sfx.EXIT_OPEN)
	if Game.level != null:
		Game.level.complete(exit_kind)


## Update the look (cold / locked / open flame). Override.
func _on_open_changed() -> void:
	pass


func _on_exit_unlocked() -> void:
	# A dozing exit must notice the opening in the tick it happens in (SimEntity "Dozing").
	_doze_wake_now()
	_on_open_changed()


## Dozing (SimEntity, ARCHITECTURE.md 11): an unused exit far from the hero only tests the overlap, which fails.
func _doze_area() -> Rect2i:
	return _doze_box()


func _can_doze() -> bool:
	return not used

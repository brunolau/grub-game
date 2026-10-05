extends ObjectsTestCase
## Checkpoints, exits, gates and markers, springs, signs, villagers and sprite hazards.


func before_each() -> void:
	super.before_each()
	make_ground_level(48, 16, 10)
	add_hero(Vector2i(40, 160))


func test_checkpoint_stores_the_hero_position_and_only_one_is_lit() -> void:
	var first: Checkpoint = spawn(&"objects/checkpoint", Vector2i(100, 160)) as Checkpoint
	var second: Checkpoint = spawn(&"objects/checkpoint", Vector2i(250, 160)) as Checkpoint
	var sprite: Sprite2D = first.get_node("Sprite") as Sprite2D
	assert_eq(sprite.frame, Checkpoint.FRAME_OFF)
	hero.teleport(Vector2i(104, 160))
	Sim.step(1)
	assert_true(first.active)
	assert_eq(Game.checkpoint_pos, Vector2i(104, 160), "the hero's feet, not the checkpoint's")
	Sim.step(3)
	assert_true(sprite.frame >= Checkpoint.FRAME_ON_FIRST, "the fire burns")
	hero.teleport(Vector2i(246, 160))
	Sim.step(1)
	assert_true(second.active)
	assert_false(first.active, "only the last one touched is active")
	assert_eq(sprite.frame, Checkpoint.FRAME_OFF)
	hero.kill(&"pit")
	Events.player_death_finished.emit()
	assert_eq(hero.sim_pos, Vector2i(246, 160), "respawn at the active checkpoint")
	assert_eq(Game.lives, Tuning.LIVES_START - 1)
	assert_true(second.active, "checkpoints stay lit after a death")


func test_locked_exit_needs_the_fire_starter() -> void:
	var exit: LevelExit = spawn(&"objects/exit", Vector2i(200, 160), {"locked": true}) as LevelExit
	var sprite: Sprite2D = exit.get_node("Sprite") as Sprite2D
	hero.teleport(Vector2i(200, 160))
	Sim.step(2)
	assert_false(exit.used, "a red totem does not end the level")
	assert_true(sprite.frame >= LevelExit.FRAME_LOCKED_FIRST and sprite.frame < LevelExit.FRAME_OPEN_FIRST)
	spawn(&"items/fire_starter", Vector2i(200, 160))
	Sim.step(1)
	assert_true(Game.exit_unlocked)
	Sim.step(1)
	assert_true(exit.used)
	assert_eq(level.completed_kinds, [&"exit"] as Array[StringName])
	assert_false(hero.control_enabled, "the hero stops at the exit")
	assert_true(sprite.frame >= LevelExit.FRAME_OPEN_FIRST, "green flame")


func test_exit_kinds() -> void:
	spawn(&"objects/exit", Vector2i(40, 160), {"kind": "warp"})
	Sim.step(1)
	assert_eq(level.completed_kinds, [&"warp"] as Array[StringName])


func test_gate_takes_the_hero_to_its_destination() -> void:
	spawn(&"objects/gate", LevelText.cell_to_feet(5, 9), {"name": "in", "dest": "out"})
	var out: Gate = spawn(&"objects/gate", LevelText.cell_to_feet(30, 9), {
		"name": "out", "dest": "in", "lock": "28,0", "skin": "hole",
	}) as Gate
	assert_eq((out.get_node("Sprite") as Sprite2D).texture.resource_path, "res://assets/sprites/objects/gate_hole.png")
	var journeys: Array[Vector2i] = []
	var covered: Array = []
	var on_gate: Callable = func(from: Vector2i, to: Vector2i) -> void:
		journeys.append_array([from, to])
		covered.append_array([Flow.get_transition_cover().amount, Flow.get_transition_cover().shape, Sim.frozen])
	Events.gate_used.connect(on_gate)
	hero.teleport(Vector2i(88, 160))
	Sim.step(3)
	assert_eq(hero.sim_pos, Vector2i(88, 160), "standing in front of it is not enough")
	hero.drop_timer = Tuning.DROP_TIMER
	Sim.step(1)
	assert_eq(covered, [1.0, Defs.Transition.CURTAIN, true],
			"the hero travels while Flow's curtain covers the screen and the clock stands still")
	assert_eq(hero.sim_pos, Vector2i(30 * 16 + 8, 160), "the hero appears at the destination")
	assert_true(hero.control_enabled, "the curtain opened again")
	assert_eq(Flow.get_transition_cover().amount, 0.0)
	assert_true(level.is_camera_locked(), "the destination's single-screen room locks the camera")
	assert_eq(level.get_camera_lock(), Rect2i(28 * 16, 0, Tuning.VIEW_COLS * 16, Tuning.VIEW_ROWS * 16))
	assert_eq(level.snaps, 1)
	Sim.step(5)
	assert_eq(hero.sim_pos.x, 30 * 16 + 8, "still holding Down: no immediate return")
	hero.drop_timer = 0
	Sim.step(1)
	hero.drop_timer = Tuning.DROP_TIMER
	Sim.step(1)
	assert_eq(hero.sim_pos, Vector2i(88, 160), "and back")
	assert_false(level.is_camera_locked(), "arriving outside a room frees the camera")
	Events.gate_used.disconnect(on_gate)
	var inside: Vector2i = Vector2i(488, 160)
	assert_eq(journeys, [Vector2i(88, 160), inside, inside, Vector2i(88, 160)] as Array[Vector2i])


func test_gate_to_a_marker_and_not_with_the_glider() -> void:
	spawn(&"objects/gate", LevelText.cell_to_feet(5, 9), {"name": "door", "dest": "spot", "skin": "none"})
	spawn(&"objects/marker", Vector2i(600, 96), {"name": "spot"})
	assert_not_null(level.find_named(&"spot"))
	hero.teleport(Vector2i(88, 160))
	hero.drop_timer = Tuning.DROP_TIMER
	Game.set_glider(true)
	Sim.step(2)
	assert_eq(hero.sim_pos, Vector2i(88, 160), "not usable while carrying the glider")
	Game.set_glider(false)
	Sim.step(1)
	assert_eq(hero.sim_pos, Vector2i(600, 96))


func test_spring_throws_the_hero_up() -> void:
	var spring: SpringPad = spawn(&"objects/spring", Vector2i(100, 160)) as SpringPad
	hero.teleport(Vector2i(100, 160))
	Sim.step(2)
	assert_eq(spring.launches, 0, "walking onto it does nothing")
	hero.teleport(Vector2i(100, 152))
	hero.yvel = 32
	Sim.step(1)
	assert_eq(spring.launches, 1)
	assert_eq(hero.yvel, ObjTuning.SPRING_DEFAULT_POWER)
	assert_eq(hero.sim_pos.y, 150, "lifted out of the pad")
	var strong: SpringPad = spawn(&"objects/spring", Vector2i(300, 160), {"power": -300}) as SpringPad
	hero.teleport(Vector2i(300, 155))
	hero.yvel = 64
	Sim.step(1)
	assert_eq(strong.launches, 1)
	assert_eq(hero.yvel, -300)


func test_sign_shows_its_text_near_the_hero() -> void:
	var board: SignBoard = spawn(&"objects/sign", Vector2i(300, 160), {"text": "SIGN_TEST"}) as SignBoard
	var label: Label = board.get_node("Text") as Label
	assert_eq(label.text, "SIGN_TEST")
	Sim.step(1)
	assert_false(label.visible)
	hero.teleport(Vector2i(296, 160))
	Sim.step(1)
	assert_true(label.visible)


func test_villagers_idle_turn_to_the_hero_and_are_harmless() -> void:
	var sizes: Dictionary = {"elder": 5, "kid": 6, "warrior": 6}
	var villagers: Array[Npc] = []
	var x: int = 120
	for kind: String in sizes:
		var npc: Npc = spawn(&"objects/npc", Vector2i(x, 160), {"kind": kind, "facing": "l"}) as Npc
		assert_eq(npc.kind, kind)
		assert_eq((npc.get_node("Sprite") as Sprite2D).hframes, int(sizes[kind]), "%s: idle frames" % kind)
		assert_eq(npc.get_kind(), Defs.Kind.OTHER, "not an enemy, item, hazard or hittable")
		villagers.append(npc)
		x += 120
	var still: Npc = spawn(&"objects/npc", Vector2i(60, 160), {"kind": "kid", "facing": "l", "turn": false}) as Npc
	var sprite: Sprite2D = villagers[0].get_node("Sprite") as Sprite2D
	var frames: Dictionary = {}
	var hearts: int = Game.hearts
	hero.teleport(Vector2i(150, 160))
	for i: int in 30:
		Sim.step(1)
		frames[sprite.frame] = true
	assert_true(frames.size() >= 3, "the idle loop plays")
	assert_eq(villagers[0].facing, 1, "a villager turns to face the hero standing near")
	assert_eq(villagers[2].facing, -1, "one far away keeps its facing")
	assert_eq(still.facing, -1, "turn=false keeps the placed facing")
	assert_true(sprite.flip_h == false)
	assert_eq(Game.hearts, hearts, "standing in a villager never hurts")
	assert_false(hero.dead)
	var counter: LogCounter = LogCounter.new()
	OS.add_logger(counter)
	var odd: Npc = spawn(&"objects/npc", Vector2i(200, 160), {"kind": "dragon"}) as Npc
	OS.remove_logger(counter)
	assert_eq(odd.kind, Npc.DEFAULT_KIND, "an unknown kind falls back to the elder")
	assert_eq(counter.warnings, 1, "and says so once")


func test_sprite_hazards_hurt_or_kill() -> void:
	var thorn: HazardBase = HazardBase.new()
	place(level, thorn, Vector2i(140, 160))
	hero.teleport(Vector2i(140, 160))
	Sim.step(1)
	assert_eq(Game.hearts, Tuning.ENERGY_START - 1, "a harmful hazard costs a heart")
	assert_false(hero.dead)
	thorn.armed = false
	hero.hit_timer = 0
	Sim.step(1)
	assert_eq(Game.hearts, Tuning.ENERGY_START - 1, "a disarmed hazard is harmless")
	var pit: HazardBase = HazardBase.new()
	pit.deadly = true
	pit.death_cause = &"crush"
	place(level, pit, Vector2i(140, 160))
	var causes: Array[StringName] = []
	var on_died: Callable = func(cause: StringName) -> void: causes.append(cause)
	Events.player_died.connect(on_died)
	Sim.step(1)
	Events.player_died.disconnect(on_died)
	assert_true(hero.dead)
	assert_eq(causes, [&"crush"] as Array[StringName])

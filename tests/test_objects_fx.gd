extends ObjectsTestCase
## Pop-ups and particles, and the whole catalogue of ARCHITECTURE.md 6.2 owned by this module: every id exists,
## spawns and runs without a warning or an error.

const ITEM_IDS: Array[StringName] = [
	&"items/food", &"items/treasure", &"items/giant_bonus", &"items/letter", &"items/jackpot", &"items/feast_piece",
	&"items/fire_starter", &"items/heart", &"items/one_up", &"items/bone", &"items/skull", &"items/kill_all",
	&"items/grenade", &"items/weapon", &"items/glider", &"items/water_bucket", &"items/warp", &"items/trophy",
	&"items/code_stone", &"items/random_bonus",
]
const OBJECT_IDS: Array[StringName] = [
	&"objects/checkpoint", &"objects/exit", &"objects/hidden_spot", &"objects/breakable_block", &"objects/container",
	&"objects/platform", &"objects/drop_platform", &"objects/column", &"objects/gate", &"objects/marker",
	&"objects/spring", &"objects/sign", &"objects/npc",
]
const FX_IDS: Array[StringName] = [
	&"fx/dust", &"fx/star_puff", &"fx/hit_stars", &"fx/poof", &"fx/explosion", &"fx/explosion_big", &"fx/ring",
	&"fx/splash", &"fx/debris", &"fx/popup",
]


func before_each() -> void:
	super.before_each()
	make_ground_level()
	add_hero(Vector2i(40, 160))


func test_every_catalogue_id_exists_and_spawns_cleanly() -> void:
	var counter: LogCounter = LogCounter.new()
	OS.add_logger(counter)
	var x: int = 64
	for id: StringName in ITEM_IDS + OBJECT_IDS + FX_IDS:
		assert_true(Spawner.exists(id), "%s has a scene" % id)
		var node: Node = spawn(id, Vector2i(x, 160))
		assert_true(node is SimEntity, "%s is a SimEntity" % id)
		x += 12
	Sim.step(60)
	OS.remove_logger(counter)
	assert_eq(counter.warnings, 0, "no warnings")
	assert_eq(counter.errors, 0, "no errors")


func test_sprites_match_the_manifest() -> void:
	var expected: Dictionary = {
		&"items/food": [Vector2(-16, -32), 8, 6], &"items/treasure": [Vector2(-16, -32), 8, 2],
		&"items/giant_bonus": [Vector2(-36, -72), 7, 1], &"items/letter": [Vector2(-20, -40), 5, 1],
		&"items/heart": [Vector2(-24, -40), 8, 2], &"items/weapon": [Vector2(-16, -40), 1, 1],
		&"items/glider": [Vector2(-20, -40), 1, 1], &"objects/checkpoint": [Vector2(-42, -55), 5, 1],
		&"objects/exit": [Vector2(-20, -88), 5, 1], &"objects/breakable_block": [Vector2(-19, -32), 8, 1],
		&"objects/spring": [Vector2(-32, -26), 5, 1], &"fx/star_puff": [Vector2(-22, -20), 5, 1],
		&"fx/poof": [Vector2(-28, -28), 9, 1], &"fx/explosion_big": [Vector2(-64, -96), 12, 1],
	}
	for id: StringName in expected:
		var node: Node = spawn(id, Vector2i(200, 160))
		var sprite: Sprite2D = node.get_node("Sprite") as Sprite2D
		var want: Array = expected[id]
		assert_false(sprite.centered, "%s: pivot by offset" % id)
		assert_eq(sprite.offset, want[0], "%s: manifest pivot" % id)
		assert_eq(sprite.hframes, want[1], "%s: columns" % id)
		assert_eq(sprite.vframes, want[2], "%s: rows" % id)


func test_popup_rises_one_pixel_per_tick_for_44_ticks() -> void:
	var popup: FxPopup = spawn(&"fx/popup", Vector2i(100, 100), {"kind": "score", "value": 750}) as FxPopup
	assert_eq(popup.text, "750")
	Sim.step(1)
	assert_eq(popup.sim_pos.y, 99)
	Sim.step(Tuning.SCORE_POPUP_TICKS - 2)
	assert_eq(popup.sim_pos.y, 100 - (Tuning.SCORE_POPUP_TICKS - 1))
	assert_false(popup.is_queued_for_deletion())
	Sim.step(1)
	assert_true(popup.is_queued_for_deletion(), "gone after 44 ticks")
	assert_eq((spawn(&"fx/popup", Vector2i(0, 0), {"kind": "multiplier", "value": 4}) as FxPopup).text, "X4")
	assert_eq((spawn(&"fx/popup", Vector2i(0, 0), {"kind": "one_up", "value": 1}) as FxPopup).text, "1UP")


func test_popups_are_limited() -> void:
	for i: int in ObjTuning.MAX_POPUPS + 4:
		spawn(&"fx/popup", Vector2i(100, 100), {"value": 100})
	var alive: int = 0
	for entity: SimEntity in level.get_kind(Defs.Kind.FX):
		if entity is FxPopup and entity.visible and not entity.is_queued_for_deletion():
			alive += 1
	assert_eq(alive, ObjTuning.MAX_POPUPS)


func test_popups_at_one_spot_on_consecutive_ticks_stack() -> void:
	var popups: Array[FxPopup] = []
	for i: int in 3:
		popups.append(spawn(&"fx/popup", Vector2i(100, 100), {"value": 100 * (i + 1)}) as FxPopup)
		Sim.step(1)
	for i: int in popups.size():
		for j: int in range(i + 1, popups.size()):
			var gap: int = absi(popups[i].sim_pos.y - popups[j].sim_pos.y)
			assert_true(gap >= FxPopup.STAGGER_LINE, "pop-ups %d and %d are a line apart (%d px)" % [i, j, gap])
	assert_true(popups[1].sim_pos.y < popups[0].sim_pos.y, "the later one starts higher")
	var beside: FxPopup = spawn(&"fx/popup", Vector2i(118, 100), {"value": 300}) as FxPopup
	assert_true(beside.sim_pos.y <= popups[2].sim_pos.y - FxPopup.STAGGER_LINE, "text that would touch moves up too")
	var elsewhere: FxPopup = spawn(&"fx/popup", Vector2i(160, 100), {"value": 5}) as FxPopup
	assert_eq(elsewhere.sim_pos, Vector2i(160, 100), "a pop-up clear of the others keeps its place")
	var first_y: int = popups[0].sim_pos.y
	Sim.step(1)
	assert_eq(popups[0].sim_pos.y, first_y - 1, "stacked pop-ups still rise 1 px per tick")


func test_level_turns_popup_requests_into_popups() -> void:
	Events.popup_requested.emit(&"heart", 1, Vector2i(80, 80))
	assert_eq(count_alive(Defs.Kind.FX), 1)


func test_animations_play_once_and_free_themselves() -> void:
	var puff: FxAnim = spawn(&"fx/star_puff", Vector2i(100, 100)) as FxAnim
	var sprite: Sprite2D = puff.get_node("Sprite") as Sprite2D
	assert_eq(puff.lifetime, ObjTuning.anim_ticks(5, 16))
	var frames: Array[int] = []
	for i: int in puff.lifetime - 1:
		Sim.step(1)
		frames.append(sprite.frame)
	assert_eq(frames[0], 0)
	assert_eq(frames[frames.size() - 1], 4, "reaches the last frame")
	for i: int in frames.size() - 1:
		assert_true(frames[i + 1] >= frames[i], "frames only advance")
	Sim.step(1)
	assert_true(puff.is_queued_for_deletion())


func test_splash_kinds() -> void:
	var lava: FxAnim = spawn(&"fx/splash", Vector2i(100, 100), {"kind": "lava"}) as FxAnim
	assert_eq((lava.get_node("Sprite") as Sprite2D).texture.resource_path, "res://assets/sprites/fx/splash_lava.png")
	var water: FxAnim = spawn(&"fx/splash", Vector2i(100, 100)) as FxAnim
	assert_eq((water.get_node("Sprite") as Sprite2D).texture.resource_path, "res://assets/sprites/fx/splash_water.png")


func test_debris_sprays_bits_that_fall() -> void:
	var debris: FxDebris = spawn(&"fx/debris", Vector2i(100, 100), {"kind": "wood", "count": 6}) as FxDebris
	assert_eq(debris.get_child_count(), 6)
	var bit: Sprite2D = debris.get_child(0) as Sprite2D
	assert_eq(bit.texture.resource_path, "res://assets/sprites/fx/debris_wood.png")
	var heights: Array[float] = []
	for i: int in ObjTuning.DEBRIS_LIFE - 2:
		Sim.step(1)
		debris._process(0.0)
		heights.append(bit.position.y)
	assert_true(heights[2] < 0.0, "thrown up first")
	assert_true(heights[heights.size() - 1] > heights.min(), "then falls")
	Sim.step(2)
	assert_true(debris.is_queued_for_deletion())
	var many: FxDebris = spawn(&"fx/debris", Vector2i(100, 100), {"count": 99}) as FxDebris
	assert_eq(many.get_child_count(), ObjTuning.DEBRIS_MAX_COUNT)


func test_debris_lands_on_floors_instead_of_falling_through() -> void:
	# Sprayed from the middle of a ground tile (a hidden spot in the floor): up, back down, bounce, lie still.
	var ground_y: int = 10 * Tuning.TILE
	var debris: FxDebris = spawn(&"fx/debris", Vector2i(100, ground_y + 8), {"count": 8}) as FxDebris
	var lowest: int = -9999
	var bounced: bool = false
	var touched: Dictionary = {}
	var prev_y: PackedInt32Array = PackedInt32Array()
	prev_y.resize(8)
	prev_y.fill(ground_y + 8)
	for t: int in ObjTuning.DEBRIS_LIFE - 1:
		Sim.step(1)
		for i: int in 8:
			var pos: Vector2i = debris.bit_pos(i)
			if prev_y[i] <= ground_y:
				lowest = maxi(lowest, pos.y)
				if pos.y == ground_y:
					touched[i] = true
				if pos.y < prev_y[i] and prev_y[i] == ground_y:
					bounced = true
			prev_y[i] = pos.y
	assert_true(lowest <= ground_y, "once above the floor no bit sinks into it (lowest %d)" % lowest)
	assert_true(touched.size() >= 3, "bits come down onto the floor (%d)" % touched.size())
	assert_true(bounced, "a bit bounces off the floor")
	for i: int in 8:
		if debris.is_resting(i):
			assert_eq(debris.bit_pos(i).y, ground_y, "a resting bit lies on the surface")
	# A solid ceiling stops a rising bit.
	var lines: PackedStringArray = PackedStringArray()
	for row: int in 16:
		lines.append(TileGrid.CH_SOLID_A.repeat(40) if row == 8 or row >= 10 else TileGrid.CH_AIR.repeat(40))
	make_recording_level(lines)
	var capped: FxDebris = spawn(&"fx/debris", Vector2i(100, ground_y + 8), {"count": 8}) as FxDebris
	var highest: int = 9999
	for t: int in 12:
		Sim.step(1)
		for i: int in 8:
			highest = mini(highest, capped.bit_pos(i).y)
	assert_eq(highest, 9 * Tuning.TILE, "rising bits stop under the ceiling (highest %d)" % highest)


func test_effects_do_not_touch_the_gameplay_random_sequence() -> void:
	Sim.rng.reseed(9)
	var expected: int = SimRng.new(9).next_u32()
	spawn(&"fx/debris", Vector2i(100, 100), {"count": 8})
	spawn(&"fx/dust", Vector2i(100, 100))
	Sim.step(5)
	assert_eq(Sim.rng.next_u32(), expected)

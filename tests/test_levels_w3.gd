extends TestCase
## World 3 level checks beyond the route proofs (owner: level design w3): Frost Summit (w3_l1), Blizzard Pass
## (w3_l1b) and Crystal Grotto (w3_l2). The routes (main routes, the valley under the icicle overhang, the Blizzard
## Pass pond), the links and the validity of the files are checked by the campaign suite,
## tests/test_campaign_routes.gd.

const W3_L1: StringName = &"w3_l1"
const W3_L1B: StringName = &"w3_l1b"
const W3_L2: StringName = &"w3_l2"
## Logical view of the 1280 x 720 game window (integer scale 2).
const VIEW: Vector2i = Vector2i(Tuning.VIEW_W, Tuning.VIEW_H)


func after_each() -> void:
	Sim.manual = false
	Sim.stop()
	if get_tree().current_scene != null:
		get_tree().current_scene.free()
		get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT


## A hero who touches a checkpoint while standing stores his own feet point as the respawn point. The whole range in
## which his box can overlap a checkpoint should lie over floor, so that this point is on the ground (a touch in the
## air stores the checkpoint's own point, CheckpointBase.activate).
func test_every_checkpoint_is_touched_over_floor() -> void:
	var hero_box: Vector3i = Tuning.HERO_BOX_JUMP_TOP
	for level_id: StringName in [W3_L1, W3_L1B, W3_L2]:
		Game.new_game(Defs.Difficulty.BEGINNER)
		await _start(level_id)
		var grid: TileGrid = Game.level.grid
		var checkpoints: Array = Game.level.get_kind(Defs.Kind.CHECKPOINT)
		assert_true(checkpoints.size() >= 2, "%s has checkpoints" % level_id)
		for entity: SimEntity in checkpoints:
			var left: int = entity.sim_pos.x - entity.box_xo
			var row: int = entity.sim_pos.y >> 4
			var bad: Array[int] = []
			for x: int in range(left - hero_box.x + hero_box.z + 1, left + entity.box_w + hero_box.z):
				if not TileGrid.is_ground(grid.floor_at(x >> 4, row)):
					bad.append(x)
			assert_true(bad.is_empty(), "%s: checkpoint at %s can be touched over a gap at x %s" % [
				level_id, entity.sim_pos, bad])
		after_each()


func test_the_blizzard_blows_harder_on_expert() -> void:
	var peaks: Array[int] = []
	for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		var peak: int = 0
		for entry: String in str(Levels.get_value(W3_L1B, "wind", "", difficulty)).split(","):
			peak = maxi(peak, entry.get_slice(":", 1).to_int())
		peaks.append(peak)
	assert_true(peaks[0] >= 48, "Beginner gusts are strong enough to need a crouch on ice (%d)" % peaks[0])
	assert_true(peaks[1] > peaks[0], "Expert gusts (%d) are stronger than Beginner gusts (%d)" % [peaks[1], peaks[0]])


## Enter `level_id` through Flow like the game does, with the clock under the test's control.
func _start(level_id: StringName) -> void:
	Sim.manual = true
	await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame
	Flow.start_level(level_id, Defs.Transition.NONE)
	for i: int in 3:
		await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL)
	assert_eq(Game.level.level_id, level_id)
	var level: Level = Game.level as Level
	if level != null:
		level.set_view_size(VIEW * Tuning.ART_SCALE)

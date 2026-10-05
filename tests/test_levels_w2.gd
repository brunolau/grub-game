extends TestCase
## World 2 level checks beyond the route proofs (owner: level design w2): the Brute of Brute's Den (w2_l2b).
## The routes of Echo Caverns, Bone Gorge and the den, the links and the validity of the files are checked by the
## campaign suite, tests/test_campaign_routes.gd.

const W2_L2B: StringName = &"w2_l2b"
## Logical view of the 1280 x 720 game window (integer scale 2).
const VIEW: Vector2i = Vector2i(Tuning.VIEW_W, Tuning.VIEW_H)


func after_each() -> void:
	Sim.manual = false
	Sim.stop()
	if get_tree().current_scene != null:
		get_tree().current_scene.free()
		get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT


func test_the_brute_survives_charged_strikes() -> void:
	# A charged strike does 4 x the weapon power (club 100, hammer 120). The first boss must not fall to one of them
	# on Beginner, nor to two on Expert, and its arena limits must reach the den walls (no safe corner).
	var strongest: int = Tuning.WEAPON_POWER[Defs.Weapon.HAMMER] * Tuning.CHARGE_MULTIPLIER
	for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		Game.new_game(difficulty)
		await _start(W2_L2B)
		var bosses: Array[SimEntity] = Game.level.get_kind(Defs.Kind.BOSS)
		assert_eq(bosses.size(), 1, "one Brute in %s" % Defs.difficulty_name(difficulty))
		var brute: Brute = bosses[0] as Brute if bosses.size() == 1 else null
		assert_not_null(brute)
		if brute != null:
			var strikes: int = 2 if difficulty == Defs.Difficulty.EXPERT else 1
			assert_true(brute.max_hp > strikes * strongest, "%s Brute hp %d survives %d charged hammer strike(s)" % [
					Defs.difficulty_name(difficulty), brute.max_hp, strikes])
			assert_eq(brute.left_x, 42 * Tuning.TILE + Tuning.TILE / 2, "left limit one column inside the den wall")
			assert_eq(brute.right_x, 59 * Tuning.TILE + Tuning.TILE / 2, "right limit one column inside the den wall")
			assert_eq(brute.get_max_pips(), Tuning.BOSS_BAR_MAX_PIPS, "the energy bar spans the tougher Brute")
		after_each()


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

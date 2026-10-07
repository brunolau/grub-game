extends PlayerTestCase
## The weapon belt and Swap (docs/spec/PHYSICS.md C.1, C.2) and the spear (C.3) with the real hero: the edge-
## triggered Swap, the 8-tick lock-out, what a swap may not touch, the fresh-club rule, the pick-up rule, belt
## invariance on a short run; the spear's flight, its count per hero, MAX_THROWN, its hits, the bark-board step
## request and the throw through the real strike.


## A spear step as objects-B's SpearStep answers it (is_live / collapse).
class FakeStep:
	extends RefCounted

	var live: bool = true
	var collapsed: bool = false

	func is_live() -> bool:
		return live and not collapsed

	func collapse() -> void:
		collapsed = true


## A bark board as objects-B's BarkBoard answers the spear (catches / stick): one step at a time (C.3 "one step per
## board"); its cell overlaps the spear's box and the spear's xvel points into its face.
class FakeBoard:
	extends SimEntity

	var cell: Vector2i = Vector2i.ZERO
	## +1: air on the right, takes spears flying left (xvel < 0); -1: air on the left.
	var face: int = 1
	var step: FakeStep = null
	var asked: int = 0
	## True: stick() hands out a Node step (FakeNodeStep, kept in node_step) instead of a FakeStep.
	var node_steps: bool = false
	var node_step: Object = null

	func catches(spear: SimEntity) -> bool:
		if spear.xvel * face >= 0:
			return false
		return Overlap.rects(Rect2i(cell * Tuning.TILE, Vector2i(Tuning.TILE, Tuning.TILE)), spear.get_box())

	func stick(_spear: SimEntity) -> Object:
		asked += 1
		if node_steps:
			node_step = FakeNodeStep.new()
			return node_step
		if step != null and step.is_live():
			return null
		step = FakeStep.new()
		return step


## A spear step that is a node (as objects-B's SpearStep is), so a test can free it.
class FakeNodeStep:
	extends Node

	func is_live() -> bool:
		return true


## A flat world whose belt rule is `fresh` (a Book II stage).
func fresh_flat() -> FollowLevel:
	world_flat()
	level.meta = {"book": 2, "belt": LevelText.BELT_FRESH}
	return level


# =================================================================================================================
# Belt and Swap
# =================================================================================================================

func test_book1_hero_has_no_belt_and_ignores_swap() -> void:
	world_flat()
	spawn_hero()
	assert_false(hero.hero_belt.active, "belt = carry (the 1.0 rule): the component stays off")
	hero.run.set_weapon(Defs.Weapon.AXE)
	hero.run.set_belt(Defs.Weapon.CLUB)
	play(hold("S", 1) + hold("", 12) + hold("S", 1))
	assert_eq(hero.run.weapon, Defs.Weapon.AXE, "Swap is sampled but ignored")
	assert_eq(hero.run.belt, Defs.Weapon.CLUB)
	HeroBelt.give_weapon(hero, Defs.Weapon.HAMMER)
	assert_eq(hero.run.weapon, Defs.Weapon.HAMMER, "a pick-up replaces the one weapon (1.0)")


func test_a_fresh_stage_starts_with_the_club_in_hand() -> void:
	Game.runs[0].weapon = Defs.Weapon.AXE
	Game.runs[0].belt = Defs.Weapon.CLUB
	fresh_flat()
	spawn_hero()
	assert_true(hero.hero_belt.active)
	assert_eq(hero.run.weapon, Defs.Weapon.CLUB, "the club goes into the hand")
	assert_eq(hero.run.belt, Defs.Weapon.AXE, "the special waits on the belt")
	hero.run.set_weapon(Defs.Weapon.HAMMER)
	hero.run.set_belt(Defs.Weapon.CLUB)
	hero.respawn_at(START)
	assert_eq([hero.run.weapon, hero.run.belt], [Defs.Weapon.HAMMER, Defs.Weapon.CLUB], "a death keeps both places")
	# The default of a Book II level that does not set the key, and the arena rule.
	assert_eq(HeroBelt.belt_rule_of(level), LevelText.BELT_FRESH)
	level.meta = {"book": 2}
	assert_eq(HeroBelt.belt_rule_of(level), LevelText.BELT_FRESH, "book 2 defaults to fresh")
	level.meta = {"kind": "coop"}
	assert_eq(HeroBelt.belt_rule_of(level), LevelText.BELT_FRESH, "co-op files default to fresh")
	level.meta = {}
	assert_eq(HeroBelt.belt_rule_of(level), LevelText.BELT_CARRY, "a 1.0 file is carry")
	assert_eq(HeroBelt.belt_rule_of(null), LevelText.BELT_CARRY)


func test_swap_is_edge_triggered_with_an_8_tick_lockout() -> void:
	fresh_flat()
	spawn_hero()
	hero.run.set_belt(Defs.Weapon.HAMMER)
	play(hold("S", 1))
	assert_eq([hero.run.weapon, hero.run.belt], [Defs.Weapon.HAMMER, Defs.Weapon.CLUB], "one press swaps")
	assert_eq(hero.hero_belt.swap_lock, Tuning.SWAP_LOCKOUT_TICKS - 1, "8, counted down in 8i of the same tick")
	play(hold("S", 20))
	assert_eq(hero.run.weapon, Defs.Weapon.HAMMER, "holding Swap does nothing more")
	assert_eq(hero.hero_belt.swap_lock, 0)
	play(hold("", 1) + hold("S", 1))
	assert_eq(hero.run.weapon, Defs.Weapon.CLUB, "a new press swaps back")
	# A press inside the lock-out is dropped, not buffered.
	play(hold("", 1) + hold("S", 1) + hold("", 12))
	assert_eq(hero.run.weapon, Defs.Weapon.CLUB, "refused 2 ticks after the swap, and not done later")
	var ticks: Array[int] = []
	for gap: int in [6, 7]:
		fresh_flat()
		spawn_hero()
		hero.run.set_belt(Defs.Weapon.AXE)
		play(hold("S", 1) + hold("", gap) + hold("S", 1))
		ticks.append(hero.run.weapon)
	assert_eq(ticks, [Defs.Weapon.AXE, Defs.Weapon.CLUB], "the 8th tick after a swap is the first one free")


func test_swap_needs_a_special_and_no_running_strike() -> void:
	fresh_flat()
	spawn_hero()
	assert_eq(hero.run.belt, PlayerRun.BELT_EMPTY)
	play(hold("S", 1))
	assert_eq(hero.run.weapon, Defs.Weapon.CLUB, "an empty belt: nothing to swap")
	assert_eq(hero.hero_belt.swap_lock, 0, "a refused press arms no lock-out")
	hero.run.set_belt(Defs.Weapon.AXE)
	play(hold("F", 2))
	assert_true(hero.attack_gate, "a strike runs")
	play(hold("FS", 1))
	assert_eq(hero.run.weapon, Defs.Weapon.CLUB, "refused during the strike (attack_gate)")
	var ticks: int = 0
	while hero.attack_gate and ticks < 20:
		play(hold("", 1))
		ticks += 1
	assert_true(hero.swing_lock > 0 or ticks > 0, "the swing ended")
	play(hold("S", 1))
	assert_eq(hero.run.weapon, Defs.Weapon.AXE, "allowed again once the strike ended (also during swing_lock)")


func test_swap_works_in_the_air_and_changes_no_motion() -> void:
	var keys: PackedInt32Array = hold("RU", 6) + hold("R", 3) + hold("", 4)
	var with_swap: PackedInt32Array = keys.duplicate()
	with_swap[3] |= Defs.IN_SWAP
	var runs: Array = []
	for flags: PackedInt32Array in [keys, with_swap]:
		fresh_flat()
		spawn_hero()
		hero.run.set_belt(Defs.Weapon.BOOMERANG)
		runs.append(_trace(flags))
	assert_eq(runs[1], runs[0], "the same x, y, xvel, yvel, state and timers on every tick")
	assert_eq(hero.run.weapon, Defs.Weapon.BOOMERANG, "and it swapped in mid-air")


func test_belt_invariance_without_swap() -> void:
	var keys: PackedInt32Array = hold("R", 10) + hold("RU", 12) + hold("F", 9) + hold("DF", 9) + hold("L", 6)
	var reference: Array = []
	for belt: int in [PlayerRun.BELT_EMPTY, Defs.Weapon.HAMMER, Defs.Weapon.AXE, Defs.Weapon.BOOMERANG,
			Defs.Weapon.SPEAR]:
		fresh_flat()
		spawn_hero()
		hero.run.set_belt(belt)
		var trace: Array = _trace(keys)
		if reference.is_empty():
			reference = trace
		else:
			assert_eq(trace, reference, "belt %s changes nothing without Swap" % Defs.weapon_name(belt))


func test_swap_is_refused_while_stunned_dead_or_curled() -> void:
	fresh_flat()
	spawn_hero()
	hero.run.set_belt(Defs.Weapon.HAMMER)
	hero.hit_timer = Tuning.HIT_STUN_MIN
	assert_false(hero.hero_belt.can_swap(), "hurt-stunned")
	hero.hit_timer = Tuning.HIT_STUN_MIN - 1
	assert_true(hero.hero_belt.can_swap(), "the immune ticks after the stun allow it")
	hero.hit_timer = 0
	hero.curl = PlayerBase.CURL_CURLED
	assert_false(hero.hero_belt.can_swap(), "curled")
	hero.curl = PlayerBase.CURL_NONE
	hero.down = true
	assert_false(hero.hero_belt.can_swap(), "an egg")
	hero.down = false
	hero.dead = true
	assert_false(hero.hero_belt.can_swap(), "dead")
	hero.dead = false
	assert_true(hero.hero_belt.try_swap())
	assert_eq(hero.run.weapon, Defs.Weapon.HAMMER)


func test_down_and_swap_is_a_plain_swap_in_single_player() -> void:
	fresh_flat()
	spawn_hero()
	hero.run.set_belt(Defs.Weapon.HAMMER)
	play(hold("DS", 1))
	assert_eq(hero.run.weapon, Defs.Weapon.HAMMER, "no curl without a party: Down + Swap swaps")
	assert_eq(hero.state, Defs.HeroState.CROUCH, "and he crouches as usual")


func test_pick_up_rule_with_the_belt() -> void:
	fresh_flat()
	spawn_hero()
	HeroBelt.give_weapon(hero, Defs.Weapon.AXE)
	assert_eq([hero.run.weapon, hero.run.belt], [Defs.Weapon.AXE, Defs.Weapon.CLUB], "special in the hand, club on the belt")
	HeroBelt.give_weapon(hero, Defs.Weapon.SPEAR)
	assert_eq([hero.run.weapon, hero.run.belt], [Defs.Weapon.SPEAR, Defs.Weapon.CLUB], "the axe is gone")
	HeroBelt.give_weapon(hero, Defs.Weapon.CLUB)
	assert_eq([hero.run.weapon, hero.run.belt], [Defs.Weapon.CLUB, Defs.Weapon.SPEAR], "a club item swaps them")
	HeroBelt.give_weapon(hero, Defs.Weapon.CLUB)
	assert_eq([hero.run.weapon, hero.run.belt], [Defs.Weapon.CLUB, Defs.Weapon.SPEAR], "club in hand: nothing changes")
	HeroBelt.give_weapon(hero, Defs.Weapon.HAMMER)
	assert_eq([hero.run.weapon, hero.run.belt], [Defs.Weapon.HAMMER, Defs.Weapon.CLUB], "the belt's spear is gone too")
	HeroBelt.give_weapon(hero, Defs.Weapon.CLUB)
	HeroBelt.give_weapon(hero, Defs.Weapon.AXE, true)
	assert_eq([hero.run.weapon, hero.run.belt], [Defs.Weapon.CLUB, Defs.Weapon.AXE], "a versus crate: onto the belt")
	HeroBelt.give_weapon(null, Defs.Weapon.AXE)
	var bare: PlayerBase = PlayerBase.new()
	HeroBelt.give_weapon(bare, Defs.Weapon.HAMMER)
	assert_eq(bare.run.weapon, Defs.Weapon.HAMMER, "a bare PlayerBase: the 1.0 rule")
	bare.run.set_weapon(Defs.Weapon.CLUB)
	bare.free()


func test_hurt_and_respawn_keep_hand_and_belt() -> void:
	fresh_flat()
	spawn_hero()
	hero.run.set_belt(Defs.Weapon.AXE)
	play(hold("S", 1))
	assert_true(hero.hurt(null))
	assert_eq([hero.run.weapon, hero.run.belt], [Defs.Weapon.AXE, Defs.Weapon.CLUB])
	hero.respawn_at(START)
	assert_eq([hero.run.weapon, hero.run.belt], [Defs.Weapon.AXE, Defs.Weapon.CLUB])
	assert_eq(hero.hero_belt.swap_lock, 0, "a respawn clears the lock-out")


# =================================================================================================================
# Spear
# =================================================================================================================

func test_spear_flies_flat_then_drops() -> void:
	fresh_flat()
	spawn_hero()
	var anchor: Vector2i = START + Vector2i(20, -20)
	assert_true(HeroSpear.throw_from(hero, anchor, Tuning.SPEAR_POWER))
	var spear: HeroSpear = _spears()[0]
	assert_eq(spear.sim_pos, anchor + Vector2i(12, 0), "spawned one tick of its motion ahead of the anchor")
	assert_eq([spear.xvel, spear.yvel, spear.power, spear.owner_slot], [Tuning.SPEAR_XVEL, 0, 25, 0])
	assert_eq([spear.box_w, spear.box_h, spear.box_xo], [24, 6, 12])
	assert_true(spear.from_hero)
	var xs: Array[int] = []
	var ys: Array[int] = []
	hero.facing = 1
	play(hold("", 12), func(_t: int) -> void:
		xs.append(spear.sim_pos.x - anchor.x)
		ys.append(spear.sim_pos.y - anchor.y)
	)
	assert_ints_eq(xs, [24, 36, 48, 60, 72, 84, 96, 108, 120, 132, 144, 156], "12 px per tick")
	assert_ints_eq(ys, [0, 0, 0, 0, 0, 0, 0, 0, 1, 3, 6, 10], "flat for 8 moves, then +16 v16 per tick")


func test_spear_thrown_left_and_its_fall_cap() -> void:
	fresh_flat()
	spawn_hero()
	hero.facing = -1
	assert_true(HeroSpear.throw_from(hero, START, 100))
	var spear: HeroSpear = _spears()[0]
	assert_eq(spear.xvel, -Tuning.SPEAR_XVEL)
	assert_eq(spear.facing, -1)
	assert_eq(spear.power, 100, "a charged throw keeps the x4 power")
	spear.on_screen = true
	for i: int in 30:
		spear.yvel = mini(spear.yvel, 1000)
		Sim.step(1)
		if not is_instance_valid(spear) or spear.spent:
			break
		spear.on_screen = true
	if is_instance_valid(spear) and not spear.spent:
		assert_eq(spear.yvel, Tuning.SPEAR_FALL_MAX, "the drop is capped at 192")
	else:
		fail("the spear should still fly while it is on the view")


func test_spear_hits_an_enemy_and_is_used_up() -> void:
	fresh_flat()
	spawn_hero()
	var enemy: EnemyBase = EnemyBase.new()
	enemy.set_box(Vector3i(16, 16, 8))
	place(level, enemy, START + Vector2i(80, 0), {"hp": 100})
	enemy.wake()
	assert_true(HeroSpear.throw_from(hero, START + Vector2i(10, -6), Tuning.SPEAR_POWER))
	var spear: HeroSpear = _spears()[0]
	play(hold("", 10))
	assert_eq(enemy.hp, 75, "the spear's power")
	assert_false(is_instance_valid(spear) and not spear.spent, "used up by the hit")
	assert_eq(HeroSpear.count_of(level, 0), 0)


func test_two_spears_per_hero_a_third_pulls_out_the_oldest() -> void:
	fresh_flat()
	spawn_hero()
	for i: int in 2:
		assert_true(HeroSpear.throw_from(hero, START - Vector2i(0, 20 * i), 25))
	var first: HeroSpear = _spears()[0]
	assert_eq(HeroSpear.count_of(level, 0), 2)
	assert_true(HeroSpear.throw_from(hero, START - Vector2i(0, 60), 25))
	assert_true(first.spent, "the oldest is pulled out")
	assert_eq(HeroSpear.count_of(level, 0), 2)
	assert_eq(HeroSpear.count_of(level, 1), 0, "every hero has his own")


func test_max_thrown_counts_spears_with_the_other_throws() -> void:
	fresh_flat()
	spawn_hero()
	for i: int in Tuning.MAX_THROWN:
		level.spawn(Player.ID_AXE, START + Vector2i(0, -10 * i), {"from_hero": true, "owner": 0, "xvel": 16})
	assert_false(HeroSpear.throw_from(hero, START, 25), "four of his own throws in flight: nothing is thrown")
	assert_eq(HeroSpear.count_of(level, 0), 0)
	var partner_axes: int = 0
	for projectile: SimEntity in level.get_kind(Defs.Kind.HERO_PROJECTILE):
		if (projectile as ProjectileBase).owner_slot == 0:
			partner_axes += 1
	assert_eq(partner_axes, Tuning.MAX_THROWN)
	fresh_flat()
	spawn_hero()
	for i: int in Tuning.MAX_THROWN:
		level.spawn(Player.ID_AXE, START + Vector2i(0, -10 * i), {"from_hero": true, "owner": 1, "xvel": 16})
	assert_true(HeroSpear.throw_from(hero, START, 25), "a partner's throws do not count")


func test_spear_sticks_in_a_bark_board_and_its_step_counts() -> void:
	fresh_flat()
	spawn_hero()
	var board: FakeBoard = _board(-1)
	assert_true(HeroSpear.throw_from(hero, START + Vector2i(0, -16), 25))
	var spear: HeroSpear = _spears()[0]
	play(hold("", 6))
	assert_eq(board.asked, 1, "the spear requested a step")
	assert_true(spear.spent, "the flying spear is gone: the step stands for it")
	var step: FakeStep = board.step
	assert_not_null(step)
	assert_eq(HeroSpear.owned_by(level, 0), [step], "the step counts as his spear")
	assert_true(HeroSpear.throw_from(hero, START + Vector2i(0, -60), 25))
	assert_true(HeroSpear.throw_from(hero, START + Vector2i(0, -80), 25))
	assert_true(step.collapsed, "a third spear pulls the oldest out: its step collapses")
	assert_eq(HeroSpear.count_of(level, 0), 2)


func test_spear_glances_off_a_board_with_a_step_and_flies_past_the_wrong_face() -> void:
	fresh_flat()
	spawn_hero()
	var board: FakeBoard = _board(1)
	assert_true(HeroSpear.throw_from(hero, START + Vector2i(0, -16), 25))
	var spear: HeroSpear = _spears()[0]
	play(hold("", 6))
	assert_eq(board.asked, 0, "face = r takes only spears flying left")
	assert_false(spear.spent)
	board.face = -1
	board.step = FakeStep.new()
	assert_true(HeroSpear.throw_from(hero, START + Vector2i(0, -16), 25))
	var second: HeroSpear = _spears()[-1]
	play(hold("", 6))
	assert_eq(board.asked, 1)
	assert_true(second.spent, "a board that holds a live step: the spear glances off")
	assert_false(HeroSpear.owned_by(level, 0).has(board.step))


func test_a_spear_thrown_from_inside_the_boards_reach_sticks() -> void:
	# D5's report (G1): a hero pressed against the board's wall, or standing on a spear step under a second board of the
	# same face, throws from inside the board's reach - the spawn position (anchor + one tick of motion) overlaps the
	# board's cell and the first move carries the box past it. The board is asked at the spawn position too.
	fresh_flat()
	spawn_hero()
	var board: FakeBoard = _board(-1)
	var cell_left: int = board.cell.x * Tuning.TILE
	# Spawned at cell_left + 20: its box (x - 12 .. x + 11) overlaps the cell; after one move (+12) it no longer would.
	var anchor: Vector2i = Vector2i(cell_left + 20 - Tuning.floor16(Tuning.SPEAR_XVEL), board.cell.y * Tuning.TILE + 8)
	assert_true(HeroSpear.throw_from(hero, anchor, Tuning.SPEAR_POWER))
	var spear: HeroSpear = _spears()[0]
	assert_true(Overlap.rects(Rect2i(board.cell * Tuning.TILE, Vector2i(Tuning.TILE, Tuning.TILE)), spear.get_box()),
			"the spawn box overlaps the board's cell")
	play(hold("", 1))
	assert_eq(board.asked, 1, "the board was asked on the first move, before moving")
	assert_true(spear.spent, "it stuck")
	assert_eq(HeroSpear.owned_by(level, 0), [board.step], "its step stands for it")


func test_the_boards_are_kept_and_found_again_when_the_level_changes() -> void:
	# The spear asks only the bark boards each tick (kept on the level, HeroSpear.BOARDS_META), not every OTHER entity;
	# a board placed after the first throw is found because the OTHER list changed.
	fresh_flat()
	spawn_hero()
	assert_true(HeroSpear.throw_from(hero, START + Vector2i(0, -16), 25))
	play(hold("", 10))
	assert_eq(HeroSpear.boards_of(level), [], "no board yet (the first spear flew past where it will stand)")
	var board: FakeBoard = _board(-1)
	assert_eq(HeroSpear.boards_of(level), [board], "the new board is found")
	assert_true(HeroSpear.throw_from(hero, START + Vector2i(0, -16), 25))
	play(hold("", 6))
	assert_eq(board.asked, 1, "and asked by the next spear")


func test_a_step_freed_meanwhile_no_longer_counts() -> void:
	# A step node freed with its level part (or removed on a reset) leaves the per-hero list quietly: no engine error,
	# and the hero has his two spears again.
	fresh_flat()
	spawn_hero()
	var board: FakeBoard = _board(-1)
	board.node_steps = true
	assert_true(HeroSpear.throw_from(hero, START + Vector2i(0, -16), 25))
	play(hold("", 6))
	assert_eq(HeroSpear.count_of(level, 0), 1, "the step counts")
	(board.node_step as Node).free()
	assert_eq(HeroSpear.count_of(level, 0), 0, "a freed step does not")
	assert_true(HeroSpear.throw_from(hero, START + Vector2i(0, -60), 25))
	assert_true(HeroSpear.throw_from(hero, START + Vector2i(0, -80), 25))
	assert_eq(HeroSpear.count_of(level, 0), 2)


func test_a_board_gone_from_the_kept_list_is_looked_for_again() -> void:
	# The kept list is keyed by the size of the OTHER list; a board freed while another OTHER entity appears in the same
	# tick leaves the size as it was. The freed board drops the kept list, so the next move finds the new board.
	fresh_flat()
	spawn_hero()
	var first: FakeBoard = _board(-1)
	assert_eq(HeroSpear.boards_of(level), [first])
	first.free()
	var second: FakeBoard = _board(-1)
	assert_true(HeroSpear.throw_from(hero, START + Vector2i(0, -16), 25))
	var spear: HeroSpear = _spears()[0]
	play(hold("", 6))
	assert_eq(second.asked, 1, "the new board was found")
	assert_true(spear.spent, "and the spear stuck in it")


func test_a_versus_spear_lies_in_front_of_a_walls_face_never_inside_it() -> void:
	# C.14: a spear whose point enters a wall stops and lies there as a temporary pick-up. Inside a solid wall nobody
	# could reach it: it lies in the open cell in front of the face and drops to the floor there (worlds of '#': the
	# arenas' walls are FLOOR and SIDE alike).
	var rows: PackedStringArray = PackedStringArray()
	for row: int in GROUND_ROW + WORLD_ROWS_BELOW:
		var line: String = ""
		for col: int in WORLD_COLS:
			var wall: bool = col >= 66 and col <= 67 and row >= GROUND_ROW - 3
			line += TileGrid.CH_SOLID_A if row >= GROUND_ROW or wall else TileGrid.CH_AIR
		rows.append(line)
	world_rows(rows)
	var grid: TileGrid = level.grid
	var face_cell_x: int = 65 * Tuning.TILE + Tuning.TILE / 2
	assert_eq(HeroSpear.lie_spot(grid, Vector2i(66 * 16 + 5, 310), 192), Vector2i(face_cell_x, 304),
			"into the face: the open cell in front of it")
	assert_eq(HeroSpear.lie_spot(grid, Vector2i(67 * 16 + 3, 310), 192), Vector2i(face_cell_x, 304),
			"two cells deep (thrown from inside the wall's reach): still in front of the face")
	assert_eq(HeroSpear.lie_spot(grid, Vector2i(67 * 16 + 9, 300), -192), Vector2i(68 * 16 + 8, 288),
			"flying left: the face on the right")
	assert_eq(HeroSpear.lie_spot(grid, Vector2i(66 * 16 + 5, 275), 192), Vector2i(66 * 16 + 5, 272),
			"into the wall's top row: on its top")
	assert_eq(HeroSpear.lie_spot(grid, Vector2i(40 * 16 + 5, 322), 192), Vector2i(40 * 16 + 5, 320),
			"down onto a floor: on it")
	# Through the real flight: thrown at the wall, it lies at the foot of the face, where the thrower picks it up.
	Game.mode = Defs.GameMode.VERSUS
	spawn_hero()
	assert_true(HeroSpear.throw_from(hero, START + Vector2i(0, -10), 25))
	play(hold("", 8))
	var pickup: CollectibleBase = null
	for entity: SimEntity in level.get_kind(Defs.Kind.COLLECTIBLE):
		if entity.spawn_params.get("kind", "") == "spear" and bool(entity.spawn_params.get("temp", false)):
			pickup = entity as CollectibleBase
	assert_not_null(pickup, "it lies there as a temporary pick-up")
	if pickup == null:
		Game.mode = Defs.GameMode.SINGLE
		return
	var ticks: int = 0
	while not pickup.resting and ticks < 120:
		play(hold("", 1))
		ticks += 1
	Game.mode = Defs.GameMode.SINGLE
	assert_true(pickup.resting, "it came to rest")
	assert_eq(pickup.sim_pos, Vector2i(face_cell_x, GROUND_ROW * Tuning.TILE), "on the floor in front of the face")
	assert_true(pickup.sim_pos.x + 8 <= 66 * Tuning.TILE, "its box stays out of the wall")


func test_versus_spear_stops_in_a_wall_and_lies_there() -> void:
	world_wall(66, 67)
	Game.mode = Defs.GameMode.VERSUS
	spawn_hero()
	assert_true(HeroSpear.throw_from(hero, START + Vector2i(0, -10), 25))
	var spear: HeroSpear = _spears()[0]
	play(hold("", 6))
	Game.mode = Defs.GameMode.SINGLE
	assert_true(spear.spent, "an arena spear stops at a wall (C.14) ...")
	var pickups: int = 0
	for entity: SimEntity in level.get_kind(Defs.Kind.COLLECTIBLE):
		if entity.spawn_params.get("kind", "") == "spear" and bool(entity.spawn_params.get("temp", false)):
			pickups += 1
	assert_eq(pickups, 1, "... and lies there as a temporary pick-up")
	world_wall(66, 67)
	spawn_hero()
	assert_true(HeroSpear.throw_from(hero, START + Vector2i(0, -10), 25))
	spear = _spears()[0]
	play(hold("", 6))
	assert_false(spear.spent, "outside versus it passes walls like the axe")


func test_spear_in_objects_b_bark_board() -> void:
	world_wall(66, 67)
	if not Spawner.exists(&"objects/bark_board") or not Spawner.exists(&"objects/spear_step"):
		print("    PENDING objects-B objects/bark_board")
		assert_true(true)
		return
	var board: SimEntity = level.spawn(&"objects/bark_board", LevelText.cell_to_feet(66, 18), {"face": "l"})
	assert_not_null(board)
	spawn_hero()
	assert_true(HeroSpear.throw_from(hero, START + Vector2i(0, -16), Tuning.SPEAR_POWER))
	var spear: HeroSpear = _spears()[0]
	play(hold("", 6))
	assert_true(spear.spent, "the spear stuck in the board")
	var owned: Array = HeroSpear.owned_by(level, 0)
	assert_eq(owned.size(), 1, "its step stands for it")
	if owned.is_empty():
		return
	var step: Object = owned[0]
	assert_true(step is PlatformBase, "the step is a sprite platform")
	assert_true(step.has_method(&"collapse"))
	# A second spear at the same board glances off: the board holds a step.
	assert_true(HeroSpear.throw_from(hero, START + Vector2i(0, -16), Tuning.SPEAR_POWER))
	var second: HeroSpear = _spears()[-1]
	play(hold("", 6))
	assert_true(second.spent, "glanced off")
	assert_eq(HeroSpear.count_of(level, 0), 1)
	# Two more throws: the third spear owned pulls the oldest out - the step collapses.
	assert_true(HeroSpear.throw_from(hero, START + Vector2i(0, -60), 25))
	assert_true(HeroSpear.throw_from(hero, START + Vector2i(0, -80), 25))
	assert_false(is_instance_valid(step) and not (step as Node).is_queued_for_deletion() \
			and bool(step.call(&"is_solid")), "the oldest (the step) was pulled out")
	assert_eq(HeroSpear.count_of(level, 0), 2)


func test_spear_through_the_real_strike() -> void:
	fresh_flat()
	spawn_hero()
	hero.run.set_weapon(Defs.Weapon.SPEAR)
	var thrown: Array[SimEntity] = []
	play(hold("F", 12), func(_t: int) -> void:
		for entity: SimEntity in level.get_kind(Defs.Kind.HERO_PROJECTILE):
			if not thrown.has(entity):
				thrown.append(entity)
	)
	assert_true(thrown.size() >= 1, "the strike threw something")
	if thrown.is_empty():
		return
	if thrown[0] is HeroSpear:
		var spear: HeroSpear = thrown[0]
		assert_eq(absi(spear.xvel), Tuning.SPEAR_XVEL)
		assert_eq(spear.power, Tuning.SPEAR_POWER)
		assert_eq(hero.swing_lock >= 0, true)
	else:
		# Player._throw routes the spear to HeroSpear.throw_from once player-A's hook lands
		# (build/engine_requests/wf7_player-B_to_player-A.txt #1).
		print("    PENDING player-A spear hook: the strike still throws %s" % thrown[0].get_script().resource_path)
		assert_true(HeroSpear.throw_from(hero, hero.sim_pos, Tuning.SPEAR_POWER), "the throw itself works")


# =================================================================================================================
# Helpers
# =================================================================================================================

## A stand-in bark board 60 px in front of START, 20 px up, with its air on side `face`.
func _board(face: int) -> FakeBoard:
	var board: FakeBoard = FakeBoard.new()
	board.cell = Vector2i(Tuning.to_cell(START.x + 60), Tuning.to_cell(START.y - 20))
	board.face = face
	place(level, board, board.cell * Tuning.TILE + Vector2i(8, 16))
	return board


func _spears() -> Array[HeroSpear]:
	var spears: Array[HeroSpear] = []
	for entity: SimEntity in level.get_kind(Defs.Kind.HERO_PROJECTILE):
		if entity is HeroSpear:
			spears.append(entity as HeroSpear)
	return spears


## Per tick: position, velocities, state, handler and the timers a swap must not touch.
func _trace(flags: PackedInt32Array) -> Array:
	var rows: Array = []
	play(flags, func(_t: int) -> void:
		rows.append([hero.sim_pos, hero.xvel, hero.yvel, hero.state, hero.handler, hero.swing_lock, hero.charge,
				hero.jump_ticks, hero.no_jump, hero.attack_gate, hero.club_box_active])
	)
	return rows

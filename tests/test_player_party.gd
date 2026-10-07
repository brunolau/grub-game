extends PartyTestCase
## The hero's side of the party rules (docs/spec/PHYSICS.md C.10-C.14, PLAN.md P1.4): the component switch, Shoulder
## Hop and Totem Ride against PARTY_REFERENCE.json, the rider's drop and the scrape, a hurt carrier, the curl, the
## batted ball (line drive, lob, grounder, charged; walls, landings, small and big enemies, blocks), the bat by a
## strike in versus, the edge walls, the egg (voluntary, by a death toss, hatched), the versus hurt table, hit-stop,
## squash, the immunity that a strike ends, the Brace flag, the emote bubble and the movement-cap hooks.


# =================================================================================================================
# The component
# =================================================================================================================

func test_the_party_component_is_off_for_a_party_of_one() -> void:
	world_flat()
	spawn_hero()
	assert_false(hero.hero_party.active, "single-player: the 1.0 hero")
	assert_null(hero.get_node(^"Sprite").material, "single-player: no palette material")
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 1)
	world_flat()
	spawn_hero()
	assert_false(hero.hero_party.active, "a co-op party of one is the 1.0 hero too")
	party(Defs.GameMode.COOP)
	assert_true(p1.hero_party.active and p1.hero_party.coop and not p1.hero_party.versus)
	assert_true(p2.hero_party.active and p2.hero_party.coop)
	party(Defs.GameMode.VERSUS)
	assert_true(p1.hero_party.versus and not p1.hero_party.coop)


# =================================================================================================================
# Shoulder Hop and Totem Ride (C.10)
# =================================================================================================================

## A hero falling onto his still partner's head with UP held bounces -224: his feet reach 140 px over the floor, tick
## for tick as PARTY_REFERENCE.json shoulder_hop.
func test_shoulder_hop_matches_the_reference() -> void:
	var ref: Dictionary = party_reference()["shoulder_hop"]
	party(Defs.GameMode.COOP, P2_START - Vector2i(0, 90), P2_START)
	p1.yvel = Tuning.GRAVITY
	p1.no_jump = Tuning.NO_JUMP_TICKS
	p1.grounded = false
	var heights: Array[int] = []
	var hop_tick: Array[int] = [0]
	play_party([[60, "U|"]], func(t: int) -> void:
		if hop_tick[0] == 0:
			for contact: Vector3i in driver.contacts:
				if contact == Vector3i(0, 1, PlayerBase.HEAD_HOP):
					hop_tick[0] = t
					assert_eq(GROUND_ROW * 16 - p1.sim_pos.y, PartyTuning.TOTEM_HEAD_PX, "lifted onto the head")
					assert_eq(p1.yvel, PartyTuning.SHOULDER_HOP_YVEL)
		elif heights.size() < 26:
			heights.append(GROUND_ROW * 16 - p1.sim_pos.y)
	)
	assert_true(hop_tick[0] > 0, "the hop happened")
	var want: Array = []
	for row: Variant in ref["feet_per_tick"]:
		want.append(int(row[1]))
	assert_ints_eq(heights, want.slice(0, heights.size()), "feet over the floor after the hop")
	var top: int = 0
	for h: int in heights:
		top = maxi(top, h)
	assert_eq(top, int(ref["feet_apex_over_floor_px"]), "apex 140 px")
	assert_eq(p2.sim_pos, P2_START, "the partner is unaffected")


func test_totem_ride_starts_carries_and_halves_the_carrier_jump() -> void:
	var ref: Dictionary = party_reference()["totem_ride"]
	party(Defs.GameMode.COOP, P2_START - Vector2i(0, 60), P2_START)
	p1.yvel = Tuning.GRAVITY
	p1.no_jump = Tuning.NO_JUMP_TICKS
	p1.grounded = false
	play_party([[30, "|"]])
	assert_eq(p1.totem_carrier, p2, "landing without UP: a ride")
	assert_eq(p2.totem_rider, p1)
	assert_eq(p1.sim_pos.y, p2.sim_pos.y - PartyTuning.TOTEM_REST_PX, "rests 34 px over the carrier's feet")
	assert_true(p1.on_platform and p1.is_grounded())
	var x_before: int = p1.sim_pos.x
	var carrier_before: int = p2.sim_pos.x
	play_party([[8, "|R"]], func(_t: int) -> void:
		assert_eq(p1.sim_pos.y, p2.sim_pos.y - PartyTuning.TOTEM_REST_PX, "carried on the head")
	)
	assert_eq(p1.sim_pos.x - x_before, p2.sim_pos.x - carrier_before, "carried by the carrier's dx")
	assert_eq(p1.totem_carrier, p2)
	play_party([[20, "|"]])
	var heights: Array[int] = []
	play_party([[12, "|U"]], func(_t: int) -> void:
		heights.append(GROUND_ROW * 16 - p2.sim_pos.y)
		assert_eq(p1.sim_pos.y, p2.sim_pos.y - PartyTuning.TOTEM_REST_PX, "the rider stays on during the hop")
	)
	assert_ints_eq(heights, ref["carrier_heights"], "the carrier's halved jump (UP held)")
	assert_eq(p1.totem_carrier, p2, "still riding after the carrier's hop")


## The rider's own jump from a still carrier: feet apex 98 px (UP released after 5 ticks), 94 px (held).
func test_rider_jump_from_a_still_carrier() -> void:
	var still: Dictionary = party_reference()["totem_ride"]["rider_jump_from_still_carrier"]
	for k: int in [5, 99]:
		_ride_still()
		var top: int = _rider_apex(k, 0)
		assert_eq(top, int(still[str(k)]), "UP held %d ticks" % k)


## The Totem launch (R6): the rider presses Jump on tick 5 of the carrier's jump - 152 px (UP 5 ticks), 140 (held).
func test_totem_launch_timed_after_the_carrier() -> void:
	var timed: Array = party_reference()["totem_ride"]["rider_jump_timed"]
	var row: Dictionary = timed[4]
	assert_eq(int(row["t0"]), 5)
	for k: int in [5, 99]:
		_ride_still()
		var top: int = _rider_apex(k, 5)
		assert_eq(top, int(row["rider_feet_apex_by_k"][str(k)]), "pressed on carrier tick 5, held %d" % k)


func _ride_still() -> void:
	party(Defs.GameMode.COOP, P2_START - Vector2i(0, 60), P2_START)
	p1.yvel = Tuning.GRAVITY
	p1.no_jump = Tuning.NO_JUMP_TICKS
	p1.grounded = false
	play_party([[30, "|"]])


## Highest feet of the rider over the floor when he presses UP on tick `t0` of the carrier's jump (0 = the carrier
## stays still) for `k` ticks, until his next head contact.
func _rider_apex(k: int, t0: int) -> int:
	assert_eq(p1.totem_carrier, p2, "riding before the jump")
	var entries: Array = []
	var rider_from: int = maxi(t0, 1)
	var carrier: String = "U" if t0 > 0 else ""
	if rider_from > 1:
		entries.append([rider_from - 1, "|" + carrier])
	entries.append([k, "U|" + carrier])
	entries.append([60, "|" + carrier])
	var top: Array[int] = [0]
	var done: Array[bool] = [false]
	play_party(entries, func(t: int) -> void:
		if done[0] or t < rider_from:
			return
		if t > rider_from and not driver.contacts.is_empty():
			done[0] = true
			return
		top[0] = maxi(top[0], GROUND_ROW * 16 - p1.sim_pos.y)
	)
	return top[0]


func test_the_rider_drops_through_his_carrier_with_down_and_up() -> void:
	_ride_still()
	play_party([[1, "DU|"]])
	assert_null(p1.totem_carrier, "the drop ends the ride")
	assert_null(p2.totem_rider)
	assert_eq(p1.totem_drop_lock, PartyTuning.TOTEM_DROP_LOCK_TICKS - 1, "drop lock (counted in 8i)")
	play_party([[20, "|"]], func(_t: int) -> void:
		assert_true(driver.contacts.is_empty(), "no head contact while he falls through")
	)
	assert_eq(p1.sim_pos.y, GROUND_ROW * 16, "down on the floor")
	assert_eq(p1.totem_drop_lock, 0)


func test_a_hurt_carrier_throws_his_rider_off_unharmed() -> void:
	_ride_still()
	var hearts: int = p1.run.hearts
	assert_true(p2.hurt(null, Defs.HurtKind.ENEMY))
	assert_null(p1.totem_carrier)
	assert_eq(p1.yvel, PartyTuning.TOTEM_THROW_OFF_YVEL, "launch(0, -64)")
	assert_eq(p1.no_jump, Tuning.NO_JUMP_TICKS)
	assert_eq(p1.run.hearts, hearts, "no damage")
	assert_eq(p1.hit_timer, 0)


func test_a_ceiling_scrapes_the_rider_off() -> void:
	_ride_still()
	var head_row: int = Tuning.to_cell(p1.sim_pos.y) - Tuning.HEAD_PROBE_ROWS
	var col: int = Tuning.to_cell(p2.sim_pos.x) + 3
	for c: int in range(col, col + 6):
		Game.level.grid.set_props(c, head_row, 0, 0, TileGrid.CEILING_SOLID, TileGrid.PROFILE_NONE)
	var scraped: Array[int] = [0]
	play_party([[30, "|R"]], func(t: int) -> void:
		if scraped[0] == 0 and p1.totem_carrier == null:
			scraped[0] = t
			assert_true(Tuning.to_cell(p1.sim_pos.x) < col, "pushed back out of the ceiling")
	)
	assert_true(scraped[0] > 0, "scraped off under the ceiling")
	assert_true(p2.sim_pos.x > col * 16, "the carrier walks on under it")


func test_land_on_partner_rules() -> void:
	party(Defs.GameMode.COOP)
	assert_eq(p1.land_on_partner(p2), PlayerBase.HEAD_NONE, "side by side: no contact")
	assert_eq(p1.land_on_partner(p1), PlayerBase.HEAD_NONE)
	p1.teleport(p2.sim_pos - Vector2i(0, 30))
	p1.yvel = -32
	assert_eq(p1.land_on_partner(p2), PlayerBase.HEAD_NONE, "rising: no contact")
	p1.yvel = 32
	p1.totem_drop_lock = 3
	assert_eq(p1.land_on_partner(p2), PlayerBase.HEAD_NONE, "drop lock")
	p1.totem_drop_lock = 0
	p2.curl = PlayerBase.CURL_CURLED
	assert_eq(p1.land_on_partner(p2), PlayerBase.HEAD_NONE, "no ride on a curled partner")
	p2.curl = PlayerBase.CURL_NONE
	assert_eq(p1.land_on_partner(p2), PlayerBase.HEAD_RIDE)
	# On an egg, UP held: the hatch with the plain bounce, never the Shoulder Hop (G1 resolution).
	party(Defs.GameMode.COOP)
	p2.go_down(&"voluntary")
	p1.teleport(p2.sim_pos - Vector2i(0, 20))
	p1.yvel = 32
	p1.set(&"_raw_flags", Defs.IN_UP)
	assert_true(p1.holds_up())
	assert_eq(p1.land_on_partner(p2), PlayerBase.HEAD_HATCH)
	assert_eq(p1.yvel, Tuning.BOUNCE_YVEL, "-64 with UP held")
	assert_false(p2.down)
	# Far apart (the coarse reject that comes first): nothing, whatever else holds.
	party(Defs.GameMode.COOP)
	p1.teleport(p2.sim_pos - Vector2i(Tuning.OVERLAP_MAX_DX, 20))
	p1.yvel = 32
	assert_eq(p1.land_on_partner(p2), PlayerBase.HEAD_NONE)
	p1.teleport(p2.sim_pos - Vector2i(0, Tuning.OVERLAP_MAX_DY))
	assert_eq(p1.land_on_partner(p2), PlayerBase.HEAD_NONE)
	p1.teleport(p2.sim_pos - Vector2i(0, 20))
	assert_eq(p1.land_on_partner(p2), PlayerBase.HEAD_RIDE, "close enough: the ride")


# =================================================================================================================
# Curl and the batted ball (C.11)
# =================================================================================================================

func test_down_and_swap_curls_until_down_is_released() -> void:
	party(Defs.GameMode.COOP)
	play_party([[1, "DS|"]])
	assert_eq(p1.curl, PlayerBase.CURL_CURLED)
	assert_eq(p1.state, Defs.HeroState.CURL)
	assert_eq(Vector3i(p1.box_w, p1.box_h, p1.box_xo), HeroParty.curl_box(), "curl box 24 x 20")
	assert_eq(p1.run.weapon, Defs.Weapon.CLUB, "Down + Swap does not swap")
	play_party([[10, "DR|"]])
	assert_eq(p1.curl, PlayerBase.CURL_CURLED, "every input but DOWN is ignored")
	assert_eq(p1.facing, 1)
	assert_eq(p1.xvel, 0)
	play_party([[1, "|"]])
	assert_eq(p1.curl, PlayerBase.CURL_NONE, "DOWN released: uncurled")
	assert_eq(p1.state, Defs.HeroState.IDLE)
	assert_true(p1.hero_belt.swap_lock >= Tuning.SWAP_LOCKOUT_TICKS - 1, "the swap lock-out after a curl")


func test_a_curl_lasts_66_ticks_at_most_and_needs_the_ground() -> void:
	party(Defs.GameMode.COOP)
	play_party([[1, "DS|"], [PartyTuning.CURL_MAX_TICKS - 1, "D|"]])
	assert_eq(p1.curl, PlayerBase.CURL_CURLED, "66 ticks curled")
	play_party([[1, "D|"]])
	assert_eq(p1.curl, PlayerBase.CURL_NONE, "then up again")
	assert_eq(p1.state, Defs.HeroState.CROUCH, "DOWN still held: a crouch")
	party(Defs.GameMode.COOP)
	play_party([[3, "U|"], [1, "DS|"]])
	assert_eq(p1.curl, PlayerBase.CURL_NONE, "no curl in the air")
	party(Defs.GameMode.COOP)
	play_party([[2, "F|"], [1, "DSF|"]])
	assert_eq(p1.curl, PlayerBase.CURL_NONE, "no curl while a strike runs")


## The reference flies to the right: to the left a speed that is no multiple of 16 v16 floors 1 px farther per tick
## (floor16(-216) = -14, the asymmetry of PHYSICS.md 15.5), so every flight here goes right.
func test_line_drive_lob_and_grounder_fly_as_the_reference() -> void:
	var ref: Dictionary = party_reference()["batter_up"]
	for flight: String in ["line_drive", "lob", "line_drive_charged", "lob_charged"]:
		var data: Dictionary = ref[flight]
		_curled_p2(P1_START - Vector2i(300, 0))
		var start: Vector2i = p2.sim_pos
		p2.bat(int(data["xvel"]), int(data["yvel"]), p1)
		assert_eq(p2.curl, PlayerBase.CURL_BALL)
		assert_eq(p2.ball_batter, p1)
		var rows: Array = []
		var landed: Array[int] = [0]
		var landed_dx: Array[int] = [0]
		var lock: Array[int] = [0]
		play_party([[int(data["back_tick"]) + 2, "|"]], func(t: int) -> void:
			if landed[0] != 0:
				return
			rows.append([t, p2.sim_pos.x - start.x, start.y - p2.sim_pos.y])
			if p2.curl == PlayerBase.CURL_NONE:
				landed[0] = t
				landed_dx[0] = p2.sim_pos.x - start.x
				lock[0] = p2.no_jump
		)
		var per_tick: Array = data["per_tick"]
		for i: int in mini(rows.size(), per_tick.size()) - 1:
			assert_ints_eq(rows[i], per_tick[i], "%s tick %d (tick, x, height)" % [flight, i + 1])
		assert_eq(landed[0], int(data["back_tick"]), "%s: lands and uncurls on tick %d" % [flight, data["back_tick"]])
		assert_eq(landed_dx[0], int(data["dx_at_back"]), "%s: distance" % flight)
		assert_eq(p2.sim_pos.x - start.x, int(data["dx_at_back"]), "%s: it stops where it lands" % flight)
		assert_eq(p2.sim_pos.y, start.y, "%s: back on the floor" % flight)
		assert_eq(lock[0], Tuning.NO_JUMP_TICKS, "%s: the landing lock-out" % flight)
		assert_eq(Vector3i(p2.box_w, p2.box_h, p2.box_xo), Tuning.HERO_BOX_STAND)
	for flight: String in ["grounder", "grounder_charged"]:
		var data: Dictionary = ref[flight]
		_curled_p2(P1_START - Vector2i(300, 0))
		var start_x: int = p2.sim_pos.x
		p2.bat(int(data["xvel"]), 0, p1)
		var uncurled: Array[int] = [0]
		play_party([[int(data["ticks"]) + 2, "|"]], func(t: int) -> void:
			if uncurled[0] == 0 and p2.curl == PlayerBase.CURL_NONE:
				uncurled[0] = t
				assert_eq(p2.sim_pos.x - start_x, int(data["dx"]), "%s: rolled distance" % flight)
		)
		assert_eq(uncurled[0], int(data["ticks"]), "%s: uncurls after 32 ticks" % flight)
		assert_eq(p2.xvel, 0)


func _curled_p2(at: Vector2i = P2_START + Vector2i(96, 0)) -> void:
	party(Defs.GameMode.COOP, P1_START, at)
	driver.fence = false
	play_party([[1, "|DS"]])
	assert_eq(p2.curl, PlayerBase.CURL_CURLED)


func test_a_ball_uncurls_at_a_wall_and_ignores_the_keys() -> void:
	_curled_p2()
	var col: int = Tuning.to_cell(p2.sim_pos.x) - 5
	for row: int in range(GROUND_ROW - 4, GROUND_ROW):
		Game.level.grid.set_props(col, row, TileGrid.FLOOR_SOLID, TileGrid.SIDE_WALL, 0, TileGrid.PROFILE_NONE)
	p2.bat(-PartyTuning.BAT_GROUNDER_XVEL, 0, p1)
	play_party([[30, "|L"]], func(_t: int) -> void:
		if p2.curl == PlayerBase.CURL_BALL:
			assert_eq(p2.facing, 1, "a ball ignores the keys")
	)
	assert_eq(p2.curl, PlayerBase.CURL_NONE, "uncurled at the wall")
	assert_true(p2.sim_pos.x > (col + 1) * 16 - 1, "stopped in front of it")


func test_a_ball_knocks_small_enemies_once_and_a_big_one_ends_the_flight() -> void:
	_curled_p2()
	var small: EnemyBase = EnemyBase.new()
	place(Game.level, small, p2.sim_pos - Vector2i(40, 0), {"hp": 49})
	small.wake()
	var big: EnemyBase = EnemyBase.new()
	place(Game.level, big, p2.sim_pos - Vector2i(120, 0), {"hp": 50})
	big.wake()
	Sim.step(1)
	p2.bat(-PartyTuning.BAT_GROUNDER_XVEL, 0, p1)
	var hearts: int = p2.run.hearts
	play_party([[30, "|"]])
	assert_eq(small.hp, 49 - PartyTuning.BALL_POWER, "small enemy: 25 once per flight")
	assert_eq(big.hp, 50, "a big one is not hurt by the ball ...")
	assert_eq(p2.run.hearts, hearts - 1, "... it hurts the ball")
	assert_eq(p2.curl, PlayerBase.CURL_NONE, "and ends the flight")


func test_a_ball_breaks_a_block_at_once() -> void:
	_curled_p2()
	var col: int = Tuning.to_cell(p2.sim_pos.x) - 4
	var row: int = GROUND_ROW - 1
	Game.level.set_cell(col, row, TileGrid.CH_SOLID_A)
	var block: HittableBase = Game.level.spawn(&"objects/breakable_block", Vector2i(col * 16 + 8, (row + 1) * 16),
			{"hits": 3}) as HittableBase
	assert_not_null(block)
	p2.bat(-PartyTuning.BAT_GROUNDER_XVEL, 0, p1)
	play_party([[16, "|"]])
	assert_true(block.opened, "broken by one touch of the ball")
	assert_true(p2.sim_pos.x < col * 16, "and the ball rolled on through")


func test_a_front_strike_bats_a_curled_rival_in_versus() -> void:
	for charged: bool in [false, true]:
		party(Defs.GameMode.VERSUS, P1_START, P1_START + Vector2i(22, 0))
		play_party([[1, "|DS"]])
		assert_eq(p2.curl, PlayerBase.CURL_CURLED)
		if charged:
			play_party([[20, "D|D"]])
		var batted: Array[int] = [0]
		play_party([[8, "F|D"]], func(t: int) -> void:
			if batted[0] == 0 and p2.curl == PlayerBase.CURL_BALL:
				batted[0] = t
				assert_eq(p2.ball_batter, p1)
				var line: Vector2i = Vector2i(PartyTuning.BAT_LINE_DRIVE_XVEL, PartyTuning.BAT_LINE_DRIVE_YVEL)
				if charged:
					line = Vector2i(PartyTuning.bat_charged(line.x), PartyTuning.bat_charged(line.y))
				assert_eq(p2.xvel, line.x, "line drive xvel (charged %s)" % charged)
		)
		assert_eq(batted[0], 6, "batted by the forward front box (made on tick 5, tested on tick 6)")


# =================================================================================================================
# Edge walls (C.13)
# =================================================================================================================

func test_edge_walls_stop_a_hero_at_the_view_side() -> void:
	party(Defs.GameMode.COOP)
	var walls: Vector2i = Game.level.get_edge_walls()
	assert_eq(walls.y - walls.x, Tuning.VIEW_COLS * Tuning.TILE - 2 * PartyTuning.VIEW_EDGE_WALL_PX)
	assert_false(p1.x_commit_allows(walls.x - 1))
	assert_true(p1.x_commit_allows(walls.x))
	assert_false(p1.x_commit_allows(walls.y))
	play_party([[60, "L|"]])
	assert_true(p1.sim_pos.x >= walls.x and p1.sim_pos.x < walls.x + 6, "stopped at the left wall: %d" % p1.sim_pos.x)
	p1.go_down(&"leash")
	assert_true(p1.x_commit_allows(walls.x - 100), "an egg is no member of the tribe: no walls")


# =================================================================================================================
# The egg (C.12)
# =================================================================================================================

func test_voluntary_egg_after_24_ticks_of_down_and_look() -> void:
	party(Defs.GameMode.COOP)
	var downs: Array[StringName] = []
	var on_down: Callable = func(h: PlayerBase, cause: StringName) -> void:
		if h == p1:
			downs.append(cause)
	Events.hero_down.connect(on_down)
	play_party([[PartyTuning.VOLUNTARY_EGG_HOLD_TICKS - 1, "DK|"]])
	assert_false(p1.down, "23 ticks: not yet")
	play_party([[1, "DK|"]])
	Events.hero_down.disconnect(on_down)
	assert_true(p1.down, "24 ticks of Down + Look: an egg")
	assert_eq(downs.size(), 1)
	assert_eq(downs[0], &"voluntary")
	assert_false(p1.dead)
	assert_eq(Vector3i(p1.box_w, p1.box_h, p1.box_xo), HeroParty.egg_box(), "egg box 24 x 24")
	assert_false(p1.get_node(^"Sprite").visible, "the hero is hidden")
	var egg: Sprite2D = p1.get_node_or_null(^"EggSprite") as Sprite2D
	assert_not_null(egg)
	assert_true(egg.visible)
	assert_eq(p1.run.deaths, 1, "a down counts for the tally")
	# Consecutive ticks: letting go of either key starts the count again.
	party(Defs.GameMode.COOP)
	play_party([[PartyTuning.VOLUNTARY_EGG_HOLD_TICKS - 4, "DK|"], [1, "D|"],
			[PartyTuning.VOLUNTARY_EGG_HOLD_TICKS - 1, "DK|"]])
	assert_false(p1.down, "Look let go for a tick: the 24 ticks start again")
	play_party([[1, "DK|"]])
	assert_true(p1.down, "24 consecutive ticks")
	party(Defs.GameMode.COOP)
	p2.go_down(&"voluntary")
	play_party([[30, "DK|"]])
	assert_false(p1.down, "not while the partner is down")


func test_an_egg_touches_nothing_and_hatches_with_the_shield() -> void:
	party(Defs.GameMode.COOP)
	p2.go_down(&"leash")
	assert_true(p2.is_immune())
	assert_false(p2.hurt(null, Defs.HurtKind.ENEMY), "an egg is never hurt")
	p2.kill(&"pit")
	assert_false(p2.dead, "nor killed")
	var at: Vector2i = p2.sim_pos
	play_party([[5, "|R"]])
	assert_eq(p2.sim_pos, at, "an egg has no motion of its own (the PartyDriver drifts it)")
	p2.hatch(p1, PartyTuning.hatch_hearts(Game.difficulty))
	assert_false(p2.down)
	assert_eq(p2.run.hearts, PartyTuning.HATCH_HEARTS_BEGINNER)
	assert_eq(p2.shield, PartyTuning.HATCH_BLINK_TICKS)
	assert_eq(p2.yvel, PartyTuning.HATCH_POP_YVEL, "the -64 pop")
	assert_eq(Vector3i(p2.box_w, p2.box_h, p2.box_xo), Tuning.HERO_BOX_STAND)
	assert_eq(p1.run.revives, 1, "the hatcher's tally")
	assert_true(p2.control_enabled)
	var egg: Sprite2D = p2.get_node(^"EggSprite") as Sprite2D
	play_party([[1, "|"]])
	assert_true(egg.visible and egg.frame >= HeroParty.EGG_FRAME_HATCH, "the shell left behind")
	assert_true(p2.get_node(^"Sprite").visible)
	play_party([[HeroParty.SHELL_TICKS, "|"]])
	assert_false(egg.visible)
	play_party([[PartyTuning.HATCH_BLINK_TICKS, "|"]])
	assert_eq(p2.shield, 0, "the shield runs out")


## An egg is no springboard (orchestrator resolution after G1): a hero falling onto an egg hatches it with the plain
## enemy bounce (Tuning.BOUNCE_YVEL, -64: a 10 px rise) whether he holds UP or not - never the Shoulder Hop's -224.
func test_an_egg_is_no_springboard() -> void:
	for up: bool in [true, false]:
		party(Defs.GameMode.COOP, P2_START - Vector2i(0, 120), P2_START)
		p2.go_down(&"voluntary")
		var egg_at: Vector2i = P2_START - Vector2i(0, 48)
		p2.teleport(egg_at)  # an egg floats where the driver puts it (no tile collision)
		p1.yvel = Tuning.GRAVITY
		p1.no_jump = Tuning.NO_JUMP_TICKS
		p1.grounded = false
		var hatched: Array[int] = [0]
		var bounce_y: Array[int] = [0]
		var top: Array[int] = [0]
		var done: Array[bool] = [false]
		play_party([[40, "U|" if up else "|"]], func(t: int) -> void:
			if done[0]:
				return
			if hatched[0] == 0:
				for contact: Vector3i in driver.contacts:
					if contact == Vector3i(0, 1, PlayerBase.HEAD_HATCH):
						hatched[0] = t
						bounce_y[0] = p1.sim_pos.y
						assert_eq(p1.yvel, Tuning.BOUNCE_YVEL, "UP held %s: the hatching stomp bounces -64" % up)
						assert_false(p2.down, "the egg hatched")
						# The body that pops out is no head for a hero holding UP until he is ACTIVE: world-A's
						# PartyDriver rule (tests/test_world_party.gd); this stand-in driver has none, so move it away.
						p2.teleport(p2.sim_pos + Vector2i(160, 0))
				return
			if not driver.contacts.is_empty() or p1.yvel > 0:
				done[0] = true  # past the apex (a later contact with the hatched body is the driver's ACTIVE rule)
				return
			top[0] = maxi(top[0], bounce_y[0] - p1.sim_pos.y)
		)
		assert_true(hatched[0] > 0, "UP held %s: he fell onto the egg and hatched it" % up)
		var rise: int = -1
		for launch: Variant in party_reference()["launches"]:
			if int(launch["yvel"]) == Tuning.BOUNCE_YVEL:
				rise = int(launch["rise_px"])
		assert_eq(rise, 10, "PARTY_REFERENCE.json: a -64 launch rises 10 px")
		assert_eq(top[0], rise, "UP held %s: a 10 px rise, as on an enemy without UP" % up)
		assert_eq(p2.run.hearts, PartyTuning.hatch_hearts(Game.difficulty))


func test_a_death_toss_ends_where_it_started() -> void:
	party(Defs.GameMode.COOP)
	var at: Vector2i = p2.sim_pos
	p2.kill(&"spikes")
	assert_eq(p2.death_origin, at)
	assert_eq(p2.death_cause, &"spikes")
	play_party([[Tuning.DEATH_ANIM_TICKS + 1, "|"]])
	assert_true(p2.down, "the stand-in driver made an egg")
	assert_false(p2.dead)
	assert_eq(p2.sim_pos, at)


# =================================================================================================================
# Versus (C.14)
# =================================================================================================================

func test_versus_hurt_table_matches_the_reference() -> void:
	var knocks: Dictionary = party_reference()["versus"]["knock_backs"]
	for name: String in ["hit_right", "hit_left", "hammer_right", "charged_right", "charged_left"]:
		var want: Dictionary = knocks[name]
		var right: bool = name.ends_with("right")
		party(Defs.GameMode.VERSUS, P1_START if right else P2_START + Vector2i(40, 0), P2_START)
		if name.begins_with("hammer"):
			p1.run.weapon = Defs.Weapon.HAMMER
		p1.club_power = Tuning.WEAPON_POWER[p1.run.weapon] * (Tuning.CHARGE_MULTIPLIER if name.begins_with("charged") else 1)
		var hearts: int = p2.run.hearts
		assert_true(p2.hurt(p1, Defs.HurtKind.RIVAL), name)
		assert_eq(p2.run.hearts, hearts, "%s: no heart (the referee charges the mode's currency)" % name)
		assert_eq([p2.xvel, p2.yvel, p2.ice], [int(want["xvel"]), int(want["yvel"]), int(want["ice"])], name)
		assert_eq(p2.hit_timer, VersusTuning.HURT_TIMER_TICKS)
		var x0: int = p2.sim_pos.x
		var landing: Array[int] = [0]
		var stunned: Array[int] = [0]
		play_party([[40, "|"]], func(t: int) -> void:
			if p2.state == Defs.HeroState.HURT:
				stunned[0] += 1
			if landing[0] == 0 and t > 1 and p2.grounded:
				landing[0] = t
		)
		assert_eq(p2.sim_pos.x - x0, int(want["dx"]), "%s: distance" % name)
		assert_eq(landing[0], int(want["landing_tick"]), "%s: landing tick" % name)
		# Stunned while hit_timer >= 31: a hit landing between two ticks shows 43..31 (13 PLAYER phases); the referee's
		# hit lands in WEAPONS, where that tick's POST takes the first (12, the 1.0 count of a contact hurt).
		assert_eq(stunned[0], VersusTuning.HURT_TIMER_TICKS - VersusTuning.STUN_HIT_TIMER_MIN + 1, "%s: stun" % name)


func test_a_swirling_axe_pops_and_a_strike_ends_the_immunity() -> void:
	party(Defs.GameMode.VERSUS)
	var axe: SimEntity = Game.level.spawn(&"projectiles/hero_boomerang", p2.sim_pos - Vector2i(10, 10),
			{"from_hero": true, "power": Tuning.WEAPON_POWER[Defs.Weapon.BOOMERANG], "owner": 0}) as SimEntity
	assert_not_null(axe)
	assert_true(p2.hurt(axe, Defs.HurtKind.RIVAL))
	assert_eq(p2.yvel, VersusTuning.BOOMERANG_POP_YVEL, "the swirling axe pops him up")
	assert_eq(p2.xvel, VersusTuning.HIT_XVEL)
	assert_false(p2.hurt(p1, Defs.HurtKind.RIVAL), "immune meanwhile")
	play_party([[VersusTuning.STUN_TICKS + 1, "|"]])
	assert_true(p2.hit_timer > 0 and p2.hit_timer < VersusTuning.STUN_HIT_TIMER_MIN, "immune with control")
	p2.shield = 20
	play_party([[1, "|F"]])
	assert_eq(p2.hit_timer, 0, "his strike ends the immunity")
	assert_eq(p2.shield, 0, "and the spawn shield")
	p2.feast = 30
	assert_false(p2.hurt(p1, Defs.HurtKind.RIVAL), "the feaster cannot be hit")


func test_hit_stop_and_squash() -> void:
	party(Defs.GameMode.VERSUS)
	p2.hit_stop = VersusTuning.HIT_STOP_TICKS
	var x0: int = p2.sim_pos.x
	play_party([[VersusTuning.HIT_STOP_TICKS, "|R"]])
	assert_eq(p2.sim_pos.x, x0, "no PLAYER phase during the hit-stop")
	assert_eq(p2.hit_stop, 0)
	play_party([[2, "|R"]])
	assert_true(p2.sim_pos.x > x0, "then he moves again")
	p2.squash = VersusTuning.STOMP_SQUASH_TICKS
	play_party([[3, "|U"]])
	assert_eq(p2.jump_ticks, 0, "squashed: no jump")
	play_party([[2, "|F"]])
	assert_false(p2.attack_gate, "squashed: no strike")
	var x1: int = p2.sim_pos.x
	play_party([[2, "|R"]])
	assert_true(p2.sim_pos.x > x1, "walking is allowed")
	play_party([[5, "|"]])
	assert_eq(p2.squash, 0)


func test_versus_weight_hooks() -> void:
	var stack: Dictionary = party_reference()["versus"]["jumps"]["stack_20"]
	party(Defs.GameMode.VERSUS, P1_START, P1_START + Vector2i(200, 0))
	p1.walk_cap_override = VersusTuning.STACK_HEAVIER_WALK_CAP
	p1.jump_scale_3_4 = true
	play_party([[20, "R|"]])
	assert_eq(p1.xvel, VersusTuning.STACK_HEAVIER_WALK_CAP, "a 20+ stack walks at 48")
	play_party([[20, "|"]])
	var floor_y: int = p1.sim_pos.y
	var top: Array[int] = [0]
	var landing: Array[int] = [0]
	play_party([[40, "U|"]], func(t: int) -> void:
		top[0] = maxi(top[0], floor_y - p1.sim_pos.y)
		if landing[0] == 0 and t > 1 and p1.grounded:
			landing[0] = t
	)
	assert_eq(top[0], int(stack["apex_px"]), "apex with impulses x3/4")
	assert_eq(landing[0], int(stack["landing_tick"]))
	p1.respawn_at(P1_START)
	assert_eq([p1.walk_cap, p1.air_cap, p1.jump_impulse_quarters], [Tuning.WALK_CAP, Tuning.WALK_CAP, 4],
			"a respawn restores the 1.0 values")


# =================================================================================================================
# Brace flag (C.10), emote, poses
# =================================================================================================================

class HeavyStub:
	extends EnemyBase

	var stops: int = 0

	func brace_stop(_hero: PlayerBase, _partner: PlayerBase) -> bool:
		stops += 1
		xvel = 0
		return true


func test_brace_wall_stops_a_heavy_and_a_lone_croucher_is_hurt() -> void:
	party(Defs.GameMode.COOP, P1_START, P1_START + Vector2i(12, 0))
	var heavy: HeavyStub = HeavyStub.new()
	place(Game.level, heavy, P1_START - Vector2i(10, 0))
	heavy.wake()
	play_party([[2, "D|D"]])
	assert_true(p1.is_braced() and p2.is_braced(), "two croucher within 16 px")
	assert_eq(p1.brace_partner(), p2)
	var hearts: int = p1.run.hearts
	play_party([[4, "D|D"]])
	assert_true(heavy.stops > 0, "the heavy's brace rule was asked")
	assert_eq(p1.run.hearts, hearts, "nobody is touched")
	assert_eq(p1.hit_timer, 0)
	party(Defs.GameMode.COOP, P1_START, P1_START + Vector2i(60, 0))
	var lone: HeavyStub = HeavyStub.new()
	place(Game.level, lone, P1_START - Vector2i(10, 0))
	lone.wake()
	play_party([[4, "D|D"]])
	assert_false(p1.is_braced())
	assert_eq(lone.stops, 0)
	assert_true(p1.hit_timer > 0, "a lone croucher is trampled")


func test_a_double_tap_of_look_shows_an_emote() -> void:
	party(Defs.GameMode.COOP)
	var seen: Array[int] = []
	p1.emoted.connect(func(kind: int) -> void: seen.append(kind))
	play_party([[1, "K|"], [3, "|"], [1, "K|"]])
	assert_eq(seen.size(), 1, "a double tap")
	assert_eq(seen[0], HeroParty.Emote.EXCLAIM, "'!'")
	var bubble: Node2D = p1.get_node_or_null(^"EmoteBubble") as Node2D
	assert_not_null(bubble)
	assert_true(bubble.visible)
	if ResourceLoader.exists("res://assets/ui/emotes.png"):
		assert_not_null(bubble.get(&"_sheet"), "art-A's ui/emotes.png is drawn")
	play_party([[1, "K|"], [3, "|"], [1, "KU|"]])
	assert_eq(seen.back(), HeroParty.Emote.HEART, "Up on the second tap: a heart")
	play_party([[HeroParty.EMOTE_TICKS, "|"]])
	assert_false(bubble.visible, "gone after 2 s")
	play_party([[1, "K|"], [HeroParty.EMOTE_DOUBLE_TAP_TICKS + 2, "|"], [1, "K|"]])
	assert_eq(seen.size(), 2, "two presses far apart are no double tap")


func test_curl_ball_and_egg_poses() -> void:
	party(Defs.GameMode.COOP)
	play_party([[1, "DS|"]])
	assert_eq(p1.anim_frame, HeroAnim.ROLL_FIRST, "curled: roll frame 24")
	p1.bat(64, -128, p2)
	var frames: Dictionary = {}
	play_party([[8, "|"]], func(_t: int) -> void:
		if p1.curl == PlayerBase.CURL_BALL:
			frames[p1.anim_frame] = true
	)
	for frame: Variant in frames.keys():
		assert_true(int(frame) >= HeroAnim.ROLL_FIRST and int(frame) < HeroAnim.ROLL_FIRST + HeroAnim.ROLL_COUNT)
	assert_true(frames.size() > 1, "the ball rolls through frames 24-26")

extends PlayerTestCase
## Strikes, club boxes, charge, thrown weapons, the weapon pass, bounces, damage, death and respawn
## (PHYSICS.md 8-10, ARCHITECTURE 4.2) against PHYSICS_REFERENCE.json where it has numbers.

const STRIKE_KEYS: Dictionary = {"forward": "F", "high": "UF", "low": "DF"}

var _struck_ticks: Array[int] = []


func before_each() -> void:
	super.before_each()
	_struck_ticks = []
	Events.player_struck.connect(_on_struck)


func after_each() -> void:
	Events.player_struck.disconnect(_on_struck)
	super.after_each()


# --- Strike timelines (8.1, 8.2) --------------------------------------------------------------------------------------

func test_strike_timelines_and_club_boxes() -> void:
	var ref: Dictionary = load_reference()["attack"]
	for strike: String in STRIKE_KEYS:
		var expected: Dictionary = ref[strike]
		world_flat()
		spawn_hero()
		_struck_ticks = []
		var rows: Array[Dictionary] = _strike_rows(str(STRIKE_KEYS[strike]), 40)
		var ends: Array[int] = _struck_ticks.duplicate()
		var label: String = "%s strike" % strike
		assert_eq(ends[0], int(expected["length_ticks"]), label + ": length")
		assert_eq(ends[1] - ends[0], int(expected["auto_repeat_period_ticks"]), label + ": repeat period")
		var front: int = CLUB_FRAME_NAMES.find(str(expected["script"][-1]))
		var created: Array[int] = []
		for i: int in int(expected["length_ticks"]):
			if int(rows[i]["club_frame"]) == front:
				created.append(i + 1)
		assert_ints_eq(created, expected["front_box_created_on_ticks"], label + ": front box ticks")
		var airborne: Array[int] = []
		for i: int in ends[1] - 1:
			if not bool(rows[i]["grounded"]):
				airborne.append(i + 1)
		assert_ints_eq(airborne, expected["airborne_ticks_first_strike"], label + ": hop airborne ticks")
		var per_tick: Array = expected["per_tick"]
		for i: int in per_tick.size():
			var want: Dictionary = per_tick[i]
			var row: Dictionary = rows[i]
			var tick_label: String = "%s tick %d" % [label, i + 1]
			assert_eq(STATE_NAMES[int(row["state"])], str(want["state"]), tick_label + ": state")
			assert_eq(int(row["height"]), int(want["height"]), tick_label + ": height")
			assert_eq(bool(row["grounded"]), bool(want["grounded"]), tick_label + ": grounded")
			if want["club_box"] == null:
				assert_eq(int(row["club_frame"]), Tuning.ClubFrame.NONE, tick_label + ": no club box")
				continue
			var box: Dictionary = want["club_box"]
			assert_eq(CLUB_FRAME_NAMES[int(row["club_frame"])], str(box["frame"]), tick_label + ": frame")
			assert_ints_eq(row["rel_x"], box["x"], tick_label + ": box x range")
			assert_ints_eq(row["rel_y"], box["y"], tick_label + ": box y range")


func test_strike_ignores_input_after_the_last_tick() -> void:
	var ref: Dictionary = load_reference()["attack"]["forward"]
	world_flat()
	spawn_hero()
	var rows: Array[Dictionary] = _strike_rows("F", 7)
	assert_eq(hero.swing_lock, int(ref["swing_lock_set"]) - 1, "swing_lock is set on the last tick, then decremented")
	play(hold("R", 1))
	assert_eq(hero.state, Defs.HeroState.IDLE, "tick 8: inputs are ignored")
	assert_eq(int(ref["input_ignored_ticks"][0]), 8)
	play(hold("R", 1))
	assert_eq(hero.state, Defs.HeroState.WALK, "tick 9: free again")
	assert_eq(rows.size(), 7)


func test_strike_cannot_be_interrupted_but_restarts_with_another_type() -> void:
	world_flat()
	spawn_hero()
	play(hold("F", 2) + hold("R", 3))
	assert_eq(hero.handler, Defs.HeroState.STRIKE, "the strike gate runs the strike for walk input")
	assert_eq(hero.strike_tick, 5)
	assert_eq(hero.xvel, 0, "friction only while striking")
	play(hold("UF", 1))
	assert_eq(hero.handler, Defs.HeroState.HIGH_STRIKE, "a different strike type restarts the script")
	assert_eq(hero.strike_tick, 1)


func test_repeat_period_per_weapon() -> void:
	var ref: Dictionary = load_reference()["attack"]["repeat_period_forward"]
	var names: Array[String] = ["club", "hammer", "axe", "swirling_axe"]
	for weapon: int in names.size():
		Game.set_weapon(weapon)
		world_flat()
		spawn_hero()
		_struck_ticks = []
		_strike_rows("F", 40)
		assert_eq(_struck_ticks[1] - _struck_ticks[0], int(ref[names[weapon]]), "%s repeat period" % names[weapon])
	Game.set_weapon(Defs.Weapon.CLUB)


func test_charge_table() -> void:
	var ref: Dictionary = load_reference()["attack"]["charge"]
	for k: int in [1, 2, 4, 5, 6, 7, 10, 60]:
		var expected: Dictionary = ref["crouch_%d_ticks" % k]
		world_flat()
		spawn_hero()
		play(hold("D", k))
		assert_eq(hero.charge, int(expected["charge_after_crouch"]), "charge after %d crouched ticks" % k)
		var rows: Array[Dictionary] = run_rows(hold("F", 7))
		var powers: Array = []
		var charged_front: int = 0
		for i: int in rows.size():
			var has_box: bool = int(rows[i]["club_frame"]) != Tuning.ClubFrame.NONE
			powers.append(int(rows[i]["club_power"]) if has_box else null)
			if i >= 4 and has_box and int(rows[i]["club_power"]) == 100:
				charged_front += 1
		assert_eq(powers, expected["box_power_per_strike_tick"].map(func(v: Variant) -> Variant:
			return null if v == null else int(v)), "box power per strike tick after %d crouched ticks" % k)
		assert_eq(charged_front, int(expected["charged_front_frames"]))
	world_flat()
	spawn_hero()
	play(hold("D", 80))
	assert_eq(hero.charge, int(ref["saturation_value_after_long_crouch"]))
	var ticks: Array[int] = [0]
	while hero.charge != 0 and ticks[0] < 100:
		play(hold("", 1))
		ticks[0] += 1
	assert_eq(ticks[0], int(ref["ticks_until_zero_after_standing_up"]))


func test_club_box_mirrors_when_facing_left() -> void:
	world_flat()
	spawn_hero()
	hero.facing = -1
	var rows: Array[Dictionary] = _strike_rows("F", 6)
	assert_eq(int(rows[5]["club_frame"]), Tuning.ClubFrame.FWD_FRONT)
	assert_ints_eq(rows[5]["rel_x"], [-35, -11], "front box mirrored: 11..35 px behind his new facing")
	assert_eq(hero.club_origin, Vector2i(START_X - 23, START.y - 2))
	assert_eq(hero.club_box_xo, 12)


# --- Weapon pass (PHYSICS.md 3 step 2, 8.3, 9) ------------------------------------------------------------------------

func test_club_hits_an_enemy_and_the_last_box_pogos() -> void:
	world_flat()
	spawn_hero()
	var enemy: EnemyBase = _place_enemy(START + Vector2i(24, 0), 100)
	play(hold("", 2))
	assert_true(enemy.is_targetable())
	var hp: Array[int] = []
	var yvel_after: Array[int] = []
	play(hold("F", 7) + hold("", 1), func(_t: int) -> void:
		hp.append(enemy.hp)
		yvel_after.append(hero.yvel)
	)
	assert_ints_eq(hp, [100, 100, 100, 100, 100, 75, 50, 25], "front boxes of ticks 5-7 hit on ticks 6-8")
	assert_eq(yvel_after[7], Tuning.POGO_YVEL + Tuning.GRAVITY, "the box made after the hop hits in the air: pogo")
	assert_false(enemy.dead)


func test_charged_strike_kills_in_one_hit() -> void:
	world_flat()
	spawn_hero()
	var enemy: EnemyBase = _place_enemy(START + Vector2i(24, 0), 60)
	play(hold("D", 10))
	play(hold("F", 6))
	assert_true(enemy.dead, "x4 power: 100 > 60")
	assert_eq(enemy.hp, 60 - Tuning.WEAPON_POWER[Defs.Weapon.CLUB] * Tuning.CHARGE_MULTIPLIER)


func test_one_target_per_box_in_slot_order() -> void:
	world_flat()
	spawn_hero()
	var first: EnemyBase = _place_enemy(START + Vector2i(24, 0), 100)
	var second: EnemyBase = _place_enemy(START + Vector2i(26, 0), 100)
	play(hold("", 2) + hold("F", 6))
	assert_eq(first.hp, 75, "the first enemy in slot order takes the hit")
	assert_eq(second.hp, 100, "the box is consumed")


func test_club_opens_a_hittable_when_no_enemy_is_hit() -> void:
	Game.add_completion_totals(1, 0)
	world_flat()
	spawn_hero()
	var spot: HittableBase = HittableBase.new()
	place(level, spot, START + Vector2i(32, 0), {"kind": "small", "count": 3})
	play(hold("F", 6))
	assert_eq(spot.hits_left, 2, "front box origin within a tile: hit")
	play(hold("", 2))
	assert_eq(spot.hits_left, 2, "later boxes fall into its cool-down (and are consumed)")
	assert_eq(hero.yvel, Tuning.POGO_YVEL + Tuning.GRAVITY, "the box made after the hop pogoes on a hidden spot too")


func test_thrown_weapons_fly_like_the_reference() -> void:
	var ref: Dictionary = load_reference()["thrown_weapons"]
	var cases: Dictionary = {"axe": Defs.Weapon.AXE, "swirling_axe": Defs.Weapon.BOOMERANG}
	for weapon_name: String in cases:
		var expected: Dictionary = ref[weapon_name]
		Game.set_weapon(int(cases[weapon_name]))
		world_flat()
		spawn_hero()
		play(hold("F", 6))
		var anchor: Vector2i = hero.club_origin
		play(hold("F", 1))
		assert_eq(hero.club_frame, Tuning.ClubFrame.NONE, "%s: no club box on the throw tick" % weapon_name)
		var thrown: Array[SimEntity] = level.get_kind(Defs.Kind.HERO_PROJECTILE)
		assert_eq(thrown.size(), 1, "%s: one projectile" % weapon_name)
		var projectile: ProjectileBase = thrown[0] as ProjectileBase
		assert_true(projectile.from_hero)
		assert_eq(projectile.power, Tuning.WEAPON_POWER[int(cases[weapon_name])])
		assert_eq(projectile.xvel, int(expected["xvel"]))
		assert_eq(projectile.yvel, int(expected["yvel_start"]))
		assert_eq(projectile.yacc, int(expected["yvel_change_per_tick"]))
		var offset: Array = expected["spawn_offset_from_reference"]
		assert_eq(projectile.sim_pos, anchor + Vector2i(int(offset[0]), int(offset[1])), "leaves the hand at the club")
		var dx: Array[int] = []
		var dy: Array[int] = []
		var last: Array[Vector2i] = [projectile.sim_pos]
		play(hold("", 6), func(_t: int) -> void:
			dx.append(projectile.sim_pos.x - last[0].x)
			dy.append(projectile.sim_pos.y - last[0].y)
			last[0] = projectile.sim_pos
		)
		assert_ints_eq(dx, (expected["dx_per_tick"] as Array).slice(0, 6), "%s dx per tick" % weapon_name)
		assert_ints_eq(dy, (expected["dy_per_tick"] as Array).slice(0, 6), "%s dy per tick" % weapon_name)
	Game.set_weapon(Defs.Weapon.CLUB)


func test_thrown_axe_hits_an_enemy_and_is_consumed() -> void:
	Game.set_weapon(Defs.Weapon.AXE)
	world_flat()
	spawn_hero()
	var enemy: EnemyBase = _place_enemy(START + Vector2i(62, 0), 25)
	play(hold("F", 7))
	var projectile: ProjectileBase = level.get_kind(Defs.Kind.HERO_PROJECTILE)[0] as ProjectileBase
	play(hold("", 1))
	assert_eq(enemy.hp, 25, "still flying on tick 8")
	play(hold("", 1))
	assert_eq(enemy.hp, 25 - Tuning.WEAPON_POWER[Defs.Weapon.AXE], "hit for 20 in the weapon pass of tick 9")
	assert_true(projectile.spent, "removed on the hit")
	Game.set_weapon(Defs.Weapon.CLUB)


func test_thrown_weapons_never_pogo() -> void:
	world_flat()
	spawn_airborne_hero(0, 1, 100)
	var enemy: EnemyBase = _place_enemy(START + Vector2i(100, 0), 100)
	enemy.wake()
	enemy.on_screen = true
	var axe: ProjectileBase = level.spawn(&"projectiles/hero_axe", enemy.sim_pos, {"power": 20}) as ProjectileBase
	var yvel: int = hero.yvel
	play(hold("", 1))
	assert_eq(enemy.hp, 80, "the axe hit while the hero was in the air")
	assert_true(axe.spent)
	assert_eq(hero.yvel, yvel + Tuning.GRAVITY, "no pogo: plain gravity")


func test_at_most_four_thrown_weapons() -> void:
	Game.set_weapon(Defs.Weapon.AXE)
	world_flat()
	spawn_hero()
	for i: int in Tuning.MAX_THROWN:
		level.spawn(&"projectiles/hero_axe", START + Vector2i(-40 + 8 * i, -40), {"power": 20})
	play(hold("F", 7))
	assert_eq(level.get_kind(Defs.Kind.HERO_PROJECTILE).size(), Tuning.MAX_THROWN, "a fifth throw is refused")
	Game.set_weapon(Defs.Weapon.CLUB)


# --- Hurt, invulnerability, death (PHYSICS.md 10) ---------------------------------------------------------------------

func test_hurt_knockback_matches_the_reference() -> void:
	var ref: Dictionary = load_reference()["hurt"]
	for case_name: String in ["standing", "moving_right", "moving_left"]:
		var expected: Dictionary = ref[case_name]
		world_flat()
		spawn_hero()
		if case_name != "standing":
			hero.facing = 1 if case_name == "moving_right" else -1
			hero.xvel = hero.facing * Tuning.WALK_CAP
		assert_true(hero.hurt(null))
		hero.hit_timer -= 1  # the draw step of the hit tick (the hit happens in step 9, after the hero update)
		var rows: Array[Dictionary] = run_rows(hold("", 50))
		var landing: int = first_landing()
		assert_eq(landing, int(expected["landing_tick"]), case_name + ": lands on the 17th tick")
		assert_ints_eq(column(rows, "x", landing), expected["x"], case_name + ": x per tick")
		assert_ints_eq(column(rows, "height", landing), expected["height"], case_name + ": height per tick")
		assert_eq(int(rows[-1]["x"]), int(expected["knockback_px"]), case_name + ": knock-back")
		var stunned: Array[int] = []
		for i: int in rows.size():
			if int(rows[i]["state"]) == Defs.HeroState.HURT:
				stunned.append(i + 1)
		assert_eq(stunned.size(), int(expected["stun_ticks"]), case_name + ": stunned ticks")
		assert_eq(stunned[-1] + 1, int(expected["first_tick_with_control"]))


func test_enemy_contact_hurts_every_44_ticks_and_the_fourth_hit_kills() -> void:
	var ref: Dictionary = load_reference()["hurt"]
	world_flat()
	spawn_hero()
	var enemy: EnemyBase = _place_enemy(START, 25)
	var hurt_ticks: Array[int] = []
	var deaths: Array[StringName] = []
	var on_hurt: Callable = func(_kind: int, _source: SimEntity) -> void: hurt_ticks.append(current_tick)
	var on_died: Callable = func(cause: StringName) -> void: deaths.append(cause)
	Events.player_hurt.connect(on_hurt)
	Events.player_died.connect(on_died)
	play(hold("", 150))
	Events.player_hurt.disconnect(on_hurt)
	Events.player_died.disconnect(on_died)
	assert_eq(hurt_ticks.size(), 4)
	for i: int in range(1, hurt_ticks.size()):
		assert_eq(hurt_ticks[i] - hurt_ticks[i - 1], int(ref["ticks_after_hit_tick_until_contact_tested_again"]),
				"two hits are 44 ticks apart")
	assert_eq(deaths, [&"enemy"] as Array[StringName], "survives %d hits" % int(ref["hits_survived_from_full_energy"]))
	assert_true(enemy.stole_heart)
	assert_eq(Game.hearts, 0)


func test_stomp_bounces_without_damaging() -> void:
	for up: bool in [false, true]:
		world_flat()
		spawn_hero(START + Vector2i(0, -20))
		hero.yvel = 64
		hero.grounded = false
		hero.fall_ticks = 3
		hero.no_jump = Tuning.NO_JUMP_TICKS
		var enemy: EnemyBase = _place_enemy(START, 25)
		enemy.wake()
		enemy.on_screen = true
		var bounced: Array[int] = []
		var on_bounce: Callable = func(_target: SimEntity, multiplier: int) -> void: bounced.append(multiplier)
		Events.player_bounced.connect(on_bounce)
		var bounce_y: Array[int] = [0]
		var peak: Array[int] = [START.y]
		play(hold("U" if up else "", 30), func(_t: int) -> void:
			if bounced.size() == 1:
				if bounce_y[0] == 0:
					bounce_y[0] = hero.sim_pos.y
				peak[0] = mini(peak[0], hero.sim_pos.y)
		)
		Events.player_bounced.disconnect(on_bounce)
		var label: String = "UP held" if up else "UP released"
		assert_false(bounced.is_empty(), label + ": bounced")
		assert_eq(bounced[0], 0, label + ": the first bounce shows no multiplier")
		assert_eq(bounce_y[0], START.y - 16, label + ": lifted by the penetration depth onto the enemy top")
		assert_eq(enemy.hp, 25, label + ": the enemy is not damaged")
		assert_eq(enemy.bounce_count, bounced.size(), label + ": bounce counter")
		assert_eq(Game.hearts, Tuning.ENERGY_START, label + ": not hurt")
		var rise: int = int(load_reference()["impulse_rise"]["-224" if up else "-64"]["rise_px"])
		assert_eq(peak[0], START.y - 16 - rise, label + ": lifted to the enemy top by depth, then the bounce rise")


func test_feast_eats_enemies_and_warns_before_the_end() -> void:
	world_flat()
	spawn_hero()
	var enemy: EnemyBase = _place_enemy(START, 25)
	hero.start_feast(20)
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_FEAST)
	play(hold("", 3))
	assert_true(enemy.dead, "touching an enemy kills it")
	assert_eq(Game.hearts, Tuning.ENERGY_START)
	assert_false(hero.hurt(enemy), "enemy damage is ignored during the feast")
	var ended: Array[int] = []
	var on_feast: Callable = func(ticks: int) -> void: ended.append(ticks)
	Events.feast_changed.connect(on_feast)
	play(hold("", 20))
	Events.feast_changed.disconnect(on_feast)
	assert_true(level.shake_requests.has(9), "a shake warns 7 ticks before the end")
	assert_eq(ended, [0] as Array[int])
	assert_ne(Audio.get_music_context(), Sfx.MUSIC_FEAST)


func test_death_toss_and_respawn_at_the_checkpoint() -> void:
	world_flat()
	level.start_pos = START
	spawn_hero()
	Game.set_checkpoint(START + Vector2i(48, 0))
	var lives: int = Game.lives
	var finished: Array[int] = []
	var on_finished: Callable = func() -> void: finished.append(current_tick)
	Events.player_death_finished.connect(on_finished)
	hero.kill(&"spikes")
	assert_true(hero.dead)
	var path: Array[Vector2i] = []
	play(hold("R", 60), func(_t: int) -> void: path.append(hero.sim_pos))
	Events.player_death_finished.disconnect(on_finished)
	assert_eq(path[13], START + Vector2i(-14 * Tuning.DEATH_DX, -105), "rises 105 px in 14 ticks, drifting 5 px/tick")
	assert_eq(path[14].y, path[13].y, "then turns")
	assert_eq(finished, [Tuning.DEATH_ANIM_TICKS] as Array[int], "player_death_finished after 60 ticks")
	assert_eq(Game.lives, lives - 1)
	assert_false(hero.dead)
	assert_eq(hero.sim_pos, Game.checkpoint_pos, "respawned at the checkpoint")
	assert_eq(Game.hearts, Tuning.ENERGY_START)
	assert_eq(hero.xvel, 0)
	assert_eq(hero.yvel, 0)


func test_trap_and_boss_hits() -> void:
	world_flat()
	spawn_hero()
	assert_true(hero.hurt(null, Defs.HurtKind.TRAP))
	assert_eq(Game.hearts, 0, "all energy scattered")
	assert_false(hero.dead, "a trap never kills")
	assert_true(hero.hurt(null, Defs.HurtKind.TRAP), "traps ignore the immunity")
	hero.respawn_at(START)
	Game.on_respawn()
	var boss_side: SimEntity = SimEntity.new()
	boss_side.sim_pos = START + Vector2i(20, 0)
	assert_true(hero.hurt(boss_side, Defs.HurtKind.BOSS_BODY))
	assert_eq(hero.xvel, -Tuning.BOSS_KNOCK_XVEL, "knocked away from the boss")
	assert_eq(hero.ice, Tuning.ICE_MAX)
	assert_eq(Game.bones, Tuning.BONES_PER_HEART - 1, "one bone")
	assert_false(hero.hurt(boss_side, Defs.HurtKind.BOSS_BODY), "immune for 44 ticks")
	assert_true(hero.hurt(null, Defs.HurtKind.BOSS_PROJECTILE), "boss projectiles ignore the immunity")
	boss_side.free()


# --- Helpers ----------------------------------------------------------------------------------------------------------

## Hold `keys` for `ticks`; rows also carry the club box relative to the hero after the tick.
func _strike_rows(keys: String, ticks: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var origin: Vector2i = hero.sim_pos
	play(hold(keys, ticks), func(_t: int) -> void:
		var box: Rect2i = hero.club_box
		rows.append({
			"state": hero.state, "height": origin.y - hero.sim_pos.y, "grounded": hero.grounded,
			"club_frame": hero.club_frame,
			"rel_x": [box.position.x - hero.sim_pos.x, box.position.x + box.size.x - hero.sim_pos.x],
			"rel_y": [box.position.y - hero.sim_pos.y, box.position.y + box.size.y - hero.sim_pos.y],
		})
	)
	return rows


## A plain EnemyBase (16 x 16 box) with `hp` hit points, already awake and on screen after one tick.
func _place_enemy(pos: Vector2i, hp: int) -> EnemyBase:
	var enemy: EnemyBase = EnemyBase.new()
	place(level, enemy, pos, {"hp": hp})
	return enemy


func _on_struck(_strike: int, _weapon: int) -> void:
	_struck_ticks.append(current_tick)

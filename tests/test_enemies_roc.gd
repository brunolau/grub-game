extends "res://tests/test_enemies_case.gd"
## The Storm Roc (scripts/bosses/roc.gd, scripts/projectiles/boss_bolt.gd; DESIGN.md B.5, GAMEPLAY.md 13.6; PLAN.md
## P2.3, owner enemies-C): the nest and the perch, phase 1 (wings telegraph, gusts of wind, feathers, the head open from
## the nest), phase 2 (circle, a 14-tick screech, the dive, the buried beak), phase 3 (lightning marked 22 ticks ahead,
## burning nest sticks, the gliders on the nest, three glider dives, the defeat), the hit-point floor between the
## phases; the co-op form (the wing shield, the Snatch and the rescue, Pilot and Spotter) and the single-hero search.
##
## The room: 20 x 12 cells, invisible walls in columns 0 and 19, the nest of one-way cells in columns 6-13 of row 8
## (top y 128), the floor at row 10 (feet y 160). The Roc's record stands on the nest at column 9.

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const NEST_X0: int = 96
const NEST_X1: int = 224
const NEST_TOP: int = 128

var _p2: PlayerBase = null
var _defeated: Array[BossBase] = []


func before_each() -> void:
	super.before_each()
	_defeated.clear()
	_p2 = null
	Events.boss_defeated.connect(_on_defeated)


func after_each() -> void:
	Events.boss_defeated.disconnect(_on_defeated)
	GameInput.clear_scripted()
	Game.helper_mode = false
	if _level != null and is_instance_valid(_level):
		_level.set_wind(0)
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"")


# =================================================================================================================
# The nest and phase 1
# =================================================================================================================

func test_the_roc_finds_its_nest_and_perches_on_a_rim() -> void:
	var roc: Roc = _fight()
	assert_eq([roc.nest_x0, roc.nest_x1, roc.nest_top], [NEST_X0, NEST_X1, NEST_TOP], "the run of nest cells")
	assert_eq(roc.get_state(), Roc.State.REST)
	assert_eq(roc.sim_pos, Vector2i(NEST_X0 + 52 - 16, NEST_TOP), "on the left rim")
	assert_eq(roc.get_box(), Rect2i(roc.sim_pos.x - 52, NEST_TOP - 44, 104, 44), "104 x 44")
	assert_eq(roc.max_hp, 300, "phases 1-2 take 200; the last third falls to three dives")
	assert_eq(roc.get_storm_hp(), 100)
	assert_false(roc.is_coop_form())
	assert_eq(_level.get_kind(Defs.Kind.BOSS).size(), 1)


func test_wings_telegraph_then_a_gust_blows_away_from_it_with_feathers() -> void:
	var roc: Roc = _fight()
	_hero.teleport(Vector2i(200, NEST_TOP))
	Sim.step(Roc.REST_TICKS - 1)
	assert_eq(roc.get_state(), Roc.State.WINGS, "rests 44 ticks (the first was the fight's), then raises its wings")
	assert_eq(_level.wind, 0, "the wings come first: no wind yet")
	Sim.step(Roc.WINGS_TICKS - 1)
	assert_eq(_level.wind, 0, "14 ticks of warning")
	Sim.step(1)
	assert_eq(roc.get_state(), Roc.State.GUST)
	assert_eq(_level.wind, -Roc.GUST_WIND, "facing right: the gust blows to the right, away from it")
	Sim.step(Roc.FEATHER_PERIOD + 1)
	assert_true(_of_scene(Defs.Kind.ENEMY_PROJECTILE, &"projectiles/enemy_ember").size() >= 1, "feathers fall")
	for feather: SimEntity in _of_scene(Defs.Kind.ENEMY_PROJECTILE, &"projectiles/enemy_ember"):
		assert_eq((feather as EnemyEmber).skin, EnemyEmber.SKIN_FEATHER, "drawn as roc_parts feathers (enemies-A / C)")
	Sim.step(Roc.GUST_TICKS - Roc.FEATHER_PERIOD - 1)
	assert_eq(_level.wind, 0, "66 ticks of wind")
	assert_eq(roc.get_state(), Roc.State.REST, "then it rests again")
	for gust: int in Roc.GUSTS - 1:
		Sim.step(Roc.REST_TICKS + Roc.WINGS_TICKS + Roc.GUST_TICKS)
		_hero.hit_timer = 0
		Game.hearts = Tuning.ENERGY_START
	assert_eq(roc.get_state(), Roc.State.TAKEOFF, "after 3 gusts it takes off")


func test_the_perched_head_takes_a_high_strike_from_the_nest() -> void:
	var roc: Roc = _fight()
	var head: Rect2i = roc.get_head_rect()
	assert_eq(head, Rect2i(roc.sim_pos.x - 52, NEST_TOP - 44, 104, 20), "the top band of the body")
	var high: Rect2i = _high_box(Vector2i(roc.sim_pos.x + 62, NEST_TOP), -1)
	assert_true(Overlap.rects(high, head), "a high strike from the nest beside it reaches the head")
	assert_false(Overlap.body(_at(Vector2i(roc.sim_pos.x + 62, NEST_TOP)), roc, _hero), "without touching its body")
	_hero.club_box_active = true
	_hero.club_box = high
	_hero.club_power = 25
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(roc.hp, 275, "a club hit")
	assert_eq(roc.last_hitter, _hero)


func test_dive_screeches_14_ticks_and_a_miss_buries_the_beak() -> void:
	var roc: Roc = _fight()
	_hero.teleport(Vector2i(60, 160))
	roc._take_off()
	var circled: int = _step_until(func() -> bool: return roc.get_state() == Roc.State.SCREECH, 300)
	assert_true(circled > 0, "takes off, circles, then screeches")
	var aim: Vector2i = _hero.sim_pos
	Sim.step(Roc.SCREECH_TICKS - 1)
	assert_eq(roc.get_state(), Roc.State.SCREECH, "14 ticks of screech")
	Sim.step(1)
	assert_eq(roc.get_state(), Roc.State.DIVE, "then the dive")
	_hero.teleport(Vector2i(300, 160))
	var buried: int = _step_until(func() -> bool: return roc.get_state() == Roc.State.BURIED, 60)
	assert_true(buried > 0, "the hero stepped away: a miss")
	assert_eq(roc.sim_pos.y, 160, "the beak in the floor")
	assert_true(absi(roc.sim_pos.x - aim.x) <= Roc.DIVE_SPEED, "where he stood at the end of the screech")
	var head: Rect2i = roc.get_head_rect()
	assert_true(head.size.x > 0 and head.end.y > 160 - 16, "the head is low: open to a forward strike")
	_throw_at(head, 25)
	Sim.step(1)
	assert_eq(roc.hp, 275)
	Sim.step(Roc.BURY_TICKS)
	assert_eq(roc.get_state(), Roc.State.RISE, "44 ticks, then it rises")


func test_a_dive_that_meets_a_hero_hurts_and_pulls_up() -> void:
	var roc: Roc = _fight()
	_hero.teleport(Vector2i(60, 160))
	roc._take_off()
	_step_until(func() -> bool: return roc.get_state() == Roc.State.DIVE, 300)
	var hurt: int = _step_until(func() -> bool: return _hero.hit_timer > 0, 60)
	assert_true(hurt > 0, "the dive reaches the hero who stays")
	assert_eq(Game.bones, Tuning.BONES_PER_HEART - 1, "the boss body: a bone")
	assert_eq(roc.get_state(), Roc.State.RISE, "it pulls up")


func test_phases_one_and_two_stop_at_a_third_and_the_storm_follows() -> void:
	var roc: Roc = _fight()
	roc.hp = roc.get_storm_hp() + 10
	_hero.club_box_active = true
	_hero.club_box = roc.get_head_rect()
	_hero.club_power = 100
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(roc.hp, roc.get_storm_hp(), "weapons stop at the last third")
	Sim.step(Tuning.BOSS_HIT_COOLDOWN)
	_hero.club_box_active = true
	_hero.club_box = roc.get_head_rect()
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(roc.hp, roc.get_storm_hp(), "it glances now")
	_step_until(func() -> bool: return roc.is_storm_phase(), 400)
	assert_true(roc.is_storm_phase(), "the gust ends, then the storm")
	assert_eq(_gliders(), 1, "the hang-glider lies on the nest")
	var glider: SimEntity = _of_scene(Defs.Kind.COLLECTIBLE, &"items/glider")[0]
	assert_eq(glider.sim_pos.y, NEST_TOP)
	assert_true(glider.sim_pos.x >= NEST_X0 and glider.sim_pos.x < NEST_X1)
	_step_until(func() -> bool: return roc.get_state() == Roc.State.STORM, 200)
	assert_true(roc.sim_pos.y < 0, "it climbs above the view")


func test_lightning_is_marked_22_ticks_ahead_and_nest_sticks_burn() -> void:
	_room()
	var bolt: BossBolt = _spawn(&"projectiles/boss_bolt", Vector2i(120, 0), {
		"mark": 22, "bottom": 192, "nest_x0": NEST_X0, "nest_x1": NEST_X1, "nest_top": NEST_TOP}) as BossBolt
	_hero.teleport(Vector2i(122, NEST_TOP))
	assert_eq(bolt.strike_y, NEST_TOP, "it strikes the nest under the column")
	assert_true(bolt.burns)
	Sim.step(21)
	assert_true(bolt.is_marking())
	assert_eq(Game.hearts, Tuning.ENERGY_START, "the darkening cloud harms nobody")
	Sim.step(1)
	assert_true(bolt.is_striking(), "22 ticks after the mark")
	Sim.step(1)
	assert_eq(Game.hearts, Tuning.ENERGY_START - 1, "the bolt hurts as an enemy contact")
	_hero.hit_timer = 0
	Sim.step(BossBolt.BOLT_TICKS)
	assert_true(bolt.is_burning(), "the struck sticks burn")
	Sim.step(1)
	assert_eq(Game.hearts, Tuning.ENERGY_START - 2, "and burn whoever stands in them")
	Sim.step(BossBolt.BURN_TICKS)
	assert_true(bolt.spent, "for 66 ticks")
	var floor_bolt: BossBolt = _spawn(&"projectiles/boss_bolt", Vector2i(88, 0), {
		"bottom": 192, "nest_x0": NEST_X0, "nest_x1": NEST_X1, "nest_top": NEST_TOP}) as BossBolt
	assert_eq(floor_bolt.strike_y, 160, "beside the nest it strikes the floor")
	assert_false(floor_bolt.burns)
	Game.runs[0].has_glider = true
	_hero.hit_timer = 0
	_hero.teleport(Vector2i(88, 60))
	Sim.step(23)
	assert_false(Game.runs[0].has_glider, "a glider is lost instead of a heart")
	assert_eq(Game.hearts, Tuning.ENERGY_START - 2)


func test_three_glider_dives_bring_it_down() -> void:
	var roc: Roc = _fight()
	roc.hp = roc.get_storm_hp()
	roc._begin_storm()
	var score: int = Game.score
	for dive: int in 3:
		_step_until(func() -> bool: return roc.get_state() == Roc.State.CRUISE, 400)
		assert_eq(roc.get_state(), Roc.State.CRUISE, "dive %d: it cruises in view" % dive)
		_glide_onto(_hero, roc)
		Sim.step(1)
		if dive < 2:
			assert_eq(roc.get_state(), Roc.State.TUMBLE, "it tumbles low over the nest")
			assert_eq(_hero.yvel, Tuning.GLIDER_BUMP_YVEL, "the pilot is bumped up")
		_hero.glide = 0
		_hero.teleport(Vector2i(30, 160))
	assert_eq(Game.score - score, 1000 + 5000 + 10000, "the dive ladder")
	assert_eq(roc.get_state(), Roc.State.DYING, "the third dive brings it down")
	_step_until(func() -> bool: return roc.dead, 80)
	assert_true(roc.dead)
	assert_eq(_defeated, [roc] as Array[BossBase])
	if Spawner.exists(&"items/fire_starter"):
		var starters: Array[SimEntity] = _of_scene(Defs.Kind.COLLECTIBLE, &"items/fire_starter")
		assert_eq(starters.size(), 1, "the fire-starter")
		assert_true(absi(starters[0].sim_pos.x - (NEST_X0 + NEST_X1) / 2) <= 16, "over the nest")
	assert_eq(_level.wind, 0)


## Book II rule: the solo Roc falls. Bare heroes play it through: club hits on the head whenever it is open (phases 1-2),
## glider dives in the storm; it is defeated and never stun-locked (it keeps acting between the hits).
func test_the_solo_roc_can_be_beaten_through_all_phases() -> void:
	var roc: Roc = _fight()
	var states: Dictionary = {}
	for tick: int in 6000:
		var head: Rect2i = roc.get_head_rect()
		# Four hits while it perches, the rest on the buried beak: both phases get their turn.
		var perched_hits_done: bool = roc.hp <= roc.max_hp - 100
		var buried: bool = roc.get_state() == Roc.State.BURIED
		if head.size.x > 0 and roc.hit_cooldown == 0 and not roc.is_storm_phase() \
				and (buried or not perched_hits_done):
			_hero.club_box_active = true
			_hero.club_box = head
			_hero.club_power = 25
		if roc.get_state() == Roc.State.CRUISE:
			_glide_onto(_hero, roc)
		Sim.step(1)
		_hero.club_box_active = false
		_hero.glide = 0
		# Stand at the left end; once a dive is under way step to the right end: every dive misses.
		var diving: bool = roc.get_state() == Roc.State.DIVE or roc.get_state() == Roc.State.SWOOP
		_hero.teleport(Vector2i(290 if diving else 30, 160))
		_hero.hit_timer = 0
		Game.hearts = Tuning.ENERGY_START
		states[roc.get_state()] = true
		if roc.dead:
			break
	assert_true(roc.dead, "beaten (hp %d)" % roc.hp)
	for state: int in [Roc.State.GUST, Roc.State.DIVE, Roc.State.BURIED, Roc.State.STORM, Roc.State.CRUISE]:
		assert_true(states.has(state), "went through state %d" % state)


# =================================================================================================================
# The co-op form
# =================================================================================================================

func test_coop_the_wing_shield_faces_the_nearer_hero() -> void:
	var roc: Roc = _coop_fight(Vector2i(roc_right(), NEST_TOP), Vector2i(20, 160))
	assert_true(roc.is_coop_form())
	assert_eq(roc.max_hp, 375, "phases 1-2 take 250")
	assert_eq(roc.facing, 1, "it faces P1, the nearer")
	_hero.club_box_active = true
	_hero.club_box = roc.get_head_rect()
	_hero.club_power = 25
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(roc.hp, 375, "a hit from the shield's side glances")
	_p2.teleport(Vector2i(roc.sim_pos.x - 62, NEST_TOP))
	_hero.teleport(Vector2i(roc.sim_pos.x + 80, NEST_TOP))
	Sim.step(1)
	_p2.club_box_active = true
	_p2.club_box = roc.get_head_rect()
	_p2.club_power = 25
	Sim.step(1)
	_p2.club_box_active = false
	assert_eq(roc.facing, -1, "now P2 is nearer: the shield turns to him")
	assert_eq(roc.hp, 375, "and his hit glances")
	Sim.step(Tuning.BOSS_HIT_COOLDOWN)
	_hero.club_box_active = true
	_hero.club_box = roc.get_head_rect()
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(roc.hp, 350, "the far hero's hit counts: a pincer")
	Sim.step(Tuning.BOSS_HIT_COOLDOWN)
	var axe: ProjectileBase = _shot(Vector2i(roc.sim_pos.x, NEST_TOP - 30), 100, 0)
	Sim.step(1)
	assert_true(axe.spent)
	assert_eq(roc.hp, 350, "a throw flying in from the shield's side (P2's) glances, whoever threw it")


func test_coop_snatch_and_the_partners_rescue() -> void:
	Game.difficulty = Defs.Difficulty.EXPERT
	var roc: Roc = _coop_fight(Vector2i(60, 160), Vector2i(260, 160))
	roc._take_off()
	_step_until(func() -> bool: return roc.get_state() == Roc.State.SCREECH, 300)
	var target: PlayerBase = roc._target_hero()
	_step_until(func() -> bool: return roc.get_state() != Roc.State.SCREECH and roc.get_state() != Roc.State.DIVE, 80)
	assert_eq(roc.get_state(), Roc.State.SNATCH, "the dive grabs its target")
	assert_eq(roc.get_held(), target)
	assert_false(target.control_enabled, "he cannot move or strike")
	var y0: int = roc.sim_pos.y
	Sim.step(10)
	assert_eq(roc.sim_pos.y, y0 - 10 * Roc.SNATCH_RISE, "it climbs at 2 px per tick")
	assert_eq(target.sim_pos, roc.sim_pos + Vector2i(0, Roc.SNATCH_HANG_DY), "he hangs under it")
	var partner: PlayerBase = _p2 if target == _hero else _hero
	partner.club_box_active = true
	partner.club_box = roc.get_head_rect()
	partner.club_power = 25
	Sim.step(1)
	partner.club_box_active = false
	assert_null(roc.get_held(), "the partner's hit frees him")
	assert_true(target.control_enabled)
	assert_eq(target.shield, Roc.FREE_SHIELD_TICKS)
	assert_eq(roc.get_state(), Roc.State.STUNNED, "the rescue stuns it")
	assert_eq(roc.hp, 350, "the hit counts")
	assert_true(roc.get_head_rect().size.x > 0, "head open")
	Sim.step(Roc.STUN_TICKS)
	assert_eq(roc.get_state(), Roc.State.RISE, "66 ticks")


func test_coop_an_unrescued_hero_becomes_an_egg() -> void:
	Game.difficulty = Defs.Difficulty.EXPERT
	var roc: Roc = _coop_fight(Vector2i(60, 160), Vector2i(260, 160))
	roc._take_off()
	_step_until(func() -> bool: return roc.get_state() == Roc.State.SNATCH, 400)
	var target: PlayerBase = roc.get_held()
	assert_not_null(target)
	var downs: Array[PlayerBase] = []
	var on_down: Callable = func(hero: PlayerBase, _cause: StringName) -> void: downs.append(hero)
	Events.hero_down.connect(on_down)
	Sim.step(Roc.SNATCH_TICKS)
	Events.hero_down.disconnect(on_down)
	assert_true(target.is_down(), "73 ticks without a rescue: an egg")
	assert_eq(downs, [target] as Array[PlayerBase])
	assert_null(roc.get_held())


## Helper mode (PHYSICS.md C.12): the Snatch makes an egg outside hurt(), so a Helper-mode P2 is never snatched; the
## dive's touch spares him like every boss body.
func test_coop_a_helper_is_never_snatched() -> void:
	Game.difficulty = Defs.Difficulty.EXPERT
	var roc: Roc = _coop_fight(Vector2i(60, 160), Vector2i(260, 160))
	Game.helper_mode = true
	_hero.down = true
	assert_true(_p2.is_helper())
	roc._take_off()
	var dived: bool = false
	for tick: int in 500:
		Sim.step(1)
		_p2.hit_timer = 0
		dived = dived or roc.get_state() == Roc.State.DIVE
		assert_null(roc.get_held(), "never holds the helper")
	assert_true(dived, "it dived at him")
	assert_false(_p2.is_down(), "no egg")
	Game.helper_mode = false


func test_coop_beginner_has_no_snatch() -> void:
	var roc: Roc = _coop_fight(Vector2i(60, 160), Vector2i(260, 160))
	roc._take_off()
	_step_until(func() -> bool: return roc.get_state() == Roc.State.DIVE, 300)
	_step_until(func() -> bool: return roc.get_state() != Roc.State.DIVE, 60)
	assert_ne(roc.get_state(), Roc.State.SNATCH, "boss grabs are off on Beginner (GAMEPLAY 13.9.10)")


func test_coop_pilot_and_spotter() -> void:
	var roc: Roc = _coop_fight(Vector2i(30, 160), Vector2i(150, NEST_TOP))
	roc.hp = roc.get_storm_hp()
	roc._begin_storm()
	Sim.step(1)
	assert_eq(_gliders() + int(_hero.run.has_glider) + int(_p2.run.has_glider), 2,
			"a glider per hero on the nest (P2 stands on one and takes it)")
	_step_until(func() -> bool: return roc.get_state() == Roc.State.CRUISE, 400)
	_glide_onto(_hero, roc)
	Sim.step(1)
	_hero.glide = 0
	assert_eq(roc.get_state(), Roc.State.TUMBLE)
	assert_eq(roc.hp, roc.get_storm_hp(), "the dive waits for the spotter")
	var tail: Rect2i = roc.get_head_rect()
	assert_true(tail.size.x > 0, "the tail feathers are open")
	assert_true(tail.end.y >= NEST_TOP - 15, "low enough for a strike from the nest")
	_hero.teleport(Vector2i(tail.get_center().x, NEST_TOP))
	_hero.club_box_active = true
	_hero.club_box = tail
	_hero.club_power = 25
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(roc.hp, roc.get_storm_hp(), "the pilot's own strike does not count")
	_p2.club_box_active = true
	_p2.club_box = tail
	_p2.club_power = 25
	Sim.step(1)
	_p2.club_box_active = false
	assert_true(roc.hp < roc.get_storm_hp(), "the spotter's strike makes the dive count")
	assert_eq(roc.dive_count, 1)
	_step_until(func() -> bool: return roc.get_state() == Roc.State.CRUISE, 600)
	_glide_onto(_hero, roc)
	Sim.step(Roc.TUMBLE_TICKS + 2)
	_hero.glide = 0
	assert_eq(roc.dive_count, 1, "a dive nobody spotted within 24 ticks is lost")


## V3.d: one hero cannot beat the co-op Roc. The real hero, his partner an egg, with every weapon from every spot of the
## nest and the floor plus seeded random inputs, never hurts the perched Roc (the wing shield always faces him); and in
## the storm his own dives never count without a spotter (Pilot and Spotter).
func test_the_single_hero_search_cannot_beat_the_coop_roc() -> void:
	var roc: Roc = _coop_room()
	var hero: PlayerBase = _real_hero(Vector2i(200, NEST_TOP))
	_p2 = _add_hero2(Vector2i(30, 160))
	_p2.down = true
	roc.start_fight()
	assert_true(roc.is_coop_form())
	var rng: SimRng = SimRng.new(77)
	for weapon: int in [Defs.Weapon.CLUB, Defs.Weapon.HAMMER, Defs.Weapon.AXE, Defs.Weapon.BOOMERANG, Defs.Weapon.SPEAR]:
		for x: int in [100, 150, 170, 200, 215, 40, 280]:
			roc._perch(0 if x >= 150 else 1)
			var y: int = NEST_TOP if x >= NEST_X0 and x < NEST_X1 else 160
			_episode(hero, weapon, Vector2i(x, y), _random_flags(rng, 120))
			assert_eq(roc.hp, roc.max_hp, "perched: weapon %d from x %d never counts" % [weapon, x])
	roc.hp = roc.get_storm_hp()
	roc._begin_storm()
	hero.set_glider(true)
	for dive: int in 3:
		_step_until(func() -> bool: return roc.get_state() == Roc.State.CRUISE, 600)
		_glide_onto(hero, roc)
		var strikes: PackedInt32Array = _random_flags(rng, Roc.TUMBLE_TICKS + 4)
		strikes[1] = Defs.IN_FIRE
		_episode(hero, Defs.Weapon.CLUB, hero.sim_pos, strikes, false)
	assert_eq(roc.hp, roc.get_storm_hp(), "his own dives never count alone")
	assert_false(roc.dead)


# =================================================================================================================
# Helpers
# =================================================================================================================

func roc_right() -> int:
	return NEST_X0 + 52 - 16 + 62


## The room of the header (P1 at (30, 160)); returns nothing.
func _room() -> void:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 12:
		var line: String = "|" + ".".repeat(18) + "|"
		if row == 5:
			line = "|.---..........---.|"
		elif row == 8:
			line = "|.....--------.....|"
		elif row >= 10:
			line = "#".repeat(20)
		rows.append(line)
	_rows_level(rows)
	_hero.teleport(Vector2i(30, 160))
	_level.view = Rect2i(0, 0, Tuning.VIEW_W, Tuning.VIEW_H)


func _roc() -> Roc:
	_room()
	return _enemy(&"bosses/roc", Vector2i(9 * Tuning.TILE + 8, NEST_TOP)) as Roc


func _fight() -> Roc:
	var roc: Roc = _roc()
	roc.start_fight()
	Sim.step(1)
	return roc


func _coop_room() -> Roc:
	Game.start_run(Game.difficulty, Defs.GameMode.COOP, 2)
	Game.begin_level(&"test")
	Sim.rng.reseed(1)
	var roc: Roc = _roc()
	_level.meta["kind"] = "coop"
	return roc


func _coop_fight(p1: Vector2i, p2: Vector2i) -> Roc:
	var difficulty: int = Game.difficulty
	Game.start_run(difficulty, Defs.GameMode.COOP, 2)
	Game.begin_level(&"test")
	Sim.rng.reseed(1)
	var roc: Roc = _roc()
	_level.meta["kind"] = "coop"
	_hero.teleport(p1)
	_p2 = _add_hero2(p2)
	roc.start_fight()
	Sim.step(1)
	return roc


func _add_hero2(pos: Vector2i) -> PlayerBase:
	var p2: PlayerBase = PlayerBase.new()
	place(_level, p2, pos, {"slot": 1})
	p2.respawn_at(pos)
	return p2


func _real_hero(pos: Vector2i) -> PlayerBase:
	if _hero != null and is_instance_valid(_hero):
		_hero.free()
	var hero: PlayerBase = (load(PLAYER_SCENE) as PackedScene).instantiate() as PlayerBase
	place(_level, hero, pos, {"slot": 0})
	hero.respawn_at(pos)
	_hero = hero
	return hero


func _at(pos: Vector2i) -> PlayerBase:
	_hero.teleport(pos)
	_hero.yvel = 0
	return _hero


## The high-front club box of a hero standing at `feet` facing `facing` (PHYSICS.md 8.2).
func _high_box(feet: Vector2i, facing: int) -> Rect2i:
	var rect: Rect2i = Tuning.CLUB_BOX[Tuning.ClubFrame.HIGH_FRONT]
	var origin: Vector2i = Tuning.CLUB_ORIGIN[Tuning.ClubFrame.HIGH_FRONT]
	var xo: int = origin.x - rect.position.x
	var ox: int = feet.x + facing * origin.x
	return Rect2i(ox - xo, feet.y + rect.position.y, rect.size.x, rect.size.y)


## A gliding hero coming down onto the Roc's back (yvel 64: a dive).
func _glide_onto(hero: PlayerBase, roc: Roc) -> void:
	hero.teleport(Vector2i(roc.sim_pos.x, roc.sim_pos.y - 44 + 6))
	hero.glide = 1
	hero.yvel = 64
	hero.hit_timer = 0


func _gliders() -> int:
	var count: int = 0
	for item: SimEntity in _of_scene(Defs.Kind.COLLECTIBLE, &"items/glider"):
		if not (item as CollectibleBase).collected:
			count += 1
	return count


func _throw_at(target: Rect2i, power: int) -> void:
	var axe: ProjectileBase = ProjectileBase.new()
	place(_level, axe, Vector2i(target.get_center().x, target.end.y), {"from_hero": true, "power": power})


func _shot(pos: Vector2i, p_xvel: int, owner: int) -> ProjectileBase:
	var shot: ProjectileBase = ProjectileBase.new()
	place(_level, shot, pos, {"from_hero": true, "power": 25, "xvel": p_xvel, "owner": owner, "life": 1})
	return shot


func _step_until(done: Callable, max_ticks: int) -> int:
	for tick: int in max_ticks:
		Sim.step(1)
		for hero: PlayerBase in [_hero, _p2]:
			if hero != null and is_instance_valid(hero) and not hero.is_down():
				hero.run.hearts = Tuning.ENERGY_START
		if done.call():
			return tick + 1
	return -1


func _random_flags(rng: SimRng, ticks: int) -> PackedInt32Array:
	var flags: PackedInt32Array = PackedInt32Array()
	var keys: Array[int] = [0, Defs.IN_LEFT, Defs.IN_RIGHT, Defs.IN_UP, Defs.IN_FIRE, Defs.IN_UP | Defs.IN_FIRE,
			Defs.IN_FIRE | Defs.IN_LEFT, Defs.IN_FIRE | Defs.IN_RIGHT, Defs.IN_UP | Defs.IN_LEFT,
			Defs.IN_UP | Defs.IN_RIGHT, Defs.IN_DOWN | Defs.IN_FIRE]
	var held: int = 0
	var left: int = 0
	for tick: int in ticks:
		if left <= 0:
			held = keys[rng.next_int(keys.size())]
			left = rng.range_int(2, 12)
		left -= 1
		flags.append(held)
	return flags


## One episode of the single-hero search: the real hero (respawned at `pos` unless `respawn` is false) with `weapon`
## plays `flags`, kept alive; the Roc perched episodes hold it on the nest (its phase-1 clock reset).
func _episode(hero: PlayerBase, weapon: int, pos: Vector2i, flags: PackedInt32Array, respawn: bool = true) -> void:
	if respawn:
		hero.respawn_at(pos)
	hero.run.set_weapon(weapon)
	var first: int = Sim.tick + 1
	GameInput.set_scripted_slot(0, func(tick: int) -> int:
		var index: int = tick - first
		return flags[index] if index >= 0 and index < flags.size() else 0
	)
	for tick: int in flags.size():
		Sim.step(1)
		hero.run.hearts = Tuning.ENERGY_START
		hero.hit_timer = mini(hero.hit_timer, 1)
		if hero.dead or hero.is_down():
			hero.respawn_at(pos)
	GameInput.clear_scripted()


func _on_defeated(boss: BossBase) -> void:
	_defeated.append(boss)

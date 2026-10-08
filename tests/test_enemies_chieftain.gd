extends "res://tests/test_enemies_case.gd"
## The Rival Chieftains (scripts/bosses/chieftain.gd; DESIGN.md B.6, GAMEPLAY.md 13.6; PLAN.md P2.3, owner enemies-C):
## the pair and its lead, the solo tag team, the "HUP!" telegraph, one pip per hit, P1 raids, the P2 bat (solo: the
## waiting chief comes down to bat the fighter; co-op: the stack, then the bat), the P3 roast run, the eggs (solo 132,
## co-op 66, the mate's hatch), the win; the co-op hold-off rule and the single-hero search; and the hero-physics
## executor driven by core-B's HeroBot (behind Chieftain.hero_bot_enabled); the idle-partner rule (G33: an idle hatched
## partner holds nobody off, and the single-hero searches place one anywhere); the bodies clear of the HUD on the test
## level (G35) and the recorded club routes there.
##
## The pyre (as levels/test_enemies_chieftain.lvl): 20 x 12 cells, walls at columns 0 and 19, a rock crown in rows 0-4
## (ceiling underside y 80), the floor at row 11 (feet y 176), the altar (one-way) at columns 9-10 of row 8 (top y 128:
## 3 rows up, level with the side ledges - the lead designer's G35 ruling), ledges at row 8. Gorm's record stands on the
## floor at column 6 (x 104), Gulla's on the altar (x 152, y 128).

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const FLOOR_Y: int = 176
const ALTAR_Y: int = 128
## The developer level with its baked bot graph (resources/bots/test_enemies_chieftain.json): the chieftains fight on
## hero physics there, played in the real level scene by the Lab of tests/test_enemies_tusker.gd.
const LEVEL_PATH: String = "res://levels/test_enemies_chieftain.lvl"
const Lab = preload("res://tests/test_enemies_tusker.gd").Lab

var _p2: PlayerBase = null
## The idle-partner searches: P2 (hatched, idle) is kept at the side of the chieftain nobody smashes (_keep_alive).
var _shadow: bool = false
var _gorm: Chieftain = null
var _gulla: Chieftain = null
var _defeated: Array[BossBase] = []
## The pyre's bot graph as JSON text, baked once for the whole file (a bake simulates thousands of hero runs).
static var _pyre_graph_json: String = ""
var _lab: Lab = null
var _was_manual: bool = false


func before_each() -> void:
	super.before_each()
	_defeated.clear()
	_p2 = null
	_shadow = false
	_lab = null
	_was_manual = Sim.manual
	Events.boss_defeated.connect(_on_defeated)
	NavGraph.clear_cache()


func after_each() -> void:
	Events.boss_defeated.disconnect(_on_defeated)
	Chieftain.hero_bot_enabled = true
	GameInput.clear_scripted()
	if _lab != null:
		if _lab.level != null and is_instance_valid(_lab.level):
			_lab.level.free()
		Sim.stop()
		Sim.manual = _was_manual
		Audio.stop_music(0.0)
		Lab.cleanup_flow(get_tree())
		_lab = null
	GameInput.reset_slots()
	NavGraph.clear_cache()
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"")


# =================================================================================================================
# The pair, the solo tag team, the telegraph, the hits
# =================================================================================================================

func test_the_pair_leads_and_tags_in_one_at_a_time_solo() -> void:
	_pyre(false)
	_start()
	assert_true(_gorm.is_lead(), "Gorm's name sorts first: he leads")
	assert_false(_gulla.is_lead())
	assert_eq(_gorm.mate, _gulla)
	assert_eq(_gulla.mate, _gorm)
	assert_false(_gorm.is_coop_form())
	assert_eq(_gorm.life, Chieftain.Life.FIGHT, "solo: Gorm fights ...")
	assert_eq(_gulla.life, Chieftain.Life.WAIT, "... and Gulla waits on the pyre")
	assert_eq(_gorm.get_pips_left(), 4)
	assert_eq(_gorm.get_max_pips(), 4, "4 pips each")
	assert_eq(_gorm.altar, Vector2i(160, ALTAR_Y), "the altar: the first floor under the middle")
	assert_eq(_gulla.get_weak_rect(), Rect2i(), "the waiting chief is out of reach")
	assert_eq(_level.get_kind(Defs.Kind.BOSS).size(), 2)


func test_a_raid_is_announced_by_hup_and_a_14_tick_crouch() -> void:
	_pyre(false)
	_hero.teleport(Vector2i(170, FLOOR_Y))
	_start()
	var announced: int = _step_until(func() -> bool: return _gorm.is_telegraphing(), 200)
	assert_true(announced > 0, "Gorm comes and announces a strike")
	assert_true(_gorm._hup.visible, "the HUP! pop-up")
	var crouch: int = 0
	var hurt_at: int = -1
	for tick: int in 40:
		if _gorm.is_telegraphing():
			crouch += 1
			assert_eq(_gorm.get_attack_box(), Rect2i(), "nothing reaches the hero while he crouches")
		Sim.step(1)
		if hurt_at < 0 and _hero.hit_timer > 0:
			hurt_at = tick
			break
	assert_eq(crouch, Chieftain.TELEGRAPH_TICKS, "a 14-tick crouch")
	assert_true(hurt_at >= Chieftain.TELEGRAPH_TICKS, "then the strike hurts the hero")
	assert_eq(Game.bones, Tuning.BONES_PER_HEART - 1, "a boss body hit: one bone")


func test_one_pip_per_hit_with_a_cooldown_and_a_head_bounce_is_harmless() -> void:
	_pyre(false)
	_start()
	_club(_gorm.get_weak_rect())
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(_gorm.get_pips_left(), 3, "one pip per hit, whatever the weapon")
	_club(_gorm.get_weak_rect())
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(_gorm.get_pips_left(), 3, "hit cooldown per chieftain")
	_hero.teleport(Vector2i(_gorm.sim_pos.x, _gorm.sim_pos.y - Tuning.HERO_BOX_STAND.y + 4))
	_hero.yvel = 64
	Sim.step(1)
	assert_eq(_hero.yvel, Tuning.BOSS_BOUNCE_YVEL, "landing on a chieftain bounces")
	assert_eq(Game.bones, 0, "and harms nobody")
	assert_eq(_gorm.get_pips_left(), 3)


# =================================================================================================================
# P2, P3, eggs and the win (solo)
# =================================================================================================================

func test_solo_p2_the_waiting_chief_comes_down_to_bat_the_fighter() -> void:
	_pyre(false)
	_hero.teleport(Vector2i(280, FLOOR_Y))
	_start()
	_gorm.hp = 2
	_gorm._set_routine(Chieftain.Routine.RAID)
	_gorm._routine_timer = Chieftain.SOLO_RAID_TICKS
	var curled: int = _step_until(func() -> bool: return _gorm.get_act() == Chieftain.Act.CURLED, 120)
	assert_true(curled > 0, "at 2 pips Gorm curls up ...")
	var batted: int = _step_until(func() -> bool: return _gorm.get_act() == Chieftain.Act.BALL, 400)
	assert_true(batted > 0, "... Gulla comes down from the pyre and bats him at the hero")
	assert_true(_gorm.xvel > 0, "toward the hero")
	var dazed: int = _step_until(func() -> bool: return _gorm.get_act() == Chieftain.Act.DAZED, 80)
	assert_true(dazed > 0, "where he lands he lies dazed")
	_club(_gorm.get_weak_rect())
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(_gorm.get_pips_left(), 1, "the dazed chieftain is the solo opening")
	var back: int = _step_until(func() -> bool: return _gulla.sim_pos == _gulla._post, 300)
	assert_true(back > 0, "Gulla climbs back onto the pyre")


func test_p3_the_last_pip_runs_the_roast_to_the_perch() -> void:
	_pyre(false)
	_hero.teleport(Vector2i(250, FLOOR_Y))
	_start()
	_gorm.hp = 1
	var took: int = _step_until(func() -> bool: return _gorm.carries_roast(), 300)
	assert_true(took > 0, "he fetches the Great Roast from the altar")
	assert_true(_gorm.perch.x <= 40, "and runs for the perch farther from the hero (the left floor edge: x %d)" % _gorm.perch.x)
	_club(_gorm.get_weak_rect())
	Sim.step(1)
	_hero.club_box_active = false
	assert_false(_gorm.carries_roast(), "a hit makes him drop it (it goes back to the altar)")
	assert_true(_gorm.dead or _gorm.life != Chieftain.Life.FIGHT, "that was his last pip")
	_level.reset_entities()
	_start()
	_gorm.hp = 1
	_step_until(func() -> bool: return _gorm.carries_roast(), 300)
	assert_eq(_gorm.get_attack_box(), Rect2i())
	var home: int = _step_until(func() -> bool:
		return not _gorm.carries_roast(), 400)
	assert_true(home > 0, "he reaches the perch")
	assert_eq(_gorm.get_pips_left(), 2, "the roast returns to the altar and he regains a pip")


func test_solo_egg_tag_in_smash_and_the_win() -> void:
	_pyre(false)
	_hero.teleport(Vector2i(60, FLOOR_Y))
	_start()
	_gorm.hp = 1
	_gorm.hit_cooldown = 0
	_club(_gorm.get_weak_rect())
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(_gorm.life, Chieftain.Life.EGG, "knocked to 0: an egg")
	assert_eq(_gulla.life, Chieftain.Life.FIGHT, "Gulla tags in ...")
	assert_eq(_gulla.get_pips_left(), 2, "... with half energy")
	for hit: int in Chieftain.EGG_SMASH_HITS:
		_club(_gorm.get_weak_rect())
		Sim.step(1)
		_hero.club_box_active = false
		Sim.step(Chieftain.EGG_HIT_GAP_TICKS)
	assert_eq(_gorm.life, Chieftain.Life.OUT, "3 hits smash the egg: Gorm is out")
	assert_true(_defeated.is_empty(), "Gulla still fights")
	_gulla.hp = 1
	_gulla.hit_cooldown = 0
	_club(_gulla.get_weak_rect())
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(_gulla.life, Chieftain.Life.OUT, "at 0 with no mate left: out at once")
	assert_eq(_defeated.size(), 2, "both defeated")
	assert_true(_gorm.dead and _gulla.dead)
	if Spawner.exists(&"items/trophy"):
		assert_eq(_of_scene(Defs.Kind.COLLECTIBLE, &"items/trophy").size(), 1, "one trophy: the Great Roast")


func test_solo_an_unsmashed_egg_hatches_after_132_ticks_onto_the_pyre() -> void:
	_pyre(false)
	_hero.teleport(Vector2i(280, FLOOR_Y))
	_start()
	_gorm.hp = 1
	_club(_gorm.get_weak_rect())
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(_gorm.life, Chieftain.Life.EGG)
	Sim.step(Chieftain.EGG_TICKS_SOLO - 1)
	_keep_alive()
	assert_eq(_gorm.life, Chieftain.Life.EGG, "132 ticks ...")
	Sim.step(1)
	assert_eq(_gorm.life, Chieftain.Life.WAIT, "... then he hatches and waits on the pyre")
	assert_eq(_gorm.get_pips_left(), 1, "with 1 pip")


# =================================================================================================================
# Co-op
# =================================================================================================================

func test_coop_both_fight_and_the_mate_runs_to_hatch_the_egg() -> void:
	_pyre(true)
	_start()
	assert_true(_gorm.is_coop_form())
	assert_eq(_gulla.life, Chieftain.Life.FIGHT, "co-op: both fight at once")
	_gulla.teleport(Vector2i(200, FLOOR_Y))
	_gorm.teleport(Vector2i(120, FLOOR_Y))
	_gorm.hp = 1
	_club(_gorm.get_weak_rect())
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(_gorm.life, Chieftain.Life.EGG)
	Sim.step(1)
	assert_eq(_gulla.order_kind, Chieftain.Order.HATCH, "Gulla runs to hatch it")
	var hatched: int = _step_until(func() -> bool: return _gorm.life == Chieftain.Life.FIGHT, 70)
	assert_true(hatched > 0 and hatched < Chieftain.EGG_TICKS_COOP, "his head bounce hatches it (tick %d)" % hatched)
	assert_eq(_gorm.get_pips_left(), 1)


func test_coop_an_egg_hatches_by_itself_after_66_ticks() -> void:
	_pyre(true)
	_start()
	_gulla.hp = 1
	_gorm.hp = 1
	_club(_gorm.get_weak_rect())
	_club_by(_p2, _gulla.get_weak_rect())
	Sim.step(1)
	_hero.club_box_active = false
	_p2.club_box_active = false
	assert_eq([_gorm.life, _gulla.life], [Chieftain.Life.EGG, Chieftain.Life.EGG], "both eggs at once")
	Sim.step(Chieftain.EGG_TICKS_COOP)
	_keep_alive()
	assert_eq([_gorm.life, _gulla.life], [Chieftain.Life.FIGHT, Chieftain.Life.FIGHT], "66 ticks: both hatch")


func test_coop_an_egg_cracks_only_while_the_partner_holds_the_mate_off() -> void:
	_pyre(true)
	_start()
	_gorm.teleport(Vector2i(80, FLOOR_Y))
	_gulla.teleport(Vector2i(260, FLOOR_Y))
	_hero.teleport(Vector2i(60, FLOOR_Y))
	_p2.teleport(Vector2i(160, FLOOR_Y))
	_gorm.hp = 1
	_club(_gorm.get_weak_rect())
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(_gorm.life, Chieftain.Life.EGG)
	_club(_gorm.get_weak_rect())
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(_gorm._egg_hits, 0, "P2 is far from Gulla: P1's blow glances off the egg")
	Sim.step(Chieftain.EGG_HIT_GAP_TICKS)
	_p2.teleport(Vector2i(_gulla.sim_pos.x - 30, FLOOR_Y))
	_p2.idle = true
	_club(_gorm.get_weak_rect())
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(_gorm._egg_hits, 0, "G33: P2 dozes next to Gulla - an idle partner holds nobody off")
	Sim.step(Chieftain.EGG_HIT_GAP_TICKS)
	_p2.idle = false
	_p2.teleport(Vector2i(_gulla.sim_pos.x - 30, FLOOR_Y))
	_club(_gorm.get_weak_rect())
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(_gorm._egg_hits, 1, "P2 keeps Gulla busy: the blow cracks it")


func test_coop_totem_stack_then_the_bat() -> void:
	_pyre(true)
	_hero.teleport(Vector2i(280, FLOOR_Y))
	_p2.teleport(Vector2i(250, FLOOR_Y))
	_start()
	_gulla.teleport(Vector2i(130, FLOOR_Y))
	_gorm.hp = 2
	_gulla.hp = 2
	var stacked: int = _step_until(func() -> bool:
		return absi(_gulla.sim_pos.x - _gorm.sim_pos.x) <= 2 and _gulla.sim_pos.y == _gorm.sim_pos.y - 34, 200)
	assert_true(stacked > 0, "both at 2 pips: they stack (one on the other's head)")
	var batted: int = _step_until(func() -> bool:
		return _gorm.get_act() == Chieftain.Act.BALL or _gulla.get_act() == Chieftain.Act.BALL, 400)
	assert_true(batted > 0, "then the top curls and the bottom bats him across the arena")


## V3.d: one hero cannot beat the co-op pair. With his partner an egg, P1 (bare) knocks one chieftain into an egg and
## strikes it on every tick it could count, then knocks the other too: no egg ever cracks, both hatch, nobody is out.
## The real hero with seeded random play and every weapon for a while: still nobody out.
func test_the_single_hero_search_cannot_beat_the_coop_chieftains() -> void:
	_pyre(true)
	_p2.down = true
	_start()
	assert_true(_gorm.is_coop_form(), "the egg partner still makes it a co-op party")
	_gorm.hp = 1
	_club(_gorm.get_weak_rect())
	Sim.step(1)
	_hero.club_box_active = false
	for tick: int in Chieftain.EGG_TICKS_COOP - 2:
		if _gorm.life == Chieftain.Life.EGG:
			_hero.teleport(Vector2i(_gorm.sim_pos.x - 20, FLOOR_Y))
			_club(_gorm.get_weak_rect())
		Sim.step(1)
		_hero.club_box_active = false
		_keep_alive()
	assert_ne(_gorm.life, Chieftain.Life.OUT, "alone he cannot crack the egg")
	assert_eq(_gorm._egg_hits, 0)
	var real: PlayerBase = _real_p1(Vector2i(60, FLOOR_Y))
	var rng: SimRng = SimRng.new(21)
	for weapon: int in [Defs.Weapon.CLUB, Defs.Weapon.AXE, Defs.Weapon.SPEAR]:
		_gorm.hp = 1
		_gulla.hp = 1
		_episode(real, weapon, Vector2i(rng.range_int(40, 280), FLOOR_Y), _random_flags(rng, 260))
	assert_ne(_gorm.life, Chieftain.Life.OUT, "nobody out")
	assert_ne(_gulla.life, Chieftain.Life.OUT)
	assert_true(_defeated.is_empty())


## V3.d with the idle partner (G33 / G34): P2 hatched and IDLE, kept at whichever chieftain is not being smashed (more
## than any real placement: a dozing hero never follows anyone). P1 (bare) strikes an egg on every tick it could count,
## then the real P1 plays seeded random inputs with every weapon on both executors: no egg ever cracks, nobody is out.
func test_the_single_hero_search_with_an_idle_partner_cannot_beat_the_coop_chieftains() -> void:
	for bot: bool in [false, true]:
		if bot:
			_bot_pyre(true)
		else:
			_pyre(true)
		_start()
		_p2.idle = true
		_shadow = true
		assert_true(_gorm.is_coop_form())
		assert_eq(_gorm.get_body() != null, bot, "executor: hero physics %s" % bot)
		_gorm.hp = 1
		_club(_gorm.get_weak_rect())
		Sim.step(1)
		_hero.club_box_active = false
		for tick: int in Chieftain.EGG_TICKS_COOP - 2:
			if _gorm.life == Chieftain.Life.EGG:
				_hero.teleport(Vector2i(_gorm.sim_pos.x - 20, FLOOR_Y))
				_club(_gorm.get_weak_rect())
			Sim.step(1)
			_hero.club_box_active = false
			_keep_alive()
		assert_eq(_gorm._egg_hits, 0, "bot %s: the dozing partner at Gulla's side holds nobody off" % bot)
		var real: PlayerBase = _real_p1(Vector2i(60, FLOOR_Y))
		var rng: SimRng = SimRng.new(55)
		for weapon: int in [Defs.Weapon.CLUB, Defs.Weapon.AXE, Defs.Weapon.SPEAR]:
			for chief: Chieftain in [_gorm, _gulla]:
				if chief.life == Chieftain.Life.FIGHT:
					chief.hp = 1
			_episode(real, weapon, Vector2i(rng.range_int(40, 280), FLOOR_Y), _random_flags(rng, 260))
		assert_ne(_gorm.life, Chieftain.Life.OUT, "bot %s: nobody out" % bot)
		assert_ne(_gulla.life, Chieftain.Life.OUT)
		assert_true(_defeated.is_empty())
		_shadow = false
		GameInput.clear_scripted()
		GameInput.reset_slots()


# =================================================================================================================
# The hero-physics executor (HeroBot)
# =================================================================================================================

## The default: each chieftain drives a hero body (scenes/player/player.tscn, not one of the level's heroes) from its
## HeroBot's GameInput slot; the body moves on the hero's own physics (at most the hero's 5 px per tick, the jump
## table), the shell mirrors it, and the brain's telegraph shows the HUP!. Without a bot graph for the level the state
## machine plays instead (PLAN cut 8 behind Chieftain.hero_bot_enabled).
func test_hero_bot_bodies_move_on_hero_physics() -> void:
	assert_true(Chieftain.hero_bot_enabled, "hero physics is the default executor")
	_pyre(false)
	_start()
	assert_null(_gorm.get_body(), "no bot graph for the level: the state machine plays")
	_bot_pyre(false)
	_hero.teleport(Vector2i(250, FLOOR_Y))
	_start()
	var body: PlayerBase = _gorm.get_body()
	assert_not_null(body, "Gorm drives a hero body")
	if body == null:
		return
	assert_true(body is Player, "the real hero simulation")
	assert_false(_level.heroes.has(body), "not one of the level's heroes")
	assert_eq(_level.hero_count(), 1)
	assert_eq(GameInput.get_slot(2).kind, Defs.InputSlotKind.BOT, "fed by a HeroBot through GameInput slot 2")
	assert_not_null(_gulla.get_body(), "Gulla too (slot 3), waiting on the pyre")
	var fastest: int = 0
	var telegraphed: bool = false
	var last: Vector2i = _gorm.sim_pos
	for tick: int in 400:
		Sim.step(1)
		_keep_alive()
		fastest = maxi(fastest, absi(_gorm.sim_pos.x - last.x))
		last = _gorm.sim_pos
		assert_eq(_gorm.sim_pos, body.sim_pos, "the shell mirrors the body")
		telegraphed = telegraphed or _gorm.is_telegraphing()
		if _hero.hit_timer > 0 and telegraphed:
			break
	assert_true(fastest <= Tuning.WALK_CAP / 16 + 1, "never faster than the hero walks (%d px/tick)" % fastest)
	assert_true(absi(_gorm.sim_pos.x - 104) > 16, "it went for the hero")
	assert_true(telegraphed, "its attacks are announced (the brain's 14-tick crouch)")
	assert_eq(_gulla.sim_pos, Vector2i(152, ALTAR_Y), "the waiting chief stays on the pyre")


## Every attack on hero physics: the HUP! and the body's 14-tick crouch, nothing reaches the hero meanwhile, then the
## club costs him a bone (a boss body hit).
func test_hero_bot_a_raid_is_announced_by_hup_and_a_14_tick_crouch() -> void:
	_bot_pyre(false)
	_hero.teleport(Vector2i(170, FLOOR_Y))
	_start()
	var announced: int = _step_until(func() -> bool: return _gorm.is_telegraphing(), 300)
	assert_true(announced > 0, "Gorm comes and announces an attack")
	assert_true(_gorm._hup.visible, "the HUP! pop-up")
	var crouch: int = 0
	var hurt_at: int = -1
	for tick: int in 60:
		if _gorm.is_telegraphing():
			crouch += 1
			assert_eq(_gorm.get_attack_box(), Rect2i(), "nothing reaches the hero while he crouches")
		Sim.step(1)
		if _hero.hit_timer > 0:
			hurt_at = tick
			break
	assert_true(crouch >= Chieftain.TELEGRAPH_TICKS - 1, "a 14-tick crouch (%d)" % crouch)
	assert_true(hurt_at >= Chieftain.TELEGRAPH_TICKS - 1, "then the attack hurts the hero (tick %d)" % hurt_at)
	assert_eq(Game.bones, Tuning.BONES_PER_HEART - 1, "a boss body hit: one bone")


## Co-op on hero physics, both at 2 pips: the stack (the top's body rides the bottom's head while he walks), then the
## top curls, the bottom bats him across the arena (a line drive) and he lies dazed DAZE_TICKS where he lands.
func test_hero_bot_coop_stack_then_bat_and_daze() -> void:
	_bot_pyre(true)
	_hero.teleport(Vector2i(200, FLOOR_Y))
	_p2.teleport(Vector2i(186, FLOOR_Y))
	_start()
	_gulla._place(Vector2i(130, FLOOR_Y))
	_gorm.hp = 2
	_gulla.hp = 2
	var stacked: int = _step_until(func() -> bool:
		return _gulla.sim_pos == _gorm.sim_pos - Vector2i(0, Chieftain.STACK_HEAD_PX), 300)
	assert_true(stacked > 0, "the top got onto the bottom's head")
	var carried: Vector2i = _gorm.sim_pos
	Sim.step(10)
	_keep_alive()
	if _gorm.order_kind == Chieftain.Order.STACK_BOTTOM and _gulla.order_kind == Chieftain.Order.STACK_TOP:
		assert_eq(_gulla.sim_pos, _gorm.sim_pos - Vector2i(0, Chieftain.STACK_HEAD_PX), "and rides along")
	var batted: int = _step_until(func() -> bool:
		return _gorm.get_act() == Chieftain.Act.BALL or _gulla.get_act() == Chieftain.Act.BALL, 500)
	assert_true(batted > 0, "the top curls and the bottom bats him")
	if batted <= 0:
		return
	var ball: Chieftain = _gorm if _gorm.get_act() == Chieftain.Act.BALL else _gulla
	var start_x: int = ball.sim_pos.x
	var landed: int = _step_until(func() -> bool:
		return ball.get_act() == Chieftain.Act.DAZED, 80)
	assert_true(landed > 0, "the ball lands: dazed")
	assert_true(absi(ball.sim_pos.x - start_x) >= 48, "batted across the arena (%d px)" % absi(ball.sim_pos.x - start_x))
	var lying: Vector2i = ball.sim_pos
	Sim.step(Chieftain.DAZE_TICKS - 2)
	_keep_alive()
	assert_eq(ball.get_act(), Chieftain.Act.DAZED, "dazed 30 ticks ...")
	assert_eq(ball.sim_pos, lying, "... where he landed")
	Sim.step(3)
	assert_ne(ball.get_act(), Chieftain.Act.DAZED, "then he gets up")


## Co-op egg revive on hero physics: the mate's body jumps onto the egg and his landing hatches it before the egg
## would hatch by itself.
func test_hero_bot_coop_the_mate_jumps_on_the_egg_to_hatch_it() -> void:
	_bot_pyre(true)
	_hero.teleport(Vector2i(40, FLOOR_Y))
	_p2.teleport(Vector2i(290, FLOOR_Y))
	_start()
	_gorm._place(Vector2i(120, FLOOR_Y))
	_gulla._place(Vector2i(200, FLOOR_Y))
	_gorm.hp = 1
	_club(_gorm.get_weak_rect())
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(_gorm.life, Chieftain.Life.EGG)
	var hatched: int = _step_until(func() -> bool: return _gorm.life == Chieftain.Life.FIGHT, 70)
	assert_true(hatched > 0 and hatched < Chieftain.EGG_TICKS_COOP - 1,
			"Gulla's head bounce hatches it (tick %d)" % hatched)
	assert_eq(_gorm.get_pips_left(), 1)
	assert_true(_gorm.get_body().control_enabled, "his body moves again")


## P3 on hero physics: with his last pip Gorm climbs to the altar (the bot graph: ledges, then the altar), takes the
## roast, runs for the perch at the floor edge and regains a pip there.
func test_hero_bot_p3_the_roast_run_climbs_to_the_altar() -> void:
	_bot_pyre(false)
	_hero.teleport(Vector2i(250, FLOOR_Y))
	_start()
	_gorm.hp = 1
	var took: int = _step_until(func() -> bool: return _gorm.carries_roast(), 600)
	assert_true(took > 0, "he climbed to the altar and took the roast (at %s)" % _gorm.sim_pos)
	assert_eq(_gorm.get_attack_box(), Rect2i(), "no strike while carrying")
	var home: int = _step_until(func() -> bool: return not _gorm.carries_roast(), 600)
	assert_true(home > 0, "he reaches the perch (at %s, perch %s)" % [_gorm.sim_pos, _gorm.perch])
	assert_eq(_gorm.get_pips_left(), 2, "and regains a pip")


## Solo P2 on hero physics: the waiting chief comes down from the pyre, bats the curled fighter at the hero, and
## climbs back onto the pyre.
func test_hero_bot_solo_p2_the_waiting_chief_bats_and_climbs_back() -> void:
	_bot_pyre(false)
	_hero.teleport(Vector2i(280, FLOOR_Y))
	_start()
	_gorm.hp = 2
	_gorm._set_routine(Chieftain.Routine.RAID)
	_gorm._routine_timer = Chieftain.SOLO_RAID_TICKS
	var batted: int = _step_until(func() -> bool: return _gorm.get_act() == Chieftain.Act.BALL, 600)
	assert_true(batted > 0, "Gulla came down and batted Gorm (Gulla at %s)" % _gulla.sim_pos)
	var dazed: int = _step_until(func() -> bool: return _gorm.get_act() == Chieftain.Act.DAZED, 80)
	assert_true(dazed > 0, "he lies dazed")
	var back: int = _step_until(func() -> bool:
		return absi(_gulla.sim_pos.x - 152) <= ChieftainBrain.ARRIVE_PX and _gulla.sim_pos.y == ALTAR_Y, 600)
	assert_true(back > 0, "Gulla climbs back onto the pyre (at %s)" % _gulla.sim_pos)


## The whole fight ends on hero physics: a bare hero who keeps hitting whichever chieftain is in play wins.
func test_hero_bot_fight_can_be_won() -> void:
	_bot_pyre(false)
	_hero.teleport(Vector2i(250, FLOOR_Y))
	_start()
	for tick: int in 4000:
		for chief: Chieftain in [_gorm, _gulla]:
			var weak: Rect2i = chief.get_weak_rect()
			if weak.size.x > 0 and chief.hit_cooldown == 0 and chief._egg_gap == 0:
				_club(weak)
		Sim.step(1)
		_hero.club_box_active = false
		_keep_alive()
		if _gorm.dead and _gulla.dead:
			break
	assert_true(_gorm.dead and _gulla.dead, "won (Gorm %s, Gulla %s)" % [_gorm.life, _gulla.life])
	assert_eq(GameInput.get_slot(2).kind, Defs.InputSlotKind.NONE, "the bots gave their slots back")
	assert_eq(GameInput.get_slot(3).kind, Defs.InputSlotKind.NONE)


## V3.d on hero physics: one hero (his partner an egg) with seeded random play and every weapon never puts a co-op
## chieftain out.
func test_hero_bot_the_single_hero_search_cannot_beat_the_coop_chieftains() -> void:
	_bot_pyre(true)
	_p2.down = true
	_start()
	assert_not_null(_gorm.get_body())
	var real: PlayerBase = _real_p1(Vector2i(60, FLOOR_Y))
	var rng: SimRng = SimRng.new(33)
	for weapon: int in [Defs.Weapon.CLUB, Defs.Weapon.AXE, Defs.Weapon.SPEAR]:
		for chief: Chieftain in [_gorm, _gulla]:
			if chief.life == Chieftain.Life.FIGHT:
				chief.hp = 1
		_episode(real, weapon, Vector2i(rng.range_int(40, 280), FLOOR_Y), _random_flags(rng, 260))
	assert_ne(_gorm.life, Chieftain.Life.OUT, "nobody out")
	assert_ne(_gulla.life, Chieftain.Life.OUT)
	assert_true(_defeated.is_empty())


# =================================================================================================================
# The test level: hero physics, the HUD, the recorded club routes
# =================================================================================================================

## G35 (lead designer, wf9 #2 / D9b): on the test level (the altar 3 rows up under a 5-row crown, the camera locked on
## the pyre) the chieftains fight on hero physics (its baked graph), and through a long fight every rectangle a hit
## must touch - a fighting chieftain's body, an egg - lies wholly in the view and clear of the fight HUD
## (Hud.weak_point_problem), wherever the bodies walk, jump, stack or carry the roast.
func test_the_bodies_stay_clear_of_the_hud_on_the_test_level() -> void:
	var chiefs: Array[Chieftain] = _open_pyre_lab(Defs.Difficulty.EXPERT)
	var hero: PlayerBase = _lab.hero()
	_lab.step(PackedInt32Array([0]))
	assert_not_null(chiefs[0].get_body(), "Gorm fights on hero physics here (the level's bot graph)")
	var view: Rect2i = _lab.level.get_view_rect()
	var checked: int = 0
	for tick: int in 1500:
		# The hero roams the floor (kept alive): the chieftains chase him all over the pyre.
		var keys: int = Defs.IN_RIGHT if (tick / 90) % 2 == 0 else Defs.IN_LEFT
		_lab.step(PackedInt32Array([keys | (Defs.IN_UP if tick % 45 == 0 else 0)]))
		Lab.top_up(hero)
		for chief: Chieftain in chiefs:
			var weak: Rect2i = chief.get_weak_rect()
			if not weak.has_area():
				continue
			checked += 1
			assert_true(view.encloses(weak), "tick %d: %s wholly in the view (%s)" % [tick, chief.name, weak])
			var art: Rect2 = Rect2(Vector2(weak.position - view.position) * 2, Vector2(weak.size) * 2)
			var problem: String = Hud.weak_point_problem(art, Vector2(view.size) * 2)
			if problem != "":
				assert_eq(problem, "", "tick %d: %s (%s)" % [tick, chief.name, weak])
				return
	assert_true(checked > 1000, "the weak points were checked (%d)" % checked)


## G2 criterion (PLAN.md 5, enemies-C): the solo Rival Chieftains on hero physics fall to the club on their test
## level, played by the real hero from the level start with no refill - replayed tick for tick from the routes
## [ChiefClubPilot] recorded (CHIEF_ROUTE=1 on test_the_club_pilot_still_wins_on_the_test_level prints fresh ones).
func test_the_club_routes_beat_the_solo_chieftains_on_the_test_level() -> void:
	for case: Array in [[Defs.Difficulty.BEGINNER, ROUTE_BEGINNER], [Defs.Difficulty.EXPERT, ROUTE_EXPERT]]:
		var chiefs: Array[Chieftain] = _open_pyre_lab(int(case[0]))
		var hero: PlayerBase = _lab.hero()
		var lives: int = Game.lives
		var route: PackedInt32Array = Lab.parse_route(str(case[1]))
		var specials: Array[int] = [0]
		var played: int = _lab.play([route] as Array[PackedInt32Array], func() -> bool:
			if hero.run.weapon != Defs.Weapon.CLUB:
				specials[0] += 1
			return (chiefs[0].dead and chiefs[1].dead) or hero.dead)
		print("    chieftains route difficulty %d: won on tick %d of %d, hearts %d bones %d" % [case[0], played,
				route.size(), hero.run.hearts, hero.run.bones])
		assert_true(chiefs[0].dead and chiefs[1].dead, "difficulty %d: the club route beats both (Gorm %s, Gulla %s)" % [
				case[0], chiefs[0].life, chiefs[1].life])
		assert_false(hero.dead, "difficulty %d: without a death" % case[0])
		assert_eq(Game.lives, lives, "no life lost")
		assert_eq(specials[0], 0, "the club in his hand all the way")
		_close_pyre_lab()


## The pilot that recorded those routes still wins from the level start (a guard against drift of the bots or the
## tuning; CHIEF_ROUTE=1 prints the fresh routes).
func test_the_club_pilot_still_wins_on_the_test_level() -> void:
	for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		var chiefs: Array[Chieftain] = _open_pyre_lab(difficulty)
		var hero: PlayerBase = _lab.hero()
		var pilot: ChiefClubPilot = ChiefClubPilot.new()
		var hurts: int = 0
		for tick: int in 9000:
			_lab.step(PackedInt32Array([pilot.flags(hero, chiefs)]))
			if hero.hit_timer == Tuning.HIT_TIMER - 1:
				hurts += 1
			if (chiefs[0].dead and chiefs[1].dead) or hero.dead:
				break
		if OS.has_environment("CHIEF_ROUTE"):
			print("ROUTE %d %s" % [difficulty, Lab.route_text(_lab.streams[0])])
		print("    chieftains pilot difficulty %d: won %s after %d ticks (Gorm %s %d, Gulla %s %d), hurts %d, hearts %d bones %d" % [
				difficulty, chiefs[0].dead and chiefs[1].dead, _lab.ticks(), chiefs[0].life, chiefs[0].hp, chiefs[1].life,
				chiefs[1].hp, hurts, hero.run.hearts, hero.run.bones])
		assert_true(chiefs[0].dead and chiefs[1].dead, "difficulty %d: the club pilot beats the chieftains" % difficulty)
		assert_false(hero.dead)
		_close_pyre_lab()


## The test level in the real level scene (the fixture's own room freed first), one real hero, club in hand; returns
## [Gorm, Gulla].
func _open_pyre_lab(difficulty: int) -> Array[Chieftain]:
	if _level != null and is_instance_valid(_level):
		_level.free()
	_level = null
	_hero = null
	_lab = Lab.new()
	assert_true(_lab.open(self, LEVEL_PATH, "bosses/chieftain", difficulty), "the pyre came up")
	var chiefs: Array[Chieftain] = []
	for entity: SimEntity in _lab.level.get_kind(Defs.Kind.BOSS):
		chiefs.append(entity as Chieftain)
	chiefs.sort_custom(func(a: Chieftain, b: Chieftain) -> bool:
		return String(a.spawn_params.get("name", "")) < String(b.spawn_params.get("name", "")))
	return chiefs


func _close_pyre_lab() -> void:
	if _lab != null and _lab.level != null and is_instance_valid(_lab.level):
		_lab.level.free()
	GameInput.clear_scripted()
	GameInput.reset_slots()
	_lab = null


## The club pilot of the solo Rival Chieftains on the test level (it recorded ROUTE_BEGINNER / ROUTE_EXPERT): it goes
## for an egg first (three blows before it hatches), else for the chieftain in the fight; it takes the floor, the
## ledges or the altar he stands on (a jump where he is higher or a wall blocks), keeps STRIKE_MIN..STRIKE_MAX px in
## front of him, faces him and swings the club whenever the forward box would meet him and a hit may count (his
## cooldown, the egg's gap). Its strikes land first: a counted hit makes the body flinch and drops an announced attack.
class ChiefClubPilot:
	extends RefCounted

	const STRIKE_MIN: int = 14
	const STRIKE_MAX: int = 30
	const JUMP_TICKS: int = 10
	const STRIKE_TICKS: int = 7

	var plan: Array[int] = []
	var _last_x: int = -100000
	var _stuck: int = 0

	func flags(hero: PlayerBase, chiefs: Array[Chieftain]) -> int:
		if not plan.is_empty():
			return plan.pop_front()
		var target: Chieftain = pick(chiefs)
		if target == null or not hero.is_grounded():
			return 0
		var weak: Rect2i = target.get_weak_rect()
		var x: int = hero.sim_pos.x
		var tx: int = target.sim_pos.x
		var dir: int = 1 if tx >= x else -1
		var toward: int = Defs.IN_RIGHT if dir > 0 else Defs.IN_LEFT
		var away: int = Defs.IN_LEFT if dir > 0 else Defs.IN_RIGHT
		var dx: int = absi(tx - x)
		var same_floor: bool = absi(target.sim_pos.y - hero.sim_pos.y) <= 6
		if same_floor and dx >= STRIKE_MIN - 4 and dx <= STRIKE_MAX + 6:
			if hero.facing != dir:
				return toward
			var ready: bool = target.hit_cooldown == 0 if target.life == Chieftain.Life.FIGHT else target._egg_gap == 0
			if ready and Overlap.rects(front_box(hero.sim_pos, dir), weak):
				for i: int in STRIKE_TICKS - 2:
					plan.append(Defs.IN_FIRE)
				plan.append(0)
				return Defs.IN_FIRE
			if dx < STRIKE_MIN:
				return away
			return toward if dx > STRIKE_MAX else 0
		if same_floor and dx < STRIKE_MIN - 4:
			return away
		# Get to him: walk; jump where he stands higher, or where a wall stops the walk.
		var key: int = toward
		if x == _last_x:
			_stuck += 1
		else:
			_stuck = 0
		_last_x = x
		var higher: bool = target.sim_pos.y < hero.sim_pos.y - 6 and dx <= 40
		if higher or _stuck >= 2:
			_stuck = 0
			for i: int in JUMP_TICKS - 1:
				plan.append(Defs.IN_UP | key)
			return Defs.IN_UP | key
		return key

	## The target: an egg first (it hatches by itself), else the fighting chieftain.
	static func pick(chiefs: Array[Chieftain]) -> Chieftain:
		for chief: Chieftain in chiefs:
			if not chief.dead and chief.life == Chieftain.Life.EGG:
				return chief
		for chief: Chieftain in chiefs:
			if not chief.dead and chief.life == Chieftain.Life.FIGHT:
				return chief
		return null

	## The forward strike's front box (frames 5-7 of the script, PHYSICS.md 8.2) of a hero at `feet` facing `facing`.
	static func front_box(feet: Vector2i, facing: int) -> Rect2i:
		var rect: Rect2i = Tuning.CLUB_BOX[Tuning.ClubFrame.FWD_FRONT]
		var origin: Vector2i = Tuning.CLUB_ORIGIN[Tuning.ClubFrame.FWD_FRONT]
		var xo: int = origin.x - rect.position.x
		var ox: int = feet.x + facing * origin.x
		return Rect2i(ox - xo, feet.y + rect.position.y, rect.size.x, rect.size.y)


# =================================================================================================================
# Helpers
# =================================================================================================================

## The pyre of the header with both chieftains (fight not started); `coop`: a co-op game of two on a co-op file.
func _pyre(coop: bool) -> void:
	if coop:
		Game.start_run(Defs.Difficulty.EXPERT, Defs.GameMode.COOP, 2)
		Game.begin_level(&"test")
		Sim.rng.reseed(1)
	_rows_level(_pyre_rows())
	_level.view = Rect2i(0, 0, Tuning.VIEW_W, 192)
	_hero.teleport(Vector2i(40, FLOOR_Y))
	if coop:
		_level.meta["kind"] = "coop"
		_p2 = PlayerBase.new()
		place(_level, _p2, Vector2i(280, FLOOR_Y), {"slot": 1})
		_p2.respawn_at(Vector2i(280, FLOOR_Y))
	_gorm = _enemy(&"bosses/chieftain", Vector2i(104, FLOOR_Y), {"name": "gorm", "mate": "gulla"}) as Chieftain
	_gulla = _enemy(&"bosses/chieftain", Vector2i(152, ALTAR_Y),
			{"name": "gulla", "mate": "gorm", "drops": "trophy"}) as Chieftain


## The pyre's tile rows (the header's room).
static func _pyre_rows() -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	rows.append("#".repeat(20))
	for row: int in range(1, 11):
		var line: String = "#" + ".".repeat(18) + "#"
		if row <= 4:
			line = "#".repeat(20)
		elif row == 8:
			line = "#.---....--...---..#"
		rows.append(line)
	rows.append("#".repeat(20))
	return rows


## The pyre of [method _pyre] with its bot graph (core-B's NavBaker on the same rows, baked once for the file and
## cached under the test level's id), so that the hero-physics executor plays.
func _bot_pyre(coop: bool) -> void:
	if _pyre_graph_json.is_empty():
		var text: String = "[meta]\nformat = 2\nid = test\nkind = test\n[tiles]\n%s\n[entities]\n" \
				% "\n".join(_pyre_rows())
		var baked: NavGraph = NavBaker.new().bake_text(self, &"test", text, Defs.Difficulty.BEGINNER,
				PackedInt32Array([NavGraph.WEIGHT_LIGHT]))
		_pyre_graph_json = baked.to_json()
	var json: JSON = JSON.new()
	json.parse(_pyre_graph_json)
	NavGraph.cache(NavGraph.from_dict(json.data))
	_pyre(coop)


func _start() -> void:
	_gorm.start_fight()
	_gulla.start_fight()
	Sim.step(1)


func _club(box: Rect2i) -> void:
	_club_by(_hero, box)


func _club_by(hero: PlayerBase, box: Rect2i) -> void:
	hero.club_box_active = true
	hero.club_box = box
	hero.club_power = 25


func _keep_alive() -> void:
	for hero: PlayerBase in [_hero, _p2]:
		if hero != null and is_instance_valid(hero) and not hero.is_down():
			hero.run.hearts = Tuning.ENERGY_START
			hero.hit_timer = mini(hero.hit_timer, 1)
	if _shadow and _p2 != null and is_instance_valid(_p2):
		# The search's idle partner: hatched, idle, at the side of the chieftain nobody is smashing (the mate of an egg).
		var keep: Chieftain = _gulla if _gorm.life == Chieftain.Life.EGG else _gorm
		if _p2.dead or _p2.is_down():
			_p2.down = false
			_p2.respawn_at(keep.sim_pos)
		_p2.teleport(Vector2i(keep.sim_pos.x + 12, keep.sim_pos.y))
		_p2.idle = true


func _step_until(done: Callable, max_ticks: int) -> int:
	for tick: int in max_ticks:
		Sim.step(1)
		_keep_alive()
		if done.call():
			return tick + 1
	return -1


func _real_p1(pos: Vector2i) -> PlayerBase:
	if _hero != null and is_instance_valid(_hero):
		_hero.free()
	var hero: PlayerBase = (load(PLAYER_SCENE) as PackedScene).instantiate() as PlayerBase
	place(_level, hero, pos, {"slot": 0})
	hero.respawn_at(pos)
	_hero = hero
	return hero


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


func _episode(hero: PlayerBase, weapon: int, pos: Vector2i, flags: PackedInt32Array) -> void:
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
		if _shadow:
			_keep_alive()
	GameInput.clear_scripted()


func _on_defeated(boss: BossBase) -> void:
	_defeated.append(boss)


## Recorded by test_the_club_pilot_still_wins_on_the_test_level with CHIEF_ROUTE=1 (Beginner, Expert).
const ROUTE_BEGINNER: String = (
	"8:R,6:F,21:,6:F,5:,5:R,10:RU,8:,6:F,7:,1:L,1:R,3:L,32:,1:R,4:,6:F,1:,6:F,8:,10:R,6:F,9:,6:F,8:,6:F"
)
const ROUTE_EXPERT: String = (
	"8:R,6:F,21:,6:F,5:,5:R,10:RU,8:,6:F,7:,1:L,1:R,3:L,32:,20:RU,47:,20:RU,10:,1:L,6:F,5:,2:R,1:L,1:R,20:," +
	"10:LU,14:,7:L,10:,5:L,6:F,5:,3:R,1:L,11:,6:F,6:,6:L,10:LU,10:,20:RU,13:,14:R,6:F,22:,6:F,46:,15:L,6:F,5:," +
	"10:LU,34:,7:R,10:RU,4:,3:R,10:,6:F,5:,2:R,1:,6:F,5:,3:L,6:F,13:,7:R,1:L,1:,4:F"
)

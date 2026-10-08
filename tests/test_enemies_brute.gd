extends "res://tests/test_enemies_case.gd"
## The co-op Brute (scripts/bosses/brute.gd; DESIGN.md B.7, GAMEPLAY.md 13.6; PLAN.md P2.3, owner enemies-C): the form
## only in a co-op game of two heroes on a co-op file (everywhere else the 1.0 Brute: tests/test_enemies_bosses.gd and
## the two-hero identity traces of tests/test_enemies_coop.gd), hit points x5/4, the last hitter as its target, the arm
## guard that only the partner (or a Totem Ride rider) gets past, the Grab with its chest beat, squeeze, wriggle and the
## partner's rescue, Beginner without grabs, the reset; the fairness per hero and the single-hero search.
##
## A flat floor (feet y 160), the Brute at x 400 between columns 20 and 30; P1 = `_hero`, P2 = `_p2` (bare heroes).

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"

var _p2: PlayerBase = null
## Where the single-hero search keeps its idle partner (x < 0: none kept).
var _p2_spot: Vector2i = Vector2i(-1, -1)


func before_each() -> void:
	super.before_each()
	_p2_spot = Vector2i(-1, -1)


func after_each() -> void:
	GameInput.clear_scripted()
	Game.helper_mode = false
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"")


# =================================================================================================================
# The form
# =================================================================================================================

func test_the_brute_keeps_its_solo_form_off_a_coop_file_or_alone() -> void:
	var brute: Brute = _coop_brute(Defs.Difficulty.EXPERT, false, Vector2i(300, 160), Vector2i(330, 160))
	brute.start_fight()
	assert_false(brute.is_coop_form(), "a co-op game on a solo file: the 1.0 Brute")
	assert_eq(brute.max_hp, EnemyTuning.BRUTE_HP)
	_level.free()
	_level = null
	Game.new_game(Defs.Difficulty.EXPERT)
	Game.begin_level(&"test")
	_flat_level(60, 16, 10)
	_level.meta["kind"] = "coop"
	var solo: Brute = _brute()
	solo.start_fight()
	assert_false(solo.is_coop_form(), "a party of one: the 1.0 Brute")
	assert_eq(solo.max_hp, EnemyTuning.BRUTE_HP)


func test_coop_hit_points_and_the_last_hitter_is_the_target() -> void:
	var brute: Brute = _coop_fight(Defs.Difficulty.BEGINNER, Vector2i(330, 160), Vector2i(470, 160))
	assert_true(brute.is_coop_form())
	assert_eq(brute.max_hp, 80, "64 -> 80 (x5/4)")
	assert_eq(brute.hp, 80)
	assert_eq(brute._target_hero(), _hero, "before any hit: the nearest hatched hero")
	_club_by(_p2, brute.get_head_rect())
	Sim.step(1)
	_p2.club_box_active = false
	assert_eq(brute.hp, 80 - 25, "P2, not its target, reaches the head")
	assert_eq(brute.last_hitter, _p2)
	assert_eq(brute._target_hero(), _p2, "now it targets P2, who hit it last")
	_p2.down = true
	assert_eq(brute._target_hero(), _hero, "an egg is no target: back to the nearest")


func test_coop_the_arm_guard_turns_the_target_heros_hits_away() -> void:
	var brute: Brute = _coop_fight(Defs.Difficulty.BEGINNER, Vector2i(330, 160), Vector2i(470, 160))
	var stars: int = _count_fx(&"fx/hit_stars")
	_club_by(_hero, brute.get_head_rect())
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(brute.hp, 80, "its target's club glances off the arm guard")
	assert_eq(_count_fx(&"fx/hit_stars"), stars + 1, "with a spark")
	var axe: ProjectileBase = _shot(brute.get_head_rect(), 0)
	Sim.step(1)
	assert_true(axe.spent, "a throw is used up ...")
	assert_eq(brute.hp, 80, "... and glances too")
	_hero.teleport(Vector2i(470, 160))
	_p2.teleport(Vector2i(330, 160))
	Sim.step(1)
	_club_by(_hero, brute.get_head_rect())
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(brute.hp, 80, "from behind as well: the guard turns with its target")
	_club_by(_p2, brute.get_head_rect())
	Sim.step(1)
	_p2.club_box_active = false
	assert_eq(brute.hp, 55, "the partner's club counts from the front")
	Sim.step(Tuning.BOSS_HIT_COOLDOWN + 2)
	assert_eq(brute._target_hero(), _p2)
	_shot(brute.get_head_rect(), 0)
	Sim.step(1)
	assert_eq(brute.hp, 55, "wf10: its head is covered after a counted hit - P1's throw glances")
	brute._set_state(Brute.State.JUMP)
	Sim.step(1)
	_shot(brute.get_head_rect(), 0)
	Sim.step(1)
	assert_eq(brute.hp, 30, "its chest beat uncovers it: now P1's throw counts - the roles swap with every hit")


## wf10 boss balance: the co-op Brute counts club hits - a charged blow (or any weapon's power) takes 25 - and after a
## counted hit its head is COVERED: blows glance with a clank, it watches the whole BRUTE_WATCH_TICKS without anger
## (also late in the fight) and uncovers when it beats its chest. The solo Brute keeps the power of every blow.
func test_coop_counts_club_hits_and_covers_its_head_until_its_chest_beat() -> void:
	var brute: Brute = _coop_fight(Defs.Difficulty.EXPERT, Vector2i(330, 160), Vector2i(470, 160))
	var full: int = brute.hp
	assert_eq(full, EnemyTuning.BRUTE_HP * 5 / 4, "the test den's 64 x 5/4 (w2_l2b_coop: 187 / 312 = 8 / 13 club hits)")
	_club_by(_p2, brute.get_head_rect())
	_p2.club_power = 100
	Sim.step(1)
	_p2.club_box_active = false
	assert_eq(brute.hp, full - Brute.COOP_HIT_POWER, "a charged blow counts one club hit")
	assert_true(brute._cover, "then the head is covered")
	brute.hp = 40
	var stars: int = _count_fx(&"fx/hit_stars")
	var watched: int = 0
	var uncovered: int = -1
	for tick: int in EnemyTuning.BRUTE_STAGGER_TICKS + EnemyTuning.BRUTE_WATCH_TICKS + 30:
		if tick % 12 == 0:
			_club_by(_hero, brute.get_head_rect())
		Sim.step(1)
		_hero.club_box_active = false
		_hero.run.hearts = Tuning.ENERGY_START
		_p2.run.hearts = Tuning.ENERGY_START
		if brute.get_state() == Brute.State.WATCH:
			watched += 1
		if uncovered < 0 and not brute._cover:
			uncovered = tick
			assert_eq(brute.get_state(), Brute.State.JUMP, "the chest beat uncovers it")
		if uncovered < 0:
			assert_eq(brute.hp, 40, "tick %d: every blow on the covered head glances" % tick)
	assert_true(_count_fx(&"fx/hit_stars") > stars, "with sparks")
	assert_true(uncovered >= 0, "it uncovers")
	assert_true(watched >= EnemyTuning.BRUTE_WATCH_TICKS - 2, "under 60 hit points it still watched %d ticks" % watched)
	var solo: Brute = _coop_brute(Defs.Difficulty.EXPERT, false, Vector2i(330, 160), Vector2i(470, 160))
	solo.start_fight()
	Sim.step(1)
	assert_false(solo.is_coop_form())


func test_coop_a_totem_ride_rider_strikes_over_the_guard() -> void:
	var brute: Brute = _coop_fight(Defs.Difficulty.BEGINNER, Vector2i(330, 160), Vector2i(330, 160))
	_hero.totem_carrier = _p2
	_p2.totem_rider = _hero
	assert_true(_hero.is_riding_totem())
	_club_by(_hero, brute.get_head_rect())
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(brute.hp, 55, "the target on his partner's head is above the guard")


## G33: the first target is the nearest ACTIVE hero. P2 dozes right beside the Brute, P1 stands farther off: the guard
## faces P1 (his hits glance); P2's own hit (G34: an action) would count - but a dozing hero gives none.
func test_coop_a_dozing_partner_never_draws_the_guard() -> void:
	var brute: Brute = _coop_fight(Defs.Difficulty.BEGINNER, Vector2i(500, 160), Vector2i(370, 160))
	_p2.idle = true
	Sim.step(1)
	assert_eq(brute._target_hero(), _hero, "the dozing P2 is nearer, but P1 is the nearest ACTIVE hero")
	_club_by(_hero, brute.get_head_rect())
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(brute.hp, 80, "P1's hit glances off the guard that faces him")
	_shot(brute.get_head_rect(), 0)
	Sim.step(1)
	assert_eq(brute.hp, 80, "and so does his throw")
	_p2.idle = false
	Sim.step(1)
	assert_eq(brute._target_hero(), _p2, "P2 plays again: the nearest active hero is the target")


## G35 (lead designer, wf9 #2 as corrected): the co-op Brute's head on the floor - standing, beating its chest, holding
## a hero - stays clear of the fight HUD (ui's Hud.weak_point_problem) in a view whose last row is the floor.
func test_coop_the_head_stays_clear_of_the_hud() -> void:
	var brute: Brute = _grabbed(Defs.Difficulty.EXPERT)
	var view: Rect2i = Rect2i(brute.sim_pos.x - Tuning.VIEW_W / 2, 160 + Tuning.TILE - Tuning.VIEW_H, Tuning.VIEW_W,
			Tuning.VIEW_H)
	for state: int in [Brute.State.HOLD, Brute.State.GRAB_BEAT, Brute.State.WATCH]:
		if state != Brute.State.HOLD:
			brute._release(false)
			brute._set_state(state)
			brute.set_box(EnemyTuning.BRUTE_BOX_STAND)
		var head: Rect2i = brute.get_head_rect()
		assert_true(view.encloses(head), "state %d: wholly in the view" % state)
		var art: Rect2 = Rect2(Vector2(head.position - view.position) * 2, Vector2(head.size) * 2)
		assert_eq(Hud.weak_point_problem(art, Vector2(view.size) * 2), "", "state %d: the HUD rule" % state)


## G56: the co-op Brute's 1.0 high JUMP (take-off to landing) and its DYING leap carry no weak point - an empty head
## rect, so Hud.weak_point_problem has nothing to judge there and a throw during the leap does no damage; on the floor
## its head stays clear of the HUD band (the JUMP's taunt on the ground included).
func test_coop_the_jump_and_the_death_leap_are_no_weak_point() -> void:
	var brute: Brute = _coop_fight(Defs.Difficulty.BEGINNER, Vector2i(250, 160), Vector2i(560, 160))
	var view: Rect2i = Rect2i(brute.sim_pos.x - Tuning.VIEW_W / 2, 160 + Tuning.TILE - Tuning.VIEW_H, Tuning.VIEW_W,
			Tuning.VIEW_H)
	brute._set_state(Brute.State.JUMP)
	var ground_head: Rect2i = brute.get_head_rect()
	assert_true(ground_head.has_area(), "JUMP, still on the floor (the chest beat): the head is open")
	var art: Rect2 = Rect2(Vector2(ground_head.position - view.position) * 2, Vector2(ground_head.size) * 2)
	assert_eq(Hud.weak_point_problem(art, Vector2(view.size) * 2), "", "JUMP on the floor: the HUD rule")
	var airborne: int = _step_until(func() -> bool: return brute.get_state() == Brute.State.JUMP and not brute._grounded,
			EnemyTuning.BRUTE_TAUNT_TICKS + 10)
	assert_true(airborne > 0, "the high jump takes off")
	assert_false(brute.get_head_rect().has_area(), "JUMP in the air (co-op form): no weak point (G56)")
	assert_eq(Hud.weak_point_rects(brute), [] as Array[Rect2i], "nothing for weak_point_problem to judge")
	var hp: int = brute.hp
	_shot(Rect2i(brute.sim_pos.x - 16, brute.sim_pos.y - brute.box_h, 32, 30), 1)
	Sim.step(1)
	assert_eq(brute.hp, hp, "a throw during the leap does no damage")
	brute._set_state(Brute.State.WATCH)
	brute.hp = 1
	brute.last_hitter = _p2
	brute._on_lethal_hit()
	brute.hp = 0
	assert_eq(brute.get_state(), Brute.State.DYING)
	assert_false(brute.get_head_rect().has_area(), "DYING (every form): no weak point after the lethal blow (G56)")
	assert_eq(Hud.weak_point_rects(brute), [] as Array[Rect2i], "and no weak_point_problem for the HUD band")


## G56 in the 1.0 form: the solo Brute's high jump keeps its 1.0 head (V1); only its death leap has no weak point.
func test_the_solo_brute_keeps_its_jump_head_and_loses_it_dying() -> void:
	var brute: Brute = _brute()
	brute._set_state(Brute.State.JUMP)
	brute._grounded = false
	assert_true(brute.get_head_rect().has_area(), "the 1.0 high jump keeps its head")
	brute._set_state(Brute.State.DYING)
	assert_false(brute.get_head_rect().has_area(), "DYING: none")


## G33: no Totem Ride exemption on an idle carrier (party allows no ride on one; the guard checks it too).
func test_coop_a_rider_on_a_dozing_carrier_stays_under_the_guard() -> void:
	var brute: Brute = _coop_fight(Defs.Difficulty.BEGINNER, Vector2i(330, 160), Vector2i(330, 160))
	_hero.totem_carrier = _p2
	_p2.totem_rider = _hero
	_p2.idle = true
	_club_by(_hero, brute.get_head_rect())
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(brute.hp, 80, "the rider of a dozing carrier is still its guarded target")
	_hero.totem_carrier = null
	_p2.totem_rider = null


## G33: the Grab seizes only an active hero: a dozing target in reach of the open hands is not held (he is no bait for
## a lone player's rescue hit).
func test_coop_a_dozing_hero_is_never_grabbed() -> void:
	var brute: Brute = _coop_fight(Defs.Difficulty.EXPERT, Vector2i(380, 160), Vector2i(560, 160))
	brute.hp = 39
	brute.last_hitter = _hero
	_hero.idle = true
	brute._set_state(Brute.State.WATCH)
	for tick: int in 120:
		_hero.teleport(Vector2i(brute.sim_pos.x + brute.facing * 20, 160))
		Sim.step(1)
		_hero.run.hearts = Tuning.ENERGY_START
		_hero.hit_timer = 0
		assert_null(brute.get_held(), "tick %d: the dozing hero is not seized" % tick)


func test_coop_the_grab_beats_its_chest_opens_and_squeezes() -> void:
	var brute: Brute = _coop_fight(Defs.Difficulty.EXPERT, Vector2i(380, 160), Vector2i(500, 160))
	brute.hp = 39
	brute._set_state(Brute.State.WATCH)
	var began: int = _step_until(func() -> bool: return brute.get_state() == Brute.State.GRAB_BEAT, 10)
	assert_true(began > 0, "below half its hit points, its target close: the chest beat")
	_hero.teleport(Vector2i(340, 160))
	Sim.step(Brute.GRAB_BEAT_TICKS - 1)
	assert_eq(brute.get_state(), Brute.State.GRAB_BEAT, "22 ticks of warning")
	assert_null(brute.get_held())
	_hero.teleport(Vector2i(brute.sim_pos.x + brute.facing * 20, 160))
	_hero.hit_timer = 0
	Sim.step(2)
	assert_eq(brute.get_held(), _hero, "the hands open: a target within 30 px in front is seized")
	assert_false(_hero.control_enabled, "he cannot move or strike")
	assert_eq(_hero.sim_pos, Vector2i(brute.sim_pos.x + brute.facing * Brute.GRAB_REACH_PX, 160))
	var bones: int = Game.runs[0].bones
	Sim.step(Brute.GRAB_SQUEEZE_TICKS - 1)
	assert_eq(Game.runs[0].bones, bones, "not yet")
	Sim.step(1)
	assert_eq(Game.runs[0].bones, bones - 1, "a bone per 44 ticks of squeezing")


func test_coop_wriggling_shortens_the_hold() -> void:
	var brute: Brute = _grabbed(Defs.Difficulty.EXPERT)
	var left0: int = brute.get_hold_left()
	var keys: Array[int] = [Defs.IN_LEFT, Defs.IN_RIGHT, Defs.IN_LEFT, Defs.IN_RIGHT, Defs.IN_RIGHT, 0]
	for key: int in keys:
		GameInput.set_scripted_slot(0, func(_t: int) -> int: return key)
		Sim.step(1)
	GameInput.clear_scripted()
	assert_eq(brute.get_hold_left(), left0 - keys.size() - 3 * Brute.GRAB_WRIGGLE_TICKS,
			"three presses in turn after the first: 3 x 4 ticks off (a held key counts once)")
	var ended: int = _step_until(func() -> bool: return brute.get_held() == null, Brute.GRAB_HOLD_TICKS)
	assert_true(ended > 0, "the hold ends by itself")
	assert_true(_hero.control_enabled)
	assert_eq(_hero.shield, Brute.GRAB_FREE_SHIELD_TICKS, "he blinks free")


func test_coop_the_partners_head_hit_frees_him_and_staggers_the_brute() -> void:
	var brute: Brute = _grabbed(Defs.Difficulty.EXPERT)
	var hp: int = brute.hp
	_club_by(_hero, brute.get_head_rect())
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(brute.get_held(), _hero, "the held hero cannot strike himself free")
	_club_by(_p2, brute.get_head_rect())
	Sim.step(1)
	_p2.club_box_active = false
	assert_null(brute.get_held(), "the partner's head hit frees him")
	assert_eq(brute.hp, hp - 25, "and counts")
	assert_eq(brute.get_state(), Brute.State.STAGGER, "the Brute staggers")
	assert_true(_hero.control_enabled)
	assert_eq(_hero.shield, Brute.GRAB_FREE_SHIELD_TICKS)
	Sim.step(EnemyTuning.BRUTE_STAGGER_TICKS + 1)
	assert_ne(brute.get_state(), Brute.State.STAGGER, "19 ticks")


func test_coop_beginner_has_no_grab() -> void:
	var brute: Brute = _coop_fight(Defs.Difficulty.BEGINNER, Vector2i(380, 160), Vector2i(500, 160))
	brute.hp = 30
	brute._set_state(Brute.State.WATCH)
	for tick: int in 200:
		Sim.step(1)
		_hero.hit_timer = 0
		Game.runs[0].hearts = Tuning.ENERGY_START
		assert_ne(brute.get_state(), Brute.State.GRAB_BEAT, "no grabs on Beginner (GAMEPLAY 13.9.10)")
	assert_null(brute.get_held())


## Helper mode (PHYSICS.md C.12, player-A's PlayerBase.is_helper): the Grab hurts outside hurt(), so a Helper-mode P2
## is never grabbed - the Brute that targets him beats no chest and seizes nobody.
func test_coop_a_helper_is_never_grabbed() -> void:
	var brute: Brute = _coop_fight(Defs.Difficulty.EXPERT, Vector2i(120, 160), Vector2i(380, 160))
	Game.helper_mode = true
	assert_true(_p2.is_helper())
	brute.hp = 39
	brute.last_hitter = _p2
	brute._set_state(Brute.State.WATCH)
	for tick: int in 150:
		_p2.teleport(Vector2i(brute.sim_pos.x + brute.facing * 20, 160))
		_p2.hit_timer = 0
		Sim.step(1)
		assert_ne(brute.get_state(), Brute.State.GRAB_BEAT, "no grab for a helper")
		assert_null(brute.get_held())
	Game.helper_mode = false


func test_coop_a_team_wipe_resets_the_form_and_lets_go() -> void:
	var brute: Brute = _grabbed(Defs.Difficulty.EXPERT)
	_level.reset_entities()
	assert_null(brute.get_held(), "the reset lets go")
	assert_true(_hero.control_enabled)
	assert_false(brute.fighting)
	assert_eq(brute.hp, EnemyTuning.BRUTE_HP, "back to rest")
	brute.start_fight()
	assert_true(brute.is_coop_form(), "the next fight is the co-op form again")
	assert_eq(brute.hp, 80)


## The fairness of the Grab per hero: the chest beat shows 22 ticks ahead whichever hero it targets, a hero who steps
## more than 30 px away before the hands open is never seized, and the partner can always reach the head of a holding
## Brute from the floor behind it (a standing club strike).
func test_coop_the_grab_is_fair_to_either_hero() -> void:
	for slot: int in 2:
		var brute: Brute = _coop_fight(Defs.Difficulty.EXPERT, Vector2i(380, 160), Vector2i(500, 160))
		var target: PlayerBase = _hero if slot == 0 else _p2
		var other: PlayerBase = _p2 if slot == 0 else _hero
		brute.last_hitter = target
		other.teleport(Vector2i(560, 160) if slot == 0 else Vector2i(240, 160))
		target.teleport(Vector2i(brute.sim_pos.x + (-40 if slot == 0 else 40), 160))
		brute.hp = 39
		brute._set_state(Brute.State.WATCH)
		var began: int = _step_until(func() -> bool: return brute.get_state() == Brute.State.GRAB_BEAT, 10)
		assert_true(began > 0, "slot %d: the beat" % slot)
		target.teleport(Vector2i(brute.sim_pos.x + brute.facing * 48, 160))
		_step_until(func() -> bool: return brute.get_state() != Brute.State.GRAB_BEAT \
				and brute.get_state() != Brute.State.GRAB_OPEN, 40)
		assert_null(brute.get_held(), "slot %d: a hero who stepped away is never seized" % slot)
		brute._grab_cooldown = 0
		brute._set_state(Brute.State.WATCH)
		target.teleport(Vector2i(brute.sim_pos.x - 25, 160))
		_step_until(func() -> bool: return brute.get_held() != null, 60)
		assert_eq(brute.get_held(), target, "slot %d: seized" % slot)
		var behind: Vector2i = Vector2i(brute.sim_pos.x - brute.facing * 40, 160)
		other.teleport(behind)
		var high: Rect2i = _high_box(behind, brute.facing)
		assert_true(Overlap.rects(high, brute.get_head_rect()), "slot %d: the partner's high strike reaches" % slot)
		_level.free()
		_level = null


## V3.d: one hero cannot beat the co-op Brute. The real hero (every weapon, many starts, seeded random inputs) fights
## it while his partner is an egg, or hatched and IDLE anywhere on its floor (G33: right beside it on either side, or
## far off): whatever he does, he is always its target and its arm guard turns every hit away.
func test_the_single_hero_search_cannot_hurt_the_coop_brute() -> void:
	Game.start_run(Defs.Difficulty.EXPERT, Defs.GameMode.COOP, 2)
	Game.begin_level(&"test")
	Sim.rng.reseed(3)
	_flat_level(60, 16, 10)
	_level.meta["kind"] = "coop"
	_level.view = Rect2i(240, 0, Tuning.VIEW_W, Tuning.VIEW_H)
	_hero.free()
	var hero: PlayerBase = (load(PLAYER_SCENE) as PackedScene).instantiate() as PlayerBase
	place(_level, hero, Vector2i(300, 160), {"slot": 0})
	hero.respawn_at(Vector2i(300, 160))
	_hero = hero
	_p2 = _add_p2(Vector2i(500, 160))
	_p2.down = true
	var brute: Brute = _brute()
	brute.start_fight()
	assert_true(brute.is_coop_form())
	var rng: SimRng = SimRng.new(99)
	for weapon: int in [Defs.Weapon.CLUB, Defs.Weapon.HAMMER, Defs.Weapon.AXE, Defs.Weapon.BOOMERANG, Defs.Weapon.SPEAR]:
		for start: int in [300, 340, 460, 500]:
			_episode(hero, weapon, Vector2i(start, 160), _random_flags(rng, 160))
			assert_eq(brute.hp, 80, "weapon %d from x %d: nothing counts" % [weapon, start])
	# The idle partner, hatched, kept where he was put (beside it on both sides, far off on both sides).
	for spot: int in [370, 430, 260, 560]:
		_p2_spot = Vector2i(spot, 160)
		_p2.down = false
		_p2.respawn_at(_p2_spot)
		_p2.idle = true
		brute.last_hitter = null
		for weapon: int in [Defs.Weapon.CLUB, Defs.Weapon.AXE, Defs.Weapon.SPEAR]:
			for start: int in [300, 460]:
				_episode(hero, weapon, Vector2i(start, 160), _random_flags(rng, 160))
				assert_eq(brute.hp, 80, "partner at %d, weapon %d from x %d: nothing counts" % [spot, weapon, start])
	assert_false(brute.dead)


# =================================================================================================================
# Helpers
# =================================================================================================================

func _brute() -> Brute:
	return _enemy(&"bosses/brute", Vector2i(400, 160), {"arena": "pit", "left": 20, "right": 30}) as Brute


## A co-op game (`coop_file`: on a co-op file) with P1 at `p1`, P2 at `p2` and the Brute (fight not started).
func _coop_brute(difficulty: int, coop_file: bool, p1: Vector2i, p2: Vector2i) -> Brute:
	Game.start_run(difficulty, Defs.GameMode.COOP, 2)
	Game.begin_level(&"test")
	Sim.rng.reseed(1)
	_flat_level(60, 16, 10)
	if coop_file:
		_level.meta["kind"] = "coop"
	_level.view = Rect2i(240, 0, Tuning.VIEW_W, Tuning.VIEW_H)
	_hero.teleport(p1)
	_p2 = _add_p2(p2)
	return _brute()


func _coop_fight(difficulty: int, p1: Vector2i, p2: Vector2i) -> Brute:
	var brute: Brute = _coop_brute(difficulty, true, p1, p2)
	brute.start_fight()
	Sim.step(1)
	return brute


## A co-op Brute (Expert) holding P1 in its Grab.
func _grabbed(difficulty: int) -> Brute:
	var brute: Brute = _coop_fight(difficulty, Vector2i(380, 160), Vector2i(500, 160))
	brute.hp = 39
	brute.last_hitter = _hero
	brute._set_state(Brute.State.WATCH)
	_step_until(func() -> bool: return brute.get_held() != null, 60)
	assert_eq(brute.get_held(), _hero, "held")
	return brute


func _add_p2(pos: Vector2i) -> PlayerBase:
	var p2: PlayerBase = PlayerBase.new()
	place(_level, p2, pos, {"slot": 1})
	p2.respawn_at(pos)
	return p2


func _club_by(hero: PlayerBase, box: Rect2i) -> void:
	hero.club_box_active = true
	hero.club_box = box
	hero.club_power = 25


## A thrown weapon of the hero of `owner` in the middle of `target`.
func _shot(target: Rect2i, owner: int) -> ProjectileBase:
	var shot: ProjectileBase = ProjectileBase.new()
	place(_level, shot, Vector2i(target.get_center().x, target.end.y),
			{"from_hero": true, "power": 25, "owner": owner})
	return shot


func _high_box(feet: Vector2i, facing: int) -> Rect2i:
	var rect: Rect2i = Tuning.CLUB_BOX[Tuning.ClubFrame.HIGH_FRONT]
	var origin: Vector2i = Tuning.CLUB_ORIGIN[Tuning.ClubFrame.HIGH_FRONT]
	var xo: int = origin.x - rect.position.x
	var ox: int = feet.x + facing * origin.x
	return Rect2i(ox - xo, feet.y + rect.position.y, rect.size.x, rect.size.y)


func _count_fx(id: StringName) -> int:
	var count: int = 0
	for entity: SimEntity in _level.get_kind(Defs.Kind.FX):
		if entity.scene_file_path.get_file().get_basename() == String(id).get_file():
			count += 1
	return count


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
		if _p2 != null and is_instance_valid(_p2) and _p2_spot.x >= 0:
			# The search's idle partner stays where he was put, hatched and idle (a hurt or a grab would move him).
			_p2.run.hearts = Tuning.ENERGY_START
			_p2.hit_timer = mini(_p2.hit_timer, 1)
			if _p2.dead or _p2.is_down() or _p2.sim_pos != _p2_spot:
				_p2.down = false
				_p2.respawn_at(_p2_spot)
			_p2.idle = true
	GameInput.clear_scripted()

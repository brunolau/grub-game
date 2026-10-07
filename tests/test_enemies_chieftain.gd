extends "res://tests/test_enemies_case.gd"
## The Rival Chieftains (scripts/bosses/chieftain.gd; DESIGN.md B.6, GAMEPLAY.md 13.6; PLAN.md P2.3, owner enemies-C):
## the pair and its lead, the solo tag team, the "HUP!" telegraph, one pip per hit, P1 raids, the P2 bat (solo: the
## waiting chief comes down to bat the fighter; co-op: the stack, then the bat), the P3 roast run, the eggs (solo 132,
## co-op 66, the mate's hatch), the win; the co-op hold-off rule and the single-hero search; and the hero-physics
## executor driven by core-B's HeroBot (behind Chieftain.hero_bot_enabled).
##
## The pyre: 20 x 12 cells, walls at columns 0 and 19, the floor at row 11 (feet y 176), the altar (one-way) at columns
## 9-10 of row 5 (top y 80), ledges at row 8. Gorm's record stands on the floor at column 6 (x 104), Gulla's on the
## altar (x 152, y 80).

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const FLOOR_Y: int = 176
const ALTAR_Y: int = 80

var _p2: PlayerBase = null
var _gorm: Chieftain = null
var _gulla: Chieftain = null
var _defeated: Array[BossBase] = []


func before_each() -> void:
	super.before_each()
	_defeated.clear()
	_p2 = null
	Events.boss_defeated.connect(_on_defeated)


func after_each() -> void:
	Events.boss_defeated.disconnect(_on_defeated)
	Chieftain.hero_bot_enabled = false
	GameInput.clear_scripted()
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
	assert_eq(_gorm.perch.x, 24, "and runs for the perch farther from the hero")
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
	var home: int = _step_until(func() -> bool: return not _gorm.carries_roast(), 400)
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


# =================================================================================================================
# The hero-physics executor (HeroBot)
# =================================================================================================================

## Behind the flag: each chieftain drives a hero body (scenes/player/player.tscn, not one of the level's heroes) from
## its HeroBot's GameInput slot; the body moves on the hero's own physics (at most the hero's 5 px per tick, the
## jump table), the shell mirrors it, and the brain's telegraph shows the HUP!.
func test_hero_bot_bodies_move_on_hero_physics() -> void:
	Chieftain.hero_bot_enabled = true
	_pyre(false)
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
	var fastest: int = 0
	var highest: int = FLOOR_Y
	var telegraphed: bool = false
	var last: Vector2i = _gorm.sim_pos
	for tick: int in 400:
		Sim.step(1)
		_keep_alive()
		fastest = maxi(fastest, absi(_gorm.sim_pos.x - last.x))
		highest = mini(highest, _gorm.sim_pos.y)
		last = _gorm.sim_pos
		assert_eq(_gorm.sim_pos, body.sim_pos, "the shell mirrors the body")
		telegraphed = telegraphed or _gorm.is_telegraphing()
		if _hero.hit_timer > 0 and telegraphed:
			break
	assert_true(fastest <= Tuning.WALK_CAP / 16 + 1, "never faster than the hero walks (%d px/tick)" % fastest)
	assert_true(absi(_gorm.sim_pos.x - 104) > 16, "it went for the hero")
	assert_true(telegraphed, "its attacks are announced (the brain's 14-tick crouch)")


## Behind the flag the whole fight still ends: a bare hero who keeps hitting whichever chieftain is in play wins.
func test_hero_bot_fight_can_be_won() -> void:
	Chieftain.hero_bot_enabled = true
	_pyre(false)
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


# =================================================================================================================
# Helpers
# =================================================================================================================

## The pyre of the header with both chieftains (fight not started); `coop`: a co-op game of two on a co-op file.
func _pyre(coop: bool) -> void:
	if coop:
		Game.start_run(Defs.Difficulty.EXPERT, Defs.GameMode.COOP, 2)
		Game.begin_level(&"test")
		Sim.rng.reseed(1)
	var rows: PackedStringArray = PackedStringArray()
	rows.append("#".repeat(20))
	for row: int in range(1, 11):
		var line: String = "#" + ".".repeat(18) + "#"
		if row == 5:
			line = "#........--........#"
		elif row == 8:
			line = "#.---.........---..#"
		rows.append(line)
	rows.append("#".repeat(20))
	_rows_level(rows)
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
	GameInput.clear_scripted()


func _on_defeated(boss: BossBase) -> void:
	_defeated.append(boss)

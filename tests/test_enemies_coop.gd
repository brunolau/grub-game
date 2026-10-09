extends "res://tests/test_enemies_case.gd"
## The co-op enemy rules (PLAN.md P1.8; DESIGN.md D.6, GAMEPLAY.md 13.9.4 / 13.9.5): the eight traits of
## scripts/enemies/coop_traits.gd - shell, bond, daze, heavy, lone, grab, leech, split - and the bond / keeper
## registry, the sticky party targeting, the record file levels/test_enemies_coop.lvl, and the two-hero contacts of
## the Brute and the Colossus (converted in P0.6) with their solo behaviour unchanged.
##
## Two bare heroes (PlayerBase: they never move by themselves) in a co-op game: P1 = `_hero` (slot 0), P2 = `_p2`
## (slot 1). A party of one, or any other mode, collapses every trait to its archetype (PHYSICS.md C.0 #2).

const COOP_LEVEL: String = "res://levels/test_enemies_coop.lvl"
const PLAYER_SCENE: String = "res://scenes/player/player.tscn"

var _p2: PlayerBase = null
## The real level of the last _real_level() (null otherwise) and Sim.manual before it.
var _real: Level = null
var _was_manual: bool = false


func before_each() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	Game.begin_level(&"test")
	Sim.rng.reseed(1)
	_level = null
	_party_flat()


func after_each() -> void:
	GameInput.clear_scripted()
	if _real != null:
		Sim.manual = _was_manual
		Flow.pending_level_id = &""
		Audio.stop_music(0.0)
		_real = null
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"")


# =================================================================================================================
# Traits need a co-op party; targeting
# =================================================================================================================

func test_only_records_with_a_trait_carry_rules_and_they_need_a_coop_party() -> void:
	var plain: EnemyBase = _enemy(&"enemies/walker", Vector2i(240, 160))
	assert_null(plain.coop_traits(), "every 1.0 record: no traits")
	assert_eq(plain._sim_phases(), PackedInt32Array([Defs.Phase.ENEMIES]))
	var shell: EnemyBase = _enemy(&"enemies/walker", Vector2i(160, 160), {"coop": "shell", "speed": 0})
	assert_eq(shell.coop_traits().kind, Defs.CoopTrait.SHELL)
	assert_eq(shell._sim_phases(), PackedInt32Array([Defs.Phase.ENEMIES]))
	for trait_name: String in ["heavy", "grab", "leech"]:
		var record: EnemyBase = _enemy(&"enemies/walker", Vector2i(400, 160), {"coop": trait_name})
		assert_eq(record._sim_phases(), PackedInt32Array([Defs.Phase.ENEMIES, Defs.Phase.CONTACT_ENEMIES]),
				"%s meets the heroes before their contact pass" % trait_name)
	assert_true(CoopTraits.party_on())
	_hero.teleport(Vector2i(130, 160))
	_p2.teleport(Vector2i(600, 160))
	Sim.step(2)
	assert_eq(shell.facing, -1, "the shield faces P1")
	assert_true(shell.take_hit(10, _hero))
	assert_eq(shell.hp, 25, "front hit glances in a co-op party")
	Game.mode = Defs.GameMode.VERSUS
	assert_false(CoopTraits.party_on(), "versus: no traits")
	assert_true(shell.take_hit(10, _hero))
	assert_eq(shell.hp, 15)
	Game.mode = Defs.GameMode.COOP
	_p2.free()
	assert_false(CoopTraits.party_on(), "a party of one: no traits (N = 1 is the identity)")
	assert_true(shell.take_hit(10, _hero))
	assert_eq(shell.hp, 5, "the plain walker takes the front hit")


func test_a_party_targets_the_nearest_hatched_hero_and_sticks_to_him() -> void:
	var enemy: EnemyBase = _enemy(&"enemies/walker", Vector2i(200, 160), {"speed": 0})
	_hero.teleport(Vector2i(40, 160))
	_p2.teleport(Vector2i(260, 160))
	Sim.step(1)
	assert_eq(enemy._target_hero(), _p2, "the nearest hatched hero")
	_p2.teleport(Vector2i(560, 160))
	Sim.step(PartyTuning.TARGET_HOLD_TICKS - 1)
	assert_eq(enemy._target_hero(), _p2, "kept for TARGET_HOLD_TICKS although P1 is nearer now")
	Sim.step(1)
	assert_eq(enemy._target_hero(), _hero, "then the nearest again")
	_hero.down = true
	assert_eq(enemy._target_hero(), _p2, "an egg stops being the target at once")
	_hero.down = false
	_p2.dead = true
	assert_eq(enemy._target_hero(), _hero)
	_hero.dead = true
	assert_null(enemy._target_hero(), "nobody hatched: no target")


# =================================================================================================================
# shell
# =================================================================================================================

func test_shell_faces_the_nearer_hero_every_tick_and_only_its_back_can_be_hit() -> void:
	var shell: EnemyBase = _enemy(&"enemies/walker", Vector2i(160, 160), {"coop": "shell", "speed": 0, "hp": 100})
	_hero.teleport(Vector2i(130, 160))
	_p2.teleport(Vector2i(200, 160))
	Sim.step(2)
	assert_eq(shell.facing, -1, "the shield faces the nearer hero (P1, on the left)")
	var sparks: int = _count_fx(&"fx/hit_stars")
	assert_true(shell.take_hit(25, _hero), "a front hit is used up ...")
	assert_eq(shell.hp, 100, "... and glances")
	assert_eq(_count_fx(&"fx/hit_stars"), sparks + 1, "with a spark (and the clank)")
	assert_true(shell.take_hit(25, _p2))
	assert_eq(shell.hp, 75, "the partner hits its back")
	_p2.teleport(Vector2i(175, 160))
	Sim.step(1)
	assert_eq(shell.facing, 1, "it turns to the nearer hero on the very next tick")
	shell.take_hit(25, _p2)
	assert_eq(shell.hp, 75, "now P2 is in front")
	shell.take_hit(25, _hero)
	assert_eq(shell.hp, 50)
	_hero.teleport(Vector2i(162, 160))
	shell.take_hit(25, _hero)
	assert_eq(shell.hp, 50, "|dx| < 4 counts as the front")
	var into_face: ProjectileBase = _shot(Vector2i(200, 150), -208, 0)
	shell.take_hit(20, into_face)
	assert_eq(shell.hp, 50, "a thrown weapon flying into the shield glances")
	var from_behind: ProjectileBase = _shot(Vector2i(120, 150), 208, 0)
	shell.take_hit(20, from_behind)
	assert_eq(shell.hp, 30, "one flying at its back counts")


## G33 (the IDLE-PARTNER rule): the shield faces the nearer hero who COUNTS - a dozing partner is no bait.
func test_an_idle_partner_is_no_shell_bait() -> void:
	var shell: EnemyBase = _enemy(&"enemies/walker", Vector2i(160, 160), {"coop": "shell", "speed": 0, "hp": 100})
	var back: EnemyBase = _enemy(&"enemies/shellback", Vector2i(260, 160), {"speed": 0, "hp": 100})
	_hero.teleport(Vector2i(120, 160))
	_p2.teleport(Vector2i(180, 160))
	_p2.idle = true
	Sim.step(2)
	assert_eq(shell.facing, -1, "the shield faces the active P1, not the dozing P2 who stands nearer")
	shell.take_hit(25, _hero)
	assert_eq(shell.hp, 100, "P1's strike glances: he cannot club its back over his idle partner")
	_hero.teleport(Vector2i(220, 160))
	_p2.teleport(Vector2i(280, 160))
	Sim.step(2)
	assert_eq(back.facing, -1, "the Shellback preset too")
	back.take_hit(25, _hero)
	assert_eq(back.hp, 100)
	_p2.idle = false
	Sim.step(1)
	assert_eq(back.facing, 1, "P2 plays again: he is the nearer hero who counts")
	_hero.idle = true
	_p2.idle = true
	_p2.teleport(Vector2i(240, 160))
	_hero.teleport(Vector2i(300, 160))
	Sim.step(1)
	assert_eq(back.facing, 1, "nobody counts: it keeps its facing")


# =================================================================================================================
# bond
# =================================================================================================================

func test_a_bond_killed_within_its_window_stays_dead() -> void:
	var a: EnemyBase = _bonded(Vector2i(60, 160))
	var b: EnemyBase = _bonded(Vector2i(280, 160))
	Sim.step(2)
	assert_eq(CoopTraits.bond_members(_level, &"twins"), [a, b] as Array[EnemyBase], "the bond registry")
	assert_eq(a.bond_mates(), [b] as Array[SimEntity])
	assert_false(CoopTraits.bond_done(_level, &"twins"))
	a.kill(&"weapon", _hero)
	assert_eq(a.coop_traits().died_tick, Sim.total_ticks, "the window opens")
	assert_false(a._can_doze(), "a dead member waits awake while its window is open")
	Sim.step(CoopTraits.window_ticks() - 1)
	assert_true(a.dead)
	b.kill(&"weapon", _p2)
	assert_true(a.coop_traits().sealed and b.coop_traits().sealed, "the last kill landed within the window")
	assert_true(CoopTraits.bond_done(_level, &"twins"))
	Sim.step(100)
	assert_true(a.dead and b.dead, "a sealed bond never regrows")
	assert_eq(Game.runs[0].kills, 1)
	assert_eq(Game.runs[1].kills, 1)


func test_a_late_bond_regrows_at_its_anchor_harmless_for_a_moment() -> void:
	Game.difficulty = Defs.Difficulty.EXPERT
	assert_eq(CoopTraits.window_ticks(), PartyTuning.WINDOW_TICKS_EXPERT)
	var a: EnemyBase = _bonded(Vector2i(60, 160))
	var b: EnemyBase = _bonded(Vector2i(280, 160))
	Sim.step(2)
	a.kill(&"weapon", _hero)
	Sim.step(PartyTuning.WINDOW_TICKS_EXPERT - 1)
	assert_true(a.dead, "still dead inside the window")
	Sim.step(1)
	assert_false(a.dead, "the window closed with its mate alive: it regrows")
	assert_true(a.awake)
	assert_eq(a.sim_pos, a.spawn_pos, "at its anchor")
	assert_eq(a.hp, a.max_hp, "with full hit points")
	assert_false(a.tangible, "harmless while it regrows")
	assert_false(a.take_hit(25, _hero), "a weapon passes through it")
	assert_eq(a.coop_traits().regrow, EnemyTuning.REGROW_TICKS)
	Sim.step(EnemyTuning.REGROW_TICKS)
	assert_true(a.tangible, "after the regrow it is a normal enemy again")
	assert_false(CoopTraits.bond_done(_level, &"twins"))
	# Both killed, but too far apart: both regrow.
	a.kill(&"weapon", _hero)
	Sim.step(PartyTuning.WINDOW_TICKS_EXPERT)
	b.kill(&"weapon", _p2)
	assert_false(b.coop_traits().sealed)
	assert_false(a.dead, "the first one regrew before the second fell")
	Sim.step(PartyTuning.WINDOW_TICKS_EXPERT + 1)
	assert_false(b.dead, "and the second one regrows in its own window")


func test_a_bond_needs_the_party_and_a_team_wipe_clears_it() -> void:
	var a: EnemyBase = _bonded(Vector2i(60, 160))
	var b: EnemyBase = _bonded(Vector2i(280, 160))
	Sim.step(2)
	a.kill(&"weapon", _hero)
	b.kill(&"weapon", _p2)
	assert_true(a.coop_traits().sealed)
	_level.reset_entities()
	assert_false(a.dead or b.dead, "a team wipe brings every record back")
	assert_false(a.coop_traits().sealed or b.coop_traits().sealed)
	assert_eq(a.coop_traits().died_tick, -1)
	Sim.step(2)
	_p2.free()
	a.kill(&"weapon", _hero)
	assert_eq(a.coop_traits().died_tick, -1, "a party of one opens no window")
	Sim.step(60)
	assert_true(a.dead, "and nothing regrows")


func test_a_bond_window_is_capped_by_its_smallest_window() -> void:
	var a: EnemyBase = _enemy(&"enemies/walker", Vector2i(60, 160),
			{"coop": "bond", "bond": "twins", "speed": 0, "window": 6})
	var b: EnemyBase = _bonded(Vector2i(280, 160))
	var c: EnemyBase = _enemy(&"enemies/walker", Vector2i(400, 160),
			{"coop": "bond", "bond": "pair", "speed": 0, "window": 40})
	var d: EnemyBase = _enemy(&"enemies/walker", Vector2i(500, 160), {"coop": "bond", "bond": "pair", "speed": 0})
	assert_eq(a.coop_traits().window_cap, 6)
	assert_eq(b.coop_traits().group_window(), 6, "the bond's smallest cap")
	assert_eq(c.coop_traits().group_window(), PartyTuning.WINDOW_TICKS_BEGINNER, "a cap above 24 changes nothing")
	assert_eq(d.coop_traits().group_window(), PartyTuning.WINDOW_TICKS_BEGINNER)
	Sim.step(2)
	a.kill(&"weapon", _hero)
	Sim.step(5)
	b.kill(&"weapon", _p2)
	assert_true(a.coop_traits().sealed and b.coop_traits().sealed, "5 ticks apart: inside a 6-tick window")
	_level.reset_entities()
	Sim.step(2)
	a.kill(&"weapon", _hero)
	Sim.step(5)
	assert_true(a.dead)
	Sim.step(1)
	assert_false(a.dead, "the 6-tick window closed with its mate alive: it regrows (not after the Beginner 24)")


func test_a_bond_counts_in_while_a_hero_stands_at_each_member() -> void:
	var a: EnemyBase = _bonded(Vector2i(60, 160))
	var b: EnemyBase = _bonded(Vector2i(280, 160))
	assert_true(AudioTable.SFX.has(Sfx.COUNT_IN) and AudioTable.SFX.has(Sfx.DRUM), "the cues have their rows")
	_hero.teleport(Vector2i(80, 160))
	_p2.teleport(Vector2i(160, 160))
	Sim.step(3)
	var leader: CoopTraits = a.coop_traits()
	assert_eq(leader.count_in, -1, "P2 is not at the second member: no count-in")
	_p2.teleport(Vector2i(280 - EnemyTuning.COUNT_IN_REACH_PX, 160))
	Sim.step(1)
	assert_eq(leader.count_in, 1, "a hero at each member: the first blip, on the leader (the first in the registry)")
	assert_eq(b.coop_traits().count_in, -1, "only the leader counts")
	Sim.step(PartyTuning.COUNT_IN_BEEPS * PartyTuning.COUNT_IN_SPACING_TICKS - 1)
	assert_eq(leader.count_in, PartyTuning.COUNT_IN_BEEPS * PartyTuning.COUNT_IN_SPACING_TICKS,
			"three blips 8 ticks apart ...")
	Sim.step(1)
	assert_eq(leader.count_in, -1, "... then go")
	Sim.step(30)
	assert_eq(leader.count_in, -1, "once per arrival: no second count-in while they stand there")
	_p2.teleport(Vector2i(160, 160))
	Sim.step(1)
	_p2.teleport(Vector2i(260, 160))
	Sim.step(1)
	assert_eq(leader.count_in, 1, "they left and came back: it counts in again")
	a.kill(&"weapon", _hero)
	Sim.step(1)
	assert_eq(b.coop_traits().count_in, -1, "the window is open: no count-in")


func test_one_hero_between_both_members_is_no_count_in() -> void:
	var a: EnemyBase = _bonded(Vector2i(200, 160))
	var b: EnemyBase = _bonded(Vector2i(240, 160))
	_hero.teleport(Vector2i(220, 160))
	_p2.teleport(Vector2i(600, 160))
	Sim.step(10)
	assert_eq(a.coop_traits().count_in, -1, "one hero standing at both is not a pair")
	assert_eq(b.coop_traits().count_in, -1)
	_p2.teleport(Vector2i(230, 160))
	Sim.step(1)
	assert_eq(a.coop_traits().count_in, 1, "two heroes: it counts in")


## G33: a dozing partner is nobody for the count-in and no company for a `lone` record.
func test_an_idle_partner_counts_for_no_count_in_and_no_lone_company() -> void:
	var a: EnemyBase = _bonded(Vector2i(60, 160))
	var b: EnemyBase = _bonded(Vector2i(280, 160))
	_hero.teleport(Vector2i(80, 160))
	_p2.teleport(Vector2i(270, 160))
	_p2.idle = true
	Sim.step(3)
	assert_eq(a.coop_traits().count_in, -1, "the idle P2 at the second member: no count-in")
	_p2.idle = false
	Sim.step(1)
	assert_eq(a.coop_traits().count_in, 1, "awake: the first blip")
	assert_eq(b.coop_traits().count_in, -1)
	Game.difficulty = Defs.Difficulty.EXPERT
	var stinger: EnemyBase = _enemy(&"enemies/stinger", Vector2i(560, 100), {"coop": "lone"})
	_hero.teleport(Vector2i(550, 160))
	_p2.teleport(Vector2i(570, 160))
	assert_null(stinger._target_hero(), "together: it keeps away")
	_p2.idle = true
	assert_eq(stinger._target_hero(), _hero, "a dozing partner beside him is no protection: P1 is the straggler")


func test_split_halves_count_in_too() -> void:
	var blob: EnemyBase = _splitter(Vector2i(200, 160))
	_hero.teleport(Vector2i(150, 160))
	_p2.teleport(Vector2i(250, 160))
	Sim.step(2)
	blob.take_hit(25, _hero)
	var copy: EnemyBase = blob.coop_traits().mate
	Sim.step(EnemyTuning.SPLIT_RUN_TICKS)
	_hero.teleport(copy.sim_pos + Vector2i(-20, 0))
	_p2.teleport(blob.sim_pos + Vector2i(20, 0))
	Sim.step(2)
	assert_true(blob.coop_traits().count_in > 0, "the record leads the two halves' count-in")
	assert_eq(copy.coop_traits().count_in, -1)


func test_zone_spawners_take_turns_between_the_heroes_and_allow_half_as_many_again() -> void:
	var record: Dropper = _enemy(&"enemies/dropper", Vector2i(300, 160), {"zone": "0,0,60,16", "pause": 0, "max": 2}) \
			as Dropper
	_hero.teleport(Vector2i(100, 160))
	_p2.teleport(Vector2i(500, 160))
	assert_eq(record.max_alive_now(), 3, "max 2 x 1.5 in a co-op party")
	Sim.step(6)
	var copies: Array[SimEntity] = _of_scene(Defs.Kind.ENEMY, &"enemies/dropper")
	copies.erase(record)
	assert_eq(copies.size(), 3, "three alive at once")
	assert_eq(record.alive_copies(), 3)
	var around: Array[int] = []
	for copy: SimEntity in copies:
		around.append(0 if absi(copy.sim_pos.x - 100) == EnemyTuning.DROPPER_SIDE_PX else
				(1 if absi(copy.sim_pos.x - 500) == EnemyTuning.DROPPER_SIDE_PX else -1))
	assert_eq(around, [0, 1, 0] as Array[int], "beside P1, then P2, then P1 again")
	_p2.free()
	assert_eq(record.max_alive_now(), 2, "a party of one: the 1.0 max")


func test_an_enemy_that_hurt_both_heroes_bursts_into_twelve_bones() -> void:
	var both: EnemyBase = _enemy(&"enemies/walker", Vector2i(200, 160), {"speed": 0})
	var one: EnemyBase = _enemy(&"enemies/walker", Vector2i(260, 160), {"speed": 0})
	Sim.step(2)
	both.on_hurt_hero(_hero)
	both.on_hurt_hero(_p2)
	one.on_hurt_hero(_hero)
	one.on_hurt_hero(_hero)
	both.kill(&"weapon", _hero)
	assert_eq(_of_scene(Defs.Kind.COLLECTIBLE, &"items/bone").size(), 2 * Tuning.BONES_PER_HEART,
			"each hero's stolen heart bursts as bones: 12")
	one.kill(&"weapon", _hero)
	assert_eq(_of_scene(Defs.Kind.COLLECTIBLE, &"items/bone").size(), 3 * Tuning.BONES_PER_HEART,
			"one hero hurt twice: one heart, 6")
	_level.reset_entities()
	Sim.step(2)
	both.on_hurt_hero(_p2)
	assert_eq(both._hearts_held(), 1, "a team wipe gives the hearts back")


func test_kill_points_are_shared_out_for_the_rival_score() -> void:
	var a: EnemyBase = _enemy(&"enemies/walker", Vector2i(200, 160), {"speed": 0, "score": 3})
	var b: EnemyBase = _enemy(&"enemies/walker", Vector2i(240, 160), {"speed": 0, "score": 1})
	Sim.step(2)
	var team: int = Game.score
	a.kill(&"weapon", _p2)
	assert_eq(Game.runs[1].score, Tuning.SCORE_LADDER[3], "P2's share of the tribe score")
	assert_eq(Game.score, team + Tuning.SCORE_LADDER[3], "the tribe score as in 1.0")
	assert_eq(Game.runs[0].score, 0)
	b.on_glider_stomp(_hero)
	assert_eq(Game.runs[0].score, Tuning.GLIDER_DIVE_SCORES[0], "a glider dive counts for the diver")
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"test")
	_flat_level(60, 16, 10)
	var solo: EnemyBase = _enemy(&"enemies/walker", Vector2i(200, 160), {"speed": 0, "score": 3})
	Sim.step(2)
	solo.kill(&"weapon", _hero)
	assert_eq(Game.runs[0].score, 0, "single-player: only Game.score, as in 1.0")
	assert_eq(Game.score, Tuning.SCORE_LADDER[3])


func test_a_struck_dangler_thread_is_cut_and_the_dangler_falls_away() -> void:
	var dangler: Dangler = _enemy(&"enemies/dangler", Vector2i(200, 80), {"depth": 0}) as Dangler
	_hero.teleport(Vector2i(120, 160))
	_p2.teleport(Vector2i(180, 160))
	Sim.step(2)
	var thread: Rect2i = dangler.get_thread_rect()
	assert_true(thread.size.y > 0, "it hangs on its thread")
	# A club box beside the body only (not the thread): nothing.
	_p2.club_box = Rect2i(dangler.sim_pos.x + 20, dangler.sim_pos.y - 20, 16, 16)
	_p2.club_box_active = true
	Sim.step(1)
	assert_false(dangler.is_cut())
	_p2.club_box = Rect2i(thread.position.x - 8, thread.position.y + (thread.size.y >> 1), 16, 8)
	Sim.step(1)
	_p2.club_box_active = false
	assert_true(dangler.is_cut(), "P2's strike cut the thread")
	assert_false(dangler.contact_hurts, "falling, it is harmless")
	var y0: int = dangler.sim_pos.y
	Sim.step(10)
	assert_true(dangler.sim_pos.y > y0, "it falls")
	assert_eq(dangler.get_thread_rect(), Rect2i(), "no thread any more")
	var gone: int = _step_until(func() -> bool: return dangler.dead, 120)
	assert_true(gone > 0, "out of the view it is gone")
	assert_eq(Game.score, 0, "without points")
	_level.reset_entities()
	assert_false(dangler.is_cut() or dangler.dead or dangler.one_shot, "a team wipe hangs it up again")
	assert_true(dangler.contact_hurts)


func test_alone_a_struck_dangler_thread_holds() -> void:
	_p2.free()
	var dangler: Dangler = _enemy(&"enemies/dangler", Vector2i(200, 80), {"depth": 0}) as Dangler
	_hero.teleport(Vector2i(180, 160))
	Sim.step(2)
	var thread: Rect2i = dangler.get_thread_rect()
	_hero.club_box = Rect2i(thread.position.x - 8, thread.position.y + (thread.size.y >> 1), 16, 8)
	_hero.club_box_active = true
	Sim.step(3)
	_hero.club_box_active = false
	assert_false(dangler.is_cut(), "a party of one: the 1.0 dangler, its thread is only drawn")
	assert_eq(dangler.sim_pos, Vector2i(200, 80))


func test_keepers_and_drums_share_the_registry() -> void:
	var guard_a: EnemyBase = _enemy(&"enemies/walker", Vector2i(120, 160), {"keeper": "gully"})
	var guard_b: EnemyBase = _enemy(&"enemies/walker", Vector2i(200, 160), {"keeper": "gully"})
	var drum: SimEntity = SimEntity.new()
	place(_level, drum, Vector2i(300, 160), {"bond": "twins"})
	var a: EnemyBase = _bonded(Vector2i(60, 160))
	assert_eq(CoopTraits.bond_members(_level, &"twins"), [a] as Array[EnemyBase], "drums are not bond members")
	assert_false(CoopTraits.keepers_done(_level, &"gully"))
	assert_false(CoopTraits.keepers_done(_level, &"nobody"), "an empty group never opens a door")
	Sim.step(2)
	guard_a.kill(&"weapon", _hero)
	assert_false(CoopTraits.keepers_done(_level, &"gully"))
	guard_b.kill(&"weapon", _hero)
	assert_true(CoopTraits.keepers_done(_level, &"gully"), "every keeper dead: the door may rise")


## G66 - a flying keeper holds its perch (world-B's hop-over probe on w9_l1b_coop 'stormwall': the woken keeper
## Harrier followed a lone hero 14 columns to its mate): a Harrier record with `keeper=` never takes off. A hero right
## under it wakes it - it turns to him and screeches - and when he walks 14 columns away it is still on its anchor
## after 300 ticks, struck where it sits. The plain Harrier beside it follows him as in 1.0.
func test_a_keeper_harrier_holds_its_perch_and_a_plain_one_follows() -> void:
	_level.view = Rect2i(0, 0, 960, Tuning.VIEW_H)
	_p2.down = true
	var perch: Vector2i = Vector2i(200, 128)
	var keeper: Harrier = _enemy(&"enemies/harrier", perch, {"skin": "storm_ptero", "range": 0, "hp": 10,
			"coop": "bond", "bond": "storm", "keeper": "storm"}) as Harrier
	var plain: Harrier = _enemy(&"enemies/harrier", Vector2i(248, 128), {"skin": "storm_ptero", "range": 0,
			"hp": 10}) as Harrier
	_hero.teleport(Vector2i(160, 160))
	Sim.step(3)
	assert_true(keeper.awake and plain.awake)
	assert_eq([keeper._circling, plain._circling], [false, false], "range 0: nobody is right under them yet")
	_hero.teleport(Vector2i(204, 160))
	Sim.step(1)
	assert_true(keeper._circling, "a hero right under it: it wakes ...")
	assert_eq(keeper._anim_role, &"screech", "... and screeches")
	assert_eq(keeper.facing, 1, "turned to him")
	_hero.teleport(Vector2i(250, 160))
	Sim.step(1)
	assert_true(plain._circling, "the plain one wakes too")
	# He walks on, 14 columns in 75 ticks, and waits there: 300 ticks in all.
	var moved: int = 0
	for tick: int in 300:
		if tick < 75:
			_hero.teleport(_hero.sim_pos + Vector2i(3, 0))
		Sim.step(1)
		if keeper.sim_pos != perch or keeper.xvel != 0 or keeper.yvel != 0:
			moved += 1
	assert_eq(moved, 0, "the keeper never left its anchor")
	assert_eq(_hero.sim_pos.x - perch.x, 14 * Tuning.TILE + 50 + 1)
	assert_eq(keeper.facing, 1, "it watches him go")
	assert_eq(keeper._anim_role, &"fly", "the screech is over")
	assert_eq(keeper.get_waypoint(), 0, "no way-points")
	assert_true(absi(plain.sim_pos.x - _hero.sim_pos.x) <= 96 and absi(plain.sim_pos.x - 248) > 10 * Tuning.TILE,
			"the plain Harrier came along and circles him (1.0): %s" % plain.sim_pos)
	assert_true(keeper.contact_hurts and keeper.is_targetable(), "its body hurts, a club reaches it")
	assert_true(keeper.take_hit(25, _hero))
	assert_true(keeper.dead, "struck where it sits")


## G66, the gate as a regression (a copy of 'stormwall': two bonded keeper Harriers perched 14 columns apart, Expert,
## window 12; the partner an egg the whole time): the lone REAL hero wakes the first by walking under it, walks to the
## second and high-strikes it dead - the first has not come along. He runs back and high-strikes the first: far too
## late for the window, the second has regrown, so the keepers are never all dead and the door stays shut. (Before G66
## the first followed him and both fell 8 ticks apart.) A pair that strikes one each on the same tick opens it.
## The perches are 4 px higher than the file's two rows, so that his head passes under them without a touch.
func test_one_hero_cannot_club_both_stormwall_keepers_within_the_window() -> void:
	Game.difficulty = Defs.Difficulty.EXPERT
	_level.view = Rect2i(0, 0, 960, Tuning.VIEW_H)
	_p2.down = true
	var storm: Dictionary = {"skin": "storm_ptero", "range": 0, "hp": 10, "coop": "bond", "bond": "storm",
			"keeper": "storm"}
	var perches: Array[Vector2i] = [Vector2i(200, 124), Vector2i(200 + 14 * Tuning.TILE, 124)]
	var first: Harrier = _enemy(&"enemies/harrier", perches[0], storm) as Harrier
	var second: Harrier = _enemy(&"enemies/harrier", perches[1], storm) as Harrier
	var hero: PlayerBase = _real_hero(Vector2i(150, 160), 0)
	var keys: Array[int] = [0]
	GameInput.set_scripted_slot(0, func(_tick: int) -> int: return keys[0])
	var opened: Array[int] = [0]
	var step: Callable = func() -> void:
		Sim.step(1)
		hero.run.hearts = Tuning.ENERGY_START
		if CoopTraits.keepers_done(_level, &"storm"):
			opened[0] += 1
	# Under the first (it wakes), on to the second, into his high strike's reach.
	keys[0] = Defs.IN_RIGHT
	for tick: int in 200:
		if hero.sim_pos.x >= perches[1].x - 40:
			break
		step.call()
	assert_true(first._circling, "walking under the first woke it")
	assert_eq(first.sim_pos, perches[0], "... and it stays perched 14 columns behind him")
	keys[0] = 0
	for tick: int in 12:
		step.call()
	keys[0] = Defs.IN_UP | Defs.IN_FIRE
	for tick: int in Tuning.STRIKE_SCRIPT_HIGH.size() + 2:
		step.call()
	assert_true(second.dead, "his high strike kills the second (hero %s)" % hero.sim_pos)
	assert_false(first.dead)
	var second_died: int = Sim.total_ticks
	# Back to the first as fast as he runs.
	keys[0] = Defs.IN_LEFT
	for tick: int in 200:
		if hero.sim_pos.x <= perches[0].x + 40:
			break
		step.call()
	keys[0] = 0
	for tick: int in 12:
		step.call()
	keys[0] = Defs.IN_UP | Defs.IN_FIRE
	for tick: int in Tuning.STRIKE_SCRIPT_HIGH.size() + 2:
		step.call()
	keys[0] = 0
	assert_true(first.dead, "... and the first, where it sat (hero %s)" % hero.sim_pos)
	assert_true(Sim.total_ticks - second_died > 3 * CoopTraits.window_ticks(), "%d ticks after the second: the window is %d"
			% [Sim.total_ticks - second_died, CoopTraits.window_ticks()])
	assert_false(second.dead, "the second has regrown meanwhile (a late bond)")
	for tick: int in 60:
		step.call()
	GameInput.clear_scripted()
	assert_eq(opened[0], 0, "the keepers were never all dead: the door stays shut for one hero")
	assert_false(first.dead or second.dead, "both are back on their perches")
	assert_eq([first.sim_pos, second.sim_pos], perches)
	# The pair: one each, on the same tick.
	_p2.down = false
	first.take_hit(25, hero)
	second.take_hit(25, _p2)
	assert_true(CoopTraits.keepers_done(_level, &"storm"), "two heroes on the count-in open it")


# =================================================================================================================
# daze
# =================================================================================================================

func test_daze_hops_away_from_a_strike_and_over_a_throw() -> void:
	var raptor: EnemyBase = _raptor(Vector2i(200, 160))
	_hero.teleport(Vector2i(170, 160))
	_p2.teleport(Vector2i(300, 160))
	Sim.step(2)
	_hero.attack_gate = true
	Sim.step(1)
	assert_eq(raptor.xvel, EnemyTuning.DAZE_HOP_XVEL, "P1 started a strike 30 px away: it hops away from him")
	assert_eq(raptor.yvel, EnemyTuning.DAZE_HOP_YVEL)
	var landed: int = _step_until(func() -> bool: return raptor._grounded and raptor.xvel == 0, 40)
	assert_true(landed > 0, "and lands")
	assert_true(raptor.sim_pos.x >= 200 + 40, "out of the club's reach (%d)" % raptor.sim_pos.x)
	Sim.step(5)
	assert_eq(raptor.xvel, 0, "a strike that goes on is no new alarm")
	_hero.attack_gate = false
	Sim.step(1)
	_hero.attack_gate = true
	Sim.step(1)
	assert_eq(raptor.xvel, 0, "a new strike farther than 48 px away is ignored")
	_hero.attack_gate = false
	raptor.teleport(Vector2i(200, 160))
	var axe: ProjectileBase = _shot(Vector2i(160, 156), 208, 0)
	Sim.step(1)
	assert_eq(raptor.yvel, EnemyTuning.DAZE_THROW_HOP_YVEL, "a thrown weapon coming at it: straight up")
	assert_eq(raptor.xvel, 0)
	assert_true(is_instance_valid(axe))


func test_only_a_dazed_record_can_be_hurt() -> void:
	var raptor: EnemyBase = _raptor(Vector2i(200, 160))
	_hero.teleport(Vector2i(140, 160))
	_p2.teleport(Vector2i(300, 160))
	Sim.step(2)
	assert_true(raptor.take_hit(25, _hero), "undazed: the hit is used up ...")
	assert_eq(raptor.hp, 100, "... and glances")
	raptor.on_bounced(_p2)
	assert_eq(raptor.coop_traits().dazed, PartyTuning.DAZE_TICKS_BEGINNER, "a head bounce dazes it (Beginner 14)")
	Sim.step(1)
	assert_eq(raptor._anim_role, &"dizzy", "showing the dizzy frames")
	raptor.take_hit(25, _hero)
	assert_eq(raptor.hp, 75, "dazed: hits count")
	Sim.step(PartyTuning.DAZE_TICKS_BEGINNER)
	assert_eq(raptor.coop_traits().dazed, 0)
	raptor.take_hit(25, _hero)
	assert_eq(raptor.hp, 75, "the daze is over")
	Game.difficulty = Defs.Difficulty.EXPERT
	raptor.on_bounced(_p2)
	assert_eq(raptor.coop_traits().dazed, PartyTuning.DAZE_TICKS_EXPERT, "Expert: 12")


## G47: the daze is slot-bound - only a hero of another slot than the bouncer's hurts the dazed record.
func test_the_daze_is_slot_bound() -> void:
	var raptor: EnemyBase = _raptor(Vector2i(200, 160))
	_hero.teleport(Vector2i(180, 160))
	_p2.teleport(Vector2i(300, 160))
	Sim.step(2)
	raptor.on_bounced(_hero)
	assert_true(raptor.coop_traits().dazed > 0, "P1's head bounce dazes it")
	raptor.take_hit(25, _hero)
	assert_eq(raptor.hp, 100, "the bouncer's own strike glances: one hero never dazes and strikes alone")
	raptor.take_hit(25, _p2)
	assert_eq(raptor.hp, 75, "the partner's strike counts")
	var axe: ProjectileBase = _shot(Vector2i(160, 156), 208, 0)
	raptor.take_hit(20, axe)
	assert_eq(raptor.hp, 75, "P1's thrown weapon is his too")
	raptor.on_bounced(_p2)
	raptor.take_hit(25, _hero)
	assert_eq(raptor.hp, 50, "P2 bounced it last: now P1's strike counts ...")
	raptor.take_hit(25, _p2)
	assert_eq(raptor.hp, 50, "... and P2's glances")


# =================================================================================================================
# heavy
# =================================================================================================================

func test_heavy_glances_in_front_and_a_brace_wall_stops_it() -> void:
	var bull: EnemyBase = _enemy(&"enemies/walker", Vector2i(260, 160),
			{"coop": "heavy", "skin": "rex_b", "left": -10, "right": 0, "facing": "l", "hp": 100})
	_crouch(_hero, Vector2i(150, 160))
	_crouch(_p2, Vector2i(150 + PartyTuning.BRACE_GAP_PX, 160))
	Sim.step(2)
	assert_eq(bull.facing, -1)
	bull.take_hit(25, _hero)
	assert_eq(bull.hp, 100, "its front glances")
	var into_face: ProjectileBase = _shot(Vector2i(200, 150), 208, 1)
	bull.take_hit(20, into_face)
	assert_eq(bull.hp, 100, "a throw into its face too")
	var braced: int = _step_until(func() -> bool: return bull.coop_traits().dazed > 0, 120)
	assert_true(braced > 0, "it walks into the braced pair")
	assert_eq(bull.xvel, 0, "it stops dead")
	assert_eq(bull.coop_traits().dazed, PartyTuning.BRACE_DAZE_TICKS)
	assert_false(bull.contact_hurts, "neither hero is touched while it is dazed")
	var stopped: int = bull.sim_pos.x
	Sim.step(10)
	assert_eq(bull.sim_pos.x, stopped)
	bull.take_hit(25, _hero)
	assert_eq(bull.hp, 75, "dazed, its head is open: front hits count")
	_hero.state = Defs.HeroState.IDLE
	_p2.state = Defs.HeroState.IDLE
	Sim.step(PartyTuning.BRACE_DAZE_TICKS - 10)
	assert_eq(bull.coop_traits().dazed, 0, "the daze is over")
	assert_true(bull.contact_hurts, "awake again it hurts")
	Sim.step(1)
	assert_eq(bull.coop_traits().dazed, 0, "standing heroes are no wall")
	assert_eq(bull.xvel, -EnemyTuning.PATROL_SPEED, "it walks on at its old speed")
	_crouch(_hero, _hero.sim_pos)
	_crouch(_p2, _p2.sim_pos)
	Sim.step(1)
	assert_eq(bull.coop_traits().dazed, PartyTuning.BRACE_DAZE_TICKS, "braced again, it is stopped again")


func test_the_heroes_contact_pass_may_ask_for_the_brace() -> void:
	var bull: EnemyBase = _enemy(&"enemies/walker", Vector2i(260, 160), {"coop": "heavy", "facing": "l"})
	var plain: EnemyBase = _enemy(&"enemies/walker", Vector2i(200, 160))
	Sim.step(2)
	assert_false(plain.brace_stop(_hero, _p2), "only a heavy is stopped by a Brace Wall")
	assert_true(bull.brace_stop(_hero, _p2), "player-A's contact pass: the braced hero is not hurt")
	assert_eq(bull.coop_traits().dazed, PartyTuning.BRACE_DAZE_TICKS)
	assert_eq(bull.xvel, 0)
	Sim.step(3)
	assert_true(bull.brace_stop(_p2, _hero), "asked again while dazed: still true")
	assert_eq(bull.coop_traits().dazed, PartyTuning.BRACE_DAZE_TICKS - 3, "the daze is not restarted")
	_p2.free()
	assert_false(bull.brace_stop(_hero, null), "a party of one has no Brace Wall")


func test_a_lone_croucher_is_no_brace_wall() -> void:
	var bull: EnemyBase = _enemy(&"enemies/walker", Vector2i(260, 160),
			{"coop": "heavy", "skin": "rex_b", "left": -10, "right": 0, "facing": "l"})
	_crouch(_hero, Vector2i(150, 160))
	_crouch(_p2, Vector2i(150 + PartyTuning.BRACE_GAP_PX + 1, 160))
	var leftmost: int = bull.sim_pos.x
	for tick: int in 120:
		Sim.step(1)
		leftmost = mini(leftmost, bull.sim_pos.x)
		assert_eq(bull.coop_traits().dazed, 0, "17 px apart is no wall")
	assert_true(leftmost < 150, "it walked through them")


## The heavy-keeper ruling (G3 verifier: one hero let the Bull Rex charge under his jump and clubbed its back): a
## `heavy` record is hurt ONLY while a Brace Wall staggers it - its back glances like its front, a throw at its back
## too, and no other death takes it (kill-all, grenade, a feast's bite, glider dives); braced, its back counts. A party
## of one still meets the plain archetype.
func test_an_unbraced_heavy_glances_everywhere_and_dies_of_nothing_else() -> void:
	var bull: EnemyBase = _enemy(&"enemies/walker", Vector2i(260, 160),
			{"coop": "heavy", "skin": "rex_b", "left": -10, "right": 0, "facing": "l", "hp": 100})
	_hero.teleport(Vector2i(300, 160))
	_p2.teleport(Vector2i(60, 160))
	Sim.step(2)
	assert_eq(bull.facing, -1, "it walks left, at P2")
	assert_false(bull._hit_from_front(_hero), "P1 stands behind it")
	var sparks: int = _count_fx(&"fx/hit_stars")
	assert_true(bull.take_hit(25, _hero), "a strike at its back is used up ...")
	assert_eq(bull.hp, 100, "... and glances: no Brace Wall staggers it")
	assert_eq(_count_fx(&"fx/hit_stars"), sparks + 1, "with the glance's spark")
	assert_true(bull.take_hit(100, _hero))
	assert_eq(bull.hp, 100, "a charged one too")
	_hero.teleport(Vector2i(bull.sim_pos.x, 120))
	bull.take_hit(25, _hero)
	assert_eq(bull.hp, 100, "from above (a pogo on its back)")
	_hero.teleport(Vector2i(300, 160))
	bull.take_hit(20, _shot(Vector2i(300, 150), -208, 0))
	assert_eq(bull.hp, 100, "and a throw at its back")
	_p2.teleport(Vector2i(bull.sim_pos.x - 20, 160))
	bull.take_hit(25, _p2)
	assert_eq(bull.hp, 100, "and the partner in front")
	bull.kill(&"kill_all", _hero)
	assert_false(bull.dead, "a kill-all leaves it alive")
	bull.burst_into_items()
	assert_false(bull.dead, "a grenade too")
	for dive: int in Tuning.GLIDER_DIVE_KILLS_ON:
		bull.on_glider_stomp(_hero)
	assert_false(bull.dead, "and glider dives")
	assert_eq(bull.dive_count, 0)
	_hero.feast = 30
	assert_false(bull._shows_food(), "a feast does not show it as food ...")
	bull.kill(&"feast", _hero)
	assert_false(bull.dead, "... nor eat it")
	_hero.feast = 0
	# Braced: its back counts (one hit per strike: a bare hero's take_hit is a strike of its own).
	_crouch(_p2, Vector2i(150, 160))
	_crouch(_hero, Vector2i(150 + PartyTuning.BRACE_GAP_PX, 160))
	assert_true(_step_until(func() -> bool: return bull.coop_traits().dazed > 0, 120) > 0, "the Brace Wall stops it")
	_hero.state = Defs.HeroState.IDLE
	_hero.teleport(Vector2i(bull.sim_pos.x + 30, 160))
	bull.take_hit(25, _hero)
	assert_eq(bull.hp, 75, "staggered, its back is open")
	bull.take_hit(25, _p2)
	assert_eq(bull.hp, 50, "and its front")
	assert_false(bull.coop_traits().refuses_death(), "staggered, it can die")
	bull.burst_into_items()
	assert_true(bull.dead, "a grenade now takes it")


## An idle partner is no half of the Brace Wall, so a lone player never staggers a heavy - and never hurts it.
func test_a_lone_player_never_hurts_a_heavy_beside_his_idle_partner() -> void:
	var bull: EnemyBase = _enemy(&"enemies/walker", Vector2i(260, 160),
			{"coop": "heavy", "skin": "rex_b", "left": -10, "right": 0, "facing": "l", "hp": 25})
	_crouch(_hero, Vector2i(150, 160))
	_crouch(_p2, Vector2i(150 + PartyTuning.BRACE_GAP_PX, 160))
	_p2.idle = true
	for tick: int in 120:
		Sim.step(1)
		assert_eq(bull.coop_traits().dazed, 0, "a dozing partner braces nothing")
		if bull.sim_pos.x < 140:
			break
	assert_true(bull.sim_pos.x < 150, "it walked through them")
	_hero.state = Defs.HeroState.IDLE
	for side: int in [-30, 30]:
		_hero.teleport(Vector2i(bull.sim_pos.x + side, 160))
		bull.take_hit(25, _hero)
		bull.take_hit(25, _hero)
	assert_eq(bull.hp, 25, "front or back, every strike glances")
	assert_false(bull.dead)


## One hit per strike (the heavy-keeper ruling): a club box that overlaps a staggered heavy on several ticks of one
## swing hurts it once; the partner's swing on the same ticks is a strike of its own, a new swing (strike_tick from 1
## again) another, a thrown weapon one each. So `hp` counts strikes: hp 25 takes two club strikes. A party of one
## (the plain archetype, 1.0) takes a hit on every tick.
func test_a_staggered_heavy_takes_one_hit_per_strike() -> void:
	var bull: EnemyBase = _enemy(&"enemies/walker", Vector2i(260, 160),
			{"coop": "heavy", "skin": "rex_b", "speed": 0, "facing": "l", "hp": 100})
	Sim.step(2)
	assert_true(bull.brace_stop(_hero, _p2), "staggered by a Brace Wall")
	var p1: PlayerBase = _striker(0, Vector2i(240, 160))
	var p2: PlayerBase = _striker(1, Vector2i(280, 160))
	for tick: int in 5:
		_swing(p1, tick + 1)
		_swing(p2, tick + 1)
		assert_true(bull.take_hit(25, p1), "every tick of the swing is used up (the pogo stays)")
		assert_true(bull.take_hit(25, p2))
		Sim.step(1)
	assert_eq(bull.hp, 50, "five ticks of two swings: one hit each")
	_swing(p1, 1)
	assert_true(bull.take_hit(25, p1))
	assert_eq(bull.hp, 25, "P1's next swing is a new strike")
	Sim.step(1)
	_swing(p1, 2)
	bull.take_hit(25, p1)
	assert_eq(bull.hp, 25, "its second tick is not")
	bull.take_hit(20, _shot(Vector2i(240, 150), 208, 0))
	assert_eq(bull.hp, 5, "a throw hits once (it is used up)")
	assert_false(bull.dead)
	_swing(p2, 1)
	bull.take_hit(25, p2)
	assert_true(bull.dead, "the strike that takes it below zero kills it")
	# hp 25: two club strikes.
	var small: EnemyBase = _enemy(&"enemies/walker", Vector2i(290, 160),
			{"coop": "heavy", "skin": "rex_b", "speed": 0, "facing": "l"})
	Sim.step(1)
	small.brace_stop(_hero, _p2)
	for tick: int in 3:
		_swing(p1, tick + 1)
		small.take_hit(25, p1)
		Sim.step(1)
	assert_eq(small.hp, 0, "one strike leaves the default 25 hp at 0 ...")
	assert_false(small.dead)
	_swing(p1, 1)
	small.take_hit(25, p1)
	assert_true(small.dead, "... the second kills")
	# A party of one: the plain walker takes a hit on every tick of a swing (1.0).
	var plain: EnemyBase = _enemy(&"enemies/walker", Vector2i(200, 160),
			{"coop": "heavy", "speed": 0, "facing": "l", "hp": 100})
	Sim.step(1)
	_p2.free()
	for tick: int in 3:
		_swing(p1, tick + 1)
		plain.take_hit(25, p1)
		Sim.step(1)
	assert_eq(plain.hp, 25, "a party of one: three ticks, three hits")
	p1.free()
	p2.free()


## G57 (2): in a co-op party EVERY enemy - with a trait or without - takes one hit per strike: one club swing held
## over a 100-hp walker for 6 ticks takes 25, two swings 50; the back of a `shell` record the same. In single-player
## (and versus) the 1.0 hit lands on every tick a box overlaps.
func test_every_coop_enemy_takes_one_hit_per_strike_and_solo_keeps_the_tick_hit() -> void:
	var plain: EnemyBase = _enemy(&"enemies/walker", Vector2i(220, 160), {"speed": 0, "hp": 100})
	var shell: EnemyBase = _enemy(&"enemies/walker", Vector2i(160, 160), {"coop": "shell", "speed": 0, "hp": 100})
	_hero.teleport(Vector2i(130, 160))
	_p2.teleport(Vector2i(400, 160))
	Sim.step(2)
	assert_null(plain.coop_traits(), "a plain 1.0 record")
	assert_eq(shell.facing, -1)
	var p1: PlayerBase = _striker(0, Vector2i(200, 160))
	var p2: PlayerBase = _striker(1, Vector2i(190, 160))
	for tick: int in 6:
		_swing(p1, tick + 1)
		_swing(p2, tick + 1)
		plain.take_hit(25, p1)
		shell.take_hit(25, p2)
		Sim.step(1)
	assert_eq(plain.hp, 75, "one swing held over it for 6 ticks: 25")
	assert_eq(shell.hp, 75, "a shell's back: one hit for the swing too")
	for tick: int in 6:
		_swing(p1, tick + 1)
		plain.take_hit(25, p1)
		Sim.step(1)
	assert_eq(plain.hp, 50, "two swings: 50")
	# The repeat ticks are used up (one target per box per tick, as in 1.0): the box does not go on to an enemy behind.
	var front: EnemyBase = _enemy(&"enemies/walker", Vector2i(250, 160), {"speed": 0, "hp": 100})
	var behind: EnemyBase = _enemy(&"enemies/walker", Vector2i(256, 160), {"speed": 0, "hp": 100})
	Sim.step(1)
	for tick: int in 3:
		_swing(p1, tick + 1)
		assert_true(front.take_hit(25, p1) or behind.take_hit(25, p1), "tick %d: the box is used up" % tick)
		Sim.step(1)
	assert_eq([front.hp, behind.hp], [75, 100], "one swing over two enemies: the front one, once")
	# A party of one (the co-op rules collapse) and single-player: the 1.0 per-tick hit.
	_p2.free()
	for tick: int in 3:
		_swing(p1, tick + 1)
		plain.take_hit(25, p1)
		Sim.step(1)
	assert_eq(plain.hp, -25, "a party of one: three ticks, three hits (dead)")
	assert_true(plain.dead)
	Game.new_game(Defs.Difficulty.BEGINNER)
	assert_eq(Game.mode, Defs.GameMode.SINGLE)
	var solo: EnemyBase = _enemy(&"enemies/walker", Vector2i(240, 160), {"speed": 0, "hp": 100})
	Sim.step(1)
	for tick: int in 3:
		_swing(p1, tick + 1)
		solo.take_hit(25, p1)
		Sim.step(1)
	assert_eq(solo.hp, 25, "single-player: every tick of a swing hits (1.0)")
	assert_true(solo._strike_keys.is_empty(), "no strike memory outside a co-op party")
	p1.free()
	p2.free()


## End to end with the real hero (scenes/player/player.tscn: his strike script, his club boxes, his weapon pass) - the
## G3 verifier's solo attacks on a keeper end with one hero behind the Bull Rex (it charged under his jump, or it runs
## at his dozing partner - the idle bait) clubbing its BACK. Here it runs at the dozing P2 with P1 right behind its
## tail: every box tick of his swings reaches it and glances (G57: no Brace Wall, no damage). Alone in the level (a
## party of one: the plain charger, hit anywhere on every tick) the same swing kills it - so the glances were real hits.
func test_the_real_heros_swings_at_a_bull_rexs_back_glance_and_alone_they_kill() -> void:
	for party: bool in [true, false]:
		_party_flat()
		var hero: PlayerBase = _real_hero(Vector2i(200, 160), 0)
		var rex: EnemyBase = _enemy(&"enemies/bull_rex", Vector2i(260, 160), {"speed": 16})
		# Its tail 3 px in front of P1's body, inside his forward club box ...
		rex.sim_pos.x = hero.sim_pos.x - hero.box_xo + hero.box_w + 3 + rex.box_xo
		if party:
			# ... and the dozing partner before its nose, a little nearer to it than P1: it wakes and runs at him.
			_p2.teleport(Vector2i(2 * rex.sim_pos.x - hero.sim_pos.x - 2, 160))
			_p2.idle = true
		else:
			_p2.free()
		var hearts: int = hero.run.hearts
		var sparks: int = _count_fx(&"fx/hit_stars")
		var hits: int = 0
		var last_hit: int = rex.last_hit_tick
		GameInput.set_scripted_slot(0, func(_tick: int) -> int: return Defs.IN_FIRE)
		for tick: int in 12:
			Sim.step(1)
			assert_eq(CoopTraits.party_on(), party)
			if rex.dead:
				break
			if party:
				assert_eq(rex.facing, 1, "tick %d: it runs at the dozing partner, its back to P1" % tick)
				assert_false(rex._hit_from_front(hero), "P1 stands behind it")
				assert_eq(rex.coop_traits().dazed, 0, "a dozing partner braces nothing")
			if rex.last_hit_tick != last_hit:
				last_hit = rex.last_hit_tick
				hits += 1
		GameInput.clear_scripted()
		if party:
			assert_eq(hero.run.hearts, hearts, "it never touched P1")
			assert_true(hits >= 3, "a swing and a half held on its back: %d box ticks reached it" % hits)
			assert_eq(rex.last_hit_slot, 0)
			assert_eq(rex.hp, rex.max_hp, "a lone player's blows at a heavy's back glance: no Brace Wall, no damage")
			assert_false(rex.dead)
			assert_true(_count_fx(&"fx/hit_stars") > sparks, "with the glance's spark")
		else:
			assert_true(rex.dead, "a party of one: the plain charger falls to that swing (%d box ticks)" % hits)


## End to end, the pair's side (w3_l1_coop 'lake', hp 100): two real heroes crouch side by side in the keeper's path,
## the Brace Wall stops and dazes it, neither is touched; P1 rises and swings while P2 keeps crouching. Each swing
## lands ONCE (the 1.0 test landed it on every tick its box overlapped: the first swing alone took 100 hp below zero) -
## the crouch-charged first swing takes its 100 hp to 0 and the next one kills it, inside the 44-tick daze.
func test_the_real_pair_braces_the_keeper_and_each_swing_counts_once() -> void:
	var p1: PlayerBase = _real_hero(Vector2i(200, 160), 0)
	_p2.free()
	_p2 = _real_hero(Vector2i(200 + PartyTuning.BRACE_GAP_PX - 4, 160), 1)
	var rex: EnemyBase = _enemy(&"enemies/bull_rex", Vector2i(310, 160), {"hp": 100})
	var hearts: Array[int] = [p1.run.hearts, _p2.run.hearts]
	var keys: Array[int] = [Defs.IN_DOWN, Defs.IN_DOWN]
	GameInput.set_scripted_slot(0, func(_tick: int) -> int: return keys[0])
	GameInput.set_scripted_slot(1, func(_tick: int) -> int: return keys[1])
	assert_true(_step_until(func() -> bool: return rex.coop_traits().dazed > 0, 120) > 0, "the Brace Wall stops it")
	assert_eq([p1.run.hearts, _p2.run.hearts], hearts, "neither hero is touched")
	assert_false(p1.is_idle() or _p2.is_idle(), "held keys are input: both count")
	var daze_left: int = rex.coop_traits().dazed
	# P1 rises into a forward swing (FIRE held for the 7 ticks of the strike script), P2 holds the crouch.
	keys[0] = Defs.IN_FIRE
	Sim.step(Tuning.STRIKE_SCRIPT_FORWARD.size())
	keys[0] = 0
	Sim.step(3)
	assert_eq(rex.hp, 0, "the charged swing (x4) took 100 - once, although its box stayed on the keeper for ticks")
	assert_false(rex.dead, "0 hp is not below zero")
	keys[0] = Defs.IN_FIRE
	Sim.step(Tuning.STRIKE_SCRIPT_FORWARD.size())
	keys[0] = 0
	Sim.step(2)
	GameInput.clear_scripted()
	assert_true(rex.dead, "the second swing kills it")
	assert_true(2 * Tuning.STRIKE_SCRIPT_FORWARD.size() + 5 < daze_left, "both swings fit one %d-tick daze" % daze_left)
	assert_eq([p1.run.hearts, _p2.run.hearts], hearts)


## The real hero (scenes/player/player.tscn) of `slot` at `pos`; for slot 0 it replaces the bare P1 of the fixture.
func _real_hero(pos: Vector2i, slot: int) -> PlayerBase:
	if slot == 0 and _hero != null and is_instance_valid(_hero):
		_hero.free()
	var hero: PlayerBase = (load(PLAYER_SCENE) as PackedScene).instantiate() as PlayerBase
	place(_level, hero, pos, {"slot": slot})
	hero.respawn_at(pos)
	if slot == 0:
		_hero = hero
	return hero


# =================================================================================================================
# lone
# =================================================================================================================

func test_lone_keeps_away_from_heroes_together_and_hunts_the_straggler() -> void:
	Game.difficulty = Defs.Difficulty.EXPERT
	var stinger: EnemyBase = _enemy(&"enemies/stinger", Vector2i(160, 100), {"coop": "lone"})
	_hero.teleport(Vector2i(150, 160))
	_p2.teleport(Vector2i(150 + PartyTuning.LONE_KEEP_AWAY_PX, 160))
	Sim.step(10)
	assert_null(stinger._target_hero(), "heroes within 64 px of each other: it keeps away")
	assert_eq(stinger.sim_pos, Vector2i(160, 100), "no dive")
	_p2.teleport(Vector2i(300, 160))
	assert_eq(stinger._target_hero(), _p2, "the straggler: the hero farther from the view centre")
	_hero.teleport(Vector2i(100, 160))
	_p2.teleport(Vector2i(220, 160))
	assert_eq(stinger._target_hero(), _p2, "a tie goes to the higher slot")
	_p2.down = true
	assert_eq(stinger._target_hero(), _hero, "one hatched hero: him")
	_p2.down = false
	Game.difficulty = Defs.Difficulty.BEGINNER
	_hero.teleport(Vector2i(150, 160))
	_p2.teleport(Vector2i(170, 160))
	assert_eq(stinger._target_hero(), _hero, "Beginner: plain (nearest) targeting")


func test_a_lone_spawner_rises_only_around_the_straggler() -> void:
	Game.difficulty = Defs.Difficulty.EXPERT
	var digger: SpawnerEnemy = _enemy(&"enemies/digger", Vector2i(200, 160),
			{"coop": "lone", "zone": "0,0,40,16", "pause": 0}) as SpawnerEnemy
	_hero.teleport(Vector2i(150, 160))
	_p2.teleport(Vector2i(170, 160))
	Sim.step(20)
	assert_eq(digger.alive_copies(), 0, "nothing rises beside heroes who keep together")
	_p2.teleport(Vector2i(400, 160))
	Sim.step(20)
	assert_eq(digger.alive_copies(), 1, "the straggler is hunted")


# =================================================================================================================
# grab
# =================================================================================================================

func test_grab_seizes_a_hero_from_below_and_his_partner_frees_him() -> void:
	var bat: EnemyBase = _grabber(Vector2i(160, 140))
	_hero.teleport(Vector2i(160, 160))
	_p2.teleport(Vector2i(260, 160))
	Sim.step(2)
	var traits: CoopTraits = bat.coop_traits()
	assert_eq(traits.held, _hero, "P1 touched it from below: seized instead of hurt")
	assert_false(_hero.control_enabled, "he cannot move or strike")
	assert_eq(_hero.sim_pos, bat.sim_pos + Vector2i(0, EnemyTuning.GRAB_HANG_DY), "he hangs under it")
	assert_false(bat.contact_hurts)
	assert_eq(Game.hearts, Tuning.ENERGY_START, "no damage")
	Sim.step(10)
	assert_eq(bat.sim_pos, Vector2i(170, 130), "carried towards the perch at 1 px per tick")
	assert_eq(_hero.sim_pos, Vector2i(170, 130 + EnemyTuning.GRAB_HANG_DY))
	_hero.club_box_active = true
	Sim.step(1)
	assert_false(_hero.club_box_active, "a grabbed hero's strike is cancelled")
	bat.take_hit(25, _hero)
	assert_eq(traits.held, _hero, "his own throws do not free him")
	assert_true(bat.take_hit(25, _p2))
	assert_null(traits.held, "the partner's hit frees him ...")
	assert_eq(bat.hp, 100 - 50, "... and counts")
	assert_true(_hero.control_enabled)
	assert_eq(_hero.shield, EnemyTuning.GRAB_FREE_SHIELD_TICKS, "he falls with 44 ticks of immunity")
	assert_true(bat.contact_hurts)
	var home: Vector2i = Vector2i(160, 140)
	_step_until(func() -> bool: return bat.sim_pos == home, 40)
	assert_eq(bat.sim_pos, home, "it flies back to where it seized him")


func test_grab_drops_its_catch_at_the_perch() -> void:
	var bat: EnemyBase = _grabber(Vector2i(160, 140))
	_hero.teleport(Vector2i(40, 160))
	_p2.teleport(Vector2i(160, 125))
	Sim.step(3)
	assert_null(bat.coop_traits().held, "a hero above its feet point is not seized")
	_p2.teleport(Vector2i(300, 160))
	_hero.teleport(Vector2i(160, 160))
	Sim.step(1)
	assert_eq(bat.coop_traits().held, _hero)
	var perch: Vector2i = bat.coop_traits().perch
	assert_eq(perch, LevelText.cell_to_feet(15, 6))
	var dropped: int = _step_until(func() -> bool: return bat.coop_traits().held == null, 200)
	assert_true(dropped > 0)
	assert_eq(bat.sim_pos, perch, "dropped at the perch")
	assert_true(_hero.control_enabled)
	assert_eq(_hero.shield, 0, "no immunity for a drop")


# =================================================================================================================
# leech
# =================================================================================================================

func test_a_leech_rides_drains_and_only_the_partner_clubs_it_off() -> void:
	var leech: EnemyBase = _leech(Vector2i(200, 160))
	_hero.teleport(Vector2i(190, 160))
	_hero.facing = 1
	_p2.teleport(Vector2i(300, 160))
	var latched: int = _step_until(func() -> bool: return leech.coop_traits().host == _hero, 40)
	assert_true(latched > 0, "it lands on P1's back")
	assert_false(leech.contact_hurts, "instead of hurting him")
	assert_eq(leech.sim_pos, _hero.sim_pos + Vector2i(-EnemyTuning.LEECH_BACK_DX, -EnemyTuning.LEECH_BACK_DY))
	_hero.teleport(Vector2i(240, 160))
	Sim.step(1)
	assert_eq(leech.sim_pos.x, 240 - EnemyTuning.LEECH_BACK_DX, "it rides along")
	assert_false(leech.take_hit(25, _hero), "his own weapons pass through it")
	assert_eq(leech.hp, 100)
	var energy: int = Game.hearts * Tuning.BONES_PER_HEART + Game.bones
	var drained: int = _step_until(func() -> bool:
		return Game.hearts * Tuning.BONES_PER_HEART + Game.bones < energy, PartyTuning.LEECH_DRAIN_TICKS + 2)
	assert_true(drained > 0, "one bone every 44 ticks")
	assert_eq(Game.hearts * Tuning.BONES_PER_HEART + Game.bones, energy - 1)
	assert_eq(Game.runs[1].hearts, Tuning.ENERGY_START, "only the host's")
	assert_true(leech.take_hit(25, _p2))
	assert_null(leech.coop_traits().host, "the partner clubs it off")
	assert_eq(leech.hp, 75, "and the hit counts")
	assert_true(leech.contact_hurts)


func test_helper_mode_spares_p2_the_leech_and_the_grab() -> void:
	Game.helper_mode = true
	assert_true(_p2.is_helper() and not _hero.is_helper(), "Helper mode: P2 of a co-op run")
	var leech: EnemyBase = _leech(Vector2i(200, 160))
	var bat: EnemyBase = _grabber(Vector2i(400, 140))
	_hero.teleport(Vector2i(40, 160))
	_p2.teleport(Vector2i(190, 160))
	_p2.facing = 1
	Sim.step(20)
	assert_null(leech.coop_traits().host, "no leech on the helper's back")
	_p2.teleport(Vector2i(400, 160))
	Sim.step(3)
	assert_null(bat.coop_traits().held, "the helper is never seized")
	assert_true(_p2.control_enabled)
	_hero.teleport(Vector2i(190, 160))
	_hero.facing = 1
	_p2.teleport(Vector2i(40, 160))
	var latched: int = _step_until(func() -> bool: return leech.coop_traits().host == _hero, 40)
	assert_true(latched > 0, "P1 is no helper: it lands on his back")
	Game.helper_mode = false


func test_alone_a_leech_falls_off_after_220_ticks() -> void:
	var leech: EnemyBase = _leech(Vector2i(200, 160))
	_hero.teleport(Vector2i(190, 160))
	_p2.teleport(Vector2i(300, 160))
	_step_until(func() -> bool: return leech.coop_traits().host == _hero, 40)
	assert_eq(leech.coop_traits().host, _hero)
	Sim.step(PartyTuning.LEECH_FALL_OFF_TICKS - 1)
	assert_eq(leech.coop_traits().host, _hero)
	Sim.step(1)
	assert_null(leech.coop_traits().host, "it falls off by itself")
	Sim.step(EnemyTuning.LEECH_RELATCH_TICKS - 1)
	assert_null(leech.coop_traits().host, "and does not jump straight back on")
	assert_eq(Game.hearts * Tuning.BONES_PER_HEART + Game.bones,
			Tuning.ENERGY_START * Tuning.BONES_PER_HEART - PartyTuning.LEECH_FALL_OFF_TICKS / PartyTuning.LEECH_DRAIN_TICKS)


# =================================================================================================================
# split
# =================================================================================================================

func test_split_halves_run_apart_and_must_both_die_within_the_window() -> void:
	var blob: EnemyBase = _splitter(Vector2i(200, 160))
	_hero.teleport(Vector2i(150, 160))
	_p2.teleport(Vector2i(250, 160))
	Sim.step(2)
	assert_true(blob.take_hit(25, _hero))
	assert_eq(blob.hp, 0, "the first hit splits it without damage ...")
	var copy: EnemyBase = blob.coop_traits().mate
	assert_not_null(copy, "... into two halves")
	assert_eq(copy.hp, 0, "of 0 hit points each")
	assert_true(copy.coop_traits().is_copy)
	assert_eq(copy.coop_traits().mate, blob)
	assert_eq(_of_scene(Defs.Kind.ENEMY, &"enemies/walker").size(), 2)
	Sim.step(EnemyTuning.SPLIT_RUN_TICKS)
	var apart: int = blob.sim_pos.x - copy.sim_pos.x
	assert_eq(apart, 2 * EnemyTuning.SPLIT_RUN_TICKS * Tuning.floor16(EnemyTuning.SPLIT_RUN_XVEL),
			"they ran apart at 48 v16 for 22 ticks (away from the hitter first)")
	blob.take_hit(25, _p2)
	assert_true(blob.dead, "a half dies to any hit")
	Sim.step(CoopTraits.window_ticks() - 1)
	copy.take_hit(25, _hero)
	assert_true(copy.dead)
	assert_true(blob.coop_traits().sealed and copy.coop_traits().sealed, "both within the window")
	Sim.step(60)
	assert_true(blob.dead and copy.dead, "they stay dead")


func test_a_late_split_merges_back_into_the_whole() -> void:
	var blob: EnemyBase = _splitter(Vector2i(200, 160))
	_hero.teleport(Vector2i(150, 160))
	_p2.teleport(Vector2i(250, 160))
	Sim.step(2)
	blob.take_hit(25, _hero)
	var copy: EnemyBase = blob.coop_traits().mate
	Sim.step(EnemyTuning.SPLIT_RUN_TICKS)
	blob.take_hit(25, _hero)
	assert_true(blob.dead)
	Sim.step(CoopTraits.window_ticks() - 1)
	var meeting: Vector2i = copy.sim_pos
	Sim.step(1)
	assert_false(blob.dead, "the dead half regrows next to the living one ...")
	assert_eq(blob.sim_pos, meeting, "... where the living half stood")
	assert_eq(blob.hp, blob.max_hp, "merged into the whole")
	assert_eq(blob.coop_traits().split, CoopTraits.Split.WHOLE)
	assert_true(copy.dead and not copy.sim_active, "the spawned half is gone")
	blob.take_hit(25, _p2)
	assert_eq(blob.hp, 0, "whole again, the next hit splits it again")
	assert_not_null(blob.coop_traits().mate)


func test_a_team_wipe_removes_the_spawned_half() -> void:
	var blob: EnemyBase = _splitter(Vector2i(200, 160))
	_hero.teleport(Vector2i(150, 160))
	_p2.teleport(Vector2i(250, 160))
	Sim.step(2)
	blob.take_hit(25, _hero)
	var copy: EnemyBase = blob.coop_traits().mate
	Sim.step(5)
	_level.reset_entities()
	assert_true(copy.dead and not copy.sim_active, "the copy leaves the level")
	assert_eq(blob.hp, blob.max_hp)
	assert_eq(blob.coop_traits().split, CoopTraits.Split.WHOLE)
	assert_null(blob.coop_traits().mate)
	assert_eq(blob.sim_pos, blob.spawn_pos)


# =================================================================================================================
# The record file
# =================================================================================================================

func test_the_trait_gallery_level_carries_every_trait() -> void:
	var records: Array[EnemyBase] = _load_records(COOP_LEVEL)
	var traits: Dictionary = {}
	for record: EnemyBase in records:
		var rules: CoopTraits = record.coop_traits()
		assert_not_null(rules, "%s carries a trait" % record.name)
		if rules != null:
			traits[rules.kind] = int(traits.get(rules.kind, 0)) + 1
	for value: int in range(1, Defs.CoopTrait.size()):
		assert_true(traits.has(value), "trait %s is in the gallery" % Defs.coop_trait_name(value))
	assert_eq(traits.get(Defs.CoopTrait.BOND, 0), 2, "the bond is a pair")
	assert_eq(CoopTraits.bond_members(_level, &"twins").size(), 2)
	assert_eq(_level.get_tagged(&"keeper", &"gully").size(), 1, "the Shellback keeps the gully")
	for record: EnemyBase in records:
		if record.coop_traits() != null and record.coop_traits().kind == Defs.CoopTrait.GRAB:
			assert_true(record.coop_traits().has_perch, "the grabber has its perch")
			assert_eq(record.coop_traits().perch, LevelText.cell_to_feet(78, 9))
	assert_eq(_level.grid.get_char(78, 12), TileGrid.CH_LIQUID, "over the pit")
	Sim.step(30)
	for record: EnemyBase in records:
		assert_false(record.dead, "%s lives" % record.name)


# =================================================================================================================
# The bosses meet both heroes (P0.6 conversion) and play solo exactly as before
# =================================================================================================================

func test_the_brute_meets_both_heroes() -> void:
	var brute: Brute = _brute()
	_hero.teleport(Vector2i(40, 160))
	_p2.teleport(Vector2i(300, 160))
	Sim.step(1)
	assert_true(brute.fighting, "P2 within 250 px starts the fight")
	_p2.teleport(Vector2i(brute.sim_pos.x - 20, 160))
	Sim.step(1)
	assert_eq([Game.runs[1].hearts, Game.runs[1].bones], [Tuning.ENERGY_START - 1, Tuning.BONES_PER_HEART - 1],
			"the body costs P2 a bone")
	assert_eq(_p2.hit_timer, Tuning.HIT_TIMER)
	assert_eq([Game.hearts, Game.bones], [Tuning.ENERGY_START, 0], "P1 untouched")
	_hero.teleport(Vector2i(brute.sim_pos.x, brute.sim_pos.y - brute.box_h + 6))
	_hero.yvel = 64
	Sim.step(1)
	assert_eq(_hero.yvel, Tuning.BOSS_BOUNCE_YVEL, "P1 bounces on its head")
	assert_eq([Game.hearts, Game.bones], [Tuning.ENERGY_START, 0], "without damage")
	_hero.teleport(Vector2i(40, 160))
	_p2.club_box_active = true
	_p2.club_box = brute.get_head_rect()
	_p2.club_power = 25
	Sim.step(1)
	assert_eq(brute.hp, EnemyTuning.BRUTE_HP - 25, "P2's club on the head counts")
	assert_eq(brute.last_hitter, _p2)
	assert_eq(brute.last_hit_slot, 1)
	_p2.club_box_active = false


func test_a_striking_partner_angers_the_brute() -> void:
	var brute: Brute = _brute()
	_p2.teleport(Vector2i(330, 160))
	_hero.teleport(Vector2i(290, 160))
	_hero.attack_gate = true
	var ticks: int = _step_until(func() -> bool: return brute.get_state() == Brute.State.JUMP, 200)
	assert_eq(brute.get_anger(), 4)
	assert_eq(ticks, 4 * (EnemyTuning.BRUTE_ANGER_PERIOD_MASK + 1),
			"P1 swings, P2 is its target: the anger rises as in single-player")


func test_the_colossus_meets_both_heroes() -> void:
	var colossus: Colossus = _colossus()
	_hero.teleport(Vector2i(40, 160))
	_p2.teleport(Vector2i(100, 160))
	Sim.step(1)
	assert_true(colossus.fighting, "P2 close to the statue wakes it")
	var axe: ProjectileBase = _shot(Vector2i(colossus.get_head_rect().get_center().x,
			colossus.get_head_rect().end.y), 0, 1)
	Sim.step(1)
	assert_true(axe.spent)
	assert_eq(colossus.hp, EnemyTuning.COLOSSUS_HP - 1, "P2's throw counts one point")
	assert_eq(colossus.last_hitter, _p2)
	_p2.teleport(Vector2i(colossus.sim_pos.x - 52, 160))
	Sim.step(1)
	assert_eq(Game.runs[1].hearts, Tuning.ENERGY_START - 1, "the statue's body costs P2 a bone")
	assert_eq(Game.hearts, Tuning.ENERGY_START)
	var rock: ProjectileBase = _spawn(&"projectiles/boss_rock", Vector2i(44, 160), {"xvel": -16}) as ProjectileBase
	_hero.teleport(Vector2i(44, 160))
	_p2.teleport(Vector2i(150, 160))
	Sim.step(1)
	assert_true(rock.spent)
	assert_eq(Game.hearts, Tuning.ENERGY_START - 1, "a rock hurts P1 as well")


func test_a_downed_partner_changes_nothing_for_the_brute() -> void:
	var solo: PackedStringArray = _brute_trace(false)
	var party: PackedStringArray = _brute_trace(true)
	assert_true(solo.size() == 400)
	assert_eq(party, solo, "the Brute fights P1 alone exactly as in single-player while P2 is an egg")


func test_a_downed_partner_changes_nothing_for_the_colossus() -> void:
	var solo: PackedStringArray = _colossus_trace(false)
	var party: PackedStringArray = _colossus_trace(true)
	assert_true(solo.size() == 400)
	assert_eq(party, solo, "the Colossus fights P1 alone exactly as in single-player while P2 is an egg")


# =================================================================================================================
# Helpers
# =================================================================================================================

## A flat level (60 x 16 tiles, floor at row 10) with P1 at (40, 160) and P2 at (100, 160).
func _party_flat() -> void:
	_flat_level(60, 16, 10)
	_p2 = _add_p2(Vector2i(100, 160))


func _add_p2(pos: Vector2i) -> PlayerBase:
	var p2: PlayerBase = PlayerBase.new()
	place(_level, p2, pos, {"slot": 1})
	p2.respawn_at(pos)
	return p2


func _bonded(pos: Vector2i) -> EnemyBase:
	return _enemy(&"enemies/walker", pos, {"coop": "bond", "bond": "twins", "speed": 0})


func _raptor(pos: Vector2i) -> EnemyBase:
	return _enemy(&"enemies/hopper", pos, {"coop": "daze", "skin": "mini_rex_b", "range": 0, "hp": 100})


func _grabber(pos: Vector2i) -> EnemyBase:
	return _enemy(&"enemies/dangler", pos, {"coop": "grab", "skin": "bat_b", "depth": 0, "perch": "15,6", "hp": 100})


func _leech(pos: Vector2i) -> EnemyBase:
	return _enemy(&"enemies/lurker", pos, {"coop": "leech", "pause": 0, "hp": 100})


func _splitter(pos: Vector2i) -> EnemyBase:
	return _enemy(&"enemies/walker", pos, {"coop": "split", "speed": 0})


func _crouch(hero: PlayerBase, pos: Vector2i) -> void:
	hero.teleport(pos)
	hero.state = Defs.HeroState.CROUCH
	hero.grounded = true
	hero.set_box(Tuning.HERO_BOX_CROUCH)


## A bare hero with the strike-script counter of player-A's Player (`strike_tick`, read by CoopTraits.strike_key);
## never in the tree (the caller frees it).
class Striker:
	extends PlayerBase

	var strike_tick: int = 0


func _striker(p_slot: int, pos: Vector2i) -> PlayerBase:
	var striker: Striker = Striker.new()
	striker.slot = p_slot
	striker.sim_pos = pos
	return striker


## `hero` tests a club box in this tick's weapon pass, `into` ticks into his strike script.
func _swing(hero: PlayerBase, into: int) -> void:
	hero.club_box_active = true
	hero.set(&"strike_tick", into)


## A thrown weapon of the hero of `owner` at `pos` flying with `p_xvel`.
func _shot(pos: Vector2i, p_xvel: int, owner: int) -> ProjectileBase:
	var shot: ProjectileBase = ProjectileBase.new()
	place(_level, shot, pos, {"from_hero": true, "power": 20, "xvel": p_xvel, "owner": owner})
	return shot


## Step until `done` holds (at most `max_ticks`); the tick it held on, or -1.
func _step_until(done: Callable, max_ticks: int) -> int:
	for tick: int in max_ticks:
		Sim.step(1)
		if done.call():
			return tick + 1
	return -1


func _count_fx(id: StringName) -> int:
	var count: int = 0
	for entity: SimEntity in _level.get_kind(Defs.Kind.FX):
		if entity.scene_file_path.get_file().get_basename() == String(id).get_file():
			count += 1
	return count


func _brute() -> Brute:
	return _enemy(&"bosses/brute", Vector2i(400, 160), {"arena": "pit", "left": 20, "right": 30}) as Brute


## The Colossus room of test_enemies_bosses.gd (a wall from column 20), with both heroes.
func _colossus() -> Colossus:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 10:
		rows.append(".".repeat(20) + "#".repeat(10))
	rows.append("#".repeat(30))
	_rows_level(rows)
	_p2 = _add_p2(Vector2i(100, 160))
	return _enemy(&"bosses/colossus", Vector2i(19 * Tuning.TILE + 8, 160)) as Colossus


## Records of a level file spawned into a bare level of its tiles (the legend letters of [tiles] and the [entities]
## lines; enemies only), with P1 at '@' and P2 beside him.
func _load_records(path: String) -> Array[EnemyBase]:
	var sections: Dictionary = LevelText.split_sections(FileAccess.get_file_as_string(path))
	var legend: Dictionary = LevelText.parse_legend(sections.get("legend", PackedStringArray()))
	var rows: PackedStringArray = sections.get("tiles", PackedStringArray())
	_rows_level(rows)
	var records: Array[EnemyBase] = []
	for row: int in rows.size():
		for col: int in rows[row].length():
			var key: String = rows[row][col]
			if key == TileGrid.CH_PLAYER_START:
				_hero.teleport(LevelText.cell_to_feet(col, row))
			if not legend.has(key):
				continue
			var entry: Dictionary = legend[key]
			if Spawner.category(entry["id"]) != "enemies":
				continue
			var params: Dictionary = (entry["params"] as Dictionary).duplicate()
			records.append(_enemy(entry["id"], LevelText.cell_to_feet(col, row, params), params))
	_p2 = _add_p2(_hero.sim_pos + Vector2i(-PartyTuning.RESPAWN_SPREAD_PX, 0))
	_level.view = Rect2i(0, 0, rows[0].length() * Tuning.TILE, rows.size() * Tuning.TILE)
	return records


## 400 ticks of a Brute fight against P1, who strikes now and then and lands a head hit every 60 ticks; with
## `egg_partner` a co-op game where P2 is an egg standing in the Brute. One line per tick.
func _brute_trace(egg_partner: bool) -> PackedStringArray:
	_trace_game(egg_partner)
	var brute: Brute = _brute()
	var egg: PlayerBase = _trace_egg(egg_partner, Vector2i(400, 160))
	_hero.teleport(Vector2i(300, 160))
	var lines: PackedStringArray = PackedStringArray()
	for tick: int in 400:
		_hero.attack_gate = (tick / 20) % 3 == 0
		_hero.club_box_active = tick % 60 == 59
		if _hero.club_box_active:
			_hero.club_box = brute.get_head_rect()
			_hero.club_power = 25
		if tick % 90 == 45:
			_hero.teleport(Vector2i(brute.sim_pos.x - 30, 160))
			_hero.hit_timer = 0
		if egg != null:
			egg.teleport(brute.sim_pos)
		Sim.step(1)
		lines.append("%d %s %d %d %d %d %d %d" % [tick, brute.sim_pos, brute.get_state(), brute.hp, brute.get_anger(),
				Game.hearts, Game.bones, _hero.yvel])
	return lines


## 400 ticks of the Colossus against P1 throwing at its head every 50 ticks (P2 an egg in front of it).
func _colossus_trace(egg_partner: bool) -> PackedStringArray:
	_trace_game(egg_partner)
	var colossus: Colossus = _colossus()
	if not egg_partner:
		_p2.free()
		_p2 = null
	var egg: PlayerBase = _trace_egg(egg_partner, Vector2i(220, 160))
	_hero.teleport(Vector2i(150, 160))
	var lines: PackedStringArray = PackedStringArray()
	for tick: int in 400:
		if tick % 50 == 25:
			_shot(Vector2i(colossus.get_head_rect().get_center().x, colossus.get_head_rect().end.y), 0, 0)
		if egg != null:
			egg.teleport(Vector2i(colossus.box_left() + 8, 160))
		Sim.step(1)
		var shots: int = _level.get_kind(Defs.Kind.ENEMY_PROJECTILE).size()
		lines.append("%d %d %d %d %d %d %d" % [tick, colossus.get_state(), colossus.hp, colossus.get_hits(), shots,
				Game.hearts, Game.bones])
	return lines


func _trace_game(egg_partner: bool) -> void:
	if egg_partner:
		Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	else:
		Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"test")
	Sim.rng.reseed(7)
	_flat_level(60, 16, 10)  # frees the level of the previous trace (its boss must not tick on)
	_p2 = null


## P2 as an egg at `pos` (co-op), or nobody.
func _trace_egg(egg_partner: bool, pos: Vector2i) -> PlayerBase:
	if not egg_partner:
		return null
	if _p2 == null or not is_instance_valid(_p2):
		_p2 = _add_p2(pos)
	_p2.teleport(pos)
	_p2.down = true
	return _p2


# =================================================================================================================
# R2: the windows are slot-bound (bond, split, the twin drums)
# =================================================================================================================

## R2: a bond is met only by deaths credited to two DIFFERENT heroes. One hero kills one member; while it lies dead
## his hits on the other glance - whatever their gap - and nothing else of his kills it; his partner's hit does, and
## the bond seals.
func test_a_bond_is_met_only_by_two_different_heroes() -> void:
	var a: EnemyBase = _bonded(Vector2i(60, 160))
	var b: EnemyBase = _bonded(Vector2i(280, 160))
	Sim.step(2)
	assert_true(b.take_hit(10, _hero))
	assert_eq(b.hp, 15, "no window open: any hero who counts hurts a member")
	assert_true(a.take_hit(100, _hero))
	assert_true(a.dead, "P1 kills the first")
	assert_eq(a.coop_traits().kill_slot, 0, "credited to his slot")
	var sparks: int = _count_fx(&"fx/hit_stars")
	for gap: int in [0, 1, CoopTraits.window_ticks() - 2]:
		Sim.step(gap)
		assert_true(b.take_hit(100, _hero), "his hit on the other is used up ...")
		assert_eq(b.hp, 15, "... and glances")
		assert_false(b.dead)
	assert_eq(b.coop_traits().slot_refusals, 3)
	assert_true(_count_fx(&"fx/hit_stars") > sparks, "with the glance's spark")
	b.kill(&"weapon", _hero)
	assert_false(b.dead, "nor does a kill of his own slot go through")
	assert_true(b.take_hit(100, _p2), "his partner's hit, still inside the window")
	assert_true(b.dead)
	assert_eq(b.coop_traits().kill_slot, 1)
	assert_true(a.coop_traits().sealed and b.coop_traits().sealed, "two different slots: the bond is met")
	assert_true(CoopTraits.bond_done(_level, &"twins"))
	# One hero alone, striking at both on every tick: the dead member regrows when its window closes and he may
	# then kill the other - never both.
	_level.reset_entities()
	Sim.step(2)
	var kills: Array[int] = [0, 0]
	var both_dead: int = 0
	for tick: int in 200:
		for n: int in 2:
			var member: EnemyBase = [a, b][n]
			var was_dead: bool = member.dead
			member.take_hit(100, _hero)
			if member.dead and not was_dead:
				kills[n] += 1
		if (a.dead and b.dead) or CoopTraits.bond_done(_level, &"twins"):
			both_dead += 1
		Sim.step(1)
	assert_true(kills[0] >= 2 and kills[1] >= 2, "he killed each several times (%s)" % str(kills))
	assert_eq(both_dead, 0, "and never had both members dead")
	assert_false(a.coop_traits().sealed or b.coop_traits().sealed)


## R2: a hit credited to a hero who does not COUNT - idle, an egg, down - counts for nobody: it glances off a bond
## member, his thrown weapon and his ball too. A batted ball is credited to the BALL, not to his batter: a lone hero
## who bats his idle partner into a member has not found a second slot, and a pair's Batter Up has.
func test_a_hit_of_an_idle_hero_an_egg_or_a_downed_hero_counts_for_nobody() -> void:
	var a: EnemyBase = _bonded(Vector2i(60, 160))
	var b: EnemyBase = _bonded(Vector2i(280, 160))
	Sim.step(2)
	assert_eq(CoopTraits.credit_slot(_hero), 0)
	assert_eq(CoopTraits.credit_slot(_p2), 1)
	assert_eq(CoopTraits.credit_slot(null), -1, "no hero's hit")
	assert_eq(CoopTraits.credit_slot(a), -1)
	var throw: ProjectileBase = _shot(Vector2i(200, 150), 208, 1)
	assert_eq(CoopTraits.credit_slot(throw), 1, "a thrown weapon: its thrower")
	for state: String in ["idle", "egg", "dead"]:
		_p2.idle = state == "idle"
		_p2.down = state == "egg"
		_p2.dead = state == "dead"
		assert_false(_p2.counts_for_coop())
		assert_eq(CoopTraits.credit_slot(_p2), -1, "%s: his own box counts for nobody" % state)
		assert_eq(CoopTraits.credit_slot(throw), -1, "%s: the weapon he threw before, too" % state)
		assert_true(a.take_hit(100, _p2))
		assert_true(a.take_hit(100, throw))
		assert_false(a.dead, "%s: his hits glance, also with no window open" % state)
		assert_eq(a.hp, a.max_hp)
	assert_eq(a.coop_traits().slot_refusals, 6)
	_p2.idle = false
	_p2.down = false
	_p2.dead = false
	# The ball: credited to the batted hero himself.
	_p2.curl = PlayerBase.CURL_BALL
	_p2.ball_batter = _hero
	assert_eq(Defs.hitter_slot(_p2), 0, "the statistics credit a ball's hit to its batter")
	assert_eq(CoopTraits.credit_slot(_p2), 1, "the windows credit it to the ball")
	assert_true(a.take_hit(100, _hero))
	assert_true(a.dead, "P1 clubs one member ...")
	_p2.idle = true
	assert_true(b.take_hit(100, _p2))
	assert_false(b.dead, "... and bats his IDLE partner into the other: nobody's hit, it glances")
	_p2.idle = false
	assert_true(b.take_hit(100, _p2))
	assert_true(b.dead, "a partner who plays, batted into it, is the second slot")
	assert_eq([a.coop_traits().kill_slot, b.coop_traits().kill_slot], [0, 1])
	assert_true(a.coop_traits().sealed and b.coop_traits().sealed, "a pair's Batter Up meets the bond")
	_p2.curl = PlayerBase.CURL_NONE
	_p2.ball_batter = null


## R2: nothing else of one hero's ends the bond either - with one member dead by his hand the other stays alive
## through his kill-all, a grenade (nobody's), his feast and his glider dives; the same deaths by his partner count.
func test_no_other_death_by_the_same_hero_ends_a_bond() -> void:
	var a: EnemyBase = _bonded(Vector2i(60, 160))
	var b: EnemyBase = _bonded(Vector2i(280, 160))
	Sim.step(2)
	assert_eq(ItemEffects.kill_all(_hero), 2, "a kill-all reaches both")
	assert_eq([a.dead, b.dead].count(true), 1, "and kills ONE: the second death would be the same hero's")
	var dead: EnemyBase = a if a.dead else b
	var alive: EnemyBase = b if a.dead else a
	assert_eq(alive.coop_traits().slot_refusals, 1)
	ItemEffects.grenade()
	assert_false(alive.dead, "a grenade is nobody's")
	alive.kill(&"feast", _hero)
	assert_false(alive.dead, "his feast does not eat it")
	for dive: int in Tuning.GLIDER_DIVE_KILLS_ON:
		alive.on_glider_stomp(_hero)
	assert_false(alive.dead, "nor do his glider dives kill it")
	assert_eq(alive.coop_traits().slot_refusals, 4)
	assert_false(CoopTraits.bond_done(_level, &"twins"))
	alive.kill(&"feast", _p2)
	assert_true(alive.dead, "his partner's feast does")
	assert_true(dead.coop_traits().sealed and alive.coop_traits().sealed)
	# A grenade first: the death is nobody's, so the window it opens cannot be met by one more hero.
	_level.reset_entities()
	Sim.step(2)
	a.burst_into_items(0)
	assert_true(a.dead, "the first death is free (it only opens the window)")
	assert_eq(a.coop_traits().kill_slot, -1)
	assert_true(b.take_hit(100, _hero))
	assert_true(b.take_hit(100, _p2))
	assert_false(b.dead, "one slot more would be one slot in all: both heroes' hits glance until it regrows")
	Sim.step(CoopTraits.window_ticks())
	assert_false(a.dead, "the window closed: it regrew")


## R2 for a bond of three: two different slots among the three deaths meet it; the hero who killed two cannot kill
## the last, his partner can.
func test_a_bond_of_three_needs_two_slots_among_its_deaths() -> void:
	var members: Array[EnemyBase] = []
	for x: int in [60, 160, 280]:
		members.append(_enemy(&"enemies/walker", Vector2i(x, 160), {"coop": "bond", "bond": "trio", "speed": 0}))
	Sim.step(2)
	assert_true(members[0].take_hit(100, _hero))
	assert_true(members[1].take_hit(100, _hero))
	assert_true(members[0].dead and members[1].dead, "P1 may kill two of three")
	assert_true(members[2].take_hit(100, _hero))
	assert_false(members[2].dead, "but not the last: every death would be his")
	assert_true(members[2].take_hit(100, _p2))
	assert_true(members[2].dead)
	for member: EnemyBase in members:
		assert_true(member.coop_traits().sealed, "P1, P1, P2: met")


## R2 leaves a record whose mates LEFT without a window as it was: a one-shot member that despawned is gone, and
## the one that remains dies as a plain enemy.
func test_a_member_whose_mate_despawned_dies_as_before() -> void:
	var a: EnemyBase = _bonded(Vector2i(60, 160))
	var b: EnemyBase = _bonded(Vector2i(280, 160))
	Sim.step(2)
	a.one_shot = true
	a.sleep()
	assert_true(a.dead, "a one-shot member that left the view is gone for good")
	assert_eq(a.coop_traits().died_tick, -1, "without a window")
	assert_true(b.take_hit(100, _hero))
	assert_true(b.dead, "nothing waits for a second slot: the rest of the bond dies to any hero")
	assert_true(b.coop_traits().sealed)


## R2 for the split: its halves fall to two different heroes. The hero who killed one half cannot kill the other
## while it lies dead - they merge back when the window closes - and his partner can.
func test_split_halves_fall_to_two_different_heroes() -> void:
	var blob: EnemyBase = _splitter(Vector2i(200, 160))
	_hero.teleport(Vector2i(150, 160))
	_p2.teleport(Vector2i(250, 160))
	Sim.step(2)
	_p2.idle = true
	assert_true(blob.take_hit(25, _p2), "an idle hero's hit on the whole record")
	assert_eq(blob.hp, 0, "a whole record has no window: an idle hero's hit splits it as any hit does")
	var copy: EnemyBase = blob.coop_traits().mate
	Sim.step(EnemyTuning.SPLIT_RUN_TICKS)
	assert_true(copy.take_hit(25, _p2), "his hit on a half is used up")
	assert_false(copy.dead, "a half is a windowed record: nobody's hit glances")
	assert_true(copy.take_hit(25, _hero), "P1's hit on a half")
	assert_true(copy.dead, "P1 kills one half")
	for tick: int in CoopTraits.window_ticks() - 1:
		assert_true(blob.take_hit(25, _hero), "tick %d: his hit on the other half is used up" % tick)
		assert_false(blob.dead, "tick %d: it glances" % tick)
		Sim.step(1)
	Sim.step(1)
	assert_eq(blob.coop_traits().split, CoopTraits.Split.WHOLE, "the window closed: merged back into the whole")
	assert_eq(blob.hp, blob.max_hp)
	# The pair.
	_p2.idle = false
	assert_true(blob.take_hit(25, _hero), "split again")
	copy = blob.coop_traits().mate
	Sim.step(EnemyTuning.SPLIT_RUN_TICKS)
	assert_true(copy.take_hit(25, _hero), "P1 kills the spawned half")
	Sim.step(3)
	assert_true(blob.take_hit(25, _p2), "P2 hits the other inside the window")
	assert_true(blob.dead and copy.dead, "both halves dead")
	assert_true(blob.coop_traits().sealed and copy.coop_traits().sealed, "one half each: the split is met")


## R2, a tar blob from the sky (`enemies/dropper coop=split`: its halves are a zone spawner's copy and the half that
## copy spawned). The copy's half, killed at the view's edge, is thrown out of the view and used to be freed 5 ticks
## later - no merge, and its mate was left a plain half that the same hero finished alone. Now it waits for its
## window: its mate turns his hits away, they merge back, and with one half each the blob is gone for good and the
## record may drop the next one.
func test_a_dead_half_of_a_sky_blob_waits_for_its_window() -> void:
	var record: Dropper = _enemy(&"enemies/dropper", Vector2i(200, 160), {"coop": "split", "max": 1, "hp": 10,
			"pause": 0}) as Dropper
	var blob: Dropper = null
	for tick: int in 120:
		Sim.step(1)
		for entity: SimEntity in _level.get_kind(Defs.Kind.ENEMY):
			var dropper: Dropper = entity as Dropper
			if dropper != null and dropper.is_copy() and dropper.xvel != 0 and dropper._grounded:
				blob = dropper
		if blob != null:
			break
	assert_not_null(blob, "a blob dropped and walks")
	if blob == null:
		return
	assert_true(blob.take_hit(25, _hero))
	var half: EnemyBase = blob.coop_traits().mate
	assert_not_null(half, "the first hit split it")
	assert_eq(blob.coop_traits().split, CoopTraits.Split.HALF)
	# The spawner's copy stands at the view's right edge when P1 (left of it) kills it: its corpse flies out.
	blob.teleport(Vector2i(_level.view.end.x - 4, 160))
	half.teleport(Vector2i(120, 160))
	_hero.teleport(Vector2i(100, 160))
	Sim.step(1)
	assert_true(blob.take_hit(25, _hero))
	assert_true(blob.dead)
	Sim.step(EnemyTuning.DEATH_ARC_MIN_TICKS + 3)
	assert_false(blob._corpse, "its corpse left the view and is over")
	assert_false(blob.is_queued_for_deletion(), "but the dead half stays for its window")
	assert_eq(record.alive_copies(), 1)
	assert_true(half.take_hit(25, _hero))
	assert_false(half.dead, "so its mate still turns the same hero's hit away")
	Sim.step(CoopTraits.window_ticks())
	assert_false(blob.dead, "the window closed: it merged back")
	assert_eq(blob.coop_traits().split, CoopTraits.Split.WHOLE)
	assert_true(half.dead and not half.sim_active, "the spawned half is gone")
	# One half each.
	assert_true(blob.take_hit(25, _hero))
	half = blob.coop_traits().mate
	blob.teleport(Vector2i(_level.view.end.x - 4, 160))
	Sim.step(1)
	assert_true(blob.take_hit(25, _hero))
	Sim.step(EnemyTuning.DEATH_ARC_MIN_TICKS + 3)
	assert_false(blob.is_queued_for_deletion())
	assert_true(half.take_hit(25, _p2))
	assert_true(half.dead and half.coop_traits().sealed, "P2's hit ends it")
	assert_true(blob.is_queued_for_deletion(), "the sealed copy leaves at once")
	assert_eq(record.alive_copies(), 0, "and the record may drop the next blob")


## R2 for the twin drums (objects/drum.gd; the bond test there is this rule's): the bond succeeds only through hits
## of two different heroes who count. The hero who lit one drum cannot light the last - his second hit sounds and
## stays dark - until his partner has struck a drum of the window; an idle hero's, an egg's and a downed hero's hits
## light nothing; a ball is its own slot. A party of one keeps the rule before R2.
func test_twin_drums_are_lit_only_by_two_different_heroes() -> void:
	var d1: Drum = _spawn(&"objects/drum", Vector2i(100, 160), {"bond": "twin"}) as Drum
	var d2: Drum = _spawn(&"objects/drum", Vector2i(400, 160), {"bond": "twin"}) as Drum
	var window: int = PartyTuning.window_ticks(Game.difficulty)
	Sim.step(1)
	d1.take_hit(25, _hero)
	assert_true(d1.lit, "P1 lights the first drum")
	assert_eq(d1.struck_by, 1)
	d2.take_hit(25, _shot(Vector2i(380, 150), 208, 0))
	assert_eq(d2.hits, 1, "his throw strikes the second inside the window ...")
	assert_false(d2.lit, "... and it stays dark: every drum would be his")
	assert_eq(d2.refused, 1)
	assert_false(Drum.bond_succeeded(_level, &"twin"))
	Sim.step(window)
	assert_false(d1.lit, "the window closed")
	# His partner struck a drum of the window: now the hero who was refused lights the last one.
	d1.take_hit(25, _hero)
	Sim.step(Tuning.HIDDEN_SPOT_HIT_COOLDOWN)
	d2.take_hit(25, _hero)
	assert_false(d2.lit)
	d1.take_hit(25, _p2)
	assert_eq(d1.struck_by, 3, "P2 strikes the lit drum too")
	Sim.step(Tuning.HIDDEN_SPOT_HIT_COOLDOWN)
	d2.take_hit(25, _hero)
	assert_true(Drum.bond_succeeded(_level, &"twin"), "both heroes drummed inside the window")
	# Nobody's hits.
	_level.reset_entities()
	Sim.step(1)
	assert_eq([d1.struck_by, d2.refused], [0, 0], "a team wipe clears the drums' slot state")
	d1.take_hit(25, _hero)
	var refused: int = d2.refused
	var throw: ProjectileBase = _shot(Vector2i(380, 150), 208, 1)
	for state: String in ["idle", "egg", "dead"]:
		_p2.idle = state == "idle"
		_p2.down = state == "egg"
		_p2.dead = state == "dead"
		d2.take_hit(25, throw if state != "idle" else _p2)
		assert_false(d2.lit, "%s: his hit lights nothing" % state)
		Sim.step(Tuning.HIDDEN_SPOT_HIT_COOLDOWN)
	assert_eq(d2.refused, refused + 3)
	_p2.idle = false
	_p2.down = false
	_p2.dead = false
	# The ball is its own slot.
	_level.reset_entities()
	Sim.step(1)
	d1.take_hit(25, _hero)
	_p2.curl = PlayerBase.CURL_BALL
	_p2.ball_batter = _hero
	_p2.idle = true
	d2.take_hit(25, _p2)
	assert_false(d2.lit, "his idle partner batted into the second drum lights nothing")
	_p2.idle = false
	Sim.step(Tuning.HIDDEN_SPOT_HIT_COOLDOWN)
	d2.take_hit(25, _p2)
	assert_true(Drum.bond_succeeded(_level, &"twin"), "a partner who plays, batted into it, is the second hero")
	_p2.curl = PlayerBase.CURL_NONE
	_p2.ball_batter = null
	# A party of one: the rule before R2 (any hit lights).
	_level.reset_entities()
	_p2.free()
	Sim.step(1)
	assert_false(CoopTraits.party_on())
	d1.take_hit(25, _hero)
	d2.take_hit(25, _hero)
	assert_true(Drum.bond_succeeded(_level, &"twin"), "alone in the level one hero drums both")


# =================================================================================================================
# R2 with the real entities: one hero's two throws in flight open no door, the pair's do
# =================================================================================================================

## G3b cause C on w5_l2_coop 'rattlers' (Expert, window 12; the verifier's route w5_l2_coop.rattlers.expert): the lone
## real hero stands between the bonded keeper Snappers of the real file with spears, his partner parked idle beside
## him. He throws high at the far one and forward at the near one as that spear lands: both hits arrive 6 ticks
## apart, inside the window - the far one dies and the near one's hit GLANCES (the slot rule; before R2 it died and
## the keeper door opened). The dead one regrows, the door never opens. The pair - the same two throws, one by each
## hero - kills both, seals the bond and the door rises.
func test_one_heros_two_spears_in_flight_never_open_the_rattlers_door_and_the_pairs_do() -> void:
	var lv: Level = _real_level(&"w5_l2_coop", Defs.Difficulty.EXPERT)
	var keepers: Array[EnemyBase] = _keepers(lv, &"rattlers")
	var door: RisingColumn = _door(lv, RisingColumn.Drive.KEEPERS, &"rattlers")
	assert_eq([keepers[0].spawn_pos, keepers[1].spawn_pos], [Vector2i(344, 480), Vector2i(632, 480)],
			"the keeper Snappers of the file (cells 21,29 and 39,29)")
	assert_eq(door.block, Rect2i(19, 26, 1, 4), "their door")
	var spot: Vector2i = Vector2i(455, 480)
	var opened: Array[int] = [0]
	var watch: Callable = func() -> void:
		if door.triggered or CoopTraits.keepers_done(lv, &"rattlers"):
			opened[0] += 1
	# One hero, both throws.
	_stand(lv, 0, spot, 1, Defs.Weapon.SPEAR)
	var parked: PlayerBase = _stand(lv, 1, spot - Vector2i(25, 0), 1, Defs.Weapon.CLUB, false)
	lv.snap_camera()
	Sim.step(3)
	assert_true(parked.is_idle() and not lv.get_hero(0).is_idle(), "the lone player and his parked partner")
	assert_true(keepers[0].is_targetable() and keepers[1].is_targetable(), "both keepers on the view")
	_play_party("10:UF|,2:|,1:L|,8:F|,12:|", watch, func() -> bool: return keepers[0].last_hit_tick >= 0)
	_assert_second_hit_refused(keepers[1], keepers[0], "the far Snapper", "the near Snapper")
	assert_eq(opened[0], 0, "the keepers were never both dead")
	_play_party("30:|", watch)
	assert_eq(opened[0], 0, "the door stays shut for one hero")
	assert_false(keepers[0].dead or keepers[1].dead, "the dead keeper regrew when its window closed")
	assert_eq(door.risen, 0)
	# The pair: the same two throws, one each.
	_clear_throws(lv)
	lv.reset_entities()
	_stand(lv, 0, spot, 1, Defs.Weapon.SPEAR)
	_stand(lv, 1, spot, 1, Defs.Weapon.SPEAR)
	lv.snap_camera()
	Sim.step(3)
	_play_party("10:UF|,2:|,1:|L,8:|F,12:|", watch)
	assert_true(keepers[0].dead and keepers[1].dead, "one spear each: both keepers fall inside the window")
	assert_eq([keepers[1].coop_traits().kill_slot, keepers[0].coop_traits().kill_slot], [0, 1],
			"the far one to P1, the near one to P2")
	assert_true(keepers[0].coop_traits().sealed and keepers[1].coop_traits().sealed, "the bond is met")
	assert_eq(keepers[0].coop_traits().slot_refusals + keepers[1].coop_traits().slot_refusals, 0,
			"nothing glanced this time")
	assert_true(door.triggered, "the keeper door starts")
	Sim.step(Tuning.COLUMN_RISE_PERIOD * 4 + 1)
	assert_eq(door.risen, 4, "and rises")
	assert_eq(lv.get_cell(19, 29), TileGrid.CH_AIR, "the doorway is open")


## The same on w9_l1b_coop 'stormwall' (Expert; the verifier's route w9_l1b_coop.stormwall.expert): the two perched
## keeper Harriers of the real file, 14 columns apart over the cloud. The lone real hero throws an axe high at the
## far one and, turned round, one at the near one: 7 ticks apart - the second glances, the door stays shut; with one
## axe each the pair opens it.
func test_one_heros_two_axes_in_flight_never_open_the_stormwall_and_the_pairs_do() -> void:
	var lv: Level = _real_level(&"w9_l1b_coop", Defs.Difficulty.EXPERT)
	var keepers: Array[EnemyBase] = _keepers(lv, &"storm")
	var door: RisingColumn = _door(lv, RisingColumn.Drive.KEEPERS, &"storm")
	assert_eq([keepers[0].spawn_pos, keepers[1].spawn_pos], [Vector2i(3176, 160), Vector2i(3400, 160)],
			"the perched keepers of the file (cells 198,9 and 212,9)")
	var spot: Vector2i = Vector2i(3246, 192)
	var opened: Array[int] = [0]
	var watch: Callable = func() -> void:
		if door.triggered or CoopTraits.keepers_done(lv, &"storm"):
			opened[0] += 1
	_stand(lv, 0, spot, 1, Defs.Weapon.AXE)
	_stand(lv, 1, spot - Vector2i(25, 0), 1, Defs.Weapon.CLUB, false)
	lv.snap_camera()
	Sim.step(3)
	assert_true(keepers[0].is_targetable() and keepers[1].is_targetable(), "both keepers on the view")
	_play_party("10:UF|,2:|,1:L|,10:UF|,10:|", watch, func() -> bool: return keepers[0].last_hit_tick >= 0)
	_assert_second_hit_refused(keepers[1], keepers[0], "the far keeper", "the near keeper")
	assert_eq(keepers[0].sim_pos, Vector2i(3176, 160), "the near one sits on its perch untouched")
	_play_party("30:|", watch)
	assert_eq(opened[0], 0, "the stormwall's door stays shut for one hero")
	assert_false(keepers[0].dead or keepers[1].dead, "the dead keeper is back on its perch")
	_clear_throws(lv)
	lv.reset_entities()
	_stand(lv, 0, spot, 1, Defs.Weapon.AXE)
	_stand(lv, 1, spot, 1, Defs.Weapon.AXE)
	lv.snap_camera()
	Sim.step(3)
	_play_party("10:UF|,2:|,1:|L,10:|UF,10:|", watch)
	assert_true(keepers[0].dead and keepers[1].dead, "one axe each: both keepers fall inside the window")
	assert_true(keepers[0].coop_traits().sealed and keepers[1].coop_traits().sealed, "the bond is met")
	assert_true(door.triggered, "the stormwall's door starts")
	Sim.step(Tuning.COLUMN_RISE_PERIOD * 4 + 1)
	assert_eq(door.risen, 4, "and rises")


## The twin drums of w4_l2_coop 'drums' (Expert; the verifier's route found_w4_l2_coop__drums__1: "two axes thrown in
## one jump between the drums land inside the window, the bond succeeds"): the lone real hero throws a spear at drum B
## by the keep tower and, turned round, one from a jump at drum A on its ledge - they strike 8 ticks apart, inside the
## window: B is lit and A stays DARK (the hero who lit every other drum cannot light the last). The portcullis stays
## down. With one spear each the pair's bond succeeds and the door rises.
func test_one_heros_two_spears_in_flight_never_light_both_drums_and_the_pairs_do() -> void:
	var lv: Level = _real_level(&"w4_l2_coop", Defs.Difficulty.EXPERT)
	var door: RisingColumn = _door(lv, RisingColumn.Drive.DRUMS, &"spikes")
	var drum_a: Drum = null
	var drum_b: Drum = null
	for entity: SimEntity in lv.get_tagged(&"bond", &"spikes"):
		var drum: Drum = entity as Drum
		if drum != null and drum.cell == Vector2i(155, 22):
			drum_a = drum
		elif drum != null and drum.cell == Vector2i(141, 26):
			drum_b = drum
	assert_true(drum_a != null and drum_b != null, "the twin drums of the file (cells 155,22 and 141,26)")
	var window: int = drum_a.bond_drums(lv)[0].window_ticks()
	assert_eq(window, PartyTuning.WINDOW_TICKS_EXPERT)
	var spot: Vector2i = Vector2i(2440, 432)
	_stand(lv, 0, spot, -1, Defs.Weapon.SPEAR)
	_stand(lv, 1, spot - Vector2i(25, 0), 1, Defs.Weapon.CLUB, false)
	lv.snap_camera()
	Sim.step(3)
	var lit_both: Array[int] = [0]
	_play_party("8:F|,6:|,1:R|,4:U|,8:F|,6:|", func() -> void:
		if drum_a.lit and drum_b.lit:
			lit_both[0] += 1, func() -> bool: return drum_a.hits > 0)
	assert_eq([drum_b.hits, drum_a.hits], [1, 1], "both spears struck their drums")
	var gap: int = drum_a.last_hit_tick - drum_b.last_hit_tick
	assert_true(gap > 0 and gap < window, "%d ticks apart: inside the %d-tick window" % [gap, window])
	assert_true(drum_b.lit, "drum B is lit: his first hit opened the window")
	assert_false(drum_a.lit, "drum A stays dark: the same hero lit the other one")
	assert_eq([drum_a.refused, drum_b.refused], [1, 0], "refused by the slot rule")
	assert_eq(lit_both[0], 0)
	assert_false(Drum.bond_succeeded(lv, &"spikes"))
	Sim.step(window + 4)
	assert_false(drum_a.lit or drum_b.lit, "the window closed: both dark again")
	assert_false(door.triggered, "the portcullis stays down for one hero")
	# The pair: P1's spear at drum B, P2's from his jump at drum A.
	_clear_throws(lv)
	lv.reset_entities()
	_stand(lv, 0, spot, -1, Defs.Weapon.SPEAR)
	_stand(lv, 1, spot, -1, Defs.Weapon.SPEAR)
	lv.snap_camera()
	Sim.step(3)
	_play_party("8:F|,6:|,1:|R,4:|U,8:|F,6:|", Callable(), func() -> bool: return drum_a.hits > 1)
	assert_eq([drum_b.struck_by, drum_a.struck_by], [1, 2], "B by P1, A by P2")
	assert_true(Drum.bond_succeeded(lv, &"spikes"), "one spear each: the bond succeeds")
	Sim.step(2)
	assert_true(door.triggered, "and the portcullis rises")
	Sim.step(Tuning.COLUMN_RISE_PERIOD * 4 + 1)
	assert_eq(door.risen, 4)


## `first` died to the lone hero's first throw; his second hit `second` inside the window and glanced.
func _assert_second_hit_refused(first: EnemyBase, second: EnemyBase, first_name: String, second_name: String) -> void:
	var window: int = first.coop_traits().group_window()
	assert_true(first.dead, "%s fell to his first throw" % first_name)
	assert_eq(first.coop_traits().kill_slot, 0, "credited to P1")
	var gap: int = second.last_hit_tick - first.last_hit_tick
	assert_true(first.last_hit_tick >= 0 and gap > 0 and gap < window,
			"his second throw hit %s %d ticks later, inside the %d-tick window" % [second_name, gap, window])
	assert_eq(second.last_hit_slot, 0)
	assert_false(second.dead, "%s lives: the hit glanced" % second_name)
	assert_eq(second.hp, second.max_hp, "without damage")
	assert_eq(second.coop_traits().slot_refusals, 1, "turned away by the slot rule")
	assert_false(first.coop_traits().sealed or second.coop_traits().sealed)


## The enemies of keeper group `group` of a real level, left to right.
func _keepers(lv: LevelBase, group: StringName) -> Array[EnemyBase]:
	var keepers: Array[EnemyBase] = []
	for entity: SimEntity in lv.get_tagged(&"keeper", group):
		keepers.append(entity as EnemyBase)
	keepers.sort_custom(func(a: EnemyBase, b: EnemyBase) -> bool: return a.spawn_pos.x < b.spawn_pos.x)
	return keepers


## The door (objects/column) of drive `drive` whose trigger names `group`.
func _door(lv: LevelBase, drive: int, group: StringName) -> RisingColumn:
	for entity: SimEntity in lv.get_kind(Defs.Kind.OTHER):
		var column: RisingColumn = entity as RisingColumn
		if column != null and column.drive == drive and column.group == group:
			return column
	return null


## The real hero of `slot` at `pos` (feet) facing `face` with `weapon` in hand; `plays` false: his player never
## pressed anything (PlayerBase.is_idle from his first tick on).
func _stand(lv: LevelBase, slot: int, pos: Vector2i, face: int, weapon: int, plays: bool = true) -> PlayerBase:
	var hero: PlayerBase = lv.get_hero(slot)
	hero.respawn_at(pos)
	hero.facing = face
	hero.run.set_weapon(weapon)
	hero.gave_input = plays
	hero.input_idle_ticks = 0
	hero.idle = not plays
	return hero


## Play the party script `text` ("ticks:P1 keys|P2 keys,...") tick by tick; `each` is called after every tick, and the
## script ends early on the tick after which `stop` holds.
func _play_party(text: String, each: Callable = Callable(), stop: Callable = Callable()) -> void:
	var streams: Array[PackedInt32Array] = Autoplay.parse_inputs_multi(text)
	var first: int = Sim.tick + 1
	for slot: int in streams.size():
		var flags: PackedInt32Array = streams[slot]
		GameInput.set_scripted_slot(slot, func(tick: int) -> int:
			var index: int = tick - first
			return flags[index] if index >= 0 and index < flags.size() else 0)
	for i: int in streams[0].size():
		Sim.step(1)
		if each.is_valid():
			each.call()
		if stop.is_valid() and stop.call():
			break
	GameInput.clear_scripted()


## Every thrown weapon still in the level is used up (before a reset: a stuck spear is no part of the next try).
func _clear_throws(lv: LevelBase) -> void:
	for entity: SimEntity in lv.get_kind(Defs.Kind.HERO_PROJECTILE).duplicate():
		var shot: ProjectileBase = entity as ProjectileBase
		if shot != null:
			shot.consume()


## The real level `level_id` (its scene, its records) with a co-op party of two real heroes whose players are at
## their pads (PlayerBase.gave_input); the flat fixture level is dropped.
func _real_level(level_id: StringName, difficulty: int) -> Level:
	if _level != null and is_instance_valid(_level):
		_level.free()
	_level = null
	_was_manual = Sim.manual
	Sim.manual = true
	Game.start_run(difficulty, Defs.GameMode.COOP, 2)
	Game.begin_level(level_id)
	var made: Level = (load(Flow.LEVEL_SCENE) as PackedScene).instantiate() as Level
	made.setup_from_text(level_id, FileAccess.get_file_as_string(Levels.get_level_path(level_id)))
	add_node(made)
	made.set_view_size(Vector2i(Tuning.VIEW_W, Tuning.VIEW_H) * Tuning.ART_SCALE)
	for who: PlayerBase in made.contact_order():
		who.gave_input = true
	_real = made
	return made

extends "res://tests/test_enemies_case.gd"
## The co-op-only enemies of PLAN.md P2.1 (DESIGN.md D.7, GAMEPLAY.md 13.9.6): `enemies/raptor`, `snatcher`, `leech`,
## `bull_rex`, `tar_splitter` and `shaman` (the Shellback is in test_enemies_book2.gd), each with its preset trait and
## skin, in a co-op party and alone (a party of one meets the plain archetype: N = 1 is the identity), plus the record
## file levels/test_enemies_bestiary.lvl.
##
## Heroes are bare PlayerBase nodes (they never move by themselves and have no contact pass of their own): P1 =
## `_hero` (slot 0), P2 = `_p2` (slot 1) in a co-op game.

const BESTIARY_LEVEL: String = "res://levels/test_enemies_bestiary.lvl"

var _p2: PlayerBase = null


func after_each() -> void:
	GameInput.clear_scripted()
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"")


# =================================================================================================================
# Raptor (Hopper + daze)
# =================================================================================================================

func test_a_raptor_alone_is_a_plain_hopper() -> void:
	var raptor: Raptor = _enemy(&"enemies/raptor", Vector2i(200, 160), {"range": 0}) as Raptor
	assert_true(raptor is Hopper)
	assert_eq(raptor.skin, "mini_rex_b", "the temple raptor")
	assert_eq(raptor.coop_traits().kind, Defs.CoopTrait.DAZE, "the preset carries the daze trait")
	assert_eq(raptor.score_index, EnemyTuning.SCORE_HOPPER)
	Sim.step(2)
	_hero.attack_gate = true
	Sim.step(1)
	assert_eq(raptor.xvel, 0, "no hop back from a strike")
	assert_true(raptor.take_hit(10, _hero))
	assert_eq(raptor.hp, 15, "a party of one hits it undazed")


func test_a_raptor_in_a_party_is_hurt_only_while_dazed() -> void:
	_party()
	var raptor: Raptor = _enemy(&"enemies/raptor", Vector2i(200, 160), {"range": 0, "hp": 100}) as Raptor
	_hero.teleport(Vector2i(140, 160))
	_p2.teleport(Vector2i(300, 160))
	Sim.step(2)
	raptor.take_hit(25, _hero)
	assert_eq(raptor.hp, 100, "undazed, hits glance")
	raptor.on_bounced(_p2)
	assert_eq(raptor.coop_traits().dazed, PartyTuning.DAZE_TICKS_BEGINNER)
	Sim.step(1)
	assert_eq(raptor._anim_role, &"dizzy")
	var sprite: Sprite2D = raptor.get_node(^"Sprite")
	assert_true(sprite.frame >= 16 and sprite.frame <= 19, "the sheet's dizzy frames 16-19 (%d)" % sprite.frame)
	raptor.take_hit(25, _hero)
	assert_eq(raptor.hp, 75, "dazed, the partner's strike counts")


func test_a_raptors_window_caps_its_daze() -> void:
	_party()
	var capped: Raptor = _enemy(&"enemies/raptor", Vector2i(200, 160), {"range": 0, "window": 9}) as Raptor
	var loose: Raptor = _enemy(&"enemies/raptor", Vector2i(400, 160), {"range": 0, "window": 30}) as Raptor
	Sim.step(1)
	capped.on_bounced(_hero)
	loose.on_bounced(_hero)
	assert_eq(capped.coop_traits().dazed, 9, "window=9 caps the Beginner daze of 14")
	assert_eq(loose.coop_traits().dazed, PartyTuning.DAZE_TICKS_BEGINNER, "a cap above the daze changes nothing")
	Game.difficulty = Defs.Difficulty.EXPERT
	capped.on_bounced(_hero)
	loose.on_bounced(_hero)
	assert_eq(capped.coop_traits().dazed, 9)
	assert_eq(loose.coop_traits().dazed, PartyTuning.DAZE_TICKS_EXPERT, "Expert: 12")
	assert_eq(CoopTraits.capped_window(PartyTuning.DAZE_TICKS_EXPERT, {"window": "9"}), 9, "the tools' rule")
	assert_eq(CoopTraits.capped_window(PartyTuning.DAZE_TICKS_EXPERT, {}), PartyTuning.DAZE_TICKS_EXPERT)


# =================================================================================================================
# Snatcher (Dangler or Stinger + grab)
# =================================================================================================================

func test_a_dangler_snatcher_alone_only_yo_yos() -> void:
	var bat: Snatcher = _enemy(&"enemies/snatcher", Vector2i(160, 100), {"depth": 32}) as Snatcher
	assert_eq(bat.kind, Snatcher.Kind.DANGLER)
	assert_eq(bat.skin, "bat_b", "the Snatcher bat")
	assert_eq(bat.coop_traits().kind, Defs.CoopTrait.GRAB)
	assert_eq(bat.score_index, EnemyTuning.SCORE_DANGLER)
	_hero.teleport(Vector2i(160, 160))
	var lowest: int = 0
	for tick: int in 40:
		Sim.step(1)
		lowest = maxi(lowest, bat.sim_pos.y)
		assert_null(bat.coop_traits().held, "a party of one is never seized")
		assert_eq(bat.sim_pos.x, 160, "on its line")
	assert_eq(lowest, 100 + 32, "down to `depth`")
	assert_true(bat._thread_on, "on its thread")


func test_a_dangler_snatcher_carries_a_hero_and_takes_up_its_thread_again() -> void:
	_party()
	var bat: Snatcher = _enemy(&"enemies/snatcher", Vector2i(160, 140), {"depth": 8, "perch": "15,6", "hp": 100}) \
			as Snatcher
	_p2.teleport(Vector2i(400, 160))
	_hero.teleport(Vector2i(160, 160))
	var seized: int = _step_until(func() -> bool: return bat.coop_traits().held == _hero, 10)
	assert_true(seized > 0, "touched from below: seized")
	var at: Vector2i = bat.sim_pos
	Sim.step(1)
	assert_false(bat._thread_on, "no thread while it carries him")
	Sim.step(9)
	assert_eq(bat.sim_pos, at + Vector2i(10, -10), "towards its perch at 1 px per tick")
	bat.take_hit(25, _p2)
	assert_null(bat.coop_traits().held, "the partner frees him")
	_hero.teleport(Vector2i(40, 160))
	var home: int = _step_until(func() -> bool: return bat.sim_pos.x == 160 and bat._thread_on, 60)
	assert_true(home > 0, "back on its line, on its thread")
	var y0: int = bat.sim_pos.y
	Sim.step(3)
	assert_ne(bat.sim_pos.y, y0, "and yo-yos again")


func test_a_stinger_snatcher_dives_seizes_drops_at_its_perch_and_flies_home() -> void:
	_party()
	var gull: Snatcher = _enemy(&"enemies/snatcher", Vector2i(200, 100),
			{"kind": "stinger", "perch": "16,4", "hp": 100}) as Snatcher
	assert_eq(gull.kind, Snatcher.Kind.STINGER)
	assert_eq(gull.skin, "gull_b", "the Snatcher's gull (pterodactyl_b recoloured)")
	assert_eq(gull.score_index, EnemyTuning.SCORE_STINGER)
	_p2.teleport(Vector2i(800, 160))
	_hero.teleport(Vector2i(240, 160))
	var seized: int = _step_until(func() -> bool: return gull.coop_traits().held == _hero, 60)
	assert_true(seized > 0, "it dives onto P1 and seizes him")
	assert_eq(gull.get_state(), Snatcher.State.DIVE)
	assert_false(_hero.control_enabled)
	var perch: Vector2i = LevelText.cell_to_feet(16, 4)
	var dropped: int = _step_until(func() -> bool: return gull.coop_traits().held == null, 300)
	assert_true(dropped > 0)
	assert_eq(gull.sim_pos, perch, "dropped at its perch")
	_hero.teleport(Vector2i(40, 160))
	var hovering: int = _step_until(func() -> bool: return gull.get_state() == Snatcher.State.HOVER, 300)
	assert_true(hovering > 0, "it flies home ...")
	assert_eq(gull.sim_pos, Vector2i(200, 100), "... to its anchor and hovers again")


func test_a_stinger_snatcher_alone_dives_like_a_stinger() -> void:
	var gull: Snatcher = _enemy(&"enemies/snatcher", Vector2i(200, 100), {"kind": "stinger"}) as Snatcher
	_hero.teleport(Vector2i(240, 160))
	Sim.step(2)
	assert_eq(gull.get_state(), Snatcher.State.DIVE)
	assert_eq(Vector2i(gull.xvel, gull.yvel), Vector2i(48, 48), "3 px per tick on both axes")
	var level: int = _step_until(func() -> bool: return gull.get_state() == Snatcher.State.LEVEL, 30)
	assert_true(level > 0, "it levels out")
	Sim.step(5)
	assert_null(gull.coop_traits().held, "a party of one is never seized")


# =================================================================================================================
# Leech (Lurker + leech)
# =================================================================================================================

func test_a_leech_rides_its_host_on_its_front_frames() -> void:
	_party()
	var leech: Leech = _enemy(&"enemies/leech", Vector2i(200, 160), {"pause": 0, "hp": 100}) as Leech
	assert_true(leech is Lurker)
	assert_eq(leech.skin, "leech")
	assert_eq(leech.coop_traits().kind, Defs.CoopTrait.LEECH)
	_hero.teleport(Vector2i(190, 160))
	_p2.teleport(Vector2i(300, 160))
	var latched: int = _step_until(func() -> bool: return leech.coop_traits().host == _hero, 40)
	assert_true(latched > 0, "it lands on P1's back")
	Sim.step(1)
	assert_eq(leech._anim_role, &"front", "shown latched")
	var sprite: Sprite2D = leech.get_node(^"Sprite")
	assert_true(sprite.frame >= 4 and sprite.frame <= 7, "the front frames 4-7 (%d)" % sprite.frame)
	assert_false(leech.take_hit(25, _hero), "its host's weapon passes through it")
	assert_true(leech.take_hit(25, _p2))
	assert_null(leech.coop_traits().host, "his partner clubs it off")


func test_a_leech_alone_never_latches() -> void:
	var leech: Leech = _enemy(&"enemies/leech", Vector2i(200, 160), {"pause": 0}) as Leech
	_hero.teleport(Vector2i(190, 160))
	for tick: int in 60:
		Sim.step(1)
		assert_null(leech.coop_traits().host)
	assert_true(leech.contact_hurts, "a plain lurker that hurts on contact")
	assert_true(leech.take_hit(10, _hero))
	assert_eq(leech.hp, 15)


# =================================================================================================================
# Bull Rex (Charger + heavy)
# =================================================================================================================

func test_a_bull_rex_runs_at_its_target_and_turns_when_it_overran_him() -> void:
	_level.view = Rect2i(0, 0, 2 * Tuning.VIEW_W, Tuning.VIEW_H)
	var bull: BullRex = _enemy(&"enemies/bull_rex", Vector2i(400, 160)) as BullRex
	assert_eq(bull.skin, "rex_b")
	assert_eq(bull.coop_traits().kind, Defs.CoopTrait.HEAVY)
	assert_eq(bull.score_index, EnemyTuning.SCORE_CHARGER)
	assert_false(bull.one_shot, "not the edge rusher's one-shot run")
	_hero.teleport(Vector2i(250, 160))
	Sim.step(1)
	assert_eq(bull.xvel, -EnemyTuning.CHARGER_SPEED, "it wakes in view and runs at the hero")
	var turned: int = _step_until(func() -> bool: return bull.xvel > 0, 120)
	assert_true(turned > 0, "it turns round ...")
	var decided_at: int = bull.sim_pos.x - Tuning.floor16(bull.xvel)
	assert_true(decided_at < 250 - EnemyTuning.BULL_TURN_PX and decided_at >= 250 - EnemyTuning.BULL_TURN_PX - 4,
			"... once it overran him by 48 px (it stood at %d)" % decided_at)
	assert_true(bull.take_hit(10, _hero))
	assert_eq(bull.hp, 15, "alone, its front is no armour")


func test_a_wall_turns_a_bull_rex_round() -> void:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 16:
		rows.append(("#" + ".".repeat(28) + "#" + ".".repeat(30)) if row < 10 else "#".repeat(60))
	_rows_level(rows)
	_level.view = Rect2i(0, 0, 60 * Tuning.TILE, 16 * Tuning.TILE)
	var bull: BullRex = _enemy(&"enemies/bull_rex", Vector2i(300, 160)) as BullRex
	_hero.teleport(Vector2i(440, 160))
	Sim.step(1)
	assert_eq(bull.xvel, EnemyTuning.CHARGER_SPEED)
	var turned: int = _step_until(func() -> bool: return bull.xvel < 0, 60)
	assert_true(turned > 0, "the wall of column 29 turns it")
	assert_true(bull.sim_pos.x < 29 * Tuning.TILE)


func test_a_bull_rex_is_stopped_by_a_brace_wall_only() -> void:
	_party()
	_level.view = Rect2i(0, 0, 2 * Tuning.VIEW_W, Tuning.VIEW_H)
	var bull: BullRex = _enemy(&"enemies/bull_rex", Vector2i(400, 160), {"hp": 100}) as BullRex
	_crouch(_hero, Vector2i(250, 160))
	_crouch(_p2, Vector2i(250 + PartyTuning.BRACE_GAP_PX, 160))
	Sim.step(1)
	bull.take_hit(25, _hero)
	assert_eq(bull.hp, 100, "its front glances")
	var braced: int = _step_until(func() -> bool: return bull.coop_traits().dazed > 0, 80)
	assert_true(braced > 0, "it runs into the braced pair")
	assert_eq(bull.xvel, 0, "and stops dead")
	assert_false(bull.contact_hurts)
	Sim.step(1)
	assert_eq(bull._anim_role, &"dizzy", "dazed (the rex sheet shows it with its hurt frames)")
	bull.take_hit(25, _hero)
	assert_eq(bull.hp, 75, "dazed, its head is open")
	_hero.state = Defs.HeroState.IDLE
	_p2.state = Defs.HeroState.IDLE
	_step_until(func() -> bool: return bull.coop_traits().dazed == 0, PartyTuning.BRACE_DAZE_TICKS + 1)
	Sim.step(1)
	assert_eq(bull.xvel, -EnemyTuning.CHARGER_SPEED, "it runs on")


# =================================================================================================================
# Tar Splitter (Walker + split)
# =================================================================================================================

func test_a_tar_splitter_splits_into_the_two_palettes() -> void:
	_party()
	var blob: TarSplitter = _enemy(&"enemies/tar_splitter", Vector2i(200, 160), {"speed": 32}) as TarSplitter
	assert_true(blob is Walker)
	assert_eq(blob.skin, "slime")
	assert_eq(blob.coop_traits().kind, Defs.CoopTrait.SPLIT)
	_hero.teleport(Vector2i(150, 160))
	_p2.teleport(Vector2i(250, 160))
	Sim.step(2)
	blob.take_hit(25, _hero)
	var half: EnemyBase = blob.coop_traits().mate
	assert_not_null(half)
	assert_true(half is TarSplitter)
	assert_eq(half.skin, "slime_b", "the spawned half wears the other palette")
	assert_eq(blob.skin, "slime")
	Sim.step(1)
	assert_eq(half._anim_role, &"squash", "freshly split off")
	Sim.step(EnemyTuning.SPLIT_RUN_TICKS)
	assert_true(absi(blob.xvel) > 0, "after the run the halves patrol again")
	assert_eq(TarSplitter.other_palette("slime_b"), "slime")
	assert_eq(TarSplitter.other_palette("frog"), "frog", "a sheet with one palette keeps it")


func test_a_tar_splitter_window_is_capped_per_record() -> void:
	_party()
	_level.view = Rect2i(0, 0, 2 * Tuning.VIEW_W, Tuning.VIEW_H)
	var blob: TarSplitter = _enemy(&"enemies/tar_splitter", Vector2i(200, 160), {"speed": 0, "window": 5}) \
			as TarSplitter
	_hero.teleport(Vector2i(150, 160))
	_p2.teleport(Vector2i(250, 160))
	Sim.step(2)
	blob.take_hit(25, _hero)
	var half: EnemyBase = blob.coop_traits().mate
	assert_eq(half.coop_traits().window_cap, 5, "the half keeps the record's cap")
	assert_eq(blob.coop_traits().group_window(), 5)
	Sim.step(EnemyTuning.SPLIT_RUN_TICKS)
	blob.take_hit(25, _p2)
	Sim.step(4)
	assert_true(blob.dead, "inside its 5-tick window")
	Sim.step(1)
	assert_false(blob.dead, "the window closed at 5 ticks (not the Beginner 24): they merge back")
	assert_eq(blob.coop_traits().split, CoopTraits.Split.WHOLE)
	# Within the cap: sealed.
	var other: TarSplitter = _enemy(&"enemies/tar_splitter", Vector2i(400, 160), {"speed": 0, "window": 5}) \
			as TarSplitter
	_hero.teleport(Vector2i(350, 160))
	_p2.teleport(Vector2i(450, 160))
	Sim.step(2)
	other.take_hit(25, _hero)
	var mate: EnemyBase = other.coop_traits().mate
	Sim.step(EnemyTuning.SPLIT_RUN_TICKS)
	other.take_hit(25, _p2)
	Sim.step(4)
	mate.take_hit(25, _hero)
	assert_true(other.coop_traits().sealed and mate.coop_traits().sealed, "4 ticks apart: within the window")


func test_a_tar_splitter_alone_is_a_plain_walker() -> void:
	var blob: TarSplitter = _enemy(&"enemies/tar_splitter", Vector2i(200, 160)) as TarSplitter
	Sim.step(2)
	assert_true(blob.take_hit(10, _hero))
	assert_eq(blob.hp, 15, "a party of one: the hit counts, nothing splits")
	assert_null(blob.coop_traits().mate)
	assert_eq(_of_scene(Defs.Kind.ENEMY, &"enemies/tar_splitter").size(), 1)


func test_a_split_sky_dropper_keeps_its_state() -> void:
	_party()
	var record: Dropper = _enemy(&"enemies/dropper", Vector2i(200, 160),
			{"coop": "split", "skin": "slime", "zone": "0,0,60,16", "pause": 0, "max": 1}) as Dropper
	_hero.teleport(Vector2i(100, 160))
	_p2.teleport(Vector2i(500, 160))
	var copies: Array[SimEntity] = []
	for tick: int in 200:
		Sim.step(1)
		copies = _of_scene(Defs.Kind.ENEMY, &"enemies/dropper")
		if copies.size() >= 2 and (copies[1] as Dropper)._state == Dropper.State.WALK:
			break
	assert_eq(copies.size(), 2, "the record and one falling blob")
	var blob: Dropper = copies[1] as Dropper
	assert_eq(blob._state, Dropper.State.WALK)
	blob.take_hit(25, _hero)
	var half: Dropper = blob.coop_traits().mate as Dropper
	assert_not_null(half, "the blob split")
	assert_eq(half._state, Dropper.State.WALK, "its half walks on instead of waiting above the view")
	Sim.step(EnemyTuning.SPLIT_RUN_TICKS + 2)
	assert_ne(half.xvel, 0, "and keeps walking after the run")
	assert_ne(blob.xvel, 0)
	assert_true(record.awake == false, "the record never shows itself")


# =================================================================================================================
# Shaman
# =================================================================================================================

func test_a_shaman_patrols_and_flees_from_the_nearer_hero() -> void:
	var shaman: Shaman = _enemy(&"enemies/shaman", Vector2i(200, 160), {"left": -6, "right": 6}) as Shaman
	assert_eq(shaman.score_index, EnemyTuning.SCORE_SHAMAN)
	assert_eq(shaman.speed, EnemyTuning.SHAMAN_SPEED)
	assert_null(shaman.coop_traits(), "no trait: a patroller of his own")
	_hero.teleport(Vector2i(40, 160))
	var fastest: int = 0
	for tick: int in 40:
		Sim.step(1)
		fastest = maxi(fastest, absi(shaman.xvel))
		assert_false(shaman.is_fleeing())
	assert_eq(fastest, EnemyTuning.SHAMAN_SPEED, "he patrols at 48 v16")
	_hero.teleport(Vector2i(shaman.sim_pos.x - 50, 160))
	Sim.step(1)
	assert_true(shaman.is_fleeing())
	assert_eq(shaman.xvel, EnemyTuning.SHAMAN_SPEED, "he turns away from the hero at once")
	_hero.teleport(Vector2i(shaman.sim_pos.x + 50, 160))
	Sim.step(1)
	assert_eq(shaman.xvel, -EnemyTuning.SHAMAN_SPEED, "and the other way")


func test_a_cornered_shaman_hops_over_the_hero_without_hurting_him() -> void:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 16:
		rows.append((".".repeat(16) + "#" + ".".repeat(43)) if row < 10 else "#".repeat(60))
	_rows_level(rows)
	var shaman: Shaman = _enemy(&"enemies/shaman", Vector2i(240, 160), {"left": -3, "right": 3}) as Shaman
	_hero.teleport(Vector2i(200, 160))
	var hopped: int = _step_until(func() -> bool: return shaman.is_hopping(), 10)
	assert_true(hopped > 0, "cornered against the wall of column 16, he hops")
	assert_false(shaman.contact_hurts, "harmless while he slips past")
	assert_eq(shaman.xvel, -EnemyTuning.SHAMAN_HOP_XVEL, "over the hero")
	var top: int = shaman.sim_pos.y
	var landed: int = -1
	for tick: int in 40:
		Sim.step(1)
		top = mini(top, shaman.sim_pos.y)
		if not shaman.is_hopping():
			landed = tick
			break
	assert_true(landed > 0)
	assert_true(top <= 160 - 40, "about 45 px high (%d)" % top)
	assert_true(shaman.sim_pos.x < 200, "he landed behind the hero")
	assert_true(shaman.contact_hurts)
	Sim.step(1)
	assert_true(shaman.xvel < 0, "and flees on (past his patrol limit: only walls and edges corner him)")


func test_a_shaman_with_no_floor_beyond_the_hero_cowers() -> void:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 16:
		if row == 7:
			rows.append(".".repeat(10) + "#".repeat(5) + ".".repeat(45))
		else:
			rows.append(("." if row < 10 else "#").repeat(60))
	_rows_level(rows)
	var shaman: Shaman = _enemy(&"enemies/shaman", Vector2i(216, 112), {"left": -3, "right": 3}) as Shaman
	_hero.teleport(Vector2i(176, 112))
	for tick: int in 30:
		Sim.step(1)
		assert_false(shaman.is_hopping(), "a hop would land off his 5-cell platform")
		assert_eq(shaman.sim_pos.y, 112, "he stays on it")
	assert_eq(shaman.xvel, 0, "he cowers at its end")
	assert_true(shaman.sim_pos.x > 216 and shaman.sim_pos.x < 240)
	assert_eq(shaman.facing, -1, "facing the hero")
	assert_true(shaman.take_hit(25, _hero))
	assert_eq(shaman.hp, 0, "and can be hit")


func test_a_shaman_never_walks_off_his_platform() -> void:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 16:
		if row < 7:
			rows.append(".".repeat(60))
		elif row == 7:
			rows.append(".".repeat(10) + "#".repeat(8) + ".".repeat(42))
		elif row < 10:
			rows.append(".".repeat(60))
		else:
			rows.append("#".repeat(60))
	_rows_level(rows)
	var shaman: Shaman = _enemy(&"enemies/shaman", LevelText.cell_to_feet(14, 6), {"left": -10, "right": 10}) \
			as Shaman
	_hero.teleport(Vector2i(800, 160))
	for tick: int in 200:
		Sim.step(1)
		assert_eq(shaman.sim_pos.y, 112, "on his platform (tick %d)" % tick)
		assert_true(shaman.sim_pos.x >= 160 and shaman.sim_pos.x < 288, "between its ends (%d)" % shaman.sim_pos.x)


func test_a_shaman_shields_his_neighbours_in_a_party_until_he_dies() -> void:
	_party()
	var shaman: Shaman = _enemy(&"enemies/shaman", Vector2i(200, 160), {"speed": 0}) as Shaman
	var near: EnemyBase = _enemy(&"enemies/walker", Vector2i(260, 160), {"speed": 0, "hp": 100})
	var far: EnemyBase = _enemy(&"enemies/walker", Vector2i(280, 160), {"speed": 0, "hp": 100})
	var other: Shaman = _enemy(&"enemies/shaman", Vector2i(140, 160), {"speed": 0}) as Shaman
	_hero.teleport(Vector2i(40, 160))
	_p2.teleport(Vector2i(600, 160))
	Sim.step(2)
	assert_true(near.bone_shielded(), "64 px away: shielded")
	assert_false(far.bone_shielded(), "80 px away: not")
	assert_false(shaman.bone_shielded() or other.bone_shielded(), "Shamans never shield each other")
	var sparks: int = _count_fx(&"fx/hit_stars")
	assert_true(near.take_hit(25, _hero))
	assert_eq(near.hp, 100, "every hit on it glances")
	assert_eq(_count_fx(&"fx/hit_stars"), sparks + 1, "with the clank and spark")
	var bone: Sprite2D = near.get_node_or_null(^"BoneShield") as Sprite2D
	assert_not_null(bone, "a bone floats over it")
	assert_true(bone != null and bone.visible)
	far.take_hit(25, _hero)
	assert_eq(far.hp, 75)
	other.kill(&"weapon", _hero)
	shaman.kill(&"weapon", _hero)
	Sim.step(1)
	assert_true(near.bone_shielded(), "his last shield holds through the tick he dies in ...")
	Sim.step(1)
	assert_false(near.bone_shielded(), "... then it falls with its Shaman")
	assert_false(bone.visible)
	near.take_hit(25, _hero)
	assert_eq(near.hp, 75)


func test_a_shaman_shields_nobody_for_a_party_of_one() -> void:
	var shaman: Shaman = _enemy(&"enemies/shaman", Vector2i(200, 160), {"speed": 0}) as Shaman
	var near: EnemyBase = _enemy(&"enemies/walker", Vector2i(230, 160), {"speed": 0})
	_hero.teleport(Vector2i(40, 160))
	Sim.step(3)
	assert_false(near.bone_shielded())
	near.take_hit(10, _hero)
	assert_eq(near.hp, 15)
	assert_eq(shaman.skin, "shaman", "the dragon-man sheet")


func test_two_heroes_pin_a_shaman_between_them() -> void:
	_party()
	var shaman: Shaman = _enemy(&"enemies/shaman", Vector2i(200, 160), {"left": -5, "right": 5}) as Shaman
	_hero.teleport(Vector2i(160, 160))
	_p2.teleport(Vector2i(240, 160))
	for tick: int in 60:
		Sim.step(1)
		assert_false(shaman.is_hopping(), "never cornered by a limit")
		assert_true(shaman.sim_pos.x > 180 and shaman.sim_pos.x < 220, "pinned (%d)" % shaman.sim_pos.x)
	assert_true(shaman.take_hit(25, _p2))
	assert_true(shaman.take_hit(25, _hero))
	assert_true(shaman.dead, "two hits from both sides")


# =================================================================================================================
# The record file
# =================================================================================================================

func test_the_bestiary_level_names_every_coop_only_enemy() -> void:
	var records: Dictionary = _load_records(BESTIARY_LEVEL)
	var ids: Dictionary = {}
	for key: String in records:
		ids[String((records[key] as EnemyBase).scene_file_path.get_file().get_basename())] = true
	for id: String in ["shellback", "raptor", "snatcher", "leech", "bull_rex", "tar_splitter", "shaman"]:
		assert_true(ids.has(id), "enemies/%s is in the bestiary" % id)
	var kinds: Dictionary = {}
	for key: String in records:
		var snatcher: Snatcher = records[key] as Snatcher
		if snatcher != null:
			kinds[snatcher.kind] = true
			assert_true(snatcher.coop_traits().has_perch, "every snatcher has its perch")
	assert_eq(kinds.size(), 2, "both snatcher forms")
	var bull: BullRex = records["X"] as BullRex
	assert_not_null(bull)
	var col: int = Tuning.to_cell(bull.sim_pos.x)
	assert_eq(_level.grid.get_char(col, Tuning.to_cell(bull.sim_pos.y) - 5), TileGrid.CH_SOLID_A, "a roof ...")
	for up: int in range(1, 5):
		assert_eq(_level.grid.get_char(col, Tuning.to_cell(bull.sim_pos.y) - up), TileGrid.CH_AIR,
				"... over the 4-row brace corridor")
	Sim.step(30)
	for key: String in records:
		assert_false((records[key] as EnemyBase).dead, "%s lives" % key)


# =================================================================================================================
# Helpers
# =================================================================================================================

## A co-op game on a fresh flat level: P1 at (40, 160), P2 at (100, 160).
func _party() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	Game.begin_level(&"test")
	_flat_level(60, 16, 10)
	_p2 = _add_p2(Vector2i(100, 160))


func _add_p2(pos: Vector2i) -> PlayerBase:
	var p2: PlayerBase = PlayerBase.new()
	place(_level, p2, pos, {"slot": 1})
	p2.respawn_at(pos)
	return p2


func _crouch(hero: PlayerBase, pos: Vector2i) -> void:
	hero.teleport(pos)
	hero.state = Defs.HeroState.CROUCH
	hero.grounded = true
	hero.set_box(Tuning.HERO_BOX_CROUCH)


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


## The enemy records of a level file by legend letter, spawned into a co-op game on a bare level of its tiles (the
## whole level in view), P1 at '@' and P2 beside him.
func _load_records(path: String) -> Dictionary:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	Game.begin_level(&"test")
	var sections: Dictionary = LevelText.split_sections(FileAccess.get_file_as_string(path))
	var legend: Dictionary = LevelText.parse_legend(sections.get("legend", PackedStringArray()))
	var rows: PackedStringArray = sections.get("tiles", PackedStringArray())
	_rows_level(rows)
	var records: Dictionary = {}
	for row: int in rows.size():
		for col: int in rows[row].length():
			var key: String = rows[row][col]
			if key == TileGrid.CH_PLAYER_START:
				_hero.teleport(LevelText.cell_to_feet(col, row))
			if not legend.has(key) or Spawner.category(legend[key]["id"]) != "enemies":
				continue
			var params: Dictionary = (legend[key]["params"] as Dictionary).duplicate()
			records[key] = _enemy(legend[key]["id"], LevelText.cell_to_feet(col, row, params), params)
	_p2 = _add_p2(_hero.sim_pos + Vector2i(-PartyTuning.RESPAWN_SPREAD_PX, 0))
	_level.view = Rect2i(0, 0, rows[0].length() * Tuning.TILE, rows.size() * Tuning.TILE)
	return records

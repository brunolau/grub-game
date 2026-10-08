extends TestCase
## The 2.0 contract of docs/expansion/PLAN.md P0.3: the appended Defs values, Tuning's Book II rules, PartyTuning,
## VersusTuning, the Events twins and party / round signals, and the Sfx names of DESIGN.md F.2 - and that every
## 1.0 value they were appended to is unchanged (TECH_AUDIT.md 2: a party of one is the 1.0 game).


## A stand-in for any hero-kind entity that carries a slot (PlayerBase.slot itself is tested in
## tests/test_core_player_set.gd).
class SlotHero:
	extends SimEntity
	var slot: int = 0

	func get_kind() -> int:
		return Defs.Kind.PLAYER


## A stand-in for a hero projectile that already carries its owner's slot.
class SlotShot:
	extends SimEntity
	var owner_slot: int = 0

	func get_kind() -> int:
		return Defs.Kind.HERO_PROJECTILE


# =================================================================================================================
# Defs
# =================================================================================================================

func test_1_0_defs_values_are_unchanged() -> void:
	assert_eq(Defs.PHASE_COUNT, 12)
	assert_eq(Defs.Phase.size(), Defs.PHASE_COUNT)
	assert_eq(Defs.Phase.CONTACT_ENEMIES, 7)
	assert_eq(Defs.Phase.CONTACT_ITEMS, 8)
	assert_eq(Defs.Phase.POST, 11)
	assert_eq(Defs.KIND_COUNT, 14)
	assert_eq(Defs.Kind.size(), Defs.KIND_COUNT)
	assert_ints_eq([Defs.Weapon.CLUB, Defs.Weapon.HAMMER, Defs.Weapon.AXE, Defs.Weapon.BOOMERANG], [0, 1, 2, 3])
	assert_ints_eq([Defs.IN_FIRE, Defs.IN_DOWN, Defs.IN_UP, Defs.IN_LEFT, Defs.IN_RIGHT, Defs.IN_LOOK],
		[1, 2, 4, 8, 16, 32])
	assert_eq(Defs.IN_STATE_MASK, 31)
	for name: String in ["club", "hammer", "axe", "boomerang"]:
		assert_eq(Defs.weapon_name(Defs.Weapon[name.to_upper()]), name)
	assert_eq(Defs.weapon_name(99), "club", "an unknown weapon is still named club")


func test_players_modes_and_input_slots() -> void:
	assert_eq(Defs.MAX_PLAYERS, 4)
	assert_eq(Defs.GameMode.SINGLE, 0, "single-player is the default everywhere")
	assert_eq(Defs.GameMode.size(), 3)
	assert_eq(Defs.game_mode_name(Defs.GameMode.SINGLE), "single")
	assert_eq(Defs.game_mode_name(Defs.GameMode.COOP), "coop")
	assert_eq(Defs.game_mode_name(Defs.GameMode.VERSUS), "versus")
	assert_eq(Defs.InputSlotKind.NONE, 0)
	var kinds: Array = Defs.InputSlotKind.values()
	for kind: int in kinds:
		assert_eq(kinds.count(kind), 1, "input slot kind %d is unique" % kind)
	for key: String in ["ALL_DEVICES", "KEYBOARD_LEFT", "KEYBOARD_RIGHT", "KEYBOARD_FULL", "PAD", "TOUCH", "BOT",
			"SCRIPT"]:
		assert_true(Defs.InputSlotKind.has(key), "InputSlotKind.%s (TECH_AUDIT.md 4.3)" % key)


func test_swap_flag_is_a_free_bit_outside_the_state_table() -> void:
	assert_eq(Defs.IN_SWAP, 64)
	assert_eq(Defs.IN_SWAP & (Defs.IN_SWAP - 1), 0, "one bit")
	var old_flags: int = Defs.IN_FIRE | Defs.IN_DOWN | Defs.IN_UP | Defs.IN_LEFT | Defs.IN_RIGHT | Defs.IN_LOOK
	assert_eq(Defs.IN_SWAP & old_flags, 0, "IN_SWAP shares no bit with a 1.0 flag")
	assert_eq(Defs.IN_SWAP & Defs.IN_STATE_MASK, 0, "the state table never sees Swap")
	assert_eq(Tuning.STATE_LUT[(Defs.IN_SWAP | Defs.IN_RIGHT) & Defs.IN_STATE_MASK], Defs.HeroState.WALK)
	assert_eq(Defs.ACT_SWAP, &"swap")


func test_coop_traits_and_versus_modes_have_names() -> void:
	assert_eq(Defs.COOP_TRAIT_NAMES.size(), Defs.CoopTrait.size())
	assert_eq(Defs.CoopTrait.NONE, 0)
	for key: String in Defs.CoopTrait:
		var value: int = Defs.CoopTrait[key]
		var name: StringName = Defs.coop_trait_name(value)
		assert_eq(String(name), "" if value == Defs.CoopTrait.NONE else key.to_lower(), "trait %s" % key)
		assert_eq(Defs.coop_trait_from_name(name), value)
	assert_eq(Defs.coop_trait_from_name(&"sticky"), -1)
	assert_eq(Defs.coop_trait_name(-1), &"")
	assert_eq(Defs.coop_trait_name(Defs.CoopTrait.size()), &"")
	assert_eq(Defs.VERSUS_MODE_NAMES.size(), Defs.VersusMode.size())
	for key: String in Defs.VersusMode:
		var mode: int = Defs.VersusMode[key]
		assert_eq(Defs.versus_mode_from_name(Defs.versus_mode_name(mode)), mode, "mode %s" % key)
	assert_eq(Defs.versus_mode_name(Defs.VersusMode.GRUB_STACK), &"grub_stack")
	assert_eq(Defs.versus_mode_from_name(&"tag"), -1)
	assert_eq(Defs.versus_mode_name(99), &"")
	assert_eq(Defs.BotLevel.size(), 3)


func test_spear_is_an_appended_weapon_with_its_rules() -> void:
	assert_eq(Defs.Weapon.SPEAR, 4)
	assert_eq(Defs.weapon_name(Defs.Weapon.SPEAR), "spear")
	for table: Array in [Tuning.WEAPON_POWER, Tuning.WEAPON_LOCK, Tuning.WEAPON_THROWN]:
		assert_eq(table.size(), Defs.Weapon.size(), "one entry per weapon")
	assert_eq(Tuning.WEAPON_POWER[Defs.Weapon.SPEAR], Tuning.SPEAR_POWER)
	assert_eq(Tuning.WEAPON_LOCK[Defs.Weapon.SPEAR], Tuning.SPEAR_LOCK)
	assert_true(Tuning.WEAPON_THROWN[Defs.Weapon.SPEAR])
	assert_eq(Tuning.floor16(Tuning.SPEAR_XVEL), 12, "thrown flat at 12 px/tick (DESIGN.md C.2)")
	assert_eq(VersusTuning.SPECIAL_THROWS.size(), Defs.Weapon.size())


func test_hitter_slot_credits_heroes_and_their_projectiles() -> void:
	assert_eq(Defs.hitter_slot(null), -1)
	var hero: SlotHero = SlotHero.new()
	var shot: SlotShot = SlotShot.new()
	var other: SimEntity = SimEntity.new()
	var player: PlayerBase = PlayerBase.new()
	var enemy: EnemyBase = EnemyBase.new()
	var projectile: ProjectileBase = ProjectileBase.new()
	assert_eq(Defs.hitter_slot(hero), 0)
	hero.slot = 3
	assert_eq(Defs.hitter_slot(hero), 3)
	shot.owner_slot = 2
	assert_eq(Defs.hitter_slot(shot), 2)
	assert_eq(Defs.hitter_slot(other), -1)
	assert_eq(Defs.hitter_slot(enemy), -1)
	assert_eq(Defs.hitter_slot(player), 0, "a hero spawned without a slot is P1")
	projectile.from_hero = true
	assert_eq(Defs.hitter_slot(projectile), 0)
	projectile.from_hero = false
	assert_eq(Defs.hitter_slot(projectile), -1, "an enemy projectile credits nobody")
	assert_eq(Defs.hitter_slot(RefCounted.new()), -1, "not an entity")
	assert_eq(Defs.hitter_slot(7), -1, "not an object")
	var stored: Array = [hero]
	for node: Node in [hero, shot, other, player, enemy, projectile]:
		node.free()
	assert_eq(Defs.hitter_slot(stored[0]), -1, "a last hitter freed since credits nobody")


# =================================================================================================================
# Tuning: Book II rules
# =================================================================================================================

func test_book2_rules_in_tuning() -> void:
	assert_eq(Tuning.SWAP_LOCKOUT_TICKS, 8)
	assert_true(Tuning.BARK_BOARD_BLINK_TICKS < Tuning.BARK_BOARD_STEP_TICKS)
	assert_eq(Tuning.BARK_BOARD_STEP_W, Tuning.TILE)
	assert_eq(Tuning.TAR_WALK_CAP, Tuning.CRAWL_CAP, "2 px/tick")
	assert_true(Tuning.TAR_JUMP_IMPULSE_TICKS < Tuning.JUMP_IMPULSE_TICKS)
	assert_eq(Tuning.GEYSER_POWER, Tuning.BOUNCE_YVEL_UP, "a geyser launches like a spring (-224)")
	assert_true(Tuning.GEYSER_BUBBLE_TICKS >= Tuning.TELEGRAPH_MIN_TICKS)
	assert_ints_eq(Tuning.RAFT_WIDTHS, [3, 4])
	assert_eq(Tuning.RISE_SPEED, Tuning.V16_PER_PX, "1 px per tick")
	assert_eq(Tuning.PAINTING_BOOK2_COUNT, 20)
	# The ladder after cut 3 (DESIGN.md G60): patterns, loincloths, variants, Spear Party, gold, the mural.
	var unlocks: Array[int] = [Tuning.PAINTING_UNLOCK_PATTERNS, Tuning.PAINTING_UNLOCK_LOINCLOTHS,
		Tuning.PAINTING_UNLOCK_VARIANTS, Tuning.PAINTING_UNLOCK_SPEAR_PARTY, Tuning.PAINTING_UNLOCK_GOLD,
		Tuning.PAINTING_UNLOCK_MURAL]
	assert_ints_eq(unlocks, [5, 10, 15, 20, 25, 30])
	assert_eq(unlocks[unlocks.size() - 1], Tuning.PAINTING_COUNT)


## The core-owned rows of the constant sheet docs/spec/PHYSICS.md C.16 (and the register GAMEPLAY.md 13.11) exist with
## the spec's values, and the states and hurt kind the appendix names are appended after the 1.0 values.
func test_physics_appendix_c_constant_sheet() -> void:
	# Defs: states outside the 4.3 table, the versus hurt kind; the 1.0 values unchanged.
	assert_ints_eq([Defs.HeroState.IDLE, Defs.HeroState.HURT], [0, 8])
	assert_ints_eq([Defs.HeroState.CLIMB, Defs.HeroState.CURL, Defs.HeroState.RIDING], [9, 10, 11])
	for flags: int in Tuning.STATE_LUT.size():
		assert_true(int(Tuning.STATE_LUT[flags]) <= Defs.HeroState.HURT, "the state table never yields a 2.0 state")
	assert_ints_eq([Defs.HurtKind.ENEMY, Defs.HurtKind.BOSS_BODY, Defs.HurtKind.BOSS_PROJECTILE, Defs.HurtKind.TRAP,
		Defs.HurtKind.RIVAL], [0, 1, 2, 3, 4])
	# Tuning (C.3 - C.7).
	assert_ints_eq([Tuning.SPEAR_FALL_MAX, Tuning.SPEAR_BOX_W, Tuning.SPEAR_BOX_H, Tuning.SPEAR_BOX_XO],
		[192, 24, 6, 12])
	assert_ints_eq([Tuning.VINE_HAND_REACH_PX, Tuning.VINE_REGRAB_LOCK_TICKS, Tuning.VINE_TOP_STEP_PX], [32, 12, 12])
	assert_ints_eq([Tuning.GEYSER_PERIOD, Tuning.GEYSER_PERIOD_MIN, Tuning.GEYSER_VENT_W, Tuning.GEYSER_VENT_H,
		Tuning.GEYSER_DEADLY_H], [88, 34, 24, 16, 64])
	assert_ints_eq([Tuning.RAFT_SPEED_CAP, Tuning.RAFT_HEIGHT_PX, Tuning.RAFT_FLOAT_DEPTH_PX], [48, 8, 4])
	# PartyTuning (C.10 - C.13, GAMEPLAY 13.9).
	assert_ints_eq([PartyTuning.TOTEM_HEAD_PX, PartyTuning.TOTEM_REST_PX, PartyTuning.TOTEM_FOOT_REACH_PX,
		PartyTuning.TOTEM_JUMP_OFF_YVEL, PartyTuning.TOTEM_DROP_LOCK_TICKS, PartyTuning.TOTEM_THROW_OFF_YVEL],
		[35, 34, 16, -16, 12, -64])
	assert_ints_eq([PartyTuning.CURL_BOX_W, PartyTuning.CURL_BOX_H, PartyTuning.CURL_BOX_XO], [24, 20, 12])
	assert_ints_eq([PartyTuning.EGG_BOX_W, PartyTuning.EGG_BOX_H, PartyTuning.EGG_BOX_XO, PartyTuning.EGG_OFFSET_X,
		PartyTuning.EGG_OFFSET_Y, PartyTuning.EGG_DRIFT_PX, PartyTuning.EGG_DRIFT_FAST_PX, PartyTuning.EGG_DRIFT_FAR_PX,
		PartyTuning.EGG_NUDGE_PX, PartyTuning.EGG_VIEW_INSET_PX, PartyTuning.EGG_RETURN_SPEED_PX],
		[24, 24, 12, -24, -48, 2, 6, 64, 1, 16, 6])
	assert_true(PartyTuning.EGG_RETURN_SPEED_PX <= PartyTuning.MOVE_MAX_PX_PER_TICK, "an egg stays in the doze reach")
	assert_ints_eq([PartyTuning.PULL_IN_BEHIND_PX, PartyTuning.TARGET_HOLD_TICKS, PartyTuning.LONE_KEEP_AWAY_PX,
		PartyTuning.LONE_CIRCLE_WIDER_PX, PartyTuning.PLATE_WEIGHT_BOULDER, PartyTuning.PULLEY_RANGE_ROWS],
		[24, 22, 64, 32, 2, 3])
	# Phase 2 rows (P2.6, asked by world-A and enemies-A): C.13 keep-the-head margin, the count-in spacing of 13.9.3.
	assert_ints_eq([PartyTuning.CAM_KEEP_HEAD_PX, PartyTuning.COUNT_IN_SPACING_TICKS, PartyTuning.COUNT_IN_BEEPS],
		[32, 8, 3])
	# The lee of C.6 / C.16 ("64 px downwind, 16 px vertical", asked by world-A in phase 2).
	assert_ints_eq([PartyTuning.LEE_REACH_PX, PartyTuning.LEE_DY_PX], [64, 16])
	# VersusTuning (C.14, GAMEPLAY 13.10 / 13.11).
	assert_ints_eq([VersusTuning.HURT_TIMER_TICKS, VersusTuning.STUN_HIT_TIMER_MIN], [43, 31])
	# Set to 43 on the hit tick; the following ticks see 42 .. 31 (12 stunned), then 30 .. 1 (30 immune with control).
	assert_eq(VersusTuning.HURT_TIMER_TICKS - VersusTuning.STUN_HIT_TIMER_MIN, VersusTuning.STUN_TICKS,
		"12 stunned ticks ...")
	assert_eq(VersusTuning.STUN_HIT_TIMER_MIN - 1, VersusTuning.IMMUNE_TICKS, "... then 30 immune")
	assert_ints_eq([VersusTuning.CLANG_PUSH_EACH_PX, VersusTuning.STOMP_IMMUNE_TICKS, VersusTuning.TEAMMATE_BUMP_XVEL,
		VersusTuning.CURL_GLANCE_ABOVE_PX, VersusTuning.BODY_KNOCK_XVEL, VersusTuning.BODY_KNOCK_YVEL],
		[8, 30, 32, 16, 64, -64])
	assert_ints_eq([VersusTuning.HOT_ROCK_FIRST_PICK_TICKS, VersusTuning.HOT_ROCK_REPICK_TICKS,
		VersusTuning.BALL_ROLL_LOSS, VersusTuning.GIANT_BONK_DAZE_TICKS, VersusTuning.ARENA_FILE_ROWS],
		[66, 66, 2, 12, 12])
	# The look of a player (join panel / lobby -> hero palette, HUD): the slot default until someone picks one.
	var run: PlayerRun = PlayerRun.new(1)
	assert_eq(run.palette, &"", "the slot's default colour")
	assert_eq(run.pattern, -1, "the slot's default pattern")
	run.palette = &"pink"
	run.reset_run()
	assert_eq(run.palette, &"pink", "a new run keeps the players' colours")


# =================================================================================================================
# PartyTuning
# =================================================================================================================

func test_party_seconds_follow_the_design_conversion() -> void:
	var seconds: Dictionary = {
		"leash Beginner": [PartyTuning.LEASH_EGG_TICKS_BEGINNER, 5.0],
		"leash Expert": [PartyTuning.LEASH_EGG_TICKS_EXPERT, 3.0],
		"egg return": [PartyTuning.EGG_RETURN_TICKS_EXPERT, 10.0],
		"voluntary egg": [PartyTuning.VOLUNTARY_EGG_HOLD_TICKS, 1.0],
		"gate solve": [PartyTuning.GATE_SOLVE_TICKS, 30.0],
		"join ready": [PartyTuning.JOIN_READY_HOLD_TICKS, 1.0],
	}
	for key: String in seconds:
		var entry: Array = seconds[key]
		assert_eq(int(entry[0]), Tuning.seconds_to_ticks(float(entry[1])), key)


func test_party_rules_agree_with_the_1_0_rules() -> void:
	assert_eq(PartyTuning.COOP_PLAYERS, 2)
	assert_true(PartyTuning.COOP_PLAYERS <= Defs.MAX_PLAYERS)
	assert_eq(PartyTuning.TRIBE_LIVES_START, Tuning.LIVES_START)
	assert_eq(PartyTuning.CAM_FRONT_START_COL, 16)
	assert_eq(PartyTuning.CAM_FRONT_START_COL_LEFT, 4)
	assert_eq(PartyTuning.CAM_FRONT_STOP_COL, 5)
	assert_eq(PartyTuning.CAM_REAR_MARGIN_COL, 1)
	assert_eq(PartyTuning.CAM_REAR_MARGIN_COL_LEFT, 18, "column 1 mirrored on the 20-column view")
	assert_eq(PartyTuning.GATE_PARTNER_RANGE_PX, Tuning.VIEW_COLS * Tuning.TILE, "one screen")
	assert_eq(PartyTuning.EGG_SCOUT_RADIUS_PX, 2 * Tuning.TILE)
	assert_eq(PartyTuning.SHOULDER_HOP_YVEL, Tuning.BOUNCE_YVEL_UP)
	var rise: int = 0
	var yvel: int = PartyTuning.SHOULDER_HOP_YVEL
	while yvel < 0:
		rise -= Tuning.floor16(yvel)
		yvel += Tuning.GRAVITY
	assert_eq(rise, PartyTuning.SHOULDER_HOP_RISE_PX, "a head bounce with Up held rises 105 px")
	assert_eq(PartyTuning.PLATE_COLUMN_PERIOD, Tuning.COLUMN_RISE_PERIOD)
	assert_eq(PartyTuning.CURL_LANDING_TICKS, 6)
	var ladder_top: int = Tuning.BOUNCE_MULTIPLIER[Tuning.BOUNCE_MULTIPLIER.size() - 1]
	assert_ints_eq(PartyTuning.RELAY_BOUNCE_MULTIPLIERS, [10, 12])
	assert_true(PartyTuning.RELAY_BOUNCE_MULTIPLIERS[0] > ladder_top, "Relay Bounce extends the ladder")


func test_party_launches_respect_the_doze_reach() -> void:
	# DESIGN.md D.4: a launch moves at most 18 px/tick per axis (or calls LevelBase.notify_hero_teleported).
	var launches: Dictionary = {
		"shoulder hop": PartyTuning.SHOULDER_HOP_YVEL, "line drive x": PartyTuning.BAT_LINE_DRIVE_XVEL,
		"line drive y": PartyTuning.BAT_LINE_DRIVE_YVEL, "lob x": PartyTuning.BAT_LOB_XVEL,
		"lob y": PartyTuning.BAT_LOB_YVEL, "grounder": PartyTuning.BAT_GROUNDER_XVEL,
		"see-saw cap": PartyTuning.SEESAW_LAUNCH_CAP,
	}
	for key: String in launches:
		var v16: int = int(launches[key])
		assert_true(absi(v16) / Tuning.V16_PER_PX <= PartyTuning.MOVE_MAX_PX_PER_TICK, "%s: %d v16" % [key, v16])
	assert_eq(PartyTuning.BAT_GROUNDER_XVEL, 6 * Tuning.V16_PER_PX)
	assert_eq(absi(PartyTuning.SEESAW_LAUNCH_CAP), PartyTuning.MOVE_MAX_PX_PER_TICK * Tuning.V16_PER_PX)


func test_party_helpers_per_difficulty() -> void:
	var b: int = Defs.Difficulty.BEGINNER
	var e: int = Defs.Difficulty.EXPERT
	assert_eq(PartyTuning.window_ticks(b), 24)
	assert_eq(PartyTuning.window_ticks(e), 12)
	assert_eq(PartyTuning.window_ticks(b, 20), 16, "never longer than the solo minimum minus 4")
	assert_eq(PartyTuning.window_ticks(e, 30), 12)
	assert_eq(PartyTuning.window_ticks(b, 3), 0)
	assert_eq(PartyTuning.leash_egg_ticks(b), 121)
	assert_eq(PartyTuning.leash_egg_ticks(e), 73)
	assert_eq(PartyTuning.hatch_hearts(b), 2)
	assert_eq(PartyTuning.hatch_hearts(e), 1)
	assert_eq(PartyTuning.egg_return_ticks(b), -1, "Beginner: the egg follows forever")
	assert_eq(PartyTuning.egg_return_ticks(e), 243)
	assert_eq(PartyTuning.daze_ticks(b), 14)
	assert_eq(PartyTuning.daze_ticks(e), 12)
	assert_eq(PartyTuning.boost_ledge_tiles(b), 8, "G39: 8 rows on Beginner too")
	assert_eq(PartyTuning.IDLE_TICKS, 243, "G33: the idle partner, 10 s")
	assert_eq(PlayerBase.IDLE_TICKS, PartyTuning.IDLE_TICKS)
	assert_eq(PartyTuning.IDLE_WARN_TICKS, 170, "G58: the \"Zzz soon\" bubble shows 73 ticks (3 s) before the doze")
	assert_eq(HeroParty.IDLE_WARN_TICKS, PartyTuning.IDLE_WARN_TICKS, "the bubble draws by the table's value")
	assert_eq(PartyTuning.boost_ledge_tiles(e), 8)
	assert_false(PartyTuning.lone_trait_on(b))
	assert_true(PartyTuning.lone_trait_on(e))
	assert_false(PartyTuning.boss_grabs_on(b))
	assert_true(PartyTuning.boss_grabs_on(e))


func test_party_formulas() -> void:
	assert_eq(PartyTuning.seesaw_launch(128, false), -160, "-(landing yvel + 32)")
	assert_eq(PartyTuning.seesaw_launch(192, false), -224)
	assert_eq(PartyTuning.seesaw_launch(192, true), -288, "+64 on a hard landing")
	assert_eq(PartyTuning.seesaw_launch(320, true), PartyTuning.SEESAW_LAUNCH_CAP, "capped")
	assert_eq(PartyTuning.bat_charged(PartyTuning.BAT_LINE_DRIVE_XVEL), 216, "x1.5")
	assert_eq(PartyTuning.bat_charged(PartyTuning.BAT_LOB_YVEL), -360)
	assert_eq(PartyTuning.boss_coop_hp_max(64), 80, "the Brute: 64 -> 80 (DESIGN.md B.7)")
	assert_eq(PartyTuning.boss_coop_hp_max(24), 30, "the Colossus: 24 -> 30")


# =================================================================================================================
# VersusTuning
# =================================================================================================================

func test_versus_seconds_follow_the_design_conversion() -> void:
	var seconds: Dictionary = {
		"KO credit": [VersusTuning.KO_CREDIT_TICKS, 3.0],
		"stack round": [VersusTuning.STACK_ROUND_TICKS, 90.0],
		"stack round 2p": [VersusTuning.STACK_ROUND_TICKS_2P, 60.0],
		"spot refill": [VersusTuning.SPOT_REFILL_TICKS, 15.0],
		"spot sparkle": [VersusTuning.SPOT_SPARKLE_TICKS, 2.0],
		"crate period": [VersusTuning.CRATE_PERIOD_TICKS, 20.0],
		"feast": [VersusTuning.FEAST_TICKS, 8.0],
		"feast rush": [VersusTuning.FEAST_RUSH_TICKS, 15.0],
		"sudden death": [VersusTuning.SUDDEN_DEATH_AT_TICKS, 60.0],
		"grudge rock": [VersusTuning.GRUDGE_ROCK_PERIOD_TICKS, 3.0],
		"fuse min": [VersusTuning.HOT_ROCK_FUSE_MIN_TICKS, 12.0],
		"fuse max": [VersusTuning.HOT_ROCK_FUSE_MAX_TICKS, 20.0],
		"fuse hurry": [VersusTuning.HOT_ROCK_HURRY_TICKS, 3.0],
		"clubball match": [VersusTuning.CLUBBALL_MATCH_TICKS, 180.0],
		"mother rex": [VersusTuning.EGG_MOTHER_CHASE_TICKS, 8.0],
		"mayhem crates": [VersusTuning.MAYHEM_CRATE_PERIOD_TICKS, 8.0],
		"stampede": [VersusTuning.STAMPEDE_PERIOD_TICKS, 3.0],
		"echo dark period": [VersusTuning.ECHO_DARK_PERIOD_TICKS, 20.0],
		"echo dark": [VersusTuning.ECHO_DARK_TICKS, 3.0],
		"echo walls": [VersusTuning.ECHO_WALL_REGROW_TICKS, 15.0],
		"whiteout": [VersusTuning.WHITEOUT_STEP_TICKS, 5.0],
		"colossus spit": [VersusTuning.COLOSSUS_SPIT_PERIOD_TICKS, 10.0],
		"rodeo": [VersusTuning.RODEO_CHOMPER_PERIOD_TICKS, 30.0],
		"bot idle": [VersusTuning.BOT_IDLE_MAX_TICKS, 10.0],
		"ready": [VersusTuning.READY_HOLD_TICKS, 1.0],
		"deciding moment": [VersusTuning.DECIDING_REPLAY_TICKS, 3.0],
		"scoreboard": [VersusTuning.SCOREBOARD_TICKS, 5.0],
	}
	for key: String in seconds:
		var entry: Array = seconds[key]
		assert_eq(int(entry[0]), Tuning.seconds_to_ticks(float(entry[1])), key)


func test_versus_tables_fit_the_contract() -> void:
	assert_eq(VersusTuning.PLAYERS_MIN, 2)
	assert_eq(VersusTuning.PLAYERS_MAX, Defs.MAX_PLAYERS)
	assert_eq(VersusTuning.BOT_REACTION_TICKS.size(), Defs.BotLevel.size())
	assert_ints_eq(VersusTuning.BOT_REACTION_TICKS, [10, 6, 3], "Rookie, Hunter, Chief")
	assert_eq(VersusTuning.bot_reaction_ticks(Defs.BotLevel.HUNTER), 6)
	assert_eq(VersusTuning.SPECIAL_THROWS[Defs.Weapon.CLUB], 0)
	assert_eq(VersusTuning.SPECIAL_THROWS[Defs.Weapon.AXE], 3)
	assert_eq(VersusTuning.SPECIAL_THROWS[Defs.Weapon.BOOMERANG], 2)
	assert_eq(VersusTuning.SPECIAL_THROWS[Defs.Weapon.SPEAR], 3)
	var ladder: Array[int] = []
	for multiplier: int in Tuning.BOUNCE_MULTIPLIER:
		if not ladder.has(multiplier):
			ladder.append(multiplier)
	assert_ints_eq(VersusTuning.STOMP_LADDER, ladder, "the stomp ladder is the head-bounce ladder 1-2-3-4-6-8")
	assert_eq(VersusTuning.ARENA_COLS, Tuning.VIEW_COLS)
	assert_eq(VersusTuning.ARENA_ROWS, Tuning.VIEW_ROWS)
	assert_eq(VersusTuning.ARENA_FLOOR_ROW, VersusTuning.ARENA_ROWS - 1)
	assert_true(VersusTuning.HOT_ROCK_FUSE_MIN_TICKS < VersusTuning.HOT_ROCK_FUSE_MAX_TICKS)
	assert_true(VersusTuning.BALL_KNOCKDOWN_SPEED_EXCL < VersusTuning.BALL_MAX_SPEED)
	# GAMEPLAY.md 13.10.6 shots (P2.7, the coconut): drive (144, -128), lob (32, -240), grounder (96, 0); a floor
	# bounce while yvel >= 32; a head bounce at least -96. Every component within the launch axis cap.
	assert_ints_eq([VersusTuning.BALL_DRIVE_XVEL, VersusTuning.BALL_DRIVE_YVEL, VersusTuning.BALL_LOB_XVEL,
			VersusTuning.BALL_LOB_YVEL, VersusTuning.BALL_GROUNDER_XVEL, VersusTuning.BALL_BOUNCE_MIN_YVEL,
			VersusTuning.BALL_HEAD_BOUNCE_MIN_YVEL], [144, -128, 32, -240, 96, 32, -96], "the coconut's shots")
	for value: int in [VersusTuning.BALL_DRIVE_XVEL, VersusTuning.BALL_DRIVE_YVEL, VersusTuning.BALL_LOB_YVEL,
			VersusTuning.BALL_GROUNDER_XVEL, VersusTuning.BALL_MAX_SPEED]:
		assert_true(absi(value) <= PartyTuning.LAUNCH_AXIS_CAP, "a shot stays within the axis cap (%d)" % value)
	assert_true(VersusTuning.STACK_GUARD_PERCENT.has(100))
	assert_eq(VersusTuning.LCS_HEART_BONES, Tuning.BONES_PER_HEART)
	var telegraphs: Array[int] = [VersusTuning.CRATE_SHADOW_TICKS, VersusTuning.STAMPEDE_DUST_TICKS,
		VersusTuning.RODEO_RUMBLE_TICKS, VersusTuning.LIGHTNING_MARK_TICKS, VersusTuning.COLOSSUS_JAWS_TICKS,
		VersusTuning.GRUDGE_SQUAWK_TICKS]
	for ticks: int in telegraphs:
		assert_true(ticks >= Tuning.TELEGRAPH_MIN_TICKS, "every versus hazard telegraphs 10+ ticks ahead (%d)" % ticks)


func test_versus_formulas() -> void:
	assert_eq(VersusTuning.round_seed(7, 2), 7 * 31 + 2)
	assert_eq(VersusTuning.stack_round_ticks(2), 1457)
	assert_eq(VersusTuning.stack_round_ticks(3), 2185)
	assert_eq(VersusTuning.stack_round_ticks(4), 2185)
	assert_eq(VersusTuning.spill(0, VersusTuning.SPILL_HIT_DIV), 0)
	assert_eq(VersusTuning.spill(1, VersusTuning.SPILL_HIT_DIV), 1)
	assert_eq(VersusTuning.spill(10, VersusTuning.SPILL_HIT_DIV), 3, "1 + stack / 5")
	assert_eq(VersusTuning.spill(10, VersusTuning.SPILL_CHARGED_DIV), 6, "1 + stack / 2")
	assert_eq(VersusTuning.spill(10, VersusTuning.SPILL_THROWN_DIV), 2, "1 + stack / 8")
	assert_eq(VersusTuning.spill(1, VersusTuning.SPILL_CHARGED_DIV), 1, "never more than the stack")
	assert_eq(VersusTuning.stomp_steal(1, false), 1)
	assert_eq(VersusTuning.stomp_steal(5, false), 6)
	assert_eq(VersusTuning.stomp_steal(40, false), 8, "past the end: the ladder's top")
	assert_eq(VersusTuning.stomp_steal(2, true), 4, "a banking hero loses double")
	assert_eq(VersusTuning.stack_walk_cap(0), Tuning.WALK_CAP)
	assert_eq(VersusTuning.stack_walk_cap(10), 64)
	assert_eq(VersusTuning.stack_walk_cap(19), 64)
	assert_eq(VersusTuning.stack_walk_cap(20), 48)


# =================================================================================================================
# Events
# =================================================================================================================

## Argument names of every Events signal, by signal name.
func _signal_args() -> Dictionary:
	var result: Dictionary = {}
	for entry: Dictionary in Events.get_signal_list():
		var names: PackedStringArray = PackedStringArray()
		for arg: Dictionary in entry["args"]:
			names.append(str(arg["name"]))
		result[str(entry["name"])] = names
	return result


func test_1_0_events_are_unchanged() -> void:
	var args: Dictionary = _signal_args()
	var frozen: Dictionary = {
		"player_spawned": ["player"], "player_hurt": ["kind", "source"], "player_died": ["cause"],
		"player_death_finished": [], "player_landed": ["hard", "shake"], "player_jumped": [],
		"player_struck": ["strike", "weapon"], "player_bounced": ["target", "multiplier"],
		"glider_state_changed": ["carrying", "gliding"], "enemy_hit": ["enemy", "power"],
		"enemy_killed": ["enemy", "points", "cause"], "boss_started": ["boss"],
		"boss_energy_changed": ["boss", "pips", "max_pips"], "boss_defeated": ["boss"],
		"item_collected": ["item_id", "index", "points", "pos"], "hittable_hit": ["hittable", "opened"],
		"hidden_spot_opened": ["pos", "kind"], "secret_found": ["zone_name"], "checkpoint_activated": ["checkpoint"],
		"exit_unlocked": [], "exit_reached": ["exit_kind"], "gate_used": ["from_pos", "to_pos"],
		"shake_requested": ["amount"], "feast_changed": ["ticks"], "darkness_changed": ["dark"],
		"popup_requested": ["kind", "value", "pos"], "wind_changed": ["wind"], "time_left_changed": ["seconds"],
		"message_requested": ["source", "text"], "level_started": ["level_id"],
		"level_completed": ["level_id", "exit_kind"], "pause_changed": ["paused"], "level_respawned": [],
		"game_over": [],
	}
	for name: String in frozen:
		assert_true(args.has(name), "Events.%s exists" % name)
		if args.has(name):
			assert_eq(Array(args[name]), frozen[name], "Events.%s arguments" % name)


func test_hero_twins_carry_the_hero_first() -> void:
	var args: Dictionary = _signal_args()
	var twins: Dictionary = {
		"hero_hurt": "player_hurt", "hero_died": "player_died", "hero_death_finished": "player_death_finished",
		"hero_landed": "player_landed", "hero_jumped": "player_jumped", "hero_struck": "player_struck",
		"hero_bounced": "player_bounced", "hero_glider_state_changed": "glider_state_changed",
		"hero_feast_changed": "feast_changed",
	}
	for twin: String in twins:
		assert_true(args.has(twin), "Events.%s exists" % twin)
		if args.has(twin):
			var expected: Array = ["hero"]
			expected.append_array(Array(args[twins[twin]]))
			assert_eq(Array(args[twin]), expected, "Events.%s = (hero, %s's arguments)" % [twin, twins[twin]])


func test_party_round_and_painting_events() -> void:
	var args: Dictionary = _signal_args()
	var added: Dictionary = {
		"hero_down": ["hero", "cause"], "hero_revived": ["hero", "by"], "party_wiped": [],
		"hero_ko": ["victim", "killer", "cause"], "round_countdown": ["round_index", "count"],
		"round_started": ["round_index"], "round_feast_rush_started": ["round_index"],
		"round_sudden_death_started": ["round_index", "kind"], "round_ended": ["round_index", "winner_slots"],
		"painting_found": ["index"],
	}
	for name: String in added:
		assert_true(args.has(name), "Events.%s exists" % name)
		if args.has(name):
			assert_eq(Array(args[name]), added[name], "Events.%s arguments" % name)


# =================================================================================================================
# Sfx
# =================================================================================================================

func test_sfx_names_are_unique_and_every_2_0_name_is_listed() -> void:
	var constants: Dictionary = (load("res://scripts/core/sfx.gd") as GDScript).get_script_constant_map()
	var effects: Dictionary = {}
	var music: Dictionary = {}
	for key: String in constants:
		if key.begins_with("EXPANSION_"):
			continue
		var value: StringName = constants[key]
		var group: Dictionary = music if key.begins_with("MUSIC_") else effects
		assert_false(group.has(value), "Sfx.%s = &\"%s\" is used once" % [key, value])
		group[value] = key
	for event: StringName in Sfx.EXPANSION_SFX:
		assert_true(effects.has(event), "EXPANSION_SFX lists the effect %s" % event)
	for context: StringName in Sfx.EXPANSION_MUSIC:
		assert_true(music.has(context), "EXPANSION_MUSIC lists the context %s" % context)
	for event: StringName in effects:
		assert_true(AudioTable.SFX.has(event) or Sfx.EXPANSION_SFX.has(event),
			"%s has an AudioTable row or is a listed 2.0 name" % event)
	for context: StringName in music:
		assert_true(AudioTable.MUSIC.has(context) or Sfx.EXPANSION_MUSIC.has(context),
			"%s has an AudioTable row or is a listed 2.0 context" % context)
	for event: StringName in AudioTable.SFX:
		assert_true(effects.has(event), "the 1.0 effect %s is still a Sfx name" % event)
	for context: StringName in AudioTable.MUSIC:
		assert_true(music.has(context), "the 1.0 context %s is still a Sfx name" % context)
	assert_eq(Sfx.EXPANSION_SFX.size(), 35,
			"the 32 effects of DESIGN.md F.2, the versus clang (E.2), the lightning bolt and the round gong (P2.6)")
	assert_eq(Sfx.EXPANSION_MUSIC.size(), 30)

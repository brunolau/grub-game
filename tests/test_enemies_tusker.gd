extends TestCase
## Tusker, the Boar King (scripts/bosses/tusker.gd; DESIGN.md B.1, GAMEPLAY.md 13.6; PLAN.md P2.2, owner enemies-B) on
## its test level levels/test_enemies_tusker.lvl, loaded into the real level scene with the real hero(es).
##
## Pinned here (DESIGN.md B.0): every attack shows itself 10+ ticks ahead; every attack can be escaped; hits never
## stop or lengthen its states (no stun-lock) and count at most once per BOSS_HIT_COOLDOWN whoever lands them; the
## club beats the solo form on a scripted route (Beginner and Expert); the co-op form's weak window for one hero is
## shorter than his measured solo minimum; the single-hero search cannot hurt the co-op form.
##
## The inner class [Lab] (a level file in the real level scene, scripted heroes, recorded and replayed input streams)
## is shared by tests/test_enemies_mangrove.gd and tests/test_enemies_squid.gd (`preload(...).Lab`).

const LEVEL_PATH: String = "res://levels/test_enemies_tusker.lvl"
const BOSS_ID: String = "bosses/tusker"


## A boss test level in the real level scene (scenes/world/level.tscn) with real heroes driven by scripted input:
## every tick's flags per player slot are recorded, so a fight a policy played can be replayed as a plain route.
class Lab:
	extends RefCounted

	const LEVEL_SCENE: String = "res://scenes/world/level.tscn"
	const VIEW_ART: Vector2i = Vector2i(640, 360)

	var level: Level = null
	var boss: BossBase = null
	## Recorded input per player slot (index = tick of the fight, 0 = the first tick after open()).
	var streams: Array[PackedInt32Array] = []
	var party: int = 1
	var _first_tick: int = 0
	var _owner: TestCase = null

	## Load `path` (the boss record `boss_id` gets `form=coop` when `coop_form`) for `party` heroes (2 = a co-op
	## game) in `difficulty`, every hero holding `weapon`. False when the level or its boss did not come up.
	func open(owner: TestCase, path: String, boss_id: String, difficulty: int, p_party: int = 1,
			coop_form: bool = false, weapon: int = Defs.Weapon.CLUB, extra: String = "") -> bool:
		_owner = owner
		party = p_party
		Sim.manual = true
		if party > 1:
			Game.start_run(difficulty, Defs.GameMode.COOP, party, 2)
		else:
			Game.start_run(difficulty, Defs.GameMode.SINGLE, 1, 2)
		var text: String = with_boss_params(FileAccess.get_file_as_string(path), boss_id,
				("form=coop " if coop_form else "") + extra)
		var id: StringName = StringName(path.get_file().get_basename())
		Game.begin_level(id)
		for slot: int in party:
			Game.runs[slot].set_weapon(weapon)
		level = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level
		level.setup_from_text(id, text)
		owner.add_node(level)
		level.set_view_size(VIEW_ART)
		for entity: SimEntity in level.get_kind(Defs.Kind.BOSS):
			boss = entity as BossBase
		streams.clear()
		for slot: int in party:
			streams.append(PackedInt32Array())
			GameInput.set_scripted_slot(slot, _flag_of.bind(slot))
		_first_tick = Sim.tick + 1
		return boss != null and level.hero_count() == party

	## `text` with `params` (space-separated key=value pairs) appended to every entity line of `boss_id` (after
	## its col and row, where the level format reads parameters).
	static func with_boss_params(text: String, boss_id: String, params: String) -> String:
		params = params.strip_edges()
		if params == "":
			return text
		var lines: PackedStringArray = text.split("\n")
		for i: int in lines.size():
			var line: String = lines[i].strip_edges(false, true)
			if line.begins_with(boss_id + " "):
				lines[i] = "%s %s" % [line, params]
		return "\n".join(lines)

	func hero(slot: int = 0) -> PlayerBase:
		return level.get_hero(slot) if level != null else null

	## One tick with `flags[slot]` for every slot (recorded).
	func step(flags: PackedInt32Array) -> void:
		for slot: int in party:
			streams[slot].append(flags[slot] if slot < flags.size() else 0)
		Sim.step(1)

	## Ticks played since open().
	func ticks() -> int:
		return streams[0].size() if not streams.is_empty() else 0

	## Play recorded `runs` (one stream per slot) from the current tick to their end (stops early when `until`
	## returns true). Returns the ticks played.
	func play(runs: Array[PackedInt32Array], until: Callable = Callable()) -> int:
		var length: int = 0
		for run: PackedInt32Array in runs:
			length = maxi(length, run.size())
		var played: int = 0
		var frame: PackedInt32Array = PackedInt32Array()
		frame.resize(party)
		while played < length:
			for slot: int in party:
				frame[slot] = runs[slot][played] if slot < runs.size() and played < runs[slot].size() else 0
			step(frame)
			played += 1
			if until.is_valid() and bool(until.call()):
				break
		return played

	func _flag_of(tick: int, slot: int) -> int:
		var index: int = tick - _first_tick
		var stream: PackedInt32Array = streams[slot]
		return stream[index] if index >= 0 and index < stream.size() else 0

	## Keep a hero alive and topped up (watch tests: the boss is observed, not survived).
	static func top_up(hero_node: PlayerBase) -> void:
		if hero_node == null:
			return
		hero_node.run.hearts = Tuning.ENERGY_START
		hero_node.run.bones = 0

	## Flags as route keys (L R U D F), for messages and the recorded routes.
	static func keys(flags: int) -> String:
		var text: String = ""
		for pair: Array in [[Defs.IN_LEFT, "L"], [Defs.IN_RIGHT, "R"], [Defs.IN_UP, "U"], [Defs.IN_DOWN, "D"],
				[Defs.IN_FIRE, "F"], [Defs.IN_LOOK, "K"], [Defs.IN_SWAP, "S"]]:
			if flags & int(pair[0]):
				text += str(pair[1])
		return text

	## A stream as a run-length route text ("12:R,4:RU,...").
	static func route_text(stream: PackedInt32Array) -> String:
		var runs: PackedStringArray = PackedStringArray()
		var value: int = -1
		var count: int = 0
		for t: int in stream.size() + 1:
			if t < stream.size() and stream[t] == value:
				count += 1
				continue
			if count > 0:
				runs.append("%d:%s" % [count, keys(value)])
			if t < stream.size():
				value = stream[t]
				count = 1
		return ",".join(runs)

	## The inverse of [method route_text].
	static func parse_route(text: String) -> PackedInt32Array:
		var flags: PackedInt32Array = PackedInt32Array()
		for part: String in text.split(",", false):
			var colon: int = part.find(":")
			var count: int = part.substr(0, colon).to_int()
			var value: int = GameInput.keys_to_flags(part.substr(colon + 1))
			for i: int in count:
				flags.append(value)
		return flags


var _lab: Lab = null
var _was_manual: bool = false


func before_each() -> void:
	_was_manual = Sim.manual
	_lab = Lab.new()


func after_each() -> void:
	GameInput.clear_scripted()
	Sim.stop()
	Sim.manual = _was_manual
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"")
	Audio.stop_music(0.0)
	_lab = null


func _open(difficulty: int = Defs.Difficulty.BEGINNER, party: int = 1, coop_form: bool = false) -> Tusker:
	assert_true(_lab.open(self, LEVEL_PATH, BOSS_ID, difficulty, party, coop_form), "the test level came up")
	return _lab.boss as Tusker


# =================================================================================================================
# Basics
# =================================================================================================================

func test_tusker_loads_with_its_hit_points_and_starts_in_its_arena() -> void:
	var boar: Tusker = _open()
	if boar == null:
		return
	assert_false(boar.coop_form)
	assert_eq(boar.max_hp, Tusker.TUSKER_HP_BEGINNER, "Beginner 150 = 6 club hits")
	assert_eq(boar.get_max_pips(), 6)
	assert_eq(boar.music, Sfx.MUSIC_BOSS_TUSKER)
	assert_eq(boar.boss_drops, [&"fire_starter"] as Array[StringName])
	_lab.step(PackedInt32Array([0]))
	assert_true(boar.fighting, "the hero starts inside the arena zone")
	var paw_at: int = -1
	for t: int in 80:
		_lab.step(PackedInt32Array([0]))
		if paw_at < 0 and boar.get_state() == Tusker.State.PAW:
			paw_at = t + 2
	assert_eq(paw_at, Tusker.TUSKER_IDLE_TICKS + 1, "after the 44-tick idle it paws at the hero")
	assert_eq(boar.facing, -1, "facing him (he waits on the left bank)")


func test_hit_points_of_every_form_and_difficulty() -> void:
	var cases: Array = [
		[Defs.Difficulty.BEGINNER, false, 150], [Defs.Difficulty.EXPERT, false, 225],
		[Defs.Difficulty.BEGINNER, true, 187], [Defs.Difficulty.EXPERT, true, 280],
	]
	for case: Array in cases:
		var lab: Lab = Lab.new()
		assert_true(lab.open(self, LEVEL_PATH, BOSS_ID, int(case[0]), 1, bool(case[1])))
		var boar: Tusker = lab.boss as Tusker
		assert_eq(boar.coop_form, bool(case[1]))
		assert_eq(boar.max_hp, int(case[2]), "difficulty %d, co-op %s" % [case[0], case[1]])
		lab.level.free()
	assert_true(Tusker.TUSKER_COOP_HP_BEGINNER * PartyTuning.BOSS_HP_MAX_DEN
			<= Tusker.TUSKER_HP_BEGINNER * PartyTuning.BOSS_HP_MAX_NUM, "a co-op form has at most 5/4 of the solo hp")
	assert_true(Tusker.TUSKER_COOP_HP_EXPERT * PartyTuning.BOSS_HP_MAX_DEN
			<= Tusker.TUSKER_HP_EXPERT * PartyTuning.BOSS_HP_MAX_NUM)


func test_the_head_is_open_only_while_it_lies_dizzy_or_stuck_and_bounces_never_hurt() -> void:
	var boar: Tusker = _open()
	var hero: PlayerBase = _lab.hero()
	_lab.step(PackedInt32Array([0]))
	_shot_at(boar.get_head_rect())
	_lab.step(PackedInt32Array([0]))
	assert_eq(boar.hp, boar.max_hp, "closed: the head glances")
	boar._set_state(Tusker.State.DIZZY)
	boar._dizzy_len = 100
	_shot_at(boar.get_head_rect())
	_lab.step(PackedInt32Array([0]))
	assert_eq(boar.hp, boar.max_hp - 20, "dizzy: an axe on the head counts (power 20)")
	_shot_at(boar.get_head_rect())
	_lab.step(PackedInt32Array([0]))
	assert_eq(boar.hp, boar.max_hp - 20, "the next hit waits for the 22-tick cooldown")
	# A landing on top bounces the hero and harms nobody.
	boar._set_state(Tusker.State.IDLE)
	hero.teleport(boar.sim_pos + Vector2i(0, -boar.box_h + 4))
	hero.yvel = 64
	var hp: int = boar.hp
	var hearts: int = hero.run.hearts
	_lab.step(PackedInt32Array([0]))
	assert_true(hero.yvel < 0, "bounced off its back")
	assert_eq(boar.hp, hp)
	assert_eq(hero.run.hearts, hearts)
	assert_eq(hero.hit_timer, 0)


# =================================================================================================================
# B.0 fairness: telegraphs, escapes, no stun-lock
# =================================================================================================================

## The whole Expert fight played by the club bot (all three phases, rocks included), watched tick by tick: every charge
## comes after 22 ticks of pawing, every roll after the 14-tick squeal, every rock after a 14-tick dust trickle in its
## column, the hop's landing after its whole flight (its rise is the warning) - none of them less than 10 ticks.
func test_every_attack_shows_itself_10_ticks_ahead() -> void:
	var watch: Dictionary = _watch_fight(Defs.Difficulty.EXPERT)
	print("    Tusker telegraphs (Expert club fight, %d ticks): paw before a charge %s, squeal before a roll %s, dust before a rock %s, hop flight %s" % [
		watch["ticks"], watch["paw"], watch["squeal"], watch["dust"], watch["hop"]])
	assert_true(bool(watch["won"]), "the fight was played to its end")
	for key: String in ["paw", "squeal", "dust", "hop"]:
		var values: Array = watch[key]
		assert_false(values.is_empty(), "%s seen" % key)
		for value: Variant in values:
			assert_true(int(value) >= 10, "%s: %d ticks ahead" % [key, int(value)])
	if not (watch["paw"] as Array).is_empty():
		assert_true(int((watch["paw"] as Array).min()) >= Tusker.TUSKER_PAW_TICKS)
	if not (watch["dust"] as Array).is_empty():
		assert_true(int((watch["dust"] as Array).min()) >= Tusker.TUSKER_ROCK_WARN_TICKS)


## Every attack can be escaped: a hero who only dodges (stays on a mesa bank, steps out from under the dust) is never
## hurt in 900 ticks of each phase - charges and rolls crash into the bank below him, the hop lands in the pit.
func test_every_attack_can_be_escaped() -> void:
	for phase_hp: int in [150, 75, 25]:
		var boar: Tusker = _open()
		boar.hp = phase_hp
		var bot: TuskerBot = TuskerBot.new()
		bot.attack = false
		var hero: PlayerBase = _lab.hero()
		var hurts: int = 0
		var attacks: int = 0
		var last: int = -1
		for t: int in 900:
			_lab.step(PackedInt32Array([bot.flags(hero, boar, _lab.level)]))
			if hero.hit_timer == Tuning.HIT_TIMER - 1:
				hurts += 1
			if boar.get_state() != last:
				last = boar.get_state()
				if last == Tusker.State.CHARGE or last == Tusker.State.ROLL:
					attacks += 1
		print("    dodging phase %d: %d charges / rolls, %d hurts" % [boar.get_phase(), attacks, hurts])
		assert_eq(boar.get_phase(), 1 if phase_hp == 150 else (2 if phase_hp == 75 else 3))
		assert_true(attacks >= 4, "it kept attacking (%d)" % attacks)
		assert_eq(hurts, 0, "phase %d: never hurt while dodging" % boar.get_phase())
		_lab.level.free()
		_lab = Lab.new()


## Hits never stop it or lengthen a state: a perfect thrower (an axe on the head on every tick it is open) still sees
## every dizzy end on time and the next attack come after the usual idle; a hit counts at most once per
## BOSS_HIT_COOLDOWN.
func test_hits_never_stun_lock_it() -> void:
	var boar: Tusker = _open(Defs.Difficulty.EXPERT)
	var hero: PlayerBase = _lab.hero()
	var dizzy_lengths: Array[int] = []
	var gaps: Array[int] = []
	var hit_ticks: Array[int] = []
	var last_state: int = -1
	var state_start: int = 0
	var last_attack: int = 0
	var t: int = 0
	while t < 4000 and not boar.dead:
		Lab.top_up(hero)
		if boar.is_open():
			_shot_at(boar.get_head_rect())
		var hp: int = boar.hp
		_lab.step(PackedInt32Array([0]))
		t += 1
		if boar.hp < hp:
			hit_ticks.append(t)
		var state: int = boar.get_state()
		if state != last_state:
			if last_state == Tusker.State.DIZZY:
				dizzy_lengths.append(t - state_start)
			if state == Tusker.State.PAW or state == Tusker.State.SQUEAL:
				gaps.append(t - last_attack)
				last_attack = t
			last_state = state
			state_start = t
	print("    perfect thrower: beaten after %d ticks, %d hits, dizzy lengths %s, ticks between attacks %s" % [t,
		hit_ticks.size(), dizzy_lengths, gaps])
	assert_true(boar.dead, "it is beaten")
	for i: int in range(1, hit_ticks.size()):
		assert_true(hit_ticks[i] - hit_ticks[i - 1] >= Tuning.BOSS_HIT_COOLDOWN, "hits %d ticks apart" % [
			hit_ticks[i] - hit_ticks[i - 1]])
	for length: int in dizzy_lengths:
		assert_true(length == Tusker.TUSKER_DIZZY_TICKS or length == Tusker.TUSKER_ROLL_DIZZY_TICKS,
				"a dizzy lasts its own length however often it is hit (%d)" % length)
	for gap: int in gaps.slice(1):
		assert_true(gap <= 200, "the next attack came %d ticks after the last" % gap)


func test_two_heroes_striking_together_count_once() -> void:
	var boar: Tusker = _open(Defs.Difficulty.BEGINNER, 2, true)
	_lab.step(PackedInt32Array([0, 0]))
	boar._set_state(Tusker.State.DAZED)
	var hp: int = boar.hp
	_shot_at(boar.get_head_rect(), 0)
	_shot_at(boar.get_rump_rect(), 1)
	_lab.step(PackedInt32Array([0, 0]))
	assert_eq(boar.hp, hp - 20, "two thrown weapons in one tick: one hit")
	for t: int in Tuning.BOSS_HIT_COOLDOWN - 2:
		boar._set_state(Tusker.State.DAZED)
		_shot_at(boar.get_rump_rect(), 1)
		_lab.step(PackedInt32Array([0, 0]))
	assert_eq(boar.hp, hp - 20, "the cooldown is the boss's, not the hero's")


# =================================================================================================================
# The club beats the solo form
# =================================================================================================================

## The recorded club routes (TuskerBot's play, see test_the_club_bot_still_wins): replayed tick for tick from the
## start of the test level, the boar is beaten with the club alone and the hero lives.
func test_the_club_beats_the_solo_form_on_its_scripted_routes() -> void:
	for case: Array in [[Defs.Difficulty.BEGINNER, ROUTE_BEGINNER], [Defs.Difficulty.EXPERT, ROUTE_EXPERT]]:
		var boar: Tusker = _open(int(case[0]))
		var hero: PlayerBase = _lab.hero()
		var route: PackedInt32Array = Lab.parse_route(str(case[1]))
		var played: int = _lab.play([route] as Array[PackedInt32Array], func() -> bool: return boar.dead)
		print("    route difficulty %d: beaten on tick %d of %d, hero %d hearts %d bones" % [case[0], played,
			route.size(), hero.run.hearts, hero.run.bones])
		assert_true(boar.dead, "difficulty %d: the club route beats the boar" % case[0])
		assert_false(hero.dead, "and the hero lives")
		assert_eq(hero.run.weapon, Defs.Weapon.CLUB, "with the club")
		_lab.level.free()
		_lab = Lab.new()


## The policy that recorded those routes still wins (a guard against tuning drift; with TUSKER_ROUTE=1 it prints the
## fresh routes).
func test_the_club_bot_still_wins() -> void:
	for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		var result: Dictionary = _bot_fight(difficulty)
		print("    club bot difficulty %d: won %s in %d ticks, %d hurts, %d hearts left" % [difficulty, result["won"],
			result["ticks"], result["hurts"], result["hearts"]])
		if OS.get_environment("TUSKER_ROUTE") != "":
			print("ROUTE %d %s" % [difficulty, result["route"]])
		assert_true(bool(result["won"]), "difficulty %d" % difficulty)
		assert_false(bool(result["dead"]))
		_lab.level.free()
		_lab = Lab.new()


# =================================================================================================================
# The co-op form
# =================================================================================================================

func test_coop_form_charges_whoever_hit_it_last() -> void:
	var boar: Tusker = _open(Defs.Difficulty.BEGINNER, 2, true)
	var p1: PlayerBase = _lab.hero(0)
	var p2: PlayerBase = _lab.hero(1)
	_lab.step(PackedInt32Array([0, 0]))
	p1.respawn_at(Vector2i(32, 112))
	p2.respawn_at(Vector2i(288, 112))
	boar.teleport(Vector2i(100, 160))
	_lab.step(PackedInt32Array([0, 0]))
	assert_eq(boar._charge_target(null), p1, "at first the nearest hero")
	boar._set_state(Tusker.State.DAZED)
	_shot_at(boar.get_rump_rect(), 1)
	_lab.step(PackedInt32Array([0, 0]))
	assert_eq(boar.last_hitter, p2)
	assert_eq(boar._charge_target(null), p2, "then whoever hit it last, however far")
	boar._begin_idle()
	for t: int in Tusker.TUSKER_IDLE_TICKS + 2:
		_lab.step(PackedInt32Array([0, 0]))
	assert_eq(boar.get_state(), Tusker.State.PAW)
	assert_eq(boar.facing, 1, "it paws at P2 on the right bank")


## While it lies open it turns every tick to the nearer hero and its head glances; the partner behind strikes the rump.
func test_coop_form_only_the_partner_behind_can_strike_the_rump() -> void:
	var boar: Tusker = _open(Defs.Difficulty.BEGINNER, 2, true)
	var p1: PlayerBase = _lab.hero(0)
	var p2: PlayerBase = _lab.hero(1)
	_lab.step(PackedInt32Array([0, 0]))
	boar.teleport(Vector2i(160, 166))
	boar._set_state(Tusker.State.DIZZY)
	boar._dizzy_len = 400
	p1.respawn_at(Vector2i(100, 160))
	p2.respawn_at(Vector2i(240, 160))
	_lab.step(PackedInt32Array([0, 0]))
	assert_eq(boar.facing, -1, "faces P1, the nearer")
	_shot_at(boar.get_head_rect(), 0)
	_lab.step(PackedInt32Array([0, 0]))
	assert_eq(boar.hp, boar.max_hp, "the head glances in the co-op form")
	_shot_at(boar.get_rump_rect(), 0)
	_lab.step(PackedInt32Array([0, 0]))
	assert_eq(boar.hp, boar.max_hp, "P1 is in front: his throw at the rump glances too")
	_shot_at(boar.get_rump_rect(), 1)
	_lab.step(PackedInt32Array([0, 0]))
	assert_eq(boar.hp, boar.max_hp - 20, "P2 stands behind it: the rump counts")
	p1.respawn_at(Vector2i(230, 160))
	p2.respawn_at(Vector2i(72, 160))
	_lab.step(PackedInt32Array([0, 0]))
	assert_eq(boar.facing, 1, "it turned to P1 (now the nearer) on the very next tick")
	for t: int in Tuning.BOSS_HIT_COOLDOWN:
		_lab.step(PackedInt32Array([0, 0]))
	_shot_at(boar.get_rump_rect(), 1)
	_lab.step(PackedInt32Array([0, 0]))
	assert_eq(boar.hp, boar.max_hp - 40, "P2, behind it again, strikes the rump again")


## Phase 3: a charge skids and turns 32 px before the wall (no impact, no rocks); a lone croucher is trampled; a Brace
## Wall stops it dead, dazed 66 ticks with head and rump open to both heroes.
func test_coop_form_phase_3_skids_and_only_a_brace_wall_stops_it() -> void:
	var boar: Tusker = _open(Defs.Difficulty.BEGINNER, 2, true)
	var p1: PlayerBase = _lab.hero(0)
	var p2: PlayerBase = _lab.hero(1)
	boar.hp = 40
	_lab.step(PackedInt32Array([0, 0]))
	assert_eq(boar.get_phase(), 3)
	p1.respawn_at(Vector2i(32, 112))
	p2.respawn_at(Vector2i(40, 112))
	boar.teleport(Vector2i(200, 160))
	boar._begin_idle()
	var skidded: bool = false
	var impacts: int = 0
	for t: int in 200:
		_lab.step(PackedInt32Array([0, 0]))
		skidded = skidded or boar.get_state() == Tusker.State.SKID
		impacts += 1 if boar.get_state() == Tusker.State.RECOIL else 0
	assert_true(skidded, "the charge skids before the bank")
	assert_eq(impacts, 0, "and never crashes")
	assert_true(boar.pending_rocks().is_empty(), "no rocks")
	# A lone croucher in its path is trampled (a charge already stuck once wades on through the wallow to him).
	_charge_left_from(boar, 236)
	p1.respawn_at(Vector2i(100, 160))
	p2.respawn_at(Vector2i(288, 112))
	var hurt: bool = false
	for t: int in 60:
		_lab.step(PackedInt32Array([Defs.IN_DOWN, 0]))
		hurt = hurt or p1.hit_timer > 0
		if hurt:
			break
	assert_true(hurt, "one crouching hero is trampled")
	assert_ne(boar.get_state(), Tusker.State.DAZED)
	# Two crouching heroes within 16 px brace.
	_charge_left_from(boar, 236)
	p1.respawn_at(Vector2i(96, 160))
	p2.respawn_at(Vector2i(108, 160))
	var dazed_at: int = -1
	for t: int in 60:
		_lab.step(PackedInt32Array([Defs.IN_DOWN, Defs.IN_DOWN]))
		if boar.get_state() == Tusker.State.DAZED:
			dazed_at = t
			break
	assert_true(dazed_at >= 0, "the Brace Wall stops it dead")
	assert_eq(p1.hit_timer, 0, "neither hero is touched")
	assert_eq(p2.hit_timer, 0)
	assert_true(boar.get_head_rect().size.x > 0)
	var hp: int = boar.hp
	_shot_at(boar.get_head_rect(), 0)
	_lab.step(PackedInt32Array([Defs.IN_DOWN, Defs.IN_DOWN]))
	assert_eq(boar.hp, hp - 20, "dazed by the Brace Wall its head is open to the hero in front")
	# Ticks it was seen dazed so far: the tick of the brace and the tick of the hit.
	var length: int = 2
	while length < 200:
		_lab.step(PackedInt32Array([0, 0]))
		if boar.get_state() != Tusker.State.DAZED:
			break
		length += 1
	assert_eq(length, Tusker.TUSKER_BRACE_DAZE_TICKS, "dazed 66 ticks [R24], a hit does not lengthen it")


## The co-op weak window for one hero is shorter than his measured solo minimum: alone he is always the nearer hero,
## so the open boar faces him on every tick (its window for him: 0 ticks), while his fastest strike needs its start-up
## (measured with the real hero: the front box of a forward strike exists 5 ticks after the press) - the window stays
## below the solo minimum minus PartyTuning.WINDOW_SOLO_MARGIN_TICKS.
func test_coop_weak_window_is_shorter_than_the_measured_solo_minimum() -> void:
	var boar: Tusker = _open(Defs.Difficulty.BEGINNER, 1, true)
	var hero: PlayerBase = _lab.hero()
	_lab.step(PackedInt32Array([0]))
	boar.teleport(Vector2i(160, 166))
	boar._set_state(Tusker.State.DIZZY)
	boar._dizzy_len = 100000
	hero.respawn_at(Vector2i(100, 160))
	hero.facing = 1
	for t: int in 4:
		_lab.step(PackedInt32Array([0]))
	var solo_min: int = -1
	for t: int in 12:
		_lab.step(PackedInt32Array([Defs.IN_FIRE]))
		if solo_min < 0 and hero.club_box_active and hero.club_box.position.x > hero.sim_pos.x:
			solo_min = t + 1
	var behind: int = 0
	var looked: int = 0
	for start: int in [80, 120, 200, 240]:
		for keys: int in [Defs.IN_RIGHT, Defs.IN_LEFT, Defs.IN_RIGHT | Defs.IN_UP, Defs.IN_LEFT | Defs.IN_UP]:
			hero.respawn_at(Vector2i(start, 160))
			for t: int in 30:
				_lab.step(PackedInt32Array([keys]))
				looked += 1
				behind += 1 if boar._is_behind(hero) else 0
	print("    co-op window for one hero: %d of %d ticks behind the open boar; his solo minimum %d ticks" % [behind,
		looked, solo_min])
	assert_true(solo_min >= 5, "a forward strike's front box comes 5 ticks after the press (PHYSICS.md 8.1)")
	assert_eq(behind, 0, "alone he is never behind it")
	assert_true(behind <= solo_min - PartyTuning.WINDOW_SOLO_MARGIN_TICKS)


## The single-hero search cannot hurt the co-op form: one hero, with the club, the hammer, the axe, the swirling axe and
## the spear, from every side of the open boar, striking forward / high / low, standing and out of jumps (and over its
## back), never lands a hit - while the very same search does hit the solo form. And the solo club route played
## against the co-op form never hurts it.
func test_the_single_hero_search_cannot_hurt_the_coop_form() -> void:
	var coop: Dictionary = _search(true)
	var solo: Dictionary = _search(false)
	print("    single-hero search: %d trials, co-op form hit %d times; solo form hit %d times" % [coop["trials"],
		coop["hits"], solo["hits"]])
	assert_true(int(coop["trials"]) >= 300)
	assert_eq(int(coop["hits"]), 0, "one hero never hurts the open co-op boar: %s" % coop["first"])
	assert_true(int(solo["hits"]) >= 20, "the same search hurts the solo form (the search is not blind)")
	var boar: Tusker = _open(Defs.Difficulty.BEGINNER, 1, true)
	var route: PackedInt32Array = Lab.parse_route(ROUTE_BEGINNER)
	var lowest: Array[int] = [boar.hp]
	_lab.play([route] as Array[PackedInt32Array], func() -> bool:
		lowest[0] = mini(lowest[0], boar.hp)
		return _lab.hero().dead)
	assert_eq(lowest[0], boar.max_hp, "the solo route never hurts the co-op form")


# =================================================================================================================
# Helpers
# =================================================================================================================

## Put the boar at x `x` of the pit floor in a charge to the left that was already stuck in the wallow once (it wades
## on through the mud at 2 px per tick and runs on).
func _charge_left_from(boar: Tusker, x: int) -> void:
	boar.teleport(Vector2i(x, 160))
	boar._dir = -1
	boar.facing = -1
	boar._stuck_done = true
	boar._wallow_centre = Tusker.NO_WALLOW
	boar._set_state(Tusker.State.CHARGE)


## A hero's thrown axe (power 20) right on `rect` this tick (slot `owner`).
func _shot_at(rect: Rect2i, owner: int = 0) -> void:
	_lab.level.spawn(&"projectiles/hero_axe", Vector2i(rect.get_center().x, rect.end.y - 1),
			{"from_hero": true, "power": 20, "xvel": 0, "yvel": 0, "yacc": 0, "owner": owner})


## Play the bot's fight and watch the telegraphs.
func _watch_fight(difficulty: int) -> Dictionary:
	var boar: Tusker = _open(difficulty)
	var hero: PlayerBase = _lab.hero()
	var bot: TuskerBot = TuskerBot.new()
	var watch: Dictionary = {"paw": [], "squeal": [], "dust": [], "hop": [], "ticks": 0, "won": false}
	var last: int = -1
	var since: int = 0
	var dust_seen: Dictionary = {}
	var rocks_seen: Dictionary = {}
	var t: int = 0
	while t < 8000 and not boar.dead and not hero.dead:
		Lab.top_up(hero)
		_lab.step(PackedInt32Array([bot.flags(hero, boar, _lab.level)]))
		t += 1
		var state: int = boar.get_state()
		if state != last:
			if state == Tusker.State.CHARGE and last == Tusker.State.PAW:
				(watch["paw"] as Array).append(since)
			elif state == Tusker.State.ROLL:
				(watch["squeal"] as Array).append(since)
			elif state == Tusker.State.DIZZY and last == Tusker.State.HOP:
				(watch["hop"] as Array).append(since)
			last = state
			since = 0
		since += 1
		for drop: Vector3i in boar.pending_rocks():
			if not dust_seen.has(drop.x):
				dust_seen[drop.x] = t
		for entity: SimEntity in _lab.level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
			if entity is BossRock and not rocks_seen.has(entity.get_instance_id()):
				rocks_seen[entity.get_instance_id()] = true
				if dust_seen.has(entity.sim_pos.x):
					(watch["dust"] as Array).append(t - int(dust_seen[entity.sim_pos.x]))
					dust_seen.erase(entity.sim_pos.x)
				else:
					(watch["dust"] as Array).append(0)
	watch["ticks"] = t
	watch["won"] = boar.dead
	return watch


## Run the club bot until the boar is beaten or `limit` ticks; {"won", "ticks", "hurts", "hearts", "route", "dead"}.
func _bot_fight(difficulty: int, limit: int = 8000) -> Dictionary:
	var boar: Tusker = _open(difficulty)
	var bot: TuskerBot = TuskerBot.new()
	var hero: PlayerBase = _lab.hero()
	var hurts: int = 0
	var t: int = 0
	var trace: bool = OS.get_environment("TUSKER_TRACE") != ""
	var last_state: int = -1
	while t < limit and not boar.dead and not hero.dead:
		_lab.step(PackedInt32Array([bot.flags(hero, boar, _lab.level)]))
		t += 1
		if hero.hit_timer == Tuning.HIT_TIMER - 1:
			hurts += 1
			if trace:
				print("      t%d HURT hero %s boar %s state %d" % [t, hero.sim_pos, boar.sim_pos, boar.get_state()])
		if trace and boar.get_state() != last_state:
			last_state = boar.get_state()
			print("      t%d boar %s state %d phase %d hp %d hero %s" % [t, boar.sim_pos, last_state, boar.get_phase(),
				boar.hp, hero.sim_pos])
	return {"won": boar.dead, "ticks": t, "hurts": hurts, "hearts": hero.run.hearts, "bones": hero.run.bones,
		"route": Lab.route_text(_lab.streams[0]), "dead": hero.dead}


## The single-hero search against the open boar (co-op or solo form): every trial puts the boar in a fresh dizzy in
## the middle of the pit and the hero at a distance on either side, then plays one input macro with one hand weapon.
func _search(coop_form: bool) -> Dictionary:
	var boar: Tusker = _open(Defs.Difficulty.BEGINNER, 1, coop_form)
	var hero: PlayerBase = _lab.hero()
	_lab.step(PackedInt32Array([0]))
	var result: Dictionary = {"trials": 0, "hits": 0, "first": ""}
	var weapons: Array[int] = [Defs.Weapon.CLUB, Defs.Weapon.HAMMER, Defs.Weapon.AXE, Defs.Weapon.BOOMERANG,
		Defs.Weapon.SPEAR]
	for weapon: int in weapons:
		hero.run.set_weapon(weapon)
		var thrown: bool = Tuning.WEAPON_THROWN[weapon]
		for dx: int in [-84, -64, -48, -36, -24, -12, 12, 24, 36, 48, 64, 84]:
			for toward: bool in [true, false]:
				for macro: PackedInt32Array in _macros(-signi(dx) if toward else signi(dx), thrown):
					result["trials"] = int(result["trials"]) + 1
					_clear_shots()
					boar.teleport(Vector2i(160, 166))
					boar.hp = boar.max_hp
					boar.hit_cooldown = 0
					boar._set_state(Tusker.State.DIZZY)
					boar._dizzy_len = 100000
					boar.facing = signi(dx)
					hero.respawn_at(Vector2i(160 + dx, 160))
					hero.facing = -signi(dx) if toward else signi(dx)
					Lab.top_up(hero)
					var frame: PackedInt32Array = PackedInt32Array([0])
					for flags: int in macro:
						frame[0] = flags
						_lab.step(frame)
						if boar.hp < boar.max_hp:
							break
					if boar.hp < boar.max_hp:
						result["hits"] = int(result["hits"]) + 1
						if str(result["first"]) == "":
							result["first"] = "weapon %d from dx %d (%s)" % [weapon, dx, Lab.route_text(macro)]
	_lab.level.free()
	_lab = Lab.new()
	return result


## Input macros of the search, `dir` = the side the hero moves to (+1 right): strikes forward / high / low standing,
## out of a jump towards that side (and on over the boar's back), a walk past it and a turn.
func _macros(dir: int, thrown: bool) -> Array[PackedInt32Array]:
	var go: int = Defs.IN_RIGHT if dir > 0 else Defs.IN_LEFT
	var back: int = Defs.IN_LEFT if dir > 0 else Defs.IN_RIGHT
	var list: Array = [
		[[12, Defs.IN_FIRE]],
		[[12, Defs.IN_UP | Defs.IN_FIRE]],
		[[3, go], [12, Defs.IN_FIRE]],
		[[6, Defs.IN_UP | go], [4, go], [12, Defs.IN_FIRE | go], [10, go]],
		[[9, Defs.IN_UP | go], [12, Defs.IN_UP | Defs.IN_FIRE], [10, go]],
		[[9, Defs.IN_UP | go], [6, go], [12, back | Defs.IN_FIRE], [10, back]],
		[[16, go], [2, back], [12, Defs.IN_FIRE]],
	]
	if not thrown:
		list.append([[12, Defs.IN_DOWN | Defs.IN_FIRE]])
		list.append([[9, Defs.IN_UP | go], [6, go], [12, Defs.IN_DOWN | Defs.IN_FIRE], [8, go]])
	var macros: Array[PackedInt32Array] = []
	for runs: Array in list:
		var flags: PackedInt32Array = PackedInt32Array()
		for run: Array in runs:
			for i: int in int(run[0]):
				flags.append(int(run[1]))
		for i: int in 14:
			flags.append(0)
		macros.append(flags)
	return macros


func _clear_shots() -> void:
	for entity: SimEntity in _lab.level.get_kind(Defs.Kind.HERO_PROJECTILE):
		(entity as ProjectileBase).consume()


# =================================================================================================================
# The bot
# =================================================================================================================

## Plays the solo form with the club: waits on a mesa bank while the boar is dangerous, drops into the pit and clubs
## the head while it lies open, climbs back before it gets up; keeps out from under the dust trickles of phase 3.
## With `attack` off it only dodges (the escape test).
class TuskerBot:
	extends RefCounted

	const LEFT_SAFE_X: int = 32
	const RIGHT_SAFE_X: int = 288
	const PIT_LEFT: int = 64
	const PIT_RIGHT: int = 256
	const BANK_Y: int = 112
	var attack: bool = true
	var _jump: int = 0
	var _jump_dir: int = 0

	func flags(hero: PlayerBase, boar: Tusker, level: LevelBase) -> int:
		if hero == null or hero.dead or boar == null or boar.dead:
			return 0
		var x: int = hero.sim_pos.x
		var grounded: bool = hero.is_grounded()
		# A running jump: hold Up for up to 9 ticks while rising, keep the direction.
		if _jump > 0:
			if grounded and _jump > 2:
				_jump = 0
			else:
				_jump += 1
				var dir_flag: int = Defs.IN_RIGHT if _jump_dir > 0 else Defs.IN_LEFT
				return dir_flag | (Defs.IN_UP if _jump <= 9 else 0)
		var on_bank: bool = hero.sim_pos.y <= BANK_Y and grounded
		var rocks: Array[int] = _rock_xs(boar, level)
		if attack and _should_attack(boar):
			var head: Rect2i = boar.get_head_rect()
			var spot: int = head.end.x + 20 if boar.facing > 0 else head.position.x - 20
			spot = clampi(spot, PIT_LEFT + 18, PIT_RIGHT - 18)
			spot = _away_from_rocks(spot, rocks)
			if absi(x - spot) > 4:
				return Defs.IN_RIGHT if spot > x else Defs.IN_LEFT
			var to_boar: int = 1 if boar.sim_pos.x >= x else -1
			if hero.facing != to_boar and not hero.is_striking():
				return Defs.IN_RIGHT if to_boar > 0 else Defs.IN_LEFT
			return Defs.IN_FIRE
		# Back to the nearer bank.
		var left_bank: bool = x < (PIT_LEFT + PIT_RIGHT) / 2
		var safe: int = LEFT_SAFE_X if left_bank else RIGHT_SAFE_X
		if on_bank:
			var target: int = _away_from_rocks(safe, rocks, 26, 24 if left_bank else 266, 46 if left_bank else 290)
			if absi(x - target) > 3:
				return Defs.IN_RIGHT if target > x else Defs.IN_LEFT
			return 0
		var face: int = PIT_LEFT if left_bank else PIT_RIGHT
		var dir: int = -1 if left_bank else 1
		if grounded and absi(x - face) <= 30:
			_jump = 1
			_jump_dir = dir
			return (Defs.IN_RIGHT if dir > 0 else Defs.IN_LEFT) | Defs.IN_UP
		return Defs.IN_RIGHT if dir > 0 else Defs.IN_LEFT

	## Go in while the boar lies open with time to spare to climb back.
	func _should_attack(boar: Tusker) -> bool:
		match boar.get_state():
			Tusker.State.RECOIL:
				return true
			Tusker.State.DIZZY:
				return boar.get_state_ticks() < boar._dizzy_len - 6
			Tusker.State.STUCK:
				return boar.get_state_ticks() < Tusker.TUSKER_STUCK_TICKS - 16
		return false

	static func _rock_xs(boar: Tusker, level: LevelBase) -> Array[int]:
		var xs: Array[int] = []
		for drop: Vector3i in boar.pending_rocks():
			xs.append(drop.x)
		for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
			xs.append(entity.sim_pos.x)
		return xs

	static func _away_from_rocks(spot: int, rocks: Array[int], clearance: int = 26, low: int = -100000,
			high: int = 100000) -> int:
		for shift: int in [0, 8, -8, 16, -16, 24, -24, 32, -32, 40, -40, 48, -48]:
			var x: int = clampi(spot + shift, low, high)
			var clear: bool = true
			for rock: int in rocks:
				clear = clear and absi(rock - x) >= clearance
			if clear:
				return x
		return spot


## Recorded by test_the_club_bot_still_wins with TUSKER_ROUTE=1 (Beginner, Expert).
const ROUTE_BEGINNER: String = (
	"3:L,3:,2:R,63:,11:R,5:F,3:L,1:R,31:F,4:L,12:LU,12:L,3:R,53:,11:R,3:F,6:L,1:R,30:F,17:LU,12:L,3:R,47:,3:L," +
	"4:R,19:,2:L,1:,5:R,32:,11:R,2:F,7:L,1:R,6:F,17:LU,12:L,3:R,24:,10:R,5:F,15:L,17:LU,12:L,2:R"
)
const ROUTE_EXPERT: String = (
	"3:L,3:,2:R,63:,11:R,5:F,3:L,1:R,31:F,4:L,12:LU,12:L,3:R,53:,11:R,3:F,6:L,1:R,30:F,17:LU,12:L,3:R,47:,3:L," +
	"4:R,19:,2:L,1:,5:R,32:,11:R,2:F,7:L,1:R,6:F,17:LU,12:L,3:R,41:,3:L,4:R,19:,2:L,1:,5:R,32:,11:R,2:F,7:L,1:R," +
	"6:F,17:LU,12:L,3:R,41:,3:L,4:R,19:,2:L,1:,5:R,32:,11:R,2:F,7:L,1:R,6:F,17:LU,12:L,3:R,24:,10:R,5:F,3:L,1:R," +
	"22:F,14:L,12:LU,12:L,3:R,4:"
)

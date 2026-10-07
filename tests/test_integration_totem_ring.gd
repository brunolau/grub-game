extends TestCase
## DA's proof for levels/arena_totem_ring.lvl (docs/expansion/PLAN.md P1.14 / gate G1: "arena_totem_ring playing Grub
## Stack with two humans and two Rookie bots"; DESIGN.md E.9: the classic one-keyboard layout).
##
## A whole Grub Stack match through Flow.start_versus on the Totem Ring: P1 on W A S D + Space (jump) + Left Shift
## (strike) + E (swap) + Q (look), P2 on Num 8 4 5 6 + Num 0 + Num Enter + Num + + Num . (NumLock on in even rounds,
## off in odd rounds - Windows then reports the navigation keycodes with the numpad's physical keycodes), P3 and P4
## Rookie HeroBots (core-B) with the committed graph resources/bots/arena_totem_ring.json. Nothing is scripted into
## GameInput: the two humans are physical key events every tick. P1 plays like a floor player (works the spots he can
## strike from the floor, picks up food lying on the floor, would bank in a floor-level cookpot from a stack of 4 -
## the Totem Ring has none, its pots are on the totem top and the left bridge - and walks off any ledge he lands on);
## P2 mashes (a seeded random choice of keys every 12 ticks, as core-B's slice test does). ui-A's scoreboard between
## rounds is confirmed as a player would (its next_round).
## Checked:
##  - the match finishes (round_ended for every round, VersusMatch.is_over()), each round reaching its gong;
##  - no stuck bot: no bot idle more than VersusTuning.BOT_IDLE_MAX_TICKS in a round, each bot stands on 2+ graph
##    nodes per round, plays links, and no link misses its node while the bot's head is empty (weight class 0: the
##    graph is baked for an empty head; misses with a heavy stack, which the navigator blocks per weight class, are
##    printed);
##  - no spawn hit (PHYSICS.md C.14 "Spawn shield: 48 ticks after every (re)spawn: no PvP hit, stomp ... touches him;
##    it ends at once when he starts a strike or a throw"): no hit and no stomp is applied to a hero within
##    VersusTuning.SPAWN_SHIELD_TICKS of his spawn (the round start or a respawn) while his shield is up. Hits inside
##    those ticks on a hero who already gave his shield up with his own strike are allowed by C.14; they are counted
##    and printed (the floor player and the bots strike the spot beside their spawn at once);
##  - every tick of play each human slot reads exactly the keys of its own keyboard half;
##  - deterministic replay: a second run with the same seed gives the identical per-tick trace (four slots' flags and
##    the four heroes' feet) and the same round results.
## Written by DA as build/da/proof_totem_ring.gd (P1.14); adopted into the suite by the G1 integration (owner:
## integration) so the G1 line "arena_totem_ring playing Grub Stack with two humans and two Rookie bots" stays proven.

const ARENA: StringName = &"arena_totem_ring"
const REFEREE: String = "res://scripts/world/versus/referee.gd"
const SEED: int = 4711
## Rounds to win (Grub Stack's default is 3; 2 keeps the proof at 2-3 full rounds of 90 s).
const ROUNDS_TO_WIN: int = 2
const MAX_ROUNDS: int = 6
## Classic layout: per player, flag -> physical key.
const CLASSIC: Array[Dictionary] = [
	{Defs.IN_LEFT: KEY_A, Defs.IN_RIGHT: KEY_D, Defs.IN_UP: KEY_SPACE, Defs.IN_DOWN: KEY_S, Defs.IN_FIRE: KEY_SHIFT,
		Defs.IN_LOOK: KEY_Q, Defs.IN_SWAP: KEY_E},
	{Defs.IN_LEFT: KEY_KP_4, Defs.IN_RIGHT: KEY_KP_6, Defs.IN_UP: KEY_KP_0, Defs.IN_DOWN: KEY_KP_5,
		Defs.IN_FIRE: KEY_KP_ENTER, Defs.IN_LOOK: KEY_KP_PERIOD, Defs.IN_SWAP: KEY_KP_ADD},
]
## The keycode Windows reports for a numpad key while NumLock is off (the physical keycode stays the numpad key).
const NUMLOCK_OFF: Dictionary = {
	KEY_KP_8: KEY_UP, KEY_KP_4: KEY_LEFT, KEY_KP_5: KEY_CLEAR, KEY_KP_6: KEY_RIGHT, KEY_KP_0: KEY_INSERT,
	KEY_KP_PERIOD: KEY_DELETE,
}
## P2's choices (core-B's slice test "human"), one every MASH_TICKS.
const MASH: PackedStringArray = ["L", "R", "RU", "LU", "RF", "LF", "", "D", "U"]
const MASH_TICKS: int = 12
## Floor feet y of the arena (row 10) and the floor halves left and right of the totem (the graph's floor nodes).
const FLOOR_Y: int = 160
const LEFT_FLOOR: Vector2i = Vector2i(8, 134)
const RIGHT_FLOOR: Vector2i = Vector2i(185, 311)
## P1 banks from this stack on.
const BANK_FROM: int = 4
const WANDER_X: PackedInt32Array = [40, 120, 200, 290]

var _held: Dictionary = {}
var _numlock_on: bool = true
var _rounds: Array[Array] = []
var _graph: NavGraph = null
# P1 (the floor player).
var _queue: Array[Array] = []
var _wander: int = 0
# P2 (the masher).
var _mash_rng: SimRng = null
var _mash: String = ""


func before_each() -> void:
	_reset_world()


func after_each() -> void:
	_reset_world()


func test_classic_keyboard_humans_and_rookie_bots_play_a_match() -> void:
	if not Levels.has_level(ARENA) or not ResourceLoader.exists(REFEREE):
		fail("%s and the referee are needed" % ARENA)
		return
	var first: Dictionary = await _play_match(SEED)
	_reset_world()
	var second: Dictionary = await _play_match(SEED)
	if first.is_empty() or second.is_empty():
		fail("a match did not start")
		return
	print("    match: %d round(s) %s, %d ticks played, wins %s" % [first["rounds"].size(), str(first["rounds"]),
			first["ticks"], str(first["wins"])])
	for line: String in first["notes"]:
		print("    " + line)
	for line: String in first["early_hits"]:
		print("    after his own strike: " + line)
	assert_true(first["over"], "the match finished (VersusMatch.is_over)")
	assert_true(first["rounds"].size() >= ROUNDS_TO_WIN, "at least %d rounds" % ROUNDS_TO_WIN)
	assert_eq(first["gongs"], first["rounds"].size(), "every round reached its gong")
	assert_eq(first["spawn_hits"], PackedStringArray(), "no hit or stomp on a hero whose %d-tick spawn shield is up" %
			VersusTuning.SPAWN_SHIELD_TICKS)
	assert_eq(first["stuck"], PackedStringArray(), "no stuck bot")
	assert_eq(first["mismatches"], 0, "each human slot read exactly its own keys")
	assert_true(first["bot_score"] > 0, "the Rookies scored")
	assert_eq(second["rounds"], first["rounds"], "the replay has the same round results")
	assert_eq(second["trace"].size(), first["trace"].size(), "the replay is as long")
	assert_true(second["trace"] == first["trace"], "the replay is identical tick for tick (%d values)" %
			first["trace"].size())


# =================================================================================================================
# The match
# =================================================================================================================

func _play_match(seed_value: int) -> Dictionary:
	var versus_match: VersusMatch = VersusMatch.new()
	versus_match.mode = Defs.VersusMode.GRUB_STACK
	versus_match.rounds_to_win = ROUNDS_TO_WIN
	versus_match.round_seconds = 0
	versus_match.crates = false
	versus_match.preset = VersusMatch.Preset.CLASSIC
	versus_match.arena = ARENA
	assert_eq(versus_match.seat_human(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT)), 0, "P1 on W A S D")
	assert_eq(versus_match.seat_human(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_RIGHT)), 1, "P2 on the numpad")
	assert_eq(versus_match.seat_bot(Defs.BotLevel.ROOKIE), 2, "P3 a Rookie")
	assert_eq(versus_match.seat_bot(Defs.BotLevel.ROOKIE), 3, "P4 a Rookie")
	versus_match.ready_all()
	_graph = NavGraph.load_for_level(ARENA)
	assert_not_null(_graph, "the committed graph resources/bots/arena_totem_ring.json")
	_mash_rng = SimRng.new(seed_value)
	_mash = ""
	_queue.clear()
	_wander = 0
	Events.round_ended.connect(_on_round_ended)
	Flow.instant_transitions = true
	Sim.manual = true
	await _frames(1)
	if not Flow.start_versus(versus_match, seed_value):
		fail("Flow.start_versus refused the match")
		return {}
	var result: Dictionary = {
		"trace": PackedInt32Array(), "rounds": [], "gongs": 0, "ticks": 0, "mismatches": 0, "bot_score": 0,
		"over": false, "wins": PackedInt32Array(),
	}
	var spawn_hits: PackedStringArray = PackedStringArray()
	var early_hits: PackedStringArray = PackedStringArray()
	var stuck: PackedStringArray = PackedStringArray()
	var notes: PackedStringArray = PackedStringArray()
	var trace: PackedInt32Array = PackedInt32Array()
	var last_level: LevelBase = null
	for round_number: int in MAX_ROUNDS:
		var level: Level = await _await_level(last_level)
		if level == null:
			break
		last_level = level
		_numlock_on = round_number % 2 == 0
		var played: Dictionary = _play_round(level, versus_match, round_number, trace)
		result["ticks"] = int(result["ticks"]) + int(played["ticks"])
		result["mismatches"] = int(result["mismatches"]) + int(played["mismatches"])
		result["bot_score"] = int(result["bot_score"]) + int(played["bot_score"])
		spawn_hits.append_array(played["spawn_hits"])
		early_hits.append_array(played["early_hits"])
		stuck.append_array(played["stuck"])
		notes.append(played["note"])
		for line: String in played["heavy_misses"]:
			notes.append("heavy-stack link miss (graph baked for an empty head; the navigator blocks it): " + line)
		_release_all()
		if versus_match.is_over() or _rounds.size() <= round_number:
			break
	# Let Flow finish the match (results, then the title) before anything else runs.
	for i: int in 60:
		if not Flow.busy and Flow.current_screen != Flow.SCREEN_LEVEL:
			break
		await _frames(1)
	await _frames(2)
	result["gongs"] = _rounds.size()
	for entry: Array in _rounds:
		(result["rounds"] as Array).append([entry[0], Array(entry[1])])
	result["over"] = versus_match.is_over()
	result["wins"] = versus_match.round_wins.duplicate()
	for slot: int in [2, 3]:
		var bot: HeroBot = versus_match.bots[slot] as HeroBot
		if bot == null:
			stuck.append("P%d had no HeroBot" % (slot + 1))
			continue
		notes.append("P%d (Rookie): %d links played, %d failed%s" % [slot + 1,
				bot.nav.links_played, bot.nav.links_failed,
				"" if bot.nav.failure_log.is_empty() else ": " + "; ".join(bot.nav.failure_log)])
		if bot.nav.links_played == 0:
			stuck.append("P%d never used the graph" % (slot + 1))

	result["trace"] = trace
	result["spawn_hits"] = spawn_hits
	result["early_hits"] = early_hits
	result["stuck"] = stuck
	result["notes"] = notes
	Events.round_ended.disconnect(_on_round_ended)
	return result


## One round on `level`: the intro (no keys), then play to the gong. Appends to `trace`.
func _play_round(level: Level, versus_match: VersusMatch, round_number: int, trace: PackedInt32Array) -> Dictionary:
	var out: Dictionary = {"ticks": 0, "mismatches": 0, "bot_score": 0, "spawn_hits": PackedStringArray(),
			"stuck": PackedStringArray(), "note": ""}
	var spawn_hits: PackedStringArray = PackedStringArray()
	var stuck: PackedStringArray = PackedStringArray()
	level.set_view_size(Vector2i(Tuning.VIEW_W, Tuning.VIEW_H) * Tuning.ART_SCALE)
	var referee: VersusReferee = VersusReferee.find(level)
	assert_not_null(referee, "round %d: the arena has its referee" % round_number)
	if referee == null:
		return out
	var waited: int = 0
	while referee.phase == VersusReferee.PHASE_INTRO and waited < 400:
		_drive(["", ""], 1)
		waited += 1
	assert_eq(referee.phase, VersusReferee.PHASE_PLAY, "round %d: the countdown ended" % round_number)
	var rounds_before: int = _rounds.size()
	var spawn_tick: PackedInt32Array = PackedInt32Array([Sim.tick, Sim.tick, Sim.tick, Sim.tick])
	var was_dead: PackedByteArray = PackedByteArray([0, 0, 0, 0])
	var shield_gone: PackedInt32Array = PackedInt32Array([-1, -1, -1, -1])
	var hurts: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	var last_hit: PackedInt32Array = PackedInt32Array([-1, -1, -1, -1])
	var early_hits: PackedStringArray = PackedStringArray()
	var spawns: PackedStringArray = PackedStringArray()
	for slot: int in 4:
		var hero: PlayerBase = level.get_hero(slot)
		hurts[slot] = hero.run.hurts
		last_hit[slot] = int(referee._last_hit_tick[slot])
		spawns.append("P%d%s" % [slot + 1, hero.sim_pos])
	var worst_idle: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	var failed_seen: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	var heavy_misses: PackedStringArray = PackedStringArray()
	for slot: int in [2, 3]:
		var seen_bot: HeroBot = versus_match.bots[slot] as HeroBot
		if seen_bot != null:
			failed_seen[slot] = seen_bot.nav.links_failed
	var nodes: Array[Dictionary] = [{}, {}, {}, {}]
	var hits: int = 0
	var stomps: int = 0
	var limit: int = referee.round_length() + 1500
	var ticks: int = 0
	while _rounds.size() == rounds_before and ticks < limit and Game.level == level:
		var keys: Array = [_p1_keys(level, referee), _p2_keys(ticks)]
		var sampled: Array[PackedInt32Array] = _drive(keys, 1)
		ticks += 1
		var live: bool = _rounds.size() == rounds_before and Game.level == level and is_instance_valid(referee) \
				and (referee.phase == VersusReferee.PHASE_PLAY or referee.phase == VersusReferee.PHASE_GOLDEN)
		if live and sampled[0].size() == 1:
			for slot: int in 2:
				if sampled[slot][0] != GameInput.keys_to_flags(str(keys[slot])):
					out["mismatches"] = int(out["mismatches"]) + 1
					if int(out["mismatches"]) <= 5:
						print("    round %d tick %d: P%d keys '%s' read %d" % [round_number, ticks, slot + 1,
								keys[slot], sampled[slot][0]])
		if Game.level != level:
			break
		for slot: int in 4:
			trace.append(GameInput.get_flags(slot))
			var hero: PlayerBase = level.get_hero(slot)
			trace.append(hero.sim_pos.x)
			trace.append(hero.sim_pos.y)
			if hero.dead:
				was_dead[slot] = 1
				continue
			if was_dead[slot] == 1:
				was_dead[slot] = 0
				spawn_tick[slot] = Sim.tick
				shield_gone[slot] = -1
			var since: int = Sim.tick - spawn_tick[slot]
			if hero.shield <= 0 and shield_gone[slot] < 0:
				shield_gone[slot] = since
			# A hit or a stomp that the referee applied (VersusReferee._apply_hit / _stomp_step stamp the victim's
			# _last_hit_tick and _last_hitter; a shielded, immune or curled victim is never stamped).
			var hit_tick: int = int(referee._last_hit_tick[slot])
			if hit_tick != last_hit[slot] and hit_tick >= 0:
				last_hit[slot] = hit_tick
				var landed: String = "hit" if hero.run.hurts > hurts[slot] else "stomped"
				if landed == "hit":
					hits += 1
				else:
					stomps += 1
				if since < VersusTuning.SPAWN_SHIELD_TICKS:
					# The shield was up when this landed unless it ended before this tick, or on this very tick for a
					# stomp (stomps are applied in CONTACT_ENEMIES, after the PLAYER phase in which the victim's own
					# strike ends his shield; hits are applied in WEAPONS, before it).
					var by: int = int(referee._last_hitter[slot])
					var attacker: PlayerBase = level.get_hero(by) if by >= 0 else null
					var line: String = "round %d: P%d %s %d ticks after his spawn at %s by P%d at %s" % [round_number,
							slot + 1, landed, since, hero.sim_pos, by + 1,
							attacker.sim_pos if attacker != null else Vector2i.ZERO]
					var ended: int = shield_gone[slot]
					if ended < 0 or ended > since or (ended == since and landed == "hit"):
						spawn_hits.append(line + " - his spawn shield was still up")
					else:
						early_hits.append(line + " (he gave up his shield with a strike on tick %d)" % shield_gone[slot])
			hurts[slot] = hero.run.hurts
			if slot >= 2:
				var bot: HeroBot = versus_match.bots[slot] as HeroBot
				if bot != null:
					if bot.nav.links_failed > failed_seen[slot]:
						failed_seen[slot] = bot.nav.links_failed
						var line: String = "round %d: P%d (weight class %d, stack %d): %s" % [round_number, slot + 1,
								bot.nav.weight_class, referee.stack_of(slot), bot.nav.failure_log[-1]]
						if bot.nav.weight_class == 0:
							stuck.append(line)
						else:
							heavy_misses.append(line)
					worst_idle[slot] = maxi(worst_idle[slot], bot.idle_ticks)
					var node: int = bot.nav.node_of(hero)
					if node >= 0:
						nodes[slot][node] = true
		if live:
			out["bot_score"] = maxi(int(out["bot_score"]), referee.score_of(2) + referee.score_of(3))
	out["ticks"] = ticks
	var gong: bool = _rounds.size() > rounds_before
	assert_true(gong, "round %d reached its gong (%d ticks)" % [round_number, ticks])
	var scores: Array[int] = []
	if is_instance_valid(referee):
		for slot: int in 4:
			scores.append(referee.score_of(slot))
	for slot: int in [2, 3]:
		if worst_idle[slot] > VersusTuning.BOT_IDLE_MAX_TICKS:
			stuck.append("round %d: P%d stood still %d ticks" % [round_number, slot + 1,
					worst_idle[slot]])
		if nodes[slot].size() < 2:
			stuck.append("round %d: P%d stayed on node(s) %s" % [round_number, slot + 1,
					str(nodes[slot].keys())])
	out["spawn_hits"] = spawn_hits
	out["early_hits"] = early_hits
	out["stuck"] = stuck
	out["heavy_misses"] = heavy_misses
	out["note"] = "round %d (NumLock %s): %d ticks, spawns %s, scores %s, winners %s, %d hits, %d stomps, bot idle max %d / %d, bot nodes %d / %d" % [
		round_number, "on" if _numlock_on else "off", ticks, " ".join(spawns), str(scores),
		str(_rounds[-1][1]) if gong else "-", hits, stomps, worst_idle[2], worst_idle[3], nodes[2].size(),
		nodes[3].size(),
	]
	return out


# =================================================================================================================
# P1: the floor player (W A S D)
# =================================================================================================================

func _p1_keys(level: LevelBase, referee: VersusReferee) -> String:
	var hero: PlayerBase = level.get_hero(0)
	if hero == null or hero.dead or not hero.control_enabled or hero.hit_timer >= VersusTuning.STUN_HIT_TIMER_MIN:
		_queue.clear()
		return ""
	if not _queue.is_empty():
		var step: Array = _queue[0]
		step[1] = int(step[1]) - 1
		if int(step[1]) <= 0:
			_queue.pop_front()
		return str(step[0])
	if not hero.is_grounded():
		return ""
	var x: int = hero.sim_pos.x
	if hero.sim_pos.y != FLOOR_Y:
		return _walk_off(hero)
	var stack: int = referee.stack_of(0)
	# Bank in the floor pot (lid open) from a stack of BANK_FROM.
	if stack >= BANK_FROM or (stack > 0 and referee.is_banking(0)):
		for pot: Cookpot in Cookpot.pots_of(level):
			if pot.sim_pos.y != FLOOR_Y or not pot.is_open():
				continue
			if absi(x - pot.sim_pos.x) <= 6:
				_queue.append(["D", 8])
				return "D"
			return _walk_to(x, pot.sim_pos.x)
	# Food lying on the floor.
	var best_item: int = -1
	var best_cost: int = 1 << 20
	for entity: SimEntity in level.get_kind(Defs.Kind.COLLECTIBLE):
		var item: CollectibleBase = entity as CollectibleBase
		if item == null or item.collected or item.sim_pos.y < FLOOR_Y - 4 or item.sim_pos.y > FLOOR_Y:
			continue
		if not _on_floor_x(item.sim_pos.x):
			continue
		var cost: int = _ring_distance(x, item.sim_pos.x)
		if cost < best_cost:
			best_cost = cost
			best_item = item.sim_pos.x
	if best_item >= 0:
		return _walk_to(x, best_item)
	# A spot he can strike from the floor.
	var best_stand: Dictionary = {}
	var best_spot: HittableBase = null
	best_cost = 1 << 20
	for entity: SimEntity in level.get_kind(Defs.Kind.HITTABLE):
		var spot: HittableBase = entity as HittableBase
		if spot == null or spot.opened:
			continue
		for stand: Dictionary in BotBrain.spot_stands(_graph, spot.cell):
			if _graph.nodes[int(stand["node"])].y != FLOOR_Y:
				continue
			var cost: int = _ring_distance(x, int(stand["x"])) + 6 * int(stand["kind"])
			if cost < best_cost:
				best_cost = cost
				best_stand = stand
				best_spot = spot
	if best_spot != null:
		var stand_x: int = int(best_stand["x"])
		var half: int = maxi((int(best_stand["x1"]) - int(best_stand["x0"])) / 2, 2)
		if absi(x - stand_x) > half:
			return _walk_to(x, stand_x)
		if absi(hero.xvel) >= 16 or best_spot.cooldown > 1:
			return ""
		var facing: String = "R" if int(best_stand["facing"]) > 0 else "L"
		var kind: int = int(best_stand["kind"])
		var keys: String = facing + ["F", "UF", "DF"][kind]
		_queue.append([keys, BotBrain.strike_ticks(kind) - 1])
		_queue.append(["", 4])
		return keys
	# Nothing to do: walk the floor.
	if absi(x - WANDER_X[_wander]) <= 6:
		_wander = (_wander + 1) % WANDER_X.size()
	return _walk_to(x, WANDER_X[_wander])


## Off a ledge, a bridge or the totem top: walk toward the end that drops to the floor.
func _walk_off(hero: PlayerBase) -> String:
	var x: int = hero.sim_pos.x
	if hero.sim_pos.y <= 80:
		if x < 144:
			return "R" if x < 60 else "L"
		if x > 176:
			return "L" if x > 260 else "R"
		return "L"
	return "L" if x < 160 else "R"


func _on_floor_x(x: int) -> bool:
	return (x >= LEFT_FLOOR.x and x <= LEFT_FLOOR.y) or (x >= RIGHT_FLOOR.x and x <= RIGHT_FLOOR.y)


## Position along the floor ring (the totem blocks it, the seam joins it): the right half 0..126, then the left half.
func _ring(x: int) -> int:
	if x >= RIGHT_FLOOR.x:
		return x - RIGHT_FLOOR.x
	return (RIGHT_FLOOR.y - RIGHT_FLOOR.x + 1) + (x - LEFT_FLOOR.x)


func _ring_distance(a: int, b: int) -> int:
	return absi(_ring(a) - _ring(b))


func _walk_to(x: int, target: int) -> String:
	var dx: int = _ring(target) - _ring(x)
	if absi(dx) <= 2:
		return ""
	return "R" if dx > 0 else "L"


# =================================================================================================================
# P2: the masher (numpad)
# =================================================================================================================

func _p2_keys(tick: int) -> String:
	if tick % MASH_TICKS == 0:
		_mash = MASH[_mash_rng.next_int(MASH.size())]
	return _mash


# =================================================================================================================
# Helpers
# =================================================================================================================

## Wait for the arena of the next round (a level other than `previous`, Flow idle on the level screen).
func _await_level(previous: LevelBase) -> Level:
	var skipped: bool = false
	for i: int in 600:
		await _frames(1)
		# ui-A's scoreboard between rounds: confirm it, as a player would (it calls Flow.next_round).
		var scene: Node = get_tree().current_scene
		if not skipped and not Flow.busy and Flow.current_screen == Flow.SCREEN_VERSUS_SCOREBOARD and scene != null:
			skipped = true
			if scene.has_method(&"next_round"):
				scene.call(&"next_round")
			else:
				Flow.next_round()
		var level: Level = Game.level as Level
		if level != null and level != previous and is_instance_valid(level) and not Flow.busy \
				and Flow.current_screen == Flow.SCREEN_LEVEL and level.level_id == ARENA:
			return level
	print("    no arena level: Game.level %s, screen %s, busy %s, scene %s" % [Game.level, Flow.current_screen, Flow.busy,
			get_tree().current_scene])
	return null


## Hold the keys of `keys` (one key string per player) for `ticks` ticks through physical key events; returns the
## flags each human slot sampled, per tick.
func _drive(keys: Array, ticks: int) -> Array[PackedInt32Array]:
	var sampled: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
	for slot: int in 2:
		var wanted: int = GameInput.keys_to_flags(str(keys[slot]))
		var layout: Dictionary = CLASSIC[slot]
		for bit: int in layout:
			_set_key(layout[bit], (wanted & bit) != 0)
	Input.flush_buffered_events()
	for i: int in ticks:
		if Game.level == null or not Sim.running:
			break
		Sim.step(1)
		for slot: int in 2:
			sampled[slot].append(GameInput.get_flags(slot))
	return sampled


func _set_key(physical: Key, down: bool) -> void:
	if down == _held.has(physical):
		return
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = physical
	event.keycode = physical if _numlock_on else NUMLOCK_OFF.get(physical, physical)
	event.pressed = down
	Input.parse_input_event(event)
	if down:
		_held[physical] = event
	else:
		_held.erase(physical)


func _release_all() -> void:
	for physical: Key in _held.keys():
		_set_key(physical, false)
	Input.flush_buffered_events()


func _on_round_ended(round_index: int, winners: PackedInt32Array) -> void:
	_rounds.append([round_index, winners])


func _reset_world() -> void:
	_release_all()
	_numlock_on = true
	if Events.round_ended.is_connected(_on_round_ended):
		Events.round_ended.disconnect(_on_round_ended)
	_rounds.clear()
	GameInput.clear_scripted()
	GameInput.reset_slots()
	# The scoreboard and results screens switch the menu clusters on; later test files expect them off.
	GameInput.set_menu_clusters(false)
	Game.versus_match = null
	Sim.manual = false
	Sim.stop()
	if get_tree().current_scene != null:
		get_tree().current_scene.free()
		get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT
	Flow.args = {}
	Flow.play_mode = Defs.GameMode.SINGLE
	Game.new_game(Defs.Difficulty.BEGINNER)
	Settings.reset()
	Settings.set_value("controls/party_keyboard", "classic")
	NavGraph.clear_cache()
	BotBrain.clear_cache()


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame

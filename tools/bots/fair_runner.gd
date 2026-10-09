extends Node
## The runner of tools/bots/fair.gd (loaded once the autoloads exist): see fair.gd and fair.sh.

## The test's 12 seeds first, then further primes: seed i of a longer set.
const SEEDS: PackedInt32Array = [
	11, 23, 37, 41, 53, 67, 71, 89, 97, 101, 113, 127,
	131, 137, 139, 149, 151, 157, 163, 167, 173, 179, 181, 191,
	193, 197, 199, 211, 223, 227, 229, 233, 239, 241, 251, 257,
	263, 269, 271, 277, 281, 283, 293, 307, 311, 313, 317, 331,
	337, 347, 349, 353, 359, 367, 373, 379, 383, 389, 397, 401,
	409, 419, 421, 431, 433, 439, 443, 449, 457, 461, 463, 467,
	479, 487, 491, 499, 503, 509, 521, 523, 541, 547, 557, 563,
	569, 571, 577, 587, 593, 599, 601, 607, 613, 617, 619, 631,
]


const STAT_NAMES: Array[StringName] = [&"food", &"stolen", &"dropped", &"hits", &"hurts", &"bonks", &"deaths", &"picked",
	&"best_stack"]


func run(args: PackedStringArray) -> void:
	var arena_id: StringName = &"arena_sky_picnic"
	var mode_name: String = "grub_stack"
	var seeds: PackedInt32Array = SEEDS.slice(0, 12)
	var detail: bool = false
	var bot_level: int = Defs.BotLevel.HUNTER
	for arg: String in args:
		if arg.begins_with("arena="):
			arena_id = StringName(arg.trim_prefix("arena="))
		elif arg.begins_with("mode="):
			mode_name = arg.trim_prefix("mode=")
		elif arg.begins_with("seeds="):
			seeds = PackedInt32Array()
			for part: String in arg.trim_prefix("seeds=").split(",", false):
				seeds.append(int(part))
		elif arg.begins_with("first="):
			seeds = SEEDS.slice(0, int(arg.trim_prefix("first=")))
		elif arg.begins_with("range="):
			var parts: PackedStringArray = arg.trim_prefix("range=").split(":")
			seeds = SEEDS.slice(int(parts[0]), int(parts[0]) + int(parts[1]))
		elif arg == "detail=1":
			detail = true
		elif arg.begins_with("level="):
			bot_level = int(arg.trim_prefix("level="))
	var mode: int = Defs.versus_mode_from_name(StringName(mode_name))
	var test: Node = (load("res://tests/test_versus_bots.gd") as GDScript).new() as Node
	add_child(test)
	test.call(&"_begin_test")
	test.call(&"before_each")
	var text: String = FileAccess.get_file_as_string("res://levels/%s.lvl" % arena_id)
	var arena: Dictionary = test.call(&"_arena_entry", arena_id, text)
	var players: int = int(arena["players"])
	var wins: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	var scores: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	var rounds: int = 0
	var stats: PackedInt32Array = PackedInt32Array()
	stats.resize(4 * STAT_NAMES.size())
	stats.fill(0)
	var draws: int = 0
	var shared: int = 0
	var ticks: int = 0
	var unfinished: int = 0
	var worst_idle: int = 0
	var started: int = Time.get_ticks_msec()
	for seed_value: int in seeds:
		var bots: Array[HeroBot] = []
		for slot: int in players:
			bots.append(HeroBot.new(slot, bot_level, seed_value, mode))
		for round_index: int in players:
			var round_seed: int = VersusTuning.round_seed(seed_value, round_index)
			var result: Dictionary = test.call(&"_play_round", arena, mode, players, round_index, round_seed, bots, false)
			if result.is_empty():
				print("FAIR %s %s: the round could not start" % [arena_id, mode_name])
				return
			rounds += 1
			ticks += int(result["ticks"])
			worst_idle = maxi(worst_idle, int(result["worst_idle"]))
			if not bool(result["ended"]):
				unfinished += 1
			var winners: PackedInt32Array = result["winner_spawns"]
			if winners.is_empty():
				draws += 1
			if winners.size() > 1:
				shared += 1
			for spawn: int in winners:
				wins[spawn] += 1
			var round_scores: PackedInt32Array = result["spawn_scores"]
			for spawn: int in Defs.MAX_PLAYERS:
				scores[spawn] += round_scores[spawn]
			# What the round left in every run (the statistics are zeroed when a round's level loads), by spawn.
			for slot: int in players:
				var spawn: int = posmod(slot + round_index, 4)
				for i: int in STAT_NAMES.size():
					stats[spawn * STAT_NAMES.size() + i] += int(Game.runs[slot].get(STAT_NAMES[i]))
			if detail:
				print("ROUND seed %d r%d: %d ticks, winner spawns %s, scores by spawn %s" % [seed_value, round_index,
						result["ticks"], winners, round_scores])
			await get_tree().process_frame
	test.call(&"after_each")
	var shares: PackedStringArray = PackedStringArray()
	for spawn: int in 4:
		shares.append("%d%%" % roundi(100.0 * float(wins[spawn]) / float(maxi(rounds, 1))))
	for spawn: int in 4:
		var parts: PackedStringArray = PackedStringArray()
		for i: int in STAT_NAMES.size():
			parts.append("%s=%d" % [STAT_NAMES[i], stats[spawn * STAT_NAMES.size() + i]])
		print("STAT spawn=%d %s" % [spawn + 1, " ".join(parts)])
	print("FAIR %s %s rounds=%d wins=%d,%d,%d,%d (%s) scores=%d,%d,%d,%d draws=%d shared=%d unfinished=%d idle=%d ticks=%d ms=%d seeds=%s" % [
		arena_id, mode_name, rounds, wins[0], wins[1], wins[2], wins[3], " ".join(shares), scores[0], scores[1], scores[2],
		scores[3], draws, shared, unfinished, worst_idle, ticks, Time.get_ticks_msec() - started, seeds])

extends Node
## What a low strike begun ON A SPRING gives a hero who holds Up from the strike's hop - the "hop jump" of DESIGN.md
## G67 stacked on the spring's launch - against the plain spring bounce and the plain hop jump: the highest feet point
## per variant, in the solo search's world of w2_l2_coop 'seesaw' (the cap at 46,19). The G3b verifier's measurement
## (cause B: 256 px = 16 rows), adopted by world-B in wf11. R1 / G71: for a hero of a co-op party a spring is a launch
## and THE MEASUREMENT IS THE RULE - 115 px over the floor the pad stands on, from every start.
## Usage: bash .tools/gd.sh script res://tools/coop_explore/main.gd -- spring
## Exit code 0 = the strike begun on the pad rises no more than a plain jump onto it; 1 = it rises more (the stack).

const LIB: String = "res://tools/coop_explore/harness.gd"


func run(_arguments: PackedStringArray) -> int:
	var lib: RefCounted = (load(LIB) as GDScript).new()
	if not lib.build(&"w2_l2_coop", "seesaw", 1, false):
		print("SPRING: cannot build the world of w2_l2_coop 'seesaw'")
		return 2
	var floor_y: int = 320
	var d: int = Defs.IN_DOWN
	var f: int = Defs.IN_FIRE
	var u: int = Defs.IN_UP
	var best: Dictionary = {}
	var r: int = Defs.IN_RIGHT
	# The stack: a low strike begun on the cap, Up (and a side) from its hop, with or without a high strike in it.
	for start_x: int in range(726, 762, 1):
		for low: int in [7, 8, 9, 10, 11]:
			for hold: int in [4, 6, 9, 12, 16]:
				for kind: int in 3:
					lib.begin(Vector2i(start_x, floor_y), 1)
					var flags: Array = []
					for i: int in low:
						flags.append(d | f)
					for i: int in hold:
						flags.append(u | (r if kind > 0 else 0))
					if kind == 2:
						for i: int in 10:
							flags.append(u | f)
					for i: int in 70:
						flags.append(0)
					for flag: int in flags:
						if lib.step(flag) != "":
							break
					var rise: int = floor_y - lib.min_y
					if best.is_empty() or rise > int(best["rise"]):
						best = {"rise": rise, "x": start_x, "low": low, "hold": hold, "kind": kind}
	print("SPRING a low strike begun on the cap of w2_l2_coop (46,19), Up from its hop: highest %d px over the floor (%.1f rows) - start x %d, Down+Fire %d ticks, then Up%s %d ticks%s" % [
		int(best["rise"]), int(best["rise"]) / 16.0, int(best["x"]), int(best["low"]),
		"" if int(best["kind"]) == 0 else "+Right", int(best["hold"]),
		", then Up+Fire 10" if int(best["kind"]) == 2 else ""])
	# The plain bounce: a jump from beside the cap onto it, Up held.
	var plain: int = 0
	for start_x: int in range(690, 730, 2):
		lib.begin(Vector2i(start_x, floor_y), 1)
		for i: int in 90:
			if lib.step(u | r if i < 30 else u) != "":
				break
		plain = maxi(plain, floor_y - lib.min_y)
	print("SPRING a plain jump onto the cap, Up held: highest %d px over the floor (%.1f rows)" % [plain, plain / 16.0])
	# The plain hop jump on bare floor (x 880: no spring, no plank).
	var hop: int = 0
	for low: int in [7, 8, 9, 10, 11]:
		for hold: int in [6, 9, 12]:
			lib.begin(Vector2i(880, floor_y), -1)
			for i: int in 80:
				var flag: int = (d | f) if i < low else (u if i < low + hold else 0)
				if lib.step(flag) != "":
					break
			hop = maxi(hop, floor_y - lib.min_y)
	print("SPRING the plain hop jump on the floor: highest %d px (%.1f rows)" % [hop, hop / 16.0])
	lib.close()
	var stacked: bool = int(best["rise"]) > plain
	print("SPRING %s: the strike begun on the pad rises %d px, a plain jump onto it %d px" % [
		"STACKED (R1 / G71 is not met)" if stacked else "a launch (R1 / G71)", int(best["rise"]), plain])
	return 1 if stacked else 0

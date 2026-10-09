extends "res://tools/autoplay/recorders/db2/botx.gd"
## The two-stream routes of w2_l2_coop "Bone Gorge" (DB2): recorded by probe_work.gd --bot --players=2.
## P1 is the dropper at the see-saw and the plate holder at the lift; P2 is launched up the bone wall and rides the
## lift; each time the upper hero clubs the coiled vine down and the other climbs it. Both act all the way (the IDLE
## rule): nobody stands 243 ticks without input while a co-op rule needs him.

const FLOOR: int = 320          ## feet y on the main floor (row 19)
const TERRACE: int = 176        ## feet y on the upper terrace / the bone wall (row 10)
const RUNWAY: int = 256         ## feet y on the runway (row 15)


func header() -> String:
	var mode: String = "expert" if expert else "beginner"
	return "# route: level=w2_l2_coop difficulty=%s players=2 ends=exit after=tally expect=wipes:0,eggs:0,x2_gates:2,min_checkpoints:3,painting:23\n" % mode


## Cross the stepping-stone pit: each stone rises when the hero stands on the one before it.
func pit(p: Array) -> void:
	var fight: Dictionary = {"fight": true}
	p.append(["go", 536, fight])
	p.append(["until", solid_fn(35, 21), 0])
	p.append(["fn", hop_fn(cx(35.5), 3)])
	p.append(["until", solid_fn(39, 21), 0])
	p.append(["fn", hop_fn(cx(39.5), 11)])
	p.append(["until", solid_fn(43, 21), 0])
	p.append(["fn", hop_fn(cx(43.5), 11)])
	p.append(["fn", hop_fn(cx(45.2), 6)])


func build() -> Array:
	var fight: Dictionary = {"fight": true}
	var p1: Array = []
	var p2: Array = []
	# --- the digger meadow and the stepping stones: P2 crosses first (he will be launched), P1 behind him ---
	p1.append(["keys", 2, R])
	p2.append(["keys", 2, R])
	p1.append(["go", 520, fight])
	p2.append(["go", 500, fight])
	p2.append(["mark", "pit"])
	pit(p2)
	p2.append(["go", cx(52.8), {"tol": 2}])         # the see-saw's low end (cols 52.5-54)
	p2.append(["mark", "on the low end"])
	p1.append(["fn", guard_fn(partner_fn(func(lv: LevelBase, hh: PlayerBase) -> bool: return hh.sim_pos.x > 760))])
	pit(p1)
	# --- gate 'seesaw': P1 springs onto the bone shelf and drops on the high end ---
	p1.append(["go", 724, {"tol": 2}])
	p1.append(["fn", spring_fn(744, 768)])
	p1.append(["mark", "on the shelf"])
	p1.append(["go", 772, {"tol": 2}])
	both([p1, p2], ["sync", "drop"])
	p1.append(["run", 786])
	p1.append(["until", grounded_fn(), 0])
	p1.append(["mark", "landed"])
	p2.append(["fn", launch_fn(cx(57.5))])
	p2.append(["mark", "on the wall"])
	p2.append(["go", 924, {"tol": 2}])
	p2.append(["face", -1])
	p2.append(["fn", unroll_fn(56, D)])
	p1.append(["go", cx(56), {"tol": 2}])
	both([p1, p2], ["sync", "vine1"])
	p1.append(["fn", climb_fn(11)])
	p1.append(["mark", "up the vine"])
	both([p1, p2], ["sync", "over_wall"])
	# --- the x2 secret: P1 hops off P2's head onto the bone ledge (painting 23) and drops back down ---
	p2.append(["run", 952])
	p2.append(["until", grounded_fn(), 0])
	p2.append(["go", cx(67.6), {"tol": 1}])
	p2.append(["face", -1])
	p1.append(["wait", 8])
	p1.append(["run", 952])
	p1.append(["until", grounded_fn(), 0])
	p1.append(["go", cx(69.2), {"tol": 2}])
	both([p1, p2], ["sync", "hop"])
	p1.append(["fn", shoulder_fn(cx(67.6), cx(65), 192)])
	p1.append(["mark", "on the x2 ledge"])
	p1.append(["go", cx(64.3), {"tol": 2}])
	p1.append(["run", cx(67.2)])
	p1.append(["until", grounded_fn(), 0])
	p2.append(["fn", guard_fn(partner_fn(func(lv: LevelBase, hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.y == FLOOR and hh.sim_pos.x > cx(66.5)))])
	both([p1, p2], ["sync", "hop_done"])
	# --- gate 'lift': P2 rides the pillar while P1 holds the plate; P2 unrolls the vine down the terrace face ---
	p2.append(["go", cx(71.5), {"tol": 2}])
	p2.append(["mark", "on the lift"])
	p1.append(["go", cx(61), {"tol": 2}])
	both([p1, p2], ["sync", "lift_ready"])
	p1.append(["go", cx(62.5), {"tol": 2}])
	p1.append(["mark", "on the plate"])
	p2.append(["until", stands_above_fn(TERRACE), 0])
	p2.append(["fn", hop_fn(cx(75), 6)])
	p2.append(["go", cx(74.5), {"tol": 2}])
	p2.append(["face", -1])
	p2.append(["fn", unroll_fn(73, D)])
	p1.append(["fn", hold_fn(func(lv: LevelBase, _h: PlayerBase) -> bool:
		var top: PlayerBase = hero(1)
		return top.is_grounded() and top.sim_pos.x >= cx(74) and top.sim_pos.y <= TERRACE)])
	both([p1, p2], ["sync", "vine2"])
	p1.append(["go", cx(73), {"tol": 2}])
	p1.append(["fn", climb_fn(11)])
	p1.append(["mark", "on the terrace"])
	both([p1, p2], ["sync", "terrace"])
	# --- the terrace: the slab bridge, the hopper and the digger, the Shellback (a pincer) ---
	p1.append(["go", 1500, fight])
	p2.append(["go", 1476, fight])
	p1.append(["until", solid_fn(96, 11), 0])
	p1.append(["wait", 12])
	p2.append(["until", solid_fn(96, 11), 0])
	p2.append(["wait", 20])
	p1.append(["go", cx(109) - 90, fight])
	p2.append(["go", cx(109) - 60, fight])
	both([p1, p2], ["sync", "shell1"])
	pincer(p1, p2, cx(109), TERRACE)
	both([p1, p2], ["sync", "shell1_done"])
	# --- down the slope to the runway: a glider each, then the glide over the gorge ---
	p1.append(["go", 1920, fight])
	p2.append(["go", 1880, fight])
	p1.append(["go", 1984, {"tol": 2}])
	p1.append(["go", 1900, {"tol": 2}])
	both([p1, p2], ["sync", "runway"])
	glide(p1, 0)
	glide(p2, 24)
	both([p1, p2], ["sync", "far_rim"])
	# --- the far rim: the Shellback at the tunnel's mouth (a pincer), then the Bull Rex (a Brace Wall) ---
	both([p1, p2], ["sync", "shell2"])
	pincer(p1, p2, cx(230), 368)
	both([p1, p2], ["sync", "shell2_done"])
	p1.append(["go", cx(242), {"tol": 2}])
	p2.append(["go", cx(242) + 10, {"tol": 2}])
	p1.append(["face", 1])
	p2.append(["face", 1])
	both([p1, p2], ["sync", "brace"])
	for p: Array in [p1, p2]:
		p.append(["until", rex_dazed_fn(), D])
		p.append(["strike", 0])
		p.append(["until", rex_dead_fn(), 0])
	both([p1, p2], ["sync", "rex_done"])
	p1.append(["hold", R])
	p2.append(["hold", R])
	return [p1, p2]


## A Shellback pincer at x (feet y): P1 baits 26 px in front (left), P2 hops over and strikes from 31 px behind.
func pincer(bait: Array, striker: Array, x: int, y: int) -> void:
	bait.append(["go", x - 90, {"tol": 2}])
	striker.append(["go", x - 60, {"tol": 2}])
	striker.append(["fn", hop_fn(x + 31, 12)])
	striker.append(["go", x + 31, {"tol": 1}])
	striker.append(["face", -1])
	striker.append(["sync", "behind%d" % x])
	bait.append(["sync", "behind%d" % x])
	bait.append(["go", x - 26, {"tol": 1}])
	bait.append(["face", 1])
	striker.append(["sync", "pincer%d" % x])
	bait.append(["sync", "pincer%d" % x])
	for k: int in 3:
		striker.append(["fn", strike_unless_dead_fn(x, y)])
	striker.append(["until", until_dead_fn(x, y), 0])


func strike_unless_dead_fn(x: int, y: int) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		if enemy_near(x, y, 64) == null or n >= 12:
			return -1
		return F if n < 8 else 0


## The glide from the runway (the solo route's take-off): run, take off with Up, glide on.
func glide(p: Array, delay: int) -> void:
	if delay > 0:
		p.append(["wait", delay])
	p.append(["keys", 48, R])
	p.append(["keys", 30, R | U])
	p.append(["keys", 53, R])
	p.append(["until", grounded_fn(), R])
	p.append(["mark", "landed on the far rim"])


func rex() -> EnemyBase:
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = entity as EnemyBase
		if foe != null and foe is BullRex:
			return foe
	return null


func rex_dazed_fn() -> Callable:
	return func(_lv: LevelBase, _h: PlayerBase) -> bool:
		var r: EnemyBase = rex()
		if r == null or r.dead:
			return true
		var tr: Object = traits_of(r)
		return tr != null and int(tr.get("dazed")) > 30


func rex_dead_fn() -> Callable:
	return func(_lv: LevelBase, _h: PlayerBase) -> bool:
		var r: EnemyBase = rex()
		return r == null or r.dead

extends "res://tools/autoplay/recorders/db3/bot_w3_l2_coop.gd"
## The two-stream route of w4_l1_coop "Cinder Shaft" (DB3; Expert only), recorded by probe_work.gd --bot --players=2.
## The view sinks one pixel per tick: a hero above its top edge is egged, one below its bottom edge dies. P1 plays the
## solo club route's keys (tools/autoplay/routes/w4_l1.inputs) wherever the co-op map is the solo map, and his own
## moves at the co-op edits; P2 follows P1's trail a few ticks behind (the breadcrumb follower) except at the gates.

const SOLO: String = "res://tools/autoplay/routes/w4_l1.inputs"


func header() -> String:
	return "# route: level=w4_l1_coop difficulty=expert players=2 ends=exit after=tally expect=eggs:0,wipes:0,x2_gates:2,painting:27,min_checkpoints:3\n" \
		+ "# The Expert two-stream route of Cinder Shaft in co-op (designer DB3; P1|P2, keys L R U D F K S; recorded from\n" \
		+ "# closed-loop duo macros, build/db3/bot_w4_l1_coop.gd). The view sinks one pixel per tick: P1 plays the solo club\n" \
		+ "# route's keys where the co-op map is the solo map and P2 follows his trail 24 ticks behind (a ledge apart on the\n" \
		+ "# zigzags, never under or over him); both hop the Shellback of the first gallery, push the heave boulder left into\n" \
		+ "# the chute together (gate 'boulder': it plugs the vent of the lava pool below), drop onto it one after the other\n" \
		+ "# as the pool comes into view and hop to the right bank; in the Cinder Cache P2 Shoulder-Hops off P1's head onto\n" \
		+ "# the shelf for Cave Painting 27; through the ember chute, the spike strata, the cavern and the Ember Hoard to the\n" \
		+ "# magma chamber, where P2 Shoulder-Hops onto the 8-row cliff (gate 'cliff'), clubs the coiled vine down and P1\n" \
		+ "# climbs it; both walk into the exit (the team exit). Some hurts, no egg. Nobody stands 243 ticks without input.\n"


## The solo route's keys from tick `from` to tick `to` as raw commands.
func solo_keys(prog: Array, from: int, to: int) -> void:
	var t0: int = 0
	for line: String in FileAccess.get_file_as_string(SOLO).split("\n"):
		if line.begins_with("#") or line.strip_edges() == "":
			continue
		for entry: String in line.strip_edges().split(",", false):
			var parts: PackedStringArray = entry.split(":")
			var n: int = int(parts[0])
			var k: int = 0
			for ch: String in parts[1]:
				match ch:
					"L": k |= L
					"R": k |= R
					"U": k |= U
					"D": k |= D
					"F": k |= F
					"K": k |= Defs.IN_LOOK
			var a: int = maxi(t0, from)
			var b: int = mini(t0 + n, to)
			if b > a:
				prog.append(["keys", b - a, k])
			t0 += n


## True from tick `tick` of the stage on.
func after(tick: int) -> Callable:
	return func(_lv: LevelBase, _h: PlayerBase) -> bool:
		return t >= tick


func cell_solid(c: int, r: int) -> Callable:
	return func(lv: LevelBase, _h: PlayerBase) -> bool:
		return lv.get_cell(c, r) != TileGrid.CH_AIR


func lands(y: int) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase) -> bool:
		return h.is_grounded() and h.sim_pos.y >= y


## The solo keys, but a strike (Fire) whenever a stinger is about to enter the club box in front.
func _slot_flags(s: int) -> int:
	var f: int = super._slot_flags(s)
	if s != 0 or not bool(opts.get("guard", false)):
		return f
	var h: PlayerBase = hero(0)
	if h == null or not h.is_grounded() or h.is_striking():
		return f
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = entity as EnemyBase
		if foe == null or foe.dead or not foe.awake or not (foe is Stinger):
			continue
		var dx: int = (foe.sim_pos.x - h.sim_pos.x) * h.facing
		var dy: int = foe.sim_pos.y - h.sim_pos.y
		if dx > 4 and dx < 40 and dy > -48 and dy < 4:
			return f | F | (U if dy < -24 else 0)
	return f


func build() -> Array:
	var p1: Array = []
	var p2: Array = []
	var stop: int = int(opts.get("stop", "999999"))
	# === The crater throat and the long ledges: the solo's keys down to the first digger gallery ===============
	# P1 plays the solo's keys down the long ledges (striking the lone stinger if it dives at him); P2 follows his trail
	# 24 ticks behind (closer, a falling hero swinging under his partner's ledge is lifted onto his head)
	solo_keys(p1, 0, 384)
	p2.append(["wait", 24])
	p2.append(["follow", 24, lands(512), {"hold": false}])
	# === Gallery one: over the Shellback (its shield faces the nearer hero) to the hole on the right ==========
	p1.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded(), 0])
	p1.append(["fn", pass_fn(262)])
	p2.append(["fn", pass_fn(240)])
	p1.append(["sync", "hole1"])
	p2.append(["sync", "hole1"])
	p1.append(["until", after(410), 0])
	p1.append(["until", lands(576), R])
	p2.append(["until", after(420), 0])
	p2.append(["until", lands(576), R])
	# === Gate "boulder": both push the heave boulder left into the chute; it falls into the lava pool below ====
	p1.append(["go", 200, {"tol": 3}])
	# P2 brakes at the slab's left end and drops nearly straight (never onto P1's head at the boulder's face)
	p2.append(["go", 262, {"tol": 2}])
	p2.append(["go", 246, {"tol": 2, "max": 40}])
	p2.append(["until", lands(620), 0])
	p2.append(["go", 214, {"tol": 3}])
	p1.append(["sync", "push"])
	p2.append(["sync", "push"])
	# push until the boulder stands over the chute (cols 7-8), then let go: it falls into the pool alone
	p1.append(["until", cell_solid(7, 38), L])
	p2.append(["until", cell_solid(7, 38), L])
	p1.append(["until", cell_solid(8, 46), 0])
	p2.append(["until", cell_solid(8, 46), 0])
	p1.append(["mark", "boulder in the pool"])
	# P1 drops down the chute onto the boulder as soon as the pool is on the view, jumps to the right bank
	p1.append(["go", 150, {"tol": 3}])
	p1.append(["until", after(545), 0])
	p1.append(["go", 128, {"tol": 2, "max": 40}])
	p1.append(["until", lands(730), 0])
	p1.append(["go", 120, {"tol": 2}])
	p1.append(["run", 136])
	p1.append(["leap", 226, 5, {"lead": 3}])
	p1.append(["go", 230, {"tol": 3}])
	p1.append(["mark", "right bank"])
	p2.append(["go", 160, {"tol": 3}])
	# P2 a little after P1 (he is off the boulder before P2 lands on it), before the view's top edge reaches him
	p2.append(["until", after(578), 0])
	p2.append(["go", 128, {"tol": 2, "max": 40}])
	p2.append(["until", lands(730), 0])
	p2.append(["go", 120, {"tol": 2}])
	p2.append(["run", 136])
	p2.append(["leap", 220, 5, {"lead": 3}])
	p2.append(["go", 214, {"tol": 3}])
	# === Down the exit hole onto the slab of the third stratum; P1 picks up the solo keys there ===============
	p1.append(["sync", "bank"])
	p2.append(["sync", "bank"])
	p1.append(["until", after(650), 0])
	p1.append(["until", lands(810), R])
	p1.append(["go", 292, {"tol": 1}])
	p1.append(["mark", "third stratum"])
	p2.append(["until", func(_lv: LevelBase, _h: PlayerBase) -> bool: return hero(0).sim_pos.y >= 800, 0])
	p2.append(["until", lands(810), R])
	p2.append(["go", 272, {"tol": 3}])
	p1.append(["until", after(733), 0])
	solo_keys(p1, 733, 1296)
	p2.append(["follow", 24, in_vault(), {"hold": false}])
	# === The Cinder Cache (the hatch band's team gate took both): P2 Shoulder-Hops off P1's head onto the shelf
	# 8 rows over the vault floor for Cave Painting 27 and drops back; P1 takes the gate back on the solo's tick ===
	p1.append(["go", 640, {"tol": 2}])
	p1.append(["face", 1])
	p1.append(["sync", "shelf"])
	p2.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded(), 0])
	p2.append(["go", 612, {"tol": 2}])
	p2.append(["face", 1])
	p2.append(["sync", "shelf"])
	p2.append(["wait", 4])
	p2.append(["fn", hop_fn(1, 1346)])
	p2.append(["mark", "on the shelf"])
	p2.append(["go", 696, {"tol": 3}])
	p2.append(["mark", "painting 27"])
	p2.append(["sync", "painted"])
	p1.append(["until", func(_lv: LevelBase, _h: PlayerBase) -> bool: return hero(1).sim_pos.y <= 1350 and hero(1).is_grounded(), 0])
	p1.append(["go", 470, {"tol": 2}])
	p1.append(["sync", "painted"])
	p2.append(["go", 640, {"tol": 3}])
	p2.append(["until", lands(1468), L])
	p2.append(["go", 520, {"tol": 3}])
	p2.append(["sync", "vault_done"])
	p1.append(["sync", "vault_done"])
	p1.append(["go", 456, {"tol": 2}])
	p1.append(["until", after(1607), 0])
	p1.append(["keys", 8, D])
	p1.append(["until", after(1635), 0])
	solo_keys(p1, 1635, mini(stop, 3060))
	# === Gate "cliff": the magma chamber - P1 at the cliff's foot, P2 Shoulder-Hops off his head onto the cliff
	# (8 rows) and clubs the coiled vine at its face down; P1 climbs it; both walk into the exit (the team exit) ====
	p1.append(["until", lands(2740), 0])
	p1.append(["go", 224, {"tol": 2}])
	p1.append(["face", -1])
	p1.append(["sync", "cliff"])
	p1.append(["sync", "unrolled"])
	p1.append(["go", 216, {"tol": 1}])
	p1.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.sim_pos.y <= 2626 and h.is_grounded(), U])
	p1.append(["go", 56, {"tol": 3}])
	p1.append(["hold", L])
	p2.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.sim_pos.x < 400, 0])
	p2.append(["follow", 24, after(2440), {"hold": false}])
	# from the checkpoint ledge on: never step off a ledge onto P1 waiting for the view just below
	p2.append(["follow", 24, func(_lv: LevelBase, h: PlayerBase) -> bool: return h.sim_pos.y >= 2740 and h.is_grounded() and hero(0).sim_pos.y >= 2740, {"hold": false, "below": true}])
	p2.append(["go", 252, {"tol": 2}])
	p2.append(["face", -1])
	p2.append(["sync", "cliff"])
	p2.append(["wait", 4])
	p2.append(["fn", hop_fn(-1, 2626)])
	p2.append(["mark", "on the cliff"])
	p2.append(["go", 196, {"tol": 2}])
	p2.append(["face", 1])
	p2.append(["strike", 0])
	p2.append(["wait", 12])
	p2.append(["sync", "unrolled"])
	p2.append(["until", func(_lv: LevelBase, _h: PlayerBase) -> bool: return hero(0).sim_pos.y <= 2626 and hero(0).is_grounded(), 0])
	p2.append(["go", 72, {"tol": 3}])
	p2.append(["hold", L])
	return [p1, p2]


## True once this hero stands in a vault (the side rooms right of the shaft, x > 400).
func in_vault() -> Callable:
	return func(_lv: LevelBase, h: PlayerBase) -> bool:
		return h.sim_pos.x > 400 and h.is_grounded()

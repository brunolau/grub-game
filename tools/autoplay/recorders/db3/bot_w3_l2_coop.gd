extends "res://tools/autoplay/recorders/db3/botlib.gd"
## The two-stream routes of w3_l2_coop (DB3, Beginner and Expert), recorded by probe_work.gd --bot --players=2.
## P1 leads and fights, P2 follows a few cells behind. At the leaper lake P1 curls at the bank's edge and P2 (club in
## hand) bats him over the pool; P1 strikes the far bank's drum while P2 strikes the near one: the floes freeze into a
## bridge and P2 walks over. In the skylight cave P1 stands under the crystal cache and P2 Shoulder-Hops onto its
## ledge, takes Cave Painting 26 (not the warp) and drops back; both walk into the exit (the team exit).

const S: int = Defs.IN_SWAP


func header() -> String:
	if expert:
		return "# route: level=w3_l2_coop difficulty=expert players=2 ends=exit after=tally expect=eggs:0,wipes:0,x2_gates:2,painting:26,min_checkpoints:3\n"
	return "# route: level=w3_l2_coop difficulty=beginner players=2 ends=exit after=tally expect=eggs:0,wipes:0,x2_gates:2,painting:26,min_checkpoints:3\n"


func past(slot: int, x: int) -> Callable:
	return func(_lv: LevelBase, _h: PlayerBase) -> bool:
		return hero(slot).sim_pos.x >= x


func below(slot: int, y: int) -> Callable:
	return func(_lv: LevelBase, _h: PlayerBase) -> bool:
		return hero(slot).sim_pos.y >= y and hero(slot).is_grounded()


func landed_at(slot: int, x0: int, x1: int, y: int) -> Callable:
	return func(_lv: LevelBase, _h: PlayerBase) -> bool:
		var h: PlayerBase = hero(slot)
		return h.is_grounded() and h.sim_pos.x >= x0 and h.sim_pos.x <= x1 and absi(h.sim_pos.y - y) <= 4


func strikes(prog: Array, extra: int, count: int, pause: int = 6) -> void:
	for i: int in count:
		prog.append(["strike", extra])
		prog.append(["wait", pause])


## Curl (Down + Swap) and stay curled until launched; done once back on the ground for 8 ticks.
func curl_fn() -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n == 0:
			return D | S
		if not h.is_grounded():
			st["flying"] = true
			st["ground"] = 0
			return 0
		if bool(st.get("flying", false)):
			st["ground"] = int(st.get("ground", 0)) + 1
			return -1 if int(st["ground"]) >= 8 else 0
		if n > 200:
			return -1
		return D if h.curl == PlayerBase.CURL_CURLED else 0


## The batter: wait until the partner is curled, then a forward strike.
func bat_fn() -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var other: PlayerBase = hero(1 - h.slot)
		var st: Dictionary = _st[h.slot]
		if int(st.get("swing", 0)) > 0:
			st["swing"] = int(st["swing"]) - 1
			return F if int(st["swing"]) > 2 else (0 if int(st["swing"]) > 0 else -1)
		if other.curl == PlayerBase.CURL_CURLED and other.is_grounded():
			st["swing"] = 10
			return F
		if n > 120:
			return -1
		return 0


## The Shoulder Hop (see bot_ending_coop.gd): jump holding Up onto the partner's head, keep Up through the bounce and
## drift toward `land_dir` until standing high.
func hop_fn(land_dir: int, top_y: int) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		var other: PlayerBase = hero(1 - h.slot)
		if n > 200:
			return -1
		if h.is_grounded() and n > 4:
			if h.sim_pos.y <= top_y:
				return -1
			if bool(st.get("bounced", false)):
				return -1
		if not h.is_grounded() and h.yvel < -150 and n > 6:
			st["bounced"] = true
		if bool(st.get("bounced", false)):
			return U | (R if land_dir > 0 else L)
		var dx: int = other.sim_pos.x - h.sim_pos.x
		var k: int = U
		if n < 3:
			k |= R if dx > 0 else L
		elif absi(dx) > 3 and h.yvel > 0:
			k |= R if dx > 0 else L
		return k


func grounded_past(slot: int, x: int) -> Callable:
	return func(_lv: LevelBase, _h: PlayerBase) -> bool:
		return hero(slot).sim_pos.x >= x and hero(slot).is_grounded()


func has_curled_partner() -> Callable:
	return func(_lv: LevelBase, _h: PlayerBase) -> bool:
		return hero(0).curl == PlayerBase.CURL_CURLED


func build() -> Array:
	var fight: Dictionary = {"fight": true}
	var p1: Array = []
	var p2: Array = []
	# === Outside: the Shellback turtle (a pincer: P1 baits in front, P2 jumps over and clubs its back) ==========
	p2.append(["go", 124, {"tol": 2}])
	p2.append(["run", 168])
	p2.append(["jump", 1, 16, {"air": R}])
	p2.append(["go", 256, {"tol": 2}])
	p2.append(["face", -1])
	p2.append(["sync", "pincer"])
	p2.append(["strike", 0])
	p2.append(["wait", 6])
	p2.append(["strike", 0])
	p2.append(["sync", "turtle_done"])
	p1.append(["wait", 6])
	p1.append(["go", 100, {"tol": 2}])
	p1.append(["until", grounded_past(1, 240), 0])
	p1.append(["go", 186, {"tol": 2}])
	p1.append(["face", 1])
	p1.append(["sync", "pincer"])
	p1.append(["wait", 16])
	p1.append(["sync", "turtle_done"])
	# === The gallery mouth: the dangler (P1 high strikes), P2 waits behind ======================================
	p1.append(["go", 407, fight.merged({"tol": 2})])
	p1.append(["face", 1])
	strikes(p1, U, 2)
	# P2 shadows P1 (replays his moves a little later, parking behind him) down to the leaper lake
	p2.append(["shadow", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.sim_pos.x >= 1060 and h.is_grounded(), {}])
	p2.append(["go", 1100, fight.merged({"tol": 3})])
	# === Down the first descent: the dart of the alcove (P1 high strikes at the landing) ========================
	p1.append(["go", 629, fight.merged({"tol": 2})])
	p1.append(["face", 1])
	strikes(p1, U, 3)
	# === Down the second descent: the swirling axes (one each), over the cracked ice and down to the lake =======
	p1.append(["go", 1000, fight.merged({"tol": 3})])
	p1.append(["go", 1130, fight.merged({"tol": 2})])
	p1.append(["mark", "lake"])
	p2.append(["mark", "lake"])
	# === The leaper lake: both pits in one go when no leaper is out (the solo's two long jumps), P2 a moment later ==
	p1.append(["go", 1174, {"tol": 1}])
	p1.append(["sync", "lake_ready"])
	p1.append(["until", lake_quiet(), 0])
	raw(p1, "4:R,18:RU,4:R,8:,12:R,18:RU,6:R,4:")
	p1.append(["mark", "over the pits"])
	p2.append(["go", 1140, {"tol": 2}])
	p2.append(["sync", "lake_ready"])
	p2.append(["until", func(_lv: LevelBase, _h: PlayerBase) -> bool: return hero(0).sim_pos.x > 1200, 0])
	p2.append(["go", 1174, {"tol": 1}])
	raw(p2, "4:R,18:RU,4:R,8:,12:R,18:RU,6:R,4:")
	p2.append(["mark", "over the pits"])
	# === Gate "drive": P1 curls at the lip, P2 (the club back in hand) bats him over the pool =====================
	p1.append(["go", 1524 if expert else 1540, {"tol": 1}])
	p1.append(["face", 1])
	p1.append(["sync", "bat"])
	p1.append(["fn", curl_fn()])
	p1.append(["mark", "over the pool"])
	p2.append(["go", 1506 if expert else 1522, {"tol": 1}])
	p2.append(["face", 1])
	p2.append(["fn", club_in_hand_fn()])
	p2.append(["sync", "bat"])
	p2.append(["wait", 2])
	p2.append(["fn", bat_fn()])
	p2.append(["until", func(_lv: LevelBase, _h: PlayerBase) -> bool: return hero(0).is_grounded() and hero(0).sim_pos.x > 1600, 0])
	# === Gate "floes": both drums on the count of three ========================================================
	p1.append(["go", 1712, {"tol": 1}])
	p1.append(["face", 1])
	p1.append(["sync", "drums"])
	p1.append(["strike", 0])
	p2.append(["go", 1458, {"tol": 1}])
	p2.append(["face", -1])
	p2.append(["sync", "drums"])
	p2.append(["strike", 0])
	p2.append(["wait", 20])
	# P2 walks over the frozen floes; both jump the far drum and drop down the chasm
	p2.append(["go", 1690, {"tol": 3}])
	p2.append(["mark", "over the floes"])
	p1.append(["wait", 20])
	p1.append(["until", grounded_past(1, 1660), 0])
	p1.append(["jump", 1, 12, {"air": R}])
	p1.append(["fn", descend_fn()])
	p2.append(["until", past(0, 1800), 0])
	p2.append(["jump", 1, 12, {"air": R}])
	p2.append(["go", 1786, {"tol": 2}])
	p2.append(["until", func(_lv: LevelBase, _h: PlayerBase) -> bool: return hero(0).sim_pos.y >= 860 and hero(0).is_grounded() and hero(0).sim_pos.x >= 1870 and hero(0).xvel == 0, 0])
	p2.append(["run", 1806])
	p2.append(["until", below(1, 860), 0])
	p1.append(["mark", "lower gallery"])
	p2.append(["mark", "lower gallery"])
	# === The lower gallery: the checkpoint, over the first ice pit (the twin leaper), past the Shellback and the
	# Raptors, over the second pit ===============================================================================
	p1.append(["go", 1880 if expert else 1944, {"tol": 8}])
	p2.append(["go", 1850 if expert else 1876, {"tol": 6}])
	if expert:
		# Expert: a Raptor waits on the rock before the first pit: P1 bounces on its head, P2 clubs it while dazed.
		p1.append(["sync", "raptor0"])
		p2.append(["sync", "raptor0"])
		p1.append(["fn", duo_daze_fn("bounce", 1792, 1990)])
		p2.append(["fn", duo_daze_fn("strike", 1792, 1990)])
		p1.append(["mark", "rock raptor done"])
		p1.append(["sync", "raptor0_done"])
		p2.append(["sync", "raptor0_done"])
		p1.append(["go", 1944, {"tol": 6}])
		p2.append(["go", 1876, {"tol": 6}])
		# over the first pit while the Shellback walks away at the far end of the ice, over it, over the second pit
		# from the rock lip (P2 a little behind)
		p1.append(["go", 1950, {"tol": 2}])
		p1.append(["until", shell_away(), 0])
		p1.append(["fn", pit_jump_fn(1950, 2045, Vector2i(125, 53))])
		p1.append(["fn", pass_fn(2232)])
		p1.append(["fn", pit_jump_fn(2232, 2320, Vector2i(142, 53), 3)])
		p1.append(["go", 2318, {"tol": 3}])
		p2.append(["until", grounded_past(0, 2040), 0])
		p2.append(["go", 1950, {"tol": 2}])
		p2.append(["until", shell_away(), 0])
		p2.append(["fn", pit_jump_fn(1950, 2045, Vector2i(125, 53))])
		p2.append(["fn", pass_fn(2190)])
		p2.append(["until", grounded_past(0, 2310), 0])
		p2.append(["fn", pass_fn(2232)])
		p2.append(["fn", pit_jump_fn(2232, 2320, Vector2i(142, 53), 3)])
		# the second Raptor on the rock at the foot of the crystal shaft: P1 bounces, P2 clubs
		p1.append(["sync", "raptor1"])
		p2.append(["sync", "raptor1"])
		p1.append(["fn", duo_daze_fn("bounce", 2300, 2560)])
		p2.append(["fn", duo_daze_fn("strike", 2300, 2560)])
		p1.append(["mark", "shaft raptor done"])
		p1.append(["sync", "raptor1_done"])
		p2.append(["sync", "raptor1_done"])
		p1.append(["go", 2360, {"tol": 3}])
		p2.append(["go", 2330, {"tol": 3}])
	else:
		p1.append(["fn", pit_jump_fn(1950, 2045, Vector2i(125, 53))])
		p1.append(["go", 2090, fight.merged({"tol": 3})])
		p1.append(["fn", pit_jump_fn(2222, 2320, Vector2i(142, 53))])
		p1.append(["go", 2360, fight.merged({"tol": 3})])
		p2.append(["until", grounded_past(0, 2040), 0])
		p2.append(["fn", pit_jump_fn(1950, 2045, Vector2i(125, 53))])
		p2.append(["go", 2070, fight.merged({"tol": 3})])
		p2.append(["until", grounded_past(0, 2320), 0])
		p2.append(["fn", pit_jump_fn(2222, 2320, Vector2i(142, 53))])
		p2.append(["go", 2330, fight.merged({"tol": 3})])
	# === The crystal shaft: up the one-way slabs (rows 51, 48, 45, 42, 39, 36, left and right in turn), P2 one slab
	# behind P1: P2 leaps onto a slab once P1 has left it for the next one ===================================
	p1.append(["fn", climb_shaft_fn(2600)])
	p2.append(["until", func(_lv: LevelBase, _h: PlayerBase) -> bool: return _slab_index(hero(0)) >= 1, 0])
	p2.append(["fn", climb_shaft_fn(2560)])
	p1.append(["go", 2600, fight.merged({"tol": 3})])
	# === The skylight cave: P1 under the crystal cache, P2 hops onto its ledge for Cave Painting 26 ==============
	p1.append(["go", 2700, {"tol": 2}])
	p1.append(["face", -1])
	p1.append(["sync", "hop"])
	p2.append(["go", 2730, {"tol": 2}])
	p2.append(["face", -1])
	p2.append(["sync", "hop"])
	p2.append(["wait", 4])
	p2.append(["fn", hop_fn(-1, 452)])
	p2.append(["mark", "on the cache ledge"])
	p2.append(["go", 2646, {"tol": 3}])
	p2.append(["mark", "painting"])
	p2.append(["sync", "painting"])
	p1.append(["sync", "painting"])
	# P1 to the exit totem; P2 walks off the ledge and joins him
	p1.append(["go", 2760, {"tol": 3}])
	p1.append(["hold", R])
	p2.append(["go", 2760, {"tol": 3}])
	p2.append(["hold", R])
	return [p1, p2]


## Jump from a slab of the shaft to the next one: Up 14 ticks with the direction, then the direction until standing.
func climb_fn(dir: int) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var k: int = (R if dir > 0 else (L if dir < 0 else 0))
		if n < 14:
			return U | k
		if h.is_grounded() and n > 16:
			return -1
		if n > 120:
			return -1
		return k


## Hunt the leaper of record cell `cell` until it is dead: wait at x (facing `face`); with a throwing weapon throw at it
## whenever it is level with the hero and in front, with the club walk up to it while it rests and strike (the fight
## prediction also strikes at it in flight).
func kill_fn(cell: Vector2i, x: int, face: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		# the pit's record is a dormant spawner (never awake); what leaps out are its copies
		var target: EnemyBase = null
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var foe: EnemyBase = entity as EnemyBase
			if foe != null and not foe.dead and foe.awake and absi((foe.spawn_pos.x >> 4) - cell.x) <= 2 					and absi(((foe.spawn_pos.y - 1) >> 4) - cell.y) <= 4:
				target = foe
		if target != null:
			st["seen"] = true
		elif bool(st.get("seen", false)) or n > 900:
			return -1
		if target == null:
			if absi(h.sim_pos.x - x) > 3:
				return _go_x(h, st, x, 2)
			if h.facing != face:
				return R if face > 0 else L
			return 0
		if int(st.get("striking", 0)) > 0:
			st["striking"] = int(st["striking"]) - 1
			return F if int(st["striking"]) > 3 else 0
		if not h.is_grounded():
			return 0
		var thrower: bool = h.run.weapon != Defs.Weapon.CLUB
		var dx: int = target.sim_pos.x - h.sim_pos.x
		var dy: int = target.sim_pos.y - h.sim_pos.y
		if target.awake and target.tangible:
			if thrower:
				if dy > -120 and dy < 20 and absi(dx) < 160 and absi(dx) > 14 and not _own_throw(lv, h.slot):
					if h.facing != signi(dx):
						return R if dx > 0 else L
					st["striking"] = 9
					return F
			else:
				var f: int = _fight(h, {"fight": true, "wait_px": 0})
				if f >= 0:
					return f
				if target.yvel == 0 and absi(dy) < 8 and absi(dx) > 26 and absi(dx) < 120:
					return R if dx > 0 else L
		if absi(h.sim_pos.x - x) > 3:
			return _go_x(h, st, x, 2)
		if h.facing != face:
			return R if face > 0 else L
		return 0


func _own_throw(lv: LevelBase, slot: int) -> bool:
	for entity: SimEntity in lv.get_kind(Defs.Kind.HERO_PROJECTILE):
		var p: ProjectileBase = entity as ProjectileBase
		if p != null and not p.spent and p.owner_slot == slot:
			return true
	return false


## Jump a leaper pit: walk to x0 and stop, wait while its leaper (record cell `cell`) is up, run `run` ticks, jump
## (Up 14 ticks, Right held) and land past x1.
func pit_jump_fn(x0: int, x1: int, cell: Vector2i, run: int = 5) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if not bool(st.get("at", false)):
			var dx: int = x0 - h.sim_pos.x
			if absi(dx) <= 3 and h.xvel == 0 and h.is_grounded():
				st["at"] = true
			elif n > 300:
				st["at"] = true
			else:
				var speed: int = absi(h.xvel)
				if h.xvel != 0 and signi(h.xvel) == signi(dx) and absi(dx) <= (speed * speed) / (2 * 12 * 16) + 2:
					return 0
				return R if dx > 0 else (L if dx < 0 else 0)
		if not bool(st.get("go", false)):
			if _leaper_up(lv, cell) and n < 500:
				return 0
			st["go"] = true
			st["t"] = n
		var k: int = n - int(st["t"])
		if k < run:
			return R
		if k < run + 14:
			return U | R
		if not h.is_grounded() or k < run + 18:
			return R
		if h.sim_pos.x < x1:
			return R
		return -1


## True while the leaper of record cell `cell` is out of its pit (or about to jump).
func _leaper_up(lv: LevelBase, cell: Vector2i) -> bool:
	for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = entity as EnemyBase
		if foe == null or foe.dead or not foe.awake or not (foe is Leaper):
			continue
		if absi((foe.sim_pos.x >> 4) - cell.x) <= 4 and absi(((foe.sim_pos.y - 1) >> 4) - cell.y) <= 8:
			return true
	return false


## Down the chasm: walk right off the far bank (if the jump over the drum did not carry him over already) and fall
## straight into the lower gallery; done once standing on its floor.
func descend_fn() -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		if h.is_grounded() and h.sim_pos.y >= 860:
			return -1
		if n > 400:
			return -1
		return R if h.sim_pos.y < 590 else 0


## True while no leaper copy is out of the lake's pits (the records are dormant spawners; their copies leap).
func lake_quiet() -> Callable:
	return func(lv: LevelBase, _h: PlayerBase) -> bool:
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var foe: EnemyBase = entity as EnemyBase
			if foe != null and not foe.dead and foe.awake and foe.sim_pos.x > 1000 and foe.sim_pos.x < 1500:
				return false
		return true


## Raw keys of a run-length text ("4:R,15:,14:RU") as one command list entry per run.
func raw(prog: Array, text: String) -> void:
	for entry: String in text.split(",", false):
		var parts: PackedStringArray = entry.split(":")
		var k: int = 0
		for ch: String in parts[1]:
			match ch:
				"L": k |= L
				"R": k |= R
				"U": k |= U
				"D": k |= D
				"F": k |= F
		prog.append(["keys", int(parts[0]), k])


## Swap until the club is in hand (the swirling axe goes to the belt).
func club_in_hand_fn() -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		if h.run.weapon == Defs.Weapon.CLUB:
			return -1
		if n > 40:
			return -1
		return S if n % 12 == 0 else 0


## True while the Shellback of the ice strip (a walker between the two pits) is dead or walks right in the far half
## of its beat (the landing of the first pit is clear for a while).
func shell_away() -> Callable:
	return func(lv: LevelBase, _h: PlayerBase) -> bool:
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var foe: EnemyBase = entity as EnemyBase
			if foe == null or foe.dead or foe is Leaper or foe.coop_traits() == null:
				continue
			if foe.coop_traits().kind != Defs.CoopTrait.SHELL or foe.sim_pos.x < 2032 or foe.sim_pos.x > 2256:
				continue
			return foe.sim_pos.x >= 2110 and foe.xvel > 0
		return true


## The crystal shaft, robustly: the one-way slabs (centre x, feet y) from the floor up; the hero finds the slab he
## stands on and leaps to the next one (from its near half, rising before he steers); the follower waits while his
## partner still stands on the slab he wants (never on his head). Done on the top slab, walked out to `out_x`.
const SLABS: Array = [[2416, 816], [2500, 768], [2416, 720], [2500, 672], [2416, 624], [2500, 576]]


func _slab_index(h: PlayerBase) -> int:
	if not h.is_grounded():
		return -2
	if h.sim_pos.y >= 860:
		return -1
	# the top slab's level runs on over the shaft's right wall towards the skylight cave
	if absi(h.sim_pos.y - int(SLABS[SLABS.size() - 1][1])) <= 3 and h.sim_pos.x >= 2460:
		return SLABS.size() - 1
	for i: int in SLABS.size():
		if absi(h.sim_pos.y - int(SLABS[i][1])) <= 3 and absi(h.sim_pos.x - int(SLABS[i][0])) <= 48:
			return i
	return -3


func climb_shaft_fn(out_x: int) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		var other: PlayerBase = hero(1 - h.slot)
		if n > 1500:
			return -1
		if int(st.get("air", 0)) > 0:
			st["air"] = int(st["air"]) + 1
			var tx: int = int(st["tx"])
			var k: int = 0
			if int(st["air"]) > 5 and absi(tx - h.sim_pos.x) > 3:
				k = R if tx > h.sim_pos.x else L
			if int(st["air"]) <= 15:
				k |= U
			if h.is_grounded() and int(st["air"]) > 4:
				st["air"] = 0
			return k
		var at: int = _slab_index(h)
		if at == -2:
			return 0
		if at == SLABS.size() - 1:
			if h.sim_pos.x >= out_x - 3:
				return -1
			return R
		if at == -3:
			# off the slabs (a knock): back to the floor under the shaft
			return L if h.sim_pos.x > 2440 else R
		var next: Array = SLABS[at + 1]
		# wait while the partner stands on the slab I want, or is in the air over the shaft
		var oat: int = _slab_index(other)
		if (oat == at + 1 and absi(other.sim_pos.x - int(next[0])) < 48) or (oat == -2 and other.sim_pos.y < h.sim_pos.y and absi(other.sim_pos.x - int(next[0])) < 60):
			return 0
		# jump from my slab's side nearest the next slab, about 24 px in from its centre
		var from_x: int = int(SLABS[at][0]) if at >= 0 else 2440
		from_x += 20 if int(next[0]) > from_x else -20
		if at == -1:
			from_x = 2444
		if absi(h.sim_pos.x - from_x) > 3 or h.xvel != 0:
			return _go_x(h, st, from_x, 3) if absi(h.sim_pos.x - from_x) > 3 else 0
		st["air"] = 1
		st["tx"] = int(next[0])
		return U

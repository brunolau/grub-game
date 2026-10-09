extends "res://tools/autoplay/recorders/d6/bot_w6_l1_coop.gd"
## enemies-A (wf10 resumed, G57): D6's w6_l1_coop bot for one hit per strike in co-op files. A Tar Splitter (or a split
## tar blob) split by one hero's swing keeps its record half for that swing, and the Expert window (12 ticks) closes
## before a lone striker's next swing - so the pair now fights TOGETHER: on the root deck and on the last stretch to
## the exit totem the two heroes walk as one body (the same keys on the same tick from the same spot, `pair_fn`) and
## every strike is a twin strike: P1's box splits the whole record, P2's box kills the record half on the same tick
## and P1's box takes the spawned half on the next - both halves inside the window. While the two are not side by
## side nobody strikes a whole splitter alone. A Leech on a back is clubbed off by the partner from behind. While P1
## opens the root vine P2 fights at the root's foot (the first run's change). Every other macro is D6's.

const FORM_TOL: int = 3          # the two feet points this close (and at rest): one body from now on
const HOLD_TOL: int = 8          # ... and they stay one body while this close
const LEECH_BEHIND: int = 26     # the partner stands this far behind a leeched hero's back to club it off

var _pair: Dictionary = {}


func header() -> String:
	return super.header() + "# Re-recorded by enemies-A (wf10) for G57 (one hit per strike in co-op files: a swing hurts a given enemy once,\n" \
			+ "# so a Tar Splitter split by one swing keeps its record half for that swing): on the root deck and on the last\n" \
			+ "# stretch the pair walks side by side and strikes together (build/enemies_a11/bot_w6_l1_coop_g57.gd) - P1's\n" \
			+ "# box splits it, P2's kills the record half on the same tick, P1's takes the spawned half on the next.\n"


## The leech riding `h` (null: none).
func _leech_on(h: PlayerBase) -> EnemyBase:
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = entity as EnemyBase
		if foe == null or foe.dead:
			continue
		var traits: CoopTraits = foe.coop_traits()
		if traits != null and traits.host == h:
			return foe
	return null


## The names of the whole `split` records (a lone striker leaves them alone: D6's `ignore` option of the fight rule).
func _whole_splitters() -> Array:
	var names: Array = []
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = entity as EnemyBase
		if foe == null or foe.dead:
			continue
		var traits: CoopTraits = foe.coop_traits()
		if traits != null and traits.kind == Defs.CoopTrait.SPLIT and traits.split == CoopTraits.Split.WHOLE \
				and not traits.is_copy:
			names.append(String(foe.name))
	return names


func _steady(h: PlayerBase) -> bool:
	return h.is_grounded() and h.xvel == 0 and h.state != Defs.HeroState.HURT and not h.dead and not h.down


## Hold the direction to `x` until `h` is within `tol` px (released in time to stop there); -1 once he rests there.
func _walk_to(h: PlayerBase, x: int, tol: int) -> int:
	var dx: int = x - h.sim_pos.x
	if absi(dx) <= tol:
		return -1 if h.xvel == 0 else 0
	var speed: int = absi(h.xvel)
	var stop: int = (speed * speed) / (2 * 12 * 16) + 1
	if h.xvel != 0 and signi(h.xvel) == signi(dx) and absi(dx) <= stop + tol:
		return 0
	return R if dx > 0 else L


## The pair's fight rule (both heroes get its keys): D6's rule for everything but a whole splitter; a whole splitter is
## struck only when its box will be inside the forward club box on the box's FIRST ticks (5 and 6 ticks from now), so
## P1's box splits it and P2's kills the record half at once, and P1's later box ticks take the spawned half that runs
## at them (a split on the box's last tick leaves that half alive: it hurt both).
func _twin_fight(h: PlayerBase, behind: int = 0) -> int:
	var st: Dictionary = _st[h.slot]
	if int(st.get("striking", 0)) > 0 or not h.is_grounded():
		return _fight(h, {"fight": true})
	var wholes: Array = _whole_splitters()
	var f: int = h.facing
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = entity as EnemyBase
		if foe == null or foe.dead or not foe.awake or not foe.tangible or not wholes.has(String(foe.name)):
			continue
		var dx: float = foe.sim_pos.x - h.sim_pos.x
		var dy: float = foe.sim_pos.y - h.sim_pos.y
		var vx: float = foe.xvel / 16.0
		var hv: float = h.xvel / 16.0
		var inside: bool = true
		for k: int in [5, 6]:
			var fx: float = dx + (vx - hv * 0.5) * k
			var left: float = fx - foe.box_xo
			var right: float = left + foe.box_w
			var top: float = dy - foe.box_h
			# ... inside BOTH boxes: the partner stands `behind` px back, his box ends that much earlier.
			var far: float = 32.0 - behind
			var hit_x: bool = (right > 13.0 and left < far) if f > 0 else (left < -13.0 and right > -far)
			if not (hit_x and dy > -15.0 and top < -2.0):
				inside = false
		if inside:
			st["striking"] = 9
			st["strike_keys"] = 0
			return F
	return _fight(h, {"fight": true, "ignore": wholes})


## One tick of the pair (called for slot 0; slot 1 reads the result): keys for both heroes.
func _pair_step(until_x: int, rally_x: int) -> void:
	var a: PlayerBase = hero(0)
	var b: PlayerBase = hero(1)
	_pair["tick"] = t
	_pair["done"] = false
	var st: Dictionary = _st[0]
	var sync: bool = str(_pair.get("mode", "align")) == "sync"
	# A twin strike in progress is finished by both, whatever happens.
	var behind: int = maxi((a.sim_pos.x - b.sim_pos.x) * a.facing, 0)
	if sync and int(st.get("striking", 0)) > 0:
		var keys: int = _twin_fight(a, behind)
		_pair["k0"] = keys
		_pair["k1"] = keys
		return
	# A leech on a back: the host stands, the partner clubs it off from behind.
	for slot: int in 2:
		var host: PlayerBase = hero(slot)
		var other: PlayerBase = hero(1 - slot)
		if _leech_on(host) == null or host.dead or host.down or other.dead or other.down:
			continue
		_pair["mode"] = "leech"
		var spot: int = host.sim_pos.x - host.facing * LEECH_BEHIND
		var keys: int = 0
		var ost: Dictionary = _st[other.slot]
		if int(ost.get("lstrike", 0)) > 0:
			ost["lstrike"] = int(ost["lstrike"]) - 1
			keys = F if int(ost["lstrike"]) > 3 else 0
		elif not other.is_grounded():
			keys = 0
		elif absi(other.sim_pos.x - spot) > 5:
			keys = R if spot > other.sim_pos.x else L
		elif other.facing != host.facing:
			keys = R if host.facing > 0 else L
		else:
			ost["lstrike"] = 9
			keys = F
		_pair["k%d" % other.slot] = keys
		_pair["k%d" % host.slot] = 0
		return
	if a.sim_pos.x >= until_x and b.sim_pos.x >= until_x:
		_pair["done"] = true
		return
	var calm: bool = a.state != Defs.HeroState.HURT and b.state != Defs.HeroState.HURT and not a.dead and not b.dead \
			and not a.down and not b.down
	if sync and calm and absi(a.sim_pos.x - b.sim_pos.x) <= HOLD_TOL and absi(a.sim_pos.y - b.sim_pos.y) <= 8\
			and a.facing == b.facing:
		var keys: int = _twin_fight(a, behind)
		if keys < 0:
			keys = R
		_pair["k0"] = keys
		_pair["k1"] = keys
		return
	# Align: P1 stands (fighting what comes, but no whole splitter alone), P2 walks to his spot; then both face right
	# and go on as one.
	if sync and opts.has("pair_log"):
		print("PAIR t=%d apart: P1 %s v%d f%d st%d | P2 %s v%d f%d st%d" % [t, a.sim_pos, a.xvel, a.facing, a.state,
			b.sim_pos, b.xvel, b.facing, b.state])
	_pair["mode"] = "align"
	var alone: Dictionary = {"fight": true, "ignore": _whole_splitters()}
	var k0: int = _fight(a, alone)
	var k1: int = _fight(b, alone)
	if a.sim_pos.y != b.sim_pos.y or not a.is_grounded() or not b.is_grounded():
		# Not on one floor yet (thrown off Chomper, a drop, a hurt's arc): whoever stands on his partner's head steps
		# off it to the right; of two floors the upper hero walks to the lower one's spot (and on to the right over
		# the edge when he is above it).
		var ks: Array[int] = [k0, k1]
		for slot: int in 2:
			if ks[slot] >= 0:
				continue
			var me: PlayerBase = hero(slot)
			var mate: PlayerBase = hero(1 - slot)
			ks[slot] = 0
			if not me.is_grounded() or not mate.is_grounded():
				continue
			if me.is_riding_totem():
				ks[slot] = R
			elif me.sim_pos.y < mate.sim_pos.y and not mate.is_riding_totem():
				ks[slot] = L if me.sim_pos.x > mate.sim_pos.x + 2 else R
		_pair["k0"] = ks[0]
		_pair["k1"] = ks[1]
		return
	if k0 < 0:
		k0 = 0
		# The first time on this stretch P1 walks to the rally point (out of a splitter's beat) before P2 joins him.
		if rally_x >= 0 and not _pair.has("rallied%d" % until_x):
			k0 = _walk_to(a, rally_x, 3)
			if k0 < 0:
				k0 = 0
				_pair["rallied%d" % until_x] = true
	if k1 < 0:
		# P2 a step behind P1 at most, never ahead: P1's box (slot order) must be the one that splits.
		k1 = _walk_to(b, a.sim_pos.x - 2, 2)
		if k1 < 0:
			k1 = 0
			if _steady(a) and _steady(b) and k0 == 0:
				if a.facing != 1 or b.facing != 1:
					# One tap of Right turns whoever looks left (both get it, so both move the same).
					k0 = R
					k1 = R
				else:
					_pair["mode"] = "sync"
					if opts.has("pair_log"):
						print("PAIR t=%d one body at %s / %s" % [t, a.sim_pos, b.sim_pos])
	_pair["k0"] = k0
	_pair["k1"] = k1


## Both heroes run this on the same stretch: they walk right to `until_x` as one body, twin strikes at what comes.
func pair_fn(until_x: int, rally_x: int = -1) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n > 3000:
			return -1
		if h.slot == 0:
			_pair_step(until_x, rally_x)
		if int(_pair.get("tick", -1)) != t:
			return 0
		if bool(_pair.get("done", false)):
			return -1
		return int(_pair.get("k%d" % h.slot, 0))


## Fight (D6's `fight` rule) until `cond` holds and the root's vine hangs (or 420 ticks).
func _guard_fn(cond: Callable) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n > 420 or (cond.call(lv, h) and _vine_hangs(lv)):
			return -1
		var keys: int = _fight(h, {"fight": true})
		return keys if keys >= 0 else 0


func _vine_hangs(lv: LevelBase) -> bool:
	for entity: SimEntity in lv.get_kind(Defs.Kind.HITTABLE):
		var vine: Vine = entity as Vine
		if vine != null and vine.vine_x >> 4 == ROOT0 - 1:
			return vine.unrolled
	return true


func build() -> Array:
	var progs: Array = super.build()
	var deck_to: int = int(opts.get("deck_to", str(cx(155))))
	for slot: int in 2:
		var p: Array = progs[slot]
		# --- the root deck: the pair as one body ---
		var at_deck: int = -1
		for i: int in p.size():
			if str(p[i][0]) == "mark" and str(p[i][1]) == "deck":
				at_deck = i
				break
		# D6: mark deck, wait, run cx(155) - slot * 30 (fight).
		p[at_deck + 1] = ["sync", "deck_pair"]
		p[at_deck + 2] = ["fn", pair_fn(deck_to)]
	# --- gate 'root': P2 fights at the root's foot while P1 opens the vine ---
	var p2: Array = progs[1]
	var at_hop: int = -1
	for i: int in p2.size():
		if str(p2[i][0]) == "sync" and str(p2[i][1]) == "hop":
			at_hop = i
			break
	for i: int in range(at_hop + 1, p2.size()):
		if str(p2[i][0]) == "until":
			p2[i] = ["fn", _guard_fn(p2[i][1] as Callable)]
			break
	# --- the last stretch: thrown off Chomper at letter R's stump, then the pair as one body to the exit totem ---
	for slot: int in 2:
		var p: Array = progs[slot]
		for i: int in range(p.size() - 1, -1, -1):
			if str(p[i][0]) == "run":
				p[i] = ["fn", pair_fn(cx(250), int(opts.get("rally", "3642")))]
				p.insert(i, ["sync", "last_pair"])
				break
	return progs

class_name VersusHotRock
extends RefCounted
## Hot Rock (docs/expansion/DESIGN.md E.4, GAMEPLAY.md 13.10.5, PHYSICS.md C.14 "Hot Rock holder"): a glowing ember
## sticks to one hero and passes to the other hero on any body touch, hit or stomp; whoever passed it cannot receive
## it back for 44 ticks; its holder walks up to 96 v16. The fuse is 291-486 ticks (Sim.rng, the round seed) and
## bubbles faster in its last 73; then the holder pops (the death toss) and is out, and 66 ticks later the ember picks
## a new holder among the rest with a new fuse. Last one standing wins; first to 3. Owner: world-B (PLAN.md P2.4).
##
## The referee owns the state of the round and calls in: [method tick] from its WORLD step (first pick, fuse, pop,
## re-pick), [method touch] from its PLAYER step (body touches after every hero moved) and [method contact] for every
## hit or stomp it applies. The holder's walk cap is read by the referee's weight step ([method walk_cap_for]).

## The slot holding the ember (-1 = nobody: before the first pick and between a pop and the next pick).
var holder: int = -1
## Ticks left on the fuse, and its whole length.
var fuse_left: int = 0
var fuse_total: int = 0
## Round tick on which the next holder is picked (-1 = none pending).
var pick_at: int = VersusTuning.HOT_ROCK_FIRST_PICK_TICKS
## Per slot: the round tick until which he cannot receive the ember (he just passed it).
var immune_until: PackedInt32Array = PackedInt32Array([-1, -1, -1, -1])
## Passes so far this round.
var passes: int = 0
## Pops so far this round.
var pops: int = 0

var _referee: VersusReferee = null


func _init(referee: VersusReferee) -> void:
	_referee = referee


## Back to the round start: nobody holds it; the first pick comes HOT_ROCK_FIRST_PICK_TICKS after the gong.
func reset() -> void:
	holder = -1
	fuse_left = 0
	fuse_total = 0
	pick_at = VersusTuning.HOT_ROCK_FIRST_PICK_TICKS
	immune_until.fill(-1)
	passes = 0
	pops = 0


## True in the fuse's last VersusTuning.HOT_ROCK_HURRY_TICKS (it bubbles faster).
func in_hurry() -> bool:
	return holder >= 0 and fuse_left <= VersusTuning.HOT_ROCK_HURRY_TICKS


## The walk cap (v16) of `slot` in Hot Rock: the holder is the faster one.
func walk_cap_for(slot: int) -> int:
	return VersusTuning.HOT_ROCK_HOLDER_WALK_CAP if slot == holder else Tuning.WALK_CAP


## WORLD step (round tick `round_ticks`, already counted): pick, burn the fuse, pop.
func tick(round_ticks: int) -> void:
	if holder < 0:
		if pick_at >= 0 and round_ticks >= pick_at:
			_pick()
		return
	var hero: PlayerBase = _referee.level.get_hero(holder)
	if hero == null or hero.dead or not _referee.is_in_play(hero):
		# He left the round another way (a hazard): the ember waits for the next pick.
		holder = -1
		pick_at = round_ticks + VersusTuning.HOT_ROCK_REPICK_TICKS
		return
	fuse_left -= 1
	if fuse_left % (6 if in_hurry() else 24) == 0 and AudioTable.SFX.has(Sfx.HOT_ROCK_FUSE):
		Audio.play_sfx(Sfx.HOT_ROCK_FUSE)
	if fuse_left <= 0:
		_pop(hero, round_ticks)


## PLAYER step: a body touch between the holder and a rival who may receive it passes it (the first in slot order).
func touch(round_ticks: int) -> void:
	if holder < 0:
		return
	var from: PlayerBase = _referee.level.get_hero(holder)
	if from == null or not _referee.is_in_play(from):
		return
	for other: PlayerBase in _referee.heroes_in_order():
		if other == from or not _referee.is_in_play(other) or not can_receive(other.slot, round_ticks):
			continue
		if Overlap.body(from, other):
			pass_to(other.slot, round_ticks)
			return


## A hit or a stomp between `a` and `b` (either way round): the ember jumps to the one who did not hold it.
func contact(a: PlayerBase, b: PlayerBase, round_ticks: int) -> void:
	if a == null or b == null or holder < 0:
		return
	if a.slot == holder and can_receive(b.slot, round_ticks):
		pass_to(b.slot, round_ticks)
	elif b.slot == holder and can_receive(a.slot, round_ticks):
		pass_to(a.slot, round_ticks)


## True when `slot` may receive the ember now (he did not pass it within HOT_ROCK_PASS_IMMUNE_TICKS).
func can_receive(slot: int, round_ticks: int) -> bool:
	return slot >= 0 and slot < Defs.MAX_PLAYERS and slot != holder and round_ticks >= immune_until[slot]


## The ember goes from the holder to `slot`; the passer cannot get it back for HOT_ROCK_PASS_IMMUNE_TICKS.
func pass_to(slot: int, round_ticks: int) -> void:
	var from: int = holder
	holder = slot
	passes += 1
	if from >= 0:
		immune_until[from] = round_ticks + VersusTuning.HOT_ROCK_PASS_IMMUNE_TICKS
		var passer: PlayerBase = _referee.level.get_hero(from)
		if passer != null:
			passer.run.passes += 1
	if AudioTable.SFX.has(Sfx.BAT_HIT):
		Audio.play_sfx(Sfx.BAT_HIT)
	_referee.ember_changed.emit(holder)


func _pick() -> void:
	var standing: PackedInt32Array = PackedInt32Array()
	for hero: PlayerBase in _referee.heroes_in_order():
		if _referee.is_in_play(hero):
			standing.append(hero.slot)
	if standing.size() < 2:
		pick_at = -1
		return
	holder = standing[Sim.rng.pick_index(standing.size())]
	fuse_total = Sim.rng.range_int(VersusTuning.HOT_ROCK_FUSE_MIN_TICKS, VersusTuning.HOT_ROCK_FUSE_MAX_TICKS)
	fuse_left = fuse_total
	pick_at = -1
	immune_until.fill(-1)
	_referee.ember_changed.emit(holder)
	if AudioTable.SFX.has(Sfx.HOT_ROCK_FUSE):
		Audio.play_sfx(Sfx.HOT_ROCK_FUSE)


func _pop(hero: PlayerBase, round_ticks: int) -> void:
	holder = -1
	fuse_left = 0
	pops += 1
	pick_at = round_ticks + VersusTuning.HOT_ROCK_REPICK_TICKS
	if AudioTable.SFX.has(Sfx.EXPLOSION):
		Audio.play_sfx(Sfx.EXPLOSION)
	_referee.ember_changed.emit(-1)
	hero.kill(&"hot_rock")

class_name VersusReferee
extends SimEntity
## The versus referee of an arena (docs/spec/PHYSICS.md C.14, GAMEPLAY.md 13.10, DESIGN.md E.2 / E.3): the PartyDriver
## of a `kind = arena` level (TECH_AUDIT.md 4.9). Owner: world-B (docs/expansion/PLAN.md P1.7).
##
## Registered after every hero (VersusArena.setup -> LevelBase.register_party_driver), so in each phase it runs after
## the heroes did their own part:
##  - WEAPONS: every hero's club box of the previous tick that is still live after his own weapon pass (enemies,
##    hittables, curled partners and eggs come first, C.0) and every hero projectile are GATHERED against the rival
##    heroes, then APPLIED at once - nobody wins a trade by slot order. Clang (two front boxes meet: both cancelled and
##    pushed 8 px apart; a charged box wins), deflect (a front box bats a rival's special back, owned by the striker,
##    +32 v16), hits (the C.14 knock-back table, hit_timer 43, hit-stop 2 / 4), curled victims (glance from above, a
##    front box from the side bats him), teammates (a hit only bumps).
##  - PLAYER: after every hero moved: the lr / tb wrap of heroes and hero projectiles, the end of the immunity and of
##    the spawn shield when a hero starts a strike or a throw, the body bump, the stomp chain reset on the ground, the
##    weight caps of Grub Stack.
##  - CONTACT_ENEMIES: stomps gathered then applied (the stomp ladder 1-2-3-4-6-8 since the stomper's last ground
##    tick, an 8-tick squash, 30 immune ticks; an immune, shielded, curled or teammate head is a free springboard).
##  - WORLD: the round: intro countdown, clock, Feast Rush, gong, the Golden Drumstick on a tie.
##  - POST: hazards (knock-outs: credit to the last hitter within 73 ticks), respawns after 48 ticks at the free spawn
##    farthest from the rivals with a 48-tick spawn shield, the referee's own counters (spawn shield, squash, hit-stop,
##    stomp immunity) written to the heroes.
## The mode's currency: Grub Stack (the stack on the head, banking in the cookpot, spills and steals) and Last
## Caveman Standing (hearts); Hot Rock and Clubball hits only knock back (their rules are PLAN.md P2.4).
##
## The hero side of a hit is the contract call `victim.hurt(source, Defs.HurtKind.RIVAL)` (the hero's party
## component, player-A); right after it the referee writes the C.14 values itself and puts the run's hearts, bones
## back (the currency is the referee's), so the result is the same whatever the hero component does with the call.
##
## Public reading API (HUD, cookpot, bots, tests): [method find], [member mode], [member phase], [member round_index],
## [method stack_of], [method banked_of], [method score_of], [method leader_slot], [method time_left_ticks],
## [method in_feast_rush], [method lids_closed], [method bank_from] / [method bank_from_stack], [method is_banking],
## [method walk_cap_of], [method round_length], [method round_ticks_left], [method round_wins_of], [method team_of],
## [method food_value], [method weight_class],
## signal [signal stack_changed]; round control: [method begin_round], [method start_round_now], [method end_round].

## A hero's stack, bank or both changed (HUD, stack display).
signal stack_changed(slot: int, stack: int, banked: int)

## Round phases.
const PHASE_INTRO: int = 0   ## "3, 2, 1, GRUB!": heroes frozen at their spawns
const PHASE_PLAY: int = 1    ## the round runs
const PHASE_GOLDEN: int = 2  ## a tie: the Golden Drumstick fell, first to grab it wins (clock stopped)
const PHASE_OVER: int = 3    ## the gong: heroes frozen, the round loop takes over

## One count of the intro countdown (1 s); the intro is VersusTuning.COUNTDOWN_STEPS counts, then "GRUB!".
const INTRO_COUNT_TICKS: int = 24
## The food item that is the Golden Drumstick (a food picture worth nothing on the stack).
const GOLDEN_ID: StringName = &"items/food"
const GOLDEN_INDEX: int = 12
## Spilled units fly out as dropped items: 10s as giant bonuses, 5s as treasures, 1s as small food (R22).
const SPILL_GIANT_INDEX: int = 3
const SPILL_TREASURE_INDEX: int = 8
const SPILL_FOOD_INDEX: int = 0
## Points of a food picture from which it counts as big food (GAMEPLAY.md 3.2: small food 100 - 500).
const BIG_FOOD_MIN_POINTS: int = 600
## objects-B's cookpot (Cookpot.slot_banking_anywhere(level, slot)), read by path while it may not exist yet.
const COOKPOT_SCRIPT: String = "res://scripts/objects/cookpot.gd"
## The clang (DESIGN.md E.2, the Colossus clank); Sfx.IMPACT while AudioTable has no row for it.
const SFX_CLANG: StringName = Sfx.CLANG

## The level this referee runs (Game.level when it entered the tree).
var level: LevelBase = null
## Defs.VersusMode of the round.
var mode: int = Defs.VersusMode.GRUB_STACK
## Round index within the match (0-based; spawns rotate by it).
var round_index: int = 0
## PHASE_* of the round.
var phase: int = PHASE_INTRO
## Ticks the round has been played (PLAY and GOLDEN).
var round_ticks: int = 0
## Round length in ticks (0 = no clock: the round ends by the mode's own rule); [method round_length] reads it.
var round_total: int = 0
## VersusArena.WRAP_* of the arena.
var wrap: int = VersusArena.WRAP_NONE
## Team per slot (-1 = free for all); 2v2 teams share a cookpot and only bump each other.
var teams: PackedInt32Array = PackedInt32Array([-1, -1, -1, -1])
## Stack guard per slot in percent of every spill (handicap card: 50 / 100 / 150).
var guard_percent: PackedInt32Array = PackedInt32Array([100, 100, 100, 100])
## Last Caveman Standing: hearts per slot at a round start (handicap card 1-5).
var start_hearts: PackedInt32Array = PackedInt32Array([3, 3, 3, 3])
## False: hazard knock-outs respawn (Grub Stack; LCS option Stock); true: a knock-out is out for the round.
var knockouts_final: bool = false
## Winners of the round once it is over.
var winner_slots: PackedInt32Array = PackedInt32Array()
## Spawn index per slot this round (index into VersusArena.spawn_points; -1 = rotate by round_index).
var spawn_of: PackedInt32Array = PackedInt32Array([-1, -1, -1, -1])

# --- Per slot (index = player slot) -------------------------------------------------------------------------------
var _stack: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
## Banked units per pot (the slot, or the team's first slot in 2v2).
var _pot: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var _chain: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var _stomp_immune: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var _shield_left: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var _squash_left: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var _stop_left: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var _last_hitter: PackedInt32Array = PackedInt32Array([-1, -1, -1, -1])
var _last_hit_tick: PackedInt32Array = PackedInt32Array([-1, -1, -1, -1])
var _dead_tick: PackedInt32Array = PackedInt32Array([-1, -1, -1, -1])
var _out: PackedByteArray = PackedByteArray([0, 0, 0, 0])
var _bank_count: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var _bank_tick: PackedInt32Array = PackedInt32Array([-1, -1, -1, -1])
var _bank_seen: PackedInt32Array = PackedInt32Array([-1, -1, -1, -1])
var _picked_seen: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var _throws_left: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var _death_pos: Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO]
var _death_cause: Array[StringName] = [&"", &"", &"", &""]
var _walk_cap: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])

var _intro_ticks: int = 0
var _feast_rush: bool = false
var _golden: CollectibleBase = null
## Instance id of an emptied visible spot -> round tick it was found empty (the refill clock).
var _spot_empty_since: Dictionary = {}
var _wrapped: Dictionary = {}
var _display: Node2D = null
## The referee of the arena that entered the tree last ([method find] falls back to it when it is not the driver).
static var _current: VersusReferee = null


func get_kind() -> int:
	return Defs.Kind.OTHER


func _init() -> void:
	box_w = 0
	box_h = 0
	box_xo = 0


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([
		Defs.Phase.WEAPONS, Defs.Phase.PLAYER, Defs.Phase.CONTACT_ENEMIES, Defs.Phase.WORLD, Defs.Phase.POST,
	])


func _enter_tree() -> void:
	_current = self
	if level == null:
		level = Game.level
	if not Events.item_collected.is_connected(_on_item_collected):
		Events.item_collected.connect(_on_item_collected)
	if not Events.hero_died.is_connected(_on_hero_died):
		Events.hero_died.connect(_on_hero_died)


func _exit_tree() -> void:
	_exit_display()
	if _current == self:
		_current = null
	if Events.item_collected.is_connected(_on_item_collected):
		Events.item_collected.disconnect(_on_item_collected)
	if Events.hero_died.is_connected(_on_hero_died):
		Events.hero_died.disconnect(_on_hero_died)


func _ready() -> void:
	if level == null:
		level = Game.level
	_read_setup()
	begin_round(round_index)
	_add_display.call_deferred()


## The referee of `p_level` (its party driver, else the arena referee that entered the tree last for that level);
## null outside an arena.
static func find(p_level: LevelBase) -> VersusReferee:
	if p_level == null:
		return null
	var driver: VersusReferee = p_level.party_driver as VersusReferee
	if driver != null:
		return driver
	if is_instance_valid(_current) and _current.level == p_level:
		return _current
	return null


# =================================================================================================================
# Round control
# =================================================================================================================

## Start round `index`: every hero back at his rotated spawn (VersusTuning: spawns rotate every round), stacks,
## banks and counters cleared, the intro countdown (heroes frozen) running. Called once when the referee enters the
## level; the round loop calls it again for a rematch on the same arena.
func begin_round(index: int) -> void:
	round_index = maxi(index, 0)
	phase = PHASE_INTRO
	round_ticks = 0
	_intro_ticks = 0
	_feast_rush = false
	winner_slots = PackedInt32Array()
	_golden = null
	_wrapped.clear()
	_spot_empty_since.clear()
	round_total = _round_length()
	for slot: int in Defs.MAX_PLAYERS:
		_stack[slot] = 0
		_pot[slot] = 0
		_chain[slot] = 0
		_stomp_immune[slot] = 0
		_shield_left[slot] = 0
		_squash_left[slot] = 0
		_stop_left[slot] = 0
		_last_hitter[slot] = -1
		_last_hit_tick[slot] = -1
		_dead_tick[slot] = -1
		_out[slot] = 0
		_bank_count[slot] = 0
		_bank_tick[slot] = -1
		_bank_seen[slot] = -1
		_throws_left[slot] = 0
		_walk_cap[slot] = Tuning.WALK_CAP
	if level == null:
		return
	var spawns: Array[Vector2i] = VersusArena.spawn_points(level)
	for hero: PlayerBase in _heroes():
		var slot: int = hero.slot
		var spawn: int = spawn_of[slot] if spawn_of[slot] >= 0 else slot + round_index
		var pos: Vector2i = spawns[posmod(spawn, spawns.size())] if not spawns.is_empty() else hero.sim_pos
		level.respawn_hero(hero, pos)
		hero.facing = 1 if pos.x < VersusArena.view_rect().get_center().x else -1
		hero.run.hearts = start_hearts[slot] if mode == Defs.VersusMode.LAST_CAVEMAN else Tuning.ENERGY_START
		hero.run.bones = 0
		hero.run.emit_energy()
		_picked_seen[slot] = hero.run.picked
		hero.set_control_enabled(false)
		_emit_stack(slot)


## Skip the intro: the round starts now (tests, a rematch without countdown).
func start_round_now() -> void:
	if phase == PHASE_INTRO:
		_start_play()


## End the round now (the gong): the winners are decided by the mode's score (a tie in Grub Stack drops the Golden
## Drumstick instead unless `allow_golden` is false).
func end_round(allow_golden: bool = true) -> void:
	if phase == PHASE_OVER:
		return
	var best: PackedInt32Array = _best_slots()
	if best.size() > 1 and allow_golden and mode == Defs.VersusMode.GRUB_STACK and _team_count(best) > 1:
		_start_golden()
		return
	_finish(best)


func _start_play() -> void:
	phase = PHASE_PLAY
	for hero: PlayerBase in _heroes():
		hero.set_control_enabled(true)
		_shield_left[hero.slot] = VersusTuning.SPAWN_SHIELD_TICKS
		hero.shield = VersusTuning.SPAWN_SHIELD_TICKS
	_sfx(Sfx.COUNTDOWN_GO)
	Events.round_countdown.emit(round_index, 0)
	Events.round_started.emit(round_index)


func _start_golden() -> void:
	phase = PHASE_GOLDEN
	var view: Rect2i = VersusArena.view_rect()
	var pos: Vector2i = Vector2i(view.get_center().x, Tuning.TILE * 2)
	if level != null and Spawner.exists(GOLDEN_ID):
		_golden = level.spawn(GOLDEN_ID, pos, {"index": GOLDEN_INDEX, "dropped": true, "xvel": 0, "yvel": 0}) \
				as CollectibleBase
		if _golden != null:
			_golden.life = 0
	if _golden == null:
		_finish(_best_slots())


func _finish(winners: PackedInt32Array) -> void:
	phase = PHASE_OVER
	winner_slots = _with_teammates(winners)
	for hero: PlayerBase in _heroes():
		hero.set_control_enabled(false)
	# A match round: Flow records it (VersusMatch.record_round) and emits Events.round_ended once; without a match
	# (tests, a free round) the referee emits it itself.
	var versus_match: Object = _versus_match()
	if versus_match != null and bool(versus_match.get(&"round_open")) and Flow.has_method(&"end_round"):
		Flow.call(&"end_round", winner_slots)
	else:
		Events.round_ended.emit(round_index, winner_slots)


func _round_length() -> int:
	var versus_match: Object = _versus_match()
	if versus_match != null and versus_match.has_method(&"round_ticks"):
		return int(versus_match.call(&"round_ticks", mode))
	var players: int = level.hero_count() if level != null else 2
	match mode:
		Defs.VersusMode.GRUB_STACK:
			var seconds: int = int(level.meta.get("round_time", 90)) if level != null else 90
			if seconds == 90:
				return VersusTuning.stack_round_ticks(players)
			return Tuning.seconds_to_ticks(float(seconds))
		Defs.VersusMode.CLUBBALL:
			return VersusTuning.CLUBBALL_MATCH_TICKS
	return 0


## The round setup from Game.versus_match (core-A's VersusMatch: round_mode, round_index, spawn_index(slot), the
## seats' team / stack_guard / hearts, the Stock option; read duck-typed) when a match runs, else the arena's first
## mode, round 0, free for all, guard x1, 3 hearts, spawns rotated by the round.
func _read_setup() -> void:
	if level == null:
		return
	wrap = VersusArena.wrap_mode(level.meta)
	mode = VersusArena.default_mode(level.meta)
	knockouts_final = false
	var versus_match: Object = _versus_match()
	if versus_match == null:
		return
	var round_mode: Variant = versus_match.get(&"round_mode")
	if round_mode is int and int(round_mode) >= 0:
		mode = int(round_mode)
	var index: Variant = versus_match.get(&"round_index")
	if index is int:
		round_index = int(index)
	var team_match: bool = versus_match.has_method(&"is_team_match") and bool(versus_match.call(&"is_team_match"))
	for slot: int in Defs.MAX_PLAYERS:
		if versus_match.has_method(&"spawn_index"):
			spawn_of[slot] = int(versus_match.call(&"spawn_index", slot)) - 1
		var seat: Object = versus_match.call(&"get_seat", slot) as Object if versus_match.has_method(&"get_seat") \
				else null
		if seat == null:
			continue
		var team: Variant = seat.get(&"team")
		teams[slot] = int(team) if team_match and team is int and int(team) > 0 else -1
		var guard: Variant = seat.get(&"stack_guard")
		if guard is int:
			guard_percent[slot] = VersusTuning.STACK_GUARD_PERCENT[clampi(int(guard), 0,
					VersusTuning.STACK_GUARD_PERCENT.size() - 1)]
		var hearts: Variant = seat.get(&"hearts")
		if hearts is int and int(hearts) > 0:
			start_hearts[slot] = clampi(int(hearts), VersusTuning.HANDICAP_HEARTS_MIN, VersusTuning.HANDICAP_HEARTS_MAX)
	var stock: Variant = versus_match.get(&"stock")
	knockouts_final = mode == Defs.VersusMode.LAST_CAVEMAN and not (stock is bool and bool(stock))


## Game.versus_match while a match is set up (null otherwise or before core-A's member exists).
static func _versus_match() -> Object:
	return Game.get(&"versus_match") as Object


# =================================================================================================================
# Reading API
# =================================================================================================================

## Units on the head of `slot` (Grub Stack).
func stack_of(slot: int) -> int:
	return _stack[slot] if slot >= 0 and slot < Defs.MAX_PLAYERS else 0


## Units banked in the cookpot of `slot` (2v2: the team's shared pot).
func banked_of(slot: int) -> int:
	return _pot[_pot_index(slot)] if slot >= 0 and slot < Defs.MAX_PLAYERS else 0


## The round score of `slot`: Grub Stack banked + stack; Last Caveman Standing the hearts left (0 when out).
func score_of(slot: int) -> int:
	if slot < 0 or slot >= Defs.MAX_PLAYERS:
		return 0
	if mode == Defs.VersusMode.LAST_CAVEMAN:
		var hero: PlayerBase = level.get_hero(slot) if level != null else null
		return 0 if hero == null or _out[slot] != 0 else hero.run.hearts
	return _stack[slot] + banked_of(slot)


## The crowned slot: the tallest stack (Grub Stack: units on the head; ties and an empty arena: -1).
func leader_slot() -> int:
	var best: int = -1
	var best_value: int = 0
	var tie: bool = false
	for hero: PlayerBase in _heroes():
		var value: int = _stack[hero.slot]
		if value > best_value:
			best = hero.slot
			best_value = value
			tie = false
		elif value == best_value and value > 0:
			tie = true
	return -1 if tie else best


## Ticks left on the round clock (-1 = the mode has none).
func time_left_ticks() -> int:
	if round_total <= 0:
		return -1
	return maxi(round_total - round_ticks, 0)


## The round's whole length in ticks (0 = no clock) - the HUD's sundial (ui-B).
func round_length() -> int:
	return round_total


## Ticks until the gong of the running round; -1 = no clock running (no clock in this mode, the countdown, the
## Golden Drumstick, after the gong) - the HUD's sundial (ui-B).
func round_ticks_left() -> int:
	if phase != PHASE_PLAY:
		return -1
	return time_left_ticks()


## [method time_left_ticks] by the bots' name (core-B).
func ticks_left() -> int:
	return time_left_ticks()


## Rounds `slot` has won in the match so far (Game.versus_match.round_wins; 0 without a match).
func round_wins_of(slot: int) -> int:
	var versus_match: Object = _versus_match()
	if versus_match == null:
		return 0
	var wins: Variant = versus_match.get(&"round_wins")
	if wins is PackedInt32Array and slot >= 0 and slot < (wins as PackedInt32Array).size():
		return (wins as PackedInt32Array)[slot]
	return 0


## The team of `slot` (-1 = free for all).
func team_of(slot: int) -> int:
	return teams[slot] if slot >= 0 and slot < Defs.MAX_PLAYERS else -1


## Units `item` adds to a stack when picked up (core-B's bots): food by class, 0 = not food, -1 = harmful (the skull
## spills everything).
func food_value(item: CollectibleBase) -> int:
	if item == null:
		return 0
	if item.item_id == &"items/skull":
		return -1
	return food_units(item.item_id, item.points)


## Weight class of a stack (C.14): 0 light, 1 heavy (10+ units: walk cap 64), 2 heavier (20+: walk cap 48, jump
## impulses x3/4).
static func weight_class(stack: int) -> int:
	if stack >= VersusTuning.STACK_HEAVIER:
		return 2
	if stack >= VersusTuning.STACK_HEAVY:
		return 1
	return 0


func in_feast_rush() -> bool:
	return _feast_rush


## True while the cookpot lids are closed (the Feast Rush: no banking).
func lids_closed() -> bool:
	return _feast_rush


## True while `slot` banks: a unit banked within the last VersusTuning.COOKPOT_BANK_TICKS ticks, or crouched in an
## open cookpot (objects-B's Cookpot.slot_banking_anywhere(level, slot) when it exists). A stomp on him steals double.
func is_banking(slot: int) -> bool:
	if slot < 0 or slot >= Defs.MAX_PLAYERS:
		return false
	var hero: PlayerBase = level.get_hero(slot) if level != null else null
	if hero != null and hero.is_crouching() and _bank_tick[slot] >= 0 \
			and Sim.tick - _bank_tick[slot] <= VersusTuning.COOKPOT_BANK_TICKS:
		return true
	if _bank_seen[slot] >= 0 and Sim.tick - _bank_seen[slot] <= 1:
		return true  # reported crouching in a pot (bank_from) on this tick or the last
	if level != null and ResourceLoader.exists(COOKPOT_SCRIPT):
		var cookpot: Script = load(COOKPOT_SCRIPT) as Script
		if cookpot != null and cookpot.has_script_method(&"slot_banking_anywhere"):
			return bool(cookpot.call(&"slot_banking_anywhere", level, slot))
	return false


## The cookpot's call (objects-B): move up to `units` from the stack of `slot` into his pot (the team's in 2v2);
## the cookpot keeps the cadence (one unit per VersusTuning.COOKPOT_BANK_TICKS crouched ticks). Grub Stack round
## running, lids open, the hero alive, not stunned. Returns the units moved.
func bank_from_stack(slot: int, units: int) -> int:
	if slot < 0 or slot >= Defs.MAX_PLAYERS or units <= 0 or mode != Defs.VersusMode.GRUB_STACK or not _round_live() \
			or _feast_rush or level == null:
		return 0
	var hero: PlayerBase = level.get_hero(slot)
	if hero == null or hero.dead or hero.is_down() or _is_stunned(hero):
		return 0
	var moved: int = mini(units, _stack[slot])
	if moved <= 0:
		return 0
	_stack[slot] -= moved
	_pot[_pot_index(slot)] += moved
	_bank_tick[slot] = Sim.tick
	_emit_stack(slot)
	return moved


## Walking cap (v16) the weight of the stack gives `slot` (C.14 "Weight"; Tuning.WALK_CAP when light).
func walk_cap_of(slot: int) -> int:
	return _walk_cap[slot] if slot >= 0 and slot < Defs.MAX_PLAYERS else Tuning.WALK_CAP


## True when `slot` is out of the round (Last Caveman Standing).
func is_out(slot: int) -> bool:
	return slot >= 0 and slot < Defs.MAX_PLAYERS and _out[slot] != 0


## The cookpot (objects-B) reports a hero touching it on its CONTACT_ITEMS tick. Grub Stack, round running, lids
## open, the hero alive, crouching on the ground, not stunned, with something on his head: every
## VersusTuning.COOKPOT_BANK_TICKS consecutive ticks one unit moves from his stack into his pot. True on the tick a
## unit was banked.
func bank_from(hero: PlayerBase, _pot_entity: SimEntity = null) -> bool:
	if hero == null or mode != Defs.VersusMode.GRUB_STACK or not _round_live() or _feast_rush:
		return false
	var slot: int = hero.slot
	if hero.dead or hero.is_down() or not hero.is_crouching() or not hero.is_grounded() or _is_stunned(hero) \
			or _stack[slot] <= 0:
		_bank_count[slot] = 0
		return false
	if _bank_seen[slot] < Sim.tick - 1:
		_bank_count[slot] = 0
	if _bank_seen[slot] == Sim.tick:
		return false  # one report per tick (two pots touched at once)
	_bank_seen[slot] = Sim.tick
	_bank_count[slot] += 1
	if _bank_count[slot] < VersusTuning.COOKPOT_BANK_TICKS:
		return false
	_bank_count[slot] = 0
	if bank_from_stack(slot, 1) <= 0:
		return false
	_sfx(Sfx.COOKPOT_BANK)
	return true


## Put `units` of food on the head of `hero` (Grub Stack pick-ups; tests). Returns the units added.
func add_food(hero: PlayerBase, units: int) -> int:
	if hero == null or units <= 0 or mode != Defs.VersusMode.GRUB_STACK:
		return 0
	var slot: int = hero.slot
	_stack[slot] += units
	_stat(hero, &"food", units)
	hero.run.note_stack(_stack[slot])
	_emit_stack(slot)
	return units


## Units a food pick-up is worth on the stack (DESIGN.md E.3): small food 1, big food 2, treasure 5, giant bonus 10.
static func food_units(item_id: StringName, points: int) -> int:
	match item_id:
		&"items/food":
			return VersusTuning.FOOD_BIG if points >= BIG_FOOD_MIN_POINTS else VersusTuning.FOOD_SMALL
		&"items/treasure":
			return VersusTuning.FOOD_TREASURE
		&"items/giant_bonus", &"items/jackpot":
			return VersusTuning.FOOD_GIANT
	return 0


## LevelBase.hero_death_finished asks the party driver first: in an arena every death is the referee's (respawn or
## out, handled in POST), never a team wipe or a game over.
func handle_hero_death(_hero: PlayerBase) -> bool:
	return true


# =================================================================================================================
# Simulation
# =================================================================================================================

func _sim_tick(sim_phase: int) -> void:
	if level == null:
		return
	match sim_phase:
		Defs.Phase.WEAPONS:
			# The pick-up counters as the tick starts (food is collected later, in CONTACT_ITEMS).
			for hero: PlayerBase in _heroes():
				_picked_seen[hero.slot] = hero.run.picked
			if _round_live():
				_weapons_step()
		Defs.Phase.PLAYER:
			_player_step()
		Defs.Phase.CONTACT_ENEMIES:
			if _round_live():
				_stomp_step()
		Defs.Phase.WORLD:
			_round_step()
		Defs.Phase.POST:
			_post_step()


func _round_live() -> bool:
	return phase == PHASE_PLAY or phase == PHASE_GOLDEN


# --- WEAPONS: gather, then apply ------------------------------------------------------------------------------------

func _weapons_step() -> void:
	var heroes: Array[PlayerBase] = _heroes()
	# 1. The live club boxes of the previous tick.
	var boxes: Array[Dictionary] = []
	for hero: PlayerBase in heroes:
		if hero.club_box_active and _in_play(hero):
			boxes.append({
				"hero": hero, "box": hero.club_box, "xo": hero.club_box_xo, "front": _is_front(hero),
				"charged": _is_charged(hero), "frame": _frame_of(hero), "live": true,
			})
	# 2. Clang: two rivals' front boxes meeting (Overlap.rects: a non-original test). A charged box wins.
	for i: int in boxes.size():
		for j: int in range(i + 1, boxes.size()):
			var a: Dictionary = boxes[i]
			var b: Dictionary = boxes[j]
			if not a["front"] or not b["front"] or _teammates(a["hero"], b["hero"]):
				continue
			if not Overlap.rects(a["box"], b["box"]):
				continue
			var a_charged: bool = a["charged"]
			var b_charged: bool = b["charged"]
			if a_charged == b_charged:
				a["live"] = false
				b["live"] = false
				_clang(a["hero"], b["hero"])
			elif a_charged:
				b["live"] = false
			else:
				a["live"] = false
	var hits: Array[Dictionary] = []
	var hit_victims: Dictionary = {}
	# 3. Deflects, then hero hits, for every live box (one target per box).
	var projectiles: Array[SimEntity] = level.get_kind(Defs.Kind.HERO_PROJECTILE)
	for record: Dictionary in boxes:
		if not record["live"]:
			continue
		var attacker: PlayerBase = record["hero"]
		if record["front"] and _deflect(attacker, record["box"], record["xo"], projectiles):
			attacker.club_box_active = false
			continue
		for victim: PlayerBase in heroes:
			if victim == attacker or not _in_play(victim):
				continue
			if not Overlap.weapon(record["box"], record["xo"], victim):
				continue
			attacker.club_box_active = false
			hits.append({"attacker": attacker, "source": attacker, "victim": victim, "front": record["front"],
				"charged": record["charged"], "frame": record["frame"], "thrown": false,
				"weapon": attacker.run.weapon})
			break
	# 4. Hero projectiles against rival heroes.
	for i: int in projectiles.size():
		var projectile: ProjectileBase = projectiles[i] as ProjectileBase
		if projectile == null or projectile.spent or not projectile.from_hero:
			continue
		var thrower: PlayerBase = level.get_hero(projectile.owner_slot)
		for victim: PlayerBase in heroes:
			if victim.slot == projectile.owner_slot or not _in_play(victim):
				continue
			if thrower != null and _teammates(thrower, victim):
				continue
			if not Overlap.weapon_entity(projectile, victim):
				continue
			projectile.consume()
			hits.append({"attacker": thrower, "source": projectile, "victim": victim, "front": false,
				"charged": false, "frame": Tuning.ClubFrame.NONE, "thrown": true,
				"weapon": _projectile_weapon(projectile)})
			break
	# 5. Apply, against the state every hero had before any of them (a trade hits both).
	var immune_before: Dictionary = {}
	for hero: PlayerBase in heroes:
		immune_before[hero.slot] = _pvp_immune(hero)
	for hit: Dictionary in hits:
		var victim: PlayerBase = hit["victim"]
		if hit_victims.has(victim.slot):
			continue  # one hit per victim and tick (the first gathered)
		hit_victims[victim.slot] = true
		_resolve_hit(hit, bool(immune_before[victim.slot]))


## One gathered box or projectile on a rival hero: curled rules, teammate bump, immunity, then the hit.
func _resolve_hit(hit: Dictionary, victim_immune: bool) -> void:
	var victim: PlayerBase = hit["victim"]
	var attacker: PlayerBase = hit["attacker"]
	var thrown: bool = hit["thrown"]
	if victim.is_curled() and not thrown:
		if attacker != null and victim.sim_pos.y - attacker.sim_pos.y >= VersusTuning.CURL_GLANCE_ABOVE_PX:
			_sfx(SFX_CLANG)
			return  # a box from above glances off the curl
		if hit["front"] and victim.curl == PlayerBase.CURL_CURLED:
			_bat(victim, attacker, int(hit["frame"]), bool(hit["charged"]))
		return
	if attacker != null and _teammates(attacker, victim):
		victim.xvel = VersusTuning.TEAMMATE_BUMP_XVEL * _away(attacker, victim, hit["source"])
		return
	if victim_immune or victim.is_curled():
		return
	_apply_hit(attacker, hit["source"], victim, bool(hit["charged"]), int(hit["weapon"]), thrown)


## The C.14 hit: the contract call victim.hurt(source, RIVAL), then the referee's table (knock-back, hurt timer,
## hit-stop) and the mode's currency. The run's hearts / bones / glider are put back after the call.
func _apply_hit(attacker: PlayerBase, source: SimEntity, victim: PlayerBase, charged: bool, weapon: int,
		thrown: bool) -> void:
	var run: PlayerRun = victim.run
	var hearts: int = run.hearts
	var bones: int = run.bones
	# The 1.0 hurt path (when no party component takes the call) must never kill: the currency is ours.
	if run.hearts < 2:
		run.hearts = 2
	var applied: bool = victim.hurt(source if source != null else attacker, Defs.HurtKind.RIVAL)
	run.hearts = hearts
	run.bones = bones
	run.emit_energy()
	if not applied or victim.dead:
		return
	var away: int = _away(attacker, victim, source)
	var knock_x: int = VersusTuning.HIT_XVEL
	var knock_y: int = VersusTuning.HIT_YVEL
	if weapon == Defs.Weapon.HAMMER and not thrown:
		knock_x = VersusTuning.HIT_XVEL * VersusTuning.HAMMER_KNOCK_NUM / VersusTuning.HAMMER_KNOCK_DEN
	if charged:
		knock_x = VersusTuning.CHARGED_XVEL
		knock_y = VersusTuning.CHARGED_YVEL
		victim.ice = VersusTuning.CHARGED_SLIDE_ICE
	if thrown and weapon == Defs.Weapon.BOOMERANG:
		knock_y = VersusTuning.BOOMERANG_POP_YVEL
	victim.xvel = knock_x * away
	victim.yvel = knock_y
	victim.grounded = false
	victim.on_platform = false
	victim.attack_gate = false
	victim.hit_timer = VersusTuning.HURT_TIMER_TICKS
	_stomp_immune[victim.slot] = 0
	_squash_left[victim.slot] = 0
	_bank_count[victim.slot] = 0
	var stop: int = VersusTuning.HIT_STOP_BIG_TICKS if charged else VersusTuning.HIT_STOP_TICKS
	_set_stop(victim, stop)
	if attacker != null and not thrown:
		_set_stop(attacker, stop)
	if attacker != null:
		_last_hitter[victim.slot] = attacker.slot
		_last_hit_tick[victim.slot] = Sim.tick
		_stat(attacker, &"hits", 1)
	_stat(victim, &"hurts", 1)
	_sfx(Sfx.CLUB_HIT_HEAVY if charged or weapon == Defs.Weapon.HAMMER else Sfx.CLUB_HIT)
	# The mode's currency.
	match mode:
		Defs.VersusMode.GRUB_STACK:
			var divisor: int = VersusTuning.SPILL_HIT_DIV
			if charged:
				divisor = VersusTuning.SPILL_CHARGED_DIV
			elif thrown:
				divisor = VersusTuning.SPILL_THROWN_DIV
			spill(victim, VersusTuning.spill(_stack[victim.slot], divisor), true)
		Defs.VersusMode.LAST_CAVEMAN:
			_lose_hearts(victim, VersusTuning.LCS_CHARGED_HEARTS if charged else 1, attacker, &"hit")


func _set_stop(hero: PlayerBase, ticks: int) -> void:
	_stop_left[hero.slot] = maxi(_stop_left[hero.slot], ticks)
	hero.hit_stop = maxi(hero.hit_stop, ticks)


## Two front boxes met: both heroes are pushed CLANG_PUSH_EACH_PX away from each other (commit rule), clank.
func _clang(a: PlayerBase, b: PlayerBase) -> void:
	var dir: int = 1 if a.sim_pos.x > b.sim_pos.x else (-1 if a.sim_pos.x < b.sim_pos.x else (1 if a.slot > b.slot else -1))
	_commit_x(a, dir * VersusTuning.CLANG_PUSH_EACH_PX)
	_commit_x(b, -dir * VersusTuning.CLANG_PUSH_EACH_PX)
	_stat(a, &"clangs", 1)
	_stat(b, &"clangs", 1)
	_sfx(SFX_CLANG)
	_fx(&"fx/hit_stars", Vector2i((a.sim_pos.x + b.sim_pos.x) / 2, mini(a.sim_pos.y, b.sim_pos.y) - 16))


## A front box bats a rival's thrown special back: reversed plus DEFLECT_SPEEDUP in the new direction, now owned by
## the striker. True when one was deflected (the box is consumed).
func _deflect(attacker: PlayerBase, box: Rect2i, xo: int, projectiles: Array[SimEntity]) -> bool:
	for i: int in projectiles.size():
		var projectile: ProjectileBase = projectiles[i] as ProjectileBase
		if projectile == null or projectile.spent or not projectile.from_hero:
			continue
		if projectile.owner_slot == attacker.slot:
			continue
		var thrower: PlayerBase = level.get_hero(projectile.owner_slot)
		if thrower != null and _teammates(thrower, attacker):
			continue
		if not Overlap.weapon(box, xo, projectile):
			continue
		var direction: int = -1 if projectile.xvel > 0 else 1
		projectile.xvel = direction * (absi(projectile.xvel) + VersusTuning.DEFLECT_SPEEDUP)
		projectile.facing = direction
		projectile.owner_slot = attacker.slot
		_sfx(SFX_CLANG)
		return true
	return false


## A front box bats a curled hero as a ball (C.11): line drive, lob or grounder by the frame, x3/2 when charged.
func _bat(victim: PlayerBase, batter: PlayerBase, frame: int, charged: bool) -> void:
	var facing_dir: int = batter.facing if batter != null else 1
	var bx: int = PartyTuning.BAT_LINE_DRIVE_XVEL
	var by: int = PartyTuning.BAT_LINE_DRIVE_YVEL
	if frame == Tuning.ClubFrame.HIGH_FRONT:
		bx = PartyTuning.BAT_LOB_XVEL
		by = PartyTuning.BAT_LOB_YVEL
	elif frame == Tuning.ClubFrame.LOW_FRONT:
		bx = PartyTuning.BAT_GROUNDER_XVEL
		by = 0
	if charged:
		bx = PartyTuning.bat_charged(bx)
		by = PartyTuning.bat_charged(by)
	victim.bat(bx * facing_dir, by, batter)
	if batter != null:
		_stat(batter, &"bats", 1)
	_sfx(Sfx.BAT_HIT)


# --- PLAYER: after every hero moved ---------------------------------------------------------------------------------

func _player_step() -> void:
	var heroes: Array[PlayerBase] = _heroes()
	for hero: PlayerBase in heroes:
		if hero.dead:
			continue
		_wrap_hero(hero)
		var slot: int = hero.slot
		if hero.attack_gate:
			# A strike or a throw ends the immunity and the spawn shield at once (C.14).
			if hero.shield > 0 or _shield_left[slot] > 0:
				hero.shield = 0
				_shield_left[slot] = 0
			if hero.hit_timer > 0 and hero.hit_timer < VersusTuning.STUN_HIT_TIMER_MIN:
				hero.hit_timer = 0
			if _squash_left[slot] == 0:
				_stomp_immune[slot] = 0
		if hero.is_grounded():
			_chain[slot] = 0
		_apply_weight(hero)
	_wrap_projectiles()
	if _round_live():
		_body_bump(heroes)


## The lr / tb wrap of an arena (VersusArena.wrap_step, after every hero moved).
func _wrap_hero(hero: PlayerBase) -> void:
	VersusArena.wrap_step(level, hero, wrap)


## Thrown specials crossing a wrap edge wrap once and vanish VersusTuning.WRAP_SPECIAL_TICKS later.
func _wrap_projectiles() -> void:
	if wrap == VersusArena.WRAP_NONE:
		return
	var view: Rect2i = VersusArena.view_rect()
	var projectiles: Array[SimEntity] = level.get_kind(Defs.Kind.HERO_PROJECTILE)
	for i: int in projectiles.size():
		var projectile: ProjectileBase = projectiles[i] as ProjectileBase
		if projectile == null or projectile.spent:
			continue
		var id: int = projectile.get_instance_id()
		if _wrapped.has(id):
			continue
		var pos: Vector2i = projectile.sim_pos
		var moved: bool = false
		if wrap == VersusArena.WRAP_LR:
			if pos.x < view.position.x:
				pos.x += view.size.x
				moved = true
			elif pos.x >= view.end.x:
				pos.x -= view.size.x
				moved = true
		elif pos.y >= view.end.y:
			pos.y -= view.size.y
			moved = true
		elif pos.y < view.position.y:
			pos.y += view.size.y
			moved = true
		if moved:
			_wrapped[id] = true
			projectile.teleport(pos)
			projectile.on_screen = true
			var age: Variant = projectile.get(&"_age")
			projectile.life = (int(age) if age is int else 0) + VersusTuning.WRAP_SPECIAL_TICKS


## Body bump (C.14): overlapping rivals (body test, no stomp) move 1 px apart per tick; running into each other at
## 4+ px/tick knocks both back (+/-64, -64), no damage.
func _body_bump(heroes: Array[PlayerBase]) -> void:
	for i: int in heroes.size():
		for j: int in range(i + 1, heroes.size()):
			var a: PlayerBase = heroes[i]
			var b: PlayerBase = heroes[j]
			if not _in_play(a) or not _in_play(b) or a.is_curled() or b.is_curled() or _teammates(a, b):
				continue
			if not Overlap.body(a, b) or Overlap.stomp:
				continue
			var left: PlayerBase = a
			var right: PlayerBase = b
			if b.sim_pos.x < a.sim_pos.x or (b.sim_pos.x == a.sim_pos.x and b.slot < a.slot):
				left = b
				right = a
			if left.xvel >= VersusTuning.BODY_KNOCK_MIN_XVEL and -right.xvel >= VersusTuning.BODY_KNOCK_MIN_XVEL:
				left.xvel = -VersusTuning.BODY_KNOCK_XVEL
				right.xvel = VersusTuning.BODY_KNOCK_XVEL
				left.yvel = VersusTuning.BODY_KNOCK_YVEL
				right.yvel = VersusTuning.BODY_KNOCK_YVEL
				left.grounded = false
				right.grounded = false
				_sfx(Sfx.BOUNCE)
			else:
				_commit_x(left, -VersusTuning.BODY_BUMP_PX)
				_commit_x(right, VersusTuning.BODY_BUMP_PX)


## Grub Stack weight (C.14): the walk cap of the stack, written to the hero when he has the member (player-A).
func _apply_weight(hero: PlayerBase) -> void:
	var slot: int = hero.slot
	var cap: int = Tuning.WALK_CAP
	var heavy: bool = false
	if mode == Defs.VersusMode.GRUB_STACK:
		cap = VersusTuning.stack_walk_cap(_stack[slot])
		heavy = _stack[slot] >= VersusTuning.STACK_HEAVIER
	_walk_cap[slot] = cap
	if &"walk_cap_override" in hero:
		hero.set(&"walk_cap_override", 0 if cap == Tuning.WALK_CAP else cap)
	if &"jump_scale_3_4" in hero:
		hero.set(&"jump_scale_3_4", heavy)


# --- CONTACT_ENEMIES: stomps ------------------------------------------------------------------------------------------

func _stomp_step() -> void:
	var heroes: Array[PlayerBase] = _heroes()
	var stomps: Array[Dictionary] = []
	for stomper: PlayerBase in heroes:
		if not _in_play(stomper) or stomper.yvel < 0 or stomper.is_curled() or stomper.is_gliding():
			continue
		for victim: PlayerBase in heroes:
			if victim == stomper or not _in_play(victim):
				continue
			if Overlap.body(stomper, victim, stomper) and Overlap.stomp:
				stomps.append({"stomper": stomper, "victim": victim, "depth": Overlap.depth})
				break
	var immune_before: Dictionary = {}
	for hero: PlayerBase in heroes:
		immune_before[hero.slot] = _pvp_immune(hero)
	for stomp: Dictionary in stomps:
		var stomper: PlayerBase = stomp["stomper"]
		var victim: PlayerBase = stomp["victim"]
		var up: bool = (GameInput.get_flags(stomper.slot) & Defs.IN_UP) != 0 and stomper.control_enabled \
				and _squash_left[stomper.slot] == 0
		stomper.bounce(Tuning.BOUNCE_YVEL_UP if up else Tuning.BOUNCE_YVEL, int(stomp["depth"]))
		_sfx(Sfx.BOUNCE)
		if _teammates(stomper, victim) or bool(immune_before[victim.slot]) or victim.is_curled():
			continue  # a free springboard
		_chain[stomper.slot] += 1
		stomper.run.note_chain(_chain[stomper.slot])
		_squash_left[victim.slot] = VersusTuning.STOMP_SQUASH_TICKS
		victim.squash = VersusTuning.STOMP_SQUASH_TICKS
		_stomp_immune[victim.slot] = VersusTuning.STOMP_SQUASH_TICKS + VersusTuning.STOMP_IMMUNE_TICKS
		_last_hitter[victim.slot] = stomper.slot
		_last_hit_tick[victim.slot] = Sim.tick
		match mode:
			Defs.VersusMode.GRUB_STACK:
				var steal: int = mini(VersusTuning.stomp_steal(_chain[stomper.slot], is_banking(victim.slot)),
						_stack[victim.slot])
				if steal > 0:
					_stack[victim.slot] -= steal
					_stack[stomper.slot] += steal
					_stat(stomper, &"stolen", steal)
					_stat(victim, &"dropped", steal)
					stomper.run.note_stack(_stack[stomper.slot])
					_emit_stack(victim.slot)
					_emit_stack(stomper.slot)
			Defs.VersusMode.LAST_CAVEMAN:
				_lose_hearts(victim, 1, stomper, &"stomp")


# --- WORLD: the round -------------------------------------------------------------------------------------------------

func _round_step() -> void:
	match phase:
		PHASE_INTRO:
			var steps: int = VersusTuning.COUNTDOWN_STEPS
			if _intro_ticks % INTRO_COUNT_TICKS == 0 and _intro_ticks < steps * INTRO_COUNT_TICKS:
				Events.round_countdown.emit(round_index, steps - _intro_ticks / INTRO_COUNT_TICKS)
				_sfx(Sfx.COUNTDOWN_BEEP)
			_intro_ticks += 1
			if _intro_ticks >= steps * INTRO_COUNT_TICKS:
				_start_play()
		PHASE_PLAY:
			round_ticks += 1
			if mode == Defs.VersusMode.GRUB_STACK:
				_refill_spots()
			if mode == Defs.VersusMode.GRUB_STACK and round_total > 0 and not _feast_rush \
					and round_ticks >= round_total - VersusTuning.FEAST_RUSH_TICKS:
				_start_feast_rush()
			if round_total > 0 and round_ticks >= round_total:
				end_round()
			elif mode == Defs.VersusMode.LAST_CAVEMAN:
				var standing: PackedInt32Array = _standing_slots()
				if _team_count(standing) <= 1 and level.hero_count() > 1:
					_finish(standing)
		PHASE_GOLDEN:
			round_ticks += 1
			if _golden == null or not is_instance_valid(_golden):
				_finish(_best_slots())


## The Feast Rush (DESIGN.md E.3): the bell, every spot refills at once, a second giant bonus drops in the middle,
## the pot lids close.
func _start_feast_rush() -> void:
	_feast_rush = true
	var spots: Array[SimEntity] = level.get_kind(Defs.Kind.HITTABLE)
	for i: int in spots.size():
		var spot: SimEntity = spots[i]
		if spot != null and spot.has_method(&"refill"):
			spot.call(&"refill")
		_spot_empty_since.erase(spot.get_instance_id() if spot != null else 0)
	if Spawner.exists(&"items/giant_bonus"):
		var view: Rect2i = VersusArena.view_rect()
		level.spawn(&"items/giant_bonus", Vector2i(view.get_center().x, Tuning.TILE * 2),
				{"index": SPILL_GIANT_INDEX, "dropped": true, "xvel": 0, "yvel": 0})
	Events.round_feast_rush_started.emit(round_index)


## Grub Stack's visible spots refill VersusTuning.SPOT_REFILL_TICKS after they are emptied (DESIGN.md E.3): the referee
## keeps the clock and calls the spot's `refill()` (objects; a spot without it stays empty).
func _refill_spots() -> void:
	var spots: Array[SimEntity] = level.get_kind(Defs.Kind.HITTABLE)
	for i: int in spots.size():
		var spot: HittableBase = spots[i] as HittableBase
		if spot == null or not spot.has_method(&"refill"):
			continue
		var id: int = spot.get_instance_id()
		if not spot.opened:
			_spot_empty_since.erase(id)
		elif not _spot_empty_since.has(id):
			_spot_empty_since[id] = round_ticks
		elif round_ticks - int(_spot_empty_since[id]) >= VersusTuning.SPOT_REFILL_TICKS:
			_spot_empty_since.erase(id)
			spot.call(&"refill")


# --- POST: knock-outs, respawns, counters -----------------------------------------------------------------------------

func _post_step() -> void:
	for hero: PlayerBase in _heroes():
		var slot: int = hero.slot
		if hero.dead:
			if _dead_tick[slot] < 0:
				_dead_tick[slot] = Sim.tick
				_knocked_out(hero)
			elif not knockouts_final and _out[slot] == 0 and _round_live() \
					and Sim.tick - _dead_tick[slot] >= VersusTuning.RESPAWN_TICKS:
				_respawn(hero)
			continue
		_dead_tick[slot] = -1
		_count_down(hero)


## The referee's own counters, written to the hero every tick (whatever the hero side counts, the referee's value
## is the one that stands at the end of the tick): spawn shield, squash, hit-stop, stomp immunity.
func _count_down(hero: PlayerBase) -> void:
	var slot: int = hero.slot
	if _shield_left[slot] > 0:
		_shield_left[slot] -= 1
		hero.shield = _shield_left[slot]
	if _squash_left[slot] > 0:
		_squash_left[slot] -= 1
		hero.squash = _squash_left[slot]
	if _stop_left[slot] > 0:
		_stop_left[slot] -= 1
		hero.hit_stop = _stop_left[slot]
	if _stomp_immune[slot] > 0:
		_stomp_immune[slot] -= 1


## A hero died (a hazard, or a hit at 0 hearts): the knock-out credit, the currency, temporary specials lost.
func _knocked_out(hero: PlayerBase) -> void:
	var slot: int = hero.slot
	var killer: PlayerBase = null
	if _last_hitter[slot] >= 0 and Sim.tick - _last_hit_tick[slot] <= VersusTuning.KO_CREDIT_TICKS:
		killer = level.get_hero(_last_hitter[slot])
	if killer != null:
		_stat(killer, &"kills", 1)
	var cause: StringName = _death_cause[slot] if _death_cause[slot] != &"" else &"hazard"
	_stat(hero, &"deaths", 1)
	if cause != &"enemy" and cause != &"hit" and cause != &"stomp":
		_stat(hero, &"hazards", 1)
	match mode:
		Defs.VersusMode.GRUB_STACK:
			var all: int = _stack[slot]
			if all > 0:
				var burst: int = all / VersusTuning.HAZARD_BURST_DIV
				_stack[slot] = 0
				_stat(hero, &"dropped", all)
				_spawn_food(_death_pos[slot], burst)
				_emit_stack(slot)
		Defs.VersusMode.LAST_CAVEMAN:
			if knockouts_final or hero.run.hearts <= 0:
				_out[slot] = 1
	if hero.run.special() != Defs.Weapon.CLUB:
		hero.run.take_fresh_club()
	_throws_left[slot] = 0
	Events.hero_ko.emit(hero, killer, cause)


## Back after VersusTuning.RESPAWN_TICKS at the free spawn point farthest from the rivals, shielded.
func _respawn(hero: PlayerBase) -> void:
	var slot: int = hero.slot
	var best: Vector2i = hero.sim_pos
	var best_distance: int = -1
	for point: Vector2i in VersusArena.spawn_points(level):
		var nearest: int = 1 << 30
		var free: bool = true
		for other: PlayerBase in _heroes():
			if other == hero or other.dead:
				continue
			var distance: int = absi(other.sim_pos.x - point.x) + absi(other.sim_pos.y - point.y)
			nearest = mini(nearest, distance)
			if distance < PartyTuning.RESPAWN_SPREAD_PX:
				free = false
		if free and nearest > best_distance:
			best = point
			best_distance = nearest
	level.respawn_hero(hero, best)
	hero.facing = 1 if best.x < VersusArena.view_rect().get_center().x else -1
	hero.run.hearts = Tuning.ENERGY_START if mode != Defs.VersusMode.LAST_CAVEMAN else maxi(hero.run.hearts, 1)
	hero.run.emit_energy()
	_dead_tick[slot] = -1
	_death_cause[slot] = &""
	_shield_left[slot] = VersusTuning.SPAWN_SHIELD_TICKS
	hero.shield = VersusTuning.SPAWN_SHIELD_TICKS
	_chain[slot] = 0
	if phase == PHASE_OVER:
		hero.set_control_enabled(false)


# =================================================================================================================
# Grub Stack: spills and food
# =================================================================================================================

## Knock `units` off the head of `hero` (the stack guard of his handicap applied: x0.5 / x1 / x1.5, rounded down, at
## least 1), never more than he has. `burst` = they fly out as dropped food (else they are lost). Returns the units
## that left the stack.
func spill(hero: PlayerBase, units: int, burst: bool = true) -> int:
	if hero == null or units <= 0:
		return 0
	var slot: int = hero.slot
	var guarded: int = maxi(units * guard_percent[slot] / 100, 1)
	var taken: int = mini(guarded, _stack[slot])
	if taken <= 0:
		return 0
	_stack[slot] -= taken
	_stat(hero, &"dropped", taken)
	if burst:
		_spawn_food(Vector2i(hero.sim_pos.x, hero.sim_pos.y - hero.box_h), taken)
	_emit_stack(slot)
	return taken


## Spilled units fly out as dropped items split greedily into 10s, 5s and 1s (R22), with the fan of a burst.
func _spawn_food(at: Vector2i, units: int) -> void:
	if level == null or units <= 0:
		return
	var view: Rect2i = VersusArena.view_rect()
	var pos: Vector2i = Vector2i(clampi(at.x, view.position.x + Tuning.TILE, view.end.x - Tuning.TILE),
			clampi(at.y, view.position.y + Tuning.TILE * 2, view.end.y - Tuning.TILE))
	var left: int = units
	var n: int = 0
	while left > 0:
		var id: StringName = &"items/food"
		var index: int = SPILL_FOOD_INDEX
		if left >= VersusTuning.FOOD_GIANT:
			id = &"items/giant_bonus"
			index = SPILL_GIANT_INDEX
			left -= VersusTuning.FOOD_GIANT
		elif left >= VersusTuning.FOOD_TREASURE:
			id = &"items/treasure"
			index = SPILL_TREASURE_INDEX
			left -= VersusTuning.FOOD_TREASURE
		else:
			left -= VersusTuning.FOOD_SMALL
		if Spawner.exists(id):
			var velocity: Vector2i = ObjTuning.fan_velocity(n, ObjTuning.BURST_XVEL, ObjTuning.BURST_YVEL)
			level.spawn(id, pos, {"index": index, "dropped": true, "xvel": velocity.x, "yvel": velocity.y})
		n += 1


func _on_item_collected(item_id: StringName, index: int, points: int, pos: Vector2i) -> void:
	if level == null or not is_inside_tree():
		return
	var collector: PlayerBase = null
	for hero: PlayerBase in _heroes():
		if hero.run.picked - _picked_seen[hero.slot] >= 1:
			_picked_seen[hero.slot] += 1
			collector = hero
			break
	if collector == null or not _round_live():
		return
	if _golden != null and is_instance_valid(_golden) and _golden.collected:
		_golden = null
		_finish(PackedInt32Array([collector.slot]))
		return
	if mode == Defs.VersusMode.GRUB_STACK and item_id == &"items/skull":
		# Whoever picks up the skull spills everything (all of it bursts out).
		spill(collector, _stack[collector.slot], true)
		return
	if mode == Defs.VersusMode.GRUB_STACK and item_id == &"items/grenade":
		# Every rival spills VersusTuning.GRENADE_SPILL (or all he has).
		for rival: PlayerBase in _heroes():
			if rival != collector and not _teammates(rival, collector) and _in_play(rival):
				spill(rival, mini(VersusTuning.GRENADE_SPILL, _stack[rival.slot]), true)
		return
	var units: int = food_units(item_id, points)
	if units <= 0 or mode != Defs.VersusMode.GRUB_STACK:
		return
	if _is_stunned(collector):
		# A stunned hero cannot pick anything up (E.3): the piece lies where it was.
		if Spawner.exists(item_id):
			level.spawn(item_id, pos, {"index": index, "dropped": true, "xvel": 0, "yvel": 0})
		return
	add_food(collector, units)


func _on_hero_died(hero: PlayerBase, cause: StringName) -> void:
	if hero == null or level == null or hero.slot < 0 or hero.slot >= Defs.MAX_PLAYERS:
		return
	_death_cause[hero.slot] = cause
	_death_pos[hero.slot] = hero.sim_pos


# --- Last Caveman Standing (hearts) -----------------------------------------------------------------------------------

func _lose_hearts(victim: PlayerBase, count: int, attacker: PlayerBase, cause: StringName) -> void:
	var run: PlayerRun = victim.run
	var lost: int = mini(count, run.hearts)
	run.hearts -= lost
	run.emit_energy()
	if lost > 0 and Spawner.exists(&"items/bone"):
		for n: int in lost * VersusTuning.LCS_HEART_BONES:
			var velocity: Vector2i = ObjTuning.fan_velocity(n, ObjTuning.BURST_XVEL, ObjTuning.BURST_YVEL)
			level.spawn(&"items/bone", Vector2i(victim.sim_pos.x, victim.sim_pos.y - victim.box_h),
					{"dropped": true, "xvel": velocity.x, "yvel": velocity.y})
	if run.hearts <= 0:
		_death_cause[victim.slot] = cause
		_death_pos[victim.slot] = victim.sim_pos
		if attacker != null:
			_last_hitter[victim.slot] = attacker.slot
			_last_hit_tick[victim.slot] = Sim.tick
		victim.kill(&"enemy")


func _standing_slots() -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for hero: PlayerBase in _heroes():
		if _out[hero.slot] == 0 and not hero.dead:
			result.append(hero.slot)
	return result


# =================================================================================================================
# Helpers
# =================================================================================================================

## The heroes in slot order (no allocation-free promise: a small array per call).
func _heroes() -> Array[PlayerBase]:
	var result: Array[PlayerBase] = []
	if level == null:
		return result
	for hero: PlayerBase in level.heroes:
		if hero != null and is_instance_valid(hero):
			result.append(hero)
	return result


## In play: alive, hatched, not out of the round.
func _in_play(hero: PlayerBase) -> bool:
	return hero != null and not hero.dead and not hero.is_down() and _out[hero.slot] == 0


## Immune to PvP: the spawn shield, the hurt immunity, the stomp immunity, the versus feast.
func _pvp_immune(hero: PlayerBase) -> bool:
	return hero.shield > 0 or _shield_left[hero.slot] > 0 or hero.hit_timer > 0 or _stomp_immune[hero.slot] > 0 \
			or hero.feast > 0


func _is_stunned(hero: PlayerBase) -> bool:
	return hero.hit_timer >= VersusTuning.STUN_HIT_TIMER_MIN


func _teammates(a: PlayerBase, b: PlayerBase) -> bool:
	if a == null or b == null or a == b:
		return false
	var team: int = teams[a.slot]
	return team >= 0 and team == teams[b.slot]


func _pot_index(slot: int) -> int:
	var team: int = teams[slot]
	if team < 0:
		return slot
	for other: int in Defs.MAX_PLAYERS:
		if teams[other] == team:
			return other
	return slot


## +1 / -1: the direction from the attacker (or the projectile's flight) to the victim.
func _away(attacker: PlayerBase, victim: PlayerBase, source: SimEntity) -> int:
	if source is ProjectileBase:
		return 1 if source.xvel > 0 else (-1 if source.xvel < 0 else source.facing)
	if attacker == null:
		return 1
	if victim.sim_pos.x > attacker.sim_pos.x:
		return 1
	if victim.sim_pos.x < attacker.sim_pos.x:
		return -1
	return attacker.facing


## The club frame of the hero's box (Player.club_frame; a bare PlayerBase counts as the forward front frame).
func _frame_of(hero: PlayerBase) -> int:
	var frame: Variant = hero.get(&"club_frame")
	return int(frame) if frame is int else Tuning.ClubFrame.FWD_FRONT


## A front frame (forward front, high front-high, low front-low, PHYSICS.md 8.2): clangs, deflects, bats.
func _is_front(hero: PlayerBase) -> bool:
	var frame: int = _frame_of(hero)
	return frame == Tuning.ClubFrame.FWD_FRONT or frame == Tuning.ClubFrame.HIGH_FRONT \
			or frame == Tuning.ClubFrame.LOW_FRONT


## A charged box: made while charge > 0, power x4 (PHYSICS.md 8.5).
func _is_charged(hero: PlayerBase) -> bool:
	var weapon: int = clampi(hero.run.weapon, 0, Tuning.WEAPON_POWER.size() - 1)
	return hero.club_power > Tuning.WEAPON_POWER[weapon]


## The weapon a hero projectile is (the swirling axe pops its victim up).
func _projectile_weapon(projectile: ProjectileBase) -> int:
	if projectile.scene_file_path.contains("boomerang") or projectile.yacc == Tuning.BOOMERANG_YACC:
		return Defs.Weapon.BOOMERANG
	if projectile.scene_file_path.contains("spear"):
		return Defs.Weapon.SPEAR
	return Defs.Weapon.AXE


## Move a hero by `dx` px under the commit rule (level bounds) and not into a wall.
func _commit_x(hero: PlayerBase, dx: int) -> void:
	var next_x: int = hero.sim_pos.x + dx
	if next_x < Tuning.X_MIN or next_x >= level.grid.x_max_excl():
		return
	var probe: int = next_x + (Tuning.WALL_PROBE if dx > 0 else -Tuning.WALL_PROBE)
	if level.grid.side_at(Tuning.to_cell(probe), Tuning.to_cell(hero.sim_pos.y) - 1) == TileGrid.SIDE_WALL:
		return
	hero.sim_pos.x = next_x


## The slots with the best round score (several on a tie; empty when no hero).
func _best_slots() -> PackedInt32Array:
	var best: PackedInt32Array = PackedInt32Array()
	var best_score: int = -1
	var team_scores: Dictionary = {}
	for hero: PlayerBase in _heroes():
		var key: int = teams[hero.slot] + 100 if teams[hero.slot] >= 0 else hero.slot
		if teams[hero.slot] >= 0:
			# 2v2: separate stacks, one pot.
			team_scores[key] = int(team_scores.get(key, banked_of(hero.slot))) + _stack[hero.slot] \
					if mode == Defs.VersusMode.GRUB_STACK else int(team_scores.get(key, 0)) + score_of(hero.slot)
		else:
			team_scores[key] = score_of(hero.slot)
	for hero: PlayerBase in _heroes():
		var key: int = teams[hero.slot] + 100 if teams[hero.slot] >= 0 else hero.slot
		var value: int = int(team_scores[key])
		if value > best_score:
			best_score = value
			best = PackedInt32Array([hero.slot])
		elif value == best_score:
			best.append(hero.slot)
	return best


## Number of different sides (teams or free-for-all players) among `slots`.
func _team_count(slots: PackedInt32Array) -> int:
	var seen: Dictionary = {}
	for slot: int in slots:
		seen[teams[slot] + 100 if teams[slot] >= 0 else slot] = true
	return seen.size()


func _with_teammates(slots: PackedInt32Array) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for hero: PlayerBase in _heroes():
		var slot: int = hero.slot
		var wins: bool = slots.has(slot)
		if not wins and teams[slot] >= 0:
			for other: int in slots:
				wins = wins or teams[other] == teams[slot]
		if wins:
			result.append(slot)
	return result


func _emit_stack(slot: int) -> void:
	stack_changed.emit(slot, _stack[slot], banked_of(slot))


## Add to a statistic counter of the hero's run (PlayerRun.STATS: the versus awards of DESIGN.md E.8; nothing in the
## simulation reads them). Unknown names are skipped.
func _stat(hero: PlayerBase, stat: StringName, amount: int) -> void:
	if hero == null or amount == 0:
		return
	var run: PlayerRun = hero.run
	if stat in run:
		run.set(stat, int(run.get(stat)) + amount)


func _sfx(event: StringName) -> void:
	if event == SFX_CLANG and not AudioTable.SFX.has(SFX_CLANG):
		event = Sfx.IMPACT
	if AudioTable.SFX.has(event):
		Audio.play_sfx(event)


func _fx(id: StringName, pos: Vector2i) -> void:
	if level != null and Spawner.exists(id):
		level.spawn_fx(id, pos)


## The tower of food pictures over every head and the leader's crown (presentation only).
func _add_display() -> void:
	if level == null or _display != null or DisplayServer.get_name() == "headless":
		return
	_display = VersusStackDisplay.new()
	_display.name = "VersusStackDisplay"
	_display.set(&"referee", self)
	level.add_child(_display)


func _exit_display() -> void:
	if _display != null and is_instance_valid(_display):
		_display.queue_free()
	_display = null

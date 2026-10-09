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
##    tick, an 8-tick squash, 30 immune ticks; an immune, shielded, curled or teammate head is a free springboard),
##    then the head bounces off the arena's neutral enemies (VersusSignatures.springboard_step).
##  - WORLD: the round: intro countdown, clock, Feast Rush, gong, the Golden Drumstick on a tie.
##  - POST: hazards (knock-outs: credit to the last hitter within 73 ticks), respawns after 48 ticks at the free spawn
##    farthest from the rivals with a 48-tick spawn shield, the referee's own counters (spawn shield, squash, hit-stop,
##    stomp immunity) written to the heroes.
## The mode's currency: Grub Stack (the stack on the head, banking in the cookpot, spills and steals) and Last
## Caveman Standing (hearts, bones, Stock, Grudge Pterodactyls [VersusGrudge]); Hot Rock ([VersusHotRock]: the ember)
## and Clubball ([VersusClubball]: shots, goals) - their hits only knock back.
## PLAN.md P2.4 (phase 2): the themed sudden deaths ([VersusSuddenDeath], at 1 457 ticks in Last Caveman Standing,
## an event toggle elsewhere; ruling R8, DESIGN.md G78: a Last Caveman Standing round has a HARD CAP,
## VersusTuning.SUDDEN_DEATH_CAP_TICKS after its sudden death started - [member cap_at], [method cap_winners]: no
## round lasts for ever between players who hide from the arena's threats), pterodactyl crates ([VersusCrates]),
## temporary specials (throws counted, lost on a
## knock-out or at the round end), the versus feast (per hero cutlery; a feaster's touch costs a rival), presets,
## variants and the Auto handicap ([VersusRules]), dazes (a Grudge rock, a giant bonus bonk, a Clubball knock-down:
## 12 stunned ticks and no immunity after).
##
## The hero side of a hit is the contract call `victim.hurt(source, Defs.HurtKind.RIVAL)` (the hero's party
## component, player-A); right after it the referee writes the C.14 values itself and puts the run's hearts, bones
## back (the currency is the referee's), so the result is the same whatever the hero component does with the call.
##
## Public reading API (HUD, cookpot, bots, tests): [method find], [member mode], [member phase], [member round_index],
## [method stack_of], [method banked_of], [method score_of], [method leader_slot], [method time_left_ticks],
## [method in_feast_rush], [method lids_closed], [method bank_from] / [method bank_from_stack], [method is_banking],
## [method walk_cap_of], [method round_length], [method round_ticks_left], [method round_wins_of], [method team_of],
## [method food_value], [method weight_class], [method hurts_of], [method cap_ticks_left], [method cap_winners],
## [method ended_by_cap], signal [signal stack_changed]; round control: [method begin_round],
## [method start_round_now], [method end_round].

## A hero's stack, bank or both changed (HUD, stack display).
signal stack_changed(slot: int, stack: int, banked: int)
## Hot Rock: the ember went to `slot` (-1 = it popped / nobody holds it).
signal ember_changed(slot: int)
## Clubball: `team` (1 / 2) scored; the score after it.
signal goal_scored(team: int, goals_team_1: int, goals_team_2: int)

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
## Node group of everything a round spawns (hazards, crates, Grudge Pterodactyls): freed when the next round begins.
const ROUND_GROUP: StringName = &"versus_round"

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
## The round's rules (presets, variants, crates, Stock, Auto handicap); tests may change them before begin_round.
var rules: VersusRules = VersusRules.new()
## The mode modules (PLAN.md P2.4).
var hot_rock: VersusHotRock = null
var clubball: VersusClubball = null
var sudden_death: VersusSuddenDeath = null
## The arena signatures (phase 3: ring-outs, the darkness pulse, regrowing walls, neutral enemies, the ember lane, the
## neutral Colossus, the round-synced arena wind; [VersusSignatures]).
var signatures: VersusSignatures = null
## The Gusty variant's wind now (the arena wind gives way to it).
var gust_wind: int = 0
## Round tick at which the themed sudden death starts (-1 = never this round).
var sudden_death_at: int = -1
## Round tick of the hard cap (ruling R8, DESIGN.md G78; -1 = none armed): Last Caveman Standing,
## VersusTuning.SUDDEN_DEATH_CAP_TICKS after its sudden death started. On that tick the round ends whoever still stands
## ([method cap_winners]).
var cap_at: int = -1
## True once the hard cap ended this round ([method ended_by_cap]).
var _capped: bool = false

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
## 1 when the hero had no ground, platform or carrier under his feet as the tick began (the end of the previous tick):
## only such a hero lands a stomp (PHYSICS.md C.14 "a stomp is a landing", G15).
var _airborne: PackedByteArray = PackedByteArray([0, 0, 0, 0])
## Ticks of daze left (12 stunned ticks, then hit_timer 0: no immunity after).
var _daze_left: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
## Last Caveman Standing, option Stock: lives left.
var _stocks: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
## Last Caveman Standing: hurts taken this round - one per heart lost (a charged hit is two), whoever or whatever
## took it; bones that heal a heart do not take a hurt back. The hard cap's measure ([method cap_winners]).
var _hurts_taken: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
## The Auto handicap's leaf shield (absorbs one hit).
var _leaf: PackedByteArray = PackedByteArray([0, 0, 0, 0])
## The versus feast: cutlery pieces each hero holds (bit mask) and the referee's feast clock.
var _cutlery: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var _feast_left: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
## Round tick at which an out hero's Grudge Pterodactyl takes off (-1 = none pending).
var _grudge_at: PackedInt32Array = PackedInt32Array([-1, -1, -1, -1])
## Entities the referee spawned this round (grudges, hazards, crates): freed at the next round.
var _spawned: Array[Node] = []
## Hero projectiles already counted for the temporary specials (instance id -> true).
var _thrown_seen: Dictionary = {}
## Giant bonuses that bonked a head already (instance id -> true).
var _bonked: Dictionary = {}
var _gust_sign: int = 1

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
	hot_rock = VersusHotRock.new(self)
	clubball = VersusClubball.new(self)
	signatures = VersusSignatures.new(self)


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
	if sudden_death != null:
		sudden_death.stop()
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
		_daze_left[slot] = 0
		_stocks[slot] = VersusTuning.LCS_STOCKS if mode == Defs.VersusMode.LAST_CAVEMAN and rules.stock else 0
		_hurts_taken[slot] = 0
		_leaf[slot] = rules.leaf_shield[slot] if slot < rules.leaf_shield.size() else 0
		_cutlery[slot] = 0
		_feast_left[slot] = 0
		_grudge_at[slot] = -1
	knockouts_final = (mode == Defs.VersusMode.LAST_CAVEMAN and not rules.stock) or mode == Defs.VersusMode.HOT_ROCK
	_clear_spawned()
	_thrown_seen.clear()
	_bonked.clear()
	_gust_sign = 1
	gust_wind = 0
	hot_rock.reset()
	if level == null:
		return
	if sudden_death != null:
		sudden_death.stop()
	sudden_death = VersusSuddenDeath.new(self, level)
	sudden_death_at = _sudden_death_start()
	cap_at = -1
	_capped = false
	level.set_wind(0)
	level.set_darkness(rules.has(VersusRules.LIGHTS_OUT))
	var spawns: Array[Vector2i] = VersusArena.spawn_points(level)
	if mode == Defs.VersusMode.CLUBBALL:
		clubball.set_round(round_index)
	var sides: Dictionary = _clubball_spawns(spawns) if mode == Defs.VersusMode.CLUBBALL else {}
	for hero: PlayerBase in _heroes():
		var slot: int = hero.slot
		var spawn: int = spawn_of[slot] if spawn_of[slot] >= 0 else slot + round_index
		var pos: Vector2i = spawns[posmod(spawn, spawns.size())] if not spawns.is_empty() else hero.sim_pos
		if sides.has(slot):
			pos = sides[slot]
		level.respawn_hero(hero, pos)
		hero.facing = 1 if pos.x < VersusArena.view_rect().get_center().x else -1
		hero.run.hearts = start_hearts[slot] if mode == Defs.VersusMode.LAST_CAVEMAN else Tuning.ENERGY_START
		hero.run.bones = 0
		hero.run.emit_energy()
		_picked_seen[slot] = hero.run.picked
		hero.set_control_enabled(false)
		hero.feast = 0
		_arm_round_weapons(hero)
		_emit_stack(slot)
	if mode == Defs.VersusMode.CLUBBALL:
		clubball.reset()
	signatures.begin_round()
	signatures.wind_step()


## Everyone starts every round with the club in the hand and an empty belt (DESIGN.md E.2); Hammer Time puts the
## hammer in the hand and the club on the belt, Spear Party a spear on the belt that never runs out.
func _arm_round_weapons(hero: PlayerBase) -> void:
	var run: PlayerRun = hero.run
	var slot: int = hero.slot
	if rules.has(VersusRules.HAMMER_TIME):
		run.set_weapon(Defs.Weapon.HAMMER)
		run.set_belt(Defs.Weapon.CLUB)
	else:
		run.set_weapon(Defs.Weapon.CLUB)
		run.set_belt(PlayerRun.BELT_EMPTY)
	if rules.has(VersusRules.SPEAR_PARTY):
		run.set_belt(Defs.Weapon.SPEAR)
		_throws_left[slot] = -1
	else:
		_throws_left[slot] = 0


## When the themed sudden death starts this round (round ticks; -1 = never): Last Caveman Standing at
## VersusTuning.SUDDEN_DEATH_AT_TICKS; as the event toggle in the other modes at the same time, or at the Feast Rush
## when the round is shorter.
func _sudden_death_start() -> int:
	if mode == Defs.VersusMode.LAST_CAVEMAN:
		return VersusTuning.SUDDEN_DEATH_AT_TICKS
	if not rules.sudden_death_event:
		return -1
	if round_total > 0 and round_total - VersusTuning.FEAST_RUSH_TICKS < VersusTuning.SUDDEN_DEATH_AT_TICKS:
		return maxi(round_total - VersusTuning.FEAST_RUSH_TICKS, 0)
	return VersusTuning.SUDDEN_DEATH_AT_TICKS


## Clubball: each side at the spawn points nearest its own goal (team 1 the left ones when it defends the left goal),
## in slot order. slot -> feet point.
func _clubball_spawns(spawns: Array[Vector2i]) -> Dictionary:
	var result: Dictionary = {}
	if spawns.is_empty():
		return result
	if clubball.zones.is_empty():
		clubball.set_round(round_index)
	var sorted: Array[Vector2i] = spawns.duplicate()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	var centre: int = VersusArena.view_rect().get_center().x
	var used: Dictionary = {}
	for hero: PlayerBase in _heroes():
		var side: int = clubball.side_of(hero.slot)
		var left: bool = clubball.own_goal_x(side) < centre
		var order: Array[Vector2i] = sorted if left else sorted.duplicate()
		if not left:
			order.reverse()
		for point: Vector2i in order:
			if not used.has(point):
				used[point] = true
				result[hero.slot] = point
				break
	return result


## Skip the intro: the round starts now (tests, a rematch without countdown).
func start_round_now() -> void:
	if phase == PHASE_INTRO:
		_start_play()


## End the round now (the gong): the winners are decided by the mode's score (a tie in Grub Stack drops the Golden
## Drumstick instead unless `allow_golden` is false).
func end_round(allow_golden: bool = true) -> void:
	if phase == PHASE_OVER:
		return
	if mode == Defs.VersusMode.CLUBBALL:
		var lead: int = clubball.leader()
		if lead == 0 and allow_golden:
			# A tie at the clock's end: the golden coconut - the next goal wins (the clock stops).
			clubball.start_golden()
			phase = PHASE_GOLDEN
			return
		_finish(clubball.slots_of(lead) if lead > 0 else PackedInt32Array())
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


## Clubball after a goal's pause: every hero back at his side's spawn, shielded, playing on (the clock runs).
func kickoff() -> void:
	if level == null:
		return
	var sides: Dictionary = _clubball_spawns(VersusArena.spawn_points(level))
	for hero: PlayerBase in _heroes():
		if not sides.has(hero.slot):
			continue
		var pos: Vector2i = sides[hero.slot]
		level.respawn_hero(hero, pos)
		hero.facing = 1 if pos.x < VersusArena.view_rect().get_center().x else -1
		_shield_left[hero.slot] = VersusTuning.SPAWN_SHIELD_TICKS
		hero.shield = VersusTuning.SPAWN_SHIELD_TICKS
		_daze_left[hero.slot] = 0
		_dead_tick[hero.slot] = -1
		if phase == PHASE_OVER:
			hero.set_control_enabled(false)


## Start the arena's themed sudden death now (`theme` "" = the arena's own, VersusSuddenDeath.theme_of).
func start_sudden_death(theme: StringName = &"") -> void:
	if level == null:
		return
	if sudden_death == null:
		sudden_death = VersusSuddenDeath.new(self, level)
	var chosen: StringName = theme if theme != &"" else VersusSuddenDeath.theme_of(level.meta)
	sudden_death.start(chosen)
	# Ruling R8: from here a Last Caveman Standing round has at most VersusTuning.SUDDEN_DEATH_CAP_TICKS left (armed
	# once per round: a second start does not move it).
	if mode == Defs.VersusMode.LAST_CAVEMAN and cap_at < 0 and VersusTuning.SUDDEN_DEATH_CAP_TICKS > 0:
		cap_at = round_ticks + VersusTuning.SUDDEN_DEATH_CAP_TICKS
	_sfx(Sfx.SUDDEN_DEATH)
	Events.round_sudden_death_started.emit(round_index, chosen)


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
	if sudden_death != null:
		sudden_death.stop()
	if level != null:
		level.set_wind(0)
	for hero: PlayerBase in _heroes():
		hero.set_control_enabled(false)
		# Temporary specials end with the round (DESIGN.md E.2).
		_lose_special(hero)
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
		rules = VersusRules.from_match(null, mode)
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
	rules = VersusRules.from_match(versus_match, mode)
	knockouts_final = (mode == Defs.VersusMode.LAST_CAVEMAN and not rules.stock) or mode == Defs.VersusMode.HOT_ROCK


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


## The round score of `slot`: Grub Stack banked + stack; Last Caveman Standing the hearts left (0 when out); Hot Rock
## 1 while standing; Clubball his side's goals.
func score_of(slot: int) -> int:
	if slot < 0 or slot >= Defs.MAX_PLAYERS:
		return 0
	match mode:
		Defs.VersusMode.LAST_CAVEMAN:
			var hero: PlayerBase = level.get_hero(slot) if level != null else null
			return 0 if hero == null or _out[slot] != 0 else hero.run.hearts
		Defs.VersusMode.HOT_ROCK:
			return 0 if _out[slot] != 0 else 1
		Defs.VersusMode.CLUBBALL:
			return clubball.goals[clubball.side_of(slot)]
	return _stack[slot] + banked_of(slot)


## Hot Rock: the slot holding the ember (-1 = nobody).
func ember_holder() -> int:
	return hot_rock.holder if mode == Defs.VersusMode.HOT_ROCK else -1


## Clubball: the goals of `team` (1 / 2).
func goals_of(team: int) -> int:
	return clubball.goals[team] if team == 1 or team == 2 else 0


## Throws a temporary special of `slot` has left (0 = none counted, -1 = never runs out).
func throws_left(slot: int) -> int:
	return _throws_left[slot] if slot >= 0 and slot < Defs.MAX_PLAYERS else 0


## Last Caveman Standing with Stock: lives left of `slot`.
func stocks_of(slot: int) -> int:
	return _stocks[slot] if slot >= 0 and slot < Defs.MAX_PLAYERS else 0


## True while `slot` carries the Auto handicap's leaf shield.
func has_leaf(slot: int) -> bool:
	return slot >= 0 and slot < Defs.MAX_PLAYERS and _leaf[slot] != 0


## True while `slot` is dazed (a Grudge rock, a giant bonus bonk, a Clubball knock-down).
func is_dazed(slot: int) -> bool:
	return slot >= 0 and slot < Defs.MAX_PLAYERS and _daze_left[slot] > 0


## The cutlery pieces `slot` holds (bit mask of feast-kit indices).
func cutlery_of(slot: int) -> int:
	return _cutlery[slot] if slot >= 0 and slot < Defs.MAX_PLAYERS else 0


## Last Caveman Standing: the hearts of `slot` (0 while out or down; ui-B's corner panel). Other modes: his run's.
func hearts_of(slot: int) -> int:
	var hero: PlayerBase = level.get_hero(slot) if level != null and slot >= 0 and slot < Defs.MAX_PLAYERS else null
	if hero == null:
		return 0
	if mode == Defs.VersusMode.LAST_CAVEMAN and (_out[slot] != 0 or hero.dead):
		return 0
	return hero.run.hearts


## Mesa Rodeo (objects-B's objects/mount in an arena, GAMEPLAY.md 13.10.9): the rider `driver`'s Chomper bites
## `victim` - a hit of the mode's currency (Grub Stack: VersusTuning.RODEO_BITE_SPILL units; Last Caveman Standing: a
## heart; Hot Rock: an ember contact) with the knock-back, hurt timing, hit-stop and knock-out credit of a club hit
## from `mount`. False when it did not land (the round not running, the victim out, immune, shielded, curled or a
## teammate). The leaf shield absorbs it like a hit (true: the bite landed on the shield).
func bite_hit(driver: PlayerBase, victim: PlayerBase, mount: SimEntity) -> bool:
	if victim == null or not _round_live() or not _in_play(victim) or victim == driver:
		return false
	if _teammates(driver, victim) or _pvp_immune(victim) or victim.is_curled():
		return false
	if _leaf[victim.slot] != 0:
		_leaf[victim.slot] = 0
		victim.xvel = VersusTuning.TEAMMATE_BUMP_XVEL * _away(driver, victim, mount if mount != null else driver)
		_sfx(SFX_CLANG)
		return true
	_apply_hit(driver, mount, victim, false, -1, false, VersusTuning.RODEO_BITE_SPILL)
	return true


## objects-B's crate lanes ask the party driver what the next crate holds (CrateLane, P2.7): ItemContents tokens of
## [method VersusCrates.contents_for] for this round's mode and rules ("" = the lane's default table).
func crate_contents(_lane: Object) -> String:
	return VersusCrates.contents_for(mode, rules)


# --- What the bots read (core-B, wf8_core-B_to_world-B.txt; read-only, between ticks) ------------------------------

## Last Caveman Standing: the feet point of `slot`'s Grudge Pterodactyl, Vector2i(-1, -1) while he rides none.
func grudge_pos(slot: int) -> Vector2i:
	var grudge: VersusGrudge = _grudge_of(slot)
	return grudge.sim_pos if grudge != null else Vector2i(-1, -1)


## True when a Strike of `slot` would make his Grudge Pterodactyl squawk and drop a rock now.
func grudge_ready(slot: int) -> bool:
	var grudge: VersusGrudge = _grudge_of(slot)
	return grudge != null and grudge.cooldown == 0 and grudge.squawk == 0


## Hot Rock: ticks left in which `slot` cannot receive the ember back (0 = he can).
func ember_pass_immune(slot: int) -> int:
	if mode != Defs.VersusMode.HOT_ROCK or slot < 0 or slot >= Defs.MAX_PLAYERS:
		return 0
	return maxi(hot_rock.immune_until[slot] - round_ticks, 0)


## Hot Rock: true in the fuse's last VersusTuning.HOT_ROCK_HURRY_TICKS (the visible fast bubbling).
func ember_hurry() -> bool:
	return mode == Defs.VersusMode.HOT_ROCK and hot_rock.in_hurry()


## Clubball: the coconut (objects-B's Coconut; null outside Clubball or without one).
func ball() -> SimEntity:
	return clubball.ball() if mode == Defs.VersusMode.CLUBBALL else null


## Clubball: the goal mouth `team` (1 / 2) defends, logical px (the other team scores in it).
func goal_rect(team: int) -> Rect2i:
	return clubball.goal_rect(team)


## The boxes (logical px) that are deadly now or whose telegraph is showing and that turn deadly within
## `lookahead_ticks`: armed and telegraphing sudden-death hazards, the rising band (and its next row once the rumble
## announced it), the arena hits of the signatures (embers, the Colossus's rock) and the ring-out mouths
## (VersusSignatures). A Grudge rock is a daze, not listed. Only what a player can see.
func danger_rects(lookahead_ticks: int) -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	if level == null or not level.is_inside_tree():
		return result
	for node: Node in level.get_tree().get_nodes_in_group(ROUND_GROUP):
		var hazard: VersusHazard = node as VersusHazard
		if hazard == null or hazard.is_queued_for_deletion() \
				or (hazard.effect != VersusHazard.EFFECT_KILL and hazard.effect != VersusHazard.EFFECT_HIT):
			continue
		if not hazard.is_warning():
			result.append(hazard.danger_rect())
		elif hazard.warn_tick + hazard.warn_ticks - Sim.tick <= lookahead_ticks:
			result.append(hazard.danger_rect())
	if sudden_death != null and sudden_death.band_top >= 0 and sudden_death.theme != VersusSuddenDeath.SYRUP_FLOOD:
		var view: Rect2i = VersusArena.view_rect()
		var top: int = sudden_death.band_top
		if sudden_death.band_step_tick >= 0 and sudden_death.band_step_tick - Sim.tick <= lookahead_ticks:
			top -= Tuning.TILE
		result.append(Rect2i(view.position.x, top, view.size.x, maxi(view.end.y + Tuning.TILE - top, 0)))
	result.append_array(signatures.danger_rects())
	return result


func _grudge_of(slot: int) -> VersusGrudge:
	if level == null or not level.is_inside_tree():
		return null
	for node: Node in level.get_tree().get_nodes_in_group(ROUND_GROUP):
		var grudge: VersusGrudge = node as VersusGrudge
		if grudge != null and grudge.slot == slot and not grudge.is_queued_for_deletion():
			return grudge
	return null


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


## The round's whole length in ticks (0 = no clock) - the HUD's sundial (ui-B). Last Caveman Standing has no clock
## until its hard cap is armed (ruling R8): from then on the sundial is the cap's, VersusTuning.SUDDEN_DEATH_CAP_TICKS
## long, so the HUD counts the round's last seconds down with the timer it has.
func round_length() -> int:
	if cap_at >= 0:
		return VersusTuning.SUDDEN_DEATH_CAP_TICKS
	return round_total


## Ticks until the gong of the running round; -1 = no clock running (no clock in this mode, the countdown, the
## Golden Drumstick, after the gong) - the HUD's sundial (ui-B). With the hard cap armed: the ticks until the cap.
func round_ticks_left() -> int:
	if phase != PHASE_PLAY:
		return -1
	if cap_at >= 0:
		return cap_ticks_left()
	return time_left_ticks()


## Ticks until the hard cap of the round (ruling R8); -1 = no cap armed (not Last Caveman Standing, or its sudden
## death has not started).
func cap_ticks_left() -> int:
	if cap_at < 0:
		return -1
	return maxi(cap_at - round_ticks, 0)


## Last Caveman Standing: the hurts `slot` took this round - one per heart lost (a charged hit is two). Bones that
## heal a heart take none back, and a handicap's extra hearts do not count: it is what he TOOK, not what he has left.
func hurts_of(slot: int) -> int:
	return _hurts_taken[slot] if slot >= 0 and slot < Defs.MAX_PLAYERS else 0


## Who wins when the hard cap ends the round (ruling R8: "the hero with fewer hurts taken wins, then a draw"): among
## the sides that still stand, the one with the fewest hurts taken this round; several with the same: nobody (a draw,
## an empty list). Before the hurts, where the rules give a side more than one body or life: the side with more
## heroes standing (2v2), then with more lives left (option Stock) - a hazard takes a life without a hurt. A side is
## a team in 2v2 (its hurts, heroes and lives are summed), else one hero.
func cap_winners() -> PackedInt32Array:
	var standing: PackedInt32Array = _standing_slots()
	var bodies: Dictionary = {}   # side key -> heroes standing
	var lives: Dictionary = {}    # side key -> lives left (Stock)
	var hurts: Dictionary = {}    # side key -> hurts taken by the whole side
	for hero: PlayerBase in _heroes():
		var key: int = _side_key(hero.slot)
		hurts[key] = int(hurts.get(key, 0)) + _hurts_taken[hero.slot]
		if standing.has(hero.slot):
			bodies[key] = int(bodies.get(key, 0)) + 1
			lives[key] = int(lives.get(key, 0)) + _stocks[hero.slot]
	var best_key: int = -1
	var best: Array[int] = []
	var tie: bool = false
	for key: int in bodies:
		var value: Array[int] = [int(bodies[key]), int(lives[key]), -int(hurts[key])]
		if best_key < 0 or value > best:
			best_key = key
			best = value
			tie = false
		elif value == best:
			tie = true
	var winners: PackedInt32Array = PackedInt32Array()
	if best_key < 0 or tie:
		return winners
	for slot: int in standing:
		if _side_key(slot) == best_key:
			winners.append(slot)
	return winners


## True when the hard cap ended this round (ruling R8, DESIGN.md G78) - the gong fell on the cap's tick with more
## than one side standing - and false for every other gong (the last one standing, also on the cap's own tick; a
## clock; a goal) and while a round runs. True from the gong on, so a listener of Events.round_ended may ask.
func ended_by_cap() -> bool:
	return phase == PHASE_OVER and _capped


## "TIME!" - the round banner of a round the hard cap ended (the orchestrator's phase-4 ruling; G78 had left the
## reason unsaid). Presentation only, and nothing without a HUD (headless tests, the bot tools): the versus HUD's own
## banner (HudVersus.show_banner, reached as a sign board reaches the HUD: by its group and a method's name) shows
## "TIME!" in the alarm colour of "SUDDEN DEATH!" with the result line the HUD wrote at the gong - the winner, or its
## "Draw!" - as the second line, for as long as that line would have stayed. Called deferred from the cap's tick.
func _call_time() -> void:
	if not is_inside_tree() or not ended_by_cap():
		return
	var hud: Node = get_tree().get_first_node_in_group(Defs.GROUP_HUD)
	var banner: Object = hud.call(&"get_versus") as Object if hud != null and hud.has_method(&"get_versus") else null
	if banner == null or not banner.has_method(&"show_banner"):
		return
	var result: Variant = banner.get(&"banner_text")
	banner.call(&"show_banner", tr("UI_VS_TIME"), HudAtlas.COL_RUSH, UiKit.Style.HUD, HudVersus.RESULT_SECONDS,
			str(result) if result is String else "")


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


## The team of `slot` (-1 = free for all). Clubball always has two sides: 1 or 2 for every slot (VersusClubball).
func team_of(slot: int) -> int:
	if slot < 0 or slot >= Defs.MAX_PLAYERS:
		return -1
	if mode == Defs.VersusMode.CLUBBALL:
		return clubball.side_of(slot)
	return teams[slot]


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
			# The pick-up counters as the tick starts (food is collected later, in CONTACT_ITEMS); who stands on
			# something as the tick starts (heroes move in PLAYER, after this).
			for hero: PlayerBase in _heroes():
				_picked_seen[hero.slot] = hero.run.picked
				_airborne[hero.slot] = 0 if hero.is_grounded() or hero.is_riding_totem() else 1
			if _round_live():
				_giant_bonks()
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


## True while the round is played (after the countdown, before the gong).
func round_live() -> bool:
	return _round_live()


## In play: alive, hatched, not out of the round (the mode modules' test).
func is_in_play(hero: PlayerBase) -> bool:
	return _in_play(hero)


## The heroes of the arena in slot order.
func heroes_in_order() -> Array[PlayerBase]:
	return _heroes()


## Immune to PvP right now (spawn shield, hurt immunity, stomp immunity, the feast).
func is_pvp_immune(hero: PlayerBase) -> bool:
	return _pvp_immune(hero)


## The club frame of the hero's box (Tuning.ClubFrame).
func frame_of(hero: PlayerBase) -> int:
	return _frame_of(hero)


## True when the hero's box is a front frame (clangs, deflects, bats, shoots the coconut).
func is_front_box(hero: PlayerBase) -> bool:
	return _is_front(hero)


## True when the hero's box is charged (power x4).
func is_charged_box(hero: PlayerBase) -> bool:
	return _is_charged(hero)


## Daze `hero` for `ticks` (a Grudge rock, a giant bonus bonk, a Clubball knock-down): stunned (hit_timer 43, so
## the HURT state and no pick-ups), then hit_timer 0 at once - no immunity after. His box ends; no currency.
func daze(hero: PlayerBase, ticks: int) -> void:
	if hero == null or hero.dead or hero.is_down():
		return
	var slot: int = hero.slot
	_daze_left[slot] = maxi(ticks, 1)
	hero.hit_timer = VersusTuning.HURT_TIMER_TICKS
	hero.club_box_active = false
	hero.attack_gate = false
	hero.charge = 0
	_bank_count[slot] = 0
	_sfx(Sfx.DAZE)


## A [VersusHazard] touched `hero` (its CONTACT_ITEMS step): a sudden-death kill (the spawn shield does not help), a
## Grudge rock's daze (shield, immunity and the curl do), a crate nothing. Only while the round is played.
func hazard_contact(hero: PlayerBase, hazard: VersusHazard) -> void:
	if hero == null or hazard == null or not _round_live() or not _in_play(hero):
		return
	var slot: int = hero.slot
	match hazard.effect:
		VersusHazard.EFFECT_KILL:
			_death_cause[slot] = hazard.cause
			_death_pos[slot] = hero.sim_pos
			hero.kill(hazard.cause)
		VersusHazard.EFFECT_DAZE:
			if _pvp_immune(hero) or hero.is_curled():
				return
			daze(hero, VersusTuning.GRUDGE_ROCK_DAZE_TICKS)
			if hazard.owner_slot >= 0:
				_last_hitter[slot] = hazard.owner_slot
				_last_hit_tick[slot] = Sim.tick
		VersusHazard.EFFECT_HIT:
			arena_hit(hero, hazard)


## An arena hit (an ember, the Colossus's rock; DESIGN.md E.5, G43): a hit by nobody in the mode's currency - Grub
## Stack the spill of a hit (1 + stack / 5, nothing stolen), Last Caveman Standing one heart, Hot Rock the knock-back
## only - away from `source`, unless the hero is shielded, immune (hurt, stomp, feast) or curled. True when it landed.
func arena_hit(hero: PlayerBase, source: SimEntity) -> bool:
	if hero == null or not _round_live() or not _in_play(hero) or _pvp_immune(hero) or hero.is_curled():
		return false
	if _leaf[hero.slot] != 0:
		# The Auto handicap's leaf shield absorbs it as it absorbs a hit: a bump, nothing else.
		_leaf[hero.slot] = 0
		hero.xvel = VersusTuning.TEAMMATE_BUMP_XVEL * _away(null, hero, source)
		_sfx(SFX_CLANG)
		return true
	_apply_hit(null, source, hero, false, Defs.Weapon.CLUB, false)
	return true


## Knock `hero` out now as a hazard does (`cause`: a ring-out's "surf", ...): Grub Stack spills everything and he
## respawns, Last Caveman Standing and Hot Rock put him out (the mode's knock-out rules).
func knock_out(hero: PlayerBase, cause: StringName) -> void:
	if hero == null or not _in_play(hero):
		return
	_death_cause[hero.slot] = cause
	_death_pos[hero.slot] = hero.sim_pos
	hero.kill(cause)


## Add an entity of this round (a hazard of the signatures): it is freed when the next round begins.
func add_round_entity(node: SimEntity) -> void:
	if level == null:
		node.free()
		return
	level.get_container("fx").add_child(node)


## A cave-in block settled into `cell`: a hero whose body is in it is crushed.
func crush_cell(cell: Vector2i) -> void:
	var rect: Rect2i = Rect2i(cell * Tuning.TILE, Vector2i(Tuning.TILE, Tuning.TILE))
	for hero: PlayerBase in _heroes():
		if _in_play(hero) and Overlap.rects(rect, hero.get_box()):
			_death_cause[hero.slot] = &"crush"
			_death_pos[hero.slot] = hero.sim_pos
			hero.kill(&"crush")


## A giant bonus falling onto a head bonks it (DESIGN.md E.3: the 4.5 bounce of the item, plus a 12-tick daze); each
## falling bonus bonks once (Head Case).
func _giant_bonks() -> void:
	if mode != Defs.VersusMode.GRUB_STACK:
		return
	for entity: SimEntity in level.get_kind(Defs.Kind.COLLECTIBLE):
		var item: CollectibleBase = entity as CollectibleBase
		if item == null or item.collected or item.item_id != &"items/giant_bonus" or item.yvel <= 0:
			continue
		var id: int = item.get_instance_id()
		if _bonked.has(id):
			continue
		for hero: PlayerBase in _heroes():
			if not _in_play(hero) or _pvp_immune(hero):
				continue
			var head: Rect2i = Rect2i(hero.sim_pos.x - 8, hero.sim_pos.y - hero.box_h - 4, 16, 8)
			if Overlap.rects(head, item.get_box()):
				_bonked[id] = true
				daze(hero, VersusTuning.GIANT_BONK_DAZE_TICKS)
				_stat(hero, &"bonks", 1)
				break


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
	if _leaf[victim.slot] != 0:
		# The Auto handicap's leaf shield absorbs one hit: a bump, nothing else.
		_leaf[victim.slot] = 0
		victim.xvel = VersusTuning.TEAMMATE_BUMP_XVEL * _away(attacker, victim, hit["source"])
		_sfx(SFX_CLANG)
		return
	_apply_hit(attacker, hit["source"], victim, bool(hit["charged"]), int(hit["weapon"]), thrown)


## The C.14 hit: the contract call victim.hurt(source, RIVAL), then the referee's table (knock-back, hurt timer,
## hit-stop) and the mode's currency. The run's hearts / bones / glider are put back after the call. `spill_units`
## >= 0 replaces the Grub Stack spill formula (a feaster's touch: VersusTuning.FEAST_TOUCH_SPILL).
func _apply_hit(attacker: PlayerBase, source: SimEntity, victim: PlayerBase, charged: bool, weapon: int,
		thrown: bool, spill_units: int = -1) -> void:
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
	# Hit sparks in the attacker's colour (DESIGN.md E.9; art-A's colour rows of fx/hit_stars, FxAnim `row`).
	if attacker != null:
		_fx(&"fx/hit_stars", Vector2i(victim.sim_pos.x, victim.sim_pos.y - victim.box_h / 2),
				{"row": UiPlayers.colour_index(attacker.slot)})
	_daze_left[victim.slot] = 0
	_drop_cutlery(victim)
	var one_bonk: bool = rules.has(VersusRules.ONE_BONK)
	# The mode's currency.
	match mode:
		Defs.VersusMode.GRUB_STACK:
			var divisor: int = VersusTuning.SPILL_HIT_DIV
			if charged:
				divisor = VersusTuning.SPILL_CHARGED_DIV
			elif thrown:
				divisor = VersusTuning.SPILL_THROWN_DIV
			var units: int = VersusTuning.spill(_stack[victim.slot], divisor)
			if spill_units >= 0:
				units = mini(spill_units, _stack[victim.slot])
			if one_bonk:
				units = _stack[victim.slot]
			spill(victim, units, true)
		Defs.VersusMode.LAST_CAVEMAN:
			var hearts_lost: int = VersusTuning.LCS_CHARGED_HEARTS if charged else 1
			if one_bonk:
				hearts_lost = victim.run.hearts
			_lose_hearts(victim, hearts_lost, attacker, &"hit")
		Defs.VersusMode.HOT_ROCK:
			if attacker != null:
				hot_rock.contact(attacker, victim, round_ticks)


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
			if rules.has(VersusRules.SLIPPERY):
				hero.ice = maxi(hero.ice, VersusRules.SLIPPERY_ICE)
		_apply_weight(hero)
	_wrap_projectiles()
	if _round_live():
		_feast_touches(heroes)
		_body_bump(heroes)
		if mode == Defs.VersusMode.HOT_ROCK:
			hot_rock.touch(round_ticks)


## The versus feast (DESIGN.md E.3): a feaster's touch knocks VersusTuning.FEAST_TOUCH_SPILL units off any rival he
## overlaps (a hit with its knock-back; Last Caveman Standing a heart) - hits cannot touch him meanwhile.
func _feast_touches(heroes: Array[PlayerBase]) -> void:
	for feaster: PlayerBase in heroes:
		if _feast_left[feaster.slot] <= 0 or not _in_play(feaster):
			continue
		for victim: PlayerBase in heroes:
			if victim == feaster or not _in_play(victim) or _teammates(feaster, victim) or _pvp_immune(victim):
				continue
			if victim.is_curled() or not Overlap.body(feaster, victim):
				continue
			_apply_hit(feaster, feaster, victim, false, feaster.run.weapon, false, VersusTuning.FEAST_TOUCH_SPILL)


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
## 4+ px/tick knocks both back (+/-64, -64), no damage - only when both stand on something (a knock while either is
## still in the air from the last one would lift them again every tick: core-B's floating pair), and the nudge apart
## comes on the knock tick too.
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
			if left.xvel >= VersusTuning.BODY_KNOCK_MIN_XVEL and -right.xvel >= VersusTuning.BODY_KNOCK_MIN_XVEL \
					and left.is_grounded() and right.is_grounded():
				left.xvel = -VersusTuning.BODY_KNOCK_XVEL
				right.xvel = VersusTuning.BODY_KNOCK_XVEL
				left.yvel = VersusTuning.BODY_KNOCK_YVEL
				right.yvel = VersusTuning.BODY_KNOCK_YVEL
				left.grounded = false
				right.grounded = false
				left.on_platform = false
				right.on_platform = false
				_sfx(Sfx.BOUNCE)
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
	elif mode == Defs.VersusMode.HOT_ROCK:
		cap = hot_rock.walk_cap_for(slot)
	if sudden_death != null and sudden_death.band_effect(hero) == &"slow":
		cap = mini(cap, VersusSuddenDeath.SYRUP_WALK_CAP)
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
		if _airborne[stomper.slot] == 0:
			continue  # a stomp is a landing: a hero standing on a tier never stomps a head rising into his feet
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
		var up_yvel: int = VersusRules.BIG_BOUNCE_YVEL if rules.has(VersusRules.BIG_BOUNCE) else Tuning.BOUNCE_YVEL_UP
		stomper.bounce(up_yvel if up else Tuning.BOUNCE_YVEL, int(stomp["depth"]))
		_sfx(Sfx.BOUNCE)
		if mode == Defs.VersusMode.HOT_ROCK and not _teammates(stomper, victim):
			hot_rock.contact(stomper, victim, round_ticks)
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
	# The arena's neutral enemies are springboards (the hero's own contact skips them: they hurt nobody).
	signatures.springboard_step()


# --- WORLD: the round -------------------------------------------------------------------------------------------------

func _round_step() -> void:
	match phase:
		PHASE_INTRO:
			signatures.wind_step()
			var steps: int = VersusTuning.COUNTDOWN_STEPS
			if _intro_ticks % INTRO_COUNT_TICKS == 0 and _intro_ticks < steps * INTRO_COUNT_TICKS:
				Events.round_countdown.emit(round_index, steps - _intro_ticks / INTRO_COUNT_TICKS)
				_sfx(Sfx.COUNTDOWN_BEEP)
			_intro_ticks += 1
			if _intro_ticks >= steps * INTRO_COUNT_TICKS:
				_start_play()
		PHASE_PLAY:
			round_ticks += 1
			_world_rules()
			signatures.wind_step()
			if phase != PHASE_PLAY:
				return  # a goal ended the game
			if mode == Defs.VersusMode.GRUB_STACK:
				_refill_spots()
			if mode == Defs.VersusMode.GRUB_STACK and round_total > 0 and not _feast_rush \
					and round_ticks >= round_total - VersusTuning.FEAST_RUSH_TICKS:
				_start_feast_rush()
			if round_total > 0 and round_ticks >= round_total:
				end_round()
			elif mode == Defs.VersusMode.LAST_CAVEMAN or mode == Defs.VersusMode.HOT_ROCK:
				var standing: PackedInt32Array = _standing_slots()
				if _team_count(standing) <= 1 and level.hero_count() > 1:
					_finish(standing)
				elif cap_at >= 0 and round_ticks >= cap_at:
					# Ruling R8: the hard cap. Nobody outlasts the sudden death by hiding from it.
					_capped = true
					_finish(cap_winners())
					# "TIME!" (phase 4): after every listener of the gong, so the HUD's result line is there to keep.
					_call_time.call_deferred()
		PHASE_GOLDEN:
			round_ticks += 1
			signatures.wind_step()
			if mode == Defs.VersusMode.CLUBBALL:
				_world_rules()
			elif _golden == null or not is_instance_valid(_golden):
				_finish(_best_slots())


## The WORLD part of the mode modules and the round's rules: Hot Rock's ember, Clubball's goals, the variants on a
## clock (Gusty, Giant Rain), the themed sudden death (start, threats, the band).
func _world_rules() -> void:
	match mode:
		Defs.VersusMode.HOT_ROCK:
			hot_rock.tick(round_ticks)
		Defs.VersusMode.CLUBBALL:
			var scorer: int = clubball.tick()
			if scorer > 0 and clubball.has_won(scorer):
				_finish(clubball.slots_of(scorer))
				return
	if rules.has(VersusRules.GUSTY) and round_ticks % VersusRules.GUSTY_PERIOD_TICKS == 1:
		gust_wind = VersusRules.GUSTY_WIND * _gust_sign
		level.set_wind(gust_wind)
		_gust_sign = -_gust_sign
	signatures.world_step()
	if rules.has(VersusRules.GIANT_RAIN) and mode == Defs.VersusMode.GRUB_STACK \
			and round_ticks % VersusRules.GIANT_RAIN_PERIOD_TICKS == 0 and Spawner.exists(&"items/giant_bonus"):
		var view: Rect2i = VersusArena.view_rect()
		var x: int = view.position.x + Tuning.TILE + Sim.rng.next_int(view.size.x - 2 * Tuning.TILE)
		_spawned.append(level.spawn(&"items/giant_bonus", Vector2i(x, Tuning.TILE * 2),
				{"index": SPILL_GIANT_INDEX, "dropped": true, "xvel": 0, "yvel": 0}))
	if sudden_death_at >= 0 and round_ticks == sudden_death_at and not sudden_death.is_running():
		start_sudden_death()
	if sudden_death != null and sudden_death.is_running():
		sudden_death.tick()
		for hero: PlayerBase in _heroes():
			if _in_play(hero) and sudden_death.band_effect(hero) == &"kill":
				_death_cause[hero.slot] = &"liquid"
				_death_pos[hero.slot] = hero.sim_pos
				hero.kill(&"liquid")


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
	_count_throws()
	for hero: PlayerBase in _heroes():
		var slot: int = hero.slot
		if hero.dead:
			if _dead_tick[slot] < 0:
				_dead_tick[slot] = Sim.tick
				_knocked_out(hero)
			elif _out[slot] == 0 and _round_live() and Sim.tick - _dead_tick[slot] >= VersusTuning.RESPAWN_TICKS:
				_respawn(hero)
			if _grudge_at[slot] >= 0 and _round_live() and round_ticks >= _grudge_at[slot]:
				_launch_grudge(hero)
			continue
		_dead_tick[slot] = -1
		_count_down(hero)


## Temporary specials (PHYSICS.md C.14): every new throw of a hero counts against his special's
## VersusTuning.SPECIAL_THROWS (axe 3, swirling axe 2, spear 3; the hammer never); at 0 the special is gone (the club
## in the hand, the belt empty). Spear Party's spear never runs out.
func _count_throws() -> void:
	if level == null:
		return
	var projectiles: Array[SimEntity] = level.get_kind(Defs.Kind.HERO_PROJECTILE)
	for i: int in projectiles.size():
		var projectile: ProjectileBase = projectiles[i] as ProjectileBase
		if projectile == null or not projectile.from_hero:
			continue
		var id: int = projectile.get_instance_id()
		if _thrown_seen.has(id):
			continue
		_thrown_seen[id] = true
		var slot: int = projectile.owner_slot
		if slot < 0 or slot >= Defs.MAX_PLAYERS or _throws_left[slot] <= 0:
			continue
		_throws_left[slot] -= 1
		if _throws_left[slot] == 0:
			var hero: PlayerBase = level.get_hero(slot)
			if hero != null:
				_lose_special(hero)


## The hero's special is gone: the club in the hand, the belt empty (Hammer Time keeps the hammer: it is the round's
## weapon).
func _lose_special(hero: PlayerBase) -> void:
	var run: PlayerRun = hero.run
	_throws_left[hero.slot] = 0
	if rules.has(VersusRules.HAMMER_TIME):
		if run.weapon != Defs.Weapon.HAMMER or run.belt != Defs.Weapon.CLUB:
			run.set_weapon(Defs.Weapon.HAMMER)
			run.set_belt(Defs.Weapon.CLUB)
		return
	if run.weapon != Defs.Weapon.CLUB:
		run.set_weapon(Defs.Weapon.CLUB)
	if run.belt != PlayerRun.BELT_EMPTY:
		run.set_belt(PlayerRun.BELT_EMPTY)


## An out hero's Grudge Pterodactyl takes off over where he fell (Last Caveman Standing).
func _launch_grudge(hero: PlayerBase) -> void:
	var slot: int = hero.slot
	_grudge_at[slot] = -1
	var grudge: VersusGrudge = VersusGrudge.new().setup(slot, _death_pos[slot].x, self)
	level.get_container("fx").add_child(grudge)
	_spawned.append(grudge)


## Free what the referee spawned in the round before (grudges, hazards, crates, rain): its own list and every node of
## the group ROUND_GROUP under the level.
func _clear_spawned() -> void:
	var nodes: Array[Node] = _spawned.duplicate()
	if level != null and level.is_inside_tree():
		for node: Node in level.get_tree().get_nodes_in_group(ROUND_GROUP):
			if level.is_ancestor_of(node):
				nodes.append(node)
	for node: Node in nodes:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			if node is SimEntity:
				(node as SimEntity).sim_active = false
			node.queue_free()
	_spawned.clear()


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
	if _daze_left[slot] > 0:
		_daze_left[slot] -= 1
		if _daze_left[slot] == 0:
			hero.hit_timer = 0   # a daze leaves no immunity
		else:
			hero.hit_timer = maxi(hero.hit_timer, VersusTuning.STUN_HIT_TIMER_MIN)
	# The versus feast is the referee's clock (a feast the 1.0 kit item started on its own does not count).
	if _feast_left[slot] > 0:
		_feast_left[slot] -= 1
		hero.feast = _feast_left[slot]
	elif hero.feast > 0:
		hero.feast = 0


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
			if rules.stock and not knockouts_final:
				# Option Stock: a knock-out costs a life; the last one puts him out.
				_stocks[slot] = maxi(_stocks[slot] - 1, 0)
				if _stocks[slot] <= 0:
					_out[slot] = 1
			elif knockouts_final or hero.run.hearts <= 0:
				_out[slot] = 1
			if _out[slot] != 0:
				_grudge_at[slot] = round_ticks + VersusTuning.RESPAWN_TICKS
		Defs.VersusMode.HOT_ROCK:
			_out[slot] = 1
	_lose_special(hero)
	_drop_cutlery(hero)
	_feast_left[slot] = 0
	_daze_left[slot] = 0
	_leaf[slot] = 0
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
	hero.run.hearts = Tuning.ENERGY_START if mode != Defs.VersusMode.LAST_CAVEMAN else start_hearts[slot]
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
	if item_id == &"items/feast_piece":
		_collect_cutlery(collector, index)
		return
	if item_id == &"items/weapon":
		var weapon: int = collector.run.special()
		if weapon == Defs.Weapon.SPEAR and rules.has(VersusRules.SPEAR_PARTY):
			_throws_left[collector.slot] = -1
		elif weapon >= 0 and weapon < VersusTuning.SPECIAL_THROWS.size():
			_throws_left[collector.slot] = VersusTuning.SPECIAL_THROWS[weapon]
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


## The versus feast (DESIGN.md E.3): each hero collects his own fork, knife and spoon (the 1.0 kit is the team's:
## its mask is cleared here); his third piece starts his feast of VersusTuning.FEAST_TICKS.
func _collect_cutlery(hero: PlayerBase, index: int) -> void:
	var slot: int = hero.slot
	_cutlery[slot] |= 1 << clampi(index, 0, Tuning.FEAST_PIECES - 1)
	if Game.feast_kit != 0:
		Game.feast_kit = 0
		Game.feast_kit_changed.emit(0)
	if _cutlery[slot] == (1 << Tuning.FEAST_PIECES) - 1:
		_cutlery[slot] = 0
		_feast_left[slot] = VersusTuning.FEAST_TICKS
		hero.start_feast(VersusTuning.FEAST_TICKS)


## A hit (or a knock-out) drops the cutlery a hero holds: the pieces hop out as dropped items.
func _drop_cutlery(hero: PlayerBase) -> void:
	var slot: int = hero.slot
	if _cutlery[slot] == 0:
		return
	var mask: int = _cutlery[slot]
	_cutlery[slot] = 0
	if level == null or not Spawner.exists(&"items/feast_piece"):
		return
	var n: int = 0
	for index: int in Tuning.FEAST_PIECES:
		if mask & (1 << index):
			var velocity: Vector2i = ObjTuning.fan_velocity(n, ObjTuning.BURST_XVEL, ObjTuning.BURST_YVEL)
			level.spawn(&"items/feast_piece", Vector2i(hero.sim_pos.x, hero.sim_pos.y - hero.box_h),
					{"index": index, "dropped": true, "xvel": velocity.x, "yvel": velocity.y})
			n += 1


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
	_hurts_taken[victim.slot] += lost
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


## The slots still in the round: not out, and not dead in a mode where a knock-out is final (a Stock hero waiting
## for his respawn still stands).
func _standing_slots() -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for hero: PlayerBase in _heroes():
		if _out[hero.slot] == 0 and not (hero.dead and (knockouts_final or mode == Defs.VersusMode.HOT_ROCK)):
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
	if attacker == null and source is VersusHazard:
		# An arena hit: away from the ember / rock (its flight decides when it hit him dead centre).
		if victim.sim_pos.x != source.sim_pos.x:
			return 1 if victim.sim_pos.x > source.sim_pos.x else -1
		return 1 if source.xvel >= 0 else -1
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
		seen[_side_key(slot)] = true
	return seen.size()


## The side `slot` plays on, as a key: his team in 2v2 (100 + team), else the slot itself.
func _side_key(slot: int) -> int:
	return teams[slot] + 100 if teams[slot] >= 0 else slot


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


func _fx(id: StringName, pos: Vector2i, params: Dictionary = {}) -> void:
	if level != null and Spawner.exists(id):
		level.spawn_fx(id, pos, params)


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

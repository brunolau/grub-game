class_name HeroBot
extends RefCounted
## A computer player: an input producer for one player slot (docs/expansion/DESIGN.md E.7, GAMEPLAY.md 13.10.10,
## PLAN.md P1.2 / P2.5). Owner: core-B.
##
## Each tick GameInput.sample() calls [method produce] (InputSlot.BOT) and the bot returns the flags a human would
## press, decided from the state at the end of the previous tick. It draws only from its own [SimRng] (seeded from the
## match seed and the slot), never from Sim.rng, and never looks inside a spot or a crate - so a bot match is a pure
## function of the inputs and replays tick for tick (and a recorded match replays without the bot).
##
## Difficulty is reaction and decisions, never cheating (Defs.BotLevel): what the bot sees of the OTHER heroes is
## VersusTuning.bot_reaction_ticks(level) ticks old (Rookie 10, Hunter 6, Chief 3); its own hero it knows now.
## Goals are re-chosen every VersusTuning.BOT_GOAL_PERIOD_TICKS (6) by the mode's [BotBrain] ([GrubStackBrain],
## [LastCavemanBrain], [HotRockBrain], [ClubballBrain]; Party Mix swaps it per round); [BotNavigator] walks and jumps
## on the level's [NavGraph] (res://resources/bots/<level_id>.json, baked by tools/bots/bake_nav.gd) with the links of
## its weight class.
##
## Usage (Flow / VersusMatch, core-A):
##     var bot: HeroBot = HeroBot.new(slot, Defs.BotLevel.ROOKIE, match_seed, Defs.VersusMode.GRUB_STACK)
##     bot.install()      # GameInput.assign_slot(slot, InputSlot.bot(bot.produce)); keep the bot referenced
##     bot.uninstall()    # GameInput.assign_slot(slot, null)
## The bot follows Game.level: a new level (a new round) re-binds its graph and brain by itself.
##
## Boss use (the Rival Chieftains, GAMEPLAY.md 13.6, enemies-C): [method for_boss] makes a bot that drives a hero
## body of a boss shell ([member body], not one of level.heroes) with a [ChieftainBrain]; every hero of the level is
## its rival. The shell feeds the body from [method produce] (or [method install] on the slot the body reads).

## Seen-state layout: SEEN_FIELDS ints per player slot and tick.
const SEEN_FIELDS: int = 9
const SEEN_X: int = 0
const SEEN_Y: int = 1
const SEEN_XVEL: int = 2
const SEEN_YVEL: int = 3
const SEEN_BITS: int = 4
const SEEN_STACK: int = 5
const SEEN_FACING: int = 6
const SEEN_HIT_TIMER: int = 7
const SEEN_HEARTS: int = 8
## SEEN_BITS flags.
const SEEN_PRESENT: int = 1
const SEEN_GROUNDED: int = 2
const SEEN_CROUCHING: int = 4
const SEEN_STRIKING: int = 8
const SEEN_SAFE: int = 16       ## immune, shielded, dead or down: no point in hitting him
const SEEN_BANKING: int = 32
const SEEN_GONE: int = 64       ## dead, down or out of the round
const SEEN_CURLED: int = 128    ## curled or flying as a ball (a bat target)
const SEEN_HOLDER: int = 256    ## holds the Hot Rock ember
const SEEN_SQUASHED: int = 512  ## stomped: no jump, no strike for a few ticks
## Flags that act in place (not idle): crouch, strike, jump.
const ACTIVE_FLAGS: int = Defs.IN_DOWN | Defs.IN_FIRE | Defs.IN_UP

## Player slot this bot plays (0..Defs.MAX_PLAYERS - 1); for a boss bot the key of its stream (and the GameInput
## slot [method install] feeds).
var slot: int = 0
## Defs.BotLevel.
var bot_level: int = Defs.BotLevel.HUNTER
## Defs.VersusMode the brain plays.
var versus_mode: int = Defs.VersusMode.GRUB_STACK
## The match seed it was created with.
var match_seed: int = 1
## The bot's own random stream (never Sim.rng).
var rng: SimRng = SimRng.new(1)
## Ticks of delay on what it sees of the other heroes.
var reaction: int = 6
## Walking and jumping.
var nav: BotNavigator = BotNavigator.new()
## The live movers of the level's graph.
var movers: NavMoversLive = NavMoversLive.new()
## The mode's decisions.
var brain: BotBrain = null
## The level it is bound to (null = none yet).
var level: LevelBase = null
## A boss body this bot drives instead of the hero of [member slot] (null = a versus bot).
var body: PlayerBase = null
## Flags it produced last (tests, the HUD's bot debug).
var last_flags: int = 0
## Ticks its hero has stood still while it had control and pressed nothing that acts in place (V4.b: no bot idle
## more than 10 s). Crouching (banking, charging), striking and jumping are not idle; pushing a direction without
## moving is (stuck).
var idle_ticks: int = 0

# Ring of seen states: (reaction + 1) entries of SEEN_FIELDS * MAX_PLAYERS ints.
var _seen: Array[PackedInt32Array] = []
var _seen_ticks: PackedInt32Array = PackedInt32Array()
var _seen_count: int = 0
var _installed: bool = false
var _installed_slot: int = 0
# Levels already reported as having no graph.
static var _warned: Dictionary = {}
var _last_pos: Vector2i = Vector2i(-(1 << 20), -(1 << 20))


func _init(p_slot: int = 0, p_level: int = Defs.BotLevel.HUNTER, p_seed: int = 1,
		p_mode: int = Defs.VersusMode.GRUB_STACK) -> void:
	slot = clampi(p_slot, 0, Defs.MAX_PLAYERS - 1)
	bot_level = clampi(p_level, Defs.BotLevel.ROOKIE, Defs.BotLevel.CHIEF)
	versus_mode = p_mode
	match_seed = p_seed
	reaction = VersusTuning.bot_reaction_ticks(bot_level)
	reset_round(p_seed)
	brain = make_brain(versus_mode)
	brain.bot = self


## A bot that drives `p_body`, a hero body of a boss shell (the Rival Chieftains), with a [ChieftainBrain]; `key`
## mixes into its stream (enemies-C passes 2 for Gorm, 3 for Gulla). [method install] feeds the GameInput slot the
## body reads (its `slot`; [member input_slot]).
static func for_boss(p_body: PlayerBase, p_seed: int, p_level: int = Defs.BotLevel.HUNTER, key: int = 0) -> HeroBot:
	var bot: HeroBot = HeroBot.new(key, p_level, p_seed, Defs.VersusMode.GRUB_STACK)
	bot.body = p_body
	bot.brain = ChieftainBrain.new()
	bot.brain.bot = bot
	return bot


## The GameInput slot this bot feeds: its boss body's slot (the slot the body reads), else [member slot].
func input_slot() -> int:
	if body != null and is_instance_valid(body):
		return clampi(body.slot, 0, Defs.MAX_PLAYERS - 1)
	return slot


## The seed of a bot's own stream: the match (or round) seed mixed with the slot.
static func seed_for(p_seed: int, p_slot: int) -> int:
	return (p_seed * 1103515245 + (p_slot + 1) * 12345 + 0x5BD1E995) & 0x7FFFFFFF


## The brain of a versus mode (the second-wave modes have none yet: they get the Grub Stack brain).
static func make_brain(mode: int) -> BotBrain:
	match mode:
		Defs.VersusMode.LAST_CAVEMAN:
			return LastCavemanBrain.new()
		Defs.VersusMode.HOT_ROCK:
			return HotRockBrain.new()
		Defs.VersusMode.CLUBBALL:
			return ClubballBrain.new()
	return GrubStackBrain.new()


## Restart the bot's own random stream from a (round) seed and forget the seen states. Flow calls it at every round
## start with the round seed; when the match's round mode changed (Party Mix: Game.versus_match.round_mode) the bot
## takes the brain of the new mode.
func reset_round(p_seed: int) -> void:
	var versus_match: Object = Game.get(&"versus_match") as Object
	if versus_match != null and brain != null and body == null:
		var round_mode: Variant = versus_match.get(&"round_mode")
		if round_mode != null and int(round_mode) >= 0 and int(round_mode) != versus_mode:
			set_mode(int(round_mode))
	rng.reseed(seed_for(p_seed, slot))
	_seen.clear()
	_seen_ticks = PackedInt32Array()
	for i: int in reaction + 1:
		var entry: PackedInt32Array = PackedInt32Array()
		entry.resize(SEEN_FIELDS * Defs.MAX_PLAYERS)
		_seen.append(entry)
		_seen_ticks.append(-1)
	_seen_count = 0
	idle_ticks = 0
	nav.reset()
	if brain != null:
		brain.reset()


## Play another versus mode from now on (a new brain).
func set_mode(mode: int) -> void:
	versus_mode = mode
	brain = make_brain(mode)
	brain.bot = self


## Feed the slot from this bot (GameInput.assign_slot with InputSlot.bot; [method input_slot]).
func install() -> void:
	_installed_slot = input_slot()
	GameInput.assign_slot(_installed_slot, InputSlot.bot(produce))
	_installed = true


## Give the slot back (it reads nothing until it is assigned again).
func uninstall() -> void:
	if _installed:
		GameInput.assign_slot(_installed_slot, null)
	_installed = false


## The hero this bot plays (its boss body, else the level's hero of its slot); null when none.
func get_hero() -> PlayerBase:
	if body != null:
		return body if is_instance_valid(body) else null
	return level.get_hero(slot) if level != null else null


## True when the hero in `p_slot` is a rival (a boss bot: every hero of the level but its own body and its mate's; a
## versus bot: BotSenses.are_rivals). Before the bot is bound it reads Game.level.
func is_rival(p_slot: int) -> bool:
	var current: LevelBase = level if level != null else Game.level
	if body != null:
		var hero: PlayerBase = current.get_hero(p_slot) if current != null else null
		if hero == null or hero == body:
			return false
		var chieftain: ChieftainBrain = brain as ChieftainBrain
		return chieftain == null or chieftain.mate != hero
	return BotSenses.are_rivals(current, slot, p_slot)


## The InputSlot source: the flags for tick `tick` (GameInput.sample(), before the tick runs).
func produce(tick: int) -> int:
	var current: LevelBase = Game.level
	if current == null or not is_instance_valid(current):
		level = null
		return 0
	if current != level:
		bind(current)
	_record(tick)
	movers.update()
	var hero: PlayerBase = get_hero()
	if hero == null or hero.dead or hero.is_down() or (body == null and BotSenses.is_out(level, slot)):
		nav.link = null
		last_flags = brain.act_out(level, tick) if body == null else 0
		return last_flags
	if not hero.control_enabled:
		nav.link = null
		last_flags = 0
		return 0
	if hero.sim_pos != _last_pos or (last_flags & ACTIVE_FLAGS) != 0:
		idle_ticks = 0
	else:
		idle_ticks += 1
	_last_pos = hero.sim_pos
	nav.set_weight_class(brain.nav_class(hero, level))
	nav.update_movers(hero, movers)
	# A versus bot never steers a fall to where nothing is to land on; a boss body keeps the plain rule (its recorded
	# routes replay the navigator tick for tick).
	nav.safe_falls = body == null
	if brain.needs_thinking(tick) or (tick + slot) % VersusTuning.BOT_GOAL_PERIOD_TICKS == 0:
		brain.think(hero, level, tick)
	var flags: int = brain.act(hero, level, tick)
	if not brain.may_strike(hero):
		flags &= ~Defs.IN_FIRE  # keep the spawn shield (BotBrain.may_strike)
	if body == null and not nav.is_busy():
		flags = brain.guard_ramming(hero, flags)
	last_flags = flags
	return flags


## Bind to a level: its baked graph (none: the bot only walks within the floor it stands on).
func bind(p_level: LevelBase) -> void:
	level = p_level
	nav.graph = NavGraph.load_for_level(level.level_id)
	if nav.graph == null and not _warned.has(level.level_id):
		_warned[level.level_id] = true
		push_warning("HeroBot: %s has no nav graph (%s): the bots only walk. Bake it: bash .tools/gd.sh script "
				% [level.level_id, NavGraph.path_for(level.level_id)] + "res://tools/bots/bake_nav.gd -- %s"
				% level.level_id)
	movers.bind(level, nav.graph)
	nav.reset()
	_seen_count = 0
	brain.reset()


## What this bot saw of the hero in `p_slot`, `reaction` ticks ago (the oldest it has when the match is younger):
## SEEN_FIELDS ints (SEEN_X ...). Its own slot reads the newest entry.
func seen(p_slot: int) -> PackedInt32Array:
	if _seen_count == 0 or p_slot < 0 or p_slot >= Defs.MAX_PLAYERS:
		var empty: PackedInt32Array = PackedInt32Array()
		empty.resize(SEEN_FIELDS)
		return empty
	var size: int = _seen.size()
	var newest: int = (_seen_count - 1) % size
	var age: int = 0 if (p_slot == slot and body == null) else mini(reaction, _seen_count - 1)
	var entry: PackedInt32Array = _seen[(newest - age + size) % size]
	return entry.slice(p_slot * SEEN_FIELDS, (p_slot + 1) * SEEN_FIELDS)


## The seen position of a slot.
func seen_pos(p_slot: int) -> Vector2i:
	var s: PackedInt32Array = seen(p_slot)
	return Vector2i(s[SEEN_X], s[SEEN_Y])


## Where the hero of `p_slot` is likely now: his seen feet point moved on by his seen speed over the seen state's age
## (x only; at most the reaction ticks) - a player's anticipation, still nothing he could not see.
func predicted_pos(p_slot: int) -> Vector2i:
	var s: PackedInt32Array = seen(p_slot)
	var age: int = 0 if (p_slot == slot and body == null) else mini(reaction, maxi(_seen_count - 1, 0))
	return Vector2i(s[SEEN_X] + Tuning.floor16(s[SEEN_XVEL] * age), s[SEEN_Y])


## True when the seen hero of `p_slot` is in play (present, not dead, down or out).
func seen_alive(p_slot: int) -> bool:
	var bits: int = seen(p_slot)[SEEN_BITS]
	return (bits & SEEN_PRESENT) != 0 and (bits & SEEN_GONE) == 0


func _record(tick: int) -> void:
	var size: int = _seen.size()
	var index: int = _seen_count % size
	var entry: PackedInt32Array = _seen[index]
	entry.fill(0)
	var holder: int = BotSenses.ember_holder(level)
	for p_slot: int in Defs.MAX_PLAYERS:
		var hero: PlayerBase = level.get_hero(p_slot)
		if hero == null:
			continue
		var base: int = p_slot * SEEN_FIELDS
		var bits: int = SEEN_PRESENT
		if hero.is_grounded():
			bits |= SEEN_GROUNDED
		if hero.is_low():
			bits |= SEEN_CROUCHING
		if hero.is_striking():
			bits |= SEEN_STRIKING
		if hero.is_immune():
			bits |= SEEN_SAFE
		if hero.dead or hero.is_down() or BotSenses.is_out(level, p_slot):
			bits |= SEEN_GONE | SEEN_SAFE
		if hero.is_curled():
			bits |= SEEN_CURLED
		if hero.squash > 0:
			bits |= SEEN_SQUASHED
		if p_slot == holder:
			bits |= SEEN_HOLDER
		if BotSenses.is_banking(level, p_slot):
			bits |= SEEN_BANKING
		entry[base + SEEN_X] = hero.sim_pos.x
		entry[base + SEEN_Y] = hero.sim_pos.y
		entry[base + SEEN_XVEL] = hero.xvel
		entry[base + SEEN_YVEL] = hero.yvel
		entry[base + SEEN_BITS] = bits
		entry[base + SEEN_STACK] = BotSenses.stack_of(level, p_slot)
		entry[base + SEEN_FACING] = hero.facing
		entry[base + SEEN_HIT_TIMER] = hero.hit_timer
		entry[base + SEEN_HEARTS] = hero.run.hearts if hero.run != null else 0
	_seen[index] = entry
	_seen_ticks[index] = tick
	_seen_count += 1

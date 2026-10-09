class_name CoopTraits
extends RefCounted
## The co-op traits of one enemy record (DESIGN.md D.6, GAMEPLAY.md 13.9.5; PLAN.md P1.8): `shell`, `bond`, `daze`,
## `heavy`, `lone`, `grab`, `leech` and `split`, plus the bond registry they share with `objects/drum bond=` and the
## keeper doors (LevelBase.get_tagged, the phase-0 hooks of PLAN.md P0.8).
##
## Owner: enemies-A. One instance per record whose level parameter `coop=<trait>` is set (or a preset that carries one,
## `enemies/shellback`): EnemyBase._apply_params creates it, no 1.0 record ever has one. EnemyBase calls it from its
## own body, so every archetype gets the rules without code of its own. The rules run only in a co-op party
## ([method party_on]: Game.mode COOP with LevelBase.hero_count() > 1, PHYSICS.md C.0 #2); for a party of one every
## trait collapses to nothing and the record is its plain archetype (TECH_AUDIT.md 2: N = 1 is the identity).
##
## Where each rule hooks in, in tick order (Defs.Phase):
##  - WEAPONS (a hero's weapon pass -> EnemyBase.take_hit): [method skips_hit] (the leech host's own boxes pass
##    through it), [method accepts_hit] (EnemyBase.accepts_hit_from: the front of a `shell`, an undazed `daze` and
##    every hit on a `heavy` that no Brace Wall has dazed glance, G57), [method absorbs_hit] (the first hit splits a
##    `split` record without damage; a partner's hit frees a grabbed hero or clubs a leech off - those hits count).
##    G57's one hit per strike is EnemyBase's (every enemy of a co-op party, trait or not; [method strike_key]).
##  - deaths that are no weapon hit (EnemyBase.kill, burst_into_items, on_glider_stomp): [method refuses_death] (G57:
##    a `heavy` dies of nothing while no Brace Wall has it dazed: no kill-all, grenade, feast or glider dive).
##  - ENEMIES: [method pre_ai] before the archetype's `_ai_tick()` - true when the trait ran the tick itself (the
##    regrow, a daze, the daze hop, the grab carry, the leech ride, the split run); [method post_ai] after it (the
##    shell turns to the nearer hero, the Brace Wall test); a dead `bond` / `split` record runs [method dead_tick]
##    (its window: seal, regrow or merge) and does not doze meanwhile ([method keeps_awake]).
##  - CONTACT_ENEMIES (`heavy`, `grab` and `leech` records register this phase too; level records come before the
##    heroes, so this runs before their contact pass): [method contact_tick] - the Brace Wall test, the seize, the
##    latch; placing a held hero, riding a host.
##  - the hero's contact pass: EnemyBase.on_bounced -> [method on_bounced] (the `daze` head bounce).
##  - targeting: EnemyBase._choose_target asks [method lone_target] for a `lone` record (Expert).
##
## Windows (bond, split): PartyTuning.window_ticks(difficulty) = 24 ticks Beginner / 12 Expert; the kills must land
## within the window: `last kill tick - first kill tick < window`. The window opens on the first death and is decided
## by the dead records themselves: on the first ENEMIES tick with `now - first >= window` the group regrows (bond) or
## merges (split). A group that died in time is sealed: dead until a team wipe resets the level.
## Per-record caps (GAMEPLAY.md 13.9.3 / LEVEL_DESIGN.md 15.7.6: `window = min(24 B / 12 E, solo_min - 4)` per placed
## record): level parameter `window=<ticks>` on a `bond`, `split` or `daze` record caps its window (a bond uses the
## smallest cap of its members) or its daze time; [method capped_window] is the same rule for tools reading level files.
## Count-in (GAMEPLAY.md 13.9.3): while every member of a bond (or both halves of a split) is alive and each has a
## hatched hero within EnemyTuning.COUNT_IN_REACH_PX - not one hero for all - the group plays three blips
## PartyTuning.COUNT_IN_SPACING_TICKS apart, then "go" (presentation only, like the twin drums' count-in).
##
## THE WINDOWS ARE SLOT-BOUND (orchestrator ruling R2 of the G3b round; G3b cause C: one hero threw at the far member
## and hit the near one as that special landed - the gap between two hits in flight is his to choose). A bond or a
## split is met only by deaths credited to TWO DIFFERENT heroes who both COUNT (PlayerBase.counts_for_coop: alive,
## hatched, not idle), however the hits are timed or thrown:
##  - [method credit_slot] names the slot of a hit: the striker (his club box, his mount's bite), the thrower of a
##    thrown weapon, the BALL itself for a batted hero (not his batter: a lone hero who bats his idle partner into a
##    member has not found a second slot) - and nobody (-1) for a hero who does not count when it lands;
##  - a weapon hit credited to nobody glances off a windowed record ([method accepts_hit]);
##  - a death that would leave the whole group dead without two different counting slots among its deaths is refused:
##    a weapon hit on the last living member glances (the clank and the spark of every glance), and any other death
##    of it - a kill-all, a grenade, a feast's or a mount's bite, a glider dive - leaves it alive
##    ([method refuses_kill]). So one hero kills one member and never the last: the dead one regrows (or merges) when
##    its window closes, and "every member dead" still means "the bond was met" for the keeper doors;
##  - the group seals ([method on_killed]) only with two different slots among its deaths in the window.
## The twin drums use the same credit (objects/drum.gd); the daze is slot-bound by G47. A party of one, single-player
## and versus never come here ([method party_on]).

enum Split { WHOLE, HALF }

## The record these rules belong to.
var enemy: EnemyBase = null
## Its trait (Defs.CoopTrait, never NONE).
var kind: int = Defs.CoopTrait.NONE

## `daze` / `heavy`: ticks left dazed (a `daze` record after a head bounce, a `heavy` one after a Brace Wall): only
## then do hits count (a `daze` record: another slot's than the bouncer's, G47; a `heavy` one: any at all, G57).
var dazed: int = 0
## `bond` / `split`: ticks left of the harmless regrow (intangible, blinking, no AI).
var regrow: int = 0
## `bond` / `split`: Sim.total_ticks of this record's death while its window is open; -1 = none.
var died_tick: int = -1
## `bond` / `split`: the group died within its window: it stays dead until the level resets.
var sealed: bool = false
## `bond` / `split` (R2): the player slot its death in the open window is credited to ([method credit_slot] of its
## killer; -1 = nobody, or not dead). Kept while it lies dead, cleared when it regrows, merges or the level resets.
var kill_slot: int = -1
## `bond` / `split` (R2), statistics only (tools and tests; nothing in the simulation reads it): the hits and deaths
## the slot rule refused on this record since it was spawned.
var slot_refusals: int = 0
## `grab`: the hero it holds (null = none) and its perch (`perch=c,r`, the feet point of that cell).
var held: PlayerBase = null
var perch: Vector2i = Vector2i.ZERO
var has_perch: bool = false
## `grab`: heroes seized since the level started (an archetype notices a carry by it: enemies/snatcher).
var carries: int = 0
## `leech`: the hero on whose back it sits (null = none) and the ticks it has sat there.
var host: PlayerBase = null
var host_ticks: int = 0
## `split`: whole or a half; the other half; true for the half that was spawned (removed again on a merge or reset).
var split: int = Split.WHOLE
var mate: EnemyBase = null
var is_copy: bool = false
## `bond` / `split` / `daze`: the record's cap on its window or daze time in ticks (level parameter `window`; -1 =
## none: the difficulty's value).
var window_cap: int = -1
## `bond` / `split`: the group's count-in on its leader (the first awake, living member): ticks into it (-1 = none).
var count_in: int = -1

## `daze`: hopping away (airborne until it lands); bit per player slot: that hero was striking on the last look.
var _hop: bool = false
var _strikers: int = 0
## `daze` (G47): the player slot whose head bounce dazed it (-1 = none): his own hits glance while it is dazed.
var _dazer_slot: int = -1
## `heavy`: its run before the Brace Wall stopped it (given back when the daze ends).
var _run_xvel: int = 0
## `grab`: where it seized the hero (it flies back there after the drop), flying back, ticks held without a perch,
## true when it switched the held hero's control off itself.
var _home: Vector2i = Vector2i.ZERO
var _returning: bool = false
var _hold_ticks: int = 0
var _took_control: bool = false
## `leech`: its xvel when it latched on (given back when it falls off).
var _latch_xvel: int = 0
## `leech`: ticks before it may latch on again after falling off (EnemyTuning.LEECH_RELATCH_TICKS).
var _relatch_wait: int = 0
## `split`: ticks left of the run apart and its direction; where this half died.
var _run: int = 0
var _run_dir: int = 1
var _death_pos: Vector2i = Vector2i.ZERO
## `split`: the archetype's own speed when it split, given back in the run's direction when the run ends.
var _resume_speed: int = 0
## `bond` / `split` count-in: every member had a hero beside it on the leader's last look.
var _count_ready: bool = false
## Contact made harmless by the trait (holding a hero, riding a host, braced) and the value to give back; the
## tangibility the regrow took away.
var _harmless: bool = false
var _saved_contact: bool = true
var _saved_tangible: bool = true


# =================================================================================================================
# Creation, mode and the bond registry
# =================================================================================================================

## The trait rules of `p_enemy` (its coop_trait and spawn parameters), or null when it has no trait.
static func create(p_enemy: EnemyBase) -> CoopTraits:
	if p_enemy == null or p_enemy.coop_trait <= Defs.CoopTrait.NONE:
		return null
	var traits: CoopTraits = CoopTraits.new()
	traits.enemy = p_enemy
	traits.kind = p_enemy.coop_trait
	traits._read_params(p_enemy.spawn_params)
	return traits


## True while the co-op rules run: a co-op game (Game.mode COOP) with more than one hero in the level.
static func party_on() -> bool:
	var level: LevelBase = Game.level
	return level != null and Game.mode == Defs.GameMode.COOP and level.hero_count() > 1


## The window of the bond and split traits for the current difficulty (PartyTuning.window_ticks).
static func window_ticks() -> int:
	return PartyTuning.window_ticks(Game.difficulty)


## R2 (slot-bound windows): the hero a hit by `source` is credited to in a bond, split or drum window - `source`
## itself when it is a hero (his club box, his mount's bite; a batted BALL is credited to the ball, not to his batter
## as Defs.hitter_slot does for the statistics), the thrower of a thrown weapon (the hero of its `owner_slot`); null
## for anything else. Whether he COUNTS is [method credit_slot]'s question.
static func credit_hero(source: SimEntity) -> PlayerBase:
	if source == null or not is_instance_valid(source):
		return null
	var hero: PlayerBase = source as PlayerBase
	if hero != null:
		return hero
	if source.get_kind() != Defs.Kind.HERO_PROJECTILE or Game.level == null:
		return null
	var owner: Variant = source.get(&"owner_slot")
	return Game.level.get_hero(int(owner)) if owner is int else null


## R2: the player slot a hit by `source` counts for in a bond, split or drum window: [method credit_hero]'s slot while
## that hero COUNTS on this tick (PlayerBase.counts_for_coop: alive, hatched, not idle); -1 = it counts for nobody (no
## hero's hit, or the hit of an idle hero, an egg or a downed hero - his own box, his ball, a weapon he threw before).
static func credit_slot(source: SimEntity) -> int:
	var hero: PlayerBase = credit_hero(source)
	return hero.slot if hero != null and hero.counts_for_coop() else -1


## A record's window or daze time from the difficulty's value `base` and its level parameters `params` (the
## `window=<ticks>` cap of LEVEL_DESIGN.md 15.7.6: the smaller of the two). For tools reading level files (the solo
## search, the validator); the game uses [method group_window] / [method daze_window].
static func capped_window(base: int, params: Dictionary) -> int:
	if params.has("window"):
		return mini(base, maxi(int(params["window"]), 0))
	return base


## The window of this record's bond or split group: the difficulty's value, capped by the smallest `window` of the
## group's members.
func group_window() -> int:
	var window: int = window_ticks()
	for member: EnemyBase in _group():
		var traits: CoopTraits = member.coop_traits()
		if traits != null and traits.window_cap >= 0:
			window = mini(window, traits.window_cap)
	return window


## The daze time of a `daze` record: PartyTuning.daze_ticks(difficulty), capped by its `window`.
func daze_window() -> int:
	var ticks: int = PartyTuning.daze_ticks(Game.difficulty)
	return mini(ticks, window_cap) if window_cap >= 0 else ticks


## Bond registry: the enemy records of bond `bond_name` in registration order (drums of the same name left out).
static func bond_members(level: LevelBase, bond_name: StringName) -> Array[EnemyBase]:
	var members: Array[EnemyBase] = []
	if level == null or bond_name == &"":
		return members
	for entity: SimEntity in level.get_tagged(&"bond", bond_name):
		var member: EnemyBase = entity as EnemyBase
		if member != null and is_instance_valid(member):
			members.append(member)
	return members


## Bond registry: true when the bond has enemy records and every one of them is dead (a bond killed within its window
## stays so until a team wipe; a late one regrows and turns this false again).
static func bond_done(level: LevelBase, bond_name: StringName) -> bool:
	var members: Array[EnemyBase] = bond_members(level, bond_name)
	if members.is_empty():
		return false
	for member: EnemyBase in members:
		if not member.dead:
			return false
	return true


## Keeper doors ([R10], `objects/column trigger=keepers:<name>`): true when the group has enemies and every one of
## them is dead.
static func keepers_done(level: LevelBase, keeper_name: StringName) -> bool:
	if level == null or keeper_name == &"":
		return false
	var found: bool = false
	for entity: SimEntity in level.get_tagged(&"keeper", keeper_name):
		var member: EnemyBase = entity as EnemyBase
		if member == null or not is_instance_valid(member):
			continue
		found = true
		if not member.dead:
			return false
	return found


## True when this record ticks the CONTACT_ENEMIES phase too (EnemyBase._sim_phases).
func needs_contact_phase() -> bool:
	return kind == Defs.CoopTrait.HEAVY or kind == Defs.CoopTrait.GRAB or kind == Defs.CoopTrait.LEECH


## True while the record must not doze: a bond / split window is open, a hero is held or ridden, a regrow runs.
func keeps_awake() -> bool:
	return (died_tick >= 0 and not sealed) or held != null or host != null or regrow > 0 or _returning


## True while this record lies dead in its group's open window: it regrows or merges when the window closes, or
## stays dead when the group seals. A dead record must stay in the level meanwhile (SpawnerEnemy keeps a dead copy
## until then: a half that was freed could neither merge nor hold its mate to the slot rule).
func window_open() -> bool:
	return died_tick >= 0 and not sealed


# =================================================================================================================
# Hits and bounces (EnemyBase.take_hit, accepts_hit_from, on_bounced)
# =================================================================================================================

## True when a hit from `source` passes through without touching it (the leech host's own weapons).
func skips_hit(source: SimEntity) -> bool:
	return host != null and Defs.hitter_slot(source) == host.slot


## May a hit from `source` hurt it now? False = it glances (EnemyBase.accepts_hit_from).
func accepts_hit(source: SimEntity) -> bool:
	if not party_on():
		return true
	match kind:
		Defs.CoopTrait.SHELL:
			return not enemy._hit_from_front(source)
		Defs.CoopTrait.HEAVY:
			# G57 (heavy keepers): hurt ONLY while a Brace Wall of two active heroes has it dazed - then from every
			# side; every other hit glances, its back too, so a lone player (who can run under or hop over it) never
			# wears it down.
			return dazed > 0
		Defs.CoopTrait.DAZE:
			# G47: the daze is slot-bound - only a hero of another slot than the bouncer's hurts it.
			return dazed > 0 and Defs.hitter_slot(source) != _dazer_slot
		Defs.CoopTrait.BOND, Defs.CoopTrait.SPLIT:
			# R2: the windows are slot-bound - nobody's hit and the hit that could not meet the group glance.
			return not _slot_glances(source)
	return true


## R2: true when the slot rule turns a weapon hit by `source` away from this record: it is a windowed record (a named
## bond's member, a split half) and the hit is credited to nobody, or its death by that slot would leave the whole
## group dead without two different counting slots ([method _wasted_kill]).
func _slot_glances(source: SimEntity) -> bool:
	if not _windowed() or sealed:
		return false
	var slot: int = credit_slot(source)
	return slot < 0 or _wasted_kill(slot)


## R2: true when this record's death, credited to player slot `slot` (-1: nobody), would end its group without
## meeting it: every other member that still belongs to the group lies dead in the open window and no two different
## counting slots would stand among the deaths - for a pair: the mate fell to the same hero, or to nobody. False
## while a mate lives (this death only opens the window or leaves it open) and for a record whose mates all left
## without a window (a one-shot that despawned: it dies as a plain enemy, as it did before R2).
func _wasted_kill(slot: int) -> bool:
	var slots: int = (1 << slot) if slot >= 0 else 0
	var open: bool = false
	for member: EnemyBase in _group():
		if member == enemy:
			continue
		if not member.dead:
			return false
		var traits: CoopTraits = member.coop_traits()
		if traits == null or traits.died_tick < 0 or traits.sealed:
			continue
		open = true
		if traits.kill_slot >= 0:
			slots |= 1 << traits.kill_slot
	return open and (slots & (slots - 1)) == 0


## R2 (EnemyBase.kill of every cause, burst_into_items): true when this death must not happen - `killer`'s slot
## ([method credit_slot]; null: nobody's, a grenade) could not meet the group ([method _wasted_kill]): the last
## living member of a bond or split whose mates fell to the same hero or to nobody stays alive through a kill-all, a
## grenade, a feast's or a mount's bite and a glider dive, as its weapon hits glance. Counted in
## [member slot_refusals].
func refuses_kill(killer: SimEntity) -> bool:
	if not _windowed() or sealed or not party_on():
		return false
	if not _wasted_kill(credit_slot(killer)):
		return false
	slot_refusals += 1
	return true


## EnemyBase.take_hit: a hit by `source` has just glanced ([method accepts_hit] or the record's own rule refused it).
## Statistics only: counts the glances the slot rule asks for.
func on_hit_refused(source: SimEntity) -> void:
	if party_on() and _slot_glances(source):
		slot_refusals += 1


## G57 one hit per strike (EnemyBase._repeats_strike, every enemy of a co-op party): the strike instance a weapon hit
## from `source` belongs to, for a hero's melee box (Player: `club_box_active` while his weapon pass tests it) - the
## Sim.total_ticks on which his strike script started: `strike_tick` counts the script's ticks (player-A's Player), so
## Sim.total_ticks - strike_tick is the same on every tick of one swing and new for the next (a held FIRE re-swings from
## strike_tick 0). -1 for every other source, which is an instance of its own by its own rules: a thrown weapon is used
## up by its one hit (ProjectileBase.consume), the batted ball hits an enemy once per flight (the party component), a
## mount's bite once per bite, a head bounce never hurts; a bare PlayerBase (tests) has no strike script.
static func strike_key(source: SimEntity) -> int:
	var hero: PlayerBase = source as PlayerBase
	if hero == null or not hero.club_box_active:
		return -1
	var into: Variant = hero.get(&"strike_tick")
	if into == null:
		return -1
	return Sim.total_ticks - int(into)


## True while it may not die of anything but a weapon hit it accepted: a `heavy` record of a co-op party that no Brace
## Wall has dazed (G57: "damaged ONLY while so dazed") shrugs off a kill-all, a grenade, a feast's or a mount's bite
## and glider dives. Everything else: false (its archetype's deaths).
func refuses_death() -> bool:
	return kind == Defs.CoopTrait.HEAVY and dazed <= 0 and party_on()


## An accepted hit of the hero of player slot `slot` (-1: no hero's) is about to be applied. True = the trait used it
## up without damage (the first hit of a whole `split` record).
func absorbs_hit(slot: int, source: SimEntity) -> bool:
	if not party_on():
		return false
	match kind:
		Defs.CoopTrait.SPLIT:
			if split == Split.WHOLE and not is_copy:
				_split_now(source)
				return true
		Defs.CoopTrait.GRAB:
			if held != null and slot >= 0 and slot != held.slot:
				_release(true)
		Defs.CoopTrait.LEECH:
			if host != null and slot >= 0 and slot != host.slot:
				_drop_host()
	return false


## A hero bounced on its head (the `daze` rule: dazed PartyTuning.daze_ticks, only then can it be hurt - and, G47,
## only by a hero of another slot than this bouncer's: a lone player never kills it, an idle partner never strikes).
func on_bounced(hero: PlayerBase) -> void:
	if kind != Defs.CoopTrait.DAZE or not party_on():
		return
	dazed = daze_window()
	_dazer_slot = hero.slot if hero != null else -1
	_hop = false
	enemy.xvel = 0
	enemy._play(&"dizzy", true)
	_sfx(Sfx.DAZE)


## The record died (EnemyBase.kill, burst_into_items; `killer` as EnemyBase.kill got it, null: nobody): let go of what
## it holds; a `bond` / `split` record opens or completes its group's window. R2: the death is credited to
## [method credit_slot] of `killer`, and the group seals only when its deaths in the window carry two different
## counting slots ([method refuses_kill] has kept every other last death from happening; a record whose mates all left
## without a window - nothing but its own death is open - dies as a plain enemy, as before).
func on_killed(killer: SimEntity = null) -> void:
	_let_go()
	dazed = 0
	_dazer_slot = -1
	_hop = false
	_run = 0
	regrow = 0
	if sealed or not party_on() or not _windowed():
		return
	died_tick = Sim.total_ticks
	kill_slot = credit_slot(killer)
	_death_pos = enemy.sim_pos
	var first: int = died_tick
	var open: int = 0
	var slots: int = 0
	for member: EnemyBase in _group():
		if not member.dead:
			return
		var traits: CoopTraits = member.coop_traits()
		if traits != null and traits.died_tick >= 0:
			first = mini(first, traits.died_tick)
			open += 1
			if traits.kill_slot >= 0:
				slots |= 1 << traits.kill_slot
	if open >= 2 and (slots & (slots - 1)) == 0:
		return  # R2: one slot (or nobody) for every death - not met; the dead regrow when the window closes
	if died_tick - first < group_window():
		for member: EnemyBase in _group():
			var traits: CoopTraits = member.coop_traits()
			if traits != null:
				traits.sealed = true
				traits.died_tick = -1
				member._doze_note()
				member._on_coop_sealed()


## The level was reset (team wipe, EnemyBase._on_level_reset): everything back to the level-file state.
func on_reset() -> void:
	_let_go()
	_set_harmless(false)
	if regrow > 0:
		enemy.tangible = _saved_tangible
	dazed = 0
	_dazer_slot = -1
	regrow = 0
	died_tick = -1
	kill_slot = -1
	sealed = false
	split = Split.WHOLE
	mate = null
	_hop = false
	_strikers = 0
	_returning = false
	_relatch_wait = 0
	_run = 0
	count_in = -1
	_count_ready = false


## The record went to sleep (left behind, or killed): it lets go of a held hero or a host.
func on_sleep() -> void:
	_let_go()
	dazed = 0
	_hop = false
	_returning = false
	_run = 0
	if regrow > 0:
		regrow = 0
		enemy.tangible = _saved_tangible


# =================================================================================================================
# Ticks
# =================================================================================================================

## ENEMIES phase, awake and alive, before the archetype's AI. True = the trait ran this tick (no `_ai_tick()`).
func pre_ai() -> bool:
	if not party_on():
		# A party of one: the plain archetype (whatever a party left behind is let go).
		_let_go()
		_returning = false
		if dazed > 0:
			dazed = 0
			_set_harmless(false)
		_hop = false
		return false
	if regrow > 0:
		regrow -= 1
		if regrow == 0:
			enemy.tangible = _saved_tangible
		enemy._play(&"idle")
		return true
	match kind:
		Defs.CoopTrait.DAZE:
			return _daze_pre()
		Defs.CoopTrait.HEAVY:
			return _heavy_pre()
		Defs.CoopTrait.GRAB:
			return _grab_pre()
		Defs.CoopTrait.LEECH:
			return _leech_pre()
		Defs.CoopTrait.SPLIT:
			return _split_pre()
	return false


## ENEMIES phase, after the archetype's AI ran.
func post_ai() -> void:
	if not party_on():
		return
	match kind:
		Defs.CoopTrait.SHELL:
			# The shield faces the nearer hero who COUNTS every tick (not the sticky target; G33: never a dozing
			# partner - an idle body is no bait); nobody counts: it keeps its facing.
			var hero: PlayerBase = Game.level.nearest_coop_hero(enemy)
			if hero != null:
				enemy.facing = enemy._dir_to(hero)
		Defs.CoopTrait.HEAVY:
			_brace_test()
		Defs.CoopTrait.BOND, Defs.CoopTrait.SPLIT:
			_count_in_step()


## CONTACT_ENEMIES phase, awake and alive (heavy, grab, leech), after every hero moved and before their contact pass.
func contact_tick() -> void:
	if not party_on() or not enemy.awake:
		return
	match kind:
		Defs.CoopTrait.HEAVY:
			_brace_test()
		Defs.CoopTrait.GRAB:
			if held != null:
				_place_held()
			elif not _returning and regrow == 0:
				_try_seize()
		Defs.CoopTrait.LEECH:
			if host != null:
				_place_on_host()
			elif regrow == 0 and _relatch_wait == 0:
				_try_latch()


## ENEMIES phase while the record is dead or its corpse flies: the open window of a bond or split group.
func dead_tick() -> void:
	if died_tick < 0 or sealed:
		return
	if not party_on():
		# The party fell apart: the record stays dead as its archetype would.
		sealed = true
		died_tick = -1
		enemy._doze_note()
		enemy._on_coop_sealed()
		return
	if Sim.total_ticks - _group_first() < group_window():
		return
	if kind == Defs.CoopTrait.SPLIT:
		_merge()
		return
	for member: EnemyBase in _group():
		var traits: CoopTraits = member.coop_traits()
		if member.dead and traits != null and not traits.sealed and traits.died_tick >= 0:
			traits._regrow_at(member.spawn_pos)


## `lone` (Expert, PartyTuning.lone_trait_on): null while the heroes who COUNT keep together (within
## PartyTuning.LONE_KEEP_AWAY_PX of each other on both axes: it keeps away), else the straggler - the counting hero
## farther from the view centre, ties to the higher slot [R9]. With one counting hero: him (G33: a dozing partner
## parked beside a lone player is no protection).
func lone_target() -> PlayerBase:
	var level: LevelBase = Game.level
	if level == null:
		return null
	var hatched: Array[PlayerBase] = []
	for hero: PlayerBase in level.contact_order():
		if hero.counts_for_coop():
			hatched.append(hero)
	if hatched.size() <= 1:
		return hatched[0] if hatched.size() == 1 else null
	if heroes_together(hatched):
		return null
	var centre: Vector2i = level.get_view_rect().get_center()
	var best: PlayerBase = null
	var best_distance: int = -1
	for hero: PlayerBase in hatched:
		var distance: int = absi(hero.sim_pos.x - centre.x) + absi(hero.sim_pos.y - centre.y)
		if distance >= best_distance:
			best = hero
			best_distance = distance
	return best


## True when every two of `heroes` stand within PartyTuning.LONE_KEEP_AWAY_PX of each other on both axes.
static func heroes_together(heroes: Array[PlayerBase]) -> bool:
	for i: int in heroes.size():
		for j: int in range(i + 1, heroes.size()):
			if absi(heroes[i].sim_pos.x - heroes[j].sim_pos.x) > PartyTuning.LONE_KEEP_AWAY_PX \
					or absi(heroes[i].sim_pos.y - heroes[j].sim_pos.y) > PartyTuning.LONE_KEEP_AWAY_PX:
				return false
	return true


# =================================================================================================================
# daze and heavy
# =================================================================================================================

func _daze_pre() -> bool:
	var striker: PlayerBase = _note_strikers()
	if dazed > 0:
		dazed -= 1
		_stand_still(&"dizzy")
		return true
	if _hop:
		if enemy._ground_step(false, false):
			_hop = false
			enemy.xvel = 0
		enemy._play(&"air")
		return true
	if not enemy._grounded:
		return false
	if striker != null:
		_start_hop(-enemy._dir_to(striker) * EnemyTuning.DAZE_HOP_XVEL, EnemyTuning.DAZE_HOP_YVEL)
		return true
	if _throw_coming():
		_start_hop(0, EnemyTuning.DAZE_THROW_HOP_YVEL)
		return true
	return false


## The first hatched hero within the alert distance whose strike started since the last look (attack_gate rising);
## remembers who strikes now.
func _note_strikers() -> PlayerBase:
	var found: PlayerBase = null
	var bits: int = 0
	for hero: PlayerBase in Game.level.contact_order():
		if not hero.is_party_targetable() or not hero.is_striking():
			continue
		var bit: int = 1 << hero.slot
		bits |= bit
		if found == null and (_strikers & bit) == 0 \
				and absi(hero.sim_pos.x - enemy.sim_pos.x) <= PartyTuning.DAZE_ALERT_PX \
				and absi(hero.sim_pos.y - enemy.sim_pos.y) <= EnemyTuning.DAZE_ALERT_DY:
			found = hero
	_strikers = bits
	return found


## True when a thrown weapon flies at it within the alert distance.
func _throw_coming() -> bool:
	for entity: SimEntity in Game.level.get_kind(Defs.Kind.HERO_PROJECTILE):
		var shot: ProjectileBase = entity as ProjectileBase
		if shot == null or shot.spent or shot.xvel == 0:
			continue
		var dx: int = enemy.sim_pos.x - shot.sim_pos.x
		if signi(dx) == signi(shot.xvel) and absi(dx) <= PartyTuning.DAZE_ALERT_PX \
				and absi(shot.sim_pos.y - enemy.sim_pos.y) <= EnemyTuning.DAZE_ALERT_DY:
			return true
	return false


func _start_hop(p_xvel: int, p_yvel: int) -> void:
	_hop = true
	enemy.xvel = p_xvel
	enemy.yvel = p_yvel
	enemy._grounded = false
	if p_xvel != 0:
		enemy.facing = -signi(p_xvel)
	enemy._play(&"air", true)


func _heavy_pre() -> bool:
	if dazed <= 0:
		return false
	dazed -= 1
	_stand_still(&"dizzy")
	if dazed == 0:
		_set_harmless(false)
		enemy.xvel = _run_xvel
	return true


## Brace Wall (PHYSICS.md C.10): an active hero (G33: not idle) in the crouch state overlaps it while his active
## partner crouches too, both grounded and within PartyTuning.BRACE_GAP_PX: it stops dead and is dazed
## PartyTuning.BRACE_DAZE_TICKS with its head open - the only time it can be hurt; neither hero is touched (its contact
## is harmless while dazed). A lone croucher is trampled as usual.
func _brace_test() -> void:
	if dazed > 0 or not enemy.is_targetable():
		return
	var heroes: Array[PlayerBase] = Game.level.contact_order()
	for hero: PlayerBase in heroes:
		if not hero.counts_for_coop() or not hero.is_crouching() or not Overlap.body(hero, enemy, hero):
			continue
		for partner: PlayerBase in heroes:
			if partner != hero and hero.braces_with(partner):
				_brace()
				return


## EnemyBase.brace_stop: a braced pair touches this record (the hero's contact pass asks). A `heavy` record of a
## co-op party stops dead and is dazed, or already is: true. Everything else: false.
func brace_stop() -> bool:
	if kind != Defs.CoopTrait.HEAVY or not party_on():
		return false
	if dazed <= 0:
		_brace()
	return true


func _brace() -> void:
	if enemy.xvel != 0:
		_run_xvel = enemy.xvel
	enemy.xvel = 0
	dazed = PartyTuning.BRACE_DAZE_TICKS
	_set_harmless(true)
	enemy._play(&"dizzy", true)
	_sfx(Sfx.BRACE)


func _stand_still(role: StringName) -> void:
	enemy.xvel = 0
	enemy._ground_step(false, false)
	enemy._play(role)


# =================================================================================================================
# grab
# =================================================================================================================

func _grab_pre() -> bool:
	if held != null:
		if not _holdable(held):
			_release(false)
			return true
		_hold_ticks += 1
		if has_perch:
			enemy.sim_pos += _step_towards(enemy.sim_pos, perch, PartyTuning.GRAB_REEL_PX)
			if enemy.sim_pos == perch:
				_release(false)
		elif _hold_ticks >= PartyTuning.LEECH_FALL_OFF_TICKS:
			_release(false)
		enemy._play(&"fly")
		return true
	if _returning:
		enemy.sim_pos += _step_towards(enemy.sim_pos, _home, EnemyTuning.GRAB_RETURN_SPEED)
		_returning = enemy.sim_pos != _home
		enemy._play(&"fly")
		return true
	return false


## A hatched hero who touches it from below (his feet below its feet point) or whom it comes down on is seized.
func _try_seize() -> void:
	if not enemy.is_targetable():
		return
	for hero: PlayerBase in Game.level.contact_order():
		# Helper mode (PHYSICS.md C.12): enemy contacts never harm the helper - a seize is that contact.
		if not hero.is_party_targetable() or hero.is_immune() or hero.is_feasting() or hero.is_helper():
			continue
		if not Overlap.body(hero, enemy, hero):
			continue
		if hero.sim_pos.y > enemy.sim_pos.y or enemy.yvel > 0:
			_seize(hero)
			return


func _seize(hero: PlayerBase) -> void:
	held = hero
	carries += 1
	_hold_ticks = 0
	_home = enemy.sim_pos
	_returning = false
	_took_control = hero.control_enabled
	if _took_control:
		hero.set_control_enabled(false)
	enemy.xvel = 0
	enemy.yvel = 0
	_set_harmless(true)
	_place_held()
	Game.level.notify_hero_teleported(hero)
	Audio.play_sfx(Sfx.ENEMY_VOICE)


## The held hero hangs under it: no motion of his own, no strike.
func _place_held() -> void:
	if not _holdable(held):
		_release(false)
		return
	held.sim_pos = enemy.sim_pos + Vector2i(0, EnemyTuning.GRAB_HANG_DY)
	held.xvel = 0
	held.yvel = 0
	held.attack_gate = false
	held.club_box_active = false


## Let the held hero go: dropped at the perch (or after the hold ran out), or freed by his partner's hit (he falls with
## EnemyTuning.GRAB_FREE_SHIELD_TICKS of immunity, the hatch shield of PlayerBase).
func _release(by_partner: bool) -> void:
	var hero: PlayerBase = held
	held = null
	_hold_ticks = 0
	_set_harmless(false)
	_returning = not enemy.dead and enemy.awake
	if hero == null or not is_instance_valid(hero):
		_took_control = false
		return
	if _took_control and not hero.dead and not hero.is_down():
		hero.set_control_enabled(true)
	_took_control = false
	if by_partner and not hero.dead and not hero.is_down():
		hero.shield = maxi(hero.shield, EnemyTuning.GRAB_FREE_SHIELD_TICKS)


# =================================================================================================================
# leech
# =================================================================================================================

func _leech_pre() -> bool:
	if host == null:
		if _relatch_wait > 0:
			_relatch_wait -= 1
		return false
	if not _holdable(host) or host.is_helper():
		_drop_host()  # gone down, or Helper mode switched on for him meanwhile
		return true
	host_ticks += 1
	if host_ticks % PartyTuning.LEECH_DRAIN_TICKS == 0 and host.run.lose_bone():
		# Drained empty: he goes down (the co-op death, PHYSICS.md C.12) and it falls off.
		host.kill(&"enemy")
		_drop_host()
		return true
	if host_ticks >= PartyTuning.LEECH_FALL_OFF_TICKS:
		_drop_host()
		return true
	_place_on_host()
	enemy._play(&"front")  # the Leech sheet's latched pose (falls back to idle on other sheets)
	return true


## A hatched hero who touches it (except by landing on its head) gets it on his back instead of being hurt.
func _try_latch() -> void:
	if not enemy.is_targetable():
		return
	for hero: PlayerBase in Game.level.contact_order():
		# Helper mode (PHYSICS.md C.12): no leech on the helper's back (its drain costs bones and can kill).
		if not hero.is_party_targetable() or hero.is_immune() or hero.is_feasting() or hero.is_helper():
			continue
		if not Overlap.body(hero, enemy, hero) or (Overlap.stomp and hero.yvel >= 0):
			continue
		host = hero
		host_ticks = 0
		_latch_xvel = enemy.xvel
		enemy.xvel = 0
		enemy.yvel = 0
		_set_harmless(true)
		_place_on_host()
		Audio.play_sfx(Sfx.ENEMY_VOICE)
		return


func _place_on_host() -> void:
	if not _holdable(host):
		_drop_host()
		return
	enemy.facing = host.facing
	enemy.sim_pos = host.sim_pos + Vector2i(-host.facing * EnemyTuning.LEECH_BACK_DX, -EnemyTuning.LEECH_BACK_DY)


## It falls off its host (clubbed off by the partner, after PartyTuning.LEECH_FALL_OFF_TICKS, or the host went down).
func _drop_host() -> void:
	host = null
	host_ticks = 0
	_relatch_wait = EnemyTuning.LEECH_RELATCH_TICKS
	_set_harmless(false)
	enemy.xvel = _latch_xvel
	enemy.yvel = 0
	enemy._grounded = false


# =================================================================================================================
# bond and split: the windows
# =================================================================================================================

## True for a trait whose deaths open a window (a bond needs its `bond=` name).
func _windowed() -> bool:
	if kind == Defs.CoopTrait.BOND:
		return enemy.bond != &""
	return kind == Defs.CoopTrait.SPLIT and split == Split.HALF


## The records that share this record's window: its bond (registry), or the two halves of a split.
func _group() -> Array[EnemyBase]:
	if kind == Defs.CoopTrait.BOND:
		return bond_members(Game.level, enemy.bond)
	var halves: Array[EnemyBase] = [enemy]
	if mate != null and is_instance_valid(mate):
		halves.append(mate)
	return halves


## The tick the group's open window started (the earliest death of a member still waiting).
func _group_first() -> int:
	var first: int = died_tick
	for member: EnemyBase in _group():
		var traits: CoopTraits = member.coop_traits()
		if member.dead and traits != null and traits.died_tick >= 0:
			first = mini(first, traits.died_tick)
	return first


## Bond: back alive at `pos` (its anchor) with full hit points, harmless for EnemyTuning.REGROW_TICKS.
func _regrow_at(pos: Vector2i) -> void:
	died_tick = -1
	kill_slot = -1
	enemy._coop_revive(pos)
	if enemy.awake:
		regrow = EnemyTuning.REGROW_TICKS
		_saved_tangible = enemy.tangible
		enemy.tangible = false
		enemy.flash = EnemyTuning.REGROW_TICKS


func _split_now(source: SimEntity) -> void:
	split = Split.HALF
	enemy.hp = 0
	var away: int = 1 if source == null or source.sim_pos.x <= enemy.sim_pos.x else -1
	_run_dir = away
	_run = EnemyTuning.SPLIT_RUN_TICKS
	_resume_speed = absi(enemy.xvel)
	enemy.flash = EnemyTuning.FLASH_TICKS
	Audio.play_sfx(Sfx.ENEMY_HURT)
	var copy: EnemyBase = enemy._coop_spawn_copy({"split_half": true, "hp": 0})
	var other: CoopTraits = copy.coop_traits() if copy != null else null
	if other == null:
		return
	other.split = Split.HALF
	other.is_copy = true
	other.mate = enemy
	other._run_dir = -away
	other._run = EnemyTuning.SPLIT_RUN_TICKS
	other._resume_speed = _resume_speed
	other.window_cap = window_cap
	mate = copy


func _split_pre() -> bool:
	if split == Split.HALF and not is_copy and _mate_left():
		# The other half left without a window (it despawned far away): whole again.
		if mate != null and is_instance_valid(mate):
			mate._coop_remove()
		_become_whole()
	if _run <= 0:
		return false
	var age: int = EnemyTuning.SPLIT_RUN_TICKS - _run
	_run -= 1
	enemy.xvel = EnemyTuning.SPLIT_RUN_XVEL * _run_dir
	enemy.facing = _run_dir
	enemy._ground_step(false, false)
	if enemy.xvel != 0:
		_run_dir = signi(enemy.xvel)
	var squash: bool = age < EnemyTuning.SPLIT_SQUASH_TICKS and enemy._skin != null \
			and enemy._skin.has_anim(&"squash")
	enemy._play(&"squash" if squash else &"walk")
	if _run == 0:
		# The run is over: the archetype goes on with its own speed, now in the run's direction.
		enemy.xvel = _resume_speed * _run_dir
	return true


## Split: the window closed with one half alive - the dead half regrows next to it and they merge into the whole (the
## record, full hit points); the spawned half is removed. Both dead too late: the whole regrows where the record died.
func _merge() -> void:
	var record: EnemyBase = mate if is_copy else enemy
	var copy: EnemyBase = enemy if is_copy else mate
	if record == null or not is_instance_valid(record):
		return
	var record_traits: CoopTraits = record.coop_traits()
	if record.dead:
		var pos: Vector2i = record_traits._death_pos
		if copy != null and is_instance_valid(copy) and not copy.dead:
			pos = copy.sim_pos
		record._coop_revive(pos)
	record_traits._become_whole()
	if copy != null and is_instance_valid(copy):
		copy._coop_remove()


## True when the other half is gone without dying in a window (it never existed, or it despawned).
func _mate_left() -> bool:
	if mate == null or not is_instance_valid(mate):
		return true
	var other: CoopTraits = mate.coop_traits()
	return mate.dead and other != null and other.died_tick < 0 and not other.sealed


func _become_whole() -> void:
	split = Split.WHOLE
	mate = null
	died_tick = -1
	kill_slot = -1
	_run = 0
	enemy.hp = enemy.max_hp
	enemy.flash = EnemyTuning.FLASH_TICKS


# =================================================================================================================
# bond and split: the count-in (presentation)
# =================================================================================================================

## The leader's count-in, once per tick (post_ai of every member; only the leader acts): three blips while every
## member is alive and has a hatched hero beside it (at least two different heroes), then "go"; it starts again only
## after the heroes left and came back.
func _count_in_step() -> void:
	var members: Array[EnemyBase] = _count_group()
	if members.size() < 2 or _count_leader(members) != enemy:
		return
	var ready: bool = not sealed and _count_ready_now(members)
	if not ready:
		count_in = -1
		_count_ready = false
		return
	if not _count_ready:
		_count_ready = true
		count_in = 0
	if count_in < 0:
		return
	if count_in % PartyTuning.COUNT_IN_SPACING_TICKS == 0:
		if count_in / PartyTuning.COUNT_IN_SPACING_TICKS < PartyTuning.COUNT_IN_BEEPS:
			_sfx(Sfx.COUNT_IN)
		else:
			_sfx(Sfx.DRUM)  # "go": the beat the twin drums use for it
			count_in = -1
			return
	count_in += 1


## The group in a fixed order for every member: a bond's registry, or a split's record before its spawned half.
func _count_group() -> Array[EnemyBase]:
	if kind == Defs.CoopTrait.BOND:
		return bond_members(Game.level, enemy.bond)
	var halves: Array[EnemyBase] = []
	if split == Split.HALF and mate != null and is_instance_valid(mate):
		halves.append(mate if is_copy else enemy)
		halves.append(enemy if is_copy else mate)
	return halves


## The member that runs the group's count-in: the first awake, living one.
static func _count_leader(members: Array[EnemyBase]) -> EnemyBase:
	for member: EnemyBase in members:
		if member.awake and not member.dead:
			return member
	return null


## True when every member is alive and awake with a hero who COUNTS (G33: not idle) within
## EnemyTuning.COUNT_IN_REACH_PX, and those heroes are not all the same one.
static func _count_ready_now(members: Array[EnemyBase]) -> bool:
	var used: int = 0
	var heroes: Array[PlayerBase] = Game.level.contact_order()
	for member: EnemyBase in members:
		if member.dead or not member.awake:
			return false
		var near: int = 0
		for hero: PlayerBase in heroes:
			if hero.counts_for_coop() \
					and absi(hero.sim_pos.x - member.sim_pos.x) <= EnemyTuning.COUNT_IN_REACH_PX \
					and absi(hero.sim_pos.y - member.sim_pos.y) <= EnemyTuning.COUNT_IN_REACH_PX:
				near |= 1 << hero.slot
		if near == 0:
			return false
		used |= near
	return (used & (used - 1)) != 0


# =================================================================================================================
# Internals
# =================================================================================================================

func _read_params(params: Dictionary) -> void:
	if params.has("perch"):
		var cells: PackedInt32Array = LevelText.to_int_list(params["perch"])
		if cells.size() == 2:
			perch = LevelText.cell_to_feet(cells[0], cells[1])
			has_perch = true
	if params.has("split_half"):
		split = Split.HALF
		is_copy = true
	if params.has("window"):
		window_cap = maxi(int(params["window"]), 0)


## Let go of a held hero or a host (no shield).
func _let_go() -> void:
	if held != null:
		_release(false)
	if host != null:
		_drop_host()


func _holdable(hero: PlayerBase) -> bool:
	return hero != null and is_instance_valid(hero) and not hero.dead and not hero.is_down()


## Contact made harmless (true) or given back (false).
func _set_harmless(on: bool) -> void:
	if on == _harmless:
		return
	_harmless = on
	if on:
		_saved_contact = enemy.contact_hurts
		enemy.contact_hurts = false
	else:
		enemy.contact_hurts = _saved_contact


## One step of at most `speed` px per axis from `from` towards `to`.
static func _step_towards(from: Vector2i, to: Vector2i, speed: int) -> Vector2i:
	return Vector2i(clampi(to.x - from.x, -speed, speed), clampi(to.y - from.y, -speed, speed))


## Play a 2.0 effect name once AudioTable has its row (core-A's batches; Audio.play_sfx reports unknown names).
static func _sfx(event: StringName) -> void:
	if AudioTable.SFX.has(event):
		Audio.play_sfx(event)

class_name HeroBelt
extends RefCounted
## The hero's weapon belt and the Swap input (docs/spec/PHYSICS.md C.1, C.2; DESIGN.md C.1): hand and belt, the
## edge-triggered Swap, the 8-tick lock-out, the fresh-club rule at a stage start, the pick-up rule.
##
## Owner: player-B (docs/expansion/PLAN.md 4.1). A component of [Player], created with him; the calls below are the
## hooks of PLAN.md P0.8 and are made only while [member active] is true. Book I solo never switches it on (meta
## `belt = carry`: Swap is ignored, the 1.0 single weapon), so a single-player Book I hero never runs any of it.
##
## Hook order inside Player._hero_update (PLAYER phase, step 8): after the input is read (8b) and after the party and
## mount components had their turn, [method update] runs once (it never takes the update over); the timers of 8i run
## [method tick_timers]. The gunner's seat of a mount runs [method update] from HeroMount (the hero's own hook is
## skipped while the mount component takes the update). The run state lives in `hero.run` (PlayerRun: weapon = the
## hand, belt, swap_belt(), take_fresh_club()); nothing in the simulation but Swap reads the belt (PHYSICS.md C.2
## rule 5: belt invariance) - the HUD reads it for display only.
##
## Other modules: an `items/weapon` pick-up gives its weapon with [method give_weapon] (both belt rules); a versus
## crate special goes onto the belt with `give_weapon(hero, weapon, true)`.

const FX_SWAP: StringName = &"fx/star_puff"
## The swap puff is drawn this far above the feet point (about the hands).
const FX_SWAP_DY: int = -24

## The hero this component belongs to.
var hero: Player = null
## True while the hooks run: the level's belt rule is `fresh` (Book II, every co-op file), or the level is a versus
## arena. Default false: the 1.0 hero (`belt = carry`) never swaps.
var active: bool = false
## Ticks before the next Swap is accepted (PHYSICS.md C.2 rule 2: Tuning.SWAP_LOCKOUT_TICKS after a swap). Counted
## down in step 8i ([method tick_timers]).
var swap_lock: int = 0
## Sim.total_ticks of the last accepted swap (-1 = none in this level); cosmetic and tests.
var swapped_on_tick: int = -1


func _init(p_hero: Player) -> void:
	hero = p_hero


## The hero entered a level (Player._ready): switch on for a `fresh` level (the level's resolved `belt` meta, or the
## default of its book and kind) and for a versus arena; a `fresh` level applies the fresh-club rule at once (C.2
## rule 4: this is a stage start - the hero is created once per level; deaths, hatches and team wipes respawn him).
func setup(level: LevelBase) -> void:
	swap_lock = 0
	swapped_on_tick = -1
	var rule: String = belt_rule_of(level)
	var arena: bool = level != null and str(level.meta.get("kind", "")) == LevelText.KIND_ARENA
	active = rule == LevelText.BELT_FRESH or arena or Game.mode == Defs.GameMode.VERSUS
	if rule == LevelText.BELT_FRESH and not arena and Game.mode != Defs.GameMode.VERSUS:
		hero.run.take_fresh_club()


## PLAYER phase, after 8b: read this tick's Swap edge from the hero's own flags (PHYSICS.md C.1) and swap hand and
## belt (C.2 rule 2). Never takes the hero's update over: returns false.
func update(level: LevelBase) -> bool:
	var flags: int = hero._raw_flags
	if not swap_pressed(flags):
		return false
	# Down + Swap is the curl in co-op and versus (C.1, C.11: the party component's), never a swap there.
	if (flags & Defs.IN_DOWN) != 0 and hero.hero_party.active:
		return false
	try_swap(level)
	return false


## True when Swap went from released to held on this tick: `flags` are the hero's flags of this tick, the previous
## tick's are his slot's sampled flags (GameInput.get_prev_flags; PHYSICS.md C.1, the only edge-triggered input).
func swap_pressed(flags: int) -> bool:
	if (flags & Defs.IN_SWAP) == 0:
		return false
	return (GameInput.get_prev_flags(hero.slot) & Defs.IN_SWAP) == 0


## Swap hand and belt now if the rules allow it (C.2 rule 2): a special owned (belt not empty), no strike running
## (attack_gate), the lock-out at 0, not hurt-stunned, curled, a ball, an egg or dead. A refused press is dropped (not
## buffered). Touches nothing but hand, belt and swap_lock (no velocity, state or other timer). Returns true when it
## swapped.
func try_swap(level: LevelBase = null) -> bool:
	if not can_swap():
		return false
	if not hero.run.swap_belt():
		return false
	swap_lock = Tuning.SWAP_LOCKOUT_TICKS
	swapped_on_tick = Sim.total_ticks
	_play_cue(Sfx.SWAP)
	var where: LevelBase = level if level != null else Game.level
	if where != null and Spawner.exists(FX_SWAP):
		where.spawn_fx(FX_SWAP, hero.sim_pos + Vector2i(0, FX_SWAP_DY))
	return true


## True when a Swap pressed now would be accepted (see [method try_swap]).
func can_swap() -> bool:
	if hero.run.belt == PlayerRun.BELT_EMPTY or swap_lock > 0 or hero.attack_gate:
		return false
	if hero.dead or hero.down or hero.curl != PlayerBase.CURL_NONE:
		return false
	return hero.hit_timer < hero_stun_min(hero)


## The hurt-stun threshold of this mode: hit_timer at or above it is the hurt state (PHYSICS.md 10.1; versus C.14).
static func stun_min() -> int:
	return VersusTuning.STUN_HIT_TIMER_MIN if Game.mode == Defs.GameMode.VERSUS else Tuning.HIT_STUN_MIN


## The hurt-stun threshold `hero`'s own update uses this tick (player-A's Player._stun_min when it has one, else
## [method stun_min]).
static func hero_stun_min(target: PlayerBase) -> int:
	var own: Variant = target.get(&"_stun_min") if target != null else null
	return int(own) if own is int else stun_min()


## Step 8i: count the swap lock-out down.
func tick_timers() -> void:
	if swap_lock > 0:
		swap_lock -= 1


## The hero was hurt; true = the belt took the hit instead of the 1.0 hurt (never: hand and belt survive a hurt).
func on_hurt(_source: SimEntity, _kind: int) -> bool:
	return false


## The hero respawned (Player.respawn_at): hand and belt are kept (C.2 rule 4); the lock-out is cleared.
func on_respawn() -> void:
	swap_lock = 0


# =================================================================================================================
# Rules other modules call
# =================================================================================================================

## The belt rule of a level (LevelText.BELT_FRESH / BELT_CARRY): its resolved `belt` meta (Level.meta holds it with
## the difficulty variant applied), else the default of its book and kind. A level without meta (a bare test level)
## is `carry`.
static func belt_rule_of(level: LevelBase) -> String:
	if level == null:
		return LevelText.BELT_CARRY
	if level.meta.has("belt"):
		return str(level.meta["belt"])
	return LevelText.meta_belt(level.meta, Game.difficulty)


## Give `hero` the weapon of an `items/weapon` pick-up or a versus crate (PHYSICS.md C.2 rule 1). With his belt
## active: a special goes into the hand and the club onto the belt (an owned special is gone, no item spawns); the
## club while a special is in the hand exchanges them (with the club in the hand nothing changes); `to_belt` (a versus
## crate, C.2 rule 6) puts a special onto the belt instead and keeps the hand. Without the belt (Book I solo, `carry`):
## the 1.0 rule, the weapon replaces the one in the hand. Works for a bare PlayerBase too (the 1.0 rule).
static func give_weapon(target: PlayerBase, weapon: int, to_belt: bool = false) -> void:
	if target == null:
		return
	var run: PlayerRun = target.run
	var belt: HeroBelt = null
	if target is Player:
		belt = (target as Player).hero_belt
	if belt == null or not belt.active:
		run.set_weapon(weapon)
		return
	if weapon == Defs.Weapon.CLUB:
		if run.weapon != Defs.Weapon.CLUB:
			run.swap_belt()
		return
	if to_belt:
		if run.weapon == Defs.Weapon.CLUB:
			run.set_belt(weapon)
		else:
			# The special in the hand is replaced by the new one; the club stays on the belt.
			run.set_weapon(weapon)
		return
	if run.weapon == Defs.Weapon.CLUB:
		run.set_weapon(weapon)
		run.set_belt(Defs.Weapon.CLUB)
	else:
		run.set_weapon(weapon)
		if run.belt != Defs.Weapon.CLUB:
			run.set_belt(Defs.Weapon.CLUB)


# =================================================================================================================
# Helpers
# =================================================================================================================

## Play a 2.0 cue only once its AudioTable row exists (core-A adds the rows; Audio.play_sfx of a name without a row is
## an error).
static func _play_cue(event: StringName) -> void:
	if AudioTable.SFX.has(event):
		Audio.play_sfx(event)

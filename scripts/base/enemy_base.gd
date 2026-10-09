class_name EnemyBase
extends SimEntity
## Shared rules of every enemy (GAMEPLAY.md 5.1, 12.2): slot activation, hit points versus weapon power, flash and
## knock-back, death arc, bone burst, head-bounce counter, stolen heart, feast food swap, Expert-only flag, ground
## physics, skins and tick-driven animation.
##
## CONTRACT FILE (docs/ARCHITECTURE.md 3.13). Owner: enemies (bodies may be replaced; public signatures frozen).
## Archetype scripts extend this class and implement `_ai_tick()`. The hero's weapon pass and contact pass call
## the public methods below; they never look inside an archetype.
##
## Life cycle of a record: ASLEEP at its anchor (`spawn_pos`, hidden, no slot) -> AWAKE (one of the
## Tuning.MAX_ACTIVE_ENEMIES slots, `_ai_tick()` runs) -> back to sleep when it is left behind, or DEAD: thrown
## off the screen in an arc (or eaten, or burst into bones / bonus items) and gone until the level resets after the
## hero's death. A record that went to sleep wakes again only after its anchor was out of view once, so it never
## pops into existence in front of the player.
## Hooks for archetypes (all optional): `_default_skin()`, `_on_wake()`, `_on_reset()`, `_on_gone()`,
## `_asleep_tick()`, `_should_wake()`, `_should_sleep()`; 2.0 (PLAN.md P0.8): `accepts_hit_from()`, `_on_hit_by()`,
## `_on_hit_refused()`, `_choose_target()`, with the fields `last_hit_slot`, `last_hit_tick`, `coop_trait`, `bond`,
## `keeper`. Their defaults are the 1.0 behaviour.
## 2.0 co-op (PLAN.md P1.8): a record with a trait carries a [CoopTraits] ([method coop_traits]); this class calls it
## from its own body (take_hit, on_bounced, kill, the ENEMIES / CONTACT_ENEMIES ticks, dozing, targeting), so every
## archetype gets the trait rules. A party (LevelBase.hero_count() > 1) targets the nearest hatched hero, sticky for
## PartyTuning.TARGET_HOLD_TICKS (GAMEPLAY.md 13.9.4). A record without a trait in a party of one runs exactly the
## 1.0 code: every 2.0 branch below is behind `_traits != null` or `hero_count() > 1`.
## 2.0 phase 2 (PLAN.md P2.1): the co-op Shaman's bone shield ([method wear_bone_shield], [method bone_shielded]: every
## hit glances while a Shaman stands near; only a co-op party's Shaman ever sets it) and the hook
## [method _on_coop_copy] for the half a `split` record spawns.

## Emitted once when the enemy dies.
signal died(enemy: EnemyBase, cause: StringName)

## Food sheet the feast swap draws from (ASSET_MANIFEST.md 7): 8 x 6 cells of 32 art px, pivot bottom-centre.
const FEAST_TEXTURE_PATH: String = "res://assets/sprites/items/food.png"
const FEAST_COLUMNS: int = 8
const FEAST_ROWS: int = 6
const FEAST_OFFSET: Vector2 = Vector2(-16.0, -32.0)
## Over-bright modulate of the hit flash (no per-entity material, ARCHITECTURE.md 11).
const FLASH_COLOR: Color = Color(3.0, 3.0, 3.0, 1.0)
const FX_HIT: StringName = &"fx/hit_stars"
const FX_POOF: StringName = &"fx/poof"
const FX_SPLASH: StringName = &"fx/splash"
const ITEM_BONE: StringName = &"items/bone"
const ITEM_RANDOM: StringName = &"items/random_bonus"
## "No floor here" result of the floor search (far outside any level).
const NO_FLOOR: int = -1073741824

## Hit points at spawn (level parameter `hp`). A weapon hit subtracts its power; the enemy dies below zero.
var max_hp: int = 25
## Current hit points.
var hp: int = 25
## Index into Tuning.SCORE_LADDER (level parameter `score`, 0..11 = 100 .. 8 000 points).
var score_index: int = 0
## Sprite sheet name without path and extension (level parameter `skin`, e.g. "turtle_b").
var skin: String = ""
## False = touching it does nothing (decorations).
var contact_hurts: bool = true
## False = cannot be hit, touched or bounced on right now (hanging lurker, rising burrower).
var tangible: bool = true
## True while the enemy occupies one of the Tuning.MAX_ACTIVE_ENEMIES slots.
var awake: bool = false
## True after death until the next level reset.
var dead: bool = false
## One-shot enemies (launched divers, edge rushers) do not come back after they despawn.
var one_shot: bool = false
## Head bounces received (0..Tuning.BOUNCE_COUNT_MAX; 2.0: up to 15 with the co-op Relay Bounce of a Feast Land):
## drives the score multiplier.
var bounce_count: int = 0
## Hang-glider dive stomps received; the third kills.
var dive_count: int = 0
## True after this enemy hurt the hero: it bursts into 6 bones when killed (2.0: 6 per hero it hurt, below).
var stole_heart: bool = false
## Ticks left of the hit flash (cosmetic).
var flash: int = 0
## Record exists in Expert mode only (level flag `expert`, GAMEPLAY.md 1.3): in Beginner it never wakes.
var expert_only: bool = false
## Record exists in Beginner mode only (level flag `beginner`).
var beginner_only: bool = false

# --- 2.0 hooks for parallel work (PLAN.md P0.8, TECH_AUDIT.md 4.8; the co-op traits are enemies-A's, PLAN.md P1.8) --
## Player slot of the hero who hit it last (Defs.hitter_slot of the weapon's source: the hero, or the owner of his
## thrown weapon); -1 = never hit since the level started. Bookkeeping only: nothing in the 1.0 game reads it.
var last_hit_slot: int = -1
## Sim.total_ticks of that hit (-1 = never).
var last_hit_tick: int = -1
## Co-op trait of this record (level parameter `coop=<trait>`, a Defs.CoopTrait; only in co-op files, DESIGN.md D.6):
## Defs.CoopTrait.NONE for every 1.0 record. The trait rules hook into [method accepts_hit_from], [method _on_hit_by]
## and [method _choose_target] (scripts/enemies/coop_traits.gd, phase 1).
var coop_trait: int = Defs.CoopTrait.NONE
## Bond of linked records (level parameter `bond=<name>`, the `bond` and `split` traits; "" = none). Its members:
## LevelBase.get_tagged(&"bond", bond) - the bond registry, shared with `objects/drum bond=`.
var bond: StringName = &""
## Keeper group (level parameter `keeper=<name>`, [R10]; "" = none): a column `trigger=keepers:<name>` opens when every
## member (LevelBase.get_tagged(&"keeper", keeper)) is dead.
var keeper: StringName = &""

## Main picture (child node "Sprite"); null for a bare EnemyBase.
var _sprite: Sprite2D = null
## Sheet facts of the current skin; null for a bare EnemyBase.
var _skin: EnemySkin = null
## Current animation (first frame, count, ticks per frame, loop), its role and its age in ticks.
var _anim: Vector4i = EnemySkin.STILL
var _anim_role: StringName = &""
var _anim_age: int = 0
## False for enemies that stay visible while asleep (bosses, decorations).
var _hide_asleep: bool = true
## True while standing on a floor (maintained by _ground_step()).
var _grounded: bool = false
## True while a climber goes up a wall.
var _climbing: bool = false

var _feast_sprite: Sprite2D = null
var _visual_ready: bool = false
var _corpse: bool = false
var _corpse_ticks: int = 0
var _must_leave_view: bool = false
var _ledge_ticks: int = 0
var _spawn_facing: int = 1

## 2.0: the co-op trait rules of this record (null without a trait: every 1.0 record).
var _traits: CoopTraits = null
## 2.0 party targeting (GAMEPLAY.md 13.9.4): the hero it sticks to and the Sim.total_ticks until which it does.
var _held_target: PlayerBase = null
var _held_until: int = 0
## 2.0: Sim.total_ticks of the last glance clank and spark (EnemyTuning.GLANCE_TICKS apart).
var _glance_tick: int = -1000
## 2.0 co-op Shaman (GAMEPLAY.md 13.9.6): Sim.total_ticks on which a Shaman last put his bone shield on it (it holds
## through the next tick: the Shaman renews it every ENEMIES phase); the bone drawn over it (created on first use).
var _bone_shield_tick: int = -1000
var _bone_sprite: Sprite2D = null
## 2.0 co-op (GAMEPLAY.md 13.9.4: "each hero's stolen heart bursts as bones for the team - an enemy that hurt both
## releases 12"): bit per player slot of the heroes it hurt since it last came back.
var _hurt_slots: int = 0
## 2.0 co-op, G57 one hit per strike: per player slot, the CoopTraits.strike_key of the strike that last hurt it (-1 =
## none); empty until a co-op party first hits it (never allocated in single-player or versus).
var _strike_keys: PackedInt64Array = PackedInt64Array()
## 2.0 phase 4, Q2 (DESIGN.md G85) - DRAWING ONLY: true while its sprite wears the ward mark ([method
## _show_ward_mark]: fx/WardMark's shared material). Written by [method _refresh_visual] alone; no rule reads it.
var _ward_marked: bool = false

static var _warned_skins: Dictionary[String, bool] = {}


func get_kind() -> int:
	return Defs.Kind.ENEMY


func _init() -> void:
	z_index = Defs.Z_ENEMIES


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			_setup_visual()
		NOTIFICATION_EXIT_TREE:
			_release_slot()


func _sim_phases() -> PackedInt32Array:
	if _traits != null and _traits.needs_contact_phase():
		# 2.0: heavy, grab and leech meet the heroes before their contact pass (CoopTraits.contact_tick).
		return PackedInt32Array([Defs.Phase.ENEMIES, Defs.Phase.CONTACT_ENEMIES])
	return PackedInt32Array([Defs.Phase.ENEMIES])


func _apply_params(params: Dictionary) -> void:
	max_hp = int(params.get("hp", max_hp))
	hp = max_hp
	score_index = clampi(int(params.get("score", score_index)), 0, Tuning.SCORE_LADDER.size() - 1)
	skin = str(params.get("skin", skin))
	expert_only = param_bool("expert", expert_only)
	beginner_only = param_bool("beginner", beginner_only)
	_spawn_facing = facing
	# 2.0 (format 2, co-op files only; no 1.0 record has these parameters).
	if params.has("coop"):
		coop_trait = maxi(Defs.coop_trait_from_name(StringName(str(params["coop"]))), Defs.CoopTrait.NONE)
	if params.has("bond"):
		bond = StringName(str(params["bond"]))
	if params.has("keeper"):
		keeper = StringName(str(params["keeper"]))
	# Presets set coop_trait before calling super (enemies/shellback); the level's `coop=` wins.
	_traits = CoopTraits.create(self)


func _sim_tick(phase: int) -> void:
	if phase != Defs.Phase.ENEMIES:
		if phase == Defs.Phase.CONTACT_ENEMIES and _traits != null and not dead and not _corpse:
			_traits.contact_tick()
		return
	if _corpse:
		_corpse_tick()
		if _traits != null:
			_traits.dead_tick()
		return
	if dead or _excluded_by_mode():
		if dead and _traits != null:
			_traits.dead_tick()
		return
	if flash > 0:
		flash -= 1
	if not awake:
		_asleep_tick()
		return
	if _should_sleep():
		sleep()
		return
	if _traits == null or not _traits.pre_ai():
		_ai_tick()
		if _traits != null and awake and not dead:
			_traits.post_ai()
	if awake:
		_refresh_visual()
		_anim_age += 1


## Archetype behaviour for one tick while awake. Override.
func _ai_tick() -> void:
	pass


## Dozing (SimEntity, ARCHITECTURE.md 11): a record asleep at its anchor only waits for the view to come within
## Tuning.ENEMY_SPAWN_MARGIN_PX (the doze region reaches farther), a dead or mode-excluded one does nothing at all.
## A corpse in flight, an awake or flashing enemy, or one that must still see the view leave first, ticks.
func _doze_area() -> Rect2i:
	return get_box()


func _can_doze() -> bool:
	if _corpse:
		return false
	if _traits != null and _traits.keeps_awake():
		# 2.0: an open bond / split window, a held hero, a regrow.
		return false
	if dead or _excluded_by_mode():
		return true
	if awake or flash > 0 or (_must_leave_view and on_screen):
		return false
	return _asleep_waits_for_view()


## True when `_asleep_tick()` of this archetype does nothing while its `_doze_area()` is far from the view and the
## hero (the default rule: wake when the view comes near). An archetype that wakes by another rule (by the hero's
## distance, by a timer) returns false, or narrows `_doze_area()` to what its rule looks at.
func _asleep_waits_for_view() -> bool:
	return true


func _on_doze() -> void:
	# Its next asleep tick would have cleared the flag: the anchor is off screen (it is outside the doze region).
	if not dead:
		_must_leave_view = false


## True when the weapon pass may hit it and the hero's contact pass may touch it: awake, alive, tangible and
## drawn in the previous frame (PHYSICS.md 10.1).
func is_targetable() -> bool:
	return awake and not dead and tangible and on_screen


## A weapon box or thrown weapon overlaps this enemy (PHYSICS.md 8.3 #1). Returns true when the hit is consumed
## (always, for ordinary enemies). Dies when hp drops below zero, otherwise flashes and is pushed back by
## xvel >> 2 px.
## 2.0 (PLAN.md P0.8): the hitter's slot is noted ([member last_hit_slot], [member last_hit_tick]); a hit that
## [method accepts_hit_from] refuses glances (consumed, no damage: a shell's front); every other hit goes through
## [method _on_hit_by] first. With the defaults this is the 1.0 hit.
## Co-op traits (PLAN.md P1.8): a leech's host's own weapons pass through it (false, not consumed); the first hit of a
## whole `split` record splits it without damage (CoopTraits.absorbs_hit).
## G57 one hit per strike (a co-op party, every enemy): the later ticks of a swing that already hurt it are used up
## without anything happening ([method _repeats_strike]); single-player and versus keep the 1.0 hit on every tick.
## R2 (slot-bound windows, a co-op party): a member of a bond or a split half turns away the hit of a hero who does not
## count and the hit that could not meet its group - it glances (CoopTraits.accepts_hit).
func take_hit(power: int, source: SimEntity) -> bool:
	if not is_targetable():
		return false
	if _traits != null and _traits.skips_hit(source):
		return false
	var slot: int = Defs.hitter_slot(source)
	if slot >= 0:
		last_hit_slot = slot
		last_hit_tick = Sim.total_ticks
	if not accepts_hit_from(source):
		if _traits != null:
			_traits.on_hit_refused(source)
		_on_hit_refused(source)
		return true
	if slot >= 0 and _repeats_strike(slot, source):
		return true
	_on_hit_by(slot, power)
	if _traits != null and _traits.absorbs_hit(slot, source):
		return true
	hp -= power
	_spawn_optional(FX_HIT, sim_pos + Vector2i(0, -(box_h >> 1)))
	if hp < 0:
		kill(&"weapon", source)
	else:
		flash = EnemyTuning.FLASH_TICKS
		sim_pos.x -= Tuning.shr(xvel, Tuning.ENEMY_KNOCKBACK_SHIFT)
		Audio.play_sfx(Sfx.ENEMY_HURT)
		Events.enemy_hit.emit(self, power)
		_on_hurt(power)
	return true


## The hero bounced on its head (never damages the enemy). Returns the multiplier to show above the hero
## (0 = show nothing: a number appears on every second bounce). 2.0: a `daze` record is dazed (CoopTraits); with a
## party driver the count is the driver's Relay Bounce answer (GAMEPLAY.md 13.9.8: in a co-op Feast Land it rises past
## Tuning.BOUNCE_COUNT_MAX only on a bounce by the other hero, up to 15; elsewhere exactly the 1.0 count).
func on_bounced(hero: PlayerBase) -> int:
	var driver: SimEntity = Game.level.party_driver if Game.level != null else null
	if driver != null and driver.has_method(&"relay_bounce_count"):
		bounce_count = int(driver.call(&"relay_bounce_count", self, hero, bounce_count))
	else:
		bounce_count = mini(bounce_count + 1, Tuning.BOUNCE_COUNT_MAX)
	if _traits != null:
		_traits.on_bounced(hero)
	if (bounce_count & 1) == 0:
		return _bounce_multiplier(bounce_count)
	return 0


## The hero dive-stomped it with the hang-glider: 1 000 / 5 000 / 10 000 points, the third stomp kills. 2.0 (G57): a
## `heavy` record of a co-op party that no Brace Wall has dazed takes nothing from it (CoopTraits.refuses_death).
func on_glider_stomp(hero: PlayerBase) -> void:
	if _traits != null and _traits.refuses_death():
		return
	var index: int = mini(dive_count, Tuning.GLIDER_DIVE_SCORES.size() - 1)
	_credit_points(hero, Tuning.GLIDER_DIVE_SCORES[index])
	Game.add_score(Tuning.GLIDER_DIVE_SCORES[index])
	Events.popup_requested.emit(&"score", Tuning.GLIDER_DIVE_SCORES[index], sim_pos)
	dive_count += 1
	if dive_count >= Tuning.GLIDER_DIVE_KILLS_ON:
		kill(&"glider", hero)


## This enemy just hurt the hero: it now "holds" the stolen heart (2.0: one per hero it hurt).
func on_hurt_hero(hero: PlayerBase) -> void:
	stole_heart = true
	if hero != null and is_instance_valid(hero) and hero.slot >= 0:
		_hurt_slots |= 1 << hero.slot


## Hearts it holds: one per hero it hurt (at least one once it stole a heart; a party of one: exactly the 1.0 one).
func _hearts_held() -> int:
	var count: int = 0
	var mask: int = _hurt_slots
	while mask != 0:
		mask &= mask - 1
		count += 1
	return maxi(count, 1)


## 2.0 Brace Wall (PHYSICS.md C.10), asked by a braced crouching hero's contact pass (player-A) before a contact would
## hurt him: true = this is a `heavy` record of a co-op party and it is stopped dead and dazed
## (PartyTuning.BRACE_DAZE_TICKS, head open; true again while that daze lasts), so the contact is ignored; false = the
## normal contact (every other enemy, a party of one). The heavy also tests the wall itself (CoopTraits).
func brace_stop(_hero: PlayerBase, _partner: PlayerBase) -> bool:
	return _traits != null and _traits.brace_stop()


## 2.0 (TECH_AUDIT.md 4.8): may a weapon hit from `source` (a hero, or his thrown weapon: Defs.hitter_slot names the
## hero) hurt it now? False = the hit glances ([method take_hit] consumes it without damage; [method _on_hit_refused]
## shows it). Override for "shielded from the front" (the Guard), the Shaman's bone shields (DESIGN.md D.6). Default
## true: every 1.0 hit counts; a record with a co-op trait asks its rules (CoopTraits.accepts_hit: the front of a
## `shell`, an undazed `daze`, and - G57 - every side of a `heavy` that no Brace Wall has dazed); a record under a
## Shaman's bone shield refuses every hit ([method bone_shielded]). Overrides call super.
func accepts_hit_from(source: SimEntity) -> bool:
	if _bone_shield_tick >= Sim.total_ticks - 1:
		return false
	return _traits == null or _traits.accepts_hit(source)


## 2.0 co-op Shaman (GAMEPLAY.md 13.9.6): a living Shaman within PartyTuning.SHAMAN_SHIELD_TILES puts his bone shield
## on it for this tick and the next (he renews it every tick). Called by enemies/shaman only.
func wear_bone_shield() -> void:
	_bone_shield_tick = Sim.total_ticks


## 2.0: true while a Shaman's bone shield covers it (every weapon hit glances).
func bone_shielded() -> bool:
	return _bone_shield_tick >= Sim.total_ticks - 1


## Points paid when it dies now: ladder value x head-bounce multiplier.
func get_points() -> int:
	return Tuning.SCORE_LADDER[score_index] * _bounce_multiplier(bounce_count)


## 2.0: the multiplier of a bounce count - Tuning.bounce_multiplier up to BOUNCE_COUNT_MAX (1.0), the party driver's
## Relay Bounce steps above it (x10 for 12-13, x12 for 14-15; world-A's PartyDriver.relay_multiplier).
func _bounce_multiplier(count: int) -> int:
	if count <= Tuning.BOUNCE_COUNT_MAX:
		return Tuning.bounce_multiplier(count)
	var driver: SimEntity = Game.level.party_driver if Game.level != null else null
	if driver != null and driver.has_method(&"relay_multiplier"):
		return int(driver.call(&"relay_multiplier", count))
	return Tuning.bounce_multiplier(count)


## Kill it: pays the score, frees the slot, releases 6 bones when it had stolen a heart.
## `cause`: &"weapon", &"feast", &"kill_all", &"glider", &"boss". `killer` may be null.
## An enemy that stole a heart bursts into its bones and one eaten during the feast vanishes; every other awake
## enemy is thrown away from the killer in an arc and falls off the screen.
## 2.0 (G57): a `heavy` record of a co-op party that no Brace Wall has dazed dies of no cause but a weapon hit it
## accepted (CoopTraits.refuses_death: a kill-all, a feast's bite, a mount's bite leave it alive).
## R2 (slot-bound windows): the last living member of a bond or split of a co-op party dies of nothing its `killer`'s
## slot could not meet the group with - not by the hero who killed its mates, not by nobody (CoopTraits.refuses_kill;
## its weapon hits have glanced in [method take_hit] already).
func kill(cause: StringName, killer: SimEntity = null) -> void:
	if dead:
		return
	if _traits != null and ((cause != &"weapon" and _traits.refuses_death()) or _traits.refuses_kill(killer)):
		return
	var was_awake: bool = awake
	dead = true
	var points: int = get_points()
	_credit_points(killer, points)
	Game.add_score(points)
	_credit_kill(killer)
	Events.popup_requested.emit(&"score", points, sim_pos)
	sleep()
	var thrown: bool = was_awake and cause != &"feast" and not stole_heart
	if stole_heart:
		for i: int in Tuning.BONES_PER_HEART * _hearts_held():
			_spawn_optional(ITEM_BONE, sim_pos + Vector2i(0, EnemyTuning.BURST_DY), {"dropped": true, "fan": i})
	if thrown:
		_start_corpse(killer)
	else:
		if was_awake:
			_spawn_optional(FX_POOF, sim_pos + Vector2i(0, -(box_h >> 1)))
		visible = false
	Audio.play_sfx(Sfx.FEAST_CHOMP if cause == &"feast" else Sfx.ENEMY_DEATH)
	if _traits != null:
		# 2.0: a bond / split death opens or completes its window (R2: credited to the killer's slot); a held hero or
		# a host is let go.
		_traits.on_killed(killer)
	Events.enemy_killed.emit(self, points, cause)
	died.emit(self, cause)
	if not thrown:
		_on_gone()
	_doze_note()


## Grenade: vanish into `count` random bonus items, no score. 2.0 (G57): not a `heavy` record of a co-op party that
## no Brace Wall has dazed (CoopTraits.refuses_death). R2: nor the last living member of a bond or split whose mates
## lie dead in the open window - a grenade's death is credited to nobody (CoopTraits.refuses_kill).
func burst_into_items(count: int = Tuning.GRENADE_ITEMS_PER_ENEMY) -> void:
	if dead:
		return
	if _traits != null and (_traits.refuses_death() or _traits.refuses_kill(null)):
		return
	dead = true
	for i: int in count:
		_spawn_optional(ITEM_RANDOM, sim_pos + Vector2i(0, EnemyTuning.BURST_DY), {"dropped": true, "fan": i})
	if awake:
		_spawn_optional(FX_POOF, sim_pos + Vector2i(0, -(box_h >> 1)))
	sleep()
	visible = false
	if _traits != null:
		_traits.on_killed()
	Events.enemy_killed.emit(self, 0, &"grenade")
	died.emit(self, &"grenade")
	_on_gone()


## Take an active slot.
func wake() -> void:
	if awake:
		return
	_doze_wake_now()
	awake = true
	visible = true
	_must_leave_view = false
	if Game.level != null:
		Game.level.active_enemies += 1
	_anim_role = &""
	_on_wake()
	_refresh_visual()


## Free the slot. Ordinary enemies return to their anchor and may wake again; one-shot enemies stay gone.
func sleep() -> void:
	if not awake:
		return
	_doze_note()
	_release_slot()
	_grounded = false
	_climbing = false
	_ledge_ticks = 0
	_held_target = null
	if _traits != null:
		_traits.on_sleep()
	if dead:
		return
	if one_shot:
		dead = true
		visible = false
		_on_gone()
		return
	xvel = 0
	yvel = 0
	flash = 0
	facing = _spawn_facing
	_must_leave_view = true
	if _hide_asleep:
		visible = false
	teleport(spawn_pos)


## Respawn of the hero: every enemy returns to its level-file state. 2.0: the half a `split` record spawned leaves
## the level; the trait state is cleared.
func _on_level_reset() -> void:
	if _traits != null and _traits.is_copy:
		_coop_remove()
		return
	sleep()
	_corpse = false
	dead = false
	hp = max_hp
	bounce_count = 0
	dive_count = 0
	stole_heart = false
	_hurt_slots = 0
	flash = 0
	xvel = 0
	yvel = 0
	facing = _spawn_facing
	_must_leave_view = false
	visible = not _hide_asleep
	teleport(spawn_pos)
	_held_target = null
	if _traits != null:
		_traits.on_reset()
	_on_reset()
	_play(&"idle", true)
	_refresh_visual()


# =================================================================================================================
# Hooks for archetypes
# =================================================================================================================

## Sheet used when the level gives no `skin`. Override.
func _default_skin() -> String:
	return ""


## The enemy just took a slot: start the behaviour from its first state. Override.
func _on_wake() -> void:
	pass


## The level was reset after the hero's death: clear whatever the archetype remembers across sleeps. Override.
func _on_reset() -> void:
	pass


## A dead enemy finished disappearing (corpse left the screen, eaten, burst, or a one-shot despawned). Override.
func _on_gone() -> void:
	pass


## A weapon hit of `power` was survived (the flash and the knock-back are already applied). Override.
func _on_hurt(_power: int) -> void:
	pass


## 2.0 (TECH_AUDIT.md 4.8): a weapon hit of `power` from player slot `slot` (-1: no hero's) is about to be applied
## ([method take_hit], before the hit points drop). Hook for the two-hero rules: twin hits of two slots within a
## window, bonds, splits (scripts/enemies/coop_traits.gd). Override; nothing by default.
func _on_hit_by(_slot: int, _power: int) -> void:
	pass


## 2.0: a hit [method accepts_hit_from] refused has just glanced off. Default: the clank and the spark (at most one
## per EnemyTuning.GLANCE_TICKS, so one per strike). Override (call super to keep them).
func _on_hit_refused(source: SimEntity) -> void:
	_show_glance(source)


## 2.0 (TECH_AUDIT.md 4.8): the hero this enemy reacts to this tick - what [method _target_hero] returns to every
## archetype. A party of one: LevelBase.target_hero(self) (the 1.0 hero unless he is dead). A party (GAMEPLAY.md
## 13.9.4): the nearest hatched hero, kept for PartyTuning.TARGET_HOLD_TICKS unless he stops being hatched; a `lone`
## record on Expert: the straggler, or nobody while the heroes keep together (CoopTraits.lone_target). Override for
## other aggro rules (call super for these).
func _choose_target() -> PlayerBase:
	var level: LevelBase = Game.level
	if level == null:
		return null
	if level.hero_count() <= 1:
		return level.target_hero(self)
	if _traits != null and _traits.kind == Defs.CoopTrait.LONE and CoopTraits.party_on() \
			and PartyTuning.lone_trait_on(Game.difficulty):
		return _traits.lone_target()
	var now: int = Sim.total_ticks
	if _held_target != null and is_instance_valid(_held_target) and _held_target.is_party_targetable() \
			and now < _held_until:
		return _held_target
	var hero: PlayerBase = level.target_hero(self)
	_held_target = hero
	_held_until = now + PartyTuning.TARGET_HOLD_TICKS
	return hero


## One tick while asleep (no slot). The default wakes it by the activation rule; zone spawners override.
func _asleep_tick() -> void:
	if _must_leave_view:
		_must_leave_view = on_screen
		return
	if _should_wake():
		wake()


## Activation rule of GAMEPLAY.md 5.1: the anchor is within about 2 tiles of the visible area and a slot is free.
func _should_wake() -> bool:
	var level: LevelBase = Game.level
	if level == null or level.active_enemies >= Tuning.MAX_ACTIVE_ENEMIES:
		return false
	return level.is_in_view(self, Tuning.ENEMY_SPAWN_MARGIN_PX)


## Despawn rule of GAMEPLAY.md 5.1: not drawn and farther than one screen horizontally (or one screen + 124 px
## vertically) from the hero. An enemy inside the activation area never sleeps (no wake / sleep flicker at the
## edge of the view). A party (2.0, TECH_AUDIT.md 3.8): farther than that from every hero (LevelBase.contact_order;
## like the 1.0 hero, a hero in his death toss still counts where he is).
func _should_sleep() -> bool:
	var level: LevelBase = Game.level
	if level == null or on_screen:
		return false
	var heroes: Array[PlayerBase] = level.contact_order()
	if heroes.is_empty():
		return false
	if level.is_in_view(self, Tuning.ENEMY_SPAWN_MARGIN_PX):
		return false
	var view: Rect2i = level.get_view_rect()
	for hero: PlayerBase in heroes:
		if absi(sim_pos.x - hero.sim_pos.x) <= view.size.x \
				and absi(sim_pos.y - hero.sim_pos.y) <= view.size.y + Tuning.ENEMY_DESPAWN_EXTRA_Y:
			return false
	return true


# =================================================================================================================
# Helpers for archetypes
# =================================================================================================================

## The hero to react to, or null when there is none (not spawned yet, or in his death sequence): the "target" idiom
## of LevelBase.target_hero() - in a party the nearest hero that is alive and not down (TECH_AUDIT.md 4.1); for a
## party of one exactly 1.0's `level.player` unless he is dead. 2.0: the answer of the [method _choose_target] hook.
func _target_hero() -> PlayerBase:
	return _choose_target()


## 2.0: the other members of this record's bond (LevelBase.get_tagged(&"bond", bond), itself left out); empty without
## a bond or a level.
func bond_mates() -> Array[SimEntity]:
	var mates: Array[SimEntity] = []
	var level: LevelBase = Game.level
	if bond == &"" or level == null:
		return mates
	for member: SimEntity in level.get_tagged(&"bond", bond):
		if member != self:
			mates.append(member)
	return mates


## 2.0 (PLAN.md P1.8): the co-op trait rules of this record (scripts/enemies/coop_traits.gd), null without a trait.
func coop_traits() -> CoopTraits:
	return _traits


## 2.0: true when a weapon hit from `source` comes from the side this enemy faces (the Guard's shield, `shell`;
## GAMEPLAY.md 13.9.5 - a `heavy` no longer asks: since G57 it glances on every side until a Brace Wall dazes it): a
## thrown weapon flying into its face, else the striker's x on the facing side or within EnemyTuning.FRONT_DX of the
## feet point. No source: not from the front.
func _hit_from_front(source: SimEntity) -> bool:
	if source == null or not is_instance_valid(source):
		return false
	if source.get_kind() == Defs.Kind.HERO_PROJECTILE and source.xvel != 0:
		return signi(source.xvel) == -facing
	var dx: int = source.sim_pos.x - sim_pos.x
	if absi(dx) < EnemyTuning.FRONT_DX:
		return true
	return signi(dx) == facing


## 2.0 co-op, G57 one hit per strike (DESIGN.md D.6, PHYSICS.md C.10; [method take_hit], after the hit was accepted):
## in a co-op party (CoopTraits.party_on - a co-op party plays only co-op files) one strike instance of the hero of
## player slot `slot` hurts it at most once: true when this hit belongs to the strike of that slot that already hurt it
## (take_hit uses it up without damage, so the hero's side - the pogo, the clank, one target per box per tick - stays
## as in 1.0; the box does not reach a second enemy behind it on that tick); otherwise the strike is remembered
## (false: it hurts). So `hp` counts strikes. Strikes come from CoopTraits.strike_key (a melee swing; a
## throw, a ball flight, a bite is an instance by its own rules: -1). A party of one, single-player and versus: false
## (the 1.0 hit on every tick a box overlaps). Bosses never come here (they test the hero's boxes themselves and keep
## BOSS_HIT_COOLDOWN).
func _repeats_strike(slot: int, source: SimEntity) -> bool:
	if not CoopTraits.party_on():
		return false
	var key: int = CoopTraits.strike_key(source)
	if key < 0:
		return false
	if _strike_keys.is_empty():
		_strike_keys.resize(Defs.MAX_PLAYERS)
		_strike_keys.fill(-1)
	if slot >= _strike_keys.size():
		return false
	if _strike_keys[slot] == key:
		return true
	_strike_keys[slot] = key
	return false


## 2.0: the clank and the spark of a glancing hit, at the side it faces (at most one per EnemyTuning.GLANCE_TICKS).
func _show_glance(_source: SimEntity) -> void:
	if Sim.total_ticks - _glance_tick < EnemyTuning.GLANCE_TICKS:
		return
	_glance_tick = Sim.total_ticks
	Audio.play_sfx(Sfx.CLUB_HIT_SCENERY)
	_spawn_optional(FX_HIT, sim_pos + Vector2i(facing * (box_w >> 2), -(box_h >> 1)))


## 2.0 co-op (CoopTraits: a bond regrows, a split merges): alive again at `pos` with full hit points, awake at once
## when a slot is free and the place is in view (else asleep, waking by the usual rule).
func _coop_revive(pos: Vector2i) -> void:
	_doze_wake_now()
	_corpse = false
	dead = false
	hp = max_hp
	flash = 0
	xvel = 0
	yvel = 0
	stole_heart = false
	_hurt_slots = 0
	_grounded = false
	_climbing = false
	_ledge_ticks = 0
	_must_leave_view = false
	facing = _spawn_facing
	teleport(pos)
	_on_reset()
	visible = not _hide_asleep
	_play(&"idle", true)
	var level: LevelBase = Game.level
	if level != null and _slot_free() and level.is_in_view(self, Tuning.ENEMY_SPAWN_MARGIN_PX):
		wake()
	_refresh_visual()
	_doze_note()


## 2.0 co-op (the `split` trait): a second record of this enemy at its feet point - the same scene (or script) with
## its spawn parameters plus `extra`, without its `name` and `bond`; one-shot and awake at once. Null when it cannot be
## made.
func _coop_spawn_copy(extra: Dictionary) -> EnemyBase:
	var level: LevelBase = Game.level
	if level == null:
		return null
	var params: Dictionary = spawn_params.duplicate()
	params.erase("name")
	params.erase("bond")
	params.erase("record")
	params["facing"] = "l" if facing < 0 else "r"
	params.merge(extra, true)
	var copy: EnemyBase = null
	if scene_file_path.begins_with(Spawner.SCENE_ROOT):
		var id: StringName = StringName(scene_file_path.trim_prefix(Spawner.SCENE_ROOT).trim_suffix(".tscn"))
		copy = level.spawn(id, sim_pos, params) as EnemyBase
	else:
		var script: GDScript = get_script() as GDScript
		copy = script.new() as EnemyBase if script != null else null
		if copy != null:
			copy.spawn_setup(sim_pos, params)
			level.get_container("enemies").add_child(copy)
	if copy == null:
		return null
	copy.one_shot = true
	copy.wake()
	copy._on_coop_copy(self)
	return copy


## 2.0 co-op (the `split` trait): this enemy was just made by `source`'s [method _coop_spawn_copy] and woke. Archetypes
## that keep a state of their own (a sky dropper falling or walking) take the source's here. Override; nothing by
## default.
func _on_coop_copy(_source: EnemyBase) -> void:
	pass


## 2.0 co-op (CoopTraits): this record's bond or split group was met while it lay dead (or the party fell apart with
## its window open) - it will not regrow or merge. Archetypes that keep a dead record back for its window let it go
## here (SpawnerEnemy). Override; nothing by default.
func _on_coop_sealed() -> void:
	pass


## 2.0 co-op: a record made by [method _coop_spawn_copy] leaves the level for good (merged, or a team wipe).
func _coop_remove() -> void:
	_release_slot()
	dead = true
	visible = false
	sim_active = false
	queue_free()


## Per-player statistics (2.0, TECH_AUDIT.md 3.8): the hero who killed it - Defs.hitter_slot() of `killer`, the hero
## himself or the owner of his thrown weapon - counts the kill in his run (PlayerRun.kills). The team score
## (Game.score) is paid as in 1.0; nothing in the simulation reads the count.
func _credit_kill(killer: SimEntity) -> void:
	var slot: int = Defs.hitter_slot(killer)
	if slot >= 0:
		Game.runs[slot].kills += 1


## 2.0 co-op "Rival score" (DESIGN.md D.11; ui-B's request): in a co-op party the hero who earned `points` - the hero
## of Defs.hitter_slot(`source`) - keeps his share of the tribe score in PlayerRun.score, as collectibles do. Called
## just before Game.add_score (the HUD refreshes both on Game.score_changed). Statistics only; a party of one and
## versus never take this branch.
func _credit_points(source: SimEntity, points: int) -> void:
	if points <= 0 or Game.mode != Defs.GameMode.COOP or Game.level == null or Game.level.hero_count() <= 1:
		return
	var slot: int = Defs.hitter_slot(source)
	if slot >= 0:
		Game.runs[slot].score += points


## +1 when `target` is to the right of this enemy (or exactly above it), else -1.
func _dir_to(target: SimEntity) -> int:
	return 1 if target.sim_pos.x >= sim_pos.x else -1


## True when a slot is free for an enemy that wakes itself (zone spawners).
func _slot_free() -> bool:
	return Game.level != null and Game.level.active_enemies < Tuning.MAX_ACTIVE_ENEMIES


## Trigger rectangle of a zone spawner in logical px: level parameter `zone=c,r,w,h`, or
## EnemyTuning.DEFAULT_ZONE_TILES around the anchor.
func _zone_from_params(params: Dictionary) -> Rect2i:
	if params.has("zone"):
		var rect: Rect2i = LevelText.to_rect_px(params["zone"])
		if rect.size.x > 0 and rect.size.y > 0:
			return rect
	var reach: int = EnemyTuning.DEFAULT_ZONE_TILES * Tuning.TILE
	return Rect2i(spawn_pos.x - reach, spawn_pos.y - reach, reach * 2, reach * 2)


## Spawn an entity of another module when its scene exists (ARCHITECTURE.md 10.2 "expected absence").
func _spawn_optional(id: StringName, pos: Vector2i, params: Dictionary = {}) -> Node:
	if Game.level == null or not Spawner.exists(id):
		return null
	return Game.level.spawn(id, pos, params)


## Show the animation of a role (EnemySkin). Keeps running when the role is already playing, unless `restart`.
func _play(role: StringName, restart: bool = false) -> void:
	if _skin == null or (role == _anim_role and not restart):
		return
	_anim_role = role
	_anim = _skin.anim(role)
	_anim_age = 0


## Index of the current frame inside the running animation (0 = its first frame).
func _anim_step() -> int:
	var step: int = _anim_age / _anim.z
	if _anim.w != 0:
		return step % _anim.y
	return mini(step, _anim.y - 1)


## True when a non-looping animation showed its last frame for its full time.
func _anim_done() -> bool:
	return _anim.w == 0 and _anim_age >= _anim.y * _anim.z


## Ground physics of GAMEPLAY.md 5.1 for one tick: integrate, turn round at walls (climbers go up instead), follow
## floors and slopes, gravity Tuning.ENEMY_GRAVITY up to Tuning.ENEMY_TERMINAL, small landing bounce when `bouncy`.
## Returns true while the enemy stands on a floor.
func _ground_step(climber: bool = false, bouncy: bool = true) -> bool:
	var level: LevelBase = Game.level
	if level == null:
		sim_pos.x += Tuning.floor16(xvel)
		sim_pos.y += Tuning.floor16(yvel)
		return _grounded
	var grid: TileGrid = level.grid
	var dir: int = signi(xvel)
	if _climbing:
		_climb_step(grid, dir)
		return false
	# 2.0 tar floor (PHYSICS.md C.5): a ground enemy standing on a ':' cell moves at most Tuning.TAR_WALK_CAP; its
	# own speed is kept for when it leaves the tar. Format-1 grids have no tar: `step` is always `xvel` there.
	var step: int = xvel
	if dir != 0 and _grounded and grid.is_tar(Tuning.to_cell(sim_pos.x), Tuning.to_cell(sim_pos.y)):
		step = clampi(xvel, -Tuning.TAR_WALK_CAP, Tuning.TAR_WALK_CAP)
	sim_pos.x += Tuning.floor16(step)
	sim_pos.y += Tuning.floor16(yvel)
	if yvel >= 0 and _sank_in_liquid(grid):
		return false
	if dir != 0 and _blocked_ahead(grid, dir):
		if climber and yvel >= 0 and not _edge_ahead(grid, dir) and not _ceiling_above(grid):
			# Stay in front of the wall and start to climb it.
			sim_pos.x -= Tuning.floor16(step)
			_climbing = true
			_grounded = false
			_ledge_ticks = 0
			yvel = 0
			return false
		xvel = -xvel
		sim_pos.x += Tuning.floor16(-step)
		facing = -dir
	if yvel < 0:
		yvel = mini(yvel + Tuning.ENEMY_GRAVITY, Tuning.ENEMY_TERMINAL)
		_grounded = false
		return false
	var col: int = Tuning.to_cell(sim_pos.x)
	var row: int = Tuning.to_cell(sim_pos.y)
	var surface: int = _surface_y(grid, col, row - 1)
	if surface == NO_FLOOR:
		surface = _surface_y(grid, col, row)
	if surface == NO_FLOOR and (_grounded or _ledge_ticks > 0) and yvel == 0:
		# Step down: the foot of a slope, or the line between a climbed wall top and its floor.
		var lower: int = _surface_y(grid, col, row + 1)
		if lower != NO_FLOOR and lower - sim_pos.y <= EnemyTuning.STEP_DOWN_PX:
			surface = lower
	if surface == NO_FLOOR:
		if _ledge_ticks > 0:
			_ledge_ticks -= 1
			return true
		yvel = mini(yvel + Tuning.ENEMY_GRAVITY, Tuning.ENEMY_TERMINAL)
		_grounded = false
		return false
	sim_pos.y = surface
	_ledge_ticks = 0
	var rebound: int = -Tuning.shr(yvel, 1)
	if not bouncy or absi(rebound) <= EnemyTuning.LANDING_BOUNCE_MIN:
		rebound = 0
	yvel = rebound
	_grounded = rebound == 0
	return _grounded


## Refresh the picture from the tick counters: animation frame, facing, hit flash, feast food swap. Purely
## cosmetic; the sim advances `_anim_age` once per tick after calling it.
func _refresh_visual() -> void:
	if _sprite == null:
		return
	var food: bool = _shows_food()
	if food:
		_show_food()
	elif _feast_sprite != null:
		_feast_sprite.visible = false
	_sprite.visible = not food
	# Only changes are written: a sprite's frame and flip setters redraw (and signal) even when nothing changed.
	var frame: int = clampi(_anim.x + _anim_step(), 0, _sprite.hframes * _sprite.vframes - 1)
	if _sprite.frame != frame:
		_sprite.frame = frame
	var flip: bool = facing < 0
	if _sprite.flip_h != flip:
		_sprite.flip_h = flip
	_sprite.modulate = FLASH_COLOR if (flash & EnemyTuning.FLASH_PERIOD_MASK) != 0 else Color.WHITE
	if _bone_sprite != null or _bone_shield_tick >= Sim.total_ticks - 1:
		_show_bone_shield(not food and not dead and bone_shielded())
	# 2.0 phase 4, Q2 (DESIGN.md G85), drawing only: the ward mark. One bool test in every level that shows none
	# (single-player, versus, the search's world: LevelBase.ward_marks is false there).
	var level: LevelBase = Game.level
	if _ward_marked or (level != null and level.ward_marks):
		_show_ward_mark(level != null and level.ward_marks and not food and wears_ward_mark()
				and level.in_ward(sim_pos.x))


## True while the enemy is drawn as food (feast mode, GAMEPLAY.md 5.3; a party: while any hero feasts). 2.0 (G57):
## never a `heavy` record of a co-op party that cannot be eaten now (CoopTraits.refuses_death).
func _shows_food() -> bool:
	if not awake or not tangible or not contact_hurts:
		return false
	if _traits != null and _traits.refuses_death():
		return false
	var level: LevelBase = Game.level
	return level != null and level.any_hero_feasting()


# =================================================================================================================
# Internals
# =================================================================================================================

func _setup_visual() -> void:
	if _visual_ready:
		return
	_visual_ready = true
	_sprite = get_node_or_null(^"Sprite") as Sprite2D
	_apply_skin(skin if not skin.is_empty() else _mode_skin(_default_skin()))
	if _hide_asleep and not awake:
		visible = false
	_play(&"idle", true)
	_refresh_visual()


## Switch to another sheet: texture, grid, pivot and the body box of the manifest. An unknown name is a content
## error: reported once, the default skin is used instead.
func _apply_skin(skin_name: String) -> void:
	var def: EnemySkin = EnemySkin.find(skin_name)
	if def == null and not skin_name.is_empty():
		if not _warned_skins.has(skin_name):
			_warned_skins[skin_name] = true
			push_warning("EnemyBase: unknown skin '%s' for %s, using '%s'" % [skin_name, name, _default_skin()])
		def = EnemySkin.find(_default_skin())
	if def == null:
		return
	_skin = def
	skin = def.sheet
	set_box(Vector3i(def.box.x, def.box.y, def.box.x >> 1))
	_anim_role = &""
	if _sprite == null:
		return
	_sprite.texture = load(def.texture_path) as Texture2D
	_sprite.centered = false
	_sprite.hframes = def.columns
	_sprite.vframes = def.rows
	_sprite.offset = def.sprite_offset()
	_sprite.frame = 0


## Default sheet for the current mode: in Expert the second palette (`_b`) when the sheet has one
## (ASSET_MANIFEST.md 2: "`_b` palette for Expert"). A `skin` given by the level always wins.
func _mode_skin(default_skin: String) -> String:
	if Game.difficulty == Defs.Difficulty.EXPERT and not default_skin.is_empty():
		var variant: String = default_skin + EnemySkin.VARIANT_SUFFIX
		if EnemySkin.find(variant) != null:
			return variant
	return default_skin


func _excluded_by_mode() -> bool:
	return (expert_only and Game.difficulty != Defs.Difficulty.EXPERT) \
			or (beginner_only and Game.difficulty != Defs.Difficulty.BEGINNER)


func _release_slot() -> void:
	if not awake:
		return
	awake = false
	if Game.level != null:
		Game.level.active_enemies = maxi(Game.level.active_enemies - 1, 0)


## A ground enemy whose feet entered a liquid cell (water, ice water, lava) is gone with a splash, without points,
## like one that fell off the map: it leaves the view and returns from its anchor later (sleep). Liquids are pits
## for everybody - only the hero used to die in them, while walkers, hoppers and chargers walked on the pit bed.
func _sank_in_liquid(grid: TileGrid) -> bool:
	var col: int = Tuning.to_cell(sim_pos.x)
	var row: int = Tuning.to_cell(sim_pos.y)
	if grid.get_char(col, row) != TileGrid.CH_LIQUID:
		return false
	var lava: bool = Game.level != null and str(Game.level.meta.get("liquid", "")) == "lava"
	_spawn_optional(FX_SPLASH, Vector2i(sim_pos.x, row * Tuning.TILE), {"kind": "lava" if lava else "water"})
	Audio.play_sfx(Sfx.SPLASH)
	sleep()
	return true


## Feet y on the floor of cell (col, row), or NO_FLOOR when that cell is no floor for enemies.
func _surface_y(grid: TileGrid, col: int, row: int) -> int:
	if not TileGrid.is_ground(grid.floor_at(col, row)):
		return NO_FLOOR
	return row * Tuning.TILE + grid.surface_offset(col, row, sim_pos.x)


## True when a wall (or the edge of the level) is half a body width ahead, in the row above the feet row.
func _blocked_ahead(grid: TileGrid, dir: int) -> bool:
	if _edge_ahead(grid, dir):
		return true
	var probe_x: int = sim_pos.x + dir * (box_w >> 1)
	return grid.side_at(Tuning.to_cell(probe_x), Tuning.to_cell(sim_pos.y) - 1) == TileGrid.SIDE_WALL


## True when the edge of the level is half a body width ahead (nothing to climb there).
func _edge_ahead(grid: TileGrid, dir: int) -> bool:
	var probe_x: int = sim_pos.x + dir * (box_w >> 1)
	return probe_x < Tuning.X_MIN or probe_x >= grid.x_max_excl()


## True when a solid ceiling is directly above the head.
func _ceiling_above(grid: TileGrid) -> bool:
	return grid.ceiling_at(Tuning.to_cell(sim_pos.x), Tuning.to_cell(sim_pos.y - box_h - 1)) \
			== TileGrid.CEILING_SOLID


## One tick on a wall: up EnemyTuning.CLIMB_SPEED until the wall ends, then onto its top. A ceiling stops the
## climb and turns the climber round.
func _climb_step(grid: TileGrid, dir: int) -> void:
	if dir == 0 or _ceiling_above(grid):
		_climbing = false
		xvel = -xvel
		facing = -facing
		return
	sim_pos.y += Tuning.floor16(-EnemyTuning.CLIMB_SPEED)
	if _blocked_ahead(grid, dir):
		return
	_climbing = false
	sim_pos.y = Tuning.tile_top(sim_pos.y)
	_ledge_ticks = EnemyTuning.LEDGE_TICKS


func _start_corpse(killer: SimEntity) -> void:
	_corpse = true
	_corpse_ticks = 0
	visible = true
	flash = 0
	xvel = EnemyTuning.DEATH_ARC_XVEL * _away_from(killer)
	yvel = EnemyTuning.DEATH_ARC_YVEL
	facing = -signi(xvel)
	_play(&"dead", true)
	_refresh_visual()


func _corpse_tick() -> void:
	_corpse_ticks += 1
	_anim_age += 1
	sim_pos.x += Tuning.floor16(xvel)
	sim_pos.y += Tuning.floor16(yvel)
	yvel = mini(yvel + Tuning.ENEMY_GRAVITY, Tuning.ENEMY_TERMINAL)
	if _corpse_ticks >= EnemyTuning.DEATH_ARC_MAX_TICKS \
			or (_corpse_ticks > EnemyTuning.DEATH_ARC_MIN_TICKS and not on_screen):
		_corpse = false
		visible = false
		xvel = 0
		yvel = 0
		_on_gone()
		_doze_note()
		return
	_refresh_visual()


## Direction in which a killed enemy is thrown: with a thrown weapon's flight, otherwise away from the killer.
func _away_from(killer: SimEntity) -> int:
	if killer == null:
		return -facing
	if killer is ProjectileBase and killer.xvel != 0:
		return signi(killer.xvel)
	if killer.sim_pos.x == sim_pos.x:
		return killer.facing
	return 1 if sim_pos.x > killer.sim_pos.x else -1


## 2.0 phase 4, Q2 (DESIGN.md G85), a query for the picture only: true when this is an enemy a hero could come down
## on - the test of the hero's contact pass (PHYSICS.md 10.1) without the view: an ordinary enemy (not a boss, whose
## body no ward covers), awake, alive, touchable and one whose touch counts (no decoration). Such an enemy wears the
## ward mark while its feet column is in a ward of a co-op party's level ([method is_ward_marked]).
func wears_ward_mark() -> bool:
	return awake and not dead and tangible and contact_hurts and get_kind() == Defs.Kind.ENEMY


## True while the ward mark is drawn on it (tests, tools; drawing only).
func is_ward_marked() -> bool:
	return _ward_marked


## The ward mark on or off (cosmetic): fx/WardMark's one shared material on the sprite - chalk war paint over every
## frame of every sheet. Written only when it changes.
func _show_ward_mark(on: bool) -> void:
	if on == _ward_marked:
		return
	_ward_marked = on
	_sprite.material = WardMark.material() if on else null


## The Shaman's bone over its head (cosmetic): shown while [method bone_shielded].
func _show_bone_shield(on: bool) -> void:
	if _bone_sprite == null:
		if not on:
			return
		_bone_sprite = Sprite2D.new()
		_bone_sprite.name = "BoneShield"
		_bone_sprite.texture = load(EnemyTuning.BONE_SHIELD_TEXTURE) as Texture2D
		_bone_sprite.hframes = EnemyTuning.BONE_SHIELD_FRAMES
		_bone_sprite.frame = 0
		var height: int = _skin.body_height if _skin != null else box_h * Tuning.ART_SCALE
		_bone_sprite.position = Vector2(0.0, -float(height + EnemyTuning.BONE_SHIELD_ABOVE_ART
				+ (EnemyTuning.BONE_SHIELD_CELL >> 1)))
		add_child(_bone_sprite)
	if _bone_sprite.visible != on:
		_bone_sprite.visible = on


func _show_food() -> void:
	if _feast_sprite == null:
		_feast_sprite = Sprite2D.new()
		_feast_sprite.name = "FeastSprite"
		_feast_sprite.texture = load(FEAST_TEXTURE_PATH) as Texture2D
		_feast_sprite.centered = false
		_feast_sprite.hframes = FEAST_COLUMNS
		_feast_sprite.vframes = FEAST_ROWS
		_feast_sprite.offset = FEAST_OFFSET
		_feast_sprite.frame = EnemyTuning.FEAST_FOOD_CELLS[
			clampi(score_index, 0, EnemyTuning.FEAST_FOOD_CELLS.size() - 1)
		]
		add_child(_feast_sprite)
	_feast_sprite.visible = true

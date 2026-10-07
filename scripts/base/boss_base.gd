class_name BossBase
extends EnemyBase
## Shared rules of bosses (GAMEPLAY.md 6): energy bar, hit cooldown, own weapon tests, defeat burst.
##
## CONTRACT FILE (docs/ARCHITECTURE.md 3.13). Owner: enemies (bodies may be replaced; public signatures frozen).
## Bosses are NOT in the ordinary enemy list: the hero's weapon pass and contact pass skip them. A boss tests the
## hero's club box and thrown weapons itself in the ENEMIES phase ([method poll_weapon_hit]) and decides itself
## what a body contact does ([method touch_hero]).
##
## A boss is visible from the start, ticks its `_ai_tick()` every tick (asleep or fighting) and never despawns.
## A defeated boss stays defeated when the hero later dies and respawns; an undefeated one is reset to full energy.

const ITEM_PREFIX: String = "items/"
const FX_DEFEAT: StringName = &"fx/explosion_big"
## Least ticks between two glance-off clanks of a melee weapon on a `thrown_only` boss.
const GLANCE_TICKS: int = 12
## Short content tokens that name another item id (ARCHITECTURE.md 6.2).
const TOKEN_ALIASES: Dictionary[String, String] = {"giant": "giant_bonus", "random": "random_bonus"}

## Name of the `zones/arena` entity this boss belongs to (level parameter `arena`).
var arena: StringName = &""
## True once the fight has started (energy bar visible, boss music playing).
var fighting: bool = false
## Ticks until the next weapon hit can count (Tuning.BOSS_HIT_COOLDOWN).
var hit_cooldown: int = 0
## Hit points per energy-bar pip (the Brute: 8; the Colossus: 4).
var hp_per_pip: int = 8
## Music context of the fight.
var music: StringName = Sfx.MUSIC_BOSS
## When true only thrown weapons count and every hit removes exactly 1 hit point (the Wall Colossus).
var thrown_only: bool = false
## Ticks until the next glance-off clank may play (thrown_only bosses).
var _glance_ticks: int = 0
## 2.0 (PLAN.md P0.8, TECH_AUDIT.md 4.8): the hero whose weapon made the last hit [method poll_weapon_hit] counted (the
## owner of a thrown weapon, the hero of a club box; also [member EnemyBase.last_hit_slot]); null before the first.
## For the co-op forms (charge whoever hit it last, stagger away from him, take his glider); the 1.0 bosses read
## their target hero instead.
var last_hitter: PlayerBase = null
## What the boss drops when defeated (level parameter `drops`): content tokens such as `fire_starter`, `trophy`,
## `food:3`, `weapon:axe` (ARCHITECTURE.md 6.2) or full entity ids such as `items/heart`.
var boss_drops: Array[StringName] = []


func get_kind() -> int:
	return Defs.Kind.BOSS


func _init() -> void:
	z_index = Defs.Z_ENEMIES
	_hide_asleep = false


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	arena = StringName(str(params.get("arena", "")))
	if params.has("drops"):
		boss_drops.clear()
		for token: String in LevelText.to_list(params["drops"]):
			boss_drops.append(StringName(token.strip_edges()))


## A boss runs its own tick (death bursts, drops, the arena) and never dozes.
func _can_doze() -> bool:
	return false


func _sim_tick(phase: int) -> void:
	if phase != Defs.Phase.ENEMIES or _excluded_by_mode():
		return
	if flash > 0:
		flash -= 1
	_ai_tick()
	_refresh_visual()
	_anim_age += 1


## Pips to draw on the energy bar: ceil(hp / pip size), at most Tuning.BOSS_BAR_MAX_PIPS.
func get_pips() -> int:
	if hp <= 0:
		return 0
	var size: int = get_hp_per_pip()
	return clampi((hp + size - 1) / size, 0, Tuning.BOSS_BAR_MAX_PIPS)


## Pips of the full bar.
func get_max_pips() -> int:
	var size: int = get_hp_per_pip()
	return clampi((max_hp + size - 1) / size, 1, Tuning.BOSS_BAR_MAX_PIPS)


## Hit points one pip stands for: `hp_per_pip`, or more for a boss whose `hp` would need more pips than the bar
## has (a tougher boss set by its level), so that the full bar always spans its own hit points and every hit of
## such a boss visibly removes pips.
func get_hp_per_pip() -> int:
	return maxi(maxi(hp_per_pip, 1), ceili(float(max_hp) / float(Tuning.BOSS_BAR_MAX_PIPS)))


## Start the fight: show the energy bar and switch to the boss music. Idempotent.
func start_fight() -> void:
	if fighting or dead:
		return
	fighting = true
	wake()
	Audio.push_music(music)
	Audio.play_sfx(Sfx.BOSS_ROAR)
	Events.boss_started.emit(self)
	Events.boss_energy_changed.emit(self, get_pips(), get_max_pips())


## Test the hero's weapons against `weak_point` (logical px) for this tick: first every thrown weapon in flight,
## then the club box created on the previous tick. Returns the power of the first hit (0 = none) and consumes a
## thrown weapon that hit. Honours `thrown_only` and the hit cooldown; a club hit makes the hero pogo. On a
## `thrown_only` boss a club or hammer on the weak point glances off: a clank and a spark, no damage, no pogo.
## A party (2.0, TECH_AUDIT.md 3.9): every hero's thrown weapons (newest first, as in 1.0), then every hero's club
## box in LevelBase.contact_order() (slot order); the first box that hits counts and that hero pogos.
func poll_weapon_hit(weak_point: Rect2i) -> int:
	if hit_cooldown > 0:
		hit_cooldown -= 1
	if _glance_ticks > 0:
		_glance_ticks -= 1
	var level: LevelBase = Game.level
	if level == null or dead or not fighting:
		return 0
	var projectiles: Array[SimEntity] = level.get_kind(Defs.Kind.HERO_PROJECTILE)
	for i: int in range(projectiles.size() - 1, -1, -1):
		var projectile: ProjectileBase = projectiles[i] as ProjectileBase
		if projectile != null and not projectile.spent and Overlap.rects(projectile.get_box(), weak_point):
			projectile.consume()
			if hit_cooldown > 0:
				return 0
			_note_hitter(level, projectile.owner_slot)
			return 1 if thrown_only else projectile.power
	if thrown_only:
		for hero: PlayerBase in level.contact_order():
			_glance(level, hero, weak_point)
		return 0
	if hit_cooldown > 0:
		return 0
	for hero: PlayerBase in level.contact_order():
		if hero.club_box_active and Overlap.rects(hero.club_box, weak_point):
			hero.notify_weapon_hit()
			_note_hitter(level, hero.slot)
			return hero.club_power
	return 0


## 2.0: remember the hero of player slot `slot` as the one who made the hit poll_weapon_hit just counted
## ([member last_hitter], [member EnemyBase.last_hit_slot] / [member EnemyBase.last_hit_tick]). Bookkeeping only.
func _note_hitter(level: LevelBase, slot: int) -> void:
	last_hitter = level.get_hero(slot)
	if last_hitter == null and slot == 0:
		last_hitter = level.player
	last_hit_slot = slot
	last_hit_tick = Sim.total_ticks


## A melee weapon on the weak point of a boss that only thrown weapons hurt: show that it glances off (a clank and
## a spark at most every GLANCE_TICKS), so a player learns to throw instead.
func _glance(level: LevelBase, hero: PlayerBase, weak_point: Rect2i) -> void:
	if _glance_ticks > 0 or hero == null or not hero.club_box_active or not Overlap.rects(hero.club_box, weak_point):
		return
	_glance_ticks = GLANCE_TICKS
	Audio.play_sfx(Sfx.CLUB_HIT_SCENERY)
	var contact: Rect2i = hero.club_box.intersection(weak_point)
	level.spawn_fx(&"fx/hit_stars", contact.get_center())


## Apply a weapon hit found by poll_weapon_hit(): lose `power` hit points, update the bar, die at zero.
func apply_boss_hit(power: int) -> void:
	if power <= 0 or dead:
		return
	hit_cooldown = Tuning.BOSS_HIT_COOLDOWN
	hp = maxi(hp - power, 0)
	flash = EnemyTuning.FLASH_TICKS
	Audio.play_sfx(Sfx.BOSS_HIT)
	Events.enemy_hit.emit(self, power)
	Events.boss_energy_changed.emit(self, get_pips(), get_max_pips())
	if hp <= 0:
		_on_lethal_hit()


## A body part touched the hero: costs one bone, throws him back, 44 ticks of immunity (GAMEPLAY.md 6).
## Returns true when the hit was applied.
func touch_hero(hero: PlayerBase) -> bool:
	return hero.hurt(self, Defs.HurtKind.BOSS_BODY)


## Defeat: drop `drops` (e.g. the fire-starter or the trophies; content tokens or entity ids), burst into
## Tuning.BOSS_BURST_ITEMS random bonus items, return to the level music. The drops are thrown out first so that a
## cap on dropped items can never swallow the fire-starter or a trophy.
func defeat(drops: Array[StringName] = []) -> void:
	if dead:
		return
	dead = true
	fighting = false
	sleep()
	var origin: Vector2i = _burst_origin()
	if Game.level != null:
		for i: int in drops.size():
			var entry: Dictionary = _drop_entry(drops[i])
			var params: Dictionary = entry["params"]
			params["dropped"] = true
			params["fan"] = i
			_spawn_optional(entry["id"], origin, params)
		for i: int in Tuning.BOSS_BURST_ITEMS:
			_spawn_optional(ITEM_RANDOM, origin, {"dropped": true, "fan": i})
		_spawn_optional(FX_DEFEAT, origin)
		Game.level.unlock_camera()
	Audio.play_sfx(Sfx.BOSS_DEFEATED)
	Audio.pop_music()
	Events.boss_energy_changed.emit(self, 0, get_max_pips())
	Events.boss_defeated.emit(self)
	died.emit(self, &"weapon")
	_on_defeated()


func _on_level_reset() -> void:
	if dead:
		# A defeated boss stays defeated: its drops belong to the level now.
		return
	var was_fighting: bool = fighting
	super._on_level_reset()
	fighting = false
	hit_cooldown = 0
	if was_fighting:
		Audio.pop_music()
		Events.boss_energy_changed.emit(self, 0, get_max_pips())


## Bosses never despawn.
func _should_sleep() -> bool:
	return false


## Bosses are never drawn as food.
func _shows_food() -> bool:
	return false


# =================================================================================================================
# Hooks for the bosses
# =================================================================================================================

## The last hit point is gone. The default defeats at once; a boss with a death animation overrides it and calls
## defeat(drops) itself when the animation is over.
func _on_lethal_hit() -> void:
	defeat(boss_drops)


## Where the bonus burst and the drops come out (logical px).
func _burst_origin() -> Vector2i:
	return sim_pos + Vector2i(0, EnemyTuning.BOSS_DROP_DY)


## Called at the end of defeat(): hide, show the broken pose ... Override.
func _on_defeated() -> void:
	visible = false


## True when `hero` is close enough to start the fight (the boss's own wake rule). Override; used by
## [method _wakes_for_any].
func _wakes_for(_hero: PlayerBase) -> bool:
	return false


## True when a hero starts the fight by the boss's [method _wakes_for] rule: the target hero `target` (1.0, null =
## none); a party (2.0, TECH_AUDIT.md 3.9): any hero that enemies may target (PlayerBase.is_party_targetable), in
## LevelBase.contact_order().
func _wakes_for_any(target: PlayerBase) -> bool:
	var level: LevelBase = Game.level
	if level == null or level.hero_count() <= 1:
		return target != null and _wakes_for(target)
	for hero: PlayerBase in level.contact_order():
		if hero.is_party_targetable() and _wakes_for(hero):
			return true
	return false


# =================================================================================================================
# Internals
# =================================================================================================================

## Entity id and parameters of a drop: a full id ("items/heart") or a content token ("food:3", "weapon:axe").
static func _drop_entry(token: StringName) -> Dictionary:
	var text: String = String(token)
	var params: Dictionary = {}
	if text.contains("/"):
		return {"id": StringName(text), "params": params}
	var colon: int = text.find(":")
	var item: String = text if colon < 0 else text.substr(0, colon)
	if colon >= 0:
		var value: String = text.substr(colon + 1)
		if value.is_valid_int():
			params["index"] = value.to_int()
		else:
			params["kind"] = value
	item = TOKEN_ALIASES.get(item, item)
	return {"id": StringName(ITEM_PREFIX + item), "params": params}

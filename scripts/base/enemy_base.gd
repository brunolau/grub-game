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
## `_asleep_tick()`, `_should_wake()`, `_should_sleep()`.

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
## Head bounces received (0..Tuning.BOUNCE_COUNT_MAX): drives the score multiplier.
var bounce_count: int = 0
## Hang-glider dive stomps received; the third kills.
var dive_count: int = 0
## True after this enemy hurt the hero: it bursts into 6 bones when killed.
var stole_heart: bool = false
## Ticks left of the hit flash (cosmetic).
var flash: int = 0
## Record exists in Expert mode only (level flag `expert`, GAMEPLAY.md 1.3): in Beginner it never wakes.
var expert_only: bool = false
## Record exists in Beginner mode only (level flag `beginner`).
var beginner_only: bool = false

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
	return PackedInt32Array([Defs.Phase.ENEMIES])


func _apply_params(params: Dictionary) -> void:
	max_hp = int(params.get("hp", max_hp))
	hp = max_hp
	score_index = clampi(int(params.get("score", score_index)), 0, Tuning.SCORE_LADDER.size() - 1)
	skin = str(params.get("skin", skin))
	expert_only = param_bool("expert", expert_only)
	beginner_only = param_bool("beginner", beginner_only)
	_spawn_facing = facing


func _sim_tick(phase: int) -> void:
	if phase != Defs.Phase.ENEMIES:
		return
	if _corpse:
		_corpse_tick()
		return
	if dead or _excluded_by_mode():
		return
	if flash > 0:
		flash -= 1
	if not awake:
		_asleep_tick()
		return
	if _should_sleep():
		sleep()
		return
	_ai_tick()
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
func take_hit(power: int, source: SimEntity) -> bool:
	if not is_targetable():
		return false
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
## (0 = show nothing: a number appears on every second bounce).
func on_bounced(_hero: PlayerBase) -> int:
	bounce_count = mini(bounce_count + 1, Tuning.BOUNCE_COUNT_MAX)
	if (bounce_count & 1) == 0:
		return Tuning.bounce_multiplier(bounce_count)
	return 0


## The hero dive-stomped it with the hang-glider: 1 000 / 5 000 / 10 000 points, the third stomp kills.
func on_glider_stomp(hero: PlayerBase) -> void:
	var index: int = mini(dive_count, Tuning.GLIDER_DIVE_SCORES.size() - 1)
	Game.add_score(Tuning.GLIDER_DIVE_SCORES[index])
	Events.popup_requested.emit(&"score", Tuning.GLIDER_DIVE_SCORES[index], sim_pos)
	dive_count += 1
	if dive_count >= Tuning.GLIDER_DIVE_KILLS_ON:
		kill(&"glider", hero)


## This enemy just hurt the hero: it now "holds" the stolen heart.
func on_hurt_hero(_hero: PlayerBase) -> void:
	stole_heart = true


## Points paid when it dies now: ladder value x head-bounce multiplier.
func get_points() -> int:
	return Tuning.SCORE_LADDER[score_index] * Tuning.bounce_multiplier(bounce_count)


## Kill it: pays the score, frees the slot, releases 6 bones when it had stolen a heart.
## `cause`: &"weapon", &"feast", &"kill_all", &"glider", &"boss". `killer` may be null.
## An enemy that stole a heart bursts into its bones and one eaten during the feast vanishes; every other awake
## enemy is thrown away from the killer in an arc and falls off the screen.
func kill(cause: StringName, killer: SimEntity = null) -> void:
	if dead:
		return
	var was_awake: bool = awake
	dead = true
	var points: int = get_points()
	Game.add_score(points)
	Events.popup_requested.emit(&"score", points, sim_pos)
	sleep()
	var thrown: bool = was_awake and cause != &"feast" and not stole_heart
	if stole_heart:
		for i: int in Tuning.BONES_PER_HEART:
			_spawn_optional(ITEM_BONE, sim_pos + Vector2i(0, EnemyTuning.BURST_DY), {"dropped": true, "fan": i})
	if thrown:
		_start_corpse(killer)
	else:
		if was_awake:
			_spawn_optional(FX_POOF, sim_pos + Vector2i(0, -(box_h >> 1)))
		visible = false
	Audio.play_sfx(Sfx.FEAST_CHOMP if cause == &"feast" else Sfx.ENEMY_DEATH)
	Events.enemy_killed.emit(self, points, cause)
	died.emit(self, cause)
	if not thrown:
		_on_gone()
	_doze_note()


## Grenade: vanish into `count` random bonus items, no score.
func burst_into_items(count: int = Tuning.GRENADE_ITEMS_PER_ENEMY) -> void:
	if dead:
		return
	dead = true
	for i: int in count:
		_spawn_optional(ITEM_RANDOM, sim_pos + Vector2i(0, EnemyTuning.BURST_DY), {"dropped": true, "fan": i})
	if awake:
		_spawn_optional(FX_POOF, sim_pos + Vector2i(0, -(box_h >> 1)))
	sleep()
	visible = false
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


## Respawn of the hero: every enemy returns to its level-file state.
func _on_level_reset() -> void:
	sleep()
	_corpse = false
	dead = false
	hp = max_hp
	bounce_count = 0
	dive_count = 0
	stole_heart = false
	flash = 0
	xvel = 0
	yvel = 0
	facing = _spawn_facing
	_must_leave_view = false
	visible = not _hide_asleep
	teleport(spawn_pos)
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
## edge of the view).
func _should_sleep() -> bool:
	var level: LevelBase = Game.level
	if level == null or on_screen or level.player == null:
		return false
	if level.is_in_view(self, Tuning.ENEMY_SPAWN_MARGIN_PX):
		return false
	var view: Rect2i = level.get_view_rect()
	var hero: Vector2i = level.player.sim_pos
	return absi(sim_pos.x - hero.x) > view.size.x \
			or absi(sim_pos.y - hero.y) > view.size.y + Tuning.ENEMY_DESPAWN_EXTRA_Y


# =================================================================================================================
# Helpers for archetypes
# =================================================================================================================

## The hero, or null when there is none to react to (not spawned yet, or in his death sequence).
func _target_hero() -> PlayerBase:
	var level: LevelBase = Game.level
	if level == null or level.player == null or level.player.dead:
		return null
	return level.player


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
	sim_pos.x += Tuning.floor16(xvel)
	sim_pos.y += Tuning.floor16(yvel)
	if yvel >= 0 and _sank_in_liquid(grid):
		return false
	if dir != 0 and _blocked_ahead(grid, dir):
		if climber and yvel >= 0 and not _edge_ahead(grid, dir) and not _ceiling_above(grid):
			# Stay in front of the wall and start to climb it.
			sim_pos.x -= Tuning.floor16(xvel)
			_climbing = true
			_grounded = false
			_ledge_ticks = 0
			yvel = 0
			return false
		xvel = -xvel
		sim_pos.x += Tuning.floor16(xvel)
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


## True while the enemy is drawn as food (feast mode, GAMEPLAY.md 5.3).
func _shows_food() -> bool:
	if not awake or not tangible or not contact_hurts:
		return false
	var level: LevelBase = Game.level
	return level != null and level.player != null and level.player.is_feasting()


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

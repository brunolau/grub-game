class_name Player
extends PlayerBase
## The hero. Reproduces docs/spec/PHYSICS.md sections 4-11 and 13 tick for tick (docs/ARCHITECTURE.md 8.2).
##
## Everything is integer math in original units (logical px, v16, ticks) read from [Tuning]; nothing here uses
## Godot physics, floats or frame time. One tick runs four phases:
##  - WEAPONS: thrown weapons and the club box of the previous tick against enemies, then hittables (step 2);
##  - PLAYER: input, state table, handler, x then y integration, tile collision, glider, timers (step 8);
##  - CONTACT_ENEMIES: bounce / glider bump / hurt against the first enemy that overlaps (step 9a);
##  - POST: hit timer, death sequence, picture of the tick (steps 14-15).
##
## Root of `res://scenes/player/player.tscn`; the children `Sprite` and `GliderSprite` are cosmetic.

const ID_AXE: StringName = &"projectiles/hero_axe"
const ID_BOOMERANG: StringName = &"projectiles/hero_boomerang"
const ID_BONE: StringName = &"items/bone"
const FX_DUST: StringName = &"fx/dust"
const FX_HIT_STARS: StringName = &"fx/hit_stars"
const FX_RING: StringName = &"fx/ring"

# Cosmetic values.
## Ticks the landing squash is shown after landing from a long fall (more than 10 falling ticks).
const LAND_POSE_TICKS: int = 5
## Opacity on the three ticks out of four on which the original does not draw the hurt hero. [P 10.1]
const BLINK_ALPHA: float = 0.3
## Where the glider's bar is drawn (art px above the feet): at the raised hands of the glide frames while gliding,
## held over the head while he carries it on the ground.
const GLIDER_HANDS_Y: int = -50
const GLIDER_CARRY_Y: int = -62

## Hero sheets indexed by Defs.Weapon (ASSET_MANIFEST 3: one layout, four weapon variants). Set in the scene.
@export var weapon_sheets: Array[Texture2D] = []

## Handler that actually ran on this tick (Defs.HeroState). Differs from `state` while a strike is in progress
## (4.3 override 4), during the jump lock-out (6.1 #1), while sliding into a crawl and with the hang-glider.
var handler: int = Defs.HeroState.IDLE
## Tuning.ClubFrame of the club box created on this tick (NONE = no box).
var club_frame: int = Tuning.ClubFrame.NONE
## Entries of the current strike script played so far (1 on its first tick); keeps its value after the strike.
var strike_tick: int = 0
## Hang-glider lift left: UP spends it to climb, a dive at speed refills it. [P 13.2]
var glider_lift: int = 0
## Hang-glider nose position 0 (down) .. Tuning.GLIDER_TILT_MAX (up).
var glider_tilt: int = Tuning.GLIDER_TILT_NEUTRAL
## Ticks walked at run-up speed with the glider; at Tuning.GLIDER_RUNUP_TICKS pressing UP takes off.
var glider_runup: int = 0
## Ticks of the death sequence played so far (0 while alive).
var death_ticks: int = 0
## True on a tick on which his head hit a ceiling while he was rising. [P 11.2 #5]
var bumped_head: bool = false
## True while he brakes in the direction he faces (skid pose, dust). [P 5.5]
var skidding: bool = false
## True while he catches his breath after a long run. [P 5.5]
var panting: bool = false
## Ticks left of the landing squash pose.
var land_pose: int = 0
## True after he touched an open exit (victory pose).
var victorious: bool = false
## Sheet frame shown on this tick (ASSET_MANIFEST 3).
var anim_frame: int = HeroAnim.IDLE_FIRST

var _raw_flags: int = 0
var _lr_held: bool = false
## Which state's animation script is loaded: a strike restarts when the strike type differs from it. [P 4.3 #4]
var _loaded_anim: int = Defs.HeroState.IDLE
## Origin of the last club box: thrown weapons leave the hand there. [P 8.4]
var _weapon_anchor: Vector2i = Vector2i.ZERO
var _hard_landed: bool = false
var _death_dx: int = 0
var _death_vy: int = 0
var _animator: HeroAnim = HeroAnim.new()
var _sprite: Sprite2D = null
var _glider_sprite: Sprite2D = null


func _ready() -> void:
	_sprite = get_node_or_null(^"Sprite") as Sprite2D
	_glider_sprite = get_node_or_null(^"GliderSprite") as Sprite2D
	_on_weapon_changed(Game.weapon)
	_refresh_visual()


func _enter_tree() -> void:
	if not Game.weapon_changed.is_connected(_on_weapon_changed):
		Game.weapon_changed.connect(_on_weapon_changed)
	if not Events.exit_reached.is_connected(_on_exit_reached):
		Events.exit_reached.connect(_on_exit_reached)


func _exit_tree() -> void:
	if Game.weapon_changed.is_connected(_on_weapon_changed):
		Game.weapon_changed.disconnect(_on_weapon_changed)
	if Events.exit_reached.is_connected(_on_exit_reached):
		Events.exit_reached.disconnect(_on_exit_reached)


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([
		Defs.Phase.WEAPONS, Defs.Phase.PLAYER, Defs.Phase.CONTACT_ENEMIES, Defs.Phase.POST,
	])


func _sim_tick(phase: int) -> void:
	match phase:
		Defs.Phase.WEAPONS:
			_weapon_pass()
		Defs.Phase.PLAYER:
			_hero_update()
		Defs.Phase.CONTACT_ENEMIES:
			_contact_pass()
		Defs.Phase.POST:
			_post_step()


# =================================================================================================================
# Queries
# =================================================================================================================

## True while he carries the hang-glider (folded or open).
func is_carrying_glider() -> bool:
	return Game.has_glider


## Animation playing on this tick (a [enum HeroAnim.Anim]).
func get_anim() -> int:
	return _animator.anim


# =================================================================================================================
# Calls other modules make (PlayerBase contract)
# =================================================================================================================

func hurt(source: SimEntity, kind: int = Defs.HurtKind.ENEMY) -> bool:
	if dead:
		return false
	var pierces_immunity: bool = kind == Defs.HurtKind.TRAP or kind == Defs.HurtKind.BOSS_PROJECTILE
	if hit_timer > 0 and not pierces_immunity:
		return false
	if feast > 0 and kind == Defs.HurtKind.ENEMY:
		return false
	var killed: bool = false
	var bones: int = 0
	match kind:
		Defs.HurtKind.BOSS_BODY:
			killed = Game.lose_bone()
			var toward_right: bool = source == null or source.sim_pos.x <= sim_pos.x
			xvel = Tuning.BOSS_KNOCK_XVEL if toward_right else -Tuning.BOSS_KNOCK_XVEL
			ice = Tuning.ICE_MAX
		Defs.HurtKind.TRAP:
			bones = Game.scatter_energy()
		Defs.HurtKind.BOSS_PROJECTILE:
			killed = Game.lose_heart()
			if not killed:
				bones = Tuning.BONES_PER_HEART
		_:
			if Game.has_glider:
				set_glider(false)
			else:
				killed = Game.lose_heart()
			xvel = xvel * Tuning.HURT_XVEL_FACTOR
	hit_timer = Tuning.HIT_TIMER
	attack_gate = false
	_close_glider()
	yvel = Tuning.HURT_YVEL
	grounded = false
	Audio.play_sfx(Sfx.PLAYER_HURT if kind == Defs.HurtKind.ENEMY else Sfx.PLAYER_HURT_HEAVY)
	Events.player_hurt.emit(kind, source)
	_scatter_bones(bones)
	if killed:
		kill(&"enemy")
	return true


func kill(cause: StringName) -> void:
	if dead:
		return
	dead = true
	control_enabled = false
	club_box_active = false
	club_frame = Tuning.ClubFrame.NONE
	attack_gate = false
	looking = false
	grounded = false
	on_platform = false
	xvel = 0
	yvel = 0
	_close_glider()
	# Death toss (PHYSICS.md 10.4): drifts toward the middle of the screen, 14 px/tick up, then falls away.
	death_ticks = 0
	_death_vy = Tuning.DEATH_VY_START
	_death_dx = Tuning.DEATH_DX
	var level: LevelBase = Game.level
	if level != null:
		var view: Rect2i = level.get_view_rect()
		if sim_pos.x >= view.position.x + view.size.x / 2:
			_death_dx = -Tuning.DEATH_DX
	Audio.play_sfx(Sfx.PLAYER_DEATH)
	Events.player_died.emit(cause)


func start_feast(ticks: int = Tuning.FEAST_TICKS) -> void:
	super.start_feast(ticks)
	if ticks > 0:
		Audio.push_music(Sfx.MUSIC_FEAST)
	else:
		_stop_feast_music()


func set_glider(carrying: bool) -> void:
	glide = 0
	glider_lift = 0
	glider_tilt = Tuning.GLIDER_TILT_NEUTRAL
	glider_runup = 0
	if carrying:
		attack_gate = false  # no strikes with the glider: a swing in progress ends here
	Game.set_glider(carrying)
	Events.glider_state_changed.emit(carrying, false)
	_refresh_visual()


func respawn_at(pos: Vector2i) -> void:
	if feast > 0:
		_stop_feast_music()
	handler = Defs.HeroState.IDLE
	input_flags = 0
	club_frame = Tuning.ClubFrame.NONE
	strike_tick = 0
	glider_lift = 0
	glider_tilt = Tuning.GLIDER_TILT_NEUTRAL
	glider_runup = 0
	death_ticks = 0
	skidding = false
	panting = false
	land_pose = 0
	victorious = false
	_raw_flags = 0
	_lr_held = false
	_loaded_anim = Defs.HeroState.IDLE
	_weapon_anchor = pos
	_hard_landed = false
	set_box(Tuning.HERO_BOX_STAND)
	_animator.reset()
	anim_frame = _animator.frame
	super.respawn_at(pos)
	_refresh_visual()


# =================================================================================================================
# Phase WEAPONS (PHYSICS.md 3 step 2, 8.3)
# =================================================================================================================

func _weapon_pass() -> void:
	# The platform pass of this tick decides again whether he rides (PHYSICS.md 11.4).
	on_platform = false
	var level: LevelBase = Game.level
	if level == null:
		return
	var enemies: Array[SimEntity] = level.get_kind(Defs.Kind.ENEMY)
	var hittables: Array[SimEntity] = level.get_kind(Defs.Kind.HITTABLE)
	var projectiles: Array[SimEntity] = level.get_kind(Defs.Kind.HERO_PROJECTILE)
	for i: int in projectiles.size():
		var projectile: ProjectileBase = projectiles[i] as ProjectileBase
		if projectile != null and not projectile.spent and _projectile_hits(projectile, enemies, hittables):
			projectile.consume()
	if club_box_active and not dead and _club_hits(enemies, hittables):
		# One target per box; a hit in the air is the pogo (PHYSICS.md 9).
		club_box_active = false
		notify_weapon_hit()


func _club_hits(enemies: Array[SimEntity], hittables: Array[SimEntity]) -> bool:
	for i: int in enemies.size():
		var enemy: EnemyBase = enemies[i] as EnemyBase
		if enemy == null or not enemy.is_targetable():
			continue
		if Overlap.weapon(club_box, club_box_xo, enemy) and enemy.take_hit(club_power, self):
			_on_weapon_connected(enemy, club_power)
			return true
	for i: int in hittables.size():
		var hittable: HittableBase = hittables[i] as HittableBase
		if hittable != null and hittable.is_hit_by(club_origin) and hittable.take_hit(club_power, self):
			return true
	return false


func _projectile_hits(
		projectile: ProjectileBase, enemies: Array[SimEntity], hittables: Array[SimEntity]
) -> bool:
	for i: int in enemies.size():
		var enemy: EnemyBase = enemies[i] as EnemyBase
		if enemy == null or not enemy.is_targetable():
			continue
		if Overlap.weapon_entity(projectile, enemy) and enemy.take_hit(projectile.power, projectile):
			_on_weapon_connected(enemy, projectile.power)
			return true
	for i: int in hittables.size():
		var hittable: HittableBase = hittables[i] as HittableBase
		if hittable != null and hittable.is_hit_by(projectile.sim_pos) \
				and hittable.take_hit(projectile.power, projectile):
			return true
	return false


func _on_weapon_connected(enemy: EnemyBase, power: int) -> void:
	var heavy: bool = Game.weapon == Defs.Weapon.HAMMER or power > Tuning.WEAPON_POWER[Game.weapon]
	Audio.play_sfx(Sfx.CLUB_HIT_HEAVY if heavy else Sfx.CLUB_HIT)
	_spawn_fx(FX_HIT_STARS, Vector2i(enemy.sim_pos.x, enemy.sim_pos.y - enemy.box_h / 2))


# =================================================================================================================
# Phase PLAYER (PHYSICS.md 3 step 8)
# =================================================================================================================

func _hero_update() -> void:
	# 8a: the club box lives for exactly one weapon pass.
	club_box_active = false
	club_frame = Tuning.ClubFrame.NONE
	looking = false
	bumped_head = false
	_hard_landed = false
	var level: LevelBase = Game.level
	if dead or level == null:
		return
	# 8b: input and facing (facing flips at once, even in mid-air and mid-swing).
	_raw_flags = GameInput.flags if control_enabled else 0
	var left: bool = (_raw_flags & Defs.IN_LEFT) != 0
	var right: bool = (_raw_flags & Defs.IN_RIGHT) != 0
	_lr_held = left or right
	if right and not left:
		facing = 1
	elif left and not right:
		facing = -1
	# 8c: state table, then the overrides swing_lock and hurt.
	input_flags = 0 if swing_lock != 0 else _raw_flags
	var selected: int = Tuning.STATE_LUT[input_flags & Defs.IN_STATE_MASK]
	if hit_timer >= Tuning.HIT_STUN_MIN:
		selected = Defs.HeroState.HURT
	state = selected
	# 8d: handler.
	if Game.has_glider:
		_run_glider(selected)
	else:
		_run_handler(selected)
	# 8e: x step, committed only inside the level bounds; 8f: y step, unconditional.
	var next_x: int = sim_pos.x + Tuning.floor16(xvel)
	if next_x >= Tuning.X_MIN and next_x < level.grid.x_max_excl():
		sim_pos.x = next_x
	sim_pos.y += Tuning.floor16(yvel)
	# 8g: tile collision.
	var low: bool = selected == Defs.HeroState.CRAWL or selected == Defs.HeroState.CROUCH
	_collide(level, Tuning.HERO_PROBE_H_CROUCH if low else Tuning.HERO_PROBE_H_STAND)
	if dead:
		return
	# 8h: the glider nose returns to neutral; 8i: timers.
	var steering: bool = (_raw_flags & (Defs.IN_UP | Defs.IN_DOWN)) != 0
	if Game.has_glider and not steering and glider_tilt != Tuning.GLIDER_TILT_NEUTRAL:
		glider_tilt += 1 if glider_tilt < Tuning.GLIDER_TILT_NEUTRAL else -1
	_tick_timers(level)
	_update_box()


func _run_handler(selected: int) -> void:
	match selected:
		Defs.HeroState.IDLE:
			_handle_idle()
		Defs.HeroState.WALK:
			_handle_walk()
		Defs.HeroState.JUMP:
			_handle_jump()
		Defs.HeroState.CRAWL:
			_handle_crawl()
		Defs.HeroState.CROUCH:
			_handle_crouch()
		Defs.HeroState.HURT:
			_handle_hurt()
		_:
			_handle_strike(selected)


# --- Primitives (PHYSICS.md 5.1, 6.2) ---------------------------------------------------------------------------------

## ACCEL(limit): one acceleration step in the facing direction while LEFT or RIGHT is held, then the clamp.
func _accel(limit: int) -> void:
	var value: int = xvel
	if _lr_held:
		value += facing * Tuning.accel_step(ice)
	xvel = clampi(value, -limit, limit)


## FRICTION: |xvel| shrinks by one braking step, not below zero.
func _friction() -> void:
	var magnitude: int = maxi(absi(xvel) - Tuning.friction_step(ice), 0)
	xvel = -magnitude if xvel < 0 else magnitude


## WIND: the level's wind pushes left; without wind this is only the floor on leftward speed.
func _wind() -> void:
	var level: LevelBase = Game.level
	if level != null:
		xvel -= Tuning.shr(level.wind, Tuning.WIND_SHIFT)
	if xvel < Tuning.LEFT_FLOOR:
		xvel = Tuning.LEFT_FLOOR


## GRAVITY: a quarter of it under the open glider, unless this tick is a stall or a dive (bit 1 of `glide`).
func _gravity() -> void:
	if glide == 1:
		yvel = mini(yvel + Tuning.GLIDE_GRAVITY, Tuning.GLIDE_CAP)
	else:
		yvel = mini(yvel + Tuning.GRAVITY, Tuning.TERMINAL)


func _add_charge() -> void:
	if charge <= Tuning.CHARGE_STEP_MAX_AT:
		charge += Tuning.CHARGE_STEP


# --- State handlers (PHYSICS.md 5.2, 6.1, 8) --------------------------------------------------------------------------

func _handle_idle() -> void:
	if attack_gate:
		_handle_strike(_loaded_anim)
	else:
		_idle_body()


func _idle_body() -> void:
	handler = Defs.HeroState.IDLE
	var was_skidding: bool = skidding
	skidding = false
	panting = false
	_wind()
	_friction()
	if not on_platform and yvel != 0:
		if jump_ticks > Tuning.IDLE_AIR_SECOND_WIND_AFTER:
			_wind()
		return
	_loaded_anim = Defs.HeroState.IDLE
	# On the ground: cosmetic choices only (PHYSICS.md 5.5).
	if absi(xvel) >= Tuning.SKID_MIN_XVEL:
		if (xvel > 0) == (facing > 0):
			skidding = true
			if Sim.tick % Tuning.SKID_DUST_PERIOD == 0:
				_spawn_fx(FX_DUST, sim_pos)
			if ice > 0 and not was_skidding:
				Audio.play_sfx(Sfx.SKID_ICE)
		return
	if xvel != 0:
		return
	var both: int = Defs.IN_LEFT | Defs.IN_RIGHT
	var look_input: bool = (_raw_flags & Defs.IN_LOOK) != 0 or (_raw_flags & both) == both
	if idle_timer >= Tuning.BREATH_IDLE_MIN and not look_input:
		idle_timer -= Tuning.BREATH_IDLE_DECAY
		panting = true
	elif look_input and not on_platform:
		looking = true


func _handle_walk() -> void:
	if attack_gate:
		_handle_strike(_loaded_anim)
		return
	_walk_body()


func _walk_body() -> void:
	handler = Defs.HeroState.WALK
	skidding = false
	panting = false
	idle_timer = mini(idle_timer + 1, Tuning.IDLE_TIMER_MAX)
	_accel(Tuning.WALK_CAP)
	_wind()
	_loaded_anim = Defs.HeroState.WALK


func _handle_jump() -> void:
	if attack_gate:
		_handle_strike(_loaded_anim)
	elif no_jump != 0:
		_idle_body()
	else:
		_jump_body(false)


## The jump handler proper. It runs whether or not he stands on the ground: the impulse table simply continues
## where `jump_ticks` stopped, and after it gravity is applied a second time. `halved` = carrying the glider.
func _jump_body(halved: bool) -> void:
	handler = Defs.HeroState.JUMP
	skidding = false
	panting = false
	on_platform = false
	var n: int = jump_ticks
	jump_ticks += 1
	if n < Tuning.JUMP_IMPULSE_TICKS:
		var impulse: int = Tuning.JUMP_IMPULSES[n]
		yvel += Tuning.shr(impulse, 1) if halved else impulse
	else:
		_gravity()
	if Tuning.unsigned_below(xvel, Tuning.JUMP_HELD_CAP):
		_accel(Tuning.JUMP_HELD_CAP)
	else:
		_friction()
	_loaded_anim = Defs.HeroState.JUMP
	_wind()
	_wind()
	if n == 0:
		Audio.play_sfx(Sfx.JUMP)
		Events.player_jumped.emit()


func _handle_crawl() -> void:
	if attack_gate:
		_handle_strike(_loaded_anim)
		return
	handler = Defs.HeroState.CRAWL
	idle_timer = 0
	drop_timer = Tuning.DROP_TIMER
	_add_charge()
	if absi(xvel) > Tuning.CRAWL_CAP:
		_idle_body()  # too fast to crawl: he slides until slow enough
		return
	skidding = false
	panting = false
	_accel(Tuning.CRAWL_CAP)
	_loaded_anim = Defs.HeroState.CRAWL


func _handle_crouch() -> void:
	if attack_gate:
		_handle_strike(_loaded_anim)
	else:
		_crouch_body()


func _crouch_body() -> void:
	handler = Defs.HeroState.CROUCH
	skidding = false
	panting = false
	glider_runup = 0
	drop_timer = Tuning.DROP_TIMER
	_loaded_anim = Defs.HeroState.CROUCH
	_friction()
	_add_charge()


func _handle_hurt() -> void:
	handler = Defs.HeroState.HURT
	skidding = false
	panting = false
	_wind()
	_friction()
	_loaded_anim = Defs.HeroState.HURT


## One tick of a strike script (PHYSICS.md 8.1). `kind` is STRIKE, HIGH_STRIKE or LOW_STRIKE.
func _handle_strike(kind: int) -> void:
	handler = kind
	skidding = false
	panting = false
	if _loaded_anim != kind:
		_loaded_anim = kind
		strike_tick = 0
	var frames: Array[int] = Tuning.STRIKE_SCRIPT_FORWARD
	var hop: int = Tuning.STRIKE_HOP_FORWARD
	if kind == Defs.HeroState.HIGH_STRIKE:
		frames = Tuning.STRIKE_SCRIPT_HIGH
		hop = Tuning.STRIKE_HOP_HIGH
	elif kind == Defs.HeroState.LOW_STRIKE:
		frames = Tuning.STRIKE_SCRIPT_LOW
		hop = Tuning.STRIKE_HOP_LOW
	if strike_tick >= frames.size():
		strike_tick = 0  # the script loops: FIRE held re-swings
	var frame: int = frames[strike_tick]
	var last: bool = strike_tick == frames.size() - 1
	strike_tick += 1
	_friction()
	idle_timer = mini(idle_timer + 1, Tuning.IDLE_TIMER_MAX)
	var weapon: int = Game.weapon
	# The charge multiplier is evaluated on every tick of the swing (PHYSICS.md 8.5).
	club_power = Tuning.WEAPON_POWER[weapon] * (Tuning.CHARGE_MULTIPLIER if charge != 0 else 1)
	attack_gate = not last
	if last:
		swing_lock = Tuning.WEAPON_LOCK[weapon]
		if not on_platform:
			yvel += hop
		if kind == Defs.HeroState.LOW_STRIKE and Sim.tick % Tuning.SKID_DUST_PERIOD == 0:
			_spawn_fx(FX_DUST, sim_pos)
		Events.player_struck.emit(kind, weapon)
		if Tuning.WEAPON_THROWN[weapon]:
			Audio.play_sfx(Sfx.THROW)
			if _throw(weapon):
				return  # the weapon left the hand: no club box on this tick
		else:
			Audio.play_sfx(Sfx.HAMMER_SWING if weapon == Defs.Weapon.HAMMER else Sfx.CLUB_SWING)
		if fall_ticks != 0:
			return  # descending in the air: no club box on the last tick
	_create_club_box(frame, weapon)


## The club box of this tick (PHYSICS.md 8.2): placed where the hero will be after this tick's integration,
## mirrored about him when he faces left. It is hit-tested in the weapon pass of the next tick.
func _create_club_box(frame: int, weapon: int) -> void:
	var rect: Rect2i = Tuning.CLUB_BOX[frame]
	var origin: Vector2i = Tuning.CLUB_ORIGIN[frame]
	if weapon == Defs.Weapon.HAMMER and frame == Tuning.ClubFrame.FWD_FRONT:
		rect = Tuning.HAMMER_FRONT_BOX
		origin = Tuning.HAMMER_FRONT_ORIGIN
	var base_x: int = sim_pos.x + Tuning.floor16(xvel)
	var base_y: int = sim_pos.y + Tuning.floor16(yvel)
	club_box_xo = origin.x - rect.position.x
	club_origin = Vector2i(base_x + facing * origin.x, base_y + origin.y)
	club_box = Rect2i(club_origin.x - club_box_xo, base_y + rect.position.y, rect.size.x, rect.size.y)
	club_box_active = true
	club_frame = frame
	_weapon_anchor = club_origin


## Throw the axe or the boomerang (PHYSICS.md 8.4). Returns false when Tuning.MAX_THROWN are already in flight.
func _throw(weapon: int) -> bool:
	var level: LevelBase = Game.level
	var id: StringName = ID_BOOMERANG if weapon == Defs.Weapon.BOOMERANG else ID_AXE
	if level == null or not Spawner.exists(id):
		return false
	var in_flight: int = 0
	for entity: SimEntity in level.get_kind(Defs.Kind.HERO_PROJECTILE):
		var projectile: ProjectileBase = entity as ProjectileBase
		if projectile != null and not projectile.spent:
			in_flight += 1
	if in_flight >= Tuning.MAX_THROWN:
		return false
	var throw_xvel: int = Tuning.THROW_XVEL * facing
	var throw_yvel: int = Tuning.AXE_YVEL
	var throw_yacc: int = Tuning.AXE_YACC
	if weapon == Defs.Weapon.BOOMERANG:
		throw_yvel = Tuning.BOOMERANG_YVEL
		throw_yacc = Tuning.BOOMERANG_YACC
	var pos: Vector2i = _weapon_anchor + Vector2i(Tuning.floor16(throw_xvel), Tuning.floor16(throw_yvel))
	level.spawn(id, pos, {
		"from_hero": true, "power": club_power, "xvel": throw_xvel, "yvel": throw_yvel, "yacc": throw_yacc,
		"facing": "l" if facing < 0 else "r",
	})
	return true


# --- Hang-glider (PHYSICS.md 13.2) ------------------------------------------------------------------------------------

## State dispatch while carrying the glider. Folded: walk and jump have their own rules, hurt runs nothing and
## every other state runs the crouch handler (so no strikes). Open: the handlers are skipped altogether.
func _run_glider(selected: int) -> void:
	glide &= 1
	if glide != 0:
		handler = selected
		_steer_glider()
		return
	if yvel > Tuning.GLIDER_AUTO_OPEN_YVEL_EXCL:
		_open_glider()
	match selected:
		Defs.HeroState.WALK:
			if absi(xvel) >= Tuning.GLIDER_RUNUP_MIN_XVEL:
				glider_runup = mini(glider_runup + 1, Tuning.IDLE_TIMER_MAX)
			_walk_body()
		Defs.HeroState.JUMP:
			if glider_runup >= Tuning.GLIDER_RUNUP_TICKS:
				handler = Defs.HeroState.JUMP
				glider_runup = 0
				glider_lift = Tuning.GLIDER_LIFT_START
				sim_pos.y += Tuning.GLIDER_TAKEOFF_DY
				_open_glider()
				_wind()
				_wind()
			else:
				_jump_body(true)
		Defs.HeroState.HURT:
			handler = Defs.HeroState.HURT
		_:
			_crouch_body()


## One tick under the open glider: UP pulls the nose up and spends lift to climb, neutral bleeds lift, DOWN
## dives with full gravity and, nose down at speed, refills the lift.
func _steer_glider() -> void:
	if (_raw_flags & Defs.IN_UP) != 0:
		if glider_tilt >= Tuning.GLIDER_TILT_MAX:
			if yvel > Tuning.GLIDER_STALL_MIN_YVEL_EXCL:
				glide |= 2
		else:
			glider_tilt += 1
		if glider_lift > 0:
			glider_lift -= 1
			if glider_tilt >= Tuning.GLIDER_CLIMB_MIN_TILT:
				yvel = Tuning.GLIDER_CLIMB_YVEL
			return
	if (_raw_flags & Defs.IN_DOWN) == 0:
		glider_lift = maxi(glider_lift - 1, 0)
		return
	if glider_tilt > 0:
		glider_tilt -= 1
	glide |= 2
	if glider_tilt > 1:
		return
	var speed: int = absi(Tuning.floor16(xvel))
	if glider_lift < speed * Tuning.GLIDER_LIFT_REFILL_MAX_FACTOR:
		glider_lift += speed


func _open_glider() -> void:
	if glide == 0:
		glide = 1
		Events.glider_state_changed.emit(true, true)


func _close_glider() -> void:
	if glide != 0:
		glide = 0
		Events.glider_state_changed.emit(Game.has_glider, false)


# --- Tile collision (PHYSICS.md 11.2) ---------------------------------------------------------------------------------

func _collide(level: LevelBase, body_height: int) -> void:
	var grid: TileGrid = level.grid
	var col: int = Tuning.to_cell(sim_pos.x)
	var row: int = Tuning.to_cell(sim_pos.y)
	var edge: int = 0
	if xvel > 0:
		edge = Tuning.WALL_PROBE
	elif xvel < 0:
		edge = -Tuning.WALL_PROBE
	# 1. Out of range: instant death.
	if _left_the_playfield(level, col, row):
		return
	var was_grounded: bool = grounded
	var airborne: bool = false
	var above_map: bool = sim_pos.y <= -1
	if above_map:
		# 3. Above the map there are no tiles: only the airborne step.
		_airborne_step()
	else:
		# 4. Floor under the feet point.
		var floor_value: int = grid.floor_at(col, row)
		if floor_value == TileGrid.FLOOR_EMPTY:
			if yvel == 0 and grid.has_profile(col, row + 1) \
					and grid.surface_offset(col, row + 1, sim_pos.x) < Tuning.TILE:
				# Glued to descending ground: step down one row and land there.
				sim_pos.y += Tuning.TILE
				airborne = _land(level, col, row + 1, was_grounded)
			else:
				airborne = true
		elif floor_value == TileGrid.FLOOR_DEADLY:
			kill(_tile_death_cause(grid, col, row))
			return
		elif floor_value == TileGrid.FLOOR_HATCH and drop_timer != 0:
			ice = 0
			airborne = true
		elif floor_value != TileGrid.FLOOR_NOTHING:
			airborne = _land(level, col, row, was_grounded)
			ice = TileGrid.floor_ice(floor_value)
		# 5. Ceiling block: rising or grounded, never while falling.
		if row >= Tuning.HEAD_PROBE_ROWS and yvel <= 0:
			_ceiling_block(grid, col, row)
			if dead:
				return
	# 6. Airborne result.
	if airborne:
		if on_platform:
			no_jump = maxi(no_jump - 1, 0)
			jump_ticks = 0
			last_ground_y = sim_pos.y
			fall_ticks = 0
		else:
			_airborne_step()
			if yvel > 0:
				fall_ticks += 1
	else:
		fall_ticks = 0
	grounded = on_platform if airborne else not above_map
	if sim_pos.y <= 0:
		return
	# 7. Wall probe: 9 px ahead, in the row above the feet row only.
	var probe_col: int = Tuning.to_cell(sim_pos.x + edge)
	var side: int = grid.side_at(probe_col, row - 1)
	if side == TileGrid.SIDE_WALL:
		sim_pos.x -= Tuning.floor16(xvel)
		xvel = 0
	elif side == TileGrid.SIDE_DEADLY:
		kill(_tile_death_cause(grid, probe_col, row - 1))
		return
	# 8. Body probes: the rows above, as far as the sprite reaches. Only deadly tiles act here.
	var remaining: int = body_height - Tuning.TILE
	var probe_row: int = row - 2
	while probe_row >= 0 and remaining > 0:
		if grid.side_at(probe_col, probe_row) == TileGrid.SIDE_DEADLY:
			kill(_tile_death_cause(grid, probe_col, probe_row))
			return
		remaining -= Tuning.TILE
		probe_row -= 1


## Instant deaths of PHYSICS.md 10.3 that do not depend on a tile. Returns true when he died.
func _left_the_playfield(level: LevelBase, col: int, row: int) -> bool:
	var view: Rect2i = level.get_view_rect()
	var cell: Vector2i = level.get_camera_cell()
	# The original limits are one screen (20 x 11 tiles); a larger view keeps "one screen" (ARCHITECTURE 2).
	var max_rows: int = maxi(Tuning.DEATH_ROWS_FROM_CAMERA, Tuning.to_cell(view.size.y))
	var max_cols: int = maxi(Tuning.DEATH_COLS_FROM_CAMERA, Tuning.to_cell(view.size.x + Tuning.TILE - 1))
	if absi(row - cell.y) > max_rows or absi(col - cell.x) > max_cols:
		kill(&"off_screen")
		return true
	if (level.scroll_flags & Defs.SCROLL_AUTO_DOWN) != 0 and sim_pos.y < view.position.y:
		kill(&"off_screen")
		return true
	if sim_pos.y > level.grid.height_px() + Tuning.PIT_DEPTH_PX:
		kill(&"pit")
		return true
	return false


func _tile_death_cause(grid: TileGrid, col: int, row: int) -> StringName:
	match grid.get_char(col, row):
		TileGrid.CH_LIQUID:
			return &"liquid"
		TileGrid.CH_KILL:
			return &"pit"
	return &"spikes"


## LAND of PHYSICS.md 11.2 step 4 on the floor tile (col, row). Returns true when he is airborne after it.
func _land(level: LevelBase, col: int, row: int, was_grounded: bool) -> bool:
	var grid: TileGrid = level.grid
	ice = 0
	if yvel < 0:
		return true  # floors are one-way
	_close_glider()
	sim_pos.y = Tuning.tile_top(sim_pos.y)
	if grid.has_profile(col, row):
		var offset: int = grid.surface_offset(col, row, sim_pos.x)
		var descent: int = Tuning.floor16(yvel)
		if descent > 0 and offset >= descent:
			offset = descent
		sim_pos.y += offset
	elif grid.has_profile(col, row - 1):
		# Walk up onto a slope that starts in the tile above.
		var above: int = grid.surface_offset(col, row - 1, sim_pos.x)
		if above < Tuning.TILE:
			sim_pos.y += above - Tuning.TILE
	# Landing rules of PHYSICS.md 6.5.
	if fall_ticks > Tuning.SOFT_LANDING_MAX_FALL_TICKS:
		_spawn_fx(FX_DUST, sim_pos)
		var long_fall: bool = fall_ticks > Tuning.HARD_LANDING_MIN_FALL_TICKS_EXCL
		if long_fall:
			land_pose = LAND_POSE_TICKS
			Audio.play_sfx(Sfx.LAND)
		if sim_pos.y - last_ground_y >= Tuning.DROP_MIN_PX and yvel >= Tuning.DROP_MIN_YVEL:
			last_ground_y = sim_pos.y
			var shook: bool = false
			if fall_ticks >= Tuning.SHAKE_MIN_FALL_TICKS and yvel > Tuning.SHAKE_MIN_YVEL_EXCL:
				level.request_shake(Tuning.SHAKE_LANDING)
				shook = true
			if long_fall:
				# Hard landing: a small hop, unless the level has the low camera band.
				if (level.scroll_flags & Defs.SCROLL_LOW_BAND) == 0:
					yvel = Tuning.HARD_LANDING_HOP
				fall_ticks = 0
				_hard_landed = true
				_spawn_fx(FX_RING, sim_pos)
				Events.player_landed.emit(true, shook)
				return false
	if yvel > 0 or not was_grounded:
		Events.player_landed.emit(false, false)
	# Soft landing.
	yvel = 0
	no_jump = maxi(no_jump - 1, 0)
	jump_ticks = 0
	last_ground_y = sim_pos.y
	return false


func _ceiling_block(grid: TileGrid, col: int, row: int) -> void:
	var ceiling: int = grid.ceiling_at(col, row - Tuning.HEAD_PROBE_ROWS)
	if ceiling == TileGrid.CEILING_SOLID:
		if yvel != 0:
			# Head bump: stopped and pushed down to the next row boundary.
			yvel = 0
			sim_pos.y = Tuning.tile_top(sim_pos.y) + Tuning.TILE
			bumped_head = true
	elif ceiling == TileGrid.CEILING_DEADLY:
		kill(&"spikes")
		return
	# Corner slip: inside a wall tile he slides out sideways, 2 px per tick.
	if (grid.side_at(col, row - 1) & TileGrid.SIDE_WALL) != 0 and sim_pos.y > 0:
		var step: int = -1 if xvel > 0 else 1
		if grid.side_at(col + step, row - 1) == TileGrid.SIDE_OPEN:
			sim_pos.x += Tuning.CORNER_SLIP * step
		elif grid.side_at(col - step, row - 1) == TileGrid.SIDE_OPEN:
			sim_pos.x -= Tuning.CORNER_SLIP * step


## No ground: air control and gravity, applied AFTER the position was integrated (PHYSICS.md 5.2). Falling
## arms the jump lock-out, except with the glider, whose jump ignores it.
func _airborne_step() -> void:
	_accel(Tuning.WALK_CAP)
	_gravity()
	if yvel > 0 and not Game.has_glider:
		no_jump = Tuning.NO_JUMP_TICKS


# --- Timers and boxes -------------------------------------------------------------------------------------------------

func _tick_timers(level: LevelBase) -> void:
	if charge > 0:
		charge -= 1
	if swing_lock > 0:
		swing_lock -= 1
	if drop_timer > 0:
		drop_timer -= 1
	if land_pose > 0:
		land_pose -= 1
	level.tick_shake_timer()
	if feast > 0:
		feast -= 1
		if feast == Tuning.FEAST_WARN_TICKS_BEFORE_END:
			level.request_shake(Tuning.FEAST_WARN_SHAKE)
			Audio.play_sfx(Sfx.QUAKE)
		elif feast == 0:
			_stop_feast_music()
			Events.feast_changed.emit(0)


## Sprite box of the pose of this tick, used by every sprite contact (PHYSICS.md 2.1).
func _update_box() -> void:
	if state == Defs.HeroState.HURT:
		set_box(Tuning.HERO_BOX_HURT)
	elif _hard_landed:
		set_box(Tuning.HERO_BOX_FALL)
	elif not grounded and yvel > 0 and not attack_gate:
		var long_fall: bool = fall_ticks >= Tuning.FALL_WIDE_SPRITE_TICKS
		set_box(Tuning.HERO_BOX_FALL_LONG if long_fall else Tuning.HERO_BOX_FALL)
	elif handler == Defs.HeroState.JUMP:
		set_box(Tuning.HERO_BOX_JUMP_UP if jump_ticks <= Tuning.HERO_JUMP_TALL_BOX_TICKS else Tuning.HERO_BOX_JUMP_TOP)
	elif is_low():
		set_box(Tuning.HERO_BOX_CROUCH)
	elif grounded:
		set_box(Tuning.HERO_BOX_STAND)


# =================================================================================================================
# Phase CONTACT_ENEMIES (PHYSICS.md 9, 10.1; ARCHITECTURE 4.2)
# =================================================================================================================

func _contact_pass() -> void:
	var level: LevelBase = Game.level
	if dead or hit_timer != 0 or level == null:
		return
	var enemies: Array[SimEntity] = level.get_kind(Defs.Kind.ENEMY)
	for i: int in enemies.size():
		var enemy: EnemyBase = enemies[i] as EnemyBase
		if enemy == null or not enemy.contact_hurts or not enemy.is_targetable():
			continue
		if not Overlap.body(self, enemy, self):
			continue
		var stomp: bool = Overlap.stomp
		var depth: int = Overlap.depth
		if feast > 0:
			enemy.kill(&"feast", self)
			continue
		if stomp and yvel >= 0:
			if is_gliding():
				var dive: bool = yvel > Tuning.GLIDER_DIVE_MIN_YVEL_EXCL
				bounce(Tuning.GLIDER_BUMP_YVEL, depth)
				if dive:
					enemy.on_glider_stomp(self)
			else:
				_bounce_on(enemy, depth)
		elif hurt(enemy):
			enemy.on_hurt_hero(self)
		return


func _bounce_on(enemy: EnemyBase, depth: int) -> void:
	var up_held: bool = (_raw_flags & Defs.IN_UP) != 0
	bounce(Tuning.BOUNCE_YVEL_UP if up_held else Tuning.BOUNCE_YVEL, depth)
	var multiplier: int = enemy.on_bounced(self)
	Audio.play_sfx(Sfx.BOUNCE)
	_spawn_fx(FX_RING, sim_pos)
	Events.player_bounced.emit(enemy, multiplier)
	if multiplier > 0:
		Events.popup_requested.emit(&"multiplier", multiplier, Vector2i(sim_pos.x, sim_pos.y - box_h))


# =================================================================================================================
# Phase POST (PHYSICS.md 3 steps 14-15, 10.4)
# =================================================================================================================

func _post_step() -> void:
	if hit_timer > 0:
		hit_timer -= 1
	if dead and death_ticks < Tuning.DEATH_ANIM_TICKS:
		_death_step()
	if dead and death_ticks >= Tuning.DEATH_ANIM_TICKS:
		_refresh_visual()
		return
	anim_frame = _animator.update(self)
	if _animator.footstep:
		Audio.play_sfx(Sfx.FOOTSTEP)
	_refresh_visual()


## One tick of the death toss: no input, no tiles. After Tuning.DEATH_ANIM_TICKS the level takes over.
func _death_step() -> void:
	sim_pos.x += _death_dx
	sim_pos.y += _death_vy
	_death_vy = mini(_death_vy + 1, Tuning.DEATH_VY_MAX)
	death_ticks += 1
	var level: LevelBase = Game.level
	if level != null:
		level.tick_shake_timer()
	if death_ticks == Tuning.DEATH_ANIM_TICKS:
		Events.player_death_finished.emit()


# =================================================================================================================
# Helpers
# =================================================================================================================

func _scatter_bones(count: int) -> void:
	var level: LevelBase = Game.level
	if count <= 0 or level == null or not Spawner.exists(ID_BONE):
		return
	for i: int in count:
		level.spawn(ID_BONE, sim_pos + Vector2i(0, -Tuning.TILE / 2), {"dropped": true, "fan": i})


func _spawn_fx(id: StringName, pos: Vector2i) -> void:
	var level: LevelBase = Game.level
	if level != null and Spawner.exists(id):
		level.spawn_fx(id, pos)


func _stop_feast_music() -> void:
	if Audio.get_music_context() == Sfx.MUSIC_FEAST:
		Audio.pop_music()


func _on_weapon_changed(weapon: int) -> void:
	if _sprite != null and weapon >= 0 and weapon < weapon_sheets.size() and weapon_sheets[weapon] != null:
		_sprite.texture = weapon_sheets[weapon]


func _on_exit_reached(_exit_kind: StringName) -> void:
	victorious = true


## Show the picture of this tick: sheet frame, mirroring, hurt blink, glider overlay.
func _refresh_visual() -> void:
	if _sprite != null:
		_sprite.frame = anim_frame
		_sprite.flip_h = facing < 0
		_sprite.visible = not dead or death_ticks < Tuning.DEATH_ANIM_TICKS
		var ghost: bool = hit_timer > 0 and not dead and Sim.tick % Tuning.BLINK_PERIOD != 0
		_sprite.modulate.a = BLINK_ALPHA if ghost else 1.0
	if _glider_sprite != null:
		_glider_sprite.visible = Game.has_glider and not dead
		_glider_sprite.flip_h = facing < 0
		_glider_sprite.position.y = float(GLIDER_HANDS_Y if is_gliding() else GLIDER_CARRY_Y)

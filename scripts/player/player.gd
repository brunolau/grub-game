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

## 2.0 (co-op and versus only): an emote bubble appeared over this hero (HeroParty.Emote; DESIGN.md D.11, E.9).
signal emoted(kind: int)

const ID_AXE: StringName = &"projectiles/hero_axe"
const SPEAR_SCRIPT: String = "res://scripts/projectiles/hero_spear.gd"
static var _spear: Script = null
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
## Presentation of the crouch charge (PHYSICS.md 8.5): the original shows nothing, the remake lets the hero glow
## while his next blow is charged (x4) and chimes once when the charge is full, so the mechanic can be found.
const CHARGE_TINT: Color = Color(1.5, 1.4, 1.1)
const CHARGE_FULL_TINT: Color = Color(1.9, 1.8, 1.4)
var _charge_chimed: bool = false

## 2.0 components (docs/expansion/PLAN.md P0.8): the files player-A / player-B fill in during phase 1 without
## touching this one. Each runs its hooks only while its `active` is true; every one stays off for a single-player
## Book I hero, so the 1.0 hero runs exactly the 1.0 code (a few bool tests per tick).
## The weapon belt and Swap (player-B, scripts/player/hero_belt.gd, PHYSICS.md C.1-C.2).
var hero_belt: HeroBelt = HeroBelt.new(self)
## Vines and the CLIMB state (player-B, hero_climb.gd, C.4).
var hero_climb: HeroClimb = HeroClimb.new(self)
## The rider's side of Chomper (player-B, hero_mount.gd, C.9).
var hero_mount: HeroMount = HeroMount.new(self)
## The party rules on the hero's side: egg, shield, curl and ball, bat and hatch, edge walls (player-A,
## hero_party.gd, C.10-C.14).
var hero_party: HeroParty = HeroParty.new(self)

## 2.0 state of the hero's own update (default = 1.0; only the party component changes them):
## the hurt state lasts while hit_timer >= this (Tuning.HIT_STUN_MIN; a versus hurt: VersusTuning.STUN_HIT_TIMER_MIN).
var _stun_min: int = Tuning.HIT_STUN_MIN
## Facing before step 8b of this tick (a curled hero, a ball and an egg ignore the keys: they put it back).
var _facing_at_tick_start: int = 1
## True when this tick's tile collision met a wall in the wall probe (11.2 #7): a batted ball uncurls there.
var wall_bumped: bool = false
## The grid whose TileGrid.x_max_excl() [member _x_max] holds (step 8e asks it every tick; a grid's width never
## changes).
var _x_max_grid: TileGrid = null
var _x_max: int = 0

## wf11 rulings for a hero of a CO-OP PARTY (hero_party.coop; every member below keeps its default in single-player
## and versus, whose code paths only compare them):
## R3, the WARD (LevelBase.in_ward): the enemies whose heads gave him nothing - he came down on each inside a ward,
## the stomp was counted against it, and until their boxes part nothing more happens between the two (it gives no lift
## and does not hurt him while he falls through it). Empty = none; more than one when bodies overlap.
var _ward_heads: Array[EnemyBase] = []
## Phase 4 ruling Q4 (DESIGN.md G87), THE GRACE IS SHORT: the clock of each head of [member _ward_heads] (same index;
## PlayerBase.ward_grace_step) - WARD_FALLING while the fall of that stomp lasts, then the ticks since he first had
## ground under him again. Past PartyTuning.WARD_GRACE_TICKS the head is forgotten although the boxes still overlap:
## standing inside a keeper is no shelter ([method _ward_heads_check]).
var _ward_since: PackedInt32Array = PackedInt32Array()
## R3: true when the club box of this tick's weapon pass was used up on an enemy (not on a hittable): the hit whose
## pogo a ward takes away - and that enemy (for the measurement trace only).
var _club_hit_enemy: bool = false
var _club_enemy: EnemyBase = null
## R5, "a closed door passes nobody": his feet point at the end of the last tick on which his body cell (feet column,
## the wall-probe row above the feet row) was no wall - the side he came from ([method _hold_the_side]).
var _free_x: int = 0
var _free_y: int = 0
## R5: farther than this from his last free place (px, either axis) he was not pushed there - he was PUT there (a gate,
## a travel, a tool that sets his feet point): a new place to come from. No mover carries a hero that far in a tick
## (PartyTuning.MOVE_MAX_PX_PER_TICK is 18, a knock-back's first tick 20), and a solid of up to three cells lies within it.
const DOOR_REACH_PX: int = 4 * Tuning.TILE

## What _refresh_visual() last wrote to the sprites (the performance pass: no engine property is read or written on a
## tick on which the picture did not change).
var _shown_frame: int = -1
var _shown_flip: bool = false
var _shown_visible: bool = true
var _shown_alpha: float = 1.0
var _shown_tint: Color = Color.WHITE
## True while [member _shown_tint] is not white.
var _tinted: bool = false
var _glider_shown: bool = false
var _glider_flip: bool = false
var _glider_y: int = GLIDER_CARRY_Y


func _ready() -> void:
	_sprite = get_node_or_null(^"Sprite") as Sprite2D
	_glider_sprite = get_node_or_null(^"GliderSprite") as Sprite2D
	if _sprite != null:
		_shown_frame = _sprite.frame
		_shown_flip = _sprite.flip_h
		_shown_visible = _sprite.visible
		_shown_alpha = _sprite.modulate.a
		_shown_tint = _sprite.self_modulate
		_tinted = _shown_tint != Color.WHITE
	if _glider_sprite != null:
		_glider_shown = _glider_sprite.visible
		_glider_flip = _glider_sprite.flip_h
		_glider_y = int(_glider_sprite.position.y)
	_on_weapon_changed(run.weapon)
	_refresh_visual()
	# 2.0: each component decides whether this level and mode need it (none does in Book I solo).
	var level: LevelBase = Game.level
	hero_party.setup(level)
	hero_mount.setup(level)
	hero_belt.setup(level)
	hero_climb.setup(level)
	if hero_party.active:
		apply_palette()


## 2.0 (DESIGN.md D.1, E.9): paint this hero in his slot's colour and loincloth pattern (HeroPalette.resolve: his run's
## choice or the slot default, arena swaps in versus). The 1.0 look - yellow with the spots - keeps no material at
## all; a single-player hero never calls it.
func apply_palette() -> void:
	if _sprite == null:
		return
	var look: Array = hero_party.palette()
	_sprite.material = HeroPalette.material_for(look[0], look[1], true)


func _enter_tree() -> void:
	# The sheet follows this hero's own hand (Game.run_weapon_changed of his slot; P1's is Game.weapon_changed too).
	if not Game.run_weapon_changed.is_connected(_on_run_weapon_changed):
		Game.run_weapon_changed.connect(_on_run_weapon_changed)
	if not Events.exit_reached.is_connected(_on_exit_reached):
		Events.exit_reached.connect(_on_exit_reached)


func _exit_tree() -> void:
	if Game.run_weapon_changed.is_connected(_on_run_weapon_changed):
		Game.run_weapon_changed.disconnect(_on_run_weapon_changed)
	if Events.exit_reached.is_connected(_on_exit_reached):
		Events.exit_reached.disconnect(_on_exit_reached)


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([
		Defs.Phase.WEAPONS, Defs.Phase.PLAYER, Defs.Phase.CONTACT_ENEMIES, Defs.Phase.POST,
	])


func _sim_tick(phase: int) -> void:
	match phase:
		Defs.Phase.WEAPONS:
			if hero_party.coop:
				# 2.0 IDLE rule (PlayerBase.note_own_input): his own slot's input of this tick, before anything reads it.
				note_own_input(GameInput.get_flags(slot))
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
	return run.has_glider


## Animation playing on this tick (a [enum HeroAnim.Anim]).
func get_anim() -> int:
	return _animator.anim


# =================================================================================================================
# Calls other modules make (PlayerBase contract)
# =================================================================================================================

func hurt(source: SimEntity, kind: int = Defs.HurtKind.ENEMY) -> bool:
	if dead or down or _level_completed():
		return false
	if slot != 0 and helper_ignores(kind):
		return false  # 2.0 Helper mode (PlayerBase.is_helper): enemies never hurt a co-op P2 who has it on
	var pierces_immunity: bool = kind == Defs.HurtKind.TRAP or kind == Defs.HurtKind.BOSS_PROJECTILE
	if hit_timer > 0 and not pierces_immunity:
		return false
	if feast > 0 and (kind == Defs.HurtKind.ENEMY or kind == Defs.HurtKind.RIVAL):
		return false
	# 2.0 components (off in single-player): a seated rider's hit is the mount's (PHYSICS.md C.9); a climb or a curl
	# ends on a hurt and may take it (C.4, C.11, the versus table C.14).
	if hero_mount.active and hero_mount.on_hurt(source, kind):
		return true
	if hero_climb.active and hero_climb.on_hurt(source, kind):
		return true
	if hero_party.active and hero_party.on_hurt(source, kind):
		return true
	var killed: bool = false
	var bones: int = 0
	match kind:
		Defs.HurtKind.BOSS_BODY:
			killed = run.lose_bone()
			var toward_right: bool = source == null or source.sim_pos.x <= sim_pos.x
			xvel = Tuning.BOSS_KNOCK_XVEL if toward_right else -Tuning.BOSS_KNOCK_XVEL
			ice = Tuning.ICE_MAX
		Defs.HurtKind.TRAP:
			bones = run.scatter_energy()
		Defs.HurtKind.BOSS_PROJECTILE:
			killed = run.lose_heart()
			if not killed:
				bones = Tuning.BONES_PER_HEART
		_:
			if run.has_glider:
				set_glider(false)
			else:
				killed = run.lose_heart()
			xvel = xvel * Tuning.HURT_XVEL_FACTOR
	hit_timer = Tuning.HIT_TIMER
	_stun_min = Tuning.HIT_STUN_MIN
	attack_gate = false
	_close_glider()
	yvel = Tuning.HURT_YVEL
	grounded = false
	Audio.play_sfx(Sfx.PLAYER_HURT if kind == Defs.HurtKind.ENEMY else Sfx.PLAYER_HURT_HEAVY)
	Events.player_hurt.emit(kind, source)
	Events.hero_hurt.emit(self, kind, source)
	_scatter_bones(bones)
	if killed:
		kill(&"enemy")
	return true


func kill(cause: StringName) -> void:
	if dead or down or _level_completed():
		return
	# 2.0: where and why the toss starts (the co-op egg appears there, PHYSICS.md C.12); a curl or a ride ends.
	death_origin = sim_pos
	death_cause = cause
	if hero_party.active:
		hero_party.on_killed(cause)
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
	# Death toss (PHYSICS.md 10.4): drifts toward the middle of the screen (the view he is drawn in), 14 px/tick up,
	# then falls away.
	death_ticks = 0
	_death_vy = Tuning.DEATH_VY_START
	_death_dx = Tuning.DEATH_DX
	var level: LevelBase = Game.level
	if level != null:
		var view: Rect2i = level.get_view_rect_of(self) if level.hero_count() <= 1 else level.get_party_frame()
		if sim_pos.x >= view.position.x + view.size.x / 2:
			_death_dx = -Tuning.DEATH_DX
	Audio.play_sfx(Sfx.PLAYER_DEATH)
	if cause == &"liquid" and level != null:
		# Into the water or the lava: the splash an enemy makes there too.
		var surface: int = Tuning.to_cell(sim_pos.y - 1) * Tuning.TILE
		if Spawner.exists(&"fx/splash"):
			level.spawn_fx(&"fx/splash", Vector2i(sim_pos.x, surface + 2),
					{"kind": "lava" if str(level.meta.get("liquid", "water")) == "lava" else "water"})
		Audio.play_sfx(Sfx.SPLASH)
	Events.player_died.emit(cause)
	Events.hero_died.emit(self, cause)


func start_feast(ticks: int = Tuning.FEAST_TICKS) -> void:
	super.start_feast(ticks)
	if ticks > 0:
		_start_feast_music()
	else:
		_stop_feast_music()


func set_glider(carrying: bool) -> void:
	glide = 0
	glider_lift = 0
	glider_tilt = Tuning.GLIDER_TILT_NEUTRAL
	glider_runup = 0
	if carrying:
		attack_gate = false  # no strikes with the glider: a swing in progress ends here
	run.set_glider(carrying)
	Events.glider_state_changed.emit(carrying, false)
	Events.hero_glider_state_changed.emit(self, carrying, false)
	_refresh_visual()


## 2.0 (PHYSICS.md C.12): an egg. After a death toss it appears where the toss started, clamped into the view; the
## leash and the voluntary egg make it where he is. The party component draws and moves it.
func go_down(cause: StringName) -> void:
	if down:
		return
	var from_toss: bool = dead
	super.go_down(cause)
	state = Defs.HeroState.IDLE
	handler = Defs.HeroState.IDLE
	death_ticks = 0
	looking = false
	charge = 0
	swing_lock = 0
	glider_runup = 0
	skidding = false
	panting = false
	land_pose = 0
	club_frame = Tuning.ClubFrame.NONE
	if hero_party.active:
		hero_party.on_down(cause, from_toss)
	else:
		set_box(HeroParty.egg_box())
	_refresh_visual()


## 2.0 (PHYSICS.md C.12): hatched again - the hero's box, his first frame, the shell left behind, a doze decision for
## his place (an egg is no hero rectangle).
func hatch(by: PlayerBase, hearts: int) -> void:
	if not down:
		return
	super.hatch(by, hearts)
	state = Defs.HeroState.IDLE
	handler = Defs.HeroState.IDLE
	set_box(Tuning.HERO_BOX_STAND)
	_animator.reset()
	anim_frame = _animator.frame
	if hero_party.active:
		hero_party.on_hatched(by)
	_refresh_visual()


## 2.0 (PHYSICS.md C.11): batted by `batter`'s front strike - a ball (the party component flies it).
func bat(p_xvel: int, p_yvel: int, batter: PlayerBase) -> void:
	super.bat(p_xvel, p_yvel, batter)
	hero_party.on_batted()


func holds_up() -> bool:
	return (_raw_flags & Defs.IN_UP) != 0


func x_commit_allows(x: int) -> bool:
	if not super.x_commit_allows(x):
		return false
	var level: LevelBase = Game.level
	return not hero_party.active or level == null or hero_party.edge_walls_allow(level, x)


func respawn_at(pos: Vector2i) -> void:
	if feast > 0:
		_stop_feast_music()
	_stun_min = Tuning.HIT_STUN_MIN
	wall_bumped = false
	_ward_heads.clear()
	_ward_since.clear()
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
	# 2.0 components (off in single-player).
	if hero_party.active:
		hero_party.on_respawn()
	if hero_mount.active:
		hero_mount.on_respawn()
	if hero_belt.active:
		hero_belt.on_respawn()
	if hero_climb.active:
		hero_climb.on_respawn()
	_refresh_visual()


# =================================================================================================================
# Phase WEAPONS (PHYSICS.md 3 step 2, 8.3)
# =================================================================================================================

func _weapon_pass() -> void:
	# The platform pass of this tick decides again whether he rides (PHYSICS.md 11.4).
	on_platform = false
	var level: LevelBase = Game.level
	if level == null or down:
		return
	var projectiles: Array[SimEntity] = level.get_kind(Defs.Kind.HERO_PROJECTILE)
	if projectiles.is_empty() and not club_box_active:
		return  # nothing in the air and no club box: the usual tick
	if hero_party.active:
		# 2.0 (off in single-player): a box first bats curled partners and hatches eggs (PHYSICS.md C.0 table).
		hero_party.weapon_pass(level)
	var enemies: Array[SimEntity] = level.get_kind(Defs.Kind.ENEMY)
	var hittables: Array[SimEntity] = level.get_kind(Defs.Kind.HITTABLE)
	for i: int in projectiles.size():
		# Only his own throws (a party of one owns every hero projectile: the 1.0 pass).
		var projectile: ProjectileBase = projectiles[i] as ProjectileBase
		if projectile != null and not projectile.spent and projectile.owner_slot == slot \
				and _projectile_hits(projectile, enemies, hittables):
			projectile.consume()
	if club_box_active and not dead and _club_hits(enemies, hittables):
		# One target per box; a hit in the air is the pogo (PHYSICS.md 9).
		club_box_active = false
		# 2.0 wf11 R3: inside a ward a club hit on an ENEMY gives a co-op hero no pogo (a hittable still does).
		if not (_club_hit_enemy and hero_party.coop and _in_ward(level)):
			notify_weapon_hit()
		elif (gate_rules_off & GATE_TRACE) != 0 and yvel != 0:
			_ward_trace(level, "no pogo off", _club_enemy)


func _club_hits(enemies: Array[SimEntity], hittables: Array[SimEntity]) -> bool:
	_club_hit_enemy = false
	for i: int in enemies.size():
		var enemy: EnemyBase = enemies[i] as EnemyBase
		if enemy == null or not enemy.awake or not enemy.is_targetable():
			continue
		if Overlap.weapon(club_box, club_box_xo, enemy) and enemy.take_hit(club_power, self):
			_on_weapon_connected(enemy, club_power)
			_club_hit_enemy = true
			_club_enemy = enemy
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
		if enemy == null or not enemy.awake or not enemy.is_targetable():
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
	var heavy: bool = run.weapon == Defs.Weapon.HAMMER or power > Tuning.WEAPON_POWER[run.weapon]
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
	if hit_stop > 0 and hero_party.active:
		# 2.0 versus hit-stop (PHYSICS.md C.14): this hero's PLAYER phase is skipped.
		hero_party.hold_hit_stop()
		return
	# 8b: input and facing (facing flips at once, even in mid-air and mid-swing). His own slot's flags (slot 0 is
	# GameInput.flags).
	_facing_at_tick_start = facing
	_raw_flags = GameInput.get_flags(slot) if control_enabled else 0
	var left: bool = (_raw_flags & Defs.IN_LEFT) != 0
	var right: bool = (_raw_flags & Defs.IN_RIGHT) != 0
	_lr_held = left or right
	if right and not left:
		facing = 1
	elif left and not right:
		facing = -1
	# 2.0 components (off in single-player, PLAN.md P0.8): the egg, the curl and the ball (party) and a seated rider
	# (mount) run the rest of this tick themselves; the belt reads Swap. An egg without its component only waits.
	if hero_party.active and hero_party.update(level):
		return
	if down:
		return
	if hero_mount.active and hero_mount.update(level):
		return
	if hero_belt.active:
		hero_belt.update(level)
	# 8c: state table, then the overrides swing_lock and hurt.
	input_flags = 0 if swing_lock != 0 else _raw_flags
	var selected: int = Tuning.STATE_LUT[input_flags & Defs.IN_STATE_MASK]
	if hit_timer >= _stun_min:
		selected = Defs.HeroState.HURT
	state = selected
	# 2.0 (off without vines): the vine grab and the CLIMB state replace 8d-8g (PHYSICS.md C.4).
	if hero_climb.active and hero_climb.update(level):
		return
	# 8d: handler.
	if run.has_glider:
		_run_glider(selected)
	else:
		_run_handler(selected)
	# 8e: x step, committed only inside the level bounds (2.0: and inside this tick's fence - edge walls, raft rails;
	# never fenced in single-player); 8f: y step, unconditional. (`v >> 4` is Tuning.floor16(v), written out on the
	# hero's per-tick path - the two-hero performance pass, PLAN.md P2.12; the same integer arithmetic.)
	var next_x: int = sim_pos.x + (xvel >> 4)
	var grid: TileGrid = level.grid
	if grid != _x_max_grid:
		_x_max_grid = grid  # TileGrid.x_max_excl() depends on the grid's width only: asked once per grid
		_x_max = grid.x_max_excl()
	if next_x >= Tuning.X_MIN and next_x < _x_max:
		if not _fenced:
			sim_pos.x = next_x
		elif next_x >= _fence_left and next_x < _fence_right:  # fence_allows(next_x)
			sim_pos.x = next_x
		elif _fence_clamp and _fence_left < _fence_right:
			# 2.0 raft rails (PHYSICS.md C.7): clamped into the fence, never refused - a rider caught while his feet
			# are still outside it is pulled to its edge (wf9 D9b #3). The co-op edge walls refuse (C.13).
			sim_pos.x = clampi(next_x, _fence_left, _fence_right - 1)
	_fenced = false  # clear_fence(): a fence lasts for this tick's x step
	_fence_clamp = false
	sim_pos.y += yvel >> 4
	# 8g: tile collision.
	var low: bool = selected == Defs.HeroState.CRAWL or selected == Defs.HeroState.CROUCH
	_collide(level, Tuning.HERO_PROBE_H_CROUCH if low else Tuning.HERO_PROBE_H_STAND)
	if dead:
		return
	# 8h: the glider nose returns to neutral; 8i: timers.
	var steering: bool = (_raw_flags & (Defs.IN_UP | Defs.IN_DOWN)) != 0
	if run.has_glider and not steering and glider_tilt != Tuning.GLIDER_TILT_NEUTRAL:
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
## (`ACCEL >> ice` is Tuning.accel_step(ice), written out: these primitives run several times per hero and tick.)
func _accel(limit: int) -> void:
	var value: int = xvel
	if _lr_held:
		value += facing * (Tuning.ACCEL >> ice)
	xvel = clampi(value, -limit, limit)


## FRICTION: |xvel| shrinks by one braking step (Tuning.friction_step(ice) = FRICTION >> ice), not below zero.
func _friction() -> void:
	var magnitude: int = maxi(absi(xvel) - (Tuning.FRICTION >> ice), 0)
	xvel = -magnitude if xvel < 0 else magnitude


## WIND: the level's wind pushes left (wind >> WIND_SHIFT, Tuning.shr); without wind this is only the floor on
## leftward speed. 2.0 co-op: a hero in a crouching partner's lee feels no wind (LevelBase.wind_for; the PartyDriver
## writes LevelBase.lee_mask, which is 0 on every single-player tick - then this reads the level's wind, no call).
func _wind() -> void:
	var level: LevelBase = Game.level
	if level != null:
		var wind: int = level.wind if level.lee_mask == 0 else level.wind_for(self)
		xvel -= wind >> Tuning.WIND_SHIFT
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
		if charge > Tuning.CHARGE_STEP_MAX_AT and not _charge_chimed:
			_charge_chimed = true
			Audio.play_sfx(Sfx.PICKUP_LETTER)


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
	_accel(walk_cap)
	_wind()
	_loaded_anim = Defs.HeroState.WALK


func _handle_jump() -> void:
	if attack_gate:
		_handle_strike(_loaded_anim)
	elif no_jump != 0:
		_idle_body()
	else:
		# 2.0: a Totem carrier's impulses are halved (PHYSICS.md C.10); never in single-player.
		_jump_body(totem_rider != null)


## The jump handler proper. It runs whether or not he stands on the ground: the impulse table simply continues
## where `jump_ticks` stopped, and after it gravity is applied a second time. `halved` = carrying the glider (2.0: or
## a Totem rider). 2.0 hooks (1.0 values in single-player): impulses only while n < jump_impulse_ticks (tar), scaled by
## jump_impulse_quarters / 4 (a heavy versus stack).
func _jump_body(halved: bool) -> void:
	handler = Defs.HeroState.JUMP
	skidding = false
	panting = false
	on_platform = false
	var n: int = jump_ticks
	jump_ticks += 1
	if n < Tuning.JUMP_IMPULSE_TICKS:
		var impulse: int = Tuning.JUMP_IMPULSES[n] if n < jump_impulse_ticks else 0
		if jump_impulse_quarters != 4:
			impulse = (impulse * jump_impulse_quarters) >> 2
		yvel += (impulse >> 1) if halved else impulse
	else:
		_gravity()
	if (xvel & 0xFFFF) < Tuning.JUMP_HELD_CAP:  # Tuning.unsigned_below(xvel, JUMP_HELD_CAP)
		_accel(Tuning.JUMP_HELD_CAP)
	else:
		_friction()
	_loaded_anim = Defs.HeroState.JUMP
	_wind()
	_wind()
	if n == 0:
		Audio.play_sfx(Sfx.JUMP)
		Events.player_jumped.emit()
		Events.hero_jumped.emit(self)


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
	if strike_tick == 0 and hero_party.active:
		# 2.0 versus: a swing or a throw ends the hurt immunity and the spawn shield (PHYSICS.md C.14).
		hero_party.on_strike_started()
	var frame: int = frames[strike_tick]
	var last: bool = strike_tick == frames.size() - 1
	strike_tick += 1
	_friction()
	idle_timer = mini(idle_timer + 1, Tuning.IDLE_TIMER_MAX)
	var weapon: int = run.weapon
	# The charge multiplier is evaluated on every tick of the swing (PHYSICS.md 8.5).
	club_power = Tuning.WEAPON_POWER[weapon] * (Tuning.CHARGE_MULTIPLIER if charge != 0 else 1)
	attack_gate = not last
	if last:
		swing_lock = Tuning.WEAPON_LOCK[weapon]
		# (2.0 wf11 R1: no hop in the flight a spring gave a co-op hero - PlayerBase.launch_hold, false in single-player.)
		if not on_platform and not launch_hold:
			yvel += hop
		if kind == Defs.HeroState.LOW_STRIKE and Sim.tick % Tuning.SKID_DUST_PERIOD == 0:
			_spawn_fx(FX_DUST, sim_pos)
		Events.player_struck.emit(kind, weapon)
		Events.hero_struck.emit(self, kind, weapon)
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
	var base_x: int = sim_pos.x + (xvel >> 4)  # Tuning.floor16
	var base_y: int = sim_pos.y + (yvel >> 4)
	club_box_xo = origin.x - rect.position.x
	club_origin = Vector2i(base_x + facing * origin.x, base_y + origin.y)
	club_box = Rect2i(club_origin.x - club_box_xo, base_y + rect.position.y, rect.size.x, rect.size.y)
	club_box_active = true
	club_frame = frame
	_weapon_anchor = club_origin


## Throw the axe or the boomerang (PHYSICS.md 8.4). Returns false when Tuning.MAX_THROWN of his own are already in
## flight (each hero of a party has his own; a party of one owns every hero projectile, as in 1.0).
func _throw(weapon: int) -> bool:
	if weapon == Defs.Weapon.SPEAR:
		# 2.0 (PHYSICS.md C.3): the spear is player-B's projectile with its own count rules; bound late, so a broken or
		# missing spear script never stops this file from compiling.
		var spear: Script = _spear_script()
		return spear != null and bool(spear.call(&"throw_from", self, _weapon_anchor, club_power))
	var level: LevelBase = Game.level
	var id: StringName = ID_BOOMERANG if weapon == Defs.Weapon.BOOMERANG else ID_AXE
	if level == null or not Spawner.exists(id):
		return false
	var in_flight: int = 0
	for entity: SimEntity in level.get_kind(Defs.Kind.HERO_PROJECTILE):
		var projectile: ProjectileBase = entity as ProjectileBase
		if projectile != null and not projectile.spent and projectile.owner_slot == slot:
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
		"facing": "l" if facing < 0 else "r", "owner": slot,
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
			elif launch_hold:
				_idle_body()  # 2.0 wf11 R1 (co-op springs; false in single-player): no jump table in a spring's flight
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
		Events.hero_glider_state_changed.emit(self, true, true)


func _close_glider() -> void:
	if glide != 0:
		glide = 0
		Events.glider_state_changed.emit(run.has_glider, false)
		Events.hero_glider_state_changed.emit(self, run.has_glider, false)


# --- Tile collision (PHYSICS.md 11.2) ---------------------------------------------------------------------------------

func _collide(level: LevelBase, body_height: int) -> void:
	var grid: TileGrid = level.grid
	# `v >> 4` is Tuning.to_cell(v) / floor16(v) throughout the collision (the same floor; P2.12 performance pass).
	var col: int = sim_pos.x >> 4
	var row: int = sim_pos.y >> 4
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
	var side_above: int = -1  # grid.side_at(col, row - 1) once step 5 read it
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
			# 2.0: a raft whose deck his feet just crossed catches him before the liquid under it (Raft.catch_sinking;
			# a level without rafts - every 1.0 level - kills as before).
			if grid.get_char(col, row) != TileGrid.CH_LIQUID or not Raft.catch_sinking(level, self):
				kill(_tile_death_cause(grid, col, row))
				return
			airborne = true
		elif floor_value == TileGrid.FLOOR_HATCH and drop_timer != 0:
			ice = 0
			airborne = true
		elif floor_value != TileGrid.FLOOR_NOTHING:
			airborne = _land(level, col, row, was_grounded)
			ice = TileGrid.floor_ice(floor_value)
		# 5. Ceiling block: rising or grounded, never while falling.
		if row >= Tuning.HEAD_PROBE_ROWS and yvel <= 0:
			side_above = _ceiling_block(grid, col, row)
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
	var probe_col: int = (sim_pos.x + edge) >> 4
	# The cell step 5 read for the corner slip is not read again (the grid does not change in between; P2.12).
	var side: int = side_above if probe_col == col and side_above >= 0 else grid.side_at(probe_col, row - 1)
	if side == TileGrid.SIDE_WALL:
		sim_pos.x -= xvel >> 4
		xvel = 0
		wall_bumped = true
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
	# 2.0: a party measures against the tribe camera's authentic frame (identical on every device, PHYSICS.md C.13) and
	# its cell, so a co-op or versus route replays the same on any screen; one hero keeps the 1.0 view and camera cell.
	var view: Rect2i
	var cell: Vector2i
	if level.hero_count() <= 1:
		view = level.get_view_rect()
		cell = level.get_camera_cell()
	else:
		view = level.get_party_frame()
		cell = Vector2i(view.position.x >> 4, view.position.y >> 4)
	# The original limits are one screen (20 x 11 tiles); a larger view keeps "one screen" (ARCHITECTURE 2).
	# (`>> 4` is Tuning.to_cell, written out: this runs for every hero on every tick.)
	var max_rows: int = maxi(Tuning.DEATH_ROWS_FROM_CAMERA, view.size.y >> 4)
	var max_cols: int = maxi(Tuning.DEATH_COLS_FROM_CAMERA, (view.size.x + Tuning.TILE - 1) >> 4)
	# 2.0 co-op: a hero above or below the tribe camera's frame while a partner of the tribe holds the view (a
	# partner's jump scrolled it up, or he dropped below a partner who stands) is the leash's case (C.13: an egg after
	# 121 / 73 ticks outside the view, the edge arrow counts down), not an instant down. The pit rule below still takes
	# a hero who falls out of the map. (G1 integration; the D5 / DB1 / world-B reports.) The same for the columns
	# (wf9 DB1): a hero CARRIED past the side of the frame (a ride platform, a current - his own steps stop at the
	# edge walls) while a partner holds the view is leashed, not downed at once.
	if absi(row - cell.y) > max_rows or absi(col - cell.x) > max_cols:
		if not _partner_holds_view(level):
			kill(&"off_screen")
			return true
	if (level.scroll_flags & Defs.SCROLL_AUTO_DOWN) != 0 and sim_pos.y < view.position.y:
		kill(&"off_screen")
		return true
	if sim_pos.y > level.grid.rows * Tuning.TILE + Tuning.PIT_DEPTH_PX:  # TileGrid.height_px()
		kill(&"pit")
		return true
	return false


## True in a co-op party (not versus) while another hero of the tribe (alive, hatched) is in the level: the tribe
## camera follows one anchor, so a hero may be out of its rows without having left the playfield.
func _partner_holds_view(level: LevelBase) -> bool:
	if Game.mode != Defs.GameMode.COOP or level.hero_count() <= 1:
		return false
	for other: PlayerBase in level.heroes:
		if other != self and other != null and not other.dead and not other.is_down():
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
	if glide != 0:
		_close_glider()
	sim_pos.y = sim_pos.y & ~15  # Tuning.tile_top
	# The surface profiles read once each (grid.has_profile / surface_offset, written out: every grounded tick).
	var profile: int = grid.profile_at(col, row)
	if profile != TileGrid.PROFILE_NONE:
		var offset: int = TileGrid.profile_offset(profile, sim_pos.x)
		var descent: int = yvel >> 4
		if descent > 0 and offset >= descent:
			offset = descent
		sim_pos.y += offset
	else:
		var above_profile: int = grid.profile_at(col, row - 1)
		if above_profile != TileGrid.PROFILE_NONE:
			# Walk up onto a slope that starts in the tile above.
			var above: int = TileGrid.profile_offset(above_profile, sim_pos.x)
			if above < Tuning.TILE:
				sim_pos.y += above - Tuning.TILE
	if curl == CURL_BALL:
		# 2.0: a batted ball lands softly (PHYSICS.md C.11); a line drive or a lob uncurls here.
		hero_party.ball_landed()
		return false
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
				Events.hero_landed.emit(self, true, shook)
				return false
	if yvel > 0 or not was_grounded:
		Events.player_landed.emit(false, false)
		Events.hero_landed.emit(self, false, false)
	# Soft landing.
	yvel = 0
	no_jump = maxi(no_jump - 1, 0)
	jump_ticks = 0
	last_ground_y = sim_pos.y
	return false


## Step 5. Returns grid.side_at(col, row - 1), which the corner slip reads (-1 when a deadly ceiling killed him).
func _ceiling_block(grid: TileGrid, col: int, row: int) -> int:
	var ceiling: int = grid.flags_at(col, row - Tuning.HEAD_PROBE_ROWS) & TileGrid.FLAG_CEILING_MASK  # ceiling_at
	if ceiling == TileGrid.CEILING_SOLID:
		if yvel != 0:
			# Head bump: stopped and pushed down to the next row boundary.
			yvel = 0
			sim_pos.y = (sim_pos.y & ~15) + Tuning.TILE  # the next row boundary (Tuning.tile_top + 16)
			bumped_head = true
	elif ceiling == TileGrid.CEILING_DEADLY:
		kill(&"spikes")
		return -1
	# Corner slip: inside a wall tile he slides out sideways, 2 px per tick.
	var side: int = grid.side_at(col, row - 1)
	if (side & TileGrid.SIDE_WALL) != 0 and sim_pos.y > 0:
		var step: int = -1 if xvel > 0 else 1
		if grid.side_at(col + step, row - 1) == TileGrid.SIDE_OPEN:
			sim_pos.x += Tuning.CORNER_SLIP * step
		elif grid.side_at(col - step, row - 1) == TileGrid.SIDE_OPEN:
			sim_pos.x -= Tuning.CORNER_SLIP * step
	return side


## No ground: air control and gravity, applied AFTER the position was integrated (PHYSICS.md 5.2). Falling
## arms the jump lock-out, except with the glider, whose jump ignores it.
func _airborne_step() -> void:
	if curl == CURL_BALL:
		# 2.0: a batted ball flies with gravity only (PHYSICS.md C.11).
		_gravity()
		return
	_accel(air_cap)
	_gravity()
	if yvel > 0 and not run.has_glider:
		no_jump = Tuning.NO_JUMP_TICKS


# --- Timers and boxes -------------------------------------------------------------------------------------------------

func _tick_timers(level: LevelBase) -> void:
	if charge > 0:
		charge -= 1
	if charge == 0:
		_charge_chimed = false
	if swing_lock > 0:
		swing_lock -= 1
	if drop_timer > 0:
		drop_timer -= 1
	if land_pose > 0:
		land_pose -= 1
	level.tick_shake_timer_by(self)
	if feast > 0:
		feast -= 1
		if feast == Tuning.FEAST_WARN_TICKS_BEFORE_END:
			level.request_shake(Tuning.FEAST_WARN_SHAKE)
			Audio.play_sfx(Sfx.QUAKE)
		elif feast == 0:
			_stop_feast_music()
			Events.feast_changed.emit(0)
			Events.hero_feast_changed.emit(self, 0)
	# 2.0 components (off in single-player): their own 8i timers (swap lock, re-grab and remount locks).
	if hero_belt.active:
		hero_belt.tick_timers()
	if hero_climb.active:
		hero_climb.tick_timers()
	if hero_mount.active:
		hero_mount.tick_timers()
	if hero_party.active and totem_drop_lock > 0:
		hero_party.tick_timers()  # its only timer: the Totem drop lock


## Sprite box of the pose of this tick, used by every sprite contact (PHYSICS.md 2.1).
## (SimEntity.set_box written out at the end: three fields - the two-hero performance pass, PLAN.md P2.12.)
func _update_box() -> void:
	var box: Vector3i
	if state == Defs.HeroState.HURT:
		box = Tuning.HERO_BOX_HURT
	elif _hard_landed:
		box = Tuning.HERO_BOX_FALL
	elif not grounded and yvel > 0 and not attack_gate:
		box = Tuning.HERO_BOX_FALL_LONG if fall_ticks >= Tuning.FALL_WIDE_SPRITE_TICKS else Tuning.HERO_BOX_FALL
	elif handler == Defs.HeroState.JUMP:
		box = Tuning.HERO_BOX_JUMP_UP if jump_ticks <= Tuning.HERO_JUMP_TALL_BOX_TICKS else Tuning.HERO_BOX_JUMP_TOP
	elif state == Defs.HeroState.CROUCH or state == Defs.HeroState.CRAWL:  # is_low()
		box = Tuning.HERO_BOX_CROUCH
	elif grounded:
		box = Tuning.HERO_BOX_STAND
	else:
		return  # airborne in none of the poses above (a bounce, a hop, a strike in the air): the last box stays
	box_w = box.x
	box_h = box.y
	box_xo = box.z


# =================================================================================================================
# Phase CONTACT_ENEMIES (PHYSICS.md 9, 10.1; ARCHITECTURE 4.2)
# =================================================================================================================

func _contact_pass() -> void:
	var level: LevelBase = Game.level
	if not _ward_heads.is_empty():
		_ward_heads_check()  # 2.0 wf11 R3 (co-op only): a head that gave nothing is forgotten once the boxes part
	# 2.0: an egg touches nothing and the hatch shield skips enemy contact like the hit timer (both never in
	# single-player).
	# 2.0: a seated rider's contacts are the mount's (PHYSICS.md C.9, objects/mount tests its ridden box).
	if dead or hit_timer != 0 or level == null or down or shield != 0 or mount != null:
		return
	if curl == CURL_BALL and hero_party.active:
		hero_party.ball_contacts(level)  # 2.0: a batted ball knocks small enemies (PHYSICS.md C.11)
		return
	var enemies: Array[SimEntity] = level.get_kind(Defs.Kind.ENEMY)
	var x: int = sim_pos.x
	var y: int = sim_pos.y
	for i: int in enemies.size():
		# Overlap.body's coarse reject first, before the cast and every other test (the performance pass, PLAN.md
		# P2.12: the list holds every enemy of the level, sleeping and dozing ones too, and nearly all are far from each
		# hero); the outcome is the same, since a pair this far apart never overlaps and the tests are pure.
		var at: Vector2i = enemies[i].sim_pos
		if absi(at.x - x) >= Tuning.OVERLAP_MAX_DX or absi(at.y - y) >= Tuning.OVERLAP_MAX_DY:
			continue
		var enemy: EnemyBase = enemies[i] as EnemyBase
		if enemy == null or not enemy.awake or not enemy.contact_hurts:
			continue
		if not enemy.is_targetable() or not Overlap.body(self, enemy, self):
			continue
		var stomp: bool = Overlap.stomp
		var depth: int = Overlap.depth
		if feast > 0:
			enemy.kill(&"feast", self)
			continue
		if not _ward_heads.is_empty() and _ward_heads.has(enemy):
			continue  # 2.0 wf11 R3 (never in single-player): he is still falling through a head that gave nothing
		if stomp and yvel >= 0:
			if hero_party.coop and _in_ward(level):
				_ward_stomp(enemy)  # 2.0 wf11 R3: in a ward a head gives no lift, no rest, no carry
			elif is_gliding():
				var dive: bool = yvel > Tuning.GLIDER_DIVE_MIN_YVEL_EXCL
				bounce(Tuning.GLIDER_BUMP_YVEL, depth, enemy)
				if dive:
					enemy.on_glider_stomp(self)
			else:
				_bounce_on(enemy, depth)
		elif hero_party.active and is_crouching() and _brace_stops(enemy):
			continue  # 2.0 Brace Wall (PHYSICS.md C.10): the heavy stopped dead, neither hero is touched
		elif hurt(enemy):
			enemy.on_hurt_hero(self)
		return


func _bounce_on(enemy: EnemyBase, depth: int) -> void:
	var up_held: bool = (_raw_flags & Defs.IN_UP) != 0
	# 2.0 G54: the head is passed, so a lift into rock slides him off this enemy (PlayerBase.bounce).
	bounce(Tuning.BOUNCE_YVEL_UP if up_held else Tuning.BOUNCE_YVEL, depth, enemy)
	var multiplier: int = enemy.on_bounced(self)
	Audio.play_sfx(Sfx.BOUNCE)
	_spawn_fx(FX_RING, sim_pos)
	Events.player_bounced.emit(enemy, multiplier)
	Events.hero_bounced.emit(self, enemy, multiplier)
	if multiplier > 0:
		Events.popup_requested.emit(&"multiplier", multiplier, Vector2i(sim_pos.x, sim_pos.y - box_h))


## 2.0 wf11 ruling R3, THE WARD (DESIGN.md G-rulings; LevelBase.in_ward, objects/x2_tablet): a hero of a co-op party
## came down on `enemy`'s head inside a ward - the contact that bounces him everywhere else. Here the head gives
## NOTHING: his velocity and his position stay as they are (no small bounce, no Up bounce, no glider bump, no standing,
## no being carried: he falls on through the body). The stomp still counts against the enemy exactly as elsewhere -
## EnemyBase.on_bounced (the bounce ladder and its number, a `daze` record dazed, the Relay Bounce) or, in a glider
## dive, on_glider_stomp - once: `enemy` joins [member _ward_heads], and until their boxes part or the grace runs out
## ([method _ward_heads_check]: that fall and PartyTuning.WARD_GRACE_TICKS after it, phase 4 Q4) the two do nothing more
## to each other, so it does not hurt him during that fall. The cue: a dust puff at the head and the dull thud of a
## landing. No Events.hero_bounced / player_bounced: he did not bounce.
func _ward_stomp(enemy: EnemyBase) -> void:
	_ward_heads.append(enemy)
	_ward_since.append(WARD_FALLING)
	if (gate_rules_off & GATE_TRACE) != 0:
		_ward_trace(Game.level, "no lift from", enemy)
	if is_gliding():
		if yvel > Tuning.GLIDER_DIVE_MIN_YVEL_EXCL:
			enemy.on_glider_stomp(self)
	else:
		var multiplier: int = enemy.on_bounced(self)
		if multiplier > 0:
			Events.popup_requested.emit(&"multiplier", multiplier, Vector2i(sim_pos.x, sim_pos.y - box_h))
	Audio.play_sfx(Sfx.LAND)
	_spawn_fx(FX_DUST, Vector2i(sim_pos.x, enemy.sim_pos.y - enemy.box_h))


## The measurement trace of PlayerBase.GATE_TRACE: one line per contact a ward changed.
func _ward_trace(level: LevelBase, what: String, enemy: EnemyBase) -> void:
	print("WARD %s t%d P%d at cell %d,%d (yvel %d, Up %s): %s %s at cell %d,%d" % [level.level_id, Sim.tick, slot + 1,
		sim_pos.x >> 4, (sim_pos.y - 1) >> 4, yvel, str((_raw_flags & Defs.IN_UP) != 0), what,
		String((enemy.get_script() as Script).resource_path).get_file().get_basename() if is_instance_valid(enemy) else "?",
		(enemy.sim_pos.x >> 4) if is_instance_valid(enemy) else -1,
		((enemy.sim_pos.y - 1) >> 4) if is_instance_valid(enemy) else -1])


## R3: true when his feet column lies in a ward of `level` (LevelBase.in_ward; asked for a hero of a co-op party only,
## and never while the rule is switched off for a measurement, PlayerBase.gate_rules_off).
func _in_ward(level: LevelBase) -> bool:
	return (gate_rules_off & GATE_R3) == 0 and level.in_ward(sim_pos.x)


## R3: an enemy stays in [member _ward_heads] only while it is there to touch and its box still overlaps his - the
## fall through it. Parted, dead, asleep, gone, or he himself out of play: forgotten, and the next contact is a new one.
## Phase 4 ruling Q4 (DESIGN.md G87), "the ward's grace is short": the pass also ends by the clock - it holds during
## THAT FALL (while he has no ground, platform, carrier, vine or saddle under him: the list that ends a launch's hold)
## and for PartyTuning.WARD_GRACE_TICKS ticks after the first tick on which he has one. On the tick after those - the
## 13th after the landing - the head is forgotten while the boxes still overlap, and this very contact pass finds that
## enemy's body as it finds any body: it hurts him (10.1). 12 ticks are 60 px at the walk cap: a hero who lands in a
## body and walks on never pays, one who stays does. A new landing on it from above is a new ward stomp.
func _ward_heads_check() -> void:
	var landed: bool = grounded or on_platform or mount != null or totem_carrier != null \
			or state == Defs.HeroState.CLIMB
	for i: int in range(_ward_heads.size() - 1, -1, -1):
		var enemy: EnemyBase = _ward_heads[i]
		var forget: bool = dead or down or not is_instance_valid(enemy) or enemy.dead or not enemy.awake \
				or not enemy.contact_hurts or not enemy.is_targetable() or not Overlap.body(self, enemy, self)
		if not forget:
			var since: int = ward_grace_step(_ward_since[i], landed)
			_ward_since[i] = since
			forget = ward_grace_over(since)
		if forget:
			_ward_heads.remove_at(i)
			_ward_since.remove_at(i)


## 2.0 Brace Wall (PHYSICS.md C.10), before an enemy's contact would hurt this crouching hero: when he braces with a
## partner (PlayerBase.brace_partner) and the enemy has the brace rule - a `heavy` enemy or a boss whose rule says so
## implements `brace_stop(hero: PlayerBase, partner: PlayerBase) -> bool` (enemies; true = it stopped dead and is
## dazed) - the contact is ignored. A lone croucher is trampled as usual.
func _brace_stops(enemy: EnemyBase) -> bool:
	if not enemy.has_method(&"brace_stop"):
		return false
	var partner: PlayerBase = brace_partner()
	if partner == null:
		return false
	if not bool(enemy.call(&"brace_stop", self, partner)):
		return false
	_party_cue(Sfx.BRACE)
	return true


# =================================================================================================================
# Phase POST (PHYSICS.md 3 steps 14-15, 10.4)
# =================================================================================================================

func _post_step() -> void:
	if hit_timer > 0:
		hit_timer -= 1
	if hero_party.active:
		# 2.0 (off in single-player): the shield, the egg, the leash count (PHYSICS.md C.0 table, POST).
		hero_party.post_step(Game.level)
		if hero_party.coop:
			_hold_the_side(Game.level)  # wf11 R5: a closed door passes nobody
			if launch_hold and (grounded or on_platform or down or dead or mount != null or totem_carrier != null
					or state == Defs.HeroState.CLIMB):
				launch_hold = false  # wf11 R1: ground, a platform, a carrier, a vine or a saddle ends a spring's flight
	if dead and death_ticks < Tuning.DEATH_ANIM_TICKS:
		_death_step()
	if (dead and death_ticks >= Tuning.DEATH_ANIM_TICKS) or down:
		_refresh_visual()
		return
	anim_frame = _animator.update(self)
	if _animator.footstep:
		Audio.play_sfx(Sfx.FOOTSTEP)
	_refresh_visual()


## 2.0 wf11 ruling R5, "A CLOSED DOOR PASSES NOBODY" (co-op only; POST, after every mover of the tick - his own step,
## platforms and rafts, a Totem carry, a head's slide, a grab, a knock-back). The hero's BODY CELL is his feet column in
## the wall-probe row (the row above his feet row, PHYSICS.md 11.2 #7). The 1.0 collision keeps a walker 10 px from a
## wall, but it can be talked into letting the feet point into a wall's column - a wind that pushes while he steers
## away creeps 1 px a tick past the probe (it takes back the speed AFTER the air step), a floor edge under a door lands
## him in the door's column - and then the corner slip (11.2 #5) carries him across a one-cell door to its far side
## (the w9_l2_coop 'brace' route of build/g3bv/evidence: through the keeper door, the Bull Rex alive). For a hero of a
## co-op party:
##  - a tick that ends with his body cell in a WALL which he entered SIDEWAYS - from another column than the one he
##    last stood free in ([member _free_x]) - puts him back at that x, the side he came from, and stops the speed that
##    carried him in;
##  - so does a tick that took him ACROSS a wall cell (two columns or more in one go with a wall between: a knock-back,
##    a launch, a carry).
## A wall cell entered from above or below, or one that came to him (a rising block), is left to the 1.0 corner slip.
## An egg and a hero in his death toss pass through everything; a seated rider is placed by his mount (his free x is
## only kept). Every discontinuous move starts afresh ([method teleport]; and any place farther than DOOR_REACH_PX
## from his last free one: he was put there, not pushed).
func _hold_the_side(level: LevelBase) -> void:
	if level == null or down or dead or (gate_rules_off & GATE_R5) != 0 \
			or absi(sim_pos.x - _free_x) > DOOR_REACH_PX or absi(sim_pos.y - _free_y) > DOOR_REACH_PX:
		_free_x = sim_pos.x
		_free_y = sim_pos.y
		return
	var grid: TileGrid = level.grid
	var col: int = sim_pos.x >> 4
	var row: int = sim_pos.y >> 4
	var from_col: int = _free_x >> 4
	var blocked: bool = row >= 1 and sim_pos.y > 0 and grid.side_at(col, row - 1) == TileGrid.SIDE_WALL
	if not blocked and row >= 1 and sim_pos.y > 0 and absi(col - from_col) >= 2:
		var step: int = 1 if col > from_col else -1
		var between: int = from_col + step
		while between != col:
			if grid.side_at(between, row - 1) == TileGrid.SIDE_WALL:
				blocked = true
				break
			between += step
	if not blocked:
		_free_x = sim_pos.x
		_free_y = sim_pos.y
		return
	if col == from_col or mount != null:
		return
	if signi(xvel) == signi(col - from_col):
		xvel = 0
	sim_pos.x = _free_x


## Every discontinuous move (a spawn, a respawn, a gate, the party's travel, a pull into a locked view) is a new
## place to come from for R5 ([method _hold_the_side]).
func teleport(pos: Vector2i) -> void:
	super.teleport(pos)
	_free_x = pos.x
	_free_y = pos.y


## One tick of the death toss: no input, no tiles. After Tuning.DEATH_ANIM_TICKS the level takes over: through
## Events.player_death_finished in single-player (1.0), by LevelBase.hero_death_finished(self) in a party.
func _death_step() -> void:
	sim_pos.x += _death_dx
	sim_pos.y += _death_vy
	_death_vy = mini(_death_vy + 1, Tuning.DEATH_VY_MAX)
	death_ticks += 1
	var level: LevelBase = Game.level
	if level != null:
		level.tick_shake_timer_by(self)
	if death_ticks == Tuning.DEATH_ANIM_TICKS:
		var party: bool = level != null and level.hero_count() > 1
		Events.player_death_finished.emit()
		Events.hero_death_finished.emit(self)
		if party and is_instance_valid(level):
			level.hero_death_finished(self)


# =================================================================================================================
# Helpers
# =================================================================================================================

## True once the hero reached an exit: the level only plays its exit animation (the closing iris) from here on,
## and nothing may hurt or kill him any more.
func _level_completed() -> bool:
	var level: LevelBase = Game.level
	return level != null and level.completed


func _scatter_bones(count: int) -> void:
	var level: LevelBase = Game.level
	if count <= 0 or level == null or not Spawner.exists(ID_BONE):
		return
	for i: int in count:
		level.spawn(ID_BONE, sim_pos + Vector2i(0, -Tuning.TILE / 2), {"dropped": true, "fan": i})


## The spear projectile's script (player-B, scripts/projectiles/hero_spear.gd: static throw_from), loaded on first use.
static func _spear_script() -> Script:
	if _spear == null and ResourceLoader.exists(SPEAR_SCRIPT):
		_spear = load(SPEAR_SCRIPT) as Script
	return _spear


func _spawn_fx(id: StringName, pos: Vector2i) -> void:
	var level: LevelBase = Game.level
	if level != null and Spawner.exists(id):
		level.spawn_fx(id, pos)


## The feast music: pushed in single-player (1.0); held while any hero of a party feasts (Audio.hold_music).
func _start_feast_music() -> void:
	var level: LevelBase = Game.level
	if level != null and level.hero_count() > 1:
		Audio.hold_music(Sfx.MUSIC_FEAST, self)
	else:
		Audio.push_music(Sfx.MUSIC_FEAST)


func _stop_feast_music() -> void:
	if Audio.is_music_held_by(Sfx.MUSIC_FEAST, self):
		Audio.release_music(Sfx.MUSIC_FEAST, self)
	elif Audio.get_music_context() == Sfx.MUSIC_FEAST:
		Audio.pop_music()


func _on_weapon_changed(weapon: int) -> void:
	if _sprite != null and weapon >= 0 and weapon < weapon_sheets.size() and weapon_sheets[weapon] != null:
		_sprite.texture = weapon_sheets[weapon]


func _on_run_weapon_changed(run_slot: int, weapon: int) -> void:
	if run_slot == slot:
		_on_weapon_changed(weapon)


func _on_exit_reached(_exit_kind: StringName) -> void:
	victorious = true


## Show the picture of this tick: sheet frame, mirroring, hurt blink, glider overlay.
func _refresh_visual() -> void:
	# Only changes are written, and the sprite's own properties are never read back: what was last written is kept in
	# the _shown_* fields (the A53 performance pass, PLAN.md P1.4 - an engine property access costs far more than a
	# script field, and this runs for every hero on every tick). 2.0: an egg hides the hero (the party component draws
	# the egg); the hatch shield blinks like the hit timer (both never in single-player).
	if _sprite != null:
		if _shown_frame != anim_frame:
			_shown_frame = anim_frame
			_sprite.frame = anim_frame
		var flip: bool = facing < 0
		if _shown_flip != flip:
			_shown_flip = flip
			_sprite.flip_h = flip
		var shown: bool = (not dead or death_ticks < Tuning.DEATH_ANIM_TICKS) and not down
		if _shown_visible != shown:
			_shown_visible = shown
			_sprite.visible = shown
		var ghost: bool = false
		if (hit_timer > 0 or shield > 0) and not dead:
			ghost = Sim.tick % Tuning.BLINK_PERIOD != 0
		var alpha: float = BLINK_ALPHA if ghost else 1.0
		if _shown_alpha != alpha:
			_shown_alpha = alpha
			var modulation: Color = _sprite.modulate
			modulation.a = alpha
			_sprite.modulate = modulation
		# The tint is white unless a charge glows: the usual tick only tests two fields ([member _tinted]).
		if charge > 0 and not dead:
			var tint: Color = Color.WHITE
			if _charge_chimed:
				tint = CHARGE_FULL_TINT if (Sim.tick >> 1) & 1 == 0 else CHARGE_TINT
			else:
				tint = Color.WHITE.lerp(CHARGE_TINT, minf(float(charge) / float(Tuning.CHARGE_STEP_MAX_AT), 1.0))
			if _shown_tint != tint:
				_shown_tint = tint
				_tinted = tint != Color.WHITE
				_sprite.self_modulate = tint
		elif _tinted:
			_shown_tint = Color.WHITE
			_tinted = false
			_sprite.self_modulate = Color.WHITE
	if _glider_sprite != null:
		var carried: bool = run.has_glider and not dead and not down
		if _glider_shown != carried:
			_glider_shown = carried
			_glider_sprite.visible = carried
		if carried:
			var flip: bool = facing < 0
			if _glider_flip != flip:
				_glider_flip = flip
				_glider_sprite.flip_h = flip
			var bar_y: int = GLIDER_HANDS_Y if is_gliding() else GLIDER_CARRY_Y
			if _glider_y != bar_y:
				_glider_y = bar_y
				_glider_sprite.position.y = float(bar_y)

class_name VersusGrudge
extends SimEntity
## A Grudge Pterodactyl (docs/expansion/DESIGN.md E.4, GAMEPLAY.md 13.10.4): in Last Caveman Standing a player who is
## out rides one along row 1 - Left / Right move it 4 px per tick, Strike drops a rock: a 10-tick squawk first, one
## rock per 73 ticks; a rock dazes the hero it lands on for 12 ticks and costs no heart (VersusHazard ROCK, the
## referee's daze). Owner: world-B (PLAN.md P2.4). Spawned by the referee; gone with the round.
##
## It reads its slot's flags (GameInput.get_flags) in PLAYER, after the heroes, so a bot or a human drives it like a
## hero. The spawn shield and the hurt immunity protect from its rocks (an arena hazard box, PHYSICS.md C.14).

const SPEED_PX: int = 4
## Feet y of the pterodactyl: the bottom of row 1 (row 0 is the HUD row).
const RIDE_Y: int = 2 * Tuning.TILE
const SHEET: String = "res://assets/sprites/enemies/pterodactyl.png"
const SHEET_FRAMES: Vector2i = Vector2i(8, 2)
const SHEET_OFFSET: Vector2 = Vector2(-72, -104)
const FLAP_TICKS: int = 4

## The out player's slot.
var slot: int = 0
## The referee (its rocks report to it).
var referee: Object = null
## Ticks of squawk left before the rock falls (0 = not squawking).
var squawk: int = 0
## Ticks until the next rock may be dropped.
var cooldown: int = 0
## Rocks dropped so far.
var rocks: int = 0

var _was_fire: bool = true
var _sprite: Sprite2D = null


func _init() -> void:
	set_box(Vector3i(32, 16, 16))


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.PLAYER])


func _ready() -> void:
	z_index = Defs.Z_FX
	add_to_group(VersusReferee.ROUND_GROUP)
	if ResourceLoader.exists(SHEET):
		_sprite = Sprite2D.new()
		_sprite.texture = load(SHEET) as Texture2D
		_sprite.centered = false
		_sprite.offset = SHEET_OFFSET
		_sprite.hframes = SHEET_FRAMES.x
		_sprite.vframes = SHEET_FRAMES.y
		_sprite.scale = Vector2(0.6, 0.6)
		_sprite.modulate = Color(0.8, 0.7, 1.0, 0.9)
		add_child(_sprite)


## Put it in the air above `x` for `p_slot` (before it enters the tree).
func setup(p_slot: int, x: int, p_referee: Object) -> VersusGrudge:
	slot = p_slot
	referee = p_referee
	spawn_setup(Vector2i(x, RIDE_Y), {})
	return self


func _sim_tick(_phase: int) -> void:
	var flags: int = GameInput.get_flags(slot)
	var dir: int = 0
	if flags & Defs.IN_LEFT:
		dir -= 1
	if flags & Defs.IN_RIGHT:
		dir += 1
	if dir != 0:
		facing = dir
	var view: Rect2i = VersusArena.view_rect()
	sim_pos.x = clampi(sim_pos.x + dir * SPEED_PX, view.position.x + box_xo, view.end.x - box_xo)
	var fire: bool = (flags & Defs.IN_FIRE) != 0
	if cooldown > 0:
		cooldown -= 1
	if squawk > 0:
		squawk -= 1
		if squawk == 0:
			_drop_rock()
	elif fire and not _was_fire and cooldown == 0:
		squawk = VersusTuning.GRUDGE_SQUAWK_TICKS
		cooldown = VersusTuning.GRUDGE_ROCK_PERIOD_TICKS
		if AudioTable.SFX.has(Sfx.BOSS_ROAR):
			Audio.play_sfx(Sfx.BOSS_ROAR)
	_was_fire = fire
	if _sprite != null:
		_sprite.flip_h = facing < 0
		_sprite.frame = (Sim.tick / FLAP_TICKS) % SHEET_FRAMES.x + (SHEET_FRAMES.x if squawk > 0 else 0)


func _drop_rock() -> void:
	var level: LevelBase = Game.level
	if level == null:
		return
	var rock: VersusHazard = VersusHazard.new().setup(VersusHazard.ROCK, 0, referee)
	rock.owner_slot = slot
	rock.cause = &"grudge"
	rock.spawn_setup(Vector2i(sim_pos.x, sim_pos.y + 4), {})
	level.get_container("fx").add_child(rock)
	rocks += 1

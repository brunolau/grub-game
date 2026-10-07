class_name SpearStep
extends PlatformBase
## `objects/spear_step`: the step a spear makes when it sticks in a bark board (PHYSICS.md C.3, DESIGN.md C.2). Never
## placed in a level file: [BarkBoard] spawns it (params `face`, `board`, `owner`). A static sprite platform with the
## ride rules of PHYSICS.md 11.4 (PlatformBase: one-way, the 16 px catch band of a fast fall), 16 px wide in the air
## cell in front of the board's face, its top on the top edge of the board's cell. Any hero can stand on it (co-op:
## both); it never carries anyone. It stands Tuning.BARK_BOARD_STEP_TICKS, blinks for the last
## Tuning.BARK_BOARD_BLINK_TICKS, then falls (cosmetic: riders fall, it drops out of sight and is removed).
## [method collapse] removes it at once (the spear that made it was pulled out by its owner's third throw).
##
## Owner: objects-B (docs/expansion/PLAN.md 4.1). Its life counts in its own PLATFORMS step, so it is a pure function
## of the ticks since it was made; a level reset (death, team wipe) removes it.

## Box height (px): the contact band of the ride test below the top.
const STEP_H: int = 8
## Cosmetic fall after the life ran out: ticks and the drop per tick (px). [own]
const FALL_TICKS: int = 10
const FALL_PX_PER_TICK: int = 3
## The stuck spear of fx/projectile_spear.png (ASSET_MANIFEST: frame 4 = stuck in a bark board, drawn as the step).
const SPEAR_TEXTURE: Texture2D = preload("res://assets/sprites/fx/projectile_spear.png")
const SPEAR_FRAMES: int = 7
const SPEAR_STUCK_FRAME: int = 4
## Sprite placement (art px from the feet point): the tip rests in the wall face.
const SPRITE_DX_ART: float = 8.0
const SPRITE_Y_ART: float = -14.0

## Ticks left standing (0 = it fell or collapsed: no longer solid).
var life: int = Tuning.BARK_BOARD_STEP_TICKS
## +1: the board's air side is to the right of the board (the step stands right of the wall); -1: to the left.
var face: int = 1
## The bark board that made it (may be null for a step spawned by hand).
var board: SimEntity = null
## Player slot of the spear's thrower (-1 = unknown).
var owner_slot: int = -1

var _falling: int = 0
var _gone: bool = false
var _sprite: Sprite2D = null


func _init() -> void:
	super()
	z_index = Defs.Z_PLATFORMS
	box_w = Tuning.BARK_BOARD_STEP_W
	box_h = STEP_H
	box_xo = Tuning.BARK_BOARD_STEP_W / 2


func _apply_params(params: Dictionary) -> void:
	face = -1 if str(params.get("face", "r")).begins_with("l") else 1
	board = params.get("board") as SimEntity
	owner_slot = int(params.get("owner", -1))


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = SPEAR_TEXTURE
	_sprite.hframes = SPEAR_FRAMES
	_sprite.frame = SPEAR_STUCK_FRAME
	# The sheet faces right (tip on the right): a step right of the wall came from a spear flying left.
	_sprite.flip_h = face > 0
	_sprite.position = Vector2(SPRITE_DX_ART * face, SPRITE_Y_ART)
	add_child(_sprite)


## True while heroes can stand on it.
func is_solid() -> bool:
	return life > 0 and not _gone


## Remove it at once (riders fall): its spear was pulled out.
func collapse() -> void:
	if _gone:
		return
	life = 0
	_gone = true
	rider_mask = 0
	ridden = false
	visible = false
	sim_active = false
	queue_free()


func _move_tick() -> void:
	if _gone:
		return
	if life > 0:
		life -= 1
		if life <= Tuning.BARK_BOARD_BLINK_TICKS:
			visible = life == 0 or (life & 2) == 0
		return
	# Fallen: a short cosmetic drop, then it is gone.
	visible = true
	_falling += 1
	dy = FALL_PX_PER_TICK
	if _falling >= FALL_TICKS:
		collapse()


func _ride_test() -> bool:
	if not is_solid():
		rider_mask = 0
		return false
	return super._ride_test()


func _on_level_reset() -> void:
	collapse()

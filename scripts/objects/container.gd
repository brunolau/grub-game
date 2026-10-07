class_name BonusContainer
extends SceneryHittable
## `objects/container` (`skin=barrel|crate|pot|chest` [crate], `contents` [random], `hits` [1]): a free-standing
## barrel, crate, pot or treasure chest. It wobbles under the club and bursts on the last hit, throwing its contents
## out in a fan. `random` stands for three random bonus items. (The class is not called `Container`: that is an
## engine class.)
##
## `skin=chest` (2.0, 8-1 Overgrown Steps: real chests among the Mimics, DESIGN.md A.5 / GAMEPLAY.md 13.5): the
## chest does not burst - on its last hit the lid flips open (CHEST_OPEN_FRAMES) and the contents fan out of it; it
## stands there open for the rest of the stage. Its closed picture is the one `enemies/mimic` must look like exactly:
## cell CHEST_FRAME_CLOSED of CHEST_TEXTURE (60 x 36 art px cells, pivot CHEST_PIVOT, the shipped treasure chest).

const SKINS: Array[String] = ["barrel", "crate", "pot", "chest"]
const TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/objects/barrel.png"),
	preload("res://assets/sprites/objects/crate.png"),
	preload("res://assets/sprites/objects/pot.png"),
	preload("res://assets/sprites/objects/chest.png"),
]
## Pivots of the pictures (bottom-centre, ASSET_MANIFEST.md 8) and their contact boxes (logical px).
const PIVOTS: Array[Vector2] = [Vector2(15, 26), Vector2(16, 22), Vector2(8, 27), Vector2(24, 36)]
const BOXES: Array[Vector3i] = [Vector3i(16, 13, 8), Vector3i(16, 11, 8), Vector3i(8, 14, 4), Vector3i(24, 18, 12)]
## Frames per sheet (the chest: closed, then three opening frames).
const HFRAMES: Array[int] = [1, 1, 1, 4]
const DEFAULT_SKIN: int = 1
const DEFAULT_CONTENTS: String = "random,random,random"
const DEBRIS_KINDS: Array[String] = ["wood", "wood", "rock", "wood"]
## The chest skin [M chest]: its index, the closed cell and the opening cells (played once at CHEST_OPEN_FPS).
const SKIN_CHEST: int = 3
const CHEST_TEXTURE: String = "res://assets/sprites/objects/chest.png"
const CHEST_PIVOT: Vector2 = Vector2(24, 36)
const CHEST_FRAME_CLOSED: int = 0
const CHEST_OPEN_FRAMES: Array[int] = [1, 2, 3]
const CHEST_OPEN_FPS: int = 10

## Index into SKINS.
var skin: int = DEFAULT_SKIN
## What it throws out when it bursts.
var contents: ItemContents = null

var _sprite: Sprite2D = null
## Ticks since a chest's lid started to open (-1: closed, or the opening has finished).
var _lid: int = -1


func _init() -> void:
	super()
	spot_kind = &"container"


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	spot_kind = &"container"
	hits_left = maxi(int(params.get("hits", 1)), 1)
	hits_total = hits_left
	skin = SKINS.find(str(params.get("skin", SKINS[DEFAULT_SKIN])))
	if skin < 0:
		push_warning("objects/container: unknown skin '%s'" % str(params.get("skin")))
		skin = DEFAULT_SKIN
	set_box(BOXES[skin])
	var text: String = str(params.get("contents", ItemContents.TOKEN_RANDOM))
	if text == ItemContents.TOKEN_RANDOM:
		text = DEFAULT_CONTENTS
	contents = ItemContents.parse(text)
	_sprite = get_node_or_null(^"Sprite") as Sprite2D
	if _sprite != null:
		_sprite.texture = TEXTURES[skin]
		_sprite.hframes = HFRAMES[skin]
		_sprite.vframes = 1
		_sprite.frame = CHEST_FRAME_CLOSED
		_sprite.offset = -PIVOTS[skin]
		_sprite.visible = true


## The centre of the picture.
func get_hit_point() -> Vector2i:
	return Vector2i(sim_pos.x, sim_pos.y - (box_h >> 1))


func _sim_tick(phase: int) -> void:
	super._sim_tick(phase)
	if phase == Defs.Phase.WORLD and _lid >= 0:
		_lid += 1
		var index: int = ObjTuning.anim_frame(_lid, CHEST_OPEN_FPS)
		if _sprite != null:
			_sprite.frame = CHEST_OPEN_FRAMES[mini(index, CHEST_OPEN_FRAMES.size() - 1)]
		if index >= CHEST_OPEN_FRAMES.size():
			_lid = -1
			_doze_note()


func _is_idle() -> bool:
	return super._is_idle() and _lid < 0


func _on_hit(_power: int, _source: SimEntity) -> void:
	wobble(_sprite)
	spray(DEBRIS_KINDS[skin], ObjTuning.BLOCK_HIT_DEBRIS >> 1, get_hit_point())


## 2.0 versus refill (HittableBase.refill): the crate / barrel / pot stands there again (a chest closes its lid).
func _on_refilled() -> void:
	_lid = -1
	if _sprite != null:
		_sprite.visible = true
		_sprite.frame = CHEST_FRAME_CLOSED
	if Game.level != null:
		Game.level.spawn_fx(ID_POOF, get_hit_point())


func _on_opened() -> void:
	var level: LevelBase = Game.level
	if level == null:
		return
	if skin == SKIN_CHEST:
		# The lid flips open (open() played the "spot opened" cue); the chest stays.
		_lid = 0
		if _sprite != null:
			_sprite.frame = CHEST_OPEN_FRAMES[0]
	else:
		if _sprite != null:
			_sprite.visible = false
		spray(DEBRIS_KINDS[skin], ObjTuning.CONTAINER_DEBRIS, get_hit_point())
		level.spawn_fx(ID_POOF, get_hit_point())
		Audio.play_sfx(Sfx.BLOCK_BREAK)
	for i: int in contents.size():
		var v: Vector2i = ObjTuning.fan_velocity(i, strike_dir * ObjTuning.SPOT_THROW_XVEL, ObjTuning.SPOT_THROW_YVEL)
		contents.spawn(level, i, Vector2i(sim_pos.x, sim_pos.y - 1), v.x, v.y)

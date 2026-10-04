class_name BonusContainer
extends SceneryHittable
## `objects/container` (`skin=barrel|crate|pot` [crate], `contents` [random], `hits` [1]): a free-standing barrel,
## crate or pot. It wobbles under the club and bursts on the last hit, throwing its contents out in a fan.
## `random` stands for three random bonus items. (The class is not called `Container`: that is an engine class.)

const SKINS: Array[String] = ["barrel", "crate", "pot"]
const TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/objects/barrel.png"),
	preload("res://assets/sprites/objects/crate.png"),
	preload("res://assets/sprites/objects/pot.png"),
]
## Pivots of the three pictures (bottom-centre, ASSET_MANIFEST.md 8) and their contact boxes (logical px).
const PIVOTS: Array[Vector2] = [Vector2(15, 26), Vector2(16, 22), Vector2(8, 27)]
const BOXES: Array[Vector3i] = [Vector3i(16, 13, 8), Vector3i(16, 11, 8), Vector3i(8, 14, 4)]
const DEFAULT_SKIN: int = 1
const DEFAULT_CONTENTS: String = "random,random,random"
const DEBRIS_KINDS: Array[String] = ["wood", "wood", "rock"]

## Index into SKINS.
var skin: int = DEFAULT_SKIN
## What it throws out when it bursts.
var contents: ItemContents = null

var _sprite: Sprite2D = null


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
		_sprite.offset = -PIVOTS[skin]
		_sprite.visible = true


## The centre of the picture.
func get_hit_point() -> Vector2i:
	return Vector2i(sim_pos.x, sim_pos.y - (box_h >> 1))


func _on_hit(_power: int, _source: SimEntity) -> void:
	wobble(_sprite)
	spray(DEBRIS_KINDS[skin], ObjTuning.BLOCK_HIT_DEBRIS >> 1, get_hit_point())


func _on_opened() -> void:
	var level: LevelBase = Game.level
	if level == null:
		return
	if _sprite != null:
		_sprite.visible = false
	spray(DEBRIS_KINDS[skin], ObjTuning.CONTAINER_DEBRIS, get_hit_point())
	level.spawn_fx(ID_POOF, get_hit_point())
	Audio.play_sfx(Sfx.BLOCK_BREAK)
	for i: int in contents.size():
		var v: Vector2i = ObjTuning.fan_velocity(i, strike_dir * ObjTuning.SPOT_THROW_XVEL, ObjTuning.SPOT_THROW_YVEL)
		contents.spawn(level, i, Vector2i(sim_pos.x, sim_pos.y - 1), v.x, v.y)

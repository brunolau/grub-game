class_name BreakableBlock
extends SceneryHittable
## `objects/breakable_block` (GAMEPLAY.md 4.4, ARCHITECTURE.md 7.7): a solid block that cracks under the club and
## breaks on the last hit, opening the cell (`Game.level.set_cell(col, row, ".")`). Walls of secret passages are
## columns of blocks; touching blocks break together (flood fill in HittableBase).
##
## Parameters: `hits` 1..64 [2]; `skin=auto|dirt|cave|ice|obsidian` [auto: by biome]; `contents` [none] thrown out
## when it breaks.

const DEFAULT_HITS: int = 2
const MAX_HITS: int = 64
const SKINS: Array[String] = ["dirt", "cave", "ice", "obsidian"]
const TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/objects/breakable_block.png"),
	preload("res://assets/sprites/objects/breakable_block_cave.png"),
	preload("res://assets/sprites/objects/breakable_block_ice.png"),
	preload("res://assets/sprites/objects/breakable_block_obsidian.png"),
]
const BIOME_SKINS: Dictionary = {"cave": "cave", "ice": "ice"}
## Sheet animation [M 8]: idle 0, crack 1-3, break 4-7 at 14 fps.
const FRAME_IDLE: int = 0
const FRAME_CRACK_FIRST: int = 1
const CRACK_FRAMES: int = 3
const FRAME_BREAK_FIRST: int = 4
const BREAK_FRAMES: int = 4
const BREAK_FPS: int = 14
const ICE_SKIN: int = 2

## Index into SKINS.
var skin: int = 0
## What it throws out when it breaks.
var contents: ItemContents = null

var _sprite: Sprite2D = null
var _break_age: int = -1


func _init() -> void:
	super()
	joins_flood = true
	spot_kind = &"block"


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	spot_kind = &"block"
	hits_left = clampi(int(params.get("hits", DEFAULT_HITS)), 1, MAX_HITS)
	hits_total = hits_left
	var skin_name: String = str(params.get("skin", "auto"))
	if skin_name == "auto" or not SKINS.has(skin_name):
		var biome: String = str(Game.level.meta.get("biome", "jungle")) if Game.level != null else "jungle"
		skin_name = str(BIOME_SKINS.get(biome, "obsidian" if _is_keep() else "dirt"))
	skin = SKINS.find(skin_name)
	contents = ItemContents.parse(params.get("contents", ItemContents.TOKEN_NONE))
	_sprite = get_node_or_null(^"Sprite") as Sprite2D
	if _sprite != null:
		_sprite.texture = TEXTURES[skin]
		_sprite.frame = FRAME_IDLE


func _sim_tick(phase: int) -> void:
	super._sim_tick(phase)
	if phase == Defs.Phase.WORLD and _break_age >= 0 and _sprite != null and _sprite.visible:
		_break_age += 1
		var frame: int = ObjTuning.anim_frame(_break_age, BREAK_FPS)
		if frame >= BREAK_FRAMES:
			_sprite.visible = false
		else:
			_sprite.frame = FRAME_BREAK_FIRST + frame


func _on_hit(_power: int, _source: SimEntity) -> void:
	if hits_left > 0 and _sprite != null:
		# Cracks deepen over the hits: the first hit shows the first crack frame, the one before the last the
		# deepest (with more hits the middle frame shows in between).
		var damage: int = hits_total - hits_left
		var crack: int = (damage - 1) * (CRACK_FRAMES - 1) / maxi(hits_total - 2, 1)
		_sprite.frame = FRAME_CRACK_FIRST + mini(crack, CRACK_FRAMES - 1)
		wobble(_sprite)
	spray(_debris_kind(), ObjTuning.BLOCK_HIT_DEBRIS, get_hit_point())


func _on_opened() -> void:
	var level: LevelBase = Game.level
	if level == null:
		return
	level.set_cell(cell.x, cell.y, TileGrid.CH_AIR)
	_break_age = 0
	if _sprite != null:
		_sprite.frame = FRAME_BREAK_FIRST
		_sprite.position.x = 0.0
	spray(_debris_kind(), ObjTuning.BLOCK_BREAK_DEBRIS, get_hit_point())
	Audio.play_sfx(Sfx.BLOCK_BREAK_ICE if skin == ICE_SKIN else Sfx.BLOCK_BREAK)
	for i: int in contents.size():
		var out: Vector4i = emerge(
			(1 if (i & 1) == 0 else -1) * ObjTuning.SPOT_THROW_XVEL, ObjTuning.SPOT_THROW_YVEL
		)
		contents.spawn(level, i, Vector2i(out.x, out.y), out.z, out.w)


func _debris_kind() -> String:
	return "ice" if skin == ICE_SKIN else "rock"


func _is_keep() -> bool:
	return Game.level != null and str(Game.level.meta.get("terrain_a", "")).contains("obsidian")

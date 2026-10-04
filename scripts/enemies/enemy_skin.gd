class_name EnemySkin
extends RefCounted
## Sprite-sheet facts of ASSET_MANIFEST.md 4 (enemies) and 5 (bosses): cell size, grid, pivot, body box and
## animations of every sheet an enemy can be skinned with.
##
## A skin is found by its sheet name without path and extension ("turtle", "turtle_b", "brute_enraged"). The `_b`
## palettes share the layout of their base sheet. Animations are stored by ROLE (what an archetype wants to show),
## and a role a sheet does not have falls back to the closest one it has, so every enemy id works with every skin.
## An animation is a Vector4i(first frame, frame count, ticks per frame, 1 = loop / 0 = hold the last frame).

const ENEMY_DIR: String = "res://assets/sprites/enemies/"
const BOSS_DIR: String = "res://assets/sprites/bosses/"
const VARIANT_SUFFIX: String = "_b"
const ENRAGED_SUFFIX: String = "_enraged"
## Shown when a sheet has no animation at all for a role (never the case for the shipped sheets).
const STILL: Vector4i = Vector4i(0, 1, 1, 0)
## Roles tried in turn when a sheet lacks the wanted one.
const FALLBACKS: Dictionary[StringName, Array] = {
	&"idle": [&"fly", &"walk"],
	&"walk": [&"fly", &"idle"],
	&"fly": [&"glide", &"walk", &"idle"],
	&"air": [&"fly", &"walk", &"idle"],
	&"hang": [&"idle", &"fly"],
	&"dive": [&"leap", &"fly", &"attack", &"walk", &"idle"],
	&"leap": [&"dive", &"air", &"fly", &"walk", &"idle"],
	&"glide": [&"fly", &"air", &"walk", &"idle"],
	&"roll": [&"air", &"fly", &"idle"],
	&"land": [&"idle", &"fly"],
	&"attack": [&"bite", &"idle", &"fly"],
	&"windup": [&"attack", &"idle", &"fly"],
	&"bite": [&"attack", &"idle", &"fly"],
	&"recover": [&"idle", &"fly"],
	&"screech": [&"dive", &"fly", &"idle"],
	&"hurt": [&"dead", &"idle", &"fly"],
	&"dead": [&"hurt", &"idle", &"fly"],
}

## Sheet name this skin was asked for ("turtle_b").
var sheet: String = ""
## Texture file.
var texture_path: String = ""
## Cell size in art px.
var cell: Vector2i = Vector2i(32, 32)
## Columns and rows of the sheet (Sprite2D.hframes / vframes).
var columns: int = 1
var rows: int = 1
## Feet point inside a cell, art px.
var pivot: Vector2i = Vector2i(16, 32)
## Body box in logical px (width, height), centred on the feet point.
var box: Vector2i = Vector2i(16, 16)
## Height of the standing body above the feet point in art px (thread attach point, burrower clip).
var body_height: int = 32
## Animations by role.
var anims: Dictionary[StringName, Vector4i] = {}

static var _cache: Dictionary[String, EnemySkin] = {}


## The skin called `skin_name`, or null when no such sheet exists.
static func find(skin_name: String) -> EnemySkin:
	if _cache.has(skin_name):
		return _cache[skin_name]
	var skin: EnemySkin = _build(skin_name)
	if skin != null and not ResourceLoader.exists(skin.texture_path):
		skin = null
	_cache[skin_name] = skin
	return skin


## Animation for a role, using the fallbacks of this sheet.
func anim(role: StringName) -> Vector4i:
	if anims.has(role):
		return anims[role]
	if FALLBACKS.has(role):
		for other: StringName in FALLBACKS[role]:
			if anims.has(other):
				return anims[other]
	return STILL


## True when the sheet has its own frames for a role (no fallback).
func has_anim(role: StringName) -> bool:
	return anims.has(role)


## Sprite2D.offset that puts the pivot on the node origin.
func sprite_offset() -> Vector2:
	return Vector2(-pivot.x, -pivot.y)


static func _build(skin_name: String) -> EnemySkin:
	var base: String = skin_name
	if base.ends_with(VARIANT_SUFFIX):
		base = base.left(base.length() - VARIANT_SUFFIX.length())
	elif base.ends_with(ENRAGED_SUFFIX):
		base = base.left(base.length() - ENRAGED_SUFFIX.length())
	var skin: EnemySkin = EnemySkin.new()
	skin.sheet = skin_name
	skin.texture_path = ENEMY_DIR + skin_name + ".png"
	match base:
		"bat":
			skin._layout(56, 72, 8, 2, 28, 56, 22, 23, 27)
			skin._add(&"fly", 0, 4, 2, true)
			skin._add(&"screech", 4, 1, 1, false)
			skin._add(&"dive", 5, 2, 3, true)
			skin._add(&"attack", 7, 2, 3, true)
			skin._add(&"roll", 9, 3, 3, true)
			skin._add(&"dead", 12, 1, 1, false)
			skin._add(&"hang", 13, 1, 1, false)
		"dragon":
			skin._layout(120, 80, 8, 2, 60, 64, 35, 26, 53)
			skin._add(&"idle", 0, 3, 3, true)
			skin._add(&"glide", 3, 2, 3, true)
			skin._add(&"attack", 5, 4, 2, false)
			skin._add(&"leap", 7, 2, 3, true)
			skin._add(&"hurt", 9, 3, 3, false)
			skin._add(&"roll", 12, 3, 2, true)
			skin._add(&"dead", 15, 1, 1, false)
		"egg_kid":
			skin._layout(120, 88, 8, 5, 60, 72, 26, 30, 60)
			skin._add(&"idle", 0, 6, 3, true)
			skin._add(&"walk", 6, 8, 2, true)
			skin._add(&"air", 14, 3, 2, false)
			skin._add(&"land", 17, 1, 1, false)
			skin._add(&"roll", 18, 3, 2, true)
			skin._add(&"attack", 22, 4, 2, false)
			skin._add(&"hurt", 26, 2, 3, true)
			skin._add(&"dead", 28, 5, 3, false)
			skin._add(&"hang", 33, 4, 4, true)
		"insect":
			skin._layout(88, 88, 8, 2, 44, 72, 35, 18, 36)
			skin._add(&"idle", 0, 2, 12, true)
			skin._add(&"walk", 2, 3, 2, true)
			skin._add(&"fly", 5, 2, 2, true)
			skin._add(&"dead", 7, 4, 3, false)
			skin._add(&"hang", 11, 1, 1, false)
		"lizard":
			skin._layout(136, 72, 8, 3, 68, 56, 32, 20, 41)
			skin._add(&"idle", 0, 6, 3, true)
			skin._add(&"walk", 6, 6, 2, true)
			skin._add(&"air", 7, 1, 1, false)
			skin._add(&"attack", 12, 4, 2, false)
			skin._add(&"hurt", 16, 2, 3, false)
			skin._add(&"dead", 22, 1, 1, false)
		"mini_rex":
			skin._layout(104, 80, 8, 3, 52, 64, 29, 24, 47)
			skin._add(&"idle", 0, 6, 3, true)
			skin._add(&"walk", 6, 5, 2, true)
			skin._add(&"air", 7, 1, 1, false)
			skin._add(&"attack", 11, 3, 2, false)
			skin._add(&"hurt", 14, 2, 3, false)
			skin._add(&"dead", 20, 2, 6, false)
		"plant":
			skin._layout(176, 104, 8, 3, 88, 88, 30, 28, 56)
			skin._add(&"idle", 0, 6, 3, true)
			skin._add(&"windup", 6, 3, 2, false)
			skin._add(&"bite", 9, 3, 2, false)
			skin._add(&"hurt", 12, 3, 3, false)
			skin._add(&"recover", 15, 6, 2, false)
			skin._add(&"dead", 21, 3, 4, false)
		"pterodactyl":
			skin._layout(144, 120, 8, 2, 72, 104, 52, 22, 58)
			skin._add(&"fly", 0, 4, 3, true)
			skin._add(&"land", 4, 1, 1, false)
			skin._add(&"dive", 7, 2, 2, true)
			skin._add(&"screech", 9, 2, 3, true)
			skin._add(&"hurt", 11, 4, 2, false)
			skin._add(&"dead", 15, 1, 1, false)
		"rex":
			skin._layout(152, 112, 8, 3, 76, 96, 58, 35, 70)
			skin._add(&"idle", 0, 6, 3, true)
			skin._add(&"walk", 6, 8, 2, true)
			skin._add(&"attack", 14, 5, 2, false)
			skin._add(&"hurt", 19, 2, 3, false)
			skin._add(&"dead", 21, 3, 4, false)
		"rival":
			skin._layout(96, 80, 8, 5, 48, 64, 22, 26, 51)
			skin._add(&"idle", 0, 6, 3, true)
			skin._add(&"walk", 6, 8, 2, true)
			skin._add(&"air", 14, 3, 2, false)
			skin._add(&"land", 20, 1, 1, false)
			skin._add(&"roll", 21, 3, 2, true)
			skin._add(&"attack", 25, 4, 2, false)
			skin._add(&"hurt", 29, 2, 3, true)
			skin._add(&"dead", 31, 5, 3, false)
		"turtle":
			skin._layout(64, 56, 8, 3, 32, 40, 26, 15, 30)
			skin._add(&"idle", 0, 4, 4, true)
			skin._add(&"walk", 4, 6, 3, true)
			skin._add(&"hurt", 10, 6, 2, false)
			skin._add(&"dead", 16, 5, 3, false)
		"brute":
			skin.texture_path = BOSS_DIR + skin_name + ".png"
			skin._layout(288, 176, 7, 6, 144, 144, 55, 61, 122)
			skin._add(&"idle", 0, 6, 3, true)
			skin._add(&"walk", 6, 8, 2, true)
			skin._add(&"air", 14, 3, 2, false)
			skin._add(&"land", 17, 1, 1, false)
			skin._add(&"roll", 18, 3, 2, true)
			skin._add(&"crouch", 21, 1, 1, false)
			skin._add(&"attack", 22, 4, 2, false)
			skin._add(&"hurt", 26, 2, 3, true)
			skin._add(&"dead", 28, 5, 3, false)
			skin._add(&"taunt", 33, 4, 4, true)
			skin._add(&"pound", 37, 4, 3, true)
		"colossus":
			skin.texture_path = BOSS_DIR + skin_name + ".png"
			skin._layout(260, 224, 6, 3, 260, 208, 104, 95, 190)
			skin._add(&"idle", 0, 6, 4, true)
			skin._add(&"spit", 6, 4, 3, false)
			skin._add(&"slam", 10, 2, 4, false)
			skin._add(&"hurt", 12, 2, 3, true)
			skin._add(&"rage", 14, 2, 3, true)
			skin._add(&"dead", 16, 1, 1, false)
		_:
			return null
	return skin


func _layout(
		cell_w: int, cell_h: int, p_columns: int, p_rows: int, pivot_x: int, pivot_y: int, box_w: int, box_h: int,
		p_body_height: int
) -> void:
	cell = Vector2i(cell_w, cell_h)
	columns = p_columns
	rows = p_rows
	pivot = Vector2i(pivot_x, pivot_y)
	box = Vector2i(box_w, box_h)
	body_height = p_body_height


func _add(role: StringName, first: int, count: int, ticks_per_frame: int, loop: bool) -> void:
	anims[role] = Vector4i(first, count, ticks_per_frame, 1 if loop else 0)

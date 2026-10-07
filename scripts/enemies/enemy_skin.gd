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
## 2.0: the rage palette of a Book II boss (`tusker_rage`) shares the layout of its base sheet.
const RAGE_SUFFIX: String = "_rage"
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
	# 2.0 roles (the Roller, the Guard, the co-op dazes; DESIGN.md A.5, D.6).
	&"curl": [&"roll", &"idle", &"fly"],
	&"uncurl": [&"curl", &"idle", &"fly"],
	&"bump": [&"hurt", &"roll", &"idle", &"fly"],
	&"dizzy": [&"hurt", &"idle", &"fly"],
	&"guard": [&"hurt", &"idle", &"fly"],
	&"rear": [&"windup", &"attack", &"idle", &"fly"],
	# 2.0 phase 2 (P2.1): the Mimic's telegraph, a Leech riding a back, a freshly split half.
	&"shudder": [&"windup", &"idle", &"fly"],
	&"front": [&"idle", &"fly", &"walk"],
	&"squash": [&"land", &"idle", &"walk"],
	&"cast": [&"attack", &"idle", &"walk"],
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
	elif base.ends_with(RAGE_SUFFIX):
		base = base.left(base.length() - RAGE_SUFFIX.length())
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
		"insect", "mosquito":  # 2.0: the swamp mosquito keeps the shipped insect layout exactly (art-B)
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
			skin._add(&"dizzy", 16, 4, 3, true)  # 2.0: the Raptor's daze (DESIGN.md D.7); never shown in Book I
			skin._add(&"dead", 20, 2, 6, false)
		"plant":
			skin._layout(176, 104, 8, 3, 88, 88, 30, 28, 56)
			skin._add(&"idle", 0, 6, 3, true)
			skin._add(&"windup", 6, 3, 2, false)
			skin._add(&"bite", 9, 3, 2, false)
			skin._add(&"hurt", 12, 3, 3, false)
			skin._add(&"recover", 15, 6, 2, false)
			skin._add(&"dead", 21, 3, 4, false)
		"pterodactyl", "gull", "storm_ptero":
			# 2.0 recolours on this layout (art-B, worlds 7-9): the coast gull (gull, pterodactyl recoloured white-grey;
			# gull_b = pterodactyl_b recoloured, the co-op Snatcher's gull) and the storm pterodactyl of 9-1b / 9-2.
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
		"rival", "rival_tar":  # 2.0: rival_tar = the Tar Tribe warrior (Charger, DESIGN.md A.5 desert tribesmen)
			skin._layout(96, 80, 8, 5, 48, 64, 22, 26, 51)
			skin._add(&"idle", 0, 6, 3, true)
			skin._add(&"walk", 6, 8, 2, true)
			skin._add(&"air", 14, 3, 2, false)
			skin._add(&"land", 20, 1, 1, false)
			skin._add(&"roll", 21, 3, 2, true)
			skin._add(&"attack", 25, 4, 2, false)
			skin._add(&"hurt", 29, 2, 3, true)
			skin._add(&"dead", 31, 5, 3, false)
		"turtle", "sea_snail":  # 2.0: the coast's sea snail (Dropper) is turtle_b with a shell recolour (art-B)
			skin._layout(64, 56, 8, 3, 32, 40, 26, 15, 30)
			skin._add(&"idle", 0, 4, 4, true)
			skin._add(&"walk", 4, 6, 3, true)
			skin._add(&"hurt", 10, 6, 2, false)
			skin._add(&"dead", 16, 5, 3, false)
		# --- 2.0 world 5 sheets (art-B's hand-over: .tools/asset_candidates/expansion/_handover/WORLD5_HANDOVER.md;
		# frame rates converted to ticks per frame at 24.3 Hz: 8 fps = 3, 10-16 fps = 2, 6 fps = 4) --------------------
		"roller":
			skin._layout(144, 96, 8, 3, 72, 80, 54, 24, 49)
			skin._add(&"idle", 0, 5, 3, true)
			skin._add(&"walk", 0, 5, 2, true)
			skin._add(&"curl", 5, 4, 3, false)
			skin._add(&"roll", 9, 4, 2, true)
			skin._add(&"bump", 14, 1, 1, false)
			skin._add(&"uncurl", 15, 2, 4, false)
			skin._add(&"attack", 17, 2, 3, true)
			skin._add(&"dizzy", 19, 2, 3, true)
			skin._add(&"dead", 21, 1, 1, false)
		"guard", "shellback":
			skin._layout(304, 168, 6, 3, 152, 152, 76, 54, 109)
			skin._add(&"idle", 0, 5, 3, true)
			skin._add(&"walk", 0, 5, 2, true)
			skin._add(&"attack", 5, 6, 2, false)
			skin._add(&"guard", 11, 2, 3, false)
			skin._add(&"hurt", 13, 2, 3, false)
			skin._add(&"dead", 15, 1, 1, false)
		"snake":
			# The rattler (Snapper: idle, windup, bite, recover, hurt) and the burrow snake (Digger: walk = lunge).
			skin._layout(208, 112, 8, 3, 104, 96, 38, 30, 59)
			skin._add(&"idle", 0, 5, 3, true)
			skin._add(&"windup", 5, 2, 3, false)
			skin._add(&"bite", 7, 3, 2, false)
			skin._add(&"recover", 0, 4, 3, false)
			skin._add(&"rear", 10, 3, 3, false)
			skin._add(&"walk", 13, 3, 2, true)
			skin._add(&"lunge", 13, 3, 2, false)
			skin._add(&"hurt", 16, 3, 3, false)
			skin._add(&"dead", 19, 1, 1, false)
		"cave_bat":
			skin._layout(128, 88, 8, 3, 64, 72, 55, 28, 58)
			skin._add(&"fly", 0, 5, 2, true)
			skin._add(&"screech", 5, 2, 3, true)
			skin._add(&"dive", 7, 4, 2, true)
			skin._add(&"swoop", 7, 4, 2, true)
			skin._add(&"roll", 11, 5, 2, true)
			skin._add(&"spin", 11, 5, 2, true)
			skin._add(&"hurt", 16, 2, 3, false)
			skin._add(&"dead", 18, 1, 1, false)
			skin._add(&"hang", 19, 1, 1, false)
		"eagle":
			skin._layout(80, 120, 6, 1, 40, 88, 34, 41, 82)
			skin._add(&"fly", 0, 2, 3, true)
			skin._add(&"dive", 2, 2, 2, true)
			skin._add(&"hurt", 4, 1, 1, false)
			skin._add(&"dead", 5, 1, 1, false)
		"bear":
			# The cave bear (Western FPS bear at 2x, a Snapper: claw = bite); recover holds the idle frames once.
			skin._layout(128, 144, 7, 1, 64, 112, 63, 51, 102)
			skin._add(&"idle", 0, 4, 4, true)
			skin._add(&"walk", 0, 4, 3, true)
			skin._add(&"windup", 4, 1, 6, false)
			skin._add(&"bite", 5, 1, 6, false)
			skin._add(&"recover", 0, 4, 3, false)
			skin._add(&"hurt", 4, 1, 1, false)
			skin._add(&"dead", 6, 1, 1, false)
		# --- 2.0 world 6 sheets (art-B's ENEMY_SKIN_ROWS.md; ahead of phase 2) -------------------------------------
		"slime", "jelly":  # 2.0: jelly flyers are the slime recoloured translucent blue (DESIGN.md F.1)
			skin._layout(120, 96, 8, 3, 60, 80, 36, 28, 55)
			skin._add(&"idle", 0, 5, 3, true)
			skin._add(&"walk", 0, 5, 2, true)
			skin._add(&"squash", 5, 2, 3, false)
			skin._add(&"attack", 7, 3, 2, false)
			skin._add(&"recover", 10, 1, 1, false)
			skin._add(&"air", 11, 4, 2, true)
			skin._add(&"land", 15, 5, 2, false)
			skin._add(&"dead", 19, 1, 1, false)
			skin._add(&"bob", 20, 2, 3, true)
			skin._add(&"hurt", 22, 2, 3, false)
		"puffcap":
			skin._layout(200, 160, 8, 5, 100, 144, 51, 42, 83)
			skin._add(&"idle", 0, 8, 3, true)
			skin._add(&"windup", 8, 4, 2, false)
			skin._add(&"bite", 12, 5, 2, false)
			skin._add(&"recover", 17, 3, 2, false)
			skin._add(&"burst", 20, 9, 2, false)
			skin._add(&"hurt", 29, 4, 2, false)
			skin._add(&"dead", 33, 1, 1, false)
		"frog":
			skin._layout(72, 96, 8, 2, 36, 64, 26, 19, 38)
			skin._add(&"idle", 0, 4, 3, true)
			skin._add(&"walk", 0, 4, 2, true)
			skin._add(&"land", 4, 1, 1, false)
			skin._add(&"windup", 4, 1, 1, false)
			skin._add(&"air", 5, 2, 4, false)
			skin._add(&"hurt", 7, 1, 1, false)
			skin._add(&"dead", 8, 1, 1, false)
		"larva", "leech":
			skin._layout(32, 64, 8, 2, 16, 32, 15, 13, 26)
			skin._add(&"idle", 0, 2, 6, true)
			skin._add(&"walk", 0, 4, 3, true)
			skin._add(&"front", 4, 4, 3, true)
			skin._add(&"hang", 4, 1, 1, false)
			skin._add(&"dead", 8, 1, 1, false)
		"mimic":
			# 2.0 archetype 15 (GAMEPLAY.md 13.5: "drawn exactly as a chest"): art-B built this sheet from the chest
			# container's sprites/objects/chest.png - frame 0 is its closed cell pixel for pixel at the same feet point
			# (the chest's pivot (24, 36) of 60 x 36 = (40, 40) of 80 x 56). Then the shudder with the lid lifting on two
			# eyes (windup 1-3), the fangs (bite 4-6), the lid up (awake / recover 7-8), hurt 9-10 (also the daze),
			# dead 11. The box is the container chest's (EnemyTuning.MIMIC_BOX). One palette: no `mimic_b`.
			if skin_name != "mimic":
				return null
			skin._layout(80, 56, 8, 2, 40, 40, EnemyTuning.MIMIC_BOX.x, EnemyTuning.MIMIC_BOX.y, 27)
			skin._add(&"idle", 0, 1, 1, false)
			skin._add(&"windup", 1, 3, 3, false)
			skin._add(&"shudder", 1, 3, 3, false)
			skin._add(&"bite", 4, 3, 2, false)
			skin._add(&"awake", 7, 2, 6, true)
			skin._add(&"recover", 7, 2, 4, false)
			skin._add(&"hurt", 9, 2, 2, false)
			skin._add(&"dizzy", 9, 2, 4, true)
			skin._add(&"dead", 11, 1, 1, false)
		"shaman":
			# 2.0 co-op Shaman (DESIGN.md D.7: AP npc dragon-man at 1x, art-B): idle loop, walk, cast (the bone shield).
			skin._layout(64, 88, 8, 2, 32, 72, 24, 32, 63)
			skin._add(&"idle", 0, 10, 3, true)
			skin._add(&"walk", 0, 10, 2, true)
			skin._add(&"cast", 5, 5, 2, false)
			skin._add(&"hurt", 10, 1, 1, false)
			skin._add(&"dead", 11, 1, 1, false)
		"ghost":
			# 2.0 ruin ghost (Harrier; ghost_b shares the case), art-B world 8.
			skin._layout(120, 104, 8, 4, 60, 88, 39, 41, 82)
			skin._add(&"fly", 0, 6, 3, true)
			skin._add(&"screech", 6, 3, 3, false)
			skin._add(&"dive", 9, 3, 2, true)
			skin._add(&"vanish", 12, 14, 2, false)
			skin._add(&"hurt", 26, 4, 2, false)
			skin._add(&"dead", 30, 1, 1, false)
		"octopus":
			# 2.0 sea caves: the octopus on a kelp thread (Dangler, `hang` = front view) and the red one on the ceiling
			# (octopus_b, Lurker: `hang` upside down, `walk` after the drop), art-B world 7.
			skin._layout(32, 64, 8, 2, 16, 32, 16, 15, 30)
			skin._add(&"hang", 0, 4, 4, true)
			skin._add(&"idle", 0, 4, 4, true)
			skin._add(&"walk", 4, 4, 3, true)
			skin._add(&"hurt", 8, 1, 1, false)
			skin._add(&"dead", 9, 1, 1, false)
		"fish":
			# 2.0 leaping fish (Leaper; fish_b = the red one), art-B world 7.
			skin._layout(32, 64, 4, 1, 16, 32, 15, 8, 16)
			skin._add(&"idle", 0, 1, 1, false)
			skin._add(&"leap", 1, 1, 1, false)
			skin._add(&"glide", 2, 1, 1, false)
			skin._add(&"dead", 3, 1, 1, false)
			skin._add(&"hurt", 3, 1, 1, false)
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
		# --- 2.0 boss sheets of art-B for enemies-B's bosses (ENEMY_SKIN_ROWS.md); `tusker_rage` shares the case ---
		"tusker":
			skin.texture_path = BOSS_DIR + skin_name + ".png"
			skin._layout(256, 184, 8, 5, 128, 168, 76, 57, 114)
			skin._add(&"idle", 0, 7, 3, true)
			skin._add(&"paw", 7, 9, 2, false)
			skin._add(&"charge", 16, 3, 2, true)
			skin._add(&"walk", 17, 2, 3, true)
			skin._add(&"hurt", 19, 3, 3, false)
			skin._add(&"squeal", 19, 3, 2, false)
			skin._add(&"curl", 22, 4, 2, false)
			skin._add(&"spin", 26, 2, 2, true)
			skin._add(&"roll", 28, 4, 2, true)
			skin._add(&"flash", 32, 2, 2, false)
			skin._add(&"slam", 34, 1, 1, false)
			skin._add(&"dizzy", 35, 2, 4, true)
			skin._add(&"dead", 37, 1, 1, false)
		"mangrove":
			skin.texture_path = BOSS_DIR + skin_name + ".png"
			skin._layout(112, 144, 8, 3, 56, 112, 48, 52, 104)
			skin._add(&"idle", 0, 6, 3, true)
			skin._add(&"attack", 6, 5, 2, false)
			skin._add(&"charge", 11, 3, 2, false)
			skin._add(&"hurt", 14, 4, 2, false)
			skin._add(&"dead", 18, 1, 1, false)
		"mangrove_parts":
			skin.texture_path = BOSS_DIR + skin_name + ".png"
			skin._layout(80, 80, 8, 1, 40, 64, 40, 32, 64)
			skin._add(&"fist", 0, 1, 1, false)
			skin._add(&"fist_flash", 1, 1, 1, false)
			skin._add(&"hand", 2, 1, 1, false)
			skin._add(&"arm", 3, 3, 1, false)
			skin._add(&"leaf", 6, 2, 6, true)
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

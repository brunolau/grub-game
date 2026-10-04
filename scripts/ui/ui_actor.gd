class_name UiActor
extends Sprite2D
## A cosmetic sprite-sheet character for menus and cut scenes (title attract, world map, tally, game over).
##
## Owner: ui. It is NOT a SimEntity and never touches gameplay: frames advance with the rendered frame time.
## The node sits at the character's feet point; sheets, cells, pivots and animations come from the tables of
## docs/ASSET_MANIFEST.md (sections 3, 4 and 6). Every sheet faces right: `face(-1)` mirrors it.

## kind -> { "sheet", "cell": Vector2i, "pivot": Vector2i, "anims": { name: [first frame, last frame, fps] } }.
const KINDS: Dictionary = {
	&"hero": {
		"sheet": "res://assets/sprites/player/hero.png", "cell": Vector2i(176, 112), "pivot": Vector2i(88, 96),
		"anims": {
			&"idle": [0, 5, 8.0], &"walk": [6, 13, 12.0], &"run": [6, 13, 16.0], &"jump": [14, 16, 10.0],
			&"fall": [17, 19, 10.0], &"skid": [20, 20, 1.0], &"hurt": [37, 38, 8.0], &"victory": [48, 49, 4.0],
		},
	},
	&"companion": {
		"sheet": "res://assets/sprites/npc/companion.png", "cell": Vector2i(112, 88), "pivot": Vector2i(56, 72),
		"anims": {
			&"idle": [0, 5, 8.0], &"walk": [6, 13, 12.0], &"jump": [14, 16, 10.0], &"catch": [22, 25, 12.0],
			&"cry": [26, 27, 8.0],
		},
	},
	&"mini_rex": {
		"sheet": "res://assets/sprites/enemies/mini_rex.png", "cell": Vector2i(104, 80), "pivot": Vector2i(52, 64),
		"anims": {&"idle": [0, 5, 8.0], &"walk": [6, 10, 10.0], &"run": [6, 10, 14.0]},
	},
	&"mini_rex_b": {
		"sheet": "res://assets/sprites/enemies/mini_rex_b.png", "cell": Vector2i(104, 80),
		"pivot": Vector2i(52, 64),
		"anims": {&"idle": [0, 5, 8.0], &"walk": [6, 10, 10.0], &"run": [6, 10, 14.0]},
	},
	&"rex": {
		"sheet": "res://assets/sprites/enemies/rex.png", "cell": Vector2i(152, 112), "pivot": Vector2i(76, 96),
		"anims": {&"idle": [0, 5, 8.0], &"walk": [6, 13, 12.0], &"run": [6, 13, 16.0]},
	},
	&"pterodactyl": {
		"sheet": "res://assets/sprites/enemies/pterodactyl.png", "cell": Vector2i(144, 120),
		"pivot": Vector2i(72, 104),
		"anims": {&"fly": [0, 3, 8.0]},
	},
	&"bat": {
		"sheet": "res://assets/sprites/enemies/bat.png", "cell": Vector2i(56, 72), "pivot": Vector2i(28, 56),
		"anims": {&"fly": [0, 3, 10.0]},
	},
	&"elder": {
		"sheet": "res://assets/sprites/npc/elder.png", "cell": Vector2i(64, 88), "pivot": Vector2i(32, 72),
		"anims": {&"idle": [0, 4, 5.0]},
	},
	&"kid": {
		"sheet": "res://assets/sprites/npc/kid.png", "cell": Vector2i(48, 80), "pivot": Vector2i(24, 64),
		"anims": {&"idle": [0, 5, 5.0]},
	},
	&"warrior": {
		"sheet": "res://assets/sprites/npc/warrior.png", "cell": Vector2i(72, 88), "pivot": Vector2i(36, 72),
		"anims": {&"idle": [0, 5, 5.0]},
	},
}

## Name of the animation being played.
var animation: StringName = &""

var _anims: Dictionary = {}
var _first: int = 0
var _last: int = 0
var _fps: float = 0.0
var _loop: bool = true
var _time: float = 0.0


func _init(kind: StringName = &"hero", start_animation: StringName = &"idle") -> void:
	centered = false
	var entry: Dictionary = KINDS.get(kind, {})
	if entry.is_empty():
		push_error("UiActor: unknown kind '%s'" % kind)
		return
	var sheet: Texture2D = UiKit.tex(str(entry["sheet"]))
	var cell_size: Vector2i = entry["cell"]
	var pivot: Vector2i = entry["pivot"]
	texture = sheet
	if sheet != null:
		hframes = maxi(1, sheet.get_width() / cell_size.x)
		vframes = maxi(1, sheet.get_height() / cell_size.y)
	offset = Vector2(-pivot)
	_anims = entry["anims"]
	play(start_animation)


func _process(delta: float) -> void:
	if _fps <= 0.0 or _last <= _first:
		return
	_time += delta
	var count: int = _last - _first + 1
	var step: int = int(_time * _fps)
	if _loop:
		frame = _first + step % count
	else:
		frame = _first + mini(step, count - 1)


## Play an animation of this kind (see KINDS). Unknown names are ignored.
func play(anim: StringName, loop: bool = true) -> void:
	if not _anims.has(anim):
		return
	if anim == animation and loop == _loop:
		return
	var data: Array = _anims[anim]
	animation = anim
	_first = int(data[0])
	_last = int(data[1])
	_fps = float(data[2])
	_loop = loop
	_time = 0.0
	if _first < hframes * vframes:
		frame = _first


## Look right (+1) or left (-1).
func face(direction: int) -> void:
	flip_h = direction < 0

class_name Npc
extends SimEntity
## `objects/npc` (`kind=elder|kid|warrior` [elder], `facing=l|r`, `turn` [true]): a friendly villager (the ending
## stage's welcome, ASSET_MANIFEST.md 6). Purely cosmetic: it plays its idle loop, turns to face the hero while he
## is near (unless `turn=false`), never hurts, cannot be hit or collected and is counted nowhere.
##
## The feet point is the bottom-centre of the cell it is placed in, like every other standing entity.

## The villagers: sheet, cell size, pivot (art px) and idle frames of ASSET_MANIFEST.md 6.
const KINDS: Dictionary = {
	"elder": {"sheet": "res://assets/sprites/npc/elder.png", "cell": Vector2i(64, 88), "pivot": Vector2i(32, 72),
			"frames": 5},
	"kid": {"sheet": "res://assets/sprites/npc/kid.png", "cell": Vector2i(48, 80), "pivot": Vector2i(24, 64),
			"frames": 6},
	"warrior": {"sheet": "res://assets/sprites/npc/warrior.png", "cell": Vector2i(72, 88), "pivot": Vector2i(36, 72),
			"frames": 6},
}
const DEFAULT_KIND: String = "elder"
## Idle loop speed of every villager sheet [M 6].
const IDLE_FPS: int = 5
## The villager turns towards the hero while he is closer than this (logical px, sideways / up-down).
const TURN_RANGE_X: int = 96
const TURN_RANGE_Y: int = 48

## Villager (level parameter `kind`).
var kind: String = DEFAULT_KIND
## Turns to face a hero standing near (level parameter `turn`).
var turn: bool = true

var _sprite: Sprite2D = null
var _frames: int = 1
var _age: int = 0


func _init() -> void:
	z_index = Defs.Z_OBJECTS


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.WORLD])


func _apply_params(params: Dictionary) -> void:
	kind = str(params.get("kind", DEFAULT_KIND))
	if not KINDS.has(kind):
		push_warning("objects/npc at %s: unknown kind '%s', using '%s'" % [sim_pos, kind, DEFAULT_KIND])
		kind = DEFAULT_KIND
	turn = param_bool("turn", true)
	var entry: Dictionary = KINDS[kind]
	var cell: Vector2i = entry["cell"]
	var pivot: Vector2i = entry["pivot"]
	_frames = int(entry["frames"])
	_sprite = get_node_or_null(^"Sprite") as Sprite2D
	if _sprite != null:
		_sprite.texture = load(str(entry["sheet"])) as Texture2D
		_sprite.centered = false
		_sprite.hframes = _frames
		_sprite.offset = -Vector2(pivot)
	# Sprite box in logical px, for the on-screen test.
	var w: int = ceili(float(cell.x) / float(Tuning.ART_SCALE))
	set_box(Vector3i(w, ceili(float(pivot.y) / float(Tuning.ART_SCALE)), w >> 1))
	_refresh()


func _sim_tick(_phase: int) -> void:
	_age += 1
	if turn:
		# The hero it turns to: the nearest one enemies would target (2.0, LevelBase.target_hero; 1.0: the hero
		# unless dead).
		var level: LevelBase = Game.level
		var hero: PlayerBase = level.target_hero(self) if level != null else null
		if hero != null:
			var dx: int = hero.sim_pos.x - sim_pos.x
			if absi(dx) < TURN_RANGE_X and absi(hero.sim_pos.y - sim_pos.y) < TURN_RANGE_Y and dx != 0:
				facing = 1 if dx > 0 else -1
	_refresh()


func _refresh() -> void:
	if _sprite == null:
		return
	_sprite.frame = ObjTuning.anim_frame(_age, IDLE_FPS) % _frames
	_sprite.flip_h = facing < 0

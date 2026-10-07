class_name RexPen
extends SimEntity
## `objects/rex_pen` (`name`): the pen of a mount (`objects/mount pen=<name>`, DESIGN.md C.8, PHYSICS.md C.9). Its feet
## point (the floor under its cell) is where Chomper waits tame: after he bolted (Mount BOLT_TICKS after a hit), after a
## death or team wipe, at the stage start. A marker with a fence picture; it takes no tick.
##
## Owner: objects-B (docs/expansion/PLAN.md 4.1). Picture: sprites/objects/rex_pen.png (ASSET_MANIFEST 17.3, a rope
## fence about 3 cells wide, pivot bottom-centre, drawn behind the rex).

## Level-file `name` the mounts refer to.
var pen_name: StringName = &""


func _init() -> void:
	z_index = Defs.Z_PROPS_BACK + 1
	set_box(Vector3i(Tuning.TILE * 3, Tuning.TILE, Tuning.TILE * 3 / 2))


func _apply_params(params: Dictionary) -> void:
	pen_name = StringName(str(params.get("name", "")))


## The pen named `pen` in the level (null when none).
static func find(level: LevelBase, pen: StringName) -> RexPen:
	if level == null or pen == &"":
		return null
	return level.find_named(pen) as RexPen

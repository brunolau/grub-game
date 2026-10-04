class_name FxPopup
extends FxBase
## `fx/popup` (`kind=score|multiplier|one_up|heart` [score], `value`): a value that rises 1 px per tick for
## Tuning.SCORE_POPUP_TICKS at the pick-up or kill position (GAMEPLAY.md 2), drawn with the HUD capitals
## (FxFont). It moves in the ITEMS phase like the original score sprites. At most ObjTuning.MAX_POPUPS are alive at
## once; further requests are not shown.

const TEX_HEART: Texture2D = preload("res://assets/ui/hud_heart.png")
const HEART_CELL: Vector2 = Vector2(32, 32)
## The HUD heart is a 2x icon: drawn at half size it is the 16 px original.
const HEART_SIZE: Vector2 = Vector2(16, 16)
const COLOR_SCORE: Color = Color(1.0, 1.0, 1.0)
const COLOR_MULTIPLIER: Color = Color(1.0, 0.84, 0.37)
const COLOR_ONE_UP: Color = Color(0.56, 0.87, 0.36)

## Shown text ("" for the heart picture).
var text: String = ""
## Text colour.
var tint: Color = COLOR_SCORE

var _heart: bool = false
var _counted: bool = false

static var _alive: int = 0


func _init() -> void:
	super()
	lifetime = Tuning.SCORE_POPUP_TICKS


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		if _alive >= ObjTuning.MAX_POPUPS:
			sim_active = false
			visible = false
			queue_free()
		else:
			_counted = true
			_alive += 1
	elif what == NOTIFICATION_EXIT_TREE and _counted:
		_counted = false
		_alive -= 1


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.ITEMS])


func _apply_params(params: Dictionary) -> void:
	var value: int = int(params.get("value", 0))
	match str(params.get("kind", "score")):
		"multiplier":
			text = "X%d" % value
			tint = COLOR_MULTIPLIER
		"one_up":
			text = "1UP"
			tint = COLOR_ONE_UP
		"heart":
			_heart = true
		_:
			text = str(value)
	queue_redraw()


func _fx_tick() -> void:
	sim_pos.y -= 1
	if lifetime - age <= ObjTuning.POPUP_BLINK_TICKS:
		visible = (age & 1) == 0


func _draw() -> void:
	if _heart:
		draw_texture_rect_region(
			TEX_HEART, Rect2(-HEART_SIZE * Vector2(0.5, 1.0), HEART_SIZE), Rect2(Vector2.ZERO, HEART_CELL)
		)
	else:
		FxFont.draw_centered(self, text, 0, 0, tint)

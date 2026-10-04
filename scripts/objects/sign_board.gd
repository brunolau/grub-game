class_name SignBoard
extends SimEntity
## `objects/sign` (`text=<translation key>`): a hint board. Its text appears above it while the hero stands near.

const FONT: FontFile = preload("res://assets/fonts/pixelify_sans.ttf")
## The 2x size of the pixel face (ASSET_MANIFEST.md 12), matching the density of the art.
const FONT_SIZE: int = 22
const OUTLINE_SIZE: int = 6
const OUTLINE_COLOR: Color = Color("272018")
const TEXT_COLOR: Color = Color("fff1cf")
const TEXT_WIDTH: float = 280.0
## Lowest edge of the text above the feet point, art px: clear of the hero's head.
const TEXT_BOTTOM_ART: float = -84.0

## Translation key of the text.
var text_key: String = ""

var _label: Label = null


func _init() -> void:
	z_index = Defs.Z_OBJECTS
	# The reading area is wider than the board.
	set_box(Vector3i(48, 24, 24))


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.CONTACT_ITEMS])


func _apply_params(params: Dictionary) -> void:
	text_key = str(params.get("text", ""))
	_label = get_node_or_null(^"Text") as Label
	if _label == null:
		return
	var settings: LabelSettings = LabelSettings.new()
	settings.font = FONT
	settings.font_size = FONT_SIZE
	settings.outline_size = OUTLINE_SIZE
	settings.outline_color = OUTLINE_COLOR
	settings.font_color = TEXT_COLOR
	_label.label_settings = settings
	_label.text = tr(text_key)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size = Vector2(TEXT_WIDTH, 0.0)
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.position = Vector2(-TEXT_WIDTH * 0.5, TEXT_BOTTOM_ART)
	# In front of the actors, like the effects.
	_label.z_as_relative = false
	_label.z_index = Defs.Z_FX
	_label.visible = false


func _sim_tick(_phase: int) -> void:
	if _label == null or text_key.is_empty():
		return
	var level: LevelBase = Game.level
	var near: bool = level != null and level.player != null and not level.player.dead \
			and Overlap.body(self, level.player, level.player)
	_label.visible = near

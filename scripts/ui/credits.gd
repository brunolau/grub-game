class_name CreditsScreen
extends UiScreen
## Scrolling credits, generated at run time from the wording of `CREDITS.md` (shipped with every export):
## the suggested in-game wording (Art / Music / Sound), the required font attributions, every source pack with
## author and licence, and the engine notice. Down speeds the roll up, Up rewinds; the confirm button or "back"
## returns to the title, and so does the end of the roll.

const CREDITS_PATH: String = "res://CREDITS.md"
const SPEED: float = 30.0          ## art px per second
const FAST_FACTOR: float = 6.0
const TEXT_WIDTH: float = 520.0
const END_HOLD: float = 3.0

var _roll: VBoxContainer = null
var _clip: Control = null
var _offset: float = 0.0
var _end_time: float = 0.0


## The credits as a list of [heading key, [lines...]] parsed from CREDITS.md (public for tests).
static func parse_credits(text: String) -> Array[Array]:
	var sections: Array[Array] = []
	var lines: PackedStringArray = text.split("\n")
	var section: String = ""
	var intro: String = ""
	var packs: PackedStringArray = PackedStringArray()
	var fonts: PackedStringArray = PackedStringArray()
	var engine: String = ""
	var wording: String = ""
	for raw: String in lines:
		var line: String = raw.strip_edges()
		if line.begins_with("## "):
			section = line.substr(3).to_lower()
			continue
		if line.begins_with("# ") or line.is_empty():
			continue
		if section == "" and intro == "" and not line.begins_with("All "):
			intro = line.get_slice(". ", 0).trim_suffix(".") + "."
		elif section.begins_with("art") and line.begins_with("|") and not line.begins_with("|---"):
			var cells: PackedStringArray = line.trim_prefix("|").trim_suffix("|").split("|")
			if cells.size() >= 4 and cells[0].strip_edges() != "Pack":
				packs.append("%s\n%s - %s" % [cells[0].strip_edges(), cells[1].strip_edges(), cells[3].strip_edges()])
		elif section.begins_with("required") and line.begins_with("- "):
			fonts.append(line.substr(2))
		elif section.begins_with("courtesy") and line.begins_with("Suggested in-game wording:"):
			wording = line.get_slice("\"", 1)
		elif section.begins_with("engine") and engine == "":
			engine = line.get_slice(". ", 0).trim_suffix(".") + "."
	if intro != "":
		sections.append(["", [intro]])
	var roles: RegEx = RegEx.create_from_string("([A-Z][a-z]+): (.*?)\\.(?= [A-Z][a-z]+: |$)")
	for found: RegExMatch in roles.search_all(wording):
		var names: PackedStringArray = PackedStringArray()
		for person: String in found.get_string(2).split(", "):
			names.append(person.strip_edges())
		sections.append(["UI_CREDITS_" + found.get_string(1).to_upper(), Array(names)])
	if not fonts.is_empty():
		sections.append(["UI_CREDITS_FONTS", Array(fonts)])
	if not packs.is_empty():
		sections.append(["UI_CREDITS_PACKS", Array(packs)])
	if engine != "":
		sections.append(["UI_CREDITS_ENGINE", [engine]])
	return sections


func _build_screen() -> void:
	var sky: UiBackdrop = UiBackdrop.new("ice", 8.0)
	sky.modulate = Color(0.45, 0.45, 0.6)
	add_child(sky)
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.add_child(_clip)
	_roll = VBoxContainer.new()
	_roll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roll.add_theme_constant_override(&"separation", 4)
	_clip.add_child(_roll)
	var logo: TextureRect = UiKit.picture(UiKit.tex("res://assets/ui/title_logo.png"))
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_roll.add_child(logo)
	var text: String = ""
	if FileAccess.file_exists(CREDITS_PATH):
		text = FileAccess.get_file_as_string(CREDITS_PATH)
	for entry: Array in parse_credits(text):
		_add_gap(18.0)
		if str(entry[0]) != "":
			_add_line(str(entry[0]), UiKit.Style.HUD, UiKit.COL_FOCUS, true)
		var names: Array = entry[1]
		var small: bool = str(entry[0]) == "UI_CREDITS_FONTS" or str(entry[0]) == "UI_CREDITS_PACKS"
		for line: Variant in names:
			_add_line(str(line), UiKit.Style.SMALL if small else UiKit.Style.BODY, UiKit.COL_CREAM, false)
			if small:
				_add_gap(4.0)
	_add_gap(40.0)
	_add_line("UI_CREDITS_THANKS", UiKit.Style.HUD, UiKit.COL_FOCUS, true)
	var corner: UiPrompts = UiPrompts.new()
	corner.add_hint(&"ui_cancel", "UI_HINT_BACK", _on_cancel)
	corner.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_clip.add_child(corner)


func _screen_ready() -> void:
	Audio.play_music(Sfx.MUSIC_CREDITS)
	_offset = _clip.size.y


func _process(delta: float) -> void:
	var width: float = minf(TEXT_WIDTH, _clip.size.x)
	_roll.size = Vector2(width, _roll.get_combined_minimum_size().y)
	var speed: float = SPEED
	if Input.is_action_pressed(&"ui_down"):
		speed *= FAST_FACTOR
	elif Input.is_action_pressed(&"ui_up"):
		speed = -SPEED * FAST_FACTOR
	var end_offset: float = roundf((_clip.size.y - 30.0) * 0.5) - _roll.size.y
	_offset = clampf(_offset - speed * delta, end_offset, _clip.size.y)
	_roll.position = Vector2(roundf((_clip.size.x - width) * 0.5), roundf(_offset))
	if _offset <= end_offset:
		_end_time += delta
		if _end_time >= END_HOLD:
			leave()
	else:
		_end_time = 0.0


func _on_accept() -> void:
	leave()


func _on_cancel() -> void:
	leave()


## Back to the title screen.
func leave() -> void:
	if not is_accepting_input():
		return
	Audio.play_sfx(Sfx.MENU_BACK)
	go_to(Flow.SCREEN_TITLE)


func _add_line(text: String, style: int, color: Color, translate: bool) -> void:
	var line: Label = UiKit.label(text, style, HORIZONTAL_ALIGNMENT_CENTER)
	line.add_theme_color_override(&"font_color", color)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.size_flags_horizontal = Control.SIZE_FILL
	if not translate:
		line.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_roll.add_child(line)


func _add_gap(height: float) -> void:
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0.0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roll.add_child(gap)

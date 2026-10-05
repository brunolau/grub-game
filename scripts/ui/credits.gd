class_name CreditsScreen
extends UiScreen
## Scrolling credits, generated at run time from the wording of `CREDITS.md` (shipped with every export):
## the suggested in-game wording (Art / Music / Sound), the required font attributions, every source pack with
## author and licence, and the engine notice. Down speeds the roll up, Up rewinds; the confirm button or "back"
## returns to the title, and so does the end of the roll.
##
## The look button (or a tap on its prompt) opens the licence texts that ship in `assets/licenses/` (the MIT
## notice of the engine, both SIL OFL fonts, the engine's third-party components): the only place a player on a
## phone can read them. Up / Down (wheel, drag) scroll, Left / Right change the text, "back" returns to the roll,
## which waits meanwhile. The long third-party text is read only when its page is opened.

const CREDITS_PATH: String = "res://CREDITS.md"
const SPEED: float = 30.0          ## art px per second
const FAST_FACTOR: float = 6.0
const TEXT_WIDTH: float = 520.0
const END_HOLD: float = 3.0
## Confirm and a tap are ignored this long after the roll opened (a player who pressed Enter on The End just as it
## moved on would otherwise skip the whole roll); Back leaves at once.
const ACCEPT_GRACE: float = 1.5
## Where the roll starts: its top (the logo) this far down the view, so the screen never opens empty.
const START_TOP: float = 0.3
## Licence texts: [title (a translation key or a name), file]. Shipped with every export (include filter).
const LICENCES: Array[Array] = [
	["Godot Engine", "res://assets/licenses/godot_engine.txt"],
	["Press Start 2P", "res://assets/licenses/googlefonts_pressstart2p.txt"],
	["Pixelify Sans", "res://assets/licenses/googlefonts_pixelifysans.txt"],
	["UI_LICENCES_THIRD_PARTY", "res://assets/licenses/godot_third_party.txt"],
]
## Lines of a licence text per label (long texts are split, so that only the visible part is drawn).
const LICENCE_CHUNK_LINES: int = 60
## Scroll speed of the licence text with Up / Down held (art px per second).
const LICENCE_SCROLL_SPEED: float = 240.0

var _roll: VBoxContainer = null
var _clip: Control = null
var _offset: float = 0.0
var _end_time: float = 0.0
## Seconds since the roll opened.
var _age: float = 0.0
var _corner: UiPrompts = null
var _viewer: Control = null
var _viewer_title: Label = null
var _viewer_scroll: ScrollContainer = null
var _viewer_text: VBoxContainer = null
var _viewer_prompts: UiPrompts = null
## Index into LICENCES of the text on screen (-1 = the licence view is closed).
var licence_page: int = -1


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
	_corner = UiPrompts.new()
	_corner.add_hint(Defs.ACT_LOOK, "UI_HINT_LICENCES", open_licences)
	_corner.add_hint(&"ui_cancel", "UI_HINT_BACK", _on_cancel)
	_corner.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_clip.add_child(_corner)
	_build_viewer()


func _screen_ready() -> void:
	Audio.play_music(Sfx.MUSIC_CREDITS)
	_offset = roundf(_clip.size.y * START_TOP)


func _process(delta: float) -> void:
	_age += delta
	if is_licence_open():
		var step: float = Input.get_axis(&"ui_up", &"ui_down") * LICENCE_SCROLL_SPEED * delta
		if step != 0.0:
			_viewer_scroll.scroll_vertical = int(roundf(float(_viewer_scroll.scroll_vertical) + step))
		return
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


func _unhandled_input(event: InputEvent) -> void:
	if is_accepting_input() and not event.is_echo():
		if not is_licence_open() and event.is_action_pressed(Defs.ACT_LOOK):
			get_viewport().set_input_as_handled()
			open_licences()
			return
		if is_licence_open() and (event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"ui_left")):
			get_viewport().set_input_as_handled()
			show_licence(licence_page + (1 if event.is_action_pressed(&"ui_right") else -1))
			return
	super._unhandled_input(event)


func _on_accept() -> void:
	if is_licence_open():
		show_licence(licence_page + 1)
		return
	if _age < ACCEPT_GRACE:
		return
	leave()


func _on_cancel() -> void:
	if is_licence_open():
		close_licences()
		return
	leave()


func _on_tap() -> void:
	if not is_licence_open() and _age >= ACCEPT_GRACE:
		leave()


## True while the licence texts are on screen.
func is_licence_open() -> bool:
	return licence_page >= 0


## Show the licence texts (the first one); the roll waits.
func open_licences() -> void:
	if is_licence_open() or not is_accepting_input():
		return
	Audio.play_sfx(Sfx.MENU_SELECT)
	_roll.visible = false
	_corner.visible = false
	_viewer.visible = true
	show_licence(0)


## Back from the licence texts to the roll.
func close_licences() -> void:
	if not is_licence_open():
		return
	Audio.play_sfx(Sfx.MENU_BACK)
	licence_page = -1
	_viewer.visible = false
	_roll.visible = true
	_corner.visible = true
	_end_time = 0.0
	for child: Node in _viewer_text.get_children():
		_viewer_text.remove_child(child)
		child.queue_free()


## Show licence text `index` of LICENCES (wraps around).
func show_licence(index: int) -> void:
	var count: int = LICENCES.size()
	var page: int = posmod(index, count)
	if page != licence_page and licence_page >= 0:
		Audio.play_sfx(Sfx.MENU_MOVE)
	licence_page = page
	_viewer_title.text = "< %s  %d/%d >" % [tr(str(LICENCES[page][0])), page + 1, count]
	for child: Node in _viewer_text.get_children():
		_viewer_text.remove_child(child)
		child.queue_free()
	var path: String = str(LICENCES[page][1])
	var text: String = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var lines: PackedStringArray = text.strip_edges(false, true).split("\n")
	for start: int in range(0, lines.size(), LICENCE_CHUNK_LINES):
		var chunk: Label = UiKit.label("\n".join(lines.slice(start, start + LICENCE_CHUNK_LINES)), UiKit.Style.SMALL)
		chunk.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		chunk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		chunk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chunk.mouse_filter = Control.MOUSE_FILTER_PASS
		_viewer_text.add_child(chunk)
	_viewer_scroll.scroll_vertical = 0


## Text of the licence on screen ("" while closed; tests).
func get_licence_text() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for child: Node in _viewer_text.get_children():
		parts.append((child as Label).text)
	return "\n".join(parts)


## The licence view: a panel with the title row (tap its left / right half to change the text), the scrolling text
## and its prompts.
func _build_viewer() -> void:
	_viewer = VBoxContainer.new()
	_viewer.visible = false
	_viewer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewer.add_theme_constant_override(&"separation", 6)
	safe.add_child(_viewer)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 6)
	var box: PanelContainer = UiKit.panel_box(content, 12)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewer.add_child(box)
	_viewer_title = UiKit.label("", UiKit.Style.HUD, HORIZONTAL_ALIGNMENT_CENTER)
	_viewer_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_viewer_title.add_theme_color_override(&"font_color", UiKit.COL_FOCUS)
	_viewer_title.mouse_filter = Control.MOUSE_FILTER_STOP
	_viewer_title.gui_input.connect(_on_title_input)
	content.add_child(_viewer_title)
	var line: ColorRect = ColorRect.new()
	line.color = Color(UiKit.COL_INK, 0.5)
	line.custom_minimum_size = Vector2(0.0, 2.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(line)
	_viewer_scroll = ScrollContainer.new()
	_viewer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_viewer_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_viewer_scroll)
	_viewer_text = VBoxContainer.new()
	_viewer_text.add_theme_constant_override(&"separation", 0)
	_viewer_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewer_scroll.add_child(_viewer_text)
	_viewer_prompts = UiPrompts.new()
	_viewer_prompts.add_hint(&"ui_right", "UI_HINT_NEXT", show_licence_next)
	_viewer_prompts.add_hint(&"ui_cancel", "UI_HINT_BACK", close_licences)
	_viewer.add_child(_viewer_prompts)


## Next licence text (prompt tap).
func show_licence_next() -> void:
	show_licence(licence_page + 1)


func _on_title_input(event: InputEvent) -> void:
	if UiKit.is_tap(event) and is_licence_open():
		_viewer_title.accept_event()
		var button: InputEventMouseButton = event as InputEventMouseButton
		show_licence(licence_page + (-1 if button.position.x < _viewer_title.size.x * 0.5 else 1))


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

class_name WorldMapScreen
extends UiScreen
## World map shown before every level (GAMEPLAY.md 11.1 step 6): the two-screen map scrolls in, the hero walks
## from the last level's marker to the next one, and the level starts on the confirm button or by itself.
##
## Args: {"level_id": StringName}, optionally {"campaign": Array of level ids} to place the markers of another
## level list (previews, tests); by default the campaign of the current mode. Ends with
## `Flow.start_level(Flow.args["level_id"])` (ARCHITECTURE.md 8.6).
## Every campaign level of the current mode has a marker on an island: gold = completed, cream = reached,
## grey = not reached yet. Each world has its island (MARKERS: jungle on the left, the caves and the ice on the two
## grey rocks, the volcano on the right, which only Expert runs visit). A stage without a marker of its own stands at
## the marker of the map stop it belongs to: a linked sub-stage at its main level, a bonus stage at its source level,
## the ending at the last stop. Levels outside the campaign (test levels) show the hero in the middle of the map.
## 2.0 (PLAN.md P1.11; the Far Shore map page of Book II is P2.8): the markers are the campaign of the running book
## (Game.book; Book II's stops spread over the SLOTS until its map page exists), marker colours come from the save
## namespace of the run (Flow.save_space: mode x book x difficulty), every hero of a co-op party walks the route in his
## colour (P2 one step behind P1), and "back" ends the run through Flow.goto_title (the party's seats are freed). The
## menu clusters are off here: a stray Look (Q / Num .) must not end a co-op run; Space and Num Enter still start the
## stage (Godot's ui_accept), and the stage starts by itself anyway.

## Seconds the map waits on the marker before the level starts by itself.
const AUTO_START: float = 4.0
const WALK_SECONDS: float = 1.4
const SCROLL_IN_PX: float = 260.0
const MAP_TEXTURE: String = "res://assets/ui/world_map_background.png"
const SKY_COLOR: Color = Color("98e6ff")
const SEA_COLOR: Color = Color("77d9ff")
## Marker of each campaign stage on the islands of world_map_background.png (map px), by Vector2i(world, stage):
## the sand and grass of the jungle island, the beaches of the two grey rocks (caves above, ice below), the shore
## of the volcano island. The two rocks overlap in the picture: 2-2 stands at the far right of the upper beach and
## 3-1 at the far left of the lower one, so that 2-2's number plate keeps clear of the 3-1 marker and the hero
## standing on either stop covers neither the other marker nor its plate (test_ui_screens checks the spacing).
const MARKERS: Dictionary = {
	Vector2i(1, 1): Vector2(180, 211), Vector2i(1, 2): Vector2(362, 198),
	Vector2i(2, 1): Vector2(586, 185), Vector2i(2, 2): Vector2(712, 185),
	Vector2i(3, 1): Vector2(656, 219), Vector2i(3, 2): Vector2(786, 219),
	Vector2i(4, 1): Vector2(992, 241), Vector2i(4, 2): Vector2(1186, 241),
}
## Fallback places for a campaign stage without an entry in MARKERS (other level lists, previews): the stages are
## spread over these.
const SLOTS: Array[Vector2] = [
	Vector2(180, 206), Vector2(265, 198), Vector2(335, 186), Vector2(402, 208), Vector2(598, 184),
	Vector2(680, 186), Vector2(740, 214), Vector2(985, 238), Vector2(1085, 224), Vector2(1195, 238),
]
const MARKER_RADIUS: float = 8.0
## Number plate of a marker: its top edge below the marker centre and its height (map px).
const PLATE_GAP: float = 12.0
const PLATE_HEIGHT: float = 12.0
const COL_LOCKED: Color = Color("8a8f99")
## Co-op: the partners walk this far behind P1 (map px) and stand there on the marker.
const PARTNER_GAP: float = 30.0

## Seconds left before the level starts by itself (negative while the hero is still walking).
var countdown: float = -1.0

var _level_id: StringName = &""
var _map: Control = null
## The map picture, held for the whole screen (a texture drawn from a local would be freed after the draw call).
var _map_texture: Texture2D = null
var _fill: Control = null
var _hero: UiActor = null
## Co-op: the heroes of P2.. (P1 is _hero).
var _partners: Array[UiActor] = []
var _here: TextureRect = null
var _markers: Array[Vector2] = []
var _marker_ids: Array[StringName] = []
var _target: Vector2 = Vector2.ZERO
var _walk: Tween = null
var _time: float = 0.0
var _font: Font = UiKit.font(UiKit.Style.MONO)


func _build_screen() -> void:
	_level_id = StringName(str(Flow.args.get("level_id", "")))
	_fill = Control.new()
	_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.draw.connect(_draw_fill)
	add_child(_fill)
	_map = Control.new()
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_texture = UiKit.tex(MAP_TEXTURE)
	_map.size = _map_texture.get_size() if _map_texture != null else Vector2(1280.0, 360.0)
	_map.draw.connect(_draw_map)
	add_child(_map)
	_place_markers()
	for slot: int in range(1, party_size()):
		var partner: UiActor = UiActor.new(&"hero", &"idle")
		_dress(partner, slot)
		_map.add_child(partner)
		_partners.append(partner)
	_hero = UiActor.new(&"hero", &"idle")
	if party_size() > 1:
		_dress(_hero, 0)
	_map.add_child(_hero)
	_here = UiKit.picture(UiKit.icon(UiKit.ICON_DOWN))
	_map.add_child(_here)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(column)
	var header: VBoxContainer = VBoxContainer.new()
	header.add_theme_constant_override(&"separation", 2)
	var where: Label = UiKit.label(_where_text(), UiKit.Style.HUD, HORIZONTAL_ALIGNMENT_CENTER)
	where.add_theme_color_override(&"font_color", UiKit.COL_CREAM)
	where.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	where.visible = where.text != ""
	header.add_child(where)
	var title: Label = UiKit.label(UiKit.level_name(_level_id), UiKit.Style.HUD, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override(&"font_color", UiKit.COL_FOCUS)
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	header.add_child(title)
	var header_box: PanelContainer = UiKit.panel_box(header, 10)
	header_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	header_box.custom_minimum_size = Vector2(260.0, 0.0)
	column.add_child(header_box)
	var spacer: Control = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var footer: HBoxContainer = HBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(footer)
	var lives: Label = UiKit.label("%s x%d   %s" % [
		tr("UI_LIVES"), Game.lives, UiKit.score_text(Game.score)], UiKit.Style.HUD)
	lives.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(lives)
	var prompts: UiPrompts = UiPrompts.new()
	prompts.add_hint(&"ui_accept", "UI_HINT_START", _on_accept)
	prompts.add_hint(&"ui_cancel", "UI_HINT_TITLE", _on_cancel)
	footer.add_child(prompts)


func _screen_ready() -> void:
	Audio.play_music(Sfx.MUSIC_MAP)
	GameInput.set_menu_clusters(false)
	resized.connect(_on_resized)
	var index: int = _marker_ids.find(map_stop(_level_id))
	_target = _markers[index] if index >= 0 else SLOTS[SLOTS.size() / 2]
	var start: Vector2 = _target
	if index > 0:
		start = _markers[index - 1]
	_hero.position = start
	_hero.face(1 if _target.x >= start.x else -1)
	_follow()
	_here.visible = false
	_on_resized()
	# The map scrolls in, then the hero walks (or jumps in at the first level).
	var camera_to: float = _camera_x(start.x)
	var camera_from: float = _scroll_in_from(camera_to)
	_set_camera(camera_from)
	_walk = create_tween()
	_walk.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_walk.tween_method(_set_camera, camera_from, camera_to, 0.8)
	if start != _target:
		_walk.tween_callback(_hero.play.bind(&"walk"))
		_walk.set_ease(Tween.EASE_IN_OUT)
		_walk.tween_method(_walk_hero.bind(start), 0.0, 1.0, WALK_SECONDS)
	else:
		_walk.tween_callback(_hero.play.bind(&"jump", false))
		_walk.tween_property(_hero, "position:y", _target.y - 24.0, 0.18)
		_walk.tween_property(_hero, "position:y", _target.y, 0.18).set_ease(Tween.EASE_IN)
	_walk.tween_callback(_arrive)


func _process(delta: float) -> void:
	_time += delta
	if _here.visible:
		_here.position = Vector2(_target.x - 16.0, _target.y - 96.0 - roundf(absf(sin(_time * 4.0)) * 4.0))
	_follow()
	if countdown < 0.0 or not is_accepting_input():
		return
	countdown -= delta
	if countdown <= 0.0:
		start_level()


func _on_accept() -> void:
	start_level()


func _on_cancel() -> void:
	if is_accepting_input():
		Audio.play_sfx(Sfx.MENU_BACK)
		if begin_leave():
			Flow.goto_title()


## Leave the map and start the level of Flow.args["level_id"].
func start_level() -> void:
	if not begin_leave():
		return
	if _walk != null and _walk.is_valid():
		_walk.kill()
	Audio.play_sfx(Sfx.MENU_SELECT)
	Flow.start_level(_level_id)


func _place_markers() -> void:
	var campaign: Array[StringName] = Levels.get_campaign(Game.difficulty, maxi(Game.book, 1))
	if Flow.args.get("campaign") is Array:
		campaign.clear()
		for id: Variant in Flow.args["campaign"]:
			campaign.append(StringName(str(id)))
	var count: int = campaign.size()
	for i: int in count:
		var place: Vector2 = marker_place(campaign[i])
		if place == Vector2.INF:
			var t: float = 0.0 if count <= 1 else float(i) * float(SLOTS.size() - 1) / float(count - 1)
			if count <= SLOTS.size():
				place = SLOTS[roundi(t)]
			else:
				# More levels than places: interpolate between neighbouring places.
				var low: int = floori(t)
				var high: int = mini(low + 1, SLOTS.size() - 1)
				place = SLOTS[low].lerp(SLOTS[high], t - float(low)).round()
		_markers.append(place)
		_marker_ids.append(campaign[i])


## The island place of a campaign stage (MARKERS by its world and stage), or Vector2.INF when it has none.
static func marker_place(level_id: StringName) -> Vector2:
	var key: Vector2i = Vector2i(int(Levels.get_value(level_id, "world", 0)), int(Levels.get_value(level_id, "stage", 0)))
	return MARKERS.get(key, Vector2.INF)


## The map stop a level is shown at: itself for a campaign level, the main level of a linked sub-stage, the source
## level of a bonus stage, the last stop of the mode for the ending; "" for anything else.
static func map_stop(level_id: StringName) -> StringName:
	var difficulty: int = Game.difficulty
	var campaign: Array[StringName] = Levels.get_campaign(difficulty, maxi(Game.book, 1))
	if campaign.has(level_id):
		return level_id
	var kind: String = str(Levels.get_value(level_id, "kind", Levels.KIND_MAIN))
	match kind:
		Levels.KIND_SUB:
			return Levels.parent_level(level_id, difficulty)
		Levels.KIND_BONUS:
			for id: StringName in campaign:
				if str(Levels.get_value(id, "bonus", "", difficulty)) == String(level_id):
					return id
		Levels.KIND_ENDING:
			return campaign[-1] if not campaign.is_empty() else &""
	return &""


func _walk_hero(t: float, from: Vector2) -> void:
	_hero.position = from.lerp(_target, t).round()
	_set_camera(_camera_x(_hero.position.x))


func _arrive() -> void:
	_hero.position = _target
	# Where the walk ended for the current view size (the window may have been resized meanwhile).
	_set_camera(_camera_x(_target.x))
	_hero.play(&"idle")
	for partner: UiActor in _partners:
		partner.play(&"idle")
	_here.visible = true
	countdown = AUTO_START


## The number plate under the marker at `center` (map px) for the text `number` ("2-2").
func number_plate(center: Vector2, number: String) -> Rect2:
	var width: float = _font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_MONO).x
	return Rect2(roundf(center.x - width * 0.5) - 3.0, center.y + PLATE_GAP, width + 6.0, PLATE_HEIGHT)


## Players on the map: the party of a co-op run, else one.
static func party_size() -> int:
	return clampi(Game.party, 1, Defs.MAX_PLAYERS) if Game.mode == Defs.GameMode.COOP else 1


## The heroes of P2.. on the map (tests).
func get_partners() -> Array[UiActor]:
	return _partners


## The hero of player `slot` in his colour (HeroPalette; P1's yellow with spots keeps no material).
func _dress(actor: UiActor, slot: int) -> void:
	var look: Array = HeroPalette.resolve(slot, Game.get_run(slot))
	actor.material = HeroPalette.material_for(look[0], int(look[1]))


## The partners walk behind P1 on the route (and stand behind him on the marker), mirroring his animation.
func _follow() -> void:
	if _partners.is_empty() or _hero == null:
		return
	var facing: int = -1 if _hero.flip_h else 1
	for i: int in _partners.size():
		var partner: UiActor = _partners[i]
		partner.position = (_hero.position - Vector2(float(facing) * PARTNER_GAP * float(i + 1), 0.0)).round()
		partner.face(facing)
		if partner.animation != _hero.animation:
			partner.play(_hero.animation)


## Map places of the markers on this map (parallel to get_marker_ids()).
func get_markers() -> Array[Vector2]:
	return _markers


## Level ids of the markers on this map.
func get_marker_ids() -> Array[StringName]:
	return _marker_ids


## The map picture on the screen (the camera never shows anything beside it while the map is wider than the view).
func get_map_rect() -> Rect2:
	return Rect2(_map.position, _map.size)


func _camera_x(focus_x: float) -> float:
	var view: float = size.x
	if _map.size.x <= view:
		return (_map.size.x - view) * 0.5
	return clampf(focus_x - view * 0.5, 0.0, _map.size.x - view)


## Where the scroll-in starts: SCROLL_IN_PX to the left of `camera_to`, or to the right of it when the map has no
## room on the left (the first islands). Starting beyond an edge would show the empty screen beside the map.
func _scroll_in_from(camera_to: float) -> float:
	var last: float = _map.size.x - size.x
	if last <= 0.0:
		return camera_to
	if camera_to >= SCROLL_IN_PX:
		return camera_to - SCROLL_IN_PX
	return minf(camera_to + SCROLL_IN_PX, last)


## Place the view at camera x `x`, kept inside the map (a tween that started before the view changed size may ask
## for a place the new size no longer allows); a map narrower than the view stays centred.
func _set_camera(x: float) -> void:
	var last: float = _map.size.x - size.x
	var clamped: float = last * 0.5 if last <= 0.0 else clampf(x, 0.0, last)
	_map.position.x = -roundf(clamped)


func _on_resized() -> void:
	_map.position.y = roundf((size.y - _map.size.y) * 0.5)
	_fill.queue_redraw()
	if countdown >= 0.0:
		_set_camera(_camera_x(_hero.position.x))


func _where_text() -> String:
	var world: int = int(Levels.get_value(_level_id, "world", 0))
	var stage: int = int(Levels.get_value(_level_id, "stage", 0))
	if world > 0 and stage > 0:
		return tr("UI_MAP_WORLD_STAGE").format({"world": world, "stage": stage})
	if world > 0:
		return tr("UI_MAP_WORLD").format({"world": world})
	if str(Levels.get_value(_level_id, "kind", Levels.KIND_MAIN)) == Levels.KIND_BONUS:
		return tr("UI_MAP_BONUS")
	return ""


func _draw_fill() -> void:
	var top: float = _map.position.y
	_fill.draw_rect(Rect2(0.0, 0.0, _fill.size.x, top + 2.0), SKY_COLOR)
	_fill.draw_rect(Rect2(0.0, top + _map.size.y - 2.0, _fill.size.x, _fill.size.y), SEA_COLOR)


func _draw_map() -> void:
	if _map_texture != null:
		_map.draw_texture(_map_texture, Vector2.ZERO)
	# Dotted route between the markers.
	for i: int in range(1, _markers.size()):
		var a: Vector2 = _markers[i - 1]
		var b: Vector2 = _markers[i]
		var steps: int = maxi(1, int(a.distance_to(b) / 9.0))
		for s: int in range(1, steps):
			var p: Vector2 = a.lerp(b, float(s) / float(steps)).round()
			_map.draw_rect(Rect2(p - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), UiKit.COL_INK)
			_map.draw_rect(Rect2(p - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), UiKit.COL_CREAM)
	for i: int in _markers.size():
		var level_id: StringName = _marker_ids[i]
		var center: Vector2 = _markers[i]
		var fill_color: Color = COL_LOCKED
		var space_key: String = Flow.save_space()
		if int(Save.get_level_result_in(space_key, level_id)["clears"]) > 0:
			fill_color = UiKit.COL_FOCUS
		elif i == 0 or Save.is_level_unlocked_in(space_key, level_id) or level_id == map_stop(_level_id):
			fill_color = UiKit.COL_CREAM
		_map.draw_circle(center, MARKER_RADIUS + 2.0, UiKit.COL_INK)
		_map.draw_circle(center, MARKER_RADIUS, fill_color)
		_map.draw_circle(center + Vector2(-2.0, -3.0), 2.0, Color(1.0, 1.0, 1.0, 0.6))
		var number: String = UiKit.level_number(level_id)
		if number == "":
			continue
		var plate: Rect2 = number_plate(center, number)
		_map.draw_rect(plate, Color(UiKit.COL_INK, 0.85))
		_map.draw_string(_font, Vector2(plate.position.x + 3.0, plate.position.y + 10.0), number,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_MONO, UiKit.COL_CREAM)

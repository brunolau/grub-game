class_name HudVersus
extends Control
## The versus HUD of Grub Stack (DESIGN.md E.3 / E.8 / E.9, GAMEPLAY.md 13.10.1; the minimal G1 version of PLAN.md
## P2.9): one corner panel per player (P1 top-left, P2 top-right, P3 bottom-left, P4 bottom-right) with his tag,
## the units on his head (the stack), the units banked in the cookpot, his held special and the rounds he has won;
## the round sundial top centre (its shadow sweeps round as the round runs out, red in the Feast Rush); and the round
## banners: the "3, 2, 1, GRUB!" countdown, "FEAST RUSH!", "SUDDEN DEATH!" and the round result.
##
## Owner: ui-B. Part of [Hud] while `Game.mode` is VERSUS (the campaign rows hide). The round events come from
## `Events.round_*`; the numbers are asked by duck typing from [member source] - by default the level's
## `party_driver` (world-B's referee in an arena) - through the optional methods below. A missing method reads 0, and
## the round clock then counts itself from `Events.round_started` (the arena's `round_time`, else
## `VersusTuning.stack_round_ticks`):
##   stack_of(slot) -> int, banked_of(slot) -> int, round_wins_of(slot) -> int, leader_slot() -> int (the crown;
##   -1 = a tie), round_ticks_left() -> int (-1 = no clock), round_length() -> int (0 = no clock).
## Read once per frame outside the tick; nothing is written back.

## Corner panel size (art px).
const PANEL_SIZE: Vector2 = Vector2(140.0, 50.0)
## Sundial: diameter of the face, and the room under it for the seconds (art px).
const DIAL_SIZE: float = 40.0
const DIAL_TEXT_H: float = 18.0
## Seconds left at which the sundial's numbers turn red.
const DIAL_WARN_SECONDS: int = 10
## Seconds a round banner stays (the countdown numbers stay until the next one).
const BANNER_SECONDS: float = 1.6
const RESULT_SECONDS: float = 3.0
## Pictures of ui/stack_food.png (32 x 28 cells): the roast beside the stack count, the clay pot beside the banked
## count; ui/crown.png (32 x 24, frame 0) over the leader's panel (ties: no crown).
const TEX_STACK_FOOD: String = "res://assets/ui/stack_food.png"
const TEX_CROWN: String = "res://assets/ui/crown.png"
const STACK_CELL: int = 3
const POT_CELL: int = 4
const COL_DIAL: Color = Color("d8c7a0")
const COL_DIAL_SHADOW: Color = Color(0.153, 0.125, 0.094, 0.55)
const COL_RUSH: Color = Color("ff6b5a")


## One player's corner panel.
class CornerPanel:
	extends Control

	## Player slot.
	var slot: int = 0
	## True for the panels on the right side (P2, P4): the content runs right to left.
	var mirrored: bool = false
	var stack: int = 0
	var banked: int = 0
	var wins: int = 0
	var belt: int = PlayerRun.BELT_EMPTY
	## True while this player leads (the referee's leader_slot()): the crown sits on the panel.
	var crowned: bool = false
	var _stack_label: Label = null
	var _banked_label: Label = null
	var _belt_icon: TextureRect = null
	var _food: AtlasTexture = null
	var _pot: AtlasTexture = null
	var _crown: AtlasTexture = null

	func _init(p_slot: int, p_mirrored: bool) -> void:
		slot = p_slot
		mirrored = p_mirrored
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = HudVersus.PANEL_SIZE
		size = HudVersus.PANEL_SIZE
		_food = UiKit.cell(HudVersus.TEX_STACK_FOOD, Vector2i(32, 28), HudVersus.STACK_CELL)
		_pot = UiKit.cell(HudVersus.TEX_STACK_FOOD, Vector2i(32, 28), HudVersus.POT_CELL)
		_crown = UiKit.cell(HudVersus.TEX_CROWN, Vector2i(32, 24), 0)
		var tag: Label = UiPlayers.tag_label(slot)
		tag.position = Vector2(HudVersus.PANEL_SIZE.x - 34.0 if mirrored else 6.0, 4.0)
		add_child(tag)
		_stack_label = UiKit.label("0", UiKit.Style.HUD)
		_stack_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_stack_label)
		_banked_label = UiKit.label("0", UiKit.Style.SMALL)
		_banked_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_banked_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_banked_label)
		_belt_icon = UiKit.picture(null)
		_belt_icon.visible = false
		add_child(_belt_icon)
		_layout()

	## Show new values (only what changed is redrawn).
	func show_values(p_stack: int, p_banked: int, p_wins: int, p_belt: int, p_crowned: bool = false) -> void:
		if p_stack == stack and p_banked == banked and p_wins == wins and p_belt == belt and p_crowned == crowned:
			return
		crowned = p_crowned
		stack = maxi(p_stack, 0)
		banked = maxi(p_banked, 0)
		wins = maxi(p_wins, 0)
		belt = p_belt
		_stack_label.text = str(stack)
		_banked_label.text = str(banked)
		_belt_icon.visible = belt != PlayerRun.BELT_EMPTY
		if _belt_icon.visible:
			_belt_icon.texture = UiPlayers.belt_icon(belt)
		_layout()
		queue_redraw()

	func get_stack_text() -> String:
		return _stack_label.text

	func get_banked_text() -> String:
		return _banked_label.text

	func _layout() -> void:
		var w: float = HudVersus.PANEL_SIZE.x
		_stack_label.reset_size()
		_banked_label.reset_size()
		var stack_w: float = _stack_label.get_minimum_size().x
		var banked_w: float = _banked_label.get_minimum_size().x
		# Outer side: tag, roast, stack count (row 1), pot and banked count (row 2); inner side: the held special.
		if mirrored:
			_stack_label.position = Vector2(w - 70.0 - stack_w, 4.0)
			_banked_label.position = Vector2(w - 26.0 - banked_w, 30.0)
			_belt_icon.position = Vector2(2.0, 9.0)
		else:
			_stack_label.position = Vector2(70.0, 4.0)
			_banked_label.position = Vector2(26.0, 30.0)
			_belt_icon.position = Vector2(w - 34.0, 9.0)

	func _draw() -> void:
		var w: float = HudVersus.PANEL_SIZE.x
		var plate: Rect2 = Rect2(Vector2.ZERO, HudVersus.PANEL_SIZE)
		draw_rect(plate, Color(UiKit.COL_INK, 0.72))
		draw_rect(plate.grow(-1.0), UiPlayers.colour(slot, UiPlayers.SHADE), false, 2.0)
		if _food.atlas != null:
			draw_texture(_food, Vector2(w - 68.0 if mirrored else 34.0, 1.0))
		if _pot.atlas != null:
			draw_texture_rect(_pot, Rect2(w - 24.0 if mirrored else 4.0, 30.0, 18.0, 16.0), false)
		if crowned and _crown.atlas != null:
			# By the tag, on the panel's edge that faces the middle of the view (the top panels' crown hangs below).
			var crown_y: float = HudVersus.PANEL_SIZE.y - 2.0 if slot < 2 else -22.0
			draw_texture(_crown, Vector2(w - 36.0 if mirrored else 4.0, crown_y))
		# Round wins: pips in the player's colour beside the banked count.
		for i: int in mini(wins, VersusTuning.STACK_ROUND_WINS):
			var x: float = w - 72.0 - float(i) * 12.0 if mirrored else 64.0 + float(i) * 12.0
			var pip: Rect2 = Rect2(x, 34.0, 8.0, 8.0)
			draw_rect(pip.grow(1.0), UiKit.COL_INK)
			draw_rect(pip, UiPlayers.colour(slot))


## The round sundial (drawn by hand: a stone face whose shadow sweeps clockwise as the round runs out).
class Sundial:
	extends Control

	## Fraction of the round that has run (0..1).
	var elapsed: float = 0.0
	## Seconds left shown under the face (-1 = none).
	var seconds: int = -1
	## True in the Feast Rush (red rim and numbers).
	var rush: bool = false
	var _label: Label = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(HudVersus.DIAL_SIZE + 24.0, HudVersus.DIAL_SIZE + HudVersus.DIAL_TEXT_H)
		size = custom_minimum_size
		_label = UiKit.label("", UiKit.Style.HUD, HORIZONTAL_ALIGNMENT_CENTER)
		_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.position = Vector2(0.0, HudVersus.DIAL_SIZE - 2.0)
		_label.size = Vector2(size.x, HudVersus.DIAL_TEXT_H)
		add_child(_label)

	## Show the round's state.
	func show_time(p_elapsed: float, p_seconds: int, p_rush: bool) -> void:
		var changed: bool = absf(p_elapsed - elapsed) > 0.002 or p_seconds != seconds or p_rush != rush
		elapsed = clampf(p_elapsed, 0.0, 1.0)
		seconds = p_seconds
		rush = p_rush
		if not changed:
			return
		_label.text = "" if seconds < 0 else "%d:%02d" % [seconds / 60, seconds % 60]
		var warn: bool = rush or (seconds >= 0 and seconds <= HudVersus.DIAL_WARN_SECONDS)
		_label.add_theme_color_override(&"font_color", HudVersus.COL_RUSH if warn else UiKit.COL_TEXT)
		queue_redraw()

	func get_text() -> String:
		return _label.text

	func _draw() -> void:
		var radius: float = HudVersus.DIAL_SIZE * 0.5
		var centre: Vector2 = Vector2(size.x * 0.5, radius)
		draw_circle(centre, radius + 2.0, UiKit.COL_INK)
		draw_circle(centre, radius - 1.0, HudVersus.COL_DIAL)
		if elapsed > 0.0:
			# The shadow wedge from twelve o'clock, clockwise.
			var points: PackedVector2Array = PackedVector2Array([centre])
			var steps: int = maxi(2, ceili(elapsed * 32.0))
			for i: int in steps + 1:
				var angle: float = -PI * 0.5 + TAU * elapsed * float(i) / float(steps)
				points.append(centre + Vector2(cos(angle), sin(angle)) * (radius - 3.0))
			draw_colored_polygon(points, HudVersus.COL_DIAL_SHADOW)
		for hour: int in 12:
			var angle: float = TAU * float(hour) / 12.0
			var dir: Vector2 = Vector2(cos(angle), sin(angle))
			draw_line(centre + dir * (radius - 6.0), centre + dir * (radius - 2.0), UiKit.COL_INK, 2.0)
		var hand_angle: float = -PI * 0.5 + TAU * elapsed
		draw_line(centre, centre + Vector2(cos(hand_angle), sin(hand_angle)) * (radius - 5.0), UiKit.COL_INK, 3.0)
		draw_circle(centre, 3.0, UiKit.COL_INK)
		if rush:
			draw_arc(centre, radius + 1.0, 0.0, TAU, 32, HudVersus.COL_RUSH, 3.0)


## Object asked for the numbers (see the class description); null = the level's party_driver.
var source: Object = null
## Round index of the running (or last) round, -1 before the first.
var round_index: int = -1
## True while a round runs (between round_started and round_ended).
var round_running: bool = false
## True in the Feast Rush of the running round.
var feast_rush: bool = false
## Ticks left of the running round as shown (-1 = no clock).
var ticks_left: int = -1
## Text of the banner on screen ("" = none).
var banner_text: String = ""

var _panels: Array[CornerPanel] = []
var _dial: Sundial = null
var _banner: PanelContainer = null
var _banner_label: Label = null
var _banner_tween: Tween = null
var _round_start_tick: int = 0
var _round_length: int = 0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_build()
	resized.connect(_layout)
	Events.round_countdown.connect(_on_round_countdown)
	Events.round_started.connect(_on_round_started)
	Events.round_feast_rush_started.connect(_on_feast_rush)
	Events.round_sudden_death_started.connect(_on_sudden_death)
	Events.round_ended.connect(_on_round_ended)
	_layout()
	refresh()


func _process(_delta: float) -> void:
	refresh()


## Read the numbers again and show them.
func refresh() -> void:
	var provider: Object = _provider()
	var leader: int = -1
	if provider != null and provider.has_method(&"leader_slot"):
		leader = int(provider.call(&"leader_slot"))
	for panel: CornerPanel in _panels:
		var run: PlayerRun = Game.get_run(panel.slot)
		var belt: int = run.special() if run != null else PlayerRun.BELT_EMPTY
		panel.show_values(_ask(provider, &"stack_of", panel.slot), _ask(provider, &"banked_of", panel.slot),
				_ask(provider, &"round_wins_of", panel.slot), belt, leader >= 0 and leader == panel.slot)
	var length: int = _round_length
	if provider != null and provider.has_method(&"round_length"):
		length = int(provider.call(&"round_length"))
	if provider != null and provider.has_method(&"round_ticks_left"):
		ticks_left = int(provider.call(&"round_ticks_left"))
	elif round_running:
		ticks_left = maxi(_round_length - (Sim.tick - _round_start_tick), 0)
	var elapsed: float = 0.0
	var seconds: int = -1
	if ticks_left >= 0 and length > 0:
		elapsed = 1.0 - float(ticks_left) / float(length)
		seconds = ceili(Tuning.ticks_to_seconds(ticks_left) - 0.0001)
	_dial.show_time(elapsed, seconds, feast_rush)


## The corner panel of a player slot (null when that player is not in the match).
func get_panel(slot: int) -> CornerPanel:
	for panel: CornerPanel in _panels:
		if panel.slot == slot:
			return panel
	return null


## The round sundial.
func get_sundial() -> Sundial:
	return _dial


## True while a banner is on screen.
func is_banner_visible() -> bool:
	return _banner.visible


func _build() -> void:
	for slot: int in clampi(Game.party, 1, Defs.MAX_PLAYERS):
		var panel: CornerPanel = CornerPanel.new(slot, slot % 2 == 1)
		add_child(panel)
		_panels.append(panel)
	_dial = Sundial.new()
	add_child(_dial)
	_banner = PanelContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate: StyleBoxFlat = UiKit.plate(Color(UiKit.COL_INK, 0.82), 8)
	plate.content_margin_left = 16.0
	plate.content_margin_right = 16.0
	plate.set_border_width_all(2)
	plate.border_color = UiKit.COL_CREAM
	_banner.add_theme_stylebox_override(&"panel", plate)
	_banner_label = UiKit.label("", UiKit.Style.TITLE, HORIZONTAL_ALIGNMENT_CENTER)
	_banner_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(_banner_label)
	_banner.visible = false
	add_child(_banner)


## Corner panels inside the safe area, the sundial top centre, the banner in the middle.
func _layout() -> void:
	var margins: Vector4i = UiKit.safe_margins(get_viewport())
	var view: Vector2 = size
	var table: bool = _table_mode()
	for panel: CornerPanel in _panels:
		var right: bool = panel.slot % 2 == 1
		var bottom: bool = panel.slot >= 2
		var x: float = view.x - float(margins.z) - PANEL_SIZE.x if right else float(margins.x)
		var y: float = view.y - float(margins.w) - PANEL_SIZE.y if bottom else float(margins.y)
		if table and panel.slot < 2:
			# Table mode (two touch players, TouchControls): the corners hold the stones; P1's panel sits bottom centre
			# between his d-pad and stones, P2's top centre beside the sundial.
			var beside_dial: float = roundf(view.x * 0.5 - _dial.size.x * 0.5 - 8.0 - PANEL_SIZE.x)
			x = roundf(view.x * 0.5 - PANEL_SIZE.x * 0.5) if panel.slot == 0 else beside_dial
			y = view.y - float(margins.w) - PANEL_SIZE.y if panel.slot == 0 else float(margins.y)
		panel.position = Vector2(x, y).round()
	_dial.position = Vector2(roundf((view.x - _dial.size.x) * 0.5), float(margins.y))
	_place_banner()


## True while two players play on touch slots (the table mode of TouchControls).
static func _table_mode() -> bool:
	var count: int = 0
	for slot: int in Defs.MAX_PLAYERS:
		if GameInput.get_slot(slot).kind == Defs.InputSlotKind.TOUCH:
			count += 1
	return count >= 2


func _place_banner() -> void:
	_banner.reset_size()
	var box: Vector2 = _banner.get_combined_minimum_size()
	_banner.size = box
	_banner.position = ((size - box) * 0.5 - Vector2(0.0, 24.0)).round()


## Show `text` in the middle; it fades after `seconds` (0 = stays until replaced).
func show_banner(text: String, color: Color, style: int, seconds: float) -> void:
	banner_text = text
	UiKit.style_label(_banner_label, style)
	_banner_label.text = text
	_banner_label.add_theme_color_override(&"font_color", color)
	_banner.visible = true
	_banner.modulate.a = 1.0
	_place_banner()
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = null
	if seconds > 0.0:
		_banner_tween = create_tween()
		_banner_tween.tween_interval(seconds)
		_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.3)
		_banner_tween.tween_callback(_hide_banner)


func _hide_banner() -> void:
	_banner.visible = false
	banner_text = ""


## Text of the round result for the winning slots: one player, a team / shared win, or a draw.
static func result_text(winner_slots: PackedInt32Array) -> String:
	if winner_slots.is_empty():
		return TranslationServer.translate("UI_VS_DRAW")
	var tags: PackedStringArray = PackedStringArray()
	for slot: int in winner_slots:
		tags.append(UiPlayers.tag(slot))
	if tags.size() == 1:
		return TranslationServer.translate("UI_VS_ROUND_WIN").format({"player": tags[0]})
	return TranslationServer.translate("UI_VS_ROUND_SHARED").format({"players": " + ".join(tags)})


func _provider() -> Object:
	if source != null and is_instance_valid(source):
		return source
	var level: LevelBase = Game.level
	if level != null and is_instance_valid(level) and level.party_driver != null \
			and is_instance_valid(level.party_driver):
		return level.party_driver
	return null


static func _ask(provider: Object, method: StringName, slot: int) -> int:
	if provider == null or not provider.has_method(method):
		return 0
	return int(provider.call(method, slot))


func _round_ticks() -> int:
	var seconds: int = int(Levels.get_value(Game.level_id, "round_time", 0)) if Game.level_id != &"" else 0
	if seconds > 0:
		return Tuning.seconds_to_ticks(float(seconds))
	return VersusTuning.stack_round_ticks(Game.party)


func _on_round_countdown(p_round_index: int, count: int) -> void:
	round_index = p_round_index
	if count > 0:
		show_banner(str(count), UiKit.COL_CREAM, UiKit.Style.TITLE, 0.0)
	else:
		show_banner(tr("UI_VS_GO"), UiKit.COL_FOCUS, UiKit.Style.TITLE, 0.7)


func _on_round_started(p_round_index: int) -> void:
	round_index = p_round_index
	round_running = true
	feast_rush = false
	_round_start_tick = Sim.tick
	_round_length = _round_ticks()
	if banner_text != "" and banner_text != tr("UI_VS_GO"):
		show_banner(tr("UI_VS_GO"), UiKit.COL_FOCUS, UiKit.Style.TITLE, 0.7)


func _on_feast_rush(_round_index: int) -> void:
	feast_rush = true
	show_banner(tr("UI_VS_FEAST_RUSH"), COL_RUSH, UiKit.Style.HUD, BANNER_SECONDS)


func _on_sudden_death(_round_index: int, _kind: StringName) -> void:
	show_banner(tr("UI_VS_SUDDEN_DEATH"), COL_RUSH, UiKit.Style.HUD, BANNER_SECONDS)


func _on_round_ended(p_round_index: int, winner_slots: PackedInt32Array) -> void:
	round_index = p_round_index
	round_running = false
	feast_rush = false
	var provider: Object = _provider()
	if provider == null or not provider.has_method(&"round_ticks_left"):
		ticks_left = 0
	var color: Color = UiPlayers.text_colour(winner_slots[0]) if winner_slots.size() == 1 else UiKit.COL_FOCUS
	show_banner(result_text(winner_slots), color, UiKit.Style.HUD, RESULT_SECONDS)

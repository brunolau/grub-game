class_name HudVersus
extends Control
## The versus HUD (DESIGN.md E.3 / E.4 / E.8 / E.9, GAMEPLAY.md 13.10.1, PLAN.md P2.9): one corner panel per player
## (P1 top-left, P2 top-right, P3 bottom-left, P4 bottom-right) with his tag, the win pips under it, his head in the
## colour he wears (ui/portrait_heads.png: cheering while he leads, "ouch" while he is knocked out), what the round's
## mode counts ([enum Content]: Grub Stack the units on his head and in the cookpot, Last Caveman Standing his hearts
## and - with the Stock option - his lives, Hot Rock the ember while he holds it (his plate glows red), Clubball his
## side's goals) and his held special; the crown beside the leader's panel; the round sundial top centre (its shadow
## sweeps round as the round runs out, a red rim in the Feast Rush) with the seconds left - hidden in a mode without a
## clock; the round banners: "3, 2, 1, GRUB!", "FEAST RUSH!", "SUDDEN DEATH!" with the arena's theme ("Stampede!"),
## the Golden Drumstick / Golden Coconut of a tie and the result; and while Flow replays a round's deciding moment
## (DESIGN.md E.8) its banner with the skip hint, plus a "Skip" button for touch players (Flow.skip_replay). Where the
## top row cannot hold both top panels, their crowns and the sundial (three-digit counts on a 640 px view) the panels
## leave out the tag text: the head in the player's colour still says who is who.
##
## "TIME!" (DESIGN.md G78 / G95; the 2.0 release round's ruling F1): a round the hard cap ended says so in a line of
## its own over the banner ([member banner_reason], the alarm colour of "SUDDEN DEATH!") - over the result at the
## gong, over "The deciding moment" all through that round's replay, over the result again when the replay ends - so
## the reason is on the screen from the gong until the scoreboard, which says it too (VersusScoreboardScreen). The
## round's own level, referee and HUD are gone the moment the gong hands over to Flow (the replay loads the arena
## again with a new HUD, the scoreboard is another scene), so the HUD that hears the gong notes the round on the match
## ([method note_time]) and whoever shows the round afterwards asks ([method time_called]). While a deciding moment
## plays, the banner is the replay's: the banners of what happens in it again (the countdown, the Feast Rush, the
## sudden death, the Golden Drumstick that lies there) do not replace it.
##
## Never over a hero: every panel is one arena row tall (32 art px). The top panels and the sundial sit in row 0, which
## holds nothing to stand on (LEVEL_DESIGN.md 15.8); the bottom panels sit under the arena's floor line (the floor
## tiles of row 10 and the fill below), so a hero walking on the floor is never behind one. Wherever a hero still
## comes behind a panel (a jump into a corner, a view whose floor leaves no room) the panel fades like the solo HUD
## row (Hud.ROW_UNDER_HERO_ALPHA).
##
## One draw batch (G1: the Label / TextureRect panels cost 31 draw calls of the 4-player arena's 60): this Control has
## no child nodes and draws everything itself - first every picture, plate, edge and pip from [HudAtlas] (one
## texture), then all text in the HUD face, then a banner's text - so the renderer needs one call per texture (two or
## three in all; [member draw_batches]).
##
## Owner: ui-B. Part of [Hud] while `Game.mode` is VERSUS (the campaign rows hide). The round events come from
## `Events.round_*`; the numbers are asked by duck typing from [member source] - by default the level's
## `party_driver` (world-B's referee in an arena) - through the optional members below. A missing one reads 0, and the
## round clock then counts itself from `Events.round_started` (the arena's `round_time`, else
## `VersusTuning.stack_round_ticks`):
##   stack_of(slot) -> int, banked_of(slot) -> int, round_wins_of(slot) -> int, leader_slot() -> int (the crown;
##   -1 = a tie), round_ticks_left() -> int (-1 = no clock running), round_length() -> int (0 = the mode has no
##   clock), `mode` (Defs.VersusMode), hearts_of(slot) -> int (else score_of(slot) in Last Caveman Standing, else the
##   run's hearts), stocks_of(slot) -> int and `rules.stock` (the Stock option), ember_holder() -> int (Hot Rock),
##   score_of(slot) -> int (Clubball: his side's goals), `phase` (VersusReferee.PHASE_GOLDEN: the tie's golden item).
## Read once per frame outside the tick; nothing is written back.

## Panel height (one arena row, art px), its inner padding, and the gap between its parts.
const PANEL_H: float = 32.0
const PAD: float = 4.0
const GAP: float = 3.0
## Plate edge (art px) in the player's shade colour.
const EDGE: float = 2.0
## A bottom panel keeps this far under the arena's floor line (art px).
const FLOOR_GAP: float = 2.0
## Text baseline inside a panel (the HUD face: 14 px capitals, 16 px above the baseline).
const TEXT_BASELINE: float = 21.0
## Win pips under the tag: size and step (art px).
const PIP: float = 5.0
const PIP_STEP: float = 7.0
## Hearts of a hearts mode: step between two (art px).
const HEART_STEP: float = 24.0
## Sundial face (art px; HudAtlas dial cells), and the text that reserves the room of the seconds left.
const DIAL_PX: float = 28.0
const CLOCK_SAMPLE: String = "88"
## Seconds left at which the clock turns red.
const DIAL_WARN_SECONDS: int = 10
## Seconds a round banner stays (the countdown numbers stay until the next one), and its fade.
const BANNER_SECONDS: float = 1.6
const RESULT_SECONDS: float = 3.0
const BANNER_FADE_SECONDS: float = 0.3
const BANNER_PAD: Vector2 = Vector2(16.0, 8.0)
## A panel with a hero behind it fades to this alpha (as the solo HUD row), this fast.
const UNDER_HERO_ALPHA: float = 0.3
const FADE_SECONDS: float = 0.15
## Pictures (HudAtlas groups / cells) and their visible parts inside the cell (art px): the roast beside the stack,
## the clay pot beside the banked count (ui/stack_food.png), crown frame 0 (ui/crown.png), a belt icon, a heart.
const STACK_CELL: int = 3
const POT_CELL: int = 4
const FOOD_PART: Rect2 = Rect2(2.0, 3.0, 28.0, 25.0)
const POT_PART: Rect2 = Rect2(8.0, 1.0, 16.0, 27.0)
const CROWN_PART: Rect2 = Rect2(3.0, 2.0, 26.0, 21.0)
const BELT_PART: Rect2 = Rect2(0.0, 1.0, 32.0, 30.0)
const HEART_PART: Rect2 = Rect2(0.0, 2.0, 32.0, 30.0)
## The Hot Rock emblem (HudAtlas `ember`) and the Clubball coconut (HudAtlas `coconut`): their visible discs.
const EMBER_PART: Rect2 = Rect2(1.0, 1.0, 30.0, 30.0)
const COCONUT_PART: Rect2 = Rect2(1.0, 1.0, 30.0, 30.0)
## Text that reserves the room of the lives left under the Stock option ("x3").
const STOCK_SAMPLE: String = "x8"
## The player's head (ui/portrait_heads.png, 28 x 28 cells).
const HEAD_W: float = 28.0
const COL_PLATE: Color = Color(0.153, 0.125, 0.094, 0.72)
const COL_RUSH: Color = HudAtlas.COL_RUSH
## The second line of the sudden-death banner: the arena's theme (VersusSuddenDeath.THEMES -> text key).
const SUDDEN_DEATH_KEYS: Dictionary = {
	&"stampede": "UI_VS_SD_STAMPEDE",
	&"cave_in": "UI_VS_SD_CAVE_IN",
	&"whiteout": "UI_VS_SD_WHITEOUT",
	&"lava_rise": "UI_VS_SD_LAVA_RISE",
	&"tar_rise": "UI_VS_SD_TAR_RISE",
	&"high_tide": "UI_VS_SD_HIGH_TIDE",
	&"syrup_flood": "UI_VS_SD_SYRUP_FLOOD",
	&"stalactites": "UI_VS_SD_STALACTITES",
	&"rockslide": "UI_VS_SD_ROCKSLIDE",
	&"lightning": "UI_VS_SD_LIGHTNING",
}
## Seconds the banner of the tie's golden item stays.
const GOLDEN_SECONDS: float = 3.0
## The note on the match (Object metadata of Game.versus_match: it ends with the match) of the round the hard cap
## ended last - the round's index ([method note_time], [method time_called]).
const TIME_META: StringName = &"hud_time_round"

## What a corner panel counts, by the round's mode.
enum Content {
	STACK = 0,   ## Grub Stack: the stack (roast) and the banked units (pot)
	HEARTS = 1,  ## Last Caveman Standing: the hearts, and the lives left under the Stock option
	EMBER = 2,   ## Hot Rock: the ember while he holds it
	GOALS = 3,   ## Clubball: his side's goals
}


## One player's corner panel: what it shows and where (the HUD draws it).
class CornerPanel:
	extends RefCounted

	## Player slot.
	var slot: int = 0
	## True for the panels on the right side (P2, P4): the content runs from the outer edge inwards.
	var mirrored: bool = false
	## True for the bottom panels (P3, P4).
	var bottom: bool = false
	var stack: int = 0
	var banked: int = 0
	var wins: int = 0
	## Round wins that take the match (the pips).
	var wins_needed: int = VersusTuning.STACK_ROUND_WINS
	var belt: int = PlayerRun.BELT_EMPTY
	## What the panel counts (Content, by the round's mode).
	var content: int = HudVersus.Content.STACK
	## Hearts left in a mode that counts hearts; -1 = the mode shows something else.
	var hearts: int = -1
	## Lives left under Last Caveman Standing's Stock option; -1 = no Stock.
	var stock: int = -1
	## Hot Rock: true while he holds the ember.
	var ember: bool = false
	## Clubball: his side's goals, and true while the golden coconut of a tie is in play.
	var goals: int = 0
	var golden: bool = false
	## True while this player leads (the referee's leader_slot()): the crown hangs beside the panel.
	var crowned: bool = false
	## Face of his head (UiPlayers.Face): CHEER while he leads, OUCH while his hero is knocked out.
	var face: int = UiPlayers.Face.NORMAL
	## False when the top row is too narrow for the tag text (the head still shows his colour).
	var show_tag: bool = true
	## Alpha of the panel (UNDER_HERO_ALPHA while a hero is behind it).
	var alpha: float = 1.0
	## Screen rectangle of the plate (viewport px).
	var rect: Rect2 = Rect2()

	func get_stack_text() -> String:
		return str(stack)

	func get_banked_text() -> String:
		return str(banked)

	## Text of the lives left under the Stock option ("" without it).
	func get_stock_text() -> String:
		return "x%d" % stock if stock >= 0 else ""

	func get_goals_text() -> String:
		return str(goals)

	## Screen rectangle of the plate (as a Control's global rect).
	func get_global_rect() -> Rect2:
		return rect

	## Screen rectangle of the crown beside the plate (empty while not crowned).
	func get_crown_rect() -> Rect2:
		if not crowned:
			return Rect2()
		var x: float = rect.position.x - HudVersus.GAP - HudVersus.CROWN_PART.size.x if mirrored \
				else rect.end.x + HudVersus.GAP
		return Rect2(x, rect.position.y + roundf((HudVersus.PANEL_H - HudVersus.CROWN_PART.size.y) * 0.5),
				HudVersus.CROWN_PART.size.x, HudVersus.CROWN_PART.size.y)

	## Everything the panel draws on the screen (plate and crown).
	func get_cover_rect() -> Rect2:
		return rect.merge(get_crown_rect()) if crowned else rect


## The round sundial: what it shows and where.
class Sundial:
	extends RefCounted

	## Fraction of the round that has run (0..1).
	var elapsed: float = 0.0
	## Seconds left shown beside the face (-1 = none).
	var seconds: int = -1
	## True in the Feast Rush (red rim and numbers).
	var rush: bool = false
	## False in a mode without a round clock (Hot Rock): nothing is drawn (the rect still ends the HUD row).
	var visible: bool = true
	var alpha: float = 1.0
	## Screen rectangle of its plate (viewport px).
	var rect: Rect2 = Rect2()

	func get_text() -> String:
		return "" if seconds < 0 else str(seconds)

	func get_global_rect() -> Rect2:
		return rect

	## True while the clock shows red (the Feast Rush or the last seconds).
	func is_warning() -> bool:
		return rush or (seconds >= 0 and seconds <= HudVersus.DIAL_WARN_SECONDS)


## Object asked for the numbers (see the class description); null = the level's party_driver.
var source: Object = null
## Level whose heroes make a panel fade and whose floor line places the bottom panels; null = Game.level.
var level_override: LevelBase = null
## Round index of the running (or last) round, -1 before the first.
var round_index: int = -1
## True while a round runs (between round_started and round_ended).
var round_running: bool = false
## True in the Feast Rush of the running round.
var feast_rush: bool = false
## Ticks left of the running round as shown (-1 = no clock).
var ticks_left: int = -1
## Text of the banner on screen ("" = none), and its second line ("" = none).
var banner_text: String = ""
var banner_hint: String = ""
## The reason line over the banner's text ("" = none): "TIME!" from the gong of a round the hard cap ended, through
## its deciding moment, until a new round counts down. It is drawn with the banner ([method get_reason_text] is what
## the screen shows).
var banner_reason: String = ""
## True while Flow replays a round's deciding moment.
var replaying: bool = false
## Draw batches of the last frame drawn: one per change of texture in the draw order (the atlas, the HUD face, a
## banner's face).
var draw_batches: int = 0

var _panels: Array[CornerPanel] = []
var _dial: Sundial = Sundial.new()
var _round_start_tick: int = 0
var _round_length: int = 0
var _font: Font = null
var _banner_font: Font = null
var _banner_size: int = UiKit.SIZE_HUD
var _banner_color: Color = Color.WHITE
var _banner_left: float = 0.0
var _banner_timed: bool = false
var _banner_rect: Rect2 = Rect2()
var _digit_w: float = 16.0
var _tag_w: float = 32.0
var _clock_w: float = 48.0
var _stock_w: float = 32.0
## True from the gong until the next countdown (the dial shows a full shadow while no clock runs).
var _round_over: bool = false
## True once the banner of the tie's golden item showed in this round.
var _golden_shown: bool = false
var _drawn_key: Array = []
var _last_batch: Object = null
var _skip_button: UiButton = null


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UiKit.font(UiKit.Style.HUD)
	_banner_font = _font
	_digit_w = _text_width("8")
	_tag_w = _text_width("P4")
	_clock_w = _text_width(CLOCK_SAMPLE)
	_stock_w = _text_width(STOCK_SAMPLE)
	for slot: int in players_wanted():
		var panel: CornerPanel = CornerPanel.new()
		panel.slot = slot
		panel.mirrored = slot % 2 == 1
		panel.bottom = slot >= 2
		_panels.append(panel)


func _ready() -> void:
	Events.round_countdown.connect(_on_round_countdown)
	Events.round_started.connect(_on_round_started)
	Events.round_feast_rush_started.connect(_on_feast_rush)
	Events.round_sudden_death_started.connect(_on_sudden_death)
	Events.round_ended.connect(_on_round_ended)
	Flow.replay_started.connect(_on_replay_started)
	Flow.replay_finished.connect(_on_replay_finished)
	refresh()


func _process(delta: float) -> void:
	if _banner_timed and banner_text != "":
		_banner_left -= delta
		if _banner_left <= 0.0:
			_hide_banner()
	refresh(delta)


## Read the numbers again, place the panels and fade those with a hero behind them; redraws only on a change.
## `delta` = seconds since the last refresh (0: the fade jumps to its end).
func refresh(delta: float = 0.0) -> void:
	var provider: Object = _provider()
	var leader: int = -1
	if provider != null and provider.has_method(&"leader_slot"):
		leader = int(provider.call(&"leader_slot"))
	var mode: int = _mode(provider)
	var content: int = content_of(mode)
	var needed: int = _wins_needed()
	var stock_rule: bool = content == Content.HEARTS and _stock_rule(provider)
	var holder: int = -1
	if content == Content.EMBER and provider != null and provider.has_method(&"ember_holder"):
		holder = int(provider.call(&"ember_holder"))
	var golden: bool = _golden_phase(provider)
	for panel: CornerPanel in _panels:
		var run: PlayerRun = Game.get_run(panel.slot)
		panel.belt = run.special() if run != null else PlayerRun.BELT_EMPTY
		panel.stack = maxi(_ask(provider, &"stack_of", panel.slot), 0)
		panel.banked = maxi(_ask(provider, &"banked_of", panel.slot), 0)
		panel.wins = maxi(_ask(provider, &"round_wins_of", panel.slot), 0)
		panel.wins_needed = needed
		panel.crowned = leader >= 0 and leader == panel.slot
		panel.face = UiPlayers.Face.CHEER if panel.crowned else UiPlayers.Face.NORMAL
		var hero: PlayerBase = _hero(panel.slot)
		if hero != null and (hero.dead or hero.down):
			panel.face = UiPlayers.Face.OUCH
		panel.content = content
		panel.hearts = -1
		panel.stock = -1
		panel.ember = false
		panel.goals = 0
		panel.golden = false
		match content:
			Content.HEARTS:
				panel.hearts = clampi(_hearts_of(provider, panel.slot, run), 0, Tuning.ENERGY_START)
				if stock_rule:
					panel.stock = maxi(_ask(provider, &"stocks_of", panel.slot), 0)
			Content.EMBER:
				panel.ember = holder >= 0 and holder == panel.slot
			Content.GOALS:
				panel.goals = maxi(_ask(provider, &"score_of", panel.slot), 0)
				panel.golden = golden
	var length: int = _round_length
	if provider != null and provider.has_method(&"round_length"):
		length = int(provider.call(&"round_length"))
	if provider != null and provider.has_method(&"round_ticks_left"):
		ticks_left = int(provider.call(&"round_ticks_left"))
	elif round_running:
		ticks_left = maxi(_round_length - (Sim.tick - _round_start_tick), 0)
	_dial.visible = length > 0
	_dial.elapsed = 0.0
	_dial.seconds = -1
	if ticks_left >= 0 and length > 0:
		_dial.elapsed = clampf(1.0 - float(ticks_left) / float(length), 0.0, 1.0)
		_dial.seconds = ceili(Tuning.ticks_to_seconds(ticks_left) - 0.0001)
	elif golden or _round_over:
		# The clock ran out (the gong, a tie's golden item): the shadow covers the whole dial.
		_dial.elapsed = 1.0
	_dial.rush = feast_rush
	if golden and not _golden_shown:
		_golden_shown = true
		if replaying:
			# A deciding moment that plays while the golden item lies there keeps the replay's banner and skip hint.
			pass
		elif content == Content.GOALS:
			show_banner(tr("UI_VS_GOLDEN_COCONUT"), UiKit.COL_FOCUS, UiKit.Style.HUD, GOLDEN_SECONDS,
					tr("UI_VS_GOLDEN_COCONUT_HINT"))
		else:
			show_banner(tr("UI_VS_GOLDEN_DRUMSTICK"), UiKit.COL_FOCUS, UiKit.Style.HUD, GOLDEN_SECONDS,
					tr("UI_VS_GOLDEN_DRUMSTICK_HINT"))
	_layout()
	_fade(delta)
	var key: Array = _state_key()
	if key != _drawn_key:
		_drawn_key = key
		queue_redraw()


## The corner panel of a player slot (null when that player is not in the match).
func get_panel(slot: int) -> CornerPanel:
	for panel: CornerPanel in _panels:
		if panel.slot == slot:
			return panel
	return null


## Screen rectangle of a player's corner panel (empty when he is not in the match).
func get_panel_rect(slot: int) -> Rect2:
	var panel: CornerPanel = get_panel(slot)
	return panel.rect if panel != null else Rect2()


## The round sundial.
func get_sundial() -> Sundial:
	return _dial


## True while a banner is on screen.
func is_banner_visible() -> bool:
	return banner_text != ""


## Screen rectangle of the banner (empty while none shows).
func get_banner_rect() -> Rect2:
	return _banner_rect if banner_text != "" else Rect2()


## The reason line the screen shows over the banner's text now ("TIME!"; "" when there is none or no banner shows).
func get_reason_text() -> String:
	return banner_reason if banner_text != "" else ""


## Note on the match whether the hard cap ended round `p_round_index` (the versus HUD at that round's gong; nothing
## without a match).
static func note_time(p_round_index: int, capped: bool) -> void:
	var versus_match: VersusMatch = Game.versus_match
	if versus_match == null:
		return
	if capped:
		versus_match.set_meta(TIME_META, p_round_index)
	elif time_called(p_round_index):
		versus_match.remove_meta(TIME_META)


## True when the hard cap ended round `p_round_index` of the match being played ([method note_time]) - asked by who
## shows that round after its gong: the HUD of its deciding moment, the scoreboard.
static func time_called(p_round_index: int) -> bool:
	var versus_match: VersusMatch = Game.versus_match
	if versus_match == null or not versus_match.has_meta(TIME_META):
		return false
	var noted: Variant = versus_match.get_meta(TIME_META)
	return noted is int and int(noted) == p_round_index


## Show `text` in the middle (UiKit.Style TITLE or HUD); it fades after `seconds` (0 = stays until replaced). `hint`
## is a second, smaller line under it ("" = none).
func show_banner(text: String, color: Color, style: int, seconds: float, hint: String = "") -> void:
	banner_text = text
	banner_hint = hint
	_banner_color = color
	_banner_font = UiKit.font(style)
	_banner_size = UiKit.font_size(style)
	_banner_timed = seconds > 0.0
	_banner_left = seconds + BANNER_FADE_SECONDS
	refresh()
	queue_redraw()


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


# --- Layout -----------------------------------------------------------------------------------------------------------

## Width of a panel for what it shows now (the counts take at least two digits, so a panel does not jump at 10).
func panel_width(panel: CornerPanel) -> float:
	var x: float = _content_x(panel) + _counts_width(panel)
	return x + GAP + BELT_PART.size.x + PAD


## Width of what the panel counts (between the head and the belt icon). Room is kept for the ember the whole round,
## so a panel does not jump when it passes.
func _counts_width(panel: CornerPanel) -> float:
	match panel.content:
		Content.HEARTS:
			var hearts: float = HEART_STEP * float(Tuning.ENERGY_START - 1) + HEART_PART.size.x
			return hearts + (GAP + _stock_w if panel.stock >= 0 else 0.0)
		Content.EMBER:
			return EMBER_PART.size.x
		Content.GOALS:
			return COCONUT_PART.size.x + 1.0 + _count_w(panel.goals)
	return FOOD_PART.size.x + 1.0 + _count_w(panel.stack) + GAP + POT_PART.size.x + 1.0 + _count_w(panel.banked)


## Top-left corners: P1 / P2 in row 0 under the safe-area top, the sundial between them; P3 / P4 under the arena's
## floor line (or at the bottom of the safe area when that is lower).
func _layout() -> void:
	var margins: Vector4i = UiKit.safe_margins(get_viewport()) if is_inside_tree() else Vector4i.ONE * UiKit.MARGIN
	var view: Vector2 = get_viewport_rect().size if is_inside_tree() else size
	var top: float = float(maxi(0, margins.y - 2))
	var bottom: float = view.y - float(margins.w) - PANEL_H
	var floor_line: float = floor_line_y()
	if is_finite(floor_line) and floor_line + FLOOR_GAP > bottom:
		bottom = minf(floor_line + FLOOR_GAP, view.y - PANEL_H)
	var table: bool = _table_mode()
	# The top row holds both top panels with their crowns, each on its side of the centred sundial; when a side cannot,
	# every panel drops its tag text.
	var side_room: float = (view.x - _dial_width()) * 0.5 - GAP * 2.0
	var narrow: bool = false
	for panel: CornerPanel in _panels:
		panel.show_tag = true
	for panel: CornerPanel in _panels:
		if not panel.bottom:
			var margin: float = float(margins.z if panel.mirrored else margins.x)
			var crown: float = CROWN_PART.size.x + GAP if panel.crowned else 0.0
			narrow = narrow or margin + panel_width(panel) + crown > side_room
	for panel: CornerPanel in _panels:
		panel.show_tag = not narrow
	for panel: CornerPanel in _panels:
		var w: float = panel_width(panel)
		var x: float = view.x - float(margins.z) - w if panel.mirrored else float(margins.x)
		var y: float = bottom if panel.bottom else top
		if table and panel.slot < 2:
			# Table mode (two touch players, TouchControls): the corners hold the stones; P1's panel sits bottom
			# centre between his d-pad and stones, P2's top centre beside the sundial.
			var dial_w: float = _dial_width()
			x = roundf(view.x * 0.5 - w * 0.5) if panel.slot == 0 else roundf(view.x * 0.5 - dial_w * 0.5 - GAP * 3.0 - w)
			y = view.y - float(margins.w) - PANEL_H if panel.slot == 0 else top
		panel.rect = Rect2(Vector2(x, y).round(), Vector2(w, PANEL_H))
	var dial_w: float = _dial_width()
	_dial.rect = Rect2(Vector2(roundf((view.x - dial_w) * 0.5), top), Vector2(dial_w, PANEL_H))
	if banner_text != "":
		var text: Vector2 = _banner_font.get_string_size(banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _banner_size)
		# The reason line over the text and the hint under it: each one more line in the HUD face.
		for line: String in [banner_reason, banner_hint]:
			if line != "":
				var extra: Vector2 = _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_HUD)
				text = Vector2(maxf(text.x, extra.x), text.y + extra.y)
		var box: Vector2 = (text + BANNER_PAD * 2.0).ceil()
		_banner_rect = Rect2(((view - box) * 0.5 - Vector2(0.0, 24.0)).round(), box)
		if _skip_button != null:
			_skip_button.reset_size()
			var button: Vector2 = _skip_button.get_combined_minimum_size()
			_skip_button.position = Vector2(roundf((view.x - button.x) * 0.5), _banner_rect.end.y + GAP * 2.0)


## Screen y of the arena's floor line (the top of floor row 10; viewport px), INF outside an arena.
func floor_line_y() -> float:
	var level: LevelBase = _level()
	if level == null or not level.is_inside_tree() or not VersusArena.is_arena(level):
		return INF
	var floor_px: float = float(VersusTuning.ARENA_FLOOR_ROW * Tuning.TILE * Tuning.ART_SCALE)
	return (level.get_global_transform_with_canvas() * Vector2(0.0, floor_px)).y


func _dial_width() -> float:
	return PAD + DIAL_PX + GAP + _clock_w + PAD


## True while two players play on touch slots (the table mode of TouchControls).
static func _table_mode() -> bool:
	var count: int = 0
	for slot: int in Defs.MAX_PLAYERS:
		if GameInput.get_slot(slot).kind == Defs.InputSlotKind.TOUCH:
			count += 1
	return count >= 2


## Fade every panel (and the sundial) with a living hero's body behind it.
func _fade(delta: float) -> void:
	var bodies: Array[Rect2] = _hero_bodies()
	var step: float = delta / FADE_SECONDS if delta > 0.0 else 1.0
	for panel: CornerPanel in _panels:
		var target: float = UNDER_HERO_ALPHA if _covers(panel.get_cover_rect(), bodies) else 1.0
		panel.alpha = move_toward(panel.alpha, target, step)
	_dial.alpha = move_toward(_dial.alpha, UNDER_HERO_ALPHA if _covers(_dial.rect, bodies) else 1.0, step)


## Screen rectangles of the bodies of the living heroes (viewport px).
func _hero_bodies() -> Array[Rect2]:
	var result: Array[Rect2] = []
	var level: LevelBase = _level()
	if level == null:
		return result
	for hero: PlayerBase in level.heroes:
		if hero == null or not is_instance_valid(hero) or not hero.is_inside_tree() or hero.dead:
			continue
		var feet: Vector2 = hero.get_global_transform_with_canvas().origin
		var box: Vector2 = Vector2(float(hero.box_w), float(hero.box_h)) * float(Tuning.ART_SCALE)
		result.append(Rect2(feet.x - box.x * 0.5, feet.y - box.y, box.x, box.y))
	return result


static func _covers(rect: Rect2, bodies: Array[Rect2]) -> bool:
	for body: Rect2 in bodies:
		if body.intersects(rect.grow(2.0)):
			return true
	return false


## Everything a frame shows, to redraw only on a change.
func _state_key() -> Array:
	var key: Array = [banner_text, banner_hint, banner_reason, _banner_rect, snappedf(_banner_alpha(), 0.02), _dial.rect,
			HudAtlas.dial_index(_dial.elapsed), _dial.seconds, _dial.rush, _dial.visible, snappedf(_dial.alpha, 0.02)]
	for panel: CornerPanel in _panels:
		key.append_array([panel.rect, panel.content, panel.stack, panel.banked, panel.wins, panel.wins_needed,
				panel.belt, panel.hearts, panel.stock, panel.ember, panel.goals, panel.golden, panel.crowned, panel.face,
				panel.show_tag, snappedf(panel.alpha, 0.02), UiPlayers.palette_of(panel.slot)])
	return key


# --- Drawing ----------------------------------------------------------------------------------------------------------

func _draw() -> void:
	draw_batches = 0
	_last_batch = null
	var atlas: Texture2D = HudAtlas.texture()
	# 1. Pictures, plates, edges and pips: all from the atlas.
	for panel: CornerPanel in _panels:
		_draw_panel_pictures(atlas, panel)
	_draw_dial_pictures(atlas)
	if banner_text != "":
		var alpha: float = _banner_alpha()
		_plate(atlas, _banner_rect, Color(UiKit.COL_INK, 0.82 * alpha), Color(UiKit.COL_CREAM, alpha))
	# 2. Text in the HUD face.
	for panel: CornerPanel in _panels:
		_draw_panel_text(panel)
	if _dial.visible and _dial.seconds >= 0:
		var color: Color = COL_RUSH if _dial.is_warning() else UiKit.COL_TEXT
		_text(_dial.get_text(), _dial.rect.position + Vector2(PAD + DIAL_PX + GAP, TEXT_BASELINE),
				Color(color, _dial.alpha))
	if banner_hint != "" and banner_text != "":
		var hint_w: float = _text_width(banner_hint)
		var hint_at: Vector2 = Vector2(_banner_rect.get_center().x - hint_w * 0.5,
				_banner_rect.end.y - BANNER_PAD.y - _font.get_descent(UiKit.SIZE_HUD))
		_text(banner_hint, hint_at, Color(UiKit.COL_CREAM, _banner_alpha()))
	var line_h: float = _font.get_height(UiKit.SIZE_HUD)
	var reason_h: float = line_h if banner_reason != "" else 0.0
	if banner_reason != "" and banner_text != "":
		# The reason line ("TIME!"): the first line of the plate, in the alarm colour.
		var reason_at: Vector2 = Vector2(_banner_rect.get_center().x - _text_width(banner_reason) * 0.5,
				_banner_rect.position.y + BANNER_PAD.y + _font.get_ascent(UiKit.SIZE_HUD))
		_text(banner_reason, reason_at, Color(COL_RUSH, _banner_alpha()))
	# 3. The banner's text (the title face for the countdown).
	if banner_text != "":
		var ascent: float = _banner_font.get_ascent(_banner_size)
		var height: float = _banner_font.get_height(_banner_size)
		var room: float = _banner_rect.size.y - reason_h - (line_h if banner_hint != "" else 0.0)
		var width: float = _banner_font.get_string_size(banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _banner_size).x
		var at: Vector2 = Vector2(roundf(_banner_rect.get_center().x - width * 0.5),
				_banner_rect.position.y + reason_h + roundf((room - height) * 0.5 + ascent))
		_note_batch(_banner_font)
		draw_string(_banner_font, at, banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _banner_size,
				Color(_banner_color, _banner_color.a * _banner_alpha()))


func _draw_panel_pictures(atlas: Texture2D, panel: CornerPanel) -> void:
	var a: float = panel.alpha
	var r: Rect2 = panel.rect
	# The holder of the hot rock glows: his plate's rim turns ember red.
	var rim: Color = COL_RUSH if panel.ember else UiPlayers.colour(panel.slot, UiPlayers.SHADE)
	_plate(atlas, r, Color(COL_PLATE, COL_PLATE.a * a), Color(rim, a))
	var fill: Color = Color(UiPlayers.colour(panel.slot), a)
	var ink: Color = Color(UiKit.COL_INK, a)
	var white: Rect2 = HudAtlas.white()
	for i: int in panel.wins_needed:
		var pip: Rect2 = _place(panel, PAD + float(i) * PIP_STEP + 1.0, PIP)
		pip.position.y = r.position.y + PANEL_H - EDGE - PIP - 2.0
		pip.size.y = PIP
		_blit(atlas, white, pip.grow(1.0), ink)
		_blit(atlas, white, pip, fill if i < panel.wins else Color(UiKit.COL_DIM, 0.25 * a))
	var tint: Color = Color(1.0, 1.0, 1.0, a)
	var head: Rect2 = _place(panel, _content_x(panel) - HEAD_W - GAP, HEAD_W)
	_blit(atlas, HudAtlas.region(&"head", UiPlayers.head_cell(panel.slot, panel.face)),
			Rect2(head.position + Vector2(0.0, roundf((PANEL_H - HEAD_W) * 0.5)), Vector2.ONE * HEAD_W), tint)
	var x: float = _content_x(panel)
	match panel.content:
		Content.HEARTS:
			for i: int in Tuning.ENERGY_START:
				var heart: Rect2 = _place(panel, x + float(i) * HEART_STEP, HEART_PART.size.x)
				_icon(atlas, &"heart", 0 if i < panel.hearts else 1, HEART_PART, heart, tint)
		Content.EMBER:
			if panel.ember:
				_icon(atlas, &"ember", 0, EMBER_PART, _place(panel, x, EMBER_PART.size.x), tint)
		Content.GOALS:
			var ball: int = HudAtlas.COCONUT_GOLDEN if panel.golden else HudAtlas.COCONUT
			_icon(atlas, &"coconut", ball, COCONUT_PART, _place(panel, x, COCONUT_PART.size.x), tint)
		_:
			_icon(atlas, &"food", STACK_CELL, FOOD_PART, _place(panel, x, FOOD_PART.size.x), tint)
			var pot_x: float = x + FOOD_PART.size.x + 1.0 + _count_w(panel.stack) + GAP
			_icon(atlas, &"food", POT_CELL, POT_PART, _place(panel, pot_x, POT_PART.size.x), tint)
	x += _counts_width(panel)
	if panel.belt != PlayerRun.BELT_EMPTY:
		var cell: int = clampi(panel.belt, Defs.Weapon.CLUB, Defs.Weapon.SPEAR)
		_icon(atlas, &"belt", cell, BELT_PART, _place(panel, x + GAP, BELT_PART.size.x), tint)
	if panel.crowned:
		var crown: Rect2 = panel.get_crown_rect()
		_blit(atlas, HudAtlas.sub_region(&"crown", 0, CROWN_PART), crown, tint)


func _draw_panel_text(panel: CornerPanel) -> void:
	var a: float = panel.alpha
	if panel.show_tag:
		var tag: Rect2 = _place(panel, PAD, _tag_w)
		_text(UiPlayers.tag(panel.slot), Vector2(tag.position.x, panel.rect.position.y + TEXT_BASELINE - 3.0),
				Color(UiPlayers.text_colour(panel.slot), a))
	var baseline: float = panel.rect.position.y + TEXT_BASELINE
	var x: float = _content_x(panel)
	match panel.content:
		Content.HEARTS:
			if panel.stock >= 0:
				x += HEART_STEP * float(Tuning.ENERGY_START - 1) + HEART_PART.size.x + GAP
				var lives: Rect2 = _place(panel, x, _stock_w)
				_text(panel.get_stock_text(), Vector2(lives.position.x, baseline), Color(UiKit.COL_CREAM, a))
		Content.GOALS:
			x += COCONUT_PART.size.x + 1.0
			var goals: Rect2 = _place(panel, x, _count_w(panel.goals))
			_text(panel.get_goals_text(), Vector2(goals.position.x, baseline),
					Color(UiKit.COL_FOCUS if panel.golden else UiKit.COL_TEXT, a))
		Content.STACK:
			x += FOOD_PART.size.x + 1.0
			var stack: Rect2 = _place(panel, x, _count_w(panel.stack))
			_text(str(panel.stack), Vector2(stack.position.x, baseline), Color(UiKit.COL_TEXT, a))
			x += _count_w(panel.stack) + GAP + POT_PART.size.x + 1.0
			var banked: Rect2 = _place(panel, x, _count_w(panel.banked))
			_text(str(panel.banked), Vector2(banked.position.x, baseline), Color(UiKit.COL_CREAM, a))


func _draw_dial_pictures(atlas: Texture2D) -> void:
	if not _dial.visible:
		return
	var a: float = _dial.alpha
	_plate(atlas, _dial.rect, Color(COL_PLATE, COL_PLATE.a * a), Color(UiKit.COL_INK, 0.0))
	var face: Rect2 = Rect2(_dial.rect.position + Vector2(PAD, roundf((PANEL_H - DIAL_PX) * 0.5)), Vector2.ONE * DIAL_PX)
	_blit(atlas, HudAtlas.dial_frame(_dial.elapsed), face, Color(1.0, 1.0, 1.0, a))
	if _dial.rush:
		_blit(atlas, HudAtlas.region(&"dial_rush"), face, Color(1.0, 1.0, 1.0, a))


## A plate: the fill and an EDGE-wide rim (a rim with alpha 0 is left out).
func _plate(atlas: Texture2D, rect: Rect2, fill: Color, rim: Color) -> void:
	var white: Rect2 = HudAtlas.white()
	_blit(atlas, white, rect, fill)
	if rim.a <= 0.0:
		return
	_blit(atlas, white, Rect2(rect.position, Vector2(rect.size.x, EDGE)), rim)
	_blit(atlas, white, Rect2(rect.position.x, rect.end.y - EDGE, rect.size.x, EDGE), rim)
	_blit(atlas, white, Rect2(rect.position.x, rect.position.y + EDGE, EDGE, rect.size.y - EDGE * 2.0), rim)
	_blit(atlas, white, Rect2(rect.end.x - EDGE, rect.position.y + EDGE, EDGE, rect.size.y - EDGE * 2.0), rim)


## A picture of the atlas at its own size, vertically centred in the panel row of `slot_rect`.
func _icon(atlas: Texture2D, group: StringName, cell: int, part: Rect2, slot_rect: Rect2, tint: Color) -> void:
	var y: float = slot_rect.position.y + roundf((PANEL_H - part.size.y) * 0.5)
	_blit(atlas, HudAtlas.sub_region(group, cell, part), Rect2(slot_rect.position.x, y, part.size.x, part.size.y), tint)


func _blit(atlas: Texture2D, source: Rect2, target: Rect2, tint: Color) -> void:
	if tint.a <= 0.0:
		return
	_note_batch(atlas)
	draw_texture_rect_region(atlas, target, source, tint)


func _text(text: String, baseline: Vector2, color: Color) -> void:
	_note_batch(_font)
	draw_string(_font, baseline.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_HUD, color)


## Count a draw batch when the texture (or face) changes.
func _note_batch(what: Object) -> void:
	if what != _last_batch:
		_last_batch = what
		draw_batches += 1


## Where the counts start (art px from the panel's outer edge): after the tag (when shown) and the head.
func _content_x(panel: CornerPanel) -> float:
	return PAD + (_tag_w + GAP if panel.show_tag else 0.0) + HEAD_W + GAP


## The screen rectangle of a part that starts `x` art px from the panel's outer edge and is `width` wide (the right
## panels mirror the order of the parts, not the parts themselves).
func _place(panel: CornerPanel, x: float, width: float) -> Rect2:
	var left: float = panel.rect.end.x - x - width if panel.mirrored else panel.rect.position.x + x
	return Rect2(left, panel.rect.position.y, width, PANEL_H)


func _count_w(value: int) -> float:
	return maxf(_digit_w * 2.0, _text_width(str(maxi(value, 0))))


func _text_width(text: String) -> float:
	return ceilf(_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_HUD).x)


func _banner_alpha() -> float:
	if banner_text == "" or not _banner_timed:
		return 1.0
	return clampf(_banner_left / BANNER_FADE_SECONDS, 0.0, 1.0)


func _hide_banner() -> void:
	banner_text = ""
	banner_hint = ""
	_banner_timed = false
	queue_redraw()


## The skip button of the deciding moment (null unless a touch player watches a replay).
func get_skip_button() -> UiButton:
	return _skip_button


## True where a player may be on touch: a touch screen, a phone, or a touch input slot / the last input a touch.
static func touch_in_use() -> bool:
	if DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or GameInput.device == Defs.Device.TOUCH:
		return true
	for slot: int in Defs.MAX_PLAYERS:
		if GameInput.get_slot(slot).kind == Defs.InputSlotKind.TOUCH:
			return true
	return false


func _on_replay_started(p_round_index: int, _first: int, _last: int, steal: bool) -> void:
	replaying = true
	# This HUD came with the arena the replay loaded: the round's own HUD noted at the gong whether the cap ended it.
	banner_reason = tr("UI_VS_TIME") if time_called(p_round_index) else ""
	show_banner(tr("UI_VS_REPLAY_STEAL" if steal else "UI_VS_REPLAY_MOMENT"), UiKit.COL_FOCUS, UiKit.Style.HUD, 0.0,
			tr("UI_VS_REPLAY_SKIP"))
	if touch_in_use() and _skip_button == null:
		_skip_button = UiButton.new("UI_VS_REPLAY_SKIP_BUTTON")
		_skip_button.mouse_filter = Control.MOUSE_FILTER_STOP
		_skip_button.pressed.connect(Flow.skip_replay)
		add_child(_skip_button)
	refresh()


func _on_replay_finished(_skipped: bool) -> void:
	replaying = false
	if banner_reason != "":
		# The cap ended the round shown: "TIME!" stays, over the round's result, until the scoreboard takes the screen.
		_show_result(_recorded_winners())
	else:
		_hide_banner()
	if _skip_button != null:
		_skip_button.queue_free()
		_skip_button = null


# --- Sources ----------------------------------------------------------------------------------------------------------

func _provider() -> Object:
	if source != null and is_instance_valid(source):
		return source
	var level: LevelBase = _level()
	if level != null and level.party_driver != null and is_instance_valid(level.party_driver):
		return level.party_driver
	return null


func _level() -> LevelBase:
	var level: LevelBase = level_override if level_override != null else Game.level
	return level if level != null and is_instance_valid(level) else null


## The hero of player slot `slot` in the level (null when there is none).
func _hero(slot: int) -> PlayerBase:
	var level: LevelBase = _level()
	if level == null or slot < 0 or slot >= level.heroes.size():
		return null
	var hero: PlayerBase = level.heroes[slot]
	return hero if hero != null and is_instance_valid(hero) else null


## The versus mode of the round: the provider's `mode`, else the match's round mode, else Grub Stack.
static func _mode(provider: Object) -> int:
	if provider != null:
		var value: Variant = provider.get(&"mode")
		if value is int:
			return value
	if Game.versus_match != null:
		return Game.versus_match.round_mode
	return Defs.VersusMode.GRUB_STACK


## What the corner panels count in versus mode `mode` (Defs.VersusMode).
static func content_of(mode: int) -> int:
	match mode:
		Defs.VersusMode.LAST_CAVEMAN:
			return Content.HEARTS
		Defs.VersusMode.HOT_ROCK:
			return Content.EMBER
		Defs.VersusMode.CLUBBALL:
			return Content.GOALS
	return Content.STACK


## Panels this HUD builds: one per player of the match (Game.party, 1..MAX_PLAYERS).
static func players_wanted() -> int:
	return clampi(Game.party, 1, Defs.MAX_PLAYERS)


## Panels this HUD has.
func player_count() -> int:
	return _panels.size()


## True when Last Caveman Standing is played with the Stock option: the provider's `rules.stock`, else the match's.
static func _stock_rule(provider: Object) -> bool:
	var rules: Variant = provider.get(&"rules") if provider != null else null
	if rules is Object and rules != null:
		var stock: Variant = (rules as Object).get(&"stock")
		if stock is bool:
			return stock
	if Game.versus_match != null:
		var value: Variant = Game.versus_match.get(&"stock")
		return value is bool and bool(value)
	return false


## Hearts left of `slot` in a hearts mode: the provider's hearts_of, else its score_of (0 once he is out), else the
## run's hearts.
static func _hearts_of(provider: Object, slot: int, run: PlayerRun) -> int:
	if provider != null and provider.has_method(&"hearts_of"):
		return int(provider.call(&"hearts_of", slot))
	if provider != null and provider.has_method(&"score_of"):
		return int(provider.call(&"score_of", slot))
	return run.hearts if run != null else 0


## True while the round's tie is decided by the golden item (the referee's PHASE_GOLDEN).
static func _golden_phase(provider: Object) -> bool:
	if provider == null:
		return false
	var phase: Variant = provider.get(&"phase")
	return phase is int and int(phase) == VersusReferee.PHASE_GOLDEN


## Round wins that take the match (the pips): the match's rule, else Grub Stack's.
static func _wins_needed() -> int:
	if Game.versus_match != null:
		return clampi(Game.versus_match.round_wins_needed(), 1, 9)
	return VersusTuning.STACK_ROUND_WINS


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
	_round_over = false
	_golden_shown = false
	if replaying:
		return
	banner_reason = ""
	if count > 0:
		show_banner(str(count), UiKit.COL_CREAM, UiKit.Style.TITLE, 0.0)
	else:
		show_banner(tr("UI_VS_GO"), UiKit.COL_FOCUS, UiKit.Style.TITLE, 0.7)


func _on_round_started(p_round_index: int) -> void:
	round_index = p_round_index
	round_running = true
	feast_rush = false
	_round_over = false
	_golden_shown = false
	_round_start_tick = Sim.tick
	_round_length = _round_ticks()
	if replaying:
		return
	banner_reason = ""
	if banner_text != "" and banner_text != tr("UI_VS_GO"):
		show_banner(tr("UI_VS_GO"), UiKit.COL_FOCUS, UiKit.Style.TITLE, 0.7)


func _on_feast_rush(_round_index: int) -> void:
	feast_rush = true
	if not replaying:
		show_banner(tr("UI_VS_FEAST_RUSH"), COL_RUSH, UiKit.Style.HUD, BANNER_SECONDS)


## "SUDDEN DEATH!" and, under it, which one the arena throws in (VersusSuddenDeath's theme: "Stampede!").
func _on_sudden_death(_round_index: int, kind: StringName) -> void:
	if replaying:
		return
	var theme: String = tr(str(SUDDEN_DEATH_KEYS[kind])) if SUDDEN_DEATH_KEYS.has(kind) else ""
	show_banner(tr("UI_VS_SUDDEN_DEATH"), COL_RUSH, UiKit.Style.HUD, BANNER_SECONDS * 1.5, theme)


## The gong: the result, and over it "TIME!" when the hard cap ended the round (the referee's ended_by_cap(), true
## from the gong on). The round is noted on the match for who shows it next ([method note_time]).
func _on_round_ended(p_round_index: int, winner_slots: PackedInt32Array) -> void:
	round_index = p_round_index
	round_running = false
	_round_over = true
	feast_rush = false
	var provider: Object = _provider()
	if provider == null or not provider.has_method(&"round_ticks_left"):
		ticks_left = 0
	var capped: bool = provider != null and provider.has_method(&"ended_by_cap") and bool(provider.call(&"ended_by_cap"))
	note_time(p_round_index, capped)
	banner_reason = tr("UI_VS_TIME") if capped else ""
	_show_result(winner_slots)


## The result banner of a round: who won it, or "Draw!" (under [member banner_reason] when there is one).
func _show_result(winner_slots: PackedInt32Array) -> void:
	var color: Color = UiPlayers.text_colour(winner_slots[0]) if winner_slots.size() == 1 else UiKit.COL_FOCUS
	show_banner(result_text(winner_slots), color, UiKit.Style.HUD, RESULT_SECONDS)


## The winners of the round the match recorded last (none without a match or a recorded round).
static func _recorded_winners() -> PackedInt32Array:
	var versus_match: VersusMatch = Game.versus_match
	if versus_match == null or versus_match.history.is_empty():
		return PackedInt32Array()
	var winners: Variant = versus_match.history[-1].get("winners")
	return winners if winners is PackedInt32Array else PackedInt32Array()

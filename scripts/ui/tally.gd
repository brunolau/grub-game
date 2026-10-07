class_name TallyScreen
extends UiScreen
## End-of-level tally (GAMEPLAY.md 3.7, 3.4): score and completion percentage, the hero walks in, the companion
## slides to the middle, and every bonus collected since the last death drops into the companion, one every
## Tuning.TALLY_ITEM_PERIOD ticks, paying its value again. Then both walk off and `Flow.finish_tally()` runs.
##
## Args: {"level_id": StringName, "percent": int}. The confirm button (or a tap) skips ahead: the remaining items
## are paid at once; a second press leaves. Every item is paid exactly once.
##
## 2.0 co-op (DESIGN.md D.11, GAMEPLAY.md 13.9.9, PLAN.md P2.8): every hero of the party walks in in his colour (P2 a
## step behind P1); the score is the tribe's. After the items the companion hands out the medals of the stage
## (PlayerRun.medals(Game.party_runs()): Most Food, Best Bounce Chain, Hatchling, Slugger, Strongman, Clumsiest; ties
## share one) - one every MEDAL_SECONDS: the medal flies from the companion to its winner's head and its row on the
## medal board lights up with his tag (one row per medal: a shared one lists both); heroes who won one cheer. With the
## "Rival score" option (ui-B's OptionsPanel.KEY_RIVAL_SCORE) the board first shows every hero's own points
## (PlayerRun.score, his share of the tribe score), and an item paid again also counts again for the hero who picked
## it. A skip hands out the rest at once. The companion catches each item on its picker's side
## (Game.tally_item_slots), so every hero gets his own pile.

enum Phase { INTRO, ENTER, DROPS, MEDALS, SETTLE, EXIT, DONE }

const INTRO_SECONDS: float = 0.6
const ENTER_SECONDS: float = 1.5
const FALL_SECONDS: float = 0.45
const SETTLE_SECONDS: float = 0.9
const EXIT_SECONDS: float = 1.4
const HERO_STOP: float = 0.2        ## hero stops at this fraction of the width
const COMPANION_STOP: float = 0.56  ## companion stops here
const CATCH_HEIGHT: float = 52.0    ## items land this far above the companion's feet
## Co-op: the partners stop this far behind P1 (art px), and a medal is handed out every MEDAL_SECONDS.
const PARTNER_GAP: float = 58.0
const MEDAL_SECONDS: float = 0.55
## The medal board's width: this share of the view, at least BOARD_MIN_WIDTH px.
const BOARD_SHARE: float = 0.36
const BOARD_MIN_WIDTH: float = 196.0
## art-A's medals (ui/medals.png): one 32 x 32 gold disc per medal / award (medal_cell).
const TEX_MEDALS: String = "res://assets/ui/medals.png"
const MEDAL_CELL: float = 32.0
## The medal texts by PlayerRun.COOP_MEDALS id: [name, what it was for].
const MEDAL_KEYS: Dictionary = {
	&"most_food": ["UI_MEDAL_MOST_FOOD", "UI_MEDAL_MOST_FOOD_INFO"],
	&"best_bounce_chain": ["UI_MEDAL_BEST_BOUNCE_CHAIN", "UI_MEDAL_BEST_BOUNCE_CHAIN_INFO"],
	&"hatchling": ["UI_MEDAL_HATCHLING", "UI_MEDAL_HATCHLING_INFO"],
	&"slugger": ["UI_MEDAL_SLUGGER", "UI_MEDAL_SLUGGER_INFO"],
	&"strongman": ["UI_MEDAL_STRONGMAN", "UI_MEDAL_STRONGMAN_INFO"],
	&"clumsiest": ["UI_MEDAL_CLUMSIEST", "UI_MEDAL_CLUMSIEST_INFO"],
}

## Current step of the sequence (Phase).
var phase: int = Phase.INTRO
## Items paid so far.
var paid: int = 0
## Co-op: medals handed out so far (entries of [method get_medals]).
var medals_shown: int = 0

var _ids: Array[StringName] = []
var _indices: PackedInt32Array = PackedInt32Array()
var _points: PackedInt32Array = PackedInt32Array()
var _pickers: PackedInt32Array = PackedInt32Array()
var _launched: int = 0
var _phase_time: float = 0.0
var _drop_timer: float = 0.0
var _bonus_total: int = 0
var _stage: Control = null
var _ground: UiGround = null
var _hero: UiActor = null
var _partners: Array[UiActor] = []
var _companion: UiActor = null
var _score_label: Label = null
var _bonus_label: Label = null
var _falling: Array[Node] = []
var _catch_time: float = 0.0
## Co-op: [medal id, winner slot] in hand-out order; the board's column per slot; the medals over the heads.
var _medals: Array[Array] = []
var _board_columns: Dictionary = {}
var _head_medals: Dictionary = {}
## Rival score: the label of each hero's own points, by slot.
var _rival_labels: Dictionary = {}
## Co-op: the medal board (wider on wide views, so the medals' reasons fit).
var _board: VBoxContainer = null


## A medal: art-A's gold disc with its engraved emblem (`ui/medals.png`) hanging from a ribbon in its winner's colour
## (DESIGN.md D.11). Also the versus results' award badge (versus_results.gd, `versus` = a PlayerRun.VERSUS_AWARDS id).
class MedalIcon:
	extends Control

	var medal: StringName = &""
	var ribbon: Color = Color.WHITE
	var versus: bool = false
	# The medal sheet, held while the icon draws it (UiKit.tex keeps no cache).
	var _sheet: Texture2D = UiKit.tex(TallyScreen.TEX_MEDALS)

	func _init(p_medal: StringName, p_ribbon: Color, icon_size: float = 16.0, p_versus: bool = false) -> void:
		medal = p_medal
		ribbon = p_ribbon
		versus = p_versus
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(icon_size, icon_size + 5.0)
		size = custom_minimum_size

	func _draw() -> void:
		TallyScreen.draw_medal(self, Vector2(size.x * 0.5, size.y - size.x * 0.5), size.x * 0.5, medal, ribbon, versus,
				_sheet)


func _build_screen() -> void:
	_ids = Game.tally_item_ids.duplicate()
	_indices = Game.tally_item_indices.duplicate()
	_points = Game.tally_item_points.duplicate()
	if Game.tally_item_slots.size() == _ids.size():
		_pickers = Game.tally_item_slots.duplicate()
	var level_id: StringName = StringName(str(Flow.args.get("level_id", Game.level_id)))
	var biome: String = str(Levels.get_value(level_id, "background", Levels.get_value(level_id, "biome", "jungle")))
	if not UiBackdrop.SETS.has(biome):
		biome = "jungle"
	var night: UiBackdrop = UiBackdrop.new(biome, 10.0)
	night.modulate = Color(0.32, 0.3, 0.42)
	add_child(night)
	_stage = Control.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_ground = UiGround.new(str(Levels.get_value(level_id, "terrain_a", "jungle/terrain_grass")), 2)
	_ground.modulate = Color(0.6, 0.58, 0.72)
	_stage.add_child(_ground)
	for slot: int in range(1, party_size()):
		var partner: UiActor = UiActor.new(&"hero", &"walk")
		_dress(partner, slot)
		_stage.add_child(partner)
		_partners.append(partner)
	_hero = UiActor.new(&"hero", &"walk")
	if party_size() > 1:
		_dress(_hero, 0)
	_stage.add_child(_hero)
	_companion = UiActor.new(&"companion", &"walk")
	_companion.face(-1)
	_stage.add_child(_companion)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 4)
	safe.add_child(column)
	column.add_child(UiKit.label("UI_TALLY_HEADING", UiKit.Style.TITLE, HORIZONTAL_ALIGNMENT_CENTER))
	var score_row: HBoxContainer = HBoxContainer.new()
	score_row.alignment = BoxContainer.ALIGNMENT_CENTER
	score_row.add_theme_constant_override(&"separation", 12)
	score_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(score_row)
	var caption: Label = UiKit.label("UI_TALLY_SCORE", UiKit.Style.HUD)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	score_row.add_child(caption)
	_score_label = UiKit.label(UiKit.score_text(Game.score), UiKit.Style.DIGITS)
	_score_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	score_row.add_child(_score_label)
	var percent: int = int(Flow.args.get("percent", Game.completion_percent()))
	var completed: Label = UiKit.label(tr("UI_TALLY_COMPLETED").format({"percent": percent}), UiKit.Style.HUD,
			HORIZONTAL_ALIGNMENT_CENTER)
	completed.add_theme_color_override(&"font_color", UiKit.COL_FOCUS if percent >= 100 else UiKit.COL_CREAM)
	column.add_child(completed)
	_bonus_label = UiKit.label("", UiKit.Style.HUD, HORIZONTAL_ALIGNMENT_CENTER)
	_bonus_label.add_theme_color_override(&"font_color", UiKit.COL_GOOD)
	column.add_child(_bonus_label)
	if party_size() > 1:
		_build_medal_board(column)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	var prompts: UiPrompts = UiPrompts.new()
	prompts.alignment = BoxContainer.ALIGNMENT_END
	prompts.add_hint(&"ui_accept", "UI_HINT_SKIP", _on_accept)
	column.add_child(prompts)
	for child: Node in column.get_children():
		if child is Control:
			(child as Control).modulate.a = 0.0


func _screen_ready() -> void:
	Audio.play_jingle(Sfx.MUSIC_LEVEL_COMPLETE, Sfx.MUSIC_TALLY)
	Game.score_changed.connect(_on_score_changed)
	_hero.position = Vector2(-60.0, _floor_y())
	for i: int in _partners.size():
		_partners[i].position = Vector2(-60.0 - PARTNER_GAP * float(i + 1), _floor_y())
	_companion.position = Vector2(size.x + 70.0, _floor_y())
	if _board != null:
		resized.connect(_size_board)
		_size_board()
	var column: Node = safe.get_child(0)
	var reveal: Tween = create_tween()
	for child: Node in column.get_children():
		if child is Control:
			reveal.tween_property(child, "modulate:a", 1.0, 0.15)


func _process(delta: float) -> void:
	_phase_time += delta
	if _catch_time > 0.0:
		_catch_time -= delta
		if _catch_time <= 0.0:
			_companion.play(&"idle")
	match phase:
		Phase.INTRO:
			if _phase_time >= INTRO_SECONDS:
				_set_phase(Phase.ENTER)
		Phase.ENTER:
			var t: float = clampf(_phase_time / ENTER_SECONDS, 0.0, 1.0)
			var eased: float = 1.0 - (1.0 - t) * (1.0 - t)
			_hero.position = Vector2(roundf(lerpf(-60.0, size.x * HERO_STOP, eased)), _floor_y())
			for i: int in _partners.size():
				var stop: float = size.x * HERO_STOP - PARTNER_GAP * float(i + 1)
				_partners[i].position = Vector2(roundf(lerpf(-60.0 - PARTNER_GAP * float(i + 1), stop, eased)), _floor_y())
			_companion.position = Vector2(roundf(lerpf(size.x + 70.0, size.x * COMPANION_STOP, eased)), _floor_y())
			if t >= 1.0:
				_play_heroes(&"skid" if not _ids.is_empty() else &"victory")
				_companion.play(&"idle")
				if not _ids.is_empty():
					_set_phase(Phase.DROPS)
				else:
					_set_phase(Phase.MEDALS if not _medals.is_empty() else Phase.SETTLE)
		Phase.DROPS:
			_keep_actors_at_stops()
			if _phase_time > 0.35 and _hero.animation == &"skid":
				_play_heroes(&"idle")
			_drop_timer -= delta
			if _launched < _ids.size() and _drop_timer <= 0.0:
				_drop_timer += Tuning.ticks_to_seconds(Tuning.TALLY_ITEM_PERIOD)
				_launch(_launched)
				_launched += 1
			if paid >= _ids.size():
				_set_phase(Phase.MEDALS if not _medals.is_empty() else Phase.SETTLE)
		Phase.MEDALS:
			_keep_actors_at_stops()
			if _hero.animation == &"skid":
				_play_heroes(&"idle")
			_drop_timer -= delta
			if medals_shown < _medals.size() and _drop_timer <= 0.0:
				_drop_timer += MEDAL_SECONDS
				_hand_out(medals_shown, true)
			elif medals_shown >= _medals.size() and _drop_timer <= 0.0:
				_set_phase(Phase.SETTLE)
		Phase.SETTLE:
			_keep_actors_at_stops()
			if _phase_time >= SETTLE_SECONDS:
				_set_phase(Phase.EXIT)
		Phase.EXIT:
			var t: float = clampf(_phase_time / EXIT_SECONDS, 0.0, 1.0)
			var eased: float = t * t
			_hero.position = Vector2(roundf(lerpf(size.x * HERO_STOP, size.x + 80.0, eased)), _floor_y())
			for i: int in _partners.size():
				var stop: float = size.x * HERO_STOP - PARTNER_GAP * float(i + 1)
				_partners[i].position = Vector2(roundf(lerpf(stop, size.x + 80.0, eased)), _floor_y())
			_companion.position = Vector2(roundf(lerpf(size.x * COMPANION_STOP, -80.0, eased)), _floor_y())
			_follow_head_medals()
			if t >= 1.0:
				finish()


func _on_accept() -> void:
	skip()


## Skip ahead: pay everything that is still pending, hand out every medal and go to the end of the sequence; when
## already there, leave the tally.
func skip() -> void:
	if not is_accepting_input():
		return
	if phase < Phase.SETTLE:
		_pay_rest()
		for medal: int in range(medals_shown, _medals.size()):
			_hand_out(medal, false)
		_keep_actors_at_stops()
		_play_heroes(&"victory")
		_companion.play(&"idle")
		_set_phase(Phase.SETTLE)
		_phase_time = SETTLE_SECONDS * 0.5
	else:
		finish()


## Pay what is left and hand over to Flow (records the result, world map / next level).
func finish() -> void:
	if phase == Phase.DONE or not begin_leave():
		return
	_pay_rest()
	phase = Phase.DONE
	Flow.finish_tally()


## Number of items this tally pays again.
func get_item_count() -> int:
	return _ids.size()


## Feet points of the hero and the companion on the screen, in this order (co-op: then the partners).
func get_actor_feet() -> PackedVector2Array:
	var feet: PackedVector2Array = PackedVector2Array([_hero.position, _companion.position])
	for partner: UiActor in _partners:
		feet.append(partner.position)
	return feet


## Y of the ground the actors walk on.
func get_ground_y() -> float:
	return _floor_y()


## Co-op: the medals of this stage in hand-out order, [medal id, winner slot] (a shared medal once per winner).
func get_medals() -> Array[Array]:
	return _medals


## Co-op: the medal ids the board shows for player `slot` so far.
func get_board_texts(slot: int) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var box: VBoxContainer = _board_columns.get(0) as VBoxContainer
	if box == null:
		return result
	for row: Node in box.get_children():
		if not (row is HBoxContainer and row.has_meta(&"medal") and (row as Control).modulate.a > 0.5):
			continue
		var tag: Control = _row_tag(row, slot)
		if tag != null and tag.visible:
			result.append(str(row.get_meta(&"medal")))
	return result


## The winner tag of player `slot` on a board row (null when he did not win that medal).
func _row_tag(row: Node, slot: int) -> Control:
	for child: Node in row.get_children():
		if child is Label and child.has_meta(&"slot") and int(child.get_meta(&"slot")) == slot:
			return child as Control
	return null


## Heroes at the tally: the party of a co-op run, else one.
static func party_size() -> int:
	return clampi(Game.party, 1, Defs.MAX_PLAYERS) if Game.mode == Defs.GameMode.COOP else 1


## The cell of a medal in ui/medals.png (32 x 32 cells): 0-5 the co-op medals in PlayerRun.COOP_MEDALS order, 6-18
## the versus awards in PlayerRun.VERSUS_AWARDS order ("slugger" is in both: `versus` tells which); -1 when unknown.
static func medal_cell(medal: StringName, versus: bool) -> int:
	var table: Array[Dictionary] = PlayerRun.VERSUS_AWARDS if versus else PlayerRun.COOP_MEDALS
	for i: int in table.size():
		if table[i]["id"] == medal:
			return i + (PlayerRun.COOP_MEDALS.size() if versus else 0)
	return -1


## Draw a medal at `centre` (radius `radius`) on `canvas`: two ribbon tails in `ribbon` above the disc of `medal` from
## `sheet` (ui/medals.png, held by the caller; a plain gold disc without it or for an unknown medal).
static func draw_medal(canvas: CanvasItem, centre: Vector2, radius: float, medal: StringName, ribbon: Color,
		versus: bool = false, sheet: Texture2D = null) -> void:
	var r: float = roundf(radius)
	var top: Vector2 = centre - Vector2(0.0, r + 5.0)
	canvas.draw_colored_polygon(PackedVector2Array([top + Vector2(-r * 0.75, 0.0), top + Vector2(-1.0, 0.0),
			centre + Vector2(-1.0, -r * 0.5), centre + Vector2(-r * 0.55, -r * 0.5)]), ribbon.darkened(0.2))
	canvas.draw_colored_polygon(PackedVector2Array([top + Vector2(1.0, 0.0), top + Vector2(r * 0.75, 0.0),
			centre + Vector2(r * 0.55, -r * 0.5), centre + Vector2(1.0, -r * 0.5)]), ribbon)
	canvas.draw_rect(Rect2(top + Vector2(-r * 0.75, -1.0), Vector2(r * 1.5, 1.0)), UiKit.COL_INK)
	var cell: int = medal_cell(medal, versus)
	if sheet != null and cell >= 0:
		canvas.draw_texture_rect_region(sheet, Rect2(centre - Vector2(r, r), Vector2(r, r) * 2.0),
				Rect2(float(cell) * MEDAL_CELL, 0.0, MEDAL_CELL, MEDAL_CELL))
		return
	canvas.draw_circle(centre, r, UiKit.COL_INK)
	canvas.draw_circle(centre, r - 1.0, Color("e8a930"))
	canvas.draw_circle(centre + Vector2(-1.0, -1.0), r - 3.0, Color("ffd75e"))


func _set_phase(next: int) -> void:
	phase = next
	_phase_time = 0.0
	match next:
		Phase.DROPS:
			_drop_timer = 0.0
		Phase.MEDALS:
			_drop_timer = 0.25
		Phase.SETTLE:
			Audio.play_sfx(Sfx.TALLY_END)
		Phase.EXIT:
			_play_heroes(&"run")
			_hero.face(1)
			for partner: UiActor in _partners:
				partner.face(1)
			_companion.play(&"walk")
			_companion.face(-1)


func _launch(item: int) -> void:
	var picture: TextureRect = UiKit.picture(item_texture(_ids[item], _indices[item]))
	var picture_size: Vector2 = picture.texture.get_size() if picture.texture != null else Vector2(32.0, 32.0)
	var x: float = roundf(_catch_x(item) - picture_size.x * 0.5)
	var land_y: float = _floor_y() - CATCH_HEIGHT - picture_size.y
	picture.position = Vector2(x, -picture_size.y)
	_stage.add_child(picture)
	_falling.append(picture)
	var fall: Tween = picture.create_tween()
	fall.tween_property(picture, "position:y", land_y, FALL_SECONDS).set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_IN)
	fall.tween_callback(_land.bind(item, picture))


## Where item `item` falls: onto the companion, or - when the game knows who picked it - a little to that hero's side
## of him (each hero's own pile, DESIGN.md D.11).
func _catch_x(item: int) -> float:
	var x: float = _companion.position.x
	if party_size() > 1 and item < _pickers.size():
		x += -14.0 if _pickers[item] == 0 else 14.0
	return x


func _land(item: int, picture: TextureRect) -> void:
	_falling.erase(picture)
	picture.queue_free()
	if item != paid:
		return
	_pay(item)
	Audio.play_sfx(Sfx.TALLY_TICK)
	_companion.play(&"catch", false)
	_catch_time = 0.3
	if _points[item] > 0:
		_popup("+%d" % _points[item])


func _pay(item: int) -> void:
	Game.add_score(_points[item])
	_bonus_total += _points[item]
	paid = item + 1
	_bonus_label.text = tr("UI_TALLY_BONUS").format({"points": _bonus_total})
	# Co-op: the item counts again for the hero who picked it (his share of the tribe score, the Rival score line).
	if party_size() > 1 and item < _pickers.size() and _points[item] > 0:
		var run: PlayerRun = Game.get_run(_pickers[item])
		if run != null:
			run.score += _points[item]
			var own: Label = _rival_labels.get(_pickers[item]) as Label
			if own != null:
				own.text = UiKit.score_text(run.score)


func _pay_rest() -> void:
	for picture: Node in _falling:
		picture.queue_free()
	_falling.clear()
	for item: int in range(paid, _ids.size()):
		_pay(item)
	_launched = _ids.size()


func _popup(text: String) -> void:
	var label: Label = UiKit.label(text, UiKit.Style.HUD)
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.add_theme_color_override(&"font_color", UiKit.COL_FOCUS)
	_stage.add_child(label)
	var start: Vector2 = Vector2(roundf(_companion.position.x + 18.0), _floor_y() - 110.0)
	label.position = start
	var rise: Tween = label.create_tween().set_parallel(true)
	rise.tween_property(label, "position:y", start.y - 24.0, 0.45)
	rise.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.15)
	rise.chain().tween_callback(label.queue_free)


## While they stand, the heroes and the companion stay on the ground at their marks, also when the view changes size
## (a resized window, a rotated tablet).
func _keep_actors_at_stops() -> void:
	_hero.position = Vector2(roundf(size.x * HERO_STOP), _floor_y())
	for i: int in _partners.size():
		_partners[i].position = Vector2(roundf(size.x * HERO_STOP - PARTNER_GAP * float(i + 1)), _floor_y())
	_companion.position = Vector2(roundf(size.x * COMPANION_STOP), _floor_y())
	_follow_head_medals()


func _floor_y() -> float:
	return _ground.get_surface_y() if _ground.is_inside_tree() else size.y - 54.0


func _on_score_changed(score: int) -> void:
	_score_label.text = UiKit.score_text(score)


## Every hero plays `anim`.
func _play_heroes(anim: StringName) -> void:
	_hero.play(anim)
	for partner: UiActor in _partners:
		partner.play(anim)


## The actor of player `slot`.
func _actor_of(slot: int) -> UiActor:
	if slot <= 0:
		return _hero
	return _partners[slot - 1] if slot - 1 < _partners.size() else _hero


## The hero of player `slot` in his colour (HeroPalette).
func _dress(actor: UiActor, slot: int) -> void:
	var look: Array = HeroPalette.resolve(slot, Game.get_run(slot))
	actor.material = HeroPalette.material_for(look[0], int(look[1]))


## The text colour of player `slot` (his chosen palette, lifted for the dark cloths).
static func slot_colour(slot: int) -> Color:
	return JoinScreen.text_colour(HeroPalette.resolve(slot, Game.get_run(slot))[0])


## The medal board on the right of the stage, under the score lines (the heroes stand on the left, the companion in
## the middle): with the "Rival score" option first every hero's own points, then one line per medal as it is handed
## out - the medal in its winner's ribbon, his tag in his colour, the medal's name and what it was for. The medals
## come from the party's statistics of this stage.
func _build_medal_board(column: VBoxContainer) -> void:
	var won: Dictionary = PlayerRun.medals(Game.party_runs())
	for award: Dictionary in PlayerRun.COOP_MEDALS:
		var id: StringName = award["id"]
		if won.has(id):
			for slot: int in (won[id] as PackedInt32Array):
				_medals.append([id, slot])
	var row_holder: HBoxContainer = HBoxContainer.new()
	row_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gap: Control = Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_holder.add_child(gap)
	var board: VBoxContainer = VBoxContainer.new()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_theme_constant_override(&"separation", 0)
	board.custom_minimum_size = Vector2(BOARD_MIN_WIDTH, 0.0)
	row_holder.add_child(board)
	if Settings.get_bool(OptionsPanel.KEY_RIVAL_SCORE):
		var scores: HBoxContainer = HBoxContainer.new()
		scores.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scores.add_theme_constant_override(&"separation", 6)
		for slot: int in party_size():
			var tag: Label = UiKit.label(UiPlayers.tag(slot), UiKit.Style.SMALL)
			tag.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			tag.add_theme_color_override(&"font_color", slot_colour(slot))
			scores.add_child(tag)
			var own: Label = UiKit.label(UiKit.score_text(Game.get_run(slot).score), UiKit.Style.MONO)
			own.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			own.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			scores.add_child(own)
			_rival_labels[slot] = own
		board.add_child(scores)
	# One row per medal: its disc in the (first) winner's ribbon, every winner's tag (a shared medal lists both; a tag
	# shows once his medal was handed out), the medal's name and, where it fits, what it was for.
	var winners_of: Dictionary = {}
	for entry: Array in _medals:
		var list: PackedInt32Array = winners_of.get(entry[0], PackedInt32Array())
		list.append(int(entry[1]))
		winners_of[entry[0]] = list
	for medal: Variant in winners_of:
		var winners: PackedInt32Array = winners_of[medal]
		var row: HBoxContainer = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override(&"separation", 4)
		row.set_meta(&"medal", medal)
		row.modulate.a = 0.0
		var icon: MedalIcon = MedalIcon.new(medal, slot_colour(winners[0]), 16.0)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		for slot: int in winners:
			var tag: Label = UiKit.label(UiPlayers.tag(slot), UiKit.Style.SMALL)
			tag.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			tag.add_theme_color_override(&"font_color", slot_colour(slot))
			tag.set_meta(&"slot", slot)
			tag.visible = false
			row.add_child(tag)
		var keys: Array = MEDAL_KEYS.get(medal, [String(medal), ""])
		var name: Label = UiKit.label(str(keys[0]), UiKit.Style.SMALL)
		name.add_theme_color_override(&"font_color", UiKit.COL_FOCUS)
		row.add_child(name)
		var info: Label = UiKit.label(str(keys[1]), UiKit.Style.SMALL)
		info.add_theme_color_override(&"font_color", UiKit.COL_DIM)
		info.clip_text = true
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.set_meta(&"info", true)
		row.add_child(info)
		board.add_child(row)
	_board_columns[0] = board
	_board = board
	board.resized.connect(_fit_board_infos.bind(board))
	column.add_child(row_holder)


## The board takes about a third of the view on the right (at least BOARD_MIN_WIDTH), clear of the companion.
func _size_board() -> void:
	_board.custom_minimum_size.x = maxf(BOARD_MIN_WIDTH, roundf(size.x * BOARD_SHARE))


## A medal's reason ("Longest head-bounce chain") shows only where it fits whole on the board (a narrow view keeps the
## names alone rather than cut words).
func _fit_board_infos(board: VBoxContainer) -> void:
	var font: Font = UiKit.font(UiKit.Style.SMALL)
	for row: Node in board.get_children():
		if not row is HBoxContainer:
			continue
		for child: Node in row.get_children():
			if child is Label and child.has_meta(&"info"):
				var info: Label = child as Label
				var used: float = 0.0
				for other: Node in row.get_children():
					if other != info and other is Control:
						used += (other as Control).get_combined_minimum_size().x + 4.0
				var need: float = font.get_string_size(info.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_SMALL).x
				info.visible = used + need <= board.size.x


## Hand out medal `index` of the list: its board row shows with the winner's tag, a medal flies from the companion to the
## winner's head (`animate`) or appears there at once.
func _hand_out(index: int, animate: bool) -> void:
	if index < medals_shown or index >= _medals.size():
		return
	medals_shown = index + 1
	var entry: Array = _medals[index]
	var slot: int = int(entry[1])
	var box: VBoxContainer = _board_columns.get(0) as VBoxContainer
	if box != null:
		for row: Node in box.get_children():
			if not (row is HBoxContainer and row.has_meta(&"medal") and row.get_meta(&"medal") == entry[0]):
				continue
			var tag: Control = _row_tag(row, slot)
			if tag != null:
				tag.visible = true
			if (row as Control).modulate.a < 0.5:
				if animate:
					(row as Control).create_tween().tween_property(row, "modulate:a", 1.0, 0.2)
				else:
					(row as Control).modulate.a = 1.0
			break
	var icon: MedalIcon = MedalIcon.new(entry[0], slot_colour(slot), 16.0)
	_stage.add_child(icon)
	var stack: Array = _head_medals.get(slot, [])
	stack.append(icon)
	_head_medals[slot] = stack
	var target: Vector2 = _head_medal_place(slot, stack.size() - 1)
	var actor: UiActor = _actor_of(slot)
	actor.play(&"victory")
	if animate:
		icon.position = _companion.position + Vector2(-8.0, -70.0)
		icon.set_meta(&"flying", true)
		var arc: Tween = icon.create_tween()
		arc.tween_property(icon, "position", target, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		arc.tween_callback(icon.remove_meta.bind(&"flying"))
		_companion.play(&"catch", false)
		_catch_time = 0.3
		Audio.play_sfx(Sfx.MENU_SELECT)
	else:
		icon.position = target


## Where the `n`-th medal of player `slot` hangs over his head: side by side, centred on him, overlapping a little
## from the third one on (so a partner's medals never seem to hang over the wrong hero).
func _head_medal_place(slot: int, n: int) -> Vector2:
	var actor: UiActor = _actor_of(slot)
	var count: int = (_head_medals.get(slot, []) as Array).size()
	var step: float = 16.0 if count <= 2 else 11.0
	var x: float = actor.position.x - 8.0 - step * float(count - 1) * 0.5 + float(n) * step
	return Vector2(roundf(x), actor.position.y - 96.0)


func _follow_head_medals() -> void:
	for slot: Variant in _head_medals:
		var stack: Array = _head_medals[slot]
		for n: int in stack.size():
			var icon: Control = stack[n] as Control
			if icon != null and not icon.has_meta(&"flying"):
				icon.position = _head_medal_place(int(slot), n)


## Picture of a collected item for the tally (ASSET_MANIFEST.md 7).
static func item_texture(item_id: StringName, index: int) -> Texture2D:
	match item_id:
		&"items/food":
			return UiKit.cell(UiKit.TEX_FOOD, Vector2i(32, 32), clampi(index, 0, 47))
		&"items/treasure":
			return UiKit.cell("res://assets/sprites/items/treasure.png", Vector2i(32, 32), clampi(index, 0, 15))
		&"items/giant_bonus":
			return UiKit.cell("res://assets/sprites/items/giant_bonus.png", Vector2i(72, 72), clampi(index, 0, 6))
		&"items/letter":
			return UiKit.cell(UiKit.TEX_LETTERS, Vector2i(40, 40), clampi(index, 0, 4))
		&"items/heart":
			return UiKit.cell(UiKit.TEX_PICKUPS, Vector2i(48, 40), 0)
		&"items/one_up":
			return UiKit.cell(UiKit.TEX_PICKUPS, Vector2i(48, 40), 1)
		&"items/fire_starter":
			return UiKit.cell(UiKit.TEX_PICKUPS, Vector2i(48, 40), 5)
		&"items/feast_piece":
			return UiKit.cell(UiKit.TEX_PICKUPS, Vector2i(48, 40), 6 + clampi(index, 0, 2))
		&"items/trophy":
			return UiKit.cell(UiKit.TEX_PICKUPS, Vector2i(48, 40), 9)
		&"items/warp":
			return UiKit.cell(UiKit.TEX_PICKUPS, Vector2i(48, 40), 10)
		&"items/water_bucket":
			return UiKit.cell(UiKit.TEX_PICKUPS, Vector2i(48, 40), 11)
		&"items/jackpot":
			return UiKit.cell("res://assets/sprites/objects/chest.png", Vector2i(60, 36), 0)
		&"items/painting":
			# The pick-up's own picture (ASSET_MANIFEST.md 7: 6 pictures, column = index % 6, row 0).
			return UiKit.cell("res://assets/sprites/items/painting.png", Vector2i(32, 32), posmod(index, 6))
		_:
			return UiKit.icon(UiKit.ICON_FRUIT)

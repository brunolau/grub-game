class_name TallyScreen
extends UiScreen
## End-of-level tally (GAMEPLAY.md 3.7, 3.4): score and completion percentage, the hero walks in, the companion
## slides to the middle, and every bonus collected since the last death drops into the companion, one every
## Tuning.TALLY_ITEM_PERIOD ticks, paying its value again. Then both walk off and `Flow.finish_tally()` runs.
##
## Args: {"level_id": StringName, "percent": int}. The confirm button (or a tap) skips ahead: the remaining items
## are paid at once; a second press leaves. Every item is paid exactly once.

enum Phase { INTRO, ENTER, DROPS, SETTLE, EXIT, DONE }

const INTRO_SECONDS: float = 0.6
const ENTER_SECONDS: float = 1.5
const FALL_SECONDS: float = 0.45
const SETTLE_SECONDS: float = 0.9
const EXIT_SECONDS: float = 1.4
const HERO_STOP: float = 0.2        ## hero stops at this fraction of the width
const COMPANION_STOP: float = 0.56  ## companion stops here
const CATCH_HEIGHT: float = 52.0    ## items land this far above the companion's feet

## Current step of the sequence (Phase).
var phase: int = Phase.INTRO
## Items paid so far.
var paid: int = 0

var _ids: Array[StringName] = []
var _indices: PackedInt32Array = PackedInt32Array()
var _points: PackedInt32Array = PackedInt32Array()
var _launched: int = 0
var _phase_time: float = 0.0
var _drop_timer: float = 0.0
var _bonus_total: int = 0
var _stage: Control = null
var _ground: UiGround = null
var _hero: UiActor = null
var _companion: UiActor = null
var _score_label: Label = null
var _bonus_label: Label = null
var _falling: Array[Node] = []
var _catch_time: float = 0.0


func _build_screen() -> void:
	_ids = Game.tally_item_ids.duplicate()
	_indices = Game.tally_item_indices.duplicate()
	_points = Game.tally_item_points.duplicate()
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
	_hero = UiActor.new(&"hero", &"walk")
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
	_companion.position = Vector2(size.x + 70.0, _floor_y())
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
			_companion.position = Vector2(roundf(lerpf(size.x + 70.0, size.x * COMPANION_STOP, eased)), _floor_y())
			if t >= 1.0:
				_hero.play(&"skid" if not _ids.is_empty() else &"victory")
				_companion.play(&"idle")
				_set_phase(Phase.DROPS if not _ids.is_empty() else Phase.SETTLE)
		Phase.DROPS:
			_keep_actors_at_stops()
			if _phase_time > 0.35 and _hero.animation == &"skid":
				_hero.play(&"idle")
			_drop_timer -= delta
			if _launched < _ids.size() and _drop_timer <= 0.0:
				_drop_timer += Tuning.ticks_to_seconds(Tuning.TALLY_ITEM_PERIOD)
				_launch(_launched)
				_launched += 1
			if paid >= _ids.size():
				_set_phase(Phase.SETTLE)
		Phase.SETTLE:
			_keep_actors_at_stops()
			if _phase_time >= SETTLE_SECONDS:
				_set_phase(Phase.EXIT)
		Phase.EXIT:
			var t: float = clampf(_phase_time / EXIT_SECONDS, 0.0, 1.0)
			var eased: float = t * t
			_hero.position = Vector2(roundf(lerpf(size.x * HERO_STOP, size.x + 80.0, eased)), _floor_y())
			_companion.position = Vector2(roundf(lerpf(size.x * COMPANION_STOP, -80.0, eased)), _floor_y())
			if t >= 1.0:
				finish()


func _on_accept() -> void:
	skip()


## Skip ahead: pay everything that is still pending and go to the end of the sequence; when already there,
## leave the tally.
func skip() -> void:
	if not is_accepting_input():
		return
	if phase < Phase.SETTLE:
		_pay_rest()
		_hero.position = Vector2(roundf(size.x * HERO_STOP), _floor_y())
		_companion.position = Vector2(roundf(size.x * COMPANION_STOP), _floor_y())
		_hero.play(&"victory")
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


## Feet points of the hero and the companion on the screen, in this order.
func get_actor_feet() -> PackedVector2Array:
	return PackedVector2Array([_hero.position, _companion.position])


## Y of the ground the actors walk on.
func get_ground_y() -> float:
	return _floor_y()


func _set_phase(next: int) -> void:
	phase = next
	_phase_time = 0.0
	match next:
		Phase.DROPS:
			_drop_timer = 0.0
		Phase.SETTLE:
			Audio.play_sfx(Sfx.TALLY_END)
		Phase.EXIT:
			_hero.play(&"run")
			_hero.face(1)
			_companion.play(&"walk")
			_companion.face(-1)


func _launch(item: int) -> void:
	var picture: TextureRect = UiKit.picture(item_texture(_ids[item], _indices[item]))
	var picture_size: Vector2 = picture.texture.get_size() if picture.texture != null else Vector2(32.0, 32.0)
	var x: float = roundf(_companion.position.x - picture_size.x * 0.5)
	var land_y: float = _floor_y() - CATCH_HEIGHT - picture_size.y
	picture.position = Vector2(x, -picture_size.y)
	_stage.add_child(picture)
	_falling.append(picture)
	var fall: Tween = picture.create_tween()
	fall.tween_property(picture, "position:y", land_y, FALL_SECONDS).set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_IN)
	fall.tween_callback(_land.bind(item, picture))


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


## While they stand, the hero and the companion stay on the ground at their marks, also when the view changes size
## (a resized window, a rotated tablet).
func _keep_actors_at_stops() -> void:
	_hero.position = Vector2(roundf(size.x * HERO_STOP), _floor_y())
	_companion.position = Vector2(roundf(size.x * COMPANION_STOP), _floor_y())


func _floor_y() -> float:
	return _ground.get_surface_y() if _ground.is_inside_tree() else size.y - 54.0


func _on_score_changed(score: int) -> void:
	_score_label.text = UiKit.score_text(score)


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
		_:
			return UiKit.icon(UiKit.ICON_FRUIT)

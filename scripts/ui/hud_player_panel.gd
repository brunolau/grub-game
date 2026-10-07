class_name HudPlayerPanel
extends Control
## The energy panel of one co-op player on the HUD (DESIGN.md D.11, GAMEPLAY.md 13.9.9): his "P2" tag, his three
## hearts with the bone fraction under them and his belt icon (what a Swap brings, DESIGN.md C.1 rule 5: only while
## he owns a special). P1's hearts stay the 1.0 row of [Hud]; this panel is P2's, mirrored top-right: the tag on the
## outer side, the hearts filling from the outside in, the belt icon on the inner side.
##
## Owner: ui-B. Reads PlayerRun through `Game.run_energy_changed` / `run_belt_changed` (a run is never replaced, so the
## panel connects once) and greys out while the player's hero is an egg (`Events.hero_down` / `hero_revived`).

const HEART_SPACING: float = 34.0
const HEART_SIZE: float = 32.0
const TAG_W: float = 30.0
const BELT_GAP: float = 6.0
const BONE_W: float = 9.0
const BONE_Y: float = 37.0
## Width and height of the panel (art px).
const PANEL_W: float = TAG_W + HEART_SPACING * 2.0 + HEART_SIZE + BELT_GAP + 32.0
const PANEL_H: float = 44.0
## Look of the panel while its hero is an egg.
const DOWN_TINT: Color = Color(0.55, 0.55, 0.6, 0.85)

## Player slot shown (1 = P2).
var slot: int = 1
## True: tag on the right, belt icon on the left (the top-right panel).
var mirrored: bool = true
## Hearts drawn (PlayerRun.hearts).
var shown_hearts: int = 0
## Bone fraction drawn (PlayerRun.bones).
var shown_bones: int = 0
## Belt icon drawn: a Defs.Weapon, or PlayerRun.BELT_EMPTY (hidden).
var shown_belt: int = PlayerRun.BELT_EMPTY
## True while the player's hero is an egg.
var hero_down: bool = false

var _hearts: Array[TextureRect] = []
var _bones: Control = null
var _belt: TextureRect = null
var _tag: Label = null
var _heart_full: AtlasTexture = null
var _heart_empty: AtlasTexture = null


func _init(p_slot: int = 1, p_mirrored: bool = true) -> void:
	slot = p_slot
	mirrored = p_mirrored
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	size = custom_minimum_size
	_heart_full = UiKit.cell("res://assets/ui/hud_heart.png", Vector2i(32, 32), 0)
	_heart_empty = UiKit.cell("res://assets/ui/hud_heart.png", Vector2i(32, 32), 1)
	_build()


func _ready() -> void:
	Game.run_energy_changed.connect(_on_run_energy_changed)
	Game.run_belt_changed.connect(_on_run_belt_changed)
	Game.run_started.connect(_on_run_started)
	Events.hero_down.connect(_on_hero_down)
	Events.hero_revived.connect(_on_hero_revived)
	refresh()


## Show the run as it is now.
func refresh() -> void:
	var run: PlayerRun = Game.get_run(slot) if slot >= 0 and slot < Defs.MAX_PLAYERS else null
	if run == null:
		return
	_set_energy(run.hearts, run.bones, false)
	_set_belt(run.belt)


## True while the belt icon shows.
func is_belt_visible() -> bool:
	return _belt.visible


## The tag label ("P2").
func get_tag() -> Label:
	return _tag


func _build() -> void:
	var hearts_x: float = BELT_GAP + 32.0 if mirrored else TAG_W
	_tag = UiPlayers.tag_label(slot)
	_tag.position = Vector2(PANEL_W - TAG_W + 4.0 if mirrored else 0.0, 7.0)
	add_child(_tag)
	for i: int in Tuning.ENERGY_START:
		var heart: TextureRect = UiKit.picture(_heart_full)
		# Mirrored: the first heart sits outermost, so the row empties from the inside out like P1's from the right.
		var column: int = Tuning.ENERGY_START - 1 - i if mirrored else i
		heart.position = Vector2(hearts_x + float(column) * HEART_SPACING, 2.0)
		heart.pivot_offset = Vector2(16.0, 16.0)
		add_child(heart)
		_hearts.append(heart)
	_bones = Control.new()
	_bones.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bones_width: float = BONE_W * float(Tuning.BONES_PER_HEART - 2) + 6.0
	var hearts_w: float = HEART_SPACING * float(Tuning.ENERGY_START - 1) + HEART_SIZE
	_bones.position = Vector2(roundf(hearts_x + (hearts_w - bones_width) * 0.5), BONE_Y)
	_bones.draw.connect(_draw_bones)
	add_child(_bones)
	_belt = UiKit.picture(null)
	_belt.position = Vector2(0.0 if mirrored else hearts_x + hearts_w + BELT_GAP, 2.0)
	_belt.visible = false
	add_child(_belt)


func _set_energy(hearts: int, bones: int, animate: bool) -> void:
	var before: int = shown_hearts
	shown_hearts = clampi(hearts, 0, _hearts.size())
	shown_bones = clampi(bones, 0, Tuning.BONES_PER_HEART - 1)
	for i: int in _hearts.size():
		_hearts[i].texture = _heart_full if i < shown_hearts else _heart_empty
	if animate and shown_hearts > before and shown_hearts > 0:
		_pop(_hearts[shown_hearts - 1])
	_bones.queue_redraw()


func _set_belt(belt: int) -> void:
	shown_belt = belt if belt >= 0 else PlayerRun.BELT_EMPTY
	_belt.visible = shown_belt != PlayerRun.BELT_EMPTY
	if _belt.visible:
		_belt.texture = UiPlayers.belt_icon(shown_belt)


func _draw_bones() -> void:
	if shown_bones <= 0:
		return
	for i: int in Tuning.BONES_PER_HEART - 1:
		var x: float = float(i) * BONE_W
		var color: Color = UiKit.COL_CREAM if i < shown_bones else Color(UiKit.COL_INK, 0.6)
		_bones.draw_rect(Rect2(x - 1.0, -1.0, 8.0, 6.0), UiKit.COL_INK)
		_bones.draw_rect(Rect2(x, 0.0, 6.0, 4.0), color)


func _pop(target: Control) -> void:
	var tween: Tween = target.create_tween()
	tween.tween_property(target, "scale", Vector2(1.3, 1.3), 0.08)
	tween.tween_property(target, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_down(down: bool) -> void:
	hero_down = down
	modulate = DOWN_TINT if down else Color.WHITE


func _on_run_energy_changed(p_slot: int, hearts: int, bones: int) -> void:
	if p_slot == slot:
		_set_energy(hearts, bones, true)


func _on_run_belt_changed(p_slot: int, belt: int) -> void:
	if p_slot == slot:
		_set_belt(belt)


func _on_run_started(_difficulty: int) -> void:
	_set_down(false)
	refresh()


func _on_hero_down(hero: PlayerBase, _cause: StringName) -> void:
	if hero != null and hero.slot == slot:
		_set_down(true)


func _on_hero_revived(hero: PlayerBase, _by: PlayerBase) -> void:
	if hero != null and hero.slot == slot:
		_set_down(false)

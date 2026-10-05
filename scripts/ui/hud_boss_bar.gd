class_name HudBossBar
extends Control
## Boss energy bar of the HUD: a bone-framed bar (`ui/bar_frame_bone.png`, `bar_back.png`, `bar_fill.png`,
## ASSET_MANIFEST 12) with the skull icon, that spans the boss's own hit points whatever their number. The fill is
## ceil(window * hp / max_hp) px wide, so any hit point left shows. A hit lights the lost part in cream (it drains
## after a short hold), flashes the fill and shakes the bar, so every hit reads at once, also a 1-point hit of a
## boss with hundreds of hit points; quarter notches tell how much is left at a glance and the fill pulses in its
## last quarter. On defeat the bar drains and fades out.
##
## Owner: ui. Driven by Hud ([method start], [method set_energy], [method finish], [method clear]); it never reads
## the boss itself. The node's rect is the frame (152 x 37 art px); the skull hangs off its left edge.

const TEX_FRAME: String = "res://assets/ui/bar_frame_bone.png"
const TEX_BACK: String = "res://assets/ui/bar_back.png"
const TEX_FILL: String = "res://assets/ui/bar_fill.png"
## Size of the frame picture and the transparent window inside it that the energy fills (measured from the picture).
const FRAME_SIZE: Vector2 = Vector2(152.0, 37.0)
const WINDOW: Rect2 = Rect2(12.0, 10.0, 128.0, 18.0)
## Rows of the window drawn as "energy" (the fill picture's own top and bottom border rows are left out).
const INNER_TOP: float = 2.0
const INNER_BOTTOM: float = 1.0
## Left and right caps of the nine-patch fill picture.
const FILL_CAP: int = 3
## Skull of ui/icons.png and where it hangs (relative to the frame's top-left corner).
const SKULL_ICON: int = 10
const SKULL_POS: Vector2 = Vector2(-30.0, 2.0)
## Quarter notches.
const NOTCHES: int = 4
const COL_NOTCH: Color = Color(0.153, 0.125, 0.094, 0.55)
## The lost part of a hit stays lit this long, then drains at TRAIL_SPEED px per second.
const TRAIL_HOLD: float = 0.4
const TRAIL_SPEED: float = 90.0
const COL_TRAIL: Color = Color("fff1cf")
const FLASH_SECONDS: float = 0.14
const SHAKE_SECONDS: float = 0.24
const SHAKE_PX: float = 3.0
## Last quarter: the fill pulses.
const LOW_RATIO: float = 0.25
## Defeat: the empty bar stays a moment, then fades out.
const FINISH_HOLD: float = 0.6
const FINISH_FADE: float = 0.5

## Hit points and maximum shown (max_hp 0 = no bar).
var hp: int = 0
var max_hp: int = 0
## True while a fight is shown (false while the bar fades out after a defeat and when it is hidden).
var active: bool = false

var _trail_px: float = 0.0
var _trail_hold: float = 0.0
var _flash: float = 0.0
var _shake: float = 0.0
var _time: float = 0.0
var _fade: Tween = null
var _frame: Texture2D = null
var _back: Texture2D = null
var _fill: Texture2D = null
var _fill_box: StyleBoxTexture = null
var _skull: AtlasTexture = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = FRAME_SIZE
	size = FRAME_SIZE
	visible = false
	_frame = UiKit.tex(TEX_FRAME)
	_back = UiKit.tex(TEX_BACK)
	_fill = UiKit.tex(TEX_FILL)
	_skull = UiKit.icon(SKULL_ICON)
	if _fill != null:
		_fill_box = StyleBoxTexture.new()
		_fill_box.texture = _fill
		_fill_box.texture_margin_left = float(FILL_CAP)
		_fill_box.texture_margin_right = float(FILL_CAP)
	set_process(false)


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - delta, 0.0)
	_shake = maxf(_shake - delta, 0.0)
	var fill: float = float(fill_width(hp, max_hp))
	if _trail_hold > 0.0:
		_trail_hold -= delta
	else:
		_trail_px = move_toward(_trail_px, fill, TRAIL_SPEED * delta)
	queue_redraw()
	if _flash <= 0.0 and _shake <= 0.0 and _trail_px <= fill and not _is_low() and _fade == null:
		set_process(false)


## Width of the fill in art px for `p_hp` of `p_max` hit points: ceil(window * hp / max), so that any hit point
## left shows; 0 without hit points.
static func fill_width(p_hp: int, p_max: int) -> int:
	if p_hp <= 0 or p_max <= 0:
		return 0
	var full: int = int(WINDOW.size.x)
	return clampi(ceili(float(full) * float(p_hp) / float(p_max)), 1, full)


## Width of the fill shown now (art px).
func get_fill_width() -> int:
	return fill_width(hp, max_hp)


## Right end of the lit "lost energy" part (art px from the window's left edge); equals the fill when no hit is
## being shown.
func get_trail_width() -> float:
	return maxf(_trail_px, float(get_fill_width()))


## True while a hit is being shown (lit lost part, flash or shake).
func is_showing_hit() -> bool:
	return _flash > 0.0 or _shake > 0.0 or _trail_px > float(get_fill_width())


## A fight starts: show the bar with `p_hp` of `p_max` hit points (no hit effect).
func start(p_hp: int, p_max: int) -> void:
	_stop_fade()
	active = true
	max_hp = maxi(p_max, 1)
	hp = clampi(p_hp, 0, max_hp)
	_trail_px = float(get_fill_width())
	_trail_hold = 0.0
	_flash = 0.0
	_shake = 0.0
	modulate.a = 1.0
	visible = true
	set_process(true)
	queue_redraw()


## New energy. Less than before is a hit: the lost part lights up, the fill flashes and the bar shakes.
func set_energy(p_hp: int, p_max: int) -> void:
	if not active or p_max != max_hp:
		# A bar that was not shown (or another boss) starts with this energy.
		start(p_hp, p_max)
		return
	var new_hp: int = clampi(p_hp, 0, max_hp)
	if new_hp < hp:
		_trail_px = maxf(_trail_px, float(get_fill_width()))
		_trail_hold = TRAIL_HOLD
		_flash = FLASH_SECONDS
		_shake = SHAKE_SECONDS
	hp = new_hp
	if float(get_fill_width()) > _trail_px:
		_trail_px = float(get_fill_width())
	set_process(true)
	queue_redraw()


## The boss is defeated: the bar shows its last hit, then fades out.
func finish() -> void:
	if not active:
		if _fade == null:
			clear()
		return
	set_energy(0, max_hp)
	active = false
	_stop_fade()
	_fade = create_tween()
	_fade.tween_interval(FINISH_HOLD)
	_fade.tween_property(self, "modulate:a", 0.0, FINISH_FADE)
	_fade.tween_callback(_on_faded)


## Hide at once (respawn, new level).
func clear() -> void:
	_stop_fade()
	active = false
	visible = false
	hp = 0
	max_hp = 0
	_trail_px = 0.0
	_trail_hold = 0.0
	_flash = 0.0
	_shake = 0.0
	modulate.a = 1.0
	set_process(false)


func _on_faded() -> void:
	_fade = null
	clear()


func _stop_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null


func _is_low() -> bool:
	return hp > 0 and max_hp > 0 and float(hp) <= float(max_hp) * LOW_RATIO


func _draw() -> void:
	var offset: float = 0.0
	if _shake > 0.0:
		offset = roundf(sin(_shake * 70.0) * SHAKE_PX * _shake / SHAKE_SECONDS)
	draw_set_transform(Vector2(offset, 0.0))
	if _skull != null:
		draw_texture(_skull, SKULL_POS)
	if _back != null:
		draw_texture(_back, WINDOW.position)
	else:
		draw_rect(WINDOW, UiKit.COL_INK)
	var fill: float = float(get_fill_width())
	var inner_y: float = WINDOW.position.y + INNER_TOP
	var inner_h: float = WINDOW.size.y - INNER_TOP - INNER_BOTTOM
	var trail: float = minf(_trail_px, WINDOW.size.x)
	if trail > fill:
		draw_rect(Rect2(WINDOW.position.x + fill, inner_y, trail - fill, inner_h), COL_TRAIL)
	if fill > 0.0:
		var fill_rect: Rect2 = Rect2(WINDOW.position, Vector2(fill, WINDOW.size.y))
		if _fill_box != null and fill >= float(2 * FILL_CAP):
			draw_style_box(_fill_box, fill_rect)
		elif _fill != null:
			draw_texture_rect_region(_fill, fill_rect, Rect2(Vector2.ZERO, fill_rect.size))
		else:
			draw_rect(fill_rect, UiKit.COL_BAD)
		var glow: float = 0.0
		if _flash > 0.0:
			glow = 0.75 * _flash / FLASH_SECONDS
		elif _is_low():
			glow = 0.22 * (0.5 + 0.5 * sin(_time * 9.0))
		if glow > 0.0:
			draw_rect(Rect2(WINDOW.position.x, inner_y, fill, inner_h), Color(1.0, 1.0, 1.0, glow))
	for i: int in range(1, NOTCHES):
		var x: float = WINDOW.position.x + roundf(WINDOW.size.x * float(i) / float(NOTCHES))
		draw_rect(Rect2(x, inner_y, 1.0, inner_h), COL_NOTCH)
	if _frame != null:
		draw_texture(_frame, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO)

class_name Dangler
extends HangerEnemy
## `enemies/dangler` - archetype 2, yo-yo dangler (GAMEPLAY.md 5.2): hangs on a thread from the ceiling above its
## anchor, lowers itself `depth` px at `speed` px per tick, climbs back to the anchor and repeats.
## 2.0 co-op (GAMEPLAY.md 13.9.4, DESIGN.md D.6; a co-op party only): its thread can be struck - a hero's club box
## that overlaps the thread (EnemyTuning.THREAD_CUT_W px wide, from its attach point down to the body) cuts it: the
## dangler falls off with gravity, harmless, and is gone (no points; it comes back only after a team wipe). The
## Snatcher bat keeps its thread (its `grab` gate). A party of one runs exactly the 1.0 code.
##
## Parameters: `depth` px [48], `speed` px per tick [2], `skin` [bat], `hp` [25], `score` [0].

## How far below the anchor it goes, px (level parameter `depth`).
var depth: int = EnemyTuning.DANGLER_DEPTH
## Thread speed, px per tick (level parameter `speed`).
var speed: int = EnemyTuning.DANGLER_SPEED

var _going_down: bool = true
## 2.0 co-op: its thread was cut (it falls until it leaves the view, then is gone); its one-shot flag before the cut.
var _cut: bool = false
var _one_shot_before_cut: bool = false


func _default_skin() -> String:
	return "bat"


func _apply_params(params: Dictionary) -> void:
	score_index = EnemyTuning.SCORE_DANGLER
	super._apply_params(params)
	depth = maxi(int(params.get("depth", depth)), 0)
	speed = maxi(absi(int(params.get("speed", speed))), 1)


## True after its thread was cut (tests and tools).
func is_cut() -> bool:
	return _cut


func _on_wake() -> void:
	_thread_top = _find_thread_top()
	_thread_on = true
	_going_down = true
	_play(&"hang")


func _on_reset() -> void:
	if _cut:
		_cut = false
		one_shot = _one_shot_before_cut
		contact_hurts = true


func _ai_tick() -> void:
	if _cut:
		yvel = mini(yvel + Tuning.ENEMY_GRAVITY, Tuning.ENEMY_TERMINAL)
		sim_pos.y += Tuning.floor16(yvel)
		_play(&"dive")
		return
	if CoopTraits.party_on() and _thread_struck():
		_cut_thread()
		return
	var bottom: int = spawn_pos.y + depth
	if _going_down:
		sim_pos.y = mini(sim_pos.y + speed, bottom)
		_going_down = sim_pos.y < bottom
	else:
		sim_pos.y = maxi(sim_pos.y - speed, spawn_pos.y)
		_going_down = sim_pos.y <= spawn_pos.y
	_play(&"hang")


## The thread as a box: EnemyTuning.THREAD_CUT_W px wide on the anchor column, from the attach point to the body.
func get_thread_rect() -> Rect2i:
	if not _thread_on or _cut:
		return Rect2i()
	var bottom: int = sim_pos.y - _thread_end_art() / Tuning.ART_SCALE
	if bottom <= _thread_top.y:
		return Rect2i()
	return Rect2i(_thread_top.x - (EnemyTuning.THREAD_CUT_W >> 1), _thread_top.y, EnemyTuning.THREAD_CUT_W,
			bottom - _thread_top.y)


## True when a living hero's club box of this tick (still active after the weapon pass: it hit nothing) overlaps the
## thread.
func _thread_struck() -> bool:
	var thread: Rect2i = get_thread_rect()
	if thread.size.y <= 0:
		return false
	for hero: PlayerBase in Game.level.contact_order():
		if hero.club_box_active and not hero.dead and hero.club_box.intersects(thread):
			return true
	return false


func _cut_thread() -> void:
	_cut = true
	_one_shot_before_cut = one_shot
	one_shot = true  # gone once it falls out of the view (reset after a team wipe)
	_thread_on = false
	contact_hurts = false
	xvel = 0
	yvel = 0
	Audio.play_sfx(Sfx.ENEMY_VOICE)
	_play(&"dive", true)

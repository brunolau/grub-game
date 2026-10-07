class_name Drum
extends HittableBase
## `objects/drum bond=<name>` (DESIGN.md D.5, GAMEPLAY.md 13.9.7, [R10]): a twin drum. Every weapon box, thrown weapon
## or batted ball hits it (at most one hit per Tuning.HIDDEN_SPOT_HIT_COOLDOWN = 6 ticks; it is never used up). The
## first hit of a try lights it and opens the bond's window - PartyTuning.window_ticks(difficulty): 24 ticks on
## Beginner, 12 on Expert, or [member window] when a tool or test set it; when every drum of the bond is lit inside
## the window the bond succeeds for good (its `objects/column trigger=drums:<bond>` rises, its `objects/gate
## needs=<bond>` unlocks), otherwise every drum goes dark at the end of the window and may be tried again. A team
## wipe (the level reset) darkens the bond and undoes a success.
##
## Timing (hits arrive in the WEAPONS phase, the window counts down in WORLD): a hit on tick t0 opens a window of W
## ticks, so the other drums must be hit on ticks t0 .. t0 + W - 1.
##
## The bond's state lives on its first drum in registration order, the leader ([method bond_drums]). The count-in:
## while a hatched hero stands within ObjTuning.COUNT_IN_REACH_PX of every drum of the bond (not all of them the same
## hero) the leader plays three blips ObjTuning.COUNT_IN_SPACING_TICKS apart, then "go" (presentation only; nothing
## needs two inputs on the same tick).
##
## Enemies may share the `bond=` registry (LevelBase.get_tagged): only Drum members count here.
##
## `skin=drum|cap` [drum] (2.0, 6-2 Spore Hollow co-op: "twin drums made of glowing caps", DESIGN.md D.10; a picture
## only): CAP_TEXTURE in the layout of drum.png (5 cells of 40 x 44 art px, pivot (20, 44), the same frames). Until
## art-A delivers that file the drum is drawn.

## Sheet [M drum]: idle 0; hit 1, 2, 0 at 16 fps; lit 3; lit_hit 4, 3 at 16 fps.
const HIT_FRAMES: Array[int] = [1, 2, 0]
const LIT_HIT_FRAMES: Array[int] = [4, 3]
const FRAME_IDLE: int = 0
const FRAME_LIT: int = 3
## `skin` values; the glowing cap's picture.
const SKINS: Array[String] = ["drum", "cap"]
const CAP_TEXTURE: String = "res://assets/sprites/objects/drum_cap.png"

## The bond this drum belongs to (`bond`).
var bond: StringName = &""
## Index into SKINS.
var skin: int = 0
## Lit: struck in the open window (or the bond succeeded).
var lit: bool = false
## True once the bond succeeded (until the level reset).
var succeeded: bool = false
## Window length in ticks; -1 = PartyTuning.window_ticks(Game.difficulty). Tools and tests may set it (on the leader:
## it is the bond's).
var window: int = -1
## The leader only: ticks the bond's open window still runs (0 = closed).
var window_left: int = 0
## Sim.tick of its last counted hit (-1 = none) and the hits it took (statistics, the solo search, tests).
var last_hit_tick: int = -1
var hits: int = 0
## The leader only: ticks into the running count-in (-1 = none) and whether the heroes stood ready on the last test.
var count_in: int = -1

var _sprite: Sprite2D = null
var _anim: int = -1
var _ready_last: bool = false
var _drums: Array[Drum] = []
var _drums_members: int = -1


func _init() -> void:
	super()
	counts_for_completion = false
	spot_kind = &"drum"
	# 40 x 44 art px = 20 x 22 logical px (ASSET_MANIFEST: drum), bottom-centred.
	set_box(Vector3i(20, 22, 10))


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	bond = StringName(str(params.get("bond", "")))
	hits_left = 1
	hits_total = 1
	_sprite = get_node_or_null(^"Sprite") as Sprite2D
	skin = SKINS.find(str(params.get("skin", SKINS[0])))
	if skin < 0:
		push_warning("objects/drum: unknown skin '%s'" % str(params.get("skin")))
		skin = 0
	if skin == 1 and _sprite != null:
		_sprite.texture = ObjTuning.picture(CAP_TEXTURE, _sprite.texture)
	_show()


## The weapon pass's hit test (PHYSICS.md 8.3 #2 for a free-standing thing): within 1 column of its cell, and the
## box origin between its top and one tile below its feet.
func is_hit_by(origin: Vector2i) -> bool:
	return absi(cell.x - (origin.x >> 4)) <= Tuning.HIDDEN_HIT_COLS and origin.y > box_top() \
			and origin.y < sim_pos.y + Tuning.TILE


## A weapon hit it: consumed (a hit inside the 6-tick cool-down too, without effect). Lights it and opens or joins the
## bond's window.
func take_hit(_power: int, source: SimEntity) -> bool:
	_doze_wake_now()
	if cooldown > 0:
		return true
	cooldown = Tuning.HIDDEN_SPOT_HIT_COOLDOWN
	if source is PlayerBase:
		strike_dir = source.facing
	elif source != null:
		strike_dir = -1 if source.xvel < 0 else 1
	last_hit_tick = Sim.tick
	hits += 1
	_anim = 0
	ObjTuning.play_cue(Sfx.DRUM, Sfx.CLUB_HIT_SCENERY)
	var level: LevelBase = Game.level
	if level != null:
		level.spawn_fx(&"fx/star_puff", get_hit_point())
		if not succeeded:
			_light(level)
	_show()
	return true


func get_hit_point() -> Vector2i:
	return Vector2i(sim_pos.x, sim_pos.y - (box_h >> 1))


## The drums of this bond in registration order (the first is the leader). Cached while the bond's registry keeps its
## size; read it, never modify it.
func bond_drums(level: LevelBase) -> Array[Drum]:
	if level == null or bond == &"":
		if _drums.is_empty():
			_drums.append(self)
		return _drums
	var members: Array[SimEntity] = level.get_tagged(&"bond", bond)
	if members.size() == _drums_members:
		return _drums
	_drums_members = members.size()
	_drums.clear()
	for entity: SimEntity in members:
		var drum: Drum = entity as Drum
		if drum != null:
			_drums.append(drum)
	if _drums.is_empty():
		_drums.append(self)
	return _drums


## The bond's window length (ticks) for the current difficulty.
func window_ticks() -> int:
	return window if window >= 0 else PartyTuning.window_ticks(Game.difficulty)


func _light(level: LevelBase) -> void:
	if lit:
		return
	var drums: Array[Drum] = bond_drums(level)
	var leader: Drum = drums[0]
	lit = true
	if leader.window_left <= 0:
		# The first hit of a try opens the window (the leader counts it down, so wake it now: SimEntity "Dozing").
		leader._doze_wake_now()
		leader.window_left = leader.window_ticks()
	for drum: Drum in drums:
		if not drum.lit:
			return
	for drum: Drum in drums:
		drum.succeeded = true
		drum.lit = true
		drum._show()
	leader.window_left = 0
	ObjTuning.play_cue(Sfx.COUNT_IN, Sfx.SPOT_OPENED)


## True when the drum bond `bond` of `level` has succeeded (its column rises, its gate unlocks); false while one of
## its drums has not, or when the level has no drum of that bond.
static func bond_succeeded(level: LevelBase, bond_name: StringName) -> bool:
	if level == null or bond_name == &"":
		return false
	var found: bool = false
	for entity: SimEntity in level.get_tagged(&"bond", bond_name):
		var drum: Drum = entity as Drum
		if drum == null:
			continue
		if not drum.succeeded:
			return false
		found = true
	return found


func _sim_tick(phase: int) -> void:
	super._sim_tick(phase)
	if _anim >= 0:
		_anim += 1
		var frames: Array[int] = LIT_HIT_FRAMES if lit else HIT_FRAMES
		if ObjTuning.anim_frame(_anim, ObjTuning.DRUM_HIT_FPS) >= frames.size():
			_anim = -1
			_doze_note()
		_show()
	var level: LevelBase = Game.level
	if level == null:
		return
	var drums: Array[Drum] = bond_drums(level)
	if drums[0] != self:
		return
	if window_left > 0:
		window_left -= 1
		if window_left == 0 and not succeeded:
			for drum: Drum in drums:
				drum.lit = false
				drum._show()
				drum._doze_note()
	_count_in_step(level, drums)


## The leader's count-in (presentation): three blips while every drum has a hatched hero beside it, then "go".
func _count_in_step(level: LevelBase, drums: Array[Drum]) -> void:
	if succeeded or drums.size() < 2:
		count_in = -1
		return
	var ready: bool = _heroes_ready(level, drums)
	if not ready:
		count_in = -1
		_ready_last = false
		return
	if not _ready_last:
		_ready_last = true
		count_in = 0
	if count_in < 0:
		return
	if count_in % ObjTuning.COUNT_IN_SPACING_TICKS == 0:
		var beep: int = count_in / ObjTuning.COUNT_IN_SPACING_TICKS
		if beep < PartyTuning.COUNT_IN_BEEPS:
			ObjTuning.play_cue(Sfx.COUNT_IN)
		else:
			ObjTuning.play_cue(Sfx.DRUM)
			count_in = -1
			return
	count_in += 1


func _heroes_ready(level: LevelBase, drums: Array[Drum]) -> bool:
	var used: int = 0
	for drum: Drum in drums:
		var near: int = 0
		for hero: PlayerBase in level.contact_order():
			if hero.is_party_targetable() \
					and absi(hero.sim_pos.x - drum.sim_pos.x) <= ObjTuning.COUNT_IN_REACH_PX \
					and absi(hero.sim_pos.y - drum.sim_pos.y) <= ObjTuning.COUNT_IN_REACH_PX:
				near |= 1 << hero.slot
		if near == 0:
			return false
		used |= near
	# Not one hero standing between them all.
	return ObjTuning.bit_count(used) >= 2


## Dozing (HittableBase): only while dark, without a window and without an animation.
func _is_idle() -> bool:
	return _anim < 0 and not lit and window_left == 0 and count_in < 0


func _on_level_reset() -> void:
	lit = false
	succeeded = false
	window_left = 0
	cooldown = 0
	count_in = -1
	_ready_last = false
	_anim = -1
	_show()


func _show() -> void:
	if _sprite == null:
		return
	if _anim >= 0:
		var frames: Array[int] = LIT_HIT_FRAMES if lit else HIT_FRAMES
		var index: int = mini(ObjTuning.anim_frame(_anim, ObjTuning.DRUM_HIT_FPS), frames.size() - 1)
		_sprite.frame = frames[index]
	else:
		_sprite.frame = FRAME_LIT if lit else FRAME_IDLE

class_name BossBolt
extends ProjectileBase
## `projectiles/boss_bolt` - the Storm Roc's lightning (DESIGN.md B.5, GAMEPLAY.md 13.6; the lightning rule of
## PHYSICS.md C.6). Owner: enemies-C (PLAN.md P2.3). Spawned by the Roc at the TOP of the room over the column of a hero
## (the spawn point: the column's centre x at the room's top).
##
##  1. `mark` [22] ticks: a darkening cloud at the top marks the column; nothing is harmful yet.
##  2. BOLT_TICKS ticks: a bolt fills the 16 px column from the top down to the first floor below it. A hero touching
##     it is hurt as by an enemy contact (PlayerBase.hurt, Defs.HurtKind.ENEMY: a heart - or the glider instead).
##  3. When that first floor is the Roc's stick nest (`nest_x0` <= x < `nest_x1`, surface `nest_top`), the struck
##     sticks burn BURN_TICKS: a 16 x 8 fire on the nest top that hurts like the bolt. Otherwise it is gone.
## The tests use plain rectangles (a bolt is a tall thin column; the body test's coarse reject would miss a glider).
## The struck floor shelters a hero beneath it (his feet below its surface): standing on the floor under the nest he is
## neither struck nor burnt by a bolt on the nest over his head.
##
## Parameters (set by the Roc): `mark` ticks [22], `bottom` y of the room's bottom (px), `nest_x0`, `nest_x1`,
## `nest_top` (px).

const MARK_TICKS: int = 22
const BOLT_TICKS: int = 4
const BURN_TICKS: int = 66
const COLUMN_W: int = Tuning.TILE
const BURN_H: int = 8
## art-B's sheets (EnemySkin cases): the bolt and its flash, the storm mark.
const LIGHTNING_SHEET: String = "roc_lightning"
const PARTS_SHEET: String = "roc_parts"
## Colours of the drawn placeholder (and of the burning sticks, which have no picture).
const COL_CLOUD: Color = Color(0.16, 0.16, 0.24, 0.85)
const COL_BOLT: Color = Color(1.0, 0.97, 0.7, 0.95)
const COL_BURN: Color = Color(1.0, 0.55, 0.15, 0.9)

var mark: int = MARK_TICKS
## The top of the column (the spawn y) and the floor it strikes (px).
var top_y: int = 0
var strike_y: int = 0
var burns: bool = false


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	from_hero = false
	hurt_kind = Defs.HurtKind.ENEMY
	xvel = 0
	yvel = 0
	mark = maxi(int(params.get("mark", MARK_TICKS)), 0)
	top_y = spawn_pos.y
	var bottom: int = int(params.get("bottom", top_y + Tuning.VIEW_H))
	strike_y = bottom
	var level: LevelBase = Game.level
	if level != null:
		var col: int = Tuning.to_cell(spawn_pos.x)
		for row: int in range(maxi(Tuning.to_cell(top_y), 0), Tuning.to_cell(bottom) + 1):
			if TileGrid.is_ground(level.grid.floor_at(col, row)):
				strike_y = row * Tuning.TILE + level.grid.surface_offset(col, row, spawn_pos.x)
				break
	var nest_x0: int = int(params.get("nest_x0", 0))
	var nest_x1: int = int(params.get("nest_x1", 0))
	var nest_top: int = int(params.get("nest_top", -1))
	burns = spawn_pos.x >= nest_x0 and spawn_pos.x < nest_x1 and strike_y == nest_top
	life = mark + BOLT_TICKS + (BURN_TICKS if burns else 0)
	set_box(Vector3i(COLUMN_W, maxi(strike_y - top_y, 1), COLUMN_W >> 1))
	teleport(Vector2i(spawn_pos.x, strike_y))


## Marking (harmless), striking or burning.
func is_marking() -> bool:
	return _age < mark


func is_striking() -> bool:
	return _age >= mark and _age < mark + BOLT_TICKS


func is_burning() -> bool:
	return burns and _age >= mark + BOLT_TICKS


## The harmful rectangle now (logical px; empty while marking).
func get_harm_rect() -> Rect2i:
	var left: int = sim_pos.x - (COLUMN_W >> 1)
	if is_striking():
		return Rect2i(left, top_y, COLUMN_W, strike_y - top_y)
	if is_burning():
		return Rect2i(left, strike_y - BURN_H, COLUMN_W, BURN_H)
	return Rect2i()


func _move_tick() -> void:
	_age += 1
	if _age == mark:
		Audio.play_sfx(Sfx.IMPACT)
		if Game.level != null:
			Game.level.request_shake(EnemyTuning.BOSS_BOB_SHAKE)
	queue_redraw()
	if life > 0 and _age >= life:
		consume()


func _test_hero() -> void:
	var harm: Rect2i = get_harm_rect()
	var level: LevelBase = Game.level
	if harm.size.x <= 0 or level == null:
		return
	for hero: PlayerBase in level.contact_order():
		if hero.dead or hero.is_down():
			continue
		# The struck floor shelters whoever stands beneath it: a hero on the floor under the nest (his head pokes 3 px
		# into the one-way nest row) is neither struck nor burnt by a bolt that hits the nest over him.
		if hero.sim_pos.y > strike_y:
			continue
		if Overlap.rects(harm, hero.get_box()) and hero.hurt(self, hurt_kind):
			_on_hit_hero()
			return


func _on_hit_hero() -> void:
	Audio.play_sfx(Sfx.IMPACT)


func _draw() -> void:
	var scale: float = float(Tuning.ART_SCALE)
	var half: float = float(COLUMN_W >> 1) * scale
	var height: float = float(strike_y - top_y) * scale
	if _draw_sheets(height):
		return
	if is_marking():
		var dark: float = clampf(float(_age + 1) / float(maxi(mark, 1)), 0.2, 1.0)
		var cloud: Color = COL_CLOUD
		cloud.a *= dark
		draw_circle(Vector2(0.0, -height + 6.0 * scale), 14.0 * scale, cloud)
	elif is_striking():
		draw_rect(Rect2(-half * 0.5, -height, half, height), COL_BOLT)
	elif is_burning():
		draw_rect(Rect2(-half, -float(BURN_H) * scale, half * 2.0, float(BURN_H) * scale), COL_BURN)


## art-B's sheets (cosmetic): the storm mark (roc_parts `storm_mark`, lit / dim) at the top of the column while it
## marks, the bolt segments (roc_lightning `bolt` 0 / 1 stacked down the column) and the `flash` at the struck floor
## while it strikes. False when a sheet is missing (the drawn placeholder then) or while it burns (drawn).
func _draw_sheets(height: float) -> bool:
	if is_burning():
		return false
	if is_marking():
		var parts: EnemySkin = EnemySkin.find(PARTS_SHEET)
		if parts == null or not parts.has_anim(&"storm_mark"):
			return false
		var mark_anim: Vector4i = parts.anim(&"storm_mark")
		var mark_frame: int = mark_anim.x + (_age / maxi(mark_anim.z, 1)) % maxi(mark_anim.y, 1)
		_draw_cell(parts, mark_frame, Vector2(0.0, -height + float(parts.pivot.y)))
		return true
	var lightning: EnemySkin = EnemySkin.find(LIGHTNING_SHEET)
	if lightning == null or not lightning.has_anim(&"bolt"):
		return false
	var bolt: Vector4i = lightning.anim(&"bolt")
	var step: float = float(lightning.pivot.y)
	var y: float = -height + step
	var i: int = 0
	while y < step:
		_draw_cell(lightning, bolt.x + (i + (_age >> 1)) % maxi(bolt.y, 1), Vector2(0.0, minf(y, 0.0)))
		y += step
		i += 1
	if lightning.has_anim(&"flash"):
		_draw_cell(lightning, lightning.anim(&"flash").x, Vector2.ZERO)
	return true


## One cell of `sheet` with its pivot at `at` (art px, relative to the feet point).
func _draw_cell(sheet: EnemySkin, frame: int, at: Vector2) -> void:
	var texture: Texture2D = load(sheet.texture_path) as Texture2D
	if texture == null:
		return
	var column: int = frame % maxi(sheet.columns, 1)
	var row: int = frame / maxi(sheet.columns, 1)
	var source: Rect2 = Rect2(Vector2(column * sheet.cell.x, row * sheet.cell.y), Vector2(sheet.cell))
	draw_texture_rect_region(texture, Rect2(at - Vector2(sheet.pivot), Vector2(sheet.cell)), source)

class_name LevelBase
extends Node2D
## Base class of the gameplay scene root: what every other module may ask the running level.
##
## CONTRACT FILE (docs/ARCHITECTURE.md 3.11). Owner: world (bodies may be extended; public signatures are frozen).
## `res://scenes/world/level.tscn` has a root script that extends this class. A bare LevelBase with a TileGrid is
## already a working, invisible level: tests build one in a few lines (see tests/test_core_level_base.gd).
##
## Everything positional is in logical px (feet points); the level node itself and all entity containers must
## stay at the canvas origin with identity transform, because SimEntity writes `position = sim_pos * ART_SCALE`.
##
## 2.0 PlayerSet (docs/expansion/TECH_AUDIT.md 4.1, PLAN.md P0.6): a level may hold up to Defs.MAX_PLAYERS heroes,
## one per player slot ([member heroes]; slot 0 = P1 = [member player]). Every reader of "the hero" uses one of three
## idioms, and each reduces to the 1.0 code for a party of one (the single-player game, TECH_AUDIT.md 2):
##  - target: `level.target_hero(self)` - the hero an enemy reacts to (1.0: `player` unless dead);
##  - every:  `for hero: PlayerBase in level.contact_order(): ...` - every hero in contact order (1.0: `[player]`);
##  - P1:     `level.player` - genuinely player 1 (the camera of 1.0, a P1 HUD panel, traces).
## Views: [method get_view_count], [method get_view_rect_at], [method get_view_rect_of], [method get_views_bounds];
## `is_in_view` and the `on_screen` flags mean "in any view" (one view in 1.0). The doze manager keeps one rectangle
## per hero. The party rules themselves (eggs, the tribe camera, versus) are NOT here: a party of two or more gets
## only the neutral defaults documented on each member (TECH_AUDIT.md 4.7; the PartyDriver of PLAN.md P1 replaces
## them). A party of one never reaches a party branch: they are all behind `hero_count() > 1`.
## Hooks for parallel work (PLAN.md P0.8): [method register_party_driver] / [member party_driver] (world-A's
## PartyDriver after the heroes) and [method get_tagged] (the bond and keeper groups of format 2).
## Co-op rules of phase 1 (PLAN.md P1.6, PHYSICS.md C.12 / C.13): [method get_party_frame] (the authentic 20 x 11-cell
## view of the tribe camera), [method get_edge_walls], [method pull_party_into] (locked views take the whole party),
## [method team_wipe], [method party_spread_point]. Each is neutral for a party of one and outside co-op.

## Gameplay is about to start: the grid is built, the hero is spawned, Sim is started.
signal play_started
## The whole seconds left on the level's time limit changed (only emitted by levels whose `time` is > 0).
signal time_left_changed(seconds: int)

## Id of the level file (name without extension).
var level_id: StringName = &""
## Parsed [meta] section of the level file.
var meta: Dictionary = {}
## Collision grid. Never null once the level is ready.
var grid: TileGrid = TileGrid.new(0, 0)
## The hero: P1, the hero of player slot 0 (null until spawned). In single-player the only hero.
var player: PlayerBase = null
## Where the hero (P1) starts when no checkpoint is active (feet point, logical px).
var start_pos: Vector2i = Vector2i(Tuning.TILE * 2, Tuning.TILE * 2)
## Every hero of the level in slot order: `heroes[s]` is the hero of player slot `s` (PlayerBase.slot), slot 0 = P1 =
## [member player]. A single-player level holds `[player]`. Kept by the registry (a hero registers himself when he
## enters the tree): read it, never write it. Within 0..hero_count() - 1 an entry is null only while the level is
## built or torn down. For loops use [method contact_order] (no null entries, the order contested contacts use).
var heroes: Array[PlayerBase] = []
## Feet points (logical px) where each player slot starts, filled by the level loader (index = slot): [0] = '@' =
## [member start_pos], [s] = the `objects/hero_start slot=<s + 1>` marker or the spread of
## PartyTuning.RESPAWN_SPREAD_PX per slot from '@'. Ask [method get_start_pos_for]: it also answers for a slot the
## loader did not fill (and for slot 0 always returns [member start_pos]).
var start_positions: Array[Vector2i] = []
## Screen-shake counter of PHYSICS.md 13.3. Write it through request_shake(); the hero decrements it with
## tick_shake_timer() in his timer step (a party: tick_shake_timer_by(), once per tick).
var shake: int = 0
## Vertical view offset in logical px produced by the shake this tick (0 = none). The camera adds it when drawing.
var shake_offset: int = 0
## Current wind value of PHYSICS.md 13.1 (0 on normal levels). The hero's WIND primitive reads it.
var wind: int = 0
## 2.0 co-op lee ("lee leapfrog", DESIGN.md 3-1b / 9-2 co-op): bit per slot - that hero is sheltered from the wind on
## this tick by a crouching partner. The PartyDriver writes it in WEAPONS, before any hero moves; it is always 0 in
## single-player, in versus and for a party of one. Read it through [method wind_for].
var lee_mask: int = 0
## Bit mask of Defs.SCROLL_* flags.
var scroll_flags: int = 0
## True while the level is dark (GAMEPLAY.md 7.10).
var dark: bool = false
## True once the hero reached an exit; the simulation keeps running for the exit animation only.
var completed: bool = false
## Number of enemies that are awake (EnemyBase keeps it up to date); capped at Tuning.MAX_ACTIVE_ENEMIES.
var active_enemies: int = 0
## Ticks left on the level's time limit (meta key `time`); -1 = the level has no limit. Running out costs a life.
var time_left: int = -1

## Measurement switch (scripts/core/dev/sim_bench.gd --no-doze): false = no entity ever dozes. Dozing changes no
## outcome; the bench proves it by comparing both.
static var doze_enabled: bool = true

var _by_kind: Array[Array] = []
var _named: Dictionary = {}
var _camera_locked: bool = false
var _camera_lock_rect: Rect2i = Rect2i()
## Darkness a respawn restores: the state when the active checkpoint was touched, or at the start of play.
var _respawn_dark: bool = false
## Registered entities that tick (not dozing), any order: the on_screen pass runs over them.
var _awake: Array[SimEntity] = []
## Doze manager (ARCHITECTURE.md 11, SimEntity "Dozing"): the entities it looks after, their doze areas (4 ints per
## slot: left, top, right, bottom, right exclusive; right <= left = never dozes), whether an area is known, the
## entities whose state changed since the last decision, the bounds of the two doze rectangles of the last full
## pass (view and hero: left, top, right, bottom each), and the view and hero feet point the last decision was
## made for.
var _doze: Array[SimEntity] = []
var _doze_rects: PackedInt32Array = PackedInt32Array()
var _doze_known: PackedByteArray = PackedByteArray()
var _doze_notes: Array[SimEntity] = []
var _dz_view_left: int = 0
var _dz_view_top: int = 0
var _dz_view_right: int = 0
var _dz_view_bottom: int = 0
var _dz_hero_left: int = 0
var _dz_hero_top: int = 0
var _dz_hero_right: int = 0
var _dz_hero_bottom: int = 0
var _doze_full: bool = true
var _doze_view: Rect2i = Rect2i()
## True while the end-of-tick decision runs (right before the on_screen pass). An entity dozing off at any other
## moment keeps its on_screen until the next pass computes it once more (as it would have without dozing).
var _doze_at_tick_end: bool = false
var _doze_screen_pending: Array[SimEntity] = []
var _doze_hero: Vector2i = Vector2i(-1, -1)
## Doze rectangles beyond view 0 and the first hero, for a party or a level with several views (none in
## single-player): 4 ints each (left, top, right, bottom; the extra views first, then every other hero), their count,
## a scratch buffer, the feet point of every hero (x, y in slot order) and every view (index = view) of the last
## decision.
var _dz_more: PackedInt32Array = PackedInt32Array()
var _dz_more_count: int = 0
var _dz_scratch: PackedInt32Array = PackedInt32Array()
var _doze_feet: PackedInt32Array = PackedInt32Array()
var _doze_views: Array[Rect2i] = []

## PlayerSet bookkeeping: the number of registered heroes (non-null entries of `heroes`), the contact orders of a
## party (index r = the heroes in slot order rotated by r; rebuilt when the party changes, so contact_order() never
## allocates), the one-entry order of a party of one (always `player`, as 1.0 read it) and the empty order.
var _hero_total: int = 0
var _orders: Array[Array] = []
var _solo_order: Array[PlayerBase] = [null]
var _no_heroes: Array[PlayerBase] = []
## tick_shake_timer_by(): the Sim.total_ticks value and the hero (instance id) that own this tick's decrement.
var _shake_tick: int = -1
var _shake_hero: int = 0
## hero_death_finished() of a party: bit `slot` = that hero's death toss has finished (cleared by every respawn).
var _death_done: int = 0

## 2.0 hooks (PLAN.md P0.8). Spawn parameters that tag an entity into a group ([method get_tagged]): `bond=<name>`
## (linked enemies and drums, DESIGN.md D.5 / D.6) and `keeper=<name>` (the enemies a keeper door waits for, [R10]).
const TAG_PARAMS: Array[String] = ["bond", "keeper"]
## The PartyDriver of a party (world-A, PLAN.md P1.6), registered after the heroes ([method register_party_driver]);
## null in single-player and until one is registered.
var party_driver: SimEntity = null
## Tag groups: StringName param -> { StringName value -> Array[SimEntity] in registration order }.
var _tagged: Dictionary = {}
var _no_entities: Array[SimEntity] = []
## True when the registered party driver handles party deaths itself (it has `handle_hero_death(hero) -> bool`).
var _driver_handles_deaths: bool = false


func _init() -> void:
	for i: int in Defs.KIND_COUNT:
		var list: Array[SimEntity] = []
		_by_kind.append(list)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			add_to_group(Defs.GROUP_LEVEL)
			Game.level = self
			if not Sim.tick_finished.is_connected(_on_tick_finished):
				Sim.tick_finished.connect(_on_tick_finished)
			if not Sim.tick_started.is_connected(_on_tick_started):
				Sim.tick_started.connect(_on_tick_started)
			if not Events.shake_requested.is_connected(request_shake):
				Events.shake_requested.connect(request_shake)
			if not Events.player_death_finished.is_connected(_on_player_death_finished):
				Events.player_death_finished.connect(_on_player_death_finished)
			if not Events.popup_requested.is_connected(_on_popup_requested):
				Events.popup_requested.connect(_on_popup_requested)
			if not Game.checkpoint_changed.is_connected(_on_checkpoint_changed):
				Game.checkpoint_changed.connect(_on_checkpoint_changed)
		NOTIFICATION_EXIT_TREE:
			if Events.popup_requested.is_connected(_on_popup_requested):
				Events.popup_requested.disconnect(_on_popup_requested)
			if Game.checkpoint_changed.is_connected(_on_checkpoint_changed):
				Game.checkpoint_changed.disconnect(_on_checkpoint_changed)
			if Sim.tick_finished.is_connected(_on_tick_finished):
				Sim.tick_finished.disconnect(_on_tick_finished)
			if Sim.tick_started.is_connected(_on_tick_started):
				Sim.tick_started.disconnect(_on_tick_started)
			if Events.shake_requested.is_connected(request_shake):
				Events.shake_requested.disconnect(request_shake)
			if Events.player_death_finished.is_connected(_on_player_death_finished):
				Events.player_death_finished.disconnect(_on_player_death_finished)
			if Game.level == self:
				Game.level = null


# =================================================================================================================
# Entity registry
# =================================================================================================================

## Called by SimEntity when it enters the tree. Adds it to the list of its kind and to the name index.
func register_entity(entity: SimEntity) -> void:
	var kind: int = entity.get_kind()
	var list: Array = _by_kind[kind]
	if not list.has(entity):
		list.append(entity)
	if entity.spawn_params.has("name"):
		_named[StringName(str(entity.spawn_params["name"]))] = entity
	for tag: String in TAG_PARAMS:
		if entity.spawn_params.has(tag):
			_tag_add(tag, StringName(str(entity.spawn_params[tag])), entity)
	if kind == Defs.Kind.PLAYER and entity is PlayerBase:
		_add_hero(entity as PlayerBase)
	if entity._level_awake_slot < 0 and not entity._sim_suspended:
		entity._level_awake_slot = _awake.size()
		_awake.append(entity)
	if doze_enabled and kind != Defs.Kind.PLAYER and kind != Defs.Kind.FX and entity._doze_slot < 0:
		entity._doze_slot = _doze.size()
		_doze.append(entity)
		_doze_rects.append_array([0, 0, 0, 0])
		_doze_known.append(0)


## Called by SimEntity when it leaves the tree.
func unregister_entity(entity: SimEntity) -> void:
	var kind: int = entity.get_kind()
	var list: Array = _by_kind[kind]
	list.erase(entity)
	if entity.spawn_params.has("name"):
		_named.erase(StringName(str(entity.spawn_params["name"])))
	for tag: String in TAG_PARAMS:
		if entity.spawn_params.has(tag):
			var members: Array[SimEntity] = get_tagged(StringName(tag), StringName(str(entity.spawn_params[tag])))
			members.erase(entity)
	if entity == party_driver:
		party_driver = null
		_driver_handles_deaths = false
	if entity == player:
		player = null
	if kind == Defs.Kind.PLAYER:
		_remove_hero(entity)
	_awake_remove(entity)
	var slot: int = entity._doze_slot
	if slot >= 0 and slot < _doze.size() and _doze[slot] == entity:
		# Swap with the last slot (the order of the doze list does not matter).
		var last: int = _doze.size() - 1
		var moved: SimEntity = _doze[last]
		_doze[slot] = moved
		moved._doze_slot = slot
		for j: int in 4:
			_doze_rects[slot * 4 + j] = _doze_rects[last * 4 + j]
		_doze_known[slot] = _doze_known[last]
		_doze.resize(last)
		_doze_rects.resize(last * 4)
		_doze_known.resize(last)
	entity._doze_slot = -1


## Live list of the entities of one Defs.Kind, in spawn (slot) order. Do NOT modify it and do not keep it
## across ticks. Iterate by index when the loop body may spawn or free entities.
func get_kind(kind: int) -> Array[SimEntity]:
	return _by_kind[kind]


## Entity whose level-file parameter `name=` equals `entity_name` (null when there is none).
func find_named(entity_name: StringName) -> SimEntity:
	var entity: SimEntity = _named.get(entity_name)
	return entity if is_instance_valid(entity) else null


## 2.0 (PLAN.md P0.8): the registered entities whose spawn parameter `param` (one of TAG_PARAMS: &"bond", &"keeper")
## equals `value`, in registration order - the bond registry of linked enemies and drums, the keepers of a keeper
## door. Live list of the level: read it, never modify or keep it; empty when there is none.
func get_tagged(param: StringName, value: StringName) -> Array[SimEntity]:
	var groups: Dictionary = _tagged.get(String(param), {})
	return groups.get(value, _no_entities)


func _tag_add(param: String, value: StringName, entity: SimEntity) -> void:
	if not _tagged.has(param):
		_tagged[param] = {}
	var groups: Dictionary = _tagged[param]
	if not groups.has(value):
		var fresh: Array[SimEntity] = []
		groups[value] = fresh
	var members: Array[SimEntity] = groups[value]
	if not members.has(entity):
		members.append(entity)


# =================================================================================================================
# PlayerSet: the heroes of the party (2.0, docs/expansion/TECH_AUDIT.md 4.1)
# =================================================================================================================

## Number of heroes in the level (registered heroes; 1 in single-player once the hero is spawned). The party
## branches of every module test `hero_count() > 1`; a party of one runs the 1.0 code.
func hero_count() -> int:
	return _hero_total


## The hero of player slot `slot` (0 = P1 = [member player]); null when that slot has no hero.
func get_hero(slot: int) -> PlayerBase:
	if slot < 0 or slot >= heroes.size():
		return null
	return heroes[slot]


## The heroes in the order contested contacts test them this tick ("every hero" idiom): slot order, rotated by
## `Sim.tick % hero_count()` in versus (Game.mode VERSUS) so that no slot wins every tie. A party of one: exactly
## `[player]` (empty without a hero), the 1.0 contact. Dead heroes are included (callers skip them as 1.0 skipped a
## dead hero). The array is the level's own (no allocation per call): read it, never modify it or keep it across
## ticks; iterate a copy when the loop body may free a hero.
func contact_order() -> Array[PlayerBase]:
	if _hero_total <= 1:
		if player == null:
			return _no_heroes
		_solo_order[0] = player
		return _solo_order
	if Game.mode == Defs.GameMode.VERSUS:
		return _orders[Sim.tick % _orders.size()]
	return _orders[0]


## The hero an enemy at `from` reacts to ("target" idiom). A party of one: [member player] unless he is dead, else
## null - exactly 1.0's EnemyBase._target_hero(). A party: the nearest hero that is targetable
## (PlayerBase.is_party_targetable(): alive and hatched) by |dx| + |dy| between feet points, ties to the lower slot
## (GAMEPLAY.md 13.9.4); null when none is. Stateless: stickiness (TARGET_HOLD_TICKS) is the enemy's own business
## (EnemyBase target hook). `from` null = the first targetable hero in slot order.
func target_hero(from: SimEntity) -> PlayerBase:
	if _hero_total <= 1:
		if player == null or player.dead:
			return null
		return player
	var best: PlayerBase = null
	var best_distance: int = 0
	for hero: PlayerBase in _orders[0]:
		if not hero.is_party_targetable():
			continue
		if from == null:
			return hero
		var distance: int = absi(hero.sim_pos.x - from.sim_pos.x) + absi(hero.sim_pos.y - from.sim_pos.y)
		if best == null or distance < best_distance:
			best = hero
			best_distance = distance
	return best


## 2.0 IDLE rule (phase 3): the hero a co-op RULE reads as "the nearer hero" of `from` - [method target_hero]'s
## choice (|dx| + |dy| between feet points, ties to the lower slot) among the heroes that count
## (PlayerBase.counts_for_coop: alive, hatched, not idle); null when none does. For position rules, not for targeting:
## a `shell` record's shield and a boss's "nearer hatched hero" / "on its half" face a hero who plays, never his dozing
## partner (enemies keep attacking whom [method target_hero] gives). A party of one: exactly [method target_hero].
func nearest_coop_hero(from: SimEntity) -> PlayerBase:
	if _hero_total <= 1:
		return target_hero(from)
	var best: PlayerBase = null
	var best_distance: int = 0
	for hero: PlayerBase in _orders[0]:
		if not hero.counts_for_coop():
			continue
		if from == null:
			return hero
		var distance: int = absi(hero.sim_pos.x - from.sim_pos.x) + absi(hero.sim_pos.y - from.sim_pos.y)
		if best == null or distance < best_distance:
			best = hero
			best_distance = distance
	return best


## True when some hero is dead (death toss) or down (an egg, PlayerBase.is_down()). A party of one: P1 is dead.
func any_hero_dead_or_down() -> bool:
	if _hero_total <= 1:
		return player != null and (player.dead or player.is_down())
	for hero: PlayerBase in _orders[0]:
		if hero.dead or hero.is_down():
			return true
	return false


## True when there is a hero and every hero is dead or down at once (a party of one: P1 is dead) - the team wipe of
## DESIGN.md D.3. Flow's restart and the death jingle use it.
func all_heroes_dead_or_down() -> bool:
	if _hero_total <= 1:
		return player != null and (player.dead or player.is_down())
	for hero: PlayerBase in _orders[0]:
		if not hero.dead and not hero.is_down():
			return false
	return true


## True while some hero feasts (enemies are drawn as food, GAMEPLAY.md 8.3). A party of one: P1 feasts.
func any_hero_feasting() -> bool:
	if _hero_total <= 1:
		return player != null and player.is_feasting()
	for hero: PlayerBase in _orders[0]:
		if hero.is_feasting():
			return true
	return false


## Feet point where the hero of player slot `slot` starts: [member start_pos] for slot 0 (P1, '@'), else
## [member start_positions] when the loader filled the slot, else the spread from '@' (PartyTuning.RESPAWN_SPREAD_PX
## per slot towards the side where the floor continues).
func get_start_pos_for(slot: int) -> Vector2i:
	if slot <= 0:
		return start_pos
	if slot < start_positions.size():
		return start_positions[slot]
	return _spread_point(start_pos, slot)


## Spawn the heroes of player slots 1..Game.party - 1 at their starts (party only; a party of one spawns nothing),
## after P1 and after every level entity, as TECH_AUDIT.md 4.4 orders them (level entities -> P1 -> P2 ...): call it
## right after spawning P1. Slots that already have a hero are skipped. Returns the heroes spawned.
func spawn_party_heroes() -> Array[PlayerBase]:
	var spawned: Array[PlayerBase] = []
	if Game.party <= 1 or not Spawner.exists(&"player/player"):
		return spawned
	for slot: int in range(1, mini(Game.party, Defs.MAX_PLAYERS)):
		if get_hero(slot) != null:
			continue
		var pos: Vector2i = get_start_pos_for(slot)
		var hero: PlayerBase = spawn(&"player/player", pos, {"slot": slot}) as PlayerBase
		if hero != null:
			hero.respawn_at(pos)
			spawned.append(hero)
	return spawned


## 2.0 (PLAN.md P0.8, TECH_AUDIT.md 4.4): register the PartyDriver (world-A, PLAN.md P1.6) - the entity that runs the
## hero-against-hero steps of a party (Totem Ride, head contacts, egg drift, team wipe; the versus referee in an
## arena) in the phases it registers, AFTER every hero: call it right after [method spawn_party_heroes], so the
## registration order is level entities -> P1 -> P2 .. -> driver -> runtime spawns and Defs.Phase stays as it is.
## Adds `driver` to the level (container "player") when it has no parent yet and keeps it in [member
## party_driver]. A driver with a method `handle_hero_death(hero: PlayerBase) -> bool` takes over
## [method hero_death_finished] for a party (true = handled; false = the neutral default runs). Never called in
## single-player; a second call replaces nothing (the first driver stays).
func register_party_driver(driver: SimEntity) -> void:
	if driver == null or party_driver != null:
		return
	party_driver = driver
	_driver_handles_deaths = driver.has_method(&"handle_hero_death")
	if driver.get_parent() == null:
		get_container("player").add_child(driver)


# =================================================================================================================
# View
# =================================================================================================================

## Visible rectangle of the level in logical px. The world module overrides it with the camera rectangle.
## With several views (split screen; none yet) this is view 0.
func get_view_rect() -> Rect2i:
	return Rect2i(0, 0, Tuning.VIEW_W, Tuning.VIEW_H)


## Camera cell (column, row) of PHYSICS.md 12: top-left visible tile.
func get_camera_cell() -> Vector2i:
	var view: Rect2i = get_view_rect()
	return Vector2i(view.position.x >> 4, view.position.y >> 4)


## True when the sprite box of `entity`, grown by `margin` px, intersects a view (any view; 1.0: the view).
func is_in_view(entity: SimEntity, margin: int = 0) -> bool:
	var count: int = get_view_count()
	if count <= 1:
		var view: Rect2i = get_view_rect().grow(margin)
		return Overlap.rects(entity.get_box(), view)
	var box: Rect2i = entity.get_box()
	for i: int in count:
		if Overlap.rects(box, get_view_rect_at(i).grow(margin)):
			return true
	return false


## Number of views the level is drawn in: 1 (the shared camera of single-player, co-op and versus). A split screen
## (TECH_AUDIT.md 4.5 option C) would override it together with [method get_view_rect_at].
func get_view_count() -> int:
	return 1


## View `index` in logical px: 0 = [method get_view_rect]; an empty Rect2i for an index that does not exist.
func get_view_rect_at(index: int) -> Rect2i:
	if index == 0:
		return get_view_rect()
	return Rect2i()


## The view `entity` is drawn in (the first view its sprite box meets), else view 0. One view: [method
## get_view_rect]. For "the view this hero is in" (the death toss drifts to its middle, a drop from its top edge).
func get_view_rect_of(entity: SimEntity) -> Rect2i:
	var count: int = get_view_count()
	if count <= 1 or entity == null:
		return get_view_rect()
	var box: Rect2i = entity.get_box()
	for i: int in count:
		var view: Rect2i = get_view_rect_at(i)
		if Overlap.rects(box, view):
			return view
	return get_view_rect()


## The smallest rectangle that contains every view (one view: [method get_view_rect]). "Below every view" is
## `y >= get_views_bounds().end.y`.
func get_views_bounds() -> Rect2i:
	var bounds: Rect2i = get_view_rect()
	for i: int in range(1, get_view_count()):
		bounds = bounds.merge(get_view_rect_at(i))
	return bounds


## 2.0 (PHYSICS.md C.13): the authentic view of the tribe camera in logical px - Tuning.VIEW_COLS x VIEW_ROWS cells
## at the camera cell, identical on every device (a wider screen shows more around it). The co-op edge walls
## ([method get_edge_walls]), the leash and the egg clamp use it. A camera locked to a rectangle no larger than that
## (an arena, a one-screen room) gives that rectangle itself, wherever a larger screen centres it. Otherwise the base
## gives the cells of [method get_view_rect] at the camera cell; the world module's level returns its tribe camera's
## view in co-op.
func get_party_frame() -> Rect2i:
	if _camera_locked and _camera_lock_rect.size.x <= Tuning.VIEW_COLS * Tuning.TILE \
			and _camera_lock_rect.size.y <= Tuning.VIEW_ROWS * Tuning.TILE:
		return _camera_lock_rect
	var cell: Vector2i = get_camera_cell()
	return Rect2i(cell * Tuning.TILE, Vector2i(Tuning.VIEW_COLS, Tuning.VIEW_ROWS) * Tuning.TILE)


## 2.0 co-op edge walls (PHYSICS.md C.13): the x range [x, y) a hero of the tribe may commit his x step to on this
## tick - `camera_column * 16 + 8 <= new_x < camera_column * 16 + 312` of [method get_party_frame]. Vector2i.ZERO
## when no edge walls apply: single-player, versus, or a party of one. The PartyDriver fences every hatched hero with
## it (PlayerBase.fence_x) before the PLAYER phase; a mount or a ball that runs its own x step reads it too.
func get_edge_walls() -> Vector2i:
	if _hero_total <= 1 or Game.mode != Defs.GameMode.COOP:
		return Vector2i.ZERO
	var frame: Rect2i = get_party_frame()
	return Vector2i(frame.position.x + PartyTuning.VIEW_EDGE_WALL_PX, frame.end.x - PartyTuning.VIEW_EDGE_WALL_PX)


## 2.0 locked views in co-op (PHYSICS.md C.13: `zones/arena`, `zones/camera_lock`, a gate with `lock=`): when `trigger`
## locks the camera to `rect`, every other hatched hero whose feet are outside `rect` is moved to the trigger hero's
## feet point - PartyTuning.PULL_IN_BEHIND_PX * his facing (same y; [method notify_hero_teleported]); an egg is
## clamped into the rectangle (PartyTuning.EGG_VIEW_INSET_PX inside). Nothing for a party of one or outside co-op.
func pull_party_into(rect: Rect2i, trigger: PlayerBase) -> void:
	if _hero_total <= 1 or trigger == null or Game.mode != Defs.GameMode.COOP:
		return
	for hero: PlayerBase in _orders[0]:
		if hero == trigger or hero.dead:
			continue
		if hero.is_down():
			var inner: Rect2i = rect.grow(-PartyTuning.EGG_VIEW_INSET_PX)
			var egg: Vector2i = hero.sim_pos.clamp(inner.position, inner.end - Vector2i.ONE)
			if egg != hero.sim_pos:
				hero.teleport(egg)
			continue
		if Overlap.point_in(rect, hero.sim_pos.x, hero.sim_pos.y - 1):
			continue
		hero.xvel = 0
		hero.yvel = 0
		hero.teleport(Vector2i(trigger.sim_pos.x - PartyTuning.PULL_IN_BEHIND_PX * trigger.facing, trigger.sim_pos.y))
		notify_hero_teleported(hero)


## Lock the camera so that it shows exactly `view_px` (boss rooms, single-screen rooms; PHYSICS.md 12.4).
func lock_camera(view_px: Rect2i) -> void:
	_camera_locked = true
	_camera_lock_rect = view_px


## Release a camera lock.
func unlock_camera() -> void:
	_camera_locked = false


## Re-initialise the camera around the hero without scrolling (after a gate, a warp or a respawn; PHYSICS.md 12.5).
## The base implementation has no camera and does nothing.
func snap_camera() -> void:
	pass


## True while the camera is locked; [method get_camera_lock] gives the rectangle.
func is_camera_locked() -> bool:
	return _camera_locked


func get_camera_lock() -> Rect2i:
	return _camera_lock_rect


# =================================================================================================================
# Spawning
# =================================================================================================================

## Spawn an entity by id ("<category>/<name>", see Spawner) with its feet point at `pos` (logical px).
## Returns the node (already in the tree) or null when the scene does not exist.
func spawn(id: StringName, pos: Vector2i, params: Dictionary = {}) -> Node:
	var node: Node = Spawner.instantiate(id)
	if node == null:
		return null
	if node is SimEntity:
		var entity: SimEntity = node
		entity.spawn_setup(pos, params)
	elif node is Node2D:
		var node_2d: Node2D = node
		node_2d.position = Tuning.to_art(Vector2(pos))
	get_container(Spawner.category(id)).add_child(node)
	return node


## Spawn a cosmetic effect ("fx/<name>"). Same as spawn(); exists so call sites read clearly.
func spawn_fx(id: StringName, pos: Vector2i, params: Dictionary = {}) -> Node:
	return spawn(id, pos, params)


## Parent node for a spawned entity of an id category ("enemies", "items", "fx" ...). The world module returns
## its layer containers (ARCHITECTURE.md 5.2); the base implementation returns the level node itself.
func get_container(_category: String) -> Node:
	return self


# =================================================================================================================
# Tiles
# =================================================================================================================

## Replace the tile at a cell by a fixed legend character (TileGrid.CH_*): collision changes at once. The world
## module also updates the visuals (and re-autotiles the neighbours). Used by breakable blocks, rising columns.
func set_cell(col: int, row: int, ch: String) -> void:
	grid.set_char(col, row, ch)


## Fixed legend character at a cell.
func get_cell(col: int, row: int) -> String:
	return grid.get_char(col, row)


## Draw another terrain-atlas tile at a cell without touching collision (-1 = back to the automatic tile).
## Used by hidden spots for their "unopened" / "opened" look. Visual only: the base implementation does nothing.
func set_cell_look(_col: int, _row: int, _atlas_index: int) -> void:
	pass


# =================================================================================================================
# Level-wide effects
# =================================================================================================================

## Start (or strengthen) a screen shake: 4, 7, 8 or 9 (PHYSICS.md 13.3).
func request_shake(amount: int) -> void:
	shake = maxi(shake, amount)


## Step 8i of the hero update: the shake counter decreases by 1 per tick. Called by the hero only.
func tick_shake_timer() -> void:
	if shake > 0:
		shake -= 1


## [method tick_shake_timer] for hero `hero`, once per tick for the whole party (TECH_AUDIT.md 3.4, 5.1): the first
## hero that calls it on a tick owns that tick's decrement; further calls by the same hero in the same tick count
## again, exactly as in 1.0 (his timer step and, on the tick he dies, his death step), and calls by any other hero in
## that tick are ignored. A party of one is therefore exactly tick_shake_timer(). Heroes call this one.
func tick_shake_timer_by(hero: PlayerBase) -> void:
	var now: int = Sim.total_ticks
	var id: int = hero.get_instance_id() if hero != null else 0
	if _shake_tick == now and _shake_hero != id:
		return
	_shake_tick = now
	_shake_hero = id
	tick_shake_timer()


## Switch darkness on or off (fades over Tuning.DARKNESS_FADE_TICKS in the world module).
func set_darkness(p_dark: bool) -> void:
	if dark == p_dark:
		return
	dark = p_dark
	Events.darkness_changed.emit(dark)


## 2.0: the wind `hero`'s WIND primitive feels on this tick - [member wind], or 0 while he is in a crouching
## partner's lee ([member lee_mask], co-op only). Without a party (every single-player tick) it is exactly
## [member wind].
func wind_for(hero: PlayerBase) -> int:
	if lee_mask == 0 or hero == null:
		return wind
	return 0 if (lee_mask & (1 << clampi(hero.slot, 0, Defs.MAX_PLAYERS - 1))) != 0 else wind


## Set the wind value (blizzard script) and tell listeners.
func set_wind(value: int) -> void:
	if wind == value:
		return
	wind = value
	Events.wind_changed.emit(wind)


## Arm the time limit of the level (meta key `time`, in seconds; 0 or less = no limit) and tell listeners
## (Events.time_left_changed always; [signal time_left_changed] only for a real limit). The limit is the whole
## number of ticks that fits into `seconds`, so the display starts at exactly `seconds`.
func set_time_limit(seconds: int) -> void:
	if seconds <= 0:
		time_left = -1
		Events.time_left_changed.emit(-1)
		return
	time_left = floori(float(seconds) * Tuning.TICK_HZ)
	time_left_changed.emit(get_time_left_seconds())
	Events.time_left_changed.emit(get_time_left_seconds())


## One tick of the time limit (phase POST; called by the world module's level). Counts down while the hero is
## alive and the level is not completed, tells listeners when the displayed second changes and kills the hero
## with cause &"time" when it reaches zero. A party: counts while any hero is alive and kills every living hero
## (slot order) at zero.
func tick_time_limit() -> void:
	if _hero_total > 1:
		_tick_party_time_limit()
		return
	if time_left <= 0 or completed or player == null or player.dead:
		return
	var before: int = get_time_left_seconds()
	time_left -= 1
	var after: int = get_time_left_seconds()
	if after != before:
		time_left_changed.emit(after)
		Events.time_left_changed.emit(after)
	if time_left == 0:
		player.kill(&"time")


## Whole seconds left on the time limit, rounded up (-1 = the level has no limit). For the HUD.
func get_time_left_seconds() -> int:
	if time_left < 0:
		return -1
	return ceili(Tuning.ticks_to_seconds(time_left))


# =================================================================================================================
# Flow
# =================================================================================================================

## Begin gameplay: start the simulation clock and announce the level.
func start_play(seed_value: int = 1) -> void:
	completed = false
	_respawn_dark = dark
	Sim.start(seed_value)
	Events.level_started.emit(level_id)
	play_started.emit()


## The hero reached an exit (`exit_kind`: &"exit", &"warp", &"trophy"). Hands over to Flow once. The caller froze
## the controls of the hero who reached it; a party (2.0, TECH_AUDIT.md 3.11 / 3.12): every other hero's controls
## are frozen here too, since the level ends for the whole team.
func complete(exit_kind: StringName) -> void:
	if completed:
		return
	completed = true
	if _hero_total > 1:
		for hero: PlayerBase in _orders[0]:
			hero.set_control_enabled(false)
	Events.exit_reached.emit(exit_kind)
	Flow.complete_level(exit_kind)


## Feet point where the hero (re)appears: the active checkpoint, else the level start.
func get_respawn_pos() -> Vector2i:
	return Game.checkpoint_pos if Game.has_checkpoint else start_pos


## Feet point where the hero of player slot `slot` reappears after a team wipe (PHYSICS.md C.12): slot 0 =
## [method get_respawn_pos]; another slot = the active checkpoint moved PartyTuning.RESPAWN_SPREAD_PX * slot px
## towards the side where the floor continues (the same point when both sides are blocked), or that slot's start
## ([method get_start_pos_for]) without a checkpoint.
func get_respawn_pos_for(slot: int) -> Vector2i:
	if slot <= 0:
		return get_respawn_pos()
	if not Game.has_checkpoint:
		return get_start_pos_for(slot)
	return _spread_point(get_respawn_pos(), slot)


## Respawn after a death (PHYSICS.md 10.4 step 3): reset enemies / platforms / columns, put the hero at the
## respawn point with full energy. Collected items and opened spots stay as they are. The darkness goes back to
## what it was when the active checkpoint was touched (at the level start without one), so a checkpoint before a
## `zones/dark` trigger is lit again. A party: the team wipe - every hero at [method get_respawn_pos_for] his slot
## (Game.on_respawn refills every run of the party); one hero alone comes back with [method respawn_hero].
func respawn_player() -> void:
	Game.on_respawn()
	shake = 0
	shake_offset = 0
	unlock_camera()
	if dark != _respawn_dark:
		# Directly, not through set_darkness(): a respawn behind the curtain plays no "lights out" cue.
		dark = _respawn_dark
		Events.darkness_changed.emit(dark)
	reset_entities()
	_death_done = 0
	if _hero_total > 1:
		for hero: PlayerBase in _orders[0].duplicate():
			hero.respawn_at(get_respawn_pos_for(hero.slot))
	elif player != null:
		player.respawn_at(get_respawn_pos())
	snap_camera()
	# The reset moved entities back to their anchors and the hero far away: decide every doze area afresh.
	_doze_full = true
	_doze_known.fill(0)
	_doze_update()
	Events.level_respawned.emit()


## Call `_on_level_reset()` on every registered entity.
func reset_entities() -> void:
	for list: Array in _by_kind:
		for i: int in range(list.size() - 1, -1, -1):
			var entity: SimEntity = list[i]
			if is_instance_valid(entity):
				entity._on_level_reset()


## Score / multiplier / 1UP / heart pop-ups requested through the event bus become "fx/popup" entities.
func _on_popup_requested(kind: StringName, value: int, pos: Vector2i) -> void:
	if Spawner.exists(&"fx/popup"):
		spawn_fx(&"fx/popup", pos, {"kind": String(kind), "value": value})


## A checkpoint was touched: a respawn there brings back the darkness of this moment.
func _on_checkpoint_changed(_pos: Vector2i) -> void:
	_respawn_dark = dark


## Darkness a respawn would restore now (tests, tools).
func get_respawn_darkness() -> bool:
	return _respawn_dark


## Events.player_death_finished: the hero's death toss ended (PHYSICS.md 10.4) - one life, then the respawn or the
## game over. A party never comes here: its heroes call [method hero_death_finished] themselves.
func _on_player_death_finished() -> void:
	if _hero_total > 1:
		return
	_lose_team_life()


func _lose_team_life() -> void:
	if Game.lose_life():
		respawn_player()
	else:
		Sim.stop()
		Flow.game_over()


## Death routing of a party (TECH_AUDIT.md 4.7): a hero of a party of two or more calls this when his death toss
## has ended (a party of one goes through Events.player_death_finished, which this also falls back to). The
## neutral default, until the PartyDriver (PLAN.md P1) turns deaths into eggs and versus respawns: the hero stays
## dead while any other hero still plays or still has his toss running; once every hero is dead (each toss finished)
## or down, Events.party_wiped, one life from the pool and [method respawn_player] for the whole party (or game
## over), exactly the 1.0 rule. Overrides keep that last step. A registered PartyDriver with `handle_hero_death`
## ([method register_party_driver]) is asked first and replaces the default when it returns true.
func hero_death_finished(hero: PlayerBase) -> void:
	if hero == null:
		return
	if _hero_total <= 1:
		_lose_team_life()
		return
	if _driver_handles_deaths and is_instance_valid(party_driver) \
			and bool(party_driver.call(&"handle_hero_death", hero)):
		return  # the PartyDriver (register_party_driver) took the death: an egg, a versus respawn
	_death_done |= 1 << clampi(hero.slot, 0, Defs.MAX_PLAYERS - 1)
	for other: PlayerBase in _orders[0]:
		if other.is_down():
			continue
		if not other.dead or (_death_done & (1 << clampi(other.slot, 0, Defs.MAX_PLAYERS - 1))) == 0:
			return
	Events.party_wiped.emit()
	_lose_team_life()


## 2.0 team wipe of a party at once (PHYSICS.md C.12; DESIGN.md D.3): Events.party_wiped, one life from the tribe
## pool, then [method respawn_player] (every hero at his slot's respawn point, the world reset) or the game over.
## The PartyDriver calls it when the last hatched hero becomes an egg with no death toss running (a leash or a
## voluntary egg while every partner is down); a wipe after a death toss goes through [method hero_death_finished].
func team_wipe() -> void:
	Events.party_wiped.emit()
	_lose_team_life()


## Put one hero back at `pos` without resetting the world (a co-op hatch, a versus respawn; TECH_AUDIT.md 4.7):
## PlayerBase.respawn_at(pos) (tick state cleared, Events.player_spawned), his finished death forgotten and a doze
## decision for his new place ([method notify_hero_teleported]). His run (energy, glider) is the caller's business
## (`hero.run`); a team wipe uses [method respawn_player] instead.
func respawn_hero(hero: PlayerBase, pos: Vector2i) -> void:
	if hero == null:
		return
	hero.respawn_at(pos)
	_death_done &= ~(1 << clampi(hero.slot, 0, Defs.MAX_PLAYERS - 1))
	notify_hero_teleported(hero)


## A hero of a party moved farther in one go than the doze reach allows for (Tuning.DOZE_HERO_REACH_PX assumes at
## most PartyTuning.MOVE_MAX_PX_PER_TICK px per tick): a throw, a launch, an egg's return, a leash pull, a gate's
## party travel, a respawn. Decides the doze state at once (safe inside a tick: entities near his new place wake
## before the next phase reads them; ARCHITECTURE.md 11.1, TECH_AUDIT.md 4.6). A party of one: nothing - the 1.0
## teleports are covered by the decisions at the end and at the start of every tick.
func notify_hero_teleported(_hero: PlayerBase) -> void:
	if _hero_total <= 1 or not doze_enabled or _doze.is_empty():
		return
	_doze_update()


## End of every tick (after phase POST): the screen-shake step 18 of PHYSICS.md 3, the doze decisions for the next
## tick, and the on_screen flags ("drawn in the previous frame") of every entity. A dozing entity lies outside the
## doze region, which contains the view: its on_screen stays false (set when it dozed off).
func _on_tick_finished(tick: int) -> void:
	shake_offset = 0
	if shake > 1 and (tick & 1) == 1:
		shake += 1
		shake_offset = shake
		if _hero_total > 1:
			# Every hero of the party is nudged, in slot order.
			for hero: PlayerBase in _orders[0]:
				hero.apply_shake_nudge(Tuning.SHAKE_NUDGE)
		elif player != null:
			player.apply_shake_nudge(Tuning.SHAKE_NUDGE)
	if doze_enabled:
		_doze_at_tick_end = true
		_doze_update()
		_doze_at_tick_end = false
	if get_view_count() > 1:
		_update_on_screen_views()
		return
	# Overlap.rects(entity.get_box(), view) for every entity, written out: this loop runs over every ticking
	# entity every tick, and the two calls per entity were a large share of the tick on slow devices. The doze
	# decision has just read the view.
	var view: Rect2i = _doze_view if doze_enabled else get_view_rect()
	var left: int = view.position.x
	var right: int = left + view.size.x
	var top: int = view.position.y
	var bottom: int = top + view.size.y
	for entity: SimEntity in _awake:
		var feet: Vector2i = entity.sim_pos
		var box_left: int = feet.x - entity.box_xo
		entity.on_screen = box_left < right and left < box_left + entity.box_w \
				and feet.y - entity.box_h < bottom and top < feet.y
	if not _doze_screen_pending.is_empty():
		for entity: SimEntity in _doze_screen_pending:
			if is_instance_valid(entity) and entity._sim_suspended:
				var feet: Vector2i = entity.sim_pos
				var box_left: int = feet.x - entity.box_xo
				entity.on_screen = box_left < right and left < box_left + entity.box_w \
						and feet.y - entity.box_h < bottom and top < feet.y
		_doze_screen_pending.clear()


## The on_screen pass with several views: an entity is on screen when its box meets any view.
func _update_on_screen_views() -> void:
	var count: int = get_view_count()
	if _doze_views.size() != count:
		_doze_views.resize(count)
	for i: int in count:
		_doze_views[i] = get_view_rect_at(i)
	for entity: SimEntity in _awake:
		entity.on_screen = _box_in_views(entity)
	if not _doze_screen_pending.is_empty():
		for entity: SimEntity in _doze_screen_pending:
			if is_instance_valid(entity) and entity._sim_suspended:
				entity.on_screen = _box_in_views(entity)
		_doze_screen_pending.clear()


func _box_in_views(entity: SimEntity) -> bool:
	var feet: Vector2i = entity.sim_pos
	var box_left: int = feet.x - entity.box_xo
	for view: Rect2i in _doze_views:
		if box_left < view.position.x + view.size.x and view.position.x < box_left + entity.box_w \
				and feet.y - entity.box_h < view.position.y + view.size.y and view.position.y < feet.y:
			return true
	return false


## Start of every tick: when the view or the hero moved since the last doze decision (a respawn behind the curtain,
## a resized window), decide again before anything reads them. A party: any hero or any view.
func _on_tick_started(_tick: int) -> void:
	if not doze_enabled or _doze.is_empty():
		return
	if _hero_total > 1 or get_view_count() > 1:
		if _party_moved():
			_doze_update()
		return
	var hero: Vector2i = player.sim_pos if player != null else Vector2i(-1, -1)
	if hero != _doze_hero or get_view_rect() != _doze_view:
		_doze_update()


## A party: true when a hero or a view moved since the last doze decision.
func _party_moved() -> bool:
	if get_view_rect() != _doze_view:
		return true
	var count: int = get_view_count()
	for i: int in range(1, count):
		if i >= _doze_views.size() or get_view_rect_at(i) != _doze_views[i]:
			return true
	if _hero_total <= 1:
		var hero: Vector2i = player.sim_pos if player != null else Vector2i(-1, -1)
		return hero != _doze_hero
	var order: Array = _orders[0]
	if _doze_feet.size() != order.size() * 2:
		return true
	for k: int in order.size():
		var hero: PlayerBase = order[k]
		if hero.sim_pos.x != _doze_feet[k * 2] or hero.sim_pos.y != _doze_feet[k * 2 + 1]:
			return true
	return false


# =================================================================================================================
# Doze manager (ARCHITECTURE.md 11; the contract is in SimEntity, "Dozing")
# =================================================================================================================

## An entity's state changed so that it may doze now (or its area moved): look at it at the next decision.
func doze_note(entity: SimEntity) -> void:
	var slot: int = entity._doze_slot
	if slot < 0 or slot >= _doze.size() or _doze[slot] != entity:
		return
	_doze_known[slot] = 0
	_doze_notes.append(entity)


## Wake a dozing entity at once (its ticks matter again; also in the middle of a tick).
func doze_wake(entity: SimEntity) -> void:
	if entity._sim_suspended and entity._doze_slot >= 0:
		_doze_known[entity._doze_slot] = 0
		_doze_wake_entity(entity)


## Number of entities dozing now (diagnostics: the performance probe and the bench).
func get_dozing_count() -> int:
	var count: int = 0
	for entity: SimEntity in _doze:
		if entity._sim_suspended:
			count += 1
	return count


## Decide which entities doze: a full pass when a doze rectangle crossed a grid line (or after a respawn), else
## only the entities whose state changed. The two rectangles: the view grown by Tuning.DOZE_VIEW_REACH_PX and the
## hero's box and feet point grown by Tuning.DOZE_HERO_REACH_PX, each rounded outwards to Tuning.DOZE_GRID_PX. A
## party (or several views) adds one rectangle per further hero and view (`_dz_more`): an entity dozes only when it
## is far from all of them.
func _doze_update() -> void:
	var view: Rect2i = get_view_rect()
	_doze_view = view
	var grid: int = Tuning.DOZE_GRID_PX
	var mask: int = ~(grid - 1)
	var reach: int = Tuning.DOZE_VIEW_REACH_PX
	var view_left: int = (view.position.x - reach) & mask
	var view_top: int = (view.position.y - reach) & mask
	var view_right: int = (view.position.x + view.size.x + reach + grid - 1) & mask
	var view_bottom: int = (view.position.y + view.size.y + reach + grid - 1) & mask
	var hero_left: int = view_left
	var hero_top: int = view_top
	var hero_right: int = view_right
	var hero_bottom: int = view_bottom
	var first: PlayerBase = player
	if _hero_total > 1:
		first = _orders[0][0]
	if first != null:
		# first._doze_box() written out (box and feet point together): this runs at the end of every tick.
		var feet: Vector2i = first.sim_pos
		_doze_hero = feet
		var box_left: int = feet.x - first.box_xo
		var box_top: int = feet.y - first.box_h
		reach = Tuning.DOZE_HERO_REACH_PX
		hero_left = (mini(feet.x, box_left) - reach) & mask
		hero_top = (mini(feet.y, box_top) - reach) & mask
		hero_right = (maxi(feet.x + 1, box_left + maxi(first.box_w, 1)) + reach + grid - 1) & mask
		hero_bottom = (maxi(feet.y + 1, box_top + maxi(first.box_h, 1)) + reach + grid - 1) & mask
	else:
		_doze_hero = Vector2i(-1, -1)
	var more_changed: bool = false
	if _hero_total > 1 or get_view_count() > 1:
		more_changed = _doze_party_rects(first)
	elif _dz_more_count > 0:
		_dz_more_count = 0
		more_changed = true
	if _doze_full or more_changed or view_left != _dz_view_left or view_top != _dz_view_top \
			or view_right != _dz_view_right or view_bottom != _dz_view_bottom or hero_left != _dz_hero_left \
			or hero_top != _dz_hero_top or hero_right != _dz_hero_right or hero_bottom != _dz_hero_bottom:
		_doze_full = false
		_dz_view_left = view_left
		_dz_view_top = view_top
		_dz_view_right = view_right
		_dz_view_bottom = view_bottom
		_dz_hero_left = hero_left
		_dz_hero_top = hero_top
		_dz_hero_right = hero_right
		_dz_hero_bottom = hero_bottom
		_doze_notes.clear()
		_doze_full_pass()
		return
	if _doze_notes.is_empty():
		return
	var notes: Array[SimEntity] = _doze_notes.duplicate()
	_doze_notes.clear()
	for entity: SimEntity in notes:
		if is_instance_valid(entity) and entity._doze_slot >= 0:
			_doze_check(entity._doze_slot)


## Every entity against the doze rectangles, in slot order: exactly [method _doze_check] for each slot, with the
## common cases written out (the multi-hero performance pass of phase 3): a dozing entity that stays far and an awake
## one that stays near cost a few array reads instead of two calls. The far test is [method _doze_far] on locals
## (`_dz_more` is only read here). Everything else - an unknown area, a never-dozing area, a wake, a doze-off - goes
## through _doze_check / _doze_wake_entity as before, so the decisions and their order are the same.
func _doze_full_pass() -> void:
	var view_left: int = _dz_view_left
	var view_top: int = _dz_view_top
	var view_right: int = _dz_view_right
	var view_bottom: int = _dz_view_bottom
	var hero_left: int = _dz_hero_left
	var hero_top: int = _dz_hero_top
	var hero_right: int = _dz_hero_right
	var hero_bottom: int = _dz_hero_bottom
	var more: PackedInt32Array = _dz_more
	var more_end: int = _dz_more_count * 4
	for slot: int in _doze.size():
		if _doze_known[slot] == 0:
			_doze_check(slot)
			continue
		var k: int = slot * 4
		var left: int = _doze_rects[k]
		var right: int = _doze_rects[k + 2]
		if right <= left:
			_doze_check(slot)
			continue
		var top: int = _doze_rects[k + 1]
		var bottom: int = _doze_rects[k + 3]
		var far: bool = (right <= view_left or left >= view_right or bottom <= view_top or top >= view_bottom) \
				and (right <= hero_left or left >= hero_right or bottom <= hero_top or top >= hero_bottom)
		if far:
			var j: int = 0
			while j < more_end:
				if not (right <= more[j] or left >= more[j + 2] or bottom <= more[j + 1] or top >= more[j + 3]):
					far = false
					break
				j += 4
		var entity: SimEntity = _doze[slot]
		if entity._sim_suspended:
			if not far:
				_doze_wake_entity(entity)
		elif far:
			_doze_check(slot)


## The rectangles of the further views (1..) and heroes (all but `first`) into `_dz_more`, the feet points of every
## hero into `_doze_feet` and every view into `_doze_views`. Returns true when the rectangles changed.
func _doze_party_rects(first: PlayerBase) -> bool:
	var grid: int = Tuning.DOZE_GRID_PX
	var mask: int = ~(grid - 1)
	var views: int = get_view_count()
	var order: Array = _orders[0] if _hero_total > 1 else _no_heroes
	var needed: int = (maxi(views - 1, 0) + order.size()) * 4
	if _dz_scratch.size() < needed:
		_dz_scratch.resize(needed)
	if _doze_views.size() != views:
		_doze_views.resize(views)
	var n: int = 0
	var reach: int = Tuning.DOZE_VIEW_REACH_PX
	for i: int in views:
		var view: Rect2i = get_view_rect_at(i)
		_doze_views[i] = view
		if i == 0:
			continue
		_dz_scratch[n] = (view.position.x - reach) & mask
		_dz_scratch[n + 1] = (view.position.y - reach) & mask
		_dz_scratch[n + 2] = (view.position.x + view.size.x + reach + grid - 1) & mask
		_dz_scratch[n + 3] = (view.position.y + view.size.y + reach + grid - 1) & mask
		n += 4
	reach = Tuning.DOZE_HERO_REACH_PX
	if _doze_feet.size() != order.size() * 2:
		_doze_feet.resize(order.size() * 2)
	for k: int in order.size():
		var hero: PlayerBase = order[k]
		var feet: Vector2i = hero.sim_pos
		_doze_feet[k * 2] = feet.x
		_doze_feet[k * 2 + 1] = feet.y
		if hero == first:
			continue
		var box_left: int = feet.x - hero.box_xo
		var box_top: int = feet.y - hero.box_h
		_dz_scratch[n] = (mini(feet.x, box_left) - reach) & mask
		_dz_scratch[n + 1] = (mini(feet.y, box_top) - reach) & mask
		_dz_scratch[n + 2] = (maxi(feet.x + 1, box_left + maxi(hero.box_w, 1)) + reach + grid - 1) & mask
		_dz_scratch[n + 3] = (maxi(feet.y + 1, box_top + maxi(hero.box_h, 1)) + reach + grid - 1) & mask
		n += 4
	var changed: bool = n != _dz_more_count * 4
	if not changed:
		for j: int in n:
			if _dz_scratch[j] != _dz_more[j]:
				changed = true
				break
	if changed:
		_dz_more = _dz_scratch.slice(0, n)
		_dz_more_count = n / 4
	return changed


## True when the area in slot `slot` touches no doze rectangle.
func _doze_far(slot: int) -> bool:
	var k: int = slot * 4
	var left: int = _doze_rects[k]
	var top: int = _doze_rects[k + 1]
	var right: int = _doze_rects[k + 2]
	var bottom: int = _doze_rects[k + 3]
	if not ((right <= _dz_view_left or left >= _dz_view_right or bottom <= _dz_view_top or top >= _dz_view_bottom) \
			and (right <= _dz_hero_left or left >= _dz_hero_right or bottom <= _dz_hero_top or top >= _dz_hero_bottom)):
		return false
	for r: int in _dz_more_count:
		var j: int = r * 4
		if not (right <= _dz_more[j] or left >= _dz_more[j + 2] or bottom <= _dz_more[j + 1] or top >= _dz_more[j + 3]):
			return false
	return true


## One entity against the doze rectangles.
func _doze_check(slot: int) -> void:
	var entity: SimEntity = _doze[slot]
	var k: int = slot * 4
	if _doze_known[slot] == 0:
		_doze_store_area(slot, entity._doze_area())
	if _doze_rects[k + 2] <= _doze_rects[k]:
		if entity._sim_suspended:
			_doze_wake_entity(entity)
		return
	if entity._sim_suspended:
		if not _doze_far(slot):
			_doze_wake_entity(entity)
		return
	if not _doze_far(slot) or not entity._can_doze():
		return
	# The area the entity has right now (a cached one may be old), then off it goes.
	_doze_store_area(slot, entity._doze_area())
	if _doze_rects[k + 2] <= _doze_rects[k] or not _doze_far(slot):
		return
	entity._on_doze()
	if _doze_at_tick_end:
		# What the pass that follows would compute: the area is off the view.
		entity.on_screen = false
	elif entity.on_screen:
		_doze_screen_pending.append(entity)
	entity.sim_prev = entity.sim_pos
	Sim.suspend(entity)
	entity.set_process_internal(false)
	_awake_remove(entity)


func _doze_store_area(slot: int, area: Rect2i) -> void:
	var k: int = slot * 4
	_doze_known[slot] = 1
	if area.size.x <= 0 or area.size.y <= 0:
		_doze_rects[k] = 0
		_doze_rects[k + 1] = 0
		_doze_rects[k + 2] = 0
		_doze_rects[k + 3] = 0
		return
	_doze_rects[k] = area.position.x
	_doze_rects[k + 1] = area.position.y
	_doze_rects[k + 2] = area.end.x
	_doze_rects[k + 3] = area.end.y


func _doze_wake_entity(entity: SimEntity) -> void:
	Sim.resume(entity)
	entity.set_process_internal(true)
	if entity._level_awake_slot < 0:
		entity._level_awake_slot = _awake.size()
		_awake.append(entity)
	entity._on_doze_wake()


func _awake_remove(entity: SimEntity) -> void:
	var slot: int = entity._level_awake_slot
	if slot >= 0 and slot < _awake.size() and _awake[slot] == entity:
		var last: SimEntity = _awake[_awake.size() - 1]
		_awake[slot] = last
		last._level_awake_slot = slot
		_awake.resize(_awake.size() - 1)
	entity._level_awake_slot = -1


# =================================================================================================================
# PlayerSet internals
# =================================================================================================================

## A hero registered: he takes his slot (PlayerBase.slot); slot 0 is also `player` (1.0: the hero that registered
## last, which a party of one still is).
func _add_hero(hero: PlayerBase) -> void:
	var slot: int = clampi(hero.slot, 0, Defs.MAX_PLAYERS - 1)
	while heroes.size() <= slot:
		heroes.append(null)
	heroes[slot] = hero
	if slot == 0:
		player = hero
	_party_changed()


func _remove_hero(entity: SimEntity) -> void:
	var at: int = heroes.find(entity)
	if at < 0:
		return
	heroes[at] = null
	while not heroes.is_empty() and heroes[heroes.size() - 1] == null:
		heroes.resize(heroes.size() - 1)
	_party_changed()


## Count the heroes and build the contact orders (slot order and its rotations) once per change of the party.
func _party_changed() -> void:
	var present: Array[PlayerBase] = []
	for hero: PlayerBase in heroes:
		if hero != null:
			present.append(hero)
	_hero_total = present.size()
	_orders.clear()
	for r: int in present.size():
		var order: Array[PlayerBase] = []
		for k: int in present.size():
			order.append(present[(r + k) % present.size()])
		_orders.append(order)


## 2.0: `base` moved PartyTuning.RESPAWN_SPREAD_PX * `place` px towards the side where the floor continues (right
## first, then left), or `base` itself when neither side has a floor there (PHYSICS.md C.12) - the spread of the
## team-wipe respawn, also used for a party's gate travel. `place` <= 0 returns `base`.
func party_spread_point(base: Vector2i, place: int) -> Vector2i:
	return _spread_point(base, place)


## `base` moved PartyTuning.RESPAWN_SPREAD_PX * `slot` px towards the side where the floor continues (right first,
## then left), or `base` itself when neither side has a floor to stand on there (PHYSICS.md C.12).
func _spread_point(base: Vector2i, slot: int) -> Vector2i:
	if slot <= 0:
		return base
	var step: int = PartyTuning.RESPAWN_SPREAD_PX * slot
	if _stands_at(base.x + step, base.y):
		return Vector2i(base.x + step, base.y)
	if _stands_at(base.x - step, base.y):
		return Vector2i(base.x - step, base.y)
	return base


## True when a hero's feet at (x, y) would stand on a floor (not a hole, a hatch or a deadly tile) with free space
## above it, inside the level.
func _stands_at(x: int, y: int) -> bool:
	if x < Tuning.X_MIN or x >= grid.x_max_excl():
		return false
	var col: int = Tuning.to_cell(x)
	var row: int = Tuning.to_cell(y)
	var floor_value: int = grid.floor_at(col, row)
	if floor_value < TileGrid.FLOOR_SOLID or floor_value > TileGrid.FLOOR_ICE_3:
		return false
	return grid.side_at(col, row - 1) == TileGrid.SIDE_OPEN


## tick_time_limit() of a party: counts while any hero is alive, kills every living hero (slot order) at zero.
func _tick_party_time_limit() -> void:
	if time_left <= 0 or completed:
		return
	var alive: bool = false
	for hero: PlayerBase in _orders[0]:
		alive = alive or not hero.dead
	if not alive:
		return
	var before: int = get_time_left_seconds()
	time_left -= 1
	var after: int = get_time_left_seconds()
	if after != before:
		time_left_changed.emit(after)
		Events.time_left_changed.emit(after)
	if time_left == 0:
		for hero: PlayerBase in _orders[0].duplicate():
			if not hero.dead:
				hero.kill(&"time")

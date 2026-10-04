class_name Overlap
extends RefCounted
## The sprite-overlap test of PHYSICS.md 2.2, used for every sprite-versus-sprite contact in the game.
##
## CONTRACT FILE (docs/ARCHITECTURE.md 3.3). Owner: core. Do not replace it with Rect2i.intersects(), Area2D or
## any physics query: the asymmetries of this test (only the lower object's height, half width of the left-most
## box for body contacts, the stomp flag) are part of the original feel.
##
## Argument order matters ("A is the first argument"): the hero in hero-vs-enemy and hero-vs-platform tests,
## the item in item-vs-hero tests, the weapon box in weapon tests.

## Result of the last [method body] / [method test] call: true when the contact counts as a stomp (head bounce).
static var stomp: bool = false
## Result of the last body test: vertical penetration `high.y - top` in px (the hero is lifted by it on a bounce).
static var depth: int = 0


## Body-contact test between two entities (half width of the left-most box counts, stomp flag evaluated).
## `hero` is the entity whose yvel and identity drive the stomp flag: pass the hero when one of the two is the
## hero, or null for tests that do not involve him (the flag is then set by the top-half rule only).
static func body(a: SimEntity, b: SimEntity, hero: SimEntity = null) -> bool:
	return test(
		a.sim_pos.x, a.sim_pos.y, a.box_w, a.box_h, a.box_xo,
		b.sim_pos.x, b.sim_pos.y, b.box_w, b.box_h, b.box_xo,
		false,
		0 if hero == null else hero.yvel,
		1 if hero == a else (2 if hero == b else 0)
	)


## Weapon test (club box or thrown weapon against an enemy / boss): full widths, no stomp flag.
## `box` is the weapon rectangle in logical px (Rect2i(left, top, w, h)), `x_offset` its x_offset
## (origin.x - left; half the width for the club and the hammer).
static func weapon(box: Rect2i, x_offset: int, target: SimEntity) -> bool:
	return test(
		box.position.x + x_offset, box.position.y + box.size.y, box.size.x, box.size.y, x_offset,
		target.sim_pos.x, target.sim_pos.y, target.box_w, target.box_h, target.box_xo,
		true, 0, 0
	)


## Weapon test for an entity that is itself the weapon (a thrown axe) against a target.
static func weapon_entity(projectile: SimEntity, target: SimEntity) -> bool:
	return test(
		projectile.sim_pos.x, projectile.sim_pos.y, projectile.box_w, projectile.box_h, projectile.box_xo,
		target.sim_pos.x, target.sim_pos.y, target.box_w, target.box_h, target.box_xo,
		true, 0, 0
	)


## The raw test. A and B are given as feet point (x, y), width, height and x_offset.
## `weapon_test` selects the weapon variant. `hero_yvel` is the hero's vertical velocity (v16) and `hero_is`
## says which argument is the hero (1 = A, 2 = B, 0 = neither); both only matter for body tests.
## Sets [member stomp] and [member depth]; returns true on overlap.
static func test(
		ax: int, ay: int, aw: int, ah: int, axo: int,
		bx: int, by: int, bw: int, bh: int, bxo: int,
		weapon_test: bool = false, hero_yvel: int = 0, hero_is: int = 0
) -> bool:
	stomp = false
	depth = 0
	# 1. Coarse reject.
	if absi(ax - bx) >= Tuning.OVERLAP_MAX_DX or absi(ay - by) >= Tuning.OVERLAP_MAX_DY:
		return false
	# 2. Vertical: only the LOWER object's height matters. A is low on a tie.
	var a_is_low: bool = ay >= by
	var low_y: int = ay if a_is_low else by
	var low_h: int = ah if a_is_low else bh
	var high_y: int = by if a_is_low else ay
	var top: int = low_y - low_h
	if top >= high_y:
		return false
	# 3. Stomp flag (body tests only).
	if not weapon_test:
		depth = high_y - top
		var low_is_hero: bool = (hero_is == 1 and a_is_low) or (hero_is == 2 and not a_is_low)
		stomp = (hero_is != 0 and hero_yvel >= Tuning.STOMP_MIN_YVEL) or (depth <= low_h / 2 and not low_is_hero)
	# 4. Horizontal: the object whose left edge is further left (the low one on a tie) lends its width,
	#    halved for body contacts.
	var a_left: int = ax - axo
	var b_left: int = bx - bxo
	var a_is_leftmost: bool
	if a_left == b_left:
		a_is_leftmost = a_is_low
	else:
		a_is_leftmost = a_left < b_left
	var left: int = a_left if a_is_leftmost else b_left
	var other_left: int = b_left if a_is_leftmost else a_left
	var width: int = aw if a_is_leftmost else bw
	if not weapon_test:
		width = width / 2
	if left + width > other_left:
		return true
	stomp = false
	depth = 0
	return false


## Plain axis-aligned rectangle intersection, for zones and other non-original tests.
static func rects(a: Rect2i, b: Rect2i) -> bool:
	return a.position.x < b.position.x + b.size.x and b.position.x < a.position.x + a.size.x \
			and a.position.y < b.position.y + b.size.y and b.position.y < a.position.y + a.size.y


## True when the feet point (x, y) lies inside a rectangle given in logical px.
static func point_in(rect: Rect2i, x: int, y: int) -> bool:
	return x >= rect.position.x and x < rect.position.x + rect.size.x \
			and y >= rect.position.y and y < rect.position.y + rect.size.y

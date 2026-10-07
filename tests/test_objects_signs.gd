extends ObjectsTestCase
## Where `objects/sign` boards go (2.0, G1 follow-up; presentation only): a board never covers a hero, the HUD row or
## the HUD's co-op P2 panel, only one board shows at a time, and boards stay small (MAX_LINES). The pure geometry
## (SignBoard.plan_board) is tested on numbers; the boards of real signs with two heroes and a co-op HUD run through
## their _process. The look of a board (face, wrap, fade, banner) is the ui module's test_ui_signs.

## A 3-line board (view px) and the 640 x 360 view; the top limit under the HUD row.
const BOARD: Vector2 = Vector2(300.0, 80.0)
const VIEW: Vector2 = Vector2(640.0, 360.0)
const TOP: float = SignBoard.VIEW_TOP
## A standing hero's body (view px): the stand box (32 x 35 logical, x offset 15) at ART_SCALE 2.
const BODY_W: float = 64.0
const BODY_H: float = 70.0
const BODY_XO: float = 30.0
const NO_PANELS: Array[Rect2] = []

var p2: PlayerBase = null


func before_each() -> void:
	super.before_each()
	UiKit.ensure_locale()
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	Game.begin_level(&"test_objects")


func after_each() -> void:
	super.after_each()
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"")
	p2 = null


## The body of a hero standing with his feet at `feet` (view px).
func body(feet: Vector2) -> Rect2:
	return Rect2(feet.x - BODY_XO, feet.y - BODY_H, BODY_W, BODY_H)


func clear_of(rect: Rect2, bodies: Array[Rect2]) -> bool:
	for b: Rect2 in bodies:
		if rect.intersects(b.grow(SignBoard.HERO_ROOM)):
			return false
	return true


## The tail of a board at `rect` can point at the sign at `x` (it leaves the board TAIL_INSET from a corner at most).
func tail_reaches(rect: Rect2, x: float) -> bool:
	return x >= rect.position.x + SignBoard.TAIL_INSET - 0.5 and x <= rect.end.x - SignBoard.TAIL_INSET + 0.5


func inside_view(rect: Rect2, top: float = TOP) -> bool:
	return rect.position.x >= SignBoard.VIEW_EDGE - 0.5 and rect.end.x <= VIEW.x - SignBoard.VIEW_EDGE + 0.5 \
			and rect.position.y >= top - 0.5 and rect.end.y <= VIEW.y - SignBoard.VIEW_EDGE + 0.5


# =================================================================================================================
# The geometry (SignBoard.plan_board)
# =================================================================================================================

func test_a_free_board_stands_centred_above_its_sign() -> void:
	var sign: Vector2 = Vector2(320.0, 300.0)
	var reader: Array[Rect2] = [body(Vector2(310.0, 300.0))]
	var plan: SignBoard.BoardPlace = SignBoard.plan_board(sign, BOARD, VIEW, 1.0, TOP, NO_PANELS, reader)
	assert_eq(plan.place, SignBoard.Place.ABOVE)
	assert_almost_eq(plan.rect.get_center().x, sign.x, 0.5, "centred on the sign")
	assert_almost_eq(plan.rect.end.y, sign.y + SignBoard.BOARD_BOTTOM_ART, 0.5, "its bottom edge over the head")
	assert_true(clear_of(plan.rect, reader), "clear of the reader")
	assert_eq(plan.covered, 0.0)
	assert_true(inside_view(plan.rect))


## The G1 plates gate of 1-1 co-op: a sign near the top of the view. Above it the board would be pushed down over the
## reader (and the plate he explains); it hangs under the sign instead, its tail pointing up.
func test_a_sign_near_the_top_hangs_its_board_under_itself() -> void:
	var sign: Vector2 = Vector2(400.0, 130.0)
	var bodies: Array[Rect2] = [body(Vector2(396.0, 130.0)), body(Vector2(470.0, 130.0))]
	var plan: SignBoard.BoardPlace = SignBoard.plan_board(sign, BOARD, VIEW, 1.0, TOP, NO_PANELS, bodies)
	assert_eq(plan.place, SignBoard.Place.BELOW, "under the sign")
	assert_true(plan.rect.position.y >= sign.y, "below the sign's feet")
	assert_true(clear_of(plan.rect, bodies), "both heroes stay visible")
	assert_true(tail_reaches(plan.rect, sign.x))
	assert_true(inside_view(plan.rect))
	for place: int in [SignBoard.Place.ABOVE, SignBoard.Place.ABOVE_LEFT, SignBoard.Place.ABOVE_RIGHT]:
		assert_null(SignBoard.board_place(place, sign, BOARD, VIEW, 1.0, TOP, NO_PANELS, bodies),
				"above, the HUD row would push it down over the sign (place %d): no such place" % place)
	# Without the rule's last resort a board always has a place: a board taller than the whole room above and under
	# its sign stands clamped into the view.
	var huge: Vector2 = Vector2(BOARD.x, VIEW.y - TOP - 20.0)
	var squeezed: SignBoard.BoardPlace = SignBoard.plan_board(sign, huge, VIEW, 1.0, TOP, NO_PANELS, bodies)
	assert_not_null(squeezed, "never without a place")
	if squeezed != null:
		assert_eq(squeezed.place, SignBoard.Place.ABOVE)
		assert_true(inside_view(squeezed.rect), "clamped into the view: %s" % squeezed.rect)


## A sign so high that a standing board would be pushed under the sign's top by the HUD row or P2's panel (ui-B's
## test_a_board_never_covers_the_p2_panel, signs at x 240-308 logical, y 24-44): the board never stands below the sign
## with its tail pointing away from it - it hangs under the sign, below the panel with its tail (TAIL_HALF art px,
## scaled by the view).
func test_a_board_pushed_over_its_sign_hangs_under_it_clear_of_the_panel_and_its_tail() -> void:
	var panel: Rect2 = Rect2(464.0, 52.0, 168.0, 44.0)
	var big: Vector2 = Vector2(329.0, 76.0)
	for art: float in [1.0, 2.0]:
		var view: Vector2 = VIEW * art
		var scaled_panel: Rect2 = Rect2(panel.position * art, panel.size * art)
		for sign: Vector2 in [Vector2(616.0, 48.0), Vector2(616.0, 88.0), Vector2(560.0, 68.0), Vector2(480.0, 88.0),
				Vector2(200.0, 48.0)]:
			var at: Vector2 = sign * art
			var plan: SignBoard.BoardPlace = SignBoard.plan_board(at, big * art, view, art, TOP * art,
					[scaled_panel], [])
			assert_true(plan.place >= SignBoard.Place.BELOW, "art %.0f sign %s: hangs (place %d, %s)" % [
					art, sign, plan.place, plan.rect])
			assert_true(plan.rect.position.y > at.y, "under the sign")
			var tail: Rect2 = Rect2(clampf(at.x, plan.rect.position.x + SignBoard.TAIL_INSET * art,
					plan.rect.end.x - SignBoard.TAIL_INSET * art) - float(SignBoard.TAIL_HALF) * art,
					plan.rect.position.y - float(SignBoard.TAIL_HALF) * art, float(2 * SignBoard.TAIL_HALF) * art,
					float(SignBoard.TAIL_HALF) * art)
			assert_false(plan.rect.intersects(scaled_panel), "art %.0f sign %s: board %s off the panel" % [
					art, sign, plan.rect])
			assert_false(tail.intersects(scaled_panel), "art %.0f sign %s: tail %s off the panel" % [art, sign, tail])


## The partner on a ledge three rows over the sign: every place above covers him (the tail must point at the sign he
## stands over), so the board hangs under the sign.
func test_a_partner_over_the_sign_sends_the_board_under_it() -> void:
	var sign: Vector2 = Vector2(320.0, 240.0)
	var bodies: Array[Rect2] = [body(Vector2(316.0, 240.0)), body(Vector2(324.0, 240.0 - 96.0))]
	var plan: SignBoard.BoardPlace = SignBoard.plan_board(sign, BOARD, VIEW, 1.0, TOP, NO_PANELS, bodies)
	assert_eq(plan.place, SignBoard.Place.BELOW)
	assert_true(clear_of(plan.rect, bodies), "neither hero is covered")


## The partner on a ledge up and to the right: the board moves left of the sign (its tail still points at it).
func test_a_partner_beside_the_board_shifts_it_aside() -> void:
	var sign: Vector2 = Vector2(320.0, 240.0)
	var bodies: Array[Rect2] = [body(Vector2(316.0, 240.0)), body(Vector2(482.0, 150.0))]
	var plan: SignBoard.BoardPlace = SignBoard.plan_board(sign, BOARD, VIEW, 1.0, TOP, NO_PANELS, bodies)
	assert_eq(plan.place, SignBoard.Place.ABOVE_LEFT)
	assert_true(clear_of(plan.rect, bodies))
	assert_true(tail_reaches(plan.rect, sign.x), "the tail points at the sign: %s" % plan.rect)
	assert_true(plan.rect.end.y <= sign.y + SignBoard.BOARD_BOTTOM_ART + 0.5, "still above the sign")
	var mirrored: Array[Rect2] = [body(Vector2(324.0, 240.0)), body(Vector2(158.0, 150.0))]
	plan = SignBoard.plan_board(sign, BOARD, VIEW, 1.0, TOP, NO_PANELS, mirrored)
	assert_eq(plan.place, SignBoard.Place.ABOVE_RIGHT, "the partner up on the left: the board goes right")
	assert_true(clear_of(plan.rect, mirrored))
	assert_true(tail_reaches(plan.rect, sign.x))


## P2's HUD panel (top-right, under the letters; the versus corners alike): a board that lies under it keeps below
## it, in every place, its tail included (a hanging board's tail rises TAIL_HALF over its top edge); one that would
## lie over a panel in the lower half keeps above it.
func test_a_board_never_covers_the_party_panels_or_the_hud_row() -> void:
	var panel: Rect2 = Rect2(464.0, 52.0, 168.0, 44.0)
	var panels: Array[Rect2] = [panel]
	for sign: Vector2 in [Vector2(560.0, 130.0), Vector2(600.0, 200.0), Vector2(320.0, 100.0), Vector2(40.0, 60.0),
			Vector2(616.0, 48.0), Vector2(560.0, 68.0), Vector2(480.0, 88.0)]:
		for place: int in SignBoard.Place.size():
			var at: SignBoard.BoardPlace = SignBoard.board_place(place, sign, BOARD, VIEW, 1.0, TOP, panels, [])
			if at == null:
				continue
			var with_tail: Rect2 = at.rect
			if place >= SignBoard.Place.BELOW:
				with_tail = with_tail.grow_individual(0.0, float(SignBoard.TAIL_HALF), 0.0, 0.0)
			assert_false(with_tail.intersects(panel.grow(SignBoard.P2_PANEL_GAP - 0.5)),
					"sign %s place %d: %s (tail included) near the panel" % [sign, place, at.rect])
			assert_true(inside_view(at.rect), "sign %s place %d: %s inside the view under the row" % [
					sign, place, at.rect])
	var corners: Array[Rect2] = [Rect2(8.0, 300.0, 150.0, 52.0), Rect2(482.0, 300.0, 150.0, 52.0)]
	for sign: Vector2 in [Vector2(60.0, 330.0), Vector2(600.0, 250.0), Vector2(100.0, 200.0)]:
		for place: int in SignBoard.Place.size():
			var low: SignBoard.BoardPlace = SignBoard.board_place(place, sign, BOARD, VIEW, 1.0, TOP, corners, [])
			if low == null:
				continue
			for corner: Rect2 in corners:
				assert_false(low.rect.intersects(corner), "sign %s place %d: %s over a lower panel" % [
						sign, place, low.rect])


## A board keeps its place while it stays clear (no jumping back and forth while the heroes move); a covered one goes
## to the first clear place; when no place is clear it stays where it is (and fades, see the _process tests).
func test_a_board_keeps_its_place_while_it_stays_clear() -> void:
	var sign: Vector2 = Vector2(320.0, 240.0)
	var none: Array[Rect2] = []
	var plan: SignBoard.BoardPlace = SignBoard.plan_board(sign, BOARD, VIEW, 1.0, TOP, NO_PANELS, none,
			SignBoard.Place.BELOW)
	assert_eq(plan.place, SignBoard.Place.BELOW, "placed under the sign earlier: it stays there")
	var under: Array[Rect2] = [body(Vector2(330.0, 340.0))]
	plan = SignBoard.plan_board(sign, BOARD, VIEW, 1.0, TOP, NO_PANELS, under, SignBoard.Place.BELOW)
	assert_eq(plan.place, SignBoard.Place.ABOVE, "a hero behind it: the first clear place")
	var everywhere: Array[Rect2] = [body(Vector2(316.0, 240.0)), body(Vector2(324.0, 144.0)),
			body(Vector2(320.0, 330.0)), body(Vector2(100.0, 144.0)), body(Vector2(540.0, 144.0))]
	plan = SignBoard.plan_board(sign, BOARD, VIEW, 1.0, TOP, NO_PANELS, everywhere, SignBoard.Place.ABOVE_RIGHT)
	assert_eq(plan.place, SignBoard.Place.ABOVE_RIGHT, "nothing is clear: it stays")
	assert_true(plan.covered > 0.0)
	plan = SignBoard.plan_board(sign, BOARD, VIEW, 1.0, TOP, NO_PANELS, everywhere)
	for place: int in SignBoard.Place.size():
		var other: SignBoard.BoardPlace = SignBoard.board_place(place, sign, BOARD, VIEW, 1.0, TOP, NO_PANELS,
				everywhere)
		if other != null:
			assert_true(plan.covered <= other.covered, "the least covering place (%d)" % place)


## Every place keeps the board inside the view (a sign at a view edge, a sign under the HUD row, a sign at the
## bottom whose board cannot hang under it).
func test_every_place_stays_inside_the_view() -> void:
	for sign: Vector2 in [Vector2(10.0, 200.0), Vector2(630.0, 200.0), Vector2(320.0, 40.0), Vector2(320.0, 350.0)]:
		var fits: int = 0
		for place: int in SignBoard.Place.size():
			var at: SignBoard.BoardPlace = SignBoard.board_place(place, sign, BOARD, VIEW, 1.0, TOP, NO_PANELS, [])
			if at == null:
				# A hanging board near the bottom, a standing one the HUD row would push over a sign near the top.
				assert_true(place >= SignBoard.Place.BELOW if sign.y > VIEW.y * 0.5 else place < SignBoard.Place.BELOW,
						"sign %s: place %d may not fit" % [sign, place])
				continue
			fits += 1
			assert_true(inside_view(at.rect), "sign %s place %d: %s" % [sign, place, at.rect])
		assert_true(fits >= 3, "sign %s: three places fit" % sign)
	assert_null(SignBoard.board_place(SignBoard.Place.BELOW, Vector2(320.0, 350.0), BOARD, VIEW, 1.0, TOP,
			NO_PANELS, []), "no room under a sign at the bottom")


## Small boards: a short sign takes one line, the 1-1 club sign two or three, and the board wraps exactly as measured.
func test_boards_are_small_and_text_lines_measures_them() -> void:
	make_ground_level(80, 16, 10)
	add_hero(Vector2i(40, 160))
	assert_eq(SignBoard.text_lines(""), 0)
	assert_eq(SignBoard.text_lines("GO!"), 1)
	var long_text: String = "STAND ON A STONE PLATE TO HOLD ITS DOOR OPEN. HOLD ONE FOR YOUR PARTNER, THEN HE " \
			+ "HOLDS ONE FOR YOU!"
	assert_true(SignBoard.text_lines(long_text) > SignBoard.MAX_LINES, "a G1 text is too long for a small board")
	var x: int = 200
	for key: String in ["SIGN_W1_CLUB", "SIGN_W1_HOME", "SIGN_W1_BOUNCE", "SIGN_W1_VILLAGE"]:
		var sign: SignBoard = spawn(&"objects/sign", Vector2i(x, 160), {"text": key}) as SignBoard
		var label: Label = sign.get_node("Text") as Label
		var lines: int = SignBoard.text_lines(label.text)
		assert_eq(label.get_line_count(), lines, "%s: the board wraps as measured" % key)
		var line_h: float = label.get_theme_font(&"font").get_height(UiKit.SIZE_HUD)
		var tallest: float = float(lines) * (line_h + SignBoard.LINE_SPACING) + 2.0 * SignBoard.PAD_Y + 1.0
		assert_true(label.size.y <= tallest, "%s: %.0f px tall, at most %.0f" % [key, label.size.y, tallest])
		if key != "SIGN_W1_CLUB":
			assert_true(lines <= SignBoard.MAX_LINES, "%s: %d lines, a small board" % [key, lines])
		x += 150


# =================================================================================================================
# Real boards (_process): two heroes, two signs, a co-op HUD
# =================================================================================================================

## A ground level (row 10 down solid, feet y 160) with P1 (`hero`) and P2 (`p2`).
func party(x1: int, x2: int, cols: int = 60) -> void:
	make_ground_level(cols, 16, 10)
	add_hero(Vector2i(x1, 160))
	p2 = PlayerBase.new()
	place(level, p2, Vector2i(x2, 160), {"slot": 1})
	p2.respawn_at(Vector2i(x2, 160))


## Solid cells (set A) over a rectangle of the level.
func fill(col: int, row: int, w: int, h: int) -> void:
	for r: int in range(row, row + h):
		for c: int in range(col, col + w):
			level.set_cell(c, r, TileGrid.CH_SOLID_A)


func settle() -> void:
	await get_tree().create_timer(SignBoard.FADE_SECONDS + 0.15).timeout


func board_rect(sign: SignBoard) -> Rect2:
	return (sign.get_node("Text") as Label).get_global_rect()


## Two heroes at two signs (G1: two boards showed at once and covered each other): the board a hero came to last is
## in front, the other fades out; once that hero left, the board the other hero still stands at comes back.
func test_one_board_at_a_time_with_two_heroes() -> void:
	party(100, 20)
	var first: SignBoard = spawn(&"objects/sign", Vector2i(100, 160), {"text": "SIGN_W1_HOME"}) as SignBoard
	var second: SignBoard = spawn(&"objects/sign", Vector2i(200, 160), {"text": "SIGN_W1_CLUB"}) as SignBoard
	Sim.step(1)
	await settle()
	assert_true(first.is_board_shown(), "P1 reads the first sign")
	assert_false(second.is_board_shown())
	p2.teleport(Vector2i(200, 160))
	Sim.step(1)
	await settle()
	assert_true(second.is_board_shown(), "P2 came to the second sign last: in front")
	assert_false(first.is_board_shown(), "the first board gave way")
	p2.teleport(Vector2i(400, 160))
	Sim.step(1)
	await settle()
	await settle()
	assert_true(first.is_board_shown(), "P2 left: the board P1 still stands at is back in front")
	assert_false(second.is_board_shown(), "and the other one gave way")


## A solo hero walking on from a held board to the next sign sees only the new board.
func test_walking_on_to_the_next_sign_shows_only_its_board() -> void:
	make_ground_level(80, 16, 10)
	add_hero(Vector2i(100, 160))
	var first: SignBoard = spawn(&"objects/sign", Vector2i(100, 160), {"text": "SIGN_W1_HOME"}) as SignBoard
	var second: SignBoard = spawn(&"objects/sign", Vector2i(170, 160), {"text": "SIGN_W1_CLUB"}) as SignBoard
	Sim.step(1)
	await settle()
	assert_true(first.is_board_shown())
	hero.teleport(Vector2i(170, 160))
	Sim.step(1)
	await settle()
	assert_true(second.is_board_shown(), "the new sign's board")
	assert_false(first.is_board_shown(), "the held board is not shown beside it")


## The 1-1 co-op plates case with the real co-op HUD: a sign on a ledge near the top of the view, the reader at it
## and the partner beside him. The board hangs under the sign: clear of both heroes, the HUD row and P2's panel.
func test_a_real_board_keeps_clear_of_heroes_and_the_p2_panel() -> void:
	var hud: Hud = (load(Flow.HUD_SCENE) as PackedScene).instantiate() as Hud
	add_node(hud)
	await get_tree().process_frame
	assert_true(hud.get_p2_panel().visible, "the co-op HUD shows P2's panel")
	party(250, 290)
	fill(10, 4, 15, 1)
	hero.teleport(Vector2i(250, 64))
	p2.teleport(Vector2i(290, 64))
	var sign: SignBoard = spawn(&"objects/sign", Vector2i(254, 64), {"text": "SIGN_W1_BOUNCE"}) as SignBoard
	Sim.step(1)
	await settle()
	assert_true(sign.is_board_shown())
	var rect: Rect2 = board_rect(sign)
	var bodies: Array[Rect2] = SignBoard.hero_bodies()
	assert_eq(bodies.size(), 2, "both heroes count")
	assert_true(clear_of(rect, bodies), "no hero behind the board: %s / %s" % [rect, bodies])
	assert_false(sign.is_covering_a_hero())
	assert_false(rect.intersects(hud.get_p2_panel().get_global_rect()), "not over P2's panel")
	assert_true(rect.position.y >= SignBoard.VIEW_TOP - 0.5, "under the HUD row")
	assert_true(sign.get_board_place() >= SignBoard.Place.BELOW, "hanging under the sign")
	assert_almost_eq((sign.get_node("Text") as Label).modulate.a, 1.0, 0.001, "fully shown")


## A hero jumping through a board does not make it jump about: it fades to COVER_ALPHA while he is behind it and moves
## to a clear place only once he stayed there for MOVE_SECONDS.
func test_a_hero_behind_a_board_shows_through_then_the_board_moves() -> void:
	party(160, 20)
	var sign: SignBoard = spawn(&"objects/sign", Vector2i(160, 160), {"text": "SIGN_W1_HOME"}) as SignBoard
	Sim.step(1)
	await settle()
	assert_eq(sign.get_board_place(), SignBoard.Place.ABOVE)
	var rect: Rect2 = board_rect(sign)
	# P2 "in the air" inside the board's left part (bare heroes stay where they are put).
	var inside: Vector2 = Vector2(rect.position.x + 40.0, rect.end.y)
	p2.teleport(Vector2i(roundi(inside.x / Tuning.ART_SCALE), roundi(inside.y / Tuning.ART_SCALE)))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(sign.is_covering_a_hero(), "P2 is behind the board")
	assert_eq(sign.get_board_place(), SignBoard.Place.ABOVE, "it does not move at once")
	await get_tree().create_timer(SignBoard.MOVE_SECONDS + 0.1).timeout
	assert_eq(sign.get_board_place(), SignBoard.Place.ABOVE_RIGHT, "he stayed: the board moved right of the sign")
	assert_false(sign.is_covering_a_hero())
	assert_true(clear_of(board_rect(sign), SignBoard.hero_bodies()), "clear of both heroes")
	await settle()
	assert_almost_eq((sign.get_node("Text") as Label).modulate.a, 1.0, 0.001, "fully shown again")


## A sign at the bottom of the view (no room under it) with the partner right over it: no place is clear, so the board
## fades to COVER_ALPHA (he shows through) and stays put.
func test_a_board_with_no_clear_place_is_translucent() -> void:
	party(160, 160)
	# The sign 16 view px over the bottom edge: no room to hang the board under it.
	var y: int = (roundi(get_tree().root.get_visible_rect().size.y) - 16) / Tuning.ART_SCALE
	hero.teleport(Vector2i(160, y))
	p2.teleport(Vector2i(160, y - 60))
	var sign: SignBoard = spawn(&"objects/sign", Vector2i(160, y), {"text": "SIGN_W1_HOME"}) as SignBoard
	Sim.step(1)
	await get_tree().create_timer(SignBoard.FADE_SECONDS + SignBoard.MOVE_SECONDS + 0.2).timeout
	assert_true(sign.is_board_shown())
	assert_true(sign.get_board_place() < SignBoard.Place.BELOW, "no room under the sign")
	assert_true(sign.is_covering_a_hero(), "every place covers P2")
	assert_almost_eq((sign.get_node("Text") as Label).modulate.a, SignBoard.COVER_ALPHA, 0.001,
			"translucent: P2 shows through")

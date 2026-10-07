extends ObjectsTestCase
## ui module: the look of `objects/sign` boards (the rule of when they show is tested by test_objects_flow): a wooden
## board (ui/panel.png) with the text in the HUD face, wrapped into balanced lines, faded in near the sign, held
## for a read time after the hero left, kept inside the view, and never under the stage banner.


func before_each() -> void:
	super.before_each()
	UiKit.ensure_locale()
	make_ground_level(80, 16, 10)
	add_hero(Vector2i(100, 160))


func test_sign_board_is_a_wooden_board_in_the_hud_face() -> void:
	var sign: SignBoard = spawn(&"objects/sign", Vector2i(200, 160), {"text": "SIGN_W1_CLUB"}) as SignBoard
	var label: Label = sign.get_node("Text") as Label
	assert_eq(label.text, String(TranslationServer.translate("SIGN_W1_CLUB")), "the translated text")
	assert_ne(label.text, "SIGN_W1_CLUB")
	assert_eq(label.get_theme_font(&"font"), UiKit.font(UiKit.Style.HUD), "the HUD face")
	assert_eq(label.get_theme_color(&"font_color"), UiKit.COL_CREAM, "cream like the hint panel")
	var board: StyleBoxTexture = label.get_theme_stylebox(&"normal") as StyleBoxTexture
	assert_not_null(board, "a textured board")
	if board != null:
		assert_eq(board.texture.resource_path, UiKit.TEX_PANEL, "the wooden panel")
	assert_true(label.size.x <= SignBoard.TEXT_MAX_W + 2.0 * SignBoard.PAD_X + 1.0, "at most the widest line")
	assert_true(label.get_line_count() >= 2, "a long text wraps")
	assert_false(label.visible, "hidden while the hero is away")
	hero.teleport(Vector2i(196, 160))
	Sim.step(1)
	assert_true(label.visible, "shown at once when the hero comes near")
	await get_tree().create_timer(SignBoard.FADE_SECONDS + 0.15).timeout
	assert_almost_eq(label.modulate.a, 1.0, 0.001, "faded in")
	var rect: Rect2 = label.get_global_rect()
	var view: Rect2 = label.get_viewport_rect()
	assert_true(rect.position.x >= SignBoard.VIEW_EDGE - 0.5 and rect.end.x <= view.end.x - SignBoard.VIEW_EDGE + 0.5,
			"inside the view: %s in %s" % [rect, view])
	assert_true(rect.position.y >= SignBoard.VIEW_TOP - 0.5, "below the HUD row")
	var sign_screen: Vector2 = sign.get_global_transform_with_canvas().origin
	assert_true(rect.end.y < sign_screen.y, "above the sign")
	assert_true(rect.position.x < sign_screen.x and rect.end.x > sign_screen.x, "over the sign")
	hero.teleport(Vector2i(100, 160))
	Sim.step(1)
	await get_tree().create_timer(SignBoard.FADE_SECONDS + 0.15).timeout
	assert_true(label.visible and label.modulate.a > 0.99, "held for the read time after the hero left")
	await get_tree().create_timer(SignBoard.READ_SECONDS + SignBoard.FADE_SECONDS).timeout
	assert_false(label.visible, "faded out once the read time is over")


## A board that appears while the stage banner shows makes the banner give way (it never sits under the banner).
func test_a_board_makes_the_stage_banner_give_way() -> void:
	var hud: Hud = Hud.new()
	get_tree().root.add_child(hud)
	hud.show_intro(&"w1_l1")
	assert_true(hud.is_intro_visible(), "the banner shows")
	var sign: SignBoard = spawn(&"objects/sign", Vector2i(200, 160), {"text": "SIGN_W1_CLUB"}) as SignBoard
	hero.teleport(Vector2i(196, 160))
	Sim.step(1)
	await get_tree().create_timer(Hud.INTRO_DISMISS_SECONDS + 0.2).timeout
	assert_true(sign.is_board_shown(), "the board shows")
	assert_false(hud.is_intro_visible(), "the banner is gone")
	hud.queue_free()


## Co-op (G1 follow-up): a board never covers P2's heart panel top-right, wherever its sign stands - beside the panel
## at any height, under it, and so high that the board hangs under its sign (the tail included).
func test_a_board_never_covers_the_p2_panel() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	var hud: Hud = Hud.new()
	get_tree().root.add_child(hud)
	await get_tree().process_frame
	await get_tree().process_frame
	var panel_rect: Rect2 = hud.get_party_panel_rect(1)
	assert_true(panel_rect.size.x > 0.0, "co-op: P2's panel shows (%s)" % panel_rect)
	var view: Rect2 = get_tree().root.get_visible_rect()
	var right: int = int(view.size.x / float(Tuning.ART_SCALE))
	var checked: int = 0
	for x: int in [right - 12, right - 40, right - 80, right - 130]:
		for y: int in [24, 34, 44, 56, 72, 100, 160]:
			var sign: SignBoard = spawn(&"objects/sign", Vector2i(x, y), {"text": "SIGN_W1_CLUB"}) as SignBoard
			hero.teleport(Vector2i(x - 4, y))
			Sim.step(1)
			await get_tree().create_timer(SignBoard.FADE_SECONDS + 0.1).timeout
			if sign.is_board_shown():
				var label: Label = sign.get_node("Text") as Label
				var rect: Rect2 = label.get_global_rect()
				var sign_y: float = sign.get_global_transform_with_canvas().origin.y
				# The tail: a wedge TAIL_HALF tall at the sign's x, over the board's top edge when the board hangs
				# under its sign (SignBoard._draw_tail_up).
				var centre: float = clampf(roundf(-label.position.x), SignBoard.TAIL_INSET,
						label.size.x - SignBoard.TAIL_INSET)
				var tail: Rect2 = Rect2()
				if rect.position.y > sign_y:
					tail = Rect2(rect.position.x + centre - float(SignBoard.TAIL_HALF),
							rect.position.y - float(SignBoard.TAIL_HALF), float(2 * SignBoard.TAIL_HALF),
							float(SignBoard.TAIL_HALF))
				assert_false(rect.intersects(panel_rect),
						"sign at (%d, %d): its board %s covers P2's panel %s" % [x, y, rect, panel_rect])
				assert_false(tail.has_area() and tail.intersects(panel_rect),
						"sign at (%d, %d): the tail %s of its board pokes into P2's panel %s" % [x, y, tail, panel_rect])
				checked += 1
			sign.queue_free()
			hero.teleport(Vector2i(20, 160))
			Sim.step(1)
			await get_tree().process_frame
	assert_true(checked >= 20, "boards were shown (%d)" % checked)
	hud.queue_free()
	Game.new_game(Defs.Difficulty.BEGINNER)


## Every sign text of the language file fits a small board (SignBoard.MAX_LINES lines, objects-A's G1 follow-up):
## Book I's signs were shortened to three lines; designers' sub-catalogues keep to it as well (LEVEL_DESIGN.md).
func test_every_sign_text_of_en_po_fits_a_small_board() -> void:
	var catalogue: Translation = load("res://locale/en.po") as Translation
	assert_not_null(catalogue)
	if catalogue == null:
		return
	var checked: int = 0
	for key: StringName in catalogue.get_message_list():
		if not String(key).begins_with("SIGN_"):
			continue
		var text: String = String(catalogue.get_message(key))
		var lines: int = SignBoard.text_lines(text)
		assert_true(lines <= SignBoard.MAX_LINES, "%s takes %d lines: \"%s\"" % [key, lines, text])
		checked += 1
	assert_true(checked >= 20, "the Book I signs were checked (%d)" % checked)


## The HUD's rule for world text near a party panel (Hud.clear_of_panels, asked by the sign board): the shortest move
## that clears every panel by the gap and stays inside the view; a rect that covers no panel stays where it is.
func test_hud_moves_world_text_clear_of_the_party_panels() -> void:
	var view: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)
	var p2: Rect2 = Rect2(464.0, 52.0, 168.0, 44.0)
	var gap: float = Hud.PANEL_CLEAR_GAP
	var apart: Rect2 = Rect2(40.0, 60.0, 200.0, 80.0)
	assert_eq(Hud.clear_of(apart, [p2], view, gap), apart, "clear already: unchanged")
	var under: Rect2 = Hud.clear_of(Rect2(300.0, 60.0, 330.0, 120.0), [p2], view, gap)
	assert_false(under.intersects(p2.grow(gap - 0.01)), "moved off P2's panel: %s" % under)
	assert_eq(under.position.y, p2.end.y + gap, "below it: the shorter way")
	assert_eq(under.position.x, 300.0, "only down")
	var beside: Rect2 = Hud.clear_of(Rect2(440.0, 40.0, 40.0, 300.0), [p2], view, gap)
	assert_eq(beside.end.x, p2.position.x - gap, "a tall narrow rect slides left: the shorter way")
	# Four versus corner panels: a move off one never ends on another.
	var corners: Array[Rect2] = [Rect2(8.0, 6.0, 200.0, 32.0), Rect2(432.0, 6.0, 200.0, 32.0),
			Rect2(8.0, 322.0, 200.0, 32.0), Rect2(432.0, 322.0, 200.0, 32.0)]
	for start: Rect2 in [Rect2(180.0, 30.0, 260.0, 100.0), Rect2(180.0, 230.0, 260.0, 100.0),
			Rect2(190.0, 150.0, 30.0, 200.0)]:
		var moved: Rect2 = Hud.clear_of(start, corners, view, gap)
		for corner: Rect2 in corners:
			assert_false(moved.intersects(corner), "%s -> %s is clear of %s" % [start, moved, corner])
		assert_true(view.encloses(moved), "inside the view: %s" % moved)


## A sign at the right edge of the view keeps its board inside the view; the board is no longer centred on it.
func test_board_stays_inside_the_view_at_its_edge() -> void:
	var view: Rect2 = get_tree().root.get_visible_rect()
	var right_x: int = int(view.size.x / float(Tuning.ART_SCALE)) - 12
	var sign: SignBoard = spawn(&"objects/sign", Vector2i(right_x, 160), {"text": "SIGN_W3_LULL"}) as SignBoard
	var label: Label = sign.get_node("Text") as Label
	hero.teleport(Vector2i(right_x - 4, 160))
	Sim.step(1)
	await get_tree().create_timer(SignBoard.FADE_SECONDS + 0.15).timeout
	var rect: Rect2 = label.get_global_rect()
	assert_true(rect.end.x <= label.get_viewport_rect().end.x - SignBoard.VIEW_EDGE + 0.5, "inside: %s" % rect)
	var sign_screen: Vector2 = sign.get_global_transform_with_canvas().origin
	assert_true(rect.position.x + rect.size.x * 0.5 < sign_screen.x - 1.0, "moved left of the sign")

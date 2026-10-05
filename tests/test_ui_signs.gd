extends ObjectsTestCase
## ui module: the look of `objects/sign` boards (the rule of when they show is tested by test_objects_flow): a wooden
## board (ui/panel.png) with the text in the HUD face, wrapped into balanced lines, faded in near the sign and out
## after, and kept inside the view.


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
	assert_false(label.visible, "faded out after the hero left")


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

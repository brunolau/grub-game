extends TestCase
## ui module: the three gameplay overlays (HUD, touch controls, pause menu) react to Game / Events / input.


func before_each() -> void:
	# A screen of an earlier test file (versus scoreboard / results) may have left the menu clusters on.
	GameInput.set_menu_clusters(false)
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"test_example")


func after_each() -> void:
	Settings.set_value("controls/touch_always", false)
	GameInput.clear_touch()
	GameInput.reset_slots()
	GameInput.sample()
	GameInput.sample()
	Game.new_game(Defs.Difficulty.BEGINNER)


## A stand-in for world-B's referee: the numbers the versus HUD asks for (HudVersus class description).
class FakeReferee:
	extends RefCounted

	var stacks: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	var banks: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	var wins: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	var left: int = -1
	var length: int = 2185

	func stack_of(slot: int) -> int:
		return stacks[slot]

	func banked_of(slot: int) -> int:
		return banks[slot]

	func round_wins_of(slot: int) -> int:
		return wins[slot]

	func round_ticks_left() -> int:
		return left

	func round_length() -> int:
		return length


func test_hud_reflects_game_signals() -> void:
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	assert_true(hud.is_in_group(Defs.GROUP_HUD))
	assert_eq(hud.get_score_text(), "0000000")
	assert_eq(hud.get_lives_text(), "x%d" % Tuning.LIVES_START)
	Game.add_score(12340)
	assert_eq(hud.get_score_text(), "0012340")
	Game.add_lives(3)
	assert_eq(hud.get_lives_text(), "x%d" % (Tuning.LIVES_START + 3))
	assert_eq(hud.shown_hearts, Tuning.ENERGY_START)
	Game.lose_heart()
	assert_eq(hud.shown_hearts, Tuning.ENERGY_START - 1, "a lost heart is shown empty")
	Game.add_bones(2)
	assert_eq(hud.shown_bones, 2, "the bone fraction is shown")
	Game.collect_letter(0)
	Game.collect_letter(3)
	assert_eq(hud.shown_letters, 0b01001, "collected letters are lit")


func test_hud_shows_the_time_limit() -> void:
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	assert_false(hud.is_time_visible(), "no counter without a level time limit")
	Events.time_left_changed.emit(42)
	assert_true(hud.is_time_visible())
	assert_eq(hud.shown_time, 42)
	assert_eq(hud.get_time_text(), tr("UI_HUD_TIME").format({"seconds": 42}))
	assert_true(hud.get_time_text().contains("42"))
	Events.time_left_changed.emit(-1)
	assert_false(hud.is_time_visible(), "a level without a limit hides it")


func test_hud_blinks_the_completed_word() -> void:
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	for i: int in Tuning.LETTER_COUNT - 1:
		Game.collect_letter(i)
	Game.collect_letter(Tuning.LETTER_COUNT - 1)
	assert_eq(Game.letters, 0, "the word was completed and cleared")
	assert_eq(hud.shown_letters, 0b11111, "the HUD shows the whole word while it blinks")
	await get_tree().create_timer(Tuning.ticks_to_seconds(Tuning.LETTERS_BLINK_TICKS) + 0.2).timeout
	assert_eq(hud.shown_letters, 0, "after the blink the empty word is shown")


func test_hud_boss_bar_follows_the_boss() -> void:
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	assert_false(hud.is_boss_bar_visible(), "no boss bar outside boss fights")
	Events.boss_started.emit(null)
	assert_true(hud.is_boss_bar_visible())
	assert_eq(hud.boss_max_pips, Tuning.BOSS_BAR_MAX_PIPS)
	Events.boss_energy_changed.emit(null, 3, 6)
	assert_eq(hud.boss_pips, 3)
	assert_eq(hud.boss_max_pips, 6)
	Events.boss_defeated.emit(null)
	assert_false(hud.is_boss_bar_visible())
	Events.boss_energy_changed.emit(null, 2, 8)
	assert_true(hud.is_boss_bar_visible(), "an energy update shows the bar again")
	Events.level_respawned.emit()
	assert_false(hud.is_boss_bar_visible(), "a respawn resets the fight")


## The boss bar spans the boss's own hit points whatever their number: full at the start, and every hit shows at
## once (lit lost part, flash, shake) and shortens the fill while the window has a pixel per hit.
func test_boss_bar_spans_any_number_of_hit_points() -> void:
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	var bar: HudBossBar = hud.get_boss_bar()
	var full: int = int(HudBossBar.WINDOW.size.x)
	assert_eq(HudBossBar.fill_width(1, 100000), 1, "a last hit point always shows")
	assert_eq(HudBossBar.fill_width(0, 64), 0)
	for case: Vector2i in [Vector2i(24, 1), Vector2i(64, 25), Vector2i(150, 25), Vector2i(250, 25), Vector2i(1000, 1)]:
		var max_hp: int = case.x
		var power: int = case.y
		Events.boss_started.emit(null)
		Events.boss_energy_changed.emit(null, max_hp, max_hp)
		assert_true(hud.is_boss_bar_visible())
		assert_eq(hud.boss_max_hp, max_hp)
		assert_eq(bar.get_fill_width(), full, "%d hp: a full bar" % max_hp)
		assert_false(bar.is_showing_hit(), "no hit effect at the start")
		var hp: int = max_hp
		var hits: int = 0
		while hp > 0:
			var before: int = bar.get_fill_width()
			hp = maxi(hp - power, 0)
			hits += 1
			Events.boss_energy_changed.emit(null, hp, max_hp)
			assert_true(bar.is_showing_hit(), "%d hp, hit %d shows" % [max_hp, hits])
			if max_hp <= full * power:
				assert_true(bar.get_fill_width() < before, "%d hp, hit %d shortens the fill" % [max_hp, hits])
			else:
				assert_true(bar.get_fill_width() <= before)
		assert_eq(bar.get_fill_width(), 0, "%d hp: empty after the last hit" % max_hp)
		Events.boss_defeated.emit(null)
		assert_false(hud.is_boss_bar_visible(), "the fight is over")
	await get_tree().create_timer(HudBossBar.FINISH_HOLD + HudBossBar.FINISH_FADE + 0.2).timeout
	assert_false(bar.visible, "the bar has faded out")


## The real bosses of the campaign, as their levels set them up (hit points read at run time, so a retuned boss is
## covered): the bar starts full and every weapon hit shortens it until the last one empties it.
func test_boss_bar_follows_the_campaign_bosses() -> void:
	var cases: Array[Array] = [
		[Defs.Difficulty.BEGINNER, &"w2_l2b"], [Defs.Difficulty.EXPERT, &"w2_l2b"], [Defs.Difficulty.EXPERT, &"w4_l2b"],
	]
	for case: Array in cases:
		Game.new_game(int(case[0]))
		await _start_level(case[1])
		var hud: Hud = get_tree().get_first_node_in_group(Defs.GROUP_HUD) as Hud
		var bosses: Array[SimEntity] = Game.level.get_kind(Defs.Kind.BOSS) if Game.level != null else []
		assert_not_null(hud, "%s has a HUD" % case[1])
		assert_eq(bosses.size(), 1, "%s has its boss" % case[1])
		if hud == null or bosses.size() != 1:
			_leave_level()
			continue
		var boss: BossBase = bosses[0] as BossBase
		var bar: HudBossBar = hud.get_boss_bar()
		var label: String = "%s %s (%d hp)" % [Defs.difficulty_name(int(case[0])), case[1], boss.max_hp]
		boss.start_fight()
		assert_true(hud.is_boss_bar_visible(), label)
		assert_eq(hud.boss_max_hp, boss.max_hp, "%s: the bar spans the boss's own hit points" % label)
		assert_eq(bar.get_fill_width(), int(HudBossBar.WINDOW.size.x), "%s: full" % label)
		var power: int = 1 if boss.thrown_only else Tuning.WEAPON_POWER[Defs.Weapon.CLUB]
		var hits: int = 0
		while boss.hp > 0 and hits < 1000:
			var before: int = bar.get_fill_width()
			boss.apply_boss_hit(power)
			hits += 1
			assert_true(bar.get_fill_width() < before, "%s: hit %d shortens the bar" % [label, hits])
			assert_true(bar.is_showing_hit(), "%s: hit %d is shown" % [label, hits])
		assert_eq(bar.get_fill_width(), 0, "%s: empty after %d hits" % [label, hits])
		_leave_level()


## The HUD row fades while the hero is under it (the auto-scrolling shaft kills at the view's top edge, where the
## row would hide him) and comes back when he leaves it.
func test_hud_row_fades_while_the_hero_is_under_it() -> void:
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	await get_tree().process_frame
	assert_true(hud.is_under_row(10.0), "the top band is under the row")
	assert_false(hud.is_under_row(200.0), "the middle of the screen is not")
	assert_eq(hud.row_alpha, 1.0, "no hero: the row is fully visible")


func test_hud_shows_level_hints_on_a_panel() -> void:
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	assert_false(hud.is_hint_visible(), "no hint panel without a hint")
	var first: Node = Node.new()
	var second: Node = Node.new()
	add_node(first)
	add_node(second)
	Events.message_requested.emit(first, "ZONE_DEMO")
	assert_eq(hud.get_hint_text(), tr("ZONE_DEMO"), "the hint is a translation key")
	await get_tree().create_timer(Hud.HINT_FADE_SECONDS + 0.1).timeout
	assert_true(hud.is_hint_visible())
	assert_eq(hud.get_hint_shown_text(), tr("ZONE_DEMO"))
	Events.message_requested.emit(second, "Plain text works too")
	assert_eq(hud.get_hint_text(), "Plain text works too", "the newest hint wins")
	Events.message_requested.emit(first, "")
	assert_eq(hud.get_hint_text(), "Plain text works too", "withdrawing an older hint keeps the newer one")
	Events.message_requested.emit(first, "ZONE_DEMO")
	Events.message_requested.emit(first, "")
	assert_eq(hud.get_hint_text(), "Plain text works too", "back to the hint still asked for")
	second.free()
	assert_eq(hud.get_hint_text(), "", "the hint of a freed source is forgotten")
	await get_tree().create_timer(Hud.HINT_FADE_SECONDS + 0.1).timeout
	assert_false(hud.is_hint_visible(), "faded out")
	# The panel stays inside the view at the narrowest supported width and wraps long text.
	Events.message_requested.emit(first, "Club the ground - bonuses hide everywhere! Every single one of them.")
	await get_tree().create_timer(Hud.HINT_FADE_SECONDS + 0.1).timeout
	var label_rect: Rect2 = _hint_label_rect(hud)
	var view: Rect2 = hud.get_viewport_rect()
	assert_true(view.encloses(label_rect), "the hint text is inside the view: %s in %s" % [label_rect, view])
	assert_true(label_rect.size.x <= Hud.HINT_MAX_TEXT_W + 0.5, "long hints wrap")
	assert_true(label_rect.position.y >= Hud.HINT_TOP, "the hint sits under the HUD row")
	first.free()


func _hint_label_rect(hud: Hud) -> Rect2:
	var found: Array[Label] = []
	for node: Node in hud.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label.text == hud.get_hint_shown_text():
			found.append(label)
	assert_eq(found.size(), 1, "one hint label")
	return found[0].get_global_rect() if not found.is_empty() else Rect2()


## The belt icon right of P1's hearts shows what a Swap brings, only while a special is owned (DESIGN.md C.1 rule 5);
## a Book I solo run never fills the belt, so its HUD stays the 1.0 one.
func test_hud_belt_icon_shows_what_a_swap_brings() -> void:
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	assert_false(hud.is_belt_visible(), "no special: no icon")
	assert_eq(hud.hud_layout, Defs.GameMode.SINGLE)
	assert_false(hud.get_p2_panel().visible, "single-player: no P2 panel")
	assert_null(hud.get_versus())
	Game.runs[0].set_weapon(Defs.Weapon.AXE)
	Game.runs[0].set_belt(Defs.Weapon.CLUB)
	assert_true(hud.is_belt_visible(), "an axe in the hand: the club is what a swap brings")
	assert_eq(hud.shown_belt, Defs.Weapon.CLUB)
	Game.runs[0].swap_belt()
	assert_eq(hud.shown_belt, Defs.Weapon.AXE, "swapped: the axe waits on the belt")
	Game.runs[1].set_belt(Defs.Weapon.SPEAR)
	assert_eq(hud.shown_belt, Defs.Weapon.AXE, "another slot's belt is not P1's")
	Game.runs[0].set_belt(PlayerRun.BELT_EMPTY)
	assert_false(hud.is_belt_visible(), "nothing on the belt: hidden")
	Game.runs[0].set_belt(Defs.Weapon.HAMMER)
	Game.new_game(Defs.Difficulty.BEGINNER)
	assert_false(hud.is_belt_visible(), "a new run starts with an empty belt")


## Co-op (GAMEPLAY.md 13.9.9): P1's row as today plus his tag, P2's hearts and belt icon mirrored top-right under the
## letters, everything inside the view and clear of the 1.0 row.
func test_hud_coop_shows_p2_panel_mirrored_top_right() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	await get_tree().process_frame
	assert_eq(hud.hud_layout, Defs.GameMode.COOP)
	var panel: HudPlayerPanel = hud.get_p2_panel()
	assert_true(panel.visible, "P2's panel shows in co-op")
	assert_eq(panel.slot, 1)
	assert_eq(panel.get_tag().text, "P2")
	assert_eq(panel.shown_hearts, Tuning.ENERGY_START)
	assert_eq(hud.get_lives_text(), "x%d" % Tuning.LIVES_START, "tribe lives where they are today")
	Game.runs[1].lose_heart()
	assert_eq(panel.shown_hearts, Tuning.ENERGY_START - 1, "P2 lost a heart")
	assert_eq(hud.shown_hearts, Tuning.ENERGY_START, "P1's hearts are his own")
	Game.runs[1].add_bones(2)
	assert_eq(panel.shown_bones, 2)
	assert_false(panel.is_belt_visible())
	Game.runs[1].set_belt(Defs.Weapon.SPEAR)
	assert_true(panel.is_belt_visible(), "P2's belt icon")
	assert_eq(panel.shown_belt, Defs.Weapon.SPEAR)
	assert_false(hud.is_belt_visible(), "P1 owns no special")
	var view: Rect2 = hud.get_viewport_rect()
	var rect: Rect2 = panel.get_global_rect()
	assert_true(view.encloses(rect), "inside the view: %s" % rect)
	assert_true(rect.position.x > view.size.x * 0.5, "on the right")
	assert_true(rect.position.y >= Hud.P2_TOP, "under the letters")
	assert_true(rect.end.x >= view.size.x - float(UiKit.MARGIN) - 1.0, "against the right margin")
	# Mirrored: the tag on the outer (right) side, the belt icon on the inner side.
	assert_true(panel.get_tag().get_global_rect().position.x > rect.get_center().x, "tag outside")
	var hero: PlayerBase = PlayerBase.new()
	hero.slot = 1
	Events.hero_down.emit(hero, &"pit")
	assert_true(panel.hero_down, "P2 is an egg: his panel greys")
	Events.hero_revived.emit(hero, null)
	assert_false(panel.hero_down)
	hero.free()
	Game.new_game(Defs.Difficulty.BEGINNER)
	assert_false(panel.visible, "back to single-player: the 1.0 HUD")


## A hero off the view gets an arrow in his colour at the nearest edge; while the co-op leash counts, a stone counts
## the seconds down to the egg (5..1 Beginner, 3..1 Expert). A party of one gets none.
func test_hud_edge_arrows_follow_heroes_off_the_view() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	var level: LevelBase = make_flat_level(80, 30, 20)
	var p1: PlayerBase = PlayerBase.new()
	place(level, p1, Vector2i(100, 160), {"slot": 0})
	var p2: PlayerBase = PlayerBase.new()
	place(level, p2, Vector2i(150, 160), {"slot": 1})
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	var arrows: HudEdgeArrows = hud.get_edge_arrows()
	arrows.level_override = level
	await get_tree().process_frame
	arrows.update_markers()
	assert_true(arrows.visible)
	assert_eq(arrows.markers.size(), 0, "both on the view: no arrow")
	assert_eq(arrows.tags.size(), 2, "the stage has just started: both heroes wear their P1 / P2 tags")
	arrows.show_tags(0.0)
	arrows.update_markers()
	assert_eq(arrows.tags.size(), 0, "later: no tags while they stand apart")
	p2.teleport(p1.sim_pos + Vector2i(4, 0))
	await get_tree().process_frame
	arrows.update_markers()
	assert_eq(arrows.tags.size(), 2, "two heroes overlap: both tags show")
	if arrows.tags.size() == 2:
		assert_true(arrows.tags[0]["pos"].y < float(p1.sim_pos.y * Tuning.ART_SCALE), "over the head")
	var view: Rect2 = hud.get_viewport_rect()
	p2.teleport(Vector2i(int(view.size.x / float(Tuning.ART_SCALE)) + 60, 160))
	await get_tree().process_frame
	arrows.update_markers()
	assert_eq(arrows.markers.size(), 1, "P2 is off the right edge")
	var marker: Dictionary = arrows.markers[0] if not arrows.markers.is_empty() else {}
	assert_eq(int(marker.get("slot", -1)), 1)
	assert_eq(int(marker.get("side", -1)), UiPlayers.Side.RIGHT)
	assert_true(view.has_point(marker.get("pos", Vector2(-1.0, -1.0))), "the arrow is on the view")
	assert_eq(int(marker.get("digit", -1)), 0, "no leash counted yet: no stone")
	p2.leash = 30
	arrows.update_markers()
	assert_eq(int(arrows.markers[0]["digit"]), 4, "Beginner: 121 ticks, 91 left = 4 s")
	p2.leash = PartyTuning.LEASH_EGG_TICKS_BEGINNER - 1
	arrows.update_markers()
	assert_eq(int(arrows.markers[0]["digit"]), 1, "the last second")
	Game.difficulty = Defs.Difficulty.EXPERT
	p2.leash = 1
	arrows.update_markers()
	assert_eq(int(arrows.markers[0]["digit"]), 3, "Expert counts from 3")
	Game.difficulty = Defs.Difficulty.BEGINNER
	p2.teleport(Vector2i(150, -80))
	await get_tree().process_frame
	arrows.update_markers()
	assert_eq(int(arrows.markers[0]["side"]), UiPlayers.Side.UP, "above the view")
	p2.teleport(Vector2i(150, 160))
	await get_tree().process_frame
	arrows.update_markers()
	assert_eq(arrows.markers.size(), 1, "back on the screen but the leash still counts")
	assert_eq(int(arrows.markers[0]["side"]), -1, "...so the stone hangs over his head")
	p2.leash = 0
	p2.dead = true
	arrows.update_markers()
	assert_eq(arrows.markers.size(), 0, "a dead hero gets no marker")
	p2.dead = false
	p2.teleport(Vector2i(-200, 160))
	p2.down = true
	await get_tree().process_frame
	arrows.update_markers()
	assert_eq(arrows.markers.size(), 0, "an egg follows his partner: no marker")
	p2.down = false
	p2.free()
	arrows.update_markers()
	assert_eq(arrows.markers.size(), 0, "a party of one: no arrows")


## Versus (Grub Stack): the campaign rows give way to four corner panels, the sundial and the round banners.
func test_hud_versus_corner_panels_sundial_and_banners() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, 4)
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	await get_tree().process_frame
	assert_eq(hud.hud_layout, Defs.GameMode.VERSUS)
	var versus: HudVersus = hud.get_versus()
	assert_not_null(versus)
	if versus == null:
		return
	var score: Label = _label_with_text(hud, hud.get_score_text())
	assert_true(score != null and not score.is_visible_in_tree(), "no campaign score in versus")
	var view: Rect2 = hud.get_viewport_rect()
	var corners: Array[Vector2] = []
	for slot: int in 4:
		var panel: HudVersus.CornerPanel = versus.get_panel(slot)
		assert_not_null(panel, "P%d has a panel" % (slot + 1))
		if panel == null:
			continue
		var rect: Rect2 = panel.get_global_rect()
		assert_true(view.encloses(rect), "P%d inside the view" % (slot + 1))
		corners.append(rect.get_center())
	if corners.size() == 4:
		assert_true(corners[0].x < view.size.x * 0.5 and corners[0].y < view.size.y * 0.5, "P1 top-left")
		assert_true(corners[1].x > view.size.x * 0.5 and corners[1].y < view.size.y * 0.5, "P2 top-right")
		assert_true(corners[2].x < view.size.x * 0.5 and corners[2].y > view.size.y * 0.5, "P3 bottom-left")
		assert_true(corners[3].x > view.size.x * 0.5 and corners[3].y > view.size.y * 0.5, "P4 bottom-right")
	var dial: HudVersus.Sundial = versus.get_sundial()
	assert_true(absf(dial.get_global_rect().get_center().x - view.size.x * 0.5) <= 1.0, "the sundial top centre")
	var referee: FakeReferee = FakeReferee.new()
	referee.stacks = PackedInt32Array([3, 12, 0, 27])
	referee.banks = PackedInt32Array([5, 0, 9, 1])
	referee.wins = PackedInt32Array([1, 0, 2, 0])
	referee.left = 1000
	versus.source = referee
	Game.runs[3].set_weapon(Defs.Weapon.HAMMER)
	Game.runs[3].set_belt(Defs.Weapon.CLUB)
	versus.refresh()
	assert_eq(versus.get_panel(1).get_stack_text(), "12")
	assert_eq(versus.get_panel(3).get_stack_text(), "27")
	assert_eq(versus.get_panel(2).get_banked_text(), "9")
	assert_eq(versus.get_panel(2).wins, 2)
	assert_eq(versus.get_panel(3).belt, Defs.Weapon.HAMMER, "the held special")
	assert_eq(versus.get_panel(0).belt, PlayerRun.BELT_EMPTY)
	assert_almost_eq(dial.elapsed, 1.0 - 1000.0 / 2185.0, 0.001, "the shadow sweeps with the round")
	assert_eq(dial.get_text(), "0:%02d" % ceili(Tuning.ticks_to_seconds(1000) - 0.0001))
	Events.round_countdown.emit(0, 3)
	assert_eq(versus.banner_text, "3", "3, 2, 1 ...")
	Events.round_countdown.emit(0, 0)
	assert_eq(versus.banner_text, tr("UI_VS_GO"), "... GRUB!")
	Events.round_started.emit(0)
	assert_true(versus.round_running)
	Events.round_feast_rush_started.emit(0)
	versus.refresh()
	assert_true(dial.rush, "the Feast Rush turns the sundial red")
	assert_eq(versus.banner_text, tr("UI_VS_FEAST_RUSH"))
	Events.round_ended.emit(0, PackedInt32Array([1]))
	assert_false(versus.round_running)
	assert_true(versus.banner_text.contains("P2"), "P2 won: %s" % versus.banner_text)
	assert_true(versus.is_banner_visible())
	Events.round_ended.emit(1, PackedInt32Array([0, 2]))
	assert_true(versus.banner_text.contains("P1") and versus.banner_text.contains("P3"), "a shared (team) win")
	Events.round_ended.emit(2, PackedInt32Array())
	assert_eq(versus.banner_text, tr("UI_VS_DRAW"))
	# Without a referee the round clock counts itself from round_started.
	versus.source = null
	Events.round_started.emit(3)
	versus.refresh()
	assert_eq(versus.ticks_left, VersusTuning.stack_round_ticks(4), "a whole round left")
	assert_almost_eq(dial.elapsed, 0.0, 0.001)
	assert_eq(versus.get_panel(1).get_stack_text(), "0", "no referee: nothing on the heads")


## Two players: only their two panels.
func test_hud_versus_shows_only_the_players_of_the_match() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, 2)
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	var versus: HudVersus = hud.get_versus()
	assert_not_null(versus.get_panel(0))
	assert_not_null(versus.get_panel(1))
	assert_null(versus.get_panel(2), "no P3 in a match of two")
	assert_eq(HudVersus.result_text(PackedInt32Array([3])), tr("UI_VS_ROUND_WIN").format({"player": "P4"}))
	# The colours are the ones the heroes wear: P4's green turns white on a jungle arena (hero_palettes.json).
	assert_eq(UiPlayers.palette_of(3), &"green")
	if Levels.has_level(&"test_world_arena_flat"):
		Game.begin_level(&"test_world_arena_flat")
		assert_eq(UiPlayers.palette_of(3), &"white", "jungle arena: P4 in white")
		assert_eq(UiPlayers.palette_of(1), &"blue")
	Game.runs[1].palette = &"gold"
	assert_eq(UiPlayers.palette_of(1), &"gold", "the colour chosen in the lobby")
	Game.runs[1].palette = &""


func _label_with_text(root: Node, text: String) -> Label:
	for node: Node in root.find_children("*", "Label", true, false):
		if (node as Label).text == text:
			return node as Label
	return null


func test_touch_controls_feed_game_input_with_multi_touch() -> void:
	var touch: TouchControls = await _overlay(Flow.TOUCH_SCENE) as TouchControls
	assert_true(touch.is_in_group(Defs.GROUP_TOUCH))
	Settings.set_value("controls/touch_always", true)
	assert_true(touch.visible, "the setting shows the overlay without a touch screen")
	var left: Vector2 = touch.get_button_rect(Defs.ACT_LEFT).get_center()
	var jump: Vector2 = touch.get_button_rect(Defs.ACT_JUMP).get_center()
	_touch(0, left, true)
	_touch(1, jump, true)
	assert_true(touch.is_button_held(Defs.ACT_LEFT))
	assert_true(touch.is_button_held(Defs.ACT_JUMP), "two fingers at once")
	var flags: int = GameInput.sample()
	assert_eq(flags & (Defs.IN_LEFT | Defs.IN_UP), Defs.IN_LEFT | Defs.IN_UP)
	_drag(0, touch.get_button_rect(Defs.ACT_RIGHT).get_center())
	assert_false(touch.is_button_held(Defs.ACT_LEFT), "sliding a finger releases the old button")
	assert_true(touch.is_button_held(Defs.ACT_RIGHT), "...and presses its neighbour")
	flags = GameInput.sample()
	assert_eq(flags & (Defs.IN_LEFT | Defs.IN_RIGHT), Defs.IN_RIGHT)
	_touch(0, touch.get_button_rect(Defs.ACT_RIGHT).get_center(), false)
	_touch(1, jump, false)
	assert_false(touch.is_button_held(Defs.ACT_RIGHT))
	assert_false(touch.is_button_held(Defs.ACT_JUMP))
	GameInput.sample()
	assert_eq(GameInput.sample() & (Defs.IN_RIGHT | Defs.IN_UP), 0, "released buttons stop feeding the game")


func test_touch_controls_follow_layout_and_pause() -> void:
	var touch: TouchControls = await _overlay(Flow.TOUCH_SCENE) as TouchControls
	Settings.set_value("controls/touch_always", true)
	var view: Vector2 = touch.size
	assert_true(touch.get_button_rect(Defs.ACT_LEFT).position.x < view.x * 0.5, "d-pad on the left")
	assert_true(touch.get_button_rect(Defs.ACT_JUMP).position.x > view.x * 0.5, "jump on the right")
	for action: StringName in [Defs.ACT_LEFT, Defs.ACT_JUMP, Defs.ACT_PAUSE]:
		assert_true(Rect2(Vector2.ZERO, view).encloses(touch.get_button_rect(action)), "inside the view")
		assert_true(touch.get_button_rect(action).size.x >= float(UiKit.TOUCH_TARGET), "touch target size")
	Settings.set_value(OptionsPanel.KEY_TOUCH_LAYOUT, "swapped")
	assert_true(touch.get_button_rect(Defs.ACT_LEFT).position.x > view.x * 0.5, "mirrored layout")
	Settings.set_value(OptionsPanel.KEY_TOUCH_LAYOUT, "standard")
	Settings.set_value("controls/touch_opacity", 0.4)
	assert_almost_eq(touch.modulate.a, 0.4, 0.001)
	Settings.set_value("controls/touch_opacity", Settings.DEFAULTS["controls/touch_opacity"])
	_touch(0, touch.get_button_rect(Defs.ACT_LEFT).get_center(), true)
	Events.pause_changed.emit(true)
	assert_false(touch.visible, "hidden while the pause menu is open")
	assert_false(touch.is_button_held(Defs.ACT_LEFT), "pausing lifts every finger")
	Events.pause_changed.emit(false)
	assert_true(touch.visible)


func test_pause_menu_shows_and_resumes() -> void:
	var menu: PauseMenu = await _overlay(Flow.PAUSE_SCENE) as PauseMenu
	assert_false(menu.visible, "hidden until the game pauses")
	Events.pause_changed.emit(true)
	assert_true(menu.visible)
	assert_eq(menu.page, PauseMenu.Page.MAIN)
	menu.open_options()
	assert_eq(menu.page, PauseMenu.Page.OPTIONS)
	_press(&"ui_cancel")
	assert_eq(menu.page, PauseMenu.Page.MAIN, "back leaves the options page")
	assert_true(menu.visible)
	_press(&"ui_cancel")
	assert_false(menu.visible, "back on the main page resumes")


func test_pause_menu_resume_unpauses_the_level() -> void:
	var menu: PauseMenu = await _overlay(Flow.PAUSE_SCENE) as PauseMenu
	Flow.current_screen = Flow.SCREEN_LEVEL
	Flow.set_paused(true)
	assert_true(menu.visible, "Flow's pause opens the menu")
	_press(&"ui_accept")
	assert_false(Flow.is_paused(), "the focused 'resume' entry unpauses")
	assert_false(menu.visible)
	Flow.current_screen = Flow.SCREEN_BOOT


func test_pause_menu_gamepad_start_confirms_the_focused_entry() -> void:
	var menu: PauseMenu = await _overlay(Flow.PAUSE_SCENE) as PauseMenu
	Flow.current_screen = Flow.SCREEN_LEVEL
	Flow.set_paused(true)
	assert_true(menu.visible)
	menu._options_button.grab_focus()
	_pad(JOY_BUTTON_START)
	assert_eq(menu.page, PauseMenu.Page.OPTIONS, "Start confirmed 'options' instead of resuming")
	assert_true(Flow.is_paused(), "the game stays paused")
	_press(&"ui_cancel")
	assert_eq(menu.page, PauseMenu.Page.MAIN)
	menu._resume.grab_focus()
	_pad(JOY_BUTTON_START)
	assert_false(Flow.is_paused(), "Start on 'resume' resumes")
	assert_false(menu.visible)
	_pad(JOY_BUTTON_START)
	assert_true(Flow.is_paused(), "in play Start pauses")
	Flow.set_paused(false)
	Flow.current_screen = Flow.SCREEN_BOOT


func test_pause_menu_give_up_needs_a_hero() -> void:
	var menu: PauseMenu = await _overlay(Flow.PAUSE_SCENE) as PauseMenu
	Events.pause_changed.emit(true)
	menu.restart_from_checkpoint()
	assert_true(menu.visible, "without a running level nothing happens")
	Events.pause_changed.emit(false)
	assert_false(menu.visible)


## Pause per slot (DESIGN.md D.11): in a party the menu is the pausing player's - his tag in his colour, his own
## cluster drives it (classic P2: Num 8 / Num 5 move, Num 0 confirms, Num . goes back), the other half's keys do not,
## and Options opens on his binding profile.
func test_pause_menu_belongs_to_the_player_who_paused() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	GameInput.assign_slot(0, InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT))
	GameInput.assign_slot(1, InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_RIGHT))
	var menu: PauseMenu = await _overlay(Flow.PAUSE_SCENE) as PauseMenu
	Flow.pause_slot = 1
	Events.pause_changed.emit(true)
	assert_true(menu.visible)
	assert_eq(menu.slot, 1, "the menu is P2's")
	assert_eq(menu.get_slot_text(), tr("UI_PAUSE_BY").format({"player": "P2"}))
	await get_tree().process_frame
	var first: Control = get_viewport().gui_get_focus_owner()
	assert_not_null(first, "an entry has the focus")
	_slot_key(KEY_KP_5)
	var second: Control = get_viewport().gui_get_focus_owner()
	assert_true(second != null and second != first, "Num 5 (P2's down) moved the focus")
	_slot_key(KEY_KP_8)
	assert_eq(get_viewport().gui_get_focus_owner(), first, "Num 8 (P2's up) moved it back")
	_slot_key(KEY_S)
	assert_eq(get_viewport().gui_get_focus_owner(), first, "P1's S does not drive P2's menu")
	_slot_key(KEY_KP_PERIOD)
	assert_false(menu.visible, "Num . (P2's look) is back: the game resumes")
	Flow.pause_slot = 1
	Events.pause_changed.emit(true)
	menu.open_options()
	assert_eq(menu.page, PauseMenu.Page.OPTIONS)
	assert_eq(_options_of(menu).bind_profile, 1, "Options edit P2's buttons")
	_slot_key(KEY_KP_PERIOD)
	assert_eq(menu.page, PauseMenu.Page.MAIN, "Num . left the options page")
	Events.pause_changed.emit(false)
	Flow.pause_slot = 0


## Joining and leaving from the pause menu (DESIGN.md D.1, Flow's join / leave / lost pads): a second player joins with
## his Jump (here P2's Num 0 of the classic layout), a co-op player leaves, a lost pad offers "continue alone". The
## 2.0 entries come after the 1.0 ones.
func test_pause_menu_joins_and_leaves_players() -> void:
	Settings.set_value(Settings.PARTY_KEYBOARD_KEY, "classic")
	var menu: PauseMenu = await _overlay(Flow.PAUSE_SCENE) as PauseMenu
	Events.pause_changed.emit(true)
	assert_eq(menu.get_party_entries(), PackedStringArray(["join"]), "one player: a second may join")
	menu.open_join()
	assert_eq(menu.page, PauseMenu.Page.JOIN)
	_slot_key(KEY_KP_0)
	assert_eq(Flow.party_size(), 2, "Num 0 joined a second player")
	assert_eq(GameInput.get_slot(1).kind, Defs.InputSlotKind.KEYBOARD_RIGHT, "P2 on the numpad")
	assert_eq(GameInput.get_slot(0).kind, Defs.InputSlotKind.KEYBOARD_LEFT, "P1 keeps the keyboard, left half")
	assert_false(menu.visible, "the menu gives way to the restart of the stage")
	# Co-op: the player who paused may leave.
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	Flow.pause_slot = 1
	Events.pause_changed.emit(true)
	assert_eq(menu.get_party_entries(), PackedStringArray(["leave"]), "a full co-op party: no join, a leave")
	menu.leave_game()
	assert_eq(GameInput.get_slot(1).kind, Defs.InputSlotKind.NONE, "P2 left")
	# A lost pad: reconnect it, or continue alone.
	GameInput.assign_slot(1, InputSlot.pad(7))
	Flow.notify_pad_connection(7, false)
	assert_eq(Flow.lost_pad_slots(), PackedInt32Array([1]))
	Events.pause_changed.emit(true)
	assert_true(menu.get_party_entries().has("alone"))
	assert_true(menu.get_lost_pad_text().contains("P2"), "names the player: %s" % menu.get_lost_pad_text())
	menu.continue_alone()
	assert_eq(Flow.lost_pad_slots(), PackedInt32Array())
	assert_false(menu.get_party_entries().has("alone"))
	assert_eq(menu.get_lost_pad_text(), "")
	Events.pause_changed.emit(false)
	Flow.pause_slot = 0
	Settings.reset()


## Single-player keeps the 1.0 pause menu: no player line, the keys keep their 1.0 meaning, Options edit the
## single-player buttons.
func test_pause_menu_in_single_player_is_the_1_0_menu() -> void:
	var menu: PauseMenu = await _overlay(Flow.PAUSE_SCENE) as PauseMenu
	Events.pause_changed.emit(true)
	assert_eq(menu.slot, 0)
	assert_eq(menu.get_slot_text(), "", "no 'P1 paused' line")
	await get_tree().process_frame
	var first: Control = get_viewport().gui_get_focus_owner()
	_slot_key(KEY_KP_5)
	assert_eq(get_viewport().gui_get_focus_owner(), first, "the numpad is no menu key in single-player")
	menu.open_options()
	assert_eq(_options_of(menu).bind_profile, OptionsPanel.PROFILE_SOLO)
	Events.pause_changed.emit(false)


## The Y stone is Swap (DESIGN.md C.1): absent from Book I solo (the 1.0 overlay), present where the belt counts,
## feeding IN_SWAP through GameInput.set_touch_slot.
func test_touch_controls_swap_stone_where_the_belt_counts() -> void:
	var touch: TouchControls = await _overlay(Flow.TOUCH_SCENE) as TouchControls
	Settings.set_value("controls/touch_always", true)
	assert_false(TouchControls.swap_wanted(), "Book I solo (test_example) ignores Swap")
	assert_eq(touch.get_button_rect(Defs.ACT_SWAP), Rect2(), "no Y stone in Book I solo")
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 1)
	assert_true(TouchControls.swap_wanted(), "a party uses the belt")
	var swap: Rect2 = touch.get_button_rect(Defs.ACT_SWAP)
	assert_ne(swap, Rect2(), "the Y stone shows")
	var view: Rect2 = Rect2(Vector2.ZERO, touch.size)
	assert_true(view.encloses(swap), "inside the view")
	assert_true(swap.size.x >= float(UiKit.TOUCH_TARGET), "a full touch target")
	for other: StringName in [Defs.ACT_JUMP, Defs.ACT_ATTACK, Defs.ACT_LOOK, Defs.ACT_PAUSE, Defs.ACT_UP]:
		assert_false(swap.intersects(touch.get_button_rect(other)), "the Y stone clear of %s" % other)
	_touch(0, swap.get_center(), true)
	assert_true(touch.is_button_held(Defs.ACT_SWAP))
	assert_eq(GameInput.sample() & Defs.IN_SWAP, Defs.IN_SWAP, "the stone swaps")
	_touch(0, swap.get_center(), false)
	GameInput.sample()
	assert_eq(GameInput.sample() & Defs.IN_SWAP, 0)


## Table mode (the D.11 tablet prototype): two touch slots, P1's cluster along the bottom, P2's turned half a circle
## along the top, each feeding only its own slot.
func test_touch_controls_table_mode_gives_each_player_a_cluster() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, 2)
	var regions: Array[Rect2] = TouchControls.table_regions()
	GameInput.assign_slot(0, InputSlot.touch(regions[0]))
	GameInput.assign_slot(1, InputSlot.touch(regions[1]))
	var touch: TouchControls = await _overlay(Flow.TOUCH_SCENE) as TouchControls
	touch.refresh_slots()
	assert_true(touch.table_mode)
	assert_true(touch.visible, "touch slots show the overlay")
	var view: Vector2 = touch.size
	for action: StringName in [Defs.ACT_LEFT, Defs.ACT_JUMP, Defs.ACT_ATTACK, Defs.ACT_SWAP]:
		var mine: Rect2 = touch.get_button_rect(action, 0)
		var theirs: Rect2 = touch.get_button_rect(action, 1)
		assert_true(mine.get_center().y > view.y * 0.5, "P1's %s along the bottom" % action)
		assert_true(theirs.get_center().y < view.y * 0.5, "P2's %s along the top" % action)
		assert_true(Rect2(Vector2.ZERO, view).encloses(theirs), "inside the view")
		assert_false(touch.is_button_flipped(action, 0))
		assert_true(touch.is_button_flipped(action, 1), "turned for the player across the table")
		assert_true(theirs.size.x >= float(UiKit.TOUCH_TARGET), "56 art px stones")
	assert_true(touch.get_button_rect(Defs.ACT_LEFT, 1).get_center().x > view.x * 0.5,
			"P2's d-pad is under his left hand: on the right of the screen")
	_touch(0, touch.get_button_rect(Defs.ACT_JUMP, 1).get_center(), true)
	_touch(1, touch.get_button_rect(Defs.ACT_LEFT, 0).get_center(), true)
	GameInput.sample()
	assert_eq(GameInput.get_flags(1) & (Defs.IN_UP | Defs.IN_LEFT), Defs.IN_UP, "P2's jump feeds P2 only")
	assert_eq(GameInput.get_flags(0) & (Defs.IN_UP | Defs.IN_LEFT), Defs.IN_LEFT, "P1's left feeds P1 only")
	_touch(0, touch.get_button_rect(Defs.ACT_JUMP, 1).get_center(), false)
	_touch(1, touch.get_button_rect(Defs.ACT_LEFT, 0).get_center(), false)
	_touch(2, touch.get_button_rect(Defs.ACT_JUMP, 1).get_center(), true)
	_drag(2, touch.get_button_rect(Defs.ACT_LEFT, 0).get_center())
	assert_false(touch.is_button_held(Defs.ACT_LEFT, 0), "a finger never slides from P2's stones onto P1's d-pad")
	assert_false(touch.is_button_held(Defs.ACT_JUMP, 1), "... it let go of the stone it left")
	touch.release_all()
	assert_true(TouchControls.table_regions()[0].intersection(TouchControls.table_regions()[1]).size.y <= 0.0,
			"the two regions do not overlap")


func _options_of(menu: PauseMenu) -> OptionsPanel:
	for node: Node in menu.find_children("*", "OptionsPanel", true, false):
		return node as OptionsPanel
	return null


## A physical key press and release as the OS delivers it (through Input, then dispatched to the nodes).
func _slot_key(physical: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = physical
		event.keycode = physical
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		Input.flush_buffered_events()


## Enter `level_id` through Flow like the game does (HUD included), with the clock under the test's control.
func _start_level(level_id: StringName) -> void:
	Sim.manual = true
	await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame
	Flow.start_level(level_id, Defs.Transition.NONE)
	for i: int in 3:
		await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL, "%s started" % level_id)


func _leave_level() -> void:
	Sim.manual = false
	Sim.stop()
	if get_tree().current_scene != null:
		get_tree().current_scene.free()
		get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT


func _overlay(path: String) -> Control:
	var node: Control = (load(path) as PackedScene).instantiate() as Control
	add_node(node)
	await get_tree().process_frame
	return node


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = pressed
		get_tree().root.push_input(event)


func _pad(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventJoypadButton = InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		get_tree().root.push_input(event)


func _touch(finger: int, pos: Vector2, pressed: bool) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = finger
	event.position = pos
	event.pressed = pressed
	get_tree().root.push_input(event)


func _drag(finger: int, pos: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = finger
	event.position = pos
	get_tree().root.push_input(event)

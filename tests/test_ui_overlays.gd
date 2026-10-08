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
	var leader: int = -1

	func stack_of(slot: int) -> int:
		return stacks[slot]

	func leader_slot() -> int:
		return leader

	func banked_of(slot: int) -> int:
		return banks[slot]

	func round_wins_of(slot: int) -> int:
		return wins[slot]

	func round_ticks_left() -> int:
		return left

	func round_length() -> int:
		return length


## The referee of the other launch modes (world-B's VersusReferee reading API): the mode, the ember's holder, the
## round score (Clubball: the side's goals; Last Caveman Standing: the hearts), the Stock lives and the round phase.
class FakeModeReferee:
	extends FakeReferee

	var mode: int = Defs.VersusMode.GRUB_STACK
	var phase: int = VersusReferee.PHASE_PLAY
	var rules: VersusRules = VersusRules.new()
	var holder: int = -1
	var scores: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	var stocks: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])

	func ember_holder() -> int:
		return holder

	func score_of(slot: int) -> int:
		return scores[slot]

	func stocks_of(slot: int) -> int:
		return stocks[slot]


## A level's party driver for the tags test: it only tells the stacks (VersusStackDisplay's towers).
class FakeDriver:
	extends SimEntity

	var stacks: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])

	func stack_of(slot: int) -> int:
		return stacks[slot]

	func leader_slot() -> int:
		return -1


const LEVEL_SCENE: String = "res://scenes/world/level.tscn"
const TOTEM_RING: StringName = &"arena_totem_ring"


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


## A boss weak point for the fight-band tests: a boss whose head is wherever the test puts it (logical px).
class BandBoss:
	extends BossBase

	var head: Rect2i = Rect2i()

	func get_head_rect() -> Rect2i:
		return head


## The fight band (phase 3, Hud.BAND_HEIGHT): in a co-op boss fight the bonus letters give way and P2's panel moves
## up into their row, so the HUD keeps to the top BAND_HEIGHT px (plus the boss bar); his Rival-score line waits; after
## the fight everything goes back. In solo the letters stay (they lie inside the band).
func test_hud_coop_fight_band() -> void:
	Settings.set_value(OptionsPanel.KEY_RIVAL_SCORE, true)
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	await get_tree().process_frame
	var panel: HudPlayerPanel = hud.get_p2_panel()
	assert_true(panel.get_global_rect().position.y >= Hud.P2_TOP, "outside a fight: under the letters")
	assert_true(panel.score_shown, "the Rival score line under his hearts")
	Events.boss_started.emit(null)
	assert_true(hud.fight_layout, "a boss bar shows: the fight band")
	hud._process(Hud.ROW_FADE_SECONDS + 0.01)
	await get_tree().process_frame
	var band_bottom: float = hud.get_row_bottom()
	assert_true(panel.get_global_rect().end.y <= band_bottom + 0.5,
			"P2's panel in the letters' row: %s, band bottom %d" % [panel.get_global_rect(), int(band_bottom)])
	assert_almost_eq(hud.letters_alpha, 0.0, 0.001, "the letters gave way")
	assert_true(panel.visible, "P2's hearts stay in sight")
	assert_false(panel.score_shown, "his Rival-score line waits for the end of the fight")
	var view: Vector2 = hud.get_viewport_rect().size
	for rect: Rect2 in Hud.band_rects(view, true, true, true, Hud.BAND_MARGIN_DESKTOP):
		assert_true(rect.end.y <= Hud.BAND_MARGIN_DESKTOP + Hud.BOSS_TOP + HudBossBar.FRAME_SIZE.y + 0.5,
				"the fight band: the row and the boss bar only (%s)" % rect)
	Events.level_respawned.emit()
	hud._process(Hud.ROW_FADE_SECONDS + 0.01)
	await get_tree().process_frame
	assert_false(hud.fight_layout)
	assert_true(panel.get_global_rect().position.y >= Hud.P2_TOP, "after the fight: back under the letters")
	assert_almost_eq(hud.letters_alpha, 1.0, 0.001, "the letters are back")
	assert_true(panel.score_shown, "and the Rival score line")
	# Solo: the letters stay in a fight.
	Game.new_game(Defs.Difficulty.BEGINNER)
	Events.boss_started.emit(null)
	hud._process(Hud.ROW_FADE_SECONDS + 0.01)
	assert_true(hud.fight_layout)
	assert_almost_eq(hud.letters_alpha, 1.0, 0.001, "solo: the letters stay")
	Events.level_respawned.emit()
	Settings.set_value(OptionsPanel.KEY_RIVAL_SCORE, false)


## A fighting boss's weak point behind the HUD fades what covers it (the row, P2's co-op panel, the boss bar), like a
## hero under the row; it comes back once the weak point moved away. Weak points come from the boss's own methods
## (Hud.weak_point_rects: head, rump, face, weak spot; the Twin Idols' head of each idol).
func test_hud_fades_over_a_boss_weak_point() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	await get_tree().process_frame
	var boss: BandBoss = BandBoss.new()
	boss.sim_pos = Vector2i(160, 150)
	boss.sim_prev = boss.sim_pos
	add_node(boss)
	boss.fighting = true
	boss.head = Rect2i(150, 140, 20, 10)
	Events.boss_started.emit(boss)
	await get_tree().process_frame
	assert_eq(Hud.weak_point_rects(boss), [Rect2i(150, 140, 20, 10)] as Array[Rect2i])
	var on_screen: Array[Rect2] = hud.boss_weak_rects_on_screen()
	assert_eq(on_screen.size(), 1)
	assert_eq(on_screen[0], Rect2(300.0, 280.0, 40.0, 20.0), "logical px -> screen px")
	hud._process(Hud.ROW_FADE_SECONDS + 0.01)
	assert_eq(hud.row_alpha, 1.0, "a weak point low in the view: nothing fades")
	# Up under the letters' row (top-right): the row fades.
	var view: Vector2 = hud.get_viewport_rect().size
	boss.head = Rect2i(int(view.x * 0.5 / float(Tuning.ART_SCALE)) + 120, 4, 20, 10)
	hud._process(Hud.ROW_FADE_SECONDS + 0.01)
	assert_almost_eq(hud.row_alpha, Hud.ROW_UNDER_HERO_ALPHA, 0.001, "the row fades over the weak point")
	# Behind the boss bar: the bar fades too.
	var bar: Rect2 = hud.get_boss_bar_rect()
	boss.head = Rect2i(int(bar.get_center().x / float(Tuning.ART_SCALE)) - 5, int(bar.get_center().y / 2.0) - 3, 10, 6)
	hud._process(Hud.ROW_FADE_SECONDS + 0.01)
	assert_almost_eq(hud.get_boss_bar().self_modulate.a, Hud.BOSS_UNDER_HERO_ALPHA, 0.001, "the bar fades")
	boss.head = Rect2i(150, 140, 20, 10)
	hud._process(Hud.ROW_FADE_SECONDS + 0.01)
	assert_eq(hud.row_alpha, 1.0, "back when the weak point moved away")
	assert_eq(hud.get_boss_bar().self_modulate.a, 1.0)
	Events.boss_defeated.emit(boss)
	assert_eq(hud.boss_weak_rects_on_screen().size(), 0, "no fight, no weak point")


## The band rule designers check their arenas with (Hud.weak_point_problem): a weak point inside the view at least
## WEAK_POINT_CLEARANCE px below the fight band passes; one under the row, under the boss bar or cut off by the view
## fails. The numbers hold on every device (the touch margin).
func test_weak_point_band_rule() -> void:
	var view: Vector2 = Vector2(640.0, 360.0)
	var row_bottom: float = Hud.BAND_MARGIN_TOUCH + Hud.BAND_HEIGHT
	var clear_top: float = row_bottom + Hud.WEAK_POINT_CLEARANCE
	assert_eq(Hud.weak_point_problem(Rect2(560.0, clear_top, 40.0, 40.0), view), "", "right wall, clear of the row")
	assert_ne(Hud.weak_point_problem(Rect2(560.0, clear_top - 1.0, 40.0, 40.0), view), "", "1 px too high")
	assert_ne(Hud.weak_point_problem(Rect2(560.0, 20.0, 40.0, 40.0), view), "", "under the letters")
	var bar_bottom: float = Hud.BAND_MARGIN_TOUCH + Hud.BOSS_TOP + HudBossBar.FRAME_SIZE.y
	assert_ne(Hud.weak_point_problem(Rect2(310.0, clear_top, 20.0, 20.0), view), "", "under the boss bar's column")
	assert_eq(Hud.weak_point_problem(Rect2(310.0, bar_bottom + Hud.WEAK_POINT_CLEARANCE, 20.0, 20.0), view), "")
	assert_ne(Hud.weak_point_problem(Rect2(630.0, 200.0, 20.0, 20.0), view), "", "cut off by the view's edge")
	assert_eq(Hud.weak_point_problem(Rect2(700.0, clear_top, 40.0, 40.0), Vector2(800.0, 360.0)), "", "a wide view")
	# In logical px (DESIGN.md G35, Tuning.ART_SCALE 2): 24 px of clearance; a weak point's top 55 px under the view
	# top clears the row, 72 px the boss bar's columns.
	assert_eq(Hud.WEAK_POINT_CLEARANCE, 24.0 * float(Tuning.ART_SCALE))
	assert_eq(int(ceilf(clear_top / float(Tuning.ART_SCALE))), 55)
	assert_eq(int(ceilf((bar_bottom + Hud.WEAK_POINT_CLEARANCE) / float(Tuning.ART_SCALE))), 72)


## Boss stages whose weak point still breaks the band rule, with the request that fixes it (the test reports them and
## says when they are clear, so the entry can go). Book I's solo boss stages keep their 1.0 framing (frozen files):
## reported, never failed. Empty since D6's 11-row chamber lock of w6_l2b landed (03:20, MANGROVE_FACE_RISE 70: the
## face's top 55 px under the view's top); w6_l2b_coop is asserted as soon as it lands.
const BAND_OPEN: Dictionary = {}
const BAND_FROZEN: Array[StringName] = [&"w2_l2b", &"w4_l2b"]


## The band rule on every boss stage that exists (solo and co-op files; new ones are picked up as they land): the
## heroes walk into the boss's arena, the camera settles on its lock, the fight starts, and every weak point of the
## boss lies inside the view at least WEAK_POINT_CLEARANCE px below the fight band (Hud.weak_point_problem, the touch
## margin) - at the start of the fight, where the arena puts it.
func test_boss_stages_keep_weak_points_clear_of_the_hud() -> void:
	var ids: Array[StringName] = []
	for level_id: StringName in Levels.all_ids():
		if not Levels.get_level_kind(level_id) in ["main", "sub", "coop"]:
			continue
		if FileAccess.get_file_as_string(Levels.get_level_path(level_id)).contains("\nbosses/"):
			ids.append(level_id)
	ids.sort()
	assert_true(ids.has(&"w5_l2b") and ids.has(&"w6_l2b"), "the Book II boss stages are found (%s)" % [ids])
	var report: PackedStringArray = PackedStringArray()
	for level_id: StringName in ids:
		var coop: bool = Levels.get_level_kind(level_id) == "coop"
		Game.start_run(Defs.Difficulty.EXPERT, Defs.GameMode.COOP if coop else Defs.GameMode.SINGLE, 2 if coop else 1,
				Levels.get_book(level_id))
		await _start_level(level_id)
		var bosses: Array[SimEntity] = Game.level.get_kind(Defs.Kind.BOSS) if Game.level != null else []
		if bosses.is_empty():
			report.append("%s: no boss" % level_id)
			_leave_level()
			continue
		var boss: BossBase = bosses[0] as BossBase
		_walk_into_arena(boss)
		# The game's base view (the test window's own size differs), the camera placed around the party at once.
		if Game.level.has_method(&"set_view_size"):
			Game.level.call(&"set_view_size", Vector2i(Tuning.VIEW_W, Tuning.VIEW_H) * Tuning.ART_SCALE)
		for tick: int in 120:
			Sim.step(1)
		if not boss.fighting:
			boss.start_fight()
		Sim.step(2)
		var view: Rect2i = Game.level.get_view_rect()
		var view_art: Vector2 = Vector2(view.size) * float(Tuning.ART_SCALE)
		var problems: PackedStringArray = PackedStringArray()
		var weak_rects: Array[Rect2i] = Hud.weak_point_rects(boss)
		if weak_rects.is_empty():
			# Nothing open at the fight's start (the bosses return an empty rect while a part cannot be struck): the
			# parts that open later, where the arena holds them.
			for method: StringName in [&"get_face_box", &"get_head_box"]:
				if boss.has_method(method) and (boss.call(method) as Rect2i).has_area():
					weak_rects.append(boss.call(method) as Rect2i)
		for weak: Rect2i in weak_rects:
			var art: Rect2 = Rect2(Vector2(weak.position - view.position) * float(Tuning.ART_SCALE),
					Vector2(weak.size) * float(Tuning.ART_SCALE))
			var problem: String = Hud.weak_point_problem(art, view_art)
			if problem != "":
				problems.append(problem)
		var verdict: String = "; ".join(problems)
		if problems.is_empty():
			verdict = "nothing open at the fight's start (the route checks cover it)"
			if not weak_rects.is_empty():
				verdict = "clear (%d weak rect(s))" % weak_rects.size()
		report.append("%s (%s): %s" % [level_id, boss.get_script().resource_path.get_file(), verdict])
		if BAND_FROZEN.has(level_id):
			pass
		elif BAND_OPEN.has(level_id):
			if problems.is_empty():
				print("    %s is clear now: remove it from BAND_OPEN" % level_id)
		else:
			assert_true(problems.is_empty(), "%s: the boss's weak point keeps clear of the HUD band: %s" % [level_id,
					verdict])
		_leave_level()
	for line: String in report:
		print("    band: %s" % line)
	Game.new_game(Defs.Difficulty.BEGINNER)


## Put the party into `boss`'s arena (zones/arena named by its `arena`, else 6 tiles before the boss), standing on the
## first floor under the arena's middle, so the camera takes the arena's lock.
func _walk_into_arena(boss: BossBase) -> void:
	var level: LevelBase = Game.level
	var target: Vector2i = boss.sim_pos - Vector2i(6 * Tuning.TILE, 2 * Tuning.TILE)
	for node: Node in get_tree().get_nodes_in_group(Defs.GROUP_SIM):
		var zone: SimEntity = node as SimEntity
		if zone == null or str(zone.spawn_params.get("name", "")) != String(boss.arena) \
				or not zone.spawn_params.has("rect"):
			continue
		var parts: PackedStringArray = str(zone.spawn_params["rect"]).split(",")
		if parts.size() == 4:
			var col: int = parts[0].to_int() + parts[2].to_int() / 2
			if absi(col * Tuning.TILE - boss.sim_pos.x) < 3 * Tuning.TILE:
				col = parts[0].to_int() + parts[2].to_int() / 4
			target = Vector2i(col * Tuning.TILE + Tuning.TILE / 2, (parts[1].to_int() + 1) * Tuning.TILE)
	var col_x: int = target.x / Tuning.TILE
	for row: int in range(target.y / Tuning.TILE, level.grid.rows):
		if TileGrid.is_ground(level.grid.floor_at(col_x, row)):
			target.y = row * Tuning.TILE
			break
	for i: int in level.heroes.size():
		var hero: PlayerBase = level.heroes[i]
		hero.sim_pos = target - Vector2i(24 * i, 0)
		hero.sim_prev = hero.sim_pos
		level.notify_hero_teleported(hero)


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
	assert_eq(dial.get_text(), str(ceili(Tuning.ticks_to_seconds(1000) - 0.0001)), "the seconds left")
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


## G1: the four corner panels cost 31 of the arena's 60 draw calls. The versus HUD has no child nodes and draws every
## picture, plate, edge and pip from one texture (HudAtlas), then the text in one face: two batches, three while a
## banner in the title face shows. The tags, edge arrows and stones of the party HUD come from the same texture.
func test_hud_versus_draws_from_one_texture() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, 4)
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	var versus: HudVersus = hud.get_versus()
	var referee: FakeReferee = FakeReferee.new()
	referee.stacks = PackedInt32Array([3, 12, 0, 127])
	referee.banks = PackedInt32Array([5, 0, 19, 1])
	referee.wins = PackedInt32Array([1, 0, 2, 0])
	referee.left = 900
	referee.leader = 3
	versus.source = referee
	Game.runs[1].set_weapon(Defs.Weapon.AXE)
	Game.runs[1].set_belt(Defs.Weapon.CLUB)
	versus.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(versus.get_child_count(), 0, "no child nodes: the panels are drawn, not built of labels")
	assert_eq(versus.draw_batches, 2, "every picture from the atlas, then all text in the HUD face")
	versus.show_banner("3", UiKit.COL_CREAM, UiKit.Style.TITLE, 0.0)
	await get_tree().process_frame
	assert_eq(versus.draw_batches, 3, "a countdown banner adds the title face")
	var atlas: Texture2D = HudAtlas.texture()
	assert_true(atlas.get_width() <= 2048 and atlas.get_height() <= 2048, "one small texture")
	for group: StringName in [&"food", &"crown", &"belt", &"heart", &"tag", &"arrow", &"stone", &"dial"]:
		var cell: Rect2 = HudAtlas.region(group, 0)
		assert_true(cell.has_area() and Rect2(Vector2.ZERO, atlas.get_size()).encloses(cell), "%s in the atlas" % group)
	var image: Image = atlas.get_image()
	var tag_cell: Rect2 = HudAtlas.region(&"tag", 0)
	assert_true(image.get_region(Rect2i(tag_cell)).get_used_rect().has_area(), "the P1 tag was copied")
	var empty: Rect2 = HudAtlas.dial_frame(0.0)
	var full: Rect2 = HudAtlas.dial_frame(1.0)
	assert_ne(empty, full, "the sundial has frames")
	assert_ne(image.get_region(Rect2i(empty)).get_pixel(9, 6), image.get_region(Rect2i(full)).get_pixel(9, 6),
			"its shadow sweeps over the face")


## G1: the bottom panels sat on the arena floor and hid a hero walking there. On the real Totem Ring at 640 x 360 every
## panel, the crown and the sundial keep clear of a hero standing on any surface of the arena: the top ones fill row 0,
## the bottom ones the floor tiles under the floor line.
func test_hud_versus_panels_never_hide_a_hero_standing_in_the_arena() -> void:
	if not Levels.has_level(TOTEM_RING) or not ResourceLoader.exists(LEVEL_SCENE):
		fail("DA's Totem Ring and the level scene are needed")
		return
	Game.versus_match = null
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, 4)
	Sim.manual = true
	Flow.pending_level_id = TOTEM_RING
	var level: LevelBase = (load(LEVEL_SCENE) as PackedScene).instantiate() as LevelBase
	add_node(level)
	await get_tree().process_frame
	if level.has_method(&"set_view_size"):
		level.call(&"set_view_size", Vector2i(Tuning.VIEW_W, Tuning.VIEW_H) * Tuning.ART_SCALE)
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	var versus: HudVersus = hud.get_versus()
	versus.level_override = level
	var referee: FakeReferee = FakeReferee.new()
	# The widest panels: three-digit counts, a special on every belt; P1 leads (the crown).
	referee.stacks = PackedInt32Array([123, 104, 99, 110])
	referee.banks = PackedInt32Array([101, 0, 19, 100])
	referee.leader = 0
	referee.left = 600
	versus.source = referee
	for slot: int in 4:
		Game.runs[slot].set_weapon(Defs.Weapon.SPEAR)
		Game.runs[slot].set_belt(Defs.Weapon.CLUB)
	await get_tree().process_frame
	versus.refresh()
	var view: Rect2 = hud.get_viewport_rect()
	var floor_line: float = versus.floor_line_y()
	assert_true(is_finite(floor_line), "an arena has a floor line")
	var covers: Array[Rect2] = [versus.get_sundial().rect]
	for slot: int in 4:
		var panel: HudVersus.CornerPanel = versus.get_panel(slot)
		covers.append(panel.get_cover_rect())
		assert_true(view.encloses(panel.get_cover_rect()), "P%d's panel inside the view: %s" % [slot + 1, panel.rect])
		if panel.bottom:
			assert_true(panel.rect.position.y >= floor_line, "P%d under the floor line %.0f: %s" % [slot + 1,
					floor_line, panel.rect])
	for i: int in covers.size():
		for j: int in range(i + 1, covers.size()):
			assert_false(covers[i].intersects(covers[j]), "HUD parts apart: %s / %s" % [covers[i], covers[j]])
	assert_true(versus.get_panel(0).get_crown_rect().has_area(), "the leader's crown")
	var hero: PlayerBase = level.get_hero(0)
	var grid: TileGrid = level.grid
	var surfaces: int = 0
	for row: int in range(1, grid.rows):
		for col: int in grid.cols:
			if not TileGrid.is_ground(grid.floor_at(col, row)) or TileGrid.is_ground(grid.floor_at(col, row - 1)):
				continue
			for dx: int in [2, 8, 14]:
				hero.teleport(Vector2i(col * Tuning.TILE + dx, row * Tuning.TILE))
				var feet: Vector2 = hero.get_global_transform_with_canvas().origin
				var box: Vector2 = Vector2(float(hero.box_w), float(hero.box_h)) * float(Tuning.ART_SCALE)
				var body: Rect2 = Rect2(feet.x - box.x * 0.5, feet.y - box.y, box.x, box.y)
				surfaces += 1
				for cover: Rect2 in covers:
					assert_false(body.intersects(cover), "a hero standing at cell (%d, %d) is behind %s" % [col, row,
							cover])
	assert_true(surfaces > 40, "the arena's surfaces were walked (%d)" % surfaces)
	Sim.manual = false
	Flow.pending_level_id = &""


## A hero who still comes behind a panel (a jump into a corner) sees it fade like the solo HUD row, and back.
func test_hud_versus_panel_fades_while_a_hero_is_behind_it() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, 2)
	var level: LevelBase = make_flat_level(80, 30, 20)
	var p1: PlayerBase = PlayerBase.new()
	place(level, p1, Vector2i(200, 160), {"slot": 0})
	var p2: PlayerBase = PlayerBase.new()
	place(level, p2, Vector2i(240, 160), {"slot": 1})
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	var versus: HudVersus = hud.get_versus()
	versus.level_override = level
	versus.refresh(1.0)
	assert_almost_eq(versus.get_panel(0).alpha, 1.0, 0.001, "nobody behind P1's panel")
	var rect: Rect2 = versus.get_panel_rect(0)
	var feet: Vector2 = rect.get_center() / float(Tuning.ART_SCALE) + Vector2(0.0, 10.0)
	p2.teleport(Vector2i(feet))
	versus.refresh(1.0)
	assert_almost_eq(versus.get_panel(0).alpha, HudVersus.UNDER_HERO_ALPHA, 0.001, "P2 jumped behind P1's panel")
	assert_almost_eq(versus.get_panel(1).alpha, 1.0, 0.001, "the other panel stays")
	await get_tree().process_frame
	assert_eq(versus.draw_batches, 2, "a faded panel is drawn in the same batches")
	p2.teleport(Vector2i(240, 160))
	versus.refresh(0.05)
	assert_true(versus.get_panel(0).alpha > HudVersus.UNDER_HERO_ALPHA and versus.get_panel(0).alpha < 1.0,
			"it fades back in")
	versus.refresh(1.0)
	assert_almost_eq(versus.get_panel(0).alpha, 1.0, 0.001)
	p1.dead = true
	p1.teleport(Vector2i(feet))
	versus.refresh(1.0)
	assert_almost_eq(versus.get_panel(0).alpha, 1.0, 0.001, "a dead hero does not count")


## The crown hangs beside the leader's panel (none on a tie); a hearts mode shows hearts instead of the stack.
func test_hud_versus_crown_and_hearts() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, 4)
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	var versus: HudVersus = hud.get_versus()
	var referee: FakeReferee = FakeReferee.new()
	versus.source = referee
	versus.refresh()
	for slot: int in 4:
		assert_false(versus.get_panel(slot).crowned, "a tie: no crown")
	referee.leader = 1
	versus.refresh()
	var panel: HudVersus.CornerPanel = versus.get_panel(1)
	assert_true(panel.crowned)
	var crown: Rect2 = panel.get_crown_rect()
	assert_true(crown.end.x <= panel.rect.position.x, "P2's crown on the inner side of his panel: %s" % crown)
	assert_false(crown.intersects(versus.get_sundial().rect), "clear of the sundial")
	assert_eq(panel.hearts, -1, "Grub Stack: the stack and the pot")
	Game.versus_match = VersusMatch.new()
	Game.versus_match.round_mode = Defs.VersusMode.LAST_CAVEMAN
	Game.runs[2].lose_heart()
	versus.refresh()
	assert_eq(versus.get_panel(2).hearts, Tuning.ENERGY_START - 1, "Last Caveman Standing: his hearts")
	assert_eq(versus.get_panel(0).wins_needed, Game.versus_match.round_wins_needed(), "pips to win the match")
	await get_tree().process_frame
	assert_eq(versus.draw_batches, 2)
	Game.versus_match = null


## Every panel shows the player's head in the colour he wears (ui/portrait_heads.png): cheering while he leads, "ouch"
## while his hero is knocked out. Three-digit counts on a 640 px view: the panels drop the tag text instead of
## running into the sundial.
func test_hud_versus_heads_and_the_narrow_top_row() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, 2)
	var level: LevelBase = make_flat_level(80, 30, 20)
	var p1: PlayerBase = PlayerBase.new()
	place(level, p1, Vector2i(100, 160), {"slot": 0})
	var p2: PlayerBase = PlayerBase.new()
	place(level, p2, Vector2i(200, 160), {"slot": 1})
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	var versus: HudVersus = hud.get_versus()
	versus.level_override = level
	var referee: FakeReferee = FakeReferee.new()
	referee.leader = 1
	versus.source = referee
	versus.refresh()
	assert_eq(versus.get_panel(0).face, UiPlayers.Face.NORMAL)
	assert_eq(versus.get_panel(1).face, UiPlayers.Face.CHEER, "the leader cheers")
	p1.dead = true
	versus.refresh()
	assert_eq(versus.get_panel(0).face, UiPlayers.Face.OUCH, "knocked out")
	p1.dead = false
	assert_eq(UiPlayers.head_cell(1, UiPlayers.Face.CHEER), 1 * 3 + 2, "P2 in blue: row 1, the cheer column")
	Game.runs[1].palette = &"gold"
	assert_eq(UiPlayers.head_cell(1), 5 * 3, "the colour he chose: the gold row")
	assert_eq(UiPlayers.tag_cell(1), (1 + 5) * 4 + 1, "his tag in gold")
	assert_eq(UiPlayers.arrow_cell(1, UiPlayers.Side.UP), 5 * 4 + UiPlayers.Side.UP, "his arrow in gold")
	Game.runs[1].palette = &""
	assert_eq(UiPlayers.tag_cell(0), 4, "P1's default tag: the yellow row")
	var view: Rect2 = hud.get_viewport_rect()
	assert_true(versus.get_panel(0).show_tag, "two-digit counts: the tag fits")
	if view.size.x <= 680.0:
		referee.stacks = PackedInt32Array([123, 456, 0, 0])
		referee.banks = PackedInt32Array([789, 101, 0, 0])
		referee.leader = 0
		versus.refresh()
		var dial: Rect2 = versus.get_sundial().rect
		for slot: int in 2:
			var panel: HudVersus.CornerPanel = versus.get_panel(slot)
			assert_false(panel.get_cover_rect().intersects(dial), "P%d clear of the sundial: %s / %s" % [slot + 1,
					panel.get_cover_rect(), dial])
		assert_false(versus.get_panel(0).get_cover_rect().intersects(versus.get_panel(1).get_cover_rect()))
	await get_tree().process_frame
	assert_eq(versus.draw_batches, 2, "the heads come from the atlas too")


## The deciding moment (DESIGN.md E.8, Flow.replay_started / replay_finished): its banner with the skip hint while it
## plays - "the biggest steal" or "the deciding moment" - and a Skip button for a touch player that calls
## Flow.skip_replay; all gone when it ends.
func test_hud_versus_deciding_moment_banner_and_skip() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, 2)
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	var versus: HudVersus = hud.get_versus()
	Flow.replay_started.emit(0, 100, 172, true)
	assert_true(versus.replaying)
	assert_eq(versus.banner_text, tr("UI_VS_REPLAY_STEAL"))
	assert_eq(versus.banner_hint, tr("UI_VS_REPLAY_SKIP"), "how to skip it")
	assert_true(versus.is_banner_visible())
	if not HudVersus.touch_in_use():
		assert_null(versus.get_skip_button(), "keyboard and pads: no button")
	await get_tree().process_frame
	assert_true(versus.draw_batches <= 3, "banner and hint in the HUD face")
	Flow.replay_finished.emit(false)
	assert_false(versus.replaying)
	assert_false(versus.is_banner_visible(), "the scoreboard follows: banner gone")
	var device: int = GameInput.device
	GameInput.device = Defs.Device.TOUCH
	Flow.replay_started.emit(1, 200, 272, false)
	assert_eq(versus.banner_text, tr("UI_VS_REPLAY_MOMENT"), "no steal: the deciding moment")
	var button: UiButton = versus.get_skip_button()
	assert_not_null(button, "a touch player gets a Skip button")
	if button != null:
		assert_eq(button.text, "UI_VS_REPLAY_SKIP_BUTTON")
		assert_true(button.pressed.is_connected(Flow.skip_replay), "it skips the replay")
		await get_tree().process_frame
		versus.refresh()
		assert_true(hud.get_viewport_rect().encloses(button.get_global_rect()), "on the screen")
		assert_false(button.get_global_rect().intersects(versus.get_banner_rect()), "under the banner")
	Flow.replay_finished.emit(true)
	await get_tree().process_frame
	assert_null(versus.get_skip_button(), "removed when the replay ends")
	GameInput.device = device


## The corner panels count what the round's mode counts (DESIGN.md E.4): Hot Rock the ember on its holder (his plate
## glows; no clock, so no sundial), Clubball the side's goals with the coconut (golden on a tie), Last Caveman
## Standing the hearts and, with Stock, the lives left. Every picture still comes from the atlas.
func test_hud_versus_panels_count_what_the_mode_counts() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, 4)
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	var versus: HudVersus = hud.get_versus()
	var referee: FakeModeReferee = FakeModeReferee.new()
	referee.stacks = PackedInt32Array([7, 0, 0, 0])
	versus.source = referee
	# Hot Rock: the ember on P3, no round clock.
	referee.mode = Defs.VersusMode.HOT_ROCK
	referee.holder = 2
	referee.length = 0
	versus.refresh()
	for slot: int in 4:
		var panel: HudVersus.CornerPanel = versus.get_panel(slot)
		assert_eq(panel.content, HudVersus.Content.EMBER, "Hot Rock: P%d" % (slot + 1))
		assert_eq(panel.ember, slot == 2, "the ember is P3's: P%d" % (slot + 1))
		assert_eq(panel.hearts, -1)
	assert_almost_eq(versus.get_panel(0).rect.size.x, versus.get_panel(2).rect.size.x, 0.5,
			"room for the ember on every panel: it never jumps when the rock passes")
	assert_false(versus.get_sundial().visible, "no clock in Hot Rock: no sundial")
	assert_eq(hud.get_row_bottom(), versus.get_sundial().rect.end.y, "the row still ends where the sundial would")
	await get_tree().process_frame
	assert_eq(versus.draw_batches, 2, "the ember comes from the atlas")
	assert_true(HudAtlas.region(&"ember").has_area() and HudAtlas.region(&"coconut", HudAtlas.COCONUT_GOLDEN).has_area())
	var image: Image = HudAtlas.texture().get_image()
	assert_true(image.get_region(Rect2i(HudAtlas.region(&"ember"))).get_used_rect().has_area(), "the ember was copied")
	# Clubball: each panel shows his side's goals; a tie at the gong plays the golden coconut.
	referee.mode = Defs.VersusMode.CLUBBALL
	referee.scores = PackedInt32Array([3, 1, 3, 1])
	referee.length = 3780
	referee.left = 400
	versus.refresh()
	assert_eq(versus.get_panel(0).content, HudVersus.Content.GOALS)
	assert_eq(versus.get_panel(2).get_goals_text(), "3", "P3 plays on P1's side")
	assert_eq(versus.get_panel(1).get_goals_text(), "1")
	assert_true(versus.get_sundial().visible, "Clubball's three minutes")
	assert_false(versus.get_panel(0).golden)
	referee.phase = VersusReferee.PHASE_GOLDEN
	referee.left = -1
	referee.scores = PackedInt32Array([3, 3, 3, 3])
	versus.refresh()
	assert_true(versus.get_panel(0).golden, "the golden coconut")
	assert_eq(versus.banner_text, tr("UI_VS_GOLDEN_COCONUT"))
	assert_eq(versus.banner_hint, tr("UI_VS_GOLDEN_COCONUT_HINT"))
	assert_almost_eq(versus.get_sundial().elapsed, 1.0, 0.001, "the clock ran out: the shadow covers the dial")
	await get_tree().process_frame
	assert_true(versus.draw_batches <= 3)
	# Last Caveman Standing with Stock: hearts (0 once out) and the lives left.
	referee.phase = VersusReferee.PHASE_PLAY
	referee.mode = Defs.VersusMode.LAST_CAVEMAN
	referee.scores = PackedInt32Array([3, 0, 2, 1])
	referee.stocks = PackedInt32Array([2, 0, 1, 3])
	versus.refresh()
	assert_eq(versus.get_panel(1).hearts, 0, "P2 is out")
	assert_eq(versus.get_panel(2).hearts, 2)
	assert_eq(versus.get_panel(0).stock, -1, "no Stock option: no lives")
	assert_eq(versus.get_panel(0).get_stock_text(), "")
	var plain_w: float = versus.get_panel(0).rect.size.x
	referee.rules.stock = true
	versus.refresh()
	assert_eq(versus.get_panel(0).get_stock_text(), "x2", "Stock: his lives")
	assert_eq(versus.get_panel(1).get_stock_text(), "x0")
	assert_true(versus.get_panel(0).rect.size.x > plain_w, "the panel makes room for them")
	var view: Rect2 = hud.get_viewport_rect()
	for slot: int in 4:
		assert_true(view.encloses(versus.get_panel(slot).get_cover_rect()), "P%d inside the view" % (slot + 1))
	# Grub Stack: a tie drops the Golden Drumstick.
	referee.mode = Defs.VersusMode.GRUB_STACK
	versus.refresh()
	assert_eq(versus.get_panel(0).content, HudVersus.Content.STACK)
	assert_eq(versus.get_panel(0).get_stack_text(), "7")
	Events.round_started.emit(1)
	referee.phase = VersusReferee.PHASE_GOLDEN
	versus.refresh()
	assert_eq(versus.banner_text, tr("UI_VS_GOLDEN_DRUMSTICK"), "a new round: its own golden banner")
	assert_eq(versus.banner_hint, tr("UI_VS_GOLDEN_DRUMSTICK_HINT"))


## "SUDDEN DEATH!" says which one the arena throws in: every theme of VersusSuddenDeath has its line in en.po.
func test_hud_versus_sudden_death_names_the_theme() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, 2)
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	var versus: HudVersus = hud.get_versus()
	for theme: StringName in VersusSuddenDeath.THEMES:
		assert_true(HudVersus.SUDDEN_DEATH_KEYS.has(theme), "a line for %s" % theme)
		if HudVersus.SUDDEN_DEATH_KEYS.has(theme):
			var key: String = HudVersus.SUDDEN_DEATH_KEYS[theme]
			assert_ne(tr(key), key, "%s has an English text" % key)
	Events.round_sudden_death_started.emit(0, VersusSuddenDeath.STAMPEDE)
	assert_eq(versus.banner_text, tr("UI_VS_SUDDEN_DEATH"))
	assert_eq(versus.banner_hint, tr("UI_VS_SD_STAMPEDE"), "Stampede!")
	await get_tree().process_frame
	assert_true(hud.get_viewport_rect().encloses(versus.get_banner_rect()), "the banner fits the view")
	Events.round_sudden_death_started.emit(0, &"unknown_theme")
	assert_eq(versus.banner_hint, "", "an unknown theme: the banner alone")


## A new match with another number of players gets its own set of panels.
func test_hud_versus_follows_the_number_of_players() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, 4)
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	assert_eq(hud.get_versus().player_count(), 4)
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, 3)
	assert_eq(hud.get_versus().player_count(), 3, "three players: three panels")
	assert_null(hud.get_versus().get_panel(3))
	await get_tree().process_frame
	var count: int = 0
	for child: Node in hud.get_children():
		if child is HudVersus:
			count += 1
	assert_eq(count, 1, "the old panels are gone")


## A found Cave Painting that opens a reward (Save.reward_unlocked): "Unlocked: <reward>" under the HUD row for a few
## seconds, then it fades.
func test_hud_shows_a_reward_notice() -> void:
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	assert_false(hud.is_reward_visible())
	Save.reward_unlocked.emit(&"mesa_rodeo")
	assert_true(hud.is_reward_visible())
	assert_eq(hud.reward_text, tr("UI_HUD_REWARD").format({"reward": tr("UI_REWARD_MESA_RODEO")}))
	assert_false(hud.reward_text.contains("{"), "the reward's own text: %s" % hud.reward_text)
	await get_tree().process_frame
	await get_tree().process_frame
	var label: Label = _label_with_text(hud, hud.reward_text)
	assert_not_null(label)
	if label != null:
		assert_true(label.get_global_rect().position.y >= hud.get_row_bottom(), "under the HUD row")
	await get_tree().create_timer(Hud.REWARD_SECONDS + 0.3).timeout
	assert_false(hud.is_reward_visible(), "gone after a few seconds")


## The HUD row's bottom edge for world text (sign boards): under lives, hearts and letters; in versus under the row of
## corner panels and the sundial.
func test_hud_tells_where_its_row_ends() -> void:
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	var bottom: float = hud.get_row_bottom()
	assert_true(bottom >= Hud.ROW_HEIGHT and bottom <= Hud.ROW_HEIGHT + float(UiKit.MARGIN_MOBILE), "%.0f" % bottom)
	assert_true(hud.is_under_row(bottom - 1.0))
	assert_false(hud.is_under_row(bottom + 1.0))
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, 2)
	await get_tree().process_frame
	assert_eq(hud.get_row_bottom(), hud.get_versus().get_sundial().rect.end.y, "versus: the panel row")


## Tags and colour arrows (DESIGN.md E.9): every hero's tag through the round's countdown and the start of the round,
## and whenever heroes overlap; in Grub Stack the tag stands on top of the food tower over the head.
func test_hud_tags_show_at_the_round_start_and_ride_on_the_tower() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, 2)
	var level: LevelBase = make_flat_level(80, 30, 20)
	var p1: PlayerBase = PlayerBase.new()
	place(level, p1, Vector2i(100, 160), {"slot": 0})
	var p2: PlayerBase = PlayerBase.new()
	place(level, p2, Vector2i(200, 160), {"slot": 1})
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	var arrows: HudEdgeArrows = hud.get_edge_arrows()
	arrows.level_override = level
	assert_true(arrows.visible, "versus: tags and arrows")
	arrows.show_tags(0.0)
	arrows.update_markers()
	assert_eq(arrows.tags.size(), 0, "apart, mid-round: no tags")
	Events.round_countdown.emit(0, 3)
	arrows.update_markers()
	assert_eq(arrows.tags.size(), 2, "3, 2, 1: who is who")
	arrows.show_tags(0.0)
	Events.round_started.emit(0)
	arrows.update_markers()
	assert_eq(arrows.tags.size(), 2, "GRUB!: still shown")
	var bare_y: float = _tag_y(arrows, 1)
	var driver: FakeDriver = FakeDriver.new()
	add_node(driver)
	driver.stacks = PackedInt32Array([0, 6, 0, 0])
	level.party_driver = driver
	arrows.update_markers()
	var tower: float = VersusStackDisplay.FIRST_FOOT_ART + 5.0 * VersusStackDisplay.STEP_ART \
			+ float(VersusStackDisplay.CELL.y) - float(p2.box_h * Tuning.ART_SCALE)
	assert_almost_eq(bare_y - _tag_y(arrows, 1), tower, 0.5, "P2's tag on top of his six pictures")
	assert_almost_eq(_tag_y(arrows, 0), bare_y, 0.5, "P1 has no tower")
	driver.stacks = PackedInt32Array([0, 400, 0, 0])
	arrows.update_markers()
	assert_true(_tag_y(arrows, 1) >= float(HudEdgeArrows.TAG_CELL.y), "a tall tower never pushes the tag off the view")
	level.party_driver = null
	arrows.show_tags(0.0)
	p2.teleport(p1.sim_pos + Vector2i(6, 0))
	arrows.update_markers()
	assert_eq(arrows.tags.size(), 2, "overlapping heroes wear their tags")


func _tag_y(arrows: HudEdgeArrows, slot: int) -> float:
	for tag: Dictionary in arrows.tags:
		if int(tag["slot"]) == slot:
			return (tag["pos"] as Vector2).y
	return NAN


## Co-op with the Rival score option (DESIGN.md D.11): the score counter shows P1's own score in his colour, P2's panel
## his own under his hearts; off, the tribe score as in 1.0.
func test_hud_rival_score_shows_each_players_own_score() -> void:
	Settings.set_value(OptionsPanel.KEY_RIVAL_SCORE, false)
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	var panel: HudPlayerPanel = hud.get_p2_panel()
	Game.runs[0].score = 300
	Game.runs[1].score = 1200
	Game.add_score(1500)
	assert_false(hud.rival_score)
	assert_eq(hud.get_score_text(), UiKit.score_text(1500), "off: the tribe score")
	assert_eq(panel.get_score_text(), "", "off: no score in P2's panel")
	var height: float = panel.size.y
	Settings.set_value(OptionsPanel.KEY_RIVAL_SCORE, true)
	assert_true(hud.rival_score)
	assert_eq(hud.get_score_text(), UiKit.score_text(300), "P1's own score")
	assert_eq(panel.get_score_text(), UiKit.score_text(1200), "P2's own score in his panel")
	assert_almost_eq(panel.size.y, height + HudPlayerPanel.SCORE_H, 0.5, "the panel grows by the score line")
	assert_true(hud.get_viewport_rect().encloses(panel.get_global_rect()), "inside the view")
	Game.runs[1].score += 50
	Game.add_score(50)
	assert_eq(panel.get_score_text(), UiKit.score_text(1250), "it follows the score")
	Game.new_game(Defs.Difficulty.BEGINNER)
	assert_false(hud.rival_score, "single-player keeps the 1.0 counter")
	Settings.set_value(OptionsPanel.KEY_RIVAL_SCORE, false)


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


## The UI pass of the pause menu (wf9, the check of tests/test_ui_screens.gd layout_problems): the 1.0 menu of a solo
## run, P2's menu in co-op, its join page and P2's options page, at 640 x 360 and 800 x 360 - no text or entry past the
## view's edge, no two texts over each other, no clipped text that cuts its words.
func test_pause_menu_passes_the_ui_check_at_640_and_800() -> void:
	const Screens: GDScript = preload("res://tests/test_ui_screens.gd")
	var report: PackedStringArray = PackedStringArray()
	for state: String in ["solo", "co-op P2", "co-op P2 join", "co-op P2 options"]:
		for view: Vector2 in Screens.PASS_VIEWS:
			var coop: bool = state.begins_with("co-op")
			Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP if coop else Defs.GameMode.SINGLE, 2 if coop else 1)
			if coop:
				GameInput.assign_slot(0, InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT))
				GameInput.assign_slot(1, InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_RIGHT))
			var menu: PauseMenu = await _overlay(Flow.PAUSE_SCENE) as PauseMenu
			menu.size = view
			Flow.pause_slot = 1 if coop else 0
			Events.pause_changed.emit(true)
			if state.ends_with("join"):
				menu.open_join()
			elif state.ends_with("options"):
				menu.open_options()
			for frame: int in 3:
				await get_tree().process_frame
			var problems: PackedStringArray = Screens.layout_problems(menu)
			var seen: Vector2i = Screens.pass_checked
			assert_true(problems.is_empty(), "%s at %d x %d: %s" % [state, view.x, view.y, "; ".join(problems)])
			assert_true(seen.x >= 2, "%s: the check saw its texts (%d)" % [state, seen.x])
			report.append("%s %d: %d texts %d entries" % [state, view.x, seen.x, seen.y])
			Events.pause_changed.emit(false)
			Flow.pause_slot = 0
			menu.queue_free()
			await get_tree().process_frame
			GameInput.reset_slots()
	print("    ui pass: %s" % ", ".join(report))
	Game.new_game(Defs.Difficulty.BEGINNER)


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


## Cut list 2 APPLIED (DESIGN.md G37): table mode is a hidden prototype - not offered unless the developer switch is
## on: a tap on the join panel or in the lobby always seats a whole-screen touch player.
func test_table_mode_is_hidden_behind_the_developer_switch() -> void:
	assert_false(TouchControls.experimental_table_mode, "off by default")
	if not OS.get_cmdline_user_args().has("--table-mode"):
		assert_false(TouchControls.table_mode_switched_on(), "no switch, no table mode")
	assert_false(TouchControls.table_mode_available(), "never offered without the switch")
	var tapped: InputSlot = JoinScreen.touch_input_at(Vector2(320.0, 40.0), Vector2(640.0, 360.0))
	assert_eq(tapped.kind, Defs.InputSlotKind.TOUCH)
	assert_eq(tapped.region, InputSlot.touch().region, "a tap in the top half: the whole screen, not P2's half")
	TouchControls.experimental_table_mode = true
	assert_eq(TouchControls.table_mode_switched_on(), OS.is_debug_build(), "the switch works in debug builds only")
	TouchControls.experimental_table_mode = false


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

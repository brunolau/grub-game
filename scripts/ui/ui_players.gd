class_name UiPlayers
extends RefCounted
## Who is who on one screen (DESIGN.md D.1 / D.11 / E.9, ASSET_MANIFEST.md 17.1 / 17.5): the colour of every player
## slot, its "P1".."P4" tag, and the cells of the 2.0 HUD sheets - edge arrows (`ui/player_arrows.png`), the stone
## countdown (`ui/countdown_stones.png`) and the belt icon (`ui/hud_belt.png`).
##
## Owner: ui-B. The colours are the `ui_colours` of `assets/sprites/player/palettes/hero_palettes.json`, kept here as
## constants (the JSON is reference data that the export does not carry, ASSET_MANIFEST.md 17.9). A player's own
## colour is `PlayerRun.palette` (chosen on the join panel / in the lobby); `&""` means the slot's default.

## Side of the view a hero is off (the columns of `ui/player_arrows.png`).
enum Side { LEFT = 0, RIGHT = 1, UP = 2, DOWN = 3 }

const TEX_ARROWS: String = "res://assets/ui/player_arrows.png"
const TEX_STONES: String = "res://assets/ui/countdown_stones.png"
const TEX_BELT: String = "res://assets/ui/hud_belt.png"
## Cell size of the three sheets (art px).
const CELL: Vector2i = Vector2i(32, 32)
## Highest digit of the stone countdown (cells 0..4 = '1'..'5').
const STONE_MAX: int = 5

## Slot defaults (hero_palettes.json `slot_defaults`): P1 yellow, P2 blue, P3 pink, P4 green.
const SLOT_PALETTES: Array[StringName] = [&"yellow", &"blue", &"pink", &"green"]
## `ui_colours` of hero_palettes.json: palette -> [fill, light, shade, dark].
const PALETTE_COLOURS: Dictionary = {
	&"yellow": [Color("ffe94f"), Color("ffffff"), Color("f3aa39"), Color("272018")],
	&"blue": [Color("8ae6ff"), Color("ffffff"), Color("3f9fe8"), Color("142a55")],
	&"pink": [Color("c41f8f"), Color("ffa8de"), Color("861465"), Color("3d0d33")],
	&"green": [Color("13893d"), Color("a6ee7c"), Color("0b5c35"), Color("0e321d")],
	&"white": [Color("f7f4ec"), Color("ffffff"), Color("b7bfd2"), Color("2c2c3a")],
	&"gold": [Color("ffc928"), Color("fff7c2"), Color("c97d10"), Color("3f2508")],
}
## `arena_swaps` of hero_palettes.json, by palette: biome -> the palette worn there in versus.
const ARENA_SWAPS: Dictionary = {&"green": {"jungle": &"white", "swamp": &"white"}}
## Index of each colour in a PALETTE_COLOURS entry.
const FILL: int = 0
const LIGHT: int = 1
const SHADE: int = 2
const DARK: int = 3


## The palette name of player slot `slot`: his run's choice, else the slot default.
static func palette_of(slot: int) -> StringName:
	var index: int = clampi(slot, 0, Defs.MAX_PLAYERS - 1)
	var run: PlayerRun = Game.get_run(index) if slot >= 0 and slot < Defs.MAX_PLAYERS else null
	var palette: StringName = SLOT_PALETTES[index]
	if run != null and PALETTE_COLOURS.has(run.palette):
		palette = run.palette
	# The arena swaps of hero_palettes.json (as the hero wears them, HeroPalette): green turns white on a jungle or
	# swamp arena.
	if Game.mode == Defs.GameMode.VERSUS and Game.level_id != &"" and ARENA_SWAPS.has(palette):
		var biome: String = str(Levels.get_value(Game.level_id, "biome", ""))
		if (ARENA_SWAPS[palette] as Dictionary).has(biome):
			palette = ARENA_SWAPS[palette][biome]
	return palette


## One colour of player slot `slot` (FILL, LIGHT, SHADE or DARK).
static func colour(slot: int, which: int = FILL) -> Color:
	var entry: Array = PALETTE_COLOURS[palette_of(slot)]
	return entry[clampi(which, 0, entry.size() - 1)]


## A colour of `slot` that reads as text on the HUD's dark plates and over the scenery: the fill, lifted towards
## its light colour for the two dark cloths (pink, green), so that every tag stays legible.
static func text_colour(slot: int) -> Color:
	var fill: Color = colour(slot, FILL)
	if fill.get_luminance() < 0.45:
		return fill.lerp(colour(slot, LIGHT), 0.55)
	return fill


## "P1".."P4".
static func tag(slot: int) -> String:
	return "P%d" % (clampi(slot, 0, Defs.MAX_PLAYERS - 1) + 1)


## Edge arrow of player slot `slot` pointing to `side` (Side).
static func arrow(slot: int, side: int) -> AtlasTexture:
	var row: int = clampi(slot, 0, Defs.MAX_PLAYERS - 1)
	return UiKit.cell(TEX_ARROWS, CELL, row * 4 + clampi(side, Side.LEFT, Side.DOWN))


## Countdown stone showing `digit` (1..STONE_MAX, clamped).
static func stone(digit: int) -> AtlasTexture:
	return UiKit.cell(TEX_STONES, CELL, clampi(digit, 1, STONE_MAX) - 1)


## Belt icon of a weapon (Defs.Weapon: club, hammer, axe, boomerang = the swirling axe, spear).
static func belt_icon(weapon: int) -> AtlasTexture:
	return UiKit.cell(TEX_BELT, CELL, clampi(weapon, Defs.Weapon.CLUB, Defs.Weapon.SPEAR))


## Whole seconds shown by the stone countdown of a hero whose leash count is `leash` (PlayerBase.leash) when he turns
## into an egg at `limit` ticks (PartyTuning.leash_egg_ticks): 5..1 on Beginner, 3..1 on Expert; 0 = no countdown.
static func leash_digit(leash: int, limit: int) -> int:
	if leash <= 0 or limit <= 0:
		return 0
	var left: int = maxi(limit - leash, 0)
	return clampi(ceili(Tuning.ticks_to_seconds(left) - 0.0001), 1, STONE_MAX)


## A small "P2" label in the HUD face, tinted with the player's colour (the face's own dark outline stays).
static func tag_label(slot: int) -> Label:
	var label: Label = UiKit.label(tag(slot), UiKit.Style.HUD)
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.add_theme_color_override(&"font_color", text_colour(slot))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## The menu action (`ui_up`, `ui_down`, `ui_left`, `ui_right`, `ui_accept`, `ui_cancel`) that `event` means for player
## slot `slot` of a party, by the slot's own game keys (DESIGN.md D.11: each player drives the menus from his own
## cluster - classic P1: W / S / Space / Q, P2: Num 8 / Num 5 / Num 0 / Num .): move keys move, Jump and Strike
## confirm, Look goes back. &"" when the event is none of them, is already a menu action, or the slot reads no
## generated actions (single-player: every key keeps its 1.0 meaning). Presses only (held moves repeat).
static func menu_action(event: InputEvent, slot: int) -> StringName:
	if event == null or not event.is_pressed() or slot < 0 or slot >= Defs.MAX_PLAYERS:
		return &""
	if not GameInput.get_slot(slot).uses_generated_actions():
		return &""
	for ui: StringName in [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_accept", &"ui_cancel"]:
		if event.is_action(ui, true):
			return &""
	var moves: Dictionary = {
		Defs.ACT_UP: &"ui_up", Defs.ACT_DOWN: &"ui_down", Defs.ACT_LEFT: &"ui_left", Defs.ACT_RIGHT: &"ui_right",
	}
	for action: StringName in moves:
		var generated: StringName = GameInput.slot_action(slot, action)
		if InputMap.has_action(generated) and event.is_action(generated, true):
			return moves[action]
	if event.is_echo():
		return &""
	for action: StringName in [Defs.ACT_JUMP, Defs.ACT_ATTACK]:
		var generated: StringName = GameInput.slot_action(slot, action)
		if InputMap.has_action(generated) and event.is_action(generated, true):
			return &"ui_accept"
	var look: StringName = GameInput.slot_action(slot, Defs.ACT_LOOK)
	if InputMap.has_action(look) and event.is_action(look, true):
		return &"ui_cancel"
	return &""


## Send the menu action `ui` as an input event (pressed, then released), as [method menu_action] found it.
static func send_menu_action(ui: StringName) -> void:
	for pressed: bool in [true, false]:
		var action: InputEventAction = InputEventAction.new()
		action.action = ui
		action.pressed = pressed
		Input.parse_input_event(action)

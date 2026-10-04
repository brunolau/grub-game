class_name ItemContents
extends RefCounted
## A parsed `contents` parameter (ARCHITECTURE.md 6.2): what a hidden spot, a breakable block or a container
## throws out. Tokens are `<item name>[:<index or kind>]` joined by commas, e.g. `food:3,treasure:8,heart,
## weapon:axe`; `giant` = `giant_bonus`, `random` = `items/random_bonus`, `none` = nothing.

const TOKEN_NONE: String = "none"
const TOKEN_RANDOM: String = "random"
const ALIASES: Dictionary = {"giant": "giant_bonus"}
const ID_GIANT: StringName = &"items/giant_bonus"
const ID_WEAPON: StringName = &"items/weapon"

## Entity id of every token.
var ids: Array[StringName] = []
## Argument of every token ("" when it has none): a sprite cell, or the kind of a weapon.
var args: PackedStringArray = PackedStringArray()


## Parse a contents value. Tokens that name no existing item are reported and skipped. `random_item` is the item
## the token `random` stands for (a big hidden spot passes "giant_bonus": its random reward is a giant bonus).
static func parse(value: Variant, random_item: String = "random_bonus") -> ItemContents:
	var contents: ItemContents = ItemContents.new()
	for token: String in LevelText.to_list(value):
		var text: String = token.strip_edges()
		if text.is_empty() or text == TOKEN_NONE:
			continue
		var colon: int = text.find(":")
		var item_name: String = text if colon < 0 else text.substr(0, colon)
		if item_name == TOKEN_RANDOM:
			item_name = random_item
		var id: StringName = StringName("items/" + str(ALIASES.get(item_name, item_name)))
		if not Spawner.exists(id):
			push_warning("ItemContents: unknown contents token '%s'" % text)
			continue
		contents.ids.append(id)
		contents.args.append("" if colon < 0 else text.substr(colon + 1))
	return contents


## Number of tokens.
func size() -> int:
	return ids.size()


## True when there is nothing to throw out.
func is_empty() -> bool:
	return ids.is_empty()


## Throw out token number `token` (cycled) as a dropped item at `pos` with the start velocity (`xvel`, `yvel`).
## A giant bonus without a cell number is a random one (Sim.rng). Returns the item, or null.
func spawn(level: LevelBase, token: int, pos: Vector2i, xvel: int, yvel: int) -> Node:
	if ids.is_empty() or level == null:
		return null
	var i: int = posmod(token, ids.size())
	var id: StringName = ids[i]
	var arg: String = args[i]
	var params: Dictionary = {"dropped": true, "xvel": xvel, "yvel": yvel}
	if id == ID_WEAPON:
		params["kind"] = arg
	elif not arg.is_empty():
		params["index"] = arg.to_int()
	elif id == ID_GIANT:
		params["index"] = Sim.rng.next_int(ItemTable.GIANT_POINTS.size())
	return level.spawn(id, pos, params)

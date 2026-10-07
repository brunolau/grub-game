class_name UnlockTable
extends RefCounted
## The Cave Painting table (docs/expansion/DESIGN.md C.9, GAMEPLAY.md 13.2 / 13.7, PLAN.md P2.6). Owner: core-A.
##
## One place for every module that asks about the paintings and what they open: where painting n hides
## ([constant PAINTING_LEVELS], [method painting_file], [method paintings_of]), the reward ladder ([constant REWARDS]:
## the paintings each reward needs and the arenas, variants, loincloth patterns, palettes and the mural it opens) and
## whether a piece of content is open now ([method is_arena_open], [method is_variant_open], [method is_pattern_open],
## [method is_palette_open], [method is_mural_open]). Save keeps the state - the found paintings (Save.add_painting,
## profile-wide across modes), the rewards opened by hand (Save.unlock) and Options > Versus > "Unlock everything"
## (Save.set_unlock_everything) - and announces a reward the moment a found painting opens it
## (Save.reward_unlocked). Static data only: nothing here draws from Sim.rng or changes state.

## Where each painting hides, by index (GAMEPLAY.md 13.2 and 13.7): 0-19 one per Book II level in A.2 order (the same
## index in its solo and co-op file), 20-29 behind an x2 secret in the co-op file of these Book I levels (`ending` =
## the Way Home). Always the solo level id; [method painting_file] names the file it lies in for a mode.
const PAINTING_LEVELS: Array[StringName] = [
	&"w5_l1", &"w5_l2", &"w5_l2b", &"w6_l1", &"w6_l2", &"w6_l2b", &"w7_l1", &"w7_l2", &"w7_l2b", &"w8_l1",
	&"w8_l2", &"w8_l2b", &"w9_l1", &"w9_l1b", &"w9_l2", &"w9_l2b", &"w9_l3", &"bonus_d", &"bonus_e", &"ending_b",
	&"w1_l1", &"w1_l2", &"w2_l1", &"w2_l2", &"w3_l1", &"w3_l1b", &"w3_l2", &"w4_l1", &"w4_l2", &"ending",
]
## Paintings from this index on lie only in Book I co-op files (behind x2 secrets); the ones before it lie in the Book II
## solo files and their co-op twins.
const COOP_ONLY_FROM: int = Tuning.PAINTING_BOOK2_COUNT

## The rewards in the order they open (DESIGN.md C.9). Each: "id" (Save.UNLOCK_*), "paintings" (found paintings that
## open it, Save.UNLOCK_PAINTINGS), "text" (its translation key, locale/en.po), and what it opens: "arenas" (level ids,
## VersusMatch keeps them out of Random / Party Mix until open), "variants" (VersusMatch.variants names), "patterns" (the
## `unlock` tag of the loincloth patterns of assets/sprites/player/palettes/hero_palettes.json), "palettes"
## (PlayerRun.palette names), "mural" (the cave mural that ends The Long Raft Home).
const REWARDS: Array[Dictionary] = [
	{"id": &"mesa_rodeo", "paintings": Tuning.PAINTING_UNLOCK_MESA_RODEO, "text": "UI_REWARD_MESA_RODEO",
		"arenas": [&"arena_mesa_rodeo"]},
	{"id": &"loincloths", "paintings": Tuning.PAINTING_UNLOCK_LOINCLOTHS, "text": "UI_REWARD_LOINCLOTHS",
		"patterns": ["paintings_10"]},
	{"id": &"variants", "paintings": Tuning.PAINTING_UNLOCK_VARIANTS, "text": "UI_REWARD_VARIANTS",
		"variants": [&"big_bounce", &"lights_out", &"giant_rain"]},
	{"id": &"cloud_top", "paintings": Tuning.PAINTING_UNLOCK_CLOUD_TOP, "text": "UI_REWARD_CLOUD_TOP",
		"arenas": [&"arena_cloud_top"]},
	{"id": &"spear_party", "paintings": Tuning.PAINTING_UNLOCK_SPEAR_PARTY, "text": "UI_REWARD_SPEAR_PARTY",
		"variants": [&"spear_party"], "palettes": [&"gold"]},
	{"id": &"mural", "paintings": Tuning.PAINTING_UNLOCK_MURAL, "text": "UI_REWARD_MURAL", "mural": true},
]
## The `unlock` tag of a loincloth pattern that is open from the start (hero_palettes.json).
const PATTERN_DEFAULT: String = "default"


# =================================================================================================================
# Where the paintings hide
# =================================================================================================================

## The solo level painting `index` belongs to ("" for an index outside 0..Tuning.PAINTING_COUNT - 1).
static func painting_level(index: int) -> StringName:
	return PAINTING_LEVELS[index] if index >= 0 and index < PAINTING_LEVELS.size() else &""


## True for a painting that only a co-op run can find (20-29, the Book I co-op secrets).
static func is_coop_only(index: int) -> bool:
	return index >= COOP_ONLY_FROM and index < PAINTING_LEVELS.size()


## The level file painting `index` lies in for a game mode (Defs.GameMode): COOP = the co-op file of its level
## (`<id>_coop`, by the naming rule of PLAN.md 6.1, whether or not the file exists yet), SINGLE = the solo level, or ""
## when the mode cannot find it (a Book I co-op secret in single-player, versus, an unknown index).
static func painting_file(index: int, mode: int) -> StringName:
	var level_id: StringName = painting_level(index)
	if level_id == &"":
		return &""
	match mode:
		Defs.GameMode.COOP:
			return StringName(String(level_id) + "_coop")
		Defs.GameMode.SINGLE:
			return &"" if is_coop_only(index) else level_id
	return &""


## The paintings that hide in `level_id` (a solo level or its co-op file; a co-op file also holds its Book I secret),
## ascending. Empty for a level without one.
static func paintings_of(level_id: StringName) -> PackedInt32Array:
	var coop: bool = String(level_id).ends_with("_coop")
	var solo: StringName = StringName(String(level_id).trim_suffix("_coop")) if coop else level_id
	var result: PackedInt32Array = PackedInt32Array()
	for index: int in PAINTING_LEVELS.size():
		if PAINTING_LEVELS[index] == solo and (coop or not is_coop_only(index)):
			result.append(index)
	return result


# =================================================================================================================
# Rewards
# =================================================================================================================

## The reward entry of REWARDS with id `reward` ({} when unknown).
static func reward(reward_id: StringName) -> Dictionary:
	for entry: Dictionary in REWARDS:
		if entry["id"] == reward_id:
			return entry
	return {}


## Paintings reward `reward_id` needs (Tuning.PAINTING_COUNT + 1 for an unknown one: never by paintings).
static func paintings_needed(reward_id: StringName) -> int:
	var entry: Dictionary = reward(reward_id)
	return int(entry["paintings"]) if not entry.is_empty() else Tuning.PAINTING_COUNT + 1


## True when reward `reward_id` is open now (Save.is_unlocked: enough paintings, opened by hand, or a versus reward
## while "Unlock everything" is on).
static func is_open(reward_id: StringName) -> bool:
	return Save.is_unlocked(reward_id)


## The rewards that are open now, in ladder order.
static func open_rewards() -> Array[StringName]:
	var result: Array[StringName] = []
	for entry: Dictionary in REWARDS:
		if is_open(entry["id"]):
			result.append(entry["id"])
	return result


## The rewards whose painting count lies in (`before`, `after`]: what finding paintings `before` + 1 .. `after` opens,
## in ladder order (the "new reward" notice; Save.reward_unlocked uses it).
static func rewards_between(before: int, after: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for entry: Dictionary in REWARDS:
		var needed: int = int(entry["paintings"])
		if needed > before and needed <= after:
			result.append(entry["id"])
	return result


## The next reward still closed and the paintings missing for it: {"id": StringName, "missing": int} ({} when every
## reward is open) - the map slab's and the unlocks screen's "N more for ...".
static func next_reward() -> Dictionary:
	for entry: Dictionary in REWARDS:
		if not is_open(entry["id"]):
			return {"id": entry["id"], "missing": maxi(int(entry["paintings"]) - Save.painting_count(), 1)}
	return {}


## The reward that opens arena `arena_id` (&"" for an arena open from the start).
static func reward_of_arena(arena_id: StringName) -> StringName:
	return _reward_listing("arenas", arena_id)


## The reward that opens variant `variant` (&"" for a variant open from the start).
static func reward_of_variant(variant: StringName) -> StringName:
	return _reward_listing("variants", variant)


## The reward that opens palette `palette` (&"" for a colour open from the start).
static func reward_of_palette(palette: StringName) -> StringName:
	return _reward_listing("palettes", palette)


## The reward that opens the loincloth patterns tagged `unlock_tag` in hero_palettes.json (&"" for "default" and for
## an unknown tag).
static func reward_of_pattern(unlock_tag: String) -> StringName:
	return _reward_listing("patterns", unlock_tag)


## True when arena `arena_id` may be offered (an arena without a reward always).
static func is_arena_open(arena_id: StringName) -> bool:
	var reward_id: StringName = reward_of_arena(arena_id)
	return reward_id == &"" or is_open(reward_id)


## True when variant `variant` may be chosen or rolled (Mayhem).
static func is_variant_open(variant: StringName) -> bool:
	var reward_id: StringName = reward_of_variant(variant)
	return reward_id == &"" or is_open(reward_id)


## True when palette `palette` may be chosen.
static func is_palette_open(palette: StringName) -> bool:
	var reward_id: StringName = reward_of_palette(palette)
	return reward_id == &"" or is_open(reward_id)


## True when the loincloth patterns tagged `unlock_tag` may be chosen ("default" always; an unknown tag never).
static func is_pattern_open(unlock_tag: String) -> bool:
	if unlock_tag == PATTERN_DEFAULT:
		return true
	var reward_id: StringName = reward_of_pattern(unlock_tag)
	return reward_id != &"" and is_open(reward_id)


## True when The Long Raft Home ends with the cave mural (every painting found, or the reward opened by hand).
static func is_mural_open() -> bool:
	return is_open(&"mural")


## The first reward whose list `key` holds `value`.
static func _reward_listing(key: String, value: Variant) -> StringName:
	for entry: Dictionary in REWARDS:
		for item: Variant in entry.get(key, []):
			if str(item) == str(value):
				return entry["id"]
	return &""

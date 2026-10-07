class_name VersusRules
extends RefCounted
## The rules of one versus round as the referee applies them (docs/expansion/DESIGN.md E.4, GAMEPLAY.md 13.10.8):
## presets (Classic / Feast / Mayhem), variants, the weapons rule, crates, the sudden-death event toggle, the Stock
## option and the Auto handicap. Owner: world-B (docs/expansion/PLAN.md P2.4).
##
## [method from_match] reads them from core-A's VersusMatch (Game.versus_match, duck-typed: preset, weapons,
## crate_period_ticks(), has_variant(name), sudden_death, stock, round_wins, get_seat(slot).auto_handicap,
## round_seed()); without a match a round plays the Feast preset with no variant (tests set the fields directly).
## Party Mix (arena and mode per round) is the match's own pick (VersusMatch.arena_for_round / mode_for_round): the
## referee only reads `round_mode`.
##
## Mayhem's "random variant per round" is drawn from a SimRng of the round seed (never Sim.rng), so the variant is
## known before the round's first tick and a round stays a pure function of its seed and the inputs.

## Variant names (VersusMatch.variants; DESIGN.md E.4).
const HAMMER_TIME: StringName = &"hammer_time"   ## everyone holds the hammer, the club on the belt
const AXE_RAIN: StringName = &"axe_rain"         ## crates hold only axes, every 194 ticks
const BIG_BOUNCE: StringName = &"big_bounce"     ## head bounces with Up give -288
const ONE_BONK: StringName = &"one_bonk"         ## every hit costs everything
const SLIPPERY: StringName = &"slippery"         ## every floor is ice 2
const LIGHTS_OUT: StringName = &"lights_out"     ## night palette, heroes glow
const GUSTY: StringName = &"gusty"               ## alternating wind 32 / -32 every 66 ticks
const GIANT_RAIN: StringName = &"giant_rain"     ## a giant bonus falls every 364 ticks
const SPEAR_PARTY: StringName = &"spear_party"   ## everyone starts with a spear on the belt that never runs out
const VARIANTS: Array[StringName] = [
	HAMMER_TIME, AXE_RAIN, BIG_BOUNCE, ONE_BONK, SLIPPERY, LIGHTS_OUT, GUSTY, GIANT_RAIN, SPEAR_PARTY,
]
## Variant numbers (GAMEPLAY.md 13.10.8, all (tune)).
const BIG_BOUNCE_YVEL: int = -288
const SLIPPERY_ICE: int = 2
const GUSTY_WIND: int = 32
const GUSTY_PERIOD_TICKS: int = 66
const GIANT_RAIN_PERIOD_TICKS: int = 364
const AXE_RAIN_PERIOD_TICKS: int = 194
## VersusMatch.Preset values (mirrored: the match class is read duck-typed).
const PRESET_CLASSIC: int = 0
const PRESET_FEAST: int = 1
const PRESET_MAYHEM: int = 2
## Mayhem's crates bring a skull this often (out of 8 crates of food; DESIGN.md E.4 "skull spots").
const MAYHEM_SKULL_EIGHTHS: int = 2

## VersusMatch.Preset of the round.
var preset: int = PRESET_FEAST
## Ticks between pterodactyl crates (0 = no crates).
var crate_period: int = VersusTuning.CRATE_PERIOD_TICKS
## Weapons rule `club`: no special comes out of a crate.
var club_only: bool = false
## Variant name -> true for every variant on this round.
var variants: Dictionary = {}
## The themed sudden death as an event in the modes other than Last Caveman Standing.
var sudden_death_event: bool = false
## Last Caveman Standing option Stock (VersusTuning.LCS_STOCKS lives with respawns).
var stock: bool = false
## Per slot: a leaf shield at the round start (the Auto handicap: two round wins behind the leader).
var leaf_shield: PackedByteArray = PackedByteArray([0, 0, 0, 0])
## False for a mode without crates (Clubball).
var mode_has_crates: bool = true


## The rules of the round that `versus_match` (a VersusMatch, or null) is about to play in `mode` (Defs.VersusMode).
static func from_match(versus_match: Object, mode: int) -> VersusRules:
	var rules: VersusRules = VersusRules.new()
	if mode == Defs.VersusMode.CLUBBALL:
		rules.crate_period = 0   # Clubball: club only, no crates (GAMEPLAY.md 13.10.6)
		rules.club_only = true
		rules.mode_has_crates = false
	if versus_match == null:
		return rules
	var preset_value: Variant = versus_match.get(&"preset")
	if preset_value is int:
		rules.preset = int(preset_value)
	if versus_match.has_method(&"crate_period_ticks") and mode != Defs.VersusMode.CLUBBALL:
		rules.crate_period = int(versus_match.call(&"crate_period_ticks"))
	var weapons: Variant = versus_match.get(&"weapons")
	if weapons is StringName or weapons is String:
		rules.club_only = rules.club_only or StringName(str(weapons)) == &"club" or rules.preset == PRESET_CLASSIC
	var listed: Variant = versus_match.get(&"variants")
	if listed is PackedStringArray or listed is Array:
		for name: Variant in listed:
			var variant: StringName = StringName(str(name))
			if VARIANTS.has(variant):
				rules.variants[variant] = true
	if rules.preset == PRESET_MAYHEM:
		var seed_value: int = int(versus_match.call(&"round_seed")) if versus_match.has_method(&"round_seed") else 1
		rules.variants[mayhem_variant(seed_value, mode)] = true
	var toggle: Variant = versus_match.get(&"sudden_death")
	rules.sudden_death_event = toggle is bool and bool(toggle)
	var stock_value: Variant = versus_match.get(&"stock")
	rules.stock = stock_value is bool and bool(stock_value)
	rules.leaf_shield = auto_shields(versus_match)
	rules._apply_variant_rates()
	return rules


## Mayhem's variant of a round: a pick of SimRng(round seed) among the variants that change something in `mode`.
static func mayhem_variant(round_seed: int, mode: int) -> StringName:
	var choices: Array[StringName] = []
	for variant: StringName in VARIANTS:
		if mode == Defs.VersusMode.CLUBBALL and variant in [HAMMER_TIME, AXE_RAIN, SPEAR_PARTY, GIANT_RAIN, ONE_BONK]:
			continue
		if mode != Defs.VersusMode.GRUB_STACK and variant == GIANT_RAIN:
			continue
		choices.append(variant)
	var rng: SimRng = SimRng.new(round_seed * 7 + 0x5EED)
	return choices[rng.pick_index(choices.size())]


## The Auto handicap (DESIGN.md E.4): a seat with `auto_handicap` that is VersusTuning.AUTO_HANDICAP_ROUNDS_BEHIND
## round wins or more behind the leader starts the round with a leaf shield. Per slot 1 / 0.
static func auto_shields(versus_match: Object) -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray([0, 0, 0, 0])
	if versus_match == null:
		return result
	var wins: Variant = versus_match.get(&"round_wins")
	if not wins is PackedInt32Array:
		return result
	var round_wins: PackedInt32Array = wins
	var lead: int = 0
	for value: int in round_wins:
		lead = maxi(lead, value)
	for slot: int in mini(round_wins.size(), Defs.MAX_PLAYERS):
		var seat: Object = versus_match.call(&"get_seat", slot) as Object if versus_match.has_method(&"get_seat") \
				else null
		if seat == null:
			continue
		var auto: Variant = seat.get(&"auto_handicap")
		if auto is bool and bool(auto) and lead - round_wins[slot] >= VersusTuning.AUTO_HANDICAP_ROUNDS_BEHIND:
			result[slot] = 1
	return result


## True when `variant` is on this round.
func has(variant: StringName) -> bool:
	return variants.has(variant)


## Switch a variant on (tests, tools) and apply what it changes in the crate rate.
func set_variant(variant: StringName, on: bool = true) -> void:
	if on:
		variants[variant] = true
	else:
		variants.erase(variant)
	_apply_variant_rates()


## Axe Rain: crates every AXE_RAIN_PERIOD_TICKS whatever the preset says (unless the mode has none: Clubball).
func _apply_variant_rates() -> void:
	if has(AXE_RAIN) and mode_has_crates:
		crate_period = AXE_RAIN_PERIOD_TICKS

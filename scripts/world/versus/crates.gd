class_name VersusCrates
extends RefCounted
## What the pterodactyl crates hold, mode by mode (docs/expansion/DESIGN.md E.3 / E.4, GAMEPLAY.md 13.10.3 /
## 13.10.8). Owner: world-B (PLAN.md P2.4).
##
## The crates themselves - the lanes (`objects/crate_lane rect=c,r,w,h`), the period (Feast 486 ticks, Mayhem 194,
## Axe Rain 194, Classic / Clubball none), the shadow 22 ticks ahead, the fall, the crate one hit opens, temporary
## specials - are objects-B's [CrateLane] (P2.7). A lane asks the level's party driver for its contents
## (VersusReferee.crate_contents(lane) -> [method contents_for]); the referee answers with ItemContents tokens drawn
## from Sim.rng (the round seed):
##  - Grub Stack: one food, one special (none with the weapons rule `club`), one cutlery piece, and a skull or a
##    grenade with SKULL_CHANCE (doubled in Mayhem: its "skull spots").
##  - Last Caveman Standing: a special, a cutlery piece and a heart (the currency); no skull (it would scatter every
##    heart without a knock-out) and no grenade (nothing to blow up).
##  - Hot Rock: a special and a cutlery piece (the feast makes its holder untouchable, so the ember stays put).
##  - Clubball: nothing (club only, no crates).
##  - Axe Rain: a single axe, whatever the mode.

## Specials a crate may hold (items/weapon kinds; they spawn as temporary specials).
const SPECIALS: Array[String] = ["hammer", "axe", "boomerang", "spear"]
## A skull or a grenade with this chance in Grub Stack (doubled with the Mayhem preset).
const SKULL_CHANCE_NUM: int = 1
const SKULL_CHANCE_DEN: int = 4


## The contents of the next crate for `mode` under `rules` (ItemContents tokens; "" = no crate in this mode).
static func contents_for(mode: int, rules: VersusRules) -> String:
	if mode == Defs.VersusMode.CLUBBALL:
		return ""
	if rules != null and rules.has(VersusRules.AXE_RAIN):
		return "weapon:axe"
	var specials: bool = rules == null or not rules.club_only
	var tokens: PackedStringArray = PackedStringArray()
	match mode:
		Defs.VersusMode.LAST_CAVEMAN:
			if specials:
				tokens.append(_special())
			tokens.append(_cutlery())
			tokens.append("heart")
		Defs.VersusMode.HOT_ROCK:
			if specials:
				tokens.append(_special())
			tokens.append(_cutlery())
		_:
			tokens.append("food:%d" % Sim.rng.next_int(ItemTable.FOOD_POINTS.size()))
			if specials:
				tokens.append(_special())
			tokens.append(_cutlery())
			var chance: int = SKULL_CHANCE_NUM * (2 if rules != null and rules.preset == VersusRules.PRESET_MAYHEM else 1)
			if Sim.rng.chance(chance, SKULL_CHANCE_DEN):
				tokens.append("skull" if Sim.rng.next_int(2) == 0 else "grenade")
	return ",".join(tokens)


static func _special() -> String:
	return "weapon:%s" % SPECIALS[Sim.rng.next_int(SPECIALS.size())]


static func _cutlery() -> String:
	return "feast_piece:%d" % Sim.rng.next_int(Tuning.FEAST_PIECES)

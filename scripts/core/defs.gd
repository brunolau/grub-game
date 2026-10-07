class_name Defs
extends RefCounted
## Shared enums, bit masks and names used by every module.
##
## CONTRACT FILE (docs/ARCHITECTURE.md section 3): existing values are frozen. New values may only be
## appended by the core module. Numbers (physics, timers) do not belong here: see [Tuning].

## Difficulty modes (GAMEPLAY.md 1.3).
enum Difficulty { BEGINNER = 0, EXPERT = 1 }

## Weapons in the order of PHYSICS.md 8.1. BOOMERANG is our skin of the original "swirling axe".
## SPEAR (2.0, DESIGN.md C.2) is appended: Book II and co-op only, never carried by a Book I solo run.
enum Weapon { CLUB = 0, HAMMER = 1, AXE = 2, BOOMERANG = 3, SPEAR = 4 }

## Simulation phases, executed in this order once per tick (PHYSICS.md 3). See ARCHITECTURE.md 4.2.
enum Phase {
	FX = 0,               ## step 1: cosmetic puffs
	WEAPONS = 1,          ## step 2: thrown weapons, then last tick's club box, against enemies then hittables
	ENEMIES = 2,          ## step 3: enemies and bosses update (bosses test the club box here)
	PROJECTILES = 3,      ## step 4: thrown weapons and enemy projectiles move
	ITEMS = 4,            ## steps 5-6: dropped items / bones move, score pop-ups rise
	PLATFORMS = 5,        ## step 7: platforms move, then test whether the hero rides them
	PLAYER = 6,           ## step 8: hero update (handler, integrate, tile collision, timers)
	CONTACT_ENEMIES = 7,  ## step 9a: hero versus enemies
	CONTACT_ITEMS = 8,    ## step 9b: hero versus items, checkpoints, exits, hazards, zones
	WORLD = 9,            ## steps 10-12: item refresh, gates, rising columns
	CAMERA = 10,          ## step 13: camera follow
	POST = 11,            ## steps 14-18: hit timers, level state, extra life, light fade, shake apply
}
const PHASE_COUNT: int = 12

## What a [SimEntity] is, for the level's typed entity lists ([method LevelBase.get_kind]).
enum Kind {
	OTHER = 0,
	PLAYER = 1,
	ENEMY = 2,             ## ordinary enemies: tested by the weapon pass and the hero contact pass
	BOSS = 3,              ## bosses: do their own weapon and contact tests
	COLLECTIBLE = 4,
	HITTABLE = 5,          ## hidden spots, breakable blocks, containers: tested by the weapon pass after enemies
	HAZARD = 6,
	PLATFORM = 7,
	HERO_PROJECTILE = 8,
	ENEMY_PROJECTILE = 9,
	CHECKPOINT = 10,
	EXIT = 11,
	ZONE = 12,
	FX = 13,
}
const KIND_COUNT: int = 14

## How the hero is being damaged (PHYSICS.md 10.1).
enum HurtKind {
	ENEMY = 0,            ## enemy contact: -1 heart (or lose the glider), knock-back, 44 tick immunity
	BOSS_BODY = 1,        ## boss body or limb: costs one bone, knock-back +/-128 v16 with ice 3
	BOSS_PROJECTILE = 2,  ## rock / stalactite / ember: -1 heart and 6 bones scattered
	TRAP = 3,             ## skull item: all energy scattered as bones, no death
	## 2.0 versus only (PHYSICS.md C.14): a rival's hit, applied by the referee (world-B) with
	## PlayerBase.hurt(source, RIVAL); the reaction (hit_timer 43, knock-back, the mode's currency) is the hero's party
	## component (player-A, HeroParty.on_hurt). Never used in single-player or co-op.
	RIVAL = 4,
}

## Hero states: the numbers of the state table in PHYSICS.md 4.3.
## 2.0 appends the states outside the 4.3 table (never entered in Book I solo; Tuning.STATE_LUT never yields them):
## CLIMB on a vine (PHYSICS.md C.4, HeroClimb), CURL curled up or flying as a batted ball (C.11, HeroParty;
## PlayerBase.curl tells which), RIDING on a mount's seat (C.9, HeroMount; PlayerBase.mount_seat tells which).
enum HeroState {
	IDLE = 0, WALK = 1, JUMP = 2, STRIKE = 3, CRAWL = 4, CROUCH = 5, HIGH_STRIKE = 6, LOW_STRIKE = 7, HURT = 8,
	CLIMB = 9, CURL = 10, RIDING = 11,
}

## Input device families, for glyph switching and touch overlay visibility.
enum Device { KEYBOARD = 0, GAMEPAD = 1, TOUCH = 2 }

## Scene transitions offered by Flow (GAMEPLAY.md 11.1).
enum Transition { NONE = 0, FADE = 1, CURTAIN = 2, IRIS = 3 }

# --- Input flags -----------------------------------------------------------------------------------------------
# One bit per level-triggered flag of PHYSICS.md 4.1. The low five bits are laid out so that
# (flags & IN_STATE_MASK) is directly the index into Tuning.STATE_LUT.
const IN_FIRE: int = 1
const IN_DOWN: int = 2
const IN_UP: int = 4
const IN_LEFT: int = 8
const IN_RIGHT: int = 16
const IN_LOOK: int = 32
const IN_STATE_MASK: int = 31

# --- InputMap action names -------------------------------------------------------------------------------------
const ACT_LEFT: StringName = &"move_left"
const ACT_RIGHT: StringName = &"move_right"
const ACT_UP: StringName = &"move_up"
const ACT_DOWN: StringName = &"move_down"
const ACT_JUMP: StringName = &"jump"
const ACT_ATTACK: StringName = &"attack"
const ACT_LOOK: StringName = &"look"
const ACT_PAUSE: StringName = &"pause"
## Actions the options menu may rebind (ui_* actions stay on Godot's defaults). 2.0 appends `swap` (ACT_SWAP).
const GAME_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down", &"jump", &"attack", &"look", &"pause", &"swap",
]

# --- Node groups -----------------------------------------------------------------------------------------------
const GROUP_SIM: StringName = &"sim_entities"   ## every SimEntity
const GROUP_LEVEL: StringName = &"level"        ## the active LevelBase node
const GROUP_HUD: StringName = &"hud"            ## HUD root (ui)
const GROUP_TOUCH: StringName = &"touch_controls"

# --- Canvas z_index of gameplay layers (children of the Level node; ARCHITECTURE.md 5.2) -------------------------
const Z_PARALLAX: int = -100
const Z_BACK_TILES: int = -50
const Z_PROPS_BACK: int = -40
const Z_TILES: int = 0
const Z_OBJECTS: int = 10
const Z_PLATFORMS: int = 12
const Z_ITEMS: int = 20
const Z_ENEMIES: int = 30
const Z_PLAYER: int = 40
const Z_PROJECTILES: int = 50
const Z_FX: int = 60
const Z_PROPS_FRONT: int = 70
const Z_FRONT_TILES: int = 80

# --- CanvasLayer numbers ------------------------------------------------------------------------------------------
const LAYER_HUD: int = 10
const LAYER_TOUCH: int = 20
const LAYER_MENU: int = 30
const LAYER_TRANSITION: int = 100
const LAYER_DEBUG: int = 120

# --- 2D physics layer bits (cosmetic Area2D / particles only: gameplay never uses the physics server) ------------
const PHYS_WORLD: int = 1 << 0
const PHYS_PLAYER: int = 1 << 1
const PHYS_ENEMIES: int = 1 << 2
const PHYS_ITEMS: int = 1 << 3
const PHYS_OBJECTS: int = 1 << 4
const PHYS_HAZARDS: int = 1 << 5
const PHYS_PLATFORMS: int = 1 << 6
const PHYS_HERO_WEAPONS: int = 1 << 7
const PHYS_ENEMY_PROJECTILES: int = 1 << 8
const PHYS_TRIGGERS: int = 1 << 9

# --- Level scroll flags (PHYSICS.md 12.2 / 12.4), stored in LevelBase.scroll_flags --------------------------------
const SCROLL_LOW_BAND: int = 1      ## bit 0: alternative vertical band, no hard-landing hop
const SCROLL_NO_HORIZONTAL: int = 2 ## bit 1: vertical-only level
const SCROLL_AUTO_DOWN: int = 4     ## bit 2: auto-scroll down 1 px per tick

# =================================================================================================================
# 2.0 expansion "The Far Shore" (docs/expansion/DESIGN.md; contract step P0.3 of docs/expansion/PLAN.md).
# Appended only: nothing above changes. For a party of one every 1.0 value keeps its meaning (TECH_AUDIT.md 2).
# =================================================================================================================

## Most heroes in one game: versus 2-4, co-op exactly 2 (PartyTuning.COOP_PLAYERS); slot 0 is P1 = the 1.0 hero.
const MAX_PLAYERS: int = 4

## What kind of game runs (Game.mode). SINGLE is the 1.0 game and the default everywhere.
enum GameMode { SINGLE = 0, COOP = 1, VERSUS = 2 }

## Where a player slot's input comes from (GameInput slots, TECH_AUDIT.md 4.3). NONE = the slot is free;
## ALL_DEVICES = every keyboard / pad / touch event, the 1.0 path of slot 0 in single-player.
enum InputSlotKind {
	NONE = 0,
	ALL_DEVICES = 1,     ## single-player slot 0: the unprefixed actions of project.godot
	KEYBOARD_LEFT = 2,   ## left half of a shared keyboard (W A S D ...), DESIGN.md D.11
	KEYBOARD_RIGHT = 3,  ## right half (arrows ...)
	KEYBOARD_FULL = 4,   ## one player on the whole keyboard, the others on pads
	PAD = 5,             ## one gamepad, by its device id
	TOUCH = 6,           ## a touch overlay (one screen region per touch slot)
	BOT = 7,             ## a HeroBot computes the flags (versus, the Rival Chieftains)
	SCRIPT = 8,          ## a route / flow / test feeds the flags (GameInput.set_scripted_slot)
}

## Co-op trait of an enemy record (`coop=<name>` in co-op level files only, DESIGN.md D.6). NONE = plain enemy.
enum CoopTrait { NONE = 0, SHELL = 1, BOND = 2, DAZE = 3, HEAVY = 4, LONE = 5, GRAB = 6, LEECH = 7, SPLIT = 8 }
## Level-file names of the traits, by CoopTrait value ("" = NONE).
const COOP_TRAIT_NAMES: Array[StringName] = [
	&"", &"shell", &"bond", &"daze", &"heavy", &"lone", &"grab", &"leech", &"split",
]

## Versus modes (DESIGN.md E.3 / E.4): the four launch modes, then the second wave.
enum VersusMode {
	GRUB_STACK = 0, LAST_CAVEMAN = 1, HOT_ROCK = 2, CLUBBALL = 3, KING_OF_THE_FEAST = 4, LETTER_SNATCH = 5,
	EGG_HEIST = 6,
}
## Names of the versus modes (arena meta `modes`, settings, save data), by VersusMode value.
const VERSUS_MODE_NAMES: Array[StringName] = [
	&"grub_stack", &"last_caveman", &"hot_rock", &"clubball", &"king_of_the_feast", &"letter_snatch", &"egg_heist",
]

## Bot levels (DESIGN.md E.7): reaction and decisions, never cheating (VersusTuning.BOT_REACTION_TICKS).
enum BotLevel { ROOKIE = 0, HUNTER = 1, CHIEF = 2 }

## Input flag of the Swap action (DESIGN.md C.1): swaps hand and belt. Outside IN_STATE_MASK, so the state table
## never sees it; Book I solo samples it but ignores it (PLAN.md P0.5). Route key letter `S`.
const IN_SWAP: int = 64
## InputMap action behind IN_SWAP (project.godot: V, `;`, pad LB; the last entry of GAME_ACTIONS).
const ACT_SWAP: StringName = &"swap"


## Name of a difficulty, as used in level files and save data ("beginner" / "expert").
static func difficulty_name(difficulty: int) -> String:
	return "expert" if difficulty == Difficulty.EXPERT else "beginner"


## Name of a weapon, as used in asset file names and level files.
static func weapon_name(weapon: int) -> String:
	match weapon:
		Weapon.HAMMER:
			return "hammer"
		Weapon.AXE:
			return "axe"
		Weapon.BOOMERANG:
			return "boomerang"
		Weapon.SPEAR:
			return "spear"
		_:
			return "club"


## Name of a game mode, as used in save namespaces and settings ("single" / "coop" / "versus").
static func game_mode_name(mode: int) -> String:
	match mode:
		GameMode.COOP:
			return "coop"
		GameMode.VERSUS:
			return "versus"
		_:
			return "single"


## Level-file name of a co-op trait ("" for NONE or an unknown value).
static func coop_trait_name(coop_trait: int) -> StringName:
	if coop_trait < 0 or coop_trait >= COOP_TRAIT_NAMES.size():
		return &""
	return COOP_TRAIT_NAMES[coop_trait]


## The CoopTrait of a level-file name (`coop=shell` -> SHELL); -1 for an unknown name, NONE for "".
static func coop_trait_from_name(trait_name: StringName) -> int:
	return COOP_TRAIT_NAMES.find(trait_name)


## Name of a versus mode ("" for an unknown value).
static func versus_mode_name(mode: int) -> StringName:
	if mode < 0 or mode >= VERSUS_MODE_NAMES.size():
		return &""
	return VERSUS_MODE_NAMES[mode]


## The VersusMode of a name (arena meta `modes`), -1 for an unknown name.
static func versus_mode_from_name(mode_name: StringName) -> int:
	return VERSUS_MODE_NAMES.find(mode_name)


## Level scroll flag of format 2 (LevelBase.scroll_flags, beside SCROLL_LOW_BAND / NO_HORIZONTAL / AUTO_DOWN): bit 3,
## `scroll = rising` - the rising tide of PHYSICS.md C.8 (the loader sets it; the band and its camera rule are
## world-A's, PLAN.md P1.6). No 1.0 level has it.
const SCROLL_RISING: int = 8


## The player slot credited with a hit or a kill by `source` (TECH_AUDIT.md 4.8): a hero -> his `slot`
## (PlayerBase.slot), a hero projectile -> its `owner_slot` (ProjectileBase.owner_slot), anything else (an enemy, an
## object, null, a freed node, a non-object) -> -1. In single-player every hero source is P1 (0), as in 1.0.
## Untyped on purpose: a stored last hitter may have been freed since. For attribution (stats, versus credit, co-op
## hit rules); it changes nothing in the simulation.
## Duck-typed (no entity class is named here): Defs is compiled by the tool scripts that run before the autoloads
## exist (tools/world_render_level.gd, tools/validate_levels.gd ...), and the entity classes need the autoloads.
static func hitter_slot(source: Variant) -> int:
	if not is_instance_valid(source):
		return -1
	var object: Object = source as Object
	if object == null or not object.has_method(&"get_kind"):
		return -1
	match int(object.call(&"get_kind")):
		Kind.PLAYER:
			return _slot_field(object, &"slot")
		Kind.HERO_PROJECTILE:
			return _slot_field(object, &"owner_slot")
	return -1


static func _slot_field(entity: Object, field: StringName) -> int:
	var value: Variant = entity.get(field)
	return int(value) if value is int else 0

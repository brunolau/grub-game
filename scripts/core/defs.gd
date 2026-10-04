class_name Defs
extends RefCounted
## Shared enums, bit masks and names used by every module.
##
## CONTRACT FILE (docs/ARCHITECTURE.md section 3): existing values are frozen. New values may only be
## appended by the core module. Numbers (physics, timers) do not belong here: see [Tuning].

## Difficulty modes (GAMEPLAY.md 1.3).
enum Difficulty { BEGINNER = 0, EXPERT = 1 }

## Weapons in the order of PHYSICS.md 8.1. BOOMERANG is our skin of the original "swirling axe".
enum Weapon { CLUB = 0, HAMMER = 1, AXE = 2, BOOMERANG = 3 }

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
}

## Hero states: the numbers of the state table in PHYSICS.md 4.3.
enum HeroState {
	IDLE = 0, WALK = 1, JUMP = 2, STRIKE = 3, CRAWL = 4, CROUCH = 5, HIGH_STRIKE = 6, LOW_STRIKE = 7, HURT = 8,
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
## Actions the options menu may rebind (ui_* actions stay on Godot's defaults).
const GAME_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down", &"jump", &"attack", &"look", &"pause",
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
		_:
			return "club"

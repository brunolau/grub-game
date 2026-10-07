class_name MountTuning
extends RefCounted
## Chomper, the rex you ride: the integer constants of docs/spec/PHYSICS.md C.9 (mount table, constant sheet C.16) and
## the per-tick velocity rules his entity uses (DESIGN.md C.8).
##
## Owner: player-B (docs/expansion/PLAN.md 2.5 "mount constants in MountTuning (player)", 4.1). Read by the mount
## entity (objects-B, `objects/mount`), by the rider's side (HeroMount) and by the tests. *(tune)* values change only
## through DESIGN.md (PLAN 2.3), then here and in PHYSICS.md C.16. The numbers are pinned against
## docs/spec/PARTY_REFERENCE.json ("mount": walk from rest, stop, hop table) by tests/test_player_mount.gd: the
## velocity rules below ([method ground_xvel], [method air_xvel], [method fall_yvel]) reproduce that table exactly when
## applied in the order of C.9 (ground: x velocity, the hop impulse, integrate x then y; airborne: integrate, then
## [method air_xvel] and [method fall_yvel]).

# --- Boxes and seats ----------------------------------------------------------------------------------------------
## Sprite box of the mount (width, height, x_offset), the shipped `rex` box. [P C.9]
const BOX: Vector3i = Vector3i(58, 35, 29)
## The box while ridden: it includes the rider (enemy contacts with it are hits on the mount). [P C.9]
const RIDDEN_BOX: Vector3i = Vector3i(58, 56, 29)
## The driver's feet are this far above the mount's feet point. [P C.9]
const SADDLE_PX: int = 26
## The gunner sits this far behind the driver (x - GUNNER_BEHIND_PX * facing), on the same saddle height (tune with
## the art). [P C.9]
const GUNNER_BEHIND_PX: int = 14

# --- Motion (v16, ticks) --------------------------------------------------------------------------------------------
## Walking speed cap: 4 px/tick. [P C.9]
const WALK_CAP: int = 64
## Ground and air acceleration per tick while a direction is held (`>> ice`, the hero's primitive). [P C.9]
const ACCEL: int = 16
## Braking per tick on the ground with no direction held (`>> ice`). [P C.9]
const FRICTION: int = 12
## The hop: one impulse, no variable height (rise 55 px, lands on tick 21). [P C.9]
const HOP: int = -160
## Gravity, terminal speed and the jump lock-out after a fall: the hero's values. [P C.9]
const GRAVITY: int = Tuning.GRAVITY
const TERMINAL: int = Tuning.TERMINAL
const NO_JUMP: int = Tuning.NO_JUMP_TICKS
## Wall probe: this many px ahead of the feet point, in rows `row - 1` and `row - 2`. [P C.9]
const WALL_PROBE: int = 20
## Head probe: a ceiling at `row - HEAD_PROBE_ROWS_*` blocks ("4 rows of air" ridden, 3 unridden). [P C.9]
const HEAD_PROBE_ROWS_RIDDEN: int = 4
const HEAD_PROBE_ROWS_UNRIDDEN: int = 3
## The mount's own stomp (its feet land on an enemy with the stomp flag): this yvel, the enemy unharmed. [P C.9]
const STOMP_YVEL: int = -64

# --- The bite (the driver's FIRE) -----------------------------------------------------------------------------------
## The bite script lasts this many ticks; FIRE held repeats it every BITE_TICKS. [P C.9]
const BITE_TICKS: int = 8
## Script ticks (1-based) on which the bite box is live (tested in the next tick's WEAPONS phase). [P C.9]
const BITE_LIVE_FIRST: int = 5
const BITE_LIVE_LAST: int = 6
## The bite box from the feet point, facing right (mirrored when facing left): x +0 .. +40, y -35 .. -6 ("knee to
## head"). [P C.9]
const BITE_BOX: Rect2i = Rect2i(0, -35, 40, 29)
## An enemy with hp below this is eaten (vanishes into the jaws, pays its score + FOOD_BONUS). [P C.9]
const EAT_HP: int = 50
## Displayed points added to an eaten enemy's score (tune). [P C.9]
const FOOD_BONUS: int = 500
## Damage of a bite on an enemy with hp >= EAT_HP (bosses ignore bites). [P C.9]
const BITE_POWER: int = 25

# --- Hits, bolting, mounting ----------------------------------------------------------------------------------------
## A hit on the ridden mount throws every rider off: xvel +/-HIT_XVEL away from the source, yvel HIT_YVEL,
## hit_timer HIT_TIMER (stunned and blinking as PHYSICS.md 10.1) and no heart lost. [P C.9]
const HIT_XVEL: int = 64
const HIT_YVEL: int = -128
const HIT_TIMER: int = Tuning.HIT_TIMER
## Ticks the mount stays away after a hit, then it waits in its pen. [P C.9]
const BOLT_TICKS: int = 132
## Ticks a hero cannot sit down again after leaving the saddle. [P C.9]
const REMOUNT_LOCK: int = 22
## Dismount (DOWN + UP): launch(0, DISMOUNT_YVEL) from the seat. [P C.9]
const DISMOUNT_YVEL: int = -128
## A wild rex is tamed by this many head bounces with no grounded tick and no hurt in between. [P C.9]
const TAME_BOUNCES: int = 3
## A wild rex paces +/- this many cells from its pen at WILD_PACE_V16 (tune). [P C.9]
const WILD_PACE_CELLS: int = 3
const WILD_PACE_V16: int = 16
## A wild rex's stomp bounce (the enemy bounce of PHYSICS.md 9: UP held / not held). [P C.9]
const WILD_BOUNCE_YVEL_UP: int = Tuning.BOUNCE_YVEL_UP
const WILD_BOUNCE_YVEL: int = Tuning.BOUNCE_YVEL


# --- Velocity rules (PHYSICS.md C.9 "Update") -----------------------------------------------------------------------

## One grounded tick of the mount's x velocity: a direction held (`dir` -1 / +1) is ACCEL(WALK_CAP) towards it (the
## hero's ACCEL primitive: the step, then the clamp), none is FRICTION (towards 0, never past it). `ice` 0..3 as the
## hero's floors.
static func ground_xvel(xvel: int, dir: int, ice: int = 0) -> int:
	if dir != 0:
		return clampi(xvel + signi(dir) * (ACCEL >> ice), -WALK_CAP, WALK_CAP)
	var magnitude: int = maxi(absi(xvel) - (FRICTION >> ice), 0)
	return -magnitude if xvel < 0 else magnitude


## One airborne tick of the mount's x velocity, after the position was integrated: ACCEL(WALK_CAP) while a direction
## is held, otherwise unchanged (no air friction).
static func air_xvel(xvel: int, dir: int, ice: int = 0) -> int:
	if dir == 0:
		return xvel
	return clampi(xvel + signi(dir) * (ACCEL >> ice), -WALK_CAP, WALK_CAP)


## Gravity of one airborne tick, capped at TERMINAL.
static func fall_yvel(yvel: int) -> int:
	return mini(yvel + GRAVITY, TERMINAL)


## True when a grounded mount whose driver holds `flags` (Defs.IN_*) hops this tick (UP with no_jump at 0). DOWN + UP
## is the dismount, never a hop.
static func wants_hop(flags: int, no_jump: int) -> bool:
	return (flags & Defs.IN_UP) != 0 and (flags & Defs.IN_DOWN) == 0 and no_jump == 0


## The direction (-1, 0, +1) the driver's `flags` steer: LEFT or RIGHT alone; both or none = 0.
static func steer(flags: int) -> int:
	var left: bool = (flags & Defs.IN_LEFT) != 0
	var right: bool = (flags & Defs.IN_RIGHT) != 0
	if left == right:
		return 0
	return 1 if right else -1


## True when `flags` are the dismount of either seat (DOWN + UP held together).
static func is_dismount(flags: int) -> bool:
	return (flags & (Defs.IN_DOWN | Defs.IN_UP)) == (Defs.IN_DOWN | Defs.IN_UP)


## The bite box of a mount at `feet` facing `facing` (+1 / -1) as Rect2i(left, top, w, h) in logical px, and its
## x_offset for Overlap.weapon (the feet point's distance from the box's left edge).
static func bite_rect(feet: Vector2i, facing: int) -> Rect2i:
	var left: int = feet.x + BITE_BOX.position.x if facing >= 0 else feet.x - BITE_BOX.position.x - BITE_BOX.size.x
	return Rect2i(left, feet.y + BITE_BOX.position.y, BITE_BOX.size.x, BITE_BOX.size.y)


## Feet point of a rider on `seat` (PlayerBase.SEAT_DRIVER / SEAT_GUNNER) of a mount at `feet` facing `facing`.
static func seat_point(feet: Vector2i, facing: int, seat: int) -> Vector2i:
	var behind: int = GUNNER_BEHIND_PX * facing if seat == PlayerBase.SEAT_GUNNER else 0
	return Vector2i(feet.x - behind, feet.y - SADDLE_PX)

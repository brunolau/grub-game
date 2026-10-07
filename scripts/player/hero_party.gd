class_name HeroParty
extends RefCounted
## The hero's side of the party rules (docs/spec/PHYSICS.md C.10-C.13; DESIGN.md D): the egg (down, drift, nudge,
## Expert return, voluntary egg), the hatch shield, the curl and the batted ball, the bat and the hatch by his own
## weapons, the edge walls of the tribe camera and the leash count; in versus his hurt reactions.
##
## Owner: player-A (docs/expansion/PLAN.md 4.1); the party-wide steps (Totem Ride, head contacts, team wipe, egg
## drift targets) are world-A's PartyDriver (LevelBase.register_party_driver). A component of [Player], created with
## him; the calls below are the hooks of PLAN.md P0.8 and are made only while [member active] is true (co-op or
## versus with more than one hero). The bodies are minimal on purpose: phase 1 (PLAN.md P1.4) fills them in. A party
## of one never switches it on (TECH_AUDIT.md 2: N = 1 is the identity).
##
## Hook order inside the hero's phases:
##  - WEAPONS: [method weapon_pass] before his box and his throws meet enemies (a box first tests curled partners -
##    the bat - and eggs - the hatch; PHYSICS.md C.0 table); it consumes what it uses (`hero.club_box_active = false`,
##    `projectile.consume()`).
##  - PLAYER: [method update] first of all components, right after 8b (egg, curl and ball flight run the hero's
##    PLAYER phase themselves: return true). Edge walls: PlayerBase.fence_x() before the x step.
##  - POST: [method post_step] after the hit timer (shield, egg, leash count).
##  - Player.hurt asks [method on_hurt] before the 1.0 hurt (a curl ends on a hurt; versus hurt table C.14).

## The hero this component belongs to.
var hero: Player = null
## True while the hooks run. Default false: a party of one is the 1.0 hero.
var active: bool = false


func _init(p_hero: Player) -> void:
	hero = p_hero


## The hero entered a level (Player._ready): switch on in a party (Game.mode COOP / VERSUS with level.hero_count() >
## 1, or Game.party > 1 before the partners are spawned). Minimal body: stays off.
func setup(_level: LevelBase) -> void:
	pass


## WEAPONS phase, before the 1.0 weapon pass: bat curled partners, hatch eggs (PHYSICS.md C.11, C.12).
func weapon_pass(_level: LevelBase) -> void:
	pass


## PLAYER phase, right after 8b: the egg, the curl start (Down + Swap), the curled state and the ball flight. True = it
## ran the rest of the hero's PLAYER phase this tick.
func update(_level: LevelBase) -> bool:
	return false


## Step 8i of the hero's own timers.
func tick_timers() -> void:
	pass


## POST phase, after the hit timer: the shield countdown (PlayerBase.shield), the egg, the leash count.
func post_step(_level: LevelBase) -> void:
	pass


## The hero was hurt (after the immunity checks of Player.hurt). True = handled here instead of the 1.0 hurt (the
## versus hurt table); a curl simply ends (false: the 1.0 hurt follows).
func on_hurt(_source: SimEntity, _kind: int) -> bool:
	return false


## The hero respawned (team wipe, versus respawn; PlayerBase.respawn_at already cleared down, shield and curl).
func on_respawn() -> void:
	pass

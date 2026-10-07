class_name HeroParty
extends RefCounted
## The hero's side of the party rules (docs/spec/PHYSICS.md C.10-C.14; DESIGN.md D, E.2): the egg (its box, picture
## and the voluntary egg), the hatch shield, the curl and the batted ball's flight and contacts, the bat by a strike in
## versus, the edge walls in his own x steps, the Totem rider's own update and drop; in versus his hurt reactions,
## hit-stop, squash and the end of his immunity on a strike; the emote bubble.
##
## Owner: player-A (docs/expansion/PLAN.md 4.1, P1.4). The party-wide steps are world-A's PartyDriver
## (scripts/world/party_driver.gd, LevelBase.register_party_driver; split agreed in build/engine_requests/): in co-op it
## fences the heroes into LevelBase.get_edge_walls() (WEAPONS), runs the Batter Up launch and the hatch by a box
## (PartyDriver.weapon_pass, called first by [method weapon_pass]), the Totem carry and the head contacts through the
## hero-side primitives PlayerBase.carry_totem() / land_on_partner() (PLAYER), the leash, the egg drift and the team
## wipe (POST), and turns a finished death toss into an egg (handle_hero_death, reading PlayerBase.death_origin /
## death_cause). In versus world-B's referee applies the PvP hits (PlayerBase.hurt with Defs.HurtKind.RIVAL), sets
## hit_stop and squash and the weight caps. Nothing here repeats a driver rule: a party level without a driver gets
## LevelBase's neutral defaults for them (TECH_AUDIT.md 4.7). The bat by a front box is this file's in versus only
## (the referee leaves it to the hero, world-B's agreement), the driver's in co-op.
## A component of [Player], created with him; the hooks below run only while [member active] is true: co-op or versus
## with more than one hero. A party of one never switches it on (TECH_AUDIT.md 2: N = 1 is the identity).
##
## Hook order inside the hero's phases:
##  - WEAPONS: [method weapon_pass] before his box and his throws meet enemies (a box first tests curled partners -
##    the bat - and eggs - the hatch; PHYSICS.md C.0 table: the PartyDriver's in co-op); what is used is consumed
##    (`hero.club_box_active = false`, `projectile.consume()`).
##  - PLAYER: a versus hit-stop skips the whole phase ([method hold_hit_stop], before 8b); [method update] first of all
##    components, right after 8b (egg, curl and ball run the hero's PLAYER phase themselves and return true; a curl and
##    a ball obey the driver's edge-wall fence; the Totem rider stands on his carrier's head or drops through it).
##  - CONTACT_ENEMIES: a ball's contacts are [method ball_contacts]; a croucher's Brace Wall is Player._brace_stops.
##  - POST: [method post_step] after the hit timer (shield, squash, the egg's and the emote's pictures).
##  - Player.hurt asks [method on_hurt] before the 1.0 hurt (versus: the hurt table C.14; a curl or a ride ends).

## Emote bubbles (DESIGN.md D.11, E.9: a double tap of Look; the direction held on the second tap picks it).
enum Emote { NONE = -1, EXCLAIM = 0, QUESTION = 1, HEART = 2, ANGRY = 3 }
## Two presses of Look at most this many ticks apart are a double tap.
const EMOTE_DOUBLE_TAP_TICKS: int = 10
## An emote bubble shows this long (2 s).
const EMOTE_TICKS: int = 48
## Ticks a hatched egg's shell stays on screen (hero_egg.png hatch 6-7 at 12 fps).
const SHELL_TICKS: int = 4
## hero_egg.png (ASSET_MANIFEST.md: 8 x 1 cells of 64 x 88 art px, pivot (32, 72)): float 0 / 3, nudge 1 / 2, crack
## 4-5, hatch 6-7.
const EGG_SHEET_PATH: String = "res://assets/sprites/player/hero_egg.png"
const EGG_FRAMES: int = 8
const EGG_OFFSET: Vector2 = Vector2(-32.0, -72.0)
const EGG_FRAME_FLOAT_A: int = 0
const EGG_FRAME_FLOAT_B: int = 3
const EGG_FRAME_NUDGE_LEFT: int = 1
const EGG_FRAME_NUDGE_RIGHT: int = 2
const EGG_FRAME_CRACK: int = 4
const EGG_FRAME_HATCH: int = 6
const EGG_FLOAT_FPS: int = 4
const EGG_CRACK_TICKS: int = 24   ## Expert: the crack frames show this long before the egg flies to the checkpoint
## The bubble's centre above the feet point, art px.
const BUBBLE_Y: float = -100.0

## The hero this component belongs to.
var hero: Player = null
## True while the hooks run. Default false: a party of one is the 1.0 hero.
var active: bool = false
## Co-op rules (Game.mode COOP): edge walls, leash, eggs, voluntary egg, hatching.
var coop: bool = false
## Versus rules (Game.mode VERSUS): the hurt table, hit-stop, squash, the end of the immunity on a strike.
var versus: bool = false
## Ticks since this hero became an egg (the crack frames before the Expert return; the driver keeps its own clock).
var egg_ticks: int = 0
## The emote shown now (Emote) and its ticks left (cosmetic; [signal Player.emoted] announces it).
var emote: int = Emote.NONE
var emote_ticks: int = 0

var _curl_ticks: int = 0
var _ball_ticks: int = 0
var _ball_grounder: bool = false
## Enemies and hittables this ball has met in its current flight (each once per flight, C.11).
var _ball_enemies: Array[SimEntity] = []
var _ball_spots: Array[SimEntity] = []
var _volunteer_ticks: int = 0
var _egg_nudge: int = 0
## True while hit_timer is a versus hurt timer (it ends when he starts a strike, C.14).
var _rival_immune: bool = false
var _look_tap_tick: int = -1000
var _shell_ticks: int = 0
var _shell_pos: Vector2i = Vector2i.ZERO
var _egg_sprite: Sprite2D = null
var _bubble: EmoteBubble = null


func _init(p_hero: Player) -> void:
	hero = p_hero


## The hero entered a level (Player._ready): switch on in a party - Game.mode COOP or VERSUS with Game.party > 1 (the
## partners are spawned after P1, so the run's party size decides, not level.hero_count()).
func setup(_level: LevelBase) -> void:
	active = Game.party > 1 and (Game.mode == Defs.GameMode.COOP or Game.mode == Defs.GameMode.VERSUS)
	coop = active and Game.mode == Defs.GameMode.COOP
	versus = active and Game.mode == Defs.GameMode.VERSUS


# =================================================================================================================
# WEAPONS: the bat and the hatch (PHYSICS.md C.11, C.12 a)
# =================================================================================================================

## Before the 1.0 weapon pass. Co-op: PartyDriver.weapon_pass(hero) - his throws and his box hatch eggs and bat curled
## partners first. Versus: his last-tick club box bats a curled rival or teammate with a front frame of the club or the
## hammer (C.11, C.14). Whatever is used is consumed (one target per box).
func weapon_pass(level: LevelBase) -> void:
	if level.hero_count() <= 1:
		return
	if coop:
		# Co-op: the PartyDriver's (Batter Up launch and the hatch by a box or a throw, PLAN.md P1.6).
		if _driver(level, &"weapon_pass"):
			level.party_driver.call(&"weapon_pass", hero)
		return
	var heroes: Array[PlayerBase] = level.contact_order()
	if hero.club_box_active and not hero.dead:
		for other: PlayerBase in heroes:
			if other == hero or other.dead:
				continue
			if other.curl == PlayerBase.CURL_CURLED and _bats(other):
				return


## The bat test of one curled hero (PHYSICS.md C.11): a front frame (forward front = line drive, high front = lob,
## low front = grounder) of a melee weapon whose box overlaps him (weapon test). Charged (the box was made while
## charge > 0: power x4) launches x3/2, each component clamped by PlayerBase.launch to +/-288.
func _bats(other: PlayerBase) -> bool:
	var weapon: int = hero.run.weapon
	if Tuning.WEAPON_THROWN[weapon]:
		return false
	var xv: int = 0
	var yv: int = 0
	match hero.club_frame:
		Tuning.ClubFrame.FWD_FRONT:
			xv = PartyTuning.BAT_LINE_DRIVE_XVEL
			yv = PartyTuning.BAT_LINE_DRIVE_YVEL
		Tuning.ClubFrame.HIGH_FRONT:
			xv = PartyTuning.BAT_LOB_XVEL
			yv = PartyTuning.BAT_LOB_YVEL
		Tuning.ClubFrame.LOW_FRONT:
			xv = PartyTuning.BAT_GROUNDER_XVEL
			yv = 0
		_:
			return false
	if not Overlap.weapon(hero.club_box, hero.club_box_xo, other):
		return false
	if hero.club_power > Tuning.WEAPON_POWER[weapon]:
		xv = PartyTuning.bat_charged(xv)
		yv = -PartyTuning.bat_charged(-yv)
	hero.club_box_active = false
	other.bat(xv * hero.facing, yv, hero)
	PlayerBase._party_cue(Sfx.BAT_HIT)
	return true


# =================================================================================================================
# PLAYER
# =================================================================================================================

## A versus hit-stop tick (PlayerBase.hit_stop > 0, PHYSICS.md C.14): the hero's PLAYER phase is skipped (no input, no
## facing, no motion); the count goes down. Called by Player before step 8b.
func hold_hit_stop() -> void:
	hero.hit_stop -= 1


## Right after 8b. True = this component ran the rest of the hero's PLAYER phase (egg, curl, ball).
func update(level: LevelBase) -> bool:
	var flags: int = hero._raw_flags
	# Swap is edge-triggered (PHYSICS.md C.1), read as the belt reads it (GameInput's flags of the previous tick).
	var swap_pressed: bool = (flags & Defs.IN_SWAP) != 0 and (GameInput.get_prev_flags(hero.slot) & Defs.IN_SWAP) == 0
	_watch_emote()
	if hero.down:
		_egg_input()
		return true
	if hero.curl == PlayerBase.CURL_BALL:
		_ball_tick(level)
		return true
	if hero.curl == PlayerBase.CURL_CURLED:
		if (flags & Defs.IN_DOWN) != 0 and _curl_ticks < PartyTuning.CURL_MAX_TICKS:
			_curl_tick(level)
			return true
		# DOWN released or 66 ticks curled: state idle, the belt's swap lock-out; the normal update runs this tick.
		_uncurl()
		var belt: Object = hero.hero_belt
		if belt != null and &"swap_lock" in belt:
			belt.set(&"swap_lock", Tuning.SWAP_LOCKOUT_TICKS)
	if versus and hero.squash > 0:
		hero._raw_flags &= ~(Defs.IN_UP | Defs.IN_FIRE)
	if swap_pressed and (flags & Defs.IN_DOWN) != 0 and _may_curl():
		_start_curl()
		_curl_tick(level)
		return true
	if coop and _volunteer(level, flags):
		return true
	if hero.totem_carrier != null:
		if (flags & (Defs.IN_DOWN | Defs.IN_UP)) == (Defs.IN_DOWN | Defs.IN_UP):
			hero.drop_from_totem()
		else:
			# Riding the carrier's head (the platform rule of PHYSICS.md 11.4): no gravity in his own update.
			hero.on_platform = true
	return false


## True when Swap with Down held curls this hero up (PHYSICS.md C.11): standing on a floor or platform, no strike
## running, not hurt-stunned, climbing, riding a partner or a mount, carrying a rider, nor gliding. In co-op and
## versus a Down + Swap never swaps the belt (C.1), curl or not (player-B's belt asks [method swap_is_curl]).
func _may_curl() -> bool:
	if not (hero.on_platform or (hero.grounded and hero.yvel == 0)):
		return false
	return not hero.attack_gate and hero.hit_timer < hero._stun_min and hero.state != Defs.HeroState.CLIMB \
			and hero.mount == null and hero.totem_carrier == null and hero.totem_rider == null and not hero.is_gliding()


## True when the Swap press in `flags` is the curl's (Down held) and not a belt swap: in co-op and versus
## (PHYSICS.md C.1). For the belt (player-B), which must not swap on it.
func swap_is_curl(flags: int) -> bool:
	return active and (flags & Defs.IN_DOWN) != 0


# --- Curl and ball (PHYSICS.md C.11) ---------------------------------------------------------------------------------

func _start_curl() -> void:
	hero.curl = PlayerBase.CURL_CURLED
	hero.ball_batter = null
	hero.attack_gate = false
	hero.state = Defs.HeroState.CURL
	hero.handler = Defs.HeroState.CURL
	hero.set_box(curl_box())
	_curl_ticks = 0
	PlayerBase._party_cue(Sfx.CURL)


## The curl box 24 x 20, x_offset 12 (PartyTuning.CURL_BOX_*), as Vector3i(w, h, x_offset).
static func curl_box() -> Vector3i:
	return Vector3i(PartyTuning.CURL_BOX_W, PartyTuning.CURL_BOX_H, PartyTuning.CURL_BOX_XO)


## One curled tick: FRICTION only (every input but DOWN ignored), the x and y steps, the tile collision, the timers.
## The curl ends (in [method update]) when DOWN is released or after PartyTuning.CURL_MAX_TICKS.
func _curl_tick(level: LevelBase) -> void:
	hero.facing = hero._facing_at_tick_start
	hero._lr_held = false
	_curl_ticks += 1
	hero.state = Defs.HeroState.CURL
	hero.handler = Defs.HeroState.CURL
	hero.input_flags = 0
	hero._friction()
	_x_step(level, false)
	hero.sim_pos.y += Tuning.floor16(hero.yvel)
	hero._collide(level, Tuning.HERO_PROBE_H_CROUCH)
	if hero.dead:
		return
	hero._tick_timers(level)
	hero.set_box(curl_box())


## A batted ball's tick (inputs ignored): x step with the commit rule and the edge walls (a wall only zeroes xvel),
## y step, the touches of hittables, the hero's tile collision with gravity only in the air; a SIDE-1 wall ends the
## flight (he falls as a hero), a landing ends a line drive or a lob (Player._land), a grounder rolls on for
## PartyTuning.BAT_GROUNDER_TICKS.
func _ball_tick(level: LevelBase) -> void:
	hero.facing = hero._facing_at_tick_start
	hero._lr_held = false
	hero.input_flags = 0
	hero.state = Defs.HeroState.CURL
	hero.handler = Defs.HeroState.CURL
	_ball_ticks += 1
	_x_step(level, true)
	hero.sim_pos.y += Tuning.floor16(hero.yvel)
	_ball_touch_hittables(level)
	hero.wall_bumped = false
	hero._collide(level, Tuning.HERO_PROBE_H_CROUCH)
	if hero.dead:
		return
	if hero.curl == PlayerBase.CURL_BALL and hero.wall_bumped:
		_uncurl()
	elif hero.curl == PlayerBase.CURL_BALL and _ball_grounder and _ball_ticks >= PartyTuning.BAT_GROUNDER_TICKS:
		hero.xvel = 0
		_uncurl()
	hero._tick_timers(level)
	if hero.curl != PlayerBase.CURL_NONE:
		hero.set_box(curl_box())


## The x step of a curled hero or a ball: committed inside the level bounds and this tick's fence (the edge walls of
## the tribe camera, C.13: a ball's refused step zeroes its xvel; the level bounds keep it, the commit rule).
func _x_step(level: LevelBase, ball: bool) -> void:
	var next_x: int = hero.sim_pos.x + Tuning.floor16(hero.xvel)
	var inside: bool = next_x >= Tuning.X_MIN and next_x < level.grid.x_max_excl()
	var walled: bool = hero._fenced and not hero.fence_allows(next_x)
	if inside and not walled:
		hero.sim_pos.x = next_x
	elif walled and ball:
		hero.xvel = 0
	hero.clear_fence()


## The ball touches hittables with its box grown by 1 px (PHYSICS.md C.11): a breakable `$` block breaks at once (it
## opens with every block it touches), any other hittable (hidden spot, rolled vine, drum) takes one hit, each once
## per flight.
func _ball_touch_hittables(level: LevelBase) -> void:
	var box: Rect2i = Rect2i(hero.sim_pos.x - hero.box_xo - 1, hero.sim_pos.y - hero.box_h - 1, hero.box_w + 2,
			hero.box_h + 2)
	for entity: SimEntity in level.get_kind(Defs.Kind.HITTABLE):
		if _ball_spots.has(entity):
			continue
		if entity.has_method(&"coil_rect"):
			# A rolled vine (objects-B's Vine): its coil box unrolls under the ball (C.4).
			if Overlap.rects(box, entity.call(&"coil_rect")) and entity.has_method(&"unroll"):
				_ball_spots.append(entity)
				entity.call(&"unroll", hero)
			continue
		var hittable: HittableBase = entity as HittableBase
		if hittable == null or hittable.opened:
			continue
		var cell: Rect2i = Rect2i(hittable.cell * Tuning.TILE, Vector2i(Tuning.TILE, Tuning.TILE))
		if not Overlap.rects(box, cell):
			continue
		_ball_spots.append(hittable)
		if hittable.spot_kind == &"block":
			hittable.hits_left = 1
			hittable.cooldown = 0
		hittable.take_hit(PartyTuning.BALL_POWER, hero)


## The ball's CONTACT_ENEMIES (PHYSICS.md C.11): an enemy with hp < 50 takes 25 once per flight and the ball flies on;
## a bigger one hurts the ball as an enemy contact does (10.1), which ends the flight. A feast still eats.
func ball_contacts(level: LevelBase) -> void:
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var enemy: EnemyBase = entity as EnemyBase
		if enemy == null or not enemy.awake or not enemy.contact_hurts or not enemy.is_targetable():
			continue
		if _ball_enemies.has(enemy) or not Overlap.body(hero, enemy, hero):
			continue
		if hero.feast > 0:
			enemy.kill(&"feast", hero)
			continue
		if enemy.hp < PartyTuning.BALL_KNOCK_HP_EXCL:
			_ball_enemies.append(enemy)
			enemy.take_hit(PartyTuning.BALL_POWER, hero)
			continue
		if hero.hurt(enemy):
			enemy.on_hurt_hero(hero)
		return


## The ball landed on a floor (Player._land, before the landing rules of 6.5). A line drive or a lob uncurls with the
## soft-landing bookkeeping and no_jump = 6 (the landing lock-out) and stops where it lands (xvel 0: the 153 px of a
## line drive are where the hero stands, not where a 9 px/tick slide begins); a grounder keeps rolling.
func ball_landed() -> void:
	hero.yvel = 0
	hero.jump_ticks = 0
	hero.last_ground_y = hero.sim_pos.y
	if _ball_grounder:
		return
	hero.no_jump = Tuning.NO_JUMP_TICKS
	hero.xvel = 0
	_uncurl()


## PlayerBase.bat() made this hero a ball: start the flight bookkeeping.
func on_batted() -> void:
	_ball_ticks = 0
	_ball_grounder = hero.yvel == 0
	_ball_enemies.clear()
	_ball_spots.clear()
	hero.state = Defs.HeroState.CURL
	hero.handler = Defs.HeroState.CURL
	hero.attack_gate = false
	hero.set_box(curl_box())


func _uncurl() -> void:
	hero.curl = PlayerBase.CURL_NONE
	hero.ball_batter = null
	hero.state = Defs.HeroState.IDLE
	hero.handler = Defs.HeroState.IDLE
	hero.set_box(Tuning.HERO_BOX_STAND)
	_curl_ticks = 0
	_ball_ticks = 0
	_ball_grounder = false
	_ball_enemies.clear()
	_ball_spots.clear()


# --- Egg (PHYSICS.md C.12) -------------------------------------------------------------------------------------------

## The egg's PLAYER tick: no tile collision, no handler; the owner's Left / Right nudge it in POST. An egg's controls
## are off (PlayerBase.go_down), so the nudge reads his slot's flags directly.
func _egg_input() -> void:
	hero.facing = hero._facing_at_tick_start
	var flags: int = GameInput.get_flags(hero.slot)
	var left: bool = (flags & Defs.IN_LEFT) != 0
	var right: bool = (flags & Defs.IN_RIGHT) != 0
	_egg_nudge = 0
	if left and not right:
		_egg_nudge = -PartyTuning.EGG_NUDGE_PX
	elif right and not left:
		_egg_nudge = PartyTuning.EGG_NUDGE_PX


## Voluntary egg (PHYSICS.md C.12): Down + Look held together for PartyTuning.VOLUNTARY_EGG_HOLD_TICKS consecutive ticks
## while grounded and a partner is hatched. True = he became an egg on this tick.
func _volunteer(level: LevelBase, flags: int) -> bool:
	var both: int = Defs.IN_DOWN | Defs.IN_LOOK
	if (flags & both) != both or not hero.is_grounded() or partner(level) == null:
		_volunteer_ticks = 0
		return false
	_volunteer_ticks += 1
	if _volunteer_ticks < PartyTuning.VOLUNTARY_EGG_HOLD_TICKS:
		return false
	_volunteer_ticks = 0
	hero.go_down(&"voluntary")
	return true


## Player.kill(): a curl and a ride end (Player.kill recorded PlayerBase.death_origin / death_cause, where the egg
## appears).
func on_killed(_cause: StringName) -> void:
	_end_moves()


## Player.go_down() made this hero an egg (`from_toss`: at the end of his death toss, else at once - the leash, the
## voluntary egg). Box 24 x 24. The PartyDriver places the egg (where the toss started, PlayerBase.death_origin,
## clamped into the party frame) and moves it.
func on_down(_cause: StringName, _from_toss: bool) -> void:
	_end_moves()
	egg_ticks = 0
	_egg_nudge = 0
	_volunteer_ticks = 0
	_rival_immune = false
	hero.leash = 0
	hero.set_box(egg_box())
	hero.run.deaths += 1
	PlayerBase._party_cue(Sfx.EGG_DOWN)
	_show_egg(true)


## The egg box 24 x 24, x_offset 12 (PartyTuning.EGG_BOX_*), as Vector3i(w, h, x_offset).
static func egg_box() -> Vector3i:
	return Vector3i(PartyTuning.EGG_BOX_W, PartyTuning.EGG_BOX_H, PartyTuning.EGG_BOX_XO)


## The egg hatched (Player.hatch after PlayerBase.hatch): the shell left behind, the partner's tally, a doze decision
## for his place (an egg is no hero rectangle, PHYSICS.md C.15).
func on_hatched(by: PlayerBase) -> void:
	_shell_pos = hero.sim_pos
	_shell_ticks = SHELL_TICKS
	egg_ticks = 0
	if by != null and by.run != null:
		by.run.revives += 1
	PlayerBase._party_cue(Sfx.EGG_HATCH)
	var level: LevelBase = Game.level
	if level != null:
		level.notify_hero_teleported(hero)


# --- Edge walls (PHYSICS.md C.13) -----------------------------------------------------------------------------------

## True when the co-op edge walls (LevelBase.get_edge_walls: the authentic 20-column frame of the tribe camera,
## 8 px inside its sides; the PartyDriver fences every hero of the tribe with them) let this hero stand at `x`; always
## true for a hero outside the tribe (an egg, a death toss) and outside co-op.
func edge_walls_allow(level: LevelBase, x: int) -> bool:
	if not coop or not _in_tribe(hero):
		return true
	var walls: Vector2i = level.get_edge_walls()
	return walls.y <= walls.x or (x >= walls.x and x < walls.y)


## The first other hero of the level who is hatched and alive (co-op: the partner), null when none.
func partner(level: LevelBase) -> PlayerBase:
	if level == null:
		return null
	for other: PlayerBase in level.contact_order():
		if other != hero and _in_tribe(other):
			return other
	return null


static func _in_tribe(member: PlayerBase) -> bool:
	return member != null and not member.dead and not member.down


## True when `level` has a PartyDriver with the method `method`.
static func _driver(level: LevelBase, method: StringName) -> bool:
	return level != null and is_instance_valid(level.party_driver) and level.party_driver.has_method(method)


## Step 8i of the hero's own timers: the drop lock of the Totem Ride.
func tick_timers() -> void:
	if hero.totem_drop_lock > 0:
		hero.totem_drop_lock -= 1


## POST phase, after the hit timer: the shield and the squash count down; the picture of the egg, the shell and the
## emote bubble. (The egg drift and the leash are the PartyDriver's POST, after every hero.)
func post_step(_level: LevelBase) -> void:
	if hero.shield > 0:
		hero.shield -= 1
	if hero.squash > 0:
		hero.squash -= 1
	if hero.hit_timer == 0:
		_rival_immune = false
	if hero.down:
		egg_ticks += 1
	_refresh_party_visual()


## A strike starts (Player._handle_strike, the first tick of a swing or a throw): in versus the hurt immunity and the
## spawn shield end at once (PHYSICS.md C.14).
func on_strike_started() -> void:
	if not versus:
		return
	if _rival_immune and hero.hit_timer > 0 and hero.hit_timer < hero._stun_min:
		hero.hit_timer = 0
		_rival_immune = false
	hero.shield = 0


# =================================================================================================================
# Hurt
# =================================================================================================================

## The hero was hurt (after the immunity checks of Player.hurt). A curl, a ball and a Totem Ride end; a carrier
## throws his rider off. Versus: a rival's hit (Defs.HurtKind.RIVAL) is the hurt table of PHYSICS.md C.14 and returns
## true (no heart: the referee charges the mode's currency); everything else falls through to the 1.0 hurt (false).
func on_hurt(source: SimEntity, kind: int) -> bool:
	_end_moves()
	if kind != Defs.HurtKind.RIVAL:
		return false
	rival_hit(source)
	return true


## The versus knock-back of PHYSICS.md C.14 on this hero, from `source` (the attacking hero for a club box, his thrown
## weapon for a throw): away from the attacker xvel +/-64 (the hammer x3/2), yvel -128; a swirling axe pops him up
## (-160); a charged box or throw launches him (+/-128, -160, ice 3). hit_timer 43, stunned while >= 31 (12 ticks),
## then 30 immune ticks with control, which a strike of his own ends.
func rival_hit(source: SimEntity) -> void:
	var attacker: PlayerBase = source as PlayerBase
	var weapon: int = Defs.Weapon.CLUB
	var power: int = 0
	var thrown: bool = false
	var projectile: ProjectileBase = source as ProjectileBase
	if projectile != null:
		thrown = true
		power = projectile.power
		if &"weapon" in projectile:
			weapon = int(projectile.get(&"weapon"))
		elif projectile.get_script() == Player._spear_script():
			weapon = Defs.Weapon.SPEAR
		else:
			weapon = Defs.Weapon.AXE
		if Game.level != null:
			attacker = Game.level.get_hero(projectile.owner_slot)
	elif attacker != null:
		weapon = attacker.run.weapon
		power = attacker.club_power
	var away: SimEntity = attacker if attacker != null and not thrown else source
	var direction: int = 1 if away == null or away.sim_pos.x <= hero.sim_pos.x else -1
	var charged: bool = weapon >= 0 and weapon < Tuning.WEAPON_POWER.size() and power > Tuning.WEAPON_POWER[weapon]
	if charged:
		hero.xvel = direction * VersusTuning.CHARGED_XVEL
		hero.yvel = VersusTuning.CHARGED_YVEL
		hero.ice = VersusTuning.CHARGED_SLIDE_ICE
	else:
		var knock: int = VersusTuning.HIT_XVEL
		if weapon == Defs.Weapon.HAMMER and not thrown:
			knock = knock * VersusTuning.HAMMER_KNOCK_NUM / VersusTuning.HAMMER_KNOCK_DEN
		hero.xvel = direction * knock
		hero.yvel = VersusTuning.BOOMERANG_POP_YVEL if thrown and weapon == Defs.Weapon.BOOMERANG \
				else VersusTuning.HIT_YVEL
	hero.hit_timer = VersusTuning.HURT_TIMER_TICKS
	hero._stun_min = VersusTuning.STUN_HIT_TIMER_MIN
	_rival_immune = true
	hero.attack_gate = false
	hero._close_glider()
	hero.grounded = false
	hero.on_platform = false
	Audio.play_sfx(Sfx.PLAYER_HURT)
	Events.player_hurt.emit(Defs.HurtKind.RIVAL, source)
	Events.hero_hurt.emit(hero, Defs.HurtKind.RIVAL, source)


## A curl or a ball ends, a ride ends (a rider is thrown off his hurt carrier).
func _end_moves() -> void:
	if hero.curl != PlayerBase.CURL_NONE:
		_uncurl()
	if hero.totem_carrier != null:
		hero.end_totem_ride()
	if hero.totem_rider != null:
		hero.throw_off_totem_rider()


## The hero respawned (team wipe, versus respawn; PlayerBase.respawn_at already cleared down, shield and curl).
func on_respawn() -> void:
	_curl_ticks = 0
	_ball_ticks = 0
	_ball_grounder = false
	_ball_enemies.clear()
	_ball_spots.clear()
	_volunteer_ticks = 0
	_egg_nudge = 0
	egg_ticks = 0
	_rival_immune = false
	_shell_ticks = 0
	_show_egg(false)


# =================================================================================================================
# Pictures (cosmetic: nothing below is read by the simulation)
# =================================================================================================================

## The colour and pattern this hero wears ([method HeroPalette.resolve] for his slot and run, the arena swaps in versus).
func palette() -> Array:
	var biome: String = str(Game.level.meta.get("biome", "")) if Game.level != null else ""
	return HeroPalette.resolve(hero.slot, hero.run, biome, Game.mode == Defs.GameMode.VERSUS)


## Emote: a double tap of Look (two presses at most EMOTE_DOUBLE_TAP_TICKS apart); the direction held on the second
## press picks the bubble - none "!", Down "?", Up a heart, Left / Right angry.
func _watch_emote() -> void:
	var flags: int = GameInput.get_flags(hero.slot)
	var pressed: bool = (flags & Defs.IN_LOOK) != 0 and (GameInput.get_prev_flags(hero.slot) & Defs.IN_LOOK) == 0
	if not pressed:
		return
	if Sim.tick - _look_tap_tick <= EMOTE_DOUBLE_TAP_TICKS:
		_look_tap_tick = -1000
		var kind: int = Emote.EXCLAIM
		if (flags & Defs.IN_UP) != 0:
			kind = Emote.HEART
		elif (flags & Defs.IN_DOWN) != 0:
			kind = Emote.QUESTION
		elif (flags & (Defs.IN_LEFT | Defs.IN_RIGHT)) != 0:
			kind = Emote.ANGRY
		show_emote(kind)
	else:
		_look_tap_tick = Sim.tick


## Show emote `kind` (Emote) over the hero for EMOTE_TICKS.
func show_emote(kind: int) -> void:
	emote = kind
	emote_ticks = EMOTE_TICKS
	if _bubble == null and is_instance_valid(hero):
		_bubble = EmoteBubble.new()
		_bubble.name = "EmoteBubble"
		_bubble.position = Vector2(0.0, BUBBLE_Y)
		_bubble.z_index = 1
		hero.add_child(_bubble)
	if _bubble != null:
		_bubble.colour = HeroPalette.ui_colour(palette()[0], "dark")
		_bubble.kind = kind
		_bubble.visible = true
		_bubble.queue_redraw()
	hero.emoted.emit(kind)


func _show_egg(on: bool) -> void:
	if on and _egg_sprite == null and is_instance_valid(hero) and ResourceLoader.exists(EGG_SHEET_PATH):
		_egg_sprite = Sprite2D.new()
		_egg_sprite.name = "EggSprite"
		_egg_sprite.texture = load(EGG_SHEET_PATH) as Texture2D
		_egg_sprite.centered = false
		_egg_sprite.offset = EGG_OFFSET
		_egg_sprite.hframes = EGG_FRAMES
		var look: Array = palette()
		_egg_sprite.material = HeroPalette.material_for(look[0], look[1], false)
		hero.add_child(_egg_sprite)
	if _egg_sprite != null:
		_egg_sprite.visible = on
		_egg_sprite.position = Vector2.ZERO


func _refresh_party_visual() -> void:
	if emote_ticks > 0:
		emote_ticks -= 1
		if emote_ticks == 0:
			emote = Emote.NONE
			if _bubble != null:
				_bubble.visible = false
	if _egg_sprite == null:
		return
	if hero.down:
		var frame: int = EGG_FRAME_FLOAT_B if (egg_ticks * EGG_FLOAT_FPS / Tuning.ANIM_TICKS_PER_SECOND) % 2 == 1 \
				else EGG_FRAME_FLOAT_A
		if _egg_nudge < 0:
			frame = EGG_FRAME_NUDGE_LEFT
		elif _egg_nudge > 0:
			frame = EGG_FRAME_NUDGE_RIGHT
		var return_after: int = PartyTuning.egg_return_ticks(Game.difficulty)
		if return_after >= 0 and egg_ticks >= return_after - EGG_CRACK_TICKS and egg_ticks < return_after:
			frame = EGG_FRAME_CRACK + (egg_ticks / 2) % 2
		_egg_sprite.frame = frame
		_egg_sprite.position = Vector2.ZERO
		_egg_sprite.visible = true
	elif _shell_ticks > 0:
		_shell_ticks -= 1
		_egg_sprite.visible = true
		_egg_sprite.frame = EGG_FRAME_HATCH + (1 if _shell_ticks < SHELL_TICKS / 2 else 0)
		_egg_sprite.position = Vector2(_shell_pos - hero.sim_pos) * float(Tuning.ART_SCALE)
	elif _egg_sprite.visible:
		_egg_sprite.visible = false


## The speech bubble of an emote (DESIGN.md D.11): art-A's `ui/emotes.png` (ASSET_MANIFEST.md: 4 cells of 32 x 32 -
## "!", "?", heart, angry - pivot (16, 32) at the tail's tip, a few art px over the head); without that sheet a white
## bubble with a dark outline holding the same four signs, drawn with primitives. Art px, origin at the bubble's middle.
class EmoteBubble:
	extends Node2D

	const SHEET_PATH: String = "res://assets/ui/emotes.png"
	const CELL: int = 32
	## The sheet's tail tip under the bubble's middle (art px): 24 px below it, i.e. 76 art px over the feet.
	const TAIL_Y: float = 24.0
	const OUTLINE: Color = Color("#272018")
	const PAPER: Color = Color("#fff8e8")
	const RED: Color = Color("#d83a2c")

	var kind: int = 0
	var colour: Color = OUTLINE
	var _sheet: Texture2D = null

	func _ready() -> void:
		if ResourceLoader.exists(SHEET_PATH):
			_sheet = load(SHEET_PATH) as Texture2D

	func _draw() -> void:
		if _sheet != null:
			draw_texture_rect_region(_sheet, Rect2(-CELL / 2.0, TAIL_Y - CELL, CELL, CELL),
					Rect2(clampi(kind, 0, 3) * CELL, 0.0, CELL, CELL))
			return
		var body: Rect2 = Rect2(-15.0, -26.0, 30.0, 22.0)
		draw_rect(body.grow(2.0), OUTLINE)
		draw_rect(body, PAPER)
		draw_colored_polygon(PackedVector2Array([Vector2(-6.0, -5.0), Vector2(4.0, -5.0), Vector2(-4.0, 4.0)]),
				OUTLINE)
		draw_colored_polygon(PackedVector2Array([Vector2(-4.0, -5.0), Vector2(1.0, -5.0), Vector2(-3.0, 0.0)]),
				PAPER)
		match kind:
			0:
				draw_rect(Rect2(-2.0, -23.0, 4.0, 10.0), colour)
				draw_rect(Rect2(-2.0, -11.0, 4.0, 4.0), colour)
			1:
				draw_rect(Rect2(-5.0, -23.0, 10.0, 3.0), colour)
				draw_rect(Rect2(3.0, -21.0, 3.0, 5.0), colour)
				draw_rect(Rect2(-1.0, -17.0, 5.0, 3.0), colour)
				draw_rect(Rect2(-1.0, -15.0, 3.0, 3.0), colour)
				draw_rect(Rect2(-1.0, -11.0, 3.0, 3.0), colour)
			2:
				draw_circle(Vector2(-4.0, -18.0), 4.5, RED, true, -1.0, false)
				draw_circle(Vector2(4.0, -18.0), 4.5, RED, true, -1.0, false)
				draw_colored_polygon(PackedVector2Array([Vector2(-8.5, -17.0), Vector2(8.5, -17.0),
						Vector2(0.0, -8.0)]), RED)
			3:
				# The anger mark: four brackets around the middle of the bubble.
				for sx: float in [-1.0, 1.0]:
					for sy: float in [-1.0, 1.0]:
						var corner: Vector2 = Vector2(-2.0 + sx * 4.0, -16.0 + sy * 4.0)
						draw_rect(Rect2(corner.x - (3.0 if sx < 0.0 else 0.0), corner.y - 1.0, 4.0, 2.0), RED)
						draw_rect(Rect2(corner.x - 1.0 + (0.0 if sx < 0.0 else 2.0),
								corner.y - (3.0 if sy < 0.0 else 0.0), 2.0, 4.0), RED)

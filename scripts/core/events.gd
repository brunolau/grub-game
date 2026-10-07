extends Node
## Autoload `Events`: the gameplay event bus. Signals only, no state, no logic.
##
## CONTRACT FILE (docs/ARCHITECTURE.md 3.4). Owner: core. Signals are frozen; new ones are appended by core only.
##
## Use it for fan-out notifications between modules that must not know each other (gameplay -> HUD, audio, FX,
## achievements). Do NOT use it for anything the simulation depends on: state changes go through direct method
## calls on the base-class APIs so that the order of operations stays deterministic. Positions are feet points
## in logical px.

@warning_ignore_start("unused_signal")

# --- Hero ----------------------------------------------------------------------------------------------------------
## The hero was placed in the level (start or respawn).
signal player_spawned(player: PlayerBase)
## The hero took a hit of [enum Defs.HurtKind]; `source` may be null.
signal player_hurt(kind: int, source: SimEntity)
## The death sequence started (PHYSICS.md 10.4 step 1). `cause` e.g. &"enemy", &"spikes", &"pit", &"liquid".
signal player_died(cause: StringName)
## The death animation finished; the level decides between respawn and game over.
signal player_death_finished
## The hero landed. `hard` = hard landing (hop + dust), `shake` = it also shook the screen.
signal player_landed(hard: bool, shake: bool)
## The hero left the ground by a jump (not by walking off a ledge).
signal player_jumped
## A strike reached its last tick. `strike` is Defs.HeroState.STRIKE / HIGH_STRIKE / LOW_STRIKE.
signal player_struck(strike: int, weapon: int)
## The hero bounced on an enemy or boss head. `multiplier` is the score multiplier now shown (0 = none).
signal player_bounced(target: SimEntity, multiplier: int)
## The hero took off with / lost / landed the hang-glider.
signal glider_state_changed(carrying: bool, gliding: bool)

# --- Enemies and bosses ----------------------------------------------------------------------------------------------
## An enemy survived a weapon hit.
signal enemy_hit(enemy: EnemyBase, power: int)
## An enemy died. `points` is the total paid (already multiplied); `cause` e.g. &"weapon", &"feast", &"kill_all".
signal enemy_killed(enemy: EnemyBase, points: int, cause: StringName)
## A boss woke up: show the energy bar, switch to boss music.
signal boss_started(boss: BossBase)
## Boss energy changed: `pips` filled of `max_pips` (GAMEPLAY.md 2).
signal boss_energy_changed(boss: BossBase, pips: int, max_pips: int)
## A boss was defeated (burst into bonus items).
signal boss_defeated(boss: BossBase)

# --- Items, hidden spots, objects ------------------------------------------------------------------------------------
## Something was collected. `item_id` is the entity id (e.g. &"items/food"), `index` its sprite cell, `points` >= 0.
signal item_collected(item_id: StringName, index: int, points: int, pos: Vector2i)
## A weapon box hit a hittable (star puff). `opened` = this hit used the spot up / broke the block.
signal hittable_hit(hittable: HittableBase, opened: bool)
## A hidden spot or breakable block was used up (counts for the completion percentage).
signal hidden_spot_opened(pos: Vector2i, kind: StringName)
## A secret area was entered for the first time.
signal secret_found(zone_name: StringName)
## A restart point was activated.
signal checkpoint_activated(checkpoint: CheckpointBase)
## The exit was unlocked (fire-starter collected or dropped by a boss).
signal exit_unlocked
## The hero touched an open exit. `exit_kind` is &"exit", &"warp" or &"trophy".
signal exit_reached(exit_kind: StringName)
## A gate was used: the hero travels to `to_pos`.
signal gate_used(from_pos: Vector2i, to_pos: Vector2i)

# --- Level-wide effects ----------------------------------------------------------------------------------------------
## Request a screen shake of the given strength (4, 7, 8 or 9; PHYSICS.md 13.3). The level owns the counter.
signal shake_requested(amount: int)
## Feast mode started (`ticks` long) or ended (`ticks` == 0).
signal feast_changed(ticks: int)
## Darkness toggled by a trigger (GAMEPLAY.md 7.10).
signal darkness_changed(dark: bool)
## A score pop-up should be shown at `pos` (FX module). `kind`: &"score", &"multiplier", &"one_up", &"heart".
signal popup_requested(kind: StringName, value: int, pos: Vector2i)
## The wind value of the level changed (blizzard script).
signal wind_changed(wind: int)
## The level's time limit (meta key `time`) shows another whole second; -1 = the level has no limit. Emitted when
## the limit is armed (level start, respawn) and whenever the displayed second changes. For the HUD.
signal time_left_changed(seconds: int)
## A level hint (zones/message) asks to be shown: `text` is a translation key (or plain text) and `source` the
## node that asks. An empty `text` withdraws the hint of that source. The HUD shows the newest hint still asked for.
signal message_requested(source: Node, text: String)

# --- Level flow -------------------------------------------------------------------------------------------------------
## A level finished loading; gameplay is about to start.
signal level_started(level_id: StringName)
## The level was completed; the flow decides tally / linked stage / warp.
signal level_completed(level_id: StringName, exit_kind: StringName)
## Gameplay was paused or resumed through Flow.set_paused().
signal pause_changed(paused: bool)
## The hero respawned at a checkpoint after a death.
signal level_respawned
## No lives left.
signal game_over

# =====================================================================================================================
# 2.0 expansion (docs/expansion/PLAN.md P0.3, TECH_AUDIT.md 3.17). Appended only; every 1.0 signal above keeps its
# meaning and is still emitted for every hero, so P1 listeners keep working.
# =====================================================================================================================

# --- Heroes by slot: the twins of the hero signals above, the hero first (`hero.slot` tells the player) ---------------
# The hero emits each twin right after its 1.0 signal, for every hero including P1. Nothing inside a tick listens.
## Twin of player_hurt.
signal hero_hurt(hero: PlayerBase, kind: int, source: SimEntity)
## Twin of player_died.
signal hero_died(hero: PlayerBase, cause: StringName)
## Twin of player_death_finished (in multiplayer the level is called directly instead, TECH_AUDIT.md 4.7).
signal hero_death_finished(hero: PlayerBase)
## Twin of player_landed.
signal hero_landed(hero: PlayerBase, hard: bool, shake: bool)
## Twin of player_jumped.
signal hero_jumped(hero: PlayerBase)
## Twin of player_struck.
signal hero_struck(hero: PlayerBase, strike: int, weapon: int)
## Twin of player_bounced.
signal hero_bounced(hero: PlayerBase, target: SimEntity, multiplier: int)
## Twin of glider_state_changed.
signal hero_glider_state_changed(hero: PlayerBase, carrying: bool, gliding: bool)
## Twin of feast_changed: this hero's feast started (`ticks` long) or ended (0).
signal hero_feast_changed(hero: PlayerBase, ticks: int)

# --- Co-op party (DESIGN.md D.3) ---------------------------------------------------------------------------------
## A co-op hero who would have died became an egg (no life lost while a partner stands). `cause` as player_died;
## &"voluntary" for an egg on purpose (Down + Look).
signal hero_down(hero: PlayerBase, cause: StringName)
## An egg hatched. `by` is the partner who hatched it, or null when a checkpoint hatched it.
signal hero_revived(hero: PlayerBase, by: PlayerBase)
## Every hero of the party was dead or in an egg at once: the tribe loses one life and respawns at the checkpoint.
signal party_wiped

# --- Versus rounds (DESIGN.md E) ---------------------------------------------------------------------------------
## A hero was knocked out. `killer` is the credited rival (last hitter within VersusTuning.KO_CREDIT_TICKS) or null;
## `cause` e.g. &"hit", &"stomp", &"hazard", &"hot_rock".
signal hero_ko(victim: PlayerBase, killer: PlayerBase, cause: StringName)
## The round intro counts down: `count` 3, 2, 1, then 0 = "GRUB!" (the heroes are released by round_started).
signal round_countdown(round_index: int, count: int)
## Round `round_index` (0-based within the match) started: the heroes are free.
signal round_started(round_index: int)
## Grub Stack's Feast Rush began (the last VersusTuning.FEAST_RUSH_TICKS of the round).
signal round_feast_rush_started(round_index: int)
## The arena's themed sudden death began. `kind` e.g. &"stampede", &"cave_in", &"lava_rise" (DESIGN.md E.6).
signal round_sudden_death_started(round_index: int, kind: StringName)
## The round is over. `winner_slots` holds the winning slot(s): one, both of a 2v2 team, or none for a draw.
signal round_ended(round_index: int, winner_slots: PackedInt32Array)

# --- Book II -----------------------------------------------------------------------------------------------------
## A Cave Painting fragment (items/painting, `index` 0..29, DESIGN.md C.9) was collected.
signal painting_found(index: int)

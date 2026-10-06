# RESEARCH_COOP.md - local co-op for Club & Grub: research and design proposal

Status: research and proposal (no code yet). Scope: a same-device co-op mode over the whole campaign (the 15 shipped
stages and the 20 new ones) in which levels, enemies and bosses **need** two players working together, while
single-player stays bit-identical (every recorded route keeps replaying tick for tick).

Units as in the rest of the docs: ticks (24.2753 per second, "22 ticks = one designer second"), logical px (1 tile =
16 px), v16 = 1/16 px per tick. Hero metrics are those of `docs/spec/PHYSICS.md` and `docs/LEVEL_DESIGN.md` 12.
Engine cost: **S** = a few days inside one module, no contract change; **M** = a new object, state or AI with its
own tests; **L** = touches several modules or contracts, or needs new art. Everything here sits on top of one shared
prerequisite, the N-player refactor of section 8 (L).

Source keys `[S1]`..`[S30]` are listed in section 9.

---

## 0. Recommendations at a glance

**Top 8 co-op mechanics** (section 3 has all 28):

| # | Mechanic | Why it is in the top 8 |
|---|---|---|
| 1 | **Egg Hatch** revive (R1) with **tribe lives** (R2) | the safety net that makes every other mechanic fair to a weaker partner; no life is lost while one hero stands |
| 2 | **Shoulder Hop / Totem Stack / Caveman Toss** (T1-T3) | one family built on the head bounce that already defines this game; gives heights and gaps solo can never reach |
| 3 | **Stone Plates** that hold doors and columns (T4) | the simplest "you stay, I go" gate; reuses `objects/column`; the low-skill role is "stand here" |
| 4 | **Mammoth-Bone See-saw** (T5) | turns the hard landing (an existing rule) into a launch; loud, physical, readable |
| 5 | **Shellback pincer** enemies (C1) | an enemy that can only be hit from behind and always faces the nearer hero; solo-proof, trivial to learn |
| 6 | **Daze and Club** (C2) | a head bounce (harmless in solo) dazes a dodging enemy for a window shorter than one hero can use alone |
| 7 | **Twinbond** linked enemies (C3) | two foes that must die within a window; creates the "3-2-1-now!" shouting that co-op research names the core of fun |
| 8 | **Two-headed and tag-team bosses** (C6, C7) incl. co-op Brute and Colossus | bosses are where cooperation feels best; the existing boss hit cooldown already stops simple damage doubling |

**Camera**: one shared **tribe camera** that keeps the authentic paging on the group: it pages when the front hero
reaches the trigger column, stops before the rear hero would leave the view, and the screen edges become walls for the
leader. A hero who stays off-screen for 3 s (5 s on Beginner) - or dies - becomes an **egg** that flies to the
partner. **Look** claims the camera. Gates, arenas and auto-scroll carry both heroes. No zoom (the picture must
keep whole-number pixel scaling) and **no split screen** (at 640 x 360 a half view is 10 x 11 or 20 x 5.6 tiles,
which breaks the paging camera and jump readability).

**Player count**: design, test and ship co-op for **exactly two players**. Build the engine for up to four (arrays,
not `player` / `player2`), use 2-4 for the same-device deathmatch, and treat 3-4-player co-op as a possible later
"party" setting without required-co-op gates.

**Non-negotiable**: with one player every code path is the shipped one. Co-op content is flagged per entity
(`coop=only|solo`) like the Expert flag, so solo levels never contain it.

---

## 1. What the best local co-op games teach

### 1.1 Survey

| Game | What makes co-op necessary or fun | How it protects the weaker player | Lesson for Club & Grub |
|---|---|---|---|
| New Super Mario Bros. Wii / U (2009 / 2012) `[S1]`-`[S5]` | 4 players on one zooming screen; pick up and throw partners, co-op jump on heads, bump into each other | a dead or lagging player floats back in a **bubble**, popped by a partner; anybody can bubble at will and be carried; bubbles cost no lives; "everyone can see you, so you're like: hurry up and pop me!" `[S2]` | the bubble solves several problems at once (exclusion, waiting, inconsistent respawn) `[S2]`; but 4 players on one screen is chaos that frustrates serious play `[S5]` |
| Super Mario Bros. Wonder (2023) `[S6]` | drop-in co-op | player collision was **removed** because bodies on narrow platforms caused stress | heroes should not block each other sideways; keep only the deliberate contacts (heads) |
| Rayman Origins / Legends (2011 / 2013) `[S7]`-`[S9]` | up to 4 on one shared view (no split screen), hoisting partners, drop-in / drop-out | a dead player becomes a bubble a partner pops; all in bubbles = checkpoint; Legends' Murfy is an asymmetric **touch** helper who cuts ropes, moves platforms and tickles enemies | revive by touch keeps the run going; a touch "helper" role exists as a proven idea for tablets |
| Kirby's Return to Dream Land (2011) `[S10]` | **piggyback** stacking that does not slow movement; team attacks from a stack | **shared lives**, joining costs a life; a lagging helper warps to player 1 | stacking as a co-op move; shared life pool; warp the lagging player |
| Trine 1-5 `[S11]` `[S12]` | three heroes with different tools; physics puzzles with **several solutions** | any puzzle has more than one answer, so nobody is stuck on one precise action | allow at least two answers for every co-op gate where possible (e.g. melee *or* thrown) |
| LittleBigPlanet (2008) `[S13]` | "x2 / x3 / x4" co-op areas marked by stickers, rewarded with prize bubbles | co-op areas are optional rewards, never in the critical path of solo | mark two-player secrets visibly (our **x2 stone tablet**) |
| It Takes Two (2021) `[S14]` | built for two from day one; each mechanic needs the partner and "combines well" | a partner who "means something" in every mechanic; constant role swaps | design co-op levels as their own layouts, not solo levels with a second body |
| Unravel Two (2018) `[S15]` | two characters on one **tether**: anchor, swing, climb on each other | the skilled player can carry the other through hard parts and hold the rope while the partner climbs | every gate needs an easy role (anchor, stand, crouch) |
| Pico Park (2016) `[S16]` `[S17]` | key and door: the level ends only when **all** players are at the door; stack on each other, push boxes together, relay jumps; partners can block each other | failure is shared and funny, not personal | push-together boulders, stacking, "everyone through the gate" |
| Overcooked (2016) `[S18]` | every player has an integral role; the game is about how roles are distributed | roles can be swapped by the group | roles come from situations (who stands, who goes), not from fixed classes |
| Snipperclips (2017) `[S19]` | puzzles need both characters at the same time | none built in: "if one person was stubborn ... the team wouldn't make progress" | good co-op asks for talk; keep each gate short so a stalemate never lasts |
| The Lost Vikings (1992) `[S20]` | three heroes with complementary abilities (runner, fighter, shield / glider / platform); all must reach the exit | puzzle pacing, no twitch timing on the hard gates | the shield-as-platform idea maps onto our Totem Stack and hide shields |
| Cuphead (2017) `[S21]` `[S22]` | 2-player boss fights | revive by **parrying** the partner's ghost; the ghost rises faster after each death; bosses have more health in co-op | a revive should be an *action*, and tougher on Expert |
| Shovel Knight (2017 co-op update) `[S23]` | 2 players | revive splits the remaining health; **shared gold**, individual tallies only for bragging rights | shared score plus per-player medals at the tally |
| Spelunky (2012) / Spelunky 2 (2020) `[S24]` `[S25]` | shared screen led by player 1 (a flag); in Spelunky 2 ghosts can still act | off-screen for long = a 10-second timer, then death; in Spelunky 2 coffins revive | a leash timer works, but ours ends in an egg, never a death |
| Chip 'n Dale Rescue Rangers (1990) `[S26]` | pick up and **throw the partner**, carry crates, stack metal boxes as stairs | - | the 8/16-bit precedent for Caveman Toss |
| Joe & Mac (1991) `[S27]` | two cavemen, simultaneous; jump on each other's heads to reach higher enemies | - | the prehistoric-genre precedent for the Shoulder Hop |
| The Blues Brothers (Titus, 1991) `[S28]` | two-player simultaneous mode in the engine family Prehistorik 2 grew from | none: "the scrolling screen only focuses on the first, so the second had better keep up" | the cautionary tale for our camera: never follow player 1 only |

Research on co-op patterns: Rocha et al. list **complementarity, synergies between abilities, abilities that can only
be used on another player, shared goals, synergies between goals, special rules** `[S29]`; El-Nasr et al. add
interacting with the same object, shared puzzles, shared characters, **enemies targeting a lone wolf**, vocalization and
limited shared resources, and found laughter and shared excitement clustered around these patterns `[S29]`. A designer
taxonomy ranks "forced cooperation" below co-op where joint actions *boost* what players can do `[S30]`; Tim Keenan
(A Virus Named Tom) kept player collision, built separate co-op levels and handed out end-of-level roles/awards to
create banter `[S31]`; death design in co-op ranges from shared health to ghosts, revive-on-action and timers, with
the warning that revive-by-action punishes beginner-pro pairs when the action itself is hard `[S32]`.

### 1.2 Principles distilled for this game

1. **Co-op gates are puzzles, not skill checks for the weaker player.** Every gate has an easy role (stand on a plate,
   crouch as a step, be the bait, stand still to be bounced on) and a harder role (the jump, the toss, the timed
   strike). The pair chooses who does what.
2. **One shared safety net**: falling behind or dying never ends the run while a partner stands (egg, R1). The penalty
   is time, the partner's attention and the lost "since last death" tally list, as in the original - "if you mess up,
   you need to incur some kind of penalty, even if you return to the game right away" `[S2]`.
3. **Joint actions boost, not just block** `[S30]`: a partner is a springboard, a catapult, a carrier, a shield. The
   co-op toolset makes the heroes stronger together (heights, gaps, damage windows) instead of only locking doors.
4. **Every one-way move has a way back.** If A is boosted up, A must then lower something for B (spring, lift,
   bridge). Never strand a hero.
5. **No friendly fire, no sideways body blocking** `[S6]`; only heads are solid (they are platforms and springboards).
   Griefing stays possible (a toss into a pit) but is cheap: it only costs an egg.
6. **Windows, not frame-perfect sync.** Simultaneous actions get windows of 12 ticks (Expert) / 24 ticks (Beginner) and
   an audible count-in; nothing needs two players to act on the same tick.
7. **Visible intent.** An "x2" stone tablet (two carved cavemen) marks every co-op gate and secret, as LittleBigPlanet
   marks its co-op areas `[S13]`; signs teach each mechanic before it can hurt (LEVEL_DESIGN 10).
8. **Solo-proof gates.** A co-op gate must not be beatable alone with an enemy bounce (rise 105 px), a club-pogo hover
   against hidden spots (each hit lifts 15 px), the glider or a spring. The validator checks this (section 4.6).
9. **Same physics for both heroes.** No hero classes: the levels must stay fair with every weapon a hero can carry
   (LEVEL_DESIGN 10), and classes would multiply route proofs. Roles come from situations (Overcooked `[S18]`) and,
   softly, from the weapons each hero holds (melee vs thrown).
10. **Short loops.** A co-op gate should be solvable in under ~30 s once understood; a stubborn pair (Snipperclips
    `[S19]`) never blocks the game for long.

---

## 2. Rules of the two-hero world

| Topic | Rule | Engine anchor |
|---|---|---|
| Heroes | P1 and P2 use the same hero physics, boxes and strike scripts; P2 is a palette swap with a coloured marker | `PlayerBase`, `Tuning` |
| Body contact | heroes pass through each other sideways; a hero landing on a partner from above uses the head-stomp test of PHYSICS.md 2.2 / 9 | `Overlap.body(faller, other, faller)` |
| Strikes | club boxes and thrown weapons pass through partners (no damage), except where a mechanic says otherwise (hatching an egg, launching from a stack) | weapon pass of `Phase.WEAPONS` |
| Energy | each hero has own hearts and bones; the team shares score, lives, G-R-U-B-S letters, feast kit, checkpoint and exit state | `Game` split, section 8 |
| Weapons | each hero keeps his own weapon; co-op layouts place weapon items in pairs | `items/weapon` |
| Glider | one per hero; carrying it still forbids strikes (original rule), which co-op turns into a role (T7) | glider rules, PHYSICS.md 13.2 |
| Checkpoints | one team checkpoint; touching it also hatches every egg on screen | `CheckpointBase` |
| Exit | the level ends when **both** heroes are at the exit (Pico Park `[S16]`); an egg counts as present if it is on screen | `LevelExitBase` |
| Gates | Down on a gate takes both heroes (a partner farther than one screen arrives as an egg) | `Flow.play_covered` |
| Feast | three cutlery pieces from either hero start the feast for both | `Game.feast_kit` |

---

## 3. Catalogue of co-op mechanics

Each entry: **How** it works / **Extends** which existing system / **Fun** / **Unequal pair** (how it fails
gracefully when one player is much weaker) / **Cost**.

### Traversal

**T1. Shoulder Hop** (boost on the partner's head)
- How: a hero who lands on the partner's head bounces exactly as on an enemy: -224 v16 with Up held (rises 105 px from
  the partner's head, so feet reach about 140 px = 8.7 tiles above the floor), -64 without. Co-op ledges for it are
  6-8 tiles high; solo reach is 3 tiles safe, 4 impossible (LEVEL_DESIGN 12).
- Extends: the enemy head bounce (`Overlap.body` stomp flag, `PlayerBase.bounce`); the multiplier is not counted.
- Fun: it is the game's signature move turned into a team move; instantly understood.
- Unequal pair: the bottom role is "stand still"; the top role needs one held jump. The strong hero can also be the
  bottom and catch a weak jumper's bad aim by walking under him.
- Cost: S.

**T2. Totem Stack** (ride on the partner)
- How: landing on the partner's head *without* Up held keeps the rider standing there: the carrier is a moving
  platform (ride test of PHYSICS.md 11.4). The carrier walks normally; his jump impulses are halved while carrying
  (as with the glider). The rider can strike from up there (high strikes reach about 5 tiles over the floor) or jump
  off (60 px + the carrier's 35 px = 95 px, 5.9 tiles). Kirby's piggyback `[S10]`, Joe & Mac `[S27]`.
- Extends: `PlatformBase` ride test, glider-carry impulse halving.
- Fun: a two-headed caveman tower; the rider can be the "gun turret".
- Unequal pair: the weak player rides and only presses strike; the strong one walks and jumps. Or the weak player is
  the carrier and only walks.
- Cost: M (new ride source, carry pose, ride order after both hero updates).

**T3. Caveman Toss**
- How: from a Totem Stack the carrier presses Up + strike: the rider is thrown in the facing direction with about
  -256 v16 up and 80 v16 forward (tunable): roughly 10 tiles across at launch height or 8 up - far beyond the best solo
  jump (6 tiles, expert). The thrown hero keeps air control and can strike in flight (mid-air hits on hidden spots or
  a far switch). Chip 'n Dale `[S26]`, NSMB Wii `[S4]`.
- Extends: hero state table (new CARRY / THROWN flags), airborne step.
- Fun: comedy; the "human projectile" also stuns a small enemy it hits (no score multiplier abuse: one hit).
- Unequal pair: being thrown needs nothing; throwing needs one button. Rule 4 applies: the thrown hero then drops a
  bridge or spring for the thrower (T8).
- Cost: M (two new hero flags, two poses per palette).

**T4. Stone Plates** (weight plates and held doors)
- How: a plate tile is pressed while a hero (or a co-op boulder, T9) stands on it; it drives an `objects/column` that
  rises while pressed and sinks back at 1 tile per 4 ticks when released. The plate stands far enough from its door
  (8+ tiles) that its presser cannot pass himself. Leapfrog layouts: A holds plate 1 for B, B holds plate 2 for A.
  Variants: timed plates (stay open N ticks), paired plates (both must be pressed at once).
- Extends: step-on tiles of PHYSICS.md 11.1 (visual only in the original) + `objects/column` trigger (new `hold` mode).
- Fun: the purest "you stay, I go" moment; creates talk ("stay on it!").
- Unequal pair: standing on a plate is the easiest job in the game; the weak player does it while the strong one
  runs the gauntlet.
- Cost: S-M.

**T5. Mammoth-Bone See-saw**
- How: a long bone plank on a rock. One hero stands on the low end; the other lands on the high end. The launch is
  -(landing yvel + 32) v16, plus 64 when the landing counts as a hard landing (a drop of 4+ tiles, PHYSICS.md 6.5),
  capped at -288 (tunable): a full jump from the plank's own height throws the partner about 91 px (5.7 tiles), a hard
  landing from higher ground about 171 px (10.7 tiles). Enemies on the low end are thrown off screen (and killed).
- Extends: `PlatformBase` (two linked ends), the hard-landing rule (PHYSICS.md 6.5, `fall_ticks`).
- Fun: big physical cause and effect; rewards a partner who climbs high to "drop the bomb".
- Unequal pair: the launched hero only stands; the dropper only needs to land on a big target.
- Cost: M.

**T6. Pulley Lift** (counterweight)
- How: two platforms on one rope over a log pulley. A hero stepping on the upper one sinks it and raises the lower
  one: a hero standing on the lower platform rides up. Both on board = balance, nothing moves. The lift is the
  "elevator for your partner": you go down to bring him up; the one left below takes a second, safe but longer route
  (or the partner then drops a spring, T8).
- Extends: `objects/platform mode=ride`, linked in pairs.
- Fun: a small sacrifice for the partner; good timing comedy when both jump on at once.
- Unequal pair: no timing at all.
- Cost: M.

**T7. Pilot and Gunner** (tandem glider)
- How: a big hide glider for two. The pilot runs the take-off (24 ticks at speed, as now) and steers (Up climb,
  Down dive); the gunner hangs below and is the only one who can strike or throw (the original forbids attacks while
  carrying the glider, PHYSICS.md 13.2). Glider sections place flyers that block the route and must be cleared by the
  gunner; dive stomps still work for the pilot.
- Extends: glider flight model, Totem Stack ride (gunner rides the glider), weapon pass.
- Fun: a shoot-'em-up moment inside a platformer; clear asymmetric roles.
- Unequal pair: the gunner role is the forgiving one (only strike); a crash drops both, never kills by itself.
- Cost: L (new glider art, flight with a passenger, route tests for 2-2's gorge).

**T8. Drop Gifts** (the way back: spring flowers, ladders of log, drawbridges)
- How: on top of every boost ledge sits something only the upper hero can release: a potted springy flower he clubs
  off the edge (it lands below as an `objects/spring`), a rope-held log bridge he cuts (a breakable block that falls
  and becomes a one-way bridge row), or a lift lever.
- Extends: `objects/spring`, `objects/breakable_block`, falling-item physics, `TileGrid.set_cell`.
- Fun: completes the loop of T1-T3 and T6; "pull me up" turns into a gift.
- Unequal pair: one strike; nothing timed.
- Cost: S.

**T9. Boulder Shove**
- How: a 2 x 2 tile boulder that moves one tile per 6 ticks only while **two** heroes walk into it on the same side
  (both wall probes touching, both pushing). It fills a gap, blocks a lava flow, presses a plate (T4) or crushes a
  burrow. One hero alone cannot move it. Pico Park's push-together `[S16]`.
- Extends: tile blocks moved like rising columns (`objects/column` moves whole tiles), hero wall probe.
- Fun: the cartoon "heave-ho" with both cavemen straining.
- Unequal pair: both only hold a direction.
- Cost: M.

**T10. Leapfrog in the Lee** (wind)
- How: in strong wind a standing hero is pushed back and every jump into the wind fails (WIND twice per jump tick,
  PHYSICS.md 13.1); crouching is immune, but crawling cannot cross gaps. A hero who stands within 2 tiles downwind of
  a **crouching** partner is in the lee: no WIND. The pair crosses a windy ledge with gaps by leapfrogging: A crouches,
  B runs up in A's lee and jumps the gap, lands and crouches; A crosses in B's lee.
- Extends: the blizzard wind script and crouch immunity (already taught by Blizzard Pass).
- Fun: rhythmic teamwork; reads like a nature documentary of penguins in a storm.
- Unequal pair: the croucher role only holds Down; gaps are 2-3 tiles.
- Cost: S.

**T11. Torch-bearer** (pitch-black caves)
- How: some new caves are black except a light circle of about 4 tiles around a carried torch. The torch-bearer
  cannot strike (hands full, like the glider); the partner fights inside the light. Swapping the torch is a walk-into
  hand-over. Hidden spots glint only inside the light.
- Extends: `zones/dark` (today a palette fade) plus a cosmetic light (Godot 2D light in the compatibility renderer),
  carry rule of the glider.
- Fun: tension, staying close, "bring the light over here!".
- Unequal pair: carrying the torch is the safe role; the bearer never has to fight.
- Cost: M (light rendering is cosmetic; the carry rule is S).

### Combat

**C1. Pincer** (Shellback enemies)
- How: an enemy with a shell or shield that turns each tick to face the **nearest** hero (ties: the one that hit it
  last). Hits on the shield glance off with the Colossus clank and spark; only hits on its back count. One hero
  alone is always in front. Two heroes on both sides: the far one hits the back - with a club, or a thrown weapon from
  any distance.
- Extends: `EnemyBase.take_hit` with a direction test, walker / patroller movement.
- Fun: an instant "you go left, I go right"; works with every weapon.
- Unequal pair: the bait only has to stand closer than the partner (outside contact range); the shield never hurts.
- Cost: S.

**C2. Daze and Club** (enemies that must be held while the other strikes)
- How: a Raptor-type enemy hops back out of strike reach when a hero within 48 px starts a strike, and leaps over
  low thrown axes. A head bounce on it **dazes** it for 12 ticks (Expert) / 14 (Beginner); only a dazed one can be
  hurt. A lone hero cannot use his own daze: after a bounce he is airborne for about 9 ticks, a strike's first
  damage comes 5-6 ticks after the press, and strikes started while descending make no club box (PHYSICS.md 8.1);
  roughly 15 ticks pass, longer than the window. The partner, standing ready, strikes on the "now".
- Extends: bounce (`on_bounced`), hopper AI, strike timeline.
- Fun: the rhythm "bounce - bonk"; the bouncer also scores the multiplier.
- Unequal pair: bouncing is easy (big target, no damage on a bounce); the strike is a single press on a call.
- Cost: S (tune the window below the solo minimum, proven by a solo search, section 4.6).

**C3. Twinbond** (linked enemies that must die together)
- How: two enemies joined by a glowing vine of spirit. Killing one starts a count-in sound; if the other is not
  killed within 12 ticks (Expert) / 24 (Beginner), the first regrows from its seed. They are placed or behave so that
  one hero cannot reach both in time (opposite ledges, or they flee from the nearest hero).
- Extends: `EnemyBase.kill`, a small pair registry.
- Fun: the "3-2-1-now!" moment, the most talked-about kind of co-op in the research `[S19]` `[S29]`.
- Unequal pair: the window is generous on Beginner; any weapon counts, thrown included; a failed attempt only regrows
  the enemy.
- Cost: S.

**C4. Bait and Bite** (stationary or slow foes with an exposed weak point)
- How: a big snapper plant lunges at the nearest hero within range; during its 20-tick lunge recovery its stem is
  exposed from the side. Alone, the hero who baits is the one being bitten and recovering; with two, the bait steps
  back, the partner hits the stem.
- Extends: `enemies/snapper`.
- Fun: easy-to-read timing for kids.
- Unequal pair: baiting means standing at the edge of the range and stepping back.
- Cost: S.

**C5. Shared Burden** (escort a carried object)
- How: an ember pot, a dino egg or a big roast must be carried to a nest or fire. The carrier walks at 3 px/tick and
  cannot strike or jump high; enemies converge on him (the lone-wolf rule); the partner clears the way. Dropping it
  (hurt) sends it back to its stand after 132 ticks.
- Extends: carry rule (glider), sky dropper / digger zones.
- Fun: protect-the-VIP drama; gives the porter a stake in the fight.
- Unequal pair: the porter role is pure walking.
- Cost: M.

**C6. Two Weak Points** (bosses)
- How: a boss with two weak points at opposite ends or heights (a two-headed tar serpent, a mammoth with a tusk guard
  and a soft tail) where a hit only counts if the other point is hit within the window (C3), or where the boss guards
  the point facing its current target (C1). Each phase moves the points so the roles swap.
- Extends: `BossBase.poll_weapon_hit(weak_point)` (already per weak point), `hit_cooldown`.
- Fun: the climax of everything above; the boss bar drops in big synchronized chunks.
- Unequal pair: one weak point is always reachable from the floor with a forward strike or a throw; the harder one
  (high, moving) is for the stronger player.
- Cost: M per boss (bosses need art anyway).

**C7. Tag-team and Rescue phases** (bosses)
- How: (a) **Grab**: the boss grabs its target (the hero who hit it last) and squeezes one bone per 44 ticks; the
  grabbed hero wriggles (Left/Right) to shorten it; the partner frees him with a hit on the weak point. (b) **Aggro
  swap**: the boss turns to whoever hit it last, which keeps the other's side open. (c) **Split arena**: a wall rises
  (rising columns) between the heroes; each side's half of the boss is hurt only from the other side.
- Extends: Brute state machine (target selection), `objects/column`, `BossBase.touch_hero`.
- Fun: rescue is the strongest "we did it together" emotion; aggro swapping is natural teamwork without explanation.
- Unequal pair: being grabbed is the weak player's failure state and costs little; the strong partner saves him.
- Cost: M.

### Resources

**R1. Egg Hatch** (the revive; our "bubble")
- How: a hero who dies while the partner stands plays the death toss, then appears inside a speckled egg carried by a
  small friendly pterosaur near the partner (about 3 tiles above and behind him). The egg drifts after the partner;
  its owner can nudge it left/right (engagement, NSMB's shake `[S1]`). The partner hatches it with any weapon hit, a
  thrown weapon, or a **head bounce** on the egg (easiest of all). The hatched hero has 2 hearts (Beginner) / 1 heart
  (Expert), 44 ticks of blinking, and loses his own "since last death" tally list. Touching a checkpoint hatches all
  eggs. Expert: the egg rises a little faster after each death in the same level (as Cuphead's ghost `[S21]`) and,
  if not hatched within 10 s, flies back to the checkpoint and waits there. A hero may also curl into an egg at will
  (Down + Look held 1 s) to be carried through a hard stretch - NSMB's voluntary bubble `[S3]`.
- Extends: death sequence (PHYSICS.md 10.4), a hittable that follows a hero, weapon pass, bounce test.
- Fun: no waiting, no screen of shame; the egg owner keeps "playing" (nudging, shouting).
- Unequal pair: this *is* the graceful failure for everything else.
- Cost: M.

**R2. Tribe Lives**
- How: one shared pool of lives (start as solo: the counter shows 2). A life is lost only on a **team wipe** - both
  heroes dead or egged at the same moment, or the last standing hero dying. Then both respawn at the checkpoint with
  3 hearts each, enemies reset (as now). 1UPs and the 250 000-point extra lives feed the pool. Kirby `[S10]`.
- Extends: `Game.lives`, respawn flow, `Events.player_death_finished`.
- Fun: tension of the last hero standing.
- Unequal pair: the weak player's deaths cost no lives; only the team's double failure does.
- Cost: S (after the split of `Game`, section 8).

**R3. Bone Sharing and Heart Gifts**
- How: bones picked up by a hero at full energy fly to the partner (a visible arc) instead of being wasted. A placed
  heart stays when the picker is full (original rule), so the partner can take it. A hero with 2+ hearts can give one
  to a touching partner (Down + Look while overlapping).
- Extends: `Game.add_bones`, heart item rule.
- Fun: caretaking without menus; "eat this!".
- Unequal pair: the strong player feeds the weak one.
- Cost: S.

**R4. Feast for Two**
- How: the three cutlery pieces may be collected by either hero; the feast covers both. In co-op some feast tables
  (giant roasts) only release their giant bonus when both heroes strike them within the window (C3 rule).
- Extends: `Game.feast_kit`, big-bonus spots.
- Fun: shared power fantasy.
- Unequal pair: nothing timed beyond a generous window.
- Cost: S.

### Scoring

**S1. Tribe Score with Medals**
- How: one shared score (HUD centre, one co-op high-score table); the tally shows per-hero medals: Most Food, Best
  Bounce Chain, Hatchling (eggs hatched for the partner), Strongman (tosses and boosts), Clumsiest (deaths, as a joke).
  Shovel Knight keeps gold shared with individual tallies for "bragging rights" `[S23]`; Keenan's end-of-level roles
  feed banter `[S31]`.
- Extends: `Game.add_score`, tally screen, `Save` high scores per mode.
- Fun: friendly competition without hurting the team.
- Unequal pair: medals for helping (Hatchling, Strongman) reward the supporter too.
- Cost: S.

**S2. Relay Bounce**
- How: bounces on one enemy by both heroes raise the same counter (`bounce_count` is already per enemy); alternating
  heroes extend the multiplier ladder from 1/2/3/4/6/8 to x10 and x12 at 12 and 14 alternating bounces. The kill pays
  the team.
- Extends: `EnemyBase.on_bounced`, `Tuning.bounce_multiplier`.
- Fun: juggling an enemy between two heads for a huge pop-up.
- Unequal pair: any bounce counts; no penalty for breaking the chain.
- Cost: S.

**S3. Rival mode** (optional switch)
- How: an option for two separate scores (who eats more) on the same co-op levels; food goes to the picker, a kill to
  the killer. Default is Tribe Score.
- Extends: S1.
- Fun: sibling rivalry, the NSMB energy `[S5]`, without changing the levels.
- Unequal pair: off by default.
- Cost: S.

### Secrets that need two

**X1. Twin Drums**
- How: two drum stones (hidden spots with a look) on opposite sides of a room must be struck within the window; then
  a gate opens or a column rises. Variant: a call-and-response rhythm (A, B, A, B).
- Extends: `HittableBase`, columns, gates.
- Fun: music-like coordination; the x2 tablet points it out.
- Unequal pair: big targets, generous window, any weapon.
- Cost: S.

**X2. High Cache**
- How: hidden spots and secret walls at 6-8 tiles high, reachable only from a Totem Stack (high strike) or a Shoulder
  Hop; the giant bonus of a big spot falls "from 112 px above" onto a ledge only a boosted hero reaches.
- Extends: hidden-spot rules (PHYSICS.md 8.3), level design only.
- Fun: rewards using the co-op moves outside their gates.
- Unequal pair: optional by definition.
- Cost: S (level design).

**X3. Over-the-Pit Wall**
- How: a cracked wall hanging over a pit, reachable only by a tossed hero striking in flight (T3).
- Extends: breakable blocks, Caveman Toss.
- Fun: a stunt.
- Unequal pair: optional; a miss is an egg.
- Cost: S.

That is 28 mechanics: 11 traversal (T1-T11), 7 combat (C1-C7), 4 resources (R1-R4), 3 scoring (S1-S3) and 3
secrets (X1-X3).

---

## 4. Enemy structure for co-op

### 4.1 Shared rules (all enemies)

| Rule | Solo (today) | Co-op |
|---|---|---|
| Target | "the hero" | `target_player()`: the nearest hatched hero by distance in x, then y; ties to the lower player index. With one player it returns the hero, so solo is unchanged |
| Lone-wolf variants | - | some variants target the hero **farther from his partner** (El-Nasr's pattern `[S29]`): staying together is the defence |
| Activation | anchor within ~2 tiles of the view | unchanged (one shared view) |
| Despawn | off-screen and farther than a screen from the hero | farther than a screen from **every** hero |
| Zone spawners (dropper, digger) | while the hero is inside the zone | while any hero is inside; spawns alternate between the heroes inside; `max` alive x1.5 rounded down |
| Active cap | 12 | 12 (the cap is a performance and readability budget, not per hero) |
| Hit points | weapon power vs hp | unchanged for ordinary enemies (two heroes already double the damage) |
| Bosses | hits count once per `BOSS_HIT_COOLDOWN` (22 ticks; Colossus 26) | the cooldown already caps damage per boss, so two heroes do **not** double boss DPS; boss hp +25 % at most, co-op phases (C6, C7) add the challenge |
| Contact damage | 1 heart, 44 ticks immunity | per hero; the enemy keeps the stolen heart of each hero it hurt (bones burst to the team on its death) |
| Respawn | all enemies reset on a respawn | reset only on a team wipe; eggs and hatches do not reset enemies |
| Placement flags | `expert` | `expert` plus `coop=only` / `coop=solo` per entity (solo levels never load co-op entities) |

### 4.2 Existing archetypes in co-op

| Archetype (GAMEPLAY 5.2) | Co-op behaviour change | Co-op-only variants |
|---|---|---|
| 0 Dropper (sky dropper) | drops alternate between the two heroes; each walker heads for its own target | **Pack Drop**: drops in Twinbond pairs (C3), one at each hero |
| 1 Decoration | none | - |
| 2 Dangler (yo-yo) | none; the thread is a hit target too | **Snatcher Bat**: big bat that grabs a hero touching it from below and carries him up its thread (new archetype N4 rules) |
| 3 Lurker (ceiling dropper -> chaser) | drops when any hero is in range; chases the hero it lands nearest to | **Leech** (N5): lands on a hero's back instead of chasing |
| 4 Swinger (pendulum) | none | pendulum stones that **carry** a hero who lands on them (a moving platform with a swing), timed by a partner striking its rope peg |
| 5 Stinger (sentry diver) | faces and dives at its target | **Hive Stinger**: lone-wolf targeting |
| 6 Harrier (clever flyer) | its waypoint loop is relative to its target; switches target every loop | **Harrier pair** circling in opposite directions, reachable from a Totem Stack |
| 7 Dart (kamikaze) | aims at its target at launch | none |
| 8 Hopper | hops at its target | **Raptor** dodger, needs Daze and Club (C2) |
| 9 Walker / Flyer (patroller) | none (patrol limits) | **Shellback** (C1 pincer); **Shaman** (N8) |
| 10 Digger (burrower) | rises around the hero chosen by the spawner | **Tunnel King**: surfaces only under a hero who stands still; the partner must strike it in its 120-tick walk |
| 11 Leaper (arc leaper) | leaps toward its target | **Twin Leapers** from two pits, bonded (C3) |
| 12 Charger (edge rusher) | runs at its target | **Pack Wolf** (N6) lone-wolf rusher; **Mammoth** (N7) |
| Snapper (stationary biter) | bites the nearest hero in range | **Big Snapper**, Bait and Bite (C4) |

### 4.3 New co-op-native archetypes

| Id (working) | Behaviour | Why it needs two | Built on |
|---|---|---|---|
| N1 `enemies/shellback` | turns each tick to face the nearest hero; front hits glance off; back hits count | one hero is always in front | walker + direction test |
| N2 `enemies/raptor` | hops back from wind-ups within 48 px, jumps over low throws; a head bounce dazes it for a short window | its own daze is too short for one hero (C2) | hopper |
| N3 `enemies/twinbond` (a param on any enemy: `bond=<name>`) | killing one starts the window; the survivor's partner regrows | needs two kills at once (C3) | `EnemyBase.kill` |
| N4 `enemies/snatcher` | a pterosaur (or the big bat) swoops at the lone wolf, grabs him, flies toward the screen edge at 2 px/tick; the grabbed hero wriggles to slow it | only a partner can hit it (high strike, throw, or a Shoulder Hop); if it reaches the edge the hero is egged (no life lost) | stinger dive + carry |
| N5 `enemies/leech` | drops onto a hero's back and drains one bone per 44 ticks; the carrier cannot hit his own back | the partner clubs it off ("an ability only usable on another player" `[S29]`); alone it falls off after 220 ticks | lurker drop + attach |
| N6 `enemies/pack_wolf` | rusher that targets the hero farther from his partner; when both stand within 4 tiles of each other it circles and growls instead of attacking | rewards staying together; punishes splitting | charger |
| N7 `enemies/mammoth` | heavy charger, too strong to hit from the front (glances); it stops and is dazed for 44 ticks only when **two** crouching (braced) heroes stand within one tile of each other in its path; dazed, its head can be struck | one braced hero is trampled (hurt, thrown back) | charger + crouch state |
| N8 `enemies/shaman` | casts bone shields on enemies near it (they glance); flees from the nearest hero along its platform | must be pinned from both sides (C1 by movement) | patroller + shield flag |
| N9 `enemies/splitter` | a tar blob that splits into two halves running apart when hit; if both halves are not killed within the window they merge back | Twinbond created on the fly | dropper walker + bond |

### 4.4 Bosses in co-op

**Brute (2-2, Expert rematch)**: targets the hero who hit it last (aggro swap, C7b): it watches, guards and leaps at
that hero, so the other has the open side and the head; its arm guard still blocks thrown weapons from the side it
faces. Below 50 % hp it adds the **Grab** (C7a): it seizes its target, squeezing a bone every 44 ticks; a hit on the
head drops him. The ground pound shakes both heroes (crouch to stand firm, as now). A stacked rider (T2) reaches the
head with a forward strike - a second answer next to the high strike and the thrown axe. hp 64 -> 80.

**Wall Colossus (4-2)**: the face carries a stone **visor**. Two chains at the hall's sides lift it while a hero
stands on the matching Stone Plate (T4); rocks are spat at the plate holder and stalactites rattle over the thrower,
so both are busy. Only thrown weapons hurt the head (unchanged; the checkpoint places **two** axes in co-op). Every
4th hit the rage pose (armoured, as now) moves the active chain to the other side: the roles swap. Fairness tests of
`tests/test_enemies_colossus.gd` (telegraphs of 10+ ticks, no stun-lock) apply per hero.

**Patterns for the new bosses** (for the level designers of the 20 new stages):

| Pattern | Sketch |
|---|---|
| Two heads (C6) | a two-headed tar serpent rising from two pits at the arena's ends; heads must be hit within the window; between rounds the heads swap pits |
| Tag team | the **Rival Chieftains**: two rival cavemen bosses who use *our* co-op moves against us - one tosses the other across the arena, they stack to reach the heroes' ledge, one revives the other from an egg unless the heroes hit the egg first |
| Rescue | a giant pterosaur nest boss that snatches one hero to its nest (N4 at boss scale); the partner climbs a see-saw (T5) to reach the nest |
| Split arena | a rooted guardian (the stretch boss of GAMEPLAY 12.1) whose fist splits the room with a wall; the hero on the fist side baits punches, the other uses the resting fist as a springboard to the face |
| Escort | a mammoth matriarch that can only be beaten by leading her (C5 porter carrying a fire pot) into a pit while the partner keeps her calves (N7) braced off |

### 4.5 Retro-fitting the 15 shipped stages (co-op layouts)

| Stage | Co-op gates (sketch; the solo layout is untouched) |
|---|---|
| 1-1 Vine Bridges | teaches T1 (the springy flower becomes a 6-tile ledge plus a T8 flower drop), T4, R1 with signs and the x2 tablet |
| 1-2 Canopy Village | T2 to the tree houses, T6 in the trunk room, Twinbond monkeys; the Feast Land A warp behind X1 drums |
| 2-1 Echo Caverns | T11 torch caves, leeches (N5), paired plates on the hatches |
| 2-2 Bone Gorge, Brute's Den | T5 on the rising stones, T7 pilot and gunner over the gorge, co-op Brute |
| 3-1 Frost Summit, Blizzard Pass | Shellback penguins (N1), T10 leapfrog gaps, a Mammoth (N7) on the frozen lake |
| 3-2 Crystal Grotto | see-saw floes (a drop floe that tips if one hero stands on one end), Raptors (N2), Twin Leapers |
| 4-1 Cinder Shaft | both heroes inside the auto-scroll; T3 tosses across lava strata; C5 carrying an ember pot under the ember rain |
| 4-2 Obsidian Keep, Colossus Hall | leapfrog plate doors (T4), spike switches on X1 drums, the visor Colossus |
| Feast Land A/B/C | giant roasts for two (R4), Relay Bounce chains (S2), Rival mode shines here |
| Way Home | the walk home side by side; the exit counts both heroes |

### 4.6 Validation of co-op gates (solo-proof and fair)

- Every co-op gate gets a solo **impossibility** check: no bounceable enemy, spring or glider within reach of a boost
  ledge (an enemy bounce rises 105 px), no column of hidden spots that allows a club-pogo hover, plates far enough from
  their doors, windows (C2, C3) shorter than the measured solo minimum. A small search with the reference hero
  (as the route tools already do) proves the "cannot alone".
- Every co-op gate gets a co-op **route proof**: two input streams, replayed tick-exactly, per stage and difficulty
  with the weapon pair the campaign carries, plus club/club for the level select.
- Every gate works with every weapon pair (thrown weapons hit plates' drums, eggs, backs of Shellbacks).

---

## 5. Camera and screen

### 5.1 Constraints

- The view is 320 x 180 logical px (20 x 11.25 tiles) at 640 x 360 art px, scaled by whole numbers; wider screens
  show more columns, never fewer (ARCHITECTURE 2). Levels are designed for 20 x 11 (LEVEL_DESIGN 13).
- The authentic camera **pages**: it does not move while the hero walks inside columns 5..15 and slides 16 px per tick
  once he reaches the last 4 columns (PHYSICS.md 12.1); vertically a row window with two speed curves (12.2).
- No zoom exists, and pixel art at an integer scale cannot zoom out smoothly: at 1280 x 720 one art px is already 2 x 2
  screen px, so a 2x zoom-out would draw art at half a screen pixel (shimmer).
- Enemies wake about 2 tiles outside the view and must never attack from outside it.

### 5.2 The tribe camera (recommended)

1. **Focus**: the bounding box of all hatched heroes (eggs, dying heroes and heroes on the leash do not count).
   With one hero the focus *is* the hero and every rule below reduces to PHYSICS.md 12 exactly.
2. **Horizontal paging**: a page right starts when the **front** hero reaches the trigger column (column 16 of 20)
   and stops at whichever comes first: the front hero reaching column 5, or the **rear** hero reaching column 1. Left
   paging mirrors it. Standing heroes never move the view (as now).
3. **Screen walls**: while the rear hero pins the view, the front hero cannot walk past the view's right edge (his x
   step is refused, like the original's commit rule at the level edge, PHYSICS.md 2). NSMB and Rayman work this way.
4. **Vertical**: the row window is applied to the focus box: scroll down only if no **grounded** hero would leave the
   top row; scroll up only if no grounded hero would leave the bottom row. Airborne and falling heroes may leave the
   view - the grounded partner keeps the camera, so one hero's fall into a pit never drags the view away.
5. **Leash**: a hero outside the view gets an edge arrow in his colour with a stone count-down; after 3 s (Expert) /
   5 s (Beginner) he becomes an egg (R1) that flies to the partner - no life lost, no tally loss. Spelunky kills on
   its timer `[S24]`; ours forgives, like the bubbles of NSMB and Rayman `[S1]` `[S7]`.
6. **Anchor**: when the focus box is larger than the view, the camera holds the **anchor** hero in view. The anchor is
   P1 by default; a hero who presses **Look** while standing claims it (Look already pans the camera in solo); an
   egged anchor passes it to the partner. The Blues Brothers' "follow player 1 only" `[S28]` is the anti-pattern this
   replaces.
7. **Locked rooms**: gates take both heroes (curtain, `Flow.play_covered`); `zones/arena` and `zones/camera_lock`
   start only when both are inside - the second arrives as an egg if he is far; arena walls keep both in.
8. **Auto-scroll** (Cinder Shaft): the view scrolls for both; the deadly top edge eggs a hero while his partner lives.
9. **Wide screens** (21:9, phones at 20:9) simply give the pair more room; designs still assume 20 x 11.
10. **Feel**: the page speed and dead zone stay authentic, so the pair feels the same camera as solo; the comfort
    smooth-follow option (PHYSICS.md 12.6) applies to the focus box too.

### 5.3 When one hero falls behind or dies

| Situation | Result |
|---|---|
| Rear hero idles while the front hero pushes | front hero meets the screen wall; nothing else happens |
| One hero falls into the bottom rows / a lower floor | camera stays with the grounded partner; leash count-down; egg after 3-5 s |
| One hero dies (enemy, spikes, pit, lava) | death toss, then egg near the partner (R1) |
| The standing hero dies while the other is an egg | team wipe: curtain, checkpoint, one tribe life |
| A gate is used while the partner is a screen away | both pass; the far one arrives as an egg |
| A hero wants to skip a hard stretch | voluntary egg (Down + Look, 1 s), carried by the partner |

### 5.4 Split screen at 640 x 360 - why not

| Option | What each player sees | Problems |
|---|---|---|
| Vertical split, same scale | 160 x 180 logical = **10 x 11 tiles** | half the look-ahead; the paging dead zone shrinks to columns 2..7, a page every 5 columns; a running jump (5.5-7 tiles) lands near or past the edge; enemies wake about 2 tiles off a 10-tile view and attack almost from off-screen; HUD twice |
| Horizontal split, same scale | 320 x 90 logical = **20 x 5.6 tiles** | a full jump (60 px = 3.75 tiles) fills two thirds of the view; vertical levels (Canopy Village, Cinder Shaft) unplayable |
| Split with 1:1 art scale | a full 20 x 11 view per player needs 640 x 360 screen px per half | at 1280 x 720 the halves are letterboxed; at 1920 x 1080 the integer scale is 1 (tiny) because 1.5 is not allowed; only from 2560 px wide does each half get scale 2 |
| Dynamic split (merge when close, split when far, like Renegade Ops `[S33]`) | shared when close | all of the above when split, plus a moving seam; co-op gates need both heroes in one place anyway |

Pros of split screen (freedom, no leash, no screen walls) matter little here: our co-op levels *want* the heroes
together. Verdict: **shared screen only** for co-op; deathmatch uses single-screen arenas (no camera problem at all).

### 5.5 More than two heroes on the camera

Four heroes about 2 tiles wide each in a 20-column view leave little room; the focus box will often exceed the view,
so the leash would egg someone every few seconds - the "four Jack-in-the-boxes in one box" of NSMB reviews `[S5]`.
The rules above work for N heroes, but 3-4-player co-op would be a party setting, not the designed experience.

---

## 6. Player count, drop-in / drop-out, difficulty

### 6.1 Two players (recommended) vs up to four

| Factor | 2 players | 3-4 players |
|---|---|---|
| View 20 x 11 tiles, paging camera | fits; walls and leash rarely bite | crowded; constant leash eggs |
| The co-op moves | all pairwise (hop, stack, toss, pincer, see-saw, twin windows) | gates either ignore players 3-4 (they become passengers) or need 3-4 variants of every gate |
| Keyboard | two players fit on one keyboard (7.1) | only with pads |
| Touch | a tablet may host two (7.3) | no |
| Enemy cap 12 and readability | fine | sprites and pop-ups everywhere |
| Route proofs | one extra input stream per co-op cell | combinatorial; per-count proofs |
| Precedent | It Takes Two, Unravel Two, Cuphead, Snipperclips, Shovel Knight are two-player by design `[S14]` `[S15]` `[S19]` `[S21]` `[S23]` | NSMB / Rayman 4-player co-op is loved as chaos but criticised for serious play `[S5]` |

Recommendation: **co-op = exactly 2**; engine arrays for **up to 4** so the deathmatch can use 2-4 on single-screen
arenas, and a later "party co-op" for 3-4 remains possible (extra heroes count as additional bodies for plates and
boulders; gates are designed for two).

### 6.2 Drop-in / drop-out

- **Join** at the title (co-op mode), on the world map, or from the pause menu. Joining mid-level restarts the level
  from the active checkpoint in the co-op layout (curtain; score and progress kept), because co-op layouts contain
  different entities. On the world map nothing is lost.
- **Leave** from the pause menu: the level restarts from the active checkpoint in the solo layout. A disconnected pad
  pauses the game: "Reconnect, or continue alone (restarts from the checkpoint)".
- **Saves**: the co-op campaign has its own progress, unlocks and high-score table (Save gains a mode key), so solo
  progress and records stay clean.
- **Hand-over**: a device can be passed between people at any time (pads are slots, not people).

### 6.3 Difficulty scaling

- Beginner / Expert stay; both exist in co-op with the Beginner wall unchanged.
- Co-op Beginner: linked windows (C3, X1) 24 ticks, daze 14 ticks, egg follows forever, leash 5 s, hatch with 2 hearts, lone-wolf enemies off.
- Co-op Expert: windows 12 ticks, egg returns to the checkpoint after 10 s, leash 3 s, hatch with 1 heart, lone-wolf
  enemies on, Grab phases on bosses.
- No hp multiplier on ordinary enemies; bosses at most +25 % hp (the boss hit cooldown already stops damage doubling).
- Optional assist (Options): "Helper mode" makes P2 immune to enemy contact (eggs only from pits) for a child or a
  first-time player. It does not change the gates.

---

## 7. Controls and menu flow

### 7.1 Two players on one keyboard

Keys bind by physical position (works on QWERTY, QWERTZ, AZERTY). WASD and the arrow keys sit on different parts and
rows of the key matrix and are the standard two-player split; a cheap membrane keyboard may still register only two
or three keys at once in one region, so each player's keys stay in his own region `[S34]` `[S35]`.

| Layout | P1 (left) | P2 (right) | Notes |
|---|---|---|---|
| **Classic, one hand each** (default for shared keyboards) | W A S D (W = Up: jump and Up + strike for the high strike), **Space** = strike (left thumb), A + D together = look | arrow keys (Up jumps), **Right Ctrl** or **Num 0** = strike (thumb or index), Left + Right together = look | the original's own scheme: Up jumps, one strike button (PHYSICS.md 4.1). "Up jumps" is forced on for keyboard-shared players. Comfortable: one hand per player, no crossing |
| Two hands each (full-size keyboard) | W A S D + **C** strike, **V** jump, **B** look | arrows + **Num 0** strike, **Num .** jump, **Num 3** look | Nidhogg uses this split (P1 WASD + C/V, P2 arrows + Num 0 / Num .) `[S34]` |
| Two hands each (laptop) | W A S D + **C** / **V** / **B** | arrows + **K** strike, **L** jump, **;** look (left hand) | tight but separated by 2-3 key columns |
| Keyboard + pad | P1 keeps all solo bindings | pad | the most robust; recommended in the join screen hint |

- Pause: Escape (either player), Start on pads. Fullscreen keys unchanged.
- The join screen runs a **key test**: each player holds left + jump + strike; all six lights must stay lit, otherwise
  the screen suggests the one-hand layout or a pad (Microsoft's anti-ghosting demo idea `[S35]`).
- Every slot is rebindable separately (Settings gains a binding set per keyboard slot).

### 7.2 Gamepads

- One pad = one player slot; Godot reports every pad as its own device. Joining = press A (or Start) on that pad.
- Pads keep the solo layout (A jump, X/B strike, Y/RB look, Start pause); vibration per pad.
- Hot-plug: a new pad on the map or in the pause menu can join; a lost pad pauses (6.2).
- Steam Deck / handheld PCs: the built-in controls are one pad; a second pad joins.

### 7.3 Touch

- **Phones**: no two-player touch (two sets of buttons on a 6-inch screen hide the picture and the hands collide).
  Phones support co-op with Bluetooth pads, or touch for P1 plus a pad for P2.
- **Tablets (9 inches and up), "table mode"**: the tablet lies flat; each player gets a mirrored cluster at his
  end of the landscape screen (left: P1, right: P2): a three-way pad (left, right, down) and two buttons (jump,
  strike), 56 art px or more each (the project's touch minimum; Apple asks for at least 44 pt, Material for 48 dp
  `[S36]` `[S37]`), drawn in the player's colour, the play area in the middle. A 4:3 tablet already shows about
  682 x 512 art px, so the clusters can sit below the action. Mark it experimental until tested with real players.
- **Touch helper (later idea)**: Rayman Legends' Murfy and NSMB U's Boost Mode `[S9]` `[S36b]` show a proven asymmetric
  touch role (tap enemies to daze them, tap a drum, hold a plate by touch). It would let a non-gamer join on a tablet
  but would need every gate to accept a "spirit" press, so it is out of scope for the first co-op release.

### 7.4 Menu flow

1. Title -> **Play**: Solo / **Co-op** / Deathmatch.
2. Co-op -> **Tribe Gathering** (join screen): two slots. "Press jump to join" on any device: keyboard left half
   (Space or V), keyboard right half (Num 0 / Right Ctrl / L), any pad, or a tablet cluster. Each slot shows the
   device, the key test lights, the hero colour and "Ready" (hold strike 1 s). A slot can be left again with the
   look key.
3. **Colours**: four palette swaps of the hero, each with a distinct hue *and* a pattern or accessory so they read
   without colour (orange plain - the shipped hero; teal with stripes; purple with spots; green with a bone necklace).
   A small arrow in the player's colour with his number floats above the head when heroes overlap; the club or axe
   shows a tint of the same colour. Recolouring the existing CC0-derived hero sheet is allowed (project art rules).
4. Continue / New co-op game -> Beginner / Expert -> world map (both heads on the marker) -> level.
5. HUD for two: P1 hearts top-left, P2 hearts top-right, tribe lives and the shared score in the centre, G-R-U-B-S
   letters as now; the boss bar under them; leash arrows at the screen edges.
6. Pause menu: resume, restart from checkpoint, controls (per slot), Player 2 join / leave, swap colours, quit.

---

## 8. Engine impact: the N-player refactor and the regression guard

The shipped engine assumes one hero in several contracts: `Game` holds the hero's hearts, bones, weapon and glider;
`GameInput.flags` is one bit mask; `LevelBase.player` is one `PlayerBase`; enemies read "the hero"; `LevelCamera`
follows one position. The refactor keeps every solo path identical:

| Area | Change | Solo invariance |
|---|---|---|
| `Game` | split into team state (score, lives, letters, feast kit, checkpoint, exit, tally of the team) and `PlayerState` per hero (hearts, bones, weapon, glider, own tally list, stats) | the existing fields stay as properties that read and write player 0 |
| `GameInput` | per-slot flag sets (`flags_of(slot)`), device -> slot map, scripted input per slot | `flags` = slot 0; scripted single stream unchanged |
| `LevelBase` | `players: Array[PlayerBase]`, `target_player(pos)`, team respawn and egg logic | `player` = players[0]; with one hero `target_player` returns it |
| Tick order | heroes register in slot order; hero-vs-hero contact and stack riding run in a new sub-step after all heroes moved (PLAYER phase) | the sub-step is skipped with one hero |
| Enemies, bosses | every read of "the hero" goes through `target_player()` | same object, same order, same RNG calls |
| Camera | `LevelCamera.tick(focus_box, ...)` | focus box of one hero = his point |
| Events / HUD | new signals with a player index (existing signals untouched) | - |
| Level format | `coop=only` / `coop=solo` on entity lines, `.coop` meta variants like `.expert` (`LevelText.applies_to`) | solo never loads co-op entities |
| Tests | co-op route proofs with two input streams; solo-impossibility searches for gates | **all 575 existing tests, every route proof, both campaigns must pass after each refactor step**, before any co-op content lands |

Determinism stays as in ARCHITECTURE 4.5: fixed slot order, ties broken by slot index, randomness only from
`Sim.rng`. Order hazards to watch: a rider must move after his carrier (riding resolved after both hero updates), and
the weapon pass must test P1's boxes before P2's.

---

## 9. Sources

- `[S1]` New Super Mario Bros. Wii - Wikipedia: https://en.wikipedia.org/wiki/New_Super_Mario_Bros._Wii
- `[S2]` Iwata Asks: New Super Mario Bros. Wii, Vol. 3, "Solving Multiple Problems with Bubbles":
  https://www.nintendo.com/en-gb/Iwata-Asks/Iwata-Asks-New-Super-Mario-Bros-Wii/Volume-3/1-Solving-Multiple-Problems-with-Bubbles/1-Solving-Multiple-Problems-with-Bubbles-219417.html
  and Vol. 3 page 2: https://iwataasks.nintendo.com/interviews/wii/nsmb/2/1/
- `[S3]` Bubble - Super Mario Wiki: https://www.mariowiki.com/Bubble
- `[S4]` New Super Mario Bros. Wii - Super Mario Wiki: https://www.mariowiki.com/New_Super_Mario_Bros._Wii ;
  co-op review: https://www.co-optimus.com/review/356/page/2/new-super-mario-bros-wii-co-op-review.html
- `[S5]` reviews on NSMB Wii's four-player chaos: https://www.gamereactor.eu/new-super-mario-bros-wii-review/ ,
  https://giantbomb.com/reviews/new-super-mario-bros-wii-review ,
  https://www.resetera.com/threads/new-super-mario-bros-wii-multiplayer-is-perhaps-too-chaotic.589040/
- `[S6]` Super Mario Bros. Wonder removed player collision to reduce stress:
  https://nintendoeverything.com/super-mario-bros-wonder-local-multiplayer-initially-had-collision/ ,
  https://gonintendo.com/contents/26682-super-mario-bros-wonder-originally-had-co-op-collision-but-it-was-removed-to-reduce
- `[S7]` Rayman Origins - Wikipedia: https://en.wikipedia.org/wiki/Rayman_Origins
- `[S8]` Rayman Origins local play (one shared view, no split screen, 4 players): https://splitthescreen.com/game/rayman-origins ;
  co-op information: https://www.co-optimus.com/game/2477/pc/rayman-origins.html
- `[S9]` Rayman Legends - Wikipedia (Murfy, touch co-op): https://en.wikipedia.org/wiki/Rayman_Legends
- `[S10]` Kirby's Return to Dream Land - Wikipedia: https://en.wikipedia.org/wiki/Kirby's_Return_to_Dream_Land ;
  Piggyback: https://kirby.fandom.com/wiki/Piggyback
- `[S11]` Trine 2 - Wikipedia: https://en.wikipedia.org/wiki/Trine_2
- `[S12]` Trine 2 review (several solutions): https://www.gamespot.com/reviews/trine-2-review/1900-6348111/
- `[S13]` LittleBigPlanet co-operative challenges: https://littlebigplanet.fandom.com/wiki/Co-operative_challenge
- `[S14]` Josef Fares on It Takes Two: https://venturebeat.com/games/josef-fares-interview-why-youre-going-to-love-it-takes-two/ ,
  https://www.theringer.com/2021/04/22/video-games/josef-fares-it-takes-two-interview-co-op-gaming
- `[S15]` Unravel Two: https://variety.com/2018/gaming/features/unravel-two-interview-1202842450/ ,
  https://www.thesixthaxis.com/2018/06/09/hands-on-unravel-twos-co-op-platforming-with-martin-sahlin/
- `[S16]` Pico Park - Wikipedia: https://en.wikipedia.org/wiki/Pico_Park
- `[S17]` PICO PARK (Nintendo store page): https://www.nintendo.com/us/store/products/pico-park-switch/
- `[S18]` Overcooked design (Ghost Town Games):
  https://www.nintendo.com/en-gb/News/2017/April/Interview-Cooking-up-chaos-in-Overcooked-Special-Edition-on-Nintendo-Switch-1215687.html ,
  https://www.gamedeveloper.com/design/road-to-the-igf-ghost-town-games-i-overcooked-i-
- `[S19]` Snipperclips - working with Nintendo: https://www.nintendolife.com/news/2017/03/feature_snipperclips_-_working_with_nintendo_to_create_a_switch_co-op_classic
- `[S20]` The Lost Vikings - Wikipedia: https://en.wikipedia.org/wiki/The_Lost_Vikings ; Blizzard developer insights:
  https://news.blizzard.com/en-us/article/17944909/developer-insights-the-lost-vikings
- `[S21]` Cuphead co-op revive (parry the ghost, faster each death):
  https://www.vintageisthenewold.com/game-pedia/can-you-revive-cuphead , https://en.wikipedia.org/wiki/Cuphead
- `[S22]` Cuphead co-op boss health discussion: https://steamcommunity.com/app/268910/discussions/0/1488861734096966284/
- `[S23]` Shovel Knight co-op instruction manual (Yacht Club Games): https://old.yachtclubgames.com/2017/05/co-op-instruction-manual/
- `[S24]` Spelunky co-op (leader flag, off-screen timer): https://www.co-optimus.com/review/1089/page/2/spelunky-co-op-review.html
- `[S25]` Spelunky 2 ghosts and coffins: https://spelunky.fandom.com/wiki/Spelunkers_(2) , https://en.wikipedia.org/wiki/Spelunky_2
- `[S26]` Chip 'n Dale Rescue Rangers (NES): https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/ChipNDaleRescueRangersCapcom ,
  https://giantbomb.com/wiki/Games/Chip_N_Dale_Rescue_Rangers
- `[S27]` Joe & Mac: https://www.hardcoregaming101.net/joe-mac/ ,
  https://www.co-optimus.com/editorial/2462/page/1/co-op-classics-joe-mac-caveman-ninja.html
- `[S28]` The Blues Brothers (Titus, 1991): https://en.wikipedia.org/wiki/The_Blues_Brothers_(video_game) ,
  https://www.lemon64.com/review/blues-brothers/614
- `[S29]` El-Nasr et al., "Understanding and evaluating cooperative games" (CHI 2010), building on Rocha et al.'s
  patterns: https://www.researchgate.net/publication/221516170_Understanding_and_evaluating_cooperative_games ,
  https://www.semanticscholar.org/paper/Understanding-and-evaluating-cooperative-games-El-Nasr-Aghabeigi/3727b4f1fc8e4e90e5f7bbde7e9df742195059bd
- `[S30]` Critical-Gaming, "CO OP Mechanics and Design": https://critical-gaming.squarespace.com/blog/2008/10/25/co-op-mechanics-and-design.html
- `[S31]` Tim Keenan, "Effective Co-Op Design" (Game Developer): https://www.gamedeveloper.com/design/effective-co-op-design
- `[S32]` "Designing death in co-op roguelikes" (Bigosaur): https://bigosaur.com/blog/165-soaw-death
- `[S33]` Split-screen co-op approaches (Renegade Ops dynamic split, Ys shared camera):
  https://ph3at.github.io/posts/Ray-Coop-Camera/ , Godot split screen: https://www.gdquest.com/library/split_screen_coop/
- `[S34]` Two players on one keyboard (Nidhogg layout, rollover caution):
  https://steamcommunity.com/app/94400/discussions/0/496880503062985349
- `[S35]` Keyboard input for two-player games (WASD / arrows, ghosting):
  https://dev.to/imagebear/the-hidden-complexity-of-two-player-browser-games-a-practical-guide-to-keyboard-input-4gea ,
  https://en.wikipedia.org/wiki/Key_rollover
- `[S36]` Apple Human Interface Guidelines, accessibility (44 x 44 pt minimum hit target):
  https://developer.apple.com/design/human-interface-guidelines/accessibility
- `[S36b]` Boost Mode (NSMB U): https://www.mariowiki.com/Boost_Mode
- `[S37]` Android accessibility guidance (touch targets of at least 48 x 48 dp):
  https://developer.android.com/guide/topics/ui/accessibility/apps

Project sources: `docs/spec/GAMEPLAY.md` (sections 5, 6, 12), `docs/spec/PHYSICS.md` (sections 2, 6, 8-13, 15),
`docs/LEVEL_DESIGN.md` (sections 7, 10, 12, 13), `docs/ARCHITECTURE.md` (sections 2-4), `scripts/world/level_camera.gd`,
`scripts/core/game_input.gd`, `scripts/bosses/brute.gd`, `scripts/core/tuning.gd` (`BOSS_HIT_COOLDOWN`).

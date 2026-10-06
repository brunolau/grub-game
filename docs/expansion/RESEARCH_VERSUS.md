# RESEARCH_VERSUS.md - same-device versus ("deathmatch") for Club & Grub

Research and design proposal for the local versus mode of the expansion. Status: **proposal**, nothing here is
implemented. Inputs: `docs/spec/GAMEPLAY.md` (12 = our adaptation), `docs/spec/PHYSICS.md` (all tick and pixel
numbers below come from it unless marked *proposal*), `docs/LEVEL_DESIGN.md`, `docs/ARCHITECTURE.md`, the art in
`docs/media` and `docs/art`. Sources of the survey are numbered `[n]` and listed at the end.

Units: 1 tick = 1/24.2753 s (41.2 ms; "22 ticks = one designer second" is close to 0.9 s); px = logical pixel
(1 cell = 16 px; the 640 x 360 art picture is 320 x 180 logical px = 20 x 11.25 cells); v16 = 1/16 px per tick.

---

## 0. Recommendations in one page

| Question | Recommendation |
|---|---|
| Flagship mode | **Food Fight**: a 90 s round where every hit, stomp or fall knocks food out of the victim (Sonic ring loss [17], Mario vs. Luigi stars [18], Smash coins [8]); most food at the gong wins the round, first to 3 rounds wins. Nobody is ever eliminated. |
| Mode list (6) | Food Fight (flagship), **Last Caveman Standing** (the pure deathmatch: 3 hearts, elimination, themed sudden death, eliminated players fly Grudge Pterodactyls), **King of the Feast** (keep-away with a giant roast), **Hot Rock** (bomb tag), **Letter Snatch** (hidden-spot race + capture the G-R-U-B-S letters), **Egg Heist** (2v2 capture the egg). Launch with the first four; Letter Snatch and Egg Heist in a second wave. A "Party Mix" playlist rotates modes and arenas per round. |
| PvP combat kit | Built from the existing frame data: forward strike (fast, low), high strike (anti-air), stomp (beats crouchers), crouch-charge (wins clashes, launches), thrown axe (ranged, can be batted back). New versus-only rules: **clang** (two strikes meet: both pushed apart), **deflect** (a strike bats an axe back), **heads are always springboards**, the original **bounce multiplier ladder 1-2-3-4-6-8** drives stomp chains. |
| Arenas | **8 single-screen arenas at launch** (20 x 11 cells, one per biome theme plus the Colossus hall and a Feast Land sky arena), 2 stretch arenas later (10 max). 3 of them wrap horizontally, 2 wrap vertically. Tiers 3 rows apart; one signature hazard per arena; visible hidden spots that refill. |
| Balance | Club for everyone; weapons are temporary pick-ups from pterodactyl crates (option: club only / fixed loadout). Versus hurt timing 12 stunned + 30 immune ticks (campaign: 22 + 44), immunity ends when the victim acts. Visible comeback only: proportional spill, a crown bounty on the leader, TowerFall-style autobalance shield [2], Grudge Pterodactyls for the eliminated (Bomberman revenge carts [10]). |
| Bots | **Yes, ship CPU opponents** (Rookie / Hunter / Chief) for Food Fight, Last Caveman Standing, King of the Feast and Hot Rock: 1 human + bots is a common case on Windows and phones, and TowerFall players asked for versus bots in thread after thread (its creator explains why they were left out) [5]. Bots only produce input flags (deterministic, testable headless like the route proofs); arenas are built to be bot-navigable. |
| Players and devices | 2-4 player slots, any mix of devices: up to 2 on one keyboard (two halves), gamepads, 1 touch player on a phone, 2 touch players on a tablet (mirrored corner pads); bots fill empty slots. Every player needs only direction + jump + strike, which also fits a sideways half-controller. |
| Readability | 4 hero palettes chosen for colour-blind safety (Okabe-Ito hues [27]) plus a loincloth pattern per player, name tags at round start and when overlapping, attacker-coloured hit sparks, 2-4 tick hit-stop, off-screen bubbles, corner HUD panels, a replay of the deciding moment (the simulation is deterministic, TowerFall does this [6]). |

---

## 1. What makes local versus entertaining - survey

### 1.1 Game by game

| Game | What it does | Lesson for us |
|---|---|---|
| **TowerFall Ascension** | 2-4 archers on one screen; 3 arrows to start, arrows are picked up again and can be caught; head stomps kill; screens wrap like Pac-Man [1][3]. Modes Last Man Standing (1 point per round won), Headhunters (1 per kill, -1 per self kill), Team Deathmatch; points to win adjustable; **Autobalance** on by default: leaders start with fewer arrows, players 3+ points behind start with a shield [2]. Sudden-death **miasma** closes in [5]. A replay of the final moments plays after every round and can be saved as a GIF [6]. Every player gets 1-3 of 70 end-of-match awards, several about the leader (Most Regal, Usurper = killed the leading player most) and Comeback King/Queen/Kid [3]. Built "for four people in a room"; particle effects were added because spectators could no longer follow fast play [4]. No versus bots: "Making bots fun to fight is a difficult problem ... navigating a level, prioritizing targets, or avoiding the sudden death miasma" (Thorson) [5]. | Short rounds + points target; limited, recoverable ammo; stomps matter; wrap-around makes small arenas deep; visible autobalance; round-end replay; design for spectators; if we want bots, the arenas and modes must be designed for them. |
| **Duck Game** | One hit kills, rounds last seconds to about a minute, weapons come out of presents with random contents, every round a new level [12]; an intermission shows the scores (each duck throws a rock as far as its score) and crowns the winner on a podium [13]. | Rounds so short that elimination does not hurt; randomness as the great equaliser; a funny scoreboard between rounds. |
| **Samurai Gunn** | 2-4 players, sword + gun, **3 bullets per life**, one hit kills, sword hits deflect bullets and swords bounce off swords; some maps wrap horizontally or vertically [14][15]. | Clash and deflect turn a 50/50 into a skill moment; scarce ammo forces melee. |
| **Super Smash Bros.** | Stock (lives), time, coin and stamina (HP) rules [7][9]. Coin battle: coins fly out of the victim on every hit (taken from nobody), a KO costs half of your coins [8]. Sudden Death: everyone at 300 %, and from Melee to Smash 4 Bob-ombs rain after about 20 s [10a]. Handicap: knockback (64 / Melee), then starting damage (Brawl on), with an **Auto** setting [11]. CPU levels 1-9, default 3 [11a]. Respawn invincibility 1-2 s [11b]. Results pages list KOs, falls, self-destructs and many joke bonuses [11c]. | Several rule sets on one engine; coins spraying out of victims is pure spectacle; a sudden death that ends ties fast; Auto handicap; graded CPUs; respawn protection; stats as entertainment. |
| **Rivals of Aether** | Competitive rules: best of 3, 3 stocks, 8 minutes, no items [16]. | The "Classic" preset: no items, fixed stages, stock rules - offer it, never as the default. |
| **Bomberman** | Battle Game sets, best of three; at time-out **Pressure Blocks** fall from the edges toward the centre; eliminated players ride **Revenge Carts** around the edge and throw bombs in [10]; in some versions a revenge kill brings you back [10b]. | Shrinking arena as sudden death; eliminated players stay in the game. |
| **Nidhogg** | Tug of war: a kill gives you the right of way and you run toward your goal; the dead player respawns in front of you at once; first through the last screen wins [19][20]. Two players on one keyboard is the normal set-up; budget keyboards may drop the 4th key [21]. | No waiting after death; territory as score; one-keyboard play needs a key test. |
| **Lethal League** | Only the ball hurts; every hit speeds it up and lengthens the hit-stop, so rallies escalate to one-hit KOs [22]. | Escalation creates natural climaxes; hit-stop sells big hits. |
| **Sonic ring loss** | A hit scatters all rings; about 32 can be recollected before they vanish [17]. Sonic 2's 2P race ranks score, time, rings and boxes [17a]. | Losing *stuff* instead of life is forgiving and readable; the scramble afterwards is the fun. |
| **Mario battle modes** | SMB3's Mario Bros. battle: bump, stomp or POW the other brother to steal his cards [18a]. NSMB **Mario vs. Luigi**: hits make you drop a Big Star (3 for a ground pound), bumping into each other knocks both back and both drop one, stars spawn about 10 s apart at random, most courses wrap [18]. Mario Kart **Shine Thief**: hold the Shine for 20 counts; your count is kept if you lose it, but if you dropped it under 5 it restarts at 5 [18b]. | Dropping the prize on a hit; heavier attacks drop more; mutual bump without damage; cumulative hold timer with a floor. |
| **Gang Beasts** | Floppy physics, grab and throw, ring-outs from hazardous arenas (trucks, grinders, girders) [23]. | Hazards and ring-outs make stories; loose control is fun when failure is funny. |
| **Stick Fight: The Game** | Weapons rain from the sky; last stick standing wins the round; the map changes every round [24]. | Item drops from above are fair (everyone sees them coming) and dramatic. |
| **Ultimate Chicken Horse** | ~1 min rounds; points for goal, placement, traps, solo, and **Comeback** points for an "Underdog" (did not reach the goal for 2+ turns while others did) [25][25a]. | Comeback rewards can be explicit and named. |
| **Pico Park** (battle mode) | Four tiny mini-games; first to win three of them wins [26]. | A playlist of short, rule-light games keeps a party going. |
| **Worms** | When round time expires, Sudden Death raises the water and/or drops every worm to 1 HP; crate drops are configurable [26a][26b]. | A rising hazard ends stalemates; rule toggles. |

### 1.2 Cross-cutting findings

1. **Round structure.** The fun games use many short rounds inside a match (TowerFall, Duck Game, Pico Park,
   UCH ~1 min [25]) or a single continuous fight with a clear finish line (Nidhogg, Shine Thief). Short rounds make
   elimination bearable, reset snowballs and give a scoreboard moment every minute. Target for us: **rounds of
   30-90 s, matches of 4-8 min, at most ~10 s between rounds**, rematch as the default button.
2. **Comeback.** Two families: *structural* (the leader carries more and therefore loses more - Sonic rings, Smash
   coin KO halving, Shine Thief) and *explicit handicaps* (TowerFall Autobalance, UCH comeback points, Smash Auto
   handicap). Hidden rubber-banding is resented; visible, earnable comebacks are not [28]. We use structural ones
   first and explicit ones that are shown on screen.
3. **Chaos vs. skill.** Every successful party game has a dial: Smash items on/off and the "no items" competitive
   preset [16], TowerFall variants and rule sets [1], Duck Game's random presents. One default ("Feast") plus a "Classic"
   (skill) and a "Mayhem" (chaos) preset covers it.
4. **Readability on one screen.** Small cast (2-4), distinct colours, one focus of attention (a ball, a Shine, an
   arrow cloud), big feedback (particles, hit-stop, screen shake [29]) and replays. TowerFall had to *add* effects for
   spectators [4].
5. **Arena size.** Single-screen arenas where any player can reach any other in 2-3 s (TowerFall, Samurai Gunn,
   Duck Game). Wrap-around multiplies routes without growing the screen [1][14][18].
6. **Items.** Visible spawns, ideally falling from the sky (Stick Fight, Smash crates, Worms crates), or from
   known places. Fairness comes from everyone seeing the spawn at the same time.
7. **Sudden death.** Either everyone becomes fragile (Smash 300 %, Worms 1 HP) or the arena shrinks (Bomberman
   pressure blocks, Worms water, TowerFall miasma). Both end a round within ~20 s.
8. **Eliminated players.** Best practice keeps them playing (Bomberman revenge carts, Nidhogg instant respawn);
   otherwise rounds must be very short (Duck Game).
9. **Handicaps** must be per player and optional; Auto modes help mixed groups (Smash [11], TowerFall [2]).
10. **Bots** are expected by solo owners (TowerFall threads [5]); they are only fun when the arena and the mode are
    simple enough for them to play well, and when their difficulty is about reaction and decisions, not cheating
    (Smash level 9 CPUs react in one frame [11a] - a known source of frustration).
11. **Spectator fun**: the room laughs at reversals (a leader losing everything), at near misses and at the
    scoreboard. Make those moments big: spills, clangs, replays, awards.

---

## 2. What Club & Grub brings to a versus mode

### 2.1 Our verbs, with their real numbers

| Mechanic | Numbers (PHYSICS.md / GAMEPLAY.md) | Versus meaning |
|---|---|---|
| Walk | accelerate 16 v16/tick to 80 (5 px/tick); crossing 20 cells takes about 66 ticks (2.7 s) | a 20-cell arena is "one dash wide" |
| Jump | apex 60 px held to the end, **64 px if released after 5-9 ticks**; running jump lands +88 px right / -110 px left (held), up to +111 / -120 with the release trick | platforms 3 rows apart are easy, 4 rows is an expert jump, 5+ needs a spring or a head |
| Forward strike | 7 ticks; damage box ticks 5-7 reaches +11..+35 px ahead, low (-15..-2 px); **earliest hit 5 ticks (0.21 s)**; club repeats every 8 ticks | the fast poke; up close it cannot be reacted to, only read |
| High strike (Up + strike) | 9 ticks; box at +10..+26 px, -43..-27 px (head height and above); earliest hit 7 ticks | anti-air against jumpers and stompers |
| Low strike (Down + strike) | 9 ticks; box -3..+21 px, reaches 10 px below the feet; hop of 6 px | hits crawlers, players on the step below, and spots in the floor |
| Wind-up boxes | live behind and above the hero | a strike also covers your back a little |
| Crouch-charge | 7+ crouched ticks for a fully charged forward strike; lasts 48-49 ticks (2 s) after standing up; the hero glows | the "smash attack": readable wind-up, big reward |
| Head bounce | stomp flag when falling onto the top half of a box (or falling at 8+ px/tick); bounce -224 with jump held (rise 105 px) or -64 (10 px); the victim is not hurt in the campaign | heads are springboards - mobility and a weapon |
| Bounce multiplier | 1, 2, 3, 4, 6, 8 x after 0-1, 2-3, 4-5, 6-7, 8-9, 10+ bounces | the stomp-chain ladder (food spilled per stomp) |
| Club pogo | a club hit while airborne sets yvel -80 (15 px) | air control and "hovering" over a victim |
| Thrown axe / swirling axe | 13 px/tick; axe arcs down (yvel -64, +32/tick), swirling axe curves up (-32, -16/tick); max 4 in flight; ignores walls in the campaign | 320 px in 25 ticks (1.0 s): reactable from across the arena, not from 3 cells |
| Hurt | 22 ticks stunned, 44 immune, rise 36 px, thrown 23-31 px | versus needs shorter values (5.3) |
| Hidden spots | small: one item per hit, at most one per 6 ticks; big: N hits, then a giant bonus falls from 112 px (7 rows) above; touching spots open together | food fountains with a known location |
| Dropped items | fan out, bounce, live 198 ticks (8.2 s), uncollectable for 10, blink the last 15 | the Sonic-ring scramble is already implemented |
| Giant bonus | 10 000-60 000 points; a fast-falling one bounces off a head once | a prize that bonks people |
| Springs | `objects/spring` power -224 (rise 105 px), -288 (rise 171 px, almost the whole screen) | fast vertical routes, launch traps |
| Platforms | moving, ride-only, drop platforms (fall, wait 22 ticks, return), hatches (crouch to drop), breakable blocks, rising columns (1 tile per 4 ticks with shake) | arena dynamics |
| Screen shake | the hero is jolted up every other tick unless crouching | earthquakes push people into stomps |
| Wind / ice | wind pushes up to 6 px/tick, crouch braces; ice halves acceleration and braking per step | ring-out arenas |
| Feast | fork + knife + spoon = 660 ticks (27 s) of eating enemies on touch, shake 7 ticks before the end | the "star" power-up (shortened in versus) |
| Skull / grenade / kill-all | skull scatters all energy as bones; grenade turns enemies into 16 items; kill-all kills the screen | chaos items |
| Letters G-R-U-B-S | five letters, all five drop the 100 000 jackpot | five flags to capture |
| Bones | 6 bones = 1 heart; an enemy that hurt the hero "holds" his heart and bursts into 6 bones | a lost heart becomes 6 bones anyone can grab |

### 2.2 What 24 Hz deliberate movement means for versus

- **Every action is a commitment.** A strike cannot be cancelled (`attack_gate`), a jump arc is nearly fixed (air
  speed cap 3 px/tick with jump held), reversing from full speed takes ~9 ticks. This makes play *readable* and
  rewards prediction: good for a party game and for spectators.
- **Two distance bands.** Inside club range (35 px) the 5-tick strike is faster than human reaction (~0.2-0.25 s):
  close combat is a guessing game (strike / high strike / jump / stomp / crouch). Outside ~6 cells the thrown axe
  takes 12+ ticks (0.5 s) to arrive: ranged play is a reaction game. **Arenas must be at least 18 cells wide** so the
  far band exists, and axes must be scarce so the near band stays the heart of the game.
- **The physics is left-right asymmetric** (`floor16`: leftward motion is up to 1 px/tick faster; a held running
  jump lands +88 px to the right but -110 px to the left). A mirrored arena is therefore not perfectly fair: **rotate
  spawn points every round**, and size every gap so it is crossable to the right (clear gaps of at most 5 cells).
- **Integer, deterministic simulation.** Same inputs, same match: replays of the deciding moment cost only an input
  log plus a snapshot; bot matches can run headless as tests exactly like the route proofs.
- **Hurt timings were made for one hero vs. many enemies.** 1.8 s of immunity per hit would stall a 90 s round;
  versus uses its own table (5.3).

### 2.3 The versus combat kit (proposal)

A rock-paper-scissors triangle that falls out of the existing frame data:

| Action | Beats | Loses to | Why (frame data) |
|---|---|---|---|
| Forward strike | a high strike at the same moment, a grounded player in front | stomp (its box is low and in front), high strike vs. a jumper | 5-tick start, box low |
| High strike | stompers and jumpers (box above the head) | forward strike up close (2 ticks slower) | box -43..-27 px |
| Stomp | crouch-chargers, forward strikers | high strike | falls on the top half of the box |
| Charged strike | any uncharged strike in a clang; launches | stomp (charging means crouching), thrown axe from range | 7 crouched ticks, glow visible |
| Thrown axe | static players, chargers at range | deflect by any strike, jump | 13 px/tick, max 3 ammo |

New versus-only rules (no effect on single-player):

- **Hit** (club / hammer / axe on a hero): the victim loses one unit of the mode's currency (food, a heart, a
  letter...), is knocked *away from the attacker* (campaign heroes are thrown against their own motion, which reads
  wrong in PvP): uncharged `xvel = +/-64, yvel = -128` (rise 36 px); **charged = launch**: `xvel = +/-128` with ice-like
  sliding and `yvel = -160` (rise 55 px), the same shape as the boss body hit that already exists. Hammer: x1.5
  horizontal. Swirling axe: pops the victim up (`yvel = -160`).
- **Clang**: when two strikers' front boxes overlap each other in the same tick, nobody is hurt, both are pushed
  16 px apart, a spark and a clank play (Samurai Gunn's sword-on-sword [14]). A charged strike wins the clang and
  hits. The Colossus already has a clank and spark for glancing blows: reuse them.
- **Deflect**: a strike's front box that meets a thrown axe bats it back, now owned by the striker, 2 px/tick faster
  (Lethal League escalation [22]); an axe deflected twice glows.
- **Stomp**: the stomper bounces exactly as on an enemy (-224 / -64). The victim is **squashed** for 8 ticks (cannot
  jump or strike; the existing `land` squash frame) and loses currency by the **bounce multiplier ladder** of the
  original: the 1st stomp of a chain (no ground touched in between) costs 1, then 2, 3, 4, 6, 8. Chains need
  several heads (or a spring in between), which makes them a mastery skill. A blinking (immune) head is still a
  springboard but costs nothing. Teammates' heads are always free springboards (team boosts, shared with co-op).
- **Body bump**: heroes do not pass through each other freely; overlapping heroes are nudged 1 px/tick apart.
  Running into each other at 4+ px/tick knocks both back like a mutual NSMB bump [18] (Food Fight: no spill).
- **Thrown weapons stop at solid cells** in versus and stick there as pick-ups (TowerFall's arrow economy [1]), so
  solid ground is cover; one-way platforms do not stop them. In wrap arenas an axe wraps once and vanishes after 40
  ticks.
- **Hit-stop**: 2 ticks on a hit, 4 on a charged hit or the deciding hit, plus the existing 3 px shake on charged
  hits only (the camera is fixed, so shake is the only camera feedback) [29].

---

## 3. Candidate modes

All modes: 2-4 players, free-for-all or teams (2v2, 2v1), bots allowed unless noted. Round and match lengths are
defaults; every number is a rule setting.

### 3.1 Food Fight - **flagship**

*"Most food when the gong sounds wins. Get hit and you drop it."*

- **Setup**: everyone starts with the club and an empty belly. No hearts: nobody dies from hits.
- **Food sources**: the arena's visible hidden spots (inset look; a small spot gives one item per hit, refills 15 s
  after it is emptied, sparkles 2 s before); one big spot (3 hits by anyone, then a giant bonus falls from 7 rows
  above - whoever grabs it gets it, and it bonks a head on the way down); pterodactyl crates every ~20 s (food,
  a weapon, one cutlery piece, sometimes a skull); in some arenas a neutral critter carrying 3 food.
- **Values**: small food 1, big food 2, treasure 5, giant bonus 10 - the existing tiers, so a bigger picture is
  worth more. The belly count floats over the HUD panel and as a pile icon above the leader.
- **Spill** (the Sonic rule): hit = 1 + carried/5; charged hit = 1 + carried/2 and a launch; stomp = the ladder
  1-2-3-4-6-8; thrown axe = 1 + carried/8; pit, spikes, lava or water = everything (half bursts out at the spot of
  death, half is lost) and a respawn after 48 ticks. A burst shows at most 12 pieces; bigger amounts come out as
  bigger foods (2s and 5s). Spilled food uses the existing dropped-item physics (198 ticks, blinking); the victim
  cannot pick up for 12 ticks (his stun), others after the usual 10.
- **Items**: *Feast* (fork + knife + spoon, the pieces arrive separately from crates and are dropped on a hit):
  8 s (194 ticks) in which your touch knocks 3 food out of anyone and hits cannot touch you; the existing shake
  warns 7 ticks before the end. *Skull*: whoever touches it spills everything. *Grenade*: every opponent spills 5.
- **Win**: highest belly at 90 s (2 185 ticks; 60 s with 2 players) wins the round; first to 3 round wins.
  Tie: **Golden Drumstick** - one giant bonus falls in the middle, first to grab it wins.
- **Finale**: the last 15 s are a **Feast Rush**: a bell, every spot refills at once, a second giant bonus drops.
- **Why it is fun**: it *is* Club & Grub - clubbing scenery for food, eating, head bounces, giant bonuses falling from
  the sky. Nobody sits out. The leader carries the most and therefore loses the most (structural comeback), and
  everyone can see who is leading. Reversals are loud and visual (a fountain of food out of the leader). Newcomers
  still score by clubbing spots; experts score with stomp chains and charged launches into lava. Bots can play it
  well (goals are items and the leader).
- **Teams**: shared belly; friendly hits only bump; a teammate's head gives the big bounce to the high spots.

### 3.2 Last Caveman Standing - the pure deathmatch

- **Rules**: 3 hearts, one life per round. Hit = 1 heart, charged hit = 2 hearts + launch, stomp = 1 heart + squash,
  hazard = out. A lost heart bursts into **6 bones** (the original's "stolen heart"): 6 bones heal a heart (max 3),
  and anyone can grab them - the victim can recover, the attacker can bank a spare.
- **Win**: last player (or team) alive wins the round; first to 5 round wins (TowerFall structure [2]).
- **Length**: rounds 30-90 s. At 60 s (1 457 ticks) **themed sudden death** starts (table below); every round ends
  within ~20 s after that.
- **Grudge Pterodactyls**: eliminated players ride a pterodactyl along the top of the screen and drop a rock with
  strike (one per 3 s, a 10-tick squawk before it falls, like the Colossus telegraphs). A rock dazes for 12 ticks and
  costs no heart; option **Super Grudge**: a grudge player who lands the deciding hit on someone comes back with one
  heart (Bomberman's revenge rule [10][10b]). Uses the existing pterodactyl sprite with the rider's palette.
- **Option Stock**: 3 lives with respawn (Smash stock [9]) for groups that hate waiting.
- **Why it is fun**: clean stakes, the tension of the last two, guaranteed endings, and eliminated players keep
  playing and can decide the round.

Themed sudden death (also usable as an arena event in other modes):

| Biome | Sudden death | Built from |
|---|---|---|
| Jungle | **Stampede**: chargers run along the floor every 3 s from alternating sides, dust 22 ticks ahead; their heads are springboards | `enemies/charger` |
| Cave | **Cave-in**: blocks fall from the top row inward, one every 11 ticks (Bomberman pressure blocks [10]) | breakable block art, `objects/column` |
| Ice | **Whiteout**: gusts get stronger every 5 s, crouch to brace, the sides are icy water | blizzard wind script |
| Volcano | **Lava rise**: lava rises one row per 44 ticks with a rumble shake that jolts standing heroes (Worms water [26a]) | `~` liquid, shake |
| Feast Land | **Syrup flood**: the same rise as lava, pink | liquid with a feast skin |

### 3.3 King of the Feast - keep-away

- **Rules**: a giant roast drumstick falls in at the start. Carrying it fills your counter: **20 counts** of 22 ticks
  each. The carrier has both hands full: **no strikes** (the campaign already forbids attacks with the glider),
  walk capped at 64 v16, normal jumps. Strike throws it as a heavy lob (axe arc at 8 px/tick); a thrown roast that
  hits someone dazes him. Any hit or stomp on the carrier makes him drop it; it bounces like a giant bonus and can be
  picked up after 10 ticks. Your count is kept when you lose it, but if you had fewer than 5 left it goes back to 5
  (Shine Thief [18b]).
- **Win**: first to finish the 20 counts; at 120 s the lowest remaining count wins. Best of 3 / 5 rounds.
- **Why it is fun**: one object, one focus - perfect readability; everyone automatically gangs up on the leader;
  passing in team play; desperate throws.

### 3.4 Hot Rock - bomb tag

- **Rules**: a glowing ember sticks to a random player. It passes on **any touch**, hit or stomp; whoever just passed
  it cannot get it back for 44 ticks. The holder walks at up to 96 v16 (the chaser is faster). The fuse lasts a
  random 12-20 s; the ember bubbles faster and the sound ticks in the last 3 s. When it pops, the holder is out (food
  explosion, existing death toss); a new ember lands on a survivor after 2 s.
- **Win**: last one standing; first to 3 round wins. Rounds 20-60 s.
- **Why it is fun**: explained in one sentence, panic and laughter, works for kids, on touch, with bots and with
  2 players. No weapons needed. A palate cleanser between heavier modes (Pico Park's lesson [26]).

### 3.5 Letter Snatch - hidden-spot race + capture the letters

- **Rules**: the arena has 8-12 visible spots; five of them hold the letters G, R, U, B, S (shuffled every round),
  the others food, a decoy puff or a skull. Letters you hold float in a row above your head in your colour.
  Hit = drop your newest letter (charged: 2, hazard: all, stomp: 1). A dropped letter bounces and blinks; after 8 s on
  the ground it burrows into a random spot (which glows).
- **Win**: hold all five for 3 s (the existing 44-tick letter blink, then the 100 000 jackpot fridge falls) - round won.
  At 120 s the most letters wins; tie: sudden death. First to 3 round wins.
- **Why it is fun**: two phases in one round - an exploration race (who clubs the right spots) and capture the flag;
  the near-winner is obvious (four letters over his head) so the room turns on him.

### 3.6 Egg Heist - teams (2v2, also 1v1)

- **Rules**: each team has a nest on a raised ledge at its side of the arena; a giant egg drops in the middle. Carry
  it to your nest (carrier rules as in King of the Feast). The egg cracks if it falls more than 6 rows (back to the
  middle after 3 s), so throws are risky. If one carrier holds it for more than 8 s, a **mother rex** hops out and
  chases him (`enemies/hopper` with the rex skin).
- **Win**: first team to 3 eggs; 3-minute cap.
- **Why it is fun**: real team play - escort, block, pass, boost a teammate off your head; the mechanics overlap with
  co-op (sibling research in `docs/expansion/`). Needs team AI for bots, hence the second wave.

### 3.7 Choice of flagship, launch set, playlists, variants

- **Flagship: Food Fight.** It is the only candidate that uses the game's signature verbs (club the world, food
  bursts, head-bounce ladder, giant bonuses) as the scoring itself, keeps all players in play, has a built-in and
  visible comeback, is friendly to mixed skill and to bots, and fits the name of the game. It is the default
  entry of the Versus menu; Last Caveman Standing sits next to it for players who want a classic deathmatch.
- **Launch set**: Food Fight, Last Caveman Standing, King of the Feast, Hot Rock. **Second wave**: Letter Snatch,
  Egg Heist (needs team bots and the egg art).
- **Party Mix**: a playlist that picks mode and arena per round from the enabled ones (Duck Game / Stick Fight new map
  every round [12][24], Pico Park mini-games [26]); score = round wins across modes.
- **Presets**: *Classic* (club only, no crates, no handicap - the Rivals-style skill set [16]), *Feast* (default),
  *Mayhem* (crates every 8 s, skull spots, a random variant per round).
- **Variants** (TowerFall-style rule toggles [1]): Hammer Time (everyone has the hammer), Axe Rain (pterodactyls drop
  axes), Big Bounce (every head bounce is the big one), One-Bonk (1 heart, Samurai Gunn style), Slippery (ice
  braking everywhere), Lights Out (night palette, heroes glow), Skull Surprise (spots may throw skulls), Gusty
  (random wind), Giant Rain (a giant bonus every 20 s), Coconut Rally (one coconut that speeds up when struck,
  Lethal League [22] - a candidate seventh mode if it tests well).

---

## 4. Arena design

### 4.1 Principles (single screen, 640 x 360, this physics)

1. **Size**: author every arena as **20 x 11 cells** (320 x 176 px) with the floor the heroes stand on in row 10
   (LEVEL_DESIGN 9: an 11-row camera rectangle with the floor as its bottom row), plus fill below. Row 0 holds no
   standing places (HUD corners and the round timer live there). Lock the camera to the rectangle. Wider or taller
   views (800 x 360 phones, 4:3 tablets) show a decorated frame around it, never gameplay - ARCHITECTURE 2 forbids
   assuming 640 x 360.
2. **Heights**: tiers 3 rows apart (48 px; jump apex 60 px). 4 rows (64 px) is an expert jump (release after 5-9
   ticks). 5+ rows only by spring (-224 = 105 px) or head bounce (105 px) - this is where stomping becomes movement.
   Springs of -288 (171 px) only under a ceiling, or the hero leaves the screen.
3. **Gaps**: at most 5 cells clear at the same height (crossable to the right, see 2.2). Close wall ends with ground
   or `|` unless the gap is a deliberate pit.
4. **Width for ranged play**: at least 18 cells of open line somewhere (axe from across the arena takes ~1 s).
5. **Symmetry**: mirror the layout left-right; rotate spawn points every round to cancel the physics asymmetry.
6. **Spawns**: 4-8 spawn points, at least 6 cells apart, never under a spring path, never next to a hazard; respawn at
   the free point farthest from opponents.
7. **Wrap-around**: horizontal wrap in 3 arenas, vertical (fall out of the bottom, enter at the top) in 2. Wrapped
   platforms continue across the seam; on wide views draw the wrapped columns beyond the edge so nothing pops. The
   campaign's off-camera death rule (feet more than 20 columns or 11 rows from the camera) and the x commit rule are
   replaced by arena bounds in versus.
8. **Hidden spots**: 4-8 per arena, **visible** (`look=inset` or a prop) - in versus, knowing where food comes from
   beats discovering it; place them on contested heights. One big spot per arena with 7 free rows above it (or the
   giant falls in from above the screen).
9. **Hazards**: one signature hazard per arena; every lethal event is telegraphed 10+ ticks ahead (the Colossus
   fairness rule). Mind the ceiling-spike rule: any hit knocks a hero up 36 px.
10. **Cover**: solid blocks stop axes in versus; one-way platforms do not. Breakable blocks are cover that can be
    clubbed away and grows back after 15 s.
11. **No foreground props over play spaces** (heroes would hide); darkness only with hero glow.
12. **Bot-friendly geometry**: platforms and links that a navigation graph can describe (no 1-row squeezes, no
    pixel-perfect jumps on the main routes).
13. **Item drop lanes**: pterodactyl crates are dropped from the top row on lanes that land on floors, not in pits.

### 4.2 The arenas (8 at launch, 2 stretch)

| # | Arena | Biome / art | Edges | Signature feature | Default mode |
|---|---|---|---|---|---|
| 1 | **Vine Ring** | jungle | wrap left-right | springs to wrapped side ledges, a cake-like top island with the big spot, reachable only by a head bounce from the bridge (sketch below) | Food Fight |
| 2 | **Canopy Huts** | jungle village | walls, a pit in the middle | hatches, drop platforms, a ride lift over the pit, hut roofs | King of the Feast |
| 3 | **Echo Hollow** | cave | wrap top-bottom (a shaft in the floor) | darkness pulses every 20 s (3 s of night, heroes glow), regrowing breakable walls, a dangler as a neutral springboard | Letter Snatch |
| 4 | **Bone Ring** | cave / bone gorge | walls with bone spikes | rising columns reshape the floor every 20 s (rumble 22 ticks ahead; the shake jolts standing heroes) | Hot Rock |
| 5 | **Frozen Pond** | ice | open sides into icy water | ice floor, drop floes, alternating gusts - knock-back slides: ring-outs | Last Caveman Standing |
| 6 | **Cinder Pit** | volcano | walls, lava below | obsidian slabs, ember rain zone, lava-rise sudden death | Last Caveman Standing |
| 7 | **Colossus Hall** | volcano keep | walls | the Wall Colossus as a neutral: every ~10 s it spits a rock at the current leader (telegraphed jaws); stalactites | Food Fight |
| 8 | **Sky Picnic** | Feast Land | wrap top-bottom, no deaths | springs, icing clouds, a cake island; the kid-safe arena | Egg Heist / Food Fight |
| 9 | *Crystal Teeth* (stretch) | ice cave | wrap left-right | falling icicles (leaf-hazard logic), crystal spots | any |
| 10 | *Sugar Rush* (stretch) or an arena in a biome of the 20 new levels | Feast Land / new | walls | syrup flood, moving platforms | any |

Egg Heist plays on arenas 2, 5 and 8 with nest markers; a wider scrolling Egg Heist strip (40 x 11 cells, group
camera) is possible later but is not in the count.

Sketch of **Vine Ring** in the level format (LEVEL_DESIGN 4; to be validated with `tools/validate_levels.gd`):

```
     col 01234567890123456789
row  0   ....................   HUD row: nothing to stand on
row  1   ....................
row  2   ......#?#**#?#......   top island: 2 small spots, the big spot pair (giant falls in from above)
row  3   ......########......
row  4   ....................
row  5   ----............----   one 8-cell ledge across the wrap seam
row  6   ....................
row  7   .......------.......   bridge (48 px above the floor: a plain jump)
row  8   ....................
row  9   ..J..............J..   springs, power -224: rise 105 px, land on the side ledges
row 10   ####?##########?####   floor with two small spots, wraps left-right
row 11   ####################
```

Routes: floor to bridge by a jump (48 px); floor to ledge by spring; ledge to island by a jump (48 px); bridge to
island is 80 px - only by bouncing off someone's head. The prize sits where you need an opponent to reach it.

---

## 5. Balance

### 5.1 Weapons: pick-ups, not loadouts

- **Default**: everyone starts every round with the club. Hammer, axe and swirling axe come from pterodactyl crates
  and are **temporary** (lost when you lose a life, or after 3 axe throws / 2 swirling-axe throws once the thrown
  ones are gone), so a lucky pick-up does not snowball. Thrown axes stick in walls and can be picked up by anyone.
- **Options**: Club only (Classic), Random loadout (everyone gets the same random weapon each round), Pick-ups
  (default).
- **Roles**: club = fast all-rounder; hammer = slower (6-tick lock), bigger box, x1.5 knock-back; axe = ranged poke,
  arcs down; swirling axe = anti-air, curves up. Charged power x4 in the campaign becomes the *launch* in versus.

### 5.2 Respawn

- Food Fight / Stock option: respawn after 48 ticks at the free spawn farthest from opponents; **spawn shield** for
  48 ticks that ends the moment the player strikes or throws (Smash revival invincibility 1-2 s [11b]).
- Elimination modes: no respawn; Grudge Pterodactyls instead.

### 5.3 Invulnerability and stun-lock prevention (versus table, campaign values untouched)

| Event | Stun (no control) | Immune to hits | Note |
|---|---|---|---|
| Hit | 12 ticks (0.5 s) | 30 ticks (1.2 s), blinking | immunity ends early if the victim strikes or throws |
| Charged hit (launch) | 16 ticks | 36 ticks | |
| Stomp | 8 ticks squash | none from strikes; same stomper cannot stomp the same head again for 44 ticks | heads stay springboards |
| Grudge rock / thrown roast | 12 ticks daze | 44 ticks against grudge rocks | |
| Respawn | - | 48 ticks or until the first strike | |

Immunity is always longer than the stun, so two attackers cannot juggle a victim; acting ends immunity, so it
cannot be used to attack safely. Clangs and deflects give the defender a skill answer.

### 5.4 Comeback mechanics (all visible)

1. **Proportional loss**: spill grows with what you carry (Food Fight), letters held are the target (Letter Snatch),
   the King's count floor (King of the Feast).
2. **Crown bounty**: the round leader wears a crown (TowerFall tracks the leader and rewards hunting him with its
   Usurper award [3]; its Quest mode crowns the better player of each level [3a]); a hit on the crowned player spills
   2 extra; the Colossus in arena 7 targets the leader.
3. **Autobalance** (on by default, TowerFall [2]): a player 2+ round wins behind starts the round with a **leaf
   shield** (absorbs one hit, drawn around him).
4. **Grudge Pterodactyls** for the eliminated (Bomberman [10]).
5. **Feast Rush** and the Golden Drumstick: the end of each Food Fight round is a free-for-all.
6. No hidden rubber-banding: crate contents do not depend on rank (a hidden "blue shell" is resented [28]).

### 5.5 Handicap

Per player, shown on the lobby card: hearts 1-5 (elimination modes), belly guard (Food Fight spill x0.5 / x1 /
x1.5), start weapon. Global: Off / On / **Auto** (Smash's Auto adjusts handicaps after each match by who won [11]; our
proposal: the winner's handicap rises one step, the last player's falls one step).

### 5.6 2, 3 and 4 players, teams

- 2 players: same arenas (TowerFall does the same); Food Fight rounds 60 s; suggest adding bots.
- 3 players: the crown matters most (two gang up on the leader).
- 4 players: free-for-all or 2v2. Teams share a hue family (warm / cool) with a team marker under the feet; friendly
  hits only bump; teammates' heads are free springboards.
- More than 4: not supported (screen, devices, readability of 22 px heroes on a 320 px stage).

### 5.7 Bots - recommendation: yes

**Why**: the game ships on Windows and is prepared for phones and tablets, where one person often plays alone; a
versus mode without bots is unused by them, and the TowerFall community asked for them repeatedly [5]. Bots also fill
a 3-human game to 4, teach the modes, and - because the simulation is deterministic - give us automated balance tests.

**How (proposal)**:

- A bot is an **input producer**: each tick it writes the same input flags a human slot would (Left, Right, Up,
  Down, Jump, Strike). No physics shortcuts, no hidden information (it does not know spot contents). Bot decisions
  use the match's seeded RNG, so a bot match replays tick for tick, headless.
- **Navigation graph per arena**, baked offline by a tool: nodes = standable spans; links = walk, drop, hatch drop,
  jump with k held ticks (k = 1..11, from `PHYSICS_REFERENCE.json`'s jump tables), spring, wrap; every link is
  verified by simulating the real hero, like the route proofs. Arena rule 4.1.12 keeps this tractable.
- **Behaviour**: utility choice every 6 ticks between goals (grab food / letter / roast, open a spot, chase the
  leader, flee, charge); combat micro-rules from the triangle in 2.3 (high strike when someone is above within
  26 px, crouch-charge when an opponent approaches from 3+ cells, stomp when above a croucher, deflect axes).
- **Levels**: Rookie (reaction 10 ticks, decides every 12, never charges, never deflects), **Hunter** (default;
  reaction 6, uses stomps and charge), Chief (reaction 3, stomp chains, deflects 50 %, never frame-perfect - Smash
  level 9 CPUs are frustrating [11a]).
- **Scope**: launch for Food Fight, Last Caveman Standing, King of the Feast, Hot Rock; Letter Snatch and Egg Heist
  bots with the second wave.
- **Tests**: 4 Hunter bots finish a round on every arena without getting stuck; no hit within 48 ticks of a spawn;
  win rates per spawn point within a band (the left-right asymmetry check); weapon win rates logged.

---

## 6. Controls, readability and menus

### 6.1 Telling four cavemen apart

- **Palettes**: the hero is an orange cartoon caveman; recolour body, hair tuft and loincloth (palette swaps of the
  CC0 hero are allowed). Default four from Okabe-Ito hues, which stay distinct for the common colour-vision
  deficiencies [27]: **P1 orange** (the original), **P2 sky blue**, **P3 bluish green**, **P4 reddish purple**; extra
  choices yellow, vermilion, dark blue, stone grey. Okabe and Ito also recommend not relying on colour alone [27]:
  every player also gets a **loincloth pattern** (spots, stripes, zigzag, plain) and a number tag. Arena critters
  avoid the player hues (no orange enemies in arenas). Use a palette-swap shader instead of 8 x 4 weapon sheets.
- **Name tags**: a small "P1" / "CPU" arrow in the player colour with a black outline (Press Start 2P) above the
  head for 3 s at round start and after a respawn, and whenever heroes overlap.
- **Off-screen**: a bubble with the hero's head at the screen edge when a hero is above the view (springs) or beyond
  it in a scrolling arena; arrow plus distance.
- **Feedback**: hit sparks in the *attacker's* colour (who hit whom is readable), spill bursts, "BONK!", "CLANG!",
  "GRUB!" pop-ups in the HUD font, 2-4 tick hit-stop [29], the crown on the leader, letters over heads.
- **HUD**: four compact corner panels (face icon in the player colour, hearts or belly, held letters / items); top
  corners for P1 / P2, bottom corners for P3 / P4 over the ground fill (arena rule 4.1.1 keeps play out of those
  rows); panels fade when a hero is behind them. Round timer at top centre (a sundial).

### 6.2 Devices

- **Joining**: a lobby with four slots; *press Jump on any device to join*. Each keyboard half counts as a device.
  Hot-plugging gamepads must work (Godot sends keyboard events with device 0, the same id as the first joypad, so
  the slot mapping has to tell event classes apart [30]).
- **One keyboard, two players** (Nidhogg's usual set-up [21]): **Keys A** = W A S D + C (jump) + V (strike);
  **Keys B** = arrow keys + numpad 0 (jump) + numpad . (strike), laptop alternative . (jump) + / (strike). Keys are
  bound by position like the campaign, and rebindable per slot. Cheap keyboards block or ghost when several keys are
  held [31]: the join screen shows a **key test** (both players hold everything and see what registers). "Up jumps"
  is not used (Up + strike is the high strike).
- **Gamepads**: any number up to 4 slots; A jump, X / B strike (campaign default); Start pauses. Because a player
  needs only direction + 2 buttons, one sideways half-controller per player works.
- **Touch**: phone = one touch player (others on gamepads or bots); **tablet = up to two touch players** with
  mirrored corner pads (a left / right slider with crouch on slide-down, jump and strike stacked vertically, 56 art px
  targets per ARCHITECTURE 9) at 50 % opacity over the ground rows. Swipe up on strike = high strike. Each finger is
  tracked by its touch index. Phones as Wi-Fi controllers are out of scope (local-only rule).

### 6.3 Menus and flow

1. **Versus** -> **lobby**: join, palette (left / right, duplicates only in team mode), team toggle, *Add CPU* with
   level, handicap card. Each player readies on his own device.
2. **Rules**: mode, preset (Classic / Feast / Mayhem), round wins, round time, crates, weapons, handicap, variants.
   Whoever pressed Start controls this screen. The last rules are remembered.
3. **Arena select**: thumbnails, Random, Party Mix.
4. **Round**: heroes burst out of spots (the "3, 2, 1, GRUB!" count-in), play, gong.
5. **Deciding moment**: in elimination modes the last 3 s replay at half speed (TowerFall [6]); in Food Fight the
   biggest spill of the round. Skippable.
6. **Scoreboard** (5 s): round wins as drumsticks thrown onto each player's plate (Duck Game's rock throw [13]).
7. **Results**: podium with the victory pose; the **tally companion** NPC presents 1-3 **awards** per player (TowerFall's 70
   awards [3], Smash's results pages and bonuses [11c]): *Glutton* (most food eaten), *Butterfingers* (most dropped), *Pogo Stick* (most
   head bounces), *Chain Gang* (longest stomp chain), *Clang Master* (most clangs), *Batter Up* (axes deflected),
   *Lava Lover* (hazard deaths), *Spot Hunter* (spots opened), *Head Case* (bonked by a falling giant bonus), *Hot
   Potato* (longest ember hold), *Comeback Caveman* (won a round from last place), *Pacifist* (no hits, still scored).
   Buttons: **Rematch** (default), Change rules, Quit.

### 6.4 Spectator fun

Big readable events (spills, clangs, launches, crowns), the replay, pop-up words, awards, Grudge Pterodactyls that
let the eliminated mock the living, and the Feast Rush finale. The rule of thumb from TowerFall: if the people on the
sofa cannot follow it, add feedback until they can [4].

---

## 7. Constraints for the implementation (for the architecture work)

- **Regression guard**: versus runs only in new arena files (`kind = arena`) and its own mode table; campaign
  constants and code paths stay untouched. New passes (hero-vs-hero contact, clang, deflect, projectiles vs heroes)
  must be no-ops with one hero, so all 575 route proofs keep replaying tick for tick.
- **Several heroes** in the simulation and per-slot input flags (`GameInput.flags` is one mask today) - the same
  change co-op needs; share it.
- **Determinism**: a match seed for every random choice (spawns, crates, spot contents, bots) -> input-log replays and
  headless bot tests.
- **Item budget**: the original's "20 active items" cap is too low for food fountains; budget about 60 dropped items
  and check the 8 ms CPU target at 800 x 360.
- **Art and audio (all CC0-compatible)**: palette swaps of the CC0 hero; the existing pterodactyl, crate, food,
  letters, giant bonus, lava, colossus, explosion and slash art; small new UI pieces (crown, tags, arrows, sundial,
  leaf shield, ember, egg, plates) drawn in the anchor style or composited from shipped CC0 sheets; gong, bell, clank
  and cheer picked from the CC0 sound packs already shipped. Any new third-party file goes through CREDITS.md and
  THIRD_PARTY.md like today.

## 8. Open questions for playtests

1. Does a stomp cost a heart in Last Caveman Standing, or only squash? (Proposal: costs one.)
2. Spill fractions (1/5, 1/2) and the 12 / 30 tick hurt table.
3. Hot Rock fuse visible or hidden.
4. Wrap rendering on wide screens: copies of the seam columns vs. a frame.
5. Whether two touch players on a phone are ever playable (proposal: no).
6. Whether Coconut Rally deserves to be a seventh mode.

---

## Sources

1. TowerFall - Wikipedia. https://en.wikipedia.org/wiki/TowerFall ; PC Gamer review (wrap, stomps, catching arrows) https://www.pcgamer.com/towerfall-ascension-review/
2. TowerFall Wiki, Versus (modes, points, Autobalance). http://towerfall.wikidot.com/versus
3. The TowerFall Wiki, Awards (versus awards, leader awards, Usurper, Comeback). https://towerfall.wiki.gg/wiki/Awards
3a. TowerFall Ascension Steam announcements (patch notes: the Quest "Level Complete" screen awards the crown). https://steamcommunity.com/app/251470/announcements/
4. "The magic of TowerFall: depth, simplicity, community", Game Developer. https://www.gamedeveloper.com/design/the-magic-of-i-towerfall-i-depth-simplicity-community ; Shacknews, local-only approach https://www.shacknews.com/article/83560/towerfall-ascension-creator-discusses-local-multiplayer-only-approach
5. Steam discussion "Add bot pls", developer replies on versus bots and the miasma. https://steamcommunity.com/app/251470/discussions/0/540743757720340856/ ; also https://steamcommunity.com/app/251470/discussions/0/558749824942904792/
6. TowerFall replays and GIF export: Steam guide "Making Replays look good". https://steamcommunity.com/sharedfiles/filedetails/?id=548441362
7. SmashWiki, Stamina Mode. https://www.ssbwiki.com/Stamina_Mode
8. SmashWiki, Coin Battle. https://www.ssbwiki.com/Coin_Battle
9. SmashWiki, Stock. https://www.ssbwiki.com/Stock
10. Konami, Super Bomberman R online manual, battle rules (best of three, pressure blocks, revenge carts). https://www.konami.com/games/bomberman/online/manual/en/ps/page04.html
10a. SmashWiki, Sudden Death. https://www.ssbwiki.com/Sudden_Death
10b. Bomberman Wiki, Bad Bomber (Misobon, "Super" return rule). https://bomberman.fandom.com/wiki/Bad_Bomber ; Sudden Death https://bomberman.fandom.com/wiki/Sudden_Death
11. SmashWiki, Handicap. https://www.ssbwiki.com/Handicap
11a. SmashWiki, Artificial intelligence (CPU levels 1-9). https://www.ssbwiki.com/Artificial_intelligence
11b. SmashWiki, Revival platform (respawn invincibility). https://www.ssbwiki.com/Revival_platform
11c. SmashWiki, Results screen; List of bonuses. https://www.ssbwiki.com/Results_screen ; https://www.ssbwiki.com/List_of_bonuses
12. Duck Game - Wikipedia https://en.wikipedia.org/wiki/Duck_Game ; DualShockers review https://www.dualshockers.com/duck-game-review-switch/
13. Duck Game Wiki, Intermission. https://duckgame.fandom.com/wiki/Intermission
14. Samurai Gunn - Wikipedia. https://en.wikipedia.org/wiki/Samurai_Gunn
15. PC Gamer, Samurai Gunn review (wrap-around maps). https://www.pcgamer.com/samurai-gunn-review/
16. Rivals of Aether Wiki, Competitive Rules. https://rivals-of-aether.fandom.com/wiki/Competitive_Rules
17. Sonic Wiki, Ring (scatter, ~32 recoverable). https://sonic.fandom.com/wiki/Ring
17a. Sonic Wiki, Sonic the Hedgehog 2 (2P versus categories). https://sonic.fandom.com/wiki/Sonic_the_Hedgehog_2
18. Super Mario Wiki, Mario Vs. Luigi. https://www.mariowiki.com/Mario_Vs._Luigi
18a. Super Mario Wiki, Mario Bros. (Super Mario Bros. 3). https://www.mariowiki.com/Mario_Bros._(Super_Mario_Bros._3)
18b. Super Mario Wiki, Shine Thief. https://www.mariowiki.com/Shine_Thief
19. Nidhogg - Wikipedia. https://en.wikipedia.org/wiki/Nidhogg_(video_game)
20. Destructoid, Nidhogg review. https://www.destructoid.com/reviews/review-nidhogg/
21. Steam discussion, Nidhogg on one keyboard. https://steamcommunity.com/app/94400/discussions/0/496880503062985349
22. Lethal League - Wikipedia https://en.wikipedia.org/wiki/Lethal_League ; TV Tropes https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/LethalLeague
23. Shacknews, Gang Beasts review. https://www.shacknews.com/article/102538/gang-beasts-review-royal-fumble
24. Steam guide, In Depth Guide to Stick Fight. https://steamcommunity.com/sharedfiles/filedetails/?id=2821046017 ; TV Tropes https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/StickFight
25. Ultimate Chicken Horse - Wikipedia. https://en.wikipedia.org/wiki/Ultimate_Chicken_Horse
25a. Clever Endeavour support, Custom rules and presets (point types, Underdog). https://cleverendeavourgames.freshdesk.com/support/solutions/articles/32000028991-custom-rules-and-presets
26. PICO PARK Wiki, Battle Mode. https://pico-park.fandom.com/wiki/Battle_Mode ; Wikipedia https://en.wikipedia.org/wiki/Pico_Park
26a. Worms Wiki, Sudden Death. https://worms.fandom.com/wiki/Sudden_Death
26b. Worms Wiki, Game Style (crates per turn). https://worms.fandom.com/wiki/Game_Style
27. Okabe and Ito, Color Universal Design (palette and "do not rely on colour alone"). https://jfly.uni-koeln.de/color/ ; reference values https://wjake.wjakethompson.com/reference/palette_okabeito.html
28. Comeback mechanics and rubber banding: "Theory: Rubber Bands", Law of Game Design https://lawofgamedesign.com/2014/08/25/theory-rubber-bands/ ; TV Tropes, Comeback Mechanic https://tvtropes.org/pmwiki/pmwiki.php/Main/ComebackMechanic
29. Jan Willem Nijman (Vlambeer), "The art of screenshake", INDIGO Classes 2013. https://www.youtube.com/watch?v=AJdEqssNZ-U
30. Godot proposals: device id conflict between joypads and keyboard https://github.com/godotengine/godot-proposals/issues/7161 ; local multiplayer input mapping https://github.com/godotengine/godot-proposals/issues/10887
31. Key rollover - Wikipedia. https://en.wikipedia.org/wiki/Key_rollover

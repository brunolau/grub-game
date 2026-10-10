# Club & Grub 2.0.0 - "The Far Shore"

Release notes for players. The short list of changes is in [CHANGELOG.md](../CHANGELOG.md); the text prepared for
the GitHub release page is at the end of this file.

2.0 is a free update of the same game. It more than doubles it: a second campaign, a game for two on one keyboard,
and a party game for up to four.

## What you get

### Book II: The Far Shore

At the homecoming feast the two chieftains of the Tar Tribe swoop down on their Storm Roc and carry off the Great
Roast. Grub lashes a raft together and follows the crumbs across five new lands:

| World | Stages | Boss |
|---|---|---|
| 5 Sunbaked Canyon | Red Mesa Trail, Rattlesnake Gulch | Tusker, the Boar King (Tusker's Wallow) |
| 6 Tar Fen | Bubbling Fen, Spore Hollow | Old Mangrove, the Rooted Guardian (Heart of the Mangrove) |
| 7 Coral Coast | Shell Beach, Sea Caves | Inkjaw, the Grotto Squid (Squid Grotto) |
| 8 Idol Ruins (Expert) | Overgrown Steps, Hall of Idols | the Twin Idols (Idol Court) |
| 9 Sky Spire (Expert) | Cloudbreak Climb, Thunderhead Glide, The Roc's Spire, Chieftains' Pyre | the Storm Roc (Storm Nest), then the Rival Chieftains Gorm and Gulla |

Twenty new stages in all, counting the two new Feast Lands (Honey Falls, Pudding Lagoon) behind hidden warps and
the playable ending, The Long Raft Home. Beginner plays worlds 5 to 7; Expert plays everything. Book II is open from the start:
choose **Play > Solo > Book II**. It has its own world map, its own level codes and its own save slots.

### The belt and the spear

In Book II the club is never lost. A special weapon you pick up - hammer, axe, swirling axe or the new **spear** -
rides on your **belt**, and the new **Swap** button puts it in your hand or away again. The spear flies straight and
sticks in bark boards, where it becomes a step. Book I played alone keeps the weapon rule of 1.0, so everything
you learned there is still true.

### Chomper

A rex you can tame and ride. He wades through tar, walks over urchins and eats what stands in his way.

### New ground, new trouble

Vines to climb and rolled vines to knock open, tar that holds your feet, geysers that throw you, rafts on
currents, a tide that rises under you. Rollers come down the slopes, Guards hold their ground, and not every
treasure chest is one. Thirty **Cave Paintings** are hidden - one in every Book II stage and ten behind two-player
secrets of Book I in co-op; finding them opens loincloth patterns and variants for the versus game.

### Co-op: the tribe of two

**Play > Co-op** is the whole game again for two players on one computer - all 35 stages of both books, each rebuilt
so that some gates open only for a pair:

- **Shoulder Hop**: land on your partner's head with jump held and you fly a storey higher.
- **Totem Ride**: stand on your partner and be carried.
- **Batter Up**: curl into a ball (Down + Swap) and let your partner bat you across a gap.
- **Brace Wall**: crouch side by side and a charging heavy stops dead.
- plates that need two, twin drums, see-saws, boulders too heavy for one, and enemies only a pair can beat.

You share one camera and one stock of lives. A fallen hero comes back as an egg that follows his partner and is
hatched with a strike; the tribe loses a life only when both are down. A stone tablet carved with two cavemen marks
every place that needs both of you. Near those places beasts wear chalk-white marks: **marked beasts are no stepping
stones - use your partner's shoulders**.

Two options make it kinder or meaner: **Helper mode** (player 2 cannot be hurt - for a small brother or sister) and
**Rival score** (each keeps an own score). Co-op progress is saved apart from solo progress.

### Versus: two to four on one screen

**Play > Versus** is a party game in eight single-screen arenas, with bots (Rookie, Hunter, Chief) for the empty seats:

| Mode | The idea |
|---|---|
| **Grub Stack** | everything you grab stacks on your head; hits knock it off, stomps steal it, the cookpot banks it |
| **Last Caveman Standing** | three hearts each, lost hearts burst into bones anyone can grab; then the arena itself turns on you |
| **Hot Rock** | a glowing ember sticks to one player and passes on every touch - do not hold it when it pops |
| **Clubball** | bat a coconut into the other goal; the direction of your strike is the shot |

Arenas: Totem Ring, Echo Hollow, Floe Rink, Cinder Pit, Tar Pulleys, Coconut Cove, Sky Picnic and Colossus Hall.

Every round ends: a Last Caveman Standing round has a hard cap a minute after the arena turns on you, a tied Grub
Stack round is decided by the Golden Drumstick - grab it within a minute or the round is drawn - and a coconut
nobody has struck for 15 seconds drops in at the middle again. When the cap ends a round the banner says so:
**TIME!** stands over the result at the gong, through the replay of the deciding moment and before the result on
the scoreboard.

## Controls for two on one keyboard

The default layout puts one player at each end of the keyboard:

| | Walk | Jump | Strike | Swap | Look |
|---|---|---|---|---|---|
| **Player 1** | W A S D | Space | Left Ctrl | E | Q |
| **Player 2** | numpad 8 4 5 6 | Num 0 | Num Enter | Num + | Num . |

The numpad works with Num Lock on or off. Player 1 strikes with Ctrl and not with Shift because Windows lets go of
Shift whenever a numpad key is pressed. Two more layouts are offered where you join ("Two hands each" for keyboards
without a numpad: W A S D with F G R T, and the arrows with `.` `/` `,` `;`; "One hand each"), every key can be
rebound per player, and the join screen has a **key test**: hold your keys together and see whether your keyboard
reports them all (cheap keyboards drop some combinations - choose another layout or use a gamepad then).

Gamepads: one per player - A jump, X or B strike, Y or RB look, LB swap, Start pause. Versus seats three and four
need gamepads.

Playing alone, the controls are those of 1.0, plus **Swap on V or `;`** (pad LB) in Book II.

## Your 1.0 save carries over

- Install 2.0 over 1.0 (the installer replaces it in place) or unpack the zip; your saves are not part of the
  installation and stay where they are (`%APPDATA%\ClubAndGrub`).
- Everything you reached in 1.0 is under **Solo > Book I**: unlocked stages, best results, the finished game, code
  stones, the high score - for Beginner and Expert separately, as before.
- Your options and your key bindings are used as they are. If you had bound **V**, **`;`** or **pad LB** to an
  action in 1.0 - the three inputs 2.0 gives to the new Swap button - your binding wins: that input does what you
  set it to and nothing else, and Swap keeps the others (give it another key or button under *Options > Key
  bindings* if you like).
- The level codes of 1.0 open the same stages.
- Before 2.0 writes its first save, it copies your 1.0 save, untouched, to `save.v1.json` in the same folder, and
  never changes that copy. If you ever want to go back to 1.0.0: close the game, rename `save.v1.json` to
  `save.json`, install 1.0.0. (1.0.0 does not read a 2.0 save: it shows no progress. If you play it anyway and
  return to 2.0, nothing is lost - 2.0 merges what both versions wrote.)
- The game never deletes a file it cannot read. If `save.json` is damaged (a crash, a full disk), 2.0 goes on
  with the backup `save.json.bak`, sets the damaged file aside as `save.bad.json` at its next save, and keeps
  the good backup until a new save has been written and read back. A `settings.cfg` it cannot read is kept as
  `settings.bad.cfg` before the default options take its place.

## Exactly the old game where it should be

Book I played alone is 1.0.0 tick for tick: the same 15 level files, the same physics and scores. Every recorded
play-through of 1.0.0 still replays to the same result in 2.0.

## Download and install (Windows 10 / 11, 64-bit)

- **`ClubAndGrub-2.0.0-setup.exe`** - the installer. No administrator rights needed; it upgrades an installed 1.0.0.
- **`ClubAndGrub-2.0.0-windows.zip`** - the portable version: unpack anywhere and run `ClubAndGrub.exe`.

An OpenGL 3.3 graphics driver is needed. The files are not code-signed, so SmartScreen may warn on first start:
*More info > Run anyway*. The game uses no network, has no accounts and collects no data.

## Good to know

- Co-op is for exactly two players; versus for two to four. Both are played on one computer - there is no online
  play.
- Android, iOS and macOS builds are prepared in the project but are not part of this release.
- **Known in 2.0.0**: on the arena Echo Hollow the starting places are not equally good when CPUs play - over many
  rounds the right floor wins more than its share of Grub Stack and the left shelf of Last Caveman Standing. The
  starting places rotate every round, so over a match everybody stands on each of them; a rebuild of the arena is
  planned for the next version.
- **Small things known in 2.0.0**: when a capped round is the last of a match, the results screen does not repeat
  "TIME!" (the gong and the replay said it); the chalk marks of co-op are faint on the palest beasts (gulls,
  ghosts, snow turtles: the dark edges carry them); two heroes standing on one spot wear their "P1" / "P2" tags
  side by side, and for a moment a tag can stand on the far side of its hero; under *Options > Buttons* one row
  label is cut short ("SHARED..") and Pause shows "-" for both players (Esc and P pause for everyone); the
  Book I card of the book select shows your 1.0 high score until a 2.0 run beats it, then Book I's own best.
- Every co-op gate was proven by machine to need two heroes, and every stage has a recorded play-through that the
  test suite replays. What only people can judge - how the co-op stages feel to a mixed pair, the versus modes with a
  full sofa, key combinations on many keyboards, the music by ear - is listed step by step in
  `docs/expansion/HUMAN_CHECKS.md` and decides what a 2.0.1 tunes. Tell us what you find:
  https://github.com/brunolau/grub-game/issues

---

## Text for the GitHub release page (`v2.0.0`)

> **Club & Grub 2.0.0 - The Far Shore**
>
> A free update that more than doubles the game.
>
> - **Book II: The Far Shore** - 20 new stages in five new worlds, six new bosses, two new Feast Lands and a
>   playable ending. Open from the start (Play > Solo > Book II).
> - **The weapon belt and the spear** - keep your club, carry a special on the belt, swap with V (pad LB). The
>   spear sticks in bark boards and becomes a step.
> - **Chomper the rex** - tame him, ride him, let him eat.
> - **Co-op for two on one keyboard** - all 35 stages rebuilt with gates that need both of you: Shoulder Hop, Totem
>   Ride, Batter Up, Brace Wall. P1: W A S D, Space jump, Left Ctrl strike, E swap, Q look. P2: numpad 8 4 5 6,
>   Num 0 jump, Num Enter strike, Num + swap, Num . look. Gamepads work too.
> - **Versus for two to four**, with bots - Grub Stack, Last Caveman Standing, Hot Rock and Clubball in eight
>   arenas.
> - **Your 1.0 save carries over** - progress, options and key bindings; the 1.0 file is kept as `save.v1.json`.
> - Book I played alone is exactly 1.0.0, tick for tick.
>
> **Download**: `ClubAndGrub-2.0.0-setup.exe` (installer, upgrades 1.0.0 in place) or
> `ClubAndGrub-2.0.0-windows.zip` (portable). Windows 10 / 11, 64-bit, OpenGL 3.3. Not code-signed: SmartScreen >
> *More info > Run anyway*.
>
> Full notes: `docs/RELEASE_NOTES_2.0.md`. All art and audio CC0, fonts OFL: `CREDITS.md`.
>
> SHA-256 of the published files (the second build of 2026-10-10, after the release polish):
> `ClubAndGrub-2.0.0-setup.exe` `ca415db076769d082f4b74a4d21f715fa8eb7469b077a4aa5e2600225062dbc4`
> `ClubAndGrub-2.0.0-windows.zip` `10c70ef7041684fc984d5314b60fc19e050afc58e7e8dc7901385644313f987e`

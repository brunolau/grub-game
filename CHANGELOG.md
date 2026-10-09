# Changelog

Every version of Club & Grub, newest first. What a player gets from 2.0 is told at length in
[docs/RELEASE_NOTES_2.0.md](docs/RELEASE_NOTES_2.0.md).

## 2.0.0 - "The Far Shore"

A free update of the same game: install it over 1.0.0 (or unpack the zip anywhere). Saves and settings of 1.0.0
carry over.

### New

- **Book II: The Far Shore** - 20 new stages in five new worlds (Sunbaked Canyon, Tar Fen, Coral Coast, Idol Ruins,
  Sky Spire), two new Feast Lands and a playable ending, with its own world map, level codes and save slots.
  Beginner plays worlds 5-7, Expert plays everything. Book II is open from the start.
- **Six new bosses**: Tusker the Boar King, Old Mangrove, Inkjaw the Grotto Squid, the Twin Idols, the Storm Roc
  and the Rival Chieftains Gorm and Gulla.
- **The weapon belt and the spear** (Book II): the club is never lost, one special weapon rides on the belt, and a
  new **Swap** button (V or `;`, pad LB) changes hands. The spear sticks in bark boards and becomes a step.
- **Chomper the rex**: a mount that is tamed, ridden over tar and urchins, and eats enemies.
- **New ground and new trouble**: vines to climb and to unroll, tar, geysers, rafts on currents, the rising tide;
  the Roller, the Guard and the Mimic chest; 30 Cave Paintings to find, which open loincloth patterns and versus
  variants.
- **Co-op for two** on one computer: every stage of both books has a co-op version (35 stages) with gates that
  need two heroes - Shoulder Hop, Totem Ride, Batter Up, Brace Wall, plates, twin drums, see-saws, heavy boulders
  and enemies that only a pair can beat. One shared camera, tribe lives, and the Egg Hatch that brings a fallen
  partner back. Options: Helper mode (player 2 cannot be hurt) and Rival score.
- **Versus for two to four** on one computer, with bots for empty seats (Rookie, Hunter, Chief): Grub Stack, Last
  Caveman Standing, Hot Rock and Clubball in eight single-screen arenas (Totem Ring, Echo Hollow, Floe Rink, Cinder
  Pit, Tar Pulleys, Coconut Cove, Sky Picnic, Colossus Hall).
- **Two players on one keyboard**: player 1 on W A S D, Space, Left Ctrl, E, Q; player 2 on the numpad (8 4 5 6,
  0, Enter, +, .). Two more layouts for keyboards without a numpad, a key test for ghosting, one gamepad per player,
  every key rebindable per player.
- New music for every new world, boss, arena and menu; all art and audio CC0, fonts OFL (CREDITS.md).
- In co-op, beasts near a two-player gate wear chalk-white marks: marked beasts are no stepping stones.
- Every versus round ends: Last Caveman Standing has a hard cap ("TIME!"), a Golden Drumstick nobody takes within a
  minute ends its round drawn, and a coconut nobody has struck for 15 seconds drops in at the middle again.

### Changed

- The title menu: **Play** opens Solo / Co-op / Versus; Solo and Co-op then ask for the book and the difficulty.
- **Save format version 2**: progress is kept per mode (solo, co-op), book and difficulty. A 1.0 save becomes
  Solo > Book I, with nothing lost; before the first 2.0 save is written the 1.0 file is copied untouched to
  `save.v1.json` in the same folder, and it stays there.
- Settings keep their format; options and key bindings of 1.0.0 are used as they are. A key or button a 1.0
  player had bound that 2.0 gives to the new Swap (V, `;`, pad LB) stays his: Swap gives it up.
- Alt+Enter and F11 switch fullscreen on every screen.
- The installer upgrades a 1.0.0 installation in place (same folder, same Start menu entry).

### Unchanged on purpose

- **Book I played alone is exactly 1.0.0**: the same 15 level files, the same physics, tick for tick; every
  recorded route of 1.0.0 still replays to the same score. Book I solo keeps the 1.0 weapon rule (no belt).
- Level codes of 1.0.0 open the same stages.
- Windows 10 / 11 (64-bit), OpenGL 3.3; one self-contained exe; no network, no accounts, no data collected.

### For developers

- `tools/build_installer.ps1 -TestInstall` installs a throwaway twin of the installer (its own AppId, name and
  Start menu group), so it is safe on a machine where the game is installed; `-OutputRoot` builds beside the
  release files. `tools/build_windows.ps1` now also runs the asset and licence audit and reads the file table of
  the exported exe: no developer level, test, tool or recorder, no asset outside the manifest.
- The level validator and the co-op gate search are left out of every export.
- `tools/bots/soak.sh` (4 x 1 000 seeded versus rounds with CPUs, every rule checked on every tick),
  `tools/perf.sh` (the tick's cost with one, two and four heroes) and `tools/audit_assets.py` (every asset, its
  manifest row and its licence) are part of the release checklist (docs/BUILD.md 7).

### Known

- Echo Hollow's starting places are not equally good in Grub Stack and Last Caveman Standing when CPUs play
  (measured over 384 rounds; the places rotate every round). See docs/expansion/DESIGN.md G97.
- What only people can judge - pair playtests of the co-op stages, the music by ear, key combinations on real
  keyboards, pads, an Android device - has not been done: docs/expansion/HUMAN_CHECKS.md lists every check.

## 1.0.0

The first release: Book I, "The First Feast" - 15 stages in four worlds, two bosses, three Feast Lands and the way
home; Beginner and Expert; keyboard, gamepad and touch; a Windows exe, zip and installer.

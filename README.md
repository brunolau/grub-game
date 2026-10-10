# Club & Grub

A hungry caveman clubs his way through jungles, caves, ice fields and a volcano: he bounces on heads, knocks
hidden food out of the scenery, spells G-R-U-B-S for a jackpot and eats everything that is not nailed down.

Club & Grub is an original 2D platformer that reproduces the *gameplay and physics* of Prehistorik 2 (Titus, 1993)
tick for tick - the same 24.3 Hz simulation, momentum, jumps, club strikes, hidden spots, bosses and stage flow -
with entirely original levels, code and freely licensed (CC0 / OFL) art and audio.

**Version 2.0, "The Far Shore"**, more than doubles the game: a second campaign of 20 stages with six new bosses,
the weapon belt, the spear and a rex to ride; **co-op for two on one keyboard** through every stage of both books;
and **versus for two to four** with bots. Saves of 1.0 carry over. What is new, at length:
[docs/RELEASE_NOTES_2.0.md](docs/RELEASE_NOTES_2.0.md); every version: [CHANGELOG.md](CHANGELOG.md).

| | |
|---|---|
| ![Title screen](docs/media/title.png) | ![The world map](docs/media/map.png) |
| ![1-1 Vine Bridges](docs/media/jungle.png) | ![Feast Land, a bonus stage](docs/media/feast.png) |
| ![3-1 Blizzard Pass](docs/media/blizzard.png) | ![The Wall Colossus](docs/media/colossus.png) |

> **An homage, not a copy.** Club & Grub is not affiliated with, endorsed by or connected to Titus Interactive or
> the owners of Prehistorik. It contains no graphics, audio, level data or code of that game or of any other
> commercial game. All third-party material is listed in [CREDITS.md](CREDITS.md).

## Download and install (Windows)

Get the latest version from [Releases](https://github.com/brunolau/grub-game/releases/latest):

- **`ClubAndGrub-<version>-setup.exe`** (2.0: `ClubAndGrub-2.0.0-setup.exe`) - the installer. Installs for your
  user account without administrator rights (or for all users, if you choose so), adds Start menu and optional
  desktop shortcuts and an uninstaller under *Settings > Apps*. An installed 1.0.0 is upgraded in place. Saved games
  and settings stay in `%APPDATA%\ClubAndGrub`; uninstalling asks whether to delete them too.
- **`ClubAndGrub-<version>-windows.zip`** - the portable version: unpack anywhere and run `ClubAndGrub.exe`.

Windows 10 or 11 (64-bit) with an OpenGL 3.3 graphics driver. The files are not code-signed yet, so Windows
SmartScreen may warn on first start: choose *More info > Run anyway*.

**Coming from 1.0?** Your progress, options and key bindings are used as they are: everything you reached is under
*Play > Solo > Book I*. Before 2.0 writes its first save it copies your 1.0 save, untouched, to `save.v1.json` in the
same folder and never changes that copy.

## Features

- **Faithful feel**: the hero's weight, skids, jumps, head bounces and strike timing follow a frame-exact
  specification of the original (`docs/spec/PHYSICS.md`), verified against reference traces by the test suite.
- **Book I, The First Feast - 15 stages**: four worlds of two stages, two bosses (the Brute and the Wall Colossus),
  three Feast Land bonus stages behind hidden warps, and the way home. Beginner plays worlds 1-3 and ends at the
  expert wall; Expert adds the volcano, the Colossus and the ending. Played alone it is exactly the game of 1.0.
- **Book II, The Far Shore - 20 stages** (2.0): five new worlds - Sunbaked Canyon, Tar Fen, Coral Coast, Idol Ruins,
  Sky Spire - with six bosses (Tusker, Old Mangrove, Inkjaw, the Twin Idols, the Storm Roc, the Rival Chieftains),
  two more Feast Lands and a playable ending. Vines, tar, geysers, rafts on currents, a rising tide, **Chomper the
  rex** to ride, and 30 hidden Cave Paintings. Open from the start; Beginner plays worlds 5-7.
- **The weapon belt and the spear** (Book II): the club is never lost, one special rides on the belt, Swap changes
  hands; the spear sticks in bark boards and becomes a step.
- **Co-op for two** (2.0) on one computer: all 35 stages again, each with gates only a pair can pass - Shoulder Hop,
  Totem Ride, Batter Up, Brace Wall, plates, twin drums, see-saws - one shared camera, tribe lives and the Egg Hatch
  that brings a fallen partner back.
- **Versus for two to four** (2.0) on one computer, bots for empty seats: Grub Stack, Last Caveman Standing, Hot
  Rock and Clubball in eight single-screen arenas.
- **Hidden everything**: odd ground, rocks, bushes and walls hide food, treasures, hearts and giant bonuses; the
  letters G-R-U-B-S drop a 100 000-point jackpot; secret rooms behind gates and cracked walls.
- **Five weapons** a run keeps from stage to stage: the club, the hammer, the thrown axe, the swirling axe and
  (Book II) the spear. Crouch to charge your next blow (four times the damage) - the hero glows while it lasts.
- **Glider, wind, ice, darkness, an auto-scrolling lava shaft**, rising columns, drop floes and springs.
- **Progress**: checkpoints, a level code for every solo stage, saved progress and high score per mode (solo,
  co-op), book and difficulty, a level select of the stages reached.
- **Any screen**: the 640 x 360 picture is scaled by whole numbers; wider or taller screens show more of the level,
  never black bars. Keyboard, gamepad and touch, every action rebindable.
- **Proven playable**: every stage has recorded input routes, replayed tick for tick by the test suite (Book I for
  every weapon a player can bring into it); every co-op stage has a two-player route, and every co-op gate is proven
  by a search to need two heroes.

## Controls

| Action | Keyboard | Gamepad | Touch |
|---|---|---|---|
| Walk | Left / Right, A / D | D-pad, left stick | on-screen pad |
| Jump (hold it as you land on a head to bounce high) | Z, K (Up / W too while "Up jumps" is on) | A | jump button |
| Strike (hold Up for a high strike, Down for a low one) | Space, X, J | X, B | club button |
| Crouch (charges the next blow), enter a gate, drop through a hatch | Down, S | D-pad down, stick down | on-screen pad |
| Look ahead | C, L, keypad 5 | Y, RB | look button |
| Swap hand and belt (2.0, Book II) | V, `;` | LB | swap button |
| Pause | Escape, P | Start | pause button |
| Menus | arrows, Enter / Space, Escape | D-pad, A, B | tap |
| Fullscreen (desktop) | Alt+Enter, F11 | - | - |

Keys are bound by their position, so the layout works on every keyboard; Options rebinds every game action for
keyboard and gamepad. The game pauses by itself when its window loses focus.

### Two players on one keyboard (2.0: co-op and versus)

The default ("classic") layout, also the versus default:

| | Walk | Jump | Strike | Swap | Look |
|---|---|---|---|---|---|
| **Player 1** | W A S D | Space | **Left Ctrl** | E | Q |
| **Player 2** | numpad 8 4 5 6 | Num 0 | Num Enter | Num + | Num . |

The numpad works with Num Lock on or off. P1's strike is not Shift because Windows lets go of Shift while a numpad
key is pressed with Num Lock on. Keyboards without a numpad use the layout "Two hands each" (P1: W A S D, strike F,
jump G, look R, swap T; P2: arrows, strike `.`, jump `/`, look `,`, swap `;`); a third layout, "One hand each", jumps
with Up. The join screen offers the three layouts, has a key test that shows whether your keyboard reports both
players' keys together, and every key can be rebound per player. Gamepads: one per player with the layout of the
table above; players three and four of a versus match need gamepads.

## The stages

| Stage | Name | What happens there |
|---|---|---|
| 1-1 | Vine Bridges | jungle tutorial: the club, hidden spots, head bounces, vine bridges over a lake, a canopy road home |
| 1-2 | Canopy Village | a tall tree village: the axe, danglers, lifts, a trunk room; a bat bounce up to the warp to Feast Land A |
| 2-1 | Echo Caverns | hatches between cave chambers, darkness, swinging bats, gates to secret rooms, the hammer, the warp to Feast Land B |
| 2-2 | Bone Gorge, Brute's Den | rising stepping stones, a lift pillar, the hang-glider over the gorge, then boss 1: the Brute |
| 3-1 | Frost Summit, Blizzard Pass | slippery snow on ice, a frozen lake, a cliff climb, chargers; then the gusts of a blizzard (crouch to brace) |
| 3-2 | Crystal Grotto | drop floes over icy water, leapers, the swirling axe, the warp to Feast Land C - the last Beginner stage |
| 4-1 | Cinder Shaft | Expert: an auto-scrolling descent through lava strata and ember rain |
| 4-2 | Obsidian Keep, Colossus Hall | Expert: a fortress of rising columns and spikes, then boss 2: the Wall Colossus |
| - | Feast Land A, B, C | bonus stages full of food behind the warps of 1-2, 2-1 and 3-2 |
| - | Way Home | the epilogue after the Colossus: the walk home to the village, then The End |

### Book II: The Far Shore (2.0)

| Stage | Name | What happens there |
|---|---|---|
| 5-1 | Red Mesa Trail | the belt, Swap and the spear; bark boards on palisades; Rollers down long sand slopes |
| 5-2 | Rattlesnake Gulch, Tusker's Wallow | a gulch climbed on vines, the warp to Feast Land D; then boss: Tusker, the Boar King |
| 6-1 | Bubbling Fen | tar floors, rafts on slow currents, Chomper the rex tamed and ridden |
| 6-2 | Spore Hollow, Heart of the Mangrove | a dark mushroom cave with geysers; a rising tide of tar inside a hollow tree; then boss: Old Mangrove |
| 7-1 | Shell Beach | surf, blowholes, Chomper over urchin beds, the warp to Feast Land E |
| 7-2 | Sea Caves, Squid Grotto | drift floes over deadly water; then boss: Inkjaw - the last Beginner stage |
| 8-1 | Overgrown Steps | Expert: rising columns on trigger plates, Guards, Mimic chests |
| 8-2 | Hall of Idols, Idol Court | Expert: a maze of gates and secret rooms; then boss: the Twin Idols |
| 9-1 | Cloudbreak Climb, Thunderhead Glide | Expert: a climb on vines and steam, then a glider crossing through a storm |
| 9-2 | The Roc's Spire, Storm Nest | Expert: gusts and crumbling clouds; then boss: the Storm Roc |
| 9-3 | Chieftains' Pyre | Expert: the final boss, the Rival Chieftains Gorm and Gulla |
| - | Feast Land D, E | Honey Falls and Pudding Lagoon, behind the warps of 5-2 and 7-1 |
| - | The Long Raft Home | the playable ending of Book II |

Every stage of both books has a co-op version (*Play > Co-op*), and versus has its own eight arenas: Totem Ring,
Echo Hollow, Floe Rink, Cinder Pit, Tar Pulleys, Coconut Cove, Sky Picnic and Colossus Hall.

## Running from source

The engine is not part of this repository.

1. Download **Godot 4.7.2 stable, standard build** (not .NET) from
   [godotengine.org](https://godotengine.org/download/archive/4.7.2-stable/) or the
   [GitHub release](https://github.com/godotengine/godot/releases/tag/4.7.2-stable).
2. Either open the project folder in the Godot editor and press F5, or from a terminal in the project folder:

   ```
   godot --headless --path . --import    # once: builds Godot's import cache
   godot --path .                        # play
   ```

The development scripts expect the console binary in `.tools/godot/` (on Windows
`.tools/godot/Godot_v4.7.2-stable_win64_console.exe`), or the path in the `GODOT` environment variable;
`bash .tools/gd.sh` explains what to download when it cannot find it. User data (`settings.cfg`, `save.json` with
its backup `save.json.bak`, and `save.v1.json`, the untouched copy of a 1.0 save) lives in `%APPDATA%/ClubAndGrub/`
on Windows, `~/Library/Application Support/ClubAndGrub/` on macOS and in the app sandbox on phones. A save or
settings file the game could not read is never deleted: the next save sets it aside there as `save.bad.json` /
`settings.bad.cfg` (numbered when one exists), and a readable `save.json.bak` is kept until a new save has been
written and read back.

## Tests and development tools

Run from the project root with Git Bash (or any POSIX shell). `.tools/gd.sh` wraps Godot so that several tools can
share the folder; the plain Godot command is in brackets.

| What | Command |
|---|---|
| Import (after a checkout or a new `class_name`) | `bash .tools/gd.sh import` (`godot --headless --path . --import`) |
| All tests (about 1 780; slow modules skipped) | `GD_TIMEOUT=600 bash .tools/gd.sh test` (`godot --headless --path . -s res://tests/run_tests.gd`) |
| One module / one test | `bash .tools/gd.sh test player --verbose`, `bash .tools/gd.sh test campaign --only=world_2` |
| Every route proof (all weapons) and both campaigns, headless | `bash .tools/gd.sh test campaign_routes` |
| A slow module (co-op gate search, versus bot matches) - named in full, or all with `--slow` | `bash .tools/gd.sh test coop_gates`, `GD_TIMEOUT=900 bash .tools/gd.sh test --slow` |
| Single-player tick identity of 2.0 (after any code change) | `bash tools/sp_identity.sh` (last line `IDENTICAL`) |
| The three proofs of every co-op gate (after a change to the simulation or a co-op level; about 50 minutes) | `bash tools/world_coop_gates.sh` |
| The whole gate table of 2.0 (about 70 minutes) | `bash tools/g3.sh --require` |
| Real 1.0.0 profiles loaded by 2.0 | `bash .tools/gd.sh test core_save` (fixtures: `tests/data/saves_1_0/`) |
| Boot check | `bash .tools/gd.sh smoke 3` (`godot --headless --path . -- --smoke=3`; exit code 0 = clean log) |
| Watch a route | `bash .tools/gd.sh play --autoplay=w2_l2b --difficulty=expert --weapon=axe --inputs-file=tools/autoplay/routes/w2_l2b.expert.axe.inputs --fast` |
| The whole Expert campaign, played and checked | `GD_TIMEOUT=1800 bash .tools/gd.sh play --flow=tools/autoplay/campaign.flow --fast --fresh-user` |
| Check level files | `bash .tools/gd.sh script res://tools/validate_levels.gd -- --strict` |
| Render a whole level | `bash .tools/gd.sh script res://tools/world_render_level.gd -- w1_l1 --collision` |

Screenshots of harness runs land in `build/screenshots/<name>/`. How to build a level is in
[docs/LEVEL_DESIGN.md](docs/LEVEL_DESIGN.md); the architecture, module ownership and every API are in
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md); the gameplay and physics specifications are in `docs/spec/`.

## Building a release

Windows (one self-contained `.exe`, plus the licence texts in the release zip):

```
powershell -ExecutionPolicy Bypass -File tools\build_windows.ps1
```

The script checks Godot and the export templates, imports the project, runs the asset and licence audit and the
whole test suite, exports `build/windows/ClubAndGrub.exe`, starts it for a smoke check, reads the list of files
packed inside it (no developer level, test, tool or recorder; no asset outside the manifest), puts the licence
texts into `build/windows/licenses/` and packs `build/ClubAndGrub-<version>-windows.zip`; it stops with exit code 1
at the first problem.

The installer (`build/ClubAndGrub-<version>-setup.exe`, Inno Setup 7, see [docs/BUILD.md](docs/BUILD.md) 3.4):

```
powershell -ExecutionPolicy Bypass -File tools\build_installer.ps1 -TestInstall
```

`-TestInstall` installs, checks and removes a throwaway twin of the installer (its own application id, name and
Start menu group), so it is safe on a machine where the game is installed: a real installation, its Start menu
entry and its saves are never touched, and the script proves that on every run. `-OutputRoot <folder>` on both
scripts builds beside the release files instead of replacing them.

Every platform, the export templates and the signing placeholders: [docs/BUILD.md](docs/BUILD.md). Android, iOS
and macOS status: [docs/PORTING.md](docs/PORTING.md).

## Project structure

| Path | Content |
|---|---|
| `scripts/`, `scenes/` | game code and scenes: `core` (autoloads, simulation clock, flow, input, audio, save), `base` (the contract classes), `player`, `enemies`, `bosses`, `projectiles`, `objects`, `items`, `fx`, `world`, `zones`, `ui` |
| `levels/` | level files (plain text, format in ARCHITECTURE.md section 7): `w<world>_l<stage>[b].lvl`, `bonus_*.lvl`, `ending*.lvl`, their co-op versions `<id>_coop.lvl`, the versus arenas `arena_*.lvl`; `test_*.lvl` are developer levels (not exported) |
| `assets/` | art, fonts and audio (all third-party, licences in `assets/licenses/`) |
| `locale/` | the English texts (`en.po`) |
| `tests/` | the headless test suite (`run_tests.gd` runs every `test_*.gd`); `tests/data/saves_1_0/` holds real 1.0.0 profiles |
| `tools/` | build script, level tools, autoplay flows and route proofs (`tools/autoplay/`) - not exported |
| `docs/` | architecture, specifications, level design, build, porting and third-party notes (not exported) |
| `build/` | scratch output: exports, screenshots, test user data (ignored by Godot and git) |

## Credits and licence

Art, sound and music are CC0 packs by Pixel-boy / Sparklin Labs, ARoachIFoundOnMyPillow, ghostpixxells, Pixel Frog,
ansimuz, Juhani Junkala, MintoDog, Wolfgang_ and others; the fonts Press Start 2P and Pixelify Sans are under the
SIL Open Font License; made with [Godot Engine](https://godotengine.org) (MIT). The full list with sources and
changes is in [CREDITS.md](CREDITS.md), the licence texts are in `assets/licenses/` (and readable in the game under
Credits > Licences), and [docs/THIRD_PARTY.md](docs/THIRD_PARTY.md) lists every obligation and how it is met.

The game's own code, levels and documentation: all rights reserved, see [LICENSE](LICENSE).

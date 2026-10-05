# Club & Grub

An original prehistoric 2D platformer: a hungry caveman clubs his way through jungles, caves, ice fields and a
volcano, opens hidden bonus spots, bounces on heads and eats everything that is not nailed down.

Club & Grub reproduces the *gameplay and physics* of Prehistorik 2 (Titus, 1993) tick for tick - the same 24.3 Hz
simulation, momentum, jumps, club strikes, hidden spots, bosses and stage flow - with entirely original levels,
code and freely licensed (CC0 / OFL) art and audio. It contains no graphics, audio, level data or code of the
original or of any other commercial game. See [CREDITS.md](CREDITS.md).

- Engine: Godot 4.7.2, GDScript only, statically typed.
- Platforms: Windows now; Android, iOS and macOS prepared (see [docs/PORTING.md](docs/PORTING.md)).
- Input: keyboard, gamepad and touch; every game action can be rebound.
- Any screen shape: the 640 x 360 base picture is scaled by whole numbers; wider or taller screens show more level.

## The game

Four worlds, eight stages, two bosses, three bonus stages and an epilogue. Beginner plays worlds 1-3 and ends at
the expert wall; Expert adds the volcano, the Wall Colossus and the way home.

| Stage | Name | What happens there |
|---|---|---|
| 1-1 | Vine Bridges | jungle tutorial: the club, hidden spots, head bounces, vine bridges over a lake, a canopy road home |
| 1-2 | Canopy Village | a tall tree village: the axe, danglers, lifts, a trunk room; a bat bounce up to the warp to Feast Land A |
| 2-1 | Echo Caverns | hatches between cave chambers, darkness, swinging bats, gates to secret rooms, the hammer, the warp to Feast Land B |
| 2-2 | Bone Gorge, Brute's Den | rising stepping stones, a lift pillar, the hang-glider over the gorge, then boss 1: the Brute |
| 3-1 | Frost Summit, Blizzard Pass | slippery snow on ice, a frozen lake, a cliff climb, chargers; then gusts of a blizzard (crouch to brace) |
| 3-2 | Crystal Grotto | drop floes over icy water, leapers, the swirling axe, the warp to Feast Land C - the last Beginner stage |
| 4-1 | Cinder Shaft | Expert: an auto-scrolling descent through lava strata and ember rain |
| 4-2 | Obsidian Keep, Colossus Hall | Expert: a fortress of rising columns and spikes, then boss 2: the Wall Colossus |
| - | Feast Land A, B, C | bonus stages full of food behind the warps of 1-2, 2-1 and 3-2 |
| - | Way Home | the epilogue after the Colossus: the walk home to the village, then The End |

Features: hidden spots to club open everywhere (inset ground, scenery, big spots with giant bonuses, breakable
walls), the bonus word G-R-U-B-S (100 000 points), four weapons that a run keeps from level to level (club, hammer,
axe, swirling axe), checkpoints, secret rooms, level codes for every stage (Continue on the title screen; a stage
started from a code begins with the club), saved progress and high score per mode, and a level select of the
stages reached.

## Controls

| Action | Keyboard | Gamepad | Touch |
|---|---|---|---|
| Walk | Left / Right, A / D | D-pad, left stick | on-screen pad |
| Jump | Z, K (Up / W too while "Up jumps" is on) | A | jump button |
| Strike (hold Up for a high strike) | Space, X, J | X, B | club button |
| Crouch, enter a gate, drop through a hatch | Down, S | D-pad down, stick down | on-screen pad |
| Look ahead | C, L, keypad 5 | Y, RB | look button |
| Pause | Escape, P | Start | pause button |
| Menus | arrows, Enter / Space, Escape | D-pad, A, B | tap |

Keys are bound by their position, so the layout works on every keyboard; the options screen rebinds every game
action for keyboard and gamepad. On Android the back button pauses the game (and goes back in menus). The game
pauses by itself when its window loses focus or the app goes to the background.

## Running the game

1. Install Godot 4.7.2 (standard build, not .NET), or use the copy in `.tools/godot/` if you have it.
2. Open the project folder in the editor once (or run `godot --headless --path . --import`) so the assets are
   imported, then press F5 - or from a terminal:

   ```
   godot --path .
   ```

The user data (settings, save game) lives in `%APPDATA%/ClubAndGrub/` on Windows, `~/Library/Application
Support/ClubAndGrub/` on macOS and the app sandbox on phones.

## Tests and development tools

Everything runs from the project root. In this repository use the serialising wrapper `.tools/gd.sh`, which lets
several tools share the folder (one Godot at a time); with a plain Godot the equivalent command is given in brackets.

| What | Command |
|---|---|
| Import (after a checkout or a new `class_name`) | `bash .tools/gd.sh import` (`godot --headless --path . --import`) |
| All tests | `bash .tools/gd.sh test` (`godot --headless --path . -s res://tests/run_tests.gd`) |
| Tests of one module | `bash .tools/gd.sh test core --verbose` (`... -s res://tests/run_tests.gd -- --filter=core --verbose`) |
| Boot check | `bash .tools/gd.sh smoke 3` (`godot --headless --path . -- --smoke=3`; exit code 0 = clean log) |
| Scripted play + screenshots | `bash .tools/gd.sh play --autoplay=test_example --inputs=40:R,12:RU --shots=10 --fast` |
| Whole game loop, played and checked | `bash .tools/gd.sh play --flow=tools/autoplay/full_loop.flow --fast --fresh-user` |
| The whole Expert campaign, played and checked | `GD_TIMEOUT=1800 bash .tools/gd.sh play --flow=tools/autoplay/campaign.flow --fast --fresh-user` |
| Beginner: level code to the expert wall | `bash .tools/gd.sh play --flow=tools/autoplay/campaign_beginner.flow --fast --fresh-user` |
| Every route proof and both campaign runs, headless | `bash .tools/gd.sh test campaign_routes --verbose` |
| Check level files | `bash .tools/gd.sh script res://tools/validate_levels.gd -- --strict` (or `-- w1_l1 w2_l2`) |
| Render a whole level | `bash .tools/gd.sh script res://tools/world_render_level.gd -- w1_l1 --collision` |
| Robustness (timed transitions, mashing, focus, window sizes) | `bash .tools/gd.sh play --flow=tools/autoplay/robustness.flow --fast --fresh-user --transitions` |

Screenshots land in `build/screenshots/<name>/`; harness runs keep their saves and settings in
`build/autoplay_user/`. Every stage has route proofs in `tools/autoplay/routes/` (input scripts that play it to its
exit, its warp or a secret); `tests/test_campaign_routes.gd` describes and replays all of them and plays both
campaigns in one run. The two integration levels (`levels/test_integration*.lvl`, `kind = test`, linked by `next`)
use every system of the game; `tools/autoplay/full_loop.flow` plays them from the title to the ending. How to build
a level is in [docs/LEVEL_DESIGN.md](docs/LEVEL_DESIGN.md); the architecture, ownership rules and every API are in
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md); the specifications are in `docs/spec/`.

## Building a release

Windows (one self-contained `.exe`):

```
powershell -ExecutionPolicy Bypass -File tools\build_windows.ps1
```

The script imports the project, runs the whole test suite, exports `build/windows/ClubAndGrub.exe` and starts it
for a smoke check; it stops with exit code 1 at the first problem. Every platform, the signing placeholders and
the export templates are described in [docs/BUILD.md](docs/BUILD.md).

## Repository layout

| Path | Content |
|---|---|
| `scripts/`, `scenes/` | game code and scenes, one folder per module (core, player, enemies, objects, world, ui) |
| `levels/` | level files (plain text, format in ARCHITECTURE.md section 7): `w<world>_l<stage>[b].lvl` the campaign, `bonus_*.lvl`, `ending.lvl`; `test_*.lvl` are developer levels (not exported) |
| `assets/` | art, fonts and audio (all third-party, licences in `assets/licenses/`) |
| `tests/` | headless test suite |
| `tools/` | build scripts and level tools (not exported) |
| `docs/` | architecture, specifications, build and porting notes (not exported) |
| `build/` | scratch output: exports, screenshots, test user data (ignored by Godot and git) |

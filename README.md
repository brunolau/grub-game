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
| Robustness (timed transitions, mashing, focus, window sizes) | `bash .tools/gd.sh play --flow=tools/autoplay/robustness.flow --fast --fresh-user --transitions` |

Screenshots land in `build/screenshots/<name>/`; harness runs keep their saves and settings in
`build/autoplay_user/`. Until the campaign levels exist, debug builds play a development campaign of two levels
(`levels/test_integration*.lvl`); the flow scripts in `tools/autoplay/` drive it from the title to the ending. The architecture, ownership rules and every API are in
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
| `levels/` | level files (plain text, format in ARCHITECTURE.md section 7); `test_*.lvl` are developer levels |
| `assets/` | art, fonts and audio (all third-party, licences in `assets/licenses/`) |
| `tests/` | headless test suite |
| `tools/` | build scripts and level tools (not exported) |
| `docs/` | architecture, specifications, build and porting notes (not exported) |
| `build/` | scratch output: exports, screenshots, test user data (ignored by Godot and git) |

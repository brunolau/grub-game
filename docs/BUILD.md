# BUILD.md - building Club & Grub for every platform

Exact steps to produce the release builds. All commands run from the project root. `godot` stands for the Godot
4.7.2 console binary. The engine is not part of the repository: download it (section 1) and unpack it to
`.tools/godot/` (`Godot_v4.7.2-stable_win64_console.exe` on Windows), or point the `GODOT` environment variable at
it. Inside this repository prefer `bash .tools/gd.sh raw <arguments>`, which waits until no other Godot uses the
project; `gd.sh` says how to install the engine when it cannot find it. (`raw` is Godot exactly as called and keeps
the real `APPDATA`, so a raw run of the project writes into `%APPDATA%\ClubAndGrub`, the folder of an installed
game; the `test`, `smoke`, `play`, `script` and `import` commands of `gd.sh` get a folder of their own.)

## 1. Prerequisites (every platform)

1. **Godot 4.7.2 stable, standard build** (not .NET), from https://godotengine.org/download/archive/4.7.2-stable/
   or https://github.com/godotengine/godot/releases/tag/4.7.2-stable. `godot --version` must print
   `4.7.2.stable...`.
2. **Export templates 4.7.2.stable**, unpacked to
   - Windows: `%APPDATA%\Godot\export_templates\4.7.2.stable\`
   - macOS: `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`
   - Linux: `~/.local/share/godot/export_templates/4.7.2.stable/`

   (Editor: *Editor > Manage Export Templates > Download and Install*, or *Install from File* with the `.tpz`.)
3. A clean import and a green test suite:

   ```
   godot --headless --path . --import
   godot --headless --path . -s res://tests/run_tests.gd        # must end with "RESULT: PASS"
   ```

   Godot exits with code 0 even when an export logs errors, so always read the log: a release log has no
   `ERROR:` and no `WARNING:` line (the Windows script below checks this for you), apart from the three "at exit"
   shutdown lines of the first export of a fresh checkout (3.1, step 4).

## 2. The presets (`export_presets.cfg`)

| Preset | Output | Architectures | Signing in the file |
|---|---|---|---|
| `Windows Desktop` | `build/windows/ClubAndGrub.exe` - one file, game data embedded | x86_64 | off (optional Authenticode, 3.3) |
| `macOS` | `build/macos/ClubAndGrub.zip` (`.dmg` possible on a Mac) | universal (arm64 + x86_64) | ad-hoc, distribution type *Testing* |
| `Android` | `build/android/ClubAndGrub.apk` | arm64-v8a, armeabi-v7a | release keystore **placeholders** |
| `iOS` | `build/ios/ClubAndGrub.ipa` (on a Mac; elsewhere an Xcode project) | arm64 | team id **placeholder**, automatic signing |

Every preset exports all resources plus `levels/*.lvl`, `CREDITS.md` and `assets/licenses/*`, and excludes
`tests/*`, `tools/*`, `docs/*`, `build/*`, the developer levels `levels/test_*.lvl` and their baked bot graphs
`resources/bots/test_*.json`, the debug level (`scenes/core/debug_level.tscn`, `scripts/core/debug_level.gd`),
every folder named `dev` (`*/dev/*`: the flow runner, the input recorder, the perf probe, the benches, the UI
previews), the font tool `resources/ui/*.py`, and two development tools that live beside game code and that no
shipped script names: the level validator and the co-op gate search (`scripts/world/level_validator.gd`,
`scripts/world/coop_search.gd`). The four presets carry the same three filter lines.

Two test files keep this true:

- `tests/test_core_release.gd` - the filters are present and equal on all four presets, the version, the icons,
  the installer's test mode;
- `tests/test_core_release_pack.gd` - works out, from the project folder, the file list each preset ships (the way
  the exporter does: all resources plus the include filter minus the exclude filter) and judges every file: no
  developer level (by name `test_*` or by `kind = test`), no test, tool or recorder, nothing outside `assets/`,
  `scripts/`, `scenes/`, `levels/`, `locale/`, `resources/` and the two root files, every asset named in
  `docs/ASSET_MANIFEST.md`, no shipped script naming a tool that is left out. When the environment variable
  `CLUBANDGRUB_RELEASE_EXE` names an exported exe (the Windows build script sets it), the same test reads the file
  table of the pack embedded in that exe and compares it with the list: nothing more, nothing less.

To see exactly what a preset ships, export only the data and list the zip:

```
godot --headless --path . --export-pack "Android" build/export_check/Android.zip
```

Shared identity: application id `com.clubandgrub.game` (macOS, iOS, Android), name "Club & Grub", version from
`application/config/version` in `project.godot` (2.0.0; the Windows exe reports 2.0.0.0 - the presets leave their
own version fields empty so that this one value is the version everywhere: the title screen, the exe, the zip and
the installer take it from there, and `tests/test_core_release.gd` pins it). The Android `version/code` is 2. The icon is
`res://assets/icon.png` (256 x 256); Godot derives the `.ico`, `.icns` and the legacy Android launcher icon from it.
The iOS store icon (`assets/icon_1024.png`) and the Android adaptive layers (`assets/icon_android_*.png`) are
built from the hero sheet by `tools/make_app_icons.py` (run it again after the hero art changes).

### 2.1 The headless preset check (Android, macOS, iOS)

2.0.0 ships for Windows; the other three presets must stay loadable (docs/PORTING.md). The check needs no SDK, no
Mac and no signing - a data-only export loads the preset, applies its filters and writes the pack:

```
godot --headless --path . --export-pack "Android" build/export_check/android.zip
godot --headless --path . --export-pack "macOS"   build/export_check/macos.zip
godot --headless --path . --export-pack "iOS"     build/export_check/ios.zip
```

Each must exit with code 0, print no `ERROR:` line about the preset, and leave `export_presets.cfg` unchanged
(`git diff --stat export_presets.cfg` is empty). The three zips must list the same project files as the Windows
build (compare the names; converted files carry platform-independent names). The results for 2.0.0 are in
docs/PORTING.md ("State of 2.0.0"). A full export of these platforms was not made for
2.0.0: their toolchains are not part of the project (sections 4 to 6 say what each needs).

### Placeholders to replace before a store release

| Preset | Option | Value in the file | Replace with |
|---|---|---|---|
| Android | `keystore/release` | `PLACEHOLDER_RELEASE_KEYSTORE_PATH` | path of the upload keystore, or env `GODOT_ANDROID_KEYSTORE_RELEASE_PATH` |
| Android | `keystore/release_user` | `PLACEHOLDER_RELEASE_KEY_ALIAS` | key alias, or env `GODOT_ANDROID_KEYSTORE_RELEASE_USER` |
| Android | `keystore/release_password` | empty - **never commit it** | env `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` |
| iOS | `application/app_store_team_id` | `PLACEHOLDER_APPLE_TEAM_ID` | the 10-character Apple team id |
| macOS | `codesign/apple_team_id` | `PLACEHOLDER_APPLE_TEAM_ID` | the same team id (Developer ID signing) |
| macOS | `codesign/identity` | empty | `Developer ID Application: <Name> (<TEAMID>)` (3.2) |
| all | application id | `com.clubandgrub.game` | keep it if the publisher owns it; otherwise change it in all three presets and in `tests/test_core_release.gd` |
| Windows | `application/company_name`, `application/copyright` | `Club & Grub Team` | the publisher's legal name |

Environment variables always win over the file, so CI machines and release managers keep secrets out of the
repository. When a secret is typed into the editor's export dialog, Godot stores it in
`.godot/export_credentials.cfg`, which is never committed (`.gitignore`). With the placeholders in place an
Android release export fails on purpose ("Release keystore incorrectly configured").

## 3. Windows

### 3.1 One command

```
powershell -ExecutionPolicy Bypass -File tools\build_windows.ps1
```

The script

1. checks the Godot version and the template `windows_release_x86_64.exe`;
2. imports the project and stops on any import error or warning;
2b. runs the asset and licence audit `tools\audit_assets.py` (Python 3, standard library only: the project's
   `.tools\venv` or `python` on the PATH; it installs nothing) and stops on any asset without a row in
   `docs/ASSET_MANIFEST.md`, any licence that is not CC0 / OFL, any pack missing from the credits or the licence
   texts;
3. runs the whole test suite and stops unless it reports `RESULT: PASS`;
4. exports the `Windows Desktop` preset in release mode to `build\windows\ClubAndGrub.exe`, stops on any `ERROR:` /
   `WARNING:` in the export log and checks that the exe is the only file written (no `.pck`, no DLL), that it
   reports the version of `project.godot`, and that the export left `export_presets.cfg` as it was (if the editor
   rewrote it, the file is put back and the build stops). Three lines are let through: the first export of a
   fresh checkout converts every scene to binary (`.godot/exported/`) and the editor then reports
   `WARNING: <n> ObjectDB instances were leaked at exit`, `ERROR: <n> resources still in use at exit` and (the
   headless renderer, for the textures those resources held)
   `ERROR: <n> RID allocations of type '...DummyTexture...' were leaked at exit` while it shuts down, after the pack
   is written; later exports reuse the converted scenes and print none of them. The script lists them as "ignored
   editor shutdown report" (the third line was added at the 2.0.0 release check: a clean copy of the repository
   stopped on it at its first build and passed at its second);
5. starts the exe for a smoke check (below) and stops unless it exits with code 0, its log is clean and it reports
   the version of `project.godot`. "Clean" is read from the log itself, not taken from the game: the script stops on
   every `WARNING:` and `ERROR:` line of the boot log (none is tolerated: `$BootLogTolerated` is empty), also one
   the game's own count did not see, and on a log without the game's `0 error(s), 0 warning(s)` verdict;
6. reads the file table of the pack inside the exe and lets `tests/test_core_release_pack.gd` judge it (section 2):
   no developer level, test, tool or recorder, every asset in the manifest, exactly the files the filters ship.
   The script prints the test's `pack:` line, for example
   `pack: 2591 file(s) inside ClubAndGrub.exe (engine 4.7.2): 1368 project files, 78 levels, ...`;
7. copies the licence texts next to the exe (`build\windows\licenses\`: `CREDITS.md` and every file of
   `assets\licenses\` - the Godot MIT notice and third-party notices, both OFL font licences with the FONTLOG, the
   CC0 legal code and the per-pack evidence; the game shows the same texts under Credits > Licences), packs the
   release zip `build\ClubAndGrub-<version>-windows.zip` (the exe plus that folder) and lets
   `tools\audit_assets.py --shipped` compare the folder and the zip with the project's licence texts, byte for byte;
8. prints the SHA-256 of the exe and of the zip and exits with 0. Any failure prints `BUILD FAILED: ...` and exits
   with 1.

Options: `-Godot <path>` (else `$env:GODOT`, else `.tools\godot\...`, else `godot` on the PATH), `-SmokeSeconds <n>`
(default 4), `-HeadlessSmoke` (build machines without a GPU), `-SkipTests` (packaging experiments only - never
ship such a build), `-OutputRoot <folder>` (default `build`: the exe goes to `<folder>\windows`, the zip to
`<folder>`; use another folder, for example `build\trial`, to try the script without replacing the release files),
`-CheckBootLog <file>` (builds nothing: judges an existing boot log by the rule of step 5, prints the lines that
fail it and `BOOT LOG OK` / `BOOT LOG FAILED`, exit code 0 / 1).
Logs: `build\windows\logs\` (import, audit, tests, export, pack check) and `build\windows\smoke\smoke.log`.

The script shares the project with other Godot runs through `build\.godot_lock`, as `.tools/gd.sh` does: the
import and the export run alone, the tests run beside other test runs.

**No run of the script writes into the player's own folder.** The game's `user://` is `%APPDATA%\ClubAndGrub`, where
an installed game keeps its saves and settings, and a Godot run of the project goes there by itself: a test run
rotates the engine's log into `logs\` and writes what a test puts into `user://`, and the editor (import, export)
makes the folder and `objectdb_snapshots\` in it when they are missing. So every Godot run of the script - the
version check, the import, both test runs and the export - is started with `APPDATA` pointed at the build's own
folder `build\run_users\build_windows_<PID>\appdata` (removed when the script ends, also when it fails), like the
runs of `.tools/gd.sh`; the exported game's smoke check has its own (3.2). The editor looks for the export
templates under `APPDATA`, so before the export the script copies `windows_release_x86_64.exe` (with its console
twin and `version.txt`) from the real `%APPDATA%\Godot\export_templates\4.7.2.stable\` into that folder - about
110 MB, read only. Measured for 2.0.0: an export made that way, with fresh editor settings and nothing but those
three files, is byte for byte the exe exported with the real `APPDATA`; and the files of the real
`%APPDATA%\ClubAndGrub` have the same times and sizes before and after a whole run of the script.
`tests/test_core_boot_check.gd` keeps the rule in the script (every start of the Godot binary carries the build's
`APPDATA`).

### 3.2 The smoke check of a release build

Release builds act on no development command-line switch (`--autoplay`, `--inputs`, `--shots`, ... need a debug
build). The one switch they honour is the boot check:

```
build\windows\ClubAndGrub.exe --log-file build\windows\smoke\smoke.log -- --smoke=3
```

It runs the game normally for 3 s (0.1 .. 120), then quits through the normal shutdown, with exit code 0 only when
nothing logged an error or a warning. In an exported build it also logs an error for every development file it
finds inside the package. The log ends with lines such as

```
Smoke: Club & Grub 2.0.0 (release build), 78 level(s), screen 'title'
Smoke: levels arena_cinder_pit,arena_coconut_cove,...,bonus_a,bonus_a_coop,...,w9_l3,w9_l3_coop
Smoke: campaign beginner w1_l1,w1_l2,w2_l1,w2_l2,w3_l1,w3_l2; expert w1_l1,w1_l2,w2_l1,w2_l2,w3_l1,w3_l2,w4_l1,w4_l2
Smoke: counted since the autoloads were made, before Settings and Save loaded (no log file of this run at the project's log path: read the log's lines too)
Smoke: ran 3.0 s, 0 error(s), 0 warning(s) logged
```

**What the boot check counts.** Its counter is attached when the engine makes the game's autoloads - before the
first of them is ready, so before `Settings` reads `settings.cfg` and `Save` reads `save.json`: a damaged save or
an unreadable settings file is a counted warning and the exit code is 1 (until the 2.0.0 release round the counter
was attached after both had loaded, and such a boot ended `0 error(s), 0 warning(s)` with exit code 0). What the
engine logs before any script runs is read from the engine's own log, from its first line, when the game can find
that log: the project's default `user://logs/godot.log` - the line then reads `Smoke: counted from the first line
of the engine's log (...)` and the game takes the larger of the two counts. A run started with `--log-file`, as
above, writes its log where the game cannot know, and nothing in the game sees what the engine logs after the
verdict, while it shuts down. So **whoever trusts a boot check also reads the lines of its log**: both build
scripts do (`tools\build_windows.ps1` step 5 and the installer's twin, by one rule;
`tools\build_windows.ps1 -CheckBootLog <file>` applies it to any log). `tests/test_core_boot_check.gd` boots the
project on an empty folder, on a cut-off `save.json` and on an unreadable `settings.cfg` beside it, and runs both
scripts on the logs of `tests/data/boot_logs/`.

The script runs the exe with `APPDATA` pointed at `build\windows\smoke\appdata`, so the check never reads or writes
the settings and saves of a real installation, and it adds `--autoplay=w1_l1`, which the log must report as
ignored. It also compares the `Smoke: levels` line with the folder: the build must hold every `levels\*.lvl` except
the developer levels `test_*.lvl`, and none of those (78 files in 2.0.0: 35 solo stages, 35 co-op versions, 8 arenas;
the `Smoke: campaign` line names the map stops of Book I), and the first line must carry the project's version. The exe is a GUI program: it opens no console, so read the log
file, not the terminal.

### 3.3 Manual export and optional code signing

```
godot --headless --path . --export-release "Windows Desktop" build/windows/ClubAndGrub.exe
```

Unsigned executables trigger SmartScreen warnings. To sign with Authenticode: install the Windows SDK, set the
editor setting *Export > Windows > Signtool* to `signtool.exe`, set `codesign/enable=true` in the preset and provide
the certificate through `GODOT_WINDOWS_CODESIGN_IDENTITY` (path of the `.pfx` or the certificate's SHA-1),
`GODOT_WINDOWS_CODESIGN_IDENTITY_TYPE` (0 = select automatically, 1 = PKCS#12 file, 2 = certificate store) and
`GODOT_WINDOWS_CODESIGN_PASSWORD`.

Graphics: the build uses the Compatibility renderer on OpenGL 3.3. ANGLE (OpenGL ES on Direct3D, for very old or
broken GPU drivers) is not shipped, because it needs two DLLs next to the exe; set `application/export_angle=1` if
that fallback matters more than a single file.

### 3.4 Installer

`installer/club_and_grub.iss` packs `build\windows` (the exe and `licenses\`) into
`build\ClubAndGrub-<version>-setup.exe` with [Inno Setup 7](https://jrsoftware.org/isinfo.php) (free, also for
commercial use). It is not part of the repository; install it once, portable inside the project (no registry
entries, no Start menu):

```
curl.exe -L -o is.exe https://github.com/jrsoftware/issrc/releases/download/is-7_1_0/innosetup-7.1.0-x64.exe
.\is.exe /VERYSILENT /PORTABLE=1 /CURRENTUSER /NOICONS /DIR="%CD%\.tools\innosetup"
```

Then:

```
powershell -ExecutionPolicy Bypass -File tools\build_installer.ps1 -TestInstall
```

The script runs `tools\build_windows.ps1` first (`-SkipBuild` packs the existing export), takes the version from
`project.godot`, checks that the exe carries that version and compiles the installer. It stops with exit code 1 at
the first problem. `-OutputRoot <folder>` works as for the Windows script (the export is read from
`<folder>\windows`, the installer is written to `<folder>`).

The compiler writes the setup file into a folder of its own under `%TEMP%` and the script moves the finished file
to the output folder. Inno Setup's first step writes the icon and version resources into the new file, and that
fails with `Resource update error: EndUpdateResource failed, try excluding the Output folder from your antivirus
software (110)` when another program opens the file at that moment; on the development machine it failed for every
output folder inside the project and never under `%TEMP%`. The script also compiles again (up to three times) when
it sees that one error.

**`-TestInstall` is safe on a machine where the game is installed.** It never runs the release installer. It
compiles the same script a second time in its test mode (`/DTestAppId=<a new GUID>`): a throwaway twin that is
another application for Windows - its own AppId, the name "Club & Grub installer test xxxxxxxx", its own Start menu
group and uninstall entry, no desktop shortcut, no "close the running game", and none of the code that offers to
delete saved games. The twin is installed silently for the current user into `<folder>\installer_test\app`, its
files, uninstall entry and Start menu shortcut are checked, the installed game runs its smoke check with its own
`APPDATA` and must report the version - its boot log is judged by the rule of the Windows script (exit code 0, no
`WARNING:` or `ERROR:` line, the game's clean verdict; `tools\build_installer.ps1 -CheckBootLog <file>` applies it
to any log) - then the twin is uninstalled through its own uninstaller and the script
checks that no file, no uninstall entry and no Start menu folder of it is left. A failed check still uninstalls
the twin; a run that was killed leaves a record (`installer_test\test_install.json`) and the next run removes that
twin first. The file `...-setup-TEST-ONLY.exe` is deleted after a good run; never publish one.

The script proves on every run that the real game was not touched: before the test it records the uninstall
entries of the real AppId (this user and all users), every installed file, the Start menu folders, the desktop
shortcuts and the save and settings files in `%APPDATA%\ClubAndGrub` with their hashes, and compares after it.
Any difference fails the run and is listed. (Playing the game during the test changes the save files and is
reported as such a difference - run the test again without playing.) The script itself never writes to the
registry and uninstalls only the copy whose uninstall entry carries its own throwaway AppId and points into its
own test folder.

What the installer does: per-user install into `%LOCALAPPDATA%\Programs\Club & Grub` by default (no administrator
rights; the first page offers an all-users install into Program Files), Start menu entries for the game, the licence
folder and the uninstaller, an optional desktop shortcut, an entry under *Settings > Apps*, upgrades in place (fixed
`AppId` - never change it) and closes a running game before replacing it. Uninstalling keeps `%APPDATA%\ClubAndGrub`
(saves and settings) unless the player answers yes to the question at the end. Silent installs:
`ClubAndGrub-<version>-setup.exe /VERYSILENT /CURRENTUSER` (add `/MERGETASKS=desktopicon` for the desktop shortcut).

**Upgrading 1.0.0 to 2.0.0**: the 2.0.0 installer has the AppId of 1.0.0, so it replaces the installed game in its
folder and keeps one entry under *Settings > Apps*. It does not touch `%APPDATA%\ClubAndGrub`. The game itself
reads the 1.0 save (section 3.5).

### 3.5 Saves and settings of 1.0.0 in 2.0.0

- `save.json` is version 2 in 2.0 (progress per mode, book and difficulty; ARCHITECTURE.md 3.6). A version 1 file
  is migrated when it is read: its progress becomes Solo > Book I. Reading writes nothing. The first save after it
  first copies the 1.0 file, byte for byte, to `save.v1.json` beside it and reads the copy back; only then is
  `save.json` replaced, and if the copy cannot be made nothing is written. The game never changes `save.v1.json`
  (a second, different 1.0 file would become `save.v1.2.json`).
- `settings.cfg` keeps its version (1) and format: options and key bindings of 1.0.0 are read as they are, and the
  file 2.0 writes still reads in 1.0.0. New keys: `controls/party_keyboard`, `coop/rival_score`,
  `coop/helper_mode`, `versus/last_rules`, and the per-player binding sections `[bindings_p1]`..`[bindings_p4]`.
- Going back: 1.0.0 does not read a version 2 save (it warns and shows no progress). If it is played anyway it
  writes a version 1 file that still carries the 2.0 data; 2.0 merges both when it reads that file. To restore the
  old state exactly, put `save.v1.json` back as `save.json`.
- A file that cannot be read is kept, and a good backup is never thrown away for it. A `save.json` (or
  `save.json.bak`) that is there and holds no save - garbage, a write that was cut off, an empty or zero-filled
  file, JSON that is no object - is named in a warning; the game plays on with `save.json.bak`, and reading still
  writes nothing. The first save after it writes the new file and reads it back, then sets the unreadable file
  aside, byte for byte, as `save.bad.json` (`save.bad.2.json` ... when that name holds other bytes) instead of
  making it the backup: the readable `save.json.bak` stays where it is until the save after that one. Beside a 1.0
  backup the copy `save.v1.json` is still made first. An unreadable `settings.cfg` (a parse error, or bytes without
  any section) is set aside the same way as `settings.bad.cfg` before the defaults replace it. While a file cannot
  be set aside nothing is written over it. The game never reads the `.bad` files again; they are for a person to
  look at, and may be deleted.
- Proof: `bash .tools/gd.sh test core_save` - `tests/test_core_save_1_0.gd` loads real profiles written by the
  1.0.0 release (`tests/data/saves_1_0/`: a fresh one, mid Book I on both difficulties with a level code, changed
  options and rebound keys, a finished game, and a 2.0 profile that 1.0.0 then played) and checks every unlocked
  stage, result, completion flag, code stone, high score, option and binding, the 20 level codes, and that no 2.0
  save is written before the copy exists; `tests/test_core_save_damage.gd` puts five kinds of an unreadable
  `save.json` (garbage, half-written, empty, the wrong JSON type, zero-filled) beside a good backup - a 2.0 one and
  the `save.json.bak` of three of those 1.0 profiles - and checks after the first save that nothing of the backup is
  missing from the new file and that the backup, the copy `save.v1.json` and the file set aside are all there, byte
  for byte; the same for four kinds of an unreadable `settings.cfg`.

### 3.6 Two players on one PC (what a tester needs to know)

Co-op (two players) and versus (two to four) share one computer. Default keys: P1 W A S D, Space jump, Left Ctrl
strike, E swap, Q look; P2 numpad 8 4 5 6, Num 0 jump, Num Enter strike, Num + swap, Num . look - bound by physical
key (any keyboard layout, Num Lock on or off). Two more layouts exist for keyboards without a numpad; every key
can be rebound per player. A keyboard seats two players; further players use gamepads, one per player (A jump, X /
B strike, Y / RB look, LB swap, Start pause). Many keyboards cannot report every combination of six or more keys:
the join screen's key test shows it, and a gamepad or another layout is the cure. What a person must check on real
keyboards and pads is listed in `docs/expansion/HUMAN_CHECKS.md`.

The installer art (`installer/*.png`, `installer/club_and_grub.ico`) is generated from the game's sprites by
`tools/make_installer_art.py`. To sign the installer as well, add a `SignTool` entry to the `[Setup]` section (see
the Inno Setup help) with the same certificate as the exe.

## 4. macOS

**Bundle name (Godot 4.7.2 workaround, applied):** the macOS export writes the executable name into `Info.plist`
without escaping it, and the project name contains `&`, which would make the bundle's `Info.plist` invalid XML.
`project.godot` therefore sets `config/name.macos="Club and Grub"` in `[application]`: the bundle is
`Club and Grub.app` with a valid `Info.plist`. Keep that override until the engine escapes the name.

### 4.1 Test build (any host)

```
godot --headless --path . --export-release "macOS" build/macos/ClubAndGrub.zip
```

The zip holds the universal `.app`, signed ad-hoc (built-in signer). On a Mac: unzip, then right-click the app >
*Open* (or `xattr -dr com.apple.quarantine "Club and Grub.app"`) the first time, because the build is neither
Developer-ID signed nor notarized.

### 4.2 Distribution build (Developer ID, outside the App Store)

1. Apple Developer Program membership; a *Developer ID Application* certificate in the keychain (Mac) or as a
   `.p12` file (any host).
2. In the preset: `export/distribution_type` = *Distribution*, `codesign/apple_team_id` = your team id,
   `codesign/identity` = `Developer ID Application: <Name> (<TEAMID>)`.
3. Signing: on a Mac choose *Xcode codesign*; on other hosts *rcodesign* (install `rcodesign` and set its path in
   the editor settings) with `GODOT_MACOS_CODESIGN_CERTIFICATE_FILE` / `GODOT_MACOS_CODESIGN_CERTIFICATE_PASSWORD`.
4. Notarization: *Xcode notarytool* (Mac) or *rcodesign* with an App Store Connect API key:
   `GODOT_MACOS_NOTARIZATION_API_UUID` (issuer id), `GODOT_MACOS_NOTARIZATION_API_KEY` (path of the `.p8`),
   `GODOT_MACOS_NOTARIZATION_API_KEY_ID`. (Apple-id notarization: `GODOT_MACOS_NOTARIZATION_APPLE_ID_NAME` /
   `..._PASSWORD`, an app-specific password.)
5. Export (`.dmg` needs a Mac; `.zip` works everywhere), then staple: `xcrun stapler staple "Club and Grub.app"`.

The Mac App Store additionally needs `codesign/entitlements/app_sandbox/enabled=true`, an installer identity, a
provisioning profile (`GODOT_MACOS_CODESIGN_PROVISIONING_PROFILE`) and distribution type *App Store* (Mac only).

## 5. Android

### 5.1 One-time setup

1. JDK 17 and the Android SDK with `platform-tools`, `build-tools;36.0.0` (any 35+ works; Godot falls back to the
   newest installed and says so) and `platforms;android-36`:

   ```
   sdkmanager "platform-tools" "build-tools;36.0.0" "platforms;android-36" "cmdline-tools;latest"
   ```

2. Editor settings (*Editor > Editor Settings > Export > Android*): `Java SDK Path`, `Android SDK Path`. Godot
   creates the debug keystore itself.
3. An **upload keystore** for release builds, kept outside the repository and backed up:

   ```
   keytool -genkeypair -v -keystore clubandgrub-upload.jks -alias clubandgrub -keyalg RSA -keysize 4096 -validity 10000
   ```

### 5.2 Release APK (sideloading, testing)

```
set GODOT_ANDROID_KEYSTORE_RELEASE_PATH=C:\keys\clubandgrub-upload.jks
set GODOT_ANDROID_KEYSTORE_RELEASE_USER=clubandgrub
set GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=<password>
godot --headless --path . --export-release "Android" build/android/ClubAndGrub.apk
adb install -r build/android/ClubAndGrub.apk
```

Verified on the development machine with a throwaway keystore: the preset produces a signed APK with
`lib/arm64-v8a` and `lib/armeabi-v7a`, package `com.clubandgrub.game`, min SDK 24, target SDK 36, landscape
(`userLandscape`), `isGame`, backup allowed, and exactly one permission (`VIBRATE`, for `GameInput.vibrate`).

### 5.3 Google Play (AAB)

Google Play needs an Android App Bundle, which Godot builds with Gradle from the Android build template:

1. `godot --headless --path . --install-android-build-template --export-release "Android" build/android/ClubAndGrub.apk`
   once per build machine; this creates the Gradle project in `android/build/` (ignored by git - commit it only if
   the team decides to customise it).
2. In the preset set `gradle_build/use_gradle_build=true` and `gradle_build/export_format=1` (AAB).
3. `godot --headless --path . --export-release "Android" build/android/ClubAndGrub.aab`.
4. Raise `version/code` in the preset for every upload (Play rejects a code it has seen).

Enrol in Play App Signing; the keystore above is then only the upload key.

## 6. iOS

1. A Mac with Xcode 16 or newer, an Apple Developer Program membership, the bundle id `com.clubandgrub.game`
   registered under *Certificates, Identifiers & Profiles*, and an app record in App Store Connect.
2. Replace `PLACEHOLDER_APPLE_TEAM_ID` (`application/app_store_team_id`). Signing is automatic; for manual signing
   set `GODOT_APPLE_PLATFORM_PROVISIONING_PROFILE_UUID_RELEASE` (or `..._SPECIFIER_RELEASE`).
3. Export on the Mac:

   ```
   godot --headless --path . --export-release "iOS" build/ios/ClubAndGrub.ipa
   ```

   Godot writes the Xcode project and runs `xcodebuild` to archive and export the `.ipa` (method *App Store*). On
   Windows or Linux the same command stops after writing the Xcode project (warning "`.ipa` can only be built on
   macOS"); copy `build/ios/` to a Mac and use *Product > Archive* in Xcode.
4. Upload with Xcode's Organizer or Transporter; test through TestFlight.

The preset already declares landscape only, full screen, hidden status bar, iPhone and iPad, iOS 15+, no camera,
no file sharing, and `ITSAppUsesNonExemptEncryption = false` (no export-compliance question per upload).

## 7. Release checklist

1. `application/config/version` raised in `project.godot` (2.0.0); Android `version/code` raised (2); the fallback
   version in `installer/club_and_grub.iss` and `VERSION` in `tests/test_core_release.gd` follow; `CHANGELOG.md` has
   the version and the release notes exist (`docs/RELEASE_NOTES_2.0.md`).
2. Import clean, `tests/run_tests.gd` green, level validator green. After any change to a simulation script or a
   co-op level also: `bash tools/sp_identity.sh` (`IDENTICAL`), `bash tools/world_coop_gates.sh`, and before the
   release the whole table `bash tools/g3.sh --require` (it must print `REACHED`; about 70 minutes, alone on the
   machine). After any change to the versus referee, a mode, an arena file or the bots also the soak, which is no
   job of that table: `bash tools/bots/soak.sh p4 1000 16` and `bash tools/bots/soak.sh mix 250 16 rules=mix` (each
   ends `RESULT PASS`; about 6 and 2 minutes) and, for an arena whose file changed, its 384-round fairness claims
   (`bash tools/bots/fair.sh <tag> <arena> <mode> 0 96`, DESIGN.md G80). `python tools/audit_assets.py` and
   `python -m unittest discover -s docs/spec -p "test_*.py"` are green. Performance is measured with
   `bash tools/perf.sh` on a quiet machine when the simulation's cost may have moved (ARCHITECTURE.md 11.5 holds
   the numbers of 2.0.0; no release gate).
3. Windows: `tools\build_windows.ps1` ends with `BUILD OK`, then `tools\build_installer.ps1 -SkipBuild -TestInstall`
   ends with `INSTALLER OK` (safe on a machine where the game is installed, 3.4). Publish the setup exe and the zip
   together as GitHub release `v<version>`, with the text at the end of the release notes and the two SHA-256
   values of the build log. Publishing is the owner's decision; no build script commits, tags or uploads.
4. Other platforms: export, install on the devices of `docs/PORTING.md` section 5, run the device checklist.
5. `CREDITS.md` and `assets/licenses/` are inside the package (they are, through the include filter) and readable
   in the game (Credits > Licences); the Windows release zip also carries them as files in `licenses/` next to the
   exe (`tools/build_windows.ps1` step 6). Distribute the zip, never the bare exe. After an asset rebuild
   (`docs/art/pipeline/build_all.py`) the hand-maintained `CREDITS.md`, `assets/licenses/README.md` and
   `godot_*.txt` are kept, and the pipeline fails if a pack is missing from them (docs/THIRD_PARTY.md).
6. Archive the exact build: the exe / apk / aab / ipa, its SHA-256, and the commit it was built from.

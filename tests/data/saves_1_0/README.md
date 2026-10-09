# Real Club & Grub 1.0.0 profiles

Each folder here is the user folder (`%APPDATA%\ClubAndGrub`) that the **1.0.0 release** (git tag `v1.0.0`, commit
`0b83519`) wrote when it was played from an empty folder by its own flow runner. Nothing was edited by hand; the
files are byte for byte what 1.0.0 stored (all of them use LF line ends, so git keeps them exact).
`tests/test_core_save_1_0.gd` loads every profile with 2.0 and checks that nothing is lost and that the 1.0 file
is never written over before an untouched copy of it exists (`save.v1.json`).

| Profile | The player | Files |
|---|---|---|
| `fresh` | started a Beginner run, walked a few steps into 1-1, quit through the pause menu | `settings.cfg` only: 1.0.0 writes no save before a stage is cleared |
| `expert_start` | only ever played Expert: cleared 1-1, changed no option | `save.json`, `settings.cfg` (last difficulty Expert, no `[bindings]`) |
| `mid_beginner` | Beginner, mid Book I: cleared 1-1 and 1-2, typed the level code of 3-1 (`SN0W`), then Options: music 0.5, effects 0.9, screen shake off, flashes off, "Up jumps" off; jump rebound to **V**, look rebound to **pad LB** (two inputs 2.0 gives its new action `swap`) | `save.json`, `save.json.bak`, `settings.cfg` |
| `mid_expert` | progress in both difficulties: Expert 1-1, 1-2 (through the warp and Feast Land A), 2-1; then Beginner 1-1; Options: master 0.8, smooth camera on, vibration off; strike rebound to **H**, jump to **Space** | `save.json`, `save.json.bak`, `settings.cfg` |
| `finished` | finished the game: the whole Expert campaign to The End and the credits, then a Beginner run from the code `GR0T` to the expert wall | `save.json`, `save.json.bak`, `settings.cfg` |

One more folder is the way back: **`downgraded`** is the `mid_expert` profile after 2.0 had migrated it and added
2.0 progress (Cave Painting 3, the co-op unlock of 5-2, a Book II result) and after the 1.0.0 release then played
on that 2.0 profile (`flows/expert_start.flow`, default settings, no `--fresh-user`). 1.0.0 warned "file version 2
is newer than this build", showed no progress, cleared 1-1 on Expert and wrote `save.json` as version 1 with the
2.0 keys still inside; `save.json.bak` is the 2.0 file it replaced, `save.v1.json` the copy 2.0 had made of the
first 1.0 file. 2.0 must merge it: nothing of either version is lost.

`flows/<profile>.flow` is the script that played each one (the 1.0.0 flow language, `scripts/core/dev/autoplay_flow.gd`
of that tag); `finished.flow` is 1.0.0's own `tools/autoplay/campaign.flow` followed by its `campaign_beginner.flow`.
`level_codes.txt` lists the 20 level codes of the 15 stages of 1.0.0.

## Making them again

The game's own tools are used, on a private checkout of the release, with its own `APPDATA` so that not even the
engine's log touches a real installation; windows are muted and off-screen:

```
git worktree add --detach build/release_prep/v1_0_0 v1.0.0
G=.tools/godot/Godot_v4.7.2-stable_win64_console.exe
W=build/release_prep/v1_0_0
"$G" --headless --path $W --import
mkdir -p $W/build/rp && cp tests/data/saves_1_0/flows/*.flow $W/build/rp/
export APPDATA="$PWD/build/release_prep/appdata_1_0"; mkdir -p "$APPDATA"
for n in fresh expert_start mid_beginner mid_expert finished; do
  "$G" --path $W --audio-driver Dummy --position 30000,30000 --disable-vsync -- \
      --flow=build/rp/$n.flow --fast --fresh-user --user-dir=res://build/rp_users/$n --out=rp_$n
done      # each must end with "Autoplay flow: RESULT PASS"; finished.flow takes about 15 minutes
# the profiles are then in build/release_prep/v1_0_0/build/rp_users/<profile>/
git worktree remove --force build/release_prep/v1_0_0
```

The runs are deterministic (the routes are replayed tick for tick), so a new run gives the same files: `finished`
was played twice on 2026-10-09 and the three files of the second run were byte-identical to the first.

`downgraded` needs 2.0 in between: copy `mid_expert/*` to a folder, let 2.0 load it there and add its own progress
(`Save.set_storage_dir(<folder>)`, `Save.add_painting(3)`, `Save.unlock_level_in("coop/book2/expert", &"w5_l2")`,
`Save.record_level_result_in("single/book2/beginner", &"w5_l1", 77000, 66)`, `Save.save_game()` - a five-line
`-s` script through `bash .tools/gd.sh script`), copy `save.json`, `save.json.bak` and `save.v1.json` of that folder
(not its `settings.cfg`: the smooth camera of `mid_expert` changes what the route meets) to
`build/release_prep/v1_0_0/build/rp_users/down/`, and run the 1.0.0 line above with `expert_start.flow`,
`--user-dir=res://build/rp_users/down` and without `--fresh-user`.

The older pair `tests/fixtures/save_v1/campaign_*.json` (phase 0) holds save files only; these folders add the
settings, the backups and the mid-game states.

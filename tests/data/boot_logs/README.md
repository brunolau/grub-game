# Boot logs for the boot check's tests

The log files (`--log-file`) of boot checks (`-- --smoke=<seconds>`), for `tests/test_core_boot_check.gd`: the
line counter of the game (`Autoplay.count_log_problems`) and the rule of the two build scripts
(`tools\build_windows.ps1 -CheckBootLog <file>`, `tools\build_installer.ps1 -CheckBootLog <file>`) are run on
each of them. They are `.txt` files so that Godot imports nothing and git keeps them.

| File | What it is | The game's count | The build scripts |
|---|---|---|---|
| `clean.txt` | a real log: the project booted on an empty user folder | 0 errors, 0 warnings | pass |
| `damaged_settings_and_save.txt` | a real log: the same boot on a folder with an unreadable `settings.cfg` and a cut-off `save.json` - what Settings and Save log while they load | 1 error, 2 warnings | fail |
| `warning_before_the_first_script.txt` | `clean.txt` with one planted `WARNING:` line after the engine's header: the engine warned while it started, before any script of the game ran. The game printed a clean verdict | 0 errors, 1 warning | fail (the line) |
| `error_after_the_verdict.txt` | `clean.txt` with one planted `ERROR:` line after the game's verdict: the engine reported a leak while it shut down | 1 error, 0 warnings | fail (the line) |
| `no_verdict.txt` | `clean.txt` without its last line: the game never printed its verdict | 0 errors, 0 warnings | fail (no clean run reported) |

The two real logs were written by

```
godot --headless --path . --log-file <file> -- --smoke=0.2
```

with `APPDATA` pointed at an empty folder and at a folder holding the two damaged files (the bytes
`00 ff "[[[ not a config \n=== " 01 02` as `settings.cfg`, `{ "version": 2, "spaces": { "single/book1/beg` as
`save.json`). The planted lines say `PLANTED FOR THE TEST`. The line numbers in the backtraces are those of the day
the logs were made.

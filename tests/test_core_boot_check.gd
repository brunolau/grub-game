extends TestCase
## The boot check sees the boot (`-- --smoke=<seconds>`, scripts/core/autoplay.gd), and the build scripts that trust
## it read the lines of its log as well (tools/build_windows.ps1, tools/build_installer.ps1).
##
## The release verifier's finding (build/engine_requests/wf12_p4_verify_to_orchestrator.txt, 3c): the counter was
## attached in the tenth autoload's _ready, after Settings and Save had loaded; a boot on a damaged save or an
## unreadable settings file logged its warnings and still ended "0 error(s), 0 warning(s) logged" with exit code 0,
## and the installer's twin check trusted that line and the exit code alone.
##
## The boots below are real ones: this test starts the engine again on the project (headless, a fifth of a second)
## with the user folder of each case - APPDATA on Windows, XDG_DATA_HOME on Linux - inside the test run's own folder.

const LOG_DIR: String = "res://tests/data/boot_logs/"
## tests/data/boot_logs/README.md: file -> [errors, warnings] of the game's line counter, and whether the build
## scripts must take the log for the log of a clean boot.
const LOGS: Dictionary = {
	"clean.txt": [0, 0, true],
	"damaged_settings_and_save.txt": [1, 2, false],
	"warning_before_the_first_script.txt": [0, 1, false],
	"error_after_the_verdict.txt": [1, 0, false],
	"no_verdict.txt": [0, 0, false],
}
const SMOKE_SECONDS: String = "0.2"
const VERDICT: String = "Smoke: ran 0.2 s, %d error(s), %d warning(s) logged"
## An unreadable settings.cfg (a ConfigFile parse error) and a save.json whose write was cut off.
const BAD_SAVE: String = '{ "version": 2, "spaces": { "single/book1/beg'


func _bad_settings() -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray([0x00, 0xff])
	bytes.append_array("[[[ not a config \n=== ".to_utf8_buffer())
	bytes.append_array(PackedByteArray([0x01, 0x02]))
	return bytes


# --- Helpers -----------------------------------------------------------------------------------------------------

## The environment variable that moves the game's user:// on this platform ("" where none does).
func _user_data_variable() -> String:
	match OS.get_name():
		"Windows":
			return "APPDATA"
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			return "XDG_DATA_HOME"
	return ""


func _remove_tree(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for folder: String in dir.get_directories():
		_remove_tree(path + "/" + folder)
	for file: String in dir.get_files():
		dir.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## An empty folder for one boot, inside the test run's own user folder: the game's user folder is ClubAndGrub in it.
func _case_dir(case: String) -> String:
	var path: String = Save.storage_dir + "boot_check/" + case
	_remove_tree(path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path + "/ClubAndGrub"))
	return path


func _write(path: String, bytes: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()


## Boot the project in a new process with its user data in `case_dir` and run the boot check:
## {"code": exit code, "text": everything it printed}.
func _boot(case_dir: String, engine_arguments: PackedStringArray = PackedStringArray()) -> Dictionary:
	var variable: String = _user_data_variable()
	var had_value: bool = OS.has_environment(variable)
	var value: String = OS.get_environment(variable)
	var arguments: PackedStringArray = PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://")])
	arguments.append_array(engine_arguments)
	arguments.append_array(PackedStringArray(["--", "--smoke=" + SMOKE_SECONDS]))
	var output: Array = []
	OS.set_environment(variable, ProjectSettings.globalize_path(case_dir))
	var code: int = OS.execute(OS.get_executable_path(), arguments, output, true)
	if had_value:
		OS.set_environment(variable, value)
	else:
		OS.unset_environment(variable)
	return {"code": code, "text": "".join(PackedStringArray(output))}


## Run a build script on a boot log: {"code": exit code, "text": what it printed}.
func _check_boot_log(script: String, log_path: String) -> Dictionary:
	var output: Array = []
	var code: int = OS.execute("powershell", PackedStringArray(["-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
		ProjectSettings.globalize_path("res://tools/" + script), "-CheckBootLog", log_path]), output, true)
	return {"code": code, "text": "".join(PackedStringArray(output))}


# --- The game's line counter ----------------------------------------------------------------------------------------

func test_the_line_counter_counts_error_and_warning_lines() -> void:
	for file: String in LOGS:
		var text: String = FileAccess.get_file_as_string(LOG_DIR + file)
		assert_true(text.begins_with("Godot Engine v"), "%s is an engine log" % file)
		assert_eq(Autoplay.count_log_problems(text), Vector2i(int(LOGS[file][0]), int(LOGS[file][1])), file)
	var lines: PackedStringArray = [
		"ERROR: one", "   at: push_error (core/variant/variant_utility.cpp:1098)", "SCRIPT ERROR: two",
		"USER ERROR: three", "USER SCRIPT ERROR: four", "   WARNING: indented, one", "USER WARNING: two",
		"Smoke: ran 0.2 s, 0 error(s), 0 warning(s) logged", "a line that says ERROR: in its middle",
		"       [0] _read (res://scripts/core/save.gd:1)", "WARNINGS: no prefix of the engine", "",
	]
	assert_eq(Autoplay.count_log_problems("\n".join(lines)), Vector2i(4, 2), "by the line's first word")
	assert_eq(Autoplay.count_log_problems("\r\n".join(lines)), Vector2i(4, 2), "also in a file with CR LF")
	assert_eq(Autoplay.count_log_problems(""), Vector2i.ZERO)


## The log file holds what a counter that was attached later did not see: the boot check takes the larger count.
func test_the_log_of_this_run_is_read_from_its_first_line() -> void:
	push_warning("test_core_boot_check: a warning before the counter exists (expected)")
	var counter: Autoplay.LogCounter = Autoplay.LogCounter.new()
	OS.add_logger(counter)
	push_warning("test_core_boot_check: a warning the counter sees (expected)")
	OS.remove_logger(counter)
	assert_eq([counter.errors, counter.warnings], [0, 1], "a counter counts from the moment it is attached")
	var logged: Vector2i = Autoplay.own_log_problems()
	var log_path: String = str(ProjectSettings.get_setting(Autoplay.ENGINE_LOG_SETTING, ""))
	if logged.x < 0:
		# No log of this run at the project's log path (file logging off, or the run was started with --log-file).
		print("    note: this run writes no log at %s; the read of the log from its first line was not exercised" % log_path)
		assert_eq(logged, Vector2i(-1, -1))
		return
	assert_true(logged.y >= 2, "the log of this run (%s) holds both warnings: %s" % [log_path, str(logged)])
	var text: String = FileAccess.get_file_as_string(log_path)
	assert_true(text.contains("a warning before the counter exists") and text.contains("a warning the counter sees"))
	assert_eq(Autoplay.count_log_problems(text), logged, "nothing was logged between the two reads")


# --- Real boots -----------------------------------------------------------------------------------------------------

func test_the_boot_check_counts_what_settings_and_save_log_while_they_load() -> void:
	if _user_data_variable().is_empty():
		print("    note: no way to move the game's user folder on %s; the boots were not made" % OS.get_name())
		assert_eq(Autoplay.RELEASE_SWITCHES, PackedStringArray(["smoke"]))
		return
	# 1. An empty user folder: a clean boot, exit code 0.
	var clean_dir: String = _case_dir("clean")
	var clean: Dictionary = _boot(clean_dir)
	assert_eq(int(clean["code"]), 0, "a clean boot exits with 0: %s" % str(clean["text"]).right(400))
	assert_true(str(clean["text"]).contains(VERDICT % [0, 0]), str(clean["text"]).right(400))
	assert_true(FileAccess.file_exists(clean_dir + "/ClubAndGrub/settings.cfg"),
		"the boot used the folder of this test (its shutdown wrote the settings there)")
	if FileAccess.file_exists(clean_dir + "/ClubAndGrub/logs/godot.log"):
		assert_true(str(clean["text"]).contains("Smoke: counted from the first line of the engine's log"),
			"the engine's own log of the run was read")
	# 2. A save.json whose write was cut off: Save warns while it loads - one warning, exit code 1.
	var save_dir: String = _case_dir("save")
	_write(save_dir + "/ClubAndGrub/save.json", BAD_SAVE.to_utf8_buffer())
	var save: Dictionary = _boot(save_dir)
	assert_eq(int(save["code"]), 1, "a warning of Save's loading fails the boot check")
	assert_true(str(save["text"]).contains("WARNING: Save: user://save.json is damaged"), str(save["text"]).right(600))
	assert_true(str(save["text"]).contains(VERDICT % [0, 1]), "and is counted: %s" % str(save["text"]).right(300))
	assert_eq(_bytes(save_dir + "/ClubAndGrub/save.json"), BAD_SAVE.to_utf8_buffer(), "a boot writes no save file")
	assert_false(FileAccess.file_exists(save_dir + "/ClubAndGrub/save.bad.json"), "nor sets one aside: nothing was saved")
	# 3. An unreadable settings.cfg as well, and the log written elsewhere (--log-file, as the build scripts start the
	#    exported game): the game cannot read that log, so this count is the counter's alone - attached before
	#    Settings and Save loaded.
	var both_dir: String = _case_dir("both")
	_write(both_dir + "/ClubAndGrub/save.json", BAD_SAVE.to_utf8_buffer())
	_write(both_dir + "/ClubAndGrub/settings.cfg", _bad_settings())
	var log_path: String = ProjectSettings.globalize_path(both_dir + "/smoke.log")
	var both: Dictionary = _boot(both_dir, PackedStringArray(["--log-file", log_path]))
	var both_text: String = str(both["text"])
	assert_eq(int(both["code"]), 1, "warnings of Settings' and Save's loading fail the boot check")
	assert_true(both_text.contains("WARNING: Settings: could not read user://settings.cfg"), both_text.right(900))
	assert_true(both_text.contains("WARNING: Save: user://save.json is damaged"), both_text.right(900))
	assert_true(both_text.contains("Smoke: counted since the autoloads were made, before Settings and Save loaded"),
		"the count of this boot is the counter's own")
	assert_true(both_text.contains(VERDICT % [1, 2]),
		"the ConfigFile parse error and both warnings are counted: %s" % both_text.right(300))
	# The log file says the same, line by line - what the build scripts read.
	var log_text: String = FileAccess.get_file_as_string(log_path)
	assert_eq(Autoplay.count_log_problems(log_text), Vector2i(1, 2), "the lines of %s" % log_path)
	# And the shutdown's settings save kept the unreadable file before the defaults replaced it.
	assert_eq(_bytes(both_dir + "/ClubAndGrub/settings.bad.cfg"), _bad_settings(), "settings.bad.cfg, byte for byte")
	var written: ConfigFile = ConfigFile.new()
	assert_eq(written.load(both_dir + "/ClubAndGrub/settings.cfg"), OK, "the new settings.cfg is readable")
	assert_eq(_bytes(both_dir + "/ClubAndGrub/save.json"), BAD_SAVE.to_utf8_buffer())
	for case: String in ["clean", "save", "both"]:
		_remove_tree(Save.storage_dir + "boot_check/" + case)
	_remove_tree(Save.storage_dir + "boot_check")


# --- The build scripts ----------------------------------------------------------------------------------------------

func test_both_build_scripts_fail_on_a_boot_log_with_a_warning_or_an_error_line() -> void:
	if OS.get_name() != "Windows":
		print("    note: the build scripts are PowerShell scripts for Windows; their -CheckBootLog was not run on %s" % OS.get_name())
		assert_true(FileAccess.file_exists("res://tools/build_windows.ps1"))
		return
	for script: String in ["build_windows.ps1", "build_installer.ps1"]:
		for file: String in LOGS:
			var clean: bool = LOGS[file][2]
			var result: Dictionary = _check_boot_log(script, ProjectSettings.globalize_path(LOG_DIR + file))
			var text: String = str(result["text"])
			assert_eq(int(result["code"]), 0 if clean else 1, "%s on %s: %s" % [script, file, text.right(300)])
			assert_eq(text.contains("BOOT LOG OK"), clean, "%s on %s: %s" % [script, file, text.right(300)])
			assert_eq(text.contains("BOOT LOG FAILED"), not clean, "%s on %s" % [script, file])
			# The line that fails the log is shown, also where the game's own verdict was clean.
			if int(LOGS[file][0]) + int(LOGS[file][1]) > 0:
				assert_true(text.contains("WARNING / ERROR line(s)"), "%s on %s names the lines: %s" % [script, file, text])
			if file == "warning_before_the_first_script.txt":
				assert_true(text.contains("WARNING: PLANTED FOR THE TEST"), "%s prints the line: %s" % [script, text])
			if file == "error_after_the_verdict.txt":
				assert_true(text.contains("ERROR: PLANTED FOR THE TEST"), "%s prints the line: %s" % [script, text])
			if file == "no_verdict.txt":
				assert_true(text.contains("did not report a clean run"), "%s: %s" % [script, text])
		var missing: Dictionary = _check_boot_log(script, ProjectSettings.globalize_path(LOG_DIR + "no_such_log.txt"))
		assert_eq(int(missing["code"]), 1, "%s: a log that is not there is no clean boot" % script)


## What the two scripts must keep doing, read from their text (on every platform): the log's lines are judged by one
## rule, and no Godot run of the Windows build is started with the player's own APPDATA.
func test_the_build_scripts_read_the_log_and_keep_out_of_the_players_folder() -> void:
	var build_windows: String = FileAccess.get_file_as_string("res://tools/build_windows.ps1")
	var build_installer: String = FileAccess.get_file_as_string("res://tools/build_installer.ps1")
	assert_true(build_windows.contains("$BootLogTolerated = @()"), "no WARNING or ERROR line is tolerated in a boot log")
	assert_true(build_windows.contains("$bootFailure = Get-BootLogFailure $logText"), "step 5 judges the log's lines")
	assert_true(build_installer.contains("$bootLogClean = Test-BootLog $smokeLog"), "the twin's boot is judged the same way")
	assert_true(build_installer.contains('"build_windows.ps1")') and build_installer.contains("-CheckBootLog $LogPath"),
		"by the rule of build_windows.ps1")
	assert_false(build_installer.contains('$smokeText -notmatch "Smoke: ran'), "the game's line alone is not trusted")
	# Every start of the Godot binary gets the build's own APPDATA, the exported game its own.
	var godot_runs: int = 0
	for line: String in build_windows.split("\n"):
		if line.contains("Invoke-Program $script:GodotExe"):
			godot_runs += 1
			assert_true(line.strip_edges().ends_with("$RunAppData"), "a Godot run without the build's APPDATA: %s" % line)
		if line.contains("Invoke-Program $ExePath"):
			assert_true(line.strip_edges().ends_with("$smokeAppData"), "the exported game's own APPDATA: %s" % line)
	assert_eq(godot_runs, 3, "the version check, the runs that hold the lock (import, export) and the shared runs (tests)")
	assert_true(build_windows.contains("$env:APPDATA = $AppData"), "Invoke-Program starts the program with that APPDATA")
	assert_true(build_windows.contains("Copy-Item -LiteralPath (Join-Path $templates $name) -Destination $ownTemplates"),
		"the export finds its template inside the build's own APPDATA")

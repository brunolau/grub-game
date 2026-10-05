extends TestCase
## Release safety: development command-line switches, development files and the export presets.

const PRESETS_PATH: String = "res://export_presets.cfg"
const REQUIRED_EXCLUDES: PackedStringArray = [
	"tests/*", "tools/*", "docs/*", "build/*", "levels/test_*.lvl", "scenes/core/debug_level.tscn",
	"scripts/core/debug_level.gd", "*/dev/*",
]


func _presets() -> ConfigFile:
	var file: ConfigFile = ConfigFile.new()
	assert_eq(file.load(PRESETS_PATH), OK, "export_presets.cfg is readable")
	return file


func _preset_section(file: ConfigFile, platform: String) -> String:
	for section: String in file.get_sections():
		if not section.ends_with(".options") and str(file.get_value(section, "platform", "")) == platform:
			return section
	return ""


func test_release_builds_honour_only_the_smoke_switch() -> void:
	var requested: Dictionary = Autoplay.parse_args(PackedStringArray([
		"--autoplay=test_example", "--inputs=10:R", "--autoplay-scene=res://x.tscn", "--smoke=3", "--fast",
	]))
	var release: Dictionary = Autoplay.allowed_options(requested, false)
	assert_eq(release.keys(), ["smoke"], "a player's copy acts on nothing but the boot check")
	assert_eq(release["smoke"], "3")
	assert_eq(Autoplay.allowed_options(requested, true), requested, "debug builds keep every switch")
	assert_true(Autoplay.allowed_options(Autoplay.parse_args(PackedStringArray(["--autoplay=x"])), false).is_empty())
	var flow: Dictionary = Autoplay.parse_args(PackedStringArray([
		"--flow=tools/autoplay/full_loop.flow", "--user-dir=res://build/x", "--fresh-user", "--transitions",
	]))
	assert_true(Autoplay.allowed_options(flow, false).is_empty(), "flow scripts are a debug-build tool")
	assert_eq(Autoplay.RELEASE_SWITCHES, PackedStringArray(["smoke"]))


func test_development_files_are_detected() -> void:
	var found: PackedStringArray = Autoplay.find_development_files()
	assert_true(found.has("res://tests"), "the source tree has its tests: %s" % str(found))
	assert_true(found.has("res://levels/test_example.lvl"))
	assert_true(found.has("res://scenes/core/debug_level.tscn"))
	assert_true(found.has(Autoplay.FLOW_RUNNER), "the flow runner is a development file")
	assert_true(Autoplay.FLOW_RUNNER.contains("/dev/"), "it lives in a dev folder, which every export excludes")


func test_every_preset_ships_levels_and_no_development_files() -> void:
	var file: ConfigFile = _presets()
	for platform: String in ["Windows Desktop", "macOS", "Android", "iOS"]:
		var section: String = _preset_section(file, platform)
		assert_ne(section, "", "a %s preset exists" % platform)
		if section.is_empty():
			continue
		assert_eq(str(file.get_value(section, "export_filter")), "all_resources", platform)
		var includes: PackedStringArray = str(file.get_value(section, "include_filter")).split(",", false)
		var excludes: PackedStringArray = str(file.get_value(section, "exclude_filter")).split(",", false)
		for i: int in includes.size():
			includes[i] = includes[i].strip_edges()
		for i: int in excludes.size():
			excludes[i] = excludes[i].strip_edges()
		assert_true(includes.has("levels/*.lvl"), "%s ships the level files" % platform)
		assert_true(includes.has("CREDITS.md") and includes.has("assets/licenses/*"), "%s ships the credits" % platform)
		for pattern: String in REQUIRED_EXCLUDES:
			assert_true(excludes.has(pattern), "%s excludes %s" % [platform, pattern])
		assert_false(bool(file.get_value(section, "encrypt_pck", false)), platform)


func test_platform_specific_release_settings() -> void:
	var file: ConfigFile = _presets()
	var windows: String = _preset_section(file, "Windows Desktop") + ".options"
	assert_true(bool(file.get_value(windows, "binary_format/embed_pck")), "Windows ships one .exe")
	assert_eq(str(file.get_value(windows, "binary_format/architecture")), "x86_64")
	assert_eq(str(file.get_value(windows, "application/product_name")), "Club & Grub")
	assert_true(ResourceLoader.exists(str(file.get_value(windows, "application/icon"))))
	var macos: String = _preset_section(file, "macOS") + ".options"
	assert_eq(str(file.get_value(macos, "binary_format/architecture")), "universal")
	var android: String = _preset_section(file, "Android") + ".options"
	assert_true(bool(file.get_value(android, "architectures/arm64-v8a")))
	assert_true(bool(file.get_value(android, "architectures/armeabi-v7a")))
	assert_false(bool(file.get_value(android, "architectures/x86_64")))
	assert_true(bool(file.get_value(android, "screen/immersive_mode")))
	assert_true(bool(file.get_value(android, "permissions/vibrate")), "GameInput.vibrate() needs it")
	assert_eq(str(file.get_value(android, "keystore/release_password")), "", "no secret is ever committed")
	var ios: String = _preset_section(file, "iOS") + ".options"
	assert_true(bool(file.get_value(ios, "architectures/arm64")))
	for options: String in [macos, android, ios]:
		var id_key: String = "package/unique_name" if options == android else "application/bundle_identifier"
		assert_eq(str(file.get_value(options, id_key)), "com.clubandgrub.game", "one application id everywhere")
	assert_eq(int(ProjectSettings.get_setting("display/window/handheld/orientation")), 4,
		"phones and tablets run in (sensor) landscape")


func test_mobile_app_icons() -> void:
	var file: ConfigFile = _presets()
	var ios: String = _preset_section(file, "iOS") + ".options"
	var store: Image = _icon(str(file.get_value(ios, "icons/icon_1024x1024")))
	assert_eq(store.get_size(), Vector2i(1024, 1024), "iOS: the 1024 px store icon")
	assert_false(store.detect_alpha() != Image.ALPHA_NONE, "iOS: the store icon is opaque")
	var android: String = _preset_section(file, "Android") + ".options"
	var back: Image = _icon(str(file.get_value(android, "launcher_icons/adaptive_background_432x432")))
	var fore: Image = _icon(str(file.get_value(android, "launcher_icons/adaptive_foreground_432x432")))
	var mono: Image = _icon(str(file.get_value(android, "launcher_icons/adaptive_monochrome_432x432")))
	for layer: Image in [back, fore, mono]:
		assert_eq(layer.get_size(), Vector2i(432, 432), "Android: adaptive layers are 432 px")
	assert_true(back.detect_alpha() == Image.ALPHA_NONE, "Android: the background layer is opaque")
	# Everything drawn on the foreground lies inside the 66 dp safe circle of the 108 dp layer.
	var radius: float = 432.0 * 66.0 / 108.0 / 2.0
	var outside: int = 0
	for layer: Image in [fore, mono]:
		for y: int in range(0, 432, 2):
			for x: int in range(0, 432, 2):
				if layer.get_pixel(x, y).a > 0.0 and Vector2(x, y).distance_to(Vector2(216, 216)) > radius:
					outside += 1
	assert_eq(outside, 0, "Android: the hero stays inside the safe zone")
	assert_true(ResourceLoader.exists(str(file.get_value(android, "launcher_icons/main_192x192"))))


func _icon(path: String) -> Image:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	assert_not_null(image, "%s loads" % path)
	return image if image != null else Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)

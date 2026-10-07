extends TestCase
## Gate G2 (docs/expansion/PLAN.md 5: "every id of the DESIGN appendix exists with tests"; owner: integration).
##
## Reads the table "Appendix: new ids, keys and actions" of docs/expansion/DESIGN.md and checks every entity id of its
## Enemies, Bosses, Objects, Items, Zones and Projectiles rows: the id has its scene (Spawner.exists - the scene the
## level loader spawns), and some test file (tests/test_*.gd) or developer test level (levels/test_*.lvl) names it,
## so no id of the appendix ships untested. A short name in a row (`guard` after `enemies/roller`) takes the category
## of the last full id before it; a token with `=` or `<` is a parameter, not an id.

const DESIGN_PATH: String = "res://docs/expansion/DESIGN.md"
const APPENDIX_HEADING: String = "## Appendix: new ids, keys and actions"
const ID_ROWS: PackedStringArray = ["Enemies", "Bosses", "Objects", "Items", "Zones", "Projectiles"]


## The appendix's entity ids, in table order.
static func appendix_ids(text: String) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	var start: int = text.find(APPENDIX_HEADING)
	if start < 0:
		return ids
	var end: int = text.find("\n## ", start + APPENDIX_HEADING.length())
	var section: String = text.substr(start, end - start if end > start else -1)
	for line: String in section.split("\n"):
		if not line.begins_with("| "):
			continue
		var cells: PackedStringArray = line.split("|")
		if cells.size() < 3 or not ID_ROWS.has(cells[1].strip_edges()):
			continue
		var category: String = ""
		var parts: PackedStringArray = cells[2].split("`")
		for i: int in range(1, parts.size(), 2):
			var token: String = parts[i].strip_edges().get_slice(" ", 0)
			if token.is_empty() or token.contains("=") or token.contains("<") or token.contains("\\"):
				continue
			if token.contains("/"):
				category = token.get_slice("/", 0)
			elif category.is_empty():
				continue
			else:
				token = "%s/%s" % [category, token]
			if not ids.has(token):
				ids.append(token)
	return ids


## The text of every test file and developer test level, for the "named by a test" check.
static func _test_texts() -> String:
	var all: PackedStringArray = PackedStringArray()
	for pair: Array in [["res://tests/", "test_", ".gd"], ["res://levels/", "test_", ".lvl"]]:
		for file: String in DirAccess.get_files_at(str(pair[0])):
			if file.begins_with(str(pair[1])) and file.ends_with(str(pair[2])) and file != "test_integration_appendix.gd":
				all.append(FileAccess.get_file_as_string(str(pair[0]) + file))
	return "\n".join(all)


func test_the_appendix_lists_the_ids_of_phase_0() -> void:
	var ids: PackedStringArray = appendix_ids(FileAccess.get_file_as_string(DESIGN_PATH))
	for id: String in ["enemies/roller", "enemies/shaman", "bosses/chieftain", "objects/x2_tablet", "objects/gate",
			"objects/spawn_point", "items/painting", "items/weapon", "zones/current", "zones/goal",
			"projectiles/hero_spear"]:
		assert_true(ids.has(id), "the appendix names %s (read %d ids)" % [id, ids.size()])
	assert_true(ids.size() >= 40, "the 41 ids of phase 0 (%d)" % ids.size())


func test_every_appendix_id_has_a_scene_and_a_test() -> void:
	var ids: PackedStringArray = appendix_ids(FileAccess.get_file_as_string(DESIGN_PATH))
	var tests: String = _test_texts()
	var missing_scene: PackedStringArray = PackedStringArray()
	var untested: PackedStringArray = PackedStringArray()
	for id: String in ids:
		if not Spawner.exists(StringName(id)):
			missing_scene.append(id)
		if not tests.contains(id):
			untested.append(id)
	assert_eq(missing_scene, PackedStringArray(), "every appendix id has its scene (%s)" % Spawner.scene_path(&"x/y"))
	assert_eq(untested, PackedStringArray(), "every appendix id is named by a test or a test level")
	print("    appendix ids: %d, each with a scene and a test" % ids.size())

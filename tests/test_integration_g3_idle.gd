extends "res://tests/test_enemies_case.gd"
## Gate G3 bookkeeping of the IDLE-PARTNER rule (owner: integration; DESIGN.md D.3 [G33], G47; PLAN.md 8 V3.c).
##
## The single-hero search of test_coop_gates models a lone player's partner as an idle hatched hero placed anywhere he
## could be hatched who counts for NO co-op rule. Its refusals only prove the gates if the engine agrees. This file
## checks the engine side of the trait rules whose owner (enemies-A, scripts/enemies/coop_traits.gd) had no run in
## phase 3 (wf9_lead_design_to_integration.txt #4): a `shell` record's shield must face the nearer hero who COUNTS
## (LevelBase.nearest_coop_hero), never a dozing partner - else a lone player parks his idle partner in front of a
## Shellback keeper and clubs its back (G33); a dazed `daze` record is hurt only by a hero of another slot than the one
## whose bounce dazed it (G47) - else one hero dazes and strikes alone. It prints one `G3 |` row per rule (tools/g3.sh
## shows them in the content table, run with the inventory: `bash .tools/gd.sh test integration_g3`); an open rule fails
## only at the gate itself (G3_REQUIRE=1, tools/g3.sh --require), so the default suite stays green meanwhile.

var _p2: PlayerBase = null


func before_each() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	Game.begin_level(&"test")
	Sim.rng.reseed(1)
	_level = null
	_flat_level(60, 16, 10)
	_p2 = PlayerBase.new()
	place(_level, _p2, Vector2i(100, 160), {"slot": 1})
	_p2.respawn_at(Vector2i(100, 160))


func after_each() -> void:
	GameInput.clear_scripted()
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"")


## P1 plays, P2 dozes (the fixture's heroes are bare PlayerBase: nothing recounts their idle verdict).
func _p1_active_p2_idle() -> void:
	_hero.gave_input = true
	_hero.input_idle_ticks = 0
	_hero.idle = false
	_p2.gave_input = false
	_p2.input_idle_ticks = PlayerBase.IDLE_TICKS
	_p2.idle = true


func _row(row: String, done: bool, detail: String) -> void:
	print("    G3 | %s | %d | 1 | %s | %s" % [row, 1 if done else 0, "complete" if done else "open", detail])
	if OS.get_environment("G3_REQUIRE") == "1":
		assert_true(done, "G3 %s: %s" % [row, detail])


## G33: a Shellback keeper's shield faces the hero who plays, not the dozing partner who stands nearer.
func test_an_idle_partner_is_no_shellback_bait() -> void:
	var shell: EnemyBase = _enemy(&"enemies/walker", Vector2i(160, 160), {"coop": "shell", "speed": 0, "hp": 100})
	_hero.teleport(Vector2i(120, 160))
	_p2.teleport(Vector2i(180, 160))
	_p1_active_p2_idle()
	assert_true(_hero.counts_for_coop(), "P1 counts")
	assert_false(_p2.counts_for_coop(), "the dozing P2 counts for no co-op rule")
	Sim.step(2)
	_p1_active_p2_idle()
	var faces_p1: bool = shell.facing == -1
	shell.take_hit(25, _hero)
	var glanced: bool = shell.hp == 100
	_row("idle_shell_bait", faces_p1 and glanced, "G33 (enemies-A, coop_traits.gd): a shell keeper with the active P1 40 px left and the idle P2 20 px right %s" % (
			"faces P1 and his strike glances" if faces_p1 and glanced
			else "faces the idle P2 (facing %d) and P1's strike hits its back (hp %d): a lone player can bait it with his dozing partner" % [
				shell.facing, shell.hp]))


## G47: the daze is slot-bound - the bouncer's own hits glance, the other hero's count.
func test_the_daze_is_slot_bound() -> void:
	var raptor: EnemyBase = _enemy(&"enemies/hopper", Vector2i(200, 160), {"coop": "daze", "skin": "mini_rex_b",
		"range": 0, "hp": 100})
	_hero.teleport(Vector2i(180, 160))
	_p2.teleport(Vector2i(300, 160))
	Sim.step(2)
	raptor.on_bounced(_hero)
	assert_true(raptor.coop_traits().dazed > 0, "P1's head bounce dazes it")
	raptor.take_hit(25, _hero)
	var own_glances: bool = raptor.hp == 100
	raptor.take_hit(25, _p2)
	var other_counts: bool = raptor.hp < 100
	_row("daze_slot_bound", own_glances and other_counts, "G47 (enemies-A, coop_traits.gd): after P1's bounce %s" % (
			"P1's own strike glances and P2's counts" if own_glances and other_counts
			else "P1's own strike %s, P2's %s (hp %d): one hero dazes and strikes alone" % [
				"glances" if own_glances else "counts", "counts" if other_counts else "glances", raptor.hp]))

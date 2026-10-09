extends TestCase
## Phase 4 (PLAN.md 7 P4.2, docs/ARCHITECTURE.md 11.5): the mobile cap on the heroes of a versus match. On a phone or
## tablet a match seats VersusTuning.PLAYERS_MAX_MOBILE heroes at most - humans and CPUs together -, a desktop build
## seats Defs.MAX_PLAYERS as before. The value is an estimate for a Cortex-A53 class device (no device was measured);
## the test pins the rule, whatever the value becomes after a device check.


func before_each() -> void:
	VersusMatch.mobile = false


func after_each() -> void:
	VersusMatch.mobile = OS.has_feature("mobile")


func test_the_cap_is_a_tuning_value_inside_the_player_range() -> void:
	assert_eq(VersusTuning.players_max(false), VersusTuning.PLAYERS_MAX, "a desktop seats every player slot")
	assert_eq(VersusTuning.players_max(false), Defs.MAX_PLAYERS)
	assert_eq(VersusTuning.players_max(true), VersusTuning.PLAYERS_MAX_MOBILE)
	assert_true(VersusTuning.PLAYERS_MAX_MOBILE >= VersusTuning.PLAYERS_MIN, "a match needs two")
	assert_true(VersusTuning.PLAYERS_MAX_MOBILE <= VersusTuning.PLAYERS_MAX)
	# Two-player co-op is the mobile target (PLAN.md 9): the cap never goes under a co-op party.
	assert_true(VersusTuning.PLAYERS_MAX_MOBILE >= PartyTuning.COOP_PLAYERS)
	# The estimate of ARCHITECTURE.md 11.5 as it stands (no device was measured): two heroes.
	assert_eq(VersusTuning.PLAYERS_MAX_MOBILE, 2)


func test_a_desktop_match_seats_four() -> void:
	var versus_match: VersusMatch = VersusMatch.new()
	assert_eq(VersusMatch.seat_limit(), Defs.MAX_PLAYERS)
	assert_eq(versus_match.seat_human(InputSlot.new()), 0)
	for slot: int in range(1, Defs.MAX_PLAYERS):
		assert_eq(versus_match.seat_bot(Defs.BotLevel.HUNTER), slot)
	assert_eq(versus_match.player_count(), Defs.MAX_PLAYERS)
	assert_eq(versus_match.seat_bot(Defs.BotLevel.HUNTER), -1, "the lobby is full")


func test_a_mobile_match_seats_no_more_than_the_cap() -> void:
	VersusMatch.mobile = true
	var cap: int = VersusTuning.PLAYERS_MAX_MOBILE
	assert_eq(VersusMatch.seat_limit(), cap)
	var versus_match: VersusMatch = VersusMatch.new()
	assert_eq(versus_match.seat_human(InputSlot.new()), 0)
	for slot: int in range(1, cap):
		assert_eq(versus_match.seat_bot(Defs.BotLevel.HUNTER), slot)
	assert_eq(versus_match.player_count(), cap)
	# Neither a CPU nor a human gets a seat beyond it, by the first free seat or by name.
	assert_eq(versus_match.seat_bot(Defs.BotLevel.ROOKIE), -1, "the lobby is full at the cap")
	if cap < Defs.MAX_PLAYERS:
		assert_eq(versus_match.seat_bot(Defs.BotLevel.ROOKIE, cap), -1, "seat %d is beyond the cap" % cap)
		assert_eq(versus_match.seat_human(InputSlot.new(), Defs.MAX_PLAYERS - 1), -1)
		assert_false(versus_match.is_seated(cap))
	assert_eq(versus_match.player_count(), cap)
	# A seat inside the cap that was left is free again.
	versus_match.unseat(cap - 1)
	assert_eq(versus_match.seat_bot(Defs.BotLevel.CHIEF), cap - 1)
	# The match itself is an ordinary match of that many players.
	versus_match.ready_all()
	assert_true(versus_match.can_start(), "a match of %d can start" % cap)
	# Back on a desktop the same match takes more.
	VersusMatch.mobile = false
	if cap < Defs.MAX_PLAYERS:
		assert_eq(versus_match.seat_bot(Defs.BotLevel.HUNTER), cap)

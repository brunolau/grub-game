#!/usr/bin/env bash
# R7 (b) - THE EVIDENCE SET: replay every route of tools/coop_explore/evidence in a FRESH process each (the solo
# search's own world, or the real game for a file that says real=true) and print one line per route. A route that
# still says "REACHED the far cell" is an open gate row: each must say "not reached" (or "DIED") before its gate is
# closed (docs/expansion/DESIGN.md G77, LEVEL_DESIGN.md 15.7.6: "a replay wins"). The set only grows: the G3b
# verifier's 21 routes, the lead designer's three (G79, the pool ledge of 1-1), the nine finds of wf11's explorer - and
# since wf12 four routes AIMED AT THE REBUILT GATES (their old routes steer for geometry that is gone):
#   w9_l2_coop.drive.expert.gust_new_lip          the gust jump from the slide at the new lip (203): it carries 150 px
#                                                 and ends in the tar at column 212 of a gap that ends at 216
#   w7_l1_coop.stack.{beginner,expert}.long_drop_moved_stack   the warp stack's vine and the running jump off its top
#                                                 (tools/coop_explore/main.gd explore ... goal=213,17): the fall ends on
#                                                 the step at column 218, 7 rows under the shoulder
#   w6_l2_coop.seesaw.expert.wf12_ward_off        found with the ward switched off (PRE2_GATE_RULES_OFF=2: an Up bounce
#                                                 on the stinger he leads to the cap ledge, tick 458) - it REACHES the
#                                                 far cell with that switch and does not with every rule on
# WHICH RULE HOLDS A ROUTE: `PRE2_GATE_RULES_OFF=<bits> EVIDENCE_OUT=build/coop_explore/evidence_off bash
# tools/coop_explore/replay_evidence.sh` replays the set with gate rules switched off (PlayerBase.GATE_R1 = 1 the
# spring launch, R3 = 2 the ward, R5 = 4 the closed door, R6 = 8 the idle hero; 15 = all four). A route that reaches
# then and not without the switch stands at today's geometry and is held by that rule (11 of the 33 routes of wf11
# with all four off; the others are held by the level as rebuilt or by a rule without a switch - the slot-bound
# bonds G72, the coil's own level G81, the shield G82). Results found with a switch are kept under their own keys.
# Owner: world-B (PLAN.md 4.1). The G3b verifier's verify_evidence.sh, adopted in wf11.
#
#   bash tools/coop_explore/replay_evidence.sh [P] [dir]
#       P     processes at once (default 8)
#       dir   another folder of route files (default tools/coop_explore/evidence; its sub-folders are not read:
#             evidence/not_replayable holds the explorer finds of G3b that no fresh process replayed - seeds, no
#             evidence either way)
#   EVIDENCE_OUT=build/coop_explore/evidence bash ...    where the logs go
# Every result is kept for the gate test (tests/test_coop_gates.gd reads it back: harness.gd replay_key - the route
# file, the level file and the simulation's code). Exit code 0 = no route reaches its far cell, 1 = some do.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 2
P="${1:-8}"
DIR="${2:-tools/coop_explore/evidence}"
OUT="${EVIDENCE_OUT:-build/coop_explore/evidence}"
mkdir -p "$OUT"
for f in "$DIR"/*.txt; do
	[ -f "$f" ] || continue
	while [ "$(jobs -rp | wc -l)" -ge "$P" ]; do wait -n 2>/dev/null || sleep 1; done
	name="$(basename "$f" .txt)"
	( GD_TIMEOUT="${EVIDENCE_TIMEOUT:-900}" bash .tools/gd.sh script res://tools/coop_explore/main.gd -- replay "res://$f" cache=1 \
		> "$OUT/$name.log" 2>&1 ) &
	sleep 0.5
done
wait
reached=0; total=0; missing=0
for f in "$DIR"/*.txt; do
	[ -f "$f" ] || continue
	name="$(basename "$f" .txt)"
	line="$(grep -h "^REPLAY .*: \(REACHED\|DIED\|not reached\)" "$OUT/$name.log" | tail -1)"
	total=$((total + 1))
	case "$line" in
		*"REACHED the far cell"*) reached=$((reached + 1)) ;;
		"") missing=$((missing + 1)) ;;
	esac
	printf '%-46s %s\n' "$name" "${line:-NO RESULT (see $OUT/$name.log)}"
done
echo "replay_evidence: $reached of $total route(s) still REACH their far cell$([ "$missing" -gt 0 ] && echo "; $missing without a result")"
[ "$reached" -eq 0 ] && [ "$missing" -eq 0 ]

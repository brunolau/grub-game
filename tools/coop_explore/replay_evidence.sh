#!/usr/bin/env bash
# R7 (b) - THE EVIDENCE SET: replay every route of tools/coop_explore/evidence in a FRESH process each (the solo
# search's own world, or the real game for a file that says real=true) and print one line per route. A route that
# still says "REACHED the far cell" is an open gate row: each must say "not reached" (or "DIED") before its gate is
# closed (docs/expansion/DESIGN.md G77, LEVEL_DESIGN.md 15.7.6: "a replay wins"). The set only grows: the G3b
# verifier's 21 routes and the lead designer's two gust routes (G79) today.
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

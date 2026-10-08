#!/usr/bin/env bash
# The co-op gate proofs in parallel: tests/test_coop_gates.gd (the solo-impossibility search of every x2 gate of every
# co-op file on both difficulties, docs/expansion/PLAN.md 8 V3.c) on N processes at once.
# Owner: world-B (PLAN.md 4.1, tools/world_*).
#
#   bash tools/world_coop_gates.sh                N workers = the CPU cores (Godot's thread count / 2, at most 16)
#   bash tools/world_coop_gates.sh 8              8 workers
#   bash tools/world_coop_gates.sh --shards [N]   the old way: N shards of the test itself (COOP_GATES_SHARD=i/N)
#   bash tools/world_coop_gates.sh --bench K [N]  the SCALE BENCH of the queue mode: the workers search every gate K
#                                                 times (copies 1..K-1 afresh, no cache: tools/coop_search.gd --repeat=K),
#                                                 then the test as usual - today's 45 gates x 3 cost what about 70 gates x
#                                                 2 difficulties will (PLAN.md V7's 20-minute target)
#   COOP_GATES_TIMEOUT=2400 bash tools/world_coop_gates.sh     each process's GD_TIMEOUT (default 3600 s)
#   COOP_GATES_ROUNDS=3 bash tools/world_coop_gates.sh         most worker rounds of step 1 (default 3)
#
# QUEUE MODE (the default) - two steps:
#  1. N workers `bash .tools/gd.sh script res://tools/coop_search.gd -- --queue=build/coop_gates/queue` share one work
#     queue: each takes the gates dearest first (the cost of their last search, CoopSearch.order_by_cost) and searches
#     only the gates it claims (CoopSearch.claim_gate: an atomic folder per gate), so no worker idles while another
#     still has a long list (the fixed `index % N` split of --shards left shards 415-565 s apart). Every search lands
#     in scripts/world/coop_search.gd's result cache (build/coop_search_cache: keyed by the level file, its base file,
#     gate, difficulty, partner model and the md5 of the simulation's code). A round that searched anything is followed
#     by another round (a fresh queue; the cached gates are read back in a moment): a level saved or a script edited
#     while the round ran (other agents work meanwhile) is searched again in parallel there, not alone by the test.
#     The rounds end with one that searched nothing (the cache is complete) or after COOP_GATES_ROUNDS.
#  2. ONE run of the test (`bash .tools/gd.sh test coop_gates`) asserts every gate: it calls the same search, which
#     reads each result back from the cache ("cached" in its line) - unless a file or the code changed since step 1,
#     then it searches that gate again itself. The test is the verdict; the workers only do the work early.
# Logs: build/coop_gates/worker_<i>.r<round>.log, build/coop_gates/test.log (or shard_<i>.log). Prints every gate
# line, the verdict and the wall time; exit 0 when the test passed.
#
# Many processes share the machine: run it alone for the timing of PLAN.md V7 (target: about 70 gates x 2
# difficulties in under 20 minutes on this 12-core desktop). The processes share Godot's import cache (gd.sh shared
# runs). Measured 2026-10-08 (world-B, wf9; 12 workers, other agents' Godot runs beside them):
#   08:00  --bench 3: 135 searches (45 gates x 3) in 688-713 s per worker (mean 62.6 s a search; 14.6 Godot
#          processes and 85 % CPU on average), after 70 s waiting for another agent's exclusive gd.sh run;
#   08:34  the default mode on the 72-gate table: round 1 72 searches in 360 s (mean 57.4 s), round 2 nothing new
#          (14 s), the test 5 s (all 72 cached) - 6 min 19 s in all, every gate refused.
# So about 140 gate searches take about 12 minutes on 12 workers.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE=queue
REPEAT=1
if [ "${1:-}" = "--shards" ]; then
	MODE=shards
	shift
elif [ "${1:-}" = "--bench" ]; then
	REPEAT="${2:-3}"
	shift
	[ $# -gt 0 ] && shift
fi
THREADS="$(nproc 2>/dev/null || echo 4)"
N="${1:-$(( THREADS / 2 ))}"
[ "$N" -lt 1 ] && N=1
[ "$N" -gt 16 ] && [ $# -eq 0 ] && N=16
TMO="${COOP_GATES_TIMEOUT:-3600}"
OUT="$ROOT/build/coop_gates"
mkdir -p "$OUT"
START=$(date +%s)

if [ "$MODE" = "shards" ]; then
	rm -f "$OUT"/shard_*.log
	pids=()
	for ((i = 0; i < N; i++)); do
		( cd "$ROOT" && COOP_GATES_SHARD="$i/$N" GD_TIMEOUT="$TMO" bash .tools/gd.sh test coop_gates \
			> "$OUT/shard_$i.log" 2>&1; echo "exit=$?" >> "$OUT/shard_$i.log" ) &
		pids+=($!)
		sleep 1   # stagger the starts: every shard parses the gate table at once otherwise
	done
	for pid in "${pids[@]}"; do
		wait "$pid"
	done
	END=$(date +%s)
	failed=0
	echo "== gates"
	grep -h -E "^\s+.* gate .*: (refused|REACHED) in " "$OUT"/shard_*.log | sed 's/^ *//' | sort
	echo "== shards"
	for ((i = 0; i < N; i++)); do
		log="$OUT/shard_$i.log"
		code="$(grep -E '^exit=' "$log" | tail -1 | cut -d= -f2)"
		summary="$(grep -E 'passed|failed|FAIL' "$log" | tail -1)"
		if [ "$code" != "0" ]; then
			failed=1
			echo "shard $i/$N: FAILED (exit $code) - $summary  ($log)"
			grep -E "FAIL|assert|Error|error" "$log" | head -20 | sed 's/^/    /'
		else
			echo "shard $i/$N: ok - $summary"
		fi
	done
	echo "== $N shard(s) in $((END - START)) s: $([ $failed -eq 0 ] && echo "all gates refused" || echo "FAILURES")"
	exit $failed
fi

# Queue mode: worker rounds until a round searched nothing new (or ROUNDS_MAX rounds), then the test.
QUEUE="$OUT/queue"
rm -f "$OUT"/worker_*.log "$OUT/test.log"
ROUNDS_MAX="${COOP_GATES_ROUNDS:-3}"
round=0
searches=0
while :; do
	round=$((round + 1))
	rm -rf "$QUEUE"
	mkdir -p "$QUEUE"
	# The bench's copies are searched in the first round only (a later round only catches up with changed files).
	repeat=$([ "$round" -eq 1 ] && echo "$REPEAT" || echo 1)
	pids=()
	for ((i = 0; i < N; i++)); do
		( cd "$ROOT" && GD_TIMEOUT="$TMO" bash .tools/gd.sh script res://tools/coop_search.gd -- \
			--queue=res://build/coop_gates/queue --repeat="$repeat" \
			> "$OUT/worker_$i.r$round.log" 2>&1; echo "exit=$?" >> "$OUT/worker_$i.r$round.log" ) &
		pids+=($!)
		sleep 1   # stagger the starts (each worker reads the gate table and the code fingerprint first)
	done
	for pid in "${pids[@]}"; do
		wait "$pid"
	done
	fresh="$(cat "$OUT"/worker_*.r$round.log | grep -E ' gate .*: (refused|REACHED) in ' | grep -vc ', cached)')"
	searches=$((searches + fresh))
	echo "== round $round: $fresh gate search(es) ($(( $(date +%s) - START )) s so far)"
	# A round that searched something may have raced a file edit (a designer saving a level, a code change): one
	# more round finds every gate whose result is not in the cache any more, in parallel, before the test does it
	# alone. A round that only read the cache is the proof that the cache is complete.
	if [ "$fresh" -eq 0 ] || [ "$round" -ge "$ROUNDS_MAX" ]; then
		break
	fi
done
MID=$(date +%s)
echo "== workers ($N, $round round(s), $((MID - START)) s, $searches search(es)$([ "$REPEAT" -gt 1 ] && echo "; bench: every gate $REPEAT times in round 1"))"
for ((i = 0; i < N; i++)); do
	log="$OUT/worker_$i.r1.log"
	echo "worker $i (round 1): $(grep -E '^coop_search: ' "$log" | tail -1) ($(grep -E '^exit=' "$log" | tail -1))"
done
( cd "$ROOT" && GD_TIMEOUT="$TMO" bash .tools/gd.sh test coop_gates > "$OUT/test.log" 2>&1 )
code=$?
END=$(date +%s)
echo "== gates (the test, $((END - MID)) s)"
grep -E "^\s+.* gate .*: (refused|REACHED) in |slot-bound" "$OUT/test.log" | sed 's/^ *//'
searched_again="$(grep -E "^\s+.* gate .*: (refused|REACHED) in " "$OUT/test.log" | grep -vc " cached$")"
echo "== $(grep -E 'test_coop_gates.gd' "$OUT/test.log" | tail -1 | sed 's/^ *//')"
echo "== $N worker(s) + the test in $((END - START)) s ($searched_again gate(s) searched again by the test): \
$([ $code -eq 0 ] && echo "all gates refused" || echo "FAILURES (see $OUT/test.log)")"
exit $code

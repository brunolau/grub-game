#!/usr/bin/env bash
# The co-op gate proofs in parallel: tests/test_coop_gates.gd (the solo-impossibility search of every x2 gate of every
# co-op file on both difficulties, docs/expansion/PLAN.md 8 V3.c) on N processes at once.
# Owner: world-B (PLAN.md 4.1, tools/world_*).
#
# THE ROW IS THREE PROOFS (wf11: the orchestrator's R7, docs/expansion/DESIGN.md G77 - the bar is fixed): (a) the solo
# search refuses the gate, (b) every route of the evidence set says "not reached" in a fresh process, (c) the
# continuous-play explorer opens it in none of two seeded passes of 300 s over the whole level. This script runs all
# three on worker processes and then the test, which reads their kept results:
#   step 1  the search workers (below)                        76 rows: about 10-15 minutes on 12 workers
#   step 1b tools/coop_explore/replay_evidence.sh             23 routes, a fresh process each: about a minute
#   step 1c tools/coop_explore/explore_gates.sh               76 rows x 2 passes x 300 s = 12.7 hours of play:
#                                                             38 minutes on 20 processes, 63 on 12 (COOP_GATES_EXPLORERS,
#                                                             default N); rows the search or a route already opened
#                                                             are not explored (they are red)
#   step 2  the test (reads everything back)                  seconds
# THE WHOLE GATE JOB IN ABOUT 40 MINUTES: `COOP_GATES_EXPLORERS=20 bash tools/world_coop_gates.sh 12` on this 12-core /
# 24-thread desktop with nothing else running - the search on 12 workers WHILE the explorers start on the rows the
# evidence set leaves closed is not attempted: the three steps run one after another (about 12 + 1 + 38 minutes; with
# the results kept, a rerun on an unchanged tree is a minute). A pass is 300 s of WALL time, so more explorer
# processes than cores play fewer ticks per pass: each pass prints the ticks it played and the row shows them.
#   --no-explore      skip step 1c (the rows then read "unproven: (c) ... NOT RUN" unless their passes are kept)
#   COOP_GATES_EXPLORERS=20 bash tools/world_coop_gates.sh 12     12 search workers, 20 explorer processes
#
#   bash tools/world_coop_gates.sh                N workers = the CPU cores (Godot's thread count / 2, at most 16)
#   bash tools/world_coop_gates.sh 8              8 workers
#   bash tools/world_coop_gates.sh --fresh [N]    the UNCACHED proof run (DESIGN.md G59): round 1 searches every gate
#                                                 again whatever the cache holds (tools/coop_search.gd --fresh) and
#                                                 stores the results; the test then reads exactly those
#   bash tools/world_coop_gates.sh --shards [N]   the old way: N shards of the test itself (COOP_GATES_SHARD=i/N)
#   bash tools/world_coop_gates.sh --bench K [N]  the SCALE BENCH of the queue mode: the workers search every gate K
#                                                 times (copies 1..K-1 afresh, no cache: tools/coop_search.gd --repeat=K),
#                                                 then the test as usual - today's 45 gates x 3 cost what about 70 gates x
#                                                 2 difficulties will (PLAN.md V7's 20-minute target)
#   COOP_GATES_TIMEOUT=2400 bash tools/world_coop_gates.sh     each process's GD_TIMEOUT (default 3600 s)
#   COOP_GATES_ROUNDS=3 bash tools/world_coop_gates.sh         most worker rounds of step 1 (default 3)
#   COOP_GATES_OUT=build/my_gates bash tools/world_coop_gates.sh    another folder for the queue and the logs (two runs
#                                                              at once must not share one: each empties its queue)
#
# QUEUE MODE (the default) - two steps:
#  1. N workers share one work queue: each runs `bash .tools/gd.sh script res://tools/coop_search.gd --
#     --queue=build/coop_gates/queue --max-gates=1` again and again - ONE GATE PER GODOT PROCESS, so an import another
#     terminal needs gets its turn between two gates, and every gate starts with an empty engine message queue - and
#     each process takes the dearest gate nobody claimed yet (the cost of its last search, CoopSearch.order_by_cost;
#     CoopSearch.claim_gate: an atomic folder per gate), so no worker idles while another
#     still has a long list (the fixed `index % N` split of --shards left shards 415-565 s apart). Every search lands
#     in scripts/world/coop_search.gd's result cache (build/coop_search_cache: keyed by the level file, its base file,
#     gate, difficulty, partner model and the md5 of the simulation's code). A round that searched anything is followed
#     by another round (a fresh queue; the cached gates are read back in a moment): a level saved or a script edited
#     while the round ran (other agents work meanwhile) is searched again in parallel there, not alone by the test.
#     The rounds end with one that searched nothing (the cache is complete) or after COOP_GATES_ROUNDS.
#  2. ONE run of the test (`bash .tools/gd.sh test coop_gates`) asserts every gate: it calls the same search, which
#     reads each result back from the cache ("cached" in its line) - unless a file or the code changed since step 1,
#     then it searches that gate again itself. The test is the verdict; the workers only do the work early.
#  3. THE G59 TABLE: one verdict line per gate and difficulty - `GATE <level> <difficulty> <gate>: refused
#     (exhaustive) | refused (bounded) | open | unproven (<evidence>)` - printed and kept in
#     build/coop_gates/verdicts.txt, with the counts. "Refused" never means "stopped at the bound": an exhaustive
#     refusal emptied the search's frontier; a bounded one expanded at least 660 resting points AND ran every
#     continuous-play probe of the gate's kind (hop-over, charge-under, idle-bait, thrown-special, plates; egg
#     placement besides); anything less is UNPROVEN and fails the test like an open gate.
# Logs: build/coop_gates/worker_<i>.r<round>.log (per gate: the search and every probe family's counts),
# build/coop_gates/test.log (or shard_<i>.log). Prints every gate line, the verdicts and the wall time; exit 0 when
# the test passed.
#
# Many processes share the machine: run it alone for the timing of PLAN.md V7 (target: about 70 gates x 2
# difficulties in under 20 minutes on this 12-core desktop). The processes share Godot's import cache (gd.sh shared
# runs). Measured 2026-10-08 (world-B, wf9; 12 workers, other agents' Godot runs beside them):
#   08:00  --bench 3: 135 searches (45 gates x 3) in 688-713 s per worker (mean 62.6 s a search; 14.6 Godot
#          processes and 85 % CPU on average), after 70 s waiting for another agent's exclusive gd.sh run;
#   08:34  the default mode on the 72-gate table: round 1 72 searches in 360 s (mean 57.4 s), round 2 nothing new
#          (14 s), the test 5 s (all 72 cached) - 6 min 19 s in all, every gate refused.
# So about 140 gate searches took about 12 minutes on 12 workers - under the 220-point bound of phase 3.
# Since the G59 search of wf10 (2026-10-09; raised bounds, the continuous-play probes, one gate per process):
#   00:03  --fresh 12 on the 76-gate table: round 1 76 uncached searches in 799 s (2 h 34 min of search summed: mean
#          122 s a gate, the dearest 315 s; 50.0 million ticks), round 2 nothing new (33 s), the test 4 s (all 76
#          cached) - 13 min 56 s in all, other agents' Godot runs beside it. Verdicts of that tree: 40 refused
#          (exhaustive), 27 refused (bounded), 9 open, 0 unproven.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE=queue
REPEAT=1
FRESH=0
EXPLORE=1
if [ "${1:-}" = "--no-explore" ]; then
	EXPLORE=0
	shift
fi
if [ "${1:-}" = "--shards" ]; then
	MODE=shards
	shift
elif [ "${1:-}" = "--bench" ]; then
	REPEAT="${2:-3}"
	shift
	[ $# -gt 0 ] && shift
elif [ "${1:-}" = "--fresh" ]; then
	FRESH=1
	shift
fi
THREADS="$(nproc 2>/dev/null || echo 4)"
N="${1:-$(( THREADS / 2 ))}"
[ "$N" -lt 1 ] && N=1
[ "$N" -gt 16 ] && [ $# -eq 0 ] && N=16
TMO="${COOP_GATES_TIMEOUT:-3600}"
OUT="${COOP_GATES_OUT:-$ROOT/build/coop_gates}"
case "$OUT" in
	/* | ?:*) ;;
	*) OUT="$ROOT/$OUT" ;;
esac
mkdir -p "$OUT"
# The queue folder as the workers get it: a res:// path inside the project, else the OS path.
case "$OUT" in
	"$ROOT"/*) QUEUE_ARG="res://${OUT#"$ROOT"/}/queue" ;;
	*) QUEUE_ARG="$OUT/queue" ;;
esac
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
rm -f "$OUT"/worker_*.log "$OUT"/worker_*.part "$OUT/test.log" "$OUT/verdicts.txt"
ROUNDS_MAX="${COOP_GATES_ROUNDS:-3}"

# One worker of one round: ONE GATE PER GODOT PROCESS (tools/coop_search.gd --max-gates=1), again and again until a
# process finds nothing left to claim. A process per gate costs a few seconds of start-up each, and buys two things:
# an import that another terminal needs (gd.sh: exclusive, it waits for every running Godot) gets its turn after the
# gates in flight instead of after the whole table, and Godot's message queue starts empty for every gate (a search
# passes no frame; scripts/world/coop_search.gd SearchLevel.spawn).
worker() {
	local index="$1" round="$2" extra="$3"
	local log="$OUT/worker_$index.r$round.log" part="$OUT/worker_$index.r$round.part"
	local code=0 failed=0
	: > "$log"
	while :; do
		( cd "$ROOT" && GD_TIMEOUT="$TMO" bash .tools/gd.sh script res://tools/coop_search.gd -- \
			--queue="$QUEUE_ARG" --max-gates=1 $extra ) > "$part" 2>&1
		code=$?
		cat "$part" >> "$log"
		if grep -q "^coop_search: 0 gate(s)" "$part"; then
			break   # nothing left to claim
		fi
		if ! grep -q "^coop_search: 1 gate(s)" "$part"; then
			# Killed or crashed: its gate stays claimed without a result - the next round searches it again.
			failed=$((failed + 1))
			echo "worker $index: a search process ended without a result (exit $code)" >> "$log"
			[ "$failed" -ge 3 ] && break
		fi
	done
	rm -f "$part"
	echo "exit=$code" >> "$log"
}

round=0
searches=0
while :; do
	round=$((round + 1))
	rm -rf "$QUEUE"
	mkdir -p "$QUEUE"
	# The bench's copies and the uncached proof run are the first round's (a later round only catches up with what
	# changed meanwhile, from the cache).
	extra=""
	if [ "$round" -eq 1 ]; then
		[ "$REPEAT" -gt 1 ] && extra="--repeat=$REPEAT"
		[ "$FRESH" -eq 1 ] && extra="$extra --fresh"
	fi
	pids=()
	for ((i = 0; i < N; i++)); do
		worker "$i" "$round" "$extra" &
		pids+=($!)
		sleep 1   # stagger the starts (each process reads the gate table and the code fingerprint first)
	done
	for pid in "${pids[@]}"; do
		wait "$pid"
	done
	fresh="$(cat "$OUT"/worker_*.r$round.log | grep -E ' gate .*: (refused|REACHED|UNPROVEN) in ' | grep -vc ', cached)')"
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
echo "== workers ($N, $round round(s), $((MID - START)) s, $searches search(es)$([ "$REPEAT" -gt 1 ] && echo "; bench: every gate $REPEAT times in round 1")$([ "$FRESH" -eq 1 ] && echo "; round 1 uncached (--fresh)"))"
for ((i = 0; i < N; i++)); do
	log="$OUT/worker_$i.r1.log"
	echo "worker $i (round 1): $(grep -cE ' gate .*: (refused|REACHED|UNPROVEN) in ' "$log") gate(s), $(grep -E ' gate .*: (refused|REACHED|UNPROVEN) in ' "$log" | sed -E 's/.* in ([0-9.]+) s.*/\1/' | awk '{s += $1} END {printf "%.0f", s}') s searching ($(grep -E '^exit=' "$log" | tail -1))"
done
# R7 (b): the evidence set, a fresh process per route (kept for the test).
REL_OUT="build/coop_gates"
case "$OUT" in "$ROOT"/*) REL_OUT="${OUT#"$ROOT"/}" ;; esac
( cd "$ROOT" && EVIDENCE_OUT="$REL_OUT/evidence" bash tools/coop_explore/replay_evidence.sh "$N" > "$OUT/evidence.txt" 2>&1 )
echo "== evidence (R7 b; $(( $(date +%s) - MID )) s): $(tail -1 "$OUT/evidence.txt")"
grep "REACHED the far cell" "$OUT/evidence.txt" | sed 's/^/   /' | cut -c1-200
# R7 (c): the explorer's two seeded passes of 300 s on every gate row that (a) and (b) leave closed.
EXPLORERS="${COOP_GATES_EXPLORERS:-$N}"
if [ "$EXPLORE" -eq 1 ]; then
	XSTART=$(date +%s)
	( cd "$ROOT" && GD_TIMEOUT=300 bash .tools/gd.sh script res://tools/coop_search.gd -- --list 2>/dev/null ) \
		| awk '$1 ~ /^[0-9]+$/ { print $2, $4, ($3 == "Expert" ? 1 : 0) }' > "$OUT/rows_all.txt"
	: > "$OUT/rows_explore.txt"
	skipped=0
	while read -r level gate diff; do
		[ -z "$level" ] && continue
		dname="beginner"; [ "$diff" = "1" ] && dname="expert"
		if cat "$OUT"/worker_*.log 2>/dev/null | grep -qE "GATE $level $dname $gate: open" \
				|| grep -qE "REPLAY $level d$diff $gate: REACHED" "$OUT/evidence.txt"; then
			skipped=$((skipped + 1))   # red already: (a) or (b) opened it
		else
			echo "$level $gate $diff" >> "$OUT/rows_explore.txt"
		fi
	done < "$OUT/rows_all.txt"
	if [ -s "$OUT/rows_explore.txt" ]; then
		( cd "$ROOT" && EXPLORE_OUT="$REL_OUT/passes" bash tools/coop_explore/explore_gates.sh "$REL_OUT/rows_explore.txt" \
			"$EXPLORERS" passes=0,1 > "$OUT/explore.txt" 2>&1 )
	else
		echo "explore_gates: no row to explore" > "$OUT/explore.txt"
	fi
	echo "== explorer (R7 c; $(( $(date +%s) - XSTART )) s on $EXPLORERS process(es); $skipped row(s) red already, not explored): $(tail -1 "$OUT/explore.txt")"
	grep "REACHED the far cell" "$OUT/explore.txt" | sed 's/^/   /' | cut -c1-260
else
	echo "== explorer (R7 c): skipped (--no-explore) - a row without kept passes reads unproven"
fi
( cd "$ROOT" && GD_TIMEOUT="$TMO" bash .tools/gd.sh test coop_gates > "$OUT/test.log" 2>&1 )
code=$?
END=$(date +%s)
echo "== gates (the test, $((END - MID)) s)"
grep -E "^\s+.* gate .*: (refused|REACHED) in |slot-bound" "$OUT/test.log" | sed 's/^ *//'
# The G59 verdict of every gate (DESIGN.md G59, LEVEL_DESIGN.md 15.7.6): the test's own lines when it prints them
# (CoopSearch.verdict_line), else the search tool's table from the cache the workers filled.
grep -E "^\s*GATE " "$OUT/test.log" | sed 's/^ *//' > "$OUT/verdicts.txt"
if [ ! -s "$OUT/verdicts.txt" ]; then
	( cd "$ROOT" && GD_TIMEOUT="$TMO" bash .tools/gd.sh script res://tools/coop_search.gd -- --table 2>&1 ) \
		| grep -E "^GATE " > "$OUT/verdicts.txt"
fi
grep -E "^\s*R7 " "$OUT/test.log" | sed 's/^ *//' > "$OUT/r7_rows.txt"
echo "== the three proofs per row (R7; $OUT/r7_rows.txt): $(grep -c '=> GREEN' "$OUT/r7_rows.txt") green, $(grep -c '=> RED' "$OUT/r7_rows.txt") red, $(grep -c '=> OPEN WORK' "$OUT/r7_rows.txt") open work of $(grep -c '^R7 ' "$OUT/r7_rows.txt") row(s)"
grep -E "=> (RED|OPEN WORK)" "$OUT/r7_rows.txt" | cut -c1-420
echo "== verdicts (G59 + R7; $OUT/verdicts.txt)"
cat "$OUT/verdicts.txt"
count() { grep -cE "^GATE [^:]*: $1" "$OUT/verdicts.txt"; }
echo "== $(count 'refused \(exhaustive\)') refused (exhaustive), $(count 'refused \(bounded\)') refused (bounded), \
$(count 'open') open, $(count 'unproven') unproven of $(grep -c '^GATE ' "$OUT/verdicts.txt") gate(s)"
searched_again="$(grep -E "^\s+.* gate .*: (refused|REACHED) in " "$OUT/test.log" | grep -vc " cached$")"
echo "== $(grep -E 'test_coop_gates.gd' "$OUT/test.log" | tail -1 | sed 's/^ *//')"
echo "== $N worker(s) + the test in $((END - START)) s ($searched_again gate(s) searched again by the test): \
$([ $code -eq 0 ] && echo "every gate refused, with its evidence" || echo "FAILURES (see $OUT/test.log)")"
exit $code

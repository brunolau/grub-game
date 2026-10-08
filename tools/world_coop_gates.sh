#!/usr/bin/env bash
# The co-op gate proofs in parallel: tests/test_coop_gates.gd (the solo-impossibility search of every x2 gate of every
# co-op file on both difficulties, docs/expansion/PLAN.md 8 V3.c) on N processes at once.
# Owner: world-B (PLAN.md 4.1, tools/world_*).
#
#   bash tools/world_coop_gates.sh                N workers = the CPU cores (Godot's thread count / 2, at most 16)
#   bash tools/world_coop_gates.sh 8              8 workers
#   bash tools/world_coop_gates.sh --shards [N]   the old way: N shards of the test itself (COOP_GATES_SHARD=i/N)
#   COOP_GATES_TIMEOUT=2400 bash tools/world_coop_gates.sh     each process's GD_TIMEOUT (default 3600 s)
#
# QUEUE MODE (the default) - two steps:
#  1. N workers `bash .tools/gd.sh script res://tools/coop_search.gd -- --queue=build/coop_gates/queue` share one work
#     queue: each takes the gates dearest first (the cost of their last search, CoopSearch.order_by_cost) and searches
#     only the gates it claims (CoopSearch.claim_gate: an atomic folder per gate), so no worker idles while another
#     still has a long list (the fixed `index % N` split of --shards left shards 415-565 s apart). Every search lands
#     in scripts/world/coop_search.gd's result cache (build/coop_search_cache: keyed by the level file, its base file,
#     gate, difficulty, partner model and the md5 of the simulation's code).
#  2. ONE run of the test (`bash .tools/gd.sh test coop_gates`) asserts every gate: it calls the same search, which
#     reads each result back from the cache ("cached" in its line) - unless a file or the code changed since step 1,
#     then it searches that gate again itself. The test is the verdict; the workers only do the work early.
# Logs: build/coop_gates/worker_<i>.log, build/coop_gates/test.log (or shard_<i>.log). Prints every gate line, the
# verdict and the wall time; exit 0 when the test passed.
#
# Many processes share the machine: run it alone for the timing of PLAN.md V7 (target: about 70 gates x 2
# difficulties in under 20 minutes on this 12-core desktop). The processes share Godot's import cache (gd.sh shared
# runs).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE=queue
if [ "${1:-}" = "--shards" ]; then
	MODE=shards
	shift
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

# Queue mode.
QUEUE="$OUT/queue"
rm -rf "$QUEUE"
rm -f "$OUT"/worker_*.log "$OUT/test.log"
mkdir -p "$QUEUE"
pids=()
for ((i = 0; i < N; i++)); do
	( cd "$ROOT" && GD_TIMEOUT="$TMO" bash .tools/gd.sh script res://tools/coop_search.gd -- \
		--queue=res://build/coop_gates/queue \
		> "$OUT/worker_$i.log" 2>&1; echo "exit=$?" >> "$OUT/worker_$i.log" ) &
	pids+=($!)
	sleep 1   # stagger the starts (each worker reads the gate table and the code fingerprint first)
done
for pid in "${pids[@]}"; do
	wait "$pid"
done
MID=$(date +%s)
echo "== workers ($N, $((MID - START)) s)"
for ((i = 0; i < N; i++)); do
	log="$OUT/worker_$i.log"
	echo "worker $i: $(grep -E '^coop_search: ' "$log" | tail -1) ($(grep -E '^exit=' "$log" | tail -1))"
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

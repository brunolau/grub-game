#!/usr/bin/env bash
# The co-op gate proofs in parallel: tests/test_coop_gates.gd (the solo-impossibility search of every x2 gate of every
# co-op file on both difficulties, docs/expansion/PLAN.md 8 V3.c) split into N shards that run at the same time.
# Owner: world-B (PLAN.md 4.1, tools/world_*).
#
#   bash tools/world_coop_gates.sh            N = half the CPU threads (at most 16)
#   bash tools/world_coop_gates.sh 8          8 shards
#   COOP_GATES_TIMEOUT=2400 bash tools/world_coop_gates.sh 12     each shard's GD_TIMEOUT (default 3600 s)
#
# Shard i runs `COOP_GATES_SHARD=i/N bash .tools/gd.sh test coop_gates` (the test's own split: every N-th gate from i,
# CoopSearch.shard_gates), its log in build/coop_gates/shard_<i>.log. When all are done the script prints each gate's
# line (refused / REACHED, seconds; "cached" results come from scripts/world/coop_search.gd's result cache in
# build/coop_search_cache: a gate whose level, base level and simulation code are unchanged is read back, not searched
# again), each shard's verdict and the wall time. Exit code 0 when every shard passed, 1 otherwise.
#
# Many processes share the machine: run it alone for the timing of PLAN.md V7 (target: about 70 gates x 2 difficulties
# in under 20 minutes on a 12-core desktop). The shards share Godot's import cache (gd.sh shared runs).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THREADS="$(nproc 2>/dev/null || echo 4)"
N="${1:-$(( THREADS / 2 ))}"
[ "$N" -lt 1 ] && N=1
[ "$N" -gt 16 ] && [ $# -eq 0 ] && N=16
TMO="${COOP_GATES_TIMEOUT:-3600}"
OUT="$ROOT/build/coop_gates"
mkdir -p "$OUT"
rm -f "$OUT"/shard_*.log
START=$(date +%s)
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

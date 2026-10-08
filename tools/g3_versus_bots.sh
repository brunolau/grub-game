#!/usr/bin/env bash
# The versus bot proofs in parallel (docs/expansion/PLAN.md 8 V4.b): tests/test_versus_bots.gd split into N shards
# (VERSUS_BOTS_SHARD=i/N: every N-th (arena, mode) set, the mover bake in shard 0), all through .tools/gd.sh at once.
# Owner: integration (G3). Development only.
#
#   bash tools/g3_versus_bots.sh [N]      N shards (default $VERSUS_BOTS_SHARDS, else 8)
#
# Prints every shard's log one after the other (the (arena, mode) lines, the human-only skip lines of G50, the
# failures), then one summary in the test runner's own words - "TESTS: <passed> passed, <failed> failed" and
# "RESULT: PASS|FAIL" - so tools/g3.sh reads the merged output like a single run of the module. Each shard's
# GD_TIMEOUT is $VERSUS_BOTS_TIMEOUT (default 3600 s). Logs: build/g3/versus_bots_shards/shard_<i>.log.
# Exit code: 0 when every shard passed.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
N="${1:-${VERSUS_BOTS_SHARDS:-8}}"
case "$N" in '' | *[!0-9]*) echo "g3_versus_bots.sh: N must be a number" >&2; exit 2 ;; esac
[ "$N" -ge 1 ] || { echo "g3_versus_bots.sh: N must be >= 1" >&2; exit 2; }
DIR="build/g3/versus_bots_shards"
mkdir -p "$DIR"
rm -f "$DIR"/shard_*.log
started=$(date +%s)
for ((i = 0; i < N; i++)); do
	VERSUS_BOTS_SHARD="$i/$N" GD_TIMEOUT="${VERSUS_BOTS_TIMEOUT:-3600}" bash .tools/gd.sh test versus_bots \
		>"$DIR/shard_$i.log" 2>&1 &
	sleep 1
done
wait
passed=0
failed=0
ok=1
for ((i = 0; i < N; i++)); do
	log="$DIR/shard_$i.log"
	echo "=== shard $i/$N"
	grep -vE '^(TESTS|RESULT):' "$log"
	p="$(sed -n 's/^TESTS: \([0-9]*\) passed.*/\1/p' "$log" | tail -1)"
	f="$(sed -n 's/^TESTS: [0-9]* passed, \([0-9]*\) failed.*/\1/p' "$log" | tail -1)"
	if [ -z "$p" ] || grep -q "gd.sh: TIMEOUT" "$log"; then
		echo "=== shard $i/$N: no result (crash or timeout)"
		ok=0
		f=$((${f:-0} + 1))
		p=${p:-0}
	fi
	grep -q "^RESULT: PASS" "$log" || ok=0
	passed=$((passed + p))
	failed=$((failed + ${f:-0}))
done
echo "g3_versus_bots.sh: $N shard(s) in $(($(date +%s) - started)) s"
echo "TESTS: $passed passed, $failed failed, $N shard(s)"
if [ "$ok" = 1 ] && [ "$failed" = 0 ]; then
	echo "RESULT: PASS"
	exit 0
fi
echo "RESULT: FAIL"
exit 1

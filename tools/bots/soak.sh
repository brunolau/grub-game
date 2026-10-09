#!/usr/bin/env bash
# The versus soak in parallel (docs/expansion/PLAN.md 7 P4.1: "versus soak (bots, 1 000 seeded rounds per mode,
# headless)"): tools/bots/soak.gd in N processes (shard i/N = every N-th round of the plan), summed. Seeded rounds
# with CPUs on every seat over every (mode, arena that lists it, 2 / 3 / 4 players), the real heroes and the real
# referee; what is checked on every tick is in the header of tools/bots/soak_runner.gd. Owner: versus (phase 4).
# Development only.
#
#   bash tools/bots/soak.sh [tag=soak] [rounds per mode=1000] [processes=16] [extra args of soak.gd ...]
#   bash tools/bots/soak.sh p4                       the 4 x 1 000 rounds of P4.1 (about 12 minutes on 16 processes)
#   bash tools/bots/soak.sh mix 250 16 rules=mix     presets, variants, Stock, the sudden-death event, 2v2 from the seed
#   bash tools/bots/soak.sh two 1000 16 first=1000   a second, different thousand per mode
#
# Prints the cell table, every ANOMALY line (each names mode, arena, players, seed and round: replay it alone with
#   bash .tools/gd.sh script res://tools/bots/soak.gd -- mode=<m> arena=<a> players=<n> seed=<s> round=<r> detail=1),
# a `NET` line for every round in which one of the referee's two nets fired (squeezed_out: a hero knocked out outside
# the arena's side; wedged_coconuts: a coconut freed from a wall - DESIGN.md G93; counted, not anomalies),
# one `SOAKSUM mode=...` line per mode (rounds, ticks, the longest round and where, how the rounds ended), and
# `SOAKTOTAL ... RESULT PASS|FAIL`. FAIL: an anomaly, an engine error line in a log, or a shard that did not finish
# (crash, timeout). Logs: build/bots_soak/soak_<tag>_<i>.log. Exit code 0 = PASS.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TAG="${1:-soak}"; ROUNDS="${2:-1000}"; N="${3:-16}"
shift $(($# < 3 ? $# : 3))
LOGS="$ROOT/build/bots_soak"
mkdir -p "$LOGS"
rm -f "$LOGS/soak_${TAG}_"*.log
started=$(date +%s)
pids=()
for ((i = 0; i < N; i++)); do
	( GD_TIMEOUT="${GD_TIMEOUT:-5400}" bash "$ROOT/.tools/gd.sh" script res://tools/bots/soak.gd -- \
		"rounds=$ROUNDS" "shard=$i/$N" "$@" > "$LOGS/soak_${TAG}_$i.log" 2>&1 ) &
	pids+=($!)
done
for pid in "${pids[@]}"; do wait "$pid"; done
grep -h "^CELL" "$LOGS/soak_${TAG}_0.log"
grep -h "^ANOMALY" "$LOGS/soak_${TAG}_"*.log
# The referee's two nets at work (a hero squeezed out of the arena's side, a wedged coconut): not anomalies, but named.
grep -h "^NET" "$LOGS/soak_${TAG}_"*.log
# Engine errors outside a round (a script that does not compile, an autoload that did not start) reach no ANOMALY line.
loose="$(grep -lE "SCRIPT ERROR|^ERROR:|gd.sh: TIMEOUT" "$LOGS/soak_${TAG}_"*.log 2>/dev/null | wc -l)"
done_count="$(grep -h "^SOAKDONE" "$LOGS/soak_${TAG}_"*.log | wc -l)"
grep -h "^SOAK mode=" "$LOGS/soak_${TAG}_"*.log | awk -v tag="$TAG" '
{
	mode = ""; at = ""; longest = 0
	for (k = 1; k <= NF; k++) {
		split($k, kv, "=")
		if (kv[1] == "mode") mode = kv[2]
		else if (kv[1] == "rounds") rounds[mode] += kv[2]
		else if (kv[1] == "ticks") ticks[mode] += kv[2]
		else if (kv[1] == "play") play[mode] += kv[2]
		else if (kv[1] == "longest") longest = kv[2]
		else if (kv[1] == "at") at = kv[2]
		else if (kv[1] == "golden_max") { if (kv[2] + 0 > golden[mode] + 0) golden[mode] = kv[2] }
		else if (kv[1] == "idle_max") { if (kv[2] + 0 > idle[mode] + 0) idle[mode] = kv[2] }
		else if (kv[1] == "anomalies") anomalies[mode] += kv[2]
		else if (kv[1] == "squeezed") squeezed[mode] += kv[2]
		else if (kv[1] == "wedged") wedged[mode] += kv[2]
		else if (kv[1] == "ends") {
			n = split(kv[2], parts, ",")
			for (j = 1; j <= n; j++) { split(parts[j], e, ":"); ends[mode "," e[1]] += e[2]; kinds[e[1]] = 1 }
		}
	}
	if (longest + 0 > best[mode] + 0) { best[mode] = longest; where[mode] = at }
	if (!(mode in order)) { order[mode] = ++count; names[count] = mode }
}
END {
	for (i = 1; i <= count; i++) {
		m = names[i]
		line = ""
		for (kind in kinds) if ((m "," kind) in ends) line = line (line == "" ? "" : ",") kind ":" ends[m "," kind]
		printf "SOAKSUM %s mode=%s rounds=%d ticks=%d play=%d mean=%.0f longest=%d at=%s ends=%s golden_max=%d idle_max=%d squeezed=%d wedged=%d anomalies=%d\n", tag, m, rounds[m], ticks[m], play[m], play[m] / (rounds[m] > 0 ? rounds[m] : 1), best[m], where[m], line, golden[m], idle[m], squeezed[m], wedged[m], anomalies[m]
		all_rounds += rounds[m]; all_ticks += ticks[m]; all_anomalies += anomalies[m]
		if (best[m] + 0 > top + 0) { top = best[m]; top_at = m "/" where[m] }
	}
	printf "SOAKTOTAL %s rounds=%d ticks=%d longest=%d at=%s anomalies=%d", tag, all_rounds, all_ticks, top, top_at, all_anomalies
}'
anomalies="$(grep -h "^ANOMALY" "$LOGS/soak_${TAG}_"*.log | wc -l)"
echo " shards=$done_count/$N logs_with_engine_errors=$loose seconds=$(($(date +%s) - started))"
if [ "$anomalies" -eq 0 ] && [ "$loose" -eq 0 ] && [ "$done_count" -eq "$N" ]; then
	echo "SOAKTOTAL $TAG RESULT PASS"
	exit 0
fi
echo "SOAKTOTAL $TAG RESULT FAIL ($anomalies anomaly line(s), $loose log(s) with engine errors, $done_count of $N shards finished)"
exit 1

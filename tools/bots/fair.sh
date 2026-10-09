#!/usr/bin/env bash
# The spawn fairness of one (arena, mode) bot set over many seeds, in parallel processes, summed (docs/expansion/PLAN.md
# 8 V4.b, DESIGN.md G80: a fairness claim is made on at least 384 rounds - 96 seeds x 4 rounds; the 48-round sets of
# tests/test_versus_bots.gd are the regression pin). Written by the versus builder in wf11, versioned by the G3c
# integration. Development only.
#   bash tools/bots/fair.sh <tag> <arena> <mode> <first seed index> <seeds> [seeds per process=3] [extra args]
#   bash tools/bots/fair.sh sky arena_sky_picnic grub_stack 0 96        the 384 rounds of a fairness claim
# Seeds are indices into fair_runner.gd's SEEDS (0-11 = the test's own twelve). Logs: build/bots_fair/fair_<tag>_*.log
# Prints `SUM <tag>: <arena> <mode>, <n> rounds, wins per spawn ...; fair share ..., worst spread <points> points`,
# and before it an `ERRORS <tag>: ...` line when a process logged an engine error (the measurement is void then).
# A variant of an arena file is measured without touching the shipped one - the extra arguments of fair_runner.gd:
#   bash tools/bots/fair.sh try arena_sky_picnic grub_stack 0 96 5 "file=res://build/x/arena_sky_picnic.lvl graph=res://build/x/arena_sky_picnic.json"
# Seed indices 96-191 are a second, independent set of 96 (a claim made on 0-95 is confirmed on them).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TAG="$1"; ARENA="$2"; MODE="$3"; FROM="$4"; COUNT="$5"; PER="${6:-3}"; EXTRA="${7:-}"
LOGS="$ROOT/build/bots_fair"
mkdir -p "$LOGS"
rm -f "$LOGS/fair_${TAG}_"*.log
pids=()
i="$FROM"
end=$((FROM + COUNT))
while [ "$i" -lt "$end" ]; do
	n="$PER"
	[ $((i + n)) -gt "$end" ] && n=$((end - i))
	( GD_TIMEOUT="${GD_TIMEOUT:-1800}" bash "$ROOT/.tools/gd.sh" script res://tools/bots/fair.gd -- \
		"arena=$ARENA" "mode=$MODE" "range=$i:$n" $EXTRA > "$LOGS/fair_${TAG}_$i.log" 2>&1 ) &
	pids+=($!)
	i=$((i + n))
done
for pid in "${pids[@]}"; do wait "$pid"; done
# A process that logged an engine error (a script another hand was editing, a missing autoload) did not play the game
# as it is: its rounds count for nothing. Say so before the sums.
bad="$(grep -lE "SCRIPT ERROR|^ERROR:|gd.sh: TIMEOUT" "$LOGS/fair_${TAG}_"*.log 2>/dev/null | wc -l)"
[ "$bad" -gt 0 ] && echo "ERRORS $TAG: $bad of ${#pids[@]} processes logged an engine error or timed out - this measurement is void (logs: build/bots_fair/fair_${TAG}_*.log)"
grep -h "^STAT" "$LOGS/fair_${TAG}_"*.log | awk '{ sp = $2; for (k = 3; k <= NF; k++) { split($k, kv, "="); sum[sp " " kv[1]] += kv[2]; names[kv[1]] = k } } END { for (s = 1; s <= 4; s++) { line = "STATSUM spawn " s ":"; n = split("food stolen dropped hits hurts bonks deaths picked best_stack", order, " "); for (i = 1; i <= n; i++) line = line " " order[i] "=" sum["spawn=" s " " order[i]]; print line } }'
grep -h "^FAIR" "$LOGS/fair_${TAG}_"*.log | awk -v tag="$TAG" '
{
	for (k = 1; k <= NF; k++) {
		if ($k ~ /^rounds=/) { sub("rounds=", "", $k); rounds += $k }
		if ($k ~ /^wins=/) { sub("wins=", "", $k); split($k, w, ","); for (j = 1; j <= 4; j++) wins[j] += w[j] }
		if ($k ~ /^scores=/) { sub("scores=", "", $k); split($k, s, ","); for (j = 1; j <= 4; j++) scores[j] += s[j] }
		if ($k ~ /^draws=/) { sub("draws=", "", $k); draws += $k }
		if ($k ~ /^shared=/) { sub("shared=", "", $k); shared += $k }
		if ($k ~ /^unfinished=/) { sub("unfinished=", "", $k); unfinished += $k }
		if ($k ~ /^idle=/) { sub("idle=", "", $k); if ($k > idle) idle = $k }
	}
	name = $2 " " $3
}
END {
	if (rounds == 0) { print "SUM " tag ": no FAIR line"; exit 1 }
	total = wins[1] + wins[2] + wins[3] + wins[4]
	mean = total / 4 / rounds * 100
	worst = 0
	line = ""
	for (j = 1; j <= 4; j++) {
		share = wins[j] / rounds * 100
		d = share - mean; if (d < 0) d = -d
		if (d > worst) worst = d
		line = line sprintf(" %d:%.1f%% (%d wins, score %.1f)", j, share, wins[j], scores[j] / rounds)
	}
	printf "SUM %s: %s, %d rounds, wins per spawn%s; fair share %.1f%%, worst spread %.1f points; draws %d, shared %d, unfinished %d, worst idle %d\n", tag, name, rounds, line, mean, worst, draws, shared, unfinished, idle
}'

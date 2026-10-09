#!/usr/bin/env bash
# The exact reset's check over a gate list (tools/coop_explore/exact.gd; wf11, R7: "a found route always replays in a
# fresh process"). Owner: world-B. For every gate row of the list it runs the check TWICE in two processes with two
# play orders (order=1 with audit=1, order=2 without): each process must find every route on its first trajectory
# whatever was played before it, and the two processes must print the same digest - the first route of each starts
# from the world a fresh process builds, so equal digests mean "the same route does the same thing in any process".
#
#   bash tools/coop_explore/exact.sh                      the default rows (one of every mechanism: plates, bonded keepers,
#                                                         a pulley, see-saws and caps, drums, a boulder, vines, followers)
#   bash tools/coop_explore/exact.sh <list> [P] [key=value ...]
#       <list>   a file of `<level> <gate> <0|1>` lines, or `all` (every row of the gate table)
#       P        processes at once (default 6)
#       key=value   passed on to exact.gd (whole=1 the whole level as the explorer plays it, runs=, rounds=, ticks=)
#   EXACT_OUT=build/coop_explore/exact bash ...           where the logs go
# Prints one line per row (`ok` / `NOT EXACT` with the reason) and the count; exit 0 when every row is exact.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 2
LIST="${1:-default}"
P="${2:-6}"
[ $# -gt 0 ] && shift
[ $# -gt 0 ] && shift
EXTRA="$*"
OUT="${EXACT_OUT:-build/coop_explore/exact}"
mkdir -p "$OUT"
ROWS="$OUT/rows.txt"
if [ "$LIST" = "default" ]; then
	cat > "$ROWS" <<'EOF'
w1_l1_coop plates 0
w2_l2_coop seesaw 1
w4_l1_coop boulder 1
w4_l2_coop drums 1
w5_l2_coop rattlers 0
w6_l2_coop caps 0
w7_l1_coop stack 1
w9_l1_coop pulley 1
w9_l2_coop brace 1
EOF
elif [ "$LIST" = "all" ]; then
	GD_TIMEOUT=300 bash .tools/gd.sh script res://tools/coop_search.gd -- --list 2>/dev/null \
		| awk '$1 ~ /^[0-9]+$/ { print $2, $4, ($3 == "Expert" ? 1 : 0) }' > "$ROWS"
else
	grep -v '^[[:space:]]*$' "$LIST" > "$ROWS"
fi
while read -r level gate diff; do
	[ -z "$level" ] && continue
	for order in 1 2; do
		while [ "$(jobs -rp | wc -l)" -ge "$P" ]; do wait -n 2>/dev/null || sleep 1; done
		audit=""
		[ "$order" = "1" ] && audit="audit=1 report=1"
		( GD_TIMEOUT="${EXACT_TIMEOUT:-1800}" bash .tools/gd.sh script res://tools/coop_explore/main.gd -- exact "$level" "$gate" "$diff" \
			order="$order" $audit $EXTRA > "$OUT/${level}__${gate}__${diff}.o$order.log" 2>&1 ) &
		sleep 1
	done
done < "$ROWS"
wait
bad=0; total=0
while read -r level gate diff; do
	[ -z "$level" ] && continue
	total=$((total + 1))
	a="$(grep -h '^EXACT ' "$OUT/${level}__${gate}__${diff}.o1.log" | tail -1)"
	b="$(grep -h '^EXACT ' "$OUT/${level}__${gate}__${diff}.o2.log" | tail -1)"
	da="${a##*digest }"; db="${b##*digest }"
	why=""
	[ -z "$a" ] || [ -z "$b" ] && why="no result (see the logs)"
	[ -z "$why" ] && { echo "$a" | grep -q ", 0 play(s) off their first trajectory, 0 entities left changed by a reset, 0 changed without a tick" || why="order 1: $a"; }
	[ -z "$why" ] && { echo "$b" | grep -q ", 0 play(s) off their first trajectory, 0 entities left changed by a reset, 0 changed without a tick" || why="order 2: $b"; }
	[ -z "$why" ] && [ "$da" != "$db" ] && why="the two processes differ (digest $da / $db)"
	if [ -n "$why" ]; then
		bad=$((bad + 1))
		printf '%-34s NOT EXACT - %s\n' "$level $gate $diff" "$why"
	else
		printf '%-34s ok   %s\n' "$level $gate $diff" "$(echo "$a" | sed -E 's/^EXACT [^:]*: //; s/; digest.*//' | cut -c1-150)"
	fi
done < "$ROWS"
echo "exact: $((total - bad)) of $total gate world(s) exact ($OUT)"
[ "$bad" -eq 0 ]

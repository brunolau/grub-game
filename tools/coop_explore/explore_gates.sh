#!/usr/bin/env bash
# R7 (c) - THE CONTINUOUS-PLAY EXPLORER on every gate row of a list, P processes at once (tools/coop_explore/
# explorer.gd; docs/expansion/DESIGN.md G77: "the explorer opens it in none of two seeded passes of 300 s per gate
# row over the whole level"). Owner: world-B (PLAN.md 4.1). The G3b verifier's explore_run.sh, adopted in wf11.
#
#   bash tools/coop_explore/explore_gates.sh <list> [P] [key=value ...]
#       <list>   a file of `<level> <gate> <0|1>` lines (0 = Beginner, 1 = Expert), or `all`: every row of the gate
#                table (tools/coop_search.gd --list)
#       P        processes at once (default 12)
#       passes=0,1      R7's two passes, each row with its own seed (harness.gd row_seed) and 300 s; every result is
#                       kept for the gate test and read back when nothing changed (the default)
#       seed=<n> seconds=<s>   instead: ONE pass with seed n + the row's number and s seconds (nothing kept)
#       anything else   passed on to the explorer (nothrow=1, noplace=1, maxt=, fresh=1 ...)
#   EXPLORE_OUT=build/coop_explore/passes bash ...     where the logs and the found routes go
# Per row and pass: <out>/<level>__<gate>__<d>.p<pass>.log, and a found route as <out>/found_<level>__<gate>__<d>.p<pass>.txt
# (a route file: replay it with `bash .tools/gd.sh script res://tools/coop_explore/main.gd -- replay <file> trace=20`).
# Prints one line per row and pass and the count; exit 0 = no row opened, 1 = a row was REACHED, 2 = bad arguments.
# Time: rows x passes x seconds / P - the 76 rows x 2 x 300 s are 38 minutes on 20 processes, 63 on 12.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 2
LIST="${1:-}"
[ -z "$LIST" ] && { sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 2; }
shift
P=12
if [ $# -gt 0 ] && [ "${1#*=}" = "$1" ]; then P="$1"; shift; fi
PASSES="0,1"; SEED=""; SECONDS_EACH=""; EXTRA=()
for arg in "$@"; do
	case "$arg" in
		passes=*) PASSES="${arg#passes=}" ;;
		seed=*) SEED="${arg#seed=}" ;;
		seconds=*) SECONDS_EACH="${arg#seconds=}" ;;
		*) EXTRA+=("$arg") ;;
	esac
done
OUT="${EXPLORE_OUT:-build/coop_explore/passes}"
mkdir -p "$OUT"
ROWS="$OUT/rows.txt"
if [ "$LIST" = "all" ]; then
	GD_TIMEOUT=300 bash .tools/gd.sh script res://tools/coop_search.gd -- --list 2>/dev/null \
		| awk '$1 ~ /^[0-9]+$/ { print $2, $4, ($3 == "Expert" ? 1 : 0) }' > "$ROWS"
else
	[ -f "$LIST" ] || { echo "explore_gates: no list $LIST"; exit 2; }
	grep -v '^[[:space:]]*$' "$LIST" > "$ROWS.tmp" && mv "$ROWS.tmp" "$ROWS"
fi
total_rows="$(grep -c . "$ROWS")"
[ "$total_rows" -gt 0 ] || { echo "explore_gates: the list is empty"; exit 2; }
if [ -n "$SEED" ]; then PASS_LIST="s"; else PASS_LIST="${PASSES//,/ }"; fi
START=$(date +%s)
n=0
for pass in $PASS_LIST; do
	n=0
	while read -r level gate diff; do
		[ -z "$level" ] && continue
		n=$((n + 1))
		while [ "$(jobs -rp | wc -l)" -ge "$P" ]; do wait -n 2>/dev/null || sleep 1; done
		tag="${level}__${gate}__${diff}.p${pass}"
		if [ "$pass" = "s" ]; then
			args=(seed=$((SEED + n)) seconds="${SECONDS_EACH:-300}")
		else
			args=(pass="$pass")
			[ -n "$SECONDS_EACH" ] && args+=(seconds="$SECONDS_EACH")
		fi
		(
			GD_TIMEOUT=$(( ${SECONDS_EACH:-300} + 900 )) bash .tools/gd.sh script res://tools/coop_explore/main.gd -- explore \
				"$level" "$gate" "$diff" "${args[@]}" "out=res://$OUT/found_$tag.txt" ${EXTRA[@]+"${EXTRA[@]}"} \
				> "$OUT/$tag.log" 2>&1
			echo "rc=$?" >> "$OUT/$tag.log"
		) &
		sleep 1
	done < "$ROWS"
done
wait
reached=0; silent=0; missing=0
for pass in $PASS_LIST; do
	while read -r level gate diff; do
		[ -z "$level" ] && continue
		tag="${level}__${gate}__${diff}.p${pass}"
		line="$(grep -h "^EXPLORE .*: \(REACHED\|NOT reached\)" "$OUT/$tag.log" 2>/dev/null | tail -1)"
		case "$line" in
			*"REACHED the far cell"*) reached=$((reached + 1)); printf '%-40s %s\n' "$tag" "$(echo "$line" | cut -c1-210)  [$OUT/found_$tag.txt]" ;;
			*"NOT reached"*) silent=$((silent + 1)); printf '%-40s %s\n' "$tag" "$(echo "$line" | sed -E 's/^EXPLORE [^:]*: //' | cut -c1-170)" ;;
			*) missing=$((missing + 1)); printf '%-40s %s\n' "$tag" "NO RESULT (see $OUT/$tag.log)" ;;
		esac
	done < "$ROWS"
done
echo "explore_gates: $total_rows row(s), pass(es) $PASS_LIST: $reached REACHED, $silent not reached, $missing without a result; $(( $(date +%s) - START )) s on $P process(es) ($OUT)"
[ "$missing" -eq 0 ] || exit 2
[ "$reached" -eq 0 ]

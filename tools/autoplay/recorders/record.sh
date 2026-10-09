#!/usr/bin/env bash
# RE-RECORD A CO-OP ROUTE with the recorder it was last made with (docs/expansion/PLAN.md 7, wf12; owner: world-B for
# the kit, the level designers for the bots). Every two-stream route under tools/autoplay/routes/ was played by a
# closed-loop pair bot (or a macro script) of its level's designer; until wf12 those lived unversioned under build/.
# They are kept here as they were (the folder of each designer under this one), with one line per route file in
# routes.txt: its probe, its bot or macro script, its difficulty and the bot's own arguments.
#
#   bash tools/autoplay/recorders/record.sh <route file>            e.g. w2_l2_coop.expert.inputs
#   bash tools/autoplay/recorders/record.sh <route file> --land     ... and put the recording's body under the route
#                                                                   file's own header lines (its pins stay)
#   bash tools/autoplay/recorders/record.sh --list                  the table: every route file and its command
#   bash tools/autoplay/recorders/record.sh --all [P]               every route, P at once (default 6): the check
#                                                                   of the whole kit on today's tree
#   RECORD_OUT=build/recorders ...                                  where recordings and logs go (default)
#   RECORD_LIMIT=9000 ...                                           the bot's tick limit
#
# A recording goes to <out>/<route file>, its log to <out>/<route file>.log, and the line says how its BODY (the
# key lines, no comment) compares with the versioned route:
#   IDENTICAL   byte for byte - the recorder still makes this route on today's tree
#   DIFFERENT   the bot played another route (the simulation, the level or the bot changed since): replay it with
#               the route proofs before landing it (`bash .tools/gd.sh test coop_routes`), and name it in the header
#   FAILED      the bot did not end the stage or the recorder did not run (see the log)
# Exit code 0 = identical, 1 = different, 2 = failed or bad arguments.
#
# What a route needs when it is recorded anew (integration's proofs read the header, not this folder): the header's
# `# route:` line with its pins, both players' streams (`ticks:KEYS|KEYS`), club only where the header says so.
# The recorders are development tools: nothing here is loaded by the game or exported (BUILD.md export filters).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
KIT="tools/autoplay/recorders"
TABLE="$ROOT/$KIT/routes.txt"
ROUTES="tools/autoplay/routes"
OUT="${RECORD_OUT:-build/recorders}"
LIMIT="${RECORD_LIMIT:-9000}"
cd "$ROOT" || exit 2

body_md5() { grep -v '^#' "$1" | grep -v '^[[:space:]]*$' | tr -d '\r' | md5sum | cut -d' ' -f1; }
body_ticks() { grep -v '^#' "$1" | tr ',' '\n' | sed -E 's/^([0-9]+):.*/\1/' | awk '/^[0-9]+$/ { s += $1 } END { print s + 0 }'; }

command_of() {
	# The recorder's command for a table line (shown by --list, run by record_one).
	local route="$1" kind="$2" probe="$3" script="$4" mode="$5" extra="$6" level
	level="$(head -1 "$ROUTES/$route" | sed -E 's/.*level=([A-Za-z0-9_]+).*/\1/')"
	if [ "$kind" = "rec" ]; then
		echo "bash .tools/gd.sh script res://$KIT/$probe -- --level=res://levels/$level.lvl --rec=res://$KIT/$script --dir=res://$OUT/ --every=1000000 --quiet $extra"
	else
		echo "bash .tools/gd.sh script res://$KIT/$probe -- --level=res://levels/$level.lvl --start=$level --bot=res://$KIT/$script --players=2 --mode=$mode --limit=$LIMIT --out=res://$OUT/$route --every=0 --quiet $extra"
	fi
}

record_one() {
	local route="$1" land="${2:-}" line kind probe script mode extra cmd made
	line="$(awk -F'	' -v route="$route" '$1 == route' "$TABLE")"
	if [ -z "$line" ] || [ ! -f "$ROUTES/$route" ]; then
		echo "record: $route is not in $KIT/routes.txt (or not under $ROUTES)"
		return 2
	fi
	IFS=$'\t' read -r _ kind probe script mode extra <<< "$line"
	cmd="$(command_of "$route" "$kind" "$probe" "$script" "$mode" "$extra")"
	mkdir -p "$OUT"
	rm -f "$OUT/$route"
	made="$OUT/$route"
	GD_TIMEOUT="${GD_TIMEOUT:-900}" bash -c "$cmd" > "$OUT/$route.log" 2>&1
	if [ "$kind" = "rec" ]; then
		# A macro script names its own file (`out:`): the recorder wrote that one into the folder.
		local named
		named="$(grep -m1 '^out:' "$KIT/$script" | sed -E 's/^out:[[:space:]]*//' | tr -d '\r')"
		[ -n "$named" ] && [ "$named" != "$route" ] && [ -f "$OUT/$named" ] && mv "$OUT/$named" "$OUT/$route"
	fi
	if [ ! -s "$made" ]; then
		echo "FAILED     $route - no recording (see $OUT/$route.log: $(grep -E 'SCRIPT ERROR|Parse Error|BOT END|REC' "$OUT/$route.log" | tail -1 | cut -c1-140))"
		return 2
	fi
	local verdict="DIFFERENT" code=1
	if [ "$(body_md5 "$made")" = "$(body_md5 "$ROUTES/$route")" ]; then
		verdict="IDENTICAL"
		code=0
	fi
	echo "$verdict  $route - $(body_ticks "$made") ticks recorded, the versioned route $(body_ticks "$ROUTES/$route") ($made)"
	if [ "$land" = "--land" ] && [ "$code" -ne 0 ]; then
		{ grep '^#' "$ROUTES/$route"; grep -v '^#' "$made" | grep -v '^[[:space:]]*$'; } | tr -d '\r' > "$OUT/$route.landed"
		cp "$OUT/$route.landed" "$ROUTES/$route"
		echo "           landed under the route file's own header: now prove it (bash .tools/gd.sh test coop_routes) and say in a comment line how it was recorded"
	fi
	return "$code"
}

case "${1:-}" in
	"" | -h | --help)
		sed -n '2,29p' "${BASH_SOURCE[0]}"
		exit 2
		;;
	--list)
		while IFS=$'\t' read -r route kind probe script mode extra; do
			case "$route" in "" | \#*) continue ;; esac
			printf '%-28s %s\n' "$route" "$(command_of "$route" "$kind" "$probe" "$script" "$mode" "$extra")"
		done < "$TABLE"
		;;
	--all)
		P="${2:-6}"
		mkdir -p "$OUT"
		: > "$OUT/all.txt"
		while IFS=$'\t' read -r route _; do
			case "$route" in "" | \#*) continue ;; esac
			while [ "$(jobs -rp | wc -l)" -ge "$P" ]; do wait -n 2>/dev/null || sleep 1; done
			( record_one "$route" >> "$OUT/all.txt" 2>&1 ) < /dev/null &
			sleep 0.5
		done < "$TABLE"
		wait
		sort -k2 "$OUT/all.txt"
		echo "record: $(grep -c '^IDENTICAL' "$OUT/all.txt") identical, $(grep -c '^DIFFERENT' "$OUT/all.txt") different, $(grep -c '^FAILED' "$OUT/all.txt") failed of $(grep -vc '^[[:space:]]' "$OUT/all.txt") route(s) ($OUT/all.txt)"
		! grep -q '^\(DIFFERENT\|FAILED\)' "$OUT/all.txt"
		;;
	*)
		record_one "$1" "${2:-}"
		;;
esac

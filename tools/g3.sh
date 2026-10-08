#!/usr/bin/env bash
# Gate G3 bookkeeping (docs/expansion/PLAN.md 6.2 "Gate G3", 8 V1-V7). Owner: integration. Development only.
#
#   bash tools/g3.sh [--shards=N] [--jobs=J] [--only=a,b] [--skip=a,b] [--require] [--report=<run dir>]
#
# ONE command for the gate: every slow module - test_coop_gates sharded over N processes (COOP_GATES_SHARD=i/N) -
# beside the default suite, the single-player identity check (tools/sp_identity.sh), the G3 content inventory
# (tests/test_integration_g3.gd) and the campaign flows headless (scripts/core/dev/headless_flow.gd), all through
# .tools/gd.sh, at most J at once (sp_identity counts as one job; it starts four Godot runs itself). Then it prints the
# G3 table: the content rows (Book II files, co-op files, route cells, featured routes, paintings, x2 gates, arenas)
# and one verdict per proof (tests passed / failed, gates refused / reached, (arena, mode) bot cells, identity, flow
# checks and PENDING parts).
#
# Jobs (names for --only / --skip): inventory, default, campaign_routes, book2_routes, coop_routes, coop_gates (all
# shards), versus_bots, sp_identity, flow_campaign, flow_campaign_beginner, flow_campaign_b2, flow_campaign_coop.
#   --shards=N     coop_gates shards (default $G3_SHARDS, else 8)
#   --jobs=J       jobs at once (default $G3_JOBS, else 12)
#   --require      G3 itself (G3_REQUIRE=1 for every job): the inventory rows, every Expert route cell, the campaign
#                  runs of the route modules and every `need` of the campaign flows must be complete
#   --report=DIR   print the table from the logs of an earlier run dir (build/g3/run_<tag>); nothing is run
# Each Godot run is limited by GD_TIMEOUT (set per job below); never wrap this script or gd.sh in an outer `timeout`
# (its SIGTERM skips gd.sh's cleanup and leaves the shared import lock behind, wf9_db3_to_integration.txt).
# Output: build/g3/run_<tag>/<job>.log (tag: $G3_TAG, else the date and the pid), <job>.rc / .secs, and the table in
# <run dir>/g3_table.txt. Exit code: 0 = every proof green (with --require also the content complete), 1 = something
# red or open, 2 = usage.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

SHARDS="${G3_SHARDS:-8}"
MAXJOBS="${G3_JOBS:-12}"
ONLY=""
SKIP=""
REQUIRE=0
REPORT=""
for arg in "$@"; do
	case "$arg" in
		--shards=*) SHARDS="${arg#--shards=}" ;;
		--jobs=*) MAXJOBS="${arg#--jobs=}" ;;
		--only=*) ONLY=",${arg#--only=}," ;;
		--skip=*) SKIP=",${arg#--skip=}," ;;
		--require) REQUIRE=1 ;;
		--report=*) REPORT="${arg#--report=}" ;;
		-h | --help) sed -n 2,26p "$0"; exit 0 ;;
		*) echo "g3.sh: unknown option $arg (see --help)" >&2; exit 2 ;;
	esac
done
case "$SHARDS$MAXJOBS" in *[!0-9]*) echo "g3.sh: --shards and --jobs take numbers" >&2; exit 2 ;; esac
[ "$SHARDS" -ge 1 ] && [ "$MAXJOBS" -ge 1 ] || { echo "g3.sh: --shards and --jobs must be >= 1" >&2; exit 2; }

FLOWS=(campaign campaign_beginner campaign_b2 campaign_coop)
GD=".tools/gd.sh"

wanted() {
	local job="$1" group="$1"
	case "$job" in coop_gates_*) group="coop_gates" ;; esac
	[ -n "$ONLY" ] && [[ "$ONLY" != *",$group,"* ]] && return 1
	[ -n "$SKIP" ] && [[ "$SKIP" == *",$group,"* ]] && return 1
	return 0
}

# --- Run ---------------------------------------------------------------------------------------------------------
if [ -n "$REPORT" ]; then
	RUN="$REPORT"
	[ -d "$RUN" ] || { echo "g3.sh: no run dir $RUN" >&2; exit 2; }
else
	TAG="${G3_TAG:-$(date +%Y%m%d_%H%M%S)_$$}"
	RUN="build/g3/run_${TAG//[^A-Za-z0-9_-]/_}"
	mkdir -p "$RUN"
	declare -A CMD=()
	ORDER=()
	add() { wanted "$1" || return 0; CMD[$1]="$2"; ORDER+=("$1"); }
	# Longest first: the gate search, the bots, the suite, the co-op campaign flow.
	for ((i = 0; i < SHARDS; i++)); do
		add "coop_gates_$i" "COOP_GATES_SHARD=$i/$SHARDS GD_TIMEOUT=7200 bash $GD test coop_gates"
	done
	add versus_bots "GD_TIMEOUT=5400 bash $GD test versus_bots"
	add default "GD_TIMEOUT=2400 bash $GD test"
	for flow in campaign_coop campaign_b2 campaign campaign_beginner; do
		add "flow_$flow" "GD_TIMEOUT=5400 bash $GD script res://scripts/core/dev/headless_flow.gd -- \
--flow=tools/autoplay/$flow.flow --fast --fresh-user --user-dir=res://$RUN/user_$flow --out=g3_$flow"
	done
	add sp_identity "SP_ID_TAG=g3_${TAG//[^A-Za-z0-9_-]/_} bash tools/sp_identity.sh"
	add campaign_routes "GD_TIMEOUT=3600 bash $GD test campaign_routes"
	add book2_routes "GD_TIMEOUT=3600 bash $GD test book2_routes"
	add coop_routes "GD_TIMEOUT=3600 bash $GD test coop_routes"
	add inventory "G3_REQUIRE=$REQUIRE GD_TIMEOUT=600 bash $GD test integration_g3"
	# --require: every job demands the finished content (inventory rows, Expert route cells, whole campaign runs, every
	# `need` of the campaign flows).
	[ "$REQUIRE" = 1 ] && export G3_REQUIRE=1
	echo "g3.sh: ${#ORDER[@]} job(s), at most $MAXJOBS at once, coop_gates in $SHARDS shard(s); logs in $RUN"
	started=$(date +%s)
	for job in "${ORDER[@]}"; do
		while [ "$(jobs -rp | wc -l)" -ge "$MAXJOBS" ]; do
			wait -n 2>/dev/null || sleep 1
		done
		(
			t0=$(date +%s)
			bash -c "${CMD[$job]}" >"$RUN/$job.log" 2>&1
			echo $? >"$RUN/$job.rc"
			echo $(($(date +%s) - t0)) >"$RUN/$job.secs"
			echo "g3.sh: $job done ($(cat "$RUN/$job.secs") s, exit $(cat "$RUN/$job.rc"))"
		) &
		sleep 1
	done
	wait
	echo "g3.sh: all jobs done in $(($(date +%s) - started)) s"
fi

# --- Report ------------------------------------------------------------------------------------------------------
LINES=()
RED=()
OPEN=()
row() { LINES+=("$(printf '  %-26s %-14s %s' "$1" "$2" "$3")"); }

secs() { [ -f "$RUN/$1.secs" ] && echo "$(cat "$RUN/$1.secs") s" || echo "-"; }

# A test module's verdict: "PASS 12/12 (34 s)" or "FAIL 3 of 12: <first failure>".
test_verdict() {
	local job="$1" log="$RUN/$1.log" passed failed first
	if [ ! -f "$log" ]; then
		echo "not run"
		return 2
	fi
	if grep -q "gd.sh: TIMEOUT" "$log"; then
		echo "TIMEOUT ($(secs "$job"))"
		return 1
	fi
	passed="$(sed -n 's/^TESTS: \([0-9]*\) passed.*/\1/p' "$log" | tail -1)"
	failed="$(sed -n 's/^TESTS: [0-9]* passed, \([0-9]*\) failed.*/\1/p' "$log" | tail -1)"
	if [ -z "$passed" ]; then
		echo "NO RESULT (crash? see $log)"
		return 1
	fi
	if grep -q "^RESULT: PASS" "$log" && [ "$failed" = "0" ]; then
		echo "PASS $passed/$((passed + failed)) ($(secs "$job"))"
		return 0
	fi
	first="$(grep -m1 '^  - ' "$log" | cut -c5-150)"
	echo "FAIL $failed of $((passed + failed)): $first"
	return 1
}

note() {
	# $1 name, $2 verdict text, $3 status (0 green, 1 red, 2 not run)
	row "$1" "" "$2"
	case "$3" in 1) RED+=("$1") ;; esac
}

# Content rows.
INV="$RUN/inventory.log"
LINES+=("Content (tests/test_integration_g3.gd)                       have / want   state")
if [ -f "$INV" ]; then
	while IFS='|' read -r _ name have want state detail; do
		name="$(echo "$name" | xargs)"
		[ "$name" = "row" ] && continue
		have="$(echo "$have" | xargs)"
		want="$(echo "$want" | xargs)"
		state="$(echo "$state" | xargs)"
		detail="$(echo "$detail" | xargs | cut -c1-150)"
		LINES+=("$(printf '  %-58s %4s / %-6s %s' "$name" "$have" "$want" "$state")")
		[ -n "$detail" ] && [ "$detail" != "all" ] && LINES+=("      $detail")
		[ "$state" = "complete" ] || OPEN+=("content: $name $have/$want")
	done < <(grep "^    G3 |" "$INV")
	v="$(test_verdict inventory)"; s=$?
	[ $s -eq 1 ] && RED+=("inventory: $v")
else
	LINES+=("  (inventory not run)")
	OPEN+=("content: inventory not run")
fi

LINES+=("" "Proofs")
for job in default campaign_routes book2_routes coop_routes; do
	[ -f "$RUN/$job.log" ] || { wanted "$job" && row "$job" "" "not run"; continue; }
	v="$(test_verdict "$job")"; s=$?
	label="$job"
	case "$job" in
		default) label="default suite (V7)" ;;
		campaign_routes) label="campaign_routes (Book I)" ;;
		book2_routes) label="book2_routes (V2.a-c)" ;;
		coop_routes) label="coop_routes (V3.a-b)" ;;
	esac
	note "$label" "$v" $s
done

# coop_gates over the shards: every gate line, the refusals, the reached gates, each shard's verdict.
shard_logs=("$RUN"/coop_gates_*.log)
if [ -f "${shard_logs[0]}" ]; then
	gates="$(grep -h "co-op gates:" "${shard_logs[@]}" | head -1 | sed 's/[^0-9]//g')"
	refused="$(grep -h ": refused in " "${shard_logs[@]}" | wc -l)"
	cached="$(grep -h ": refused in .* cached" "${shard_logs[@]}" | wc -l)"
	reached="$(grep -h ": REACHED in " "${shard_logs[@]}" | sed 's/^ *//; s/: REACHED.*//' | paste -sd ';' -)"
	bad=0
	for log in "${shard_logs[@]}"; do
		job="$(basename "$log" .log)"
		v="$(test_verdict "$job")" || bad=$((bad + 1))
	done
	worst="$(grep -h -o "in [0-9.]* s" "${shard_logs[@]}" | sed 's/[^0-9.]//g' | sort -n | tail -1)"
	text="$refused/${gates:-?} gates refused ($cached cached), ${#shard_logs[@]} shard(s), slowest gate ${worst:-?} s"
	if [ "$bad" -eq 0 ] && [ "$refused" = "${gates:-x}" ]; then
		note "coop_gates (V3.c)" "PASS $text" 0
	else
		note "coop_gates (V3.c)" "FAIL $text; $bad shard(s) red${reached:+; REACHED: $reached}" 1
		for log in "${shard_logs[@]}"; do
			first="$(grep -m1 '^  - ' "$log" | cut -c5-140)"
			[ -n "$first" ] && LINES+=("      $(basename "$log" .log): $first")
		done
	fi
elif wanted coop_gates; then
	row "coop_gates (V3.c)" "" "not run"
fi

# versus_bots: one line per (arena, mode); a cell is red when a failure line names it.
if [ -f "$RUN/versus_bots.log" ]; then
	v="$(test_verdict versus_bots)"; s=$?
	cells="$(grep -cE '^    [a-z0-9_]+/[a-z_]+: [0-9]+ rounds' "$RUN/versus_bots.log")"
	launch="$(grep -E '^    arena_[a-z0-9_]+/[a-z_]+: [0-9]+ rounds' "$RUN/versus_bots.log" | sed 's/^ *//; s/:.*//' | paste -sd ' ' -)"
	red_cells="$(grep '^  - ' "$RUN/versus_bots.log" | grep -oE 'arena_[a-z0-9_]+/[a-z_]+' | sort -u | paste -sd ' ' -)"
	note "versus_bots (V4.b)" "$v; $cells (arena, mode) cell(s)${red_cells:+, red: $red_cells}" $s
	[ -n "$launch" ] && LINES+=("      $launch")
elif wanted versus_bots; then
	row "versus_bots (V4.b)" "" "not run"
fi

if [ -f "$RUN/sp_identity.log" ]; then
	last="$(tail -1 "$RUN/sp_identity.log")"
	case "$last" in IDENTICAL*) s=0 ;; *) s=1 ;; esac
	note "sp_identity (V1)" "$last ($(secs sp_identity))" $s
elif wanted sp_identity; then
	row "sp_identity (V1)" "" "not run"
fi

for flow in "${FLOWS[@]}"; do
	log="$RUN/flow_$flow.log"
	if [ ! -f "$log" ]; then
		wanted "flow_$flow" && row "$flow.flow" "" "not run"
		continue
	fi
	result="$(grep -m1 "^Autoplay flow: RESULT" "$log" | sed 's/^Autoplay flow: RESULT //')"
	checks="$(grep -m1 "check(s), " "$log" | sed 's/^Autoplay flow: //; s/, [0-9]* screenshot.*//')"
	pending="$(grep "^Autoplay flow: pending: " "$log" | sed 's/^Autoplay flow: pending: //; s/ (.*//' | paste -sd ';' -)"
	if grep -q "gd.sh: TIMEOUT" "$log"; then
		note "$flow.flow" "TIMEOUT ($(secs "flow_$flow"))" 1
	elif [ -z "$result" ]; then
		note "$flow.flow" "NO RESULT (see $log)" 1
	elif [[ "$result" == PASS* ]]; then
		note "$flow.flow" "$result: $checks ($(secs "flow_$flow"))" 0
		[ -n "$pending" ] && { LINES+=("      pending: $(echo "$pending" | cut -c1-140)"); OPEN+=("$flow.flow pending"); }
	else
		first="$(grep -m1 "^Autoplay flow: failed: " "$log" | sed 's/^Autoplay flow: failed: //' | cut -c1-120)"
		note "$flow.flow" "FAIL: $checks; $first" 1
	fi
done

if [ ${#RED[@]} -eq 0 ] && [ ${#OPEN[@]} -eq 0 ]; then
	VERDICT="G3: REACHED - every proof green, the content complete"
	CODE=0
elif [ ${#RED[@]} -eq 0 ]; then
	VERDICT="G3: NOT YET - every proof that ran is green; open: $(printf '%s; ' "${OPEN[@]}")"
	CODE=$((REQUIRE == 1 ? 1 : 0))
else
	VERDICT="G3: RED - ${#RED[@]} proof(s) red: $(printf '%s; ' "${RED[@]}")"
	CODE=1
fi
{
	echo "G3 table ($(date '+%Y-%m-%d %H:%M'), run dir $RUN)"
	echo ""
	printf '%s\n' "${LINES[@]}"
	echo ""
	echo "$VERDICT"
} | tee "$RUN/g3_table.txt"
exit "$CODE"

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
# and one verdict per proof (tests passed / failed; per x2 gate refused exhaustive / refused bounded with its probes /
# open / unproven, DESIGN.md G59; (arena, mode) bot cells; identity; the rulings of the specs still waiting for their
# owner; flow checks, PENDING parts and a clean exit of every flow run).
#
# Jobs (names for --only / --skip): inventory, default, slow_tests (the SLOW_TESTS of tests/run_tests.gd),
# campaign_routes, book2_routes, coop_routes, core_bots, integration_totem_ring, levels_w4, coop_gates (all shards),
# versus_bots, sp_identity, spec_docs (docs/spec/test_spec_docs.py, needs python), flow_campaign,
# flow_campaign_beginner, flow_campaign_b2, flow_campaign_coop, flow_harness_exit (a clean engine exit after a
# harness run).
#   --shards=N     coop_gates shards (default $G3_SHARDS, else 8)
#   --jobs=J       jobs at once (default $G3_JOBS, else 12)
#   --require      G3 itself (G3_REQUIRE=1 for every job): the inventory rows, every Expert route cell, the campaign
#                  runs of the route modules and every `need` of the campaign flows must be complete
#   --report=DIR   print the table from the logs of an earlier run dir (build/g3/run_<tag>); nothing is run, and
#                  the run's own g3_table.txt is kept (the reprint goes to g3_table.report.txt)
# Each Godot run is limited by GD_TIMEOUT (set per job below); never wrap this script or gd.sh in an outer `timeout`
# (its SIGTERM skips gd.sh's cleanup and leaves the shared import lock behind, wf9_db3_to_integration.txt).
# Output: build/g3/run_<tag>/<job>.log (tag: $G3_TAG, else the date and the pid), <job>.rc / .secs, the table in
# <run dir>/g3_table.txt and the G59 verdict of every x2 gate in <run dir>/coop_gates_verdicts.txt. Exit code: 0 =
# every proof green (with --require also the content complete and nothing open), 1 = something red or open, 2 = usage.
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
		-h | --help) sed -n 2,30p "$0"; exit 0 ;;
		*) echo "g3.sh: unknown option $arg (see --help)" >&2; exit 2 ;;
	esac
done
case "$SHARDS$MAXJOBS" in *[!0-9]*) echo "g3.sh: --shards and --jobs take numbers" >&2; exit 2 ;; esac
[ "$SHARDS" -ge 1 ] && [ "$MAXJOBS" -ge 1 ] || { echo "g3.sh: --shards and --jobs must be >= 1" >&2; exit 2; }

# The campaign flows, and the shortest run that showed the G3 leak at exit (its checks pass either way: the row is
# about the end of its log).
FLOWS=(campaign campaign_beginner campaign_b2 campaign_coop harness_exit)
# Slow modules beside the route replays, the gate search and the bot sets (tests/run_tests.gd SLOW_FILES): the bots'
# nav-graph tests (the filter core_bots also runs test_core_bots_modes again - 20 s, harmless), the Totem Ring match,
# the fairness checks of world 4.
MORE_SLOW=(core_bots integration_totem_ring levels_w4)
GD=".tools/gd.sh"
PYTHON="$(command -v python || command -v python3 || echo python)"

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
	# The bot sets in shards side by side (tools/g3_versus_bots.sh: one merged log, the runner's TESTS / RESULT lines).
	add versus_bots "VERSUS_BOTS_SHARDS=${G3_VERSUS_SHARDS:-8} bash tools/g3_versus_bots.sh"
	add default "GD_TIMEOUT=2400 bash $GD test"
	for flow in campaign_coop campaign_b2 campaign campaign_beginner harness_exit; do
		add "flow_$flow" "GD_TIMEOUT=5400 bash $GD script res://scripts/core/dev/headless_flow.gd -- \
--flow=tools/autoplay/$flow.flow --fast --fresh-user --user-dir=res://$RUN/user_$flow --out=g3_$flow"
	done
	add sp_identity "SP_ID_TAG=g3_${TAG//[^A-Za-z0-9_-]/_} bash tools/sp_identity.sh"
	add campaign_routes "GD_TIMEOUT=3600 bash $GD test campaign_routes"
	add book2_routes "GD_TIMEOUT=3600 bash $GD test book2_routes"
	add coop_routes "GD_TIMEOUT=3600 bash $GD test coop_routes"
	# The slow modules that left the default suite for its budget (V7, the G3 follow-up round), and the slow TESTS of
	# files that stayed in it (SLOW_TESTS of tests/run_tests.gd): nothing the default run skips is skipped by the gate.
	for module in "${MORE_SLOW[@]}"; do
		add "$module" "GD_TIMEOUT=1800 bash $GD test $module"
	done
	add slow_tests "GD_TIMEOUT=2400 bash $GD test --slow-tests"
	# The lead designer's consistency tests of the specs against the code (docs/spec/test_spec_docs.py): a ruling whose
	# owner has not built it yet is skipped there with its request named - the table lists each as open work.
	add spec_docs "$PYTHON -m unittest discover -s docs/spec -p 'test_*.py' -v"
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
# A run writes its table to g3_table.txt; --report prints an earlier run again (with the rows as this script reads
# them today) into g3_table.report.txt and leaves the run's own table as it was.
TABLE="$RUN/g3_table.txt"
[ -n "$REPORT" ] && TABLE="$RUN/g3_table.report.txt"
LINES=()
RED=()
OPEN=()
row() { LINES+=("$(printf '  %-26s %-14s %s' "$1" "$2" "$3")"); }

secs() { [ -f "$RUN/$1.secs" ] && echo "$(cat "$RUN/$1.secs") s" || echo "-"; }

# A table cell without its outer blanks (not xargs: a detail may hold an apostrophe, "P1's bounce").
trim() { echo "$1" | sed 's/^ *//; s/ *$//'; }

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
		name="$(trim "$name")"
		[ "$name" = "row" ] && continue
		have="$(trim "$have")"
		want="$(trim "$want")"
		state="$(trim "$state")"
		detail="$(trim "$detail" | cut -c1-150)"
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
for job in default slow_tests campaign_routes book2_routes coop_routes "${MORE_SLOW[@]}"; do
	[ -f "$RUN/$job.log" ] || { wanted "$job" && row "$job" "" "not run"; continue; }
	v="$(test_verdict "$job")"; s=$?
	label="$job"
	case "$job" in
		default)
			label="default suite (V7)"
			# The suite's own clock, beside every other job of the gate: the V7 budget (about 5 minutes) is for an idle
			# machine, so this number only says how the run went here.
			suite="$(sed -n 's/^TESTS: .* file(s), \([0-9.]*\) s$/\1/p' "$RUN/$job.log" | tail -1)"
			skipped="$(sed -n 's/^SKIPPED: \([0-9]*\) slow test(s).*/\1/p' "$RUN/$job.log" | tail -1)"
			[ -n "$suite" ] && v="$v; its own clock ${suite} s beside the gate's other jobs (V7: about 300 s idle)"
			[ -n "$skipped" ] && v="$v; $skipped slow test(s) left to slow_tests"
			# Tests on no slow list that took more than the runner's LONG_TEST_SECONDS: the budget's next leak.
			long_mark='s/^NOTE: [0-9]* test(s) on no slow list took more than [0-9]* s each (PLAN.md 8 V7): //p'
			long="$(sed -n "$long_mark" "$RUN/$job.log" | tail -1)"
			[ -n "$long" ] && LONG_NOTE="over 10 s and on no slow list: $(echo "$long" | cut -c1-220)"
			;;
		slow_tests) label="slow tests (V7)" ;;
		campaign_routes) label="campaign_routes (Book I)" ;;
		book2_routes) label="book2_routes (V2.a-c)" ;;
		coop_routes) label="coop_routes (V3.a-b)" ;;
	esac
	note "$label" "$v" $s
	[ "$job" = default ] && [ -n "${LONG_NOTE:-}" ] && LINES+=("      $LONG_NOTE")
done

# coop_gates over the shards (DESIGN.md G59, PLAN.md 8 V3.c: "a refusal names its evidence"). Every gate prints
# `GATE <level> <difficulty> <gate>: <verdict> (<evidence>)` (tests/test_coop_gates.gd, the search's own verdict):
# refused (exhaustive) | refused (bounded) - at least 660 resting points and every probe of the gate's kind failed |
# open - reached, red | unproven - stopped at its bound without its probes: never "refused", neither green nor red
# (open work, listed by name). "n / n refused" is shown only when every gate is exhaustive or bounded with its probes.
# The verdict of every gate goes to <run dir>/coop_gates_verdicts.txt.
shard_red() {
	# A shard is red for another reason than an unproven gate: no result, a timeout, or a failure line that is not the
	# UNPROVEN line of a gate.
	local log="$RUN/$1.log"
	grep -q "gd.sh: TIMEOUT" "$log" && return 0
	grep -q "^TESTS: " "$log" || return 0
	grep '^  - ' "$log" | grep -qv "UNPROVEN (G59)" && return 0
	return 1
}
shard_logs=("$RUN"/coop_gates_*.log)
if [ -f "${shard_logs[0]}" ]; then
	# Each shard counts the gate table when it starts; a co-op file that lands while the run is under way shifts the
	# `index % n` partition, so shards that started on different tables may search a gate twice and miss others.
	# Gates are therefore counted once by name, and a run whose shards saw different tables is not a proof.
	gate_counts="$(grep -h "co-op gates:" "${shard_logs[@]}" | sed 's/[^0-9]//g' | sort -n | uniq)"
	gates="$(echo "$gate_counts" | tail -1)"
	gates_min="$(echo "$gate_counts" | head -1)"
	cached="$(grep -h ": refused in .* cached" "${shard_logs[@]}" | sed 's/^ *//; s/: refused in.*//' | sort -u | wc -l)"
	searched="$(grep -h -E ": (refused|REACHED) in " "${shard_logs[@]}" | sed 's/^ *//; s/: \(refused\|REACHED\) in.*//' \
		| sort -u | wc -l)"
	bad=0
	for log in "${shard_logs[@]}"; do
		shard_red "$(basename "$log" .log)" && bad=$((bad + 1))
	done
	worst="$(grep -h -o "in [0-9.]* s" "${shard_logs[@]}" | sed 's/[^0-9.]//g' | sort -n | tail -1)"
	VERDICTS="$RUN/coop_gates_verdicts.txt"
	grep -h "^ *GATE " "${shard_logs[@]}" | sed 's/^ *GATE //' | sort -u >"$VERDICTS"
	names() { grep -- "$1" "$VERDICTS" | sed 's/: .*//' | sort -u; }
	if [ -s "$VERDICTS" ]; then
		exhaustive="$(names ': refused (exhaustive) ' | wc -l)"
		bounded="$(names ': refused (bounded) ' | wc -l)"
		unproven="$(names ': unproven ' | paste -sd ';' - | sed 's/;/; /g')"
		# A search without G59 verdicts says plain "refused": not reached, no evidence named - unproven all the same.
		plain="$(names ': refused (the search names no evidence)' | paste -sd ';' - | sed 's/;/; /g')"
		reached="$(names ': open ' | paste -sd ';' - | sed 's/;/; /g')"
		unproven_count="$(names ': unproven ' | wc -l)"
		plain_count="$(names ': refused (the search names no evidence)' | wc -l)"
		refused=$((exhaustive + bounded))
		text="$refused/${gates:-?} gates refused: $exhaustive exhaustive, $bounded bounded + probes ($cached cached)"
		text="$text; ${#shard_logs[@]} shard(s), slowest gate ${worst:-?} s"
		[ "$unproven_count" -gt 0 ] && text="$text; UNPROVEN $unproven_count (neither green nor red)"
		[ "$plain_count" -gt 0 ] && text="$text; $plain_count refused without evidence (the search printed no G59 verdict)"
	else
		# Logs from before G59: the test printed no verdict, and "refused" only meant "not reached within the bound".
		rm -f "$VERDICTS"
		refused=0
		unproven_count="$(grep -h ": refused in " "${shard_logs[@]}" | sed 's/^ *//; s/: refused in.*//' | sort -u | wc -l)"
		plain_count=0
		unproven=""
		plain=""
		reached="$(grep -h ": REACHED in " "${shard_logs[@]}" | sed 's/^ *//; s/: REACHED.*//' | sort -u | paste -sd ';' -)"
		text="0/${gates:-?} gates refused with evidence: $unproven_count not reached within the bound ($cached cached) -"
		text="$text these logs carry no G59 verdicts (unproven); ${#shard_logs[@]} shard(s), slowest gate ${worst:-?} s"
	fi
	if [ -n "$gates" ] && [ "$gates_min" != "$gates" ]; then
		text="$text; the gate table changed during the run ($gates_min..$gates gates): $searched searched - rerun coop_gates"
	fi
	if [ "$bad" -gt 0 ] || [ -n "$reached" ] || { [ -n "$gates" ] && [ "$gates_min" != "$gates" ]; }; then
		note "coop_gates (V3.c)" "FAIL $text; $bad shard(s) red${reached:+; OPEN (a lone hero gets through): $reached}" 1
		for log in "${shard_logs[@]}"; do
			first="$(grep '^  - ' "$log" | grep -v "UNPROVEN (G59)" | head -1 | cut -c5-140)"
			[ -n "$first" ] && LINES+=("      $(basename "$log" .log): $first")
		done
	elif [ "$refused" = "${gates:-x}" ]; then
		note "coop_gates (V3.c)" "PASS $text" 0
	else
		row "coop_gates (V3.c)" "" "OPEN $text"
		OPEN+=("coop_gates: $((${gates:-0} - refused)) of ${gates:-?} gate(s) not refused with evidence")
	fi
	[ -n "$unproven" ] && LINES+=("      unproven: $unproven")
	[ -n "$plain" ] && LINES+=("      no evidence: $plain")
	[ -f "$VERDICTS" ] && LINES+=("      per gate: $VERDICTS")
elif wanted coop_gates; then
	row "coop_gates (V3.c)" "" "not run"
fi

# versus_bots: one line per (arena, mode); a cell is red when a failure line names it.
if [ -f "$RUN/versus_bots.log" ]; then
	v="$(test_verdict versus_bots)"; s=$?
	cells="$(grep -cE '^    [a-z0-9_]+/[a-z_]+: [0-9]+ rounds' "$RUN/versus_bots.log")"
	launch="$(grep -E '^    arena_[a-z0-9_]+/[a-z_]+: [0-9]+ rounds' "$RUN/versus_bots.log" | sed 's/^ *//; s/:.*//' | paste -sd ' ' -)"
	red_cells="$(grep '^  - ' "$RUN/versus_bots.log" | grep -oE 'arena_[a-z0-9_]+/[a-z_]+' | sort -u | paste -sd ' ' -)"
	# G50 / cut 4: a cell the arena's meta `bots` leaves out is human-only - neither green nor red. The inventory names
	# them (row versus_cells); while the bot test still plays such a cell, its failures do not make the proof red.
	human=""
	[ -f "$INV" ] && human="$(grep -m1 '^    G3 | versus_cells |' "$INV" | sed -n 's/.*human-only (cut 4): //p' | sed 's/^ *//; s/ *$//')"
	[ "$human" = "none" ] && human=""
	if [ $s -eq 1 ] && [ -n "$human" ] && [ -n "$red_cells" ]; then
		real_red=""
		for cell in $red_cells; do
			[[ ", $human," == *", $cell,"* ]] || real_red="$real_red $cell"
		done
		failures="$(grep -c '^  - ' "$RUN/versus_bots.log")"
		named="$(grep '^  - ' "$RUN/versus_bots.log" | grep -cE 'arena_[a-z0-9_]+/[a-z_]+')"
		if [ -z "$real_red" ] && [ "$failures" = "$named" ]; then
			s=0
			v="PASS but for human-only cell(s)"
		fi
	fi
	note "versus_bots (V4.b)" "$v; $cells (arena, mode) cell(s)${red_cells:+, red: $red_cells}" $s
	[ -n "$human" ] && LINES+=("      human-only (cut 4): $human")
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

# The spec consistency tests: failures are red; a skipped test is a ruling waiting for its owner (open work).
if [ -f "$RUN/spec_docs.log" ]; then
	ran="$(sed -n 's/^Ran \([0-9]*\) tests.*/\1/p' "$RUN/spec_docs.log" | tail -1)"
	pending="$(grep -c "skipped 'pending owner change" "$RUN/spec_docs.log")"
	if [ -z "$ran" ]; then
		note "spec docs (rulings)" "NO RESULT (python? see $RUN/spec_docs.log)" 1
	elif grep -q "^FAILED" "$RUN/spec_docs.log"; then
		first="$(grep -m1 -E "^(FAIL|ERROR): " "$RUN/spec_docs.log" | cut -c1-120)"
		counts="$(grep "^FAILED" "$RUN/spec_docs.log" | tail -1 | sed 's/^FAILED *//')"
		note "spec docs (rulings)" "FAIL $counts of $ran test(s): $first" 1
	else
		note "spec docs (rulings)" "PASS $((ran - pending))/$ran, $pending ruling(s) pending their owner ($(secs spec_docs))" 0
	fi
	while IFS= read -r line; do
		LINES+=("      not built: $(echo "$line" | cut -c1-170)")
	done < <(sed -n "s/.* skipped 'pending owner change: \(.*\)'$/\1/p" "$RUN/spec_docs.log")
	[ "$pending" -gt 0 ] && OPEN+=("$pending ruling(s) pending their owner")
elif wanted spec_docs; then
	row "spec docs (rulings)" "" "not run"
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
	# The harness must leave the engine clean (G3: a run that went from w4_l2_coop into w4_l2b_coop quit with 42
	# textures, 118 text RIDs and 167 resources "still in use"; Autoplay.keep_script): any leak report at exit is red.
	leaks="$(grep -cE "were leaked at exit|resources still in use at exit|: leaked [0-9]+ bytes" "$log")"
	if grep -q "gd.sh: TIMEOUT" "$log"; then
		note "$flow.flow" "TIMEOUT ($(secs "flow_$flow"))" 1
	elif [ -z "$result" ]; then
		note "$flow.flow" "NO RESULT (see $log)" 1
	elif [[ "$result" == PASS* ]] && [ "$leaks" -gt 0 ]; then
		note "$flow.flow" "FAIL: $checks, but the engine reports leaks at exit ($leaks line(s), see $log)" 1
	elif [[ "$result" == PASS* ]]; then
		note "$flow.flow" "$result: $checks, clean exit ($(secs "flow_$flow"))" 0
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
} | tee "$TABLE"
exit "$CODE"

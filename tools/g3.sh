#!/usr/bin/env bash
# Gate G3 bookkeeping (docs/expansion/PLAN.md 6.2 "Gate G3", 8 V1-V7). Owner: integration. Development only.
#
#   bash tools/g3.sh [--jobs=J] [--only=a,b] [--skip=a,b] [--require] [--gates-beside] [--report=<run dir>]
#
# ONE command for the gate: the three proofs of every x2 gate row (the orchestrator's R7, DESIGN.md G77, PLAN.md 8
# V3.c "The fixed bar": tools/world_coop_gates.sh - the solo search, the evidence set, the continuous-play explorer's
# two seeded passes of 300 s per row - and tests/test_coop_gates.gd, which reads them back), then every other slow
# module beside the default suite, the single-player identity check (tools/sp_identity.sh), the G3 content inventory
# (tests/test_integration_g3.gd) and the campaign and versus flows, headless (scripts/core/dev/headless_flow.gd) and
# windowed (gd.sh play: off-screen, muted), all through .tools/gd.sh, at most J at once (sp_identity counts as one
# job; it starts four Godot runs itself). Then it prints the G3 table: the content rows (Book II files, co-op files,
# route cells, featured routes, paintings, x2 gates, arenas) and one verdict per proof (tests passed / failed; per x2
# gate row the three proofs - GREEN / RED with its route file / OPEN WORK; the co-op bosses' single-hero searches;
# (arena, mode) bot cells; identity; the rulings of the specs still waiting for their owner; flow checks, PENDING
# parts and a clean exit of every flow run).
#
# THE GATE JOB RUNS FIRST AND ALONE (stage 1): an explorer pass is 300 s of WALL time, so every process that shares
# the cores takes ticks from it - the search workers ($G3_GATE_SEARCHERS, default 6) and the explorer processes
# ($G3_GATE_EXPLORERS, default 18) fill this 12-core desktop by themselves (51 minutes measured, 2026-10-09). The other
# jobs follow (stage 2, about 25 minutes). --gates-beside starts everything at once (shorter, weaker passes: each row
# prints the ticks its passes played). The gate job's own folder is <run dir>/coop_gates (COOP_GATES_OUT): worker
# logs, evidence.txt, explore.txt, test.log, verdicts.txt (one GATE line per row) and r7_rows.txt (the three proofs).
# Its results are kept (build/coop_search_cache, build/coop_explore_cache), keyed by the level file and the
# simulation's code: a rerun on an unchanged tree reads them back in a few minutes.
#
# Jobs (names for --only / --skip): inventory, default, slow_tests (the SLOW_TESTS of tests/run_tests.gd),
# campaign_routes, book2_routes, coop_routes, core_bots, integration_totem_ring, levels_w4, coop_gates,
# versus_bots, sp_identity, spec_docs (docs/spec/test_spec_docs.py, needs python), flow_campaign,
# flow_campaign_beginner, flow_campaign_b2, flow_campaign_coop, flow_g3_versus, flow_harness_exit (a clean engine exit
# after a harness run), and the windowed runs of the five play flows: wflow_campaign, wflow_campaign_beginner,
# wflow_campaign_b2, wflow_campaign_coop, wflow_g3_versus (one name for all ten: --skip=wflows / --only=wflows).
#   --jobs=J       jobs at once in stage 2 (default $G3_JOBS, else 12)
#   --gates-beside the gate job beside the others, not before them
#   --require      G3 itself (G3_REQUIRE=1 for every job): the inventory rows, every Expert route cell, the campaign
#                  runs of the route modules and every `need` of the campaign flows must be complete
#   --report=DIR   print the table from the logs of an earlier run dir (build/g3/run_<tag>); nothing is run, and
#                  the run's own g3_table.txt is kept (the reprint goes to g3_table.report.txt)
# Each Godot run is limited by GD_TIMEOUT (set per job below); never wrap this script or gd.sh in an outer `timeout`
# (its SIGTERM skips gd.sh's cleanup and leaves the shared import lock behind, wf9_db3_to_integration.txt).
# Output: build/g3/run_<tag>/<job>.log (tag: $G3_TAG, else the date and the pid), <job>.rc / .secs, the table in
# <run dir>/g3_table.txt, the verdict of every x2 gate row in <run dir>/coop_gates_verdicts.txt and its three proofs
# in <run dir>/coop_gates_r7_rows.txt. Exit code: 0 = every proof green (with --require also the content complete and
# nothing open), 1 = something red or open, 2 = usage.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

MAXJOBS="${G3_JOBS:-12}"
GATE_SEARCHERS="${G3_GATE_SEARCHERS:-6}"
GATE_EXPLORERS="${G3_GATE_EXPLORERS:-18}"
ONLY=""
SKIP=""
REQUIRE=0
REPORT=""
GATES_BESIDE=0
for arg in "$@"; do
	case "$arg" in
		--shards=*) ;;   # (the gate job is no longer shards of the test: tools/world_coop_gates.sh; accepted, ignored)
		--jobs=*) MAXJOBS="${arg#--jobs=}" ;;
		--only=*) ONLY=",${arg#--only=}," ;;
		--skip=*) SKIP=",${arg#--skip=}," ;;
		--require) REQUIRE=1 ;;
		--gates-beside) GATES_BESIDE=1 ;;
		--report=*) REPORT="${arg#--report=}" ;;
		-h | --help) sed -n 2,48p "$0"; exit 0 ;;
		*) echo "g3.sh: unknown option $arg (see --help)" >&2; exit 2 ;;
	esac
done
case "$MAXJOBS$GATE_SEARCHERS$GATE_EXPLORERS" in *[!0-9]*) echo "g3.sh: --jobs and the gate's process counts take numbers" >&2; exit 2 ;; esac
[ "$MAXJOBS" -ge 1 ] && [ "$GATE_SEARCHERS" -ge 1 ] && [ "$GATE_EXPLORERS" -ge 1 ] \
	|| { echo "g3.sh: --jobs and the gate's process counts must be >= 1" >&2; exit 2; }

# The campaign flows, the versus flow (every (arena, mode) cell CPUs play, through the real versus UI) and the
# shortest run that showed the G3 leak at exit (its checks pass either way: the row is about the end of its log).
FLOWS=(campaign campaign_beginner campaign_b2 campaign_coop g3_versus harness_exit)
# The flows that are also played WINDOWED (gd.sh play: a real window, off-screen and muted; screenshots under
# build/screenshots/g3w_<flow>_<tag>): what a headless run cannot show - the renderer, the screens, a clean exit.
WFLOWS=(campaign campaign_beginner campaign_b2 campaign_coop g3_versus)
# Slow modules beside the route replays, the gate search and the bot sets (tests/run_tests.gd SLOW_FILES): the bots'
# nav-graph tests (the filter core_bots also runs test_core_bots_modes again - 20 s, harmless), the Totem Ring match,
# the fairness checks of world 4.
MORE_SLOW=(core_bots integration_totem_ring levels_w4)
GD=".tools/gd.sh"
PYTHON="$(command -v python || command -v python3 || echo python)"

wanted() {
	local job="$1" group=""
	case "$job" in wflow_*) group="wflows" ;; esac
	if [ -n "$ONLY" ] && [[ "$ONLY" != *",$job,"* ]]; then
		[ -n "$group" ] && [[ "$ONLY" == *",$group,"* ]] || return 1
	fi
	[ -n "$SKIP" ] && [[ "$SKIP" == *",$job,"* ]] && return 1
	[ -n "$SKIP" ] && [ -n "$group" ] && [[ "$SKIP" == *",$group,"* ]] && return 1
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
	SAFE_TAG="${TAG//[^A-Za-z0-9_-]/_}"
	# THE GATE JOB (R7, DESIGN.md G77): the search workers and the explorer's two passes of every row side by side
	# (COOP_GATES_TOGETHER=1), then the evidence set and the test, which reads all three back and prints one GATE line
	# and one R7 line per row. Stage 1: alone (see the header) unless --gates-beside.
	GATE_CMD="COOP_GATES_OUT=$RUN/coop_gates COOP_GATES_TOGETHER=1 COOP_GATES_EXPLORERS=$GATE_EXPLORERS \
COOP_GATES_TIMEOUT=7200 bash tools/world_coop_gates.sh $GATE_SEARCHERS"
	run_job() {
		local job="$1" t0
		t0=$(date +%s)
		bash -c "${CMD[$job]}" >"$RUN/$job.log" 2>&1
		echo $? >"$RUN/$job.rc"
		echo $(($(date +%s) - t0)) >"$RUN/$job.secs"
		echo "g3.sh: $job done ($(cat "$RUN/$job.secs") s, exit $(cat "$RUN/$job.rc"))"
	}
	started=$(date +%s)
	if wanted coop_gates && [ "$GATES_BESIDE" = 0 ]; then
		CMD[coop_gates]="$GATE_CMD"
		echo "g3.sh: stage 1 - the three proofs of every x2 gate row, alone ($GATE_SEARCHERS search worker(s), $GATE_EXPLORERS explorer process(es)); logs in $RUN/coop_gates"
		run_job coop_gates
		unset 'CMD[coop_gates]'
	elif wanted coop_gates; then
		add coop_gates "$GATE_CMD"
	fi
	# Longest first: the bots, the suite, the co-op campaign flow.
	# The bot sets in shards side by side (tools/g3_versus_bots.sh: one merged log, the runner's TESTS / RESULT lines).
	add versus_bots "VERSUS_BOTS_SHARDS=${G3_VERSUS_SHARDS:-8} bash tools/g3_versus_bots.sh"
	add default "GD_TIMEOUT=2400 bash $GD test"
	for flow in campaign_coop campaign_b2 campaign g3_versus campaign_beginner harness_exit; do
		add "flow_$flow" "GD_TIMEOUT=5400 bash $GD script res://scripts/core/dev/headless_flow.gd -- \
--flow=tools/autoplay/$flow.flow --fast --fresh-user --user-dir=res://$RUN/user_$flow --out=g3_$flow"
	done
	for flow in campaign_coop campaign_b2 campaign g3_versus campaign_beginner; do
		add "wflow_$flow" "GD_TIMEOUT=7200 bash $GD play --flow=tools/autoplay/$flow.flow --fast --fresh-user \
--user-dir=res://$RUN/user_w_$flow --out=g3w_${flow}_$SAFE_TAG"
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
	echo "g3.sh: ${#ORDER[@]} job(s), at most $MAXJOBS at once; logs in $RUN"
	for job in "${ORDER[@]}"; do
		while [ "$(jobs -rp | wc -l)" -ge "$MAXJOBS" ]; do
			wait -n 2>/dev/null || sleep 1
		done
		run_job "$job" &
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
row() { LINES+=("$(printf '  %-32s %-8s %s' "$1" "$2" "$3")"); }

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

# coop_gates (PLAN.md 8 V3.c "The fixed bar", DESIGN.md G77): the gate job's folder <run dir>/coop_gates holds what
# tools/world_coop_gates.sh wrote - the test's log with one `GATE <level> <difficulty> <gate>: <verdict> (<evidence>)`
# line per row (refused (exhaustive) | refused (bounded) | open - a proof opened it, red, its route file named |
# unproven - a proof did not run: never "refused", neither green nor red) and one `R7 <row>: (a) ... | (b) ... | (c)
# ... => GREEN | RED | OPEN WORK` line per row. The row is green only when every row of the table is GREEN by all
# three proofs; a red row is named with its line, an unproven one is open work. The files are copied to
# <run dir>/coop_gates_verdicts.txt and <run dir>/coop_gates_r7_rows.txt.
GATES_DIR="$RUN/coop_gates"
if [ -f "$RUN/coop_gates.log" ]; then
	VERDICTS="$RUN/coop_gates_verdicts.txt"
	R7ROWS="$RUN/coop_gates_r7_rows.txt"
	rm -f "$VERDICTS" "$R7ROWS"
	[ -f "$GATES_DIR/test.log" ] && grep -E "^\s*GATE " "$GATES_DIR/test.log" | sed 's/^ *GATE //' | sort -u >"$VERDICTS"
	[ -f "$GATES_DIR/test.log" ] && grep -E "^\s*R7 " "$GATES_DIR/test.log" | sed 's/^ *//' >"$R7ROWS"
	gates="$(grep -h "co-op gates:" "$GATES_DIR/test.log" 2>/dev/null | sed 's/[^0-9]//g' | tail -1)"
	names() { grep -- "$1" "$VERDICTS" 2>/dev/null | sed 's/: .*//' | sort -u; }
	exhaustive="$(names ': refused (exhaustive) ' | wc -l)"
	bounded="$(names ': refused (bounded) ' | wc -l)"
	open_count="$(names ': open ' | wc -l)"
	unproven_count="$(names ': unproven ' | wc -l)"
	reached="$(names ': open ' | paste -sd ';' - | sed 's/;/; /g')"
	unproven="$(names ': unproven ' | paste -sd ';' - | sed 's/;/; /g')"
	rows="$(grep -c ' => ' "$R7ROWS" 2>/dev/null)"; rows="${rows:-0}"
	green="$(grep -c '=> GREEN' "$R7ROWS" 2>/dev/null)"; green="${green:-0}"
	red="$(grep -c '=> RED' "$R7ROWS" 2>/dev/null)"; red="${red:-0}"
	open_work="$(grep -c '=> OPEN WORK' "$R7ROWS" 2>/dev/null)"; open_work="${open_work:-0}"
	# (b) and (c) as the worker steps printed them: the routes that still reach, the passes played and their finds.
	evidence="$(tail -1 "$GATES_DIR/evidence.txt" 2>/dev/null | cut -c1-110)"
	explore="$(tail -1 "$GATES_DIR/explore.txt" 2>/dev/null | cut -c1-150)"
	fresh="$(grep -h -E '^== round [0-9]+: ' "$RUN/coop_gates.log" | sed -E 's/^== round [0-9]+: ([0-9]+) gate search.*/\1/' | awk '{s += $1} END {print s + 0}')"
	text="$green/${gates:-?} gate rows GREEN by the three proofs (R7): (a) $exhaustive exhaustive, $bounded bounded + probes"
	text="$text ($fresh searched in this run); (b) ${evidence:-evidence step not run}; (c) ${explore:-explorer step not run}"
	text="$text ($(secs coop_gates))"
	gate_red=0
	grep -q "gd.sh: TIMEOUT" "$GATES_DIR/test.log" 2>/dev/null && gate_red=1
	grep -q "^TESTS: " "$GATES_DIR/test.log" 2>/dev/null || gate_red=1
	if [ "$gate_red" = 1 ]; then
		note "coop_gates (V3.c, R7)" "FAIL the gate test printed no result (a crash or a timeout: see $GATES_DIR/test.log); $text" 1
	elif [ "$red" -gt 0 ] || [ "$open_count" -gt 0 ]; then
		note "coop_gates (V3.c, R7)" "FAIL $red row(s) RED${reached:+ - OPEN (a lone hero gets through): $reached}; $text" 1
		while IFS= read -r line; do
			LINES+=("      $(echo "$line" | cut -c1-300)")
		done < <(grep '=> RED' "$R7ROWS" 2>/dev/null)
	elif [ -n "$gates" ] && [ "$rows" = "$gates" ] && [ "$green" = "$gates" ] && [ $((exhaustive + bounded)) = "$gates" ]; then
		note "coop_gates (V3.c, R7)" "PASS $text" 0
	else
		row "coop_gates (V3.c, R7)" "" "OPEN $text; $open_work row(s) open work, $unproven_count unproven"
		OPEN+=("coop_gates: $((${gates:-0} - green)) of ${gates:-?} gate row(s) not GREEN by the three proofs")
	fi
	[ -n "$unproven" ] && LINES+=("      unproven: $(echo "$unproven" | cut -c1-300)")
	while IFS= read -r line; do
		LINES+=("      $(echo "$line" | cut -c1-200)")
	done < <(grep '^R7 note' "$R7ROWS" 2>/dev/null)
	[ -s "$VERDICTS" ] && LINES+=("      per row: $VERDICTS, $R7ROWS")
elif wanted coop_gates; then
	row "coop_gates (V3.c, R7)" "" "not run"
fi

# The co-op bosses (PLAN.md 8 V3.d): each boss's co-op form is not beatable by the single-hero search - one hero with
# his idle hatched partner placed where he could be hatched (G33). Eight forms, each a named test of its
# tests/test_enemies_<boss>.gd in the default suite or among the slow tests; a boss is refused when its file ran in
# that job and no failure line names the test.
BOSSES=(
	"Brute|default|test_enemies_brute.gd|test_the_single_hero_search_cannot_hurt_the_coop_brute"
	"Tusker|default|test_enemies_tusker.gd|test_the_single_hero_search_cannot_hurt_the_coop_form"
	"Inkjaw|default|test_enemies_squid.gd|test_the_single_hero_search_cannot_hurt_the_coop_form"
	"Mangrove|default|test_enemies_mangrove.gd|test_the_single_hero_search_cannot_hurt_the_coop_form"
	"Rival Chieftains|slow_tests|test_enemies_chieftain.gd|test_the_single_hero_search_with_an_idle_partner_cannot_beat_the_coop_chieftains"
	"Colossus|slow_tests|test_enemies_colossus.gd|test_coop_the_single_hero_search_cannot_hurt_the_visor_colossus"
	"Twin Idols|slow_tests|test_enemies_idols.gd|test_the_single_hero_search_cannot_crack_the_twin_idols"
	"Storm Roc|slow_tests|test_enemies_roc.gd|test_the_single_hero_search_cannot_beat_the_coop_roc"
)
if [ -f "$RUN/default.log" ] || [ -f "$RUN/slow_tests.log" ]; then
	refused_bosses=0
	boss_red=""
	boss_missing=""
	for entry in "${BOSSES[@]}"; do
		IFS='|' read -r boss job file test <<<"$entry"
		log="$RUN/$job.log"
		if [ ! -f "$log" ] || ! grep -qE "^  (ok|FAIL) +$file " "$log"; then
			boss_missing="$boss_missing $boss;"
		elif grep -q "^  - $file\.$test" "$log"; then
			boss_red="$boss_red $boss;"
		else
			refused_bosses=$((refused_bosses + 1))
		fi
	done
	if [ -n "$boss_red" ]; then
		note "co-op bosses (V3.d)" "FAIL $refused_bosses/${#BOSSES[@]} refused; a single hero beats:$boss_red" 1
	elif [ -n "$boss_missing" ]; then
		row "co-op bosses (V3.d)" "" "OPEN $refused_bosses/${#BOSSES[@]} refused; not run:$boss_missing"
		OPEN+=("co-op bosses: search not run for$boss_missing")
	else
		note "co-op bosses (V3.d)" "PASS $refused_bosses/${#BOSSES[@]} co-op boss forms refuse one hero with an idle partner (4 in the default suite, 4 among the slow tests)" 0
	fi
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

FLOW_ROWS=()
for flow in "${FLOWS[@]}"; do FLOW_ROWS+=("flow_$flow"); done
for flow in "${WFLOWS[@]}"; do FLOW_ROWS+=("wflow_$flow"); done
for flow_job in "${FLOW_ROWS[@]}"; do
	flow="${flow_job#*flow_}"
	log="$RUN/$flow_job.log"
	label="$flow.flow"
	case "$flow_job" in wflow_*) label="$flow.flow windowed" ;; esac
	if [ ! -f "$log" ]; then
		wanted "$flow_job" && row "$label" "" "not run"
		continue
	fi
	result="$(grep -m1 "^Autoplay flow: RESULT" "$log" | sed 's/^Autoplay flow: RESULT //')"
	checks="$(grep -m1 "check(s), " "$log" | sed 's/^Autoplay flow: //; s/, [0-9]* screenshot.*//')"
	pending="$(grep "^Autoplay flow: pending: " "$log" | sed 's/^Autoplay flow: pending: //; s/ (.*//' | paste -sd ';' -)"
	# The harness must leave the engine clean (G3: a run that went from w4_l2_coop into w4_l2b_coop quit with 42
	# textures, 118 text RIDs and 167 resources "still in use"; Autoplay.keep_script): any leak report at exit is red.
	leaks="$(grep -cE "were leaked at exit|resources still in use at exit|: leaked [0-9]+ bytes" "$log")"
	if grep -q "gd.sh: TIMEOUT" "$log"; then
		note "$label" "TIMEOUT ($(secs "$flow_job"))" 1
	elif [ -z "$result" ]; then
		note "$label" "NO RESULT (see $log)" 1
	elif [[ "$result" == PASS* ]] && [ "$leaks" -gt 0 ]; then
		note "$label" "FAIL: $checks, but the engine reports leaks at exit ($leaks line(s), see $log)" 1
	elif [[ "$result" == PASS* ]]; then
		note "$label" "$result: $checks, clean exit ($(secs "$flow_job"))" 0
		[ -n "$pending" ] && { LINES+=("      pending: $(echo "$pending" | cut -c1-140)"); OPEN+=("$label pending"); }
	else
		first="$(grep -m1 "^Autoplay flow: failed: " "$log" | sed 's/^Autoplay flow: failed: //' | cut -c1-120)"
		note "$label" "FAIL: $checks; $first" 1
	fi
done

# The gate is the WHOLE list: a run that left a proof out (--only / --skip, a job that wrote no log) never says
# "reached" - the proofs that did not run are open work, named here (the G3b verifier: `--require --skip=coop_gates`
# printed "G3: REACHED" with no gate searched).
NOT_RUN=()
for job in inventory default slow_tests campaign_routes book2_routes coop_routes "${MORE_SLOW[@]}" versus_bots 		sp_identity spec_docs; do
	[ -f "$RUN/$job.log" ] || NOT_RUN+=("$job")
done
[ -f "$RUN/coop_gates.log" ] || NOT_RUN+=("coop_gates")
for flow_job in "${FLOW_ROWS[@]}"; do
	[ -f "$RUN/$flow_job.log" ] || NOT_RUN+=("$flow_job")
done
[ ${#NOT_RUN[@]} -gt 0 ] && OPEN+=("not run: ${NOT_RUN[*]}")

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

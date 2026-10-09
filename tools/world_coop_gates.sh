#!/usr/bin/env bash
# THE GATE JOB: the three proofs of every x2 gate row of every co-op file on both difficulties, then
# tests/test_coop_gates.gd, which reads them back (docs/expansion/PLAN.md 8 V3.c "The fixed bar", DESIGN.md G77).
# Owner: world-B (PLAN.md 4.1, tools/world_*).
#
# THE ROW IS THREE PROOFS (the orchestrator's R7 - the bar is fixed): (a) the solo search refuses the gate, (b) every
# route of the evidence set (tools/coop_explore/evidence) says "not reached" in a fresh process, (c) the
# continuous-play explorer opens it in none of two seeded passes of 300 s over the whole level. Every piece is ONE
# Godot process and keeps its result under a key of everything it depends on - the level file and its solo base,
# the gate and difficulty, the simulation's scripts, scenes and resources (CoopSearch.code_fingerprint), the search's
# bounds, the pass's seed and seconds, the route file (CoopSearch.file_cache_key, tools/coop_explore/harness.gd
# explore_key / replay_key; build/coop_search_cache, build/coop_explore_cache).
#
# HOW IT RUNS (wf12: one plan, one pool):
#  1. THE PLAN - one process (`tools/coop_search.gd --plan`, a few seconds) asks every key: what is kept and still
#     valid is not run again. AN UNCHANGED LEVEL FILE AND UNCHANGED SIMULATION SCRIPTS NEED NO NEW SEARCH, PASS OR
#     REPLAY: on an unchanged tree the job is the plan and the test (under a minute); after an edit of one co-op
#     file only that file's rows are made again. (Any change under scripts/, scenes/ or resources/ outside the
#     screens, the versus referee, the bots and the development tools makes every row new: the search plays the
#     real game's code.)
#  2. THE POOL - every piece that is to do is a job; S of them run at once (S = the machine's threads, 24 here):
#     the searches, the dearest first by their last measured cost (the dearest takes 25 minutes), on their share of
#     the slots (about 7 of 24); the explorer's passes (300 s of wall time each, whatever the machine does) and then
#     the evidence replays (seconds) on the rest. A slot that falls free takes the next job at once, and a kind
#     that runs out leaves its slots to the other - before wf12 the search workers and the explorer were two fixed
#     groups (6 + 18) that waited for each other, and a round of 76 processes only read the cache back.
#  3. THE PLAN AGAIN - a file saved or a script edited while the pool ran (other agents work meanwhile) shows as
#     pieces to do: another pool (COOP_GATES_ROUNDS, default 3), then
#  4. THE TEST - `bash .tools/gd.sh test coop_gates` asserts every row from the kept results and prints its `R7` and
#     `GATE` line. The test is the verdict; the pool only does the work early.
#
# TIME on this 12-core / 24-thread desktop. The bar fixes the work: 152 passes of 300 s of wall time (306 s a
# process: 12.9 process-hours) and 4.9 hours of search under that load (76 searches, the dearest 26 minutes; G3c's
# durations) - 64 300 process-seconds, so 24 processes cannot end before 44.9 minutes (this pool's schedule on those
# durations: 2 696 s; with the two plans and the test about 46). The two fixed groups of wf11 took 51 (3 050 s: the
# 6 search workers 2 990 s beside 18 explorers, then a round of 76 processes that only read the cache back, the
# evidence, the test). "ABOUT 40 MINUTES" IS NOT REACHED WITHOUT WEAKENING PROOF (c): 28 processes on the 24 threads
# would end in 39 minutes (COOP_GATES_SLOTS=28), and every pass would play about a seventh fewer ticks (a pass is
# wall time). The default stays one process per thread; every run prints the ticks its passes played (G3c: 0.88 to
# 1.93 million a pass, median 1.30), so a run on a loaded machine shows what it is worth.
#
#   bash tools/world_coop_gates.sh                the whole job on S = `nproc` processes
#   bash tools/world_coop_gates.sh 16             ... on 16 processes
#   bash tools/world_coop_gates.sh --fresh [S]    the UNCACHED proof run (DESIGN.md G59): every search, pass and
#                                                 replay again whatever is kept, and the results stored
#   bash tools/world_coop_gates.sh --no-explore [S]   without proof (c) (its rows then read "unproven: (c) ... NOT
#                                                 RUN" unless their passes are kept)
#   bash tools/world_coop_gates.sh --plan         only say what is to do (exit 0 = nothing: the tree is proven as
#                                                 far as the kept results go; the test is still the verdict)
#   bash tools/world_coop_gates.sh --shards [N]   the old way: N shards of the test itself (COOP_GATES_SHARD=i/N)
#   bash tools/world_coop_gates.sh --bench K [S]  the SCALE BENCH: every gate searched K times afresh, nothing kept
#   COOP_GATES_ONLY="w2_l2_coop w9_l2_coop:drive" bash tools/world_coop_gates.sh
#                                                 A DESIGNER'S LOOP: only the rows of these files / gates (the
#                                                 selectors of tools/coop_search.gd) - their searches and passes,
#                                                 no evidence replay and NO TEST; prints their lines and exits 1
#                                                 when a search or a pass opened one. Not a proof of the table.
#   COOP_GATES_SLOTS=20 ...                       the pool's size (wins over the positional number)
#   COOP_GATES_SEARCHERS=7 ...                    how many of the slots the searches hold while passes are left
#                                                 (default: their share of the work by the last measured costs)
#   COOP_GATES_TOGETHER=1 COOP_GATES_EXPLORERS=18 bash tools/world_coop_gates.sh 6    as tools/g3.sh calls it since
#                                                 wf11: read as one pool of 6 + 18 = 24 processes
#   COOP_GATES_TIMEOUT=2400 ...                   each search process's GD_TIMEOUT (default 3600 s)
#   COOP_GATES_ROUNDS=3 ...                       most pools (default 3)
#   COOP_GATES_OUT=build/my_gates ...             another folder for the logs (two runs at once must not share one)
#
# Output folder (default build/coop_gates): plan.r<round>.txt, jobs.r<round>.txt, search/<row>.log,
# passes/<row>.p<pass>.log (a found route: passes/found_<row>.p<pass>.txt), evidence/<route>.log, evidence.txt and
# explore.txt (one line per route / per row and pass, and the count: what tools/g3.sh quotes), test.log,
# verdicts.txt (`GATE <level> <difficulty> <gate>: refused (exhaustive) | refused (bounded) | open | unproven
# (<evidence>)`), r7_rows.txt (the three proofs per row). Prints the rounds, the red rows, the verdicts and the wall
# time; exit 0 when the test passed.
#
# One row by hand:
#   bash .tools/gd.sh script res://tools/coop_search.gd -- <level>:<gate>:<beginner|expert> --no-cache      (a)
#   bash .tools/gd.sh script res://tools/coop_explore/main.gd -- replay <route file> cache=1                (b)
#   bash .tools/gd.sh script res://tools/coop_explore/main.gd -- explore <level> <gate> <0|1> pass=0        (c)
# A whole proof alone, as wf11 ran its steps (the same processes and the same keys: this job reads their results
# back; the pool's jobs are these commands for one route / one row and pass):
#   bash tools/coop_explore/replay_evidence.sh [P]                    (b) every route of the set
#   bash tools/coop_explore/explore_gates.sh all [P] passes=0,1       (c) both passes of every row
#
# MEASURED (world-B; the same bar in every line: 76 rows, two passes of 300 s a row, every route in a fresh process):
#   2026-10-09 07:16  wf11, two fixed groups (6 search workers + 18 explorer processes), nothing else running:
#                     51 minutes (3 050 s: 76 searches 2 995 s, 152 passes 2 540 s, evidence 23 s, the test 28 s).
#   2026-10-09 11:39  the G3c table (tools/g3.sh): 3 050 s the same way; 201.3 million explorer ticks.
#   2026-10-09 15:32  wf12, this pool on 24 slots - party's proof run of Q3 / Q4, NOT alone (16 processes of versus's
#                     fairness sweeps, recorder trials and a runner convoy beside it): pool 4 898 s, the searches
#                     36 148 s (twice G3c's), the passes a median of 0.66 million ticks (half G3c's) - what a loaded
#                     machine does to the job, and why the pass line prints its ticks. No clean run of the round.
#   2026-10-09 17:17  wf12, this pool with the longest job first and no mix, --fresh: 50 minutes (3 015 s: the pool
#                     2 993 s with 99.7 % of its 24 slots busy, the plans 12 s, the test 5 s); 76 rows green, 37
#                     routes, 184.2 million explorer ticks (0.58 to 1.70 million a pass, median 1.20). Other agents'
#                     runs beside it until 17:36 (up to 16 processes) - and the searches took 24 341 s for G3c's
#                     17 588 s: 24 of them at once at the start and again at the end. Hence the mix (run_pool).
# RUN IT ALONE: every other Godot run takes ticks from the passes (their wall time is fixed), and an exclusive
# runner call of another terminal (`gd.sh raw`, an import) holds every start of the pool back for minutes.
# (The body is one function, parsed whole before it runs: saving this file under a running job does not disturb it.)
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
main() {
MODE=pool
REPEAT=1
FRESH=0
EXPLORE=1
PLAN_ONLY=0
while [ $# -gt 0 ]; do
	case "$1" in
		--no-explore) EXPLORE=0; shift ;;
		--fresh) FRESH=1; shift ;;
		--plan) PLAN_ONLY=1; shift ;;
		--shards) MODE=shards; shift ;;
		--bench)
			MODE=bench
			REPEAT="${2:-3}"
			shift
			[ $# -gt 0 ] && shift
			;;
		*) break ;;
	esac
done
THREADS="$(nproc 2>/dev/null || echo 4)"
TMO="${COOP_GATES_TIMEOUT:-3600}"
OUT="${COOP_GATES_OUT:-$ROOT/build/coop_gates}"
case "$OUT" in
	/* | ?:*) ;;
	*) OUT="$ROOT/$OUT" ;;
esac
mkdir -p "$OUT"
START=$(date +%s)

if [ "$MODE" = "shards" ]; then
	N="${1:-$(( THREADS / 2 ))}"
	[ "$N" -lt 1 ] && N=1
	rm -f "$OUT"/shard_*.log
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
fi

# --- The pool ----------------------------------------------------------------------------------------------------
# S: COOP_GATES_SLOTS, else the positional number (with COOP_GATES_TOGETHER=1 plus COOP_GATES_EXPLORERS: the two
# groups of wf11 as one pool), else every thread of the machine.
if [ -n "${COOP_GATES_SLOTS:-}" ]; then
	SLOTS="$COOP_GATES_SLOTS"
elif [ $# -gt 0 ]; then
	SLOTS="$1"
	[ "${COOP_GATES_TOGETHER:-0}" = "1" ] && SLOTS=$(( SLOTS + ${COOP_GATES_EXPLORERS:-$1} ))
else
	SLOTS="$THREADS"
fi
[ "$SLOTS" -lt 1 ] && SLOTS=1
ROUNDS_MAX="${COOP_GATES_ROUNDS:-3}"
# The folders as Godot gets them: a res:// path inside the project, else the OS path.
REL_OUT=""
case "$OUT" in "$ROOT"/*) REL_OUT="${OUT#"$ROOT"/}" ;; esac
if [ -z "$REL_OUT" ]; then
	echo "world_coop_gates: COOP_GATES_OUT must be a folder inside the project ($ROOT): the explorer writes its found routes there" >&2
	exit 2
fi
PASS_SECONDS=300
gd() { ( cd "$ROOT" && bash .tools/gd.sh "$@" ); }

# One job of the pool: `<kind> <args...>` as the plan names it. Each is one Godot process with its own log.
run_job() {
	local kind="$1"
	shift
	case "$kind" in
		search)
			# search <level> <gate> <0|1>: ONE GATE PER PROCESS (an import another terminal needs gets its turn
			# between two gates, and Godot's message queue starts empty for every gate).
			local level="$1" gate="$2" diff="$3" name="beginner" extra=""
			[ "$diff" = "1" ] && name="expert"
			[ "$FRESH" -eq 1 ] && extra="--fresh"
			[ "$MODE" = "bench" ] && extra="--no-cache"
			GD_TIMEOUT="$TMO" gd script res://tools/coop_search.gd -- "$level:$gate:$name" $extra \
				> "$OUT/search/${level}__${gate}__${diff}${4:+.b$4}.log" 2>&1
			;;
		explore)
			# explore <level> <gate> <0|1> <pass>: R7's pass with the row's own seed; the result is kept.
			local tag="${1}__${2}__${3}.p${4}" extra=""
			[ "$FRESH" -eq 1 ] && extra="fresh=1"
			GD_TIMEOUT=$(( PASS_SECONDS + 900 )) gd script res://tools/coop_explore/main.gd -- explore "$1" "$2" "$3" \
				"pass=$4" "out=res://$REL_OUT/passes/found_$tag.txt" $extra > "$OUT/passes/$tag.log" 2>&1
			echo "rc=$?" >> "$OUT/passes/$tag.log"
			;;
		replay)
			# replay <route file>: one evidence route in a fresh process; the result is kept.
			GD_TIMEOUT="${EVIDENCE_TIMEOUT:-900}" gd script res://tools/coop_explore/main.gd -- replay "res://$1" cache=1 \
				> "$OUT/evidence/$(basename "$1" .txt).log" 2>&1
			;;
	esac
}

# The pool: the jobs of a list file (`<seconds> <kind> <args...>`, the longest first), S at once - and MIXED: the
# searches hold only their share of the slots (their cost over the cost of everything in the list, at least one
# slot), the dearest first; the passes and replays take the rest; whichever kind runs out leaves its slots to the
# other. Measured (the fresh run of 2026-10-09 17:17, the longest first without the mix): 24 searches at once are
# each a third slower than 7 of them beside 17 explorer passes - 24 341 s of search for G3c's 17 588 s, the same
# searches to the tick - and all the long searches came first, all the short ones last, 24 at once both times.
run_pool() {
	local list="$1" line running searching share si=0 oi=0
	local -a searches=() others=()
	mapfile -t searches < <(grep " search " "$list")
	mapfile -t others < <(grep -v " search " "$list" | grep .)
	share="$(awk -v slots="$SLOTS" '{ all += $1; if ($2 == "search") mine += $1 }
		END { n = (all > 0) ? int(slots * mine / all + 0.5) : 0; if (mine > 0 && n < 1) n = 1; print n }' "$list")"
	[ -n "${COOP_GATES_SEARCHERS:-}" ] && share="$COOP_GATES_SEARCHERS"
	rm -rf "$OUT/.searching"
	mkdir -p "$OUT/.searching"
	echo "   pool: ${#searches[@]} search(es) on $share of the $SLOTS slots, ${#others[@]} other job(s) on the rest"
	while [ "$si" -lt "${#searches[@]}" ] || [ "$oi" -lt "${#others[@]}" ]; do
		while :; do
			running="$(jobs -rp | wc -l)"
			[ "$running" -lt "$SLOTS" ] && break
			wait -n 2>/dev/null || sleep 1
		done
		searching="$(ls "$OUT/.searching" | wc -l)"
		if [ "$si" -lt "${#searches[@]}" ] && { [ "$oi" -ge "${#others[@]}" ] || [ "$searching" -lt "$share" ]; }; then
			line="${searches[$si]}"
			si=$((si + 1))
			# shellcheck disable=SC2086
			( : > "$OUT/.searching/$si"; run_job ${line#* }; rm -f "$OUT/.searching/$si" ) < /dev/null &
		else
			line="${others[$oi]}"
			oi=$((oi + 1))
			# shellcheck disable=SC2086
			run_job ${line#* } < /dev/null &
		fi
		sleep 0.3   # (the runner's entry gate is a lock folder: a burst of starts would queue behind it)
	done
	wait
	rm -rf "$OUT/.searching"
}

ONLY="${COOP_GATES_ONLY:-}"
plan() {
	local file="$1" extra="$ONLY"
	[ "$FRESH" -eq 1 ] && [ "$2" -eq 1 ] && extra="$extra --fresh"
	[ "$EXPLORE" -eq 0 ] && extra="$extra --no-explore"
	# shellcheck disable=SC2086
	GD_TIMEOUT=900 gd script res://tools/coop_search.gd -- --plan $extra 2>&1 | grep -E "^(PLAN |coop_search: plan)" > "$file"
	grep -q "^coop_search: plan" "$file"
}

if [ "$MODE" = "bench" ]; then
	mkdir -p "$OUT/search"
	plan "$OUT/plan.bench.txt" 0 || { echo "world_coop_gates: the plan did not run (see $OUT/plan.bench.txt)" >&2; exit 2; }
	: > "$OUT/jobs.bench.txt"
	for ((copy = 1; copy <= REPEAT; copy++)); do
		awk -v copy="$copy" '$2 == "search" { print $6, "search", $3, $4, $5, copy }' "$OUT/plan.bench.txt" >> "$OUT/jobs.bench.txt"
	done
	sort -k1,1nr -o "$OUT/jobs.bench.txt" "$OUT/jobs.bench.txt"
	run_pool "$OUT/jobs.bench.txt"
	END=$(date +%s)
	echo "== bench: $(grep -c . "$OUT/jobs.bench.txt") search(es) (every gate $REPEAT time(s), nothing kept) on $SLOTS process(es) in $((END - START)) s; $(cat "$OUT"/search/*.b*.log 2>/dev/null | grep -cE ' gate .*: (refused|REACHED|UNPROVEN) in ') with a result, $(cat "$OUT"/search/*.b*.log 2>/dev/null | grep -E ' gate .*: (refused|REACHED|UNPROVEN) in ' | sed -E 's/.* in ([0-9.]+) s.*/\1/' | awk '{s += $1} END {printf "%.0f", s}') s of search"
	exit 0
fi

if [ "$PLAN_ONLY" -eq 1 ]; then
	plan "$OUT/plan.txt" 1 || { echo "world_coop_gates: the plan did not run (see $OUT/plan.txt)" >&2; exit 2; }
	grep " todo" "$OUT/plan.txt" | cut -c1-200
	tail -1 "$OUT/plan.txt"
	! grep -q " todo" "$OUT/plan.txt"
	exit $?
fi

rm -rf "$OUT/search" "$OUT/passes" "$OUT/evidence" "$OUT/queue"
rm -f "$OUT"/worker_*.log "$OUT"/plan.r*.txt "$OUT"/jobs.r*.txt "$OUT/test.log" "$OUT/verdicts.txt" "$OUT/r7_rows.txt" \
	"$OUT/evidence.txt" "$OUT/explore.txt"
mkdir -p "$OUT/search" "$OUT/passes" "$OUT/evidence"
round=0
searches=0
passes=0
replays=0
while :; do
	round=$((round + 1))
	PLAN="$OUT/plan.r$round.txt"
	JOBS="$OUT/jobs.r$round.txt"
	if ! plan "$PLAN" "$round"; then
		echo "world_coop_gates: the plan did not run (see $PLAN)" >&2
		break
	fi
	# The jobs, the longest first: a search by its last measured cost, a pass by its wall time and a little for the
	# process, a replay last.
	awk -v pass="$PASS_SECONDS" '$NF == "todo" && $2 == "search" { print $6, "search", $3, $4, $5 }
		$2 == "explore" && $7 == "todo" { print pass + 8, "explore", $3, $4, $5, $6 }
		$2 == "replay" && $4 == "todo" { print 5, "replay", $3 }' "$PLAN" | sort -k1,1nr > "$JOBS"
	s="$(grep -c " search " "$JOBS")"; p="$(grep -c " explore " "$JOBS")"; r="$(grep -c " replay " "$JOBS")"
	echo "== round $round: $s gate search(es), $p explorer pass(es), $r evidence replay(s) to do on $SLOTS process(es) ($(( $(date +%s) - START )) s so far) - $(tail -1 "$PLAN" | sed 's/^coop_search: //')"
	# A round with nothing to do is the proof that every result is kept and valid: on to the test.
	if [ ! -s "$JOBS" ] || [ "$round" -gt "$ROUNDS_MAX" ]; then
		[ -s "$JOBS" ] && echo "== $ROUNDS_MAX pool(s) and still something to do (a file or a script keeps changing, or a process dies: see $OUT): the test says which rows are unproven"
		break
	fi
	searches=$((searches + s)); passes=$((passes + p)); replays=$((replays + r))
	run_pool "$JOBS"
	echo "== pool $round done ($(( $(date +%s) - START )) s so far): $(cat "$OUT"/search/*.log 2>/dev/null | grep -cE ' gate .*: (refused|REACHED|UNPROVEN) in ') search result(s), $(cat "$OUT"/search/*.log 2>/dev/null | grep -E ' gate .*: (refused|REACHED|UNPROVEN) in ' | sed -E 's/.* in ([0-9.]+) s.*/\1/' | awk '{s += $1} END {printf "%.0f", s}') s of search"
done
MID=$(date +%s)

# R7 (b) as a table: one line per route - this run's fresh process, or the kept result the plan read back.
: > "$OUT/evidence.txt"
reached=0; total=0; missing=0
while read -r _ _ route state rest; do
	[ -z "$route" ] && continue
	name="$(basename "$route" .txt)"
	# (Only what the last plan found kept and valid counts: a result that went stale under the job has no line.)
	line=""
	if [ "$state" = "kept" ]; then
		line="$(grep -h "^REPLAY .*: \(REACHED\|DIED\|not reached\)" "$OUT/evidence/$name.log" 2>/dev/null | tail -1)"
		[ -z "$line" ] && line="${rest#| }"
	fi
	total=$((total + 1))
	case "$line" in
		*"REACHED the far cell"*) reached=$((reached + 1)) ;;
		"") missing=$((missing + 1)) ;;
	esac
	printf '%-52s %s\n' "$name" "${line:-NO RESULT (to do: stale or its process died, see $OUT/evidence/$name.log)}" >> "$OUT/evidence.txt"
done < <(grep "^PLAN replay " "$PLAN" 2>/dev/null)
echo "replay_evidence: $reached of $total route(s) still REACH their far cell$([ "$missing" -gt 0 ] && echo "; $missing without a result")" >> "$OUT/evidence.txt"
echo "== evidence (R7 b; $replays replayed in this run, a fresh process each): $(tail -1 "$OUT/evidence.txt")"
grep "REACHED the far cell" "$OUT/evidence.txt" | sed 's/^/   /' | cut -c1-200

# R7 (c) as a table: one line per row and pass.
: > "$OUT/explore.txt"
if [ "$EXPLORE" -eq 1 ]; then
	reached=0; silent=0; missing=0; rows=0
	while read -r _ _ level gate diff pass state rest; do
		[ -z "$level" ] && continue
		tag="${level}__${gate}__${diff}.p${pass}"
		[ "$pass" = "0" ] && rows=$((rows + 1))
		line=""
		if [ "$state" = "kept" ]; then
			line="$(grep -h "^EXPLORE .*: \(REACHED\|NOT reached\)" "$OUT/passes/$tag.log" 2>/dev/null | tail -1)"
			[ -z "$line" ] && line="EXPLORE $level d$diff $gate whole: ${rest#| }"
		fi
		case "$line" in
			*"REACHED the far cell"*) reached=$((reached + 1)); printf '%-40s %s\n' "$tag" "$(echo "$line" | cut -c1-210)  [$OUT/passes/found_$tag.txt]" >> "$OUT/explore.txt" ;;
			*"NOT reached"*) silent=$((silent + 1)); printf '%-40s %s\n' "$tag" "$(echo "$line" | sed -E 's/^EXPLORE [^:]*: //' | cut -c1-170)" >> "$OUT/explore.txt" ;;
			*) missing=$((missing + 1)); printf '%-40s %s\n' "$tag" "NO RESULT (to do: stale or its process died, see $OUT/passes/$tag.log)" >> "$OUT/explore.txt" ;;
		esac
	done < <(grep "^PLAN explore " "$PLAN" 2>/dev/null)
	echo "explore_gates: $rows row(s), pass(es) 0 1: $reached REACHED, $silent not reached, $missing without a result; $passes pass(es) played in this run on $SLOTS process(es) ($OUT/passes)" >> "$OUT/explore.txt"
	echo "== explorer (R7 c; every row): $(tail -1 "$OUT/explore.txt")"
	grep "REACHED the far cell" "$OUT/explore.txt" | sed 's/^/   /' | cut -c1-260
	# The ticks the passes of this run played (a pass is wall time: the load of the machine shows here).
	played="$(grep -h "^EXPLORE .*: \(REACHED\|NOT reached\)" "$OUT"/passes/*.log 2>/dev/null | grep -v "\[cached\]" | sed -E 's/.* ([0-9]+) ticks played.*/\1/' | sort -n)"
	if [ -n "$played" ]; then
		echo "== explorer ticks of this run: $(echo "$played" | awk '{ v[NR] = $1; s += $1 } END { printf "%d pass(es), %.1f million ticks, %.2f to %.2f million a pass (median %.2f)", NR, s / 1e6, v[1] / 1e6, v[NR] / 1e6, v[int((NR + 1) / 2)] / 1e6 }')"
	fi
else
	echo "explore_gates: skipped (--no-explore)" >> "$OUT/explore.txt"
	echo "== explorer (R7 c): skipped (--no-explore) - a row without kept passes reads unproven"
fi

if [ -n "$ONLY" ]; then
	# A designer's loop: the rows asked for, as their searches and passes say - no test, no proof of the table.
	echo "== the rows of COOP_GATES_ONLY=\"$ONLY\" (no test: not a proof of the table)"
	( cd "$ROOT" && GD_TIMEOUT="$TMO" bash .tools/gd.sh script res://tools/coop_search.gd -- --table $ONLY 2>&1 ) 		| grep -E "^(GATE |coop_search: )" | tee "$OUT/verdicts.txt" | cut -c1-300
	cat "$OUT/explore.txt"
	echo "== $(( $(date +%s) - START )) s ($searches search(es), $passes pass(es) on $SLOTS process(es))"
	if grep -qE "^GATE [^:]*: (open|unproven)" "$OUT/verdicts.txt" || grep -q "REACHED the far cell\|NO RESULT" "$OUT/explore.txt"; then
		exit 1
	fi
	exit 0
fi
TSTART=$(date +%s)
( cd "$ROOT" && GD_TIMEOUT="$TMO" bash .tools/gd.sh test coop_gates > "$OUT/test.log" 2>&1 )
code=$?
END=$(date +%s)
echo "== gates (the test, $((END - TSTART)) s)"
grep -E "^\s+.* gate .*: (refused|REACHED) in |slot-bound" "$OUT/test.log" | sed 's/^ *//'
# The G59 verdict of every gate (DESIGN.md G59, LEVEL_DESIGN.md 15.7.6): the test's own lines when it prints them
# (CoopSearch.verdict_line), else the search tool's table from the kept results.
grep -E "^\s*GATE " "$OUT/test.log" | sed 's/^ *//' > "$OUT/verdicts.txt"
if [ ! -s "$OUT/verdicts.txt" ]; then
	( cd "$ROOT" && GD_TIMEOUT="$TMO" bash .tools/gd.sh script res://tools/coop_search.gd -- --table 2>&1 ) \
		| grep -E "^GATE " > "$OUT/verdicts.txt"
fi
grep -E "^\s*R7 " "$OUT/test.log" | sed 's/^ *//' > "$OUT/r7_rows.txt"
echo "== the three proofs per row (R7; $OUT/r7_rows.txt): $(grep -c '=> GREEN' "$OUT/r7_rows.txt") green, $(grep -c '=> RED' "$OUT/r7_rows.txt") red, $(grep -c '=> OPEN WORK' "$OUT/r7_rows.txt") open work of $(grep -c ' => ' "$OUT/r7_rows.txt") row(s)"
grep -E "=> (RED|OPEN WORK)|^R7 note" "$OUT/r7_rows.txt" | cut -c1-420
echo "== verdicts (G59 + R7; $OUT/verdicts.txt)"
cat "$OUT/verdicts.txt"
count() { grep -cE "^GATE [^:]*: $1" "$OUT/verdicts.txt"; }
echo "== $(count 'refused \(exhaustive\)') refused (exhaustive), $(count 'refused \(bounded\)') refused (bounded), \
$(count 'open') open, $(count 'unproven') unproven of $(grep -c '^GATE ' "$OUT/verdicts.txt") gate(s)"
searched_again="$(grep -E "^\s+.* gate .*: (refused|REACHED) in " "$OUT/test.log" | grep -vc " cached$")"
echo "== $(grep -E 'test_coop_gates.gd' "$OUT/test.log" | tail -1 | sed 's/^ *//')"
echo "== the plan(s) and pool(s) $((MID - START)) s ($searches search(es), $passes pass(es), $replays replay(s) on $SLOTS process(es), $((round - 1)) pool(s)) + the test $((END - TSTART)) s = $((END - START)) s ($searched_again gate(s) searched again by the test): \
$([ $code -eq 0 ] && echo "every gate refused, with its evidence" || echo "FAILURES (see $OUT/test.log)")"
exit $code
}
main "$@"

#!/usr/bin/env bash
# The performance measurement of 2.0 in one command (docs/ARCHITECTURE.md 11.5; docs/expansion/PLAN.md 7 P4.2, 8 V5).
# Owner: core. Development only. Run it ALONE on a quiet machine: every other Godot process moves the numbers.
#
#   bash tools/perf.sh [options]
#     --part=<list>   which parts to run, comma separated (default solo,coop,idle4,versus):
#                       solo    one solo route per world (w1_l1 .. w9_l1): Book I is the 1.0 baseline, Book II its twin
#                       coop    the two-hero route of the same stage of every world (w1_l1_coop .. w9_l1_coop)
#                       idle4   four heroes who press nothing on every arena, 600 ticks: the floor of a 4-hero tick
#                       versus  one 4-hero round per arena through the real versus UI: P1 idle, three Hunter CPUs
#                               (tools/autoplay/gen_versus_flow.py --perf; needs python), the match seed fixed
#     --all-coop      coop plays every co-op stage (35 files; a linked stage right after the stage that leads into it)
#     --profile       also time every _sim_tick call (--perf=profile): prints the cost per phase and class of the three
#                     most expensive levels and fills the `input` column (the CPUs' thinking). The timing itself costs:
#                     take the tick columns from a run without it
#     --fast          one tick per rendered frame instead of real time (24 ticks per second, as a player sees it):
#                     about 3 minutes instead of 17, ticks follow each other 7 ms apart instead of 41 ms and cost
#                     10 - 15 % less (warmer caches). For comparing two trees; the numbers of record are real time
#     --sleep=<usec>  idle sleep between two frames (default 6900: about 140 frames per second). Every run plays with
#                     vsync off and this sleep (the flow command frame_sleep), so the pace does not depend on the
#                     display, and several windows do not throttle each other. 0 = vsync as the settings say: then
#                     use --serial (off-screen windows share one slow vsync on Windows)
#     --serial        one part after another (default: the parts side by side, one game process each - a process
#                     sleeps for most of every frame, so they do not disturb each other on a desktop with free cores)
#     --runs=<n>      play every part n times (default 1); the table then holds the quietest run of each level
#     --seed=<n>      match seed of the versus part (default 2026): the same seed plays the same rounds
#     --tag=<name>    output folder build/perf_sh/<name> (default "run"): flows, logs, table.txt
#     --table         play nothing: print the table of the logs the tag's folder holds (with --profile its profiles)
#
# What it does: writes the flow scripts of the parts (start_level + play_file of the versioned route files), plays each
# in the windowed game (off-screen and muted, .tools/gd.sh play) with the game's own probe (--perf,
# scripts/core/dev/perf_probe.gd) and prints one row per level from the probe's "Perf row:" lines:
#   tick     cost of one simulation tick in microseconds, average / p95 / p99 / worst (every phase and every
#            end-of-tick handler; NOT the input sampling before it, where the CPU heroes think - that is `input`)
#   input    with --profile: the start of a tick (input sampling with the CPUs' thinking, the sim_prev snapshot)
#   frame    CPU time of a rendered frame in milliseconds, average / p95 / p99 (process step + render CPU time). With
#            --fast every frame holds one tick; in real time about one frame in six does, so the average is that of
#            a frame without a tick and p95 / p99 are frames with one (their input, tick and the frame's own work)
#   xproxy   tick average and p99 against the desktop proxy of the 1.0 budget (150 / 500 us, ARCHITECTURE.md 11)
# A route that no longer reaches its exit still measures its stage; the flow does not check the route (the route
# tests do). The versus rounds are the same rounds for the same --seed (the flow command versus_seed) as long as the
# bots and the referee decide the same. Exit code 0 when every part ran to its end and printed its rows.
# The numbers of record and what they mean for a Cortex-A53 class device: docs/ARCHITECTURE.md 11.5.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

PARTS="solo,coop,idle4,versus"
ALL_COOP=0
PROFILE=0
FAST=0
QUICK=6900
SERIAL=0
RUNS=1
SEED=2026
TAG="run"
TABLE_ONLY=0
for arg in "$@"; do
	case "$arg" in
		--part=*) PARTS="${arg#--part=}" ;;
		--all-coop) ALL_COOP=1 ;;
		--profile) PROFILE=1 ;;
		--fast) FAST=1 ;;
		--sleep=*) QUICK="${arg#--sleep=}" ;;
		--serial) SERIAL=1 ;;
		--runs=*) RUNS="${arg#--runs=}" ;;
		--seed=*) SEED="${arg#--seed=}" ;;
		--tag=*) TAG="${arg#--tag=}" ;;
		--table) TABLE_ONLY=1 ;;
		*) sed -n '2,43p' "${BASH_SOURCE[0]}"; exit 2 ;;
	esac
done
TAG="${TAG//[^A-Za-z0-9_-]/_}"
OUT="build/perf_sh/$TAG"
ROUTES="tools/autoplay/routes"
WORLDS="1 2 3 4 5 6 7 8 9"
mkdir -p "$OUT"
[ "$TABLE_ONLY" = "1" ] || rm -f "$OUT"/*.log "$OUT"/*.flow "$OUT"/table.txt

has_part() {
	case ",$PARTS," in *",$1,"*) return 0 ;; esac
	return 1
}

# "expert" when route file $1 plays on Expert: its header says so, or it is a 1.0 route of world 4.
difficulty_of() {
	local first
	first="$(head -n 1 "$1")"
	case "$first" in
		"# route:"*difficulty=expert*) echo expert ;;
		"# route:"*) echo "" ;;
		*) case "$(basename "$1")" in w4_* | *.expert.*) echo expert ;; *) echo "" ;; esac ;;
	esac
}

# The stage route file $1 leads into (header `after=level:<id>`), or nothing.
next_stage_of() {
	head -n 1 "$1" | sed -n 's/^# route:.* after=level:\([a-z0-9_]*\).*/\1/p'
}

flow_head() {
	echo "# Written by tools/perf.sh ($1): every stage started on its own and played by its route, for the --perf probe."
	echo "wait_until flow.current_screen == title 600"
	echo "wait_until flow.busy == false 600"
	echo "wait 30"
	[ "$QUICK" -gt 0 ] && echo "frame_sleep $QUICK"
	return 0
}

# One stage: level id $1, route file $2, players $3; a linked stage the route leads into is played by its own route.
flow_stage() {
	local level="$1" route="$2" players="$3" expert next
	expert="$(difficulty_of "$route")"
	echo "wait_until flow.busy == false 900"
	if [ "$players" -gt 1 ]; then
		echo "start_level $level $expert players=$players"
	else
		echo "start_level $level $expert"
	fi
	echo "play_file $route"
	if [ "$4" = "chain" ]; then
		next="$(next_stage_of "$route")"
		while [ -n "$next" ] && [ -f "$ROUTES/$next.inputs" ]; do
			echo "wait_until flow.busy == false 900"
			echo "play_file $ROUTES/$next.inputs"
			next="$(next_stage_of "$ROUTES/$next.inputs")"
		done
	fi
	echo "wait 30"
}

write_solo() {
	flow_head "solo"
	for w in $WORLDS; do
		flow_stage "w${w}_l1" "$ROUTES/w${w}_l1.inputs" 1 single
	done
}

write_coop() {
	flow_head "coop"
	if [ "$ALL_COOP" = "1" ]; then
		# Every co-op stage; a stage another route leads into is played behind that route, not started on its own.
		local linked="" file level
		for file in "$ROUTES"/*_coop.inputs; do
			linked="$linked $(next_stage_of "$file")"
		done
		for file in "$ROUTES"/*_coop.inputs; do
			level="$(basename "$file" .inputs)"
			case " $linked " in *" $level "*) continue ;; esac
			flow_stage "$level" "$file" 2 chain
		done
	else
		for w in $WORLDS; do
			flow_stage "w${w}_l1_coop" "$ROUTES/w${w}_l1_coop.inputs" 2 single
		done
	fi
}

write_idle4() {
	local file
	flow_head "idle4"
	for file in levels/arena_*.lvl; do
		echo "wait_until flow.busy == false 900"
		echo "start_level $(basename "$file" .lvl) players=4"
		echo "play 600:"
		echo "wait 10"
	done
}

# The versus owner's flow (one 4-hero round per arena, three Hunters), with the match seed fixed first.
write_versus() {
	local python=""
	command -v python >/dev/null 2>&1 && python=python
	[ -z "$python" ] && command -v python3 >/dev/null 2>&1 && python=python3
	if [ -z "$python" ]; then
		echo "perf.sh: the versus part needs python (tools/autoplay/gen_versus_flow.py); skipped" >&2
		return 1
	fi
	"$python" tools/autoplay/gen_versus_flow.py "--perf=$OUT/versus_generated.flow" >/dev/null || return 1
	{
		echo "# Written by tools/perf.sh (versus): the match seed is fixed, so the same seed plays the same rounds."
		echo "versus_seed $SEED"
		[ "$QUICK" -gt 0 ] && echo "frame_sleep $QUICK"
		cat "$OUT/versus_generated.flow"
	} >"$OUT/versus.flow"
	rm -f "$OUT/versus_generated.flow"
}

perf_arg="--perf"
[ "$PROFILE" = "1" ] && perf_arg="--perf=profile"
fast_arg=()
[ "$FAST" = "1" ] && fast_arg=(--fast)
failed=""
started=$(date +%s)
ready=""
for part in solo coop idle4 versus; do
	has_part "$part" || continue
	[ "$TABLE_ONLY" = "1" ] && continue
	if [ "$part" = "versus" ]; then
		write_versus || { failed="$failed $part(no flow)"; continue; }
	else
		"write_$part" >"$OUT/$part.flow"
	fi
	ready="$ready $part"
done
# One game process per part, side by side (each is idle for most of a frame); --serial plays them one after another.
play_part() {
	GD_TIMEOUT="${GD_TIMEOUT:-5400}" bash .tools/gd.sh play "--flow=$OUT/$1.flow" --fresh-user "$perf_arg" \
		"${fast_arg[@]}" "--out=perf_sh_${TAG}_$1" >"$OUT/$1_$2.log" 2>&1
	echo "exit $?" >>"$OUT/$1_$2.log"
}
for ((run = 1; run <= RUNS; run++)); do
	[ -n "$ready" ] || break
	echo "perf.sh: run $run of $RUNS:$ready ..." >&2
	for part in $ready; do
		if [ "$SERIAL" = "1" ]; then
			play_part "$part" "$run"
		else
			play_part "$part" "$run" &
		fi
	done
	wait
	for part in $ready; do
		log="$OUT/${part}_$run.log"
		if ! grep -q "^exit 0$" "$log" || ! grep -q "^Perf row:" "$log"; then
			failed="$failed $part(run $run, $(tail -n 1 "$log"))"
			grep -E "FAIL|stopped at|SCRIPT ERROR|^ERROR|TIMEOUT" "$log" | head -n 5 >&2
		fi
	done
done

# --- The table: one row per level, the quietest run of each (lowest tick average) --------------------------------------
{
	echo "perf.sh: $TAG - $([ "$FAST" = "1" ] && echo "one tick per rendered frame" || echo "real time")$([ "$QUICK" -gt 0 ] && echo ", vsync off with $QUICK us of sleep per frame" || echo ", vsync as set")$([ "$PROFILE" = "1" ] && echo ", profiled (tick columns include the timing)"), $RUNS run(s), $(($(date +%s) - started)) s"
	echo "part    level                heroes  ticks   tick us avg / p95 / p99 / max    input us avg / p99    frame ms avg / p95 / p99   ticking  xproxy avg / p99"
	for part in solo coop idle4 versus; do
		ls "$OUT/${part}_"*.log >/dev/null 2>&1 || continue
		grep -h "^Perf row:" "$OUT/${part}_"*.log | awk -F'|' -v part="$part" '
		{
			level = $1; sub(/^Perf row: /, "", level); gsub(/ /, "", level)
			split($4, t, " ")    # tick us avg A p95 B p99 C max D
			avg = t[4] + 0
			if (!(level in best) || avg < best[level]) {
				best[level] = avg
				split($2, h, " "); split($3, n, " "); split($5, i, " "); split($6, c, " "); split($11, k, " ")
				split($12, x, " ")
				row[level] = sprintf("%-7s %-20s %4d  %6d   %5d / %5d / %5d / %6d      %5d / %6d        %5.2f / %5.2f / %5.2f     %4d     %s / %s",
					part, level, h[2], n[2], t[4], t[6], t[8], t[10], i[4], i[8], c[4], c[6], c[8], k[2], x[3], x[5])
			}
			if (!(level in seen)) { seen[level] = 1; order[++count] = level }
		}
		END { for (j = 1; j <= count; j++) print row[order[j]] }'
	done
} | tee "$OUT/table.txt"

# --- The profile of the three most expensive levels (--profile): tick average plus input average ----------------------
if [ "$PROFILE" = "1" ]; then
	worst="$(for part in solo coop idle4 versus; do
		[ -f "$OUT/${part}_1.log" ] || continue
		grep -h "^Perf row:" "$OUT/${part}_1.log" | awk -F'|' -v part="$part" '{
			level = $1; sub(/^Perf row: /, "", level); gsub(/ /, "", level)
			split($4, t, " "); split($5, i, " "); print t[4] + i[4], part, level }'
	done | sort -rn | head -n 3 | awk '{ print $2 ":" $3 }')"
	for entry in $worst; do
		echo
		echo "profile of ${entry#*:} (${entry%%:*}):"
		grep -h "^Perf profile level:${entry#*:}: " "$OUT/${entry%%:*}_1.log" | sed 's/^Perf profile level:[a-z0-9_]*: //' | head -n 26
	done | tee -a "$OUT/table.txt"
fi
echo "perf.sh: logs and flows in $OUT/"
if [ -n "$failed" ]; then
	echo "perf.sh: FAILED:$failed"
	exit 1
fi
exit 0

#!/usr/bin/env bash
# Single-player identity check of the 2.0 expansion (docs/expansion/PLAN.md 8 V1, TECH_AUDIT.md 4.12).
# Run it after every change set that touches scripts/**, scenes/** or project.godot, together with
# "bash .tools/gd.sh test". Owner: integration (phase 0: the contract owner). Development only.
#
#   bash tools/sp_identity.sh
#
# It checks, against the evidence frozen once before the refactor (PLAN P0.1):
#   1. the 15 Book I level files and the 72 Book I route files are identical to tests/fixtures/book1_hashes.txt,
#      in the tree and in the frozen snapshot build/mp_baseline (hashes of the text with CRLF read as LF, the bytes
#      git stores: a Windows checkout may hold CRLF copies of some route files);
#   2. every route of the snapshot replays to the same per-tick digest as before, dozing on and off:
#      sim_bench.gd --snapshot=res://build/mp_baseline --digest --tight [--no-doze] into
#      build/mp_digest_after[_nodoze], compared file by file with build/mp_digest_before[_nodoze]
#      (bench.json holds timings and is not compared);
#   3. the committed fixtures tests/fixtures/sp_digest/*.txt (w1_l1.inputs, w2_l2b.inputs from a fresh run,
#      w4_l1.boomerang.inputs) replay identically from the live tree, dozing on and off
#      (build/mp_digest_after_fixtures[_nodoze]);
#   4. on every tick of every replay the input slots hold (PLAN P0.5): slot 0 read exactly the route's flags,
#      GameInput.flags == GameInput.get_flags(0), slots 1..3 read nothing (the "input slots" line of each run).
# The four Godot runs go in parallel through .tools/gd.sh (GD_TIMEOUT defaults to 1800 s here); their logs are in
# build/sp_identity/. The last line of the output is the verdict:
#   IDENTICAL                      exit 0
#   DIFFERENT: <first difference>  exit 1 (the lines above name the route, stage, tick and both digest lines)
#   ERROR: <reason>                exit 2 (a run failed or the frozen evidence is missing)
# A difference is a refactor bug: find its cause (sim_bench.gd --dump=<level>:<tick> prints the doze state around
# a tick). Never re-baseline the evidence to make a change pass.
#
# The evidence (build/ is not versioned) was made once, on the unmodified 1.0.0 tree, with:
#   bash .tools/gd.sh script res://scripts/core/dev/sim_bench.gd -- --make-snapshot=res://build/mp_baseline
#   bash .tools/gd.sh script res://scripts/core/dev/sim_bench.gd -- --snapshot=res://build/mp_baseline --digest \
#       --tight --out=res://build/mp_digest_before
#   bash .tools/gd.sh script res://scripts/core/dev/sim_bench.gd -- --snapshot=res://build/mp_baseline --digest \
#       --tight --no-doze --out=res://build/mp_digest_before_nodoze
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
export GD_TIMEOUT="${GD_TIMEOUT:-1800}"

BENCH="res://scripts/core/dev/sim_bench.gd"
SNAPSHOT="build/mp_baseline"
BEFORE="build/mp_digest_before"
BEFORE_NODOZE="build/mp_digest_before_nodoze"
AFTER="build/mp_digest_after"
AFTER_NODOZE="build/mp_digest_after_nodoze"
FIX_AFTER="build/mp_digest_after_fixtures"
FIX_AFTER_NODOZE="build/mp_digest_after_fixtures_nodoze"
FIXTURES="tests/fixtures/sp_digest"
HASHES="tests/fixtures/book1_hashes.txt"
FIXTURE_ROUTES=(w1_l1.inputs w2_l2b.inputs w4_l1.boomerang.inputs)
LOGS="build/sp_identity"

error() {
	echo "ERROR: $*"
	exit 2
}

# sha256 (hex) of the text of file $1 with CRLF line ends read as LF, as tests/fixtures/book1_hashes.txt lists it.
text_sha256() {
	local sum
	if command -v sha256sum >/dev/null 2>&1; then
		sum="$(tr -d '\r' <"$1" | sha256sum)"
	else
		sum="$(tr -d '\r' <"$1" | shasum -a 256)"
	fi
	echo "${sum%% *}"
}

# Check every file of the hash list under directory $1 (the route paths rewritten by the sed expression $2); prints
# the first problems and the number of files checked; returns 1 when a file is missing or differs.
check_frozen() {
	local base="$1" rewrite="$2" hash path file count=0 bad=0
	while read -r hash path; do
		case "$hash" in "" | \#*) continue ;; esac
		count=$((count + 1))
		file="$base/$(echo "$path" | sed -e "$rewrite")"
		if [ ! -f "$file" ]; then
			bad=$((bad + 1))
			[ "$bad" -le 5 ] && echo "  missing: $file"
		elif [ "$(text_sha256 "$file")" != "$hash" ]; then
			bad=$((bad + 1))
			[ "$bad" -le 5 ] && echo "  changed: $file"
		fi
	done <"$HASHES"
	echo "  $count frozen files checked in $base, $bad differ"
	[ "$count" -eq 87 ] || { echo "  $HASHES lists $count files instead of 87"; return 1; }
	[ "$bad" -eq 0 ]
}

# The first line where two digest files differ (1-based), from the first hunk of diff.
first_line() {
	local hunk number
	hunk="$(diff "$1" "$2" | head -n 1)"
	number="${hunk%%[^0-9]*}"
	case "$hunk" in
		"${number}a"*) echo $((number + 1)) ;;
		*) echo "$number" ;;
	esac
}

# Compare digest file $1 (expected) with $2 (replayed); on a difference print its details and set FIRST.
compare_file() {
	local expected="$1" actual="$2" label="$3" line stage tick
	if [ ! -f "$actual" ]; then
		echo "  $label: no replayed digest ($actual)"
		[ -n "$FIRST" ] || FIRST="$label: the route did not replay ($actual is missing)"
		return 1
	fi
	cmp -s "$expected" "$actual" && return 0
	line="$(first_line "$expected" "$actual")"
	stage="$(awk -v n="$line" 'NR >= n && /^end / {print $2; exit}' "$expected")"
	tick="$(sed -n "${line}p" "$expected" | awk '{print $1}')"
	echo "  $label: first difference at line $line (stage ${stage:-?}, tick ${tick:-?})"
	echo "    expected: $(sed -n "${line}p" "$expected")"
	echo "    replayed: $(sed -n "${line}p" "$actual")"
	[ -n "$FIRST" ] || FIRST="$label line $line (stage ${stage:-?}, tick ${tick:-?})"
	return 1
}

# Compare every digest of directory $1 (before) with directory $2 (after); counts into DIFFERING.
compare_dirs() {
	local before="$1" after="$2" mode="$3" file name count=0
	for file in "$before"/*.digest; do
		name="${file##*/}"
		count=$((count + 1))
		compare_file "$file" "$after/$name" "$mode: $name" || DIFFERING=$((DIFFERING + 1))
	done
	for file in "$after"/*.digest; do
		[ -f "$file" ] || continue
		name="${file##*/}"
		if [ ! -f "$before/$name" ]; then
			echo "  $mode: $name has no frozen counterpart"
			[ -n "$FIRST" ] || FIRST="$mode: $name has no frozen counterpart"
			DIFFERING=$((DIFFERING + 1))
		fi
	done
	echo "sp_identity: $mode: $count route digests compared"
}

# Start one sim_bench run (name, out dir under the project, options) in the background, into a fresh out dir;
# its pid goes to PIDS, its name to NAMES.
start_run() {
	local name="$1" out="$2"
	shift 2
	rm -rf "${ROOT:?}/${out:?}"
	bash .tools/gd.sh script "$BENCH" -- --out="res://$out" "$@" >"$LOGS/$name.log" 2>&1 &
	PIDS+=($!)
	NAMES+=("$name")
}

# --- 0. The frozen evidence must exist --------------------------------------------------------------------------
[ -f "$HASHES" ] || error "$HASHES is missing"
[ -f "$SNAPSHOT/routes.json" ] || error "the frozen snapshot $SNAPSHOT is missing (see the header of this script)"
for dir in "$BEFORE" "$BEFORE_NODOZE"; do
	ls "$dir"/*.digest >/dev/null 2>&1 || error "the frozen digests $dir are missing (see the header of this script)"
done
for route in "${FIXTURE_ROUTES[@]}"; do
	ls "$FIXTURES/$route".*.txt >/dev/null 2>&1 || error "no fixture for $route in $FIXTURES"
done
mkdir -p "$LOGS"

# --- 1. Book I files unchanged (tree and snapshot) ---------------------------------------------------------------
echo "sp_identity: Book I files against $HASHES"
if ! check_frozen "." "s#^##"; then
	echo "DIFFERENT: a frozen Book I file changed in the tree (see above)"
	exit 1
fi
check_frozen "$SNAPSHOT" "s#^tools/autoplay/routes/#routes/#" \
	|| error "the frozen snapshot $SNAPSHOT does not hold the Book I files of $HASHES"

# --- 2./3. Replays (four Godot runs in parallel) ----------------------------------------------------------------
echo "sp_identity: replaying every route (dozing on and off) and the fixtures; logs in $LOGS/"
PIDS=()
NAMES=()
start_run digest "$AFTER" --snapshot="res://$SNAPSHOT" --digest --tight
start_run digest_nodoze "$AFTER_NODOZE" --snapshot="res://$SNAPSHOT" --digest --tight --no-doze
start_run fixtures "$FIX_AFTER" --digest --tight --alone "${FIXTURE_ROUTES[@]}"
start_run fixtures_nodoze "$FIX_AFTER_NODOZE" --digest --tight --alone --no-doze "${FIXTURE_ROUTES[@]}"
failed_runs=""
for i in "${!PIDS[@]}"; do
	wait "${PIDS[$i]}"
	rc=$?
	if [ "$rc" -ne 0 ] || ! grep -q "^SimBench: all levels" "$LOGS/${NAMES[$i]}.log"; then
		failed_runs="$failed_runs ${NAMES[$i]} (exit $rc)"
	fi
done
[ -z "$failed_runs" ] || error "sim_bench run(s) failed:$failed_runs - see $LOGS/"

# --- Compare ------------------------------------------------------------------------------------------------------
FIRST=""
DIFFERING=0
compare_dirs "$BEFORE" "$AFTER" "doze on"
compare_dirs "$BEFORE_NODOZE" "$AFTER_NODOZE" "doze off"
fixtures=0
for fixture in "$FIXTURES"/*.txt; do
	name="$(basename "$fixture" .txt)"
	fixtures=$((fixtures + 1))
	compare_file "$fixture" "$FIX_AFTER/$name.digest" "fixture (doze on): $name" || DIFFERING=$((DIFFERING + 1))
	compare_file "$fixture" "$FIX_AFTER_NODOZE/$name.digest" "fixture (doze off): $name" || DIFFERING=$((DIFFERING + 1))
done
echo "sp_identity: $fixtures fixtures compared (dozing on and off)"
# Input slots (PLAN P0.5): on every tick of every replay slot 0 read exactly the route's flags, GameInput.flags was
# get_flags(0), and the free slots 1..3 read nothing (sim_bench_runner.gd _check_input).
input_bad=""
for name in "${NAMES[@]}"; do
	line="$(grep "^SimBench: input slots:" "$LOGS/$name.log" | tail -n 1)"
	case "$line" in
		*"; 0 mismatch(es)") echo "sp_identity: $name: ${line#SimBench: }" ;;
		*) input_bad="$input_bad $name"; echo "sp_identity: $name: ${line:-no input slot report}" ;;
	esac
done
if [ "$DIFFERING" -gt 0 ]; then
	echo "DIFFERENT: $FIRST ($DIFFERING digest file(s) differ)"
	exit 1
fi
if [ -n "$input_bad" ]; then
	echo "DIFFERENT: the input slots differ from the route flags in:$input_bad (see $LOGS/)"
	exit 1
fi
echo "IDENTICAL"
exit 0

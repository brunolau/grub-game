#!/usr/bin/env bash
# Godot runner shared by every agent and terminal working in this project.
#
#   bash .tools/gd.sh import                      headless import (exclusive), prints only error / warning lines
#   bash .tools/gd.sh test [module] [--verbose]   tests (optionally only tests/test_<module>_*.gd)
#   bash .tools/gd.sh smoke [seconds]             headless boot check
#   bash .tools/gd.sh play <user args...>         windowed run; args are passed after "--"
#   bash .tools/gd.sh script <res://x.gd> [...]   headless "-s" tool script
#   bash .tools/gd.sh raw <godot args...>         Godot with exactly these arguments (exclusive)
#
# Concurrency: runs are SHARED (many at once) while Godot's import cache is up to date. An import is
# EXCLUSIVE: it waits for running Godot processes to finish and blocks new ones meanwhile. The import runs
# automatically before any command when an asset / .import file changed or a new script appeared since the last
# import. After adding or renaming a class_name in an EXISTING script, run "bash .tools/gd.sh import" yourself.
# Every test / play run gets its own save + settings folder (build/run_users/<id>, deleted afterwards), so
# parallel runs never share user data. To keep user data across runs (e.g. the options_persist flow after
# code_and_options), pass --user-dir=res://build/autoplay_user yourself.
#
# GD_TIMEOUT=<seconds> (default 300) limits each Godot run; on timeout only that run's processes are killed.
# GODOT=<path> uses another Godot 4.7.2 binary (default: .tools/godot/Godot_v4.7.2-stable_win64_console.exe on
# Windows, .tools/godot/Godot_v4.7.2-stable_linux.x86_64 on Linux, .tools/godot/Godot.app on macOS).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && (pwd -W 2>/dev/null || pwd))"
GODOT_VERSION="4.7.2"
case "$(uname -s 2>/dev/null)" in
	Linux*) DEFAULT_GODOT="$ROOT/.tools/godot/Godot_v${GODOT_VERSION}-stable_linux.x86_64" ;;
	Darwin*) DEFAULT_GODOT="$ROOT/.tools/godot/Godot.app/Contents/MacOS/Godot" ;;
	*) DEFAULT_GODOT="$ROOT/.tools/godot/Godot_v${GODOT_VERSION}-stable_win64_console.exe" ;;
esac
GODOT="${GODOT:-$DEFAULT_GODOT}"
BUILD="$ROOT/build"
LOCK="$BUILD/.godot_lock"
READERS="$BUILD/.godot_readers"
STAMP="$BUILD/.import_stamp"
TMO="${GD_TIMEOUT:-300}"
RUN_ID="$$_${RANDOM}${RANDOM}"
MARKER="$READERS/$RUN_ID"
RUN_USER="build/run_users/$RUN_ID"
mkdir -p "$BUILD" "$READERS" "$BUILD/run_users"

# The engine is not part of the repository (.tools/ is not versioned): say how to get it.
require_godot() {
	[ -f "$GODOT" ] && return 0
	cat >&2 <<EOF
gd.sh: Godot ${GODOT_VERSION} was not found at
    $GODOT
The engine is not part of this repository (.tools/ is not versioned). To install it:
  1. Download "Godot ${GODOT_VERSION} stable", standard build (not .NET), from
       https://godotengine.org/download/archive/${GODOT_VERSION}-stable/
     or https://github.com/godotengine/godot/releases/tag/${GODOT_VERSION}-stable
     (Windows: Godot_v${GODOT_VERSION}-stable_win64.exe.zip, which holds Godot_v${GODOT_VERSION}-stable_win64_console.exe;
      Linux: Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip; macOS: Godot_v${GODOT_VERSION}-stable_macos.universal.zip).
  2. Unpack it into .tools/godot/ so that the path above exists,
     or point GODOT at your binary:   GODOT=/path/to/godot bash .tools/gd.sh test
  3. Run "bash .tools/gd.sh import" once (it builds Godot's import cache).
To export builds, also install the ${GODOT_VERSION} export templates (docs/BUILD.md section 1).
EOF
	exit 3
}

cleanup() {
	rm -f "$MARKER" 2>/dev/null
	[ -n "${HOLDING_LOCK:-}" ] && rmdir "$LOCK" 2>/dev/null
	rm -rf "$ROOT/$RUN_USER" 2>/dev/null
}
trap cleanup EXIT

# Entry gate: a writer holds it for the whole import; a reader holds it only while registering.
gate() {
	until mkdir "$LOCK" 2>/dev/null; do
		if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +12 2>/dev/null)" ]; then
			echo "gd.sh: removing stale lock" >&2
			rmdir "$LOCK" 2>/dev/null
		fi
		sleep 1
	done
	HOLDING_LOCK=1
}

ungate() {
	rmdir "$LOCK" 2>/dev/null
	HOLDING_LOCK=
}

acquire_shared() {
	gate
	touch "$MARKER"
	ungate
}

release_shared() {
	rm -f "$MARKER" 2>/dev/null
}

acquire_exclusive() {
	gate
	# Wait for running readers; markers older than two timeouts belong to dead runs.
	while [ -n "$(ls -A "$READERS" 2>/dev/null)" ]; do
		find "$READERS" -type f -mmin +12 -delete 2>/dev/null
		sleep 1
	done
}

run() {
	local flag="$BUILD/run_users/.timeout_$RUN_ID"
	"$GODOT" "$@" 2>&1 &
	local pid=$!
	local winpid
	winpid="$(cat "/proc/$pid/winpid" 2>/dev/null)"
	if [ -n "$winpid" ]; then
		( sleep "$TMO" && touch "$flag" && taskkill //F //T //PID "$winpid" ) >/dev/null 2>&1 &
	else
		( sleep "$TMO" && touch "$flag" && kill -9 "$pid" ) >/dev/null 2>&1 &
	fi
	local dog=$!
	wait "$pid"
	local rc=$?
	kill "$dog" 2>/dev/null
	if [ -f "$flag" ]; then
		rm -f "$flag"
		echo "gd.sh: TIMEOUT after ${TMO}s, this run was killed" >&2
		return 124
	fi
	return "$rc"
}

# Import is needed for new or changed assets / import settings and for new scripts (no .uid yet). Edits of
# existing scripts and scenes are picked up at run time; after adding or renaming a class_name in an existing
# script, run "gd.sh import" yourself.
needs_import() {
	[ -f "$STAMP" ] || return 0
	[ -d "$ROOT/.godot" ] || return 0
	local f
	while IFS= read -r f; do
		case "$f" in
			*.gd) [ -f "$ROOT/$f.uid" ] || return 0 ;;
			*.tscn | *.tres | *.lvl | *.inputs | *.flow | *.md | *.cfg | *.py | *.json | *.txt | *.uid | *.ps1 | *.sh) ;;
			*) return 0 ;;
		esac
	done < <(cd "$ROOT" && find assets scenes scripts resources tests tools locale -newer "$STAMP" -type f 2>/dev/null)
	return 1
}

do_import() {
	touch "$STAMP"
	run --headless --path "$ROOT" --import | grep -iE "error|warning" | head -60
}

import_if_needed() {
	needs_import || return 0
	acquire_exclusive
	needs_import && do_import
	ungate
}

has_user_dir() {
	local a
	for a in "$@"; do
		case "$a" in --user-dir=*) return 0 ;; esac
	done
	return 1
}

cmd="${1:-help}"
[ $# -gt 0 ] && shift
case "$cmd" in
	import | test | smoke | play | script | raw) require_godot ;;
esac
case "$cmd" in
	import)
		acquire_exclusive
		do_import
		ungate
		echo "gd.sh: import done"
		;;
	test)
		import_if_needed
		acquire_shared
		filter=()
		if [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; then
			filter=(--filter="$1")
			shift
		fi
		run --headless --path "$ROOT" -s res://tests/run_tests.gd -- "${filter[@]}" --user-dir="res://$RUN_USER" "$@"
		;;
	smoke)
		import_if_needed
		acquire_shared
		run --headless --path "$ROOT" -- --smoke="${1:-3}"
		;;
	play)
		import_if_needed
		acquire_shared
		if has_user_dir "$@"; then
			run --path "$ROOT" -- "$@"
		else
			run --path "$ROOT" -- --user-dir="res://$RUN_USER" "$@"
		fi
		;;
	script)
		import_if_needed
		acquire_shared
		script="$1"
		shift
		run --headless --path "$ROOT" -s "$script" "$@"
		;;
	raw)
		acquire_exclusive
		run "$@"
		;;
	*)
		sed -n '2,21p' "${BASH_SOURCE[0]}"
		exit 2
		;;
esac

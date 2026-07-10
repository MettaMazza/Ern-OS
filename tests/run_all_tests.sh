#!/usr/bin/env bash
# run_all_tests.sh — everything that must be true before Ern-OS ships.
#
#   1. Layer rules: only the hal touches the host machine.
#   2. Unit tests: parser, virtual files, accounts.
#   3. End to end: a scripted first boot, diffed against the expected
#      transcript, then a second boot proving nothing was forgotten.
#
# Usage: bash tests/run_all_tests.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
FAIL=0

[ -x toolchain/epc ] || bash toolchain/build_toolchain.sh

echo "== 1. layer rules =="
# Modules carry no imports of their own — the manifest start_ern_os.ep has them all.
if grep -rn "^import" system/ ; then
    echo "LINT FAIL: a module inside system/ carries its own import"
    FAIL=1
fi
# Only the hal may talk to the host machine.
HOST_CALLS='\b(read_file|write_file|append_file|file_exists|is_directory|list_directory|create_directory|remove_file|remove_directory|rename_file|copy_file|run_command|get_env|set_env|read_line|read_key|display_string|screen_write|terminal_columns|terminal_rows|now_ms|now_seconds|format_time|sleep_ms|net_connect|net_listen|ep_dlopen|ep_exit|ep_os_name|ep_arch_name)\b'
if grep -rnE "$HOST_CALLS" system/kernel system/shell system/apps system/desktop start_ern_os.ep ; then
    echo "LINT FAIL: something above the hal talks to the host machine"
    FAIL=1
fi
# The shell, apps, and desktop may not reach past the kernel onto the disk.
if grep -rnE '\bdisk_[a-z_]+\(' system/shell system/apps system/desktop ; then
    echo "LINT FAIL: userland touches the disk directly"
    FAIL=1
fi
# Nothing above the hal may print for itself — everything goes through say/paint.
if grep -rnE '^\s*display\b' system/kernel system/shell system/apps system/desktop ; then
    echo "LINT FAIL: something above the hal prints for itself"
    FAIL=1
fi
[ "$FAIL" -eq 0 ] && echo "layer rules hold"

echo "== 2. unit tests =="
mkdir -p tests/tmp_run
for t in tests/test_*.ep; do
    name="$(basename "$t" .ep)"
    if ! ./toolchain/epc "$t" > "tests/tmp_run/$name.build.log" 2>&1; then
        echo "BUILD FAIL: $t (see tests/tmp_run/$name.build.log)"
        FAIL=1
        continue
    fi
    # epc writes the binary into the current folder, named after the file.
    rm -rf "tests/tmp_run/$name"
    mkdir -p "tests/tmp_run/$name"
    ( cd "tests/tmp_run/$name" && "../../../$name" ) > "tests/tmp_run/$name.out" 2>&1
    if grep -q "RESULT: 0 failed" "tests/tmp_run/$name.out"; then
        echo "PASS: $name"
    else
        echo "TEST FAIL: $name"
        grep "FAIL" "tests/tmp_run/$name.out" || tail -5 "tests/tmp_run/$name.out"
        FAIL=1
    fi
done

echo "== 3. end to end =="
if [ ! -x ./start_ern_os ]; then
    bash build_ern_os.sh >/dev/null
fi
MASK='s/[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}/TIMESTAMP/g; s/- on [a-z0-9]+ \([a-z0-9_]+\)/- on HOST/; s/[0-9]+ beats/SOME beats/g; s/Awake for .+/Awake for A WHILE/'
# The transcript tests drive the sentence-only shell with --plain.
run_transcript() {
    name="$1"
    dir="tests/tmp_run/e2e_$name"
    rm -rf "$dir"
    mkdir -p "$dir"
    ( cd "$dir" && ../../../start_ern_os --plain < "../../end_to_end/$name.commands" ) 2>&1 \
        | sed -E "$MASK" > "$dir/$name.actual"
    if diff -u "tests/end_to_end/$name.expected" "$dir/$name.actual" > "$dir/$name.diff"; then
        echo "PASS: $name transcript"
    else
        echo "E2E FAIL: $name transcript differs (see $dir/$name.diff)"
        head -20 "$dir/$name.diff"
        FAIL=1
    fi
}
run_transcript first_boot
run_transcript full_tour
# Boot the first disk again: the note must still be there, the password still hashed.
E2E=tests/tmp_run/e2e_first_boot
( cd "$E2E" && ../../../start_ern_os --plain < ../../end_to_end/second_boot.commands ) > "$E2E/second_boot.actual" 2>&1
if grep -q "good morning world" "$E2E/second_boot.actual"; then
    echo "PASS: the note survived a restart"
else
    echo "E2E FAIL: the note did not survive a restart"
    FAIL=1
fi
if grep -rq "sunrise" "$E2E/disk" || grep -rq "tide42" "tests/tmp_run/e2e_full_tour/disk"; then
    echo "E2E FAIL: a plain password reached the disk"
    FAIL=1
else
    echo "PASS: no plain password on the disk"
fi

echo "== 4. the desktop =="
# The desktop draws escape codes and live figures, so it cannot be diffed
# byte for byte. Instead: boot the real desktop over a pipe and prove the
# frame is there, a command runs inside it, and the terminal is left clean.
DSK=tests/tmp_run/desktop
rm -rf "$DSK"
mkdir -p "$DSK"
printf 'ada\nlovelace\nada\nlovelace\nwhat is running\n\topen files\ndone\nshut down\n' > "$DSK/keys.txt"
( cd "$DSK" && ../../../start_ern_os < ../../tmp_run/desktop/keys.txt ) > "$DSK/raw.out" 2>&1
desk_rc=$?
strip_ansi() { sed $'s/\x1b\\[[0-9;?]*[a-zA-Z]//g' "$1"; }
strip_ansi "$DSK/raw.out" > "$DSK/text.out"
desk_ok=1
[ "$desk_rc" -eq 0 ] || { echo "  desktop exited non-zero ($desk_rc)"; desk_ok=0; }
grep -q "Ern-OS" "$DSK/text.out" || { echo "  menu bar missing"; desk_ok=0; }
grep -q "at a glance" "$DSK/text.out" || { echo "  glance panel missing"; desk_ok=0; }
grep -q "notes here" "$DSK/text.out" || { echo "  Tab did not flip to the notes panel"; desk_ok=0; }
grep -q "conversation" "$DSK/text.out" || { echo "  conversation window missing"; desk_ok=0; }
grep -q "heartbeat" "$DSK/text.out" || { echo "  taskbar heartbeat missing"; desk_ok=0; }
grep -q "Working in the background" "$DSK/text.out" || { echo "  a command did not run in the window"; desk_ok=0; }
# The alternate screen must be entered exactly once and left exactly once.
[ "$(grep -c $'\x1b\\[?1049h' "$DSK/raw.out")" -eq 1 ] || { echo "  alt screen not entered once"; desk_ok=0; }
[ "$(grep -c $'\x1b\\[?1049l' "$DSK/raw.out")" -eq 1 ] || { echo "  alt screen not left once"; desk_ok=0; }
grep -q "Ern-OS is going to sleep" "$DSK/text.out" || { echo "  no clean shutdown"; desk_ok=0; }
if [ "$desk_ok" -eq 1 ]; then
    echo "PASS: the desktop boots, runs a command in-window, and restores the terminal"
else
    echo "DESKTOP FAIL: see $DSK/raw.out"
    FAIL=1
fi

echo "== summary =="
LINES=$(cat system/hal/*.ep system/kernel/*.ep system/shell/*.ep start_ern_os.ep | wc -l | tr -d ' ')
echo "Ern-OS is $LINES lines of Ernos."
if [ "$FAIL" -eq 0 ]; then
    echo "ALL TESTS PASS"
else
    echo "SOMETHING FAILED"
    exit 1
fi

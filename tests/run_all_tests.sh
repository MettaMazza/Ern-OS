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
HOST_CALLS='\b(read_file|write_file|append_file|file_exists|is_directory|list_directory|create_directory|remove_file|remove_directory|rename_file|copy_file|run_command|get_env|set_env|read_line|display_string|now_ms|now_seconds|format_time|sleep_ms|net_connect|net_listen|ep_dlopen|ep_exit|ep_os_name|ep_arch_name)\b'
if grep -rnE "$HOST_CALLS" system/kernel system/shell start_ern_os.ep ; then
    echo "LINT FAIL: something above the hal talks to the host machine"
    FAIL=1
fi
# The shell may not reach past the kernel onto the disk.
if grep -rnE '\bdisk_[a-z_]+\(' system/shell ; then
    echo "LINT FAIL: the shell touches the disk directly"
    FAIL=1
fi
# Nothing above the hal may print for itself — everything goes through say/ask.
if grep -rnE '^\s*display\b' system/kernel system/shell ; then
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
E2E=tests/tmp_run/e2e
rm -rf "$E2E"
mkdir -p "$E2E"
MASK='s/[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}/TIMESTAMP/g; s/- on [a-z0-9]+ \([a-z0-9_]+\)/- on HOST/'
( cd "$E2E" && ../../../start_ern_os < ../../end_to_end/first_boot.commands ) 2>&1 \
    | sed -E "$MASK" > "$E2E/first_boot.actual"
if diff -u tests/end_to_end/first_boot.expected "$E2E/first_boot.actual" > "$E2E/first_boot.diff"; then
    echo "PASS: first boot transcript"
else
    echo "E2E FAIL: first boot transcript differs (tests/tmp_run/e2e/first_boot.diff)"
    head -20 "$E2E/first_boot.diff"
    FAIL=1
fi
# Boot the same disk again: the note must still be there, the password still hashed.
( cd "$E2E" && ../../../start_ern_os < ../../end_to_end/second_boot.commands ) > "$E2E/second_boot.actual" 2>&1
if grep -q "good morning world" "$E2E/second_boot.actual"; then
    echo "PASS: the note survived a restart"
else
    echo "E2E FAIL: the note did not survive a restart"
    FAIL=1
fi
if grep -rq "sunrise" "$E2E/disk"; then
    echo "E2E FAIL: a plain password reached the disk"
    FAIL=1
else
    echo "PASS: no plain password on the disk"
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

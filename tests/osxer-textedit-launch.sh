#!/usr/bin/env bash
# OSXER TEXTEDIT (regression runner) / OSXER LOG (regression runner).
# Run inside the reviewer's Darling shell with the staged frameworks.
# Set OSXER_TEST_DIR to a writable disk directory; never use RAM-backed /tmp.
set -euo pipefail
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
test_dir=$(mktemp -d "${OSXER_TEST_DIR:-$PWD}/.osxer-textedit-launch.XXXXXX")
trap 'rm -rf -- "$test_dir"' EXIT # Only the directory created by this script.
export TMPDIR="$test_dir" CCACHE_DISABLE=1
if test -x "$source_dir/Probe.app/Contents/MacOS/probe"; then
    cp -R "$source_dir/Probe.app" "$test_dir/"
else
    # Source checkout fallback requires clang and an SDK on the reviewer machine.
    mkdir -p "$test_dir/Probe.app/Contents/MacOS"
    cp "$source_dir/osxer-textedit-launch.plist" "$test_dir/Probe.app/Contents/Info.plist"
    "${CC:-clang}" -fblocks -fno-objc-arc -framework AppKit \
        "$source_dir/osxer-textedit-launch.m" -o "$test_dir/Probe.app/Contents/MacOS/probe"
fi
probe="$test_dir/Probe.app/Contents/MacOS/probe"
unset OSXER_LOG_STDERR OSXER_TEXTEDIT_DEBUG CFLOG_FORCE_STDERR
"$probe"
"$probe" logs-normal-exit >"$test_dir/off.out" 2>"$test_dir/off.err"
OSXER_LOG_STDERR=0 "$probe" logs-normal-exit >"$test_dir/zero.out" 2>"$test_dir/zero.err"
OSXER_LOG_STDERR=true "$probe" logs-normal-exit >"$test_dir/true.out" 2>"$test_dir/true.err"
for mode in off zero true; do
    grep -q 'OSXER-NS-ONE' "$test_dir/$mode.out"
    if grep -qE 'OSXER-NS-|OSXER-OS-' "$test_dir/$mode.err"; then
        printf 'FAIL: stderr mirror enabled without value 1\n' >&2
        exit 1
    fi
done
OSXER_LOG_STDERR=1 CFLOG_FORCE_STDERR=1 "$probe" logs >"$test_dir/on.out" 2>"$test_dir/on.err"
for marker in OSXER-NS-ONE OSXER-NS-NL OSXER-CF-ONE OSXER-CF-NL OSXER-OS-ONE; do
    test "$(grep -c "$marker" "$test_dir/on.err")" -eq 1
done
grep -q 'ação 17' "$test_dir/on.err"
grep -q 'ação 23' "$test_dir/on.err"
# Original stdout destination remains available on normal exit.
OSXER_LOG_STDERR=1 "$probe" logs-normal-exit >"$test_dir/both.out" 2>"$test_dir/both.err"
grep -q 'OSXER-NS-ONE' "$test_dir/both.out"
OSXER_LOG_STDERR=1 "$probe" exception >"$test_dir/exception.out" 2>"$test_dir/exception.err"
grep -q 'name=OSXERException reason=OSXER exception reason' "$test_dir/exception.err"
grep -q 'return address: 0x' "$test_dir/exception.err"
printf 'PASS: UTI lookup/creation, opt-in stderr, flush, exception stack\n'

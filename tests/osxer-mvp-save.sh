#!/usr/bin/env bash
# OSXER MVP (Darling runner): staged frameworks + host mldr/darlingserver required.
# Run inside a Darling shell on an isolated display; builds are not done here.
set -euo pipefail
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
case "$HOME" in /Users/*) ;; *) echo 'Run inside Darling with its prefix home' >&2; exit 1;; esac
test ! -L "$HOME"
test ! -L "$HOME/Documents" # Refuse old XDG links before any panel is shown.
: "${OSXER_TEST_DIR:?Set OSXER_TEST_DIR to a disk-backed directory inside the Darling prefix}"
test_dir=$(mktemp -d "$OSXER_TEST_DIR/mvp-save.XXXXXX")
trap 'rm -rf -- "$test_dir"' EXIT # Only this script's directory.
cp -R "$source_dir/Probe.app" "$test_dir/"
probe="$test_dir/Probe.app/Contents/MacOS/probe"
export OSXER_MVP_DIR="$test_dir" TMPDIR="$test_dir"
OSXER_MVP_MODE=stack "$probe"
printf '{\\rtf1\\ansi synthetic launch fixture}' > "$test_dir/first file.rtf"
printf '{\\rtf1\\ansi second fixture}' > "$test_dir/second.rtf"
OSXER_MVP_MODE=multi OSXER_MVP_EXPECT="$test_dir/first file.rtf
$test_dir/second.rtf" "$probe" -NSDocumentRevisionsDebugMode YES -psn_0_123 "$test_dir/first file.rtf" "$test_dir/second.rtf"
OSXER_MVP_MODE=single OSXER_MVP_EXPECT="$test_dir/first file.rtf" "$probe" -psn_0_123 -NSOpen "$test_dir/first file.rtf"
OSXER_MVP_MODE=multi OSXER_MVP_EXPECT='-dash.rtf' "$probe" -- -dash.rtf
OSXER_MVP_MODE=empty "$probe" -NSDocumentRevisionsDebugMode YES -psn_0_123
OSXER_MVP_MODE=controller "$probe" "$test_dir/first file.rtf"
OSXER_MVP_MODE=save "$probe"
# LaunchServices jobs do not necessarily inherit the calling shell's environment.
# The child defaults to checking its opened document and writes a marker beside it.
OSXER_MVP_MODE=ls "$probe" "$test_dir/Probe.app" "$test_dir/second.rtf"
for ((attempt = 0; attempt < 100; attempt++)); do
    test ! -f "$test_dir/second.rtf.opened" || break
    sleep 0.1
done
test -f "$test_dir/second.rtf.opened"
printf 'PASS: argv, NSOpen, controller, save/Return, RTF, LaunchServices file delivery\n'

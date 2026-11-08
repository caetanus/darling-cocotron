#!/usr/bin/env bash
# OSXER FOCUS (regression runner) / OSXER BIGSUR DARK (regression runner).
# Run INSIDE the reviewer's Darling shell, with the rebuilt frameworks loaded.
# No installations, defaults writes or execution outside this script.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
test_dir=$(mktemp -d "$root/.osxer-focus-dark.XXXXXX")
trap 'rm -f -- "$test_dir/probe"; rmdir -- "$test_dir"' EXIT
"${CC:-clang}" -fblocks -fno-objc-arc -framework AppKit "$root/osxer-focus-dark.m" -o "$test_dir/probe"
unset OSXER_APPEARANCE GALLERY_APPEARANCE
OSXER_TEST_EXPECT=light "$test_dir/probe" -OSXERGraphicsStyle BigSur -OSXERAppearance Light
OSXER_TEST_EXPECT=light "$test_dir/probe" -OSXERGraphicsStyle BigSur -OSXERAppearance Unknown
OSXER_TEST_EXPECT=dark "$test_dir/probe" -OSXERGraphicsStyle BigSur -OSXERAppearance Dark
OSXER_APPEARANCE=dark OSXER_TEST_EXPECT=dark "$test_dir/probe" -OSXERGraphicsStyle BigSur -OSXERAppearance Light
OSXER_APPEARANCE=light OSXER_TEST_EXPECT=light "$test_dir/probe" -OSXERGraphicsStyle BigSur -OSXERAppearance Dark
OSXER_APPEARANCE=invalid OSXER_TEST_EXPECT=dark "$test_dir/probe" -OSXERGraphicsStyle BigSur -OSXERAppearance Dark
# The gallery asks through NSApp.setAppearance:; explicit Dark must beat Light overrides.
GALLERY_APPEARANCE=dark OSXER_APPEARANCE=light OSXER_TEST_EXPECT=light "$test_dir/probe" -OSXERGraphicsStyle BigSur -OSXERAppearance Light
GALLERY_APPEARANCE=dark OSXER_TEST_EXPECT=dark "$test_dir/probe" -OSXERGraphicsStyle BigSur -OSXERAppearance Dark

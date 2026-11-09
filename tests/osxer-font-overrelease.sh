#!/usr/bin/env bash
# OSXER TEXTEDIT LOOK (memory): use only inside Darling, on an isolated display.
set -euo pipefail
case "$(uname -s)" in Darwin) ;; *) echo 'Run this script inside Darling' >&2; exit 1;; esac
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
: "${DISPLAY:?Use an isolated X11 test display}"
exec "$source_dir/Probe.app/Contents/MacOS/probe"

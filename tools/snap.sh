#!/bin/bash
# Renders named scenarios to out/<name>.png via the SVG renderer + Chromium.
set -e
cd "$(dirname "$0")/.."
export PATH=/opt/swift/usr/bin:$PATH
swift build -q --product fpod-tool 2>&1 | grep -E "error" || true
files=()
for s in "$@"; do
  .build/debug/fpod-tool snapshot "$s" "out/$s.svg" > /dev/null
  files+=("out/$s.svg")
done
node tools/svg2png.js "${files[@]}"

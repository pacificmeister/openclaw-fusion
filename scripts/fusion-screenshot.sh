#!/bin/bash
# fusion-screenshot.sh — Capture Fusion 360 viewport screenshot
# Usage: fusion-screenshot.sh [output_path] [--crop x,y,w,h]
#
# Captures the screen and optionally crops to a region.
# Uses macOS screencapture (silent mode).

set -euo pipefail

OUTPUT="${1:-/tmp/fusion-viewport-$(date +%s).png}"
CROP=""

# Parse --crop flag
shift 2>/dev/null || true
while [[ $# -gt 0 ]]; do
  case $1 in
    --crop) CROP="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Capture full screen (silent, no shadow)
/usr/sbin/screencapture -x -C "$OUTPUT"

# Crop if requested (requires sips)
if [[ -n "$CROP" ]]; then
  IFS=',' read -r cx cy cw ch <<< "$CROP"
  # sips --cropToHeightWidth requires temp + offset approach
  # Use python for precise cropping
  python3 - "$OUTPUT" "$cx" "$cy" "$cw" "$ch" << 'PYEOF'
import sys
from PIL import Image
img = Image.open(sys.argv[1])
x, y, w, h = int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
cropped = img.crop((x, y, x + w, y + h))
cropped.save(sys.argv[1])
PYEOF
fi

echo "$OUTPUT"

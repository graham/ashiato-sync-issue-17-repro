#!/usr/bin/env bash
# ONE PICTURE OF EVERY DEVICE IN THE COCKPIT BUILDER'S PARTS BIN.
# Use --device=GuardedToggleSwitch for one part or --out=/somewhere for another folder.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
godot="${GODOT:-$(dirname "$here")/_tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
if [ ! -x "$godot" ]; then
    echo "No Godot at $godot. Run tools/bootstrap.sh first, or set GODOT=." >&2
    exit 1
fi
echo "Godot: $godot"
exec "$godot" --xr-mode off --path "$here" --resolution 1600x900 res://tests/device_gallery_shot.tscn -- --desktop-only "$@"

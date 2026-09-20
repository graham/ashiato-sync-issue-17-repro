#!/usr/bin/env bash
# ONE PICTURE OF EVERY KIND OF CRAFT THE LEVEL PLACES: `cockpit/craft_gallery.sh`, or with `--finish=fine --out=/somewhere`.
# Runs tests/craft_gallery_shot.tscn in a window on the stock editor, because the double build cannot render windowed on
# the Linux machine's RADV (CLAUDE.md). GODOT=/path/to/godot picks another. Pictures land in
# <repo>/screenshots/<today>/cockpit-craft-<kind>.png. Judge the run by its RESULT= line, not the exit code.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
godot="${GODOT:-$(dirname "$here")/_tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
if [ ! -x "$godot" ]; then
    echo "No Godot at $godot. Run tools/bootstrap.sh first, or set GODOT=." >&2
    exit 1
fi
echo "Godot: $godot"
exec "$godot" --xr-mode off --desktop-only --path "$here" --resolution 1600x900 res://tests/craft_gallery_shot.tscn -- --level=watch "$@"

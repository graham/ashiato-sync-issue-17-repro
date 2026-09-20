#!/usr/bin/env bash
#
# THE SWEEP: what the wire and the server cost as the crowd grows.
#
#   cockpit/tests/crowd.sh                       1..32 clients at 100 ms
#   cockpit/tests/crowd.sh --ping 200            the same, on a worse link
#   cockpit/tests/crowd.sh --tick 30 --ai 40     a slower clock and a populated world
#   cockpit/tests/crowd.sh --counts "1 4 16"     pick the points yourself
#
# Runs tests/crowd.tscn once per client count and lays the CROWD lines out as a table.
# Each run is its own process, so one crashing does not take the sweep with it.
#
# THE NUMBERS ARE MEASURED, NOT MODELLED, but only the wire numbers are portable. Bytes
# per second and rollbacks per second come out of a fake link and are identical on any
# machine; the server-tick milliseconds are wall clock on THIS one, with every client
# world running in the same process and competing for the same core. Read them as a shape
# rather than as a capacity.

set -uo pipefail

counts="1 2 4 8 16 32"
ping=100
tick=120
ai=0
seconds=6
loss=0
jitter=0
while [ $# -gt 0 ]; do
    case "$1" in
        --counts)  counts="$2"; shift 2 ;;
        --ping)    ping="$2"; shift 2 ;;
        --tick)    tick="$2"; shift 2 ;;
        --ai)      ai="$2"; shift 2 ;;
        --seconds) seconds="$2"; shift 2 ;;
        --loss)    loss="$2"; shift 2 ;;
        --jitter)  jitter="$2"; shift 2 ;;
        -h|--help) sed -n '2,17p' "$0" | sed 's/^# \?//'; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cockpit="$(dirname "$here")"
root="$(dirname "$cockpit")"
godot=""
for candidate in \
    "$root/_tools/godot-4.7.2-double/godot.linuxbsd.editor.double.x86_64" \
    "$root/_tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64"; do
    if [ -x "$candidate" ]; then godot="$candidate"; break; fi
done
[ -n "$godot" ] || { echo "No Godot under $root/_tools." >&2; exit 1; }

printf '%s Hz, %s ms ping, %s AI craft, %s%% loss, %s ms jitter, %ss per point\n\n' \
    "$tick" "$ping" "$ai" "$loss" "$jitter" "$seconds"
printf '%8s %9s %11s %11s %10s %10s %10s %9s\n' \
    clients entities 'down kB/s' 'per client' 'up/client' 'pkts/s' 'srv ms' 'rollb/s'
printf '%8s %9s %11s %11s %10s %10s %10s %9s\n' \
    -------- --------- ----------- ----------- ---------- ---------- ---------- ---------

for n in $counts; do
    line="$(timeout 600 "$godot" --headless --xr-mode off --fixed-fps 240 --path "$cockpit" \
        res://tests/crowd.tscn -- "--clients=$n" "--ping=$ping" "--tick=$tick" \
        "--ai=$ai" "--seconds=$seconds" "--loss=$loss" "--jitter=$jitter" \
        2>/dev/null | grep '^CROWD ')"
    if [ -z "$line" ]; then
        printf '%8s %9s\n' "$n" "(no result)"
        continue
    fi
    # Pull the fields out by name so a new one in the middle cannot shift the table.
    get() { echo "$line" | tr ' ' '\n' | grep "^$1=" | cut -d= -f2; }
    printf '%8s %9s %11s %11s %10s %10s %10s %9s\n' \
        "$(get clients)" "$(get entities)" "$(get down_kBps)" \
        "$(get down_per_client_kBps)" "$(get up_per_client_kBps)" \
        "$(get pkts_per_client)" "$(get server_ms)" "$(get rollbacks_per_s)"
done

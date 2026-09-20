#!/usr/bin/env bash
#
# Every test suite, once each, with a deadline. The Linux counterpart of run_all.ps1.
#
#   cockpit/tests/run_all.sh
#   cockpit/tests/run_all.sh --only smoke
#   cockpit/tests/run_all.sh --only lint,docs,helmet_*
#   cockpit/tests/run_all.sh --tier core --only apache
#   cockpit/tests/run_all.sh --tier core --list
#   cockpit/tests/run_all.sh --deadline 300
#
# --only and --tier mean what they mean in run_all.ps1: comma lists, the union of the two, and a
# name that matches nothing stops the run. THIS ONE STILL RUNS ONE SUITE AT A TIME. The parallel
# batch, the job slots and the solo retry are run_all.ps1's (lane/gate, 2026-09-19): they were
# built and measured on the Windows machine, where the gate runs, and a scheduler nobody has run
# on Linux would be a second copy of one that nobody has tested. Solo suites run last here too.
#
# TWO THINGS THIS DOES THAT RUNNING THEM BY HAND DOES NOT, both lifted from run_all.ps1
# because both were learned the hard way there.
#
# --fixed-fps, which is the difference between twelve seconds and two minutes. Headless
# still paces its main loop to real time otherwise, so a suite that waits 4400 physics
# frames for the formations to settle spends thirty-seven seconds of wall clock doing
# about two seconds of work.
#
# And a DEADLINE. A GDScript parse error does not fail, it HANGS: the scene never loads,
# so `_ready` never runs, so nothing ever calls quit(), and the run sits there until
# somebody notices. Every suite that ever appeared to take minutes was this. A suite that
# outstays its deadline is killed and reported as TIMEOUT, and the log is scanned for the
# parse error that usually caused it. `lint` runs first now and catches that class in one
# second, which is the difference between a red line and three minutes of waiting.
#
# AND A SUITE THAT PRINTS ENGINE ERRORS FAILS, even if every one of its own checks passed.
# See "the error gate" below. This is not tidiness: the whole of the lift-zone shading had
# been silently dead, and the only evidence was two million lines of stderr that nothing
# was reading.

set -uo pipefail

only=""
tier=""
list=0
# A DEADLINE IS A GUARD AGAINST A HANG, NOT A PERFORMANCE BUDGET. This is the one every suite
# gets unless its row in suites.txt names its own in a fourth column: see run_all.ps1's note,
# and lane/stress on 2026-09-17, where a sixth level took ship_legs from 125.7 s to 197.9 s.
deadline=180
while [ $# -gt 0 ]; do
    case "$1" in
        --only)     only="$2"; shift 2 ;;
        --tier)     tier="$2"; shift 2 ;;
        --list)     list=1; shift ;;
        --deadline) deadline="$2"; shift 2 ;;
        -h|--help)  sed -n '2,27p' "$0" | sed 's/^# \?//'; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cockpit="$(dirname "$here")"
root="$(dirname "$cockpit")"
addon="$root/ashiato-gd/addon"

# THE DOUBLE-PRECISION EDITOR IF THERE IS ONE, and the stock one if there is not.
#
# The world is ten kilometres across and float32 draws its far corner on a half-millimetre
# grid, so the game is built against a Godot compiled with precision=double. That binary
# is not something you can download -- see agents.md -- so the suite runs on whichever is
# present rather than insisting, and says which it used.
#
# It matters that the tests run on the SAME build the game does: the extension is bound to
# one precision or the other, and the two disagree about the width of every real_t
# crossing the boundary. A single-precision run is the right tool for anything that is not
# about float width, and the wrong one for anything that is.
godot=""
for candidate in \
    "$root/_tools/godot-4.7.2-double/godot.linuxbsd.editor.double.x86_64" \
    "$root/_tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64"; do
    if [ -x "$candidate" ]; then godot="$candidate"; break; fi
done
[ -n "$godot" ] || { echo "No Godot found under $root/_tools. Run ashiato-gd/tools/bootstrap-linux.sh." >&2; exit 1; }

case "$godot" in
    *double*) precision="double" ;;
    *)        precision="single" ;;
esac
echo "Godot: $(basename "$godot") ($precision precision)"

# AND THE LIBRARY HAS TO MATCH THE EDITOR. A double editor handed the single library does
# not fail to load it; it aborts inside godot-cpp's class registration ("stack smashing
# detected") before any suite prints a line. So if the double editor is here and its library
# is not, this says so and runs on the stock pair instead -- a fallback that is loud about
# being one, because the silent kind cost a morning.
if [ "$precision" = double ] && [ ! -f "$cockpit/addons/ashiato/bin/ashiato_gd.double.so" ]; then
    echo "  no ashiato_gd.double.so in cockpit/addons/ashiato/bin/ -- falling back to the stock editor." >&2
    echo "  Build it with: ashiato-gd/tools/bootstrap-linux.sh --double" >&2
    godot="$root/_tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64"
    precision="single"
    [ -x "$godot" ] || { echo "No stock Godot under $root/_tools either. Run tools/bootstrap.sh." >&2; exit 1; }
    echo "Godot: $(basename "$godot") ($precision precision)"
fi
if [ ! -f "$cockpit/addons/ashiato/bin/ashiato_gd.so" ]; then
    echo "No ashiato_gd.so in cockpit/addons/ashiato/bin/. Run ashiato-gd/tools/bootstrap-linux.sh." >&2
    exit 1
fi

# THE SUITES COME FROM tests/suites.txt, which run_all.ps1 reads too. Two lists went out
# of step -- the PowerShell one had been missing `water` and `air` for as long as they had
# existed -- so there is one now.
suites=()
# AFTER THE SCENE, A NUMBER IS THAT SUITE'S OWN DEADLINE IN SECONDS and a word is its tiers,
# comma-separated (see suites.txt's header), and almost no row has either. See the note on
# `deadline` above. BOTH ARE PACKED BEFORE THE SCENE and not after it, because a scene is
# `res://tests/x.tscn` and the unpacking below splits on colons: a field written after the scene
# could never be got at again.
while read -r name project scene extra; do
    case "${name:-#}" in ''|'#'*) continue ;; esac
    case "$project" in
        cockpit) where="$cockpit" ;;
        addon)   where="$addon" ;;
        *) echo "suites.txt: unknown project '$project' for $name" >&2; exit 2 ;;
    esac
    # A TRAILING CR FIRST. `read` puts the rest of the line in the LAST field, so on a CRLF
    # checkout the carriage return lands in `its` on every row that has no fourth column --
    # and would be refused below as "not a deadline in seconds", turning a stray line ending
    # into a runner that will not start. git gives Linux LF, so this is belt and braces.
    extra="${extra%$'\r'}"
    its=0
    tags=""
    for word in $extra; do
        case "$word" in
            *[!0-9]*)
                for tag in ${word//,/ }; do
                    case "$tag" in
                        core|net|solo) tags="$tags,$tag" ;;
                        *) echo "suites.txt: '$word' is neither a deadline in seconds nor tiers (core, net, solo) for $name" >&2; exit 2 ;;
                    esac
                done ;;
            *) its="$word" ;;
        esac
    done
    suites+=("$name:$where:$its:${tags#,}:$scene")
done < "$here/suites.txt"
[ ${#suites[@]} -gt 0 ] || { echo "suites.txt listed nothing." >&2; exit 2; }

# WHICH OF THEM. The same rules as run_all.ps1: a name with * or ? is a wildcard, a suite's exact
# name is that suite, anything else matches every suite with it in its name; a name or tier that
# matches nothing stops the run rather than quietly running less than it was told.
# ARRAYS, NOT A WORD-SPLIT STRING: an unquoted `helmet_*` is a glob, and would be matched
# against the files in the current directory before it ever met a suite name.
IFS=", " read -r -a only_list <<< "$only"
IFS=", " read -r -a tier_list <<< "$tier"
all_names=" "
for entry in "${suites[@]}"; do all_names="$all_names${entry%%:*} "; done
name_matches() {
    local name="$1" asked="$2"
    case "$asked" in
        *[*?]*) [[ "$name" == $asked ]] ;;
        *) if [[ "$all_names" == *" $asked "* ]]; then [ "$name" = "$asked" ]; else [[ "$name" == *"$asked"* ]]; fi ;;
    esac
}
for t in "${tier_list[@]}"; do
    case "$t" in core|net|solo) ;; *) echo "No tier '$t'. The tiers are: core, net, solo." >&2; exit 1 ;; esac
done
for asked in "${only_list[@]}"; do
    hit=0
    for entry in "${suites[@]}"; do name_matches "${entry%%:*}" "$asked" && { hit=1; break; }; done
    [ $hit -eq 1 ] || { echo "No suite matches '$asked'." >&2; exit 1; }
done
chosen=()
together=()
alone=()
for entry in "${suites[@]}"; do
    name="${entry%%:*}"; rest="${entry#*:}"; rest="${rest#*:}"; rest="${rest#*:}"; tags="${rest%%:*}"
    take=1
    if [ -n "$only$tier" ]; then
        take=0
        for asked in "${only_list[@]}"; do name_matches "$name" "$asked" && take=1; done
        for t in "${tier_list[@]}"; do [[ ",$tags," == *",$t,"* ]] && take=1; done
    fi
    [ $take -eq 1 ] || continue
    if [[ ",$tags," == *",solo,"* ]]; then alone+=("$entry"); else together+=("$entry"); fi
done
chosen=("${together[@]}" "${alone[@]}")
if [ $list -eq 1 ]; then
    echo "${#chosen[@]} suites: ${#together[@]} one after another, then ${#alone[@]} alone"
    for entry in "${together[@]}"; do printf '  together  %s\n' "${entry%%:*}"; done
    for entry in "${alone[@]}"; do printf '  alone     %s\n' "${entry%%:*}"; done
    exit 0
fi


# A NEW `class_name` NEEDS AN IMPORT BEFORE IT EXISTS.
#
# Godot registers global class names in .godot/global_script_class_cache.cfg, written when
# the project is scanned. Add a script with a new `class_name` and run a test straight
# away and the parser has never heard of it: "Identifier X not declared in the current
# scope". The scene then fails to load, `_ready` never runs, nothing calls quit(), and the
# suite is reported as a TIMEOUT three minutes later -- which looks like a hang in the
# code under test rather than a stale cache.
#
# So any .gd newer than the cache means a rescan first. Cheap when nothing changed.
# CAN THE EDITOR STILL OPEN THE PROJECT, and while we are here, does it know about any
# class_name added since the last run?
#
# This used to be `refresh_class_cache`, which ran the same import and threw the output away.
# It had the answer and discarded it. Every suite below runs the GAME, and the game is more
# forgiving than the editor about one thing in particular: a cyclic dependency between a
# script and a scene. At runtime the loop comes apart in whatever order the loads happen to
# arrive in; in the editor `preload` has to resolve while the script is being COMPILED, so a
# cycle stops a scene loading -- and says nothing about cycles:
#
#   res://marshalling/hand/marshal_rig.tscn:6 - Parse Error: .
#   Failed loading resource: res://marshalling/hand/marshal_rig.tscn.
#
# Sixteen suites passed while that was true. It was found by opening the editor, which is a
# poor last line of defence.
#
# AND IT RUNS EVERY TIME NOW, not only when a .gd is newer than the cache. A cycle can be
# created by editing a .tscn, which that check never looked at.
#
# AN EDITOR IS KNOWN BY ITS COMMAND LINE. This used to be `pgrep -f "godot.*--path.*$project"`
# or `pgrep -x godot`, which is true of every GAME of this project as well -- a headless suite, a
# watch camera -- and of any Godot at all. So whenever anything else was running Godot, the
# import was skipped, the class cache went stale, and new classes failed as "Identifier not
# declared". The PowerShell runner had the same fault by a different route (a window title) and
# on 2026-09-12 it cost six suites. An editor is a Godot started with `-e`/`--editor`; the
# project manager is `-p`/`--project-manager` or the bare executable. Verified by a dry run over
# synthetic command lines only: this machine does not run the Linux script.
is_an_editor() {
    # One process's command line, as /proc writes it: arguments separated by NULs.
    local arg
    local args=()
    while IFS= read -r -d '' arg || [ -n "$arg" ]; do
        args+=("$arg")
    done < "$1"
    [ "${#args[@]}" -gt 0 ] || return 1
    case "$(basename "${args[0]}")" in
        *odot*) ;;
        *) return 1 ;;
    esac
    [ "${#args[@]}" -gt 1 ] || return 0
    for arg in "${args[@]:1}"; do
        case "$arg" in
            -e|--editor|-p|--project-manager) return 0 ;;
        esac
    done
    return 1
}

an_editor_is_open() {
    local cmdline
    for cmdline in /proc/[0-9]*/cmdline; do
        [ -r "$cmdline" ] && is_an_editor "$cmdline" && return 0
    done
    return 1
}

editor_can_open_it() {
    local project="$1" name out
    name="$(basename "$project")"
    [ -d "$project" ] || return 0
    # AND IT STANDS ASIDE WHEN AN EDITOR IS ALREADY OPEN. `--import` writes the project's
    # `.godot` directory and so does a running editor; the two racing over it wedged a run
    # for nineteen minutes with an empty log. The check is worth having and it is not worth
    # having at the cost of the run somebody is watching.
    if an_editor_is_open; then
        printf '  %-20s SKIP   (an editor is open)
' "editor:$name"
        return 0
    fi
    out="$log_dir/import_$name.log"
    timeout 300 "$godot" --headless --import --path "$project" > "$out" 2>&1 || true
    # NAMED FAILURES ONLY. A clean import still prints "Plugin is not attached to debugger",
    # so a bare search for ERROR reports every run as broken and gets turned off by whoever
    # is next in a hurry.
    if ! grep -qE "Failed loading resource|Parse Error|SCRIPT ERROR|Compile Error" "$out"; then
        printf '  %-20s PASS\n' "editor:$name"
        return 0
    fi
    printf '  %-20s FAIL   the editor cannot load this project\n' "editor:$name"
    grep -E "Failed loading resource|Parse Error|SCRIPT ERROR|Compile Error" "$out" | head -4 \
        | sed 's/^/      /'
    echo "      full log: $out"
    return 1
}

# PER WORKTREE, NOT PER USER. This was a single `cockpit_tests` for the whole account until
# 2026-09-17. The runner judges a suite by the `RESULT=` line it reads back from that suite's
# log, so two checkouts running the same suite name at once write the same file and each can
# read the OTHER's verdict. A false red costs a rerun; a false green costs a bad merge, and
# nothing in the output shows either. See the long note at the same place in run_all.ps1.
log_dir="${TMPDIR:-/tmp}/cockpit_tests_$(printf '%s' "$root" | tr 'A-Z' 'a-z' | cksum | cut -d' ' -f1)"
mkdir -p "$log_dir"

# ---- the error gate --------------------------------------------------------------------
#
# A SUITE THAT PRINTS ENGINE ERRORS HAS FAILED, whatever its own checks said.
#
# Every check in the `air` suite passed while the engine wrote four hundred copies of "Can't
# set instance color on a Multimesh that isn't using colors" to a file nobody opened -- and
# `smoke` wrote two million of them, six hundred megabytes, every run. The feature under
# them was dead: the per-instance fade on the lift columns had never once been applied. No
# assertion caught it because no assertion could. The evidence was never in the test's
# output; it was in the stream the test's output was carefully kept separate from.
#
# So stderr and stdout are both read for ERROR and SCRIPT ERROR, and anything found that is
# not on the list below turns a green line red.
#
# THE LIST IS OF MESSAGES, NOT OF SUITES, and that is the whole design of it. Exempting a
# suite would mean the next real error inside it is exempt too. These three are errors a
# test provokes ON PURPOSE, to prove the extension rejects what it should:
allowed_errors='\[ashiato\] field .* has an unknown type|\[ashiato\] add\(\): component was not registered|\[CockpitWorld\] that formation is a circle'
# `lint` is the one suite exempt by name, because printing parse errors is its JOB -- it
# compiles every script in the project and reports which ones the type checker rejects, and
# those rejections are already a red RESULT= line of its own.
gateless="lint"

# What a suite printed that it should not have. Empty means clean.
engine_errors() {
    grep -hE '^(ERROR|SCRIPT ERROR):' "$1" "$1.err" 2>/dev/null \
        | grep -vE "$allowed_errors" || true
}

failed=()
ran=0
started=$SECONDS

# ALWAYS, and only for the projects the chosen suites use: see run_all.ps1, "ALWAYS, NOT ONLY
# ON A FULL GATE". This was `if [ -z "$only" ]`, the guard that cost three lanes an hour each.
case " ${chosen[*]} " in *":$cockpit:"*) editor_can_open_it "$cockpit" || failed+=("editor:cockpit") ;; esac
case " ${chosen[*]} " in *":$addon:"*) editor_can_open_it "$addon" || failed+=("editor:addon") ;; esac

for entry in "${chosen[@]}"; do
    name="${entry%%:*}"; rest="${entry#*:}"
    path="${rest%%:*}"; rest="${rest#*:}"
    its="${rest%%:*}"; rest="${rest#*:}"
    scene="${rest#*:}"
    # ITS OWN DEADLINE, or everybody's.
    its_deadline="$deadline"
    if [ "$its" -gt 0 ]; then its_deadline="$its"; fi
    [ -d "$path" ] || { printf '  %-20s SKIP   (no %s)\n' "$name" "$path"; continue; }

    out="$log_dir/$name.log"
    clock=$SECONDS
    ran=$((ran + 1))
    # stderr to its own file rather than the console: `conformance` deliberately feeds the
    # extension bad input, and the errors it prints are the test working.
    # --xr-mode off, because there is no headset on a build machine and asking for one
    # writes eight lines of OpenXR failure to stderr before anything starts. That noise is
    # not free: the error gate below has to be able to say "this suite printed nothing",
    # and it cannot while every suite prints the same eight lines.
    timeout "$its_deadline" "$godot" --headless --xr-mode off --fixed-fps 120 \
        --path "$path" "$scene" > "$out" 2> "$out.err"
    status=$?
    seconds=$((SECONDS - clock))

    if [ $status -eq 124 ]; then
        printf '  \033[31m%-20s TIMEOUT after %ss\033[0m\n' "$name" "$its_deadline"
        why="$(grep -hoE 'Parse Error.*|Compile Error.*' "$out" "$out.err" 2>/dev/null | head -1)"
        [ -z "$why" ] || printf '      \033[31m%s\033[0m\n' "$why"
        failed+=("$name")
        continue
    fi

    # A RUNAWAY IS CAPPED HERE, after the fact rather than during. Piping stderr through
    # `head` would close the pipe under Godot and kill the run at the first error, which
    # loses the suite; truncating what it left costs nothing and keeps the log directory
    # from carrying half a gigabyte of the same line around between runs.
    if [ "$(stat -c %s "$out.err" 2>/dev/null || echo 0)" -gt 4000000 ]; then
        kept="$(head -c 400000 "$out.err")"
        printf '%s\n\n[run_all.sh] ...truncated: this suite wrote more than 4 MB to stderr.\n' \
            "$kept" > "$out.err"
    fi

    noise=""
    case " $gateless " in
        *" $name "*) ;;
        *) noise="$(engine_errors "$out")" ;;
    esac

    result="$(grep -h "RESULT=" "$out" "$out.err" 2>/dev/null | tail -1)"
    if [[ "$result" != *"RESULT=PASS"* ]]; then
        said="${result:-no RESULT line -- see $out}"
        printf '  \033[31m%-20s FAIL   %4ss  %s\033[0m\n' "$name" "$seconds" "$said"
        failed+=("$name")
    elif [ -n "$noise" ]; then
        # ITS OWN CHECKS PASSED AND IT STILL FAILS, which is exactly the case this is for,
        # so the line says so and shows the first distinct message and how many there were.
        count="$(printf '%s\n' "$noise" | wc -l)"
        first="$(printf '%s\n' "$noise" | head -1 | cut -c1-100)"
        printf '  \033[31m%-20s ERRORS %4ss  %s engine error(s), first: %s\033[0m\n' \
            "$name" "$seconds" "$count" "$first"
        failed+=("$name")
    else
        printf '  \033[32m%-20s PASS   %4ss\033[0m\n' "$name" "$seconds"
    fi
done

echo
if [ ${#failed[@]} -eq 0 ]; then
    printf '\033[32m%d suite(s) passed in %ss.\033[0m\n' "$ran" "$((SECONDS - started))"
    exit 0
fi
printf '\033[31m%d of %d failed: %s\033[0m\n' "${#failed[@]}" "$ran" "${failed[*]}"
printf 'Logs in %s\n' "$log_dir"
exit 1

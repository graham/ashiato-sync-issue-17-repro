#!/usr/bin/env bash
#
# Everything needed to build and test the cockpit game on Linux, from a fresh clone.
#
#   ashiato-gd/tools/bootstrap-linux.sh                # fetch what is missing, then build
#   ashiato-gd/tools/bootstrap-linux.sh --clean        # throw the build tree away first
#   ashiato-gd/tools/bootstrap-linux.sh --fetch-only   # get the dependencies, build nothing
#   ashiato-gd/tools/bootstrap-linux.sh --build-only   # assume they are already there
#   ashiato-gd/tools/bootstrap-linux.sh --double       # the double-precision library instead
#
# The Linux counterpart of build.ps1, which does LESS than this: it assumes the four
# upstream checkouts already exist, because on the machine it was written for they did.
# On a fresh clone they do not, and working out which four repositories at which four
# revisions is most of the work. So this fetches them too.
#
# TWO LIBRARIES, ONE FLAG. Without --double this builds ashiato_gd.so against the stock
# 4.7.2, which is what every game but the cockpit runs on and what cockpit/tests/run_all.sh
# falls back to. With --double it builds ashiato_gd.double.so against the API file of the
# editor tools/build_godot_double.sh produces, in a build tree of its own, and installs it
# only into games whose .gdextension asks for a linux double entry -- today, the cockpit.
# The two are different binaries, not a setting: every real_t that crosses the boundary is
# a different width, and a double editor handed the single library aborts in godot-cpp's
# class registration with "stack smashing detected", which is the crash this flag exists to
# make impossible. It was reachable until 2026-09-11 because the Linux entries in the
# .gdextension carried no precision tag at all.
#
# THE REVISIONS COME FROM upstream.lock and are not written down here. That file is what
# tools/update_upstream.ps1 maintains, and a second copy of three hashes is a second copy
# to forget to update -- at which point this script silently builds a different library
# from the one the lock file claims produced the binary.

set -euo pipefail

fetch=1
build=1
clean=0
double=0
for arg in "$@"; do
    case "$arg" in
        --fetch-only) build=0 ;;
        --build-only) fetch=0 ;;
        --clean)      clean=1 ;;
        --double)     double=1 ;;
        -h|--help)    sed -n '2,33p' "$0" | sed 's/^# \?//'; exit 0 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gd_root="$(dirname "$here")"
root="$(dirname "$gd_root")"

# The build tree is kept OUT of the source tree, exactly as build.ps1 does. CMake writes a
# swarm of small temporary files under _deps, and this repository has lived on an SMB
# share where those writes get dropped.
#
# AND IT IS PER CHECKOUT, which it was not: the name was a bare "ashiato-gd-build", one per
# user, and CMakeCache.txt stores the ABSOLUTE source path it was generated from. So a
# second clone of this repository could not build at all -- configure stops with "The
# source ... does not match the source ... used to generate cache", which names both paths
# and still does not say that the cache belongs to somebody else's working tree. Two
# checkouts cannot share one build tree even in principle; that is what the cache check is
# for. So the path carries a digest of the source directory and they get one each.
#
# cksum rather than a hash command, because it is POSIX and md5sum/sha256sum are not
# everywhere. Only distinctness is wanted here, not secrecy.
build_key="$(printf '%s' "$gd_root" | cksum | cut -d' ' -f1)"
build_dir="${ASHIATO_GD_BUILD_DIR:-$HOME/.cache/ashiato-gd-build-$build_key}"

# The binary's name and the download URL are NOT here: tools/get_godot.sh owns those, and
# this script only needs to know where it put them.
godot_version="4.7.2"
godot_dir="$root/_tools/godot-$godot_version"

# THE DOUBLE BUILD GETS ITS OWN TREE AND ITS OWN API FILE. godot-cpp generates its bindings
# from extension_api.json at configure time, and the double editor's file differs from the
# stock one in the hash of every method that takes a real_t -- so the two cannot share a
# CMake cache, and a tree configured for one precision must never be reused for the other.
# The double API file is TRACKED (tools/build_godot_double.sh compares its dump against
# it rather than writing over it), so this needs no editor to be present, only the file.
lib_name="ashiato_gd.so"
double_flags=()
if [ "$double" = 1 ]; then
    godot_dir="$root/_tools/godot-$godot_version-double"
    build_dir="${ASHIATO_GD_BUILD_DIR:-$HOME/.cache/ashiato-gd-build-$build_key-double}"
    lib_name="ashiato_gd.double.so"
    double_flags=(-DASHIATO_GD_DOUBLE=ON)
    [ -f "$godot_dir/extension_api.json" ] || die "no $godot_dir/extension_api.json.
  The double library is bound against the double editor's API file, which is tracked in
  git beside where tools/build_godot_double.sh installs that editor. Check the file out."
fi

say() { printf '\033[1m%s\033[0m\n' "$*"; }
die() { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }

# ---- what has to be on the machine already -----------------------------------
#
# Named individually rather than as one "install build tools" line, because the thing you
# are missing is the thing you want to be told about.
missing=()
for tool in git curl unzip cmake g++ python3; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
if [ ${#missing[@]} -gt 0 ]; then
    die "Not installed: ${missing[*]}
  Arch:   sudo pacman -S --needed git curl unzip cmake gcc python ninja
  Debian: sudo apt install git curl unzip cmake g++ python3 ninja-build
  Fedora: sudo dnf install git curl unzip cmake gcc-c++ python3 ninja-build

  ninja is the odd one out: it is optional, and the build falls back to make
  without it. It is in the line because it is a good deal faster and you are
  installing things anyway."
fi

# ninja is what CMakeLists.txt documents and is a good deal faster, but make is always
# there. Use whichever is present rather than insisting on one.
if command -v ninja >/dev/null 2>&1; then
    generator="Ninja"
else
    generator="Unix Makefiles"
fi

# ---- the pinned revisions ----------------------------------------------------
lock="$gd_root/upstream.lock"
[ -f "$lock" ] || die "upstream.lock not found at $lock"

pin() {
    # `name = hash`, ignoring the comment lines that make up most of that file.
    local value
    value="$(sed -n "s/^$1[[:space:]]*=[[:space:]]*\([0-9a-f]\{7,\}\).*/\1/p" "$lock" | head -1)"
    [ -n "$value" ] || die "no '$1' revision in upstream.lock"
    printf '%s' "$value"
}

# godot-cpp is NOT in upstream.lock, and that is not an oversight: it is pinned by API
# version rather than by revision -- GODOTCPP_API_VERSION in CMakeLists.txt, against the
# extension_api.json dumped below. There is no godot-cpp branch for 4.7; the newest is
# 4.5, and the custom API file is what makes it bind to 4.7 anyway.
godot_cpp_branch="4.5"

# ---- fetch -------------------------------------------------------------------

# Clone if absent, and in both cases end up ON the pinned revision. An existing checkout
# left on the wrong revision is the failure mode worth catching: it builds, it runs, and
# it is not the library upstream.lock says it is.
checkout() {
    local dir="$1" url="$2" want="$3"
    if [ ! -d "$dir/.git" ]; then
        say "  cloning $(basename "$dir")"
        git clone --quiet "$url" "$dir"
    fi
    local at
    at="$(git -C "$dir" rev-parse --short HEAD)"
    if [ "${want:0:7}" != "${at:0:7}" ]; then
        say "  $(basename "$dir"): $at -> ${want:0:7}"
        git -C "$dir" fetch --quiet --all --tags
        git -C "$dir" checkout --quiet "$want"
    else
        say "  $(basename "$dir"): $at"
    fi
}

# BOTH UPSTREAMS BUILD WITH -Werror, AGAINST MSVC.
#
# Neither has ever been compiled by GCC 16, which raises three warning families they have
# no reason to have accounted for. They are not about this code:
#
#   stringop-overflow  a known GCC false positive inside <bits/stl_construct.h> at -O2
#   invalid-offsetof   offsetof on a non-standard-layout type -- conditionally-supported
#                      by the standard, not undefined
#   array-bounds       the same optimiser pass as stringop-overflow
#
# So each is downgraded from an error to a warning and -Werror stays on for everything
# else. Done by appending INSIDE the same target_compile_options list, which is the only
# place that works: those options are PRIVATE to the target and therefore land after
# anything CMAKE_CXX_FLAGS could say, so a -Wno-error passed at configure time is
# overridden by the -Werror it was meant to relax.
#
# Applied on every run and idempotent, because these are gitignored checkouts: a
# re-clone, or update_upstream moving a pin, silently reverts it.
relax_werror() {
    local file="$1"
    grep -q -- '-Wno-error=stringop-overflow' "$file" && return 0
    grep -q -- '^            -Werror$' "$file" || return 0
    python3 - "$file" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
p.write_text(s.replace("            -Werror\n", "            -Werror\n"
    "            # GCC 16; see relax_werror in ashiato-gd/tools/bootstrap-linux.sh.\n"
    "            -Wno-error=stringop-overflow\n"
    "            -Wno-error=invalid-offsetof\n"
    "            -Wno-error=array-bounds\n", 1))
PY
    say "  relaxed -Werror for GCC in $(basename "$(dirname "$file")")/CMakeLists.txt"
}

# FIXES TO UPSTREAM THAT WE DEPEND ON, kept as patches in tools/patches/ and applied on
# every fetch.
#
# These checkouts are gitignored and pinned by upstream.lock, so anything edited in place
# is lost on a re-clone and on the next revision bump -- which would silently take a
# behaviour the game relies on with it. A patch that fails to apply is a HARD ERROR for
# the same reason: building against an upstream that no longer has the fix, without
# saying so, is the failure this whole arrangement exists to prevent.
#
# Named `<repo>-<what-it-does>.patch` and applied with -p1 from the repo root. Each one
# should be upstreamable and should say, in its own comments, what it is for.
apply_patches() {
    local dir="$1" name="$2" patch
    for patch in "$here/patches/$name"-*.patch; do
        [ -e "$patch" ] || continue
        # Already applied -- a re-run over an unchanged checkout, which is the normal case.
        if git -C "$dir" apply --reverse --check "$patch" >/dev/null 2>&1; then
            say "  $(basename "$patch"): already applied"
            continue
        fi
        if ! git -C "$dir" apply --check "$patch" >/dev/null 2>&1; then
            die "$(basename "$patch") does not apply to $name at $(git -C "$dir" rev-parse --short HEAD).
  Upstream has moved under it. Rework the patch, or drop it if the fix has landed
  upstream -- but do not build without it: see the patch header for what it fixes."
        fi
        git -C "$dir" apply "$patch"
        say "  $(basename "$patch"): applied"
    done
}

if [ "$fetch" = 1 ]; then
    say "Dependencies, beside ashiato-gd:"
    checkout "$root/ashiato"      https://github.com/ErikGoldman/ashiato.git      "$(pin ashiato)"
    checkout "$root/ashiato-sync" https://github.com/ErikGoldman/ashiato-sync.git "$(pin 'ashiato-sync')"
    checkout "$root/box3d"        https://github.com/erincatto/box3d.git          "$(pin box3d)"
    relax_werror "$root/ashiato/CMakeLists.txt"
    relax_werror "$root/ashiato-sync/CMakeLists.txt"
    apply_patches "$root/ashiato-sync" "ashiato-sync"

    if [ ! -d "$root/godot-cpp/.git" ]; then
        say "  cloning godot-cpp ($godot_cpp_branch)"
        git clone --quiet --branch "$godot_cpp_branch" \
            https://github.com/godotengine/godot-cpp.git "$root/godot-cpp"
    else
        say "  godot-cpp: $(git -C "$root/godot-cpp" rev-parse --short HEAD)"
    fi

    say "Godot $godot_version:"
    # HANDED TO tools/get_godot.sh, which is the one copy of this step.
    #
    # It used to be spelled out here, and that made this script the only way to get an
    # engine -- so a checkout that wanted nothing but topdowntest's GDScript tests still had
    # to satisfy the compiler gate above before it could download one. The download has
    # nothing to do with the C++ toolchain; it is shared with tools/bootstrap.sh, and a
    # second copy of it is a second copy to forget.
    #
    # It also dumps extension_api.json if it is somehow absent. That matters here more than
    # anywhere: godot-cpp's 4.5 branch has never heard of 4.7, so left to itself it binds
    # against 4.5's API and the extension loads and then calls the wrong methods -- the same
    # failure the double-precision note in CMakeLists.txt describes, for the same reason.
    # The double directory is not get_godot.sh's to fill: its API file is tracked and its
    # editor is built, not downloaded. The stock one is still fetched, because the addon's
    # own suites run on whichever editor is to hand.
    "$root/tools/get_godot.sh" --version "$godot_version" || die "tools/get_godot.sh failed"
fi

[ "$build" = 1 ] || { say "Fetched. Not building."; exit 0; }

# AND VERIFIED AGAIN HERE, OUTSIDE THE FETCH.
#
# apply_patches only runs when we fetch, so --build-only compiled against whatever the
# checkout happened to hold. These checkouts are ordinary git working trees that nothing
# tracks, so a patch in one is undone by any checkout, reset or pull somebody runs in it,
# and nothing says so.
#
# That is how the Windows and Linux builds came to disagree: the shared ashiato-sync
# working tree lost ashiato-sync-baseline-on-mask-open.patch, Linux had built before it
# went and Windows built after, and the library that came out loads and runs and is
# silently wrong -- a crew in one aeroplane who cannot see each other. tools/build.ps1
# grew the same gate at the same time, so neither platform can now build past a missing
# patch.
#
# MATCHED BY LONGEST PREFIX rather than globbing "$name-*": `ashiato-sync` starts with
# `ashiato`, so the obvious glob hands sync's patches to the wrong checkout.
verify_patches() {
    local patch base owner dir name any=0
    say "Patches:"
    for patch in "$here"/patches/*.patch; do
        [ -e "$patch" ] || continue
        any=1
        base="$(basename "$patch")"
        owner=""
        for name in ashiato-sync ashiato box3d; do
            case "$base" in
                "$name"-*)
                    if [ ${#name} -gt ${#owner} ]; then owner="$name"; fi
                    ;;
            esac
        done
        [ -n "$owner" ] || die "$base names no known checkout (ashiato-sync, ashiato, box3d)."
        dir="$root/$owner"
        if [ ! -d "$dir/.git" ]; then
            say "  $base: cannot verify -- $owner at $dir is not a git checkout"
            continue
        fi
        # --reverse --check succeeds only where the patch is ALREADY in the tree, which is
        # the same test apply_patches uses to decide there is nothing to do.
        if git -C "$dir" apply --reverse --check "$patch" >/dev/null 2>&1; then
            say "  $base: applied"
            continue
        fi
        die "$base is NOT applied to $owner at $(git -C "$dir" rev-parse --short HEAD).
  A library built without it loads and is silently wrong; see the patch header.
  Apply it:  git -C '$dir' apply '$patch'
  Or re-run this script without --build-only, which applies every patch."
    done
    if [ "$any" = 0 ]; then say "  none"; fi
}

verify_patches

# ---- build -------------------------------------------------------------------

[ -f "$godot_dir/extension_api.json" ] || die "extension_api.json missing; run without --build-only"

if [ "$clean" = 1 ] && [ -d "$build_dir" ]; then
    say "Cleaning $build_dir"
    rm -rf "$build_dir"
fi

# EVERY GAME MODULE, not just the cockpit's.
#
# build.ps1 takes one -With<Module> at a time, which is right when you are iterating on
# one. It is wrong for a test run: tests/run_all.sh runs the addon's suites as well as the
# game's, and resim_settles, resim_events, two_clients and predict_all all build a
# DrivingWorld. Against a cockpit-only library that class does not exist, so the scene
# never finishes loading, never calls quit(), and the suite is reported as a TIMEOUT three
# minutes later -- which looks exactly like a hang in the code under test.
#
# The modules are cheap: they are separate .cpp files in one library, and sync and physics
# are already being built for the cockpit either way.
say "Configuring ($generator${double:+, double precision})"
cmake -S "$gd_root" -B "$build_dir" \
    -G "$generator" \
    -DCMAKE_BUILD_TYPE=Release \
    -DASHIATO_GD_WITH_COCKPIT=ON \
    -DASHIATO_GD_WITH_DRIVING=ON \
    -DASHIATO_GD_WITH_VR=ON \
    -DGODOTCPP_CUSTOM_API_FILE="$godot_dir/extension_api.json" \
    -DASHIATO_GD_UPSTREAM_REV="$(pin ashiato)" \
    "${double_flags[@]}" \
    >/dev/null

say "Building (this takes a while the first time: godot-cpp is ~2100 generated files)"
cmake --build "$build_dir" --target ashiato_gd -j "$(nproc)"

# ---- install -----------------------------------------------------------------
#
# CMake writes into ashiato-gd/addon/, which is build output and gitignored. The game's
# own copy is TRACKED, because that is what makes cockpit runnable from a clone with no
# C++ toolchain -- so the binary is copied across exactly as build.ps1 does it.
built="$gd_root/addon/addons/ashiato/bin/$lib_name"
[ -f "$built" ] || die "build produced no $built"

# EVERY SIBLING THAT ALREADY HAS THE ADDON, discovered, not a list -- which is what
# build.ps1 has always done on Windows and this loop used to spell as `for game in
# "$root/cockpit"`.
#
# That asymmetry is why racer has an ashiato_gd.dll in git and no ashiato_gd.so: the
# Windows build pushed the library into every game that had an addons/ashiato/bin, the
# Linux build pushed it into the cockpit alone, and racer's own .gdextension names a
# linux.editor.x86_64 file that has therefore never existed. On Linux the game opens,
# reports that it cannot open the library, and every AshiatoWorld in it is missing.
#
# Only EXISTING installs are updated: this copies the addon forward, it does not decide
# which projects should have one.
#
# AND ONLY WHERE THE .gdextension ASKS FOR THAT PRECISION. racer and vrplayground-2 carry
# precompiled single-precision godotsteam binaries and can never run in a double editor, so
# a double library copied into them would be dead weight that a future entry might one day
# match. A game says which libraries it wants by naming them; this copies what is named.
installed=0
for bin_dir in "$root"/*/addons/ashiato/bin; do
    [ -d "$bin_dir" ] || continue
    # ashiato-gd/addon is where the compiler just wrote; copying it onto itself is not
    # an install and saying so would be a lie.
    [ "$bin_dir" = "$(dirname "$built")" ] && continue
    if ! grep -q "$lib_name" "$(dirname "$bin_dir")"/*.gdextension 2>/dev/null; then
        say "Skipped ${bin_dir#$root/}: its .gdextension names no $lib_name"
        continue
    fi
    cp "$built" "$bin_dir/"
    say "Installed into ${bin_dir#$root/}/$lib_name"
    installed=$((installed + 1))
done
[ "$installed" -gt 0 ] || say "No sibling game names $lib_name in its .gdextension."

say ""
say "Done. Run the suites with:  cockpit/tests/run_all.sh"

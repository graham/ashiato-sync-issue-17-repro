"""Prove that `tests/runabout.gd` can actually fail, by putting back the bugs this lane really made.

    python cockpit/tests/runabout_mutants.py            # every mutant
    python cockpit/tests/runabout_mutants.py <name>     # one of them

"One mutant per check, and the mutant must be the bug -- not the source's number"
(`modelling_here.md` section 6). Every mutant below is a mistake that was actually in the model at
some point today and that a picture, not a check, found. Encoding them is the best use of a mutant
there is: the four faults cannot silently come back.

THE RUNNER OBEYS THE FIVE-OCCURRENCE RULE and it had to, immediately. It asserts its anchor is
present EXACTLY ONCE, prints whether it applied, refuses to run the suite if it did not, and
restores the whole file text rather than replacing the mutant back. Three of these four mutants
printed "not applied" on the first attempt because the anchors were typed with "\\n" against a file
that is 523 CRLF line endings and no bare LF -- which is the first case in that rule's list, met
again, in a runner written by somebody who had just read it. The anchor takes the file's own line
ending before it is looked for now.
"""

import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
TARGET = os.path.join(PROJECT, "objects", "vehicles", "ships", "runabout.gd")
ENGINE = os.path.join(os.path.dirname(PROJECT), "_tools", "godot-4.7.2-double",
                      "godot.windows.editor.double.x86_64.console.exe")

# name -> (anchor, replacement, the check it must turn red)
MUTANTS = {
    # THE BUG THAT ACTUALLY HAPPENED, and the reason the suite exists. Sections that step straight
    # over the waterline: `HullLoft` colours a row GAP by that gap's midpoint, so no gap lands
    # inside BOOT and the stripe is never drawn at all. The hull stays perfectly correct.
    "no_rows_straddling_the_waterline": (
        "\t[0.103, 0.997, 0.028, 0.004],\n\t[-0.103, 0.992, 0.058, 0.007],\n",
        "\t[-0.52, 0.990, 0.045, 0.006],\n",
        "the_white_stripe_is_actually_drawn"),
    # THE SECOND HALF OF THE SAME TRAP: once two rows straddle the waterline the stripe's WIDTH is
    # the row spacing and not `BOOT`, so the first attempt painted 0.14 m of white on a boat with
    # 0.50 m of freeboard -- a hull banded like a lifebuoy.
    "the_stripe_at_the_first_attempts_width": (
        "\t[0.103, 0.997, 0.028, 0.004],\n\t[-0.103, 0.992, 0.058, 0.007],\n",
        "\t[0.206, 0.997, 0.028, 0.004],\n\t[-0.206, 0.992, 0.058, 0.007],\n",
        "the_white_stripe_is_actually_drawn"),
    # A DECK "WARMED UP" a little against the topsides, which is what happens to anybody who takes
    # the deck's colour off a photograph: it reads lighter there only because it faces the sky.
    "a_lighter_deck_than_the_topsides": (
        "\treturn SEAM if i % 2 == 1 else MAHOGANY",
        "\treturn SEAM if i % 2 == 1 else Color(0.56, 0.27, 0.18)",
        "the_deck_is_the_same_wood_as_the_topsides"),
    # THE RUB RAIL HUNG OUTBOARD OF THE SHEER again. A published beam is measured over the rail, so
    # a rail proud of the planking makes the boat wider than the figure she was built from.
    "the_rub_rail_hung_outboard_again": (
        "\t\t\tvar in_a := Vector3(x0 - RAIL_WIDE * side, top0, z0)",
        "\t\t\tvar a2 = a\n\t\t\ta = Vector3(x0 + 0.03 * side, top0, z0)\n"
        "\t\t\tb = Vector3(x1 + 0.03 * side, top1, z1)\n\t\t\tvar in_a := Vector3(a2.x, top0, z0)",
        "her_drawn_beam_is_the_published_one"),
    # THE DECK'S CELLS RUNNING PAST THE COVERING BOARD at the stem, where there is no room for seven
    # planks: the last cells come out drawn backwards, which shows in no picture at all.
    "deck_cells_unclamped_at_the_stem": (
        "\t\tat = minf(at + SEAM_WIDE, field_out)\n\t\tbounds.append(at)\n"
        "\t\tat = minf(at + plank, field_out)\n\t\tbounds.append(at)",
        "\t\tat += SEAM_WIDE\n\t\tbounds.append(at)\n\t\tat += plank\n\t\tbounds.append(at)",
        # NOT the winding check, though that is what the fault first showed up as. `_facet_up` forces
        # every deck triangle to face up whatever order its corners arrive in, so it CURES the
        # backwards faces on its own and the winding check now passes with the clamp removed. The
        # fault the clamp actually prevents is the one still left: at the stem the cells walk out to
        # 0.19 m on a boat 0.03 m wide there, so the planking hangs over the side.
        #
        # Two fixes made for one symptom, and only one of them was load-bearing for it. That is worth
        # knowing: a mutant that stops being caught has not gone away, it has moved.
        "no_deck_plank_hangs_over_her_side"),
}


def run_one(name):
    anchor, replacement, expect = MUTANTS[name]
    original = open(TARGET, encoding="utf-8", newline="").read()
    ending = "\r\n" if "\r\n" in original else "\n"
    anchor = anchor.replace("\n", ending)
    replacement = replacement.replace("\n", ending)
    count = original.count(anchor)
    if count != 1:
        print("%-38s NOT APPLIED: anchor appears %d times, not once" % (name, count))
        return False
    open(TARGET, "w", encoding="utf-8", newline="").write(original.replace(anchor, replacement, 1))
    print("%-38s APPLIED" % name)
    try:
        run = subprocess.run(
            [ENGINE, "--headless", "--xr-mode", "off", "--path", PROJECT, "--fixed-fps", "120",
             "res://tests/runabout.tscn"],
            capture_output=True, text=True, timeout=240)
        output = run.stdout + run.stderr
    except subprocess.TimeoutExpired:
        print("%-38s   the suite HUNG, which is what a parse error does here" % "")
        return False
    finally:
        open(TARGET, "w", encoding="utf-8", newline="").write(original)
    result = [line.strip() for line in output.splitlines() if "RESULT=" in line]
    caught = any(expect in line for line in result)
    print("%-38s   %s" % ("", result[0] if result else "NO RESULT= LINE: it parse-errored or hung"))
    print("%-38s   %s expected %s" % ("", "CAUGHT by" if caught else "MISSED by", expect))
    return caught


def main():
    wanted = sys.argv[1:] or sorted(MUTANTS)
    missed = [name for name in wanted if not run_one(name)]
    print()
    if missed:
        print("RESULT=FAIL mutants not caught: %s" % ", ".join(missed))
        sys.exit(1)
    print("RESULT=PASS all %d mutants caught by the check each was written for" % len(wanted))


if __name__ == "__main__":
    main()

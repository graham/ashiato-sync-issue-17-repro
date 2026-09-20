"""THE P-38L'S MUTANTS: `tests/p38.gd` against one at a time, each the bug its check exists to catch.

    python cockpit/craft/p38/mutants.py [godot console exe]

The runner is `tools/mutants.py`: it refuses a mutant whose anchor is not in its file exactly once, restores the whole
file afterwards, and calls a mutant KILLED only when the check it names is red; other checks it turns red are printed.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
from mutants import run_all  # noqa: E402

AIRFRAME = "objects/vehicles/p38_airframe.gd"

# (name, file, anchor, replacement, the check it must turn red)
MUTANTS = [
    ("both propellers turning clockwise, as a single-engined kit would make them", AIRFRAME,
     "PROP_PITCH, side, 0.26, paint)", "PROP_PITCH, 1.0, 0.26, paint)",
     "the_propellers_turn_opposite_ways_outboard_at_the_top"),
    ("the main doors at their first width, 0.20 m either side of the boom", AIRFRAME,
     "const MAIN_DOOR: Vector3 = Vector3(4.20, 5.95, 0.28)", "const MAIN_DOOR: Vector3 = Vector3(4.20, 5.95, 0.20)",
     "no_leg_ever_passes_through_a_door"),
    ("the dihedral from the root, as a one-piece wing would have it", AIRFRAME,
     "return 0.0 if a <= WING_JOINT else (a - WING_JOINT) * tan(DIHEDRAL)", "return a * tan(DIHEDRAL)",
     "the_wing_has_its_edges_and_its_dihedral_from_the_joint"),
    ("the booms at their drawn 4.842 m apart, not the printed 96 in either side", AIRFRAME,
     "const PRINTED_BOOM_OUT: float = 2.438", "const PRINTED_BOOM_OUT: float = 2.421",
     "two_booms_96_in_either_side_and_the_tail_between"),
    ("the main wheels stowed where they first were, low in the boom", AIRFRAME,
     "const MAIN_STOWED: Vector3 = Vector3(2.438, -0.06, 5.44)", "const MAIN_STOWED: Vector3 = Vector3(2.46, -0.12, 5.30)",
     "the_gear_folds_aft_inside_the_booms_and_the_gondola"),
    ("the outer flap lofted between its ends only, its trailing edge a chord across the wing's curve", AIRFRAME,
     "stood 6 cm off the drawn edge 4.0 m out.\n\tvar outs: Array = [o0]\n\tfor row in WING_ROWS:",
     "stood 6 cm off the drawn edge 4.0 m out.\n\tvar outs: Array = [o0]\n\tfor row in []:",
     "the_wing_has_its_edges_and_its_dihedral_from_the_joint"),
]


if __name__ == "__main__":
    run_all("res://tests/p38.tscn", MUTANTS)

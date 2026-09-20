"""THE P-47D-30'S MUTANTS: `tests/p47.gd` against one at a time, each the bug its check exists to catch.

    python cockpit/craft/p47/mutants.py [godot console exe]

The runner is `tools/mutants.py`: it refuses a mutant whose anchor is not in its file exactly once, restores the whole
file afterwards, and calls a mutant KILLED only when the check it names is red and no other is.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
from mutants import run_all  # noqa: E402

AIRFRAME = "objects/vehicles/p47_airframe.gd"

# (name, file, anchor, replacement, the check it must turn red)
MUTANTS = [
    ("the mains folding without shortening", AIRFRAME,
     "_telescoping_leg(\"MainGear\" + named, pivot, axle, well, TELESCOPE,",
     "_telescoping_leg(\"MainGear\" + named, pivot, axle, well, 0.0,",
     "the_mains_shorten_as_they_fold"),
    ("the inner doors where they first were, hinged at 0.70 m and opened 85 degrees", AIRFRAME,
     "const INNER_DOOR: Vector4 = Vector4(3.12, 4.02, 0.62, 1.55)", "const INNER_DOOR: Vector4 = Vector4(3.12, 4.02, 0.70, 1.55)",
     "no_leg_ever_passes_through_a_door"),
    ("the wing built to its drawn span, not its printed one", AIRFRAME,
     "const WING_STRETCH: float = PRINTED_SPAN / DRAWN_SPAN", "const WING_STRETCH: float = 1.0",
     "the_drawn_aeroplane_is_the_published_length_and_span"),
    ("the propeller turning anticlockwise", AIRFRAME,
     "PROP_PITCH,\n\t\t1.0, 0.24, paint)", "PROP_PITCH,\n\t\t-1.0, 0.24, paint)",
     "the_propeller_is_the_printed_size_and_turns_clockwise"),
    ("the belly at a slim fighter's depth, the turbo's ducting left out", AIRFRAME,
     "[2.95, -1.120], [3.45, -1.120]", "[2.95, -1.000], [3.45, -1.000]",
     "it_has_the_jugs_belly_canopy_fin_and_eight_guns"),
    ("the tail wheel stowed under the belly", AIRFRAME,
     "const TAIL_STOWED: Vector2 = Vector2(8.42, -0.22)", "const TAIL_STOWED: Vector2 = Vector2(8.42, -0.62)",
     "the_mains_fold_inward_and_the_tail_wheel_forward_inside_the_skin"),
    ("parked level on the mains, the tail wheel in the air", AIRFRAME,
     "return _three_point(Vector2(MAIN_AXLE.z, MAIN_AXLE.y), MAIN_TYRE.x * 0.5, TAIL_AXLE, TAIL_TYRE.x * 0.5)",
     "return Transform3D.IDENTITY",
     "it_parks_tail_down_on_three_points"),
]


if __name__ == "__main__":
    run_all("res://tests/p47.tscn", MUTANTS)

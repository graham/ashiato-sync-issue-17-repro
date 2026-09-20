"""THE P-51D'S MUTANTS: `tests/p51.gd` against one at a time, each the bug its check exists to catch.

    python cockpit/craft/p51/mutants.py [godot console exe]

The runner is `tools/mutants.py`: it refuses a mutant whose anchor is not in its file exactly once, restores the whole
file afterwards, and calls a mutant KILLED only when the check it names is red and no other is.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
from mutants import run_all  # noqa: E402

AIRFRAME = "objects/vehicles/p51_airframe.gd"
BASE = "objects/vehicles/warbird_airframe.gd"

# (name, file, anchor, replacement, the check it must turn red)
MUTANTS = [
    ("the inner doors shut before the legs move", BASE,
     "	if amount >= DOORS_SHUT_FROM:\n		return 1.0 - smoothstep(DOORS_SHUT_FROM, 1.0, amount)",
     "	if amount >= 0.5:\n		return 1.0 - smoothstep(0.5, 0.6, amount)",
     "the_inner_doors_open_before_a_leg_moves_and_shut_after"),
    ("the stowed wheels in the drawing's circles, through the thin root", AIRFRAME,
     "const MAIN_WELL: Vector3 = Vector3(0.69, -0.50, 3.40)", "const MAIN_WELL: Vector3 = Vector3(0.69, -0.50, 3.13)",
     "the_mains_fold_inward_and_the_tail_wheel_forward_inside_the_skin"),
    ("the propeller turning anticlockwise", AIRFRAME,
     "PROP_PITCH,\n		1.0, 0.30, paint)", "PROP_PITCH,\n		-1.0, 0.30, paint)",
     "the_propeller_is_the_printed_size_and_turns_clockwise"),
    ("the elevators going down as far as up", BASE,
     "	var angle: float = -_pitch * (elevator_up if _pitch > 0.0 else elevator_down)",
     "	var angle: float = -_pitch * elevator_up",
     "the_hinged_surfaces_move_the_right_way_and_come_back"),
    # THE WHOLE DEEP PART, not one row: moving the 4.50 row alone left the 4.80 row 9 mm short of the measured depth, and
    # that mutant stayed green, because a scoop with one shallow station is not shallow.
    ("the scoop drawn 5 cm shallow", AIRFRAME,
     "[4.20, -1.153, 0.28], [4.50, -1.170, 0.28], [4.80, -1.161, 0.28]",
     "[4.20, -1.103, 0.28], [4.50, -1.120, 0.28], [4.80, -1.111, 0.28]",
     "it_has_the_mustangs_scoop_canopy_fin_and_guns"),
    ("the wing's dihedral at the printed 5 degrees instead of the drawn 5.7", AIRFRAME,
     "const WING_MID: Vector2 = Vector2(-0.593, 0.0993)", "const WING_MID: Vector2 = Vector2(-0.593, 0.0875)",
     "the_wing_has_the_measured_edges_dihedral_and_area"),
    ("the tail wheel stowed under the belly", AIRFRAME,
     "const TAIL_STOWED: Vector2 = Vector2(7.20, -0.24)", "const TAIL_STOWED: Vector2 = Vector2(7.20, -0.60)",
     "the_mains_fold_inward_and_the_tail_wheel_forward_inside_the_skin"),
    ("the main tyres built at the 27-inch published size on the drawn axle", AIRFRAME,
     "const MAIN_TYRE: Vector2 = Vector2(0.70, 0.22)", "const MAIN_TYRE: Vector2 = Vector2(0.686, 0.22)",
     "the_tyres_stand_on_the_ground_level_and_three_point"),
    ("parked level on the mains, the tail wheel in the air", AIRFRAME,
     "return _three_point(Vector2(MAIN_AXLE.z, MAIN_AXLE.y), MAIN_TYRE.x * 0.5, TAIL_AXLE, TAIL_TYRE.x * 0.5)",
     "return Transform3D.IDENTITY",
     "it_parks_tail_down_on_three_points"),
    ("parked tail down on round tyres, a faceted tyre's corner through the floor", "objects/vehicles/warbird_airframe.gd",
     "axle - turn * axle + Vector3.UP * lift)", "axle - turn * axle)",
     "it_parks_tail_down_on_three_points"),
]


if __name__ == "__main__":
    run_all("res://tests/p51.tscn", MUTANTS)

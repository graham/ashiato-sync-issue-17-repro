"""The track's mutants: each is one of the faults `PermanentWay` fixed on 2026-09-19, typed back, and the check in
`tests/track_drawn.gd` it must turn red. Run from the lane with its own engine and TEMP:

    WARBIRDS_TEMP=C:/gg-wt/trains-temp python cockpit/craft/train/track_mutants.py <godot console exe>

The runner is `tools/mutants.py` (lane/warbirds): it refuses an anchor that is not in its file exactly once, prints
"applied", and restores the file's whole text afterwards.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
from mutants import run_all  # noqa: E402

RAILS = "rails_at.append(Transform3D(facing.scaled_local(Vector3(1.0, 1.0, run)), middle))"
MUTANTS = [
    ("the rails stretched with Basis.scaled, along the world's z: the dashes",
     "world/permanent_way.gd", RAILS,
     "rails_at.append(Transform3D(facing.scaled(Vector3(1.0, 1.0, run)), middle))",
     "each_length_of_rail_runs_from_one_waypoint_to_the_next"),
    ("the rails drawn up from the railhead, so the wheels stand in them",
     "world/permanent_way.gd", RAILS,
     "rails_at.append(Transform3D(facing.scaled_local(Vector3(1.0, 1.0, run)), middle + facing.y * RAIL_HIGH))",
     "and_the_railhead_is_the_waypoints_line"),
    ("the old typed 1.44 between the rails' middles",
     "world/permanent_way.gd", "const RAIL_CENTRES: float = GAUGE + HEAD_WIDE",
     "const RAIL_CENTRES: float = 1.44",
     "the_gauge_between_the_drawn_heads_is_standard"),
    ("a tie every 12 m",
     "world/permanent_way.gd", "const TIE_SPACING: float = 19.5 * 0.0254",
     "const TIE_SPACING: float = 12.0",
     "at_nineteen_and_a_half_inch_centres"),
    ("the ties' tops at the railhead, as the old slabs were",
     "world/permanent_way.gd", "static func tie_top() -> float:\r\n\treturn -RAIL_HIGH",
     "static func tie_top() -> float:\r\n\treturn 0.0",
     "and_the_rails_stand_on_them"),
    ("the bank tipped with the track on a banked bend",
     "world/permanent_way.gd", "bed_at.append(Transform3D(level.scaled_local(Vector3(1.0, 1.0, run)), middle))",
     "bed_at.append(Transform3D(facing.scaled_local(Vector3(1.0, 1.0, run)), middle))",
     "at_the_sharpest_bend_the_bank_stands_on_the_ground"),
    ("no bank under the ballast: the railway floating over the grass",
     "world/sky.gd", "PermanentWay.bed(ground)", "PermanentWay.bed(0.0)",
     "at_the_sharpest_bend_the_bank_stands_on_the_ground"),
    ("the track laid on the 40 m survey",
     "world/terrain.gd", "const RAIL_LAID_EVERY: float = 10.0", "const RAIL_LAID_EVERY: float = 40.0",
     "no_joint_between_two_lengths_of_rail_is_kinked"),
    ("the boxcar's treads at the old typed 0.72",
     "objects/vehicles/boxcar.gd", "const WHEEL_ACROSS: float = PERMANENT_WAY.RAIL_CENTRES * 0.5",
     "const WHEEL_ACROSS: float = 0.72",
     "a_boxcar_at_the_sharpest_bend_runs_its_treads_over_the_rails"),
    ("the locomotive's wheels at 0.88 of its half-width, in the ballast",
     "objects/vehicles/vehicle_view.gd", "Vector3(side * PermanentWay.RAIL_CENTRES * 0.5, rail + wheel_radius, truck_at + at)",
     "Vector3(side * half_width * 0.88, rail + wheel_radius, truck_at + at)",
     "the_locomotive_runs_its_treads_over_the_rails"),
]

if __name__ == "__main__":
    run_all("res://tests/track_drawn.tscn", MUTANTS)

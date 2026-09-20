"""The SD40-2's mutants: each is a fault the model made or nearly made, and the check in `tests/road_diesel.gd` that
must turn red for it. Run from the lane with its own engine and TEMP:

    WARBIRDS_TEMP=C:/gg-wt/trains-temp python cockpit/craft/train/diesel_mutants.py <godot console exe>

The runner is `tools/mutants.py`. Each mutant is THE BUG, not the published number: the fault a check exists to catch.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools"))
from mutants import run_all  # noqa: E402

MODEL = "objects/vehicles/road_diesel.gd"
MUTANTS = [
    ("the cab built as the tallest thing on the locomotive, which is a switcher",
     MODEL, "const CAB_ROOF: float = 4.55", "const CAB_ROOF: float = 4.90",
     "the_cab_roof_sits_below_the_long_hood"),
    ("a high short hood, as the photographed unit has and a standard one does not",
     MODEL, "const NOSE_TOP: float = 3.30", "const NOSE_TOP: float = 4.62",
     "and_the_short_hood_is_a_low_nose_below_the_cab"),
    ("the radiator drawn no wider than the hood, so the flare is gone",
     MODEL, "const RADIATOR_WIDE: float = 3.00", "const RADIATOR_WIDE: float = 2.82",
     "and_the_radiator_flares_out_past_the_hood_sides"),
    ("the walkway at the 1.37 m first typed, which the photograph refused",
     MODEL, "const DECK: float = 1.14", "const DECK: float = 1.37",
     "the_walkway_stands_where_the_broadside_puts_it"),
    ("the wheel drawn THROUGH its circle rather than round it, so it stands 3 cm low",
     MODEL, "var radius: float = (WHEEL_DIAMETER * 0.5) / cos(PI / float(WHEEL_SIDES))",
     "var radius: float = WHEEL_DIAMETER * 0.5",
     "and_each_is_the_published_forty_inches_across_its_flats"),
    ("a smooth cylinder in place of the eight-sided wheel",
     MODEL, "const WHEEL_SIDES: int = 8", "const WHEEL_SIDES: int = 24",
     "and_each_is_an_eight_sided_prism_rather_than_a_smooth_cylinder"),
    ("the F7A's truck centres left on the SD40-2",
     MODEL, "const TRUCK_CENTRES: float = 43.0 * 0.3048 + 6.0 * 0.0254",
     "const TRUCK_CENTRES: float = 9.144",
     "and_two_trucks_at_the_published_centres"),
    ("the trucks given a GP's two axles",
     MODEL, "const AXLES_EACH_TRUCK: int = 3", "const AXLES_EACH_TRUCK: int = 2",
     "it_has_twelve_wheels"),
    ("the wheels at the boxcar's old typed 0.72 across, inside the gauge",
     MODEL, "_wheel(tool, Vector3(side * PERMANENT_WAY.RAIL_CENTRES * 0.5, radius, along))",
     "_wheel(tool, Vector3(side * 0.72, radius, along))",
     "and_each_runs_over_a_railhead"),
    # THE PART MUST COME OFF WHOLE, and this is what the float check can and cannot see. Hanging the fuel tank 0.6 m
    # lower does NOT make a group of its own -- the air reservoirs drawn in the same part still touch the frame, and the
    # union-find joins PARTS by their boxes (the same blind spot `learnings/2026-09-17-falcon.md` recorded for
    # `DrawnParts.adrift`). It went red on the height and railhead checks instead, because the tank then hangs under the
    # rail. A whole part lifted off its neighbours is what this check exists for.
    # AND 0.6 m IS NOT ENOUGH TO SEE: lifted that far the handrails still overlap the CAB's box, which is 3.05 m wide
    # against their 3.02, so the boxes meet on all three axes and the part reads as joined. It takes 4 m -- clear over
    # everything -- for the check to fire. That is the honest limit of joining parts by their boxes, and it is worth
    # knowing before anyone trusts this check to catch a part that has merely slipped.
    ("the handrails lifted clear of the locomotive, attached to nothing",
     MODEL, '_add("Handrails", _handrails(), paint)',
     '_add("Handrails", _handrails(), paint).position.y += 4.0',
     "every_part_of_it_touches_another"),
]

if __name__ == "__main__":
    run_all("res://tests/road_diesel.tscn", MUTANTS)

"""Mutants for the F-4E Phantom II airframe (lane/phantom).

    python mutants.py [<path to the editor .console.exe>]

Run it from this folder. Each mutant is THE BUG a check exists to catch, typed back into the
airframe -- never the source's number (`modelling_here.md` section 6: `lane/carrier` 4b typed
Slover's own figure and the mutant stayed green, because the number was not the fault). The shared
runner in `cockpit/tools/mutants.py` refuses a mutant whose anchor is not present exactly once,
prints "applied", restores the file's whole text afterwards, and judges by the printed RESULT=.

FOUR OF THESE ARE MISTAKES THIS LANE ACTUALLY MADE, which is the best use of a mutant there is:

- `a_45_degree_leading_edge` is the wrong reading of the published figure. The article body calls
  45 degrees a LEADING-EDGE sweep; it is the QUARTER CHORD, and the leading edge is 51.47. Building
  to the sentence puts ROOT_LE at 6.948 so the leading edge runs at exactly 45 -- a wing visibly too
  straight, and every dimension check stays green because length, span and area barely move.
- `the_spine_half_a_metre_low` is the masked construction line. Two long level lines over the
  fuselage at 3.33 and 3.28 m were taken for the page's own furniture and removed before the top of
  the body was read; what was left was a panel line at 2.77, and the whole aeroplane came out flat.
  Only the orthographic overlay found it.
- `the_hook_defines_the_length` is the first build's tail: a stowed arrester hook drawn to station
  19.30 on a 19.202 m aeroplane, so the HOOK set the length.
- The fin drawn with a flat root over a deck that falls away under it, so aft of about station 15 it
  was attached to nothing. Fifteen checks were green and only the side overlay showed it, as a white
  band between the fin's foot and the body. **It has no mutant, and that is the finding**: raising
  the fin leaves `nothing_floats` green, because the fin's box still overlaps the spine's and a box
  is not a surface. `a_part_hangs_in_mid_air` detaches a part outright instead, so the check is
  proved able to fail, and the check's doc block says what it cannot do.
- `the_gear_door_joins_the_track` is the check's own fault rather than the model's, and it is kept
  because it is the one the reviewer would not have found: measuring the track from the gear part's
  centroid instead of from its tyre's contact patch reads 5.01 m against a printed 5.461, and a
  centroid over a set hides every member that is not the one being asked about.
"""
import os
import sys

sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tools")))

from mutants import run_all   # noqa: E402

AIRFRAME = os.path.join("objects", "vehicles", "phantom_airframe.gd")
SUITE = os.path.join("tests", "phantom.gd")

MUTANTS = [
    ("a_45_degree_leading_edge", AIRFRAME,
     "const ROOT_LE: float = 5.913",
     "const ROOT_LE: float = 6.948",
     "the_quarter_chord_sweep_is_the_published_forty_five"),

    ("the_outer_panels_are_flat", AIRFRAME,
     "const DIHEDRAL: float = 12.0",
     "const DIHEDRAL: float = 0.0",
     "the_outer_panels_carry_the_published_dihedral"),

    ("the_stabilators_are_flat", AIRFRAME,
     "const ANHEDRAL: float = 23.0",
     "const ANHEDRAL: float = 0.0",
     "the_stabilators_carry_the_published_anhedral"),

    ("no_dogtooth", AIRFRAME,
     "const DOGTOOTH: float = 0.316",
     "const DOGTOOTH: float = 0.0",
     "the_wing_has_its_dogtooth_where_the_front_view_folds"),

    ("the_spine_half_a_metre_low", AIRFRAME,
     "const SPINE: Vector3 = Vector3(7.20, 14.60, 3.280)",
     "const SPINE: Vector3 = Vector3(7.20, 14.60, 2.770)",
     "the_spine_stands_at_the_printed_height"),

    ("the_boundary_layer_gap_shut", AIRFRAME,
     "const SPLITTER_GAP: float = 0.12",
     "const SPLITTER_GAP: float = 0.0",
     "the_boundary_layer_gap_is_open"),

    ("the_main_gear_a_metre_aft", AIRFRAME,
     "const MAIN_GEAR_STATION: float = 11.272",
     "const MAIN_GEAR_STATION: float = 12.272",
     "the_gear_stands_at_the_measured_stations_and_track"),

    ("a_short_wing_root", AIRFRAME,
     "const ROOT_TE: float = 13.150",
     "const ROOT_TE: float = 11.600",
     "the_wing_area_is_the_published_area"),

    ("the_hook_defines_the_length", AIRFRAME,
     "const HOOK_TIP: float = 19.05",
     "const HOOK_TIP: float = 19.80",
     "the_drawn_aeroplane_is_the_published_length_and_span"),

    ("the_gun_fairing_behind_the_intakes", AIRFRAME,
     "const GUN_FAIRING: Vector3 = Vector3(1.70, 4.30, 0.94)",
     "const GUN_FAIRING: Vector3 = Vector3(6.40, 9.00, 0.94)",
     "the_gun_fairing_is_under_the_nose_and_ahead_of_the_intakes"),

    # THE HOOK HUNG IN MID-AIR, not the fin. The first version of this mutant raised the fin clear
    # of the deck and the check STAYED GREEN: the fin's box still overlapped the spine's, because a
    # box is not a surface. That is a real limit of an AABB union-find and it is written into the
    # check's own doc block. This mutant detaches a part outright -- the tanker's case, which is
    # what the check was written for -- so the check is at least proved able to fail.
    ("a_part_hangs_in_mid_air", AIRFRAME,
     "const HOOK_HEIGHT: Vector2 = Vector2(1.36, 1.08)",
     "const HOOK_HEIGHT: Vector2 = Vector2(-1.40, -1.62)",
     "nothing_floats"),

    # THE STABILATOR PITCHED THE WRONG WAY, and this is the bug this lane actually shipped for an
    # hour: every hinge is wound so a positive turn carries the trailing edge DOWN, and pulling the
    # stick back must raise it. Every angle was right and every mirror held; only reading the drawn
    # trailing edge caught it.
    ("the_stabilator_pitches_the_wrong_way", AIRFRAME,
     "	var together: float = -_stab_pitch * (STAB_PITCH_TRAVEL.x if _stab_pitch >= 0.0 else STAB_PITCH_TRAVEL.y)",
     "	var together: float = _stab_pitch * (STAB_PITCH_TRAVEL.x if _stab_pitch >= 0.0 else STAB_PITCH_TRAVEL.y)",
     "the_stick_moves_the_right_surfaces_the_right_way"),

    ("both_ailerons_go_the_same_way", AIRFRAME,
     '	_turn("AileronPort", _ailerons * AILERON_TRAVEL)',
     '	_turn("AileronPort", -_ailerons * AILERON_TRAVEL)',
     "the_two_sides_mirror_each_other"),

    ("a_setter_that_accumulates", AIRFRAME,
     "	_flaps = clampf(amount, 0.0, 1.0)",
     "	_flaps = clampf(_flaps * 0.02 + amount, 0.0, 1.0)",
     "every_feature_is_a_pure_function_of_its_amount"),

    ("the_canopies_do_not_open", AIRFRAME,
     "const CANOPY_TRAVEL: float = 42.0",
     "const CANOPY_TRAVEL: float = 0.0",
     "the_canopies_and_the_nozzles_open"),

    ("the_gear_door_joins_the_track", SUITE,
     "\tvar track: float = absf(starboard_contact.x - port_contact.x)",
     "\tvar track: float = absf(_bounds_of(frame, \"MainGearStarboard\").get_center().x"
     " - _bounds_of(frame, \"MainGearPort\").get_center().x)",
     "the_gear_stands_at_the_measured_stations_and_track"),
]

# THE WEATHERING'S OWN MUTANTS, run against a DIFFERENT suite -- `tests/phantom_wear.gd` -- because that is where
# its checks live. Kept in this file so there is one place to run and one place to read.
#
# `the_soot_three_metres_forward` is the mutant the step 0 plan asked for by name, and it is the one a UV-only
# check cannot catch: move the mark and every vertex still has a perfectly good second coordinate, every coordinate
# is still inside 0..1, and the sheet is still neither blank nor solid. What changes is WHICH TEXEL the tail reads,
# so only a check that asks about the pair -- this vertex, that texel -- goes red.
WEAR_MUTANTS = [
    ("the_soot_three_metres_forward", AIRFRAME,
     '_stains.mark("exhaust_soot", [S, D], 16.2, LENGTH, 0.3, 2.9, Color(0.11, 0.10, 0.09), 0.76)',
     '_stains.mark("exhaust_soot", [S, D], 13.2, LENGTH - 3.0, 0.3, 2.9, Color(0.11, 0.10, 0.09), 0.76)',
     "a_vertex_by_the_nozzles_reads_a_dirty_texel"),

    ("a_mark_quietly_dropped", AIRFRAME,
     '_stains.mark("gun_gas", [S], 2.6, 7.5, 0.6, 1.5, Color(0.15, 0.14, 0.13), 0.54)',
     "pass",
     "the_sheet_carries_its_eight_named_marks"),

    # IT HAS TO BE THE BUG THAT WAS ACTUALLY MADE. A first version of this mutant only switched the repeat off and
    # left the mark starting at station 3.5, and it SURVIVED -- a veil that politely stops short of the radome
    # breaks none of these checks. That is this lane's own lesson arriving a second time: a check whose mutant does
    # not kill it is a check about a different thing than you think. The veil really drawn started at station 0.0
    # at a flat 0.10, covered 100% of the sheet, and dirtied the nose exactly as much as the tailpipe.
    ("the_panel_lines_as_one_veil", AIRFRAME,
     '_stains.mark("panel_line_dirt", [S, U, D], 3.5, LENGTH, 0.0, SPAN * 0.5, '
     'Color(0.22, 0.23, 0.24), 0.30, 1.35, 0.22)',
     '_stains.mark("panel_line_dirt", [S, U, D], 0.0, LENGTH, 0.0, SPAN * 0.5, '
     'Color(0.24, 0.25, 0.26), 0.10, 0.0, 0.0)',
     "the_sheet_is_neither_blank_nor_a_solid_wall"),

    # A SECOND SET OF COORDINATES THAT NEVER GETS WRITTEN. The aeroplane still draws, and reads texel (0,0) -- the
    # nose on the side band -- over its whole self, so it comes out uniformly CLEAN rather than obviously broken.
    ("no_second_uv_at_all", AIRFRAME,
     "\t\ttool.set_uv2(_sheet().uv2_for(band, corner.z + _half.z, corner.y + _half.y, corner.x))",
     "\t\tpass",
     "every_drawn_surface_carries_a_second_uv"),
]

if __name__ == "__main__":
    run_all("res://tests/phantom.tscn", MUTANTS)
    run_all("res://tests/phantom_wear.tscn", WEAR_MUTANTS)

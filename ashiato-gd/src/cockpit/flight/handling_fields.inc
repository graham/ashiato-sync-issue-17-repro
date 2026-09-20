// EVERY NUMBER IN `Handling`, ONE ROW EACH: the one list a per-kind tuning number is added to (lane/flightcore, step 1).
//
// A field used to be typed three times -- in `struct Handling`, in `set_handling`'s `dict_get` and in `handling()`'s
// dictionary -- a hundred and fifty lines apart, and the file's own comment warns what the third one is for:
// `set_handling` "treats a misspelled key as absent, so a typo leaves the setting at its default while the game goes on
// believing it applied". A field missed in `set_handling` is a `--set=` that silently does nothing; one missed in
// `handling()` is a number no suite can read back. Now it is a row here, and cockpit_world.cpp makes all three from it.
//
//   HANDLING_FIELD(name, default)
//
// WRITTEN BY `cockpit/tools/generate_handling_fields.py` FROM `struct Handling` ITSELF, so the struct keeps the doc
// blocks that say what each number is and what it cost to learn, and this file cannot drift from them. Add a field to
// the struct, with its comment, and run the script.
//
// The row order is the struct's, so the file still reads as the table it is, and the sections are the struct's too.
// What is NOT here: the `Rig` a ship under sail carries (a struct, not a number), and `cruise_pinned`, which is a
// second NAME for `cruise` in the dictionary. Both stay hand-written beside the generated ones.
//
// The same shape as `cockpit_kinds.inc`, and for the same reason (lane/kinds, 2026-09-18): a list kept in three places
// is a list kept in one place and two copies of it.

// ---- every model ----
HANDLING_FIELD(thrust, 6000.0f)
HANDLING_FIELD(brake, 4000.0f)
HANDLING_FIELD(brake_drag, 0.0f)
HANDLING_FIELD(drag_forward, 0.9f)
HANDLING_FIELD(drag_side, 4.5f)
HANDLING_FIELD(drag_vertical, 5.5f)
HANDLING_FIELD(angular_damping, 0.9f)
HANDLING_FIELD(pitch_rate, 1.8f)
HANDLING_FIELD(roll_rate, 3.4f)
HANDLING_FIELD(yaw_rate, 1.1f)
HANDLING_FIELD(control_authority, 20000.0f)
HANDLING_FIELD(control_reference, 24.0f)
// ---- Airplane ----
HANDLING_FIELD(lift, 50.0f)
HANDLING_FIELD(camber, 0.0f)
HANDLING_FIELD(stall_angle, 0.30f)
HANDLING_FIELD(induced_drag, 100.0f)
HANDLING_FIELD(side_lift, 0.0f)
HANDLING_FIELD(weathervane, 40.0f)
HANDLING_FIELD(yaw_damping, 0.0f)
HANDLING_FIELD(pitch_damping, 0.0f)
HANDLING_FIELD(flap_lift, 0.10f)
HANDLING_FIELD(flap_drag, 2.2f)
HANDLING_FIELD(gear_drag, 1.1f)
HANDLING_FIELD(spoiler_drag, 2.6f)
HANDLING_FIELD(pitch_stability, 3.0f)
HANDLING_FIELD(turn_coordination, 1.0f)
HANDLING_FIELD(g_limit, 0.0f)
// ---- An aeroplane on its surfaces (lane/flightmodel, 2026-09-18) ----
HANDLING_FIELD(surfaces, 0.0f)
HANDLING_FIELD(clmax, 1.4f)
HANDLING_FIELD(flap_clmax, 0.5f)
HANDLING_FIELD(augmentation, 0.0f)
HANDLING_FIELD(surface_mutant, 0.0f)
HANDLING_FIELD(cruise, 0.0f)
// ---- A helicopter on its rotor disc (Little Bird, 2026-09-19) ----
HANDLING_FIELD(rotors, 0.0f)
HANDLING_FIELD(rotor_mutant, 0.0f)
// ---- Helicopter and Hover ----
HANDLING_FIELD(hover, 0.0f)
HANDLING_FIELD(collective_range, 0.0f)
HANDLING_FIELD(vector_travel, 1.702f)
// ---- Car ----
HANDLING_FIELD(wheelbase, 2.8f)
HANDLING_FIELD(grip, 7000.0f)
HANDLING_FIELD(grip_rear, 8200.0f)
HANDLING_FIELD(peak_slip, 0.14f)
HANDLING_FIELD(steer_lock, 0.55f)
HANDLING_FIELD(steer_reference, 12.0f)
HANDLING_FIELD(rolling_resistance, 500.0f)
// ---- on the ground ----
HANDLING_FIELD(ground_height, 4.0f)
HANDLING_FIELD(ground_speed, 12.0f)
HANDLING_FIELD(ground_steer, 0.5f)
HANDLING_FIELD(wheel_brake, 0.45f)
HANDLING_FIELD(rolling, 0.015f)
HANDLING_FIELD(belly, 0.5f)
// ---- Train ----
HANDLING_FIELD(rail_power, 1.0f)
HANDLING_FIELD(bogie_spacing, 9.144f)
// ---- Boat ----
HANDLING_FIELD(water_level, 0.0f)
HANDLING_FIELD(buoyancy, 26000.0f)
HANDLING_FIELD(probe_damping, 1000.0f)
HANDLING_FIELD(sea_smoothing, 1.0f)
HANDLING_FIELD(float_lift, 1.0f)
HANDLING_FIELD(water_drag, 1800.0f)
HANDLING_FIELD(keel_limit, 9000.0f)
HANDLING_FIELD(rudder_force, 4.0f)
HANDLING_FIELD(rudder_arm, 2.6f)
HANDLING_FIELD(hull_speed, 100.0f)
HANDLING_FIELD(wave_drag, 0.0f)
HANDLING_FIELD(righting, 0.0f)
HANDLING_FIELD(lean, 0.0f)
HANDLING_FIELD(bow_rise, 0.0f)
HANDLING_FIELD(plane_speed, 10.0f)
HANDLING_FIELD(plane_lift, 0.0f)
// ---- Sail ----

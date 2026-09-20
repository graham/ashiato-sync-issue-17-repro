# flightcore's prototypes

Not built by anything, and not part of any suite. They include the game's own headers unedited, so what they measure
is the code the game runs. `build_audit.bat` builds both with the MSVC and flags the addon uses (/O2 /fp:precise).

- `rotor_audit.cpp`: the Little Bird's `rotor_disc.hpp` integrated with the body drags `drive_vehicle` applies on the
  disc path, at 120 Hz with the attitude held. The hover lever in and out of ground effect, the steady vertical climb
  at three levers, level speed at four nose-down angles, the lever's step at 0.08, and autorotation at three forward
  speeds. `../flight_model_review.md`, section 7, is what it found.
- `rotor_cost.cpp`: the price of one `rotor::fly` call, median of five runs of two million.
- `rotor_bem.hpp`: THE PROPOSED ROTOR BLOCK (review section 7): blade-element momentum, the climb in the power,
  autorotation as zero engine power, the vortex ring and windmill states in an axial descent, ground effect on the
  inflow. Pure and stateless, as the game's blocks must be.
- `rotor_bem_audit.cpp`: the same tests as `rotor_audit.cpp`, on `rotor_bem.hpp`, against the MD 530F, and its price;
  `results_bem.txt` is the run.
- `probe_bem.cpp`: thrust, inflow and power at a grid of pitch and descent, for looking at the descent branches.
- `count_bem.cpp`: how much work one `fly` does in each expensive state (passes of the blades, steps of the ring's
  regula falsi), which is how the cost was brought down rather than by guessing at it.
- `rotor_fleet.cpp`: the same block on the Little Bird, the UH-60, the Apache and the Chinook's two discs, with nothing
  per kind but its own numbers; `results_fleet.txt` is the run. It is what found that the disc had no top speed of its
  own until the retreating blade's stall boundary went in.
- `panel_wing.hpp`: THE PROPOSED SURFACES BLOCK, generalised (review section 3): an aeroplane as a LIST of panels,
  with the lift slopes, the downwash, the neutral point, the centre of gravity and the trim derived from the list.
- `surfaces_fleet.cpp`: the Cessna through both the game's builder and the panel list (they must agree), the F/A-18F's
  canted fins and rolling stabilators, and the P-38's booms, with what each of those is worth measured;
  `results_surfaces.txt` is the run.
- `propeller.hpp`: THE PROPULSION BLOCK's propeller half (review section 3): a constant-speed propeller's thrust from
  momentum theory, and the three moments a big propeller makes -- torque, P-factor and the slipstream's swirl at the
  fin -- with a handedness an engine, so a counter-rotating pair cancels them.
- `propeller_fleet.cpp`: the Cessna, the P-51 and the P-38's pair through it, printing what each has to be held
  straight against as a share of its rudder, and the P-38 with one engine out; `results_propeller.txt` is the run.
- `p51_for_warbirds2.cpp`: two questions lane/warbirds2 asked on 2026-09-19, answered with THEIR numbers: does the
  "28 per cent of full rudder" hold with their fin, rudder and arm (it is 23), and would a constant-speed propeller
  shorten their take-off (it would, by about a third); `results_p51_warbirds2.txt` is the run.

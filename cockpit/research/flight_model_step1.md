# Step 1: the blocks extracted, and nothing else changed

lane/flightcore, drafted 2026-09-19 while the C++ turn is queued behind lane/warbirds2 and gunscatter. This is the
edit list for `ashiato-gd/src/cockpit/cockpit_world.cpp`, written so that the rebase onto whatever has landed is
mechanical and a reviewer can read it as moves rather than changes. The plan it serves is
`flight_model_review.md`, section 9; the user approved it on 2026-09-19 (section 10).

**The promise of this step: not one number moves.** `tests/flight_fingerprint.gd` prints every kind's final position,
attitude, velocity and spin as hex floats, and every line must be identical before and after. That is the whole gate,
with `-Tier core` and the flight suites behind it.

## What is drafted already, in the lane

| File | What it holds | Replaces (review section 2) |
|---|---|---|
| `flight/air.hpp` | `kGravity`, `kSeaLevelDensity`, `surface_bite`, `thruster_bite`, `dynamic_pressure` | D13 (`9.81f` 27 times, density three ways), the two `*_bite` statics |
| `flight/hull.hpp` | `keel`, `bow_wave`, `stern_rudder`, `rudder_drag`, `waterline_length`, `probe_reach`, `planing_lift`, `hump`, `lean` | D4 to D8 (three keels, two bow waves, two stern rudders, three probe reaches) |
| `flight/body.inc` | `inertia_about` (twice over), `Loads`, `apply` | D2 (six inertia reads) and the groundwork for one force and one torque a model |
| `flight/handling_fields.inc` | all 70 of `Handling`'s numbers, one row each, WRITTEN by `cockpit/tools/generate_handling_fields.py` from the struct | D20 (every field typed three times) |

Nothing includes them yet, so nothing is built differently. That is deliberate: they are drafted against a file that is
moving under me.

## The edits, call site by call site

**1. The constants.** `9.81f` becomes `flight::kGravity` at all 27 sites; `kAirDensity` (cockpit_world.cpp 20327) and
`aero::kSeaLevelDensity` and `rotor::kSeaLevelDensity` become `flight::kSeaLevelDensity`. Bit-identical: the same
literal by another name.

**2. The two bites.** `surface_bite(h, f)` and `thruster_bite(h, f)` become thin calls to
`flight::surface_bite(f.speed, h.control_reference)` and `flight::thruster_bite(...)`. Their callers are unchanged.

**3. The inertia.** The six copies become `inertia_about(...)`:
`fly_on_surfaces` (the law's `about` lambda), `steer_on_the_ground`, `steer_on_the_water`, `sail_ship`'s roll report,
`hold_the_turn`'s `hold` lambda, and `command_rate`. Each keeps its own guard's meaning, because the helper carries it.

**4. The water.** `sail_boat`, `alight` and `sail_ship` call `hull::keel`, `hull::bow_wave`, `hull::stern_rudder` and
`hull::rudder_drag` instead of their own copies; `float_the_hull`, `plane_the_hull` and `waterline_length` call
`hull::probe_reach` and `hull::waterline_length`; `plane_the_hull` calls `hull::planing_lift`, `hull::hump` and
`hull::lean`. Each call passes what the expression used, in the same order, so the products round the same way.

**5. The handling table.** `struct Handling`'s 70 floats, `set_handling`'s 70 `dict_get` lines and `handling()`'s 70
dictionary writes all come from `handling_fields.inc` through three different definitions of `HANDLING_FIELD`. The list
is GENERATED from the struct by `cockpit/tools/generate_handling_fields.py`, so the struct keeps the doc block above
each number (the most valuable thing in that part of the file) and the list cannot drift from it; `--check` says whether
it is stale, for a gate. What
stays hand-written: the `Rig` (a struct, not a number), `cruise_pinned` (a second name for `cruise` in the dictionary),
and the derived read-only entries `handling()` adds (`stall_speed`, `cruise`, the rig's own keys).

**6. Nothing else.** No model changes shape, no kind changes a number, and the lumped wing, the rate servo, the
surfaces and the disc all still run exactly where they ran.

## What this step deliberately does NOT do

- **It does not make a kind's model its own function.** That is step 3 for the Cessna, and each kind's own step after.
- **It does not move `roll_on_wheels` into a ground block.** lane/warbirds2 is writing the taildragger's wheel forces
  in that function now; the block takes its shape from what they land, afterwards, not before (team-lead's ruling).
  **They have landed and it has been read: the shape is at the end of this file.**
- **It does not raise `kMostSurfaces`** from 6 to 8. That belongs with the panel list, in step 3.
- **It does not touch the autopilot** (`autopilot.hpp`) at all.

## The gate

- `tests/flight_fingerprint.gd` against main's reference file: every line identical, and the suite's own mutant still
  moves the light twin's line.
- `-Only lint,docs,flight_fingerprint,surfaces,cessna_book,handling,ground_stick,water,water_rudder,seakeeping,sailing,climb,trim,crashes,rotor_rates,rotor_turn,rotor_hold,littlebird_book,littlebird_flight`
  plus `-Tier core,net`, because it is a C++ change.
- A MEASUREMENT slot is not needed: no force changes, and the only cost question (one inertia read instead of six) is
  step 3's, when a model starts handing `Loads` to `apply`.

## The rebase

Onto lane/warbirds2's P-51 and then gunscatter's `muzzle_of` change. **warbirds2's is substantial** (team-lead,
2026-09-19: 41 files, including `cockpit_world.cpp`, `cockpit_kinds.inc`, `lifting_surfaces.hpp` and both DLLs), and
what it lands touches three of the four edits above:

- **a taildragger ground model** -- wheel forces at the wheels, a steering tailwheel, differential brakes -- in and
  around `roll_on_wheels`. Step 1 does not touch that function, and the ground block takes its shape from what they
  land, later. No collision expected, and none wanted.
- **`Handling::ground_mutant`, and any other field it adds.** No hand-work: the field arrives in the struct with its
  doc block, `generate_handling_fields.py` is run, and the row appears. That is the whole point of generating the list.
- **`lifting_surfaces.hpp`**, which step 1 does not edit at all (the panel list is step 3, and it will start from
  whatever their version is).
- **a keel hull and taildragger touchdown rules**, which may touch the water. If their keel is the same expression as
  `sail_boat`'s, it joins `hull::keel`; if it is a new one, it is theirs and stays where they put it until its own
  step.

So the order at the turn is: rebase, re-run the generator, re-check the four edit sites against their file, then build.

## The ground-contact block, read off main's taildragger (2026-09-19, after e5331a8a)

The ruling was that the ground block takes its shape from what lane/warbirds2 lands, not before it. It has landed, it
has been read, and **the shape is better than the one this lane would have drafted**: `aircraft_tyre` is already the
primitive, so the block is mostly a matter of giving the OTHER undercarriages the same one.

### What is there now

| | where | what it does |
|---|---|---|
| `aircraft_tyre(body, f, below, from_centre, local, ahead, side, load, along, grips)` | `cockpit_world.cpp` | **ONE WHEEL AT A POINT.** Rolls along `ahead` against `along` newtons, clamped never to reverse; grips across as a slip-angle tyre, `kTyreGrip` 0.75 of its load, peak at `kTyrePeakSlip` 0.14 rad, with a clamp at what would stop its share of the aeroplane in one step. Everything relative to `below.moving`, so a deck comes free. |
| `roll_a_taildragger` | beside it | **THREE OF THEM.** Two mains at `±half_track` on the ground line, each braking on its own pedal (`pedals * min(1, 1 + sgn * rudder)`, which is differential braking); a tail wheel that is down only while a ray finds ground within `kTailReach` of its tyre, steering `tailwheel_steer` each way and castoring with no grip once the stick is past `kTailwheelUnlock` forward. Loads are the static split about the CG along the ground: `tail_share = mains_ahead / (mains_ahead + tail_behind)`. |
| the tricycle path | `roll_on_wheels` | **STILL AT THE MASS CENTRE**, and the comment says so: "Every tricycle goes on as below, its forces at the mass centre, byte for byte as before." Its own sideways grip (a `kDeckGrip` damper floored at the brake), its own rolling-plus-brake along `ahead`, both `ApplyForceToCenter`. |
| `GroundMutant` | `has_ground_mutant` | A bitmask on `Handling::ground_mutant`: `kWheelsAtTheCentre` puts a taildragger back on the tricycle's model and `kFlatUnderside` takes the keel away, both for `tests/taildragger.gd`. **Zero in the game.** |

### What the block should be, and the one decision it needs

`flight/wheels.hpp`, and it is three things:

1. **`tyre()`** -- `aircraft_tyre` lifted as it stands. It is already general: a point, a heading, a load, a resistance
   and whether it grips. The car's tyre (`grip`, `grip_rear`, `peak_slip`) is the same shape with different constants
   and should end up calling it, which is where the duplication actually is.
2. **`stance()`** -- the static weight split along the ground about the CG, which `roll_a_taildragger` computes inline
   for two wheels and a tricycle would compute for two and a nose. One expression, given the arms.
3. **`roll()`** -- a small list of wheel placements, each with its load share, its brake share and its steer, walked
   and handed to `tyre()`. The taildragger's three and the tricycle's three are then the same call with different lists.

**THE DECISION, and it is not mine to take quietly.** Putting the tricycle on the same three wheels **changes how every
tricycle in the game behaves on the ground**: its forces stop acting at the mass centre, so a braked turn pitches and
yaws it, and a nosewheel's grip against a skid resists rather than teleporting the force to the middle. That is more
correct, it is what the taildragger's own doc block argues for ("a model that cannot misbehave... a test that it does
neither would pass whatever was built"), and it will move **every tricycle's `flight_fingerprint` wheels line and every
`vehicle_gym` line that touches the ground**. So the block lands in two commits:

- **one that is bit-identical**: `tyre`, `stance` and `roll` extracted, the taildragger calling them, the tricycle
  still at the mass centre. The fingerprint must not move at all.
- **one that moves the tricycles onto their wheels**, on its own, with the fingerprint lines it moves named and the
  gym's take-off and taxi scores before and after. `kWheelsAtTheCentre` already exists as its mutant, which is
  convenient: after the change it becomes the way back to today's behaviour, and `tests/taildragger.gd` keeps working.

**What NOT to fold in.** `h.belly` (the gear-up slide) and the squash spring above it are the hull on the ground, not a
wheel, and they belong with `hull.hpp` if they move at all. The deck bookkeeping (`Deck`, `kDeckGrip`, `Underneath`) is
the world's, not the undercarriage's.

**And one number to ask about rather than copy.** `kTyreGrip` is 0.75 and `kTyrePeakSlip` 0.14, cited as the car's and
as dry concrete for an aircraft tyre. The car has `grip`, `grip_rear` and `peak_slip` as per-kind `Handling` fields;
the aeroplane's are constants in the file. When the block is written they should be one thing, and the question is
whether an aeroplane's tyre wants to be per-kind (a carrier deck and a grass strip are not dry concrete) -- which is a
change of behaviour and therefore its own step, not the block's.

### The clip that has to come with the tricycles (team-lead's condition, 2026-09-19)

A braked turn that now pitches and yaws is a change somebody feels before any number tells them, so the second commit
does not land without a picture. The shape, agreed:

- **ONE BINARY, TWO RUNS, ONE BIT APART.** The "before" is `kWheelsAtTheCentre`, the ground mutant that already exists
  for `tests/taildragger.gd`, which reproduces today's tricycle exactly. Not an older build: same aeroplane, same
  script, same camera, same time of day, same lighting, so the only difference in the frame is the bit that was
  flipped.
- **SOMEWHERE WITH GROUND TO READ.** A real airfield's apron and taxiway, on the island or the test field -- never the
  reel stage, whose floor is a flat green plane a taxiing aeroplane is invisible against (see `../agents.md`). With
  lane/tracelog's trace level drawing the path along the ground if it will take a taxi trace: **a ground loop as a
  spiral on the floor is the picture**, and nothing else says it as quickly.
- **THE TOOLING IS ALREADY IN** (97f2c932): a six-field `-StickScript` that works the throttle and the brake, and
  `-NoPen`, because a parked craft stands inside a wall two centimetres off it.

### What to look for, named before it is measured

Writing this down first is what stops it being quietly not found. Moving a tricycle's forces from the mass centre to
its wheels gives it two couples it did not have:

| | what appears | where it will show worst |
|---|---|---|
| a **pitch** couple from the brakes, acting at the tyres under the CG | the nose dips under braking | **a heavy braking hard with the nose leg loaded** (team-lead's addition): the airliner is the kind most likely to look WORSE |
| a **yaw** couple from asymmetric grip | a skid turns the aeroplane instead of sliding it | the take-off run, where a wander is possible for the first time |

**And the honest expectation: some kinds will get less pleasant.** A long-nose-leg heavy may read as firmer and more
deliberate; something light and short-coupled may read as twitchy on the brakes, and a take-off run that tracked
perfectly may start to wander -- because until now nothing about the undercarriage could disturb it. **Every kind that
gets less pleasant is named in the READY with its gym take-off and taxi numbers**, not only the ones that get more
correct. Look, fly, function -- and "more correct" is only the third of those.

### And the ground chatter, which no picture will show (lane/tracelog, 2026-09-19)

tracelog measured a Cessna taxiing on the test field -- 160 s at 30 Hz -- whose **pitch rate crosses zero fourteen
times a second** at 0.01 to 0.02 rad/s with 0.11 spikes, on a body whose pitch never leaves -0.09 to +0.33 degrees.
Its yaw rate is calm in the hunting sense (0.01 crossings a second; the spread is the route's turns). The same Cessna
flying is 0.03 on pitch rate and 0.01 on roll. So it reads as tick-level ground contact making and breaking, or a
ground seam, and not a controller fighting anything. **It is sub-degree, so it will not show in the clip**, and the
tricycle change will either damp it or make it worse.

**THE INSTRUMENT IS BUILT AND THE "BEFORE" IS RECORDED.** The gym has a `taxi` task and a `chatter_per_s` column:

- **`chatter_per_s` counts the same crossings a hundred times more finely** than `reversals_per_min`. The coarse count
  uses a 0.02 rad/s deadband and **every one of tracelog's crossings is inside it** -- a deadband that keeps noise out
  of one number keeps the interesting noise out of it too, which is worth knowing before trusting any such count.
- **The taxi runs on the SLAB, flat and seamless on purpose**, so what is measured is the wheel model's own chatter
  with no terrain seam to confuse it. 40 s at `AirportTraffic.TAXI_SPEED`, AI-steered with `wheels: taxi`.
- **Today's number is 0.0 for every aeroplane in the fleet** (the Warthog 0.1, and that is the whole spread). So
  **today's tricycle, with its forces at the mass centre, does not chatter on flat ground at all** -- which means
  tracelog's fourteen a second is the test field's ground and not the wheel model, and it makes the gym's zero the
  most sensitive "before" available: anything the change introduces has nowhere to hide.
- **The counter is alive**, which a zero baseline obliges one to prove: the same column reads **6.8 a second** on the
  Cessna with `pitch_rate x 4`, the gym's own hunting mutant, and 6.8/s is exactly the 406 a minute the coarse count
  reads there.

**So the ground-block READY carries three numbers per kind, before and after**: `chatter_per_s` on the slab taxi (is
the wheel model quiet?), the gym's taxi settling and steady speed error (does it still roll straight and hold its
speed?), and the clip on real ground (does a braked turn look right?). If wheels at their own places damp the chatter,
that is a second argument for the change; if it grows, we know before anybody feels it in a headset.

### THE GROUND BLOCK'S FIRST QUESTION, ASKED AND ANSWERED: a taildragger's wheels cost nothing

**THE ANSWER IS THAT THERE IS NOTHING TO FEAR, AND THE QUESTION WAS BUILT ON A MISREAD.** lane/warbirds2 ran the gym
on their lane and on main at 55a201c3 and got the same numbers both times. On the 40 s slab taxi:

| | `chatter_per_s` | `reversals_per_min` |
|---|---|---|
| **P-51** (taildragger) | **0.1** | **1.5** |
| **P-47** (taildragger) | **0.1** | **1.5** |
| Cessna (tricycle) | 0.0 | **6.0** |

**A taildragger, whose wheel forces already push where the wheels are, is the QUIETEST aeroplane in the fleet on the
ground** -- a quarter of the Cessna's reversals -- and the second taildragger reads the same to the digit. **So the
tricycles have no reason to fear inheriting per-wheel forces**, and the ground block should be written without that
worry.

**WHAT I GOT WRONG, because it is the more useful half.** The 16.6 that started this is the P-51's **`waypoint`** row,
not its taxi row: one task out of eight, and the one with no wheel on anything. The two columns were read across in a
hand-off, and **I then built a detailed, plausible mechanism on a number I had never seen myself** -- a limit cycle in
`tail_down`'s boolean, complete with the loop written out. It was persuasive precisely because it fitted. **A
mechanism that explains a number is not evidence that the number is real; check the number first, and check it in the
row it actually came from.**

**What survives of it.** warbirds2 keeps the ray, and rightly: a tail wheel must be held only while there is ground
under it, and it must be a ray and never the terrain map (`tests/ground_stick.gd`). They have no objection to the
shared block ramping `tail_share` over the last centimetres of `kTailReach` instead of stepping it -- *"strictly
better physics and it costs nothing"* -- but they are explicit that **no measurement says it is currently buying
anything**, and so is this document. It goes in as tidiness, not as a fix.

### What the misread did turn up, which was mine: the waypoint task was incoherent

Chasing the P-51's waypoint number led warbirds2 to the observation that the task asks for `cruise * 0.8`, and that
for a kind whose cruise is low that lands near the stall. Checking it across the fleet found a fault **in the gym, not
in any aeroplane**:

- `AircraftMixer::slow_margin` is **1.30**. At that multiple of the stall the mixer allows **no climb at all**, and
  below it the ceiling it allows is a **descent**.
- `waypoint` is the only task that asks for a place, a height **and** a speed together -- and it was asking the **747
  and the Warthog to climb at 1.16 times their stall**. It told the autopilot to climb and refused it permission in
  the same breath, and then scored it for not getting there.

**Fixed by flooring the waypoint's asked speed**, and the shape of the floor matters twice over:

- **The stall is asked of the model, not measured and not typed**: `handling()` reports `stall_speed` beside `cruise`
  as one of "the two derived speeds, which are not settings".
- **The floor is half way from the slow margin up to the cruise, not at the margin itself.** The climb allowance
  FADES -- all of it at cruise, none of it at `slow_margin` -- so a floor set exactly at the margin buys an aeroplane
  nothing. Half way up is about half the climb. **It reproduces today's speed exactly on every kind whose cruise is a
  proper 1.45 times its stall** (the Cessna: 45.3 m/s either way, and its line did not move by a digit) and binds only
  where the cruise is lower than the design.
- **And it is applied to the `waypoint` task alone.** Flooring the level tasks as well shrank the arrival task until
  there was nothing left to slow for and **the braking curve's own check went red, because both hosts had the same
  trivial job**. A floor put in to make a task honest must not be put anywhere it makes a task empty.

**Fifteen waypoint lines moved and nothing else did.** The 747 now **fails** the waypoint -- it is flying faster and
does not get near the point in the time -- which is the same story as its speed gate and is now told honestly instead
of being hidden behind an incoherent demand.

### Still open, and NOT the ground block's

- **The P-51's 16.6 chatter and 70 reversals a minute on the waypoint, in the air.** Every other aeroplane in the
  fleet reads 0.0 to 0.1 there. warbirds2 owns it.
- **The P-47 does not arrive on the waypoint at all**: start 2,265.7 m, end 1,558.9, closest 1,553.3, throttle 0.02
  to 1.00 and **never shut**. Same shape as the Mustang's, an order of magnitude smaller. warbirds2 is writing it up.
- Their hypothesis is the formation cruise cap (`cruise_over`), with a counter-example they cannot explain: the A-10
  stalls higher than either warbird and reads 0.0 on the same task. Offered as a hypothesis and not a finding, and
  recorded here the same way. **And the A-10 counter-example holds from this side too**: the Warthog's cruise over its
  stall is 89.9 / 62.0 = **1.45**, the same ratio as the 747's, so stall margin is not what separates them.
- **How to test the cap from outside, which is now possible.** `--set=cruise=` DOES reach `cruise_over`; it is simply
  clamped there, down to the 70 m/s cap and up to 1.45 times the stall (measured, `../agents.md`). So a warbird
  pinned BELOW the cap can be flown at a different cruise -- the fighter pinned at 65 reports 65.00 -- which is enough
  to ask whether the cap is the story without changing any C++.

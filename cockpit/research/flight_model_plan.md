# The flight model: a plan for aeroplanes that fly on their surfaces

lane/flightmodel, 2026-09-18. Step 0 of an incremental build: the deep dive, the measurements and the plan. No game code
has changed. Every number here was measured on this machine (Ryzen 9 9950X3D, MSVC /O2 /fp:precise, the addon's own
compiler and flags) unless it says otherwise, and the prototype that measured it is in `flight_model_prototype/` beside
this file.

The user's words, 2026-09-18: *"i'd love for the flight physics to be more realistic and driven by flight surfaces, but
not too much, i don't want to lose a ton of performance."* And the standing ones: craft look good, fly well and do their
job; exact specs matter less; good enough for a while, tune later.

Read `cockpit/agents.md`, "The flight model, as found" first. It is groundroll's map of today's code, and this plan
starts where it stops.

## In one screen

- **Today the wing is real in shape and the controls are not.** Lift, drag, the fin and the tailplane are lumped
  coefficients that act at the centre of mass. The stick asks for a body RATE, and a servo with tens to hundreds of times the
  torque a surface could make supplies it within a tick or two. Nothing the pilot feels about the controls comes out
  of the air.
- **The target is four surfaces per aeroplane.** These are the left wing panel, the right wing panel, the tailplane and
  the fin, and a few kinds get five or six. Each has an area, a lift slope, a stall and a position, and each works out
  its own lift and drag from the airflow where it is. The controls change a surface's lift. Stability, damping, adverse
  yaw, dihedral effect, wing drop at the stall and rotation on the take-off roll all come out of that. None of them is
  typed.
- **A stateless control law sits between the stick and the surfaces.** It turns a rate demand into the deflection that
  would produce that rate, and it can never ask for more than the surfaces can give at this airspeed. The autopilot
  keeps its rate interface unchanged. A fighter keeps its fly-by-wire feel through the same law. A Cessna can be flown
  straight to the surfaces, or through a little of the law.
- **Cost: +43 ns per aircraft per tick** for four surfaces and the law (70 ns today against 113), and **+95 ns** for
  six. Box3D calls per aircraft fall from 15 to 3, so the true difference is smaller still. The server simulates each
  aircraft once per tick and never resimulates. A client resimulates only the one craft it is flying. The budget set
  below is +250 ns, and the plan uses under half of it.
- **The unedited autopilot flies it.** The game's own `AircraftMixer` (`autopilot.hpp`, included as it is) flew a
  90-degree turn and a 100 m climb through the law as well as it flies today's servo, or better. On the Cessna, height
  held within 0.3 m against 1.2 m, with no hunting. The fighter was the same.
- **The big decision is the stall speed.** Real surfaces give real stall speeds: the F/A-18F's flown stall goes from
  20 m/s today to about 67. That moves the AI's cruise, the world's soft edge and carrier landings, and the simulation
  has no arrestor wire. The recommendation is real surfaces with a game-sized maximum lift per kind for now, and real
  numbers later with the wires.

## 1. What the model does now, axis by axis, and what a pilot would feel

Measured by `tests/handling.gd` on the lane at 160c2e27 (the table is at the end of its log), by `tests/ground_stick.gd`,
and by the prototype's transcription of `fly_airplane`, `apply_controls`, `command_rate` and `pitch_demand` in the same
harness as the surface model.

| Axis | Today | Real aeroplane | Feel | Cost to fix |
|---|---|---|---|---|
| **Lift** | `(aoa + camber + flaps) x along^2 x lift`, one force at the centre of mass. The coefficients are lumped: the F/A-18F's `lift` 2,350 over its 46.45 m^2 wing is a lift slope of **82 per radian**, and a real wing has about 3.5 to 5. | 0.5 rho v^2 S CL, with CL = a alpha, and a about 4 to 5 per radian on a straight wing. | **High.** The jets cruise nose-DOWN (about -4 degrees at 150 m/s), the stall is barely reachable, and the nose never sits high on an approach. | The surfaces |
| **Stall** | A symmetric fall-off past `stall_angle`, and it is reached at absurd speeds. Flown power-off stalls: fighter **20 m/s**, airliner 26, Hawkeye 23, Cessna **17** (published: 47 kn = 24 m/s at 1,111 kg with flaps down). No wing drop, no buffet, no spin. | 1.2 to 1.6 CL clean and about 2 to 2.4 with flaps. It breaks, and one wing usually goes first. | **High.** "It never stalls" is the first thing a pilot notices. | The surfaces. Buffet is extra and cheap |
| **Pitch** | A rate servo: the stick asks for `pitch_rate` and gets it within about a tick. `pitch_stability` and `pitch_damping` are typed torques. `g_limit` caps the rate at g_limit x g / v. | The elevator moves the tail's lift. The rate settles where the tail's moment meets the damping. The trim speed moves with the elevator. | **High.** The stick has no speed feel, and the trim wheel only biases a rate. | The surfaces plus the law |
| **Roll** | A rate servo. **No aerodynamic roll damping at all**: only Box3D's constant `angular_damping`. No dihedral effect. Roll rates today: Cessna 113 deg/s, the light twin 192, the glider 56. | Aileron moment against the wing's own damping, so the rate at full stick grows with airspeed. The published classic is a pb/2V of about 0.07 to 0.09. | **High.** It rolls as fast at 30 m/s as at 60, and a glider rolls like a trainer. | The surfaces |
| **Yaw** | A rate servo on the pedals. The fin is `weathervane` plus `yaw_damping`. **No adverse yaw.** | The rudder is a side force at the tail. An aileron's induced drag swings the nose the wrong way. | **Medium.** It is what makes rudder a real control in a light aeroplane. | The surfaces |
| **Side force** | `side_lift`, linear in slip, at the centre of mass. | The fin, and the fuselage's own side force. | Low | Mostly the fin |
| **Drag** | Quadratic on three body axes, plus hanging drags, plus induced drag. | Profile drag plus induced drag per surface. The body keeps its own. | Low: today's is right in shape. | Kept |
| **Thrust** | `throttle x thrust` along the nose, constant with speed and height. | A propeller's falls with speed. A jet's falls with density. | Medium, and in the numbers, not the feel. | Later step |
| **Air density** | None. Nothing changes with height. | rho falls about 10% per 1,000 m. | Low at the heights flown here (under 1,500 m) | One multiply. Later |
| **Ground effect, P-factor, slipstream** | None | Float in the flare, swing on take-off, rudder authority from the propeller wash | Low to medium | Cheap. Later, and only if cheap |
| **On the ground** | The stick is dead below `ground_speed`, which is above flying speed, so there is no rotation (gap 3). At that speed the stick bites all at once: at rotation speed full roll puts the light twin on its back (180 degrees) and the Cessna at 112 (`ground_stick`, reported). | The elevator lifts the nose at rotation speed, and the ailerons are weak at taxi speed. | **Medium to high.** You cannot rotate. | Free: moments go with q |

**Why the controls are the root of it.** `command_rate` pushes `control_authority x bite x (wanted - rate)`, clamped to
what would close 60% of the error in one step through the body's own inertia. The fighter's 4.6 MN m per rad/s is
tens of times any real surface. In the air it uses only what it needs, so nobody sees it. Against a constraint (the
ground, the water, a pen) it pushes with everything it has. That caused groundroll's bug, floats' buried float and
tomcat2's pen. **The prototype puts a number on it:** a full stick at 5 m/s makes 198 N m of roll on the Cessna and 709
N m on the fighter through the surfaces. Today's servo made 449,000 N m on the fighter at the same speed (groundroll's
measurement), against the 248,000 it takes to lift the fighter's hull off one edge.

**What is already right, and stays.** Lift along the body's up turns a bank into a turn with nothing saying "turn".
The side force makes the flight path follow the nose. Induced drag makes a hard turn cost speed. The resist clamp is
kept on every resistance. `coordinated_turn` answered the user's "held %" (lane/handling) and stays as a rate demand
into the law.

## 2. The target: surfaces

### The fidelity chosen, and what was rejected

**Chosen: a handful of lifting surfaces per aeroplane, each a flat wing with its own local airflow.** A surface is:

| Field | What it is | Where it comes from |
|---|---|---|
| `at` | aerodynamic centre, metres from the mass centre, body axes | the drawn airframe (quarter chord at the mean chord's station) |
| `normal`, `chord` | which way it lifts, which way it faces | the drawing: dihedral on a wing panel, sideways on a fin, the cant on the F/A-18's fins |
| `area` | m^2 | the drawing, or the published wing area in `craft/<kind>/sources.md` |
| `slope` | dCL/dalpha per radian | derived from the aspect ratio: 2 pi AR / (AR + 2) x 0.92 |
| `alpha0` | incidence plus camber | the wing's: typed per kind. The tail's: **derived** (below) |
| `stall` | angle at CLmax | CLmax / slope. CLmax is the one wing number a kind tunes (decision 1) |
| `cd0`, `k` | profile drag, 1 / (pi e AR) | derived |
| `downwash` | dEps/dAlpha on a tail, 2a / (pi AR) of the wing | derived |
| `mix[pitch, roll, yaw, flaps]` | radians of effective angle per unit of each channel: flap effectiveness times the drawn travel | the drawn travels (the Skyhawk airframe already has `AILERON_UP` 20 degrees, `AILERON_DOWN` 15 and `ELEVATOR_UP` 28) |

Per tick, per surface: the local airflow `v + w x r`, its angle (one `atan2`), a lift and drag coefficient (linear to
the stall, then a blend to a flat plate whose sin 2a and sin^2 a come from the velocity components, not from more
trigonometry), and a force at `r`. The sums become ONE force and ONE torque handed to Box3D.

**What falls out, measured in the prototype (a 1,000 kg Cessna from its published 11.0 m and 16.2 m^2, with the tail
estimated):**
- **Trim speed moves with the elevator.** Hands off at 0.35 throttle: 45.2 m/s with the elevator centred, 39.3 with
  0.15 back, and 35.4 with 0.30 back. That makes the trim wheel a speed control, which is what it is in a real one.
- **Roll rate grows with airspeed.** Full stick raw: 58 deg/s at 30 m/s and 77 at 50. The glider does 14 at 25 m/s
  and 20 at 35. Today's glider does 56.
- **Adverse yaw.** Full aileron with the rudder centred: the nose swings 0.2 degrees the wrong way in the first quarter
  second. Mutant, with the wing's induced drag removed: +0.04, so it is gone.
- **Dihedral effect.** Full right rudder with the stick centred: 17 degrees of right bank after 3 s. Mutant, with no
  dihedral and the wing at the mass centre: 1 degree.
- **The stall breaks and recovers.** Stick held back power-off: alpha peaks at 23 degrees and the nose falls through.
  Released, it is flying again at 46 m/s, 145 m lower. With one panel's stall 0.01 rad early, the break rolls it to
  90 degrees of bank: **a wing drop, from nothing typed.** In the game, the asymmetry comes from yaw rate and slip at
  the break, which a human always has.
- **The stick is live on the wheels and weak there.** The Cessna makes 198 N m of full-stick roll at 5 m/s, 2.5% of
  what lifts its hull's edge, and 3,174 N m at 20 m/s. The fighter makes 709 N m at 5 m/s, 0.3%. The elevator
  therefore rotates the aeroplane at rotation speed. That closes gap 3 with no code of its own.

**Rejected:**
- **Full stability-derivative tables** (JSBSim-style CL(alpha, Mach, flaps), Cm_q and so on). They need data we do not
  have for 15 kinds and cost a table lookup per coefficient. They also make every behaviour a number somebody typed,
  which is the problem we already have.
- **Blade-element strips** (8 to 20 per wing). This is the right model for spins and wing-rock, and it is 3 to 5
  times the cost of four surfaces. It would leave the budget below.
- **Keeping the rate servo and lowering its authority to a surface's.** This treats the symptom. It still gives no
  trim-speed feel, no adverse yaw, no roll-rate-with-speed and no stall behaviour, and every kind's authority would be
  a hand-tuned number again.
- **An actuator model** (surfaces with a rate limit and a position). A position is STATE, and state has to be rolled
  back and replicated. A hand on a stick is already rate-limited, and so is the autopilot's PID output. Not now.

### One number, one place

- **The tail's incidence is derived**, never typed: at load, a bisection finds the incidence that trims the aeroplane
  level at the kind's cruise with the stick centred. The prototype derives -3.0 degrees for the Cessna at 45 m/s, -6.5
  for the glider at 30 and -2.1 for the fighter at 150.
- **`stall_speed()` becomes sqrt(2 m g / (rho S CLmax))** from the surfaces. It is what the autopilot's slow margin and
  `default_cruise` read, so both follow the wing. Today's is sqrt(m g / (camber x lift)), which is not a stall at all
  (the wing carrying the weight at zero angle of attack). That is why the handling lane found "the book stall about
  twice the flown one".
- **The roll and yaw inertia follows the drawn span.** See the stiffness trap below.
- **The surface table lives in C++ and is published** through `kind_geometry` as `"surfaces"`, as the wingtip floats
  are (lane/floats). A suite then holds the drawn airframe's tail, fin and wing to it (area, arm, span, within a stated
  tolerance), the way `savoia`'s float check does. **Trap already paid for:** a new key in `kind_geometry` changes
  every craft package's `simulation_contract` hash. Publish it only on the kinds that have it, then run
  `tools/generate_authored_packages.tscn` (lane/floats, 2026-09-18).

### What leaves `Handling` for a kind on surfaces, and what stays

- **Leaves** (the surfaces replace them): `lift`, `camber`, `stall_angle`, `induced_drag`, `weathervane`,
  `yaw_damping`, `pitch_damping`, `pitch_stability`, `flap_lift`, `control_authority`, `control_reference`, and most
  of `side_lift` (a small fuselage share stays).
- **Stays:** `thrust`, the three body drags (`drag_forward` less the surfaces' profile drag, so the top speed does not
  move), `brake`/`brake_drag`, `gear_drag`, `flap_drag`, `spoiler_drag`, `angular_damping` (smaller), everything on
  the ground and the water, `turn_coordination`, `g_limit`, and `pitch_rate`/`roll_rate`/`yaw_rate`. These three now
  mean "the rate the law asks for at full stick" and no longer "the rate a servo forces".
- **New per kind:** the surface table, CLmax clean and with flaps, the aileron, elevator and rudder travel, and the
  control law's augmentation (section 4).

### The stiffness trap, and the inertia rule

**A box's inertia is a fuselage's, and aerodynamic roll damping is a wing's.** Every kind but the Hawkeye, the fighter,
the Tomcat and a few others uses its hull box's inertia. The glider's box is 158 kg m^2 in roll. With the surfaces'
roll damping on a 20 m wing, its roll answered inside one tick in the prototype (t63 0.000 s). The damping is applied
explicitly, once per tick across Box3D's four substeps, so a time constant under a couple of ticks is the edge of
stability. Today the same thing is hidden by `command_rate`'s clamp.

**The rule:** the roll and yaw inertia is the box's plus the wing's share of the mass spread along the drawn span,
`wing_share x m x span^2 / 12`. That share is 0.10 on a light aeroplane and 0.30 on a glider, which is mostly wing. It
puts the glider at 6,158 kg m^2, with a t63 of 0.17 s. A stated inertia (Hawkeye, F-14 from the NPS thesis, fighter)
wins wherever there is one. **A guard goes with it:** at load, each kind's slowest aerodynamic time constant is checked
against 3 ticks, and a kind under it fails `many_kinds` by name. It is never silently clamped.

## 3. Performance and determinism

### Measured

`flight_model_prototype/surfaces.exe`: 1,000 aircraft x 2,000 ticks, median of 5 runs, three repeats, with the machine
at about 50% load from other lanes:

| | ns per aircraft per tick | Box3D calls |
|---|---|---|
| today: `fly_airplane` + `apply_controls` arithmetic | **68 to 72** | 15 (8 aerodynamic forces and torques, thrust, 3 `command_rate` torques and their 3 inertia reads; more for a human's `hold_the_turn`) |
| 4 surfaces, raw stick | 108 to 111 | 2 (one force, one torque) |
| **4 surfaces plus the law** | **111 to 115** | 3 (plus one inertia read) |
| 6 surfaces plus the law | 160 to 170 | 3 |

Today's per-wing cost in the game, from `tests/rota_probe.gd` at 1,000 wings (lane/rota, 2026-09-14,
`../learnings/2026-09-14-cockpit-rota.md`): 0.97 us for `drive_vehicle` less the autopilot, of which **0.48 us is the
forces themselves** once the ground query (0.43) is taken out, and about 2.5 us of tick altogether. Four surfaces add
**+43 ns: 9% of the forces and under 2% of a wing's tick.** That in-game figure is OLDER than this plan and was not
re-measured: a clean slot was not possible on 2026-09-18, with 16 Godots running across 10 lanes. **The budget is
therefore anchored on the prototype's A/B**, where both models run on the same harness with the same compiler, which is
a fair comparison between them. The in-game figure only sets the scale. The Box3D calls saved (15 to 3, each a
world lookup and a body lookup) are not counted in that, so +43 ns is an upper bound. (A clean in-game A/B of the forces
figure is step 1's first measurement, in a MEASUREMENT slot.)

### Where rollback multiplies it, and where it does not

- **The server never resimulates** (`register_simulation_jobs`: "it is authoritative and never resimulates"). It runs
  each aircraft once per tick: at 1,000 wings and 120 Hz, +43 ns is **43 us a tick, 0.5% of a core.**
- **A client resimulates only what it predicts**, and `drive_vehicle` returns before any force for a vehicle it does
  not predict (`if (!is_server_ && !predicts(entity)) return;`). It predicts only the craft in whose pilot seat it
  sits. A rollback of D ticks is therefore D x one aircraft. At a 250 ms round trip at 120 Hz (D about 30), that is
  30 x 43 ns = **1.3 us per rollback.** The Box3D step for the whole world, replayed D times, is thousands of times that.
- **The budget: no more than +250 ns per aircraft per tick** on the server, measured in the game and not in the
  prototype. Four surfaces are +43 and six are +95. Extras (ground effect, density, P-factor, buffet) are a multiply or
  two each and fit many times over.

### Determinism

- **No new state.** The law has no integrator and the surfaces have no position. Everything is computed from the
  rolled-back `VehicleState` and this tick's input, so a replay recomputes it exactly. An integrator in the law would
  be state that sync has to snapshot. It is rejected for that reason, and the prototype shows it is not needed: the
  inversion (below) has no steady error to integrate away.
- **Fixed order.** Surfaces are summed in table order in a `single_thread()` job, as every force is today, and handed to
  Box3D as one force and one torque.
- **The same functions as today.** `std::atan2` and `std::sqrt` are already in `fly_airplane` and the autopilot. Four
  surfaces add four `atan2` calls, not a new kind of risk. The known risk is unchanged: a Linux peer built with FMA
  contraction (GCC's default `-ffp-contract=fast`) can differ in the last bit from a Windows peer. That costs a
  correction, not a desync, because the server is the authority. It is written down here, not fixed here.
- **Float, as the simulation is.** Box3D is float on both builds. The double build changes Godot's `real_t` and not
  this arithmetic.
- **No branch on uninitialised state.** The table is built at load from the kind. A kind without a table keeps today's
  model (a switch per kind, below). The law's divisions are guarded (`|per| > 1e-3`), so zero airspeed gives zero
  deflection, not a NaN.

## 4. The autopilot, the AI, and the stick a person holds

### The law

`control_law` in `flight_model_prototype/model.hpp`, about 25 lines. Per axis (pitch, roll, yaw):

1. The surfaces are evaluated once with the pitch, roll and yaw channels at zero. That gives the moment the airframe
   makes by itself, `M0`, and, linearised at this state, the moment one unit of each channel adds, `Mc`. The second is
   nearly free: it is the same lift slope times the same q.
2. The moment wanted is `I x (rate asked - rate now) / settle`. The deflection is `(wanted - M0) / Mc`, **clamped to
   full travel.**
3. The deflection's moment is added, and the deflection is what the airframe draws.

This is dynamic inversion through the model we already have, and it cannot cheat. At low q, `Mc` is small and the
clamp binds: a slow aeroplane answers slowly because its surfaces cannot do more. A stalled surface's control goes limp
(its `dcl` falls to zero past the stall), so the law cannot fly through a stall. For comparison: today's servo gave the
fighter its full 2.25 rad/s at 24 m/s. Through the law it gets 114 deg/s at 80 m/s, 128 at 150 and 129 at 220 (asked
129). **It is stateless** (see determinism).

### The autopilot, measured

The game's `AircraftMixer`, from `autopilot.hpp` included unedited, configured as `fly_it_like_a` configures it (the
kind's stall, cruise and bank limit), flying a 90-degree heading change and a 100 m climb at once from level at cruise.
Today's model gets its levers as a rate servo. The surface model gets the same levers as a rate asked of the law.

| | heading within 5 deg | overshoot | height within, 30-70 s | climb reversals | slowest |
|---|---|---|---|---|---|
| Cessna, today (rate servo, box inertia) | 17.2 s | 0.0 deg | 1.2 m | 0 | 52.5 m/s |
| Cessna, surfaces and the law (settle 0.12 s) | 7.8 s | 0.2 deg | **0.3 m** | 0 | 40.3 m/s |
| Fighter, today | 30.5 s | 0.0 deg | 0.9 m | 0 | 74.6 m/s |
| Fighter, surfaces and the law | 21.2 s | 0.0 deg | **0.5 m** | 0 | 99.4 m/s |

The heading times are not like for like: each model flies at its own derived cruise, and the surface Cessna's is
slower (41 m/s), so its turn is tighter. The point is the other columns. **Nothing in the mixer had to change**, the
settle time made no difference between 0.03 and 0.12 s, and nothing hunts. **So the autopilot keeps its rate loop,
and the law is its servo.** It never uses a raw stick. That is also what a real autopilot does: it drives servos
behind the surfaces.

**What still moves for the AI, and is measured at step 2:** the cruise follows the new stall (`default_cruise` is
max(0.55 x flat-out capped at 70, 1.45 x stall)), so the stall decision below moves every AI cruise with it. Hold, before
and after (the baselines are recorded, all green on the lane at 160c2e27): `trim` (height wander 0 m on every
aeroplane, no porpoising), `climb` (fastest climb 7.3 to 8.3 m/s against a cap of 10, steepest 5.2 to 6.0 degrees
against 9), `avoid` (the tanker 686 m up over a 680 m face, 0.9 m/s lost), `holding_stack` (600 aircraft, worst 1.85 m
off its layer against 10), `air`, `smoke`'s formation checks (`the_flights_hold_to_a_wingspan`,
`the_flights_settle_rather_than_hunt`), and `terrain_level`'s widest turn.

### The person holding the stick: augmentation per kind

One number per kind, `augmentation`, from 0 to 1, blends the law's deflection with the raw stick: `u = a x law + (1 -
a) x stick`. The autopilot always flies at 1. The coordinated turn (lane/handling) and the g limit go into the rate
the law is asked for, so at 0 they fall away with it.

| Kind | Recommendation | Why |
|---|---|---|
| F-16 (falcon), F/A-18F (fighter), Prowler | **1: fly-by-wire.** Stick is rate, g limit, alpha limit, auto-coordinated | Both real aircraft are fly-by-wire. The feel people have now is kept, and the limits become honest |
| F-14 (tomcat) | **0.7**: a stability augmentation over mechanical controls | The real F-14 was hydromechanical with a SAS. It should feel heavier than the Hornet |
| Airliner, Mercury, Hawkeye, gunship, tanker (water bomber), Osprey's wing | **0.5**: a yaw damper and turn coordination, the stick mostly direct | Big aeroplanes with dampers. Trim matters, and turns take pull |
| Cessna, light twin, Savoia, glider | **0 raw**, with an option (decision 3) | The mechanical feel: adverse yaw, rudder, pull in a turn, the trim wheel as speed |

At 0 the handling suite's "held %" will fall from 100 (a centred stick in a bank does not hold the turn in a real
Cessna). That is realism the user asked for, and it undoes lane/handling's fix for these four kinds, which is why it is
decision 3 and not a default.

## 5. What changes for which kinds

**On surfaces** (every `Model::Airplane` kind, and the tiltrotor's wing): the plane (light twin), Cessna, glider,
fighter (F/A-18F), falcon (F-16), tomcat (F-14), prowler (EA-6B, which shares the Tomcat's case today and gets its own),
airliner, Mercury, Hawkeye, tanker (CL-415 water bomber), Savoia, gunship, and the Osprey in aeroplane mode.

| Kind | Surfaces | Special |
|---|---|---|
| Most | 4: wing L/R, tailplane, fin | — |
| Fighter, F-16, F-14 | 5: two fins (canted 20 degrees on the F/A-18, `fighter.gd` holds it) or one, and the tailplane as a stabilator | The stabilators also roll (differential tail). The F-14 rolls with **spoilers** (a one-sided lift loss, locked out past 57 degrees of sweep, tomcat2's `spoiler_share`) and the tail |
| F-14 | 5 | **The sweep can move the wing's `at`, area and slope**, which makes the sweep channel physical. Later, and only if wanted (decision 4). Today the user said "for now it doesn't need to change the flight characteristics" |
| Glider | 4 | No engine; `powered` false as now. Thermals from `air_at` at the mass centre, as today. Sampling the thermal at each wing panel (a thermal under one wing lifts it) is a later extra |
| Osprey | wing and tail only | `fly_tiltrotor` calls `fly_airplane` with `flown` false for the wing. The rotors stay the controls. The surface table replaces the lumped wing there too |
| Savoia, tanker | 4 | Amphibians: `alight` and the wingtip floats run after the flight model, unchanged. The surfaces make no moment at 5 m/s, so the float is never pushed under by the stick again |

**The F-14's drawn surfaces can follow the real deflections.** The law's output is the deflection. `VehicleView`
already hands `TomcatAirframe` and the F-16 their stick, and the deflection can replace it, locally for the pilot. A
spectator still draws them neutral, because the stick is not on the replicated bus (tomcat2's note). That is unchanged.

**Helicopters are out of scope.** Nothing in `fly_helicopter`, `thruster_bite` or the rotor suites moves.

**The ground and the water.** The taxiing branch stays: the nosewheel steers, and `steer_on_the_ground` blends to the
fin (now the real fin). What changes is that the stick is no longer dead on the wheels. It makes what the surfaces make,
which at taxi speed is almost nothing (above) and at rotation speed lifts the nose. `ground_stick`'s parked and 5 m/s
rows must still hold. Its "at rotation speed" line becomes a held check (the nose rises, the bank stays under 10
degrees). groundroll's pen in `bench.gd --parked` can then go. floats and `water_rudder` hold as they are. Coordinate
with seakeep through team-lead before touching anything next to `alight`.

## 6. Tests: proving it is more realistic without a tautology

The trap is a test that types the model's own formula as its expectation. Each check below flies the aeroplane through
the pilot's control frame (`set_pilot_input`) or the autopilot, and holds it to a number from OUTSIDE the model: a
published figure, a sign, or a ratio between two flights. Each has a mutant that must turn it red. The mutants are
switches on the surface table set through `set_handling` (for example `surface_k_scale=0`), so they cost no build.

| Check | Measured by flying | Held to | Mutant (must fail) |
|---|---|---|---|
| The stall emerges | power-off, height held, slow down | the Cessna's published 47 kn CAS flaps-down at 1,111 kg, scaled to the game's 1,000 kg (22.9 m/s), within 10% | CLmax x 2 |
| Flaps lower the stall | the same, flaps up and down | flown flaps-down < flown clean by the published margin | flap mix 0 |
| Trim speed follows the elevator | hands off, trim wheel at three settings | speed strictly falls as the trim goes back | the tail's control mix 0 |
| Roll rate grows with airspeed | full stick raw at 30 and 60 m/s | rate(60) / rate(30) between 1.3 and 2.2 | the wing panels' `at.x` 0 (no damping arm) |
| Adverse yaw | full aileron, feet still, raw | the nose moves AWAY from the roll in the first 0.25 s | the wing's induced drag 0 |
| Dihedral effect | full rudder, stick centred | bank grows TOWARD the pedal | dihedral 0 and the wing at the mass centre |
| The stall breaks and recovers | stick held back power-off, then released | alpha passes the stall, the nose drops, it flies again within N s | the post-stall blend removed |
| The law never beats the air | the law asked for full roll at 30 and 150 m/s | the rate at 30 is below the rate at 150 | the clamp removed |
| The stick cannot tip a parked or taxiing aeroplane | `ground_stick`, as now, without a pen | as now | the old servo |
| Rotation | full back stick at the kind's rotation speed on the runway | the nose rises more than 5 degrees before lift-off | the tail's control mix 0 |
| The drawn surfaces are the simulated ones | `kind_geometry("surfaces")` against the airframe's constants | area and arm within 5% | a tail moved 1 m |
| The AI fleet | `trim`, `climb`, `avoid`, `holding_stack`, `air`, `smoke` | today's numbers (above) | — |
| Handling table | `handling.gd`, before and after | roll, top speed, climb and take-off within a stated band. Held % is decision 3 | — |

Roll rate in particular is the one where the published figure is soft: the classic pb/2V of 0.07 to 0.09 is a
design requirement, not a measurement of any one of these aircraft. So it is held as a ratio between two speeds, not
as a figure.

## 7. The step order

Each step lands, gates and is sent READY before the next is built, per the lane rule.

1. **The surface model for ONE aircraft, the Cessna, behind a per-kind switch** (`surfaces` on or off in `Handling`,
   default off everywhere but where it is tried), A/B against today in `handling.gd --kind=cessna --set=surfaces=0/1`.
   This covers the surface table in C++, the inertia rule, the derived tail and `stall_speed`, the law with
   `augmentation`, and one force and one torque to Box3D. The first thing measured, in a MEASUREMENT slot, is
   `rota_probe` with 1,000 Cessnas on and off (the in-game cost). The tests are the realism checks above, for the
   Cessna, each with its mutant. C++, so it waits its turn in the serial queue.
2. **The autopilot and AI, on the Cessna, then the light twin and the airliner.** The mixer is unchanged: prove it with
   `trim`, `climb`, `avoid`, `air` and `smoke`'s formations before and after. Decide the stall figures (decision 1),
   then re-run `terrain_level` for the widest turn.
3. **Roll out to the fleet**, a few kinds per commit: the light aeroplanes (plane, glider, Savoia), the big ones
   (airliner, Mercury, Hawkeye, tanker, gunship), the jets (fighter, falcon, tomcat, prowler), then the Osprey's wing.
   `many_kinds` holds that every aeroplane has a table or an intended default. The stiffness guard runs at load. Each
   kind's handling row stays in its band. `ground_stick`'s rotation line becomes held. The old lumped path is deleted
   once no kind uses it, because two models kept in step is the trap `Model::FlyingBoat` was refused for.
4. **The extras, only if cheap and only if wanted:** stall buffet (a camera shake and a sound from alpha near the
   stall, display only, zero simulation cost), ground effect (a CL and k factor under one span of height; the height is
   already asked), density with height (one multiply), propeller P-factor and slipstream over the tail (rudder
   authority on the ground), thrust lapse, the F-14's sweep in the surfaces, and thermals per wing panel.

## 8. Risks

- **The AI's speeds move with the stall** (decision 1). Every formation, holding stack and world edge is sized on
  today's cruise and turn radii. Mitigation: step 2 on its own, with the whole AI set of suites before and after.
- **Stiffness on light, long-winged kinds.** Mitigation: the inertia rule and the load-time guard.
- **Numbers in other suites that know the handling table** (lane/handling's lesson): `cockpit_loopback` wants the light
  twin airborne within 1.75 s and taxiing 40 m in 10 s at 5%, `smoke`'s `an_airliner_can_raise_its_nose`, and
  `terrain_level`'s turn radii. Run each with `--set` before building, not after.
- **Feel is not a suite.** Held % and roll rates can be measured, but whether a raw Cessna is fun in a headset is the
  user's call. Mitigation: the switch in step 1 lets the user fly both.
- **Packages.** A new `kind_geometry` key re-hashes every package. Publish it only on the kinds that have it, and
  regenerate.
- **The water.** The amphibians' take-off (`water.gd`, no skipping) runs through the new lift. Hold it at step 3, and
  coordinate with seakeep.
- **Weapons mass and drag** (jetarms): a heavier fighter now stalls faster, and that is real. Stores' drag is a body
  drag and fits in unchanged. Coordinate through team-lead.

## 9. Decisions for the user

1. **Stall speeds.** Real surfaces put the F/A-18F's flown stall near 67 m/s (130 kt), where today it is 20. The
   knock-on: the AI's cruise follows the stall (`default_cruise` is at least 1.45 x stall, over the shared 70 m/s
   formation cap), so the fighter's AI would cruise near 100 m/s. Every level's soft edge is sized on the widest
   top-speed turn at the autopilot's bank (`turn_radii`), and it widens. A carrier landing at 70 m/s onto 330 m of deck
   with wheel brakes alone does not stop, because the simulation has no arrestor wire. The options:
   - **A. Realistic everywhere, with the AI retuned.** The fighter near 67 m/s, the airliner and the big aeroplanes at
     their real figures. It needs the formation cap raised or made per kind, the edge bands re-sized (`terrain_level`,
     `level_swap`, `ship_legs`), and an arrestor wire and a catapult in the simulation before a jet can use the carrier.
     The most real, and the most work: a lane of its own after this one.
   - **B. Softened everywhere.** Every kind keeps about today's BOOK stall (what the autopilot already believes: Cessna
     38, fighter 36, airliner 50), with the stall's character real (the break, the wing drop, the nose attitude) but at
     those speeds. Nothing in the AI moves. But the light aeroplanes stall faster than the real ones (the Cessna at 38
     against a published 24), which is the wrong way round.
   - **C. Per kind** (**recommended**): CLmax is one number per kind, so each gets the stall that serves it. The light
     aeroplanes and the glider get their real ones (Cessna about 24 m/s, glider about 22), which are at or below the
     book stall the AI uses today, so their AI does not speed up. The jets and the carrier aeroplanes get a generous
     one (about 45 to 50 m/s with flaps down), so formations, world edges and carrier landings keep working. It moves
     to A kind by kind when the wires exist, and each move is one number and a suite run.
2. **Fly-by-wire where the real aircraft has it?** **Recommended: yes**, per the table in section 4: the F-16 and
   F/A-18 (and Prowler) keep today's crisp rate feel, now with honest limits. The F-14 is a little heavier. The big
   aeroplanes get a damper.
3. **The light aeroplanes: raw, or with a turn assist?** Raw means rudder matters, the nose falls in a turn unless you
   pull, and the trim wheel sets the speed. That is a real Cessna, and it undoes lane/handling's "held %" for those
   four. **Recommended: raw for the Cessna and the glider, where the user wants the aircraft to be the lesson, and a
   light assist (0.3) on the light twin and the Savoia, which are the fun ones.** A settings toggle later would let a
   player choose.
4. **The F-14's sweep in the flight model?** It is cheap once the surfaces exist (move the wing's centre and area with
   the sweep). **Recommended: later, as an extra**, because the user said it need not fly differently yet.
5. **How far past four surfaces?** **Recommended: four, five where the aircraft has two fins or rolls with its tail;
   never strips.** That fits the budget with room for the extras.

## 10. The prototype

`flight_model_prototype/`, not built by anything, and not part of any suite:
- `model.hpp`: today's `fly_airplane` + `apply_controls` arithmetic, transcribed for timing; the surface model; the law;
  a 120 Hz harness that steps as Box3D does here (forces held over the tick, four substeps, angular damping as a divisor).
- `surfaces.cpp`: the timing, and the Cessna's trim, stall, roll, adverse yaw and stall-break checks.
- `fleet.cpp`: the kinds built from a few measured numbers with the tail derived; the glider's stiffness trap; the
  fighter's law; rudder alone; the stick on the ground; and the game's `AircraftMixer` flying both models.
- `build.bat` builds both with the addon's MSVC. `results.txt` is the run the numbers above came from.

The tail areas, arms and inertias in it are ESTIMATES for a prototype. In the build they are measured off the drawn
airframes, which already carry them (`skyhawk_airframe.gd`: `STAB_*`, `FIN_*`, the aileron's 20 up and 15 down, the
elevator's 28 and 23, the rudder's 17.7).

Known gaps in the prototype, which step 1 must close: flaps lowered the Cessna's book stall from 26.1 to 22.2 m/s but
its flown stall only from 25.9 to 25.7. The height-holding loop or the tail's own stall is the likely cause, and it has
not been found. The law adds a deflection's moment but not its force (a few per cent of the tail's lift). The fighter's
law reached 7.0 g of an 8 g limit in a 2 s pull, where today's servo reaches 8.4.

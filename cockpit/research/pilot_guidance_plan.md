# The pilots: a plan they can fly, an envelope they can ask, and a gym that scores them

lane/flightcore, step 0 of the guidance work, 2026-09-19. A plan and no game code, as the flight-model review was.

The user, 2026-09-19, in full:

> "Performance is very important, let's make sure we cache some data for pilots so that they don't have to resample
> every time they need to take an action, otherwise all actions are very jerky and oscillate quite a bit. This is why
> you should take a look at the pid work in ./godotgames/ (up from cockpit). There is some work in there. Perhaps the
> AI pilot should have a destination waypoint and altitude, and it should consider how to get the airplane/helicopter
> on a derivative that would take them there. So not just one pid that controls the stick/throttle/etc but (climb at
> forward speed X and pitch for that speed until i hit my altitude, but i should know when i'm approaching the target
> so i can slow my speed and not overshoot)
>
> I think you should build a "vehicle gym" that pressure tests this with different aircraft (a cessna can't climb fast
> enough sometimes, and a jumbo jet can't slow down enough sometimes) so being able to know your min/max speeds and
> goal speeds when doing things (ascend/descend) means you can better predict what to do."

## In one screen

- **The pilots fly without knowing what the aeroplane can do.** Every setpoint is a step: a phase changes and a new
  height, speed and aim point arrive at once. Nothing works out when to start slowing, when to start levelling off, or
  whether what it just asked for is possible at all. The loops then do what loops do with a step and a saturating
  limit: overshoot, come back, and saw.
- **`pid-control/` needs nothing taken from it but two ideas.** Cockpit ported it into `autopilot.hpp` long ago and
  carries a superset. The gold example the user is describing is elsewhere in the workshop and already written: the
  train's `auto_driver.gd`, whose outer loop is a braking curve, `v = sqrt(2 a d)`.
- **The missing piece is an ENVELOPE, asked of the flight model**: minimum and maximum speed, best climb speed and
  rate, the descent it can hold, the deceleration and acceleration available, and its turn rate at a bank. Nearly all
  of it is already inside the models; two of them are new and a few lines each. **Nothing is typed.**
- **With the envelope, a pilot plans and then tracks.** A plan is a few gates -- a place, a height, a speed -- and the
  distance at which each must begin, from `d = (v^2 - target^2) / (2 a)` and `lead = climb^2 / (2 a_v)`. It is cached
  on the pilot and made on the rota; the tick interpolates ALONG it, so the setpoint keeps moving between serves
  instead of standing still. That is the smoothness and the caching the user asked for, in one mechanism.
- **A VEHICLE GYM scores it**: the same tasks for every kind -- level off, make a speed gate, climb at a speed, turn to
  a heading, fly to a waypoint, an approach -- scored on overshoot, settling time, steady error, ENVELOPE HONESTY (how
  often the plan asked for the impossible) and CONTROL ACTIVITY, which is the oscillation the user keeps seeing and the
  one number no suite here has ever measured. Thresholds per kind, so a change that smooths a Cessna and spoils a 747
  cannot pass.
- **It does not overlap lane/pilotcost.** They own how often and how cheaply a pilot thinks, and are building the
  once-a-tick index; this owns what it decides. The planner reads their index rather than sampling the world again.
- **The user's own `AI_Pilot_Guidance_Brief.md` was read after the rest of this was written, and section 9 says what
  was taken from it, what was adapted and what is wrong for this tree.** The short version: TECS for the aeroplane's
  energy layer is taken and is the brief's best addition; the mixer does NOT ask for body rates (the rate layer is
  already a layer further down, inside the model); planning at 5--10 Hz and holding the commands would ADD the
  sample-and-hold this plan is trying to remove; and the envelope is derived from the model, never typed from a book.
- **First, and it needs no C++ turn: the gym, measuring today.** It puts numbers on the user's two examples and gives
  every step after it a scoreboard. Then the envelope, then the anticipation in the planner, then the tracker.

## 1. What a pilot does today, and where the jerk comes from

Two layers fly every AI craft, and neither knows what the aircraft can do.

**The route layer, GDScript** (`world/airport_traffic.gd`, 1,101 lines). `_think` is served on the chore rota, and per
phase it calls `_steer` -> `steer_ai(entity, {toward, altitude, speed, wheels})` with a CARROT: a point some distance
ahead on the leg. `set_ai_manners` gives it a bank limit, a climb rate and (since lane/smoothturn, light aeroplanes
only) a roll rate. The phases are a state machine: taxi, hold_short, line_up, align, take_off, departure, departing,
crosswind, downwind, base, final, flare, roll_out.

**The control layer, C++** (`autopilot.hpp`'s `AircraftMixer`, `HeliMixer`). Cascaded already: height -> climb rate
-> stick, heading -> bank -> stick, speed -> throttle, slip -> rudder. The outer loops are P only (`altitude_outer`
0.45, `heading_outer` 1.7); the inner ones have I and D.

**Where the jerk and the oscillation come from**, in the order I would fix them:

1. **Nothing anticipates the arrival.** The altitude loop is proportional with a cap: commanded climb is
   `0.45 x error`, clamped to the kind's `max_climb_rate`. So it flies at full climb until the error is
   `climb / 0.45` and only then begins to ease. **The distance it actually needs is `climb^2 / (2 a)`**, where `a` is
   the vertical acceleration the aeroplane can produce at that speed. At 10 m/s of climb, the loop starts easing 22 m
   out and a heavy needs about 50: it goes through the height and comes back. The same arithmetic, unwritten, is why a
   747 cannot make a speed gate: slowing from 90 m/s to 70 needs `(90^2 - 70^2) / (2 a)`, and at an airliner's clean
   deceleration of about 0.35 m/s^2 that is **4.6 km**, where the phase change gives it a few hundred metres.
2. **The setpoint steps.** Each phase hands over a new height and a new speed at once, and the carrot jumps to the next
   leg. A step into a proportional loop is a kick, and the kick is what a person sees as jerk.
3. **The setpoint is stale between serves.** `_think` runs on the rota; between serves the carrot does not move, so
   the correction is computed against where the aircraft was, not where it is. That is a sample-and-hold in the middle
   of a control loop, and it saws.
4. **The plan is re-made under the aeroplane.** `_gauge_the_turn` re-sizes the pattern mid-flight, and an instrument
   approach re-lays its vectors from the new turn (`_think`, the `replan` branch). Every re-lay moves the fixes the
   aircraft is flying at.
5. **One loop's limit is another loop's input.** The mixer's climb allowance is scaled by `spare`, a function of
   airspeed, so a speed error becomes a climb-rate limit change: lane/cessnafm measured exactly this hunting between
   0.2 and 5.8 m/s of sink on base when the flaps came out as a speed brake.
6. **The manners are the only per-kind knowledge in the loop**, and they are three numbers (bank, climb rate, roll
   rate). Nothing knows a minimum speed, a deceleration, or a turn radius.

## 2. `pid-control/` at the repo root: what to reuse

**Read, and the answer is: take two ideas and no code.** `pid-control/` is a standalone lab -- an addon plus a demo,
on Godot 4.6.2, whose own runners still point at another machine's username, and whose strategy document marks its
last three build steps "not yet". It was never wired into a game. Its README says so plainly: *"Copy
`addons/pid_control/` into a game; improve it here."*

**Cockpit already did that, and has moved well past it.** `autopilot.hpp` says so in its first line ("Ported from the
`pid_control` addon"), and what it carries now is a superset:

| | pid-control | cockpit's `autopilot.hpp` |
|---|---|---|
| `Pid`: anti-windup on saturation, derivative on measurement, clamped output | yes | the same, near line for line |
| a cascade: an outer loop whose output is a LIMIT, an inner that tracks it | yes | the same |
| aircraft, ground and boat mixers | yes | the same, plus **HeliMixer** and **SailMixer**, which the addon has not |
| formation guidance with a clamped intercept (the anti-360) | yes | the same, plus gain scheduling on crosstrack, a rate term, turn-rate feed-forward, a helicopter's side-step and stacking |
| `max_descent_rate`, `bank_rate`, `climb_angle` and `climb_share`, `slow_margin`, a glider's own speed loop | no | yes, each with the measurement that earned it |

So: **do not depend on it, do not fork it, and do not copy code out of it.** It is a lab whose lessons were taken
already. Two things in it are still worth having, and both are ideas rather than lines:

1. **`WaypointGuide`'s arrival radius scales with speed** (`reach = max(arrive_radius, airspeed_bug * 1.8)`), and
   widens again when the height is wrong. Cockpit's equivalent is `kArrived`, a flat 220 m for everything from a
   Cessna to a 747 -- four seconds of flying for one and a second and a half for the other. The envelope makes that a
   derived number instead of a constant.
2. **`docs/STRATEGY.md` section 6 proposes a `PilotProfile` resource -- the per-kind limits a pilot reads -- and
   records that it was never built.** That is this plan's envelope. The reason to build it from the flight model
   rather than as a typed resource is the rule the book suites already follow: ask the model.

**And the gold example is elsewhere in the workshop, already written.**
`previous_projects/august-15-train/scripts/auto_driver.gd` is the anticipation the user is asking for, in a train:
*"outer: distance to the next stop -> the speed to be doing right now; inner: speed error -> throttle or brake. The
outer loop is a braking curve, `v = sqrt(2 a d)`: the speed from which the train could still stop on the marker at a
comfortable rate."* It plans on LESS deceleration than it has, so something is left for a late correction; it aims a
little short of the marker, so the last metres are crept rather than braked; and its inner loop carries a feed-forward
for the forces already acting, which is what holds a train's speed up a hill (*"the old one cruised at 13.97 for a
target of 14.00 and never got closer"*). `pid-control`'s own strategy document names this file as the example it never
ported.

**The aeroplanes have never had any of it.** That is the whole of the user's complaint, and the shape of the fix is
already in this repository, written down, with its measurements.

## 3. The envelope: what each kind can do, asked of the model

**The fix for "a Cessna cannot climb fast enough and a jumbo cannot slow down enough" is for the pilot to know both
before it asks.** Every number below already exists inside the flight model or falls out of it in one line, and
**none of it is typed**: that is the same rule the book suites hold ("ask the model", `../agents.md`, "A SUITE THAT
KEEPS A FORMULA BESIDE THE MODEL").

| The pilot asks | Answered by | Today |
|---|---|---|
| minimum speed (the stall, and the margin over it) | `stall_speed(index)` -- the surfaces' CLmax, or the lumped wing's | exists |
| maximum speed | `flat_out(index)` -- thrust against drag, the propeller's line included | exists |
| best climb speed, and the rate there | `best_climb_speed`, `sustained_climb` | exists |
| the descent it can hold without gaining speed | `idle_sink` | exists, propellers only |
| **deceleration available**, clean and with everything out | thrust at idle minus drag at this speed, over the mass: the same `zero_lift_drag` and `thrust_at` those two use, plus `flap_drag`, `gear_drag`, `spoiler_drag`, `brake_drag` | **new, four lines** |
| **acceleration available** at full power | `thrust_at` minus drag, over the mass | **new, two lines** |
| **turn rate and radius at a bank** | `g tan(bank) / v`, and what the kind actually achieves (`AirportTraffic._gauge_the_turn` measures 0.28 to 0.99 of it today) | the gauge exists; the envelope should carry both |
| roll rate available | the surfaces' own damping and travel (`roll_damping`), or the kind's `roll_rate` | exists for a surface kind |
| **the vertical acceleration it can pull** at this speed | the load factor the mixer will ask for, against `g_limit` and the stall margin | **new** |

**How the pilot uses it.** Three questions, each answered with arithmetic a school-leaver can check:

- **"Can I be at that height by that point?"** `time = distance / speed`, `climb needed = (target - here) / time`, and if
  that exceeds `sustained_climb` at the speed it will fly, **the plan is wrong, not the loop**: ask for the height
  later, or slow to the best climb speed first. Today the loop just saturates and the aeroplane arrives low.
- **"When do I start slowing?"** `d = (v^2 - target^2) / (2 a)`, with `a` the deceleration available in the
  configuration it will use. Begin there, not at the phase boundary.
- **"When do I start levelling off?"** `lead = climb^2 / (2 a_v)`. Begin there.

## 4. The guidance layer: a plan, then tracking it

**The shape: PLAN, then TRACK.** The rota serves the planner; the tick runs the tracker.

- **A PLAN is a short list of gates**: a place, a height, a speed, and how it is reached (climb at best-climb speed,
  descend at idle, hold). It is made from the route the phase wants, the envelope above, and the anticipation
  arithmetic. It is data, and it is cached on the pilot.
- **The TRACKER runs every tick** and reads the plan, not the world: where should I be now, at what height and speed?
  It interpolates ALONG the plan, so between rota serves the setpoint keeps moving instead of standing still. That is
  the user's "cache some data so they don't have to resample", and it is also what stops the sawing.
- **The setpoints are rate-limited** to what the kind can do: bank at its roll rate (lane/smoothturn did this for the
  circuit's light aeroplanes, and it is general), climb at its achievable vertical acceleration, speed at its
  acceleration. A rate-limited setpoint cannot kick a proportional loop.
- **The cascade the user describes falls out of it**: "climb at forward speed X and pitch for that speed until I hit my
  altitude" is a plan whose gate is a height, whose speed is `best_climb_speed`, and whose exit is anticipated by
  `climb^2 / (2 a_v)`.

**Where each piece lives.**

| Piece | Where | Why |
|---|---|---|
| the envelope (`envelope(kind)`) | C++, beside the models, built at load and rebuilt on `set_handling` | it is the model's own arithmetic; and every AI kind, not just the airport's, should have it |
| the anticipation arithmetic (the three distances) | C++, in the guidance block, and exposed so a suite and the GDScript planner can ask it | one number, one place: the pilot and the gym must agree |
| the tracker (interpolating the plan, rate-limiting setpoints) | C++, between `fly_itself` and the mixers | it runs every tick, and it must be deterministic for rollback |
| the plan itself (which gates, in what order) | GDScript, `AirportTraffic` and friends | it is route and procedure, it changes often, and it is where the game's rules live |
| the mixers | unchanged | they are tuned, and lane/cessnafm proved the rate interface survives a new flight model |

**Determinism**: a plan is derived from the craft's state and the route, both replicated; the tracker is a pure
function of the plan and this tick's state. Nothing new goes on the wire.

## 5. The vehicle gym

**A harness that flies every kind through the same tasks and scores them**, so "smoother" is a number and a change that
helps a Cessna and hurts a 747 cannot pass. `tests/vehicle_gym.gd`, with `cockpit/tools/vehicle_gym.ps1` for a full
sweep and a per-kind table.

**The tasks** (each from a settled cruise, each flown through the real path, autopilot or scripted pilot):

| Task | What it asks | Why it is here |
|---|---|---|
| **level off from a climb** | climb 300 m and hold the new height | the user's overshoot |
| **level off from a descent** | descend 300 m and hold | heavies float |
| **make a speed gate** | be at a stated speed by a stated point | the jumbo that cannot slow |
| **climb at a speed** | hold best-climb speed through a 300 m climb | the Cessna that cannot climb |
| **turn to a heading** | 90 and 180 degrees at the kind's bank limit | roll-in and roll-out |
| **fly to a waypoint at a height and speed** | arrive within a band on all three | the whole plan in one |
| **an approach** | a 3-degree path to a gate at a stated speed | what the pattern and the instrument approach do |
| **a helicopter's own**: hover to a point, hover taxi, a 500 ft circuit | the rotorcraft cases | `HeliMixer` is a different cascade |

**The scores**, per task per kind:

- **overshoot**: the most it went past the target, as a share of the step;
- **settling time**: to within a band and staying there;
- **steady error**: what is left when it has settled;
- **CONTROL ACTIVITY**: the sum of `|delta control|` a second on each axis, and the number of sign reversals a minute.
  **This is the oscillation the user is describing**, and it is the one number today's suites never look at;
- **envelope honesty**: how often the plan asked for something outside the envelope (a climb the engine cannot hold,
  a deceleration the airframe cannot make). A good pilot's answer is zero.

**The thresholds.** Per kind, from a baseline measured before anything changes, plus the absolutes the books and the
procedures already give (a 3-degree final, +10/-5 kt at the gate, 500 to 1,000 ft/min on descent). A change must not
worsen any kind's score by more than a stated margin: **that is how a Cessna's improvement cannot pay for a 747's
regression.**

**Mutants**: rate limits off must raise control activity; anticipation off must raise overshoot; the envelope replaced
by a generic one must raise the envelope-honesty count. Each is a `--set=` or a flag, not a rebuild.

## 6. Caching, and the line with lane/pilotcost

**pilotcost owns the cost of thinking; this owns the quality of the decision.** They are measuring today that the
airport pilots' looks are about 80 per cent of the tick at 100 aircraft and grow super-linearly, and they are building
a once-a-tick index so each pilot stops walking every other pilot.

**What this layer must read rather than sample:**

- **their index** for "who is near me", the leader, the runway's state and the crossing: a planner asks once when it
  makes the plan, not per tick;
- **the terrain look** (`_high_ground_ahead`, `look_ahead` on the rota) as it stands: a plan is made against the look
  that has already been taken, not a fresh one;
- **its own plan**, which is the new cache: made on a rota serve, read every tick.

**What this layer adds to the cost**: the tracker's per-tick work is a handful of multiplies (interpolate, rate-limit,
hand to the mixer), and it REMOVES the re-planning that today happens inside `_think`. The envelope is built once a
kind at load. I would expect it to be cost-neutral to slightly cheaper per pilot, and it must be measured that way in
a MEASUREMENT slot with pilotcost's own stress harness, not a new one.

**No duplication**: I will not build an index, a separation rule or a rota change. If the planner wants something their
index does not have, that is a request to them through team-lead.

## 7. Where it fits the steps already agreed, and what I would do first

The flight-model steps stand (review section 9): blocks, the Little Bird, the Cessna, the propeller, then the fleet.
Guidance is orthogonal to those, and the gym is what tells us whether either is working.

**What I would do first, and it needs no C++ turn:**

1. **The gym, measuring today.** It is GDScript, it lands on its own, and it gives every later step a scoreboard. It
   will also put numbers on the user's two examples for the first time.
2. **The envelope, exposed.** Mostly existing functions gathered into one `envelope(kind)` call, plus deceleration and
   acceleration. Small C++, and it can ride with step 1 of the blocks.
3. **The anticipation, in the planner.** The three distances, used by `AirportTraffic` to move its phase boundaries.
   GDScript, and it should cure the 747's speed gate on its own.
4. **The tracker and the rate limits.** C++, with the gym as its proof.

**And one thing it is not.** The 747 turning at 0.28 of its bank's rate (`todo/airport--747-turns-at-0.28.md`) is NOT
a guidance fault and this work will not fix it: the aeroplane genuinely does not turn, because the lumped wing's rate
servo settles short. That is the heavies' real-wing step (review section 9, step 5). The gym will show it as a
turn-task failure that no amount of planning improves, which is exactly what it should do.

## 8. Questions for the user, each with a recommendation

1. **Build the gym first, before any guidance change?** Recommended: yes. It is GDScript, it lands on its own, it
   turns the jerk you are describing into a number, and it tells us which kinds are worst rather than assuming it is
   the Cessna and the 747.
2. **Should a pilot refuse an impossible plan, or fly the best approximation?** **(ANSWERED by the user's own brief,
   section 3.2: "If the envelope says the climb or the stop is impossible, clip and flag. Do not stall the airframe to
   'try harder.'" -- which is the recommendation below. Treat it as settled.)** A Cessna asked to be at 2,000 ft by a
   point it cannot reach can climb at its best rate and arrive late, or pitch up until it stalls, which is roughly what
   today's saturating loop does. Recommended: **refuse and re-plan** -- take the height later, or slow to the best
   climb speed first -- and count every refusal in the gym's envelope-honesty score, so we can see how often the routes
   ask for the impossible.
3. **How much of the smoothing should a person feel?** The rate limits that stop an autopilot sawing are not what a
   human's hands want: a fighter's stick should stay crisp. Recommended: **the limits live in the AI's tracker, not in
   the controls**, so nothing a person holds is slowed down; a human's stick keeps going straight to the control law.
4. **Is `pid-control/` still wanted as a project?** It is on Godot 4.6.2, its runners point at another machine's paths,
   and nothing depends on it. Recommended: **leave it exactly where it is**, as the lab it was, and take nothing
   further from it. If you want it kept alive, that is a small lane of its own (its engine and its two tool scripts),
   not this work.
5. **Helicopters in the gym from the start?** Their cascade is a different one (`HeliMixer`), and the Little Bird's
   rotor rebuild is already queued. Recommended: **yes, from the start**, with their own tasks -- hover to a point,
   hover taxi, the 500 ft circuit -- because the rotor rebuild will want the same scoreboard.

## 9. The user's own brief, read against the tree

The user handed over `AI_Pilot_Guidance_Brief.md` on 2026-09-19, after the sections above were written. It is a good
document and it agrees with this plan on the diagnosis and on most of the cure: an envelope cached per kind, braking
distance from it, layers instead of one PID on world error, and a vehicle gym as a requirement rather than a nicety.
Below is what is taken, what is adapted, and what is wrong for this codebase -- with the line of code or the
measurement that says so, because the user asked for the good bits and not for obedience.

### 9.1 Taken as written

- **TECS for the aeroplane's energy layer**, and this is the brief's biggest addition to this plan. Throttle tracks
  the total energy rate and pitch tracks the energy BALANCE, so "climb at speed X, and pitch for that speed" is one
  policy instead of two loops fighting over the same elevator. Section 4 above had a speed loop and a height loop and
  was going to hit exactly that fight. `AircraftMixer` already has half of the idea in `climb_share` and
  `climb_angle`; TECS is the whole of it and it is the standard shape. **Adopted.**
- **The envelope's extra terms**: best-angle speed as well as best-rate, an approach speed, and for a rotor the
  translational-lift onset, the hover climb and the hover thrust margin. Section 3's table gains those rows.
- **Reserve turn room as well as braking room**: `R = v^2 / (g tan(bank))`, and begin the deceleration at
  `d_brake + R * heading change`. Section 3 had the braking distance and the level-off lead but not the turn room,
  and the turn is where a heavy loses most of its distance.
- **"If the envelope says it is impossible, clip and FLAG -- do not stall the airframe to try harder."** That is
  question 2 of section 8 answered the same way this plan recommends, by the user's own document, so treat it as
  settled: refuse, re-plan, and count the refusal.
- **Every NEVER in its section 2 that touches the flight model.** No pilot integrator inside `lifting_surfaces.hpp`
  or `rotor_disc.hpp`; no second terrain sampler; no lerp of two models' Loads; no wall clock. All of these are
  already house rules, and this plan was written to them.

### 9.2 Adapted, with the reason

- **"`AircraftMixer` asks for body rates" -- it does not, and the layering is one step shallower than the brief
  draws it.** `autopilot.hpp` line 5: *"a PID outputs the controls a human could hold -- throttle, pitch, roll,
  rudder, brake -- and never a velocity or a force on the hull."* `Levers` is a stick position, not a p/q/r demand.
  The rate demand exists one layer DOWN, inside the model: `fly_on_surfaces` builds `aero::Rates want` from
  `in.pitch * h.pitch_rate`, and takes the law at full strength whenever the pilot is not human
  (`through_law = human ? h.augmentation : 1.0f`, `cockpit_world.cpp:19111`). **This is good news for the plan**:
  the brief's fourth layer already exists and needs nothing built. What the guidance layer feeds is the mixer's
  bugs (height, heading, speed, bank), and the stick-to-rate conversion is the model's, per kind, as it should be.
- **"Plan at 5--10 Hz and HOLD the commands between plan ticks" -- plan far more rarely than that, and make the held
  thing a function rather than a value.** Holding `yaw_rate_cmd` for 200 ms while the aeroplane keeps turning is a
  sample-and-hold inside a control loop, which is the fourth of the six sources of jerk in section 1 and is what the
  carrot does today. And the cost is not free: the rota serves `leg_check` every 3 s and `look_ahead` every 0.5 s
  (`kLegCheckEvery`, `kLookEvery`), so 5--10 Hz is fifteen to thirty times more planning than the pilots do now, at
  1,000 AI, in a lane whose neighbour is cutting that same cost. **The adaptation:** the rota keeps its present rate
  and stores GATES -- geometry, a place, a height, a speed, a distance at which each begins; the tick evaluates the
  setpoint from those gates and the CURRENT state, a few multiplies. That is continuous rather than stepped, so it
  is smoother than the brief's 5--10 Hz, and cheaper than today.
- **"Fill the envelope from published book figures first" -- fill it from the MODEL, and let the book suites check
  the filling.** This is the one place the brief cuts across a rule that has already cost this repo a red suite:
  a number typed beside the model instead of asked of it goes stale the moment the model changes. Merge 851314da
  moved kinds onto new models and three suites went red at once for exactly that, `rotor_hold.gd` among them, which
  held the flown collective against the old weight-fraction thruster's arithmetic on a kind that had moved to a disc
  (fixed this lane, bc4cc7f6; `../agents.md`, "A SUITE THAT KEEPS A FORMULA BESIDE THE MODEL"). Book figures belong
  in the book suites, where their job is to fail when the model drifts from the aeroplane. The envelope is derived.
  The gym's identification pass (the brief's section 7) is then a CHECK on the derivation, not its source.
- **`struct PilotBrain` -- it exists, and it is called `AiPilot`** (`cockpit_world.cpp:10464`): the goal, the mixers
  with their clamped integrators, the steering, the wheels state, the approach, the seed. `NavGoal` is most of the
  way there as `steer_toward` / `steer_altitude` / `steer_speed` / `wheels`. So: extend it, never add a second brain.
- **"Reuse the PID types from `godotgames/`" -- reuse the ones cockpit already has.** `autopilot.hpp`'s `Pid` IS that
  type, ported, with anti-windup and derivative-on-measurement, and since extended. Section 2 above has the detail.
- **"Then delete the per-airframe magic PID tables"** -- only where the gym says a kind no longer needs its own
  number. Several of cockpit's per-kind manners were measured against a symptom the envelope will indeed remove, but
  several others are the airframe (a 200-tonne hull's helm, a rotor's side-step). The gym decides each one, with the
  before-and-after score in the commit.

### 9.3 Does not apply here, or is already true

- **Section 6's second row, rewinding a `PilotBrain` on a predicted client.** There is nothing to do: the rota is
  server-only by construction -- *"The rota is the server's: a client flies no autopilot and serves nothing"*
  (`cockpit_world.cpp:6051`), and every `steer_ai` and `set_ai_manners` entry point returns early unless
  `is_server_`. A client predicts only the vehicle its own hands are on, from recorded `ControlInput`, which is the
  brief's own preferred option. The guidance layer must not break this, and the way it does not is that the tracker
  is a pure function of the cached plan and this tick's state.
- **Determinism from the frame number**: already so. `seconds_now()` is the frame divided by the tick rate
  (`cockpit_world.cpp:16513`), the weather reads that, and the rota's jitter is hashed from (stream, kind, cycle)
  rather than drawn, *"so that a world that is started twice serves the same chores on the same ticks"*
  (`chore_rota.hpp`).
- **"TAS or EAS -- pick one unit and stick to it"**: moot today and worth a note for the day it is not. Cockpit's
  atmosphere has no density with height yet (`flight/air.hpp`: *"The simulation has no density with height yet"*),
  so true and equivalent airspeed are the same number. When density with height lands -- it is section 5 of the
  flight-model review -- the envelope's speeds become equivalent airspeed and its rates true, and the conversion
  belongs in the envelope, once.
- **Section 9, "out of scope, leave for flightcore"**: the brief imagines a separate pilot agent and a separate
  model agent. Here they are one lane, and the ordering in section 7 above already keeps them apart in time -- the
  gym first, then the envelope, then guidance, with the surfaces and rotor work as its own ordered steps.
- **"NEVER treat a slow-cruising kind as cheaper in `rota_probe` without matching cruise speed"**: already the rule
  and already implemented -- `default_cruise` exists *"so two flight models can be priced at the SAME speed"*
  (`cockpit_world.cpp:3914`).

### 9.4 What the brief changes about the order of work

Nothing, except that step 4 of the guidance work is now TECS rather than a pair of loops, and the envelope gains
four rows. The recommendation stands: **the gym first**, because the brief's own section 7 calls it required rather
than optional, and because its identification pass is the thing that will tell us whether a derived envelope and a
flown aeroplane agree.

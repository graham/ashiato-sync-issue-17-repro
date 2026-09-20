# The flight models, reviewed: a model per kind, built from shared blocks, and the order to move them

lane/flightcore, step 0, 2026-09-19. A review and a proposal; no game code has changed. The prototypes that measured
the numbers below are in `flightcore_prototype/` beside this file. Every figure measured here is marked with how.

The user, 2026-09-19: *"we probably want flight models that can be shared between aircraft of the same type (boat,
small plane, large plane, helicopter, vtol, tiltrotor) and then have variables that change how specific planes fly.
Alternatively, we could have custom flight models for each, but have helper functions that are shared between some
types of planes ... look for places where we can dedupe the code and keep it general enough to be powerful ... making
this feel like a good sim (doesn't have to be perfect) is important to me, we should try to model the physics well
too."* And, later the same day: *"Since the little bird had it's physics changed recently can you pay special
attention there, i don't trust the work that was done on that model's flight model."*

Read first: `real_wing_playbook.md` (the method that worked for the Cessna), `flight_model_plan.md` (the surface model's
plan and its decisions), `littlebird_rotor_plan.md`, and `../agents.md`, "The flight model, as found" and "An aeroplane
on its surfaces".

## FIVE AIRFRAMES WEARING ONE PLACEHOLDER, AND NOBODY DECIDED IT

**The fighter, the Tomcat, the Falcon, the Prowler and the Lightning return the same numbers to three decimal
places**: top speed 214 to 216 m/s, climb 7.27 m/s, turn 0.067 to 0.075 rad/s (`tests/vehicle_gym.gd`, 2026-09-19).
Five aeroplanes, one set of behaviour, arrived at by nobody's decision.

**That is not a prediction about what a shared model would do. It is what already happened**, and it is why the
`recipes::` layer this document originally proposed has been removed (section 10, question 1, and the user's own
words there). The rule it is replaced by is one line:

> **The physics lives once, in the block. What repeats per kind is the CHOICE of which forces that aeroplane has.**

A wrong lift curve is fixed in `surfaces.hpp` and every aeroplane gets it. **A warbird's file is a different LIST,
not the same list with different numbers.** The blocks are `inline` in headers, so a kind calling them directly
removes an indirection rather than adding one -- this costs nothing against the 250 ns budget, and it is the reason
the cheap way and the right way are the same way here.

**And the price, which is real and is the correct side of the trade:** a fleet-wide new force means editing every
light single that should have it. A fleet-wide force is rare; a fleet-wide feel is the complaint.

## In one screen

- **Where it stands.** One kind, the Cessna, flies on a real model held to its book (the 172S POH), and it went well.
  One, the Little Bird, is on a new rotor model that is held only to its own formula, and it is wrong where it shows
  most: it climbs at 23 m/s in its own suite and 53 m/s held flat out, against the book's 10.5 (section 7). Every other
  aeroplane flies the lumped wing and rate servo, most on rows scaled by hand from the F/A-18F or from a placeholder;
  the 737 and 747 turn at a third of what their bank buys. Only the Cessna has a flown book check with a mutant.
- **The recommendation, which is also what the user said mid-review:** a flight model **per kind**, a few lines each,
  built from **shared, pure, stateless blocks** (surfaces, propulsion, rotor, vectored thrust, control law, ground
  contact, hull), with the kind's **knobs** read off its drawing and its book. Categories are **families in a table**
  (light single, warbird, glider, heavy jet, fast jet, helicopter, planing boat, ...) that a kind is written FROM --
  never a function it calls, and never a code path. The
  autopilots sit on top unchanged: they ask for rates, and each kind's control law delivers them (section 3).
- **What is duplicated** (section 2): two whole aeroplane models side by side, six copies of one inertia read, three
  keels, three probe schemes, thrust typed five times, 28-number rows scaled from other rows by hand, and every
  handling field typed three times. The blocks replace all of it.
- **The order** (section 9): a fingerprint suite first, so "every other kind unchanged" is a printed fact; then the
  blocks extracted with nothing changing; then **the Little Bird rebuilt on a correct rotor block**, flown against its
  book; then the Cessna moved onto the blocks unchanged; then the fleet a category at a time, light, heavy, fast jet,
  helicopters, the two VTOLs, boats; then the old paths deleted. Each step lands before the next, is priced in a
  MEASUREMENT slot against the +250 ns budget, and waits its C++ turn behind lane/warbirds2.
- **Feel** (section 5): what a person in a headset notices most and costs least comes first: helicopter power and
  translational lift done properly, the heavies' inertia and turns, fly-by-wire on the jets, ground effect in the
  flare, a stall buffet, and the propeller's swing on a warbird's take-off.
- **Questions for the user** are in section 10, each with a recommendation.

## 1. Inventory: every kind with a good model, how it moves today, and against what

"Good model" is a drawn airframe measured off a source, as opposed to a box with parts (the light twin, the pod, the
car). The model column is the code path; "lumped" is `fly_airplane` with the rate servo (`apply_controls`), the path
every aeroplane but the Cessna still flies. "Mass-ratio carry" is `carry_to_mass` or a row scaled by hand from another
kind's. Sources: the kinds' `sources.md`, their airframe classes, `default_handling`, and the suites' own logs.

### Aeroplanes

| Kind | Model today | Its numbers come from | Held to a published figure? | How far off, where measured |
|---|---|---|---|---|
| **Cessna 172S** | **surfaces** (default since lane/cessnafm), fixed-pitch propeller | the drawing (`SkyhawkAirframe`), the 172S POH, component-mass inertia (ESTIMATE) | **Yes**: `cessna_book` (six POH figures) and `surfaces` (the flaps-down stall), each with a mutant | turn 0.99 of textbook; top speed 126 kn against 126; Vy climb 4.5 against 4.3; glide 7.5 against 9; take-off roll 337 m against 219 (the drawn tail, explained); pb/2V 0.087 |
| **Duo Discus** (`glider`) | lumped, `powered` false | lumped numbers typed for a 31 m/s stall and 20:1; the drawing has [SH]'s planform | **No.** `air` holds a typed sink band | flown 16 to 18:1 against the book's 45:1; min sink about 1.05 m/s against 0.58; **the lumped model gains energy at low drag** (lane/sailplane) |
| **Savoia S.21** (film) | lumped + hull + floats + water rudder | typed for fun (the user: *"realism isn't as important with this plane"*); the mass is an ESTIMATE | No | 112 m/s level; skips off the water at 33.9 m/s, under its 40 m/s book stall |
| **737-800** (`airliner`) | lumped | a nine-tonne placeholder's row, carried to 62 t by ratio (lane/liners), never tuned | No: procedure only (bank, rate, stabilised gate) | **autopilot turn 0.34 of textbook**; a 3,350 m radius at 25 degrees |
| **747-400** (`jumbo`) | lumped | the E-6B's row carried to 280 t | No: runway-fit bounds only | **autopilot turn 0.28**: a 3.8 km radius at 25 degrees, against about 1.1 km |
| **C-130H / AC-130U** (`transport`, `gunship`) | lumped | a 20 t row carried to 55 t | No | none recorded |
| **CL-415 water bomber** (`tanker`) | lumped + hull + floats | typed around its 45 m/s drop run; hull loft by eye (the user ruled the maker's sheet out) | No (the 12 s scoop is "the real machine's number") | lifts off the water at 43.5 m/s; turn 0.54 |
| **E-2D Hawkeye** | lumped, stated inertia | typed from Jane's figures kept outside the repo (drafts); stall 75 kt landing, 350 kn max, "3.06 for 140 m/s" by choice | No | turn 0.63; flies 140 m/s against 180 published, by choice (the speed order) |
| **F/A-18F** (`fighter`) | lumped, stated inertia | typed; the lift slope is 82 per radian against a real wing's 3.5 to 5 | No (only the 25 ft/s carrier sink) | top speed 221 m/s, sized by the world's edge, not the book; flown stall about 20 m/s where a real one is about 67 |
| **F-16A** (`falcon`) | lumped | the F/A-18F's row scaled by hand (mass 0.546, inertia 0.465), then quickened | No: ratios to the F/A-18F | 220 m/s; 171 deg/s roll; 9.4 g |
| **F-14D** (`tomcat`), **EA-6B** (`prowler`) | lumped, stated inertia (the F-14's from an NPS thesis) | the F/A-18F's row scaled by hand; the Prowler shares the Tomcat's case | No | the sweep changes nothing in flight (the user's ruling) |
| **A-10C** (`warthog`) | lumped | the F/A-18F's row scaled by hand, then set to its published thrust, top speed, stall and g | **Partly**: top speed 381 kt flown (198.0 m/s, within 1 per cent); the 120 kt stall is **the table's**, not flown | roll 91 deg/s against "about 90" |
| **F-35B** (`lightning`) | tiltrotor: the lumped wing plus a swinging thrust, weight-fraction hover | the F-16's row carried to 17.5 t; the LiftSystem's 186 kN | No (typed VTOL bands) | hover margin 1.08 g, the book's |
| **MV-22B** (`osprey`) | tiltrotor: lumped wing + weight-fraction rotor | typed (stall "about 57", cruise "140", unsourced) | No | none recorded |
| P-51D, P-47D, P-38L, B-17G | **no kind yet** (lane/warbirds2 is making them fly now, with a taildragger ground model) | drawn from AN sheets and NACA reports; the P-51's top speed and stall are in its `sources.md` | — | — |

### Rotorcraft

| Kind | Model today | Its numbers come from | Held to a published figure? | How far off |
|---|---|---|---|---|
| **MH-6M Little Bird** | **rotor disc** (default since 2026-09-19) | MD 530F sheet figures; the disc is a weight-fraction thruster with multipliers | A probe of the formula, never a flight (section 7) | **climb 23.3 m/s flown, 53 m/s steady in the prototype, against 10.5**; autorotation ignores airspeed; a cliff at the bottom of the lever |
| Light helicopter (`heli`, Huey-like) | thruster (`fly_helicopter`) | fictional 900 kg | No | — |
| **UH-60M** | thruster | FM 3-04 size and gross weight; handling typed | No | — |
| **AH-64D Apache** | thruster | the UH-60's row by mass, climb held by vertical drag (130) | Typed bands round [W] figures | climb 16.3 m/s against 9.0 published |
| **CH-47F Chinook** | thruster, authority and damping from NASA/ERF data | handling tuned to ADS-33E rates | Rate floors only | — |

### Water

| Kind | Model today | Its numbers come from | Held to a published figure? | Measured |
|---|---|---|---|---|
| **RIB launch** (`boat`), **patrol boat** (`gunboat`), **CB90** | four-probe hull, keel, stern rudder, bow wave, planing lift, lean and bow rise | tuned for fun ("more juice", "lean into their turns"); CB90 size and mass from [W] | No speed or turn figure | 25.1, 24.0, 24.0 m/s; circles 60, 102, 81 m; leans 13.1, 9.0, 8.6 degrees |
| **Ford carrier**, **Iowa battleship**, **Virginia submarine** | four-probe hull (the long-hull swell rule) | shapes from fact sheets; masses a tenth of real (a stated choice) | Draught only | carrier 15.2 m/s, 477 m circle |
| **Brig** (`pirate`) | six-probe hull, sails as wings, keel lift | typed; HMS Beagle's draught | 6 to 9 kt on a beam reach ("the brief") | as held |

**The short version.** One kind (the Cessna) is on a real model held to its book. One (the Little Bird) is on a new
model held only to its own formula, and it is wrong in the climb. Every other aeroplane is on the lumped wing, most of
them with rows scaled by hand from the F/A-18F or a placeholder, and the three biggest turn at 0.28 to 0.54 of what
their bank buys. No helicopter but the Little Bird has any physics of a rotor. No boat is held to a speed or a turn.


## 2. Duplication: what is copied, and what one block would replace

Line numbers are `ashiato-gd/src/cockpit/cockpit_world.cpp` at 5bde7c4e unless a file is named. They drift; search
for the names.

### The model code

| # | What is copied | Where | What one block would replace it with |
|---|---|---|---|
| D1 | **Two whole flight models kept side by side.** `fly_airplane` (the lumped wing and the rate servo) and `fly_on_surfaces`, which re-types the lumped wing's hanging drag, its thrust and its taxi branch | `fly_airplane` 18984-19080; `fly_on_surfaces` 19098-19162; the hanging drag is the same expression at 19007-19013 and 19143-19150 | The surfaces for every aeroplane, and the lumped path deleted (the plan's own rule: *"two models kept in step is the trap"*). Until then, `hanging_drag(h, levers, wing)` once |
| D2 | **"The inertia about this axis"**, a world inverse-inertia read and `a . (I^-1 a)`, typed six times | 19119, 19186, 20186, 20402, 20694, 20753 | `inertia_about(body, axis)`: one helper, and one read per tick handed to every block that needs it (the surfaces' law, the nosewheel, the water rudder, `hold_the_turn`, `command_rate`) |
| D3 | **A yaw rate commanded through the body's own inertia**, `gain = grip x I x (1/settle + angular_damping)`: the nosewheel and the water rudder are the same controller with different names | `steer_on_the_ground` 19180-19200; `steer_on_the_water` 20177-20193 | `steer_by_rate(body, rate, grip, settle)`: a nosewheel, a tailwheel, a water rudder and a skid are each one call with their own grip and settle |
| D4 | **The keel**, a side force linear in slip, capped | `sail_boat` 20271-20277; `alight` 20141-20147; `sail_ship` 20408-20412 (with a lift-from-leeway term) | `hull::keel(slip, way, water_drag, keel_lift, limit)` |
| D5 | **Wave-making resistance**, `over^2 x wave_drag` past a hull speed | `sail_boat` 20283-20288; `sail_ship` 20414-20420 | `hull::bow_wave(along, hull_speed, wave_drag)` |
| D6 | **A rudder at the stern**, `-steer x v|v| x rudder_force` at `rudder_arm` | `sail_boat` 20310-20314 (plus its drag, 20317-20323); `sail_ship` 20425-20429 | `hull::stern_rudder` |
| D7 | **Float probes**: sample the sea where the point is, push up by depth, damp at the point. Three variants | `float_the_hull` 19953-20002 (four probes); `sail_ship` 20365-20391 (six, placed by the metacentre); `float_the_wingtips` 20023-20045 (two floats) | `hull::probe(point, sea, depth cap, stiffness, damping)`, and a hull is a list of probes. The six-probe rule (spread from the metacentric height) is the better one and could place every hull's probes |
| D8 | **The probes' reach**, `(afloat_hz > 0 ? afloat_hz : hz) x 0.75` | 19799, 19973-19974, 20230-20231 | computed once per shape, at load |
| D9 | **Thrust as `throttle x thrust` along the nose** | `fly_airplane` 19067, `fly_tiltrotor` 19578, `drive_car` 19713, `sail_boat` 20307, `hover_pod` 20561 | a propulsion block per kind: a jet, a fixed-pitch propeller (the Cessna's `aero::thrust_at`), a constant-speed propeller, a rotor, a waterjet, a car's drive |
| D10 | **A rotor's thrust as a share of the weight**, `m g (hover + lever x collective_range)` | old helicopter 19634-19637; `fly_tiltrotor` 19579-19580; `rotor::fly` (`rotor_disc.hpp` 240) | one rotor disc, used by every helicopter and by the tiltrotor's nacelles (see section 7 first: the disc is not yet right) |
| D11 | **The rate servo's three axes**, retyped with a different bite | `apply_controls` 20609-20622; `fly_tiltrotor` 19588-19597 | `apply_controls(body, h, in, f, bite, coordinate)` already takes both; the tiltrotor can call it |
| D12 | **Translational lift's fade, 8 to 16 m/s, typed twice** | `kRotorTurnFrom`/`kRotorTurnFull` 19616-19617; `rotor::fly`'s `(along - 8) / 8` (`rotor_disc.hpp` 229) and `classify`'s 5 and 16 (203-208) | one number: the disc's own induced velocity says where translational lift is (it is where the forward speed passes about vh) |
| D13 | **Constants three times**: sea-level density and g | `aero::kSeaLevelDensity` (`lifting_surfaces.hpp` 44), `rotor::kSeaLevelDensity` (`rotor_disc.hpp` 26), `kAirDensity` 20327; `9.81f` typed 27 times in `cockpit_world.cpp` | `atmosphere.hpp`: g, rho at sea level, and rho(h) when density with height arrives |
| D14 | **`clampf` three times** | `cockpit_world.cpp` 5469, `rotor::clampf`, `ai::clamp` | one |
| D15 | **Level-flight drag, typed twice** | `sustained_climb` 17150-17153; `idle_sink` 17168-17173 | `level_drag(index, speed)` |
| D16 | **The flat-out speed, typed three times** | `flat_out` 16210-16220; `cruise_over` 17244; `default_cruise` 17254 | `flat_out(index)`, which already exists and knows the propeller |
| D17 | **The book stall's formula, twice** | `flying_speed` 5324 (x 1.15) and `stall_speed` 17184-17186 | one |

### The data

| # | What is copied | Where | What would replace it |
|---|---|---|---|
| D18 | **A kind's air "scaled by the mass ratio" BY HAND**: the Tomcat/Prowler (x 23.6/22 and x 315,600/210,000), the Falcon (x 0.546 and x 0.465, then retuned), the F-35B (x 1.456 of the Falcon), the A-10 (x 0.677 and x 0.523), each with the scaled numbers typed and the arithmetic in the comment | `default_handling` 4203-4367 | A **preset** and a scale: `carry_to_mass` (4093) already does it for four kinds and is exact. A kind that says "the fighter's air at my mass" should be one line, and today it is 28 typed numbers that drift the moment the fighter's are retuned |
| D19 | The same for helicopters and boats: the Little Bird is "the light helicopter's by the mass ratio", the Apache "the UH-60's at 7,270 / 9,979", the CB90 "the patrol boat's by 15.3 / 14" | 4813-4862, 5130-5164 | the same |
| D20 | **Every `Handling` field three times**: declared, read in `set_handling` (90 `dict_get` lines, 9347-9472) and written in `handling()` (9580-9693). A field missed in one is a `--set` that silently does nothing, which the file itself warns of | 3783-4086, 9347, 9580 | an X-macro list of fields, as `cockpit_kinds.inc` did for kinds (lane/kinds): one row per field |
| D21 | **The rotor disc's numbers are a function, not data.** `rotor::littlebird()` hard-codes the one kind, `disc_of` is `kind == kKindLittleBird`, and generic code carries Little Bird numbers: tip speed 210 m/s (`power_required`), the hub's 2.75 m in `classify`, the 8-16 m/s of translational lift, the 18 per cent lift bonus, the 1.2 vh of autorotation | `rotor_disc.hpp` 135, 204, 229, 242, 175; `disc_of` 17194; `build_the_disc` 17202 | a `Disc` read from the kind (radius, blades and chord or solidity, tip speed, power, hub height), like `planform_of` |
| D22 | **`planform_of` has four surfaces built in**: two wing panels, one tailplane, one fin. A twin fin (F/A-18, F-14, Prowler, B-17 has one, P-38 has two), a stabilator that rolls (F-14, F-16), a delta with no tail (none yet), a canard, a T-tail's position and a twin boom cannot be described | `lifting_surfaces.hpp` 379-479 | a list of surfaces from the planform, each a panel with its own place, normal, area and control mix; the builder helpers keep today's four as the default |

### What is NOT duplication, and should stay one-off

- `sail_ship` and `Rig`: one brig; its sails are wings on their ends and could use the surfaces' `coefficients` one
  day, but there is one ship under sail and no second to share with.
- `ride_segway`, `hover_pod`, `run_on_rails`: each is the only one of its kind, and small.
- `drive_car`'s bicycle model: cars and the tank share it already, which is the right shape.
- The autopilot mixers (`autopilot.hpp`): one per way of moving, already shared by every kind of that way, and tuned on
  the rate interface. They stay, above the blocks (section 3).


## 3. The architecture: a flight model per kind, built from shared blocks, with knobs

The user, mid-review: *"I feel better about a specific flight model per KIND but have lots of shared functionality so
that building them is easy. but custom per kind with knobs."* That is the recommendation here, and the code supports
it: the Cessna's surface model is already a kind-specific assembly (`planform_of`'s case) of generic pieces
(`lifting_surfaces.hpp`), and it is the one model that works.

### The rule

- **Every kind has its own flight model**: a short, pure function in its own file, `flight/kinds/<kind>.hpp`, that
  says which forces this aircraft has and calls the shared blocks to make them. Most are five to fifteen lines.
- **The blocks are shared, pure and stateless**: they know physics, not kinds. They are where nearly all the code is.
- **The knobs are the kind's own data**: its drawing's numbers and its book's, in one struct beside its model, each
  with its source or ESTIMATE, as `planform_of` has them now.
- **A CATEGORY IS A FAMILY, NOT A FUNCTION. There is no recipe in the call path.** The user, 2026-09-19: *"I still
  think that having a different flight model for each plane is good and we have lots of common functions to take care
  of physics correctly (inlined). That way they all don't just feel like copies with knobs turned (and we can tweak
  them more)."* A kind's `fly()` calls the BLOCKS directly, as its own short list of the forces that aeroplane has. Two light singles look alike because they call alike, not because they call the same wrapper -- and
  either can gain a force, lose one or reorder them without touching the other. **The blocks are `inline` in headers,
  so calling them directly costs nothing at runtime; it removes an indirection rather than adding one.**
- **The movement model (`Model`) stays**, and keeps meaning what it means now: which autopilot mixer flies it, which
  ground and water rules apply, what the world treats it as. It stops meaning "which physics function".

Rejected: **one model per category with variables** (the user's first option). The kinds do not divide cleanly: the
F-35B is a jet, a VTOL and (in this code) a tiltrotor; the CL-415 is a heavy, an amphibian and a propeller aeroplane; the
AC-130 is a transport with guns; the P-38 has twin booms and two fins. A category model would grow a flag for each,
which is the lumped wing again, "wrong for everything and tunable into being wrong for everything" (`../agents.md`,
the tiltrotor). Also rejected: **one model per kind with nothing shared**. It is 30 kinds of copied surfaces and rotors,
and today's duplication (section 2) is what that looks like after a year.

### The blocks

```
ashiato-gd/src/cockpit/flight/
  air.hpp           g, sea-level density, rho(h) when wanted; BodyAir: the airflow and spin in body axes, height over
                    what is under, rho, dynamic pressure -- built once from the Frame, handed to every block
  loads.hpp         Loads: one force and one torque about the centre of gravity, body axes; add_at(point, force);
                    and the ONE place they become Box3D calls (`apply(body, frame, loads)`)
  surfaces.hpp      today's lifting_surfaces.hpp, generalised: N panels, each with a place, normal, area, slope, stall,
                    control mix; builders for a wing pair, a tailplane, a stabilator that also rolls, one fin or two
                    canted, a T-tail, a twin boom; ground effect on the wing (a factor under one span)
  propulsion.hpp    fixed-pitch propeller (the Cessna's thrust_at), constant-speed propeller (power over speed, capped
                    at static thrust), turbofan/turbojet (thrust with a speed and density lapse), reverse thrust; the
                    propeller's extras: P-factor, torque reaction, slipstream over the tail
  rotor.hpp         the rotor disc rebuilt (section 7): blade-element momentum, power with the climb in it, autorotation
                    as zero engine power, ground effect under the disc; a tail rotor (thrust and its power share); two
                    discs in tandem or side by side (the Chinook, the Osprey)
  vectored.hpp      a thrust vector swung by a channel (today's thrust_along), for the F-35B's nozzle and the Osprey's
                    nacelles; a lift fan and roll posts where the kind has them
  control.hpp       the control law (dynamic inversion, clamped to full travel, today's), augmentation 0..1 (cables to
                    fly-by-wire), the g limit, an alpha limit, the coordinated turn; and the old rate servo
                    (command_rate) for the kinds not yet moved, and for pods and the segway
  ground.hpp        contact points: a wheel with a leg's spring and damper, a castoring or steered tailwheel, a
                    nosewheel, brakes, a skid (lane/warbirds2 is building the wheel-at-the-wheel model: it becomes this)
  hull.hpp          probes (the six-probe placement from the metacentre, D7), keel, bow wave, stern rudder, water rudder,
                    planing lift, lean and bow rise, wingtip floats, porpoising when wanted
  kinds/<kind>.hpp  each kind: its knobs struct and its model, calling the blocks directly
  (no recipes.hpp)  the families in section 4 are a TABLE IN THIS DOCUMENT and a set of default numbers to start a
                    kind from -- never a function a kind calls. A new light single is written by copying the
                    Cessna's dozen lines and editing them, which is the point: it can then diverge.
```

A kind's model, for the Cessna as it is today plus the extras section 5 recommends:

```cpp
/// THE CESSNA 172S: a light single on its surfaces, a fixed-pitch propeller, and the propeller's swing.
inline void fly(const Cessna& k, const BodyAir& air, const Controls& c, Loads& out) {
    surfaces::evaluate(k.wing, air, c, out);            // wing, tailplane, fin, and the stick through their travel
    surfaces::ground_effect(k.wing, air, out);          // the cushion in the flare
    surfaces::buffet(k.wing, air, out);                 // the shake before the break
    propulsion::fixed_pitch(k.prop, air, c, out);       // thrust from the disc
    propulsion::propeller_swing(k.prop, air, c, out);   // P-factor, torque, slipstream over the tail
    ground::tricycle(k.gear, air, c, out);              // three wheels, where they are
}
```

And the Osprey, whose conversion is its own:

```cpp
inline void fly(const Osprey& k, const BodyAir& air, const Controls& c, Loads& out) {
    surfaces::evaluate(k.wing, air, c, out);                  // the wing and tail, always on
    const float tilt = c.tilt;                                // the nacelles, from the bus
    for (const auto& side : k.nacelles) {
        rotor::fly(side.disc, air.at(side.hub, tilt), c.collective_for(side, tilt), out);
    }
    control::conversion_mix(k.mix, tilt, c, out);             // cyclic and differential collective at the hover,
                                                              // the surfaces as the nacelles come down
}
```

`drive_vehicle` keeps everything it does now before the model (the frame, drag against the body, the autopilot, the
lever, the edge, the undercarriage) and its switch becomes, for a kind that has moved, `fly_kind(index, air, controls,
loads)` then `loads::apply`. A kind that has not moved runs exactly the code it runs now. The table of which kinds have
moved is one row per kind in `cockpit_kinds.inc` (a column naming the model function, empty for "not yet").

### Prototyped: the surfaces as a list of panels (`panel_wing.hpp`, `surfaces_fleet.cpp`, `results_surfaces.txt`)

The surfaces block is the one that has to grow most, because today's `Planform` is one wing, one tailplane and one fin,
filled into four surfaces in a fixed order. The prototype opens that into a **list of panels**, each with its own
place, normal, area, aspect ratio, incidence and controls, and derives the rest from the list: the lift slopes, the
downwash on anything behind the wing, the neutral point, the centre of gravity and the incidence that trims it.

**The Cessna is the regression, and it passes exactly.** The same numbers through the game's `build_wing` and through
the panel list give the same four panels to the centimetre and the same derived quantities: the centre of gravity
2.4720 m aft of the nose both ways, the tail's incidence +0.2353 degrees both ways, the clean stall 26.112 m/s both
ways. A generalisation that moved the one aeroplane already flying on it would not be one.

| | panels | what it needs that the Cessna does not | measured |
|---|---|---|---|
| **F/A-18F** | 6: wing pair, **stabilators that roll**, **two fins canted 20 degrees** | a control on a channel it is not "for" (the tailplane answering roll), and a fin whose normal is tilted | the rolling stabilator is worth **156 deg/s of roll at 150 m/s against 127 without it**; the cant turns some of the rudder's yaw into roll (−243 kN m of yaw and −122 of roll, against −258 and −102 upright) |
| **P-38L** | 6: wing pair, tailplane pair **between the booms**, **two fins 2.438 m out** | an end-plated tailplane | the booms' fins raise the tailplane's lift slope **6 per cent** (4.59 against 4.32) |
| Cessna | 4 | — | unchanged, to four decimal places |

**What a twin boom needs, and what it does not.** The finding worth keeping is a negative one, measured rather than
assumed: **the booms' offset changes nothing about how it flies.** Moving the P-38's two fins onto the centreline,
leaving everything else alone, gives the same rudder authority to the kilonewton-metre (−129 kN m of yaw and −13 of
roll either way), because a side force at an arm out to the SIDE makes neither yaw nor roll; only its arm aft and its
height above the centre of gravity do. So a twin boom needs two things in the surfaces — a tailplane that knows it is
end-plated, and fins at their own height — and everything else it needs is in the other blocks:

- **propulsion**: two engines off the centreline (asymmetric thrust with one out), and the P-38's counter-rotating
  propellers, which cancel the torque and the P-factor a single-engine warbird swings on (the `propeller_swing` block,
  section 5);
- **ground contact**: a 5.03 m track with the main wheels in the booms (lane/warbirds2's block);
- **inertia**: the booms' and the engines' mass out along the span, which no box and no "wing share of the span" rule
  will give — it wants a component estimate, as the Cessna's did.

**Cost**: 75 ns an evaluation for the Cessna's four panels and 107 for six, against the plan's measured 70 to 113 ns
for four surfaces and the control law. Six panels are what the F/A-18F and the P-38 need; the game's `kMostSurfaces`
is 6 today and would go to 8, which costs two more slots in a table built once at load.

**A trap paid for here:** a stabilator's roll sign is the AILERON's, not the elevator's. Written the natural way round
(the right half positive for a right roll) it fought the ailerons and cost the aeroplane roll: 98 deg/s against the 127
the ailerons gave on their own. It is in the block's doc block now.

### Prototyped: the propeller and its swing (`propeller.hpp`, `propeller_fleet.cpp`, `results_propeller.txt`)

The last block on the critical path, and the one nothing in the game has any of: an aeroplane's thrust is
`throttle x thrust` along the nose, the same at every speed and every angle, with no moment of any kind. A big
propeller in front of a light aeroplane makes three, and together they are what a taildragger's take-off is:

- **torque**, the equal and opposite of what turns the blades, which rolls it;
- **P-factor**, the thrust's centre moving toward the descending blade when the disc meets the air at an angle, which
  yaws it;
- **slipstream**, the air the disc has already worked on arriving at the tail faster and turning, which yaws it again
  and gives the fin authority at a standstill.

A counter-rotating pair cancels all three, and one handedness per engine is all that takes.

**Measured at full power with the tail still down (12 degrees at the disc), as a share of what full rudder can hold:**

| | standstill | 10 m/s | 30 m/s | 60 m/s | torque, and what it would roll |
|---|---|---|---|---|---|
| Cessna 172S, 180 hp | 28% | 23% | 20% | 10% | 533 N m, 0.11 rad/s^2 |
| **P-51D, 1,490 hp** | **28%** | **23%** | **22%** | **14%** | **7,383 N m, 0.35 rad/s^2** |
| P-38L, two engines counter-rotating | 0% | 0% | 0% | 0% | 7,595 N m an engine, cancelled by the pair |

**What the numbers say.** A Mustang needs a quarter to a third of its rudder to keep straight at the start of its
take-off roll, falling to a seventh by 60 m/s, which is the shape every pilot's account of it has. The trainer's is
the same shape and a twentieth of the size in absolute terms (1.1 kN m against 5.8). The P-38 has none of it, and
instead has the twin's own problem: **one engine out at 60 m/s is 35.8 kN m of yaw against 46.4 kN m of full rudder,
77 per cent** — which is where a minimum control speed comes from, and why it is worth having.

**Two details worth keeping.** The thrust is momentum theory for a CONSTANT-SPEED propeller (a warbird, a transport)
and stays the game's line through two book points for a FIXED-PITCH one (the Cessna's): a fixed-pitch propeller at a
standstill is far off its design point and momentum theory overstates it by half again (3,181 N against the 2,495 N
the Cessna's book fits). And every fin here sits behind a disc, the P-38's two behind their booms' engines, so all
three have a rudder before they are rolling: 44 kN m on the P-38 at a standstill, where its airspeed alone would give
it nothing.

**Cost**: 82 ns for a propeller and its three moments, against the budget's +250 ns an aircraft.

**What a take-off suite could hold** (for lane/warbirds2, whose P-factor is parked as a todo):
1. **It swings, and the right way.** Full power from a standstill, feet off: the heading goes LEFT for a clockwise
   propeller. Mutant: handedness or P-factor zero, and it must not.
2. **A rudder holds it.** The same roll with a robot's feet: the heading stays within a stated band to lift-off, and
   the rudder never needs more than about 40 per cent, which leaves a margin for a crosswind.
3. **The swing falls away as it accelerates**: the share of rudder needed at 10 m/s is greater than at 45 (a ratio
   between two moments of the same run, not an absolute).
4. **Torque rolls it when the wheels stop holding it**: just off the ground, hands off, it rolls left within a second.
5. **The P-38 does not swing**: the same take-off holds its heading within a degree or two. Mutant: both engines the
   same handedness, and it must swing.
6. **One engine out has a speed below which the rudder loses**: at 60 m/s full rudder holds it; slower, it does not.

### What stays custom, in the kind's own file

- **The Osprey's conversion**: two discs on nacelles swinging on the bus, cyclic and differential collective at the
  hover handing over to the surfaces as they come down, and the conversion corridor. The wing and the discs are blocks.
- **The F-14's sweep**: its wing panels' place, area and slope move with `Sim.Channel.SWEEP`. The user has said it
  need not fly differently yet; with panels as data it is a function of the sweep channel, when wanted.
- **The F-35B**: the nozzle and lift fan balanced about the centre of gravity, the roll posts' control at the hover.
- **The flying boats**: the hull's water loads (`hull.hpp`) are added in the kind's model after the air's, as `alight`
  is now.
- **Carrier traps and catapults**: not a flight model at all but a deck's force on a hook or a shuttle; they belong
  with the deck (`deck_under`), and every jet's model is unchanged by them.

### The autopilot and the AI sit on top, unchanged

Every AI aircraft is flown by `AircraftMixer`, `HeliMixer`, `BoatMixer` or `SailMixer` (`autopilot.hpp`), and they
speak one interface: levers, where the stick is a **rate asked for**. Lane/cessnafm proved that interface survives a
real model: the control law inverts through the surfaces' own moments and the unedited mixer turned at 0.99. So:
- **An autopilot always flies through the kind's control law** (augmentation 1), whatever the kind gives a human.
- **A rotor kind gets the same**: the cyclic and pedals as hub moments and tail-rotor thrust, with a law that asks
  them for the rate the HeliMixer wants.
- What the mixers read from a kind (the stall, the cruise, the climb budget, the idle sink, Vy, the flat-out speed)
  comes from the kind's model through one set of questions (`stall_speed`, `sustained_climb`, `idle_sink`,
  `flat_out`), asked of the model and not of `Handling`, so a new kind needs nothing typed for its autopilot. Today
  they already ask the surfaces for the Cessna; the change is that every kind answers them.
- The traps lane/cessnafm paid for travel with every kind: the climb budget at Vy, `max_descent_rate` inside the idle
  sink, circuits and approaches sized on the full turn, the take-off asking for enough rate to saturate the elevator.

### Determinism and rollback

- **No new state.** Every block is a function of the rolled-back `VehicleState`, this tick's input and the bus. The
  surfaces have no position, the law no integrator, the rotor no RPM. Things that would need state are named and
  deferred: rotor RPM (a flare that stores energy), engine spool-up, actuator lag. Each would be a field in the
  replicated state with a cost on the wire, and each is a question for the user when it is wanted.
- **Fixed order.** A kind's model adds its loads in a fixed order into one `Loads`, handed to Box3D as one force and
  one torque, as `fly_on_surfaces` does now. Floats throughout, as Box3D is on both builds; the double build changes
  Godot's `real_t`, not this arithmetic.
- **Every force is resimulated where it is today**: the server runs each craft once a tick and never resimulates; a
  client resimulates only the craft it flies (`predicts`). Nothing about that changes.
- **The known risk is unchanged**: a Linux peer compiled with FMA contraction can differ in the last bit. It costs a
  correction, not a desync, because the server is the authority.
- **Moving a kind changes it, by design; moving the code must not.** The extraction step (section 9, step 1) keeps
  every expression's order, and a fingerprint suite proves it: every kind flown for ten seconds on a script through
  the real input path, its final state printed bit for bit, identical before and after.

### Performance

The budget stays the plan's: **+250 ns an aircraft a tick** over today's, measured in the game in a MEASUREMENT slot,
bracketed, at the same speed as the model it replaces (the playbook's trap).
- Measured: the Cessna's surfaces, **+57 ns of forces, +26 ns of tick** at 1,000 autopilot Cessnas.
- Measured here, prototype, the disc as it is: **112 ns a call** (`flightcore_prototype/rotor_cost.exe`, median of
  five; another lane's MEASUREMENT slot was up, so this is an upper bound and is re-measured on a quiet machine before
  any decision rests on it). Fourteen bisection steps of six inflow iterations each are most of it; the rebuilt disc
  solves the inflow once and clips power once, and should cost less.
- The blocks themselves change nothing in cost: they are the same arithmetic in named functions, inlined.
- Extras are a multiply or two each (ground effect, density, P-factor, slipstream).
- A heavy with four propellers or two discs is two to four times one; still inside the budget, and priced when it
  moves.


## 4. The families that make sense, as a table and not as code

**These are families, not functions.** A family earns a row when the FORCES are different, not when the numbers are,
and the row says which blocks a kind of that sort calls and what its defaults are -- it is where you look when you
write a new kind, and nothing calls it. Twelve families cover every drawn kind:

| Family | What it has that the others do not | Kinds written from it |
|---|---|---|
| `light_single` | a straight wing, a tail, a fixed-pitch propeller; raw controls; tricycle wheels | Cessna |
| `warbird` | `light_single` with a constant-speed propeller of big power, so torque, P-factor and slipstream are strong; a taildragger's wheels | P-51, P-47 (warbirds2); the Savoia's air (a racer, raw) |
| `light_twin` | two propellers, so asymmetric thrust on an engine failure; tricycle | the light twin (no drawing yet), P-38 (twin boom, two fins) |
| `glider` | no engine, a long wing (the inertia rule's 0.30 wing share), airbrakes, a skid | Duo Discus |
| `heavy_turboprop` | four or two constant-speed propellers, big inertia, a yaw damper (augmentation 0.5) | C-130s, Hawkeye, CL-415 (plus `hull`), B-17 (a taildragger) |
| `heavy_jet` | swept wing, turbofans with lapse, spoilers, reversers, augmentation 0.5, slow roll | 737, 747 |
| `fast_jet` | fly-by-wire (augmentation 1), g and alpha limits, stabilators that roll, twin canted fins where drawn, afterburning turbofans, a game-sized CLmax until the carrier has wires (the plan's decision C) | F/A-18F, F-16, F-35B's wing |
| `attack_jet` | cables, not fly-by-wire; a straight thick wing; decelerons | A-10, EA-6B, F-14 (hydromechanical with a SAS, 0.7) |
| `helicopter` | one disc and a tail rotor, a rate-command SAS for the hands | Little Bird, light helicopter, UH-60, Apache |
| `tandem_helicopter` | two discs, yaw by differential cyclic, pitch by differential collective | Chinook |
| `planing_boat` | probes, planing lift, lean, bow rise, a stern rudder or waterjets | launch, patrol boat, CB90 |
| `ship` | probes on the long-hull swell, keel, bow wave, stern rudder | carrier, battleship, submarine; the brig adds its rig |

Tiltrotors and VTOL jets get no family row: there are three of them now and they share nothing but the blocks. Their
own files assemble a wing (`surfaces`), discs or a nozzle (`rotor`, `vectored`) and a conversion (their own) -- which
is what every kind's file does, so they are not a special case so much as the general one made obvious.

**THE PRICE, STATED PLAINLY, because it is real.** With no recipe in the call path, giving every light single a new
force means editing every light single. That is the cost of their not being copies, and it is paid in the one place it
is cheap: **the physics still lives once, in the block** -- a wrong lift curve is fixed in `surfaces.hpp` and every
kind gets it. What is repeated per kind is only the CHOICE of which forces that aeroplane has, which is exactly the
thing that must be allowed to differ. A fleet-wide force is a rare event; a fleet-wide feel is the complaint.

## 5. Feel: what makes each category feel right, what it costs, and what a person in a headset notices

"Notices" is judged for a person flying by hand in VR, where the horizon, the nose and the controls are in front of
them. Cost is in the simulation. The ones marked **built** exist on the Cessna today.

| Category | What makes it feel right | Cost | Noticed in VR | Built? |
|---|---|---|---|---|
| **All wings** | the stall breaks, and one wing drops | free with surfaces | **High**: "it never stalls" is the first thing a pilot notices | built (Cessna) |
| | the controls go soft as it slows, firm as it speeds up | free with surfaces | **High** | built |
| | adverse yaw, and the rudder mattering | free with surfaces | Medium | built |
| | the trim wheel is a speed | free with surfaces | Medium | built |
| | ground effect: the float in the flare | one factor under a span | **High**: the landing is the moment of most attention | no |
| | stall buffet: a shake before the break | display only (camera and sound from alpha) | **High** in a headset; zero simulation cost | no |
| | density with height | one multiply | Low under 1,500 m, which is where this game flies | no |
| **Propellers** | P-factor and torque: a swing on the take-off roll the feet must catch | a few multiplies | **High** on a warbird, medium on a Cessna | no |
| | slipstream over the tail: rudder at taxi speed with power on | a few multiplies | Medium | no |
| | a windmilling propeller's drag at idle | built | Medium (the glide) | built |
| **Taildraggers** | tail-down, the nose blocking the view, a tailwheel to steer, a ground loop to catch | the ground block | **High** | warbirds2 is building it |
| **Heavies** | inertia: a roll that takes its time to start and to stop; a turn that is pulled | free with real inertia and surfaces | **High**: today the 737 and the Hawkeye roll into their approach turns at up to 37 degrees a second (lane/smoothturn) | no |
| | engine spool-up: thrust arriving seconds after the lever | needs state on the wire | Medium | no (a question) |
| | a yaw damper and trim | augmentation 0.5 | Low (it is what hides the rest) | the law exists |
| **Jets** | fly-by-wire: crisp rate, a g and an alpha limit that stop the pilot | the law at 1, built | **High**: it is the jet's character | law built, no jet on it |
| | energy: a hard turn bleeds speed, the afterburner gives it back | induced drag, built; thrust lapse | Medium | partly |
| | an approach on alpha, nose high, to a carrier | the surfaces' real alpha | **High** at the carrier | no |
| **Helicopters** | power: a climb that stops when the engine is out of power | the rebuilt disc | **High**: the Little Bird climbs at 23 today | **wrong** (section 7) |
| | translational lift: the shudder and the surge through 15 to 25 kt | falls out of the inflow; a shake is display only | **High** | typed (section 7) |
| | ground effect and a cushion on landing | built (form right, reference wrong) | **High** | partly |
| | torque: the nose swings with the collective, the pedals catch it | a moment with the power | **High** to a helicopter pilot; can be hidden by the yaw SAS | no |
| | vortex ring: a fast vertical descent that will not stop | built (typed envelope) | Medium | built |
| | autorotation and a flare | the rebuilt disc; the flare needs rotor RPM (state) | Medium; rare | **wrong** (section 7) |
| | a hover that takes attention | the SAS strength | **High**; the user decides how hard | the rate servo |
| **Tiltrotor** | the conversion corridor, the wing taking over | the Osprey's own file | High for the Osprey pilot | blend exists |
| **VTOL jet** | the thin thrust margin, the nozzle's balance, roll posts | the F-35B's own file | High | the margin is right |
| **Boats** | the hump, then onto the plane | built (bow rise, planing lift) | **High** | built |
| | porpoising at a wrong trim | a pitch moment from speed and trim; free-ish | Medium | no |
| | slamming into a sea | built (probes on the wind-sea) | **High** | built |
| | lean into a turn | built | High | built |

**Recommended, in priority order** (what each kind gets as it moves, and the extras that come first):
1. **The Little Bird's disc made right** (section 7). A model the user distrusts, wrong by two to five times in its
   most visible number, is first.
2. **The light aeroplanes onto surfaces**, then the **heavies**, where the 747's 0.28 turn and the heavies' 37 deg/s roll-in are the
   most visible wrong things in the sky, then the **jets on fly-by-wire**.
3. **Ground effect for wings** and **a stall buffet** (display only), with the first aeroplane that moves after the
   Cessna: cheap and noticed at every landing.
4. **Propeller swing** (P-factor, torque, slipstream) with the warbirds: it is what a taildragger's take-off is. **And
   its thrust is worth more than its swing to them**: lane/warbirds2's P-51 takes 692 m to get off where its book says
   442, on a fixed-pitch line copied from the Cessna. Measured on their own numbers, a constant-speed propeller holds
   +9.3 kN at 10 m/s and +6.2 at 30 where the line has faded, which is a run of about **465 m against the book's 442**
   (`flightcore_prototype/p51_for_warbirds2.cpp`). That is the strongest single case for this block, and it is why the
   propulsion step is 3.5 in section 9 rather than an extra at the end.
5. **Helicopter torque** with the rebuilt disc, behind the yaw SAS the user chooses.
6. **Density with height**, **spool-up** and **rotor RPM** only when asked: the first is cheap and little noticed at
   the heights flown, and the other two need state on the wire.

## 6. Tests: "as expected, and close to reality"

The rule (CLAUDE.md 3, and the playbook): a check flies the kind through the real input path (`set_pilot_input`, the
bus, or the autopilot) and holds it to a number from OUTSIDE the model (a published figure, a sign, a ratio between two
flights), and each check has a mutant that must turn it red. `cessna_book.gd` is the pattern; `littlebird_book.gd`, as
it stands, is the trap (section 7, L8).

### What each category holds, and where the figures come from

| Category | Book figures to hold (flown) | Sources to cite | Job suite |
|---|---|---|---|
| light single | top speed, Vy and its climb, best-glide ratio by energy, flaps-down and clean stall, take-off roll, pb/2V, turn = g tan b / v | the POH (Cessna 172S, have it) | `traffic_pattern` (have it) |
| warbird | top speed at sea level, climb, stall gear and flaps down, take-off roll, roll rate | AN 01-60JE-1 (P-51 Pilot's Flight Operating Instructions), NACA reports on the P-47 and P-51 (public domain; the P-51's stall is in its `sources.md`) | take-off, circuit, three-point landing (warbirds2's) |
| glider | best L/D at its speed, minimum sink, stall | the Duo Discus flight manual and the DLR/Idaflieg 1994 polar (in its `sources.md`: 45 at 100 to 103 km/h, 0.58 m/s) | a thermal climb (`air`), a field landing |
| heavy turboprop | top speed, cruise, stall in landing configuration, take-off run | Jane's for the E-2D (the drafts' sheet), the C-130H's performance manual figures on Wikipedia as a floor | the instrument approach; the gunship's orbit |
| heavy jet | V2 and Vref at a stated weight, cruise Mach, take-off field length, approach speed | Boeing's ACAPS (runway figures, already cited by `airport.gd`); Wikipedia as a floor for speeds | the instrument approach and Cape International (`airport`, `testfield_traffic`) |
| fast jet | top speed at sea level, sustained and instantaneous turn, roll rate, g limit, approach speed and alpha | NATOPS figures where public (the F/A-18's on-speed approach alpha, about 8 degrees, to be cited from the manual itself); NASA HARV reports; Wikipedia as a floor | a carrier approach on alpha; the attackers' gun runs |
| attack jet | the A-10's published 381 kt, 300 kt cruise, 120 kt stall (flown this time), 6,000 ft/min | Wikipedia, already in `sources.md` | the gun run |
| helicopter | climb at max continuous power, level speed at full power, hover collective IGE and OGE, the collective falling through translational lift, autorotation sink at 0 and at best speed | the MD 530F sheet; ADS-33E-PRF for the rates; for the UH-60 and Apache, their Army TMs' published figures | `littlebird_circuit` (have it), a hover taxi, a confined landing |
| tandem helicopter | the same, and the pitch response to differential collective | Boeing's CH-47F sheet; NASA TM-84351 inertias (have them) | a sling-load pattern, later |
| boats | top speed, the time onto the plane, a full-helm circle's diameter, lean | makers' sheets (the CB90's 40 kt; the RIBs'), Wikipedia as a floor | the seakeeping runs (have them) |

Every kind's first book suite is `<kind>_book.gd`, modelled on `cessna_book.gd`, and every book figure goes in the
kind's `sources.md` with its source and licence (today the Little Bird's and the Apache's are cited only as "[W]" in
suite comments).

### The mutants, per claim

- Each extra has its own switch in the kind's knobs, as `surface_mutant` does now: ground effect off must fail the
  flare check; P-factor off must fail the take-off swing check; torque off must fail the helicopter's collective-yaw
  check; the rebuilt disc's climb power off must fail the climb (it is today's disc: section 7).
- The old model is the mutant of every book check that the move exists to fix (the lumped wing for the turn, the old
  disc for the climb), as `cessna_book` does.
- **A mutant is run inside the suite**, not left to a hand on the command line: the suite inventory found `crashes`,
  `seakeeping` and the Little Bird's climb mutant exist only as flags, and `warthog_flight` ignores `--set` entirely.

### The fingerprint, for "every other kind unchanged"

A new suite, `flight_fingerprint.gd`: every pilotable kind spawned in the same place, flown ten seconds on one script
of stick, pedal, throttle and bus through `set_pilot_input`, and ten more on its autopilot, printing its final
position, velocity, attitude and spin as hexadecimal floats. A step that is meant to change one kind shows exactly one
line different; a refactor shows none. It is the cheapest way to prove "byte-identical until its turn" and it runs in
seconds.

### The kinds to hold first

1. **The Little Bird**: a flown book (the MD 530F), with the old disc as the climb's mutant.
2. **The light twin** (`plane`): most of the island's traffic; needs a drawn planform first, or it waits for the P-38.
3. **The Duo Discus**: its polar is published and held by no suite, and the lumped glider gains energy.
4. **The 747 and 737**: the worst turns in the sky, and Cape International's job suites already exist.
5. **The F/A-18F and F-16**, together, on fly-by-wire, with the carrier approach as the job.


## 7. The Little Bird's rotor disc, audited

The user asked for this specifically: *"i don't trust the work that was done on that model's flight model."* The user
is right not to. The disc is honest in shape (pure, stateless, behind a switch, mutants for four effects), but **its
thrust is still a thruster, its power model has no climb power in it, and its book suite never flies the
helicopter.** Measured two ways: the lane's own suites in this worktree, and `flightcore_prototype/rotor_audit.cpp`,
which includes `rotor_disc.hpp` unedited and integrates it with the body drags `drive_vehicle` applies on the disc
path (`drag_vertical` 2.4, `drag_forward` 0.6) at 120 Hz, attitude held.

| # | Finding | Measured | Cause |
|---|---|---|---|
| L1 | **It climbs two to five times the book.** MD 530F: 2,070 ft/min, 10.5 m/s | `littlebird_flight`: best climb **23.3 m/s** (it passes: the floor is "at least 6" with no ceiling). Prototype, full collective held from a hover: **53.2 m/s** after 30 s; lever 0.8, 41.1; lever 0.6, 22.9 | `power_required` is `T x vi + profile + parasite` (`rotor_disc.hpp` 133-139). Momentum theory's power is `T x (Vc + vi)`: **the climb itself costs nothing.** At 53 m/s up the disc reports 109 kW against 317 available; the honest figure is about 1,209 kW. So the power clip never binds in a climb, and the only brake left is `drag_vertical` 2.4, a typed body drag (`cockpit_world.cpp` 15989-15990) |
| L2 | **The bottom of the lever is a cliff.** | Lever 0.079: **0 N**. Lever 0.080: **8,639 N**, 0.63 of the weight. From a hover, lowering the collective the last 8 per cent drops the helicopter until it is sinking at 2 m/s, and then the autorotation formula catches it | Two formulas meet at 0.08 with nothing blending them (`rotor_disc.hpp` 236-244): below it thrust is autorotation only, and zero until the sink passes 2 m/s (172-174); above it, `W x (0.55 + lever x 0.95)` |
| L3 | **Autorotation does not care about airspeed.** A real autorotation's sink is lowest near 50 to 60 kt (the published band here is 1,500 to 2,500 ft/min, 7.6 to 12.7 m/s) and highest straight down, and it glides | Steady sink **11.9 m/s at 0, 15 and 30 m/s forward**, identical | `autorotation_thrust` is `W x down / (1.2 vh)`, the descent along the mast only (165-176). It is typed so that 12 m/s down carries the weight, and the suite's autorotation check asks exactly that (`littlebird_book.gd` 132-142) |
| L4 | **Thrust is a share of the weight, still.** `W x (hover + lever x collective_range)`, then multiplied | A heavier Little Bird hovers at the same lever; so would one carrying six troops | The plan said the magnitude would come from momentum theory. It does not: the collective still commands a share of weight (240), and ground effect, translational lift and the vortex ring multiply it (241-251). Momentum theory reaches the thrust only through the power clip, and L1 is why that clip is idle |
| L5 | **Translational lift is typed and counted twice.** | +9 per cent at 12 m/s (`littlebird_book`) | Glauert's inflow (114-130) already lowers the induced velocity with speed, which IS translational lift; a typed `1 + 0.18 x etl` on the thrust (242) adds it again, over a typed 8 to 16 m/s ramp (229) |
| L6 | **Sideways and backwards get no translational lift.** | by reading | `along` is the airspeed along the nose, floored at 0 (119, 229). A helicopter's disc sees its speed in the disc's plane, any direction |
| L7 | **Ground effect is taken from the highest ground within 40 m**, not the ground under the disc, and not a deck | by reading | `highest_ground_near(x, z, 40)` (`cockpit_world.cpp` 19625): a hover beside a roof gets the roof's ground effect; a hover over the carrier's deck gets none, because `deck_under` is not asked |
| L8 | **The book suite never flies it.** | by reading, and by running it | `littlebird_book.gd` calls `probe_rotor` at chosen inputs and checks the formula's output: "the climb matches the 530F" asks only that thrust exceeds 0.95 W at 10.5 m/s up, which a disc that climbs at 53 passes; "past Vne" passes on a power figure the disc reports but never enforces; `rotors_off_is_the_old_thruster` reads back a number it just set; and `_probe` resets `rotors` to 1 on every call, so `--set=rotors=0` cannot reach any check (the suite inventory found this too). **Every check is the model's own formula restated** (CLAUDE.md rule 3's tautology) |
| L9 | **Little Bird numbers inside the generic disc** | by reading | tip speed 210 m/s (135), the 2.75 m hub in `classify` (204), the 8/16 m/s ramps, the 18 per cent and the 1.2 vh; `cda`'s comment says 1.15 m^2 and the value is 0.85 (265-267); "four Newton steps" are six fixed-point iterations (114) |

**What is right, and stays:** pure and stateless (a rollback decision), the switch and its mutant bits, the ground
effect's form (the lever to hover falls from 0.473 out of ground effect to 0.392 at 1 m, measured), a hover power of
192 kW against 317 available (plausible for a 530F at gross), the forward speed (71.4 m/s at 15 degrees nose down,
against a 69.5 m/s cruise), the turn (100 per cent of the coordinated rate), and the landing (0.42 m/s). The job
suites (`littlebird_flight`, `littlebird_circuit`) fly the real input path and should be kept, with book bands.

**What I recommend** (the step in section 9): rebuild the disc as the shared rotor block, and make the Little Bird its
first kind.
- **Thrust from the blades, not from the weight.** Blade-element momentum, the textbook form (Leishman ch. 3 and 5;
  Padfield ch. 3): `CT = (sigma a / 2) (theta (1/3 + mu^2 / 2) - lambda / 2)`, with the collective as blade pitch,
  the inflow `lambda` from Glauert (what the disc already solves), and `mu` from the airspeed in the disc's plane in
  any direction (L6). Thrust then does not know the weight (L4), translational lift comes out of the inflow with
  nothing typed (L5), and the lever is one continuous curve (L2). Solidity, lift slope, tip speed and hub height are
  read from the kind (L9): the drawing has the blade count, chord and radius.
- **Power with the climb in it**, `T (Vc + vi) x kappa + profile + parasite`, and thrust held to what the engine can
  give (L1). The climb then stops where the power runs out, which is what 2,070 ft/min is.
- **Autorotation as zero engine power, not a formula.** With the engine giving nothing, the disc can hold only what
  the descent pays for; the sink at which that carries the weight falls out of the same power equation and depends on
  forward speed, so the U-shaped curve and a glide come for free (L3). It needs one decision (question 4): what puts
  the engine at idle, since a single lever is both collective and throttle today.
- **Ground effect over what is under the disc,** the deck included (L7).
- **A book suite that flies it** through `set_pilot_input`: the steady climb at full collective, the level speed at
  full power, the hover lever in and out of ground effect, the collective to hold height falling through 8 to 12 m/s,
  the autorotation sink at 0 and at 30 m/s, each against the MD 530F and each with its mutant; and the job suites'
  bands tightened to the book (the plan's step 2, never done).
- Keep the rate interface for the cyclic and pedals (the HeliMixer is tuned on it). Torque reaction and a tail
  rotor's power share are the next realism step, and are in section 5.

**Prototyped, and it holds the book** (`flightcore_prototype/rotor_bem.hpp`, run by `rotor_bem_audit.cpp` with the same
body drags and integration as the audit; `results_bem.txt`). The Little Bird's disc from its drawing: six blades of
0.183 m chord (the OH-6A's; the MH-6M's is not published), a 215 m/s tip, a section's cd0 0.0095, 425 shp, no number
tuned to a figure except cd0, which moves the hover power and the autorotation sink together:

| | MD 530F | today's disc | the prototype |
|---|---|---|---|
| climb at full collective, held | 10.5 m/s | 53.2 | **10.9** (power-limited at 317 kW) |
| climb at 0.8 and 0.65 of the lever | the same, power-limited | 41.1, 22.9 | 10.8, 10.7 |
| level speed at full power | cruise 135 kt, Vne 152 | (not power-limited) | **142 kt** |
| hover lever out of and in ground effect | less in it | 0.473, 0.392 | 0.451, 0.415 (227 kW and 204 kW) |
| the lever at 0.079 and 0.080 | continuous | 0 N and 8,639 N | 932 N and 952 N |
| autorotation sink at 0, 20, 40, 55 m/s forward | 1,500 to 2,500 ft/min at its best speed; more straight down | 11.9 at every speed | **19.1, 13.1, 11.8, 16.1 m/s**: the U-curve, best 2,315 ft/min at 40 m/s |
| cost a call, cruise and hover | budget +250 ns an aircraft | 122 ns | **60 ns** |
| cost a call, a climb at the power limit | | 122 ns | 215 ns (+93 on what it replaces) |
| cost a call, in the vortex ring | | 122 ns | 177 ns (+55) |
| cost a call, an autorotation, with speed on or straight down | | 122 ns | 379 and 353 ns (+257 and +231) |

**It is half the price of today's disc in every state a helicopter normally flies in, and inside the budget in all but
one.** The budget is +250 ns an aircraft a tick over the model being replaced, and today's disc is 122 ns; the dearest
state, an autorotation with speed on, is +257, three per cent over, and the only states that reach it are ones a
helicopter is in for seconds at a time. **Left there deliberately** (team-lead's ruling, 2026-09-19, on the user's
standing "good enough, tune later"): seven nanoseconds over a budget, in a state held for seconds, is not worth
another pass of the blades. The work per call, counted rather than guessed (`count_bem.cpp`): one pass of
the blades and the inflow in cruise and in a hover, three when the engine's power binds, and five steps of the ring's
regula falsi in a slow descent. First drafts cost 505 ns across a mixed spread and 975 ns in an autorotation. What
brought them down: an inflow solved from its own closed-form axial answer (three Newton steps with an analytic slope,
not fourteen bracket steps from an end where the function is nearly singular); the ring's blend taken smoothly to
exactly nothing at three times the hover's inflow, so beyond that its solver is skipped with no step in the force; the
thrust the power holds found by a linear step where the disc absorbs power and by the parabola's larger root where the
air drives it; and a pass that stops when the engine is no longer the limit. All timings were taken with another lane's
GPU slot up, so they are upper bounds, and relative to each other.

**The same block, three more helicopters, nothing but their own numbers** (`rotor_fleet.cpp`, `results_fleet.txt`).
This is the architecture's whole claim, tested before it is built: `rotor_bem.hpp` unchanged, with each kind's radius,
blade count and chord, tip speed, engine power, mass and flat-plate area, and no code of its own.

| | disc loading | hover lever | climb at full collective | fastest level | autorotation, least sink |
|---|---|---|---|---|---|
| MH-6M Little Bird | 25.7 kg/m^2 | 0.45 | 11.4 m/s (book 10.5: 1.09) | 143 kt (book cruise 135, Vne 152) | 11.0 m/s at 68 kt |
| UH-60M Black Hawk | 47.5 | 0.69 | 13.1 m/s | 151 kt | 9.7 m/s at 78 kt |
| AH-64D Apache | 43.2 | 0.61 | 18.1 m/s (book 9.0: 2.01) | 183 kt (book 143 cruise, 158 max) | 10.3 m/s at 87 kt |
| CH-47F Chinook, two discs | 28.5 | 0.45 | 28.0 m/s | 214 kt | 11.4 m/s at 87 kt |

**What it proves, and what it found.** The block carries across with knobs alone: every kind hovers on a sensible
lever at a sensible blade pitch, and each is power-limited in its climb rather than drag-limited. It also found a gap
that the Little Bird alone could never have shown: **the disc had no top speed of its own.** The first run held the
Black Hawk and the Apache at 210 kt, because nothing in it knew that a rotor's usable thrust falls as it goes faster
(the retreating blade runs out of angle). A boundary on CT/sigma against the advance ratio (Leishman ch. 7, as a
parabola through it: two constants, shared, not per kind) put the Black Hawk at 151 kt against a published cruise near
150. The Apache and the Chinook are still fast, and for a reason worth writing down: **their game masses and my
estimated engine powers are what is wrong, not the model.** The Apache flies at 7,270 kg where the book figures are at
its real gross, and both kinds' transmission limits and flat plates here are ESTIMATE. Each kind needs its own book in
its `sources.md` before a suite holds it, which is step 7's work and not this block's.

Still to decide before building: the tail rotor and torque (question 3), and what puts the engine at idle (question 4).
The prototype's autorotation takes the engine at idle as given.


## 8. Risks

- **Merge collisions in `cockpit_world.cpp`.** Step 1 touches many functions. lane/warbirds2 holds the next C++ turn
  and is building the taildragger ground model in the same file; lane/testfield and the sweeper are live. Step 1 goes
  after warbirds2's C++ merge, rebased on it, and is kept mechanical so a reviewer reads it as moves, not changes.
- **The world's edge moves with the fastest turn.** Every level's soft band is sized on the widest top-speed turn at the
  autopilot's bank (`turn_radii`). A kind moved onto a real model keeps its top speed where the game chose it (the
  fighters' 221 m/s) unless the user decides otherwise, and `terrain_level` runs in every step's gate.
- **Jobs sized on the lumped turn tighten by about two** when a kind moves (the playbook's trap): `InstrumentApproach`'s
  vectors, the pattern sides of the big aeroplanes, the attackers' runs.
- **ESTIMATE numbers become visible.** Tail areas and inertias are soft on most drawings; a real model shows their
  error where the lumped wing hid it. The stiffness guard (roll time constant over three ticks) catches the dangerous
  case, and every ESTIMATE stays marked in the kind's knobs.
- **Packages.** Nothing new goes in `kind_geometry` (a new key re-hashes every craft package, lane/floats).
- **Feel is not a suite.** Every step ends with the user flying the moved kind in a headset, and the old model a
  `--set` away for comparison until the lumped path is deleted.

## 9. The migration plan

Each step is one READY: gated on its own suites, the fingerprint and what it touches, merged before the next begins,
and priced in a MEASUREMENT slot where it changes a force. "Unchanged" means the fingerprint suite prints the same line
for that kind. C++ merges are serial and team-lead hands out the turns; **lane/warbirds2 goes first**.

| Step | What | C++? | Changes which kinds | Proof | Price (work estimated; cost measured when built) |
|---|---|---|---|---|---|
| **0.5** | `flight_fingerprint.gd`: every pilotable kind, scripted input through `set_pilot_input` and its autopilot, final state as hex floats | no | none | runs green twice with identical output; a one-number `--set` change shows exactly one kind's line different (its own mutant) | about 1 hour; can land now, before any C++ turn |
| **1** | **The blocks, extracted, nothing changed.** `flight/air.hpp`, `loads.hpp`, `control.hpp` (the law, the rate servo, `inertia_about`), `hull.hpp` (keel, bow wave, stern rudder, probes), constants in one place (D2 to D17); `Handling`'s fields as one X-macro list (D20); the rows scaled by hand as `carry_to_mass` from their parent row only where the result is bit-identical, else left with a note (D18, D19) | yes | none | fingerprint identical on every kind; `-Tier core`; every flight suite | about 4 hours; 0 ns by construction, checked in a slot |
| **2** | **The Little Bird on a correct rotor block** (section 7): blade-element momentum thrust, climb power, autorotation as zero engine power, ground effect under the disc; the Little Bird as the first `kinds/<kind>.hpp` model; `littlebird_book.gd` rewritten to fly it against the MD 530F, the old disc as its mutant; `littlebird_flight`'s bands tightened to the book | yes | Little Bird only | the book suite; the job suites; fingerprint unchanged for every other kind; the headset | about 6 hours; budget +250 ns (the old disc is 112 ns a call in the prototype) |
| **3** | **The Cessna onto the blocks**: `kinds/cessna.hpp` calling the blocks directly, no recipe; `surfaces.hpp` generalised to N panels (two fins, stabilators, twin booms); then ground effect and the buffet as its first extras, each with a mutant | yes | Cessna (unchanged, then the two extras) | fingerprint identical before the extras; `cessna_book`, `surfaces`, `traffic_pattern`; a flare check with its mutant | about 4 hours; the extras a few ns |
| **3.5** | **The propulsion block, with the propeller's swing**: a constant-speed propeller's thrust from momentum theory, and torque, P-factor and the slipstream's swirl, with a handedness an engine. The warbirds first, because they are the kinds it is for; then the Cessna's own swing | yes | the warbirds (lane/warbirds2's kinds), then the Cessna | the six take-off checks (section 3), each with its mutant; the warbirds' published take-off distance; `flight_fingerprint` unchanged for every kind that has no propeller | about 4 hours; 82 ns a propeller measured in the prototype |
| **4** | **Light and raw**: the Duo Discus (its polar, and the energy gain found and gone) and the Savoia (a racer by the user's choice, held to its own game figures) | yes | glider, Savoia | a `glider_book` (L/D 45, min sink 0.58), `water`, `water_rudder`, `ground_stick` | about 4 hours |
| **5** | **The heavies**: 737 and 747 (`heavy_jet`), C-130s, Hawkeye and CL-415 (`heavy_turboprop`, the CL-415 with its hull); augmentation 0.5; inertias from components | yes | those six | their books; `traffic_pattern`'s instrument approach, `airport`, `testfield_traffic`, `terrain_level`; the 747's turn at 1 | about a day; two lanes' worth if wanted |
| **6** | **The jets**: F/A-18F and F-16 on fly-by-wire (`fast_jet`), then A-10, F-14 and EA-6B (`attack_jet`); a game-sized CLmax until the carrier has wires | yes | those five | their books; `falcon_flight`, `warthog_flight`, `crashes`' carrier trap; `terrain_level` | about a day |
| **7** | **The other helicopters on the rotor block**: the light helicopter, UH-60, Apache (`helicopter`), Chinook (`tandem_helicopter`) | yes | those four | their books (Army figures); `rotor_rates`, `rotor_turn`, `rotor_hold`, `trim`, `apache_flight` | about 6 hours |
| **8** | **The THREE VTOLs**: the Osprey (a wing, two discs, its conversion), the F-35B (a wing, a nozzle, a fan) and the Harrier, in their own files -- **and the hover margin made ABSOLUTE for all three** (section 11) | yes | Osprey, F-35B, Harrier | `lightning_flight`, `osprey_reel` made a suite, `crashes`' vertical landings, **and a hover-weight-limit check that cannot be written today** | about 8 hours |
| **9** | **Boats**: the hull block already extracted; a book for speed, time onto the plane and circle; porpoising if wanted | yes, small | boats, as chosen | `seakeeping`, `handling`'s boat gates | about 4 hours |
| **10** | **Delete** the lumped wing, the aeroplanes' rate servo and the weight-fraction thruster once no kind uses them | yes | none | fingerprint identical | an hour |

**Why this order.** The fingerprint first, because every later step's "nothing else moved" rests on it. The blocks
before any kind, so the first kind built on them is built on the final shape and not moved twice. The Little Bird
next, because the user distrusts it, it is wrong in its most visible number, and it is the one rotor model the other
helicopters will share: building it right once is what step 7 reuses. The Cessna third, because it proves that
moving a working kind onto the blocks changes nothing. Then the fleet in the order of what a player notices (the
heavies' turns and the jets' feel before the rarely flown), each category landing whole. The warbirds are
lane/warbirds2's and need not wait: they can land on today's surfaces, and get their own files -- the Cessna's list
plus a constant-speed propeller, its swing and a taildragger's wheels -- once step 3 has landed.

**While waiting for a C++ turn** this lane can land step 0.5, and prototype step 2's rotor block beside
`rotor_audit.cpp`, holding it to the MD 530F figures before a line of game code changes.

## 10. Questions for the user, ANSWERED

**The user, 2026-09-19, through team-lead: *"yes go with your recommendations on all the flight model questions."***
Every recommendation stands as written. Each is repeated here with what it now means for the build, so this file is
the record.

1. **A flight model per kind, built from shared blocks with knobs, and categories as recipes a kind starts from?**
   Recommended: yes. It is what you said mid-review, and it is the shape of the one model that works (the Cessna's).
   **ANSWERED YES: build it, in section 9's order** -- **and then SHARPENED by the user on 2026-09-19, which changed
   the design and not merely the wording:** *"I still think that having a different flight model for each plane is
   good and we have lots of common functions to take care of physics correctly (inlined). That way they all don't
   just feel like copies with knobs turned (and we can tweak them more)."*
   **So the recipe layer is GONE.** It was the half of the plan that would have produced the very thing they are
   describing: `recipes::light_single(k.airframe, ...)` IS a shared model with knobs, and a Piper calling it unchanged
   is a copy with the knobs turned. Now every kind's `fly()` calls the inline blocks directly as its own list of
   forces, the families in section 4 are a table to write FROM rather than a function to call, and two aeroplanes are
   alike only as far as they choose to be. **This is the correction to make before step 1, because step 1 defines the
   blocks that everything else is written from.**
2. **The Little Bird's disc rebuilt next, straight after the shared blocks?** Recommended: yes. It climbs at two to five
   times its book, the bottom of its lever drops it, and its autorotation ignores airspeed (section 7). Meanwhile it
   can go back to the old thruster with one number (`rotors` 0), which climbed at 15.6 m/s, nearer the book than the
   disc.
   **ANSWERED YES: rebuilt straight after the blocks are extracted, and NO stopgap on main in the meantime
   (team-lead's ruling): the disc stays as it is until the rebuild lands.**
3. **How a helicopter feels in your hands.** Real torque (the nose swings when you pull collective) makes the pedals
   work for their living. Recommended: torque on, with a gentle heading hold on the pedals for a human by default and a
   setting to turn it off; the autopilot flies its own pedals either way.
   **ANSWERED YES: torque on, the heading hold on by default, a setting to turn it off.**
4. **What puts a helicopter's engine at idle?** Autorotation needs the engine to give nothing, and today the one lever
   is both collective and throttle. Recommended: a switch on the bus (engine to idle) added with the rotor block, so an
   autorotation is something you choose to practise; with the engine running, the bottom of the lever is low pitch, as
   in the real aircraft.
   **ANSWERED YES: the switch goes on the bus with the rotor block, which makes it part of step 2.**
5. **The jets' stall speeds.** Recommended: keep decision C from the first plan: a game-sized CLmax for the carrier
   jets (45 to 50 m/s with flaps) until the carrier has arresting wires, then real ones kind by kind.
   **ANSWERED YES: a game-sized CLmax until the carrier has wires.**
6. **Game-chosen deviations** (the Savoia's hot-rod power, the Hawkeye's 140 m/s for the speed order, the fighters' top
   speed sized by the world's edge). Recommended: keep them, and have each book suite hold the game's figure and name
   the book's beside it, so the deviation is written down rather than forgotten.
   **ANSWERED YES: kept, and every book suite names the book's figure beside the game's.**
7. **The cheap extras first: ground effect and a stall buffet with the next aeroplane that moves?** Recommended: yes;
   they are noticed at every landing and cost almost nothing.
   **ANSWERED YES: both arrive with the next aeroplane that moves, which is the Cessna at step 3.**
8. **State on the wire for realism** (rotor RPM for a flare, engine spool-up, actuator lag). Recommended: not now.
   Each costs bits and rollback work; ask again once the fleet is on the blocks.
   **ANSWERED YES to the recommendation: none of it on the wire for now, and asked again when the fleet has moved.**
9. **Boats in this pass?** Recommended: yes, last, and light: the hull block (already mostly shared code) and a book
   for speed, planing and turn, with no new physics unless you want porpoising.
   **ANSWERED YES: in this pass, last and light.**

**Still to put to the user when its step comes** (team-lead's, step 7): the Apache's 7,270 kg and the Chinook's
15,000 kg, which are not the masses their published figures are quoted at, with the flown numbers beside them
(`todo/flightcore--helicopter-review-steps.md`).


## 11. A VTOL HOVERS AT ANY WEIGHT, AND IT ERASES THE ONE FACT ABOUT A HARRIER

**Found by lane/harrier on 2026-09-19 by reading `fly_tiltrotor` rather than assuming it, and TAKEN BY THIS LANE**
(team-lead, so that it lands in one place): it is a shared flight-model change plus three kinds' handling, which is
this lane's pass by definition, and it goes into **step 8** above rather than becoming a todo.

**The fault, in one line** (`cockpit_world.cpp`, `fly_tiltrotor`):

```cpp
const float rotor_borne = f.mass * 9.81f * (h.hover + in.throttle * h.collective_range);
```

**The rotor-borne end is a MULTIPLE OF WEIGHT, so it scales with the mass and the hover margin never changes.** A VTOL
loaded to its limit hovers exactly as willingly as an empty one. The Osprey and the F-35B have it identically; it
predates all three aeroplanes.

**Why it matters more than it reads.** It erases the single defining operational fact about a Harrier. 105 kN of
thrust against a 14,100 kg rolling limit is **0.76 g** -- it *cannot* lift its rolling take-off weight vertically,
which is the entire reason the rolling take-off and the ski jump exist. On today's model it lifts that weight without
complaint, so lane/harrier's flight suite can show that a short take-off **works** but cannot show that it is
**necessary**. **A hover-weight-limit check is not writeable against the current model at all** -- which is the real
cost: not a wrong number, an unaskable question.

**The fix, which is theirs and which this lane will make: make the rotor-borne end absolute, as the wing-borne end
already is.** `hover` and `collective_range` in newtons, or a published `vertical_thrust`, so that a heavy VTOL sinks.
**It also aligns the tiltrotor with the rotor disc**, which has been absolute since the Little Bird moved onto
blade-element thrust: it is the same correction, one model later.

**Their two numbers, derived rather than typed**, for whenever the Harrier is reached: thrust **105,000 N**, and
`hover + collective_range` = 105,000 / (9,415 x 9.81) = **1.1369 g**. **Both still stand after they got the NAVAIR SAC
sheet** (00-110AV8-4, October 1986) and corrected several of their others, because the pair is internally consistent:
the **-408** engine's thrust against the **-408-era 9,415 kg** vertical limit.

**AND THE PLANFORM NUMBERS ARE DELIBERATELY NOT COPIED HERE.** They live in the Harrier's own `sources.md` with the
document they came from, and this file points at them rather than keeping a second copy -- because several of them
moved within a day of being first quoted (area 22.61 -> **21.368 m²**, aspect ratio 3.78 -> **4.0**, sweep "37°" ->
**30.62° at quarter chord**, and a **-11° ANHEDRAL** on a shoulder wing that had been missed entirely), and a roster
kept here would now be wrong in four places. Ask the authority; do not keep a roster.

**Their arbitration is worth repeating because it is the method and not the answer:** the SAC prints span, area and
aspect ratio on one page, and **30.33² / 230.0 = 4.00**, so the three agree with each other. A 243.4 sq ft figure
found elsewhere does not fit its own span at its own stated aspect ratio, so it loses -- and the 37° sweep came from a
search summary rather than a document, which they own as their mistake. **A figure that is consistent with two other
figures from the same page beats a figure that is merely published.**

**TWO CAUTIONS FOR THIS LANE'S OWN WORK, both from the same sheet:**
- **The variant trap.** The 1986 SAC is the day-attack aeroplane with the F402-RR-406; the Night Attack has the -408
  at 105 kN. **The airframes are dimensionally identical, so every SHAPE figure is safe for either and the THRUST is
  not.** Anything this lane derives from thrust -- the envelope's top speed, its acceleration, its hover margin --
  has to name the variant it came from.
- **A lift-mode thrust is not a thrust.** The SAC's ratings *"include splay loss (90° nozzle rotation)"*: they are
  already lift-mode figures. **So 105 kN is not comparable with another kind's installed thrust**, and the gym's
  envelope, which derives a top speed and an acceleration from thrust against drag, would quietly under-read this
  aeroplane if the number went in unlabelled. Whatever `thrust` the Harrier's handling ends up with must be the
  wingborne figure, with the lift-mode figure kept separately for the hover margin.

**And the good half of their reading, which this lane wants for the guidance work:** `thrust_along` clamps the LEVER
and not the ANGLE, so a nacelle travel past ninety degrees is evaluated honestly instead of saturating at the
vertical. At 98.5 degrees the axis is -0.1478 forward and 0.9890 up -- **which is a braking stop, free, with no new
mechanism.** That is a deceleration a VTOL has and no other kind does, and it belongs in the envelope's
"deceleration available" the day that lands: `world/braking_curve.gd` will happily plan on it, and a tiltrotor that
can stop is the one kind whose arrival the braking curve should be able to make exact.

**THE THREE KINDS' NUMBERS, and every one of them carries its conditions** (the rule above, landing on this lane's own
work). From lane/harrier, 2026-09-20:

| kind | lift-mode thrust | reference mass | margin |
|---|---|---|---|
| **Harrier** | **105 kN** (F402-RR-408, includes splay loss) | 9,415 kg | **1.1369 g** |
| **F-35B** | **186 kN** = 80 swivel + 89 lift fan + 17 roll posts | 17.5 t | **1.08 g** |
| **Osprey** | **not published to us** -- harrier declined to invent one, which is right | -- | **derive at a named reference weight** |

**BOTH PUBLISHED FIGURES ARE DRY THRUST IN LIFT MODE, already net of splay loss, and NEITHER is the engine's installed
maximum.** They must never meet a wingborne field: the gym derives a top speed and an acceleration from thrust against
drag, and either number dropped into `handling().thrust` unlabelled would quietly make that aeroplane the slowest fast
jet in the fleet -- and the scoreboard would be believed. **`lift_mode_thrust` is a different field from
`installed_thrust`, and the hover margin is the only thing that reads the first.**

**The Osprey is derived, at a named reference weight**, as this lane recommended and team-lead approved: take its
current `hover + collective_range` as a g-multiple, multiply by its published maximum vertical take-off weight, and
state in the commit which weight was used. **The change then reproduces today's behaviour exactly at that weight and
differs only away from it**, which is what makes every moved fingerprint line explainable rather than mysterious.

**What this lane owes back:** the change is step 8, behind the blocks, the Little Bird, the Cessna and the propulsion
block. If lane/harrier needs the hover limit before then, say so and it can be pulled forward as its own small READY
-- it is a handful of lines in one function plus three kinds' numbers, and the suites that would catch a mistake
(`lightning_flight`, `crashes`' vertical landings, the fingerprint's three lines) already exist.


## 12. Two hand-overs that land on step 1 (2026-09-20)

### The 310R publishes two wing areas, and the lift slope must take the explicit one

lane/twin310's Cessna 310R has **two** published planforms, and which one a lift slope takes is the difference
between stalling where the book says and not:

| | area | aspect ratio | what it is |
|---|---|---|---|
| **taken** | **16.26 m²** | **6.34** | the wing's own span -- **the surface an integration walks** |
| not taken | 17.49 m² | 7.24 | carried out over the tip tanks |

**Their recommendation, accepted by team-lead: the wing's own area**, with the tanks' end-plating handled as **the
end-plate effect it actually is** rather than folded into the planform. Folding it in looks like a bigger wing at
every angle of attack; modelled as an end plate it raises the effective aspect ratio and cuts the induced drag, which
is what a tip tank really does. `Cessna310Airframe.planform()` publishes both, so **nothing downstream has to guess
and nothing has to keep a copy** -- `surfaces.hpp` asks for the explicit one by name.

**Why it lands on step 1:** the panel list is step 3's, but the *interface* is step 1's. A block that takes "the wing
area" and is handed either number silently is the same trap as a lift-mode thrust in a wingborne field. The block
takes the area it integrates over, and the end-plate effect is a separate term with its own name.

### The constant-speed propeller, handed over by lane/warbirds2 -- and the first real test of the new shape

Their exit note calls this lane's prototype **the lever on every warbird's long take-off run: 692 m down to about
465 m**. It is a todo in their name and it is step 3.5 here.

**Build it as a different LIST, not as a flag.** `propulsion::` gains a `constant_speed` variant **beside**
`fixed_pitch`, and the warbirds' files pick it; the Cessna's file goes on calling `fixed_pitch`. The tempting version
-- one `propeller()` with a `constant_speed` bool in the knobs -- is precisely the shared-model-with-a-knob this
document has just removed, and it would be the first thing to rebuild it. **This is the first case where the two
shapes differ in practice, so it is the one that sets the habit.**

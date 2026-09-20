# cockpit — the craft, and who flies them

Part of [`agents.md`](../agents.md), which carries the rules every one of these files assumes and an
index of the rest. **What flies, how it moves, what it is flown from, and what the pilot sees
out of it.**

## EVERY VEHICLE HAS ITS OWN MOVEMENT MODEL

A **kind** names a vehicle. A **model** names how it moves, and several kinds can share
one -- a Cessna and a glider are both airplanes. Keeping them apart makes "add a vehicle"
a table entry rather than another branch in the simulation.

| Model | What exists | What does not |
|-------|-------------|---------------|
| `HOVER` (pod) | cancels its own weight, full authority at a standstill | wing, stall |
| `AIRPLANE` (plane) | lift from angle of attack, camber, stall, induced drag, fuselage side force, fin, pitch stability, aerodynamic damping | hover, grip |
| `HELICOPTER` (heli) | thrust along the **rotor disc**, collective on the throttle, tail rotor at zero speed | wing, nose thrust |
| `CAR` (car) | a tyre at each axle with its own slip angle, speed-tapered lock, rolling resistance, parking hold | wing, pitch, roll |
| `BOAT` (boat) | buoyancy, keel, a rudder force at the stern, wave-making resistance, righting moment | wing, pitch, roll |
| `TRAIN` (train) | one scalar distance along a railway and one scalar speed; drawbar pull, a power ceiling, rolling resistance | a free body at all -- its pose is read off the track |
| `TILTROTOR` (osprey) | a wing AND a rotor, with the thrust vector swinging between them | a mode: it is one continuous blend end to end |
| `SAIL` (pirate) | six-probe buoyancy on the swell, sails making lift and drag off the apparent wind at their own heights, a keel that makes lift from leeway, a rudder off the water speed, a bow wave | an engine, a brake: see "A SHIP UNDER SAIL" |
| `SEGWAY` (segway) | a COMMANDED horizontal velocity, a commanded yaw rate, pitch and roll pinned at zero, no authority off the ground | thrust, drag, coasting, leaning, flying: see "A SEGWAY IS HOW A PLAYER WALKS" |

Several kinds share a model and differ only in their numbers and their cockpit: the light
`plane`, the `airliner`, the `tanker` and the engineless `glider` are all `AIRPLANE`, the light `helicopter` and the tandem-rotor
`chinook` are both `HELICOPTER`, and the launch and the `gunboat` are both `BOAT`.

### A SEGWAY IS HOW A PLAYER WALKS

Asked for on 2026-09-15, when the note on the lobby said walking was the hard part:

> "just put them in an invisible vehicle called a segway that way they can move around and they are
> still in a vehicle (but just make it a sphere at their feet."

**A player on foot would be a second kind of moving thing**, and everything here -- replication,
rollback, the crew manifest, boarding, the wire, the CREW page -- knows how to talk about a vehicle
with a seat and nothing else. A segway IS a vehicle, so a person standing in a briefing room is the
same object as a person in an aeroplane and needs no new machinery at all. The lobby then needs a
room and some props, not a player model.

**A 0.35 m sphere, 85 kg, one Pilot seat at the BOTTOM of it**, because the tracker adds the eye
height above the seat pan: put the seat at the middle and the head comes out of the top of the
sphere rather than the top of a standing person. Nothing is drawn -- there is no `craft_segway` mesh,
which is what "invisible vehicle" means; what another player sees is the pilot, which every craft
already draws from the seat. A person's mass rather than a pod's 320 kg, so walking into the
furniture does not move the furniture.

**Its own model, because neither near one will do.** `HOVER` has full authority at a standstill,
which is exactly the strafe that is wanted, and it flies; `CAR` stays on the ground and steers
instead of strafing. And neither stops when you let go, because **a person does not coast**: no
arrangement of thrust against drag both starts at once and stops at once. So `ride_segway` COMMANDS A
VELOCITY -- it closes the horizontal velocity on the one asked for with a clamped step, the same
shape and the same reason as `command_rate` closing on a rate. Pitch and roll are commanded to zero
at full authority whether or not anybody is aboard, so an empty segway stands up and a shoved one
comes back; off the ground it has no authority at all, because a segway that could steer while
falling is a flying segway with extra steps.

`pitch` is negated on the way in and `roll` is not: a stick pushed forward pitches a nose DOWN and
pushing forward is how a person says "go there", while `+1` of roll already means "to the right"
(see `apply_controls`). Diagonal is clamped to the walk rather than left as the sum of two axes.

**Measured** (`tests/segway.gd`, a bare `CockpitWorld` with a floor, 2026-09-15): 3.01 m/s against
the 3.2 asked for, forward, back and both ways sideways, with 0.00 m of drift on each; 3.18 m/s
walking to 0.00 m/s one second after the stick is let go; worst lean 0.000 rad and highest 0.35 m
from a 0.35 m start with pitch, roll, rudder and full throttle held at once.

**The RED is a section rather than a broken build.** Proving these by breaking the model would mean
editing C++ and rebuilding twice, and the proof would vanish on the revert -- so the suite keeps the
contrast instead. The same drive, the same floor, a POD (`HOVER`, which is what `model_of` defaults
to and what a segway would have been given if nobody wrote a model): climbs to 1.79 m, leans 97.7
degrees, and is still doing 19.99 m/s a second after release. A segway that started hovering fails
section 4; a suite that stopped discriminating fails section 5.

**Thirty kinds use the short kind form.** The tandem
fighter is kind 23, the distinct `uh60` (`Sim.Kind.UH60`) is kind 24, the swing-wing `tomcat` (`Sim.Kind.TOMCAT`)
is kind 25, Porco Rosso's flying boat `savoia` (`Sim.Kind.SAVOIA`) is kind 26, the single-seat F-16A `falcon`
(`Sim.Kind.FALCON`) is kind 27, the MH-6M `littlebird` (`Sim.Kind.LITTLEBIRD`) kind 28 and the EA-6B `prowler`
(`Sim.Kind.PROWLER`) kind 29; protocol 17 refused older
builds that did not know the Savoia, protocol 18 those that did not know the sixteen-bit bus (busbits), protocol 19
those that do not know the F-16 and protocol 20 those that do not know the Little Bird, even though the field remained
five bits wide. Protocol 22 refuses peers without the Prowler's native shape, bus and four-seat role table.

**A KIND IS SIXTEEN BITS NOW** (lane/kinds, 2026-09-18: "i'd like to have lots of vehicle kinds"). `kKindIdBits`,
`kNoKind` (its top, 65,535, derived and not typed) and the codec are in `cockpit_components.hpp` beside the bus's
widths; `kNoKindWanted`, `Sim.NO_KIND` and every test read them (`CockpitWorld.kind_limits`, `Sim.kind_limits`). The
old five-bit field is still the short form: codes 0 to 29 are the kind, 30 says sixteen bits follow, 31 is "no kind",
so every frame of today's is bit for bit what it was and a kind from 30 up costs 21 bits only in a record carrying it.
A kind is held as a `cockpit::KindId` wherever it is kept. A number past the table is REFUSED and counted
(`refused_kinds`, `last_refused_kind`), never masked or made a pod. `tests/many_kinds.gd` holds all of it, including
kind 300 from a joiner's real input frame, and goes red on a five-bit width or a typed 31. Protocol 21.

**A FLYING BOAT ON THE WATER STEERS WITH ITS PEDALS** (`steer_on_the_water`, 2026-09-18): any hull the sea is holding
up -- the `tanker` and the `savoia` -- gets a water rudder, a commanded yaw rate whose bite grows with speed through the
water and, stopped, with the propeller's wash. It runs from `alight`, so it never acts in the air or on land.
`tests/water_rudder.gd` holds a full circle at taxi speed to 20-40 s, a straight line with the pedals centred, and the
turn on wheels on land to what it was before.

**THE F-16 IS THE NIMBLE FIGHTER, AND NO FASTER THAN THE OTHERS.** Its air is the F/A-18F's scaled by mass (12.02 / 22
t), then given more thrust than weight (1.11) with its forward drag raised by the same factor, so it keeps the fighter's
221 m/s and the fighter's widest turn -- which is what every level's soft edge is sized on -- while it takes off in 136 m
against 156, rolls at 171 deg/s against 128 and pulls 9.4 g against 8.4 (`g_limit` 9). `tests/falcon_flight.gd` holds
those against the F/A-18F flown the same way in the same run. Its one seat is where `FalconAirframe` puts it: on the
lowest floor the station fits inside the belly, the eye `EYE_HEIGHT` over it and 0.18 m under the canopy, because the
F-16's cockpit is 1.55 m from canopy to belly. The canopy is the fuselage's second surface, not a part of its own, so the
pilot's head is inside one closed solid (`tests/shell_room.gd`).

**THE LITTLE BIRD'S SEATS ARE PINNED BY ITS EGG** (`LittleBirdAirframe`, `EYE_*`). A seat's anchor is
`CockpitStation.EYE_HEIGHT` under its eye and has to be inside the craft; the head wants 0.25 m of roof. In an egg
that narrows as fast as an MD 500's, those two leave the pilots' eyes about two centimetres to move in, 0.60 m apart,
and the anchors 0.20 m under the doors' sills. So its catalogue entry names its own FOOTWELL -- "footwell": {"raise",
"floor_width", "bar_width"}, read by `CockpitShell.fit_footwell` and refused by `CraftPackage.validate_station` outside
their limits -- lifted to the sills and narrowed, because the standard 0.60 m plate stood out of the belly under each
open door; every craft that names none is drawn exactly as before. Its own seat scene (`seat_littlebird.tscn`) puts the
crew board, the flight display and the map screen on the console, off the chin window. TWO SEATS: bench riders were
tried, and every station stands furniture ahead of its seat, which for a rider facing out of the aircraft is a desk of
screens in the air; a station with no furniture is what a rider needs. How it flies is `tests/littlebird_flight.gd`.

**THE AH-64D `apache` (`Sim.Kind.APACHE`) HAS TWO SEATS IN TANDEM, AND BOTH FLY** (lane/apache, 2026-09-18). Seat 0 is
the PILOT, behind and 0.28 m higher, the primary and the only seat that predicts; seat 1 the GUNNER in front and low, on
`Station::Copilot` -- the same linkage, each seat joining the average on the axes it is deflecting, so neither hands
anything over. The drawn cockpit is WIDENED to 1.30 m across its panes (the drawing's 0.99, inside its 1.93 m cheek
bays), the user's "bigger than normal" for the devices; `ApacheAirframe`'s doc block and `craft/apache/sources.md` say by
how much and why. Its own seat scene (`seat_apache.tscn`) lays the display, the crew board and the map low between the
knees: the light helicopter's stood them 0.21 m under the gunner's eye, across the view over the nose that the front
seat exists for, and `tests/apache.gd` holds that no crewman's own devices are the first thing he meets there. THE
COLLECTIVE'S RANGE STAYS NEAR ONE on a helicopter the autopilot flies: the altitude hold never reads it, and at 0.333 the
Apache wandered 69 m and hunted in `tests/trim.gd`; its climb is held by vertical drag instead. How it flies is
`tests/apache_flight.gd`.

**THE APACHE'S CHIN GUN FOLLOWS THE GUNNER'S HEAD, LATE, AND FIRES ALONG THE BARREL.** A seat marked `gun` in the seat
table (a bit on `Seat`, not a new Station, so the gunner keeps his stick and collective) works a HELMET mount:
`slew_to_the_head` takes his head as the wire carries it (`head_through_the_wire`, the smallest-three quantisation, so the
server and his own prediction lay the gun from the same bits), aims at the point 800 m down his look FROM HIS EYE, and
slews at 80 deg/s in azimuth and 60 in elevation (ESTIMATE, under the PNVS's 120) inside stops of +-100, +11 and -60,
worked as an offset from rest so a head swung across never takes the barrel through the tail. A round leaves along the
BARREL: a burst fired before the gun catches up goes where the gun is. `HelmetSight` draws a cross where he looks and a
ring where the rounds go, green and GUN ON inside 10 mrad; it rides whichever camera is drawing, for whoever sits there,
and its quads are drawn both faces (they wind away from the eye; culled, the first reel showed the word GUN over nothing).
`tests/helmet_gun.gd` measures the lag, the stops, zero resims over a head sweep and a round that hits the wall the barrel
points at and misses the one the head does.

**THE APACHE'S HELLFIRES LOCK WHAT A CREWMAN LOOKS AT** -- "the targeting is done via the helmet, not fixed forward like
the plane". The `hellfire` row (`kMissileHellfire`, the AGM-114L: radar, fire-and-forget, SHIPS AND AIRCRAFT and never a
land vehicle, boats' `ships` flag) on a rack marked `helmet`, eight rails at the middles `ApacheAirframe.hellfire_rails()`
draws. A helmet rack's seeker looks FROM EACH SEAT'S EYE ALONG HIS OWN HEAD (`seeker_look`, `helmet_look`: the chin gun's
eye and line, from the same PilotState), so both crewmen lock, each with his own; the cone is 0.05 rad because it is about
the head. The missile leaves TOWARD THE LOCK at 25 m/s, not along the nose, and FROM THE WING ON THE TARGET'S SIDE: from
the other wing it crosses the Apache's own nose, where the seeker's ray to the target runs through the Apache, the missile
flies blind and falls (the first Hellfire reel put one into the stage's floor). Not dropped off the rail either: a
Hellfire's motor lights on it, and a landed Apache's lower rails are 0.97 m off the ground. The lock sight at a helmet
station is `LockSight.helmet`: it rides the eye like `HelmetSight`, for whoever sits there. The pilot launches on his
trigger; the gunner's trigger is the chin gun's, so his launch is on the lower thumb. There is no weapon selector (one
station) but there is a master arm. `tests/helmet_lock.gd` drives both crewmen's heads through a server and two clients.

**THE F-35B `lightning` (`Sim.Kind.LIGHTNING`) FLIES AS A TILTROTOR WITH ONE NOZZLE** (lane/lightning, 2026-09-19). It is
kind 32 on `Model::Tiltrotor`, because that model already is what a B is: a wing, and a thrust vector that swings from the
nose towards the aircraft's up on `Sim.Channel.TILT`, sized from `thrust` along the nose to a share of the weight along the
up, with the controls floored on the swing. How far it swings is per kind, `vector_travel` in the handling (the Osprey's
97.5 degrees by default, the B's 95). THE DRAWN NOZZLE READS THAT NUMBER and `tests/lightning.gd` holds its drawn axis to
the reverse of `Sim.thrust_axis_of`, the expression `fly_tiltrotor` pushes along -- so the nozzle and the thrust cannot
point two ways. The view draws the nozzle straight from the channel, as the Osprey's nacelles are drawn (an eased copy
would be drawn where the thrust is not); the lift fan's door, the auxiliary inlet doors, the louvre doors and the
roll-post doors go with it, open by a tenth of its travel. THE GEAR IS EASED TOWARD THE BUS'S BIT over
`LightningAirframe.GEAR_SECONDS` (team-lead's ruling, as the Hawkeye's fold): the bit is what the physics reads, and the
doors-legs-doors cycle is drawn only -- the well doors open, the legs travel, and the doors SHUT AGAIN, each stopping short
of where its leg leaves the belly, because a door that shuts after the gear is down cannot shut across the leg. A PILOT
HOVERS WITH THE NOZZLE STRAIGHT DOWN, 90 degrees of the travel, not at the stop: at 95 the thrust leans aft by 8.7 per
cent of the weight and a hover drifts. The hover's margin is the LiftSystem's published 186 kN over 17.5 t, 1.08 g: a
vertical take-off climbs at 0.8 m/s2 flat out, and the short take-off is why the B has one. The cockpit is the fighter's
room with the side stick on the right, the nozzle lever by the throttle and the flight page on one panoramic screen;
a US16E (`PilotSeat`'s "us16e") under the pilot. How it flies is `tests/lightning_flight.gd`; what it looks like, and every
figure's source, `LightningAirframe`'s doc block and `craft/lightning/sources.md`.

**THE A-10C `warthog` (`Sim.Kind.WARTHOG`) IS AN AEROPLANE BUILT ROUND ITS GUN** (lane/warthog, 2026-09-19): kind 33 on
`Model::Airplane`, measured off Kaboldy's three-view (`craft/warthog/sources.md`, `WarthogAirframe`'s doc block).
- THE GAU-8/A is its ONE weapon station (`loadout_of`): selector 0, no weapon selector on the bus, a master arm. 3,900
  rounds a minute (a round every 1.85 ticks, carried forward as lane/jetarms fixed the M61's), 1,013 m/s, a 1,174-round
  drum on `CraftSystems::load` as the jets' drums are. THE GUN IS MOUNTED TO PORT SO THE FIRING BARREL IS ON THE
  CENTRELINE, bore-sighted 2 degrees down: the loadout's mount is the barrel's length back up the bore from
  `WarthogAirframe.gun_port()`, and `tests/warthog_seat.gd` holds every round to that drawn muzzle -- to the centimetre
  parked (1.6 mm measured), to 0.25 m in flight -- and to the drawn bore. The round is its own 30 mm row,
  `kAmmoThirty`: half the 25 mm's drag and 40 hit points a round on combat's table; the A-10 has 300 of its own.
- THE BARRELS TURN WHILE THE DRUM EMPTIES: the view reads `gun_rounds` falling, which every machine is handed, so a
  watcher's A-10 spins its gun as the pilot's does with no trigger on the wire. Drawn at 9 barrel passes a second (the
  real 65 aliases on a headset) with half a second of run-up and run-down, `WarthogAirframe.GUN_PASSES` and
  `GUN_SPIN_UP`.
- THE GEAR is eased toward the bus's bit over `WarthogAirframe.GEAR_SECONDS`, as the F-35B's: the nose well's doors
  open, the legs swing FORWARD, the doors shut. THE MAINS HAVE NO DOORS and stay HALF OUT OF THEIR PODS when up, as
  the real ones do for a gear-up landing; the nose leg is 0.40 m to starboard, because the gun has the centreline.
- THE SPEED BRAKE IS THE DECELERONS on the spoilers channel: each aileron is two halves hinged inside the aileron's own
  hinge, which the brake opens 40 degrees apart wherever the roll has the aileron; eased over
  `SPEEDBRAKE_SECONDS`. A `SpeedBrake` handle (`AirbrakeLever`) stands beside the throttle in `seat_warthog.tscn`.
- ITS WING IS SIZED THE HOUSE'S WAY: the book stall (`camber x v^2 x lift` carrying the weight) is the published 120 kt.
  Sized as a real wing first (the weight at a coefficient of 0.30 at 62 m/s), `tests/handling.gd`'s robot, which
  rotates at 1.2 of the book stall, ran 3.8 km of runway and never climbed. Flat out 385 kt against the published 381;
  91 degrees a second of roll; the brake loses 37 m/s in five seconds at idle against 16.5 clean (`tests/warthog_flight.gd`).
- Every moving part is a VAT feature -- gear, pitch, roll, rudder, flaps, speedbrake, gun -- within 0.67 mm of the
  parts off the grid with all seven moving at once (`tests/warthog.gd`).
**AN F-35B'S AMRAAMs LEAVE FROM BAYS, AND A BAY IS THE SERVER'S** (lane/lightning step 3, 2026-09-19). A bay rack's
launch opens the bay rather than firing: the server sets the side's bit on `CraftSystems.bays`, pushes the missile out
of it a second later at 8 m/s down the craft's frame, lights its motor 0.35 s after that (`MissileState.ejected`), and
shuts the bay 1.5 s after the last one leaves. The drawing only eases the doors toward the bit over
`LightningAirframe.BAY_SECONDS`, which is the server's `kBayDoorSeconds`, so the doors are drawn open when the missile
moves. It is the RACK that is in a bay, not the missile row: the same AIM-120 lights on an F-16's rail. The first fitting
failed `the_stowed_gear_is_inside_the_skin`: the bay cavity cut the belly where a stowed main leg sat, 0.85 m out. The
bay's outer edge came in from 0.90 to 0.80 m, and `each_bay_opens_on_its_own` now measures its drop as a share of the door's width
rather than as a fixed number. How a launch is held to the server's record is `tests/lightning_bays.gd`; at a quarter of real speed,
`tests/lightning_launch_reel.tscn`.

**THE TOMCAT'S WING SWEEP IS THE SEVENTEENTH BUS CHANNEL, `Sim.Channel.SWEEP` (16), and it is not physical.** Both crew
may move it -- the pilot and the RIO, who does not fly and whose operator station carries no throttle, stick or rudder
-- because `apply_command` refuses only the physical half to a seat that does not fly. It lives on CraftSystems as two
bytes, `sweep_command` (where the handles ask for; the handles show it) and `sweep` (where the wings are, walked toward
the command by the server at 12 degrees a second), so everybody outside sees the wings travel. Two crew on two handles:
the last command to reach the server wins. The wing is drawn from a VAT (`VatCasting`, `research/vertex_animation.md`)
baked from `TomcatAirframe.set_sweep`, and eased toward the bus at twice the simulation's rate.

**THE PROWLER IS KIND 29, AN `Airplane`, WITH FOUR CREW AND FOUR VAT FEATURES.** Its NAVAIR envelope, three ALQ-99
pod silhouettes, transparent canopy, cockpit scale cues and citations live in `craft/prowler/sources.md`. Seat 0 is
Pilot, seat 1 is Copilot as an explicit requested game concession (the real front-right crew member was ECMO-1), and
rear seats 2-3 are Operators. `seat_prowler.tscn` fits stick, throttle, rudder and three MFDs to both front seats; the
role fitter removes flight controls from both rear seats and retains the screens. It has no shared-throttle catalogue
flag. `ProwlerAirframe.features()` is fold, aileron, pitch and rudder in that order: the ailerons live below the fold
pivots, and `VehicleView` drives the baked VAT from the fold bus plus the live stick/rudder linkage.

### Authority is not the same question as rate

The tiltrotor answered its stick and felt like it was thinking about it, and the reason is
arithmetic rather than taste. `control_authority` is newton-metres per rad/s of ERROR, and
what it has to move is INERTIA: eighteen tonnes in a box seventeen metres long is about
480 000 kg m^2 in pitch. At the light aeroplane's sort of number a full-deflection error
bought a quarter of a radian a second squared, which is four seconds to reach the rate the
stick was asking for.

Nine hundred kilonewton-metres now, which looks absurd beside a light aeroplane's 26 000 and
is the same answer once the aircraft is weighed. And it is two questions, not one: the
authority is how hard it pushes to get what the stick asked for, and the RATES are what full
deflection asks for in the first place. Both were short, on all three axes.

Measured in the hover, where there is no airflow and the rotors are doing all of it: 1.87,
1.94 and 2.04 rad/s in four tenths of a second, on roll, pitch and rudder. THAT IS NO LONGER
WHAT IT DOES: measured again on 2026-09-15 by `tests/rotor_rates.gd`, a full step with the
nacelles up settles at 1.87, 0.70 and 0.81 rad/s, pitch and rudder reaching 63 per cent in
0.32 s, which is its handling today -- 2.0, 1.3 and 1.5 asked for against 1.6 of angular
damping (the arithmetic is under the Chinook, below).

**The airliner had the same problem and the same fix.** Nine tonnes over twenty-six metres
is about 530 000 kg m^2 in pitch, so its 105 000 bought a fifth of a radian a second squared
-- five seconds to reach a commanded pitch rate, through which the aeroplane goes wherever
it was already going. Eight hundred kilonewton-metres now, and its PITCH rate asks for
nearly double while roll and yaw stay where they are: an airliner that rolls like a light
aeroplane is not an airliner, but one that cannot raise its nose is not flyable, and those
are separate numbers. Measured, 0.39 rad/s in four tenths of a second of full back stick.

**The Chinook had it worst, and damping is the half of it the rule below leaves out.** Asked
for on 2026-09-15: "the chinook has far too little pitch/roll/rudder authority, let's make it
much more agile". Fifteen tonnes in a box sixteen metres long is 350 000 kg m^2 in pitch, and
90 000 of authority is 0.26 per second of it. Against a rate controller Box3D's
`angular_damping` is a second pull the other way, so what a held stick settles at is

    settled = rate asked * (K/I) / (K/I + c),    time constant = 1 / (K/I + c)

with K the authority, I the inertia about the axis and c the damping. At 0.26 against 2.2 the
Chinook settled at a tenth of what its stick asked for, however long it was held. The arithmetic,
with a box's inertia `m/3 (a^2 + b^2)`, came within 3 per cent of every measured rate below.

A full step at a hover, settled rate and time to 63 per cent (`tests/rotor_rates.gd`; sixty
knots reads the same, because the helicopter model has no speed term in its controls):

| | pitch | roll | yaw |
|---|---|---|---|
| Chinook before: 90 000, damping 2.2, asks 0.6 / 0.9 / 1.0 | 0.061 rad/s, 0.43 s | 0.397, 0.28 s | 0.106, 0.43 s |
| Chinook now: 1 000 000, damping 1.2, asks 0.75 / 1.1 / 1.0 | 0.527 (30 deg/s), 0.28 s | 1.036 (59), 0.08 s | 0.713 (41), 0.27 s |
| light helicopter: 14 000, damping 1.8 | 0.999, 0.17 s | 1.857, 0.07 s | 1.546, 0.17 s |
| Osprey, nacelles up: 900 000, damping 1.6 | 0.695, 0.32 s | 1.868, 0.07 s | 0.805, 0.32 s |
| ADS-33E-PRF Level 1 hover minimum, moderate agility | 0.23 | 0.87 | 0.38 |

Proposal A of three, measured through `set_handling` before any C++ was built and the same to
the third decimal after:
- **The authority is the rule below:** a million on 350 000 kg m^2 is 2.9 per second.
- **The damping is the real aircraft's:** a CH-47B's roll subsides at about 1.1 per second
  (Ferguson et al., ERF 2015). NASA TM-84351 puts its inertia at 275 000, 46 000 and
  259 000 kg m^2 at fifteen tonnes, which the box is within a third of.
- **It answers with the Osprey's weight, not the light helicopter's snap.** Roll answers in
  0.08 s, because roll inertia is a seventh of pitch's under one authority.

Rejected:
- 1 800 000 reached the same rates in 0.18 s, the light helicopter's snap and not a big tandem's;
- 600 000 with damping 1.5 settled under the floor in pitch and yaw.

`tests/rotor_rates.gd` holds the Chinook at a hover to:
- settled rates of at least 0.45, 0.90 and 0.60 rad/s;
- 63 per cent within 0.35 s in pitch and yaw;
- overshoot of no more than a tenth;
- slower than the light helicopter as measured in the same run on every axis.

It then makes the same judgement of the old handling, which must fail.

**A rule of thumb worth keeping:** for a rate controller, `control_authority` wants to be
roughly the body's inertia about that axis multiplied by the acceleration you want at full
error. Half a second to a commanded rate on 500 000 kg m^2 is order a million. Anything
sized by eye off a lighter aircraft will be an order of magnitude short and will feel like
the aeroplane is thinking about it.

**And the test needed its own client.** Spawning a second pilot for a client that already
had one left them owning two pilot entities (before lightgun S-1; now it moves their one
pilot, which is worse for a test) and the world went on reading the first, so
every input set on the new one landed on an orphan and the aircraft sat there at 0.00 rad/s
on all three axes. That trap is written down two sections further on and it still caught
this.

### The tiltrotor, which is the one genuinely new shape

Nacelles forward it is an aeroplane whose propellers happen to be enormous. Nacelles up it
is a helicopter that happens to have a wing making nothing. The interesting part is the
middle, and NOTHING IN THE CODE BRANCHES ON A MODE -- there are three continuous blends and
the aircraft is wherever they put it.

**The wing is the aeroplane's wing**, unchanged and always on. `fly_tiltrotor` calls
`fly_airplane` with `flown` false, which runs everything before that flag: the lift, the
drag, the fin, the pitch stability, all arriving exactly as they do on anything else with a
wing. In the hover the airspeed is nearly zero and the wing makes nearly nothing, which is
not a special case -- it is the same wing being honest about how fast it is going.

**The thrust swings with the nacelles, and so does its size.** A proprotor pulling eighteen
tonnes off the ground is doing something quite different from one pushing the same aircraft
along at cruise, so the magnitude blends from newtons along the nose to a fraction of the
WEIGHT along the aircraft's up.

**The controls are floored on the nacelle angle, not the airspeed.** A helicopter has full
authority at a standstill because its rotors provide it, and so does this with the nacelles
up; wind them forward and it goes back to being an aeroplane that needs airflow.

**The nacelle angle is on the COMMAND BUS**, beside the flaps and the gear, and not on the
input frame. It is a configuration: it stays where it is put, the physics reads it, and both
pilots have to see it. A tiltrotor whose nacelles were a momentary demand would fall out of
the sky the instant a packet went missing. Its rollback threshold is tighter than anything
else on that bus, because on this aircraft a tenth of the travel is the difference between
thrust along the nose and thrust holding the weight up.

An autopilot winds them forward and leaves them there. Crossing an island is the one job the
aircraft has a wing for; left at the hover it would try to do it sideways at thirty knots.

The difference is **which forces exist at all**, not their size. Expressing all of it as
one model with coefficients gives a model that is wrong for everything and tunable into
being wrong for everything, which is what the first version was.

`set_movement_model(kind, model)` changes it at runtime. It is part of the SIMULATION, like
the handling numbers and the static geometry, so every peer has to be told the same thing.

### The flight model, and why banking turns

Nothing in the simulation says "turn". Lift acts along the body's **up**, so rolling tilts
the lift vector, and the horizontal component of a tilted lift vector is a centripetal
force. The aeroplane accelerates sideways, the fin swings the nose into the new airflow,
and that is a turn.

It only works if the lift is **real**, and two things had to be right before it was:

1. **The wing has to carry the weight at a speed the aircraft can reach.** The first
   numbers were about a quarter of what was needed, so it could not hold altitude at any
   speed and rolling it simply made it fall sideways. Sized from the condition instead:
   cruise 55-60 m/s, stall 23 m/s.
2. **The wing needs camber.** Pitch stability points the nose into the airflow, which
   drives the angle of attack towards zero -- and with no camber, zero angle of attack is
   zero lift, so the more stable it was the harder it fell. A real wing lifts at zero angle
   of attack, and the aircraft then trims itself into level flight rather than into a dive.

**Spawn aircraft already flying.** One put into the air at a standstill falls, exceeds the
stall angle within a few ticks, and mushes into the ground at full power. That is correct
behaviour for a wing. `spawn_vehicle` and `spawn_pilot` take a velocity for this.

### And why the flight path follows the nose

Banking turns the aeroplane, but that alone is only half an aircraft. A tilted lift vector
accelerates the machine **across its own nose**, and unless something pulls the velocity
round to meet the heading, what you get is an aeroplane sliding sideways through the sky
still pointing where it started. That is exactly what it did.

The term that fixes it is a **fuselage side force**: linear in the sideslip, scaled by
airspeed. Sideways *drag* cannot do the job however large you make it, and the reason is
its shape -- drag is quadratic, so it is strongest where the slip is already large and
fades to nothing as the slip gets small. The last few degrees of crab never close. A
linear force is still worth thousands of newtons at two degrees.

With it, sideslip half-lives in about a quarter of a second at cruise, and the flight path
and the heading turn together.

A strong fin plus a strong side force will ring, so the aeroplane also has **aerodynamic
damping in yaw and pitch** -- torque per rad/s that grows with airspeed, which
`angular_damping` (a constant) is not and cannot substitute for.

Measured: 72 m/s level at +2.7 m/s vertical on 1.4 times its own weight in thrust;
**0.8 degrees of sideslip in the middle of a turn**; the nose swings 38 degrees and the
track swings 38.

### A bank held with the nose on the horizon barely turns, and the fin cannot fix it (lane/handling, 2026-09-17)

**The stick is a rate demand** (`apply_controls` -> `command_rate`): centred, it asks for zero pitch rate and zero
yaw rate, and `control_authority` holds both there. A level turn at bank b needs the body to pitch at w sin b and yaw
at w cos b (w = g tan b / v), so a player who banks and holds the nose level is asking the aeroplane not to turn.
`tests/handling.gd` measures it through `set_pilot_input` as "held %": the 45-degree turn's rate as a share of
g tan(bank) / v. **Before, on main 99f5a336: gunship 21, Mercury 24, airliner 30, fighter 45, tanker 49, Cessna 50,
light twin 68, Hawkeye 74.**

**`set_handling` can buy it, and the pedals pay.** A fin (`weathervane`) strong enough to out-push the rate loop drags
the nose round with the flight path: x10 gives 74-91 %, x50 gives 93-98 % on the Cessna, fighter, airliner and
gunship, with roll, take-off and landing unchanged. But the same fin fights a pedal that asks for yaw: full rudder,
wings held level, reaches **34-54 % of `yaw_rate` as tuned, 6-14 % at x10 and 1-4 % at x50**. Rejected: a rudder
that does nothing is a crosswind landing and a de-crab you cannot fly. Lower `angular_damping` (0.05) was the other
data-only lever tried: the pulled turn rises to 94 % but the held turn only to 33-44 %, and landings harden to
3.8-5.6 m/s. Lower `control_authority` (x0.2, Cessna): 69 % held, and a steep turn that loses 39 m.

**THE C++ FIX, LANDED (step 2 of `lane/handling`)**: `apply_controls` adds `coordinated_turn(h, f, share)` to what a
HUMAN's stick and pedals ask for, on a `Model::Airplane` and on the tiltrotor in proportion to its nacelles forward.
It is g tan(bank) / v about the world's up, `w = g * (-f.right.y) / max(f.up.y, 0.35) / max(f.along,
control_reference)`, taken into the body's three axes, faded out past 84 degrees of bank and below `control_reference`,
scaled by the kind's `turn_coordination` (1 for everything today). `hold_the_turn` feeds forward what the body's
`angular_damping` (times the inertia about each axis) and the airflow's `pitch_damping` and `yaw_damping` (times the
airspeed) take off that part, because a proportional `command_rate` settles at `K/I / (K/I + c)` of what it is asked --
the airliner's pulled turn read 63-65 % for that. **Stick feel is untouched**: the stick's own rates keep the loss every
per-kind rate was tuned through. **Humans only**: `AircraftMixer` already feeds the load factor forward and closes the
slip on the rudder, and every formation is tuned on that. The helper reads nothing a wing has, so `fly_helicopter` can
call it unedited (`lane/rotors`' option b).

Measured, main 236a41dc against the lane: **"held %" 21-74 to 100 for every aeroplane** (the Osprey's wing 4.9 deg/s of
an ideal 5.0), **"rudder %" where it was** (Cessna 34 and 34, gunship 41 and 42, Mercury 50 and 50, airliner 35 and 33;
the fighter's 54 to 44 is its new speed), take-off, stall and landing unchanged on every aeroplane.

**AND A g LIMIT PER KIND (`g_limit`)**. The stick asked for `pitch_rate` whatever the speed and every wing here lifts
many times its weight at speed, so a one-second full pull at top speed was **fighter 22 g, light twin 17, Hawkeye 11,
Cessna 6** ("yank g"). `pitch_demand` now holds the pitch rate asked for -- stick and turn together, because that is
the load -- under `g_limit * g / v`: falcon 9, fighter 8, tomcat 7.5, Cessna, light twin and glider 5, Hawkeye 4, Osprey 3.5,
airliner, Mercury, gunship and tanker 3. Measured after: fighter 8.4, Cessna 4.2, heavies 2.1-2.9. It does not fight the
turn: 70 degrees of bank asks 2.6 g by itself. **It does change what a full pull feels like on a heavy**: `smoke`'s
`an_airliner_can_raise_its_nose` read 0.13 rad/s against a typed 0.35, because at 80 m/s 3 g is 0.37 rad/s asked, not
1.1; the check now asks the handling table what the stick may ask at that speed.

**THE ROBOT FLEW WITH ITS GEAR DOWN, and the gear was most of "the speed order is upside down".** `gear_drag` is 11
against the fighter's `drag_forward` of 8.5, so 196 kN met drag at 100 m/s; the review read 104. Gear up (the robot
now sends GEAR 0 once 30 m clear and GEAR 255 before the stall), the fighter does **157.5**, the Hawkeye 166, the
light twin 166, the airliner 112, the Mercury 116, the tanker 108, the gunship 105 and the Cessna (fixed gear) 68.
Still the wrong order, and rebalanced in step 2 (`craft_review.md`, "Handling, measured and proposed"): fighter and
tomcat 221, Mercury 142, Hawkeye 140, airliner 133, light twin 96.

**THE FASTEST WING SIZES THE WORLD, so "faster" has a ceiling.** Every level's soft edge is as deep as the widest turn
any powered wing needs at its top speed on its own autopilot's bank (`turn_radii`: v^2 / g tan bank), and a level whose
placed reach plus 2 km plus two of those turns passes the wire's last resort (32.3 km) is refused on loading. Alpine's
placed reach is 22.3 km, which leaves **3.97 km for the widest turn**. The first rebalance -- fighter 238 m/s, airliner
146 -- made the airliner's turn 4,331 m (its autopilot banks only 0.44 rad) and the fighter's 4,285, and alpine was
refused in four suites at once (`terrain_level`, `level_swap`, `ship_legs`, `seabed_alpine`).
Now 3,688 and 3,609. A faster craft needs a smaller level, a steeper autopilot bank, or a new rule for the band.

Three harness traps paid for on the way, all now in `handling.gd`: **a bus command on sequence 0 is dropped** (a fresh
world has seen 0, and the robot's counter wrapped through it across craft, so the airliner and Hawkeye never raised
their gear in the fleet run and read 88 and 121); **the wire's edge is 32 km out** and `guard_the_wire_edge` zeroes
the velocity across it, so a Hawkeye flying north for ten minutes lost its airspeed at 1,021 m and fell (the long legs
now fly home); and **a full-stick level turn cannot be flown by a proportional robot** -- the fighter went over the
top and "turned 360" in 5.9 s by counting half-loops -- so the table's turn is a 70-degree pulled 360, and the pull is
measured as a one-second yank instead.

### The stick does nothing to an aeroplane at a standstill (lane/groundroll, 2026-09-18)

**A control surface is a small wing, and it pushes with the dynamic pressure over it**, one half rho v squared: none
at a standstill. `lane/tomcat2` found a scripted stick standing a parked F-14 on its back on the reel's stage, and
worked round it with invisible walls. `tests/ground_stick.gd` parks every aeroplane on that stage (a static floor
400 m up), on the sea-level slab and, for the two flying boats, afloat, and works full stick and pedal through
`set_pilot_input`. **On main bd43f201's library, from 0 m/s on the stage: fighter 180 degrees of bank, Tomcat 179.8,
Falcon 179.6, light aeroplane 180, Savoia 90; afloat, the Savoia 179.8 and the water bomber 84. On the slab: 0.00 for
every aeroplane.** That split is what showed the two causes:

1. **`apply_controls` kept a 12 per cent FLOOR** under the surfaces' authority whatever the airspeed. A wing's bite is
   now `surface_bite`, `min(1, (v / control_reference)^2)`, with no floor. A rotor's and a pod's push with their own
   thrust, so they keep the old linear fade and its floor, now `thruster_bite`; `rotor_turn`, `rotor_hold` and
   `rotor_rates` are unchanged.
2. **The taxiing branch asked for a HEIGHT against the terrain map.** `fly_airplane(..., taxiing)` is where the stick
   does nothing and the rudder is a nosewheel, and it was `grounded && touching`, where `grounded` is "below
   `ground_height` over what the map says is underneath". On a floor the map does not know, such as the reel's stage,
   a roof or a test's raised slab, a craft on its wheels got the flight controls. It is now
   `touching && short_of_flying`, the wheels' own ray. **The first fix alone was not enough**: at 5 m/s on the stage the
   fighter, the Tomcat and the Falcon still rolled over, because 4.6 MN*m per rad/s x (5/24)^2 x 2.25 rad/s is about
   449 kN*m of servo torque, against 22 t x g x 1.15 m = 248 kN*m of weight across the fighter's hull. `grounded` keeps
   the deck spring it was written for.

After: 0.00 degrees parked on the stage and the slab for every aeroplane, 0.2-0.3 afloat, which is less than the swell
does hands off (0.7 and 1.5), and 0.00 at 5 m/s on wheels. `handling` on both libraries: **held %, pulled %, the steep
360, yank g, rudder %, every top speed, every take-off and every climb identical**. Only what is flown under 24 m/s
moved: the water bomber's power-off stall went from 19.1 to 19.2 m/s, and landing roll-outs moved by 0 to 3 m.
`water` and `savoia` pass unchanged. **`water_rudder` passes, but its circles afloat are slower**, because the fin helped
the water rudder at taxi speed through the old linear fade, and squared it gives about a quarter of what it did at 6.5 m/s (0.073 against 0.27):
the water bomber went from 27.1 s to 29.6 s (band 20-40) and **the Savoia from 15.2 s to 23.9 s** (band 10-30). That is
the physics, but the user wanted the Savoia nimble on the water. If that wants back, raise the water rudder
(`kWaterRudderRate`, shared by both, or per kind), not the fin.

**REJECTED, measured: afloat as taxiing.** Treating a hull the sea holds up, below `ground_speed`, like wheels on a
runway took the stick away for the whole take-off run up to 52 m/s. `tests/water.gd`'s water bomber then skipped: off
the sea at 37.6 m/s, back on it 1.3 s later, and off again at 43.3. It was reverted. **So a held full stick while
taxiing afloat at 5 m/s still rolls the Savoia over (179.6 degrees) and the water bomber 20**, which `ground_stick`
reported but did not hold. The reason was the water model, not the stick: `alight` cancels the probes' capsizing moment
and leaves the hull only neutrally stable in roll. Fixed by the wingtip floats, below.

### A flying boat stands on its wingtip floats (lane/floats, 2026-09-18)

**Every hull with `floats` in its `Shape` gets a buoyancy point at each float's keel** (`WingFloat`,
`float_the_wingtips`, called from `alight` once the hull is wet). Each point samples the sea where it is, as the hull's
probes do, and pushes up with its drawn volume of sea water (`kSeaWeight`) times the share of its height that is
under, so it is a spring whose travel is the float. It is damped at the point by `kFloatDamping` (0.5 N s/m per N of
lift). The Savoia's floats are 0.286 m^3 each, the six drawn rows integrated as ellipses, 3.25 m out. The water
bomber's are 0.393 m^3 at 0.79 of its half-span.

- **Measured, `ground_stick`, full stick held at 5 m/s afloat:** the Savoia goes from 179.8 degrees (on its back) to
  10.0 from level, and the water bomber from 12.8 to 3.0. With the floats taken away (`float_lift` 0, the suite's own
  mutant row) both go back to what main did, and that row must fail the held one.
- **Both floats go all the way in.** The Savoia's float is buried at 9.3 degrees of bank and the water bomber's at 1.3.
  The stick at 5 m/s is still far stronger than an aileron at that speed can be (gap 1, below): a real aileron's moment
  at 5 m/s is tens of N m, and the rate servo's is kN m. Doubling the floats only takes the Savoia from 10 to 7.7
  degrees, and quadrupling takes it to 4.7. They are left at their drawn size. **The fix for the rest is the controls as
  surface moments, not bigger floats.**
- **One number, one place.** The water bomber's view now draws its floats from `kind_geometry`'s `"floats"`, which are
  the physics' own. The Savoia's airframe draws its floats from its own constants, so `tests/savoia.gd`'s
  `the_sea_pushes_on_the_floats_where_they_are_drawn` holds the two within 3 cm.
- **At rest, the water bomber's floats are 0.31 m under**, because the drawn float hangs below the derived waterline.
  They carry 4.4 kN of its 167 kN, which puts the hull 1.6 cm higher. The Savoia's keels are 2 cm clear, as its
  drawing says.
- **Rejected:** afloat as taxiing (above), and a roll moment from the hull's beam with no float behind it. That moment
  would be a number the drawing does not show, and it would not care which wing had a float in the water.

### The flight model, as found (2026-09-18, for the realism lane)

**Since lane/flightmodel, a kind can fly on its lifting surfaces instead: see "An aeroplane on its surfaces" below.**
What follows is the lumped wing and the rate servo, which every kind but the Cessna still flies. **The Cessna is on its
surfaces by default since lane/cessnafm** (`--set=surfaces=0` flies it lumped, for an A/B).

Everything is in `ashiato-gd/src/cockpit/cockpit_world.cpp` unless named otherwise. Line numbers drift, so search for
the names.

**Per tick, per vehicle: `drive_vehicle`.**
1. **The frame (`Frame f`)**: pose, velocity, spin and mass off Box3D. `air_at` gives the air's velocity (the wind by
   height, `wind_at`, plus thermals, `rising_at`; wings and rotors only). `f.along`, `f.sideways`, `f.vertical` and
   `f.speed` are the AIRFLOW on the body's axes, not the ground speed.
2. **What is underneath**: `deck_under` gives the surface height from the terrain map, or a ship's deck with its
   velocity. `touching` is a ray from the hull's middle, `hy + kWheelReach` (0.6 m) down (`stands_on_something`).
   `grounded` is `on_the_ground`: under `ground_height` over the map's surface AND slower than `ground_speed` relative
   to it.
3. **Drag on the three body axes, for everything**: quadratic, with `drag_forward` (+ `brake_drag` as an airbrake off
   the ground), `drag_side` and `drag_vertical`, each clamped by `resist` never to reverse what it opposes.
4. **Who flies**: an autopilot through `fly_itself`, whose wing is `AircraftMixer` in `autopilot.hpp` (height through
   climb rate through the stick, heading through bank, speed through the throttle, slip through the rudder) and whose
   ground roll is `take_off`. Or a human, through the linkage (`settled()`), the lever and the trim wheel
   (`kTrimAuthority`, added to pitch).
5. **`turn_back_from_the_edge`, `guard_the_wire_edge`**, then **`roll_on_wheels`**: side grip, rolling resistance and
   brakes, all at the centre of mass; chocks when nobody is aboard; a belly slide with the gear up; a deck spring.
6. **The model**: `fly_airplane`, `fly_helicopter`, `fly_tiltrotor` (which calls `fly_airplane` with `flown` false for
   the wing), `hover_pod`, and for amphibians `alight` after the flight model.

**`fly_airplane`, the forces**, all at the centre of mass and only above 1 m/s of airflow:
- **Lift** along body UP: `(aoa + camber + flaps * flap_lift)`, linear to `stall_angle` and then falling away (never
  under a quarter), `x along^2 x lift`. `along` is the airflow along the nose, not the total.
- **Hanging drag**, `q x (flaps * flap_drag + gear_drag + spoiler_drag)`, and **induced drag**, `coefficient^2 x q x
  induced_drag`.
- **Fuselage side force**, linear in the slip: `|sideways| x airspeed x side_lift` (see "And why the flight path follows
  the nose").
- **Thrust** `throttle x thrust` along the nose: constant with speed and height.

**`fly_airplane`, the torques**:
- **Weathervane** (the fin): `-sideways x airspeed x weathervane` about up. **Pitch stability**:
  `-aoa x q x pitch_stability` about right.
- **Aerodynamic damping** in yaw and pitch, `rate x speed x yaw_damping / pitch_damping`. **There is none in roll**:
  roll is damped only by Box3D's `angular_damping`, a constant.
- **The controls: `apply_controls`, RATE COMMANDS, not surface moments.** Each axis asks for a body rate (stick x
  `pitch_rate` / `roll_rate` / `yaw_rate`, plus `coordinated_turn` for a human) and `command_rate` pushes
  `gain x (wanted - rate)`, clamped to what would close `kRateSettle` of the error in one step through the body's own
  inertia. The gain is `control_authority x bite`. `hold_the_turn` feeds forward what the damping takes off a turn's
  rates, and `pitch_demand` holds the pitch rate under `g_limit x g / v`.
- **On the wheels (`taxiing`)** there is no stick at all. The rudder is `steer_on_the_ground`: a nosewheel's commanded
  yaw rate (`ground_steer`, settling in `kNosewheelSettle`) blended to the fin's by a LINEAR `speed /
  control_reference`.

**Per-kind numbers**: `struct Handling` (search `struct Handling {`) with defaults, overridden per kind in the big
switch on `kKind*` below it. Airframe mass, box half-extents and stated inertias are in each `*_shape()`
(`fighter_shape` and the rest). All of it can be read and written at runtime through `handling(kind)` and
`set_handling(kind, dict)`, which `tests/handling.gd -- --set=key*2` and `tests/ground_stick.gd -- --set=` use. The book
stall is derived, not typed: `stall_speed()` is `sqrt(m g / (camber x lift))`. So is the autopilot's cruise
(`default_cruise`).

**What is physical, and what is not:**
- **Physical in shape**: lift, induced drag and the hanging drags go with the dynamic pressure; the side force and the
  fin with the airspeed; the stall falls away; bank turns the aeroplane with nothing saying "turn". The coefficients
  are lumped per kind in newtons per (m/s)^2 per radian: there is no wing area, no rho and no Cl.
- **Not physical: the controls.** They are rate servos whose gains are tuned for feel. The fighter's 4.6 MN*m per rad/s
  of error is tens of times any real aileron moment, and in the air the servo only ever uses what it needs, so
  nobody sees it. **Against a constraint (the ground, the water, a pen) it pushes with everything it has.** That is
  the whole of today's bug, and why the fix was to take the controls away wherever the wheels are down.

**The obvious gaps, most to least visible:**
1. **The controls are a rate servo, not surface moments.** A realism pass would make each surface a moment of
   `q x (control power) x deflection`, with aerodynamic damping on every axis, and let the rate be what comes out.
   `handling`'s held %, rudder % and yank g are the numbers to hold while doing it.
2. **`control_reference` is 24 m/s for every aeroplane**, so a fighter's surfaces are at full authority at 24 m/s.
   `surface_bite` fades them below that; above it they are saturated.
3. **No rotation on the take-off roll.** The stick is dead while `touching` and below `ground_speed`, which is ABOVE the
   flying speed (fighter 78 m/s). Every aeroplane leaves the runway on camber lift alone once the wing unloads the
   wheels, and only then gets its stick; `ground_stick`'s "at rotation speed" line is really the lift-off. The light
   twin rotating at 66 m/s (`../../learnings/2026-09-17-handling.md`) is this and the book stall together.
4. **No roll damping or dihedral**, no adverse yaw, no sideslip in the lift, and a symmetric stall with no wing drop
   and no spin.
5. **No air density**: nothing changes with height. Thrust is constant with speed and height.
6. **The gear is a box on a floor.** There are no legs, oleos or track width: the hull's half-width is what resists
   tipping, the wheel forces act at the centre of mass, and there is no ground effect.
7. **Afloat, the hull alone is neutrally stable in roll, and the wingtip floats hold it** (lane/floats). They are
   points on a capped spring, with no drag of their own and no spray.
8. **`steer_on_the_ground`'s nosewheel-to-fin handover is linear** in speed, where `surface_bite` is squared. It was
   left alone because `water_rudder`'s land rate is held to three places.
9. **`on_the_ground` (the height against the map) still decides the deck spring and `fly_itself`'s "still on the
   ground"** (with `f.on_wheels`). A raised floor the map does not know is now taxiing to the flight model, but only the
   wheels' ray says so to the autopilot.

### An aeroplane on its surfaces (lane/flightmodel, 2026-09-18)

**PUTTING ANOTHER KIND ON ITS SURFACES? READ `research/real_wing_playbook.md` FIRST.** It is the method that took the
Cessna across (the book, the job, one kind at a time in four steps, priced before the flip), with every trap in one
list and the fleet's planned order. This section is the mechanism.

### A helicopter on its rotor disc (Little Bird, 2026-09-19)

**The Cessna method, for a rotor.** Helicopters were out of the surfaces work. The Little Bird now flies on
`ashiato-gd/src/cockpit/rotor_disc.hpp`: momentum theory, Glauert inflow, Cheeseman–Bennett ground effect, a
vortex-ring envelope, and a quasi-steady autorotation. Thrust still acts along the mast. What changed is its
**magnitude**, which was `mass * g * collective` in every phase, with climb and cruise capped by typed drags.

Behind `Handling::rotors`, default **on** for the Little Bird only -- the same shape as the Cessna's `surfaces`.
`--set=rotors=1` is the disc (a no-op on this kind, the enable for an A/B); `--set=rotors=0` is the old thruster,
the climb check's mutant. `TuningCard` clips it on both worlds at `Sim.start`, so a windowed run takes
`-- --set=rotors=0 --kind=littlebird` the way `tests/handling.gd -- --kind=cessna --set=surfaces=0` does.
Other helicopters are unchanged. Plan: `research/littlebird_rotor_plan.md`. Book suite: `tests/littlebird_book.gd`.
The job is `tests/littlebird_circuit.gd` and `tests/littlebird_flight.gd`. The reel is `tests/littlebird_circuit_reel.gd`.

There is no rotor RPM on the wire. A flare that stores blade energy is not here yet.

The plan and its measurements are `research/flight_model_plan.md`, and the prototype that measured it is beside it.
The model is `ashiato-gd/src/cockpit/lifting_surfaces.hpp`. It is pure, with no Box3D, so a prototype can include it.
**Step 1 put the Cessna on it behind a switch that was OFF, and lane/cessnafm switched it ON by default** (2026-09-19,
+75 ns an aircraft a tick at 1,000 Cessnas, bracketed): `Handling::surfaces`, flown with
`tests/handling.gd -- --kind=cessna --set=surfaces=1`, and held by `tests/surfaces.gd`.

**What it is.** Two wing panels, a tailplane and a fin. Each works out its own lift and drag from the air where it is
(the mass centre's velocity plus the spin crossed with its arm). The stick moves the surfaces. Stability, damping on all
three axes, adverse yaw, the dihedral effect, a wing that drops at the stall and a nose that rotates on the take-off
roll all come out of that, and nothing types any of them. `fly_on_surfaces` evaluates the surfaces once with the flaps
where they are and the stick centred, adds the stick through each surface's own travel, and hands Box3D ONE force and
ONE torque. A human's stick is the surfaces, blended toward the control law by `augmentation` (0 is cables, 1 is
fly-by-wire). An autopilot always asks the law for a rate, which is the interface `AircraftMixer` was tuned on. The
law is dynamic inversion through the surfaces, clamped to full travel and stateless, so a replay computes what the
first pass did.

**How a kind gets surfaces.** A case in `planform_of`, every number read off the kind's airframe in its own units
(stations aft of the nose, heights over the ground at rest). Then `clmax` and `flap_clmax` in `default_handling`,
which set the stall. `aero::build_wing` derives the rest:
- the lift slopes, from the aspect ratios;
- the downwash;
- the centre of gravity, a `static_margin` of the mean chord ahead of the neutral point the surfaces make;
- the tailplane's incidence, by trimming level at the cruise the autopilot will fly (`trim_the_tail`);
- what the body keeps of `drag_forward`, `drag_side` and `drag_vertical`, so the top speed does not move.

`stall_speed()` becomes sqrt(2 m g / (rho S CLmax)), and the autopilot's cruise follows it. `lifting_surfaces(kind)`
reports all of it for a suite. It is deliberately NOT in `kind_geometry`: a new key there re-hashes every craft package
(lane/floats).

**Measured, the Cessna** (`tests/handling.gd`, off against on):
- take-off: 7.3 s and 202 m, against 5.6 s and 127 m;
- top speed: 67.8 m/s, against 66.8;
- full-stick roll: 113 deg/s, against 89;
- the 45-degree turn held on the horizon, raw: 100 per cent, against 100;
- a full pull: 4.2 g, against 5.8. Raw has no g limit; the airframe's is structural.

On surfaces, the published flaps-down stall is flown to 4 per cent (23.8 m/s against 22.9, and 27.1 clean against the
book's 26.1): what is left is the tail's download at the stall, which a real aeroplane's published stall includes too.
The roll rate doubles from 30 to 60 m/s (39 and 77 deg/s). The prototype's cost: 70 ns per aircraft per tick for today's arithmetic,
113 ns for four surfaces and the law, with 15 Box3D calls down to 3.

**In the game**, in a MEASUREMENT slot on a quiet machine,
`tests/rota_probe.gd -- --counts=1000 --blocks=4 --kind=cessna --set=surfaces=0|1,cruise=62.8`, bracketed off, on, off,
on. The two models are pinned to the same cruise; the off runs agreed to 0.006 ms. At 1,000 autopilot-flown Cessnas:
- the whole tick, untimed: 1.702 and 1.708 ms off, 1.734 on. **+26 ns of tick an aircraft.** (A second on-run, 1.743, is
  void: another lane's Godot started between runs.)
- the forces: 384 and 386 us off, 443 on. **+57 ns an aircraft**, against the prototype's +43 and the plan's +250 budget.
- the Box3D step: 661 and 654 us off, 649 on, which is noise.

**THE FIRST A/B SAID "8 PER CENT FASTER", AND IT WAS THE SPEED.** Unpinned, the surface Cessna's autopilot cruised at 37.9
m/s against the lumped one's 55, and the Box3D step fell from 637 to 446 us, with the tick 1.53 ms against 1.67. At the
same 62.8 m/s the step is the same. Shorter continuous-collision sweeps at the lower speed were the whole of it. Price a
flight model at the same speed as the one it replaces (`Handling::cruise` pins it), or the sky's speed is what you have
measured.

**The traps, each paid for once:**
- **The mass centre has to move to the centre of gravity.** The hull box's middle is not it: the Cessna's box is centred
  4.14 m aft of the spinner, and its centre of gravity is at 2.47. Surfaces taken about the box's middle put the wing
  1.67 m AHEAD of the pivot, and that aeroplane flips over backwards. `weigh_as_an_aeroplane` moves it. Box3D keeps the
  pose at the origin and the velocity at the mass centre, and `drive_vehicle` and `read_from_physics` already read and
  write exactly those. REJECTED: moments about a separate aerodynamic reference point, which makes the aeroplane rotate
  about one point while its air says another.
- **The inertia has to be the aeroplane's.** A box's is a uniform bar's with no wing in it: the Cessna's box is 5,975
  kg m^2 in pitch and 454 in roll, against about 1,900 and 1,300 from component masses. Aerodynamic roll damping on a
  box's roll inertia is a time constant of a tick or two. The prototype's glider on its box answered inside one tick.
  `tests/surfaces.gd` holds the roll time constant over three ticks.
- **A box cannot rotate on its wheels.** The first build never left the ground at 65.8 m/s. Nose-up had to pivot the
  whole box about its back corner, 5.8 m behind the centre of gravity, and no tailplane lifts that. The lumped wing
  never met this, because it lifted off at zero angle of attack. On surfaces the hull's underside rises aft of the main
  wheels to the tailcone (`Planform::mains_station`, `tail_underside_height`), so the aeroplane pivots on its mains
  and the tail touches at about 7.7 degrees.
- **A robot that flies a rate stick cannot fly a raw one.** The handling robot's pitch gain is scaled by the kind's pitch
  RATE, which a surface has none of, and it has no trim. The raw Cessna "could not hold its height below 34.9 m/s". A
  trace of the same aeroplane under a firmer hand broke at 26 m/s and 16 to 18 degrees of alpha, its stall.
  `handling.gd` now gives a stick that is a surface an elevator-sized gain and a trimming integral (`K_PITCH_SURFACE`,
  `K_TRIM`). Its power-off stall line still reads 32 m/s, because it slows from 66 m/s at the game Cessna's drag, and
  `tests/surfaces.gd` flies the stall at a metre a second per second instead.
- **A stall is where the WING gives up, not where the hand does.** `tests/surfaces.gd`'s first flown stall read 25.2 m/s
  with flaps and 28.1 clean, and a trace showed neither run stalled: its raw hand let the nose lag through the
  slow-down, and the aeroplane was sinking at 2 m/s at alpha 10.9 and 12.8 degrees against a stall at 15.8. Flown
  through the control law (which can never beat the air) and counted only with alpha at the stall, it is 23.8 and
  27.1. That was also the prototype's "flaps lower the book stall and not the flown one".
- **Adverse yaw is measured as sideslip, not heading and not body yaw rate.** A heading over half a second sees the turn
  the bank starts, and the body's own yaw rate goes TOWARD a roll by p tan(alpha), because an aeroplane rolls about its
  flight path. Rolling right, the Cessna slips 1.29 degrees from the right in the first 0.4 s, and the old rate servo
  0.17.
- **The stall break is measured as lift.** A nose that falls with the stick held back also falls with no break at all,
  as the speed decays. The suite takes CL from the body's own acceleration, and it falls from 1.32 to 0.84 as alpha
  passes the stall. The mutant that holds CLmax past the stall keeps 1.34.
- **A name can already be taken.** `wings_` was the F-14's sweep map, so the surface table is `surface_tables_`.

**Still open:** the autopilot on surfaces is step 2, and the rest of the fleet is step 3.

#### The surface Cessna against its POH (lane/cessnafm, 2026-09-19)

**NOT YET FLOWN IN A HEADSET.** As of 2026-09-19 the user has not flown the surface Cessna by hand in VR (lane/flightmodel's
open question 1). Everything below is a robot, a suite and the autopilot. The other kinds stay on the lumped wing until
the user has seen the Cessna fly the pattern (the user's order); the roll-out plan is in
`../../learnings/2026-09-19-cessnafm.md`.

`tests/cessna_book.gd` flies it against the 172S POH, scaled from 2,550 lb to the game's 1,000 kg. Each line is the book,
then the first surface model (lane/flightmodel), then this one:

| | book | first surface model | now |
|---|---|---|---|
| **autopilot turn, rate / (g tan bank / v)** | 1 | 0.99 (lumped: **0.54**) | **0.99** at 20, 30 and 45 degrees |
| top speed | 126 kn | 130 | 126 |
| climb at Vy, 74 KIAS, full throttle | 4.3 m/s | **21.8** | 4.5 |
| glide at 68 KIAS, idle, by energy | 9.1 to 1 | **3.4** | 7.5, and it always loses energy |
| take-off roll, 10 degrees of flap | 219 m | 198 (lifting at 48.6 m/s) | 337, lifting at 28.9 |
| full aileron at 50 m/s, pb/2V | 0.07 to 0.09 | 0.125 | 0.087 |
| stall, clean and full flap (`surfaces.gd`) | 26.1, 22.9 | 26.1, 23.8 flown | the same |

**THE TURN WAS NEVER THE SURFACES' PROBLEM.** The same autopilot that turns at 0.54 of its bank's rate on the lumped wing
turns at 0.99 on the surfaces with nothing in the mixer changed. The lumped wing's rate servo asked the autopilot's rates
against its own typed damping, and a steady turn's yaw and pitch rates settled short of what the bank needed. The control
law inverts through the surfaces' own moments, damping included, so it gets the rate it asks for.

**THE LUMPED CESSNA'S DRAG AND THRUST WERE FIVE TIMES A REAL ONE'S**, and the surface model kept both so that the top
speed would not move: 9 kN at every speed against `drag_forward` 2.0, a CD0 of about 0.2. So it climbed at 4,300 ft/min
and glided like a brick, with a top speed that looked right. On surfaces the Cessna now takes its drag and engine from its
planform (`Planform::cd0`, `thrust`, `thrust_gone_at`, `flap_cd`), none of which touches the lumped wing:
- CD0 0.036;
- a fixed-pitch propeller, 2.5 kN x (throttle - v / 185 m/s), which is the line through the book's top speed and its
  climb at Vy. Closed, it windmills, and that is the glide's 7.5 against the 11.8 of a propeller that made no drag;
- full flap adds 0.05 to CD0. The lumped `flap_drag` of 3.0 was 3,700 N at 35 m/s.
The autopilot's climb budget (`sustained_climb`) and `flat_out` ask the same propeller.

**THE CRUISE IS 110 KN, NOT 122.** 122 kn is the 172R at 8,000 ft, and this model has no density with height. On the
propeller at sea level 122 kn is 93 per cent throttle, which left the autopilot 0.4 m/s of climb. The POH gives about
111 KTAS at 2,000 ft on 74 per cent power.

**THE AILERONS ARE AT 0.7 OF A QUARTER CHORD'S EFFECTIVENESS** (`aileron_tau` 0.315), for the full 20 degrees that a
plain flap delivers less of past about ten. At 0.45 it rolled at pb/2V 0.125.

**THE TAKE-OFF IS LONG BECAUSE OF THE DRAWING, AND THE DRAWING IS RIGHT.** The POH lifts off at 51 KIAS, a CL of about
1.6 and so about its own stall, nose high. Rotated about its mains, the drawn tail (RUDDER_TE's foot, 0.735 m up at
7.64 m, measured off [IM]; the tie-down ring under it would touch at 8.67) touches at 8.55 degrees, a CL of about 1.0 with
ten degrees of flap. So this Cessna lifts off at 1.1 x its stall, after 337 m against the book's 219. The acceleration is
the book's. The check allows 1.7 of the book and says why. **The collision hull had it at 7.6**: its ramp put the
rudder foot's height at the box's end, 0.64 m aft of the foot. `Planform::tail_underside_station` now names the drawn
station, and the ramp runs from the mains through it.

**A RATE ASKED OF THE LAW CANNOT ROTATE AN AEROPLANE ON ITS WHEELS.** The ground holds the pitch rate at nothing, and
the law does not know that the ground is there, so it only ever makes the moment its settle time asks for. The first
take-off, with the book's hand on a rate stick, did not rotate until 33 m/s and lifted off at 43.9 after 704 m. A
pilot's raw stick rotates it. The autopilot's `take_off` asks for 0.54 rad/s, which saturates the elevator, and it
lifts off 561 m down `traffic_pattern`'s 900 m runway.

#### The autopilot on the surface Cessna's propeller (lane/cessnafm, step 2)

`tests/traffic_pattern.gd -- --set=surfaces=1 --kind=cessna` passes every check. Four things had to change, and three of
them were one number the lumped wing's constant thrust had hidden: **the autopilot's climb budget, sized at cruise.**
- **Its climb.** `gentle_climb` takes what the engine holds at cruise, and a propeller has little left there: 1.5 m/s at
  110 kn against 4.5 at Vy. `engine_climb` takes it at the best-climb speed (`best_climb_speed`, 40.0 m/s against the
  POH's 38.1). And the mixer allowed none of its climb below `cruise_speed`, which on a propeller is now that Vy: it had
  climbed out at 0.8 m/s at 41 m/s and never reached pattern height inside 420 s.
- **Its descent.** The mixer's steepest descent was its climb budget (`altitude_outer.out_min`), so at 1.5 m/s it flew
  its final at 2.4 degrees and floated 2.8 km down a 900 m runway. `AircraftMixer::max_descent_rate`, zero (the climb's)
  on every other kind, is three quarters of the idle sink at the base speed (`idle_sink`): 3.8 m/s. Given the climb
  angle's 5.65 m/s instead, it could not hold its speed at idle, the flaps came out as a speed brake, and the lift they
  added set the climb loop hunting between 0.2 and 5.8 m/s of sink on base.
- **Its circuit is sized on the book's turn.** `AirportTraffic.turn_expected` is 1 for a kind on its surfaces before the
  gauge has read it, where `TURN_UNKNOWN`'s 0.5 turned final 548 m out for a 212 m turn.
- **A straight final.** `TrafficPattern.FINAL_STRAIGHT`, 300 m before the join: with the final turn ending AT the join,
  the full-rate turn rolled out 35 m wide and reached the gate 24 m off, over the 22.5 allowed, still converging on its
  carrot. It is geometry and so every light aeroplane's circuit: the lumped Cessna's arrival reaches its gate 5.4 m off
  where it was 19, and the descent is 519 fpm, where a quarter mile made it 484, under the handbook's 500.

The surface Cessna's circuit: downwind within 1.3 m of pattern height, the gate 15.4 m off the centreline at 35.0 m/s
against 35.3, a 3.01-degree final, touchdown 279 m in at 1.03 m/s down and 34.0 along, lift-off 561 m in, and the pattern
height 4.5 km out on the climb.

### A TAILDRAGGER ON ITS THREE WHEELS: the P-51D `p51` (lane/warbirds2, 2026-09-19)

The user: *"finish the p-51, p-47, p-38 and b-17. Make sure they fly well, since some are tail dragger aircraft you'll
have to make sure to handle that correctly."* `Sim.Kind.P51` is kind 35. It is the first warbird with a kind, the first
taildragger here, and the first kind born on its lifting surfaces rather than moved onto them. Its book, its sources and
its fit are in `research/warbirds_book.md`, and each figure's provenance is in `research/warbirds_sources.md`.

**A TRICYCLE'S WHEEL FORCES ALL ACT AT ITS MASS CENTRE (`roll_on_wheels`), and on a taildragger that model cannot
misbehave.** Nothing it does turns or pitches the aeroplane, so it can neither ground-loop nor nose over. A test that it
does neither would pass whatever was built. So a taildragger's wheels push WHERE THEY ARE (`roll_a_taildragger`,
`aircraft_tyre`), and the two things every tailwheel pilot is taught come out of the geometry with nothing typed for
either:
- **the ground loop**: the mains are ahead of the centre of gravity, so their grip against a skid swings the nose further
  into it;
- **the nose-over**: the brakes act at the tyres, under the centre of gravity.

It is scoped by a DERIVED test, never a flag. `aero::build_wing` calls a planform a taildragger when the centre of
gravity its static margin places is aft of its drawn mains. Every tricycle, the Cessna included, goes on exactly as
before: `tests/taildragger.gd` insists the P-51 is one, and the Cessna's suites print what they printed.

**What a taildragger has, each read off its airframe class (`planform_of`):**
- **A keel hull.** The collision hull's underside rises aft of the mains through the drawn tail wheel's tyre, so it rests
  at the drawn three-point rake: 12.95 degrees, against `P51Airframe.parked()`'s 12.99. It rises forward to the
  propeller's disc, so pitched 7.6 degrees nose down it meets the runway with its propeller. The mains' edge is the
  track wide, not the fuselage.
- **Its wheels where they are**: each main a slip-angle tyre (the car's) at half the track either side, gripping up to
  `kTyreGrip` of its load. Differential brakes: the rudder's side brakes, since a player has one brake lever. The tail
  wheel holds only while the ground is under it (a ray, never the map), steering `tailwheel_steer` (6 degrees on the
  P-51) with the stick at or aft of neutral, and castoring with it forward (AN 01-60JE-1). No nosewheel servo.
- **Issued at its rake** (`spawn_vehicle`), so it does not fall onto its tail the moment it exists.
- **The landing rule's attitudes from its drawing** (`touchdown_of`). The nose is the propeller's 7.6 degrees, not a
  nosewheel's 10. The tail is the rake plus 5 degrees, so a three-point landing is a landing. A taildragger on its wheels
  pitched onto its propeller's line has "nosed over, the propeller into the ground".
- **The propeller's slipstream over the tail** (`aero::slipstream`, `Planform::prop_disc`): 2 T / (rho A) added along the
  tailplane's and the fin's chord, in the share of each inside the wash. It is why a taildragger can raise its tail at a
  walking pace's worth of airspeed. Without it the P-51's tail came up only at 56 m/s, and the take-off ran 950 m.
- **The autopilot flies it as its manual does** (`tail_up_and_off`, `roll_on_a_tail_wheel`). The stick is held back
  until a third of the stall, the tail raised to a fifth of the rake, and the aeroplane lifted off at 1.15 x the stall
  with the tail wheel just clear. The roll-out is three-point with the stick back, braking gently below 0.6 of the touch
  speed. The rudder damps the yaw everywhere, since the heading on the wheels is unstable.

**The P-51 against its book** (`tests/warbird_book.gd`, `tests/taildragger.gd`, `tests/warbird_circuit.gd`). All figures
are at sea level, on military power, at 4,300 kg:

| | the book | now |
|---|---|---|
| autopilot turn, rate / (g tan bank / v) | 1 | 0.99 at 30 and 45 degrees (lumped: 0.64) |
| top speed | 364 mph, 162.7 m/s (Wright Field TSCEP5E-1908) | 162.9 m/s |
| climb at 170 mph | 3,030 ft/min, 15.4 m/s (NAA NA-46-130) | 16.6 m/s |
| stall, clean and gear and flaps down | 103 and 96 mph IAS at 9,500 lb (AN 01-60JE-1) | CLmax 1.50 and 1.73: 46.1 and 42.9 m/s |
| take-off ground run | 1,450 ft at 9,400 lb, 442 m | 692 m, off at 55 m/s, the tail up to 3.9 degrees on the way |
| at rest | three points, 13 deg 36 min printed | 12.95 degrees, the drawn tyres 1 mm off the ground |
| half brake from 30 m/s, tail down | | stops in 164 m, the tail never lifts |
| full brake at 40 m/s, tail up | noses over | noses over: the propeller into the ground |
| a kick with the pedals let go at 15 m/s | ground-loops | swings 180 degrees in 3 s; caught by rudder and brake, 0.5 degrees off |
| the AI's circuit | take-off, circuit, landing | tail up, off, round, three-point at 9.9 degrees, 0.82 m/s down, stops |

**WHAT IT COSTS**, `tests/rota_probe.gd -- --counts=1000 --blocks=4 --kind=p51 --set=surfaces=0|1,cruise=70`, bracketed
off, on, off, on in a MEASUREMENT slot, both models pinned to one cruise: the whole tick 2.450 and 2.456 ms off against
2.581 and 2.539 on, so **+107 ns an aircraft a tick** (the two on-runs are 42 us apart, so read it as +107 give or take
20); the FORCES 421.7 and 415.7 us against 537.9 and 527.8, **+114 ns an aircraft**; the Box3D step and the ground work
unchanged (-9 and +6 ns, noise). Against the Cessna's +75 ns and the plan's +250 budget. THE TAILDRAGGER'S WHEELS ARE
NOT IN THAT NUMBER: a thousand aeroplanes in the sky never touch `roll_a_taildragger`, which runs only with weight on
the wheels.

**THE TAKE-OFF IS LONG, AND IT IS HONEST.** The book lifts off at 99 mph, its own stall, where this wing makes a CL of
about 1.0 at the three-point attitude with no ground effect, and the straight propeller line gives 16 kN static where a
real Merlin gives 20 or more. It lifts off at 1.2 x its stall after 692 m. The check allows 1.7 of the book, the
Cessna's allowance, and says why. The lever is ground effect, one of the playbook's cheap extras, not a tuned number.

**The traps, each paid for once:**
- **A throttle input of 0 is a hand LET GO, and the lever holds where it was** (`apply_pilot_input`). A robot that
  "closes the throttle" with 0 keeps the power on. The first half-brake run went 1,100 m. A closed throttle in a suite
  is a small non-zero input (`taildragger.gd`'s `IDLE`).
- **The law cannot lift a tail the ground holds down.** The autopilot asks the control law for pitch rates, and the law
  knows nothing of the ground. Asked gently, it made an elevator too gentle to lift the tail's weight: at 2 a second the
  tail hung at 5 to 8 degrees for the whole run. At 6 a second the law saturates the elevator until the tail comes up
  (`kAttitudeRate`). This is the Cessna's rotation trap, the other way up.
- **Going on to a field is a new traffic record** (`AirportTraffic._carry_on_to`). A suite that keeps the departure's
  record watches `departing` for ever while the aeroplane comes round and lands.
- **The F-row is full.** F1 plus the kind reaches kind 34, so the P-51 is boarded from the CRAFT page and by name, not
  by a key (`tests/many_kinds.gd`).

**Its guns** are the six .50s as ONE station (`Gun::battery`): the trigger fires the battery's 4,800 rounds a minute,
and each round is born at the next of `P51Airframe.muzzles()` in turn, harmonised to cross the line of flight at 300
yards (`tests/warbird_guns.gd`). The master arm gates them, as it does every selector gun.

**Its seat** is `seat_p51.tscn`, the fighter's room with no speed brake. It sits under the eye `P51Airframe.EYE` puts
0.24 m under the bubble's top (ESTIMATE), with the kit's coaming (`WarbirdAirframe._coaming`) closing the hollow nose
off from the eye, the warthog lane's lesson. On the ground the long nose hides the runway ahead, as it really did. That
is left alone.

### THE SECOND TAILDRAGGER, AND WHAT IT COST: the P-47D-30 `p47` (lane/warbirds2, 2026-09-19)

The Thunderbolt is the P-51's machinery with its own book (`kP47Book`) and its own planform, and nothing in
`roll_a_taildragger`, `tail_up_and_off` or `roll_on_a_tail_wheel` was touched to fly it -- which is what a second kind
on new machinery is for. Its numbers and their sources are `research/warbirds_book.md` section 2. Three things about it
are new, and each is the AEROPLANE and not a tuning choice; the fourth heading below is a suite that had quietly
outgrown itself, and is here because the next kind will meet it.

**ITS TAIL WHEEL DOES NOT STEER, and that needed no code.** AN 01-65BC-1 and T.O. 01-65BC-1 give the P-47 a lock handle
and no steering linkage: locked at centre, or full swivel. `Planform::tailwheel_steer` of **0** is exactly that in
`roll_a_taildragger` -- locked, the wheel is held straight ahead and grips; unlocked by the stick full forward, it
castors and holds nothing -- so the aeroplane turns on its BRAKES alone. The taxi written for the Mustang's six steering
degrees works unchanged: **7.5 m of radius, 60 degrees round in 2.3 s**, against the Mustang's 6.9 and 2.1, and with the
wheel locked it never comes round at all (`tests/taildragger.gd`).

**A TAKE-OFF IS NOT OVER THE TICK THE WHEELS LEAVE.** `on_the_ground` hands a departing aeroplane from `take_off`'s hand
to the mixer at `Handling::ground_height` over what is below or `ground_speed` through it, and on the defaults -- 4 m,
and a speed just over the lift-off -- the P-47 was handed over three metres up at 64 m/s. The mixer's attitude loop then
swung it from the 10.6 degrees that was flying it to nothing in six tenths of a second, on an aeroplane whose pitch
inertia is nearly twice a Mustang's, and it sank back onto the runway and was written off, every time. **15 m and
72 m/s, this kind's alone**: the hand that flew the run keeps the climb-out attitude until there is height to take the
hand-over's transient. Any heavy aeroplane added here wants the same look.

**IT IS TOO HEAVY FOR THE VISUAL CIRCUIT, and that is correct.** At 6,001 kg it is over `TrafficPattern.LARGE_MASS`
(5,670 kg, the FAA's 12,500 lb), so `AirportTraffic` gives it an INSTRUMENT approach -- the thing the user asked for for
large aeroplanes -- and it is the first FIGHTER here on the far side of that line. Two consequences a suite must know:
- **it takes 1,285 s from the apron to stopped**, against the Mustang's 596, because the vectors run 16 km out and the
  final as far again. `warbird_circuit.gd` watches for 1,800 s and exits the tick it stops;
- **an instrument approach is not flared**, so it arrives in a WHEEL-landing attitude -- 8.0 degrees nose up at 66 m/s,
  296 m past the threshold, 0.77 m/s of sink -- and the three-point rule written for the Mustang does not apply to it.
  Its THREE-POINT landing is held by `tests/taildragger.gd`, which flies it by hand.

**A SUITE CAN OUTGROW ITS OWN GROUND, and the measurement will lie before it fails.** `tests/climb.gd` puts one
aeroplane a LANE, 700 m apart from -4,000, on a ground slab whose half-width was typed at 7,200 m. At the seventeenth
powered wing the lanes ran off the end of it: the P-51D was spawned on the slab's edge and the P-47D-30 beyond it, both
fell to the world's floor at -200 m and were clamped there -- thousands of `the wire clamped ... VehicleState.y` errors
a run -- and they then took 106 and 132 seconds to reach 60 m where the rule is 60. The obvious reading was "a wartime
fighter is slow off the ground", and a per-kind allowance was written here and then deleted: ON GROUND, the P-51D
reaches 60 m in 35.5 s and the P-47D in 39.5, against a Cessna's 44. The slab is worked out from the lanes now. Two
lessons, and the second is the one that matters: **a list keyed on `Sim.Kind.size()` will break at some count -- ask
each one what happens at a hundred -- and a number measured in a broken world is not a measurement.**

**The traps, each paid for once:**
- **The clipboard had the F-row snapshot too.** `tests/clipboard.gd` asked every PILOTABLE kind for a key on the board,
  and `PilotRig.desk_keys` deliberately gives a kind past F35 none. The P-51 became kind 35 and the suite went red for a
  key the game is right not to bind. It now asks `keyed_kinds()` for keys and the CRAFT page for the rest -- the same
  mending `many_kinds` had the same day.
- **A package is written from the SHAPE, so a seat moved in C++ needs it written again.** The P-47's seat moved 0.15 m
  aft after the first generation and `tests/lamp_wire.gd` caught the stale one.

**Its guns** are EIGHT .50s as one station: 6,400 rounds a minute, 2,400 rounds, each born at the next of
`P47Airframe.muzzles()` in turn, harmonised at 300 yards. The heaviest weight of fire here bar the A-10's cannon.

**Its seat** is `seat_p47.tscn`, the Mustang's with a roomier shell (0.90 by 0.96 against 0.84 by 0.92) -- a
Thunderbolt's cockpit was famously big -- under the eye `P47Airframe.EYE` puts 0.27 m under the hood's crown.

### MEASURED OFF ITS OWN MANUAL, AND THE PUBLISHED NUMBER WAS WRONG: the F-4E Phantom II `phantom` (lane/phantom, 2026-09-20)

The Phantom is drawn whole by `PhantomAirframe` -- 1,874 triangles over 29 draw surfaces, faceted, with slats, flaps,
ailerons, two all-moving stabilators, a rudder, two canopies, two variable-area nozzles, a hook and three legs that
retract. Every figure it is built from, and where each came from, is `craft/phantom/sources.md`, tagged [FM] for the
flight manual, [TO] for the technical order, [M] for measured off a drawing and [PUB] for merely published. The column
that matters most in that table is "fitted to?" -- which figures the geometry was FITTED to, and so cannot be checked
by a test without the test becoming a tautology. The height, 5.004 m, is one of those and `tests/phantom.gd`
deliberately does not assert it.

**THE WIDELY PUBLISHED "45 DEGREE LEADING EDGE SWEEP" IS THE QUARTER CHORD.** Drawn at 45 degrees on the leading edge,
the wing would not fit its own three-view at any scale. Measured off the technical order's plan, the leading edge is
**51.5 degrees** and the QUARTER CHORD line is 45.07 -- which is the published number, correct, about a different line.
`the_quarter_chord_sweep_is_the_published_forty_five` asserts the 45 from the drawn vertices, so the aeroplane is held
to the published figure and to the drawing at once. Anyone adding a swept wing here should assume a published sweep is
a quarter-chord sweep until the source says otherwise.

**A SCANNED DRAWING IS NOT ISOTROPIC, and the way to catch it is a figure nothing was scaled by.** The three views
scaled to 713 px/7.09 m on the side, 1925/19.2 on the plan and 1189/11.71 on the front: three different pixels-per-metre
for one aeroplane. Every view was then checked against the ONE printed station figure the documents give --
the 7.090 m wheelbase -- because a dimension used to set a scale can never test it. `craft/phantom/measure_manual.py`
re-derives every [M] figure from the drawing alone, so the numbers in the table can be recomputed rather than believed.

**THREE FAULTS, AND NOT ONE OF THEM COULD FAIL A TEST.** This is the entry's real content:

- **The whole aeroplane was half a metre flat.** The drawing's real fuselage top had been read as a construction line
  and masked out. Fifteen checks were green; the orthographic overlay showed it at once.
- **The fin was detached**, standing in clear air above a four-metre gap, because its root was placed where the fin
  starts rather than where it would meet the spine. Buried now by extrapolating the same leading and trailing edge
  lines down to the fuselage.
- **The slats and flaps drew a dark bar diagonally across the wing**, with every angle correct and every deflection
  check passing. They had been hinged about a SPANWISE axis. **A surface turns about its own hinge line, not about the
  span**: a slat's hinge is the leading edge, swept 51.5 degrees, so its outboard end swung metres forward. Each
  surface's axis is now the vector from its inboard hinge point to its outboard one, taken from the drawn geometry.
  Every swept-wing craft here has this exposure.

The rule those three earn: **an angle, a length and a deflection can all be right while the shape is wrong.** Render it
orthographically over the drawing and compare the silhouettes. `craft/phantom/overlay_views.py` does that on
`tools/three_view.py`, the shared library nine other craft already use -- porting it took an hour; writing a new one
took most of an afternoon and was the wrong call.

**A PART BUILT IN CRAFT COORDINATES AND HUNG ON A HINGE COUNTS ITS OFFSET TWICE.** Every builder here works in craft
coordinates, because that is what makes a station a station -- and a hinge node sits at a craft coordinate too, so the
mesh arrived at twice its station and the aeroplane came out **27.4 m long against 19.2**. `_add` now offsets a child
by `-parent.position`. **The nozzle is the exception and the reason is written in the file**: it SCALES, and a node
that scales cannot carry a cancelling offset, because the scale is applied to the offset as well. That is exactly the
kind of inconsistency somebody would otherwise tidy into a bug.

**AN ANGLE CHECK PASSES ON A HINGE WOUND BACKWARDS.** Both sides still turn by the right amount. The stabilator pitched
the wrong way -- pulling back LOWERED its trailing edge -- with every angle assertion green.
`the_stick_moves_the_right_surfaces_the_right_way` starts at the stick and asserts the direction, and it is a mutant
now. Any craft with a moving surface wants the same check.

**AND A GUARD A CORRECT AEROPLANE CANNOT SATISFY is not a strict guard, it is a wrong one.** The mirror check first
asked the two sides to be SYMMETRIC at full roll. A differential pair is not symmetric at roll; it is ANTI-symmetric,
and the check now says so. Sixteen mutants are killed by `craft/phantom/mutants.py`, and the one that refused to die
was the most useful thing in the lane: `nothing_floats` was a claim about bounding boxes, not about surfaces, so its
claim was narrowed to what it actually holds and a mutant that does kill it was written. **A check whose mutant does
not kill it is not a weak check; it is a check about a different thing than you think.**

**IT FLIES ON THE TOMCAT'S NUMBERS AND THAT IS SAID OUT LOUD.** `vehicle_gym` measures it at a top speed of 216.9 m/s,
7.26 m/s of climb and 0.061 rad/s of turn, which puts it into the family this document already names -- the fighter,
the Tomcat, the Falcon, the Prowler and the Lightning are one placeholder wearing five airframes, and the Phantom makes
**six**. It borrows `kKindTomcat`'s handling case deliberately; the lane was scoped to the airframe and not the flight
model. Its speed gate ends 5.7 m/s high, which is the documented last-five-per-cent-of-throttle fault, not a fault of
its own. **Its inertias carry the least evidence of anything on the aeroplane**: nothing public was found for any F-4
mark, so they are the F-14D's scaled by the mass ratio 0.798, with roll scaled by that ratio alone because the two
aeroplanes' spans agree to half a per cent.

**Its gun** is the M61A1 the E is the first mark to carry internally: 640 rounds [PUB], on the CENTRELINE in the
fairing under the radome at station 1.86, which is what separates it from the F-16's shoulder mounting. **Its seats**
are two in tandem, the front one noticeably further forward and higher than the back -- a Phantom recognition feature
in its own right. **It has no wing fold**: the C and D do, the E does not, so the joint is a panel line and nothing on
it moves.

### A hull floats on FOUR points

A single buoyancy force at the centre can only push a hull up. It knows how deep the boat is
and nothing about which END is deep, so a boat on a swell rises and falls dead level and
reads as a bath toy.

Four probes -- bow, stern and each quarter -- each sample the sea WHERE THEY ARE and push up
by how far under they are, and the torque falls out of the four of them disagreeing. Bow
down a wave face, rolling in a beam sea and heeling into a turn are then the same arithmetic
and none of them is a special case. It is what every game does that gets this right. The
righting moment came down to match, because a stiff one on top of four honest probes is a
hull that refuses to lean at all.

**Both sides have to agree about where the sea is**, and here they nearly do not. The ocean
shader is normals only: the sea is one enormous quad with four vertices, so there is nothing
to displace and its waves are a lighting trick. But its swell terms are the derivative of a
real surface -- the slope it draws is `dir * cos(phase) * amp * len`, so the height it is
the slope OF is `sin(phase) * amp` -- and `swell_height` is that surface. Two hundred metres
crest to crest and three quarters of a metre trough to peak, which is invisible on a flat
plane and very much not invisible from a boat sitting on it.

**The swell does not travel, and that is a rollback decision.** A resimulated tick has to
compute the same sea as the original, and there is no frame number in the world that
survives a rewind to key a phase to; a free-running clock would give a replayed boat a
different wave and a rollback every tick it was afloat. The cost is that a boat lying stopped
does not bob. A boat UNDER WAY meets a crest every dozen seconds and pitches and rolls
through it -- measured, 5 degrees off level at 9 m/s -- which is nearly all of what anybody
feels. When the world grows a rewindable clock, adding `+ t` to both phases is the whole
change.

### The car, and the boat

The car is a **bicycle model**: one tyre at the front axle, one at the rear, each turning
its own slip angle into a lateral force, each force applied **at its own axle**. Yaw is
then not something the code commands -- the steering aims the front tyre, the tyre makes a
force because it is now travelling at an angle to where it points, and that force is 1.4 m
ahead of the centre of mass. Understeer, oversteer and a slide you have to catch become
two numbers (how much each axle holds) instead of three more branches. The rear axle holds
more than the front, which is what makes this one push wide rather than swap ends.

Past the peak slip angle the force stays **flat** rather than falling away. That is the
forgiving half of a real tyre curve, and the one place this model is deliberately kinder
than the road.

The boat's keel is the same argument as the aeroplane's side force, in water: linear in the
slip, so it is still working at the small angles a quadratic term has given up on. It is
**capped**, because a hull slides when you ask too much of it -- a boat that corners at
1.4 g is a car.

Its rudder is a **force at the stern**, not a commanded yaw rate, which costs nothing and
buys two things: the stern swings wide through the turn, and the helm reverses by itself
when the boat goes astern. And a **wave-making** term gives the hull a speed it cannot
simply be powered past -- without it the same engine pushes it to 60 m/s, which is not a
boat.

Measured: the car turns 57 degrees in two and a half seconds of full lock at 0.8 degrees of
slip; the boat settles at 18 m/s on full throttle and turns 78 degrees in three seconds of
full helm at 3.6 degrees of leeway. The keel had to come up with the rudder: a helm that
turns twice as hard asks the hull to hold twice as much, and a keel that gives up under it
turns a tighter corner into a slide.

### Nothing may reverse what it is resisting

Every resistance in the file -- drag on all three body axes, the brake, rolling resistance,
the keel, wave-making, the tyres -- goes through one clamp: never more force than would
bring that component to exactly zero this step.

It matters because the simulation integrates explicitly at 60 Hz, and any coefficient large
enough to be interesting is large enough that `force * dt / mass` exceeds the velocity it
opposes. Unclamped, a vehicle shudders backwards under its own brakes.

The brake used to dodge that with a `speed > 0.3 m/s` guard, which meant it gave up before
a stop: the left trigger could slow anything right down and never park it. The clamp fixes
both halves at once. Measured, full brake from 25 m/s reaches **0.0000015 m/s** and then
moves 0.000000000 m over two more seconds of held trigger.

## HOW TO ADD A CRAFT KIND

Asked for on 2026-09-18: "we could have many vehicles in the future, so let's make sure it's easy to expand the
count" (lane/kinds). A kind's NUMBER is no longer a limit -- sixteen bits, 65,535 of them, see "A KIND IS SIXTEEN BITS
NOW" above -- and its IDENTITY is one row. What is left is content, and each place below is either one line or a
thing with a default that `tests/many_kinds.gd` will not let you take silently. Line numbers are as of 5060b0e4.

**The simulation (ashiato-gd/src/cockpit/), then rebuild both libraries:**

1. **The row.** Append `KIND(Id, "name", id_shape, Model)` to `cockpit_kinds.inc` (the last row is line 95). APPEND,
   never insert: the row's place is the kind's number, on the wire and in saved levels and packages. This one line is
   the `kKind<Id>` constant, `kKindCount`, `kind_name`, `default_model` and the shape table, each built from the file
   (`enum KindNumber`, cockpit_world.cpp:362; `default_model`, :2839; `kind_table`, :9849). Put the kind's story in
   the comment above its row, which is where every other kind's is.
2. **The shape.** `inline Shape id_shape()` in cockpit_world.cpp, beside the others (`littlebird_shape`, :2179): size,
   mass, seats, parts. If it is defined after the first use, declare it first as `uh60_shape` is (:1043). A row whose
   shape function does not exist does not compile.
3. **The content with a default** -- a kind with no case gets the default, and many_kinds' default report prints
   every kind's line and goes red for a kind with a package on a default that is not in `INTENDED_DEFAULT_BUS` or
   `INTENDED_DEFAULT_HANDLING` (tests/many_kinds.gd:45) with a reason:
   - `default_bus` (:1643): the channels its panel has. The default is a "hover hold" and nothing else, which is how
     the UH-60 flew for a day without cyclic trim.
   - `default_handling` (:3181): thrust, drags, rates. Every kind has a case today; a new one without one is red.
   - `gun_of` (:1269): crew-served mounts (door guns, pintles, turrets), none by default. They are not armed by the
     master arm; `fire_round` never reads it.
   - `loadout_of` (:1579): the gun on the weapon selector and the pylons, none by default. These ARE armed by the
     master arm, so a kind with them wants `Channel::Master` on its bus. And `Channel::Weapon`, and a fresh package (step 8): a station
     built from an old package has no lock sight and no master arm (lane/jetarms found the F/A-18F's that way). A kind
     whose model should show its missiles on the rails sets `"hung_stores": true` in its catalogue entry (`HungStores`).
4. **Net.PROTOCOL** (cockpit/autoload/net.gd:50): the next free number at your merge, with a line saying what an older
   peer would get wrong.

**The game (cockpit/):**

5. **The enum.** Run `res://tools/generate_kind_enum.tscn` (headless, from cockpit). It writes `Sim.Kind` between the
   BEGIN/END KINDS markers (autoload/sim.gd:35) from the library's table. Never type it: many_kinds names any entry the
   two disagree about, and fails a hand edit even when the entries agree.
6. **The catalogue.** An entry in `VehicleCatalogue.CRAFT` (objects/vehicles/vehicle_catalogue.gd:72): its seat scene,
   `Body`, paint, helm. A kind with no entry is drawn as the light aeroplane, which is a default you will see.
7. **The airframe**, if it has its own: a class in objects/vehicles/ (`littlebird_airframe.gd`), a `Body` for it
   (vehicle_catalogue.gd:25), and the `match VehicleCatalogue.body(kind)` arms that choose it in vehicle_view.gd:465
   and vehicle_lights.gd:311 and :341. See `modelling_here.md`.
8. **The package.** `craft/<name>/sources.md` for where its numbers came from, then run
   `res://tools/generate_authored_packages.tscn`, which writes `craft/<name>/1/`. It rewrites every craft's files; only
   yours should show content changes (`git diff --numstat`), the rest only line endings -- restore those.

9. **The places the kind must be TOLD ABOUT, which no suite loop finds for you.** A kind with no entry here does not
   go red in the suite that owns the entry; it goes red somewhere else, or nowhere:
   - `Terrain.spawns()` (world/terrain.gd): a row for the kind. **`Sky._register_issue_places` walks this table, so a kind
     with no row has no issue place**, and a player who asks the CRAFT page for one is answered `kind_no_issue_place`. It
     first shows as `crew_sync`'s "no view of kind N". A ship also goes in `Terrain.is_a_ship`, or its row is put on land
     (lane/boatcrew, 2026-09-20, after the fireboat landed without either).
   - `Terrain.fleet_size` (world/terrain.gd): **an unlisted kind silently gets `FLEET_SURFACE`**, so a jet or a boat that
     is not named there looks as though somebody chose that size. Nothing fails. Name the kind or decide it should not be in the fleet.
   - `exhaust_ports()`, if the kind has thrust: an Array of DICTIONARIES, `{"at", "axis", "radius", "kind", "heat"}`, never
     bare points. `ExhaustYard.lay` casts each one, and a wrong shape is a script error on every frame from the moment
     anybody boards the craft. Nothing red until somebody boards it.
   - The catalogue keys that adjust a shared station scene for one craft: `screens_inboard`, `footwell` and
     `map_screen_height`. A craft whose seats sit close to its front glass wants the last (`Wheelhouse`'s chart shelf
     hid the fireboat's map glass; the fix is a key and not an allowance).
10. **THE SUITES A NEW KIND MUST RUN BEFORE IT IS READY.** Gate on your own suites AND these, because a lane that gated
   on sixteen of its own suites landed the fireboat with three of them red and the fourth needing a re-record. Run them
   as `run_all.ps1 -Tier core -Only <your suites>,many_kinds,many_seats,vehicle_gym,exhaust`
   (plus `ship_models,hulls,seakeeping` for a ship): `-Tier core` carries `lint`, `docs`, `stations`, `shell_room`,
   `screens_face`, `crew_sync`, `joined_parts` and `smoke` and nothing else in the table. Read the `RESULT=` line of each:
   **AND THIS LIST IS A FLOOR, NOT A CEILING.** Two lanes found eight suites this way; `lane/phantom` then found
   three more -- `pilot_seat`, `no_vr_flight` and the absence of `sheet_cost` -- by running **`-Tier core` entire**
   rather than a chosen subset. Every time somebody gates on the list instead of the tier, the list grows by what
   they missed. **The only gate that can be trusted for a new kind is the whole core tier**; the table below tells
   you what each one will want and which ones your own work will never point you at, not which ones to run.

   | suite | what it wants of a new kind | breaks by |
   |---|---|---|
   | `many_kinds` | the enum matches the library's table, and every default (bus, handling) is intended or given a case | FORGET |
   | `stations` | every seat has a JSON station in `craft/<name>/1/` that equals the runtime station; regenerate (step 8) after ANY change to a seat scene or a catalogue key | FORGET |
   | `docs` | the docs' claims about the kind still hold; also fails a file that describes a colour or a count the code no longer has | FORGET |
   | `lint` | no parse error, and no preload cycle | change |
   | `smoke` | the game boots, and every kind builds | change |
   | `shell_room` | every station is either held inside its airframe or named in `OPEN` with a MEASURED reason; the head check says which | FORGET |
   | `screens_face` | every screen in every station is visible from its own seat, and `KNOWN` is an allowance for cases somebody judged, never a place to put a new one. Move the screen or the seat | FORGET |

   **`shell_room` AND `screens_face` LOOK MUTUALLY UNSATISFIABLE AND ARE NOT** -- the resolution is at the
   end of this note, and the first user of this table hit both halves.
   Reported by `lane/phantom` on 2026-09-20, for a craft whose crew sit above the deck under a separate
   canopy. The F-4's `_fuselage` drew a closed ring at every station, so there was no cockpit opening at
   all: eyes at 2.92 m over a sealed deck at 2.62 m, every instrument under a lid, and `screens_face`
   correctly red. Cutting the opening fixes it **and breaks `shell_room` outright** — its containment test
   is RAY PARITY, and its own doc block says an open surface makes a ray say "outside", so one hole makes
   every part of the station read as uncontained at once (`Floor 8 of 8 corners outside`).
   **The fix is neither of those.** Close the canopy shells downward so head, floor, bar and screens all
   sit inside one closed part, *then* cut the deck — which is the case `shell_room`'s doc block already
   describes for the F/A-18. It costs one hidden face; say in the commit why it is there so nobody deletes
   it as waste. **Do not cut the hole and then chase the eight corners**, and do not put the screens in
   `KNOWN`: a screen nobody can see is a bug, not a tolerance.
   **TWO THINGS THE HOLE THEN WANTS, both found by suites two steps away.** Leave the deck under any structure the
   craft really has between its canopies -- an F-4's bow at stations 5.70 to 6.02 -- or the hole is a gap over
   nothing and `pilot_seat` reports the back of the pilot's head `open along (0, 1, 0)`. And check the SEAT has room
   at both ends: the station's furniture reaches about 0.6 m ahead of it and must stay aft of the windscreen base,
   while the chair's headbox reaches about 0.56 m behind it and must stay under the canopy. Measure the headbox off
   the chair; an estimate of 0.43 left three vertices outside and read as a fix that had worked.
   | `crew_sync` | the kind can be boarded through the real CRAFT path, and a second seat's controls follow the first (step 9's spawn row) | FORGET |
   | `joined_parts` | the craft is ONE object: no part of it is adrift of the body by more than a tolerance (the Phantom's hung stores were 0.40 m off its fuselage) | FORGET |
   | `many_seats` | a craft past four seats still works: seats are sixteen-bit numbers | change |
   | `pilot_seat` | every vertex of the fitted chair has the craft's own drawing above, below and beside it within 2.2 m, and the chair hides nothing from the eye. Cut a hole in a deck and the chair looks through it | change |
   | `no_vr_flight` | two machines, the whole flow with no headset: F changes seat, G changes craft, H changes KIND. It only meets a new kind once the kind has a `Terrain.spawns` row, and it is where a slow or broken airframe shows up -- two suites from the fault, with no error printed | FORGET |
   | `sheet_cost` | dressing the first aeroplane of a kind is not slow, and dressing the SECOND is nearly free. Nothing else here times an airframe | change |
   | `vehicle_gym` | adding a kind RE-RECORDS `tests/vehicle_gym_baseline.txt` (`-- --write=<file>`); new lines are expected, MOVED lines are not and mean something else changed | FORGET |
   | `exhaust` | the ratchet of kinds with thrust and no ports; a kind's ports are dictionaries (step 9) | FORGET |
   | `ship_models` (ships only) | the helm can see the bow and the deck ahead, and the fittings stand on the hull | change |
   | `hulls`, `seakeeping` (ships only) | the hull floats level at its draught and rides a sea | change |
   | `<your kind>` | its own dimensions; a suite that reads what the model declares must read it in the shape step 9 gives | change |
   **THE `breaks by` COLUMN IS THE ONE TO READ FIRST, and it is why two lanes running have shipped red.** A lane
   gates what it believes it touched. The suites marked **FORGET** are not broken by anything a lane writes -- they
   are broken by a registration it never made, so nothing in its own work points at them and nothing in its own gate
   names them. `lane/fireboat` and `lane/phantom` shipped four red each, and **every one of the eight was a FORGET**:
   a missing `Terrain.spawns` row, a `fleet_size` default taken silently, a package not regenerated after a
   catalogue key moved, a station never looked at from inside the hull, and stores hung off pylons nobody had
   checked against the belly. Not one was a mistake in code that was written; all eight were code that was not.

   So: **gate every FORGET row even when you are certain you have not been near it.** The `change` rows will fail on
   their own when you break them, and they are the ones a lane's instincts already cover. (lane/phantom, 2026-09-20,
   at team-lead's request -- written by the first kind to meet all four from the inside.)

   The list is not derived from a table, so it can go stale: when a suite starts failing on a new kind, add it here and
   say what it wanted.

**What you do not touch:** the key (`PilotRig.kind_key` gives F1 plus the kind up to F35, and the CRAFT page lists
everything), the wire (`write_kind` carries any number up to 65,534), the seabed drop layout (it appends), and the
suites that loop over `Sim.Kind`.

## A CREW: AS MANY SEATS AS THE CRAFT IS BUILT WITH, AND EVERY SEAT WIRED TO SOMETHING DIFFERENT

Every craft built before 2026-09-18 carries **one to four**, and until then four was a wire limit: `Seats` was four
occupant bytes in the packet. Since lane/seats a craft may have **any number up to 65,534** ("yes, no max", the user),
and what bounds how many are aboard at once is the session's player cap -- see "Past the fourth seat", below. A player
asking for a seat that is taken or that the craft lacks is turned away rather than anybody being displaced to make room.

Every seat sends a full control frame; the wire does not know or care which seat sent it.
What decides where that frame goes is the seat's **station**:

| Station | What the stick does |
|---------|---------------------|
| `pilot` | flies it, and is the only seat this machine predicts from |
| `copilot` | also flies it, on the same linkage |
| `turret` | swings the turret. No authority over where the craft goes at all |
| `operator` | operates non-flight devices; no physical flight demand |

| Kind | Seat 0 | Seat 1 | Seats 2-3 |
|------|--------|--------|-----------|
| plane, pod, heli | pilot | copilot | turret |

| prowler | pilot | copilot (game concession) | operator |

| boat | helm | second helm | turret |
| car | driver | turret | turret |

A car gets no copilot because a passenger seat is not a second steering wheel.

**Dual controls: the larger deflection wins.** Not an arbitrary rule -- it is what two
control columns on one linkage physically do. Either seat can fly, neither has to be handed
anything, and a copilot who lets go contributes exactly nothing rather than averaging the
pilot's input back towards centre. The two continuous levers take the larger demand, for
the same reason. Pulled opposite ways, the aeroplane gets the bigger of the two and neither
gets what they asked for, which is also what happens in a real cockpit.

The helicopter's two back seats are turned ninety degrees OUT OF THEIR OWN DOORS, one each
way, because each of them has a machine gun to swing there -- see "the gun is the control".

**The turret aims, it does not fire.** It is deliberately something the craft carries
rather than something the craft does, so a back seat has a real system of its own without
this project pretending to have weapons. Its two angles live in `VehicleState` -- twenty-two
bits, wanting exactly the interpolation and rollback that component already has, where a
separate component would need its own traits, archetype entry and display path to arrive at
the same place. The lowest occupied turret seat has it; two gunners on one mount would
fight over it every tick and there is nothing sensible to average.

### The one cost, stated plainly

**Only seat 0 predicts.** A copilot's stick genuinely flies the aircraft, but the input
travels to the server and the result travels back, so it carries the round trip.

It cannot be otherwise yet, and the reason is the same one that keeps `ControlInput` out of
both archetypes: nobody receives anybody else's input. A copilot who predicted would be
predicting with the pilot's stick assumed centred, and the throttle alone makes that fatal
-- the pilot holds it open, the copilot's prediction says closed, and the two disagree on
every single tick for ever. What the copilot's own view does NOT suffer is jitter: their
head and hands are seat-local, so they are exactly as steady as the pilot's.

The fix, when it is wanted, is to replicate a flying seat's input to the rest of its own
crew. That is a wire change, not a rewrite.

## EVERY CRAFT TYPE FLIES ITSELF, IN ITS OWN WAY

The MODEL says which forces exist, the handling says how strong they are, and neither says
anything about MANNERS -- which is most of what tells two aircraft apart in the air. An
airliner and a light aeroplane fly on the same wing and only one of them rolls to fifty
degrees to make a waypoint. `fly_it_like_a` is where that lives: bank limits and how far out
of its slot a follower starts stacking up. The climb is not chosen there any more but derived
-- see "The heavy wings climbed themselves into the ground" below.

**Speeds are derived and are not in that table.** The stall comes out of the lift model --
level flight is `weight = camber * v^2 * lift`, so solving it for v is the speed below which
the aeroplane is not flying -- and the cruise comes out of thrust against drag. Retune a
wing and its autopilot retunes with it.

That derivation caught a real one. Cruise was a FRACTION of what thrust and drag allow,
which says nothing about what the wing needs: the airliner has a quarter of the light
aeroplane's thrust-to-weight, so 55% of its flat-out came to 48 m/s against a stall of 63,
and its autopilot spent every flight holding it below flying speed and wondering why it was
sinking. Cruise is floored above the stall now.

### Nowhere to go is a reason to climb

Every candidate leg is tested for terrain clearance, so an aeroplane that gets LOW cannot
route out of being low: from down there nothing clears, the search fails on all eight
attempts, and holding the present altitude means it fails again next tick and for ever. Two
aeroplanes out of forty were doing that at 61 m, quietly, until the world was shut down.

An autopilot with no route climbs to a height a route can be found from. Height is the thing
it is short of.

### A crisper stick, and a controller that can keep up with it

**A controller can only be as quick as the aeroplane it is asking**, so the two went up
together. A full deflection asks for half again the rate it did, and the surfaces push half
again as hard to get it: asking for more is what makes a stick feel connected, and pushing
harder is what makes the answer arrive now rather than shortly.

Every loop in `AircraftMixer` was tightened with it. The outer loops command a LIMIT and the
inner ones track it, so a higher outer gain buys an earlier commitment to the turn and a
higher inner one buys a shorter time to reach the bank that turn needs.

Measured over the whole world, before and after:

| | before | after |
|---|---|---|
| flights, median slot error | 30 m | 3 m |
| aeroplanes, average | 178 m | 1 m |
| aeroplanes, worst | 3700 m | 2 m |

The stragglers are gone entirely. `the_flights_hold_to_a_wingspan` pins it.

### And then backed off again, at the near end only

Held station beautifully and flew like something being corrected constantly, which is the
usual price of a first tightening. The fix is not to undo it: the gains that matter for
CATCHING UP are the far end of the formation schedule, and those stay.

What came down is everything about ARRIVING, which is a different job. A follower settles
from forty metres out rather than twenty-five, aims three hundred metres ahead instead of a
hundred and seventy once it is close, and takes half the cut it did -- eight degrees is a
nudge, sixteen was a swerve, and a swerve at the slot is what makes a formation look
nervous. It brakes harder onto the slot than it accelerates toward it, so it stops arriving
with speed it cannot lose. And it anticipates the leader's turn less, because at 1.35 the
anticipation was itself something to correct.

The mixer loops came down and their DAMPING went up, which buys the same settling time
without the twitch. Slot error went from 1 m to 5, which is a quarter of a wingspan and
still tighter than it has ever been.

| | first tightening | backed off |
|---|---|---|
| aeroplanes, average | 1 m | 5 m |
| aeroplanes, worst | 2 m | 15 m |

### The lateral correction had no rate term, which is a definition of a hunter

This is the one that mattered, and no amount of turning gains up or down would have found
it. The cut toward a slot was a pure function of how far across the follower was: full
correction while it is out of position, none the instant it arrives, and NOTHING ANYWHERE
that notices it is arriving fast. A proportional controller with no rate term does not
settle -- it flies through, sees the error reverse, and hauls back the other way.

`drift_rate` is the missing half: how fast the gap sideways is opening or shutting,
measured against the leader. Coming in quickly the correction eases off early; drifting out
it leans on it sooner. Same authority, and it arrives instead of crossing.

The helicopters were the worst of it -- bank straight off crosstrack with no rate term at
all, which is a spring with no damper bolted to a hovering aircraft.

**And an AVERAGE cannot see any of this.** A follower crossing its slot four times in four
seconds holds a perfect average and is not in formation.
`the_flights_settle_rather_than_hunt` samples the crosstrack over four seconds and counts
sign changes and peak-to-peak swing, which is about the second derivative and is what an
average is blind to. Currently zero crossings and a metre of swing per follower.

| | before damping | after |
|---|---|---|
| helicopters, average | 28 m | 12 m |
| helicopters, worst | 70 m | 25 m |
| all followers within 60 m | 63 of 66 | 66 of 66 |

A car wants far LESS of it than anything that flies: a convoy is twenty-four metres long
and a car can stop closing in a car's length, so a correction that eases off on sideways
speed eases off almost at once and never quite arrives. The aircraft's setting cost the
convoys twice their slot error before it was given its own.

### More sideways, where sideways was the weak axis

Closing the last few metres ACROSS took most of a leg. The near aim point came back from
three hundred metres to a hundred and ninety and the near cap from eight degrees to twelve
-- which puts the lateral authority in the MIDDLE of the range, where a follower actually
spends its time, rather than at a cap it rarely reaches.

The helicopters needed it most. A helicopter does not turn toward its slot, it LEANS at it,
so `side_step` is to a trail what the intercept is to a flight -- and it was the weakest
thing in the guidance: 33 m held against the aeroplanes' 5. Nearly doubled, and the lean it
is allowed with it.

| | before | after |
|---|---|---|
| aeroplanes, average | 5 m | 3 m |
| helicopters, average | 33 m | 28 m |

### A follower may fly harder than its leader, and has to

Every limit in a mixer is a limit on how an aircraft behaves when it is where it means to
be. A follower is by definition somewhere it does not mean to be, chasing a slot that moves
-- and if the leader is a PERSON, one that moves in ways no autopilot would choose.

Holding a follower to its leader's manners guarantees it can never quite catch up: the
moment the leader uses all of its bank, the follower needs more than all of it to close the
gap that opens. So a machine with a leader gets half again as much bank and climb, and gives
it back when it is let go.

The catch-up allowance went up with it, from 40 m/s of overtake to 70. An autopilot leader
flies long straight legs at a fixed cruise and a follower has all day; a human rolls into a
turn, changes their mind and opens the throttle.

And `turn_lead` is more than one now, deliberately. At exactly one the follower rolls in as
the leader's CURRENT rate says it should, which is right for a leader holding a steady turn
and late for one still tightening it -- and a human leader is always still tightening it.

### A follower a long way out stacks up

A rejoin from a long way out is the one leg where a follower is in real trouble. It is
chasing a slot rather than a waypoint, so nothing it is doing has been checked against the
terrain; it is at whatever height it fell out at, which is usually LOW, because falling
behind and sinking are the same mistake; and it is the one aircraft nobody can see, because
it is the one that is not where the formation is.

Climbing fixes all three. The term scales with how far out of the slot it is, so arriving in
the slot and arriving at the slot's height are the same manoeuvre.

### An aeroplane on the ground

Several things, and none of them is free.

**Its rudder has to become a nosewheel.** Every control it has is scaled by airspeed,
because every one of them is a surface in the airflow -- so at a standstill nothing it does
turns it, and an aeroplane that lands is an ornament pointing wherever it stopped. On the
ground the rudder commands a yaw rate directly and the stick is taken away entirely: with no
airflow the ailerons do nothing, and the 12% authority floor that keeps a slow-flying
aeroplane controllable was enough to roll a parked one onto its back.

The nosewheel hands over to the fin as the airflow builds, on the same `bite` every surface
fades on, and its push comes from the aircraft's own inertia and angular damping. It used to
be a torque typed in beside it, 9000 N*m for every kind, and full rudder at a standstill
measured 0.01 rad/s on the light aeroplane and nothing at all on the airliner, against 0.5
asked for.

**It stands on its wheels, and not on its hull.** Every hull had a contact friction of 0.05,
which Box3D mixes with the ground's 0.6 as a geometric mean: 0.17 of weight. A light
aeroplane sat still at 880 N of thrust, and the hull's corners ate the nosewheel. Aircraft
hulls are frictionless now and the wheels are forces -- rolling resistance, wheel brakes and
a sideways grip -- every one measured against WHATEVER IS UNDERNEATH, which on a carrier is
doing fifteen metres a second. The old brake pushed against the air: held on a carrier
under way, it slid a braked aeroplane 362 m off the stern in twenty seconds. It holds within
a third of a metre now, and an aircraft with nobody in it is chocked.

**Gear down is wheels; gear up on the ground is a belly.** A craft put down on something
spawns with its gear down, an autopilot raises its gear once it is clear of the ground, and a
squat switch refuses gear up while the wheels carry weight, so the lever comes back. The only
way onto a belly is to land on one, which slides to a stop in about three metres from 6 m/s
and does not steer. The Cessna and the glider have no gear channel: their wheels are bolted
on. The "aeroplane on the ground" section of `cockpit_loopback` holds all of it.

In the headset the brake is the left trigger, and still is with that hand on the throttle; at
the desk it is Ctrl. The rudder is the stick's twist, the right thumbstick with that hand
empty, and Q/E.

**And the mixer cannot fly a take-off.** Every loop in it assumes a working wing: told to
climb from a standstill it commands full nose-up, which is a tail scrape and then a stall,
and it never reaches a speed at which any of its loops mean anything. So `take_off` flies it
by hand -- line up on a heading with a clear run, full power, rotate at a fifth over the
stall -- and hands back the moment it is flying. The runway heading is chosen ONCE and then
held: an aeroplane that reconsiders halfway down its run is an aeroplane that leaves it.

### The heavy wings climbed themselves into the ground

Reported on 2026-09-14 as "planes still seem to end up on the ground after a minute, all
types". `tests/sinking_probe.gd` flew the real sky for three minutes, with one of every wing
added in the air and on open ground, and logged every autopilot aircraft once a second. The
light aeroplanes, airliners, helicopters and the tiltrotor in the air all held their heights.
What sank was the heavy wings, and not for want of thrust to fly level on:

| | thrust / weight | climb asked for | what it did |
|---|---|---|---|
| tanker | 0.23 | 30 m/s | pitched to 50-65 degrees, 52 m/s to 9 in eight seconds, stalled, tumbled, down in 20 s |
| gunship | 0.40 | 30 m/s | the same, down in about two minutes |
| Cessna | 0.92 | 30 m/s | 55-67 degrees, half a minute under 1.1 times its stall, hanging on the propeller |
| light aeroplane | 5.75 | 30 m/s | 23 degrees -- the steep climb the user saw |
| airliner | 0.68 | 12 m/s | 11 degrees |

Only three kinds had a climb rate chosen in `fly_it_like_a`; every other wing flew the mixer's
default of thirty. And the mixer let a wing ask for the whole of it right down to the stall:
the allowance was airspeed over stall, clamped at one.

**The climb is derived now.** `gentle_climb` is the lesser of a climb ANGLE at cruise
(`AircraftMixer::climb_angle`, 0.10 rad) and 0.6 of what the engine can sustain there -- thrust
less the drag of flying level, times the speed, over the weight. An angle and not a rate,
because a rate that is gentle at seventy metres a second is a zoom at forty. **And it is paid
for in speed**: all of it at cruise, none of it at 1.3 times the stall, and a descent below
that, so a wing that has got slow puts its nose down instead of pulling. It was 1.1 for the
first build and was raised, because "careful not to stall" is not ten per cent over it -- and
since nearly every powered wing cruised exactly on its 1.3 floor, the cruise floor went to 1.45
with it (a glider keeps 1.3), or the climb would have had no band to be paid for across.

**Two more that the tests found.** Every autopilot looked its kind up from its MODEL, which
answers with the first kind that flies that way -- so every aeroplane took off on the light
aeroplane's stall, rotation speed and `ground_speed`. `AiPilot::kind` is the real one now. And
the tiltrotor's `ground_speed` of 60 is below its 69 m/s rotation, so the runway handed it to
the mixer on its wheels: on flat ground it rolled at 74 m/s with its nose on the tarmac for 45
seconds and never left it, where the same aircraft flown by hand at full power lifts itself
off at 71. `fly_itself` keeps `take_off` in charge of anything with weight on its wheels. A
tiltrotor with no route also held whatever height it had, where an aeroplane climbs to 520.

**A climbing leg is checked the way it is flown.** A gentle climb spends the first part of a
leg below the straight line that was tested clear of the terrain, so `clear_as_flown` tests
the climb and then the level part.

**More thrust where it was short**: the tanker from 38 to 48 kN, the gunship from 78 to 92.
Both could carry themselves and neither could climb with anything to spare.

**And a gentle climb has to look where it is going.** The first real-sky run after the climb
went gentle found what a flat test world cannot: the two light aeroplanes launched at 60 m
towards the south and north gates climbed into the lintels -- 90 to 110 m up, 500 m ahead --
at 103 and 108 m seven seconds later, where thirty metres a second had put them at 260; and
an airliner turning onto a leg hit something solid at 155 m and lost 48 m/s in a second. So
every half second each wing looks twelve seconds along its own velocity, and while something
stands in that line it may climb at three times its gentle rate towards 150 m more height,
still paid for in speed. With the clearance used as the overhead allowance too, the ground
itself blocked every climb-out below thirty metres; the look ignores anything lower than the
lower end of the line. `a_light_aeroplane_launched_at_a_wall_climbs_over_it` in
`tests/climb.gd` is the gate, as a 130 m wall.

**And the look and the leg both had to know who was flying.** The merged library, three
minutes of the real sky: one powered aircraft of 45 still came down -- a tanker added on open
ground. It turned onto a leg at a 52-degree bank, the turn carried it off the straight line
that leg had been checked along, and a massif face rose some 370 m under it in six seconds of
flight. The look-ahead did see it and climbed it at 10.7 m/s, but twelve seconds of a tanker's
climb is 130 m, and it hit the face at 389 m. Two changes, one for each half:

- **A leg is re-checked as flown, from where the aircraft is**, every three seconds, and dropped
  if it has less than half the 90 m it was chosen with (`kLegKeepClearance`); the next tick
  chooses another, or climbs to a height a route can be found from.
- **The look lasts as long as 300 m of the wing's own escape climb takes** -- the lesser of
  three times its gentle climb and what its engine holds at cruise (`sustained_climb`, the same
  arithmetic `gentle_climb` uses) -- between 12 and 40 seconds: about 14 for the light
  aeroplane and 28 for the tanker.

`tests/avoid.gd` holds both, in boxes of its own rather than the island's, so a reshaped
mountain cannot move it. A tanker level at 520 m with a face 1500 m ahead rising 160 m above
it; and a light aeroplane on a leg with a three-kilometre wall put across the leg five seconds
into flying it. On the library before this, the tanker crossed the face at 626 m against a
680 m top and lost 84 m/s in half a second, and the light aeroplane flew on at its waypoint and
into the wall.

**And the formations it moved, measured rather than guessed.** The first build re-checked a leg
with the whole 90 m it was chosen with, and smoke's light aeroplanes in formation went from a
median of 4 m to 28. Keeping a leg while it still has half that room did not bring it back (25),
so both suspects were counted instead: `ai_destination` reports `legs_dropped` and `escapes`, and
`the_flights_hold_to_a_wingspan` prints them per leader and per follower. The two leaders took one
new leg each in the run and one of those was a drop; the six followers started no escape climbs
at all. The drop was real: the leader was at (2877, 508, -4009) descending towards a waypoint at
450 m, and its leg passed 41 m over a rock box topped at 443 m some 3.4 km on. That single new leg
put one flight into a turn at the instant smoke sampled, so the check now judges the MEDIAN OVER
25 SECONDS of samples, at the same 15 m: 4 m on the library before this change -- what its single
sample read -- and 10 m after it. The worst sample is 76 m on both.

**And the wind is gone** (`Terrain.WIND` is zero). In the windy run two formation followers
flew into a ridge holding 434 and 442 m and a leader grazed it at 7 m; the same run in still
air hit nothing. With no wind there is no ridge lift and no downwind for a fire front to lean
along -- so a GLIDER has lost the ring of ridge lift that was its way home when the thermals
ran out, and is held up by the town, range and open-ground thermals and by fires alone, and the sea, the grass and the trees take a direction from `Terrain.SWELL_HEADING`
instead, because their shaders normalise it and a zero vector normalised is NaN.

Rejected: lowering the wheels' friction -- every kind reached its rotation speed in 13 to 30
seconds, so the roll was never the problem. And more thrust for every wing -- the light
aeroplane has five and a half times its own weight and still climbed at twenty-three degrees;
what was wrong was the ask, not the engine.

`tests/climb.gd` holds it: every wing with an engine, put down on flat ground and put into the
air at 300 m, left to its autopilot for three minutes. Flying at the end, never under 30 m once
60 m up, never climbing steeper than nine degrees of flight path, never slower than 1.1 times
its stall while climbing -- and seen climbing for at least five seconds, because the first run
passed a tiltrotor that had never climbed at all on both climb checks.

| | before: steepest, slowest climbing | after: steepest, slowest climbing, fastest climb |
|---|---|---|
| light aeroplane | 22.5 degrees | 5.7 degrees, 82 m/s against a stall of 55, 8.4 m/s |
| airliner | 11.6 degrees | 5.8 degrees, 72 m/s against 50, 7.3 m/s |
| tiltrotor | never left the ground | 6.0 degrees, 83 m/s against 57, 8.7 m/s; off the ground in 26 s |
| Cessna | 55.8 degrees, 23.9 m/s | 4.4 degrees, 52 m/s against 38, 4.1 m/s |
| gunship | 37.5 degrees, 11.8 m/s, then the ground | 5.4 degrees, 73 m/s against 52, 6.9 m/s |
| tanker | 55.9 degrees, 4.6 m/s, then the ground | 6.1 degrees, 57 m/s against 40, 6.1 m/s |

Twenty-four failures on the previous library, none on this one; the slowest any wing climbed at
was 1.37 times its stall, against the suite's 1.25 and the mixer's 1.3. The wall is crossed at
152 m with no more than 2.1 m/s lost in half a second, where the gentle climb without the
look-ahead flew into it and lost 70.

## FORTY MACHINES THAT FLY THEMSELVES

Forty aeroplanes, forty helicopters, ten cars and ten boats, on autopilots in
`../../ashiato-gd/src/cockpit/autopilot.hpp`, ported from the `pid_control` addon in
`../../pid-control`. The rule that addon is built around is the one that matters:

**A PID OUTPUTS THE LEVERS A HUMAN COULD HOLD** -- throttle, pitch, roll, rudder, brake --
and never a velocity or a force on the hull. Everything downstream is the same simulation
you fly. An AI that set velocities would be flying a different aeroplane from the one in
your hands, and the difference would be invisible until it mattered.

The shape is cascaded loops: an OUTER loop whose output is a LIMIT (max climb rate, max
bank, max yaw rate) and an INNER loop that tracks it. That is what stops an autopilot
pulling 4 g to fix a hundred feet.

| Model | Outer | Inner | Levers |
|-------|-------|-------|--------|
| airplane | altitude, heading | climb rate, bank | stick, throttle, rudder on the slip |
| helicopter | altitude, heading, speed | climb rate, yaw rate, **pitch attitude** | collective, tilt, tail rotor |
| car | heading | yaw rate | steering, throttle, brake |
| boat | heading | yaw rate | rudder, throttle, brake |

Four times as many in the air as on it, and their waypoints are kept OVER THE ISLAND: a leg
across open water is a leg spent somewhere nobody is looking, and the point of them is to
be something you meet.

### The nose is a fraction of the aircraft, not a fixed lump

A vehicle is a box and a box has no front, so there is a cone on the nose. It was 0.44 m
across whatever it was stuck on: a clear beak on the light aeroplane, which is 1.5 m wide,
and a pimple on the airliner, which is 3.8 m wide and 17 m long. The airliner genuinely had
no visible front, and "it does not seem to be oriented forward" is what that looks like from
outside. Both the cone's width and its length now come from the hull -- 2.09 m across on the
airliner -- and the wing's chord is capped against the SPAN as well as the fuselage, because
a 19 m wing with a 4.7 m chord is a rectangle that reads the same way round whichever way it
is pointing.

Nothing was wrong with the airliner's orientation. Everything was wrong with being able to
see it, which is the same problem to whoever is looking at it.

The back tapers too, in the hull's own colour. One bright cone on a symmetrical box tells
you where the front is only once you have found the cone; two different ends mean the
SILHOUETTE says which way it is going. And the airliner is blue, because it was within two
hundredths of the light aeroplane's white and the two fly nothing alike.

### "It is starting backwards", and nothing was reversed

The autopilot took any clear waypoint at least a leg away. They are scattered over the whole
island, so half of them are behind: a machine put into the world turned straight round and
left the way it came. From outside that is indistinguishable from being spawned facing the
wrong way, and it was reported as such.

It picks a waypoint it is already pointing at now -- within about 75 degrees, which is a
turn rather than a reversal -- and only drops that requirement if nothing ahead is clear,
because sometimes turning round genuinely is the answer.

### One mount per gunner

`CraftSystems` carries two turret angles, and turret stations take them in seat order. A
patrol boat with a gun forward and a gun aft has two people looking at two different things:
a shared mount would have them fighting over it every tick with nothing sensible to average,
which is not a formation problem to be solved, it is two jobs.

The gunboat is the first craft to use the whole seat model at once -- one person steering
and two more looking wherever they like without either of them touching the boat's course.
The Chinook is the first with a seat BEHIND the middle of the craft and turned right round,
which is what the yaw in a seat pose was always for.

### Cars run in convoys, and a convoy is not a flight

Three quarters of the cars run in groups of up to four, and most of those are nose to tail.
Three in ten run TWO ABREAST, because a world where every convoy is the same shape reads as
a conveyor belt.

Every distance in the formation guidance was wrong for a car by an order of magnitude. The
slots are 24 m apart rather than sixty, and the aim points are hundreds of metres because
they were sized for an aeroplane covering seventy of them a second: a car aiming 220 m ahead
to correct a 10 m crosstrack turns almost not at all. Scaled to the road -- correcting from
a car length, committed by thirty metres, aiming where a driver looks -- the convoys went
from 36 m of average slot error to **5 m, worst 15**.

There is nothing to stack up to on a road, so that term is off for a car. Not a special
case: it is the same rule with no room above it.

### Aircraft are drawn much wider than they collide

The collision hull stops at the fuselage on purpose: a box the size of a wingspan collides
with everything the aircraft flies past, and threading a gate becomes impossible for reasons
the pilot cannot see. But a 1.5 m box is also what an aeroplane looks like at two
kilometres, which is to say nothing, and a sky full of traffic nobody can pick out is a sky
with nothing in it.

So `Shape::span` lives in the simulation's geometry table with everything else, and the
renderer builds a wing, tailplane and fin from it -- 13 m of aeroplane around a 1.5 m hull,
a 12 m rotor disc around a 1.9 m one -- that the physics has never heard of. It is the one
place in this project where the picture and the simulation deliberately disagree, and the
smoke test asserts the disagreement rather than leaving it to be noticed as a bug.

### An aeroplane has to be ONE aeroplane

`tests/joined_parts.gd` asks **every craft in the game** whether its drawn parts touch each other,
and a craft whose parts do not is named on every run. (It began in `tests/aircraft_fidelity.gd`
covering seven aircraft; nothing about the fault is aircraft-specific, and widening it found nine
craft in pieces, four of which that suite had never looked at.) **It knows no part names, no craft names and
no dimensions**: it reads the drawn vertices of every visible mesh, unions the ones that share
space, and counts the groups -- so a part renamed, moved, resized or added is checked by the
same code and a new aeroplane is covered by existing.

It exists because on 2026-09-17 the water bomber was a fuselage with **eighteen of its
twenty-one parts floating in the air around it**, and every suite was green. `aircraft_fidelity`
held it to a published 9.02 m height and the drawn model measured 9.00 -- **because the fin TOP
had been placed at the height that satisfies the contract and the fin BOTTOM had never been
joined to anything.** The dimension was real, the source was cited, the number was right, and
the aeroplane was in pieces.

**A bounding box, a triangle budget, a feature roster and a three-view all describe a SET of
parts. Not one of them asks whether the set is a single object.** That is the same hole as the
sailplane meeting its height with a stub gun mount, and the stations standing outside the skin
their own craft drew.

Nine craft are on a known-failures list, each with its worst gap and what is actually floating,
and **the list cannot rot: a craft on it that turns out to be joined is reported as an error.**
The stand-out is the airliner, whose passenger windows 7 and 8 are drawn past the end of the
fuselage, 5.71 m aft of the fin. **They are geometry faults, not naming ones** -- each fix is a
decision about that aircraft's shape -- so they wait for whoever next models each craft. It caught its own first entry
that way -- the chinook was put on it from a visual report and is not in pieces at all. **A
missing aft pylon is a fault of SHAPE; this check finds OPEN AIR.** They are not the same fault.

Two consequences for anyone building an airframe. **Bed each part into its parent rather than
resting it against one** -- a joint drawn to touch exactly opens the first time either end moves.
And **give every part its own name**: `_add_airframe_part` called twice with one name leaves
Godot to rename the second to `@MeshInstance3D@9`, and an anonymous mesh cannot be found by
name, cannot be held to a feature contract, and does not read in a screenshot review as
something somebody put there. **Name it with every loop variable that surrounds it**, and
`tests/named_parts.gd` fails any craft that does not. Build a craft from OUTSIDE when you check it
-- `setup`, never `_show_body(true)`, which is the ghosted view from inside the cabin and hides
airframe; both of these suites were first written the wrong way and measured partial craft.

The two suites share one algorithm, `tests/drawn_parts.gd`, and so does `buildings_gallery_shot`'s
`_nothing_floats` in spirit -- but it is not the same check: it reads the plan's COLLISION boxes
over a whole base and expects one group per building, where these read DRAWN vertices and expect
one group per craft. A drawn part can float off a building whose walls are exactly right.

### A seat is where somebody sits, not what they shoot

`_build_turret` draws no mount on a craft with **nothing fitted to shoot with**, whatever its
seats are called, and it asks **every** mount rather than mount 0 -- a Chinook's ramp gun is
mount 1 and its mount 0 is empty.

The rule was first written as *no turret seat AND no gun fitted*, and **the AND is what put two
machine guns on the water bomber**: its two aft seats are `Station::Turret`, so the seat test
never fired. On the aeroplane whose own simulation comment reads "Nobody in the back of this
aeroplane is shooting at anything; they are looking at the ground, which is where the fire is."
The turret station is how the simulation says a seat looks outward and turns; the observers in a
water bomber's waist do exactly that, armed with binoculars. **The only authority for whether a
gun exists is the gun table.**

## FLIGHTS

Three quarters of the aircraft fly in formations of up to four. Aeroplanes fly **finger
four** -- one on the right, two stepped away to the left -- which is the shape you can
actually see from another aircraft. Helicopters fly a **trail**, single file, because they
are slow enough that a line reads better than a wall.

A follower holds a slot in the leader's own frame (right, up, behind) and has no route of
its own: its destination is a place beside another machine, and it moves. `set_ai_leader`
refuses a cycle, because four aircraft each following the next one round is a formation
with nobody deciding where it goes, and nothing about that looks wrong from outside.

**The leader does not have to be an autopilot.** Put a player in the lead machine and the
flight follows them.

### The heading bug is never the bearing to the slot

That is the whole of formation guidance, and it is not an optimisation. Flying at a bearing
is what an autopilot chasing a point does, and here it fails in a way that only shows up in
the air: when the leader turns, the slot swings across and lands in the follower's **rear
hemisphere**. A bearing controller sees 170 degrees of error and dutifully flies a full
circle to fix it, and the formation comes apart on every heading change.

So the heading bug is the LEADER'S heading plus a **clamped** intercept -- never more than
0.75 rad of cut toward the slot. The follower always flies roughly where the leader flies,
and closes sideways as a correction on top. Straight out of `formation_guide.gd` in
`../../pid-control`, which is where the 360 was found.

### The cut is SCHEDULED on how far out it is

A single look-ahead cannot do this job, and the failure is not subtle once you know what to
look for. Set it short enough to drag a follower back from two hundred metres and the
intercept is **saturated** for anything over about fifty -- which is bang-bang control: full
cut, overshoot, full cut the other way. Measured, that was 61 m of crosstrack error against
18 m along track and 0 m vertically, which is not a follower failing to catch up. It is one
swinging through its slot.

So both the aim point and the cap move with the crosstrack: short and hard (40 m, 1.05 rad)
when there is ground to make up, long and gentle (220 m, 0.20 rad) as it arrives, so the
last few metres are flown rather than fought.

Three more things were needed before the slots actually held:

**Turn feed-forward.** A follower sits most of a second behind its leader in time. Flying
the leader's CURRENT heading means starting every turn that much late and spending the
whole of it outside the slot -- and a flight whose leader is always turning toward its next
waypoint is a flight always mid-turn. Rolling in early by the leader's own turn rate closes
it: measured, 107 m of average error down to 82.

**A slower cruise, and that is a formation decision rather than a flight one.** Turn radius
goes with the square of speed, so a flight at 90 m/s needs 700 m to come round and spends
every turn strung out behind its leader. Capped at 70 it is 420 m.

**LONG LEGS.** The single biggest one, and it is not in the PID at all. The minimum leg was
250 m, which at 70 m/s is three and a half seconds of flight: a leader that arrives, turns
hard, and arrives again is a leader whose flight is permanently mid-turn. One flight on its
own, given legs 2.4 km long, held station to 29 m while the same aircraft in a world of
short legs were 105 m out. Aeroplanes now fly at least 3 km a leg, helicopters 1.5 km. It
also simply looks better: traffic that crosses the map is traffic, traffic that circles a
point is a fairground ride.

**A HELICOPTER DOES NOT GO WHERE ITS NOSE POINTS.** It goes where the disc is tilted, so a
follower that only yaws toward its slot crabs its way there and takes a long time about it.
On identical guidance, aeroplanes held 22 m and helicopters 89. For a machine that
translates, the heading bug stays on the FLIGHT'S heading -- the trail stays lined up -- and
the crosstrack is answered with a **bank** instead, which is how a helicopter actually
side-steps into position. That halved it.

**And the axis a helicopter formation is built on is the leader's TRACK, not its nose.**
Those are the same thing for an aeroplane, whose flight path follows its nose to within a
fraction of a degree, and they are only loosely related for a helicopter, which can point
anywhere while going somewhere else. A trail built on the leader's nose lays its slots
sideways across the flight path whenever the leader is crabbing, and the whole line flies at
an angle to where it is going. Built on the track, single file means single file: measured,
helicopter followers sit **0 degrees** off their leader's track on average and 2 at worst.

| average slot error | |
|---|---|
| where it started | 107 m |
| turn feed-forward | 82 m |
| slower cruise | 66 m |
| gain scheduling and long legs | 55 m |
| helicopters banking into the slot | 34 m |
| trails built on the leader's track | **33 m** |

Measured after half a minute: 35 of 44 followers within 60 m, average 33 m (30 across, 8
along, **0 vertical**), worst 99 m. Aeroplanes average 22 m, helicopters 44 m, and every
helicopter is pointing down its leader's path.

**Every seat on them is empty**, so the take-the-next-craft button walks straight into a
moving aeroplane and you simply have it: a human in seat 0 always wins, and the autopilot
takes it back the moment you leave.

The handover is where the bugs live, in both directions.

Going IN, the destination comes off the wire, because a vehicle somebody is flying is not
going anywhere in particular and a beacon standing in a field is worse than none.

Coming OUT, the autopilot does **not** resume from the loops it was interrupted with. It
may be a long way from where it last knew it was, at an attitude it did not choose, and its
integrators are still holding the last correction they made before a human took the
controls. Picking up where it left off puts a lurch in exactly the moment the player is
watching from the seat behind. It forgets the loops, forgets the leg, looks around and
chooses again.

The autopilots run on the SERVER only. Clients receive them as buffered interpolation,
because nobody else has their input and predicting them would be a guess resimulation could
never correct.

### The beacon, and why the route is replicated

While you are in a seat of something that is going somewhere, a tall column stands on its
destination and the panel reads the distance. Only your own vehicle's -- a sky full of
everyone else's waypoints is a sky you cannot see through.

`Route` is a **replicated component**, not a question asked of the server, and that is
forced: entity ids are per-world, so a client has no way to ask "where is the aeroplane I
am sitting in going". This way the answer arrives with the aeroplane.

It is separate from `VehicleState` for the opposite reason. `VehicleState` changes every
tick and is sent every tick; a route changes once a leg, perhaps twice a minute. As a Step
component it is sent when it CHANGES and costs nothing between, where the same three
numbers folded into `VehicleState` would be sixty-two more bits per vehicle per tick for a
value that had not moved.

**A job writes what a job declares.** The first version published the route from inside
`drive_vehicle`, which the simulation job runs, and the write silently did not stick: every
autopilot had a waypoint, the AI's own table said so, and the replicated component stayed
empty on the server that had just written it. `publish_routes` runs after the job, beside
`update_display`.

### Routes

`Terrain.waypoints(kind)` builds a pool per kind and registers it with the world.
**Where the roads are, which water is deep enough and how high is over the mountains are
the terrain's business, not the autopilot's** -- so the pool is generated the same way the
collision is, on every peer, from the same data.

The simulation then checks each leg against its own boxes before flying it, with a slab
test rather than a physics raycast: it has to give the same answer on every machine, and a
route is tested once and flown for a minute, so there is nothing to optimise.

**A vehicle passes over what it travels on**, and that is not a refinement. The island is
itself a solid box, so a car asked whether it might drive across the ground was told the
ground was in the way. Every car in the world sat still. The leg test takes an `overhead`:
an aircraft wants its full clearance above anything it passes, a car and a boat want zero,
because the thing under them is the road.

### The one that took all ten helicopters down at once

This game's pitch lever commands a RATE: hold it and the aircraft keeps rotating. The
helicopter mixer wired a speed error straight to it, which asks for a permanent nose-down
rate -- so every helicopter tipped past the vertical, pointed its rotor at the horizon,
stopped making lift and flew into the ground. All ten, simultaneously, which is at least an
unambiguous way to find out. Speed error now picks a tilt to HOLD and an inner loop holds
it.

Measured after half a minute: every independent machine has a route, all but three moved
more than 250 m, none is inside the scenery, and every one is still in its own medium.

### What a hundred and nineteen vehicles cost

| | |
|---|---|
| server and client together, per tick | 0.494 ms median, 0.573 p99 |
| the client alone | 0.136 ms |
| budget at 120 Hz | 8.33 ms |

The client is cheap because it **does not simulate what it is only watching**. It predicts
one vehicle and receives the other hundred and eighteen as buffered interpolation, so
computing lift, drag and tyre loads for them is work thrown away a moment later. Their
transforms are still written from the replicated state, because your own vehicle has to be
able to collide with them.

**Do not time this from inside the scene tree.** Headless still paces its main loop to real
time, so wall clock over a physics frame measures the frame PERIOD: the first version of
that check reported 8.319 ms against an 8.33 ms budget and would have reported it whatever
the work was. `tests/hitch_probe.gd` ticks the worlds by hand, which is the only way to
find out.

## A ROTA FOR WHAT AN AUTOPILOT DOES NOW AND THEN

Asked for on 2026-09-14: "we just want to be able to run lots of ai state machines without having to run them every
physics tick on the server. so splaying them out gives us responsiveness but doesn't overload the system for every ai
fsm that gets added" -- work that runs "roughly every 10 ticks but not more than 60", with a callback.

Before it every wing kept two float countdowns of its own in `AiPilot`: a look along its flight path every half second
and a re-check of its leg every three, phased off its seed. Nothing anywhere said how many ran on one tick, and a sky of
five thousand wings would have run every one of them on time whatever else the tick had to do.

`../../ashiato-gd/src/cockpit/chore_rota.hpp` is the scheduler, with no Godot in it. A KIND is a name, a target interval,
a limit and a budget; a CHORE is one kind of work for one id.

- **A chore comes due on its target**, give or take a quarter of it, the jitter HASHED from (stream, kind, cycle): a
  world started twice serves the same chores on the same ticks, and no hash map's iteration order enters into it. For an
  autopilot the stream is its seed, which comes from where it was put, for the reason the seed does: an entity id moves
  when something is added to the spawn list.
- **Each tick serves the due chores most urgent first** -- ticks waited over the limit, which inside one kind is whoever
  was served longest ago -- up to the kind's budget. Waiting chores sit in a timing wheel one limit wide, then in a heap
  per kind, so a tick costs what it serves and not what is registered.
- **At the limit a chore is FORCED**, over budget, and counted as an overrun. No interval is ever longer than the limit,
  and a budget too small for the sky shows as a number rather than as an aeroplane that stopped looking.
- **An urgent chore** comes due on a quarter of its target AND is forced at a quarter of its limit, because the queue
  is served by DEADLINE -- last serve plus limit, earliest first -- and a chore that only came due sooner would wait
  behind every older one on a contended rota exactly as long as before. With nothing urgent every limit in a kind is
  the same, and earliest deadline is simply whoever was served longest ago. Nothing in the game flags one yet.

**The budget is a COUNT or a SHARE a tick, never microseconds.** A count is a flat ceiling. A share is "only do some
percentage of the planes per tick", in the user's words: ceil(registered x share), never less than one, held in
millionths so it is exact. A budget in time serves different chores on different ticks depending on what else the
machine is doing, and on this workstation, with five lanes running Godot at once, two identical worlds would never
agree. Time is measured per kind and reported; it decides nothing.

**It is served after the physics, outside the job**, once for every frame sync simulated (`serve_chores`). Inside the
job a chore runs between one vehicle's forces and the next and writes what the job does not declare. After
`server_->tick` every body stands where the next frame's `drive_vehicle` will read it, so a look taken there sees what a
look at the top of the next frame would have. `fly_itself` marks a wing `aloft` once it is past `take_off`, and a chore
does nothing for a wing on its roll or one a human is flying -- the countdowns did not run there either. Server only: a
client registers nothing, and nothing the rota does is replayed by a resimulation.

| kind | target | limit | budget: a share of `kChoreHeadroom` / target | the 46 powered wings `tests/sinking_probe.gd` flies |
|---|---|---|---|---|
| `look_ahead` | 0.5 s (60 ticks) | 1.0 s | 1/30 of those registered | 2 a tick, against 0.77 coming due |
| `leg_check` | 3 s (360 ticks) | 6 s | 1/180 | 1 a tick, against 0.13 |

**The defaults are DERIVED, and they do not bind today.** N chores on a target of T ticks come due N/T a tick, so a
share of two over T pays for twice that however big the sky gets; the flight suites run against main measure moving the
countdowns onto the rota, not a squeeze. A ceiling that does not grow with the sky is a count, set with
`set_chore_budget(kind, n)`; a share is `set_chore_budget(kind, 0.02)`.

**Two behaviours did change, and are measured rather than assumed.** A look comes round every 45 to 75 ticks where the
countdown made it exactly 60, and the look reaches a second further (the worst wait for the next one).

**The look reaches as far again as the longest wait for the next one**: `look_seconds` is the climb's own look (12 to
40 s, see `kLookRise`) plus the look kind's limit in seconds, read off the kind, so a rota retuned to wait longer looks
further with it.

`CockpitWorld.chore_report()` gives each kind's settings, how many are on it and waiting, served, overruns, served a tick
(last, mean, most), the mean and worst interval in ticks, and microseconds a tick; `digest` folds every serve.
`set_chore_budget(kind, n)` squeezes one; `reset_chore_report()` starts a window.

### A script's own state machine goes on the same rota

```gdscript
Sim.server.add_chore_kind("think", 10, 60, 5, _think)   # roughly every 10 ticks, never past 60, 5 a tick
Sim.server.add_chore("think", id)                        # any int the script owns; an entity id comes off at retire
Sim.server.set_chore_urgent("think", id, true)           # a threat: a quarter of the target, a quarter of the limit
Sim.server.remove_chore("think", id)                     # from inside _think too

func _think(id: int, waited: int) -> void:               # waited: ticks since this chore was last served
```

**A Callable chore runs on the main thread, inside the server's tick**, so what it costs is tick time: the budget is how
that is kept in hand. Served in the same pass as the autopilots' chores, on the server, after the physics and outside the
job, so a callback may spawn, retire, add or remove chores -- its own included -- add a kind, or change a budget. A
removed chore still in the tick's batch is passed over and nothing after it is; a budget changed mid-serve holds from the
next tick, since each kind reads its budget once before serving; a callback whose object has been freed is passed over.
An ERROR inside a callback is reported by Godot and `call` returns; it is not in the suite, because the runner fails any
suite that prints a SCRIPT ERROR and its allowlist is for messages the C++ provokes. Refused, with a warning: on a client or before
`start`, a name already on the rota, a target of none, a limit shorter than the target or past `kLongestChoreTicks`, and
a Callable that cannot be called. The world copies the Callable before calling it, because a callback may tear the world
down and clear the table it came from. `add_chore`'s optional `stream` is what the jitter hashes from; it is the id
unless given, and wants to be something that stays put when other things are added, as an autopilot's seed does.

**What a call costs.** 0.31 to 0.41 microseconds for a Callable that does nothing, in three runs, measured by the world
around each call: a thousand ids every ten ticks is 100 calls and 31 to 41 microseconds a tick, on 2026-09-14 with other
lanes' suites running.
That is the price of the Variant round trip into GDScript and back, before the script does anything, and it is paid per
chore served -- which is what the budget is for. The rota's own bookkeeping is the same as for a C++ chore.

### How it is held

`tests/rota.gd`, in hand-ticked worlds of the real autopilots on flat ground:

| | measured |
|---|---|
| 48 wings, 40 s, default share: look mean interval, worst, overruns | 60.18 ticks against 60, worst 75 of 120, 0; 2 a tick paid for, 0.80 served, most 2 |
| the same, leg check | 360.56 against 360, worst 450 of 720, 0; 1 a tick paid for, 0.13 served |
| 240 wings on a share of 0.0125 | 3 a tick, mean 80.0, worst 80; half of them retired, 2 a tick; 1.5 and 0 refused |
| 240 wings, look budget 3 a tick (they want 4) | mean 80.0, worst 80, 3.00 served a tick, 0 over budget |
| 240 wings, look budget 1 (the limit alone needs 2) | mean 120.0, worst 120, 2,400 of 4,800 over budget |
| leg check with no budget at all | 880 served, 880 over budget, every interval 720 |
| two worlds built alike, ticked in turn | the same digest; one aeroplane moved 16 m, a different one |
| a script's kind, 200 ids every 10 ticks at 5 a tick, never past 60 | 17,995 calls counted by the callback and by the report; most in a tick 5, mean 39.8, worst 44, none over budget |
| one of them flagged urgent on that contended rota | served every 2 ticks, against an urgent limit of 12; with its deadline broken back to the ordinary limit, every 40, as long as the crowd |
| a callback that removes its own chore on its third call | called 3 times |
| three chores on one stream, the first removing the second on its fifth call | the second called 4 times, the first and third 71 each |
| a callback adding ten chores and a new kind mid-serve | all ten served, the new kind's chore 69 times, worst wait 12 |
| a callback setting its kind's budget to 2 mid-serve | at most 2 a tick from the next tick, none over budget |
| a callback whose RefCounted is freed | passed over; the other kinds carry on |

Each of the later checks was broken on purpose too. A share rounded down instead of up gave 1 a tick for 120 wings where
it should be 2; a batch abandoned at the first removed chore, rather than passing over it, left the third chore on the
stream at 70 calls against 71. A look's reach that ignored the live limit read 9.49 s past a 480-tick limit, under the
climb's 12 s floor; a batch checked by generation, not by who a chore is, did not serve the flagged and re-timed chores
on the tick they were changed.
| a kind with a name taken, no target, a limit under its target, or no callback; a client | all refused |

**It passed on the library before it, and that was the first thing it found.** Every section threw on its first call to a
method that library does not have, the error ended the function, and a suite that only counted failures printed
RESULT=PASS. It counts sections now, and on that library prints `every_section_ran_to_its_end (0 of 4)`.

**And a deliberate break fails it.** Forcing at `waited > max` instead of `>=`, with a static counter in the jitter shared
by every world in the process: a starved look worst 121 against a limit of 120, a leg check with no budget 721 against
720, and two worlds built alike with digests -230753899c9d0d4b and 7116f724e9bfe622. The uncontended limit check does not
catch the first break, and cannot: an uncontended chore never reaches its limit.

**The board says whether the chores keep up.** The sky's status line -- the flat mirror of the HUD -- ends with each
built-in kind's chores served a tick and its worst wait against its limit (`look 0.8/tick worst 75/120`), read from the
SERVER's world: on a host `Sim.client` is the client world, which has no rota to report.

### Unchanged, measured against main

Moving the two countdowns onto the rota changed two things about a wing: a look comes round every 45 to 75 ticks where it
was exactly 60, and it reaches a second further (the look kind's limit). Each suite below ran on main's double library
(A) and the rota's (B), interleaved, on one editor (main's llvm-mingw double build), with no compiler or linker running in
any lane, on 2026-09-14 before the rebase onto terrain's GroundField -- which does not touch flight, so the comparison
stands.

| | main | the rota |
|---|---|---|
| climb: every check | pass | pass |
| climb: light aeroplane at a 130 m wall | 152 m up, 2.1 m/s lost | 148 m up, 3.2 m/s lost (the strike is 20) |
| climb: slowest climbing speeds, steepest climbs, lowest once flying | e.g. tanker 57.1 m/s, 5.8 deg, 62 m | 57.4 m/s, 5.8 deg, 60 m; every kind within 0.4 m/s, 0.1 deg and 2 m |
| avoid: tanker over a rising face | 688 m, 1.0 m/s lost | 687 m, 1.0 m/s lost |
| avoid: light aeroplane whose leg is blocked | never inside the wall, goes the other way | the same |
| smoke: flights hold to a wingspan, 25 s | median 10 m, worst 76 m | median 10 m, worst 76 m |
| smoke: holding their slots | 16 of 18 within 60 m, worst 62 m | 17 of 18, worst 60 m |
| sinking_probe, seeds 0-4: powered wings under 30 m at 180 s | 1 on seed 0 (the airliner parked by a massif shoulder, still on its roll -- see WHAT IS NOT HERE YET), 0 on seeds 1-4 | the same: 1 on seed 0, the same airliner; 0 on seeds 1-4 |
| sinking_probe: lowest pass once off the roll, after 60 s | seed 0 a gunship at 17 m (88 s); seeds 1-4 51 m | seed 0 51 m; seed 2 a Cessna at 26 m (175 s); seed 3 a tanker at 50 m; seeds 1 and 4 51 m |

**Each library against itself is identical.** Climb, avoid and smoke were run twice on each, and no line of any of them
differed: every difference in the table is the change, and none is a run's noise. The sinking probe's lowest passes move
both ways -- a low pass main made on seed 0 is gone, one appears late on seed 2 -- which is the same look-phase effect on a
three-minute flight: which wing sees a slope first moves, and nothing new comes down.

The only move bigger than a few per cent is the light aeroplane at the wall, and it is the look's phase: a look served on
a jittered tick sees the wall a few ticks earlier or later, and the climb it starts is correspondingly earlier or later.
Crossing 148 m against 152 over a 130 m wall is inside what the check allows by a margin of 18 m and 17 m/s.

**And hitch is the same**, timed as its own pair on a quiet machine after the rest: tick medians 0.084, 0.082 and
0.084 ms on main against 0.081, 0.081 and 0.082 on the rota, the whole game 0.366 ms on both, and the client alone 0.089
against 0.090.

### What it costs as the sky fills

`tests/rota_probe.gd` (a probe) builds a server world by hand with the island's boxes and waypoints, puts 100, 1,000 and
5,000 wings on it at 250 to 900 m -- among the rock, where a look does real work; flown at 1,100 m and up a look skipped
nearly every box and cost 0.36 microseconds -- and ticks it by hand in blocks of 600, three regimes interleaved on the one
world: ROTA (the shipped share), STRETCHED (a flat count a tick near what a thousand wings want, with limits long enough
that five thousand are not forced, via `set_chore_limit`), ON TIME (no budget: every chore on its hashed target, which is
what the countdowns did) and ROTA UNTIMED (the shipped share with the breakdown off, which is what timing costs). On
main's library the same probe times the countdowns themselves.

`CockpitWorld.set_tick_breakdown(true)` times where a server tick goes; the probe prints it per regime. Measured
2026-09-14, stock single-precision editor, per tick, the median over 4 blocks of 600 ticks of each block's mean, with no
compiler or linker running in any lane for the whole run (the lane's load log) and 4 to 13 per cent CPU outside it:

| microseconds a tick, default share | 1,000 wings | 5,000 wings | per wing at 5,000 |
|---|---|---|---|
| the whole tick | 2,549 | 24,146 | 4.83 |
| forces (`drive_vehicle` less the autopilot) | 974 | 9,827 | 1.97 |
| the Box3D step | 713 | 4,553 | 0.91 |
| display (`update_display`) | 187 | 2,269 | 0.45 |
| after the step: routes, levers, crew, turrets, seekers, rounds, missiles, fires, tanks | 163 | 2,100 | 0.42 |
| sync: `server_->tick` less every job in it | 123 | 1,650 | 0.33 |
| the autopilot's mixers, the PID step | 132 | 1,422 | 0.28 |
| the autopilot's guidance: route, formation, acting on the look | 147 | 1,053 | 0.21 |
| reading poses back from Box3D | 67 | 1,012 | 0.20 |
| **the chores: look and leg check, with the rota's bookkeeping** | **36** | **235** | **0.05** |

The timers cost 7 to 8 per cent: the same ticks untimed are 2,385 and 22,260 microseconds. Main's countdowns, untimed,
interleaved: 2,529 and 2,314 at 1,000 wings, 27,061 and 22,514 at 5,000, against the rota's 2,385 and 2,677, and 22,260
and 24,747 -- the same, within a spread as wide as the difference.

**The chores were never what a big fleet's tick is made of.** They are one per cent of it; the vehicles' own forces and
the Box3D step are sixty. Five thousand autopilots on one server is a physics and replication problem before it is an AI
one, and everything that grows faster than the fleet -- forces from 0.97 to 1.97 microseconds a wing, display from 0.19
to 0.45, after-the-step from 0.16 to 0.42 -- is outside the rota.

**What the rota does, shown directly.** The same world, the same two chores, as the fleet grows five-fold:

| chores a tick | 1,000 wings | 5,000 wings |
|---|---|---|
| every chore on its target, as the countdowns did | 33.9 us; 16.7 looks, 2.8 leg checks | 222.6 us; 83.4 looks, 15.7 leg checks |
| the default share | 36.2 us; the same | 235.4 us; the same, 0 overruns |
| a fixed budget: 16 looks and 3 leg checks, limits 480 and 2,880 ticks | 34.8 us; 16 and 2.8; look every 62.5 ticks | 71.8 us; 16 and 3; look every 308.9 (worst 313), leg check every 787.6 (worst 1,028); 0 overruns |

Under a fixed budget the work a tick does not grow with the fleet -- 16 looks and 3 leg checks at both sizes -- and the
intervals stretch instead, never past their limits. The microseconds still roughly double, and not from the chores: each
look costs 1.2 microseconds at 1,000 wings and 1.8 at 5,000, and the rota's own bookkeeping, a heap as deep as the chores
waiting, is 8 microseconds a tick against 35. The share, by design, grows with the fleet; it is "some percentage of the
planes per tick". The earlier cut of this probe capped the look at 4 a tick with the shipped 1-second limit: 5,000 wings
need 42 a tick at that limit, so every look was forced (90,400 overruns in four blocks) -- a cap is flat only between cap x
target and cap x limit chores, and past that the limit sets the rate, which is the rota's promise.

**And inside the forces**, from a build that splits them, the next quiet run (2 blocks each; the tick 2,388 and 21,251
microseconds):

| microseconds a tick | 1,000 wings | 5,000 wings | per wing, 1,000 / 5,000 |
|---|---|---|---|
| what is under the wheels: `deck_under` and a ray down in `stands_on_something` | 428 | 3,026 | 0.43 / 0.61 |
| what the air is doing: `air_at` | 49 | 265 | 0.05 / 0.05 |
| the rest: aerodynamics, engine, the forces handed to Box3D | 481 | 5,436 | 0.48 / 1.09 |

### Five thousand autopilots in a 120 Hz tick: what would have to move, proposed and not built

A 120 Hz tick is 8,333 microseconds, which for 5,000 wings is 1.67 a wing; a wing costs 4.45 untimed today. Scheduling
alone cannot get there -- the chores are 0.05 of it -- and nothing below is built. In the order of what each buys:

1. **Ask what is under the wheels only near something to stand on.** Every winged craft, every tick, walks every carrier
   deck and casts a Box3D ray straight down, a metre and a half, to learn whether its weight is on its wheels: 3,026
   microseconds at 5,000 wings, 14 per cent of the tick, and more a wing as the fleet grows. A craft higher above the
   ground than the tallest static box plus its own legs cannot be on its wheels or a deck, and one number taken when the
   boxes are added makes both questions free for everything above the island's highest rock; streaming's per-cell grid,
   when it lands, makes it free over lower rock too. `take_off`, the gear's `clear_of_the_ground` and the nosewheel keep
   asking wherever the answer can be yes. No flight change: the answer is the same, only not asked.
2. **A dedicated server does not build the display.** `update_display` captures every vehicle for a renderer: 1,933
   microseconds at 5,000 wings, 9 per cent, on a server nobody draws on. A switch at start; no flight change.
3. **After the step, cost what changed.** Routes, levers, crew controls, turrets, seekers, rounds, missiles, fires and
   tanks grow faster than the fleet, 0.16 microseconds a wing at 1,000 and 0.37 at 5,000; `publish_routes` and
   `publish_levers` walk every autopilot every tick to write the few that changed. A dirty list written where the change
   happens makes them cost the change. No flight change.
4. **Guidance on the rota; the mixers every tick.** Guidance -- the bugs, the waypoint, the formation arithmetic -- changes
   over seconds (926 microseconds at 5,000 wings); the mixers are the rate loops that move a surface (1,254) and stay at
   120 Hz, because every stability fix in this file -- the airliner at its stall, the follower with no rate term, the
   helicopter spring with no damper -- was rate-loop damping tuned at the tick, and those gains closed at 10 Hz ring. As a
   chore every 12 ticks with a limit of 24, guidance costs about a tenth. In flight, a follower's aim point and its
   leader's turn feed-forward are sampled 100 ms apart instead of 8, less than the turn anticipation already applied;
   `the_flights_hold_to_a_wingspan` and `the_flights_settle_rather_than_hunt` are the gate, and a take-off roll stays every
   tick because `take_off` is a hand on a runway.
5. **The step is the physics.** Box3D with 5,000 bodies at four substeps is 4,187 microseconds. Fewer substeps for craft
   far from anything, or letting AI that no client predicts sleep while nothing is near, are the levers; each changes
   flight and is measured by `tests/climb.gd` and `tests/smoke.gd`.

1, 2 and 3 change nothing about how anything flies and would take roughly 5,900 of the 22,260 microseconds: about 16
milliseconds a tick, still twice the budget. 4 and 5 are flight changes for a lane of their own, with the formation and
climb suites as the gate. A thousand autopilots fit a 120 Hz tick today (2,385 microseconds); five thousand do not, and
the rota was never going to be what made them.

### Found while pricing it: a dropped leg was a tick of several milliseconds

`recheck_leg` used to call `what_blocks` for every leg it dropped, to record which box the leg came nearest to, for smoke
to print. It samples the leg every ten metres against every box, and a leg is kilometres long: in `tests/rota_probe.gd`'s
sky, one tick that dropped a leg cost 4,066 to 10,612 microseconds, where the re-check itself costs a few. The rota
bounds how many chores a tick serves and cannot bound that. With it gone the leg check's worst tick is 79 microseconds at
1,000 wings and 330 at 5,000. The box is worked out when `ai_destination` is asked now,
from the dropped leg's two ends -- the same flown path the drop tested, since `top_of_climb` reads only what is set at
spawn -- and nothing that flies reads it. Smoke's one dropped leg names the same box both ways: centre (-481, 412, -4784)
at 41.1 m from the path as flown when it was worked out at the drop on main, and 42.5 m worked out when asked, the leg
dropped 23 m further along because the look now comes round on a jittered tick.

## TWO SETS OF CONTROLS, ONE AEROPLANE

`VehicleControl` is the base class for anything a hand can reach out and move, and there is
a set of them in front of EVERY seat rather than one set per craft. Two pilots have two
sticks, and the whole point is that each can see the other move theirs.

| | |
|---|---|
| `ThrottleLever` | one axis, LATCHED -- it stays where you put it, which is why it lives on the command bus |
| `CollectiveLever` | one axis, latched, PULLED UP rather than pushed forward; the helicopter's |
| `FlightStick` | two axes, SPRINGS BACK -- no position worth remembering, so it rides the input frame |
| `ControlYoke` | two axes, a wheel that ROLLS as well as moving fore and aft; the airliner's |
| `CrewButton` | no axes, squeezed to toggle ONE lamp the whole craft shares |
| `RudderIndicator` | not a control at all: nothing grabs it, it shows where the rudder is |

`roll()`, `pitch()`, `throttle()` and the centring spring live on `VehicleControl` and not
on the subclasses, because the rig holds "the thing that flies it" and "the lever beside
it" without caring which it got. Typing the rig's stick as a `FlightStick` crashed the
moment anybody sat down in the airliner, and typing its lever as a `ThrottleLever` would
have done the same in a helicopter. A subclass now says only what is different about it:
how strong its spring is, where its grip is, and which way its hand moves.

They are children of a seat anchor like everything else that rides in a vehicle, so a grab
at 300 kph is the same arithmetic as a grab on the ground: the hand pose and the control are
in the same frame and the aeroplane's motion is not a term in the subtraction.

**The aeroplane gets the average of the hands actually ON the controls -- per axis.** Two
columns on one linkage have ONE position, so what the aeroplane gets is one demand and not
two. Measured: both sticks hard over the same way gives 2.33 rad/s, hard over in opposite
directions gives 0.00, and one pilot alone gets all 2.33 of it.

That last number was 1.16 until the linkage was drawn. Averaging over every occupied flying
seat halved everything the pilot did whenever a copilot was sitting there with their hands
in their lap -- full right aileron showed on the yokes as 0.40. An idle yoke is dragged
along by the moving one, it does not fight it. So a seat joins the average only on the axes
it is actually deflecting, past `kHandsOn` of 0.02. Per AXIS and not per seat, because a
copilot with a hand on the throttle and none on the yoke is on the throttle only.

The brake is the exception and stays on the maximum, because a brake is a thing either crew
member may apply on their own authority.

**Each seat's control positions are replicated, and that is a separate thing from the
input.** The input is one client's demand, is never replicated, and exists to be merged.
`CrewControls` is the state of the physical controls in a shared cockpit and its whole
purpose is to be looked at: the server is the only machine with everybody's input, so it
publishes where every lever is and both clients read it back. Measured, with the pilot at
0.85 throttle and half right stick and the copilot at 0.20 and three quarters left: each of
them sees the other's, to within the wire's quantisation.

**And every control on the linkage is drawn AT the linkage.** `CrewControls` carries
`linked_throttle`, `linked_x`, `linked_y` and `hands_on` beside the per-seat values: where
the controls actually are, and who is moving them. A copilot with their hands in their lap
watches their own yoke and their own throttle move with the pilot's, which is what those
controls do in an aeroplane and is the only way to see the other seat's inputs without
staring across the flight deck.

It is deliberately the FLYING value and not the pilot's alone. A yoke showing one seat's
input while the aeroplane obeyed something else would be lying about what the aircraft is
doing, which is the one thing a control position is for. With one pair of hands on it -- the
usual case -- the two are the same number anyway. `hands_on` says which seat is moving it,
and the pilot wins ties, because when two people are flying it is the pilot who is flying.

Your OWN control, while you are holding it, is drawn from your own hand and never from the
wire -- applying a value a round trip old would fight the hand holding it. Let go and it
rejoins the linkage.

**ANY CONTROL IN THE CRAFT, not just the ones in front of you.** A control used to belong
to a seat: `is_mine` was set on this player's four, and `offer_hand` refused every other
hand. That is not what two people in one cockpit do. They reach across it -- to each
other's levers, and to whatever sits on the centre line between them -- so ownership by
seat is gone and what decides is distance, which is what `offer_hand` was already measuring
anyway.

Two lists in `PilotRig`, answering two questions. `_my_*` is what is in front of THIS seat:
what the keyboard drives and what the control frame falls back to. `_reachable` is every
control in the craft, gathered from every manned seat through `controls_for`, which is
already where anything the VEHICLE owns rather than a seat gets spliced in.

**Reaching is only worth anything because the frame is read from what is HELD.** A hand on
the other seat's throttle has to BE the throttle this player is sending. Read the frame
from this seat's four instead and the lever moves under the hand and the wire puts it
straight back a round trip later, which is exactly what happened first time.

What keeps a hand out of somebody else's aeroplane is no longer a flag but the shape of the
list: it is built from the `VehicleView` this rig is sitting in, so another craft's controls
are never candidates. That is better than a flag, which can be left set.

Two consequences worth knowing. The grip-separation rule below stops being tidiness and
becomes correctness -- with no ownership check, spacing is the only thing between a hand
and the wrong lever, and the smoke suite already measures every pair across the whole
crew. And every button in the craft is connected to this rig, which is safe because a press
only ever happens when THIS rig puts a hand on one: other seats' controls are moved by
`apply`, from the wire, which emits nothing.

**One hand, one control**, asked FRESH for every control rather than from a list taken at
the top of the frame. A hand that already has hold of something is offered to nothing else
until it lets go: the controls sit within a few centimetres of each other on one console, so
without it a fist closed round the stick still pressed whatever it swept across on the way.

The first version took a snapshot of who was holding what before the loop, which moved the
bug one step later rather than fixing it -- a hand that grabbed the throttle on the first
pass was still recorded as free when the button came round on the third, and pressed it. The
test grabs a control and reaches for another IN THE SAME FRAME, which is the case a snapshot
gets wrong.

**And the button is the smallest possible piece of craft-local shared state.** No physics,
no external effect, nothing to get right except that everybody aboard sees the same thing.
If that works, so does every switch shaped like it, which is the entire reason for building
it before building any of them.

**One lamp, and every switch in the craft is wired to it.** Which seat pressed does not come
into it, which is what makes this shared state at all: it used to be a bit per seat, and
four independent lamps that happen to share an aeroplane demonstrate nothing. It is
**squeezed**, not brushed -- touch alone was enough once, and a hand resting near the
console toggled the cabin every time it drifted within a few centimetres.

### Past the fourth seat: a craft with sixty-four (lane/seats, 2026-09-18)

Asked on 2026-09-18, "should a craft be able to have more than 4 seats?": **"yes, no max."**

**The limit on PEOPLE ABOARD is the session's player cap, not the seats.** A craft may be built with 65,534 seats. What
it keeps and sends is one entry per person aboard, up to `kMostAboard` (sixteen when this landed, sixty-four since the player cap went to 64: see "Sixty-four players"), and `Net.host_refusal` will not host more
players than that, so a free seat is never refused for want of room in the list.

**Every width is one number in `cockpit_components.hpp`**: `kSeatBits` (16, a `SeatId` in memory), `kShortSeatBits` (2),
`kMostSeats`, `kMostAboard`, and the sentinel `kNoSeat`, which `kAnySeat` and `kNobodyHandsOn` are. `Sim.seat_limits()`
hands them to GDScript. `Sim.ANY_SEAT` is **-1**, not the library's sentinel: it was 7, and a craft may now have a seat 7
to ask for.

**A seat on the wire is the busbits short form**: a form bit and two bits for seats 0 to 3, or sixteen. "Any seat" and
"nobody's hands" are one bit. So a craft whose crew sit below seat four costs at most one bit a field more than it did,
and the full input frame went from 342 bits to 340.

**`Seats` and `CrewControls` hold who is aboard, in seat order, not every seat.** Four occupant bytes and four seats'
hands on every cabin became a count and one entry per person. Each has two forms and the writer sends the smaller: the
old four-seat layout (one form bit dearer) or the list, where each seat is its distance past the one before, so a seat
cannot be named twice. An unmanned craft's `Seats` is 6 bits where it was 32. `put` is the only writer of `Seats` and it
replaces, so a double occupancy still cannot be written; `deserialize` refuses a record naming one client twice.

**A kind is fitted with more seats by `Sim.fit_seats(kind, [{position, yaw, station}])`**, a process-wide table like
`fit_channels`: refused while any world runs, and ALL OR NOTHING, because a seat's number is its place in the list and
dropping a bad one would renumber every seat after it. Seat 0 must be a pilot's. Nothing real is fitted yet: only the
suite does it (see What's next in the repository's seats learnings of 2026-09-18).

**The CREW page folds a long cabin.** `CrewManifest.cells`: past `FOLD_PAST` (8) seats, the free seats are one cell per
station, "OPERATOR ×9", whose JOIN asks for the first free seat of that station; everybody aboard is a cell of their own;
cells wrap `ROW_SEATS` (4) to a line under the first. A craft of four seats or fewer draws exactly the row it always did.

**Refused, never masked.** A JOIN on seat 5 of a four-seater was turned into "any free seat" and answered "joined"; it is
now "no_such_seat", and a seat the wire cannot name is counted in `refused_seats()`. `seat_pose(kind, 5)` answered seat
0's pose; a seat the table lacks is `{"valid": false}`.

Measured, `tests/many_seats.gd`: five joiners in seats 7, 9, 11 of twelve and 40, 63 of sixty-four, every machine
agreeing, the spectator included. Before and after on the same tree: `wire_budget` peak 1,636 B a tick both;
`bulk_load` 0 craft x 8 peers 40.3 -> 39.4 kB/s a client, 200 craft x 8 peers 247.6 -> 247.6.

**Where "no max" costs: drawing.** A manned craft builds a `CockpitStation` for EVERY seat, occupied or not
(`VehicleView.man`), so a crew arriving next to you is seen arriving. `tests/many_seats_shot.tscn`, the Chinook with the
whole craft in frame, on this RTX 5080: its own four stations are 617 nodes, 140 draw calls
and 0.16 ms of CPU render
and built in 62 ms; fitted with sixty-four, 14,938 nodes, 2,386 draw calls, 2.06 ms of CPU render, and **1.15 s to
build, in one frame, when the first person sits down**. The counts are exact; the milliseconds come from rounds that
another lane's build overlapped (17:52-17:57 and 18:57-19:03), so they are an upper bound until a quiet slot redoes them. The wire does not notice sixty-four seats; the renderer and
that hitch do. Seats past a craft package's own stations (and every seat of a fitted kind, whose package's contract
is then stale) use the legacy station scene and warn once each.

### The crew board is a placard by the hip, and CrewBoard alone says where (lane/crewboard, 2026-09-18)

The user, 2026-09-18: **"let's remove the GIANT PILOT screen or make it much smaller, it's good to know who is in what
seat but the current panel that shows that data is too large (this should affect all planes)."** That was `CrewBoard`:
0.34 x 0.175 m with 4 cm letters, 0.21 m under the eye and 0.36 m ahead beside the flight display, its inner top corner
26 degrees off the nose. **It is now 11 x 5.5 cm with 7 mm capitals, beside the hip on the outboard console**: 0.57 m
from the eye, 60 degrees below it and 65 to the side, tilted up and turned in. That is about 12 mrad of capital, some
15 pixels of a headset's 0.8 mrad pixel, and it read cleanly in the eye shots
(`screenshots/2026-09-18/cockpit-crewboard-*`, `station_shot -- --craft --crew`). It was first put 0.43 m under the eye
and 0.22 m ahead, where it covered the map screen's lower corner. 0.10 m further aft it clears the map.

**Its size and place are `CrewBoard`'s constants (`placement`, `half`), and nothing else types them.** `CockpitStation.fit`
sets the board there before the mirror, so no seat scene carries a transform for its `Crew` node. The authored packages
are what `tools/generate_authored_packages.tscn` read off a fitted station: move the board by changing the constants and
regenerating, never by editing a scene or a JSON. `_outboard_side` still reads its side off the board's x.

**Never more than `CrewBoard.ROWS` (4) lines.** Every seat while they fit. Past that: your own seat, the pilot's,
whoever else is aboard while there is room, and "+N MORE SEATS". The CREW page on the clipboard is where a long cabin
is read.

`tests/stations.gd`, `the_crew_board_is_a_small_placard_out_of_the_forward_view`, holds all 97 package-built boards to
0.12 x 0.06 m and every corner more than 40 degrees off the nose from the seated eye. The old board is the mutant and
fails both checks.

### Sixty-four players: what changed and what it costs (lane/seats, 2026-09-18)

Asked on 2026-09-18: **"let's make the max 64 for now, i want to see how things break down at higher loads so having an
unreasonable amount is okay."** `Net.MAX_PLAYERS` is 64 (it was 8) and a craft holds as many people (`kMostAboard`,
the count seven bits on the wire, protocol 23). `Net.host_refusal` still will not host more players than a craft holds.

**What had to change to let sixty-four in, each held by a suite:**

- **The roster travels in pages.** A hello is one unreliable packet of at most `HELLO_MOST_BYTES` (512), said until
  answered. Eight cards of the longest names fitted the level hello; sixty-four at about 25 bytes a card do not. The
  level hello now leaves the roster out when it would not fit, and `roster` hellos carry `{n, page, pages, cards}`;
  the joiner answers each page, the host repeats only the unanswered ones, and a revision is taken only once every page
  of it is in, so no machine draws half a session (`tests/names.gd`).
- **The statistics board travels in pages** (`Net.board_pages`), page 0 starting a fresh board. It was cut to what one
  hello carried, the first eleven or so rows at sixty-four. `NetStats.ROWS_MOST` is gone: it was a literal 8 beside
  Net's 8, and it is `Net.MAX_PLAYERS` where it is used (`tests/net_stats.gd`).
- **A full session says so.** The ENet carrier keeps one place spare, and `_on_peer_arrived` tells whoever takes it "The
  session is full: N players." and lets them go; at the cap it was turned away unsaid and waited out its deadline. A
  Steam lobby already refused a full game in words. `--players=N` (`Net.choose_session_size`) lets a host take fewer,
  which is how `tests/players_peers.gd` fills a session of two and hears the third told. `tests/players.gd` stands up
  sixty-four in-process clients, all handshake with distinct ids, and the ninth and the sixty-fourth join a craft.
- **Colours past the first choice.** Eight palette colours were one each at eight players; `Net.colour_of` now gives a
  player whose chosen colour a lower-numbered player already wears their client id's `PlayerColours.fallback`.
  `AirPicture.nearest_player_colour` holds every fallback clear of the machines' grey (`tests/air_picture.gd`).
- **The briefing room's marks** are eight abreast (`LevelChart.ROW`) and the room is 19 m deep: four abreast ran
  sixteen rows back through the wall (`tests/lobby.gd`, "every mark is inside the room").

**What it costs, `tests/player_load.tscn`** (a report, not a gate: `crowd.gd`'s in-process tick queue, one host, N
peers, link 8, 600 ticks settled and 600 measured, on this workstation while another gate ran, so the milliseconds
are high and the bytes are exact):

| players | no AI craft: host tick mean / p99 ms | down a client kB/s | host up Mbit/s | 200 AI craft: host tick mean / p99 ms | down a client kB/s | host up Mbit/s |
|---|---|---|---|---|---|---|
| 8 | 0.22 / 0.42 | 39.4 | 2.5 | 4.11 / 6.57 | 247.6 | 15.8 |
| 16 | 0.70 / 1.46 | 71.7 | 9.2 | 7.56 / 11.13 | 247.7 | 31.7 |
| 32 | 3.51 / 6.35 | 136.4 | 34.9 | 14.20 / 20.07 | 247.7 | 63.4 |
| 64 | 14.33 / 22.66 | 247.7 | 126.8 | 33.32 / 47.92 | 247.6 | 126.8 |

**Where it breaks down.** A 120 Hz tick has 8.33 ms. With the sky full of 200 craft the host is over it somewhere
between 8 and 16 players; with an empty sky, at 64. Players cost the host roughly as the square of their number (each
is a craft and a pilot everybody is sent: 0.22 ms at 8, 14.3 at 64). Every client is capped at the send budget, 245
kB/s, which the full sky already fills at eight and players alone fill at sixty-four, so the host's upload is that times
the players: 126.8 Mbit/s at 64 -- not a home connection. Fairness held throughout: the worst gap between two records of
one craft stayed at the four ticks the budget predicts, every craft was seen, nothing starved. Up from each client is
13.2 kB/s whatever the count. NOT MEASURED HERE: real sockets at 64 (`bulk_peers` runs two), the radio clips' shared 48
KiB/s budget spread over 63 peers (every clip would expire before most receive it), and 64 players choosing one kind,
whose issue places run a row kilometres long (`sky.gd`).

### The centre console, and levers that work the bus

What belongs to the AIRCRAFT rather than to a seat lives on `VehicleView`, not inside any
station: the airliner's shared throttle, and now a **flap gate** and a **gear lever** on
every craft whose bus carries those channels. `controls_for` splices the console into every
seat's set, so both pilots reach the same node -- one handle, not one each, because two
handles would be two positions for one flap setting.

**A lever declares its own channel.** `VehicleControl.channel` and `channel_range` say
which bus channel a latched control works and how far it goes, and `PilotRig` sends for
anything it can reach whose value has changed. That used to be a hardcoded `TiltLever`
branch in the rig; gear and flaps would have been two more, and every lever after them
another.

**The gate has the notches the craft is fitted with.** `craft_schema` fits the aeroplane's
flaps with a range of 3, which is four positions, and the simulation divides the command by
that range to get the fraction the flight model reads. A handle resting between two notches
would be asking for a setting the aircraft cannot hold, so it settles on the nearest one.
The gear snaps for the same reason, harder: there is one bit on the wire.

**Flaps were already physical and gear already was too.** `levers.flaps` is in the lift and
drag terms and `kGearBit` is in the drag term. What was missing was a handle -- the only
way to work either was a page on a screen.

**`trim` is the one that is NOT.** It is on the wire, fitted on five kinds with per-kind
names -- elevator trim, cyclic trim, drive trim -- settable by command and shown on the
MFD, and the flight model never reads it. Nothing about the aeroplane changes when you trim
it. That is a gap, not a design.

**Spacing is now correctness.** No two grips in a craft may be within `REACH * 2` of each
other, and with ownership gone that rule is the only thing between a hand reaching for the
flap gate and the gear lever beside it. The console sits in the gap between two stations'
control envelopes, which on side-by-side seats 1.10 m apart is 0.42 m wide, so its controls
are spread fore and aft as well as across.
`nothing_a_hand_can_reach_is_within_one_hand_of_anything_else` measures every pair of the
things a rig can actually reach, which is what the older per-station check could not see.

### Twisting the stick is rudder, and a lever stays where you leave it

Two promises that are opposites, which is the whole distinction between a spring and a
lever and the reason one rides the input frame and the other the command bus.

**A stick has a third axis.** `offer_hand` takes the hand's ORIENTATION as well as its
position, and `FlightStick` reads the wrist's roll about its own shaft -- which leans with
the column, so holding the stick hard over and turning the wrist is still rudder and not a
mixture of the two. Measured: 23 degrees of wrist gives 0.73 of rudder with half a throw of
roll on it at the same time and no crosstalk. Turning the grip CLOCKWISE seen from above is
right rudder, which is a negative rotation about an up axis, so the geometric measure is
negated once, at the one place that knows which way a rudder goes.

**And the rudder gets an instrument**, because it has nowhere else to show itself. A stick's
position is its own display; a twisted grip on a leaning column is very nearly invisible
from the pilot's own eye position, let alone from the seat beside it. `RudderIndicator` is a
slider on each console showing the LINKAGE, so a copilot watches the pilot's feet as
directly as they watch the pilot's hands. `linked_rudder` joins the other three on
`CrewControls`.

**The lever is the throttle, held or not.** `read_controls` used to take the lever only
while a hand was on it and fall back to the hardware otherwise -- so letting go of a lever
set to cruise dropped the engines to whatever the trigger happened to be, which was nothing.

That also means the hardware cannot be an absolute axis any more, because an absolute axis
CANNOT latch: release the trigger and it reads zero, and zero is a command. So the right
thumbstick's Y is a RATE now -- up opens, down closes, centred holds -- and it moves the
same lever the hand does. One throttle in the aeroplane, several things that can push it.

### The grab and the pinch: which finger takes which control

Asked for on 2026-09-15: *"the arm switch in the airplane, some devices should be
'grabbable' by the grab button, and others should use the trigger button, it's more natural
to grab joysticks or wheels and 'pinch' buttons and switches."*

**There was no pinch before that day, anywhere, on any control.** The same request elsewhere
calls it "the pinch gesture we built earlier"; nothing of the sort had been built. `Bind`'s
own doc block said the opposite in as many words -- "GRIP is always take-hold-of-this,
everywhere, on every control" -- and it was true: one grab took a flight stick, a bat switch
and an MFD key alike. It is worth knowing, because "we built it earlier" will be believed.
`tests/pinch.gd`'s RED reading is the record of the day it did not exist.

**A control says which finger takes it**, and that is the whole of the mechanism.
`VehicleControl.taken_by` returns `Bind.Take.GRIP` or `Bind.Take.PINCH`; the rig asks, and
hands `offer_hand` the reading of THAT finger. Nothing below that line knows there are two
gestures, which is why the change cost the twenty-odd control classes five one-line
overrides and nothing else. **No new input path was needed** -- `Bind` had distinguished
TRIGGER from the grip since the day it was written; what it had never done was let the
trigger take hold of anything.

**Grabbed: anything you wrap a hand round.** Sticks, yokes, wheels, levers, quadrants,
collectives, gear handles, gun grips -- and the pedals, which no hand takes at all.
**Pinched: anything you work with a fingertip.** The bat switch, the crew button, the rotary
knob, the detent selector, the MFD's bezel keys. Those five are exactly the parts that also
answer `faces_the_eye`, and deriving one from the other was **rejected**: they are two
different questions -- which way a part is TURNED when the builder puts it down, and which
finger takes it -- that happen to agree today, and a gun grip aimed at the eye or a screen
worked with a whole hand would then have no way to say so.

**The hard case is a hand that could take either**, and the rule is one sentence: **the
finger that is closing decides which controls are even candidates, and only then does
nearest choose between them.** A closing trigger sees nothing but pinched parts; a closing
fist sees nothing but grabbed ones. **Rejected: nearest decides and the finger only says
whether to take it** -- which is what the code did, and which the gate measured: a fist four
centimetres from a stick took the SWITCH six centimetres away. Millimetres must not settle a
question a finger has answered, and on a fighter's left console the two are always that
close.

**With both fingers closed, the grip wins.** An index finger RESTS on a trigger, and that
trigger is also the brake, the gun and the beam's press, so a pull can be incidental; a fist
is closed on purpose. Nearest-of-the-two was rejected for the same reason -- a resting
trigger would take a switch away from a hand deliberately reaching for the stick beside it,
and nothing would say why.

**The finger that is holding a control is not also free to do something else with it.** The
rule `Bind` already stated about the grip, extended the moment there was a second taking
finger. An empty left hand brakes with its trigger; without this, throwing the master arm on
final also braked the aeroplane -- measured at 1.00 on the control frame. `_bindings_for`
lays `Bind.nothing()` over the trigger while a pinched control is held, after the control's
own table and before the board's and the builder's.

**The two gestures differ in their RELEASE, and that is half the item.** Asked for on
2026-09-15: *"there is no 'quick tap to grab' with grip, long press and release will release
but quick grab on/off should hold until the grab button is hit again, this is different with
pinch, any release is a full release, this makes working with switches (which you only want
to grab until you have the setting you want) easier."*

- **A grip latches.** Tap on, tap off; a long squeeze released is an ordinary release. This
  is `_grip_of` and it is unchanged -- it is what makes holding a lever at 300 kph a decision
  rather than a hand cramp.
- **A pinch never latches.** Any release is a full release, however brief the pull. The
  reason is inside the user's sentence: you hold a switch only until it is where you want it.
  A latch is right for a lever you fly with for an hour and wrong for a switch you flick,
  where it leaves your hand stuck to the switch after every flick. `_taking_finger` declines
  the latch by reading the trigger raw.

**The latch belongs to the gesture, not to the hand**, and getting that wrong was a real bug
this item found. `_grip_of` used to pin a hand to whatever it was holding -- and a hand
pinching a switch IS holding something. So a fist tapped while pinching latched onto a switch
no fist had hold of, and the fist it left closed was still closed on the frame the trigger let
the switch go: **the hand let go of the switch and took the stick beside it**, having been
told to do neither. `_in_the_fist` narrows the latch to what a fist is actually holding.

**And the builder's carry is always the grip**, whatever takes the part in flight: you are not
pinching a switch there, you are picking a piece of furniture up, and the builder has the
trigger already.

**One trap, and it is about clocks.** `grip_left` and `grip_right` are written in
`read_controls` on the physics clock, and `_work_the_controls` runs on the render one. A
pinch read live therefore arrived up to a physics frame BEFORE the fist beside it, and at
`--fixed-fps 120` against 60 Hz physics the suite caught it: both fingers closed in one
breath, and the switch was taken before the grip reading caught up -- the exact case "the
grip wins" exists to settle. `pinch_left` and `pinch_right` now sit beside the grips and are
read on the same tick. **Two readings that decide one question have to be taken at the same
moment.**

### A camera you pick up, and the second window it draws into

Asked for on 2026-09-15: *"it's very important that I can record my play sessions, so i want the ability
to make the 'desktop' show a different view than what is in the vr headset. I want a floating camera that
i can position in my cockpit, and grab it with my hand and move it ... a button to turn it on and off and
a red light if it's on, and some fov buttons."* plan.md item 20.

`DirectorCamera` is a part in the bin, so it is placed and saved like any other piece of furniture and it
flies with the aeroplane. `CameraKeypad` -- power, wider, narrower -- is bolted to its back. `Monitor` is
the autoload that owns the second window.

**It costs 0.60 to 0.70 ms a frame, and that is the whole reason there is a switch on it.** Measured by
`tests/director_cost.gd` before any of it was built, on the RTX 5080 under D3D12 and Mobile, against a
2.05 ms baseline with the watch level's 79 vehicles in the world. A second view is a second full pass
over the world, and this is the only thing in the game that deliberately costs frames. Off by default;
the red light is what says you are paying.

**Shrinking the recording saves almost nothing, and this is the one to read before optimising it.**
960x540 costs 0.596 ms and 1920x1080 costs 0.617 -- a fiftieth of a millisecond for a ninth of the
pixels. The second viewport's own GPU timer does fall, 0.740 to 0.411, exactly as it should; the frame
does not get faster, because what it waits on is the CPU half: a second cull and a second render list
over every vehicle and the whole island, which is 0.47 to 0.50 ms **at any size**.

**So there is no render-scale knob on the recording, and adding one later would do nothing.** Say that
plainly because a smaller recording is the first optimisation anybody reaches for, and because the plan
asked for one in as many words: "its viewport wants its own render scale and its own quality, well under
the headset's", citing `PilotRig.RENDER_SCALE` as the precedent. **That precedent does not transfer.**
The headset's 1.4x is fill rate and nothing else, so halving it halves real work; a second VIEW is a
second pass over the scene, and the scene is the same size however few pixels it lands on. The only
saving is the switch, which is why the switch is the feature.

**It is a `Window` and not a `SubViewport` blitted into the game's own window, and the reason is XR.**
While the root viewport has `use_xr` on, everything drawn into it -- every `CanvasLayer`, every 2D node,
and every EMBEDDED subwindow -- is composited into the eye buffers, and the desktop is a blit of an eye.
A fullscreen `TextureRect` showing the camera would put the recording inside the headset, over the
cockpit. A `Window` node is a viewport of its own, drawn as an ordinary non-XR viewport and blitted to its
own OS window, which the root's `use_xr` never touches. It costs no more: 0.702 ms against the
`SubViewport`'s 0.671, inside the spread of either.

**A `Window` node is EMBEDDED by default.** `Viewport.gui_embed_subwindows` is a property of the PARENT,
so it cannot be set on one window alone; `Monitor` turns it off on the root while the recording is up and
puts it back afterwards, and sets it BEFORE `add_child`, because the flag is read when a window enters the
tree. The first pair of pictures taken of this feature shows what the default gives you: the recording in
a panel over the bottom half of the cockpit.

**A second `Window` works under `--headless`** -- a valid viewport RID and its own current camera -- so
which camera the desktop stands on, where it is and how wide it is are all headless questions.
`tests/director.gd` asks them. And "the field of view changes what is drawn" is not a screenshot question
either: a frustum is a thing a camera can be asked about, so a point a third of a metre out to the side of
the lens is outside the shot at 20 degrees and inside it at 100.

**A part may now bring other parts with it.** `VehicleControl.carries()` is announced by the part, and
`CockpitStation.controls()` splices the result in -- because the station walks its own CHILDREN and a
keypad on a camera is a grandchild, which would otherwise be a control no hand can reach. A station that
went hunting for `VehicleControl`s at any depth was rejected: it would also find whatever a future part
keeps deliberately out of reach.

**And `carried_by_hand()` is true on this one part alone.** Every other part is dragged about only while
the builder is on; a throttle that came off its quadrant in flight is a throttle somebody has dropped over
the Atlantic. Framing a shot IS the activity, and you cannot be in the builder while doing anything worth
recording, so the camera is picked up while flying. The machinery is `offer_hand_to_place`, which already
knew how to pivot a thing about the hand that lifted it.

#### Touching beats pointing: the beam and the pinch are the same finger

`PilotRig._point_a_hand` presses glass with `_read_input(hand, Bind.TRIGGER)` and `_nearest_takeable` takes
pinched controls from that same raw reading. Until this item they never collided, because you point at a
screen from across the cockpit and pinch a switch with your hand on it. A floating camera with keys on its
back, held in front of a monitor, is where they meet: one pull would press both.

**A hand with a pinchable control within `VehicleControl.REACH` is reaching, not pointing.** Its beam is
put away, visibly, and its pull works the control. `PilotRig._reaching_for_a_pinch`.

**Rejected: nearest wins** -- compare how far along the ray the glass is against how far the control is.
It reads fairer and it is the same mistake the two-finger rule already rejected: the beam's hit distance
is a function of where you happen to be aiming and can be a few centimetres when the glass is close, so
millimetres would settle a question the hand has answered by being ON a key.

**Rejected: the beam wins while it is on glass.** That makes the camera's keys dead whenever a board is
up, which is exactly when somebody is setting a shot, and dead without a word on screen to say why.

**A hand already pinching something counts, and that is not the same question as "is there one near".**
`_nearest_to` skips what is already held, so asking it alone lets the beam return on the very frame a key
goes down -- and that pull presses the glass as well. The held control is asked first.

**A hand carrying something with its fist still points.** Its trigger is free by definition, and taking the
beam from it would cost a player holding the camera the ability to point at anything, for no case anybody
has met.

#### The fullscreen key is the recording window's alone

cockpit had no fullscreen key before item 20. `autoload/fullscreen.gd` is racer's, brought across
rather than reinvented, with one change of substance: **every call takes a window id**, because this
game has two windows while a recording is running and a key pressed in the recording that threw the
MIRROR into fullscreen would be the least useful thing it could do.

**And nothing binds it in the main window, because both of racer's keys are already taken here.**
`PilotRig.desk_keys` binds `KEY_F1 + kind` for every craft a player may be put in, and **F11 flies a
Cessna** -- `tests/director.gd` checks that it still does, so the day nothing is on F11 is a day
anybody can find out. F is `next seat`, and `is_action_pressed` matches a plain event inside a
modified press unless asked for an exact match, so Shift+F would change seat as well. Rebinding either
to make room for a window key would change what every pilot's keyboard does.

So the key lives where the request put it -- "fullscreen IT" -- and `Monitor` listens on its window's
own `window_input`. A `Window` is its own viewport, so the rig's `_unhandled_input` never sees what
lands there and there is nothing to collide with. The main window can still be put fullscreen by
asking, by the window manager and by alt+enter.

**Headless cannot tell the two windows apart.** `DisplayServer` makes no real windows, so every
`Window` reports id 0 and an event parsed globally reaches the recording window's own `window_input`
as well. What the gate checks instead is the invariant that would rot: that the autoload defines no
global input handler at all, read off its script's method list.

#### Two things a headless suite could not see

Both found by the first run of `tests/director_shot.gd`, with `tests/director.gd` green throughout.

**The keypad's meshes were never built.** It is a grandchild of the station, so nothing but the camera
would ever call its `setup`, and an edit that was supposed to add that call had silently changed nothing.
Every check stayed green because they all ask what a key DOES, and a keypad that was never set up answers
a fingertip perfectly -- `_key_under` works off `_key_places()`, which is arithmetic. What it had was three
invisible keys and a power light that never lit. **Ask how many keys were DRAWN as well as what they do.**

**And the window was drawn inside the game's own**, as above. Neither is visible from a suite, and both are
obvious in a picture. CLAUDE.md's second rule, twice in one afternoon.

### A signal lamp, off the parts bin, in a holster at its seat

Asked for on 2026-09-18: a light gun "like the camera" -- carried, and left where you let go of it
"in relation to the player, so they can't lose it" -- with white on the trigger, red on A/X and green on
B/Y, one light at a time, that other players in other aircraft can see. `SignalLamp`,
`tests/signal_lamp.gd`.

**It is the camera's carry, with the grip snapped into the palm.** `carried_by_hand()` routes the fist to
`offer_hand_to_place`, which places it in the station's frame, so let go it stays in the cockpit and flies
with the craft (the suite flies the craft 200 m and turns it through a right angle; the lamp moves
0.0000 m in the seat's frame). Unlike the camera it does not keep the offset it was grabbed at: held,
the lamp's frame IS the hand's, so its beam is the controller's -Z. That is what lets step 2 draw a far
player's beam from the hand poses already on the wire.

**A part, since 2026-09-19 (lane/lampopt).** The user: *"let's have the light gun (like the director
camera) is optional, not always present and can be loaded via the ipad."* It was kit, holstered at every
seat by `VehicleView.man`; now no seat has one until "+ SIGNAL LAMP" is pressed on the BUILD tab, the last
of 27 parts in `ControlCatalogue.PARTS`. It is saved by `CockpitLayout` and binned like any part. It is one
to a seat, because a seat has one lamp channel, and `PilotRig._add_a_lamp` refuses a second on the board.
It arrives in its holster and not in front of the seat, so a fresh lamp is never over a gauge; where the
builder leaves it becomes its holster (`holster_here`). Every craft package lists it in `allowed_devices` and
no station carries one. The generator and `tests/stations.gd` now fit the lamp channels first, as `Sim.start`
does, or `_allowed_for` finds the lamp's channel on no craft and leaves it out.

**Other machines learn of it from the wire, not from the layout.** A layout made in flight lives in this
machine's `user://` and goes nowhere, so the lamp channel carries a `FITTED` bit (bit 4, `RANGE` 15 -> 31).
Every physics frame the rig compares its own seat's bit with whether it has a lamp, and proposes the
difference (`PilotRig._say_whether_i_have_a_lamp`). One comparison covers every way the two can part: a
lamp placed, a lamp binned (freed before `_send_what_moved` could say so), a layout loaded without one,
and the last occupant of the seat having had one. `VehicleView._match_lamps_to_the_wire` holsters a lamp
at every other seat whose bit is set and removes one whose bit is clear. That includes a lamp this
machine's own saved layout put at another player's seat, because `make_station` applies the local
layout to that seat in every craft of the kind. Between two real processes: placed, the lamp is drawn
53-65 ms later; binned, it is gone 67 ms later (`tests/lamp_peers.gd`). **Never test a lamp's removal in
a peer child with RESET**: a child started on the game scene writes the player's own `user://cockpits`,
and RESET deletes the saved layout there.

**The holster search.** `SignalLamp.holster_spot` searches out to the right of the seat at hip height for a place within
`EASY_REACH` and two hands clear of every other grip in the craft (`fit.gd`'s rule); the car needed the
search to go below the start, past its console gear. 100 seats across every craft scene, all clear.

**Inside the skin, where the airframe can say.** An airframe with `encloses(box)` fences the search
(`VehicleView.holster_fits`, which lists the airframes it asks); with a chair, nothing aft of the search's
start either. The A-10C's first holster stood with its top corner 1.40 m up through the narrowing bubble,
because the A-10's sill is at the seated hip. Fenced, it stands 0.27 m out and level with the shoulder,
inside the glass (lane/lampfix, 2026-09-19). **An `encloses` must be held to the drawn triangles by its own
test** (`tests/warthog.gd`, `the_airframe_says_inside_where_the_drawn_skin_is`). With a chair, the aft
fence alone happened to move the A-10's lamp inside, so signal_lamp stayed green with `encloses` answering
yes to everything. And read the triangles, not two rings blended: the loft cuts each quad corner to
corner, the cut runs the other way on the port side, and blending put a corner outside the glass.

**Momentary, newest press wins**, releasing falls back to what is still held, and letting go of the lamp
puts it out. Desk: 1 white, 2 red, 3 green while held, 0 back to the holster (does nothing with no lamp placed).

**`VehicleControl.own_seat_only()`** is new and true on the lamp alone: the rig reaches every other
control in the craft, but a lamp speaks for its seat. **And the builder's grid no longer snaps a part
carried in flight** -- it did, for the camera too, whenever snap had been left on in the builder.

**On the wire: a generic bus channel per seat, and the hands that were already there.** The colour and
who holds it (nobody, left, right, desk) are four bits on one generic channel per seat, audience
"craft", fitted to every kind by `SignalLamp.fit_every_kind` in `Sim.start` before any world exists. The
lamp is a CRAFT-scope control, so it reaches the bus the way every switch does. Where it points is not
sent at all: held, the lamp IS the hand, and both hands are on every pilot's state already, so
`Sky._show_their_lamp` puts a far lamp in the far hand (or in front of the far eye, from a desk). No C++:
the input frame's `buttons` byte is full. 17.6 B a change down, 11.9 B up, nothing while quiet
(`tests/lamp_wire.gd`); 18.0 and 12.0 B with the fifth bit. 3 ticks in-process; 54-89 ms between two real processes through the desk keys,
with the far lamp 0.1 mm and 0.02 degrees from the near one (`tests/lamp_peers.gd`). **A lamp let go of
has to believe what it told the craft over the wire until the wire agrees** (`SignalLamp.apply`): the
sky redraws the cockpit from the bus between the hand letting go and the rig sending, read the old red
back, and the router then had nothing to send. The far machine never saw it go dark.

**The package contract hash leaves generic channels out** (`CraftPackage._flight_schema`). They are the
cockpit's, not the flight model's, and with them in, every authored package read stale the moment the
lamps were fitted.

**The far glare** is `world/shaders/signal_lamp_glare.gdshader`: the navigation lights' least-angle quad,
placed through MODELVIEW_MATRIX, plus a beam -- full within 4 degrees of the axis, gone by 22 -- and half a
surface's share of the mist. Measured in the real level at 1.5 km (`tests/lamp_beam_shot.gd`): red aimed
24 px by day and 76 at night, 60 degrees off 0. At a least angle of 4 mrad it was 4 px by day, so it is 10.

**Pictures of two players signalling** come from `tools/lamp_session.ps1`, which drives `SignalLampHarness`: a headless
host stages both players in the air and flashes with the desk's real keys, and a windowed joiner photographs it from
its own cockpit and writes reel frames from inside the game. It is a picture harness and says so: the server's seating
calls turned up two faults, in `../../learnings/2026-09-18-lightgun.md`: S-1 (a re-spawned player got a second pilot) is
fixed, and S-2 (in a real session the server intermittently stops sending a freshly seated craft to the other machine)
is with the upstream lane, so the staged planes glide rather than fly. **Nothing is ever captured outside the game's own viewport**: ddagrab recorded somebody else's window.

### Rudder pedals on the floor show where the rudder is

Asked for on 2026-09-13: "a floor rudder pedals model and device, that way we can determine where the rudder should be".
`RudderPedals` is two pedals on a bar on the floor in front of every seat that flies an aircraft with a rudder. **Left
pedal forward is left rudder**, each pedal `TRAVEL` (0.08 m) forward or back at full deflection, and the bar between
them turns so its ends stay on the pedals. The `RudderIndicator` on the console stays.

**They show the rudder and never decide it.** Scope SEAT, like the stick. `FlightLevel._draw_cockpit` hands a pair of
pedals `PilotRig.rudder_sent()` -- the rudder `read_controls` put on the last input frame, whatever it came from --
while this player's own feet are on them, and the linkage, `linked_rudder`, otherwise: what this machine is sending
answers instantly, and a footwell nobody here is using shows what the aircraft's rudder is actually doing. The value is
`RudderPedals.shown` and not `value`, so `roll`, `pitch` and `rudder` on the pedals answer 0 and nothing that adds
controls up can count them. Written only on a change of more than `EASE`: **0 transform writes in 60 idle frames across
two pairs, and 360 with the gate taken out.**

**Drawing this player's OWN pedals from the linkage was rejected once and is now the rule**, and the reason it was
rejected -- the linkage moving only on a rollback, which is the throttle that jittered between two positions -- went
away when `CrewControls` moved to the cabin. What the rejection cost: **nine craft carry pedals at two flying seats,
and on all nine this pair lay flat while the other pilot had full boot in** (`tests/crew_sync.gd`), disagreeing with
the `RudderIndicator` a hand's breadth away, which has always read the linkage. Two instruments in one footwell saying
different things about the same rudder.

**No hand works them.** They are more than a metre from a seated shoulder, against the 0.75 m lean `tests/fit.gd`
allows, and the stick's twist and the thumbstick already give a hand the rudder. `offer_hand` does nothing; the
builder picks them up like any part. `VehicleControl.under_foot()` takes them out of
`every_control_is_within_a_seated_arm`, and they are still measured against every grip for crowding.

**Fitted, not authored.** `CockpitStation._fit_the_pedals` at a seat that flies, on a kind whose model is AIRPLANE,
HELICOPTER or TILTROTOR (`has_pedals`, the model test `trim_range_of` asks): at the flying control's x, `FOOTWELL` ahead
of its base, on `CockpitStation.FLOOR`, which is the floor `CockpitShell` lays. None on the pod, the car, the boat, the
train, the tank or the tower, and none at a seat that does not fly -- the helicopter's two door gunners included.
**`FOOTWELL` was 0.30 and the first picture from the pilot's eye showed no pedals at all**: the console, 0.815 m up
and reaching back to 0.25 m ahead of the eye, hides the floor further forward than about 0.535 m, and they stood at
0.64. At 0.12 they stand at 0.46 and can be seen whole, with the bar across the floor under the console's edge; the
dark faces were then hard to pick out on a dark floor, so they are pale. A real footwell is under the panel; these are
there to be looked at.

**In the parts bin**, so a saved cockpit carries them as `"scope": "seat"` -- and **a layout saved before the pedals
existed takes them out**, because the file wins outright. Save it again, or add them from the bin.

**Every rudder comes through one function.** `PilotRig.rudder_demand(device, held_twist, hands_or_keys)`: a pedal device
pushed off centre wins, then a stick a hand holds, twisted, then the thumbstick or Q and E. A device at rest yields, for
the reason a resting thumbstick does. The frame's rudder keeps its sign (+1 nose right) and its -1..1 scale, which the
ground handling reads as the nosewheel. The device itself is under WHAT IS NOT HERE YET.

`tests/pedals.gd` is the suite: Q held puts the left pedal 0.0800 m forward and the right 0.0800 m back in 2 frames and
home in 2; a wrist turned 23 degrees on the stick, through the rig's own hand pass, gives 0.73 of rudder and the pedals
at +/-0.0582 m, the same `TRAVEL` times the same rudder; the airliner's copilot's pedals follow the pilot's Q through the
linkage in 8 frames; fitting across eleven craft; save, rebuild and reload in place; and sixty idle frames. Each check
went red under a mutation first: the pedal sign flipped, the other seats handed 0 instead of the linkage, pedals fitted
on every kind, pedals left out of the bin, the write gate removed, the held twist ignored. In one process the pilot's
own frame and the linkage carry the same rudder, so a level that drew every seat from `rudder_sent` would pass here; that
half is the loopback's to see. `tests/pedal_shot.tscn` is the windowed look from the pilot's eye.

**Rebuilding a station under a seated rig printed a script error, and this suite found it.** `_label_the_controllers`
ran before `_work_the_controls` noticed the station was gone, and asked a freed control who held it: "Invalid access to
property or key 'held_by' on a base object of type 'previously freed'", once per rebuild -- the builder's RESET does the
same. `PilotRig._process` lets go of freed controls first now, as `read_controls` already did.

### A cockpit is a SCENE, and only a manned craft has one

`objects/seats/seat_*.tscn`, one per craft type. A control is a node with a script and a
transform -- the meshes are built at runtime by the control itself -- so a whole crew station is
half a dozen nodes and moving a lever is dragging it in the viewport rather than editing a
Vector3 in a build function. Several kinds share a scene: a pod and a light aeroplane are flown
from the same station, and a car, a boat and a gunboat are all one lever and one wheel. A kind
gets a scene of its own when what is in front of the pilot is actually different.

**Every seat in a manned craft, and none at all in an empty one.** Not just the occupied seats: a
copilot's yoke moving is half the reason the linkage is on the wire, and an empty seat beside you
with no controls in it is a seat you cannot watch somebody arrive at. The saving is the machines
nobody is in -- a hundred and forty craft with four seats each is five hundred and sixty sets of
controls, of which at most a handful are ever in front of anybody, and the rest were built at
startup, parented into the world and drawn for ever. `VehicleView.man` builds a station when
somebody sits down and frees it when they get up, from the pilot list the level already walks.

Stations parent to the SEAT ANCHOR, so everything in them stays in seat-local space and the maths
in `VehicleControl` remains subtraction between two children of one node -- which is what makes a
grab at 300 kph the same arithmetic as a grab on the ground. The smoke test asserts the anchor is
an ANCESTOR rather than the parent, because a control hangs off the station and the station hangs
off the seat.

### The load cycle, which only the editor found

`VehicleView` preloads the station scenes; a station scene needs `CockpitStation`; that read
`PilotRig.EYE_HEIGHT`; and `PilotRig` needs `VehicleView`. **A `preload` is resolved at PARSE
time**, so that ring was a hard one: every station scene failed with "Busy", which is what Godot
says when a resource is already partway through loading itself. The headless tests never saw it --
they load the level in an order that happens to work -- and the editor sees it every time.
`--headless --editor --quit` reproduces it in about a minute and is worth running after anything
that adds a scene. The fix is not a lazy `load`: a cockpit constant belongs with the cockpit, so
`EYE_HEIGHT` is on `CockpitStation` and the rig reads it, and the arrow points one way.

### The airframe ghosts for whoever is inside it

A pilot sits WITHIN the hull -- twenty-six metres of it on the airliner, with three and a half
still ahead of the windscreen -- and an aircraft is a box you look OUT of rather than at. So the
airframe goes see-through for the player at this machine and stays painted for everybody else, who
are looking at it. **It casts no shadow while ghosted either**: a fuselage shading its own console
puts the cockpit in the dark for the one person who has to read it.

**An aeroplane that looks like it spawned backwards is the interior, not a reversed model**, and it
was reported twice. Measured on the airliner: its nose lies exactly along its velocity, dot product
1.00; the nose cone is drawn at z -13.8 and the tail at +14.0 on a hull of plus or minus 13; the
pilot's seat is at -9.6, forward, facing along -Z with zero yaw. What it is, from the left-hand
seat, is sixteen metres of fuselage behind you and three in front. REJECTED: turning the airliner
round, which was done on request and undone. Every drawn part hangs off a `Body` node and the seats
deliberately do not, so a kind CAN have its model the other way round -- but turning it puts the
nose against the direction of travel and the aeroplane is then genuinely drawn flying tail-first.
The only self-consistent flip turns the model, the seats and the thrust together, which is a
relabelling nobody can see. The mechanism stays because `Body` is useful; no kind uses it.

**What replaced six arguments about which way an aeroplane points is a measurement.**
`every_craft_is_drawn_flying_forwards` takes the drawn nose -- `-Z` of the body node, in world
space, from the node tree that is actually rendered -- and measures it against the velocity, for
every winged craft. **It is the CLIENT's copy, and that matters: entity ids are per world**, so
comparing the client's vehicles to the server's by id compares different vehicles, and a probe that
did reported 175 degrees of error that was not there. Only a wing is held to it: a helicopter goes
where its disc is tilted and can point anywhere while doing it, a boat crabs, and a tiltrotor in
the hover does both -- measured, 90 degrees off and entirely correct.

The nose and tail cones are a fifth of the fuselage across and an eighth of its length long, and
the test bounds them from BOTH sides: bigger than a wart, smaller than a second aeroplane on the
front.

### Every seat on the linkage is drawn from the linkage, this one included

There is no "your own lever is where your hand left it" rule any more, and no airliner pedestal
carve-out. `apply()` refusing a control a hand is on is the whole of the exception.

**What the old rule cost while it stood**, and why the gate exists: reported from a session, "both
steering wheels should be able to control the boat (and that works) but i don't see the other
players inputs in my wheel if i'm not holding it". `tests/crew_sync.gd` sits a second crew member
beside this player in every craft that carries two pilots and has them fly. **Seventeen craft, and
all seventeen wrong the same way**: the other seat asks for 0.70 of roll, the control at the other
seat shows 0.70, and the wheel in front of me shows 0.00. Only the airliner, the Cessna and the
Hawkeye had a right THROTTLE, and only because of the carve-out.

The rule was written because `CrewControls` used to live on the VEHICLE, which the seat you fly
from PREDICTS, and on a predicted entity an authoritative value only arrives ON A ROLLBACK -- so
your own lever alternated between where your hand left it and a value a round trip old. It moved
off the vehicle onto the CABIN, which nobody predicts and everybody aboard SNAPS
(`cockpit_components.hpp`, the `CrewControls` block; `addon/tests/crew_cabin`), so there is no
predicted copy left to be stale.

**The gate names stations rather than a pair** (2026-09-17). `tests/crew_sync.gd` reads the
authored seat count instead of stopping at four, makes every flight station except the local one
the input source in turn, and checks the stick, throttle, rudder indicator and pedals at every
flight station; the fighter's crew button is then pressed through the hand path and checked at all
four stations, including its two non-flying gunner stations. That keeps a future third flight
station and today's operator stations inside the contract instead of silently testing pilot and
copilot only.

**The twist needs the guard said out loud.** `apply` refuses a held control; the `stick.twist =
linked_rudder` line under it is a plain assignment and refuses nothing, which could not matter
while the branch only ever ran for somebody else's seat. Both are under one `is_held()` now.
Without it a wrist turned on the stick was overwritten by the linkage's value a round trip old and
the rudder read -0.27 with the wrist hard over the other way (`tests/pedals.gd`).

**A TEST trap, not a game one: a value that has just changed is still the OLD one on the wire for
about two frames.** Measured on a solo world: after the rudder key comes up, `linked_rudder` reads
0.00, then -1.00 for two frames as the stop finally arrives, then 0.00 flat for the next
fifty-eight. So a suite that waits for the linkage to "read zero" is answered on frame 0 by a value
that has not caught up. **Wait for a RUN of quiet frames, and wait on the thing that is LATE** --
the linkage -- not on the stick, which the spring has already pulled back. `tests/pedals.gd`'s
`QUIET_FRAMES` is that, and an hour went on the version that waited on the stick.

### `hands_on`: the sentinel has to survive the wire

`CrewControls.hands_on` is "which seat is moving anything, or nobody". The sentinel is derived from
the seat's width (`kNobodyHandsOn = kNoSeat`, 65,535) and travels as ONE bit, and `crew_controls()`
answers nobody as **-1**, so no GDScript ever sees the library's number. `VehicleView.hands_on()`
answers `NOBODY_FLYING` (-1) for anything that is not a seat of this craft, which is right whatever
the field's width turns out to be.

**Why it is derived and not typed.** It was 255 in a three-bit field (`serialize` wrote `hands_on &
0x7u`), and 255 & 7 is 7. The server compared against 255 and was right about its own copy; every
machine reading it back off the cabin got 7, the host's own client included, since that receives
over the loopback like anybody else. Measured 2026-09-15 on a solo world with an empty cockpit:
`crew_controls()` returned `hands_on: 7`. **A GDScript check written against 255 is then a check
that is never true** -- which is how `PilotRig`'s spring, gated on "nobody is flying", came out
permanently disabled. A `kNobodyHandsOn` typed as 7 would be consistent on every machine and
therefore invisible, until a copilot in seat 7 has their hands on the stick and every machine calls
that nobody; since lane/seats (2026-09-18) there IS a seat 7, and `tests/many_seats.gd` puts a
copilot in it for exactly that reason and goes red with the typed 7. The general shape is in
`working_with_godot.md`, "A value that does not fit its field".

### No two grips within one hand of each other, ACROSS THE WHOLE CREW

A hand takes hold of anything within `REACH` of its grip, so two controls closer than TWICE that
share a place a hand can be, and which one it gets comes down to iteration order. Two ways that
goes wrong, and the second needs the whole craft in frame at once:

- **Within one station.** The Osprey's nacelle lever and its throttle were six centimetres apart.
  The controls are spread across the deck, and where sideways room ran out they are separated fore
  and aft instead: the Chinook's collective sits behind the cyclic and the Osprey's nacelle lever
  on the left console beside the hip, both of which are where the real ones are.
- **Between two seats.** Every seat gets a full set of controls, so a craft whose seats are closer
  together than a station is wide has two people reaching into the same place. The light aeroplane
  had its pilot and copilot 0.64 m apart with controls spanning 0.68, and the pilot's crew button
  was four centimetres from the copilot's throttle. Two numbers fixed it and they are a pair: **a
  station is as wide as one person, not as wide as a cockpit** -- the shells were 1.24 to 1.60
  across and are 1.05 now, just enough to clear controls reaching 0.34 either side -- **and
  side-by-side crew sit 1.10 m apart**, those 0.68 of controls plus a hand's grab radius each side.
  Every shape with two seats abreast was respaced to it.

The test instantiates a station AT EVERY SEAT POSE, in the craft's own frame, and measures every
pair of grips in the whole aircraft; checking one station in isolation cannot see the second case
at all. Smoke instantiates EVERY station scene, because a cockpit nobody has flown yet is exactly
where this goes wrong unnoticed.

**And a hand is offered one control a frame: whatever it holds, or the NEAREST thing it could
take.** Nearest is the only answer that is about where the hand actually is.

### A key per craft type

F1 upwards, one per kind, in the order `Sim.Kind` lists them. A key bound to a kind is a shortcut
where a button that walks the kinds is a place in a queue -- and pressing the key for the kind you
are already in asks for another of the same, which walks the machines of that kind.

It rides on the input frame beside the buttons (`kind_wanted`; four bits until the seventeenth
kind, five until lane/kinds, and now a sixteen-bit kind in that five-bit field's short form) rather
than as a command on the bus. The key is `KEY_F1` plus the kind (`PilotRig.kind_key`), and Godot's
`Key` enum runs to F35, so the Hawkeye and the submarine are F20 and F21: keys a desk keyboard does
not have, as the tower's F12 and every kind past it already were; the kind button still walks to
them. A kind past F35 gets NO key, not an invalid one (`PilotRig.keyed_kinds`, which is also all
the rig polls), and is reached from the CRAFT page. The bus is the CRAFT's, gated on what the craft
you are in is fitted with, and "take me to a helicopter" is not something the aeroplane you are
leaving has an opinion about.

### Stations are FOUND, not listed

`VehicleView.stations()` asks the scene tree rather than reading the dictionary that put them
there, and `CockpitStation.show_state` finds its screens the same way. Anything a cockpit scene
contains turns up without a second list to keep in step: a screen added in the editor starts being
fed without a line of code being told about it. A hand-written roster is a roster that goes stale.

`crew()` is one row per SEAT, occupied or not, with the station each one is. The empty ones are the
interesting half -- a crew of four spread through a fuselage cannot see each other, and what a
pilot needs before pressing the seat button is which seats this craft HAS and which are free. It is
on a small board on every console.

### Screens: Godot's own UI, on the glass

`CraftDisplay` renders a `Control` tree to a `SubViewport` and hangs the texture on a panel. That
is the groundwork for every instrument in the game: an MFD is a screen with buttons down each side,
an airspeed indicator is the same screen with one number on it, a moving map is the same screen
again. A `Label3D` is three lines of text and useless the moment anything wants a needle, a tape or
a button; a Control tree gets anchors, themes, containers and `_gui_input`.

**Touch comes free.** `touch()` turns a point on the glass into a synthetic mouse event, so a
finger and a mouse reach a Button by the same path and a page never knows which it got.

**A page is handed its data and draws it.** It never asks the simulation anything, never reads an
input, and never looks at which seat it is in. That is what makes two screens in one aircraft
agree: the copilot's airspeed and the pilot's are the same number from the same `craft_state()`,
rather than two instruments each asking their own machine and each getting an answer a round trip
apart. Every argument about which panel is right disappears if neither of them can have an opinion.
Anything a page wants that is not in the state is a gap in what the craft SHARES, and the fix is to
share it.

Redrawn five times a second, not ninety. Each update is a render target, and an instrument that
changes faster than a human can read it is an instrument nobody can read.

### The eye height is a relationship, not a fact about people

`EYE_HEIGHT` is what the cockpit assumes the eyes are, and what it actually sets is how far the
deck sits below whatever height the headset is really reporting -- so every 30 cm taken off it
brings the whole deck 30 cm nearer the hands of the person in the chair. The hands stay a fixed gap
below it wherever it goes, and that is the relationship that has to hold.

It was 1.15, a SEATED eye height, and stopped describing anybody the moment the controls were
raised to somewhere they could be reached in a headset. Two separate requests to move the controls
up were really this constant being wrong: with the eyes at 1.15 and the hands at 1.49 the pilot was
looking UP at their own console, and no amount of reshaping a cockpit fixes a glareshield above the
eyeline. It went to 1.49, a 1.6 m pilot's eyes STANDING.

**Moving it is two edits, and the second one gets forgotten.** It is the one head height in the
game and every level goes through it, but the eight station scenes bake their control heights in
metres rather than reading `hands()`, so raising the head raises nothing else and the pilot reaches
further DOWN for the same deck. Every node in `objects/seats/seat_*.tscn` has to move by the same
amount in Y: going from 1.00 to 1.35 was 45 nodes across eight scenes, and the three reach checks
all went red first, none of them saying why. So
`the_deck_is_authored_at_the_current_hand_height` says why: it measures the stick grip against
`hands()` and prints the correction to apply in metres, which is the number to feed straight back
into the scenes.

What that buys is the part nothing can keep in step by hand: a level with FURNITURE. The desk in
the main menu is built in plain metres and does not follow the constant, so the head really does
rise relative to it -- at 1.00 the eyes sat 26 cm over a 74 cm desk, which is a child at the dinner
table.

### And the player is SAT DOWN in the seat

Lowering the assumed eye height does not bring the controls closer to a real head. It lowers
the DECK, and moves them further away -- which is the wrong direction, and is exactly what
happened the first time it was tried.

In a headset the eyes are wherever the TRACKER says: a fact about the room the player is
standing or sitting in, with nothing to do with the aeroplane. A player whose real head is
at 1.7 m, in a cockpit authored for 0.85, is half a metre above their own instruments and no
constant in this file can reach them.

So the play space drops by the difference. `_seat_the_head` puts `origin.y` at
`EYE_HEIGHT - tracked`, the eyes land exactly where the deck was built for them, and the
hands come down with them because they are tracked in the same space. It fits any player of
any height without a setting.

On sitting down and on `recentre`, and NEVER per frame: correcting continuously would mean
standing up in the room moved the aeroplane instead of the pilot, and nobody could lean.

Headroom does NOT follow it. The canopy is measured off `PILOT_HEIGHT` instead, because
headroom is a fact about the person: tying it to the eye height meant lowering the deck
lowered the frame onto somebody's head.

Both directions are load-bearing. The console sits under the controls, so the further DOWN
they go the more of the windscreen it takes; the further UP, the sooner it crosses the
eyeline and there is no cockpit left to see out of.

The collective is the one control that reaches BELOW the deck, so lowering the deck made it
the furthest thing from the eyes -- 0.66 m, just outside a seated arm. It is three
centimetres further inboard now, which is where a seated pilot's left hand falls anyway. The
fix was the geometry and not the bound in the test.

The nose cones came down with it: a third of the fuselage across rather than half. At 55%
the cone was as wide as the aeroplane and read as a shape in its own right, when the job is
only to say which end is the front. The tail keeps more of its width than the nose, because
the DIFFERENCE between the two is what makes the silhouette readable.

**A cockpit is a box you have to see out of**, so `CockpitShell` is defined by what it does
NOT put in the way -- and since 2026-09-17 it puts almost nothing there at all. It was eleven
slabs: a console under the hands, a coaming along its front, a rail at each elbow, four
corner posts and two hoops. It is now **two**, a floor and a front firewall bar, because the
user asked for the table and the scaffold gone so that "building cockpits is a little more
free".

The floor stays because it is the one thing that has to be solid: `VehicleView._show_body`
ghosts the airframe for whoever is sitting inside it, so with no floor the occupant stands on
a see-through single-sided fuselage and looks at the ground through their own aircraft. It is
0.60 x 0.76 m -- a footwell, not the 1.05 x 1.10 m raft it was, which two side-by-side
stations used to overlap by 0.51 m at the centreline.

**`width` and `depth` are the station's ROOM, not the floor's size**, and keeping those two
apart is the design. `BuilderAuthority.validate_layout` builds the box a player may put a
control in out of exactly those two numbers, so they are how FREE building is. Shrinking them
to fit the drawn floor was tried first and is the precise opposite of what was asked for:
`builder_peers` went red on "MapScreen is outside this station's build box", which is a player
being told they may no longer put a screen where one already was. They are unchanged at
1.05 x 0.92 (0.86 on the sailplane), and the floor got its own constants instead.

**And the build box is wider than the aeroplane.** The obvious place for the bar was the box's
own front face at -0.92 m, so that what is drawn is what the host refuses. Measuring it ruled
it out: that face is OUTSIDE the drawn machine on nine of the enclosed stations -- the
Chinook's, the E-2D's and the UH-60's cabins, and the AC-130's gunners by 2.12 m. That is a finding about the BUILD BOX and not about the bar. The builder
currently lets a player place a control outside the machine they are sitting in, and nothing
refuses it; `shell_room` only measures what the shell draws. Worth someone's lane.

**The bar's place is computed, never typed.** It is there so the player can see where the
limit is, and the limit is not a taste: `tests/fit.gd` fails any control further from a
seated shoulder than `CockpitStation.EASY_REACH`, so `CockpitShell.front()` works out where
that lands at hand height -- -0.569 m with today's constants -- and the floor runs back from
it. What the player sees is the line the suite already enforces, and moving EASY_REACH moves
both together.

**The scaffold was not only in the way, it was in the wrong aeroplane**, and nothing had ever
measured it: on the F/A-18 the posts and hoops stood 0.31 m above the drawn canopy, and on the
E-2D, the UH-60 and the Chinook the rails stood out through the cabin sides -- **115 pieces of
station structure drawn outside their own machine across 33 crew positions**, measured on the
airframes as `lane/hornet` re-modelled them. `tests/shell_room.gd` is the check that had been missing, and it is what keeps
this honest now. It builds each craft with every seat manned, takes every visible mesh
outside a station as a solid in its own right, and asks by ray parity whether each corner of
each piece of shell is inside the machine. The datum is the drawn vertex and nothing else:
holding a station to `VehicleView._greenhouse` would prove nothing, because the greenhouse is
derived from `CockpitStation.EYE_HEIGHT` and `PILOT_HEIGHT`, the same two numbers the shell
sizes itself from, so a cabin roof at `floor + PILOT_HEIGHT + 0.30` clears a canopy at
`PILOT_HEIGHT + 0.25` for ever whatever either is doing to the aeroplane.

**A crew position counts as enclosed when both ends of the occupant are in the machine** --
the floor they sit on and their head -- and not necessarily in the same part of it, because
insisting on one part threw away every cabin drawn as more than one piece (the locomotive's
driver has their head in the long hood and their feet on the cab floor). That is **33 of 84
stations**; the other 51 are named with the reason, because a silently skipped craft is a
check on its way to being vacuous.

**And ASK IT WITH RAYS UP AND DOWN, BOTH ODD, from a point nudged 0.7 mm.** `lane/skyhawk`
measured all three of those the hard way (`modelling_here.md` §6). A HORIZONTAL ray crosses
door and window seams, which are drawn as inset strips -- open surfaces, so one boundary
gives two crossings: on the Cessna's centreline, plainly inside the cabin, the four directions
came back [above 3, below 1, outboard 2, inboard 2], and both horizontal rays called it
outside. Up and down meet skin, wing and gear, all closed. Requiring BOTH odd fails safe. And
every airframe here is symmetric about x = 0 with a vertex there while every drawn part is
axis-aligned, so a ray fired from an un-nudged point passes through a vertex as a matter of
course. The first version of `shell_room` fired one +X ray and had none of this. Three of the 35 still have a piece outside after the change, and both
reasons are SEAT POSES rather than shells: the Chinook's fourth seat is on an open lowered
ramp with nothing under it, and the UH-60's door gunners sit at x 0.78 in a cabin that is
0.75 m to the skin, so their whole station is outboard of the fuselage, worst corner 1.35 m
out. Those are for whoever owns the craft, and naming them is the point -- it is how the two
halves finally talk to each other.

### Every craft type has its own cockpit

Every control answers all five axes -- roll, pitch, rudder, throttle, brake -- and the base
class answers them all neutrally. That is what makes a cockpit a CHOICE OF CONTROLS rather
than a fixed set of named ones, and it is why the rig never has to know which craft it is
sitting in: it asks each control what it is asking for and adds it up.

| kind | lever | the other one |
|---|---|---|
| pod, plane | throttle | flight stick |
| airliner | ONE throttle on a centre pedestal | control yoke |
| helicopter | collective | cyclic |
| car, boat | throttle | steering wheel |
| locomotive | regulator | brake handle |

A car has no pitch axis and a boat has no roll axis, so a two-axis stick in front of either
would be a control lying about what the vehicle can do -- half of it would move and nothing
would happen. `SteeringWheel` reports steering and reports nothing else. A locomotive cannot
be steered at all, so its second control is the brake, which is the other thing a driver
spends the whole journey on.

### A helicopter is flown with a collective

`CollectiveLever` is the same one latched axis the simulation reads from every craft, moved
in a completely different direction, and the direction is the whole point. A throttle slides
fore and aft and asks an engine for more power. A collective is an arm hinged at the floor
beside the seat, and raising it increases the pitch of every rotor blade at once -- which is
why the machine climbs the moment you lift it, and why a hand that pulls UP for lift is the
muscle memory a helicopter needs. Measured: full up raises the grip 0.192 m and moves it
0.059 m along, so it is a vertical pull and reads as one.

Only the hand's VERTICAL travel moves it. The grip does swing fore and aft as the arm goes
over, but taking that arc into account would make the lever fight the hand near the top of
its swing, where the arc is mostly horizontal.

### Which way a control moves is as testable as what it sends

The sign that reaches the aeroplane and the direction the control visibly moves are two
different pieces of arithmetic, and they were opposite on both two-axis controls: the nose
went up while the stick in front of the pilot pushed forward, and the yoke's wheel went
toward the panel when it should have come toward the chest. Nothing that flew the aeroplane
was wrong, which is exactly why it survived -- a control that lies is only visible from
inside the cockpit.

Smoke reads the grip position out of the control at full deflection and asserts the
direction, rather than trusting that two sign conventions written months apart agree.

### Two thumb buttons, two levels of one list

There are a hundred and forty machines out there and ten kinds of them. The upper left-hand
button walks the MACHINES; the lower one jumps to a different KIND. Both used to do the
same thing, which meant getting from an aeroplane to a boat was forty presses through forty
aeroplanes -- a list you cannot choose anything from. Pick the sort of thing you want, then
pick which one. `switch_kind` walks the kinds round from whatever is being flown and takes
the lowest machine of the first kind with a seat free.

### The airliner: one throttle between two seats

`kKindAirliner` is the same movement model as the light aeroplane -- a wing is a wing -- and
a different COCKPIT, which is the whole reason it is a separate kind. Heavier, gentler, a
quarter of the thrust-to-weight, and flown with two hands on a yoke rather than two fingers
on a stick.

Its throttle quadrant is ONE lever, parented to the VEHICLE and not to a seat, sitting on
the pedestal between the two front seats where both crew can reach it. Nothing about the
linkage changes: whoever has hold of it is `hands_on`, and it is drawn at the linked value
for everybody else. A control shared by two seats is just a control that two seats can
reach.

The light aeroplane's per-seat sticks and levers work exactly the same way, which was the
point of doing the airliner: the yoke is not a special case, it is the ordinary case with a
wheel on it.

### Three things that made them look absent

They were there the whole time, built and working, and none of them could be seen or
reached. All three were the same class of mistake -- a frame or a reference point assumed
rather than checked:

**A seat anchor is the play space FLOOR, not the seat pan.** The tracker adds the eye
height on top of it, so controls placed at half a metre sit around the pilot's shins. They
are measured DOWN FROM THE EYES now, from the rig's own constant so the two cannot drift
apart, with a console under them so there is something to see.

**A control is grabbed by the part you hold, not by its origin.** A stick's grip is 22 cm up
its shaft, so a hand ON it was well outside a reach measured from the base: the control
simply could not be picked up while looking exactly as though it should be. `_grab_point()`
is where the hand goes, and each control says where that is.

### Shoulder level, and measured to the grip

Fixing those two put the controls somewhere reachable and left them 34 cm below the eyes and
44 cm forward -- around a seated pilot's lap, so you flew looking down and reaching out.
They are at shoulder height now: `HANDS_BELOW_EYES` 0.16 and `HANDS_FORWARD` 0.34, both in
`VehicleView` and both used by everything that places a control, including the desktop
rig's stand-in hands.

Those numbers are the position of the GRIP and not of the control's origin, which is the
part that is easy to get wrong twice. A stick mounts `FlightStick.SHAFT` lower than the hand
that holds it and a yoke mounts `ControlYoke.COLUMN` further back, so each control is
offset by its own dimension rather than by a constant somebody remembered.

Smoke asks each control where the hand goes -- `grip_global()` -- and measures it against a
head at eye height in the seat's own frame, instead of asserting a literal y that has to be
edited every time the cockpit moves. Currently the furthest is the crew button at 0.45 m.

**The airliner's shared throttle is the one that hangs off the VEHICLE**, so it is the one
that can be placed at hand height in the wrong frame: a seat anchor sits 0.30 m below the
vehicle's origin and 5.60 m forward of it, and a pedestal put at 0.99 in vehicle space
floats a third of a metre above everybody's hands. It is placed by transforming the ordinary
control position out of the pilot's frame and then sliding it onto the centre line. The
front seats were also brought in from 1.24 m apart to 0.84 m, because a control two people
share has to be inside two people's reach.

**A client must apply its own input to its own lever.** The write was guarded to the server,
so the client's throttle stayed shut while the server's opened, `CraftControls` rolled back
on the difference, and the pilot's own throttle became a rollback every tick. That is not a
throttle bug, it is prediction: a client that does not apply its own input is not predicting
anything.

### One trap worth writing down

Spawning a second pilot for a client who already has one used to leave them owning **two
pilot entities**, both carrying an input frame -- and the orphan went on delivering the
last command it was ever given. A test that did this had one crew button refuse to light.
Since lightgun S-1 (c7439df4, 2026-09-19) `spawn_pilot` instead **moves the client's one
pilot** into the new craft and returns that same entity -- so a test that spawns for
`Sim.local_client_id()` takes the rig out of its seat, and despawning the returned pilot
leaves the player with none. smoke did exactly that in its new-craft section and went red
on "not seated" in the cockpit, HUD and smoothness sections (smokefix). A test craft gets a
client id of its own; the local client is never a fixture.

**And a pilot row that names vehicle 0 while the server has the player seated is not the cockpit's to chase.** Nothing
on a client writes `Seats`; every seat change is `is_server_`. Before reading cockpit code, count on each world every
craft whose `vehicle_seats` holds that client, on every tick. cockpit-joinfix (2026-09-14) found the joiner's world
holding itself in four craft at once, and the set changed as baselines were acknowledged: ashiato-sync had freed a
frame another client still used as its baseline, and the recycled index handed that client another craft's components.
`../../ashiato-gd/addon/tests/crowd_join.gd` counts exactly that, and `../../ashiato-gd/LEARNINGS.md` has the mechanism.

### R puts the head back where it belongs

A tracked origin drifts. Somebody sits down after standing, turns their chair, or starts a
session facing the wrong way -- and a cockpit is built around a specific place and
direction, so a head that is not there is a head that cannot reach the controls or see out.

`RESET_BUT_KEEP_TILT`, because the horizon is not something to guess at: a headset's pitch
and roll are measured against gravity and are already right. On the desktop there is no
tracker to re-centre, so it is the mouse look that goes back to zero -- the same promise
either way, which is that you are facing the way the seat faces.

**And RESET HEAD on the clipboard (2026-09-13)**, asked for as "a ipad command for resetting the head position like
the 'r' key on the keyboard": a one-shot button in A ROW OF ITS OWN, above the switches and as big as MAIN MENU, on every
tab, because you reach for it when your head is wrong whatever page is up. The page announces `chose_recentre`, the
board passes it on, and `PilotRig` answers with `recentre` -- the call R makes. **Why its own row:** it was first put
in the switches row, and four there jammed BUTTON LABELS' toggle into its word and spaced the row unevenly -- a row of
three switches and one action, which is the row the note on MAIN MENU in `ui/menus/clipboard_page.gd` warns against.
Beside MAIN MENU was rejected for the same reason and a worse one: a beam slipping off it would land on an exit that
arms.

**The board's height budget after it (2026-09-13, a board of 1024 x 1280 with a time handed in and no debrief).** A row
of its own cost the scrolling page 91 px, and BUILD -- the fullest page -- then scrolled, 855 px of parts in 825. Bought
back: RESET HEAD at `reach(42)` rather than MAIN MENU's 46, the board's row gaps 10 -> 6 px (20 px, because a hidden
row takes no gap), BUILD's SAVE/RESET row 42 -> 38, and BUILD's answer line cut to one line (its second line was 37 px).
Content / scrolling area then, with one row of seven tabs: CRAFT 222/889, TRAFFIC 77/889, BUILD 848/889 (41 px spare), TIME 168/852; HELP scrolls
by design. **A tab whose answer line wraps to two lines has 37 px less page**, and BUILD is the page a new row of
furniture or a longer answer would push over first: at 4 px spare before the answer line was cut, it was one change
from scrolling.

**EVERYTHING BUILD'S ANSWER LINE SAYS IS ONE LINE**, because the line is dynamic and a second line is those 37 px
taken from BUILD while it is being used. Measured on the board (one line is 988 px of writing): the page's own line
701, the hands' USE line 783 and MOVE line 792, "Added PLUNGER THROTTLE..." 748, "...is the aircraft's, not yours to
move." 647, "Sit down first..." 579, "Back to the cockpit..." 490, "Could not write the layout." 310. "Saved to" and
the absolute path was 1225 px and two lines on Windows and longer on Linux, so the board says the file's name only --
"Saved battleship_seat3.json." (`PilotRig.saved_line`, no OS in it) -- and the console prints the path in full. A
`%APPDATA%` shortening fitted on Windows alone and was dropped. With any of them
showing, BUILD keeps its 41 px. A new message for BUILD is measured against 988 px
before it goes in. `tests/clipboard.gd` turns the look away (yaw 0.9, pitch -0.4), presses the
button with the right hand's beam, and asks the rig for a look of zero and a camera facing along the seat. RED, with
the connection cut: the look stayed at yaw 0.900, pitch -0.400.

### AN AUDIO TAB, AND THE TABS IN TWO ROWS

Asked for on 2026-09-13: "I wasn't able to find the settings for audio the last time I played. There should be an audio
panel on the iPad", and "make sure that the top tabs on the iPad are wrapped correctly". `Headphones` had GAME SOUND and
VOICE from the day before (see "A VOICE ON THE RADIO, AND BOTH EARS OFF AT START") and no page showed either.

**AUDIO is the seventh of eight tabs** (CRAFT, CREW, TRAFFIC, FEEL, BUILD, TIME, AUDIO, HELP): two plain CheckButtons, GAME
SOUND and VOICE, and under VOICE the headphones' own line saying what it is doing or why it cannot ("No voice library
(...): run kokoro-gd/scripts/build.ps1"). The page announces `chose_game_sound` and `chose_voice`, `PilotRig` hands both to
`Headphones`, and `Headphones.changed` hands the answer back to `show_audio`: FINE SCENERY's shape with `Finish`. A flick
puts the switch back to what the headphones last said, as the TIME buttons do, so VOICE with no model springs back off
with the reason under it. Its answer line is one line: "Both start off every time. VOICE takes a few seconds to load."

**The tabs are a grid of four columns, so eight are two rows of four.** One row of eight at the tab size wants 1013 px of
the page's 988 (957 px of words and seven 8 px gaps), and a row wider than the page widens the whole column and cuts its
right-hand edge off the glass. Each tab is now 241 x 80 px, where seven in one row were about 134 wide, at the same
`reach(46)` height and `pressed_text(22)` words. **No tab text scale:** a draft shrank the tab words to fit one row, and it
was dropped because the words were to stay as big as everything else you press. **A grid, not an `HFlowContainer`**, which
wraps where the words run out and would make rows of five and three.

**The second row cost the page 84 px (80 and a 4 px row gap), and BUILD's parts bin paid for it.** Twenty parts in two
columns were ten rows; in three they are seven, and the widest words, "+ PLUNGER THROTTLE", are 320 px on a button 328 px
wide, so nothing wraps and no part is shorter. The margins, the gaps and the PARTS heading are as they were. Worked out and
not needed: margins 14 -> 6 px, gaps 6 -> 4 px and no PARTS heading, about 58 px between them.

**The board's height budget now** (1024 x 1280, a time of day handed in, measured by a throwaway probe on the double
editor, 2026-09-14, with the switches in two rows of two since HUD -- see "A SWITCH THAT IS OFF LOOKS LIKE A SWITCH"):
content / scrolling area, CRAFT 222/739, TRAFFIC 77/739, BUILD 644/739 (95 px spare), TIME 168/702 (its answer line is two
lines), AUDIO 134/739 without a reason line; HELP and FEEL scroll by design. The second row of switches cost every page
67 px (a `reach(36)` row of 63 and a 4 px gap); before it the areas were 806 and BUILD had 162 spare. **With the fire
debrief showing**, a line of furniture on every tab, the areas are 41 px shorter and BUILD is 644/698 (54 px spare). **The fit check measures that
case now:** `measure_the_board` goes round every tab twice, without the debrief and with the longest sentence
`FireFront.debrief` writes, because BUILD scrolling in the middle of a fire is the same bug as BUILD scrolling at a console,
and nothing had measured it.

**How it was proved** (`tests/clipboard.gd`, pressed with the right hand's beam and trigger): every tab lies whole on the
glass at its own height and word size and wider than its word -- RED with `ClipboardPage.TABS_IN_A_ROW` at 8, which also
failed `nothing_on_the_board_runs_past_the_edges_of_the_glass`; the beam on AUDIO turns to a page that was hidden on
CRAFT -- RED with the page never hidden, which first PASSED an earlier form of the check that did not ask whether it had
been hidden, so the check asks now; eight clicks of the stick visit every tab in order and come back to CRAFT -- RED with
the wrap one tab short, "visited CREW, TRAFFIC, FEEL, BUILD, TIME, AUDIO, CRAFT, CREW"; GAME SOUND unmutes the Game bus and
leaves the Radio bus as it was, and a second pull mutes it; VOICE with `KOKORO_MODELS` pointed at an empty folder springs
back off with the reason under it -- both RED with the rig's two connections to `Headphones` cut ("switch false, headphones
false, game bus muted true"; "said ''"); and the fit check with the debrief -- RED with the parts back in two columns,
"BUILD (848 px of content in 806)" and "BUILD (848 px of content in 765 with the debrief)".

### THE BOARD CLEAR OF THE CONTROLLER HOLDING IT

Asked for on 2026-09-13: "the iPad should be raised a couple units. Right now the controller is blocking the bottom part
of it." `Clipboard.AT` moved 3.0 cm up and 5.5 cm forward in the holding hand's frame, from (0.05, 0.06, -0.15) to
(0.05, 0.09, -0.205), with the tilt unchanged.

**Judged as the eye sees the glass, not as a gap in the hand's frame.** The first measure was the bezel's bottom edge
at least 2 cm above the controller's top in the hand's frame: 12.5 cm of raise on paper. It was rejected because a line
of sight comes in at an angle, and the button labels float above the controller and are drawn over everything, the
board included. So `tests/clipboard.gd`'s `controller_clear_of_the_glass` stands an eye 40 cm straight out from the middle
of the glass. It projects the box of every mesh of the holding hand's `ControllerModel`, and of every label it is showing,
through that eye onto the glass's plane, and asks for at least 1 cm between each and the glass rectangle (the bezel may
be covered). It works in the glass's own frame and reads the nodes the rig built, so no arm pose and no typed size
enters into it.

**Measured with BUTTON LABELS on and the board up (9 parts and 4 labels):** at the old offset the controller's ring
was 4.6 cm over the glass, which is the bottom of the page: MAIN MENU and the switches. A throwaway probe stepped the
glass up and forward in half-centimetre steps, up to 15 cm each, and asked the same function each time. Up alone needed
10.5 cm, forward alone 8.0 cm, and the least total move was 3.0 up and 5.5 forward (6.3 cm), which leaves the nearest
thing, a label, 1.1 cm off the glass. **The board is now 5.5 cm further from the eye than it was**, which was the trade
against lifting it 10.5 cm towards the face. `objects/seats/placing_grid.gd`'s `BOARD_AT` still copies the old lie out to
the side, and nothing there sits over a controller, so it was left as it is.

**How it was proved:** `the_controller_holding_the_board_does_not_cover_its_glass` in `tests/clipboard.gd`, RED at the old
offset and green at the new one. The beam, RESET HEAD and fit checks are unchanged and still pass: they aim at the glass
wherever it is. Before and after, the board was shot from a seated eye placed in the hand's frame, with the labels on.

### A SWITCH THAT IS OFF LOOKS LIKE A SWITCH

Asked for on 2026-09-13: "make the off switches easier to see". Godot's unchecked CheckButton icon is 32 x 16 px with a
dot in it, and on the board's near-black the dot was all that showed: LABELS, VOICE and the snap board's POSITION SNAP read
as words with a stray mark beside them.

**One Theme, built once, at each board's root.** `BoardStyle.theme()` draws CheckButton's eight icons into Images in code
-- checked, unchecked, their `_disabled` forms and `_mirrored` forms of all four, which is the whole list `get_icon_list`
gives on 4.7.2, with no hover icon -- and sets `h_separation`. OFF is an outlined `DIM` pill with its knob on the left,
ON a filled `AMBER` pill with a dark knob on the right, so the two differ by shape and by brightness and not by colour
alone; disabled keeps 45 % of its alpha. `ClipboardPage._ready` and `SnapPage._ready` set `theme = BoardStyle.theme()`
and nothing else does: an `add_theme_icon_override` on each switch was the other way, eleven call sites today and a
twelfth that forgets. `BoardStyle.BOARD` is the board's colour, which both pages paint and the test measures against.
**The MFD is left out**: `MfdPage` is an instrument in the cockpit with its own glass and 12 px writing, not a board.
`GuardedButton` is a Button and sets its own armed colours per control; this Theme holds nothing for Button.

**The pill is 48 x 25 px with a 6 px gap, because of BUTTON LABELS.** The design was a pill the height of the switch's own
words, 61 x 32 with a `reach(8)` 14 px gap. In the row of three switches BUTTON LABELS has a third of 988 px, 324, and
asked 300 with Godot's icon and 4 px gap; at 61 x 32 and 14 it asked 339 and would have widened the row off the glass,
and 56 x 32 with 7 still asked 327. As tall as the board's writing, `BoardStyle.text(18)`, it asks 318 (6 px spare).
**Team-lead's floor (2026-09-14) is a 48 x 24 pill and a 6 px gap**: past that the row is laid out again, not the switch
made smaller. Everything else has room: USE CONTROLS asks 325 of 490, ROTATION SNAP 321 of 655, and FEEL's TURN takes
its extra 18 px out of the name beside it. Every tab's height is unchanged -- CRAFT 222/806, TRAFFIC 77/806, BUILD
644/806 (162 px spare), TIME 168/769, AUDIO 134/806 -- because the pill is shorter than the words it sits beside.

**How it was proved** (`tests/clipboard.gd`, `_an_off_switch_looks_like_a_switch`): LABELS on the clipboard and ROTATION
SNAP on the snap board each resolve their off icon to the theme's texture. The off icon's own pixels, kept as Images
because a headless ImageTexture reads back nothing: 389 of 1200 px drawn (32 %, `SWITCH_COVER_LEAST` 25 %), 6.3:1
against `BOARD` (`SWITCH_CONTRAST_LEAST` 3:1), and their mean x 19.1 of 48 where the on icon's knob is at 36.0. RED with
the clipboard page's `theme` line removed: LABELS resolved a `DPITexture`, Godot's own, while ROTATION SNAP still wore
the theme. RED with `SWITCH_OFF := BOARD`: "1.0:1 against the board". Looked at on the stock editor, windowed, on CRAFT,
TIME, AUDIO and BUILD with switches both ways, and on the snap board in a lit room with ROTATION on and POSITION off: its
3 cm bezel, steppers, axis buttons and RESET POSITION read as they did.

**And each pill beside its own words (2026-09-14).** A CheckButton draws its pill against its right-hand edge, so a switch
stretched across its share of a row put LABELS' pill 20 px from the words FINE SCENERY and 152 px from its own, and FINE
SCENERY's 20 px from BUTTON LABELS and 48 from its own; on AUDIO, VOICE's pill stood 835 px from its word and 27 px from
the voice's reason line under it. The row of three and BUILD / USE CONTROLS are now `SIZE_EXPAND | SIZE_SHRINK_CENTER`:
EXPAND keeps the shares equal, and SHRINK_CENTER sits the switch -- as wide as its words, gap and pill -- in the middle of
its share. GAME SOUND, VOICE and the snap board's two switches are `SIZE_SHRINK_BEGIN`, from the left. The snap board's
were never beside anybody else's words (about 340 px from their own, with nothing between, and the check passes with
them stretched), and are moved only so both boards read the same. A switch is a narrower target now -- LABELS 178 px
rather than 324 -- and as tall as it was; the beam checks aim at a switch's middle and pass.
`and_every_switchs_pill_is_nearer_its_own_words_than_any_others` measures every switch against every switch and label
showing, on all eight tabs of a board at a console (so FEEL's TURN switches are in it) and on the snap board with a grid
handed in: a switch's words from its stylebox's left margin at their font's width, its pill against its right margin.
RED on the stretched layout with the distances above, green after.

## MULTI-FUNCTION DISPLAYS, FOR THE SEATS THAT DO NOT FLY

A pilot has a windscreen, a stick and a horizon. A gunner sitting sideways in the back of a
boat has a screen, and that is the whole of what they can know -- so the screen has to be
worth having.

On the F/A-18's pattern, which is worth copying because it was designed for exactly this
problem. A Hornet carries three: a Digital Display Indicator either side of the windscreen
and a colour Multi-Purpose Display low on the centre console. TWENTY PUSHBUTTONS round each
bezel, five to a side, and the one in the middle of the bottom row is MENU -- press it for
the TACTICAL menu, press it again for SUPPORT, and everything else is a page selected off
one of those two.

    TAC     STORES, ATTK RDR, EW, SA, TGT DATA
    SUPT    HSI, ADI, ENG, FCS, BIT, CHKLST

**Only the pages this game can actually answer.** A real Hornet has a fuel page and this
aeroplane does not model fuel, so there is no fuel page. An instrument showing a plausible
number it did not measure is worse than no instrument, and it is the kind of lie you only
notice in the accident report -- the same rule `CraftPage.reading` already applies to a
single value, applied to a whole page. `and_says_so_when_the_craft_has_not_said` holds it:
a boat with nothing taking it anywhere reads dashes to its waypoint, not zero.

**Three of the pages are one picture.** The attack radar, the situation display and the
electronic warfare page are all "what is out there and where", so they are one plan view
with different dressing: own ship in the middle, nose up, every contact at its bearing and
range, scaled to the furthest thing shown so the picture is never empty. Bearings are
RELATIVE to the nose, because a bearing on a screen in a cockpit is an instruction about
where to look, and where to look is measured from where you are already facing.

**The data had to be shared before a page could draw it.** `CraftPage`'s rule is that a page
is handed its data and never asks the simulation anything, so anything a page wants that is
not in the state is a gap in what the craft SHARES. `craft_state` publishes attitude,
position, the route, the whole command bus, the linkage and the nearest eight contacts now,
and every seat's screen reads the same numbers from the same place.

### Three pages you can work, and the bus is what shares them

    SWITCHES   a column of CheckButtons, one per switch this craft has
    RADIO      an HSlider and a big readout
    MODE       a ButtonGroup: one of several, never two

Three different Godot idioms on purpose, because the interesting part is not the widget.

**PRESSING ONE DOES NOT MOVE IT.** The press emits a command, the command goes on the
replicated bus, the bus comes back as craft state, and the page draws what came back. So a
switch moves because the craft says it moved -- which is why the gunner copy and the driver
copy move at the same moment, and why nobody had to write a line of code to make that true.

That is the same lesson as the shared throttle, which jittered for exactly the opposite
reason: a control the whole craft owns is read from the wire, not from the hand that last
touched it. `and_pressing_one_asks_the_bus_rather_than_setting_it` holds it -- the command
goes out, and the switch still reads its old value until the state says otherwise.

`CraftPage` grew one signal for this and nothing else. A page still never touches the
simulation: it emits `commanded`, and `CraftDisplay`, which is a cockpit thing, does the
sending. `set_pressed_no_signal` on the way back, or drawing the state would look like
somebody pressing it and send the command round again for ever. The slider is not written
under a finger that is dragging it, for the same reason the shared throttle is not.

**Only the switches the craft actually has.** The pages are built from `craft_schema` --
which channels are fitted, what they are called, and how many positions each has. A gunboat
has a radio and a hover hold; an aeroplane has flaps, gear, spoilers and a master arm. A
screen offering all of them everywhere is a screen with dead switches on it, so the MODE
page says the craft own word for its selector and the SWITCHES page has nothing on it at all
where there is nothing to switch.

**Which seats get them is the vehicle's business, not the station's.** The same station
scene is used by the pilot and by the gunner; only the simulation's seat table says which is
which. `VehicleView.man` reads `flies` off the seat poses and passes it to
`CockpitStation.fit`, which fits two displays to any seat that does not.

### AN E-2D HAWKEYE AND A VIRGINIA-CLASS SUBMARINE

The user asked on 2026-09-15 for two craft in the US Navy fleet, each true to the real thing including its size. The
sourced sheets are in `godotgames-drafts/2026-09-15/cockpit-fleet/lane-work-backup/design/` (research-hawkeye.md,
research-hawkeye-measured.md, research-hawkeye-inertia.md, research-submarine.md). `tests/fleet_shapes.gd` holds both to
them; `tests/boat_seats.gd` holds the submarine's draught, watch and float with the other boats.

**`Sim.Kind.HAWKEYE`, 19, an `Airplane`.** 17.60 m long, 24.56 m in span (drawn only), a 2.1 x 2.2 m fuselage box MEASURED
off an official E-2C three-view, 23,000 kg between empty and full. Four of the five crew: the pilot and co-pilot side by
side, and the radar officer and the CIC officer turned to port under the rotodome, as they sit on station; the air control
officer is left out, because the wire carries four.

- **Its inertia is STATED, not the box's** (`Shape::inertia_pitch`, `_yaw`, `_roll`; zero keeps the box's). A kind's body is
  its fuselage box, and the E-2's wing, engines and rotodome carry most of the real inertia: the box rolled with
  17,700 kg m^2 and settled at the rate asked for in 0.02 s. No E-2 or C-2 inertia is published where an agent can read it,
  so roll 190,000, pitch 270,000 and yaw 420,000 kg m^2 are an ESTIMATE from component masses.
  - `state_inertia` writes the named diagonal terms through `b3Body_SetMassData` in `ensure_body` and keeps the mass and
    centre. Box3D recomputes a mass only in SetType, SetMotionLocks, a shape created or destroyed with a mass update,
    SetDensity with one, and ApplyMassFromShapes, and nothing here calls one after `ensure_body`. A rollback moves the same
    body; a respawn is a fresh `ensure_body`.
  - A zero written into the matrix inverts to zero, which Box3D reads as a body that never turns: an axis a kind leaves at
    zero keeps the box's own.
  - `body_mass(entity)` reads mass, centre and the three moments back from Box3D. fleet_shapes asks it after a spawn, 900
    ticks of flight, a client's rollbacks and a respawn, and every other one-box kind is held to m/3 (b^2 + c^2).
  - Rejected: a wing-span box (it collides 24.56 m wide, folded on a deck too, and `extents` is what every seat and
    placement check reads), and wing parts (the ship path, with 0.05 hull friction that pins an aeroplane on its wheels).
- **The handling** was chosen by the arithmetic, settled rate = rate x (K/I) / (K/I + c), and measured on the built library
  (fleet_shapes prints it): K 400,000 N m per rad/s of error, damping 1.3, rates asked 1.1 / 0.9 / 0.6 rad/s in pitch, roll and yaw.

  | axis | stated inertia | settles at | arithmetic | 63 % in | arithmetic |
  |---|---|---|---|---|---|
  | pitch | 270,000 | 0.534 rad/s | 0.586 | 0.32 s | 0.36 |
  | roll | 190,000 | 0.553 rad/s | 0.556 | 0.28 s | 0.29 |
  | yaw | 420,000 | 0.093 rad/s | 0.254 | 0.13 s | 0.44 |

  Roll is held to the arithmetic, since roll is where the box was wrongest and the fewest aerodynamic torques act on it;
  the weathervane and yaw damping take most of yaw's. Pitch reaches 0.386 rad/s 0.4 s after full stick against the
  airliner's 0.393, and a 30 degree bank takes about 1.2 s. The target rates are an ESTIMATE; MIL-F-8785C, the candidate source for a
  Class II carrier aircraft's roll time, could not be fetched.
- **The wing fold is `Sim.Channel.FOLD`, 7, bit 3 of `CraftControls::switches`**: on the physical half beside the gear,
  because everybody outside the aircraft sees it, and no wire change. Folding with no weight on the wheels is refused, the
  gear's squat switch the other way round; spreading is always allowed. **A Hawkeye put down on something is spawned
  folded, everywhere, runways included** (team-lead, 2026-09-15): `spawn_vehicle` sets the fold bit where it lowers the gear,
  because a level's parked Hawkeye has nobody aboard to fold it. A pilot who boards spreads it through the real switch, and
  one taken from the pilot's seat is spread by `launch_if_grounded`. It has its own case in `command()`, because that
  switch's `default:` is the spoilers', and a fold without one deployed them. `launch_if_grounded` spreads the wings of a
  parked Hawkeye taken from the pilot's seat.
- **The widest turn in the game.** At its real 180 m/s flat out and the autopilot's default bank it turns 2,624 m, and the
  soft edge's band is as deep as that. There is no Hawkeye case in `fly_it_like_a`: an airliner-like 0.44 rad would be
  a 7,023 m turn, which neither level can take (measured with it built in: the island refused by 1,087 m, alpine by
  6,098 m), and `tests/terrain_level.gd`'s `every_level_fits_the_widest_turn` fails first, in words.
- **Drawn by its own builder, `HawkeyeAirframe`,** in place of the box and the end markers, as the brig is (`Body.HAWKEYE`):
  the fuselage over the collision box, the high wing and its folding outer panels, two lofted nacelles with eight-blade
  propellers, the rotodome on its post and struts, and a dihedral tailplane with four fins. Every size is the shape table's
  extents and span, or a fitting that names its source in the builder.
  - **Not in `_body`.** `_show_body` paints one flat material over every mesh there, and the airframe's colour is in its
    vertices: a crew that boarded and left would have brought it back plain grey. It is hidden instead, never repainted.
  - **The fold is the bus's.** The view eases the drawn panels toward `craft_controls(entity)["fold"]` over
    `HawkeyeAirframe.FOLD_SECONDS` (12 s, an estimate), starting where the bus has them. The hinge is on the wing's upper
    surface at 0.75 of the chord: hinged at the quarter chord, the folded panels stood as walls through the rotodome, and only
    a picture showed it. `tests/fleet_shapes.gd` measures the folded width and the panels' tops from their drawn vertices,
    never a rotated box round a box (which read 9.67 m against 8.81 m).
  - **The rotodome turns on this machine's physics clock,** six turns a minute: nothing on the wire, and not in phase from
    one machine to the next, like every rotor disc.
  - **Lights and contrails stand on the drawn tips** (`HawkeyeAirframe.wingtips`), not the plank's, which are 0.64 m low and
    forward of them; the beacon stands on the rotodome's top.
  - `tests/hawkeye_shot.gd` photographs it in the air and parked folded on the carrier (a probe, not a suite).

**`Sim.Kind.SUBMARINE`, 20, a `Boat`.** A Block IV Virginia surfaced: 114.9 m long, a round hull 10.36 m across, 7,925 t,
the keel 8.84 m down (29 ft, between the published 32 ft, which has no primary source, and the 28 ft of a surfaced
photograph). Its frame is the carrier's, midships on the design waterline. The sail's place and size are MEASURED off a
scale-checked drawing and two Navy photographs, because none is published.

- **The watch stands in a well** at the forward end of the sail top, officer of the deck and lookout, the eye 8.21 m over the
  sea. Parts are convex and every solid part is a place a head must not be, so the sail stops at the well's grating and its
  top edge is four island boxes round the well.
- **`Terrain.is_a_ship`** includes it, so it is placed in `ship_depth` = 16.84 m of water.
- **Its surfaced speed is not published:** an 8 m/s hull speed is an ESTIMATE. A submarine sailed out at it, its autopilot
  steering for a waypoint past the edge, is held 761 m inside the soft edge's 2,624 m band by its rudder with no guard: it
  does not come home while its autopilot wants out (`tests/world_edge.gd`).
- **Drawn by its own builder, `Submarine.build`** (`ShipHull.models`' "submarine" arm), not `Superstructure`, which lofts
  ship lines: a round hull in rings about its axis, an ellipsoidal bow, a stern cone into the pump-jet shroud, the sail with
  its fillet and domed top, housed bow planes, a cruciform stern, draught marks, the raised masts, and the well with its
  rail. The catalogue's helm is `"well"`, handed to the builder.
  - **The grating is at the bridge part's bottom,** where the seats stand. The sail body's own top lies 8 cm under it, so
    the watch has a floor either way: a grating painted up on the rim stayed green in `tests/ship_models.gd`.
  - **The rail is 0.77 m over the rim,** waist-high to the watch, an open frame of posts and a bar. From an eye 8.21 m
    over the sea the bow and the casing ahead are in sight past it; with the first draft's 1.0 m rail they still are, since
    a line passes under or over a thin bar, so the rail's height is not what a check here guards.
  - **Every mast stands on the sail top** (`Superstructure.top_under`): with the masts' feet a metre up,
    `tests/ship_models.gd`'s fittings check fails, the bug the battleship's first draft had with its mounts.
  - **The side is held at the ship's own height:** the lower of just under the waterline and the ship-wide hull middle. A
    round hull is widest at its axis, under the sea, and its stern cone lies awash aft; the middle is over every hull part,
    or the battleship's forecastle and main deck would sample at two heights (cockpit-carrier's ruling).
  - `tests/ship_shot.gd` photographs the level's own submarine, found as drawn by kind, never by the spawn's id (the
    server's). Until step 4 put one to sea it spawned one beside the carrier; that is gone.

**Where they start** (`Terrain.spawns()`, both levels). The Ford's spawn is named `&"ford"` (`Terrain._named`); an E-2D is
parked on its deck at `CarrierPlan.PARKED`, carried at the ship's velocity and placed `&"carrier"` with `on = &"ford"`
(`Terrain.parked_on`); a submarine is under way 3 km further out; and an E-2D flies on station near the carrier.
- **A craft parked on a ship is still parked while it moves through the world.** Every branch that read "faster than
  1 m/s" as "launched" asks the place instead: sky.gd's spawn loop gives it no autopilot, `_spawns_on_the_ground` stands it
  on its carrier as that arm placed it, and terrain_level judges it on the deck and at rest in the carrier's frame.
- **The carrier is found by name, and asked, never predicted.** sky.gd records which entity each named spawn became
  (`FlightLevel.spawned_entity`), and the rest check asks the simulation where the carrier is now: its autopilot steers and
  the sea heaves it. A carrier the generated ground cannot place takes what is parked on it with it, saying so by name, and
  `every_named_carrier_and_what_is_parked_on_it_is_placed` holds that no real level does.
- **Every kind with an autopilot has a pool of its own:** the Hawkeye joins the wings', and the submarine sails the boats'
  offshore points on the island (the island's sea has no floor) and its own on the generated ground, open sea as deep as
  its resting place needs, each point with a leg out as deep as its moving need.

### THE BOEING 747-400, THE 737-800 AND THE C-130s (lane/liners, 2026-09-19)

**`Sim.Kind.JUMBO`, 22, an `Airplane`**, the Boeing 747-400. It was `MERCURY`, an E-6B blockout under protocol 10, and
the row was renamed in place, so the number on the wire and in saved levels is the Mercury's. **`Sim.Kind.AIRLINER`**
is the Boeing 737-800W, and **`Sim.Kind.GUNSHIP`** the AC-130U on a C-130H with **`Sim.Kind.TRANSPORT`**, 34, the same
airframe unarmed. All four are drawn by one builder, `objects/vehicles/jetliner_airframe.gd`, from each aeroplane's
table (`boeing737_airframe.gd`, `boeing747_airframe.gd`, `hercules_airframe.gd`), and each was measured off a
manufacturer's drawing scaled by one printed number: `craft/airliner/sources.md`, `craft/jumbo/sources.md` and
`craft/gunship/sources.md` say where, with the overlays at x1.000 and their per cent agreement.

- **The simulation's shape is the drawing's since protocol 36**: each kind's box is its airframe's `GEOMETRY`, its
  pilots sit `EYE_HEIGHT` under the drawn eyes (captain LEFT), and its mass is a real one (62, 280 and 55 t). THE
  HANDLING WAS NOT RETUNED: every force and torque in each row, and each kind's moments, were carried from the mass it was
  tuned at to the new one by the same ratio (`carry_to_mass`, `keep_the_tuned_moments`), so each flies as it was flown.
  Tuning them to the real aeroplanes is the flight-model work's.
- **The gunship's guns** fire from the drawn muzzles (`gun_of` is the one table; `HerculesAirframe.gun_mount` draws from
  it) and STOW: a two-position knob at each gunner's station on the Mode channel, "stow guns", mirrored onto the craft's
  outside flags (bit 2, `kGunsStowedBit`) so every machine draws them in, and a stowed gun does not fire
  (`tests/gun_stow.gd`, from the gunner's wrist to a client's drawing).
- **The C-130s' ramp** is on the drop channel, as the V-22's is, and the console's red drop lever works it.
- The 747's two operators sit on the upper deck behind the flight deck, facing consoles on its walls; an operator
  station fits only display and communications-mode selectors plus its displays, and the server accepts those system
  bus channels while refusing physical flight commands from that role.
- `tests/airliners.gd`, `tests/hercules.gd` and `tests/jumbo.gd` hold the drawings; `craft/<kind>/1/` are the immutable
  builder revisions, generated by `tools/generate_authored_packages.tscn` and verified by `tests/stations.gd` and
  `tests/craft_package.gd`.

### THE TANDEM FIGHTER

**`Sim.Kind.FIGHTER`, 23, an `Airplane`.** A two-seat F/A-18F Super Hornet: a native hull
18.5 m long and 22,000 kg representative operating mass, with distinct pilot and operator/WSO
station identities. `craft/fighter/sources.md` records every reference and the boundary: the
model is original geometry measured from them, and nothing of theirs is incorporated.

**THE AIRFRAME IS MEASURED, NOT IMPRESSED (cockpit-hornet, 2026-09-17).** The first model was a
cylinder and a capsule that passed its 2% envelope check while nothing inside the box looked
like a Hornet -- "the recently added f-18 doesn't look very close to the real thing" (the user).
`FighterAirframe` now lofts the forebody through sixteen measured sections and draws the
tandem canopy, LEX, caret intakes, a wing whose leading-edge flaps, trailing-edge flaps and
ailerons are separate slabs parting at the fold, canted fins with rudders, stabilators,
nozzles, gear with doors, and a hook. `tests/fighter.gd` measures the DRAWN VERTICES against
reference figures typed from their sources, never against the airframe's own constants:
18.38 x 13.68 x 4.88 m (Navy: 60.3 ft is 18.38 m, not the 18.5 this section used to say), fins
19.9 degrees against NASA's 20, LEX edge 1.47 m out at 8.2 m aft, track 3.11 m, wheelbase 6.32 m.
`tests/fighter_inspector_shot.gd --ortho` draws side, front and top at 40 px/m to lay the NASA
HARV three-view over; the fins and main wheels coincide in the front view.

**Its wheels stand where the hull rests, which is not where the old model put them.** A parked
fighter's origin rests 1.0998 m over flat ground (the hull's half-height); the suite asks the
simulation for that and puts the lowest drawn wheel there. **A true-scale fuselage on those
wheels showed the seats were 0.5 m low**: a real pilot's eye is about 3.05 m over the ground,
the package's was 2.55, level with the canopy sill. The seats are moved by a package migration,
not by squashing the airframe.

**Gear and hook are drawn from the bus, straight from the command.** `set_gear` and `set_hook` are
pure functions of a 0..1 amount (doors first down, last up), and `VehicleView` hands them the bus's
gear bit and a `hook` bit as 1 or 0, as the nacelles are drawn. No timer and no eased copy: the
travel time will be the simulation's (`actuators_research.md` section 3.8), and a drawn clock here
would be one more thing to delete. An aircraft issued in the air is drawn gear-up from its first frame.
Gear up hides every gear and door part inside the drawn skin, checked with vertical segments
through the airframe's triangles; the deployed hook's shoe is on the ground. **Gear up on the
ground draws a floating belly**: the hull, not the fuselage, is what rests, so a belly landing
leaves the drawn fuselage 0.9 m over the runway. Only a landing on the belly gets there; it is
noted and not fixed. The nav lights and contrails stand on the drawn launcher rails
(`FighterAirframe.wingtips`), not on the plank's numbers, which were 1 m low and 2.7 m forward.

The fighter is the first craft to exercise the package `visual` boundary. Its scene remains
replaceable by a metre-scale GLB with the same declared dimensions and sockets, while the
procedural scene is both the current visual and the fallback; its sockets are the airframe's own
axles, hook pivot and middle pylons, and the suite fails when the package's copy parts from
`FighterAirframe.sockets()`. `tests/fighter.gd` holds exact native dimensions and stations, the
measured structure, the 20-draw/100,000-triangle/12-material budgets (14 draws, 2,670 triangles,
3 materials), immutable package reload, pilot/WSO coexistence and a replicated client's selection
and control reaching the authoritative server. `tests/fighter_inspector_shot.gd`
records exterior plus side/front/top inspector views; `tests/station_gallery_shot.gd`
with `-- --only=fighter` records both initial eye views in the reference room.

## THE HALL OF COCKPITS

    Godot --path cockpit -- --level=hall

Every cockpit in the game, in a row, with nothing round them. No fuselages, no world, no
simulation. SPACE for the next, SHIFT+SPACE for the last, and the MENU BUTTON on the left
controller in a headset.

A cockpit is the part of a craft anybody actually spends time in, and the only way to judge
one is to sit in it and reach for things -- which until now meant loading a world of a
hundred and sixty machines and flying to the right one.

**One per station SCENE, not one per kind.** Eight of the fourteen craft sit at the same
station, and a hall with eight identical light-aeroplane cockpits in it is a hall you cannot
find anything in. The nameplate lists every kind that shares the station, which is the thing
you actually want to know.

**`PilotRig.take_station` is the one thing this needed that did not exist.** The rig finds
its controls by looking for the `VehicleView` its seat hangs off; in the hall the seat hangs
off a plinth. So a station can now be handed over directly, and `_claim_controls` splits
into the part that finds a set of controls and `_take`, which does not care where they came
from. A station on a stand and a station in an aeroplane are the same thing from there on.

### And a second screen at the desk to reach it from, and a third for the level

Every door in the router was already reachable from a command line, and a command line is a
poor thing to reach for with a headset on. So the desk has two panels now, angled in at the
chair rather than lying flat side by side: the session screen says WHO you are playing with,
the level screen says WHERE you are going. Separate, because they are separate questions --
a solo session in the hall of cockpits is a perfectly ordinary thing to want.

**Three screens since 2026-09-15**: "add a third monitor and reposition the other two so that they all fit on the desk.
I'd like to have a monitor so I can choose different levels." Left to right: WHICH LEVEL (`ChartMenu`), the session
screen (`SessionMenu`), WHERE TO (`LevelMenu`, the doors). The level row that sat on the session screen moved to the new
one; see "LEVELS: A FOLDER EACH".

They stand in an arc worked out from the desk, in `DeskRoom` (`world/desk.gd`):
- `DESK`, `DESK_MIDDLE` and `CHAIR` are constants. `_build_the_room` builds from them and so does the layout.
- Two 62 cm screens turned toward the chair would have needed 1.9 m of a 1.6 m desk. So `SCREEN_WIDTH` is solved in one
  line: the middle frame's width, plus each turned frame's footprint across as seen from above, plus two gaps and two
  edges, equals the desk's width. Every term is linear in the width. It comes to 48.5 cm, and the page keeps its
  1024 x 760 px shape.
- The bezel is `TouchPanel.BEZEL` and `BEZEL_DEPTH`, named for this. `SCREEN_AT` now counts the frame; before, every
  frame's lower edge was 1 cm into the desk.
- `SCREEN_TURN` (0.8 rad) is the one choice. The end screens face the chair square on, and the more they turn the
  nearer the chair they stand. At 0.8 the front corner is 1.5 cm inside the desk's front edge and all three stand
  0.73 m from the eye across the floor. At 0.9 it hangs 7.7 cm over. At 0.35 they stand 1.5 m off, beyond the back.
- **The words grew when the screens shrank.** Measured with `tests/builder.gd`'s formula at 20 px a degree, one page
  pixel of text covers 0.639 headset px at a screen's middle; it was 0.887 on the old desk. So every page's smallest
  words went from 14–16 px to 20 px, which reads 12.8 headset px, and the rest were scaled with them (door rows 24).
  Builder's 20 headset px minimum would need 32 px words. That fits the session and levels pages, but WHERE TO would
  need its craft picker moved to a view of its own.
- From the eye an end screen's outer corner is 72 degrees off straight ahead. A head turns to it, and a monitor
  player turns with the captured mouse; the two old screens were already cut off at the bottom of the desk camera's
  view.

`tests/desk_screens.gd` holds it:
- the three frames rest on the desk top, inside its edges, and no two boxes meet. Both are measured from every mesh
  vertex carried by its global transform; 1.5 cm apart.
- the levels screen has a row for every folder under `levels/`, read off the folder with `DirAccess` rather than asked
  of the drawer.
- a beam pull on a level makes it `Net.level` and marks it, through the desk's own handler.

Mutants, each restored and proved by SHA-256:
- the desk handing the screen `charts().slice(0, 1)`: 2 checks red, rows ["island"];
- the press not connected: 1 red, Net.level still island;
- `SCREEN_TURN` 0.9: 1 red, both end screens to z 0.477;
- `SCREEN_GAP` -0.03: 2 red, overlapping by 3 cm.

The craft picker is a wrapped row of small toggle buttons and not a dropdown. A popup opens
a real window when the panel is a SubViewport with embedded subwindows off, which in a
headset is a window you can neither see nor dismiss.

The world goes through `change_scene_to_file`; the bench does not. It has to be told which
craft and which mode, and those are exports rather than anything a scene path can carry, so
it is built, told and swapped in -- deferred, because swapping a scene inside a signal is
the same "busy adding/removing children" the boot router was caught by.

`and_every_door_is_on_it` names all five, so a level added to the router and forgotten on
the screen is a level nobody in a headset can reach.

**The test for the hall lives in its own section, and that is not tidiness.** It puts a SECOND rig
in the scene and lets frames pass. Dropped into the middle of the cockpit section it broke
two checks three hundred lines further down -- the ones that put a hand on a control and
expect to look at the result before any frame runs.

## A FUSELAGE WITH HOLES IN IT

A hull was one `BoxMesh`, and a box cannot be seen out of, so the whole airframe was hidden
the moment its owner climbed in. `HullSkin` builds it from PANELS instead -- belly, sides,
bulkheads, roof, and a greenhouse over the crew -- and **a window is a panel that is not
emitted**. No glass, for the reason `cockpit_shell.gd` gave about the canopy years before:
glass reflects, refracts, catches the sun and hides the world, for no gain over a gap.

One `ArrayMesh` per hull, built by appending `BoxMesh` through `SurfaceTool.append_from`, so
a hull with twenty panels in it is FEWER draw calls than the single box it replaces, and the
winding, normals and tangents come from a primitive that already knows them. The panels are
handed back as plain boxes too, which is what lets every check below be arithmetic rather
than a physics query.

### The pilots have been sitting outside their own aeroplanes

The measurement that forced the shape of this: a light aeroplane's hull is 1.4 m tall and
its seats sit 0.15 m below the middle of it, so the cabin floor is at -0.15 and the roof at
+0.70 -- and the pilot's eye, `EYE_HEIGHT` above the floor they sit on, is at **+1.20**.
Half a metre above the roof. The cockpit frame is taller still.

Every crew position in this game has been sticking out of the top of its own fuselage,
invisibly, because the fuselage was hidden from the one person in a position to notice.
Glazing the hull would have achieved nothing: there is no window you can cut in a box your
head is already above.

So the cabin is a greenhouse DERIVED from the seats -- long enough to hold them all, tall
enough to clear a standing pilot, and reaching forward to the nose, because the front of the
cabin is the front of the aeroplane and the cone beyond it is the radome. Move `EYE_HEIGHT`,
or move a seat in the C++ shape table, and it follows.

### Three things the tests found that reading would not

**The greenhouse has to cut INTO the fuselage.** Sitting it on the roof left the Cessna's
pilot looking over a sill at chin height: its roof line is 20 cm below the eye, so there was
nothing to see through. The glazing now drops 45 cm below the eye and `HullSkin` takes the
fuselage sides away to meet it, which is why a real light aircraft's side windows run well
down into the flank.

**A windscreen with a wall behind it is not a window.** The nose bulkhead was solid across
the whole section, so the airliner's flight deck could see three of fifty-seven ways out --
its own fuselage nose was three metres in front of the glass. The front bulkhead is cut down
to the cabin floor now.

**No post at the front corner.** With one there, a pilot looking thirty degrees off the nose
was looking straight at it: the airliner's crew sit 3.4 m aft of the glass, and at thirty
degrees that lands exactly on the corner. The posts run one per opening, at the BACK of
each, which is also what a windscreen looks like -- the pillar you can see is beside your
shoulder, not in front of your face.

### And one the tests were wrong about

The first see-out sweep looked a little up and down as well as level, and every aeroplane
failed it -- because a cabin has a roof and a sill, and a pilot looking twelve degrees up
sees the roof, in this game and in every real one. A test a Cessna cannot pass is not
measuring the Cessna. It sweeps level now, which is what the horizon is, plus a separate
question about whether the ground is visible out of any side window.

### The airliner needed a nose before it could have a flight deck

Glazing it as a full-width box gave a cabin 5.2 m across with the crew within a metre of the
centreline: the side sill two metres from the pilot's shoulder, eight degrees of downward
view, and no ground visible from any window. The see-out checks said so and were right.

A real airliner's nose TAPERS, and that is the entire reason its flight deck is narrow
enough to see out of. So the cabin is as wide as the CREW rather than as wide as the hull --
the widest seat plus an elbow, capped at the beam -- and `HullSkin` cuts the fuselage into
sections along its length: the nose the crew sit in, a shoulder that steps out over two and
a half metres, and the body. The step between two sections is a face, or the shoulder is a
hole you can see the inside of the aeroplane through.

The airliner's flight deck is 1.94 m across in a 5.2 m fuselage, which is about right, and
the sill is now 42 cm from the pilot instead of two metres. An aeroplane whose crew already
fill its width -- the light one, the Cessna -- gets the full beam and no taper at all,
because the minimum is what the hull is, so the same rule does nothing to them.

### It arrives one kind at a time

`VehicleCatalogue.glazing` is keyed by KIND, not by body style. Keyed by style, the airliner
was glazed along with the light aeroplane before it had a nose to hang the glass on, and the
checks failed for a shape nobody had thought about yet.

So the light aeroplane, the Cessna and the airliner have windows; everything else is still a
box and is still hidden from inside, and `_show_body` reads the schedule to decide which.
A kind arrives when its shape has been thought about.

## THE AIRFRAME YOU ARE INSIDE IS HIDDEN, NOT FADED

A pilot sits within the hull, so from inside a solid fuselage is a wall between the eye and
the horizon. It used to be drawn at 18 per cent alpha, which reads well in a screenshot and
FLICKERS in a headset.

An airframe here is thirty-odd overlapping boxes. Alpha-blended geometry is sorted PER
OBJECT with no depth written between them, so which box is in front of which is decided
afresh each frame from the distance to each one's origin. Sitting inside the hull puts most
of them at nearly the same distance and several behind the eye, so the order is not merely
arbitrary, it CHANGES from frame to frame -- and in stereo the two eyes can settle on
different answers.

ZERO ALPHA DOES NOT FIX IT. A transparent surface at zero is still submitted, still sorted
and still blended; it just contributes nothing. `visible` is what takes the geometry out of
the frame, and it costs less than drawing it did.

`GHOST_ALPHA` is kept as a number rather than deleted, because it is the thing to turn back
up if a ghosted outline is ever wanted -- at anything above zero the old blended path
returns, flicker and all.

## A COCKPIT IS NOT ALWAYS THREE LEVERS

A control tower has no stick and no throttle. It has a radio, a screen and a button, and
every one of those is worth sitting at -- but everything that walks a cockpit had been
written against an aeroplane, where there are always three. Taking the tower threw

    Invalid call. Nonexistent function 'is_held' in base 'Nil'.

the moment the player touched the throttle axis, and there was a second fault hiding behind
it: the station was never CLAIMED at all, so nothing in the cabin could be touched.

"Have I already got these controls" was asked by comparing the station's stick with the one
being held. On an aeroplane that is a fine test. On a tower both sides are null, the test
said yes, and the claim was skipped every frame from the first. It asks about the CRAFT AND
SEAT now, and compares the controls as well so that a rebuilt station is still picked up.

The lesson generalises past the tower: `CockpitStation.controls()` has always returned a
null for anything a station does not have, and every caller has to mean it. The drawing loop
in the level was guarded in two places out of five.

## SHARPER IN THE HEADSET, AND FINDING THINGS IN IT

**More pixels where the eye is.** A runtime hands the engine an eye buffer sized for the
lens distortion it is about to apply, and that buffer is normally SMALLER than the panels
can show, so the image is upscaled on the way out and every hard edge -- which here is every
instrument marking and every aeroplane against the sky -- goes soft.
`render_target_size_multiplier` is the knob and it is 1.4, which is twice the pixels per
eye. It MUST be set before the interface is initialised, because it sizes the swapchain, so
it lives in `enter_vr` just before `initialize()` and cannot be changed while you are
wearing the headset.

**Foveation pays for it.** Twice the pixels is twice the work, so the outer field is
rendered coarsely and the middle -- where you are looking, and where the whole of a cockpit
is -- at full rate. `Viewport.vrs_mode = VRS_XR` is what does it. `PilotRig` also sets the
interface's `foveation_level` and `foveation_dynamic`, and Godot's OpenXR settings page (read
2026-09-14) says of both: "Compatibility renderer only, for Mobile and Forward+ renderer, set the
`vrs_mode` property on Viewport to `VRS_XR`." So on Mobile and on Forward+ alike those two lines have
never done anything, and the note that stood here -- that a level of zero left VRS nothing to apply --
was wrong. Whether VRS_XR foveates through Virtual Desktop has not been looked at in a headset.

**And multisampling, which was meant to be four times and was never on.** The line in
`project.godot` sat under `[rendering]` with `rendering/` in front of it, so Godot read a key
that does not exist; the viewport reported `msaa_3d 0` on 2026-09-12. It is now part of the
finish -- off on PLAIN, 4x on FINE, and a headset starts PLAIN -- see "THE SCENERY HAS TWO
FINISHES". The reason it matters is unchanged: every aircraft in this game is a hard
silhouette against a flat sky, and an unsampled edge on a hard silhouette CRAWLS as your head
moves. Post-process antialiasing cannot fix that, it blurs the crawl instead. What 4x costs in
a headset has not been measured.

### Spotting boxes, on D

An aeroplane four kilometres off is three pixels of grey on a grey sky, and finding one is
most of what flying with somebody else consists of. D puts a red wireframe box round
anything more than 500 m away.

Two things about it that are not decoration. The box holds an ANGLE rather than a size --
about a degree, growing with range like a gunsight reticle -- because a box drawn at the
aeroplane's real size is a box you cannot see either, which was the whole problem. And it is
twelve edges rather than a transparent cube, because a face however faint hides what it is
pointing at, and what it is pointing at is three pixels of aeroplane.

Toggled, not always on: a sky full of red boxes is a sky you cannot see either. Roll on the
desktop moved to the arrow keys to free the key; A still rolls left.

### Spotting size, on the iPad (lane/spotting, 2026-09-19)

Asked for on 2026-09-18: "a setting that allows me to falsely increase the size to the viewer only, so in the ipad i can
turn on "spotting size" and planes get progressively bigger as they get far away ... shrinking it back to normal size
when it's within 0.5km (this should be configurable where the normal limit is)". The D boxes point at a craft; this
makes the craft itself bigger. **The clipboard's SPOTTING tab** has OFF / LOW / MEDIUM / HIGH and NORMAL SIZE WITHIN
0.25 / 0.5 / 1 / 2 km. Under each row a sentence says what the choice does now, in numbers ("MEDIUM: a fighter 10 km away
is drawn 3.8x its size ..."). OFF by default, kept in `user://spotting.json` (`Spectacles.path`, the suites' own folder
in a suite), never on the wire. `--spotting=off|low|medium|high` and `--spotting-near=<m>` override the file for one run
and never write it.

**What it touches: the scale of another aircraft's drawn node, and nothing else.** `FlightLevel._draw_through_the_spectacles`
runs after every view is drawn and after contrails, wakes and spray have been laid from the true pose. It runs before
the D boxes, and scales each aeroplane, helicopter and tiltrotor about its own origin, the hull's middle. It skips the
craft the rig is in, and so everyone aboard. No rig means no magnification, so a watch level, the observer and every
shot probe draw true size. Collision is native and has no node, and aiming, radar (`_contacts_near`), locks and the lamp
all read the simulation's state, so none of them can see it. `Observer._chase` orthonormalises the pose it reads. **Not
boats, ships, ground vehicles or trains**: they stand on a surface, and one magnified about its middle sinks into it.

**The curve is a floor on the angle**, from the ATSB's mid-air report AR 2022-001 (2020, citing Morris 2005 and an NTSB
report of 1987). It gives 12 minutes of arc as a detection threshold and 24 to 36 in poor conditions. LOW, MEDIUM and
HIGH keep a craft's longest dimension (`Shape::span` or the hull's length) at least 12, 24 and 36 arcmin across, capped at
3, 5 and 8 times. The floor is met by a soft maximum `(1 + (d/onset)^3)^(1/3)`. Past the limit the scale climbs out on a
ramp `1 + 0.5 x^2/(1+x)`, x the distance past the limit over the limit. The scale is the least of the three. Each of them
rises no faster than distance, so **what a craft LOOKS (scale over distance) never shrinks as it closes**. That is what
hides the shrink back to true size. **Rejected first: a smoothstep fade** from the limit to twice it. With HIGH and a 2 km
limit it shrank a Cessna 0.3 per cent a metre at 3.3 km, which is 55 per cent a second looking smaller at 200 m/s closing
against 6 per cent a second growing. The suite's "never looks smaller" check was written for it and went red on it.

**Measured**, the F/A-18F, 18.5 m (`tests/spotting_shot.gd`, double editor, Mobile, day, PLAIN). **The headset is a
Quest 3 (user, 2026-09-19): 2064 x 2208 panel pixels an eye.** The pictures are drawn at the RENDER TARGET, 2890 x 3091 at
96 degrees (`RENDER_SCALE` 1.4 on the 2064 x 2208 eye), about 24.3 px a degree at the middle. **What the eye resolves is
the panel**, and a Quest 3's pancake lenses put about 25 of its pixels in a degree at the middle of the view (Meta's
figure) and about 17.3 averaged over 96 degrees. So each cell below is render px / panel px at the lens's middle (x 25/24.3)
/ panel px averaged over the field (x 17.3/24.3). The middle is the one that counts for spotting: a person turns their head
to put what they are looking for there.

| | 1 km | 2 km | 3 km | 5 km | 10 km |
|---|---|---|---|---|---|
| OFF | 25.7 / 26.5 / 18.4 | 12.9 / 13.3 / 9.2 | 8.6 / 8.9 / 6.2 | 5.1 / 5.3 / 3.6 | 2.6 / 2.7 / 1.9 |
| LOW | 25.8 / 26.6 / 18.5 (x1.00) | 13.1 / 13.5 / 9.4 | 9.1 / 9.4 / 6.5 | 6.3 / 6.5 / 4.5 | 5.1 / 5.3 / 3.6 (x1.98) |
| MEDIUM | 26.2 / 27.0 / 18.7 (x1.02) | 14.5 / 14.9 / 10.4 | 11.6 / 12.0 / 8.3 | 10.2 / 10.5 / 7.3 | 9.8 / 10.1 / 7.0 (x3.80) |
| HIGH | 27.2 / 28.0 / 19.5 (x1.06) | 17.4 / 17.9 / 12.4 | 15.5 / 16.0 / 11.1 | 14.8 / 15.3 / 10.6 | 14.6 / 15.1 / 10.4 (x5.68) |

The board's words ("about 10 headset pixels") are panel pixels at the lens's middle, `Spectacles.ARCMIN_A_PIXEL`.

**The nav lights and beacon are not magnified in size.** They and the lamp's glare size themselves in view space through
`inverse(mat3(MODELVIEW_MATRIX))`, so a scaled parent spreads them with the airframe and leaves every dot at its own angle.
By day at 10 km, OFF, those dots are most of what shows. **Neither are contrails**, which is why the pass comes after them:
a trail laid from a magnified wingtip would still be that wide when the craft came close.

**The distance LOD reads the drawn size, and it turned out to barely matter.** `AircraftVisualLod` hides parts under
2.5 m past 900 m and under 5 m past 2.4 km, and the airframes' own detail parts go at 450 to 1800 m, all by the camera's
TRUE distance. So while a craft is magnified, each part's visibility range is stretched by the same factor, and a part is
hidden when it LOOKS as small as the LOD meant (team-lead, 2026-09-19). The ranges are rewritten only when the scale moves
a tenth (`Spectacles.RESTRETCH`), about 23 craft in 240 frames at 64 fighters, and all are put back when the spectacles come
off. Its cost was inside the load's spread (A/B below). **What it changed on screen, measured: 0 pixels round a fighter
at 1 to 10 km, and at most 3 round the tanker.** The fighter's only LOD parts are its gear, doors, hook and fittings at
600 m, which stay hidden until 3.4 km even stretched 5.7x; the tanker's 5 m parts come back out to 6.5 km at 2.69x, and are
2 to 3 px when they do (`cockpit-spotting-10-tanker-lod.png`). **I first blamed the LOD for a magnified fighter "coming
apart" in the first HIGH reel, and that was wrong**: the fighter was head-on, and what went missing were its wings,
thin and pale and under a pixel thick (see "Found and NOT fixed").

**What it costs**: 174 to 177 us a frame at 64 fighters (151 views) on a quiet machine, 2.9 per cent of the
`vehicles_draw` lap it follows, headless, debug editor. It read 366 to 677 us (5 to 7.3 per cent) while other lanes ran,
with and without the LOD stretch alike (A/B, 2026-09-19). Asking the view for `global_position` instead of
`transform.origin` had cost a third of it. With the setting OFF the pass is one branch.

**How it was proved.** `tests/spotting.gd` holds the curve, sweeping every metre to 25 km: exactly 1 when off and inside
the limit, never falling, never more than 0.002 in a metre, never looking smaller as a craft closes, and the floor and cap
at 1, 3, 5, 10 and 20 km. It checks five fighters in the real level at the curve's scale, and every craft back to 1 the
frame after OFF. It holds your craft and a crewmate the server seated at 1, even with the pass handed an eye 8 km off. With
the simulation held still, turning it on changes scale and nothing else: every simulation transform is unit scale, and
positions, the eye and the craft's contacts are unchanged. The LOD ranges are stretched by the scale and put back. The
SPOTTING tab is pressed with the beam and trigger, and a fresh rig (a restart) reads the setting back. The cost is under
a tenth of drawing. `tests/spotting_peers.gd` runs a host on HIGH (up to 8x) and a joiner on OFF over a real socket, and
the joiner draws every craft at 1.000. Mutants, each alone and reverted: a step at the limit (`min(wanted, cap)` with no
ramp) gives "steepest 1.58 a metre" and "looks smaller at 24 metres"; the own-craft guard removed gives "x8.0000"; the
scale put into `Sim.vehicle_transform` fails six checks, among them "unit false"; and the slow craft's lift taken out
fails "parked wheels moved 2.058407 m".

**Found and NOT fixed.** A head-on fighter at 4 km on HIGH is fuselage and intakes with the wings sub-pixel and pale
against a pale sky: magnification makes it longer, not thicker, where it is under a pixel. The director camera's second
window and any other camera in the rig's world see the same scaled nodes; per-camera scaling would need a second set of
nodes.

**A slow craft stands on its wheels.** Under `Spectacles.SLOW` (15 m/s) by its replicated velocity, a magnified craft is
scaled about the bottom of its hull, where the simulation rests it (`extents.y` below its middle), so a parked, taxiing or
hovering one stands on the runway, the deck or its skids rather than sinking by what the scale adds below its middle.
Nothing asks where the ground is, which would be a query a frame per craft. Taking off far away it moves from one pivot to
the other by `(scale - 1) * extents.y`, about 2 m at 5 km on HIGH, under a pixel. `tests/spotting.gd` holds both
pivots on a fighter parked on a 4-degree slope (`a_slow_craft_is_scaled_about_its_wheels_and_a_flying_one_about_its_middle`).

### Changing scene with a headset on

Coming out of the main menu into the world filled the log with

    framebuffer_create_multipass: Layers of our texture doesn't match view count

and every draw call after it failed on a null framebuffer -- a thousand errors a second and
no picture. THREE things were toggling stereo in one frame: the desk's rig cleared `use_xr`
on its way out, the world's rig entered desktop mode, and then it entered VR. Rebuilding an
XR render target that many times in a frame does not survive it.

An arriving rig now goes straight into whichever mode it wants without passing through the
other, and a departing one leaves the viewport exactly as it found it -- the viewport
belongs to the window, not to the rig, and the next thing to want it is almost always
another rig that wants it in this state. Booting straight into the world was always one
transition, which is why this only ever appeared on the way out of the menu.

## ARRIVING AND LEAVING

The one thing every player does twice, and until now the one thing with no test at all.
Four things were wrong, none of which flying would have shown.

**A craft made for a player was never given back.** Everybody who joins is issued one,
because there is no state in which a player exists without something to sit in. Nothing ever
removed it. Join, press the seat button twice, quit: the pod you were given is still up
there flying straight and level, and so is the next player's, and the seat button walks all
of them. `sweep_empty_issues` runs once a tick and retires anything in `issued_` that now
holds nobody.

Only what was ISSUED. The hundred and sixty machines the world starts with are scenery:
borrowing a parked Cessna and then quitting must not take the Cessna away, so "what were
they flying" is the wrong question and "what was made for them" is the right one.

**A named CRAFT request is also an issuance path now.** `switch_kind` still takes an
existing free seat first. When none exists, it records the press and `answer_the_issues`
runs after simulation jobs, because entity creation cannot happen inside a job. A flight
level registers fixed places with `Sim.add_issue_place`; a room deliberately registers
none. The native clear radius is the larger of the craft's drawn half-span and hull extents,
doubled plus four metres. The new craft enters `issued_`, so the same empty-craft sweep
above retires it. Missing or occupied places answer `kind_no_issue_place`, and the board
says the refusal immediately rather than waiting out its patience. `../../ashiato-gd/addon/tests/issue.gd` is the
native lifecycle gate; `tests/craft_peers.gd` drives the real page over ENet.

**A craft could be removed out from under its crew.** The host tidies up after a departing
player by removing the vehicle it made for them -- which by then is very often a vehicle
somebody else is sitting in, because the seat buttons walk the whole world. `despawn_vehicle`
now refuses while anyone is aboard, and the sweep picks the craft up later when its last
seat empties. Refusing costs nothing: an occupied craft is by definition one somebody wants.

**A pilot with no seat was stuck for the session.** `next_seat`, `switch_vehicle` and
`switch_kind` all began by looking up where the player was sitting and returning if they
were nowhere, so a player dropped into nowhere by the bug above pressed every control they
had and nothing happened, for ever. Two of the three now treat "adrift" as a state with a
way out: entity 0 is nothing, so it matches no craft to skip and sorts before every
candidate, and the player gets the first free seat in the world. `next_seat` legitimately
still does nothing -- there is no craft to move about inside.

**An autopilot outlived the vehicle it was flying.** `retire` erases the `ai_` entry now,
and clears the leader of anybody who was formating on the retired machine so they go back to
their own waypoints instead of holding station on a ghost.

**`seat_client(client, vehicle, seat)`** is new and is the "join my friend" call. The seat
buttons walk the world in entity order, which is the right control for a player browsing and
no way at all to ask for a particular aeroplane. It refuses rather than shuffles: a taken
seat, a craft that has gone, or a seat number this kind does not have all mean the caller
asked for something that is not there, and putting the player somewhere else instead would
be a worse answer than no.

**The builder uses `seat_client_parked`, not `seat_client`.** The ordinary exact-seat call
deliberately launches a grounded craft when its pilot seat becomes occupied. A workshop craft must
remain at model origin while its stations are edited, so the narrow parked call performs the same
validated exact-seat assignment without the launch transition. Also keep the returned server entity
handle in `BuilderSession.host_entity`: server and client worlds use different handles. The drawn
`entity` is discovered from replicated client state and must never be sent as the authority token.

**Windowed probes that must not touch OpenXR pass `--desktop-only` after the bare `--`.** Engine
`--xr-mode off` disables XR rendering, but it does not prevent `PilotRig` from explicitly calling
`OpenXR.initialize()`. `PilotRig.xr_available()` honors the application flag before asking OpenXR;
`tests/builder_shot.gd` is the reference command and still includes `--xr-mode off` as well.

**A spare aeroplane gliding into a field is not a bug.**
`every_craft_is_drawn_flying_forwards` only looks at craft above 60 m now. The unmanned airliners settle within a minute
of the world starting -- that is deliberate, and `launch_if_grounded` is what undoes it when
somebody finally climbs in -- and a wreck lying in a field pointing whichever way it stopped
is not a question about how the model is drawn.

## THE AIRLINER WAS CRUISING AT ITS STALL SPEED

It porpoised and then fell out of the sky, and the shape of the fault was a pitch
oscillation, so it looked like a controller that wanted retuning. It was not.

The wing was sized to carry nine tonnes at 70 m/s and the autopilot flew it at 72. THREE
PER CENT of margin, on an aeroplane that has to turn, climb and hold a formation slot -- a
25-degree turn alone wants ten. So it sank, the altitude loop pulled, pulling cost speed,
and round it went: 1656 m of altitude in one minute, ending at 36 m/s against a stall of 70.

THE POWER WAS NEVER SHORT. Sixty kilonewtons against 21 kN of drag at cruise is two thirds
of its own weight in thrust, more than any real airliner has. The wing went from 330 to 640,
which carries the same nine tonnes at 50 m/s, and the cruise floor over the stall went from
1.15x to 1.30x. It now holds 520 m to the metre.

The tiltrotor had the same fault worse and nobody had noticed: eighteen tonnes on a wing
that stalls at 72 m/s, against a cruise capped at 70, so the aeroplane half of it was NEVER
flying. It hung off its rotors at 54 m/s and hunted. 900 puts its stall at 57, which is what
the real one does.

### And a rate loop with no rate term hunts, again

The same lesson as the formation crosstrack, found this time by the tiltrotor. The climb
loop drove the stick from a climb-rate ERROR with nothing watching how fast that error was
closing. A light aeroplane is slow enough to be its own damping; eighteen tonnes with
900 kN m of control authority answers instantly, overshoots, and settles into a one-hertz
buzz -- 66 changes of climb direction in a minute, inside ONE METRE of altitude. Invisible
on an instrument, and exactly the sort of thing you feel in a headset. `climb_inner` has a
derivative on the measured climb rate now, so what it damps is vertical acceleration and it
does nothing at all to an aeroplane already flying smoothly.

### tests/trim.gd, and `--level=fly`

AN AVERAGE CANNOT SEE AN OSCILLATION -- a machine porpoising through its bug by a hundred
metres has exactly the right mean altitude -- so the suite measures the PEAK-TO-PEAK swing
and the number of times the climb changes sign. Every other suite watches a hundred and
forty machines do something; this one watches ONE do nothing, in an empty sky, which turns
out to be the harder test.

`Godot --path cockpit -- --level=fly --kind=airliner` is the same thing to look at: one
aeroplane, nobody in it, a chase camera, and a board with the height, the climb, the speed
against the stall, the margin, and the same two trim numbers the suite checks.

**Trim cannot see a rotorcraft's attitude handling.** A helicopter with nowhere to go hovers, and a hover asks almost
nothing of pitch, roll or yaw. Trim's Chinook and light helicopter read the same to the metre with the Chinook's old
handling, with eleven times its control authority and with twenty times: the Chinook sank 14 m between 220 and 234 m
and its climb changed sign once each time (2026-09-15, cockpit-chinook, applied with `Sim.set_handling`). How fast a
rotorcraft answers its stick is held by `tests/rotor_rates.gd`. A green trim is not a handling check.

### One number in two languages is one number too many

`Terrain.cruise_for` had its own table of cruise speeds and the simulation derived its own,
so an aeroplane was LAUNCHED at 72 and then FLOWN at 80 by its own autopilot. It asks now,
and the constants that are left are a fallback for a caller with no session. This is the
same rule the drawn geometry already follows with `kind_geometry`: a number that must agree
with another number is computed from it, not typed in beside it.

## THE CHAIR UNDER THE PILOT: `PilotSeat`

`objects/seats/pilot_seat.gd` draws the seat itself. It is one parametrised, faceted chair with a preset per kind of
seat: `aces2_f16` (30 degrees), `aces2` (13), `mk14` (14), `heli_armoured` (10), `light` (12) and `transport` (12). Each
seat is one mesh and one draw call, with 240 to 376 triangles against a `BUDGET` of 400, and its parts are named as
triangle ranges in the `parts` metadata. **No preset has armrests.** The user asked for none, and
`tests/pilot_seat.gd` fails any level face at elbow height beside the torso.

**THE CHAIR IS FITTED TO THE PLAYER, NEVER THE REVERSE.** It is built in the seat anchor's frame and solved from the
eye at `CockpitStation.EYE_HEIGHT`. The back's face is a plane `head_gap` behind the eye, leaning back by `recline`.
The pan's rear edge is where that plane comes down to `pan_height`. Nothing about the eye, the controls or the body
envelope moves to suit a chair, and `tests/pilot_seat.gd` fires `tests/seat_room.gd`'s OWN rays, with its own
clearances, at every preset.

**THE F-16'S 30 DEGREES AND THE GAME'S UPRIGHT BODY DO NOT SHARE A HIP (2026-09-18).** With the head against the
headbox (a 0.20 m gap), a 30-degree back puts the hips 0.23 m ahead of the eye line. The pan then covers the pedals at
z -0.46, and at a 0.34 m gap the back cushion stood 0.02 m in front of `seat_room`'s knee ray from z 0. `aces2_f16`
therefore keeps a 0.45 m gap. Its hips land at z -0.05, where an upright body's are, and the head rides 0.25 m off
the headbox. Real F-16 pilots fly that way, head forward and off the rest. If that ever looks wrong, the fix is to tilt
the body envelope and move the F-16's pedals forward. That is a crew-fit change, not a chair change.

The reference pictures come from `tests/pilot_seat_shot.tscn` (windowed): every preset from the side and
three-quarters on, with a head and the rig's eye drawn in each seat.

**A CRAFT NAMES ITS CHAIR IN ITS CATALOGUE ENTRY (step 2, 2026-09-18).** An entry takes `"chair"` (one preset for every
seat) or `"chairs"` (a list by seat index), plus `"chair_headroom"`. `VehicleView._finish_setup` puts a `PilotSeat`
called `Chair` on each seat anchor. It is not added to `_body`, so a crew aboard does not ghost it. Fitted so far: the
F-16 (`aces2_f16`), the F-14D (`mk14` in both seats) and the F/A-18F (`mk14` in both seats). The F/A-18F's airframe no
longer draws its two grey "EjectionSeats" blocks. `tests/shell_room.gd` leaves a `Chair` out of the machine's solids,
because a station floor corner inside a chair is not thereby inside the aeroplane.

**THE HEADROOM IS THE CRAFT'S, AND IT IS SHORT.** The rig puts a fighter pilot's eye only 0.13 to 0.25 m under the
drawn canopy, and a real headbox stands well above a helmet. The first fitting put the F-16's headbox top 0.08 m out
through the glass, and the F-14's back seat and the F/A-18's were out by 0.05 to 0.12 m. `"chair_headroom"` (F-16
1.43, F-14 1.55, F/A-18 1.48 m over the anchor) cuts the headbox, the rails and the drogue down under it. On the Mk 14
the drogue container moves from the top of the headbox to its back when it no longer fits on top.

**THE JETS' PANS ARE SHORT BECAUSE OF THE PEDALS.** The eye's line to the rudder pedals (z -0.46 on the floor) crosses
pan height at about z -0.32. At 0.40 and 0.42 m deep, the pans hid every pedal part. The Mk 14's is now 0.29 and the
F-16's 0.27. `tests/pilot_seat.gd` holds every fitted chair to two checks, both measured off drawn triangles:
**under the skin** (from every vertex of the chair, a ray up, down, to port and to starboard meets the craft within
2.2 m) and **hiding nothing** (the chair crosses no line from the eye to anything the station draws, and none of the
level or chin sight lines). `tests/chair_craft_shot.tscn` photographs the three jets: cut away, from outside, and from
the eye looking down.

## LOOKING AT A SEAT FROM THE ONE VIEWPOINT THAT MATTERS

```powershell
..\_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --path . res://tests/station_shot.tscn -- --kind=gunship --seat=1 --pitch=-38
```

`tests/station_shot.tscn` puts one station in an empty lit room, a camera where the
occupant's eyes are, and saves a PNG. `--pitch`, `--yaw` and `--fov` aim it; `--pulled`
draws the gun firing. **Not headless** -- headless has no rendering device and the file
comes back a black rectangle that looks like a broken cockpit.

It also prints where every control is and, for each one, WHICH WAY its grab point lies from
its own origin, because that is the thing that goes wrong and the thing no assertion had
been catching.

**It exists because a control can be in exactly the right place and still be wrong.** The
gunner's trigger was a red blade on the far face of a grey block, three centimetres beyond
it. Every check about where the trigger IS passed. From the only seat that will ever reach
for it, the red was behind the grey and there was nothing on the console but a small dark
box -- and the grab point was out there with the blade, so taking hold of it meant reaching
through the body of the control for a part that had never been visible.

The lesson generalises past triggers. A cockpit is judged from one position, and a test
suite that only ever asks where things ARE cannot tell you what they LOOK LIKE from it. Ask
both.

**And ask in the right frame.** The first version of the regression check subtracted world
positions and reported every gunship gun position as 0.000 m wrong. Those seats are yawed
ninety degrees to face the guns down the left side, so the gunner's "toward me" is the
world's X and the Z it was measuring was float noise. `to_local` on the control, always.

### AND THE WHOLE AIRCRAFT ROUND IT, WHEN THE SEAT'S MAIN OBJECT IS THE VEHICLE'S

`--craft` builds the aircraft round the seat instead of the station on its own, with the
airframe taken away exactly as it is for anybody sitting inside one. A station by itself is
the right picture for a cockpit, where everything in front of the crew belongs to the seat --
and the wrong one for a door gunner, whose gun is drawn by the hull because everybody outside
can see it too. Without it that seat photographs as a trigger floating in mid-air.

## A COCKPIT ON A BENCH

`tests/bench.tscn` loads ONE craft, no world, and writes everything it is doing on a board.

```powershell
..\_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --path . res://tests/bench.tscn -- --kind=osprey --mode=seat
..\_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe --path . res://tests/bench.tscn -- --kind=chinook --mode=crew
```

`--seat=N` picks WHICH seat, because a craft's seats are not the same job: the pilot flies
it, a gunner aims something, and the one on a Chinook's ramp faces backwards.

SEAT is one station with the physics running underneath, for laying a cockpit out and
watching what it sends. CREW is every seat and every station with the craft sitting on the
ground, for putting several people in one aircraft and checking that what each of them does
appears on everybody else's panel.

Neither loads `sky.tscn`, which is the point: a hundred and forty machines, four hundred
boxes of terrain and a railway stand between you and the thing you are looking at, and none
of them are needed to find out whether the flap lever is fitted.

The board shows both halves, because the second has no other way of being checked: what this
seat is ASKING for, the LINKAGE every seat sees, and every channel on the COMMAND BUS with
whether it is physics or internal.

Two traps it walked into, both already written down elsewhere in this file and both worth
the reminder. `Net.play_solo()` only announces a session -- the LEVEL is what listens and
builds the world, so a bench without a level has to call `Sim.start()` itself. And a
GDScript lambda captures by VALUE, so a `waiting` flag cleared inside a signal callback is
cleared on a copy and the loop outside waits for ever.

## SEEING A WHOLE CRAFT IN THE EDITOR

`objects/vehicles/craft_plane.tscn` and nine more like it. Open one and the hull, the wing,
the rotors, the guns and every seat's cockpit are there at the sizes the SIMULATION says.

**Without a second copy of the shape table**, which is the only reason this is worth having.
`kind_geometry` reads a table a `CockpitWorld` builds in its CONSTRUCTOR -- no session, no
network, no tick -- so `Sim.geometry_of` makes a throwaway world and asks the same question
the game asks. A constant here and a matching constant in the C++ agree until one of them
changes, and then the thing you can see is a different size from the thing you collide with.

A craft scene is worth looking at for the things a running game hides: whether a seat is
inside its own fuselage, whether the ramp seat clears the ramp, whether a gun is over the
gunner who aims it. None of those need physics and all of them need to be seen.
`every_craft_can_be_opened_in_the_editor` builds all ten headless and checks each gets a
hull, a cockpit and one station per seat.

**And every kind as the game draws it, in one run:** `tests/craft_gallery_shot.gd` (windowed; `docs.gd` PROBES) brings up
the level the game starts on, lets it seed its own fleet, and saves one picture of the first craft of each `Sim.Kind` it
placed, `cockpit-craft-<kind>.png`, into `<repo>/screenshots/<today>/` unless `--out=` says otherwise. A kind the level does
not place prints `SKIPPED <kind>: not in the level`. Each craft is fitted by its drawn meshes' vertices put into its own
frame, then by that box's projected corners: fitted by a bounding sphere, the carrier filled a third of the picture.

    godot --xr-mode off --path cockpit --resolution 1600x900 res://tests/craft_gallery_shot.tscn -- --level=watch --finish=plain

`craft_gallery.bat` beside this file (a double-click on Windows, the double editor or stock) and `craft_gallery.sh` (Linux,
the stock editor or `$GODOT`) are that command line; anything after them is the probe's own flags.

## SEEING A COCKPIT IN THE EDITOR

The controls are `@tool`, and `VehicleControl._ready` builds the meshes when
`Engine.is_editor_hint()`. Open `objects/seats/seat_plane.tscn` and the levers, the
stick and the instruments are all there in the right places, and dragging one moves it.

The editor gets the GEOMETRY and nothing else: `setup` also has to say which seat this is,
which is not a question the editor can answer. A cockpit you cannot see is a cockpit you
have to run the game to lay out.

## A FLIGHT TRACE: `--trace-craft=`, ONE `.jsonl` A CRAFT, AND A READER THAT COUNTS THE SAWING

The user, 2026-09-19: "write a 'trace location' flag into a craft so i can have it optionally (at spawn) write out it's
location during a run as json ... include it's inputs so we can introspect those, most ai pilots are still not using a PID
for their controls, so they constantly oscillate."

    Godot ... -- --trace-craft=cessna --trace-out=C:/temp/traces --trace-hz=60
    python cockpit/tools/read_trace.py C:/temp/traces/cessna_<entity>.jsonl [--chart out.png]

- `CraftTrace` (`world/craft_trace.gd`) is a node `Sim.start` adds ONLY when the flag is given, so off there is no node, no
  tick and no allocation. `--trace-craft=` is a kind, an entity, `player`, `ai` or `all`, judged as each craft appears.
  The field list, the rate rules and the refusals are in its doc block; the header line of every file repeats the fields.
- JSON lines, so a killed run still parses and a long one streams. 60 Hz by default against a 120 Hz tick; the header says
  the rate written. Written from `Sim.server` only: a client replays ticks and would hold one instant twice.
- `flight_controls(entity)` (C++) is the autopilot's last demand -- pitch, roll, rudder, brake, throttle -- kept in the
  `AiPilot` record beside `last_throttle`, because `controls` was a local inside `drive_vehicle` and nothing outside could
  see the input that oscillates. A library without it writes no `stick` and says `"stick": "absent"` in the header.
- **A crowd is capped at 16 files** (`CraftTrace.FILES_MOST`): past it a matching craft is counted and not written, and
  `trace_summary.json` beside the files says matched, written and the cap. Priced by `tests/trace_cost.gd`: ten traced craft
  cost the recorder 275 us a sample, 1.6 % of a tick; off, nothing exists.
- `tools/read_trace.py` prints min, max, mean and SIGN CHANGES A SECOND about the channel's own mean (crossings must clear
  5 % of the channel's range, so noise on the mean is not sawing). Gate: `tests/trace_log.gd` reads the file back against
  `vehicle_states`; eight mutants, each red.

### The trace level: a recorded flight replayed on a small plain map

    Godot --path cockpit -- --world=trace --trace-in=C:/temp/traces/cessna_<entity>.jsonl [--trace-at=12] [--trace-rate=2] [--trace-play=0]

The user, 2026-09-19: "we should have a special level that can read this input back in to a single craft in a small map and
redraw it's flight." `levels/trace/` (`TraceLevel`, `TracePanel`) is a level of the ordinary kind (a folder, a `level.json`, the
alpine ground at its smallest legal size, 30 m peaks, no sea, no fleet) that `Sky` builds when `Net.level` is `trace`; it is watched,
not flown, so `Sky._nobody_is_playing` says yes for it and the level supplies its own camera.

- **The craft is a puppet.** Each frame it interpolates the two samples round the playback clock and writes the pose into
  `Sim.current` under entity `TraceLevel.PUPPET` (0x7E000001, which no simulated craft can have), before `Sky` draws
  (`process_priority` -100). Nothing simulates it, so the flight shown is the flight that was flown. Not posed from the file: the
  drawn surfaces, gear and flaps, which the drawing reads off a craft's bus.
- **The path** is one decimated list (6,000 points at most) drawn as a line strip and a translucent curtain down to the ground,
  with a cross and a drop-line every 1, 2, 5, 10, 30 or 60 s (the least giving at most 120). The curtain is why it reads from the
  air; a one-pixel line does not. `lint`'s see-through-material rule lists the file with that reason.
- **The inputs** are the strip along the bottom (eight seconds behind now, two ahead, every sample, one lane a channel), the
  stick as a dot in a box, rudder and throttle bars and the levers as words. A file without the stick shows attitude and the
  lever and says so on the strip.
- **Keys:** SPACE, `,` `.`, LEFT/RIGHT (SHIFT 30 s), HOME/END, 0-9 for a tenth of the flight, a click on the timeline, C for the free
  camera, right drag, wheel. `tests/trace_replay.gd` presses them through the viewport.
- **A file that will not read is refused in words** (`TraceLevel.read`): none named, missing, not a trace, unknown kind, fewer than
  two samples, no position, time going backward, each with its line. The level still comes up, with the message on screen. A last
  line cut short (a killed run) is dropped and said. `JSON.parse_string` is not used: it prints an engine ERROR on a bad line and
  the harness fails a run on any.
- Two traps met building it: the new `class_name`s need the editor's `--import` before a run sees them (a run without it
  hangs on a parse error, as always), and `tests/lint.gd` compiles each script with its `class_name` struck out, so a typed
  assignment of `self` to its own class does not compile there (`panel.set(&"level", self)`). And `sites_within: 100` on the
  generated ground leaves the world with no runway, and `Terrain.spawns()` indexes `runways()[0]`.

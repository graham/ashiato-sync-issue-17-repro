# The fleet against the craft standard

**Every craft scored against the four things `craft_standard.md` asks of it -- looks good, flies well, fits its crew,
does its job -- with the evidence for each score, and a ranked list of what to fix first.** Written by `lane/review` on
2026-09-17, at main `c388b786` plus this lane's two new suites. **These verdicts outrank the wave order in
`craft_standard.md`** (the standard says so); where I would reorder the waves, the backlog below says how and why.

Two of the four criteria had never been measured for any craft. This lane measured them:

- **`tests/handling.gd`** flies, drives or sails every pilotable kind through the frame a seated player's rig sends
  (`set_pilot_input`: stick, pedals, lever, a TILT command for the Osprey), with one set of plain proportional loops
  for every craft. Ten seconds for the fleet. A report, not a gate.
- **`tests/seat_room.gd`** hangs a VR player envelope off every seat of every craft scene and casts rays from it at
  the drawn triangles. Five seconds. A report, not a gate. `tests/seat_room_shot.tscn` draws the same envelope so a
  tight seat can be seen.

The other two criteria reuse tonight's evidence and nothing is redone: `craft_model_audit.md` and its suite (looks),
`joined_parts` (one object), `named_parts` (parts named), `shell_room` (crew inside the drawing), `fit` (every control
within a seated arm), and each craft's own job suite. All of them were re-run on this lane's base and all passed; their
known-lists and exemptions are quoted where they matter.

## How to read the scores

Each criterion is scored **1 to 5**, where **5 is the gold standard** (the Cessna's model, the F/A-18's model, the
carrier) and **1 is broken or absent**. The number is a judgement; the evidence beside it is the measurement, and the
measurement is what to argue with.

### The player envelope (`seat_room`)

In the seat anchor's frame. The game's own numbers are used where it has them (`CockpitStation.EYE_HEIGHT` 1.35 m over
the anchor, `NECK` 0.22, `SHOULDER_HALF` 0.19), because the rig puts the player THERE whatever a tape measure says. The
rest are ANSUR II (US Army anthropometric survey, 2012) 95th-percentile men, rounded, plus the room a head in a headset
moves through seated.

| clearance | from | need | where the number comes from |
|---|---|--:|---|
| head up | the eye, up | 0.25 m | crown 0.13 over the eye (sitting height 0.97 less sitting eye height 0.85) + 0.02 strap + 0.10 of head movement |
| head side | the eye, either side | 0.20 m | half a headset (0.19 wide) + 0.10 of a head turning to look out |
| head fore | the eye, ahead | 0.30 m | a headset's depth (0.08) + a lean to read an instrument (0.20) |
| shoulders | the shoulder line, either side | 0.30 m | bideltoid breadth 0.53 halved, + 0.035 of elbow |
| knees | 0.55 m over the anchor, ahead | 0.55 m | knee height seated ~0.60; buttock-knee 0.66 less the hips ~0.10 behind the eye line |
| neighbour | shoulder middle to the next seat's | 0.53 m | one bideltoid breadth |

Each clearance is the least of five parallel rays (the point and four offset 0.08 m across it), because a head is not a
point: single rays went straight out of the airliner's side windows. **Reach is not here**: `fit` already holds every
grip to `CockpitStation.EASY_REACH` from the same shoulders, and passes (319 controls, worst 0.58 m) -- **but `fit`
walks only 20 craft and never visits the fighter, the Mercury, the UH-60 or the brig**, so for those four "within reach"
is unmeasured.

### The robot pilot (`handling`)

Aeroplanes: parked, full power, rotate at 1.2 x the book stall, climb at 10 degrees nose-up to 300 m, level at full
power for 60 s, a full-stick roll, a 45-degree level turn **twice** (once holding the nose on the horizon, once pulled
with rudder fed in, see below), a power-off slow-down to the stall, then an approach and landing. Helicopters: full
collective, a hover then five seconds hands-off, 15 degrees nose-down for speed, a 30-degree bank with the feet still
and then with half pedal, a vertical landing. The Osprey: up on the nacelles, nacelles forward, the aeroplane legs, back
up and down vertically. Ground: flat out, 0-15 m/s, a full-lock circle, a stop. Ships: full ahead, full rudder.

**One harness gotcha, now written into the suite:** a frame throttle of 0 does not close the lever. The server reads
anything at or under 0.001 as "the hand is off it" and leaves the lever where it was (`cockpit_world.cpp`, "A
CONTINUOUS THROTTLE INPUT MOVES THE LEVER"), so the robot idles at 0.002. Before that, no aeroplane slowed for its stall
and every helicopter climbed 900 m on a collective set to hold.

## The verdicts

Worst first within each group. "In progress" craft are scored as they are now, and named.

### Aircraft

| craft | looks | flies | fits | job | verdict |
|---|:-:|:-:|:-:|:-:|---|
| **cessna** | 5 | 4 | **1** | 5 | **Flies well; nobody fits in it as seated, and the cabin is nearly big enough.** See below. |
| **tanker** | 4 | 4 | **1** | 4 | Protected. Flies honestly but slowly; **both pilots' heads are in the roof and against the bow skin**. |
| **uh60** | 2 | 3 | **1** | 4 | In progress (`lane/rotors`). Pilots' heads in the roof, knees in their own drawn seats. |
| **gunship** | 4 | 3 | 2 | 4 | The pilot sits in the nose cone ahead of the flight deck. Turns very wide. |
| **glider** | 4 | 3 | 2 | 4 | Heads above the canopy, rear shoulders 0.04 m from it; circles far too wide to thermal. |
| **plane** | 2 | **2** | 4 | ? | **A rocket**: thrust-to-weight 5.75. The fastest aeroplane in the game. Slab model. |
| **heli** | **1** | 4 | 2 | ? | In progress. The worst-looking craft; the nimblest helicopter. No roof over anybody. |
| **chinook** | 2 | 3 | 5 | ? | In progress. Roomy; turns sluggishly even on the pedals. |
| **airliner** | 2 | 3 | 4 | ? | Slab, windows past the tail. Flies and lands; a bank alone barely turns it. |
| **mercury** | 2 | 3 | 4 | 4 | Envelope right, body a slab. Rolls at 22 deg/s and bounced on landing. |
| **fighter** | 5 | 3 | 4 | 4 | Gold model; **tops out at 201 kt**, slower than the light twin and the Hawkeye. Its hook catches nothing yet. |
| **hawkeye** | 5 | 3 | 5 | ? | The look reference. Heavy and slow to roll (32 deg/s); bounced 5 m on landing. |
| **osprey** | 3 | **4** | 4 | 4 | **The best-flying aircraft in the game after the Cessna**: converts both ways and lands clean. |
| **F-14 Tomcat** | -- | -- | -- | -- | Not on main yet (`lane/tomcat`). Both suites pick it up with no edit once its kind and scene land. |
| **F-16 Falcon** | -- | -- | -- | -- | Not on main yet (`lane/falcon`). The same. |

### Ground, rail and structures

| craft | looks | drives | fits | job | verdict |
|---|:-:|:-:|:-:|:-:|---|
| **pod** | **1** | 4 | **1** | ? | No hull at all; knees 0.07 m from the pressure hull it does not draw. Drives nimbly. |
| **car** | **1** | 4 | 2 | ? | Box on box; the windscreen is at knee height (0.24 m). No roof. Drives well. |
| **segway** | n/a | 4 | n/a | 4 | Invisible by design ("a sphere at their feet", 2026-09-15). Walks at 3.2 m/s and turns on the spot. |
| **tank** | 4 | 4 | 3 | 4 | Done tonight. The commander's shoulders meet the Barrel 0.11 m away on both sides. |
| **train** | 2 | n/a | 5 | 4 | In progress (`lane/train`). Roomy cab. Not driven here: it needs a rail network. |
| **tower** | 3 | n/a | 5 | ? | A building. Roomy cab. `airbase_taxi` reaches every seat; not re-run by this lane. |

### Ships

| craft | looks | sails | fits | job | verdict |
|---|:-:|:-:|:-:|:-:|---|
| **boat** | 3 | 5 | 2 | ? | The nimblest thing afloat: 49 kt, a 67 m circle, and leans 13 degrees into it (lane/boats, 2026-09-18; was 35 kt, 60 m, level). The helm's knees are 0.13 m from the wheelhouse. |
| **submarine** | 3 | 4 | 5 | ? | 20 kt; heels 13 degrees in a full-rudder turn. |
| **battleship** | 4 | 3 | 5 | 4 | Turned tighter than the patrol boat (171 m against 274 m) until lane/boats gave the patrol boat 102 m. Same 30 kt as the carrier. |
| **gunboat** | 4 | 5 | 5 | 4 | 47 kt, a 102 m circle, 9 degrees of lean into it (lane/boats, 2026-09-18; was 43 kt and 274 m). |
| **pirate** | 4 | n/a | 5 | 4 | **Not pilotable, by design**: `spawn_pilot` refuses it. `sailing` measures how the AI sails it. |
| **carrier** | 5 | 4 | 5 | 3 | Protected. 30 kt, 477 m circle. **Its catapults and wires are drawn, not simulated**: nothing launches or recovers. |

`?` under "job" means no suite holds that craft to a job of its own: it flies, drives or sails (above), and nothing
else is claimed for it.

## The evidence, craft by craft

### Cessna -- the user's own question

**As seated, nobody fits. At the eyes the airframe was drawn round, two people nearly do.**

- **At the seat poses** (`seat_room`), each pilot has 0.04 m over the eye (needs 0.25), 0.03 m to the door (needs
  0.20), 0.02 m from the outboard shoulder to the glass (needs 0.30) and 0.12 m to the windscreen (needs 0.30). The
  picture shows why: the head envelope comes up **through the top of the wing root**, and the station's floor hangs
  outside the door (`screenshots/2026-09-17/cockpit-75-review-cessna-seat0-head-envelope-through-the-wing-root.png`;
  from the eye, `-76-`, you are looking at the underside of the wing from inside it).
- **The seat poses are in the wrong place, not the cabin.** They put the eye at (+/-0.55, 1.05, -0.90) in the craft's
  frame; the airframe's reference eyes (`SkyhawkAirframe.EYE_STATION/EYE_HEIGHT/EYE_OUT`) are at (+/-0.27, 0.60,
  -1.81). The poses are **0.28 m outboard, 0.45 m high and 0.91 m aft** -- the rear seats', as the airframe's own
  `cabin_room` doc already says.
- **At the reference eyes the same cabin gives 0.40 m of headroom, 0.28 m to the glass and 0.49 m ahead.** Only the
  shoulders are short, by 0.04-0.05 m each side, and the two seats are 0.54 m apart, one shoulder breadth.
- **So: move the seat poses** (native shape-table data, a C++ slot) so the eyes land on the reference eyes -- which puts
  the anchor about 0.46 m below the drawn cabin floor, because the game's eye is 1.35 m over its anchor and a Cessna's
  real eye is 0.89 m over its floor; the station must not draw its own floor there -- **and widen the cabin about
  0.10 m** (0.05 each side). No big enlargement is needed for two players.
- **Flies** (4): off the ground in 7.3 s and 202 m, climbs 12.3 m/s, 68 m/s (132 kt) level, rolls at 113 deg/s. A 45-degree
  turn pulled properly is 6.8 deg/s (the physics for that bank and speed is 8.1), a 360 in 53 s; held on the horizon
  instead it is 4.0 deg/s. Stalls power-off at 17 m/s -- **the book stall the autopilot uses is 38 m/s** -- and lands at
  1.0 m/s of sink, rolling 125 m. Brisk, stable, forgiving: fun.
- **Job** (5): `skyhawk` holds the moving surfaces to the stick.

### Water bomber (tanker) -- protected

- **Fits** (1): both pilots have 0.11 m over the eye and the head is **0.01 m from the WaterBomberBow skin outboard**,
  shoulders 0.05 m from it (`cockpit-78-review-tanker-...png`, red through the roof under the wing). Its own
  `cabin_room` puts the roof 0.06 m over the eye. The two rear seats are fine (0.29 up, 0.40 ahead). Enlarge the flight
  deck, or move the two pilots inboard and down.
- **Flies** (4): heavy and honest. 21 s and 561 m to lift off, 9.5 m/s climb, 87 m/s level, 69 deg/s roll, a pulled
  45-degree 360 in 86 s, lands clean. Buoyancy is `lane/cl415`'s.
- **Job** (4): `water` passes (the drop leaves, lands in a line, puts a fire out); floating and scooping are in progress.

### UH-60 -- in progress (`lane/rotors`)

- **Fits** (1): both pilots have **0.01 m** over the eye and beside it, into CabinFuselage
  (`cockpit-77-review-uh60-...png`), and their knees are 0.18 m from **their own drawn PortPilotSeat and
  StarboardPilotSeat** -- the seat pose and the drawn seat disagree about where the pilot is. The door gunners' heads are
  0.03 m from the skin ahead and their shoulders 0.11 m from the engine housings.
- **Flies** (3): lifts in 0.6 s, climbs 31.6 m/s, 58 m/s (112 kt) nose-down, hovers hands-off without wandering, lands at
  0.8 m/s. **A 30-degree bank with the feet still turns its flight path at 1.2 deg/s**; half pedal gives 4.5. See the
  helicopter note in the backlog.
- **Job** (4): `uh60` passes.

### Gunship

- **Fits** (2): the pilot (seat 0) has 0.05 m from each shoulder to the flight-deck nose, 0.17 m of knee room, and the
  first floor under the seat is **3.5 m down** -- the seat pose is ahead of the drawn flight deck, which `shell_room`
  also names. Seats 1-3 are roomy.
- **Flies** (3): lifts in 18 s and 624 m, climbs 13.4 m/s, 98 m/s level, 50 deg/s roll. **A 45-degree bank held on the
  horizon turns at 20% of the rate the bank should give**; pulled, a 360 takes 102 s. Lands clean.
- **Job** (4): `gunners` and `big_guns` pass.

### Glider

- **Fits** (2): the rays over both heads meet **nothing**: the heads are above the canopy. The front seat's knees are
  0.28 m from the canopy and its shoulders 0.15 m; **the rear seat's shoulders are 0.04-0.05 m from the rear canopy**.
  `shell_room` already says the pod is narrower than the station at every height.
- **Flies** (3): best glide 1.53 m/s of sink at 27 m/s, a glide ratio of 18 (a real two-seater manages 40), roll
  56 deg/s. **A 30-degree circle pulled is 867 m across** -- a real sailplane circles in 150-200 m, and `air`'s own
  arithmetic puts a usable thermal core at 73 m -- so it cannot stay in a thermal. Lands clean at 0.8 m/s.
- **Job** (4): `soaring` passes.

### Light twin (plane)

- **Flies** (2): **780 kg and 44 kN of thrust, a thrust-to-weight of 5.75** (the Cessna's is 0.92, the F/A-18's 0.91).
  85 m/s in 1.9 s and 91 m, a 30 m/s climb, **128 m/s (249 kt) level: the fastest aeroplane in the game**. Roll
  192 deg/s. A pulled 360 still takes 99 s. It is a rocket with a slab on it. One handling number, and a remodel.
- **Fits** (4): 0.42 m over the eye; the sides are open windows.
- **Looks** (2): `joined_parts` KNOWN -- every propeller 0.62 m ahead of its nacelle.

### Fighter (F/A-18F) -- gold model

- **Flies** (3): off in 6.2 s and 158 m, climbs 17.7 m/s, rolls at 128 deg/s, pulls a 45-degree turn at 5.0 deg/s
  against an ideal 5.2, lands clean. **But it tops out at 104 m/s (201 kt) level at full power** -- slower than the
  light twin (128) and the Hawkeye (121). A fighter that cannot outrun a propeller aeroplane is the least fun thing in
  the hangar. A 360 takes 72 s.
- **Fits** (4): 0.22 m over the front seat's eye and 0.18 over the rear's (3 and 7 cm short): close, like a real
  canopy. From outside the envelope sits inside the canopy (`cockpit-79-review-fighter-...png`).
- **Job** (4): `fighter` holds the gear and the hook as drawn parts that move; the hook catches nothing yet (see the
  carrier).

### Hawkeye, Mercury, airliner -- the heavies

- **Hawkeye** flies (3): 26 s and 775 m to lift off, 121 m/s level and still gaining, **32 deg/s roll**, a 360 in
  104 s pulled, and it **bounced 5.2 m** on the robot's landing. Fits (5): 0.51 m and more everywhere.
- **Mercury** flies (3): 849 m to lift off, **22 deg/s roll** -- right for a 707 airframe, sluggish for a game -- a
  bank alone turns it at 20% of the rate, and it bounced 3.8 m. Fits (4): pilots' shoulders 0.24 of 0.30.
- **Airliner** flies (3): 437 m to lift off, 88 m/s, 59 deg/s roll, a bank alone turns it at 25%, lands clean.
  Fits (4): shoulders 0.24 of 0.30 (6 cm short); 0.37 m of headroom.

### Osprey

- **Flies** (4): nacelles up, it climbs vertically at 33 m/s; nacelles forward, 111 m/s level, 107 deg/s roll; back up,
  it lands vertically at 0.6 m/s. Every leg worked first time. **The most fun machine in the fleet after the Cessna.**
- **Fits** (4): 0.23-0.24 m over the pilots' eyes (1-2 cm short).
- **Looks** (3): `joined_parts` KNOWN -- the nose wheel 1.49 m under the fuselage with no leg; no nacelles.

### Helicopters (heli, chinook) -- in progress

- **heli** flies (4): the nimblest helicopter -- 13.2 deg/s on half pedal, 60 kt, climbs 22 m/s, lands clean. Fits
  (2): nothing over any head; the rear pair's knees 0.40 m from the hull. Looks (1): the yellow box.
- **chinook** flies (3): climbs 34.5 m/s, 119 kt, but turns at **3.7 deg/s even on half pedal** (1.2 banked). Fits
  (5): 0.86 m and more everywhere.

### Ground

- **pod**: drives at 38 m/s, 1.6 s to 15 m/s, a 12 m circle -- nimble. **Knees 0.07-0.11 m** from a pressure hull it
  does not draw (`craft_model_audit`: "no hull at all").
- **car**: 50 m/s, 2.8 s to 15 m/s, a 42 m circle, stops from 48 m/s in 61 m. Front knees 0.24 m from the
  **windscreen**, which stands at knee height; no roof.
- **tank**: 14 m/s (49 km/h), a 47 m circle, stops in 8 m. The commander's shoulders meet the Barrel mesh 0.11 m away
  **on both sides**, and there is 0.01 m of floor under the anchor -- worth a look from the hatch.
- **segway**: 3.2 m/s, turns on the spot. Invisible on purpose.

### Ships

- **boat** 35 kt, a 60 m circle in 11 s -- the most fun thing afloat. The helm pair's knees are 0.13 m from the
  wheelhouse ("Near").
- **battleship** 30 kt and a **171 m** circle; the **gunboat** 43 kt and **274 m**. A battleship out-turning a patrol
  boat is backwards.
- **carrier** 30 kt, a 477 m circle, heels 5 degrees. **submarine** 20 kt, heels 13 degrees turning.
- **The carrier's job is not done yet.** `craft_standard.md`'s own example is "a carrier launches and recovers", and
  `carrier_shape` holds four catapults and the wires to the sheet -- as DRAWN parts. In the simulation the hook is a
  channel "a wire catch will read" (`cockpit_world.cpp`, `Channel::Hook`): no catapult and no wire act on anything. An
  F/A-18 can still roll off the deck on its own (158 m to lift off, in `handling`) and stop on it with brakes (168 m),
  but that is a runway, not a carrier.

## Across the whole fleet

**1. Turns are half-hearted, and it is the controls, not the aeroplanes.** The stick is a RATE demand
(`command_rate`): centred, it asks for zero pitch and yaw rate, and the flight controls resist whatever is not asked for.
A level turn needs the body to pitch at w sin(bank) and yaw at w cos(bank), so **a player who banks and holds the nose on
the horizon is asking the aeroplane not to turn**. Measured at 45 degrees:

| held on the horizon, % of the physics rate | craft |
|---|---|
| 20-25% | gunship, Mercury, airliner |
| 35-50% | fighter, tanker, Cessna |
| 63-67% | plane, Hawkeye |

Pulled with rudder fed in, most come close to the ideal (fighter 5.0 of 5.2 deg/s, Cessna 6.8 of 8.1). So the
aeroplanes can turn; the controls make a player work for it, and in a headset a stick held back for a minute is not
fun. **Helicopters have it worse**: banking with the feet still turns the flight path at 0.4-1.2 deg/s, because nothing
weathervanes a helicopter into its turn; only the pedals turn it.

**2. The speed order is upside down.** Level at full power: light twin 128 m/s, Hawkeye 121, Osprey 111, fighter
104, gunship 98, Mercury 92, airliner 88, tanker 87, Cessna 68. The F/A-18 should lead that list.

**3. Every aeroplane stalls between 17 and 28 m/s** (light twin 27, gunship 28, Cessna 17, fighter 20), however big.
**The book stall speeds the autopilots use are about twice that** (Cessna 38 m/s, light twin 55). Forgiving is fine for
fun; identical is not, and the autopilot flying at twice the real stall costs runway.

**4. Seats and airframes disagree more than cabins are too small.** Of the four craft that fit worst -- Cessna,
tanker, UH-60, gunship -- three are a seat pose in the wrong place (Cessna 0.91 m aft and 0.45 m high; UH-60 behind its
drawn seat; gunship ahead of its flight deck), and only the tanker is a cabin too small for where its crew sits.

## Ranked backlog

**My order, highest value first.** The criteria are weighed the way the user put them -- flyable, fun planes -- so a
problem every aircraft shares outranks a problem one craft has, and a fix that is a number outranks a remodel.

1. **Turn coordination (C++, every aircraft).** Make a centred stick in a bank hold a *coordinated turn*, not zero
   rate: feed w sin(bank) into the pitch-rate demand and w cos(bank) into the yaw-rate demand (the same arithmetic
   `handling`'s robot uses to pull), and give the helicopter model a weathervane or an auto-coordination above
   translational lift. Measure with `handling`: "a bank alone turns it at N%" should read near 100.
2. **Cessna seat poses (C++ shape table) and 0.10 m of cabin width.** The user's own question; mostly a data move.
   `seat_room`'s "reference eye" lines are the target, and its Cessna rows should go quiet.
3. **The speed and thrust table (C++ handling numbers).** The light twin's thrust or mass (T/W 5.75 to about 0.3), and the
   fighter's drag so it is the fastest aeroplane in the game. One pass over `handling()`, measured by `handling`.
4. **Tanker flight deck** (with `lane/cl415`, which is in the craft now): pilots inboard and down, or a taller deck.
5. **UH-60 seats** (with `lane/rotors`, in the craft now): the pilots' poses against their drawn seats, and the roof.
6. **Gunship pilot's seat pose**, onto the flight deck.
7. **Glider**: a canopy over the heads and wide enough for the rear shoulders (the user's "more realism"), and a
   thermalling circle under 250 m (more bank authority or less speed in the turn).
8. **Light twin and airliner models** (wave 2 as planned), **Mercury** body.
9. **Stall speeds**: the autopilots' book stall against the wing that actually flies, and some spread between a
   Cessna and a Mercury.
10. **Catapult and wire catch on the carrier** (C++, additive -- the carrier's model is protected and nothing here
    touches it): the carrier's job in the standard's own words.
11. **Heavies' landings**: the Hawkeye's and Mercury's bounces, and the Hawkeye's 32 deg/s roll.
12. **Ground and sea**: pod hull and knees, car windscreen and roof, tank commander against the barrel, boat helm knees,
    and the battleship's turning circle.

**Reordering the waves.** `craft_standard.md` puts the light aircraft first in wave 2 and ground and ships in wave 3,
and I agree with that shape, but:

- **Add a "handling" lane to wave 2, first** -- items 1 and 3. It is C++ and needs the slot, touches every aircraft at
  once, and is the biggest "fun" gain available.
- **The Cessna goes first among the light aircraft, and it is a seat move, not an enlargement.**
- **The glider stays in wave 2.** The **plane** and **airliner** remodels can follow the handling lane; the plane's
  worst fault is a number, not its shape.
- **Mercury before osprey, hawkeye and gunship** in the heavy group. The Osprey already flies best, and the Hawkeye
  already looks best; the gunship needs only its pilot's seat moved (item 6).
- Wave 3 unchanged, except that **the pod and the car are worst on looks and fit together** and are one small lane.

## Handling, measured and proposed (`lane/handling`, step 1)

Items 1 and 3 above, measured through `set_pilot_input` by `tests/handling.gd`'s new table (T/W, top speed clean,
"held %", "pulled %", a 70-degree pulled 360, the g of a one-second full pull, and "rudder %"). The reasoning and the
rejected data-only fixes are in `agents.md`, "A bank held with the nose on the horizon barely turns".

**A correction to finding 2:** the robot flew with its gear down, and `gear_drag` was most of the fighter's 104 m/s.
With the gear up it does 157.5 -- still behind the light twin (166) and the Hawkeye (166, and still gaining).

**The rebalance, landed in step 2**: every row flown with `-- --kind=<k> --set=...` on main's library before it was
typed into `default_handling`, then flown again on the built one. The Cessna, the tanker, the gunship and the Osprey
are not touched.

| craft | was: thrust / drag_forward | top m/s was | now | top m/s | take-off | climb m/s | stall m/s | landing |
|---|---|--:|---|--:|---|--:|--:|---|
| **fighter** | 196 kN / 8.5 | 157.5 | drag_forward **4.3** | **221** | 6.1 s, 156 m | 22.8 | 19.7 | clean, 0.9 m/s, bounced 1.1 m |
| tomcat | 210 kN / 9.1 | 157.6 | drag_forward **4.61** (the fighter's, by mass) | 221 | | | | |
| mercury | 380 kN / 30 | 115.8 | drag_forward **19.4** | 142 | 24.5 s, 799 m | 13.6 | 25.4 | bounced 4.8 m (3.6 before) |
| hawkeye | 60 kN / 1.85 | 166.1 | drag_forward **3.06** | 140 | 26.5 s, 801 m | 12.7 | 23.2 | bounced 4.1 m (5.6 before) |
| airliner | 60 kN / 5.0 | 112.4 | drag_forward **3.6** | 133 | 11.9 s, 412 m | 18.3 | 25.8 | clean, 0.9 m/s |
| gunship | 92 kN / 9.0 | 104.5 | -- | 104.5 | | | | |
| tanker | 48 kN / 4.6 | 107.6 | -- (protected) | 107.6 | | | | |
| **plane** (light twin) | 44 kN / 1.6, T/W 5.75 | 166.4 | thrust **20 kN**, drag_forward **2.17**, T/W 2.6 | 96 | 4.6 s, 202 m | 19.7 | 25.4 | clean |
| cessna | 9 kN / 2.0 | 67.8 | -- (gold) | 67.8 | | | | |

The order is **fighter and tomcat 221 >> Mercury 142, Hawkeye 140, airliner 133 > Osprey 111, tanker 108, gunship
105 > light twin 96 > Cessna 68**. None of it moves an autopilot's cruise, `max(min(0.55 x flat_out, 70), 1.45 x
stall)`: every one of these kinds sits on the 70 m/s cap or its stall floor before and after.

**Two numbers were proposed and had to come back.** Step 1 proposed a 238 m/s fighter and a 146 m/s airliner; built,
**alpine was refused on loading**, because every level's soft edge is sized on the widest turn any powered wing needs
at its top speed (`turn_radii`), and alpine has room for 3.97 km of it -- the airliner's was 4,331 m on its autopilot's
0.44 rad of bank, the fighter's 4,285. At 221 and 133 they are 3,688 and 3,609. **A faster fighter needs a new rule for
the band, not a number here** (`agents.md`, "The fastest wing sizes the world"). And step 1's light twin, 9 kN for a
thrust-to-weight of 1.18, was the addon's own test aeroplane: `cockpit_loopback` wants its stick to bite within a
second and a half of standing still and 40 m taxied in 10 s at 5 % throttle, and it managed neither. 20 kN keeps the
same 96 m/s top with the punch to pass them, and is off the ground in 4.6 s.

**A bank turns every aeroplane now**, and the g limit caps a full pull. Main 236a41dc against the lane, through the
player's own controls: "held %" from 21-74 to **100** on every aeroplane; "rudder %" unchanged (Cessna 34 and 34,
Mercury 50 and 50, gunship 41 and 42); a full pull at top speed from 22.3 g to 8.4 in the fighter, 16.6 to 4.2 in the
light twin, 11.4 to 2.9 in the Hawkeye, 5.9 to 4.2 in the Cessna. `agents.md`, "A bank held with the nose on the horizon
barely turns", has the mechanism and the rejected data-only fixes. **Backlog items 1 and 3 are done for the aeroplanes;
the helicopters' half of item 1 is `lane/rotors`', which calls the same `coordinated_turn`.**

## Keeping the standard enforced

- **`seat_room`** is in `suites.txt` after `shell_room`. It prints every short clearance, worst first, with the craft,
  the seat, the ray and the part it ran into; the Cessna's reference-eye lines; and each drawn `cabin_room`. It fails
  only if a craft could not be built or its rays met nothing. **A new craft scene is measured the day it lands.**
- **`handling`** is in `suites.txt` after it. It prints every leg's numbers and one verdict per craft, and fails only if
  a pilotable kind produced no measurement. **A new kind is flown the day it lands**; `-- --kind=<name> --trace` prints
  the approach and the stall second by second.
- **`seat_room_shot`** (windowed, `-- --seats=cessna/0,uh60/0 --out=<dir>`) draws the envelope, 20 s for five seats.
- **`fit` should be extended** to the fighter, the Mercury, the UH-60 and the brig: it lists its craft by hand and
  those four are missing, so their reach has never been measured. Not done here -- it is `fit`'s list, and a review
  lane does not fix.

## Pictures

`screenshots/2026-09-17/` in the main checkout:

- `cockpit-75-review-cessna-seat0-head-envelope-through-the-wing-root.png` -- the head envelope through the top of the
  wing root, and the station slab outside the door.
- `cockpit-76-review-cessna-seat0-from-the-eye-inside-the-wing.png` -- from that eye: the inside of the wing.
- `cockpit-77-review-uh60-pilot-head-envelope-through-the-cabin-roof.png`
- `cockpit-78-review-tanker-pilot-head-envelope-through-the-roof.png`
- `cockpit-79-review-fighter-pilot-envelope-inside-the-canopy-fits.png` -- for contrast. The red shows through the
  glass because glass does not hide it; nothing of it stands outside the canopy.

All fifteen (side, front and eye for five seats) are in `godotgames-drafts/2026-09-17/cockpit-review/`.

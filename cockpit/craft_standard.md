# The craft standard

**Every craft in this game — aircraft, ships, land vehicles — is held to one standard, set by the
user on 2026-09-17.** This file is that standard, the gold examples it is measured against, the
state of every craft against it, and the order the work is being done in. **A lane improving a
craft reads this first.**

## What every craft must be

The goal is **flyable, fun craft**. Four things, in the user's words and in this order:

1. **It looks good.** Recognisable at a glance as what it is, in the faceted low-poly house style
   (no smooth normals), at the quality of the gold standard below. One connected object, every
   part named, nothing floating.
2. **It flies (or drives, or sails) well.** It handles sensibly and is fun — takes off, climbs,
   turns and lands like the thing it is. **This is a first-class requirement, not an afterthought,
   and until tonight nobody had checked it for any craft.**
3. **It fits its crew.** Every seat holds a real player — room for a VR head and arms, the eye where
   the view makes sense — and every seat of a multi-crew craft is actually inside the craft.
4. **It does its job.** The craft's feature works end to end: a swing wing sweeps, a water bomber
   floats and scoops, a sailplane soars, a carrier launches and recovers.

**Deviations from reality are welcome whenever they serve those four.** Exact published specs matter
less than the four above. The user's own example: **the Cessna is very good but may be too small to
hold two players, so making it artificially larger is a good call.** A reference is for getting the
*proportions and features* right; it is not a precision target, and no lane should block on a missing
published figure.

## The gold standard

Three craft are the bar. **Measure every other craft against these, and never degrade them.**

| craft | why it is gold |
|---|---|
| **Cessna 172S** (`cessna`) | Measured off its information manual, faceted to the reference tessellation, flaps, ailerons, elevators, trim tab, rudder and propeller all moving with the stick. |
| **F/A-18F Super Hornet** (`fighter`) | Measured off NASA's HARV three-view, gear and hook that work, recognisable from any angle. |
| **Nimitz/Ford-class carrier** (`carrier`) | Described by the user as *exceptionally good*. **Do not degrade it.** Now carries the flag-plot briefing room too. |

**Also protected**: the **water bomber** (`tanker`), which the user called *really nice* — its
airframe was made one object tonight and its buoyancy is being fixed.

What the gold craft have in common, and what every improved craft should have:
- a **reference** (public-domain three-view from Wikimedia Commons, dimensions from Wikipedia) used
  for proportion and features;
- **its own airframe class** (`FighterAirframe`, `SkyhawkAirframe`) rather than a generic builder;
- **moving parts driven through the real path** — the stick, the bus;
- **a suite that holds it to its shape and a probe that photographs it.**

## The fleet against the standard

State as of 2026-09-17, from tonight's evidence: `craft_model_audit.md` (the visual ranking),
`tests/joined_parts.gd` (is it one object), `tests/shell_room.gd` (is the crew inside),
`tests/named_parts.gd` (every part named). **"Flies" is unknown for every craft** — that is the
review lane's first job.

| craft | kind | user's note | tonight's evidence | work |
|---|---|---|---|---|
| **cessna** | light aircraft | gold; **too small for two players** | good model | **enlarge the cabin for two players**, keep the look |
| **fighter** | fighter | gold | good | protect |
| **carrier** | ship | **exceptionally good** | good; operator seat now enclosed | **protect — do not degrade** |
| **tanker** | amphibian | **really nice** | one object now; buoyancy in progress | finish buoyancy (`lane/cl415`) |
| **chinook** | helicopter | **not good** | no aft pylon, rear rotor on empty air, plank rotors; crew not enclosed | **rebuild** — wave 1 |
| **uh60** | helicopter | **not good** | flat-cut tail, tail rotor unreadable, parts adrift; crew not enclosed | **rebuild** — wave 1 |
| **heli** | helicopter | — | **worst in the fleet** — a yellow box, self-disclaimed | **rebuild** — wave 1 |
| **glider** | sailplane | good but **lacks realism** vs Cessna/F-18 | cabin parts poke through canopy; crew not enclosed | **more realism**, fix the canopy fit — wave 2 |
| **airliner** | airliner | — | slab-sided; windows drawn past the fuselage end; engines without pylons | rebuild |
| **plane** | light twin | — | slab; propellers ahead of their nacelles | rebuild |
| **mercury** | E-6B | — | envelope right, body is the airliner's slab; engines and wheels adrift | rebuild |
| **osprey** | tiltrotor | — | no nacelles; nose wheel adrift; crew not enclosed | improve |
| **gunship** | AC-130 | — | nose wheels adrift; crew not enclosed | improve |
| **hawkeye** | E-2 | — | the look reference; crew not enclosed | fit the crew |
| **segway** | ground | — | **its own collision box and nothing else**; never photographed | rebuild |
| **car** | ground | — | box on box, gun through the roof | rebuild |
| **pod** | ground | — | no hull at all | rebuild |
| **tank** | ground | — | M1 Abrams, done tonight | protect |
| **train** | rail | — | Super Chief, in progress (`lane/train`) | finish |
| **tower** | structure | — | fixed today; crew not enclosed | fit the crew |
| **boat**, **gunboat**, **pirate**, **submarine**, **battleship** | ships | — | mostly lofted and decent; gunports adrift on `pirate` | review |
| **cb90** | fast assault craft | new (2026-09-18): "a beefier CB90 ... two guns on the back, maybe a missile launcher" | kind 30: `cb90` holds its published 15.9 x 3.8 m, its crew, its two after guns and a lock and launch through the helm at an aircraft and at a ship under way on the light twin's missiles (its radar pair the "sea radar" row); `handling` flies it (47 kt, leans 8.6 deg) | fly it by hand |
| **F-14 Tomcat** | fighter | new, swing wing | in progress (`lane/tomcat`) | build |
| **F-16 Falcon** | fighter | new, single seat | kind 27 (2026-09-18): `falcon` and `falcon_flight` hold its shape, its pilot's seat and how it flies against the F/A-18F | fly it by hand |

## The work, in waves

**The machine renders comfortably for about six lanes at once**, so the work runs in waves. Each
wave starts as the previous one frees capacity.

**Wave 1 — starting now:**
- **`rotors`** — the three helicopters the user called out or the audit put last: **chinook,
  uh60, heli**. They share rotor, pylon and boom work, so one lane does them together, to the
  gold standard.
- **`review`** — every craft, scored against the four criteria above, **with the two nobody has
  measured: how it flies, and whether a real player fits each seat.** Produces a per-craft verdict
  and a ranked backlog for waves 2 and 3, and leaves behind a repeatable check so the standard stays
  enforced.

**Already running**, and part of this standard: `train`, `cl415` (tanker buoyancy), `tomcat`
(F-14), `falcon` (F-16).

**Wave 2 — as those finish, highest value first:**
- **light aircraft** — **cessna (enlarge for two players)** and **glider (more realism)**, the two
  the user named; then **plane** and **airliner**.
- **heavy and special aircraft** — mercury, osprey, gunship, hawkeye.

**Wave 3:**
- **land** — segway, car, pod, tower.
- **ships** — boat, gunboat, pirate, submarine, battleship. **The carrier is not touched.**

The review lane may reorder waves 2 and 3; its verdicts outrank this table.

**The review has landed: `craft_review.md`** scores every craft on the four criteria with the evidence, and ranks the
work. It puts a fleet-wide **handling** lane (turn coordination, thrust and drag numbers) at the head of wave 2, and
finds the Cessna's problem is its **seat poses**, not the size of its cabin. `tests/seat_room` (does a player fit) and
`tests/handling` (how it flies) re-measure both on every run.

## How a lane meets the standard

The method that produced the gold craft, and the traps paid for tonight:

- **Reference for proportion, then stop.** Commons for drawings, Wikipedia for dimensions, nothing
  else without asking. Get the look and the features right; do not chase the last percent.
- **Probe before a picture.** Print every visible mesh's vertex box in the craft's frame before
  opening a PNG. Measure from drawn vertices, never `transform * get_aabb()`.
- **One object.** `tests/joined_parts.gd` must pass — bed each part into its parent. A craft in
  eighteen pieces passed every other suite tonight.
- **Every part named, with every loop variable in the name.** `tests/named_parts.gd`. Godot silently
  renames a duplicate to `@MeshInstance3D@N`.
- **The crew inside, and fitting.** `tests/shell_room.gd` and `VehicleView.cabin_room()`. **Derive the
  cabin from the airframe; do not tune a tolerance** — there is no width that fits a Cessna seat in a
  sailplane canopy. Where a real craft is too small for a player, **enlarge it** — the user has said so.
- **Fly it.** Take off, climb, turn, land, drive through the real controls, and say how it handles.
- **Before and after, from the same camera, with the before taken first.** A bare scene with no level
  (`tests/fighter_inspector_shot.tscn -- --kind=<kind> --ortho`) is 8 seconds; the full gallery is minutes.
- **Never degrade a gold craft.** A lane touching shared code (`vehicle_view.gd`, the builders) re-runs
  `fighter`, `skyhawk`, `carrier_shape` and `aircraft_fidelity` and looks at the gold craft before and after.
- **C++ needs the slot from team-lead.** A new kind, a changed shape, or a flight-model change is C++.

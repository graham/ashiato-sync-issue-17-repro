// EVERY CRAFT KIND, ONE ROW EACH: the one list a new vehicle is added to (lane/kinds, 2026-09-18).
//
// Asked for on 2026-09-18: "we could have many vehicles in the future, so let's make sure it's easy to expand the
// count". A kind was a typed number, a line in `kind_name_of`'s names, a line in the constructor's shape table, a
// case in `default_model` and a `kKindCount` to bump, in five places a hundred lines to two thousand apart, and the
// GDScript enum by hand beside them. Now it is a row here, and cockpit_world.cpp includes this file to make each of
// those from it: `kKind<Id>` numbered in row order, `kKindCount`, the name, the shape, the movement model, and
// `CockpitWorld.kind_table()`, from which `cockpit/tools/generate_kind_enum.tscn` writes `Sim.Kind`.
//
//   KIND(Id, "name", shape function, movement model)
//
// - Id is the C++ constant's tail, `kKind<Id>`, and upper-cased it is the `Sim.Kind` entry: `LittleBird` is
//   `Sim.Kind.LITTLEBIRD`.
// - The name is the shape table's and `kind_name`'s: what a person reads and what a log says.
// - The shape function is the kind's `*_shape()` in cockpit_world.cpp: its size, mass, seats and parts.
// - The model is how it MOVES (`Model`), and several kinds share one: a Cessna and a glider are both airplanes.
//
// APPEND, NEVER INSERT. The row's place is the kind's number, and that number is on the wire, in saved levels and
// packages, and in two lanes' heads at once. A kind that is retired keeps its row.
//
// What a row does NOT hold is the content that has a sensible default: the bus (`default_bus`), the handling
// (`default_handling`), guns (`gun_of`) and stores (`loadout_of`). A kind with no case there is fitted with the
// default, which is right for most of them. `cockpit/agents.md`, "How to add a craft kind", is the whole checklist.

// A kind names a VEHICLE. A movement model names HOW IT MOVES, and several kinds can share one. Keeping them apart is
// what makes "add a vehicle" a table entry rather than another branch in the simulation.
KIND(Pod, "pod", pod_shape, Hover)
KIND(Plane, "plane", plane_shape, Airplane)
KIND(Boat, "boat", boat_shape, Boat)
KIND(Car, "car", car_shape, Car)
KIND(Heli, "helicopter", heli_shape, Helicopter)
KIND(Train, "train", train_shape, Train)
KIND(Airliner, "airliner", airliner_shape, Airplane)
KIND(Osprey, "osprey", osprey_shape, Tiltrotor)
KIND(Chinook, "chinook", chinook_shape, Helicopter)
KIND(Gunboat, "gunboat", gunboat_shape, Boat)
KIND(Cessna, "cessna", cessna_shape, Airplane)
KIND(Tower, "tower", tower_shape, Fixed)
KIND(Carrier, "carrier", carrier_shape, Boat)
KIND(Battleship, "battleship", battleship_shape, Boat)
// A TRACKED VEHICLE IS A CAR WITH DIFFERENT NUMBERS, and that is the whole reason there is no Model::Tracked. What a
// track changes is grip, mass and how fast the thing will turn -- every one of them a coefficient the Car model
// already has -- and a movement model exists to say which FORCES are present, not how big they are.
KIND(Tank, "tank", tank_shape, Car)
// A GUNSHIP IS A TRANSPORT AEROPLANE. The guns are cargo as far as the wing is concerned, which is exactly what they
// are on the real one.
KIND(Gunship, "gunship", gunship_shape, Airplane)
// AND THE SEVENTEENTH, WHICH COST A BIT ON THE WIRE: `VehicleKind` was four bits and sixteen kinds filled it exactly.
// It went to five, and the sentinel with it; since lane/kinds it is sixteen bits (`kKindIdBits`) and the sentinel is
// derived from the width. A WATER BOMBER IS AN AEROPLANE CARRYING WATER, the same sentence the gunship gets.
KIND(Tanker, "tanker", tanker_shape, Airplane)
// A GLIDER, the first aircraft here with no engine at all, and therefore the first that cannot fly anywhere without
// the air doing something (see `rising_at`). An aeroplane with the thrust set to zero: nothing about the forces on it
// is different, and one number in the handling table is.
KIND(Glider, "glider", glider_shape, Airplane)
// A PIRATE SHIP: a brig under sail, sailed by the world and by nobody else yet. The first kind no player may board --
// see `Shape::pilotable` -- and the first that goes where the wind lets it rather than where an engine pushes it.
KIND(Pirate, "pirate", pirate_shape, Sail)
// AN E-2D ADVANCED HAWKEYE and A VIRGINIA-CLASS SUBMARINE, the US Navy fleet's early-warning aircraft and its attack
// submarine, at their real sizes. A wing is a wing, and a surfaced submarine is a hull with a rudder.
KIND(Hawkeye, "hawkeye", hawkeye_shape, Airplane)
KIND(Submarine, "submarine", submarine_shape, Boat)
// A SEGWAY: the one vehicle a player STANDS on rather than sits in, and the only one that is invisible. A sphere at
// the feet, one seat at standing eye height, and a model that goes where the stick points without leaving the ground.
//
// Asked for on 2026-09-15, to give the lobby a way to walk about: "just put them in an invisible vehicle called a
// segway that way they can move around and they are still in a vehicle (but just make it a sphere at their feet."
//
// WHY A VEHICLE AND NOT A WALKING PLAYER. Everything in this game that moves is a vehicle with a seat, and all of it
// -- replication, rollback, the crew manifest, boarding, the wire -- follows from that. A player on foot would be a
// second kind of moving thing for every one of those systems to get wrong.
KIND(Segway, "segway", segway_shape, Segway)
// A BOEING 747-400, the "jumbo", since 2026-09-19 (lane/liners): the row that was the E-6B Mercury, renamed in place, so
// its number -- on the wire and in saved levels and packages -- is the one the Mercury had. Its size is the drawn
// airframe's (`Boeing747Airframe`, measured off Boeing's ACAPS in `cockpit/craft/jumbo/sources.md`).
KIND(Jumbo, "jumbo", jumbo_shape, Airplane)
// A tandem-seat carrier fighter inspired by the public F/A-18F envelope.
KIND(Fighter, "fighter", fighter_shape, Airplane)
// A UH-60M-INSPIRED UTILITY HELICOPTER at the Army's public envelope. A new kind rather than a replacement for
// kKindHeli: saved levels and peers which name the original light helicopter keep exactly the craft they named.
KIND(Uh60, "uh60", uh60_shape, Helicopter)
// A GRUMMAN F-14D TOMCAT, with a swing wing: two crew in tandem, a pilot who flies and a radar intercept officer who
// does not, and the wing sweep on `Channel::Sweep`. Drawn by `TomcatAirframe`; measured in
// `cockpit/craft/tomcat/sources.md`.
KIND(Tomcat, "tomcat", tomcat_shape, Airplane)
// PORCO ROSSO'S RED FLYING BOAT, the film's "Savoia S.21": one seat, a hot-rod racer on a planing hull that floats,
// taxis on its water rudder and takes off from the sea, and two machine guns in the nose. Drawn by `SavoiaAirframe`;
// measured in `cockpit/craft/savoia/sources.md`.
KIND(Savoia, "savoia", savoia_shape, Airplane)
// A GENERAL DYNAMICS F-16A FIGHTING FALCON, BLOCK 15: one pilot under a bubble canopy, a chin intake and a single
// engine. Drawn by `FalconAirframe`; measured in `cockpit/craft/falcon/sources.md` off a 1:100 vector three-view.
KIND(Falcon, "falcon", falcon_shape, Airplane)
// A BOEING (MD HELICOPTERS) MH-6M LITTLE BIRD: two pilots side by side in an egg flown doors off, and a troop bench
// outboard each side. Drawn by `LittleBirdAirframe`; measured in `cockpit/craft/littlebird/sources.md`. Kind 28: the
// F-16 merged first as 27.
KIND(LittleBird, "littlebird", littlebird_shape, Helicopter)
// A GRUMMAN EA-6B PROWLER: four crew in two side-by-side rows, a carrier wing fold and mission displays. The real
// front-right station was ECMO-1; the game's Copilot role is the requested dual-control concession. Kind 29 is the
// thirtieth and last kind in the five-bit short catalogue; later kinds use the extended form already on the wire.
KIND(Prowler, "prowler", prowler_shape, Airplane)
// A CB90 FAST ASSAULT CRAFT (Stridsbåt 90 H): a helmsman and a weapons officer in the wheelhouse, a gunner at each of
// two heavy machine guns on the after deck, and a box of missiles on the wheelhouse roof that the wheelhouse aims by
// pointing the boat, as the light twin's pilot does. Drawn by `CombatBoat`; measured in `cockpit/craft/cb90/sources.md`.
// Kind 30, the first in the extended form: the Prowler merged first as 29 (lane/boats, 2026-09-18).
KIND(Cb90, "cb90", cb90_shape, Boat)
// A BOEING AH-64D APACHE LONGBOW: two crew in tandem, the GUNNER in front and low and the PILOT behind and higher,
// and BOTH fly it -- seat 0 the pilot and the primary, seat 1 the copilot/gunner on the same linkage. Drawn by
// `ApacheAirframe`; measured in `cockpit/craft/apache/sources.md` off the Army's public-domain three-view. Kind 31:
// the Prowler merged first as 29 and the CB90 as 30 (lane/apache, 2026-09-18).
KIND(Apache, "apache", apache_shape, Helicopter)
// A LOCKHEED MARTIN F-35B LIGHTNING II, the short take-off and vertical landing one: one pilot, a lift fan behind the
// cockpit and a nozzle that swivels 95 degrees down. It FLIES AS A TILTROTOR, because that is what the model already is:
// a wing and a thrust vector that swings from the nose to the aircraft's up on `Channel::Tilt`, with the controls
// floored on the swing rather than the airspeed. The nozzle's travel is the kind's (`Handling::vector_travel`), 95
// degrees where the Osprey's nacelles go 97.5. Drawn by `LightningAirframe`; measured in
// `cockpit/craft/lightning/sources.md` off the JSF Program Office's renders. Kind 32: the Apache merged as 31
// (lane/lightning, 2026-09-19); the number is the next free one at merge.
KIND(Lightning, "lightning", lightning_shape, Tiltrotor)
// A FAIRCHILD REPUBLIC A-10C THUNDERBOLT II, the "Warthog": one pilot, a straight thick wing, two TF34s high on the
// rear fuselage, and the GAU-8/A Avenger in its nose, mounted to port so the barrel that fires is on the centreline.
// An AEROPLANE with conventional handling, cables not fly-by-wire, at its published speeds: 300 kt cruise, 381 flat
// out, a 120 kt stall. Drawn by `WarthogAirframe`; measured in `cockpit/craft/warthog/sources.md` off Kaboldy's
// three-view. The number is the next free one at merge (lane/warthog, 2026-09-19).
KIND(Warthog, "warthog", warthog_shape, Airplane)
// A LOCKHEED C-130H HERCULES TRANSPORT: the gunship's airframe with no guns and a ramp to load by. Two kinds and not a
// flag on one, because what a kind is -- its crew, its bus, its guns -- is exactly what differs: a pilot, a copilot and a
// loadmaster, a ramp, and no `gun_of`. Drawn by `HerculesAirframe` with `armed` false; measured in
// `cockpit/craft/gunship/sources.md`. The number is the next free one at merge (lane/liners, 2026-09-19).
KIND(Transport, "transport", transport_shape, Airplane)
// A NORTH AMERICAN P-51D MUSTANG: one pilot under a bubble canopy, a Packard Merlin, six .50s in the wings, and a TAIL
// WHEEL -- the first taildragger here, resting on three points at its drawn 12.9-degree rake, its wheels pushing where
// they are (`roll_a_taildragger`). Born on its lifting surfaces (`planform_of`), cables and not fly-by-wire. Drawn by
// `P51Airframe`; measured in `cockpit/craft/p51/sources.md` off AN 01-60-3's three-view. The number is the next free one
// at merge (lane/warbirds2, 2026-09-19).
KIND(P51, "p51", p51_shape, Airplane)
// A REPUBLIC P-47D-30 THUNDERBOLT: one pilot under a bubble canopy, a turbo-supercharged R-2800, EIGHT .50s in the
// wings, and a tail wheel that only ever LOCKS AT CENTRE OR SWIVELS FULLY -- there is no steering linkage on it
// (AN 01-65BC-1), which is `Planform::tailwheel_steer` of zero and not a line of new code. Born on its lifting
// surfaces (`planform_of`), cables and not fly-by-wire. Drawn by `P47Airframe`; measured in
// `cockpit/craft/p47/sources.md` off the 1944 erection and maintenance drawings and NACA TN 2675's three-view. The
// number is the next free one at merge (lane/warbirds2, 2026-09-19).
KIND(P47, "p47", p47_shape, Airplane)
// A FIREBOAT on the FDNY Three Forty Three (Marine 1): two helms in the wheelhouse and three water MONITORS -- the
// trainable deluge guns a fireboat fights with -- two forward and one aft, on the three turret mounts. It puts water
// on a burning oil platform, which the simulation already knows how to model (`FireState`, `douse`, `light_fire`).
// Drawn by `Fireboat`; measured in `cockpit/craft/fireboat/sources.md` off a Commons profile at 71.3 px a metre. The
// number is the next free one at merge (lane/fireboat, 2026-09-19).
KIND(Fireboat, "fireboat", fireboat_shape, Boat)

// A McDONNELL DOUGLAS F-4E PHANTOM II: two crew in tandem, two J79s, and the mark with the gun. The E is the first
// with an internal M61A1, in a fairing under a longer slimmer radome, and the first with LEADING EDGE SLATS and no
// boundary layer control -- all from the aeroplane's own flight manual's main differences table, not inferred
// (`cockpit/craft/phantom/sources.md`). It has NO WING FOLD: the C and D do, the E does not, so the joint is a panel
// line and nothing on it moves. Drawn by `PhantomAirframe` and measured off a USAF technical order that prints eleven
// dimensions in metres; the measuring found that the widely published "45 degree leading edge sweep" is the QUARTER
// CHORD and the leading edge is 51.5. The number is the next free one at merge (lane/phantom, 2026-09-20).
KIND(Phantom, "phantom", phantom_shape, Airplane)

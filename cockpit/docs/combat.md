# cockpit — guns, ships and what breaks

Part of [`agents.md`](../agents.md), which carries the rules every one of these files assumes and an
index of the rest. **Everything that is fired, dropped or sunk, and the craft built to do it.**

## TWO CAPITAL SHIPS, AND A CARRIER LANDING

A Ford-class carrier (337 m, a flight deck 332.8 by 78) and an Iowa-sized battleship (270 m by
33), at FULL SCALE and under way out at sea. Full scale deliberately: a carrier shrunk to look
manageable is a carrier you cannot land on, and a third of a kilometre of deck is what would
make an approach a thing you can get wrong twice and still fix. Their mass is ten thousand
tonnes rather than a hundred thousand -- real displacement beside a one-tonne Cessna is a ratio
nothing needs, and at ten thousand the aeroplane still cannot shift it.

Ocean only, which the BOAT waypoint pool already means: everything inside the island's
square is a field.

### A FORD-CLASS CARRIER

Asked for on 2026-09-15: "make sure ours is a modern american navy carrier, the shape and
features should match it (including size)". The carrier was a Nimitz-sized BOX: 333 by 76.8,
its deck 11 m above its middle, a hull 76.8 m wide all the way down to a keel 11.6 m under the
sea, and every seat on the deck. It is now the **Gerald R. Ford (CVN-78)**, the newest class in
the US Navy, at its real size.

**The fact sheet**, with a URL for every number, is `research.md` in
`C:\Users\Graham\godotgames-drafts\2026-09-15\cockpit-carrier\`, outside the repository. It was gathered from public
sources: facts and dimensions only, no copied plan, image or texture. CONFIRMED means two
sources agree; ESTIMATE means derived, with the method in the sheet.

| | Ford | status |
|---|---|---|
| length overall / flight deck | 337 m / 332.8 m (1,106 / 1,092 ft) | CONFIRMED |
| flight deck width / waterline beam | 78.0 m / 40.8 m (256 / 134 ft) | CONFIRMED |
| draught / full-load displacement | 11.9 m (39 ft) / ~100,000 t | CONFIRMED |
| flight deck above the waterline | 18.5 m | ESTIMATE, from the Nimitz hull the Ford shares |
| island | 18.3 by 9.1 m, starboard, 42.7 m further aft and 0.9 m further outboard than a Nimitz's | size SINGLE (HII); the shift CONFIRMED |
| island middle | ~230 m aft of the bow tip; mast top ~64 m above the waterline | ESTIMATE |
| navigation bridge eye | ~32 m above the waterline, on the island's forward face | ESTIMATE |
| angled deck | 9 degrees to port | the Nimitz figure (SINGLE); the Ford's is "9 to 10" |
| catapults | 4 EMALS (2 bow, 2 waist), 91.4 m stroke | CONFIRMED; positions ESTIMATE |
| arresting wires | 3 (a Nimitz has 4), 12.2 m apart | count CONFIRMED; spacing from the Nimitz manual |
| elevators | 3, each 25.9 by 15.8 m: two starboard, BOTH forward of the island, one port | count and sides CONFIRMED, size SINGLE (HII) |
| jet blast deflectors | 4, 11 m across, raised 3.3 m at 50 degrees | SINGLE (Navy SBIR) |

A Nimitz has four elevators with one aft of the island; the Ford's island moved aft to give the
deck forward of it, and both starboard elevators are there. That is the one layout fact most
worth getting right, and the obvious mistake to make from memory of the older ship.

**THE SHIP IS PARTS, AND THE PARTS ARE THE AUTHORITY.** `Shape` in `cockpit_world.cpp` may list
up to 24 `HullPart`s. Each is a convex outline in plan, stood between two heights, with what the
part is for: `Hull`, `Deck`, `Island`, `Bridge` or `Station`.
- **The physics** collides with every part but the two rooms people stand in, a `Bridge` and a
  `Station`, as one compound body with one shared density (`b3CreateHull` per part), so the mass
  centre falls low in the hull where the steel is. The first version collided with the bridge too,
  which put every seated head on the carrier inside a solid block for any ray, round or query that
  asked; `collides()` is now the one answer, and `kind_geometry` hands it out per part as `solid`.
- **The deck** `deck_under` finds is the tops of the `Deck` parts. It asks whether a point is
  inside their outlines rather than inside a rectangle, so an aeroplane beside the Ford's narrow
  bow is over the sea.
- **The drawing** is those parts (`objects/vehicles/ships/ship_hull.gd`), from `kind_geometry`'s
  `parts`.
- **The seats** are placed by `seat_in(part, across, aft, yaw, station)`: on the floor of a
  `Bridge` or `Station` part, so a helm cannot be typed anywhere its room is not.
- **`extents`** are worked out from the parts by `finish_hull`. `hy` still means "the deck,
  above the origin", which the smoke test's landing and `far_out`'s chocked aeroplane already
  took it to mean.

The flight deck is not convex -- it narrows to the bow and bulges to port where the landing
area is angled off -- so it is five parts along the sheet's 17-point outline, plus the three
elevators.

**THE ORIGIN IS ON THE DESIGN WATERLINE**, midships, +X starboard and -Z to the bow. A sheet point
"x aft of the bow tip, z to starboard" is `(z, x - 168.5)` here. A hull used to float with its
origin `kSinkAtRest` (1/1.6 m) under the sea, which is where four probes pushing at 1.6 times
weight balance it. `Shape::waterline` now puts the probes that far below the waterline instead,
and `afloat_hx`/`afloat_hz` reach them out as far as the hull is AT the waterline, not as far
as the deck overhangs it. So the carrier floats with the sea at its origin and its keel 11.9 m
down. The default `waterline` is `kSinkAtRest`, the old answer exactly, for any hull that
lists no parts.

**The mass stays ten thousand tonnes**, and that was weighed again when the hull took its real
shape. The handling is tuned to it, a hundred-thousand-tonne body against a one-tonne Cessna is a
1e5 mass ratio for the solver, and neither mass lets an aeroplane shift the ship. The draught
comes from where the keel is drawn, not from the mass.

**What the deck adds that nothing collides with** -- catapult tracks, wires, blast deflectors,
the landing area, the LSO platform, the painted 78 -- is `CarrierPlan`
(`objects/vehicles/ships/carrier_plan.gd`), in the same frame. `CarrierDeck` and `DeckLaunch`
read the launch catapult from it: bow catapult 1, parallel to the centreline. `DeckLaunch`'s
"she has gone over the side" is `CarrierPlan.is_on_deck`, the simulation's outline. It used to
be `abs(x) > 34` beside a typed `TRACK_X = -14`, `SHUTTLE_Z = -60`, which a different ship would
have kept.

**Found on the way: the carrier and the battleship were never drawn as ships.** `_build_wing`
returns at `span <= 0` before its CARRIER and WARSHIP branches, and neither ship has a span, so
the deck slab, the angled centreline stripes, the island, the superstructure and both turrets
had never been built. Both ships were the plain box with an orange nose cone. The CARRIER branch
is gone; a ship with parts is drawn from them.

`tests/carrier_shape.gd` holds the parts to the sheet, and asks the physics where an aeroplane
stands and how deep the hull floats. Measured on 2026-09-15:
- the deck is 333.0 by 77.9 m at 18.50 m;
- the island's middle is 229.9 m aft of the bow tip, on the starboard edge;
- aeroplanes put down on the bow, the angled deck's sponson, the port elevator and the island
  roof stand at 18.50, 18.50, 18.50 and 42.50 m;
- one put down beside the bow, where the old rectangle had deck, is 19 m under the waterline
  three seconds later;
- steamed for five minutes at up to 15.2 m/s, the hull averages 11.91 m of draught and tilts
  0.97 degrees at the worst.

**It can fail, and was made to.** Each mutant was built into the single library, and the
source was put back and checked against the committed file by SHA-256:
- the island moved to port failed the island's side, its deck edge, and the aeroplane on its
  roof (which stood at 18.50 against 42.50);
- the pilot's seat typed at the old `(26, 11, 20)` failed the helm's room;
- the deck 5 m higher failed its height, 23.50 against 18.5.

**What else it holds, measured on the merged source:**
- **Heads.** No seated head, nor a head's width round the eye, is inside a part the physics calls
  solid.
- **Gunners' arcs.** Each 12.7 mm gunner's clear arc from their tub, a level round swept a degree
  at a time across the mount's 298 degrees against the solid parts: 168 degrees from the
  starboard bow tub and 163 from the port quarter tub, with pitch -0.5 to +1.1 rad.
- **A touchdown.** An aeroplane brought down onto the aft deck of the carrier at 15.2 m/s,
  22 m/s over the ship and sinking at 1.5 m/s with its pilot on the brakes. It rolls 24 m and
  stops at 0.10 m/s against the deck, standing on it.

**What the compound hull costs.** `tests/deck_cost_probe.gd`, headless, stock editor, main's
library (107c3f52, the old box carrier) and the carrier lane's (b2240f78, fifteen parts),
interleaved A/B/A/B, twenty batches of 120 ticks each, on a QUIET machine (2026-09-15 21:22,
the only other Godot running a headless test of another lane, the same at the start and the
end):

| | main | lane |
|---|---|---|
| the carrier under way alone | 0.007 / 0.007 ms a tick | 0.008 / 0.009 ms |
| with twelve aeroplanes parked on its deck | 0.036 / 0.036 ms | 0.040 / 0.041 ms |

About 0.004 to 0.005 ms a tick for fourteen convex hulls under twelve aeroplanes, one worst batch
of 0.054 ms, and all twelve stayed on the deck in every run. The first figure written here,
"about 0.002 ms", was the same probe run while other lanes ran their suites; their load
flattened the difference.

**What the first pictures got wrong** (`tests/ship_shot.gd`, 2026-09-15). All three were green
in every suite:
- **A light-grey flight deck.** A vertex colour is taken as linear unless the material says
  `vertex_color_is_srgb`, so a 0.19 non-skid was drawn at about 0.47.
- **A deck shaded like a wing and a hull like a pill from overhead.** `generate_normals` averages
  across every corner it welds, so the prisms are now built by `Plating`, a normal per face.
- **The overhead camera came out with the bow to the right.** Looking straight down, a camera's yaw
  is whatever horizontal remainder the ship's roll leaves. The eye now leans 60 m aft and looks
  at midships; aiming it at a point 60 m forward did the same job and cut the stern off.

The helm picture also READ as a few metres above the deck, though its own deck edges put the eye
13.5 m above it. With no markings and smooth shading, nothing in the frame gave a scale. So the
probe prints the eye's height beside every helm picture and adds a view 30 degrees down over the
bow.

### How deep a ship floats, from the parts

A ship's DRAUGHT, how far its keel is below the sea when it floats at rest, has no key of its own.
It is `kind_geometry`'s `waterline` less the lowest `bottom` of the kind's `hull` parts. A kind
that is still one centred box has its bottom at `-extents.y` and floats with the sea `kSinkAtRest`
(0.625 m) above its centre, so the same formula covers both:

    draught = waterline - (the lowest hull-part bottom, or -extents.y for a kind with no parts)

On 2026-09-15:
- the carrier, 11.9 m;
- the gunboat's box, 1.2 + 0.625 = 1.8 m;
- the launch's box, 0.55 + 0.625 = 1.2 m;
- the battleship's box, 9 + 0.625 = 9.6 m.

cockpit-terrain's `Terrain.ship_depth(kind)` reads it this way for `open_sea_near`, so a ship is only
put where the sea is deeper than its keel. A `keel` key was proposed and not added: it would be a
second number beside the parts it is computed from.

### The carrier, near and far

`ShipHull.dress(kind, geometry)` is what `VehicleView` hangs off a ship with parts. It holds two meshes:
- a `Far` mesh, the parts as prisms in one draw call (`far_mesh`);
- for a ship that has one, a `Near` model with its paint, fittings and bridge (`Carrier.build`).

Godot's visibility ranges swap them at `ShipHull.NEAR_TO`, with `MARGIN` of overlap, so the swap
does not flicker at the boundary. Both are built once per kind and cached, and the nodes carry no
script, so a ship's detail costs nothing per frame and every launch shares one mesh.

**Everything is welded into one vertex-coloured mesh** by two builders:
- `Plating`: boxes, painted lines, prisms, walls, and quads wound to face a given way.
- `HullLoft`: the hull as stations along the `hull` part's outline, fining to a raked stem and a
  cut-up stern, with a black boot-top at the waterline and antifouling red below it.

Paint lies `Carrier.PAINT_UP` above the deck. Every position comes from the parts or from
`CarrierPlan`; a size that is in neither belongs to a fitting, and says where it came from.

**What the near model has:**
- the lofted hull and the deck parts;
- the hangar openings under the elevators and at the fantail;
- the landing area: its edges, a dashed centreline, a red-and-white foul line outboard of its
  starboard edge, the rubber between the wires, and the ramp striped at the round-down;
- four catapult tracks, each with its shuttle line and its blast deflector lying in its recess;
- three wires on sheaves;
- the elevators, edged in yellow;
- the hull number 78, on the bow and on both sides of the island;
- the island's blocks, its glazed navigation bridge (`Wheelhouse`), Pri-Fly's window band, six
  Dual Band Radar faces and the mast;
- two Mk 29, two Mk 49 and three Phalanx on sponsons;
- the two gun tubs and the LSO platform.

WHERE the weapons and the radar faces stand is UNVERIFIED: no source reached places them, and each
one says so beside it.

**Measured** on 2026-09-15. Headless, `tests/ship_models.gd`:
- the near model is 17 surfaces and 7,546 triangles, against a budget of 60 and 250,000;
- the silhouette is 1 surface, against 5;
- not one face is wound against its normal: 0 of 2,818 near, 0 of 196 far;
- from the pilot's and the copilot's eyes the bow and the deck ahead are in sight;
- nothing is within 0.25 m of either head.

In a real frame, windowed with `tests/ship_shot.gd` on PLAIN, the carrier adds 34 draw calls and
15,092 primitives at 500 m (the near model), and 17 and 4,924 at 3 km (the silhouette), shadows
included.

**The bow check failed first, for the copilot, and the check was wrong.** A window post stood exactly
on the line from the copilot's eye to the bow. The check allowed for that by moving its TARGET a
hundredth of the range: 2 m at the bow, a millimetre at the glass, so every ray of its bundle hit the
same post. It now moves the EYE 12 cm either side and 5 cm up and down, which is how far a seated head
moves. It still fails for a real obstruction: with the sill raised to 1.6 m, above a seated eye, all
four views went red, and `wheelhouse.gd` was put back by SHA-256.

**And the posts were pillars.** Built as wall strips, a post took a wall's 14 cm both ways, and from
1.2 m behind the glass it was seven degrees of solid in front of the bow. A post is now a 7 cm mullion
along the glass.

### Every boat's crew stands where its helm really is

Asked for on 2026-09-15: "the pilot seats should be higher and part of the boat as well". Every boat seated its crew on
the top of a box, with nothing round them:
- the launch's driver on a hull roof 0.55 m up;
- the patrol boat's on a roof 1.2 m up;
- the battleship's on its forecastle, in the open, 25 m forward of any superstructure.

Each boat is now built from parts, as the carrier is, with its origin on its design waterline, and each helm is placed
with `seat_in` on the floor of a `bridge` part (numbers from `research-boats.md` in the drafts folder):

| boat | the helm | floor above the water | status |
|---|---|---|---|
| launch | a centre console under a T-top, the roof at 2.2 m | 0.30 m | sizes CONFIRMED for 5.5-5.9 m RIBs; the T-top SINGLE |
| patrol boat | a US Navy PCF "Swift boat"'s wheelhouse, scaled to this boat's 18 m | 1.00 m | ESTIMATE |
| battleship | an Iowa's pilot house on the 04 level, round the conning tower | 15.9 m | ESTIMATE |
| carrier | the Ford's navigation bridge, on the island's forward face | 30.65 m | ESTIMATE |

**EVERY SEAT KEEPS ITS INDEX, ITS ROLE AND ITS FACING.** The crew page lists seats by role, a JOIN names a seat by index,
and a gunner's mount is counted in seat order (`mount_of_seat`). A launch is still pilot, copilot, a bench and a stern
seat facing aft; a patrol boat pilot, bow gun, stern gun facing aft, copilot; a battleship pilot, copilot, two gunners.
Only where they stand moved. The masses did not change either, because the handling is tuned to them.

**AN OPEN HELM IS THE CATALOGUE'S TO SAY.** `VehicleCatalogue.helm(kind)` is "glazed" -- a `Wheelhouse` behind windows --
for every ship but the launch, which is "open": a console at the knees with a low windscreen, four posts and a T-top
roof. It is presentation beside the paint; a room's size was rejected as the rule, since a small wheelhouse and a big
T-top are the same size.

**`Superstructure`** draws any ship with parts but no model of its own: its hull lofted along the hull part's outline,
its decks and superstructure as prisms, a helm room round every bridge part and a waist-high tub round every gun
station. The carrier keeps `Carrier`; `ShipHull.dress(kind, geometry)` chooses.

**`tests/boat_seats.gd`** holds for all four boats:
- built from parts;
- seats in their old order, roles and facing;
- every helm on a bridge floor with the eye under its roof, every gunner on a station floor;
- no seated head inside a solid part;
- the draught from the parts equal to the research's (0.40, 1.74, 11.33 and 11.9 m);
- a minute stopped on the swell at that draught, and upright.

On main's library, where the three boats had no parts, it failed `the_boat/gunboat/battleship_is_built_from_parts`, and
`ship_models` failed their silhouettes.

Measured on lane/carrier's library (double editor, 2026-09-15). Over 160 samples of a minute on the swell, each
origin sat on average 0.14 m (launch), 0.13 m (patrol boat), -0.10 m (battleship) and 0.05 m (carrier) from the sea,
heeling at worst 2.18, 0.89, 0.51 and 0.67 degrees against 12, 6, 2 and 2. `ship_models` puts the helm's eye 1.65,
2.35, 17.25 and 32.0 m over each origin, sees the bow and the deck ahead from both helm seats with the eye leaned
12 cm and 5 cm, and finds nothing within the head's 25 cm.

**A ROOM'S GLAZING FITS THE ROOM.** `Wheelhouse` put the header over its windows at a fixed 2.35 m; the patrol boat's
room is 2.0 m, so the strip between header and roof had a negative height and drew inside out (24 of 1,294 faces in
`ship_models`) with the posts through the roof. The header now stops 10 cm under a low roof. **A windscreen is a
frame**: the launch's solid pane stood across the seated helm's line to its foredeck, 1.14 m above the floor.

**A MODEL IS WHOLE**, which two pictures found and every suite passed, and `ship_models` now holds. Under every helm seat
an upward face lies between the room's floor and 35 cm under it: the launch's hull was lofted with no top and its helm
stood over the sea, so `Superstructure` plates every hull's top 2 cm under the sheer (under a wheelhouse floor laid on
the deck, never fighting it). And a line in from starboard just under the waterline meets the skin every 2 m of the
middle 70% of the ship: the battleship's two hull lengths each fined away at their joint and left a 12 m gap at the
forecastle's break, so a length fines only at an end that is the ship's bow or stern.

It can fail. Typing the patrol boat's pilot back at its old roof seat, and moving the battleship's pilot house 40 m aft
with its seat typed where the house used to be, each turned `boat_seats` red on
`every_<ship>_helm_is_on_its_bridge_and_every_gunner_in_a_tub`.

### Every boat has a model of its own

Step 3 put every boat's crew in a room that is part of the boat; step 4 gives the boats that were drawn only from their
parts a model of their own, as the carrier has had since step 2. `ShipHull.models` dispatches on the shape table's name:
`Carrier`, `Battleship`, `PatrolBoat`, `Launch`, and `Superstructure` for any other ship with parts. Each builder draws its parts with `Superstructure.build_into` first and its own fittings into the same
`SurfaceTool`, so a ship is still one mesh, and each is handed the helm the catalogue says its kind has
(`VehicleCatalogue.helm`) rather than typing it.

| boat | what its model adds | how sure |
|---|---|---|
| patrol boat | a rub strake round the hull, rails round the foredeck, a radar dome forward of the mast, two whip antennas, a searchlight, an anchor | ESTIMATE, sized to the boat |
| battleship | three triple 16-inch turrets (turret 2 on a barbette), the refit's six twin 5-inch mounts with their barrels laid fore-and-aft, the Tomahawk box launchers and Harpoon racks, four Phalanx mounts, a teak deck, the fantail's helicopter pad | turret places SINGLE (Slover); trunnion 2.5 m over its deck, barbette 2.6 m, mount places ESTIMATE |
| launch | tubes 0.5 m across inside the 2.4 m hull with an orange band and a grab line, an outboard, a double jockey seat under the seats that fly, an all-round white on the T-top | tube size and beam CONFIRMED; heights ESTIMATE |

**A FITTING STANDS ON THE PART UNDER IT, AND IS NEVER TYPED A HEIGHT.** `Superstructure.top_under(parts, at)` is the
highest top of any hull, deck or island part under a plan point; a fitting on a room's floor or roof asks that bridge part
by name, because a room's top is its roof -- asked for "the highest thing under it", the launch's jockey seat stood on its
T-top. The drafts typed their heights. The launch's tubes were drawn outboard of the collided hull and made it 3.4 m wide
round a 2.4 m collision; the patrol boat's radar dome sat where its collided mast stands; and the battleship's, typed
from the research over step 3's decks, put turret 1 and two 5-inch mounts inside the forecastle and its forward Phalanx
10 m up in the air.

**`tests/ship_models.gd` holds three more things.** Every fitting a model reports stands on the ship: its foot within
6 cm of the top of a hull, deck, island or bridge part under its middle, and that middle inside no hull, deck or island
part. A ship with a model of its own that reports no fittings fails rather than passing unchecked. The helm's "bow" target
is 4 m aft of the stem or 15% of the way from the stem to the eye, whichever is nearer the stem: on the 5.6 m launch 4 m
was behind its helm, and "the bow is in sight" passed whatever stood in front of it. And a blocked view names the first
panel on its straight line, so a failure says what it is fixed by. Solid fittings -- the radar dome, the jockey cushion,
and in 4b the battleship's turrets and mounts -- are panels, so the helm's view is checked against them.

**THE BATTLESHIP'S DECK IS STAIRS (step 4b).** Stood on step 3's shape, every one of its fittings was on the ship and its
helm could not see the forecastle: turret 2's gunhouse, AABB (-6.5, 11.7, -50.5) by (13, 4.2, 11), was 9.4 m in front of
the pilot house on the line to the deck ahead. The shape had a forecastle break at z -20 and a flat deck at 9.1 m forward
of it; the research has a near-flush deck about 5.5 m up under turrets 1 and 2 -- Slover's trunnions are 7.97 = 5.5 + 2.5
and 10.56 = 5.5 + 2.6 + 2.5 -- rising to 9.1 m only at the bow. A part is a prism with a flat top, so `battleship_shape`'s
sheer is four lengths: 9.1 m to z -100, 7.3 m to z -78, 5.5 m under both forward turrets to z -20, and the main deck's
5.9 m aft; the keel is the same in each, so the draught and the float did not move, and the forward superstructure's foot
came down to 5.5 m with the deck it stands on. The turrets now come out, stood on the part under them and never typed,
at trunnions 8.0, 10.6 and 8.4 m against Slover's 7.97, 10.56 and 8.66, and both helm seats see the bow and the deck ahead.
The mutants: the turret lengths put back flat at 9.1 m hide the deck ahead from the pilot house again, and turret 1 typed on
the old 9.1 m forecastle stands on nothing. Not Slover's 7.97 less 2.5: on the lowered deck that is 3 cm off, inside the
6 cm a foot is allowed, and a mutant typed there stays green.

Measured on the double editor (2026-09-15). The patrol boat's near model is 6,328 triangles in 17 surfaces, 0 of its
1,600 faces wound inwards, with 11 fittings on the ship; the launch's is 11,466 triangles in 5 surfaces, 0 of 1,482 faces
inwards, with 2 fittings. The helm's bow target moved to 3.2 m aft of the patrol boat's stem and 0.56 m aft of the
launch's, and both helm seats of each still see it. The battleship's near model is 9,798 triangles in 17 surfaces,
0 of 5,070 faces wound inwards, with 19 fittings on the ship, and at 500 m it costs 35 draw calls and 24,606 primitives (the stock editor, 1600x900, on the island). Drawn on the double editor at 1600x900, a patrol boat
at 500 m costs 48 draw calls and 18,948 primitives, and a launch 15 and 34,330: the launch's tubes and loft are most of
its triangles, and the forty-four launches in the world share its one mesh.

**NOT HERE YET.** The boats' own lights: the launch's all-round white is drawn and unlit, and the patrol boat has none. A
wake. The patrol boat's roof tub for the twin .50 (the shape has no station there). The battleship's turrets do not train:
they are drawn, and its gunners are the two 12.7 mm tubs.

### Two merchant ships, at their real size, and a draft table on a clock

The fleet was warships and small craft; it has a **very large crude carrier** and a **wave-piercing catamaran ferry** in
it now (cockpit-fleet3, 2026-09-17), each modelled on one real named vessel with its published dimensions, and each drawn
as the SHIP TYPE: no operator's livery, funnel mark or name. The sheets are `craft/crude_carrier/sources.md` and
`craft/ferry/sources.md`, which carry every figure with its source and every measurement with its method.

| | crude carrier | ferry |
|---|---|---|
| reference | MV Sirius Star, IMO 9384198 (DSME, 2008) | HSC Express 3, IMO 9793064 (Incat hull 088, 2017) |
| PUBLISHED | 332 m x 60 m, 22.5 m draught, 31 m deep | 109.40 m x 30.50 m, 3.93 m draught, 9.20 m deep |
| mass in the game | 10,000 t, the capital-ship cap | 2,800 t, real scale (ESTIMATE) |
| near model | 8,054 triangles, 1 draw call | 3,154 triangles, 1 draw call |
| silhouette | 208 triangles, 1 draw call | 108 triangles, 1 draw call |

**BOTH FIT THE SEAS AT FULL SIZE, and the VLCC is the reason to check rather than assume**: it is 332 m against the
Ford's 333, and its leg needs its 22.5 m draught plus `kKeelClearance`, which every leg off the island has three times
over at the seabed's 150 m. Nothing had to be scaled down.

**THE SHAPES ARE DRAFTS IN GDSCRIPT UNTIL THE KINDS ARE C++.** `crude_carrier` (25) and `ferry` (26) are queued for the
C++ lane, and a model needs a ship to be drawn from now, so `CrudeCarrierDraft` and `FerryDraft` hold `kind_geometry`'s own
dictionary, part for part what each `*_shape()` will list. That is two copies of one shape, which is the thing rule 4
forbids, so it is on a clock: `tests/merchant_models.gd` fails the day the simulation names a kind `crude_carrier` or
`ferry` while the GDScript copy still exists. (The wire's kind field has since gone to sixteen bits, so a kind's number
is no longer the limit it was here: lane/kinds, 2026-09-18.)

**`HullLoft` takes an axis and a palette now.** A catamaran's demihull is not on the centreline, and a merchant hull is
not haze grey. Both defaults take the path the function had before rather than an equal one -- an offset of 0 added to a
vertex turns -0.0 into +0.0 -- and every warship's mesh was checked to the byte, SHA-256 over vertices, normals and
colours, identical before and after, with a mutant nudging the default bottom paint turning four of the five red.

**What the suite holds, from the DRAWN VERTICES and against the sheets, within 2 %:** length, beam, draught and depth;
the tanker's house front 77 m forward of the stern, its bridge deck, wheelhouse roof, funnel top and masthead over the
cargo deck; the ferry's sheer, roof, wheelhouse roof, masthead, wet deck and centre-bow forefoot over the water. And two
checks that are about what the ship IS rather than how big it is: **the ferry has two hulls with a tunnel between them**
(nothing drawn under the water within half a tunnel of the centreline, skin out past 14 m both sides -- a monohull passes
every size check and fails this one), and **nothing but rails stands on the tanker's forecastle**.

**The traps, each paid for:**

- **A size typed in metres beside a shape that owns it is a size that stops following it.** The tanker's loft rows said
  -22.5 whatever the shape's keel was; the mutant that changed the draught moved the part and left the drawn hull behind.
  Rows are shares of the part's own keel now, and so are the bulb, rudder and screw.
- **Handed a keel instead of a draught, two minus signs put the bulb 13 m OVER the bow** -- and every size check stayed
  green, because a bulb in the air is well inside the ship's own box. The check that catches it allows the deck's rail
  and cuts out the foremast's column; its first version allowed anything under the foremast's 12 m and was green against
  that very bug.
- **A quad is two triangles, and a point exactly on the diagonal is inside neither.** `point_is_inside_triangle` said no
  to both halves of the ferry's wheelhouse roof, whose diagonal runs through the middle of the room, and the check read
  the deck 3.3 m below. Face probes sample a small cross.
- **Eight corners to a part cannot hold a VLCC's entry.** With one length forward the ship read as a barge in plan; the
  hull is four lengths -- stem, shoulder, parallel body, afterbody -- which is four points a side to the shoulder.
- **A loft has no top across it.** Where a superstructure stands inboard of the ship's side, the strip of sheer between
  them is a hole into the hull unless it is plated.
- **A branch that asks "is it forward of a quarter of the ship" will be true of things it did not mean.** The ferry's
  cross structure and superstructure were painted the centre bow's dark grey, and from ahead the ship was a black slab.
  Which part a thing is follows from where its floor is.
- **The mast at the bow hides the bow.** The tanker's foremast, drawn 14 m abaft the stem, stood on the centreline
  between the wheelhouse and the helm's bow target. The photographs have it at the stem head.

**Pictures, and a probe of their own.** `tests/merchant_shot.gd` stands a ship in a plain studio -- a sky, one sun and a
flat sea at the waterline -- because nothing places a kind that does not exist, so `ship_shot` cannot photograph these
yet. It takes true elevations on the waterline datum for overlaying on the references, a perspective camera put where the
reference photograph's was, the ship beside the Ford, and the view from the helm. When the kinds land, `ship_shot` takes
over and these ships go into it.

**NOT HERE YET:** the C++ kinds, their handling and their buoyancy (the ferry's four probes land at 11.4 m, inside its
demihulls, so no probe change is proposed until a suite measures the roll); the ships in a level; a ferry that shuttles
between two harbours rather than taking the boat pool's waypoints; lights, wakes and the tanker's cargo lights.

### A ship sounds every leg it chooses

Every boat kind -- carrier, battleship, gunboat, launch -- chose its next leg by boxes alone (`choose_waypoint`), and on
the generated ground that is not enough: the capital ships fly a pool filtered for a launch's depth, and on the alpine
world every leg the carrier and the battleship chose in four minutes crossed land. A ship on such a leg drove it. The
carrier sailed up the shelf at 10 m/s, lifting smoothly out of the water -- no clamp, the largest one-second rise 0.73 m --
and sat beached with its origin 10.31 m out of the water, heeled 5.7 degrees, its route still set (2026-09-15, 3490529c's
library). The island never showed it: its sea has no floor.

**A BOAT SOUNDS ITS LEG AGAINST ITS OWN NEED.** `choose_waypoint` sounds a boat's candidate with `sea_leg_is_deep`, as the
brig's sailor has since pirate step 3. The need is the kind's draught (`draught_of`) and `kKeelClearance`.
**And it tries every point of its pool once**, from a start the seed picks, ahead first and then anywhere; an aircraft
keeps eight random tries a pass, since any clear leg serves it. Eight random tries was the brigs' trap again (below, "THE
POOL ON THE GENERATED GROUND LIES ALONG A SHELF"): on the generated ground the submarine's spawn had 1 of its 24 points a
leg away with its 11.84 m need the whole way, it had chosen no leg when terrain_level looked, and `kSailRetry`'s 15 s
comes after that look (cockpit-fleet step 4). Trying every point, 30 of 30 independents there have a leg. **What it
costs:** each try sounds its leg, and a decision on alpine's biggest ship pool costs at worst 1.37 ms of soundings (the
boats' 29 points twice through the binding from the worst start, the box sweep not counted; `tests/ship_legs.gd` prints
it). In play legs end at different times; at spawn every boat chooses on the same tick, so that tick can spike. Not moved
yet: if a spawn hitch is ever seen, the choice goes onto the AI rota's per-tick budget, as the wings' look and the sailor are.

**TWO KEEL ROOMS, ON PURPOSE.** A RESTING PLACE -- a spawn, a pool point -- needs its draught and terrain's SHIP_KEEL_ROOM,
8 m (`Terrain.ship_depth`). A LEG UNDER WAY needs its draught and the sailor's `kKeelClearance`, 3 m. The brig used both
first; the pool is the stricter test, so every point kept is deeper than a leg's need there, and a point kept can still
have no deep leg to another (shallows between), which is why the whole line is sounded.

**ONE DRAUGHT.** `draught_of` is `Terrain.ship_depth`'s formula to the bit: the kind's waterline less the first hull part's
bottom, min'd with every later one, or less -extents.y with no hull part. `ai_leg_rules(kind)` gives it as "draught" and
the leg's need as "need"; terrain.gd will read "draught" instead of working it out, and tests/ship_legs.gd holds the two
equal to a millionth of a metre so that swap moves nothing.

**THE KEEL CLEARANCE IS HELD BY A LEG BUILT BY HAND.** The level's traffic never chooses a leg whose water lies between
a ship's draught and its need -- after the fix the carrier's shallowest was 20.00 m against 14.90 -- so dropping the 3 m
passed every traffic check. And `ai_leg_rules` first worked "need" out beside `leg_need` instead of asking it, so a
`leg_need` that dropped the clearance changed nothing a test could read. Now "need" IS `leg_need` for a boat, and
"keel_clearance" is exported; ship_legs holds need == draught + keel_clearance, all three asked of the simulation, and
sweeps alpine round the carrier's spawn for a straight leg whose shallowest sounding lies strictly between the carrier's
draught and need, printing it, and holds `sea_leg_is_deep` refusing it at the need and taking it at the draught.
On alpine the sweep of 62 points round the carrier's spawn found one: (-8938.0, 17384.0) -> (-8867.3, 17454.7), its
shallowest 13.32 m between the carrier's 11.90 m draught and 14.90 m need (2026-09-15).

**NO LEG: WAIT, AND STOP.** A boat that sounds the pool and finds no deep leg waits `kSailRetry` (15 s) before sounding
again -- asked every tick it sounded sixteen legs a tick at 120 Hz -- and while it has no leg it wants 0 speed, which its
speed loop brakes to and never reverses; it used to hold its heading at cruise, which is how the carrier beached. Its
patience starts at 0 and only a leg taken sets it, so a boat just spawned, arrived or giving a leg up chooses at once.

Measured with the same probes on the same level before and after (240 s of legs sounded every 25 m on each world, 300 s
of the alpine world followed once a second; the level is deterministic, and 3490529c's and 73b0c456's libraries matched to
the coordinate). ON ALPINE, BEFORE: every leg the carrier (3) and the battleship (2) chose crossed land, and 4 of the
launches' 8; the carrier was aground 229 of 300 seconds and beached 10.31 m up, the battleship 14 seconds and climbing.
AFTER: carrier 3 legs, battleship 3, launches 8, none shallower than its need, the shallowest 20.00, 19.56 and 10.36 m;
neither capital ship aground for a second, the carrier's origin at most 1.21 m over the sea on the swell. No driven ship
waited for a leg on either world. The island's numbers did not change: its sea has no floor.

**`tests/ship_legs.gd`** flies every world the desk offers the way a player does (the level's button, "Fly on your own",
MAIN MENU back), and for each kind in `DRIVEN` -- carrier, battleship, launch -- holds every leg chosen to have its need the
whole way (sounded every 25 m, a quarter of the simulation's step, so it is not the fix run twice; a kind that chose no leg
fails) and no driven ship a second aground; it reports how long each kind waited with no leg, so a ship idling at its spawn
is seen. The gunboats are parked spawns, not traffic: `the_<world>_level_drives_no_gunboat` holds that, so a level that
starts driving them fails and adds a row instead of passing as "none shallow". cockpit-fleet adds the submarine to
`DRIVEN` at its step 1.

**NOT HERE YET.** A ship that is ALREADY aground -- put on the shelf by a spawn, or pushed there -- is not refloated: it
stops and waits. The sounding is the leg's straight line; a ship steering to it does not sound the water ahead as the sailor
does (`shallowest_ahead`), because a boat's leg is sailed straight and sounded before it is taken.

### One constant sank three ships and looked like four bugs

`buoyancy` was a single number, 26 kN, in a table with a row per kind -- typed in once for
the 900 kg launch and never revisited. The gunboat weighs 137 kN, the battleship 57 MN and
the carrier 98 MN, so all three went straight to the seabed, and only the launch ever
floated well enough to hide it.

The carrier taking its own flight deck down is what made this look like an undercarriage
problem. An aeroplane placed on the deck fell 140 m in five seconds -- the textbook distance
for free fall, which is why it read as "the undercarriage never runs" -- and it was not
falling at all. The ship was, and the aeroplane was sitting on it the whole way down.

**Buoyancy is now derived from mass**, in the constructor, 1.6x weight for every kind. A
hull settles with about a third of a metre of draught and pushes back harder the deeper it
is pressed. A number that must agree with another number should be computed from it: this
is the same lesson as the drawn geometry reading `kind_geometry` rather than keeping its own
copy of every hull size.

`every_hull_floats_not_just_the_smallest` spawns one of each of the four hulls and looks at
where they are six seconds later, because one boat passing proves nothing about the others.

### A small boat leans into its turn and lifts its bow onto the plane (lane/boats, 2026-09-18)

Asked for by the user: "they should be able to go a bit faster, and lean into their turns a bit (which happens in real
life). I want some more juice in the small boats." A planing hull banks INTO a turn, like a motorcycle: the inside chine
digs in and the outside lifts. None of ours did -- the launch settled 0.3 degrees into a full-rudder turn and the patrol
boat 0.8 degrees OUT.

**`plane_the_hull` moves the hull's equilibrium; it does not command an attitude.** The hull's stiffness in roll and pitch
is what its float probes and `righting` already give it -- `buoyancy x reach^2 / 2 + righting`, LESS `weight x drop`,
because the probes push up under the centre of mass and heeled they swing out and push it further over (the flying boat's
lesson in `alight`). A steady moment of that stiffness times an angle makes the angle where the hull rests, so the boat
settles there on its own springs, rides the swell on top of it, and comes upright the moment the turn ends. The angle is
`lean` radians per g of the turn the hull is actually making (speed x yaw rate, capped at one g), so it grows with speed
and rudder and needs no switch; `bow_rise` is the hump, most at half `plane_speed` with the throttle open. Every ship has
both at zero and returns before a force is touched. **Leaving out the drop leaned the launch 35 degrees where 17 was
asked.**

**Keep `lean` where the probes are linear.** A probe's push is capped at one metre of depth; past about 0.15 on the
patrol boat the inside probe reaches it, the hull loses stiffness, and the lean runs on -- 0.18 leaned it 24 degrees
where 0.15 leans it 9. The same cap stood its bow 12.6 degrees up at a `bow_rise` of 0.10 (its probes are 6.8 m out, so
bow and stern saturate first). A carrier handed the launch's kind of number (`--set=lean=3`) capsized in `handling`.

Measured through the helm (`tests/handling.gd`, which gates it; `tests/boat_shot.gd` photographs it, with `--before`):

| | top | 0-90% | full-rudder circle | lean into the turn | bow rise |
|---|---|---|---|---|---|
| launch before | 18.0 m/s | 2.2 s | 60 m | +0.3 | 2.0 |
| launch after | 25.1 m/s (49 kt) | 2.8 s | 67 m, 38 deg/s | **+12.8** | 4.6 |
| patrol boat before | 22.0 m/s | 3.3 s | 274 m | -0.8 | 2.7 |
| patrol boat after | 24.0 m/s (47 kt) | 3.3 s | **102 m**, 26 deg/s | **+9.0** | 3.5 |

Both now pass the 80 km/h at which a hull throws spray. **Which hull must lean is its displacement** (under 100 t), never
the `lean` in its handling: the first draft of the gate read the number it was checking, and zeroing the launch's lean
moved it quietly onto the ship gate and passed. The carrier settles 2.4 degrees INTO its turn, as it always did (it
heels 5 out as the turn starts); the ship gate holds every ship under 4.

### A fireboat, and the word is MONITOR (lane/fireboat, 2026-09-20)

`Sim.Kind.FIREBOAT`, the fireboat, kind 37: the FDNY *Three Forty Three* at her published 42.67 m by 10.97 m, 2.74 m
of draught and 500 t (`fireboat_shape`; sources and what is MEASURED in `craft/fireboat/sources.md`), drawn by
`Fireboat` -- red hull, white upperworks, an open foredeck inside a bulwark, and four raked stacks on the casing.
**Five seats**, two helms and one operator per monitor, which makes her the first craft here past four.

**A fireboat's "water gun" is a MONITOR** -- a deluge gun; a hose is the flexible thing a firefighter carries. She
has three, two forward and one aft, as the user asked; the real boat has eleven.

**THE THREE MONITORS ARE THE THREE TURRET MOUNTS, and that is why they cost nothing on the wire.** `kMaxTurrets` is 3
and `CraftSystems.turret_yaw/pitch` has carried three aims since the gunship -- replicated, rolled back and
interpolated -- with turret seats taking mounts in seat order. A monitor is a `Gun` in that table's terms: a place, a
barrel, train and elevation limits, a slew rate, and a `muzzle` which for water is the nozzle's exit velocity.

**`Gun::water` IS WHAT STOPS ONE FIRING, IN `fire_round` AND NOT AT THE SEAT.** A turret seat's trigger reaches
`fire_round` unconditionally, so without it the first pull puts tracer out of a fire hose. The gate was written at
the seat's dispatch first, which is wrong and is the general lesson: **`fire_gun` and `fire_gun_pulled` are bound
straight to GDScript and arrive without a seat.** A refusal belongs at the authority, not at one of its callers.

**THE MUZZLE SPEED IS DERIVED.** A monitor runs at 7–12 bar ([W] Wikipedia, "Deluge gun"); `sqrt(2 dP/rho)` at 12 bar
is **49.0 m/s**, and drag-free `v^2/2g` is 122.4 m = 401 ft against a published "400 ft in the air". Two sources that
never met, agreeing to a foot -- which also settles that the 400 ft figure is drag-free arithmetic and not a throw
anybody measured. Against the other published figure, a 320 ft horizontal throw, the real reach is **66 m** and the
best elevation **35 degrees rather than 45**, which is drag moving the optimum and is a prediction nobody typed.

**THE STREAM IS THROWN ONCE AND FLOWN BY THE GPU** (`MonitorYard`, `water_jet.gdshader`), which is `SprayYard`'s
decision: one instance per flowing monitor every twenty-fifth of a second, carrying the two ends' launch points,
their launch times and the launch velocity, and never touched again. **That is also why the stream whips when a
monitor is trained** -- water already thrown keeps the velocity it left with, so the nozzle sweeps a curve through
the air instead of snapping the arc across. An arc recomputed each frame from the current aim cannot do it at all.

**THE DRAG LAW IS LINEAR BECAUSE IT IS THE ONLY ONE WITH A CLOSED FORM**, and it was checked before it was chosen:
fitted to the published horizontal throw it gives a vertical reach of 66.0 m where a quadratic law fitted to the same
figure gives 65.9. The same constant is handed to the shader and used by the dousing, from one place, because a
stream drawn along one arc and a fire doused along another is two answers about where the water went.

**THE FIRE IS THE SIMULATION'S OWN.** `FireState` already carried x, y AND z, so a fire sits on a module 26 m up
with no wire change; `light_fire` was bound; `FireYard` already drew flame, a smoke column and embers. What was
added is `work_the_monitors`, which follows each flowing stream **along its whole flight** and takes strength off any
fire it passes THROUGH -- not at an impact point, because a stream thrown over a burning module passes through the
flame on the way down. Its radius is 8 m where the water bomber's is 22: a bomber asks a pilot to put a falling load
on a fire from a run, and a monitor is a nozzle somebody aims.

**`aim_gun` AND `set_monitor` ARE THE SERVER'S WAY TO WORK A MOUNT**, the same thing `fire_gun` already was, so an
unmanned boat can fight a fire and three monitors do not need three players before anybody sees water. Both go
through the same stops as a gunner's stick (`hold_the_stops`, pulled out of `work_the_turrets` so the two cannot
disagree).

**AND THE BUG NOTHING COULD SEE, WHICH IS THE ONE TO REMEMBER.** `CraftSystems`' serializer wrote
`flags & kOutsideFlags` in a **hard-coded four bits** -- exactly right while the mask was `0x000D`. Widening the mask
to carry three pump bits compiled, asserted, replicated and drew, and the new bits were dropped on the way to the
wire: the boat pumped on the server and every client saw her monitors shut. **Nothing was red; the picture was
simply empty.** The mask and the width were two copies of one fact, and `bits_for_flags` makes them one. Anyone
adding an outside switch was walking into this.

**Her four stacks are `exhaust_ports`**, which is why `tests/exhaust.gd`'s ratchet stayed at 29 rather than going to
30 -- and no ship could declare an exhaust before her, because `ShipHull.dress` builds a scriptless node and
`VehicleView` asks airframe *objects*. A ship's ports now ride back with its mesh through `ShipHull.models`' existing
dispatch, so any ship can grow a funnel without a second roster of names.

### A CB90 fast assault craft: two guns at the back and the light twin's missiles (lane/boats, 2026-09-18)

`Sim.Kind.CB90`, the cb90, kind 30 (the Prowler merged first as 29): a Swedish Stridsbåt 90 H at the Wikipedia infobox's 15.9 m by 3.8 m, 0.8 m of
draught and 15.3 t (`cb90_shape`; sources and what is ESTIMATE in `craft/cb90/sources.md`), drawn by `CombatBoat` from
its parts -- hard chines, the bow ramp, the waterjets, splinter camouflage and a missile box on the wheelhouse roof.
Four seats: the helm and the weapons officer in the wheelhouse, both able to steer and to lock and launch, and a gunner
at each of two 12.7 mm rail guns on the after deck (`ship_pintle_at`).

**Its missiles are the light twin's, through the light twin's code.** `loadout_of` gives it four rails, the heat pair
on the light twin's own heat row and the radar pair on **"sea radar"**: the light twin's radar row number for number,
with `ships`. So the lock is `work_the_seekers`', the missile `launch_from`'s and the cues MissileYard's; nothing about
targeting was written twice. **It locks aircraft and ships, and nothing on land** (the user, 2026-09-18: "not ground
targets but ships yes"). `MissileType::ships`, agreed with lane/apache as the one flag for this: a Boat target is seen
when `ships || ground`, cars, trains and buildings by `ground` alone. A new row rather than `ships` on the radar row, so
the light twin's missiles are exactly what they were (`tests/cb90.gd` holds both, and locks a patrol boat making 11.5
m/s 1.5 km off; the mutant without `ships` reads "searching"). Two things a boat needed that an aeroplane did not, both on the loadout and zero on every craft that had one:
`launcher_pitch`, because a seeker looking along a boat's bow sees an aircraft only when it is nearly on the water (the
CB90's box looks 11.5 degrees up, and `tests/cb90.gd` locks an aircraft 22 degrees over the horizon, which the radar's
20-degree cone along the bow cannot), and `kick_up`/`kick_ahead`, because a missile dropped 2 m/s off a boat's roof lands
in the sea: the box throws it out at 15 m/s along itself, and it is 19.5 m up a second later. The light twin still drops
its own 2.1 m/s off the rail (`tests/cb90.gd` holds it). The helm's WHEEL carries the stick's missile bindings when the
seat launches, and the lock sight is drawn along the launcher (`LockSight.look_along`).

Through the helm: 24.0 m/s (47 kt), an 81 m circle at 33 degrees a second, 8.6 degrees of lean into it. Its `lean` is
0.09 where the patrol boat's is 0.15: at 0.15 its floats saturated and it leaned 33.7 degrees.

**A hull on the water sprays by its length** (`WakeTuning.HULL_SPRAY_FULL_LENGTH`, the one knob): past the same 80 km/h, a
hull whose lowest point is in the water throws the wall at the strength its length over 24 m says -- 2.6 m behind the
launch, 7.3 m behind the CB90, 8.2 m behind the patrol boat, as the level's SprayYard measured them at top speed -- where
the aircraft's curve, full only at 45 m/s, gave every boat the same 0.38. Aircraft keep their curve. **And the full wall
is 11 m, where it was 15** (the user: "the splash size is a little high, make it a bit smaller"; `SHEET_HEIGHT`).

**No kind falls to a "hover hold" any more.** `default_bus`'s default added one to every kind without a case of its own,
so the gunboat, the train, the brig and the segway each carried a dial that meant nothing (lane/kinds' audit). The pod
has its own case now and the default adds nothing: regenerating the packages changed only those four kinds' DetentDial
and the CB90's new MfdPanel (its "radar page").

### A hull rides the sea: its probes damped at its own critical, the wind-sea averaged over it, and a fast boat held up by its speed (lane/seakeep, 2026-09-18)

Asked for by the user: "Boats are all over the place and bounce alot ... I want ships to bounce a little less and not go
under water so much, the CB90 dives too far down often."

**IT WAS ONE CONSTANT, AGAIN.** `float_the_hull` damped every probe at a flat 1,000 N s/m, typed for the 900 kg launch.
Every hull's probe spring is `buoyancy`, 1.6 weights a metre, so every hull heaves at the same 0.63 Hz, and the flat
damping was 0.56 of critical on the launch, 0.036 on the gunboat, 0.033 on the CB90 and nothing on a ship. The wind-sea is
standing, so a boat running along it at 22 m/s meets its 64, 44 and 28 m waves at 0.34, 0.50 and 0.79 Hz, right on that
resonance. And a probe only pushes and never pulls, so a boat with nothing to take the energy out was thrown off each
crest and driven through the next: the CB90 heaved over 5.69 m on a 2.8 m sea. This is "One constant sank three ships"
above, one level down. **Any per-hull force typed as a number rather than worked out from the hull is this bug waiting
for a bigger hull.**

**Three changes, all in `cockpit_world.cpp`:**
- **`probe_damping`**, worked out in the constructor beside `buoyancy`: `kHeaveDampingRatio` (1.0, critical) x
  2 sqrt(buoyancy x mass), shared four ways. Swept on the CB90 flat out: 0.6 gave 0.176 g at the helm, 0.8 0.146 and 1.0
  0.126, with the bow the same.
- **`sea_felt`**: each probe feels the wind-sea AVERAGED OVER THE HULL. Each wind wave is scaled by
  exp(-(k_along L/2)^2/6) x exp(-(k_across B/2)^2/6), a Gaussian with the box average's curvature at zero that never
  turns negative, using the hull's heading. The swell is left whole, and a long hull still floats on the swell alone
  (`sea_under`, unchanged). `sea_smoothing` (1 is the hull, 0 a point) is there for the mutant.
- **`plane_lift`**: a share of a fast boat's weight is carried by its planing bottom, as the speed squared up to
  `plane_speed`, and only while the hull is wet. 0.25 on the launch and the gunboat, zero on the CB90 and every ship.
  Swept 0.2 / 0.35 / 0.5 on the gunboat: the bow 0.56 / 0.63 / 0.69 m clear, at 0.16 / 0.19 / 0.21 g. Riding higher
  takes the probes out of the water more often, so **lift buys freeboard with bounce**, and more damping buys the bounce
  back. **And lift costs lean**: at 0.25 the CB90 leaned 5.8 degrees into a full-rudder turn where it leans 7.2 without,
  under `tests/handling.gd`'s 6, because its probes sit nearer their cap and the air. The CB90 needs none; its bow is
  0.34 m clear on the damping alone.
- **And the launch's and the gunboat's `lean` came up to pay for their lift**: at 0.15 the lift took the launch's lean into
  a full-rudder turn from 13.1 degrees to 9.1 and the gunboat's from 9.0 to 7.3. 0.20 and 0.18 put them at 13.4 and 9.2
  (`tests/handling.gd`). The gunboat ran away to 24 degrees at 0.18 before; critically damped, it does not.

Measured by `tests/seakeeping.gd` flat out along the waves (it prints the whole table: every powered hull, stopped, at
cruise and flat out, along the wind-sea and across it; a negative bow is that far clear):

| | CB90 before | after | gunboat before | after | launch before | after |
|---|---|---|---|---|---|---|
| heave, top to bottom | 4.97 m | 1.70 m | 3.79 m | 1.71 m | 2.16 m | 1.96 m |
| helm, g rms | 0.665 | 0.126 | 0.549 | 0.148 | 0.243 | 0.230 |
| pitch sd | 3.73 | 1.24 | 3.96 | 1.19 | 2.85 | 1.85 |
| bow under the drawn sea | 1.60 m | -0.34 m | 0.73 m | -0.55 m | 0.28 m | 0.18 m |
| dives a minute | 15 | 0 | 3 | 0 | 1 | 0 |

The carrier lying stopped rang 0.11 m at 0.63 Hz and now lies still. The ships under way ring at under 0.01 g where they
took 0.02 to 0.07. Across the waves nothing much was wrong before, and nothing much changed.

**What the player sees.** On PLAIN the sea is drawn to a tenth of a millimetre of `swell_height`, the unaveraged sea, so
the short waves now run a little way up and down a hull's side rather than lifting it. `seakeeping` holds the waterline's
spread under 0.5 m (0.30 now, 1.21 on the CB90 before). **A camera 1.8 m over the sea can make a small boat look
swamped when it is not**: it looks across the near crests, and the launch's first after picture showed only its console
above the water with its bow 0.08 m under. From 4 m (`--eye=4`) the deck is dry, where main's is awash. No shader changed. FINE's drawn-only travelling chop (0.34 m) is
still there.

**A camera for it.** `tests/boat_shot.gd --views=dive` runs the boat flat out along the wind-sea, with the camera abeam
and ahead at a FIXED height over the sea, because a camera that heaves with the boat hides the heave. Without `--at=` it
prints the moment of the deepest bow; `--at=T` saves that moment. The simulation is deterministic enough that the same T
on two runs gave the same bow depth to the centimetre, so a before and an after are the same moment. Under
`--write-movie` it is the reel.

**What holds it:** `tests/seakeeping.gd` (headless, 14 s, 109 checks). Its bounds: a small boat under way keeps its bow
within 0.25 m of the drawn sea, makes no dives, keeps its deck edge within 1.0 m, heaves under 2.5 m top to bottom, pitches
under 2.5 degrees sd, and rides under 0.25 g at the helm (0.17 on a hull of 10 m or more, which the average reaches). A
ship rings under 0.015 g, and every hull lying stopped lies still and within 0.15 m of its drawn waterline. On main's
library at 910e75bb it failed 45. Mutants: `--set=probe_damping=1000` fails 29, and `--set=sea_smoothing=0` fails 3 (the
gunboat at 0.193 g against 0.17, and the submarine twice).

**Not done:** the brig (`sail_ship`, six probes of its own, not pilotable) was not measured or changed, and FINE's
drawn-only chop was left alone; the user plays PLAIN.

### The landing works

An aeroplane put on the deck of a carrier making way is 1 m from the ship's centreline five
seconds later and 0.8 m above its deck, having covered 55 m while the ship covered 54.

**What makes it work.** `deck_under` finds a ship's deck beneath an aircraft and reports its
height and its velocity, computed ONCE a tick before the jobs run -- not from inside the job,
which is where the first version read it and got nothing, because a job may only touch what
it declares. `on_the_ground` is relative to that deck rather than to an absolute altitude,
which is right anyway: an aeroplane parked on a carrier doing fifteen metres a second is
doing fifteen metres a second, and a test against its absolute speed calls it airborne and
takes its nosewheel away. **The velocity is the deck's at the aircraft's point**: the ship's centre of mass's plus its
turn across the arm FROM THAT CENTRE, since Box3D's velocity is the centre's and its spin is about it. **The turn is in
plan only**, the spin about the vertical, as the deck is taken flat: with the whole spin the ship's roll and pitch on the
swell, times the 20 m arm up to the deck, put her float32 pose's rounding into a chocked aeroplane, and far_out's drifted
286.9 mm in 20 s at the origin and 412.5 mm from 24 km out, against a 50 mm margin (384.5 and 372.3 before). The middle's alone
let a Hawkeye parked 92 m from the Ford's middle slide 6.64 m across the deck while the carrier's autopilot turned it
(terrain_level, cockpit-fleet step 4); the turn with the arm from the ship's origin still left it sliding 5.08 m athwartships
through a 63.5 degree turn. `tests/fleet_shapes.gd` holds a whole turn: a carrier sailing itself round to a waypoint astern
with a Hawkeye parked at `CarrierPlan.PARKED`, which moves 0.35 m across the deck through 63.5 degrees in 40 s. A check of
rest on a deck judges against the deck's TRUE velocity there, the whole spin from the centre of mass: the deck carries a
craft through the roll that the grip leaves out, and judged against the turn in plan the Ford's parked Hawkeye read
0.475 m/s while 0.25 m from its spot. **So a craft parked on a rolling deck sways against it:** against the true velocity
the Ford's Hawkeye reads 0.278 m/s (REST_MOVING is 0.3) and 0.25 m from its spot, where the whole spin under the wheels
read 0.037 m/s and broke far_out. Holding the roll under a wheel without far_out's rounding is not built. There is a spring-and-damper undercarriage and a sideways grip. (It
said here that two vehicle hulls do not contact each other. They do, at the hulls' own
friction; see "An aeroplane on the ground" for what that was costing.)

Two more real bugs were found on the way and are worth keeping either way. The
undercarriage lived inside the "somebody is aboard" branch, so an unmanned aeroplane had no
wheels. And the grip took out the whole relative velocity rather than the sideways part --
forty kilonewtons against nine of thrust, which pinned every aeroplane in the game to the
tarmac by its own undercarriage until a Cessna reached one metre in twenty seconds.

## THINGS THAT LEAVE THE BARREL

    Godot --path cockpit -- --level=watch --kind=tank --fire=6
    Godot --path cockpit -- --level=watch --kind=gunship --fire=0.12
    Godot --path cockpit -- --level=seat --kind=tank --seat=1     the gunner's sight

The turrets aimed and fired nothing for a year. `CraftSystems` carried two mount angles and
the `Weapon` channel was fitted to half the fleet meaning nothing, both deliberate stubs.
There is a TANK and a GUNSHIP now, and rounds come out of both.

### A SHOT IS A BIRTH RECORD, NOT A MOVING THING ON THE WIRE

`ShotState` carries where the round left and how fast it left, and that is the whole of what
is sent: ONE Step packet at the muzzle and one at the impact, nothing in between.

This is `RigState` and `RailCar` for a third time -- a trailer is one angle off the cab, a
train is one distance along a railway -- and the rule underneath all three is the same:
derive the thing from what determines it and there is no second copy that could drift. A
shell's whole future is its muzzle state.

The alternative costs what it sounds like. A 120 mm round is in the air for two thirds of a
second, which at 120 Hz is eighty ticks of pose; a 25 mm cannon at 1800 rounds a minute
would have ninety of them up at once.

**Only the SERVER integrates it**, which is what the birth record buys. A shell answers
nobody's stick, so there is nothing for a client to predict and nothing a rollback could put
right: every machine DRAWS the flight from the record, and the impact -- the one fact that
must agree -- is the server's. It is found by casting a ray ALONG each tick's step rather
than testing the end of it, because a shell covers fourteen metres in a tick and a point
test puts a round through a building six times out of seven.

None of it is in a simulation job, and that is deliberate: it writes components no job
declared, and it never needs replaying.

### AND EVERY MACHINE DRAWS IT

The record goes to `All`, like a vehicle's pose and unlike the crew-only cockpit, so a round
somebody else fired is a round you can watch cross the sky. Three things make a tracer read
as a round rather than a dot, and all three are in `ShotYard`:

- **It is a STREAK along its own velocity.** 1700 m/s is twenty-eight metres in a frame.
  Drawn as a ball it is invisible between frames and a burst of them is a stroboscope.
- **It has a floor on its drawn thickness**, the same one the spotting boxes have. A tenth
  of a metre at two kilometres is a fraction of a pixel, and a gunship working a target
  below you has to be something you can see from the ground.
- **It is wound forward by however far behind the server this machine is drawing**, which is
  the interpolation lag the clock is holding now -- `Sim.drawing_late()`, off `timing()`. That
  lag already covers the link: sync draws the server's present minus the lag, so adding the
  latency on top would draw a remote round ahead of the server. It read the depth ASKED for
  until 2026-09-13, three frames, while a real link holds more. Without the wind every remote
  shell starts at the muzzle late and crawls after an aeroplane that has already moved on.

### TWO TABLES, BECAUSE THEY ANSWER TO TWO DIFFERENT THINGS

The simulation's table says how a round FLIES -- drag and life -- and has to agree on every
machine in the session. The renderer's says what it LOOKS like and has to agree with nobody,
so a client drawing a slightly bigger fireball is not a client that is wrong.

**The rows are not one explosion scaled by a number.** Sabot is a tungsten dart with nothing
in it to go off: a flash, sparks and a dust plume, and it shoots flat because its drag is a
fifth of everything else's. HEAT is a small hard white event. HE is the one that looks like
an explosion. Canister has no fireball at all and is done by five hundred metres. If the
four looked like four sizes of the same orange ball there would be no reason to choose.

What was HIT multiplies it: dirt throws a ring, water throws a column, armour throws sparks
and almost no dust. And a round that expired in the air makes nothing -- inventing a burst
for it puts fireballs in the sky every time somebody fires at nothing.

### THE TANK, AND THE GUNSHIP

The tank is `Model::Car` with a tracked profile, because a tracked vehicle is a car with
different numbers and a movement model exists to say which FORCES are present. Sixty-two
tonnes, 20 m/s, grip an order above a car's, and it turns in about its own length. Three
seats and one of them drives.

Measured, on a flat field: 1700 m/s from a barrel 2.25 m up, level, lands 1103 m away
0.667 seconds later, which is the textbook drop for that height and the right speed loss for
that drag.

The gunship is twenty tonnes on a forty-metre wing with a 25 mm rotary cannon, a 40 mm
Bofors and a 105 mm howitzer down its LEFT side. **The aeroplane is what aims.** The guns
train twenty degrees and no further, so putting a target under them is FLOWN -- a left-hand
orbit, held -- and the pilot cannot see what the gunners are shooting at while the gunners
cannot point the aeroplane. One person cannot use it, which is the best possible reason for
it to be in this game.

In trim: 67.8 m/s at 520 m against a stall of 52.2, a margin of 1.30, no wander and no
hunting. That margin is the airliner's old accident remembered: an aeroplane that has to
hold thirty degrees of bank for minutes cannot cruise three per cent over the stall.

### WHICH GUN A SEAT WORKS IS A FACT ABOUT THE SEAT

Seat 1 is the 25 mm, seat 2 the 40 mm, seat 3 the 105 -- **by position in the seat table,
whoever else is aboard and whether anybody is at all.** `mount_of_seat` is the whole of that
rule and `CockpitWorld::seat_mount` is how the cockpit asks it.

It was written down three times before that, and the three did not agree.

**The simulation counted the OCCUPIED turret seats ahead of you**, so a gunner sitting alone
got mount 0 wherever they sat -- and the gun under their hands changed the moment somebody
sat down in front of them, mid-burst, with nothing in the cockpit to say so.

**The cockpit counted positionally** when it fitted the sight. So a lone gunner in the back
watched the 105's reticle while traversing and firing the 25 mm.

From inside, both bugs look like one thing: *every seat works the same gun*. That is what
sitting alone in any seat and getting mount 0 looks like. `_test_a_gunner_works_their_own_gun`
in `cockpit_loopback` is the reproduction -- one gunner, the LAST seat, which is the case
that tells the two rules apart -- and it reports the failure in those words: `mounts that
moved: [0]`.

The lesson is not about turrets. `pull_trigger` and `aim_turret` each carried a copy with a
comment between them asking that the pair be kept in step, and they WERE in step; the copy
that had never agreed was the one in GDScript, which neither comment mentioned. A rule
written down three times is a rule with three versions.

### AND HOLDS IT BY A GRIP THAT FACES THEM

The grip a gunner holds is a pistol grip on a stalk, with a guard and a red blade **on the
gunner's side of it**. That is not how a real gun is built -- a real trigger is on the far
face and the shooter's own hand covers it -- and it is right here for a reason that beats
realism: the only viewpoint that exists is the seat. Put the blade on the far face and the
grip swallows it whole, which was tried, looked at, and is why it is where it is.

**The blade moves on the PULL, not on the grab.** Holding this used to be the firing, so a
blade driven by the fist said "firing" whenever it meant "held". The rig tells the control
what the hand's own fingers are doing through `VehicleControl.hand_input` -- generic, so the
next control that wants to light up under a thumb does not need a branch in the rig -- and
the blade follows the trigger that actually fires the gun.

### A GUNNER LAYS A GUN WITH A JOYSTICK

One station scene serves every seat in a craft, so the gunship's three gun positions were
handed the flight deck's **yoke** -- a two-handed wheel on a column, which is what you fly
an airliner with and nothing like what you lay a gun with.

Fitted per seat now, by `CockpitStation._fit_the_gunners_stick`, for exactly the reason the
sight and the trigger are: which seats have guns is a fact about the CRAFT and only the
simulation knows it. The old control is FREED rather than hidden, because `_stick` returns
the first of its names that is present and a hidden yoke would still be the control the rig
reads -- a gunner traversing an invisible wheel.

The rule is "a seat that lays a gun gets a stick", not "gunships get sticks". Seat 0 flies
the aeroplane and keeps its yoke.

### AND A DOOR GUNNER DOES NOT: THE GUN IS THE CONTROL

The helicopter carries a **7.62 mm machine gun in each door** and the Chinook one **on its
ramp**, and none of the three is laid with a joystick. There is no joystick in those
stations at all. `PintleGun` replaces the flying control with the GUN, the gunner takes hold
of the spade grips, and the gun goes where their hands go.

The helicopter's back two seats are turned **ninety degrees out of their own doors**, one
each way, because a door gunner does not face the way the aircraft is going: the whole side
is open beside them and there is nothing out of the front of a helicopter for them. The
Chinook's ramp seat was already turned right round, which is what it was built for.

**It is a servo, not an integration, and that is the whole trick.** The mount is the same
mount a joystick drives -- two angles in `CraftSystems`, moved at a rate by the roll and
pitch on the control frame -- so nothing on the wire changed. What is different is where the
demand comes from: the hand's angle away from the grips, measured **in the gun's own frame**,
times a gain. The rig already hands every control the hand pose in that control's space;
this one turns it by the gun's live angle first, so the question asked is "where is the hand
relative to where the gun IS", and the answer is an ERROR. An error that has been answered is
zero, so the gun stops with the grips under the hand and stays there. Nothing accumulates,
so nothing drifts, and letting go asks for nothing at all -- where a stick held off centre
traverses for ever.

**Pushing the grips right swings the muzzle left.** The grips are behind the trunnion, so
that is what a gun on a pin does, and it is not a sign to flip. It is also the reason for
putting the thing in somebody's hands instead of a joystick in front of them: nobody has to
be told which way it goes, because they can see the object turn.

**The gun is drawn once, by the HULL, and held in the cockpit.** A machine gun hanging out
of an open door is most of what a helicopter with a door gunner looks like from outside, so
`VehicleView._build_turret` draws the whole thing -- barrel, body, belt box, spade grips --
in the vehicle's frame, and the station adds nothing but the butterfly trigger between the
grips. Two copies, one for the cockpit and one for the world, would be two guns to keep in
step and a pair of them z-fighting in the doorway. The grip offsets are `PintleGun`'s
constants, used by both, because a grip you reach for has to be the grip you can see. The
POST is a sibling of the mount rather than a child: a pintle is a pin in the door frame and
the gun turns on top of it.

The gun is bolted where the SIMULATION says the mount is, put through the seat's own pose --
`CockpitStation._in_seat_space` -- so the barrel everybody outside can see is the barrel in
the gunner's hands and the round leaves from the same place. What that costs is a
constraint: the gun table's numbers now have to land within reach of a seated pair of arms,
and `the_heli_gunners_grips_are_where_their_hands_are` is what says whether they do.

**A gunner's station loses its screens.** A station is laid out for somebody FLYING -- a
display at eye height an arm's length ahead -- and a door gunner looks at one thing, out of
the door, with the gun between them and it. The first picture from that seat was a sight
hidden behind a flight display. So the display is freed and the two multi-function panels
are never fitted, for the same reason the yoke is swapped: one scene serves four seats, and
what a seat needs is a fact about the craft. The crew board stays; it is out of the arc.

**And the sight goes ON the gun.** A reticle bolted to the cockpit is right for a gunship,
whose guns train twenty degrees; a gun that swings ninety degrees either way would leave it
saying "straight ahead" while the barrel is out of the door. It hangs off the swivel, low on
the receiver, with the range under it.

### AND A SERVO WITH A NETWORK IN ITS FEEDBACK IS A GUN THAT SPINS

The paragraph above says "it is a servo, not an integration, and that is the whole trick". It is also
the whole of the bug, and the sentence worth keeping is this one: **a proportional controller round
an integrator is only stable while the loop is fast compared with the lag in its feedback, and until
2026-09-15 the feedback ran to the server and back.**

`_drag` measures the hand's angle away from the grips **in the gun's own frame**, so the error
depends on where the gun is — and where the gun is came from `point_at`, which is handed the
replicated mount angle, because `aim_turrets()` is `is_server_` only and no client has ever
predicted a turret. The loop's own time constant is `1 / (FOLLOW * slew)` = `1 / (6 * 3)` = **56 ms**.
A host's own client hands its packets straight across and sits comfortably inside that. Everybody who
joined has a round trip on top of it and does not. And because the demand saturates at ±1, what comes
out is not a small wobble: it is the mount running at its full slew rate, back and forth, for as long
as anybody is holding it. Reported as "when a client player holds on to the machine guns they spin
for a unknown reason... but they do work for the server", which is the symptom stated precisely.

`tests/gun_link.gd` is the measurement and it is a SWEEP over the delay rather than a check at one
value — degrees the mount travelled in the second after the gunner stopped moving their hand, against
a slew rate of 172 deg/s:

| link, one way | round trip | before | after |
|---|---|---|---|
| 0 ticks | 0 ms | 1.8 | 1.5 |
| 2 ticks | 33 ms | 1.8 | 1.7 |
| 4 ticks | 67 ms | **121.0** | 1.8 |
| 8 ticks | 133 ms | **141.0** | 1.1 |
| 16 ticks | 267 ms | **162.0** | 2.0 |

1.5 degrees is the floor: the mount steps 1.4 degrees a tick, so a gun sitting on its target dithers
by about a step. **The after column is FLAT, and that is the claim** — the delay is not in the loop
any more, rather than merely mattering less.

**The fix is where the input is.** `PintleGun.lead` advances this machine's own belief about where
the mount has got to, at the mount's rate and against its stops, with exactly `aim_turret`'s
arithmetic taken from `gun_schema` rather than typed a second time; `_drag` measures its error
against that. The rule underneath is the one this whole project runs on and it had been applied one
step too coarsely: **PREDICT ONLY WHAT YOU HAVE THE INPUT FOR.** `CraftSystems` is not predicted
because a turret aimed by SOMEBODY ELSE is not something you have the input for — which says nothing
at all about the one you are aiming yourself.

The belief is also what the gun is DRAWN from, in the cockpit and outside it:
`VehicleView.draw_turrets_at` asks each station where its own gun really is and overrides that one
entry, copying the array only when somebody aboard is actually holding something. The sight hangs off
the swivel and the barrel hangs out of the door, and if those two were drawn from different answers
they would part company by a round trip exactly while somebody was swinging the gun.

It is put back onto the wire only when the hand has stopped asking for anything AND the wire has
stopped moving — which together mean the server has obeyed everything already sent. **Anchoring
sooner is worse than not anchoring**: the server is a round trip behind, so a belief dragged toward a
value that is still catching up pulls the gun back into the swing it has just finished, which is the
ringing the mechanism exists to remove.

**THE GENERAL RULE IS NOT ABOUT GUNS** and it is written down as one: `building_a_game_here.md`, "Never close a
control loop through the network", under Boundaries. Anything here that measures how far it is from where it should be,
asks the simulation for a RATE and reads the answer back off the wire has this shape. Nothing else in this cockpit does
today, because every other control reports a POSITION and a position has no feedback path to be delayed.

**Rejected: turning `FOLLOW` down.** It would have to come to about 1.0 — a gun that takes half a
second to answer a push — and it would still come apart on a worse link. Note that `FOLLOW`'s own
comment already said "higher than this and a network round trip starts to ring"; it rang at this
value too. **A constant whose comment names a failure mode wants a test, not a sentence.**
**Rejected: predicting the mount in C++ on the client.** `CraftSystems` is a Step component that
never rolls back, so a locally advanced value would be overwritten by every record that arrived — a
sawtooth rather than a fix — and it is a change to the meaning of a replicated component for a fault
that lives entirely inside one control.

### THE OTHER KIND OF GUN HAS NO LOOP, AND IS FINE AT ANY LATENCY

Asked in the same breath as the spin: "the cannons in planes that are controlled by joysticks don't
seem to work." A walk of `Sim.gun_of` over every kind and seat says **only the tank and the gunship
are laid with a joystick** — the helicopter's two door guns, the Chinook's ramp gun and the
gunboat's, carrier's and battleship's are all `pintle` — and a gunship is the only PLANE in this game
with cannons. So that sentence can only be about a gunship's three guns, and they work:

- `tests/gun_link.gd`: a CLIENT at the gunship's joystick gun station traverses its own mount to the
  stop and fires 28 to 30 rounds a second over links of 0, 2, 4, 8 and 16 ticks each way. A
  joystick's deflection does not depend on where the gun is, so **there is no loop there to be
  unstable** — which is why a hand-swung gun and a joystick-laid one behave completely differently
  over the same link, and why fixing one says nothing about the other.
- `tests/gunners.gd`: through the real rig, the left hand on the joystick while the right holds the
  grip — the 25 mm gunner's stick moves mount 0 and nothing else, the 40 mm gunner's moves mount 1
  and nothing else.

Two facts that would each LOOK like that report, and neither is a bug in the guns:
**no aeroplane in this game has a gun at all** (the fighter carries missiles, and `FlightStick`
puts LAUNCH on the trigger of any stick whose seat has no gun of its own, so pulling the trigger in a
fighter launches and can never fire — see "WHAT IS NOT HERE YET"); and **nothing in cockpit reads a
joystick DEVICE.** Every action is bound to a keyboard key in `PilotRig.DESK_KEYS`, and
`Input.get_joy_axis` appears exactly once in the project, in a TODO comment. A player with a physical
HOTAS has no axes and no buttons bound, and the cannons not firing would be one symptom of that.

### A SELECTOR WITH NOTHING TO SELECT WAS LOADING TANK ROUNDS

The door gun found a bug in every other gun in the game. `fire_gun` took the round from the
`Weapon` bus channel whenever it was in range -- and that channel starts at ZERO and means
something different on every craft that carries one. On the gunship it is which gun is HOT.
Zero is the first round in a tank's ready rack, so a 25 mm rotary cannon fired sabot darts,
and so would a machine gun.

A choice of round is a **ready rack**, which is a thing a tank has and a belt-fed gun does
not, so `Gun::rack` says which guns have one and the selector is read only for those. The
helicopter's weapon channel is gone with it: a selector with nothing to select is a dead
switch on a panel, which is worse than no switch.

### THE STOPS ARE MEASURED FROM WHERE THE GUN RESTS

`aim_turret` clamped the traverse between `rest_yaw - span` and `rest_yaw + span`, which is
the same thing as measuring from the rest right up until a mount rests near half a turn. The
Chinook's ramp gun points AFT, so its arc runs from 2.09 to 4.19 radians while the angle
being clamped wraps at 3.14: clamped, wrapped, then clamped again, the barrel jumped from one
end of the arc to the other every tick it was pushed past due aft.

It clamps the DIFFERENCE from the rest, the short way round, and wraps once at the end. There
is no seam anywhere in the circle now, and `wrap_pi` is written down once instead of inline
twice.

**A mount also has its own slew rate.** A door gun is a man's arms and a gunship's guns are a
motor: 3.0 rad/s against 1.2, which is a difference you feel before you notice the calibre.

### THREE THINGS THE TESTS FOUND AND READING DID NOT

**Only the first gunner has ever been able to aim.** `aim_turret` returned after aiming one
mount, directly beneath a comment reading "one mount per gunner". It never showed because
the only craft with two gunners is a boat and nobody had sat two people on one.

**A thirty-a-second gun managed twenty-four.** At 120 Hz it wants every fourth tick, and
four ticks of 0.008333 lands a hair under 0.03333 in float, so the fourth was refused and it
fired on the fifth -- a rounding error, on the one gun where the rate IS the weapon. Half a
tick of slack now, because a gun can only fire on a tick anyway.

**The drawn barrel was a metre long on everything.** A tank whose shell leaves five and a
half metres in front of the trunnion needs the drawn barrel to be that long or the round
appears out of thin air past the end of the gun. `_build_turret` asks the gun table now.

### A HELD TRIGGER IS A GUN FIRING, AT EVERY GUNNER'S STATION

Asked for on 2026-09-13: "the gunner stations in the helicopters and ships with machine guns
... should be mostly automatic not one shot".

**The simulation was already automatic, and that was the surprise.** The trigger is a level on
the input frame (`Bind.fire` is a frame bit and an axis, never a command), so the command bus's
per-channel coalescing never touched it; `drive_pilot` calls `pull_trigger` every tick the
pull is past `kTriggerBreak`, and `gun_ready_` -- keyed on simulation time, on the server,
which never resimulates -- is what spaces the rounds. `tests/shots` already counted 10-13
rounds a second from a door gun, but only through `fire_gun`. Nothing had held a real grip.
What made it feel like one shot was four other things:

1. **The ships had no guns.** The gunboat, battleship and carrier were each built with a
   gunner fore and aft, and `gun_of` had no row for them: the trigger did nothing at all.
2. **The kick came once per PULL**, from `GunTrigger`, and the pintle gun had none. A round's
   birth record did not say who fired it, so a machine could not tell its own gun's rounds
   from anybody else's.
3. **A light pull quartered the rate** (`kSlowestFire`). A tracked trigger rests part-pulled,
   so a relaxed finger fired a door gun at a third of its rate. Measured on the old library
   (`tests/shots`, rounds in two seconds of simulation): 12.0 a second at a full pull, 7.0 at
   a half, 3.5 at a fifth -- and 3.0 at a tenth, under the break, because `fire_gun_pulled`
   never checked it (only `drive_pilot` did).
4. **Sound starts off** (see the headphones), so a held gun was silent.

**What changed.** A 12.7 mm pintle on every ship's gunner seat. `ShotState` carries `shooter`
(the client, 8 bits) and `mount` (2 bits), and the gunner's hand feels every round their own
gun fires. Past the break a gun fires at its own rate, however far past. And a forced finger's
fire bit and trigger axis now reach the frame on a desk (`PilotRig.read_controls`), the way
its trim rate already did, because nothing else can pull a trigger through a hand headless.

**A PINTLE IS PLACED FROM ITS SEAT**, never typed: `pintle_at` in `cockpit_world.cpp` puts the
mount `kPintleAhead` (0.60 m) ahead of the seat and `kPintleUp` (0.88 m) above it, turned the
way the seat faces. Those were the helicopter door gun's own numbers -- its typed
(-1.15, 0.68, 0.55) is exactly its seat plus them -- so the door guns did not move, and the
Chinook's ramp gun moved 5 cm aft to 7.80 m. `the_<kind>_gunners_grips_are_where_their_hands_are`
measures every ship's gun against a seated pair of hands.

| Gun | Rate | Round interval | Kick (strength before `HAPTIC_MASTER`, length) | Why |
|---|---|---|---|---|
| Helicopter doors, Chinook ramp, 7.62 | 700/min | 86 ms | 0.80, 30 ms | automatic |
| Gunboat, battleship, carrier, 12.7 | 550/min | 109 ms | 0.80, 30 ms | automatic |
| Gunship 25 mm | 1800/min | 33 ms | 0.80, 16.7 ms | automatic: half the interval, so thirty kicks a second and not a rumble |
| Gunship 40 mm | 100/min | 600 ms | 0.80, 30 ms | automatic, slowly: a Bofors is a clip-fed autocannon |
| Gunship 105 mm | 6/min | 10 s | 0.80, 30 ms | SLOW-CYCLING ON PURPOSE: a howitzer loaded by hand. Still fires again while held |
| Tank 120 mm | 12/min | 5 s | 0.80, 30 ms | SLOW-CYCLING ON PURPOSE: a loader and a choice of round. Still fires again while held |

The kick is `FEEL[&"round"]` shortened to half the gun's interval (`PilotRig.kick_for_a_round`),
asked for so a held gun pulses; `tests/feel` sends one for every gun in the table and fails if
any is not over before the next round. What went out, read off the call: 68% (0.80 times
`HAPTIC_MASTER`) for 30 ms on every gun, and 17 ms on the 25 mm.

**Measured (2026-09-14), through the real path** -- `tests/gunners`: the server moves the player
to the gunner's seat, the right hand is put back on the gun's own grip every frame, the
controller trigger is held two seconds, and the rounds counted are the server's with this
client as `shooter`. Door gun 24 (23.3 wanted), gunboat bow 18 (18.3), battleship stern 18
(18.3), gunship 25 mm 59 (60), 40 mm 4 (3.3); letting go stops each within one round; one
frame of trigger fires one; one kick per round at every station. Past the break on
`tests/shots`: 12.0 a second at a full pull, a half and a fifth; 0 under it.

**Two test traps this found.** `view.entity` is the client world's number for a craft, and
`Sim.server.seat_client` refused it without a word -- ask the server's own `pilot_states` for
the vehicle. And on a desk a forced finger's frame was thrown away whole, so no suite had ever
fired a gun through a hand: it keeps the fire bit and trigger axis now.

**What full-rate fire costs the wire** (`cockpit_loopback`'s probe: bytes the server sends one
client a tick over a 4-tick link, three seconds quiet against three firing, 2026-09-14). Three
door guns: quiet 925 bytes a tick and no ticks at sync's 1024-byte budget; firing 1018 and 43
of 180 ticks at the budget; 107 rounds, every one at the client 5.9 ticks after it was made
(6 at worst). A door gun and a gunboat's two rail guns: firing 1018, 60 ticks at the budget, 87
rounds at 6.0. So a stream of rounds fills the per-tick budget without yet delaying a round --
what waits is whatever else was due in those ticks. The ten bits of `shooter` and `mount` do
not show (108 rounds at 6.0 ticks on the old library, 107 at 5.9 now). Not fixed; see the
per-tick budget, `bandwidth_limit_bytes_per_tick`.

**A test trap the probe found.** The loopback's `_controls()` frame had no "trigger" key, and
input is merged into what the world already holds, so a test that "let go" of a gun left it
firing. It sets the trigger to rest now.

**A ship's gunner loses the screens, as a door gunner does.** A gunboat's aft gunner's seat was
where `tests/smoke` asked for "a seat that does not fly gets two MFDs" -- true only while it had
no gun. With the gun in their hands the station clears its screens (`_clear_the_gunners_view`),
so smoke asks the Chinook's gunless mid-cabin turret seat now, found by asking the gun table,
and checks the gunboat's two gunners have none.

**Rejected:** a kick from the trigger once per pull (the bug); a kick worked out on the client
from where a new tracer starts (a guess about whose round it is, wrong for two gunners in one
craft); keeping the quarter rate for a light pull (reads as a broken gun in a headset).

### A BIG EXPLOSION: A HEAVY SHELL'S OR A MISSILE'S, FROM A POOL BUILT AT LOAD

Asked for on 2026-09-13: "the larger guns on the gunship should make large explosions ... lots of
fire and smoke, as long as they are not a weird perf hit when created". A missile, and a round
`Ammunition` marks `"heavy"` (the gunship's 40 mm and 105 mm, a tank's HE), goes off as a
`HeavyBurst` from `BurstYard`; everything lighter stays a `Burst`. The design is cockpit-fx's
unbuilt missile burst, generalised.

**The size is the simulation's number through `BurstTuning`, never typed.** A missile's fireball
radius is its `fuse_m` times 2.25, which is what makes the smallest (heat, 6 m) three times the
9 m ball every missile drew before: 27 m across, radar 54 m. A shell's is its `calibre_mm` (the
round table) times 0.199 m a millimetre -- the share that makes every heavy round at least three
times the ball `Burst` drew for it, times `SHELLS_LARGER_THAN_BEFORE` (3.8) for the agreed 105 of
about 42 m (41.8; 11 before). A 40 mm is 16 m (3.6), tank HE 48 m (7.5). A small burst's smoke
goes sooner, in proportion under a 15 m radius. Nothing in the simulation reads any of it.

**Nothing is made, compiled or grown at the moment of an explosion.**
- `BurstYard._ready` builds four ShaderMaterials (fire and smoke, PLAIN and FINE), two MultiMeshes
  laid out once with seed 1, twelve `HeavyBurst`s and two OmniLights (shadows off). The level
  makes the one yard and hands it to `ShotYard` and `MissileYard`, so they share the cap.
- Setting one off is a position, seven instance uniforms and a visibility. The thirteenth takes
  back the oldest.
- For the first four frames a burst wearing each finish, and both lights at the least energy,
  stand just in front of the camera collapsed to a point: every pipeline is drawn once before
  anybody fires.
- Every quad is aged on the GPU from the yard's clock. The processor writes `now` on the two worn
  materials while a burst is going -- `Burst` wrote about fifty colours a frame per burst.
- Lights: the newest two bursts, for 0.3 s, at the time of day's `burst_light` (0 by day).

**THE CHECK THAT NOTHING IS MADE WAS A TAUTOLOGY FIRST.** `tests/bursts` compared `Performance`'s
live node and resource counts across thirty explosions, and with a `ShaderMaterial.new()` put in
`BurstYard.set_off` it still passed, "+0 resources": a material made and dropped inside the call
is freed before anybody counts. That allocation is the whole of what the design avoids. It counts
CREATIONS now -- thirty explosions with no frame between them, and the objects Godot created read
off the instance-id serial (every Object takes the next value of one counter, the id's bits above
the 24-bit slot), calibrated by making five and counting five. Real tree: 0 created. The copy with
the material: FAIL, 30 created, while the live counts beside it still read +0. Any future "made
nothing" check here: count creations, and prove it red.

**Two things only the first pictures showed** (2026-09-14; every suite was green over both):
- **The smoke was a black ball.** `SMOKE_TONE` feeds a `source_color` uniform, which the shader
  reads as sRGB: 0.24 arrived as about 0.05 linear, and the smoke drawn at 4 s was a near-black
  blob. It is a colour-picker colour now (0.52, 0.50, 0.47). The same trap applies to any tone a
  tuning file hands a `source_color` uniform. It also climbed a fixed 3 m/s whatever the size, so a
  105's smoke sat on the ground as one ball; the climb is in fireball radii now, each puff by its
  own share, so it stands as a column.
- **The FINE shock ring was a grey rainbow over a runway.** A camera-facing ring five fireball radii
  out has its lower half under the ground on an impact, and added to a night sky it was the
  brightest thing in the frame. It is drawn in the air only, to 2.5 radii, at half the brightness,
  fading as the square. And nine additive puffs, each soft from a quarter of its radius, made a
  white ball half the size it was sized to: the puffs are solid to half their radius now, dimmer,
  and a ball goes orange sooner (`FIREBALL_COOL_S` 0.9, white only above 0.92 of the heat).

**A landed round goes off once.** `ShotYard.draw_shots` called `_land` for every landed row on
every drawn frame, and a landed record lingers until the simulation retires it -- three ticks,
until cockpit-netjump made it half a second so an impact reaches a joined machine. At half a
second one 105 would have set off an explosion a frame and taken the whole pool. The yard keeps
`_landed` and forgets an entity when its row goes; `tests/bursts` draws one landed row for five
frames and wants one explosion (1 on this tree; 5 on the yard before it).

**Fire, not a glowing ball, and smoke that stands** (team-lead, from the pictures, 2026-09-14).
A puff burns by two clocks -- `FIREBALL_COOL_S` (0.18 s white-hot) and `FIREBALL_BURN_S` (2.2 s
of orange down to dull red) -- with a cooler, lumpy rim; on the ground the puffs past the fire
shader's `LINGER_FROM` settle beside the impact and flicker as small fires for `GROUND_FIRE_S`
(5 s), so no quad is added. The smoke's puffs each take a share of the column's height, narrow and
dark at the base, widest at the top. A burst lasts at least as long as its ground fire.

**Two things the look pass's own pictures showed.** PLAIN's flame lumps first added a sine of
`x + y`, and every PLAIN fireball wore the same diagonal stripes; the lumps go round the puff
and out from its middle now, never along a straight line. And a fireball is ADDED light, so
over a pale day sky a missile's air burst washes towards peach and white whatever its ramp
says -- orange only reads against something dark (the ground behind a 105, the sky at night).
Not changed: a blended flame would need a second material and a second draw per burst.
The pixel measure on the final look, FINE at 0.45 s: 105 69 × 70 px by day and 87 × 67 at night;
missile at night 61 × 74 -- 2.9× the old width, down from 3.1× before the look pass, because the
cooler red rims fall below the measure's warmth threshold. The size in metres is unchanged.
PLAIN, retaken without the stripes: 105 by day 83 × 60 px (12 × 8 before); missile at night
74 × 78 px (15 × 16 before).

**The pool gives way oldest first.** Round-robin took the next burst whether or not it had
finished, and with ground fire outliving a 40 mm's smoke that was a fireball popped mid-barrage.
`BurstYard._free_or_oldest` takes one that has gone out, else the oldest still going, and counts
each burst it takes back (`stolen`). `tests/bursts`: a ten-round barrage fits the twelve (0 taken
back), eight missiles straight after take back exactly 6, each the oldest going, and an idle
burst is reused before a busy one. `fx_shot` prints the pool after its barrage and volley.

**It is not a hitch, timed.** `tests/fx_shot.tscn --views=barrage,volley --frames=240`, windowed,
stock editor, vsync off, on the tree before (1ad8bbd, `Burst`) and this one, interleaved A, B, A,
B, two rounds per finish and time of day, with other lanes' runs going at the same time: only the
change each tree makes to its own quiet frames is compared. Median over two rounds of the increase
over 240 frames with nothing going off, old -> new, final tree (2026-09-14):

| View | worst frame + (ms) | 99th percentile + (ms) |
|---|---|---|
| 105 barrage, PLAIN day | +2.67 -> +0.63 | +2.03 -> -0.52 |
| 105 barrage, PLAIN night | +8.15 -> +0.86 | +2.08 -> +0.17 |
| 105 barrage, FINE day | +7.04 -> +3.27 | +2.03 -> +0.17 |
| 105 barrage, FINE night | +6.70 -> +1.00 | +2.49 -> +0.15 |
| 8 missiles, PLAIN day | +5.90 -> +0.96 | +5.72 -> +0.59 |
| 8 missiles, PLAIN night | +5.56 -> -0.42 | +4.12 -> +0.37 |
| 8 missiles, FINE day | +4.08 -> -4.07 | +3.86 -> -1.39 |
| 8 missiles, FINE night | +5.76 -> +2.27 | +3.85 -> +0.63 |

Worst single frame of any explosion view: 15.46 ms old, 10.91 ms new. Under parallel load a
single frame moves by 2-4 ms either way, so read the table as "the old one cost 3-8 ms in its
worst frame and 2-6 ms at p99; this one is inside the noise at p99". The round before the look
pass (same probe) gave new -2.64..+4.21 worst, old +2.48..+8.12: the look pass added no quads,
nodes or passes and did not move it. The probe's barrage and volley took nothing back (4-6 going,
8 going); the taking back is checked in `tests/bursts`.

**How big it looks, measured.** The lit extent of the fireball at 0.45 s -- its widest; the old
`Burst` had no fire left by 1.5 s -- flood-filled out from the most fire-like pixel near the
middle of `tests/fx_shot`'s frame (warm, or all but white), before and after:

| Frame | Before | After |
|---|---|---|
| 105 by the runway, 264 m, PLAIN day | 12 × 8 px | 80 × 60 px |
| same, FINE day | 15 × 7 px | 79 × 70 px |
| same, FINE night | 18 × 9 px | 89 × 68 px |
| missile air burst, 190 m, PLAIN night | 15 × 16 px | 68 × 76 px |
| same, FINE night | 21 × 21 px | 66 × 81 px |

The first placement measured about half this -- a 105 sized 42 m across drew a 20 m dome with its
lower half under the runway -- so the puffs sit out to 0.62 of the radius and a ground burst is
lifted by a third. A missile over a pale day sky washes to near-white and defeats the measure, so
missiles are measured at night. Pictures: `godotgames-drafts/2026-09-14/cockpit-guns/explosion-looks/`.

**Rejected:** a light per burst (an eight-missile volley at night is eight omni lights on every mesh
they reach); `Burst` with bigger numbers (fifty StandardMaterials a burst, colour written every frame,
a pool grown on first hits); a fireball on every round (a 25 mm at thirty a second would be a wall);
soft-particle smoke (needs the depth texture, a pass on the Mobile renderer this was written for and
untimed on Forward+ -- see `smoke_fine.gdshader`).

## A MISSILE, FROM THE PILOT'S FINGER TO THE SMOKE IT LEAVES

The simulation's half -- the table, the seeker, the lock, proportional navigation, the motor, the
fuse -- is ashiato's, in `cockpit_world.cpp`, and its design is written down there. This is the
cockpit's half: what a pilot presses, what they look through, and what everybody sees.

### THE FINGERS: A STICK THAT LAUNCHES, AT THE SEATS THE SIMULATION NAMES

`CockpitStation._fit_the_missiles` asks `Sim.missile_schema(kind).launch_seats` -- never a list
kept here, for the reason `Sim.mount_of_seat` gives about guns -- and fits three things at a seat
that can launch: a `LockSight` in front of the eyes, a master arm `ToggleSwitch` on the
glareshield, and a stick that knows it launches (`FlightStick.missile_bindings`). The trigger is
the launch and the upper thumb the lock, which is the pair a pilot uses together; the lower thumb
walks the weapon stations. A seat whose trigger already fires a gun would launch on the lower
thumb instead -- and none does: `mount_of_seat` gives a gun only to turret seats, and launch seats
are the pilots'.

**The master arm switch is new furniture for an old channel.** The plane had `master` on its bus
from the start and nothing in its cockpit to throw it with, because a pilot's seat has no screens.
A launch the server refuses as "not armed", at a seat with no way to arm, is a dead end.

On a desk: L lock, Enter launch, U master arm, Y weapon station. The lock and the launch are levels
on the input frame and edge-detected on the server, like the trigger; arm and station are steps on
the bus.

**The station is a list the simulation gives, not the channel's range.** The plane fits `Weapon` at range 3 and carries
two missile stations, 0 and 1: the same channel is "guns hot", "ammunition" and "turret" on other kinds, so the range is
not a rack count (ashiato-missile: cockpit_world.cpp:940 against `loadout_of`). A plain wrapped `Bind.step` put the lower
thumb on [2, 3, 0, 1] from station 1 -- half its presses on selectors with nothing on them, and a sight saying NO
MISSILE ON THIS STATION. `Bind.step_among(channel, stops)` walks `CockpitStation.missile_stations()` (each schema
station's own `station` number), the thumb and the desk's Y both, and `_show_the_lock` finds the chosen station by that
number rather than by its place in the list; the two coincide on the plane and would not on a craft whose rack 0 is
empty. `the_lower_thumb_steps_the_missile_stations_the_craft_carries` in `tests/shared_controls.gd`.

### THE SEEKER: A CONE TO TAKE A LOCK, A GIMBAL TO HOLD IT

The seeker is ashiato's and so are its numbers (`MissileType` in `cockpit_world.cpp`, read back through
`Sim.missile_type`). What the cockpit needs to know about it, each edge asserted in `tests/missiles.gd` against the
server's own lock row -- whose `target` is in `spawn_vehicle`'s numbers -- and shown failing before it passed:

- **The heat seeker is all-aspect**, by the lead's decision (ashiato 441b790). A target's heat is
  `0.15 + 0.85 x throttle` if its kind has thrust, its aspect `1 + 2 x tail`, and it is seen while
  `heat x aspect / km^2 >= heat_min` (0.02) inside the row's range (3000 m). Looking up a tailpipe triples it; looking
  at a nose does not blind it. An idle aeroplane is seen head-on out to `sqrt(0.15 / 0.02)` = 2739 m. **A glider has no
  heat at any aspect.** Measured 2026-09-13: tail-on idle at 1188 m, signature 0.297, LOCKED; head-on idle at 1119 m,
  0.120, LOCKED; head-on at 2900 m, 0.018, SEARCHING; a glider tail-on at 800 m and head-on at 1000 m, SEARCHING.
- **The cone is asked once, when the key is pressed** (`best_target`). A target 0.100 rad off a 0.07 cone at the press
  gave SEARCHING and no target; 0.050 rad locked. Pressing again breaks a lock that is on its way or held.
- **A lock takes `lock_s` of ticks from the tick after the press**: 0.633 s from the key going down, against 0.60.
- **The gimbal holds it** (0.8 rad for heat): a target drifting sideways stayed LOCKED for 445 ticks between 0.3 and
  0.5 rad, left the gimbal at 8.675 s and was LOST at 8.917 s -- `kLockGrace`, 0.25 s, less the tick by which the
  test's angle leads the seeker's. Which is why a held heat lock reads "0.34 rad off the nose" with a 0.07 cone, and
  why that is not a bug.
- **Out of sight is out of sight, and the grace is the same for it.** A held target hidden behind an aeroplane for
  0.1 s kept its lock through the gap and a second after; hidden for 0.4 s it was LOST 0.25 s after the aeroplane went
  up. Checked by spawning an aeroplane in the line of sight and taking it away again -- no call puts a vehicle at a pose,
  and a target on a straight line relative to the launcher leaves the gimbal only once, so angle cannot take it out and
  bring it back. `seen_from`'s ray stops at any hull.

### THE GLASS: IT DRAWS THE LOCK AND NEVER DECIDES ONE

`LockSight` is handed this seat's row of `Sim.locks` and the craft's `stores`, `weapon` and
`master`, and draws them: the seeker's circle, sized from the type's cone; a diamond on the
target; how far the lock has got; and `why_name` when the server would refuse a launch, or SHOOT
when it would not. **Nothing on it is worked out here.** A sight that decided "locked" or "can
launch" for itself says SHOOT a tick before the server agrees, and a pilot who believed it presses
on a refusal. The diamond is drawn only when the row carries a `bearing` -- the simulation works it
out on this machine from where the target is DRAWN, so the mark sits on the aeroplane you can see.

**The glass follows the lock one feed later.** The station is handed the craft's state after the
tick that changed it; a test that reads the words on the same frame as the lock row sees
"LOCKING 92%" beside a lock that is already LOCKED.

### THE JETS: AN M61 AND TWO MISSILE STATIONS EACH (lane/jetarms, 2026-09-18)

The user: "yes, guns for sure, and missiles." The F/A-18F (`fighter`), the F-14D (`tomcat`) and the F-16A (`falcon`)
carry the light twin's selector in the light twin's order -- heat 0, radar 1, guns 2 -- so everything that launches by
number means the same station on each. All of it is `loadout_of` and `default_bus` in `cockpit_world.cpp`; the cockpit
fits itself from `missile_schema` as it always did.

| | gun, rounds | muzzle (the port the model draws) | heat pair | radar pair |
|---|---|---|---|---|
| F/A-18F | M61A2, 412 | top of the nose, station 1.90 | AIM-9, wingtip rails | AIM-120 ("active radar"), middle pylons |
| F-14D | M61A1, 675 | port side of the nose, station 3.10 | AIM-9, glove shoulder rails | AIM-7 (the radar row), glove pylons |
| F-16A | M61A1, 500 | left shoulder abeam the seat (ESTIMATE) | AIM-9, wingtip rails | AIM-120, stations 2 and 8 |

- **6,000 rounds a minute is a round every 1.2 ticks**, and `shoot` used to count each reload from the tick it fired,
  so a reload that is not whole ticks was rounded UP every round: the M61 fired every tick, 7,200 a minute. The reload
  is carried forward from the last round's due time while the trigger is held. For every gun whose reload is whole
  ticks (all of them before the jets) the two are the same tick.
- **The drum** is `Gun::rounds` (0 = never runs dry, every older gun), exact on the server (`Drum`, `drums_`) and on
  the wire as the share left on `CraftSystems::load` -- the tanker's byte, unused on anything with a selector gun --
  rounded up so 0 means empty everywhere at once. `CockpitWorld.gun_rounds(entity)` answers either way; the sight says
  `GUNS 412`. Empty, it is full again `rearm_s` (5 s) after the last round, as a rail is. It rolls back like the
  tanker's gauge: a pilot's predicting machine sees a step past 8 on a rollback.
- **The muzzle is held to the MODEL, not to the loadout.** Each airframe has `gun_port()`; `tests/jet_arms.gd` holds
  every round to it. Held to the loadout's own `at`, the first draft would have passed a gun moved anywhere -- and the
  F-16's first guess was 0.43 m inside the skin its SECTIONS draw.
- **The round is the 25 mm row**: the nearest cannon shell there is, and no new round on the wire. Not a predicted gun,
  so the 256 shell-number wrap does not bound it; the drum does.
- **The F-14 carries the Sparrow, not the AMRAAM**: its AMRAAM integration was terminated (Wikipedia). The radar row is
  semi-active, and the hands-off Tomcat in the suite drifted a target at 1,500 m out of its 1.0 rad gimbal 5.4 s after
  launch; the missile went blind and hit the ground. That is the row working. The AMRAAM is a row of its own,
  `kMissileActiveRadar`, the radar row with `semi_active` false: it guides to the end whatever the launcher does.
- **The back seat** (RIO, WSO: an Operator seat in a craft with missiles) gets a repeater of the pilot's sight, headed
  PILOT'S SIGHT (`CockpitStation._fit_the_repeater`): the pilot's row of the locks, no launch bindings, no master arm.
  `launches()` is false there, so the desk keys do not think it launches.
- **The missiles on the rails** are `HungStores`, fitted by `VehicleView` on a kind whose catalogue entry says
  `"hung_stores": true`: one faceted missile a rail at the schema's pylon point, shown while its `stores` bit is set.
- **The craft packages had to be regenerated**: a station built from a package keeps the controls it was written with,
  and the F/A-18F's pilot had no lock sight and no master arm until `generate_authored_packages` wrote them in.
- **Seen by everyone**: `tests/jet_arms_peers.gd`, two real machines through `JetArmsHarness` (`--arms=fire` on the
  host's pilot keys, `--arms=watch` on a joiner): 100 rounds fired, all 100 handed to the joiner and 100 drawn at
  once, and the Sidewinder drawn there too.
- **The pilot's own tracers start about 25 m ahead of the port**, measured in the picture pass (`late` 0.025 s): the
  rounds are server-born records drawn from their birth, as every non-predicted gun's are. The rounds themselves are
  born at the port (within 0.01 m, the suite). Predicting the selector gun, as the battleship's turrets are, would
  close it; not done.
- **Pictures and a reel** come from the same suite, windowed: `res://tests/jet_arms.tscn -- --shot=<dir>` takes four
  stills a jet in the first seconds after boarding (a hands-off Tomcat is nose down within twenty); add `--reel` and
  Godot's `--write-movie <file>.avi --fixed-fps 30` for one chase-camera reel of all three. A windowed run is a
  picture run, not a verdict.

### A GUN'S ROUNDS SCATTER A LITTLE, AND THE SAME LITTLE ON EVERY MACHINE (lane/gunscatter, 2026-09-19)

The user: "add some random distribution to the bullets coming out of the plane, not much just enough to add some
randomness." `Gun::scatter` is the half-angle, in radians, of a cone about the barrel's line; a round's heading is
turned to a point UNIFORM over that cone's disc (radius `scatter * sqrt(u)`, angle `2 pi v`), inside `muzzle_of` and before the
muzzle speed and the craft's velocity are added. The default is 0, so every gun not named below shoots dead true --
above all the tank's and the battleship's, whose range `shell_elevation` and `shell_reach` work out exactly (`big_guns`).
The numbers, all under the M61's real 80%-in-8-mils (a half-angle of about 4 mrad): the F/A-18F, F-14D, F-16, F-35 and the
A-10's 30 mm 2 mrad; the AC-130's 25 mm 2.5; the Apache's M230, the minigun aeroplane and the Savoia's machine guns 3.
The door guns are hand-swung and are 0.

**IT IS A HASH AND NOT `rand()`, AND THAT IS THE DESIGN.** A predicted gun's round is computed on the gunner's machine and
again on the server, and the two must agree or the prediction breaks (`tests/shell_prediction.gd`). So the two numbers are
`dice_of_a_round(key, round)`, a splitmix64 of the gun's loader key (`reload_key`: vehicle and mount) and the round's number: the
tick the round was DUE on for a gun the server fires (`shoot`, which carries the reload forward, so a burst's rounds have
distinct numbers), the gunner's shell number for a predicted one. Nothing is a clock or a counter, so a replay rolls the
same round the same way. Only the heading is scattered: the direction is in the birth record the wire already carries, so
there is no protocol change. A predicted gun's shell number wraps at 256, so its pattern repeats every 256 rounds.

`tests/gun_scatter.gd` holds the F/A-18F's trigger for a second through the pilot's own keys and measures each server
round off the server's nose: not on one line (a spread over half the scatter), not by more than the scatter plus the
wire's rounding, and the hash answering the same twice. `-- --flat` sets `set_gun_scatter_scale(0)` and the first check
must fail.

### THE SKY: A MISSILE IS NOT A SHELL

`MissileYard`, beside `ShotYard`. A shell's future is its birth record; a guided missile's is
decided by a target on somebody else's stick, so its position is on the wire every tick and this
draws it where the wire says, wound forward by the row's own `late` -- the interpolation lag, and
only the lag (see `Sim.drawing_late`, which had the same question).

- **It starts on the rail.** On the launcher's own machine the aeroplane is predicted ahead and the
  missile interpolated behind, so a new missile's first state is tens of metres behind the pylon.
  For its first 0.35 s it is drawn from the pylon, which moves with the aeroplane, to where the wire
  has it. The pylon comes from the launch cue, or failing that from `missile_states.pylon` and the
  launcher's client -- a machine that joined after the launch still sees it leave the rail.
- **The motor is the simulation's.** `motor` comes from the replicated `age` and the table, so the
  plume goes out on the same tick everywhere; the yard never decides a motor is burning.
- **The trail costs nothing once it is laid.** Every trail in the sky is one `MultiMeshInstance3D`
  of 512 segments. A segment is written when a burning motor has flown 0.08 s further and never
  touched again: how far it has spread and faded is worked out in `contrail.gdshader` from the time
  its two ends were laid, on the yard's own clock. What a frame costs the processor is the one
  segment still growing behind each burning motor. How long a trail lasts, 14 s PLAIN and 22 s FINE,
  is `TrailTuning.missile_life`, written onto both materials once (see "Contrails" below).
- **It ends once.** The end is on the wire twice -- a state that lingers a few ticks with `flying`
  false, and a cue -- and whichever arrives first sets the burst off. A proximity burst (surface 5)
  is an air burst; a missile that ran out of life does not explode.

Two finishes, like everything else in the sky: `missile_motor` and `missile_motor_fine`, `contrail`
and `contrail_fine`, all turned about their own axis to face the midpoint of the eyes.

**What it costs to draw**, measured on 2026-09-13 with `tests/scenery_shot.gd --missiles` on the `missiles` view:
three launches with an eight-missile salvo against three without, alternating, windowed on the stock editor,
`--fixed-fps 60`, 120 frames each, idle machine. Medians over the frames of each launch, then the median of the three;
the spread is the largest difference between two launches of the same arm.

| finish | in the air / trail segments | `missiles` lap | CPU | GPU |
|---|---|---|---|---|
| PLAIN | 8 / 192 | 0.005 -> 0.040 ms (+0.035, spread 0.012) | 0.626 -> 0.692 (+0.066, spread 0.101) | 0.213 -> 0.218 (+0.005, spread 0.002) |
| FINE | 12 / 479 | 0.005 -> 0.062 ms (+0.057, spread 0.022) | 0.674 -> 0.819 (+0.145, spread 0.141) | 0.387 -> 0.394 (+0.007, spread 0.005) |

The yard's own lap is the number that clears its spread: about four hundredths of a millisecond for eight missiles,
six for twelve. The GPU's few thousandths are one draw call for every trail and one per motor; the frame's CPU and
wall time move by less than they move between two launches with nothing in the air, so no claim is made about them.
**FINE had 479 of the 512 segments in use with twelve missiles up** -- the second salvo on top of the first's trails --
so a sky with more than about a dozen burning at once starts taking the oldest segments back.

### CONTRAILS: A MISSILE'S TRAIL, WORN SHORTER

Asked for on 2026-09-13: contrails behind aeroplanes above 300 m, shorter than a missile's. `ContrailYard`, beside
`MissileYard` under the level, lays two behind every winged aircraft with an engine that it is drawing, from the
wingtips `VehicleLights.wingtips` puts the nav lights on. Nothing about it is on the wire: every machine lays its own
from the poses it already draws.

- **It is the missile yard's trail, not a second one.** A second MultiMesh of the same segments, wearing the missile
  yard's two materials and stamped on its clock, so the one `now` written a frame serves both. What makes it shorter is
  an instance uniform on the node, `lasting`, set once to `TrailTuning.CONTRAIL_SHARE` (0.3).
- **One life, in one place.** A missile trail's life was the shaders' uniform default (14 s PLAIN, 22 s FINE), which
  headless cannot read; it is `TrailTuning.missile_life` now, written onto both materials once, and a contrail lasts 0.3
  of it: 4.2 s PLAIN, 6.6 s FINE.
- **Faded in, never switched.** Strength is a smoothstep over 280--320 m of world Y, times a speed gate from 20 to
  35 m/s, times a tiltrotor's nacelles going out between tilt 0.25 and 0.5, handed to the drawer at each END of a
  segment; and a contrail comes in along its length from each pixel's own age (see "A contrail comes and goes along its
  length", below). The slowest winged cruise the simulation reports is the Cessna's, 49.4 m/s (the
  aeroplane 71.9, the airliner 65.1, the Osprey 74.3, the tanker 52.0), so every one of them flies at full strength.
- **Nothing grows, nothing is touched again.** A segment every 0.2 s a trail, the oldest of 2,048 taken back first. With
  the island's own traffic and twenty winged aircraft added (93 machines), 28 trailing kept 1,638 in use on FINE and
  1,224 on PLAIN after ten seconds of laying; 2,048 holds 31 trailing on FINE, and past that what is taken back is the
  oldest and faintest end of a trail.
- **Length at cruise:** the aeroplane's contrail is 302 m PLAIN and 475 m FINE, the Cessna's 207 and 326. A missile's
  trail is laid only while its motor burns: a heat missile's is 609 m over its 2.5 s burn and a radar missile's 1,211 m
  over its 4 s, lasting 14 s or 22 s. The longest contrail, the Osprey's 491 m on FINE, is shorter than either
  (`tests/contrail_shot.gd --views=lengths`, one aeroplane a station: a second launch from the same aeroplane was
  refused, on the same tick and a second later).

Rejected: materials of its own (a second `now` a frame, and a second life to keep shorter than the first); a segment
growing behind each wingtip every frame, as a missile's does behind its nozzle (a transform write per aircraft per
frame, for a gap nobody sees from a cockpit); its own lifetime typed beside the missile's; trails from the engines
(nothing in the catalogue or the shape table says where an engine is -- under WHAT IS NOT HERE YET).

**Missile trails are unchanged.** `tests/scenery_shot.gd --views=missiles --missiles`, eight missiles up on PLAIN and
sixteen on FINE, HEAD's files against these with `CONTRAIL_ALTITUDE` pushed out of reach: 0 pixels moved by more than 8
of 255 on either finish, the largest difference 1. With the contrails on, 1,179 pixels moved on PLAIN and 10,523 on
FINE, all of them the salvo aeroplanes' and the traffic's new contrails -- which is why the comparison had to be made
with them off. `tests/missiles` and `tests/missile_cues` pass.

**What it costs**, `tests/contrail_shot.gd --views=contrail_cost --traffic=20`: 93 machines, 26 to 28 of them trailing,
240 frames each, contrails and none alternated three times a finish, windowed on the stock editor, in two passes under
load from the other lanes. The `contrails` lap read 0.048 to 0.084 ms on FINE and 0.061 to 0.210 ms on PLAIN -- the
0.2s in the two launches where the other lanes had the frame's CPU at 4 ms against 1.3 either side. The GPU median moved
by 0.000 to 0.004 ms against none (PLAIN 0.205 to 0.211, FINE 0.428 to 0.436). The frame's CPU moved more between
launches than between the arms, so no claim is made about it.

`tests/scenery.gd` holds it through the level: two aeroplanes put up by the server either side of the band, 421 m with
10 segments laid and 181 m followed and laying none, and the lives read off the materials against `TrailTuning` (22.00 s
and 6.60 s on FINE). RED first: the yard ignoring the height laid 10 segments at 181 m; `CONTRAIL_SHARE` 1.2 made a
contrail of 26.40 s; and `MissileYard` writing no life read 0.00 s for both.

**The pictures**, `tests/contrail_shot.gd --views=contrail_behind,contrail_side`: from astern and above, two white trails
run back from the jet's wingtips, thin on PLAIN and wider and billowing on FINE; from below and abeam, the jet and its
twin trails stand against the sky and in front of a cloud. The first poses were wrong -- astern looking back down the
trail put the ribbon a few metres under the eye as a white smear with no aeroplane in frame, and abeam from level with
it the trail lay along the clouds at the horizon -- so the camera looks at the aeroplane from astern and stands 250 m
abeam and 120 m below. And the probe's first count of segments in use read 624 of an expected 1,716, because it counted
after the arm with no contrails, when four seconds of them had faded; it counts at the end of the arm that lays them.

### A CONTRAIL COMES AND GOES ALONG ITS LENGTH, AND IS LIT BY THE TIME OF DAY

Asked for on 2026-09-14: "reducing the brightness of the contrails at night, also, the contrails should fade in more
slowly, it's a little obvious they are chunky. could you use a shader to have them fade in and out more evenly".

**What made it chunky, found before it was fixed.** `tests/contrail_shot.gd` takes strips now, not single frames:
`contrail_band` (an aeroplane put 30 m over the band and sinking through it, pictures at 325, 310, 300, 290 and 270 m)
and `contrail_ageing` (flown above the band, taken away at 5 s, pictures at 5, 6, 7, 8.5 and 10 s), each with a `.json`
of where the aeroplane's path is on the screen. What they and the code showed:
- **The head came in a segment at a time.** `forming` thickened a WHOLE segment by the age of its NEWER end, over 0.5 s:
  two neighbours laid 0.2 s apart stood 0.4 of full strength apart, and the head of the trail arrived as a 16 m block
  every fifth of a second. The biggest cause, and the one a pilot sees on every contrail.
- **The height band stepped at every join.** A segment carried one strength, the mean of its two ends, so neighbours
  differed by half of what the strength moved over two samples: 0.0684 at a join, sinking through the band in
  `tests/scenery`. Smaller, and only while crossing the band.
- **Not the rest.** The tail was already continuous (the square of what is left of the life, at each end); the speed gate
  only bites below 35 m/s, which no cruise is; the segment length (16 m at 80 m/s) is only seen through the two above;
  and nothing about a contrail is dithered.
- **And unshaded meant as white at night as at noon**: the night pictures read the trail 0.7 of full brightness over
  the sky beside it.

**The fix is in the two trail shaders, behind `forming > 0`**, which only a contrail sets:
- **Each end carries its own strength**, in the instance colour's red and green (`ContrailYard` turns `use_colors` on
  for its own drawer; the missile yard's has none and reads white), so where one segment ends the next begins at the
  same strength.
- **How much trail there is, is worked out per PIXEL from that pixel's own age**: nothing for the first
  `CONTRAIL_SAMPLE_EVERY` (0.2 s, so the segment just laid is nothing at its newer end and the head never arrives in a
  piece), smoothly in over `CONTRAIL_FORMING` (1.0 s, 80 m at the aeroplane's cruise, was 0.5 s), and smoothly out
  over its life (`1 - smoothstep(0, life)`, which holds more of a contrail's middle than the square did).
- **Lit by the time of day as a cloud is.** `ContrailYard.light_at` is the sun and sky light `LiftYard.cloud_light`
  gives a cloud at that time, taken to linear as the cloud shaders' `source_color` uniforms take them, over day's:
  (1, 1, 1) by day, (0.90, 0.45, 0.24) at evening, (0.013, 0.016, 0.025) at night. An instance uniform on the
  contrails' node, written once per change by the level, beside the lift yard's.

Rejected: a night factor of its own in `DaylightTuning` (a second number to keep agreeing with the sun and sky beside
it); dimming the shared trail material (every missile's smoke goes dim too); packing two strengths into the custom
alpha (the instance colour is free, and a missile's drawer reads white without being touched); and fading by distance
along the trail rather than age (a segment's two ages are already on the instance; its distance from the aeroplane
is not).

**Held by `tests/scenery`**, through the level: the light read off the contrails' node after the level's own
`choose_time`, white by day and the clouds' ratio at night; and an aeroplane put 30 m above the band, followed down to
300 m (10.0 s), whose last sixteen segments' ends -- strength 0.97 down to 0.14 -- meet at the same strength, the
largest step 0.0000 against a bound of 1/255. THE BOUND: every factor of a trail's alpha is 0 to 1, so strengths that
differ by d at a join move no pixel by more than d, and under one 8-bit level nobody can see it. Headless has no shader
and its MultiMesh keeps no custom data or colours (a dummy drawer read back zeros), so the test reads what the yard
handed the drawer (`ContrailYard.laid_behind`); that the shaders fade by those ends and each pixel's age is in the
pictures. RED first: on the old yard the light read null twice and the step was 0.0112 (put in the band) and 0.0684
(the final form, sinking through it) with the strength averaged back.

**The pictures**, on forward+, `C:\Users\Graham\godotgames-drafts\2026-09-14\cockpit-contrails\before-forward` (main's
contrail files) and `after-forward`, band, ageing, behind and side, PLAIN and FINE, day, evening and night; `before` and
`after` beside them are the same on the mobile renderer. After: at night a faint grey line against the dark instead of
a white one; at evening the orange of the clouds round it; from abeam the head comes in over about twice the length it
did (the first two tenths of the trail on the band strip read 11 and 10 of 255 over the sky on PLAIN and 9 and 16 on
FINE, against 20 and 30, and 20 and 36, before) and the body holds longer before it goes. PLAIN by night on the band
strip followed a traffic aeroplane at 434 m instead, both times, and is not a picture of the band.

**Missile trails are unchanged.** `tests/scenery_shot.gd --views=missiles --missiles --time=day,night`, HEAD's shaders,
yard, tuning and level against these, with `CONTRAIL_ALTITUDE` pushed out of reach in both so the traffic's contrails
are not in the comparison: PLAIN, eight missiles and 96 segments by day and sixteen and 360 by night, 0 pixels moved by
more than 8 of 255 and the largest difference 0; FINE, twenty missiles and all 512 segments, 0 pixels moved, the
largest difference 3 by day and 5 by night, on the mobile renderer. Again on forward+ after the rebase, main's files
against these: 0 pixels moved on either finish, the largest difference 0 on PLAIN and 1 on FINE.

**What it costs**, `tests/contrail_shot.gd --views=contrail_cost --traffic=20 --old_shaders=<HEAD's two shaders>`:
the new shaders against HEAD's on the contrails' own material, in one process on one sky, new then old three times a
finish, 240 frames each, windowed on the stock editor (RTX 5080, d3d12) with the other lanes working on the machine.
996 to 1,604 contrail segments in use. GPU medians, new against old: PLAIN 0.204/0.204, 0.206/0.206, 0.208/0.208 ms;
FINE 0.442/0.443, 0.445/0.443, 0.443/0.443 ms -- between -0.001 and +0.002. The frame's CPU moved by up to 0.11 ms
either way between arms, both signs, so no claim is made about it; the yard's own work is one more colour write per
segment laid (two every 0.2 s an aircraft). The old shader in that A/B read every strength as 1, so if anything it
drew more blended pixels than it would have had.

**Not fixed, and seen:** FINE from close behind shows bands across the trail at about a segment's spacing, before and
after, in the settled middle of the trail where strength and forming are both 1 -- so not the fade. PLAIN does not.
Suspects, neither proven: each segment turns about its OWN direction to face the eye, so two neighbours on a path that
bends slightly twist differently where they meet, which matters most seen nearly end-on; and the billow noise is fed
the yard's clock (thousands of seconds) times 3.1. The close-behind trail still reads as a wide sheet (WHAT IS NOT HERE
YET, "A contrail from close behind").

### FIXED: A LAUNCH FROM THE SEAT WAS NEVER HANDED ITS LAUNCH CUE

For a morning a missile launched from a seat -- the LAUNCH bit on the pilot's own input frame -- did not give the
pilot's own client its `MISSILE_LAUNCH` cue. Found on 2026-09-13 by printing what `client.take_cues()` returned in
`Sim._capture_states`: a seat launch at physics frame 1010 got no launch cue while the same missile's `MISSILE_END`
arrived at tick 1533, and a seat launch later in the same suite, at 1835, did get one at 1841 -- which is how a check in
`tests/missiles` came to pass by the order of its sections, and why that suite still only prints the cue. Same
`Sim.client` throughout, not networked, `net_status` identical; the drain, the world and the level were all ruled out
before the library was looked at.

**The cause was in sync, and it was not the missile's** (ashiato-missile). Cockpit emitted a cue after the server tick,
stamped with the frame whose packet had already gone; sync erased a pending cue as acknowledged when the client
acknowledged that older packet, whether or not any packet had carried it. In the level -- 74 vehicles and 24 fires --
the pilot's own aeroplane is left out of most packets, so most cues on it died unsent: of 308 marker cues emitted on the
plane from GDScript, 3 arrived. A server launch or a tanker's release that did arrive arrived by luck. The loopback's
aeroplane rides in every packet, which is why it never saw this. Fixed in ashiato 5e14119.

`tests/missile_cues` is a seat launch and nothing else -- armed, the heat station, Enter held, `MISSILE_LAUNCH` counted in
`Sim.cues` and the missile drawn off the rail that cue named -- with a server launch off the other rail as the control.
Written as a repro before the fix and kept as its regression test:

- on ashiato ed0e3eb: `RESULT=FAIL and_the_launching_client_is_handed_its_launch_cue`
- on ashiato 5e14119: `RESULT=PASS`

### WHAT THE SUITE FOUND

`tests/missiles.gd` drives all of it through the level, the rig and the desk's own keys against
the real simulation, and a hand closed on the stick for the headset's half. Seven things went red
before it went green: five were the test's own, one the level's and one the runner's:

- **A target that flies itself flies away.** An autopilot put down the nose climbed to its recovery
  height and was 0.69 rad off the nose when the lock was pressed -- outside the radar's cone, so
  both seekers sat in SEARCH. The target is an unpiloted aeroplane on the server's own nose now,
  keeping pace.
- **The glass lags the lock by one feed**, above.
- **The pylon moves.** A missile first drawn 0.6 m from its pylon was failed as 76 m off, because
  the pylon was read a second later, after the aeroplane had flown on.
- **And the level never played a cue** -- the level's. See "A CUE".
- **The arm key is a step, not a level.** The heat section armed the seat, the radar section pressed U again, and
  eight checks downstream failed on "not armed" with every mechanism under them working. The key is pressed once in
  the suite now, and the later section asserts it is still armed.
- **Two targets on one nose.** The head-on heat case was spawned where the tail-on target still was, and "locked" --
  with numbers printed for an aeroplane nobody was locked on. Every target is despawned (and the despawn asserted)
  before the next, and every lock is checked against the SERVER's row, whose `target` is in the same numbers as
  `spawn_vehicle`'s answer; the client's row names the same aeroplane by the client's own id.
- **`run_all.ps1 -Only` does not import** -- the runner's. The first lint after `LockSight` and `MissileYard` arrived
  failed five scripts that reach them: `-Only` skips the `--headless --import` that registers a new `class_name`, so
  the classes were on disk and unknown. Run `--headless --import --path cockpit` once after adding a class, or run the
  whole list. The other way round is harmless: with the files taken out again a re-import left both names in
  `.godot/global_script_class_cache.cfg`, pointing at nothing, and lint still passed (2026-09-13).

## A WATER BOMBER, AND SOMETHING TO PUT OUT

The island burns. Nine fires, on hillsides and out towards the ring, each a strength between
zero and one -- and an amphibian with six tonnes of water in a hull tank that empties in five
seconds and fills in twelve by flying along the sea.

**It is a loop rather than a shot.** Find the smoke, fly the run, drop the load, go back to
the water. The tank is what makes it one: a full load well aimed is a fire out, and a full
load spread over a hillside is a two-minute round trip for nothing.

### WATER IS A THING THAT LEAVES AN AIRCRAFT AND LANDS, WHICH THIS FILE ALREADY KNEW

A drop is a `ShotState`. Not a metaphor -- the same component, the same archetype, the same
birth record on the wire, the same flight integrated by every machine that can see it, and
the same impact record at the far end. What differs is one branch: a round that lands makes a
hole, and water that lands **puts something out**.

That is the whole reason it is worth reusing. The alternative is a second entity kind with
its own replication, its own wound-forward-by-latency drawing and its own retirement, to say
the same three things.

So `kAmmoWater` is a row in the round table -- drag two orders above a shell's, because a
mass of water is mostly air resistance -- and a row in the renderer's, where it is the one
entry that does not glow. `ShotYard` draws a tracer additive and a mass of water in plain
alpha, spreading as it falls; `Burst` throws a white sheet UP where a shell throws dirt OUT.
Sixteen masses a second for five seconds is eighty of them, which overlap into a curtain.

**The doors are a lever and not a button**, on the console between the pilots. Six tonnes
takes five seconds to go, so what the pilot is doing is HOLDING the aeroplane over a fire
while the load leaves -- and the control that says that is a red handle that stays where it
is put. Either pilot can reach it, which is what a crew is for.

### A FIRE IS REPLICATED BECAUSE IT CHANGES

The scenery is not replicated at all: every peer builds the same mountains from the same
generator and the simulation never mentions them again. A fire cannot work that way, and the
difference is one word -- it CHANGES. Whether a fire is out is the fact this whole exercise
turns on, and two peers with different answers are two peers playing different games.

So `FireState` is a component and a fire is an entity: position, strength, one Step component
that changes by a sixty-fourth about once a second while it burns and several times a second
while somebody is dropping on it. `Terrain.fires()` says where they are, with the scenery,
because that is the file that knows where the mountains are -- and they get a clearance of
their own for the same reason a spawn does. A fire inside a hill is worse than an aeroplane
inside one: the smoke comes out of the rock and there is nothing to aim at.

**Water douses a flat radius and nothing outside it.** A soft edge would make a sloppy pass
worth something everywhere, and what this aeroplane is about is putting the water ON the
fire. Measured: one full load along a track puts out the fires under the swathe and leaves
one 240 m to the side at full strength.

**And a fire left alone comes back**, at two per cent a second -- slower than the round trip
to the sea, so a fire you have knocked down is one you have time to finish rather than one
that races you.

### THE SMOKE IS THE HALF THAT MATTERS

A fire is a small bright thing on a fourteen-kilometre island and the aeroplane looking for it
is two thousand feet up. Flames are invisible from there. What a pilot flies towards is the
COLUMN, so `FireYard` draws 260 m of smoke leaning downwind, sized by strength, never culled
-- and the flames only exist for the last few hundred metres of the approach.

Two things that only a picture showed. The column has to start ABOVE the flames: drawn from
ground level, its thickest darkest puff sits exactly where the fire is and what you get is a
dark ball with a fire hidden inside it. And it needs enough puffs to OVERLAP, or a column is
a string of beads.

**The flicker is local and the strength is not**, which is the split this whole project runs
on. How hard a fire is burning comes off the wire; what the flames are doing this frame is a
sine wave on this machine and never on any wire at all.

### SCOOPING IS ASKED OF THE PHYSICS, NOT OF THE MAP

Three conditions, all at once: below fifteen metres, between 25 and 62 m/s, and **nothing
solid underneath** -- a ray cast straight down that finds nothing. The island is a slab and
the sea is not, so the simulation needs to know nothing about where the coast is, which is as
well: the coast is generated in the game layer and is not replicated at all.

Any two of the three is an aeroplane doing something else. Fast and low over the sea is a
transit; slow and low over the land is a landing.

### THE TANK IS A FLOAT ON THE SERVER AND A BYTE ON THE WIRE

The first version held it in the byte alone and the tank never emptied at all. A five-second
drop at 120 Hz moves the gauge by four tenths of a step per tick: read the byte, subtract
four tenths, round, write the byte, and the answer is the number you started with, for ever.
Anything integrating at the tick rate has to hold its own precision -- exactly as `flight_`
does for a shell.

It rolls back COARSELY, at eight steps of 255. A client flying its own tanker sees the gauge
arrive on a rollback, which is the same bargain the turret already makes: a step of a dial a
third of a second late, against resimulating the world for it.

### THE SEVENTEENTH KIND COST A BIT, EXACTLY AS PREDICTED

`VehicleKind` was four bits and sixteen kinds filled it exactly. This file said in advance
that the next vehicle was a wire format change; it was, and it was two lines -- five bits for
the kind and five for `kind_wanted` on the input frame.

**The sentinel was the trap.** "No kind in particular" was 15, which is one past the last
kind while there are sixteen of them and IS THE GUNSHIP the moment there are seventeen --
and `switch_kind` reads anything below `kKindCount` as a kind somebody named. Pressing "next
craft" would have taken every player to a gunship. It is `kNoKindWanted` = 31 now, written
down once in the C++ and once in `Sim`, and the test asserts it is out of range of every
kind rather than that it is any particular number.

### AND AN AUTOPILOT IS SEEDED BY WHERE IT WAS PUT, NOT BY ITS ENTITY ID

Adding two water bombers to the far side of the island broke the formation test: the flights
went from a median of one metre to thirty, with nothing about the guidance touched.

Entity ids are handed out in spawn order, and the autopilot's random stream was seeded from
one. So inserting a single vehicle ANYWHERE in the spawn list shifted the id of everything
after it and reshuffled the routes of the entire hundred-and-forty-machine world -- a
different world, flown by the same autopilot, which happened to be sampled mid-turn more
often. It looks exactly like a regression and is not one.

Seeded from the spawn POSITION, adding an aeroplane somewhere else leaves every existing
machine flying the route it flew before. Two vehicles spawned at exactly the same spot would
share a stream, which is a thing the spawn table cannot do -- two machines in one place is a
collision before it is a coincidence.

### A CUE: A MOMENT ON THE WIRE, AS OPPOSED TO A FACT

The tank doors opening is TWO things and they belong in two different places.

**That the doors are open is a fact.** It is a bit on the bus, it stays true for the next
five seconds, and anybody who joins mid-drop has to see open doors and a half-emptying tank.
A component says that, and a component is asked for as often as anybody likes because it is
still true.

**That they opened, just now, is a moment.** No component can say it. The first white gush
out of the belly happens once, at an instant, and a machine that reads a component twice
would draw it twice.

That is a CUE, and ashiato-sync has had one all along -- `CraftCue` is the first use of it
in this game. A cue is a typed payload attached to an entity and **stamped with the frame it
happened on**, delivered once to everybody who can see that entity, with a relevance window
after which it is dropped rather than played late.

**The path is: client asks, server says, everybody plays.** The pilot's lever is an ordinary
bus command on their own input frame. The server applies it inside the frame that command
belongs to, and emits the cue from there -- so the frame stamp is the frame the PILOT pulled
the lever on, not the frame the packet happened to arrive on. Measured across a three-machine
session: the client that pulled it and a client that was only watching both file the release
under frame 192, and each of them is told how late it is so the burst starts that far in
rather than at its beginning.

**One cue type with an event number in it**, rather than a type per event. Registering a cue
costs a traits specialisation, a serialiser and a line in `start`; a new EVENT costs a
constant. The next thing that wants a moment -- a ramp thumping down, a hand raised, an
animation started at a frame -- should not have to think about any of that.

Three things it is easy to get wrong and this got right by measuring:

- **An edge, not a state.** Emitting while the doors are open is one cue per tick for five
  seconds. It is emitted on the transition, and a tanker nobody has seen before has its doors
  shut -- an `emplace` with a default of true, or the first drop of every aeroplane's life is
  the one with no gush at the front of it.
- **Entity ids are per world.** The server's tanker and each client's copy are different
  numbers; sync maps between them, and the cue arrives naming the LOCAL one, which is what
  makes it usable by a renderer that looks vehicles up by id.
- **The list is drained by the reading.** `Sim.cues` is the only thing in that file that is
  not a poll, and `sky.gd` is the only place allowed to read it.

**And nothing read it.** `FlightLevel._play_the_cues` was written with the water bomber and no
line in the game ever called it: `Sim.cues` is replaced on every physics frame, so every release
gush was delivered, measured on the wire, and thrown away unplayed. The measurement above was
taken at `CockpitWorld`, below the level, which is why it never showed. It is called first thing
in the level's `_physics_process` now, on the tick that brought the cue and before anything that
returns early. Found on 2026-09-13 by the missile work, whose launch cues were never played
either; `tests/water.gd` now opens a tanker's doors through the real level and waits for the
burst at the belly.

And one it found in code that had been there for months: **every explosion in the game had
been drawing its sparks at the world origin.** `Burst` positioned them with
`look_at_from_position`, which -- as its own documentation says -- MOVES the node in GLOBAL
space, so an offset meant as "half a metre from the burst" was applied as "half a metre from
the middle of the map". Sparks are small, additive and were landing out at sea, so nothing
ever showed it until a water bomber dropped at forty metres and a handful of white specks
appeared on a hillside a kilometre away.

Playing it is `SyncCueTraits<CraftCue>::play`, which has a registry, an entity and no way at
all to reach a renderer -- so it writes into `CueLog`, a local singleton the game drains once
a tick. There is a `rollback` beside it for a cue a client PREDICTED that turns out not to
have happened; nothing here predicts one, because an effect that has to be un-drawn is worse
than one that starts a round trip late.

### WHAT IS NOT HERE

**The water does not weigh anything.** Six tonnes leaves the aeroplane over five seconds and
the handling does not change, because mass is in the shape table and the body is built from
it once. A real tanker is a different aircraft empty.

**The water does not weigh anything** -- see above. That one still stands.

### AND NOW THEY SPREAD

`FireFront`, in `world/fire_front.gd`. This file said for a long time that fires "grow back
and they go out; they do not light their neighbours -- that is one constant and a cap away,
and it is the thing that would turn nine fires into a job you can lose". Here is the constant
and here is the cap.

**IT COSTS NOTHING ON THE WIRE, which is why it is GDScript.** A fire is already an entity
with a replicated `FireState` and `light_fire` already makes one, so spreading is nothing but
lighting more of them -- and a spawn is the server's alone, exactly like every vehicle in the
world. No component, no field, no quantiser, no bit. A client finds out a hillside has caught
the same way it finds out an aeroplane took off.

**The randomness MAY be the engine's here**, and that is worth saying because `Terrain`
spends nine lines avoiding it. The scenery is not replicated -- every peer generates it, so a
generator that changed under an engine upgrade would desync everybody -- and a fire IS
replicated. Only the server rolls this dice and everyone else is told the answer. It is
seeded anyway, so two runs of the suite fight the same fire.

**One clock for the whole front, not one per fire.** The accumulator advances by `delta`
times the number of fires burning HARD, so nine fires spread three times as fast as three --
which is the shape that makes this a job you can lose rather than a timer you can ignore. A
per-fire timer would want a table keyed by an entity that comes and goes, and would give a
fire nobody can reach the same urgency as a row of them over a city.

**What makes a fire "attended" is its own strength, and nothing watches the tanker.** There
is no flag. A fire below `SPREAD_FROM` (0.55) is not making enough heat to light anything,
which is exactly the state a full load leaves one in -- so the mechanism and the gameplay are
one sentence.

The numbers, and the measurements they produce on a bare world ticked by hand:

| | |
|---|---|
| `SPREAD_SECONDS` | 30, at full strength: roughly the tanker's round trip to the sea |
| `MAX_FIRES` | 24, from the nine the world starts with |
| `SPREAD_FROM` | 0.55 -- below it a fire lights nothing |
| `SEEDED_AT` | 0.22, so a new fire is visibly younger than its parent |
| one fire alone lights its first neighbour in | **31 s** |
| and its second in | **23 s** |
| a fire left at half the threshold spreads again after | **44 s** |
| an unfought front reaches the cap and stops | **24 of 24**, and stays there |

**A NEW FIRE IS A FUSE RATHER THAN A SECOND BURNER**, and the suite found that by being
wrong about it. Two fires bank the clock twice as fast as one, so the obvious expectation is
that the third arrives in half the time -- and it does not, because a fire seeded at 0.22 is
not HOT until it has grown back through 0.55, which is about seventeen seconds. The front
builds rather than doubling, which is a better shape than the one the test assumed, and it
falls out of the regrowth rather than being tuned.

**And the regrowth is faster than it reads.** Two per cent a second sounds slow until you
work out what it means for the threshold: a fire knocked to half of `SPREAD_FROM` is back
over it in thirteen seconds and lighting neighbours again at forty-four. That is this file's
own sentence -- "a full load spread over a hillside is a two-minute round trip for nothing"
-- as a number. Put a fire OUT or do not bother.

**A spread fire earns the same clearance a placed one gets.** `Terrain.can_burn` keeps it off
the rock and inside `FIRE_REACH` (5000 m), because a fire inside a hill is worse than an
aeroplane inside one: the column is 260 m of smoke coming out of solid rock with nothing at
the bottom of it to aim at. Six attempts and then it gives up on that parent, so a fire hemmed
in on a ridge spreads slower rather than stalling the whole front.

**THE DEBRIEF IS ON THE BOARD.** One line on the clipboard, above the tabs' own answer line
and on every tab, because a score you have to go and find is a score nobody looks at: how
many are alight, what the cap is, how many are out, and how many the fire lit itself. It says
THE ISLAND IS LOST at the cap and EVERY FIRE IS OUT at nothing, and it does not end the
session -- which is the honest amount of game this is, since there is nothing yet to restart.
`FlightLevel` owns the front and writes the sentence; the board draws it and has no idea what
a fire is.

**On the physics clock**, five debriefs a second. A fire spreading happens in the world, so a
machine drawing at ninety frames must not burn faster than one at sixty -- and a line of text
on a render target formatted a hundred and twenty times a second is the mistake two sections
of this file are already about.

`tests/fires.gd` is the suite, all of it on a bare `CockpitWorld` and a bare `FireFront`
ticked by hand: twenty minutes of fire in one frame, and every number above is a count rather
than a sample.

**What is still not here:** nothing hurts, nothing burns down, and the AI tanker does not
fight them, so an unattended world always reaches the cap. The next thing is an autopilot
that flies the loop, which would make "nine fires and one aeroplane" a thing you can watch
from the observer.

## A SHIP UNDER SAIL

Asked for on 2026-09-15: "create a pirate ship, the ai should drive it around, and it shouldn't be part of the group of
craft that the user can switch to (yet). please add sails and have it correctly sail around the ocean."

`Sim.Kind.PIRATE` is a brig: 30 m on deck, 8 in the beam, 220 t at real scale, two masts, square sails on both, a jib
and a spanker. Its movement model is `Model::Sail`, `sail_ship` in `../../ashiato-gd/src/cockpit/cockpit_world.cpp`, and
the arithmetic of a sail is `../../ashiato-gd/src/cockpit/sail_plan.hpp`, which has no Godot or Box3D in it.

### The wind is a function of the frame

`../../ashiato-gd/src/cockpit/wind_field.hpp`. A direction the wind comes FROM and a speed, each the sum of two slow sines
(7 and 3 minutes for the speed, 10 and 4 for the direction). The phases are hashed from a seed. Weighted 0.7 and 0.3,
the sines cannot leave [-1, 1], so the speed never leaves [`low`, `high`] and the direction never leaves `from` ± `veer`.
`set_weather({from, low, high, veer, seed})` sets one; `set_wind` is the same field held steady.

- **Keyed to the frame, never a clock.** A resimulated tick computes its original's wind, and two peers told the same
  weather agree to the bit with nothing on the wire. The standing swell does not travel because there was no frame to key
  it to; the wind reads `FrameInfo.frame`.
- **Who feels it is `air_at`'s decision, as before.** A wing feels it unless the world says `set_wind_on_wings(false)`;
  a ship under sail reads the field itself, because its hull's forces are against the water.
- Measured by `tests/sailing.gd`, 5 to 12 m/s: 5.02 to 11.86 m/s and 48 degrees of veer over thirty minutes; two worlds
  agreed on 180 of 180 samples, and a second seed differed on 178.

### A sail is a wing stood on its end

Each sail is a flat plate: lift square to the apparent wind (the world's wind less the ship's velocity), drag along it,
by angle of attack from a curve per sail type. Each force is applied at that sail's own height and mast, so heel, weather
helm and a bow pressed down all come out of Box3D and none is typed.

- **The no-go zone is not coded.** It comes from how far a yard can be braced round (45 degrees off the keel), how
  close a boom sheets (17), and the angle lift peaks at. Closer to the wind than that, no setting of the sails makes lift
  point forwards against the drag. Yards to 38 and booms to 12 made 2.1 knots along a course 40 degrees off a ten-metre
  wind, which no brig does.
- **Two levers, by mast.** ROLL trims the foremast (fore yards and jib) and PITCH the mainmast (main yards and spanker),
  THROTTLE is how much sail is set and RUDDER the helm. With one lever for every yard the ship could not tack: every yard
  swung as the bow met the wind, nothing pushed the bow across, and it lay in irons and gathered 1.8 m/s of sternway.
- **The keel makes lift from leeway** in proportion to the way on, so a ship barely moving is blown sideways, and a
  tack needs way.
- **The rudder bites with the water going past it**, and reverses going astern; the helmsman shifts the helm when the
  ship gathers sternway.
- **The hull floats on six probes whose spread is derived from a metacentric height.** A boat's four corner probes
  on a 30 m hull are 22 MN m a radian stiff in roll against 0.2 MN m of sail, half a degree of heel. For vertical forces
  at `spread` either side and `p` above the centre of mass the roll stiffness is k·spread² + W·p, so
  spread = √(W(GM − p)/k), with k the waterplane's ρgA and p set so the keel settles at the draught. It floats on
  `swell_height`, the simulation's sea, and not on the FINE finish's drawn sheet.
- **Hull speed is derived from the waterline**, 1.34 knots per root foot (6.6 m/s for 27.9 m), and the bow wave
  starts to cost at 0.8 of it.

Every rig number is a `set_handling` key (`rig_*`, `square_*`, `fore_*`), and `tests/sailing.gd -- --tune=key=value;...`
runs the whole suite on a tuning, so the sail plan was swept with no rebuild.

### How it sails, measured

`tests/sailing.gd`, hand-ticked worlds at 120 Hz, a steady ten-metre wind. Each brig's own helmsman holds a course
(`hold_course`) and trims to the apparent wind. Knots are made good along the heading between 60 and 150 s, starboard
tack:

| off the wind | 30 | 40 | 50 | 60 | 70 | 90 | 110 | 130 | 150 | 180 |
|---|---|---|---|---|---|---|---|---|---|---|
| knots | -3.8 | -1.4 | 2.3 | 4.2 | 5.7 | 7.1 | 7.4 | 7.0 | 6.5 | 6.1 |
| heel, degrees | | | -3 | -6 | -9 | -8 | -4 | 0 | 0 | 1 |

- A beam reach at 7.1 knots, against a brief of six to nine.
- Nothing made good inside 45 degrees, and pointing at 50.
- A broad reach at 7.0 against a dead run at 6.1.
- Leeway 4 degrees on a beam reach; every course from 60 degrees held within 1.
- **Going about**, from 65 degrees on one tack to 65 on the other: head to wind the sails drive it nowhere and the fore
  yards are aback. It is on the new course within 10 degrees in 24.8 s, with a sternboard of 0.32 m/s at worst and the bow
  never falling back, and back to 2.6 m/s two minutes later.
- **Heel** to leeward: 3, 9 and 15 degrees on a beam reach in 5, 10 and 14 m/s.
- **Afloat for ten minutes** on a beam reach in a 7 to 12 m/s wind: never dry, never laid past 30 degrees, heaving
  0.38 m on the swell, deck never under.
- **Two worlds built alike** in a wandering wind end in the same state to the bit.
- **Nobody sailing it**: no sail set and no drift in a minute of a 12 m/s wind.

**Tacking was tuned, and the numbers say what each fix bought.** The polar did not move across any of these.

| helm turn | yaw damping | rudder | fore yards released at | on the new tack | worst sternway |
|---|---|---|---|---|---|
| 0.06 rad/s | 2 MN m s | 3,700 | 0.6 rad | 71 s | 1.73 m/s |
| 0.12 | 2 | 3,700 | 0.6 | about 45 s | 0.92 |
| 0.12 | 1 | 6,000 | 1.0 | 25 s | 0.32 |

### Every machine sees the sails: `Rigging`, on a Ship archetype

A machine that is only watching a ship never simulates it, so it does not know the wind and cannot tell a full sail from a
slack one. The server publishes what `sail_ship` reported as `Rigging`, a Step component:
- the fore and main levers (8 bits each), the sail set (8), each group's fill (8 each), and the apparent wind's angle
  off the bow (8) and speed (6), 70 bits a record;
- written by `publish_rigging` after the job, beside `publish_routes`, and **only when a field moves past its step**: a
  lever 2 of 127, the set 3 of 255, a fill 6 of 255, the angle 3 of 256, the breeze 1 m/s.

**It goes on a Ship archetype**, built from the same list as the Vehicle archetype plus `Rigging`, so none of the craft
without sails carries it or pays for its first send. `vehicle_rigging(entity)` reads it on any machine, and
`Sim.vehicle_rigging` is what `VehicleView` hands the drawing.

`tests/pirate_wire.gd` stands a server and a client up behind a four-tick fake link, with a brig holding a beam reach:
- the client draws it at worst 0.14 m from the server's, against an allowance of 1.65 m (its own travel over the ticks it
  is drawn behind, doubled for the heave, plus a metre), over 240 samples, with no clamps;
- its levers arrive within 0.012 and its fills within 0.002 of the server's;
- holding its course, it wrote its rigging 0.03 times a second.

### The brig drawn is the brig simulated

`objects/vehicles/brig/brig_rig.gd` (`BrigRig`) builds the hull, masts, yards, sails, jib, spanker, rudder and flag from
`kind_geometry(PIRATE)["rig"]`: each sail group's area, centre of effort, and how far round its yard or boom goes, plus
the waterline. Each square group is a course and a topsail, sized so their area is the group's and their centre of
effort is at the group's height. `trim` turns each group's pivot to the angle its lever sets, bellies each sail by its
group's fill to leeward (`sail.gdshader`, opaque), shivers a slack sail, and streams the flag along the apparent wind.
It is built in `VehicleView.setup`, not in `_build_wing`, which returns before any body branch on a craft with no span.

`tests/brig.gd` holds the arithmetic between the rigging and the drawing, against the simulation's table and the
physical meaning of a lever rather than the drawing's own formula:
- a yard let go lies athwartships;
- hauled right in, it lies at the rig's closest angle off the keel, its aft end on the lever's side, on both masts at
  both signs;
- each sail is handed its group's fill times the sail set, and bellies the other way when the wind crosses the bow.

`return` in a spatial shader's `vertex()` is refused by Godot's compiler as a SHADER ERROR, which the gate fails on. The
flag branch is an `if` and an `else`.

### What the first pictures found (2026-09-15, `tests/pirate_shot.gd`, the double editor, PLAIN and FINE)

Every one of these passed every suite, and every one was wrong on screen.

| seen | cause | now |
|---|---|---|
| a full square sail from astern was a flat white slab | the belly moved the vertices and left every normal flat, so it was lit as a card | `sail.gdshader` bends the normal by the belly's slope over the sheet's size; the belly is a seventh of the sail's width, from a ninth |
| a screen-door stipple across the canvas | shadow acne: a bellied double-sided sheet shadowing itself | sails cast no shadow |
| a speckled seam down each square sail | the sails hung on the mast's own axis, so a belly pressed aft went through the mast | square sails and their yards hang 0.55 m forward of the mast; an aft belly is notched to nothing at the mast and shallower |
| the ship seemed to hover over the sea | not a fault in the floating: beside the picture, the centre of mass was drawn at y -0.51 against the PLAIN sea at -0.02, the rig's 0.55 m waterline. A black boot-top on black topsides, and a flat PLAIN sea under a hull heaving on the simulated swell, let the copper's top edge show | the boot-top runs from 0.7 m under the waterline to 0.6 m over; PLAIN's sea rises and falls on the swell (below); `tests/sailing.gd` samples the simulation's swell at midships through its ten-minute float and holds the sea between the drawn keel and rail and on the rig's waterline |
| the beam-reach and dusk pictures were of the sea from underneath | the probe posed its camera along the heeled ship's right axis, which dropped it 9.3 m at 7.6 degrees of heel | the probe poses off flattened axes, and prints the ship's, the camera's and both seas' heights beside every picture |

**A BRIG'S WATERLINE IS MORE THAN HALF WAY UP ITS HULL.** 3.3 m of draught under 2.2 m of freeboard amidships is 60 per
cent up from the keel; HMS Beagle, 27 m, drew 3.8 m. Held between a half and seven tenths by `tests/sailing.gd`.

What is still not right, and is step 4's: nothing marks where the hull meets the water (no bow wave, no wake, no foam at
the waterline), so from low and close the join reads as a clean line rather than a ship pushing water.

### A wrap is seamless only if the swell is periodic in it (FIXED 2026-09-15, twice)

`swell_height` wrapped its inputs at 2,048 m with `std::fmod`, which keeps the sign. The ocean shaders' `tile()` is
`p - period * floor(p / period)`, always positive, and the comment said the two wrap "exactly" alike. They did only for
x, z >= 0. At x = -100 the shader tiles to 1,948 and fmod answered -100: a phase 2048 × 0.9762 × 0.030 = 59.97 rad apart,
3.13 rad after whole turns, nearly half a wave. So on the three quadrants of the sea with a negative coordinate, every
hull (launch, gunboat, carrier, battleship and brig) floated on a swell half a wave out of phase with the painted one.
Nothing showed it while the painted sea was normals only.

**The first fix moved the seam instead of removing it.** Changing the wrap to floor, to match `tile()`, left the wave
vectors as they were, and they were not whole waves across the tile: (0.9762, 0.2148) × 0.030 and (-0.3304, 0.9438) ×
0.041 fit 9.55 and 2.10, and -4.41 and 12.61, waves into 2,048 m. Wherever the wrap flips, the swell steps: 0.37 m at
z = ±2,048 under fmod, and under floor 0.82 m across z = 0 and 1.21 m across x = 0. `tests/carrier_shape.gd` found it,
not anything of the brig's: its 337 m carrier sails from the origin across z = 0 and tilted 2.67 degrees against its
1.5 degree bound, where it had tilted 0.97. The brig's float at (900, -700) never crosses an axis.

**The vectors are whole waves now**, (10, 2) and (-4, 13) of 2π/2,048 (`kSwellFirst`, `kSwellSecond`, `kSwellTile`):
wavelengths 200.8 and 150.6 m (from 209.5 and 153.3), headings 1.1 and 2.2 degrees round. Stepped across both axes and
the tile edge, the swell's step is zero under either wrap. **Check a wrap by stepping across every seam it can have**, not
by comparing two wraps' formulas: that comparison is what the first fix did.

Measured on `tests/sailing.gd`'s ten-minute float at (900, -700), which has a negative z:

| | fmod | floor, old vectors | floor, whole waves |
|---|---|---|---|
| middle of the hull | -1.30 to 0.19 m | -1.27 to 0.18 m | -1.30 to 0.09 m |
| heave | 0.366 m | 0.374 m | 0.372 m |
| most off upright | 11.1 degrees | 11.1 degrees | 11.4 degrees |
| beam reach | 7.06 knots | 7.07 knots | 7.08 knots |
| carrier tilt (`carrier_shape`, bound 1.5) | 0.97 degrees | 2.67 degrees | 1.06 degrees |

Two worlds still end identical, and `tests/water.gd` passes. **`tests/sailing.gd` asks the simulation's own
`swell_height_at` for the seam**, never a copy of the formula:
- pairs a centimetre apart straddle x = 0, z = 0 and x, z = ±2,048, every 37 m along each seam for 6 km;
- the worst step must be under 2 mm (the swell itself changes under 0.3 mm in a centimetre);
- the same samples must rise and fall by more than the swell's height, so a dead swell cannot pass;
- the shape handed to both seas must give the simulation's height within a millimetre in all four quadrants.

Its mutant puts the typed vectors back.

**The FINE sea now draws that swell.** `ocean_fine.gdshader` displaces its surface by the standing swell, as the base its
travelling chop rides on. The numbers come from `CockpitWorld.swell_shape()` through `Sim.swell_shape` and `SeaSwell`, off
the constants `swell_height` reads. It fades out between 350 and 600 m from the eye, because past there SeaSwell's growing
cells are too coarse to carry a 153 m wave.

**And PLAIN's sea does too, on the finish a headset starts on.** It was a 48 km `PlaneMesh` with four vertices, so every
hull heaved ±0.76 m on the simulated swell through a flat plane. It now wears SeaSwell's eye-following sheet
(`SeaSwell.carry`: the same mesh, moved with every snap even while the fine sea is hidden), and `ocean.gdshader` lifts it
by the same standing swell with the same wrap and fade. Its waves are still a painted normal.

**And a wind-sea on the swell that the boats feel (C1, cockpit-ocean, 2026-09-15).** Asked for: "yes add wind waves". The
swell is 150-200 m long and 0.8 degrees steep, so a launch under way barely rolled. `swell_height` now adds `kWindWaves`: three
standing waves 64, 40 and 26 m long, whole across the same 2,048 m tile and headed within 25 degrees of the swell, 0.35,
0.20 and 0.10 m high -- the wind-sea of the ships' weather's middle wind, fixed and not read from the weather a world is told
(see the comment on `kWindWaves` and WHAT IS NOT HERE YET). `swell_shape()` hands them on as `wind_waves`, each (x, z,
height), and both seas' sheets draw them to 170 m from the eye (full to 110 m), where the 3 m cells still hold a 26 m wave;
`WindSea.swell_slope_variance` counts them, so the painted sea carries that much less slope.
- **A hull three wind waves long rides through them** (team-lead's decision). Every float probe asks `sea_under`: a hull
  whose waterline, read from its shape, is at least three of the longest wind wave (`long_hull`, 191.9 m) floats on the
  swell alone. Long: the battleship (270.4 m) and the carrier (332.0 m). Not: the launch (5.6 m), the patrol boat (18.0 m),
  the brig (30.0 m) and the submarine (114.9 m). On four probes the carrier read each short wave as a tilt a hull that long
  averages out: tests/carrier_shape.gd's worst tilt five minutes under way was 2.74 degrees against 1.5 with the wind-sea
  under it, and is 1.06 on the swell alone; tests/far_out.gd's deck 64 km out, 0.456 and 0.223 mm against 0.36. Lowering
  the waves to three tenths also held the carrier (1.43) but left a launch rolling 0.19 degrees against 0.17.
- **What a small boat does over 60 s under way, with no wind-sea against with it** (tests/boat_motion_probe.gd, at 500, 1,
  500, after 20 s settling). Launch: roll sd 0.17 -> 0.55 degrees (worst 0.29 -> 1.41), pitch sd 0.40 -> 0.61 (worst 3.10 ->
  3.79), heave sd 0.382 -> 0.341 m. Patrol boat: roll 0.33 -> 1.12 (worst 0.59 -> 3.17), pitch 0.55 -> 0.85 (worst 2.05 ->
  3.00), heave 0.374 -> 0.443 m. Stopped, both settle and do not move: the sea stands.
- **Checked by** tests/sailing.gd (which kinds are long, and that a long hull floats on the swell alone and a short one on
  the whole sea -- its mutant gives every hull the wind-sea; and the drawn shape against the simulation's, whose mutant
  paints the sea without the wind waves), tests/ocean_height_shot.gd (every drawn pixel within 0.1 mm of `swell_height_at`;
  its mutant draws the plain sea without them) and tests/wind_sea.gd (Cox and Munk's slope with the wind waves counted).

**LEVEL HORIZON IN SMALL BOATS**, first on the clipboard's FEEL tab, off unless chosen and never sent. In a launch or a
patrol boat the rig takes the boat's roll and pitch off itself about the seat and keeps its heading
(`PilotRig.level_basis`, every render frame after `VehicleView.draw`); a carrier, a battleship or an aircraft is left alone.
tests/clipboard.gd sits a rig in a launch rolled 9 degrees, presses the switch with the right hand's beam, and holds the rig
level to 0.05 degrees on the launch's heading, and leaning with a carrier; its mutant makes no boat small.

- **Both seas paint the simulation's waves.** Their painted swell typed its own non-periodic vectors, so the painted
  slope stepped at every tile line too. It now takes `standing_first` and `standing_second`, handed over by one helper,
  `SeaSwell.hand_the_swell`, which both finishes and the carrier deck scene call. `wave_height` is gone.
- **The painted swell TRAVELS** (the wavelets take `t * 0.9`) where the simulated one stands, so near the eye a highlight
  runs across a shape that holds still. It reads as light on water.
- **Fog:** both ocean shaders are opaque and do not turn fog off, so the engine fogs them as before; moving the vertices
  does not change that. `scene_fog.gdshaderinc` is for shaders that take the fog themselves (the additive town lights).
- **Past 600 m a hull heaves against a flat sea.** ±0.76 m at 600 m is 1.3 mrad top to bottom, about 1.6 pixels of a
  headset's 0.8 mrad pixel (2,160 across 100 degrees), and under a pixel past about 950 m.
- **Vertices:** the sheet has 58,081 (printed by `tests/scenery.gd`), and a headset runs the vertex shader once per eye,
  so 116,162 vertex invocations a frame against eight for the quad; the fine finish already paid that. **Not yet priced
  in frame time**: PLAIN before and after, interleaved, waits for a timing slot with the GPU token.
- `tests/scenery.gd` checks the level's own nodes: the plain sea wears the fine sea's mesh, both seas' materials carry
  `Sim.swell_shape`'s height and first wave, and the sheet follows the eye on either finish.
- The hull's boot-top band, from the waterline −0.7 m to +0.6 m, is what makes the join read as sea against paint.

**THE SEAM STEP 2 SAID IT FIXED WAS STILL THERE ON PLAIN (found 2026-09-15, fixed on lane/pirate-sea).** Making the
standing swell whole across the 2,048 m tile unseamed only the swell. `ocean.gdshader` also handed its `tile()`d position
to the two chop wavelets, whose typed directions are not whole waves across the tile, and to the churn's `fbm2` at 0.012
(24.6 cells across it), so both still jumped wherever the wrap flips -- z = 0 and x = 0 among those lines. From
cockpit-mist's `sea_low` pose, 400 m off the island's edge on z = 0 looking along +x, it was a hard vertical line down the
middle of the water. The chop and the churn now take the unwrapped position, as `ocean_fine.gdshader` already did; only the
standing swell keeps the tile. A float holds 0.27 rad a metre at the 32 km corner (about 12,500 rad) to 0.001 rad.

Measured by the biggest step in mean water luminance between neighbouring columns at the frame's centre (`tests/pirate_shot.gd
--views=sea_low` and `sea_low_evening`, 1600x900 at 3D scale 1.40):

| frame | day | evening |
|---|---|---|
| main 96adc799 | 0.31 (rest of the water at most 0.16) | 3.37 (at most 0.10) |
| lane before the unwrap | 0.18 | - |
| after | 0.00 | 0.01 |

**Check a wrap by every term evaluated on the wrapped position**, not only the one made periodic: the fine shader's own
comment had said the plain seam was "still there" for three days.

**A DARK WEDGE ON FINE'S EVENING SEA from the same pose** -- a straight-edged bluish quadrilateral in the near water on main
96adc799, with the mist on and off -- is not on main with step 2 merged (blue minus red over the water beside it +7.6 on
96adc799, -0.5 on 80f66502); the ground and the sun's shadows never changed that water (0.00 and 1.15 of 255). Which step 2
change removed it these frames cannot say.

**FINE'S TRAVELLING CHOP IS CALMED NEAR THE EYE, and why (team-lead, 2026-09-15).** `ocean_fine.gdshader` draws four Gerstner
waves (70, 43, 27, 16 m) the simulation floats no hull on -- they run on TIME, and a replayed tick would meet a different
sea. At `swell_steepness` 0.4 their crests reached 0.93 m over the simulated swell where all four lined up, full strength
within 110 m of the eye, and cockpit-carrier's launch -- 0.4 m of freeboard -- looked swamped from its own helm on FINE and
dry on PLAIN (PLAIN's chop is normals only). Now 0.15: crests up to 0.35 m, under the launch's 0.4 m of deck even at its worst 2.2 degrees of heel. Judged from the launch's own helm on
cockpit-carrier's seat and plated deck (`tests/ship_shot.gd --kinds=boat --shots=helm,helm_down`), the plated deck reads dry
at 0.15. Four launches at each value rendered at nearly one moment (mean difference 0.2-0.6 of 255), so they sampled one
crest, not four: the value rests on the crest arithmetic. `tests/ocean_height_shot.gd` now reads the chop at eight moments
over 9.4 s: 0.342 m over the simulated swell at worst, each moment's worst between 0.280 and 0.342 m (cockpit-ocean, 2026-09-15). The open sea, before and after: `pirate-beam_reach-fine-chop-before.png` / `-after.png`.
**AND THE UNWRAP NEEDED A BOUNDED NOISE LATTICE.** Taking the churn off `tile()` put it at lattice cells far from the
origin -- a brig 11 km out read cell 132, and 268 in the second octave -- where `hash21` keeps too little of the fraction and
value noise draws straight-edged seams (`terrain_noise.gdshaderinc`, measured from cell 80 on rock and grass). FINE had
drawn one all along: a hard diagonal edge across the near water from 70 m to leeward of a brig, the same with every sun's
shadow off (difference 0.00) and at any steepness. The churn in both seas now reads `fbm2_turned(..., LATTICE_PERIOD)`,
as grass's clumps do (gradient noise, no crease along x and z, wrapped corners, fbm2's spread about the same mean); FINE's
wind streaks read `fbm2_wrapped(..., LATTICE_PERIOD)`, which keeps them along the wind. The biggest diagonal luminance step
across where the edge ran fell from 11.51 to 1.03 (the chop's own crests beside it: 16.59, 16.27), PLAIN far out shows no
seam, and z = 0 stays clean (0.01). **Sines may take the unwrapped world position; hashed noise may not** -- any noise on a
world position reads a `_wrapped` or `_turned` lookup with `LATTICE_PERIOD`.

**The probe's sea views:** `tests/pirate_shot.gd` has `sea_low` and `sea_low_evening` (mist's pose, a fixed camera that
follows no ship), `--scale=` for the 3D render scale, `--ground=off` to hide every node named `Ground*` or `TerrainPatch*`,
and `--shadows=off` and `tack_later` from step 2.

### THE SEA'S SURFACE, PAINTED FROM THE WEATHER (2026-09-15, cockpit-ocean)

Asked for on 2026-09-15: "ocean's are often much more tumultous and have more varied waves, it's usually darker and has
more ripples. ... combining multiple noise patterns should help, make this a shader", and after the plan, "make sure we go
for realistic water which has lots of little ripples". The user plays in a headset on PLAIN.

**WHAT WAS MISSING WAS SLOPE, NOT HEIGHT.** The simulated swell is already Hs about 1.5 m by four sigma (waves of 0.42 m and
0.336 m), but its slope variance is 0.0002, where a real sea's, measured from sun glitter by Cox and Munk, is
0.003 + 0.00512 U: 0.047 at the ships' 8.5 m/s. The sea before (`tests/ocean_shot.gd` on main c68a2b7c, drafts
cockpit-ocean/before-main) was a glassy navy lake near the eye with the sun as one smooth blob. And it read light not for its
colour, which was already 0.001-0.009 linear, but because it was mixed toward a shallow colour by view angle and reflected
as F0 0.045; water's F0 is 0.02 (`SPECULAR` 0.25 now, and no shallow mix).

**`WindSea` (`world/wind_sea.gd`) works the wind-sea out and hands it to a sea's material; `world/shaders/ocean_detail.gdshaderinc`
paints it; neither ocean shader's `vertex()` reads any of it.**
- The wind is the middle of `Terrain.weather()`, 8.5 m/s, handed once when a sea is built (`SeaSwell`, the carrier deck).
  Nothing follows the wind's wander frame by frame.
- Ten waves from 38 m down by 0.615 a step, spread about `Terrain.SWELL_HEADING`, each a whole number of waves across a
  512 m tile so the shader's wrap has no seam, each at deep water's speed for its length. Their slope variance is Cox and
  Munk's, less 30 % left to ripples shorter than anything drawn, less the swell's own, shared equally: the equilibrium range
  of a wind-sea, where each octave of wavelength carries about the same slope.
- **Whitecaps as the weather says**: Monahan and O'Muircheartaigh's cover, 3.84e-6 U^3.41 (0.09 % at 5 m/s, 1.8 % at 12),
  on crests whose curvature passes a threshold read as the sampled quantile of the breaking waves' summed curvature. Solved
  as a normal distribution by erfc it gave 0.04 % foaming at 8.5 m/s against 0.57 %: a few sines have far lighter tails
  than a normal.

**FOUR SINES AND SIX OCTAVES OF NOISE, AND WHY NOT TEN SINES.** A few sines always interfere into a lattice, and it shows
wherever they are the finest thing a pixel still draws. Each step below was looked at in `tests/ocean_shot.gd`'s pictures
(drafts cockpit-ocean/after4 to after7):

| painted | near the eye (`close_8`) | the glitter from 200 m (`sea_200`) |
|---|---|---|
| ten sines on FINE, eight on PLAIN, to 0.5 and 1.25 m | PLAIN soft and glassy; FINE a honeycomb in the glitter | a crosshatch |
| six sines to 3.3 m, three noise octaves to 0.26 m | small ripples | the crosshatch |
| four sines to 8.8 m, five octaves to 0.1 m | ripples | the crosshatch |
| no sines at all, every slope in the noise | ripples | no lattice, but the far sea glassy and the glitter from 60 m a soft blob |
| four sines keeping half their slope and fading at 16-8 pixels a wavelength; six octaves, 12 m to 0.16 m, fading at 8-4 | ripples to the eye | no lattice |

So noise as long as the sines lies under them, and wherever a sine is the finest thing drawn, noise of its scale is drawn
over it. **Bending the sines' phases by a noise only helps the waves near that noise's scale**: the 83 m churn at 1.6 rad
did nothing to a 10-40 m crosshatch, a 14 m noise at 5 rad mended it from 60 m, and neither touched the crosshatch at 200 m.
- The noise is turned gradient noise on the bounded lattice (`lattice_gradient` from `terrain_noise.gdshaderinc`) with an
  analytic slope, stretched 1.6 across the wind and drifting down it at deep water's speed for a wave a cell long. **Its slope
  variance at one cell a unit is 0.779** (value variance 0.0465), measured over 400,000 points with the include's own
  derivative, which matched a central difference to 5e-9; each octave's amplitude comes from it, so the octaves carry exactly
  the slope the sines hand them.

**AND THE OCTAVES ARE NOW TWO NORMAL MAPS MADE OF THAT NOISE (A8, team-lead, 2026-09-15)**, because worked out per pixel they
cost up to +1.09 ms of a headset's two eyes against +0.3 (see "WHAT THE PAINTED SEA MAY COST"). `WindSea.ripple_maps` makes
them when a sea is first built, 1024 px square: seamless fractal simplex noise, eight cells a tile, lacunarity 2 and gain 0.5
so every octave carries the same slope, turned into a normal map by `Image.bump_map_to_normal_map` and mipmapped. The long
map tiles every 96.3 m with four octaves, 12 m to 1.5 m, under the sines; the short one every 7.3 m with six, 0.9 m to 3 cm,
for a helm's near water, and it is read again at 10.0 m, turned and drifting on its own. Each map's slope variance is measured
off its image as the shader decodes it, so its amplitude still comes from the wind's budget.
- **Red is minus the height's rise along the image's x, green its rise down its rows**: a rising ramp in each, read back on
  the 4.7.2 editor. The docs do not say.
- **A mip bias of 2.** Read at the pixel's own mip, an octave was drawn down to a pixel or two a cell, and the dusk glitter at
  a headset's pixel popped on 0.280 % of PLAIN's pixels a frame and 0.908 % of FINE's. A mipmap averages a crisp normal over
  a few texels; it does not stop it sparkling. Biased by 2, each octave is gone at four pixels a cell, as the noise's was:
  0.032 % and 0.060 % at 90 frames a second, 0.000 at 360.
- **The long map starts under the sines.** At a 51.7 m tile its longest octave was 6.5 m, too little noise at the sines'
  scale, and their crosshatch came back in the glitter from 60 and 200 m; with the sines off it was gone (drafts
  cockpit-ocean, after-A8b against diag-A8-nosines). And 51.7 over 7.3 is 7.08, a repeat that nearly lines up.
- **`tests/wind_sea.gd` holds the maps** as a material is handed them: both mipmapped; each wrapping with its step across the
  wrap no larger than its steps inside (0.0627 and 0.1098); each handed its own slope variance, read back at a different
  stride (0.01247 against 0.01247, 0.01455 against 0.01476); no two tiles near a whole ratio (0.192 at worst). Its four
  mutants went red: plain noise instead of seamless (a wrap step of 0.92 against 0.47 inside), no mipmaps, the variance
  measured before the normal map (3.56 handed against 0.0125), and tiles of 87.6 and 7.3 m.
- Making both maps takes about 0.4 s when a level first builds its sea (1024 px: 154 ms of noise, 21 ms to a normal map,
  10 ms of mipmaps, measured headless); they are made once a run.

**BAND-LIMITED BY THE PIXEL, AND WHAT IS NOT DRAWN IS ROUGHNESS.** Metres a pixel is the geometric mean of the pixel's two
sides on the water. At a helm's grazing angle a pixel is several times longer along the view than across it, and its long
side, `length(fwidth(world_pos.xz))`, faded the ripples the eye still sees across the view and left brush strokes on the
water beside a launch (drafts cockpit-ocean/ships-lane against ships-lane2, boat-plain-helm). Each
sine and each octave fades out across its band of pixels a wavelength, and the slope variance it no longer draws goes into
GGX alpha squared (Bruneton, Neyret and Holzschuch 2010), with Tokuyoshi and Kaplanyan's per-pixel geometric antialiasing on
the final normal. Godot's screen-space roughness limiter never sees detail painted in a shader. The far sea keeps the wind's
roughness, so the sun draws a glitter path on it, and the moon one at night, where main drew a dot.

**LIGHT THROUGH THE CRESTS: BACKLIGHT IS MULTIPLIED BY THE ALBEDO AFTER THE LIGHTS** (`scene_forward_clustered.glsl`,
`diffuse_light *= albedo`), so on water this dark it shows nothing unless handed the colour wanted divided by the albedo.
At (0.04, 0.16, 0.15) the crests facing a low sun were green blotches (after5, `dusk_20`); now half that.

**FINE** works its four Gerstner waves' normal out again per pixel from the rest position (the straight facet lines along
the sheet's 3 m triangles are gone), rolls its cat's paws in two octaves, and draws wind streaks only as the weather says:
foam blown in streaks is Beaufort 7's sea, so they grow in with the whitecap cover from 1.5 % (11.6 m/s) to 3 % (13.9). Drawn
at the ships' middle wind they were scratches on the water from 200 m and a pale band past the helm (after7).

**THE WHITE SMEARS SEEN FROM A KILOMETRE UP ARE THE MIST'S STRATUS, NOT FOAM.** `--mist=off` has none, and no change to the
sea shaders moved them. Look with the mist off before blaming a surface shader.

**What holds it:**
- `tests/wind_sea.gd` (headless, in the gate), at 5, 8.5 and 12 m/s, from what `WindSea.hand` puts on a material: every
  wave vector whole across the tile and none shared; the painted, unpainted and swell slope together Cox and Munk's within
  3 % (0.0464 against 0.0465 at 8.5 m/s); the wrapped sea equal to the unwrapped across x = 0, z = 0, the tile's edge and
  30 km out, adding no step; each wave at deep water's speed within 1 %; the sampled whitecap cover Monahan's within a third
  (0.085 % against 0.093, 0.613 against 0.567, 1.932 against 1.838). A seam check's bound is the step the wrap ADDS: a
  millimetre in a centimetre, copied from the swell's check, read the wind-sea's own slope as a seam.
- `tests/lint.gd`, `and_the_seas_painted_detail_moves_no_vertex`: neither ocean shader's `vertex()` names the wind-sea, its
  whitecaps or its gusts, and the include never names VERTEX. The body is searched with CRLF taken out: on this Windows
  checkout `"\n}\n"` was never found, and the check went red on a correct tree.
- `tests/ocean_height_shot.gd` (windowed; `docs.gd` PROBES) renders each shader FILE's own `vertex()` with its
  `fragment()` swapped for one that writes the height, and holds the drawn height to `swell_height_at`. **It reads the
  rasterised position, not a varying**: `ocean_fine.gdshader` works `world_pos` out beside `VERTEX`, so a height added to
  `VERTEX` alone moved the sea and left the varying where it was. And it compares against `swell_height_at` at the corners of
  the sheet's triangle, mixed as the rasteriser mixes them: straight against the swell, the 3 m cells' own bend of a 150 m
  wave read 0.84 mm against a 1 mm bound. A floor-for-trunc wrap mutant cannot go red on waves whole across the tile; its
  mutant shifts the swell's phase by a thousandth of a radian instead (0.4 mm). On the lane (double editor d7558605, DLLs
  1722E33C and 434DCC21): PLAIN, and FINE with its chop stilled, 0.034 mm off at worst at the corners (0.85 mm at the pixel)
  over 15,876 pixels in four patches, one in each quadrant; ten times the wind-sea moved 0.0000000 m; FINE's chop 0.342 m
  over the swell at worst in eight moments over 9.4 s, against the launch's 0.40 m, and each moment's worst differs, so a
  stopped chop cannot pass. Its three mutants (a wind-sea height on PLAIN's `VERTEX`, the swell's phase a thousandth of a
  radian off, a height on FINE's `VERTEX` alone) went red on the checks named for them, as did lint's three and wind_sea's four.
- **The glitter does not sparkle at a headset's pixel.** `tests/ocean_shot.gd --views=dusk_headset --flicker=5`, its field of
  view set so a window pixel covers what a headset pixel does (`tests/builder.gd`'s `HEADSET_PIXELS_PER_DEGREE`, 20), the
  luminance step frame to frame over a 480x270 crop at 90 frames a second: PLAIN a mean of 1.08 of 255, 8.7 at the 99th
  percentile, 0.019 % of pixels popping past 24; FINE 1.85, 13.9 and 0.070 %. At 360 frames a second, a quarter of the time
  step, 0.30, 2.2, 0.000 and 0.32, 2.9, 0.000: the steps shrink with the step in time, so they are waves moving, not
  aliasing. Band-limited by the pixel's long side they were 0.87, 7.1, 0.004 % and 1.34, 9.0, 0.001 %, and the water beside
  a launch's helm was brush strokes: the helm's ripples cost FINE the most, 0.07 % of its pixels popping a frame, in a sun
  path that sparkles on a real sea too. Main's sea reads 0.13, 1.0, 0.000 there, a still blob, and any sea that moves steps more than a still one.
- `tests/ocean_shot.gd` (windowed; PROBES): the sea from fixed places at day, dusk and night, `--flicker=N` for the glitter
  frame to frame at a headset's pixel (`dusk_headset`), `--frames` for the GPU timer and `--scale` for the render scale.
  Setting a camera's fov to 0 prints "Condition p_fov < 1" errors, so a view with a worked-out fov never assigns its
  placeholder.

**WHAT THE PAINTED SEA MAY COST, AND HOW IT IS TIMED (team-lead, 2026-09-15).** At most +0.3 ms of GPU over main's sea for
a headset's two eyes on PLAIN, unfoveated, on every `tests/ocean_shot.gd` view, the helm view from a height (`close_8`)
included. A later sea lane times the same way:
- **The headset, from one source.** Two eyes are 18.3 MP: 2,160 px across 100 degrees (the headset pixel this file uses
  above) at `PilotRig.RENDER_SCALE` 1.4, 3,024 px square an eye, 9.14 MP. That is 30.2 px a degree. `tests/builder.gd`'s
  `HEADSET_PIXELS_PER_DEGREE`, 20, is a Quest 2 placement constant for sizes, not this render target; pairing it with 18.3 MP
  mixes two headsets.
- **The pixel count AND the footprint.** Every sine and every ripple octave is band-limited by the pixel's footprint, and a
  faded one is not evaluated at all -- `if (fade <= 0.0) { continue; }` in both loops of `paint_wind_sea` -- so what a
  pixel costs depends on how much water it covers. So the probe must draw the headset's density, not only its pixel count.
- **A 3D scale past 2.0 is 2.0** (working_with_godot.md). `ocean_shot --scale=3.56`, first taken for 18.3 MP, drew 3200x1800,
  5.76 MP: every headset figure from it was 3.18 times too low (a helm view reading +0.34 ms was +1.09). That window at 2.0
  is 31.2 px a degree across its 102.45 degree view (70 degrees high at 16:9), the headset's density within 3 %, so **the sea
  is timed at `--scale=2.0` and the main-to-lane difference multiplied by 18.3 / 5.76 = 3.18**. Checked at 1.94 (3104x1746,
  30.2 a degree, x3.37): the same view's two-eye figures agreed within 0.01 ms.
- **Interleaved launches in an announced slot**, each view's GPU median over 600 frames; a launch waits out every other
  lane's Godot and is void on a GPU process that was not there at the slot's start or CPU over 25 % (running_a_team_here.md).
  Rounds agreed to 0.005 ms.
- **What shipped, and it is over the bar.** Slot 4 (08:24-08:29), 3 interleaved rounds, no voids, the two-eye cost at
  18.3 MP unfoveated (the median added over main at scale 2.0, x 3.18):

  | | sea_20 | sea_200 | grazing | glitter_60 | close_8 |
  |---|---|---|---|---|---|
  | seven noise octaves per pixel (H2) | +0.60 | +0.56 | +0.56 | +0.56 | +1.09 |
  | **two ripple maps (A8, shipped)** | **+0.52** | **+0.55** | **+0.43** | **+0.53** | **+0.81** |

  A8 is cheaper everywhere and 0.28 ms cheaper at the helm view from a height, keeps the helm's ripples, shows no tiling,
  and its dusk glitter pops on 0.032 % / 0.060 % of pixels a frame. **It is still 0.13 to 0.25 ms over the +0.3 ms bar on
  the open sea and 0.51 ms over at `close_8`** (about +0.30 to +0.39 and +0.57 with VRS foveation's 0.7), which team-lead
  put to the user rather than hold the sea (WHAT IS NOT HERE YET).

### Where the brigs sail, and the weather they sail in (step 3, the GDScript half)

**The weather is the ships', and only the ships'.** `Terrain.weather()` is the wind they sail in: 5 to 12 m/s, veering
0.35 rad (20 degrees) either side of where it comes from, seed 7, from the side the sea's swell comes from (`from` is worked
out from `SWELL_HEADING`, so the painted chop and the brigs' wind agree). `Sim.set_weather` tells both worlds, because a
wind is a function of the frame and the seed: every world told the same weather sails the same wind with nothing sent.

**No wind anywhere else: the user's order, twice** ("no wind anywhere", 2026-09-14, which `tests/smoke.gd`'s
`the_air_is_still_once_the_level_is_built` carries; "no wind for aircraft", 2026-09-15). Aircraft already fly in still air
whatever the weather -- `air_at` gates aeroplanes, helicopters and tiltrotors on the wings flag, and `sky.gd` will say
`Sim.set_wind_on_wings(false)` -- but `CockpitWorld.wind(height)`, the air the game layer is told about (burst smoke leans
on it, and it is "which way to fly the run"), read the weather regardless. Handed the weather, the level made smoke's
check read (4.94, 0, -2.00) m/s. So `wind(height)` answers the air aircraft fly in, honouring the flag, with a getter
for the flag, in step 3's C++ (team-lead's final decision, 2026-09-15); only a ship's sails, flag and heel feel the
weather. It landed with step 3's sailor: the level hands every world the weather and keeps it off the wings.
**What reads which wind**, so nothing is left leaning when it lands: only `burst_yard.gd` asks `Sim.wind(height)`; fire
plumes (`fire_front.gd`), the clouds and the lift yard, the burning drift, the grass and FINE sea shaders' `wind` and
`vehicle_view.gd` all read `Terrain.WIND`, which is zero. So once `wind(height)` honours the flag, no smoke anywhere moves.
**And a trap for that commit:** `sky.gd`'s `_build` calls `Sim.set_wind(Terrain.WIND, Terrain.WIND_SHEAR)`, and `set_wind`
makes the weather a steady field -- so a `_build` after `_on_sim_ready` (a restart) would wipe the ships' weather. The
weather has to be handed over after it, every time, or `_build` stop calling `set_wind`. Step 3 hands it over in
`_on_sim_ready`, which follows `_build` every time.

**The brigs' pool is a ring, well off the coast.** `Terrain.waypoints(Sim.Kind.PIRATE)`: on the island, PIRATE_POOL
points tried and those from PIRATE_SEA_INNER (1,500 m) past the edge out to a radius of `placed_reach()` (17,309 m on
the island) kept, inside the placed reach on both worlds so the level's boundary band, built PLACED_MARGIN past it, starts
past every brig (team-lead and cockpit-levels, 2026-09-15) -- 26 of 48 -- which clears the coast and the BOAT
pool's inshore water by enough for a brig to tack and to see a shoal two minutes off. On the generated ground, `open_sea_near(at, pirate_depth())` for each tried point, as
cockpit-terrain asked. `tests/pirate_ai.gd` holds every point inside the ring, open sea, and in all four quarters.

**`Terrain.pirate_depth()` is a brig's draught and SHIP_KEEL_ROOM, and not `ship_depth`**, which reads a top-level
"waterline" and "hull" parts a brig does not have: its waterline is its rig's, over the hull box's bottom. Floated in a
world and measured under the swell, a brig draws 3.30 m against the 3.30 m pirate_depth works
from (100 samples over ten seconds after forty to settle).

### The sailor, and the brigs in the world (step 3, the C++ half)

**THE SAILOR IS A CHORE ON THE ROTA (`CockpitWorld::sail_chore`), and the helm under it runs every tick.** A heading held for
tens of seconds is what a ship is sailed on -- a tack takes 25 -- so where to go, which tack to beat on and whether the water
ahead floats it are decided twice a second (`kSailThinkEvery`, the `sail` kind, on `wing_chore`'s rules: a limit at
`kChoreSlack` times the target and a derived share), and `sail_itself` steers what was decided. A hundred ships are a
hundred decisions a second, spread by the rota.

1. **A waypoint** from the brigs' pool when it has arrived within `kSailArrived` (250 m) or its patience is spent: on a leg,
   `kSailPatience` (20 minutes); with no leg, `kSailRetry` (15 s), because a look is the whole pool sounded. At least
   `min_leg` (1,500 m for a ship), and `choose_sea_waypoint` -- not `choose_waypoint`, whose box test is for things that
   drive over what they meet -- tries EVERY point once from a start the seed picks, in four passes: ahead and deep enough
   every `kSeaLegStep` (100 m) of the straight line; anywhere and deep; anywhere with water the whole way
   (`kSailWetEnough`), the shoal look steering it round the shallows; and last, a hop of `kSailHop` (800 m) with water the
   whole way, out of a corner of shelf with nothing longer.
2. **The course off the wind.** Reachable directly, the bearing. Inside `close_hauled_of(rig)` -- the square yards' closest
   brace, half the angle their lift peaks at and `kCloseHauledMargin` for leeway, 66 degrees for the brig -- a beat on
   one tack; nearer dead downwind than `kRunLimit` (165 degrees), a broad reach at `kBroadReach` (150) on one gybe, because
   a run is slower than a broad reach (6.1 knots against 7.0). It tacks or gybes when the waypoint's bearing is past the
   wind on the other side by `kTackHysteresis` (10 degrees), or when it has stood `kBeatLane` (600 m) off the direct line
   and is still going away from it.
3. **The water ahead**, sounded at 60, 150, 300 and 500 m along the course (`kShoalLook`: two minutes of warning at 4 m/s):
   shallower anywhere than the rig's draught and `kKeelClearance` (3 m), and the course turns `kShoalTurn` (25 degrees) at a
   time, up to five, to the deeper side, and counts a shoal; nothing clear anywhere and it goes about, gives the leg up and
   waits `kSailRetry`.
4. **The world's edge.** Past the band's start (the turn-back's own test, `boundary_depth_ > 0`) the middle is the bearing,
   worked off the wind like a waypoint, so a brig whose middle is upwind beats home; the lane test is off, the middle not
   being on the leg. `turn_back_from_the_edge` still puts the rudder over, but a rudder blend is no match for a helm steering
   a course: a sailor making for a waypoint past the band ended 991 m out with the middle dead upwind and 1,215 m with a
   wind across, exactly as far as it got (tests/world_edge.gd, 2026-09-15).

**THE POOL ON THE GENERATED GROUND LIES ALONG A SHELF, AND STRAIGHT LEGS CROSS IT.** `open_sea_near(at, pirate_depth())`
hands back the nearest point just deep enough, so the alpine level's 35 points stand on the 11.3 m contour, and 72 of their
1,132 legs of 1,500 m or more are deep the whole way: sixteen random tries a decision found none for any of the three
brigs in ten decisions, and terrain_level's "every machine on its own has somewhere to be" failed on them. A deeper pool
does not cure it -- asked at 20, 30, 45 and 60 m the pool is 30, 22, 16 and 7 points with 12, 6, 7 and 7 of them having no
deep leg -- because that sea is a narrow curving band. Hence the whole-pool scan, the wet-leg pass and the retry; and the hop, because one of the level's three brigs was spawned
at (-6542, -20940) with a wet leg of 800 m and none of 1,500 (the probe's third run). **Seven of the 35 points have no wet
leg even 400 m long**: a leg works both ways, so no brig sails into one, but a brig spawned on one would never leave, and
terrain_level's leg check is what said so. **So the pool keeps only points with a leg**: `Terrain._with_a_wet_leg`, beside
`_with_a_clear_leg` and the same shape, keeps a point only if a hop to another has water the whole way, ASKED OF THE
SIMULATION -- `ai_leg_rules(kind)`'s "hop" and "wet" and the bound `sea_leg_is_deep` -- in both PIRATE arms (team-lead,
2026-09-15: a spawn or a later pool change can then never strand a brig), and warns if fewer than two a brig are left.
The level's `_build` stands the ground in the simulation, or adds the island's slab, before it asks for the pools, so the
answer is the one the sailor will get. terrain_level's `every_brig_pool_point_has_a_leg_with_water_the_whole_way` asks
the server the same of every point left, and the mutant `stranding_points_kept` drops the filter. Asked of both levels: alpine 35 points before the filter and 26 after, the island 26 and 26,
against the fewest it warns under, 6.
**So on the alpine level the brigs look slow, and that is expected:** a brig with no sailable leg holds its heading for
`kSailRetry` (15 s) before it sounds the pool again, and a wet leg along the shelf is sailed with the shoal look turning it
off the shallows, one `kShoalTurn` at a time. On the island's sea every leg away from the island is 150 m deep, the depth of
`Seabed`'s floor, which is deeper than any keel needs, so every such leg is still sailable (it was "no floor, every leg is
deep" until 2026-09-16; see THE SEABED IS A FLOOR under THE WORLD).

**`water_depth_at(x, z)`**: on the generated ground, the ground's own water less its height (the ground's function; a box
never changes it); without ground, a ray down from 1 m above the sea, `kSeaSounding` + 1 m long, that counts STATIC shapes
only (`note_the_sea_floor`), so a hull alongside is never a shoal -- `first_solid_below` uses the default filter and would
see one. On the island that ray now meets `Seabed`'s floor: open sea reads **150.0 m where it read inf** (lane/sinking,
2026-09-16), and the generated ground reads 149.98 m there. Measured before the floor went in and after it, 25,920 answers
over an 81 x 81 grid 500 m apart on the server and the client: all 11,440 open-sea soundings went from inf to 150.0;
`sea_leg_is_deep` on a 1 km leg from each point flipped from true to false only at needs of 151, 200 and 250 m (all 11,000
legs), and was identical at 1, 5, 11.84, 40 and 149 m; the 1,628 land points (0.0) and the 54 at -1.0 were identical.
No caller compares a depth with inf, and every need in the game is a keel's worth.

**The wind, as decided.** `CockpitWorld::wind(height)`, the air the game layer is told about, now answers the air aircraft fly
in: zero while `wind_on_wings()` is false, which the level sets. So smoke's "no wind anywhere" holds and burst smoke stands
still, while a ship reads the weather itself (`sail_ship`, `sail_chore`). The level hands every world `Terrain.weather()` in
`_on_sim_ready`, after `_build`'s `Sim.set_wind`, which would otherwise make it steady again on a restart.

**The brigs in the world**: `Terrain.pirates(grid)`, PIRATE_FLEET (3) points of their own pool taken evenly round it, put in
under way at 3 m/s across the wind; sky spawns them with the rest. Nobody may board one. smoke holds that the level puts
all of them on the server (`the_level_puts_its_brigs_on_the_sea`: nothing did, and a spawn loop over nothing was green) and
counts them in its traffic.

**`tests/pirate_ai.gd`** (8 sections): the pool and the spawns on it; the floated draught; a brig in a world of its own that
beats up to a waypoint dead upwind and back -- 3 legs in 42.8 minutes, 9 tacks, the shoal box standing on the line between
them sounded ahead at 870 of its decisions and never gone over (nearest 12 m) -- deciding 5,142 times in 308,400 ticks,
one a half second within 15 per cent; the close-hauled angle making 97 per cent of the best speed made good to windward
(0.82 m/s against 0.84 at 60 degrees); five brigs at 7.3 microseconds a tick (budget 300, 50 a ship); the free roll period (below); a brig whose pool has only a leg between the hop and a ship's shortest
(1,150 m, both asked of `ai_leg_rules`) beginning one -- `no_short_hop` lived until it was added, because the filter
keeps the level's brigs where a long leg exists; and the level's weather on both worlds. Two of these were wrong the first time: 45 minutes was one waypoint short at 0.82 m/s made good, and the shoal stood
111 m off the beat, was turned for 0 times, and would have let a sailor that never sounds ahead pass. Thirteen mutants go red on the check that names each one's change; see the step 3 ready.

**WHAT A SEA THAT MOVES THE BRIG MUST RESPECT** -- the sailor was tuned on the standing swell alone; cockpit-ocean's wind
waves (C1, 2026-09-15: 64, 40 and 26 m, 0.35, 0.20 and 0.10 m high, which the brig's 30 m hull feels) were added after, and
every number below was re-measured on them. Before C1 they read: roll period 4.29 s, heel 3, 9 and 15 degrees, 11.4 at most
over the float with 0.37 m of heave, 7.1 knots on a beam reach, 7.0 broad against 6.1 on a run.
- **Its free roll period is 4.25 s** (tests/pirate_ai.gd: a beam reach in 12 m/s, the wind taken away, against a
  still-air twin released at the same place and moment so the swell cancels), held to 2 pi sqrt(I / K) = 4.59 s
  from `sail_report`'s own `roll_inertia` (1,727,916 kg m^2, Box3D's, about the keel) and `roll_stiffness` (W x GM, 1.5 m, which
  the probes' spread is derived to give). A deep-water wave of that period is 29 m long; waves met at that period on
  the beam will build its roll. Box3D's inertia is the hull box's, m(hx^2 + hy^2)/3, so the 4.6 s worked out by hand was right, but typed in; the
  first test's 12.27 s from four crossings of the mean was the standing swell's 10-11 s waves once the free roll had died.
- **Its hull**: 30 m on the waterline (hz 15), 8 m beam (hx 4), 3.3 m of draught under 2.2 m of freeboard amidships,
  220 t, GM 1.5 m; the waterline 60 per cent up from the keel.
- **Its sailing, on the swell and the wind-sea** (tests/sailing.gd): 5 to 12 m/s of wind; a beam reach at 7.07 knots in
  10 m/s; nothing made good inside 45 degrees and 2.31 knots at 50; a broad reach at 6.98 knots faster than a run at 6.06;
  heel 2.6, 8.8 and 15.7 degrees in 5, 10 and 14 m/s, 12.1 at most over a ten-minute float with 0.426 m of heave, never
  dry (0 of 1,160 samples) and the sea 0.28 to 0.86 m above the centre of mass, between keel and rail; a tack in 25.9 s
  with up to 0.40 m/s of sternway. The sailor beats at 66 degrees, makes about 0.8 m/s good to windward in 9 m/s, and
  keeps 3 m of water under its draught.
- **What it floats on**: `swell_height` at six probes, the wind-sea's three waves included. A wave added to the simulated sea
  changes every one of those numbers; rerun tests/sailing.gd and tests/pirate_ai.gd on it, and the waterline checks (the
  sea between keel and rail).

### Rollback, and why it is not tested

Nothing predicts a ship nobody may board, so no rollback replays a sail. The server never resimulates, and a client
receives the ship as buffered interpolation (`drive_vehicle` returns before the forces). If a ship becomes pilotable,
its client predicts it with the wind of the frame it is replaying, which is the reason the wind reads the frame.

### Nobody may board it

`Shape::pilotable` is false for the pirate ship, in the simulation's shape table, because the server is what refuses.
`kind_geometry(kind)["pilotable"]` carries it to `VehicleCatalogue.pilotable` and `pilotable_kinds`, which the CRAFT
page, the desk keys and the help page read.

- `free_seat` answers none, so the next-craft button and the kind walk pass it by.
- A kind asked for by name, a seat asked for, and a player STARTED in one (`spawn_pilot`, so `--kind=pirate` gets no
  pilot) are each refused by `refuse_boarding`: counted (`refused_boardings`), and a warning at most once a second.
- `join_player` refuses one too, answering `not_boardable` (`kJoinNotBoardable`, 7, the last value the answer's three bits
  hold). **It is a guard nobody can reach today**: a join names a player, nobody can be aboard, so a JOIN pressed at the
  ship answers `gone` first. No test asserts it, because one would have to get round the refusals it guards.
- **The no-go angle, measured:** nothing made good 45 degrees off the wind or closer, and 2.3 knots at 50.
- `Sim.Kind` and the simulation's `kKind*` are typed in two places; `tests/nobody_aboard.gd` holds them to the same
  count and order, name by name (HELI is the shape table's "helicopter", the one alias).
- `tests/nobody_aboard.gd` plays a client's frames into a server: the forged kind is refused and counted, and the same
  press naming an aeroplane seats the player. Eight walks of the next craft never land in it, and `seat_client` is refused.
- `tests/clipboard.gd` presses every CRAFT button and checks no press asks for it, and that no desk key does.

### WHAT IS NOT HERE

- **A brig leaves no wake or bow wave.** That is cockpit-ocean's lane, after C1 changes the simulated sea (team-lead,
  2026-09-15): the pirate lane closed after step 3.
- **The soft-shadow dither reads as halftone dots on large pale surfaces such as sails; check it in the headset.** The
  sun's shadows of a brig's masts and yards fall across its canvas as soft bands and a dotted line beside each mast, in
  that dither (`tests/pirate_shot.gd --shadows=off` takes them away, 2026-09-15). The dither is the project's shadow
  filter, not the sail's, so the fix is not in this lane.
- **A brig's flag streams in the sea's weather while smoke and aircraft air are still, by the user's no-wind order.** A
  known oddity: the ships' wind is theirs alone (see "Where the brigs sail, and the weather they sail in").
## A HULL, AND WHAT BREAKS IT

    Godot --path cockpit -- --level=watch --attackers=planes:2,helis:1     a raid on a CB90 at sea
    Godot --path cockpit -- --attackers=planes:2 --attack-target=me        a raid on whatever you are in

Asked for on 2026-09-18 (lane/combat): hit points on craft, guns and missiles that take them away, smoke, an explosion
into pieces, aircraft that crash, the player's overview and respawn, and attackers bad enough to be shot down.

### THE HULL IS THE SERVER'S, ON THE WIRE, AND ROLLS BACK ON ANY CHANGE

`Hull` is a Step component on every craft: what is left as a byte (255 whole), `destroyed`, what did the last damage
(`kHullCause*`), which round or missile row, whose finger (`by`, a client) and what kind of craft it came from, and how
fast a crash was. ONLY THE SERVER WRITES IT -- `damage_hull` from `fly_shots` and `fly_missiles`, `destroy_craft` from
`judge_impacts` -- outside every job. The points themselves are held to better than the byte in `hull_points_`, the
tank's lesson: four rifle rounds on a 400-point airliner are 2.55 steps of a byte.

**It rolls back on any change, because the pilot's own craft is predicted.** On a predicted entity an authoritative value
arrives only on a rollback (the CraftSystems note); with `should_roll_back` answering false, a hit on a client's own
aeroplane reached its screen 54 ticks late over a 4-tick link, against 5 (`tests/hull_link.gd`). A KILL cannot flap:
no client writes the Hull and `destroyed` is never cleared. The kill rows of `hull_link` stay green even under that
mutant, because a wreck is frozen and the frozen pose rolls the client back by itself -- so only the SMOKE row proves
the rule, and it is the one the mutant turns red.

**Hit points are `hull_of(kind, model)`**, not a column in cockpit_kinds.inc: a row holds nothing with a default, and
this has one per model. The light aeroplane is the scale, 100. **Damage is a field on each `Round` and each
`MissileType`**: 7.62 mm 4, 12.7 mm 20, 25 mm 25, 40 mm 60, tank rounds 300, a 406 mm shell 2,000; heat 120, radar
150, Hellfire 250, full inside a third of the fuse and 40% at its edge. The capital ships and the tower are 0: nothing
destroys them. **Friendly fire is on**; a round or a missile never hurts the craft that fired it.

**The stages are C++'s** (`hull_stage`, from the byte every machine receives): thin grey smoke at 60% left or less,
thick black smoke with fire at 30%, destroyed at nothing. `DamageYard` draws them as PUFFS laid where the craft was, one
every 2.5 m of its path, aged on the GPU (`world/shaders/damage_smoke.gdshader`). The first build wore the missile
yard's trail turned dark, and it photographed as a flat beige sheet across the ground: a trail that widens with age is
a contrail, not smoke.

### DESTROYED: FROZEN, WITH ITS CREW STILL IN THEIR SEATS

A wreck keeps its entity. Its body is released, `drive_vehicle` and the read-back skip it (so a client resimulating it
agrees), its autopilot is dropped, nobody boards it and nothing fires from it, and `kCueDestroyed` is played for the
fireball and the pieces (`WreckPieces`: the view's largest meshes, thrown with the craft's last drawn velocity, local
to each machine, seeded by entity). **The crew stay seated**, because a rider is a child of its seat and a player with
no seat has no way to be drawn. An empty wreck is retired 12 s after it died.

### A LANDING, AND A CRASH (step 5, 2026-09-19)

The user: "make sure we understand the difference between a landing and a crash, since we need to support landings on
ground and on the aircraft carrier (which are 'hard' landings)". **A crash is judged by WHAT TOUCHED and HOW, not by one
speed** (`judge_impacts`, `judge_the_touchdowns`, `touchdown_of`):

1. **On its side or its back** with way on (up 75 degrees or more from the sky, over 8 m/s): a crash.
2. **Anything but its underside first** -- the nose into a wall or a carrier's round-down, a side, its back -- or
   another aircraft, faster than 4 m/s into it (`kStrike`): a crash. The face is the contact's own normal in the craft's
   frame. Slower is a scrape.
3. **Its underside, gear down: a landing**, unless the attitude at the touch put something else down first -- a
   wingtip, the nose (more than 10 degrees down), the tail (more than 17 up) -- or the sink was over the kind's gear.
4. **Its underside, gear up: a belly landing.** Survived at the gear's DESIGN sink (not the doubled one), and it takes
   half the hull, once a slide. Decided so because a real belly landing is usually walked away from, and the aeroplane
   is not the same after.
5. **The sea**, as before: an aircraft that does not float is destroyed the tick its box's lowest corner goes under;
   a planeboat is judged the tick its hull probes first read wet -- more than 5 m/s down, banked past 0.6 rad, or over
   75 m/s. Its box would not do: a Savoia dropped at 8 m/s was stopped by its probes with the box 0.17 m clear.

**A WINGED CRAFT IS JUDGED THE TICK ITS LEGS ARRIVE** -- its weight-on-wheels ray (0.6 m under the box) first reaching
something -- by the sink it ARRIVED with, a peak fading at 15 m/s squared. Not by its box's contact: over a deck the
undercarriage's spring and damper take the sink out before the box meets it (a trap arriving at 8.2 m/s met the deck with
its box at 3.8), and on open ground the box meets it after a fall over the legs' reach. So the box meeting the ground
under a winged craft afterwards only checks the gear did not bottom: the limit plus that fall, sqrt(limit^2 + 2 g 0.6).
A helicopter's skids are its box. The arresting gear and the brakes slow a craft ALONG the deck, which is never a contact
into it: a trap is judged by its sink alone.

**THE GEAR, per kind, worked out from the kind's own tables (`touchdown_rule(kind)`):**

| kind | design sink | margin | destroyed over | from |
|---|---|---|---|---|
| carrier aeroplane (its bus fits a hook: Hornet, Tomcat, Hawkeye, Prowler) | 7.62 m/s | 1 | 7.62 | 25 ft/s, the carrier design sink (MIL-A-8863); no flare, and already the limit |
| land aeroplane | 3.05 | 2 | 6.10 | 10 ft/s, 14 CFR 23.473 and 25.473; doubled because in a headset people land hard |
| tiltrotor (F-35B, Osprey) | 3.66 | 2 | 7.32 | 12 ft/s, an ESTIMATE for a STOVL gear |
| helicopter | 3.05 | 2 | 6.10 | 10 ft/s, an ESTIMATE for skids |
| glider (no thrust) | 2.0 | 2 | 4.0 | an ESTIMATE for a skid and monowheel |

The wingtip limit is the bank at which half the drawn span reaches down the fuselage's half-height, asin(hy / span),
and never under 8 degrees (0.14 rad); a glider's is 20 degrees, because it grounds a tip at the end of every landing; a
rotor's is 20 degrees either way. The collision is the fuselage's box, not the drawn wing, so a wingtip is judged by the
bank at the touch and not by the tip meeting anything.

`tests/crashes.gd`, each row's hardest contact -- the box's, or the sink the wheels arrived with:

| landing (must survive) | m/s | crash (must not) | m/s, and the rule's words |
|---|---|---|---|
| light aeroplane, gently | 2.29 | light aeroplane into the ground | 29.5, touched down over 6.1 |
| light aeroplane at 10 ft/s | 2.52 | dropped at 11 m/s | 11.6, touched down over 6.1 |
| firm ground landing asked at 3 m/s | 3.11 | a ground landing at 2.5 x 3.05 | 6.73, touched down over 6.1 |
| fighter pushed onto a runway | 6.07 | a wing dropped at the touch | 3.5, a wingtip, banked 1.05 |
| fighter onto a moving carrier's deck | 5.60 | the nose into a wall at 30 m/s | 42.6, struck its nose first |
| a carrier trap just under the line | 7.47 | a carrier trap just over it | 8.26, touched down over 7.62 |
| belly landing, gear up, gently | 2.24, half the hull left | belly landing at 9 m/s | 8.98, on its belly over 7.62 |
| Osprey landing vertically | 4.09 | light aeroplane ditched | in the water at 41.3 |
| F-35B landing vertically | 4.08 | helicopter set down on the sea | in the water at 2.4 |
| F-35B landing vertically on the carrier | 7.15 (its box) | Savoia dropped on the sea | 8.19 down |
| glider on its skid | 1.77 | rolled onto its side into the runway | a wingtip, banked 1.52 |
| helicopter / Apache set down | 4.34 / 5.05 | | |
| Savoia / water bomber alighting | 0.92 / 1.15 down | | |
| touch-and-go | 2.53 | | |

A trap asked at a sink arrives about 1.3 m/s under it: a sink put on a level aeroplane is a sudden angle of attack, and
the wing takes it off before the wheels reach the deck. So those rows hold what ARRIVED against the line. The vertical
landings meet the ground harder than the lightning lane's 0.55 m/s because the test lets them fall from just past the
legs' reach with no power; all are well under 7.32. Mutants: `--impact=1.5` (every landing red), `--landing-mutant=tip`,
`strike` and `belly` (each its own rows red).

### THE FIRST RULE, AND THE WORLD KEPT OUT OF IT

The first rule (2026-09-18) was one speed: 8.5 m/s into anything destroyed an aircraft, three times a real undercarriage's
certified sink, and 7.0 had been too close to the fighter's 6.1. **Two rules keep the world out of it, each found by a full gate going red.** A craft PUT DOWN STANDING STILL settles --
is not judged -- until it comes to rest or 8 s pass, whoever is in it (`settling_`): the island stands its parked
helicopters 26 m over their pads and on the first run of `hulls` all eight were "destroyed" arriving; a suite drops a
crewed aeroplane from 40 m to start from. And ONLY A CRAFT IN THE GAME is judged at all (`in_the_game`): one a person has
been in, or an attacker being steered. The island's unmanned traffic is scenery: judged, two AI craft brushing in
`climb` "collided at 130 knots", `seabed`'s sinking aircraft never reached the bed, and the rota's and the crowd suites'
crowds shrank. Guns still bring traffic down. **And a world has a sea only when its level says so** (`Sim.set_sea`; the
island does): nothing can tell an empty world's space from the island's floorless sea, and four suites that let a
craft fall through an empty world found it "in the water" -- `shots`, `cockpit_loopback`, `oil_platform` and
flightmodel's `surfaces`. A generated-ground level has its own water map and needs no telling. A suite measuring the
wire under a crowd that fires at itself turns damage off with `set_damage(false)`.

### THE OVERVIEW AND THE RESPAWN

Every machine whose rig sits in a craft that reads destroyed hands the rig to `CrashOverview.stand` -- a still point
70 m back and 22 m up, level and facing the wreck -- exactly as a seat anchor is handed over, so nothing writes the
rider's world transform. In a headset that is one cut and stillness. A panel in front of the eye says what happened in
`Sim.loss_words`' sentence, the same one the host's log writes.

The host's `CrewRespawn` waits `SECONDS` (6) and asks `respawn_crew`, which is decided in the tick with the CRAFT
presses (`answer_the_respawns`): a fresh craft of the same kind at its first clear issue place, or where the host says,
and every person moved to the seat they had through `move_pilot`. **Not `spawn_pilot`**, which gives a client who has a
pilot a second one (lightgun's S-1), and not `seat_client` between ticks (S-2).

The host's log: `NET_KILL ... by="PLAYER 1" by_kind=cb90 weapon=12.7mm` and `NET_CRASH ... cause=water speed_kt=140
rule="in the water at 72.0 m/s"`.

### THE ATTACKERS ARE BAD ON PURPOSE, AND THE BADNESS IS TWO NUMBERS

`Attackers` (`world/attackers.gd`) is the host's tactics and nothing else: `steer_ai`, `set_ai_manners`, `lay_ai_turret`,
`ai_burst`, ten looks a second. Clumsy flying is the manners (0.45 rad of bank, 0.35 rad/s of roll, 68% of flat-out).
A bad shot is exactly two numbers: the lead it guesses, a fresh `LEAD` share (0.6 to 1.3) of the TARGET'S OWN motion each
run, and `AIM_ERROR`, 0.01 rad, a fresh draw each burst. Everything else about its sight is right, because a sight
that cannot hit is not a bad shot, it is a broken one. `aim_point` is the one sight, the attackers' and the test gunner's.

Three faults made every round miss and hid behind the error, which moved nothing when it was changed (0 of 108 for each
aeroplane at 0.055, 0.03 and 0.02):
- an aeroplane fired down its nose, and a run flown at this bank never brings the nose nearer than 0.11 rad to the
  guess. Its burst is now laid on the guess, and the nose only has to be inside `CONE`;
- the lead share scaled the shooter's own 77 m/s as well as the boat's 10: tens of metres off. A sight allows for its
  own speed. Only the target's motion is guessed;
- the perfect-aim mutant waited for the nose inside 0.02 rad, so it never fired, and measured nothing.

Swept on tests/attackers.gd's raid (2026-09-19), struck by aeroplane, aeroplane, Apache: 0 error 11%, 58% (the boat
died before the Apache reached it); 0.005 6%, 30%, 13%; **0.01 0%, 8%, 0.6%, 10 of 381 rounds, and the boat's gunner
still wins in 176 s**; 0.014 and above, nothing. The suite holds each under 10% and the raid at 3 hits or more.
`--attack-error=` sets it for another sweep.

## THE OIL PLATFORM'S WATER (2026-09-19)

`OilField.sites()` places the platform, and asks its depth of the world (`Seabed.depth()` on the island, the ground's own
function on the generated ground). The floor is **`OilField.MIN_DEPTH` = 10 m** and the generated ground's search asks for
that same 10 m: the user's word, "we can fake it ... so that oil rigs can be more easily placed", replacing the 60 m/120 m
of 2026-09-18 that made `north_alpha` warn on some worlds. A real fixed jacket does not stand in 10 m; the drawing does
(`OilPlatform.frame_levels` gives it one bay, and `tests/oil_platform.gd` draws 10, 15, 30 and 60 m and asks that the levels
run down to the floor). Measured: from the same anchor (8000, -8000) the alpine site moved from (17307, -19115) in 120 m to
(15168, -15908) in 10 m, 15.9 km out against a placed reach of 22.3 km, 12.5 m under the deepest foot, 38.7 km from any ship's
spawn, so the anchor stayed. **A world with no sea** (`Terrain.has_sea()` false: the test field, the gliders' level) builds no
platform and pushes no warning, only a `print_verbose`; a world with sea but no site still warns, through `OilField.refuse`,
which keeps `OilField.refusals` so a suite can ask. `a_world_with_no_sea_builds_no_platform_and_says_nothing` holds it, and
fails if the `has_sea` guard is removed.

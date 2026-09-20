extends RefCounted
class_name RadarSet
## WHAT THE RADAR CAN SEE FROM ONE HEAD: the server's own craft list, cut down to what is in range and not behind
## rock, as rows that describe themselves.
##
## WHY IT EXISTS. The user, 2026-09-19: *"awacs or tower controller ... they focus on dispatching and radar (we don't
## have radar yet)"*. They were right that there was none. What there already IS is the whole operator's DISPLAY --
## `world/air_picture.gd`, `world/level_map.gd`, `ui/menus/map_canvas.gd`, the map page and the map screen -- and it
## draws every craft in `Sim.current`, at any range, through any mountain. So radar is not a new picture. **It is the
## sensor the picture never had**, and this file is only the sensor.
##
## ---------------------------------------------------------------------------------------------------
## THE AUTHORITY DECIDES; EVERYONE ELSE DISPLAYS (rule 10)
## ---------------------------------------------------------------------------------------------------
##
## A contact is what the SERVER says it is. This runs on the host, against `Sim.server`, and what it returns is
## published to each peer (`Net.publish_the_radar_picture`) and drawn by a display that is handed it. No client works
## out its own radar picture, and the display has no access to anything it was not sent.
##
## **ROWS DESCRIBE THEMSELVES AND CARRY NO ENTITY ID, AND THAT IS NOT TIDINESS -- IT IS MEASURED.** A client entity id
## and a server entity id are different numbers for different things: on the island with 93 machines, of the 89 ids
## present on both sides only 54 named the same KIND and 18 the same PLACE, and one id was an aeroplane on the client
## and a **train** on the server (`world/tower_panel.gd`, `../../todo/flightcore--a-client-id-is-not-a-server-id.md`).
## A radar picture that were a list of ids for the client to look up would be **wrong about a fifth of its contacts
## and confident about all of them.** So a row carries the kind, the place, the heading, the speed, whether a person
## is aboard and what to call it -- everything a plot needs and nothing it has to resolve.
##
## A HAPPY CONSEQUENCE: the call sign is worked out ONCE, here, on the host. `air_picture.gd` records that it cannot
## replicate call signs today because they hash the entity id and entity ids are per-world, so *"TWO operators on two
## machines would read two different numbers on the same aeroplane"*. A published row carries the call sign as a
## string, so that is simply fixed for anything that comes off radar -- one aeroplane, one name, on every plot and in
## every headset, because it is still `RadioPhrases.callsign` that makes it (rule 4).
##
## ---------------------------------------------------------------------------------------------------
## THIS MAKES CONCEALMENT REAL. IT IS NOT ANTI-CHEAT, AND NOBODY SHOULD THINK IT IS.
## ---------------------------------------------------------------------------------------------------
##
## Hiding behind a ridge genuinely keeps you off the published picture: the host never sends you, so an honest client
## cannot draw you and a controller cannot vector anybody onto you. **It does NOT hide you from a determined client.**
## Replication already sends every craft to every peer -- the priority sphere changes the RATE, not the visibility
## (`Sim.PRIORITY_RADIUS_M`, `docs/crew.md` "THE PRIORITY SPHERE") -- so a modified client can still see what radar
## does not show it.
##
## That is written here plainly because the alternative is somebody later believing radar hides something it does
## not, and building a game mode on it. Making it true would mean changing what replication sends, which is a far
## larger job than a sensor and is not this one.
##
## ---------------------------------------------------------------------------------------------------
## WHAT DETECTION IS, EXACTLY
## ---------------------------------------------------------------------------------------------------
##
## Two tests, and deliberately only two:
##
##   1. **RANGE.** Slant range from the head to the craft, against `range_m`.
##   2. **SIGHT.** `SightLine.is_clear` from the head -- lifted by `mast_m`, because an aerial at ground level has the
##      ground in its own line -- to the craft. That is `CockpitWorld.ground_leg_is_clear` at zero clearance, the
##      same pyramid the AI flies its legs by, so "concealed from radar" and "concealed from the traffic's router"
##      are one notion and a canyon cannot be both cover and open sky. Its bias is that it may call a visible contact
##      hidden and never a hidden one visible, so terrain conceals slightly MORE than geometry alone, at the grain of
##      a 32 m square (`world/sight_line.gd`, and `tests/sight_line.gd` measures it at 50 m over a 614 m summit).
##
## WHAT IS NOT MODELLED, and each is a deliberate omission rather than an oversight: beam width, sweep period, minimum
## and maximum altitude, Doppler and a notch, ground clutter, sea return, cross-section by size, jamming, and the
## radar horizon of a curved earth (this world is flat and 24 km across, where the horizon from a 20 m mast is about
## 18 km -- comparable to the map, so it would bite, but it is a second range rule and one is enough to start).
## A sensor with one range and one occlusion test is a sensor somebody can reason about; the rest can be added one at
## a time, each with the measurement that justified it.
##
## THE COST IS THE SIGHT LINES AND THEY ARE CHEAP: 0.7 to 0.8 us for a 3 km leg (`bedrock.hpp`), so ninety contacts
## is under a tenth of a millisecond, and the range test is done FIRST so a contact out of range is never raycast.
## That is why nothing here caches: a cache would be a second answer to age.

## THE ORDER OF A COMPACT ROW, in one place, read by both ends (`NetStats.COLUMNS` is the same idea and the same
## reason). A dictionary per contact would not fit: a hello is 512 bytes and named fields would halve how many
## contacts a page carries.
const COLUMNS: Array[String] = ["kind", "x", "y", "z", "heading", "speed", "manned", "name"]

## The default reach of a head, metres. 60 km, which is past any corner of the 24 km island from its middle, so on
## this map the thing that actually limits the picture is TERRAIN and not the number -- which is the point. A level
## or a station that wants a shorter reach passes its own.
const REACH_M: float = 60000.0
## How far the aerial stands above the point it is given, metres. An aerial at ground level has the ground in its own
## sight line and sees nothing at all; 20 m is an ordinary airfield radar mast.
const MAST_M: float = 20.0


## EVERY CONTACT ONE HEAD CAN SEE, as compact rows in `COLUMNS` order.
##
## `world` is the authority -- `Sim.server` on a host. `manned` is the set of vehicle entity ids with somebody in
## them, which the caller reads off the SERVER's own `pilot_states()` (see `manned_vehicles`), because whether a
## person is aboard is the session's answer and not this file's (`air_picture.gd`, "THE SESSION DECIDES WHO IS A
## PLAYER"). `skip` is the entity the head itself is on, if any, so a craft does not report itself as a contact.
static func sweep(world: Object, head: Vector3, manned: Dictionary, range_m: float = REACH_M,
		mast_m: float = MAST_M, skip: int = 0) -> Array:
	var out: Array = []
	if world == null or not world.has_method("vehicle_states"):
		return out
	var eye: Vector3 = head + Vector3(0.0, mast_m, 0.0)
	for state_any in world.vehicle_states():
		var state := state_any as Dictionary
		var entity := int(state.get("entity", 0))
		if entity == 0 or entity == skip:
			continue
		var kind := int(state.get("kind", -1))
		# THE SAME THINGS THAT ARE NOT TRAFFIC ON THE PLOT, asked of `AirPicture` rather than listed again: a tower is
		# a building and a segway is a person standing up, and neither is a contact (rule 4).
		if kind < 0 or kind in AirPicture.NOT_TRAFFIC:
			continue
		if not (state.get("position") is Vector3):
			continue
		var at: Vector3 = state["position"]
		# RANGE FIRST, ALWAYS: it is arithmetic and the sight line is a query, so an out-of-range contact costs
		# nothing. On a 24 km map with a 60 km reach this rejects little, but a station with a short reach rejects
		# most of the world here rather than in the pyramid.
		if eye.distance_to(at) > range_m:
			continue
		if not SightLine.is_clear(world, eye, at):
			continue
		out.append(row_of(state, manned.has(entity)))
	return out


## ONE CONTACT AS A COMPACT ROW. Rounded to whole metres, whole degrees and whole metres per second, because that is
## all a plot draws and every digit past it is wire.
static func row_of(state: Dictionary, manned: bool) -> Array:
	var at: Vector3 = state["position"]
	var nose := Vector3.FORWARD
	if state.get("basis") is Quaternion:
		nose = (state["basis"] as Quaternion) * Vector3.FORWARD
	var speed: float = 0.0
	if state.get("velocity") is Vector3:
		speed = (state["velocity"] as Vector3).length()
	var kind := int(state.get("kind", -1))
	return [kind, roundi(at.x), roundi(at.y), roundi(at.z),
		wrapi(roundi(rad_to_deg(atan2(nose.x, -nose.z))), 0, 360), roundi(speed),
		1 if manned else 0, AirPicture.callsign_of(kind, int(state.get("entity", 0)))]


## A ROW READ BACK, as the plot wants it: the same keys `AirPicture.contacts` produces, so a display already written
## against that shape can be handed radar contacts without learning a second one.
##
## `contact` is NEGATIVE and is the hash of the CALL SIGN, because there is no id on the wire and a plot still needs
## a stable handle to keep a selection on one marker between sweeps. The call sign is the only thing about a contact
## that does not change as it flies, and it is what the operator is saying out loud anyway.
##
## **EVERY RADAR CONTACT IS GREY, INCLUDING A MANNED ONE, AND THAT IS ON PURPOSE.** `client` is -1 for all of them:
## radar says whether somebody is aboard, never who. Colouring a manned contact from `PlayerColours` would be a
## machine wearing a player's colour while carrying no player's name -- the exact lie `air_picture.gd` was written to
## prevent (team-lead, 2026-09-17), and worse here, because radar genuinely does not know who it is. `manned` rides
## the row so a display can say it in one of the OTHER channels `air_picture.gd` lists -- solid against an outline,
## or size -- which is where a fact radar actually has belongs.
static func read(row: Array) -> Dictionary:
	if row.size() < COLUMNS.size():
		return {}
	var at := Vector3(float(row[1]), float(row[2]), float(row[3]))
	var manned := int(row[6]) != 0
	return {
		"contact": -absi(hash(String(row[7]))), "client": -1, "vehicle": 0, "kind": int(row[0]),
		"position": at, "heading": deg_to_rad(float(row[4])), "speed": float(row[5]),
		"yours": false, "name": String(row[7]), "manned": manned,
		"colour": AirPicture.AI, "distance": -1.0}


## THE LONGEST A CALL SIGN MAY BE on the wire. `RadioPhrases.callsign` makes things like "AIRLINER 27"; 32 is well
## over anything it produces and short enough that a peer cannot post a paragraph into an operator's plot.
const NAME_MOST: int = 32
## The most contacts one page may carry. A page is cut to 512 bytes and the shortest plausible row is about 30, so
## nothing honest exceeds this -- it is here to bound what a malformed hello can make a reader allocate.
const MOST_PER_PAGE: int = 64


## WHETHER THAT IS A RADAR ROW, asked by `Net.read_hello` before a page is taken. The shape is defined HERE, beside
## `COLUMNS`, and not in the carrier: a reader with its own idea of the shape is a second idea of the shape
## (`NetStats.is_a_row` is the same arrangement for the same reason).
##
## THIS IS A CLIENT CHECKING ITS HOST, which is the direction rule 8 talks about least and still means. A host that
## sent a malformed picture would otherwise put whatever it liked straight onto an operator's plot, and the plot
## draws the name.
static func is_a_row(row: Variant) -> bool:
	if not row is Array or (row as Array).size() != COLUMNS.size():
		return false
	var fields: Array = row
	# THE SIX NUMBERS. JSON brings integers back as floats, so each is accepted as either and required to be whole.
	for i in range(0, 7):
		var value: Variant = fields[i]
		if not (value is int or value is float) or float(value) != floorf(float(value)):
			return false
	if int(fields[0]) < 0 or int(fields[0]) >= Sim.Kind.size():
		return false
	if int(fields[5]) < 0 or int(fields[6]) < 0 or int(fields[6]) > 1:
		return false
	if int(fields[4]) < 0 or int(fields[4]) >= 360:
		return false
	if not fields[7] is String or String(fields[7]).is_empty() or String(fields[7]).length() > NAME_MOST:
		return false
	return true


## WHICH VEHICLES HAVE SOMEBODY IN THEM, off the SERVER's own pilot list: `{entity: true}`. Asked of the authority,
## never kept, and never derived from a roster -- a craft is manned when a pilot is seated in it, which is the same
## thing `CrewManifest` reads and the only thing the server writes.
static func manned_vehicles(world: Object) -> Dictionary:
	var out: Dictionary = {}
	if world == null or not world.has_method("pilot_states"):
		return out
	for pilot_any in world.pilot_states():
		var vehicle := int((pilot_any as Dictionary).get("vehicle", 0))
		if vehicle != 0:
			out[vehicle] = true
	return out

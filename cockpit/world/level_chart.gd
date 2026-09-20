extends RefCounted
class_name LevelChart
## ONE LEVEL, AS ITS FOLDER DESCRIBES IT: `levels/<id>/level.json`, read and checked, or refused with the reason.
##
## Asked for on 2026-09-15: "let's have multiple levels that can load." A level is content, so it is a folder scanned at
## boot (building_a_game_here.md, rule 7): the folder's name is the id, and a file that does not say what a level needs
## disables that level with a message rather than taking the game down. `ChartDrawer` is the scan; this is one sheet.
##
##   {
##     "name": "The island",                        what the desk and the clipboard call it
##     "summary": "Fourteen kilometres of ...",     one line under the name
##     "world": "island",                           which ground the flight level stands it on: see `WORLDS`
##     "ground": {...},                             a generated world's three numbers, checked by the ground (optional)
##     "reach": 24000,                              how far the level is drawn, metres, unless the player says (optional)
##     "link_ms": 80,                               the one-way link every remote machine holds on this level (optional)
##     "stats": true,                               this level keeps per-client network statistics (optional)
##     "haze": 0.35,                                how much of the game's haze this level's air holds, 0.1 to 1 (optional)
##     "fleet": false,                              no ambient AI fleet, only what the level's traffic file flies (optional)
##     "fires": false,                              no fires lit or spread on this ground (optional; true unless it says)
##     "mountains": [{"salt": 5100, "peak": 900, "saddle": 250, "points": [[x, z, crest, foot], ...]}, ...]
##                                                  the island's kind of mountain range on a generated ground (optional)
##     "lift": [{"name": "the start", "at": [x, z], "radius": 450, "strength": 4.5}, ...]
##                                                  the level's own thermals on a generated ground, the first the one
##                                                  arrivals are launched at (optional)
##     "cloud_cover": 2.0,                          how many of the low clouds the sky holds, times the game's (optional)
##     "water": {"deep": [0.012, 0.078, 0.102], "crest": [0.035, 0.155, 0.140], "foam": [0.88, 0.93, 0.92]}
##                                                  the sea's colours, linear 0..1, each channel optional (optional)
##     "craft": {"kinds": ["glider"], "why": "it is for soaring"}   the only craft the level offers, and why (optional)
##     "launch": {"height": 304.8, "beside": 100}   arrivals and respawns launched at the first thermal, or beside
##                                                  another player (`GliderWinch`); needs "lift" (optional)
##     "arrive": "segway",                         what an arriving player is put in: a `Sim.Kind`, a pod unless it says
##     "spawn": {"at": [-21, 30, 0], "yaw_degrees": 0, "apart": 1.8}   x and z where the first arrival is put, the rest
##                                                       beside it and `apart` metres along; y its height over the
##                                                       highest ground or water near it
##   }
##
## STRICT ABOUT KEYS. A key this file does not know is a refusal, not a thing ignored: "spwan" read as no spawn at all
## would put every joiner at a default nobody wrote, and a default that looks like data is invisible (CLAUDE.md, rule 8).
##
## THE HASH IS OF WHAT THE FILE SAYS, NOT OF ITS BYTES. `core.autocrlf` is true on this machine and git's blob is LF
## (learnings/2026-09-15-cockpit-crewjoin.md): the same commit checked out on Windows and on Linux has different bytes in
## every text file. So the hash is SHA-256 of the parsed Dictionary written back out with its keys sorted, which two
## checkouts of one commit agree on and any change to a value does not. Rejected: hashing the raw file, which would
## refuse a Linux joiner a Windows host's identical level; and hashing the built collision, which catches code drift too
## but only after a joiner has spent the seconds building the world it is about to be refused -- code drift is the
## `build` check's question on a Steam lobby.

## WHAT AN ARRIVING PLAYER MAY BE PUT IN: every `Sim.Kind` there is, asked of the simulation's own enum rather than
## listed here, so a kind added to the C++ and to `Sim.Kind` is one a level may name with no line in this file edited. A
## flight level seats a pod; a briefing room seats a segway, which is how a player walks (agents.md, "A SEGWAY IS HOW A
## PLAYER WALKS").
static func arrivals() -> PackedStringArray:
	var out: PackedStringArray = []
	for named in Sim.Kind.keys():
		out.append(String(named).to_lower())
	return out


## WHICH GROUNDS THIS BUILD CAN STAND A LEVEL ON: `GroundTuning.World`, which is what the flight level builds, asked
## rather than listed. A level on any other world is refused, with the list in the message.
static func worlds() -> PackedStringArray:
	var out: PackedStringArray = []
	for named in GroundTuning.World.keys():
		out.append(String(named).to_lower())
	return out


## The farthest a level may ask to be drawn: the world square's side, which no eye inside it can see past.
const REACH_MOST: int = 65536

## What a folder name may be. It goes on the wire in the join handshake and onto a Steam lobby, so it is short and plain.
const ID_PATTERN: String = "^[a-z0-9_]{1,24}$"
const NAME_MOST: int = 32
const SUMMARY_MOST: int = 96
const KEYS: PackedStringArray = ["name", "summary", "world", "ground", "reach", "arrive", "spawn", "yard_devices",
	"link_ms", "stats", "haze", "mountains", "rivers", "rock_spacing", "fleet", "fires", "lift", "cloud_cover",
	"water", "craft", "launch"]
## THE SEA'S COLOURS A LEVEL MAY NAME (lane/watercolour, 2026-09-19): deep, crest and foam, each three linear floats
## 0..1, handed to both ocean shaders through `WaterSurface`. A channel the file does not name is the shader's own
## default -- never typed here, so the two cannot drift (CLAUDE.md, rule 4). {} is every level that says nothing, and
## the island's picture with it.
const WATER_KEYS: PackedStringArray = ["deep", "crest", "foam"]
## A LEVEL'S OWN THERMAL (lane/gliderlevel, 2026-09-19): the keys one has, and the range each number may take. The
## radius runs from about the circle a sailplane turns in (88 m at its autopilot's bank; learnings/2026-09-17-glider.md)
## to a wide weak day; the strength is the island's range and a little either side of it, m/s at the core.
const LIFT_KEYS: PackedStringArray = ["name", "at", "radius", "strength"]
const LIFT_RADIUS := Vector2(100.0, 1500.0)
const LIFT_STRENGTH := Vector2(0.5, 10.0)
const LIFT_MOST: int = 64
## HOW MANY OF THE GAME'S LOW CLOUDS A LEVEL'S SKY MAY HOLD, as a factor on `PuffSky.PER_100_KM2`. 1 is every level that
## says nothing. Four times is about 250 low clouds over the 32 km square the sky is planned on.
const CLOUD_COVER_DEFAULT: float = 1.0
const CLOUD_COVER := Vector2(0.25, 4.0)
const CRAFT_KEYS: PackedStringArray = ["kinds", "why"]
## A LEVEL'S WINCH (`GliderWinch`): how high over the ground the first thermal's launch is, and how far from another player
## a launch beside them may be, metres. Both the user's: "at the first zone at 1000 feet (or if there are other players,
## within 100 meteres of that player)".
const LAUNCH_KEYS: PackedStringArray = ["height", "beside"]
const LAUNCH_HEIGHT := Vector2(30.0, 3000.0)
const LAUNCH_BESIDE := Vector2(40.0, 1000.0)
## HOW MUCH OF THE GAME'S HAZE A LEVEL'S AIR HOLDS (lane/testfield, 2026-09-19): a factor on the depth fog's clear air
## (`Daylight`) and on the low mist's densities (`MistLayer`), so a level can be clearer than the island without a second
## copy of any preset. 1 is every level that says nothing, and the island's picture with it. The test field asks for less
## because it is for seeing the other airport 35 km away: at the island's clear air, 5 % of the view is left at 18.7 km.
const HAZE_DEFAULT: float = 1.0
const HAZE_LEAST: float = 0.1
const SPAWN_KEYS: PackedStringArray = ["at", "yaw_degrees", "apart"]
## WHAT A LEVEL THAT SAYS NOTHING SEATS ITS ARRIVALS IN. Every level said this before any level could say otherwise, so
## the island and the alpine world are untouched by the key existing -- and their `content_hash` with them.
const ARRIVE_DEFAULT: String = "pod"
## HOW FAR APART ARRIVALS STAND when a level says nothing: the 14 m `Sim` used to type beside the spawn, which is right
## for pods on a runway and absurd for eight people in a room.
const APART_DEFAULT: float = 14.0
## The closest and the furthest a level may stand two arrivals. Closer than half a pace is inside each other; a kilometre
## is eight players who never find one another.
const APART_LEAST: float = 0.5
const APART_MOST: float = 1000.0
## THE ONE-WAY LINK A LEVEL ASKS EVERY REMOTE MACHINE TO HOLD, milliseconds, or 0 -- which is every level that says
## nothing, and is what a machine goes back to when it leaves one that does. It is LEVEL CONTENT and not a local
## setting, so it is in `content_hash` and a host and a joiner cannot disagree about the link the measurement was taken
## over. What applies it, and why the HOST holds none of it, is `Net.suit_the_link`.
const LINK_MS_DEFAULT: int = 0
## A DEVICE YARD declares how many endpoints EACH of its two room banks contains. It is level content rather than a
## local graphics setting: the chart hash then refuses a peer whose level describes a different registry.
const YARD_DEVICES_DEFAULT: int = 100
const YARD_DEVICES_LEAST: int = 1
const YARD_DEVICES_MOST: int = 500
## HOW MANY ARRIVALS TO A ROW before the next starts behind it. `Sim` put them four abreast; this is that number, moved
## to where the room that draws a mark on each of them can read it too. EIGHT since the session went to sixty-four
## players (lane/seats, 2026-09-18): a square of eight by eight, 12.6 m a side at the usual 1.8 m, where four abreast
## ran sixteen rows, 27 m, back through the briefing room's wall.
const ROW: int = 8
## The file every level folder holds.
const FILE: String = "level.json"

var id: String = ""
var name: String = ""
var summary: String = ""
var world: String = ""
## A GENERATED WORLD'S THREE NUMBERS, as the ground takes them: the file's, or `GroundTuning.values()` when it names
## none. Empty on the island, which is boxes on a slab.
var ground: Dictionary = {}
## HOW FAR THE LEVEL ASKS TO BE DRAWN, metres, or 0 when it asks nothing and the view's own reach stands. A player's
## own setting overrides it on their machine (cockpit-terrain's increment D).
var reach: float = 0.0
## WHAT AN ARRIVING PLAYER IS PUT IN, a `Sim.Kind`: `Kind.POD` unless the file names another. See `arrivals`.
var arrive_kind: int = Sim.Kind.POD
## HOW FAR APART ARRIVALS STAND, metres. See `spot_for`, which is the only thing that reads it.
var apart: float = APART_DEFAULT
## X AND Z WHERE THE FIRST PLAYER'S POD IS PUT, AND Y ITS HEIGHT OVER THE HIGHEST GROUND OR WATER NEAR IT, not a world
## height: the island's slab is 0, so 30 is 30 there, and on the generated ground a pod is never put inside a hill
## (`Sim._seat_new_clients`, cockpit-terrain's increment E). `spawn_yaw` is which way it faces, radians.
var spawn_at: Vector3 = Vector3.ZERO
var spawn_yaw: float = 0.0
## Endpoints in each room of the Device Yard. It has no meaning on other levels, where it remains the default.
var yard_devices: int = YARD_DEVICES_DEFAULT
## WHETHER THIS LEVEL KEEPS PER-CLIENT NETWORK STATISTICS: client receipts on, a card to the host once a second, and a
## board that draws the table. It costs a trace callback per record on every machine, so it is a level's decision and
## not the game's -- see `Sim.want_receipts` and `NetStats`.
var keeps_stats: bool = false
## THE ONE-WAY LINK THIS LEVEL ASKS FOR, milliseconds. See `LINK_MS_DEFAULT` and `Net.suit_the_link`.
var link_ms: int = LINK_MS_DEFAULT
## THE SHARE OF THE GAME'S HAZE THIS LEVEL'S AIR HOLDS. See `HAZE_DEFAULT`.
var haze: float = HAZE_DEFAULT
## THE ISLAND'S KIND OF MOUNTAIN RANGE ON THIS LEVEL'S GENERATED GROUND (lane/testfield, 2026-09-19: "can you add some of
## our mountain ranges from the island map to the testfield?"), as `MountainRange.configure` takes a range: `{salt,
## peak, saddle, points}` with the points four ints each (x, z, crest, foot), crests in metres above sea level. [] for
## every level that says nothing. IN THE LEVEL FILE, not beside it, because every machine must stand the same rock and
## the file's hash is what a joiner is checked against. Checked by the rock itself when the level is read.
var mountains: Array[Dictionary] = []
## THE WATERCOURSES THE LEVEL LAYS (lane/rivers, 2026-09-20): `{points: [[x, z], ...], width, depth, corridor,
## draught}`, metres. [] for every level that says nothing. ONE DECLARATION, THREE CONSEQUENCES -- the ground function
## cuts the bed and stands the water in it, `Watercourse` works the canyon's walls out as two ranges either side, and
## the corridor between them is kept clear of rock. In the level file for the same reason the ranges are: every machine
## must cut the same ground, and the file's hash is what a joiner is checked against.
var rivers: Array[Dictionary] = []
## HOW FINE THE LEVEL'S ROCK IS CUT, metres between the mountain grid's vertices (lane/rivers, 2026-09-20). The user:
## "we should be able to tweak the quality there so we can up or downgrade the poly count based on our needs."
## `MountainRanges.SPACING` for every level that says nothing, so no level's rock moves.
##
## IT IS A LEVEL'S NUMBER AND NOT A MACHINE'S, and that is not a preference. The mountains' triangles ARE their
## collision (range_core.hpp: "what is drawn is what is hit, to the bit, at every distance"), static collision is not
## replicated (cockpit/agents.md, RULES 8), and every peer builds its own. A per-machine poly-count slider would give
## two peers different rock, and a peer whose hillside is elsewhere predicts itself into the server's -- which is why
## this is not on `Finish` (the PLAIN/FINE tier a player flips with a thumb) nor on `DetailReach` (distance). Those
## two axes are per-machine by design and neither can carry a number that changes what an aeroplane hits.
var rock_spacing: int = MountainRanges.SPACING
## WHETHER THE AMBIENT AI FLEET FLIES HERE (`Terrain.ai_fleet`, the machines wandering between waypoints): true for every
## level that says nothing. The test field says false (lane/testfield, 2026-09-19): it is for testing, its traffic is its
## `traffic.json`, and the ambient fleet held a suite of three trips to 2.2 times real time.
var fleet: bool = true
## WHETHER THE GROUND'S FIRES ARE LIT AND SPREAD (the user, 2026-09-19: "remove fires from the glider level"). True for every level
## that says nothing. A level whose craft cannot put a fire out says false: its smoke would only pile up.
var fires: bool = true
## THE LEVEL'S OWN THERMALS on a generated ground (lane/gliderlevel, 2026-09-19: "we'll need lift zones that the gliders
## can fly to"), each `{name, at: Vector2 (x, z), radius, strength}`, in the file's order: the FIRST is the zone arrivals
## are launched at. [] for every level that says nothing, whose thermals are the ground's own scatter. `Terrain.lift_zones`
## stands each on the ground under it. IN THE LEVEL FILE because every world simulates the air it holds, so every
## machine must agree on it, and the file's hash is what a joiner is checked against.
var lift: Array[Dictionary] = []
## HOW MANY OF THE GAME'S LOW CLOUDS THIS LEVEL'S SKY HOLDS, times the game's (`PuffSky.plan`). See `CLOUD_COVER`.
var cloud_cover: float = CLOUD_COVER_DEFAULT
## THE SEA'S COLOURS THIS LEVEL NAMES, as Vector3 linear 0..1 keyed deep / crest / foam. {} when the file says
## nothing, and then `WaterSurface.dressed` never writes those uniforms, so both shaders keep the defaults they
## already had. See `WATER_KEYS`.
var water: Dictionary = {}
## THE ONLY CRAFT THIS LEVEL OFFERS, as `Sim.Kind` values, and the reason the CRAFT page gives for it. [] offers every
## craft there is, which is every level that says nothing. The glider level says gliders (the user, 2026-09-19: "The goal
## is to experiment with what the game is like with just gliders").
var craft: Array[int] = []
var craft_why: String = ""
## WHERE ARRIVALS AND RESPAWNS ARE LAUNCHED, `{height, beside}` (`GliderWinch`), or {} for every level that says nothing,
## whose arrivals stand at `spawn_at` and whose respawns are `CrewRespawn`'s.
var launch: Dictionary = {}
## SHA-256 of the canonical file, lower-case hex: what a joiner checks against the host's. See the header.
var content_hash: String = ""
## Why this level is not usable, or "" when it is.
var refusal: String = ""


func usable() -> bool:
	return refusal == ""


## WHETHER THIS LEVEL IS A ROOM RATHER THAN A COUNTRY: no sea, no scenery, no traffic and nothing to fly. A suite that
## walks every level the desk offers asks this before sailing a boat round it (`tests/ship_legs.gd`).
func indoors() -> bool:
	return GroundTuning.world_named(world) == GroundTuning.World.ROOM


## READ ONE FOLDER. Always returns a chart; `refusal` says whether it can be flown.
static func read(folder: String) -> LevelChart:
	var chart := LevelChart.new()
	chart.id = folder.get_file()
	var pattern := RegEx.create_from_string(ID_PATTERN)
	if pattern.search(chart.id) == null:
		return _refused_chart(chart, "the folder name '%s' is not a level id: lower-case letters, digits and _, at most 24" % chart.id)
	var path: String = folder.path_join(FILE)
	if not FileAccess.file_exists(path):
		return _refused_chart(chart, "there is no %s in it" % FILE)
	var text: String = FileAccess.get_file_as_string(path)
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return _refused_chart(chart, "%s is not JSON: line %d, %s" % [FILE, parser.get_error_line(), parser.get_error_message()])
	if not parser.data is Dictionary:
		return _refused_chart(chart, "%s is not a JSON object" % FILE)
	chart._take(parser.data as Dictionary)
	return chart


## THE SAME CHECKS ON A DICTIONARY ALREADY IN HAND: what `read` does once the file has parsed.
func _take(data: Dictionary) -> void:
	for key in data:
		if not KEYS.has(String(key)):
			_refuse("'%s' is not a key a level has: %s" % [key, ", ".join(KEYS)])
			return
	if not data.get("name") is String or String(data["name"]).strip_edges().is_empty():
		_refuse("it has no name")
		return
	if String(data["name"]).length() > NAME_MOST:
		_refuse("its name is longer than %d letters" % NAME_MOST)
		return
	if not data.get("summary") is String or String(data["summary"]).strip_edges().is_empty():
		_refuse("it has no summary")
		return
	if String(data["summary"]).length() > SUMMARY_MOST:
		_refuse("its summary is longer than %d letters" % SUMMARY_MOST)
		return
	if not data.get("world") is String or not worlds().has(String(data["world"])):
		_refuse("its world '%s' is not one this build stands a level on: %s" % [data.get("world", ""),
			", ".join(worlds())])
		return
	if data.has("ground") and not data["ground"] is Dictionary:
		_refuse("its ground is not a JSON object")
		return
	# THE ISLAND IS BOXES ON A SLAB AND A ROOM IS FOUR WALLS ON ONE, AND NEITHER TAKES A GROUND NUMBER; a generated world
	# takes its own, or GroundTuning's, and the ground itself says what is wrong with them (cockpit-terrain, 2026-09-15).
	# WHICH IS WHICH IS THE GROUND'S ANSWER (`GroundTuning.takes_numbers`), not a world named here: the island was named
	# here, so the room world arrived as "a generated world with no numbers" and was refused by `GroundField.configure`.
	var tuning: Dictionary = {}
	if not GroundTuning.takes_numbers(GroundTuning.world_named(String(data["world"]))):
		if data.has("ground"):
			_refuse("its world '%s' takes no ground numbers" % String(data["world"]))
			return
	else:
		tuning = GroundTuning.whole_numbers(data.get("ground", GroundTuning.values()))
		var problems: PackedStringArray = GroundTuning.problems_with(tuning)
		if not problems.is_empty():
			_refuse("its ground will not stand: %s" % ", ".join(problems))
			return
	if data.has("reach") and (not (data["reach"] is float or data["reach"] is int) or float(data["reach"]) < 1.0
			or float(data["reach"]) > REACH_MOST):
		_refuse("its reach is not a distance from 1 m to %d m" % REACH_MOST)
		return
	if data.has("yard_devices") and (not (data["yard_devices"] is float or data["yard_devices"] is int)
			or int(data["yard_devices"]) != float(data["yard_devices"])
			or int(data["yard_devices"]) < YARD_DEVICES_LEAST or int(data["yard_devices"]) > YARD_DEVICES_MOST):
		_refuse("its yard_devices is not a whole endpoint count from %d to %d" % [YARD_DEVICES_LEAST, YARD_DEVICES_MOST])
		return
	# THE LINK IT ASKS FOR, checked against the one place that holds how much delay a machine may be asked to carry, so
	# a level cannot name a number the socket would clamp behind its back.
	if data.has("link_ms") and (not (data["link_ms"] is float or data["link_ms"] is int)
			or int(data["link_ms"]) != float(data["link_ms"])
			or int(data["link_ms"]) < 0 or int(data["link_ms"]) > Net.EXTRA_LATENCY_MOST_MS):
		_refuse("its link_ms is not a whole one-way delay from 0 ms to %d ms" % Net.EXTRA_LATENCY_MOST_MS)
		return
	if data.has("stats") and not data["stats"] is bool:
		_refuse("its stats is not true or false")
		return
	if data.has("mountains"):
		var rock: Array[Dictionary] = []
		var why: String = _mountains_from(data["mountains"], rock)
		if why == "" and not GroundTuning.takes_numbers(GroundTuning.world_named(String(data["world"]))):
			why = "its world '%s' is not a generated ground, and its rock is the island's own" % String(data["world"])
		if why != "":
			_refuse("its mountains will not stand: %s" % why)
			return
		mountains = rock
	if data.has("rock_spacing"):
		if (not (data["rock_spacing"] is float or data["rock_spacing"] is int)
				or int(data["rock_spacing"]) != float(data["rock_spacing"])
				or int(data["rock_spacing"]) < MountainRanges.SPACING_LEAST
				or int(data["rock_spacing"]) > MountainRanges.SPACING_MOST):
			_refuse("its rock_spacing is not a whole number of metres from %d to %d"
				% [MountainRanges.SPACING_LEAST, MountainRanges.SPACING_MOST])
			return
		rock_spacing = int(data["rock_spacing"])
	if data.has("rivers"):
		var laid: Array[Dictionary] = []
		var why_not: String = _rivers_from(data["rivers"], laid)
		if why_not == "" and not GroundTuning.takes_numbers(GroundTuning.world_named(String(data["world"]))):
			why_not = "its world '%s' is not a generated ground, and only a generated ground can cut one" % String(data["world"])
		if why_not != "":
			_refuse("its rivers will not run: %s" % why_not)
			return
		rivers = laid
	if data.has("fleet") and not data["fleet"] is bool:
		_refuse("its fleet is not true or false")
		return
	fleet = bool(data.get("fleet", true))
	if data.has("fires") and not data["fires"] is bool:
		_refuse("its fires is not true or false")
		return
	fires = bool(data.get("fires", true))
	if data.has("lift"):
		var zones: Array[Dictionary] = []
		var why_not: String = _lift_from(data["lift"], zones)
		if why_not == "" and not GroundTuning.takes_numbers(GroundTuning.world_named(String(data["world"]))):
			why_not = "its world '%s' is not a generated ground, and its lift is the island's own" % String(data["world"])
		if why_not != "":
			_refuse("its lift will not stand: %s" % why_not)
			return
		lift = zones
	if data.has("cloud_cover") and (not (data["cloud_cover"] is float or data["cloud_cover"] is int)
			or float(data["cloud_cover"]) < CLOUD_COVER.x or float(data["cloud_cover"]) > CLOUD_COVER.y):
		_refuse("its cloud_cover is not a share of the game's clouds from %.2f to %.1f" % [CLOUD_COVER.x, CLOUD_COVER.y])
		return
	cloud_cover = float(data.get("cloud_cover", CLOUD_COVER_DEFAULT))
	if data.has("water"):
		var why_not: String = _water_from(data["water"])
		if why_not != "":
			_refuse("its water will not do: %s" % why_not)
			return
	if data.has("craft"):
		var why_not: String = _craft_from(data["craft"])
		if why_not != "":
			_refuse("its craft list will not do: %s" % why_not)
			return
	if data.has("launch"):
		var why_not: String = _launch_from(data["launch"])
		if why_not == "" and lift.is_empty():
			why_not = "it has no lift, and a launch is at the first thermal"
		if why_not != "":
			_refuse("its launch will not do: %s" % why_not)
			return
	if data.has("haze") and (not (data["haze"] is float or data["haze"] is int) or float(data["haze"]) < HAZE_LEAST
			or float(data["haze"]) > HAZE_DEFAULT):
		_refuse("its haze is not a share of the game's from %.1f to %.1f" % [HAZE_LEAST, HAZE_DEFAULT])
		return
	# WHAT ITS ARRIVALS STAND IN, checked against the simulation's own list: a level naming a kind this build has not got
	# would have seated everybody in kind -1, which spawns nothing and says nothing about it.
	if data.has("arrive") and (not data["arrive"] is String or not arrivals().has(String(data["arrive"]))):
		_refuse("its arrivals stand in '%s', which is not a kind: %s" % [data.get("arrive", ""),
			", ".join(arrivals())])
		return
	if not data.get("spawn") is Dictionary:
		_refuse("it has no spawn")
		return
	var spawn: Dictionary = data["spawn"]
	for key in spawn:
		if not SPAWN_KEYS.has(String(key)):
			_refuse("'%s' is not a key a spawn has: %s" % [key, ", ".join(SPAWN_KEYS)])
			return
	var at: Variant = spawn.get("at")
	if not at is Array or (at as Array).size() != 3 or not _all_numbers(at as Array):
		_refuse("its spawn has no 'at' of three numbers")
		return
	if not (spawn.get("yaw_degrees") is float or spawn.get("yaw_degrees") is int):
		_refuse("its spawn has no yaw_degrees")
		return
	if spawn.has("apart") and (not (spawn["apart"] is float or spawn["apart"] is int)
			or float(spawn["apart"]) < APART_LEAST or float(spawn["apart"]) > APART_MOST):
		_refuse("its spawn stands arrivals apart by %s, which is not a distance from %.1f m to %d m"
			% [spawn["apart"], APART_LEAST, int(APART_MOST)])
		return
	name = String(data["name"]).strip_edges()
	summary = String(data["summary"]).strip_edges()
	world = String(data["world"])
	ground = tuning
	reach = float(data.get("reach", 0.0))
	arrive_kind = int(arrivals().find(String(data.get("arrive", ARRIVE_DEFAULT))))
	spawn_at = Vector3(float(at[0]), float(at[1]), float(at[2]))
	spawn_yaw = deg_to_rad(float(spawn["yaw_degrees"]))
	apart = float(spawn.get("apart", APART_DEFAULT))
	yard_devices = int(data.get("yard_devices", YARD_DEVICES_DEFAULT))
	link_ms = int(data.get("link_ms", LINK_MS_DEFAULT))
	keeps_stats = bool(data.get("stats", false))
	haze = float(data.get("haze", HAZE_DEFAULT))
	content_hash = canonical_hash(data)


## A LEVEL FILE'S MOUNTAINS, as `MountainRange` takes them, into `out`; "" or what is wrong, in the rock's own words where
## the rock says (`MountainRange.configure` holds every range's limits, and a copy here would be a second one).
static func _mountains_from(listed: Variant, out: Array[Dictionary]) -> String:
	if not (listed is Array) or (listed as Array).is_empty():
		return "it is not a list of ranges"
	for one in listed:
		if not (one is Dictionary):
			return "a range is not an object"
		var points := PackedInt32Array()
		for point in (one as Dictionary).get("points", []):
			if not (point is Array) or (point as Array).size() != 4 or not _all_numbers(point):
				return "a range's point is not [x, z, crest, foot]"
			for v in point:
				points.append(int(v))
		var range := {"points": points}
		for key in one:
			if key == "points":
				continue
			if not ["salt", "peak", "saddle"].has(String(key)):
				return "'%s' is not a key a range has" % key
			if not ((one as Dictionary)[key] is float or (one as Dictionary)[key] is int):
				return "a range's %s is not a number" % key
			range[key] = int((one as Dictionary)[key])
		out.append(range)
	if not ClassDB.class_exists(&"MountainRange"):
		return "this build has no MountainRange"
	var rock: Object = ClassDB.instantiate(&"MountainRange")
	var problems: PackedStringArray = rock.call("configure", {"spacing": MountainRanges.SPACING,
		"tile_quads": MountainRanges.TILE_QUADS, "ranges": out, "keepouts": PackedInt32Array()})
	return ", ".join(problems)


## A LEVEL FILE'S WATERCOURSES, into `out` as `rivers` holds them; "" or what is wrong. The numbers are checked here
## against `Watercourse`'s ranges, and the whole list is then offered to a throwaway `GroundField` -- the same thing
## that will cut the ground -- so a river this file accepts is one the ground function accepts, and the message a level
## author sees is the ground's own.
static func _rivers_from(listed: Variant, out: Array[Dictionary]) -> String:
	if not (listed is Array) or (listed as Array).is_empty():
		return "it is not a list of rivers"
	for one in listed:
		if not (one is Dictionary):
			return "a river is not an object"
		var river: Dictionary = one
		for key in river:
			if not Watercourse.KEYS.has(String(key)):
				return "'%s' is not a key a river has: %s" % [key, ", ".join(Watercourse.KEYS)]
		if not (river.get("points", null) is Array) or (river["points"] as Array).size() < 2:
			return "a river's points is not a centre line of two or more [x, z]"
		var points: Array[Array] = []
		for point in (river["points"] as Array):
			if not (point is Array) or (point as Array).size() != 2 or not _all_numbers(point):
				return "a river's point is not [x, z]"
			points.append([int((point as Array)[0]), int((point as Array)[1])])
		var laid: Dictionary = {"points": points}
		for key in ["width", "depth", "corridor", "draught"]:
			if not river.has(key):
				continue
			if not (river[key] is float or river[key] is int):
				return "a river's %s is not a number" % key
			laid[key] = int(river[key])
		if laid.has("width") and (int(laid["width"]) < Watercourse.WIDTH.x or int(laid["width"]) > Watercourse.WIDTH.y):
			return "a river's width is not from %d to %d m" % [Watercourse.WIDTH.x, Watercourse.WIDTH.y]
		if laid.has("depth") and (int(laid["depth"]) < Watercourse.DEPTH.x or int(laid["depth"]) > Watercourse.DEPTH.y):
			return "a river's depth is not from %d to %d m" % [Watercourse.DEPTH.x, Watercourse.DEPTH.y]
		out.append(laid)
	if not ClassDB.class_exists(&"GroundField"):
		return "this build has no GroundField"
	return ""


## A LEVEL FILE'S THERMALS, into `out` as `lift` holds them; "" or what is wrong. Names are how a test, a pilot and the
## first zone are spoken of, so they are unique and never empty.
static func _lift_from(listed: Variant, out: Array[Dictionary]) -> String:
	if not (listed is Array) or (listed as Array).is_empty() or (listed as Array).size() > LIFT_MOST:
		return "it is not a list of 1 to %d thermals" % LIFT_MOST
	var names: Dictionary = {}
	for one in listed:
		if not (one is Dictionary):
			return "a thermal is not an object"
		var zone: Dictionary = one
		for key in zone:
			if not LIFT_KEYS.has(String(key)):
				return "'%s' is not a key a thermal has: %s" % [key, ", ".join(LIFT_KEYS)]
		var named: Variant = zone.get("name")
		if not (named is String) or String(named).strip_edges().is_empty() or String(named).length() > NAME_MOST:
			return "a thermal has no name of 1 to %d letters" % NAME_MOST
		if names.has(String(named)):
			return "two thermals are called '%s'" % named
		names[String(named)] = true
		var at: Variant = zone.get("at")
		if not (at is Array) or (at as Array).size() != 2 or not _all_numbers(at as Array):
			return "the thermal '%s' has no 'at' of two numbers, x and z" % named
		for key in ["radius", "strength"]:
			if not (zone.get(key) is float or zone.get(key) is int):
				return "the thermal '%s' has no %s" % [named, key]
		if float(zone["radius"]) < LIFT_RADIUS.x or float(zone["radius"]) > LIFT_RADIUS.y:
			return "the thermal '%s' reaches %s m from its middle, not %d to %d" % [named, zone["radius"], int(LIFT_RADIUS.x),
				int(LIFT_RADIUS.y)]
		if float(zone["strength"]) < LIFT_STRENGTH.x or float(zone["strength"]) > LIFT_STRENGTH.y:
			return "the thermal '%s' rises %s m/s, not %.1f to %.1f" % [named, zone["strength"], LIFT_STRENGTH.x,
				LIFT_STRENGTH.y]
		out.append({"name": String(named), "at": Vector2(float(at[0]), float(at[1])), "radius": float(zone["radius"]),
			"strength": float(zone["strength"])})
	return ""


## A LEVEL FILE'S CRAFT LIST, into `craft` and `craft_why`; "" or what is wrong. Kinds are checked against the simulation's
## own list, as `arrive` is, and must be ones a player can be put in: a level offering only a kind nobody may board offers
## nothing at all.
func _craft_from(listed: Variant) -> String:
	if not (listed is Dictionary):
		return "it is not an object with kinds and why"
	var given: Dictionary = listed
	for key in given:
		if not CRAFT_KEYS.has(String(key)):
			return "'%s' is not a key a craft list has: %s" % [key, ", ".join(CRAFT_KEYS)]
	var kinds: Variant = given.get("kinds")
	if not (kinds is Array) or (kinds as Array).is_empty():
		return "it names no kinds"
	var why: Variant = given.get("why")
	if not (why is String) or String(why).strip_edges().is_empty() or String(why).length() > SUMMARY_MOST:
		return "it gives no reason of 1 to %d letters" % SUMMARY_MOST
	var out: Array[int] = []
	for named in kinds:
		var kind: int = arrivals().find(String(named)) if named is String else -1
		if kind < 0:
			return "'%s' is not a kind: %s" % [named, ", ".join(arrivals())]
		if not bool(Sim.geometry_of(kind).get("pilotable", true)):
			return "nobody may be put in a %s" % named
		if not out.has(kind):
			out.append(kind)
	craft = out
	craft_why = String(why).strip_edges()
	return ""


## A LEVEL FILE'S SEA, into `water`; "" or what is wrong. Each channel is three linear numbers 0..1, the uniforms
## `source_color` already are; a missing channel is the shader's default, never a copy of it kept here.
func _water_from(given: Variant) -> String:
	if not (given is Dictionary):
		return "it is not an object with deep, crest or foam"
	for key in given:
		if not WATER_KEYS.has(String(key)):
			return "'%s' is not a key a sea's colour has: %s" % [key, ", ".join(WATER_KEYS)]
		var value: Variant = (given as Dictionary)[key]
		if not (value is Array) or (value as Array).size() != 3 or not _all_numbers(value as Array):
			return "its %s is not three numbers" % key
		for channel in value:
			if float(channel) < 0.0 or float(channel) > 1.0:
				return "its %s is not a colour from 0 to 1" % key
		water[String(key)] = Vector3(float(value[0]), float(value[1]), float(value[2]))
	return ""


## A LEVEL FILE'S WINCH, into `launch`; "" or what is wrong.
func _launch_from(given: Variant) -> String:
	if not (given is Dictionary):
		return "it is not an object with height and beside"
	for key in given:
		if not LAUNCH_KEYS.has(String(key)):
			return "'%s' is not a key a launch has: %s" % [key, ", ".join(LAUNCH_KEYS)]
	var limits: Array[Vector2] = [LAUNCH_HEIGHT, LAUNCH_BESIDE]
	for i in range(LAUNCH_KEYS.size()):
		var value: Variant = (given as Dictionary).get(LAUNCH_KEYS[i])
		if not (value is float or value is int) or float(value) < limits[i].x or float(value) > limits[i].y:
			return "its %s is not a distance from %d m to %d m" % [LAUNCH_KEYS[i], int(limits[i].x), int(limits[i].y)]
	launch = {"height": float(given["height"]), "beside": float(given["beside"])}
	return ""


## WHETHER THIS LEVEL OFFERS A KIND: every kind, unless its file names the only ones it does.
func offers(kind: int) -> bool:
	return craft.is_empty() or craft.has(kind)


## WHERE THE SLOT-TH ARRIVAL IS PUT: `spawn_at` for the first, then `apart` metres along in rows of `ROW`. Y is the
## spawn's own, which is a HEIGHT OVER WHAT IS UNDER IT and not a world height -- whoever puts a machine there adds the
## ground under it (`Sim._seat_new_clients`).
##
## ONE FUNCTION FOR THE SEATING AND FOR THE PICTURE. `Sim` worked this out inline, so the briefing room's floor marks
## would have been a second copy of the same arithmetic and a mark could have stood where nobody is ever put (CLAUDE.md,
## rule 4: a value that must agree with another is computed from it).
func spot_for(slot: int) -> Vector3:
	return spawn_at + Vector3(float(slot % ROW) * apart, 0.0, float(slot / ROW) * apart)


## SHA-256 OF A LEVEL'S DATA, written out with sorted keys. See the header for why not the bytes.
static func canonical_hash(data: Dictionary) -> String:
	return JSON.stringify(data, "", true).sha256_text()


static func _all_numbers(values: Array) -> bool:
	for value in values:
		if not (value is float or value is int):
			return false
	return true


func _refuse(why: String) -> void:
	refusal = why


## A chart refused, for `read` to hand back: `read` is static, so the chart is its own local and not `self` -- a method
## typed to return its own class cannot `return self` when lint compiles the script on its own ("Cannot return value of
## type gdscript://...", 2026-09-15).
static func _refused_chart(chart: LevelChart, why: String) -> LevelChart:
	chart.refusal = why
	return chart

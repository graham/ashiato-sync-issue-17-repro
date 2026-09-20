extends Node
class_name RadarWatch
## THE THING THAT SWEEPS, ONCE A SECOND: on a host it draws each peer its own radar picture and sends it; on every
## machine it keeps the latest one that arrived and hands it to whatever is drawing.
##
## `RadarSet` is the sensor and knows nothing about the session. This is the part that knows there are peers, that
## each has a head of its own, and that a picture is worth nothing a second later. `NetStats` is the same shape --
## a node on a timer that publishes on the host and keeps what arrives on a client -- and it is the shape because it
## already works.
##
## ---------------------------------------------------------------------------------------------------
## EACH PEER GETS ITS OWN PICTURE, WHICH IS WHAT MAKES ANY OF THIS MEAN ANYTHING
## ---------------------------------------------------------------------------------------------------
##
## Every other carrier in `Net` publishes one thing to everybody. This one loops the peers and sweeps once per head,
## because a radar picture is what ONE head can see: send everybody the same list and terrain masking becomes a
## decoration. `Net.publish_the_radar_picture` takes `{peer: rows}` for that reason.
##
## THE HOST'S OWN PICTURE NEVER GOES ON THE WIRE. `multiplayer.get_peers()` does not include the host, so the host
## sweeps for itself and keeps the answer directly -- the same way `NetStats` puts its own row in its own table
## before publishing anybody else's. Without that, a solo game and a host with nobody aboard would both have no
## radar at all, which are the two cases somebody developing this will actually be looking at.
##
## ---------------------------------------------------------------------------------------------------
## WHERE A HEAD IS, AND THE PART OF IT THAT IS PROVISIONAL
## ---------------------------------------------------------------------------------------------------
##
## A peer flying something has its head ON that craft, asked of the SERVER: its pilot's vehicle, and that vehicle's
## position out of the server's own `vehicle_states`. Never out of `Sim.current`, which is the client's list and
## numbers its entities differently (`world/radar_set.gd`).
##
## **A PEER FLYING NOTHING -- which is exactly what a tower controller is -- LOOKS FROM THE CONTROL TOWER**, and the
## tower is not a new idea that had to be invented for this: `Terrain` already stands a `Sim.Kind.TOWER` in the world
## where `AirbasePlan` puts it beside the first runway, as a real entity the server holds a position for. So the
## controller's aerial is on the actual building a controller would be sitting in, without a level gaining a field,
## a kind being added, or anything being typed twice.
##
## IT WAS THE MIDDLE OF THE MAP FOR ONE COMMIT and that was a stated placeholder; this replaces it. The middle of the
## map is nowhere -- on the island it is open water -- so a controller was being given a picture from a point no
## controller could stand at, and on any level whose airfield is off to one side it would have been wrong rather
## than merely arbitrary.
##
## A LEVEL WITH NO TOWER falls back to the middle of the map, which is the old behaviour and is the right one for a
## level that has no control tower in it: a radar picture from nowhere in particular beats no radar picture at all,
## and the alternative is a controller staring at an empty plot with nothing to say why.
##
## ---------------------------------------------------------------------------------------------------
## A PAGE THAT NEVER ARRIVES IS A GAP, AND A GAP IS THE RIGHT ANSWER
## ---------------------------------------------------------------------------------------------------
##
## Pages are latest-only and never repeated (`Net.publish_the_radar_picture`). Page 0 starts a fresh picture and the
## rest add to it, so a lost page is a short picture for one second. Nothing acknowledges and nothing retries,
## because a controller acting on a contact that has moved is worse off than one looking at a gap.

## How often a sweep is drawn and sent, milliseconds. A second, which is what the statistics board and
## `SERVER_CONSOLE` already use, and is about the sweep period of a real area radar.
const EVERY_MSEC: int = 1000

## THE LATEST PICTURE THIS MACHINE HAS, as compact `RadarSet.COLUMNS` rows. Replaced wholesale, never merged.
var rows: Array = []
## When it was drawn, by this machine's clock, so a display can say how old it is rather than implying it is now.
var drawn_at: int = 0
## WHERE THIS MACHINE'S OWN SWEEP LOOKED FROM, and whether that was the control tower rather than a craft. Reported
## on `SESSION_REPORT` so a suite can hold the head to the tower: "the picture is smaller" is not evidence that the
## aerial moved, because a picture is smaller for a dozen reasons.
var head: Vector3 = Vector3.ZERO
var from_the_tower: bool = false
## The picture being assembled, and which sweep its pages belong to. -1 before any has arrived.
var _building: Array = []
var _building_sweep: int = -1
var _next_msec: int = 0


func _ready() -> void:
	_next_msec = Time.get_ticks_msec() + EVERY_MSEC
	Net.radar_heard.connect(_hear_a_page)


## HOW OLD THE PICTURE IS, seconds. A plot should say this: radar that is drawn once a second is never now, and a
## number on a screen with no age on it reads as though it were.
func age() -> float:
	return -1.0 if drawn_at == 0 else float(Time.get_ticks_msec() - drawn_at) / 1000.0


## THE PICTURE IN THE SHAPE THE PLOT ALREADY DRAWS (`AirPicture.contacts`'s rows), read back through `RadarSet.read`.
func contacts() -> Array:
	var out: Array = []
	for row in rows:
		var read: Dictionary = RadarSet.read(row as Array)
		if not read.is_empty():
			out.append(read)
	return out


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if now < _next_msec:
		return
	_next_msec = now + EVERY_MSEC
	# ONLY THE AUTHORITY SWEEPS. A client has no server to ask and must not invent a picture: it draws what it was
	# sent, and if it was sent nothing it draws nothing (rule 10).
	if Sim.server == null:
		return
	var manned: Dictionary = RadarSet.manned_vehicles(Sim.server)
	var places: Dictionary = _where_everything_is()
	var mine: int = Sim.local_client_id()

	# THIS MACHINE'S OWN, kept rather than sent.
	head = _head_for(mine, places)
	from_the_tower = _craft_of(mine) == 0 and places.has(TOWER)
	rows = RadarSet.sweep(Sim.server, head, manned, RadarSet.REACH_M, RadarSet.MAST_M, _craft_of(mine))
	drawn_at = now

	if not Net.is_networked() or not Net.is_host:
		return
	var by_peer: Dictionary = {}
	for peer in multiplayer.get_peers():
		var client: int = Sim.server_client_of_peer(int(peer))
		by_peer[int(peer)] = RadarSet.sweep(Sim.server, _head_for(client, places), manned,
			RadarSet.REACH_M, RadarSet.MAST_M, _craft_of(client))
	Net.publish_the_radar_picture(by_peer)


## WHERE EVERY VEHICLE IS, off the SERVER's own list, asked once a sweep instead of once a peer: eight peers would
## otherwise walk the same ninety-craft list eight times to find eight positions. The control tower is picked out on
## the same pass, under `TOWER`, for the same reason.
const TOWER: StringName = &"tower"


func _where_everything_is() -> Dictionary:
	var out: Dictionary = {}
	for state_any in Sim.server.vehicle_states():
		var state := state_any as Dictionary
		var at: Vector3 = state.get("position", Vector3.ZERO)
		out[int(state.get("entity", 0))] = at
		# THE FIRST TOWER IN THE WORLD, and the first is the right one: `Terrain` stands one beside the first runway,
		# and a level with several would want a controller to CHOOSE, which is a question for the seat and not for a
		# sweep. Its origin is the middle of its box (`Terrain`, "stood on its own half-height"), so the aerial sits
		# on top of the building rather than inside it.
		if not out.has(TOWER) and int(state.get("kind", -1)) == Sim.Kind.TOWER:
			var half: float = (Sim.geometry_of(Sim.Kind.TOWER).get("extents", Vector3.ONE) as Vector3).y
			out[TOWER] = at + Vector3.UP * half
	return out


## WHICH CRAFT A CLIENT IS IN, off the server's own pilots, or 0. The server is asked because it is the only thing
## that knows; `Sim.pilots` is the client's copy and its entity ids are not these.
func _craft_of(client: int) -> int:
	if client <= 0 or Sim.server == null:
		return 0
	for pilot_any in Sim.server.pilot_states():
		var pilot := pilot_any as Dictionary
		if int(pilot.get("client", 0)) == client:
			return int(pilot.get("vehicle", 0))
	return 0


## WHERE THAT CLIENT'S RADAR LOOKS FROM: their own craft if they are in one, the control tower if they are not, and
## the middle of the map only on a level that has no tower. See the doc block.
func _head_for(client: int, places: Dictionary) -> Vector3:
	var craft: int = _craft_of(client)
	if craft != 0 and places.has(craft):
		return places[craft]
	if places.has(TOWER):
		return places[TOWER]
	return Vector3.ZERO


## A PAGE ARRIVED. A CHANGE OF SWEEP NUMBER starts the next picture, and the picture is handed to whatever is
## drawing after EVERY page rather than only after the last one.
##
## **IT USED TO START ON PAGE 0 AND THAT WAS A BUG THE SUITE CAUGHT.** Pages are sent once and never repeated, so
## losing one is ordinary -- and when the lost one was page 0, every later page was appended to the PREVIOUS sweep's
## list, for ever. Measured on the island: a joiner drew **120 contacts in a world holding 96**, which is the shape
## of the fault -- a plot cannot show more aircraft than exist, and it only ever grows. `radar_peers`' check that
## the picture is smaller than the world is what named it, having been written to catch something else entirely.
##
## The sweep number is on every page (`Net.radar_pages`), so ANY page can be lost and the next sweep still starts
## clean. Page 0 no longer means anything in particular.
##
## A PLOT CAN STILL BRIEFLY SHOW A SHORT SWEEP, and that is the lesser of the two wrongs. Waiting for the last page
## would mean a picture whose final page was lost is never shown at all -- the plot would hold the previous second's
## contacts, which have moved, and look perfectly confident. Growing into place shows fewer contacts for a few
## milliseconds and never shows a stale one.
func _hear_a_page(heard: Array, _page: int, sweep: int) -> void:
	if sweep != _building_sweep:
		_building = []
		_building_sweep = sweep
	_building.append_array(heard)
	rows = _building.duplicate()
	drawn_at = Time.get_ticks_msec()

extends RefCounted
class_name CrewManifest
## WHO IS IN WHICH CRAFT, AND WHICH SEATS ARE FREE: what the CREW page draws, read off what every machine already holds.
##
## A manifest is the list a crew signs: the craft, its seats, and who is in each. One row per CREWED craft -- a craft
## with at least one player in it -- because that is the question the page answers ("where can I sit with somebody"),
## and the hundred and forty machines flying themselves are the CRAFT tab's business.
##
## WHICH CRAFT ARE CREWED COMES OFF THE PILOTS, AND WHO SITS WHERE OFF THE CRAFT'S OWN SEATS. `pilot_states` names the
## vehicle each player is in; `vehicle_seats` is that vehicle's Seats component, which the server alone writes and
## sends to everybody, so two machines that have caught up read the same manifest. The seats are read from the craft and
## not from the pilots because an occupant is a byte in Seats whether or not this machine has been sent its pilot yet --
## and a manifest built from pilots alone offered a JOIN on three seats the server had filled (tests/clipboard.gd,
## 2026-09-15, "a full craft is listed with no join on it", 3 JOIN buttons). Nothing here asks the network a question and nothing here
## decides anything: a free seat on this list is a seat that was free on the last tick this machine heard about, and
## the server is who says whether it still is.
##
## A CRAFT IS NAMED BY A PLAYER IN IT, `names`: the first occupant in seat order, which is the pilot whenever there is
## one. Client ids mean the same on every machine and entity ids do not, so a JOIN carries "the craft that player is in"
## and a seat number (`ControlInput::join_seat`), and the page writes "PLAYER n'S" under the kind so four battleships can
## be told apart (team-lead, 2026-09-15: four identical BATTLESHIP headers). No craft has a callsign to use instead.
##
## NEAREST FIRST, after your own. A session holds at most `Net.MAX_PLAYERS` players and so at most that many crewed craft,
## which is more rows than the board shows at once; the ones in sight of you are the likeliest to be wanted, and the page
## scrolls with the thumb for the rest. `distance` is metres from your craft, or -1 when either craft's pose is unknown.
##
## A craft this machine has a pilot in but has not been sent yet -- the tick a join lands -- has no kind to read seats
## from, and is left off until it arrives rather than drawn with no seats.
##
## Rows, yours first and then by `names`:
##   {"vehicle": entity on this machine, "kind": Sim.Kind, "kind_name": "plane", "yours": bool, "names": client id,
##    "free": count, "distance": metres or -1, "seats": [{"seat": 0, "station": "pilot", "client": id or -1, "you": bool}]}

## HOW MANY SEATS A ROW OF THE PAGE HOLDS SIDE BY SIDE. A craft with more wraps onto further lines of this many.
## Four, because four seats was every craft there was when the page was drawn, and a four-seat craft's row is the same
## row it always was (tests/clipboard.gd, "the crew page fits full").
const ROW_SEATS: int = 4
## PAST THIS MANY SEATS, A CRAFT'S FREE SEATS ARE FOLDED, one cell for each station that has any: "OPERATOR ×9" and one
## JOIN, which asks for the first free seat of that station. Somebody sitting down is always a cell of their own. A
## craft may have any number of seats since lane/seats (2026-09-18, "yes, no max"), and a row of sixty-four JOINs on a
## clipboard is not a thing anybody can choose from; the fold is what keeps the page a page.
const FOLD_PAST: int = 8


## The manifest for these pilots and vehicle states, as `me`. `stations_of(kind)` answers the station name of each seat
## of a kind, in seat order; left out, it is `stations`, which asks the simulation's own shape table. `seats_of(vehicle)`
## answers the vehicle's occupants, one per seat it has and -1 for empty, as `CockpitWorld.vehicle_seats` does; left out, or answering
## nothing, the pilots' own seats stand in for it, which is what a page handed a made-up manifest has.
static func read(pilots: Array, current: Dictionary, me: int, stations_of: Callable = Callable(),
		seats_of: Callable = Callable()) -> Array:
	var aboard: Dictionary = {}
	for state in pilots:
		var row := state as Dictionary
		var vehicle: int = int(row.get("vehicle", 0))
		var client: int = int(row.get("client", 0))
		if vehicle == 0 or client <= 0:
			continue
		(aboard.get_or_add(vehicle, {}) as Dictionary)[int(row.get("seat", 0))] = client
	var out: Array = []
	for vehicle in aboard:
		var kind: int = int((current.get(vehicle, {}) as Dictionary).get("kind", -1))
		if kind < 0:
			continue
		var named: PackedStringArray = stations_of.call(kind) if stations_of.is_valid() else stations(kind)
		var taken: Dictionary = aboard[vehicle]
		var occupants: PackedInt64Array = seats_of.call(vehicle) if seats_of.is_valid() else PackedInt64Array()
		if not occupants.is_empty():
			taken = {}
			for seat in range(occupants.size()):
				if int(occupants[seat]) >= 0:
					taken[seat] = int(occupants[seat])
		var seats: Array = []
		var free: int = 0
		for seat in range(named.size()):
			var who: int = int(taken.get(seat, -1))
			free += 1 if who < 0 else 0
			seats.append({"seat": seat, "station": named[seat], "client": who, "you": me > 0 and who == me})
		var first: int = -1
		var yours: bool = false
		var in_order: Array = taken.keys()
		in_order.sort()
		for seat in in_order:
			if first < 0:
				first = int(taken[seat])
			yours = yours or (me > 0 and int(taken[seat]) == me)
		out.append({"vehicle": vehicle, "kind": kind, "kind_name": Sim.kind_name(kind), "yours": yours,
			"names": first, "free": free, "seats": seats, "distance": -1.0})
	# HOW FAR EACH IS FROM YOURS, off the poses this machine draws.
	var here: Variant = null
	for craft in out:
		if bool(craft["yours"]):
			here = (current.get(int(craft["vehicle"]), {}) as Dictionary).get("position", null)
	if here is Vector3:
		for craft in out:
			var there: Variant = (current.get(int(craft["vehicle"]), {}) as Dictionary).get("position", null)
			if there is Vector3:
				craft["distance"] = (there as Vector3).distance_to(here as Vector3)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a["yours"]) != bool(b["yours"]):
			return bool(a["yours"])
		if float(a["distance"]) != float(b["distance"]):
			if float(a["distance"]) < 0.0 or float(b["distance"]) < 0.0:
				return float(a["distance"]) >= 0.0
			return float(a["distance"]) < float(b["distance"])
		return int(a["names"]) < int(b["names"]))
	return out


## What each seat of a kind is, in seat order: "pilot", "copilot", "turret" and the rest, off the shape table the
## simulation flies (`kind_geometry`), so a seat's word on the page is the station its stick is wired to.
static func stations(kind: int) -> PackedStringArray:
	var out := PackedStringArray()
	for seat in Sim.geometry_of(kind).get("seat_poses", []):
		out.append(String((seat as Dictionary).get("station", "seat")))
	return out


## WHAT THE PAGE DRAWS FOR ONE CRAFT, in order: a cell per seat, or, on a craft of more than `FOLD_PAST` seats, a cell
## per occupied seat and one per station with free seats. Each is `{seat, station, client, you, free}`: `free` is how many
## free seats the cell stands for (1 for an ordinary free seat, 0 for an occupied one), and `seat` is the one its JOIN
## asks for -- the first free one of that station.
static func cells(craft: Dictionary) -> Array:
	var seats: Array = craft.get("seats", [])
	var out: Array = []
	if seats.size() <= FOLD_PAST:
		for seat in seats:
			var cell: Dictionary = (seat as Dictionary).duplicate()
			cell["free"] = 1 if int(cell.get("client", -1)) < 0 else 0
			out.append(cell)
		return out
	var folded: Dictionary = {}
	for seat in seats:
		var row := seat as Dictionary
		if int(row.get("client", -1)) >= 0:
			var taken: Dictionary = row.duplicate()
			taken["free"] = 0
			out.append(taken)
			continue
		var station: String = String(row.get("station", "seat"))
		if folded.has(station):
			(folded[station] as Dictionary)["free"] = int((folded[station] as Dictionary)["free"]) + 1
			continue
		var group: Dictionary = row.duplicate()
		group["free"] = 1
		folded[station] = group
		out.append(group)
	return out


## Every player on a manifest, and how many are somebody other than `me`.
static func others(manifest: Array) -> int:
	var count: int = 0
	for craft in manifest:
		for seat in (craft as Dictionary)["seats"]:
			if int(seat["client"]) >= 0 and not bool(seat["you"]):
				count += 1
	return count

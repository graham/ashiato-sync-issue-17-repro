extends RefCounted
class_name AirPicture
## EVERY CRAFT IN THE SKY, AND WHETHER A PERSON IS FLYING IT: the whole air picture an operator
## watching a plot has to read, in the same row shape the crew map already draws.
##
## WHY IT EXISTS. `LevelMap.markers` lists CREWED craft only, because the CREW map answers "where can I
## sit with somebody" and the hundred and forty machines flying themselves are not an answer to that
## (`ui/menus/crew_manifest.gd`). An operator directing traffic is asking the opposite question -- what is
## in the air at all, and which of it has a human in it -- so the aircraft nobody is in have to be on the
## plot, and have to be told apart at a glance from the ones that do.
##
## THE SESSION DECIDES WHO IS A PLAYER, NOT THIS FILE. A craft is manned when its own replicated `Seats`
## component holds a client id, which is what `CrewManifest.read` derives the manifest from and what the
## server alone writes. Nothing here keeps a second roster, nothing here stores a flag, and there is no
## "this one is AI" bit anywhere in the game to read -- an AI contact is simply a craft the manifest did
## not name. That is why a player who steps out of an aeroplane is a grey contact on the next tick and one
## who boards it is a coloured one, with nothing to keep in step (CLAUDE.md rule 10).
##
## AN AI CONTACT IS NAMED WITH THE CALL SIGN IT ALREADY ANSWERS TO ON THE RADIO, and that is the whole
## reason it has a name at all: a contact an operator cannot NAME is a contact they cannot direct, and the
## point of the plot is a person talking. `RadioPhrases.callsign(kind, entity)` is the authority -- it is
## what the aeroplane itself says ("Airliner 27", read "airliner two seven" by `world/radio_phrases.gd`) --
## so the words on the plot and the words in the headset are the same words, because they are one function
## and not two (CLAUDE.md rule 4). A tag typed here instead would be a second roster of names, and the day
## it drifted an operator would be calling an aeroplane something nobody in the air answers to.
##
## WHAT IT IS NOT IS REPLICATED. The call sign comes off a hash of the entity id, and entity ids are
## per-world (`ui/menus/crew_manifest.gd`: "client ids mean the same on every machine and entity ids do
## not"), so TWO operators on two machines would read two different numbers on the same aeroplane. That is
## already true of the radio and is not made worse here; with one operator's plot it costs nothing, because
## the pilot being directed cannot see the label anyway and is being turned by voice. A replicated call
## sign is a real feature and it is the one to build before a second operator seat exists.
##
## NEVER `Net.name_of`. It answers "PLAYER 7" for anybody not in the roster, so an AI contact handed its
## client id of -1 comes back labelled "PLAYER -1" and coloured `PlayerColours.at(-1, -1)` -- a machine
## wearing a player's name and a player's colour, which is the exact lie this file exists to prevent
## (team-lead, 2026-09-17). `tests/air_picture.gd` holds it.
##
## THE GREY IS NOT IN THE PALETTE, AND IS HELD AWAY FROM IT. `PlayerColours.PALETTE` is the eight colours
## a player may wear, and an AI contact must never be able to borrow one -- that is the single easiest way
## for a plot to lie about who is a person. "Not the same colour" is not enough, and looking at the first
## drawn picture is what showed it: the palette's eighth colour is `b0bec5`, a pale blue-grey, and a
## neutral AI grey sat a whisker from it. So `tests/air_picture.gd` holds the grey a stated distance
## from every one of the eight, and the nearest is written down below.
##
## WHICH IS ALSO WHY COLOUR IS ONLY ONE OF FOUR CHANNELS. A player in `b0bec5` and a machine in this grey
## are two greys; what still tells them apart across a room is that the player is SOLID, half again as
## big, and carries their name, while the machine is an open outline with no name on it until it is
## picked. Any one channel can be argued with. Four at once cannot. See `ui/menus/map_canvas.gd`.

## What every AI contact is drawn in: one neutral steel grey. The nearest colour a player can wear is
## `PlayerColours.PALETTE`'s `b0bec5`, 0.27 away in RGB; `AI_APART` is the floor that keeps it there.
const AI := Color("8a949c")
## How far the AI grey must stay from every colour in the players' palette, as an RGB distance. 0.25,
## which is under the 0.27 the drawn picture has and well over the nothing that "not equal" allows: a
## grey that crept to within a few units of `b0bec5` would pass an equality test and be unreadable.
const AI_APART: float = 0.25


## How far the AI grey is from the nearest colour a player may wear. Asked of the palette rather than
## typed beside it, so a ninth colour added to the palette moves this number and the suite that holds it.
static func nearest_player_colour() -> float:
	var nearest: float = INF
	# EVERY COLOUR A PLAYER CAN WEAR: the palette, and the fallback of every client id, which a player past the first to
	# choose a colour wears since the session went to sixty-four (`Net.colour_of`, lane/seats 2026-09-18).
	var wearable: Array = PlayerColours.PALETTE.duplicate()
	for client in range(1, 255):
		wearable.append(PlayerColours.fallback(client))
	for colour in wearable:
		var apart := Vector3(AI.r - (colour as Color).r, AI.g - (colour as Color).g,
			AI.b - (colour as Color).b).length()
		nearest = minf(nearest, apart)
	return nearest

## KINDS THAT ARE NOT CONTACTS. A tower is a building and a segway is a person standing up; neither is
## traffic, and both would sit on the plot for the whole session saying nothing. Everything else that
## flies, drives or floats is on it, because an operator's picture is of the whole exercise and a launch
## in the way of a landing matters as much as an aeroplane.
const NOT_TRAFFIC: Array[int] = [Sim.Kind.TOWER, Sim.Kind.SEGWAY]


## THE WHOLE PICTURE: the manifest's crewed craft, then every other craft in `states`, in that order, so a
## drawing that paints the list in order puts the people on top of the traffic.
##
## `manifest` is `CrewManifest.read(...)` and `states` is `Sim.current`. Rows are `LevelMap.markers`'s,
## plus `manned` and `contact`:
##   {"contact": id on THIS machine's plot, "client": client id or -1, "vehicle": entity, "kind": Sim.Kind,
##    "position": Vector3, "heading": radians, "yours": bool, "name": String, "colour": Color,
##    "distance": metres from your own craft or -1, "manned": bool}
static func contacts(manifest: Array, states: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var crewed: Dictionary = {}
	for row in LevelMap.markers(manifest, states):
		crewed[int(row["vehicle"])] = true
		out.append(row)
	# WHERE YOU ARE, off the manifest's own row rather than worked out again, so a range on the plot is
	# the range the crew page would print.
	var here: Variant = null
	for row in out:
		if bool(row.get("yours", false)):
			here = row["position"]
	for entity_any in states:
		var entity := int(entity_any)
		if crewed.has(entity):
			continue
		var state := states[entity_any] as Dictionary
		if not (state.get("position") is Vector3):
			continue
		var kind := int(state.get("kind", -1))
		if kind < 0 or kind in NOT_TRAFFIC:
			continue
		var nose := Vector3.FORWARD
		if state.get("basis") is Quaternion:
			nose = (state["basis"] as Quaternion) * Vector3.FORWARD
		var at := state["position"] as Vector3
		out.append({
			# NEGATIVE, so a contact id can never collide with a client id on the same plot. It is this
			# machine's own handle for a marker and travels nowhere: entity ids are per-world.
			"contact": -entity, "client": -1, "vehicle": entity, "kind": kind,
			"position": at, "heading": atan2(nose.x, -nose.z), "yours": false,
			"name": callsign_of(kind, entity), "colour": AI, "manned": false,
			"distance": (at.distance_to(here as Vector3)) if here is Vector3 else -1.0})
	return out


## WHAT A CONTACT NOBODY IS IN IS CALLED, in the small grey caps the plot draws it in: the craft's own radio
## call sign, upper-cased. Asked of `RadioPhrases`, never worked out here, so the plot and the radio cannot
## disagree about which aeroplane is which.
static func callsign_of(kind: int, entity: int) -> String:
	return RadioPhrases.callsign(kind, entity).to_upper()


## How many of each are in a picture: {"players": n, "ai": n}. The plot prints it, because a count is the
## fastest thing on a board to read and the one an operator checks first.
static func tally(rows: Array[Dictionary]) -> Dictionary:
	var players: int = 0
	for row in rows:
		if bool(row.get("manned", true)):
			players += 1
	return {"players": players, "ai": rows.size() - players}

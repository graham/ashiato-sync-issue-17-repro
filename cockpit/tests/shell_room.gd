extends Node
## Headless: IS THE STRUCTURE A STATION DRAWS ACTUALLY INSIDE THE AIRCRAFT IT IS DRAWN IN?
##
##   Godot --headless --path cockpit res://tests/shell_room.tscn
##
## NOTHING IN THIS PROJECT MEASURED THE STATION AND THE AIRFRAME IN THE SAME FRAME, and both
## halves were green while the two disagreed by a quarter of a metre.
##
## `tests/fighter.gd` passes on an F/A-18 whose station stands four frame posts and two hoops
## straight through the canopy: the post tops are 0.22 m above the glass and 0.18 m outside
## it. `tests/fit.gd` measures every control against every other control and never looks at
## the fuselage. The Cessna's own checks pass while its station floor would draw 0.42 m below
## the cabin floor and 0.25--0.30 m outside the skin, where it is visible from OUTSIDE, under
## the aeroplane. Each suite measured its own half perfectly.
##
## THIS IS THE FAILURE `testing_godot_headless.md` NAMES AS "anchor the check outside the
## thing it is checking". A station check that works in the station's frame cannot see that
## the frame is in the wrong aeroplane, and the obvious datum -- `VehicleView._greenhouse` --
## is worse than useless here, because the greenhouse is DERIVED from
## `CockpitStation.EYE_HEIGHT` and `PILOT_HEIGHT`, the same two numbers the shell sizes
## itself from. A cabin roof written as `floor + PILOT_HEIGHT + 0.30` will always clear a
## canopy written as `PILOT_HEIGHT + 0.25`, whatever either of them does to the aeroplane.
##
## SO THE DATUM IS THE DRAWN VERTEX, and only that. The craft is built with every seat
## manned, every visible mesh outside a station is taken as a solid in its own right, and a
## point is inside the machine when a ray fired UP from it and a ray fired DOWN from it each
## cross one of those solids an odd number of times. Nothing here asks the shell, the station
## or the eye height anything: it asks where the triangles ended up. See `_holder` for why up
## and down, why both, and why the point is moved two thirds of a millimetre first -- all
## three were paid for by `lane/skyhawk` and the first version of this file had none of them.
##
## A PART ONLY DRAWN AT A DISTANCE IS NOT WHAT THE CREW ARE INSIDE. `ShipHull` draws a `Far`
## silhouette past 900 m and a `Near` model closer in, and counting the far one made a
## battleship's bridge look enclosed by a block the crew never see. Anything with a
## `visibility_range_begin` is left out for that reason.
##
## AND NOT EVERY CRAFT ENCLOSES ITS CREW. On ten of them no closed part the craft draws holds
## the pilot at all, for three different reasons: the airliner because `HullSkin` draws the
## fuselage as open plates; the F/A-18 because its canopy is a glass shell over a double-sided
## tub; and the light aeroplanes, helicopters and ground vehicles because their exteriors
## simply do not close over the cockpit. Those are named in `OPEN` with the reason, because a
## silently skipped craft is a check that can quietly become vacuous; `ENCLOSED` is written
## out station by station and compared with what the geometry says, so an airframe that starts
## or stops enclosing its crew fails here rather than going quiet.
##
## THE USER HAS RULED THAT THOSE TEN ARE BUGS TO FIX rather than facts to record, so this list
## is a work queue and not an exemption list. It shrinks as airframes are drawn properly, and
## every craft it loses becomes one this check holds.
##
## Read RESULT=, not the exit code.

## THE STATIONS THIS HOLDS, written down by hand from the drawn geometry on 2026-09-17, and
## checked against it below. "craft/seat".
const ENCLOSED: PackedStringArray = [
	"chinook/0", "chinook/1", "chinook/2", "chinook/3",
	# THE AC-130U AND THE C-130H, WHOLE, since `lane/liners`' C++ step (2026-09-19) put the pilots under the drawn eyes and
	# the gunners and the loadmaster on the cargo floor forward of the ramp's hinge. Until then the gunship's seats were the
	# old gunship's, its pilot ahead of the drawn nose and two gunners over the open ramp.
	"gunship/0", "gunship/1", "gunship/2", "gunship/3",
	"transport/0", "transport/1", "transport/2",
	"hawkeye/0", "hawkeye/1", "hawkeye/2", "hawkeye/3",
	# THE LIGHT HELICOPTER, drawn round its crew by `LightHelicopterAirframe` on 2026-09-17 (`lane/rotors`). Until then
	# it was the simulation's box with a boom stuck on, and the rear pair were not enclosed at all.
	"heli/0", "heli/1", "heli/2", "heli/3",
	# THE 747-400's FOUR (`lane/liners`, 2026-09-19): both pilots and both operators on the upper deck, since the C++ step.
	"jumbo/0", "jumbo/1", "jumbo/2", "jumbo/3",
	# THE F-4E'S TANDEM PAIR (`lane/phantom`, 2026-09-20). `PhantomAirframe` draws a closed fuselage with two
	# canopies over it, so both crew really are in a room -- this is the state the check is for, not an exemption
	# from it. It is here rather than in `OPEN` because the aeroplane encloses them; a Phantom canopy is glass over
	# a tub and the tub is drawn.
	"phantom/0", "phantom/1",
	"osprey/0", "osprey/1", "osprey/2", "osprey/3",
	"tanker/0", "tanker/1", "tanker/2", "tanker/3",
	"tower/0", "tower/1", "tower/2", "tower/3",
	# THE CARRIER'S FLAG PLOT, added 2026-09-17. Its other three stations are still open -- the
	# helm is a glazed box on an open island and the bow tub is a gun tub -- but the operator abaft
	# the bridge is inside a deckhouse the ship really draws, which is what the room was for. This
	# check is what noticed: the seat moved and the roster had not.
	"carrier/3",
	"train/0", "train/1", "train/2", "train/3",
	# THE F-14D's PILOT AND RIO, in tandem under the one canopy `TomcatAirframe` draws, on 2026-09-17 (`lane/tomcat`).
	# The RIO sits 1.65 m aft of the pilot where the canopy drops, and is the seat this list was most likely to lose.
	"tomcat/0", "tomcat/1",
	# THE F-16A's PILOT, under the bubble canopy `FalconAirframe` draws, on 2026-09-18 (`lane/falcon`). The seat is at the
	# eye the airframe derives from its canopy, so a seat that drifted in C++ fails here and in `tests/falcon.gd`.
	"falcon/0",
	# THE MH-6M'S PILOT AND COPILOT, side by side in the egg `LittleBirdAirframe` draws, on 2026-09-18 (`lane/littlebird`).
	# Its doors are OFF, so a shell's side reaches out of the doorway; what this holds is that the seat is inside.
	"littlebird/0", "littlebird/1",
	# THE AH-64D'S PILOT AND GUNNER, in tandem under the widened canopy `ApacheAirframe` draws (`lane/apache`, 2026-09-18):
	# the gunner in front and low, over the cheek bays, the pilot behind and 0.28 m higher.
	"apache/0", "apache/1",
	# THE DUO DISCUS'S TWO PILOTS, in tandem under the one bubble `SailplaneAirframe` draws (`lane/sailplane`,
	# 2026-09-19). A RECLINED crew: the eye 0.25 m under the glass and the floor they sit on lifted 0.70 m onto the pod's,
	# with the anchor under the belly by design (`CockpitShell.reclined`). Until then the glider enclosed nobody.
	"glider/0", "glider/1",
	# THE F-35B'S PILOT, under the one-piece canopy `LightningAirframe` draws (`lane/lightning`, 2026-09-19): the seat at
	# the eye the airframe puts at the helmet in the JSF side view, 0.47 m under the canopy's top.
	"lightning/0",
	# THE A-10C'S PILOT, under the bubble `WarthogAirframe` draws (`lane/warthog`, 2026-09-19): the eye 0.32 m under the
	# bubble's top at station 3.30, the seat under it, the canopy standing on a deck from the fuselage's shoulder.
	"warthog/0",
	# THE P-51D'S PILOT, under the bubble `P51Airframe` draws (lane/warbirds2, 2026-09-19): the eye 0.24 m under the
	# canopy's top at station 4.35, the seat `CockpitStation.EYE_HEIGHT` under it, and the kit's coaming closing the nose.
	"p51/0",
	# AND THE P-47D-30'S, under the bubble `P47Airframe` draws (lane/warbirds2, 2026-09-19): the eye 0.27 m under the
	# hood's top at station 4.55, just aft of its crown, and 0.24 m over the sill; the same coaming.
	"p47/0",
	"uh60/0", "uh60/1", "uh60/2", "uh60/3",
	# THE AIRLINER, a Boeing 737-800W drawn whole by `Boeing737Airframe` (`lane/liners`, 2026-09-19): one closed fuselage
	# whose flight-deck glass is its second surface. Its four C++ seats are still the old airliner's until the kind's shape
	# is changed, so today they sit in the cabin rather than on the flight deck; `tests/airliners.gd` holds the flight
	# deck's own room and both pilots' eyes inside the skin and behind the glass.
	"airliner/0", "airliner/1", "airliner/2", "airliner/3",
]

## AND THE STATIONS IT CANNOT, with why. Every one of these is a fault of the AIRFRAME or of
## the seat pose rather than of the shell -- a crew position the craft does not draw itself
## round -- and each is somebody else's to mend. Listed so that mending one shows up here as
## a failure of the line above, which is the only way this check can grow.
const OPEN: Dictionary = {
	"car": "the cabin is drawn as a body shell with no roof under the crew",
	"cessna": "the drawn 172 does not close over its pilot's head (lane/skyhawk)",
	"pirate": "a brig's helm is on an open deck",
	# THE 310R DOES CLOSE, AND ITS SEATS ARE STILL OUTSIDE IT, which is a different fault with the
	# same symptom (`lane/twin310`, 2026-09-19). `plane_shape()` puts four seat ANCHORS 0.15 m below
	# the hull's middle, and an anchor is a play space's floor rather than a seat pan -- on a
	# true-scale 310R that is 0.48 m under the cabin floor and below the drawn belly. What the
	# anchor is for lands right: `CockpitStation.EYE_HEIGHT` puts the crew's EYES 1.90 m over the
	# ground, 0.87 m over this cabin's floor and 0.25 m under its roof. Moving the anchors is a
	# native shape-table change: `todo/twin310--the-310r-is-not-modelled-as-one.md`.
	"plane": "the 310R's cabin is a closed room and the kind's four seat anchors sit 0.48 m below its floor",
	"pod": "the hover pod's shell is smaller than the station inside it",
	"prowler": "the transparent glasshouse is a faceted shell over an open presentation tub, not a closed solid",
	"tank": "the commander sits in an open hatch",
	"savoia": "Porco's cockpit is open: the tub is a pocket in the hull and over it is sky (lane/savoia)",
	"battleship": "a bridge on an open island; the near model draws no room round it",
	"boat": "an open wheelhouse",
	# THE HELM AND THE TUBS ONLY: the flag plot abaft the bridge IS enclosed and is held above, as
	# `carrier/3`. A craft named here covers every seat it does not hold by name.
	"carrier": "an open bridge on the island, and gun tubs on the deck edge",
	"gunboat": "an open console amidships",
	"cb90": "a glazed wheelhouse with open windows, as the patrol boat's, and gunners in open tubs on the after deck",
	"fireboat": "the wheelhouse is drawn as faceted boxes with glazing strips and the monitor stations stand on open deck; measured 2026-09-20, no closed part round any of the five heads (lane/fireboat)",
	"submarine": "the officer of the deck stands in the open sail",
	"fighter/0": "the canopy is a glass SHELL and the tub is double-sided; no closed part holds the pilot",
	"fighter/1": "the canopy is a glass SHELL and the tub is double-sided; no closed part holds the pilot",
	# NOT A FAULT: WHERE THE REAL AIRCRAFT PUTS THEM. An MH-6's troops ride on a bench bolted outside the fuselage, facing
	# out, feet over the skids; a rider inside the egg would be a different helicopter.
	"littlebird/2": "the MH-6's troop bench is outside the aircraft, by design",
	"littlebird/3": "the MH-6's troop bench is outside the aircraft, by design",
}

## WHAT IS ALLOWED OUT, by station, and why -- and the allowances are COUNTED IN THE PASSING
## LINE as well, because an exemption nobody sees every run is an exemption on its way to
## being a rule.
##
## None now (three when this was written), where the eleven-piece shell this replaced had 127
## pieces outside across all of them. BOTH REASONS ARE SEAT POSES RATHER THAN SHELLS, which
## is the whole point of measuring the two halves together: the shell cannot mend either, and
## each belongs to whoever owns the craft.
##
## THE CHINOOK'S RAMP GUNNER WAS EXCUSED HERE UNTIL 2026-09-17: the ramp was drawn lowered 3.5 m behind a fuselage that
## ended at his seat, so four corners of his station's floor hung in the air. `ChinookAirframe` runs the fuselage half a
## metre past the native box, over him and his gun, and hinges the ramp behind them both.
##
## THE UH-60'S DOOR GUNNERS WERE EXCUSED HERE UNTIL 2026-09-17: they sit at x 0.78 and their stations reach 1.35 m out
## at the floor, and the first UH-60 airframe was 1.18 m to the skin, so both floors and both bars stood outboard of the
## helicopter. `lane/rotors` drew the cabin 2.84 m across round them instead, and the excuse went.
## THE GUNSHIP'S SECOND AND THIRD GUNNERS WERE EXCUSED HERE on 2026-09-19, over the AC-130U's ramp in the old gunship's
## seats, until `lane/liners`' C++ step put each beside his own gun forward of it. Nothing is excused now; the entry stays
## as a place to write the next one.
const ALLOWED: Dictionary = {}

var _failures: PackedStringArray = []
## "craft/seat" -> {"head": bool, "drew": int, "out": {piece -> corners},
## "worst_<piece>": Vector3}
var _seen: Dictionary = {}
## craft -> {part -> AABB of its drawn vertices}
var _drawn: Dictionary = {}


func _check(label: String, ok: bool, detail: String) -> void:
	print("[shell_room] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	# THE STATIONS AS AUTHORED, not as this machine's player last arranged them. See
	# `CockpitStation.use_saved_layouts`, and `fit.gd`, which learnt this the hard way.
	CockpitStation.use_saved_layouts = false
	var craft: PackedStringArray = _craft_names()
	for name in craft:
		_measure(name)
	_the_craft_that_draw_a_cabin_round_their_crew_are_the_ones_written_down()
	_and_nothing_those_stations_draw_stands_outside_that_craft()
	_the_fighters_station_keeps_under_its_own_canopy()
	_and_every_craft_scene_is_either_held_or_named_open(craft)
	_finish()


func _finish() -> void:
	print("RESULT=%s%s" % ["PASS" if _failures.is_empty() else "FAIL",
		"" if _failures.is_empty() else " " + ", ".join(_failures)])
	get_tree().quit(0 if _failures.is_empty() else 1)


## ---- the four questions ----------------------------------------------------------------

## THE LIST AGAINST THE GEOMETRY. `ENCLOSED` is a roster and a roster goes stale; this is
## what says so. A craft whose airframe starts or stops closing over a crew position fails
## here, by name, with the part its head is in.
func _the_craft_that_draw_a_cabin_round_their_crew_are_the_ones_written_down() -> void:
	var wrong: PackedStringArray = []
	for key in _seen:
		var held: bool = ENCLOSED.has(String(key))
		var inside: bool = bool((_seen[key] as Dictionary)["head"])
		if held and not inside:
			wrong.append("%s is held but its craft draws nothing round the pilot's head" % key)
		elif inside and not held:
			wrong.append("%s encloses its crew now and is not held" % key)
	_check("the_craft_that_draw_a_cabin_round_their_crew_are_the_ones_written_down",
		wrong.is_empty(), "%d of %d stations enclosed, as listed" % [ENCLOSED.size(), _seen.size()]
			if wrong.is_empty() else "\n      ".join(wrong))


## THE RULE. Nothing a station draws may be drawn outside the machine it is drawn in.
func _and_nothing_those_stations_draw_stands_outside_that_craft() -> void:
	var poking: PackedStringArray = []
	var measured: int = 0
	var excused: int = 0
	for key in ENCLOSED:
		if not _seen.has(key):
			poking.append("%s has no station" % key)
			continue
		var out: Dictionary = (_seen[key] as Dictionary)["out"]
		measured += 1
		for piece in out:
			if String(ALLOWED.get(key, "")).split(",").has(String(piece)):
				excused += 1
				continue
			poking.append("%-11s %-16s %d of 8 corners outside, worst %s"
				% [key, piece, int(out[piece]), (_seen[key] as Dictionary)["worst_%s" % piece]])
	_check("and_nothing_those_stations_draw_stands_outside_that_craft", poking.is_empty(),
		"%d stations clear of their own skin, %d piece(s) excused in %d of them"
			% [measured, excused, ALLOWED.size()] if poking.is_empty()
			else "%d pieces outside across %d stations:\n      %s"
				% [poking.size(), measured, "\n      ".join(poking)])


## AND SAID IN WORDS FOR THE ONE THAT PAID FOR IT. `lane/hornet` drew the F/A-18 a canopy and
## the station's frame came straight through it. Held as a height against the canopy's own
## drawn top so the log carries the number rather than a pass.
##
## THIS IS THE ONLY CHECK THAT HOLDS THE FIGHTER, and it is deliberately not a containment
## test. `lane/hornet` re-modelled the airframe on 2026-09-17: the canopy was a `CapsuleMesh`,
## closed by construction, and is now a strip of quads between arcs with no caps and no
## bottom -- a SHELL. So no closed part holds the pilot any more and the fighter is in `OPEN`
## with the other craft whose exteriors do not close over their crew. A height against a drawn
## AABB needs no parity and still catches the thing that was actually wrong.
func _the_fighters_station_keeps_under_its_own_canopy() -> void:
	var canopy: AABB = ((_drawn.get("fighter", {}) as Dictionary).get("Canopy", AABB()) as AABB)
	var top: float = canopy.position.y + canopy.size.y
	var highest: float = -1e9
	var what: String = "nothing"
	# HOW MANY PIECES THE STATION ACTUALLY DREW, because "nothing of it is outside the canopy"
	# is also true of a station that drew nothing at all, and that is the shape of pass this
	# project has been caught by before.
	var drew: int = 0
	for seat in [0, 1]:
		var station: Dictionary = _seen.get("fighter/%d" % seat, {}) as Dictionary
		drew += int(station.get("drew", 0))
		for piece in station.get("out", {}):
			var at: Vector3 = station["worst_%s" % piece]
			if at.y > highest:
				highest = at.y
				what = "%s at seat %d" % [piece, seat]
	_check("the_fighters_station_keeps_under_its_own_canopy",
		canopy.size.y > 0.0 and drew >= 4 and highest <= top,
		"canopy top %.2f m, %d pieces drawn across the two seats and none of them outside it"
			% [top, drew] if highest <= top
			else "canopy top %.2f m, %s stands at %.2f m -- %.2f m through the glass"
				% [top, what, highest, highest - top])


## AND EVERY CRAFT IS JUDGED. A new craft scene with a station in it is either held to its
## airframe or written into `OPEN` with a reason; it cannot arrive unnoticed.
func _and_every_craft_scene_is_either_held_or_named_open(craft: PackedStringArray) -> void:
	var unjudged: PackedStringArray = []
	for key in _seen:
		var name: String = String(key).get_slice("/", 0)
		if ENCLOSED.has(String(key)) or OPEN.has(String(key)) or OPEN.has(name):
			continue
		unjudged.append(String(key))
	_check("and_every_craft_scene_is_either_held_or_named_open", unjudged.is_empty(),
		"%d craft, %d stations, all judged" % [craft.size(), _seen.size()]
			if unjudged.is_empty() else "not judged: %s" % ", ".join(unjudged))


## ---- the measurement -------------------------------------------------------------------

func _craft_names() -> PackedStringArray:
	var names: PackedStringArray = []
	var dir := DirAccess.open("res://objects/vehicles")
	if dir == null:
		return names
	for file in dir.get_files():
		if file.begins_with("craft_") and file.ends_with(".tscn"):
			names.append(file.trim_prefix("craft_").trim_suffix(".tscn"))
	names.sort()
	return names


## ONE CRAFT, BUILT WITH EVERY SEAT MANNED, and every corner of every piece of every station
## asked whether it is inside the machine.
func _measure(name: String) -> void:
	var scene := load("res://objects/vehicles/craft_%s.tscn" % name) as PackedScene
	var view := scene.instantiate() as VehicleView if scene != null else null
	if view == null:
		return
	add_child(view)
	view._show_in_editor()
	# THE CRAFT'S OWN FRAME. `_gather_body` turns the whole drawn body by
	# `VehicleCatalogue.facing`, and the airliner's is PI, so a vertex read in the body's
	# frame is a vertex read in the wrong aeroplane. Everything goes through the view.
	var into: Transform3D = view.global_transform.affine_inverse()
	var solids: Array = _solids(view, into)
	for seat in range(view.seats.size()):
		var anchor: Node3D = view.seat_anchor(seat)
		var frame: Transform3D = into * anchor.global_transform
		var shell: CockpitShell = _shell_under(anchor)
		if shell == null:
			continue
		var out: Dictionary = {}
		# HOW MANY PIECES THIS STATION DREW AT ALL, so a check cannot pass because there is
		# nothing left to measure.
		var drew: int = 0
		# ENCLOSED MEANS BOTH ENDS OF THE OCCUPANT ARE IN THE MACHINE -- the floor they sit on
		# and their head -- but NOT NECESSARILY IN THE SAME PART OF IT. Insisting on one part
		# was tried first and threw away every real cabin that is drawn as more than one
		# piece: the F/A-18's pilot has their head in the canopy and their feet in the cockpit
		# tub, and the locomotive's driver their head in the long hood and their feet on the
		# cab floor. Two parts is what a cabin looks like when it is drawn honestly.
		# AND THE FLOOR THEY SIT ON IS THE STATION'S OWN FLOOR, which is the anchor's unless the craft lifts it: a
		# RECLINED crew (`CockpitShell.reclined`, the Duo Discus) has its anchor 0.6 m under the belly by design, and
		# its floor, feet and stick inside the pod.
		var sits_on: Vector3 = frame * Vector3(0.0, shell.footwell_raise + CockpitStation.FLOOR * 0.5, 0.0) \
			if shell.reclined else frame.origin
		var record: Dictionary = {
			"head": _inside(solids, frame * Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0))
				and _inside(solids, sits_on),
		}
		for child in shell.get_children():
			if not (child is MeshInstance3D):
				continue
			var mesh := child as MeshInstance3D
			if mesh.mesh == null:
				continue
			var here: Transform3D = into * mesh.global_transform
			var box: AABB = mesh.mesh.get_aabb()
			drew += 1
			var loose: int = 0
			var worst := Vector3.ZERO
			for i in range(8):
				var at: Vector3 = here * box.get_endpoint(i)
				if _inside(solids, at):
					continue
				loose += 1
				if at.y > worst.y or loose == 1:
					worst = at
			if loose > 0:
				out[String(mesh.name)] = loose
				record["worst_%s" % mesh.name] = worst
		record["out"] = out
		record["drew"] = drew
		_seen["%s/%d" % [name, seat]] = record
	_drawn[name] = _boxes(view, into)
	view.queue_free()


## EVERY DRAWN PART OF THE CRAFT, in the craft's own frame, each one a solid in its own
## right: a point inside ANY of them is inside the machine, which is what lets a floor
## buried in the belly and a seat inside a canopy both read as inside.
##
## A STATION'S OWN MESHES ARE NOT THE MACHINE, and neither is anything that is only drawn
## from far away -- see the doc block on `ShipHull`'s `Far`.
func _solids(view: VehicleView, into: Transform3D) -> Array:
	var solids: Array = []
	for mesh in _drawn_meshes(view):
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		if faces.is_empty():
			continue
		var frame: Transform3D = into * mesh.global_transform
		var points := PackedVector3Array()
		var box := AABB()
		for i in faces.size():
			var at: Vector3 = frame * faces[i]
			points.append(at)
			box = AABB(at, Vector3.ZERO) if i == 0 else box.expand(at)
		solids.append({"faces": points, "box": box.grow(0.001)})
	return solids


## The same parts as boxes, by name, for a check that wants one of them by itself.
func _boxes(view: VehicleView, into: Transform3D) -> Dictionary:
	var boxes: Dictionary = {}
	for mesh in _drawn_meshes(view):
		var frame: Transform3D = into * mesh.global_transform
		var local: AABB = mesh.mesh.get_aabb()
		var box := AABB(frame * local.get_endpoint(0), Vector3.ZERO)
		for i in range(1, 8):
			box = box.expand(frame * local.get_endpoint(i))
		boxes[String(mesh.name)] = box
	return boxes


func _drawn_meshes(view: VehicleView) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	var stack: Array[Node] = [view]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if not (node is MeshInstance3D):
			continue
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		if mesh.visibility_range_begin > 0.0 or _in_a_station(mesh):
			continue
		# NOR IS A PILOT'S CHAIR: it stands on the anchor inside the cabin, and a station floor corner inside a chair
		# is not thereby inside the aeroplane. `tests/pilot_seat.gd` holds the chair to the skin.
		if mesh is MeshInstance3D and mesh.name == &"Chair" and mesh.get_parent() is Node3D \
				and (mesh.get_parent() as Node3D).name.begins_with("Seat"):
			continue
		found.append(mesh)
	return found


func _shell_under(anchor: Node3D) -> CockpitShell:
	var stack: Array[Node] = [anchor]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CockpitShell:
			return node as CockpitShell
		for child in node.get_children():
			stack.append(child)
	return null


func _in_a_station(node: Node) -> bool:
	var walk: Node = node
	while walk != null:
		if walk is CockpitStation:
			return true
		walk = walk.get_parent()
	return false


## HOW FAR THE SAMPLE POINT IS MOVED before a ray is fired from it, in metres.
##
## A RAY THAT PASSES EXACTLY THROUGH A VERTEX OR ALONG AN EDGE IS COUNTED ONCE OR TWICE
## DEPENDING ON ROUNDING, and both of those are certain here rather than unlikely: every
## airframe in this game is symmetric about x = 0 with a vertex there, every drawn part is
## axis-aligned, and a station's own slabs are laid out on the same axes as the fuselage they
## stand in. `lane/skyhawk` measured the cost of not doing this -- a point ON THE CENTRELINE
## in the middle of the Cessna's cabin read as 0.49 m outside its own aeroplane. The nearest
## real geometry is 0.06 m away, so moving the point by two thirds of a millimetre is asking
## about the same place.
const NUDGE: float = 0.0007


## IS THIS POINT INSIDE THE MACHINE?
func _inside(solids: Array, at: Vector3) -> bool:
	return _holder(solids, at) >= 0


## WHICH DRAWN PART IS IT INSIDE, or -1.
##
## PARITY OF A RAY, UP AND DOWN, AND BOTH HAVE TO BE ODD. Not sideways, and not a vote.
##
## `lane/skyhawk` measured why (`modelling_here.md` §6). A HORIZONTAL ray through a cabin
## crosses the door and window seams, which are drawn as inset strips -- open surfaces, so one
## boundary gives two crossings. At s 2.64, h 0.96, on the Cessna's centreline and plainly
## inside it, the four directions came back [above 3, below 1, outboard 2, inboard 2]: both
## horizontal rays called it outside, and a majority of four threw the whole cabin away. Up
## and down meet skin, wing and gear, all of them closed.
##
## REQUIRING BOTH TO BE ODD FAILS SAFE. An open surface makes a ray say "outside", so a point
## that really is outside cannot be rescued by one lucky direction; the worst this costs is a
## fault reported that was not one, and that is the direction to be wrong in for a check whose
## answers send somebody to remodel an aeroplane.
##
## EACH PART ON ITS OWN, so a point inside any one of them is inside the machine. That is what
## lets a floor buried in the belly and a head inside a canopy both read as inside -- and it
## is also why an interior lining cannot poison the answer the way it does for a gathered
## mesh: a point between the F/A-18's cockpit tub and its canopy is inside the canopy, whole,
## whatever the tub does to a ray.
##
## The AABB is a gate and not the answer: a box round a rounded fuselage says a point over the
## roof is inside it.
func _holder(solids: Array, at: Vector3) -> int:
	var from := Vector3(at.x + NUDGE, at.y, at.z + NUDGE)
	for index in range(solids.size()):
		var solid: Dictionary = solids[index]
		if not (solid["box"] as AABB).has_point(at):
			continue
		var faces: PackedVector3Array = solid["faces"]
		var above: int = 0
		var below: int = 0
		for i in range(0, faces.size() - 2, 3):
			var where: float = _crossed_at(faces[i], faces[i + 1], faces[i + 2], from)
			if is_nan(where):
				continue
			if where > from.y:
				above += 1
			elif where < from.y:
				below += 1
		if above % 2 == 1 and below % 2 == 1:
			return index
	return -1


## WHERE A VERTICAL LINE THROUGH `from` CROSSES THIS TRIANGLE, as a height, or NAN if it does
## not. Barycentric in the X/Z plane, which is the plane a vertical ray is a point in.
func _crossed_at(a: Vector3, b: Vector3, c: Vector3, from: Vector3) -> float:
	var ax: float = a.x - from.x
	var az: float = a.z - from.z
	var bx: float = b.x - from.x
	var bz: float = b.z - from.z
	var cx: float = c.x - from.x
	var cz: float = c.z - from.z
	var d1: float = bx * cz - bz * cx
	var d2: float = cx * az - cz * ax
	var d3: float = ax * bz - az * bx
	if (d1 < 0.0 or d2 < 0.0 or d3 < 0.0) and (d1 > 0.0 or d2 > 0.0 or d3 > 0.0):
		return NAN
	var sum: float = d1 + d2 + d3
	if is_zero_approx(sum):
		return NAN
	return (d1 * a.y + d2 * b.y + d3 * c.y) / sum

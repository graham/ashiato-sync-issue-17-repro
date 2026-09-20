extends RefCounted
class_name CockpitLayout
## A COCKPIT, WRITTEN DOWN: where every control in one station sits, as JSON.
##
## The output of the cockpit builder, and the input to a station that has one. A player
## opens the board, turns on BUILD, drags the levers where they want them, presses SAVE, and
## what comes out is a file like this:
##
##     {
##       "craft": "plane", "kind": 1, "seat": 0,
##       "units": "metres and degrees, in the seat's own frame; -Z is forward",
##       "controls": [
##         {"part": "ThrottleLever", "name": "Throttle", "label": "THROTTLE",
##          "channel": 0, "channel_name": "throttle", "range": 255,
##          "at": [0.19, 0.94, -0.21], "facing": [0.0, 0.0, 0.0]}
##       ]
##     }
##
## ---------------------------------------------------------------------------------
## WHY JSON AND NOT A SCENE
## ---------------------------------------------------------------------------------
##
## A station IS a scene -- see CockpitStation -- and Godot can save one of those from a
## running game. That would have been less code and would have been the wrong artefact.
##
## What comes out of the builder has to be readable by a person and by a language model,
## because the point of laying a cockpit out by hand is to get the numbers and then put them
## in the scene where the rest of the game can see them. A `.tscn` is a list of node paths
## and packed transforms; this is a list of parts and where they are, in metres, in a frame
## that is stated at the top of the file. One of those you can paste into a conversation.
##
## ---------------------------------------------------------------------------------
## WHAT A LAYOUT OWNS, AND WHAT IT MUST NOT TOUCH
## ---------------------------------------------------------------------------------
##
## ONLY THE PARTS THE BIN CAN MAKE. See ControlCatalogue: a layout governs the levers, the
## sticks, the wheels and the buttons, and nothing else in the station.
##
## That line is not tidiness, it is the difference between a layout and a bug. A gun is
## placed from the simulation's mount table because that is where the round leaves from; a
## gunner's sight hangs off the gun; the multi-function displays are fitted to seats that do
## not fly. All three arrive during `CockpitStation.fit` from facts about the CRAFT, and a
## saved file that moved them would be a file that contradicts the simulation -- quietly,
## and only for the player who saved it.

## WHERE THEY LIVE. In `user://` and not in the project, because this is what a player did
## to their own cockpit and not a change to the game. Copying one into the repository, by
## hand, having read it, is the step that makes it everybody's -- and it should stay a step.
const PLAYER_FOLDER: String = "user://cockpits"
## AND WHERE A SUITE'S LIVE, which is never the player's. `user://` is the same folder for a suite as for the game on
## the same machine, and on 2026-09-13 a full gate deleted the plane cockpit the user had saved an hour before:
## `tests/builder.gd` forgot plane seat 0 at its start and its end, as it had every gate since 2026-09-11, and nothing
## of the file survived. A run started on a scene under `tests/` keeps its cockpits here instead, and `run_all.ps1`
## fails a gate that changed anything in the player's folder.
const TEST_FOLDER: String = "user://test_cockpits"
## The folder this run reads and writes, decided once from its command line. See `folder_for`.
static var folder: String = folder_for(OS.get_cmdline_args())


## A SUITE IS A RUN STARTED ON A TEST SCENE, which is on the command line of every suite however it is started --
## `run_all`, by hand, or an agent -- and never on the game's. Asked of the arguments rather than of a flag a runner
## adds, so a suite run by hand cannot reach the player's folder either.
static func folder_for(args: PackedStringArray) -> String:
	for arg in args:
		if arg.begins_with("res://tests/") or arg.begins_with("res://marshalling/tests/"):
			return TEST_FOLDER + test_slot()
	return PLAYER_FOLDER


## WHICH OF A PARALLEL GATE'S JOB SLOTS THIS RUN IS IN, as a suffix for anything a suite writes that another suite in
## the same checkout might read: "" by hand, "_slot3" under `run_all.ps1 -Jobs`. The runner sets the variable in each
## suite's environment and every child a suite starts inherits it, so a host and its joiners agree without a flag.
##
## WHY IT EXISTS (lane/gate, 2026-09-19). One checkout has one `user://`, and until the gate ran suites side by side
## that was harmless: `builder` and `pedals` WRITE a plane's seat layout into the test folder while `fit`, `stations`
## and `smoke` READ it, so in parallel a suite could fit a cockpit another suite had rearranged a second earlier.
## `TestPorts` and `CraftPackage` take the same suffix: ports are per checkout, and `craft_peers`/`radio_peers` overlap.
const SLOT_VARIABLE: String = "COCKPIT_TEST_SLOT"


static func test_slot() -> String:
	var slot: String = OS.get_environment(SLOT_VARIABLE).strip_edges()
	return "" if slot.is_empty() or not slot.is_valid_int() else "_slot" + slot


## WHAT THE NUMBERS MEAN, written into every file.
##
## A file of bare triples is a file whose frame somebody has to guess, and the guess that
## costs a day is the sign of Z. Godot's forward is -Z and a cockpit is authored around a
## seat anchor, so both go in the file beside the numbers they describe.
const UNITS: String = "metres and degrees, in the seat's own frame; -Z is forward, +Y is up"


## THE FILE FOR ONE SEAT OF ONE CRAFT.
##
## PER SEAT AND NOT PER CRAFT, because the right-hand seat of a pair is the left one
## mirrored -- see `CockpitStation._mirror_the_layout` -- and once somebody has dragged a
## lever in one of them the two are no longer the same cockpit.
static func path_for(kind: int, seat: int) -> String:
	return "%s/%s_seat%d.json" % [folder, Sim.kind_name(kind).replace(" ", "_"), seat]


## IS THERE ONE? Asked before a station goes to the trouble of reading.
static func exists(kind: int, seat: int) -> bool:
	return kind >= 0 and seat >= 0 and FileAccess.file_exists(path_for(kind, seat))


## ---- reading -------------------------------------------------------------------------

## THE FILE, OR AN EMPTY DICTIONARY.
##
## EVERY FAILURE IS "THERE ISN'T ONE". A missing file, a file that is not JSON, a file whose
## top level is a list -- all of them mean the station builds itself the way it always did.
## A cockpit that refuses to load because somebody hand-edited a layout and dropped a comma
## is a player with no controls and nothing on screen to say why.
static func read(kind: int, seat: int) -> Dictionary:
	if not exists(kind, seat):
		return {}
	var file := FileAccess.open(path_for(kind, seat), FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		push_warning("[cockpit] %s is not a layout" % path_for(kind, seat))
		return {}
	return parsed as Dictionary


## ---- writing -------------------------------------------------------------------------

## WRITE ONE STATION DOWN. Returns the path it went to, or "" if it could not be written.
##
## The path is returned rather than printed because the player has to be TOLD: a save button
## that saves somewhere is a save button nobody trusts, and `user://` on Windows is six
## folders deep inside AppData. See `PilotRig.save_the_cockpit`, which puts it on the board.
static func write(kind: int, seat: int, station: Node3D) -> String:
	DirAccess.make_dir_recursive_absolute(folder)
	var path: String = path_for(kind, seat)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("[cockpit] could not write %s" % path)
		return ""
	file.store_string(JSON.stringify(of_station(kind, seat, station), "  "))
	file.close()
	return path


## THROW THE SAVED ONE AWAY, so the station goes back to what the scene says.
static func forget(kind: int, seat: int) -> void:
	if exists(kind, seat):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path_for(kind, seat)))


## ONE STATION AS A DICTIONARY, ready to be written or compared.
##
## Separate from `write` so the tests can look at what WOULD be saved without leaving a file
## behind in whatever `user://` the suite happens to be running against.
static func of_station(kind: int, seat: int, station: Node3D) -> Dictionary:
	var listed: Array = []
	for child in station.get_children():
		var control := child as VehicleControl
		if control == null:
			continue
		var part: StringName = ControlCatalogue.part_of(control)
		# ONLY WHAT THE BIN CAN MAKE. See the note at the top: a gun and a sight are the
		# simulation's business, and writing them down would be writing down a number that
		# the next `fit` is going to overrule anyway.
		if not ControlCatalogue.has(part):
			continue
		listed.append({
			"part": String(part),
			"name": String(control.name),
			# An identity survives a move, label change, or binding change. Older scenes had
			# no field; give them a deterministic per-seat id on first export rather than
			# making a package migration silently reshuffle every control.
			"device_id": device_id_of(control, seat),
			# WHAT IT SAYS ON ITS OWN LABEL, and nothing reads it back. It is in the file
			# for whoever opens the file: "TrimWheel at 0.30, 0.62, -0.10" is a line you
			# have to build the cockpit in your head to check, and "TRIM / NOSE UP / DOWN"
			# beside it is the line that makes the number obviously right or obviously
			# wrong.
			"label": control.label_text().replace("\n", " / "),
			# WHAT IT IS WIRED TO, and how far the channel goes.
			#
			# A lever knows: a flap gate is the flaps and could not be anything else. The
			# panel furniture does not -- a knob is a knob until you know what it turns --
			# so a layout that recorded only WHERE a knob was would load a cockpit of
			# knobs all doing the same default thing.
			"channel": control.channel,
			"channel_name": Sim.channel_name(control.channel),
			"binding": control.signal_binding if not control.signal_binding.is_empty() else (DeviceSignalRouter.binding_of(control.channel, control.channel_range) if control.channel >= 0 else {}),
			"range": control.channel_range,
			# WHOSE ITS POSITION IS: "craft", "seat" or "pilot". See `VehicleControl.scope`. In the
			# file because a knob wired to a channel is only half a description -- the other half is
			# whether turning it asks the aircraft or only moves the knob in front of you.
			"scope": scope_word(control.scope),
			"at": _triple(control.position),
			"facing": _triple(Vector3(rad_to_deg(control.rotation.x),
				rad_to_deg(control.rotation.y), rad_to_deg(control.rotation.z))),
		})
	return {
		"craft": Sim.kind_name(kind) if kind >= 0 else "bench",
		"kind": kind,
		"seat": seat,
		"units": UNITS,
		"controls": listed,
	}


static func device_id_of(control: VehicleControl, seat: int) -> String:
	if not control.device_id.strip_edges().is_empty():
		return control.device_id
	return "seat%d/%s" % [seat, String(control.name)]


## THREE NUMBERS, ROUNDED TO THE MILLIMETRE.
##
## A hand-dragged position is good to a few millimetres at best, and the full float prints
## as 0.30000001192092896 -- which is seventeen digits of noise in a file whose whole job is
## to be read. Rounded here, on the way out, so the file says what the player meant.
static func _triple(at: Vector3) -> Array:
	return [snappedf(at.x, 0.001), snappedf(at.y, 0.001), snappedf(at.z, 0.001)]


## A SCOPE AS THE WORD THE FILE CARRIES. Words and not the enum's numbers, because this file is for a person to read,
## and "2" beside a knob says nothing.
const SCOPE_WORDS: Dictionary = {
	VehicleControl.Scope.CRAFT: "craft",
	VehicleControl.Scope.SEAT: "seat",
	VehicleControl.Scope.PILOT: "pilot",
}


static func scope_word(scope: int) -> String:
	return String(SCOPE_WORDS.get(scope, "unsaid"))


## THE SCOPE A FILE'S WORD NAMES, or `fallback` -- which every caller passes explicitly -- when it names none.
## An absent word is quiet (a layout from before scopes); a present word that is not a scope warns, because a
## hand-edited "craf" is a knob that would otherwise silently keep a scope nobody chose.
static func scope_from(word: Variant, fallback: int) -> int:
	if word == null:
		return fallback
	for scope in SCOPE_WORDS:
		if String(SCOPE_WORDS[scope]) == String(word):
			return int(scope)
	push_warning("[cockpit] \"%s\" is not a scope; the part keeps %s" % [word, scope_word(fallback)])
	return fallback


static func _vector(from: Variant) -> Vector3:
	var list: Array = from as Array if from is Array else []
	if list.size() < 3:
		return Vector3.ZERO
	return Vector3(float(list[0]), float(list[1]), float(list[2]))


## ---- putting one back --------------------------------------------------------------

## LAY A STATION OUT THE WAY THE FILE SAYS.
##
## THE FILE WINS OUTRIGHT over every part the bin can make: anything the layout does not
## mention is removed, anything it mentions that is missing is built, and everything it
## mentions is moved to where it says. A save that could only ADD would be a builder in
## which deleting a lever is impossible, and the first thing anybody does after adding a
## second throttle by accident is try to delete it.
##
## EVERYTHING ELSE IS LEFT ALONE -- the gun, the sight, the displays, the crew board. See
## the note at the top of this file.
##
## Returns how many controls the station ended up with, which is what the tests read.
static func apply(saved: Dictionary, station: Node3D, seat: int,
		allowed: Array[StringName] = [], kind: int = -1) -> int:
	if kind < 0:
		kind = int(saved.get("kind", -1))
	if allowed.is_empty() and kind >= 0:
		allowed = VehicleCatalogue.allowed(kind)
	var wanted: Array = saved.get("controls", []) as Array
	var keep: Dictionary = {}
	for entry in wanted:
		keep[String((entry as Dictionary).get("name", ""))] = true
	# GONE FIRST, so a layout that reuses a name for a different part gets a clean one
	# rather than a lever with the wrong script and the right position.
	for child in station.get_children():
		var control := child as VehicleControl
		if control == null:
			continue
		if not ControlCatalogue.has(ControlCatalogue.part_of(control)):
			continue
		if not keep.has(String(control.name)):
			station.remove_child(control)
			control.queue_free()
	var built: int = 0
	for entry in wanted:
		var one: Dictionary = entry as Dictionary
		var part := StringName(one.get("part", ""))
		if not ControlCatalogue.has(part):
			# A LAYOUT WRITTEN BEFORE A RENAME. One lever missing and the rest of the
			# cockpit intact is a cockpit somebody can fly home and fix; a load that fails
			# outright is a seat with nothing in it.
			push_warning("[cockpit] no part called %s" % part)
			continue
		if not allowed.is_empty() and not allowed.has(part):
			push_warning("[cockpit] %s is not allowed on %s; skipped" % [part,
				Sim.kind_name(kind) if kind >= 0 else "this craft"])
			continue
		var channel := int(one.get("channel", -1))
		# NOT ASKED OF A SIGNAL LAMP, which speaks on its own seat's channel whatever the file says (below), fitted to every
		# kind by `Sim.start` and so absent from a craft built before any world was.
		if kind >= 0 and channel >= 0 and part != &"SignalLamp" and not CraftPackage._has_channel(kind, channel):
			push_warning("[cockpit] %s uses an unfitted channel on %s; skipped" % [part, Sim.kind_name(kind)])
			continue
		var name: String = String(one.get("name", String(part)))
		# ONE LAMP TO A SEAT, under the name every machine finds it by (`SignalLamp.in_station`). A second one would be a
		# second lens on the same channel, and nobody's builder makes one.
		if part == &"SignalLamp" and name != SignalLamp.NODE_NAME:
			push_warning("[cockpit] a second signal lamp (%s) at seat %d; skipped, one to a seat" % [name, seat])
			continue
		var control := station.get_node_or_null(name) as VehicleControl
		if control != null and ControlCatalogue.part_of(control) != part:
			station.remove_child(control)
			control.queue_free()
			control = null
		if control == null:
			control = ControlCatalogue.make(part)
			control.name = name
			station.add_child(control)
			control.setup(seat)
		control.device_id = String(one.get("device_id", "seat%d/%s" % [seat, name]))
		# WIRED FIRST, because a control's own `_build` may have set a range from the number
		# of stops it has and the file's is the one the player chose.
		if one.has("channel"):
			control.channel = int(one["channel"])
		if one.has("range"):
			control.channel_range = maxi(int(one["range"]), 1)
		var saved_binding := one.get("binding", {}) as Dictionary
		control.signal_binding = saved_binding if not saved_binding.is_empty() else (DeviceSignalRouter.binding_of(control.channel, control.channel_range) if control.channel >= 0 else {})
		# AND WHOSE IT IS, with the part's OWN scope as the default at this call site: a file written
		# before scopes existed says nothing, and nothing means "what this part is", never "the bottom
		# of the enum". A word that is not a scope is said, and the part keeps its own.
		control.scope = scope_from(one.get("scope"), control.scope) as VehicleControl.Scope
		control.position = _vector(one.get("at"))
		var facing: Vector3 = _vector(one.get("facing"))
		control.rotation = Vector3(deg_to_rad(facing.x), deg_to_rad(facing.y),
			deg_to_rad(facing.z))
		# A SIGNAL LAMP SPEAKS ON ITS OWN SEAT'S CHANNEL, whatever the file says: that number is worked out from the
		# library's channel count (`SignalLamp.channel_for`), and a file written against another count, or copied from
		# another seat, would put this seat's flashes on somebody else's lamp. Where the file puts it is its holster.
		if control is SignalLamp:
			control.channel = SignalLamp.channel_for(seat)
			control.channel_range = SignalLamp.RANGE
			control.signal_binding = DeviceSignalRouter.binding_of(control.channel, control.channel_range)
			(control as SignalLamp).holster_here()
		built += 1
	return built

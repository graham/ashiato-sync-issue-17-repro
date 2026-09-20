extends Node
## EVERY CRAFT IN THE GAME IS ONE OBJECT: every drawn part touches the rest. Read RESULT= rather
## than the exit code.
##
## ---------------------------------------------------------------------------------
## WHAT THIS IS FOR, IN ONE SENTENCE
## ---------------------------------------------------------------------------------
##
## **A bounding box, a triangle budget, a feature roster and a three-view all describe a SET of
## parts. Not one of them asks whether the set is a single object.** On 2026-09-17 the water bomber
## was a fuselage with eighteen of its twenty-one parts floating in the air round it, and every
## suite was green: `aircraft_fidelity` held it to a published 9.02 m height and the drawn model
## measured 9.00, because the fin's TOP had been placed at the height that satisfies the contract
## and its BOTTOM had never been joined to anything.
##
## That check was written in `aircraft_fidelity` and covered seven aircraft. This is it for every
## kind -- ships, ground vehicles, structures and the rest -- because nothing about the fault is
## aircraft-specific and a destroyer's gunhouse can float off its deck exactly as a fin can float
## off a tailcone. The algorithm is `DrawnParts.adrift`, written once; see that file for why it is
## not the same check as `buildings_gallery_shot._nothing_floats`, which shares the algorithm.
##
## ---------------------------------------------------------------------------------
## WHAT IT DOES NOT FIND
## ---------------------------------------------------------------------------------
##
## **It finds OPEN AIR. It does not find missing structure.** A Chinook's rear rotor stands on a
## fuselage with no aft pylon between them -- a fault a person sees at once -- and all twenty-four
## of its parts touch, so this passes it. That is not a gap in this check; it is the boundary of
## what a connectivity test can mean. `lane/audit` drew the line and this suite's own first
## known-failures list crossed it, by listing the Chinook on the strength of a visual report.

## THE CRAFT WHOSE DRAWN PARTS DO NOT ALL TOUCH, measured, with what is adrift and by how much.
##
## THIS LIST MAY ONLY SHRINK, AND IT CANNOT ROT: a craft on it that turns out to be joined is an
## error, so the entry has to be deleted in the commit that fixes the craft. The same property has
## already caught one wrong entry -- the Chinook, above.
##
## A RATCHET RATHER THAN A RED LINE because these belong to other lanes, and a gate that is red for a
## fault the lane in front of it cannot fix teaches everybody that a red line is normal.
##
## EVERY ENTRY IS MEASURED, AND NAMES WHAT A PERSON WOULD SEE. The worst gap is typed so the entry
## can be checked against the run, and the phrase says what is actually floating -- because the next
## lane to open one of these aeroplanes wants to know what it is looking for, not that a number was
## exceeded. They are GEOMETRY faults, not naming ones: each fix is a decision about that aircraft's
## shape (does the airliner's engine get a pylon, and how long?) and belongs with whoever next models
## it, which is why this list exists rather than nine guessed airframes.
##
## None of these has an owner today.
##
## THE TRAIN CAME OFF, the way the tank came off `named_parts`: this suite went red on its own,
## naming the stale entry -- "delete these entries: train" -- when `lane/train` rebuilt the
## locomotive. Its fault was the OLD hood unit's, "the front windows 0.11 m off the cab they are
## glazing". The F7A cab unit has no separate cab: its windscreen sits on the carbody's own front
## face, a centimetre proud only so the two faces do not fight, and the fix was a consequence of
## drawing the right locomotive rather than of chasing this gap.
## AND THE AIRLINER, THE MERCURY AND THE GUNSHIP, 2026-09-19: `lane/liners` drew them as a Boeing 737-800W, a 747-400
## and an AC-130U (`JetlinerAirframe`), whose pylons carry their engines, whose winglets are lofted from the wing tips and
## whose wheels are on their legs, and this suite named each stale entry.
## AND THE LIGHT TWIN CAME OFF THIS LIST, 2026-09-19: `lane/twin310` drew it as a Cessna 310R
## (`Cessna310Airframe`), whose spinners are on its nacelles' cowl faces and whose blades are on its
## spinners, and this suite named the stale entry the way it named the train's and the airliner's.
## Its fault was the blockout's: a propeller placed at a fraction of the collision box rather than on
## the engine it belongs to, so six of twenty-three parts flew in formation with the aeroplane.
const DETACHED: Dictionary = {
	"pirate": "four gunports 0.10 to 0.11 m proud of the hull they are cut into -- 4 of 32 parts",
}

var _failures: PackedStringArray = []


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL the native library is not loaded")
		get_tree().quit(1)
		return
	var in_pieces: Dictionary = {}
	var whole: PackedStringArray = []
	var measured: int = 0
	for kind in range(Sim.Kind.size()):
		var label: String = Sim.kind_name(kind)
		var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene) \
			.instantiate() as VehicleView
		add_child(view)
		# FROM OUTSIDE, THE WAY A PLAYER SEES THE CRAFT -- `setup`, as `aircraft_fidelity` builds it.
		# NOT `_show_body(true)`, which is the GHOSTED view from INSIDE the craft and hides airframe:
		# the first run of this suite built the Chinook that way and got ten parts led by a gun
		# mount, and `named_parts` had been measuring the same partial craft since it was written.
		view.setup(0, kind)
		var parts: int = DrawnParts.count(view)
		var stray: Array = DrawnParts.adrift(view)
		measured += parts
		if stray.is_empty():
			whole.append("%s (%d)" % [label, parts])
		else:
			in_pieces[label] = {"parts": parts, "stray": stray}
		# FREED NOW, NOT QUEUED: twenty-five craft and then a quit, and `queue_free` defers to a
		# frame that never comes -- `named_parts` leaked twenty-five RIDs that way on its first run.
		remove_child(view)
		view.free()
	_report(in_pieces, whole, measured)
	print("RESULT=PASS" if _failures.is_empty() else "RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _report(in_pieces: Dictionary, whole: PackedStringArray, measured: int) -> void:
	var surprises: PackedStringArray = []
	for craft in in_pieces:
		if DETACHED.has(craft):
			continue
		var row: Dictionary = in_pieces[craft]
		var said: PackedStringArray = []
		for stray in (row["stray"] as Array):
			said.append("%s %.2f m from %s" % [stray["name"], stray["gap"], stray["nearest"]])
		surprises.append("%s: %d of %d parts adrift -- %s" % [craft, (row["stray"] as Array).size(),
			row["parts"], "; ".join(said)])
	_check("every_craft_in_the_game_is_one_object_and_not_a_set_of_parts", surprises.is_empty(),
		"%d craft whole over %d drawn parts; %d on the known list"
			% [whole.size(), measured, DETACHED.size()]
			if surprises.is_empty() else " | ".join(surprises))
	var healed: PackedStringArray = []
	for craft in DETACHED:
		if not in_pieces.has(craft):
			healed.append("%s (%s)" % [craft, DETACHED[craft]])
	# A CRAFT ON THE LIST THAT IS WHOLE IS AN ERROR, which is what makes this a ratchet and not an
	# exemption: the entry goes in the commit that fixes the craft.
	_check("and_no_craft_on_the_known_list_has_been_joined_up_without_it_being_taken_off",
		healed.is_empty(),
		"all %d still in pieces" % DETACHED.size() if healed.is_empty()
			else "delete these entries: %s" % ", ".join(healed))
	for craft in in_pieces:
		if DETACHED.has(craft):
			var worst: Dictionary = ((in_pieces[craft] as Dictionary)["stray"] as Array)[0]
			print("[joined_parts] KNOWN %s (%s): worst %s %.2f m from %s" % [craft, DETACHED[craft],
				worst["name"], worst["gap"], worst["nearest"]])


func _check(label: String, okay: bool, detail: String) -> void:
	print("[joined_parts] %s %s (%s)" % ["PASS" if okay else "FAIL", label, detail])
	if not okay:
		_failures.append(label)

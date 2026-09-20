extends Node
## Headless: does every cockpit in the game fit a pair of hands?
##
##   Godot --headless --path cockpit res://tests/fit.tscn
##
## ONE RULE, AND IT IS ABOUT GRABBING RATHER THAN ABOUT TIDINESS.
##
## A hand takes hold of whatever is within `REACH` of its grip, so two controls closer than
## TWICE that share a place a hand can be: from a point midway between them a hand is in
## range of both, and which one it gets comes down to `_nearest_to` and a fraction of a
## millimetre. In a headset that is a gunner who reaches for the trigger and takes hold of
## the crew button, at fifty feet, over a fire.
##
## THE RULE WAS ALREADY WRITTEN DOWN IN THREE PLACES AND ENFORCED IN NONE OF THEM, which is
## why this suite exists. Each of the three measured a set that was missing the very things
## most likely to collide:
##
##   `smoke` instantiated the SEAT SCENE at each seat pose and measured `controls()` on it.
##   A station built that way has never been `fit`, so the gun is not on it -- and a powered
##   mount's trigger, which is fitted rather than authored, was the closest pair in the game.
##
##   Nothing built the CONSOLE at all. The flap gate, the gear lever and the drop handle
##   hang off the VEHICLE rather than off any seat, they are spliced into every seat's set,
##   and no layout check had ever seen one.
##
##   `water` and `shots` each measured ONE control against the rest of ONE craft.
##
## So this builds the whole craft -- hull, every station, the console, and the guns -- for
## every kind in the game, and measures every grip against every other grip in it. Thirty-
## eight pairs were inside the rule the first time it was run, across eleven craft.
##
## Read RESULT=, not the exit code.

## Every craft scene, by the name in its filename. Not `Sim.Kind`, because what is being
## measured is the SCENE: a kind with no cockpit scene has nothing to crowd.
const CRAFT: PackedStringArray = ["airliner", "battleship", "boat", "carrier", "car",
	"cessna", "chinook", "glider", "gunboat", "gunship", "hawkeye", "heli", "osprey", "plane", "pod",
	"submarine", "tanker", "tank", "tower", "train"]

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[fit] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	# THE COCKPITS AS AUTHORED, not as this machine's player last arranged them: a layout saved in `user://cockpits`
	# is theirs, and it failed this suite for four pairs of their own placing (2026-09-13). See
	# `CockpitStation.use_saved_layouts`.
	CockpitStation.use_saved_layouts = false
	var seen: int = 0
	var grips: int = 0
	var crowded: PackedStringArray = []
	for name in CRAFT:
		var view := _craft(name)
		if view == null:
			crowded.append("%s: no scene" % name)
			continue
		seen += 1
		var here: Array = _grips_in(view)
		grips += here.size()
		crowded.append_array(_too_close(name, here))
		view.queue_free()
	_check("every_craft_builds_a_cockpit", seen == CRAFT.size() and grips > 60,
		"%d craft, %d grips between them" % [seen, grips])
	# THE WHOLE LIST, not the first four. A layout pass is a list of numbers to move, and a
	# report that stops at four turns one pass into four.
	_check("no_two_grips_in_a_craft_are_within_one_hand_of_each_other", crowded.is_empty(),
		"all clear" if crowded.is_empty() else "%d pairs:\n      %s"
			% [crowded.size(), "\n      ".join(crowded)])
	_and_a_hand_is_offered_every_one_of_them()
	_and_every_gun_has_a_finger_that_fires_it()
	_and_every_one_of_them_is_within_reach()
	_and_every_one_of_them_says_what_it_is()
	_finish()


## AND EVERY ONE OF THOSE GRIPS IS ONE A HAND IS ACTUALLY OFFERED.
##
## Spacing is only half of it. A control can be perfectly placed, perfectly visible, and
## still be something no hand in a headset can take hold of -- because what a hand is
## offered is `PilotRig._reachable`, and that is built somewhere else entirely.
##
## It was built from a WRITTEN LIST of roles: throttle, stick, button, extra, flaps, gear,
## drop. The gunner's trigger was added to the game after that list and never added to it,
## so on every powered mount in the game a gunner could traverse onto a target and not be
## able to shoot. The desktop hid it, because a keyboard has no hands and asks the gun
## directly.
##
## So this is the check that the two sets are the SAME set: everything a craft hands out
## under a role is something the rig will offer to a hand. The list is gone -- `grabbable_in`
## walks the set it is given -- and this is what says it stays gone.
func _and_a_hand_is_offered_every_one_of_them() -> void:
	var missed: PackedStringArray = []
	var offered: int = 0
	for name in CRAFT:
		var view := _craft(name)
		if view == null:
			continue
		for seat in range(4):
			var set: Dictionary = view.controls_for(seat)
			if set.is_empty():
				continue
			var offered_here: Dictionary = PilotRig.grabbable_in([set])
			for role in set:
				if not (set[role] is VehicleControl):
					continue
				var node: VehicleControl = set[role]
				offered += 1
				if not offered_here.has(node):
					missed.append("%s seat %d: %s (%s)" % [name, seat, node.name, role])
		view.queue_free()
	_check("and_a_hand_is_offered_every_one_of_them", missed.is_empty(),
		"all %d" % offered if missed.is_empty()
			else "%d never offered: %s" % [missed.size(), ", ".join(missed)])


## ONE CRAFT, BUILT AS IT IS FLOWN. `_show_in_editor` is the whole cockpit -- every station
## at its seat pose, the console, the guns -- which is the only state in which this question
## has an answer. A craft with nobody in it has no controls to crowd.
## ---- and does the gun this seat works have a finger on it ---------------------------

## EVERY SEAT THAT WORKS A FITTED GUN HAS SOMETHING UNDER A FINGER THAT FIRES IT -- and nothing
## under that finger is doing a different job instead.
##
## ASKED ABOUT ON 2026-09-15: "the cannons in planes that are controlled by joysticks don't seem to
## work." The wire and the simulation were ruled out first (`tests/gun_link.gd`: a client at the
## gunship's joystick gun station traverses to the stop and fires 28 to 30 rounds a second over
## links of 0 to 16 ticks), and so was the rig (`tests/gunners.gd`, a hand on the joystick and a
## hand on the grip). What was left was the BINDING, and there is a real way for it to go wrong:
## `FlightStick.missile_bindings` OVERWRITES `Bind.TRIGGER` with the launch on a stick whose
## `launch_on_trigger` is set, and a gunner pulling a trigger that has been rebound to fire a
## missile gets no cannon and would report exactly that.
##
## It does not happen today, and the second check below is why: `CockpitStation._fit_the_missiles`
## sets `launch_on_trigger` false at any seat whose own mount carries a fitted gun. Measured over all
## twenty craft: thirteen gun seats, every one of them with FIRE on both its stick and its grip, and
## no seat with its trigger taken away.
##
## THE PREDICTION THAT THIS BRANCH WOULD RUN FOR THE FIGHTER WAS WRONG, and it is corrected here
## because it was carried forward as a rule ("item 4 lands on a check that is already waiting").
## The fighter's minigun (plan item 4, 2026-09-16) is NOT a turret mount -- a mount belongs to a
## turret seat, and a seat with one is fitted a gunner's sight and a console trigger and loses its
## throttle -- so `launch_on_trigger` stays true there. It is a STATION on the weapon selector, and
## the trigger carries the launch AND the pull, with the server deciding which acts by the selected
## station. Moving the launch to the lower thumb would also have taken the station stepping off the
## stick, so a pilot in a headset could not have chosen guns at all. The walk below therefore also
## visits every launch seat of a craft whose selector carries a gun, and wants `Bind.fire()` on its
## trigger with the launch still beside it.
##
## STATIC, off the built cockpit and the simulation's own gun table, so it costs a scene and no
## flight -- and `Bind.fire()` is compared against rather than re-described, because a check with
## its own idea of what firing looks like is a check that goes stale when the binding changes.
func _and_every_gun_has_a_finger_that_fires_it() -> void:
	var fires: String = str(Bind.fire())
	var mute: PackedStringArray = []
	var stolen: PackedStringArray = []
	var armed: int = 0
	for name in CRAFT:
		var view := _craft(name)
		if view == null:
			continue
		for seat in range(4):
			var mount: int = Sim.mount_of_seat(view.kind, seat)
			if mount < 0 or not bool(Sim.gun_of(view.kind, mount).get("fitted", false)):
				continue
			armed += 1
			var set: Dictionary = view.controls_for(seat)
			var found: PackedStringArray = []
			for role in set:
				var control := set[role] as VehicleControl
				if control != null and str(control.bindings().get(Bind.TRIGGER, {})) == fires:
					found.append(String(role))
			if found.is_empty():
				mute.append("%s seat %d works mount %d and nothing fires it" % [name, seat, mount])
			# AND THE ONE WAY IT COULD BE TAKEN AWAY, said as its own sentence so that a red line
			# names the mechanism rather than the symptom.
			var stick := set.get("stick") as FlightStick
			if stick != null and stick.launches and stick.launch_on_trigger:
				stolen.append("%s seat %d: the stick launches on the trigger and the seat has a gun"
					% [name, seat])
		# AND A SEAT THAT FLIES A CRAFT WITH A GUN ON ITS WEAPON SELECTOR -- the fighter's minigun, plan item 4, which is
		# no turret seat's mount and so is not in the walk above. The guns lane expected this to arrive as a MOUNT, with
		# the launch moved to the lower thumb; it arrived as a STATION, with the trigger carrying both, because the other
		# way takes the station stepping off the stick. So the finger that must fire it is the trigger, and the rule is
		# the same one: `Bind.fire()` is on it, whatever else is.
		var schema: Dictionary = Sim.missile_schema(view.kind)
		var guns: bool = false
		for entry in (schema.get("stations", []) as Array):
			guns = guns or bool((entry as Dictionary).get("gun", false))
		for seat in (schema.get("launch_seats", []) as Array) if guns else []:
			armed += 1
			var stick := view.controls_for(int(seat)).get("stick") as FlightStick
			var on_trigger: Variant = stick.bindings().get(Bind.TRIGGER, {}) if stick != null else {}
			var has_fire: bool = on_trigger is Array
			for action in Bind.fire():
				has_fire = has_fire and (on_trigger as Array).has(action)
			if not has_fire:
				mute.append("%s seat %d selects a gun and its trigger says '%s'" % [name, int(seat), Bind.says(on_trigger)])
			if stick != null and not stick.launch_on_trigger:
				stolen.append("%s seat %d: the launch left the trigger, and the thumb no longer walks the stations"
					% [name, int(seat)])
		view.queue_free()
	_check("every_seat_that_works_a_gun_has_a_finger_that_fires_it",
		mute.is_empty() and armed > 0,
		"%d gun seats, all armed" % armed if mute.is_empty()
			else "%d of %d silent: %s" % [mute.size(), armed, ", ".join(mute)])
	_check("and_nothing_has_taken_that_finger_for_the_missiles", stolen.is_empty(),
		"no seat both launches on the trigger and works a gun" if stolen.is_empty()
			else ", ".join(stolen))


## ---- and can the person in the seat actually GET to them ----------------------------

## WHERE A SEATED SHOULDER IS AND HOW FAR A SEATED ARM GOES: `CockpitStation`'s, since the builder's landing spot asks
## them too. See `CockpitStation.EASY_REACH` for why an easy reach and a lean.
const EASY: float = CockpitStation.EASY_REACH
const LEAN: float = CockpitStation.LEAN_REACH


## EVERY CONTROL, FROM THE SEAT IT IS IN FRONT OF.
##
## The other half of a layout, and the half nothing measured. `_too_close` says two controls
## do not share a place a hand can be; this says a hand can get to them at all. A cockpit can
## pass that one and still put the throttle where only a long arm and a lean will reach it,
## which is what "there are controls too far away from the operator" means from inside one.
##
## MEASURED TO THE NEARER SHOULDER, which is the whole point of doing it per hand: a lever
## on the left is a left-handed lever, and measuring it from the middle of the chest reports
## a stretch that nobody actually has to make.
func _and_every_one_of_them_is_within_reach() -> void:
	var far: PackedStringArray = []
	var measured: int = 0
	var worst: float = 0.0
	for name in CRAFT:
		var view := _craft(name)
		if view == null:
			continue
		for seat in range(4):
			var anchor: Node3D = view.seat_anchor(seat)
			var set: Dictionary = view.controls_for(seat)
			if anchor == null or set.is_empty():
				continue
			for role in set:
				if not (set[role] is VehicleControl):
					continue
				var node: VehicleControl = set[role]
				# NOT A HAND'S BUSINESS. Pedals are on the floor, well over a metre from a shoulder, and no hand works
				# them -- they show the rudder. Still measured against every grip above, since a builder's hand does
				# pick them up.
				if node.under_foot():
					continue
				var at: Vector3 = anchor.to_local(node.grip_global())
				var reach: float = _from_a_shoulder(at)
				measured += 1
				worst = maxf(worst, reach)
				if reach > EASY:
					far.append("%-9s seat %d  %-18s %.2f m%s" % [name, seat,
						"%s/%s" % [node.name, role], reach,
						"  BEYOND AN ARM" if reach > LEAN else "  a lean"])
		view.queue_free()
	_check("every_control_is_within_a_seated_arm", far.is_empty(),
		"all %d, worst %.2f m" % [measured, worst] if far.is_empty()
			else "%d of %d past %.2f m:\n      %s"
				% [far.size(), measured, EASY, "\n      ".join(far)])


## AND EVERY ONE OF THEM CAN SAY WHAT IT IS.
##
## A cockpit is a dozen controls that all look like levers, and which one is the gear is not
## something a shape can say. The labels are what a player turns on while they are learning
## an aircraft -- see `PilotRig.name_the_controls` -- and a control that came up blank, or
## that only repeated its own category, would be the one they most needed named.
##
## THE TEXT AND NOT THE NODE. `show_label` builds a Label3D on first use, and building
## thirty of them here to read a string back off would be measuring Godot rather than the
## cockpit.
func _and_every_one_of_them_says_what_it_is() -> void:
	var mute: PackedStringArray = []
	var said: int = 0
	var seen: Dictionary = {}
	for name in CRAFT:
		var view := _craft(name)
		if view == null:
			continue
		for seat in range(4):
			for role in view.controls_for(seat):
				var node := view.controls_for(seat)[role] as VehicleControl
				if node == null or seen.has(node):
					continue
				seen[node] = true
				said += 1
				var text: String = node.label_text()
				if text.strip_edges().is_empty():
					mute.append("%s: %s says nothing" % [name, node.name])
				elif text == "CONTROL":
					# The base class default, which means `_build` never named it.
					mute.append("%s: %s is still called CONTROL" % [name, node.name])
		view.queue_free()
	_check("and_every_one_of_them_says_what_it_is", mute.is_empty(),
		"all %d" % said if mute.is_empty() else "%s" % ["
      ".join(mute)])


## Shoulder to grip, taking whichever shoulder is nearer.
func _from_a_shoulder(at: Vector3) -> float:
	return CockpitStation.from_a_shoulder(at)


func _craft(name: String) -> VehicleView:
	var scene := load("res://objects/vehicles/craft_%s.tscn" % name) as PackedScene
	if scene == null:
		return null
	var view := scene.instantiate() as VehicleView
	if view == null:
		return null
	add_child(view)
	view._show_in_editor()
	return view


## EVERY GRIP IN A CRAFT, ONCE, as [what it is called, where a hand has to be].
##
## Walked over all four seats and de-duplicated by NODE, because a console control is the
## same node in every seat's set -- that is what makes both pilots' hands land on the one
## handle -- and a control cannot crowd itself.
##
## Anything in the set that is not a control is skipped: a RudderIndicator is a display, and
## nothing grabs a display.
func _grips_in(view: VehicleView) -> Array:
	var found: Array = []
	var already: Dictionary = {}
	for seat in range(4):
		var set: Dictionary = view.controls_for(seat)
		for role in set:
			if not (set[role] is VehicleControl):
				continue
			var node: VehicleControl = set[role]
			if node.taken_by() == Bind.Take.NONE:
				continue
			if already.has(node):
				continue
			already[node] = true
			found.append(["%s/%s" % [node.name, role], node.grip_global()])
	return found


func _too_close(name: String, grips: Array) -> PackedStringArray:
	var crowded: PackedStringArray = []
	for i in range(grips.size()):
		for j in range(i + 1, grips.size()):
			var apart: float = (grips[i][1] as Vector3).distance_to(grips[j][1] as Vector3)
			if apart < VehicleControl.REACH * 2.0:
				crowded.append("%-10s %-22s %-22s %.3f m" % [name, grips[i][0],
					grips[j][0], apart])
	return crowded


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit()

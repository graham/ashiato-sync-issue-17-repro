@tool
extends Node3D
class_name CockpitStation
## ONE CREW POSITION, as a scene: the controls in front of one seat and the structure round
## them.
##
## Everything in here is authored in the editor rather than built in code, which is the
## point of it being a scene. A control is a node with a script and a transform -- the
## meshes are built at runtime by the control itself -- so a station is half a dozen nodes
## and moving a lever is dragging it in the viewport.
##
## THERE IS ONE OF THESE PER OCCUPIED SEAT AND NOT ONE PER SEAT. A hundred and forty
## machines with four seats each is five hundred and sixty sets of controls, of which at
## most a handful are in front of anybody: the rest were built at startup, parented into the
## world and drawn for ever. `VehicleView` now instantiates a station when somebody sits
## down and frees it when they get up.
##
## Parented to the SEAT ANCHOR, so everything in it is in seat-local space and the maths in
## `VehicleControl` stays subtraction between two children of the same node -- which is what
## makes a grab at 300 kph the same arithmetic as a grab on the ground.

## A 1.6 m PILOT'S EYES, SEATED: about where they are with the play space floor under a
## chair rather than under a pair of boots.
##
## HERE AND NOT ON PilotRig, and that is not tidying. A station scene needs this to know
## where to put a lever; PilotRig needs VehicleView to say what a player is sitting in; and
## VehicleView loads the station scenes. Reading it off the rig closed that ring, and a
## `preload` is resolved at parse time, so the ring was a hard one -- every station scene
## failed to load with "Busy", which is what Godot says when a resource is already partway
## through loading itself.
##
## A cockpit constant belongs with the cockpit. Now the arrow only points one way: the rig
## reads this, and nothing here reads the rig.
##
## Seated and not standing, which is the difference between a cockpit and a lectern. It
## went up to a standing 1.49 while the controls were being sorted out and everything
## authored against it went with it, so the deck ended up at chest height on somebody on
## their feet and over the head of the same person in a chair.
##
## LOWER THAN A TAPE MEASURE WOULD SAY. This number is not a fact about people, it is where
## the game ASSUMES the eyes are, and what it really sets is how far the deck sits below
## whatever height the headset is actually reporting. Every 30 cm taken off here brings the
## whole deck 30 cm nearer the hands of the person in the chair.
##
## THIS IS THE ONE HEAD HEIGHT IN THE GAME. Every level goes through it: `PilotRig` places
## the play-space origin so the eyes land here above whatever the player is sitting in, in
## a headset and on the desktop camera alike, so there is nothing per-level to keep in step.
##
## MOVING IT IS TWO EDITS, NOT ONE, and the second is the one that gets forgotten. The
## station scenes bake their control heights in metres rather than reading `hands()`, so
## raising the head raises nothing else: the pilot ends up reaching further down for the
## same deck, which is the wrong direction and is what a run of this straight away showed.
## Every node in `objects/seats/seat_*.tscn` has to move by the same amount in Y.
##
## `the_deck_is_authored_at_the_current_hand_height` in the smoke suite is the reminder. It
## goes red when the two drift apart and prints the correction to apply, in metres.
##
## What that buys is the part that CANNOT be kept in step by hand: a level with furniture.
## The desk in the main menu is built in plain metres and does not follow, so the head
## really does rise relative to it -- at 1.00 the eyes sat 26 cm over a 74 cm desk, which is
## a child at the dinner table, and this is the only number that fixes that.
const EYE_HEIGHT: float = 1.35

## WHERE A PILOT'S HANDS ARE, relative to their eyes. Every station scene is authored
## against these, so moving them moves every cockpit in the game together.
##
## FORTY CENTIMETRES BELOW THE EYES and an arm's length forward: a seated pilot looking
## down and slightly out at their hands, which is what a cockpit is.
##
## This and EYE_HEIGHT moved together on purpose. Raising the eye height alone raises the
## deck with it and the player does not move relative to their controls at all -- the two
## numbers are a head and a deck, and it is the GAP between them that anybody feels. Fifteen
## centimetres went onto both, so the head came up and the deck stayed exactly where it
## was, which is why none of the station scenes needed rebuilding.
##
## Both directions are load-bearing. The console sits under the controls, so the further
## DOWN they go the more of the windscreen it takes; the further UP, the sooner it crosses
## the eyeline and there is no cockpit left to see out of. Ten centimetres was the standing
## answer and put the whole deck half a metre too high for somebody sitting.
const HANDS_BELOW_EYES: float = 0.41
const HANDS_FORWARD: float = 0.34
## A throttle is worked with a hand lower than the one on the stick, and its knob stands
## 3 cm proud of the rail.
const THROTTLE_DROP: float = 0.11

## HOW TALL THE OCCUPANT IS, in metres, and therefore how much room the structure has to
## leave. A cockpit is a box you have to see out of: nothing solid may stand between the
## eyes and the horizon, so the console sits below them, the rails at elbow height, and the
## frame posts out at the corners.
const PILOT_HEIGHT: float = 1.6

## HOW THICK THE FLOOR IS, and so where its top stands above the seat anchor. `CockpitShell` lays a floor this thick and
## `_fit_the_pedals` stands the pedals on it, so the two are one number.
const FLOOR: float = 0.04
## HOW FAR AHEAD OF THE FLYING CONTROL'S BASE THE PEDALS STAND, in metres.
##
## SHORT, SO THE PILOT CAN SEE THEM PAST THE CONSOLE. It was 0.30, a shin's rake ahead of the stick, and the first picture
## from the pilot's eye (tests/pedal_shot.tscn, 2026-09-13) showed no pedals at all: the console slab, 0.815 m up and
## running back to 0.25 m ahead of the eye, hides everything on the floor further forward than about 0.535 m, and the
## pedals stood at 0.64. At 0.12 they stand at 0.46 and the forward pedal at full deflection at 0.54, all of it in sight.
## A real footwell is under the panel and out of view; the point of these is to be looked at.
##
## THE SLAB THAT HID THEM IS GONE (2026-09-17): `CockpitShell` no longer draws a console, so
## nothing of the station's own is in front of the pedals at all. The number stays where the
## measurement put it -- short is still where a pilot can see their own feet, and moving it
## back out would have to be argued from a picture rather than from this paragraph.
const FOOTWELL: float = 0.12
## AND FOR A RECLINED CREW (`CockpitShell.reclined`), whose legs lie forward along the pod: the pedals stand this far
## ahead of the column's base. Measured 2026-09-19 (`tests/fit.gd`): on the Duo Discus's floor, lifted 0.70 m, pedals
## `FOOTWELL` ahead of the stick came within 0.156 m of its grip -- a hand could not tell the two apart. At 0.34 they
## are a hand's width and more from it, where a reclined pilot's feet are.
const RECLINED_FOOTWELL: float = 0.34

## Where the hands are, above the seat anchor -- which is the play space FLOOR and not the
## seat pan, because the tracker adds the eye height on top of it.
static func hands() -> float:
	return EYE_HEIGHT - HANDS_BELOW_EYES


## WHERE A SEATED SHOULDER IS, in the seat anchor's own frame. The anchor is the play space FLOOR -- the tracker adds the
## sitting height on top of it -- so the eyes are at `EYE_HEIGHT` and the shoulders a neck below that. Half a shoulder
## width apart, because which arm is reaching is most of the answer for anything out to one side: the tank's throttle is
## 34 cm to the LEFT, which is nothing for a left hand and a stretch across the body for a right one.
##
## HERE AND NOT IN tests/fit.gd, where they were written first (moved 2026-09-14): the builder lands a part it adds where a
## seated hand gets to it, so the rig asks the same numbers the fit suite measures every cockpit against.
const NECK: float = 0.22
const SHOULDER_HALF: float = 0.19

## HOW FAR A SEATED ARM GOES, in metres, shoulder to grip.
##
## `SignalZones.NOMINAL_REACH` is 0.78 and that is an arm held straight out by somebody STANDING UP. Sitting, with your
## back against a seat and a harness over your shoulders, the arm is the same length and the shoulder no longer travels:
## what you can reach without coming out of the seat is the shorter number, and what you can reach by leaning is the
## longer one.
##
## EASY is the bar this game should meet. A control you have to lean for is one you stop using in a headset, because
## leaning moves your head and the horizon with it.
const EASY_REACH: float = 0.60
const LEAN_REACH: float = 0.75


## Shoulder to `at`, in the seat anchor's frame, taking whichever shoulder is nearer.
static func from_a_shoulder(at: Vector3) -> float:
	var shoulder := Vector3(SHOULDER_HALF, EYE_HEIGHT - NECK, 0.0)
	return minf(at.distance_to(shoulder), at.distance_to(Vector3(-shoulder.x, shoulder.y, shoulder.z)))


## WHERE A SEATED PILOT'S KNEES ARE, as a box in the seat anchor's frame: a place nothing is put. An adult of
## `PILOT_HEIGHT` sitting upright has knees about half a metre off the floor, a hand's breadth under the stick's base
## (every station mounts it at 0.72), and between a third and two thirds of a metre ahead of the eyes, 25 cm either side
## of the centre line. Written for the builder's landing spot on 2026-09-14; nothing measured a knee before.
const KNEES := AABB(Vector3(-0.25, 0.40, -0.66), Vector3(0.50, 0.30, 0.34))


## Every control in this station, by the job it does. A station without one of them -- a
## locomotive has no steering, a light aeroplane has no nacelles -- simply does not have
## that child, and everything downstream copes with a null rather than assuming a set.
## The second control has a different NAME in every cockpit -- a yoke, a wheel, a cyclic, a
## brake handle -- because a node called "Stick" on a locomotive is a lie to whoever opens
## the scene. They are looked up in order and the first one present wins.
const STICK_NAMES: Array[String] = ["Stick", "Yoke", "Wheel", "Brake"]


func _stick() -> VehicleControl:
	for name in STICK_NAMES:
		var found := get_node_or_null(name) as VehicleControl
		if found != null:
			return found
	return null


func controls() -> Dictionary:
	var out: Dictionary = _the_authored_set()
	# AND ANYTHING THE PLAYER PUT HERE THEMSELVES.
	#
	# The set above is the seven jobs a station scene is authored around, and for twenty
	# years of cockpits that was the whole of it. The builder can add a second throttle, a
	# trim wheel to an aeroplane that never had one, or four buttons -- see CockpitLayout --
	# and a control that is in the tree but not in this dictionary is a control no hand can
	# reach: `PilotRig` builds everything it knows about from these sets.
	#
	# KEYED BY NODE NAME, which is unique among siblings and is therefore the one key that
	# cannot collide. The key is a ROLE everywhere else, and for these the role genuinely is
	# "the thing called Throttle2" -- there is nothing else it could be.
	for child in get_children():
		var extra := child as VehicleControl
		if extra == null or out.values().has(extra):
			continue
		out[String(extra.name).to_lower()] = extra
		# AND ANYTHING THAT PART BROUGHT WITH IT. A director's camera has a keypad bolted to its back
		# -- a control on a control, and therefore a grandchild of this station, which the loop above
		# would never see. A part ANNOUNCES what it carries (`VehicleControl.carries`) rather than
		# this going hunting at any depth, because the station has no business knowing what a camera
		# is, and a hunt would also drag in whatever a future part keeps deliberately out of reach.
		#
		# NAMED UNDER ITS CARRIER, so two cameras in one cockpit do not both offer a "keys".
		for carried in extra.carries():
			if carried != null and not out.values().has(carried):
				out["%s/%s" % [String(extra.name).to_lower(),
					String(carried.name).to_lower()]] = carried
	return out


func _the_authored_set() -> Dictionary:
	return {
		"throttle": get_node_or_null("Throttle") as VehicleControl,
		"stick": _stick(),
		"button": get_node_or_null("Button") as CrewButton,
		"rudder": get_node_or_null("Rudder") as RudderIndicator,
		"extra": get_node_or_null("Extra") as VehicleControl,
		# Fitted rather than authored -- see _fit_the_gun -- and null on every craft that
		# does not have a gun in front of this seat, which is nearly all of them.
		"trigger": _trigger(),
		# Fitted rather than authored, like the gun -- see `_fit_the_trim_wheel` -- and null
		# on every craft whose bus has no trim channel.
		"trim": get_node_or_null("Trim") as VehicleControl,
	}


## WHAT FIRES THE GUN AT THIS SEAT, if anything does.
##
## A powered mount has a grip on the console beside the joystick that lays it. A gun swung
## by hand has its trigger between its own spade grips, because that is where a hand
## already is -- so on those the gun IS the trigger, and there is no second thing to reach
## for. Nothing downstream cares which: the rig wants one control that fires, and the
## keyboard, which has no hands to hold anything with, wants it just as much.
func _trigger() -> VehicleControl:
	var grip := get_node_or_null("Trigger") as VehicleControl
	if grip != null:
		return grip
	return _stick() as PintleGun


## WHICH SEAT THIS IS, so anything that finds a station in the tree can say where it is
## without being told separately. -1 until it is fitted.
var seat: int = -1
## The package/scene this loose station was fitted for. A station in a VehicleView can ask
## its parent; a builder bench cannot, and still needs the craft allowlist.
var craft_kind: int = -1
## AND WHICH WAY IT FACES, in radians about the vertical, from the simulation's seat table.
##
## Everything in a station is in seat-local space and never needs this -- that is the whole
## point of hanging it off the seat anchor. The one exception is a gun, whose angles are
## replicated in the CRAFT's frame because that is the frame the round is fired in: turning
## them back into this station's frame is the difference between the two, and this is it.
var seat_yaw: float = 0.0
## WHAT MISSILES THIS SEAT CAN LAUNCH, off `Sim.missile_schema`, kept from `_fit_the_missiles` so a frame's lock
## display does not ask the simulation for the table again. Empty at a seat that launches nothing.
var _missile_schema: Dictionary = {}
## Each missile type's seeker cone, asked once.
var _cones: Dictionary = {}
## The mounts' angles as the wire last handed them to `aim_the_gun`, for `sight_bearing`.
var _aimed: Array = []


## Hand this station to a seat.
##
## It no longer says whose station it is. Whose hands may move these controls is not a
## property of the station at all: anybody aboard may work anything they can reach, and
## the rig decides that by distance. See PilotRig._reachable.
func fit(index: int, flies: bool = true, kind: int = -1, mirrored: bool = false) -> void:
	craft_kind = kind
	seat = index
	var pose: Dictionary = _seat_pose(kind, index)
	var operator_station := String(pose.get("station", "")) == "operator"
	# A CRAFT WHOSE WALL STANDS BESIDE THE SEAT (`"screens_inboard"` in its catalogue entry) moves the flight display in to
	# 0.16 m on the inboard side, before the mirror: the scene's -0.02 put its outboard edge 0.08 m past the 310R's lining.
	var display := get_node_or_null("Display") as Node3D
	if display != null and kind >= 0 and bool(VehicleCatalogue.of(kind).get("screens_inboard", false)):
		display.position.x = 0.16
	seat_yaw = float(pose.get("yaw", 0.0))
	# THE CREW BOARD WHERE CrewBoard SAYS, before anything reads its side or the mirror
	# reflects it: no seat scene types its own transform for it (2026-09-18).
	var board := get_node_or_null("Crew") as CrewBoard
	if board != null:
		board.transform = CrewBoard.placement(EYE_HEIGHT)
	# THE STICK IS SWAPPED BEFORE ANYTHING IS SET UP, because `controls()` is what the loop
	# below walks and a gunner's station must already have the right one in it by then.
	if kind >= 0:
		# A CRAFT THAT NAMES ITS OWN FOOTWELL gets it (`CockpitShell.fit_footwell`); every other keeps the standard one.
		var shell := get_node_or_null("Shell") as CockpitShell
		if shell != null:
			shell.fit_footwell(VehicleCatalogue.of(kind).get("footwell", {}) as Dictionary)
		_fit_the_gunners_stick(index, kind)
		if operator_station:
			_fit_the_operator_controls(kind)
		_fit_the_stow_switch(index, kind, operator_station)
		_fit_the_sweep_handle(kind)
	for control in controls().values():
		var node := control as VehicleControl
		if node != null:
			node.setup(index)
	if not flies:
		_fit_the_mfds()
	else:
		_fit_the_map_screen()
		_fit_the_tank_gauge(kind)
	if kind >= 0:
		_fit_the_gun(index, kind)
		if not operator_station:
			_fit_the_trim_wheel(kind)
			_fit_the_trim_to_the_column(kind, flies)
		_fit_the_missiles(index, kind)
		if not operator_station:
			_fit_the_pedals(index, kind, flies)
	# AND THE RIGHT-HAND SEAT OF A PAIR IS THE LEFT ONE, REFLECTED.
	#
	# LAST, after everything that adds anything: the gun, the sight, the gunner's stick and
	# the two displays are all FITTED rather than authored, and a mirror applied before them
	# would reflect the scene and leave whatever arrived afterwards on the original side.
	if mirrored:
		_mirror_the_layout()
	# AND LAST OF ALL, WHATEVER THE PLAYER SAVED.
	#
	# After the mirror and after everything that fits itself, because a layout is a record
	# of where the controls ENDED UP in front of this seat -- somebody dragged them there
	# and looked at them. Applying it earlier would hand those positions to a mirror that
	# would then reflect them into the other half of the cockpit.
	#
	# THE PARTS BIN ONLY. The gun, the sight and the displays that arrived above are the
	# simulation's and are left exactly where they were put. See CockpitLayout.
	_fit_the_saved_layout(kind, index)


## RESTORE THE RUNTIME-ONLY FACTS on a station whose complete visible structure came from
## an immutable package. Positions and membership stay JSON-owned; mount indices and
## missile behavior stay simulation-owned because they participate in commands.
func configure_authored(index: int, kind: int) -> void:
	seat = index
	craft_kind = kind
	var pose: Dictionary = _seat_pose(kind, index)
	seat_yaw = float(pose.get("yaw", 0.0))
	if bool(pose.get("flies", false)):
		_fit_the_map_screen()
		_fit_the_tank_gauge(kind)
	# These values change how the authored column's fingers behave and therefore remain
	# simulation facts even though the column's shape and position came from JSON.
	_fit_the_trim_to_the_column(kind, bool(pose.get("flies", false)))
	var mount := Sim.mount_of_seat(kind, index)
	var gun := Sim.gun_of(kind, mount) if mount >= 0 else {}
	var swivel := _stick() as PintleGun
	if swivel != null and not gun.is_empty():
		swivel.mount = mount
		swivel.fit_the_mount(gun)
		if _sight() == null:
			var carried := GunSight.new()
			carried.name = "Sight"
			carried.mount = mount
			carried.stands_at = Vector3(0.0, 0.19, 0.06)
			swivel.fit_sight(carried)
	var sight := _sight()
	if sight != null:
		sight.mount = mount
	var ranging := _range_sight()
	if ranging != null:
		ranging.mount = mount
		ranging.gun = gun
	# A HELMET SIGHT FROM A PACKAGE is only its place: the mount it shows, and what the simulation says that gun is,
	# are simulation facts, filled here as the range sight's are (lane/apache).
	var helmet := _helmet_sight()
	if helmet != null:
		helmet.mount = mount
		helmet.gun = gun
	var lock := _lock_sight()
	if lock != null and _fit_the_repeater(index, kind):
		lock = null
	if lock != null:
		_missile_schema = Sim.missile_schema(kind)
		lock.helmet = _locks_by_the_helmet(_missile_schema)
		var stick := _stick() as FlightStick
		if stick != null:
			stick.launches = true
			stick.launch_on_trigger = mount < 0 or not bool(gun.get("fitted", false))
			stick.missile_stations = missile_stations()
			stick.fires_a_gun = fires_a_gun()
		_arm_the_wheel()
	ready.connect(_configure_authored_displays, CONNECT_ONE_SHOT)
	setup_controls(index)


func _configure_authored_displays() -> void:
	for screen in find_children("*", "CraftDisplay", true, false):
		var page := (screen as CraftDisplay).shown() as MfdPage
		if page != null:
			page.right_hand_side = (screen as Node3D).position.x > 0.0


func setup_controls(index: int) -> void:
	for control in controls().values():
		var node := control as VehicleControl
		if node != null:
			node.setup(index)


## WHETHER A FITTED STATION TAKES THE PLAYER'S SAVED LAYOUT. On in the game, always. A suite that measures the cockpits
## AS AUTHORED turns it off before it builds one, because `user://cockpits` is the player's and is not the repository's:
## on 2026-09-13 the user saved a plane cockpit while playing, and `fit` failed the next gate on four pairs of controls
## the player had put side by side. Suites that test saving and loading leave it on and manage their own files.
static var use_saved_layouts: bool = true


## THE COCKPIT THIS PLAYER BUILT, if they built one. See CockpitLayout, and `PilotRig`
## which is where the dragging and the saving happen.
func _fit_the_saved_layout(kind: int, index: int) -> void:
	if not use_saved_layouts or not CockpitLayout.exists(kind, index):
		return
	CockpitLayout.apply(CockpitLayout.read(kind, index), self, index)
	# THE NEW ONES HAVE NEVER BEEN SET UP. `apply` calls `setup` on anything it builds, but
	# a control that was already in the scene and has only been MOVED was set up in the loop
	# above, and one that a layout renamed arrives here built and unfitted. Cheap, and
	# idempotent: `setup` builds meshes once and redraws.
	for control in controls().values():
		var node := control as VehicleControl
		if node != null:
			node.setup(index)


## A JOYSTICK FOR A SEAT THAT TRAVERSES A GUN, in place of whatever that station flies with.
##
## One station scene serves every seat in a craft, so a gunship's three gun positions were
## handed the flight deck's YOKE -- a two-handed wheel on a column, which is what you fly an
## airliner with and nothing like what you lay a gun with. The same is true of any craft
## whose pilots use a yoke or a wheel and whose back seats shoot.
##
## Fitted per seat for exactly the reason the sight and the trigger below are: which seats
## have guns is a fact about the CRAFT, not about the station scene, and only the simulation
## knows it.
##
## THE OLD ONE IS FREED RATHER THAN HIDDEN. `_stick` returns the first of its names that is
## present, so a hidden yoke left in the tree would still be the control the rig reads, and
## the gunner would traverse an invisible wheel.
## A GENERIC MISSION OPERATOR HAS SYSTEM CONTROLS, not a decorative flight yoke whose
## input the server correctly refuses. This role is deliberately generic: the two selectors
## exercise the authoritative craft bus without claiming a real aircraft's restricted panel.
## WHAT COUNTS AS A FLIGHT CONTROL IS `STICK_NAMES`, NOT A LIST TYPED HERE. This read
## `["Yoke", "Stick", "Trim", "Rudder"]`, and `STICK_NAMES` has held "Wheel" and "Brake" as well
## for as long as there have been ships: the carrier's seat scene is `seat_wheel.tscn` and its
## flying control is called "Wheel", so the first operator ever seated on a ship would have sat at
## the helm (lane/awacs, 2026-09-17). `Station::Operator` means `flies()` is false and the server
## refuses the input, which is what makes it WORSE and not better -- a wheel that turns in your
## hands and steers nothing is the cockpit lying about what it can do. Two lists that had to agree,
## one of them typed (CLAUDE.md rule 4); now there is one, and `tests/plot_room.gd` asks
## `STICK_NAMES` rather than spelling the names again, so the check cannot inherit the same bug.
##
## AND THE THROTTLE, since 2026-09-17. The F-14's radar intercept officer has no flight controls, and neither does any
## operator: the server refuses a throttle from a seat that does not fly exactly as it refuses a stick, so a throttle
## left at an operator's elbow was the helm wheel again -- a lever that moves in your hand and does nothing. The
## F/A-18F's back seat carried one until then.
const OPERATOR_STRIPS: Array[String] = ["Throttle", "Trim", "Rudder"]


## THE WING SWEEP HANDLE, AT EVERY SEAT OF A CRAFT WHOSE BUS HAS `Sim.Channel.SWEEP`, flying or not.
##
## EVERY SEAT, because the user asked that both crew of the F-14 can sweep the wings (2026-09-17), and the simulation
## takes the channel from any seat: it is not on the physical half the server refuses to a seat that does not fly. So the
## RIO's operator station gets one too, and it is live -- unlike a throttle or a stick there, which the server would
## refuse. Fitted by channel, not by kind, as the display knob is: a craft that grows the channel grows the handle.
##
## ON THE LEFT CONSOLE, AFT OF THE THROTTLE, where the real one sits beside the throttles. 0.39 m from the throttle's grip
## and 0.33 from the cabin light's, clear of `VehicleControl.REACH * 2`, the 0.32 m `tests/fit.gd` holds grips apart by.
func _fit_the_sweep_handle(kind: int) -> void:
	if not _has_channel(kind, Sim.Channel.SWEEP) or get_node_or_null("SweepHandle") != null:
		return
	var handle := SweepHandle.new()
	handle.name = "SweepHandle"
	handle.position = Vector3(-0.36, 0.78, 0.05)
	add_child(handle)


func _fit_the_operator_controls(kind: int) -> void:
	for named in STICK_NAMES + OPERATOR_STRIPS:
		var old := get_node_or_null(named)
		if old != null:
			remove_child(old)
			old.queue_free()
	if _has_channel(kind, Sim.Channel.DISPLAY) and get_node_or_null("DisplaySelector") == null:
		var pages := RotaryKnob.new()
		pages.name = "DisplaySelector"
		# CLEAR OF WHAT THE SEAT ALREADY HAS -- AND OF EACH OTHER -- BY MORE THAN
		# `VehicleControl.REACH * 2`, the 0.32 m `tests/fit.gd` refuses to let two grips sit inside.
		# At the old (-0.19, 0.78, -0.31) this knob was 0.162 m from `seat_wheel`'s Throttle: it had
		# never been fitted to a seat that owns one. The first move cleared the throttle and put the
		# two knobs 0.289 m from EACH OTHER, which `tests/plot_room.gd` caught and `fit.gd` did not,
		# because fit walks `controls_for` over a seat somebody is in and no suite sits at this one.
		#
		# THEY ARE NOW FORE AND AFT ALONG THE RIGHT-HAND CONSOLE, 0.384 m apart, which is a console
		# with two knobs on it rather than two knobs at the same spot. The throttle owns the left
		# side of this seat, so both go to the right; the spread is across AND along, because a pure
		# sideways split needs 0.32 m of beam and puts the outboard one at the edge of a 1.05 m
		# shell. The knobs moved; the tolerance did not, and the suite reads it off
		# `VehicleControl.REACH` rather than repeating the number.
		pages.position = Vector3(0.24, 0.80, -0.46)
		pages.channel = Sim.Channel.DISPLAY
		pages.channel_range = 5
		add_child(pages)
	if _has_channel(kind, Sim.Channel.MODE) and get_node_or_null("ModeSelector") == null:
		var mode := RotaryKnob.new()
		mode.name = "ModeSelector"
		mode.position = Vector3(0.48, 0.80, -0.16)
		mode.channel = Sim.Channel.MODE
		mode.channel_range = 3
		add_child(mode)


## THE GUNSHIP'S GUNS STOWED, at every gunner's station: a two-position knob on the Mode channel where the craft's bus names
## it "stow guns" (lane/liners, 2026-09-19: "3 guns poking out of it that can be toggled off"). At a gunner's and not the
## pilot's, because it is the gunners' guns: any of them may run the battery in or out, and the simulation refuses a
## round from a stowed gun (`fire_round`). On the right-hand console beside the hip, 0.35 m from the trim wheel: where an
## operator's mode knob goes it was 0.27 m from it, inside one hand (`tests/fit.gd`).
func _fit_the_stow_switch(index: int, kind: int, operator_station: bool) -> void:
	if operator_station or kind < 0 or get_node_or_null("StowGuns") != null:
		return
	if Sim.mount_of_seat(kind, index) < 0 or _channel_name(kind, Sim.Channel.MODE) != "stow guns":
		return
	var stow := RotaryKnob.new()
	stow.name = "StowGuns"
	stow.position = Vector3(0.52, 0.80, 0.10)
	stow.channel = Sim.Channel.MODE
	stow.channel_range = 1
	add_child(stow)


## What the craft's bus calls `channel`, or "" where it has none.
func _channel_name(kind: int, channel: int) -> String:
	for row_any in Sim.schema_of(kind).get("channels", []) as Array:
		if int((row_any as Dictionary).get("channel", -1)) == channel:
			return String((row_any as Dictionary).get("name", ""))
	return ""


func _has_channel(kind: int, channel: int) -> bool:
	for row_any in Sim.schema_of(kind).get("channels", []) as Array:
		if int((row_any as Dictionary).get("channel", -1)) == channel:
			return true
	return false


func _fit_the_gunners_stick(index: int, kind: int) -> void:
	var mount: int = Sim.mount_of_seat(kind, index)
	if mount < 0:
		return
	var gun: Dictionary = Sim.gun_of(kind, mount)
	var flying: VehicleControl = _stick()
	# A GUN SWUNG BY HAND IS NOT LAID WITH ANYTHING. It replaces the flying control with
	# ITSELF: there is no joystick in a door gunner's station, because the thing they point
	# is the gun. See PintleGun, and `Gun::pintle` in the simulation, which is the one place
	# that says which mounts are worked this way.
	if bool(gun.get("fitted", false)) and bool(gun.get("pintle", false)):
		if flying is PintleGun:
			return
		if flying != null:
			remove_child(flying)
			flying.queue_free()
		var swivel := PintleGun.new()
		swivel.name = "Stick"
		swivel.mount = mount
		# HOW THE MOUNT MOVES: its rate and its stops, so the gun can work out for itself where
		# the mount has got to instead of waiting a round trip to be told. See PintleGun.lead,
		# and tests/gun_link.gd for what happened when it could not.
		swivel.fit_the_mount(gun)
		# WHERE THE GUN IS BOLTED TO THE AIRCRAFT, in this seat's frame. Not a number
		# chosen in here: the simulation says where the mount is because that is where the
		# round comes from, and the gun in the gunner's hands has to be that same gun -- so
		# it is the craft-frame position, put through the seat's own pose.
		swivel.position = _in_seat_space(kind, index, gun.get("at", Vector3.ZERO) as Vector3)
		add_child(swivel)
		return
	if flying is FlightStick:
		return
	if flying != null:
		remove_child(flying)
		flying.queue_free()
	var stick := FlightStick.new()
	stick.name = "Stick"
	# Where the station's own flying control stood, so a cockpit laid out around a yoke is
	# still laid out around what replaces it.
	stick.position = flying.position if flying != null \
		else Vector3(0.0, hands(), -HANDS_FORWARD)
	add_child(stick)


## ONE SEAT'S POSE, from the simulation's own table. {} for a kind or a seat it does not
## have, which is what the editor sees and what a station on a bench sees.
func _seat_pose(kind: int, index: int) -> Dictionary:
	if kind < 0 or index < 0:
		return {}
	var poses: Array = Sim.geometry_of(kind).get("seat_poses", []) as Array
	return poses[index] as Dictionary if index < poses.size() else {}


## A POINT IN THE CRAFT'S FRAME, EXPRESSED IN THIS SEAT'S.
##
## A station hangs off a seat anchor, and the anchor is the seat's pose -- so this is that
## transform, inverted. It is the only conversion between the two frames anywhere in a
## station, and it is here rather than written out at the one call site because the seat
## table is the simulation's and asking it twice is how two answers start disagreeing.
func _in_seat_space(kind: int, index: int, at: Vector3) -> Vector3:
	var pose: Dictionary = _seat_pose(kind, index)
	if pose.is_empty():
		return at
	var anchor := Transform3D(Basis(Vector3.UP, float(pose.get("yaw", 0.0))),
		pose.get("position", Vector3.ZERO) as Vector3)
	return anchor.affine_inverse() * at


## A SIGHT AND A TRIGGER, for a seat with a gun in front of it.
##
## Same reasoning as the displays below: which seats have guns is a fact about the CRAFT --
## one of a tank's three, three of a gunship's four -- and one station scene serves every
## seat in a craft. So it is fitted per seat rather than authored into the scene, and a
## craft with no guns never sees any of it.
##
## THE MOUNT IS COUNTED IN SEAT ORDER, which is the rule the simulation aims and fires by:
## turret seats take mounts in the order they are listed. A sight that showed mount 0 to
## everybody would have two of a gunship's three gunners looking at somebody else's gun.
func _fit_the_gun(index: int, kind: int) -> void:
	if _sight() != null or _range_sight() != null or _helmet_sight() != null:
		return
	# ASKED RATHER THAN COUNTED. This walked the seat poses and counted turret stations for
	# itself, which is a third copy of a rule the simulation states twice -- and it is the
	# copy that disagreed. See Sim.mount_of_seat.
	var mount: int = Sim.mount_of_seat(kind, index)
	if mount < 0:
		return
	var gun: Dictionary = Sim.gun_of(kind, mount)
	if not bool(gun.get("fitted", false)):
		return
	# A GUN THAT FOLLOWS THE GUNNER'S HEAD GETS A HELMET SIGHT, AND NOTHING ELSE CHANGES AT THE SEAT (lane/apache). The
	# AH-64's front seat also FLIES, so its collective and its flying stick stay; the stick's trigger already fires
	# (`FlightStick.column_bindings`), and `_fit_the_missiles` keeps the launch off that finger at a seat whose mount has
	# a gun. `_fit_the_trigger` below takes the throttle away, which here would be the gunner's collective.
	if bool(gun.get("helmet", false)):
		var helmet := HelmetSight.new()
		helmet.name = "HelmetSight"
		helmet.mount = mount
		helmet.gun = gun
		add_child(helmet)
		return
	# A BIG GUN GETS A RANGEKEEPER, NOT A REFLECTOR: laid by elevation for a target it must be able to see while laid.
	# See RangeSight. It takes the same trigger in the throttle's place.
	if bool(gun.get("predicted", false)):
		var ranging := RangeSight.new()
		ranging.name = "RangeSight"
		ranging.mount = mount
		ranging.gun = gun
		add_child(ranging)
		_fit_the_trigger(index)
		return
	var sight := GunSight.new()
	sight.name = "Sight"
	sight.mount = mount
	# ON THE GUN, WHEN THE GUN IS IN YOUR HANDS.
	#
	# A sight bolted to the cockpit is right for a mount that trains a few degrees: the
	# gunship's guns barely move and the glass in front of the gunner is as good as a
	# reticle on the barrel. A gun that swings ninety degrees either way is a different
	# question -- a fixed reticle would say the gun is pointing straight ahead while it is
	# pointing out of the door -- so on those the sight goes ON the gun and swings with it,
	# which is where every real one has been since somebody first fitted one.
	var swivel := _stick() as PintleGun
	if swivel != null:
		# ON THE RECEIVER, a little behind the trunnion and clear of the body: high enough
		# that the RANGE printed under the ring is above the gun rather than inside it,
		# which is where a first run of this put it, and low enough to be under the eyeline
		# of somebody sitting upright.
		sight.stands_at = Vector3(0.0, 0.19, 0.06)
		swivel.fit_sight(sight)
		_clear_the_gunners_view()
		return
	add_child(sight)
	_fit_the_trigger(index)


## THE TRIGGER A POWERED MOUNT IS FIRED WITH, in the throttle's place. See `_fit_the_gun`, and `RangeSight`'s seats, which
## take it too.
func _fit_the_trigger(index: int) -> void:
	# A TURRET SEAT HAS NO THROTTLE, and taking it away is what makes room for the trigger.
	#
	# It never did anything. A gunner has no authority over where the craft goes -- see the
	# station table -- so the lever in front of them was a dead handle, which this project
	# already says is worse than no handle at all: it reads as something you can do and then
	# does nothing when you do it. It was also in the way. Everything at a station lives in
	# a box two thirds of a metre across at hand height, and a gun station has to fit a
	# joystick, a crew button and a trigger into it beside the throttle.
	var dead := get_node_or_null("Throttle")
	if dead != null:
		remove_child(dead)
		dead.queue_free()
	var trigger := GunTrigger.new()
	trigger.name = "Trigger"
	# WHERE THE THROTTLE WAS: left of the joystick, at hand height, on the console face
	# where a hand and an eye both already are.
	#
	# It used to sit on the RIGHT, 0.22 m out and level with the stick, which put it 0.195 m
	# from the crew button and 0.245 m from the joystick -- both inside the one-hand rule,
	# so a gunner reaching for the trigger could come away with either. Two things had kept
	# that invisible, and both are now closed: the layout check built its stations with
	# `instantiate()` and never called `fit`, so no gun was ever on one; and the rig's
	# reachable set was a hand-written list of roles that did not mention "trigger", so in a
	# headset no hand could take hold of it in the first place.
	#
	# THE FIRST FIX WAS WORSE AND ONLY A PICTURE SHOWED IT. Dropping the trigger 0.27 m onto
	# the console face cleared every distance in the suite and put the grip UNDER the desk,
	# where it is 0.32 m from everything and visible from nowhere. See tests/station_shot.gd.
	trigger.position = Vector3(-0.30, hands() - 0.14, -0.32)
	trigger.setup(index)
	add_child(trigger)


## THE MISSILES, AT THE SEATS THE SIMULATION SAYS CAN LAUNCH THEM.
##
## ASKED, NOT LISTED: `missile_schema(kind).launch_seats` is the simulation's, beside the loadout it describes, for
## the reason `Sim.mount_of_seat` gives about guns -- a second copy of which seats launch is a copy that disagrees.
##
## THREE THINGS ARRIVE. A LockSight in front of the eyes. The stick learns it launches -- see
## `FlightStick.missile_bindings` -- with the trigger as the launch unless this seat's trigger already fires a gun.
## And a MASTER ARM switch, because the plane has had the channel all along and nothing in its cockpit to throw it
## with: a pilot's seat has no screens, and a launch the server refuses as "not armed" with no switch to arm is a
## dead end. On the glareshield, right of centre, above the hands and clear of everything they are on.
func _fit_the_missiles(index: int, kind: int) -> void:
	if _lock_sight() != null:
		return
	var schema: Dictionary = Sim.missile_schema(kind)
	var seats: Array = schema.get("launch_seats", []) as Array
	if _fit_the_repeater(index, kind):
		return
	if not seats.has(index) or (schema.get("stations", []) as Array).is_empty():
		return
	_missile_schema = schema
	var sight := LockSight.new()
	sight.name = "LockSight"
	sight.helmet = _locks_by_the_helmet(schema)
	add_child(sight)
	var stick := _stick() as FlightStick
	if stick != null:
		stick.launches = true
		var mount: int = Sim.mount_of_seat(kind, index)
		stick.launch_on_trigger = mount < 0 or not bool(Sim.gun_of(kind, mount).get("fitted", false))
		stick.missile_stations = missile_stations()
		stick.fires_a_gun = fires_a_gun()
	_arm_the_wheel()
	# AND THE CIRCLE WHERE THE SEEKER LOOKS: along the launcher, which on a boat's raised box is above the bow.
	sight.look_along(float(schema.get("launcher_pitch", 0.0)))
	if get_node_or_null("MasterArm") == null:
		var arm := ToggleSwitch.new()
		arm.name = "MasterArm"
		arm.channel = Sim.Channel.MASTER
		arm.setup(index)
		arm.position = _a_clear_place_for(arm, ARM_PLACES)
		add_child(arm)


## OR A WHEEL, at a boat's helm that launches (the CB90, lane/boats): the stick's missile bindings, through the wheel.
## Called from BOTH places a station is fitted with its missiles -- here, and again when a craft package rebuilds the
## station's controls, which the first draft missed: the wheel the hands held was the package's, and it launched nothing.
func _arm_the_wheel() -> void:
	var wheel := _stick() as SteeringWheel
	if wheel != null:
		wheel.launches = true
		wheel.missile_stations = missile_stations()


## WHERE A MASTER ARM SWITCH MAY GO, best first, in this station's space: on the glareshield OUTBOARD of the throttle,
## then lower on the same side, then the other side. Outboard, because the pedestal the console row stands on is
## inboard. The first one was typed in at (0.12, EYE - 0.28, -0.46) and the fit suite failed it: 0.19 m from the stick's
## grip, where one hand is two controls. So these are candidates, and `_a_clear_place_for` takes the first that is clear
## of every grip already at this station.
const ARM_PLACES: Array[Vector3] = [
	Vector3(-0.30, EYE_HEIGHT - 0.10, -0.45),
	Vector3(-0.42, EYE_HEIGHT - 0.25, -0.22),
	Vector3(0.34, EYE_HEIGHT - 0.10, -0.45),
	Vector3(0.44, EYE_HEIGHT - 0.25, -0.22),
]


## THE FIRST OF `places` WHERE `control`'s GRIP IS NOT WITHIN ONE HAND OF ANY GRIP ALREADY HERE -- the rule
## `tests/fit.gd` measures, two reaches apart -- or the first place if none is. Measured in this station's space, from
## each control's own grab point, so a control whose grip stands up off its mount is measured where a hand goes.
func _a_clear_place_for(control: VehicleControl, places: Array[Vector3]) -> Vector3:
	for place in places:
		var grip: Vector3 = place + control._grab_point()
		var clear: bool = true
		for other in controls().values():
			var node := other as VehicleControl
			if node == null or node == control or node.get_parent() != self:
				continue
			if (node.transform * node._grab_point()).distance_to(grip) < VehicleControl.REACH * 2.0 + 0.02:
				clear = false
				break
		if clear:
			return place
	return places[0]


## THE SEAT A REPEATER SIGHT SHOWS, or -1 at a seat whose sight is its own: see `_fit_the_repeater`.
var _repeats_seat: int = -1


## THE BACK SEAT OF A TWO-SEAT JET SEES THE PILOT'S LOCK (lane/jetarms, 2026-09-18). The F-14D's radar intercept officer
## and the F/A-18F's weapon systems officer sit behind a pilot who flies, points and fires everything; the simulation
## gives them no launch (`launch_seats` are the seats that fly), and a lock sight of their own would always say "not a
## launch seat". So an OPERATOR seat in a craft that carries missiles gets the pilot's sight, repeated: the same glass,
## handed the pilot's row of the locks, headed PILOT'S SIGHT, with no launch bindings and no master arm -- the switch is
## the pilot's. Returns whether it fitted one. The REPEAT is read here and in `configure_authored`, because a station
## built from its craft package arrives with its LockSight already in it.
func _fit_the_repeater(index: int, kind: int) -> bool:
	var schema: Dictionary = Sim.missile_schema(kind)
	var seats: Array = schema.get("launch_seats", []) as Array
	if seats.is_empty() or seats.has(index) or (schema.get("stations", []) as Array).is_empty() 			or String(_seat_pose(kind, index).get("station", "")) != "operator":
		return false
	_missile_schema = schema
	_repeats_seat = int(seats[0])
	if _lock_sight() == null:
		var sight := LockSight.new()
		sight.name = "LockSight"
		add_child(sight)
		sight.look_along(float(schema.get("launcher_pitch", 0.0)))
	return true


## WHETHER THIS SEAT CAN LAUNCH MISSILES: whether it was fitted for them, and not as a repeater. What the desk keys ask.
## WHETHER THIS CRAFT'S SEEKER IS THE CREWMAN'S HEAD: any station the simulation marks `helmet` (the AH-64D's Hellfires).
## Asked of the schema, as the launch seats are, so the sight rides the eye exactly where the server's seeker looks from.
static func _locks_by_the_helmet(schema: Dictionary) -> bool:
	for entry in (schema.get("stations", []) as Array):
		if bool((entry as Dictionary).get("helmet", false)):
			return true
	return false


## WHETHER THIS SEAT CAN LAUNCH MISSILES: whether it was fitted for them. What the desk keys ask.
func launches() -> bool:
	return _lock_sight() != null and _repeats_seat < 0


## THE WEAPON STATIONS THIS SEAT CAN SELECT, as the simulation numbers them -- each schema station's own `station`, which
## is its rack, and not where it sits in the list. What the stick's lower thumb and the desk's Y walk; empty at a seat
## that launches nothing. See `Bind.step_among`.
func missile_stations() -> Array:
	var numbers: Array = []
	for entry in (_missile_schema.get("stations", []) as Array):
		numbers.append(int((entry as Dictionary).get("station", -1)))
	return numbers


## WHETHER ONE OF THE STATIONS THIS SEAT SELECTS IS A GUN: the fighter's minigun, on the selector beside its missiles.
## What the stick's trigger and the desk's fire key ask. See `FlightStick.missile_bindings`.
func fires_a_gun() -> bool:
	for entry in (_missile_schema.get("stations", []) as Array):
		if bool((entry as Dictionary).get("gun", false)):
			return true
	return false


func _range_sight() -> RangeSight:
	return get_node_or_null("RangeSight") as RangeSight


func _helmet_sight() -> HelmetSight:
	return get_node_or_null("HelmetSight") as HelmetSight


## WHETHER THIS SEAT'S GUN FOLLOWS ITS GUNNER'S HEAD, and so fires from the flying stick's own trigger (lane/apache).
func slaves_a_gun() -> bool:
	return _helmet_sight() != null


## WHERE THIS SEAT'S BIG GUN IS TRAINED, as a level direction in the world, for a desk camera to face; ZERO at a seat with
## no ranging sight. The same laid aim the sight is drawn along (`_laid`), so the camera and the crosshair cannot part.
## See PilotRig._desk_train.
func sight_bearing() -> Vector3:
	var ranging := _range_sight()
	var craft: VehicleView = _craft_view()
	if ranging == null or craft == null:
		return Vector3.ZERO
	return RangeSight.bearing_of(craft.global_transform, _laid(ranging.mount, _aimed))


## The craft this station is in, found up the tree.
func _craft_view() -> VehicleView:
	var craft: Node = get_parent()
	while craft != null and not (craft is VehicleView):
		craft = craft.get_parent()
	return craft as VehicleView


## WHERE `mount` IS LAID, AS THIS MACHINE SHOULD SHOW IT: this machine's own gunner's PREDICTED aim when this machine is
## laying that mount -- `CockpitWorld.gunner_state` -- and the wire's `aimed` otherwise. The wire's is a round trip late,
## and a drum read that late by the hand laying the gun is a control loop through the network.
func _laid(mount: int, aimed: Array) -> Vector2:
	if Sim.client != null and Sim.client.has_method("gunner_state"):
		var mine: Dictionary = Sim.client.gunner_state(Sim.local_client_id())
		if _seated_here() and not mine.is_empty() and int(mine.get("mount", -1)) == mount:
			return mine["aim"] as Vector2
	return aimed[mount] as Vector2 if mount < aimed.size() else Vector2.ZERO


## WHETHER THIS MACHINE'S PLAYER SITS AT THIS STATION'S SEAT, as the simulation seats them: asked of the client's own seat
## table, not of the rig, which the station must not reach for.
func _seated_here() -> bool:
	if Sim.client == null or not Sim.client.has_method("vehicle_seats"):
		return false
	var view: VehicleView = _craft_view()
	var sat: PackedInt64Array = Sim.client.vehicle_seats(view.entity) if view != null else PackedInt64Array()
	return seat >= 0 and seat < sat.size() and int(sat[seat]) == Sim.local_client_id()


func _lock_sight() -> LockSight:
	return find_child("LockSight", true, false) as LockSight


## THE LOCK, ONE FRAME. This seat's row of the craft's locks, the selected station's name and how many of its pylons
## are still loaded, the master arm, and the seeker's cone -- all of it off `state`, which every seat aboard shares.
func _show_the_lock(state: Dictionary) -> void:
	var sight := _lock_sight()
	if sight == null:
		return
	var stations: Array = _missile_schema.get("stations", [])
	if stations.is_empty():
		return
	# THE STATION BY ITS OWN NUMBER, not by its place in the list. `stations` lists only racks that are fitted, and the
	# selector counts racks, so the two agree only on a craft whose racks start at 0 with none missing (ashiato-missile:
	# `missile_schema`, cockpit_world.cpp:5526). A selector on a rack with nothing fitted names nothing, which is what
	# the server will say about a launch from it.
	var weapon: int = int(state.get("weapon", 0))
	var chosen: Dictionary = {"name": "no station", "type": 0, "pylon_ids": []}
	for entry in stations:
		if int((entry as Dictionary).get("station", -1)) == weapon:
			chosen = entry
	# A REPEATER SHOWS THE SEAT IT REPEATS: the back seat of a two-seat jet watches the pilot's lock.
	var shown: int = _repeats_seat if _repeats_seat >= 0 else seat
	var mine: Dictionary = {}
	for row in (state.get("locks", []) as Array):
		if int((row as Dictionary).get("seat", -1)) == shown:
			mine = row
	var type: int = int(chosen.get("type", 0))
	if not _cones.has(type):
		_cones[type] = float(Sim.missile_type(type).get("cone", 0.1))
	# HOW MANY ARE LEFT ON THIS STATION: the bits of `stores` its own `pylon_ids` name. Read off the station, never
	# counted from where the station before it ended -- see MissileYard.pylon_of.
	var stores: int = int(state.get("stores", 0))
	var loaded: int = 0
	for id in (chosen.get("pylon_ids", []) as Array):
		if stores & (1 << int(id)):
			loaded += 1
	var craft: Node3D = get_parent() as Node3D
	while craft != null and not (craft is VehicleView):
		craft = craft.get_parent() as Node3D
	sight.show_lock(mine, String(chosen.get("name", "?")), loaded, bool(state.get("master", false)),
		float(_cones[type]), craft, bool(chosen.get("gun", false)), int(state.get("gun_rounds", -1)),
		"PILOT'S SIGHT" if _repeats_seat >= 0 else "")


## THE SIGHT AT THIS STATION, wherever it was fitted.
##
## Not a child lookup any more: on a hand-swung gun it hangs off the GUN, because it has to
## swing with it. Found rather than named, which is the same rule the screens follow.
func _sight() -> GunSight:
	return find_child("Sight", true, false) as GunSight


## WHERE EVERY GUN IN THIS STATION IS POINTING, once a render frame.
##
## `aimed` is the whole craft's mounts, interpolated between the same two simulated states
## the hull is drawn between -- see VehicleView.draw, which is the only caller and the
## reason this is not on the five-a-second state pass with the instruments. A gun in your
## hands that moved five times a second would be a gun that stutters.
func aim_the_gun(aimed: Array) -> void:
	# THE RANGEKEEPER, every drawn frame, in front of whichever camera is looking: see RangeSight.follow.
	var ranging := _range_sight()
	_aimed = aimed
	# ONLY FOR WHOEVER SITS HERE ON THIS MACHINE. Every turret station on a craft has its sight, and each follows the
	# camera that is drawing: the one nobody here sits at drew its TRAIN arrow in the other gunner's view -- turret 3's,
	# trained aft, over turret 2's drum (the 22e picture) -- and its reticle in front of a helm looking along its bearing.
	if ranging != null:
		ranging.visible = _seated_here()
	if ranging != null and ranging.visible:
		var craft: VehicleView = _craft_view()
		var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
		if craft != null and camera != null:
			var laid: Vector2 = _laid(ranging.mount, aimed)
			ranging.follow(camera.global_position, craft.global_transform, laid, -camera.global_basis.z)
			ranging.show_drum(laid, craft.kind, craft.global_transform)
	# THE HELMET SIGHT, the same way and for the same reason: in front of whichever camera is drawing, and only for
	# whoever sits here on this machine, laid by the gunner's own predicted aim (`_laid`).
	var helmet := _helmet_sight()
	if helmet != null:
		helmet.visible = _seated_here()
		if helmet.visible:
			var craft_view: VehicleView = _craft_view()
			var eye: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
			if craft_view != null and eye != null:
				helmet.follow(eye.global_position, eye.global_basis, craft_view.global_transform, _laid(helmet.mount, aimed))
	# AND A HELMET LOCK SIGHT, the same way: in front of whichever camera is drawing, for whoever sits here.
	var seeker := _lock_sight()
	if seeker != null and seeker.helmet:
		seeker.visible = _seated_here()
		var looking: Camera3D = get_viewport().get_camera_3d() if seeker.visible and is_inside_tree() else null
		if looking != null:
			seeker.follow(looking.global_position, looking.global_basis)
	var swivel := _stick() as PintleGun
	if swivel == null or swivel.mount >= aimed.size():
		return
	swivel.point_at(aimed[swivel.mount] as Vector2, seat_yaw)


## WHERE THE GUN AT THIS STATION REALLY IS, when a hand on THIS machine is out ahead of the wire
## with it: {"mount": n, "aim": Vector2}, or {} when nobody here is holding it.
##
## ANNOUNCED, NOT APPLIED. The station says what it knows and `VehicleView.draw_turrets_at`
## decides what to draw, which is the same split as everything else in this cockpit -- a station
## that reached out and turned the barrel itself would be a station that cannot be stood on a
## bench with no aircraft behind it.
func gun_it_is_leading() -> Dictionary:
	# A HELMET-SLAVED GUN THIS MACHINE'S PLAYER IS LAYING is ahead of the wire by the gunner's own prediction: the barrel
	# he sees is the one his rounds leave from, a round trip before everyone else sees it (`_laid`).
	var helmet := _helmet_sight()
	if helmet != null and _seated_here():
		return {"mount": helmet.mount, "aim": _laid(helmet.mount, _aimed)}
	var swivel := _stick() as PintleGun
	if swivel == null or not swivel.is_leading():
		return {}
	return {"mount": swivel.mount, "aim": swivel.led_aim()}


## NOTHING BETWEEN THE GUNNER AND THEIR GUN.
##
## A station is laid out for somebody FLYING: a screen at eye height an arm's length ahead,
## which is where a pilot looks between glances at the horizon. A door gunner looks at one
## thing, it is out of the door, and the gun is between them and it -- so the screen ends up
## standing in front of the gun, and the first thing a run of this showed was a sight hidden
## behind a flight display.
##
## So the screen goes. This is the same move as swapping the yoke for the gun above, and for
## the same reason: one station scene serves four seats, and what a seat needs is a fact
## about the CRAFT rather than about the scene. Freed rather than hidden, because a hidden
## screen is still a screen every walk of the station finds -- see `show_state`, which feeds
## every CraftDisplay it can reach.
##
## The crew board stays. It is off to one side, out of the arc, and knowing who else is
## aboard is worth as much to a gunner as to anybody.
func _clear_the_gunners_view() -> void:
	var screen := get_node_or_null("Display")
	if screen != null:
		remove_child(screen)
		screen.queue_free()


## THE WHOLE STATION, REFLECTED ABOUT ITS OWN CENTRE LINE.
##
## Positions and headings only -- nothing is scaled by -1. A negative scale flips the winding
## of every mesh under it, so the cockpit turns inside out and lights it from the wrong side,
## and Godot propagates that to every child. Every control in this game is symmetric about
## its own axis anyway: a lever reflected is a lever, and only WHERE it is and WHICH WAY it
## faces have to change.
##
## The stick stays put, which is the point of doing it this way: it sits on the centre line,
## `-0.0` is `0.0`, and the one control both seats must agree about does not move.
func _mirror_the_layout() -> void:
	for child in get_children():
		var node := child as Node3D
		if node == null:
			continue
		node.position.x = -node.position.x
		# THE HEADING TOO, or a display angled in at the captain is angled OUT at the
		# copilot -- turned away from the one person meant to read it.
		node.rotation.y = -node.rotation.y
		node.rotation.z = -node.rotation.z


## A TRIM WHEEL AT THE PILOT'S HIP, on the craft whose bus carries trim.
##
## ONE PER SEAT, ON ONE CHANNEL, and that is what a real flight deck has: two wheels either
## side of the pedestal, mechanically linked, both showing the same trim. Here the linkage
## is the wire -- `VehicleControl.apply` draws every control from the replicated value, so
## the copilot's wheel turns when the captain winds his, which is the same mechanism that
## makes two yokes move together.
##
## NOT ON THE CENTRE PEDESTAL, which is where it was first put. That row holds three levers
## before its ends go past a seated arm; a fourth put both ends 0.69 m out. Measured, in
## `every_control_is_within_a_seated_arm`.
##
## OUTBOARD AND LOW, below the throttle that hand is already on. That is where the wheel is
## in every aeroplane that has one, and the reason is the same here as there: it is a
## control you wind with the heel of your hand without looking, while the other hand flies.
func _fit_the_trim_wheel(kind: int) -> void:
	if get_node_or_null("Trim") != null:
		return
	var top: int = trim_range_of(kind)
	if top <= 0:
		return
	_place_the_trim_wheel(top)


## THE STICK OR YOKE AT THIS SEAT TRIMS THE CRAFT, if this seat may.
##
## THE CRAFT HAS TRIM THAT MEANS SOMETHING, and THIS SEAT FLIES. Trim is a physical channel, and `apply_command` takes
## a physical channel only from a seat that flies -- so a gunner's stick bound to trim would be a thumb whose every push
## the server refuses. Asked of the same `trim_range_of` the wheel is fitted by, so the wheel and the thumb cannot
## disagree about whether this craft trims.
func _fit_the_trim_to_the_column(kind: int, flies: bool) -> void:
	var top: int = trim_range_of(kind) if flies else 0
	var column: VehicleControl = _stick()
	if column is FlightStick:
		(column as FlightStick).trim_range = top
	elif column is ControlYoke:
		(column as ControlYoke).trim_range = top


## HOW FAR THIS KIND'S TRIM GOES, or 0 where it has none worth a wheel or a thumb.
##
## ONE QUESTION, asked by the wheel and by the column: the channel's range off `craft_schema`, and only on a craft
## whose trim works something.
static func trim_range_of(kind: int) -> int:
	if kind < 0:
		return 0
	# AND ONLY WHERE TRIM MEANS SOMETHING, which is a wing or a rotor. The locomotive's bus
	# carries a channel called "drive trim" and a locomotive has no elevator: fitting it a
	# wheel put one 0.24 m from the brake handle for a control nobody would ever wind.
	var model: int = int(Sim.geometry_of(kind).get("model", -1))
	if model != Sim.Model.AIRPLANE and model != Sim.Model.HELICOPTER 			and model != Sim.Model.TILTROTOR:
		return 0
	var top: int = 0
	for entry in (Sim.schema_of(kind).get("channels", []) as Array):
		if int((entry as Dictionary).get("channel", -1)) == Sim.Channel.TRIM:
			top = int((entry as Dictionary).get("range", 0))
	return maxi(top, 0)


## RUDDER PEDALS IN THE FOOTWELL, at a seat that flies something with a rudder. See RudderPedals.
##
## UNDER THE FLYING CONTROL AND AHEAD OF IT, ON THE FLOOR. Measured from the column rather than typed into each scene,
## because the column is what a pilot sits square to and every craft puts it somewhere else: the pedals take its x,
## stand `FOOTWELL` ahead of its base and sit on `FLOOR`. With no column they go under where the hands would be.
##
## Fitted before the mirror, so a right-hand seat's pedals are reflected with its column, and before the saved layout,
## so a player who moved them finds them where they left them.
func _fit_the_pedals(index: int, kind: int, flies: bool) -> void:
	if not flies or not has_pedals(kind) or find_children("*", "RudderPedals", false, false).size() > 0:
		return
	var pedals := RudderPedals.new()
	pedals.name = "Pedals"
	var column: VehicleControl = _stick()
	var under: Vector3 = column.position if column != null else Vector3(0.0, hands(), -HANDS_FORWARD)
	# ON THE FLOOR THE FEET ARE ON, which is the craft's raised footwell where it has one (`CockpitShell.footwell_raise`).
	# They stood on the anchor's floor until 2026-09-19: 0.20 m under the Little Bird's drawn floor, and 0.70 m under
	# the Duo Discus's -- out through its belly.
	var shell := get_node_or_null("Shell") as CockpitShell
	var raise: float = shell.footwell_raise if shell != null else 0.0
	var ahead: float = RECLINED_FOOTWELL if shell != null and shell.reclined else FOOTWELL
	pedals.position = Vector3(under.x, FLOOR + raise, under.z - ahead)
	pedals.setup(index)
	add_child(pedals)


## WHETHER THIS KIND FLIES WITH A RUDDER WORTH PEDALS: a wing with a fin, or a rotor with a tail rotor.
##
## The model test `trim_range_of` asks, off the simulation's own table. A car steers with its wheel and a pod yaws off the
## same axis a thumb pushes, and neither has a footwell; both read the rudder, and neither is given pedals.
static func has_pedals(kind: int) -> bool:
	if kind < 0:
		return false
	var model: int = int(Sim.geometry_of(kind).get("model", -1))
	return model == Sim.Model.AIRPLANE or model == Sim.Model.HELICOPTER or model == Sim.Model.TILTROTOR


## THE WHEEL ITSELF, for a craft whose trim goes to `top`.
func _place_the_trim_wheel(top: int) -> void:
	# ON THE RIGHT OF THE SEAT, because the left is taken. Every craft with trim also has a
	# power lever under the left hand -- a quadrant on an aeroplane, a collective on a
	# helicopter -- and the collective in particular sits well aft and inboard of where a
	# quadrant does, which is exactly where a wheel beside the left hip would be. Measured:
	# 0.248 m from the collective, against the 0.32 the layout rule asks.
	#
	# The right side has the crew button on it and nothing else, and that is 40 cm higher.
	var wheel := TrimWheel.new()
	wheel.name = "Trim"
	wheel.channel_range = top
	# AND OVER THE FLOOR, where a craft lifts it: at 0.62 m it stood 0.08 m UNDER the Duo Discus's raised floor, in the
	# belly (2026-09-19). A wheel 0.12 m over whatever floor the feet are on.
	var shell := get_node_or_null("Shell") as CockpitShell
	var floor_top: float = FLOOR + (shell.footwell_raise if shell != null else 0.0)
	wheel.position = Vector3(0.30, maxf(hands() - 0.32, floor_top + 0.12), -0.10)
	wheel.setup(seat)
	wheel.value = Vector2(0.0, TrimWheel.CENTRE)
	add_child(wheel)


## TWO MULTI-FUNCTION DISPLAYS, for a seat that does not fly.
##
## A pilot has a windscreen, a stick and a horizon. A gunner sitting sideways in the back of
## a boat has a screen, and that is the whole of what they can know -- so they get the same
## thing an F/A-18 gives the seat behind the pilot: a Digital Display Indicator either side,
## twenty pushbuttons round each, and every page the aircraft can actually answer.
##
## Fitted here rather than authored into eight station scenes because it depends on the SEAT
## and not on the craft: the same station scene is used by the pilot and by the gunner, and
## which of them is sitting in it is something only the vehicle knows. See `VehicleView.man`,
## which reads `flies` off the seat poses the simulation publishes.
const MFD_PAGE := preload("res://objects/seats/mfd_page.tscn")
const MFD_SIZE := Vector2(0.20, 0.20)


func _fit_the_map_screen() -> void:
	# An authored MFD cockpit already owns navigation and crew pages. Adding the generic map as well gave each Prowler
	# pilot a fourth display, and the mirrored pair nearly occupied the same point across the centreline.
	if get_node_or_null("MapScreen") != null or not find_children("*", "MfdPanel", true, false).is_empty():
		return
	var screen := MapScreen.new()
	screen.name = "MapScreen"
	# Low on the right console, below the authored crew board and flight display.
	# The first eye shot put it at their height and the crew board hid the glass.
	# At 0.40, the mirrored screens in the plane's seats at x +/-0.55 landed only
	# 0.30 m apart: closer than two 0.16 m hand targets, so either hand could select both.
	# Two centimetres outboard leaves 0.34 m between their grips while keeping each on its
	# pilot's right/left console and comfortably inside seated reach.
	# A CRAFT WITH A CHART SHELF UNDER ITS FRONT GLASS (`"map_screen_height"` in its catalogue entry) stands the glass on
	# the shelf. At the standard 0.84 the FIREBOAT's helm, sitting 0.60 m abaft the wheelhouse front, had the screen
	# 0.05 m UNDER the shelf's 0.06 m plank and could not see it from either seat (`tests/screens_face.gd`, 2026-09-20).
	var height: float = hands() - 0.10
	if craft_kind >= 0:
		height = float(VehicleCatalogue.of(craft_kind).get("map_screen_height", height))
	screen.position = Vector3(0.38, height, -HANDS_FORWARD - 0.04)
	screen.rotation = Vector3(-0.30, -0.18, 0.0)
	add_child(screen)
	screen.setup(seat)


## WHERE THE TANK GAUGE SITS, in the seat's own frame: outboard on the instrument panel,
## beside the flight display, on the side away from the crew board.
##
## NOT ON THE CENTRELINE, WHICH IS WHERE IT WAS FIRST PUT, and the measurement that moved it
## is `tests/water.gd`, `and_nothing_else_in_the_cockpit_stands_between_the_eye_and_its_face`.
## Under the flight display at x 0 looks like free panel and is not: the CONTROL COLUMN lies
## along it. The yoke's shaft is a 0.34 m cylinder of 0.026 m radius reaching forward to
## z -0.425 at h 0.914 to 0.966, and the display's bottom edge at h 1.04 casts a shadow from
## the seated eye that crosses that shaft at z -0.439. The gap between the two is nothing at
## all: every gauge that clears the column is hidden behind the display, and every gauge seen
## under the display is inside the column. The first placement was found by the check rather
## than by eye, which is what the check is for.
##
## ON THE PANEL ROW, at the height and depth of the flight display and the crew board, so it
## is read at the 30 degrees below the eye those two are and not at the 43 the centreline
## would have cost. 0.50 m from the seated eye, 40 degrees off the nose -- the crew board's
## own offset, mirrored.
const GAUGE_OUTBOARD: float = 0.30
const GAUGE_ROW: float = 1.14
const GAUGE_AHEAD: float = -0.36
## TILTED UP AND TURNED IN AT THE FACE, so the numerals are read square rather than
## foreshortened. The eye looks down at it by 30 degrees and in by 40; a face turned the
## whole way would be edge-on to a copilot glancing across, so it is turned most of the way.
const GAUGE_TILT: float = -0.35
const GAUGE_YAW: float = 0.50


## A WATER GAUGE ON THE PANEL OF A CRAFT THAT CARRIES WATER, at every seat that flies it.
##
## FITTED AND NOT AUTHORED, for the reason the map screen is: it depends on the CRAFT, and
## the same station scene serves every aeroplane in the game. Authoring it would mean editing
## two station JSON files in the tanker's package, which would move both station hashes and
## the manifest hash with them -- and a manifest hash is the one thing two lanes cannot both
## be right about (`e8005da2`). A part fitted at runtime is outside the package's signature,
## which is why the map screen is fitted the same way into an authored station.
##
## ASKED OF THE BUS AND NOT OF A LIST OF NAMES. A craft has a water gauge exactly when it has
## tank doors, because the doors are what empties the tank; `Sim.schema_of` is the same
## authority `VehicleView` fits the drop handle from, so a second aeroplane with a tank gets
## its gauge by being given its doors and nothing here is edited. A roster of which craft
## carry water is exactly the list that would go out of date.
##
## AND WHICH SIDE IT GOES ON IS READ OFF THE STATION, NOT OFF A MIRROR FLAG. This is the one
## subtle thing here. A flying seat is laid out two different ways depending on where it came
## from: a FITTED station is authored for the captain and reflected afterwards by
## `_mirror_the_layout`, and an AUTHORED station's right-hand seat arrives from its package
## already reflected and is never mirrored again. A part that placed itself at a signed x
## would have to know which of those two it was under -- and would be wrong for one of them.
## The crew board is already in the station under both, at +0.30 on a left-hand seat and
## -0.30 on a right-hand one, so its sign IS the answer, whichever way the seat got here.
## Ask the authority that is present; do not keep a flag that could disagree with it.
func _fit_the_tank_gauge(kind: int) -> void:
	if get_node_or_null("TankGauge") != null or not _carries_water(kind):
		return
	var gauge := TankGauge.new()
	gauge.name = "TankGauge"
	var side: float = _outboard_side()
	gauge.position = Vector3(side * GAUGE_OUTBOARD, GAUGE_ROW, GAUGE_AHEAD)
	gauge.rotation = Vector3(GAUGE_TILT, -side * GAUGE_YAW, 0.0)
	add_child(gauge)


## WHICH WAY IS OUTBOARD ON THIS PANEL: -1 for a left-hand seat and +1 for a right-hand one.
##
## Off the crew board, which is outboard on the far side of the flight display and is in the
## station before anything is fitted into it. A station with no crew board answers -1 and is
## reflected by `_mirror_the_layout` if it is going to be, which is right for every station
## that is FITTED; an authored package with a right-hand seat and no crew board would be the
## one case this cannot read, and `tests/water.gd` holds both seats to mirrored positions so
## the day such a craft exists the check says so rather than the cockpit quietly doubling up.
func _outboard_side() -> float:
	var board := get_node_or_null("Crew") as CrewBoard
	if board != null and absf(board.position.x) > 0.01:
		return -signf(board.position.x)
	return -1.0


## Does this craft carry water? See `_fit_the_tank_gauge`. ASKED OF THE SIMULATION'S TANK, not of the drop channel: the
## V-22's ramp is on that channel too -- the doors a load leaves by -- and the first V-22 fitted with it grew a tank gauge.
func _carries_water(kind: int) -> bool:
	if kind < 0:
		return false
	return Sim.carries_water(kind)


func _fit_the_mfds() -> void:
	if get_node_or_null("MfdLeft") != null:
		return
	# NOT IN FRONT OF A GUN. Two screens either side of the console is the right answer for
	# a gunner sitting sideways in the back of a boat, whose screen is the whole of what
	# they can know. A door gunner has a door, and the screens would sit in the arc of the
	# thing they are pointing through it.
	if _stick() is PintleGun:
		return
	var hands_at: float = hands()
	for side in [-1.0, 1.0]:
		var screen := CraftDisplay.new()
		screen.name = "MfdRight" if side > 0.0 else "MfdLeft"
		screen.page = MFD_PAGE
		screen.size = MFD_SIZE
		# 3840 pixels a metre across a 0.20 m pane. See CraftDisplay: redrawn at 5 Hz.
		screen.pixels = 768
		screen.bezel = true
		# Out past the stick and tilted up at the face, where a console screen is. Below the
		# eyeline, because nothing solid may stand between the eyes and the horizon -- the
		# rule the whole cockpit is built on, and a screen is as solid as a wall.
		var across: float = side * 0.30
		var turn: float = -side * 0.35
		# A CRAFT WHOSE WALL STANDS BESIDE THE SEAT stacks the pair on the inboard side, before the mirror flips them, the
		# right one over the left: side by side they were 0.26 m of screen across a cabin 1.18 m wide and each hid the other
		# from the eye, and the opposite seat's pair hid them both (`screens_face`, 2026-09-20).
		var lower: float = 0.0
		if craft_kind >= 0 and bool(VehicleCatalogue.of(craft_kind).get("screens_inboard", false)):
			across = 0.40
			turn = -atan2(across, 0.42) * 0.9
			lower = 0.21 if side > 0.0 else 0.51
		screen.position = Vector3(across, hands_at + 0.06 - lower, -HANDS_FORWARD - 0.08)
		screen.rotation = Vector3(-0.55, turn, 0.0)
		add_child(screen)
		var page := screen.shown() as MfdPage
		if page != null:
			page.right_hand_side = side > 0.0


## Show the whole crew on this station's board, if it has one. See CrewBoard.
func show_crew(crew: Array) -> void:
	var board := get_node_or_null("Crew") as CrewBoard
	if board != null:
		board.show_crew(crew)


func show_map(map: LevelMap, markers: Array[Dictionary]) -> void:
	for screen in find_children("*", "MapScreen", true, false):
		(screen as MapScreen).show_map(map, markers)


## SHOW THE CRAFT'S STATE ON EVERY SCREEN IN THIS STATION, however many there are and
## wherever in the scene they were put.
##
## Found rather than listed, like the stations themselves: a screen added to a cockpit
## scene in the editor starts being fed without anything here being told about it.
func show_state(state: Dictionary, crew: Array) -> void:
	show_crew(crew)
	for screen in find_children("*", "CraftDisplay", true, false):
		(screen as CraftDisplay).show_state(state)
	# AND EVERY WATER GAUGE, found the same way and for the same reason: a gauge added to a
	# cockpit scene starts being fed without anything here being told about it.
	for gauge in find_children("*", "TankGauge", true, false):
		(gauge as TankGauge).show_state(state)
	var sight := _sight()
	if sight != null:
		var mounts: Array = state.get("turrets", [])
		var aim: Vector2 = mounts[sight.mount] if sight.mount < mounts.size() \
			else Vector2.ZERO
		# The craft's own pose, found through the tree rather than passed in: the station
		# hangs off a seat anchor which hangs off the vehicle, so the answer is already
		# here and a second copy could disagree with it.
		var craft: Node3D = get_parent()
		while craft != null and not (craft is VehicleView):
			craft = craft.get_parent() as Node3D
		# WHAT THIS GUN IS LOADED WITH, and not what the first gun aboard is loaded with.
		# A Chinook's mid-cabin seat has no gun at all and its ramp gun is mount 1, so a
		# name taken off mount 0 was a name for a gun that is not there.
		var loaded: Array = state.get("ammo_names", [])
		var says: String = String(loaded[sight.mount]) if sight.mount < loaded.size() \
			else "gun"
		sight.show_gun(aim, says,
			craft.global_transform if craft != null else Transform3D.IDENTITY)
	var ranging := _range_sight()
	if ranging != null:
		var view: VehicleView = _craft_view()
		if view != null:
			var trunnion: Vector3 = view.global_transform * (ranging.gun.get("at", Vector3.ZERO) as Vector3)
			ranging.show_laying(Sim.shots, Sim.local_client_id(), trunnion)
	_show_the_lock(state)

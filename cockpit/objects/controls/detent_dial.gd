@tool
extends VehicleControl
class_name DetentDial
## A SELECTOR: a knob that stops at NAMED positions, and has them written round it.
##
## OFF, LOW, MED, HIGH. Master arm SAFE and ARM. Fuel LEFT, BOTH, RIGHT. A cockpit is full
## of these and they are not knobs with fewer numbers -- they are a different promise.
##
## ---------------------------------------------------------------------------------
## THE DIFFERENCE FROM A KNOB IS THE SAME AS FLAPS FROM A THROTTLE
## ---------------------------------------------------------------------------------
##
## A `RotaryKnob` can rest anywhere, because the thing on the other end of it can be set to
## anything. A selector cannot: the channel it works carries three positions, and a pointer
## resting between two of them would be asking for a setting the aircraft has no way to
## hold. The number on the panel would then disagree with the number in the simulation, and
## nothing would say which was wrong.
##
## So the wrist turns it smoothly and it SETTLES on the nearest stop -- exactly what the
## flap gate does on its rail, for exactly the same reason, and exactly what the detent in a
## real selector does under your fingers.
##
## ---------------------------------------------------------------------------------
## AND THE POSITIONS ARE WRITTEN ON IT
## ---------------------------------------------------------------------------------
##
## A three-position dial with no legend is three angles nobody can tell apart. Every real
## one is silkscreened, and this one is too: the stop names are part of the control and not
## part of the LABELS view, because unlike "this lever is the flaps" -- which you learn once
## and then never need again -- which way is HIGH is a thing you read every single time.
##
## A SHORT SWEEP, unlike the knob. Ninety degrees across the whole selector, so the throw
## between neighbouring stops is big enough to feel and the whole range is inside one
## comfortable roll of a wrist. A selector you have to re-grip to get to the end of is one
## nobody switches in a hurry.

const SWEEP: float = 1.571

## HOW FAR PAST HALFWAY A WRIST HAS TO TURN BEFORE THE DIAL LEAVES A STOP, as a fraction of one stop's throw.
##
## Settling on the nearest stop alone puts the boundary at exactly halfway, and a tracked wrist resting there flips
## between two stops at the display rate: a click a frame under the hand, and on a `TimeOfDayDial` a sky rewritten a
## frame. A tenth of a stop is 4.5 degrees on a three-stop dial -- over a resting hand's tremor, well under a
## deliberate turn. Every DetentDial has it; tests/scenery.gd holds a wrist wobbling two degrees either side of an edge
## to no change at all.
const DETENT_HOLD: float = 0.1

const RADIUS: float = 0.024
const HEIGHT: float = 0.020

## HOW BIG THE LEGEND IS. Smaller than a control's own label -- see `VehicleControl.
## LABEL_PIXELS` -- because these sit beside the knob a few centimetres apart rather than
## floating above the cockpit, and at label size three of them overlap.
##
## A LINE OF 10 MM, where it was 6.2 (48 x 0.00013). Flat on the panel, facing straight up, 2 mm off the dial's base --
## under the top of its own plate -- the names were turned 50 degrees from a seated eye and 4 mm tall to it, the middle one
## stood behind the pointer bar, and from the seat no stop name could be read at all (2026-09-14, tests/station_shot.gd and
## tests/builder.gd). 64 x 0.00016 at 38 cm from the eye is about 30 px on a Quest 2.
const LEGEND_PIXELS: float = 0.00016
const LEGEND_SIZE: int = 64
## HOW THICK THE PLATE UNDER THE KNOB IS. The names stand above it.
const PLATE: float = 0.006
## HOW FAR BEHIND THE KNOB'S MIDDLE THE ROW OF NAMES STANDS, and how high. Each name is where the pointer's line meets
## that row, so the pointer still points at the name of the stop it is on; high enough that the line from a seated eye
## to the middle name passes over the pointer bar rather than through it.
##
## 5 CM BACK, not 4: at 4 cm the side names stood 4 cm either side of the middle one, and EVENING alone is 4.3 cm wide, so
## from the seat EVENING and NIGHT ran into each other (2026-09-14).
const LEGEND_BACK: float = RADIUS + 0.026
## 40 MM UP, not 20: from the seat the pointer's bar lay across EVENING at 20 -- clear of it in space, and across it in the
## eye's view (2026-09-14, tests/builder.gd, from the seat the pointer covers no name).
const LEGEND_UP: float = 0.04
## HOW FAR OVER THE ROW OF NAMES A DIAL'S OWN LABEL HANGS, so the seated eye sees it above the names and not across them.
const LABEL_CLEAR: float = 0.035
## HOW FAR THE LEGEND REACHES FROM THE MIDDLE OF THE DIAL, in front of it and behind: anything that must leave a dial room
## to be read -- where the builder lands a part, see `PilotRig.where_a_new_control_lands` -- asks this.
const LEGEND_REACH: float = RADIUS + 0.056


## HOW FAR THE NAMES LEAN BACK TOWARDS THE SEAT from standing upright, in radians: the angle a seated pilot looks down at
## their own hands, off `CockpitStation`'s head and hands. Every station is authored against those two numbers, so a dial
## at hand height is read along this line; about 50 degrees.
static func legend_tilt() -> float:
	return atan2(CockpitStation.HANDS_BELOW_EYES, CockpitStation.HANDS_FORWARD)


## THE LABEL HANGS OVER THE PLACARD, not over the grip. Over the grip it was seen from the seat straight across the stop
## names -- "TIME OF DAY" written through EVENING, "MODE" through MED -- so it stands above the row instead.
func _label_point() -> Vector3:
	return Vector3(0.0, LEGEND_UP + LABEL_CLEAR, -LEGEND_BACK)

## WHAT THE STOPS ARE CALLED, in order, from hard left to hard right.
##
## EXPORTED, because the names ARE the control. Three is the common case and the one the
## default carries; two is a switch you would rather have as a `ToggleSwitch`, and five is
## about as many as a wrist can find without looking.
@export var stops: PackedStringArray = ["LOW", "MED", "HIGH"]:
	set(value):
		stops = value
		if _body != null:
			_relabel()

var _body: Node3D = null
var _legends: Array[Label3D] = []


func label_text() -> String:
	return "DIAL\n%s" % Sim.channel_name(channel).to_upper()


func _build() -> void:
	control_name = "dial"
	scope = Scope.CRAFT
	if channel < 0:
		channel = Sim.Channel.MODE
	# THE RANGE IS THE NUMBER OF GAPS, not the number of stops. Three positions is a range
	# of two, exactly as the flap gate's four notches are a range of three -- the bus
	# carries 0..range and the simulation divides by the range to get the fraction.
	channel_range = maxi(stops.size() - 1, 1)
	var plate := CylinderMesh.new()
	plate.top_radius = RADIUS + 0.010
	plate.bottom_radius = RADIUS + 0.011
	plate.height = PLATE
	plate.radial_segments = 24
	_make_mesh(plate, Color(0.10, 0.11, 0.13), Vector3(0.0, PLATE * 0.5, 0.0))
	# A PLACARD BEHIND THE KNOB, leaning towards the seat, that the stop names are written on: dark, so a name reads
	# against it and not against whatever stands behind the dial -- a screen, a window, the sky.
	var card := BoxMesh.new()
	card.size = Vector3(LEGEND_BACK * 2.0 + 0.05, float(LEGEND_SIZE) * LEGEND_PIXELS + 0.012, 0.002)
	var placard: MeshInstance3D = _make_mesh(card, Color(0.08, 0.09, 0.10), Vector3(0.0, LEGEND_UP, -LEGEND_BACK - 0.002))
	placard.name = "Placard"
	placard.rotation = Vector3(-_lean_for_where_it_stands(), 0.0, 0.0)
	_body = Node3D.new()
	_body.name = "Body"
	_body.position = Vector3(0.0, PLATE, 0.0)
	add_child(_body)
	# A BAR AND NOT A CYLINDER. A selector is turned with the whole hand rather than two
	# fingers, and the shape that says so is a wing-topped knob you can find in the dark.
	var wing := BoxMesh.new()
	wing.size = Vector3(RADIUS * 0.55, HEIGHT, RADIUS * 2.0)
	_under(_body, wing, Color(0.22, 0.23, 0.26), Vector3(0.0, HEIGHT * 0.5, 0.0))
	# THE END THAT POINTS. One end of a symmetrical bar is not a pointer until it is a
	# different colour from the other end.
	var nose := BoxMesh.new()
	nose.size = Vector3(RADIUS * 0.58, HEIGHT + 0.002, RADIUS * 0.7)
	_under(_body, nose, Color(0.93, 0.82, 0.30),
		Vector3(0.0, HEIGHT * 0.5, -RADIUS * 0.66))
	_relabel()
	# AND LEANED AGAIN WHENEVER IT IS MOVED: put down by the builder, dragged, or placed by a saved layout. See
	# `_lean_for_where_it_stands`.
	set_notify_local_transform(true)


## THE LEAN FOR THIS DIAL, WHERE IT STANDS, in radians back from upright: straight up the line to the seated eye when the
## dial is on a station, and `legend_tilt` anywhere else -- a bench, the hall, a test with no seat.
##
## BECAUSE A PART IS NOT ALWAYS AT THE HANDS. A dial the builder landed out to one side and above the stick (0.27, 1.18,
## -0.25 on the plane) is looked at from 27 degrees up, not 50, and its names, leaning at the hands' angle, were 31
## degrees off the eye (2026-09-14, tests/builder.gd). The dial is turned to face the seat when it is placed -- see
## `PilotRig.place_a_new_control` -- so only the lean has to follow the height.
func _lean_for_where_it_stands() -> float:
	if not (get_parent() is CockpitStation):
		return legend_tilt()
	var eye: Vector3 = transform.affine_inverse() * Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
	var from_the_row := Vector3(eye.x, eye.y - LEGEND_UP, eye.z + LEGEND_BACK)
	return atan2(from_the_row.y, Vector2(from_the_row.x, from_the_row.z).length())


func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED or what == NOTIFICATION_PARENTED:
		_lean_the_legend()


## LEAN THE PLACARD AND THE NAMES ON IT for where the dial stands now. Three rotations, on a move.
func _lean_the_legend() -> void:
	var lean := Vector3(-_lean_for_where_it_stands(), 0.0, 0.0)
	var placard := get_node_or_null("Placard") as Node3D
	if placard != null:
		placard.rotation = lean
	for word in _legends:
		if is_instance_valid(word):
			word.rotation = lean


## ONE NAME PER STOP, standing at the angle that stop is at.
##
## Rebuilt rather than moved when `stops` changes, because the number of them is what
## changed -- and a dial relabelled from three positions to two with a third name still
## painted on it is worse than one with no names at all.
func _relabel() -> void:
	for old in _legends:
		old.queue_free()
	_legends.clear()
	var gaps: float = float(maxi(stops.size() - 1, 1))
	for step in range(stops.size()):
		var about: float = _pointing(float(step) / gaps)
		var word := Label3D.new()
		word.name = "Stop%d" % step
		word.text = stops[step]
		word.font_size = LEGEND_SIZE
		word.pixel_size = LEGEND_PIXELS
		word.modulate = Color(0.82, 0.85, 0.86)
		word.outline_size = 10
		word.outline_modulate = Color(0.0, 0.0, 0.0, 0.8)
		# ON THE PLACARD, LEANING TOWARDS THE SEAT, where the seated eye reads them: see `legend_tilt`. Every name faces the
		# same way, level, like the words on a real placard. Billboarded they would turn to face the pilot and stop lining
		# up with the stop they name, which is the one thing they must do -- so each stands where the pointer's line at
		# that stop crosses the row, and the pointer still points at its name.
		word.rotation = Vector3(-_lean_for_where_it_stands(), 0.0, 0.0)
		word.position = Vector3(tan(about) * LEGEND_BACK, LEGEND_UP, -LEGEND_BACK)
		add_child(word)
		_legends.append(word)
	if channel_range != maxi(stops.size() - 1, 1):
		channel_range = maxi(stops.size() - 1, 1)
	_redraw()


static func _under(parent: Node3D, mesh: Mesh, colour: Color, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.5
	node.material_override = material
	parent.add_child(node)
	return node


func _pointing(at: float) -> float:
	return (clampf(at, 0.0, 1.0) - 0.5) * SWEEP


func _grab_point() -> Vector3:
	return Vector3(0.0, HEIGHT * 0.7, 0.0)


func _redraw() -> void:
	if _body == null:
		return
	_body.rotation = Vector3(0.0, -_pointing(value.y), 0.0)
	# THE STOP IT IS ON, LIT. Which one the pointer is nearest is readable from the angle,
	# but only if you are looking straight down at it -- and in a cockpit you are looking at
	# it from wherever your head happens to be.
	for step in range(_legends.size()):
		_legends[step].modulate = Color(0.97, 0.84, 0.32) if step == at_stop() \
			else Color(0.62, 0.65, 0.67)


## WHICH STOP IT IS ON, counting from 0 at the left. What a panel shows, and what the bus
## carries.
func at_stop() -> int:
	return command_value()


## The name of the stop it is on, for anything that has to say so out loud.
func stop_name() -> String:
	var which: int = at_stop()
	return stops[which] if which >= 0 and which < stops.size() else "?"


## TURNED SMOOTHLY, SETTLED ON THE NEAREST STOP. See the note at the top: this is the flap
## gate's rule, on an axis instead of a rail.
func _turn(facing: Basis) -> void:
	var rolled: float = clampf(
		_grab_value().y - _turned_about(Vector3.UP, facing) / SWEEP, 0.0, 1.0)
	var gaps: float = float(maxi(channel_range, 1))
	# AND THE STOP IT WAS ON BEFORE, so the hand can be told when it leaves one.
	#
	# A detent is the one thing on a panel whose whole point is that you do not have to
	# look at it: a real selector clicks, and a wrist that has felt three clicks knows it
	# is on the third stop without reading the legend. Modelled geometrically here since
	# the day this class was written, and until now there was no way to tell anybody.
	#
	# ON THE CHANGE OF STOP, not on the angle. `at_stop` is `command_value`, which is what
	# the bus carries -- so one click is one thing that happens on the aircraft, and a
	# wrist rolling within one detent's width says nothing at all.
	var was: int = at_stop()
	var wanted: float = rolled * gaps
	# AND NOT UNTIL IT IS CLEARLY PAST HALFWAY. See DETENT_HOLD.
	var stop: float = roundf(wanted) if absf(wanted - float(was)) >= 0.5 + DETENT_HOLD else float(was)
	_settle(Vector2(0.0, stop / gaps))
	if at_stop() != was:
		bump(&"detent")


func throttle() -> float:
	return 0.0


## PINCHED, NOT GRABBED, like the knob it is a kind of: a selector is turned between finger and
## thumb, not held in a fist. `TimeOfDayDial` inherits this, which is right -- it is this object
## with the level's times written round it. See `Bind.Take`.
func taken_by() -> int:
	return Bind.Take.PINCH


## READ, NOT PUSHED ALONG AN AXIS: turned to face the seat when the builder adds one. See `VehicleControl.faces_the_eye`.
func faces_the_eye() -> bool:
	return true

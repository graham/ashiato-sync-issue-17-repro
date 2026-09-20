extends MarshallingLevel
class_name GateArrival
## BRING AN AIRLINER ONTO THE STAND AND GET THE DOOR OPEN.
##
##   Godot --path cockpit -- --level=stand
##
## The same job as the deck, done to the other extreme. A carrier launch is twenty seconds
## of hurry; a stand arrival is two minutes of not being wrong. What is at the end of it is
## not a catapult but a jet bridge, pointed at where the door is GOING to be -- so the whole
## thing is scored on where the nosewheel stops, and the bridge swings to wherever the door
## actually ended up. Park her a metre and a half short and you can watch it stretch.
##
## And she is twenty-six metres long. The nosewheel is thirteen metres in front of the main
## gear, so the aeroplane goes where it is pointed long after it has been pointed there, and
## the turn a fighter makes in a deck's width takes an airliner half the apron. Same signals,
## same hands, a different aeroplane underneath them -- which is the entire reason for
## having two levels instead of one with the numbers changed.

const AIRLINER := preload("res://objects/vehicles/craft_airliner.tscn")

## How close the nosewheel has to be to the bar. Tighter than a deck: a bridge has to reach.
const CLOSE_ENOUGH: float = 2.5
const ON_THE_MONEY: float = 0.4
## And how straight, and how central, before she counts as being on the line.
const ON_LINE: float = 2.0
const SQUARE: float = deg_to_rad(12.0)
## Where the forward door is, along the hull from the nose. An airliner's front door is just
## behind the flight deck.
const DOOR_BACK: float = 6.0


var stand: AirportStand = null


func _build_the_place() -> void:
	stand = AirportStand.new()
	stand.name = "Stand"
	add_child(stand)


func _build_the_craft() -> MarshalledCraft:
	var jet := MarshalledCraft.new()
	jet.name = "Airliner"
	add_child(jet)
	jet.fit(Sim.Kind.AIRLINER, AIRLINER)
	# OFF THE TAXIWAY, offset from the lead-in line and waiting to be told this is her
	# stand. Brakes off and engines running: she is taxiing, she has just stopped.
	jet.position = Vector3(14.0, jet.extents.y, AirportStand.ENTRY_Z)
	# Stopped, but NOT parked: she has taxied in off the taxiway and is holding, waiting to
	# be told which stand is hers. The carrier jet starts with its brakes on because it has
	# been sitting on the deck park; this one has been rolling for the last ten minutes.
	jet.brakes_set = false
	jet.engines = true
	return jet


## AHEAD AND TO THE LEFT OF THE NOSE, behind the red safety line, facing the aeroplane. That
## is where a marshaller stands on a real stand and it is not arbitrary: it is the one place
## a captain in the left seat can see over the nose of their own aircraft.
func post_pose() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI),
		Vector3(-10.5, 0.0, AirportStand.STOP_Z - 7.0))


func the_line() -> Vector2:
	return Vector2(AirportStand.LINE_X, AirportStand.STOP_Z)


func _steps() -> Array:
	return [
		{
			"expects": &"identify",
			"tells": "She is waiting for you. Both arms straight up: this is her stand.",
		},
		{
			"expects": &"come_ahead",
			"tells": "Bring her forward and turn her onto the yellow lead-in line. Keep "
				+ "her on it: she is straight when the line runs under her nosewheel.",
			"until": _is_on_the_line,
			"faults": {
				&"cut_engines": "she is nowhere near the stand",
				&"chocks_in": "nobody goes under a moving aeroplane",
			},
		},
		{
			"expects": &"slow_down",
			"tells": "She is coming in fast. Both arms down, patting: slow her right down.",
			"until": func() -> bool: return craft.speed < MarshalledCraft.CREEP + 0.25,
		},
		{
			"expects": &"normal_stop",
			"tells": "Stop her with the nosewheel ON the bar. The bridge has to reach.",
			"until": _is_on_the_bar,
			"then": _write_down_the_stop,
			"faults": {&"chocks_in": "nobody goes under a moving aeroplane"},
		},
		{
			"expects": &"set_brakes",
			"tells": "Brakes on. Left arm down, right hand up and open, then clench it.",
		},
		{
			"expects": &"chocks_in",
			"tells": "Chocks in. Both arms above your head, jabbing inwards until your "
				+ "hands cross.",
		},
		{
			"expects": &"cut_engines",
			"tells": "Cut engines: right hand at your left shoulder, drawn across your "
				+ "throat.",
		},
		{
			"expects": &"all_clear",
			"tells": "All clear. Left arm down, right fist at your chest, thumb up.",
			"does": _bring_the_bridge_on,
			"until": func() -> bool: return stand.has_reached(),
		},
	]


## ---- what the stand asks of the aeroplane --------------------------------------------

func _is_on_the_line() -> bool:
	var nose: Vector3 = craft.nose()
	return absf(nose.x - AirportStand.LINE_X) < ON_LINE \
		and absf(angle_difference(craft.heading(), 0.0)) < SQUARE \
		and nose.z < AirportStand.STOP_Z + 18.0


func _is_on_the_bar() -> bool:
	return not craft.is_rolling() \
		and absf(craft.nose().z - AirportStand.STOP_Z) < CLOSE_ENOUGH \
		and absf(craft.nose().x - AirportStand.LINE_X) < ON_LINE


func _write_down_the_stop() -> void:
	var off: float = absf(craft.nose().z - AirportStand.STOP_Z)
	procedure.marks["on the bar"] = "%.2f m%s" % [off,
		"  (on the money)" if off <= ON_THE_MONEY else ""]
	procedure.marks["off the line"] = "%.2f m" % absf(craft.nose().x
		- AirportStand.LINE_X)


## THE BRIDGE GOES TO THE DOOR, wherever the door actually is. Six metres back from the nose
## and out at the left-hand side of the hull, in the aircraft's own frame -- so it follows
## from where the player stopped her rather than from a number in this file.
func _bring_the_bridge_on() -> void:
	var body: Transform3D = craft.global_transform
	var door: Vector3 = craft.nose() + body.basis.z * DOOR_BACK \
		- body.basis.x * (craft.extents.x + 0.4)
	stand.swing_onto(door)
	_say("Chocks in, engines off, all clear. Bridge coming on.")

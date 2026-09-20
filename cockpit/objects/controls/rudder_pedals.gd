@tool
extends VehicleControl
class_name RudderPedals
## TWO PEDALS ON A BAR, on the floor of the footwell, showing where this seat's rudder is.
##
## Asked for on 2026-09-13: "a floor rudder pedals model and device, that way we can determine where the rudder should
## be". A rudder has had nowhere to show itself but the slider on the console (RudderIndicator, which stays): the
## rudder here comes from twisting the stick, from the right thumbstick, or from Q and E at the desk, and none of those
## looks like a rudder. Pedals are what one looks like, and they are where a USB rudder device will be felt to be when
## there is one -- see `PilotRig.rudder_demand`, which is where its axis will come in.
##
## LEFT PEDAL FORWARD IS LEFT RUDDER, as in every aeroplane: the bar turns about its middle, so one foot goes forward by
## exactly as far as the other comes back, `TRAVEL` at full deflection.
##
## ANNOUNCE, DON'T ACT: THIS SHOWS THE RUDDER AND NEVER DECIDES IT. `show_rudder` is handed a value -- this seat's input
## frame at the player's own seat, the linkage at every other (`FlightLevel._draw_cockpit`) -- and draws it. Nothing
## reads a rudder back off the pedals: the value is kept in a field of its own and not in `value`, so `roll`, `pitch` and
## `rudder` all answer 0 and no sum of controls can count the pedals twice.
##
## A HAND DOES NOT WORK THEM. They are about 1.2 m from a seated shoulder, against the 0.75 m `tests/fit.gd` allows for a
## lean, and the stick's twist and the thumbstick already give a hand the rudder. A hand can pick them up in the builder
## (`offer_hand_to_place`, inherited) and that is all; `under_foot` is what tells the reach check why.
##
## SCOPE SEAT, like the stick: a demand, not a setting on the bus. Fitted by `CockpitStation._fit_the_pedals`.

## HOW FAR EACH PEDAL MOVES at full rudder, in metres, forward for one foot and back for the other.
const TRAVEL: float = 0.08
## CENTRE TO CENTRE, in metres. About where two feet rest with the knees a little apart.
const SPACING: float = 0.24
## HOW FAR THE FACES LEAN BACK towards the pilot, in radians: the angle of a foot resting on the ball.
const RAKE: float = 0.35
## THE FACE of one pedal: width, height, thickness.
const FACE := Vector3(0.09, 0.15, 0.018)
## HOW MUCH CHANGE IS WORTH A REDRAW, as a fraction of full deflection. A tenth of a millimetre of pedal.
const EASE: float = 0.001

## WHAT IS SHOWN, -1 full left to +1 full right, in ControlInput's convention.
var shown: float = 0.0
## EVERY TRANSFORM WRITTEN, counted, so a suite can say that a rudder nobody moves costs nothing. See `tests/pedals.gd`.
var writes: int = 0

var _left: Node3D = null
var _right: Node3D = null
var _bar: MeshInstance3D = null


func label_text() -> String:
	return "RUDDER PEDALS\nSHOW THE RUDDER"


## WORKED BY FEET, which the reach check measures from a shoulder and so must not measure at all.
func under_foot() -> bool:
	return true


## Where the builder's hand takes hold: the middle of the bar, a hand's width off the floor.
func _grab_point() -> Vector3:
	return Vector3(0.0, 0.10, 0.0)


## NOTHING A HAND DOES MOVES THE RUDDER HERE. Only a hand the builder left holding them is let go of, so switching the
## builder off with the pedals in a fist does not weld them to it.
func offer_hand(hand: int, _at: Vector3, grip: float, _facing: Basis = Basis.IDENTITY) -> void:
	if held_by == hand and grip < GRAB_OFF:
		release()


## SHOW A RUDDER, -1 full left to +1 full right. Written only when it has moved by more than `EASE`, because this is
## called every render frame and a rudder at rest is most of them.
func show_rudder(amount: float) -> void:
	var over: float = clampf(amount, -1.0, 1.0)
	if absf(over - shown) < EASE:
		return
	shown = over
	_redraw()


func _build() -> void:
	control_name = "rudder pedals"
	scope = Scope.SEAT
	var dark := Color(0.11, 0.11, 0.13)
	for side in [-1.0, 1.0]:
		var rail := BoxMesh.new()
		rail.size = Vector3(0.03, 0.012, TRAVEL * 2.0 + 0.10)
		_make_mesh(rail, dark, Vector3(side * SPACING * 0.5, 0.006, 0.0))
	_left = _pedal(-1.0)
	_right = _pedal(1.0)
	var tube := BoxMesh.new()
	tube.size = Vector3(SPACING, 0.018, 0.018)
	_bar = _make_mesh(tube, Color(0.50, 0.52, 0.55), Vector3(0.0, 0.03, 0.0))


## ONE PEDAL: a carriage that slides, and a raked face on it. The carriage is what moves, so the rake is written once.
func _pedal(side: float) -> Node3D:
	var carriage := Node3D.new()
	carriage.position = Vector3(side * SPACING * 0.5, 0.012, 0.0)
	add_child(carriage)
	var slab := BoxMesh.new()
	slab.size = FACE
	var face := MeshInstance3D.new()
	face.mesh = slab
	# PALE, because they stand on a floor the colour of everything else in the cockpit: dark faces on it were a pair of
	# slivers the first picture from the seat could barely pick out (tests/pedal_shot.tscn, 2026-09-13).
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.62, 0.64, 0.66)
	paint.roughness = 0.55
	face.material_override = paint
	var lean := Basis(Vector3.RIGHT, RAKE)
	face.transform = Transform3D(lean, lean * Vector3(0.0, FACE.y * 0.5, 0.0))
	carriage.add_child(face)
	return carriage


## THE PEDALS AND THE BAR BETWEEN THEM. -Z is forward: left rudder is negative, so the left pedal's z is `shown * TRAVEL`
## and goes forward, and the right one's is the opposite. The bar turns so both of its ends sit on the pedals, which is
## tan(angle) = 2 * TRAVEL * shown / SPACING, stretched by 1 / cos(angle) so it still reaches them.
func _redraw() -> void:
	if _left == null:
		return
	_left.position.z = shown * TRAVEL
	_right.position.z = -shown * TRAVEL
	var turned: float = atan(2.0 * TRAVEL * shown / SPACING)
	_bar.transform = Transform3D(Basis(Vector3.UP, turned).scaled_local(Vector3(1.0 / cos(turned), 1.0, 1.0)),
		Vector3(0.0, 0.03, 0.0))
	writes += 3

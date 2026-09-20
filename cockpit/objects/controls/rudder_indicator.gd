@tool
extends Node3D
class_name RudderIndicator
## WHERE THE RUDDER IS, on the console in front of every seat.
##
## A rudder has nowhere else to show itself. A stick's position is its own display -- you
## can see how far over it is -- but rudder here comes from twisting the grip, and a twisted
## grip on a leaning column is very nearly invisible from the pilot's own eye position, let
## alone from the seat beside it. So it gets an instrument.
##
## A slider rather than a needle, because that is what the control does: it runs left and
## right off a centre mark and returns there when you let go.
##
## NOT a VehicleControl. Nothing grabs it, it has no value of its own, and it shows the
## LINKAGE -- which is to say what the aeroplane is actually being given, from whichever
## seat is flying. See CrewControls.

## How wide the track is, in metres, from hard left to hard right.
const TRACK: float = 0.16

var _marker: MeshInstance3D = null
var _paint: StandardMaterial3D = null


func _ready() -> void:
	var dull := StandardMaterial3D.new()
	dull.albedo_color = Color(0.09, 0.10, 0.12)
	dull.roughness = 0.9
	var slot := BoxMesh.new()
	slot.size = Vector3(TRACK + 0.03, 0.006, 0.022)
	var track := MeshInstance3D.new()
	track.mesh = slot
	track.material_override = dull
	add_child(track)

	# The centre mark, so "not deflected" is a place and not merely the middle of a gap.
	var notch := BoxMesh.new()
	notch.size = Vector3(0.004, 0.004, 0.030)
	var centre := MeshInstance3D.new()
	centre.mesh = notch
	var pale := StandardMaterial3D.new()
	pale.albedo_color = Color(0.55, 0.57, 0.60)
	centre.material_override = pale
	centre.position = Vector3(0.0, 0.004, 0.0)
	add_child(centre)

	var block := BoxMesh.new()
	block.size = Vector3(0.020, 0.014, 0.028)
	_marker = MeshInstance3D.new()
	_marker.mesh = block
	_paint = StandardMaterial3D.new()
	_paint.albedo_color = Color(0.35, 0.80, 0.45)
	_paint.emission_enabled = true
	_paint.emission = Color(0.20, 0.70, 0.30)
	_paint.emission_energy_multiplier = 0.8
	_marker.material_override = _paint
	_marker.position = Vector3(0.0, 0.008, 0.0)
	add_child(_marker)


## Show a deflection, -1 hard left to +1 hard right.
func show_rudder(amount: float) -> void:
	if _marker == null:
		return
	var over: float = clampf(amount, -1.0, 1.0)
	_marker.position = Vector3(over * TRACK * 0.5, 0.008, 0.0)
	# Brighter the further it is over, so a boot resting on the rudder is noticeable from
	# the corner of an eye rather than only when looked at.
	_paint.emission_energy_multiplier = 0.5 + absf(over) * 2.0


## WHAT IT IS SHOWING, read off the marker itself rather than off a number kept beside it.
##
## One number, one place: a remembered copy of the last `show_rudder` would agree with the picture
## right up until something else moved the marker, and the whole point of asking is to find out
## what is DRAWN. Only a test asks -- see tests/crew_sync.gd, which reads the indicator at one seat
## while another seat's feet are on the pedals.
func shown() -> float:
	return 0.0 if _marker == null else _marker.position.x / (TRACK * 0.5)

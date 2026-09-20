@tool
extends ThrottleLever
class_name BrakeLever
## THE BRAKE HANDLE beside a locomotive's regulator.
##
## Mechanically a throttle lever -- one latched axis, pushed along a quadrant -- and it
## feeds a completely different thing, which is the only reason it is its own class. A
## locomotive has two levers and no stick, and giving it a stick that did nothing would be
## a control lying about what the machine underneath it can do.
##
## Latched, like the regulator. A train brake is applied and stays applied, and a driver who
## wants it off puts it off. Half a kilometre of stopping distance is not something to be
## holding down.


func _build() -> void:
	super()
	control_name = "brake"
	scope = Scope.SEAT
	# Red, because everything else on this console is not.
	_tint(_knob, Color(0.78, 0.22, 0.18))


## WHAT IT ACTUALLY DOES. The base class reads `value.y` as an opening, and this lever is
## not one.
func brake() -> float:
	return clampf(value.y, 0.0, 1.0)


func throttle() -> float:
	return 0.0

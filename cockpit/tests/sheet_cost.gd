extends Node

## WHAT IT COSTS TO DRESS AN AEROPLANE, because nothing else here measures that and a three-second airframe hid
## behind twelve green suites.
##
## THE INCIDENT THIS EXISTS FOR. `lane/phantom` gave the F-4 a weathering sheet baked in GDScript: 512 x 256 texels,
## each walking a list of eight marks TWICE. Dressing one Phantom went from 6.9 ms to **2,951 ms**, and it was paid
## again for every Phantom built, because the sheet was baked per airframe when every F-4 wears the same dirt.
##
## **NOTHING WENT RED.** `phantom`, `phantom_wear`, `screens_face`, `shell_room`, `stations`, `joined_parts`,
## `vehicle_gym` and the rest all passed: a slow airframe is a correct airframe. The cost did not reach anybody until
## the kind got its `Terrain.spawns` row and the world began building Phantoms, and then it surfaced two suites away
## as `no_vr_flight` TIMING OUT WITH NO ERROR PRINTED -- a failure whose message said "seat 0 -> 0" and named neither
## the aeroplane nor the sheet. The fix was a one-pass bake and a static texture shared by every Phantom.
##
## SO THIS SUITE HOLDS THE THING THE OTHERS CANNOT SEE: that building an aeroplane is cheap, and that building a
## SECOND one of the same kind is nearly free. The second is the one that matters -- a per-instance bake passes any
## check that only ever builds one.

## What dressing the first aeroplane of a kind may cost. Generous: it includes whatever one-off work a kind does,
## and the point is to catch three seconds, not to police three hundred milliseconds.
const FIRST_MOST_MS: float = 900.0
## And what the SECOND must cost, once anything shared has been built. This is the real guard.
const AGAIN_MOST_MS: float = 60.0

var _failures: PackedStringArray = []


func _ready() -> void:
	var first: float = _dress()
	var again: float = _dress()
	print("[sheet_cost] dressing an F-4E: first %.1f ms, again %.1f ms" % [first, again])
	_check("dressing_the_first_aeroplane_of_a_kind_is_not_slow", first <= FIRST_MOST_MS,
		"%.1f ms, most %.1f" % [first, FIRST_MOST_MS])
	# THE ONE THAT CATCHES A PER-INSTANCE BAKE. A sheet built for each aeroplane costs the same every time, so the
	# second dress reads like the first; shared, it is the cost of the mesh alone.
	_check("and_the_next_one_of_that_kind_is_nearly_free", again <= AGAIN_MOST_MS,
		"%.1f ms, most %.1f" % [again, AGAIN_MOST_MS])
	if _failures.is_empty():
		print("RESULT=PASS 2 checks")
	else:
		print("RESULT=FAIL %s" % [_failures])
	get_tree().quit(0 if _failures.is_empty() else 1)


## HOW LONG ONE F-4E TAKES TO BUILD, in milliseconds, through the real `dress` a level calls.
func _dress() -> float:
	var at: int = Time.get_ticks_usec()
	var frame := PhantomAirframe.new()
	frame.dress()
	var took: float = float(Time.get_ticks_usec() - at) / 1000.0
	frame.queue_free()
	return took


func _check(label: String, held: bool, said: String) -> void:
	print("[sheet_cost] %s %s (%s)" % ["PASS" if held else "FAIL", label, said])
	if not held:
		_failures.append(label)

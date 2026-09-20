extends "res://tests/crowd_sight.gd"
## PROBE: the crowded sky over a link that delivers in lumps. Numbers, no verdict.
##
##   Godot --path addon --headless res://tests/crowd_lumpy.tscn
##
## `crowd_sight`'s skies with the packets held until every third tick, as a real socket bunches them, with and without
## the gunships firing. On 4e76324 with the budget at 245 kB/s the whole sky still steps exactly one tick of travel
## together on about 275 of 1,200 ticks (18,856 steps; 19,523 firing), and it did the same at 1,024 and at 1,200
## bytes a tick, so it is not the budget. The interpolation lag moved twice in the watch (2 of 275 steps on a change)
## and the buffered frame advanced by exactly one on 1,197 of 1,199 ticks (3 of 275 steps near the other two), so it
## is not the lag or the clock either. What is left is how bunched records land against sync's gap fill; see
## cockpit/agents.md, WHAT IS NOT HERE YET. It moves to crowd_sight when it can pass.
##
## Every check still prints PASS or FAIL so the numbers read the same as the suite's, but the probe's own RESULT= is
## PROBE and it exits 0: nothing here is a verdict until the cause is known.


func _plans() -> Array:
	return [["a_crowded_sky_over_a_lumpy_link", CROWD, 4, 3, 0],
		["a_crowded_sky_under_fire_over_a_lumpy_link", CROWD, 4, 3, 3]]


func _finish() -> void:
	print("RESULT=PROBE %d of the suite's checks would fail: %s" % [_failures.size(), ", ".join(_failures)])
	get_tree().quit(0)

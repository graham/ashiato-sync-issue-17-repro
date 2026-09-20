extends Node
## Headless: DOES A MOUNTAIN BLOCK A SIGHT LINE, AND DOES OPEN AIR NOT?
##
##   Godot --headless --path cockpit res://tests/sight_line.tscn
##
## `SightLine` is the one function that decides whether flying low through a canyon hides you from radar
## (`world/radar_set.gd`), and `lane/rivers` is cutting the canyons. Two lanes, one question, so it is worth holding
## the answer down hard.
##
## IT IS A BARE WORLD WITH THE ISLAND'S MOUNTAINS IN IT AND NOTHING ELSE -- no session, no level, no craft, as
## `tests/mountains.gd` builds one. The question is about rock and a ray, and standing a whole level up to ask it
## would make this slow and make a failure ambiguous.
##
## WHAT IT HOLDS:
##
##   1. **A PEAK BLOCKS A LINE DRAWN THROUGH IT.** The test finds a real summit from the island's own pyramid rather
##      than trusting a typed coordinate, then draws a line between two points either side of it, BELOW its top. If
##      this passes with the rock removed, it is measuring nothing -- so it is also run against a world with NO
##      mountains, where the same line must be clear. That pair is the check; neither half alone is one.
##   2. **OPEN AIR IS CLEAR.** The same two points, raised above the peak, see each other. Without this, "everything
##      is blocked" would pass check 1 perfectly.
##   3. **THE BIAS IS THE ONE THE DOC BLOCK CLAIMS.** `height_pyramid.hpp` says it may call a clear leg blocked and
##      never the other way, which read as sight means it may hide a visible contact and never reveal a hidden one.
##      Held by sweeping the line's height up through the peak and requiring the answer to change from blocked to
##      clear EXACTLY ONCE -- monotone. A sensor that flickered between hidden and seen as a contact climbed would
##      make a nonsense of concealment, and it is the property a second, hand-rolled sampler would most likely lose.
##   4. **LIFTING THE EYE IS WHAT PUTS AN AERIAL ON A MAST**, which is what `is_clear_from_height` is for: the same
##      blocked line clears once, and stays clear, as only the eye is raised. The first version of this check asserted
##      that a line 40 m up over "open sea" was clear and FAILED, because the island's ranges stand along it -- a
##      check whose premise is "there is no rock here" has to establish that, and it could not.
##   5. **NO WORLD, OR A WORLD WITH NO SUCH METHOD, IS CLEAR** -- the documented fail-open, so a level with no
##      terrain built conceals nothing rather than going silently blind.
##
## Read RESULT=, not the exit code.

## How far either side of the summit the two ends of the blocked line stand, metres. Well outside the peak itself so
## the line genuinely crosses it rather than starting inside the rock.
const ACROSS: float = 2500.0
## How far BELOW the summit both ends sit for the blocked case.
const BELOW: float = 300.0
## The step the monotone sweep climbs in, metres, and how far above the summit it goes.
const RUNG: float = 25.0
const OVER: float = 900.0

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[sight_line] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var exists: bool = ClassDB.class_exists(&"MountainRange") and ClassDB.class_has_method(&"CockpitWorld", &"set_mountains")
	_check("the_extension_has_mountains", exists, "engine %s, double=%s"
		% [Engine.get_version_info()["string"], OS.has_feature("double")])
	if not exists:
		_finish()
		return

	var island: Object = ClassDB.instantiate(&"MountainRange")
	island.call("configure", Terrain.mountain_values())
	var rocky: Object = _a_world_with(island)
	var empty: Object = _a_world_with(null)

	# THE SUMMIT IS FOUND, NOT TYPED. `highest_over` is the pyramid's own answer, so the peak this test aims at is
	# wherever the island's rock actually is -- a range moved by a change to MountainRanges moves this test with it
	# instead of leaving it drawing lines through open sky and passing.
	var summit: Dictionary = _the_highest_place(island)
	_check("a_summit_was_found_to_aim_at", summit.get("height", 0.0) > 400.0,
		"%.0f m at %s" % [summit.get("height", 0.0), summit.get("at", Vector3.ZERO)])
	if float(summit.get("height", 0.0)) <= 400.0:
		_finish()
		return
	var at: Vector3 = summit["at"]
	var top: float = float(summit["height"])
	# ACROSS THE PEAK ALONG X, both ends below its top.
	var west := Vector3(at.x - ACROSS, top - BELOW, at.z)
	var east := Vector3(at.x + ACROSS, top - BELOW, at.z)

	# ---- 1. the rock blocks it, AND the same line is clear without the rock ---------------------
	var blocked: bool = not SightLine.is_clear(rocky, west, east)
	_check("a_line_through_a_peak_is_blocked", blocked,
		"%.0f m line at %.0f m, %.0f m under a %.0f m summit" % [west.distance_to(east), west.y, BELOW, top])
	# THE CONTROL, and it is not optional: without it "blocked" might mean the query refuses everything.
	_check("and_the_same_line_is_clear_with_the_rock_taken_away", SightLine.is_clear(empty, west, east),
		"the identical line in a world with no mountains")

	# ---- 2. open air over the top is clear ------------------------------------------------------
	var high_west := Vector3(west.x, top + OVER, west.z)
	var high_east := Vector3(east.x, top + OVER, east.z)
	_check("a_line_well_over_the_peak_is_clear", SightLine.is_clear(rocky, high_west, high_east),
		"both ends %.0f m above the summit" % OVER)

	# ---- 3. it changes its mind exactly once, going up ------------------------------------------
	var flips: int = 0
	var was: bool = SightLine.is_clear(rocky, Vector3(west.x, top - BELOW, west.z),
		Vector3(east.x, top - BELOW, east.z))
	var first_clear: float = -1.0
	var rungs: int = 0
	var height: float = top - BELOW
	while height <= top + OVER:
		var now: bool = SightLine.is_clear(rocky, Vector3(west.x, height, west.z), Vector3(east.x, height, east.z))
		rungs += 1
		if now != was:
			flips += 1
			if now and first_clear < 0.0:
				first_clear = height
		was = now
		height += RUNG
	_check("it_goes_from_blocked_to_clear_once_and_never_back", flips == 1 and was,
		"%d change(s) over %d rungs, first clear at %.0f m (summit %.0f m), ends %s"
			% [flips, rungs, first_clear, top, "clear" if was else "BLOCKED"])
	# AND IT CLEARS AT OR ABOVE THE SUMMIT, never below it: that is the "never calls a hidden contact visible" half of
	# the bias, stated as a height. The pyramid rounds up to whole metres over 32 m squares, so it may clear LATE.
	_check("and_never_clears_below_the_rock_it_is_looking_through", first_clear >= top - 1.0,
		"cleared at %.0f m against a summit of %.0f m" % [first_clear, top])

	# ---- 4. lifting the eye is what puts an aerial on a mast ------------------------------------
	# THE FIRST VERSION OF THIS CHECK WAS WRONG AND THE SUITE CAUGHT IT. It drew a line 40 m up from the origin out to
	# 6 km, called that "open sea", and asserted it was clear; it is not, because the island's ranges stand along it.
	# A check whose premise is "there is no rock here" has to ESTABLISH that there is no rock here, and this one could
	# not. So it now asks the only thing `is_clear_from_height` actually promises -- that the height is added to the
	# EYE -- against the peak already found, where the geometry is known because check 1 measured it.
	#
	# Both ends start below the summit and blocked. Raising only the eye must clear it, exactly once, and never
	# un-clear it: the line's height over the peak is the mean of its ends, so it passes the rock when the eye is
	# about `BELOW` above the top and the far end is still `BELOW` under it.
	var lift_flips: int = 0
	var first_lift: float = -1.0
	var seen: bool = SightLine.is_clear_from_height(rocky, west, east, 0.0)
	_check("with_no_lift_at_all_it_is_the_same_answer_as_a_plain_line", seen == SightLine.is_clear(rocky, west, east),
		"lift 0 gave %s, plain gave %s" % [seen, SightLine.is_clear(rocky, west, east)])
	var lift: float = 0.0
	while lift <= BELOW + OVER:
		var now: bool = SightLine.is_clear_from_height(rocky, west, east, lift)
		if now != seen:
			lift_flips += 1
			if now and first_lift < 0.0:
				first_lift = lift
		seen = now
		lift += RUNG
	_check("lifting_only_the_eye_clears_the_line_once_and_keeps_it_clear", lift_flips == 1 and seen,
		"%d change(s), first clear at a %.0f m eye over a %.0f m summit, ends %s"
			% [lift_flips, first_lift, top, "clear" if seen else "BLOCKED"])

	# ---- 5. the documented fail-open ------------------------------------------------------------
	_check("no_world_is_clear_rather_than_blind", SightLine.is_clear(null, west, east), "null world")
	_check("and_a_world_that_cannot_answer_is_clear_too", SightLine.is_clear(RefCounted.new(), west, east),
		"an object with no ground_leg_is_clear")

	_finish()


## A WORLD WITH THOSE MOUNTAINS IN IT AND NOTHING ELSE, as `tests/mountains.gd` builds one. `mountains` may be null,
## which is the control world.
func _a_world_with(mountains: Object) -> Object:
	var world: Object = ClassDB.instantiate(&"CockpitWorld")
	world.set_tick_rate(120)
	world.start(1)
	if mountains != null:
		world.set_mountains(mountains)
	return world


## THE HIGHEST PLACE THE ISLAND'S ROCK REACHES, and where, found by asking the range's own `highest_over` over a grid
## rather than by reading a coordinate out of `MountainRanges`. Coarse on purpose: this only has to land somewhere on
## a big massif, and the checks above re-measure the exact summit height at the point they use.
func _the_highest_place(island: Object) -> Dictionary:
	var best: float = -INF
	var where := Vector3.ZERO
	var step: float = 500.0
	var reach: float = 12000.0
	var x: float = -reach
	while x <= reach:
		var z: float = -reach
		while z <= reach:
			var high: float = float(island.call("highest_over", x - step, z - step, x + step, z + step))
			if high > best:
				best = high
				where = Vector3(x, 0.0, z)
			z += step
		x += step
	# THE SUMMIT AT THAT SPOT, asked tightly, so the height the checks use is the rock actually under the line rather
	# than the highest rock within half a kilometre of it.
	var tight: float = float(island.call("highest_over", where.x - 60.0, where.z - 60.0, where.x + 60.0, where.z + 60.0))
	return {"at": where, "height": tight}


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)

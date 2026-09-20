extends Node
## THE GORGE: A RIVER IN A CANYON DEEP ENOUGH TO HIDE A FIGHTER, MEASURED (lane/rivers, 2026-09-20).
##
##   Godot --headless --path cockpit res://tests/canyon.tscn
##
## The user asked for "some deep 200-300 metres that have a river in them (50m wide) and a high mountain on both sides
## so we can fly through them", and said why: "river canyons are often something that fighter planes will use to
## conceal their location". So this does not check that a canyon was built. It checks the four things that sentence
## asks for, each as a number:
##
##   THE RIVER IS THE WIDTH THE LEVEL ASKED FOR, water standing across it and none standing outside it.
##   THE WATER RUNS DOWNHILL from its head to its mouth and never climbs.
##   THE CANYON IS AS DEEP AS THE LEVEL ASKED, measured from the water to the rim, ON BOTH SIDES -- a wall on one side
##     and open ground on the other is a cliff, not a canyon, and would pass any check that took the higher of the two.
##   THE FLOOR IS FLYABLE: nothing stands in the corridor above the water.
##   AND A FIGHTER ON THE FLOOR IS HIDDEN, which is the stated point of the whole feature and the one thing that could
##     have been assumed. See below.
##
## WHAT "HIDDEN" MEANS HERE, AND WHY IT IS THIS. There is no radar in the game yet -- that is `lane/flatcrew`'s -- and
## nothing in the AI asks whether it can see a thing. So the only honest measurement is the geometric one radar and any
## future sight test would both rest on: from an observer at a bearing, a range and a height, does the straight line to
## the craft meet the ground first? That is marched against `Terrain.ground_height`, which on a generated ground with a
## level's ranges takes the higher of the ground and the rock, so the canyon's own walls are in it.
##
## THIS CHECK CAN FAIL, and it was made to fail before it was trusted: the same observers are asked about a craft at
## the SAME PLACE AND THE SAME HEIGHT ABOVE THE GROUND out on the open farmland away from the canyon, and that one has
## to be SEEN. A concealment check that does not also prove the open ground is visible is a check that the ray marcher
## is broken.
##
## Read RESULT=, not the exit code.

const LEVEL: String = "canyon"
## Where along each leg of the river the measurements are taken, metres.
const STATION: float = 200.0
## What share of the bank samples may be wet just outside the river's stated width: see `_the_river_is_the_width...`.
const BEND_WIDER_SHARE: float = 0.02
## How far out to either side the rim is looked for, as a multiple of the wall's offset: a little past the ridge, so a
## wall that stands where `Watercourse` puts it is found and one that does not is missed.
const RIM_REACH: float = 1.35
## How much of the depth the level asked for a station must actually have, either side. Not 1.0: the ridge carries
## noise inside its envelope and a saddle between two control points stands lower than its crest.
const DEPTH_SHARE: float = 0.70
## AND WHAT SHARE OF STATIONS MAY BE UNDER IT. Not none: the walls taper at the river's head and its mouth, because a
## `MountainRange` ridge ends at its last control point and no overrun makes that taper vanish -- it only moves it. On
## the gorge that is 3 stations of 80, at 158, 165 and 171 m of a 260 m ask. The MEAN is held to the full depth
## separately, so a canyon that got shallower everywhere could not hide behind this allowance.
const DEPTH_SHORT_SHARE: float = 0.08
## How far above the water a fighter flies down the canyon, metres, and how much room the corridor must have.
const FLY_HEIGHT: float = 60.0
const FLOOR_CLEAR: float = 30.0
## How far inside the corridor's edge the floor is measured, metres: see `_the_floor_is_flyable`.
const FLOOR_INSIDE: float = 15.0
## The observers: how far out, on how many bearings, and at what heights above the canyon's own rim.
const OBSERVER_RANGE: float = 6000.0
const OBSERVER_BEARINGS: int = 12
## The heights an observer is put at over the canyon's rim, and how many of them concealment is REQUIRED at. A canyon
## 260 m deep and 220 m wide cannot hide a craft from an eye directly over it, and no canyon ever has: what it gives
## is cover from a shallow look angle. At 6 km out, 200 m over the rim is a 2 degree look-down and 800 m is 8; 2,000 m
## is 18 degrees and is measured and REPORTED rather than required, so the angle where cover stops is a number in the
## log instead of an assumption in somebody's head.
## THE HEIGHT THE REQUIRED MEASUREMENT IS TAKEN AT, metres over the rim, and the sweep that finds where cover stops.
## At 6 km out, 800 m is 7.6 degrees of look-down; the sweep doubles from 200 m to 3,200 m.
const OVER_RIM_REQUIRED_M: float = 800.0
const OVER_RIM_FROM: float = 200.0
const OVER_RIM_TO: float = 3200.0
## What share of the run must be concealed from an abeam observer at the required height, and the share of sight lines
## that counts as cover having been lost during the sweep.
const HIDDEN_SHARE: float = 0.98
const COVER_LOST_AT: float = 0.25
## THE CONTROL: how far from the canyon the same craft is put on open ground, metres, and what share of the observers
## must see it there. Not all of them -- this world has 900 m ranges in it and some bearings are behind a hill, which
## is the terrain being terrain. What the share is for is to catch a ray marcher that reports everything as blocked,
## and that one would score nothing at all.
const OPEN_GROUND_AWAY: float = 5000.0
const OPEN_GROUND_SEEN: float = 0.35
## HOW FAR OFF THE RIVER'S OWN AXIS AN OBSERVER COUNTS AS ABEAM, degrees. A canyon hides a craft from the side; it
## cannot hide one from an observer looking straight down its length, and no canyon ever has. Demanding that all
## twelve bearings be blocked was asking the geometry for something impossible, and the honest measurement is the one
## below: every abeam observer blocked, and the axial ones counted and reported rather than pretended about.
const ABEAM_WITHIN: float = 50.0

var _failures: PackedStringArray = []
var _field: Object = null
var _river: Dictionary = {}


func _check(label: String, ok: bool, detail: String) -> void:
	print("[canyon] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	ChartDrawer.open_at(ChartDrawer.FOLDER)
	var chart: LevelChart = ChartDrawer.chart(LEVEL)
	if chart == null or chart.rivers.is_empty():
		_check("the_level_lays_a_river", false, "no chart for '%s', or it lays none" % LEVEL)
		_finish()
		return
	_river = chart.rivers[0]
	_field = ClassDB.instantiate(&"GroundField")
	var problems: PackedStringArray = _field.call("configure", GroundTuning.for_level(chart))
	_check("the_ground_takes_the_levels_river", problems.is_empty(), "%s" % [problems])
	if not problems.is_empty():
		_finish()
		return
	Terrain.stand_on(_field, LEVEL)
	var walls: Array[Dictionary] = Watercourse.ranges_for(chart.rivers, _field)
	print("[canyon] corridor_half=%d wall_offset=%d depth=%d; %d walls"
		% [Watercourse.corridor_half(_river), Watercourse.wall_offset(_river), Watercourse.depth_of(_river), walls.size()])
	var rock: Object = Terrain.mountains()
	print("[canyon] %d walls, %d keep-out boxes, %s tiles of rock" % [walls.size(),
		Watercourse.keepouts_for(chart.rivers, _field).size() / 5,
		rock.call("tile_count") if rock != null else "no"])
	var stations: Array[Dictionary] = _stations()
	_check("there_are_stations_down_the_river", stations.size() >= 20, "%d" % stations.size())
	if stations.size() < 20:
		_finish()
		return
	_the_river_is_the_width_asked_for(stations)
	_the_water_runs_downhill(stations)
	_the_canyon_is_deep_on_both_sides(stations)
	_the_floor_is_flyable(stations)
	_a_fighter_on_the_floor_is_hidden(stations)
	_finish()


## EVERY STATION DOWN THE RIVER: where it is, which way it runs, and the water's level there.
func _stations() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var points: Array = _river["points"]
	for k in range(points.size() - 1):
		var a := Vector2(float(int(points[k][0])), float(int(points[k][1])))
		var b := Vector2(float(int(points[k + 1][0])), float(int(points[k + 1][1])))
		var legs: int = maxi(int(a.distance_to(b) / STATION), 1)
		var along: Vector2 = (b - a).normalized()
		for s in range(legs):
			var at: Vector2 = a.lerp(b, float(s) / float(legs))
			var water: float = Watercourse.water_level_at(_field, int(round(at.x)), int(round(at.y)))
			if is_nan(water):
				continue
			out.append({"at": at, "along": along, "across": Vector2(-along.y, along.x), "water": water})
	return out


## The ground as the simulation has it at a point: the higher of the generated ground and the level's rock.
func _ground(at: Vector2) -> float:
	return Terrain.ground_height(Vector3(at.x, 0.0, at.y))


func _the_river_is_the_width_asked_for(stations: Array[Dictionary]) -> void:
	var half: float = float(int(_river.get("width", Watercourse.WIDTH_DEFAULT))) * 0.5
	var dry_inside: int = 0
	var wet_outside: int = 0
	for one in stations:
		var station: Dictionary = one
		var at: Vector2 = station["at"]
		var across: Vector2 = station["across"]
		# A METRE INSIDE EACH BANK MUST BE WATER, and three metres outside must not be. Measured off the bank rather
		# than at it, because the bank is where the answer changes and a check taken exactly there measures rounding.
		for side in [-1.0, 1.0]:
			if is_nan(Watercourse.water_level_at(_field, int(round((at + across * (side * (half - 1.0))).x)),
					int(round((at + across * (side * (half - 1.0))).y)))):
				dry_inside += 1
			if not is_nan(Watercourse.water_level_at(_field, int(round((at + across * (side * (half + 3.0))).x)),
					int(round((at + across * (side * (half + 3.0))).y)))):
				wet_outside += 1
	# DRY INSIDE A BANK IS NEVER ALLOWED -- that is a hole in the river. WET OUTSIDE ONE IS, a little: the water's edge
	# is the distance to the NEAREST leg, so on the outside of a bend the two legs' water overlaps and the river is
	# genuinely a shade wider there, which is what a river does at a bend. One station in 152 on the gorge.
	var wet_share: float = float(wet_outside) / float(stations.size() * 2)
	_check("the_river_is_the_%d_m_the_level_asked_for" % int(half * 2.0),
		dry_inside == 0 and wet_share <= BEND_WIDER_SHARE,
		"%d of %d bank samples are dry inside the water, and %d (%.1f %%, allowed %.1f %%) are wet %.0f m outside it"
			% [dry_inside, stations.size() * 2, wet_outside, wet_share * 100.0, BEND_WIDER_SHARE * 100.0, 3.0])


func _the_water_runs_downhill(stations: Array[Dictionary]) -> void:
	var climbs: int = 0
	var worst: float = 0.0
	for k in range(1, stations.size()):
		var rise: float = float(stations[k]["water"]) - float(stations[k - 1]["water"])
		if rise > 0.0:
			climbs += 1
			worst = maxf(worst, rise)
	_check("the_water_runs_downhill_and_never_up", climbs == 0,
		"%d of %d stations climb, the worst by %.3f m; it falls %.1f m from head to mouth"
			% [climbs, stations.size() - 1, worst, float(stations[0]["water"]) - float(stations[-1]["water"])])


## THE RIM EITHER SIDE, and the depth is the LOWER of the two. A wall on one side only is a cliff.
func _the_canyon_is_deep_on_both_sides(stations: Array[Dictionary]) -> void:
	var asked: float = float(Watercourse.depth_of(_river))
	var want: float = asked * DEPTH_SHARE
	var reach: float = float(Watercourse.wall_offset(_river)) * RIM_REACH
	var shallow: Array[String] = []
	var least: float = INF
	var total: float = 0.0
	for one in stations:
		var station: Dictionary = one
		var at: Vector2 = station["at"]
		var across: Vector2 = station["across"]
		var water: float = station["water"]
		var both: float = INF
		for side in [-1.0, 1.0]:
			var rim: float = -INF
			var out: float = float(Watercourse.corridor_half(_river))
			while out <= reach:
				rim = maxf(rim, _ground(at + across * (side * out)))
				out += 24.0
			both = minf(both, rim - water)
		least = minf(least, both)
		total += both
		if both < want:
			shallow.append("(%.0f, %.0f) %.0f m" % [at.x, at.y, both])
	var mean: float = total / float(stations.size())
	var short_share: float = float(shallow.size()) / float(stations.size())
	_check("the_canyon_is_%d_m_deep_on_both_sides" % int(asked),
		mean >= asked and short_share <= DEPTH_SHORT_SHARE,
		("asked %.0f m; the MEAN rim over the water is %.0f m either side, and %d of %d stations (%.1f %%, allowed "
			+ "%.1f %%) are under %.0f m. The shallowest is %.0f m. Short: %s")
			% [asked, mean, shallow.size(), stations.size(), short_share * 100.0, DEPTH_SHORT_SHARE * 100.0, want,
				least, shallow.slice(0, 5)])


func _the_floor_is_flyable(stations: Array[Dictionary]) -> void:
	# STRICTLY INSIDE THE CORRIDOR. The carve stops AT the corridor, so the natural hillside still stands at its very
	# edge and the walls rise from there -- which is what a canyon is. What a pilot needs is the floor, and the floor is
	# what is inside.
	var half: float = float(Watercourse.corridor_half(_river)) - FLOOR_INSIDE
	var blocked: Array[String] = []
	var worst: float = -INF
	for one in stations:
		var station: Dictionary = one
		var at: Vector2 = station["at"]
		var across: Vector2 = station["across"]
		var water: float = station["water"]
		var out: float = -half
		while out <= half:
			var over: float = _ground(at + across * out) - water
			worst = maxf(worst, over)
			if over > FLOOR_CLEAR:
				blocked.append("(%.0f, %.0f) at %.0f m across stands %.1f m over the water" % [at.x, at.y, out, over])
				break
			out += 12.0
	_check("the_floor_is_clear_to_fly_down", blocked.is_empty(),
		"the highest thing in the %.0f m corridor stands %.1f m over the water, allowed %.0f m; blocked: %s"
			% [half * 2.0, worst, FLOOR_CLEAR, blocked.slice(0, 4)])


## A FIGHTER FLOWN DOWN THE CANYON IS HIDDEN, ASKED OF THE GAME'S OWN SIGHT (`SightLine`, lane/flatcrew, 2026-09-20).
##
## THE FIRST VERSION OF THIS CHECK MARCHED ITS OWN RAY against `Terrain.ground_height` every 20 m, because a survey of
## this project for `line_of_sight`, `can_see` and `occlu` found nothing. **Two lanes made that survey the same night
## and both were wrong the same way:** `CockpitWorld.ground_leg_is_clear` has answered exactly this since the
## generated ground landed, over both grounds through one shared max-pyramid, and it is named for a FLIGHT LEG because
## the autopilots needed it first. A hand-rolled sampler is slower, coarser, and -- worst -- a second opinion about
## where the ground is, so a canyon could have hidden you from this test and not from radar.
##
## SO THE QUESTION IS ASKED OF THE AUTHORITY, and the answer means what radar means. The bias is stated in
## `sight_line.gd` and is one-directional: the pyramid may call a CLEAR line blocked and never a blocked one clear, at
## the grain of a 32 m square. Read as concealment that is the right way round -- terrain conceals slightly MORE than
## geometry alone -- so a canyon that measures concealed here cannot be exposed in the game by a rounding.
##
## AND IT IS THE WHOLE RUN, NOT ONE POINT. A fighter is flown down every station of the river at `FLY_HEIGHT` over the
## water and each is asked of every abeam observer, so the number is the share of the RUN that is concealed rather
## than the luck of one place. Then the observers are raised until cover fails, and that height is reported: a canyon
## does not hide you from directly above and never has, and the useful fact is the angle at which it stops.
func _a_fighter_on_the_floor_is_hidden(stations: Array[Dictionary]) -> void:
	var world: Object = _sighting_world()
	if world == null:
		_check("there_is_a_world_to_ask_about_sight", false, "no CockpitWorld with set_ground")
		return
	var rim: float = float(stations[stations.size() / 2]["water"]) + float(Watercourse.depth_of(_river))
	var middle: Vector2 = stations[stations.size() / 2]["at"]
	var along: Vector2 = stations[stations.size() / 2]["along"]
	# THE OBSERVERS: abeam ones, whose bearing is off the canyon's axis, and axial ones looking down its length.
	var abeam: Array[Vector2] = []
	var axial: Array[Vector2] = []
	for b in range(OBSERVER_BEARINGS):
		var bearing: float = TAU * float(b) / float(OBSERVER_BEARINGS)
		var out := Vector2(cos(bearing), sin(bearing)) * OBSERVER_RANGE
		if rad_to_deg(acos(clampf(absf(out.normalized().dot(along)), 0.0, 1.0))) >= ABEAM_WITHIN:
			abeam.append(out)
		else:
			axial.append(out)
	var seen_abeam: int = 0
	var seen_axial: int = 0
	var tried_abeam: int = 0
	var tried_axial: int = 0
	var worst: Array[String] = []
	for one in stations:
		var station: Dictionary = one
		var at: Vector2 = station["at"]
		var craft := Vector3(at.x, float(station["water"]) + FLY_HEIGHT, at.y)
		for out in abeam:
			tried_abeam += 1
			var eye := Vector3(middle.x + out.x, rim + OVER_RIM_REQUIRED_M, middle.y + out.y)
			if SightLine.is_clear(world, eye, craft):
				seen_abeam += 1
				if worst.size() < 5:
					worst.append("(%.0f, %.0f)" % [at.x, at.y])
		for out in axial:
			tried_axial += 1
			var eye := Vector3(middle.x + out.x, rim + OVER_RIM_REQUIRED_M, middle.y + out.y)
			if SightLine.is_clear(world, eye, craft):
				seen_axial += 1
	var hidden: float = 1.0 - float(seen_abeam) / float(maxi(tried_abeam, 1))
	_check("a_fighter_flown_down_the_canyon_is_hidden_from_abeam", hidden >= HIDDEN_SHARE,
		("%.1f %% of the run is concealed from %d abeam observers %.0f m out and %.0f m over the rim (%.1f degrees "
			+ "of look-down), wanted %.0f %%; %d of %d sight lines are clear. Down the canyon's axis %d of %d are "
			+ "clear, which is what a canyon cannot help. Asked of SightLine, so this is what radar sees. %s")
			% [hidden * 100.0, abeam.size(), OBSERVER_RANGE, OVER_RIM_REQUIRED_M,
				rad_to_deg(atan(OVER_RIM_REQUIRED_M / OBSERVER_RANGE)), HIDDEN_SHARE * 100.0, seen_abeam,
				tried_abeam, seen_axial, tried_axial, worst])
	_and_the_height_where_cover_stops(world, stations, abeam, rim, middle)
	_and_the_same_fighter_on_open_ground_is_seen(world, stations, abeam, rim)


## THE HEIGHT AT WHICH COVER STOPS, swept rather than assumed: the observers are raised over the rim until the share of
## the run they can see passes `COVER_LOST_AT`. A canyon cannot hide a craft from an eye directly over it, so the
## useful number is not whether cover fails but WHERE, and it is reported rather than required.
func _and_the_height_where_cover_stops(world: Object, stations: Array[Dictionary], abeam: Array[Vector2], rim: float,
		middle: Vector2) -> void:
	var said: Array[String] = []
	var lost_at: float = -1.0
	var over: float = OVER_RIM_FROM
	while over <= OVER_RIM_TO:
		var seen: int = 0
		var tried: int = 0
		for one in stations:
			var station: Dictionary = one
			var at: Vector2 = station["at"]
			var craft := Vector3(at.x, float(station["water"]) + FLY_HEIGHT, at.y)
			for out in abeam:
				tried += 1
				if SightLine.is_clear(world, Vector3(middle.x + out.x, rim + over, middle.y + out.y), craft):
					seen += 1
		var share: float = float(seen) / float(maxi(tried, 1))
		said.append("%.0f m (%.1f deg): %.0f %% seen" % [over, rad_to_deg(atan(over / OBSERVER_RANGE)), share * 100.0])
		if lost_at < 0.0 and share > COVER_LOST_AT:
			lost_at = over
		over *= 2.0
	# A PROBE'S NUMBER INSIDE A SUITE: the sweep has no right answer, so what is CHECKED is that cover exists at the
	# bottom of it and is lost by the top -- a canyon that concealed at every height would mean the sweep never
	# reached over the rim, and one that concealed at none would mean there is no canyon.
	_check("cover_is_there_low_and_gone_high", lost_at > OVER_RIM_FROM,
		"%s; cover is lost at %s over the rim" % [", ".join(said),
			"%.0f m (%.1f deg)" % [lost_at, rad_to_deg(atan(lost_at / OBSERVER_RANGE))] if lost_at > 0.0
				else "no height in the sweep"])


## AND THE SAME FIGHTER ON OPEN GROUND IS SEEN. The control, and the only thing standing between the check above and a
## meaningless pass: a sight function that called everything blocked would conceal the open farmland too.
func _and_the_same_fighter_on_open_ground_is_seen(world: Object, stations: Array[Dictionary], abeam: Array[Vector2],
		rim: float) -> void:
	var middle: Dictionary = stations[stations.size() / 2]
	var at: Vector2 = middle["at"]
	var across: Vector2 = middle["across"]
	var away: Vector2 = at + across * OPEN_GROUND_AWAY
	var craft := Vector3(away.x, _ground(away) + FLY_HEIGHT, away.y)
	var seen: int = 0
	for out in abeam:
		if SightLine.is_clear(world, Vector3(away.x + out.x, rim + OVER_RIM_REQUIRED_M, away.y + out.y), craft):
			seen += 1
	var share: float = float(seen) / float(maxi(abeam.size(), 1))
	_check("and_the_same_fighter_over_open_ground_is_seen", share >= OPEN_GROUND_SEEN,
		("seen from %d of %d abeam observers (%.0f %%, wanted %.0f %%) at the same height over the same ground. A "
			+ "sight function that called everything blocked would score 0 here and would pass the check above.")
			% [seen, abeam.size(), share * 100.0, OPEN_GROUND_SEEN * 100.0])


## A WORLD TO ASK ABOUT SIGHT: a `CockpitWorld` standing on this level's ground AND its rock, because a canyon's walls
## are the rock and a world without them would call the whole gorge open sky. `Sim.server` is the right thing to ask in
## the game (rule 10, a detection is the authority's); this probe builds its own because it never starts a session.
func _sighting_world() -> Object:
	if not ClassDB.class_exists(&"CockpitWorld") or not ClassDB.class_has_method(&"CockpitWorld", &"set_ground"):
		return null
	var world: Object = ClassDB.instantiate(&"CockpitWorld")
	# STARTED BEFORE IT IS STOOD ON ANYTHING, as `tests/ground_collision.gd` builds one. A world that has not started
	# takes the ground and keeps none of it, and `SightLine` then answers its safe default -- TRUE, nothing in the way
	# -- for every line asked of it. The first run of this check read 456 of 456 sight lines clear, including the ones
	# straight through 300 m of rock, and the number that gave it away was the control scoring 100 % as well.
	world.set_tick_rate(120)
	world.start(0)
	var stood: bool = bool(world.set_ground(_field))
	var rock: Object = Terrain.mountains()
	var raised: bool = rock != null and world.has_method("set_mountains") and bool(world.set_mountains(rock))
	_check("the_sighting_world_stands_on_the_ground_and_its_rock", stood and raised,
		"ground %s, rock %s" % [stood, raised])
	return world

func _finish() -> void:
	print("RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL " + ", ".join(_failures)))
	get_tree().quit(0)

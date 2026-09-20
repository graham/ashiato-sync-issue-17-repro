extends RefCounted
class_name Spectacles
## THE PILOT'S SPECTACLES: far aircraft drawn bigger, for the one person wearing them.
##
## Asked for on 2026-09-18: "Sometimes people have trouble in vr games spotting other planes, I'd like a setting that
## allows me to falsely increase the size to the viewer only, so in the ipad i can turn on "spotting size" and planes
## get progressively bigger as they get far away ... By shrinking it back to normal size when it's within 0.5km (this
## should be configurable where the normal limit is), they hopefully will not notice."
##
## WHAT IT CHANGES: the SCALE OF THE DRAWN NODE of another aircraft, on this machine, for this rig's eye, and nothing
## else. Collision is the native library's and has no node in the scene; aiming, radar, the lamp's aim and the wire are
## all worked from the simulation's state. So the one thing it can reach is what one person sees, which is the point.
## Never sent, never anybody else's business, kept in `user://` like the placing grid.
##
## THE CURVE IS A FLOOR ON HOW BIG AN AIRCRAFT LOOKS, not a straight rise with distance. What a person can find is an
## ANGLE: an ATSB mid-air report (AR 2022-001, 2020, citing Morris 2005 and an NTSB report of 1987) gives 12 minutes of
## arc as a detection threshold, and 24 to 36 as what it takes in poor conditions. The user's headset, a Quest 3 (user, 2026-09-19),
## is about 25 panel pixels a degree at the middle of the lens, so a pixel is 2.4 minutes of arc and 12 minutes is five of them.
## Unmagnified, the F/A-18F -- 18.4 m long, measured by its longest drawn dimension -- is 26 px at 1 km, 9 at 3 km,
## 5 at 5 km, 2.6 at 10 km and 1.3 at 20 km, and those are LENGTHS: the fuselage is about a metre thick, so at ten
## kilometres it is a line under a pixel wide. So each strength keeps the craft's longest dimension at least
## `FLOOR_ARCMIN` across, up to `CAP` times its real size: a light aeroplane gets more help than an airliner, because it
## needs more, and nothing is magnified that is already big enough to see.
##
## A LINEAR RISE WAS THE OTHER SHAPE, and was rejected: "bigger the further away" at one rate for every kind makes a
## 60 m airliner at 5 km absurd to give a 9 m trainer any help at all, and the number it is really trying to hold is the
## angle.
##
## NO STEP ANYWHERE, AND NOTHING THAT CLOSES EVER LOOKS SMALLER. Inside `near_m` the scale is exactly one. Past it the
## scale is the least of three things, each of which rises with distance no faster than distance does: the floor, met by
## a soft maximum of one and `distance / onset` (`KNEE`) so there is no kink where it starts to bite; the cap; and a RAMP
## out of the limit that starts level and never climbs faster than `RAMP` of distance over the limit. The least of three
## such things is another, so the scale is continuous, starts from the limit with no slope, and the size an aircraft
## LOOKS -- scale over distance -- only ever grows as it comes closer: shrinking it back is slower than it grows by
## coming nearer, which is what makes the shrink invisible.
##
## THE FIRST CURVE FADED IT IN BY A SMOOTHSTEP from the limit to twice it, and was rejected by its own suite: with HIGH
## and a 2 km limit, a Cessna 3.3 km off shrank 0.3 per cent a metre, so closing at 200 m/s it LOOKED smaller by 55 per
## cent a second when coming nearer grows it by 6. That is a pop, only a slow one.

enum Strength { OFF, LOW, MEDIUM, HIGH }

## THE WORDS ON THE BOARD, one per strength, in order.
const STRENGTH_WORDS: Array[String] = ["OFF", "LOW", "MEDIUM", "HIGH"]
## THE SMALLEST ANGLE a craft's longest dimension is drawn at, minutes of arc, per strength. LOW is the NTSB threshold;
## MEDIUM and HIGH are the two ends of the ATSB's "poor conditions" range.
const FLOOR_ARCMIN: Array[float] = [0.0, 12.0, 24.0, 36.0]
## THE MOST a strength may magnify, times real size. Past it the craft shrinks again with distance, as a real one does:
## a fighter blown up tenfold is a different thing, not a far fighter.
const CAP: Array[float] = [1.0, 3.0, 5.0, 8.0]
## HOW SHARP THE SHOULDER IS where the floor starts to bite, as the power in a soft maximum. At 3 the scale is 1.26x at
## the onset distance and within 4 per cent of the floor at twice it; at 2 it was 1.41x at the onset, magnifying craft
## that were already big enough to see, and higher powers approach a kink.
const KNEE: float = 3.0
## HOW FAST THE MAGNIFICATION MAY GROW OUT OF THE LIMIT, as a share of the distance past it over the limit: the ramp is
## `1 + RAMP * x^2 / (1 + x)` with `x = (distance - near) / near`, level at the limit and never steeper than `RAMP / near`.
## At a half, the look of a craft closing through the ramp still grows at least as fast as its scale shrinks, the whole
## way (d(scale / distance) <= 0 needs `2 * RAMP * x <= 1 + x`, which a half meets for every x); any more and it would not.
const RAMP: float = 0.5
## WITHIN THIS DISTANCE EVERY AIRCRAFT IS ITS TRUE SIZE, metres. The board's steps, and the default of the four.
const NEAR_STEPS: Array[float] = [250.0, 500.0, 1000.0, 2000.0]
const DEFAULT_NEAR: float = 500.0
const DEFAULT_STRENGTH: int = Strength.OFF
## THE PIXEL THE BOARD'S WORDS ARE COUNTED IN, minutes of arc: the Quest 3's panel (user, 2026-09-19) at about 25 pixels a degree at the lens's middle. The
## words only; the curve is in angles, so a sharper headset changes nothing but what the board says.
const ARCMIN_A_PIXEL: float = 2.4
## THE KIND THE BOARD'S EXAMPLE IS WORKED FOR: a fighter, the F/A-18F's longest drawn dimension, metres.
const EXAMPLE_SIZE: float = 18.4

## Where it is kept: the player's folder in the game, a suite's own in a suite, as `PlacingGrid` keeps snap.json.
static var path: String = CockpitLayout.folder_for(OS.get_cmdline_args()).path_join("spotting.json")

var strength: int = DEFAULT_STRENGTH
var near_m: float = DEFAULT_NEAR


## ---- the curve ------------------------------------------------------------------------------------------------

## HOW MANY TIMES ITS REAL SIZE a craft `size` metres across (its longest dimension) is drawn at `distance` metres,
## for a wearer at `strength` with true size inside `near` metres. Pure, so the suite can sweep it without a world.
static func scale_for(distance: float, size: float, which: int, near: float) -> float:
	if which <= Strength.OFF or which >= FLOOR_ARCMIN.size() or size <= 0.0 or distance <= near:
		return 1.0
	var floor_rad: float = deg_to_rad(FLOOR_ARCMIN[which] / 60.0)
	# WHERE THE FLOOR STARTS TO BITE: the distance at which `size` subtends the floor.
	var onset: float = size / floor_rad
	var wanted: float = pow(1.0 + pow(distance / onset, KNEE), 1.0 / KNEE)
	# OUT OF THE LIMIT LEVEL, and never faster than `RAMP`: see its note.
	var x: float = (distance - near) / maxf(near, 1.0)
	var ramp: float = 1.0 + RAMP * x * x / (1.0 + x)
	return minf(minf(wanted, CAP[which]), ramp)


## The same, at this pair of spectacles' own setting.
func scale_at(distance: float, size: float) -> float:
	return scale_for(distance, size, strength, near_m)


## Whether these spectacles do anything at all.
func is_on() -> bool:
	return strength > Strength.OFF


## WHETHER A KIND IS MAGNIFIED: aeroplanes, helicopters and tiltrotors. NOT boats, ships, ground vehicles or trains --
## they stand on a surface, and one magnified about its middle sinks into it or floats over it -- and they are not what
## people lose in the sky.
static func magnifies(kind: int) -> bool:
	var model: int = int(Sim.geometry_of(kind).get("model", -1))
	return model == Sim.Model.AIRPLANE or model == Sim.Model.HELICOPTER or model == Sim.Model.TILTROTOR


## A KIND'S LONGEST DRAWN DIMENSION, metres: its span (the drawn wing or rotor, `Shape::span`) or its hull's length,
## whichever is greater. What the floor is an angle OF.
static func size_of(kind: int) -> float:
	var geometry: Dictionary = Sim.geometry_of(kind)
	var extents: Vector3 = geometry.get("extents", Vector3.ONE) as Vector3
	return maxf(float(geometry.get("span", 0.0)), maxf(extents.z, extents.x) * 2.0)


## ---- the board ------------------------------------------------------------------------------------------------

## WHAT THE CURRENT SETTING DOES, in a sentence a person can check against what they see: a fighter at ten kilometres.
func words() -> String:
	if not is_on():
		return "OFF: every aircraft is drawn at its true size."
	var far: float = 10000.0
	var times: float = scale_at(far, EXAMPLE_SIZE)
	var pixels: float = FLOOR_ARCMIN[strength] / ARCMIN_A_PIXEL
	return "%s: a fighter 10 km away is drawn %.1fx its size. Nothing is drawn smaller than about %d headset pixels, up to %dx." \
		% [STRENGTH_WORDS[strength], times, roundi(pixels), roundi(CAP[strength])]


## THE LINE UNDER THE LIMIT'S ROW.
func near_words() -> String:
	return "Closer than %s, every aircraft is its true size. Past it they get bigger gradually, so one coming towards you never seems to shrink." \
		% km_words(near_m)


static func km_words(metres: float) -> String:
	return "%s km" % str(snappedf(metres / 1000.0, 0.01)).trim_suffix(".0")


## ---- drawn ----------------------------------------------------------------------------------------------------

## A KIND'S SIZE, or 0 for a kind these spectacles leave alone: asked of the shape table once per kind, not per frame.
static var _sizes: Dictionary = {}


static func drawn_size(kind: int) -> float:
	var size: float = _sizes.get(kind, -1.0)
	if size < 0.0:
		size = size_of(kind) if magnifies(kind) else 0.0
		_sizes[kind] = size
		_rests[kind] = float((Sim.geometry_of(kind).get("extents", Vector3.ZERO) as Vector3).y)
	return size


## HOW HIGH A KIND'S MIDDLE STANDS OVER WHAT IT RESTS ON, metres: its hull's half-height. Filled beside `_sizes`.
static var _rests: Dictionary = {}
## UNDER THIS SPEED, m/s, a magnified craft is scaled about its wheels: below any aeroplane's flying speed here (the
## sailplane stalls at about 20), and a hovering helicopter is as well stood on its skids as on its middle.
const SLOW: float = 15.0


## DRAW ONE VIEW THROUGH THEM: `view` was placed this frame by `VehicleView.draw` at its true size, and is scaled about
## its own origin -- the hull's middle -- by what its distance from `eye` asks for. Returns the scale. The caller skips
## the craft the wearer is in; nothing here can tell which that is.
##
## THE VIEW'S OWN `transform`, NOT ITS GLOBAL ONE: `draw` has just set it and so dirtied the global, and asking for that
## recomputes it -- a third of this function's cost at 64 fighters (2026-09-18). It is the same number, because the level
## that holds every view stands at the world's origin: `draw` writes the simulation's world pose into `transform`.
##
## A SLOW CRAFT IS SCALED ABOUT ITS WHEELS, NOT ITS MIDDLE: under `SLOW` m/s by `state`'s velocity (the simulation's
## state for this craft, `Sim.current[entity]`, or {} for none) it is lifted by what the scale adds below its middle, so a
## parked or taxiing aeroplane, a landing one and a hovering helicopter stand on the ground or deck they stand on rather
## than sinking into it. A craft the simulation rests on its hull stands `extents.y` over the ground (a parked fighter's
## origin is 1.10 m up, `FighterAirframe`). Nothing asks where the ground is: that is a query a frame per craft, and speed
## is already in hand. A craft taking off far away moves from one pivot to the other by `(scale - 1) * extents.y`, about
## 2 m at 5 km on HIGH, under a pixel.
func magnify(view: Node3D, kind: int, eye: Vector3, state: Dictionary) -> float:
	var size: float = drawn_size(kind)
	if size <= 0.0:
		return 1.0
	var away: float = view.transform.origin.distance_to(eye)
	var times: float = 1.0 if away <= near_m else scale_for(away, size, strength, near_m)
	if times != 1.0:
		var up: Vector3 = view.basis.y
		view.basis = view.basis * times
		if (state.get("velocity", Vector3.ZERO) as Vector3).length_squared() < SLOW * SLOW:
			view.position += up * (times - 1.0) * float(_rests.get(kind, 0.0))
	# ONE FLOAT LOOKED UP A FRAME, and the record only when the ranges are due a rewrite (about 23 rewrites in 240 frames at
	# 64 fighters). Measured A/B on 2026-09-19 under the same load, with and without this branch: 408 and 457 us against
	# 408 and 366 -- within the load's own spread.
	var id: int = view.get_instance_id()
	var written: float = _written.get(id, 1.0)
	if times != written and (times == 1.0 or absf(times - written) >= RESTRETCH * written):
		_stretch(view, times)
	return times


## ---- the parts a distance LOD hides ---------------------------------------------------------------------------
##
## THE LOD READS THE DRAWN SIZE. `AircraftVisualLod` hides a fitting under 2.5 m past 900 m and one under 5 m past 2.4 km,
## and each airframe's own details go at 450 to 1800 m, all by the camera's TRUE distance. So while a craft is magnified,
## every part with a visibility range has that range stretched by the same factor: a part is hidden when it LOOKS as small
## as the LOD meant, which is the rule the LOD was written to (team-lead, 2026-09-19). Put back when the craft is at its
## true size again, and when the spectacles come off (`put_back_every_part`). MEASURED, it barely shows: 0 pixels of
## difference round a fighter at 1 to 10 km and at most 3 round the tanker (agents.md, "Spotting size, on the iPad").
##
## NOT EVERY FRAME: only when the scale has moved by `RESTRETCH` since the ranges were last written, or has come back to
## one. The ranges are a threshold, and a threshold a tenth out is not a thing anybody sees.
const RESTRETCH: float = 0.1

## view instance id -> {"view": the view, "parts": [[part, end, margin], ...] as they were, "times": as last written}.
static var _stretched: Dictionary = {}
## view instance id -> the scale its ranges were last written for, for every craft in `_stretched`.
static var _written: Dictionary = {}
## HOW MANY TIMES A CRAFT'S RANGES HAVE BEEN WRITTEN, for the suite's cost line.
static var writes: int = 0


static func _stretch(view: Node3D, times: float) -> void:
	var id: int = view.get_instance_id()
	var record: Dictionary = _stretched.get(id, {})
	if record.is_empty():
		# A VIEW REAPED WHILE STRETCHED leaves its record behind; they are swept out here, rarely, rather than every frame.
		if _stretched.size() > 256:
			for old in _stretched.keys():
				if not is_instance_valid((_stretched[old] as Dictionary)["view"]):
					_stretched.erase(old)
					_written.erase(old)
		var parts: Array = []
		for node in view.find_children("*", "GeometryInstance3D", true, false):
			var part := node as GeometryInstance3D
			if part.visibility_range_end > 0.0:
				parts.append([part, part.visibility_range_end, part.visibility_range_end_margin])
		record = {"view": view, "parts": parts, "times": 1.0}
		_stretched[id] = record
	if times == float(record["times"]):
		return
	writes += 1
	for row in record["parts"]:
		var part: GeometryInstance3D = row[0]
		if is_instance_valid(part):
			part.visibility_range_end = float(row[1]) * times
			part.visibility_range_end_margin = float(row[2]) * times
	record["times"] = times
	_written[id] = times
	if times == 1.0:
		_stretched.erase(id)
		_written.erase(id)


## EVERY STRETCHED PART PUT BACK: the spectacles are off, and nothing will be magnified to put them back one at a time.
static func put_back_every_part() -> void:
	for id in _stretched.keys():
		var record: Dictionary = _stretched[id]
		if is_instance_valid(record["view"]):
			_stretch(record["view"] as Node3D, 1.0)
	_stretched.clear()
	_written.clear()


## HOW MANY CRAFT HAVE PARTS STRETCHED NOW, for the suite.
static func stretched_count() -> int:
	return _stretched.size()


## ---- kept between sessions ------------------------------------------------------------------------------------

## THE PAIR THIS MACHINE WEARS: what the file says, and then what the command line says, which is never written back.
## `--spotting=off|low|medium|high` and `--spotting-near=<metres>`, for a probe or a peer that must see a setting
## without touching the player's file.
static func worn(args: PackedStringArray = OS.get_cmdline_user_args()) -> Spectacles:
	var pair: Spectacles = read()
	for arg in args:
		if arg.begins_with("--spotting="):
			var named: int = STRENGTH_WORDS.find(arg.get_slice("=", 1).to_upper())
			if named >= 0:
				pair.strength = named
			else:
				push_warning("[spotting] %s is not one of %s" % [arg, ", ".join(STRENGTH_WORDS)])
		elif arg.begins_with("--spotting-near="):
			pair.near_m = maxf(float(arg.get_slice("=", 1)), 0.0)
	return pair


## A PAIR AS WRITTEN DOWN, or the defaults for anything the file does not say or cannot be read as.
static func read() -> Spectacles:
	var pair := Spectacles.new()
	if not FileAccess.file_exists(path):
		return pair
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("[spotting] %s is not an object; spotting size is off" % path)
		return pair
	var named: int = STRENGTH_WORDS.find(String((parsed as Dictionary).get("strength", STRENGTH_WORDS[DEFAULT_STRENGTH])).to_upper())
	pair.strength = named if named >= 0 else DEFAULT_STRENGTH
	var near: float = float((parsed as Dictionary).get("normal_within_m", DEFAULT_NEAR))
	pair.near_m = near if NEAR_STEPS.has(near) else DEFAULT_NEAR
	return pair


## WRITE IT DOWN. Returns whether it was written.
func write() -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("[spotting] could not write %s" % path)
		return false
	file.store_string(JSON.stringify({
		"units": "normal_within_m in metres; strength one of OFF, LOW, MEDIUM, HIGH",
		"strength": STRENGTH_WORDS[strength],
		"normal_within_m": near_m,
	}, "\t"))
	return true

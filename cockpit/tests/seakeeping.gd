extends Node
## HOW A HULL RIDES THE SEA: heave, pitch, roll, and how far its deck goes under, for every powered hull, stopped, at
## cruise and flat out, into the waves and across them.
##
##   Godot --headless --path cockpit --fixed-fps 120 --xr-mode off res://tests/seakeeping.tscn
##   ... -- --kind=cb90                 one kind
##   ... -- --set=buoyancy*2,righting=0 retune through set_handling first, as tests/handling.gd does
##   ... -- --probe                     print the table and gate nothing
##
## Asked for by the user on 2026-09-18: "Boats are all over the place and bounce alot ... I want ships to bounce a little
## less and not go under water so much, the CB90 dives too far down often." (lane/seakeep.)
##
## WHAT IS MEASURED, each over `SPELL` seconds after the hull has settled at its speed, sampled every tick:
##   - HEAVE: the hull's origin (the design waterline, midships) up and down: its standard deviation, its whole range, and
##     how often it rises through its mean, which is the heave's frequency;
##   - BOUNCE: the vertical acceleration at the helm seat, as a root mean square in g, which is what a seated player feels;
##   - PITCH AND ROLL: standard deviation, and the worst either way from the level the hull floats at stopped;
##   - THE BOW UNDER: the bow at deck height against the DRAWN sea there (`swell_height_at`, which the plain sea draws to a
##     tenth of a millimetre: tests/ocean_height_shot.gd). Its worst depth under, the share of the time it is under, and
##     how many times it went under by more than `DIVE_DEPTH` (a dive), counted once each;
##   - THE DECK EDGE: the lowest the deck's edge got against the drawn sea anywhere round the hull (bow, stern, both
##     sides at the widest and at the quarters);
##   - THE WATERLINE ON THE HULL: the drawn sea at the hull's middle less the hull's design waterline, as a mean and a
##     standard deviation. What the player sees as the boat sitting in the water, or bobbing against it.
##
## WHERE: a bare world, the sea everywhere, starting at `AT`. "Head" runs along +X, the swell's and the wind-sea's own
## heading, so a hull meets every wave at its full length; "beam" runs along +Z, across them.
##
## THE GATES are in `_gate_kind`. The table is printed whatever happens, and `--probe` gates nothing.
##
## MEASURED ON 2026-09-18, main 910e75bb against lane/seakeep, flat out along the waves (the table this prints):
##
##   |                         | CB90 before | CB90 after | gunboat before | gunboat after | launch before | after |
##   |-------------------------|-------------|------------|----------------|---------------|---------------|-------|
##   | heave range, m          | 4.97        | 1.70       | 3.79           | 1.71          | 2.16          | 1.96  |
##   | helm, g rms             | 0.665       | 0.126      | 0.549          | 0.148         | 0.243         | 0.230 |
##   | pitch sd, deg           | 3.73        | 1.24       | 3.96           | 1.19          | 2.85          | 1.85  |
##   | bow under the sea, m    | 1.60        | -0.34      | 0.73           | -0.55         | 0.28          | 0.18  |
##   | dives a minute          | 15          | 0          | 3              | 0             | 1             | 0     |
##   | waterline's spread, m   | 1.21        | 0.30       | 0.63           | 0.28          | 0.30          | 0.30  |
##
## (A negative bow is clear of the sea by that much.) What changed, all in `cockpit_world.cpp`: the float probes damped
## at the hull's own critical (`kHeaveDampingRatio`) where every hull had the launch's flat 1,000 N s/m, the wind-sea
## averaged over the hull (`sea_felt`), and a quarter of the launch's and the gunboat's weight carried by the planing
## bottom at speed (`plane_lift`; the CB90 has none, see its handling).
##
## At cruise the CB90 was worse still: 5.69 m of heave, 0.71 g, its bow 2.21 m under and 21 dives. The carrier lying
## stopped heaved 0.11 m at 0.63 Hz on its own spring, and rang for ever; it is still now.

const TICK: float = 1.0 / 120.0
const SPELL: float = 60.0
const AT := Vector3(500.0, 1.0, 500.0)
const CLIENT: int = 301
## A HULL UNDER A HUNDRED TONNES is a small boat: the same split `tests/handling.gd` makes, by displacement.
const SMALL_BOAT_MASS: float = 100000.0
## A BOW MORE THAN THIS FAR UNDER THE DRAWN SEA IS A DIVE: green water over the stem, not spray.
const DIVE_DEPTH: float = 0.25

## THE BOUNDS (lane/seakeep), for a small boat under way at cruise and flat out, into the waves and across them. The
## CB90 and the gunboat missed every one of them before. The launch, already damped at 0.56 of critical by the flat
## 1,000 N s/m typed for it, missed the bow, the dives and the pitch.
## The deepest the bow may go under the drawn sea, in metres (CB90 before 2.21, launch 0.28; now 0.34 clear and 0.18).
const BOW_UNDER_MOST: float = 0.25
## How many times in the spell the bow may go under by more than `DIVE_DEPTH` (CB90 before 21, launch 1).
const DIVES_MOST: int = 0
## The deepest the deck edge may go under anywhere round the hull, in metres: a boat heeled in a sea ships a little
## water over its low side, the launch's 0.30 m of freeboard most of all (CB90 before 3.42).
const DECK_UNDER_MOST: float = 1.0
## The hull's whole heave, top to bottom, in metres; the sea it rides is 2.8 m from its lowest trough to its highest
## crest (CB90 before 5.69).
const HEAVE_RANGE_MOST: float = 2.5
## The pitch's spread, standard deviation in degrees (CB90 before 3.73, launch 2.85; now 1.24 and 1.85).
const PITCH_SD_MOST: float = 2.5
## The drawn sea at the hull's middle, less its design waterline: how far the water line moves up and down the hull as
## the player sees it, standard deviation in metres (CB90 before 1.52).
const WATERLINE_SD_MOST: float = 0.5
## The vertical acceleration at the helm seat, root mean square in g (CB90 before 0.71).
const BOUNCE_MOST: float = 0.25
## AND LESS ON A HULL LONG ENOUGH TO SPAN THE SHORT WAVES: at `LONG_ENOUGH` metres of waterline or more, the average of
## the wind-sea over the hull (`sea_felt`) takes the helm from 0.160 to 0.126 g on the CB90 and from 0.193 to 0.148 g on
## the gunboat, flat out; the launch, 5.6 m, keeps nearly every wave either way. This is what the unaveraged sea's
## mutant fails (`--set=sea_smoothing=0`: the gunboat, and the submarine at 0.021 and 0.034 g against
## `SHIP_BOUNCE_MOST`). The old damping's mutant (`--set=probe_damping=1000`) fails 29 checks: the gunboat's bow 0.68 m
## under, 11 dives.
const BOUNCE_LONG_MOST: float = 0.17
const LONG_ENOUGH: float = 10.0
## A SHIP (over `SMALL_BOAT_MASS`) UNDER WAY, at the helm: the carrier's was 0.020 to 0.048 g and the battleship's to 0.036,
## both from their own probes ringing; now under 0.01.
const SHIP_BOUNCE_MOST: float = 0.015
## EVERY HULL LYING STOPPED on a standing sea lies still: its heave's whole range, in metres (the carrier rang 0.11 m).
const STOPPED_HEAVE_MOST: float = 0.02

var _overrides: Dictionary = {}
var _probe: bool = false
var _failures: PackedStringArray = []
var _rows: PackedStringArray = []


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL CockpitWorld is not registered")
		get_tree().quit(1)
		return
	var only: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="):
			only = arg.trim_prefix("--kind=")
		elif arg == "--probe":
			_probe = true
		elif arg.begins_with("--set="):
			for pair in arg.trim_prefix("--set=").split(",", false):
				var factor: bool = pair.contains("*")
				var bits: PackedStringArray = pair.split("*" if factor else "=")
				_overrides[bits[0]] = [factor, float(bits[1])]
			print("[seakeeping] retuned through set_handling: %s" % str(_overrides))
	var measured: int = 0
	for kind in range(Sim.Kind.size()):
		var name: String = Sim.kind_name(kind)
		if not only.is_empty() and name != only:
			continue
		var geometry: Dictionary = Sim.geometry_of(kind)
		# NOT A FLYING BOAT: `alight` floats those on the same probes, and tests/water.gd and tests/savoia.gd hold them.
		if int(geometry.get("model", -1)) != Sim.Model.BOAT or not bool(geometry.get("pilotable", true)):
			continue
		measured += 1
		_kind(kind, geometry)
		await get_tree().process_frame
	print("[seakeeping] ---- the table ----")
	print("[seakeeping]   %-10s %-6s %-9s %5s | %6s %6s %5s | %6s | %5s %5s | %5s %5s | %6s %5s %3s | %6s | %6s %5s | %4s" % [
		"kind", "run", "case", "m/s", "heave", "range", "Hz", "g rms", "p sd", "p max", "r sd", "r max",
		"bow", "wet%", "dv", "deck", "wl", "wl sd", "off"])
	for line in _rows:
		print("[seakeeping]   " + line)
	var ok: bool = measured > 0
	print("[seakeeping] %s every_powered_hull_was_measured (%d)" % ["PASS" if ok else "FAIL", measured])
	if not ok:
		_failures.append("every_powered_hull_was_measured")
	if _probe:
		print("RESULT=PASS (probe: nothing gated)")
	else:
		ok = ok and _failures.is_empty()
		print("RESULT=%s" % ("PASS" if ok else "FAIL " + "; ".join(_failures)))
	get_tree().quit(0)


## One kind: stopped, at cruise and flat out, into the waves and across them.
func _kind(kind: int, geometry: Dictionary) -> void:
	var hull: Dictionary = _hull_of(geometry)
	var small: bool = float(geometry.get("mass", 0.0)) < SMALL_BOAT_MASS
	var results: Dictionary = {}
	for run in ["head", "beam"]:
		for case in ["stopped", "cruise", "flat_out"]:
			if run == "beam" and case == "stopped":
				continue
			var throttle: float = {"stopped": 0.0, "cruise": 0.5, "flat_out": 1.0}[case]
			var m: Dictionary = _measure(kind, hull, small, throttle, run)
			results[run + " " + case] = m
			_rows.append("%-10s %-6s %-9s %5.1f | %6.3f %6.2f %5.2f | %6.3f | %5.2f %5.1f | %5.2f %5.1f | %+6.2f %5.1f %3d | %+6.2f | %+6.2f %5.2f | %4.1f" % [
				Sim.kind_name(kind), run, case, m["speed"], m["heave_sd"], m["heave_range"], m["heave_hz"], m["bounce"],
				m["pitch_sd"], m["pitch_worst"], m["roll_sd"], m["roll_worst"], m["bow_under"], m["bow_wet"] * 100.0,
				m["dives"], m["deck_under"], m["waterline"], m["waterline_sd"], m["off_course"]])
	if not _probe:
		_gate_kind(Sim.kind_name(kind), small, float(hull["length"]) >= LONG_ENOUGH, results)


## THE GATES: the bounds above, each printed with its number.
func _gate_kind(name: String, small: bool, long_enough: bool, results: Dictionary) -> void:
	for key in results:
		var m: Dictionary = results[key]
		var what: String = "%s %s" % [name, key]
		if String(key).ends_with("stopped"):
			_gate(absf(float(m["waterline"])) <= 0.15, "%s sits in the water it is drawn in (waterline %+.2f m off the sea, wanted within 0.15)" % [what, m["waterline"]])
			_gate(float(m["heave_range"]) <= STOPPED_HEAVE_MOST, "%s lies still (heave %.3f m top to bottom, wanted under %.2f)" % [what, m["heave_range"], STOPPED_HEAVE_MOST])
			continue
		if not small:
			_gate(float(m["bounce"]) <= SHIP_BOUNCE_MOST, "%s rides without ringing (%.3f g rms at the helm, wanted under %.3f)" % [what, m["bounce"], SHIP_BOUNCE_MOST])
			continue
		_gate(float(m["bow_under"]) <= BOW_UNDER_MOST, "%s keeps its bow out of the sea (%+.2f m under at worst, wanted at most %.2f)" % [what, m["bow_under"], BOW_UNDER_MOST])
		_gate(int(m["dives"]) <= DIVES_MOST, "%s dives %d times in %.0f s, wanted at most %d" % [what, m["dives"], SPELL, DIVES_MOST])
		_gate(float(m["deck_under"]) <= DECK_UNDER_MOST, "%s keeps its deck edge out of the sea (%+.2f m under at worst, wanted at most %.2f)" % [what, m["deck_under"], DECK_UNDER_MOST])
		_gate(float(m["heave_range"]) <= HEAVE_RANGE_MOST, "%s heaves %.2f m top to bottom, wanted under %.1f" % [what, m["heave_range"], HEAVE_RANGE_MOST])
		_gate(float(m["pitch_sd"]) <= PITCH_SD_MOST, "%s holds its pitch (sd %.2f deg, wanted under %.1f)" % [what, m["pitch_sd"], PITCH_SD_MOST])
		_gate(float(m["waterline_sd"]) <= WATERLINE_SD_MOST, "%s sits in its drawn water (the waterline moves %.2f m sd, wanted under %.1f)" % [what, m["waterline_sd"], WATERLINE_SD_MOST])
		var most: float = BOUNCE_LONG_MOST if long_enough else BOUNCE_MOST
		_gate(float(m["bounce"]) <= most, "%s rides without bouncing (%.3f g rms at the helm, wanted under %.2f)" % [what, m["bounce"], most])


func _gate(ok: bool, what: String) -> void:
	print("[seakeeping] %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


## THE HULL'S DECK EDGE, from its parts: the `hull` part's outline at its top, or the box's top for a kind with no parts.
## Returns the points to watch in the hull's frame, the bow first, and the helm seat.
func _hull_of(geometry: Dictionary) -> Dictionary:
	var points: Array = []
	var top: float = 0.0
	var outline := PackedVector2Array()
	for part in (geometry.get("parts", []) as Array):
		if String((part as Dictionary).get("part", "")) == "hull":
			outline = (part as Dictionary)["outline"]
			top = float((part as Dictionary)["top"])
			break
	if outline.is_empty():
		var e: Vector3 = geometry.get("extents", Vector3.ONE)
		top = e.y
		outline = PackedVector2Array([Vector2(-e.x, -e.z), Vector2(e.x, -e.z), Vector2(e.x, e.z), Vector2(-e.x, e.z)])
	var bow_z: float = INF
	var stern_z: float = -INF
	var beam: float = 0.0
	for c in outline:
		bow_z = minf(bow_z, c.y)
		stern_z = maxf(stern_z, c.y)
		beam = maxf(beam, absf(c.x))
	# The bow, the stern, and the widest at the quarters and amidships on each side.
	points.append(Vector3(0.0, top, bow_z))
	points.append(Vector3(0.0, top, stern_z))
	for z in [bow_z * 0.5, 0.0, stern_z * 0.5]:
		var half: float = _half_beam_at(outline, z, beam)
		points.append(Vector3(half, top, z))
		points.append(Vector3(-half, top, z))
	var seat := Vector3.ZERO
	var seats: Array = geometry.get("seat_poses", [])
	if not seats.is_empty():
		seat = ((seats[0] as Dictionary).get("position", Vector3.ZERO)) as Vector3
	return {"points": points, "seat": seat, "top": top, "length": stern_z - bow_z}


## The outline's half-width at `z`, the widest crossing of its edges there.
static func _half_beam_at(outline: PackedVector2Array, z: float, fallback: float) -> float:
	var half: float = 0.0
	for i in range(outline.size()):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		if (a.y - z) * (b.y - z) > 0.0 or is_equal_approx(a.y, b.y):
			continue
		var t: float = (z - a.y) / (b.y - a.y)
		half = maxf(half, absf(lerpf(a.x, b.x, t)))
	return half if half > 0.0 else fallback


func _measure(kind: int, hull: Dictionary, small: bool, throttle: float, run: String) -> Dictionary:
	var world: Object = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(120.0)
	world.start(0)
	if not _overrides.is_empty():
		var now: Dictionary = world.handling(kind)
		var tuned: Dictionary = {}
		for key in _overrides:
			var o: Array = _overrides[key]
			tuned[key] = float(now.get(key, 0.0)) * float(o[1]) if bool(o[0]) else float(o[1])
		world.set_handling(kind, tuned)
	# THE NOSE ALONG +X ("head") OR +Z ("beam"): `spawn_pilot`'s yaw puts the nose along (-sin yaw, 0, -cos yaw).
	var yaw: float = -PI * 0.5 if run == "head" else PI
	var want: float = rad_to_deg(atan2(-(-sin(yaw)), -(-cos(yaw))))
	var made: Dictionary = world.spawn_pilot(CLIENT, kind, AT, yaw, Vector3.ZERO)
	var vehicle: int = int(made.get("vehicle", 0))
	var pilot: int = int(made.get("pilot", 0))
	# SETTLE: long enough to be at speed. A ship takes minutes; a small boat seconds.
	var settle: float = 25.0 if small else 150.0
	var input: Dictionary = {"throttle": throttle, "rudder": 0.0}
	var ticks: int = int((settle + SPELL) / TICK)
	var heights := PackedFloat32Array()
	var pitches := PackedFloat32Array()
	var rolls := PackedFloat32Array()
	var bounce_sum: float = 0.0
	var bounce_n: int = 0
	var speed_sum: float = 0.0
	var bow_under: float = -INF
	var deck_under: float = -INF
	var wet: int = 0
	var dives: int = 0
	var diving: bool = false
	var waterline := PackedFloat32Array()
	var seat_v_was: float = NAN
	var points: Array = hull["points"]
	var seat: Vector3 = hull["seat"]
	var samples: int = 0
	var off_sum: float = 0.0
	for i in range(ticks):
		var state: Dictionary = world.vehicle_state(vehicle)
		if state.is_empty():
			break
		var basis := Basis(state["basis"] as Quaternion)
		# THE HELM: a heading hold on the rudder, so a hull runs straight through the sea it is measured on.
		var nose: Vector3 = basis * Vector3.FORWARD
		var heading: float = rad_to_deg(atan2(-nose.x, -nose.z))
		var off: float = angle_difference(deg_to_rad(heading), deg_to_rad(want))
		var spin: Vector3 = state.get("spin", Vector3.ZERO)
		input["rudder"] = clampf(-off * 2.0 + spin.y * 1.0, -1.0, 1.0) if throttle > 0.0 else 0.0
		world.set_pilot_input(pilot, input)
		world.tick(TICK)
		if i * TICK < settle:
			continue
		state = world.vehicle_state(vehicle)
		if state.is_empty():
			break
		basis = Basis(state["basis"] as Quaternion)
		var at: Vector3 = state["position"]
		var v: Vector3 = state["velocity"]
		spin = state.get("spin", Vector3.ZERO)
		samples += 1
		off_sum += absf(rad_to_deg(off))
		heights.append(at.y)
		pitches.append(rad_to_deg(asin(clampf((basis * Vector3.FORWARD).y, -1.0, 1.0))))
		rolls.append(rad_to_deg(asin(clampf(-(basis * Vector3.RIGHT).y, -1.0, 1.0))))
		speed_sum += Vector2(v.x, v.z).length()
		# THE HELM SEAT'S VERTICAL SPEED, the body's at that point, differenced tick to tick.
		var arm: Vector3 = basis * seat
		var seat_v: float = (v + spin.cross(arm)).y
		if not is_nan(seat_v_was):
			var a: float = (seat_v - seat_v_was) / TICK / 9.81
			bounce_sum += a * a
			bounce_n += 1
		seat_v_was = seat_v
		# THE BOW AND THE DECK EDGE against the drawn sea.
		var lowest: float = -INF
		for p_i in range(points.size()):
			var world_p: Vector3 = at + basis * (points[p_i] as Vector3)
			var under: float = float(world.swell_height_at(world_p.x, world_p.z)) - world_p.y
			if p_i == 0:
				bow_under = maxf(bow_under, under)
				if under > 0.0:
					wet += 1
				if under > DIVE_DEPTH and not diving:
					dives += 1
					diving = true
				elif under < 0.0:
					diving = false
			lowest = maxf(lowest, under)
		deck_under = maxf(deck_under, lowest)
		waterline.append(float(world.swell_height_at(at.x, at.z)) - at.y)
	world.teardown()
	var n: float = maxf(1.0, float(samples))
	return {
		"speed": speed_sum / n,
		"heave_sd": _sd(heights),
		"heave_range": _range(heights),
		"heave_hz": _crossings(heights) / SPELL,
		"bounce": sqrt(bounce_sum / maxf(1.0, float(bounce_n))),
		"pitch_sd": _sd(pitches),
		"pitch_worst": _worst_from_mean(pitches),
		"roll_sd": _sd(rolls),
		"roll_worst": _worst_from_mean(rolls),
		"bow_under": bow_under,
		"bow_wet": float(wet) / n,
		"dives": dives,
		"deck_under": deck_under,
		"waterline": _mean(waterline),
		"waterline_sd": _sd(waterline),
		"off_course": off_sum / n,
	}


static func _mean(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var sum: float = 0.0
	for v in values:
		sum += v
	return sum / float(values.size())


static func _sd(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var mean: float = _mean(values)
	var sum: float = 0.0
	for v in values:
		sum += (v - mean) * (v - mean)
	return sqrt(sum / float(values.size()))


static func _range(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var lo: float = INF
	var hi: float = -INF
	for v in values:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	return hi - lo


static func _worst_from_mean(values: PackedFloat32Array) -> float:
	var mean: float = _mean(values)
	var out: float = 0.0
	for v in values:
		out = maxf(out, absf(v - mean))
	return out


## Upward crossings of the mean, with a hysteresis of a tenth of the spread so the solver's jitter is not counted.
static func _crossings(values: PackedFloat32Array) -> float:
	var mean: float = _mean(values)
	var band: float = _sd(values) * 0.1
	var below: bool = false
	var count: int = 0
	for v in values:
		if v < mean - band:
			below = true
		elif v > mean + band and below:
			count += 1
			below = false
	return float(count)

extends Node
## WHAT THE GROUND'S TUNING BUILT: land, collision, slopes, and the height the towns and airfields are joined at. A probe
## for the terrain design's alpine consequences (godotgames-drafts/2026-09-14/cockpit-terrain/report.md), not a suite.
##
##   Godot --headless --path cockpit res://tests/alpine_probe.tscn -- --out=C:/somewhere
##   Godot --headless --path cockpit res://tests/alpine_probe.tscn -- --peak_height=1350 --world_half=32000
##
## `GroundField` configured from `GroundTuning` (64 km, ranges to 3,000 m, seed 0, the user's answers of 2026-09-14),
## unless a knob is given on the command line. It prints:
##
## - THE LAND: the highest ground, the share of the square that is land, land by height band, and the map as a picture.
## - THE COLLISION: land cells of `WorldMap.CELL` (any 16 m sample above -40 m) and what a height field a cell costs,
##   and each cell's RELIEF -- because a cell's Box3D height field holds 65,535 steps of 1/32 m, exact only while the
##   cell's highest sample stands less than 2,048 m above its lowest.
## - THE SLOPES at 16 m, which the skirts, the normals and anything parked have to hold on.
## - THE AI'S QUESTION: the lowest height at which every town and airfield is joined through air over land alone, and
##   over land and sea (a union-find on a 256 m grid, cells taken lowest first); and how many straight site-to-site legs
##   an aeroplane climbing at the autopilot's gentle 9 degrees clears with 150 m to spare.
##
## A probe: nothing here has a right answer; the one verdict is that every part ran.

const CELL: int = 1024
## What the design's height field costs a cell of 65 by 65 samples (cpp/probe.cpp, phase 1).
const FIELD_BYTES: int = 20840
## THE CLIMB A LEG IS FLOWN AT, as a flight path, degrees: `--climb=`. The autopilot caps it at 9 (tests/climb.gd), and
## what the aircraft actually fly is less: 5.2 to 6.0 for the light aeroplane, airliner, tiltrotor and gunship, and 4.3 for
## the Cessna (tests/climb.gd's steepest climbs, 2026-09-14). The slowest is the default, because a route the Cessna can
## fly is one every wing can.
var _climb_deg: float = 4.3
const LEG_ROOM: float = 150.0

var _out: String = "user://alpine_probe"
var _values: Dictionary = {}
var ground: Object = null


func _ready() -> void:
	_values = GroundTuning.values()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.get_slice("=", 1)
		if argument.begins_with("--climb="):
			_climb_deg = float(argument.get_slice("=", 1))
		for key in ["world_half", "peak_height", "seed"]:
			if argument.begins_with("--%s=" % key):
				_values[key] = int(argument.get_slice("=", 1))
	DirAccess.make_dir_recursive_absolute(_out)
	ground = ClassDB.instantiate("GroundField")
	if ground == null:
		print("RESULT=FAIL the extension has no GroundField")
		get_tree().quit(1)
		return
	var problems: PackedStringArray = ground.call("configure", _values)
	var catalogue: Dictionary = ground.call("catalogue")
	print("[alpine] tuning %s, problems %s; %d lakes, %d towns, %d airfields" % [_values, problems,
		(catalogue["lakes"] as Array).size(), (catalogue["towns"] as Array).size(), (catalogue["airfields"] as Array).size()])
	for town in catalogue["towns"]:
		print("[alpine]   town at (%d, %d) level %.0f m" % [town["x"], town["z"], float(town["level"]) / 1024.0])
	for strip in catalogue["airfields"]:
		print("[alpine]   airfield at (%d, %d) level %.0f m" % [strip["x"], strip["z"], float(strip["level"]) / 1024.0])
	var began: int = Time.get_ticks_usec()
	_land()
	print("[alpine] land and cells in %.1f s" % (float(Time.get_ticks_usec() - began) / 1e6))
	_map(catalogue)
	_air(catalogue)
	print("RESULT=%s" % ("PASS" if bool(ground.call("is_configured")) else "FAIL the ground did not configure"))
	get_tree().quit(0)


## ---- the land, the collision and the slopes ----------------------------------------------------------------------

func _land() -> void:
	var half: int = int(_values["world_half"])
	var side: int = (2 * half + CELL - 1) / CELL
	var land_cells: int = 0
	var reliefs := PackedFloat32Array()
	var over_window: int = 0
	var worst_relief: float = 0.0
	var worst_cell := Vector2i.ZERO
	var highest: int = -(1 << 30)
	var land_samples: int = 0
	var all_samples: int = 0
	var bands: Array[float] = [500.0, 1000.0, 1500.0, 2000.0, 2500.0]
	var above: Array[int] = [0, 0, 0, 0, 0]
	var steeper: Array[int] = [0, 0, 0]   # 30, 45, 60 degrees
	var tangents: Array[float] = [tan(deg_to_rad(30.0)), tan(deg_to_rad(45.0)), tan(deg_to_rad(60.0))]
	var steepest: float = 0.0
	var steepest_at := Vector2i.ZERO
	var slope_samples: int = 0
	for cj in range(side):
		for ci in range(side):
			var x0: int = -half + ci * CELL
			var z0: int = -half + cj * CELL
			var g: PackedInt32Array = ground.call("heights", x0, z0, 65, 65, 16)
			var low: int = g[0]
			var high: int = g[0]
			for h in g:
				low = mini(low, h)
				high = maxi(high, h)
			highest = maxi(highest, high)
			if high > -40 * 32:
				land_cells += 1
				var relief: float = float(high - low) / 32.0
				reliefs.append(relief)
				if relief >= 2048.0:
					over_window += 1
				if relief > worst_relief:
					worst_relief = relief
					worst_cell = Vector2i(ci, cj)
			# Interior samples only, so an edge shared with the next cell is counted once; every other one for slopes.
			for j in range(64):
				for i in range(64):
					var h: int = g[j * 65 + i]
					all_samples += 1
					if h <= 0:
						continue
					land_samples += 1
					var metres: float = float(h) / 32.0
					for b in range(bands.size()):
						if metres > bands[b]:
							above[b] += 1
					if (i & 1) == 0 and (j & 1) == 0:
						var dx: float = float(g[j * 65 + i + 1] - h) / 32.0
						var dz: float = float(g[(j + 1) * 65 + i] - h) / 32.0
						var gradient: float = sqrt(dx * dx + dz * dz) / 16.0
						slope_samples += 1
						for t in range(3):
							if gradient > tangents[t]:
								steeper[t] += 1
						if gradient > steepest:
							steepest = gradient
							steepest_at = Vector2i(x0 + i * 16, z0 + j * 16)
	reliefs.sort()
	var land_km2: float = float(land_samples) * 16.0 * 16.0 / 1e6
	print("[alpine] land: highest %.0f m; %.0f km2 of land, %.1f %% of the %d km square" % [float(highest) / 32.0,
		land_km2, 100.0 * land_samples / all_samples, 2 * half / 1000])
	var banding: PackedStringArray = []
	for b in range(bands.size()):
		banding.append("above %.0f m %.1f %%" % [bands[b], 100.0 * above[b] / maxi(land_samples, 1)])
	print("[alpine] land by height: %s" % ", ".join(banding))
	print("[alpine] collision: %d land cells of %d, %.1f MB of height fields at %d bytes a cell (the sea not built)" % [
		land_cells, side * side, float(land_cells * FIELD_BYTES) / 1048576.0, FIELD_BYTES])
	if not reliefs.is_empty():
		print("[alpine] relief a cell: median %.0f m, 90th %.0f m, 99th %.0f m, worst %.0f m at cell %s; %d cells at or over the 2,048 m window" % [
			reliefs[reliefs.size() / 2], reliefs[int(reliefs.size() * 0.9)], reliefs[int(reliefs.size() * 0.99)],
			worst_relief, worst_cell, over_window])
	print("[alpine] slopes at 16 m over land: steeper than 30 deg %.1f %%, 45 deg %.1f %%, 60 deg %.2f %%; steepest %.0f deg (%.0f m in 16) at %s" % [
		100.0 * steeper[0] / maxi(slope_samples, 1), 100.0 * steeper[1] / maxi(slope_samples, 1),
		100.0 * steeper[2] / maxi(slope_samples, 1), rad_to_deg(atan(steepest)), steepest * 16.0, steepest_at])


## ---- the map ---------------------------------------------------------------------------------------------------------

func _map(catalogue: Dictionary) -> void:
	var half: int = int(_values["world_half"])
	var step: int = 128
	var n: int = 2 * half / step + 1
	var h: PackedInt32Array = ground.call("heights", -half, -half, n, n, step)
	var image := Image.create(n, n, false, Image.FORMAT_RGB8)
	for j in range(n):
		for i in range(n):
			var ticks: int = h[j * n + i]
			var here: float = float(ticks) / 32.0
			var east: float = float(h[j * n + mini(i + 1, n - 1)]) / 32.0
			var south: float = float(h[mini(j + 1, n - 1) * n + i]) / 32.0
			var normal := Vector3(here - east, float(step), here - south).normalized()
			var light: float = clampf(normal.dot(Vector3(-0.5, 0.75, -0.45).normalized()) * 1.25, 0.25, 1.15)
			var water: int = ground.call("water_ticks_at", -half + i * step, -half + j * step)
			var colour: Color
			if water == 0 and ticks < 0:
				colour = Color(0.05, 0.16, 0.30).lerp(Color(0.12, 0.35, 0.45), clampf(1.0 + here / 60.0, 0.0, 1.0))
			elif water > -(1 << 29) and ticks < water:
				colour = Color(0.20, 0.45, 0.70)
			else:
				var slope: float = 1.0 - normal.y
				colour = Color(0.30, 0.45, 0.20).lerp(Color(0.52, 0.50, 0.34), clampf(here / 1200.0, 0.0, 1.0))
				colour = colour.lerp(Color(0.45, 0.42, 0.40), clampf(slope * 5.0 + (here - 1700.0) / 600.0, 0.0, 1.0))
				colour = colour.lerp(Color(0.95, 0.95, 0.97), clampf((here - 2200.0) / 300.0, 0.0, 1.0))
				colour = Color(colour.r * light, colour.g * light, colour.b * light)
			image.set_pixel(i, j, colour)
	for town in catalogue["towns"]:
		var r: int = int(town["r"]) / step
		image.fill_rect(Rect2i((int(town["x"]) + half) / step - r, (int(town["z"]) + half) / step - r, r * 2 + 1, r * 2 + 1),
			Color(0.85, 0.15, 0.1))
	for strip in catalogue["airfields"]:
		image.fill_rect(Rect2i((int(strip["x"]) - int(strip["half_long"]) + half) / step,
			(int(strip["z"]) - int(strip["half_wide"]) + half) / step, maxi(int(strip["half_long"]) * 2 / step, 1),
			maxi(int(strip["half_wide"]) * 2 / step, 1)), Color(1.0, 0.85, 0.1))
	var path: String = _out.path_join("alpine_map.png")
	image.save_png(path)
	print("[alpine] map: %s" % path)


## ---- the air ---------------------------------------------------------------------------------------------------------

func _air(catalogue: Dictionary) -> void:
	var half: int = int(_values["world_half"])
	var step: int = 256
	var n: int = 2 * half / step + 1
	var h: PackedInt32Array = ground.call("heights", -half, -half, n, n, step)
	var sites: Array = (catalogue["towns"] as Array) + (catalogue["airfields"] as Array)
	var site_cells := PackedInt32Array()
	for site in sites:
		site_cells.append(clampi((int(site["z"]) + half + step / 2) / step, 0, n - 1) * n
			+ clampi((int(site["x"]) + half + step / 2) / step, 0, n - 1))
	for over_land_only in [true, false]:
		var joined: float = _joined_at(h, n, site_cells, over_land_only)
		print("[alpine] air: every town and airfield joined %s at ground no higher than %.0f m" % [
			"over land alone" if over_land_only else "over land and sea", joined])
	# STRAIGHT LEGS between every pair of sites, flown from the lower site's level + 300 m, climbing at 9 degrees to the
	# height the leg needs (its highest ground + 300 m), and blocked if the ground under it comes within 150 m.
	var climb: float = tan(deg_to_rad(_climb_deg))
	var pairs: int = 0
	var cleared: int = 0
	var highest_ground: PackedFloat32Array = []
	for a in range(sites.size()):
		for b in range(a + 1, sites.size()):
			pairs += 1
			var from := Vector2(float(sites[a]["x"]), float(sites[a]["z"]))
			var to := Vector2(float(sites[b]["x"]), float(sites[b]["z"]))
			var length: float = from.distance_to(to)
			var samples: int = maxi(int(length / 128.0), 2)
			var points := PackedInt32Array()
			for s in range(samples + 1):
				var at: Vector2 = from.lerp(to, float(s) / float(samples))
				points.append(int(at.x))
				points.append(int(at.y))
			var under: PackedInt32Array = ground.call("heights_at", points)
			var top: float = 0.0
			for t in under:
				top = maxf(top, float(t) / 32.0)
			highest_ground.append(top)
			var start: float = minf(float(sites[a]["level"]), float(sites[b]["level"])) / 1024.0 + 300.0
			var cruise: float = top + 300.0
			var clear: bool = true
			for s in range(samples + 1):
				var flown: float = minf(start + length * float(s) / float(samples) * climb, cruise)
				if float(under[s]) / 32.0 + LEG_ROOM > flown:
					clear = false
					break
			cleared += 1 if clear else 0
	highest_ground.sort()
	if pairs > 0:
		print("[alpine] air: %d of %d straight site-to-site legs clear the ground by %.0f m climbing at %.0f deg; the highest ground under a leg: median %.0f m, worst %.0f m" % [
			cleared, pairs, LEG_ROOM, _climb_deg, highest_ground[highest_ground.size() / 2], highest_ground[highest_ground.size() - 1]])


## THE LOWEST HEIGHT JOINING EVERY SITE: cells taken lowest first into a union-find, joined to their taken neighbours,
## until one set holds every site. A cell's key packs its height above the lowest and its index, so the engine's own
## sort orders them.
static func _joined_at(h: PackedInt32Array, n: int, site_cells: PackedInt32Array, over_land_only: bool) -> float:
	var parent := PackedInt32Array()
	parent.resize(n * n)
	var holds := PackedInt32Array()
	holds.resize(n * n)
	var taken := PackedByteArray()
	taken.resize(n * n)
	for k in range(n * n):
		parent[k] = k
	for c in site_cells:
		holds[c] += 1
	var keys := PackedInt64Array()
	for k in range(n * n):
		if over_land_only and h[k] <= 0:
			continue
		keys.append((int(h[k]) + (1 << 20)) * (1 << 20) + k)
	keys.sort()
	var every: int = site_cells.size()
	for key in keys:
		var k: int = key % (1 << 20)
		taken[k] = 1
		var i: int = k % n
		var j: int = k / n
		for step in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var ni: int = i + int(step[0])
			var nj: int = j + int(step[1])
			if ni < 0 or nj < 0 or ni >= n or nj >= n or taken[nj * n + ni] == 0:
				continue
			var ra: int = _root(parent, k)
			var rb: int = _root(parent, nj * n + ni)
			if ra != rb:
				parent[rb] = ra
				holds[ra] += holds[rb]
		if holds[_root(parent, k)] >= every:
			return float(key / (1 << 20) - (1 << 20)) / 32.0
	return INF


static func _root(parent: PackedInt32Array, k: int) -> int:
	while parent[k] != k:
		parent[k] = parent[parent[k]]
		k = parent[k]
	return k

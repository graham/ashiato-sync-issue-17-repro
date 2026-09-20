extends Node
## WHERE A BIG FLEET'S TICK GOES, AND WHAT THE CHORE ROTA DOES TO IT. A probe, not a suite.
##
##   Godot --headless --fixed-fps 120 --path cockpit res://tests/rota_probe.tscn [-- --counts=100,1000,5000] [-- --blocks=4]
##
## Asked for on 2026-09-14 with the rota itself: "run lots of ai state machines without having to run them every
## physics tick on the server". For each count a server world is built by hand with the island's boxes and waypoints,
## filled with that many aeroplanes, and ticked by hand -- a headless loop paces itself to real time, so wall clock across
## a physics frame measures the frame period (agents.md, "What a hundred and nineteen vehicles cost").
##
## FOUR REGIMES ON ONE WORLD, interleaved block by block, so all of them fly the same sky under the same load from the
## other lanes on this machine:
##
##   * ROTA -- the budgets and limits as shipped;
##   * STRETCHED -- a flat count a tick near what a thousand wings want, with limits long enough that five thousand are
##     not forced: the chores a tick stay put and the intervals stretch instead, which is the user's point;
##   * ON TIME -- no budget, every chore on its own hashed target, which is what the countdowns the rota replaced did;
##   * ROTA UNTIMED -- the shipped budgets with the tick breakdown off, which is what the breakdown itself costs.
##
## Per count and regime it prints the whole tick (median over blocks of each block's median), the chores as the rota
## measured them, and where the tick went (`CockpitWorld.tick_breakdown`, medians over blocks): the chores, the rest of the
## autopilot split into guidance and mixers, the forces on the vehicles, the Box3D step, the readback, sync, and the rest.
## On a library without the rota -- main before it -- it prints the whole tick only. None of it has a right answer on
## somebody else's machine.

const HZ: float = 120.0
const WINGS: Array[int] = [Sim.Kind.PLANE, Sim.Kind.AIRLINER, Sim.Kind.TANKER, Sim.Kind.OSPREY, Sim.Kind.CESSNA,
	Sim.Kind.GUNSHIP]
## AMONG THE ROCK, NOT ABOVE IT. The first cut put every aeroplane at 1,100 to 1,600 m, where a look skips nearly every
## box on its height test and cost 0.36 us, which prices a sky nobody flies. From 250 to 900 m the massif, the ridges and
## the towns are in the way of the looks and legs as they are in the real sky. Each spot is checked clear before a craft
## is put there (`SPAWN_CLEARANCE` round a line from under it to `SPAWN_RUN` along its nose), so none starts inside a box.
const LOWEST: float = 250.0
const HIGHEST: float = 900.0
const SPAWN_CLEARANCE: float = 60.0
const SPAWN_RUN: float = 600.0
const SETTLE_TICKS: int = 240
const BLOCK_TICKS: int = 600
const CHORES: Array[String] = ["look_ahead", "leg_check"]
## STRETCHED, of the probe's own choosing: about what a thousand wings want a tick (1,000 / 60 looks, 1,000 / 360 leg
## checks), with limits eight times the targets, so five thousand at that count wait 312 and 1,667 ticks and are not forced.
const STRETCHED: Dictionary = {
	"look_ahead": {"budget": 16, "limit": 480},
	"leg_check": {"budget": 3, "limit": 2880},
}
const BREAKDOWN: Array[String] = ["tick", "chores", "guidance", "mixers", "ground", "air", "forces", "step", "readback",
	"sync", "pilots", "rails", "before", "after", "display", "other"]

var _counts: Array[int] = [100, 1000, 5000]
## `--kind=cessna` FLIES ONE KIND and `--set=surfaces=1` RETUNES IT, as `tests/handling.gd` takes them: how the in-game cost
## of a flight model is priced, one kind with a switch on against the same kind with it off (lane/flightmodel, the
## Cessna on its lifting surfaces). Unset, the six wings below and their handling as shipped.
var _wings: Array[int] = []
var _retune: Dictionary = {}
var _blocks: int = 4
var _priced: int = 0
## What the simulation shipped with, read back before the probe changes anything: a share restored as a share.
var _shipped: Dictionary = {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--counts="):
			_counts.clear()
			for part in arg.get_slice("=", 1).split(","):
				_counts.append(int(part))
		if arg.begins_with("--blocks="):
			_blocks = int(arg.get_slice("=", 1))
		if arg.begins_with("--kind="):
			for kind in range(Sim.Kind.size()):
				if Sim.kind_name(kind) == arg.trim_prefix("--kind="):
					_wings = [kind]
		if arg.begins_with("--set="):
			for pair in arg.trim_prefix("--set=").split(",", false):
				var bits: PackedStringArray = pair.split("=")
				_retune[bits[0]] = float(bits[1])
	if _wings.is_empty():
		_wings = WINGS.duplicate()
	print("[rota_probe] wings %s, retuned %s" % [_wings.map(func(k): return Sim.kind_name(k)), _retune])
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL extension_missing")
		get_tree().quit(1)
		return
	var rota: bool = ClassDB.class_has_method("CockpitWorld", "tick_breakdown")
	print("[rota_probe] %s library, %d blocks of %d ticks each" % ["rota" if rota else "pre-rota", _blocks, BLOCK_TICKS])
	var grid := BoxGrid.new(Terrain.boxes())
	for count in _counts:
		_price(count, rota, grid)
	# EVERY COUNT PRICED, or it says so. Its first run threw on a typed array just after spawning, the error ended
	# `_price`, and the probe went on to print RESULT=PASS over a table it had never printed.
	var ok: bool = _priced == _counts.size()
	print("[rota_probe] %d of %d counts priced" % [_priced, _counts.size()])
	print("RESULT=%s" % ("PASS" if ok else "FAIL not_every_count_was_priced"))
	get_tree().quit(0 if ok else 1)


func _price(count: int, rota: bool, grid) -> void:
	var world = ClassDB.instantiate("CockpitWorld")
	world.set_tick_rate(HZ)
	world.start(0)
	world.add_static_box(Vector3(0.0, -Terrain.GROUND_HALF.y, 0.0), Terrain.GROUND_HALF)
	for box in Terrain.boxes():
		world.add_static_box(box["position"], box["half_extents"])
	for kind in _wings:
		if not _retune.is_empty():
			world.set_handling(kind, _retune)
		for spot in Terrain.waypoints(Sim.Kind.PLANE, grid):
			world.add_ai_waypoint(kind, spot)
	var span: float = Terrain.WORLD_HALF * 0.8
	var spawn_began: int = Time.get_ticks_msec()
	var placed: int = 0
	var tried: int = 0
	while placed < count and tried < count * 20:
		var kind: int = _wings[placed % _wings.size()]
		var at := Vector3((Terrain.hash01(tried, 7101) * 2.0 - 1.0) * span,
			lerpf(LOWEST, HIGHEST, Terrain.hash01(tried, 7102)), (Terrain.hash01(tried, 7103) * 2.0 - 1.0) * span)
		var yaw: float = Terrain.hash01(tried, 7104) * TAU
		tried += 1
		if not world.leg_is_clear(at - Vector3(0.0, SPAWN_CLEARANCE, 0.0), at + Terrain.nose_from_yaw(yaw) * SPAWN_RUN,
				SPAWN_CLEARANCE):
			continue
		var cruise: float = float(world.handling(kind).get("cruise", 60.0))
		if int(world.spawn_ai_vehicle(kind, at, yaw, Terrain.nose_from_yaw(yaw) * cruise)) != 0:
			placed += 1
	print("[rota_probe] %d of %d wings spawned, %d spots tried, in %d ms; %d autopilots in the world" % [placed, count,
		tried, Time.get_ticks_msec() - spawn_began, int(world.ai_vehicle_count())])
	for i in range(SETTLE_TICKS):
		world.tick(1.0 / HZ)

	# Built one by one: `[...] if rota else [...]` is an untyped Array, which a typed variable refuses at run time.
	var regimes: Array[String] = []
	if rota:
		for regime in ["rota", "stretched", "on_time", "rota_untimed"]:
			regimes.append(regime)
		for chore in CHORES:
			var row: Dictionary = world.chore_report()["kinds"][chore]
			_shipped[chore] = {"budget": float(row["share"]) if float(row["share"]) > 0.0 else int(row["budget"]),
				"limit": int(row["max_ticks"])}
	else:
		regimes.append("countdowns")
	var ticks: Dictionary = {}
	var reports: Dictionary = {}
	var breakdowns: Dictionary = {}
	for regime in regimes:
		ticks[regime] = []
		reports[regime] = []
		breakdowns[regime] = []
	for block in range(_blocks):
		for regime in regimes:
			if rota:
				for chore in CHORES:
					world.set_chore_limit(chore, _limit_for(chore, regime))
					world.set_chore_budget(chore, _budget_for(chore, regime))
			for i in range(SETTLE_TICKS):
				world.tick(1.0 / HZ)
			if rota:
				world.reset_chore_report()
				world.set_tick_breakdown(regime != "rota_untimed")
			var spent: PackedFloat32Array = []
			for i in range(BLOCK_TICKS):
				var began: int = Time.get_ticks_usec()
				world.tick(1.0 / HZ)
				spent.append(float(Time.get_ticks_usec() - began))
			spent.sort()
			(ticks[regime] as Array).append(spent[spent.size() / 2])
			if rota:
				(reports[regime] as Array).append(world.chore_report()["kinds"])
				if regime != "rota_untimed":
					(breakdowns[regime] as Array).append(world.tick_breakdown())
				world.set_tick_breakdown(false)
	for regime in regimes:
		var line: String = "[rota_probe] %5d wings %-12s tick %.3f ms (blocks %s)" % [count, regime,
			_median(ticks[regime]) / 1000.0, ", ".join((ticks[regime] as Array).map(func(u): return "%.3f" % (float(u) / 1000.0)))]
		if rota:
			for chore in CHORES:
				var usec: Array = []
				var worst_usec: float = 0.0
				var served: float = 0.0
				var mean: float = 0.0
				var worst: int = 0
				var overruns: int = 0
				for kinds in reports[regime]:
					var row: Dictionary = kinds[chore]
					usec.append(float(row["usec_per_tick"]))
					worst_usec = maxf(worst_usec, float(row["usec_worst_tick"]))
					served += float(row["served_per_tick"]) / float(_blocks)
					mean += float(row["mean_interval"]) / float(_blocks)
					worst = maxi(worst, int(row["worst_interval"]))
					overruns += int(row["overruns"])
				line += " | %s %.1f us a tick (worst %.0f), %.2f served a tick, interval mean %.1f worst %d, %d overruns" % [
					chore, _median(usec), worst_usec, served, mean, worst, overruns]
		print(line)
		if rota and not (breakdowns[regime] as Array).is_empty():
			var parts: Array[String] = []
			for field in BREAKDOWN:
				var values: Array = (breakdowns[regime] as Array).map(func(b): return float(b[field]))
				parts.append("%s %.1f" % [field, _median(values)])
			print("[rota_probe] %5d wings %-12s where a tick goes, us: %s" % [count, regime, ", ".join(parts)])
	world.teardown()
	_priced += 1


func _budget_for(chore: String, regime: String) -> Variant:
	match regime:
		"rota", "rota_untimed":
			return _shipped[chore]["budget"]
		"stretched":
			return int(STRETCHED[chore]["budget"])
	return -1


func _limit_for(chore: String, regime: String) -> int:
	if regime == "stretched":
		return int(STRETCHED[chore]["limit"])
	return int(_shipped[chore]["limit"])


func _median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size() / 2])

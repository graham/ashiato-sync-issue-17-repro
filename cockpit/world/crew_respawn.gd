extends Node
class_name CrewRespawn
## THE HOST PUTS A DESTROYED CRAFT'S CREW BACK IN THE AIR, in a fresh craft of the same kind, `SECONDS` after it died
## (lane/combat, 2026-09-18).
##
## HOST ONLY, and the whole decision is the host's: it hears every loss (`Sim.craft_lost`), waits out the crash overview
## every crew machine is showing, and asks the simulation to move the crew (`CockpitWorld.respawn_crew`) -- which puts
## each person back in the seat they had, at the kind's issue place if the level has a clear one, and otherwise where
## this says. A craft nobody was in (an attacker, the island's traffic) is not replaced.
##
## WHERE, WITHOUT AN ISSUE PLACE: over the ground under the wreck for anything that stands on it, and on the water for a
## boat. An aeroplane is launched by the simulation from wherever it is put (`launch_if_grounded`), so the place is
## only its x and z.

## How long a crew watches its wreck before it is back in the air, seconds.
const SECONDS: float = 6.0

## Wreck (host entity) -> {"left": seconds, "kind": int}.
var _due: Dictionary = {}
## How many crews this has put back, for the tests.
var respawned: int = 0
## Where the last winch launch was asked for (`GliderWinch.place`), or {} -- for the tests.
var last_launch: Dictionary = {}


func _ready() -> void:
	Sim.craft_lost.connect(_on_lost)


func _on_lost(kill: Dictionary) -> void:
	if (kill.get("crew", []) as Array).is_empty():
		return
	_due[int(kill["victim"])] = {"left": SECONDS, "kind": int(kill.get("kind", -1)), "crew": kill.get("crew", []).duplicate()}


func _physics_process(delta: float) -> void:
	if Sim.server == null or _due.is_empty():
		return
	for wreck in _due.keys():
		var due: Dictionary = _due[wreck]
		due["left"] = float(due["left"]) - delta
		if float(due["left"]) > 0.0:
			continue
		_due.erase(wreck)
		var at: Vector3 = Sim.server.vehicle_state(int(wreck)).get("position", Vector3.ZERO)
		# A LEVEL WITH A WINCH LAUNCHES ITS RESPAWNS (`GliderWinch`, the glider level): at its first thermal, or beside
		# another player still flying -- never beside the wreck's own crew. The level registers no issue place for the kind
		# it launches, so `respawn_crew` takes this place and no other (sky.gd, `_register_issue_places`).
		var launch: Dictionary = GliderWinch.place(ChartDrawer.chart(Net.level), int(due["kind"]),
			GliderWinch.others_aloft(Sim.server, due["crew"]))
		var asked: bool = false
		if not launch.is_empty():
			asked = Sim.server.respawn_crew(int(wreck), launch["position"], float(launch["yaw"]), launch["velocity"])
		else:
			asked = Sim.server.respawn_crew(int(wreck), place_for(int(due["kind"]), at), 0.0, Vector3.ZERO)
		if asked:
			respawned += 1
			last_launch = launch
			print("[respawn] the crew of %d asked back into the air%s" % [int(wreck), " at %s%s" % [
				(launch["position"] as Vector3).snapped(Vector3.ONE * 0.1),
				" beside client %d" % int(launch["beside"]) if int(launch["beside"]) >= 0 else " over the first thermal"]
				if not launch.is_empty() else ""])


## WHERE A CRAFT OF `kind` THAT DIED AT `at` IS PUT, when the level has no clear issue place for it: on the water there
## for a boat or a planeboat, and otherwise on the ground -- under the wreck, or at the level's arrival spot when the
## wreck is in the sea. Its middle half its height and a little over the surface.
static func place_for(kind: int, at: Vector3) -> Vector3:
	var geometry: Dictionary = Sim.geometry_of(kind)
	var extents: Vector3 = geometry.get("extents", Vector3.ONE) as Vector3
	var floats: bool = String(geometry.get("model_name", "")) in ["boat", "sail"] or bool(geometry.get("amphibian", false))
	var water: float = Terrain.water_height(at)
	var ground: float = Terrain.ground_height(at)
	var spot: Vector3 = at
	if not floats and water > -INF and water >= ground:
		var level: LevelChart = ChartDrawer.chart(Net.level)
		spot = level.spot_for(0) if level != null else Vector3.ZERO
	return Vector3(spot.x, maxf(Terrain.surface_height(spot), Terrain.SEA_LEVEL) + extents.y + 0.5, spot.z)

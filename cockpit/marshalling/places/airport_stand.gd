extends Node3D
class_name AirportStand
## A GATE, A LEAD-IN LINE, A STOP BAR AND A BRIDGE.
##
## The other end of the same job. Nothing here is a carrier: the aeroplane is twenty-six
## metres long instead of six, it comes in off a taxiway rather than off a deck park, and
## what it has to hit is a painted bar with a jet bridge already pointed at where its door
## is going to be. A metre out on a carrier is untidy. A metre out on a stand is a bridge
## that will not reach.
##
## All of it is paint on a flat apron, one building and one hinged arm.

## Where the lead-in line runs, and where the nosewheel has to stop on it.
const LINE_X: float = 0.0
const STOP_Z: float = 0.0
## Where the aeroplane appears, off the taxiway.
const ENTRY_Z: float = 130.0

var _bridge: Node3D = null
var _arm: MeshInstance3D = null
var _reaching: Vector3 = Vector3.ZERO
var _out: float = 0.0
var _wanted_out: float = 0.0


func _ready() -> void:
	_apron()
	_markings()
	_terminal()
	_weather()


## SWING THE BRIDGE ON. The payoff: the door the passengers come off through, arriving at
## the aeroplane the player has just parked. If it were placed by hand it would prove
## nothing -- it goes to where the DOOR ended up, so a stand a metre and a half short is a
## bridge stretching for it.
func swing_onto(door: Vector3) -> void:
	_reaching = door
	_wanted_out = 1.0


## Not `is_connected`: that is Object's, it takes a signal and a callable, and naming a
## method over it fails at PARSE time in every file that calls this one.
func has_reached() -> bool:
	return _out > 0.98


func _process(delta: float) -> void:
	if _bridge == null or _wanted_out <= 0.0:
		return
	_out = move_toward(_out, _wanted_out, delta * 0.25)
	var here: Vector3 = _bridge.global_position
	var reach: Vector3 = _reaching - here
	reach.y = 0.0
	var full: float = maxf(reach.length(), 1.0)
	_bridge.rotation.y = lerp_angle(deg_to_rad(-55.0), atan2(reach.x, reach.z), _out)
	var span: float = lerpf(6.0, full, _out)
	(_arm.mesh as BoxMesh).size = Vector3(3.0, 2.8, span)
	_arm.position = Vector3(0.0, 1.9, span * 0.5)


## ---- the concrete --------------------------------------------------------------------

func _apron() -> void:
	_paint(Vector3(0.0, -0.05, 40.0), Vector3(240.0, 0.1, 260.0), Color(0.22, 0.23, 0.24))


func _markings() -> void:
	# THE LEAD-IN LINE. One stripe, and the whole first half of the job is putting a
	# nosewheel on it and keeping it there.
	_paint(Vector3(LINE_X, 0.02, (ENTRY_Z + STOP_Z) * 0.5 + 5.0),
		Vector3(0.25, 0.04, ENTRY_Z + 20.0), Color(0.95, 0.80, 0.20))
	# THE STOP BAR, and a T-bar either side of it so it reads as a mark to stop ON rather
	# than a line to cross.
	_paint(Vector3(LINE_X, 0.03, STOP_Z), Vector3(9.0, 0.05, 0.55), Color(0.95, 0.80, 0.20))
	_paint(Vector3(LINE_X, 0.03, STOP_Z + 6.0), Vector3(5.0, 0.05, 0.35),
		Color(0.92, 0.92, 0.90))
	# The safety line the ground crew stand behind, which is also where the marshaller is.
	_paint(Vector3(-11.5, 0.02, 30.0), Vector3(0.3, 0.04, 120.0), Color(0.85, 0.30, 0.22))
	for i in range(1, 12):
		_paint(Vector3(LINE_X + 3.0, 0.02, STOP_Z + float(i) * 10.0),
			Vector3(1.2, 0.04, 0.25), Color(0.80, 0.81, 0.78))


func _terminal() -> void:
	_paint(Vector3(-6.0, 7.0, -34.0), Vector3(120.0, 14.0, 26.0), Color(0.42, 0.45, 0.50))
	# A band of glass, which is what a terminal is from an apron.
	_paint(Vector3(-6.0, 8.5, -21.2), Vector3(118.0, 4.0, 0.6), Color(0.20, 0.32, 0.42))

	_bridge = Node3D.new()
	_bridge.name = "JetBridge"
	_bridge.position = Vector3(-16.0, 0.0, -20.0)
	_bridge.rotation.y = deg_to_rad(-55.0)
	add_child(_bridge)
	var pier := MeshInstance3D.new()
	var post := CylinderMesh.new()
	post.top_radius = 0.5
	post.bottom_radius = 0.7
	post.height = 3.6
	pier.mesh = post
	pier.position = Vector3(0.0, 1.8, 0.0)
	pier.material_override = _coat(Color(0.35, 0.37, 0.40))
	_bridge.add_child(pier)
	_arm = MeshInstance3D.new()
	var tube := BoxMesh.new()
	tube.size = Vector3(3.0, 2.8, 6.0)
	_arm.mesh = tube
	_arm.position = Vector3(0.0, 1.9, 3.0)
	_arm.material_override = _coat(Color(0.62, 0.64, 0.66))
	_bridge.add_child(_arm)


func _weather() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-46.0), deg_to_rad(-40.0), 0.0)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	add_child(sun)
	var air := WorldEnvironment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.24, 0.40, 0.62)
	sky_material.sky_horizon_color = Color(0.70, 0.75, 0.79)
	sky_material.ground_bottom_color = Color(0.22, 0.22, 0.22)
	sky_material.ground_horizon_color = Color(0.58, 0.60, 0.62)
	var overhead := Sky.new()
	overhead.sky_material = sky_material
	var weather := Environment.new()
	weather.background_mode = Environment.BG_SKY
	weather.sky = overhead
	weather.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	weather.ambient_light_energy = 1.0
	air.environment = weather
	add_child(air)


func _paint(at: Vector3, size: Vector3, tint: Color) -> MeshInstance3D:
	var slab := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	slab.mesh = box
	slab.position = at
	slab.material_override = _coat(tint)
	add_child(slab)
	return slab


func _coat(tint: Color) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = tint
	paint.roughness = 0.9
	return paint

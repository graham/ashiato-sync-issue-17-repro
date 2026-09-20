extends "res://tests/airliners.gd"
## Headless contract for the C-130H and its AC-130U gunship (`HerculesAirframe`, kind `gunship`): everything the airliners
## are held to (`tests/airliners.gd`, which this extends), and what only a Hercules has -- the RAMP swinging down onto the
## ground with the upper cargo door up into the tail, the PROPELLERS turning, and the AC-130U's three GUNS run out of the
## port side and stowed back inside the skin, with the transport drawing none. Read RESULT=.
##
## THE ENVELOPE IS THE C-130H'S PUBLISHED ONE, typed: 97 ft 9 in, 132 ft 7 in, 38 ft 10 in, and the fuselage 14 ft 2 in
## (Wikipedia; Lockheed Martin's General Arrangement). The wheelbase is the H's 32 ft 1 in and the track Lockheed's printed
## 14 ft 3 in.

const COMMON: Array = ["Fuselage", "WingStarboard", "WingPort", "FlapStarboard", "FlapPort", "AileronStarboard",
	"AileronPort", "TailplaneStarboard", "TailplanePort", "ElevatorStarboard", "ElevatorPort", "Engine1", "Engine2", "Engine3",
	"Engine4", "Propeller1", "Propeller2", "Propeller3", "Propeller4", "Fin", "Rudder", "NoseGear", "MainGearForeStarboard",
	"MainGearForePort", "MainGearAftStarboard", "MainGearAftPort", "NoseDoorStarboard", "NoseDoorPort",
	"SponsonDoorStarboard", "SponsonDoorPort", "SponsonStarboard", "SponsonPort", "Ramp", "CargoDoor", "CargoFloor"]
const ARMS: Array = ["Gun25", "Gun40", "Gun105", "Gun25Port", "Gun40Port", "Gun105Port", "SensorTurret"]
## The four-bladed Hamilton Standard propeller, 13.5 ft across (Wikipedia).
const PROP_DIAMETER := 4.11

const C130 := {"class": "C130H", "length": 29.79, "span": 40.41, "height": 11.84, "width": 4.32,
	# MEASURED off Lockheed's plan: the wing's leading edge outboard of 7 m swept back 0.024 a metre; the tailplane's 0.264.
	"wing_sweep": 1.35, "wing_band": [7.5, 20.1],
	"tail_sweep": 14.79, "tail_band": [0.8, 8.1],
	"wheelbase": ["NoseGear", ["MainGearForeStarboard", "MainGearAftStarboard"], 9.77],
	"tracks": [["MainGearForeStarboard", "MainGearForePort", 4.34], ["MainGearAftStarboard", "MainGearAftPort", 4.34]],
	"roll": ["AileronStarboard", "AileronPort"], "flaps": ["FlapStarboard", "FlapPort"], "spoilers": [],
	"parts": COMMON,
	"legs": ["NoseGear", "MainGearForeStarboard", "MainGearForePort", "MainGearAftStarboard", "MainGearAftPort"],
	"well_doors": ["NoseDoorStarboard", "NoseDoorPort", "SponsonDoorStarboard", "SponsonDoorPort"],
	"stowed_inside": ["NoseGear"],
	"armed": false}


func _ready() -> void:
	_suite = "hercules"
	var gunship: Dictionary = C130.duplicate(true)
	gunship["class"] = "AC130U"
	gunship["armed"] = true
	gunship["parts"] = COMMON + ARMS
	for plan in [C130, gunship]:
		var frame := _common(plan) as HerculesAirframe
		_the_ramp_swings_down_to_the_ground_and_the_door_up_and_both_come_back(frame)
		_the_propellers_are_the_published_size_and_clear_everything_and_turn(frame)
		_the_guns_run_out_of_the_port_side_and_stow_inside_the_skin(frame, bool(plan["armed"]))
		frame.queue_free()
	_finish()


func _make(plan: Dictionary) -> JetlinerAirframe:
	var frame := HerculesAirframe.new()
	frame.armed = bool(plan["armed"])
	return frame


## THE RAMP OPEN: its lowest drawn point on the ground (within 5 cm), and the upper door's lowest edge raised at least a
## metre and a half into the tail with its top still 0.2 m under the fuselage's crown -- a door swung too far stands out
## of the roof, as the first build's did; shut, both exactly where they were drawn, flush with the belly.
func _the_ramp_swings_down_to_the_ground_and_the_door_up_and_both_come_back(frame: HerculesAirframe) -> void:
	var ground: float = frame.point(0.0, 0.0, 0.0).y
	var shut_ramp := _box_of(frame, [frame.find_child("Ramp", true, false)])
	var shut_door := _box_of(frame, [frame.find_child("CargoDoor", true, false)])
	frame.set_ramp(1.0)
	var ramp_pts := _points(frame, frame.find_child("Ramp", true, false) as MeshInstance3D)
	var tail := Vector3(0.0, 0.0, -INF)
	for p in ramp_pts:
		if p.z > tail.z:
			tail = p
	var lowest: float = INF
	for p in ramp_pts:
		lowest = minf(lowest, p.y)
	var open_door := _box_of(frame, [frame.find_child("CargoDoor", true, false)])
	var crown: float = _box_of(frame, [frame.find_child("Fuselage", true, false)]).end.y
	frame.set_ramp(0.0)
	var back: bool = _box_of(frame, [frame.find_child("Ramp", true, false)]).is_equal_approx(shut_ramp) \
		and _box_of(frame, [frame.find_child("CargoDoor", true, false)]).is_equal_approx(shut_door)
	var raised: float = open_door.position.y - shut_door.position.y
	_check("the_ramp_swings_down_to_the_ground_and_the_door_up_and_both_come_back",
		absf(lowest - ground) < 0.05 and lowest >= ground - 0.05 and raised > 1.5 and open_door.end.y < crown - 0.2 and back,
		"open, the ramp's lowest point %.3f m over the ground (its tail at %.2f m aft), the door's bottom raised %.2f m and its top %.2f m under the crown; shut again %s"
			% [lowest - ground, tail.z - frame.point(0.0, 0.0, 0.0).z, raised, crown - open_door.end.y, back])


## THE PROPELLERS: each disc the published 4.11 m across (2 per cent), its tips clear of the fuselage by 0.3 m and of the
## ground by 1 m; and turned by a quarter of a pitch, a blade's tip moves while the hub stays put.
func _the_propellers_are_the_published_size_and_clear_everything_and_turn(frame: HerculesAirframe) -> void:
	var said: PackedStringArray = []
	var ok := true
	var ground: float = frame.point(0.0, 0.0, 0.0).y
	var body := _box_of(frame, [frame.find_child("Fuselage", true, false)])
	for i in range(1, 5):
		var prop := frame.find_child("Propeller%d" % i, true, false) as MeshInstance3D
		var box := _box_of(frame, [prop])
		var across: float = box.size.y
		var inner: float = minf(absf(box.position.x), absf(box.end.x))
		ok = ok and absf(across - PROP_DIAMETER) <= PROP_DIAMETER * 0.02 and inner > body.end.x + 0.3 \
			and box.position.y - ground > 1.0
		said.append("%d: %.2f m across, %.2f clear of the fuselage, %.2f over the ground" % [i, across,
			inner - body.end.x, box.position.y - ground])
	var prop := frame.find_child("Propeller1", true, false) as MeshInstance3D
	var before := _points(frame, prop)
	frame.set_props(0.5)
	var after := _points(frame, prop)
	frame.set_props(0.0)
	var moved: float = _off(before, after)
	_check("the_propellers_are_the_published_size_and_clear_everything_and_turn", ok and moved > 0.5,
		"%s; a blade's tip moves %.2f m at an eighth of a turn" % ["; ".join(said), moved])


## THE GUNS: on the AC-130U, all three out of the PORT side, each muzzle at least 1.2 m past the skin run out (the 105's
## 2.2) and
## every vertex back inside the skin's half-width stowed; on the transport, no gun, no port and no sensor drawn, and no
## `guns` feature for a VAT to bake.
func _the_guns_run_out_of_the_port_side_and_stow_inside_the_skin(frame: HerculesAirframe, armed: bool) -> void:
	var names: Array = []
	for f in frame.features():
		names.append(f["name"])
	if not armed:
		var any: bool = false
		for part in ARMS:
			any = any or frame.find_child(part, true, false) != null
		_check("the_transport_draws_no_guns", not any and not names.has("guns"),
			"gun parts drawn %s, features %s" % [any, names])
		return
	var said: PackedStringArray = []
	var ok := true
	frame.set_guns(1.0)
	var out: Dictionary = {}
	for i in range(HerculesAirframe.GUNS.size()):
		var gun: Dictionary = HerculesAirframe.GUNS[i].merged(HerculesAirframe.gun_mount(i))
		var box := _box_of(frame, [frame.find_child(String(gun["name"]), true, false)])
		var skin: float = frame.skin_out(float(gun["at"]), float(gun["high"]))
		out[gun["name"]] = box
		# SEEN FROM THE GALLERY: every muzzle 1.2 m past the skin and the 105's 2.2 m (team-lead, 2026-09-19: the first
		# build's 0.8-1.55 m barrels read as specks under the wing's shadow).
		var least: float = 2.2 if String(gun["name"]) == "Gun105" else 1.2
		ok = ok and box.position.x < -(skin + least) and box.end.x < 0.0
		said.append("%s out %.2f m past the skin" % [gun["name"], -box.position.x - skin])
	frame.set_guns(0.0)
	for i in range(HerculesAirframe.GUNS.size()):
		var gun: Dictionary = HerculesAirframe.GUNS[i].merged(HerculesAirframe.gun_mount(i))
		var box := _box_of(frame, [frame.find_child(String(gun["name"]), true, false)])
		var skin: float = frame.skin_out(float(gun["at"]), float(gun["high"]))
		ok = ok and box.position.x > -skin
		said.append("%s stowed %.2f m inside" % [gun["name"], box.position.x + skin])
	frame.set_guns(1.0)
	_check("the_guns_run_out_of_the_port_side_and_stow_inside_the_skin", ok and names.has("guns"),
		"%s; features %s" % [", ".join(said), names])
	# THE ROUND LEAVES THE DRAWN MUZZLE: each of the simulation's mounts (`gun_of`) on the drawn skin, within 5 cm, and the
	# drawn barrel the simulation's `barrel` past it (the check above holds the drawn reach). The rounds left 1.6 to 7.0 m
	# aft of the centre from a first gunship's guns until the lane's C++ step (2026-09-19).
	var mounts: PackedStringArray = []
	var on_skin := true
	for i in range(HerculesAirframe.GUNS.size()):
		var mount: Dictionary = HerculesAirframe.gun_mount(i)
		var skin: float = frame.skin_out(float(mount["at"]), float(mount["high"]))
		on_skin = on_skin and absf(float(mount["out"]) + skin) < 0.05 and float(mount["reach"]) > 1.0
		mounts.append("%s at %.2f m aft, %.2f up, %.3f out against the skin's %.3f" % [HerculesAirframe.GUNS[i]["name"],
			mount["at"], mount["high"], -float(mount["out"]), skin])
	_check("every_gun_the_simulation_fires_is_mounted_on_the_drawn_skin", on_skin, ", ".join(mounts))
	# AIMED AT THE SIMULATION'S REST (`gun_of`: a quarter turn to port and 0.45 rad down), every muzzle still a metre past
	# the skin and now 0.3 m under its own mount. A yaw read a quarter turn off -- the mutant that drops `aim_guns`' - PI/2
	# -- turns every barrel to point down the fuselage, which the run-out check above never sees.
	var rest := Vector2(PI * 0.5, -0.45)
	frame.aim_guns([rest, rest, rest])
	var aimed: PackedStringArray = []
	var aimed_ok := true
	for i in range(HerculesAirframe.GUNS.size()):
		var gun: Dictionary = HerculesAirframe.GUNS[i].merged(HerculesAirframe.gun_mount(i))
		var muzzle := Vector3(INF, 0.0, 0.0)
		for p in _points(frame, frame.find_child(String(gun["name"]), true, false) as MeshInstance3D):
			if p.x < muzzle.x:
				muzzle = p
		var skin: float = frame.skin_out(float(gun["at"]), float(gun["high"]))
		var mount: Vector3 = frame.point(-skin, float(gun["high"]), float(gun["at"]))
		aimed_ok = aimed_ok and muzzle.x < -(skin + 1.0) and muzzle.y < mount.y - 0.3
		aimed.append("%s's muzzle %.2f m past the skin, %.2f m under its mount" % [gun["name"], -muzzle.x - skin,
			mount.y - muzzle.y])
	frame.aim_guns([Vector2(PI * 0.5, 0.0), Vector2(PI * 0.5, 0.0), Vector2(PI * 0.5, 0.0)])
	_check("the_guns_aim_out_and_down_at_the_simulations_rest", aimed_ok, ", ".join(aimed))

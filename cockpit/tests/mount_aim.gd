extends Node
## Headless: DOES EACH GUN'S AIM LAND ON ITS OWN MOUNT, AND IS NOTHING DRAWN ON A MOUNT WITH NO GUN?
##
##   Godot --headless --path cockpit --fixed-fps 120 res://tests/mount_aim.tscn
##
## `draw_turrets_at` hands mount i's aim to `_turrets[i]`. THE ARRAY IS POSITIONAL: entry i has to
## be mount i's node, or mount i's gun points wherever the gunner on some other seat is looking.
##
## That matters because of how an empty mount has to be handled. Until 2026-09-17 `_build_turret`
## drew a stub dome and barrel on any turret seat whose gun the simulation says is not fitted -- the
## tank's second seat, and the Chinook's mount 0 -- and the obvious fix is to `continue` past an
## empty mount. BUT THE OBVIOUS FIX IS WRONG: a `continue` taken before `_turrets.append(gun)` shifts
## every later mount down one. On the tank that is harmless-looking, because the empty mount is the
## last one and it just goes unaimed. On the CHINOOK, whose mount 0 is empty and whose ramp gun is
## mount 1, the ramp gun would be drawn at the aim meant for the empty seat and its own gunner's aim
## would be dropped. A fix correct in the case under test and wrong in the one nobody is looking at.
##
## So this pins the INVARIANT rather than the symptom, on every craft that has a mount at all:
##
##   1. Nothing is drawn under a `Turret<i>` whose gun `Sim.gun_of` says is not fitted.
##   2. Aimed through the real path, `draw_turrets_at`, with a different yaw for every mount, each
##      `Turret<i>` ends up at ITS OWN yaw -- so the i-th aim reached the i-th mount.
##
## The second is green on the fleet before the fix as well as after, because today every mount is
## appended. It exists for the day somebody "simplifies" the safe form back to a bare `continue`:
## that turns it red on the Chinook (the ramp gun takes mount 0's aim) and on the tank (mount 1 is
## never aimed at all), and says which. That was done on purpose once, on 2026-09-17, to prove it.
##
## FLEET-WIDE ON PURPOSE. The hazard lives in `_build_turret`, which every craft shares, and the
## craft that shows it is not the one whose lane found it. Nothing here knows the shape of any craft:
## it asks the gun table what is fitted and asks the view where each mount points.
##
## Read RESULT=, not the exit code.

## How far a mount's yaw may be from the one it was handed, in radians. Nothing is interpolated or
## smoothed between the call and the read, so this is floating-point slack and nothing more.
const SLACK: float = 0.0001

var _failures: PackedStringArray = []


func _ready() -> void:
	var looked: int = 0
	for kind_name in Sim.Kind.keys():
		var kind: int = int(Sim.Kind[kind_name])
		var view := (load("res://objects/vehicles/vehicle_view.tscn") as PackedScene).instantiate() as VehicleView
		add_child(view)
		view.setup(0, kind)
		var mounts: Array[Node3D] = []
		for i in range(VehicleView.MAX_TURRETS):
			var mount := view.find_child("Turret%d" % i, true, false) as Node3D
			if mount != null:
				mounts.append(mount)
		if not mounts.is_empty():
			looked += 1
			_nothing_is_drawn_on_an_empty_mount(String(kind_name).to_lower(), kind, view)
			_each_aim_lands_on_its_own_mount(String(kind_name).to_lower(), view)
		view.queue_free()
	# A CHECK THAT VISITED NOTHING PASSES ON NOTHING. The fleet has mounted craft today; if a refactor
	# ever stopped this finding them, every line above would be silently green.
	_check("the_fleet_has_mounted_craft_to_look_at", looked >= 2, "%d craft with a mount" % looked)
	print("RESULT=PASS" if _failures.is_empty() else "RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


## A MOUNT WITH NO GUN DRAWS NOTHING. The gun table is the only authority on whether a gun exists.
func _nothing_is_drawn_on_an_empty_mount(label: String, kind: int, view: VehicleView) -> void:
	var phantom: PackedStringArray = []
	for i in range(VehicleView.MAX_TURRETS):
		var mount := view.find_child("Turret%d" % i, true, false) as Node3D
		if mount == null or bool(Sim.gun_of(kind, i).get("fitted", false)):
			continue
		for found in mount.find_children("*", "MeshInstance3D", true, false):
			var part := found as MeshInstance3D
			if part.mesh != null and part.is_visible_in_tree():
				phantom.append(String(view.get_path_to(part)))
	_check("%s_draws_no_gun_on_a_mount_with_no_gun_fitted" % label, phantom.is_empty(),
		"every empty mount is bare" if phantom.is_empty() else "drawn on an empty mount: " + ", ".join(phantom))


## THE i-TH AIM REACHES THE i-TH MOUNT, driven through `draw_turrets_at` and read back off the named
## node -- never off `_turrets`, which is the thing under test. A different yaw per mount, none of
## them zero, so a mount that was never aimed cannot pass by sitting at rest.
func _each_aim_lands_on_its_own_mount(label: String, view: VehicleView) -> void:
	var aimed: Array = []
	for i in range(VehicleView.MAX_TURRETS):
		aimed.append(Vector2(0.4 + 0.5 * float(i), 0.0))
	view.draw_turrets_at(aimed)
	var wrong: PackedStringArray = []
	for i in range(VehicleView.MAX_TURRETS):
		var mount := view.find_child("Turret%d" % i, true, false) as Node3D
		if mount == null:
			continue
		var wanted: float = (aimed[i] as Vector2).x
		var got: float = mount.basis.get_euler().y
		if absf(angle_difference(got, wanted)) > SLACK:
			var whose: String = "never aimed" if absf(got) <= SLACK else "given mount %d's aim" % \
				roundi((got - 0.4) / 0.5)
			wrong.append("Turret%d points at %.2f rad against its own %.2f -- %s" % [i, got, wanted, whose])
	_check("%s_aims_every_mount_with_its_own_gunners_aim" % label, wrong.is_empty(),
		"every mount took its own yaw" if wrong.is_empty() else "; ".join(wrong))


func _check(label: String, okay: bool, detail: String) -> void:
	print("[mount_aim] %s %s (%s)" % ["PASS" if okay else "FAIL", label, detail])
	if not okay:
		_failures.append(label)

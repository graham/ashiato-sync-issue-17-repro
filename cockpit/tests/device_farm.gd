extends Node
## A configurable load fixture for real authored devices.
## It deliberately uses the real catalogue, setup path and moved signal rather than a list
## of dictionaries, because a device that serializes cheaply but cannot build is not useful.
##
##   Godot --headless --path cockpit res://tests/device_farm.tscn -- --devices=500
##
## A station package is one long message, so large loads are split across stations of at
## most 100 devices. This proves a many-station aircraft without pretending a 500-control
## JSON object fits the 64 KiB per-transfer cap.

const KIND := Sim.Kind.PLANE
const DEFAULT_DEVICES := 140
const LEAST_DEVICES := 1
const MOST_DEVICES := 500
const DEVICES_PER_STATION := 100
const MIX: Array[StringName] = [&"CommandButton", &"MfdPanel", &"FlightStick", &"ToggleSwitch",
	&"GuardedToggleSwitch", &"RotaryKnob"]
var _failures: PackedStringArray = []

func _check(label: String, ok: bool, detail: String) -> void:
	print("[device_farm] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok: _failures.append(label)

func _ready() -> void:
	var requested := _requested_devices()
	_check("the_requested_device_count_is_bounded", requested in range(LEAST_DEVICES, MOST_DEVICES + 1),
		"%d devices; allowed %d..%d" % [requested, LEAST_DEVICES, MOST_DEVICES])
	if requested < LEAST_DEVICES or requested > MOST_DEVICES:
		_finish()
		return
	# GDScript closures capture scalar locals by value.  Keep the counter in a container so
	# the callback and this assertion observe the same number.
	var moved: Array = []
	var made: Array[VehicleControl] = []
	var stations: Array[Node3D] = []
	for index in range(requested):
		var seat: int = index / DEVICES_PER_STATION
		while stations.size() <= seat:
			var station := Node3D.new()
			station.name = "Station_%d" % stations.size()
			add_child(station)
			stations.append(station)
		var part: StringName = MIX[index % MIX.size()]
		var control := ControlCatalogue.make(part)
		control.name = "%s_%03d" % [part, index]
		(stations[seat] as Node3D).add_child(control); control.setup(seat)
		control.moved.connect(func(_which: VehicleControl): moved.append(true))
		# The same settling choke point every hand-driven control reaches.  `apply` is
		# deliberately a remote visual update and must not emit a command.
		control._settle(Vector2(0.0, 0.73))
		made.append(control)
	_check("builds_the_requested_device_count", made.size() == requested,
		"%d devices across %d stations" % [made.size(), stations.size()])
	_check("every_device_has_a_stable_unique_id", _unique_names(made), "%d ids" % made.size())
	_check("device_changes_report_once_each", moved.size() == requested, "%d moved events" % moved.size())
	var bytes: int = 0
	var biggest: int = 0
	var layouts_fit: bool = true
	var layouts_validate: bool = true
	var refusal := ""
	for seat in range(stations.size()):
		var layout := CockpitLayout.of_station(KIND, seat, stations[seat])
		var size := JSON.stringify(layout).to_utf8_buffer().size()
		bytes += size; biggest = maxi(biggest, size)
		layouts_fit = layouts_fit and size <= 65536
		var why := CraftPackage.validate_station(KIND, seat, layout)
		if why != "": refusal = why
		layouts_validate = layouts_validate and why == ""
	_check("each_station_layout_stays_inside_the_long_message_cap", layouts_fit,
		"%d bytes total; biggest station %d" % [bytes, biggest])
	_check("package_validator_accepts_the_farm", layouts_validate, refusal)
	for station in stations: station.queue_free()
	_finish()


func _requested_devices() -> int:
	for argument in OS.get_cmdline_user_args():
		var text := String(argument)
		if text.begins_with("--devices="):
			var asked := text.trim_prefix("--devices=")
			return int(asked) if asked.is_valid_int() else 0
	return DEFAULT_DEVICES


func _finish() -> void:
	print("[device_farm] RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL"))
	get_tree().quit(0 if _failures.is_empty() else 1)

func _unique_names(controls: Array[VehicleControl]) -> bool:
	var seen: Dictionary = {}
	for control in controls:
		if seen.has(control.name): return false
		seen[control.name] = true
	return true

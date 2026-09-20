extends Node
## Headless contract for semantic device routing. It deliberately tests the package-level
## signal rather than a hand pose: the resulting channel/value is what travels on the
## existing server-authoritative input frame.

const KIND := Sim.Kind.PLANE
var _failures: PackedStringArray = []

func _check(label: String, ok: bool, detail: String) -> void:
	print("[device_router] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok: _failures.append(label)

func _ready() -> void:
	var binding := DeviceSignalRouter.binding_of(Sim.Channel.THROTTLE, 255)
	var device := {"device_id": "seat0/throttle.main", "binding": binding}
	var middle := DeviceSignalRouter.resolve(KIND, device,
		{"device_id": "seat0/throttle.main", "binding": "bus.0", "phase": "change", "value": 0.5})
	_check("quantizes_a_semantic_binding_to_the_native_bus", not middle.has("error") and int(middle["channel"]) == Sim.Channel.THROTTLE and int(middle["value"]) in range(127, 129), str(middle))
	_check("rejects_a_signal_claiming_another_device", DeviceSignalRouter.resolve(KIND, device,
		{"device_id": "seat0/forged", "binding": "bus.0", "phase": "change", "value": 0.5}).has("error"), "identity checked")
	_check("rejects_an_unfitted_or_forged_binding", DeviceSignalRouter.resolve(KIND,
		{"device_id": "seat0/throttle.main", "binding": DeviceSignalRouter.binding_of(99, 255)},
		{"device_id": "seat0/throttle.main", "binding": "bus.99", "phase": "change", "value": 0.5}).has("error"), "schema checked")
	_check("rejects_non_finite_input", DeviceSignalRouter.resolve(KIND, device,
		{"device_id": "seat0/throttle.main", "binding": "bus.0", "phase": "change", "value": NAN}).has("error"), "finite checked")
	var below := DeviceSignalRouter.resolve(KIND, device,
		{"device_id": "seat0/throttle.main", "binding": "bus.0", "phase": "change", "value": -2.0})
	var above := DeviceSignalRouter.resolve(KIND, device,
		{"device_id": "seat0/throttle.main", "binding": "bus.0", "phase": "release", "value": 2.0})
	_check("clamps_to_the_schema_domain", int(below.get("value", -1)) == 0 and int(above.get("value", -1)) == 255, "%s / %s" % [below, above])
	var routed := 0
	for count in [100, 250, 500]:
		for index in range(count):
			var one := DeviceSignalRouter.resolve(KIND, {"device_id": "seat0/device%d" % index, "binding": binding},
				{"device_id": "seat0/device%d" % index, "binding": "bus.0", "phase": "change", "value": float(index % 256) / 255.0})
			if not one.has("error"): routed += 1
	_check("routes_the_100_250_and_500_device_load", routed == 850, "%d resolved" % routed)
	print("[device_router] RESULT=%s" % ("PASS" if _failures.is_empty() else "FAIL"))
	get_tree().quit(0 if _failures.is_empty() else 1)

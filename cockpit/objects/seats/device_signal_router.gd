extends RefCounted
class_name DeviceSignalRouter
## The only route from a builder-addressable physical device to the live command bus.
##
## Devices are deliberately many-to-one endpoints: a guarded toggle, MFD key and physical
## lever can all name the same semantic binding. The router resolves that binding to one of
## the craft schema's bounded native channels, quantizes once, and then uses the existing
## `VehicleView.propose` -> `Sim.send_command` input-frame path. That path reaches the
## authoritative server, carries rollback sequencing, and is the only gameplay transport
## permitted by cockpit's network rules. Hit pose is presentation/haptics data and never
## enters the simulation packet.

const VERSION := 1
const TYPE_BUS_CHANNEL := "bus_channel"
const PHASE_CHANGE := "change"
const PHASE_PRESS := "press"
const PHASE_RELEASE := "release"

## `(kind, seat, stable-device-id, binding)` -> last quantized value. A physical control
## emits many motion samples; only an actual quantized change may consume command bandwidth.
static var _last_sent: Dictionary = {}

static func binding_of(channel: int, value_range: int) -> Dictionary:
	return {"version": VERSION, "type": TYPE_BUS_CHANNEL, "id": "bus.%d" % channel,
		"channel": channel, "range": maxi(value_range, 1)}


static func route(kind: int, seat: int, control: VehicleControl, view: VehicleView = null) -> Dictionary:
	if control == null:
		return {"error": "missing device"}
	var stable_id := control.device_id if not control.device_id.strip_edges().is_empty() else "seat%d/%s" % [seat, control.name]
	var binding := control.signal_binding if not control.signal_binding.is_empty() else binding_of(control.channel, control.channel_range)
	var device := {"device_id": stable_id, "binding": binding}
	var intent := {"device_id": device["device_id"], "binding": (device["binding"] as Dictionary).get("id", ""),
		"phase": PHASE_CHANGE, "value": control.value.y}
	var resolved := resolve(kind, device, intent)
	if resolved.has("error"):
		return resolved
	# Entity scope prevents a command on one same-kind vehicle suppressing the first command
	# after the player boards another or reconnects.
	var key := "%d/%d/%d/%s/%s" % [view.entity if view != null else 0, kind, seat, intent["device_id"], intent["binding"]]
	var wanted := int(resolved["value"])
	if int(_last_sent.get(key, -999999)) == wanted:
		return {"accepted": true, "sent": false, "channel": int(resolved["channel"]), "value": wanted}
	_last_sent[key] = wanted
	if view != null:
		if view.shown_value(int(resolved["channel"])) != wanted:
			view.propose(int(resolved["channel"]), wanted)
	else:
		Sim.send_command(int(resolved["channel"]), wanted)
	return {"accepted": true, "sent": true, "channel": int(resolved["channel"]), "value": wanted}


## Pure validation/translation seam for authoring, loopback and hostile-input harnesses.
## The future native SignalRegistry must repeat this against the admitted package revision;
## current native servers already validate fitted channel, range and seat authority when the
## resulting command arrives in the input frame.
static func resolve(kind: int, device: Dictionary, intent: Dictionary) -> Dictionary:
	var device_id := String(device.get("device_id", ""))
	if device_id.is_empty() or device_id != String(intent.get("device_id", "")):
		return {"error": "unknown device"}
	var binding := device.get("binding", {}) as Dictionary
	if int(binding.get("version", -1)) != VERSION or String(binding.get("type", "")) != TYPE_BUS_CHANNEL:
		return {"error": "unsupported binding"}
	if String(binding.get("id", "")) != String(intent.get("binding", "")):
		return {"error": "binding does not belong to device"}
	var channel := int(binding.get("channel", -1))
	var schema_range := _range_for(kind, channel)
	if schema_range < 0:
		return {"error": "craft does not fit binding channel"}
	var raw: Variant = intent.get("value", 0.0)
	if not (raw is float or raw is int) or not is_finite(float(raw)):
		return {"error": "signal value is not finite"}
	var phase := String(intent.get("phase", PHASE_CHANGE))
	if phase != PHASE_CHANGE and phase != PHASE_PRESS and phase != PHASE_RELEASE:
		return {"error": "unknown signal phase"}
	var requested_range := maxi(int(binding.get("range", schema_range)), 1)
	var normalized := clampf(float(raw), 0.0, 1.0)
	# A package cannot inflate an existing channel's range. Quantizing to the native schema
	# makes every client produce the exact same integer command for a fraction.
	var value := clampi(int(round(normalized * float(requested_range))), 0, requested_range)
	value = clampi(value, 0, schema_range)
	return {"channel": channel, "value": value, "phase": phase,
		"binding": String(binding["id"])}


static func _range_for(kind: int, channel: int) -> int:
	for row_any in Sim.schema_of(kind).get("channels", []) as Array:
		var row := row_any as Dictionary
		if int(row.get("channel", -1)) == channel:
			return maxi(int(row.get("range", 0)), 0)
	return -1


## FORGET WHAT WAS LAST SENT ON ONE CHANNEL, for whoever has just proposed on it without the router. The signal lamp's
## seat does, when it says there is no lamp any more (`PilotRig._say_whether_i_have_a_lamp`). Without this a lamp placed
## again and held in the same hand as the last one sends nothing, because the router remembers that value as already sent.
static func forget_channel(channel: int) -> void:
	var tail := "/bus.%d" % channel
	for key in _last_sent.keys():
		if String(key).ends_with(tail):
			_last_sent.erase(key)


static func reset_for_test() -> void:
	_last_sent.clear()

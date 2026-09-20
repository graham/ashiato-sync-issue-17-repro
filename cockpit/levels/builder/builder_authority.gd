extends RefCounted
class_name BuilderAuthority
## The builder's semantic boundary. LongTransfer owns bytes, pacing and expiry; this owns
## who may edit which station and whether a decoded layout is safe to instantiate.

const PROPOSAL := "proposal"
const RELAY := "relay"
const SAVE := "save"
const BOARD := "board"
const READY := "ready"
const MOST_VERSION_BYTES: int = 32
const POSITION_MARGIN: float = 0.05


static func decode(bytes: PackedByteArray) -> Dictionary:
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	return parsed as Dictionary if parsed is Dictionary else {}


static func encode(document: Dictionary) -> PackedByteArray:
	return JSON.stringify(document).to_utf8_buffer()


static func envelope_is_valid(bytes: PackedByteArray) -> bool:
	var document := decode(bytes)
	if document.is_empty():
		return false
	var op := String(document.get("op", ""))
	if op not in [PROPOSAL, RELAY, SAVE, BOARD, READY]:
		return false
	for key in ["entity", "kind", "seat", "revision"]:
		if not document.has(key) or not _integral(document[key]): return false
	var kind := int(document["kind"])
	if kind == Sim.Kind.SEGWAY or not VehicleCatalogue.pilotable_kinds().has(kind): return false
	if typeof(document.get("version", null)) != TYPE_STRING: return false
	if op == RELAY:
		if int(document["seat"]) != -1 or int(document["revision"]) != 0: return false
		if not (document.get("layouts", null) is Dictionary) or not (document.get("revisions", null) is Dictionary): return false
		var layouts := document["layouts"] as Dictionary
		var revisions := document["revisions"] as Dictionary
		var seats := (Sim.geometry_of(int(document["kind"])).get("seat_poses", []) as Array).size()
		if layouts.size() > seats or revisions.size() != layouts.size(): return false
		var controls := 0
		for key in layouts:
			if not String(key).is_valid_int() or int(key) < 0 or int(key) >= seats or not (layouts[key] is Dictionary) or not revisions.has(String(key)) \
					or not _integral(revisions[String(key)]): return false
			controls += ((layouts[key] as Dictionary).get("controls", []) as Array).size()
		for key in revisions:
			if not layouts.has(String(key)): return false
		if controls > Net.MAX_PLAYERS * CraftPackage.MOST_CONTROLS: return false
	elif op in [PROPOSAL, SAVE]:
		if int(document["seat"]) < 0:
			return false
		if not (document.get("layout", null) is Dictionary): return false
	elif op == BOARD:
		if int(document["seat"]) < 0 or int(document["revision"]) != 0: return false
		if document.has("layout") or document.has("layouts") or document.has("revisions"): return false
	else:
		if int(document["seat"]) != -1 or int(document["revision"]) != 0: return false
		if document.has("layout") or document.has("layouts") or document.has("revisions"): return false
	return int(document["entity"]) > 0 and int(document["kind"]) >= 0 and int(document["seat"]) >= -1 \
		and int(document["revision"]) >= 0 and version_is_valid(String(document["version"]))


static func version_is_valid(version: String) -> bool:
	if version.is_empty() or version.to_utf8_buffer().size() > MOST_VERSION_BYTES:
		return false
	for character in version:
		if not (character >= "a" and character <= "z") and not (character >= "0" and character <= "9") \
				and character != "_": return false
	return true


## Check content separately from the envelope. This is deliberately stricter than
## CockpitLayout.apply, whose job is to salvage an old local file rather than trust a peer.
static func validate_layout(kind: int, seat: int, layout: Dictionary) -> String:
	var why := CraftPackage.validate_station(kind, seat, layout, VehicleCatalogue.allowed(kind))
	if why != "":
		return why
	var authored := AuthoredCraftPackages.read_station(kind, seat)
	if authored.has("error"):
		return String(authored["error"])
	var shell := ((authored["station"] as Dictionary).get("shell", {}) as Dictionary)
	var half_width := maxf(0.1, float(shell.get("width", 1.30)) * 0.5 + POSITION_MARGIN)
	var depth := maxf(0.1, float(shell.get("depth", 0.92)) + POSITION_MARGIN)
	for entry_any in layout.get("controls", []) as Array:
		var entry := entry_any as Dictionary
		var at_any: Variant = entry.get("at", null)
		var facing_any: Variant = entry.get("facing", null)
		if not _three_finite(at_any) or not _three_finite(facing_any):
			return "%s has a malformed position or facing" % String(entry.get("name", "device"))
		var at := _vector(at_any)
		if absf(at.x) > half_width or at.y < 0.0 or at.y > CockpitStation.PILOT_HEIGHT + 0.3 \
				or at.z < -depth or at.z > depth * 0.5:
			return "%s is outside this station's build box" % String(entry.get("name", "device"))
	return ""


static func occupant_may_edit(server: Object, peer: int, local_client: int, entity: int, seat: int) -> bool:
	if server == null or not server.has_method("vehicle_seats"):
		return false
	var client := local_client if peer == 0 else int(server.call("client_of_peer", peer))
	var seats: PackedInt64Array = server.call("vehicle_seats", entity)
	return client > 0 and seat >= 0 and seat < seats.size() and int(seats[seat]) == client


static func _three_finite(value: Variant) -> bool:
	if not (value is Array) or (value as Array).size() != 3:
		return false
	for number in value as Array:
		if not (number is int or number is float) or not is_finite(float(number)):
			return false
	return true


static func _integral(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))


static func _vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

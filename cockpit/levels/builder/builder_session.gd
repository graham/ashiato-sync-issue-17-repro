extends Node
class_name BuilderSession
## Host-owned collaborative station documents for the builder room. Edits are whole-layout
## proposals on release; revisions make delayed documents harmless.

const STALE_MSEC: int = 15000
var world: Node = null
var room: BuilderRoom = null
var entity: int = 0
## Entity ids are per simulation world and cannot go on a wire. `entity` is this
## machine's view; `host_entity` is an opaque host token echoed in proposals.
var host_entity: int = 0
var kind: int = Sim.Kind.PLANE
var version: String = CraftPackage.DEFAULT_VERSION
var revisions: Dictionary = {} # seat -> n
var layouts: Dictionary = {} # seat -> Dictionary
var refusals: int = 0
var _rig_bound: PilotRig = null
var _snapshot_sent: Dictionary = {}
var _pending_apply: Dictionary = {}
## One whole-layout document may be in flight per seat. Further releases replace the
## desired document; the newest one is sent after the host ACK advances the revision.
## This keeps rapid desk nudges and hand movement from becoming stale writes.
var _outstanding: Dictionary = {} # seat -> {base revision, exact layout sent}
var _desired_layouts: Dictionary = {} # seat -> newest locally released layout
var _harness_boarded: bool = false
var _harness_edited: bool = false
var _harness_forged: bool = false
var _harness_bad_part: bool = false
var _harness_hand_stage: int = 0
var _harness_hand_ticks: int = 0
var _harness_saved: bool = false
var _reported_revisions: String = ""
var _snapshot_received: bool = false
var _next_snapshot_request_msec: int = 0
var _wanted_board: int = -1
var _next_board_request_msec: int = 0


func setup(level: Node, builder_room: BuilderRoom) -> void:
	world = level; room = builder_room
	kind = _kind_asked()
	var asked_version := _asked("builder-version")
	if Net.is_host and BuilderAuthority.version_is_valid(asked_version): version = asked_version
	Net.set_long_validator(&"layout", BuilderAuthority.envelope_is_valid)
	Net.long_message_arrived.connect(_on_long_message)
	room.chose_craft.connect(choose_craft)
	room.chose_version.connect(choose_version)
	room.chose_save.connect(request_save)
	room.chose_board.connect(request_board)
	room.show_selection(kind, version, "Choose this craft on CRAFT, turn on BUILD, and release a device to share it.")
	set_process(true)


func _exit_tree() -> void:
	Net.set_long_validator(&"layout", Callable())


func _process(_delta: float) -> void:
	if entity == 0:
		entity = _find_builder_entity()
	if entity > 0:
		room.inspect(world.call("view_of", entity) as VehicleView)
	var current_rig: PilotRig = world.get("rig") as PilotRig
	if current_rig != _rig_bound:
		_bind_rig(current_rig)
	if Net.is_host and Net.is_networked():
		var present: PackedInt32Array = multiplayer.get_peers()
		for old_peer in _snapshot_sent.keys():
			if int(old_peer) not in present: _snapshot_sent.erase(old_peer)
		for peer in present:
			if Net.admits(int(peer)) and not _snapshot_sent.has(peer):
				_send_snapshot(int(peer)); _snapshot_sent[peer] = true
	elif Net.is_networked() and not _snapshot_received and Time.get_ticks_msec() >= _next_snapshot_request_msec:
		_request_snapshot()
	if not Net.is_host and _wanted_board >= 0:
		var aboard := current_rig != null and current_rig.vehicle_view() != null \
			and current_rig.vehicle_view().entity == entity and current_rig.seat_index() == _wanted_board
		if aboard:
			_wanted_board = -1
		elif Time.get_ticks_msec() >= _next_board_request_msec:
			_send_board(_wanted_board)
	for seat in _pending_apply.keys():
		if _apply_to_view(int(seat), _pending_apply[seat] as Dictionary): _pending_apply.erase(seat)
	_drive_harness(current_rig)


func spawn_on_host() -> int:
	if Sim.server == null or not Net.is_host:
		return 0
	if host_entity != 0:
		return host_entity
	# Preserve the craft/model local origin exactly; lift the entity origin only by its
	# native half-height so the native box rests on the room floor.  Server and client
	# entity handles deliberately come from separate worlds; keep the server token for
	# authority and let _process find the replicated client handle used by VehicleView.
	var half := Sim.geometry_of(kind).get("extents", Vector3.ONE) as Vector3
	host_entity = Sim.spawn_vehicle(kind, Vector3(0.0, half.y, 0.0), 0.0, Vector3.ZERO)
	entity = 0
	_load_defaults()
	return host_entity


func choose_craft(wanted: int) -> void:
	if not Net.is_host:
		room.show_selection(kind, version, "Only the host chooses the workshop craft.")
		return
	if not VehicleCatalogue.pilotable_kinds().has(wanted) or wanted == Sim.Kind.SEGWAY:
		_refuse("That craft is not available in the workshop."); return
	if host_entity != 0 and _occupied():
		_refuse("Everybody must leave the parked craft before it is changed."); return
	if host_entity != 0 and not bool(Sim.server.despawn_vehicle(host_entity)):
		_refuse("The simulation would not remove the parked craft."); return
	kind = wanted; entity = 0; host_entity = 0; revisions.clear(); layouts.clear(); _snapshot_sent.clear()
	_pending_apply.clear(); _outstanding.clear(); _desired_layouts.clear()
	spawn_on_host()
	room.show_selection(kind, version, "Parked %s at model origin 0,0,0." % Sim.kind_name(kind))


func choose_version(wanted: String) -> void:
	if not Net.is_host:
		room.show_selection(kind, version, "Only the host names the shared package version.")
		return
	wanted = wanted.strip_edges()
	if not BuilderAuthority.version_is_valid(wanted):
		_refuse("A version is 1-%d lowercase letters, digits, or underscores." % BuilderAuthority.MOST_VERSION_BYTES)
		return
	version = wanted
	room.show_selection(kind, version, "Version %s." % version)


func propose_current_layout() -> void:
	var rig: PilotRig = world.get("rig") as PilotRig
	var view: VehicleView = rig.vehicle_view() if rig != null else null
	if view == null or view.entity != entity or rig.seat_index() < 0:
		_refuse("Sit in the parked craft before sharing a layout."); return
	var station: CockpitStation = view.station_for(rig.seat_index())
	if station == null:
		_refuse("That station is not ready yet."); return
	var seat := rig.seat_index()
	var layout := CockpitLayout.of_station(kind, seat, station)
	if Net.is_host:
		_accept_proposal(0, _document(BuilderAuthority.PROPOSAL, seat, layout, int(revisions.get(seat, 0))))
	else:
		_desired_layouts[seat] = layout
		if not _outstanding.has(seat): _send_desired(seat)


func request_save() -> void:
	if Net.is_host:
		_save_all()
	else:
		var rig: PilotRig = world.get("rig") as PilotRig
		var view: VehicleView = rig.vehicle_view() if rig != null else null
		if view == null or view.entity != entity:
			_refuse("Sit in the parked craft before asking the host to save."); return
		var station: CockpitStation = view.station_for(rig.seat_index())
		if station == null: return
		var document := _document(BuilderAuthority.SAVE, rig.seat_index(),
			CockpitLayout.of_station(kind, rig.seat_index(), station), int(revisions.get(rig.seat_index(), 0)))
		_say(Net.send_long(1, &"layout", BuilderAuthority.encode(document), STALE_MSEC))


func request_board(seat: int) -> void:
	if not Net.is_host:
		_wanted_board = seat
		_send_board(seat)
		return
	_send_board(seat)


func _send_board(seat: int) -> void:
	_next_board_request_msec = Time.get_ticks_msec() + 500
	var document := _document(BuilderAuthority.BOARD, seat, {}, 0)
	document.erase("layout")
	if Net.is_host: _accept_board(0, document)
	else: _say(Net.send_long(1, &"layout", BuilderAuthority.encode(document), STALE_MSEC))


func _on_long_message(from_peer: int, message_kind: StringName, bytes: PackedByteArray) -> void:
	if message_kind != &"layout" or not BuilderRoom.claims(world.level): return
	var document := BuilderAuthority.decode(bytes)
	if Net.is_host:
		if String(document.get("op", "")) == BuilderAuthority.READY:
			if Net.admits(from_peer): _send_snapshot(from_peer)
		elif String(document.get("op", "")) == BuilderAuthority.BOARD:
			_accept_board(from_peer, document)
		elif String(document.get("op", "")) == BuilderAuthority.PROPOSAL:
			_accept_proposal(from_peer, document)
		elif String(document.get("op", "")) == BuilderAuthority.SAVE:
			if _accept_proposal(from_peer, document): _save_all()
		else: _refuse("A client sent a layout operation it does not own.")
	elif from_peer == 1 and String(document.get("op", "")) == BuilderAuthority.RELAY:
		_apply_relay(document)


func _accept_board(peer: int, document: Dictionary) -> bool:
	var seat := int(document.get("seat", -1))
	if int(document.get("entity", 0)) != host_entity or int(document.get("kind", -1)) != kind:
		_refuse("That boarding request is for another parked craft."); return false
	if peer > 0 and not Net.admits(peer):
		_refuse("That player has not finished loading the workshop."); return false
	var client := Sim.local_client_id() if peer == 0 else int(Sim.server.client_of_peer(peer))
	var seats: PackedInt64Array = Sim.server.vehicle_seats(host_entity)
	if client <= 0 or seat < 0 or seat >= seats.size():
		_refuse("That seat does not exist on this craft."); return false
	if int(seats[seat]) == client:
		return true
	if int(seats[seat]) > 0:
		_refuse("That seat is already occupied."); return false
	# Workshop occupancy uses the native seat map for authority, but must leave the
	# display craft chocked.  Ordinary seat_client deliberately launches seat zero.
	if not bool(Sim.server.seat_client_parked(client, host_entity, seat)):
		_refuse("The host could not seat that player."); return false
	return true


func _accept_proposal(peer: int, document: Dictionary) -> bool:
	var seat := int(document.get("seat", -1)); var layout := document.get("layout", {}) as Dictionary
	if int(document.get("entity", 0)) != host_entity or int(document.get("kind", -1)) != kind:
		_refuse("That proposal is for another parked craft."); return false
	if not BuilderAuthority.occupant_may_edit(Sim.server, peer, Sim.local_client_id(), host_entity, seat):
		_refuse("A player may edit only the seat they occupy."); return false
	if int(document.get("revision", -1)) != int(revisions.get(seat, 0)):
		_refuse("That station changed before this proposal arrived; the host kept the newer revision.")
		if peer > 0: _send_snapshot(peer)
		return false
	var why := BuilderAuthority.validate_layout(kind, seat, layout)
	if why != "": _refuse("Layout refused: %s." % why); return false
	var revision := int(revisions.get(seat, 0)) + 1
	revisions[seat] = revision; layouts[seat] = layout.duplicate(true)
	if not _apply_to_view(seat, layout): _pending_apply[seat] = layout
	if Net.is_networked():
		for peer_id in multiplayer.get_peers(): _send_snapshot(int(peer_id))
	return true


func _apply_relay(document: Dictionary) -> void:
	_snapshot_received = true
	var relayed_entity := int(document.get("entity", 0)); var relayed_kind := int(document.get("kind", -1))
	if relayed_entity <= 0 or relayed_kind < 0: return
	if relayed_entity != host_entity or relayed_kind != kind:
		host_entity = relayed_entity; entity = 0; kind = relayed_kind; layouts.clear(); revisions.clear()
		_pending_apply.clear(); _outstanding.clear(); _desired_layouts.clear()
	version = String(document.get("version", CraftPackage.DEFAULT_VERSION))
	room.show_selection(kind, version, "Host parked %s." % Sim.kind_name(kind))
	var incoming_layouts := document.get("layouts", {}) as Dictionary
	var incoming_revisions := document.get("revisions", {}) as Dictionary
	for key in incoming_layouts:
		var seat := int(key); var revision := int(incoming_revisions.get(str(seat), -1))
		var layout := incoming_layouts[key] as Dictionary
		var why := BuilderAuthority.validate_layout(kind, seat, layout)
		if why != "": _refuse("Host relay refused locally: %s." % why); continue
		# A snapshot at the base revision is also an answer: the host refused that
		# document. Clear the flight slot so a newer local release can be retried.
		var was_outstanding := _outstanding.has(seat)
		var flight := _outstanding.get(seat, {}) as Dictionary
		if was_outstanding and revision >= int(flight.get("base", 0)): _outstanding.erase(seat)
		if revision < int(revisions.get(seat, -1)): continue
		if revision == int(revisions.get(seat, -1)) and not was_outstanding: continue
		revisions[seat] = revision; layouts[seat] = layout.duplicate(true)
		var desired := _desired_layouts.get(seat, {}) as Dictionary
		var sent := flight.get("layout", {}) as Dictionary
		if was_outstanding and revision > int(flight.get("base", 0)) and not desired.is_empty() \
				and not _same_layout(desired, sent):
			# Leave the newer local pose visible and send it against the ACKed base.
			_send_desired.call_deferred(seat)
		else:
			_desired_layouts.erase(seat)
			if not _apply_to_view(seat, layout): _pending_apply[seat] = layout


func _request_snapshot() -> void:
	_next_snapshot_request_msec = Time.get_ticks_msec() + 500
	# Before the first relay a client cannot know the host's per-world entity id or
	# selected kind. READY only proves that the application consumer and validator
	# exist; the host answers with its authoritative identity and document.
	var document := {"op": BuilderAuthority.READY, "entity": 1, "kind": Sim.Kind.PLANE,
		"seat": -1, "version": CraftPackage.DEFAULT_VERSION, "revision": 0}
	var why := Net.send_long(1, &"layout", BuilderAuthority.encode(document), STALE_MSEC)
	if why != "": push_warning("[builder] snapshot request refused: %s" % why)


func _send_desired(seat: int) -> void:
	if Net.is_host or _outstanding.has(seat) or not _desired_layouts.has(seat): return
	var document := _document(BuilderAuthority.PROPOSAL, seat, _desired_layouts[seat] as Dictionary,
		int(revisions.get(seat, 0)))
	var why := Net.send_long(1, &"layout", BuilderAuthority.encode(document), STALE_MSEC)
	if why == "":
		_outstanding[seat] = {"base": int(revisions.get(seat, 0)),
			"layout": (_desired_layouts[seat] as Dictionary).duplicate(true)}
	else: _say(why)


static func _same_layout(a: Dictionary, b: Dictionary) -> bool:
	return JSON.stringify(a) == JSON.stringify(b)


func _apply_to_view(seat: int, layout: Dictionary) -> bool:
	var view: VehicleView = world.call("view_of", entity) as VehicleView
	var station: CockpitStation = view.station_for(seat) if view != null else null
	if station != null:
		CockpitLayout.apply(layout, station, seat, VehicleCatalogue.allowed(kind), kind)
		station.setup_controls(seat)
		return true
	return false


func _send_snapshot(peer: int) -> void:
	var document := {"op": BuilderAuthority.RELAY, "entity": host_entity, "kind": kind, "seat": -1,
		"version": version, "revision": 0, "layouts": {}, "revisions": {}}
	for seat in layouts:
		document["layouts"][str(seat)] = layouts[seat]
		document["revisions"][str(seat)] = revisions.get(seat, 0)
	var bytes := BuilderAuthority.encode(document)
	if bytes.size() > LongTransfer.MOST_BYTES:
		_refuse("All station layouts total %d bytes, over the %d-byte relay cap." % [bytes.size(), LongTransfer.MOST_BYTES]); return
	var why := Net.send_long(peer, &"layout", bytes, STALE_MSEC)
	if why != "": push_warning("[builder] relay to %d refused: %s" % [peer, why])


func _save_all() -> void:
	if not Net.is_host: return
	var poses := Sim.geometry_of(kind).get("seat_poses", []) as Array
	var saved := 0
	for seat in range(poses.size()):
		var built := AuthoredCraftPackages.make_station(kind, seat)
		if built.has("error"): _refuse(String(built["error"])); return
		var station := built["station"] as CockpitStation
		if layouts.has(seat): CockpitLayout.apply(layouts[seat], station, seat, VehicleCatalogue.allowed(kind), kind)
		var result := CraftPackage.write_station(kind, seat, station, version)
		station.free()
		if result.has("error"): _refuse(String(result["error"])); return
		saved += 1
	var path := ProjectSettings.globalize_path(CraftPackage.path_for(kind, version))
	print("[builder] saved %d seats to %s" % [saved, path])
	room.show_selection(kind, version, "Host saved all %d seats in %s." % [saved, path])


func _load_defaults() -> void:
	for seat in range((Sim.geometry_of(kind).get("seat_poses", []) as Array).size()):
		var loaded := AuthoredCraftPackages.read_station(kind, seat)
		if not loaded.has("error"): layouts[seat] = (loaded["station"] as Dictionary).duplicate(true); revisions[seat] = 0


func _bind_rig(rig: PilotRig) -> void:
	_rig_bound = rig
	if rig == null: return
	if not rig.builder_layout_released.is_connected(propose_current_layout): rig.builder_layout_released.connect(propose_current_layout)


func _find_builder_entity() -> int:
	for candidate in Sim.current:
		var state := Sim.current[candidate] as Dictionary
		var half := Sim.geometry_of(kind).get("extents", Vector3.ONE) as Vector3
		if int(state.get("kind", -1)) == kind and (state.get("position", Vector3.INF) as Vector3).distance_to(Vector3(0, half.y, 0)) < 2.0:
			return int(candidate)
	return 0


func _occupied() -> bool:
	for client in Sim.server.vehicle_seats(host_entity):
		if int(client) > 0: return true
	return false


func _document(op: String, seat: int, layout: Dictionary, revision: int) -> Dictionary:
	return {"op": op, "entity": host_entity, "kind": kind, "seat": seat, "version": version,
		"revision": revision, "layout": layout}


func _refuse(words: String) -> void:
	refusals += 1; push_warning("[builder] " + words); _say(words)


func _say(words: String) -> void:
	if words.is_empty(): return
	room.show_selection(kind, version, words)
	var rig: PilotRig = world.get("rig") as PilotRig
	if rig != null and rig.clipboard != null: rig.clipboard.say(words)


func _kind_asked() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kind="):
			var wanted := arg.trim_prefix("--kind=").to_lower()
			for candidate in VehicleCatalogue.pilotable_kinds():
				if Sim.kind_name(candidate) == wanted and candidate != Sim.Kind.SEGWAY: return candidate
	return Sim.Kind.PLANE


func _drive_harness(rig: PilotRig) -> void:
	if rig == null or entity == 0: return
	var wanted_seat := _asked("builder-seat")
	if not _harness_boarded and wanted_seat.is_valid_int():
		_harness_boarded = true; request_board(int(wanted_seat))
	var edit := _asked("builder-desk")
	var view := rig.vehicle_view()
	if not _harness_edited and not edit.is_empty() and view != null and view.entity == entity:
		var pieces := edit.split(":")
		if pieces.size() == 3:
			_harness_edited = rig.builder_desk_steps_for_test(String(pieces[0]), int(pieces[1]) as Key, int(pieces[2]))
	_drive_hand_harness(rig, view)
	var forged_seat := _asked("builder-forge-seat")
	if not Net.is_host and not _harness_forged and forged_seat.is_valid_int() \
			and int(revisions.get(rig.seat_index(), 0)) >= 2:
		var loaded := AuthoredCraftPackages.read_station(kind, int(forged_seat))
		if not loaded.has("error"):
			_harness_forged = true
			var forged := _document(BuilderAuthority.PROPOSAL, int(forged_seat), loaded["station"] as Dictionary,
				int(revisions.get(int(forged_seat), 0)))
			_say(Net.send_long(1, &"layout", BuilderAuthority.encode(forged), STALE_MSEC))
	if not Net.is_host and not _harness_bad_part and _asked("builder-forge-disallowed") == "1" \
			and rig.seat_index() >= 0 and int(revisions.get(rig.seat_index(), 0)) >= 1:
		var bad_layout := (layouts.get(rig.seat_index(), {}) as Dictionary).duplicate(true)
		var controls := bad_layout.get("controls", []) as Array
		if not controls.is_empty():
			_harness_bad_part = true
			var bad := (controls[0] as Dictionary).duplicate(true); bad["part"] = "TiltLever"
			controls[0] = bad
			var bad_document := _document(BuilderAuthority.PROPOSAL, rig.seat_index(), bad_layout,
				int(revisions.get(rig.seat_index(), 0)))
			_say(Net.send_long(1, &"layout", BuilderAuthority.encode(bad_document), STALE_MSEC))
	if not Net.is_host and not _harness_saved and _asked("builder-save") == "1" \
			and view != null and view.entity == entity and rig.seat_index() >= 0 \
			and int(revisions.get(rig.seat_index(), 0)) >= 1:
		_harness_hand_ticks += 1
		if _harness_hand_ticks >= 30:
			_harness_saved = true; request_save()
	var revision_line := _revision_line()
	var peer_count := multiplayer.get_peers().size() + 1 if Net.is_networked() else 1
	var report_state := "%s/%d/%s/%s/%d/%d/%d" % [revision_line, refusals, str(_harness_boarded),
		str(_harness_edited), rig.my_vehicle(), rig.seat_index(), peer_count]
	if _asked("builder-report") == "1" and report_state != _reported_revisions:
		_reported_revisions = report_state
		print("BUILDER_REPORT role=%s entity=%d host_entity=%d kind=%d seat=%d revisions=%s refusals=%d clients=%d edited=%s hand=%d" % [
			"host" if Net.is_host else "client", entity, host_entity, kind,
			rig.seat_index() if view != null and view.entity == entity else -1, revision_line, refusals,
			peer_count, str(_harness_edited), _harness_hand_stage])


func _revision_line() -> String:
	var seats: Array = revisions.keys(); seats.sort()
	var parts: PackedStringArray = []
	for seat in seats: parts.append("%d:%d" % [int(seat), int(revisions[seat])])
	return ",".join(parts) if not parts.is_empty() else "none"


func _occupant_client_for_harness() -> int:
	for pilot_any in Sim.pilots:
		var pilot := pilot_any as Dictionary
		if int(pilot.get("vehicle", 0)) == entity: return int(pilot.get("client", 0))
	return 0


func _drive_hand_harness(rig: PilotRig, view: VehicleView) -> void:
	var asked := _asked("builder-hand")
	if asked.is_empty() or _harness_hand_stage >= 5 or view == null or view.entity != entity: return
	var pieces := asked.split(":")
	if pieces.size() != 2: return
	var station := view.station_for(rig.seat_index())
	var control := station.get_node_or_null(String(pieces[0])) as VehicleControl if station != null else null
	if control == null: return
	var pose := control.global_transform * Transform3D(Basis.IDENTITY, control._grab_point())
	if _harness_hand_stage >= 2: pose.origin += Vector3(float(pieces[1]), 0.0, 0.0)
	rig.build_the_cockpit(true); rig.force_hand(0, pose)
	_harness_hand_ticks += 1
	match _harness_hand_stage:
		0:
			rig.force_grip(0, 0.0)
			if _harness_hand_ticks >= 3: _harness_hand_stage = 1; _harness_hand_ticks = 0
		1:
			rig.force_grip(0, 1.0)
			if _harness_hand_ticks >= 4: _harness_hand_stage = 2; _harness_hand_ticks = 0
		2:
			rig.force_grip(0, 1.0)
			if _harness_hand_ticks >= 4: _harness_hand_stage = 3; _harness_hand_ticks = 0
		3:
			rig.force_grip(0, 0.0)
			if _harness_hand_ticks >= 4: _harness_hand_stage = 4; _harness_hand_ticks = 0
		4:
			rig.force_grip(0, -1.0); rig.force_hand(0, null); _harness_hand_stage = 5


static func _asked(name: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name): return arg.get_slice("=", 1)
	return ""

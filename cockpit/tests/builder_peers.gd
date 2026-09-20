extends Node
## Three real Godot processes over ENet prove the builder's production boundary: a
## seated remote player moves their own station several times, the host accepts and
## relays the coalesced edit, a forged edit for another seat is refused, and a late
## joiner receives the already-authoritative document.

const FIRST_PORT: int = 48010
const PORTS: int = 8
const PATIENCE_SECONDS: float = 75.0
const BURY_SECONDS: float = 5.0

var failures: PackedStringArray = []
var children: Array[int] = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[builder_peers] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok: failures.append(label)


func _ready() -> void:
	_clear_saved_package()
	var result := await _run_three()
	var host := _latest_builder(result.get("host", ""))
	var editor := _latest_builder(result.get("editor", ""))
	var late := _latest_builder(result.get("late", ""))
	var late_first := _first_builder(result.get("late", ""))
	_check("a_host_and_two_clients_are_admitted_to_the_builder",
		bool(result.get("started", false)) and int(host.get("clients", 0)) == 3
		and int(late.get("clients", 0)) == 3,
		"host %s late %s" % [host, late])
	_check("all_three_identify_the_same_parked_craft_and_kind",
		int(host.get("entity", 0)) > 0 and int(editor.get("entity", 0)) > 0 and int(late.get("entity", 0)) > 0
		and host.get("host_entity") == editor.get("host_entity") and host.get("host_entity") == late.get("host_entity")
		and host.get("kind") == editor.get("kind")
		and host.get("kind") == late.get("kind"),
		"host %s editor %s late %s" % [host, editor, late])
	_check("the_remote_occupant_s_rapid_releases_are_accepted_and_relayed",
		_revision(editor, 0) >= 2 and _revision(host, 0) == _revision(editor, 0),
		"host %s editor %s" % [host.get("revisions"), editor.get("revisions")])
	_check("a_forged_proposal_for_another_seat_is_refused",
		int(host.get("refusals", 0)) >= 2 and _revision(host, 2) == 0,
		"refusals %s revisions %s" % [host.get("refusals"), host.get("revisions")])
	_check("a_disallowed_part_crosses_the_wire_and_is_refused_by_the_host",
		int(host.get("refusals", 0)) >= 2, "host refusals %s" % host.get("refusals"))
	_check("the_late_joiner_receives_the_first_layout_then_moves_seat_one_by_hand",
		_revision(late_first, 0) >= 2 and _revision(late, 0) == _revision(host, 0) and _revision(late, 0) >= 2
		and _revision(late, 1) >= 2 and _revision(editor, 1) == _revision(host, 1),
		"host %s late %s" % [host.get("revisions"), late.get("revisions")])
	_check_saved_package(String(result.get("host", "")))
	_finish()


func _run_three() -> Dictionary:
	var project := ProjectSettings.globalize_path("res://")
	# THIS CHECKOUT'S PORTS (`TestPorts`), and a held one is passed over silently before any child is started on it.
	for port in range(TestPorts.of(FIRST_PORT), TestPorts.of(FIRST_PORT) + PORTS):
		if TestPorts.is_held(port):
			continue
		var logs := {
			"host": ProjectSettings.globalize_path(TestPorts.log_for("builder_peers", "host")),
			"editor": ProjectSettings.globalize_path(TestPorts.log_for("builder_peers", "editor")),
			"late": ProjectSettings.globalize_path(TestPorts.log_for("builder_peers", "late"))}
		for path in logs.values():
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		children.append(OS.create_process(OS.get_executable_path(), ["--headless", "--xr-mode", "off", "--desktop-only", "--fixed-fps", "120", "--log-file",
			logs.host, "--path", project, "--", "--host=%d" % port, "--world=builder", "--kind=gunship",
			"--builder-report=1", "--builder-version=builder_peers", "--builder-test-files=1"]))
		# A command-line join is a single attempt. Let the host bind and finish the
		# workshop before starting either real client, especially on a loaded CI host.
		var host_ready := false
		var host_wait_started := Time.get_ticks_msec()
		while Time.get_ticks_msec() - host_wait_started < 10000:
			var host_start := _read(logs.host)
			if host_start.contains("BOOT_ERROR=Could not listen"): break
			if not _latest_builder(host_start).is_empty(): host_ready = true; break
			await get_tree().process_frame
		if not host_ready:
			var occupied := _read(logs.host).contains("BOOT_ERROR=Could not listen")
			await _bury_children()
			if occupied: continue
			return {"started": false, "host": _read(logs.host), "editor": "", "late": ""}
		children.append(OS.create_process(OS.get_executable_path(), ["--headless", "--xr-mode", "off", "--desktop-only", "--fixed-fps", "120", "--log-file",
			logs.editor, "--path", project, "--", "--join=127.0.0.1:%d" % port,
			"--builder-report=1", "--builder-seat=0", "--builder-desk=Yoke:%d:8" % KEY_RIGHT,
			"--builder-forge-seat=2", "--builder-test-files=1"]))
		# This peer is deliberately late: do not start it until A's coalesced edit is
		# authoritative.  Starting both clients together called B "late" without ever
		# proving that its first application snapshot contained an existing edit.
		var first_edit_until := Time.get_ticks_msec() + 30000
		while Time.get_ticks_msec() < first_edit_until:
			var first_host := _latest_builder(_read(logs.host))
			var first_editor := _latest_builder(_read(logs.editor))
			if _revision(first_host, 0) >= 2 and _revision(first_editor, 0) == _revision(first_host, 0):
				break
			await get_tree().create_timer(0.1).timeout
		if _revision(_latest_builder(_read(logs.host)), 0) < 2:
			var early := {"started": true, "host": _read(logs.host), "editor": _read(logs.editor), "late": ""}
			await _bury_children()
			return early
		children.append(OS.create_process(OS.get_executable_path(), ["--headless", "--xr-mode", "off", "--desktop-only", "--fixed-fps", "120", "--log-file",
			logs.late, "--path", project, "--", "--join=127.0.0.1:%d" % port,
			"--builder-report=1", "--builder-seat=1", "--builder-hand=Trigger:0.05",
			"--builder-forge-disallowed=1", "--builder-save=1", "--builder-test-files=1"]))
		var late_started := true
		var since := Time.get_ticks_msec()
		var busy := false
		while Time.get_ticks_msec() - since < int(PATIENCE_SECONDS * 1000.0):
			var host_text := _read(logs.host); var editor_text := _read(logs.editor)
			busy = host_text.contains("BOOT_ERROR=Could not listen")
			if busy: break
			var host_report := _latest_builder(host_text)
			var editor_report := _latest_builder(editor_text)
			if late_started:
				var late_text := _read(logs.late)
				var late_report := _latest_builder(late_text)
				if _revision(late_report, 1) >= 2 \
						and _revision(editor_report, 0) == _revision(host_report, 0) \
						and _revision(editor_report, 1) == _revision(host_report, 1) \
						and _revision(late_report, 0) == _revision(host_report, 0) \
						and _revision(late_report, 1) == _revision(host_report, 1) \
						and host_text.contains("[builder] saved") \
						and int(_latest_builder(host_text).get("refusals", 0)) >= 2 \
						and int(host_report.get("clients", 0)) == 3 \
						and int(late_report.get("clients", 0)) == 3:
					var out := {"started": true, "host": host_text, "editor": editor_text, "late": late_text}
					await _bury_children()
					return out
			await get_tree().create_timer(0.1).timeout
		var out := {"started": not busy, "host": _read(logs.host), "editor": _read(logs.editor), "late": _read(logs.late)}
		await _bury_children()
		if busy:
			print("[builder_peers] port %d is in use; trying %d" % [port, port + 1])
			continue
		return out
	print("[builder_peers] %s" % TestPorts.busy(FIRST_PORT, PORTS))
	return {"started": false, "host": "", "editor": "", "late": ""}


func _check_saved_package(host_text: String) -> void:
	var seat0 := CraftPackage.read_station(Sim.Kind.GUNSHIP, 0, "builder_peers")
	var seat1 := CraftPackage.read_station(Sim.Kind.GUNSHIP, 1, "builder_peers")
	var all_valid := host_text.contains("[builder] saved 4 seats")
	for seat in range(4): all_valid = all_valid and not CraftPackage.read_station(
		Sim.Kind.GUNSHIP, seat, "builder_peers").has("error")
	_check("host_save_writes_and_reloads_every_seat_from_the_test_package",
		all_valid, "seat0 %s seat1 %s" % [seat0.get("error", "ok"), seat1.get("error", "ok")])
	var original0 := AuthoredCraftPackages.read_station(Sim.Kind.GUNSHIP, 0)
	var original1 := AuthoredCraftPackages.read_station(Sim.Kind.GUNSHIP, 1)
	var saved_desk := _device_at(seat0.get("layout", {}), "Yoke")
	var old_desk := _device_at(original0.get("station", {}), "Yoke")
	var saved_hand := _device_at(seat1.get("layout", {}), "Trigger")
	var old_hand := _device_at(original1.get("station", {}), "Trigger")
	var finite := saved_desk.is_finite() and old_desk.is_finite() and saved_hand.is_finite() and old_hand.is_finite()
	var desk_delta := saved_desk.distance_to(old_desk) if finite else -1.0
	var hand_delta := saved_hand.distance_to(old_hand) if finite else -1.0
	_check("saved_layout_contains_the_desk_and_hand_moves", all_valid and finite and desk_delta >= 0.02 and hand_delta >= 0.04,
		"Yoke %.3f m, Trigger %.3f m" % [desk_delta, hand_delta])


func _device_at(layout_any: Variant, name: String) -> Vector3:
	var layout := layout_any as Dictionary
	for entry_any in layout.get("controls", []) as Array:
		var entry := entry_any as Dictionary
		if String(entry.get("name", "")) == name:
			var at := entry.get("at", []) as Array
			if at.size() == 3: return Vector3(float(at[0]), float(at[1]), float(at[2]))
	return Vector3.INF


func _clear_saved_package() -> void:
	var root := CraftPackage.path_for(Sim.Kind.GUNSHIP, "builder_peers")
	for seat in range(4):
		var path := root.path_join("stations/seat%d.json" % seat)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var craft := root.path_join("craft.json")
	if FileAccess.file_exists(craft): DirAccess.remove_absolute(ProjectSettings.globalize_path(craft))


func _latest_builder(text: String) -> Dictionary:
	var out := {}
	for line in text.split("\n"):
		if line.begins_with("BUILDER_REPORT "): out = _fields(line)
	return out


func _first_builder(text: String) -> Dictionary:
	for line in text.split("\n"):
		if line.begins_with("BUILDER_REPORT "): return _fields(line)
	return {}


func _fields(line: String) -> Dictionary:
	var out := {}
	for token in line.strip_edges().split(" ", false):
		if token.contains("="): out[token.get_slice("=", 0)] = token.substr(token.find("=") + 1)
	return out


func _revision(report: Dictionary, seat: int) -> int:
	for part in String(report.get("revisions", "")).split(",", false):
		if part.get_slice(":", 0) == str(seat): return int(part.get_slice(":", 1))
	return -1


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _bury_children() -> void:
	var dying := children.duplicate(); children.clear()
	for pid in dying:
		if pid > 0 and OS.is_process_running(pid): OS.kill(pid)
	var since := Time.get_ticks_msec()
	for pid in dying:
		while pid > 0 and OS.is_process_running(pid) and Time.get_ticks_msec() - since < int(BURY_SECONDS * 1000.0):
			await get_tree().create_timer(0.05).timeout


func _finish() -> void:
	for pid in children:
		if pid > 0 and OS.is_process_running(pid): OS.kill(pid)
	print("RESULT=%s" % ("PASS" if failures.is_empty() else "FAIL %s" % ", ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)

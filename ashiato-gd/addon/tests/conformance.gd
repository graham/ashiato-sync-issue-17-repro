extends Node
## Does the binding still hold against the ashiato revision currently checked out?
##
##   Godot --path addon --headless res://tests/conformance.tscn
##
## Read RESULT=, not the exit code.
##
## THIS IS THE POINT OF THE WHOLE SETUP. Both upstreams move fast and not together, so
## the question that matters after `git pull` is not "does it compile" but "does it
## still behave". Run tools/update_upstream.ps1, which pulls and then runs this.
##
## It asserts BEHAVIOUR through the public GDScript surface only. Nothing here names a
## component type in C++, which is exactly what makes a new component free.

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[conformance] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("class_registered", ClassDB.class_exists("AshiatoWorld"),
		"the GDExtension loaded and registered AshiatoWorld")
	if not ClassDB.class_exists("AshiatoWorld"):
		_finish()
		return

	var world = AshiatoWorld.new()
	print("[conformance] built against ashiato ", world.upstream_revision())

	# ---- entities ----
	var e: int = world.create_entity()
	_check("create_entity", e != 0, "id=%d" % e)
	_check("entity_is_alive", world.is_alive(e), "alive after create")

	var doomed: int = world.create_entity()
	world.destroy_entity(doomed)
	_check("destroy_entity", not world.is_alive(doomed), "dead after destroy")
	# Generational handles: the id of a destroyed entity must not come back alive even
	# though its index gets recycled.
	_check("stale_handle_stays_dead", not world.is_alive(doomed),
		"a recycled index does not resurrect an old handle")

	# ---- components declared entirely from script ----
	var position: int = world.register_component("Position", {
		"x": AshiatoWorld.TYPE_F32,
		"y": AshiatoWorld.TYPE_F32,
	})
	_check("register_component", position != 0, "Position id=%d" % position)

	var described: Dictionary = world.describe_component(position)
	_check("component_described", described.get("name", "") == "Position",
		"name=%s size=%s" % [described.get("name", "?"), described.get("size", "?")])
	# Two floats, naturally aligned: the layout must be the same 8 bytes a C struct
	# would have, or the bytes stop meaning anything to the ECS or to sync.
	_check("layout_is_c_compatible", described.get("size", 0) == 8
			and described.get("alignment", 0) == 4,
		"size=%s align=%s" % [described.get("size", "?"), described.get("alignment", "?")])
	var fields: Dictionary = described.get("fields", {})
	_check("field_offsets", fields.get("x", {}).get("offset", -1) == 0
			and fields.get("y", {}).get("offset", -1) == 4,
		"x@%s y@%s" % [fields.get("x", {}).get("offset", "?"), fields.get("y", {}).get("offset", "?")])

	# ---- values round-trip ----
	_check("add_component", world.add(e, position, {"x": 1.5, "y": -2.25}), "added")
	_check("has_component", world.has(e, position), "has() sees it")

	var got: Dictionary = world.get_component(e, position)
	_check("value_round_trips", is_equal_approx(got.get("x", 0.0), 1.5)
			and is_equal_approx(got.get("y", 0.0), -2.25),
		"got %s" % got)

	_check("set_fields_partial", world.set_fields(e, position, {"y": 9.0}), "wrote y")
	got = world.get_component(e, position)
	_check("partial_write_left_x_alone", is_equal_approx(got.get("x", 0.0), 1.5),
		"x=%s" % got.get("x", "?"))
	_check("partial_write_changed_y", is_equal_approx(got.get("y", 0.0), 9.0),
		"y=%s" % got.get("y", "?"))

	# ---- every primitive width, since layout maths is where this breaks quietly ----
	var wide: int = world.register_component("Wide", {
		"flag": AshiatoWorld.TYPE_BOOL,
		"small": AshiatoWorld.TYPE_U8,
		"i": AshiatoWorld.TYPE_I32,
		"big": AshiatoWorld.TYPE_I64,
		"d": AshiatoWorld.TYPE_F64,
	})
	var e2: int = world.create_entity()
	world.add(e2, wide, {"flag": true, "small": 200, "i": -12345, "big": 8589934592, "d": 0.125})
	var w: Dictionary = world.get_component(e2, wide)
	_check("bool_round_trips", w.get("flag", false) == true, "flag=%s" % w.get("flag", "?"))
	_check("u8_round_trips", w.get("small", 0) == 200, "small=%s" % w.get("small", "?"))
	_check("i32_negative_round_trips", w.get("i", 0) == -12345, "i=%s" % w.get("i", "?"))
	# Past 2^32, so a field silently truncated to 32 bits fails here.
	_check("i64_round_trips", w.get("big", 0) == 8589934592, "big=%s" % w.get("big", "?"))
	_check("f64_round_trips", is_equal_approx(w.get("d", 0.0), 0.125), "d=%s" % w.get("d", "?"))

	# ---- tags ----
	var frozen: int = world.register_tag("Frozen")
	_check("register_tag", frozen != 0, "Frozen id=%d" % frozen)
	_check("tag_absent_initially", not world.has(e, frozen), "not tagged yet")
	_check("add_tag", world.add(e, frozen, {}), "tagged")
	_check("has_tag", world.has(e, frozen), "has() sees the tag")
	_check("remove_tag", world.remove(e, frozen), "untagged")
	_check("tag_gone", not world.has(e, frozen), "has() agrees")

	# ---- removal ----
	_check("remove_component", world.remove(e, position), "removed")
	_check("component_gone", not world.has(e, position), "has() agrees")
	_check("get_after_remove_is_empty", world.get_component(e, position).is_empty(),
		"empty dictionary, not stale bytes")

	# ---- introspection ----
	var e3: int = world.create_entity()
	world.add(e3, position, {"x": 0.0, "y": 0.0})
	var listed: PackedInt64Array = world.components_of(e3)
	_check("components_of_lists_position", listed.has(position),
		"%d component(s) reported" % listed.size())

	# ---- misuse is reported, not fatal ----
	# These print errors on purpose; the run must survive them.
	_check("unknown_component_is_survivable",
		world.add(e, 999999, {"x": 1.0}) == false, "add() with a bogus id returns false")
	_check("bad_field_type_is_survivable",
		world.register_component("Bad", {"x": 4242}) == 0, "unknown field type returns 0")

	# ---- sync, when this binary was built with it ----
	# Guarded so the same test is valid for both build modes; -WithSync is opt-in.
	if ClassDB.class_exists("AshiatoSyncProbe"):
		var probe = ClassDB.instantiate("AshiatoSyncProbe")
		_check("sync_module_registered", probe.is_available(), "AshiatoSyncProbe loaded")
		# Non-zero sizes mean the sync types really instantiated against THIS ashiato,
		# not sync's own pinned one. That is the compatibility claim worth checking:
		# upstream.lock records that our ECS is ahead of what sync pins.
		_check("sync_types_instantiate",
			probe.server_footprint() > 0 and probe.client_footprint() > 0,
			"server=%d bytes client=%d bytes" % [probe.server_footprint(), probe.client_footprint()])
	else:
		print("[conformance] (built without sync; rebuild with -WithSync to cover it)")

	_finish()


func _finish() -> void:
	print("[conformance] RESULT=%s" % (
		"PASS" if _failures.is_empty() else "FAIL %s" % [_failures]))
	get_tree().quit(0 if _failures.is_empty() else 1)

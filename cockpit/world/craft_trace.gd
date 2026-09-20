extends Node
class_name CraftTrace
## A FLIGHT WRITTEN DOWN AS IT IS FLOWN: one file per traced craft, one JSON object per sample, so somebody can run a
## flight, open the file and see a control input sawing back and forth against the thing it is chasing.
##
## Asked for on 2026-09-19: "write a 'trace location' flag into a craft so i can have it optionally (at spawn) write out
## it's location during a run as json so we can parse it and determine what it's flight path is, include it's inputs so we
## can introspect those, most ai pilots are still not using a PID for their controls, so they constantly oscillate."
##
##   Godot ... res://... -- --trace-craft=cessna --trace-out=C:/temp/traces --trace-hz=60
##
## `--trace-craft=` is WHICH CRAFT: a kind name (`cessna`), an entity number (`42`), `player` (a craft with somebody in a
## seat), `ai` (a craft with an autopilot) or `all`. It is judged as each craft appears, so it is "at spawn": whatever is
## spawned later and matches is traced from its first tick. `--trace-out=` is the folder (made if it is not there; the
## default is `user://traces`). `--trace-hz=` is how many samples a second (default 60; the tick is 120). A level may ask
## too: `CraftTrace.install(parent, "ai")`, and `Sim.trace` is the recorder while one is up.
##
## OFF COSTS NOTHING. With no flag there is no CraftTrace node at all, so no per-tick work and no allocation; `Sim` builds
## one only when a selector is given.
##
## JSON LINES, NOT ONE ARRAY (`<kind>_<entity>.jsonl`): a run that is killed still parses up to its last flushed line, and
## a long flight streams. The file is flushed every second of simulation and closed when the recorder leaves the tree.
## The FIRST LINE is a header, `{"trace": 1, ...}`, and it names the rate the file was written at, the kind and entity and
## what every field below means. Every later line is a sample, with these keys:
##   tick     which of this recorder's physics ticks (counted from its first, 120 a second by default). A replayed tick
##            would carry the same number, so a reader can keep the last one of each.
##   t        simulation seconds since the recorder began
##   pos      [x, y, z] metres, the craft's centre, to a tenth of a millimetre
##   quat     [x, y, z, w] attitude
##   euler    {pitch, yaw, roll} degrees from the same attitude (Godot YXZ order: yaw about up, then pitch, then roll)
##   vel      [x, y, z] m/s, in the world
##   spin     [x, y, z] rad/s, in the world
##   speed    m/s, the length of `vel`. THIS IS GROUND SPEED, not airspeed: wind and lift are not taken off it
##   aoa      degrees, the angle of attack worked out from `vel` in the craft's own frame (nose along -Z, up along +Y), so it
##            is the ANGLE OF THE VELOCITY and not a measured one. Absent under 1 m/s
##   slip     degrees of sideslip, the same way
##   levers   {throttle, flaps, trim, tilt, gear, spoilers, drop, fold, hook}: `craft_controls`. Absent for a craft that
##            has no bus
##   stick    {pitch, roll, rudder, brake, throttle} the demand the controller made on THAT tick, from
##            `CockpitWorld.flight_controls`; -1..1, the same numbers a pilot's hands make. THE OSCILLATION IS HERE.
##            ABSENT ON A LIBRARY THAT PREDATES `flight_controls` (the header says `"stick": "absent"`)
##   flown    "ai" or "human" (a pilot aboard and no autopilot)
##   goal     [x, y, z] what the autopilot is chasing right now (`ai_destination`'s waypoint), `null` for a craft with none
## The header carries `cap` (the most files a recorder writes), `fields`, and the rate; `trace_summary.json`, written when the recorder
## closes, says how many craft matched and how many were written. The header carries `fields` too, which is this list as data, so a reader does not have to be told.
##
## THE SERVER WRITES, or a single-process run, and nothing else does: a client replays ticks when a correction arrives, so
## a client's trace would hold the same instant twice, disagreeing, and its pose is a prediction. This node reads
## `Sim.server`, which is only there on the host, so a joiner traces nothing and says so once.
##
## REFUSED IN WORDS: an unwritable folder, a rate that is not a positive number or above the tick, a selector that is no
## kind, number or word, are `refusal` (printed here; `Sim` pushes it as an error, which a suite that provokes one on purpose must not) and NO recorder starts. A trace that quietly
## writes nothing is the failure this exists to avoid.
##
## `tools/read_trace.py` reads a file and prints, for each channel, the SIGN CHANGES A SECOND: the number that says
## whether a control is holding a value or hunting for it.

const VERSION: int = 1
const RATE_DEFAULT: float = 60.0
const FLUSH_SECONDS: float = 1.0
## THE MOST FILES ONE RECORDER WRITES. `--trace-craft=ai` on the test field would be a hundred files at 60 Hz, about 1.4 KB a
## sample each: past this a matching craft is COUNTED and NOT WRITTEN, and the run says so once when it happens and again in
## `trace_summary.json` (matched, written, cap) beside the files, which is how a reader knows a set is not the whole set.
const FILES_MOST: int = 16
const WORDS: PackedStringArray = ["all", "ai", "player"]
const LEVERS: PackedStringArray = ["throttle", "flaps", "trim", "tilt", "gear", "spoilers", "drop", "fold", "hook"]
const FIELDS: Dictionary = {
	"tick": "recorder tick, from 0", "t": "seconds", "pos": "m, world", "quat": "x y z w",
	"euler": "degrees {pitch, yaw, roll}", "vel": "m/s, world", "spin": "rad/s, world",
	"speed": "m/s, ground speed", "aoa": "degrees, from the velocity", "slip": "degrees, from the velocity",
	"levers": "craft_controls", "stick": "flight_controls: pitch, roll, rudder, brake, throttle", "flown": "ai or human",
	"goal": "the autopilot's waypoint or null",
}

## Why no recorder started, in words. Empty when one did.
var refusal: String = ""
## WHICH CRAFT, as the flag said it. See the header.
var craft: String = ""
var out_dir: String = ""
var hz: float = RATE_DEFAULT
## Every file this recorder has opened, by entity, for a suite to read back.
var paths: Dictionary = {}
## How many samples each entity has had.
var counts: Dictionary = {}

## How many craft matched the selector, written or not (see `FILES_MOST`).
var matched: int = 0
## Microseconds this recorder has spent sampling, for `tests/trace_cost.gd`: two clock reads a tick, and only while tracing.
var spent_usec: int = 0
var _capped: bool = false
var _files: Dictionary = {}
var _skipped: Dictionary = {}
var _ticks: int = 0
var _stride: int = 1
var _has_stick: bool = false
var _since_flush: int = 0
## Set by `close`: a closed recorder writes nothing more, and never reopens (and so truncates) a file it wrote.
var _closed: bool = false


## A RECORDER FROM THE COMMAND LINE, or null when nobody asked. A refused one is returned too, with `refusal` set, so the
## caller can say why and a suite can look; `Sim` prints it.
static func from_command_line(args: PackedStringArray = OS.get_cmdline_user_args()) -> CraftTrace:
	var asked: String = ""
	var folder: String = ""
	var rate: String = ""
	for argument in args:
		if argument.begins_with("--trace-craft="):
			asked = argument.get_slice("=", 1)
		elif argument.begins_with("--trace-out="):
			folder = argument.substr("--trace-out=".length())
		elif argument.begins_with("--trace-hz="):
			rate = argument.get_slice("=", 1)
	if asked.is_empty():
		return null
	return make(asked, folder, rate)


## A recorder, checked. `rate` is text so that "abc" can be refused rather than read as 0.
static func make(asked: String, folder: String = "", rate: String = "") -> CraftTrace:
	var out := CraftTrace.new()
	out.craft = asked.strip_edges().to_lower()
	out.out_dir = folder if not folder.is_empty() else "user://traces"
	out.name = "CraftTrace"
	var why: String = ""
	if not (WORDS.has(out.craft) or out.craft.is_valid_int() or Sim.Kind.keys().has(out.craft.to_upper())):
		why = "--trace-craft=%s names no craft: a kind (%s), an entity number, or one of %s" % [
			out.craft, ", ".join(Sim.Kind.keys()).to_lower().substr(0, 60) + "...", ", ".join(WORDS)]
	if why.is_empty() and not rate.is_empty():
		if not rate.is_valid_float() or float(rate) <= 0.0:
			why = "--trace-hz=%s is not a positive number" % rate
		else:
			out.hz = float(rate)
	if why.is_empty() and out.hz > Sim.tick_hz + 0.001:
		why = "--trace-hz=%s is above the tick rate, %d" % [out.hz, int(Sim.tick_hz)]
	if why.is_empty():
		# A FILE ON THE WAY is refused in words BEFORE a directory is attempted: a failed make is an engine error, and
		# the message names the folder, not the file in its way.
		var walk: String = ProjectSettings.globalize_path(out.out_dir).trim_suffix("/")
		while walk.length() > 3 and why.is_empty():
			if FileAccess.file_exists(walk):
				why = "--trace-out=%s cannot be made: %s is a file" % [out.out_dir, walk]
			walk = walk.get_base_dir()
	if why.is_empty():
		var made: int = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.out_dir))
		if made != OK:
			why = "--trace-out=%s cannot be made (error %d)" % [out.out_dir, made]
	out.refusal = why
	if not why.is_empty():
		print("[CraftTrace] REFUSED: " + why)
	return out


## A recorder on `parent` for a level that asks: the selector as the flag would say it, the folder and rate defaults.
## Returns it, refused or not; null when `asked` is empty.
static func install(parent: Node, asked: String, folder: String = "", rate: String = "") -> CraftTrace:
	if asked.is_empty():
		return null
	var out: CraftTrace = make(asked, folder, rate)
	if out.refusal.is_empty():
		parent.add_child(out)
	return out


func _ready() -> void:
	_stride = maxi(1, int(round(Sim.tick_hz / hz)))
	hz = Sim.tick_hz / float(_stride)
	print("[CraftTrace] tracing %s at %d Hz into %s" % [craft, int(hz), out_dir])


func _physics_process(_delta: float) -> void:
	if _closed:
		return
	if Sim.server == null:
		if _ticks == 0:
			print("[CraftTrace] no server on this machine (a joiner's trace would be a replay); nothing written")
		_ticks = 1
		return
	if _ticks % _stride == 0:
		var began: int = Time.get_ticks_usec()
		_sample()
		spent_usec += Time.get_ticks_usec() - began
	_ticks += 1


func _exit_tree() -> void:
	close()


## Flush and close every file. Safe twice.
func close() -> void:
	_closed = true
	if not paths.is_empty():
		var summary := FileAccess.open(out_dir.path_join("trace_summary.json"), FileAccess.WRITE)
		if summary != null:
			summary.store_string(JSON.stringify({"selector": craft, "matched": matched, "written": paths.size(), "cap": FILES_MOST,
				"hz": hz, "files": paths.values()}, "	"))
			summary.close()
	for entity in _files:
		var file: FileAccess = _files[entity]
		file.flush()
		file.close()
	_files.clear()


func _sample() -> void:
	var server: Object = Sim.server
	_has_stick = server.has_method("flight_controls")
	var crewed: Dictionary = {}
	if craft == "player":
		for pilot in server.pilot_states():
			crewed[int(pilot["vehicle"])] = true
	for state in server.vehicle_states():
		var entity: int = int(state["entity"])
		if _skipped.has(entity):
			continue
		var goal: Dictionary = server.ai_destination(entity)
		if not _wanted(state, entity, not goal.is_empty(), crewed):
			# A kind, entity or `ai` never changes for a craft; only `player` may, so it alone is asked again.
			if craft != "player":
				_skipped[entity] = true
			continue
		if not _files.has(entity):
			matched += 1
			if paths.size() >= FILES_MOST:
				_skipped[entity] = true
				if not _capped:
					_capped = true
					print("[CraftTrace] %d files written, the cap (FILES_MOST); more craft match `%s` and are counted, not written" % [
						paths.size(), craft])
				continue
			_open(state, entity)
			if not _files.has(entity):
				continue
		_write(state, entity, goal)
	_since_flush += 1
	if float(_since_flush * _stride) / Sim.tick_hz >= FLUSH_SECONDS:
		_since_flush = 0
		for entity in _files:
			(_files[entity] as FileAccess).flush()


func _wanted(state: Dictionary, entity: int, has_autopilot: bool, crewed: Dictionary) -> bool:
	if craft == "all":
		return true
	if craft == "ai":
		return has_autopilot
	if craft == "player":
		return crewed.has(entity)
	if craft.is_valid_int():
		return entity == int(craft)
	return Sim.kind_name(int(state["kind"])) == craft


func _open(state: Dictionary, entity: int) -> void:
	var kind: String = Sim.kind_name(int(state["kind"]))
	var path: String = out_dir.path_join("%s_%d.jsonl" % [kind, entity])
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		refusal = "cannot open %s (error %d)" % [path, FileAccess.get_open_error()]
		print("[CraftTrace] REFUSED: " + refusal)
		_skipped[entity] = true
		return
	var header := {"trace": VERSION, "kind": kind, "entity": entity, "hz": hz, "tick_hz": Sim.tick_hz,
		"started_tick": _ticks, "selector": craft, "cap": FILES_MOST, "fields": FIELDS,
		"stick": "flight_controls" if _has_stick else "absent"}
	file.store_line(JSON.stringify(header))
	_files[entity] = file
	paths[entity] = ProjectSettings.globalize_path(path) if path.begins_with("user://") else path
	counts[entity] = 0


func _write(state: Dictionary, entity: int, goal: Dictionary) -> void:
	var server: Object = Sim.server
	var pos: Vector3 = state["position"]
	var quat: Quaternion = state["basis"]
	var vel: Vector3 = state["velocity"]
	var spin: Vector3 = state["spin"]
	var euler: Vector3 = Basis(quat).get_euler()
	var sample: Dictionary = {
		"tick": _ticks, "t": snappedf(float(_ticks) / Sim.tick_hz, 0.0001),
		"pos": _v(pos), "quat": [_r(quat.x), _r(quat.y), _r(quat.z), _r(quat.w)],
		"euler": {"pitch": snappedf(rad_to_deg(euler.x), 0.01), "yaw": snappedf(rad_to_deg(euler.y), 0.01),
			"roll": snappedf(rad_to_deg(euler.z), 0.01)},
		"vel": _v(vel), "spin": _v(spin), "speed": snappedf(vel.length(), 0.001),
	}
	if vel.length() > 1.0:
		var local: Vector3 = Basis(quat).inverse() * vel
		sample["aoa"] = snappedf(rad_to_deg(atan2(-local.y, -local.z)), 0.01)
		sample["slip"] = snappedf(rad_to_deg(asin(clampf(local.x / vel.length(), -1.0, 1.0))), 0.01)
	var levers: Dictionary = server.craft_controls(entity)
	if not levers.is_empty():
		var kept: Dictionary = {}
		for key in LEVERS:
			if levers.has(key):
				kept[key] = _r(levers[key]) if levers[key] is float else levers[key]
		sample["levers"] = kept
	var flown: String = "ai" if not goal.is_empty() else "human"
	if _has_stick:
		var stick: Dictionary = server.flight_controls(entity)
		if not stick.is_empty():
			sample["stick"] = {"pitch": _r(stick["pitch"]), "roll": _r(stick["roll"]), "rudder": _r(stick["rudder"]),
				"brake": _r(stick["brake"]), "throttle": _r(stick["throttle"])}
			flown = "ai" if bool(stick.get("ai", not goal.is_empty())) else "human"
	sample["flown"] = flown
	if not goal.is_empty() and bool(goal.get("has_route", false)):
		sample["goal"] = _v(goal["waypoint"])
	else:
		sample["goal"] = null
	(_files[entity] as FileAccess).store_line(JSON.stringify(sample))
	counts[entity] = int(counts[entity]) + 1


static func _r(x: float) -> float:
	return snappedf(x, 0.0001)


static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001), snappedf(v.z, 0.0001)]

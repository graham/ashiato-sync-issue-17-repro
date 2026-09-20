extends Node
## A black curtain that survives a level's scene replacement.
##
## `Net` turns the host's reliable/revisioned level notice into `level_cued`. The cue starts this fade before the host
## changes the level. `level_changing` guarantees opacity if a cue arrived late, and `level_loaded_here` reveals the new
## level only after its local build is complete. CanvasLayer is used for a viewport-fixed overlay and Node.create_tween
## for a one-use animation, following the stable Godot CanvasLayer and Tween APIs.

const FADE_MSEC: int = 400
## Finish a little before the advertised change so a normal frame or packet scheduling wobble is still hidden.
const COVER_EARLY_MSEC: int = 50
const LAYER: int = 512

signal fade_started(target: String, revision: int)
signal covered(target: String, revision: int)
signal revealed(target: String, revision: int)

var _shade: ColorRect
var _tween: Tween
var _target: String = ""
var _revision: int = -1
var _epoch: int = -1
var _due_msec: int = -1
var _covering: bool = false
var _covered: bool = false
var _loaded_target: String = ""


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.name = "LevelTransitionLayer"
	layer.layer = LAYER
	add_child(layer)
	_shade = ColorRect.new()
	_shade.name = "Black"
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color.BLACK
	_shade.modulate.a = 0.0
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.visible = false
	layer.add_child(_shade)
	Net.level_cued.connect(_on_level_cued)
	Net.level_changing.connect(_on_level_changing)
	Net.level_loaded_here.connect(_on_level_loaded)
	Net.session_reset.connect(_on_session_reset)
	_epoch = Net.session_epoch
	set_process(false)


func _process(_delta: float) -> void:
	if _due_msec < 0 or _covering or _covered:
		set_process(false)
		return
	var now: int = Time.get_ticks_msec()
	if now >= _due_msec - FADE_MSEC - COVER_EARLY_MSEC:
		var available_msec: int = maxi(0, _due_msec - COVER_EARLY_MSEC - now)
		_begin_cover(float(mini(FADE_MSEC, available_msec)) / 1000.0)


## Public for a small deterministic harness; ordinary callers receive a validated cue from Net.
func accept_level_cue(cue: Dictionary) -> bool:
	if cue.get("kind") != "level" or not cue.get("target") is String or ChartDrawer.chart(String(cue["target"])) == null:
		return false
	var chart: LevelChart = ChartDrawer.chart(String(cue["target"]))
	if not cue.get("hash") is String or String(cue["hash"]) != chart.content_hash:
		return false
	var revision_value: Variant = cue.get("revision")
	var epoch_value: Variant = cue.get("epoch")
	var due_value: Variant = cue.get("due")
	if not (revision_value is int or revision_value is float) or float(revision_value) != floorf(float(revision_value)) \
			or not (epoch_value is int or epoch_value is float) or float(epoch_value) != floorf(float(epoch_value)) \
			or not (due_value is int or due_value is float) or float(due_value) != floorf(float(due_value)):
		return false
	var revision: int = int(revision_value)
	var epoch: int = int(epoch_value)
	var due: int = int(due_value)
	if epoch != _epoch or revision <= _revision or revision < 0 or due < 0:
		return false
	_revision = revision
	_target = String(cue["target"])
	_due_msec = due
	_covering = false
	_covered = false
	_loaded_target = ""
	_kill_tween()
	set_process(true)
	_report("TRANSITION_CUE target=%s revision=%d due_in=%d" % [_target, _revision,
		maxi(0, _due_msec - Time.get_ticks_msec())])
	return true


func _on_level_cued(cue: Dictionary) -> void:
	accept_level_cue(cue)


func _on_session_reset(epoch: int) -> void:
	_epoch = epoch
	_revision = -1
	_target = ""
	_due_msec = -1
	_covering = false
	_covered = false
	_loaded_target = ""
	_kill_tween()
	set_process(false)
	if _shade != null:
		_shade.modulate.a = 0.0
		_shade.visible = false
		_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_level_changing(target: String) -> void:
	# A direct API change has no advance cue, and a severely delayed network cue may have had no frame to finish. Never
	# expose the expensive scene replacement: force the same persistent rectangle opaque before Sky defers the swap.
	if _target != target:
		_target = target
		_revision += 1
	_due_msec = -1
	if not _covered:
		_begin_cover(0.0)


func _on_level_loaded(target: String) -> void:
	if target != _target:
		return
	_loaded_target = target
	if not _covered:
		return
	_reveal.call_deferred(target, _revision)


func _begin_cover(seconds: float) -> void:
	set_process(false)
	_covering = true
	_shade.visible = true
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_kill_tween()
	fade_started.emit(_target, _revision)
	if seconds <= 0.0:
		_shade.modulate.a = 1.0
		_did_cover()
		return
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_shade, "modulate:a", 1.0, seconds)
	_tween.finished.connect(_did_cover)


func _did_cover() -> void:
	_covering = false
	_covered = true
	_shade.modulate.a = 1.0
	covered.emit(_target, _revision)
	_report("TRANSITION_COVERED target=%s revision=%d" % [_target, _revision])
	if _loaded_target == _target:
		_reveal.call_deferred(_target, _revision)


func _reveal(target: String, revision: int) -> void:
	# Let the freshly-built scene draw one complete frame beneath opaque black first.
	await get_tree().process_frame
	if target != _target or revision != _revision or not _covered:
		return
	_kill_tween()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_shade, "modulate:a", 0.0, float(FADE_MSEC) / 1000.0)
	await _tween.finished
	if target != _target or revision != _revision:
		return
	_covered = false
	_loaded_target = ""
	_shade.visible = false
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	revealed.emit(target, revision)
	_report("TRANSITION_REVEALED target=%s revision=%d" % [target, revision])


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


## Test/read-only evidence without reaching through the CanvasLayer hierarchy.
func opacity() -> float:
	return _shade.modulate.a if _shade != null else 0.0


func target() -> String:
	return _target


func revision() -> int:
	return _revision


static func _report(line: String) -> void:
	if OS.get_cmdline_user_args().has("--report=1"):
		print(line)

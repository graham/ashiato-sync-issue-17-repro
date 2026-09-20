extends Node3D
class_name CrashOverview
## WHEN YOUR CRAFT IS DESTROYED, A STILL VIEW OF THE WRECK AND A LINE SAYING WHAT HAPPENED, UNTIL YOU ARE BACK IN THE AIR
## (lane/combat, 2026-09-18): "we have to handle the player being respawned or giving them a overview of the crash."
##
## ON EVERY MACHINE, for its own player only, from facts it already has: the craft this machine's rig is seated in
## reads destroyed in `Sim.hulls`, and that is the whole trigger -- a crewmate in the same craft is on another machine
## and sees their own. Nothing is sent. It ends when the rig's seat is in a craft that is not a wreck, which is the
## host's respawn moving the crew (`CrewRespawn`), or the CRAFT page.
##
## A STAND, NOT A CAMERA MOVE. The rig is handed to `stand` -- a still point back from the wreck, a little above it,
## level and facing it -- exactly as it is handed a seat (`PilotRig.sit_in`), so rule 1 holds: nothing writes the
## rider's world transform, the stand is simply somewhere else. In a headset that is one cut and then stillness, which is
## the comfortable way to move a person: a camera flown out of the cockpit would be the nauseating one. The panel stands
## in front of the eye on the stand, which both a headset and a monitor see.

## Where the stand is put, metres from the wreck: back along the way it was going, and up.
const BACK: float = 70.0
const UP: float = 22.0
## How far in front of the eye the panel stands, and how big its letters are.
const PANEL_AHEAD: float = 3.2
const PANEL_PIXEL: float = 0.0032
## The respawn's wait, which is the host's (`CrewRespawn.SECONDS`), for the countdown.
const WAIT: float = CrewRespawn.SECONDS

## Where the rig sits while the overview lasts, or null while it does not.
var stand: Node3D = null
## The wreck being looked at, as this machine numbers it; 0 for none.
var wreck: int = 0
## What the panel says, for the tests.
var words: String = ""
var _panel: Label3D = null
var _since: float = 0.0


## ONE FRAME, from the level: `mine` is the vehicle this machine's player is seated in, as this machine numbers it (0
## for none). Returns the anchor the rig should sit in instead of its seat, or null for its seat.
func look(mine: int, delta: float) -> Node3D:
	if stand != null:
		_since += delta
		# BACK IN SOMETHING WHOLE: the respawn has moved them, and the overview is over.
		if mine != wreck and mine != 0 and not bool(Sim.hull_of(mine).get("destroyed", false)):
			_end()
			return null
		_panel.text = _panel_text()
		return stand
	if mine == 0 or not bool(Sim.hull_of(mine).get("destroyed", false)):
		return null
	_begin(mine)
	return stand


func is_showing() -> bool:
	return stand != null


func _begin(entity: int) -> void:
	wreck = entity
	_since = 0.0
	var hull: Dictionary = Sim.hull_of(entity)
	words = Sim.loss_words(hull)
	var at: Vector3 = Sim.vehicle_transform(entity).origin
	# BACK ALONG THE WAY IT WAS GOING, from the last velocity this machine drew it with; north if it was standing still.
	var going: Vector3 = (Sim.previous.get(entity, {}).get("velocity", Vector3.ZERO) as Vector3)
	var flat := Vector3(going.x, 0.0, going.z)
	if flat.length() < 1.0:
		flat = Vector3.FORWARD
	var from: Vector3 = at - flat.normalized() * BACK + Vector3.UP * UP
	# NEVER UNDER WHAT IS THERE: over the ground or the sea by at least the height it was asked for.
	from.y = maxf(from.y, maxf(Terrain.surface_height(from), Terrain.SEA_LEVEL) + UP)
	stand = Node3D.new()
	stand.name = "CrashStand"
	add_child(stand)
	# LEVEL AND FACING THE WRECK: yaw only, so the horizon is where the inner ear expects it.
	var toward: Vector3 = at - from
	stand.global_transform = Transform3D(Basis(Vector3.UP, atan2(-toward.x, -toward.z)), from)
	_panel = Label3D.new()
	_panel.name = "CrashPanel"
	_panel.pixel_size = PANEL_PIXEL
	_panel.font_size = 64
	_panel.outline_size = 12
	_panel.no_depth_test = true
	_panel.fixed_size = false
	_panel.modulate = Color(1.0, 0.93, 0.85)
	_panel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.position = Vector3(0.0, CockpitStation.EYE_HEIGHT - 0.35, -PANEL_AHEAD)
	stand.add_child(_panel)
	_panel.text = _panel_text()
	print("[overview] %s -- watching the wreck from %s" % [words, from.snapped(Vector3.ONE)])


func _panel_text() -> String:
	var hull: Dictionary = Sim.hull_of(wreck)
	var cause: String = String(hull.get("cause_name", ""))
	var title: String = "SHOT DOWN" if cause == "gun" or cause == "missile" else "CRASHED"
	var left: int = ceili(maxf(WAIT - _since, 0.0))
	return "%s\n%s\n%s" % [title, words, "Back in the air in %d s" % left if left > 0 else "Back in the air..."]


func _end() -> void:
	if stand != null:
		stand.queue_free()
	stand = null
	_panel = null
	wreck = 0

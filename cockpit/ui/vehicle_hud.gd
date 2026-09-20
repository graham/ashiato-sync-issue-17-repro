extends Node3D
class_name VehicleHud
## WHAT YOU ARE FLYING, WHERE YOU ARE SITTING, WHAT YOUR STICK DOES -- AND WHEN THE
## SIMULATION CHANGED ITS MIND.
##
## Five movement models that feel different are only useful if you can tell which one you
## are in, and from inside a box there is no way to tell. That is not hypothetical: a
## player who spawned in the pod flew a HOVER model and reported that the flight model flew
## like a spaceship. It does. It was the wrong vehicle, and nothing on screen said so.
##
## The seat matters for the same reason and more sharply, now that seats differ: the front
## two fly and the back two swing the turret, so the same stick does two entirely different
## things depending on where you sat down.
##
## And the FLASH, which is a debugging instrument rather than decoration:
##
##   YELLOW -- this machine's prediction was wrong and the vehicle you are in was rewound
##   and replayed. If the world lurches and the screen goes yellow at the same moment, the
##   lurch is a rollback.
##
##   RED -- the drawn position jumped much further in one frame than the vehicle's own
##   speed can account for. That is not the network; that is the frame missing its timing,
##   and it needs a completely different fix.
##
## Being able to tell those two apart from inside a headset is the whole point. Guessing
## between them from a description cost a day.
##
## Head-locked, mounted on whichever camera is current, rather than bolted into the
## cockpit. A panel fixed to the seat is in front of your face only if the play space
## origin happens to be under the chair, which is not something this project can know.
## Everything else that rides in a vehicle is seat-parented and must be; this is the one
## thing that has to be legible from wherever the player is actually standing.
##
## It draws with depth testing OFF, so the hull it is inside cannot hide it.

## Indexed by Sim.Model: HOVER, AIRPLANE, HELICOPTER, CAR, BOAT. Written as literals rather
## than keyed off the enum because a const initialiser cannot reach an autoload.
##
## What each line is FOR: the difference between the models is which forces exist at all,
## and every one of those differences is something that will surprise a pilot who assumed
## otherwise. A wing stalls. A rotor goes where it tilts. A car cannot leave the ground and
## a boat cannot steer without way on. One line each is enough to stop the surprise.
const CHARACTER: PackedStringArray = [
	"hovers · no wing · full control at rest",
	"wing · stalls slow · bank to turn",
	"rotor · throttle is collective · tilt to go",
	"tyres · grips then slides · ground only",
	"hull · keel · rudder needs way on",
]

## What the panel calls each station, and what the stick in front of it actually does.
const STATION: Dictionary = {
	"pilot": "PILOT · you fly it",
	"copilot": "COPILOT · dual controls, you fly it too",
	"turret": "TURRET · your stick swings the barrel",
	# A MISSION STATION, and the sentence says what it may and may not do, because the word alone
	# reads like a job title and tells a player nothing. It fell through to the bare word on the
	# Mercury and the fighter before the carrier ever had one (lane/awacs, 2026-09-17).
	"operator": "OPERATOR · systems and the air picture, no flight controls",
}

## Peak opacity of the flash, and how long it takes to fade. Low and short on purpose: a
## full-strength tint across both eyes is a diagnostic you stop being able to use because
## it makes you feel ill.
const FLASH_PEAK: float = 0.20
const FLASH_FADE: float = 0.28

const ROLLBACK := Color(1.0, 0.85, 0.2)
const FRAME_STEP := Color(1.0, 0.3, 0.25)

@onready var _title: Label3D = $Panel/Title
@onready var _detail: Label3D = $Panel/Detail
@onready var _flash: MeshInstance3D = $Flash

## What is currently written on it. Cached because the strings only change when the player
## changes vehicle or seat, and rebuilding them every frame would mean asking the
## simulation for its geometry table sixty times a second to be told the same thing.
var _kind: int = -1
var _seat: int = -1
var _character: String = ""
var _station: String = ""
var _flash_left: float = 0.0
var _flash_material: StandardMaterial3D = null


func _ready() -> void:
	# Its own copy, because the material comes out of the scene and two rigs in one tree
	# would otherwise share one alpha.
	_flash_material = (_flash.material_override as StandardMaterial3D).duplicate()
	_flash.material_override = _flash_material
	_fade(0.0)


func _process(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left = maxf(_flash_left - delta, 0.0)
	_fade(FLASH_PEAK * (_flash_left / FLASH_FADE))


## Put it out. For a test that wants a known starting point, and for a player who would
## rather not see it at all.
func clear_flash() -> void:
	_flash_left = 0.0
	_fade(0.0)


## Something changed the world out from under the picture. Say which kind.
func flash(colour: Color) -> void:
	_flash_material.albedo_color = Color(colour.r, colour.g, colour.b,
		_flash_material.albedo_color.a)
	_flash_left = FLASH_FADE
	_fade(FLASH_PEAK)


func _fade(alpha: float) -> void:
	var colour: Color = _flash_material.albedo_color
	_flash_material.albedo_color = Color(colour.r, colour.g, colour.b, alpha)
	_flash.visible = alpha > 0.001


func show_vehicle(kind: int, speed: float, seat: int, seats: int, throttle: float,
		brake: float, note: String) -> void:
	if kind != _kind or seat != _seat:
		_kind = kind
		_seat = seat
		var geometry: Dictionary = Sim.client.kind_geometry(kind)
		_title.text = "%s · %s" % [
			String(geometry.get("name", "?")).to_upper(),
			String(geometry.get("model_name", "?")),
		]
		var model: int = int(geometry.get("model", 0))
		_character = CHARACTER[model] if model < CHARACTER.size() else ""
		var poses: Array = geometry.get("seat_poses", []) as Array
		var station: String = "turret"
		if seat >= 0 and seat < poses.size():
			station = String((poses[seat] as Dictionary).get("station", "turret"))
		_station = "seat %d of %d · %s" % [seat + 1, seats,
			STATION.get(station, station.to_upper())]
	# The throttle as a PERCENTAGE, because a trigger has no detent and no travel you can
	# feel: without a number on it there is no way to hold a cruise setting, or to know
	# whether you are at full power or nearly.
	var lever: String = "throttle %3.0f%%" % (throttle * 100.0)
	if brake > 0.01:
		lever += " · BRAKE %.0f%%" % (brake * 100.0)
	_detail.text = "%s\n%s\n%s · %.0f m/s · %.0f km/h\n%s" % [_character, _station, lever,
		speed, speed * 3.6, note]


## Before the first seat arrives, and for the frame after a vehicle is reaped.
func show_nothing() -> void:
	_kind = -1
	_seat = -1
	_character = ""
	_station = ""
	_title.text = "—"
	_detail.text = "waiting for a seat"

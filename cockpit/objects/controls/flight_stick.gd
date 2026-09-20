@tool
extends VehicleControl
class_name FlightStick
## A CONTROL COLUMN. Two axes, and unlike the throttle it SPRINGS BACK.
##
## That is why a stick is not on the command bus: it has no position worth remembering.
## Let go and it centres, so the only thing worth sending is where it is right now, which
## is what the input frame has always carried. Its position is replicated anyway -- but as
## something to LOOK at, so the other pilot can see you fly, not as state the aeroplane is
## built out of.

## How far the grip moves, in metres, from centre to the stops.
const THROW: float = 0.12
## How far the GRIP is up the shaft. What you hold is here and not at the base, so this is
## how much lower than your hand the stick has to be mounted.
const SHAFT: float = 0.22
## How fast it returns to centre when nobody is holding it, in fractions per second.
const CENTRING: float = 6.0
## How far the wrist turns for full rudder, in radians. A comfortable roll of the forearm
## and no more -- ask for 90 degrees and the last of it is only reachable by letting go.
const TWIST: float = 0.55

var _grip: MeshInstance3D = null
var _shaft: MeshInstance3D = null
## WHETHER THIS STICK LAUNCHES MISSILES, set by `CockpitStation._fit_the_missiles` on the seats the simulation says
## can launch. False everywhere else, so an airliner's column never offers a button that does nothing.
var launches: bool = false
## AND WHETHER THE TRIGGER IS THE LAUNCH, which it is on a seat with no gun of its own. A seat with a gun keeps the
## trigger for the gun and launches with the thumb instead: one finger, one weapon.
var launch_on_trigger: bool = true
## HOW FAR THIS SEAT MAY TRIM THE CRAFT, as the top of the trim channel, or 0 where it may not. Set by
## `CockpitStation._fit_the_trim_to_the_column` from the craft's schema and the seat: a craft with no trim, a craft
## whose trim works no elevator, and a seat that does not fly all leave it at 0 -- and a stick at 0 leaves the mini
## joystick to whatever an empty hand does with it.
##
## It was always bound. The pod's stick took the thumbstick for "wind the trim" on a craft with no trim channel, which
## is a dead control the rest of this file has a rule against.
var trim_range: int = 0
## WHICH WEAPON STATIONS THIS STICK'S THUMB WALKS, as the simulation numbers them: `Sim.missile_schema(kind).stations`'
## own `station` values, set by `CockpitStation._fit_the_missiles`. Never 0..the channel's range -- see `Bind.step_among`.
var missile_stations: Array = []
## AND WHETHER ONE OF THOSE STATIONS IS A GUN, set beside them. The fighter's minigun is a station on the same selector
## as its missiles (plan item 4), so the finger that launches has to be able to fire as well -- see `missile_bindings`.
var fires_a_gun: bool = false


## THE FINGER FIRES AND THE THUMB TRIMS, which is what a fighter stick has on it.
##
## The contrast with the throttle beside it is the whole point of binding per control: the
## same thumb button trims the aeroplane here and works the flaps there, because a hand on
## a control column and a hand on a throttle are doing two different jobs and the pilot
## knows which one they are holding.
##
## Trim is a bus channel with a NEUTRAL IN THE MIDDLE, unlike every other lever, which is
## why `VehicleView.channel_value` has a case of its own for it.
func bindings() -> Dictionary:
	return missile_bindings(launch_on_trigger, trim_range, missile_stations, fires_a_gun) if launches \
		else column_bindings(trim_range)


## A FIGHTER'S STICK: the column's own bindings, and the missiles under the same hand.
##
## THE TRIGGER LAUNCHES and the upper thumb LOCKS, which is the pair a pilot uses together -- lock with the thumb,
## squeeze with the finger -- and the lower thumb walks the weapon stations the craft CARRIES, `stations`, round to the
## first after the last. On a seat whose trigger already fires a gun, the launch moves to the lower thumb and the station
## stays on the board. The trim stays on the mini joystick either way.
##
## AND ON A CRAFT WHOSE SELECTOR HAS A GUN ON IT, `guns`, THE TRIGGER FIRES WHATEVER IS SELECTED: it carries the launch
## AND the pull, and the SERVER decides which one acts by the station the selector is on -- `fire_the_selected_gun` for a
## gun, `work_the_seekers` for a missile. Asked for on 2026-09-15: "a minigun on the front and selecting is one of the
## options cycling through, guns, heat seeker, radar missile". Moving the launch to the lower thumb instead, as a seat
## with a turret gun of its own does, would take `step_among` off the stick -- and a pilot in a headset could then not
## cycle the stations at all, which is the thing that was asked for.
static func missile_bindings(launch_on_trigger: bool, trims: int, stations: Array, guns: bool = false) -> Dictionary:
	var table: Dictionary = column_bindings(trims)
	table[Bind.THUMB_HIGH] = Bind.frame(Sim.BUTTON_LOCK)
	if launch_on_trigger:
		table[Bind.TRIGGER] = [Bind.frame(Sim.BUTTON_LAUNCH)] + Bind.fire() if guns else Bind.frame(Sim.BUTTON_LAUNCH)
		table[Bind.THUMB_LOW] = Bind.step_among(Sim.Channel.WEAPON, stations)
	else:
		table[Bind.THUMB_LOW] = Bind.frame(Sim.BUTTON_LAUNCH)
	return table


## STATIC, AND SHARED WITH THE YOKE. A stick and a yoke are one job in two shapes, and a
## pilot moving from the Cessna to the airliner should not have to discover that trim has
## migrated to another finger.
##
## `trims` is the column's `trim_range`: 0 binds no trim at all, so the mini joystick and its click fall through to the
## empty hand's own bindings. Required rather than defaulted, so a caller has to say which column it means.
static func column_bindings(trims: int) -> Dictionary:
	var table: Dictionary = {Bind.TRIGGER: Bind.fire()}
	if trims <= 0:
		return table
	# THE MINI JOYSTICK WINDS THE TRIM, and pressing it in centres it.
	#
	# It was two thumb buttons stepping the channel by 8, which is a control you have to
	# be told about and then count. A thumbstick you push and hold is one you can feel:
	# push forward and the nose settles down, push back and it settles up, and the wheel
	# beside your hip turns while you do it so you can see how far you have gone.
	#
	# ON THE STICK AND NOT ON THE WHEEL, because that is where trim is wanted. You trim
	# while you are flying, to take the load off the arm that is flying -- a trim you
	# have to let go of the aeroplane to reach is one nobody uses in the air.
	#
	# THE RATE WINDS THE CRAFT'S TRIM, NOT A WHEEL: see `PilotRig._wind_the_trim`, which proposes it on the bus, and
	# every wheel aboard draws what the craft decided.
	table[Bind.STICK] = Bind.axis("trim_rate", 1.0, 1)
	table[Bind.STICK_CLICK] = Bind.command(Sim.Channel.TRIM, TrimWheel.neutral(trims))
	return table


## A STICK IS NOT OBVIOUSLY THE THING THAT PITCHES AND ROLLS YOU, to anybody who has not
## flown one. The second line is the whole reason labels exist.
func label_text() -> String:
	return "STICK\nPITCH / ROLL"


func _build() -> void:
	control_name = "stick"
	scope = Scope.SEAT
	centring = CENTRING
	var boot := CylinderMesh.new()
	boot.top_radius = 0.035
	boot.bottom_radius = 0.055
	boot.height = 0.04
	_make_mesh(boot, Color(0.11, 0.11, 0.13), Vector3.ZERO)
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.014
	shaft.bottom_radius = 0.018
	shaft.height = 0.20
	_shaft = _make_mesh(shaft, Color(0.20, 0.21, 0.24), Vector3(0.0, 0.10, 0.0))
	var grip := CapsuleMesh.new()
	grip.radius = 0.028
	grip.height = 0.10
	_grip = _make_mesh(grip, Color(0.16, 0.17, 0.20), Vector3(0.0, SHAFT, 0.0))


## HOW FAR IT LEANS at full deflection, in radians.
const LEAN: float = 0.42


## WHICH WAY IT LEANS. Nose up is +1 and comes from pulling the stick BACK, so the grip has
## to travel back with it: a rotation about +X carries (0, h, 0) toward +Z, which is toward
## the pilot. The sign here was negated, so the aeroplane pitched up while the stick in
## front of you pushed forward -- right in the input frame and backwards in the cockpit,
## which is the confusing half of a control that lies.
func _lean() -> Basis:
	return Basis(Vector3.RIGHT, value.y * LEAN) * Basis(Vector3.BACK, -value.x * LEAN)


## The grip, not the base: twenty centimetres up the shaft and leaning with it.
func _grab_point() -> Vector3:
	return _lean() * Vector3(0.0, SHAFT, 0.0)


func _redraw() -> void:
	if _grip == null:
		return
	# The stick pivots at its base, so the whole column tilts rather than sliding. The
	# GRIP also turns with the wrist, which is the only visible sign of rudder on the
	# stick itself -- the rest of it is on the indicator.
	var lean: Basis = _lean()
	_shaft.transform = Transform3D(lean, lean * Vector3(0.0, SHAFT * 0.45, 0.0))
	_grip.transform = Transform3D(lean * Basis(Vector3.UP, twist * TWIST),
		lean * Vector3(0.0, SHAFT, 0.0))


## TWISTING THE STICK IS RUDDER, about the shaft and not about anything fixed.
##
## The axis leans with the column, so a stick held hard over is still twisted about its own
## length rather than about the cockpit's vertical -- which is what a wrist actually does,
## and what stops rolling the aeroplane from reading as rudder.
func _turn(facing: Basis) -> void:
	var shaft: Vector3 = (_lean() * Vector3.UP).normalized()
	# NEGATED. `_turned_about` measures counter-clockwise about the axis, and turning the
	# grip CLOCKWISE seen from above is right rudder -- which is a negative rotation about
	# an up axis in a right-handed frame.
	var wanted: float = clampf(
		_twist_at_grab - _turned_about(shaft, facing) / TWIST, -1.0, 1.0)
	if absf(wanted - twist) < 0.001:
		return
	twist = wanted
	_redraw()
	moved.emit(self)


func _drag(at: Vector3) -> void:
	var travel: Vector3 = _hand_travel(at)
	var wanted := Vector2(
		clampf(_grab_value().x + travel.x / THROW, -1.0, 1.0),
		# Pushing the stick FORWARD is -Z, and forward is nose down, which is -1.
		clampf(_grab_value().y + travel.z / THROW, -1.0, 1.0))
	_settle(wanted)




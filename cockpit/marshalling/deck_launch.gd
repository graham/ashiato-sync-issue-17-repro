extends MarshallingLevel
class_name DeckLaunch
## MARSHAL A JET ONTO THE CATAPULT AND LAUNCH IT.
##
##   Godot --path cockpit -- --level=deck
##
## You are the yellow shirt. A jet is parked off the track with its engines running and its
## brakes on, and the deck is a third of a kilometre of steel with a bow at the far end of
## it. Everything that happens to that aeroplane in the next minute happens because of where
## you put your hands.
##
## The sequence is the real one, in the real order: brakes off, taxi it forward and turn it
## onto the track, stop it with the nosewheel on the shuttle, brakes on, spread the wings,
## take tension, run it up, return the salute, and then touch the deck and point at the bow.
## A carrier launch is about twenty seconds of that from the moment it reaches the catapult,
## which is why it is worth being able to do it without thinking.
##
## THE AEROPLANE DOES WHAT YOU SAY, INCLUDING WHEN YOU ARE WRONG. Wave it forward with the
## chocks in and the pilot tells you why not; wave it forward when it should be stopping and
## it rolls, past the shuttle, and you have to push it back.

const JET := preload("res://objects/vehicles/craft_plane.tscn")

## How close a nosewheel has to be to the shuttle bar. The first is a pass and the second is
## the one to be pleased about -- a bar is 0.5 m wide and the aeroplane is stopped by a
## person judging a rolling aircraft from ten metres away.
const CLOSE_ENOUGH: float = 4.0
const ON_THE_MONEY: float = 0.6
## And how straight, and how central, before it counts as being on the track at all.
const ON_TRACK: float = 1.5
const SQUARE: float = deg_to_rad(12.0)
## Where the jet waits, from the launch catapult's shuttle: across the track, and aft of it.
const JOIN_FROM := Vector2(10.0, 100.0)

var deck: CarrierDeck = null
var _over: bool = false


func _build_the_place() -> void:
	deck = CarrierDeck.new()
	deck.name = "Deck"
	add_child(deck)


func _build_the_craft() -> MarshalledCraft:
	var jet := MarshalledCraft.new()
	jet.name = "Jet"
	add_child(jet)
	jet.fit(Sim.Kind.PLANE, JET)
	# ON the deck, not in it: the hull is drawn about its middle, so it stands on its own
	# half-height. Parked off the track, pointing up the deck, brakes on and engines running
	# -- which is where a jet waits for a director to pick it up. A hundred metres aft of the
	# shuttle and ten to starboard of the track, so she is turned LEFT onto it, and clear of
	# the island and the elevators aft of her.
	jet.position = Vector3(CarrierDeck.track_x() + JOIN_FROM.x, jet.extents.y,
		CarrierDeck.shuttle_z() + JOIN_FROM.y)
	jet.brakes_set = true
	jet.engines = true
	return jet


## THE MARSHALLER'S POST: ten metres up the deck from the shuttle and eight to starboard of
## the track, facing back down the deck at the oncoming aeroplane. Where a director stands
## is where a pilot can see them over the nose, and the whole job depends on that.
func post_pose() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI),
		Vector3(CarrierDeck.track_x() + 9.0, 0.0, CarrierDeck.shuttle_z() - 9.0))


func the_line() -> Vector2:
	return Vector2(CarrierDeck.track_x(), CarrierDeck.shuttle_z())


func _steps() -> Array:
	return [
		{
			"expects": &"release_brakes",
			"tells": "Her brakes are on. Left arm down, right FIST up beside your head, "
				+ "then open it.",
		},
		{
			"expects": &"come_ahead",
			"tells": "Bring her forward and turn her LEFT onto the catapult track. "
				+ "Right arm out and still, beckon with your left.",
			"until": _is_on_the_track,
			"faults": {
				&"touch_deck": "she is nowhere near the shuttle",
				&"take_tension": "there is nothing to take tension on yet",
			},
		},
		{
			"expects": &"normal_stop",
			"tells": "Stop her with the nosewheel on the yellow bar. Arms out, then "
				+ "raise them slowly until they cross.",
			"until": _is_on_the_shuttle,
			"then": _write_down_the_stop,
			"faults": {&"touch_deck": "she is not hooked up"},
		},
		{
			"expects": &"set_brakes",
			"tells": "Hold her there. Right hand up and open, then clench it.",
		},
		{
			"expects": &"spread_wings",
			"tells": "Spread her wings: both hands at your chest, sweep them out.",
		},
		{
			"expects": &"take_tension",
			"tells": "Take tension. Left hand up and OPEN for the brakes, right arm "
				+ "straight at the bow.",
			"then": func() -> void: deck.deflector(true),
		},
		{
			"expects": &"run_up",
			"tells": "Run her up. Keep circling a hand above your head until she is at "
				+ "full power.",
			# UNTIL SHE IS ACTUALLY AT POWER. The signal is not the event: engines take a
			# couple of seconds, and a marshaller who stops asking as soon as the arm has
			# gone round twice is a marshaller who launches a jet at half thrust.
			"until": func() -> bool: return craft.power >= 0.99,
		},
		{
			"expects": &"salute",
			"tells": "She has saluted you. Return it: hand to your brow, then away.",
		},
		{
			"expects": &"touch_deck",
			"tells": "Crouch. Touch the deck. Point at the bow.",
			"until": func() -> bool: return craft.state == MarshalledCraft.State.LAUNCH,
		},
	]


## ---- what the deck asks of the aeroplane ---------------------------------------------

## LINED UP: on the track, straight, and close enough to be joining the catapult rather than
## merely pointing at it from the far end of the ship.
func _is_on_the_track() -> bool:
	var nose: Vector3 = craft.nose()
	return absf(nose.x - CarrierDeck.track_x()) < ON_TRACK \
		and absf(angle_difference(craft.heading(), 0.0)) < SQUARE \
		and nose.z < CarrierDeck.shuttle_z() + 40.0


func _is_on_the_shuttle() -> bool:
	return not craft.is_rolling() \
		and absf(craft.nose().z - CarrierDeck.shuttle_z()) < CLOSE_ENOUGH \
		and absf(craft.nose().x - CarrierDeck.track_x()) < ON_TRACK


func _write_down_the_stop() -> void:
	var off: float = absf(craft.nose().z - CarrierDeck.shuttle_z())
	procedure.marks["on the bar"] = "%.2f m%s" % [off,
		"  (on the money)" if off <= ON_THE_MONEY else ""]
	procedure.marks["off the track"] = "%.2f m" % absf(craft.nose().x
		- CarrierDeck.track_x())


## ---- and the one way to lose an aeroplane -------------------------------------------

func _physics_process(delta: float) -> void:
	super(delta)
	if craft == null or _over:
		return
	var nose: Vector3 = craft.nose()
	# THE DECK RUNS OUT. Which is the thing that makes a carrier a carrier: there is no
	# apron to wander onto, and a director who keeps waving has put an aeroplane in the sea.
	# WHERE it runs out is the simulation's deck outline -- narrow at the bow, wide where the
	# landing area is angled off -- not a rectangle typed beside it.
	if not CarrierPlan.is_on_deck(Vector2(nose.x, nose.z)):
		if craft.state == MarshalledCraft.State.TAXI \
				or craft.state == MarshalledCraft.State.PARKED:
			_over = true
			craft.wanted_speed = 0.0
			craft.speed = 0.0
			craft.brakes_set = true
			procedure.faults += 1
			_say("She has gone over the side. That is a jet and a pilot.")

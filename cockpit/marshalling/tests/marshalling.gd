extends Node
## Headless: is a marshalling signal a thing this game can actually tell apart?
##
##   Godot --headless --path cockpit res://marshalling/tests/marshalling.tscn
##
## The position rests on one claim -- that a hand's PATH THROUGH ZONES names a signal
## unambiguously -- and that claim is exactly the sort a person cannot check by making the
## signals themselves. A player who waves and gets nothing cannot tell whether their arm was
## wrong, their timing was wrong or the book is ambiguous. So the hands are driven from here,
## with no tracker, no controllers and no frame rate, and every signal in the book is walked
## and then walked slightly wrong.
##
## Read RESULT=, not the exit code.

## The step the reader takes. Small enough that a 0.5 s signal has thirty of them in it.
const TICK: float = 1.0 / 60.0

var _failures: PackedStringArray = []
var _reader: SignalReader = null
var _heard: Array[StringName] = []
## How fast the robot is waving, in seconds a stroke. See `_what_a_marshaller_would_do`.
var _wave: float = 0.35
var _strengths: Dictionary = {}


func _check(label: String, ok: bool, detail: String) -> void:
	print("[marshalling] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_reader = SignalReader.new()
	add_child(_reader)
	_reader.set_process(false)
	_reader.signalled.connect(func(id: StringName, strength: float) -> void:
		_heard.append(id)
		_strengths[id] = strength)

	_the_zones()
	_the_book()
	_every_signal()
	_the_near_misses()
	_the_rate()
	_the_desktop_hands()
	_the_ghosts()
	_the_guide_waits()
	_the_doors()
	# AND THEN THE WHOLE JOB, WITH A ROBOT DOING IT. Everything above this line is about
	# hands; this is about whether marshalling an aeroplane onto a catapult with them
	# actually closes the loop -- signal, pilot, aeroplane, checklist, and back to the
	# hands for the next one.
	await _the_whole_launch()
	_finish()


## ---- the zones -------------------------------------------------------------------

func _the_zones() -> void:
	var reach: float = SignalZones.NOMINAL_REACH
	# NO TWO PLACES A HAND CAN BE WITHIN A HAND OF EACH OTHER. The same invariant the
	# cockpit asserts about two grips, for the same reason: which of two overlapping targets
	# a hand is in comes down to arithmetic nobody can see, and the answer changes with a
	# centimetre of tracking noise.
	var closest: float = INF
	var pair: String = ""
	var names: Array = SignalZones.names()
	for i in range(names.size()):
		for j in range(i + 1, names.size()):
			var apart: float = SignalZones.place(names[i], SignalZones.RIGHT, reach) \
				.distance_to(SignalZones.place(names[j], SignalZones.RIGHT, reach))
			if apart < closest:
				closest = apart
				pair = "%s/%s" % [names[i], names[j]]
	_check("no_two_zones_are_within_a_hand_of_each_other", closest >= 0.28,
		"closest is %s at %.2f m" % [pair, closest])

	# AND EVERY ONE OF THEM IS SOMEWHERE AN ARM GOES. A zone out of reach is a signal
	# nobody can make, and it would look exactly like the reader being broken.
	var far: Array[String] = []
	for zone in names:
		if zone == &"deck":
			continue
		var out: float = SignalZones.place(zone, SignalZones.RIGHT, reach).length()
		if out > reach * 1.3:
			far.append("%s at %.2f m" % [zone, out])
	_check("every_zone_is_within_an_arm", far.is_empty(),
		"%s" % ["all %d of them" % names.size() if far.is_empty() else far])

	# THE DECK IS THE EXCEPTION AND IT IS MEANT TO BE. Standing, it is out of reach; crouch
	# and it comes to hand. That is the signal: the shooter goes down and touches the deck.
	var standing: float = SignalZones.place(&"deck", SignalZones.RIGHT, reach,
		SignalZones.NOMINAL_SHOULDER).length()
	var crouched: float = SignalZones.place(&"deck", SignalZones.RIGHT, reach,
		SignalZones.NOMINAL_SHOULDER - MarshalRig.CROUCH).length()
	_check("the_deck_is_reached_by_crouching_and_not_otherwise",
		standing > reach * 1.3 and crouched < reach * 1.3,
		"%.2f m standing, %.2f m crouched, arm is %.2f" % [standing, crouched, reach])


## ---- the book --------------------------------------------------------------------

func _the_book() -> void:
	var wrong: Array[String] = []
	for id in SignalBook.ids():
		var row: Dictionary = SignalBook.of(id)
		if (row["steps"] as Array).is_empty():
			wrong.append("%s has no steps" % id)
		if String(row.get("title", "")).is_empty() or SignalBook.says(id).is_empty():
			wrong.append("%s is not described" % id)
		for step in (row["steps"] as Array):
			for hand in step:
				for zone in (hand["zones"] as Array):
					if not SignalZones.ZONES.has(zone):
						wrong.append("%s wants %s" % [id, zone])
	_check("the_book_is_written_in_zones_that_exist", wrong.is_empty(),
		"%s" % ["%d signals" % SignalBook.ids().size() if wrong.is_empty() else wrong])


## ---- every signal, made properly --------------------------------------------------

func _every_signal() -> void:
	var missed: Array[String] = []
	var muddled: Array[String] = []
	for id in SignalBook.ids():
		var heard: Array[StringName] = _walk(id)
		if not heard.has(id):
			missed.append("%s heard %s" % [id, heard])
		for other in heard:
			if other != id and not muddled.has("%s -> %s" % [id, other]):
				muddled.append("%s -> %s" % [id, other])
	_check("every_signal_in_the_book_is_recognised", missed.is_empty(),
		"%s" % ["all %d" % SignalBook.ids().size() if missed.is_empty() else missed])
	# THE ONE THAT MATTERS. A book where two signals can be made by the same movement is a
	# book where an aeroplane does the wrong thing and the player cannot see why.
	_check("and_no_signal_is_mistaken_for_another", muddled.is_empty(),
		"%s" % ["none of %d" % SignalBook.ids().size() if muddled.is_empty() else muddled])


## ---- and made slightly wrong ------------------------------------------------------

func _the_near_misses() -> void:
	# HALF A SIGNAL IS NO SIGNAL. Arms out and then back down is a marshaller stretching.
	_heard.clear()
	_hold(&"out90", &"out90", 0.5)
	_hold(&"side", &"side", 0.5)
	_check("half_a_stop_is_not_a_stop", _heard.is_empty(), "heard %s" % [_heard])

	# THE SAME ARMS, SLOWLY AND QUICKLY, ARE TWO DIFFERENT ORDERS. This is the one place in
	# the whole book where the movement alone does not say which signal it is.
	_heard.clear()
	_hold(&"out90", &"out90", 0.6)
	_hold(&"crossed", &"crossed", 0.4)
	var slow: Array[StringName] = _heard.duplicate()
	_settle()
	_heard.clear()
	_hold(&"side", &"side", 0.15)
	_hold(&"crossed", &"crossed", 0.3)
	var quick: Array[StringName] = _heard.duplicate()
	_check("a_slow_stop_and_a_fast_one_are_different_orders",
		slow == [&"normal_stop"] and quick == [&"emergency_stop"],
		"slowly %s, quickly %s" % [slow, quick])

	# A HAND IN THE WRONG PLACE. One arm doing the come-ahead beckon and the other doing
	# nothing is not a signal at all -- which is what stops an idle hand from taxiing an
	# aeroplane while its owner scratches their nose.
	_settle()
	_heard.clear()
	for i in range(6):
		_put_zones(&"chest" if i % 2 == 0 else &"head", SignalZones.NOWHERE)
		_run(0.25)
	_check("one_arm_beckoning_alone_is_not_come_ahead", _heard.is_empty(),
		"heard %s" % [_heard])

	# AND A SIGNAL MADE WITH YOUR BACK TURNED IS NOT A SIGNAL. The zones are around the
	# player wherever they are facing -- deliberately, so you can turn to watch an aeroplane
	# come round -- so which way they are POINTING is a separate question with a separate
	# answer, and the levels gate on it because the pilot has to be able to see you.
	_check("a_signal_made_with_your_back_turned_is_not_one",
		_reader.facing(Vector3(0.0, 0.0, -20.0)) > 0.9
			and _reader.facing(Vector3(0.0, 0.0, 20.0)) < -0.9,
		"%.2f facing it, %.2f facing away" % [_reader.facing(Vector3(0.0, 0.0, -20.0)),
			_reader.facing(Vector3(0.0, 0.0, 20.0))])

	# AND A FIST IS NOT A PALM. Setting the brakes is a raised OPEN hand that then clenches;
	# a hand raised already clenched is the signal to RELEASE them, and getting those two
	# the wrong way round on a live aircraft is the worst mistake in this book.
	_settle()
	_heard.clear()
	_put_hand(SignalZones.LEFT, &"side", 0.0, 0.0)
	_put_hand(SignalZones.RIGHT, &"head", 1.0, 0.0)
	_run(0.4)
	_put_hand(SignalZones.RIGHT, &"head", 0.0, 0.0)
	_run(0.4)
	_check("a_raised_fist_that_opens_releases_the_brakes",
		_heard == [&"release_brakes"], "heard %s" % [_heard])


## ---- and the rate, which is half the message ---------------------------------------

func _the_rate() -> void:
	_settle()
	_heard.clear()
	_strengths.clear()
	_cycle(&"come_ahead", 0.75)
	var lazy: float = float(_strengths.get(&"come_ahead", -1.0))
	_settle()
	_heard.clear()
	_strengths.clear()
	_cycle(&"come_ahead", 0.28)
	var eager: float = float(_strengths.get(&"come_ahead", -1.0))
	_check("a_faster_beckon_asks_for_more_speed", lazy >= 0.0 and eager > lazy + 0.25,
		"%.2f waving slowly, %.2f waving hard" % [lazy, eager])


## ---- the rig and the reader, which have to agree about where forward is ---------------

## DRIVE THE REAL RIG TO EVERY ZONE AND ASK THE READER WHERE THE HANDS ARE.
##
## The one loop the rest of this suite cannot see. Everywhere else the hands are put into
## the reader's own frame, so if that frame were turned round the targets would turn with it
## and every test would still pass -- while a player in a headset found their left hand
## reading as their right and `forward` somewhere behind them. Which is exactly what was
## happening: the body frame was yawed 180 degrees out of the head for as long as this
## directory existed, and nothing but this could have caught it.
func _the_desktop_hands() -> void:
	var rig := (load("res://marshalling/hand/marshal_rig.tscn") as PackedScene) \
		.instantiate() as MarshalRig
	add_child(rig)
	var reader := SignalReader.new()
	reader.rig = rig
	rig.origin.add_child(reader)
	reader.set_process(false)

	var lost: Array[String] = []
	for zone in SignalZones.names():
		# `deck` is out of an arm's reach on purpose -- you crouch to it -- and a crouch is
		# a key being held, which a test has no way to hold.
		if zone == &"deck":
			continue
		for hand in range(2):
			rig.point_at(hand, SignalZones.place(zone, hand, SignalZones.NOMINAL_REACH,
				MarshalRig.STAND_EYE - SignalZones.NECK))
		rig._place_desktop_rig()
		reader.tick(1.0 / 60.0)
		if reader.left_zone != zone or reader.right_zone != zone:
			lost.append("%s read as %s/%s" % [zone, reader.left_zone, reader.right_zone])
	_check("the_hands_the_rig_draws_are_the_hands_the_reader_reads", lost.is_empty(),
		"%s" % ["all %d zones, both hands" % (SignalZones.names().size() - 1)
			if lost.is_empty() else lost])
	rig.queue_free()


## ---- the teaching, which is the whole first minute -----------------------------------

## THE TARGETS ARE ACTUALLY DRAWN, AND WHERE THE HANDS HAVE TO GO.
##
## Not a detail: a player who is not shown the zones is a player waving at an aeroplane
## hoping. And it is exactly the sort of thing that breaks silently -- a ghost at the origin,
## a ghost of the wrong size, no ghost at all -- because nothing else in the game reads it.
func _the_ghosts() -> void:
	var reader := SignalReader.new()
	add_child(reader)
	reader.set_process(false)
	var ghosts := SignalGhosts.new()
	ghosts.reader = reader
	reader.add_child(ghosts)
	ghosts.demonstrate(&"identify")

	var wrong: Array[String] = []
	var shown: int = 0
	for hand in range(2):
		var want: Vector3 = SignalZones.place(&"overhead", hand, reader.reach,
			reader.shoulder)
		var found: bool = false
		for node in ghosts.get_children():
			var ball := node as MeshInstance3D
			if ball == null or not ball.visible:
				continue
			if ball.position.distance_to(want) < 0.01:
				found = true
				var size: float = (ball.mesh as SphereMesh).radius
				if absf(size - SignalZones.radius(&"overhead", reader.reach)) > 0.01:
					wrong.append("a ghost of %.2f m where the zone is %.2f" % [size,
						SignalZones.radius(&"overhead", reader.reach)])
		if not found:
			wrong.append("no ghost for hand %d" % hand)
		else:
			shown += 1
	_check("the_targets_are_drawn_where_the_hands_have_to_go", wrong.is_empty(),
		"%s" % ["%d of 2 hands, at the zone and its size" % shown if wrong.is_empty()
			else wrong])
	reader.queue_free()


## AND THE GUIDE WAITS FOR YOU.
##
## It did not. The poses advanced on a metronome, one every 0.8 s, whatever the player was
## doing -- so on a two-pose signal the targets you were reaching for moved away before you
## arrived, went somewhere else, and came back. Meanwhile the matcher, which does NOT loop,
## sat waiting for the second pose the guide had just led you away from. Doing exactly the
## right thing looked like the game disagreeing with you, and it was reported as "the zones
## move and I can't get to the new position quickly enough".
##
## Both halves are checked, because the fix is easy to write as "never advance", and a guide
## that never advances cannot show that a beckon REPEATS -- which is the whole of what makes
## a beckon a beckon.
func _the_guide_waits() -> void:
	var reader := SignalReader.new()
	add_child(reader)
	reader.set_process(false)
	var ghosts := SignalGhosts.new()
	ghosts.reader = reader
	reader.add_child(ghosts)
	# `come_ahead` is two poses, chest then head, and both hands are wanted in each.
	ghosts.demonstrate(&"come_ahead")
	ghosts._process(0.0)
	var first: Array = _ghosts_at(ghosts)

	# HANDS NOWHERE. The guide has to sit still for a good deal longer than a beat, or a
	# player walking into position watches the target leave.
	_hands_nowhere(reader)
	reader.tick(TICK)
	for i in range(int(SignalGhosts.BEAT / TICK) + 4):
		ghosts._process(TICK)
	_check("the_guide_waits_while_your_hands_are_not_there_yet",
		_ghosts_at(ghosts) == first,
		"%s after a beat and a bit" % ["still the first pose"
			if _ghosts_at(ghosts) == first else "it moved on without me"])

	# AND MOVES ON THE MOMENT THEY ARRIVE. Being in the pose is what advances it, so the
	# guide leads rather than races.
	_hands_in(reader, &"chest")
	reader.tick(TICK)
	for i in range(int(SignalGhosts.BEAT / TICK) + 4):
		ghosts._process(TICK)
	_check("and_moves_on_once_they_are",
		_ghosts_at(ghosts) != first,
		"%s once both hands were in it" % ["advanced"
			if _ghosts_at(ghosts) != first else "still showing the same pose"])

	# AND IT STILL DEMONSTRATES ITSELF TO SOMEBODY DOING NOTHING. A beckon that never
	# repeated would be a still picture of a movement.
	var parked: Array = _ghosts_at(ghosts)
	_hands_nowhere(reader)
	reader.tick(TICK)
	for i in range(int(SignalGhosts.IDLE / TICK) + 8):
		ghosts._process(TICK)
	_check("and_a_beckon_still_shows_that_it_repeats",
		_ghosts_at(ghosts) != parked,
		"%s after %.1f s of nothing" % ["it went round"
			if _ghosts_at(ghosts) != parked else "it froze", SignalGhosts.IDLE])
	reader.queue_free()


## BOTH HANDS IN ONE ZONE, and both hands nowhere, on a reader of this section's own. The
## suite's `_put*` helpers drive `_reader`, which is a different one.
func _hands_in(reader: SignalReader, zone: StringName) -> void:
	for hand in range(2):
		reader.force_hand(hand,
			SignalZones.place(zone, hand, reader.reach, reader.shoulder), 0.0, 0.0)


func _hands_nowhere(reader: SignalReader) -> void:
	for hand in range(2):
		reader.force_hand(hand, Vector3(0.0, -3.0, 0.0), 0.0, 0.0)


## Where the visible ghosts are, rounded, so two poses can be compared for being different.
func _ghosts_at(ghosts: SignalGhosts) -> Array:
	var out: Array = []
	for node in ghosts.get_children():
		var ball := node as MeshInstance3D
		if ball != null and ball.visible:
			out.append(ball.position.snapped(Vector3.ONE * 0.01))
	# SORTED SO TWO POSES CAN BE COMPARED, and on the numbers rather than on their text.
	# `String(vector)` is not a constructor Godot has -- it is `str()` -- and it does not
	# fail the comparison, it logs an engine error every call and sorts on nothing.
	out.sort_custom(func(a, b):
		if not is_equal_approx(a.x, b.x):
			return a.x < b.x
		if not is_equal_approx(a.y, b.y):
			return a.y < b.y
		return a.z < b.z)
	return out


## ---- and a way in ------------------------------------------------------------------

## THE ROOM IS ON THE DESK. Every door in the router is meant to be reachable with a headset
## on, and a place that can only be opened by typing a command line is a place nobody in a
## headset can get to. The cockpit suite makes the same check about its own five; this one
## is about ours, and it lives here so this directory keeps its own promises in its own
## suite.
func _the_doors() -> void:
	var page := (load("res://ui/menus/level_menu.tscn") as PackedScene).instantiate()
	add_child(page)
	var named: Array[String] = []
	for node in page.find_children("*", "Button", true, false):
		named.append(String((node as Button).text).to_lower())
	var missing: Array[String] = []
	for want in ["carrier", "stand", "signal"]:
		var found: bool = false
		for got in named:
			if got.contains(want):
				found = true
		if not found:
			missing.append(want)
	_check("both_levels_are_on_the_desk", missing.is_empty(),
		"%s" % ["all three doors" if missing.is_empty() else missing])
	# AND EVERY DOOR OPENS ONTO SOMETHING. The router and the desk both ask
	# `MarshallingLevel.scene_for`, so a path typo there is a button that silently does
	# nothing -- in a headset, with no console to read.
	var broken: Array[String] = []
	var scenes: Array[String] = []
	for door in MarshallingLevel.DOORS:
		var scene: String = MarshallingLevel.scene_for(door)
		if not ResourceLoader.exists(scene):
			broken.append("%s -> %s" % [door, scene])
		elif not scenes.has(scene):
			scenes.append(scene)
	_check("and_every_door_opens_onto_a_scene", broken.is_empty(),
		"%s" % ["%d names, %d levels" % [MarshallingLevel.DOORS.size(), scenes.size()]
			if broken.is_empty() else broken])
	page.queue_free()



## ---- the whole job, done by a robot -------------------------------------------------

## MARSHAL A JET ONTO THE CATAPULT, WITH NO HANDS AND NO HEADSET.
##
## The robot is deliberately not clever: it looks at where the nosewheel is, decides which
## signal a marshaller would be making, and makes it -- properly, at a real rate, through
## the real reader. So this fails if the zones are wrong, if the book is ambiguous, if the
## pilot ignores an order, if the checklist wants them in an order nobody could do, or if
## the aeroplane cannot physically be steered onto the track from where it starts.
##
## Which is the whole level, and it is the one test that cannot be got right by accident.
func _the_whole_launch() -> void:
	var deck := await _the_whole_job("res://marshalling/deck_launch.tscn", "catapult")
	_check("a_robot_can_marshal_a_jet_onto_the_catapult",
		deck["done"] and deck["ended"], deck["said"])
	_check("and_stops_her_on_the_shuttle", deck["off"] < DeckLaunch.CLOSE_ENOUGH,
		"nosewheel %.2f m from the bar, %d mistakes" % [deck["off"], deck["faults"]])

	_check("and_her_wingtip_never_reached_the_marshaller",
		float(deck["gap"]) > 2.0,
		"%.1f m at the closest, on a %.1f m span" % [deck["gap"], deck["span"]])

	# AND THE SAME HANDS ON A DIFFERENT AEROPLANE. Twenty-six metres of airliner turns
	# nothing like six metres of fighter, and the whole point of the second level is that
	# the signals do not change and the aeroplane does.
	var gate := await _the_whole_job("res://marshalling/gate_arrival.tscn", "stand")
	_check("a_robot_can_bring_an_airliner_onto_the_stand",
		gate["done"] and gate["ended"], gate["said"])
	_check("and_the_bridge_reaches_the_door", gate["off"] < GateArrival.CLOSE_ENOUGH,
		"nosewheel %.2f m from the bar, %d mistakes" % [gate["off"], gate["faults"]])
	_check("and_the_airliner_wingtip_did_not_either",
		float(gate["gap"]) > 2.0,
		"%.1f m at the closest, on a %.1f m span" % [gate["gap"], gate["span"]])
	_check("and_neither_job_called_anything_it_did_a_mistake",
		int(deck["faults"]) == 0 and int(gate["faults"]) == 0,
		"deck %d, stand %d" % [deck["faults"], gate["faults"]])


func _the_whole_job(scene: String, called: String) -> Dictionary:
	var level := (load(scene) as PackedScene).instantiate() as MarshallingLevel
	add_child(level)
	await get_tree().physics_frame
	var reader: SignalReader = level.reader
	var jet: MarshalledCraft = level.craft
	# The reader ticks itself off `_process` in a real level. Here the hands are put in
	# place and the frames are real ones, so it is left alone to do that.
	# AN ARRAY, because a GDScript lambda captures a local by VALUE. `launched = true`
	# inside the closure sets the closure's own copy and the test reads false for ever.
	var said: Array[String] = []
	level.procedure.fault.connect(func(why: String) -> void: said.append(why))

	# THE LAST STEP OF EITHER JOB IS THE ONE WITH A PAYOFF IN IT -- a catapult stroke, a
	# bridge swinging on -- and both of them are things the WORLD does after the last
	# signal. So what is watched for is the procedure finishing.
	var ended: Array[bool] = [false]
	level.procedure.finished.connect(func(_score: Dictionary) -> void: ended[0] = true)
	var making: StringName = &""
	var since: float = 0.0
	var decide: float = 0.0
	# WINGTIP CLEARANCE, measured over the whole run rather than worked out from the plan.
	# The marshaller stands still and the aeroplane comes to them, and a fifteen-metre span
	# passing a post nine metres out is a decapitation. An array because the closure below
	# would otherwise capture a copy -- see the note on `ended`.
	var post: Vector3 = level.post_pose().origin
	var gap: Array[float] = [INF]
	var seconds: float = 0.0
	while seconds < 150.0 and not level.procedure.done:
		var delta: float = get_process_delta_time()
		# A MARSHALLER DOES NOT CHANGE THEIR MIND EVERY FRAME, and a reader cannot read a
		# signal that is abandoned halfway through: two cycles of a wave is the best part
		# of a second. So the robot decides at the rate a person would, and then commits
		# to it -- which is a constraint on the GAME as much as on the test.
		decide -= delta
		if decide <= 0.0:
			decide = 0.6
			var wanted: StringName = _what_a_marshaller_would_do(level, jet)
			if OS.has_environment("MARSHAL_TRACE"):
				print("[robot] %s nose %.1f,%.1f head %.1f steer %.1f speed %.2f" % [wanted,
					jet.nose().x, jet.nose().z, rad_to_deg(jet.heading()),
					rad_to_deg(jet.steer), jet.speed])
			if wanted != making:
				making = wanted
				since = 0.0
		since += delta
		_making(reader, making, since)
		for tip in jet.wingtips():
			gap[0] = minf(gap[0], (tip as Vector3).distance_to(post))
		await get_tree().process_frame
		seconds += delta

	var span: float = float(Sim.geometry_of(jet.kind).get("span", 0.0))
	var told: String = "%s in %.0f s, at step %d of %d" % ["finished"
		if level.procedure.done else "gave up", seconds, level.procedure.at,
		level.procedure.steps.size()]
	if not level.procedure.done:
		told += " -- nose %s heading %.1f deg rolling %s" % [jet.nose(),
			rad_to_deg(jet.heading()), jet.is_rolling()]
	var marks: Dictionary = level.procedure.marks
	var out: Dictionary = {
		"done": level.procedure.done,
		"ended": ended[0],
		"faults": level.procedure.faults + said.size(),
		"off": String(marks.get("on the bar", "99")).split(" ")[0].to_float(),
		"said": "%s on the %s" % [told, called],
		"gap": gap[0],
		"span": span,
	}
	level.queue_free()
	return out


## WHAT A MARSHALLER WOULD BE DOING RIGHT NOW: the checklist says which step, and on the two
## steps that are about MOVING an aeroplane, where the aeroplane is says the rest.
func _what_a_marshaller_would_do(level: MarshallingLevel,
		jet: MarshalledCraft) -> StringName:
	var step: StringName = level.procedure.expects()
	var line: Vector2 = level.the_line()
	var nose: Vector3 = jet.nose()
	var to_go: float = nose.z - line.y
	# THE LINEUP IS NOT OVER WHEN THE CHECKLIST TICKS IT OFF. She is still forty metres from
	# the bar and still crabbing, so the same steering runs through the first half of the
	# stopping step -- which is what a marshaller does: keep her straight while you slow her.
	if step == &"come_ahead" or (step == &"normal_stop" and to_go > 22.0):
		# Crab towards the track and straighten as it arrives. `heading` is negative when
		# the nose is swung to the left, which is the way an aeroplane at x = +5 has to go
		# to reach a track at x = -14.
		var off: float = nose.x - line.x
		# A SMALL CRAB, not a big one. There is the better part of two seconds between
		# deciding something and the nosewheel doing it, so a correction big enough to be
		# quick is a correction that arrives late enough to be wrong.
		# AND STRAIGHTEN HER UP AS THE MARK COMES UP. A crab that is still there at the bar
		# is a metre of drift while she rolls the last twenty, which on a stand is a bridge
		# that does not reach. So the crab is washed out over the last thirty metres and
		# what is left is a straight aeroplane slightly off the line, which is the right way
		# round of the two.
		var wanted: float = clampf(-off * 0.05, -0.21, 0.21) \
			* clampf(to_go / 30.0, 0.0, 1.0)
		# HOW HARD TO WAVE, WORKED OUT BACKWARDS FROM HOW HARD SHE SHOULD BE TURNING.
		#
		# Everything in this loop is late: a wave takes two strokes to be read, the pilot
		# takes half a second to answer, and the gear takes another to swing across. A
		# marshaller who waits to SEE the heading come right has already asked for far too
		# much, and the robot that did that snaked fifty degrees either side of the track
		# for the length of the ship.
		#
		# So there is a damping term -- how fast the nose is ALREADY coming round -- and
		# the answer is a nosewheel angle rather than a direction. The rate of the wave
		# then follows from the angle, because that is what the rate MEANS: see the note in
		# `MarshalledCraft` about turning as hard as you are waved at.
		var swinging: float = -(jet.speed / jet.wheelbase) * tan(jet.steer)
		var error: float = angle_difference(jet.heading(), wanted)
		var lock: float = clampf(error * 1.6 - swinging * 4.5, -jet.lock, jet.lock)
		var strength: float = clampf(absf(lock) / jet.lock, 0.0, 1.0)
		# The rate band a strength means, read off the book rather than guessed at.
		var band: Vector2 = (SignalBook.of(&"come_ahead") as Dictionary)["rate"]
		_wave = 1.0 / (2.0 * lerpf(band.x, band.y, maxf(strength, 0.2)))
		if strength < 0.25:
			return &"come_ahead"
		return &"turn_left" if lock < 0.0 else &"turn_right"
	if step == &"normal_stop":
		# THE WHOLE SKILL OF THE JOB, in three lines: wave her on while there is room,
		# wave her down as the bar comes up, and call the stop EARLY -- because half a
		# second of pilot and a metre of braking happen after your arms cross.
		if to_go > 2.2:
			return &"slow_down"
		return &"normal_stop"
	return step


## MAKE THAT SIGNAL, at a real rate, `since` seconds into it. The same walk the tests above
## do, driven by a clock instead of by a list.
func _making(reader: SignalReader, id: StringName, since: float) -> void:
	if id == &"":
		return
	var row: Dictionary = SignalBook.of(id)
	var steps: Array = row["steps"]
	match int(row["mode"]):
		SignalBook.Mode.CYCLE:
			_put_on(reader, steps[int(since / _wave) % steps.size()])
		SignalBook.Mode.CIRCLE:
			var hand: int = int(row.get("hand", SignalZones.RIGHT))
			var zone: StringName = row.get("zone", &"overhead")
			var middle: Vector3 = SignalZones.place(zone, hand, reader.reach,
				reader.shoulder)
			# THE AUTHORED RADIUS, not the slackened one -- see SignalZones.core. A circle
			# scaled off the SLACK swings wider as the slack goes up, and a wide enough
			# circle leaves `overhead` for whatever is next to it, which reads as a hand
			# that has stopped circling. What the slack widens is how far out a hand still
			# counts as being IN a zone, not how big a movement inside it should be.
			var span: float = SignalZones.core(zone, reader.reach) * 0.7
			var turn: float = since * 8.0
			reader.force_hand(hand,
				middle + Vector3(cos(turn) * span, 0.0, sin(turn) * span), 0.0, 0.0)
		SignalBook.Mode.HOLD:
			_put_on(reader, steps[0])
		_:
			var dwell: float = maxf(0.3, float(row.get("not_before", 0.0)) + 0.15)
			_put_on(reader, steps[mini(int(since / dwell), steps.size() - 1)])


func _put_on(reader: SignalReader, step: Array) -> void:
	for hand in range(2):
		var spec: Dictionary = step[hand]
		var zones: Array = spec["zones"]
		if zones.is_empty():
			reader.force_hand(hand, Vector3(0.0, -3.0, 0.0), 0.0, 0.0)
			continue
		var grip: float = 1.0 if int(spec["grip"]) == SignalBook.Grip.FIST else 0.0
		var up: float = 0.0
		if int(spec["palm"]) == SignalBook.Palm.UP:
			up = 1.0
		elif int(spec["palm"]) == SignalBook.Palm.DOWN:
			up = -1.0
		reader.force_hand(hand,
			SignalZones.place(zones[0], hand, reader.reach, reader.shoulder), grip, up)


## ---- driving the hands --------------------------------------------------------------

## WALK ONE SIGNAL, PROPERLY, and report everything that was heard while it was made.
func _walk(id: StringName) -> Array[StringName]:
	_settle()
	_heard.clear()
	var row: Dictionary = SignalBook.of(id)
	var steps: Array = row["steps"]
	match int(row["mode"]):
		SignalBook.Mode.HOLD:
			_put(steps[0])
			_run(float(row.get("dwell", 0.5)) + 0.2)
		SignalBook.Mode.ONCE:
			# Long enough in the first pose to clear a `not_before`, short enough to stay
			# inside `within`. A signal whose two limits leave no room for that is a signal
			# nobody could make either.
			var dwell: float = maxf(0.15, float(row.get("not_before", 0.0)) + 0.08)
			for step in steps:
				_put(step)
				_run(dwell)
		SignalBook.Mode.CYCLE:
			_cycle(id, 0.3)
		SignalBook.Mode.CIRCLE:
			_circle(id)
	return _heard.duplicate()


## A CYCLING SIGNAL, at a given half-period. Six half-strokes: enough to count the cycles
## the book asks for and then keep going, which is what a real one does.
func _cycle(id: StringName, half: float) -> void:
	var steps: Array = (SignalBook.of(id) as Dictionary)["steps"]
	for i in range(7):
		_put(steps[i % steps.size()])
		_run(half)


## A HAND GOING ROUND. Round the middle of its zone, at a radius the reader will believe.
func _circle(id: StringName) -> void:
	var row: Dictionary = SignalBook.of(id)
	var hand: int = int(row.get("hand", SignalZones.RIGHT))
	var zone: StringName = row.get("zone", &"overhead")
	var middle: Vector3 = SignalZones.place(zone, hand, _reader.reach, _reader.shoulder)
	var span: float = SignalZones.core(zone, _reader.reach) * 0.7
	_put_nowhere(SignalZones.LEFT if hand == SignalZones.RIGHT else SignalZones.RIGHT)
	for i in range(60):
		var turn: float = float(i) * 0.35
		_reader.force_hand(hand,
			middle + Vector3(cos(turn) * span, 0.0, sin(turn) * span), 0.0, 0.0)
		_run(TICK)


## One parsed step, put on the hands: the first zone each hand accepts, and whatever the
## step asks that hand to be doing.
func _put(step: Array) -> void:
	for hand in range(2):
		var spec: Dictionary = step[hand]
		var zones: Array = spec["zones"]
		if zones.is_empty():
			_put_nowhere(hand)
			continue
		var grip: float = 1.0 if int(spec["grip"]) == SignalBook.Grip.FIST else 0.0
		var up: float = 0.0
		if int(spec["palm"]) == SignalBook.Palm.UP:
			up = 1.0
		elif int(spec["palm"]) == SignalBook.Palm.DOWN:
			up = -1.0
		_put_hand(hand, zones[0], grip, up)


func _put_hand(hand: int, zone: StringName, grip: float, up: float) -> void:
	_reader.force_hand(hand,
		SignalZones.place(zone, hand, _reader.reach, _reader.shoulder), grip, up)


## A hand that is not in any zone at all, which is where most hands are most of the time.
func _put_nowhere(hand: int) -> void:
	_reader.force_hand(hand, Vector3(0.0, -3.0, 0.0), 0.0, 0.0)


func _put_zones(left: StringName, right: StringName) -> void:
	if left == SignalZones.NOWHERE:
		_put_nowhere(SignalZones.LEFT)
	else:
		_put_hand(SignalZones.LEFT, left, 0.0, 0.0)
	if right == SignalZones.NOWHERE:
		_put_nowhere(SignalZones.RIGHT)
	else:
		_put_hand(SignalZones.RIGHT, right, 0.0, 0.0)


func _hold(left: StringName, right: StringName, seconds: float) -> void:
	_put_zones(left, right)
	_run(seconds)


func _run(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		_reader.tick(TICK)
		left -= TICK


## HANDS DOWN AND EVERYTHING FORGOTTEN, between one test and the next. Without it a matcher
## left half-armed by the previous line completes in the middle of the next one, which is a
## failure in the test rather than in the code and takes an hour to see.
func _settle() -> void:
	_put_nowhere(SignalZones.LEFT)
	_put_nowhere(SignalZones.RIGHT)
	_run(SignalBook.LAPSE + 0.5)
	_heard.clear()


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)

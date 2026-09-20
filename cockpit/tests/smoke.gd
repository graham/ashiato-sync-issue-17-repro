extends Node
## Headless: does the whole Godot side stand up, and is the cockpit actually steady?
##
##   Godot --headless res://tests/smoke.tscn
##
## The loopback test in ashiato-gd proves the wire format and the simulation. This proves
## the things that only exist in a scene tree, and the one that matters most is the last:
## that a pilot's pose relative to their cockpit is EXACTLY constant while the vehicle is
## moving fast, because it is never computed rather than because it is computed carefully.
##
## Read RESULT=, not the exit code.

var _failures: PackedStringArray = []
var _level: Node = null
var _flat_total: float = 0.0
var _vertical_total: float = 0.0
## Which sections of this suite ran to the end. Names make an early return actionable;
## the former anonymous count could only say "9 of 10" after every visible check passed.
var _sections: Dictionary = {}
const EXPECTED_SECTIONS: PackedStringArray = [
	"render_scale", "joining", "hall", "railway", "new_craft", "cockpit",
	"hand_bindings", "hud", "world", "traffic",
]
var _in_slot: int = 0
var _crosstrack_total: float = 0.0
var _along_total: float = 0.0
var _plane_slip: Array[float] = []
var _heli_slip: Array[float] = []
var _convoy_slip: Array[float] = []
var _nose_off: Array[float] = []
var _stragglers: Array = []
var _slot_slip: Array[float] = []
## How many legs each autopilot had chosen when the traffic started being watched, and which machines lead a flight of
## light aeroplanes. Together they say how many new legs a leader took during the run -- a leader that keeps changing
## its mind is a flight that keeps turning, and until 2026-09-14 that showed only as spread.
var _legs_at_start: Dictionary = {}
var _plane_leaders: Dictionary = {}
## And the light aeroplanes that follow them, whose escape climbs out of the slot are the other way a flight spreads.
var _plane_followers: Dictionary = {}


## Degrees between a follower's nose and the direction its LEADER is actually travelling.
func _nose_off_track(leader: int, follower: Dictionary) -> float:
	var lead: Dictionary = Sim.server.vehicle_state(leader)
	var track: Vector3 = lead.get("velocity", Vector3.ZERO)
	track.y = 0.0
	if track.length() < 2.0:
		return 0.0
	var nose: Vector3 = (follower.get("basis", Quaternion.IDENTITY) as Quaternion) \
		* Vector3(0.0, 0.0, -1.0)
	nose.y = 0.0
	if nose.length_squared() < 1e-6:
		return 0.0
	return absf(rad_to_deg(angle_difference(atan2(track.x, -track.z),
		atan2(nose.x, -nose.z))))


func _summary(rows: Array[float]) -> String:
	if rows.is_empty():
		return "none"
	var total: float = 0.0
	var worst: float = 0.0
	for row in rows:
		total += row
		worst = maxf(worst, row)
	return "%d, average %.0f m, worst %.0f m" % [rows.size(), total / float(rows.size()),
		worst]
## Preloaded rather than named: a class_name declared in a file the project has not
## rescanned yet is not in scope, and the failure reads as the class not existing.
const SEGMENT_PROBE: GDScript = preload("res://tests/segment_probe.gd")


func _check(label: String, ok: bool, detail: String) -> void:
	print("[smoke] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_check("extension_loaded", ClassDB.class_exists("CockpitWorld"), "CockpitWorld registered")
	if not ClassDB.class_exists("CockpitWorld"):
		_finish()
		return

	_level = load("res://world/sky.tscn").instantiate()
	# Deferred: the tree is still setting up this node's children, and add_child from
	# inside _ready fails with "Parent node is busy setting up children" -- which the level
	# never sees, so the whole test would run against a level that was never in the tree.
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in range(240):
		await get_tree().physics_frame

	_check("sim_ready", Sim.is_ready, "client reached Ready")
	_check("has_sync_client_id", Sim.local_client_id() > 0,
		"sync client %d" % Sim.local_client_id())

	# ---- the air is still ------------------------------------------------------------
	#
	# Asked for on 2026-09-14: no wind anywhere. Asked of the SERVER once the level has built the
	# world, at the surface and a kilometre up, because the level is what tells the simulation and
	# the shear is what made the air faster higher up. See `Terrain.WIND`.
	var surface: Vector3 = Sim.server.wind(0.0) if Sim.server != null else Vector3.ONE
	var aloft: Vector3 = Sim.server.wind(1000.0) if Sim.server != null else Vector3.ONE
	_check("the_air_is_still_once_the_level_is_built",
		surface.length() < 0.001 and aloft.length() < 0.001,
		"%v at the surface, %v a kilometre up" % [surface, aloft])

	# ---- the brigs are on the sea ------------------------------------------------------
	#
	# The level spawns `Terrain.PIRATE_FLEET` brigs from `Terrain.pirates`. `tests/pirate_ai.gd` holds where they start;
	# this holds that the level starts them at all, which nothing else did: a spawn loop that ran over nothing was green.
	var brigs: int = 0
	if Sim.server != null:
		for vehicle in Sim.server.vehicle_states():
			brigs += 1 if int(vehicle["kind"]) == Sim.Kind.PIRATE else 0
	_check("the_level_puts_its_brigs_on_the_sea", brigs == Terrain.PIRATE_FLEET,
		"%d brigs on the server, %d asked for" % [brigs, Terrain.PIRATE_FLEET])

	# ---- the fleet's new craft are in the world -----------------------------------------------------------------------
	#
	# THE SUBMARINE AND BOTH HAWKEYES, counted on the server against the level's own table, so a spawn line removed goes red
	# here and not only somewhere nobody is counting (cockpit-pirate: a spawn loop that ran over nothing was green).
	var wanted: Dictionary = {Sim.Kind.SUBMARINE: 0, Sim.Kind.HAWKEYE: 0}
	for spawn in Terrain.spawns():
		if wanted.has(int(spawn["kind"])):
			wanted[int(spawn["kind"])] += 1
	var found: Dictionary = {Sim.Kind.SUBMARINE: 0, Sim.Kind.HAWKEYE: 0}
	if Sim.server != null:
		for vehicle in Sim.server.vehicle_states():
			if found.has(int(vehicle["kind"])):
				found[int(vehicle["kind"])] += 1
	_check("the_level_puts_the_submarine_to_sea_and_both_hawkeyes_out",
		wanted[Sim.Kind.SUBMARINE] == 1 and wanted[Sim.Kind.HAWKEYE] == 2 and found == wanted,
		"on the server %d submarine(s) and %d Hawkeye(s); the table asks for %d and %d" % [found[Sim.Kind.SUBMARINE],
			found[Sim.Kind.HAWKEYE], wanted[Sim.Kind.SUBMARINE], wanted[Sim.Kind.HAWKEYE]])

	# ---- one clock ---------------------------------------------------------------
	_check("physics_rate_follows_the_tick_rate",
		Engine.physics_ticks_per_second == int(round(Sim.tick_hz)),
		"physics %d Hz, simulation %.0f Hz" % [Engine.physics_ticks_per_second, Sim.tick_hz])

	# ---- every player is in a vehicle ---------------------------------------------
	var vehicles: Array = Sim.client.vehicle_states()
	var pilots: Array = Sim.client.pilot_states()
	_check("vehicles_replicated", vehicles.size() >= 5,
		"%d vehicle(s): one per player plus the spares" % vehicles.size())
	_check("the_player_has_a_vehicle", pilots.size() >= 1
			and int(pilots[0].get("vehicle", 0)) != 0,
		"pilot is in vehicle %s seat %s" % [pilots[0].get("vehicle", 0),
			pilots[0].get("seat", "?")])

	# ---- a pilot has no world pose -------------------------------------------------
	#
	# Checked as an ABSENCE, deliberately. The promise is not that the world pose is right,
	# it is that there is not one to be wrong.
	_check("a_pilot_publishes_no_world_pose",
		not pilots[0].has("position") and pilots[0].has("head"),
		"keys are %s" % [pilots[0].keys()])

	# ---- the rig is a child of a seat ----------------------------------------------
	var rig: PilotRig = _level.rig
	_check("the_rig_is_seated", rig != null and rig.is_seated(),
		"parent is %s" % (rig.get_parent().name if rig != null else "-"))
	_check("the_rig_holds_no_pose_of_its_own",
		rig.transform.is_equal_approx(Transform3D.IDENTITY)
			and rig.origin.transform.is_equal_approx(Transform3D.IDENTITY),
		"rig %s, origin %s" % [rig.transform.origin, rig.origin.transform.origin])

	# AWAITED, all of them. A section that contains an `await` and is called without one
	# returns a coroutine immediately: the rest of the suite runs past it, its checks land
	# after the results have been printed, and the only sign is a section that quietly
	# stopped halfway. That is precisely what `every_section_of_the_suite_ran` is for, and
	# it caught this the first time a section grew an await.
	await _test_the_railway()
	await _test_joining_and_leaving()
	await _test_the_hall()
	await _test_the_new_craft()
	await _test_the_cockpit(rig)
	_test_the_hand_bindings(rig)
	await _test_the_hud(rig)
	_test_the_world()
	_test_where_the_autopilots_are_sent()
	await _test_the_traffic()
	await _test_smoothness(rig)
	_test_the_render_scale_knob()
	_finish()


## ---- the knob a headset that drops frames is told to turn first -------------------------

## WHAT `--render-scale=` MEANS, asked of the function the rig actually sets the swapchain from.
##
## Added on 2026-09-15 with the move back to the Mobile renderer: 1.4 is twice the pixels of 1.0 and the largest single
## GPU cost in the game, and until then it could only be changed by editing `PilotRig` and restarting. NOTHING here has
## ever been timed in a headset, so the number a player wants is one only they can find.
##
## PURE, so this asks it what a command line means without a rig, a headset or a swapchain -- which is the only part a
## headless suite can hold. That the rig SETS it is `_ask_for_more_pixels`, three lines, and needs a runtime to prove.
##
## A NUMBER OUTSIDE THE RANGE IS REFUSED, NOT CLAMPED, and that is the case worth holding: a `--render-scale=0.1` that
## quietly became 0.5 would send somebody looking for their missing pixels in the wrong place.
func _test_the_render_scale_knob() -> void:
	var cases: Array = [
		[PackedStringArray([]), PilotRig.RENDER_SCALE, "nothing asked"],
		[PackedStringArray(["--render-scale=1.0"]), 1.0, "1.0"],
		[PackedStringArray(["--render-scale=0.85"]), 0.85, "0.85"],
		[PackedStringArray(["--level=world", "--render-scale=2.0"]), 2.0, "past other flags"],
		[PackedStringArray(["--render-scale=0.1"]), PilotRig.RENDER_SCALE, "under the least, refused"],
		[PackedStringArray(["--render-scale=4"]), PilotRig.RENDER_SCALE, "over the most, refused"],
		[PackedStringArray(["--render-scale=big"]), PilotRig.RENDER_SCALE, "not a number, refused"],
	]
	var wrong: PackedStringArray = []
	for case in cases:
		var got: float = PilotRig.render_scale_asked_for(case[0] as PackedStringArray)
		if not is_equal_approx(got, float(case[1])):
			wrong.append("%s gave %.2f, wanted %.2f" % [case[2], got, float(case[1])])
	_check("the_render_scale_flag_is_read_and_a_silly_one_is_refused", wrong.is_empty(),
		"%d cases, default %.2f%s" % [cases.size(), PilotRig.RENDER_SCALE,
			"" if wrong.is_empty() else "; " + "; ".join(wrong)])
	_sections["render_scale"] = true


## ---- arriving and leaving -------------------------------------------------------------
##
## The one thing every player does twice, and the one thing that had no test at all.
##
## Three properties, each of which was broken in a way nobody would have found by flying:
## a craft made for somebody who has gone does not stay in the sky; a craft is never taken
## out from under the people sitting in it; and a machine the world provided is not a
## player's to take home.
func _test_joining_and_leaving() -> void:
	var before: int = Sim.server.vehicle_states().size()

	# ARRIVING. One call, because there is no state in which a player exists without
	# something to sit in.
	var first: Dictionary = Sim.server.spawn_pilot(180, Sim.Kind.PLANE,
		Vector3(9000.0, 700.0, 9000.0), 0.0, Vector3(0.0, 0.0, -90.0))
	var one: int = int(first.get("pilot", 0))
	var wing: int = int(first.get("vehicle", 0))
	_check("a_player_who_joins_gets_a_seat",
		one != 0 and wing != 0 and int(Sim.server.vehicle_seats(wing)[0]) == 180,
		"client 180 is in seat 0 of entity %d" % wing)

	# AND A SECOND PLAYER CAN SIT DOWN BESIDE THEM. This is the whole of two-crew flight
	# and the reason the seat button walks craft with a FREE seat rather than empty ones.
	var second: Dictionary = Sim.server.spawn_pilot(181, Sim.Kind.PLANE,
		Vector3(9400.0, 700.0, 9000.0), 0.0, Vector3(0.0, 0.0, -90.0))
	var two: int = int(second.get("pilot", 0))
	var spare: int = int(second.get("vehicle", 0))
	await get_tree().physics_frame
	# INTO THAT ONE, by name. The seat buttons walk the world's hundred and sixty machines
	# in entity order, which is the right control for a player browsing and no way at all
	# to ask for a particular aeroplane -- so joining a friend is its own call.
	var welcomed: bool = Sim.server.seat_client(181, wing, 1)
	for _settling in range(3):
		await get_tree().physics_frame
	_check("and_can_change_seats_into_somebody_elses_craft",
		welcomed and Sim.server.vehicle_seats(wing).has(181),
		"client 181 sits in %s" % [Sim.server.vehicle_seats(wing)])

	# THE CRAFT THEY LEFT BEHIND GOES AWAY. Everybody arriving is given one, and until this
	# nothing ever gave one back: a session of people joining, switching craft and quitting
	# filled the sky with empty aeroplanes flying straight and level for ever.
	# A REAL PILOT AND A REAL CRAFT FIRST: `vehicle_state(0)` is empty too, so a second spawn that failed passed this.
	_check("and_the_craft_they_left_is_not_left_flying_empty",
		two != 0 and spare != 0 and Sim.server.vehicle_state(spare).is_empty(),
		"the abandoned craft is %s" % [
			"gone" if Sim.server.vehicle_state(spare).is_empty() else "still there"])

	# LEAVING, while somebody else is aboard. The host tidies up after a departing player
	# by removing the craft it made for them -- which by now is a craft with a live
	# crewmate in it, and removing it dropped that crewmate into nowhere: no seat, and
	# every seat control returning early because they had no seat to leave.
	Sim.server.despawn_pilot(one)
	Sim.server.despawn_vehicle(wing)
	for _settling in range(3):
		await get_tree().physics_frame
	_check("and_a_craft_is_not_removed_under_the_crew_still_in_it",
		not Sim.server.vehicle_state(wing).is_empty(),
		"the craft with a crewmate aboard is %s" % [
			"still flying" if not Sim.server.vehicle_state(wing).is_empty() else "gone"])
	_check("and_that_crewmate_is_still_sitting_somewhere",
		not Sim.server.vehicle_state(wing).is_empty()
			and Sim.server.vehicle_seats(wing).has(181),
		"seats now %s" % [Sim.server.vehicle_seats(wing)])

	# AND THE LAST OF THEM LEAVING TAKES IT WITH THEM, which is the same rule applied one
	# tick later: what was made for a player and now holds nobody is litter.
	Sim.server.despawn_pilot(two)
	for _settling in range(3):
		await get_tree().physics_frame
	_check("and_the_last_one_out_takes_the_craft_with_them",
		Sim.server.vehicle_state(wing).is_empty(),
		"the emptied craft is %s" % [
			"gone" if Sim.server.vehicle_state(wing).is_empty() else "still there"])

	# NOTHING OF THE WORLD WENT WITH THEM. A player who borrows a parked machine and quits
	# must not take it out of the world: only what was MADE for them is theirs to lose.
	_check("and_the_world_is_the_size_it_was",
		Sim.server.vehicle_states().size() == before,
		"%d craft before, %d after two players came and went" % [
			before, Sim.server.vehicle_states().size()])

	# Reached the end of this section. See _finish.
	_sections["joining"] = true


## ---- every cockpit, on its own, with no aircraft behind it ---------------------------
##
## The hall is seats and nothing else: no fuselage, no world, no simulation. That is what
## makes it useful for judging a cockpit, and it is also a path nothing else takes -- the
## rig normally finds its controls by looking for the VehicleView its seat hangs off, and in
## there the seat hangs off a plinth.
##
## ITS OWN SECTION, because it puts a SECOND rig in the scene and lets frames pass. Dropped
## into the middle of the cockpit section it broke two checks three hundred lines further
## down, which set a hand on a control and expect no frame to run before they look at it.
func _test_the_hall() -> void:
	#
	# The hall is seats and nothing else: no fuselage, no world, no simulation. That is what
	# makes it useful for judging a cockpit, and it is also a path nothing else takes -- the
	# rig normally finds its controls by looking for the VehicleView its seat hangs off, and
	# in there the seat hangs off a plinth. `PilotRig.take_station` is what bridges it, and
	# this is what says the bridge holds.
	var hall := (load("res://world/hall.tscn") as PackedScene).instantiate() as CockpitHall
	add_child(hall)
	await get_tree().process_frame
	_check("every_cockpit_stands_on_its_own_in_the_hall",
		hall.station_count() >= 6,
		"%d distinct stations, one per scene rather than one per kind" % hall.station_count())
	# AND THE HANDS REACH THEM. Sitting down in there has to claim the controls, or it is a
	# museum: the whole point is to grab things.
	var reached: Array = []
	for i in range(hall.station_count()):
		hall.sit_at(i)
		await get_tree().process_frame
		var got: Dictionary = hall.rig().my_controls_for_the_test()
		if got.is_empty():
			reached.append(hall.name_at(i))
	_check("and_the_hands_claim_the_controls_at_every_one", reached.is_empty(),
		"%s" % ["every station is reachable" if reached.is_empty() else reached])
	hall.queue_free()

	# ---- and the desk has a screen for each question ---------------------------------
	#
	# Three panels in an arc: WHICH LEVEL, WHO you are playing with, and WHERE you are going.
	# They are separate because they are separate questions -- a solo session in the hall of
	# cockpits is a perfectly ordinary thing to want -- and every door on the third one was
	# already reachable from a command line, which is a poor thing to reach for in a headset.
	# tests/desk_screens.gd holds that the three stand inside the desk top and clear of each other.
	var desk := (load("res://world/desk.tscn") as PackedScene).instantiate() as DeskRoom
	add_child(desk)
	for _settling in range(3):
		await get_tree().process_frame
	# THE SCREENS ON THE DESK, and not the one in the player's hand. Every rig carries a
	# clipboard now -- see `Clipboard` -- and it is a `TouchPanel` in the same tree as these
	# two, held rather than stood on the furniture. Counting every panel in the room counts
	# it as a third screen on the desk, which it is not.
	var screens: Array = []
	for found in desk.find_children("*", "TouchPanel", true, false):
		var carried: bool = false
		var walk: Node = found
		while walk != null:
			if walk is PilotRig:
				carried = true
				break
			walk = walk.get_parent()
		if not carried:
			screens.append(found)
	_check("the_desk_has_a_screen_for_each_question", screens.size() == 3,
		"%d screen(s) on the desk" % screens.size())
	var doors: LevelMenu = null
	var sessions: SessionMenu = null
	var charts: ChartMenu = null
	for screen in screens:
		var page: Control = (screen as TouchPanel).shown()
		if page is LevelMenu:
			doors = page as LevelMenu
		elif page is SessionMenu:
			sessions = page as SessionMenu
		elif page is ChartMenu:
			charts = page as ChartMenu
	_check("and_one_is_the_levels_one_the_session_and_one_the_doors",
		doors != null and sessions != null and charts != null,
		"levels %s, session %s, doors %s" % ["yes" if charts != null else "no",
			"yes" if sessions != null else "no", "yes" if doors != null else "no"])
	# AND EVERY DOOR IS ON IT. Named, because a level added to the router and forgotten here
	# is a level nobody in a headset can reach.
	var named: Array[String] = []
	if doors != null:
		for node in doors.find_children("*", "Button", true, false):
			named.append(String((node as Button).text).to_lower())
	var missing: Array[String] = []
	for want in ["world", "hall of cockpits", "bench", "crew", "flying itself"]:
		var found: bool = false
		for got in named:
			if got.contains(want):
				found = true
		if not found:
			missing.append(want)
	# AND THEY STAND ON THE DESK RATHER THAN IN IT. A screen is positioned by its MIDDLE and
	# leans back, so how high its lower edge ends up is the height minus half the panel
	# times the cosine of the lean -- which is exactly the sum nobody does, and both screens
	# spent a while sunk ten centimetres into the woodwork.
	var sunk: Array = []
	for screen in screens:
		var glass := screen as TouchPanel
		var bottom: float = (glass.global_position
			- glass.global_transform.basis.y * (glass.size.y * 0.5)).y
		if bottom < DeskRoom.DESK_TOP:
			sunk.append("%s edge at %.3f" % [glass.name, bottom])
	_check("and_all_stand_on_the_desk_rather_than_in_it", sunk.is_empty(),
		"%s" % ["all clear of a %.2f m desk" % DeskRoom.DESK_TOP if sunk.is_empty()
			else sunk])
	_check("and_every_door_is_on_it", doors != null and missing.is_empty(),
		"%s" % ["all of them, and %d craft to choose from" % Sim.Kind.size()
			if missing.is_empty() else missing])
	desk.queue_free()

	# ---- and the seats that neither fly nor hold a gun have something worth looking at --------
	#
	# A pilot has a windscreen, a stick and a horizon. Somebody sitting in the back of a
	# helicopter with nothing in their hands has a screen, and that is the whole of what they
	# can know -- so they get what an F/A-18 gives the seat behind the pilot: a display either
	# side, twenty pushbuttons round each, and every page the aircraft can actually answer.
	#
	# NOT A GUNNER'S SEAT, WHICH IT USED TO BE. This asked the gunboat's aft gunner, back when
	# `gun_of` gave the ships no guns; since 2026-09-14 that seat holds a 12.7 on a pintle, and
	# a gunner holding a gun loses the screens for the reason a door gunner does (see
	# `CockpitStation._clear_the_gunners_view`). So the seat asked is the Chinook's mid-cabin
	# turret seat, which has no gun -- found by asking the gun table, not by number -- and the
	# gunboat's gunner is checked to have no screens instead.
	const CRAFT_WITH_A_WATCHER: int = Sim.Kind.CHINOOK
	var craft := (load("res://objects/vehicles/craft_%s.tscn" % Sim.kind_name(CRAFT_WITH_A_WATCHER))
		as PackedScene).instantiate() as VehicleView
	add_child(craft)
	craft._show_in_editor()
	var crewed: Array = []
	for i in range(craft.seats.size()):
		crewed.append(i)
	craft.man(crewed, 0)
	var flying_seat: int = -1
	var watching_seat: int = -1
	for i in range(craft.seats.size()):
		var mount: int = Sim.mount_of_seat(CRAFT_WITH_A_WATCHER, i)
		if bool((Sim.client.kind_geometry(CRAFT_WITH_A_WATCHER).get("seat_poses", [])
				as Array)[i].get("flies", true)):
			flying_seat = i
		elif mount < 0 or not bool(Sim.gun_of(CRAFT_WITH_A_WATCHER, mount).get("fitted", false)):
			watching_seat = i
	var watcher: CockpitStation = null
	for station in craft.stations():
		if (station as CockpitStation).seat == watching_seat:
			watcher = station as CockpitStation
	var driver: CockpitStation = null
	for station in craft.stations():
		if (station as CockpitStation).seat == flying_seat:
			driver = station as CockpitStation
	_check("a_seat_that_neither_flies_nor_holds_a_gun_gets_two_mfds",
		watcher != null and watcher.find_children("Mfd*", "CraftDisplay", true, false).size() == 2,
		"%s seat %d has %d" % [Sim.kind_name(CRAFT_WITH_A_WATCHER), watching_seat, 0 if watcher == null
			else watcher.find_children("Mfd*", "CraftDisplay", true, false).size()])
	_check("and_a_seat_that_flies_gets_none",
		driver != null and driver.find_children("Mfd*", "CraftDisplay", true, false).is_empty(),
		"the driver has %d" % [0 if driver == null
			else driver.find_children("Mfd*", "CraftDisplay", true, false).size()])
	# AND A GUNNER HOLDING A GUN GETS NONE: the gunboat's, whose gun is in their hands.
	var boat := (load("res://objects/vehicles/craft_gunboat.tscn") as PackedScene).instantiate() as VehicleView
	add_child(boat)
	boat._show_in_editor()
	var boat_crew: Array = []
	for i in range(boat.seats.size()):
		boat_crew.append(i)
	boat.man(boat_crew, 0)
	var armed: Array[String] = []
	for station in boat.stations():
		var at: CockpitStation = station as CockpitStation
		if at.controls().get("stick") is PintleGun:
			armed.append("seat %d: %d" % [at.seat, at.find_children("Mfd*", "CraftDisplay", true, false).size()])
	_check("and_a_gunner_holding_a_gun_gets_none",
		armed.size() == 2 and not ", ".join(armed).contains(": 2") and not ", ".join(armed).contains(": 1"),
		"gunboat gun seats and their screens: %s" % [armed])
	boat.queue_free()

	# TWENTY PUSHBUTTONS ROUND THE BEZEL, and MENU in the middle of the bottom row, which is
	# the whole of how a Hornet's displays are worked.
	var mfd: MfdPage = null
	if watcher != null:
		for screen in watcher.find_children("Mfd*", "CraftDisplay", true, false):
			var page: Control = (screen as CraftDisplay).shown()
			if page is MfdPage:
				mfd = page as MfdPage
	var keys: Array = [] if mfd == null else mfd.find_children("*", "Button", true, false)
	_check("and_twenty_pushbuttons_round_it", keys.size() == 20,
		"%d button(s) on the bezel" % keys.size())
	_check("and_menu_is_the_middle_of_the_bottom_row",
		keys.size() == 20 and String((keys[12] as Button).text) == "MENU",
		"button 13 reads \"%s\"" % ["" if keys.size() != 20 else (keys[12] as Button).text])

	# AND EVERY PAGE DRAWS, off the craft state and nothing else. A page that shows a
	# plausible number it did not measure is worse than no page.
	var blank: Array = []
	if mfd != null:
		var state: Dictionary = craft.craft_state()
		for page_name in MfdPage.TAC + MfdPage.SUPT:
			var lines: Array = mfd._lines_for(page_name, state)
			if lines.is_empty():
				blank.append(page_name)
	_check("and_every_page_has_something_on_it", mfd != null and blank.is_empty(),
		"%s" % ["all %d pages" % (MfdPage.TAC.size() + MfdPage.SUPT.size())
			if blank.is_empty() else blank])
	# A DASH AND NOT A ZERO for what the craft has not said. A boat has no waypoint unless
	# something is taking it somewhere, and an instrument reading 0 km to a waypoint that
	# does not exist is the kind of lie you notice in the accident report.
	var quiet: Dictionary = {"name": "gunboat"}
	var unsaid: Array = [] if mfd == null else mfd._lines_for("HSI", quiet)
	var dashed: bool = false
	for line in unsaid:
		if String(line[1]) == "---":
			dashed = true
	_check("and_says_so_when_the_craft_has_not_said", dashed,
		"a page with nothing behind it reads %s" % [unsaid])

	# ---- and a worked page is worked through the bus, not locally ---------------------
	#
	# Three of the pages can be USED rather than read: a column of check buttons, a slider,
	# and a set of exclusive buttons. What matters about all three is not the widget, it is
	# that PRESSING ONE DOES NOT MOVE IT. The press asks the command bus; the bus comes back
	# as craft state; the page draws what came back.
	#
	# That is the whole of why the gunner screen and the driver screen agree, and why
	# nobody had to write a line of code to make them. It is the same lesson as the shared
	# throttle, which jittered for exactly the opposite reason.
	var both: Array = []
	if watcher != null:
		for screen in watcher.find_children("Mfd*", "CraftDisplay", true, false):
			var page: Control = (screen as CraftDisplay).shown()
			if page is MfdPage:
				both.append(page)
	# SUPT is two presses of MENU, and SWITCHES is the seventh thing on it.
	for page in both:
		(page as MfdPage)._pressed(12)
		(page as MfdPage)._pressed(12)
		(page as MfdPage)._pressed(MfdPage.SUPT.find("SWITCHES"))
	_check("a_worked_page_can_be_selected_on_every_screen",
		both.size() == 2 and (both[0] as MfdPage)._page == "SWITCHES"
			and (both[1] as MfdPage)._page == "SWITCHES",
		"%d screen(s) showing %s" % [both.size(),
			"SWITCHES" if both.size() == 2 else "-"])

	# ONE STATE, BOTH SCREENS. The same craft state to each, and they must read the same --
	# which they do because neither of them has an opinion.
	var lit: Dictionary = craft.craft_state()
	lit["lights"] = true
	for page in both:
		(page as MfdPage).render(lit)
	var reading_on: Array = []
	for page in both:
		reading_on.append(_switch_reads(page as MfdPage, Sim.Channel.LIGHTS))
	var dark: Dictionary = craft.craft_state()
	dark["lights"] = false
	for page in both:
		(page as MfdPage).render(dark)
	var reading_off: Array = []
	for page in both:
		reading_off.append(_switch_reads(page as MfdPage, Sim.Channel.LIGHTS))
	_check("and_both_screens_read_the_same_switch",
		reading_on == [true, true] and reading_off == [false, false],
		"lit %s, dark %s" % [reading_on, reading_off])

	# AND PRESSING IT ASKS RATHER THAN SETS. The command goes out; the widget does not move
	# until the craft says it moved. A switch that moved on the press would be a switch the
	# other seat never heard about.
	var asked: Array = []
	var left := both[0] as MfdPage if both.size() == 2 else null
	if left != null:
		left.commanded.connect(func(channel, value): asked.append([channel, value]))
		var box: CheckButton = _switch_of(left, Sim.Channel.LIGHTS)
		if box != null:
			box.button_pressed = true
		# The craft has not been told yet, so the state still says dark -- and the screen
		# must still say dark with it.
		left.render(dark)
	_check("and_pressing_one_asks_the_bus_rather_than_setting_it",
		asked.size() == 1 and int(asked[0][0]) == Sim.Channel.LIGHTS
			and _switch_reads(left, Sim.Channel.LIGHTS) == false,
		"sent %s, and the switch still reads %s" % [asked,
			"-" if left == null else _switch_reads(left, Sim.Channel.LIGHTS)])
	craft.queue_free()

	# Reached the end of this section. See _finish.
	_sections["hall"] = true


## THE CHECK BUTTON FOR ONE CHANNEL on a worked MFD page, and what it reads. Reaching into
## the page because the point of the check is what the widget SAYS, which is the one thing a
## public interface would hide.
func _switch_of(page: MfdPage, channel: int) -> CheckButton:
	if page == null or page._switches == null:
		return null
	return page._switches._switches.get(channel)


func _switch_reads(page: MfdPage, channel: int) -> Variant:
	var box: CheckButton = _switch_of(page, channel)
	return null if box == null else box.button_pressed


## ---- a railway right round the island -----------------------------------------------
##
## A train is a 1D problem wearing a 3D costume: it owns one scalar position along the
## railway and one scalar speed, and its pose is read back off the track from those two.
## That is the whole design, taken from ../previous_projects/august-15-train, and it is why
## a train's replicated state is thirty bits rather than a hundred and sixty -- every peer
## builds the same railway, so every peer can work out the rest.
func _test_the_railway() -> void:
	var points: Array[Vector3] = Terrain.rail_points()
	_check("the_railway_goes_right_round", points.size() > 200
			and points[0].distance_to(points[points.size() - 1]) < Terrain.RAIL_STEP * 2.0,
		"%d points, closing to within %.0f m" % [points.size(),
			points[0].distance_to(points[points.size() - 1])])

	# NO TIGHT TURNS, and on a loop that is a curvature calculation rather than a matter of
	# taste: the circle through any three consecutive points is the bend a fifty-metre
	# train has to take there.
	var tightest: float = Terrain.tightest_curve()
	_check("and_has_no_tight_turns_anywhere_on_it", tightest > 600.0,
		"the sharpest bend has a radius of %.0f m" % tightest)

	# And it is clear of the scenery, which the generator arranges rather than luck.
	var solid: Array[Dictionary] = Terrain.boxes()
	var fouled: int = 0
	for at in points:
		if _inside_anything(solid, at + Vector3(0.0, 2.0, 0.0)):
			fouled += 1
	_check("and_nothing_was_built_on_the_line", fouled == 0,
		"%d of %d points are in the open" % [points.size() - fouled, points.size()])

	if Sim.server == null:
		return
	var engines: Array = []
	for state in Sim.server.vehicle_states():
		if int(state["kind"]) == Sim.Kind.TRAIN:
			engines.append(int(state["entity"]))
	_check("there_are_trains_on_it", engines.size() >= 2,
		"%d locomotives" % engines.size())
	if engines.is_empty():
		return

	# ON the railway, not merely near it: a pose read off the track cannot be anywhere else.
	var loco: Dictionary = Sim.server.vehicle_state(engines[0])
	var at: Vector3 = loco["position"]
	var nearest: float = INF
	for point in points:
		nearest = minf(nearest, Vector2(at.x, at.z).distance_to(Vector2(point.x, point.z)))
	_check("and_they_are_on_the_rails", nearest < Terrain.RAIL_STEP,
		"the leading locomotive is %.1f m from the nearest sleeper" % nearest)

	# ON TOP OF IT, rather than in it. The waypoints are the railhead, so a body placed with
	# its CENTRE there is buried to the waist in its own embankment -- cab floor a metre
	# underground, driver looking at ballast.
	var body: Vector3 = Sim.server.kind_geometry(Sim.Kind.TRAIN).get("extents",
		Vector3.ONE)
	_check("and_they_stand_on_top_of_the_rails",
		absf(at.y - body.y - Terrain.RAIL_HEIGHT) < 0.2,
		"underside at y %.2f, railhead at %.2f" % [at.y - body.y, Terrain.RAIL_HEIGHT])

	# FACING ALONG THE TRACK, and this is the one that was wrong. A basis built right-hand
	# side first is the MIRROR of a rotation, and a mirrored basis is not a rotation at all:
	# read back as a quaternion it collapsed to the identity, so every locomotive on the
	# loop faced due north wherever it actually was. Checked all the way round, because at
	# the one place the track happens to run north it looked perfect.
	var worst_facing: float = 0.0
	var worst_at: float = 0.0
	var total: float = Sim.server.rail_length(0)
	for i in range(48):
		var along: float = total * float(i) / 48.0
		var pose: Dictionary = Sim.server.rail_pose(0, along, 20.0, 0.0)
		if pose.is_empty():
			continue
		# Where the track goes, against where the pose says the nose points.
		var ahead: Vector3 = (Sim.server.rail_pose(0, along + 10.0, 0.0, 0.0)["position"]
			as Vector3)
		var behind: Vector3 = (Sim.server.rail_pose(0, along - 10.0, 0.0, 0.0)["position"]
			as Vector3)
		var runs: Vector3 = (ahead - behind).normalized()
		var nose: Vector3 = -(Basis(pose["basis"] as Quaternion)).z
		var off: float = rad_to_deg(runs.angle_to(nose))
		if off > worst_facing:
			worst_facing = off
			worst_at = along
	_check("and_they_point_along_the_track_the_whole_way_round",
		worst_facing < 2.0,
		"worst is %.1f degrees out, %.0f m along" % [worst_facing, worst_at])

	# THE DRAWN TRACK AND THE RIDDEN TRACK ARE THE SAME TRACK. They are the same function
	# now, so the test that matters is that the function is continuous where the loop
	# closes -- the last segment runs from the final waypoint back to the first and its
	# length is in no table, so a search over the others cannot reach it. It used to
	# extrapolate off the end of the one before, which put the seam metres out.
	var before: Vector3 = Sim.server.rail_pose(0, total - 1.0, 0.0, 0.0)["position"]
	var after: Vector3 = Sim.server.rail_pose(0, 1.0, 0.0, 0.0)["position"]
	_check("and_the_loop_closes_without_a_seam",
		before.distance_to(after) < 4.0,
		"%.2f m across the join, which is 2 m of track" % before.distance_to(after))

	# LEVEL UNLESS THE WAYPOINTS ASK OTHERWISE. Any lean comes from the bank authored on
	# the track and from nothing else -- never from a frame carried along the curve, which
	# rolls over through a tight bend and takes the train with it.
	var steepest: float = 0.0
	for i in range(48):
		var pose: Dictionary = Sim.server.rail_pose(0, total * float(i) / 48.0, 0.0, 0.0)
		if pose.is_empty():
			continue
		steepest = maxf(steepest,
			rad_to_deg((Basis(pose["basis"] as Quaternion)).y.angle_to(Vector3.UP)))
	_check("and_the_track_leans_only_as_far_as_it_is_banked",
		steepest < rad_to_deg(Terrain.RAIL_MAX_BANK) + 0.5,
		"the steepest lean anywhere is %.2f degrees" % steepest)

	var started: float = float(Sim.server.rail_state(engines[0]).get("distance", 0.0))
	for i in range(600):
		await get_tree().physics_frame
	var moved: float = absf(float(Sim.server.rail_state(engines[0]).get("distance", 0.0))
		- started)
	_check("and_they_run", moved > 40.0,
		"%.0f m along the line in five seconds" % moved)

	# THE BOGIES. A body rides on two of them and hangs between, so it spans the CHORD of a
	# curve -- which means its centre sits INSIDE the arc, not on it. Sampling the middle
	# and pointing along the tangent gives a train made of bananas.
	var straight: Dictionary = Sim.server.rail_pose(0, 400.0, 0.0, 0.0)
	var chorded: Dictionary = Sim.server.rail_pose(0, 400.0, 40.0, 0.0)
	_check("a_bogied_body_spans_the_chord_of_a_curve",
		(straight["position"] as Vector3).distance_to(chorded["position"] as Vector3) > 0.02,
		"a 40 m wheelbase sits %.3f m inside the arc" %
			(straight["position"] as Vector3).distance_to(chorded["position"] as Vector3))
	# Reached the end of this section. See _finish.
	_sections["railway"] = true


## ---- the craft that are not aeroplanes -----------------------------------------------
##
## Three additions that each break an assumption the rest of the game had quietly made: a
## thrust vector that moves, more than one gun, and a seat behind the middle of the craft.
func _test_the_new_craft() -> void:
	# WHAT THIS SECTION MAKES, so it can put it away again. The checks further down count
	# and measure every vehicle in the world -- an airliner left drifting unmanned is an
	# airliner "not drawn flying forwards", and a spare Cessna is one machine too many in
	# the traffic. A test that leaves its props on the stage fails the next scene.
	var props: Array = []
	# A TILTROTOR HOVERS WITH ITS NACELLES UP AND FLIES WITH THEM FORWARD, and it is the
	# same aircraft either way -- one continuous blend and no mode anywhere in the code.
	var up: int = int(Sim.server.spawn_vehicle(Sim.Kind.OSPREY,
		Vector3(6000.0, 400.0, 6000.0), 0.0, Vector3.ZERO))
	props.append(up)
	var along: int = int(Sim.server.spawn_vehicle(Sim.Kind.OSPREY,
		Vector3(6400.0, 400.0, 6000.0), 0.0, Vector3(0.0, 0.0, -80.0)))
	props.append(along)
	_check("a_tiltrotor_exists", up != 0 and along != 0, "entities %d and %d" % [up, along])
	if up == 0 or along == 0:
		return
	# A CLIENT OF ITS OWN, 204, never Sim.local_client_id(). Since lightgun S-1
	# (c7439df4) spawn_pilot for a client who already flies MOVES that client's pilot into
	# the new craft, so this used to take the rig's own pilot into the Osprey and the
	# despawn at the end of the section took it away: the rig was unseated and the cockpit,
	# HUD and smoothness sections all read "not seated". Before S-1 it made an orphan second
	# pilot, which is why it went unnoticed.
	var hover: Dictionary = Sim.server.spawn_pilot(204, Sim.Kind.OSPREY,
		Vector3(6000.0, 400.0, 6000.0), 0.0, Vector3.ZERO)
	_check("and_its_nacelles_are_on_the_command_bus",
		Sim.server.craft_controls(up).has("tilt"),
		"the bus carries %s" % [Sim.server.craft_controls(up).keys()])
	var fitted: Array = Sim.server.craft_schema(Sim.Kind.OSPREY).get("channels", [])
	var nacelles: bool = false
	for channel in fitted:
		if String(channel.get("name", "")) == "nacelles":
			nacelles = true
	_check("and_the_craft_is_fitted_with_them", nacelles,
		"the Osprey's bus has %d channel(s) fitted" % fitted.size())

	# AND IT ANSWERS ITS STICK. Authority is newton-metres per rad/s of error and what it
	# has to move is INERTIA -- eighteen tonnes in a seventeen-metre box -- so a number that
	# flies a light aeroplane leaves this one thinking about it for four seconds.
	# A CLIENT OF ITS OWN, not this one. Spawning a pilot for a client that already has
	# one used to leave them owning two pilot entities; since lightgun S-1 it moves their
	# one pilot into the new craft instead, which here would pull the rig out of its seat.
	# Either way the local client is not a test fixture.
	var crew: Dictionary = Sim.server.spawn_pilot(200, Sim.Kind.OSPREY,
		Vector3(6000.0, 500.0, 6000.0), 0.0, Vector3(0.0, 0.0, -80.0))
	var flier: int = int(crew.get("pilot", 0))
	var craft: int = int(crew.get("vehicle", 0))
	props.append(craft)
	if flier != 0 and craft != 0:
		for axis in ["roll", "pitch", "rudder"]:
			var demand: Dictionary = {"throttle": 0.6}
			demand[axis] = 1.0
			# EVERY FRAME. An input frame is consumed by the tick that reads it, so a
			# demand set once is a demand held for one tick out of forty-eight.
			for i in range(48):
				Sim.server.set_pilot_input(flier, demand)
				await get_tree().physics_frame
			var spin: Vector3 = Sim.server.vehicle_state(craft)["spin"]
			_check("a_tiltrotor_answers_its_%s" % axis, spin.length() > 0.5,
				"%.2f rad/s after four tenths of a second of full %s" % [
					spin.length(), axis])
			for i in range(60):
				Sim.server.set_pilot_input(flier, {"throttle": 0.6})
				await get_tree().physics_frame
		Sim.server.despawn_pilot(flier)

	# AND THE AIRLINER RAISES ITS NOSE. Nine tonnes over twenty-six metres is the same
	# inertia problem as the tiltrotor's, and it had the same answer: five seconds to reach
	# a commanded pitch rate, through which the aeroplane goes wherever it was already
	# going.
	var airline: Dictionary = Sim.server.spawn_pilot(201, Sim.Kind.AIRLINER,
		Vector3(6000.0, 600.0, 6500.0), 0.0, Vector3(0.0, 0.0, -80.0))
	var captain: int = int(airline.get("pilot", 0))
	var jet: int = int(airline.get("vehicle", 0))
	props.append(jet)
	if captain != 0 and jet != 0:
		for i in range(48):
			Sim.server.set_pilot_input(captain, {"throttle": 0.8, "pitch": 1.0})
			await get_tree().physics_frame
		var turning: Vector3 = Sim.server.vehicle_state(jet)["spin"]
		# AGAINST WHAT THE STICK MAY ASK FOR AT THIS SPEED, not a typed 0.35. Since lane/handling (2026-09-17) a full
		# pull is held under the kind's g limit -- 3 g, which at 80 m/s is 0.37 rad/s, not the 1.1 `pitch_rate` alone
		# asks -- and against the fixed 0.35 the airliner read 0.13 and failed for being an airliner. A third of what is
		# asked in four tenths of a second is what the old number was of the old ask (0.35 of 1.1); the bug this guards,
		# an authority that took five seconds to arrive, reads a small fraction of either.
		var hand: Dictionary = Sim.server.handling(Sim.Kind.AIRLINER)
		var speed: float = (Sim.server.vehicle_state(jet)["velocity"] as Vector3).length()
		var asked: float = float(hand["pitch_rate"])
		if float(hand.get("g_limit", 0.0)) > 0.0:
			asked = minf(asked, float(hand["g_limit"]) * 9.81 / maxf(speed, 1.0))
		_check("an_airliner_can_raise_its_nose", turning.length() > 0.3 * asked,
			"%.2f rad/s after four tenths of a second of full back stick, of the %.2f it may ask at %.0f m/s"
				% [turning.length(), asked, speed])
		Sim.server.despawn_pilot(captain)

	# A MENU IS A CONTROL TREE ON A PANEL, and a fingertip on it is a click.
	#
	# The same TouchPanel the cockpit instruments use: there is one menu system, and the
	# fact that a page will be pressed with a finger in a headset is not something the page
	# has to know.
	var panel := TouchPanel.new()
	panel.page = load("res://ui/menus/session_menu.tscn")
	panel.size = Vector2(0.5, 0.4)
	add_child(panel)
	await get_tree().process_frame
	var menu := panel.shown() as SessionMenu
	_check("a_menu_is_an_ordinary_control_tree_on_a_panel", menu != null,
		"the panel is showing %s" % [menu.get_class() if menu != null else "nothing"])
	if menu != null:
		# PRESSED, NOT POINTED AT. A press off the glass is not this panel's business and
		# says so, which is what lets one hand be offered to several panels.
		var heard: Array = []
		menu.chose.connect(func(what, _detail): heard.append(what))
		var buttons: Array = menu.find_children("*", "Button", true, false)
		_check("and_it_has_something_to_press", buttons.size() >= 4,
			"%d button(s)" % buttons.size())
		if not buttons.is_empty():
			var target: Button = buttons[0]
			var middle: Vector2 = target.global_position + target.size * 0.5
			var glass := Vector3(
				(middle.x / float(panel.pixels) - 0.5) * panel.size.x,
				(0.5 - middle.y / float(panel.pixels * panel.size.y / panel.size.x))
					* panel.size.y, 0.0)
			panel.press(glass, true)
			panel.press(glass, false)
			await get_tree().process_frame
			_check("and_pressing_the_glass_presses_the_button",
				not heard.is_empty(),
				"the menu said %s" % [heard if not heard.is_empty() else "nothing"])
		_check("and_it_offers_a_session_over_steam",
			Net.has_method("host_steam"),
			"Net can be asked for one")
	panel.queue_free()

	# THE RUNWAY IS GENERATED FROM ITS OWN LENGTH, which is what makes it lengthenable: the
	# tarmac, the centreline stripes and the threshold bars all come out of one number.
	var strip_marks: Array[Dictionary] = Terrain.runway_marks()
	var painted: float = 0.0
	for mark in strip_marks:
		painted = maxf(painted, (mark["half_extents"] as Vector3).z * 2.0)
	_check("the_runway_is_generated_from_its_length",
		strip_marks.size() > 20 and absf(painted - Terrain.RUNWAY_LENGTH) < 1.0,
		"%d pieces of tarmac and paint over %.0f m" % [strip_marks.size(), painted])

	# AND AN AEROPLANE CAN LEAVE FROM IT. A Cessna put on the threshold and left to itself
	# lines up, opens the throttle and rotates -- which is the runway, the take-off roll and
	# the aircraft's own numbers all having to agree at once.
	var axis: Dictionary = Terrain.runway_axis()
	var trainer: int = int(Sim.server.spawn_ai_vehicle(Sim.Kind.CESSNA,
		(axis["threshold"] as Vector3) + Vector3(0.0, 1.2, 0.0),
		Terrain.RUNWAY_BEARING, Vector3.ZERO))
	props.append(trainer)
	if trainer != 0:
		var got_up: float = 0.0
		# FORTY SECONDS, not twenty. Twenty was set against a Cessna climbing at thirty metres a
		# second with its nose at fifty-five degrees; since 2026-09-14 it climbs at under six
		# degrees (see tests/climb.gd), and from the same standing start it was at 57 m when the
		# twenty were up: an eight-second roll, then about five metres a second.
		# AND FIFTY METRES, NOT NINETY, SINCE THE CESSNA FLIES ITS BOOK (lane/cessnafm): a 2.5 kN propeller rolls it for
		# about twenty seconds, as a real 172's does, and it climbs out at 2.6 m/s, so at forty seconds it was at 80 m.
		# Waiting sixty for ninety was tried, and the extra twenty seconds of island let a car on a slope show up adrift
		# in `and_everything_is_still_in_its_own_medium`, twice.
		for i in range(4800):
			await get_tree().physics_frame
			got_up = (Sim.server.vehicle_state(trainer)["position"] as Vector3).y
			if got_up > 50.0:
				break
		_check("and_a_cessna_can_take_off_from_it", got_up > 50.0,
			"reached %.0f m from a standing start on the threshold" % got_up)

	# AN AEROPLANE CAN LAND ON A MOVING SHIP, which is the whole reason the carrier is here
	# and the reason "the ground" stopped being a height.
	#
	# Put down on the deck at the carrier's own speed, which is what a landing ends as. What
	# is being checked is that it STAYS: on a deck doing twelve metres a second, an aircraft
	# that is not held to it is over the side in a few seconds.
	var fleet: int = 0
	for state in Sim.server.vehicle_states():
		if int(state.get("kind", -1)) == Sim.Kind.CARRIER:
			fleet = int(state["entity"])
			break
	_check("there_is_a_carrier_at_sea", fleet != 0, "entity %d" % fleet)
	if fleet != 0:
		var ship: Dictionary = Sim.server.vehicle_state(fleet)
		var deck: Vector3 = ship["position"]
		var way: Vector3 = ship["velocity"]
		var hull: Vector3 = Sim.server.kind_geometry(Sim.Kind.CARRIER).get("extents",
			Vector3.ONE)
		_check("and_it_is_making_way", way.length() > 4.0,
			"%.0f m/s over the ground" % way.length())
		# ON THE DECK, at the ship's speed, which is what a landing ends as. What is being
		# checked is that it STAYS: on a deck doing eleven metres a second an aircraft that
		# is not held to it is over the side in seconds.
		var landed: int = int(Sim.server.spawn_vehicle(Sim.Kind.CESSNA,
			deck + Vector3(0.0, hull.y + 1.2, 0.0), 0.0, way))
		props.append(landed)
		for i in range(600):
			await get_tree().physics_frame
		var now_at: Vector3 = Sim.server.vehicle_state(landed)["position"]
		var ship_now: Vector3 = Sim.server.vehicle_state(fleet)["position"]
		var adrift: float = Vector2(now_at.x - ship_now.x, now_at.z - ship_now.z).length()
		_check("and_an_aeroplane_put_on_the_deck_stays_on_it",
			adrift < hull.z and now_at.y > ship_now.y + hull.y - 2.0,
			"%.0f m from the ship's middle after five seconds, %.1f m above its deck" % [
				adrift, now_at.y - (ship_now.y + hull.y)])
		_check("and_travelled_with_the_ship",
			deck.distance_to(now_at) > 30.0,
			"the aeroplane covered %.0f m while the ship covered %.0f" % [
				deck.distance_to(now_at), deck.distance_to(ship_now)])
		Sim.server.despawn_vehicle(landed)

	# EVERY HULL FLOATS, which is not something one boat passing proves. Buoyancy was a
	# single constant sized for the 900 kg launch, and the gunboat, the battleship and the
	# carrier all weigh more than it -- so all three sat on the seabed and only the launch
	# ever showed it.
	var sunk: Array = []
	for hull_kind in [Sim.Kind.BOAT, Sim.Kind.GUNBOAT, Sim.Kind.CARRIER,
			Sim.Kind.BATTLESHIP, Sim.Kind.SUBMARINE]:
		var afloat: int = int(Sim.server.spawn_vehicle(hull_kind,
			Vector3(3000.0 + 400.0 * float(hull_kind), Terrain.SEA_LEVEL + 3.0, 9000.0),
			0.0, Vector3.ZERO))
		props.append(afloat)
		for i in range(360):
			await get_tree().physics_frame
		var rides: float = (Sim.server.vehicle_state(afloat)["position"] as Vector3).y
		if rides < Terrain.SEA_LEVEL - 3.0:
			sunk.append("%s at %.0f m" % [Sim.kind_name(hull_kind), rides])
		Sim.server.despawn_vehicle(afloat)
	_check("every_hull_floats_not_just_the_smallest",
		sunk.is_empty(),
		"%s" % ["all five on the surface" if sunk.is_empty() else sunk])

	# A CESSNA AND A CONTROL TOWER: two seats sharing a plunger, and a vehicle that cannot
	# move at all.
	var light: Dictionary = Sim.server.kind_geometry(Sim.Kind.CESSNA)
	_check("a_cessna_has_two_seats_and_no_more",
		(light.get("seat_poses", []) as Array).size() == 2,
		"%d seat(s)" % (light.get("seat_poses", []) as Array).size())
	var strip: VehicleView = _find_kind(_level, Sim.Kind.CESSNA)
	if strip != null:
		_man_fully(strip, [0, 1], -1)
		var plunger := strip.controls_for(0).get("throttle") as VehicleControl
		_check("and_both_of_them_share_one_plunger",
			plunger != null and plunger == strip.controls_for(1).get("throttle")
				and plunger is PlungerThrottle,
			"seat 1 and seat 2 hold the same %s" % [
				plunger.control_name if plunger != null else "nothing"])
		# PUSHED IN FOR POWER, which is backwards from every lever in the game and is what
		# the aeroplane does.
		plunger.value = Vector2(0.0, 1.0)
		var open_at: float = plunger.grip_global().z
		plunger.value = Vector2.ZERO
		_check("and_it_opens_when_pushed_in",
			plunger.grip_global().z > open_at + 0.05,
			"the knob sits %.3f m further out when shut" % [
				plunger.grip_global().z - open_at])

	var tower: int = int(Sim.server.spawn_pilot(203, Sim.Kind.TOWER,
		Vector3(4000.0, 0.0, 4000.0), 0.0, Vector3.ZERO).get("vehicle", 0))
	props.append(tower)
	if tower != 0:
		var began: Vector3 = Sim.server.vehicle_state(tower)["position"]
		for i in range(240):
			await get_tree().physics_frame
		var still: Vector3 = Sim.server.vehicle_state(tower)["position"]
		# A BUILDING DOES NOT MOVE, and a merely very heavy one would sink, drift and
		# eventually fall over. It gets no forces at all and its pose is never read back
		# out of the physics.
		_check("a_control_tower_does_not_move",
			began.distance_to(still) < 0.01,
			"%.3f m in two seconds" % began.distance_to(still))

	# A BOAT SITS ON THE SEA AND LEANS WITH IT. Four probes on the hull, each pushing up by
	# how deep IT is, so pitch and roll fall out of the four disagreeing rather than being
	# a special case anywhere.
	var hull: Dictionary = Sim.server.spawn_pilot(202, Sim.Kind.BOAT,
		Vector3(0.0, Terrain.SEA_LEVEL + 3.0, 7600.0), 0.0, Vector3.ZERO)
	var helm: int = int(hull.get("pilot", 0))
	var launch: int = int(hull.get("vehicle", 0))
	props.append(launch)
	if helm != 0 and launch != 0:
		for i in range(360):
			Sim.server.set_pilot_input(helm, {"throttle": 0.9})
			await get_tree().physics_frame
		var afloat: Dictionary = Sim.server.vehicle_state(launch)
		var at: Vector3 = afloat["position"]
		# ON the water: it found the surface from three metres up and stayed there.
		_check("a_boat_settles_on_the_water",
			absf(at.y - Terrain.SEA_LEVEL) < 1.5,
			"floating at y %.2f, sea level %.2f" % [at.y, Terrain.SEA_LEVEL])
		# AND LEANS. Under way across a swell it is never quite level, and a hull that is
		# always exactly level is a hull with one buoyancy force at its middle.
		var lean: float = rad_to_deg(
			(Basis(afloat["basis"] as Quaternion)).y.angle_to(Vector3.UP))
		_check("and_leans_with_the_swell_under_way",
			lean > 0.2 and lean < 25.0,
			"%.1f degrees off level at %.0f m/s" % [lean,
				(afloat["velocity"] as Vector3).length()])
		Sim.server.despawn_pilot(helm)

	# A TANDEM-ROTOR HELICOPTER, and the seat that is the whole reason for it.
	var lift: int = int(Sim.server.spawn_vehicle(Sim.Kind.CHINOOK,
		Vector3(6800.0, 40.0, 6000.0), 0.0, Vector3.ZERO))
	props.append(lift)
	_check("a_tandem_rotor_helicopter_exists", lift != 0, "entity %d" % lift)
	var deck: Dictionary = Sim.server.kind_geometry(Sim.Kind.CHINOOK)
	var ramp: Dictionary = {}
	for entry in (deck.get("seat_poses", []) as Array):
		if (entry.get("position", Vector3.ZERO) as Vector3).z > 0.0:
			ramp = entry
	# BEHIND the middle of the aircraft and TURNED ROUND, which nothing else in the game
	# has: the point of sitting on a Chinook's ramp is watching where you have been.
	_check("and_it_has_a_seat_on_the_ramp",
		not ramp.is_empty() and absf(float(ramp.get("yaw", 0.0)) - PI) < 0.01,
		"a seat at z %.1f facing %.0f degrees" % [
			(ramp.get("position", Vector3.ZERO) as Vector3).z,
			rad_to_deg(float(ramp.get("yaw", 0.0)))])

	# TWO GUNS, AIMED SEPARATELY. One mount per gunner: two people at two guns are looking
	# at two different things, and a shared mount would have them fighting over it every
	# tick with nothing sensible to average.
	# AT the sea's level: a gunboat's origin is its design waterline, where it floats.
	var patrol: int = int(Sim.server.spawn_vehicle(Sim.Kind.GUNBOAT,
		Vector3(7200.0, Terrain.SEA_LEVEL, 6000.0), 0.0, Vector3.ZERO))
	props.append(patrol)
	_check("a_gunboat_exists", patrol != 0, "entity %d" % patrol)
	if patrol == 0:
		return
	var stations: int = 0
	var driver: bool = false
	for entry in (Sim.server.kind_geometry(Sim.Kind.GUNBOAT).get("seat_poses", []) as Array):
		if String(entry.get("station", "")) == "turret":
			stations += 1
		if String(entry.get("station", "")) == "pilot":
			driver = true
	_check("and_it_has_two_gun_seats_and_a_driver",
		stations == 2 and driver,
		"%d turret station(s), driver %s" % [stations, driver])
	_check("and_a_mount_for_each_of_them",
		(Sim.server.craft_systems(patrol).get("turrets", []) as Array).size() >= 2,
		"%d mount(s) on the wire" % (Sim.server.craft_systems(patrol).get("turrets",
			[]) as Array).size())
	if not hover.is_empty():
		Sim.server.despawn_pilot(int(hover.get("pilot", 0)))
	for prop in props:
		if int(prop) != 0:
			Sim.server.despawn_vehicle(int(prop))
	# FOUR TICKS, because a despawn is not instant and cannot be. Removing a vehicle takes
	# the Replicated component off it on one tick, destroys the entity on the next -- doing
	# both at once loses the removal, since a dead entity has nothing left to report -- and
	# the client hears about it on the one after that. Waiting a single frame and then
	# counting what is left counts the thing that is on its way out.
	for _gone in range(4):
		await get_tree().physics_frame

	# Reached the end of this section. See _finish.
	_sections["new_craft"] = true


## ---- there are controls in front of every seat ---------------------------------------
## MAN A FLIGHT'S CRAFT WHOLE, in this call, for a check about what a station IS rather than when it is built. A flight
## builds a manned craft's stations over frames within `VehicleView.station_build_budget_ms` (lane/ashiato-latest,
## 2026-09-19), so one call may build only the first seat -- and waiting frames does not help here, because the level
## mans every craft each frame with who is really aboard, and nobody is, which takes them down again. So the budget is
## lifted for this one call and put back; `tests/station_budget.gd` holds what the budget does.
func _man_fully(view: VehicleView, crew: Array, mine: int) -> void:
	var budget: float = view.station_build_budget_ms
	view.station_build_budget_ms = 0.0
	view.man(crew, mine)
	view.station_build_budget_ms = budget


func _test_the_cockpit(rig: PilotRig) -> void:
	var view: VehicleView = rig.vehicle_view()
	if view == null:
		_check("the_cockpit_exists", false, "not seated")
		return
	# ONLY THE OCCUPIED SEATS HAVE CONTROLS. A hundred and forty machines with four seats
	# each is five hundred and sixty sets of them, of which at most a handful are ever in
	# front of anybody; the rest used to be built at startup and drawn for ever.
	_check("only_an_occupied_seat_has_controls",
		view.manned_seats().size() >= 1
			and view.manned_seats().size() < view.seats.size() + 1,
		"%d station(s) in a craft with %d seats" % [view.manned_seats().size(),
			view.seats.size()])
	var mine: Dictionary = view.controls_for(rig.seat_index())
	_check("the_seat_i_am_in_has_a_throttle_a_stick_and_a_button",
		mine.has("throttle") and mine.has("stick") and mine.has("button"),
		"seat %d: %s" % [rig.seat_index(), mine.keys()])
	if mine.is_empty():
		return
	var stick := mine["stick"] as FlightStick
	# WITHIN REACH, MEASURED TO THE GRIP, from where the head actually is.
	#
	# Two separate things put the first version of these out of reach and both are caught
	# here. A seat anchor is the play space FLOOR and not the seat pan, so a control at half
	# a metre sits around a seated pilot's shins. And the part you HOLD is not the origin,
	# so a stick whose base is at hand height has its grip 22 cm above your hand.
	#
	# Every one of them, in the seat's own frame, against a head at eye height.
	var head := Vector3(0.0, PilotRig.EYE_HEIGHT, 0.0)
	var seat: Node3D = view.seat_anchor(rig.seat_index())
	var furthest: float = 0.0
	var lowest: float = 99.0
	var named: String = ""
	for key in ["throttle", "stick", "button"]:
		var grip: Vector3 = seat.to_local((mine[key] as VehicleControl).grip_global())
		if grip.distance_to(head) > furthest:
			furthest = grip.distance_to(head)
			named = str(key)
		lowest = minf(lowest, head.y - grip.y)
	# THE STATION SCENES BAKE THEIR HEIGHTS IN METRES, so `EYE_HEIGHT` is only half a knob.
	#
	# A cockpit is authored at `hands()`, which is the eye height minus a fixed gap -- but
	# the number lives in eight .tscn files rather than being read from it, so raising the
	# head raises nothing else and the pilot is left reaching further down for the same
	# controls. Three checks below go red when that happens and none of them says why, so
	# this one does, with the correction to apply.
	var reach_from_the_grip: float = seat.to_local(stick.grip_global()).y
	_check("the_deck_is_authored_at_the_current_hand_height",
		absf(reach_from_the_grip - CockpitStation.hands()) < 0.08,
		"the stick grip is %.2f m up and the hands are at %.2f: shift every node in objects/seats/seat_*.tscn by %+.2f m in Y" % [reach_from_the_grip,
			CockpitStation.hands(), CockpitStation.hands() - reach_from_the_grip])
	_check("every_control_is_within_a_seated_arms_reach",
		furthest < 0.75,
		"the furthest is the %s at %.2f m from the head" % [named, furthest])
	# BELOW THE EYES AND ABOVE THE LAP, and both halves are load-bearing. Above the eyeline
	# and the console under them takes the windscreen; down at 34 cm and you fly looking
	# down and reaching out, which is where they started.
	_check("and_at_chest_height_rather_than_in_the_lap",
		lowest > 0.0 and lowest < 0.50,
		"the lowest sits %.2f m below the eyes" % lowest)
	# WHICH WAY IS THE FRONT. A vehicle is a box, and a box has no front: the nose marker
	# is the only thing on the hull that says which end is which, and it was a fixed lump
	# whatever it was stuck on -- a clear beak on the 1.5 m light aeroplane and a pimple on
	# the 3.8 m airliner, which is why one of them read as pointing nowhere.
	#
	# Checked on the airliner, in the vehicle's own frame, where -Z is forward. Since 2026-09-19 (lane/liners) it is a
	# 737-800 drawn whole by `Boeing737Airframe`, whose nose is the fuselage's own tip and whose tail is its fin: asked
	# for by the airframe's part names, as the fidelity pass before it was, and read from DRAWN vertices, because a node's
	# origin says nothing about where its mesh is.
	var big: VehicleView = _find_kind(_level, Sim.Kind.AIRLINER)
	if big != null:
		var frame := big.find_child("Boeing737", true, false) as JetlinerAirframe
		var body := frame.find_child("Fuselage", true, false) as MeshInstance3D if frame != null else null
		var stern := frame.find_child("Fin", true, false) as MeshInstance3D if frame != null else null
		_check("an_aeroplane_has_a_nose_and_a_tail", body != null and stern != null,
			"airframe %s, fuselage %s, fin %s" % [frame != null, body != null, stern != null])
		if body != null and stern != null:
			var half: Vector3 = frame.geometry()["extents"]
			var nose: float = INF
			for p in body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				nose = minf(nose, big.to_local(body.global_transform * (p as Vector3)).z)
			var tail: float = -INF
			for p in stern.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				tail = maxf(tail, big.to_local(stern.global_transform * (p as Vector3)).z)
			# EACH ON ITS OWN END: the nose tip at the box's front face, the fin's trailing edge in its last tenth.
			_check("and_each_is_on_its_own_end",
				absf(nose + half.z) < 0.05 and tail > half.z * 0.8,
				"nose at z %.2f, fin's trailing edge at z %.2f, on an airframe box of +/- %.2f" % [nose, tail, half.z])

	# THE AIRLINER'S SHARED THROTTLE, which is the one control here that hangs off the
	# VEHICLE rather than off a seat -- so it is the one that can be put at hand height in
	# the wrong frame and end up a third of a metre above everybody's hands. Both front
	# seats have to be able to reach it, which is also why they sit 0.84 m apart.
	var deck: VehicleView = _find_kind(_level, Sim.Kind.AIRLINER)
	if deck != null:
		_man_fully(deck, [0, 1], -1)
		var quadrant := deck.controls_for(0)["throttle"] as VehicleControl
		var shared: bool = quadrant == (deck.controls_for(1)["throttle"] as VehicleControl)
		var worst: float = 0.0
		for who in [0, 1]:
			var pan: Node3D = deck.seat_anchor(who)
			worst = maxf(worst, pan.to_local(quadrant.grip_global())
				.distance_to(Vector3(0.0, PilotRig.EYE_HEIGHT, 0.0)))
		_check("the_airliners_two_pilots_share_one_throttle", shared,
			"both seats hold the same lever: %s" % quadrant.name)
		_check("and_both_of_them_can_reach_it", worst < 0.8,
			"the further of the two is %.2f m from it" % worst)

	# PULL BACK AND IT COMES BACK. The sign that reaches the aeroplane and the direction
	# the control visibly moves are two different pieces of arithmetic, and they were
	# opposite: the nose went up while the stick in front of the pilot pushed forward.
	#
	# Measured in the SEAT's frame, where -Z is forward and the pilot is at the origin.
	stick.value = Vector2.ZERO
	var centred: float = seat.to_local(stick.grip_global()).z
	stick.value = Vector2(0.0, 1.0)
	var pulled: float = seat.to_local(stick.grip_global()).z
	stick.value = Vector2(0.0, -1.0)
	var pushed: float = seat.to_local(stick.grip_global()).z
	stick.value = Vector2.ZERO
	_check("nose_up_brings_the_stick_back_toward_the_pilot",
		pulled > centred + 0.02 and pushed < centred - 0.02,
		"full nose-up sits %.3f m back of centre, full nose-down %.3f m" % [
			pulled - centred, pushed - centred])

	# ---- THE CENTRE CONSOLE ----------------------------------------------------------
	#
	# What belongs to the AIRCRAFT rather than to a seat: the flap con_gate and the gear lever,
	# within reach of both front seats and owned by neither. Either pilot calls for flaps.
	#
	# On a craft FITTED with those channels and not on one that is not: a lever for a
	# channel the aeroplane does not carry is a dead handle, which is worse than no handle.
	var con_plane: VehicleView = _other_craft_of(view, Sim.Kind.PLANE)
	if con_plane != null:
		_man_fully(con_plane, [0], -1)
		var con_set: Dictionary = con_plane.controls_for(0)
		var con_gate := con_set.get("flaps") as FlapsLever
		var con_gear := con_set.get("gear") as GearLever
		_check("a_craft_with_flaps_and_gear_has_a_console_for_them",
			con_gate != null and con_gear != null,
			"the aeroplane's console carries %s" % [con_set.keys()])
		if con_gate != null and con_gear != null:
			# THE SAME NODE FOR EVERY SEAT. A console control both pilots can work is one
			# handle, not one each: two would be two positions for one flap setting.
			var con_other := con_plane.controls_for(1)
			_check("and_both_front_seats_get_the_same_handle",
				con_other.get("flaps") == con_gate and con_other.get("gear") == con_gear,
				"seat 1 reaches the same gate and the same gear lever")
			# THE GATE HAS THE NOTCHES THE CRAFT SAYS IT HAS. Four on this aeroplane --
			# craft_schema fits flaps with a range of 3 -- and a lever showing any other
			# number is a lever reached for in the wrong place on an approach.
			var con_notches: int = 0
			for con_entry in (Sim.client.craft_schema(Sim.Kind.PLANE).get("channels", [])
					as Array):
				if int((con_entry as Dictionary).get("channel", -1)) == Sim.Channel.FLAPS:
					con_notches = int((con_entry as Dictionary).get("range", 0))
			_check("and_the_gate_has_the_notches_the_craft_is_fitted_with",
				con_gate.channel_range == con_notches and con_notches > 1,
				"%d notches on a gate the craft fits with %d" % [con_gate.channel_range,
					con_notches])
			# AND THEY SIT ON THE BUS, which is what makes them a configuration rather than
			# a demand: they stay where they are put and the physics reads them.
			_check("and_the_console_works_the_bus",
				con_gate.channel == Sim.Channel.FLAPS and con_gear.channel == Sim.Channel.GEAR,
				"flaps on channel %d, gear on channel %d" % [con_gate.channel, con_gear.channel])
			# THE GATE SETTLES ON A NOTCH. Dragged to seven tenths it takes the nearest
			# detent, because the simulation divides the command by the range and there is
			# con_none between two notches for the aeroplane to hold.
			con_gate.value = Vector2(0.0, 0.7)
			con_gate._settle(Vector2(0.0, 0.7))
			var con_landed: float = float(con_gate.notch()) / float(con_gate.channel_range)
			_check("and_a_dragged_gate_settles_on_a_notch",
				absf(con_landed - 0.667) < 0.01,
				"seven tenths settles on notch %d of %d" % [con_gate.notch(),
					con_gate.channel_range])
			# THE GEAR SNAPS. There is one bit on the wire and the flight model reads it as
			# a drag term that is either there or not, so a handle resting halfway would be
			# promising a position the aeroplane cannot hold.
			con_gear._value_at_grab = Vector2.ZERO
			con_gear._grabbed_at = Vector3.ZERO
			con_gear._drag(Vector3(0.0, -GearLever.TRAVEL * 0.6, 0.0))
			_check("and_the_gear_snaps_to_one_end_or_the_other",
				con_gear.is_down() and con_gear.command_value() == 1,
				"dragged past halfway it selects down, and sends %d"
					% con_gear.command_value())
		# A POD HAS NEITHER, and gets no console at all.
		var con_bare: VehicleView = _other_craft_of(view, Sim.Kind.POD)
		if con_bare != null:
			con_bare.man([0], -1)
			var con_none: Dictionary = con_bare.controls_for(0)
			_check("and_a_craft_fitted_with_neither_gets_no_handles_for_them",
				not con_none.has("flaps") and not con_none.has("gear"),
				"the pod's set is %s" % [con_none.keys()])

	# THE COLLECTIVE. A helicopter's lever is not a throttle: it hinges beside the seat and
	# is pulled UP, which is the hand movement the machine is actually flown with.
	var chopper: VehicleView = _find_kind(_level, Sim.Kind.HELI)
	if chopper != null:
		# MANNED ON PURPOSE. A craft with nobody in it has no controls at all now, so a
		# test that wants to look at some has to put somebody in the seat first -- which is
		# itself the thing worth checking.
		chopper.man([0], -1)
		var collective := chopper.controls_for(0)["throttle"] as CollectiveLever
		var pan: Node3D = chopper.seat_anchor(0)
		collective.value = Vector2.ZERO
		var down: Vector3 = pan.to_local(collective.grip_global())
		collective.value = Vector2(0.0, 1.0)
		var up: Vector3 = pan.to_local(collective.grip_global())
		collective.value = Vector2.ZERO
		_check("a_helicopter_is_flown_with_a_collective",
			collective != null and collective.throttle() == 0.0,
			"seat 0 has a %s" % collective.control_name)
		_check("and_raising_it_lifts_the_grip_rather_than_sliding_it",
			up.y - down.y > 0.1 and absf(up.z - down.z) < (up.y - down.y),
			"full up is %.3f m higher and %.3f m along" % [up.y - down.y,
				absf(up.z - down.z)])
		# AND IT IS REACHABLE THROUGHOUT ITS TRAVEL, which a lever that swings 19 cm is
		# not automatically: the seat the rig happens to start in is the only one the reach
		# check above ever sees.
		var eyes := Vector3(0.0, PilotRig.EYE_HEIGHT, 0.0)
		_check("and_the_whole_of_its_travel_is_in_reach",
			down.distance_to(eyes) < 0.75 and up.distance_to(eyes) < 0.75,
			"fully down is %.2f m away, fully up %.2f m" % [down.distance_to(eyes),
				up.distance_to(eyes)])

	# UNDER THE SEAT ANCHOR, which is what makes a grab at 300 kph the same arithmetic as a
	# grab on the ground: the hand and the control are in the same frame, so the aircraft's
	# motion is not a term in the subtraction. An ANCESTOR and not a parent -- a control
	# hangs off the station scene now, and the station hangs off the seat.
	_check("they_ride_in_the_seats_own_frame",
		view.seat_anchor(rig.seat_index()).is_ancestor_of(stick),
		"the stick hangs off %s, under %s" % [stick.get_parent().name,
			view.seat_anchor(rig.seat_index()).name])
	# REACHABLE: every control in the craft, and none in any other.
	#
	# This used to be the opposite check -- that a control belonged to one seat and only its
	# occupant could move it. Two people in one cockpit reach across it, to each other's
	# levers and to whatever sits between them, so ownership by seat is gone and what
	# replaces it is distance. The fuselage is no longer what keeps a hand out of somebody
	# else's aeroplane; the reachable list being built from THIS craft is.
	var hands_reach: Array = rig._reachable
	_check("every_control_in_my_own_craft_is_within_reach",
		stick in hands_reach and hands_reach.size() >= view.manned_seats().size(),
		"%d control(s) reachable across %d manned seat(s)" % [hands_reach.size(),
			view.manned_seats().size()])
	var foreign_reach: Array = []
	for far_craft in _level.find_children("*", "VehicleView", true, false):
		if far_craft == view:
			continue
		for far_control in (far_craft as VehicleView).find_children(
				"*", "VehicleControl", true, false):
			if far_control in hands_reach:
				foreign_reach.append(far_control)
	_check("and_no_control_in_anybody_elses",
		foreign_reach.is_empty(),
		"%s" % ["nothing from another craft" if foreign_reach.is_empty()
			else foreign_reach])

	# NO TWO THINGS A HAND CAN REACH ARE WITHIN ONE HAND OF EACH OTHER.
	#
	# The check below this section measures the STATIONS, instantiated at every seat pose.
	# That was the whole of it while a control belonged to a seat, because nothing else was
	# grabbable. It is not any more: the centre console is reachable from both front seats
	# and is not in any station, so it has to be measured against them and against itself.
	#
	# And this is now CORRECTNESS rather than tidiness. With ownership gone, spacing is the
	# only thing between a hand reaching for the flap gate and the gear lever beside it.
	var too_close: Array = []
	for a in range(hands_reach.size()):
		for b in range(a + 1, hands_reach.size()):
			var one := hands_reach[a] as VehicleControl
			var two := hands_reach[b] as VehicleControl
			var apart_by: float = one.grip_global().distance_to(two.grip_global())
			if apart_by < VehicleControl.REACH * 2.0:
				too_close.append("%s and %s %.2f m" % [one.name, two.name, apart_by])
	_check("nothing_a_hand_can_reach_is_within_one_hand_of_anything_else",
		too_close.is_empty(),
		"%s" % ["all %d clear" % hands_reach.size() if too_close.is_empty()
			else too_close.slice(0, 4)])

	# AND A HAND ON ANOTHER SEAT'S LEVER IS THE LEVER THIS PLAYER IS SENDING. Without this
	# the reach is decorative: the lever moves under the hand and the wire puts it straight
	# back, because the frame was still being read from the four in front of this seat.
	var their_lever: VehicleControl = null
	for far_seat in view.manned_seats():
		var seat_lever := view.controls_for(int(far_seat)).get("throttle") as VehicleControl
		if seat_lever != null and seat_lever != rig._my_throttle:
			their_lever = seat_lever
			break
	if their_lever != null:
		their_lever.value = Vector2(0.0, 0.77)
		their_lever.held_by = 0
		var sent: float = float(rig.read_controls().get("throttle", 0.0))
		their_lever.held_by = -1
		_check("a_hand_on_another_seats_lever_is_the_one_it_sends",
			absf(sent - 0.77) < 0.02, "reaching across sends %.2f" % sent)

	# A HAND ON THE STICK MOVES THE AEROPLANE. Offered in the control's own space, which is
	# what makes this the same arithmetic at 300 kph as on the ground.
	# ON THE GRIP, which is 22 cm up the shaft. Reaching for the base is reaching for the
	# part of a control column nobody holds, and it is correctly refused.
	var grip: Vector3 = Vector3(0.0, 0.22, 0.0)
	stick.offer_hand(1, Vector3.ZERO, 1.0)
	_check("the_base_of_the_stick_is_not_where_you_hold_it", not stick.is_held(),
		"a hand at the boot got nothing")
	stick.offer_hand(1, grip, 1.0)
	_check("a_gripped_hand_takes_hold_of_the_stick", stick.is_held(),
		"held by hand %d" % stick.held_by)
	stick.offer_hand(1, grip + Vector3(FlightStick.THROW * 0.5, 0.0, 0.0), 1.0)
	_check("and_moving_it_becomes_roll", stick.roll() > 0.35,
		"roll %.2f from half a throw to the right" % stick.roll())
	stick.offer_hand(1, grip + Vector3(0.0, 0.0, -FlightStick.THROW * 0.5), 1.0)
	_check("and_pushing_it_forward_becomes_nose_down", stick.pitch() < -0.35,
		"pitch %.2f from half a throw forward" % stick.pitch())
	# WHAT THE HAND DID BEATS WHAT THE THUMBSTICK SAID, or a resting thumb averages it away.
	var frame: Dictionary = rig.read_controls()
	_check("and_the_control_frame_carries_it",
		absf(float(frame["pitch"]) - stick.pitch()) < 0.01,
		"the frame says pitch %.2f" % float(frame["pitch"]))
	# TWISTING IT IS RUDDER. A wrist rolled about the shaft, not about anything fixed: the
	# axis leans with the column, so holding the stick hard over and rolling the wrist is
	# still rudder rather than a mixture of the two.
	# Clockwise seen from above, which is a NEGATIVE rotation about up, and is right rudder.
	var wrist := Basis(Vector3.UP, -0.4)
	stick.offer_hand(1, grip, 1.0, wrist)
	_check("twisting_the_grip_clockwise_is_right_rudder", stick.rudder() > 0.5,
		"%.2f of rudder from 23 degrees of wrist" % stick.rudder())
	var turned: float = stick.rudder()
	stick.offer_hand(1, grip + Vector3(FlightStick.THROW * 0.5, 0.0, 0.0), 1.0, wrist)
	_check("and_moving_the_stick_at_the_same_time_does_not_change_it",
		absf(stick.rudder() - turned) < 0.05 and stick.roll() > 0.35,
		"rudder %.2f with %.2f of roll on it too" % [stick.rudder(), stick.roll()])
	var frame_now: Dictionary = rig.read_controls()
	_check("and_the_control_frame_carries_the_rudder_too",
		absf(float(frame_now["rudder"]) - stick.rudder()) < 0.01,
		"the frame says rudder %.2f" % float(frame_now["rudder"]))

	# THE DRAWN MODEL CAN BE TURNED ROUND WITHOUT TOUCHING THE SIMULATION, which is what
	# `Body` is for: every drawn part hangs off it and the SEATS do not, so a kind that
	# wants its model the other way round gets it and the pilot still sits where the
	# simulation put them, facing the way the craft actually goes.
	# EVERY CRAFT IS DRAWN FLYING FORWARDS, at load, as the CLIENT draws it.
	#
	# This is the property that matters and the one that was being argued about: the nose
	# you can see, in the node tree that is actually rendered, against the velocity the
	# thing is actually travelling at. Not the server's copy -- entity ids are per world, so
	# comparing the two is comparing different vehicles, which is how an earlier probe
	# managed to report 175 degrees of error that was not there.
	var crabbing: Array = []
	for entity in Sim.current:
		var here: Dictionary = Sim.current[entity]
		# A WING ONLY. A helicopter goes where its disc is tilted and can point anywhere
		# while doing it, a boat crabs, and a tiltrotor in the hover does both -- measured,
		# 90 degrees off and entirely correct. An aeroplane's flight path follows its nose
		# to within a fraction of a degree, which took some doing, so it is the one thing
		# here that CAN be held to this.
		var winged: int = int(here.get("kind", -1))
		if winged != Sim.Kind.PLANE and winged != Sim.Kind.AIRLINER:
			continue
		var motion: Vector3 = here.get("velocity", Vector3.ZERO)
		if motion.length() < 5.0:
			continue
		# AND ACTUALLY FLYING. A spare aeroplane that nobody has taken glides down and
		# settles within a minute of the world starting -- that is deliberate, and it is
		# what `launch_if_grounded` exists to undo when somebody finally climbs into one.
		# A wreck sliding across a field pointing whichever way it stopped is not a
		# question about how the model is drawn, and it was the only thing failing here.
		if (here.get("position", Vector3.ZERO) as Vector3).y < 60.0:
			continue
		var drawn: VehicleView = _level.call("view_of", int(entity)) as VehicleView
		if drawn == null:
			continue
		# THE DRAWN NOSE: -Z of the body node, which is what a catalogue `facing` turns,
		# put back into world space. Reading the vehicle's own -Z would test the simulation
		# and miss the model entirely.
		var body: Node3D = drawn.get_node("Body")
		var nose: Vector3 = -body.global_transform.basis.z
		var off: float = rad_to_deg(nose.angle_to(motion.normalized()))
		if off > 25.0:
			crabbing.append("%s %.0f deg at %s doing %.0f m/s" % [
				Sim.kind_name(int(here.get("kind", -1))), off,
				here.get("position", Vector3.ZERO), motion.length()])
	_check("every_craft_is_drawn_flying_forwards",
		crabbing.is_empty(),
		"%s" % ["all of them" if crabbing.is_empty() else crabbing])

	# A BOX ROUND ANYTHING TOO FAR OFF TO SEE, and none round anything you can.
	#
	# The whole difficulty with finding an aeroplane is that at four kilometres it is three
	# pixels of grey on a grey sky, so the marker cannot be the craft's own size -- it holds
	# an ANGLE instead and grows with range. Both halves are checked here, because a box
	# that is always on is as useless as no box at all.
	var far_off: VehicleView = null
	var eye_at: Vector3 = rig.eye_position()
	for entity in Sim.current:
		var seen: VehicleView = _level.call("view_of", int(entity)) as VehicleView
		if seen != null and seen.global_position.distance_to(eye_at) > 2000.0:
			far_off = seen
			break
	if far_off != null:
		far_off.spot(eye_at, true)
		var marker: MeshInstance3D = far_off.get_node_or_null("SpottingBox")
		_check("a_distant_craft_can_be_boxed_to_find_it",
			marker != null and marker.visible,
			"the marker on a craft %.0f m off is %s" % [
				far_off.global_position.distance_to(eye_at),
				"drawn" if marker != null and marker.visible else "missing"])
		if marker != null:
			# Sized to the RANGE, not to the aeroplane: the box a kilometre away is
			# bigger in metres and the same size in your eye.
			_check("and_the_box_holds_its_size_in_your_eye",
				absf(marker.global_basis.get_scale().x
					/ far_off.global_position.distance_to(eye_at)
					- VehicleView.SPOT_ANGLE) < 0.001,
				"%.1f m across at %.0f m" % [marker.global_basis.get_scale().x,
					far_off.global_position.distance_to(eye_at)])
		far_off.spot(eye_at, false)
		_check("and_goes_away_when_it_is_turned_off",
			marker == null or not marker.visible,
			"the marker is %s" % ["gone" if marker == null or not marker.visible
				else "still drawn"])
	_check("and_nothing_is_boxed_up_close",
		view.get_node_or_null("SpottingBox") == null
			or not (view.get_node("SpottingBox") as MeshInstance3D).visible,
		"the craft I am sitting in is not boxed")

	# THE AIRFRAME GHOSTS FOR WHOEVER IS INSIDE IT. A pilot sits within the hull, and from
	# in there a solid fuselage is a wall between the eye and the horizon, between the eye
	# and the controls, and an interior whose only visible feature is the big end behind
	# you -- which is why an aeroplane pointing exactly along its own velocity can still
	# feel as though it is flying backwards.
	# HIDDEN, NOT FADED. Drawn at 18% alpha it read well and flickered: thirty overlapping
	# boxes, alpha-blended, sorted per object with no depth between them, most of them at
	# nearly the same distance from an eye that is INSIDE the hull -- so the order changed
	# from frame to frame and differed between the two eyes. Zero alpha does not fix that,
	# because a transparent surface at zero is still submitted and still sorted. Only
	# `visible` takes it out of the frame.
	var hull := view.get_node("Body/Hull") as MeshInstance3D
	var glazed: bool = not VehicleCatalogue.glazing(view.kind).is_empty()
	_check("a_solid_airframe_is_taken_away_from_inside_it",
		glazed or (hull != null and not hull.visible),
		"the %s I am in is %s" % [Sim.kind_name(view.kind),
			"glazed, so kept" if glazed else
			("gone" if hull != null and not hull.visible else "still drawn")])

	# AND A GLAZED ONE IS KEPT, which is what the windows were cut for. Checked on a craft
	# built for the purpose rather than on whatever the rig happens to be sitting in.
	#
	# WHAT IS KEPT CHANGED ON 2026-09-19, and the check had to change with it rather than move to
	# another craft. `lane/twin310` drew this kind as a Cessna 310R through the package's `visual`
	# boundary, and a craft with a visual scene has EVERY `Body` mesh hidden, generic skin and all
	# -- so the twin's 18 generic panels are still built and then taken out of the frame, and this
	# check went red saying "hidden from the seat". The guarantee is unchanged: **a glazed craft is
	# not taken away from the person sitting in it.** What carries it now is the craft's own
	# airframe, which `_show_body` keeps because `VehicleCatalogue.glazing(kind)` is not empty.
	# Both halves are asserted, because "the skin is hidden" on its own would also be true of a
	# craft that had been hidden by mistake.
	var winged := (load("res://objects/vehicles/craft_plane.tscn") as PackedScene) \
		.instantiate() as VehicleView
	add_child(winged)
	winged._show_in_editor()
	winged.man([0], 0)
	var skin := winged.get_node_or_null("Body/Hull") as MeshInstance3D
	var drawn := winged.get_node_or_null("VisualScene") as Node3D
	_check("and_one_with_windows_in_it_is_kept",
		not VehicleCatalogue.glazing(winged.kind).is_empty() and drawn != null and drawn.visible
			and skin != null and not skin.visible and not winged.hull_panels().is_empty(),
		"the 310R's own airframe is %s from the seat and its %d generic panels are %s" % [
			"drawn" if drawn != null and drawn.visible else "hidden",
			winged.hull_panels().size(),
			"drawn" if skin != null and skin.visible else "hidden"])
	winged.queue_free()
	var other: VehicleView = _find_kind(_level, Sim.Kind.CAR)
	if other != null:
		var elsewhere := other.get_node("Body/Hull") as MeshInstance3D
		var painted := elsewhere.material_override as StandardMaterial3D
		_check("and_solid_on_everybody_elses",
			elsewhere.visible and (painted == null or painted.albedo_color.a > 0.9),
			"a craft nobody is in is %s and %.0f%% opaque" % [
				"drawn" if elsewhere.visible else "hidden",
				(painted.albedo_color.a if painted != null else 1.0) * 100.0])

	# EVERY CRAFT CAN BE OPENED AND LOOKED AT, with no world running.
	#
	# A vehicle scene is worth looking at for the things a running game hides: whether a
	# seat is inside its own fuselage, whether the ramp seat clears the ramp, whether a gun
	# is over the gunner. The sizes come from the SIMULATION's shape table -- a throwaway
	# CockpitWorld, which builds it in its constructor -- so there is no second copy in
	# GDScript to drift out of step with the thing you collide with.
	var unbuilt: Array = []
	var cessna_missing: Array[String] = []
	for kind in range(Sim.Kind.size()):
		var path: String = "res://objects/vehicles/craft_%s.tscn" % Sim.kind_name(kind)
		# ASKED FOR, NOT LOADED, so a kind with no scene is a question rather than an engine error:
		# `load()` on a missing file prints ERROR, and the runner fails a suite that prints one
		# whatever its own checks said (2026-09-15).
		var there: bool = ResourceLoader.exists(path)
		# A KIND THAT IS NOT DRAWN HAS NO SCENE, AND MUST NOT HAVE ONE. The segway is the invisible
		# vehicle a player stands on (agents.md, "A SEGWAY IS HOW A PLAYER WALKS"); there is nothing
		# to preview, and the running game builds its view from the kind rather than from a file
		# (`FlightLevel._view_for`). The rule is held BOTH ways so it cannot rot: an undrawn kind
		# with a scene is as much a mistake as a drawn one without.
		if not VehicleCatalogue.is_drawn(kind):
			if there:
				unbuilt.append("%s: is not drawn but has a craft scene" % Sim.kind_name(kind))
			continue
		if not there:
			unbuilt.append("%s: no scene" % Sim.kind_name(kind))
			continue
		var scene := load(path) as PackedScene
		if scene == null:
			unbuilt.append("%s: scene would not load" % Sim.kind_name(kind))
			continue
		var craft := scene.instantiate() as VehicleView
		add_child(craft)
		craft._show_in_editor()
		var solid: int = craft.find_children("*", "MeshInstance3D", true, false).size()
		if craft.seats.is_empty() or craft.stations().size() != craft.seats.size() \
				or solid < 20:
			unbuilt.append("%s: %d seats, %d stations, %d meshes" % [
				Sim.kind_name(kind), craft.seats.size(), craft.stations().size(), solid])
		# The Cessna is deliberately more specific than the generic trainer: a tapered high
		# wing, bracing, cowling, propeller and fixed tricycle gear are the external features
		# that make its gallery and station screenshots meaningful during cockpit iteration.
		# They are its package's SkyhawkAirframe now, measured part by part in tests/skyhawk.gd.
		if kind == Sim.Kind.CESSNA:
			for part in ["Airframe", "Propeller", "StrutPort", "StrutStarboard", "Gear", "FlapPort", "AileronStarboard",
					"Rudder"]:
				if craft.get_node_or_null("VisualScene/Exterior/%s" % part) == null:
					cessna_missing.append(part)
		craft.queue_free()
	_check("every_craft_can_be_opened_in_the_editor",
		unbuilt.is_empty(),
		"%s" % ["all %d build a hull, a cockpit and every seat" % Sim.Kind.size() if unbuilt.is_empty()
			else unbuilt])
	_check("the_cessna_has_its_high_wing_airframe_and_fixed_gear",
		cessna_missing.is_empty(),
		"all required presentation parts are built" if cessna_missing.is_empty() else ", ".join(cessna_missing))

	# ---- and you can see out of the ones with windows in them -------------------------
	#
	# A hull used to be one box, which is a thing you cannot see out of -- so the whole
	# airframe was hidden the moment its owner climbed in. A skin made of panels with the
	# windows LEFT OUT means it can stay drawn, and these are the checks that say it is
	# worth drawing: a window nobody can see through is worse than no window, because it
	# looks like it works.
	#
	# All of it is arithmetic against the panels, which are plain boxes. No physics, no
	# world, no frame drawn.
	# How big a head is, for "is anybody sitting inside a wall". A doorpost a hand's breadth
	# from your shoulder is a Cessna; one through your ear is a mistake.
	const HEAD: float = 0.11
	var blind: Array = []
	var buried: Array = []
	var oversize: Array = []
	for kind in range(Sim.Kind.size()):
		# A kind with no hull has no windows to see out of, and asking for its scene at all is an
		# engine error the runner fails on. See the note on `is_drawn` in the loop above.
		if not VehicleCatalogue.is_drawn(kind):
			continue
		var scene := load("res://objects/vehicles/craft_%s.tscn"
			% Sim.kind_name(kind)) as PackedScene
		if scene == null:
			continue
		var craft := scene.instantiate() as VehicleView
		add_child(craft)
		craft._show_in_editor()
		var panels: Array = craft.hull_panels()
		# A kind still drawn as one box has nothing to answer for yet. They arrive one at a
		# time, and the world stays flyable in between.
		if panels.is_empty():
			craft.queue_free()
			continue
		var solid_to: Vector3 = Sim.client.kind_geometry(kind).get("extents", Vector3.ONE)
		var band: Vector2 = craft.glazed_band()
		for entry in (Sim.client.kind_geometry(kind).get("seat_poses", []) as Array):
			var sat: Vector3 = entry.get("position", Vector3.ZERO)
			var eye := Vector3(sat.x, sat.y + CockpitStation.EYE_HEIGHT, sat.z)
			# NOBODY IS SITTING INSIDE A WALL. The pilot's head is a sphere, and a panel
			# through it is a panel through them.
			for panel in panels:
				if (panel as AABB).grow(HEAD).has_point(eye):
					buried.append("%s seat at %.1f" % [Sim.kind_name(kind), sat.z])
					break
			# A mission operator works inside an intentionally windowless equipment cabin. The
			# station gallery proves that seat's displays and local reference scene; treating a
			# pressure hull as a failed windscreen would force fake flight-deck glazing through
			# the whole E-6B. It still has to pass the wall/head clearance check above.
			if String(entry.get("station", entry.get("role", ""))) == "operator":
				continue
			# AND THE EYE IS IN THE GLAZING, which is the whole reason the band is worked
			# out from the seats rather than from a fraction of the hull.
			if band != Vector2.ZERO and (eye.y < band.x or eye.y > band.y):
				blind.append("%s eye at %.2f, glazing %.2f-%.2f" % [
					Sim.kind_name(kind), eye.y, band.x, band.y])
			# HOW MUCH OF THE FORWARD HALF IS CLEAR, AT EYE LEVEL.
			#
			# Level, and only level, and that is not a shortcut. The first version swept a
			# little up and down as well and every aeroplane failed it, because a cabin has
			# a roof and a sill and a pilot looking twelve degrees up sees the roof -- in
			# this game and in every real one. A test that a Cessna cannot pass is not
			# measuring the Cessna.
			#
			# What the horizon is, is level. Sweeping it is what says whether the windows
			# are windows or whether the posts have quietly closed the cabin in.
			var open_ways: int = 0
			var tried: int = 0
			for step in range(19):
				var about: float = -PI * 0.5 + PI * float(step) / 18.0
				tried += 1
				if HullSkin.is_clear(panels, eye, Vector3(sin(about), 0.0, -cos(about)), 40.0):
					open_ways += 1
			if float(open_ways) / float(tried) < 0.75:
				blind.append("%s sees out of %d of %d ways" % [
					Sim.kind_name(kind), open_ways, tried])
			# AND THE GROUND, out of at least one side. Looking down over your own sill is
			# the whole reason anybody learns to fly in a high-wing aeroplane, and it is how
			# you find a runway.
			var down: bool = false
			for about in [-1.4, -1.0, 1.0, 1.4]:
				if HullSkin.is_clear(panels, eye,
						Vector3(sin(about), -0.30, -cos(about)), 40.0):
					down = true
			if not down:
				blind.append("%s cannot see the ground from any window" % Sim.kind_name(kind))
			# AND DEAD AHEAD, which is the one direction an aeroplane is flown by -- asked
			# only of the seats that FLY it. A passenger behind the wing looking thirty
			# degrees off the nose is looking at a doorpost, in this aeroplane and in every
			# real one, and `flies` is already on the wire to tell them apart.
			if not bool(entry.get("flies", false)):
				continue
			for about in [-0.52, 0.0, 0.52]:
				if not HullSkin.is_clear(panels, eye, Vector3(sin(about), 0.0, -cos(about)),
						40.0):
					blind.append("%s cannot see %.0f deg off the nose" % [
						Sim.kind_name(kind), rad_to_deg(about)])
		# THE DRAWN THING IS STILL THE THING YOU HIT, across and along. Not in height: the
		# cabin deliberately stands proud of the hull, because the crew's eyes are above it.
		for panel in panels:
			var box: AABB = panel
			if (absf(box.position.x) > solid_to.x + 0.02
					or absf(box.position.x + box.size.x) > solid_to.x + 0.02
					or absf(box.position.z) > solid_to.z + 0.02
					or absf(box.position.z + box.size.z) > solid_to.z + 0.02):
				oversize.append("%s panel at %s" % [Sim.kind_name(kind), box.position])
				break
		craft.queue_free()
	_check("you_can_see_out_of_every_seat", blind.is_empty(),
		"%s" % ["every seat has a view" if blind.is_empty() else blind])
	_check("and_nobody_is_sitting_inside_a_wall", buried.is_empty(),
		"%s" % ["all clear" if buried.is_empty() else buried])
	_check("and_the_drawn_hull_is_the_width_you_collide_with", oversize.is_empty(),
		"%s" % ["every panel inside the extents" if oversize.is_empty() else oversize])

	# NO TWO GRIPS WITHIN ONE HAND OF EACH OTHER: MOVED TO tests/fit.gd.
	#
	# This used to be here, and it was measuring the wrong thing. It instantiated the SEAT
	# SCENE at each seat pose and walked `controls()` on it -- a station built that way has
	# never been `fit`, so it has no gun on it, and it is not in a craft, so there is no
	# centre console either. The flap gate, the gear lever, the drop handle and every
	# gunner's trigger in the game were invisible to it, and twenty-three pairs were inside
	# the rule when something finally looked at a whole cockpit.
	#
	# `fit` builds the craft instead -- hull, stations, console and guns -- for every kind,
	# and checks the same rule over all of it in under a second.

	# A cockpit is authored against one eye height and a headset reports another -- a fact
	# about the room, not about the aeroplane. The origin drops by the difference, so the
	# eyes land where the deck was built for them and the hands come down with them.
	var eyes: float = rig.origin.position.y \
		+ (rig.camera.position.y if rig.using_xr else CockpitStation.EYE_HEIGHT)
	_check("the_player_is_sat_down_where_the_cockpit_expects_them",
		absf(eyes - CockpitStation.EYE_HEIGHT) < 0.02,
		"eyes at %.2f m above the seat, cockpit built for %.2f" % [
			eyes, CockpitStation.EYE_HEIGHT])

	# THE STATIONS ARE FOUND, NOT LISTED. Anything a cockpit scene contains turns up here
	# without a second roster to keep in step, which is what lets a screen added in the
	# editor start being fed without anything in code being told about it.
	_check("the_stations_in_a_craft_can_be_found",
		view.stations().size() == view.manned_seats().size()
			and view.stations().size() >= 1,
		"%d station(s) found, %d seat(s) manned" % [view.stations().size(),
			view.manned_seats().size()])

	# WHO IS IN WHAT SEAT, every seat, occupied or not. The empty ones are the interesting
	# half: what a pilot needs before pressing the seat button is which seats this craft HAS.
	var roster: Array = view.crew()
	var seated: int = 0
	var is_mine: int = 0
	for row in roster:
		if int(row.get("client", 0)) > 0:
			seated += 1
		if bool(row.get("mine", false)):
			is_mine += 1
	_check("and_the_crew_roster_covers_every_seat",
		roster.size() == view.seats.size() and seated >= 1 and is_mine == 1,
		"%d row(s) for %d seats, %d occupied, %d mine" % [roster.size(),
			view.seats.size(), seated, is_mine])
	_check("and_says_which_station_each_one_is",
		String((roster[0] as Dictionary).get("station", "")) == "pilot",
		"seat 1 is the %s" % [(roster[0] as Dictionary).get("station", "?")])

	# EVERY SCREEN READS THE CRAFT'S OWN STATE and nothing else, which is what makes the
	# copilot's airspeed and the pilot's the same number rather than two answers a round
	# trip apart.
	var state: Dictionary = view.craft_state()
	_check("a_craft_publishes_one_state_for_all_its_screens",
		state.has("airspeed") and state.has("altitude") and state.has("heading")
			and state.has("throttle") and state.has("name"),
		"the craft says %s" % [state.keys()])
	var screens: Array = view.stations()[0].find_children("*", "CraftDisplay", true, false)
	_check("and_the_station_has_a_screen_to_put_it_on", screens.size() >= 1,
		"%d screen(s) on the console" % screens.size())

	# YOU CAN SEE OUT OF IT. A cockpit is a box you have to look out of, so what is checked
	# is what is NOT in the way: nothing solid stands in the band from just above the
	# console to well over a 1.6 m pilot's head, all the way round.
	#
	# Cast from the eye position out along eight bearings at eye level and see what it hits.
	var eye: Vector3 = Vector3(0.0, PilotRig.EYE_HEIGHT, 0.0)
	var station: Node3D = seat.get_node_or_null("Station")
	var blocked: Array = []
	if station != null:
		for solid in _solids_under(station):
			var box := (solid.mesh as BoxMesh).size
			var at: Vector3 = seat.to_local(solid.global_position)
			# Does this box straddle eye level, and is it wide enough to be a wall rather
			# than a post or a rail?
			if absf(at.y - eye.y) < box.y * 0.5 and box.x > 0.30 and box.z > 0.30:
				blocked.append(solid.name)
	_check("nothing_in_the_cockpit_blocks_the_view_out",
		blocked.is_empty(),
		"at eye level: %s" % ["clear" if blocked.is_empty() else blocked])
	# AND THERE IS NOTHING OVER THE PILOT'S HEAD AT ALL. There used to be a frame, and the
	# question was whether it cleared a 1.6 m head; the frame went on 2026-09-17 with the rest
	# of the scaffold, so what this now says is that the station puts nothing back up there.
	# It reports the height either way, because a check that is green because the thing it
	# measures does not exist should say so in its own log line.
	var overhead: float = 99.0
	if station != null:
		for solid in _solids_under(station):
			var box := (solid.mesh as BoxMesh).size
			var at: Vector3 = seat.to_local(solid.global_position)
			if box.x > 0.30 and at.y > eye.y:
				overhead = minf(overhead, at.y - box.y * 0.5)
	_check("and_nothing_the_station_draws_stands_over_a_pilots_head",
		overhead > CockpitStation.PILOT_HEIGHT,
		"nothing overhead at all" if overhead > 90.0
			else "the lowest thing overhead is at %.2f m, over a %.2f m pilot" % [
				overhead, CockpitStation.PILOT_HEIGHT])

	# A HAND ON ONE CONTROL IS ON NO OTHER. The console is a few centimetres wide, so a
	# fist closed round the stick sweeps across the crew button on the way back -- and the
	# button used to fire, at the tick rate, for as long as you were pulling.
	#
	# The rig is what enforces it, so the rig is what is asked.
	var lamp := mine["button"] as CrewButton
	# An Array and not an int, because a lambda captures by value and a counter that only
	# counts inside the lambda counts nothing.
	var fired: Array = [0]
	lamp.pressed.connect(func(_b): fired[0] += 1)
	rig.grip_right = 1.0
	rig.right_hand.global_position = lamp.grip_global()
	rig._work_the_controls(0.008)
	_check("a_hand_holding_the_stick_cannot_press_anything_else",
		int(fired[0]) == 0 and stick.is_held(),
		"the button fired %d time(s) with the stick held" % int(fired[0]))

	# AND IT STILL CANNOT WHEN IT GRABBED THE STICK THIS VERY FRAME. The controls are
	# offered in order, so a hand recorded as free at the top of the loop had already taken
	# the lever by the time the button came round -- and pressed it. Asked fresh each time,
	# it has not.
	stick.release()
	rig.right_hand.global_position = stick.grip_global()
	rig._work_the_controls(0.008)
	var took: bool = stick.is_held()
	rig.right_hand.global_position = lamp.grip_global()
	rig._work_the_controls(0.008)
	_check("and_a_hand_that_grabs_one_this_frame_cannot_press_another_this_frame",
		took and int(fired[0]) == 0,
		"grabbed %s, button fired %d time(s)" % [took, int(fired[0])])
	rig.grip_right = 0.0

	stick.offer_hand(1, grip, 0.0)
	_check("and_letting_go_releases_it", not stick.is_held(), "released")
	# AND IT CENTRES, rudder with it. A stick is a spring; that is the whole of what makes
	# it different from the lever beside it.
	stick.relax(1.0)
	_check("and_a_released_stick_centres_its_rudder_as_well",
		absf(stick.rudder()) < 0.2 and stick.value.length() < 0.2,
		"rudder back to %.2f" % stick.rudder())

	stick.value = Vector2.ZERO

	var lever := mine["throttle"] as ThrottleLever
	var knob: Vector3 = Vector3(0.0, 0.03, ThrottleLever.TRAVEL * 0.5)
	lever.offer_hand(0, knob, 1.0)
	lever.offer_hand(0, knob + Vector3(0.0, 0.0, -ThrottleLever.TRAVEL * 0.75), 1.0)
	_check("and_the_throttle_lever_opens_when_pushed_forward", lever.throttle() > 0.6,
		"throttle %.2f from three quarters of its travel" % lever.throttle())
	_check("and_a_latched_lever_stays_where_it_is_put",
		lever.throttle() > 0.6 and not lever.is_held() == false,
		"still %.2f while held" % lever.throttle())
	lever.offer_hand(0, knob + Vector3(0.0, 0.0, -ThrottleLever.TRAVEL * 0.75), 0.0)
	_check("and_it_is_still_there_after_letting_go", lever.throttle() > 0.6,
		"throttle %.2f with nobody holding it" % lever.throttle())
	# AND THAT IS WHAT THE AEROPLANE IS GIVEN. The frame used to read the lever only while
	# a hand was on it and fall back to the hardware otherwise, so letting go of a lever set
	# to cruise dropped the engines to whatever the trigger happened to be, which was
	# nothing. A lever stays where it is put; that is what makes it a lever.
	var idle: Dictionary = rig.read_controls()
	_check("and_the_aeroplane_is_given_the_lever_and_not_the_trigger",
		absf(float(idle["throttle"]) - lever.throttle()) < 0.02,
		"the frame says throttle %.2f against the lever's %.2f" % [
			float(idle["throttle"]), lever.throttle()])

	# A STATION MAY HAVE NEITHER A STICK NOR A THROTTLE, and a control tower has neither.
	#
	# It has a radio, a screen and a button, and every one of those is worth sitting at --
	# but everything that walks a cockpit had been written against an aeroplane, where
	# there are always three levers. Taking the tower threw
	#
	#   Invalid call. Nonexistent function 'is_held' in base 'Nil'.
	#
	# the moment the player touched the throttle axis, and the station was never claimed at
	# all, because "have I already got these controls" was asked by comparing the STICK --
	# and on a tower both sides of that comparison are null.
	var cabin := (load("res://objects/seats/seat_tower.tscn") as PackedScene) \
		.instantiate() as CockpitStation
	add_child(cabin)
	var up_there: Dictionary = cabin.controls()
	_check("a_control_tower_has_no_stick_and_no_throttle",
		up_there["stick"] == null and up_there["throttle"] == null,
		"it has %s" % [up_there.keys().filter(func(k): return up_there[k] != null)])
	_check("but_it_does_have_something_to_sit_at",
		up_there["button"] != null and up_there["rudder"] != null,
		"a button and a repeater")

	# THE HANDS RUN OVER IT WITHOUT A STICK OR A THROTTLE TO HOLD. If this throws, the rest
	# of this section never runs and `every_section_of_the_suite_ran` says so.
	var held_stick: VehicleControl = rig._my_stick
	var held_lever: VehicleControl = rig._my_throttle
	var held_button: CrewButton = rig._my_button
	rig._my_stick = null
	rig._my_throttle = null
	rig._my_button = up_there["button"]
	rig._lever_rate = 1.0
	rig._work_the_controls(Sim.tick_dt())
	rig._lever_rate = 0.0
	rig._my_stick = held_stick
	rig._my_throttle = held_lever
	rig._my_button = held_button
	_check("and_working_a_station_with_neither_does_not_throw", true,
		"the hands ran over a tower cabin")
	cabin.queue_free()

	# Reached the end of this section. See _finish.
	_sections["cockpit"] = true


## ---- what the rest of the hand does, and who decides -------------------------------
##
## A hand controller has a trigger, two thumb buttons, a mini joystick that clicks in, and a
## menu button. What those mean depends on what the hand is HOLDING -- that is the whole
## feature -- so what is checked here is not any one binding but the rule: a control speaks
## for its own fingers, an empty hand falls back to the global set, and the two inputs that
## may never be bound never are.
##
## NO FRAMES PASS IN HERE. The tables are asked directly and the latch is driven by hand, so
## this can sit in the middle of the suite without moving anything.
func _test_the_hand_bindings(rig: PilotRig) -> void:
	# ---- the same button, two controls, two answers --------------------------------
	#
	# The point of the exercise, stated as plainly as it can be. If these two ever agree,
	# the per-control table has stopped doing anything and the feature is gone.
	# A COLUMN ON A CRAFT THAT TRIMS, 255 wide like every trim channel. A column at 0 binds no trim; see
	# tests/shared_controls.gd, which holds the pod's stick to show it.
	var column: Dictionary = FlightStick.column_bindings(255)
	var lever: Dictionary = ThrottleLever.throttle_bindings()
	# THE MINI JOYSTICK IS THE ONE TO COMPARE NOW. It flies the aeroplane in an empty hand
	# and winds the trim in a hand that is on the stick, which is the same contrast the two
	# thumb buttons used to make before trim moved off them -- and a better one, because it
	# is the input a player reaches for without being told.
	var empty: Dictionary = rig._global_bindings(SignalZones.LEFT)
	# COMPARED AS THE AXES THEY DRIVE. One entry is a single action and the other is an
	# ARRAY of two -- a thumbstick in an empty hand is pitch AND roll -- and `!=` across
	# those two types is not a comparison, it is an error.
	_check("one_input_means_two_things_depending_what_is_held",
		_axes_of(column.get(Bind.STICK)) != _axes_of(empty.get(Bind.STICK)),
		"held, the stick drives %s; empty, %s" % [
			_axes_of(column.get(Bind.STICK)), _axes_of(empty.get(Bind.STICK))])
	_check("and_the_column_trims_with_it",
		String((column[Bind.STICK] as Dictionary).get("axis", "")) == "trim_rate",
		"%s" % _binding_says(column[Bind.STICK]))
	# AND PRESSING IT IN PUTS THE TRIM BACK. A trim you cannot quickly undo is one people
	# are afraid to touch, and afraid-to-touch is where it started.
	_check("and_pressing_it_in_centres_the_trim",
		int((column[Bind.STICK_CLICK] as Dictionary).get("channel", -1))
			== Sim.Channel.TRIM,
		"%s" % _binding_says(column.get(Bind.STICK_CLICK)))
	_check("and_the_throttle_works_the_flaps_with_it",
		int((lever[Bind.THUMB_HIGH] as Dictionary).get("channel", -1)) == Sim.Channel.FLAPS,
		"%s" % _binding_says(lever[Bind.THUMB_HIGH]))

	# ---- a gun is fired by the finger, not by holding it ----------------------------
	#
	# Holding USED to be the firing, which made a gunner who wanted to keep hold of the gun
	# without shooting -- a gunner traversing onto a target -- impossible.
	var gun := GunTrigger.new()
	var gun_table: Dictionary = gun.bindings()
	# TWO ACTIONS ON ONE FINGER, and both of them matter. See `Bind.fire`: the bit says the
	# trigger is pulled and the axis says how hard, and a server given only the first has
	# no rate of fire to work with.
	var pulled: Array = gun_table.get(Bind.TRIGGER, []) as Array
	var bit: Dictionary = {}
	for action in pulled:
		if int((action as Dictionary).get("kind", -1)) == Bind.Kind.FRAME_BIT:
			bit = action as Dictionary
	_check("the_trigger_fires_the_gun_the_hand_is_holding",
		int(bit.get("bit", 0)) == Sim.BUTTON_FIRE,
		"%s" % [pulled.map(_binding_says)])
	# AND IT IS AN AXIS AND NOT A SWITCH. The whole of the travel, onto the frame, because
	# a trigger is the one analog input a hand has and half-travel-or-nothing throws it
	# away -- a cannon eased down to single rounds is a cannon worked with a finger.
	_check("and_how_hard_it_is_pulled_goes_with_it",
		_axes_of(pulled).has("trigger"),
		"the trigger drives %s" % [_axes_of(pulled)])
	# AND THE BRAKE IS TAKEN OFF THAT FINGER. The global set puts the brake on the left
	# trigger; a gunner who braked every time they fired would be a menace. An ABSENT entry
	# would leave it braking, so this has to be a present one.
	_check("and_the_brake_is_taken_off_that_finger_rather_than_left_out",
		gun_table.has(Bind.TRIGGER) and not _axes_of(pulled).has("brake"),
		"the gun names the trigger rather than leaving it to fall through")
	var ammo: Dictionary = gun_table.get(Bind.THUMB_LOW, {})
	_check("and_the_thumb_beside_it_chooses_the_round",
		int(ammo.get("channel", -1)) == Sim.Channel.WEAPON and bool(ammo.get("wrap", false)),
		"%s" % _binding_says(ammo))
	gun.free()

	# ---- an empty hand still flies the aeroplane ------------------------------------
	#
	# The global set is not a fallback nobody uses: with no hand on anything it IS the
	# controls, and it has to say what the rig has always done.
	var empty_left: Dictionary = rig._global_bindings(0)
	var empty_right: Dictionary = rig._global_bindings(1)
	_check("an_empty_left_hand_still_brakes_with_its_trigger",
		int((empty_left[Bind.TRIGGER] as Dictionary).get("kind", -1)) == Bind.Kind.FRAME_AXIS
			and String((empty_left[Bind.TRIGGER] as Dictionary).get("axis", "")) == "brake",
		"%s" % _binding_says(empty_left[Bind.TRIGGER]))
	_check("and_its_thumbstick_is_still_the_control_column",
		_axes_of(empty_left[Bind.STICK]) == ["pitch", "roll"],
		"left stick drives %s" % [_axes_of(empty_left[Bind.STICK])])
	_check("and_the_right_one_is_still_rudder_and_power",
		_axes_of(empty_right[Bind.STICK]) == ["rudder", "lever_rate"],
		"right stick drives %s" % [_axes_of(empty_right[Bind.STICK])])

	# ---- and a held control overrides only what it names ----------------------------
	#
	# The merge is the part that makes a small table enough. A plain control column says
	# nothing about the thumb buttons, so a hand on the column keeps the empty hand's upper
	# thumb action. Use the column's frame input here rather than the throttle's flap command:
	# `_bindings_for` correctly removes commands for channels the current craft does not fit,
	# and this section may run after the cockpit checks have moved the rig to such a craft.
	var held := FlightStick.new()
	rig.add_child(held)
	held.setup(0)
	held.held_by = 0
	rig._reachable.append(held)
	var held_table: Dictionary = held.bindings()
	var merged: Dictionary = rig._bindings_for(0)
	_check("a_held_control_overrides_only_the_fingers_it_names",
		merged.get(Bind.TRIGGER) == held_table.get(Bind.TRIGGER)
			and merged.get(Bind.THUMB_HIGH) == empty_left.get(Bind.THUMB_HIGH),
		"the trigger is the column's and the upper thumb keeps the empty-hand action")

	# ---- pushed, or turned ----------------------------------------------------------
	#
	# A tracked controller is not a stick. There is nothing under your hand to push
	# against, so holding full deflection is holding an arm out in mid-air, and a shoulder
	# gives out long before an aeroplane does. Rolling a wrist you can do all afternoon.
	#
	# WHAT IS CHECKED IS THAT THE HAND NEVER MOVED. Both halves below hand the control the
	# same POSITION twice and change only which way the wrist is facing -- so a stick that
	# answers is a stick reading the turn, and there is nowhere else the deflection could
	# have come from.
	var stick_under_hand := FlightStick.new()
	rig.add_child(stick_under_hand)
	stick_under_hand.setup(0)
	var on_it: Vector3 = stick_under_hand._grab_point()
	var wrist := Basis(Vector3.RIGHT, 0.45)

	stick_under_hand.offer_hand(0, on_it, 1.0, Basis.IDENTITY)
	stick_under_hand.offer_hand(0, on_it, 1.0, wrist)
	_check("a_control_set_to_push_ignores_the_wrist",
		absf(stick_under_hand.pitch()) < 0.01, "pitch %.3f from a turned wrist alone" % stick_under_hand.pitch())
	stick_under_hand.release()
	stick_under_hand.value = Vector2.ZERO

	# WHICH WAY A PULL READS IS ASKED OF THE SAME STICK, PUSHED, and not written into this suite: the
	# hand drawn 5 cm back towards you, +Z, with the stick set to push. The turned wrist below must
	# agree with it, so the check cannot be a sign typed beside the sign it checks.
	stick_under_hand.offer_hand(0, on_it, 1.0, Basis.IDENTITY)
	stick_under_hand.offer_hand(0, on_it + Vector3(0.0, 0.0, 0.05), 1.0, Basis.IDENTITY)
	var pulled_by_the_hand: float = stick_under_hand.pitch()
	stick_under_hand.release()
	stick_under_hand.value = Vector2.ZERO
	_check("a_stick_drawn_back_by_the_hand_moves", absf(pulled_by_the_hand) > 0.1,
		"pitch %.3f from 5 cm back" % pulled_by_the_hand)

	# AND THE SAME TURN, ON THE SAME CONTROL, SET TO TURN.
	rig._turned[stick_under_hand.label_text()] = true
	rig._reachable.append(stick_under_hand)
	rig._apply_how_things_are_worked()
	_check("and_the_board_can_set_one_control_to_turn_instead",
		stick_under_hand.driven_by == VehicleControl.Drive.ROTATION,
		"driven by %d" % stick_under_hand.driven_by)
	# TIPPED BACK AND TIPPED FORWARD, 0.3 rad from the grab, with the hand exactly where it grabbed.
	# Which is which is measured off the basis rather than named: back is the controller's nose,
	# -Z, turned up. This check once called Basis(RIGHT, 0.45) "nose down", asserted a push, and
	# so passed over a stick that flew backwards in pitch (2026-09-13).
	var tipped_back := Basis(Vector3.RIGHT, 0.3)
	var tipped_forward := Basis(Vector3.RIGHT, -0.3)
	stick_under_hand.offer_hand(0, on_it, 1.0, Basis.IDENTITY)
	stick_under_hand.offer_hand(0, on_it, 1.0, tipped_back)
	var pulled_by_the_wrist: float = stick_under_hand.pitch()
	stick_under_hand.release()
	stick_under_hand.value = Vector2.ZERO
	stick_under_hand.offer_hand(0, on_it, 1.0, Basis.IDENTITY)
	stick_under_hand.offer_hand(0, on_it, 1.0, tipped_forward)
	var pushed_by_the_wrist: float = stick_under_hand.pitch()
	stick_under_hand.release()
	stick_under_hand.value = Vector2.ZERO
	# A mode that got the sign wrong would be worse than no mode at all.
	_check("and_then_a_wrist_tipped_back_pulls_it_the_way_the_hand_drawn_back_did",
		(tipped_back * Vector3.FORWARD).y > 0.0 and absf(pulled_by_the_wrist) > 0.1
			and signf(pulled_by_the_wrist) == signf(pulled_by_the_hand),
		"nose %.2f up, pitch %.3f against %.3f from the hand" % [(tipped_back * Vector3.FORWARD).y,
			pulled_by_the_wrist, pulled_by_the_hand])
	_check("and_a_wrist_tipped_forward_pushes_it",
		(tipped_forward * Vector3.FORWARD).y < 0.0 and absf(pushed_by_the_wrist) > 0.1
			and signf(pushed_by_the_wrist) == -signf(pulled_by_the_hand),
		"nose %.2f up, pitch %.3f against %.3f from the hand" % [(tipped_forward * Vector3.FORWARD).y,
			pushed_by_the_wrist, pulled_by_the_hand])
	rig._turned.clear()
	rig._reachable.erase(stick_under_hand)
	stick_under_hand.queue_free()

	# ---- tap to latch, tap again to let go ------------------------------------------
	#
	# Driven by hand rather than by letting frames pass: the threshold is wall-clock and a
	# headless suite at --fixed-fps runs a great many frames per real second, so a squeeze
	# would otherwise be indistinguishable from a tap.
	rig._latched[0] = false
	rig._grip_was_closed[0] = false
	var squeezing: float = rig._grip_of(0, 1.0)
	_check("a_closed_hand_reads_as_closed_before_any_tap_is_finished",
		absf(squeezing - 1.0) < 0.001 and not rig._latched[0],
		"grip %.2f, latched %s" % [squeezing, rig._latched[0]])
	var after_tap: float = rig._grip_of(0, 0.0)
	_check("and_a_quick_tap_latches_the_hand_onto_what_it_holds",
		rig._latched[0] and absf(after_tap - 1.0) < 0.001,
		"an open hand still reads %.2f" % after_tap)
	rig._grip_of(0, 1.0)
	var after_second: float = rig._grip_of(0, 0.0)
	_check("and_a_second_tap_lets_go", not rig._latched[0] and after_second < 0.01,
		"latched %s, grip %.2f" % [rig._latched[0], after_second])
	# A SQUEEZE IS NOT A TAP. Held past the threshold, opening the hand simply releases,
	# which is what everybody who has played this already expects.
	rig._grip_of(0, 1.0)
	rig._grip_closed_at[0] -= PilotRig.TAP_SECONDS * 2.0
	var after_hold: float = rig._grip_of(0, 0.0)
	_check("and_holding_it_down_then_releasing_is_not_a_latch",
		not rig._latched[0] and after_hold < 0.01,
		"latched %s, grip %.2f" % [rig._latched[0], after_hold])
	# AND A LATCH SURVIVES NOTHING IT SHOULD NOT. A control freed under a pinned hand --
	# which `Sky._reap` does every time an aeroplane stops being reported -- would otherwise
	# leave the fist closed for the rest of the session, grabbing everything it passed.
	rig._grip_of(0, 1.0)
	rig._grip_of(0, 0.0)
	var was_latched: bool = rig._latched[0]
	held.held_by = -1
	var orphaned: float = rig._grip_of(0, 0.0)
	_check("and_a_latch_with_nothing_left_to_hold_lets_go_of_itself",
		was_latched and not rig._latched[0] and orphaned < 0.01,
		"latched %s then %s" % [was_latched, rig._latched[0]])
	rig._reachable.erase(held)
	held.queue_free()

	# ---- every input on the controller is spoken for --------------------------------
	#
	# The ask was all of them, so this counts. Grip and menu are deliberately absent from
	# every table and that is what makes them reliable: grip is always take-hold-of-this and
	# menu is always the board, on every control in the game, so neither can be lost.
	var spoken: Dictionary = {}
	# NOT `GunTrigger.new().bindings()` INLINE. A control built with `new()` and never put
	# in a tree is never freed either, and four of them left at the end of this suite is
	# four "ObjectDB instances were leaked at exit" -- which the runner now reads as a
	# failure, and rightly: a leak here is a leak anywhere.
	var spare := GunTrigger.new()
	for table in [rig._global_bindings(0), rig._global_bindings(1),
			FlightStick.column_bindings(255), ThrottleLever.throttle_bindings(),
			spare.bindings()]:
		for input in table:
			spoken[input] = true
	_check("every_bindable_input_on_the_controller_is_bound_somewhere",
		spoken.size() == Bind.COUNT,
		"%d of %d: %s" % [spoken.size(), Bind.COUNT, spoken.keys()])
	spare.free()

	# Reached the end of this section. See _finish.
	_sections["hand_bindings"] = true


## A binding in words, for a failure message. A raw dictionary of enum ordinals tells you
## nothing at three in the morning.
func _binding_says(action: Variant) -> String:
	if action == null:
		return "nothing at all"
	var it: Dictionary = action as Dictionary
	match int(it.get("kind", -1)):
		Bind.Kind.FRAME_BIT:
			return "frame bit %d" % int(it.get("bit", 0))
		Bind.Kind.FRAME_AXIS:
			return "frame axis %s" % String(it.get("axis", "?"))
		Bind.Kind.COMMAND:
			var step: int = int(it.get("step", 0))
			return "channel %d %s" % [int(it.get("channel", -1)),
				("step %+d" % step) if step != 0 else ("set %d" % int(it.get("value", 0)))]
		Bind.Kind.LOCAL:
			return "local %d" % int(it.get("what", -1))
	return "unknown"


## Which frame axes a binding entry drives, in order. One input may drive two -- a
## thumbstick is pitch AND roll -- which is why an entry may be an Array.
func _axes_of(entry: Variant) -> Array:
	var out: Array = []
	for action in (entry if entry is Array else [entry]):
		out.append(String((action as Dictionary).get("axis", "?")))
	return out


## ---- the HUD says what you are flying ----------------------------------------------
##
## Which matters more than it sounds. Every vehicle is a box, the five movement models feel
## completely different, and from inside one there is nothing to tell them apart -- so a
## player who spawned in the pod flew a HOVER model and reported that the flight model flew
## like a spaceship. It does. It was the wrong vehicle, and nothing said so.
func _test_the_hud(rig: PilotRig) -> void:
	var hud: VehicleHud = rig.hud if rig != null else null
	_check("the_hud_exists", hud != null, "the rig carries one")
	if hud == null:
		return
	# DOWN AFTER BOOT, AND NOT WRITTEN. Asked for on 2026-09-14: the HUD starts away, and the clipboard's HUD switch puts
	# it up. This rig has flown a whole world by now, so a HUD that came up by itself, or wrote itself while down, would
	# show here.
	_check("the_hud_is_down_after_boot_and_unwritten", not hud.visible and not rig.hud_is_on() and rig.hud_writes == 0,
		"visible %s, up %s, written %d times" % [hud.visible, rig.hud_is_on(), rig.hud_writes])
	# AND THE REST OF THIS SECTION READS IT UP, put there by the rig's own call, which the switch lands on.
	rig.show_the_hud(true)
	for i in range(3):
		await get_tree().physics_frame
	# Head-locked, on whichever camera is current. Headless is never in XR, so it is the
	# desktop one; toggling the headset moves it, which _apply_display_mode does.
	_check("the_hud_is_on_the_current_camera", hud.get_parent() == rig.desktop_camera,
		"parented to %s" % hud.get_parent().name)
	var view: VehicleView = rig.vehicle_view()
	var wanted: String = String(
		Sim.client.kind_geometry(view.kind).get("name", "?")).to_upper()
	var shown: String = (hud.get_node("Panel/Title") as Label3D).text
	_check("the_hud_names_the_vehicle_you_are_in", shown.begins_with(wanted),
		"reads \"%s\", flying a %s" % [shown, wanted])
	# And says what to expect of it, which is the whole point: the difference between the
	# models is WHICH FORCES EXIST, and every one of those is a surprise to a pilot who
	# assumed otherwise.
	var detail: String = (hud.get_node("Panel/Detail") as Label3D).text
	# And which seat, because seat 0 is the only one with controls: a passenger pressing
	# the stick gets nothing, and nothing else would say why.
	_check("the_hud_names_the_seat_you_are_in",
		detail.contains("seat %d of" % (rig.seat_index() + 1)),
		"in seat %d, panel reads \"%s\"" % [rig.seat_index() + 1,
			" / ".join(detail.split(char(10)))])
	# The flash, which is a debugging instrument and therefore has to be trustworthy: if it
	# were stuck on, or stuck off, it would be worse than not having one.
	var flash := hud.get_node("Flash") as MeshInstance3D
	var material := flash.material_override as StandardMaterial3D
	# From a known state: by the time this runs the world has been flying for a while and
	# a rollback may legitimately have lit it.
	hud.clear_flash()
	_check("the_flash_is_off_until_something_happens",
		material != null and not flash.visible and material.albedo_color.a < 0.01,
		"alpha %.3f, visible %s" % [material.albedo_color.a if material != null else -1.0,
			flash.visible])
	hud.flash(VehicleHud.ROLLBACK)
	_check("a_rollback_turns_it_yellow",
		flash.visible and material.albedo_color.a > 0.05
			and material.albedo_color.r > 0.9 and material.albedo_color.b < 0.5,
		"alpha %.3f, colour %s" % [material.albedo_color.a, material.albedo_color])
	hud.flash(VehicleHud.FRAME_STEP)
	_check("a_dropped_frame_turns_it_red", material.albedo_color.g < 0.5,
		"colour %s" % material.albedo_color)
	hud.flash(VehicleHud.ROLLBACK)

	# The throttle, as a number. A trigger has no detent and no travel you can feel, so
	# without one there is no holding a cruise setting.
	_check("the_hud_reads_the_throttle_as_a_percentage",
		detail.contains("throttle") and detail.contains("%"),
		"panel reads \"%s\"" % " / ".join(detail.split(char(10))))
	_check("the_hud_says_what_to_expect_of_it",
		detail.length() > 12 and detail.contains("m/s"),
		"reads \"%s\"" % " / ".join(detail.split(char(10))))
	# Reached the end of this section. See _finish.
	rig.show_the_hud(false)
	_sections["hud"] = true


## ---- the world is the same world on every machine -----------------------------------
##
## Static collision is NOT replicated: every peer builds it from Terrain and the simulation
## never mentions it again. A peer whose mountain is somewhere else does not get a visual
## glitch -- it predicts its own aeroplane straight through a hillside the server says is
## solid, and rolls back into it for ever.
##
## So the two things worth proving here are that the generator gives the same answer twice,
## and that the picture was built from the same list the physics was.
## EVERY PLACE AN AUTOPILOT MAY BE SENT IS A PLACE IT CAN ACTUALLY BE.
##
## The pools are built by scattering points and keeping them, and only two of the four ever
## checked what they landed in: the helicopter asked for 30 m of room and the car for 14,
## and the aeroplane pool -- the biggest one, the one most of the sky flies to -- asked for
## nothing at all. A waypoint inside a mountain is not a near miss. The simulation checks
## each LEG against its own boxes before flying it, so a destination nothing can reach is a
## machine with no route, holding no altitude, descending until it hits something. That is
## the same failure the missing waypoint pools caused, arriving by a different door.
##
## MEASURED IN THE SAME BOXES THE COLLISION USES, `Terrain.boxes()`, because a check against
## a second idea of where the scenery is would pass while the aeroplane flew into a hill.
func _test_where_the_autopilots_are_sent() -> void:
	var solid: Array[Dictionary] = Terrain.boxes()
	var grid := BoxGrid.new(solid)
	var buried: Array[String] = []
	var counted: int = 0
	for kind in [Sim.Kind.PLANE, Sim.Kind.HELI, Sim.Kind.CAR, Sim.Kind.BOAT]:
		var pool: Array[Vector3] = Terrain.waypoints(kind, grid)
		_check("there_is_somewhere_for_a_%s_to_go" % Sim.kind_name(kind), pool.size() >= 8,
			"%d waypoints" % pool.size())
		for at in pool:
			counted += 1
			# ABOVE THE GROUND FIRST, which is the cheap half: the sea is at SEA_LEVEL and
			# the island above it, and nothing that flies belongs under either.
			if at.y < Terrain.SEA_LEVEL - 1.0:
				buried.append("%s at %v is under the sea" % [Sim.kind_name(kind), at])
				continue
			for box in solid:
				var to: Vector3 = at - (box["position"] as Vector3)
				var half: Vector3 = box["half_extents"]
				if absf(to.x) < half.x and absf(to.y) < half.y and absf(to.z) < half.z:
					buried.append("%s at %v is inside a %s" % [Sim.kind_name(kind), at,
						Terrain.Group.keys()[int(box.get("group", 0))].to_lower()])
					break
	_check("and_none_of_it_is_inside_the_scenery", buried.is_empty(),
		"all %d waypoints are in open air" % counted if buried.is_empty()
			else "%d of %d:\n      %s" % [buried.size(), counted,
				"\n      ".join(buried.slice(0, 8))])


func _test_the_world() -> void:
	var solid: Array[Dictionary] = Terrain.boxes()
	var again: Array[Dictionary] = Terrain.boxes()
	var identical: bool = again.size() == solid.size()
	for i in range(solid.size()):
		if not identical:
			break
		identical = again[i]["position"].is_equal_approx(solid[i]["position"]) \
			and again[i]["half_extents"].is_equal_approx(solid[i]["half_extents"])
	_check("the_world_generates_identically_every_time", identical and solid.size() > 100,
		"%d solid boxes, built twice and matching" % solid.size())

	# THE ROCK AND THE CONCRETE, a batch a kilometre since 2026-09-14 (`SceneryYard`): every box handed to every batch.
	var drawn: int = 0
	if _level.scenery != null:
		drawn += _level.scenery.drawn_boxes().size()
	# A HAND-BUILT PLACE'S BOXES are drawn by its own scene, not by the yard; they count as drawn once the place is read.
	drawn += AuthoredChunks.boxes(_level.places).size()
	var towns := _level.get_node_or_null("Towns") as TownView
	var buildings: Array[Dictionary] = towns.drawn_buildings() if towns != null else []
	drawn += buildings.size()
	# AN AIR BASE'S WALLS AND ROOFS are drawn by its own view: every solid box it handed its structures' batch.
	var airbases: Node = _level.get_node_or_null("Airbases")
	if airbases != null:
		for view in airbases.get_children():
			drawn += (view as AirbaseView).drawn_solid().size()
	# A COOLING TOWER'S SOLID is drawn by `PowerStation` as a shell rather than as boxes, for the same reason
	# an air base's is: a box drawn as well would be a grey slab inside the tower.
	var stations := _level.get_node_or_null("Stations") as PowerStation
	if stations != null:
		drawn += stations.drawn_solid().size()
	# AN OIL PLATFORM'S SOLID is drawn by the platform itself, steel and not boxes, like a tower's.
	var oil := _level.get_node_or_null("OilField") as OilField
	if oil != null:
		drawn += oil.drawn_solid().size()
	_check("the_picture_is_the_same_list_as_the_physics", drawn == solid.size(),
		"%d drawn, %d solid" % [drawn, solid.size()])

	# EVERY BUILDING DRAWN IS ONE BOX IN THE LIST, THE SAME SIZE IN THE SAME PLACE, and every building
	# box is drawn once. Read out of the MultiMeshes the town is actually rendered with, to the
	# centimetre -- a count that agreed while one town drew another's buildings would pass the check
	# above and fail this one.
	var listed: Dictionary = {}
	for box in solid:
		if int(box["group"]) == Terrain.Group.BUILDING:
			var key: String = _box_key(box)
			listed[key] = int(listed.get(key, 0)) + 1
	var unlisted: int = 0
	for building in buildings:
		var key: String = _box_key(building)
		if int(listed.get(key, 0)) == 0:
			unlisted += 1
		else:
			listed[key] = int(listed[key]) - 1
	var undrawn: int = 0
	for key in listed:
		undrawn += int(listed[key])
	_check("every_building_drawn_is_exactly_one_box_of_the_same_size", unlisted == 0 and undrawn == 0
		and buildings.size() > 0, "%d drawn; %d with no box, %d boxes not drawn" % [buildings.size(), unlisted, undrawn])

	# AND THE SIMULATION'S OWN COPY IS THAT BOX. Asked of the server's solid list through
	# `leg_is_clear`, which never sees the GDScript dictionaries: a leg across each wall of each drawn
	# building, from 0.3 m outside to 0.3 m inside, is blocked; one from 0.3 m to 1.3 m outside is not.
	var loose: Array[String] = []
	for building in buildings:
		var at: Vector3 = building["position"]
		var half: Vector3 = building["half_extents"]
		for axis in [Vector3.RIGHT, Vector3.BACK]:
			for side in [-1.0, 1.0]:
				var out: Vector3 = axis * side
				var face: Vector3 = at + out * (half * axis).length()
				var inward: bool = Sim.server.leg_is_clear(face + out * 0.3, face - out * 0.3, 0.0, 0.0)
				var outside: bool = Sim.server.leg_is_clear(face + out * 0.3, face + out * 1.3, 0.0, 0.0)
				if inward or not outside:
					loose.append("%s %s" % [at.round(), out])
	_check("and_the_simulation_holds_each_one_wall_for_wall", loose.is_empty() and buildings.size() > 0,
		"%d walls of %d buildings%s" % [buildings.size() * 4, buildings.size(),
			"" if loose.is_empty() else ", off: " + ", ".join(loose.slice(0, 4))])

	# Everything stands on the island and under the ceiling the wire can describe. A
	# vehicle outside that box is clamped on the wire, so every other machine watches it
	# stop at the boundary while its own pilot flies on.
	# AN OIL PLATFORM STANDS IN THE SEA ON PURPOSE (`OilField`), 3.3 km off the north coast, so its group is held apart:
	# not on the island, but inside the wire's range, which is what the clamp this check guards against is about.
	var reach: float = 0.0
	var at_sea: float = 0.0
	var tallest: float = 0.0
	for box in solid:
		var at: Vector3 = box["position"]
		var half: Vector3 = box["half_extents"]
		var out: float = maxf(absf(at.x) + half.x, absf(at.z) + half.z)
		if int(box.get("group", -1)) == Terrain.Group.OILRIG:
			at_sea = maxf(at_sea, out)
		else:
			reach = maxf(reach, out)
		tallest = maxf(tallest, at.y + half.y)
	_check("it_all_stands_on_the_island",
		reach < Terrain.WORLD_HALF and tallest < 1000.0 and at_sea < Terrain.WORLD_HALF * Terrain.BOAT_SPREAD,
		"reaches %.0f m out and %.0f m up, on a %.0f m island; the oil platform %.0f m out, inside the boats' %.0f" % [
			reach, tallest, Terrain.WORLD_HALF, at_sea, Terrain.WORLD_HALF * Terrain.BOAT_SPREAD])

	# The gates are gates. One that a mountain generated on top of is a wall.
	var blocked: int = 0
	var gates: Array[Vector3] = Terrain.gate_centres()
	for gate in gates:
		if _inside_anything(solid, gate + Vector3(0.0, Terrain.GATE_HEIGHT * 0.5, 0.0)):
			blocked += 1
	_check("every_gate_can_be_flown_through", blocked == 0 and gates.size() >= 4,
		"%d of %d openings are clear" % [gates.size() - blocked, gates.size()])

	# The ring of mountains is a ring you fly THROUGH. At fourteen peaks it closed into a fence
	# with no way out of the island except over the top, which is the opposite of the point
	# and is invisible from any screenshot. Measured on the rock itself since the ring became
	# ranges: the narrowest way across it at or under Terrain.PASS_LOW (2026-09-18).
	var gaps: Vector2 = Terrain.ring_gaps()
	_check("there_are_gaps_in_the_mountains_to_fly_through", gaps.x > 120.0,
		"the tightest pass under %.0f m is %.0f m wide and the widest %.0f m" % [Terrain.PASS_LOW, gaps.x, gaps.y])

	# Every aeroplane is spawned flying along its own NOSE. One that is not makes no lift
	# and mushes into the sea, and the sign error that does it is invisible for anything
	# facing along an axis -- which is why this checks the diagonals rather than trusting
	# that the ones you can see look right.
	var crabbing: int = 0
	var aircraft: int = 0
	for spawn in Terrain.spawns():
		var launch: Vector3 = spawn["velocity"]
		if launch.length() < 1.0:
			continue
		aircraft += 1
		if launch.normalized().dot(Terrain.nose_from_yaw(float(spawn["yaw"]))) < 0.999:
			crabbing += 1
	_check("every_aircraft_is_spawned_along_its_own_nose", crabbing == 0 and aircraft > 0,
		"%d of %d launched straight" % [aircraft - crabbing, aircraft])

	# And nothing was spawned inside a hill, which is a thing generated scenery will do to
	# a hand-placed spawn the moment either of them moves.
	var buried: int = 0
	for state in Sim.client.vehicle_states():
		if _inside_anything(solid, state["position"] as Vector3):
			buried += 1
	_check("nothing_was_spawned_inside_the_scenery", buried == 0,
		"%d of %d vehicles are in the open" % [
			Sim.client.vehicle_states().size() - buried,
			Sim.client.vehicle_states().size()])
	# Reached the end of this section. See _finish.
	_sections["world"] = true


static func _box_key(box: Dictionary) -> String:
	var at: Vector3 = box["position"]
	var half: Vector3 = box["half_extents"]
	return "%.2f %.2f %.2f / %.2f %.2f %.2f" % [at.x, at.y, at.z, half.x, half.y, half.z]


func _inside_anything(solid: Array[Dictionary], point: Vector3) -> bool:
	# AND UNDER THE ISLAND'S MOUNTAINS, which are triangles and not boxes since 2026-09-18: half a metre under the rock
	# the simulation collides with is inside it.
	if Terrain.mountains() != null and point.y < Terrain.ground_height(point) - 0.5:
		return true
	for box in solid:
		var to: Vector3 = point - (box["position"] as Vector3)
		var half: Vector3 = box["half_extents"]
		if absf(to.x) < half.x and absf(to.y) < half.y and absf(to.z) < half.z:
			return true
	return false


## ---- a hundred machines flying and driving themselves ---------------------------------
##
## Forty aeroplanes, forty helicopters, ten cars and ten boats, on autopilots that move the
## SAME LEVERS a player holds -- throttle, pitch, roll, rudder, brake -- and never a velocity
## or a force on the hull. An AI that set velocities would be flying a different aeroplane
## from the one in your hands, and the difference would be invisible until it mattered.
##
## Three quarters of the aircraft fly in flights of up to four. A follower has no route of
## its own: its destination is a place beside another machine, and it moves.
##
## What is worth checking is not that they move. It is that they are still where their kind
## belongs after a minute of it, that the flights are actually in formation, and that none
## of them is inside a mountain.
func _test_the_traffic() -> void:
	if Sim.server == null:
		_check("the_traffic_exists", false, "no server in this session")
		return
	var expected: int = 0
	for kind in [Sim.Kind.PLANE, Sim.Kind.HELI, Sim.Kind.CAR, Sim.Kind.BOAT]:
		expected += Terrain.fleet_size(kind)
	# AND THE BRIGS, which sail themselves too; `the_level_puts_its_brigs_on_the_sea` holds that all of them are there.
	expected += Terrain.PIRATE_FLEET
	# AND EVERY CRAFT SPAWNED ALREADY FLYING, which flies itself until somebody sits in it.
	# A wing with nobody on the throttle decays, and one parked in mid-air was measured at
	# 30 m/s and sinking within five seconds of the world starting.
	for spawn in Terrain.spawns():
		# NOT ONE PARKED ON A CARRIER: it carries the ship's speed, is still parked, and is given no autopilot.
		if (spawn["velocity"] as Vector3).length() > 1.0 and spawn.get("place", &"") != &"carrier":
			expected += 1
	_check("the_traffic_exists", int(Sim.server.ai_vehicle_count()) == expected,
		"%d machines flying themselves, wanted %d" % [
			int(Sim.server.ai_vehicle_count()), expected])

	# A leg is checked against the world before it is flown. Prove the check works at all,
	# in both directions, or "no route was blocked" means nothing.
	# THROUGH A CREST OF THE RING, at half the rock's own height there, so the leg is inside rock whatever the noise made of
	# that crest.
	var through: Vector3 = MountainRanges.ring_crests()[2]
	through.y = 0.0
	var inside := Vector3(0.0, Terrain.ground_height(through) * 0.5, 0.0)
	var west: Vector3 = through - Vector3(1200.0, 0.0, 0.0)
	var east: Vector3 = through + Vector3(1200.0, 0.0, 0.0)
	var up := Vector3(0.0, 1400.0, 0.0)
	_check("a_route_through_a_mountain_is_refused",
		inside.y > 50.0 and not Sim.server.leg_is_clear(west + inside, east + inside, 10.0, 10.0),
		"a leg drawn %.0f m up through a crest at %v" % [inside.y, through])
	_check("and_one_over_it_is_not",
		Sim.server.leg_is_clear(west + up, east + up, 10.0, 10.0),
		"the same leg 1400 m up")
	# And the one that had every car in the world sitting still: the island is a solid box,
	# so a car asked whether it may drive across the ground was told the ground was in the
	# way. A surface vehicle passes OVER what it drives on.
	_check("a_car_may_drive_across_the_ground",
		Sim.server.leg_is_clear(Vector3(0.0, 0.7, 0.0), Vector3(0.0, 0.7, 900.0), 10.0,
			0.0),
		"a leg along the island at wheel height")

	var started: Dictionary = {}
	for state in Sim.server.vehicle_states():
		var entity: int = int(state["entity"])
		if not Sim.server.ai_destination(entity).is_empty():
			started[entity] = state["position"]
			_legs_at_start[entity] = int(Sim.server.ai_destination(entity).get("legs", 0))
	# Long enough for the slowest thing out there to get somewhere, and for the flights to
	# settle into their slots.
	#
	# NOT timed here, and it is worth saying why: headless still paces its main loop to
	# real time, so wall clock over a physics frame measures the frame PERIOD and not the
	# work in it. The first version of this check reported 8.319 ms against an 8.33 ms
	# budget and would have reported that whatever the simulation cost. The real
	# measurement is in tests/hitch_probe.gd, which ticks the worlds by hand.
	for i in range(3600):
		await get_tree().physics_frame

	var solid: Array[Dictionary] = Terrain.boxes()
	var lone: int = 0
	var lone_routed: int = 0
	var lone_moved: int = 0
	var following: int = 0
	var worst_slot: float = 0.0
	var slot_total: float = 0.0
	var buried: int = 0
	var adrift: Array = []
	var stuck: Array = []
	var counted: int = 0
	for state in Sim.server.vehicle_states():
		var entity: int = int(state["entity"])
		var route: Dictionary = Sim.server.ai_destination(entity)
		if route.is_empty():
			continue
		counted += 1
		var at: Vector3 = state["position"]
		if _inside_anything(solid, at):
			buried += 1
		if bool(route.get("following", false)):
			following += 1
			var split: Vector2 = _slot_error_split(int(route.get("leader", 0)),
				route["slot"], at)
			var slip: float = Vector2(split.x, split.y).length()
			worst_slot = maxf(worst_slot, slip)
			slot_total += slip
			_flat_total += split.x
			_vertical_total += split.y
			_slot_slip.append(slip)
			if slip < 60.0:
				_in_slot += 1
			elif slip > 150.0 and _stragglers.size() < 6:
				var lead: Dictionary = Sim.server.vehicle_state(
					int(route.get("leader", 0)))
				_stragglers.append("%s %.0f m out, own %.0f m/s, leader %.0f m/s at %v" % [
					Sim.kind_name(int(state["kind"])), slip,
					(state["velocity"] as Vector3).length(),
					(lead.get("velocity", Vector3.ZERO) as Vector3).length(),
					(lead.get("position", Vector3.ZERO) as Vector3).snapped(Vector3.ONE)])
			# PER KIND, because they hold station in completely different ways and
			# averaging them together measures nothing: a convoy keeps 24 m nose to tail
			# and a flight keeps sixty across.
			match int(state["kind"]):
				Sim.Kind.PLANE:
					_plane_slip.append(slip)
					_plane_leaders[int(route.get("leader", 0))] = true
					_plane_followers[entity] = true
				Sim.Kind.CAR:
					_convoy_slip.append(slip)
				_:
					_heli_slip.append(slip)
					_nose_off.append(_nose_off_track(int(route.get("leader", 0)), state))
		else:
			lone += 1
			if int(route.get("legs", 0)) >= 1:
				lone_routed += 1
			if not started.has(entity) \
					or (started[entity] as Vector3).distance_to(at) > 250.0:
				lone_moved += 1
			else:
				stuck.append([int(state["kind"]), at])
				# HOW FAR IT ACTUALLY GOT, because the check above is a 250 m THRESHOLD and a
				# threshold cannot tell a crawl from a body held dead. "A car is in the stuck
				# list" and "moved 0.00 m, start and end identical to the last printed digit,
				# speed 0.00 m/s" are different findings, and only the second names a bug: it is
				# what isolated box3d f555ee4 against its own parent for erincatto/box3d#164, and
				# working it out after the fact cost lane/box3dreport a library build and two runs.
				#
				# ASK Sim, NOT THIS FILE. The local `_kind_name` answers "pod" for any kind it has
				# not been taught, and the two always in this list are PIRATE and SUBMARINE, so the
				# line meant to end an ambiguity would have introduced a worse one. `Sim.kind_name`
				# reads the enum's own keys and is the authority every other reader uses.
				print("[stuck] %s moved %.2f m, from %v to %v, speed %.2f m/s" % [
					Sim.kind_name(int(state["kind"])),
					(started[entity] as Vector3).distance_to(at),
					started[entity] as Vector3, at,
					(state["velocity"] as Vector3).length()])
		# Each kind still where its kind belongs. An aeroplane on the ground has crashed,
		# a boat inland has driven up the beach, and neither is a thing to leave running.
		match int(state["kind"]):
			Sim.Kind.PLANE:
				if at.y < 60.0:
					adrift.append([int(state["kind"]), at])
			Sim.Kind.HELI:
				if at.y < 15.0:
					adrift.append([int(state["kind"]), at])
			Sim.Kind.CAR:
				# OVER THE GROUND UNDER IT, since the island's mountains are ground a car can stand on (2026-09-18): a car
				# resting 57 m up on a range's foot is down, and one 8 m over the grass is not.
				if at.y - Terrain.ground_height(at) > 8.0:
					adrift.append([int(state["kind"]), at])
			Sim.Kind.BOAT:
				if absf(at.y - Terrain.SEA_LEVEL) > 4.0:
					adrift.append([int(state["kind"]), at])

	_check("every_machine_on_its_own_picked_a_route", lone > 0 and lone_routed == lone,
		"%d of %d independents have somewhere to be" % [lone_routed, lone])
	_check("and_went_there", lone_moved >= lone - 4,
		"%d of %d moved more than 250 m in half a minute (%s)" % [lone_moved, lone,
			_by_kind(stuck)])

	# THE FLIGHTS. A follower holds a slot in the leader's own frame, and the heading it
	# flies is the LEADER'S heading plus a clamped intercept -- never the bearing to the
	# slot. Steering at the slot is what makes a follower fly a full circle every time the
	# flight changes heading, because a lead turn drops the slot into its rear hemisphere.
	_check("three_quarters_of_the_aircraft_are_in_flights",
		following >= int(float(Terrain.fleet_size(Sim.Kind.PLANE)
			+ Terrain.fleet_size(Sim.Kind.HELI)) * 0.5),
		"%d of %d machines are following somebody" % [following, counted])
	# ON THE MEDIAN AND THE COUNT, not the mean and the worst, and that is a measurement
	# decision rather than a softer bar.
	#
	# A leader flies legs three kilometres long and turns onto a new one every forty
	# seconds or so, and a follower caught mid-rejoin is legitimately hundreds of metres
	# out and closing at forty metres a second -- which is the catch-up law doing its job,
	# not failing at it. One of those in the sample drags a mean of 33 m to 94 and a worst
	# to 866, and asserting on either measures whether a turn happened to be in progress
	# when the clock stopped. The median and the fraction in position describe the
	# formation; the mean describes the sampling instant.
	_slot_slip.sort()
	var median_slip: float = _slot_slip[_slot_slip.size() / 2] if not _slot_slip.is_empty() \
		else 0.0
	_check("and_they_are_holding_their_slots",
		following > 0 and median_slip < 60.0 and _in_slot > following / 2,
		"%d of %d within 60 m; median %.0f m, average %.0f m (%.0f across, %.0f along, %.0f vertical), worst %.0f m" % [
			_in_slot, following, median_slip,
			slot_total / float(maxi(following, 1)),
			_crosstrack_total / float(maxi(following, 1)),
			_along_total / float(maxi(following, 1)),
			_vertical_total / float(maxi(following, 1)), worst_slot])
	for row in _stragglers:
		print("[smoke]   straggler: %s" % row)
	# DOES IT SETTLE, OR DOES IT HUNT? An average slot error says how far out a flight sits
	# and nothing at all about whether it is sitting there or swinging through it. A
	# follower that crosses its slot four times in four seconds is holding a perfect average
	# and is not in formation.
	#
	# Sampled over four seconds: how far the error MOVES between samples, and how often the
	# crosstrack changes sign. Both are about the second derivative, which is what an
	# oscillation is and what an average is blind to.
	var track: Dictionary = {}
	for sweep in range(16):
		for i in range(15):
			await get_tree().physics_frame
		for state in Sim.server.vehicle_states():
			var id: int = int(state["entity"])
			var route: Dictionary = Sim.server.ai_destination(id)
			if route.is_empty() or not bool(route.get("following", false)):
				continue
			var split: Vector2 = _slot_error_split(int(route.get("leader", 0)),
				route["slot"], state["position"])
			if not track.has(id):
				track[id] = []
			(track[id] as Array).append(split.x)
	var crossings: float = 0.0
	var swing: float = 0.0
	for id in track:
		var rows: Array = track[id]
		var flips: int = 0
		var low: float = 1e9
		var high: float = -1e9
		for i in range(rows.size()):
			low = minf(low, float(rows[i]))
			high = maxf(high, float(rows[i]))
			if i > 0 and signf(float(rows[i])) != signf(float(rows[i - 1])):
				flips += 1
		crossings += float(flips)
		swing += high - low
	var followers: float = float(maxi(track.size(), 1))
	_check("the_flights_settle_rather_than_hunt",
		crossings / followers < 3.0 and swing / followers < 30.0,
		"%.1f crossings of the slot and %.0f m of swing per follower, over 4 s" % [
			crossings / followers, swing / followers])

	print("[smoke]   by kind: planes %s, helicopters %s, convoys %s" % [
		_summary(_plane_slip), _summary(_heli_slip), _summary(_convoy_slip)])
	# A CONVOY HOLDS TIGHTER THAN A FLIGHT, and has to: its slots are 24 m apart, so the
	# same error that is a tidy formation in the air is a pile-up on the ground.
	# A FLIGHT OF AEROPLANES HOLDS TO A WINGSPAN, and this is the number that says whether
	# the autopilot is still doing its job. It was 178 m average with a 3700 m straggler
	# before the loops were tightened and the followers were allowed to fly harder than
	# their leader; a bound of 15 catches a regression without pinning a lucky run.
	_plane_slip.sort()
	var plane_median: float = _plane_slip[_plane_slip.size() / 2] \
		if not _plane_slip.is_empty() else 0.0
	# OVER A WINDOW, NOT AT ONE INSTANT. The single sample above is one moment of a formation, and a flight whose leader
	# is mid-turn at that moment reads as spread however well it holds the rest of the run: on 2026-09-14 one leader
	# giving up one blocked leg put its flight into a turn at the sample and moved this median from 4 m to 25 with every
	# follower's escape count at zero. So the verdict is the median over a second-by-second window of about 25 s that
	# follows, and the bound is the same 15. It was held against the library from before that change as well as the one
	# after it, because a window that only ever passes the new library would be a check loosened to pass.
	var window: Array[float] = []
	for second in range(25):
		for i in range(int(round(Sim.tick_hz))):
			await get_tree().physics_frame
		for state in Sim.server.vehicle_states():
			if int(state["kind"]) != Sim.Kind.PLANE:
				continue
			var route: Dictionary = Sim.server.ai_destination(int(state["entity"]))
			if route.is_empty() or not bool(route.get("following", false)):
				continue
			var split: Vector2 = _slot_error_split(int(route.get("leader", 0)), route["slot"], state["position"])
			window.append(Vector2(split.x, split.y).length())
	window.sort()
	var window_median: float = window[window.size() / 2] if not window.is_empty() else 0.0
	var window_worst: float = window[window.size() - 1] if not window.is_empty() else 0.0
	# AND HOW MANY NEW LEGS EACH OF THEIR LEADERS TOOK while they were being watched, so a leader churning legs is a
	# number here and not only a spread.
	# THE LEADERS' LEGS DROPPED and THE FOLLOWERS' ESCAPE CLIMBS, both counted by the simulation since it started, so
	# which of the three ways a flight can come apart is happening is a number too.
	var churn: Array[String] = []
	var dropped: Array[String] = []
	for leader in _plane_leaders.keys():
		var route_now: Dictionary = Sim.server.ai_destination(int(leader))
		var now_legs: int = int(route_now.get("legs", 0))
		churn.append("%d" % (now_legs - int(_legs_at_start.get(leader, now_legs))))
		dropped.append("%d" % int(route_now.get("legs_dropped", 0)))
	# AND WHY EACH DROPPED LEG WAS DROPPED: where the leader was, where it was going, the box its leg as flown came
	# nearest and how near. A leg given up with more than the room the re-check keeps, or over the island's own ground,
	# is a re-check that is wrong.
	for leader in _plane_leaders.keys():
		var why: Dictionary = Sim.server.ai_destination(int(leader))
		if int(why.get("legs_dropped", 0)) > 0:
			print("[smoke]   leader %d dropped a leg at %v heading for %v: nearest box centre %v half %v, %.1f m from the path as flown" % [
				int(leader), why.get("dropped_at", Vector3.ZERO), why.get("dropped_goal", Vector3.ZERO),
				why.get("dropped_box_centre", Vector3.ZERO), why.get("dropped_box_half", Vector3.ZERO),
				float(why.get("dropped_clearance", -1.0))])
	var escaped: Array[String] = []
	for follower in _plane_followers.keys():
		escaped.append("%d" % int(Sim.server.ai_destination(int(follower)).get("escapes", 0)))
	_check("the_flights_hold_to_a_wingspan",
		window.is_empty() or window_median < 15.0,
		"over %d samples in 25 s, median %.0f m and worst %.0f m; at the single sample, %d aeroplanes in formation, median %.0f m, %s; their %d leaders took %s new legs in the run and have dropped %s, and the followers have started %s escape climbs" % [
			window.size(), window_median, window_worst, _plane_slip.size(), plane_median, _summary(_plane_slip),
			_plane_leaders.size(), ", ".join(churn), ", ".join(dropped), ", ".join(escaped)])

	_convoy_slip.sort()
	var convoy_median: float = _convoy_slip[_convoy_slip.size() / 2] \
		if not _convoy_slip.is_empty() else 0.0
	_check("the_convoys_hold_together",
		_convoy_slip.is_empty() or convoy_median < 45.0,
		"%d cars in convoy, median %.0f m, %s" % [_convoy_slip.size(), convoy_median,
			_summary(_convoy_slip)])


	# A HELICOPTER IN TRAIL POINTS DOWN THE LEADER'S PATH, not at its tail.
	#
	# Those are different, and only for a helicopter: an aeroplane's flight path follows its
	# nose to within a fraction of a degree, but a helicopter goes where the disc is tilted
	# and can point anywhere while doing it. A trail built on the leader's NOSE lays its
	# slots sideways across the flight path whenever the leader is crabbing, and the whole
	# line flies at an angle to where it is going.
	var worst_nose: float = 0.0
	var nose_total: float = 0.0
	for off in _nose_off:
		worst_nose = maxf(worst_nose, off)
		nose_total += off
	# The average, not the worst, for the same reason as the slots above: a helicopter
	# rejoining after a lead turn is legitimately pointing somewhere else while it does it.
	_check("helicopters_in_trail_point_down_the_leaders_track",
		not _nose_off.is_empty() and nose_total / float(_nose_off.size()) < 20.0,
		"average %.0f degrees off the leader's track, worst %.0f, over %d followers" % [
			nose_total / float(maxi(_nose_off.size(), 1)), worst_nose, _nose_off.size()])

	# The destination comes off the WIRE with the vehicle, not out of the server: entity
	# ids are per-world, so a client has no way to ask "where is the aeroplane I am in
	# going". Check it actually arrives, or the beacon in the cockpit is a solo-only
	# feature that looks fine right up until somebody joins.
	var with_route: int = 0
	for state in Sim.client.vehicle_states():
		if bool(state.get("has_route", false)):
			with_route += 1
	_check("the_destination_reaches_the_client", with_route >= lone - 4,
		"%d of %d routes arrived over the wire" % [with_route, lone])

	# And the aircraft are kept over the island rather than sent out to sea, because a leg
	# across open water is a leg spent somewhere nobody is looking.
	var offshore: int = 0
	var grid := BoxGrid.new(Terrain.boxes())
	for kind in [Sim.Kind.PLANE, Sim.Kind.HELI]:
		for waypoint in Terrain.waypoints(kind, grid):
			if maxf(absf(waypoint.x), absf(waypoint.z)) > Terrain.WORLD_HALF:
				offshore += 1
	_check("the_aircraft_are_routed_over_the_island", offshore == 0,
		"%d air waypoints fall outside the island" % offshore)

	# The aircraft are DRAWN much wider than they collide, which is the only way to have
	# both: a hull the size of a wingspan cannot thread a gate, and a hull the size of a
	# fuselage cannot be seen from two kilometres.
	for kind in [Sim.Kind.PLANE, Sim.Kind.HELI]:
		var shape: Dictionary = Sim.client.kind_geometry(kind)
		_check("a_%s_is_drawn_wider_than_it_collides" % shape.get("name", "?"),
			float(shape.get("span", 0.0)) > (shape.get("extents", Vector3.ONE)
				as Vector3).x * 3.0,
			"%.1f m across the wing, %.1f m of hull" % [float(shape.get("span", 0.0)) * 2.0,
				(shape.get("extents", Vector3.ONE) as Vector3).x * 2.0])

	_check("nothing_flew_into_the_scenery", buried == 0,
		"%d of %d are in the open" % [counted - buried, counted])
	_check("and_everything_is_still_in_its_own_medium", adrift.is_empty(),
		"%d of %d aircraft airborne, cars down, boats afloat (adrift: %s)" % [
			counted - adrift.size(), counted, _by_kind(adrift)])


## How far a follower is from the slot it is meant to be holding, worked out from the
## leader's CURRENT pose -- which is the only way to ask the question, because the slot is
## a place beside a moving machine rather than a place.
	# Reached the end of this section. See _finish.
	_sections["traffic"] = true
func _slot_error_split(leader: int, slot: Vector3, at: Vector3) -> Vector2:
	var lead: Dictionary = Sim.server.vehicle_state(leader)
	if lead.is_empty():
		return Vector2.ZERO
	var forward: Vector3 = (lead["basis"] as Quaternion) * Vector3(0.0, 0.0, -1.0)
	forward.y = 0.0
	if forward.length_squared() < 1e-6:
		return Vector2.ZERO
	forward = forward.normalized()
	var right := Vector3(-forward.z, 0.0, forward.x)
	var want: Vector3 = (lead["position"] as Vector3) + right * slot.x \
		+ Vector3(0.0, slot.y, 0.0) - forward * slot.z
	var gap: Vector3 = at - want
	# Split the flat error the way the guidance thinks about it: ACROSS the formation axis
	# is the intercept's job, ALONG it is the closing speed's. One number cannot say which
	# loop is the loose one.
	_crosstrack_total += absf(gap.dot(right))
	_along_total += absf(gap.dot(forward))
	return Vector2(Vector2(gap.x, gap.z).length(), absf(gap.y))


func _slot_error(leader: int, slot: Vector3, at: Vector3) -> float:
	var lead: Dictionary = Sim.server.vehicle_state(leader)
	if lead.is_empty():
		return 0.0
	var forward: Vector3 = (lead["basis"] as Quaternion) * Vector3(0.0, 0.0, -1.0)
	forward.y = 0.0
	if forward.length_squared() < 1e-6:
		return 0.0
	forward = forward.normalized()
	var right := Vector3(-forward.z, 0.0, forward.x)
	var want: Vector3 = (lead["position"] as Vector3) + right * slot.x \
		+ Vector3(0.0, slot.y, 0.0) - forward * slot.z
	return want.distance_to(at)


## A short summary of which kinds are in a list of [kind, position] pairs.
func _by_kind(rows: Array) -> String:
	var names: PackedStringArray = ["pod", "plane", "boat", "car", "heli"]
	var tally: Dictionary = {}
	for row in rows:
		var name: String = Sim.kind_name(int(row[0]))
		tally[name] = int(tally.get(name, 0)) + 1
	if tally.is_empty():
		return "none"
	var out: PackedStringArray = []
	for name in tally:
		out.append("%d %s" % [tally[name], name])
	if not rows.is_empty():
		# AND THE GROUND UNDER IT, since the island has mountains a car can be 50 m up and on the ground (2026-09-18).
		out.append("first at %v, the ground there %.1f m" % [rows[0][1] as Vector3, Terrain.ground_height(rows[0][1] as Vector3)])
	return ", ".join(out)


## THE TEST THIS PROJECT EXISTS TO PASS.
##
## Every box under a node, which is what a cockpit's structure is made of.
func _solids_under(node: Node) -> Array:
	var out: Array = []
	var mesh := node as MeshInstance3D
	if mesh != null and mesh.mesh is BoxMesh:
		out.append(mesh)
	for child in node.get_children():
		out.append_array(_solids_under(child))
	return out


## The first craft of a kind in the level, or null. Walked rather than asked for, because
## the level keeps its views to itself.
## A DRAWN CRAFT OF THIS KIND THAT THE RIG IS NOT SITTING IN.
##
## Manning a craft in a test puts controls in it, and manning it with `mine` of -1 says
## nobody at this machine is aboard -- which un-ghosts the airframe. Do that to the craft
## the player is actually inside and their cockpit fills with fuselage, which is exactly
## what `a_solid_airframe_is_taken_away_from_inside_it` is there to catch. So a test that
## wants a craft to poke at takes one nobody is in.
func _other_craft_of(not_this: VehicleView, wanted: int) -> VehicleView:
	for candidate in _level.find_children("*", "VehicleView", true, false):
		var found := candidate as VehicleView
		if found != not_this and found.kind == wanted:
			return found
	return null


func _find_kind(node: Node, wanted: int) -> VehicleView:
	var view := node as VehicleView
	if view != null and view.kind == wanted:
		return view
	for child in node.get_children():
		var found: VehicleView = _find_kind(child, wanted)
		if found != null:
			return found
	return null


## Fly hard, and watch the pilot's head and hands RELATIVE TO THE COCKPIT. Locked means
## they do not move at all -- not "move a little", which is what a second calculation of
## the same pose would give, and which is what the previous project could not get below.
func _test_smoothness(rig: PilotRig) -> void:
	if rig == null or not rig.is_seated():
		_check("smoothness", false, "not seated")
		return

	# Take the rig's hands off the wheel: it feeds a complete control frame every physics
	# frame, so anything set here would be overwritten before it was read.
	rig.set_physics_process(false)

	var vehicle: VehicleView = rig.get_parent().get_parent() as VehicleView
	if vehicle == null:
		_check("smoothness", false, "seat has no vehicle above it")
		rig.set_physics_process(true)
		return

	var started_at: Vector3 = vehicle.global_position
	# A hand held at a fixed seat-local pose while the vehicle is thrown around.
	var held := Vector3(0.22, -0.31, -0.42)
	var head_local: Array[Transform3D] = []
	var hand_local: Array[Transform3D] = []
	var world_steps: Array[float] = []
	var last_world: Vector3 = vehicle.global_position
	var fastest: float = 0.0

	# Watches the drawn pose from a node that processes AFTER the level, which is the only
	# place both it and the simulation's two states can be read at the same instant.
	var probe: Node = SEGMENT_PROBE.new()
	probe.entity = vehicle.entity
	probe.view = vehicle
	add_child(probe)

	# Get up to speed FIRST. Measuring from rest measures the throttle curve.
	probe.watching = false
	for i in range(150):
		Sim.set_input({"throttle": 1.0, "pitch": 0.1})
		await get_tree().physics_frame
		await get_tree().process_frame
	last_world = vehicle.global_position
	probe.watching = true

	for i in range(240):
		Sim.set_input({
			"throttle": 1.0,
			"pitch": 0.35,
			"roll": 0.6,
			"rudder": 0.2,
			"left": Vector3(-0.24, -0.33, -0.40),
			"right": held,
			"head": Vector3(0.0, 0.0, 0.0),
		})
		await get_tree().physics_frame
		await get_tree().process_frame
		# The rig's own hands, in the frame of the seat they are bolted to.
		hand_local.append(rig.origin.transform * rig.right_hand.transform)
		head_local.append(rig.origin.transform * rig.desktop_camera.transform)
		var now: Vector3 = vehicle.global_position
		world_steps.append(last_world.distance_to(now))
		last_world = now
		var speed: float = (Sim.current.get(vehicle.entity, {}).get(
			"velocity", Vector3.ZERO) as Vector3).length()
		fastest = maxf(fastest, speed)

	Sim.set_input({"throttle": 0.0, "pitch": 0.0, "roll": 0.0, "rudder": 0.0})
	rig.set_physics_process(true)

	_check("the_vehicle_really_moved",
		vehicle.global_position.distance_to(started_at) > 20.0 and fastest > 10.0,
		"travelled %.0f m, peak %.0f m/s" %
			[vehicle.global_position.distance_to(started_at), fastest])

	# THE measurement. Not a tolerance -- exactly zero, because the pose is not recomputed
	# from anything the vehicle is doing.
	var hand_wobble: float = 0.0
	var head_wobble: float = 0.0
	for i in range(hand_local.size()):
		hand_wobble = maxf(hand_wobble,
			hand_local[0].origin.distance_to(hand_local[i].origin))
		head_wobble = maxf(head_wobble,
			head_local[0].origin.distance_to(head_local[i].origin))
	_check("a_still_hand_never_moves_in_the_cockpit", hand_wobble == 0.0,
		"hand moved %.9f m in the seat at up to %.0f m/s" % [hand_wobble, fastest])
	_check("the_view_never_moves_in_the_cockpit", head_wobble == 0.0,
		"head moved %.9f m in the seat" % head_wobble)

	# And the cockpit has to move smoothly through the world, or none of the above helps.
	#
	# What is checked is that the drawn pose is ALWAYS A POINT ON THE SEGMENT between the
	# two states the simulation reported. That is the invariant smoothness rests on: a pose
	# on the segment cannot overshoot, cannot lag by more than one tick, and cannot jump --
	# and unlike a measurement of frame-to-frame motion it is true regardless of what the
	# aircraft was doing, including hitting a tower.
	#
	# Two earlier versions of this check measured the drawn motion directly and both were
	# wrong. Comparing largest step to smallest failed at a ratio of 8 while nothing was
	# juddering, because the aircraft was accelerating throughout. Measuring jerk failed
	# because a collision is a genuine step change. And neither could have been trusted
	# anyway: headless has no independent render clock, so the frame pacing this loop sees
	# is not the frame pacing a headset would.
	probe.watching = false
	_check("the_drawn_attitude_is_always_on_the_arc_between_two_simulated_ones",
		probe.worst_angle < 0.00001,
		"worst departure from the arc %.9f m of wingtip over %d drawn frames" %
			[probe.worst_angle, probe.frames])
	_check("the_drawn_pose_is_always_between_two_simulated_ones",
		probe.frames > 100 and probe.worst < 0.002,
		"worst departure from the segment %.6f m over %d drawn frames" %
			[probe.worst, probe.frames])

	# And the mechanism itself, directly. Headless has no independent render clock -- the
	# loop above steps physics and render together -- so a test of the real loop would
	# report perfect smoothness whatever the interpolation did. Walking the interval by
	# hand is what actually checks it.
	var points: Array[Vector3] = []
	var attitudes: Array[Quaternion] = []
	for i in range(9):
		var at: Transform3D = Sim.vehicle_transform(vehicle.entity, float(i) / 8.0)
		points.append(at.origin)
		attitudes.append(at.basis.get_rotation_quaternion())
	var gaps: Array[float] = []
	for i in range(8):
		gaps.append(points[i].distance_to(points[i + 1]))
	var smallest: float = gaps[0]
	var largest: float = gaps[0]
	for size in gaps:
		smallest = minf(smallest, size)
		largest = maxf(largest, size)
	_check("drawing_walks_the_tick_evenly",
		smallest > 0.0 and largest / smallest < 1.05,
		"eight slices of a tick range %.5f to %.5f m (ratio %.3f)" %
			[smallest, largest, largest / maxf(smallest, 1e-9)])

	# THE SAME TEST ON THE ATTITUDE, which had no coverage at all. An aeroplane's pitch
	# changes every tick and the whole world pivots around the pilot's head when it does,
	# so a rotation drawn in steps is far more obvious than a position drawn in steps --
	# and it was the half nothing was checking.
	# Measured as the chord a wingtip sweeps, NOT as Quaternion.angle_to: angle_to is acos
	# of a dot product that is almost exactly 1, and its noise floor is around 0.0006 rad,
	# which is larger than a whole tick of an aeroplane's pitch change. Measured with it,
	# a perfectly smooth rotation reads as seven slices of nothing and one of everything.
	var turns: Array[float] = []
	for i in range(8):
		turns.append(SEGMENT_PROBE._apart(attitudes[i], attitudes[i + 1]))
	var least: float = turns[0]
	var most: float = turns[0]
	for turn in turns:
		least = minf(least, turn)
		most = maxf(most, turn)
	_check("and_walks_the_attitude_evenly_too",
		least > 0.0 and most / least < 1.05,
		"eight slices of a tick turn %.9f to %.9f m of wingtip (ratio %.3f)" %
			[least, most, most / maxf(least, 1e-12)])


func _finish() -> void:
	# EVERY SECTION RAN. A GDScript error aborts the function it is in and carries on with
	# the next; the checks below it simply never happen, and a suite that only counts
	# FAILURES then reports a cheerful pass over a section that fell over. This is the
	# receipt, and it is checked last so it covers everything above it.
	var missing: PackedStringArray = []
	for section in EXPECTED_SECTIONS:
		if not _sections.has(section):
			missing.append(section)
	_check("every_section_of_the_suite_ran",
		missing.is_empty() and _sections.size() == EXPECTED_SECTIONS.size(),
		"%d of %d sections finished%s" % [_sections.size(), EXPECTED_SECTIONS.size(),
			"" if missing.is_empty() else "; missing " + ", ".join(missing)])
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)

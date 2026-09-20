extends RefCounted
class_name VehicleCatalogue
## EVERYTHING THE GAME KNOWS ABOUT A CRAFT THAT IS NOT PHYSICS, in one table.
##
## The simulation owns the numbers that make a craft move -- its shape, its handling, which
## channels its bus carries, how its autopilot flies it -- because those have to be the same
## on every peer and a rollback replays them. Everything else was scattered: which seat scene
## it uses lived in one dictionary, its colour in a `match`, whether it has a rotor or a wing
## in a chain of `if kind ==` inside the model builder, and which way its model faces in a
## third place again.
##
## Adding a craft therefore meant finding six files and remembering all of them. This is the
## one file: a kind gets an entry, and a kind WITHOUT an entry gets the light aeroplane's,
## which is a working craft rather than an error.
##
## What is NOT here is anything the simulation already knows. The hull size, the seat
## positions, the span, the mass, the fitted bus channels all come from `kind_geometry` and
## `craft_schema` at runtime, because a constant here and a matching constant in the C++
## agree until one of them changes -- and then the thing you can see is a different size
## from the thing you collide with, which is maddening precisely because it looks correct.

## How a craft's body is drawn. One of these, and they are about SHAPE rather than about
## physics: a tiltrotor and an aeroplane both have a wing, and the tiltrotor's happens to
## have engines on the ends of it that move.
enum Body {
	## A wing, a tailplane and a fin. Anything with a wing.
	WINGED,
	## The same, with the wing on TOP of the cabin and a strut down to each side. The
	## reason anybody learns to fly in a light aeroplane is that you can see the ground out
	## of both sides of one.
	HIGH_WING,
	## A concrete stalk with a glass cab on top. It is a building, and the only vehicle
	## here that cannot move.
	TOWER,
	## A hull with a FLIGHT DECK on top of it and an island off to one side. The deck is the
	## whole point: it is a third of a kilometre of runway that moves.
	CARRIER,
	## A hull with a superstructure amidships and turrets fore and aft.
	WARSHIP,
	## One rotor disc over the middle and a tail boom.
	ROTOR,
	## Two counter-rotating discs, one at each end, and a ramp at the back.
	TANDEM,
	## A wing with a proprotor on each tip that swings with the nacelles.
	TILTROTOR,
	## No wing, no rotor: a hull, a hall or a box on wheels.
	PLAIN,
	## A SHIP UNDER SAIL: a lofted hull, masts, yards that turn and sails that fill. See BrigRig.
	BRIG,
	## AN E-2D HAWKEYE, drawn whole by its own builder as the brig is: a high wing whose outer panels fold, two deep
	## nacelles, a rotodome and four fins. See HawkeyeAirframe.
	HAWKEYE,
	## A UH-60M-inspired utility helicopter, drawn whole by its own semantic builder.
	UH60,
	## AN F-4E PHANTOM II, drawn whole by `PhantomAirframe`: slats, flaps, ailerons, two all-moving stabilators, a
	## rudder, two canopies and two variable-area nozzles, all played from a VAT.
	PHANTOM,
	## AN F-14D TOMCAT, drawn whole by `TomcatAirframe`, its swing wing played from a VAT and swept from the bus.
	TOMCAT,
	## PORCO ROSSO'S FLYING BOAT, drawn whole by `SavoiaAirframe`, its ailerons, elevators, rudder and propeller from the
	## linkage as the Cessna's are.
	SAVOIA,
	## A SINGLE-SEAT F-16A, drawn whole by `FalconAirframe`, its flaperons, tailplanes and rudder from the stick.
	FALCON,
	## A FOUR-SEAT EA-6B, drawn whole by `ProwlerAirframe`, including its mission pods and VAT-driven surfaces.
	PROWLER,
	## AN MH-6M LITTLE BIRD, drawn whole by `LittleBirdAirframe` on `RotorcraftKit`: the open egg, doors off, and a bench
	## outboard each side.
	LITTLEBIRD,
	## AN AH-64D APACHE LONGBOW, drawn whole by `ApacheAirframe` on `RotorcraftKit`: the tandem canopy widened for two
	## players, the chin gun, the stub wings and the Longbow dome.
	APACHE,
	## A SCHEMPP-HIRTH DUO DISCUS, drawn whole by `SailplaneAirframe`: 20 m of wing turned up at the tips with winglets, a
	## T-tail, and two pilots in tandem under one bubble. Asked for on 2026-09-18 in place of the DG-1001 drawn by
	## `VehicleView._build_sailplane_airframe`.
	SAILPLANE,
	## AN F-35B, drawn whole by `LightningAirframe`: its nozzle and lift fan doors from the tilt channel, its gear eased
	## from the bus's bit, its surfaces from the stick, and all of them played from a VAT.
	LIGHTNING,
	## A BOEING JETLINER, drawn whole by a `JetlinerAirframe` from its measured table: the 737-800 for `airliner` and the
	## 747-400 for `jumbo`, the AC-130U for `gunship` (`HerculesAirframe`). Its
	## gear, flaps, spoilers and the stick's surfaces from the bus and the linkage. See `VehicleView.jetliner_for`.
	JETLINER,
	## AN A-10C, drawn whole by `WarthogAirframe`: its GAU-8's barrels turning while the drum empties, its gear eased
	## from the bus's bit, its decelerons split by the speed brake, its surfaces from the stick, all played from a VAT.
	WARTHOG,
	## A PISTON WARBIRD, drawn whole by its own class on `WarbirdAirframe`'s kit (`VehicleView.warbird_for`): the P-51D
	## first. Its gear eased from the bus's bit, its flaps from the lever, its surfaces from the stick and its propeller
	## turning while its engine runs, all played from a VAT.
	WARBIRD,
}

const SEATS := "res://objects/seats/"

## ONE ENTRY PER KIND. `seat` is the scene every crew position in this craft gets; `body` is
## how it is drawn; `paint` is what colour it is; `facing` turns the drawn model without
## touching the simulation -- see the note in VehicleView about why nothing uses it.
const CRAFT: Dictionary = {
	Sim.Kind.POD: {
		"seat": SEATS + "seat_plane.tscn", "body": Body.PLAIN,
		"paint": Color(0.36, 0.66, 0.92),
	},
	# A SEGWAY IS NOT DRAWN, which is the whole of its entry. It is the invisible vehicle a player
	# stands on to walk about a room (agents.md, "A SEGWAY IS HOW A PLAYER WALKS"), so there is no
	# hull, no paint and no `craft_segway.tscn` to open in the editor -- what anybody sees of it is
	# the pilot, which every craft already draws from the seat.
	#
	# IT NEEDS AN ENTRY ALL THE SAME. `of()` falls back to the light aeroplane's for a kind nobody
	# has described, so without this a segway would quietly be a white winged thing with an
	# aeroplane's seat in it.
	Sim.Kind.SEGWAY: {
		"seat": SEATS + "seat_plane.tscn", "body": Body.PLAIN,
		"paint": Color(1.0, 1.0, 1.0, 0.0),
		"drawn": false,
	},
	# A CESSNA 310R since 2026-09-19 (lane/twin310), drawn whole by `Cessna310Airframe` in place of
	# the generic "utility twin" blockout, which said in its own doc block that it "deliberately does
	# not claim to be one particular type". The kind, its four seats, its flight and its collision box
	# are unchanged; only the drawing moved. `craft/plane/sources.md` has the licences and the
	# measurements, and `craft/plane/measure_310l.py` re-derives every one of them from the drawing.
	Sim.Kind.PLANE: {
		"seat": SEATS + "seat_plane.tscn", "body": Body.WINGED,
		# THE SCREENS STAND ON THE INBOARD SIDE: the seats are at x +/-0.55 in a cabin lined at +/-0.59, so the flight display
		# and the rear pair's MFDs, at their usual offsets, had corners 0.08 to 0.30 m behind the lining. `screens_face` was red
		# on six of them from the 310R's landing (1e38258b) to 2026-09-20. See `CockpitStation.fit` and `_fit_the_mfds`.
		"screens_inboard": true,
		"paint": Color(0.88, 0.89, 0.92),
		"visual": {
			"scene": "res://objects/vehicles/cessna310_airframe.tscn",
			"units": "metres", "forward_axis": "-Z", "up_axis": "+Y",
			# THE PARKED BOX, not the aeroplane. A 310 stands 4.5 degrees nose-up, so a 9.74 m
			# aeroplane whose fin top is 3.5 m over its wheels needs 9.91 m of box to stand in.
			"dimensions_m": [11.23, 3.14, 9.91],
			"offset_m": [0.0, 0.0, 0.0], "rotation_deg": [0.0, 0.0, 0.0],
			# THE AIRFRAME'S OWN NUMBERS, rounded to a centimetre: the axles, the propeller hubs and
			# the tip tanks' middles. Typed here because a const cannot ask Cessna310Airframe.sockets();
			# tests/twin310.gd fails when the two part.
			"sockets": {
				"nose_gear": [0.0, -0.53, -3.86],
				"main_gear_port": [-1.83, -0.48, -0.94], "main_gear_starboard": [1.84, -0.48, -0.94],
				"propeller_port": [-1.86, 0.75, -3.97], "propeller_starboard": [1.86, 0.75, -3.97],
				"tip_tank_port": [-5.34, 0.81, -1.04], "tip_tank_starboard": [5.35, 0.81, -1.04]
			},
		},
	},
	# A BOEING 737-800W since 2026-09-19 (lane/liners), drawn whole by `Boeing737Airframe`.
	Sim.Kind.AIRLINER: {
		"seat": SEATS + "seat_airliner.tscn", "body": Body.JETLINER,
		# BLUE, and the only thing in the sky that is. It was within two hundredths of the
		# light aeroplane's white, which at any distance is the same aeroplane -- and the
		# two fly nothing alike, so telling them apart before you are in one is worth a
		# colour of its own.
		"paint": Color(0.16, 0.40, 0.86),
		## ONE THROTTLE BETWEEN THE FRONT SEATS, on the pedestal, belonging to the aircraft
		## rather than to either of them. Nothing else has one.
		"shared_throttle": true,
	},
	# A BOEING 747-400 since 2026-09-19 (lane/liners), drawn whole by `Boeing747Airframe`, in place of an E-6B Mercury
	# blockout. The kind keeps its name until the C++ step renames it; its stations are still the E-6B's four.
	Sim.Kind.JUMBO: {
		"seat": SEATS + "seat_airliner.tscn", "body": Body.JETLINER,
		"paint": Color(0.92, 0.93, 0.94),
		"shared_throttle": true,
	},
	# A tandem-seat carrier fighter. Its optional visual scene is declared by the immutable
	# craft package; this entry remains the procedural fallback when that resource is absent.
	Sim.Kind.FIGHTER: {
		"seat": SEATS + "seat_plane.tscn", "body": Body.WINGED, "chair": "mk14", "chair_headroom": 1.48,
		"paint": Color(0.64, 0.67, 0.69),
		"hung_stores": true,
		"visual": {
			"scene": "res://objects/vehicles/fighter_airframe.tscn",
			"units": "metres", "forward_axis": "-Z", "up_axis": "+Y",
			"dimensions_m": [13.68, 4.87, 18.50],
			"offset_m": [0.0, 0.0, 0.0], "rotation_deg": [0.0, 0.0, 0.0],
			# THE AIRFRAME'S OWN NUMBERS, rounded to a centimetre: the axles, the hook's pivot and the middle pylons.
			# Typed here because a const cannot ask FighterAirframe.sockets(); tests/fighter.gd fails when they part.
			"sockets": {
				"nose_gear": [0.0, -0.82, -3.32], "main_gear_port": [-1.555, -0.72, 3.12],
				"main_gear_starboard": [1.555, -0.72, 3.12], "arresting_hook": [0.0, 0.35, 6.61],
				"weapon_port": [-3.55, 0.55, 2.71], "weapon_starboard": [3.55, 0.55, 2.71]
			},
		},
	},
	# THE MV-22B: two pilots side by side "in crashworthy seats", each "an armored bucket seat" (GlobalSecurity, "V-22
	# Osprey cockpit"), so the helicopters' armoured crash seat under both; the crew chiefs' seats in the cabin keep none.
	# AND THE SAME HANDS IN BOTH SEATS: each pilot has the thrust control lever -- with the nacelles' thumbwheel -- under
	# his LEFT hand and a centre stick, as in a helicopter, so the right-hand seat is not the left one reflected. See
	# `same_hands`.
	Sim.Kind.OSPREY: {
		"seat": SEATS + "seat_osprey.tscn", "body": Body.TILTROTOR, "chairs": ["heli_armoured", "heli_armoured"],
		"same_hands": true,
		"paint": Color(0.34, 0.40, 0.33),
	},
	Sim.Kind.HELI: {
		"seat": SEATS + "seat_heli.tscn", "body": Body.ROTOR, "chairs": ["light", "light"],
		"paint": Color(0.85, 0.72, 0.30),
	},
	# A distinct utility helicopter at the Army's UH-60M public dimensions. Keeping this
	# separate preserves every level which already names the small legacy HELI.
	Sim.Kind.UH60: {
		"seat": SEATS + "seat_heli.tscn", "body": Body.UH60, "chairs": ["heli_armoured", "heli_armoured"],
		"paint": Color(0.20, 0.25, 0.18),
	},
	# A SWING-WING CARRIER FIGHTER, two crew in tandem. The fighter's seat scene, because the cockpits are the same kind
	# of room; the airframe and its sweep are `TomcatAirframe`'s.
	# A RACING FLYING BOAT WITH TWO GUNS, one seat. The fighter's seat scene, for its stick, throttle and master arm; the
	# airframe is `SavoiaAirframe`'s, and its paint is in its vertices.
	Sim.Kind.SAVOIA: {
		"seat": SEATS + "seat_plane.tscn", "body": Body.SAVOIA,
		"paint": Color(0.80, 0.09, 0.07),
	},
	# AN F-4E PHANTOM II, two crew in tandem. The Tomcat's seat scene, because the room is the same kind of room:
	# a two-seat fighter with the back seat stepped down behind a heavy canopy frame.
	Sim.Kind.PHANTOM: {
		"seat": SEATS + "seat_plane.tscn", "body": Body.PHANTOM, "chair": "mk14", "chair_headroom": 1.55,
		# NO `screens_inboard`, AND THAT WAS MEASURED RATHER THAN ASSUMED. It was set here first on the strength of the
		# 310R's note and taken out again: it moves the MFD pair OUT to 0.40 m across, and with it on, off, and the
		# seats moved, `screens_face` reported the same four screens hidden either way. The lateral offset is not what
		# is wrong -- see `todo/phantom--the-cockpit-has-no-opening.md`.
		# AND ITS OWN FOOTWELL, because the shared one's firewall bar is 0.70 m across and an F-4's tub is not. Four of
		# the bar's eight corners stood outside the fuselage, worst 0.35 m out and 2.51 m up at station 4.33 -- through
		# the decking ahead of the windscreen. `shell_room` named the piece, which is what its slab names are for.
		"footwell": {"raise": 0.12, "floor_width": 0.32, "bar_width": 0.26},
		# AND THE MAP GLASS SITS LOW. The shared station stands it at x 0.38, which is outboard of an F-4's canopy at
		# the deck, so its starboard corners poked through the glass. The canopy is not wrong -- a Phantom's really is
		# that narrow -- and the tub below the deck is wider, so the glass goes down into it rather than out through it.
		"map_screen_height": 1.02,
		"paint": Color(0.36, 0.38, 0.40),
		# THE PYLONS THE AIRFRAME DOES NOT DRAW: the wing Sidewinders' rails 0.22 m up to the wing's underside, and
		# the fuselage Sparrows' recesses 0.14 m up into the belly, which is what a recessed missile hangs from.
		"hung_stores": true,
		"store_pylons": {0: 0.22, 1: 0.22, 2: 0.14, 3: 0.14},
	},
	Sim.Kind.TOMCAT: {
		"seat": SEATS + "seat_plane.tscn", "body": Body.TOMCAT, "chair": "mk14", "chair_headroom": 1.55,
		"paint": Color(0.52, 0.55, 0.58),
		# THE GLOVE PYLONS, which the airframe does not draw: the Sidewinder's shoulder rail 0.24 m and the Sparrow's
		# pylon 0.36 m up to the glove's underside (0.90 m over the ground).
		"hung_stores": true,
		"store_pylons": {0: 0.24, 1: 0.24, 2: 0.36, 3: 0.36},
	},
	# A SINGLE-SEAT FIGHTER. The fighter's seat scene, because the cockpit is the same kind of room; the airframe is
	# `FalconAirframe`'s.
	Sim.Kind.FALCON: {
		"seat": SEATS + "seat_plane.tscn", "body": Body.FALCON, "chair": "aces2_f16", "chair_headroom": 1.43,
		"paint": Color(0.52, 0.55, 0.57),
		# ITS MISSILES DRAWN ON ITS RAILS (`HungStores`), as on the other two jets: lane/jetarms, 2026-09-18. The AMRAAMs on
		# stations 2 and 8 hang from pylons the airframe does not draw, 0.20 m up to the wing's underside.
		"hung_stores": true,
		"store_pylons": {2: 0.20, 3: 0.20},
	},
	# THE F-35B: a single seat with a SIDE STICK on the right and the throttle on the left, as an F-35's (and an F-16's)
	# are; the NOZZLE LEVER beside the throttle, the Osprey's `TiltLever` on the tilt channel; and the flight page on ONE
	# WIDE SCREEN, the F-35's 20 x 8 in panoramic cockpit display. A Martin-Baker US16E under the pilot (`PilotSeat`'s
	# "us16e"). The canopy's top is 0.47 m over the eye, so the chair is cut down to it.
	Sim.Kind.LIGHTNING: {
		"seat": SEATS + "seat_lightning.tscn", "body": Body.LIGHTNING, "chair": "us16e", "chair_headroom": 1.72,
		"paint": Color(0.40, 0.42, 0.44),
		# ITS MISSILES DRAWN WHERE THEY HANG (`HungStores`): the AIM-9Xs on pylons 0.28 m up to the wing's underside, the
		# AMRAAMs inside the bays on 0.18 m racks up to the bay's roof -- hidden behind the shut doors, seen when they open.
		"hung_stores": true,
		"store_pylons": {0: 0.28, 1: 0.28, 2: 0.18, 3: 0.18},
	},
	# THE A-10C: a single seat with a CENTRE STICK and the throttle on the left, the fighter's seat scene with a SPEED BRAKE
	# handle beside the throttle (the real one is a thumb switch on it; a desk and a hand need something to take hold of),
	# the flaps and gear levers on the console the view fits for their channels, and the GAU-8 on the stick's trigger
	# through the lock sight the station fits for a loadout. An ACES II under the pilot with
	# its side handles, `PilotSeat`'s "aces2" (the A-10 is one of the aircraft [WA2] names with side handles). The bubble's
	# top is 0.32 m over the eye, 1.67 m over the seat's anchor on the centreline, but the glass falls away aft and to the
	# sides, and at 1.62 the headbox stood 19 vertices out through it 0.44 m behind the anchor (tests/pilot_seat.gd); 1.45.
	# THE P-51D: one seat under the bubble, a centre stick with the six .50s on its trigger through the lock sight the
	# station fits for a loadout, the throttle on the left, and the flaps and gear levers the console fits for their channels.
	# No ejection seat: a 1944 fighter's armour-plated bucket, the light chair (`PilotSeat`'s "light"). The bubble's top is
	# 0.24 m over the eye (`P51Airframe.EYE`), so the chair is cut down to 1.45 m, as the A-10's under its bubble.
	Sim.Kind.P51: {
		"seat": SEATS + "seat_p51.tscn", "body": Body.WARBIRD, "chair": "light", "chair_headroom": 1.45,
		"paint": Color(0.70, 0.72, 0.74),
	},
	# THE P-47D-30: the Mustang's station with EIGHT .50s on the stick's trigger instead of six, and a roomier
	# cockpit -- the bubble's top is 0.27 m over the eye (`P47Airframe.EYE`), so the light chair keeps the same 1.45 m.
	Sim.Kind.P47: {
		"seat": SEATS + "seat_p47.tscn", "body": Body.WARBIRD, "chair": "light", "chair_headroom": 1.45,
		"paint": Color(0.70, 0.72, 0.74),
	},
	Sim.Kind.WARTHOG: {
		"seat": SEATS + "seat_warthog.tscn", "body": Body.WARTHOG, "chair": "aces2", "chair_headroom": 1.45,
		"paint": Color(0.36, 0.38, 0.39),
	},
	# A PROWLER WITH TWO GAME-FLYING FRONT STATIONS and two EW-only rear stations. The dedicated scene's two MFDs
	# are retained for Operators while CockpitStation.fit removes their throttle, stick and rudder. The real front-right
	# station was ECMO-1; the Copilot role is the requested dual-control concession.
	Sim.Kind.PROWLER: {
		"seat": SEATS + "seat_prowler.tscn", "body": Body.PROWLER,
		"paint": Color(0.56, 0.57, 0.58),
	},
	# THE MH-6M LITTLE BIRD: the light helicopter's seat scene, since the cabin is the same kind of room; black, as the
	# 160th's are.
	# ITS OWN SEAT SCENE, because the light helicopter's stood the crew board and the flight display across the lower
	# windscreen that is this craft's whole point; they are down on the console here (`seat_littlebird.tscn`). AND ITS
	# OWN FOOTWELL: the egg is 0.28 to 0.35 m wide each side at the standard footwell's height, so the floor under each
	# pilot is lifted 0.20 m to the doors' sills and drawn 0.36 m across, and the bar 0.40: at 0.50 its ends stood in
	# the front door's opening, and `shell_room` saw them there (`CockpitShell.fit_footwell`).
	Sim.Kind.LITTLEBIRD: {
		"seat": SEATS + "seat_littlebird.tscn", "body": Body.LITTLEBIRD, "chair": "light",
		"paint": Color(0.17, 0.18, 0.19),
		"footwell": {"raise": 0.20, "floor_width": 0.36, "bar_width": 0.40},
	},
	# THE AH-64D APACHE: two crew in tandem; US Army olive drab. ITS OWN SEAT SCENE, the Little Bird's layout: the light
	# helicopter's stood the display and the crew board 0.21 m under the gunner's eye, across the view down over the nose
	# that the front seat exists for (`cockpit-station-apache-seat1`, 2026-09-18); here they lie low between the knees, 54
	# degrees under the eye, and the map with them (`seat_apache.tscn`).
	Sim.Kind.APACHE: {
		"seat": SEATS + "seat_apache.tscn", "body": Body.APACHE, "chair": "heli_armoured",
		"paint": Color(0.27, 0.29, 0.22),
	},
	Sim.Kind.CHINOOK: {
		"seat": SEATS + "seat_heli.tscn", "body": Body.TANDEM, "chairs": ["heli_armoured", "heli_armoured"],
		"paint": Color(0.28, 0.35, 0.29),
	},
	Sim.Kind.CAR: {
		"seat": SEATS + "seat_wheel.tscn", "body": Body.PLAIN,
		"paint": Color(0.82, 0.30, 0.28),
	},
	Sim.Kind.BOAT: {
		"seat": SEATS + "seat_wheel.tscn", "body": Body.PLAIN,
		"paint": Color(0.32, 0.66, 0.48),
		# AN OPEN HELM: a launch is driven standing at a centre console under a T-top, not from
		# behind glass. See `helm`.
		"helm": "open",
	},
	Sim.Kind.GUNBOAT: {
		"seat": SEATS + "seat_wheel.tscn", "body": Body.PLAIN,
		# Haze grey, which is what a patrol boat is and nothing else in the water is.
		"paint": Color(0.42, 0.46, 0.50),
	},
	# A CB90: a glazed wheelhouse, and Swedish olive. Drawn by `CombatBoat` from its parts (`ShipHull`).
	Sim.Kind.CB90: {
		"seat": SEATS + "seat_wheel.tscn", "body": Body.PLAIN,
		"paint": Color(0.31, 0.35, 0.28),
	},
	# A FIREBOAT, steered from a wheelhouse like every other boat here. Her paint is the fire-service red the whole
	# fleet wears, and it is the one thing anybody names her by (lane/fireboat, 2026-09-19).
	Sim.Kind.FIREBOAT: {
		"seat": SEATS + "seat_wheel.tscn", "body": Body.PLAIN,
		"paint": Color(0.55, 0.09, 0.09),
		# THE MAP GLASS ON THE CHART SHELF, 1.12 m over the floor: the helm sits 0.60 m from the front glass, so at the
		# standard 0.84 it was under the shelf (`_fit_the_map_screen`).
		# NOT CHECKED AGAINST A PHOTOGRAPH, and there is none to check: `craft/fireboat/sources.md` has no interior view.
		# The shelf is `Wheelhouse.build`'s generic chart shelf, fitted to every glazed boat and not a part of hers, so this
		# key answers "the screen sat under a shelf" and not "the boat has one". If a photograph shows a bare sill, the
		# fix is to drop the shelf for her and delete this line.
		"map_screen_height": 1.12,
	},
	Sim.Kind.TRAIN: {
		"seat": SEATS + "seat_train.tscn", "body": Body.PLAIN,
		"paint": Color(0.62, 0.24, 0.20),
	},
	Sim.Kind.CESSNA: {
		"seat": SEATS + "seat_cessna.tscn", "body": Body.HIGH_WING,
		# White over blue, which is what most of them are.
		"paint": Color(0.90, 0.91, 0.93),
		# ONE PLUNGER in the middle of the panel, which both pilots can reach. The second
		# craft in the game with a shared control and the only one where it is a knob.
		"shared_throttle": true,
		"plunger": true,
		# THE 172S AIRFRAME, drawn through the package's visual boundary; this entry stays the procedural fallback when that
		# resource is absent. Span over the strobes, height to the beacon as measured (Textron's 2.72 m is a maximum nothing
		# reproduces: craft/cessna/sources.md), length spinner to fin cap.
		"visual": {
			"scene": "res://objects/vehicles/skyhawk_airframe.tscn",
			"units": "metres", "forward_axis": "-Z", "up_axis": "+Y",
			"dimensions_m": [11.0, 2.36, 8.28],
			"offset_m": [0.0, 0.0, 0.0], "rotation_deg": [0.0, 0.0, 0.0],
			# THE AIRFRAME'S OWN NUMBERS, rounded to a centimetre: the axles, the propeller's hub and the struts' heads.
			# Typed here because a const cannot ask SkyhawkAirframe.sockets(); tests/skyhawk.gd fails when they part.
			"sockets": {
				"nose_gear": [0.0, -0.67, -3.04], "main_gear_port": [-1.28, -0.63, -1.39],
				"main_gear_starboard": [1.28, -0.63, -1.39], "propeller": [0.0, 0.42, -3.89],
				"wing_strut_port": [-2.49, 1.07, -1.96], "wing_strut_starboard": [2.49, 1.07, -1.96]
			},
		},
	},
	Sim.Kind.TOWER: {
		"seat": SEATS + "seat_tower.tscn", "body": Body.TOWER,
		"paint": Color(0.72, 0.72, 0.70),
	},
	Sim.Kind.CARRIER: {
		# A ship is conned from a wheel, and everything on this one is steered the same way
		# whether it is the bridge or a lookout position.
		"seat": SEATS + "seat_wheel.tscn", "body": Body.CARRIER,
		# Deck grey, and darker than the gunboat so the two do not read as the same ship at
		# eight kilometres.
		"paint": Color(0.30, 0.33, 0.36),
	},
	Sim.Kind.BATTLESHIP: {
		"seat": SEATS + "seat_wheel.tscn", "body": Body.WARSHIP,
		"paint": Color(0.36, 0.39, 0.42),
	},
	# A TURRET AND A BARREL ON A BOX. The body is PLAIN because the hull IS what the
	# simulation collides with -- see the note on `tank_shape` about the gun being drawn
	# rather than collided with -- and the barrel hangs off the mount like a warship's.
	# A TRANSPORT AEROPLANE WITH THE GUNS IN THE SIDE. Drawn as a wing and a fuselage like
	# any other aeroplane -- what makes it a gunship is what is bolted inside it, and every
	# one of those is a mount the turret code already draws.
	Sim.Kind.GUNSHIP: {
		"seat": SEATS + "seat_airliner.tscn", "body": Body.JETLINER,
		"paint": Color(0.22, 0.24, 0.22),
	},
	# THE C-130H TRANSPORT (lane/liners, 2026-09-19): the gunship's airframe (`HerculesAirframe`, `armed` false) with a
	# ramp and no guns, in the lighter grey of a transport that is not trying to hide at night.
	Sim.Kind.TRANSPORT: {
		"seat": SEATS + "seat_airliner.tscn", "body": Body.JETLINER,
		"paint": Color(0.56, 0.59, 0.61),
	},
	# A WATER BOMBER, in the colour every one of them is painted. A fire crew has to be
	# able to find their own aeroplane against a hillside full of smoke, so real tankers are
	# not subtle about it and neither is this one.
	Sim.Kind.TANKER: {
		"seat": SEATS + "seat_tanker.tscn", "body": Body.WINGED,
		"paint": Color(0.94, 0.42, 0.12),
	},
	# A GLIDER: twenty metres of wing, no engine, and white because every one of them is.
	# A glider is painted white for the same reason it has a long wing -- both are about
	# not wasting anything, in this case the sun's heat on the airframe.
	Sim.Kind.GLIDER: {
		"seat": SEATS + "seat_glider.tscn", "body": Body.SAILPLANE,
		# A RECLINED CREW (`CockpitShell.reclined`): the pod's floor is 0.70 m over each seat's anchor, which is 0.6 m under
		# the belly because the eye is 1.35 m over it and under the glass. Narrow, because the Duo's pod is 0.2 m across
		# at the front seat's footwell; and the bar the narrowest there is, 0.20 m, so it runs between the two screens
		# either side of the view over the nose rather than through them (`cockpit-sailplane-13`, 2026-09-19).
		"footwell": {"raise": 0.70, "floor_width": 0.30, "bar_width": 0.20, "reclined": true},
		"paint": Color(0.95, 0.95, 0.97),
	},
	Sim.Kind.TANK: {
		"seat": SEATS + "seat_tank.tscn", "body": Body.PLAIN,
		"paint": Color(0.31, 0.34, 0.24),
	},
	# A PIRATE SHIP: a brig, in tarred black-brown. No player may board one yet, so the seat is a
	# wheel nobody stands at; whether it may be boarded is the SIMULATION's to say (`pilotable`).
	Sim.Kind.PIRATE: {
		"seat": SEATS + "seat_wheel.tscn", "body": Body.BRIG,
		"paint": Color(0.20, 0.15, 0.11),
	},
	# AN E-2D HAWKEYE: yokes and one set of power levers on the pedestal between the pilots (two Navy E-2C cockpit
	# photographs; the pedestal from a C-2A's; the E-2D's own levers are not found). Overall Light Gull Gray.
	Sim.Kind.HAWKEYE: {
		"seat": SEATS + "seat_airliner.tscn", "body": Body.HAWKEYE, "paint": Color(0.70, 0.70, 0.67),
		"shared_throttle": true,
	},
	# A VIRGINIA-CLASS SUBMARINE, surfaced: conned from a well in the top of its sail, with nothing round the watch but a
	# rail rigged on the surface. Matte black, as the anechoic coating is.
	Sim.Kind.SUBMARINE: {
		"seat": SEATS + "seat_wheel.tscn", "body": Body.PLAIN, "paint": Color(0.055, 0.058, 0.062), "helm": "well",
	},
}

## The kinds a player may be put in, in `Sim.Kind` order: worked out once and kept.
static var _pilotable: Array[int] = []

## THE GROUPS THE CRAFT PAGE SORTS KINDS INTO, in the order its bar shows them (lane/kinds, 2026-09-18: "i'd like to have
## lots of vehicle kinds"). Twenty-eight buttons in one grid was already most of the board; sixty would not fit. A
## group is chosen by HOW A KIND MOVES -- the movement model the simulation declares for it -- because that is the
## question a player picking a craft is asking first ("a helicopter"), and because a model is the simulation's to say:
## nothing here names a kind, so a kind added in the C++ lands in its group with no edit to this file.
const GROUPS: Array[String] = ["aeroplanes", "helicopters", "ships", "ground"]
## Which group each movement model's name (`kind_geometry`'s `model_name`) goes in. A tilt-rotor lifts off like a
## helicopter; a sailing ship is a ship; the hovering pod, the segway and the tower stand on the ground with the cars.
## A model missing here goes in the last group, and tests/craft_page.gd fails if one ever does.
const GROUP_OF_MODEL: Dictionary = {
	"airplane": "aeroplanes", "helicopter": "helicopters", "tiltrotor": "helicopters", "boat": "ships", "sail": "ships",
	"car": "ground", "train": "ground", "segway": "ground", "hover": "ground", "fixed": "ground",
}


## THE CRAFT PAGE'S GROUP FOR A KIND, from the movement model the simulation says it has.
static func group(kind: int) -> String:
	return String(GROUP_OF_MODEL.get(String(Sim.geometry_of(kind).get("model_name", "")), GROUPS.back()))


## EVERY KIND A PLAYER MAY BE PUT IN, as the CRAFT page is handed them: `{kind, name, group}` each, in `Sim.Kind` order.
static func craft_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for kind in pilotable_kinds():
		rows.append({"kind": kind, "name": Sim.kind_name(kind), "group": group(kind)})
	return rows


## THE CRAFT TO OFFER ON A LEVEL, asked whether it has a sea (`Terrain.has_sea`; lane/testfield, 2026-09-19): on one with
## none, the SHIPS group is left out -- a carrier, a battleship, a submarine or a boat chosen on dry land sits on a field
## and goes nowhere -- and the page says why in NO_SEA_NOTE. Asked of the group, not of a list of kinds: the next ship
## added is a ship, and goes with them. A flying boat is an aeroplane and stays; it is the one craft on the page that
## needs water it may not find, and the test field's lakes are its only water.
const NO_SEA_NOTE: String = "No ships on this level: it has no sea."


static func craft_rows_for(sea: bool, only: Array[int] = []) -> Array[Dictionary]:
	var rows: Array[Dictionary] = craft_rows()
	# AND ONLY THE KINDS A LEVEL NAMES, when it names any (`LevelChart.craft`; lane/gliderlevel, 2026-09-19).
	if not only.is_empty():
		rows = rows.filter(func(row: Dictionary) -> bool: return only.has(int(row["kind"])))
	if sea:
		return rows
	return rows.filter(func(row: Dictionary) -> bool: return String(row["group"]) != "ships")


## WHAT THE CRAFT PAGE SAYS UNDER ITS ROWS on a level: why a level offering only some craft offers those, in its own words
## ("Only the glider on this level: it is for soaring."), or why a level with no sea has no ships, or nothing.
static func craft_note(sea: bool, only: Array[int], why: String) -> String:
	if not only.is_empty():
		var names: PackedStringArray = []
		for kind in only:
			names.append(Sim.kind_name(kind).to_lower())
		return "Only the %s on this level: %s." % [" and the ".join(names), why]
	return "" if sea else NO_SEA_NOTE


## WHETHER A PLAYER MAY BE PUT IN ONE OF THESE, asked of the simulation's shape table.
##
## NOT A KEY IN `CRAFT`, though every other fact about a craft that is not physics is. The
## server is what refuses a boarding and the server cannot read this file, so a flag here would
## be a second copy of the one that decides: a CRAFT page offering what the host refuses, the day
## one of them is edited. The page, the keys and the help ask this, and this asks the simulation.
## A library too old to say answers true, which is what every craft was before there was a flag.
static func pilotable(kind: int) -> bool:
	return bool(Sim.geometry_of(kind).get("pilotable", true))


## EVERY KIND A PLAYER MAY BE PUT IN, for anything that lists craft to choose from. Kept after the
## first ask, because the rig walks it every frame and the shape table does not change in a run.
static func pilotable_kinds() -> Array[int]:
	if _pilotable.is_empty():
		for kind in range(Sim.Kind.size()):
			if pilotable(kind):
				_pilotable.append(kind)
	return _pilotable


## HOW A SHIP'S HELM IS BUILT: "glazed", a wheelhouse or a bridge behind windows, "open", a
## console under a T-top, or "well", a watch standing in a well cut into a submarine's sail. Presentation, so it lives here beside the paint; WHERE the helm is comes
## from the simulation's `bridge` part, and a seat is placed on its floor. A ship with no entry is
## conned from behind glass, which is what nearly every ship is.
static func helm(kind: int) -> String:
	return String(of(kind).get("helm", "glazed"))


## One craft's entry, or the light aeroplane's. A kind nobody has described yet is a
## flyable aeroplane in the wrong colour, which is a better place to start from than a
## crash.
## HOW A HULL IS GLAZED, per body style rather than per kind.
##
## Presentation, so it lives here beside the paint rather than in the simulation's shape
## table. The shape table stays the authority on how big a craft is and where its seats
## are; nothing here touches what you collide with.
##
## A style that is ABSENT is not glazed, and gets the old single box. That is what lets this
## arrive one aircraft at a time instead of all fourteen at once, with the world flyable at
## every step.
##
##   sides       how many openings run down each side of the cabin. There is always one more
##               POST than there are openings, so the run begins and ends with structure.
##   post        how thick a post is, in metres. Thin enough to see past, thick enough to
##               read as a frame -- which is what tells you you are inside an aeroplane
##               rather than looking at a hole.
##   sill        structure below the glazing, at the shoulder.
##   header      structure above it, carrying the roof.
##   roof_open   no roof over the cabin at all. A helicopter has one, because looking up
##               through it at the disc is most of what flying one looks like.
const GLAZING: Dictionary = {
	# A light aeroplane: a long cabin with three windows a side.
	#
	# THE LIGHT TWIN KEEPS ITS ROW THOUGH IT DRAWS ITS OWN CABIN, and this is what that row is
	# really for. `VehicleView._show_body` reads it as **"do not take this craft away from the
	# person sitting in it"**: a solid fuselage is a wall between a pilot's eye and the horizon, so
	# an unglazed craft is hidden from inside, and a GLAZED one is kept because the windows were cut
	# for exactly that. `lane/twin310` took this row out on `lane/liners`' precedent -- an airliner
	# whose flight deck it draws itself has no business with a generic skin -- and made a 310R
	# invisible to its own pilot. The two cases differ: the 737's row also put a skin round its
	# cabin pair that `smoke` found them sitting inside, and the twin's does not, because the
	# generic skin under a visual scene is hidden either way (`_show_body`, "UNDER A VISUAL SCENE").
	Sim.Kind.PLANE: {"sides": 3, "post": 0.13, "sill": 0.16, "header": 0.13},
	# A HIGH WING is the reason anybody learns to fly in one of these: you can see the
	# ground out of both sides. Fewer, wider openings and thinner posts to say so.
	Sim.Kind.CESSNA: {"sides": 2, "post": 0.11, "sill": 0.14, "header": 0.12},
	# A FLIGHT DECK. Fewer, larger panes than a light aeroplane and heavier posts between
	# them, which is what a transport windscreen looks like: five big panels wrapped round
	# the nose, and the pillar you can see is beside your shoulder.
	#
	# The cabin behind it is narrower than the fuselage -- see VehicleView._greenhouse --
	# so the hull steps out to full width behind the crew. That taper is the difference
	# between a flight deck and a shed with a windscreen in it.
	# NO AIRLINER AND NO JUMBO SINCE lane/liners' C++ step (2026-09-19): the 737 and the 747 draw their own glazed flight
	# decks round the crew (`JetlinerAirframe`), and a generic skin built from the old boxes' seats stood, invisible, round
	# the 737's cabin pair -- `smoke` found them sitting inside its wall.
	Sim.Kind.FIGHTER: {"sides": 2, "post": 0.10, "sill": 0.12, "header": 0.10},
	# The V-22 has a high wing above a short, two-seat flight deck.  The cargo cabin has
	# windows too, but it must not become a glass tube: three broad openings make the deck
	# and the first crew-chief row readable from outside while leaving a strong rear ramp.
	Sim.Kind.OSPREY: {"sides": 3, "post": 0.16, "sill": 0.20, "header": 0.18},
	# The Chinook gets its dedicated rotors, sponsons and ramp in VehicleView. Its cabin
	# glazing stays out of this generic skin table until each crew seat clears the visibility
	# audit: the first four-opening attempt blocked the ramp and troop-seat sight lines.
}


## The glazing schedule for this kind, or {} for a kind that is still drawn as one box.
##
## BY KIND, not by body style, and that is a decision a measurement forced. The airliner
## shares the WINGED style with the light aeroplane, so keying this by style glazed it too --
## and its "flight deck" is the full 5.2 m width of the fuselage, which puts the side sill
## two metres from the pilot's shoulder. From there you can see about eight degrees below
## the horizon and no ground at all. A real flight deck is narrow because the nose of a real
## fuselage TAPERS, and until that is modelled the airliner is better as one honest box than
## as a cabin with windows nobody can see out of.
##
## Which is the staging this was meant to have: a kind arrives when its shape has been
## thought about, and the world stays flyable in between.
static func glazing(kind: int) -> Dictionary:
	return GLAZING.get(kind, {})


static func of(kind: int) -> Dictionary:
	return CRAFT.get(kind, CRAFT[Sim.Kind.PLANE])


## WHETHER BOTH PILOTS' HANDS DO THE SAME THINGS, so the right-hand seat of a pair is laid out as the left one rather
## than reflected: a craft whose entry says "same_hands". The rule it is an exception to is `VehicleView`'s
## `_is_the_right_hand_seat` -- an aeroplane's two throttles meet in the middle, so the right seat's is on its left -- and
## a V-22's thrust control levers do not: each pilot's is under his left hand, as a helicopter's collective is.
static func same_hands(kind: int) -> bool:
	return bool((CRAFT.get(kind, {}) as Dictionary).get("same_hands", false))


## THE CHAIR UNDER EACH SEAT, as `PilotSeat` preset names, one per seat pose; "" where a seat has none. A kind names
## "chair" (every seat) or "chairs" (a list by seat index, and a seat past its end has none) in its entry; a kind that
## names neither draws no chair, as every craft did before 2026-09-18. See `PilotSeat`. THE HELICOPTERS NAME ONLY THEIR
## PILOTS: a UH-60's door gunners, a Chinook's cabin and ramp and a light helicopter's rear pair keep the canvas seats
## `RotorcraftKit.crew_seats` draws (team-lead, 2026-09-18: "leave the troop and cabin seats alone").
static func chairs(kind: int, seats: int) -> PackedStringArray:
	var entry: Dictionary = CRAFT.get(kind, {})
	var named: PackedStringArray = []
	for index in range(seats):
		if entry.has("chairs"):
			var listed: Array = entry["chairs"] as Array
			named.append(String(listed[index]) if index < listed.size() else "")
		else:
			named.append(String(entry.get("chair", "")))
	return named


## WHAT THE CRAFT TELLS ITS CHAIRS: its "chair_headroom", the height over a seat anchor its canopy leaves, so a headbox
## is cut down under the glass; and the floor they stand on, lifted by the craft's own "footwell" raise where it has
## one, so the chair stands where the station's floor does. Held by `tests/pilot_seat.gd` against the drawn skin.
static func chair_overrides(kind: int) -> Dictionary:
	var entry: Dictionary = CRAFT.get(kind, {})
	var told: Dictionary = {}
	if entry.has("chair_headroom"):
		told["headroom"] = float(entry["chair_headroom"])
	if entry.has("footwell"):
		told["floor"] = CockpitStation.FLOOR + float((entry["footwell"] as Dictionary).get("raise", 0.0))
	return told


static func seat_scene(kind: int) -> PackedScene:
	return load(String(of(kind).get("seat", SEATS + "seat_plane.tscn"))) as PackedScene


## DEVICES THE CHECKED-IN REVISION PERMITS A BUILDER TO PLACE.  Runtime stations still
## come from scenes during the migration; this read-only API lets package validation use
## the authored allowlist now and gives the BUILD page one stable seam for the next slice.
## A missing or malformed revision keeps the legacy complete bin, explicitly, so an old
## checkout never strands a player without controls.
static func allowed(kind: int) -> Array[StringName]:
	var fallback: Array[StringName] = []
	fallback.assign(ControlCatalogue.PARTS)
	var result := AuthoredCraftPackages.allowed(kind)
	return result if not result.is_empty() else fallback


## WHETHER A KIND IS DRAWN AT ALL, and so whether it has a craft scene to open in the editor.
##
## True of everything but the segway. A `craft_*.tscn` is an EDITOR PREVIEW -- the running game builds
## a `VehicleView` from the kind (`FlightLevel._view_for`) and never loads one -- so a vehicle with
## nothing to look at rightly has no file. Said here, once, rather than as an exception inside the
## suite that walks them: `tests/smoke.gd` skips an undrawn kind AND holds that it has no scene, so
## the rule cannot rot in either direction.
static func is_drawn(kind: int) -> bool:
	return bool(of(kind).get("drawn", true))


static func body(kind: int) -> Body:
	return of(kind).get("body", Body.PLAIN) as Body


static func paint(kind: int) -> Color:
	return of(kind).get("paint", Color.WHITE) as Color


## Whether this craft's crew share one throttle rather than each having their own.
static func shares_a_throttle(kind: int) -> bool:
	return bool(of(kind).get("shared_throttle", false))


## And whether that shared throttle is a PLUNGER through the panel rather than a lever on a
## quadrant. A light aeroplane's is; an airliner's is not.
static func has_a_plunger(kind: int) -> bool:
	return bool(of(kind).get("plunger", false))


## WHICH WAY ROUND THE DRAWN MODEL SITS, in radians about the vertical.
##
## Nothing uses it, and the mechanism is kept because the reason is worth remembering:
## turning a drawn model puts the nose against the direction of travel, so the aeroplane is
## then genuinely drawn flying tail-first. There is no orientation of a drawn model that
## makes a turned aeroplane go forwards -- the only self-consistent flip turns the model,
## the seats and the thrust together, which is a relabelling nobody can see.
static func facing(kind: int) -> float:
	return float(of(kind).get("facing", 0.0))

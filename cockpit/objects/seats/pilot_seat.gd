extends RefCounted
class_name PilotSeat
## THE CHAIR A PILOT SITS IN: one parametrised, faceted, low-poly seat, and a preset for each kind of seat the fleet
## flies from -- an ACES II ejection seat, a Martin-Baker Mk 14, a helicopter's armoured crash seat, a light aeroplane's
## seat on its rails and an airliner's. Asked for on 2026-09-18: "model a pilot seat, just the seat part, no arm rests
## (because pilot chairs don't have those), there should be some configurable parts, because the f16 is reclined a bit,
## and helicopter seats are very upright".
##
## THE CHAIR IS FITTED TO THE PLAYER, NEVER THE PLAYER TO THE CHAIR. Everything is built in the SEAT ANCHOR's own
## frame (-Z forward, +Y up, origin the play-space floor), round the eye `CockpitStation.EYE_HEIGHT` over it, which is
## where the rig puts a real head whatever a chair says. The chair is SOLVED from that eye: the back's face is a plane
## `head_gap` behind the eye, leaning back by `recline`, and the pan's rear edge is where that plane comes down to
## `pan_height`. So a reclined seat puts its hips forward and its headbox behind the head, exactly as a real one does,
## and nothing about the eye, the controls or the body envelope (`tests/seat_room.gd`) is moved to suit it.
##
## WHAT WENT WRONG FIRST: THE F-16'S 30 DEGREES AND AN UPRIGHT BODY DO NOT SHARE A HIP. A true 30-degree back with the
## head against the headbox (a 0.20 m gap) puts the seat reference point 0.23 m AHEAD of the eye line, and a 0.42 m pan
## then runs out to z -0.68, over the pedals every station stands at z -0.46. At a 0.34 m gap it was still 0.18 m ahead,
## and `tests/pilot_seat.gd` found the BACK CUSHION 0.02 m in front of the knee ray `seat_room` fires from the upright
## hip at z 0 -- the chair's back was where the game's body keeps its hips. So `aces2_f16` keeps a 0.45 m gap: the back
## crosses 0.47 m (the knee ray's lowest) behind z 0 and the hips land at z -0.05, where an upright body's are. The
## head then sits 0.25 m off the headbox, which is how F-16 pilots are reported to fly anyway -- head forward, off the
## rest (the neck aches Wikipedia cites) -- and nothing about the eye, the controls or the envelope moved.
##
## THE PANS ARE SHORT, AND THAT IS THE PEDALS' DOING (every preset; the helicopters' too, found fitting them). A real
## ejection seat's pan is about 0.42 m deep; here the rudder pedals stand at z -0.46 on the floor
## (`CockpitStation.FOOTWELL` ahead of the stick) and the eye's line to them crosses the pan's height at about z -0.32.
## Measured in the craft on 2026-09-18 (`tests/pilot_seat.gd`, "hides nothing"): at 0.40 and 0.42 deep the F-16's, the
## F-14's and the F/A-18's pans hid every pedal part from the pilot. Cut to 0.27 (the F-16's, whose hips are 0.05 m
## further forward) and 0.29 (at 0.32 the Mk 14's lip still crossed every line at z -0.32, 0.43 m up), the pilot's
## thighs would overhang the lip -- which is what they do in a real one -- and every pedal is in view.
##
## NO ARMRESTS, ON ANY OF THEM. A cockpit seat has none: the arms work the stick and the throttle, and the ACES II's and
## the Mk 14's sides are low lips on the bucket. `tests/pilot_seat.gd` fails any upward face at elbow height beside the
## torso, and its mutant adds a pair.
##
## LOW POLY AND FACETED, as the Hawkeye is (`modelling_here.md` section 4). Every part is a box, a flat plate or a
## six-sided rod through `RotorcraftKit`, each triangle with its own face normal; the colour is in the vertices, so one
## seat is ONE MESH, ONE SURFACE, ONE DRAW CALL. Measured 2026-09-18: 240 (the armoured seat) to 376 (the ACES II)
## triangles a seat (see `BUDGET`). Do not subdivide it: the Hawkeye's whole fuselage ring is 20 facets and a seat is a
## small thing seen from a metre away.
##
## EVERY PART IS NAMED, as a triangle range in the mesh's `parts` metadata ({name: [first triangle, count]}), because
## the seat is one mesh and a test must still be able to ask where the headbox is.
##
## SOURCES, tagged as `modelling_here.md` section 3 asks. The research, the photographs and their licences are in
## `~/godotgames-drafts/2026-09-18/cockpit-chairs/research/`; none is incorporated into the game.
##   [W16]  Wikipedia, "General Dynamics F-16 Fighting Falcon": the ACES II "reclined at an unusual tilt-back angle of
##          30 degrees", where most fighters "have a tilted seat at 13-15 degrees"; later US fighters about 20.
##   [WA2]  Wikipedia, "ACES II": the F-16, F-22 and WB-57 "have only one handle located between the pilot's legs";
##          the A-10, F-15, F-117, B-1 and B-2 have connected side handles.
##   [WMB]  Wikipedia, "Martin-Baker": the Mk 14 NACES (SJU-17) is in the F-14D, the F/A-18 and the T-45.
##   [WMB2] the same article: the Mk 16 is in the "Lockheed Martin F-35 Lightning II" (the US16E is the F-35's Mk 16);
##          "the most recent being the Lockheed Martin F-35 Lightning II programme". Read 2026-09-19.
##   [P03]  Commons, "F-16 Fighting Falcon egress maintenance 140731-F-SI704-681.jpg" (USAF, public domain): the ACES II
##          loop handle on the pan's front lip, a light grey seat, the survival kit under the pan.
##   [P04]  Commons, "Martin-Baker Mk.14 ejection seat Turku Airshow 2015.JPG" (public domain): the black box headbox
##          with its drogue container on top, a black frame and rails, olive cushions, a yellow and black pan handle.
##   [WUH]  Wikipedia, "Sikorsky UH-60 Black Hawk": "crashworthy crew (armored) and troop seats". No free photograph of
##          a UH-60's or an AH-64's armoured pilot seat clear enough to measure was found: the armoured preset is an
##          ESTIMATE of the type (a bucket with side armour, upright), and that gap is written in the research file.
##   [TS19] Technical Soaring Vol 19 No 2 p 52 (Sperber's suspended seat pan), reproduced as Figure 4 of Tony Segal,
##          "Designing a sailplane safety cockpit", Sailplane & Gliding / free flight 6/98: a modern glider's pilot
##          "semi-reclining rather than sitting vertically", the seat back drawn at 45 degrees; "the seat back structure
##          and parachute pack" together support the spine. The glider pilot's parachute IS the back cushion.
##   Everything else -- widths, heights, the head gap -- is ESTIMATE from a seated 95th-percentile body, the same
##   ANSUR II figures `tests/seat_room.gd` uses.

## THE MOST TRIANGLES A SEAT MAY COST. A seat is seen from a metre away and there are one or two in a craft; this is a
## few per cent of an aeroplane (the F/A-18F's exterior is 1,700).
const BUDGET: int = 400

## EVERY PARAMETER AND ITS DEFAULT. A preset names only what differs.
##   recline        degrees the back leans aft of vertical
##   pan_tilt       degrees the pan's front edge rises
##   pan_height     metres over the anchor of the pan's top at its rear edge (the seat reference point)
##   pan_depth      metres of pan, rear edge to front lip
##   head_gap       metres from the eye, square to the back's face, to that face -- a head and a helmet plus air
##   width          metres across the bucket
##   back_width     metres across the back and the headbox, no wider than the bucket: a HELICOPTER'S COLLECTIVE stands
##                  beside the hip, 0.26 m out and 0.19 m behind the eye, and the eye's line down to it passes the back
##                  at 0.20 m out and 0.88 m up -- measured 2026-09-18, a 0.40 m back hid it in all six helicopter
##                  seats.
##   headbox        "ejection" (a box behind the head, drogue on it), "headrest" (a pad) or "none"
##   drogue         "top" (a container on the headbox, Mk 14), "mortar" (a tube behind it, ACES II) or "none"
##   rails          true for an ejection seat's catapult guide rails behind the back
##   tracks         true for a light seat's floor tracks and legs
##   side_armour    true for a crash seat's armour wings beside the torso
##   handle         "loop" between the knees on the pan's front lip, or "none"
##   striped        the handle in yellow and black (Martin-Baker) rather than plain yellow (ACES II)
##   harness        shoulder straps and lap belts
##   survival_kit   a kit box under the pan
##   lips           metres the bucket's side lips stand, a hand's width on an ejection seat; low on a moulded pan
##   parachute      the back cushion is a parachute pack, as a glider pilot's is [TS19]: thicker, in the pack's colour,
##                  with its ripcord's red handle on the left of the harness
##   floor          metres over the anchor the chair stands on; below zero means the station's own floor top,
##                  `CockpitStation.FLOOR`. THE CRAFT'S, like the headroom: the Little Bird lifts its footwell 0.20 m to
##                  its door sills because the egg's belly is too narrow lower down, and its chairs' tracks stood 0.07 m
##                  over the anchor, out under the belly, until they stood on that floor instead (2026-09-18).
##   headroom       metres over the anchor that nothing of the chair may reach: THE CRAFT'S, not the seat's. A fighter's
##                  canopy is 0.13 to 0.25 m over the eye the rig places, where a real one clears a real headbox, so
##                  the headbox, the drogue and the rails are cut down under it (see `build`). The default is no limit.
const DEFAULTS: Dictionary = {
	"recline": 13.0, "pan_tilt": 6.0, "pan_height": 0.40, "pan_depth": 0.29, "head_gap": 0.22,
	"width": 0.46, "back_width": 0.46,
	"headbox": "ejection", "drogue": "none", "rails": false, "tracks": false, "side_armour": false,
	"handle": "none", "striped": false, "harness": true, "survival_kit": false, "parachute": false, "lips": 0.10,
	"frame": Color(0.30, 0.31, 0.32), "cushion": Color(0.30, 0.32, 0.26), "strap": Color(0.52, 0.47, 0.34),
	"headroom": 9.0, "floor": -1.0, "source": "",
}
## HOW FAR UNDER THE HEADROOM THE CHAIR'S TOP STOPS, in metres: the canopy's inner skin is glass, not a ceiling.
const HEADROOM_GAP: float = 0.02
## THE LEAST HEADBOX: its top no lower than this along the back over the eye's level, or it no longer covers the
## back of a head at all. A craft that cannot give it this much is told so, out loud.
const HEAD_TOP_LEAST: float = 0.02

## THE PRESETS. The recline is the figure the source gives and is typed here ONCE; the test measures it back off the
## drawn back cushion, not off this table.
const PRESETS: Dictionary = {
	# THE F-16'S ACES II, 30 degrees [W16], one loop handle between the legs [WA2], light grey [P03]. The head is held
	# off the headbox, hence the larger gap -- see the doc block for what the honest 0.20 m cost.
	"aces2_f16": {"recline": 30.0, "pan_tilt": 10.0, "pan_height": 0.36, "pan_depth": 0.27, "head_gap": 0.45,
		"drogue": "mortar", "rails": true, "handle": "loop", "survival_kit": true,
		"frame": Color(0.58, 0.60, 0.61), "cushion": Color(0.34, 0.36, 0.31),
		"source": "[W16] 30 deg; [WA2] one handle between the legs; [P03] grey"},
	# THE SAME SEAT AS THE F-15 CARRIES IT, 13 degrees [W16]. The F-15's handles are at the sides [WA2]; they are not
	# armrests but they sit where one would, so this keeps the F-16's loop and says so.
	"aces2": {"recline": 13.0, "drogue": "mortar", "rails": true, "handle": "loop",
		"survival_kit": true,
		"frame": Color(0.58, 0.60, 0.61), "cushion": Color(0.34, 0.36, 0.31),
		"source": "[W16] 13-15 deg for most fighters; [P03] grey; loop kept in place of the F-15's side handles"},
	# THE MARTIN-BAKER MK 14 NACES of the F-14D and the F/A-18 [WMB]: black, a drogue container on the headbox, olive
	# cushions and a striped pan handle [P04]; 14 degrees, the middle of "13-15" [W16].
	"mk14": {"recline": 14.0, "drogue": "top", "rails": true, "handle": "loop", "striped": true,
		"survival_kit": true, "frame": Color(0.10, 0.10, 0.11), "cushion": Color(0.31, 0.34, 0.20),
		"source": "[WMB] F-14D, F/A-18; [P04] black, drogue on the headbox, striped handle; [W16] 13-15 deg"},
	# THE MARTIN-BAKER US16E of the F-35 [WMB2]: the Mk 16 family's lighter seat, black, a drogue container on a tall
	# headbox, rails, and a striped handle between the knees. The recline, 18 degrees, is an ESTIMATE between the Mk 14's
	# 14 and the ACES II's 30 in the F-16, from photographs of F-35 cockpits; no source read this session gives it.
	"us16e": {"recline": 18.0, "pan_tilt": 8.0, "pan_height": 0.34, "pan_depth": 0.26, "head_gap": 0.36,
		"drogue": "top", "rails": true, "handle": "loop", "striped": true, "survival_kit": true,
		"frame": Color(0.09, 0.09, 0.10), "cushion": Color(0.20, 0.21, 0.19),
		"source": "[WMB2] Mk 16 in the F-35; black, drogue on the headbox, striped handle; 18 deg ESTIMATE"},
	# A HELICOPTER'S ARMOURED CRASH SEAT [WUH]: very upright, a bucket with armour wings either side of the torso and a
	# pad for the head, olive drab with black cushions. ESTIMATE of the type.
	"heli_armoured": {"recline": 10.0, "pan_tilt": 5.0, "width": 0.50, "back_width": 0.36, "headbox": "headrest",
		"side_armour": true,
		"frame": Color(0.29, 0.31, 0.22), "cushion": Color(0.11, 0.11, 0.11), "strap": Color(0.36, 0.36, 0.30),
		"source": "[WUH] crashworthy armoured crew seats; upright 10 deg ESTIMATE"},
	# A LIGHT AEROPLANE'S OR A LIGHT HELICOPTER'S SEAT: upright with a little lean, on floor tracks, a headrest. ESTIMATE.
	"light": {"recline": 12.0, "pan_tilt": 7.0, "width": 0.46, "back_width": 0.36, "headbox": "headrest",
		"tracks": true, "frame": Color(0.24, 0.24, 0.25), "cushion": Color(0.46, 0.43, 0.38),
		"strap": Color(0.20, 0.20, 0.22), "source": "light aircraft seat on rails, 12 deg ESTIMATE"},
	# AN AIRLINER'S OR A TRANSPORT'S CREW SEAT: the light seat, wider and taller, on tracks. ESTIMATE.
	# A SAILPLANE'S MOULDED SEAT [TS19]: the most reclined seat in the fleet, 45 degrees against the F-16's 30. A glass-
	# fibre pan and back shell moulded into the fuselage, NO headbox (the back ends at the neck; a head rests on the
	# parachute's top), no rails, no kit, no handle, a harness, and the parachute pack as the back cushion. The pan is
	# 0.82 m over the anchor and it stands on a floor 0.70 up: THE GAME'S BODY IS UPRIGHT, and its knees are a volume
	# 0.55 +- 0.08 m over the anchor running 0.55 m ahead of the hip (`tests/seat_room.gd`'s fan). A reclined back that
	# came lower lies across them. Measured 2026-09-18 (`tests/pilot_seat.gd`, "the body envelope"): with the pan at 0.70
	# and then 0.75, the back shell's lower corner stood 0.17 m ahead of the hip in that volume. So the pan is 0.53 m
	# under the eye where a real reclined pilot's is about 0.75 -- the price of an upright body in a reclined seat, paid
	# in the chair and not in the envelope. A craft whose floor is lifted to its belly says so in its `footwell`, and the
	# chair stands on it. The lips are low, 0.05 m, as a moulded pan's are.
	"sailplane": {"recline": 45.0, "pan_tilt": 12.0, "pan_height": 0.82, "pan_depth": 0.30, "head_gap": 0.25,
		"width": 0.44, "back_width": 0.40, "headbox": "none", "parachute": true, "floor": 0.70, "lips": 0.05,
		"frame": Color(0.84, 0.85, 0.86), "cushion": Color(0.20, 0.27, 0.44), "strap": Color(0.22, 0.24, 0.27),
		"source": "[TS19] a modern glider's seat back at 45 deg, the parachute as its back cushion; no armrests"},
	"transport": {"recline": 12.0, "pan_tilt": 6.0, "width": 0.52, "back_width": 0.36, "headbox": "headrest",
		"tracks": true, "frame": Color(0.18, 0.19, 0.21), "cushion": Color(0.22, 0.25, 0.32),
		"strap": Color(0.20, 0.20, 0.22), "source": "airliner / transport crew seat on tracks, 12 deg ESTIMATE"},
}

## HOW HIGH A CRASH SEAT'S ARMOUR WINGS COME, in metres over the anchor: below the shoulders' 1.05 (`seat_room`'s
## lowest shoulder ray), and below 0.90 because of the signal lamp. Lightgun's holster (2026-09-18) hangs the lamp 0.30 m
## out at 0.89 to 0.92 m, beside the right-hand seat, and at 1.00 m the wing crossed the eye's line to it 0.95 m up in
## the UH-60 and the Chinook. The wing is still a panel beside the ribs, which is what the real one is.
const ARMOUR_TOP: float = 0.88
const YELLOW := Color(0.92, 0.72, 0.10)
const BLACK := Color(0.06, 0.06, 0.06)
## Square section of a strap and of a rail, in metres.
const STRAP_WIDE: float = 0.045
const RAIL: float = 0.05


## THE PARAMETERS OF A PRESET, every default filled in. An unknown name is refused out loud and gets the defaults.
static func preset(name: String) -> Dictionary:
	var made: Dictionary = DEFAULTS.duplicate()
	if not PRESETS.has(name):
		push_warning("PilotSeat: no preset '%s'; the defaults are drawn" % name)
		return made
	made.merge(PRESETS[name] as Dictionary, true)
	made["preset"] = name
	return made


## THE SEAT, from a preset's name and whatever the craft overrides (its "headroom"), as a named MeshInstance3D for the
## seat anchor.
static func of(name: String, overrides: Dictionary = {}) -> MeshInstance3D:
	var p: Dictionary = preset(name)
	p.merge(overrides, true)
	return build(p)


## WHERE THE SEAT IS, solved from the eye: the back face's unit up and out vectors, the seat reference point (the pan's
## top at its rear edge, where the back meets it) and the point on the back's plane square behind the eye.
static func frame_of(p: Dictionary) -> Dictionary:
	var lean: float = deg_to_rad(float(p["recline"]))
	var up := Vector3(0.0, cos(lean), sin(lean))
	var out := Vector3(0.0, sin(lean), -cos(lean))
	var eye := Vector3(0.0, CockpitStation.EYE_HEIGHT, 0.0)
	# THE POINT OF THE BACK'S PLANE LEVEL WITH THE EYE, which is where the back of a head is: square behind the eye it
	# would sit lower by head_gap x sin(recline), which on the F-16 drops the headbox 0.17 m to the nape.
	var behind: Vector3 = eye + Vector3(0.0, 0.0, float(p["head_gap"]) / cos(lean))
	var down: float = (float(p["pan_height"]) - behind.y) / up.y
	var tilt: float = deg_to_rad(float(p["pan_tilt"]))
	return {"up": up, "out": out, "eye": eye, "behind": behind, "srp": behind + up * down,
		"along": Vector3(0.0, sin(tilt), -cos(tilt)), "neck": -0.14}


## BUILD ONE SEAT from parameters (`preset()` fills the defaults). One mesh, one surface, its parts named in metadata.
static func build(p: Dictionary) -> MeshInstance3D:
	var f: Dictionary = frame_of(p)
	var up: Vector3 = f["up"]
	var out: Vector3 = f["out"]
	var srp: Vector3 = f["srp"]
	var behind: Vector3 = f["behind"]
	var along: Vector3 = f["along"]
	var across := Vector3.RIGHT
	var wide: float = float(p["width"])
	var back_w: float = minf(float(p["back_width"]), wide)
	var frame: Color = p["frame"]
	var cushion: Color = p["cushion"]
	var strap: Color = p["strap"]
	var parts: Array = []
	# THE BACK: a cushion whose FACE is the solved plane, from the pan up to the neck, on a shell behind it.
	var back_turn := Basis(across, up, -out)
	var back_top: Vector3 = behind + up * float(f["neck"])
	var back_len: float = (back_top - srp).length()
	var t := RotorcraftKit.tool()
	RotorcraftKit.box(t, srp + up * back_len * 0.5 - out * 0.04, Vector3(back_w - 0.06, back_len, 0.08), cushion,
		back_turn)
	parts.append(["back", t])
	# THE PARACHUTE PACK, a glider pilot's back cushion [TS19]: behind the cushion's face, a container a little wider
	# than it, with its pin flap across the top.
	if bool(p["parachute"]):
		t = RotorcraftKit.tool()
		RotorcraftKit.box(t, srp + up * back_len * 0.52 - out * 0.10, Vector3(back_w - 0.02, back_len * 0.92, 0.06),
			cushion.darkened(0.25), back_turn)
		RotorcraftKit.box(t, srp + up * back_len * 0.97 - out * 0.06, Vector3(back_w - 0.10, 0.05, 0.10),
			cushion.lightened(0.15), back_turn)
		parts.append(["parachute", t])
	# THE TOP OF WHATEVER CARRIES THE HEAD, along the back from the eye's level: a tall ejection headbox, or a pad --
	# CUT DOWN UNDER THE CRAFT'S HEADROOM, and the Mk 14's drogue container with it. Measured 2026-09-18: the F-16's
	# canopy is 1.44 to 1.49 m over its anchor where the headbox stands, and the first fitting put the box's top at 1.56,
	# 0.08 m out through the glass; the F-14's back seat and the F/A-18's the same by 0.05 to 0.12.
	var head_top: float = 0.24 if String(p["headbox"]) == "ejection" else 0.12
	var drogue_on_top: bool = String(p["drogue"]) == "top"
	var room: float = (float(p["headroom"]) - HEADROOM_GAP - behind.y) / up.y
	if drogue_on_top and room - 0.10 < head_top:
		# NO ROOM FOR IT ON TOP: the container goes on the headbox's back, where the rails are.
		drogue_on_top = room - 0.10 >= HEAD_TOP_LEAST + 0.08
	head_top = minf(head_top, room - (0.10 if drogue_on_top else 0.0))
	if head_top < HEAD_TOP_LEAST:
		push_warning("PilotSeat: %.2f m of headroom leaves the headbox %.2f m over the eye's level; drawn at %.2f"
			% [float(p["headroom"]), head_top, HEAD_TOP_LEAST])
		head_top = HEAD_TOP_LEAST
	# THE SHELL behind the cushion, from under the pan to the top of whatever carries the head.
	var shell_from: Vector3 = srp - up * 0.10
	var shell_to: Vector3 = behind + up * (head_top if String(p["headbox"]) != "none" else float(f["neck"]))
	t = RotorcraftKit.tool()
	RotorcraftKit.box(t, (shell_from + shell_to) * 0.5 - out * 0.11,
		Vector3(back_w, (shell_to - shell_from).length(), 0.06),
		frame, back_turn)
	parts.append(["shell", t])
	# THE HEADBOX OR THE HEADREST, behind the head and never in front of it.
	match String(p["headbox"]):
		"ejection":
			t = RotorcraftKit.tool()
			var from: Vector3 = behind + up * (float(f["neck"]) + 0.02)
			var to: Vector3 = behind + up * head_top
			RotorcraftKit.box(t, (from + to) * 0.5 - out * 0.10, Vector3(back_w - 0.08, (to - from).length(), 0.20),
				frame, back_turn)
			RotorcraftKit.box(t, behind + up * 0.02 - out * 0.005, Vector3(0.22, 0.20, 0.01), cushion, back_turn)
			parts.append(["headbox", t])
		"headrest":
			t = RotorcraftKit.tool()
			var from: Vector3 = behind + up * (float(f["neck"]) + 0.01)
			var to: Vector3 = behind + up * head_top
			RotorcraftKit.box(t, (from + to) * 0.5 - out * 0.045, Vector3(0.28, (to - from).length(), 0.09), cushion,
				back_turn)
			parts.append(["headbox", t])
	# THE DROGUE: a container on top of the headbox (Mk 14), or the ACES II's mortar tube behind its right shoulder.
	match String(p["drogue"]):
		"top":
			t = RotorcraftKit.tool()
			if drogue_on_top:
				RotorcraftKit.box(t, behind + up * (head_top + 0.05) - out * 0.12, Vector3(back_w - 0.14, 0.10, 0.16),
					frame, back_turn)
			else:
				RotorcraftKit.box(t, behind + up * (head_top - 0.07) - out * 0.26, Vector3(back_w - 0.14, 0.12, 0.10),
					frame, back_turn)
			parts.append(["drogue", t])
		"mortar":
			t = RotorcraftKit.tool()
			var base: Vector3 = behind + up * (head_top - 0.06) - out * 0.23 + across * (back_w * 0.5 - 0.09)
			RotorcraftKit.rod(t, base - up * 0.30, base + up * 0.04, 0.045, frame.darkened(0.25), 6)
			parts.append(["drogue", t])
	# THE PAN: a cushion on the seat reference point, tilted up at the front, on the bucket.
	var pan_turn := Basis(across, along.cross(across).normalized() * -1.0, -along)
	var depth: float = float(p["pan_depth"])
	var pan_up: Vector3 = pan_turn.y
	var pan_mid: Vector3 = srp + along * depth * 0.5 - pan_up * 0.03
	t = RotorcraftKit.tool()
	RotorcraftKit.box(t, pan_mid, Vector3(wide - 0.06, 0.06, depth), cushion, pan_turn)
	parts.append(["pan", t])
	# THE BUCKET under it, with low lips at the sides -- a lip, not an arm: it stops a hand's width over the cushion.
	t = RotorcraftKit.tool()
	RotorcraftKit.box(t, pan_mid - pan_up * 0.06, Vector3(wide, 0.06, depth + 0.02), frame, pan_turn)
	for side in [-1.0, 1.0]:
		var lips: float = float(p["lips"])
		RotorcraftKit.box(t, pan_mid + across * side * (wide * 0.5 - 0.015) + pan_up * (lips * 0.5 - 0.03),
			Vector3(0.03, lips, depth), frame, pan_turn)
	parts.append(["bucket", t])
	# THE SURVIVAL KIT under the pan, or a plain pedestal: either way the seat stands on the floor.
	var floor_y: float = float(p["floor"]) if float(p["floor"]) >= 0.0 else CockpitStation.FLOOR
	var under: Vector3 = pan_mid - pan_up * 0.09
	if bool(p["tracks"]):
		# A LIGHT SEAT: two floor tracks and four legs.
		t = RotorcraftKit.tool()
		for side in [-1.0, 1.0]:
			var x: float = side * (wide * 0.5 - 0.07)
			var rear := Vector3(x, floor_y + 0.015, srp.z + 0.12)
			var front := Vector3(x, floor_y + 0.015, srp.z - depth - 0.06)
			RotorcraftKit.box(t, (rear + front) * 0.5, Vector3(0.04, 0.03, (rear - front).length()), frame.darkened(0.3))
			for end in [0.1, 0.85]:
				var top: Vector3 = srp + along * depth * end - pan_up * 0.09 + across * x
				RotorcraftKit.rod(t, Vector3(x, floor_y + 0.03, top.z), top, 0.018, frame, 4)
		parts.append(["tracks", t])
	else:
		t = RotorcraftKit.tool()
		var height: float = under.y - floor_y
		var kit: bool = bool(p["survival_kit"])
		RotorcraftKit.box(t, Vector3(0.0, floor_y + height * 0.5, under.z),
			Vector3(wide - (0.04 if kit else 0.16), height, depth * (0.9 if kit else 0.6)),
			(cushion.darkened(0.45) if kit else frame.darkened(0.2)))
		parts.append(["survival_kit" if kit else "pedestal", t])
	# THE CATAPULT RAILS behind the back, floor to the top of the headbox.
	if bool(p["rails"]):
		t = RotorcraftKit.tool()
		for side in [-1.0, 1.0]:
			var x: Vector3 = across * side * (back_w * 0.5 - 0.06)
			var top: Vector3 = behind + up * head_top - out * 0.19 + x
			var foot: Vector3 = top - up * ((top.y - floor_y) / up.y)
			RotorcraftKit.box(t, (top + foot) * 0.5, Vector3(RAIL, (top - foot).length(), RAIL), frame.darkened(0.35),
				back_turn)
		parts.append(["rails", t])
	# ARMOUR WINGS beside the torso: vertical plates outboard of the bucket, from the pan to `ARMOUR_TOP`, running
	# forward of the back no further than the shoulder's own clearance allows.
	if bool(p["side_armour"]):
		t = RotorcraftKit.tool()
		for side in [-1.0, 1.0]:
			var x: float = side * (wide * 0.5 + 0.02)
			var low_back: Vector3 = srp - out * 0.10
			var high_back: Vector3 = srp + up * ((ARMOUR_TOP - srp.y) / up.y) - out * 0.10
			var outline: Array[Vector3] = [
				Vector3(x, low_back.y, low_back.z), Vector3(x, high_back.y, high_back.z),
				Vector3(x, high_back.y, high_back.z - 0.18), Vector3(x, low_back.y + 0.04, low_back.z - 0.34)]
			RotorcraftKit.plate(t, outline, Vector3.RIGHT, 0.025, frame.darkened(0.1))
		parts.append(["armour", t])
	# THE HANDLE: a loop on the pan's front lip, between the knees, its top no higher than a hand's breadth over the lip.
	if String(p["handle"]) == "loop":
		t = RotorcraftKit.tool()
		# THE TOP IS 1 CM OVER THE CUSHION: `seat_room`'s knee ray runs forward 0.47 m over the anchor at its lowest, and
		# the upright ACES II's lip stands at 0.444.
		var lip: Vector3 = srp + along * (depth + 0.012) - pan_up * 0.05
		var points: Array[Vector3] = []
		for step in range(7):
			var a: float = PI * float(step) / 6.0
			points.append(lip + across * (cos(a) * 0.055) + pan_up * (sin(a) * 0.05) - along * (sin(a) * 0.012))
		for i in range(points.size() - 1):
			var colour: Color = BLACK if bool(p["striped"]) and i % 2 == 1 else YELLOW
			RotorcraftKit.rod(t, points[i], points[i + 1], 0.011, colour, 4)
		parts.append(["handle", t])
	# THE HARNESS: two shoulder straps down the back's face, a lap belt either side over the pan, and the buckle.
	if bool(p["harness"]):
		t = RotorcraftKit.tool()
		for side in [-1.0, 1.0]:
			var x: Vector3 = across * side * 0.09
			var top: Vector3 = back_top + x + out * 0.006
			var foot: Vector3 = srp + up * 0.06 + x + out * 0.006
			RotorcraftKit.box(t, (top + foot) * 0.5, Vector3(STRAP_WIDE, (top - foot).length(), 0.008), strap, back_turn)
			var hip: Vector3 = srp + along * 0.10 + across * side * (wide * 0.5 - 0.05) + pan_up * 0.005
			var buckle: Vector3 = srp + along * 0.22 + across * side * 0.03 + pan_up * 0.005
			var belt := Basis((buckle - hip).normalized().cross(pan_up).normalized(), pan_up, -(buckle - hip).normalized())
			RotorcraftKit.box(t, (hip + buckle) * 0.5, Vector3(STRAP_WIDE, 0.008, (buckle - hip).length()), strap, belt)
		RotorcraftKit.box(t, srp + along * 0.23 + pan_up * 0.01, Vector3(0.07, 0.015, 0.07), frame.lightened(0.3), pan_turn)
		if bool(p["parachute"]):
			# The ripcord's red D-ring on the left shoulder strap, where a glider pilot's hand finds it.
			RotorcraftKit.box(t, srp + up * back_len * 0.62 + across * -0.09 + out * 0.02, Vector3(0.06, 0.035, 0.02),
				Color(0.80, 0.10, 0.08), back_turn)
		parts.append(["harness", t])
	return _assemble(parts, p)


## EVERY PART INTO ONE SURFACE, with each part's triangle range recorded by name.
static func _assemble(parts: Array, p: Dictionary) -> MeshInstance3D:
	var whole := RotorcraftKit.tool()
	var ranges: Dictionary = {}
	var first: int = 0
	for entry in parts:
		var piece: ArrayMesh = (entry[1] as SurfaceTool).commit()
		if piece.get_surface_count() == 0:
			continue
		var count: int = piece.surface_get_array_len(0) / 3
		whole.append_from(piece, 0, Transform3D.IDENTITY)
		ranges[String(entry[0])] = [first, count]
		first += count
	var node := MeshInstance3D.new()
	node.name = "PilotSeat"
	node.mesh = whole.commit()
	node.material_override = RotorcraftKit.paint()
	node.set_meta("parts", ranges)
	node.set_meta("preset", String(p.get("preset", "")))
	node.set_meta("triangles", first)
	return node


## THE VERTICES OF ONE NAMED PART, in the seat's own frame: what a check measures, never the parameters.
static func part_triangles(seat: MeshInstance3D, part: String) -> PackedVector3Array:
	var ranges: Dictionary = seat.get_meta("parts", {})
	var found := PackedVector3Array()
	if not ranges.has(part) or seat.mesh == null:
		return found
	var span: Array = ranges[part]
	var points: PackedVector3Array = seat.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in range(int(span[0]) * 3, (int(span[0]) + int(span[1])) * 3):
		found.append(points[i])
	return found

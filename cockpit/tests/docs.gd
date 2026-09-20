extends Node
## AGENTS.MD IS NOT ALLOWED TO ROT. Headless, it checks that the map still describes the
## code.
##
##   Godot --headless --path cockpit res://tests/docs.tscn
##
## ---------------------------------------------------------------------------------
## WHY THIS EXISTS, AND WHAT IT WOULD HAVE CAUGHT
## ---------------------------------------------------------------------------------
##
## `cockpit/agents.md` is the largest document in this workshop and the primary interface for
## every future session: the first thing anybody reads and the last thing anybody edits. (A line
## count is not written here on purpose -- one typed into prose is a number in the wrong place,
## and this file's own rule is to enumerate, never hardcode.) Its closing paragraph said, for
## weeks,
##
##   "Menus, a lobby UI, audio, any art. `world/sky.gd` calls `Net.play_solo()` on load; a
##    real menu would call `Net.host()` or `Net.join()` and wait for `session_ready`."
##
## Half of that was already wrong -- the menus existed -- and the other half was a LIVE BUG
## that the wrong half hid: `sky.gd` really did still call `play_solo()`, which really did
## close the socket the menu had just opened, and both networked paths out of the only menu
## in the game were dead. A claim about the code that goes stale in the one file everybody
## reads first is worse than no claim, because it is read as true.
##
## `topdowntest/tests/docs_smoke.gd` has done this job in that project since its own
## agents.md went stale twice; this is the same idea against a bigger document.
##
## ---------------------------------------------------------------------------------
## THE ONE RULE THIS FILE HAS TO OBEY ITSELF: ENUMERATE, NEVER HARDCODE
## ---------------------------------------------------------------------------------
##
## Every claim below is derived at run time, from the disk or from another file. A test
## carrying its own list of levels, kinds, suites or paths would go stale the same afternoon
## the document did, and would do it silently, which is worse. `BootRouter.DOORS` became a
## table rather than a `match` for exactly this reason: a list nothing can read is a list
## this file would have to copy.
##
## The only hand-written lists here are the two EXCLUSIONS, and every entry carries the
## reason it is out -- because an exclusion is the one place drift can hide.
##
## WHAT IT CANNOT TELL YOU: whether a sentence is TRUE. That `world/sky.gd` is named in the
## document is not the claim that the paragraph about it describes what it does. This catches
## ABSENCE and NAMES, which is how this document has actually failed.
##
## Read RESULT=, not the exit code.

const AGENTS: String = "res://agents.md"
## THE DOCUMENT IS FIVE FILES SINCE 2026-09-20. `agents.md` kept the rules, the boot path, the
## suites and the queue; the craft, the world, the crew and the combat moved under `docs/`, so a
## session reads the one it needs instead of all eighteen thousand lines. Every check below reads
## the WHOLE document, because a claim does not stop being the document's because of which file it
## sits in -- and the folder is ENUMERATED, never listed here, so a sixth file is checked the day
## somebody adds it.
const AREA_DOCS: String = "res://docs"
## The index's own heading, and the folder as an index row spells it. These two strings are
## hand-written and there is no way round that -- a check has to know where the index is --
## so a renamed heading fails `agents_md_still_has_an_index` loudly instead of quietly
## checking nothing at all.
const INDEX_HEADING: String = "## WHICH FILE ANSWERS WHICH QUESTION"
const AREA_PREFIX: String = "docs/"
## The suite list both runners read. Read as text rather than reimplemented, for the reason
## in its own header: a list kept in two places is a list kept in one place and a copy of it.
const SUITES: String = "res://tests/suites.txt"
## Where test scenes live. Both directories, because `marshalling` keeps its own.
const TEST_DIRS: Array[String] = ["res://tests", "res://marshalling/tests"]

## SCENES UNDER tests/ THAT ARE DELIBERATELY NOT SUITES, and why each one is out.
##
## A PROBE PRINTS NUMBERS AND HAS NO VERDICT. That is the whole distinction, and it is worth
## defending: adding a name here to quiet a failure is the one edit that defeats this check,
## so each has to be a thing that genuinely cannot pass or fail.
const PROBES: Dictionary = {
	"final_shot": "renders the island strip's final for eyes (lane/throughrock) -- down it from 5 km out at the glide path's height, obliquely from outside the corridor, and straight down on the notch its keep-out cut, viewport only, run once with the keep-out taken out and once with it; it is NOT headless, and whether the cut reads as a pass and not a bite is for eyes, while airport holds the clearance and mountains the recorded rock",
	"ridge_culprit": "names which mountain range stands under the worst point of each island airfield's final (lane/ridges) -- airport.gd reports that point as so far out and so far across, which names a place and not a range, and three goes at moving the wrong arc by reasoning about bearings cost a suite run each; this walks the same finals and then asks every range on its own how high it stands there, so the answer is a salt. It has no verdict: airport holds whether the finals are clear",
	"ridge_variety": "measures how far apart the island's eleven mountain ranges actually are (lane/ridges) -- each built alone through the real MountainRange, walked at 100 m stations and cross-sectioned out to the foot on both flanks, printing the flank profile, crest roughness, summits, asymmetry and gullies on three contours, and the spread of each across the ranges; it is headless but has no verdict, because the answer is how much variety there is and how much is enough is the user's to say. mountains holds the island itself",
	"ridge_relief": "draws the island's rock as a hillshade from above and as four skylines, headless and with no rendering device (lane/ridges) -- the fast loop that gets a change to the ranges ready to be photographed, 37 ms against ninety seconds for a windowed scenery run; whether a mountainside reads as one is for eyes, and the passes and the room inside the ring it prints are smoke's and forest's verdicts, not its own",
	"splay_reel": "records a gun's scatter for eyes (lane/splayreel) -- two A-10s on a tower firing 130 rounds each at a gridded wall 800 m off, through MovieWriter; the LEFT gun is a CONTROL with `set_gun_scatter_scale(0)` and its 130 rounds land on one point, widest 0.000 m, so a reader can see that the spread is the cone and not the aeroplane. It is NOT headless. The Warthog was chosen because it parks dead still: a parked Apache sinks about 12 m/s and drifts, so its impacts spread even with scatter OFF, which is platform motion and would have read as scatter. Its own checks hold the numbers -- widest 1.62 m against the 1.60 m the 2 mrad cone allows at that range, arithmetic and simulation agreeing about a figure neither was told -- and the orange dots are an OVERLAY, one per landed round, captioned as such because the game's own hit puffs last a moment",
	"combat_reel": "records a raid for eyes (lane/combat) -- two bad attackers on a CB90, its gunner firing back, hits, smoke and the kills, through MovieWriter; it is NOT headless, and attackers holds every number the reel shows",
	"harrier_shot": "renders the AV-8B Harrier II on a stage of its own (lane/harrier): side, plan, front, rear and three-quarter orthographics, the four nozzles at the hover stop and at the braking stop, the gear up and the flaps down; it is NOT headless, and whether a shape reads as a Harrier rather than as a generic jet is for eyes, while harrier holds its published envelope, the nozzles' 98.5 degrees, the mid-span outriggers against the published 17 ft track, the nose-up stance and the winding",
	"detail_probe": "proves by RENDERING that a detail layer's own ALPHA masks it on an OPAQUE material in this engine build (lane/phantom) -- a blue unshaded quad, transparency disabled, detail on UV2, and a two-colour sheet red on its left half and fully transparent on its right, read back as pixels; the whole weathering design rests on that one behaviour and nothing in this workshop had used `detail_*` on any material before, so the class reference was a claim and this is the measurement. It is NOT headless. IT RUNS A CONTROL FIRST, with no detail layer at all, and that is not optional: the first version came back black on both halves and read exactly like 'the engine ignores this', when the quad had simply been wound away from the camera. A probe with no control cannot tell a feature that did nothing from a harness that showed nothing",
	"phantom_wear_shot": "renders the F-4E twice, weathered and factory-fresh, from the same camera in the same flat light, and reads the pixels back (lane/phantom) -- the anchor OUTSIDE the stain sheet's own frame, because every check in phantom_wear would still pass if the engine ignored the detail layer entirely. It is NOT headless. The claim is a RATIO and not an absolute: the exhaust must darken far more than the radome moves, which no uniformly dirty sheet can satisfy and which does not move when the paint or the lighting does. Sample boxes are found by unproject_position from named stations, never typed as pixels. phantom_wear holds the coordinates and the sheet itself",
	"craft_draw_cost": "puts three aircraft's DRAWING cost side by side (lane/phantomfast) -- the F-4E as built, the F-4E with its mip chain stripped, the F-4E with the weathering off, and the F-14 and F-35 as controls, every one of them built in ONE process and measured by showing and hiding it against the same empty room, at 24 m, 100 m and 290 m, with a full-frame still and a nearest-neighbour crop of each. Three separate runs cannot be subtracted from one another, which is why they are not three runs. It is NOT headless and it HANGS headless, because `frame_post_draw` never fires when no frames are drawn. It has no verdict: the answer is what one aeroplane costs against another, and what is too much is the user's to say, while sheet_cost holds what dressing one costs and that its sheet is sampled with a mip chain",
	"fireboat_shot": "renders the fireboat fighting a fire on the oil platform (lane/fireboat) -- alongside by day, the rig alight, and her three monitors playing water onto the burning module by day and again at night, which is the picture the whole lane is for; it is NOT headless, and whether a thrown arc reads as WATER rather than as a white wire is for eyes. It is not only a picture: it proves the stream by a BEFORE AND AFTER of the same frame, counting pixels that got paler when the monitors opened, because an earlier version counted bright neutral pixels in the finished shot and passed with 25,283 of them on a photograph containing no water at all; and it asks the fire its strength before and after, with a CONTROL fire out of reach that must NOT go out, without which a timer would pass it as well as the water does. fireboat holds her geometry and her mounts, oil_platform the rig, and fires the flame and the smoke column",
	"combat_shot": "renders hit craft for eyes (lane/combat) -- three light aeroplanes, one whole, one smoking thin and one thick, and a fourth destroyed into a fireball; it is NOT headless, and whether puffs read as smoke is for eyes, while hulls and hull_link hold the stages and the kill",
	"puff_shot": "renders the prototype puff clouds (lane/clouds2) -- six kinds on their own, close to, flown into behind an F-16, a layered sky, and (clouds3) a wall of towering cumulus over the sea by day, backlit, at evening and at night -- for the user to choose from, and its `look` group FAILS a heap not lit from one side (lit over shade, crown over foot, a blue shade); it is NOT headless, and whether a heap of transparent ellipsoids reads as a cloud is for eyes, while puff_sky holds the bands, the ground, the clear air between the layers and the eye inside a cloud",
	"craft_video_demo": "renders a deterministic AVI reel and midpoint PNGs of one real AI-flown craft over a quiet 16 km purpose-built landscape, retaining the game's procedural sky, LiftYard cumulus and ContrailYard wingtip trails, with orbit, chase, flyby and hero camera moves; it is NOT headless, and whether a camera move is cinematic is for eyes, while the fly bench and handling suite hold the actual flight",
	"craft_issue_shot": "renders two issued planes side by side at the native drawn-span clearance for a human to inspect; it is NOT headless, while addon issue and craft_peers hold the lifecycle and real network request",
	"lamp_part_shot": "renders the BUILD tab walked down to + SIGNAL LAMP and the plane's pilot seat from the eye before and after a lamp is placed (lane/lampopt); it is NOT headless, while signal_lamp, lamp_wire and lamp_peers hold that no seat has one until it is placed, and where it goes",
	"music_shot": "renders the MUSIC tab with the external catalogue, playing track, fade controls and readout; it is NOT headless, while record_shelf, music_page and music_peers hold its behavior",
	"taxi_ground_probe": "taxis one Cessna the same distance at AirportTraffic.TAXI_SPEED on the island and on the test field and leaves a flight trace of each (lane/tracelog); the answer is a chatter count read from those traces by tools/read_trace.py, and what it should be is the ground block's to decide",
	"crowd": "a bandwidth sweep -- the answer is a number and what it should be depends on what you are willing to pay for",
	"stress_sweep": "the craft-count sweep at 83 ms one way -- craft against peers, in one process behind an exact tick queue -- for the user question how many craft this game carries at 80 ms; it is headless but has no verdict, because the answer is a number and which number you accept depends on what you will put up with. net_stats and bulk_peers are the real-socket checks",
	"bulk_probe": "the full 0/50/100/200 craft by 2/4/8 peers by 8/16 tick load ladder; bulk_load holds the bounded production verdict while this prints the complete measurement table",
	"holding_stack_shot": "renders the real 200-aircraft island stack from a middle layer with the live TRAFFIC panel composited beside it; NOT headless, while holding_stack and bulk_load hold its behavior",
	"testfield_stress": "the test field under load, ON REQUEST and never in a gate (lane/testfield): its stress traffic scaled by --traffic-scale, the simulation's tick breakdown, go-arounds, holds, runway conflicts and losses as one STRESS line; with --scene=pictures, windowed, the whole map with every track and the busiest airport. tools/testfield_stress.ps1 runs it at each scale",
	"glider_polar": "measures the sailplane's sink flying straight at six speeds and circling at six speeds and circles, on the glider level away from any thermal (lane/gliderlevel): the table `SoaringPilot` and the level's thermals are sized from. Headless, and it has no right answer",
	"gliderlevel_shot": "renders the glider level, the ridge country, from where a glider pilot sits (lane/gliderlevel): the start's cumulus from the launch 1,000 ft up, the cloud field from a thermal's top, the north ridge and the whole sixteen kilometres; NOT headless, while gliderlevel holds its thermals, clouds, ridges, edge and craft",
	"adriatic_shot": "renders the Adriatic archipelago from the air (lane/adriatic): the whole thirty-two kilometres, the cove a seaplane takes off from, the needle channel and the twin fangs, the three sisters, a wooded island, and a low pass at 15 m; NOT headless, while adriatic holds its sea, its spawn on the water, its stacks and the widths of the gaps",
	"adriatic_reel": "films the Adriatic in the REAL level for MovieWriter: ten shots, fixed plates cut against dollies and cranes, through the needle channel and the fangs and back out, from adriatic_shot's own viewpoints so the two cannot drift; NOT headless, and NOT craft_video_demo, whose stage has no FlightLevel at all",
	"sail_reel": "films the brig under sail for eyes (lane/sailshots) -- heeled on a beam reach from astern, alongside at the bow wave, off the weather bow, up onto a crane, and put about through the wind, recorded by MovieWriter from its own viewport; it is NOT headless. HER LEAN IS NOT FAKED and must never be: PIRATE is the only kind on the Sail model, each sail's force is applied at that sail's own height and a metacentric torque rights her, so a stiffer lean is asked for with --wind= and nothing else. Its poses are SHIP-RELATIVE and rebuilt every frame, because a camera placed once behind a ship making five metres a second is filming where she was; and the shots that are FOR the heel stand astern or fine on the bow, because a camera on the beam she leans towards foreshortens -17.3 degrees of real heel into about two. sailing holds the sailing itself, and pirate_shot the stills",
	"small_craft_reel": "films the cruising sloop and the Leigh 30 cutter sailing, and photographs them in the same run (lane/sailshots) -- four boats on open water, two of each on opposite tacks, through MovieWriter with a PNG saved at the top of every shot, because a second launch for the stills would be a second sea, a second wind and a second set of liveries. NEITHER BOAT IS A KIND: SmallCraftDraft says so in its own second line, so there is no simulation under them and they cannot heel. ScenerySailboat moves them and leans them, and its heel is DRAWN -- the user's own permission, spent on the two boats it was meant for, while the brig next door in sail_reel is not faked at all. Its checks hold the one thing a picture of a fake must be held to, that the fake was ON while it was being photographed: a drawn heel silently returning zero would give four boats bolt upright and every other check would still pass. merchant_models holds their shapes",
	"testfield_shot": "renders the test field, the no-sea level, from the air (lane/testfield): each of its four fields from a kilometre or two up, and the west airport and the air base in one high oblique; NOT headless, while testfield holds its ground, its sea, its edge band and its finals",
	"diorama_reel": "records the controller's diorama MOVING, twice, one flag apart (lane/diorama) -- twenty seconds of ninety real AI craft flying over the island, swept once a second exactly as RadarWatch would, with the board HOLDING between sweeps and then DEAD RECKONING between them. It exists because the user asked for planes \"flying around\" and whether a 1 Hz plot reads as a plot or as a stutter is a question about MOTION, which no still and no assertion can answer -- rule 2 applied to time instead of to layout. It is NOT headless and it has no verdict on the choice: it prints how often one followed contact's piece moved (3.2%% of 592 frames held, 99.8%% reckoned) and the reels go to the user, because which one looks right is their call and a probe that picked a pass mark would be pretending otherwise. Note that ffmpeg mpdecimate cannot tell the two apart -- both are 601 unique frames, because the camera orbits and every pixel changes anyway, which is exactly why the measurement follows a CONTACT and not the frame. diorama holds the reckoning arithmetic and diorama_shot the stills",
	"diorama_shot": "renders the controller's DIORAMA (lane/diorama) -- the board empty, the board carrying a real ninety-craft sweep against the island's own rock, a low close angle where a stalk's length is the contact's altitude, and the flat plot beside the board as two views of ONE sweep; it is NOT headless, and whether 54 mm of relief reads as an island, whether a 14 mm token reads as an aeroplane and whether the board is actually better than the plot at anything are all for eyes. Its traffic is spread from 120 m to 4,200 m deliberately, because control_shot's ninety all fly at 300 and a board whose contacts are at one height photographs its own point away. It checks only that the pictures differ from one another -- an empty board against a busy one, the plot against the board -- because a probe that saves four photographs of the same thing passes gloriously; tests/diorama.gd holds the scale, the index and where a piece stands, and control_shot holds the plot's own legibility",
	"control_shot": "renders the controller's station (lane/flatcrew) -- the radar plot and its side panel, idle and with a contact picked, from a REAL sweep against the island's own rock; it is NOT headless, and whether a plot and a panel read as one screen rather than two competing for it, and whether a picked contact says what a controller would say on the radio, are for eyes. radar_peers holds that the picture is the host's and this machine's own, and radar_shot that the mountains' shadow falls where the rock is",
	"radar_shot": "draws what the radar HIDES (lane/flatcrew) -- ninety real aircraft at 300 m over the island plotted twice, everything that is up there and then only what one head can see, from RadarSet's own sweep against the island's own rock; it is NOT headless, and the question is whether the shadow a mountain casts on a plot looks like a mountain's shadow rather than like a sight line wired to something else, which no count can answer. radar_set holds that a craft behind a peak is missed and the same craft raised is seen, and radar_peers that two machines are sent different pictures",
	"server_shot": "renders the dedicated server's 2D console (lane/flatcrew) -- empty, which is the state a server spends its life in and the one somebody stares at wondering whether it is working, and busy with four players on two teams; it is NOT headless, and whether a person can tell a LIVE empty server from a dead one at a glance is exactly what no headless check can answer, while server_peers holds that the numbers on it are the right numbers over a real socket with a real machine joining",
	"tower_shot": "renders the tower commanding an aeroplane (lane/flightcore): a craft under the camera, the moment it is told to climb, and a minute later -- three stills whose told and doing columns part and then close, which is the smallest picture that only a working panel can produce; NOT headless, while tests/tower.gd holds that the buttons reach the autopilot",
	"pavement_shot": "renders the runway's SURFACE from the five distances it is seen from -- on the roll, at the threshold, on short final, from the downwind leg and straight down over the touchdown zone -- each in three treatments, the bare StandardMaterial3D this lane replaced against PLAIN and FINE, on the island strip and again on the one 8.4 km from the origin (lane/detailshaders); it is NOT headless, and whether the paving seams shimmer, whether the touchdown zone reads as rubber and whether anything pops as you descend are all for eyes, while pavement holds the frame convention, the one authority for the ranges and which tier declares what",
	"pavement_cost": "measures what the pavement's near detail costs a frame (lane/detailshaders) -- the bare material against both tiers and both tiers at twice the reach, interleaved with the arm order reversed, whole warm rounds discarded and any round in which the UNCHANGED baseline stuttered thrown out as somebody else on the GPU; it is NOT headless, and it has no verdict because the answer is a number whose precision depends on how busy the machine is -- it reports a bound and says so when the arms cannot be told apart, rather than picking the run that flattered them",
	"airport_shot": "renders Cape International, the island's airliner airport, from the air (lane/airport): the gates with 747s and 737s standing at them, the crossing, the final into 36 and the whole airport straight down; NOT headless, while airport holds its clearances, the 747's rolls and the rock",
	"seethrough_shot": "finds the eyes on the island from which a runway lies behind rock, day or night, and shoots one from the game viewport, with the runways' outlines drawn as pattern_shot draws them (--overlay=top|world) for the before and after of a strip showing through a mountain; NOT headless, while seethrough holds the fix",
	"pattern_shot": "renders airport life at the island's south shore strip straight down: the pattern's legs, the runway, each arrival's track and its leg and height, as a still and under MovieWriter; NOT headless, while traffic_pattern holds the flying",
	"map_shot": "renders the island once through LevelMap's 1024 px orthographic SubViewport and lays an operator's whole air picture over it -- three named players in their roster colours and thirty-two open grey machines, one of them picked -- so a person can answer the only question the plot exists to answer, which is whether they can tell which is which in a second; NOT headless, while level_map, map_page, map_screen and air_picture hold the projection, the update rules and who the session says is a person",
	"jitter": "measures the float grid at distance; reports millimetres, has no right answer",
	"level_change_shot": "renders three PNGs of one joined player: briefing room, the persistent curtain fully black, and the island after its host pressed a level; it is NOT headless, and the sequence is the visible transition contract",
	"lobby_shot": "renders three PNGs of the briefing room for a human to look at -- a standing eye, a high corner and a desk -- and is NOT headless; whether a room reads as a room has no assertion, and tests/lobby.gd holds everything about it that can fail",
	"names_shot": "renders the briefing room's identity board with two roster-coloured pilots beside it; it is NOT headless, while names and names_peers hold the roster's rules and its network. It was listed as a SUITE from 2026-09-16 to 2026-09-17 and hung the gate for three minutes every run, because its only pass condition is that a PNG was written and `RenderingServer.frame_post_draw` never comes under --headless",
	"road_vehicles_shot": "renders the nine road vehicles for eyes (lane/roadfleet): the whole fleet laid end to end in a line-up with a 1.80 m figure beside it, the same row from above, which is how nearly all of them will be seen, an eye-height pass close alongside, and every silhouette orthographic on one page at whatever scale the row comes out at, which is named in the file; it is NOT headless, and whether a few hundred triangles read as a car or a lorry is for eyes, while road_vehicles.gd holds every envelope, wheelbase, contact patch, eight-sided wheel, tumblehome, the legal maxima, the Atego body against its maker's printed G and the pickup bed against 5 ft 6 in",
	"road_diesel_shot": "renders the SD40-2 on its own: a three-quarter view, and the side, front and top orthographic with the scale in each filename, so craft/train's overlay can lay the side over the NS 3275 broadside at the photograph's own 154.4 px a metre; it is NOT headless, while road_diesel.gd holds the published envelope, the cab roof sitting below the long hood, the twelve 40 in wheels and the trucks",
	"sailplane_shot": "renders the Duo Discus airframe on its own in a sky: the front quarter, the side, the top, banked with the stick over, the rear quarter with the stick back, right rudder and the airbrakes out, the canopy close, and three orthographic silhouettes at 132.95 px a metre, the scale of the three-view it is measured from at 300 dpi; it is NOT headless, while sailplane.gd holds the size, the parts, the wing area and the hinges",
	"falcon_shot": "renders the F-16A Block 15 lit from four quarters -- one with the flaperons, stabilators and rudder deflected -- and as three orthographic silhouettes at 80 px a metre, which is 8 px a millimetre of the 1:100 three-view it is measured from, so craft/falcon/overlay_threeview.py lays them over that drawing at x1.000; it is NOT headless, while falcon.gd holds every dimension, the canopy, the intake, the pilot room and the hinges",
	"liners_shot": "renders the airliners (the 737-800W today) lit from both quarters, from the side and from below; the landing configuration, flaps at 40 degrees and spoilers up; the gear cycle as eight frames for craft/airliner/strip.py; and three orthographic silhouettes at the Boeing drawing's own 75.07 px a metre for craft/airliner/overlay_views.py; it is NOT headless, while airliners.gd holds the envelope, the pilots' room and glass, the gear's door sequence and the surfaces",
	"lightning_shot": "renders the F-35B lit from both quarters, low ahead into its intakes and from the side; its nozzle at 0, 47 and 95 degrees with the lift fan's doors; the STOVL configuration from above; both bays open from below; the gear cycle as eight frames for craft/lightning/strip.py; and three orthographic silhouettes at the JSF renders' own 178.88 px a metre for craft/lightning/overlay_views.py; it is NOT headless, while lightning.gd holds the envelope, the nozzle's angle, the gear's door sequence, the bays and the pilot room",
	"lightning_launch_reel": "films an F-35B bay launch at a quarter of real speed -- the port bay's doors swing open, the AMRAAM is pushed out and falls clear unlit, its motor lights, and the doors shut -- from its own CockpitWorld launched through a seated pilot's frame, with the drawn airframe, its bays eased from the world's bits and the missile drawn where the world has it; it is NOT headless, and lightning_bays holds every one of those to the server's record",
	"twin310_shot": "renders the Cessna 310R on white as three orthographic elevations, each fitted to the aeroplane and printing the pixels-a-metre it came out at for craft/plane/overlay_views.py; a three-quarter on grass; the gear down, halfway and up in one frame; and a scale line-up beside the Cessna 172S and the 737-800W. It is NOT headless, while twin310.gd holds the envelope, the nose-up stance, the tip tanks, the dihedral, the gear travel and the winding",
	"warthog_shot": "renders the A-10C lit from both quarters, the side, above and below; the GAU-8 from low ahead; each surface at its stop -- roll, pitch, yaw, the flaps and the decelerons split open as the speed brake; the gear cycle as eight frames; and three orthographic silhouettes at the three-view's own 199.83 px a metre for craft/warthog/overlay_views.py; it is NOT headless, while warthog.gd holds the envelope, the gun's port on the centreline, the gear's door sequence, the surfaces and the pilot room",
	"warbirds_shot": "renders the warbirds (the P-51D, the P-47D-30 and the P-38L; --only=p51,p47,p38) lit from both quarters, the side, above, below and low ahead; each surface at its stop -- roll, pitch, yaw and the flaps; the gear cycle as eight frames from the front quarter and eight from ahead; and three orthographic silhouettes, gear down (up for the P-38, whose drawing dashes it) and the propellers left out, at each drawing's own px a metre with the datum at the middle, for craft/<kind>/overlay_views.py; it is NOT headless, while p51.gd, p47.gd and p38.gd hold the envelope, the tyres on both grounds, the height tail down, the wing, the scoop, the gear's door sequence and the surfaces",
	"warthog_reel": "films the A-10C rolling in on a target and firing the GAU-8 -- the gear up in flight, the barrels turning, the tracers leaving the nose and the rounds landing on a tank, a gunboat or the tower placed where the first round is heading -- in the real level, boarded and flown through the desk's keys, with a caption of the drum, the dive and the rounds struck; it is NOT headless, and warthog_seat holds the gun, the rate, the muzzle and the barrels to numbers",
	"osprey_reel": "films the MV-22B doing what a tiltrotor is for -- parked with its nacelles up, straight up off the ground, a hover, the gear up and the conversion to wing-borne flight -- from its own CockpitWorld flown through a seated pilot's control frame, under MovieWriter, with the nacelles drawn at the world's lever times vector_travel and a caption of what the world says; it is NOT headless, and asserts only that it ends wing-borne, while osprey.gd holds the drawn angle against the simulation's travel",
	"osprey_shot": "renders the MV-22B as the game builds it (craft_osprey.tscn) from three fixed cameras, so a run before a change and one after are the same pictures; the airframe with its nacelles at 0, 45 and 90 degrees and its proprotors turning; helicopter mode from ahead, aeroplane mode from above and the flight deck close; the ramp down and shut from behind and half way from the side; the crew door open; the gear cycle as eight frames for craft/osprey/strip.py; the flight deck from each pilot's eye; with --only=crowd a stopwatch on a hundred Ospreys handed their buses; and six orthographic silhouettes, each with a second picture of its discs alone, at the Jetijones six-view's own scales for craft/osprey/overlay_views.py; it is NOT headless, while osprey.gd holds the envelope, the nacelles' angle against the simulation's travel, the discs' clearance, the crew's seats and view, the gear's door sequence, the ramp, the crew door and the VAT",
	"lightning_reel": "films the F-35B doing what a B is for -- the nozzle swung down and the lift fan doors open, straight up off the ground, a hover, the gear up and the transition to wing-borne flight -- from its own CockpitWorld flown through a seated pilot's frame by lightning_flight's robot, with the drawn airframe following the world and a caption of the world's numbers; it is NOT headless, and lightning_flight holds every one of those manoeuvres to a tolerance",
	"littlebird_circuit_reel": "films a Little Bird taking off from a strip, flying a 500 ft left-hand helicopter pattern and landing, from a chase camera through MovieWriter; it is NOT headless, while littlebird_circuit holds the flying",
	"littlebird_book": "holds the MH-6M on its rotor disc to the MD 530F book -- IGE vs OGE, translational lift, climb, cruise, vortex ring and autorotation -- each against a mutant; littlebird_flight is the job those numbers have to still do",
	"littlebird_seat_shot": "renders the MH-6M as the game builds it -- a VehicleView of kind 28 with its two stations -- from outside, close under the pilot's door where the standard footwell stood out of the belly (--tag names a before and after), and from each pilot's own eye ahead and out of his open door; it is NOT headless, while littlebird.gd, littlebird_flight.gd, seat_room and shell_room hold the seats, the view and the flying",
	"apache_shot": "renders the AH-64D Apache lit from four sides, from the gunner's eye ahead, down over the nose and out to port, from the pilot's eye over the gunner's canopy, from the side with both eyes marked to show the step, with its chin gun turned 60 degrees to port, and as three orthographic silhouettes laid on the public-domain Army three-view it is measured from at that drawing's own scale; it is NOT headless, while apache.gd holds the published size, the features, the tandem, the widened cockpit, both players fitting and the view from each eye",
	"littlebird_shot": "renders the MH-6M Little Bird lit from four sides, from both pilots' eyes and out of the open door, looking in at the two crew packed side by side, and as three orthographic silhouettes laid on the CC BY-SA three-view it is measured from at that drawing's own 6 px a unit; it is NOT headless, while littlebird.gd holds the published size, the features, the view from each eye, the doors off and both players fitting",
	"savoia_shot": "renders Porco Rosso's red flying boat lit from six angles -- one afloat at its draught with the propeller turning and the stick hard over, and one from the pilot's eye through the slot under the nacelle -- and as three orthographic silhouettes at 100 px a metre for laying over the reference photographs; it is NOT headless, while savoia.gd holds the envelope, the step, the floats, the propeller's clearance, the guns, the pilot's view, the open cockpit and the hinges",
	"prowler_shot": "renders the EA-6B Prowler lit from the front quarter, close through its gold glasshouse at all four crew cues, and as three orthographic silhouettes at the source drawing's own 57.909 px a metre, so a reader can lay one straight over the NAVAIR three-view and argue with it; it is NOT headless, while prowler.gd holds every dimension, the gear rake, the fold and the four-feature VAT",
	"chair_craft_shot": "renders the pilot's chairs in the F-16, the F-14, the F/A-18, the UH-60, the Chinook, the light helicopter, the Little Bird and the Apache as the game builds them -- a side cutaway through the cockpit by the camera's near plane with a head at every eye, a three-quarter through the glass, and a look down from the pilot's eye at the pan and the handle; it is NOT headless, while pilot_seat.gd holds the fitted chairs under the skin and out of every sight line",
	"pilot_seat_shot": "renders every PilotSeat preset in a row from the side and three-quarters on, with a head and the rig's eye in each, and a close three-quarter of each; it is NOT headless, while pilot_seat.gd holds the parts, the budget, the recline, the headbox and the body envelope",
	"tomcat_seat_shot": "renders the F-14D as the game builds it -- a VehicleView with both seats manned and the wing played from its VAT casting -- at 20, 44 and 68 degrees of sweep, from outside and from each crew eye looking at the port wing; it is NOT headless, while tomcat.gd, sweep_handle.gd and sweep_peers.gd hold the geometry, the handle and the sweep across two machines",
	"phantom_shot": "renders the F-4E Phantom II lit from both quarters, in side view, DEAD AHEAD -- the only view that can show the 12 degree outer dihedral and the 23 degree stabilator anhedral together -- from above for the dogtooth and the planform, low on the quarter for the intake splitters and the daylight in their boundary-layer gap, close on the nose for the gun fairing that makes it an E, on the tail for the nozzle petals and the hook, and as three orthographic silhouettes at the technical order drawing's own 100.26 px a metre so a reader can lay them over it at x1.000 and argue; the plan overlay reads about 0.8 per cent WIDE across ON PURPOSE, because the sheet is stretched along the aeroplane, which is the same as being compressed across it, and an orthographic render cannot be either; it is NOT headless, while phantom.gd holds the envelope, both angles, the dogtooth, the quarter-chord sweep, the wing area, the gear and the splitter gap",
	"tomcat_shot": "renders the F-14D Tomcat lit at four wing sweeps -- 20, 44, 68 and 75 degrees -- and as orthographic silhouettes at the F-14D drawing's own 121.1 px a metre, so a reader can lay the swept wing straight over the drawing and argue with it; it is NOT headless, while tomcat.gd holds the spans, the pivot, the wing clear of every other part and one object at every sweep",
	"tomcat_surfaces_shot": "renders the F-14D's stick-driven surfaces lit and close -- spoilers up on the down-going wing, the tailplanes together and apart, both rudders, a swept wing's spoilers and the lockout at 68 degrees -- and the wing at four sweeps, and compares the VAT with the parts by pixels at seven poses, one feature alone and all at once, each saved as parts, vat and difference side by side; it is NOT headless, while tomcat.gd holds the surfaces one axis at a time, from a real wire, clear of every other part and against the VAT by worst vertex",
	"station_shot": "renders a PNG for a human to look at, and is NOT headless -- headless has no rendering device and the file comes back a black rectangle",
	"station_gallery_shot": "renders the forward startup view from every real seat into one PNG per craft and seat; it is NOT headless, while station and fit suites hold the numeric cockpit rules",
	"fighter_shot": "photographs the F/A-18F in the flight level with its gear up in the air, then standing on the Ford's landing area with its gear down, and from both crews' eyes; it is NOT headless, and whether it reads as a Super Hornet has no assertion -- fighter.gd measures the structure",
	"seat_room_shot": "draws the player envelope tests/seat_room.gd measures at the seats it is given -- red where it stands outside the drawn skin, and the view from the eye with every surface double-sided -- so a tight seat can be seen; it is NOT headless, and seat_room holds the numbers",
	"fighter_inspector_shot": "renders a craft's visual scene from exterior, three-quarter, cockpit and inspection angles with dimensions, axes, collider, stations and sockets, posed by --gear and --hook, with --ortho side, front and top views at a fixed scale for laying a reference three-view over and --measure its draw calls, primitives and render time shown against hidden; it is NOT headless, while fighter.gd holds the F/A-18F's measured structure, gear, hook, budget, package, controls and replication",
	"device_gallery_shot": "renders one PNG for every placeable ControlCatalogue part through its real setup path, useful state and fitted camera on a floorless stage; it is NOT headless, while builder and pinch hold the device behavior",
	"hangar_shot": "photographs Hangar 03 in its own level the way the concept sheet draws it -- hero three-quarter, three orthographic elevations, rear three-quarter, the roof from above, the lit interior and the fighter in the open door; it is NOT headless, while tests/hangar.gd holds every dimension, the clear opening, the bays, the solid and the markings",
	"device_yard_gallery_shot": "renders both Device Yard rooms at the 100, 250 and 500 endpoint presets; it is NOT headless, while device_yard and room_load_proof hold density, isolation and transport",
	"bench": "a level you fly, opened from the desk and from --level=seat; it is furniture, not a harness",
	"builder_package_shot": "renders the builder iPad's package save and load buttons for a human to look at; it is NOT headless, while craft_package.gd holds the persistence and compatibility contract",
	"builder_shot": "renders the shared cockpit workshop, parked craft and builder board for a human to inspect; it is NOT headless, while builder_authority and builder_peers hold its data and network rules",
	"merchant_shot": "renders the merchant ships as elevations, from the reference photograph's own angle, beside the Ford and from the helm; it is NOT headless, and the ships have no kind yet, so nothing places them -- tests/merchant_models.gd holds every size, and ship_shot photographs them at sea once the kinds are C++",
	"segment_probe": "a helper another probe includes, with no scene of its own",
	"rota_probe": "times the chore rota against every chore served on time, and the whole tick, at a hundred to five thousand autopilots on the island; the rules are held by tests/rota.gd, and a microsecond has no right answer under other lanes' load",
	"controller_shot": "renders both controllers at rest and with each finger worked for a human to look at -- NOT headless, and whether three millimetres can be seen has no assertion",
	"pedal_shot": "renders the plane's footwell at rest and at full left rudder for a human to look at -- NOT headless, and whether eight centimetres of pedal can be seen from the seat has no assertion",
	"boat_shot": "photographs a small boat driven flat out and then hard over through set_pilot_input, from a chase camera that follows its heading and not its roll, and with --before the same boat on its handling before lane/boats -- NOT headless, and how far it leans is held by tests/handling.gd; --views=dive runs it along the wind-sea from a camera at the sea's height and --at= saves one moment, so a before and an after match, and how deep its bow goes is held by tests/seakeeping.gd",
	"helm_shot": "photographs a boat's two helms from the near seat with the other helm amidships and then hard over, for a human to look at -- NOT headless, and whether a wheel reads as turned is for eyes; that the two agree is held by tests/crew_sync.gd",
	"ocean_height_shot": "renders each ocean shader's own vertex() from above and holds the drawn height to the simulation's swell and the painted detail to no height at all -- NOT headless, because only a rendering device runs a vertex shader; run by hand beside the gate",
	"boat_motion_probe": "prints how much a launch and a patrol boat heave, roll and pitch over a fixed spell, stopped and under way, on the simulated sea -- a number to compare main's library with a lane's, with no right answer of its own; the sea hulls float on is held by tests/sailing.gd",
	"ocean_shot": "photographs the open sea from fixed heights and angles at day, dusk and night on each finish, and times it -- NOT headless, and whether the sea reads as an ocean is for eyes and a frame time has no right answer on somebody else's GPU",
	"water_colour_shot": "photographs the open sea in two level colour settings side by side -- a warm Mediterranean and a cold northern coast -- through WaterSurface.dressed; NOT headless, while water_surfaces and levels hold the colours as numbers",
	"scenery_shot":"renders both finishes from fixed places and times the frames -- NOT headless, and a frame time has no right answer on somebody else's GPU",
	"oil_platform_shot": "photographs the oil platform where OilField puts it -- the silhouette from sea level, a helicopter's approach to the helideck, the jacket at the splash zone, from above, the silhouette and approach again at night, the flare at night from 2 km, from a helicopter passing it and from a boat, and at dusk -- counts the platforms actually in the scene tree, and measures the flare's reflection on the bare sea as warm light in a band under the flame; it is NOT headless, and whether the flare reads as a flame has no assertion, while tests/oil_platform.gd holds the shape, the solid, the helideck and the cost",
	"cooling_shot": "photographs the power station's two cooling towers where PowerStation puts them -- the station and the whole of its steam, and then close enough to judge the waist -- and counts the towers actually in the scene tree; it is NOT headless, and whether a plume reads as steam has no assertion, while tests/cooling_towers.gd holds the hyperboloid, the waist, the winding and the cost",
	"town_lights_shot": "photographs the first city from fixed distances at a time of day, in clear air and mist, and prints what decides how far its lights are seen -- NOT headless, and where a light stops being seen is for eyes and a frame time has no right answer on somebody else's GPU",
	"wake_shot": "photographs a ship's wake from above and astern, from low beside and from far astern, and an aeroplane and the tanker frozen mid-spray skimming the sea -- NOT headless, and a picture has no assertion",
	"contrail_shot": "photographs a contrail behind a frozen aeroplane and in strips as it crosses the height band and ages out, prints how long a contrail and a missile trail are, and times the contrails against none or the trail shaders against older ones -- NOT headless, and a picture and a frame time have no assertion",
	"fx_shot": "photographs the big explosions at fixed moments and times a barrage and a volley against nothing going off -- NOT headless, and a picture and a frame time have no assertion; the rules are held by tests/bursts.gd",
	"sinking_probe": "logs every autopilot aircraft in the real sky for three minutes; the verdicts it found are held by tests/climb.gd, and the log is for a person working out why",
	"net_jump": "two real processes over ENet, started by hand as host and joiner, printing how a joined machine draws the sky; the verdicts it found are held by ashiato-gd/addon/tests/crowd_sight, and a real socket's numbers move with the load on the machine",
	"player_load": "prints what 8, 16, 32 and 64 in-process players cost one host, per step and as a table: host tick, bandwidth down and up, worst update gap and bulk_load's own faults; the user wanted to see how it breaks down, so it reports and never fails on a number",
	"many_seats_shot": "windowed: builds the Chinook with its own four stations and with sixty-four, and prints what each costs to build and draw, and photographs the CREW page of a long cabin; a draw cost has no right answer",
	"wire_budget": "prints what fills a client's tick in the real sky, per component and parked against moving, with the peak; the send budget is sized from it and a byte count has no right answer",
	"streaming_probe": "times what building the island costs piece by piece, counts what it leaves loaded, prices a world sixteen times the size in the simulation, and flies a camera across the map logging memory, draws and frame time -- the windowed parts render, and none of it has a right answer on somebody else's machine",
	"lobby2d_shot": "photographs the flat 2D voice lobby as a host sees it -- three players on two teams and one on neither, with talk on the log -- drawn from a roster handed to the page, in a SubViewport and never the desktop; it is NOT headless, and whether the room is legible is for eyes, while tests/lobby2d.gd holds the rules and tests/lobby2d_peers.gd proves three machines agree",
	"voice_probe": "prints what GodotSteam v4.21-gde's voice calls are and what they answer on a real microphone, and asks the same of Godot's own input on every device this desk offers; it needs a running Steam client and somebody speaking, both properties of the desk and not of the code, so a quiet room reads SKIP",
	"steam_probe": "prints what the GodotSteam binary offers and whether a lobby is found by its join code; it needs a running Steam client, which is a property of the desk and not of the code",
	"steam_quit": "starts a child that hosts over Steam and quits, and reads the child's exit code; it needs a running Steam client, which is a property of the desk and not of the code, and says SKIP without one",
	"notice_shot": "saves the board with a level count-down and a joined notice as PNGs for a human to look at -- NOT headless, and whether a notice reads in a hand has no assertion; what notices do across two machines is held by tests/notices.gd",
	"daytime_shot": "renders the sky at any times from one computed place -- a sunset sequence, dawn, a moonlit night -- or a time-lapse's frames, through the level's own choose_clock; it is NOT headless, and whether a sunset looks like one has no assertion, while tests/daytime.gd holds that the looks blend and the presets are what they were",
	"sky_shot": "saves the clipboard's TIME tab on a host and on a refused joiner as PNGs for a human to look at -- NOT headless, and whether the words read in a hand has no assertion; what they do across three machines is held by tests/sky_peers.gd",
	"craft_shot": "saves the clipboard's CRAFT tab in its groups, at the game's kinds and at sixty-four, and the one grid it was, as PNGs for a human -- NOT headless, and whether a group bar reads as tabs has no assertion; that every craft is one group press away and sixty-four fit is held by tests/craft_page.gd",
	"crew_shot": "saves the clipboard's CREW tab full and nearly empty as PNGs for a human to look at -- NOT headless, and whether a seat's role and a JOIN read in a hand has no assertion; that the full page fits and the beam on JOIN seats you is held by tests/clipboard.gd",
	"spotting_board_shot": "saves the clipboard's SPOTTING tab off, on MEDIUM and on HIGH with a 1 km limit as PNGs for a human to look at -- NOT headless, and whether the words read in a hand has no assertion; that the beam on each button sets and keeps it is held by tests/spotting.gd",
	"spotting_shot": "photographs one headset eye (2890 x 3091, 96 degrees) with a fighter at 1, 2, 3, 5 and 10 km, off and at each spotting size, a grid of each fighter's pixels, and with --reel a fighter flying in from 8 km past the eye -- NOT headless, and whether a far fighter is easier to see and its shrink unnoticed is for eyes; the curve and that nothing else changes are held by tests/spotting.gd",
	"lamp_beam_shot": "counts a signal lamp's pixels 1.5 km off in the real level, by day and at night, aimed at the eye, a little off and well away, and writes a picture of each -- NOT headless; lamp_wire and lamp_peers hold the lamp's state on the wire, this holds that the far beam is seen and its cone falls away",
	"build_stamp_shot":"photographs the build stamp in the lower right of the window over the island by day or at night (--time=), a close crop of it, and the clipboard held up with the build line on its frame, from the desktop and from 40 cm in front of the glass -- NOT headless, and whether small light writing reads over sky and sea is for eyes; build_stamp holds that it is there, on top, in the corner and the right words",
	"level_shot": "saves the desk's level row, the whole desk from the chair, a refused join on the desk and the clipboard's LEVEL line as PNGs for a human to look at -- NOT headless; that the row chooses and the refusal's words are held by tests/levels.gd and tests/level_hello.gd",
	"code_pad_shot": "saves the desk's session screen with the join code's keypad up as a PNG for a human to look at -- NOT headless, and whether the keys read has no assertion; that they are on the glass and press is held by tests/code_pad.gd",
	"eye_shot": "draws a runway light at the origin and 7 km out and reads back where a shader thinks the eye is, on whichever editor runs it -- NOT headless, and what it exists to catch is a difference between the stock and double editors; the rule it found is held headless by tests/lint.gd",
	"shake_shot": "reads back frame after frame of a still panel and a runway light far from the origin -- NOT headless, and its verdicts are about the double editor, which the gate's headless runs cannot draw (agents.md, \"What the double build does and does not steady\")",
	"billboards_shot": "reads back frame after frame of a contrail, a burst and a missile plume riding a still craft at the origin, 9.46 km and 60 km -- NOT headless, and its verdicts are about the double editor, which the gate's headless runs cannot draw -- nor read back, since a headless MultiMesh reads every instance as the identity",
	"vr_fallback_shot": "presses V with no OpenXR runtime and reads what the rig is left in -- NOT headless, because a headless rig never asks OpenXR, and a machine with a headset running would answer differently",
	"radio_shot": "saves the host AUDIO tab with its phrase buttons, typed line and sent-player status -- NOT headless; codec quality is held by tests/radio_clip.gd and host/model-free-client playback by tests/radio_peers.gd",
	"canyon_shot": "photographs the gorge -- the whole canyon from high up, its rim, and four from inside at the height a fighter flies it -- because whether a canyon with a river in the bottom LOOKS like one is the half of it tests/canyon.gd cannot have",
	"rivers_survey": "prints every lake the generated levels catalogue against the band inside which the ocean shaders move nothing, which is set by `land_half` and was the island's 7,200 m on every level; it found 30 of the 54 outside it, and it is the survey the shore and river work is judged against",
	"alpine_probe": "measures what the ground's tuning built -- land, collision cells and their relief, slopes at 16 m, and the height every town and airfield is joined at -- and draws the map; none of it has a right answer, and the design reads it",
	"ground_view_shot": "photographs GroundView's levels from 400 m and 3 km over the highest range, as drawn and with each level tinted -- windowed, so it has a picture, which headless does not; tests/ground_view.gd holds the geometry",
	"moon_shot": "photographs the moon close and at a headset's scale on both finishes, and holds the drawn disc to the light's direction and its lit side to the sun -- NOT headless, because only a drawn picture can say where the sky put the moon; the moon's numbers reaching both skies are held by tests/scenery.gd",
	"star_shot": "photographs the stars at night, by day and at evening on both finishes, measures the brightest stars' width and follows each as the camera turns a quarter of a pixel a frame -- NOT headless, because only a drawn picture shows a star's size and shimmer; that the stars are asked for at night and not by day is held by tests/scenery.gd",
	"pirate_shot": "photographs the pirate ship at the waterline, on a beam reach, running, mid-tack, from 2 km and at dusk on both finishes -- NOT headless, and whether sails read as sails and a hull sits in the sea is for eyes; the sailing is held by tests/sailing.gd, the drawing's arithmetic by tests/brig.gd",
	"terrain_probe": "prints the C++ ground's hashes and cost, draws the whole world as a map, measures level-of-detail cracks, and photographs cells of terrain beside today's island -- the verdicts it found are held by tests/ground_field.gd, and the windowed part renders",
	"jumbo": "holds the 747-400's printed dimensions and mass and honest station roles, the drawn model's hump and scale, immutable builder package, pilot/copilot handling, and real client selection/control replication",
	"buildings_gallery_shot": "one fitted picture of every KIND of building the game draws -- each hangar type the base's own standards list, a revetment, the control tower, one town building of each TownPlan.Roof and each standalone building -- stamped with the commit and the time it was taken and with its nearest other building named; it is NOT headless, and whether a building reads as a building has no assertion, while tests/airbase.gd holds the base's layout, tests/smoke.gd the towns' boxes and tests/hangar.gd Hangar 03's dimensions",
	"airbase_shot": "photographs the island's air base from the air, straight down at a printed scale, from the tower cab and from a cockpit taxiing -- NOT headless, and whether it reads as an air base has no assertion; its layout, clearances, collision and taxi route are held by tests/airbase.gd",
	"hawkeye_shot": "photographs the E-2D in the air from the front quarter, the side and overhead on both finishes, from the pilot's and a mission officer's seats, and parked on the carrier's deck with its wings folded through its real bus -- NOT headless, and whether the airframe reads as itself has no assertion; the fold's bus is held by tests/fleet_shapes.gd",
	"railgap_shot": "photographs the ground beside the island railway from one survey point, at eye height beside the track and from 700 m above -- NOT headless, run before and after a change to how near rock may come to the line; the distances and the drawn-rock-on-the-track check are held headless by tests/mountains.gd",
	"train_shot": "photographs the island railway's train -- the whole rake from the air, broadside and orthographic at a stated pixel scale for laying over the reference, and one boxcar close and orthographic -- NOT headless, and whether eight to ten cars behind a locomotive read as a freight train has no assertion; every dimension of the car and the rake is held headless by tests/train_models.gd",
	"craft_gallery_shot": "photographs the first craft of every kind the level places, one picture a kind, fitted to its drawn size from ahead and above -- NOT headless, and whether a craft reads as itself has no assertion; the fleet's shapes are held by tests/fleet_shapes.gd",
	"ship_shot":"photographs every boat and the level's submarine broadside and from the bow quarter near and far, the carrier from overhead and at dusk, and the view from each helm, on both finishes, and prints the draw calls and primitives each ship adds to a frame -- NOT headless, and whether a ship reads as itself has no assertion; its parts and seats are held by tests/carrier_shape.gd",
	"rotor_flight_probe": "flies each helicopter with a scripted pilot's hands through a client's controls -- hands off at the hover, ten degrees nose down, a twenty-degree bank with the pedals still and then with them keeping the nose on the track, a flare to a stop and a let-down -- and prints how it went; how a craft handles is read by a person, and the rates are held by tests/rotor_rates.gd",
	"rotor_probe": "prints the three helicopters' native extents, seat poses and every drawn mesh's vertex box in the craft's own frame, which is what `lane/rotors` read before every picture -- it has no right answer; the helicopters are held by tests/shell_room.gd, tests/joined_parts.gd, tests/named_parts.gd and tests/uh60.gd",
	"deck_cost_probe": "times the simulation tick with a carrier under way, alone and with twelve aeroplanes parked on its deck, and says which library it ran on -- a microsecond has no right answer under other lanes' load, so it is run on main's library and the lane's interleaved and the difference is what is read",
	"director_cost": "times a second view of the world -- a SubViewport at four sizes and a separate Window -- against a baseline that draws it once, strictly interleaved; NOT headless, because headless has no rendering device, and a frame time has no right answer on somebody else's GPU. What the director's camera DOES is held by tests/director.gd",
	"director_shot": "photographs the cockpit with the director's camera in it and the picture that camera puts in the second window, at both ends of its lens -- NOT headless, and whether a tally light the size of a thumbnail reads as lit from the seat has no assertion; the switch, the light, the field of view and the beam rule are held headless by tests/director.gd",
	"mist_multiview": "renders the watch level through a two-view XR SubViewport fed by a scripted XRInterfaceExtension, compute mist against the spatial pass, for eyes to compare -- NOT headless, and not runnable under --xr-mode off at all: that flag turns the renderer's multiview shader variants off, so it runs with OpenXR off by override.cfg in a scratch tree (agents.md, the --xr-mode off trap); each eye's projection is held headless by tests/mist.gd",
	"ranging_sight_shot": "photographs the battleship gunner's ranging sight from the turret seat and measures off the picture's own pixels that a hull of known length at known range subtends the mils the scale says, then photographs a splash at five and six kilometres as it swells and burns out -- NOT headless, because only a drawn picture has pixels; that each mark is placed at its angle and the desk keys lay the gun is held headless by tests/ranging_sight.gd",
	"bake_shot": "renders one craft, or the air base's west hangar authored as boxes, twice in a bare room -- as its parts and poured into a Casting -- counts both with the renderer's own counters, compares the pictures pixel for pixel and flies the Cessna's surfaces through a server and client loopback; it is NOT headless, and it is the research behind research/static_bake.md, not a gate",
	"bake_survey": "prints, for every craft kind built from outside, the instances and surfaces it draws as parts and what a Casting would leave; headless and always PASS unless a casting would draw more than its parts, because it is a research table for research/static_bake.md and not a rule the fleet is held to",
	"vat_shot": "flies the Cessna's surfaces through a server and client loopback on its parts, on a Casting posed only when a hinge moves and on a HingeCasting that turns each surface in the vertex shader, and compares the pictures; with --many it times 100 of them against 100 as parts in alternated pairs -- NOT headless, and the research behind research/vertex_animation.md, not a gate",
}

## PATHS agents.md NAMES THAT ARE NOT IN THIS PROJECT, and why each is out of reach.
##
## Every one of these is real and is somewhere this suite cannot see: the extension's C++,
## its gitignored sibling checkouts, and the workshop around the game. Naming them is better
## than not naming them, so the check is scoped rather than the mentions removed.
const ELSEWHERE: Array[String] = [
	"../ashiato-gd/",
	# The voice's C++ and its build and fetch scripts, beside the game. See agents.md, "A VOICE ON THE RADIO".
	"../kokoro-gd/",
	"../pid-control/",
	"../previous_projects/",
	"../_tools/",
	"src/",
	"client/",
	"tools/",
	"modules/",
	"misc/",
]

var _failures: PackedStringArray = []
## Sections that reached their own end. A GDScript error aborts the function it is in and
## carries on with the next, so a suite that counts only failures reports a cheerful pass
## over a section that fell over.
var _sections: int = 0
var _agents: String = ""


func _check(label: String, ok: bool, detail: String) -> void:
	print("[docs] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	var parts: PackedStringArray = [_read(AGENTS)]
	var names: PackedStringArray = ["agents.md"]
	for area in _area_docs():
		parts.append(_read(area))
		names.append(area.trim_prefix("res://"))
	_agents = "\n".join(parts)
	_check("there_is_an_agents_md_to_check", _agents.length() > 10000,
		"%d characters, %d lines over %d files: %s"
			% [_agents.length(), _agents.count("\n") + 1, names.size(), ", ".join(names)])
	if _agents.is_empty():
		_finish()
		return
	_every_level_it_names_is_a_door()
	_every_test_scene_is_a_suite_or_a_named_probe()
	_every_path_in_a_backtick_exists()
	_every_craft_and_channel_it_names_is_in_the_enum()
	_the_index_names_every_area_file()
	_check("every_section_of_the_suite_ran", _sections == 8, "%d of 8" % _sections)
	_finish()


## ---- the doors -------------------------------------------------------------------------

## EVERY `--level=` IN THE DOCUMENT IS A WORD THE ROUTER ACCEPTS, and every word the router
## accepts is in the document.
##
## Both directions, and the second is the one that catches a feature landing without a line
## in the map. A door nobody has written down is a door nobody finds; a door written down
## that the router does not answer to is a command line that silently opens the desk instead,
## which looks exactly like the game ignoring you.
func _every_level_it_names_is_a_door() -> void:
	# WORD -> SCENE, from the two tables that are the only places doors are written down.
	var doors: Dictionary = {}
	for word in BootRouter.DOORS:
		doors[String(word)] = String(BootRouter.DOORS[word])
	for word in MarshallingLevel.DOORS:
		doors[String(word)] = String(MarshallingLevel.DOORS[word])

	var named: Dictionary = {}
	var finder := RegEx.new()
	finder.compile("--level=([A-Za-z0-9_]+)")
	for hit in finder.search_all(_agents):
		named[hit.get_string(1).to_lower()] = true

	var strangers: PackedStringArray = []
	for word in named:
		if not doors.has(word):
			strangers.append(String(word))
	strangers.sort()
	_check("every_level_agents_md_names_is_a_door_the_router_opens", strangers.is_empty(),
		"%s" % ["all %d of them" % named.size() if strangers.is_empty() else strangers])

	# AND THE OTHER WAY, BY DESTINATION AND NOT BY WORD. A level the router can open that
	# nothing has written down is a level nobody will ever type -- and that is the claim
	# worth holding. Demanding every ALIAS be documented is not: the aliases exist so a
	# person typing a command line does not have to remember whether the observer is `watch`
	# or `nobody`, and a document listing all fifteen would be a document nobody reads.
	var unwritten: PackedStringArray = []
	for scene in _destinations(doors):
		var said: bool = false
		for word in doors:
			if doors[word] == scene and named.has(String(word)):
				said = true
		if not said:
			unwritten.append(String(scene))
	unwritten.sort()
	_check("and_every_level_the_router_opens_is_written_down", unwritten.is_empty(),
		"%d scenes behind %d words%s" % [_destinations(doors).size(), doors.size(),
			"" if unwritten.is_empty() else ": %s" % unwritten])
	_sections += 1


## ---- the suites ------------------------------------------------------------------------

## EVERY TEST SCENE IS EITHER IN THE RUNNER'S LIST OR IS A NAMED PROBE.
##
## The failure this catches is a suite written, committed and never run -- which is the
## quietest kind of test there is, and which this project has had: `hitch_probe` measured the
## three numbers that would catch its most expensive bug and sat outside `suites.txt` for
## months, so a regression in any of them was caught only if somebody remembered.
func _every_test_scene_is_a_suite_or_a_named_probe() -> void:
	var listed: Dictionary = {}
	for line in _read(SUITES).split("\n"):
		var row: String = line.strip_edges()
		if row.is_empty() or row.begins_with("#"):
			continue
		var parts: PackedStringArray = row.split(" ", false)
		if parts.size() >= 3:
			# name -> {project, scene}. The PROJECT column matters: the addon's suites have
			# `res://tests/` paths too, and they resolve inside a sibling project this run
			# cannot see. Filtering on the path instead reported all eleven as missing.
			listed[parts[0]] = {"project": parts[1], "scene": parts[2]}

	var scenes: Dictionary = {}
	for name in listed:
		scenes[String((listed[name] as Dictionary)["scene"])] = true
	var homeless: PackedStringArray = []
	var found: int = 0
	for where in TEST_DIRS:
		for scene in _scenes_in(where):
			found += 1
			var stem: String = scene.get_file().get_basename()
			if scenes.has(scene) or PROBES.has(stem):
				continue
			homeless.append(scene)
	homeless.sort()
	_check("every_test_scene_is_in_suites_txt_or_is_a_named_probe", homeless.is_empty(),
		"%d scenes, %d suites, %d probes%s" % [found, listed.size(), PROBES.size(),
			"" if homeless.is_empty() else ": %s" % homeless])

	# AND EVERY SUITE IN THE LIST POINTS AT SOMETHING. A scene that has moved does not fail,
	# it TIMES OUT three minutes later, which reads as a hang in the code under test.
	var missing: PackedStringArray = []
	for name in listed:
		var row: Dictionary = listed[name]
		if String(row["project"]) != "cockpit":
			continue
		if not FileAccess.file_exists(String(row["scene"])):
			missing.append("%s -> %s" % [name, row["scene"]])
	_check("and_every_cockpit_suite_in_the_list_is_a_scene_that_exists", missing.is_empty(),
		"%s" % ["all of them" if missing.is_empty() else missing])

	# AND A PROBE NAMED HERE STILL EXISTS. An exclusion for a file that has gone is an
	# exclusion quietly covering for whatever takes its name next.
	var ghosts: PackedStringArray = []
	for stem in PROBES:
		if not FileAccess.file_exists("res://tests/%s.gd" % stem):
			ghosts.append(String(stem))
	_check("and_every_probe_this_test_excuses_is_still_there", ghosts.is_empty(),
		"%s" % ["all %d" % PROBES.size() if ghosts.is_empty() else ghosts])
	_sections += 1


## ---- the paths -------------------------------------------------------------------------

## EVERY FILE agents.md NAMES IN A BACKTICK IS A FILE THAT IS THERE.
##
## This is the cheapest and highest-yield of the four, because a document this size renames
## things faster than it re-reads itself: `objects/cockpits/` became `objects/seats/` and the
## old name lived on in three paragraphs -- a document nobody reads end to end, pointing at a
## directory that is not there.
##
## SCOPED TO THIS PROJECT. The document legitimately names the extension's C++, its sibling
## checkouts and the workshop around it, none of which this run can see -- see ELSEWHERE.
func _every_path_in_a_backtick_exists() -> void:
	var looks_like := RegEx.new()
	# A path is something with a slash in it and a file extension this project uses. The
	# extension list is what keeps `/user/hand/left/output/haptic` and `s/x/y/` out of it.
	# A DIRECTORY IS WHAT MAKES IT A PATH. A bare `sky.gd` or `run_all.sh` in a backtick is
	# a NAME -- the document says "see `sky.gd`" a dozen times and means the file it has
	# already told you where to find -- and treating those as paths reported eleven
	# non-existent files in the project root, none of which was drift.
	looks_like.compile("^(res://)?[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)+\\.(gd|tscn|tres|gdshader|md|cfg|txt|sh|ps1)$")

	var ticked := RegEx.new()
	ticked.compile("`([^`\n]+)`")
	var seen: Dictionary = {}
	for hit in ticked.search_all(_agents):
		# The first word: the document writes `tools/build.ps1 -WithCockpit` and the
		# arguments are not part of the path.
		var first: String = hit.get_string(1).strip_edges().split(" ")[0]
		if looks_like.search(first) == null:
			continue
		if _is_elsewhere(first):
			continue
		seen[first] = true

	var gone: PackedStringArray = []
	for path in seen:
		var where: String = String(path)
		if not where.begins_with("res://"):
			where = "res://" + where
		if not (FileAccess.file_exists(where) or DirAccess.dir_exists_absolute(where)):
			gone.append(String(path))
	gone.sort()
	_check("every_path_agents_md_names_in_this_project_exists", gone.is_empty(),
		"%d paths checked%s" % [seen.size(), "" if gone.is_empty() else ": %s" % gone])
	_sections += 1


## The distinct scenes behind a word-to-scene table. Five doors onto one bench is one level.
func _destinations(doors: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for word in doors:
		if not String(doors[word]) in out:
			out.append(String(doors[word]))
	return out


func _is_elsewhere(path: String) -> bool:
	# ANYTHING THAT CLIMBS OUT OF res:// IS BEYOND THIS RUN, whatever it is called. The area
	# files under `docs/` sit one directory deeper than `agents.md`, so the same sibling
	# checkout is written `../../ashiato-gd/` there and `../ashiato-gd/` here; keying the
	# exclusion on the spelling would have meant listing both spellings and forgetting one.
	if path.begins_with("../"):
		return true
	for prefix in ELSEWHERE:
		if path.begins_with(prefix):
			return true
	return false


## ---- the index ------------------------------------------------------------------------

## THE INDEX NAMES EVERY AREA FILE, AND NO SECTION LIVES IN TWO OF THEM.
##
## `agents.md` became five files on 2026-09-20 and grew an index saying which one answers
## which question. An index is a hand-written list, which is the one thing this file's own
## header forbids: it goes stale the afternoon somebody adds a sixth file or moves a section,
## and it does it SILENTLY, because a reader sent to the wrong file assumes they
## misremembered. This is what holds it.
##
## THREE WAYS IT CAN ROT, and all three fail here:
##
##   - a file under `docs/` the index never mentions -- a session is never sent to it, so it
##     is invisible however good it is;
##   - an index row naming a file that is not there -- the same class as the `../Agents.md`
##     link that resolved on Windows and was dead on the Linux workstation;
##   - a `## ` heading in two files at once, which is how a move loses an edit: the copies
##     drift and the one you read is whichever you happened to open.
##
## WHAT IT DELIBERATELY DOES NOT CHECK: that a heading sits in the RIGHT file, or that the
## question a row asks is the right question. Neither is derivable, and a check that guessed
## would be a hand-written list wearing a function's clothes.
func _the_index_names_every_area_file() -> void:
	# THE WORKING COPY OF THIS DOCUMENT IS CRLF ON THIS MACHINE, so a line split on a bare
	# newline carries a trailing carriage return and never equals a constant. The first run
	# of this check reported no index at all against a file that plainly had one, so every
	# comparison here is against a stripped line.
	var lines: PackedStringArray = _read(AGENTS).split("\n")
	var first: int = -1
	for n in lines.size():
		if lines[n].strip_edges() == INDEX_HEADING:
			first = n
			break
	_check("agents_md_still_has_an_index", first != -1, "looking for %s" % INDEX_HEADING)
	_sections += 1
	if first == -1:
		return

	var named: Dictionary = {}
	for n in range(first + 1, lines.size()):
		var line: String = lines[n].strip_edges()
		if line.begins_with("## "):
			break
		var at: int = line.find(AREA_PREFIX)
		while at != -1:
			# `../pid-control/docs/STRATEGY.md` is a sibling project's file, not an index
			# row, and the first run of this check reported it as a missing area file. A
			# row names the folder from the top of this project, or it is not a row.
			var before: String = "" if at == 0 else line.substr(at - 1, 1)
			if before != "/" and before != "." and before != "-":
				var rest: String = line.substr(at)
				var stop: int = rest.find(".md")
				if stop != -1:
					named[rest.substr(0, stop + 3)] = true
			at = line.find(AREA_PREFIX, at + 1)

	var on_disk: Dictionary = {}
	for path in _area_docs():
		on_disk[path.trim_prefix("res://")] = true

	var unnamed: PackedStringArray = []
	for path in on_disk:
		if not named.has(path):
			unnamed.append(String(path))
	unnamed.sort()
	_check("the_index_names_every_file_under_docs", unnamed.is_empty(),
		"%d files, %d rows%s" % [on_disk.size(), named.size(),
			"" if unnamed.is_empty() else ": %s named by no row" % unnamed])
	_sections += 1

	var absent: PackedStringArray = []
	for path in named:
		if not on_disk.has(path):
			absent.append(String(path))
	absent.sort()
	_check("every_file_the_index_names_is_there", absent.is_empty(),
		"%d rows%s" % [named.size(),
			"" if absent.is_empty() else ": %s is not there" % absent])
	_sections += 1

	# ONE SECTION, ONE FILE. Read from the files themselves, never from a list.
	var home: Dictionary = {}
	var twice: PackedStringArray = []
	var every: PackedStringArray = _area_docs()
	every.append(AGENTS)
	for path in every:
		for raw_line in _read(path).split("\n"):
			var line: String = raw_line.strip_edges()
			if not line.begins_with("## "):
				continue
			var heading: String = line.substr(3).strip_edges()
			if home.has(heading):
				twice.append("%s (%s and %s)"
					% [heading, home[heading], path.trim_prefix("res://")])
			else:
				home[heading] = path.trim_prefix("res://")
	twice.sort()
	_check("no_section_heading_lives_in_two_files", twice.is_empty(),
		"%d headings over %d files%s" % [home.size(), every.size(),
			"" if twice.is_empty() else ": %s" % twice])
	_sections += 1


## ---- the enums -------------------------------------------------------------------------

## EVERY CRAFT AND EVERY BUS CHANNEL THE DOCUMENT NAMES IS ONE THE SIMULATION HAS.
##
## Both directions again, and the interesting one is the second: a kind added in the C++ and
## never written about is a craft nobody knows is there. That has already happened once --
## the seventeenth kind cost a bit on the wire, and this file predicted it in advance, which
## is the standard the rest of the document is held to.
##
## OFF THE ENUM, never off a list here. `Sim.Kind.keys()` is what `Sim.kind_name` reads and
## is what the simulation's own shape table is named from.
func _every_craft_and_channel_it_names_is_in_the_enum() -> void:
	var kinds: Dictionary = {}
	for kind in range(Sim.Kind.size()):
		kinds[Sim.kind_name(kind)] = true

	# `Sim.Kind.NAME`, wherever it is written -- in a backtick or in prose.
	var written := RegEx.new()
	# Digits are valid enum-name characters too. UH60 exposed the old expression's silent
	# truncation to `UH`, which then looked like a documentation typo rather than a parser bug.
	written.compile("Sim\\.Kind\\.([A-Z0-9_]+)")
	var strangers: PackedStringArray = []
	var mentions: int = 0
	for hit in written.search_all(_agents):
		mentions += 1
		if not kinds.has(hit.get_string(1).to_lower()):
			strangers.append(hit.get_string(1))
	_check("every_Sim_Kind_agents_md_names_is_in_the_enum", strangers.is_empty(),
		"%d mentions%s" % [mentions, "" if strangers.is_empty() else ": %s" % strangers])

	# AND EVERY KIND IS MENTIONED SOMEWHERE. The simulation's own word for it, which is what
	# the HUD, the clipboard and the function keys all show.
	var unwritten: PackedStringArray = []
	for name in kinds:
		if not _agents.contains(String(name)):
			unwritten.append(String(name))
	unwritten.sort()
	_check("and_every_craft_in_the_simulation_is_written_about", unwritten.is_empty(),
		"%s" % ["all %d kinds" % kinds.size() if unwritten.is_empty() else unwritten])

	# THE COMMAND BUS, the same way. `Sim.Channel` is what every lever declares and what
	# `craft_schema` fits.
	var channels: Dictionary = {}
	for named in Sim.Channel:
		channels[String(named)] = true
	var channel_written := RegEx.new()
	channel_written.compile("Sim\\.Channel\\.([A-Z_]+)")
	var unknown: PackedStringArray = []
	for hit in channel_written.search_all(_agents):
		if not channels.has(hit.get_string(1)):
			unknown.append(hit.get_string(1))
	_check("and_every_Sim_Channel_it_names_is_in_the_enum", unknown.is_empty(),
		"%d channels%s" % [channels.size(), "" if unknown.is_empty() else ": %s" % unknown])

	# AND EVERY MOVEMENT MODEL. There are eight and the document has a table of them; a model
	# added in the C++ with no row is a way of flying nobody knows about.
	# CASE-INSENSITIVELY. The document writes the simulation's own spelling, `Model::Fixed`,
	# and the enum is `FIXED`; insisting on the enum's shout would be this test telling the
	# prose how to spell rather than checking that the thing is described.
	var said_about: String = _agents.to_lower()
	var models: PackedStringArray = []
	for named in Sim.Model:
		if not said_about.contains(String(named).to_lower()):
			models.append(String(named))
	_check("and_every_movement_model_is_written_about", models.is_empty(),
		"%s" % ["all %d models" % Sim.Model.size() if models.is_empty() else models])
	_sections += 1


## ---- reading the disk --------------------------------------------------------------------

## agents.md and suites.txt are not resources. Read with `FileAccess`, which a headless run
## from the project directory does straight off the disk.
## Every area file of the document, enumerated off the disk and sorted so a run is repeatable.
func _area_docs() -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(AREA_DOCS)
	if dir == null:
		return found
	for name in dir.get_files():
		if name.ends_with(".md"):
			found.append("%s/%s" % [AREA_DOCS, name])
	found.sort()
	return found


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _scenes_in(where: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(where)
	if dir == null:
		return found
	for name in dir.get_files():
		# `.remap` is what an exported project calls an imported file; a source checkout has
		# the plain name and both should be counted once.
		if name.ends_with(".tscn"):
			found.append("%s/%s" % [where, name])
	return found


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)

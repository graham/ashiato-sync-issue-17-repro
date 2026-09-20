extends Node3D
class_name FlightLevel
## The level: builds the world into the simulation, then draws whatever the simulation
## says is in it.
##
## The direction of that sentence is the architecture. Nothing in this scene tree is
## authoritative. There are no RigidBody3Ds, no MultiplayerSynchronizers and no RPCs about
## where anything is.
##
## The draw order below is load-bearing and is the reason this file has a `_process` at
## all:
##
##   1. every vehicle node is placed, by interpolating the last two simulated states;
##   2. riders are already CHILDREN of those nodes, so they arrive for free.
##
## Step 2 is not a step. That is the point: a pilot's pose relative to their cockpit is
## never computed, so it cannot be computed wrongly, late, or twice.

const VEHICLE_SCENE: PackedScene = preload("res://objects/vehicles/vehicle_view.tscn")
const RIG_SCENE: PackedScene = preload("res://player/pilot_rig.tscn")
const SHOT_YARD := preload("res://objects/weapons/shot_yard.gd")
const MISSILE_YARD := preload("res://objects/weapons/missile_yard.gd")
const CONTRAIL_YARD := preload("res://objects/vehicles/contrail_yard.gd")
const DAMAGE_YARD := preload("res://objects/weapons/damage_yard.gd")
const WAKE_YARD := preload("res://objects/vehicles/wake_yard.gd")
const SPRAY_YARD := preload("res://objects/vehicles/spray_yard.gd")
const MONITOR_YARD := preload("res://objects/vehicles/monitor_yard.gd")
const EXHAUST_YARD := preload("res://objects/vehicles/exhaust_yard.gd")
const FIRE_YARD := preload("res://objects/weapons/fire_yard.gd")
const LIFT_YARD := preload("res://world/lift_yard.gd")
## Laps for the scenery probe; nothing unless it is running. See `world/stopwatch.gd`.
const STOPWATCH := preload("res://world/stopwatch.gd")
const PILOT_SCENE: PackedScene = preload("res://player/remote_pilot.tscn")

## The island and everything standing on it, built identically on every machine from
## Terrain -- see the note at the top of that file for why it is generated rather than
## placed, and why the randomness is not the engine's.
##
## The Ground mesh in the scene is sized to match GROUND_HALF, and has to be: a client
## whose land ends somewhere else predicts itself into the sea.
const GROUND_HALF := Terrain.GROUND_HALF

## How tall the waypoint beacon stands. Taller than the mountains, because a marker you
## cannot see over the terrain is a marker for somewhere you already are.
const BEACON_HEIGHT: float = 1400.0

## The fine finish's grass. See the note at the top of it, and `_wear_the_finish`. The rock's two shaders are
## `SceneryYard`'s, which draws the rock.
const GRASS_FINE: Shader = preload("res://world/shaders/grass_fine.gdshader")

## THE RUNWAY'S PAVEMENT, both tiers. The asphalt and the paint are one MultiMesh and wear one of these; which, and
## what the two differ by, is `pavement.gdshader`'s doc block, and how near their detail comes in is `DetailReach`.
const PAVEMENT: Shader = preload("res://world/shaders/pavement.gdshader")
const PAVEMENT_FINE: Shader = preload("res://world/shaders/pavement_fine.gdshader")

## Sea level, which is what a boat's buoyancy is measured against. The Sea mesh sits a
## couple of centimetres under it so it does not fight the island for the same pixels.
const SEA_LEVEL: float = Terrain.SEA_LEVEL

@onready var _vehicles_root: Node3D = $Vehicles
@onready var _status: Label = $Ui/Status

var rig: PilotRig = null
## The camera, when there is nobody flying. Exactly one of these two is ever set.
var observer: Observer = null
## Which server entity each NAMED spawn became: see `spawned_entity`.
var _spawned: Dictionary = {}
## Every round in the air, and every burst. One node for all of them: see ShotYard.
var shots: ShotYard = null
## Every missile in the air, its motor and its trail. See MissileYard.
var missiles: MissileYard = null
## Every aircraft's contrail above the height `TrailTuning` names, worn from the missile yard's trails. See ContrailYard.
var contrails: ContrailYard = null
## Every hit craft's smoke, and the fireball where one died (lane/combat). See DamageYard.
var damage: DamageYard = null
## THIS PLAYER'S VIEW OF THEIR OWN WRECK, until the respawn (lane/combat). See CrashOverview.
var overview: CrashOverview = null
## THE HOST PUTTING CREWS BACK IN THE AIR; null on a joiner. See CrewRespawn.
var respawner: CrewRespawn = null
## THE LEVEL'S WANDERING AIR TRAFFIC and the pilot that soars its gliders; null on a joiner and on a level with no
## `air_traffic.json`. See AirTraffic.
var air_traffic: AirTraffic = null
var soaring: SoaringPilot = null
## THE BAD ATTACKERS, and the host's tactics for them (lane/combat). See Attackers.
var attackers: Attackers = null
## Every moving hull's wake, laid on the water as a contrail is laid in the sky. See WakeYard.
var wakes: WakeYard = null
## The whitewater kicked up by anything skimming the water fast. See SprayYard.
var spray: SprayYard = null
## Every fireboat monitor's water. See MonitorYard.
var monitors: MonitorYard = null
## Every aircraft's thrust exhaust, and the dust or spray its wash raises off the surface under it. See ExhaustYard.
var exhaust: ExhaustYard = null
## Every big explosion -- a heavy shell's and a missile's -- from one pool built at load. See BurstYard.
var bursts: BurstYard = null
## EVERY FIRE ON THE ISLAND, drawn. Replicated, unlike the scenery, because fires change --
## see FireState -- so this is fed from the wire rather than from Terrain.
var burning: FireYard = null
## WHERE THE AIR GOES UP, drawn as the sky itself: a cumulus over every thermal. Built from
## the same table the simulation was given -- see LiftYard -- because a lift zone is
## generated on every peer and is not on the wire at all.
var lift: LiftYard = null
## THE CLOUDS AS FOG NEAR THE EYE, on Forward+ (null on a renderer with no volumetric fog, or with `--clouds=lumps` or
## `--clouds=none`). It draws on FINE; on PLAIN the mesh clouds are the whole sky. See CloudBank.
var clouds: CloudBank = null
## THE CLOUDS, AS PUFFS (2026-09-17, the user: "all clouds look good"): a cloud over every thermal and a layered sky of six
## kinds from the ground to nine kilometres, transparent ellipsoids you fly into and out of. See PuffSky. Null when the level
## was asked for the older lumps (`--clouds=lumps`, or `--clouds=fog`, whose fog is laid out from the lumps) or for none.
var puffs: PuffSky = null
## THE SKY'S SEED: the same on every peer, as the ground's is, so no cloud is on the wire; the host decides only whether
## there are clouds (`Net.clouds_on`).
const PUFF_SEED: int = 1917
## THE LOW MIST OVER THE WHOLE VIEW, on both finishes, told the time of day and the finish by the level. See MistLayer.
var mist: MistLayer = null
## THE EYE IS IN A CLOUD: how dense the densest cloud it is in is there, 0 to 1, and which cloud (`LiftYard.cloud_key`).
## Asked of the clouds once a frame and announced when it changes; `_on_eye_in_cloud` decides what it does.
signal eye_in_cloud(depth: float, key: Vector2i)
## What was last announced, for the tests.
var eye_depth: float = 0.0
var eye_cloud: Vector2i = Vector2i.ZERO
## THE SEA ON THE FINE FINISH. See SeaSwell; the plain sea is the `Sea` node in the scene.
var swell: SeaSwell = null
## BLADES OF GRASS round the eye, on the fine finish. See GrassBlades.
var grass: GrassBlades = null
## THE TOWNS, their streets and the roads between them, drawn from the same boxes. See TownView.
var towns: TownView = null
## THE COOLING TOWERS AND THEIR STEAM, stood beside a town rather than at typed coordinates. See PowerStation.
var stations: PowerStation = null
## THE OIL PLATFORMS, out at sea on the sea floor, placed by the depth each world gives them. See OilField.
var oil_field: OilField = null
## THE TIME OF DAY: the sun, the sky and the fog, written once per change. See Daylight, and `choose_time`.
var daylight: Daylight = null
## Session music: files are local, while track, start frame and fade are the host's small replicated state.
var music: MusicBox = null
## THE ISLAND'S SOLID BOXES, built ONCE per session in _build, and the same list filed by place. Everything that
## asks where a machine may go or where a fire may catch is handed these rather than rebuilding the island. See BoxGrid.
var _solid: Array[Dictionary] = []
var _grid: BoxGrid = null
## THE WOODS: trees that are only a picture, grown once from `Forests` and the same boxes the
## simulation is given, and never handed to it. See Woodland.
var woodland: Woodland = null
## The ground's two materials: the one in the scene, and the same numbers on the fine shader.
var _ground_plain: ShaderMaterial = null
var _ground_fine: ShaderMaterial = null
## The runway pavement's two materials, made once in `_draw_runway` and swapped by `_wear_the_finish`.
var _runway_plain: ShaderMaterial = null
var _runway_fine: ShaderMaterial = null
## THE RUNWAY FRAME THIS LEVEL HANDED EVERY MARK, in the batch's own order: see `_draw_runway`.
##
## Kept because A HEADLESS RUN CANNOT READ A MULTIMESH BACK. The dummy rendering server keeps no buffers, so
## `get_instance_custom_data` returns the default for every instance however carefully it was set -- the same trap
## `billboard.gdshaderinc` records for instance transforms. A test that read the MultiMesh would pass with this
## unplugged and fail with it working, so it is asked of what was handed over instead, which is the shape
## `AirbaseView.drawn_solid` already uses for the same reason.
var runway_frames: Array[Color] = []
## THE ROCK, THE CONCRETE AND THE RAILWAY, drawn a kilometre at a time from the same boxes. See SceneryYard.
var scenery: SceneryYard = null
## THE ISLAND FILED BY THE KILOMETRE, which the scenery and the towns are drawn from. See WorldMap.
var _map: WorldMap = null
## THE DEAD, TOP-DOWN LEVEL PICTURE shared by the clipboard and cockpit map screens.
var level_map: LevelMap = null
## THE HAND-BUILT PLACES, read at boot. See AuthoredChunks.
var places: Array[Dictionary] = []
var _places_handed: bool = false
## Red boxes round anything more than half a kilometre off. See the D key.
var _spotting: bool = false
## THE FIRE FRONT, on the server only: fires that light their neighbours, and the cap that
## says when the island is lost. Null on a client, which is told about new fires the same
## way it is told about anything else that was spawned. See `FireFront`.
var front: FireFront = null
## How much longer until the debrief line is rewritten. See `_physics_process`.
var _debrief_due: float = 0.0
## entity -> VehicleView
var _views: Dictionary = {}
## sync client id -> RemotePilot
var _pilots: Dictionary = {}
var _seeded: bool = false
## THE WORLD THIS LEVEL STANDS ON, a `GroundTuning.World`, decided on every build: its level's (`LevelChart.world`).
var _world: int = GroundTuning.World.ISLAND
## THE GENERATED GROUND, made once for the level's life and kept alive: the ground's workers and `Terrain` read it.
var _field: Object = null
## WHETHER THIS LEVEL IS A ROOM AND NOT A COUNTRY, read off the level at every build (`LevelChart.indoors`). One
## predicate, asked by the build, the finish and the seeding, so the three cannot disagree about which kind of level
## this is.
var _indoors: bool = false
## THE BRIEFING ROOM, on a level whose world is a room, and null on every other. See BriefingRoom.
var room: BriefingRoom = null
## The visual Device Yard, on its explicit level only. It is separate from `room` because the lobby owns a launch board,
## while the yard deliberately owns no local controls before RoomControlBank owns their replicated state.
var device_yard: DeviceYard = null
## The hangar yard -- an apron with Hangar 03 on it -- on its own level and null everywhere else. See HangarYard.
var hangar_yard: HangarYard = null
## THE TRACE LEVEL's playback, when the level is `trace` (`levels/trace/trace_level.gd`): one puppet craft posed from a file.
var trace_level: TraceLevel = null
## WHETHER THE LAST BUILD HAS FINISHED: `_on_sim_ready` seeds nothing before it, since on the generated ground a build waits
## a frame a world and the session comes up during the wait.
var _built: bool = false
## The generated ground as drawn, on the alpine world only. See GroundView.
var ground_view: GroundView = null
## The island's mountains, drawn; null on any other world.
var mountains: MountainView = null
## THE LAKES OF THE GENERATED GROUND, drawn as water in the sea's shader: on the alpine world only. See LakeSheets.
var lakes: LakeSheets = null
## THE WATER IN THE LEVEL'S OWN RIVERS, drawn the same way: on a generated ground, for a level that lays any.
var rivers: RiverSheets = null
## How long the last build took to stand the generated ground in every world, milliseconds, or -1 on the island.
var ground_built_msec: float = -1.0
## THE LEVEL THIS WORLD STANDS ON, read at every build from `Net.level`. See LevelChart.
var level: LevelChart = null
## THE LEVEL'S AIRPORT LIFE, on the host, where its folder has a `traffic.json` (the test field's): the pilots that fly
## it and the plan that says what to ask them for. Null on every other level. See `TrafficPlan`.
var airport_traffic: AirportTraffic = null
var traffic_plan: TrafficPlan = null
## PER-CLIENT NETWORK STATISTICS, on a level that asks for them (`LevelChart.keeps_stats`) and null on every other. It
## gathers this machine's row once a second and keeps everybody else's; whatever draws the table is handed
## `NetStats.table()`. See NetStats.
var net_stats: NetStats = null
## THE RADAR SWEEP, on every machine: the host draws each peer a picture and sends it, a joiner keeps the one it is
## sent. See `world/radar_watch.gd`.
var radar: RadarWatch = null
## THE CONTROLLER'S STATION, on `--level=control`. Handed the map and the radar once both exist -- it is built before
## `Sim.start()` and before the map, like every other layer here.
var _station: ControlStation = null
## The collaborative cockpit workshop exists only on the builder room level.
var builder_room: BuilderRoom = null
var builder_session: BuilderSession = null
## Drawn once and left alone. The simulation is rebuilt on every session; the scenery is
## the same scenery, and rebuilding two hundred boxes of it per join would be work nobody
## asked for.
var _scenery_drawn: bool = false
## Counts down to the next status line rewrite. See _process.
var _status_due: float = 0.0
## The beacon standing on your own vehicle's destination. See _draw_waypoint.
var _beacon: Node3D = null
## A CAR IS A BOXCAR, and every one of its dimensions belongs to `Boxcar` -- the length, the
## depth, the truck spacing and the coupler gap. There are no carriage numbers in this file:
## the old pair typed a 3.6 m height and a 12.0 m bogie spacing here while the mesh's own size
## was typed again eight lines further down, and the two could part without anything noticing.
const BOXCAR := preload("res://objects/vehicles/boxcar.gd")

## The carriages hung behind each locomotive this machine is DRAWING, keyed by the entity the
## renderer knows it as. There is no list of locomotives beside it any more: see `_draw_carriages`.
var _carriages: Dictionary = {}
var _railway_drawn: bool = false
## The host's layered network load. It exists only outdoors and only beside the
## authoritative world; clients may see its aircraft but cannot create or retire them.
var holding_stack: HoldingStack = null
var _load_last_rollbacks := 0
var _load_last_at := 0


func _ready() -> void:
	if not Sim.is_available():
		_status.text = "The ashiato extension is not loaded.\n" \
			+ "Build it: ashiato-gd/tools/build.ps1 -WithCockpit"
		push_error("[Sky] CockpitWorld missing")
		set_process(false)
		return

	# THE WORLD WITH NOBODY IN IT, on `--level=watch`. Every other door into this level
	# puts a player in a seat, which is right for a game about flying things and wrong for
	# the other job a game has: looking at itself. An observer is a camera and nothing
	# else -- no rig, no seat, no XR, no hands -- so the world can be watched running on a
	# monitor or headless, which is what testing anything the AI does needs.
	# THE TIME OF DAY IS THE SESSION'S, AND THIS LEVEL DRAWS IT. Before anything that shows it: the board is handed it
	# below, and the towns are told how many windows to light when they are drawn. `Net.clock_now` is `--time=` or the
	# start on a machine that decides the sky, and the host's on one that joined (plan item 17; Net, "THE SKY"), and the
	# daylight reads it on from there every frame, telling the world in steps.
	daylight = Daylight.new($DirectionalLight3D as DirectionalLight3D,
		($WorldEnvironment as WorldEnvironment).environment)
	add_child(daylight)
	daylight.changed.connect(_on_the_time_changed)
	daylight.show_clock(Net.clock_now())
	music = MusicBox.new()
	music.name = "MusicBox"
	add_child(music)

	if _the_controller():
		# AND A CONTROLLER FLIES NOTHING EITHER, for the same reason a server does not: `_seat_new_clients` gives
		# every client a pod, so a controller was being handed an aeroplane it never sits in -- and `RadarWatch` then
		# put its radar head on that POD rather than on the control tower. Measured: `radar_head=-21,30,0
		# radar_from_tower=no`, which is the island's spawn and not the airfield.
		#
		# THIS ONLY ANSWERS A CONTROLLER THAT IS HOSTING. A controller that JOINED is seated by the host, and the host
		# has no way to know that peer came in through this door -- see
		# `../../todo/flatcrew--a-joining-controller-is-still-given-an-aeroplane.md`.
		Sim.seat_the_host = false
		# NO CAMERA EITHER: a controller looks at a plot, not at the world. The station is handed the level's own map
		# and the level's own radar rather than making either, so there is only one map of the island in the game.
		var control_layer := CanvasLayer.new()
		control_layer.name = "ControlLayer"
		add_child(control_layer)
		var station := ControlStation.new()
		station.name = "ControlStation"
		station.sky = self
		control_layer.add_child(station)
		_station = station
	elif _the_server():
		# AND IT DOES NOT FLY. A host is a sync client like any other and `_seat_new_clients` gives every client a pod,
		# so a server left alone spawns an aeroplane at the level's first spawn spot and parks it there for ever --
		# measured, `craft=94 pilots=1` with nobody connected. Joiners are still seated; only this machine is not.
		Sim.seat_the_host = false
		# NO OBSERVER AND NO CAMERA: a server is not watching. The console goes on its own layer, exactly as the
		# tower's panel does, and is handed the level and the simulation's server rather than reaching for them.
		var server_layer := CanvasLayer.new()
		server_layer.name = "ServerLayer"
		add_child(server_layer)
		var console := ServerConsole.new()
		console.name = "ServerConsole"
		console.sky = self
		console.server = Sim.server
		server_layer.add_child(console)
	elif _nobody_is_playing():
		observer = Observer.new()
		observer.name = "Observer"
		observer.world = self
		add_child(observer)
		# THE TOWER'S PANEL, on its own layer above the camera's board. Built here rather than by the observer because
		# it needs the LEVEL -- landing is a pattern to join, and the observer is a camera that knows about vehicles
		# and nothing about airfields.
		if _the_tower():
			var layer := CanvasLayer.new()
			layer.name = "TowerLayer"
			add_child(layer)
			var panel := TowerPanel.new()
			panel.name = "TowerPanel"
			panel.observer = observer
			panel.sky = self
			panel.server = Sim.server
			# AND THE CAMERA'S OWN BOARD IS HIDDEN, because it reads the CLIENT's list and the panel reads the
			# server's: two boards on one screen giving different heights for the same aeroplane is what the tower
			# exists to stop. The panel's readout says everything the board said.
			for board in observer.find_children("*", "Label", true, false):
				(board as CanvasItem).visible = false
			layer.add_child(panel)
	else:
		rig = RIG_SCENE.instantiate() as PilotRig
		add_child(rig)
		# THE BOARD FILLS THE SKY. It starts quiet now -- see Terrain's fleet note -- and
		# the clipboard is what puts machines in it, one at a time.
		rig.clipboard.chose_traffic.connect(add_traffic)
		rig.clipboard.chose_stack.connect(choose_stack_count)
		rig.clipboard.chose_attack.connect(send_attackers)
		rig.clipboard.chose_latency.connect(choose_link_latency)
		# AND SAVE BANDWIDTH, the host's far-pose LOD: TRAFFIC's switch announces, `choose_save_bandwidth` decides, and
		# the board is told what is in force, here and on every press.
		rig.clipboard.chose_save_bandwidth.connect(choose_save_bandwidth)
		rig.clipboard.show_save_bandwidth(Sim.save_bandwidth)
		# AND THE TIME-OF-DAY DIAL, the same way: it announces through the rig, `choose_time` decides, and the rig shows
		# the board and every dial what the time IS.
		rig.chose_time.connect(choose_time)
		# AND SETS THE TIME OF DAY: the TIME tab announces any time and any rate, `choose_clock` and `choose_rate` decide,
		# and the board is told what the time IS -- here, and on every step -- so its highlight is never its own guess.
		rig.clipboard.chose_clock.connect(choose_clock)
		rig.clipboard.chose_rate.connect(choose_rate)
		rig.show_time(daylight.clock)
		# AND THE CLOUDS, the same way and with the same authority: the TIME tab's CLOUDS switch announces.
		rig.clipboard.chose_clouds.connect(choose_clouds)
		rig.clipboard.show_clouds(Net.clouds_on)
		rig.clipboard.chose_music.connect(_choose_music)
		rig.clipboard.chose_music_stop.connect(func(): _choose_music(""))
		rig.clipboard.chose_music_fade.connect(_fade_music)
		rig.clipboard.chose_music_sound.connect(music.set_local_on)
		music.changed.connect(_show_music)
		_show_music()

	# ONE YARD OF BIG EXPLOSIONS FOR THE WHOLE SKY, handed to both yards before they are added, so a barrage of shells and
	# a volley of missiles share one cap and one pair of night lights. Built -- and warmed -- now, at load, never in the
	# frame something goes off. See BurstYard.
	bursts = BurstYard.new()
	bursts.name = "Bursts"
	add_child(bursts)
	bursts.show_daylight(float(daylight.look.get("burst_light", 0.0)))
	shots = SHOT_YARD.new()
	shots.name = "Shots"
	shots.bursts = bursts
	add_child(shots)
	shots.round_left.connect(_on_a_round_left)
	missiles = MISSILE_YARD.new()
	missiles.name = "Missiles"
	missiles.find_rail = _rail_of_client
	missiles.bursts = bursts
	add_child(missiles)
	contrails = CONTRAIL_YARD.new()
	contrails.name = "Contrails"
	contrails.follow(missiles)
	add_child(contrails)
	contrails.show_daylight(daylight.look)
	damage = DAMAGE_YARD.new()
	damage.name = "Damage"
	damage.follow(missiles)
	damage.bursts = bursts
	add_child(damage)
	overview = CrashOverview.new()
	overview.name = "CrashOverview"
	add_child(overview)
	respawner = CrewRespawn.new()
	respawner.name = "CrewRespawn"
	add_child(respawner)
	attackers = Attackers.new()
	attackers.name = "Attackers"
	add_child(attackers)
	wakes = WAKE_YARD.new()
	wakes.name = "Wakes"
	wakes.follow(missiles)
	add_child(wakes)
	wakes.show_daylight(daylight.look)
	spray = SPRAY_YARD.new()
	spray.name = "Spray"
	spray.follow(missiles)
	add_child(spray)
	# EVERY FIREBOAT MONITOR'S STREAM, on the same clock as the contrails for the same reason: see MonitorYard.
	monitors = MONITOR_YARD.new()
	monitors.name = "Monitors"
	monitors.follow(missiles)
	add_child(monitors)
	monitors.show_daylight(daylight.look)
	exhaust = EXHAUST_YARD.new()
	exhaust.name = "Exhaust"
	exhaust.follow(missiles)
	add_child(exhaust)
	spray.show_daylight(daylight.look)
	burning = FIRE_YARD.new()
	burning.name = "Fires"
	add_child(burning)
	lift = LIFT_YARD.new()
	lift.name = "Lift"
	add_child(lift)
	# THE CLOUDS ARE SOLID OBJECTS, and the fog near the eye is built only where it is ASKED FOR: `--clouds=fog`, on a
	# renderer that can draw a FogVolume. Asked for on 2026-09-15 -- "disable all volumetrics and turn clouds back into
	# solid objects" -- and nothing of the fog is deleted; see `CloudBank.asked_for`. Without a bank the depth fog whites
	# the view out from inside a cloud, which is what `_on_eye_in_cloud` has always done on PLAIN.
	# `--clouds=none` draws no cloud at all, for the probe's reference pictures.
	var clouds_asked: String = CloudBank.asked_on_the_command_line()
	if CloudBank.asked_for(clouds_asked) and CloudBank.can_draw():
		clouds = CloudBank.new()
		clouds.name = "Clouds"
		clouds.air = ($WorldEnvironment as WorldEnvironment).environment
		add_child(clouds)
		clouds.fog_share_changed.connect(lift.show_fog_share)
	elif clouds_asked == "none":
		lift.draws_clouds = false
	# THE PUFFS, unless the lumps or no clouds were asked for. LiftYard keeps its rings and wisps and draws no lumps.
	if clouds == null and PuffSky.worn_for(clouds_asked):
		puffs = PuffSky.new()
		puffs.name = "Puffs"
		add_child(puffs)
		puffs.show_daylight(daylight.look if daylight != null else DaylightTuning.look_at(DaylightTuning.clock_of(DaylightTuning.When.DAY)))
		puffs.wear(_finish_is_fine())
	_show_the_clouds()
	eye_in_cloud.connect(_on_eye_in_cloud)
	# THE LOW MIST: ground haze and low stratus lying on the ground under it, drawn over everything opaque. Told the time of day
	# and the finish now, and on every change; its chart of the ground is baked with the scenery in `_build`.
	# `--mist=off` after the bare `--` builds none, to time and photograph against.
	if MistLayer.asked_on_the_command_line() != "off":
		mist = MistLayer.new()
		add_child(mist)
		# THE COMPUTE MIST HANGS ON THIS ENVIRONMENT'S COMPOSITOR on PLAIN; see MistEffect.
		mist.use_environment($WorldEnvironment as WorldEnvironment)
		mist.show_time(daylight.look)
		mist.wear(_finish_is_fine())
	# THE SEA WITH A SHAPE, beside the flat one, and only one of the two is ever drawn. See
	# SeaSwell, and `_wear_the_finish` below.
	swell = SeaSwell.new()
	swell.name = "Swell"
	swell.position = ($Sea as Node3D).position
	add_child(swell)
	# And the plain sea wears its sheet, so a hull heaving on the simulated swell is not heaving through a flat plane.
	swell.carry($Sea as MeshInstance3D)
	grass = GrassBlades.new()
	grass.name = "Blades"
	add_child(grass)
	woodland = Woodland.new()
	woodland.name = "Woods"
	add_child(woodland)
	# THE GROUND'S FINE MATERIAL IS A COPY OF ITS PLAIN ONE with the shader changed, so every
	# colour and scale is the one written in the scene -- once -- and the blades read the same.
	var ground := get_node_or_null("Ground") as MeshInstance3D
	if ground != null and ground.material_override is ShaderMaterial:
		_ground_plain = ground.material_override as ShaderMaterial
		_ground_fine = _ground_plain.duplicate() as ShaderMaterial
		_ground_fine.shader = GRASS_FINE
		# HOW NEAR THE GROUND'S TWO BANDS COME IN, from `DetailReach` -- the same authority and the same dial the
		# runway's and the air bases' pavement read. Set on BOTH tiers and after the duplicate, so neither can be the
		# one that missed it. Until 2026-09-20 these four numbers were typed into the two grass shaders.
		var bands: Dictionary = DetailReach.ground_numbers()
		for named in bands:
			_ground_plain.set_shader_parameter(named, bands[named])
			_ground_fine.set_shader_parameter(named, bands[named])
		# A heading and not the wind, which is zero: see `Terrain.SWELL_HEADING`.
		_ground_fine.set_shader_parameter("wind", Terrain.SWELL_HEADING)
		grass.match_the_ground(_ground_plain)
	var finish: Node = get_node_or_null("/root/Finish")
	if finish != null:
		finish.connect("changed", _wear_the_finish)
	_wear_the_finish(finish != null and bool(finish.call("is_fine")))

	Sim.sim_ready.connect(_on_sim_ready)
	# A SESSION ENDED FROM OUTSIDE IT goes back to the desk, which says why. See `_on_the_session_ended`.
	Net.session_ended.connect(_on_the_session_ended)
	Sim.sim_restarting.connect(_build)
	Net.session_ready.connect(_build)
	# THE HOST CHANGED THE LEVEL, and this machine goes and builds the new one. See `_on_the_level_changed`.
	Net.level_changing.connect(_on_the_level_changed)
	# SOMEBODY'S NETWORK STATISTICS ARRIVED. `Net` carries them and this level keeps them, on the levels that ask.
	Net.stats_row_heard.connect(func(row: Array) -> void:
		if net_stats != null and is_instance_valid(net_stats):
			net_stats.hear_a_row(row))
	Net.stats_board_heard.connect(func(table: Array, page: int) -> void:
		if net_stats != null and is_instance_valid(net_stats):
			net_stats.take_the_board(table, page))
	# THE SESSION'S SKY CHANGED -- chosen here, or said by the host -- and this level draws it. See `_on_the_sky_changed`.
	Net.sky_changed.connect(_on_the_sky_changed)
	# THE SESSION THE MENU ALREADY STARTED, IF THERE IS ONE.
	#
	# This used to call `Net.play_solo()` unconditionally, with a comment saying nothing
	# had asked for a session yet. A real menu asks now -- `DeskRoom` calls `Net.host()`
	# or `Net.join()` and then changes scene to this one -- and `play_solo` BEGINS by
	# closing whatever peer is installed. So pressing "Host a game" created the ENet
	# server, loaded the world, and destroyed the listening socket one frame later, with
	# `transport` back to "solo".
	#
	# Nothing errored and nothing warned, which is the worst shape a failure can have:
	# `Sim.start()` saw an un-networked peer, stood up a local server, and the game played
	# on its own in a session the player thought they were hosting. Both networked paths
	# out of the only menu in the game were dead and no suite ever called either.
	#
	# A session that already exists has ALREADY emitted `session_ready`, before this scene
	# existed, so waiting for it here would wait for ever. It is built directly instead.
	if Net.is_in_session:
		_build()
	else:
		Net.play_solo()


func _build() -> void:
	_forget()
	# WHICH LEVEL, before anything is built: the session's, read off the drawer. A level on a world this build cannot stand
	# was refused before it reached the desk (`LevelChart.WORLDS`), so one that is missing here is a bug, and said.
	level = ChartDrawer.chart(Net.level)
	# THE LEVEL'S AIR: a share of the game's haze, in the depth fog and in the low mist (`LevelChart.haze`).
	if level != null:
		if daylight != null:
			daylight.thin_the_air(level.haze)
		if mist != null:
			mist.thin(level.haze)
		# AND HOW FAR IT IS DRAWN (`LevelChart.reach`): read from every level file since cockpit-terrain and handed to
		# nothing, so every eye stopped at the rig's and the observer's 24 km. Every camera of this level is told before
		# anything asks `_far()`, so the yard, the ground and the mist's reach follow it (lane/testfield, 2026-09-19: the
		# test field's other airport is 35 km off).
		if level.reach > 0.0:
			# The eyes into the world, not a SubViewport's own camera: the level map's looks straight down at the whole
			# chart and sets its own far.
			for eye in find_children("*", "Camera3D", true, false):
				if (eye as Camera3D).get_viewport() == get_viewport():
					(eye as Camera3D).far = level.reach
	if level == null:
		_status.text = "There is no level called %s." % Net.level
		push_error("[Sky] the session's level '%s' is not one ChartDrawer has" % Net.level)
		return
	# THE LINK THIS LEVEL ASKS EVERY REMOTE MACHINE TO HOLD, before the simulation starts and therefore before a single
	# packet of it moves. A level that asks for nothing puts the link back to nothing, so a machine cannot walk out of
	# the stress level carrying its 80 ms into the island. The host holds none of it, which is what makes the level's
	# number mean one-way -- see `Net.suit_the_link`. A joiner is told its level before it builds and admitted after, so
	# the half of the handshake that follows this line carries the link as the simulation does: the "loaded" and the
	# "admitted" that answers it each cross a delayed edge.
	Net.suit_the_link(level.link_ms)
	# AND WHETHER THIS MACHINE COUNTS WHAT ARRIVES, which has to be asked for BEFORE `start`: a tracer is attached when
	# the replication client is built, and `set_tracing` afterwards records nothing and says nothing about it. See
	# `Sim.want_receipts`.
	Sim.want_receipts = level.keeps_stats
	if not Sim.start():
		return
	if level.keeps_stats:
		net_stats = NetStats.new()
		net_stats.name = "NetStats"
		add_child(net_stats)
	# AND THE RADAR, on every machine and not only the host: the host sweeps and publishes, a joiner keeps what
	# arrives, and both hand the same thing to whatever is drawing. Built here with `NetStats` because it is the same
	# shape -- a node on a one-second timer that publishes on the authority and stores on a client.
	radar = RadarWatch.new()
	radar.name = "RadarWatch"
	add_child(radar)
	_seeded = false
	_built = false
	# WHICH WORLD: the level's, which a joiner was told by its host before this build began. See Net's "THE HELLO".
	_world = GroundTuning.world_named(level.world)
	var island: bool = _world == GroundTuning.World.ISLAND
	# A ROOM STANDS ON THE SAME SLAB THE ISLAND DOES, whose top is y = 0, so the room's floor is 0 and a spawn's y is its
	# height over it -- and `Terrain.highest_near`, which `Sim` asks before it seats anybody, answers 0 there. What it
	# does NOT get is the island: no boxes, no scenery, no sea, nothing generated. See `_stand_the_room_up`.
	_indoors = level.indoors()
	if island or _indoors:
		Terrain.stand_on(null)
		Sim.add_static_box(Vector3(0.0, -GROUND_HALF.y, 0.0), GROUND_HALF)
		# THE ISLAND'S SEA, for the crash rule: past the slab there is water to go into. A room has none.
		Sim.set_sea(island)
	else:
		await _stand_on_the_ground()
	var ground := get_node_or_null("Ground") as MeshInstance3D
	if ground != null:
		ground.visible = island
	# AND THE FINISH AGAIN, now the world is known: `_ready` wore it before there was one, and the blades are the island's.
	_wear_the_finish(_finish_is_fine())
	# A ROOM HAS NO COUNTRY ROUND IT: no sea, no air, no lift, no scenery, no woods, no railway, no runway and no
	# waypoints. Everything outdoors is ONE function so a room skips it in one line rather than in fifteen guards -- a
	# guard per thing is a guard somebody forgets to put on the sixteenth. See `_stand_the_room_up`.
	if _indoors:
		await _stand_the_room_up()
	else:
		_stand_the_country_up(island)
	# THE TRACE LEVEL: the puppet, its path and its instruments, on the map the level just stood.
	if TraceLevel.claims(level):
		trace_level = TraceLevel.new()
		trace_level.name = "TraceLevel"
		add_child(trace_level)
		trace_level.stand_in(level, self)
	_build_level_map()
	# AND THE CONTROLLER'S STATION IS HANDED THE TWO THINGS IT DRAWS, now that both exist. It is built at the top of
	# `_ready`, before `Sim.start()` and before the map, exactly as the server console is -- and like that console it
	# would sit there drawing nothing for ever if it were left holding the nulls it was born with.
	if _station != null and is_instance_valid(_station):
		_station.level_map = level_map
		_station.radar = radar
	# AND WHERE THE LEVEL ENDS, softly: past everything placed, as deep as the widest turn, inside the wire's last
	# resort, or the level is refused in words (see WorldEdge). Told to every world like the ground.
	if not _mark_the_edge():
		return
	# BUILT: and if the session came up while the ground was being stood, seed it now.
	_built = true
	if Sim.is_ready:
		_on_sim_ready()
	# A PROBE'S SLOW BUILD, `--load-slowly=SECONDS`: the level waits that long before saying it is built, standing in
	# for a ground that takes seconds to stand (the alpine world's, about 4 s), so tests/level_join.gd can watch a host
	# hold a joiner back while it builds. Nothing in the game passes it.
	if _asked("load-slowly").is_valid_float() and float(_asked("load-slowly")) > 0.0:
		await get_tree().create_timer(float(_asked("load-slowly"))).timeout
	# AND THE LEVEL IS BUILT: a joiner tells its host, which has held back its simulation until now, with the hash of the
	# ground its worlds stand on -- Box3D's own over every height field, the same on both editors (cockpit-terrain) -- so a
	# ground function that changed under one copy of a level is caught too. "" on the island. See Net's HELLO.
	Net.level_loaded(_ground_hash())


func _build_level_map() -> void:
	if level_map != null and is_instance_valid(level_map):
		remove_child(level_map)
		level_map.queue_free()
	level_map = LevelMap.new()
	level_map.name = "LevelMap"
	add_child(level_map)
	level_map.configure(level)
	level_map.rebuild()


## EVERYTHING OUTSIDE A ROOM: the sea, the air, the rising air, the scenery, the woods, the railway, the runways and
## the places an autopilot may be sent. Lifted out of `_build` unchanged when the room world went in (2026-09-15), so a
## level that is a room skips the country in one line instead of in a guard per paragraph.
func _stand_the_country_up(island: bool) -> void:
	# THE SEABED, on either world: a floor under the open sea, so nothing that goes in falls for ever. See Seabed.
	Seabed.lay()
	# Where the sea is, told to the simulation rather than left on a default that happens
	# to agree with the mesh.
	Sim.set_handling(Sim.Kind.BOAT, {"water_level": SEA_LEVEL})
	# THE AIR. Told to the simulation with the geometry and for the same reason: it is part
	# of the world's definition, every peer must be given the same numbers, and none of it
	# is replicated -- see the note at the top of Terrain.
	Sim.set_wind(Terrain.WIND, Terrain.WIND_SHEAR)
	# THE RISING AIR, on either world: on the generated ground every zone is based on the ground under it and its cloud
	# clears the rock (Terrain, "RISING AIR ON THE GENERATED GROUND"; increment B3).
	var zones: Array[Dictionary] = Terrain.lift_zones()
	for zone in zones:
		Sim.add_lift_zone(zone["position"], float(zone["radius"]), float(zone["strength"]),
			float(zone["top"]))
	# THE SAME LIST, DRAWN. One table for the air and the picture, exactly as one list of
	# boxes feeds the collision and the mountains: rising air drawn where the simulation
	# does not have any is the worst kind of bug, because it looks like the aeroplane is
	# broken rather than the sky.
	if lift != null:
		# Before the markers are built the level's time was already on: hand the yard its brightness now, and it keeps
		# it through every rebuild.
		if daylight != null:
			lift.show_daylight(daylight.look)
		lift.show_lift(zones, Terrain.WIND)
	# AND THE PUFFS, from the same zones -- a thermal's cloud where LiftYard's stood -- and the layered sky over the land, each
	# cloud stood clear of the ground under it (sea level off the land).
	if puffs != null:
		var land_half: float = Terrain.WORLD_HALF if island else float(GroundTuning.WORLD_HALF)
		# AS MANY LOW CLOUDS AS THE LEVEL ASKS FOR (`LevelChart.cloud_cover`, 1 unless it says).
		puffs.show_clouds(PuffSky.level_sky(PUFF_SEED, land_half, zones, PuffSky.ground_under,
			level.cloud_cover if level != null else LevelChart.CLOUD_COVER_DEFAULT))
		_show_the_clouds()
	if clouds != null:
		if daylight != null:
			clouds.show_daylight(daylight.look)
		clouds.gather(zones, Terrain.WIND)
	# And the smoke leans with the wind, which is how a pilot reads it from the air.
	if burning != null:
		burning.set_drift(Terrain.WIND)
	# Mountains, a city and four gates. ONE list, walked here for the collision and in
	# _draw_scenery for the picture, because scenery drawn where the simulation does not
	# have any looks exactly like a networking fault.
	# On the generated ground the list is the seated towns' buildings, each on its site's level; see Terrain.boxes.
	var solid: Array[Dictionary] = Terrain.boxes()
	# THE ISLAND'S MOUNTAINS, into every world before anything is placed that asks what is solid: one set of triangles,
	# the simulation's here and the picture's in `_draw_scenery`. See Terrain.mountains and MountainView.
	if Terrain.mountains() != null:
		if not Sim.set_mountains(Terrain.mountains()):
			push_error("[Sky] a world would not stand among the island's mountains")
	if island:
		# AND EVERY HAND-BUILT PLACE'S BOXES, into the same list, so they reach the simulation, the grid and the fire front
		# exactly as a mountain does -- rule 8. Its scene is the yard's, loaded on a thread when it comes within reach.
		places = AuthoredChunks.catalogue()
		solid.append_array(AuthoredChunks.boxes(places))
	_solid = solid
	_grid = BoxGrid.new(solid)
	for box in solid:
		Sim.add_static_box(box["position"], box["half_extents"])
	# THE ROADS BETWEEN TOWNS, ONCE, and handed to the picture and to the woods: building them is most of the boot, and
	# both used to build their own. See `Terrain.ground_keepouts`.
	var roads: Array[Dictionary] = Terrain.roads(solid)
	_draw_scenery(solid, roads)
	# THE WOODS, from the same list, and NOT into the simulation: a tree is a picture, and an
	# aeroplane flown into a wood flies through it. Grown once, on either world (on the generated ground from the woods the
	# ground grows, Forests.stands; increment B4); the floor under them painted onto both of the island's ground materials,
	# or onto every cell of the generated ground as GroundView builds it.
	if woodland != null:
		woodland.grow(solid, roads)
		if island:
			woodland.paint_the_floor(_ground_plain, _ground_fine)
		elif ground_view != null:
			ground_view.lay_the_floor(woodland.floor_values(false))
	# THE RAILWAY, before anything is put on it. Built on both sides, like the collision.
	if island:
		var rail: Array[Vector3] = Terrain.rail_points(Terrain.RAIL_LAID_EVERY)
		var bank: PackedFloat32Array = Terrain.rail_bank(Terrain.RAIL_LAID_EVERY)
		for i in range(rail.size()):
			Sim.add_rail_point(0, rail[i], bank[i] if i < bank.size() else 0.0)
		Sim.close_rail(0)
		_draw_railway(rail)
	# EVERY RUNWAY, on either world: the island's one, or one on each airfield strip the generated ground flattened.
	_draw_runway()
	# AND EVERY AIR BASE LAID ROUND ONE. See AirbasePlan.
	_draw_airbases()
	# THE CRAFT THIS LEVEL OFFERS, now the ground says whether it has a sea: the page was drawn before there was a level.
	# AND ONLY THE ONES IT NAMES, when its file names any (`LevelChart.craft`; the glider level's gliders), with its reason.
	if rig != null and rig.clipboard != null:
		var offered: Array[int] = level.craft if level != null else ([] as Array[int])
		rig.clipboard.show_kinds(VehicleCatalogue.craft_rows_for(Terrain.has_sea(), offered),
			VehicleCatalogue.craft_note(Terrain.has_sea(), offered, level.craft_why if level != null else ""))
	# AND ALL OF IT WITHIN REACH OF THE EYE, NOW: the level is loading, which is when a long frame belongs. From here the
	# yard keeps it round the eye a few cells a frame. See SceneryYard.
	if scenery != null:
		if not _places_handed and island:
			_places_handed = true
			AuthoredChunks.add_to_yard(scenery, places, _far(), scenery)
		scenery.fill_around(_eye_now())
	# AND THE MIST'S CHART OF THE GROUND ROUND THE EYE, baked on a worker and waited for while the level loads.
	if mist != null:
		mist.bake_now(_eye_now())
		# AND THE TOWNS ITS DOMES STAND OVER, seated where the ground put them. See MistLayer.show_towns.
		mist.show_towns(TownCatalogue.towns())
	# Where the autopilots may be sent. Registered with the world rather than held here,
	# because the simulation is what checks a leg against the scenery before flying it.
	# EVERY KIND THAT HAS AN AUTOPILOT needs a pool of its own, including the ones that
	# share a movement model with something else: the simulation looks a pool up by KIND,
	# so a kind with an empty one is a machine that searches for somewhere to go for ever
	# and never finds it. That is what a tiltrotor with no pool did.
	for kind in [Sim.Kind.PLANE, Sim.Kind.HELI, Sim.Kind.CAR, Sim.Kind.BOAT,
			Sim.Kind.OSPREY, Sim.Kind.CESSNA, Sim.Kind.PIRATE, Sim.Kind.HAWKEYE, Sim.Kind.SUBMARINE]:
		for at in Terrain.waypoints(kind, _grid):
			Sim.add_ai_waypoint(kind, at)


## STAND THE ROOM UP, for a level whose world is a ROOM: the lobby's briefing room and nothing else at all.
##
## The room is the level's own -- sized and placed from its spawn data -- and its walls, its ceiling and its desks go
## into the simulation and into the picture from ONE list, exactly as the island's mountains do (`BriefingRoom.boxes`).
## The floor is the slab this level already stands on.
func _stand_the_room_up() -> void:
	var yard_level: bool = DeviceYard.claims(level)
	var build_level: bool = BuilderRoom.claims(level)
	var hangar_level: bool = HangarYard.claims(level)
	var solid: Array[Dictionary] = DeviceYard.boxes(level) if yard_level else (BuilderRoom.boxes(level) if build_level \
		else (HangarYard.boxes(level) if hangar_level else BriefingRoom.boxes(level)))
	_solid = solid
	_grid = BoxGrid.new(solid)
	for box in solid:
		Sim.add_static_box(box["position"], box["half_extents"])
	if yard_level:
		device_yard = DeviceYard.new()
		device_yard.name = "DeviceYard"
		add_child(device_yard)
		device_yard.stand_in(level)
		# The host creates the authoritative page entities.  The client configures its
		# expected schema in bind_room_control below; both values come from the hashed
		# level chart, never a joiner's request.
		if Sim.server != null and Sim.server.has_method("room_control_configure"):
			for room_id in DeviceYard.ROOMS:
				Sim.server.room_control_configure(room_id, DeviceYard.ROOM_CONTROL_REVISION,
					device_yard.endpoint_count)
		# An older extension has no RoomControlBank API; DeviceYard then remains visibly OFFLINE. A native accepted command
		# still never changes a panel locally: its next replicated state is the only thing that can do that.
		device_yard.bind_room_control(Sim.client)
		# The yard's instanced endpoints are an explicit world-pointer target.  `PilotRig`
		# works this list with either the desktop mouse ray or the VR hand ray; it does not
		# discover arbitrary geometry, which keeps another room's bank out of reach.
		if rig != null:
			rig.world_pointer_targets.append(device_yard)
	elif build_level:
		builder_room = BuilderRoom.new()
		builder_room.name = "BuilderRoom"
		add_child(builder_room)
		await builder_room.stand_in(level)
		builder_session = BuilderSession.new()
		builder_session.name = "BuilderSession"
		add_child(builder_session)
		builder_session.setup(self, builder_room)
		if rig != null and builder_room.board != null:
			rig.pointer_panels.append(builder_room.board)
	elif hangar_level:
		# THE HANGAR YARD: an apron, Hangar 03 and a parked fighter. It owns no controls and no board -- it is a building
		# and some paint -- so it is stood up and nothing is wired to it. See HangarYard.
		hangar_yard = HangarYard.new()
		hangar_yard.name = "HangarYard"
		add_child(hangar_yard)
		hangar_yard.stand_in(level)
	else:
		room = BriefingRoom.new()
		room.name = "BriefingRoom"
		add_child(room)
		await room.stand_in(level)
		# THE LAUNCH BOARD ANNOUNCES; THIS DECIDES (building_a_game_here.md, rule 5). And the board goes to the rig's
		# pointer, the seam the desk's monitors use, so the mouse works it on a desk and the beam in a headset.
		room.chose_level.connect(_launch_the_level)
		if rig != null and room.board != null:
			rig.pointer_panels.append(room.board)
		if rig != null and room.roster_board != null:
			rig.pointer_panels.append(room.roster_board)
	# AND NO WEATHER INDOORS. The mist is LET GO rather than hidden: its compute pass hangs on the environment's own
	# compositor (see MistEffect), so a hidden node still costs the pass every frame. A level cannot change its world
	# without the scene being reloaded, so nothing ever needs it back.
	if mist != null:
		mist.queue_free()
		mist = null


## THE HASH OF THE GROUND THIS MACHINE'S CLIENT WORLD STANDS ON, as text: the generated ground's height fields', or on the
## island its mountains' meshes' (massif.hpp); "" with neither. DIGITS ONLY, as Net's hello reader requires of a ground
## hash: the first version put an "m" before the island's, and the host dropped every joiner's "loaded" hello unread, so
## no two-peer suite could join the island (the 2026-09-18 gate). Two peers only ever compare hashes of the same level.
func _ground_hash() -> String:
	if Sim.client == null:
		return ""
	var report: Dictionary = Sim.client.ground_report()
	if not report.is_empty():
		return str(report.get("hash", ""))
	var rock: Dictionary = Sim.client.mountains_report()
	return str(rock.get("hash", "")) if not rock.is_empty() else ""


## A LEVEL WAS PRESSED ON THE BRIEFING ROOM'S LAUNCH BOARD. Only the host may change the level, and `Net` says so in
## words rather than this room deciding who is allowed -- one authority, asked (CLAUDE.md, rule 10). Whatever it answers
## goes back on the glass, because a button that does nothing and says nothing is a broken button.
func _launch_the_level(id: String) -> void:
	if room == null:
		return
	if id == Net.level:
		var here: LevelChart = ChartDrawer.chart(id)
		room.say("You are in %s." % [here.name if here != null else id])
		return
	# CALLED, NOT CHANGED: with anybody else here the session is warned and goes `Net.LEVEL_WARNING_MSEC` later, and alone
	# it goes at once (plan item 13). `Net` decides which; the board says what it did.
	var why: String = Net.call_the_level(id)
	if why != "":
		room.say(why)
		return
	var going: LevelChart = ChartDrawer.chart(id)
	var in_ms: int = Net.level_called_in()
	room.say(("Launching %s in %d s…" % [going.name if going != null else id, ceili(float(in_ms) / 1000.0)]) if in_ms > 0
		else ("Launching %s…" % [going.name if going != null else id]))


## THE HOST CHANGED THE LEVEL: leave this world and build the new one from the top. The session is not touched -- the
## socket stays open, nobody joins anything, and `Net` holds this machine's packets until it says the new level is
## loaded (see Net's `change_level`).
##
## THE SCENE IS RELOADED rather than `_build` being called again, and that is the decision. `_build` rebuilds the
## SIMULATION -- `Sim.start()` tears both worlds down and stands them up -- but the DRAWN world is built once per scene
## and kept on purpose: the scenery yard, the woods, the ground view, the authored places, the mist's chart and the
## railway are all once-only, because rebuilding two hundred boxes of scenery per join is work nobody asked for. So
## `_build` on a different level would stand a new simulation inside the old level's scenery, which looks exactly like a
## networking fault. Reloading is the path `tests/level_swap.gd` already measures -- a level flown, left and flown
## again, five times over every level -- with no node, object or orphan growth.
##
## DEFERRED, like every other scene swap here: this arrives on a signal, inside `Net`'s own frame.
func _on_the_level_changed(_id: String) -> void:
	if not is_inside_tree():
		return
	Sim.stop()
	get_tree().change_scene_to_file.call_deferred("res://world/sky.tscn")


## THE WAY OUT OF A WORLD WITH NO SESSION LEFT IN IT. Until 2026-09-15 nothing in the world listened: a joiner whose
## host left, or who was refused after it had loaded, sat in a world with no simulation and a line of text. Now a
## session that ended with parting words (`Net.parting_words`) takes the player back to the desk, which says them;
## one left on purpose -- MAIN MENU, Quit -- was already on its way somewhere and has none.
func _on_the_session_ended(_reason: String) -> void:
	if Net.parting_words != "" and is_inside_tree():
		Doors.to_the_desk()


## THE LEVEL'S SOFT EDGE, worked out now the ground stands: false, with the session ended and the reason said, when it
## will not fit inside the wire.
func _mark_the_edge() -> bool:
	var radii: Array = Sim.client.turn_radii()
	var fastest: float = 0.0
	for row in radii:
		fastest = maxf(fastest, float((row as Dictionary)["speed"]))
	var band: Dictionary = WorldEdge.band_for(Terrain.placed_reach(), float(Sim.client.worst_turn_radius()),
		float((Sim.client.boundary() as Dictionary)["guard_from"]), fastest)
	Sim.edge = band
	if String(band["error"]) != "":
		var why: String = "%s cannot be flown: %s." % [level.name, band["error"]]
		push_error("[Sky] " + why)
		_status.text = why
		# THE SAME DOOR AS A REFUSED JOINER: back to the desk, which says why. See `Net.refuse_the_session`.
		Net.refuse_the_session(why)
		return false
	Sim.set_boundary(float(band["start"]), float(band["depth"]))
	return true


## THE GROUND LET GO WITH THE LEVEL. `Terrain` holds the generated ground in a static, which outlives this node: unloading a
## level (cockpit-levels, island to alpine and back) must hand Terrain the island again and drop the field, or the ground
## and everything it reaches stay alive behind a level that is gone.
func _exit_tree() -> void:
	if Terrain.standing_on() == _field:
		Terrain.stand_on(null)
	_field = null


## THE GENERATED GROUND, STOOD ON: one `GroundField` for the level's life, handed to `Terrain`, and given to every world a
## frame at a time behind a line that says so. It is about 2 s a world on the main thread on either editor (2026-09-15), so
## the level says it is loading first and a headset is handed a frame between the worlds. Building the fields once on a
## worker and installing them in both is C++, and waits in agents.md's WHAT IS NOT HERE YET.
func _stand_on_the_ground() -> void:
	if _field == null:
		_field = ClassDB.instantiate("GroundField")
		# THE LEVEL'S OWN NUMBERS, checked by the ground when the level was read (`LevelChart`), so a problem here is a bug.
		var problems: PackedStringArray = _field.call("configure", GroundTuning.for_level(level))
		if not problems.is_empty():
			push_error("[Sky] the ground would not configure: %s" % ", ".join(problems))
	Terrain.stand_on(_field, level.id)
	if _status != null:
		_status.text = "Loading the ground"
	await get_tree().process_frame
	var began: int = Time.get_ticks_usec()
	if not await Sim.set_ground(_field):
		push_error("[Sky] a world would not stand on the generated ground")
	ground_built_msec = float(Time.get_ticks_usec() - began) / 1000.0


## ---- the finish ------------------------------------------------------------------------

## PUT A FINISH ON THE SCENERY THIS LEVEL OWNS: the sea. The clouds, the fires and the lights
## listen to `Finish` for themselves, because they are theirs; this is the level's share.
func _wear_the_finish(fine: bool) -> void:
	_on_eye_in_cloud(eye_depth, eye_cloud)
	# THE SKY: FINE's with cirrus, PLAIN's procedural sky -- `--cirrus=off` keeps PLAIN's on both, to time against.
	var air: Environment = ($WorldEnvironment as WorldEnvironment).environment
	if daylight != null and air.sky != null and daylight.fine_sky != null and daylight.plain_sky != null:
		air.sky.sky_material = daylight.fine_sky if fine and not Daylight.cirrus_asked_off() else daylight.plain_sky
	# NO SEA INDOORS, on either finish: the briefing room's floor is at sea level, so the flat sea would cut through it.
	# AND NONE ON A GROUND WITH NO SEA (lane/testfield, 2026-09-19): its lowest valley floor is 1.5 m, and a sheet at 0
	# would show wherever a coarse level of the drawn ground dips under the real one.
	var sea := get_node_or_null("Sea") as GeometryInstance3D
	if sea != null:
		sea.visible = not fine and not _indoors and Terrain.has_sea()
		# THE LEVEL'S SEA, from the one place water is dressed, now the world (and so the level) is known:
		# `_ready` wore it before `_build` had read the chart, and a level change must put the new colours on
		# both finishes rather than leave the last session's on a sheet that is only shown or hidden.
		WaterSurface.wear(sea, false)
	if swell != null:
		swell.visible = fine and not _indoors and Terrain.has_sea()
		WaterSurface.wear(swell, true)
	var ground := get_node_or_null("Ground") as MeshInstance3D
	if ground != null and _ground_plain != null:
		ground.material_override = _ground_fine if fine else _ground_plain
	# THE RUNWAY'S PAVEMENT. Both tiers carry the same distance ranges: FINE adds the aggregate, it does not move the
	# detail nearer. See `pavement_fine.gdshader`.
	var runway := get_node_or_null("Runway") as MultiMeshInstance3D
	if runway != null and _runway_plain != null:
		runway.material_override = _runway_fine if fine else _runway_plain
	# THE AIR BASES' PAVEMENT. Told by the level rather than listening for themselves, as the sea and the ground are:
	# a base is the level's scenery. See `AirbaseView.wear`.
	var bases := get_node_or_null("Airbases")
	if bases != null:
		for base in bases.get_children():
			(base as AirbaseView).wear(fine)
	# The blades are clipped to the island's square (`GrassBlades`, `land_half`), which the generated ground is not.
	if grass != null:
		grass.visible = fine and _world == GroundTuning.World.ISLAND
	if scenery != null:
		scenery.wear(fine)
	if mountains != null:
		mountains.wear(fine)
	if towns != null:
		towns.wear(fine)
	if mist != null:
		mist.wear(fine)
	if puffs != null:
		puffs.wear(fine)
	if level_map != null:
		level_map.rebuild()


func _finish_is_fine() -> bool:
	var finish: Node = get_node_or_null("/root/Finish")
	return finish != null and bool(finish.call("is_fine"))


## HOW DEEP IN A CLOUD THE EYE IS, asked of the clouds from the camera the viewport is drawn with -- the midpoint of the
## eyes in a headset, the desk camera or the watch camera otherwise, and the same eye CloudBank fades its fog from -- and
## announced when it moves by a hundredth or the eye leaves every cloud.
func _look_for_the_clouds() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	# AND THE FOG THE ENVIRONMENT HAS NOW, to the towns' far lights, which take the engine's own fog themselves: see
	# town_lights.gdshaderinc. Read off the environment, never worked out beside it; the towns write only on a change.
	if towns != null:
		towns.show_fog(($WorldEnvironment as WorldEnvironment).environment.fog_density)
		# AND WHERE THE TOWN'S FLASH IS, from the tick: every obstruction light on the island flashes on it. See TownView.show_flash.
		towns.show_flash(Engine.get_physics_frames(), Sim.tick_dt())
	if lift == null or camera == null:
		return
	# NO CLOUDS, NO CLOUD TO BE IN: the white-out follows what is drawn, not where a thermal's cloud would have been. The
	# puffs, where they are worn, are what is drawn.
	var found: Dictionary = {"depth": 0.0, "key": Vector2i.ZERO}
	if puffs != null:
		if puffs.visible:
			found = puffs.eye_in(camera.global_position)
	elif lift.draws_clouds:
		found = lift.eye_in_cloud(camera.global_position)
	var depth: float = found["depth"]
	if absf(depth - eye_depth) < 0.01 and not (depth == 0.0 and eye_depth > 0.0):
		return
	eye_depth = depth
	eye_cloud = found["key"]
	eye_in_cloud.emit(depth, eye_cloud)


## WHAT BEING IN A CLOUD DOES, decided here: the rings and wisps fade out on both finishes, and where there is no fog to fly
## into -- PLAIN, or no fog clouds -- the depth fog whites the view out. With fog clouds worn the fog does it itself, and the
## depth fog is left as the time of day has it. Asked again when the finish or the time of day changes.
func _on_eye_in_cloud(depth: float, _key: Vector2i) -> void:
	if lift != null:
		lift.show_eye_in_cloud(depth)
	# THE PUFFS WHITE THE VIEW OUT THEMSELVES, until they give way deep in a cloud; the depth fog takes exactly the share they
	# have given up (`PuffSky.give_way`), so the view is never both or neither.
	if puffs != null:
		puffs.show_eye_in_cloud(depth)
	if daylight != null and not daylight.look.is_empty():
		var fog_does_it: bool = clouds != null and clouds.wears_fine()
		var whiteout: float = depth
		if fog_does_it:
			whiteout = 0.0
		elif puffs != null:
			whiteout = PuffSky.give_way(depth)
		daylight.show_in_cloud(whiteout, LiftYard.cloud_colour(daylight.look))


## WHAT EVERY SURFACE IS ACTUALLY DRAWN WITH, as name -> true for fine.
##
## Read off the nodes and materials, never off `Finish` -- that is the whole use of it. A test
## that compared the tier with itself would pass with every surface unplugged; this is the
## question "did the switch reach the sea", asked of the sea.
func finish_worn() -> Dictionary:
	var worn: Dictionary = {}
	var sea := get_node_or_null("Sea") as Node3D
	worn["sea"] = swell != null and swell.visible and sea != null and not sea.visible
	worn["lights"] = VehicleLights.paint().shader == VehicleLights.FINE
	# THE SAMPLES, read off the viewport this level is drawn into -- not off the finish's own
	# answer to what they ought to be.
	worn["msaa"] = get_viewport().msaa_3d == preload("res://autoload/finish.gd").FINE_MSAA
	if lift != null:
		worn["clouds"] = lift.wears_fine()
	if clouds != null:
		worn["cloud_volumes"] = clouds.wears_fine()
	if mist != null:
		worn["mist"] = mist.wears_fine()
	var air: Environment = ($WorldEnvironment as WorldEnvironment).environment
	if daylight != null and air.sky != null and daylight.fine_sky != null and not Daylight.cirrus_asked_off():
		worn["sky"] = air.sky.sky_material == daylight.fine_sky
	var ground := get_node_or_null("Ground") as MeshInstance3D
	if ground != null and ground.material_override is ShaderMaterial:
		worn["ground"] = (ground.material_override as ShaderMaterial).shader == GRASS_FINE
	var runway := get_node_or_null("Runway") as MultiMeshInstance3D
	if runway != null and runway.material_override is ShaderMaterial:
		worn["runway"] = (runway.material_override as ShaderMaterial).shader == PAVEMENT_FINE
	# EVERY BASE, AND ALL OF THEM HAVE TO AGREE: reported as one surface, true only if each one wears it, so a base
	# the switch did not reach cannot hide behind the ones it did.
	var bases := get_node_or_null("Airbases")
	if bases != null and bases.get_child_count() > 0:
		var every: bool = true
		for base in bases.get_children():
			every = every and (base as AirbaseView).wears_fine()
		worn["airbase_pavement"] = every
	# THE BLADES ARE THE ISLAND'S: clipped to its square (`GrassBlades`, `land_half`), hidden on the generated ground on either
	# finish, so there they are not a surface a finish wears. Reported on the island only; asked on the alpine world, "not
	# visible" read as a surface left on PLAIN and failed scenery_shot's every_surface_wears_fine (increment B2, 2026-09-15).
	if grass != null and _world == GroundTuning.World.ISLAND:
		worn["blades"] = grass.visible
	if woodland != null and woodland.planted.has("plain_trees"):
		worn["forest"] = woodland.wears_fine()
	if contrails != null:
		worn["contrails"] = contrails.wears_fine()
	if scenery != null and not scenery.box_batches().is_empty():
		worn["rock"] = scenery.wears_fine()
	if mountains != null:
		worn["mountains"] = mountains.wears_fine()
	if burning != null:
		worn["fires"] = burning.wears_fine()
	if bursts != null:
		worn["bursts"] = bursts.wears_fine()
	if towns != null:
		worn["towns"] = towns.worn()
	return worn


## The same boxes the simulation was just given, drawn: filed by the kilometre (`WorldMap`) and drawn a cell at a
## time -- the rock, the concrete and the railway by `SceneryYard`, the buildings and the paint by `TownView`. It
## was one MultiMesh for all the rock and one for all the concrete, each culled as one box, so a single step of a
## single peak in frame drew every mountain on the island. Nothing here decides anything; it is handed the list
## that the physics already has.
func _draw_scenery(solid: Array[Dictionary], roads: Array[Dictionary]) -> void:
	if _scenery_drawn:
		return
	_scenery_drawn = true
	_map = WorldMap.new(solid)
	scenery = SceneryYard.new()
	scenery.name = "Scenery"
	add_child(scenery)
	scenery.draw_boxes(_map, _far(), _finish_is_fine())
	# AND THE TOWNS, from the BUILDING entries of the same list, with every street and road as paint: each town's streets
	# on its own ground (TownPlan.streets), and the roads between the towns on either world.
	towns = TownView.new()
	towns.name = "Towns"
	add_child(towns)
	var marks: Array[Dictionary] = TownPlan.streets()
	marks.append_array(TownPlan.road_marks(roads))
	towns.draw_towns(_map, marks, _far(), scenery)
	towns.wear(_finish_is_fine())
	# AND A POWER STATION BESIDE ONE OF THEM, on the same yard. Its towers are placed from the town they serve
	# rather than from typed coordinates, so they move with it when the generated ground seats it somewhere else.
	# The wind is handed over here rather than beside the fires' `set_drift` above, because this node does not
	# exist yet at that point in `_build` and a plume built later still has to lean the right way.
	stations = PowerStation.new()
	stations.name = "Stations"
	add_child(stations)
	stations.draw_stations(_map, _far(), scenery)
	stations.set_drift(Terrain.WIND)
	# AND THE ISLAND'S MOUNTAINS, every tile resident and drawn to the horizon, from the arrays the simulation's
	# collision was built from. See MountainView.
	if Terrain.mountains() != null:
		mountains = MountainView.new()
		mountains.name = "Mountains"
		add_child(mountains)
		mountains.show_mountains(Terrain.mountains(), _finish_is_fine(), _ground_plain)
	# AND AN OIL PLATFORM OUT AT SEA, on the same yard, standing in whatever depth this world's sea floor gives it.
	oil_field = OilField.new()
	oil_field.name = "OilField"
	add_child(oil_field)
	oil_field.draw_platforms(_map, _far(), scenery)
	# AND THE GENERATED GROUND, as one levelled layer of the same yard, drawn as far as the camera sees. See GroundView.
	if GroundTuning.takes_numbers(_world) and _field != null:
		ground_view = GroundView.new()
		ground_view.name = "GroundView"
		add_child(ground_view)
		ground_view.show_ground(_field, scenery, _far())
		lakes = LakeSheets.new()
		lakes.name = "Lakes"
		add_child(lakes)
		lakes.show_lakes(_field, _finish_is_fine())
		rivers = RiverSheets.new()
		rivers.name = "Rivers"
		add_child(rivers)
		rivers.show_rivers(Terrain.level_rivers(), _field, _finish_is_fine())
	if daylight != null:
		_on_the_time_changed(daylight.look)


## How far the scenery is drawn when there is no camera to ask: the far plane the rig's and the observer's cameras
## both have.
const FAR_WITH_NO_CAMERA: float = 24000.0


## HOW FAR FROM THE EYE THE SCENERY IS DRAWN: as far as the camera drawing it can see, so nothing it could see is left
## out. ASKED of the camera, not typed beside it: a batch drawn to a number of its own is a picture cut off wherever the
## two stopped agreeing. The yard builds a kilometre within this of the eye and lets it go past it and half a cell.
func _far() -> float:
	var eye: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	return eye.far if eye != null else FAR_WITH_NO_CAMERA


## Where the eye is as the level loads: the camera's, or the middle of the island before there is one.
func _eye_now() -> Vector3:
	var eye: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	return eye.global_position if eye != null else Vector3.ZERO


## ---- the time of day -----------------------------------------------------------------------

## THE TIME OF DAY, CHOSEN: by the clipboard's TIME tab or a time-of-day dial, which announce a press and have it decided
## here, or by a probe. See Daylight, which writes it once.
##
## THE SESSION DECIDES, NOT THE LEVEL (plan item 17). `Net.choose_time` takes it on a machine that decides the sky and
## tells every peer; on a joiner it is refused, and the refusal is said on the board where the press was made. The board's
## buttons and every dial then go back to the time this level still has, because they are shown it, not because they
## guessed. Written here as well as through `Net.sky_changed` so a probe that put a time straight on `daylight` and then
## chooses the session's own still gets it drawn -- `show_time` writes nothing when nothing changed.
func choose_time(which: int) -> void:
	var why: String = Net.choose_time(which)
	if why != "":
		_say_the_sky_is_not_ours(why)
		return
	if daylight != null:
		daylight.show_clock(Net.clock_now())


## ANY TIME OF DAY, CHOSEN, minutes on the clock: the TIME tab's clock row, or a probe. The same authority and refusal as a
## preset's time, and the rate is kept.
func choose_clock(minutes: float) -> void:
	var why: String = Net.choose_clock(minutes)
	if why != "":
		_say_the_sky_is_not_ours(why)
		return
	if daylight != null:
		daylight.show_clock(Net.clock_now())


## HOW FAST THE CLOCK RUNS, CHOSEN, game seconds a real second: the TIME tab's rate row, or a probe. The same authority.
func choose_rate(rate: float) -> void:
	var why: String = Net.choose_rate(rate)
	if why != "":
		_say_the_sky_is_not_ours(why)
		return
	if rig != null:
		rig.clipboard.show_rate(Net.clock_rate)


## CLOUDS OR NONE, CHOSEN: by the TIME tab's CLOUDS switch. The same authority and the same refusal as the time.
func choose_clouds(on: bool) -> void:
	var why: String = Net.choose_clouds(on)
	if why != "":
		_say_the_sky_is_not_ours(why)
		return
	_show_the_clouds()


## A JOINER PRESSED THE SKY: said on its board, and the board and dials put back to what this level draws.
func _say_the_sky_is_not_ours(why: String) -> void:
	if rig == null:
		return
	rig.clipboard.say_no(why)
	rig.show_time(daylight.clock if daylight != null else -1.0)
	rig.clipboard.show_rate(Net.clock_rate)
	rig.clipboard.show_clouds(Net.clouds_on)


func _choose_music(track: String) -> void:
	if not track.is_empty() and music.shelf.stream_for(track) == null:
		rig.clipboard.say_no("There is no local track called %s." % track)
		return
	var why := Net.choose_music(track, -12.0, 0.0)
	if not why.is_empty():
		rig.clipboard.say_no(why)
	_show_music()


func _fade_music(target_db: float, seconds: float) -> void:
	var why := Net.fade_music(target_db, seconds)
	if not why.is_empty():
		rig.clipboard.say_no(why)
	_show_music()


func _show_music() -> void:
	if rig == null or music == null:
		return
	rig.clipboard.show_music_catalog(music.track_ids())
	rig.clipboard.show_music(Net.music_state, music.status(), Net.decides_the_music())
	rig.clipboard.show_music_sound(music.local_on)


## THE SESSION'S SKY, DRAWN: the time on the daylight (which tells everything else through `_on_the_time_changed`) and the
## clouds on the yards. From `Net.sky_changed`, on a host that chose it and on every peer its host told.
func _on_the_sky_changed() -> void:
	if daylight != null:
		daylight.show_clock(Net.clock_now())
	_show_the_clouds()
	if rig != null:
		rig.clipboard.show_rate(Net.clock_rate)
		rig.clipboard.show_clouds(Net.clouds_on)


## WHETHER THE CUMULUS ARE DRAWN: the session's clouds, and not on a probe that asked for none (`--clouds=none`, a LOCAL
## reference picture). The mesh clouds and, where a machine was asked for them, its fog clouds go together; the thermal
## wisps and rings are the rising air's markers and not clouds, and stay. What is drawn is the whole of it -- the
## simulation's lift is the same with clouds or without.
func _show_the_clouds() -> void:
	var drawn: bool = Net.clouds_on and CloudBank.asked_on_the_command_line() != "none"
	if lift != null:
		lift.show_clouds(drawn and puffs == null)
	if clouds != null:
		clouds.visible = drawn
	if puffs != null:
		puffs.visible = drawn
	# AND NOBODY IS IN A CLOUD THAT IS NOT THERE: the white-out is asked again at once rather than left on.
	if not drawn and eye_depth > 0.0:
		eye_depth = 0.0
		eye_in_cloud.emit(0.0, eye_cloud)


## Whether the cumulus are drawn, for a harness and the tests: the puffs where they are worn, else LiftYard's lumps.
func clouds_drawn() -> bool:
	if puffs != null:
		return puffs.visible
	return lift != null and lift.draws_clouds


## Which `DaylightTuning.When` the level's clock is nearest, or -1 before it has one.
func time_of_day() -> int:
	return daylight.time if daylight != null else -1


## The clock the level last drew, minutes, or -1 before it has one.
func clock() -> float:
	return daylight.clock if daylight != null else -1.0


## A ROUND LEFT A GUN, from the shot yard: this player's own are felt in the hand on the gun. See
## `PilotRig.feel_a_round_leave`.
func _on_a_round_left(shooter: int, mount: int, _ammo: int) -> void:
	if rig != null and shooter >= 0 and shooter == Sim.local_client_id():
		rig.feel_a_round_leave(mount)


## EVERYTHING ELSE THE TIME OF DAY REACHES, once per step of the clock: the towns' windows, how bright an explosion lights
## what is near it, the clouds, the mist, the trails, the platforms, an aircraft's lights, the board's highlight and every
## time-of-day dial -- all handed the one look (`DaylightTuning.look_at`), so none can be at another time from the sky.
##
## THE MAP IS DRAWN AGAIN ONLY WHEN THE NEAREST PRESET CHANGES: it is a whole view rendered and read back, and a clock
## running at 60 times steps twice a second.
func _on_the_time_changed(look: Dictionary) -> void:
	if look.is_empty():
		return
	var at: int = Time.get_ticks_usec()
	if towns != null:
		towns.light_windows(float(look["windows_lit"]), float(look["window_glow"]))
		at = _counted("towns", at)
	if bursts != null:
		bursts.show_daylight(float(look["burst_light"]))
	if lift != null:
		lift.show_daylight(look)
		at = _counted("lift", at)
	if contrails != null:
		contrails.show_daylight(look)
	if wakes != null:
		wakes.show_daylight(look)
	if spray != null:
		spray.show_daylight(look)
	at = _counted("trails", at)
	if clouds != null:
		clouds.show_daylight(look)
	if puffs != null:
		puffs.show_daylight(look)
		at = _counted("puffs", at)
	if oil_field != null:
		oil_field.show_daylight(look)
		at = _counted("oil_field", at)
	if mist != null:
		mist.show_time(look)
		at = _counted("mist", at)
	_on_eye_in_cloud(eye_depth, eye_cloud)
	VehicleLights.show_daylight(float(look["aircraft_lights"]), float(look["aircraft_dim_to"]),
		float(look["aircraft_far_bright"]), float(look["aircraft_far_least"]))
	at = _counted("in_cloud_and_lights", at)
	if level_map != null and int(look["time"]) != _map_drawn_at:
		_map_drawn_at = int(look["time"])
		level_map.rebuild()
		at = _counted("map", at)
	# THE BOARD AND THE DIALS, four times a second at most in a time-lapse: the readout redraws the board, and a clock that
	# steps every frame would redraw it every frame to say a minute nobody can read.
	if rig != null and (Net.clock_rate < Daylight.LAPSE_FROM or Time.get_ticks_msec() - _rig_told_at >= RIG_TOLD_EVERY_MSEC):
		_rig_told_at = Time.get_ticks_msec()
		rig.show_time(float(look["minutes"]))
		at = _counted("rig", at)


## Count what a consumer of a step cost on the daylight's books (`Daylight.costs`), and the time to count the next from.
func _counted(name: String, began: int) -> int:
	if daylight != null:
		daylight.count(name, began)
	return Time.get_ticks_usec()


## When the board was last told the time, and how often at most in a time-lapse. See `_on_the_time_changed`.
var _rig_told_at: int = -1000000
const RIG_TOLD_EVERY_MSEC: int = 250
## Which preset the map was last drawn nearest, or -1. See `_on_the_time_changed`.
var _map_drawn_at: int = -1


## Spare vehicles, put in once the session is actually up.
##
## After the handshake, not before: a client only reaches Ready when it receives an update,
## and the server only sends updates about replicated entities -- so a host that waited for
## a connection before spawning anything would deadlock with a client waiting for a spawn.
func _register_issue_places() -> void:
	# A ROOM DELIBERATELY HAS NONE. Its CRAFT page reaches the same authoritative request
	# path and receives "no clear issue place"; spawning an aircraft through the briefing
	# room wall would make a lobby a second, broken flight level.
	if _indoors:
		return
	var registered: Dictionary = {}
	for spawn in Terrain.spawns():
		var kind: int = int(spawn["kind"])
		if registered.has(kind) or not bool(Sim.geometry_of(kind).get("pilotable", false)):
			continue
		# NONE FOR A KIND THE LEVEL DOES NOT OFFER: its CRAFT page has no button for it, and nothing else should issue one.
		if level != null and not level.offers(kind):
			continue
		# AND NONE FOR THE KIND A WINCH LAUNCHES: `respawn_crew` takes a clear issue place before the place the host asks
		# for, so one here would put a crashed glider on the apron and not at the first thermal (`GliderWinch`).
		if level != null and not level.launch.is_empty() and kind == level.arrive_kind:
			continue
		registered[kind] = true
		var geometry: Dictionary = Sim.geometry_of(kind)
		var extents: Vector3 = geometry.get("extents", Vector3.ONE)
		# kind_geometry.span is HALF a drawn wingspan. A full span plus four metres is
		# enough that two newly issued hulls and their drawn wings do not overlap.
		var half_span: float = maxf(float(geometry.get("span", 0.0)), maxf(extents.x, extents.z))
		var spacing: float = half_span * 2.0 + 4.0
		var yaw: float = float(spawn["yaw"])
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		var base: Vector3 = spawn["position"]
		# The table's own place is occupied when the level seeds. Start one place along
		# its row. `Net.MAX_PLAYERS` positions cover the session limit without an unbounded spawn
		# search, and the native clear check skips anything another row already occupies.
		# AT SIXTY-FOUR PLAYERS THIS ROW IS LONG (lane/seats, 2026-09-18): a carrier's places run kilometres along, over
		# whatever is there, and nothing checks the ground under them. Only a session that puts sixty-four players in one
		# kind reaches the end of it; written down in the seats learnings' What's next, not fixed.
		for slot in range(1, Net.MAX_PLAYERS + 1):
			Sim.add_issue_place(kind, base + right * (spacing * float(slot)), yaw,
				spawn.get("velocity", Vector3.ZERO))
	# SEGWAYS belong in rooms most of the time, so the outdoor spawn catalogue has none.
	# On a flight level they still need a valid ground apron: this is the vehicle the real
	# multiplayer issue harness uses because one seat means one request per issued craft.
	if not registered.has(Sim.Kind.SEGWAY):
		var geometry: Dictionary = Sim.geometry_of(Sim.Kind.SEGWAY)
		if bool(geometry.get("pilotable", false)):
			var extents: Vector3 = geometry.get("extents", Vector3.ONE)
			var base := Vector3(80.0, 0.0, -80.0)
			base.y = Terrain.highest_near(base, 6.0) + extents.y + 0.05
			for slot in range(Net.MAX_PLAYERS):
				Sim.add_issue_place(Sim.Kind.SEGWAY, base + Vector3(float(slot) * 4.0, 0.0, 0.0), 0.0)


func _on_sim_ready() -> void:
	# THE WEATHER THE SHIPS SAIL IN, on every peer and before the server-only seeding below: a wind is a function of the
	# frame and the seed, so every world told the same weather has the same wind with nothing sent, and a world not told is
	# in still air. Here and not in `_build`, whose `Sim.set_wind` makes the weather a steady field again: this runs after
	# it on every start and restart. And the user's decision (2026-09-15): aircraft do not feel it, and
	# `CockpitWorld.wind` answers the air they fly in, so no smoke leans on it either. See `Terrain.weather`.
	Sim.set_weather(Terrain.weather())
	Sim.set_wind_on_wings(false)
	# NOT BEFORE THE WORLD IS BUILT. On the generated ground `_build` waits a frame a world for the ground, and the session
	# comes up during that wait: seeding then spawned into a world with no grid and no railway. `_build` asks again at its
	# end.
	if _seeded or Sim.server == null or not _built:
		return
	_seeded = true
	_register_issue_places()
	# AND A ROOM HAS NOTHING TO SEED. No spawn table, no brigs, no fleet, no trains and no fire front: a briefing room
	# with a hundred and forty machines flying about outside its walls is not a briefing room, and every one of the calls
	# below asks `Terrain` about a country this level has not got.
	if _indoors:
		if builder_session != null:
			builder_session.spawn_on_host()
		return
	if holding_stack == null:
		holding_stack = HoldingStack.new()
		holding_stack.name = "HoldingStack"
		add_child(holding_stack)
		holding_stack.setup(Sim.server)
		holding_stack.said.connect(_tell_the_board)
		Sim.server.set_tick_breakdown(true)
	# ON THE GENERATED GROUND THE SAME CALLS PLACE THE SAME TABLE ON IT: Terrain's spawns, fires and pools stand on the ground
	# it was handed, and only the island's railway has no trains to put on it.
	# One of each movement model, so the difference is something you can fly rather than
	# something described in a comment.
	#
	# The aircraft are spawned ALREADY FLYING. One put into the air at a standstill stalls
	# before it can accelerate and mushes into the ground at full power -- correct
	# behaviour for a wing, and not a useful thing to hand somebody who has just arrived.
	# The spawn table lives in Terrain with the scenery, because the generator has to know
	# where things start: a spawn the scenery does not know about is a spawn the scenery
	# will eventually be generated on top of. It found a pod inside a mountain that way.
	# AND AN AIRBORNE ONE FLIES ITSELF UNTIL SOMEBODY SITS IN IT.
	#
	# Spawning it already moving is not enough. A wing with nobody on the throttle decays:
	# measured, the light aeroplanes were down to 30 m/s and sinking 3 m/s within five
	# seconds of the world starting, and the airliners were falling out of the sky before
	# anybody could reach one. An aeroplane below its flying speed drops a wing, which is
	# what "it came in with its left wing forward" looks like from the ground.
	#
	# An autopilot is the same answer the fleet already uses, and boarding hands over --
	# which is behaviour that already exists and is already tested. Anything sitting on the
	# ground is left alone: a parked helicopter should stay parked.
	for spawn in Terrain.spawns():
		# A LEVEL THAT OFFERS ONLY SOME CRAFT STANDS ONLY THOSE: the spawn table is one of every movement model, and a
		# parked jet on the glider level is a jet a player can walk into from the seat buttons.
		if level != null and not level.offers(int(spawn["kind"])):
			continue
		var launch: Vector3 = spawn["velocity"]
		var entity: int = 0
		# A CRAFT PARKED ON A SHIP carries the ship's velocity and is still parked: an autopilot handed one flies it off the
		# deck. It is spawned as parked craft are, with that velocity, so the deck under way does not slide out from under it.
		if launch.length() > 1.0 and spawn.get("place", &"") != &"carrier":
			entity = Sim.spawn_ai_vehicle(int(spawn["kind"]), spawn["position"],
				float(spawn["yaw"]), launch)
		else:
			entity = Sim.spawn_vehicle(int(spawn["kind"]), spawn["position"],
				float(spawn["yaw"]), launch)
		# RECORDED BY NAME, ONLY FOR NAMED SPAWNS: which entity the carrier became, so a check asks the simulation where it
		# is now rather than predicting it from where it was put -- its autopilot steers and the sea heaves it.
		if spawn.has("name"):
			_spawned[spawn["name"]] = entity
	# THE BRIGS, sailed by their own sailors (`CockpitWorld.sail_chore`) about their pool. Nobody may board one.
	for pirate in Terrain.pirates(_grid):
		Sim.spawn_ai_vehicle(int(pirate["kind"]), pirate["position"], float(pirate["yaw"]), pirate["velocity"])
	# And the traffic: ten of each kind, flying and driving themselves between waypoints.
	# Every seat on them is empty, so the take-the-next-craft button walks straight into
	# one and the autopilot hands over the moment a human sits in seat 0.
	# Spawned first, then joined up: a follower has to be told an ENTITY, and the leader
	# does not have one until it exists.
	# TRAINS, on the railway laid in _build. Every seat on a locomotive is empty, so the
	# take-the-next-craft button walks into the cab like anything else.
	# THE FIRES, lit by the server and heard about by everybody else. The positions come
	# from Terrain with the scenery, because that is the file that knows where the mountains
	# are -- see the note there.
	# A level may say `"fires": false` (the glider level): no fire is lit and there is no front to spread one, so
	# `front` stays null and the tick and the debrief skip it.
	var has_fires: bool = level == null or level.fires
	for fire in (Terrain.fires() if has_fires else []):
		Sim.light_fire(fire["position"], float(fire["strength"]))
	# AND THEY SPREAD FROM HERE ON. Built with the same box list the scenery was drawn from,
	# so a fire cannot catch inside a mountain -- see `Terrain.can_burn`. Server only, like
	# the lighting above it: a spread is a spawn.
	if has_fires:
		front = FireFront.new(_solid)
	# TRAINS ONLY WHERE THERE IS A RAILWAY: the island's.
	if _world == GroundTuning.World.ISLAND:
		var spawned_trains: int = 0
		for train in Terrain.trains():
			var engine: int = Sim.spawn_train(int(train["track"]), float(train["distance"]),
				float(train["speed"]))
			if engine != 0:
				spawned_trains += 1
		print("[sky] %d train(s) on the railway" % spawned_trains)

	# AND POINT THE CAMERA AT WHAT WAS ASKED FOR, now that there is something to point it
	# at. `--kind=` on an observed world means "show me that", which with a hundred and
	# forty machines in the sky is the difference between finding one and pressing a key
	# until it turns up.
	if observer != null:
		var wanted: int = _kind_asked_for()
		if wanted >= 0:
			observer.only.call_deferred(wanted)

	# AIRPORT LIFE, from the level's own traffic file: `basic` unless the command line asks for `--traffic=stress`.
	if level != null and not TrafficPlan.read(level.id, TrafficPlan.asked_for()).is_empty():
		airport_traffic = AirportTraffic.new()
		airport_traffic.name = "AirportTraffic"
		add_child(airport_traffic)
		traffic_plan = TrafficPlan.new()
		traffic_plan.name = "TrafficPlan"
		add_child(traffic_plan)
		traffic_plan.start(level.id, TrafficPlan.asked_for(), airport_traffic)
	# AND THE LEVEL'S OWN AIR TRAFFIC, from its `air_traffic.json`: machines wandering the square, keeping clear of the
	# players, and gliders among them soaring the level's thermals. The host's, as every AI is.
	if level != null and not AirTraffic.read(level.id).is_empty():
		soaring = SoaringPilot.new()
		soaring.name = "SoaringPilot"
		add_child(soaring)
		air_traffic = AirTraffic.new()
		air_traffic.name = "AirTraffic"
		add_child(air_traffic)
		air_traffic.start(level.id, soaring)
	var fleet: Array[Dictionary] = Terrain.ai_fleet(_grid) if level == null or level.fleet else ([] as Array[Dictionary])
	var entities: PackedInt64Array = []
	for machine in fleet:
		entities.append(Sim.spawn_ai_vehicle(int(machine["kind"]), machine["position"],
			float(machine["yaw"]), machine["velocity"]))
	for i in range(fleet.size()):
		var leader: int = int(fleet[i].get("leader", -1))
		if leader >= 0 and entities[i] != 0 and entities[leader] != 0:
			Sim.set_ai_leader(entities[i], entities[leader], fleet[i]["slot"])


## THE FIRE FRONT, ON THE PHYSICS CLOCK.
##
## Not the render clock, and that is the same rule everything else in this project follows:
## a fire spreading is a thing that happens in the world, so it is stepped by the world's
## clock and a machine drawing at ninety frames does not burn faster than one at sixty.
##
## AND THE DEBRIEF IS WRITTEN FIVE TIMES A SECOND, not a hundred and twenty. It is a line of
## text on a panel that is a render target; the status line in this same file was being
## formatted ninety times a second once, and that is written down two sections up.
func _physics_process(delta: float) -> void:
	# EVERY CUE, EVERY TICK, before anything that returns early. `Sim.cues` is replaced on each physics frame -- it is
	# the tick's own list, drained from the simulation -- so a cue not played on the tick that brought it is gone.
	# Nothing called this until 2026-09-13: `_play_the_cues` came with the water bomber (b347981) and no line in the game
	# ran it, so no release burst was ever drawn. See tests/water.gd, which now watches the level draw one.
	_play_the_cues()
	if front == null:
		return
	var watch: int = STOPWATCH.start()
	front.tick(Sim.server, delta)
	STOPWATCH.lap(&"fire_front", watch)
	_debrief_due -= delta
	if _debrief_due > 0.0:
		return
	_debrief_due = 0.2
	if rig != null and rig.clipboard != null:
		rig.clipboard.show_debrief(front.debrief())


func _process(_delta: float) -> void:
	_look_for_the_clouds()
	if Sim.client == null or not Sim.is_ready:
		return
	if device_yard != null and is_instance_valid(device_yard):
		device_yard.poll_room_control()

	# 1. Every vehicle where it belongs this instant.
	#
	# From Sim.current, which was captured on the last physics frame, NOT by asking the
	# simulation again. Asking builds a fresh Dictionary per vehicle with eight keys in
	# it, and this loop runs at the DISPLAY rate -- ninety times a second in a headset,
	# for a list that changes sixty times a second. That was the largest single piece of
	# per-frame garbage in the game.
	# SPOTTING BOXES, on D. An aeroplane four kilometres off is three pixels of grey on a
	# grey sky, and finding one is most of what flying with somebody else consists of.
	# Toggled rather than always on, because a sky full of red boxes is a sky you cannot
	# see either.
	# NOT WHILE A SEGWAY HAS THE KEY. D is `spot` and, in a segway, strafe right; a player walking
	# across a briefing room must not be flicking the spotting boxes on and off with every step.
	# `PilotRig.reading_a_segway` is the one predicate both ends ask, so the key has one owner at a
	# time (2026-09-15; see the note on `strafe_right` in `PilotRig.DESK_KEYS`).
	if Input.is_action_just_pressed("spot") and not (rig != null and rig.reading_a_segway()):
		_spotting = not _spotting
		print("[sky] Spotting boxes %s." % ["on" if _spotting else "off"])
	var eye: Vector3 = rig.eye_position() if rig != null \
		else (observer.global_position if observer != null else Vector3.ZERO)

	# EVERY ROUND IN THE AIR. Drawn from the birth record on every machine -- see ShotYard
	# -- and wound forward by however far behind the server this one is drawing, so a shell
	# somebody else fired starts where it has already got to rather than back at the barrel.
	var watch: int = STOPWATCH.start()
	if shots != null:
		shots.draw_shots(Sim.shots, eye, _delta, Sim.drawing_late(), Sim.take_shells_cued(), Sim.local_client_id())
	STOPWATCH.lap(&"shots", watch)
	# EVERY MISSILE, where the wire says it is, wound forward by how late this machine draws and how far this frame is
	# past the tick -- a missile's position is on the wire every tick, so there is no flight to integrate here.
	watch = STOPWATCH.start()
	if missiles != null:
		missiles.draw_missiles(Sim.missiles, eye, _delta, Sim.drawing_late(),
			Engine.get_physics_interpolation_fraction() * Sim.tick_dt())
	STOPWATCH.lap(&"missiles", watch)
	# AND EVERY FIRE. The smoke is what a pilot flies towards, so it is drawn on every
	# machine from the replicated list -- see FireYard, which is where the flames flicker
	# and the column leans.
	watch = STOPWATCH.start()
	if burning != null:
		burning.draw_fires(Sim.fires, _delta)
	STOPWATCH.lap(&"fires", watch)

	# THREE PASSES, TIMED APART, for the scenery probe: every vehicle drawn, then every spotting box, then the
	# reaping. One lap over all three said 0.72 to 0.78 ms a frame and not which part (agents.md, Stage 1). The
	# boxes come after ALL the drawing rather than after each vehicle's own, which draws the same frame: a box reads
	# only its own vehicle's place and the eye, and no vehicle's draw moves another's.
	watch = STOPWATCH.start()
	var seen: Dictionary = {}
	for entity in Sim.current:
		seen[entity] = true
		var view: VehicleView = _view_for(int(entity),
			int((Sim.current[entity] as Dictionary)["kind"]))
		view.draw()
	STOPWATCH.lap(&"vehicles_draw", watch)
	# EVERY CONTRAIL, from the views just placed: a segment behind an aircraft every fifth of a second, and nothing between.
	watch = STOPWATCH.start()
	if contrails != null:
		contrails.lay(_views)
	STOPWATCH.lap(&"contrails", watch)
	# AND EVERY HIT CRAFT'S SMOKE, from the same views and the hulls this tick brought (lane/combat).
	watch = STOPWATCH.start()
	if damage != null:
		damage.lay(_views)
	STOPWATCH.lap(&"damage", watch)
	# EVERY WAKE AND EVERY SPRAY, from the same views: see WakeYard and SprayYard.
	watch = STOPWATCH.start()
	if wakes != null:
		wakes.lay(_views)
	STOPWATCH.lap(&"wakes", watch)
	watch = STOPWATCH.start()
	if spray != null:
		spray.lay(_views)
	STOPWATCH.lap(&"spray", watch)
	# AND EVERY MONITOR'S STREAM, from the same views (lane/fireboat).
	watch = STOPWATCH.start()
	if monitors != null:
		monitors.lay(_views)
	STOPWATCH.lap(&"monitors", watch)
	# AND EVERY THRUST EXHAUST, from the same views: the plumes off each craft's declared ports, and the dust or spray
	# their wash raises off whatever is under them. Laid after the wakes and the spray and before the spotting sizes,
	# for the reason the comment below gives -- a plume laid from a magnified nozzle would stay that wide.
	watch = STOPWATCH.start()
	if exhaust != null:
		exhaust.lay(_views)
	STOPWATCH.lap(&"exhaust", watch)
	# SPOTTING SIZE: far aircraft drawn bigger for this rig's eye alone (`Spectacles`). AFTER the contrails, wakes and
	# spray have laid from every view's true pose -- a trail is not magnified, and one laid from a magnified wingtip
	# would stay that wide when the aircraft had come close -- and before the boxes, which size themselves in the world.
	# The craft the rig is in is never touched, and with it everyone aboard. No rig, no spectacles: an observer, a
	# watch level and a picture draw every craft its true size.
	watch = STOPWATCH.start()
	_draw_through_the_spectacles(seen, eye)
	STOPWATCH.lap(&"vehicles_spectacles", watch)
	watch = STOPWATCH.start()
	for entity in seen:
		(_views[entity] as VehicleView).spot(eye, _spotting)
	STOPWATCH.lap(&"vehicles_spot", watch)
	watch = STOPWATCH.start()
	_reap(seen)
	STOPWATCH.lap(&"vehicles_reap", watch)

	watch = STOPWATCH.start()
	# 1b. Where the vehicle you are in is going, if anything is taking it anywhere.
	_draw_waypoint()
	# 1c. Every cockpit control in the craft you are in, where the WIRE says it is -- which
	# is how you watch the other pilot fly, and every screen in it.
	_draw_cockpit(_delta)
	# 1d. The carriages, hung behind each locomotive on the same railway.
	_draw_carriages()
	STOPWATCH.lap(&"cockpit_and_carriages", watch)

	# 2. Riders. Their poses are seat-local and their nodes are children of the seat, so
	# this only has to set three local transforms per pilot -- and never a world one.
	watch = STOPWATCH.start()
	var mine: int = Sim.local_client_id()
	var present: Dictionary = {}
	# WHO IS SITTING WHERE, gathered as we go. A craft with nobody in it has no controls at
	# all -- see VehicleView.man -- and this is the list that decides it. It comes off the
	# pilot states the loop below is already walking, so it costs one Dictionary a frame
	# rather than a question per vehicle.
	var aboard: Dictionary = {}
	for state in Sim.pilots:
		var seated: int = int(state.get("vehicle", 0))
		if seated == 0:
			continue
		if not aboard.has(seated):
			aboard[seated] = []
		(aboard[seated] as Array).append(int(state.get("seat", 0)))
	for vehicle in _views:
		var view: VehicleView = _views[vehicle]
		view.man(aboard.get(vehicle, []), _my_seat_in(vehicle, mine))
	for state in Sim.pilots:
		var client_id: int = int(state["client"])
		var vehicle: int = int(state.get("vehicle", 0))
		if not _views.has(vehicle):
			continue
		var anchor: Node3D = (_views[vehicle] as VehicleView).seat_anchor(
			int(state.get("seat", 0)))
		if client_id == mine and mine != 0:
			# The local player is the RIG, not a mesh: drawing both would put a floating
			# head inside your own eyes. Seating it is a one-off; after that the scene
			# graph carries it and nothing here touches it again.
			# NOBODY IS FLYING on --level=watch, and the simulation still issues this
			# client a pilot and a pod, because there is no state in which a client has
			# neither. There is simply nothing to seat.
			if rig != null:
				# WHILE THIS PLAYER'S CRAFT IS A WRECK, the rig sits on the overview's still stand instead (lane/combat):
				# handed an anchor as a seat hands one, so nothing writes the rider's world transform.
				var watching: Node3D = overview.look(vehicle, _delta) if overview != null else null
				rig.sit_in(watching if watching != null else anchor)
			continue
		present[client_id] = true
		_pilot_for(client_id, anchor).apply(state)
		_show_their_lamp(_views[vehicle] as VehicleView, int(state.get("seat", 0)), state)
	_forget_missing_pilots(present)
	STOPWATCH.lap(&"riders", watch)

	# Five times a second, not ninety. The status line asks the simulation four separate
	# questions and formats nine values into a string; none of that is worth doing between
	# two frames a human cannot tell apart, and all of it was being done every frame.
	_status_due -= _delta
	if _status_due <= 0.0:
		_status_due = 0.2
		_update_status()


## THE PRIORITY SPHERE IN FORCE, for the status line and the LOAD TEST line: " · sphere 10 km x4, 12 near" on the host, the
## craft counted around this machine's own. Empty on a joiner, whose setting does nothing. See Sim.PRIORITY_*.
func _sphere_words() -> String:
	if Sim.server == null:
		return ""
	var in_force: Dictionary = Sim.server.priority_sphere()
	if not bool(in_force.get("enabled", false)):
		return " · sphere off"
	var near: Dictionary = in_force.get("near", {})
	var mine: int = int(near.get(Sim.local_client_id(), 0))
	return " · sphere %s km x%s%s, %d near" % [str(snappedf(float(in_force["radius_m"]) / 1000.0, 0.1)).trim_suffix(".0"),
		str(snappedf(float(in_force["inside"]) / float(in_force["outside"]), 0.1)).trim_suffix(".0"),
		" linear" if int(in_force["falloff"]) == Sim.Falloff.LINEAR else "", mine]


## HOW STALE THIS MACHINE'S CRAFT ARE, for tests/priority_peers.gd with `--freshness=1`: of the craft moving faster than
## FRESH_MOVING_MPS by their own replicated velocity -- which a host marks changed every tick, so staleness is only waiting
## -- how many are within `Sim.priority_sphere`'s radius of this machine's own craft and how many beyond, the most server
## frames since each group's stalest last record arrived, how many were never received, and the records received a tick
## since the last line. Parked craft are left out because sync sends nothing for a thing that has not changed.
const FRESH_MOVING_MPS: float = 5.0
var _fresh_last_count: int = -1
var _fresh_last_newest: int = -1


func _freshness_line() -> String:
	var receipts: Dictionary = Sim.client.received_frames() if Sim.client.has_method("received_frames") else {}
	var frames: Dictionary = receipts.get("frames", {})
	var newest: int = int(receipts.get("newest", -1))
	var count: int = int(receipts.get("count", 0))
	var per_tick: float = 0.0
	if _fresh_last_newest >= 0 and newest > _fresh_last_newest:
		per_tick = float(count - _fresh_last_count) / float(newest - _fresh_last_newest)
	_fresh_last_count = count
	_fresh_last_newest = newest
	var radius: float = float(Sim.priority_sphere.get("radius_m", 0.0))
	var states: Array = Sim.client.vehicle_states()
	var mine := Vector3(INF, INF, INF)
	for state in states:
		if bool((state as Dictionary).get("predicted", false)):
			mine = (state as Dictionary)["position"]
	var near := 0
	var far := 0
	var near_stale := 0
	var far_stale := 0
	var unseen := 0
	# WHICH CRAFT IS THE STALE ONE, AND OVER WHAT FRAMES. The numbers above are maxima over the set, and a maximum
	# names nothing: ashiato-sync issue #17 asked for the stalest craft and the server-frame interval its gap ran
	# over, which is exactly [`stalest_at`, `newest`]. The entity is THIS MACHINE'S: the host's id for the same craft
	# is a different number, and the trace's own records carry both.
	var far_worst := 0
	var far_worst_at := -1
	for state in states:
		var row: Dictionary = state
		if bool(row.get("predicted", false)) or (row.get("velocity", Vector3.ZERO) as Vector3).length() < FRESH_MOVING_MPS:
			continue
		var entity: int = int(row["entity"])
		if not frames.has(entity):
			unseen += 1
			continue
		var stale: int = newest - int(frames[entity])
		if (row["position"] as Vector3).distance_to(mine) <= radius:
			near += 1
			near_stale = maxi(near_stale, stale)
		else:
			far += 1
			if stale > far_stale:
				far_worst = entity
				far_worst_at = int(frames[entity])
			far_stale = maxi(far_stale, stale)
	return "FRESHNESS near=%d far=%d near_stale=%d far_stale=%d unseen=%d per_tick=%.2f newest=%d" % [near, far, near_stale,
		far_stale, unseen, per_tick, newest] + " far_worst=%d far_worst_at=%d client_id=%d" % [far_worst,
		far_worst_at, Sim.local_client_id()]


## HOW MANY CRAFT ARE INSIDE EACH CLIENT'S SPHERE, on the host, for SESSION_REPORT: `2:12,3:40` by client id, or `-`.
## No spaces, so every harness that splits the line on spaces and `=` still reads each key. `served` beside it is the
## host SERVER's own vehicle count, -1 elsewhere: `vehicles` is what this machine's CLIENT draws, and on a host whose
## prioritizer withheld something that is short too, so a joiner matching it proves nothing (tests/priority_peers.gd).
func _near_words() -> String:
	if Sim.server == null:
		return "-"
	var near: Dictionary = (Sim.server.priority_sphere() as Dictionary).get("near", {})
	var clients: Array = near.keys()
	clients.sort()
	var rows := PackedStringArray()
	for client in clients:
		rows.append("%d:%d" % [int(client), int(near[client])])
	return ",".join(rows) if not rows.is_empty() else "-"


## Which seat the player at THIS machine is in, in this craft, or -1. It is the one thing
## that decides whose hands may move a set of controls.
func _my_seat_in(vehicle: int, mine: int) -> int:
	if mine == 0:
		return -1
	for state in Sim.pilots:
		if int(state["client"]) == mine and int(state.get("vehicle", 0)) == vehicle:
			return int(state.get("seat", 0))
	return -1


## THE DESTINATION OF THE VEHICLE YOU ARE SITTING IN, as a beacon standing on it.
##
## Only your own, and only while something is taking it somewhere: a sky full of everyone
## else's waypoints is a sky you cannot see through. It comes off the wire with the
## vehicle rather than being asked of the server, because entity ids are per-world and a
## client has no way to ask "where is the aeroplane I am in going".
func _draw_waypoint() -> void:
	if _beacon == null:
		_beacon = _build_beacon()
	var view: VehicleView = rig.vehicle_view() if rig != null else null
	var state: Dictionary = Sim.current.get(view.entity, {}) if view != null else {}
	if not bool(state.get("has_route", false)):
		_beacon.visible = false
		return
	_beacon.visible = true
	_beacon.position = state.get("route", Vector3.ZERO)


## A tall thin column standing on the waypoint. Tall because the thing looking at it may be
## eight kilometres away and six hundred metres up, and at that range anything shaped like
## a marker is a pixel.
func _build_beacon() -> Node3D:
	var node := Node3D.new()
	node.name = "Waypoint"
	var mesh := MeshInstance3D.new()
	var column := CylinderMesh.new()
	column.top_radius = 3.0
	column.bottom_radius = 9.0
	column.height = BEACON_HEIGHT
	mesh.mesh = column
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.35, 1.0, 0.55, 0.35)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = glow
	node.add_child(mesh)
	add_child(node)
	return node


## How long until the screens are redrawn. See _draw_cockpit.
var _screens_due: float = 0.0


## THE CONTROLS AND SCREENS IN THE CRAFT YOU ARE SITTING IN, from the replicated positions.
##
## ONLY YOUR OWN CRAFT, and that is the rule rather than the optimisation: nobody can see
## into anybody else's cockpit, so nobody else's cockpit is ever assembled. Every question
## below is asked of `rig.vehicle_view()` and of nothing else, which is what keeps the
## craft's own state -- its instruments, its linkage, its systems -- in front of its crew
## and nowhere else.
##
## The positions come off the wire rather than from local input, because the whole point of
## the exercise is that the OTHER seat's lever moves when they move it.
func _draw_cockpit(_delta: float) -> void:
	var view: VehicleView = rig.vehicle_view() if rig != null else null
	if view == null or not view.is_manned():
		return
	var mine: int = rig.seat_index()
	# EVERY SCREEN IN THE CRAFT, from ONE reading of the craft's own state. Five times a
	# second rather than ninety: an instrument that changes faster than a human can read it
	# is an instrument nobody can read, and each update is a render target redrawn.
	_screens_due -= _delta
	if _screens_due <= 0.0:
		_screens_due = 0.2
		var state: Dictionary = view.craft_state()
		var roster: Array = view.crew()
		# THE WHOLE AIR PICTURE, not the crew alone: every screen that draws the map shows the traffic
		# nobody is in as well as the people, and tells them apart (`world/air_picture.gd`).
		var map_markers: Array[Dictionary] = AirPicture.contacts(_manifest(), Sim.current)
		for station in view.stations():
			(station as CockpitStation).show_state(state, roster)
			(station as CockpitStation).show_map(level_map, map_markers)
		if rig != null:
			rig.clipboard.show_map(level_map, map_markers)
	var shared: Dictionary = Sim.client.crew_controls(view.entity)
	var seats: Array = shared.get("seats", []) as Array
	var systems: Dictionary = Sim.client.craft_systems(view.entity)
	# ONE LAMP, shown on every button aboard. Anybody may flip it and everybody sees it,
	# which is the entire thing this button exists to demonstrate.
	var lamp: bool = bool(systems.get("crew_light", false))
	# THE LINKAGE, not the seat. Two yokes on one linkage have ONE position, so a control
	# nobody at this machine is holding shows where the controls actually ARE -- which is
	# what lets a copilot sit with their hands in their lap and watch the yoke in front of
	# them move with the pilot's.
	var linked_stick: Vector2 = shared.get("linked_stick", Vector2.ZERO)
	var linked_throttle: float = float(shared.get("linked_throttle", 0.0))
	var linked_rudder: float = float(shared.get("linked_rudder", 0.0))
	for seat in view.manned_seats():
		var entry: Dictionary = view.controls_for(int(seat))
		if entry.is_empty():
			continue
		var index: int = int(seat)
		# A control you are HOLDING is driven by your own hand. Applying the wire to it
		# would fight that hand with a value a round trip old -- and it is the one control
		# on the linkage whose position you already know.
		var lever := entry["throttle"] as VehicleControl
		var stick := entry["stick"] as VehicleControl
		# EVERY SEAT ON THE LINKAGE, AND THIS ONE IS ON IT TOO. Two wheels on one boat are ONE
		# helm: a wheel that sits still while the other one is hard over is a wheel lying about
		# which way the boat is turning. Reported from a session -- "both steering wheels should
		# be able to control the boat (and that works) but i don't see the other players inputs
		# in my wheel if i'm not holding it" -- and measured on all seventeen craft that carry
		# two pilots (`tests/crew_sync.gd`: they ask for 0.70 of roll, my own wheel read 0.00).
		#
		# `apply` REFUSES A CONTROL A HAND IS ON, so what this player is working is still
		# theirs and nothing here can fight a hand.
		#
		# WHY IT USED TO SKIP THIS SEAT, and why that reason is gone. The linkage was on the
		# VEHICLE, which the seat you are flying from PREDICTS, and on a predicted entity an
		# authoritative value only arrives on a rollback -- so between rollbacks the wire's copy
		# was stale, and a throttle drawn from it alternated between where the hand left it and
		# a value a round trip old. `CrewControls` has since moved to the CABIN, which nobody
		# predicts and everybody aboard snaps (`cockpit_components.hpp`, and `addon/tests/
		# crew_cabin`), so there is no stale copy left to alternate with. The one carve-out that
		# survived that move -- the airliner's shared throttle quadrant, which is why the
		# airliner, the Cessna and the Hawkeye were the only three craft whose throttle was
		# right -- is this rule, and is no longer a special case.
		#
		# EITHER MAY BE ABSENT. A control tower has no stick and no throttle -- it has a
		# radio, a screen and a button, and every one of those is worth sitting at -- so
		# every line below asks whether the control is there rather than assuming a cockpit
		# is three levers.
		if lever != null:
			lever.apply(Vector2(0.0, linked_throttle))
		if stick != null and not stick.is_held():
			# THE TWIST NEEDS THE GUARD SAID OUT LOUD. `apply` refuses a control a hand is on;
			# the line under it is a plain assignment and refuses nothing, and while this branch
			# only ever ran for somebody ELSE'S seat that could not matter. It matters now: a
			# wrist turned on the stick went straight back to the linkage's value a round trip
			# old, so the rudder read -0.27 with the wrist hard over the other way
			# (`tests/pedals.gd`, `a_wrist_turned_clockwise_on_the_stick_puts_the_right_pedal
			# _forward`). Both lines are under one `is_held` now rather than one of them being
			# quietly safe.
			stick.apply(linked_stick)
			stick.twist = linked_rudder
		# The rudder has nowhere else to show itself, so every seat gets an instrument for
		# it, and every one of them shows the LINKAGE.
		var needle := entry.get("rudder") as RudderIndicator
		if needle != null:
			needle.show_rudder(linked_rudder)
		# AND EVERY CONTROL THAT IS THE CRAFT'S, from the bus -- whatever it is and wherever it was
		# put. There is one set of nacelles, one flap gate, one trim and one master arm on the
		# aircraft, and every handle, wheel and switch for them shows where they ARE.
		#
		# BY SCOPE, NOT BY ROLE. This walked four roles -- extra, flaps, gear, drop -- through a
		# second copy of `channel_value` that knew four channels, so the trim wheel, the master
		# arm switch and anything the builder placed were drawn from the last hand that touched
		# them. `VehicleControl.scope` says whose a control is, and `shown_value` knows every
		# channel. See tests/shared_controls.gd.
		#
		# Which is also what makes a switch pressed on a SCREEN move the handle in the
		# cockpit. The page commands, the bus comes back, and this puts the lever where the
		# craft says it is -- so the two never disagree about the flap setting.
		#
		# `apply` refuses a control somebody has hold of, so there is no guard here for the
		# hand that is moving one. That used to be written as "unless it is mine and held",
		# which stopped being right when a hand could reach another seat's lever.
		for control in entry.values():
			var aboard := control as VehicleControl
			if aboard == null:
				continue
			# ONE LAMP ON EVERY CREW BUTTON, the builder's as well as the station's own.
			var lit := aboard as CrewButton
			if lit != null:
				lit.light(lamp)
			# AND THE PEDALS, wherever they were put: the rudder this player's own frame carried at their own seat, and the
			# linkage at every other -- the split the sticks above are drawn by. They show it; nothing reads it back.
			var feet := aboard as RudderPedals
			if feet != null:
				# THE LINKAGE, UNLESS THIS PLAYER'S OWN FEET ARE ON THEM. What this machine is
				# sending answers instantly and the linkage is a round trip behind, so a boot
				# going in is felt at once; a footwell nobody here is using shows what the
				# aircraft's rudder is actually doing, which is the other pilot. Nine craft
				# carry pedals at two flying seats and on all nine this pair lay flat while the
				# other pilot had full boot in -- and the rudder INDICATOR beside them, which
				# has always read the linkage, disagreed with them (`tests/crew_sync.gd`).
				var here_now: float = rig.rudder_sent()
				feet.show_rudder(here_now if index == mine and absf(here_now) > 0.0
					else linked_rudder)
			if aboard.scope != VehicleControl.Scope.CRAFT or aboard.channel < 0:
				continue
			var at: int = view.shown_value(aboard.channel)
			if at >= 0:
				aboard.apply(aboard.from_command(at))


## THE RUNWAYS, DRAWN FROM THEIR OWN NUMBERS.
##
## One MultiMesh for the asphalt, the centreline and the threshold bars of every runway together, because
## they are all flat boxes on the ground and none of them needs to be a node. Nothing here
## knows how long a strip is: `Terrain.runway_marks_for` generates the paint from each runway's frame,
## so changing RUNWAY_LENGTH lengthens the tarmac, adds stripes and moves the numbers. `Terrain.runways()` says which
## runways there are: the island's one, or one on each strip of the generated ground.
##
## No collision either. An aeroplane rolling down it is held up by the same ground plane
## that holds up everything else -- the tarmac is a metre of paint, not a shelf.
func _draw_runway() -> void:
	var frames: Array[Dictionary] = Terrain.runways()
	var marks: Array[Dictionary] = []
	# WHICH RUNWAY EACH MARK BELONGS TO, as the four numbers its pavement shader needs: see `_runway_frame_data`. Kept
	# beside the marks rather than worked out from them afterwards, because a stripe's own box says nothing about which
	# strip it was painted on and there would be nothing left to ask.
	var frame_data: Array[Color] = []
	# EACH OVER THE ONES BEFORE IT: where two cross, the later one's asphalt lies under the earlier's (Terrain.CROSSING_DROP).
	for i in range(frames.size()):
		var mine: Array[Dictionary] = Terrain.runway_marks_for(frames[i], frames.slice(0, i))
		var data: Color = _runway_frame_data(frames[i])
		marks.append_array(mine)
		for _mark in mine:
			frame_data.append(data)
	if marks.is_empty():
		return
	var slabs := MultiMesh.new()
	var block := BoxMesh.new()
	block.size = Vector3.ONE
	slabs.transform_format = MultiMesh.TRANSFORM_3D
	slabs.use_colors = true
	# THE RUNWAY'S FRAME, PER INSTANCE. Without it the pavement's seams and its touchdown zone would restart inside
	# every painted stripe; with it a stripe and the asphalt under it work out the same coordinate.
	slabs.use_custom_data = true
	slabs.mesh = block
	slabs.instance_count = marks.size()
	runway_frames = frame_data
	for i in range(marks.size()):
		slabs.set_instance_custom_data(i, frame_data[i])
		var mark: Dictionary = marks[i]
		var half: Vector3 = mark["half_extents"]
		# SCALED IN THE MARK'S OWN FRAME, then turned: `Basis.scaled` scales along the WORLD's axes, so a strip turned a
		# quarter (every runway along x -- the generated ground's and the south shore's) was painted along z, across its
		# own centreline, and the aeroplanes landed across the paint (lane/pattern, 2026-09-19).
		slabs.set_instance_transform(i, Transform3D(
			Basis(Vector3.UP, float(mark.get("yaw", 0.0))) * Basis.from_scale(half * 2.0),
			mark["position"]))
		slabs.set_instance_color(i, mark.get("colour", Color.WHITE))
	# THE PAVEMENT, on whichever tier is on. What replaced the bare StandardMaterial3D here, and what it costs, is in
	# `pavement.gdshaderinc`; the short of it is that the asphalt was one flat grey from a metre up and from three
	# thousand feet alike, and now it has its paving seams and its rubber within sight of them.
	_runway_plain = _pavement_paint(PAVEMENT)
	_runway_fine = _pavement_paint(PAVEMENT_FINE)
	var node := MultiMeshInstance3D.new()
	node.name = "Runway"
	node.multimesh = slabs
	node.material_override = _runway_fine if _finish_is_fine() else _runway_plain
	add_child(node)
	# AND ITS LIGHTS, which are how anybody finds it from further off than the paint. Once:
	# `_build` runs again on every session, and a second set on top of the first would be
	# twice the fill for the same picture. See `Terrain.runway_lights`.
	if get_node_or_null("RunwayLights") == null:
		var every: Array[Dictionary] = []
		for frame in frames:
			every.append_array(Terrain.runway_lights_for(frame, frames.filter(func(f: Dictionary) -> bool: return f != frame)))
		var lights := VehicleLights.build(every, 0, false)
		lights.name = "RunwayLights"
		add_child(lights)


## ONE RUNWAY'S FRAME, AS THE FOUR NUMBERS ITS PAVEMENT SHADER READS off `INSTANCE_CUSTOM`: where its middle is in
## plan, which way it points, and half its length. A `Color` because that is what a MultiMesh's custom data is; the
## four floats are not a colour and are never drawn as one.
##
## OFF THE FRAME `Terrain` LAID THE RUNWAY TO, not measured back off the boxes it produced. The shader's touchdown
## zone is a distance from the threshold, and the threshold is the authority's, so this asks it.
static func _runway_frame_data(frame: Dictionary) -> Color:
	var centre: Vector3 = frame["centre"]
	return Color(centre.x, centre.z, float(frame["bearing"]), float(frame["length"]) * 0.5)


## A PAVEMENT MATERIAL ON ONE OF THE TWO SHADERS, carrying the ranges `DetailReach` holds and nothing typed here. Both
## tiers are made at build and kept, so flicking the finish swaps a material rather than compiling a shader on the
## frame the player flicked it.
## ONLY THE RANGES THE SHADER ACTUALLY DECLARES: PLAIN has no aggregate and so no `grain_fade`, and a ShaderMaterial
## will happily hold a parameter its shader never reads. Setting it anyway would make a test that asks the material
## what range it carries pass on a shader that cannot use it, which is the tautology trap in `testing_godot_headless.md`.
static func _pavement_paint(which: Shader) -> ShaderMaterial:
	var paint := ShaderMaterial.new()
	paint.shader = which
	var wanted: Dictionary = DetailReach.pavement_numbers()
	var declared: Dictionary = {}
	for uniform in which.get_shader_uniform_list():
		declared[String(uniform["name"])] = true
	for named in wanted:
		if declared.has(named):
			paint.set_shader_parameter(named, wanted[named])
	return paint


## EVERY AIR BASE ON THIS WORLD, DRAWN: one `AirbaseView` a base, under one node that a second build replaces rather than
## doubles. What is drawn is what `AirbasePlan.bases()` laid -- the same list `Terrain.boxes()` gives the simulation.
func _draw_airbases() -> void:
	var old: Node = get_node_or_null("Airbases")
	if old != null:
		remove_child(old)
		old.queue_free()
	var holder := Node3D.new()
	holder.name = "Airbases"
	add_child(holder)
	# THE TIER THE LEVEL IS ALREADY ON, put on each base as it is drawn. The bases are built AFTER
	# `_wear_the_finish` has run, so a base that waited to be told would stand on PLAIN for the rest of the session
	# on a FINE world -- which is the shape of bug `Finish` calls "the switch being broken".
	var fine: bool = _finish_is_fine()
	for base in AirbasePlan.bases():
		var view: AirbaseView = AirbaseView.build(base)
		holder.add_child(view)
		view.wear(fine)


## THE RAILWAY, DRAWN ONTO ITS OWN WAYPOINTS: `PermanentWay`'s rails, ties and bed, handed to the `SceneryYard` as
## pieces, which draws them a kilometre at a time. Twenty kilometres of track is a lot of pieces, none of them need to be
## nodes, and one MultiMesh of all of them was drawn whole whenever any of it was in frame.
##
## POSED THROUGH `rail_pose`, which is the same function the locomotive is driven by and the carriages are hung from, and
## LAID FROM WAYPOINT TO WAYPOINT: a length of rail is exactly the chord a wheel rides, not a 12 m sample of the curve
## beside it. See `PermanentWay.lay`, and its doc block for the five things that were wrong with the track before
## (2026-09-19): the rails in dashes, the wheels in the rails, slab ties, a railway floating over the grass and the gauge.
##
## No collision: a train is not a free body and does not need rails to hold it up -- it is held by its own scalar
## position along the line. The track is there to be seen.
func _draw_railway(points: Array[Vector3]) -> void:
	var total: float = Sim.client.rail_length(0)
	if _railway_drawn or total <= 0.0:
		return
	_railway_drawn = true
	var laid: Dictionary = PermanentWay.lay(points,
		func(distance: float) -> Dictionary: return Sim.client.rail_pose(0, distance, 0.0, 0.0))
	# THE BANK GOES DOWN TO THE GROUND, which on the island is the slab at 0 all the way round the loop: the railhead's
	# height over it is the bank's whole depth.
	var ground: float = Terrain.ground_height(points[0]) - points[0].y if not points.is_empty() else 0.0
	if scenery != null:
		scenery.draw_railway(laid["bed"], PermanentWay.bed(ground), _far(), "RailwayBed")
		scenery.draw_railway(laid["rails"], PermanentWay.rails(), _far(), "Railway")
		scenery.draw_railway(laid["ties"], PermanentWay.tie(), PermanentWay.TIE_REACH, "RailwayTies")


## EVERY LOCOMOTIVE THIS MACHINE IS DRAWING, found by kind in `Sim.current` and put in entity
## order so every peer numbers them the same way.
##
## **NEVER BY THE ID `spawn_train` RETURNED, WHICH IS THE SERVER'S.** `_trains` held server ids
## and `_draw_carriages` asked `Sim.client.rail_state` with them. The two worlds keep their own
## entity ids, so that lookup is right only while the two happen to agree -- and it is not a
## question of one world having more entities than the other. Measured on 2026-09-17: **82
## vehicles on the server and 82 on the client, and the trains' ids two apart**, because the
## client creates entities as records ARRIVE and the server creates them as it SPAWNS, and
## nothing makes those two orders the same.
##
## SO THE CARRIAGES WERE DRAWN BY COINCIDENCE AND STOPPED BY COINCIDENCE, which is worse than
## never having worked: a gallery picture taken at 10:42 that day has five cars behind the
## locomotive, and by 14:20 the same code drew none, with 0 of 2 ids matching under two
## different probes. Nothing between those two times went near the railway. **Any change to
## what the level spawns can silently empty every train in the game**, and no test could notice:
## `tests/scenery_shot.gd`, `tests/town_lights_shot.gd` and the parade all walk `_carriages` to
## HIDE the cars before a picture, and walking an empty dictionary hides nothing and passes. A
## check whose job is to turn something off cannot tell you the something was never on.
##
## It was found by pointing a camera at a train and seeing a locomotive on its own, which is
## `CLAUDE.md` rule 2 in one sentence. The rule is already written down for aeroplanes --
## `modelling_here.md` section 7, "find the drawn craft by kind and position in `Sim.current`,
## never by a spawn's returned id", after `hawkeye_shot` photographed a patrol boat eight times.
## This is the same bug in the LEVEL rather than in a test, and the entry deserves widening from
## probes to anything at all that holds a server id and wants a drawn node.
func _the_trains_being_drawn() -> Array[int]:
	var out: Array[int] = []
	for entity in Sim.current:
		if int((Sim.current[entity] as Dictionary).get("kind", -1)) == Sim.Kind.TRAIN:
			out.append(int(entity))
	out.sort()
	return out


## BOXCARS, hung behind a locomotive at one car length along the SAME railway.
##
## They are drawn, not simulated: pure visuals sampling the track at the engine's distance
## less a few car lengths. That is worth doing rather than making each one a vehicle,
## because it makes the coupling exact -- no lag, no rubber band, nothing to replicate --
## and because a carriage nobody can sit in has no reason to exist in the simulation at all.
##
## Each one is placed by its TRUCKS, two samples rather than one, which is what makes a
## train spanning a curve cut the inside and overhang the outside instead of bending along
## the arc.
##
## AND ITS ORIGIN IS ON THE RAILHEAD, so the lift is zero. `Boxcar` carries its own heights in
## its own frame, whose up IS the track's up, so a banked corner leans the whole car exactly as
## it leans the rails under it -- and there is no half-a-height fudge in two files to keep in
## step. Before this, the height was typed here and the mesh's size was typed eight lines away.
func _draw_carriages() -> void:
	if Sim.client == null:
		return
	var drawn: Array[int] = _the_trains_being_drawn()
	for index in range(drawn.size()):
		var engine: int = drawn[index]
		var state: Dictionary = Sim.client.rail_state(engine)
		if state.is_empty():
			continue
		if not _carriages.has(engine):
			_carriages[engine] = _build_carriages(Terrain.cars_behind(index))
		var cars: Array = _carriages[engine]
		var track: int = int(state.get("track", 0))
		# HOW FAR IT HAS GOT AS THIS FRAME IS DRAWN, not as the tick left it: `Sim.rail_distance` carries the tick's
		# distance forward by the train's own speed through the part of the tick already drawn. Placed from the raw tick
		# distance, a rake stood still through a tick and jumped 0.183 m at every tick boundary while the locomotive
		# ahead of it -- drawn between its two simulated poses, like every other vehicle -- moved smoothly (the user,
		# 2026-09-19: the train's jitter). See `Sim.rail_distance`.
		var lead: float = Sim.rail_distance(engine)
		# THE FIRST CAR HANGS OFF THE ENGINE, NOT OFF AN IMAGINARY BOXCAR. It was spaced like every
		# other car, `SPACING` from the engine's middle, which treats a 15.44 m locomotive as a 12.6 m
		# car: it drew the first boxcar 0.54 m INSIDE the F7A, and 1.82 m inside the 18 m box before
		# it. So it stands half the engine, two couplers and half a car back, the engine's length
		# asked of the shape, and every car after it one `SPACING` further. `tests/rakes_drawn.gd`.
		var first: float = _engine_half_length() + BOXCAR.COUPLER_REACH * 2.0 + BOXCAR.LENGTH * 0.5
		for i in range(cars.size()):
			var behind: float = lead - first - BOXCAR.SPACING * float(i)
			var pose: Dictionary = Sim.client.rail_pose(track, behind, BOXCAR.TRUCK_CENTRES, 0.0)
			if pose.is_empty():
				continue
			var car := cars[i] as Node3D
			car.position = pose["position"]
			car.basis = Basis(pose["basis"] as Quaternion)


## HALF THE LOCOMOTIVE'S LENGTH, asked of the shape table once and kept: it does not change while a
## level runs, and `_draw_carriages` wants it every frame for every train.
var _engine_half: float = -1.0


func _engine_half_length() -> float:
	if _engine_half < 0.0:
		var extents: Vector3 = Sim.geometry_of(Sim.Kind.TRAIN).get("extents", Vector3.ZERO) as Vector3
		_engine_half = extents.z
	return _engine_half


## ONE MESH AND ONE MATERIAL FOR THE WHOLE RAKE. Twenty cars behind two locomotives are twenty
## instances of the same `ArrayMesh`, built once by `Boxcar` and shared. The pair it replaces
## made a fresh `BoxMesh` and a fresh `StandardMaterial3D` per car, so five cars were five
## meshes and five materials for five identical boxes.
func _build_carriages(how_many: int) -> Array:
	var out: Array = []
	var mesh: ArrayMesh = BOXCAR.mesh()
	var paint: StandardMaterial3D = BOXCAR.painted()
	for i in range(how_many):
		var car := MeshInstance3D.new()
		car.name = "Boxcar%d" % i
		car.mesh = mesh
		car.material_override = paint
		add_child(car)
		out.append(car)
	return out


## The node actually drawn for one vehicle, or null. For tests that need to look at what is
## rendered rather than at what the simulation thinks.
## EVERY MOMENT THE SIMULATION HAS TOLD THIS MACHINE ABOUT, played once.
##
## A CUE IS THE OTHER HALF OF THE WIRE. Everything else this file draws is read from a state
## that is still true -- where a vehicle is, how full a tank is, whether a fire is out -- and
## none of it can say "and it happened just now". A gush of water leaving an aeroplane is a
## moment: it is stamped with the frame the pilot's command belonged to, it reaches every
## machine that can see that aeroplane, and it is played once on each of them.
##
## `Sim.cues` is DRAINED by the read, so this is the only place that may look at it.
##
## `late` is how far behind the frame it happened on this machine is drawing, and it is
## carried into the effect rather than thrown away: an effect that always started at its
## beginning would lag the aeroplane by the length of the wire.
func _play_the_cues() -> void:
	if Sim.cues.is_empty():
		return
	for row in Sim.cues:
		var cue: Dictionary = row
		match int(cue.get("what", -1)):
			Sim.Cue.WATER_RELEASE:
				var craft: VehicleView = view_of(int(cue["entity"]))
				if craft == null or shots == null:
					continue
				# AT THE BELLY, where the doors are, and in the aeroplane's own frame so
				# that it is under the hull rather than at the point the hull is drawn from.
				var deep: float = float((Sim.geometry_of(craft.kind).get("extents",
					Vector3.ONE) as Vector3).y)
				shots.release(craft.global_transform * Vector3(0.0, -deep, 0.0),
					float(cue.get("value", 255)) / 255.0, float(cue.get("late", 0.0)))
			# A MISSILE OFF A RAIL: which pylon, so the one that appears next is drawn coming off it.
			Sim.Cue.MISSILE_LAUNCH:
				var launcher: VehicleView = view_of(int(cue["entity"]))
				if launcher == null or missiles == null:
					continue
				var packed: int = int(cue.get("value", 0))
				missiles.launched(launcher, MissileYard.pylon_of(Sim.missile_schema(launcher.kind), packed & 15),
					packed >> 4, float(cue.get("late", 0.0)))
			# AND ONE ENDING, which sets the burst off if the lingering state has not already.
			Sim.Cue.MISSILE_END:
				if missiles != null:
					missiles.ended(int(cue["entity"]), int(cue.get("value", 0)))
			# A CRAFT DESTROYED, this frame: the fireball, and the airframe gone (lane/combat).
			Sim.Cue.DESTROYED:
				if damage != null:
					damage.destroyed(view_of(int(cue["entity"])), int(cue.get("value", 0)))


## WHERE A LAUNCHER'S PYLON IS, for a missile with no launch cue to claim. The launcher is named by client, which is
## the same number on every machine, and found through the pilot list. See MissileYard.find_rail.
func _rail_of_client(client_id: int, pylon: int) -> Dictionary:
	for row in Sim.pilots:
		var pilot: Dictionary = row
		if int(pilot.get("client", -1)) != client_id:
			continue
		var launcher: VehicleView = view_of(int(pilot.get("vehicle", 0)))
		if launcher == null:
			return {}
		return {"rail": launcher, "pylon": MissileYard.pylon_of(Sim.missile_schema(launcher.kind), pylon)}
	return {}


## THE ENTITY A NAMED SPAWN BECAME on the server (`Terrain._named`), or 0: asked, never predicted, because a ship under way
## has steered and heaved since it was put.
func spawned_entity(name: StringName) -> int:
	return int(_spawned.get(name, 0))


func view_of(entity: int) -> VehicleView:
	return _views.get(entity)


## `SPECTACLES strength=... near=... drawn=N bigger=M biggest=X`: see `_update_status`.
func _spectacles_line() -> String:
	var bigger: int = 0
	var biggest: float = 1.0
	for view in _views.values():
		var times: float = (view as VehicleView).basis.get_scale().x
		if times > 1.0 + 1e-6:
			bigger += 1
		biggest = maxf(biggest, times)
	var pair: Spectacles = rig.spectacles if rig != null else null
	return "SPECTACLES strength=%s near=%d drawn=%d bigger=%d biggest=%.3f" % [
		Spectacles.STRENGTH_WORDS[pair.strength] if pair != null else "NONE", int(pair.near_m) if pair != null else 0,
		_views.size(), bigger, biggest]


## EVERY CRAFT JUST DRAWN, THROUGH THE RIG'S SPECTACLES. See `Spectacles` and the note where this is called.
func _draw_through_the_spectacles(seen: Dictionary, eye: Vector3) -> void:
	if rig == null or rig.spectacles == null or not rig.spectacles.is_on():
		if Spectacles.stretched_count() > 0:
			Spectacles.put_back_every_part()
		return
	var own: VehicleView = rig.vehicle_view()
	for entity in seen:
		var view: VehicleView = _views[entity]
		if view != own:
			rig.spectacles.magnify(view, view.kind, eye, Sim.current.get(entity, {}))


func _view_for(entity: int, kind: int) -> VehicleView:
	if _views.has(entity):
		return _views[entity]
	var view := VEHICLE_SCENE.instantiate() as VehicleView
	# A MANNED CRAFT'S STATIONS ARE BUILT OVER FRAMES in a flight, never a second in one: see
	# `VehicleView.station_build_budget_ms`.
	view.station_build_budget_ms = VehicleView.GAME_BUILD_MS
	_vehicles_root.add_child(view)
	view.setup(entity, kind)
	_views[entity] = view
	return view


## SOMEBODY ELSE'S SIGNAL LAMP: its colour and who holds it off their craft's bus, and where it is from their hands or
## their head as their pilot state has them. Every remote pilot, in any craft, the crew of this one included -- which
## is how a player in another aircraft sees a lamp flashed at them. See `SignalLamp`, "on the wire".
func _show_their_lamp(view: VehicleView, seat: int, state: Dictionary) -> void:
	var lamp: SignalLamp = SignalLamp.in_station(view.station_for(seat)) if view != null else null
	if lamp == null or lamp.channel < 0:
		return
	var at: int = view.shown_value(lamp.channel)
	if at >= 0:
		lamp.apply(lamp.from_command(at))
	lamp.follow(state)


func _pilot_for(client_id: int, anchor: Node3D) -> RemotePilot:
	var pilot: RemotePilot = _pilots.get(client_id, null)
	if pilot == null or not is_instance_valid(pilot):
		pilot = PILOT_SCENE.instantiate() as RemotePilot
		anchor.add_child(pilot)
		pilot.setup(client_id, Net.name_of(client_id))
		_pilots[client_id] = pilot
	elif pilot.get_parent() != anchor:
		# They changed seats. Reparent rather than rebuild, so their identity and colour
		# follow them across.
		pilot.reparent(anchor, false)
	return pilot


## ONE MORE MACHINE OF THAT KIND, FLYING ITSELF.
##
## The world used to be built with a hundred and sixty of these and it does not any more:
## the wire fits about fifty-two entities in a tick and shares them out evenly, so past that
## every machine in the sky gets less fresh and the ones near you jitter and appear to sink.
## See "THE CEILING IS 1024 BYTES PER CLIENT PER TICK" in agents.md, which measured it, and
## `Terrain.FLEET_AIR`, which is why the sky is quiet to begin with.
##
## THE HOST ONLY, because spawning is. `Sim.spawn_ai_vehicle` returns 0 on a client rather
## than reaching across the wire, and a button that silently did nothing on one machine and
## something on another would be worse than one that says so.
##
## COUNTED RATHER THAN RANDOM, so two presses put two aeroplanes in two pieces of air. The
## count is this session's, not the entity id: seeding an autopilot off the id is what made
## adding two spawns reseed all forty and break every formation, which is written up beside
## the fix.
var _added: int = 0

## ATTACKERS AT WHATEVER THE HOST IS IN, from the clipboard (lane/combat): a raid, or all of them called off with -1.
func send_attackers(planes: int, helis: int) -> void:
	if Sim.server == null or attackers == null:
		_tell_the_board("Only the host can send attackers.")
		return
	if planes < 0:
		attackers.clear()
		_tell_the_board("Attackers called off.")
		return
	var mine: int = 0
	for pilot in Sim.server.pilot_states():
		if int((pilot as Dictionary)["client"]) == Sim.local_client_id():
			mine = int((pilot as Dictionary)["vehicle"])
	if mine == 0:
		_tell_the_board("Sit in something first: attackers come for your craft.")
		return
	var sent: Array[int] = attackers.raid(mine, planes, helis)
	_tell_the_board("%d attackers on their way." % sent.size())


func add_traffic(kind: int) -> void:
	if Sim.server == null:
		_tell_the_board("Only the host can add to the world.")
		return
	_added += 1
	var one: Dictionary = Terrain.one_more(kind, _added, _grid)
	if one.is_empty():
		_tell_the_board("Nowhere for a %s to go." % Sim.kind_name(kind))
		return
	if Sim.spawn_ai_vehicle(int(one["kind"]), one["position"],
			float(one["yaw"]), one["velocity"]) == 0:
		_tell_the_board("The simulation refused another %s." % Sim.kind_name(kind))
		return
	# AND SAY WHAT IT COST. The number is the point: about fifty-two machines fit in a
	# tick's budget, so watching it climb past that with the sky in front of you is a
	# better way to learn where the ceiling is than any number in a document.
	var now: int = Sim.client.vehicle_states().size() if Sim.client != null else 0
	_tell_the_board("Added a %s. %d machines in the world%s." % [Sim.kind_name(kind), now,
		" -- past what the wire keeps fresh" if now > 52 else ""])
	print("[sky] added a %s -- %d machines now" % [Sim.kind_name(kind), now])


func choose_stack_count(count: int) -> void:
	if holding_stack == null or Sim.server == null:
		_tell_the_board("Only the host can set the aircraft load.")
		return
	holding_stack.set_count(count)
	_tell_the_board("The holding stack is changing to %d planes." % holding_stack.target_count())


## THE LINK ROW ON THE CLIPBOARD, which sets THIS MACHINE'S link and says so. A press is a person choosing, so from here
## on it beats whatever the level asks for (`Net.choose_link`).
##
## WHAT A PRESS DOES DEPENDS ON WHO PRESSES IT, and the words say which. A joiner's press is its own link, and the whole
## of it: a delay on both its edges is crossed once in each direction, so 80 ms is 80 one way and 160 round trip. A
## HOST'S press is added to every joiner's link and to none of its own, because the host's client is in the host's
## process and never goes near a socket -- which is why the stress level asks the joiners for the link and the host for
## nothing (`Net.suit_the_link`), and why a host that presses this is lengthening somebody else's afternoon.
func choose_link_latency(ms: int) -> void:
	Net.choose_link(ms)
	var delay: int = Net.extra_latency_ms
	var words: String = "This machine delays both its edges by %d ms: %d ms one way to the host, %d ms round trip." % [
		delay, delay, delay * 2]
	if not Net.is_networked():
		words = "This machine's link is %d ms each way, and there is no socket here to delay." % delay
	elif Net.is_host:
		words = "The host's edges now delay by %d ms, which is added to every joiner's link and to none of the host's own." % delay
	_tell_the_board(words)


## SAVE BANDWIDTH, from TRAFFIC's switch: `Sim` decides and keeps it, and the board is told what is in force either way,
## so a refused press puts the switch back where it was.
func choose_save_bandwidth(on: bool) -> void:
	var refused: String = Sim.set_save_bandwidth(on)
	if rig != null and is_instance_valid(rig) and rig.clipboard != null:
		rig.clipboard.show_save_bandwidth(Sim.save_bandwidth)
		if refused != "":
			rig.clipboard.say_no(refused)
			return
	_tell_the_board("Far players' heads and hands are %s." % ["not sent past %d m" % int(Sim.POSE_FAR_M) if on
		else "sent at any distance"])


func _tell_the_board(what: String) -> void:
	if rig != null and is_instance_valid(rig) and rig.clipboard != null:
		rig.clipboard.say(what)
	print("[sky] %s" % what)


## Anything the simulation stopped telling us about has gone. Driven off absence from the
## report rather than off a despawn message, so there is nothing to miss.
func _reap(seen: Dictionary) -> void:
	for entity in _views.keys():
		if seen.has(entity):
			continue
		var view: VehicleView = _views[entity]
		# Never free a node the local rig is sitting in: the rig is a CHILD of it and
		# would be freed with it, taking the player's camera and both hands.
		if rig != null and is_instance_valid(rig) and view.is_ancestor_of(rig):
			rig.reparent(self, false)
			rig.seat = null
		if is_instance_valid(view):
			view.queue_free()
		_views.erase(entity)


func _forget_missing_pilots(present: Dictionary) -> void:
	for client_id in _pilots.keys():
		if present.has(client_id):
			continue
		var pilot: RemotePilot = _pilots[client_id]
		if is_instance_valid(pilot):
			pilot.queue_free()
		_pilots.erase(client_id)


func _forget() -> void:
	# Let go of the vehicle first: the rig must not be a child of a node about to be freed.
	if rig != null and is_instance_valid(rig) and rig.get_parent() != self:
		rig.reparent(self, false)
		rig.seat = null
	for view in _views.values():
		if is_instance_valid(view):
			view.queue_free()
	for pilot in _pilots.values():
		if is_instance_valid(pilot):
			pilot.queue_free()
	_views.clear()
	_pilots.clear()
	if holding_stack != null and is_instance_valid(holding_stack):
		remove_child(holding_stack)
		holding_stack.queue_free()
	holding_stack = null
	if net_stats != null and is_instance_valid(net_stats):
		remove_child(net_stats)
		net_stats.queue_free()
	net_stats = null
	# AND THE RADAR, torn down with the rest of the level: it connected to `Net.radar_heard` in its `_ready`, and a
	# watch left behind across a level change would keep writing a picture of the world that has gone.
	if radar != null and is_instance_valid(radar):
		remove_child(radar)
		radar.queue_free()
	radar = null
	# AND THE AIRPORT LIFE, out of the tree before it is freed, for the same reason the room is below.
	for airport_node in [traffic_plan, airport_traffic]:
		if airport_node != null and is_instance_valid(airport_node):
			remove_child(airport_node)
			airport_node.queue_free()
	traffic_plan = null
	airport_traffic = null
	# AND THE ROOM, if the last build stood one: TAKEN OUT of the tree before it is freed, not only queued. A queued free
	# happens at the end of the frame, so a second build would have added its room beside a node with the same name and
	# `get_node("BriefingRoom")` would have found whichever came first.
	if room != null and is_instance_valid(room):
		remove_child(room)
		room.queue_free()
	room = null
	if device_yard != null and is_instance_valid(device_yard):
		remove_child(device_yard)
		device_yard.queue_free()
	device_yard = null
	if hangar_yard != null and is_instance_valid(hangar_yard):
		remove_child(hangar_yard)
		hangar_yard.queue_free()
	hangar_yard = null
	if trace_level != null and is_instance_valid(trace_level):
		remove_child(trace_level)
		trace_level.queue_free()
	trace_level = null


func _update_status() -> void:
	var status: Dictionary = Sim.client.net_status()
	var timing: Dictionary = Sim.client.timing()
	var role: String = "Solo"
	if rig != null and rig.clipboard != null:
		var stack_count := holding_stack.count() if holding_stack != null else 0
		var peers := maxi(Net.aboard() - 1, 0)
		var server_status: Dictionary = Sim.server.net_status() if Sim.server != null else status
		var out_per_peer := float(server_status.get("bytes_out_per_second", 0.0)) / 1000.0 / float(maxi(peers, 1))
		var packets_tick := ceili(out_per_peer * 1000.0 / 120.0 / 1200.0)
		var rollbacks := int((Sim.client.resim_stats() as Dictionary).get("count", 0))
		var now := Time.get_ticks_msec()
		var elapsed := maxf(float(now - _load_last_at) / 1000.0, 0.001) if _load_last_at > 0 else 1.0
		var rollback_rate := float(maxi(rollbacks - _load_last_rollbacks, 0)) / elapsed
		_load_last_rollbacks = rollbacks
		_load_last_at = now
		var breakdown: Dictionary = Sim.server.tick_breakdown() if Sim.server != null else {}
		var tick_ms := float(breakdown.get("total_us", breakdown.get("total", 0.0))) / 1000.0
		rig.clipboard.show_load_test(stack_count, Net.extra_latency_ms,
			"%d peers · %.1f kB/s each · %d pkt/tick · buffer %d · %.1f rollback/s · tick %.2f ms%s" % [
				peers, out_per_peer, packets_tick, int(timing.get("buffer_frames", 0)), rollback_rate, tick_ms,
				_sphere_words()])
	if Net.is_networked():
		role = "Host" if Net.is_host else "Client"
		# THE CODE A FRIEND TYPES, on the one line a monitor player reads while flying. The desk said it once and is gone.
		if Net.session_code != "":
			role += " (Steam %s)" % JoinCode.spell(Net.session_code)
	var mode: String = "VR" if (rig != null and rig.using_xr) else "flat"
	# WHAT THIS MACHINE'S SPECTACLES DREW, with `--spectacles=1`, for tests/spotting_peers.gd: the setting, how many craft
	# are drawn and how many of them bigger than they are, and the biggest scale. A machine wearing none must say 1.000.
	if _asked("spectacles") == "1":
		print(_spectacles_line())
	# A LINE FOR A HARNESS, with `--report=1`: tests/two_peers.gd starts a host and a joiner from the command line and
	# reads this out of their log files. `clients` is every machine whose sync client this one can name: itself, once
	# sync has given it an id, and each Godot peer `Sim.client_of_peer` maps to a client. `pilots` is every pilot this
	# world draws, the remote ones and this machine's own. Both come to 2 on both machines only when a second PLAYER has
	# arrived and is flying, which a connected socket alone never makes true.
	if _asked("report") == "1":
		var named: int = 1 if Sim.local_client_id() != 0 else 0
		for peer in multiplayer.get_peers():
			if Sim.client_of_peer(peer) != 0:
				named += 1
		# `crew` is every crewed craft this machine lists on its CREW page, as `kind:a.b.c.d` with a client id or `-` per
		# seat, sorted, so two machines that agree print the same (tests/crew_peers.gd). `answer` is what the server last
		# said to this machine's JOIN, or `none`.
		# AND WHAT A LOST JOIN LEAVES BEHIND, for tests/crew_peers.gd when the host never answers: on the host, every button
		# the server has applied from anybody else's frames (`buttons_seen`, OR-ed since the start -- 32 is a JOIN) and how
		# many JOINs it has decided; on a joiner, whether its rig is still holding a JOIN and how far its prediction leads.
		var evidence: String = ""
		if Sim.server != null and Sim.server.has_method("buttons_seen"):
			for state in Sim.server.pilot_states():
				if int((state as Dictionary).get("client", 0)) != Sim.local_client_id():
					_buttons_seen_from_others |= int(Sim.server.buttons_seen(int((state as Dictionary).get("entity", 0))))
			evidence = " seen=%d joins=%d" % [_buttons_seen_from_others,
				(Sim.server.join_log() as Array).size() if Sim.server.has_method("join_log") else -1]
		elif rig != null and Sim.client != null:
			evidence = " holding=%d lead=%d" % [int(rig.get("_join_asked")),
				int((Sim.client.timing() as Dictionary).get("prediction_lead", 0))]
		if _asked("craft") != "" and rig != null and rig.clipboard != null:
			var craft_words: String = rig.clipboard.page().said_text().replace(" ", "_")
			evidence += " craft_answer=%s" % (craft_words if craft_words != "" else "waiting")
		# `sky`, `clouds` and `finish` are what this machine DRAWS, read off the daylight, the yard and the finish rather than
		# off `Net`: tests/sky_peers.gd holds that the first two follow the host and the third does not.
		# AND THE CLOCK (2026-09-18): the session's time as this machine works it out, the session's frame it worked it out
		# at, the rate, and the height of the sun this machine last DREW -- so tests/sky_peers.gd can hold a joiner's clock to
		# the host's own sums at the joiner's frame, and its drawn sun to the host's.
		var sky_drawn: String = " sky=%s clock=%.4f sky_frame=%.1f rate=%s sun=%.3f clouds=%s finish=%s" % [
			String(DaylightTuning.When.keys()[daylight.time]).to_lower() if daylight != null and daylight.time >= 0 else "none",
			Net.clock_now(), Net._clock_frame_now(), Net.clock_rate,
			float(daylight.look.get("sun_height", -90.0)) if daylight != null else -90.0,
			"on" if clouds_drawn() else "off", "fine" if _finish_is_fine() else "plain"]
		# WHAT THIS MACHINE'S RADAR PICTURE HOLDS, for tests/radar_peers.gd: how many contacts and how old, plus the
		# call signs so a suite can say WHICH aeroplane is on the plot rather than only how many are. No spaces in any
		# value -- every harness here splits on spaces and then on `=`.
		var radar_names := PackedStringArray()
		for contact in (radar.rows if radar != null and is_instance_valid(radar) else []):
			radar_names.append(String((contact as Array)[7]).replace(" ", "_"))
		var radar_live: bool = radar != null and is_instance_valid(radar)
		var radar_said: String = " radar=%d radar_age_ms=%d radar_head=%s radar_from_tower=%s radar_who=%s" % [
			radar_names.size(), int((radar.age() * 1000.0) if radar_live else -1.0),
			("%d,%d,%d" % [roundi(radar.head.x), roundi(radar.head.y), roundi(radar.head.z)]) if radar_live else "-",
			("yes" if radar.from_the_tower else "no") if radar_live else "-",
			",".join(radar_names) if not radar_names.is_empty() else "-"]
		var identity_rows := PackedStringArray()
		for card in Net.roster_cards():
			identity_rows.append("%d:%s:%d" % [int(card["player"]), String(card["name"]).replace(" ", "_"),
				int(card["colour"])])
		var carrier_in := _carrier_total(Net.received)
		var carrier_out := _carrier_total(Net.sent)
		var socket := _enet_window()
		var vehicles: int = Sim.client.vehicle_states().size()
		var stack_count: int = holding_stack.count() if holding_stack != null else 0
		var tick_breakdown: Dictionary = Sim.server.tick_breakdown() if Sim.server != null else {}
		var tick_us := float(tick_breakdown.get("total_us", tick_breakdown.get("total", 0.0)))
		print("SESSION_REPORT role=%s transport=%s level=%s held=%d clients=%d pilots=%d vehicles=%d stack=%d crew=%s answer=%s roster=%s link_ms=%d latency_frames=%d buffer=%d rollbacks=%d rx_packets=%d rx_bytes=%d rx_largest=%d tx_packets=%d tx_bytes=%d tx_largest=%d enet_in_packets=%d enet_in_bytes=%d enet_out_packets=%d enet_out_bytes=%d server_tick_ms=%.3f sphere=%s near=%s served=%d%s%s%s" % [
			("host" if Net.is_host else "client") if Net.is_networked() else "solo", Net.transport, Net.level, Net.held_back, named,
			_pilots.size() + 1, vehicles, stack_count, _crew_line(), String(Sim.join_answer.get("why", "none")),
			",".join(identity_rows), Net.extra_latency_ms, int(timing.get("latency_frames", 0)),
			int(timing.get("buffer_frames", 0)), int((Sim.client.resim_stats() as Dictionary).get("count", 0)),
			carrier_in[0], carrier_in[1], carrier_in[2], carrier_out[0], carrier_out[1], carrier_out[2],
			socket[0], socket[1], socket[2], socket[3], tick_us / 1000.0, Sim.priority_sphere_words(), _near_words(),
			Sim.server.vehicle_states().size() if Sim.server != null else -1, evidence, sky_drawn, radar_said])
		if _asked("freshness") == "1":
			print(_freshness_line())
		_report_the_stats_table()
	# `--board=SECONDS`, for a harness: that long after this machine first lists another player's craft with a free seat,
	# press JOIN on it on this rig's own CREW page. See `_board_when_asked`.
	if _asked("board") != "" and not _boarded:
		_board_when_asked(float(_asked("board")))
	# `--take-kind=`, `--sweep=` and the WINGS lines of `--report`, for a harness: see `WingSweepHarness`.
	if _wing_harness == null and WingSweepHarness.wanted(_asked):
		_wing_harness = WingSweepHarness.new(self)
		add_child(_wing_harness)
	# `--arms=fire|watch`, for a harness: a jet's gun and missile on the pilot's keys, or what another machine sees of
	# them. See `JetArmsHarness`.
	if _arms_harness == null and JetArmsHarness.wanted(_asked):
		_arms_harness = JetArmsHarness.new(self)
		add_child(_arms_harness)
	# `--flash=` and `--lamps=1`, for a harness: see `SignalLampHarness`.
	if _lamp_harness == null and SignalLampHarness.wanted(_asked):
		_lamp_harness = SignalLampHarness.new(self)
		add_child(_lamp_harness)
	# `--launch=<level id>`, for a harness: press that level on the briefing room's launch board, once somebody else is
	# in the room. See `_launch_when_asked`.
	if _asked("launch") != "" and not _launched:
		_launch_when_asked(_asked("launch"))
	# `--leave-in=<level id>:SECONDS`, for a harness: that long after this machine is flying that level with somebody else,
	# press MAIN MENU twice on this rig's own board. See `_leave_when_asked`.
	if _asked("leave-in") != "" and not _left:
		_leave_when_asked(_asked("leave-in"))
	# `--press-time=<day|evening|night>`, for a harness: press that time on this rig's own TIME tab once the level is built
	# and flying. See `_press_the_time_when_asked`.
	if _asked("press-time") != "" and not _pressed_time:
		_press_the_time_when_asked(_asked("press-time"))
	# `--report-save-bandwidth`, for a harness: once flying, say whether this machine's own board offers SAVE BANDWIDTH.
	# sky_peers asks a joiner, whose board must not.
	if OS.get_cmdline_user_args().has("--report-save-bandwidth") and not _reported_save_bandwidth and rig != null 			and _built and Sim.is_ready and not _pilots.is_empty():
		var board: ClipboardPage = rig.clipboard.page()
		if board != null:
			board.show_tab(ClipboardPage.Tab.TRAFFIC)
			_reported_save_bandwidth = true
			print("SAVE_BANDWIDTH offered=%s host=%s" % [board.offers_save_bandwidth(), Net.is_host])
	# `--stack=200` presses the real TRAFFIC button after peers arrive. bulk_peers uses
	# this to prove the same page path on a socket that holding_stack holds in-process.
	if _asked("stack") != "" and not _pressed_stack:
		_press_the_stack_when_asked(int(_asked("stack")))
	# `--craft=<kind>[:seconds]` presses the real CRAFT button after another player
	# arrives. craft_peers uses it to cross page -> rig -> input -> ENet -> server.
	if _asked("craft") != "" and not _pressed_craft:
		_press_the_craft_when_asked(_asked("craft"))
	# The matching TRAFFIC automation preserves Item 18's baseline: ADD still makes an
	# unissued AI craft, and a later CRAFT request may take one of its free seats.
	if _asked("add") != "" and not _pressed_add:
		_press_add_when_asked(_asked("add"))
	# Which vehicle AND which model, because the whole point of having five models is that
	# they feel different and you should be able to tell which you are in. The same pair is
	# in the headset, on the HUD -- this line is the flat mirror of it, and is the only one
	# of the two anybody sees while debugging with the headset off.
	var flying: String = "nothing"
	if rig != null and rig.is_seated():
		var view: VehicleView = rig.vehicle_view()
		if view != null:
			var geometry: Dictionary = Sim.client.kind_geometry(view.kind)
			flying = "%s (%s) seat %d/%d" % [geometry.get("name", "?"),
				geometry.get("model_name", "?"), rig.seat_index() + 1,
				view.seats.size()]
	# THE ROTA, from the SERVER's world: `Sim.client` is the client world on a host and has no autopilots to serve. Served a
	# tick and the worst wait in ticks, which is what says the chores are keeping up -- see agents.md, "A ROTA".
	var chores: String = ""
	if Sim.server != null and Sim.server.has_method("chore_report"):
		for chore in ["look_ahead", "leg_check"]:
			var row: Dictionary = (Sim.server.chore_report().get("kinds", {}) as Dictionary).get(chore, {})
			if not row.is_empty():
				chores += " · %s %.1f/tick worst %d/%d" % [chore.get_slice("_", 0), float(row["served_per_tick"]),
					int(row["worst_interval"]), int(row["max_ticks"])]
	# THE SESSION'S NOTICE, FIRST, on the one line a monitor player reads while flying (plan item 13) -- the board carries it
	# too, but the board is up only when somebody holds it up. And printed for a harness when it changes, as drawn.
	var notice: String = Net.notice_words()
	if notice != _notice_drawn:
		_notice_drawn = notice
		if _asked("report") == "1":
			print("NOTICE_DRAWN level=%s at=%d words=%s" % [Net.level, Time.get_ticks_msec(), notice])
	_status.text = ("%s\n" % notice if notice != "" else "") + "%s · %s · flying a %s · %.0f Hz · %d vehicle(s) · %d pilot(s) · buffer %s · %.1f KB/s out · %d rollbacks%s%s" % [
		role,
		mode,
		flying,
		Sim.tick_hz,
		_views.size(),
		_pilots.size() + 1,
		timing.get("buffer_frames", "-"),
		float(status.get("bytes_out_per_second", 0.0)) / 1024.0,
		int(Sim.client.resim_stats().get("count", 0)),
		_sphere_words(),
		chores,
	]


## ---- the doors this level answers to ----------------------------------------------------

## `--level=watch`, and the two other spellings of it. Read here rather than passed in from
## the router, for the same reason the bench reads its own `--kind`: a level that can be
## opened directly in the editor has to be able to ask what it was opened for.
static func _nobody_is_playing() -> bool:
	# THE TRACE LEVEL IS WATCHED, not flown: it has one puppet and its own camera, and a pilot's pod has no place in it.
	return _asked("level") in ["watch", "observe", "nobody", "tower", "server", "dedicated",
		"control", "awacs", "tower2d"] or Net.level == TraceLevel.LEVEL_ID


## AND THE TOWER IS THE ONE OF THOSE WITH BUTTONS. Same camera and the same lack of a rig; what it adds is a panel
## that can TELL the craft under the camera to climb, to land, to fly somewhere. See `tower_panel.gd`.
static func _the_tower() -> bool:
	return _asked("level") == "tower"


## AND THE SERVER IS THE ONE OF THEM WITH NO EYE AT ALL. `watch` and `tower` still build an `Observer`, which is a
## camera that chases things; a server looks at nothing, so it gets a 2D console instead and the level ends up with no
## camera in it. Every `observer` use in this file was ALREADY null-guarded, which is why that costs nothing here.
##
## Asked for by the user, 2026-09-19: *"i want to make sure i make room to run the game as a server in 2d (just better
## for resources), or headless"*. What the room is worth in megabytes is measured in `world/server_console.gd`.
static func _the_server() -> bool:
	return _asked("level") in ["server", "dedicated"]


## AND THE CONTROLLER IS THE ONE OF THEM WITH A RADAR PLOT AND A JOB. Same lack of a rig and the same lack of a
## camera as the server, and what it adds is the first screen in this game that draws what the HOST says this machine
## can see rather than everything the client holds. See `world/control_station.gd`.
static func _the_controller() -> bool:
	return _asked("level") in ["control", "awacs", "tower2d"]


## `--kind=tank`, by name, matched against what the simulation calls its kinds. -1 for
## anything it does not recognise, which includes nothing being asked for.
static func _kind_asked_for() -> int:
	var wanted: String = _asked("kind")
	for kind in range(Sim.Kind.size()):
		if Sim.kind_name(kind) == wanted:
			return kind
	return -1


## THE CREW PAGE'S MANIFEST, as this machine would draw it. Seats off the craft's own replicated Seats.
func _manifest() -> Array:
	var seats_of: Callable = Callable()
	if Sim.client != null:
		seats_of = func(vehicle: int) -> PackedInt64Array: return Sim.client.vehicle_seats(vehicle)
	return CrewManifest.read(Sim.pilots, Sim.current, Sim.local_client_id(), Callable(), seats_of)


## The manifest as one word for a log: `pod:1.-.-.-/plane:2.3.-.-`, each craft's seats in order, the craft sorted, so it
## says the same on every machine that agrees.
func _crew_line() -> String:
	var rows: PackedStringArray = []
	for craft in _manifest():
		var seats: PackedStringArray = []
		for seat in (craft as Dictionary)["seats"]:
			seats.append("-" if int(seat["client"]) < 0 else str(int(seat["client"])))
		rows.append("%s:%s" % [String(craft["kind_name"]), ".".join(seats)])
	rows.sort()
	return "/".join(rows) if not rows.is_empty() else "none"


## Every button the server has applied from other machines' frames since the start, OR-ed. See the report.
var _buttons_seen_from_others: int = 0
## When this machine first listed another player's craft with a free seat, in msec, or -1. See `_board_when_asked`.
var _other_seen_at: int = -1
## Whether `--board` has pressed its JOIN, and whether `--launch` has pressed its level.
var _boarded: bool = false
var _launched: bool = false
## The Tomcat's wing sweep harness, when a flag asks for one. See `WingSweepHarness`.
var _wing_harness: WingSweepHarness = null
## The jets' weapons harness, when `--arms=` asks for one. See `JetArmsHarness`.
var _arms_harness: JetArmsHarness = null
## The signal lamps' harness, when a flag asks for one. See `SignalLampHarness`.
var _lamp_harness: SignalLampHarness = null
## When `--launch` first drew another player, in msec, or -1. See `_launch_when_asked`.
var _launch_seen_at: int = -1
## Whether `--press-time` has pressed its time.
var _pressed_time: bool = false
## Whether `--report-save-bandwidth` has said its line.
var _reported_save_bandwidth: bool = false
var _pressed_stack: bool = false
var _pressed_craft: bool = false
var _craft_seen_at: int = -1
var _pressed_add: bool = false
var _add_seen_at: int = -1
## Whether `--leave-in` has pressed MAIN MENU, and when it first saw somebody on its level, in msec, or -1.
var _left: bool = false
var _leave_seen_at: int = -1
## The notice the flat status line last drew. See `_status`'s rewrite.
var _notice_drawn: String = ""


## BOARD THE OTHER PLAYER'S CRAFT THROUGH THE CREW PAGE, for tests/crew_peers.gd: the real `Button` on this rig's own
## clipboard, pressed, so the join goes page -> rig -> input frame -> socket -> host exactly as a finger's does. Only
## the fingertip is left out, and tests/clipboard.gd presses the same button with the beam. It waits `after` seconds
## past first seeing the craft so a harness has seen the two machines apart before they are together.
## THE NETWORK STATISTICS TABLE, for a harness, beside SESSION_REPORT and on the same terms: one line per row, and on
## the host each row carries `host_kB_s_x10`, the host's OWN measurement of what it sent that client, so a suite can
## hold a client's self-reported arrival rate against the other end of the wire. `age_ms` and `stale` are how a lost
## card shows up -- the cards are never said again, so a row simply grows old.
##
## ONCE A SECOND AND NOT FIVE TIMES A SECOND: the rows only change that often, and a log with five copies of each is a
## log a suite has to de-duplicate before it can count anything.
var _stats_said_at: int = 0

func _report_the_stats_table() -> void:
	if net_stats == null or not is_instance_valid(net_stats):
		return
	var now := Time.get_ticks_msec()
	if now - _stats_said_at < NetStats.EVERY_MSEC:
		return
	_stats_said_at = now
	for row in net_stats.table():
		var said: PackedStringArray = []
		for column in NetStats.COLUMNS:
			said.append("%s=%d" % [column, int((row as Dictionary)[column])])
		said.append("age_ms=%d" % int((row as Dictionary)["age_msec"]))
		said.append("stale=%d" % (1 if bool((row as Dictionary)["stale"]) else 0))
		var client: int = int((row as Dictionary)["client"])
		said.append("host_kB_s_x10=%d" % int(round(float(net_stats.host_kB_s.get(client, -0.1)) * 10.0)))
		print("NETSTATS %s" % " ".join(said))


func _board_when_asked(after: float) -> void:
	if rig == null or rig.clipboard == null:
		return
	var theirs: Dictionary = {}
	for craft in _manifest():
		if not bool(craft["yours"]) and int(craft["free"]) > 0:
			theirs = craft
			break
	if theirs.is_empty():
		return
	if _other_seen_at < 0:
		_other_seen_at = Time.get_ticks_msec()
		return
	if Time.get_ticks_msec() - _other_seen_at < int(after * 1000.0):
		return
	rig.clipboard.show_board(true)
	var page: ClipboardPage = rig.clipboard.page()
	page.show_tab(ClipboardPage.Tab.CREW)
	var row: Node = page.find_child("Craft%d" % int(theirs["names"]), true, false)
	var buttons: Array = row.find_children("Join*", "Button", true, false) if row != null else []
	if buttons.is_empty():
		return
	var join := buttons[0] as Button
	_boarded = true
	print("BOARDING %s seat %s of the craft client %d is in" % [join.name, String(join.name).get_slice("_", 1),
		int(theirs["names"])])
	join.pressed.emit()


## LAUNCH THE FLIGHT FROM THE BRIEFING ROOM'S LAUNCH BOARD, for a harness: `--launch=<level id>[:SECONDS]` after the
## bare `--`, on a host standing in a room. The real `Button` the board built for that level, pressed as a press emits,
## so the launch goes board -> level -> `Net.change_level` -> the hello exactly as a mouse click does. Only the pointer
## is left out, and tests/lobby.gd presses the same button with the level's own press.
##
## IT WAITS FOR SOMEBODY ELSE. A host that launched the moment its room came up would change the level before the joiner
## had arrived, which is a different thing to test and a much easier one. So nothing happens until this machine is
## drawing another player, and then `SECONDS` longer if a number was given -- which is what a probe taking a picture of
## the room BEFORE the launch needs (tests/level_change_shot.gd). The same shape as `--board=`, which waits for the same
## reason. Nothing in the game passes this flag.
func _launch_when_asked(asked: String) -> void:
	var id: String = asked.get_slice(":", 0)
	var after: float = float(asked.get_slice(":", 1)) if asked.contains(":") else 0.0
	if room == null or room.board == null or not Net.is_host or _pilots.is_empty():
		return
	# ITS OWN CLOCK, not `--board`'s: the two flags wait for different things and a shared field is two flags one commit
	# away from disagreeing about when they first saw somebody.
	if _launch_seen_at < 0:
		_launch_seen_at = Time.get_ticks_msec()
	if Time.get_ticks_msec() - _launch_seen_at < int(after * 1000.0):
		return
	var board := room.board.shown() as ChartMenu
	if board == null or not board.level_buttons.has(id):
		return
	_launched = true
	print("LAUNCHING %s from the briefing room, with %d other player(s) in it" % [id, _pilots.size()])
	(board.level_buttons[id] as Button).pressed.emit()


## PRESS A TIME OF DAY ON THIS RIG'S OWN TIME TAB, for tests/sky_peers.gd: the real `Button`, pressed, so the choice goes
## page -> board -> `choose_time` -> `Net` exactly as a finger's does -- and on a joiner is refused there, which is what the
## suite holds. Once the level is built, the simulation up and another player drawn -- so a HOST's press is a change
## somebody is there to be told about -- and once. Prints what the board then says.
func _press_the_time_when_asked(asked: String) -> void:
	if rig == null or not _built or not Sim.is_ready or _pilots.is_empty():
		return
	var page: ClipboardPage = rig.clipboard.page()
	if page == null:
		return
	page.show_tab(ClipboardPage.Tab.TIME)
	for button in page.find_children("*", "Button", true, false):
		if (button as Button).text.to_lower() == asked:
			_pressed_time = true
			(button as Button).pressed.emit()
			print("PRESSED_TIME %s drawn=%s board=%s" % [asked, Orrery.point_name(Orrery.nearest_point(daylight.clock)).to_lower(),
				page.said_text()])
			return


## `--stack=N`, for a harness: PRESS THE REAL BUTTONS until the page says N.
##
## It used to press one button whose text was exactly the number, and when the TRAFFIC page's exact buttons changed
## from 0/50/100/200 to 0/50/200/600 on 2026-09-17, `--stack=100` stopped doing ANYTHING AT ALL -- no press, no
## message, a harness reporting `stack=0` and a suite failing somewhere else entirely. A flag that quietly does nothing
## is worse than one that refuses, so this reaches the number the way a person would -- the nearest exact button and
## then the fifties -- and says in an error which number it could not reach when it cannot.
func _press_the_stack_when_asked(wanted: int) -> void:
	if rig == null or not _built or not Sim.is_ready or _pilots.is_empty():
		return
	var page: ClipboardPage = rig.clipboard.page()
	if page == null:
		return
	page.show_tab(ClipboardPage.Tab.TRAFFIC)
	var buttons: Array[Button] = []
	for button in page.find_children("*", "Button", true, false):
		buttons.append(button as Button)
	# THE EXACT BUTTON IF THERE IS ONE, AND IT IS PRESSED EVEN WHEN THE STACK IS ALREADY THAT SIZE.
	#
	# A version of this returned early when `load_count()` already equalled the number, which looks like a sensible
	# saving and is not: `--stack=0` on a JOINER is how `bulk_peers` proves that a joiner's press is refused in words,
	# and a joiner's stack is already 0, so the press it was checking for never happened. The flag means "press this
	# button", not "arrange for the count to be this number" -- and the one thing a harness flag must never do is
	# quietly skip the press it exists to make.
	for button in buttons:
		if button.text == str(wanted):
			_pressed_stack = true
			button.pressed.emit()
			print("PRESSED_STACK %d page=%d board=%s" % [wanted, page.load_count(), page.said_text()])
			return
	# OR THE COUNT IS ALREADY THERE, reached by the steps below on an earlier tick.
	if page.load_count() == wanted:
		_pressed_stack = true
		print("PRESSED_STACK %d page=%d board=%s" % [wanted, page.load_count(), page.said_text()])
		return
	# OR THE LARGEST EXACT BUTTON THAT DOES NOT OVERSHOOT, once, and then the steps.
	var digits := RegEx.create_from_string("^[0-9]+$")
	var best := -1
	var best_button: Button = null
	for button in buttons:
		if digits.search(button.text) == null:
			continue
		var value := int(button.text)
		if value <= wanted and value > best:
			best = value
			best_button = button
	var step_size := 0
	for button in buttons:
		if button.text.begins_with("+") and digits.search(button.text.substr(1)) != null:
			step_size = int(button.text.substr(1))
	if step_size <= 0 or best_button == null or (wanted - best) % step_size != 0:
		push_error("[sky] --stack=%d cannot be reached from the TRAFFIC page's buttons in steps of %d" % [
			wanted, step_size])
		_pressed_stack = true
		return
	if page.load_count() < best:
		best_button.pressed.emit()
		return
	# AND THEN A FIFTY AT A TIME, one a status tick, until the page says the number.
	var toward: String = "+%d" % step_size if page.load_count() < wanted else "-%d" % step_size
	for button in buttons:
		if button.text == toward:
			button.pressed.emit()
			return


func _press_the_craft_when_asked(asked: String) -> void:
	if rig == null or not _built or not Sim.is_ready or _pilots.is_empty():
		return
	if _craft_seen_at < 0:
		_craft_seen_at = Time.get_ticks_msec()
		return
	var after: float = float(asked.get_slice(":", 1)) if asked.contains(":") else 0.0
	if Time.get_ticks_msec() - _craft_seen_at < int(after * 1000.0):
		return
	var wanted: String = asked.get_slice(":", 0).to_lower()
	var page: ClipboardPage = rig.clipboard.page()
	if page == null:
		return
	page.show_tab(ClipboardPage.Tab.CRAFT)
	for button in page.find_children("*", "Button", true, false):
		if (button as Button).text.to_lower() == wanted:
			_pressed_craft = true
			(button as Button).pressed.emit()
			print("PRESSED_CRAFT %s" % wanted)
			return


func _press_add_when_asked(asked: String) -> void:
	if rig == null or not _built or not Sim.is_ready or _pilots.is_empty():
		return
	if _add_seen_at < 0:
		_add_seen_at = Time.get_ticks_msec()
		return
	var after: float = float(asked.get_slice(":", 1)) if asked.contains(":") else 0.0
	if Time.get_ticks_msec() - _add_seen_at < int(after * 1000.0):
		return
	var wanted: String = asked.get_slice(":", 0).to_lower()
	var page: ClipboardPage = rig.clipboard.page()
	if page == null:
		return
	page.show_tab(ClipboardPage.Tab.TRAFFIC)
	for button in page.find_children("*", "Button", true, false):
		if (button as Button).text.to_lower() == "+ " + wanted:
			_pressed_add = true
			(button as Button).pressed.emit()
			print("PRESSED_ADD %s" % wanted)
			return


## LEAVE THROUGH MAIN MENU, for tests/notices.gd: the real guarded button on this rig's own board, pressed twice, so the
## session ends the way a player ends it and the host hears a peer go rather than a socket time out.
func _leave_when_asked(asked: String) -> void:
	if rig == null or not _built or level == null or level.id != asked.get_slice(":", 0) or _pilots.is_empty():
		return
	if _leave_seen_at < 0:
		_leave_seen_at = Time.get_ticks_msec()
	if Time.get_ticks_msec() - _leave_seen_at < int(float(asked.get_slice(":", 1)) * 1000.0):
		return
	var page: ClipboardPage = rig.clipboard.page()
	for button in page.find_children("*", "Button", true, false):
		if not button is GuardedButton:
			continue
		_left = true
		print("LEAVING through MAIN MENU on %s" % level.id)
		(button as Button).pressed.emit()
		(button as Button).pressed.emit()
		return


static func _carrier_total(table: Dictionary) -> Array[int]:
	var total: Array[int] = [0, 0, 0]
	for value in table.values():
		var row: Array = value
		total[0] += int(row[0])
		total[1] += int(row[1])
		total[2] = maxi(total[2], int(row[2]))
	return total


## Official ENetConnection.host statistics are window counters: pop_statistic returns
## and resets them. Reporting every status interval lets bulk_peers sum real UDP bytes
## and packets without reaching into ENet internals. Godot exposes no socket-packet
## maximum or MTU property, so rx_largest above remains the carrier's exact maximum.
func _enet_window() -> Array[int]:
	if not multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		return [0, 0, 0, 0]
	var connection: ENetConnection = (multiplayer.multiplayer_peer as ENetMultiplayerPeer).host
	if connection == null:
		return [0, 0, 0, 0]
	return [
		int(connection.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_PACKETS)),
		int(connection.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)),
		int(connection.pop_statistic(ENetConnection.HOST_TOTAL_SENT_PACKETS)),
		int(connection.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)),
	]


static func _asked(name: String) -> String:
	for argument in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.lstrip("-").split("=")
		if parts.size() == 2 and parts[0].to_lower() == name:
			return parts[1].to_lower()
	return ""

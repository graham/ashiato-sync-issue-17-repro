extends Node3D
class_name VehicleSound
## WHAT A CRAFT SOUNDS LIKE, generated a sample at a time, with no audio files anywhere.
##
## This project shipped a flight simulator with **no sound of any kind** -- not a stub, not
## a bus layout, not a placeholder, zero `AudioStreamPlayer` in eighty-two scripts. That is
## not a polish item, it is a missing instrument. An engine note is how a pilot holds a
## power setting without looking at anything; wind noise is how they feel speed with their
## eyes on the horizon; and a gun with no report does not read as a gun.
##
## ---------------------------------------------------------------------------------
## PROCEDURAL, WHICH IS THE SAME BUDGET EVERY SURFACE IN THIS GAME IS DRAWN ON
## ---------------------------------------------------------------------------------
##
## There are no textures in this project and there are no audio files either, for related
## reasons: a headset is fill-rate bound and a mobile build is memory bound, and a handful
## of multiply-adds costs neither. An `AudioStreamGenerator` is the audio equivalent of the
## rock shader -- a few operations a sample, no file, no import step, no loading, and every
## craft a different animal from one table.
##
## ONE PLAYER PER CRAFT AND NOT TWO. The engine and the wind are summed into a single
## generator, because they come from the same place: two players would mean two buffers to
## keep fed, two 3D attenuations computed for one aeroplane, and a pan that could disagree
## with itself. The gun is the exception and is separate, because it is a MOMENT and the
## rest is a level -- the same split the command bus and `CraftCue` already draw.
##
## ---------------------------------------------------------------------------------
## THE MAPPING IS A PURE FUNCTION AND THE SYNTHESIS IS NOT
## ---------------------------------------------------------------------------------
##
## `tone_for` takes three numbers and returns three numbers, which is the whole of what
## decides how a craft sounds. It is static, it touches nothing, and a headless suite can
## walk it across the range and assert that pitch rises with power, that the wind rises with
## speed, that nothing leaves 0..1 and that a shut throttle standing still is nearly silent.
## What it deliberately cannot say is whether any of that sounds like an aeroplane, which is
## a question for a pair of ears and is written down as such.
##
## AND IT IS SILENT WHERE THERE IS NOBODY TO HEAR IT. Headless has no audio device, so no
## players are built at all -- not built and muted, not built and stopped. Twenty-one suites
## run in this project and none of them should be filling a ring buffer.
##
## WHERE THERE IS A DEVICE, THE PLAYERS ARE BUILT AND THE GAME BUS DECIDES. Every player here
## goes on `PilotHeadphones.GAME_BUS`, which the clipboard's GAME SOUND switch mutes, and which
## starts muted unless `--audio` was given. Until 2026-09-13 `--audio` decided whether players
## were BUILT, which is fine for a flag and wrong for a switch: a craft somebody sat in with the
## sound off had no player to unmute when the switch went on.
##
## ---------------------------------------------------------------------------------
## WHAT IS NOT HERE
## ---------------------------------------------------------------------------------
##
## **One report per ROUND.** `ShotState` is a birth record and it does not say who fired it,
## so this machine cannot tell its own cannon from a gunship's four kilometres away. What it
## can do is put a crack at the MUZZLE of every round it is drawn, which is where the sound
## comes from anyway -- see `report`. A per-gun rattle wants a shooter field on the wire.
##
## **No stall buffet, no rotor slap, no tyre roar, no touchdown.** Each is another layer on
## the same generator and another row in the table; none of them is a new mechanism.
##
## **No Doppler.** `AudioStreamPlayer3D` has `doppler_tracking`, and turning it on wants the
## velocity Godot can see -- which for a node moved by `Sim.vehicle_transform` every frame is
## a node that teleports, not one that travels. It would need the simulation's own velocity
## handing in, which is a small job and not this one.

## ---------------------------------------------------------------------------------
## THE NUMBERS
## ---------------------------------------------------------------------------------

## HOW MANY SAMPLES A SECOND ARE GENERATED. Half CD rate, deliberately: an engine note is a
## few harmonics under 400 Hz and a wind rush is filtered noise, so there is nothing up
## there to lose -- and at the display rate this is a loop that runs per craft per frame.
const MIX_HZ: float = 22050.0
## How much sound is kept ahead of the device, in seconds. Long enough that a frame that
## takes twice as long as usual does not run the buffer dry and click; short enough that a
## throttle change is heard when it happens rather than a moment later.
const BUFFER_SECONDS: float = 0.12

## EVERYTHING IS SCALED BY THIS ON THE WAY OUT. One knob for "the whole game is too loud",
## which is the note that always comes back from a first session in a headset. Low on
## purpose: the first thing anybody does with a new sound layer is make it twice as loud as
## it should be, and in a headset that is not a preference, it is a headache.
const MASTER: float = 0.22

## THE NOTE A CRAFT IDLES AT, DERIVED FROM ITS MASS rather than typed into a table per kind.
##
## A bigger machine has a bigger engine and a lower note: a power of the mass, so every
## doubling of the weight lowers the note by the same interval, pinned at the light aeroplane
## (780 kg, 100 Hz) at one end and at the HEAVIEST CRAFT IN THE SHAPE TABLE, which sounds
## `MIN_HZ`, at the other (`_note_power`). So nothing lighter than the heaviest craft reaches
## the floor, and a heavier craft always has a lower note.
##
## It was the cube root, "double the linear size is half the frequency", and that reached
## the 22 Hz floor at 73 t. Once lane/liners made the 747 280 t and the 737 62 t (2026-09-19)
## the 747, the train, the pirate ship, the tower and every warship sounded one identical
## note on the floor, and the 737 the same 23.3 Hz as the tank. Over the table as it stands
## (85 kg to the carrier's 10,000 t) the power is about 0.16: the segway sits near 142 Hz,
## the 737 and the tank near 50, the 747 near 39. One table rather than two, which is the
## same rule the drawn geometry follows: a constant here and a matching constant in the C++
## agree until one of them changes.
const REFERENCE_MASS: float = 780.0
const REFERENCE_HZ: float = 100.0
## And a floor and a ceiling: under about 22 Hz is not a note, it is a vibration nothing
## can reproduce. The floor is where the heaviest craft lands; the clamp only guards a kind
## the table did not have when the power was worked out.
const MIN_HZ: float = 22.0
const MAX_HZ: float = 240.0
## THE POWER OF THE MASS THE NOTE FALLS BY, worked out once from the shape table. Zero until
## asked. The cube root stands in only where there is no table to ask (no extension loaded).
static var _power: float = 0.0

## WHAT A SHUT THROTTLE SOUNDS LIKE. An idling engine is not a silent engine -- it is a
## lower, quieter version of the same one -- so both the pitch and the level have a floor
## rather than going to zero, and a craft with the power off still tells you it is running.
const IDLE_PITCH: float = 0.55
const IDLE_LEVEL: float = 0.22

## THE AIRSPEED AT WHICH THE WIND IS AS LOUD AS IT GETS, in m/s. The fast aeroplane tops out
## near 165, so full roar arrives a little before anything can actually get there.
const WIND_FULL: float = 150.0
## And how loud that is against the engine. Under half, because an aeroplane with the wind
## louder than the engine is an aeroplane with the engine off.
const WIND_LEVEL: float = 0.45

## HOW LOUD A ROUND IS AT THE MUZZLE, and how long the crack lasts in seconds.
const REPORT_LEVEL: float = 0.55
const REPORT_SECONDS: float = 0.22

## HOW FAR A CRAFT CAN BE HEARD, in metres, and the distance at which it is at full volume.
## Generous: the point of hearing another aeroplane is finding it, and this is a game about
## a sky you cannot see anything in.
const HEARD_WITHIN: float = 900.0
const CLOSE_ENOUGH: float = 12.0

## CRAFT WITH NOTHING RUNNING.
##
## A glider is an aeroplane with the thrust set to zero -- one number in the simulation's
## handling table, which is not published to this side of the line -- and a control tower is
## a building. Both still carry a throttle channel on the bus, so `craft_schema` cannot be
## asked; `Model::Fixed` answers for the tower and the glider is named. The moment the
## handling table reaches GDScript, this becomes "thrust is zero" and the list goes.
const ENGINELESS: Array[int] = [Sim.Kind.GLIDER]


## ---------------------------------------------------------------------------------
## THE MAPPING, WHICH IS PURE AND IS THE PART WORTH TESTING
## ---------------------------------------------------------------------------------

## WHAT A CRAFT SOUNDS LIKE RIGHT NOW: a pitch in hertz and two levels in 0..1.
##
## Three numbers in, three out, and no state anywhere -- so it can be walked across its whole
## range by a suite with no world, no session and no audio device.
##
## The pitch rises with power and so does the level, which is the one thing an engine note
## has to do: a pilot holds a cruise setting by ear, and a note that only got LOUDER would
## be a throttle with no feel at all. The wind is the SQUARE of airspeed because it is the
## same term the drag is -- a rush that grew linearly would be as loud taxiing as it is at
## half speed, and nothing about an aeroplane feels like that.
static func tone_for(base_hz: float, throttle: float, airspeed: float) -> Dictionary:
	var open: float = clampf(throttle, 0.0, 1.0)
	var fast: float = clampf(absf(airspeed) / WIND_FULL, 0.0, 1.0)
	return {
		"hz": base_hz * (IDLE_PITCH + (1.0 - IDLE_PITCH) * open),
		"engine": IDLE_LEVEL + (1.0 - IDLE_LEVEL) * open,
		"wind": fast * fast * WIND_LEVEL,
	}


## THE NOTE THIS KIND IDLES AT, asked of the simulation's own shape table. See the note on
## REFERENCE_MASS: it is the mass that decides, and the mass lives in one place.
static func base_note(kind: int) -> float:
	var mass: float = float(Sim.geometry_of(kind).get("mass", REFERENCE_MASS))
	return clampf(REFERENCE_HZ * pow(REFERENCE_MASS / maxf(mass, 1.0), _note_power()),
		MIN_HZ, MAX_HZ)


## THE POWER THAT BRINGS THE HEAVIEST CRAFT IN THE SHAPE TABLE DOWN TO `MIN_HZ` from the
## reference aeroplane's `REFERENCE_HZ`. See the note on REFERENCE_MASS.
static func _note_power() -> float:
	if _power > 0.0:
		return _power
	var heaviest: float = 0.0
	for kind in Sim.Kind.values():
		heaviest = maxf(heaviest, float(Sim.geometry_of(kind).get("mass", 0.0)))
	if heaviest <= REFERENCE_MASS:
		return 1.0 / 3.0
	_power = log(REFERENCE_HZ / MIN_HZ) / log(heaviest / REFERENCE_MASS)
	return _power


## Whether this kind has anything running at all. See ENGINELESS.
static func has_an_engine(kind: int) -> bool:
	if kind in ENGINELESS:
		return false
	return int(Sim.geometry_of(kind).get("model", Sim.Model.HOVER)) != Sim.Model.FIXED


## THE FLAG THAT STARTS SOUND ON. It is the headphones' now -- `--audio` says where the GAME
## SOUND switch starts -- and is read here under its old name for what already asks for it.
const AUDIO_FLAG: String = PilotHeadphones.AUDIO_FLAG


## Was sound asked for on this command line? See `PilotHeadphones.asked_for`.
static func asked_for(args: PackedStringArray) -> bool:
	return PilotHeadphones.asked_for(args)


## IS THERE ANYWHERE FOR THIS TO BE HEARD. False headless, where there is no audio device at all
## and a generator would be a ring buffer filled for nobody, in twenty-one suites. Everywhere
## else the players are built, and whether they are HEARD is the game bus's mute -- see the
## header, and `PilotHeadphones`.
static func audible() -> bool:
	return DisplayServer.get_name() != "headless"


## ---------------------------------------------------------------------------------
## THE CRAFT
## ---------------------------------------------------------------------------------

var kind: int = -1
## The note this craft idles at, worked out once when it is built rather than per frame.
var _base_hz: float = REFERENCE_HZ
var _engine_on: bool = true
var _player: AudioStreamPlayer3D = null
var _playback: AudioStreamGeneratorPlayback = null
## Where the sawtooth has got to, in cycles. Kept across frames, or every buffer would start
## at zero and the note would click at the frame rate.
var _phase: float = 0.0
## The one-pole low pass the wind noise runs through, and its last output.
var _rush: float = 0.0
var _tone: Dictionary = {"hz": REFERENCE_HZ, "engine": IDLE_LEVEL, "wind": 0.0}
## What was actually generated last frame, so the tone can be eased onto rather than
## stepped. A throttle that moved a tenth in one frame would otherwise click.
var _heard_hz: float = REFERENCE_HZ
var _heard_engine: float = 0.0
var _heard_wind: float = 0.0
## HOW FAST A LEVEL IS ALLOWED TO MOVE, in full range per second. A quarter of a second from
## silence to full, which is quick enough to follow a throttle and slow enough that the step
## between two buffers is never a click.
const SLEW: float = 4.0


## BUILD IT FOR A KIND. Nothing is created at all where nothing can be heard.
func setup(for_kind: int) -> void:
	kind = for_kind
	_base_hz = base_note(kind)
	_heard_hz = _base_hz
	_engine_on = has_an_engine(kind)
	if not audible():
		return
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_HZ
	generator.buffer_length = BUFFER_SECONDS
	_player = AudioStreamPlayer3D.new()
	_player.name = "Note"
	_player.stream = generator
	_player.unit_size = CLOSE_ENOUGH
	_player.max_distance = HEARD_WITHIN
	# LINEAR, not the inverse-square default. An aeroplane a kilometre off is a thing you
	# are meant to be able to hear yourself towards, and inverse square puts it thirty
	# decibels down -- which is the same "a box the size of an aeroplane is invisible at two
	# kilometres" problem the spotting boxes exist for, in the other sense.
	_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_player.bus = PilotHeadphones.GAME_BUS
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


## WHAT THE CRAFT IS DOING, handed in once a frame by whoever is drawing it.
##
## It does not ask. `VehicleView` already has the interpolated state in its hand and a
## second reader would be a second answer -- the same rule that stopped the renderer
## rebuilding the world every frame to find out what to draw.
func set_tone(throttle: float, airspeed: float) -> void:
	_tone = tone_for(_base_hz, throttle if _engine_on else 0.0, airspeed)
	if not _engine_on:
		_tone["engine"] = 0.0


func _process(delta: float) -> void:
	if _playback == null:
		return
	# EASED ONTO, NOT STEPPED. See SLEW.
	var step: float = SLEW * delta
	_heard_engine = move_toward(_heard_engine, float(_tone["engine"]), step)
	_heard_wind = move_toward(_heard_wind, float(_tone["wind"]), step)
	# The pitch slews with the level rather than on its own clock, in the same proportion,
	# so opening the throttle is one event and not two.
	_heard_hz = move_toward(_heard_hz, float(_tone["hz"]), maxf(_base_hz, 1.0) * step)
	_fill(_playback.get_frames_available())


## GENERATE. A sawtooth and its slightly detuned octave for the engine, filtered noise for
## the wind, summed and pushed.
##
## The octave is detuned by one per cent ON PURPOSE. Two harmonics locked in phase are one
## harmonic with a different shape; a hundredth of a cent of drift is what makes a machine
## sound like it has two things turning in it rather than one oscillator.
func _fill(frames: int) -> void:
	if frames <= 0:
		return
	var step: float = _heard_hz / MIX_HZ
	for i in range(frames):
		_phase = fposmod(_phase + step, 1.0)
		var saw: float = _phase * 2.0 - 1.0
		var octave: float = fposmod(_phase * 2.01, 1.0) * 2.0 - 1.0
		var engine: float = (saw * 0.62 + octave * 0.26) * _heard_engine
		# A ONE-POLE LOW PASS over white noise. A wind rush is not hiss: the high end of
		# white noise is a hi-hat, and in a headset it is the first thing that becomes
		# unbearable.
		_rush = _rush * 0.86 + randf_range(-1.0, 1.0) * 0.14
		var value: float = clampf((engine + _rush * 4.0 * _heard_wind) * MASTER, -1.0, 1.0)
		_playback.push_frame(Vector2(value, value))


## ---------------------------------------------------------------------------------
## THE GUN, WHICH IS A MOMENT
## ---------------------------------------------------------------------------------

## A ROUND LEAVING A BARREL, AT THE BARREL.
##
## A one-shot rather than a layer on the generator above, and that is a decision rather than
## a shortcut: feeding a hundred and fifty milliseconds of crack into a ring buffer means
## per-frame bookkeeping for every round in the air, and a 25 mm cannon puts thirty a second
## up. A sample built once and played is the right tool for a thing that happens and stops.
##
## Built in code, so it is still no asset: a burst of noise under a decaying envelope, which
## is what a gun report physically IS -- a pressure step and a tail.
##
## AT THE MUZZLE AND NOT AT THE CRAFT, because the muzzle is where the record says the round
## left from and the craft's own position is a metre or ten away from it. It is also the
## only thing this machine knows about who fired: see WHAT IS NOT HERE.
static func report(into: Node, at: Vector3, calibre: float = 1.0) -> void:
	if not audible() or into == null or not into.is_inside_tree():
		return
	var crack := AudioStreamPlayer3D.new()
	crack.stream = _a_crack(calibre)
	crack.unit_size = CLOSE_ENOUGH * 4.0
	crack.max_distance = HEARD_WITHIN * 3.0
	crack.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	crack.bus = PilotHeadphones.GAME_BUS
	into.add_child(crack)
	crack.global_position = at
	crack.finished.connect(crack.queue_free)
	crack.play()


## The sample itself, one per calibre, built once and kept. A tank and a machine gun are the
## same arithmetic with a different decay: a big gun is a longer tail, not a louder hiss.
static var _cracks: Dictionary = {}


static func _a_crack(calibre: float) -> AudioStreamWAV:
	var key: int = int(roundf(clampf(calibre, 0.25, 4.0) * 4.0))
	if _cracks.has(key):
		return _cracks[key]
	var weight: float = float(key) * 0.25
	var length: int = int(MIX_HZ * REPORT_SECONDS * weight)
	var data := PackedByteArray()
	data.resize(length * 2)
	# A ONE-POLE LOW PASS AGAIN, opened up by the calibre: a big gun is mostly a thump and a
	# small one is mostly a crack, and the only difference in the arithmetic is how much of
	# the top is left in.
	var pole: float = clampf(0.72 - weight * 0.10, 0.20, 0.90)
	var filtered: float = 0.0
	for i in range(length):
		var through: float = float(i) / float(maxi(length, 1))
		# A SHARP ATTACK AND AN EXPONENTIAL TAIL. A linear fade reads as a whoosh; what a
		# gun does is arrive all at once and go away over a while.
		var envelope: float = exp(-through * 6.0) * minf(through * 60.0, 1.0)
		filtered = filtered * pole + randf_range(-1.0, 1.0) * (1.0 - pole)
		var value: int = int(clampf(filtered * envelope * REPORT_LEVEL, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, value)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(MIX_HZ)
	wav.stereo = false
	wav.data = data
	_cracks[key] = wav
	return wav

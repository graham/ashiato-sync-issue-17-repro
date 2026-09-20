extends RefCounted
class_name RadioTuning
## THE NUMBERS AND NAMES THE RADIO IS TUNED BY: who speaks in which voice, how often the frequency talks
## when nobody asked, and how hard the voice may work the processor.
##
## "Have the planes and tower occasionally (once per 15 seconds) use a different voice to make some sort of
## radio transmission" (2026-09-13). What is SAID is `RadioPhrases`; who is on the frequency is the sky's
## traffic (`TowerFrequency`); whether anything is said at all is `Headphones`. This file is what a person
## changes to make it sound different.

## ---- voices ----------------------------------------------------------------------------------

## THE TOWER, in one voice, and the only voice the tower has: the radio check and every tower line of chatter.
## `PilotHeadphones.TOWER_VOICE` is this.
const TOWER_VOICE: String = "bm_george"

## THE AIRCRAFT, each in one of these, picked by its entity so a given aircraft always sounds the same
## (`voice_for`). Never the tower's. English voices only -- voices.bin's other languages read English words
## with their own phonemes: am_ and bm_ are American and British men, af_ and bf_ women.
const PLANE_VOICES: Array[String] = ["am_michael", "bf_emma", "bm_lewis", "af_bella", "am_adam", "af_sarah"]

## HOW FAST A LINE IS READ. kokoro's own default is 1.3, which is what the radio check is read at and what
## its 2.72 s was measured at. Chatter is read a little quicker, because a busy frequency is quick.
const CHECK_SPEED: float = 1.3
const CHATTER_SPEED: float = 1.5


## THE VOICE AN AIRCRAFT SPEAKS IN: the same entity is the same voice for as long as it exists.
##
## OFF A HASH OF THE WHOLE ID, NOT A REMAINDER OF IT. An ashiato entity id is `(version << 32) | index`
## (`ashiato/include/ashiato/ashiato.hpp`, where a slot's id is built), so `posmod(id, 6)` is the slot's remainder
## plus a term from the generation: neighbouring slots walk through the pool in order, and a machine respawned in
## a slot lands on a voice fixed by that walk rather than one of its own. The hash takes every bit, generation
## included, so a respawn is a new aircraft with its own voice and neighbours are a scatter (asked for by the
## team lead, 2026-09-14). GDScript's `hash` of an int is the same on every run and every machine.
static func voice_for(entity: int) -> String:
	return PLANE_VOICES[entity_marks(entity) % PLANE_VOICES.size()]


## A SMALL NUMBER THAT IS THE SAME FOR THE SAME ENTITY, off every bit of its id. What a voice and a callsign
## are picked with, so the two never disagree about which aircraft is which.
static func entity_marks(entity: int) -> int:
	return hash(entity) & 0x7FFFFFFF


## ---- callsigns -------------------------------------------------------------------------------

## THE WORD AN AIRCRAFT IS CALLED BY, where its kind's own name is not one a radio would use or not a word the
## voice knows. Every other kind is called by its name: Airliner, Osprey, Chinook, Cessna, Gunship, Tanker,
## Glider. "plane" is every aircraft, and "heli" is not in the lexicon, so it would be guessed at.
const CALLSIGNS: Dictionary = {
	Sim.Kind.PLANE: "Viper",
	Sim.Kind.HELI: "Rescue",
}


## ---- who is on the frequency ------------------------------------------------------------------

## THE MOVEMENT MODELS THAT FLY, as the simulation names them (`Sim.geometry_of(kind)["model_name"]`). Asked
## of the simulation per kind, so a new aircraft is on the radio without a line here.
const FLYING_MODELS: Array[String] = ["airplane", "helicopter", "tiltrotor"]
## Slower than this and it is on the ground, or hovering where it was parked, and has nothing to report. m/s.
const FLYING_SPEED: float = 15.0
## HOW FAR FROM THE LISTENER AN AIRCRAFT MAY BE AND STILL BE ON THE FREQUENCY, in metres. Callsigns on a tower's
## frequency are the aircraft round the field, and the island is ten kilometres across, so fifteen is everything
## a pilot over it could plausibly hear and nothing out past the ships. Past it, only the tower talks.
const RADIO_RANGE: float = 15000.0


## ---- how often ------------------------------------------------------------------------------

## ONE LINE EVERY INTERVAL, give or take JITTER, in WALL seconds. Wall, not frames: the voice is synthesised
## and played in real time, so a frequency that ran on the frame clock would talk four times as often in a
## suite run at `--fixed-fps` and not at all in a hitch. A test shortens it on the node (`TowerFrequency.interval`).
const INTERVAL: float = 15.0
const JITTER: float = 2.0


## ---- how a line is read -----------------------------------------------------------------------

## Above this, an altitude is a flight level; below it, feet. The UK's transition altitude over most of the
## country, and a round one.
const TRANSITION_FEET: float = 6000.0
## Altitudes below the transition are read to the nearest of these, which is how a pilot passing one reads it.
const ALTITUDE_STEP_FEET: float = 500.0

## THE LONGEST A LINE MAY BE, in spoken words at its longest filling (`RadioPhrases.problem`), and in seconds
## as the voice actually read it (tests/chatter.gd). About four seconds: a frequency that holds one aircraft for
## longer is a frequency nobody else can use.
const MOST_WORDS: int = 10
const MOST_SECONDS: float = 4.0


## ---- when the frequency is free ------------------------------------------------------------------

## HOW LONG A LINE MAY BE OUT before the frequency stops waiting for kokoro to say it finished, in wall seconds.
## kokoro reports a failure with `synthesis_failed`; this is for a line that is neither finished nor failed, as a
## stopped player would leave it. Well past the longest line (`MOST_SECONDS`) and the slowest synthesis of one.
const GIVE_UP: float = 10.0


## ---- the processor --------------------------------------------------------------------------

## ONNX Runtime's threads for one line of speech (`KokoroServer.worker_threads`, read when the model loads).
##
## TWO, NOT KOKORO'S FOUR, AND NOT ONE. Measured windowed on the double editor, a line every 8 s, each thread count
## against the VOICE-off runs beside it (tests/radio_shot.gd, 2026-09-14). The machine was shared with other lanes'
## builds and windowed probes, so only pairs whose load held are counted:
## - 2 threads: median +0.9 ms, and within 1.5 s of a line p99 +4.7 ms, worst 28.4 ms, below both brackets' worst.
## - 4 threads: median -0.3 ms, near a line p99 +5.0 ms, worst 35 ms, level with VOICE off.
## - 1 thread: median +0.5 ms, near a line p99 +6.6 ms, and a worst of 41 ms against VOICE off's 32. Synthesis also
##   waited up to 1.6 s before a line went on air, against 0.35 to 1.2 s at two.
## No setting was separable from another beyond the noise. So this is the one that takes half the cores four does from
## a renderer that already spends the whole frame (most frames are over 11.1 ms with VOICE off, windowed), at no
## measured cost, and still synthesises well ahead of playback: kokoro-gd's DESIGN.md has fp32 at 2.49x real time
## on two threads. An earlier ladder on the stock editor recommended one thread for its worst frame; that was not
## reproduced here. See agents.md, "THE VOICE HOLDS NO FRAME".
const WORKER_THREADS: int = 2

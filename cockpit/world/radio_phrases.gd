extends RefCounted
class_name RadioPhrases
## WHAT IS SAID ON THE TOWER'S FREQUENCY WHEN NOBODY ASKED: one line per phrase, filled from the sky.
##
## "For voice, if it's available, just have the planes and tower occasionally (once per 15 seconds) use a
## different voice to make some sort of radio transmission" (2026-09-13). A voice reading made-up words is
## a voice nobody listens to twice, so every phrase here is one a real frequency carries, and every number
## in it is read off the craft that says it: its own altitude, its own heading, the world's first runway.
##
## A CATALOGUE, NOT A FOLDER. The house table (building_a_game_here.md) puts "a catalogue the code reads" in
## a `const` in a `RefCounted`, and a phrase is a line of text that nothing else ships with -- no icon, no
## script -- so a folder per phrase would be a folder per sentence. What the folder rule buys, a broken item
## disabling itself with a message, is kept: `problem` checks one entry, and `usable` leaves out any entry
## it has a problem with and prints why.
##
## THE SLOTS, and nothing else may appear in braces:
##
##   callsign        the craft speaking or spoken to: "Airliner 27", read "airliner two seven"
##   altitude        its own height above the sea, in words: "two thousand five hundred feet", or
##                   "flight level 070" at and above `RadioTuning.TRANSITION_FEET`
##   heading         its own compass heading to the nearest ten degrees, three digits: "270"
##   runway          the world's first runway, from `Terrain.runways()[0]`'s bearing: "36" on the island
##   carrier         the carrier's bearing from the craft, three digits. A phrase with this slot is not
##                   said while there is no carrier in the sky.
##   carrier_miles   how far away the carrier is, in words: "six miles"
##
## DIGITS ARE LEFT AS DIGITS on purpose. kokoro reads them one at a time, the radio way ("two seven zero",
## "tree", "niner"), and doing that here as well would be the same rule in two places. An altitude is the
## one number the reader cannot tell from a heading, so it is composed in words, as kokoro's README says to.
##
##   id       what the entry is called in a message
##   speaker  `&"plane"` or `&"tower"`
##   text     the line, with slots
##   reply    the id the OTHER side answers with in the next slot, or `&""` for a line nobody answers

const PHRASES: Array[Dictionary] = [
	# ---- an aircraft calls, and the tower answers ------------------------------------------------
	{"id": &"passing", "speaker": &"plane", "text": "Tower, {callsign}, passing {altitude}.",
		"reply": &"roger_passing"},
	{"id": &"roger_passing", "speaker": &"tower", "text": "{callsign}, roger, report leaving the zone.",
		"reply": &"wilco"},
	{"id": &"heading", "speaker": &"plane", "text": "Tower, {callsign}, heading {heading}.",
		"reply": &"roger_heading"},
	{"id": &"roger_heading", "speaker": &"tower", "text": "{callsign}, roger, maintain {altitude}.",
		"reply": &"wilco"},
	{"id": &"approach", "speaker": &"plane", "text": "Tower, {callsign}, request visual approach.",
		"reply": &"cleared_approach"},
	{"id": &"cleared_approach", "speaker": &"tower", "text": "{callsign}, cleared visual, runway {runway}.",
		"reply": &"wilco"},
	{"id": &"carrier_sighted", "speaker": &"plane", "text": "Tower, {callsign}, carrier in sight.",
		"reply": &"carrier_where"},
	{"id": &"carrier_where", "speaker": &"tower", "text": "{callsign}, carrier bearing {carrier}, {carrier_miles}.",
		"reply": &""},
	# ---- the tower asks, and the aircraft answers --------------------------------------------------
	{"id": &"say_altitude", "speaker": &"tower", "text": "{callsign}, tower, say altitude.",
		"reply": &"altitude_is"},
	{"id": &"altitude_is", "speaker": &"plane", "text": "{callsign}, {altitude}.", "reply": &""},
	{"id": &"radio_check", "speaker": &"tower", "text": "{callsign}, tower, radio check.",
		"reply": &"five_by_five"},
	{"id": &"five_by_five", "speaker": &"plane", "text": "Tower, {callsign}, five by five.", "reply": &""},
	# ---- and the one every exchange can end with ---------------------------------------------------
	{"id": &"wilco", "speaker": &"plane", "text": "Wilco, {callsign}.", "reply": &""},
	# ---- the tower alone, to everybody: no aircraft in it, so it can be said with none in range -----------
	{"id": &"runway_in_use", "speaker": &"tower", "text": "All stations, tower, runway {runway} in use.",
		"reply": &""},
	{"id": &"departures_and_arrivals", "speaker": &"tower",
		"text": "All stations, tower, departures and arrivals runway {runway}.", "reply": &""},
]

const SPEAKERS: Array[StringName] = [&"plane", &"tower"]
## THE LONGEST EACH SLOT CAN READ, in spoken words, so `problem` can count a line at its worst. A callsign is a
## word and two digits; an altitude is at most "five thousand five hundred feet" below the transition and
## "flight level" and three digits above it; a heading or bearing is three digits, a runway two, and a distance
## "seventeen miles".
const WORST_WORDS: Dictionary = {"callsign": 3, "altitude": 5, "heading": 3, "runway": 2, "carrier": 3,
	"carrier_miles": 2}

const FEET_PER_METRE: float = 3.28084
const METRES_PER_MILE: float = 1852.0
## For composing an altitude or a distance in words. A radio distance past nineteen miles is off this island.
const NUMBER_WORDS: Array[String] = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight",
	"nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen",
	"nineteen"]


## ---- the catalogue, checked ------------------------------------------------------------------------

## WHAT IS WRONG WITH ONE ENTRY, in a sentence, or "" when nothing is. Pure, so every broken spelling is a check
## in a suite without a process. `known` holds every id in the catalogue, for a reply that names nothing.
static func problem(entry: Dictionary, known: Dictionary) -> String:
	var id: String = String(entry.get("id", ""))
	if id.is_empty():
		return "an entry has no id"
	if not SPEAKERS.has(StringName(entry.get("speaker", &""))):
		return "%s: speaker is '%s', not plane or tower" % [id, entry.get("speaker", "")]
	var text: String = String(entry.get("text", ""))
	if text.strip_edges().is_empty():
		return "%s: no text" % id
	var words: int = 0
	var rest: String = text
	for hit in _slot_finder().search_all(text):
		var name: String = hit.get_string(1)
		if not WORST_WORDS.has(name):
			return "%s: {%s} is not a slot" % [id, name]
		words += int(WORST_WORDS[name])
		rest = rest.replace(hit.get_string(0), " ")
	if rest.contains("{") or rest.contains("}"):
		return "%s: a brace that is not a slot" % id
	# WORDS, NOT TOKENS. With the slots cut out, "Tower, {callsign}, passing {altitude}." leaves "," and "." standing
	# on their own, and counting those read a ten-word line as twelve (the first chatter run, 2026-09-14).
	for token in rest.split(" ", false):
		if _word_finder().search(token) != null:
			words += 1
	if words > RadioTuning.MOST_WORDS:
		return "%s: %d words at its longest, over %d" % [id, words, RadioTuning.MOST_WORDS]
	var reply: String = String(entry.get("reply", ""))
	if not reply.is_empty() and not known.has(StringName(reply)):
		return "%s: replies with '%s', which is not a phrase" % [id, reply]
	return ""


## EVERY ENTRY WITH NOTHING WRONG WITH IT, by id. Each one left out says why as it is read.
##
## AND NOTHING ANSWERED BY ONE THAT WAS LEFT OUT. A reply is checked against every id in the catalogue, broken or not,
## so a good call whose answer was broken stayed in -- and the frequency, due that answer, looked it up and found
## nothing, once a slot, for as long as it ran (the first chatter run, 2026-09-14: `heading` kept, `roger_heading` left
## out, 173 script errors). So the leaving out is repeated until nothing more goes.
static func usable(phrases: Array[Dictionary] = PHRASES) -> Dictionary:
	var known: Dictionary = {}
	for entry in phrases:
		known[StringName(entry.get("id", ""))] = true
	var out: Dictionary = {}
	for entry in phrases:
		var why: String = problem(entry, known)
		if why.is_empty():
			out[StringName(entry["id"])] = entry
		else:
			print("[chatter] phrase left out: %s" % why)
	var dropped: bool = true
	while dropped:
		dropped = false
		for id in out.keys():
			var reply: StringName = StringName(out[id]["reply"])
			if reply != &"" and not out.has(reply):
				print("[chatter] phrase left out: %s: its reply '%s' was left out" % [id, reply])
				out.erase(id)
				dropped = true
	return out


## THE PHRASES THAT START AN EXCHANGE: every usable one no other usable one replies with.
static func openers(phrases: Dictionary) -> Array[StringName]:
	var answers: Dictionary = {}
	for id in phrases:
		answers[StringName(phrases[id]["reply"])] = true
	var out: Array[StringName] = []
	for id in phrases:
		if not answers.has(id):
			out.append(id)
	out.sort()
	return out


## ---- filling a line from the sky ----------------------------------------------------------------------

## `text` with every slot filled from `slots`, or "" if it names a slot `slots` has no answer for.
static func fill(text: String, slots: Dictionary) -> String:
	var out: String = text
	for hit in _slot_finder().search_all(text):
		var name: String = hit.get_string(1)
		if not slots.has(name):
			return ""
		out = out.replace(hit.get_string(0), String(slots[name]))
	return out


## WHAT THE SLOTS READ WITH NO AIRCRAFT: the island's own, which is only its runway. Enough for the tower to
## talk to everybody when nobody is in range, and nothing that names a craft fills from it.
static func station_slots() -> Dictionary:
	return {"runway": runway()}


## WHAT EVERY SLOT READS FOR ONE CRAFT, off its state as the simulation reports it (`Sim.current[entity]`), and
## the carrier's state, or {} when there is none.
static func slots(craft: Dictionary, carrier: Dictionary) -> Dictionary:
	var at: Vector3 = craft.get("position", Vector3.ZERO)
	var nose: Vector3 = Basis(craft.get("basis", Quaternion()) as Quaternion) * Vector3.FORWARD
	var out: Dictionary = station_slots()
	out["callsign"] = callsign(int(craft.get("kind", 0)), int(craft.get("entity", 0)))
	out["altitude"] = altitude_words(at.y)
	out["heading"] = "%03d" % nearest_ten(compass(nose))
	if not carrier.is_empty():
		var away: Vector3 = (carrier.get("position", at) as Vector3) - at
		away.y = 0.0
		var miles: String = miles_words(away.length())
		if not miles.is_empty():
			out["carrier"] = "%03d" % nearest_ten(compass(away))
			out["carrier_miles"] = miles
	return out


## "Airliner 27": the kind's word (`RadioTuning.CALLSIGNS`, or its name) and two digits off the same hash of the
## entity its voice is picked with (`RadioTuning.entity_marks`), so a respawned aircraft is a new callsign too.
static func callsign(kind: int, entity: int) -> String:
	var word: String = String(RadioTuning.CALLSIGNS.get(kind, Sim.kind_name(kind).capitalize()))
	return "%s %d" % [word, 10 + RadioTuning.entity_marks(entity) % 90]


## A COMPASS BEARING IN DEGREES: 0 along -Z and increasing to the right. The convention `VehicleView.craft_state`
## shows on every heading display, and every autopilot flies by.
static func compass(direction: Vector3) -> float:
	return fposmod(rad_to_deg(atan2(direction.x, -direction.z)), 360.0)


## A bearing as a radio reads it: to the nearest ten, and north is 360 rather than 000.
static func nearest_ten(degrees: float) -> int:
	var tens: int = int(round(degrees / 10.0)) * 10
	return 360 if tens == 0 or tens == 360 else tens


## THE RUNWAY'S NUMBER, off the way the runway points: its bearing in tens, and 36 rather than 0. THE WORLD'S FIRST RUNWAY,
## `Terrain.runways()[0]` -- the island's, or the generated ground's flattest strip's (team-lead, 2026-09-15): the number of
## the nearest runway to whoever speaks is a radio's to work out (agents.md, WHAT IS NOT HERE YET).
static func runway() -> String:
	return "%02d" % (nearest_ten(compass(Terrain.nose_from_yaw(float(Terrain.runways()[0]["bearing"])))) / 10)


## AN ALTITUDE AS A PILOT READS IT, from metres above the sea: "two thousand five hundred feet" to the nearest
## `ALTITUDE_STEP_FEET`, never less than one step, or "flight level 080" at and above the transition.
static func altitude_words(metres: float) -> String:
	var feet: float = metres * FEET_PER_METRE
	if feet >= RadioTuning.TRANSITION_FEET:
		return "flight level %03d" % (int(round(feet / 1000.0)) * 10)
	var step: float = RadioTuning.ALTITUDE_STEP_FEET
	var rounded: int = int(maxf(step, round(feet / step) * step))
	var parts: PackedStringArray = []
	if rounded >= 1000:
		parts.append("%s thousand" % NUMBER_WORDS[rounded / 1000])
	if rounded % 1000 > 0:
		parts.append("%s hundred" % NUMBER_WORDS[(rounded % 1000) / 100])
	return "%s feet" % " ".join(parts)


## A DISTANCE IN NAUTICAL MILES, in words, never less than one; "" past nineteen.
static func miles_words(metres: float) -> String:
	var miles: int = maxi(1, int(round(metres / METRES_PER_MILE)))
	if miles >= NUMBER_WORDS.size():
		return ""
	return "one mile" if miles == 1 else "%s miles" % NUMBER_WORDS[miles]


static var _finder: RegEx = null
static var _letters: RegEx = null

static func _word_finder() -> RegEx:
	if _letters == null:
		_letters = RegEx.create_from_string("[A-Za-z0-9]")
	return _letters


static func _slot_finder() -> RegEx:
	if _finder == null:
		_finder = RegEx.create_from_string("\\{([^{}]*)\\}")
	return _finder

extends Node
## Lobbies, peers, and the pipe ashiato-sync packets travel down.
##
## One layer, not two, because they are the same decision: whoever hosts is the machine
## running the authoritative simulation, and a Godot peer id IS a sync PeerId. Splitting
## them means a mapping table to keep in step and something new to get wrong every time
## somebody reconnects.
##
## Deliberately thin about the packets themselves. sync owns the protocol, the acks, the
## ordering and the resends; this only moves opaque bytes. Anything clever here would be a
## second, worse copy of what sync already does.

## HOW MANY PLAYERS A SESSION HOLDS, the host among them. SIXTY-FOUR since 2026-09-18: "let's make the max 64 for now, i
## want to see how things break down at higher loads so having an unreasonable amount is okay." It was eight. What it
## costs at 8, 16, 32 and 64 is `tests/player_load.gd`'s table, in cockpit/agents.md ("Sixty-four players"). A host may
## choose fewer (`choose_session_size`, `--players=N`); never more, and never more than one craft holds people
## (`host_refusal`).
const MAX_PLAYERS: int = 64
const DEFAULT_PORT: int = 7788
## THE PORT A SESSION USES WHEN NOBODY NAMES ONE: `host()`, the desk's "Host a game", a bare `--host`, and an address typed
## without a port. `DEFAULT_PORT` for a player and never anything else in the game. A SUITE that drives the desk's own
## button sets it from `TestPorts` first, because the button is the path under test and 7788 is one socket for the whole
## machine: on 2026-09-18 `session`, `lobby` and `desk_screens` in every lane that gated at once all hosted on it.
var usual_port: int = DEFAULT_PORT
## THE HELLO'S VERSION: a joiner told a different one is refused before it builds anything. See "THE HELLO".
## 2 since 2026-09-16: the level hello carries the session's sky, and `sky` / `sky_heard` exist. See "THE SKY".
## 3 since 2026-09-16: `notice` / `notice_heard` exist. See "THE NOTICES".
## 4 since 2026-09-16: bounded long documents use LONG_BITS on the existing unordered carrier.
## 5 since 2026-09-16: the level hello carries music, and `music` / `music_heard` exist.
## 6 since 2026-09-16: validated player cards and the authoritative roster share that hello.
## 7 since 2026-09-16: host-generated bounded radio clips are understood.
## 8 since 2026-09-17: a level notice is also an explicit transition cue; peers joining during its countdown receive it.
## 9 since 2026-09-17: ControlInput changes from eight full frames to acknowledged-baseline
## deltas and the cockpit input/history window grows to 128 frames. An older peer would decode
## the 21-bit field mask as throttle and pose data, so refuse it before carrying simulation packets.
## 10 since 2026-09-17: Mercury is kind 22; an older peer has no geometry or handling for it.
## 11 since 2026-09-17: the revisioned notice stream carries validated host sky choices. Older
## peers would reject and never acknowledge that notice kind, causing the host to resend forever.
## 12 since 2026-09-17: Fighter is kind 23; an older peer has no geometry, package, or handling for it.
## 13 adds Sim.Kind.UH60 and its native geometry/station contract. An older peer would
## decode kind 24 but have no matching shape, so the lobby must refuse it before play.
## 14 since 2026-09-17: `netstats` and `netboard` exist, the once-a-second per-client network statistics a level may
## keep. An older peer would drop them with a warning on every card -- harmless to the simulation, but a warning a
## second is what the harness fails on, and a board silently missing a player is worse than a refused join.
## 15 since 2026-09-17: the F-14 is kind 25, the command bus has a seventeenth channel (SWEEP), and CraftSystems carries
## the wings' commanded and actual sweep. An older peer would read the two bytes as the next field.
## 16 since 2026-09-17: ControlInput's command sequence is eight bits, not two (see `tests/command_burst.gd`). An older
## peer would read six of its bits as the room-control flag and what follows.
## 17 since 2026-09-18: the Savoia is kind 26 (twenty-seven kinds in five bits); an older peer has no shape for it.
## 18 since 2026-09-18: a command's channel is one form bit and then five bits or sixteen, its sequence is sixteen bits,
## and a craft's generic channels travel on BusPage entities (`tests/many_devices.gd`). An older peer would read the form
## bit as the channel's top bit and every field after it one place out.
## 19 since 2026-09-18: the F-16 is kind 27 (twenty-eight kinds in five bits). An older peer would decode kind 27
## but have no shape, package or handling for it.
## 20 since 2026-09-18: the MH-6M Little Bird is kind 28 (`Sim.Kind.LITTLEBIRD`), twenty-nine kinds in five bits. An
## older peer's shape tables stop at 27 and would build it as whatever its own last kind is.
## 21 since 2026-09-18: a craft kind is sixteen bits (`kKindIdBits`), carried in the old five-bit field for kinds to 29
## and for "no kind", with code 30 meaning sixteen more bits follow (`tests/many_kinds.gd`). Every frame of today's is
## bit-for-bit what it was, but an older peer reads code 30 as a kind and every field after it sixteen bits out.
## 22 since 2026-09-18: the EA-6B Prowler is kind 29, with its native shape, bus channels and four-seat role table.
## Older peers would decode the kind but have no matching geometry or stations.
## 23 since 2026-09-18: a seat is one form bit and then two bits or sixteen, "any seat" and "nobody's hands" are one bit,
## and Seats and CrewControls carry who is aboard rather than four seats (`tests/many_seats.gd`). An older peer would
## read the form bit as a seat's top bit and every field after it one place out.
## 24 since 2026-09-18: the CB90 fast assault craft is kind 30 (`Sim.Kind.CB90`, the first kind in the sixteen-bit form),
## and a missile row may see ships (`MissileType::ships`, the "sea radar" row) and leave a raised box launcher
## (`Loadout::launcher_pitch`). An older peer has no shape for 30 and no third missile row.
## 25 since 2026-09-18: a session is 64 players and a craft holds 64 people, so the count of people aboard in Seats and
## CrewControls is seven bits, not five; the roster and the statistics board travel in pages of at most one hello each
## (`page`, `pages`), and a roster too long for the level hello comes after admission. An older peer would read a
## count two bits short and every field after it two places out.
## 26 since 2026-09-18: the AH-64D Apache is kind 31 (`Sim.Kind.APACHE`, in the sixteen-bit form), two seats in
## tandem that both fly. An older peer has no shape for 31.
## 27 since 2026-09-18: the island's mountains are ranges of triangles, not boxes (range_core.hpp), and an island's
## "loaded" hello carries their meshes' hash where it carried "". An older peer stands among the stepped boxes and predicts
## itself through rock the host has, and through air where the host has rock.
## 28 since 2026-09-18: a joiner's first word is `hi` -- its protocol and which build it is -- and the host tells it the
## level only once that passes; a refusal carries a `code` and both builds' lines (`tests/handshake_peers.gd`). An older
## joiner never says hi and is told why in words it already reads; an older host never answers one, and its level hello
## is refused here on the protocol.
## 29 since 2026-09-18: the AH-64D's chin gun follows the gunner's head (`Seat::gun`, a helmet mount in `gun_of`, the
## seat poses carry `gun`), and the fourth missile row is the Hellfire (`kMissileHellfire` = 3) on a `helmet` rack whose
## seeker is each crewman's head. An older peer lays the chin gun from the stick and has no fourth missile row.
## 30 since 2026-09-19: the F/A-18F, F-14D and F-16 carry an M61 and two missile stations (lane/jetarms): a weapon
## selector and master arm on the F-14's and F-16's buses, a fifth missile row (`kMissileActiveRadar` = 4, the AMRAAM),
## and on these three `CraftSystems::load` is the gun's drum. An older peer has no loadout for them and no fifth row, and
## would refuse every launch and round the host accepts.
## 31 since 2026-09-19: the F-35B Lightning II is kind 32 (`Sim.Kind.LIGHTNING`), a tiltrotor whose thrust swings 95
## degrees (`Handling::vector_travel`). An older peer has no shape for 32. The number is the next free one at merge.
## 32 since 2026-09-19: the F-35B's weapons bays (lane/lightning step 3): `CraftSystems::bays`, two bits after the sweep,
## and `MissileState::ejected`, one bit after `guided`, for a missile pushed out of a bay whose motor lights late. An older
## peer reads every field after them one place out. The number is the next free one at merge.
## 33 since 2026-09-19: craft have hit points (lane/combat): `Hull` on a craft once it is first hit, `kCueDestroyed` the
## moment one is destroyed. An older peer has no Hull to read, draws no smoke, and flies on a wreck the host froze. The
## number is the next free one at merge.
## 34 since 2026-09-19: the MV-22B (lane/osprey): the Osprey's pilots sit at -0.75 m and the pilot on the right, its
## door gunners' turrets at -1.00, and its bus fits the ramp on the drop channel (`Fitted{"ramp", 1}`). An older peer seats
## the crew elsewhere in the hull and refuses the ramp bit the host accepts. The number is the next free one at merge.
## 35 since 2026-09-19: the A-10C Thunderbolt II is kind 33 (`Sim.Kind.WARTHOG`), an aeroplane with the GAU-8 on its
## one weapon station and its drum on `CraftSystems::load`, and a 30 mm round (`kAmmoThirty` = 11). An older peer has no
## shape for 33 and no row for 11. The kind's number and this one are the next free ones at merge (lane/warthog).
## 36 since 2026-09-19 (lane/liners): the 737, the 747 and the C-130 are their drawn size, mass and seats; kind 22 is
## `jumbo` (the 747-400, the row the E-6B Mercury had); kind 34 is the C-130H `transport`; and the gunship's guns stow (its
## Mode, mirrored to outside flag bit 2) and fire from the drawn barrels. An older peer seats the crews in the old boxes,
## has no shape for 34, and fires a stowed gunship's rounds from where its guns used to be.
## 37 since 2026-09-19 (lane/buildtime): every build says WHEN it was built, epoch seconds UTC (`BuildPlate.time`): the
## hi carries `built`, the level hello the host's, each roster card its player's, and a refusal says which side is newer
## and by how much. An older joiner says no `built` and is refused on its protocol, told it is the older build; an older
## host refuses this one on its protocol in its own words. The number is the next free one at merge.
## 38 since 2026-09-19 (lane/warbirds2): the P-51D is kind 35 (`Sim.Kind.P51`), the first taildragger: it is issued at its
## three-point rake and its wheels push where they are, and its six .50s fire from their drawn muzzles in turn. An older
## peer has no shape for 35 and predicts the craft level on a flat box. The kind's number and this one are the next free
## ones at merge.
## 39 since 2026-09-19 (lane/warbirds2): the P-47D-30 is kind 36 (`Sim.Kind.P47`), the second taildragger and the
## first whose tail wheel does not steer at all -- locked at centre or full swivel, so it turns on its brakes. Its eight
## .50s fire from their drawn muzzles in turn. An older peer has no shape for 36 and predicts the craft level on a flat
## box. The kind's number and this one are the next free ones at merge.
## 40 since 2026-09-19: a roster card carries the team the host put that player on, and the chat says
## `chat`/`chat_heard` from a peer and `chatline`/`chatline_heard` from the host. The card's compact form grows from four
## elements to five, and an older peer reads a five-element card as no card at all: `_read_roster_fields` accepts the
## three- and four-element forms and drops anything else, taking THE WHOLE ROSTER with it, so an older peer in a new
## session would draw an empty player list rather than a wrong one. Refuse it on the protocol instead.
## 41 since 2026-09-20 (lane/fireboat): a FIREBOAT is kind 37 (`Sim.Kind.FIREBOAT`), a 42.7 m 500-tonne boat on the FDNY
## Three Forty Three with two helms and three water MONITORS. An older peer has no shape for 37. Two things about her
## DID move the wire and both are on `CraftSystems`: three bits saying which monitors are pumping, and -- the reason
## this note is worth reading -- the outside flags are now written `kOutsideFlagBits` wide instead of a hard-coded
## FOUR. The mask and the width had been two copies of one fact since the component was written, and widening the
## mask alone dropped the new bits silently on the wire with nothing red to say so. An older peer reads the wider
## field as the four it expects plus rubbish in every field after it. Her monitors' AIM costs nothing: it rides the
## three turret mounts `CraftSystems` has carried since the gunship.
## 42 since 2026-09-20: live voice. Frames travel at `VOICE_BITS` on the unordered carrier, and `talking`/`talking_heard`
## carry the host's answer to who is speaking. An older peer drops a negative bit count it does not know with a warning
## per frame -- fifty a second while anybody talks, and the harness fails on any warning -- and would light no lamps at
## all. 41 is lane/fireboat's, landed just before this; this lane also holds 40, for the teams and the chat.
## 43 since 2026-09-20 (lane/phantom): the F-4E PHANTOM II is kind 38 (`Sim.Kind.PHANTOM`), a two-seat airplane
## carrying an M61A1 with 640 rounds and the Sparrow on its radar row. An older peer has no shape, package or
## handling for 38 and would draw it as whatever its own last kind is. NOTHING SKIPS: 41 is fireboat's and 42 is
## voicelobby's, and both landed while this lane was building, so the three numbers were taken in the order the
## work finished rather than the order it started. The number was settled by grepping every lane's `net.gd` rather
## than by reading a message -- the tree said 41 where a message said 42, and the tree was right.
const PROTOCOL: int = 43
## Human-readable public release channel, advertised exactly in lobby metadata.
const BUILD_CHANNEL: String = "alpha"
## Bump for an incompatible gameplay/schema change that does not already bump PROTOCOL.
const COMPATIBILITY_REVISION: String = "cockpit-1"
## The bit count a hello travels with on the carriers. Below zero, because sync never sends a packet of no bits.
const HELLO_BITS: int = -1
## A binary long-document chunk or acknowledgement. It always uses `_receive_unordered`, including
## on ENet: unreliable-ordered may discard an older retried chunk after a newer one arrived.
const LONG_BITS: int = -2
## LIVE VOICE FRAMES, on the unordered carrier. See "THE VOICE".
const VOICE_BITS: int = -3
## How often a hello not yet answered is said again, milliseconds.
const HELLO_EVERY_MSEC: int = 200
## The most a hello may be, and the most a refusal's reason may say: anything longer is dropped or cut, and said.
const HELLO_MOST_BYTES: int = 512
## 300 since 2026-09-18 (was 160): a refusal now names BOTH builds, and two release lines and the sentence round them
## run to about 190 letters. An older client cuts a longer one to its 160 and says so.
const HELLO_WHY_MOST: int = 300

signal session_message(text: String)
signal session_ready
signal session_ended(reason: String)
## A NEW LOCAL SESSION ATTEMPT HAS CLEARED ALL REVISION COUNTERS. Persistent consumers use this epoch to accept revision
## zero in the next session while still rejecting a stale duplicate inside one session.
signal session_reset(epoch: int)
## THE HOST HAS CHANGED THE LEVEL AND THIS MACHINE MUST GO AND BUILD IT. Not `session_ready`: the session is the same
## one, the socket is untouched and nobody is joining anything. See `change_level`.
signal level_changing(id: String)
## A HOST-AUTHORED, REVISIONED LEVEL CUE, on the host and every client that accepts it. The cue is small and contains
## facts rather than UI text: {kind = "level", target, revision, due}. `due` is on this machine's monotonic clock,
## reconstructed from the remaining time carried over the network. See "THE NOTICES" and TransitionCurtain.
signal level_cued(cue: Dictionary)
## THIS MACHINE FINISHED BUILDING THE NAMED LEVEL. A persistent transition curtain listens to this rather than a
## scene-local ready signal, so it survives the scene replacement and never reveals a half-built world.
signal level_loaded_here(id: String)
## THE SESSION'S SKY HAS CHANGED: the time of day or the clouds, on this machine because it decided or because its host
## said so. The level draws it. See "THE SKY".
signal sky_changed
## THE HOST'S MUSIC STATE changed here or arrived from the host. A MusicBox turns it into sound.
signal music_changed
## SOMETHING HAPPENED IN THE SESSION THAT EVERYBODY IN IT SHOULD BE TOLD: the level is about to change, somebody joined,
## somebody left, or the host changed the shared sky. `notice_words` is what to write. See "THE NOTICES".
signal noticed
## A LINE OF CHAT HAS LANDED HERE, host or client, and the board should draw it: {"n", "player", "text"}. A line is
## announced once, however many times its packet arrived.
signal chat_arrived(line: Dictionary)
## A FRAME OF SOMEBODY'S VOICE HAS LANDED HERE, still packed: `VoiceFrame` unpacks it and `Intercom` plays it. Raw
## rather than decoded because the host relays far more frames than it ever listens to.
signal voice_arrived(bytes: PackedByteArray)
## WHO THE HOST SAYS IS TALKING has changed. The lamp reads `Net.is_talking`, never a local guess: a listener on another
## team receives none of a speaker's audio and must still light them.
signal talking_changed
## A CLIENT'S ONCE-A-SECOND NETWORK STATISTICS ARRIVED, on the host. The level's `NetStats` keeps them; `Net` only
## carries them. See "THE STATISTICS CARD".
signal stats_row_heard(row: Array)
## THE HOST'S TABLE ARRIVED, on a client.
## `page` of the host's board: page 0 starts a fresh one, and the pages after it add to it (`publish_the_stats_board`).
signal stats_board_heard(table: Array, page: int)

## A PAGE OF THE RADAR PICTURE THE HOST DREW FOR *THIS* MACHINE: page 0 starts a fresh one and the pages after it add
## to it, as the statistics board's do. Rows are `RadarSet.COLUMNS` order.
##
## THE DIFFERENCE FROM EVERY OTHER CARRIER HERE IS THAT EACH PEER IS SENT SOMETHING DIFFERENT. A board, a notice, the
## sky and the roster are one thing published to everybody; a radar picture is drawn from one head and is nobody
## else's picture. That is what makes concealment mean anything (`world/radar_set.gd`), and it is why
## `publish_the_radar_picture` takes a picture PER PEER rather than a table.
signal radar_heard(rows: Array, page: int, sweep: int)
signal roster_changed
signal packet_arrived(from_peer: int, bytes: PackedByteArray, bits: int)
signal long_message_arrived(from_peer: int, kind: StringName, bytes: PackedByteArray)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)

var is_host: bool = false
var is_in_session: bool = false
## "none" | "solo" | "enet" | "steam". "steam" from the moment a Steam session is asked for, before it is up, as "enet"
## is from the moment a join's socket opens: a desk waiting on either can tell a session still coming from one refused.
var transport: String = "none"
var session_epoch: int = 0
## ARTIFICIAL ONE-WAY DELAY ON THIS MACHINE'S SOCKET EDGES, for reproducing a real link
## while using ENet on one desk. A joiner set to 100 ms delays its sends by 100 ms and its
## receives by 100 ms, producing a 200 ms round trip. The host's in-process solo client is
## carried directly by Sim and deliberately never enters these queues.
const EXTRA_LATENCY_MOST_MS: int = 500
var extra_latency_ms: int = 0:
	set(value):
		if value < 0 or value > EXTRA_LATENCY_MOST_MS:
			push_warning("[net] link latency %d ms is outside 0..%d; clamped" % [
				value, EXTRA_LATENCY_MOST_MS])
		extra_latency_ms = clampi(value, 0, EXTRA_LATENCY_MOST_MS)
var _send_in_flight: Array[Dictionary] = []
var _receive_in_flight: Array[Dictionary] = []
## WHETHER A PERSON CHOSE THIS MACHINE'S LINK -- `--latency=` on the command line, or a press on the clipboard's LINK
## row -- rather than the machine standing on whatever the level asks for. The shape and the reason are `level_chosen`'s
## and `Finish._chosen`'s: move an UNCHOSEN setting to the default of whatever is about to happen, and leave a chosen
## one where the person put it. See `suit_the_link`.
var link_chosen: bool = false
## THE LEVEL THIS SESSION FLIES, or the next one will: a `ChartDrawer` id. Chosen on the desk or with `--world=` before
## hosting or flying solo, and kept between sessions, so the desk remembers it. See `choose_level`.
var level: String = ChartDrawer.DEFAULT


## WHY THE LAST SESSION ENDED, WHEN THE PLAYER DID NOT CHOOSE IT: a refusal or the host leaving, said by whatever
## the player is taken back to. "" when there is nothing to say -- a session left on purpose (MAIN MENU, Quit, a
## suite) says nothing. The desk reads it once and clears it.
var parting_words: String = ""


## WHETHER A PLAYER HAS CHOSEN THE LEVEL -- the chart monitor, or `--world=` on a command line -- rather than the machine
## standing on a default. See `suit_the_session`; the shape is `Finish._chosen`'s and so is the reason.
var level_chosen: bool = false

const NAME_MOST: int = 16
const PROFILE := preload("res://net/player_profile.gd")
## client id -> {player, name, colour}. This is the only identity lookup used by UI and map.
var roster: Dictionary = {}
var _cards_by_peer: Dictionary = {}
## ---- THE CHAT: TYPED LINES, EVERY ONE OF WHICH HAS TO ARRIVE ----------------------------------------------------
##
## The user asked for it (2026-09-19): "So it will need a player lobby with text chat".
##
## WHY THIS IS A FOURTH CARRIER AND NOT ONE OF THE THREE. Every carrier this game already has keeps only the LATEST of a
## thing, because every one of them carries STATE:
##
##   - a hello is said again every 200 ms until heard, and a newer one overwrites the older (`sky`, `music`, the card);
##   - a notice is host-only and "only the latest notice is owed", and free text on the wire is REJECTED there on purpose
##     -- a notice is a fact each machine words for itself;
##   - a long document replaces the in-flight one of its own kind and clears its own kind out of the waiting queue
##     (`LongTransfer.send`), which is right for a 64 KiB layout or a radio clip and wrong for a line of conversation.
##
## Chat is not state. It is a QUEUE OF EVENTS, and a line nobody ever sees is a bug a player notices immediately: type
## two lines quickly on any of the three above and the first is gone. So the chat keeps the shape those carriers use --
## say it again every `HELLO_EVERY_MSEC` until it is acknowledged -- and changes the one thing that matters: what is
## acknowledged is a LINE NUMBER, and the sender moves on to the next line only once the current one is in.
##
##   peer -> host   {"say": "chat", "n", "text"}        again every 200 ms until acknowledged
##   host -> peer   {"say": "chat_heard", "n"}          to every `chat` it accepts, INCLUDING a repeat
##   host -> peer   {"say": "chatline", "n", "player", "text"}   the oldest line that peer has not taken
##   peer -> host   {"say": "chatline_heard", "n"}      to every `chatline`
##
## ONE LINE IN FLIGHT EACH WAY PER PEER, and both ends number their own lines from 1. A repeat is acknowledged and NOT
## appended twice (`_chat_from`), which is what makes the carrier safe on a link that delivers the same unreliable packet
## more than once -- and `_receive`'s own comment says Steam's does.
##
## THE HOST IS THE ONLY PLACE A LINE GETS ITS NUMBER, its player and its place in the log, so two players typing at once
## cannot disagree about the order: they cannot, because neither of them decides it.
##
## Rejected: a reliable Godot RPC per line, which `tests/lint.gd` forbids outside the two carriers and which would be a
## second ordering model beside sync's, for a feature that needs 200 bytes a minute.

## EVERY LINE THE SESSION HAS SAID, oldest first, each {"n", "player", "text"}: the host's own record, and on a client
## every line it has been told. At most `ChatLine.MOST_KEPT` on either.
var chat_log: Array[Dictionary] = []
## The host's: how many lines it has accepted this session, which is the number of the newest.
var _chat_version: int = 0
## The host's: peer -> the highest line number that peer has acknowledged.
var _chat_taken: Dictionary = {}
## The host's: peer -> when to say that peer's oldest owed line again.
var _chat_owed_at: Dictionary = {}
## The host's: peer -> the highest line number it has ACCEPTED FROM that peer, so a repeat is acknowledged and not
## appended a second time.
var _chat_from: Dictionary = {}
## A client's: lines typed here and not yet acknowledged by the host, oldest first.
var _chat_outbox: Array[String] = []
## A client's: how many lines this machine has offered, so each has a number its host can tell from a repeat.
var _chat_said: int = 0
## A client's: when to offer the line at the front of the outbox again.
var _chat_next: int = 0
## A client's: the highest line number it has taken from the host, so a repeated `chatline` is not drawn twice.
var _chat_heard_to: int = 0

## THE HOST'S TEAM BOOK: sync client id -> team number, for every player it has put on one. Only the host writes it;
## everybody else reads a team off the roster card the host publishes (see `TeamBoard`). A player who is on no team is
## simply absent from here, so forgetting somebody is the same thing as taking them off a team.
var _teams_by_client: Dictionary = {}
var _roster_version: int = 0
var _roster_owed: Dictionary = {}
## peer -> {page: true} of the current roster's pages that peer has said it heard. See "THE ROSTER, IN PAGES".
var _roster_pages_heard: Dictionary = {}
var _roster_heard: int = -1
## revision -> {page: cards}, the pages of a roster this joiner has so far, until every page of one revision is in.
var _roster_parts: Dictionary = {}
## HOW MANY PLAYERS THIS SESSION TAKES, the host among them: `MAX_PLAYERS` unless the host chose fewer.
var session_players: int = MAX_PLAYERS
var _card_next: int = -1
var _card_heard: bool = false
var _local_card: Dictionary = {"name": "", "colour": 0}
var _profile_edited: bool = false
## Injectable only for suites. Empty uses the already-initialised Steam lobby directory.
var persona_name: Callable = Callable()


## CHOOSE THE LEVEL THE NEXT SESSION FLIES: "" when it was taken, a sentence when it was not. Refused while a session is
## up, because every machine in a session stands on the level its host started it with.
func choose_level(id: String) -> String:
	if ChartDrawer.chart(id) == null:
		return "There is no level called %s." % id
	if is_in_session:
		return "The level is chosen before a session starts."
	level = id
	level_chosen = true
	return ""


## THE LEVEL A SESSION OF THIS KIND STARTS ON WHEN NOBODY HAS CHOSEN ONE. The user, 2026-09-15: "let's make the lobby
## default when hosting a session. and island if they are playing alone."
##
## So the default is not one level any more -- it is a rule about which kind of session is being started, and
## `ChartDrawer.DEFAULT` on its own cannot say it. WHAT IT IS NOT IS AN OVERRIDE. `level` is deliberately kept between
## sessions so the desk remembers what a player picked, and a player who chooses the island on the chart monitor and
## then presses HOST must get the island. That is `Finish.suit_the_display`'s shape exactly, and its reason: move an
## UNCHOSEN setting to the default of whatever is about to happen, and leave a chosen one where the player put it.
##
## CALLED BY EVERY DOOR THAT STARTS A SESSION OF THIS MACHINE'S OWN -- `play_solo`, `host`, `host_steam` -- and by
## nothing else, so the boot flags follow the rule without `world/boot.gd` knowing it exists (`--host` goes through
## `host`, and `--world=` is a choice through `choose_level`, which beats it). A JOINER is not one of them: it flies its
## host's level whatever it had chosen, which is what the hello is for.
## CHANGE THE LEVEL WITH A SESSION UP: "" when it was taken, a sentence when it was not.
##
## Item 11, asked for on 2026-09-15: "make sure that the server can 'change the level' and the clients correctly load
## that level and join the game." And with the lobby being a level, this is also how a briefing room launches into a
## flight -- the two are one thing (plan.md, item 2c).
##
## A LEVEL CHANGE IS THE JOIN HANDSHAKE, RUN AGAIN, and there is deliberately no second protocol (team-lead,
## 2026-09-15). Every admitted peer becomes UN-ADMITTED and goes back into `_telling`, so the same four messages happen
## for the same reasons: the host says `level` until it is answered, the peer says `loaded` when it has built it, the
## host checks the hash and the ground and says `admitted`, and a peer that cannot fly the new level is refused in
## `why_not_the_level`'s own words. `admits` is what holds a peer's packets meanwhile -- the gate a joiner meets,
## withdrawn rather than never granted, so a machine rebuilding is never simulated into a world it no longer has.
##
## `_built_here` GOES BACK TO FALSE, and that is the part that is easy to miss: between the change and the host's own
## rebuild, `_ground_here` is still the OLD level's hash, so a peer that got there first would be sent away for ground
## that is not its fault. Until the host has built, a `loaded` is not answered at all, and the peer says it again.
func change_level(id: String) -> String:
	if not is_in_session:
		return "The level is chosen before a session starts."
	if not is_host:
		return "Only the host changes the level."
	if ChartDrawer.chart(id) == null:
		return "There is no level called %s." % id
	if id == level:
		return ""
	level = id
	level_chosen = true
	_built_here = false
	_ground_here = ""
	var now: int = Time.get_ticks_msec()
	for peer in admitted.keys():
		_telling[int(peer)] = now
	admitted.clear()
	_report("NET_LEVEL_CHANGED level=%s peers=%d at=%.3f" % [level, _telling.size(),
		Time.get_unix_time_from_system()])
	level_changing.emit(level)
	return ""


## SOMEBODY CHOSE THIS MACHINE'S LINK, and it stays chosen until the game is restarted: the clipboard's LINK row and
## `--latency=`. A chosen link beats every level's, including a level that asks for none.
func choose_link(ms: int) -> void:
	link_chosen = true
	extra_latency_ms = ms


## THE LINK THIS MACHINE HOLDS ON THE LEVEL IT IS ABOUT TO FLY, called from every build (`Sky._build`), so a machine
## that walks out of a level that asks for a link walks out of the link as well.
##
## **THE HOST HOLDS NONE OF IT, AND THAT IS THE WHOLE DEFINITION.** `extra_latency_ms` delays this machine's sends AND
## its receives, so one machine's edge is crossed once in each direction: a host at 0 and a joiner at 80 is exactly 80 ms
## one way and 160 ms round trip, which is what "80 ms of lag" is measured to mean here. Both ends holding 80 would be
## 160 one way and 320 round trip -- the same number meaning twice as much lag, which is how a stress measurement
## quietly answers a question nobody asked. The host's own in-process client is carried by `Sim` and never enters these
## queues at all, so a host's row on a stats board reads near zero latency by construction; a board that shows it says so.
func suit_the_link(level_link_ms: int) -> void:
	extra_latency_ms = link_for(level_link_ms, is_host, is_networked(), link_chosen, extra_latency_ms)


## THE RULE ITSELF, PURE, so a suite can put every case through it without a socket and so there is one copy of it:
## a chosen link stands whatever the level says; a host and a machine on no socket hold none; everybody else holds the
## level's. `now` is what the machine is holding, which is what a chosen link keeps.
static func link_for(level_link_ms: int, hosting: bool, networked: bool, chosen: bool, now: int) -> int:
	if chosen:
		return now
	if hosting or not networked:
		return 0
	return clampi(level_link_ms, 0, EXTRA_LATENCY_MOST_MS)


func suit_the_session(hosting: bool) -> void:
	if level_chosen:
		return
	var wanted: String = ChartDrawer.HOSTING if hosting else ChartDrawer.DEFAULT
	# A LEVEL THIS BUILD HAS NOT GOT CHANGES NOTHING: the rule names a folder, and a folder can be renamed or refused.
	if wanted == level or ChartDrawer.chart(wanted) == null:
		return
	level = wanted
	print("[net] %s, the level a %s session starts on when nobody chose" % [wanted, "hosted" if hosting else "solo"])


func _ready() -> void:
	lobbies = SteamLobbyDirectory.new()
	_local_card = PROFILE.load_card()
	_profile_edited = bool(_local_card.get("typed", false))
	multiplayer.peer_connected.connect(func(id: int) -> void: peer_joined.emit(id))
	multiplayer.peer_disconnected.connect(func(id: int) -> void: peer_left.emit(id))
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_host_gone)
	multiplayer.peer_connected.connect(_on_peer_arrived)
	multiplayer.peer_disconnected.connect(_on_peer_gone)
	# THE SKY A MACHINE STARTS UNDER BEFORE ANYBODY HAS SAID ANYTHING: `--time=` or the start. See "THE SKY".
	_start_the_sky()
	for argument in OS.get_cmdline_user_args():
		# A SUITE'S PRETENCE, and nothing else's: see `identity`.
		if argument.begins_with("--pretend-build="):
			var said: PackedStringArray = argument.trim_prefix("--pretend-build=").split("|", true, 1)
			_pretend["commit"] = said[0]
			_pretend["line"] = said[1] if said.size() > 1 else said[0]
		if argument.begins_with("--pretend-protocol="):
			_pretend["protocol"] = int(argument.trim_prefix("--pretend-protocol="))
		# `none` IS A BUILD FROM BEFORE PROTOCOL 37, whose hi says no time at all.
		if argument.begins_with("--pretend-built="):
			var built: String = argument.trim_prefix("--pretend-built=")
			_pretend["built"] = int(built) if built.is_valid_int() else -1
		if argument.begins_with("--latency="):
			choose_link(int(argument.trim_prefix("--latency=")))
		# A STEAM NAME, for a suite: `--pretend-persona=NAME` is there from boot; `NAME@heard` reads "" until the host
		# has acknowledged this machine's first card, as Steam's does when Steam starts after the card went out -- the
		# case a card must be said again for. See "THE PLAYER'S NAME".
		if argument.begins_with("--pretend-persona="):
			var said: PackedStringArray = argument.trim_prefix("--pretend-persona=").split("@", true, 1)
			var late: bool = said.size() > 1 and said[1] == "heard"
			var persona: String = said[0]
			persona_name = func() -> String: return persona if not late or _card_first_heard_msec >= 0 else ""
	# THE PLAYER'S STEAM NAME, FOR A PLAYER: Steam started now, at boot, only for a real player's run. See
	# `steam_at_boot_refusal`; one line in the log either way, so a report says why a name is or is not Steam's.
	var refused: String = steam_at_boot_refusal(OS.get_cmdline_args(), OS.get_cmdline_user_args(),
		DisplayServer.get_name(), OS.get_environment("COCKPIT_TEST_SLOT"), _steam_client_running())
	if refused == "" and lobbies != null:
		refused = lobbies.unavailable()
	print("STEAM_AT_BOOT=%s" % ("started, for the player's name" if refused == "" else "no (%s)" % refused))


## ON THE WAY OUT OF THE GAME: out of any lobby, and every hook into Steam taken off while the scripts that own them are
## still alive. An autoload leaves the tree on a normal quit before scripts are torn down, and after that nothing can
## disconnect them -- see `SteamLobbyDirectory.close`, and the exit code it saves.
func _exit_tree() -> void:
	_start_afresh()
	if lobbies != null:
		lobbies.close()


func is_networked() -> bool:
	return multiplayer.multiplayer_peer != null \
		and multiplayer.multiplayer_peer.get_class() != "OfflineMultiplayerPeer"


func my_peer_id() -> int:
	return multiplayer.get_unique_id() if is_networked() else 1


## HOW MANY MACHINES ARE IN THIS SESSION, this one included: the peers the transport knows, plus us. One number in one
## place, because the board says it beside the code and the games list says it about somebody else's lobby, and two
## counts of the same thing disagreeing is how a full game reads as having room.
func aboard() -> int:
	return (multiplayer.get_peers().size() + 1) if is_networked() else 1


func play_solo() -> void:
	suit_the_session(false)
	_start_afresh()
	_start_the_sky()
	is_host = true
	is_in_session = true
	transport = "solo"
	session_message.emit("Solo.")
	session_ready.emit()


## ---- Steam, by code ----------------------------------------------------------------------------
##
## Asked for on 2026-09-14: "a join code for steam players so they can join a game via a join code rather than having
## to be invited or searching for a game." A host makes an INVISIBLE lobby and writes a code on it; a friend types the
## code, and a search filtered on it finds the lobby. `JoinCode` is the code, `LobbyDirectory` is where lobbies are
## looked up, and this is the order things happen in and what is said when one of them does not.
##
## EVERY STAGE HAS A DEADLINE, and the deadline is what says no. Steam answers a request later or not at all: a search
## "can take from 300ms to 5 seconds to complete" with "a timeout of 20 seconds" (Steamworks, ISteamMatchmaking), and a
## socket against a host that is not there never fails (working_with_godot.md). Measured on 2026-09-14 against the real
## Steam backend (tests/steam_probe.gd): a lobby made in 187 ms, found by its code in 186 ms, and not found 228 ms after
## it was left. So the deadlines are generous against what was measured and none of them is the only thing standing
## between a player and a wait that never ends.

## The directory of lobbies. Steam's, unless a suite has put a paper one here.
var lobbies: LobbyDirectory = null:
	set(value):
		if lobbies != null:
			_cancel_find(_stage_find)
			_cancel_find(_browse_find)
			lobbies.opened.disconnect(_on_opened)
			lobbies.found.disconnect(_on_found)
			lobbies.find_started.disconnect(_on_find_started)
			lobbies.entered.disconnect(_on_entered)
			lobbies.invited.disconnect(join_lobby)
		lobbies = value
		_stage_find = 0
		_browse_find = 0
		if lobbies != null:
			lobbies.opened.connect(_on_opened)
			lobbies.found.connect(_on_found)
			lobbies.find_started.connect(_on_find_started)
			lobbies.entered.connect(_on_entered)
			lobbies.invited.connect(join_lobby)

## The lobby this machine is IN, or 0. Not the one it is knocking on: a lobby that refused us was never ours to leave.
var lobby: int = 0
## The lobby being entered, until it answers.
var _knocking: int = 0
## The code the session was found by, as JoinCode reads it, on the host and on everybody who joined by it. "" otherwise.
var session_code: String = ""
## EVERY COCKPIT GAME STEAM ANSWERED WITH, one Dictionary each, in the order they are to be read. Emitted by
## `look_for_games` when the search comes back, and EMPTY when it was refused or nothing answered -- so a screen that
## draws this always has something to draw, and never sits on a stale list. See `_read_the_games` for a row's fields.
signal games_listed(games: Array)
## What a new code is drawn from. A suite puts a sequence here to reach the redraw.
var draw_code: Callable = func() -> String: return JoinCode.fresh()

## Written on every lobby, so a code typed into this game finds this game's lobbies and nothing else on App ID 480,
## which every Steamworks developer shares.
const GAME_TAG: String = "cockpit_v1"
## How many codes a host draws before giving up on finding one nobody holds. At 9.3e-8 a clash per draw with a hundred
## lobbies open, three in a row is a Steam that is answering every search with something.
const CODE_DRAWS: int = 3
## HOW MANY GAMES A LOOK ROUND LISTS AT MOST. A session is 8 players, so twenty lobbies is more of this game than has
## ever been open at once; and the list is drawn on one screen, which is what really limits it -- see `GameList`.
const MOST_LISTED: int = 20
## Seconds each stage may take. `patience` is what is used, so a suite can shorten it; this is what it goes back to.
const PATIENCE: Dictionary = {"check": 20.0, "open": 20.0, "search": 20.0, "browse": 20.0, "enter": 10.0,
	"connect": 10.0, "hello": 10.0}
var patience: Dictionary = PATIENCE.duplicate()
## What each stage says when its deadline passes.
const TOO_LONG: Dictionary = {
	"check": "Steam did not answer. Try again.",
	"open": "Steam did not make a lobby in time.",
	"search": "Steam did not answer. Try again.",
	"browse": "Steam did not answer. Try again.",
	"enter": "Steam did not let you into that game in time.",
	"connect": "The host did not answer.",
	"hello": "The host never said which level it is flying.",
}

var _stage: String = ""
var _stage_until: int = 0
var _next_find: int = 0
var _stage_find: int = 0
var _browse_find: int = 0
var _browse_until: int = 0
var _find_kinds: Dictionary = {}
var _wanted: String = ""
var _draws: int = 0
var _long := LongTransfer.new()
var _long_pump_deferred: bool = false
## Item 10 may install a per-peer load signal here. Empty means do not pause; Net does not guess
## at sync's private loss/rollback counters.
var long_paused_for_peer: Callable = Callable()
## Kind-specific semantic gates installed by the feature that consumes a document. LongTransfer
## still checks the binary envelope, CRC, size, and basic JSON shape before these are called.
var long_validators: Dictionary = {}


func _process(_delta: float) -> void:
	_flush_in_flight()
	if lobbies != null:
		lobbies.pump()
	_say_hellos()
	_keep_the_notices()
	_keep_the_roster()
	_keep_my_card()
	_keep_the_chat()
	_keep_the_talking()
	if _stage != "" and Time.get_ticks_msec() > _stage_until:
		# Session-building stages pull down the half-built session. Browse owns a separate
		# request and deadline below, so it can finish while a code lookup is underway.
		var gave_up: String = too_long(_stage)
		logbook.write("TIMED_OUT", "client" if not is_host else "host", {"code": _stage, "who": _where_to(),
			"words": gave_up})
		_refuse(gave_up, false)
	if _browse_find != 0 and Time.get_ticks_msec() > _browse_until:
		_stop_looking(String(TOO_LONG["browse"]))


## AFTER the physics frame has offered sync its packets, schedule at most one background chunk per peer.
func _physics_process(_delta: float) -> void:
	if not _long_pump_deferred:
		_long_pump_deferred = true
		_pump_long.call_deferred()


func _pump_long() -> void:
	_long_pump_deferred = false
	_long.host = is_host
	var emit := func(peer: int, packet: PackedByteArray) -> void:
		if is_networked() and peer in multiplayer.get_peers():
			_carry(peer, packet, LONG_BITS, "long")
	_long.pump(Time.get_ticks_msec(), emit, long_paused_for_peer)
	while not _long.completed.is_empty():
		var message: Dictionary = _long.completed.pop_front()
		long_message_arrived.emit(int(message["peer"]), StringName(message["kind"]), message["bytes"])


## Queue one bounded document. Empty means accepted; otherwise the returned sentence says why not.
func send_long(peer: int, kind: StringName, bytes: PackedByteArray, stale_msec: int) -> String:
	if not is_networked() or peer not in multiplayer.get_peers():
		return "That peer is not in this session."
	if is_host and not admits(peer):
		return "That peer has not joined this level."
	if not is_host and peer != 1:
		return "A client sends long messages only to its host."
	if bool(LongTransfer.KINDS.get(kind, {}).get("host_only", false)) and not is_host:
		return "Only the host sends %s long messages." % kind
	return _long.send(peer, kind, bytes, stale_msec, Time.get_ticks_msec())


func set_long_validator(kind: StringName, validator: Callable) -> String:
	if not LongTransfer.KINDS.has(kind):
		return "There is no long-message kind called %s." % kind
	if validator.is_valid(): long_validators[kind] = validator
	else: long_validators.erase(kind)
	return ""


## THE PUBLIC RELEASE CHANNEL written on every lobby. Compatibility is a separate identity
## so the name players see stays `alpha` while incompatible alpha revisions are still refused.
## NO SESSION HOLDS MORE PLAYERS THAN ONE CRAFT CAN HOLD PEOPLE: "" when `MAX_PLAYERS` fits, else the words.
##
## A craft may have any number of seats (the user, 2026-09-18: "yes, no max"), but what it keeps and sends is one entry
## per person aboard, up to the library's `most_aboard` -- which is what lets a sixty-four-seat craft cost what its
## crew costs. A session of more players than that could fill a craft past it, and the last to sit down would be
## refused a seat that is plainly free. So the cap on players is checked against it here, where a session begins, and
## `tests/many_seats.gd` holds that it fits. The limit on PEOPLE ABOARD is therefore the session's player cap.
## HOST FEWER THAN `MAX_PLAYERS`: "" and the session takes `players`, or the words why not. From 2 -- a host and one
## joiner -- to `MAX_PLAYERS`. The desk has no control for it; `--players=N` on the command line is the door, and
## `tests/players_peers.gd` uses it to fill a session of two and hear the third told it is full.
func choose_session_size(players: int) -> String:
	if players < 2 or players > MAX_PLAYERS:
		return "--players= wants 2 to %d players, and %d is not one of those" % [MAX_PLAYERS, players]
	session_players = players
	return ""


static func host_refusal() -> String:
	var most: int = int(Sim.seat_limits().get("most_aboard", 0))
	if most > 0 and MAX_PLAYERS > most:
		return "This build lets %d players in and a craft holds %d; it cannot host." % [MAX_PLAYERS, most]
	return ""


static func build() -> String:
	return BUILD_CHANNEL


## Compatibility is separate from the public channel. The protocol and explicit source
## revision cover this project; production native builds add their stamped ashiato revision.
## A missing or `unknown` native stamp is named explicitly and can never become the identity.
static func compatibility() -> String:
	var native: String = "no-native-extension"
	if ClassDB.class_exists(&"AshiatoWorld"):
		var world: Object = ClassDB.instantiate(&"AshiatoWorld")
		if world != null and world.has_method("upstream_revision"):
			var stamped: String = String(world.call("upstream_revision")).strip_edges()
			if stamped != "" and stamped != "unknown":
				native = stamped
	return "%s-p%d-%s" % [COMPATIBILITY_REVISION, PROTOCOL, native]


## HOST OVER STEAM: draw a code nobody holds, make an invisible lobby, write the code on it, and host the game over it.
func host_steam() -> void:
	suit_the_session(true)
	var why: String = host_refusal()
	if why == "":
		why = lobbies.unavailable() if lobbies != null else "Steam is not in this build."
	if why != "":
		_refuse(why)
		return
	_start_afresh()
	_start_the_sky()
	is_host = true
	transport = "steam"
	_draws = 0
	session_message.emit("Asking Steam for a lobby…")
	_draw_a_code()


## A CODE IS CHECKED BEFORE A LOBBY IS MADE WITH IT, not after: searching for our own lobby's code would have to wait for
## Steam to publish what was written on it, and until it had, nothing would answer and a clash would look like none.
func _draw_a_code() -> void:
	_draws += 1
	_wanted = String(draw_code.call())
	var resume_browse: bool = _suspend_browse()
	_begin("check")
	_stage_find = _find({"game": GAME_TAG, "code": _wanted}, 1, "stage")
	if resume_browse:
		_resume_browse()


## JOIN BY CODE: read what was typed, find the one lobby holding it, check it will have us, enter it, and connect.
func join_code(typed: String) -> void:
	# THE VALIDATOR FIRST, and nothing is asked of any directory about a code it refuses.
	var why: String = JoinCode.why_not(typed)
	if why == "":
		why = lobbies.unavailable() if lobbies != null else "Steam is not in this build."
	if why != "":
		_refuse(why)
		return
	_start_afresh()
	is_host = false
	transport = "steam"
	_wanted = JoinCode.read(typed)
	session_message.emit("Looking for %s…" % JoinCode.spell(_wanted))
	var resume_browse: bool = _suspend_browse()
	_begin("search")
	# TWO, so that two lobbies holding one code are seen as two and refused, rather than the first taken.
	_stage_find = _find({"game": GAME_TAG, "code": _wanted}, 2, "stage")
	if resume_browse:
		_resume_browse()


## ---- Steam, by looking round -------------------------------------------------------------------
##
## Asked for on 2026-09-15: "can you also add a button to look for other players." A code is for a friend who told you
## theirs; this is for a player with nobody to ask. The same search the code join makes, with the code filter left off:
## every lobby wearing this game's tag, whoever opened it.
##
## IT IS ONLY POSSIBLE BECAUSE THE LOBBY IS PUBLIC. `SteamLobbyDirectory` opens a PUBLIC lobby so that invites and a
## friend's Join Game work (2026-09-14), and Steamworks returns a public lobby from any search -- so this needed no
## change to what a host writes down. A FRIENDS_ONLY lobby would be invisible here, and an invisible one has no Join
## Game; there is no lobby type that hides a game from this list and keeps the rest.
##
## EVERY GAME IS LISTED, INCLUDING THE ONES YOU CANNOT JOIN, each with the reason in place of its JOIN. A friend a
## release behind is somebody to talk to about the release they are behind on; a game silently missing from the list is
## a bug report about a list that does not work.


## LOOK FOR OTHER PLAYERS: every cockpit game Steam knows of, answered through `games_listed`.
##
## Refused while a session is up, because joining one of these leaves this one -- and this is announced, not acted on,
## so nothing here ends a session the player has not chosen to leave.
func look_for_games() -> void:
	var why: String = lobbies.unavailable() if lobbies != null else "Steam is not in this build."
	if why == "" and is_in_session:
		why = "Leave this game before looking for another."
	if why != "":
		_stop_looking(why)
		return
	session_message.emit("Asking Steam who is playing…")
	if _browse_find != 0:
		_cancel_find(_browse_find)
	_browse_until = 0x7FFFFFFFFFFFFFFF
	_browse_find = _find({"game": GAME_TAG}, MOST_LISTED, "browse")


## JOIN A GAME OFF THE LIST. The list carried a lobby, not a code: two games could hold one code and a search for it
## would refuse both (`_check_the_lobby`), where a row on a screen is one lobby a player has pointed at. Every check a
## typed code makes is made here, on the lobby the row named.
func join_game(which: int) -> void:
	var why: String = lobbies.unavailable() if lobbies != null else "Steam is not in this build."
	if why != "":
		_refuse(why)
		return
	_start_afresh()
	is_host = false
	transport = "steam"
	_wanted = JoinCode.read(lobbies.read(which, "code"))
	session_message.emit("Joining %s…" % JoinCode.spell(_wanted) if _wanted != "" else "Joining that game…")
	# The checks and the deadline on entering are `_check_the_lobby`'s, which is the same door a typed code goes through.
	_check_the_lobby([which])


## THE LOOK ROUND IS OVER WITH NOTHING TO SHOW, and why. The list goes empty rather than stale: a screen still showing
## the games of ten minutes ago is a screen offering games that have ended.
func _stop_looking(words: String) -> void:
	_cancel_find(_browse_find)
	_browse_find = 0
	session_message.emit(words)
	games_listed.emit([])


func _suspend_browse() -> bool:
	if _browse_find == 0:
		return false
	_cancel_find(_browse_find)
	_browse_find = 0
	return true


func _resume_browse() -> void:
	_browse_until = 0x7FFFFFFFFFFFFFFF
	_browse_find = _find({"game": GAME_TAG}, MOST_LISTED, "browse")


## WHAT STEAM ANSWERED A LOOK ROUND WITH, as rows to draw: one Dictionary a lobby, with
##   `lobby` the id a JOIN names, `code` as `JoinCode` reads it (or ""), `level` its id and `level_name` its title (or
##   the raw id, for a level this game does not have), `players` and `most` the machines in it and its limit, and `why`
##   the sentence saying it cannot be joined, or "" when it can.
##
## IN THE ORDER THEY ARE TO BE READ: the ones that can be joined first, then the fullest -- a game with three people in
## it is the one somebody looking for players wants -- then by lobby id, so two screens of the same answer agree.
func _read_the_games(matches: Array) -> Array:
	var games: Array = []
	for match_at in matches:
		var which: int = int(match_at)
		var flying: String = lobbies.read(which, "level")
		var chart: LevelChart = ChartDrawer.chart(flying)
		var players: int = lobbies.members(which)
		var most: int = lobbies.limit(which)
		var why: String = _what_is_wrong_with(which)
		if why == "" and most > 0 and players >= most:
			why = "Full."
		games.append({
			"lobby": which,
			"code": JoinCode.read(lobbies.read(which, "code")),
			"level": flying,
			"level_name": chart.name if chart != null else flying,
			"players": players,
			"most": most,
			"why": why,
		})
	games.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var joinable: Array = [String(a["why"]) == "", String(b["why"]) == ""]
		if joinable[0] != joinable[1]:
			return joinable[0]
		if int(a["players"]) != int(b["players"]):
			return int(a["players"]) > int(b["players"])
		return int(a["lobby"]) < int(b["lobby"]))
	return games


## JOIN A LOBBY NOBODY SEARCHED FOR: an invite accepted, or Join Game on a friend's profile (asked for on 2026-09-14,
## beside the code). No search found it, so nothing is known about it until it is entered -- see `_on_entered`, which
## checks every lobby the same way however it was reached.
func join_lobby(invited_to: int) -> void:
	var why: String = lobbies.unavailable() if lobbies != null else "Steam is not in this build."
	if why != "":
		_refuse(why)
		return
	_start_afresh()
	is_host = false
	transport = "steam"
	_wanted = ""
	_knocking = invited_to
	session_message.emit("Joining a friend's game…")
	_begin("enter")
	lobbies.enter(invited_to)


func _on_found(request: int, matches: Array) -> void:
	_find_kinds.erase(request)
	if request == _browse_find:
		_browse_find = 0
		var games: Array = _read_the_games(matches)
		var open_to_us: int = 0
		for game in games:
			open_to_us += 1 if String((game as Dictionary)["why"]) == "" else 0
		session_message.emit("Nobody is hosting over Steam just now." if games.is_empty()
			else "%d game(s), %d you can join." % [games.size(), open_to_us])
		games_listed.emit(games)
		return
	if request != _stage_find:
		return
	_stage_find = 0
	match _stage:
		"check":
			if not matches.is_empty():
				if _draws >= CODE_DRAWS:
					_refuse("Every code drawn was already in use. Try again.")
				else:
					_draw_a_code()
				return
			_begin("open")
			# AS MANY AS THE SESSION TAKES: a Steam lobby that is full refuses the next player in words before they enter it
			# (`tests/steam_join.gd`), so it needs no spare place as the ENet carrier does.
			lobbies.open(session_players)
		"search":
			_check_the_lobby(matches)

func _check_the_lobby(matches: Array) -> void:
	var spelled: String = JoinCode.spell(_wanted)
	if matches.is_empty():
		_refuse("No game has the code %s. Check it with the host." % spelled)
		return
	if matches.size() > 1:
		_refuse("Two games share that code; ask the host to host again.")
		return
	var found: int = int(matches[0])
	var most: int = lobbies.limit(found)
	if most > 0 and lobbies.members(found) >= most:
		_refuse("That game is full (%d of %d)." % [lobbies.members(found), most])
		return
	# CHECKED BEFORE ENTERING when a search found the lobby, because a search result carries its data and a refusal then
	# costs Steam nothing; and again after, in `_on_entered`, because an invite brings no search result to check. Only
	# the written-down facts, though: `_whose_lobby_it_turned_out_to_be` is not askable from out here.
	var wrong: String = _what_is_wrong_with(found)
	if wrong != "":
		_refuse(wrong)
		return
	_knocking = found
	_begin("enter")
	lobbies.enter(found)


## WHY A LOBBY IS NOT A GAME THIS MACHINE CAN JOIN, or "" when it is. EVERYTHING A STRANGER MAY ASK, and nothing else:
## a lobby's written-down facts, which a search result carries. See `_whose_lobby_it_turned_out_to_be` for the question
## that had to be taken out of here, and why nothing that reads a search result may ask it.
func _what_is_wrong_with(which: int) -> String:
	if lobbies.read(which, "game") != GAME_TAG:
		return "That is not a cockpit game."
	if lobbies.read(which, "build") != build():
		return "The host is on a different build."
	if lobbies.read(which, "compatibility") != compatibility():
		return "The host is on an incompatible alpha revision."
	# THE LEVEL, the same questions the hello asks, in the same words.
	var theirs: String = lobbies.read(which, "level")
	var chart: LevelChart = ChartDrawer.chart(theirs)
	if chart == null:
		return "That game is flying %s, a level this game does not have." % theirs
	if chart.content_hash != lobbies.read(which, "level_hash"):
		return "The host's copy of %s is not the same as yours." % chart.name
	return ""


## AND THE ONE QUESTION ONLY A MEMBER MAY ASK, asked once this machine is inside the lobby.
##
## THE HOST WROTE ITSELF DOWN, and Steam hands a lobby to another member when its owner goes, so a lobby whose owner is
## not the host it names is a game whose host has left and whose simulation left with them. That is still the question;
## what changed on 2026-09-15 is WHERE it may be asked.
##
## `getLobbyOwner` ANSWERS 0 TO A MACHINE THAT IS NOT IN THE LOBBY. Steamworks says so -- "You must be a member of the
## lobby to access this" -- and the binary agrees: `tests/steam_probe.gd --strangers` searched App ID 480, which every
## Steamworks developer shares, and asked fifty lobbies this machine was not in. Fifty gave a member limit, fifty a
## member count and forty-four their lobby data; NONE gave an owner. Asked from `_what_is_wrong_with`, which is what a
## search result went through, the comparison was "0" against a seventeen-digit Steam id, so EVERY lobby a search ever
## found was refused -- a typed code and every row of the games list alike. It could not be seen from one account,
## because the machine that made the lobby is in it and is told its owner.
##
## Rejected: having the host write its id somewhere a stranger can read -- it already does, and that is the `host` key
## this compares against; the missing half is who owns the lobby NOW, and only Steam knows that. Rejected too: taking
## the check out altogether, which would fly a joiner into a session whose host had gone. It belongs after entering,
## where `_on_entered` asks it of every join however it arrived, and a refusal there costs one lobby entry.
func _whose_lobby_it_turned_out_to_be(which: int) -> String:
	if str(lobbies.owner(which)) != lobbies.read(which, "host"):
		return "The host has left that game."
	return ""


func _on_opened(made: int, result: int) -> void:
	if _stage != "open":
		return
	if result != LobbyDirectory.OPENED or made == 0:
		_refuse("Steam could not make a lobby (result %d)." % result)
		return
	lobby = made
	lobbies.write(made, "game", GAME_TAG)
	lobbies.write(made, "code", _wanted)
	lobbies.write(made, "build", build())
	lobbies.write(made, "compatibility", compatibility())
	lobbies.write(made, "host", str(lobbies.me()))
	# AND WHICH LEVEL, readable before anybody joins: a search result carries it, so a code join is refused before it
	# enters a game on a level this machine does not have. The hello says it again once inside, however a joiner came.
	var flying: LevelChart = ChartDrawer.chart(level)
	lobbies.write(made, "level", level)
	lobbies.write(made, "level_hash", flying.content_hash if flying != null else "")
	var peer: MultiplayerPeer = lobbies.peer_to_host(made)
	if peer == null:
		_refuse("Steam made a lobby but could not host the game on it.")
		return
	_stage = ""
	multiplayer.multiplayer_peer = peer
	is_in_session = true
	session_code = _wanted
	session_message.emit("Hosting over Steam. Code %s." % JoinCode.spell(session_code))
	session_ready.emit()


func _on_entered(into: int, response: int) -> void:
	if _stage != "enter" or into != _knocking:
		# A YES THAT ARRIVED AFTER WE STOPPED WAITING for it -- the deadline passed, or the player went elsewhere -- is a
		# lobby this machine is now in and nobody wants. Out again at once.
		if response == LobbyDirectory.ENTERED and into != lobby:
			lobbies.leave(into)
		return
	_knocking = 0
	if response != LobbyDirectory.ENTERED:
		_refuse(_why_not_entered(response))
		return
	lobby = into
	# BOTH HALVES, now that this machine is a member: the written-down facts, and the one only a member may ask.
	var wrong: String = _what_is_wrong_with(into)
	if wrong == "":
		wrong = _whose_lobby_it_turned_out_to_be(into)
	if wrong != "":
		_refuse(wrong)
		return
	# An invite knows no code until the lobby says it, and the code is what this player can pass on.
	if _wanted == "":
		_wanted = JoinCode.read(lobbies.read(into, "code"))
	var peer: MultiplayerPeer = lobbies.peer_to_join(into)
	if peer == null:
		_refuse("Steam let you in but could not reach the host.")
		return
	multiplayer.multiplayer_peer = peer
	session_message.emit("Joining %s…" % JoinCode.spell(_wanted))
	_begin("connect")


## What Steam's answer to entering a lobby means to a person, for every answer but yes.
static func _why_not_entered(response: int) -> String:
	if response == LobbyDirectory.DOES_NOT_EXIST:
		return "That game has ended."
	if response == LobbyDirectory.FULL:
		return "That game filled up."
	if response == LobbyDirectory.RATE_LIMITED:
		return "Too many tries; wait a minute."
	return "Steam would not let you in (response %d)." % response


func _begin(stage: String) -> void:
	_stage = stage
	# A Steam lobby search may wait behind another owned request. Its clock begins when
	# LobbyDirectory says it actually owns Steam's single RequestLobbyList slot.
	_stage_until = 0x7FFFFFFFFFFFFFFF if stage in ["check", "search"] else \
		Time.get_ticks_msec() + int(float(patience.get(stage, PATIENCE[stage])) * 1000.0)


## NO, AND WHY: out of whatever was half made, and the reason said last, so it is the line left on the screen.
##
## IN THE BOOK TOO, unless the caller has already written the row with more in it (a refusal's code and builds, a
## deadline's stage): a knock that ended is an event at the door, and the LOG tab is where a player reads it again.
func _refuse(words: String, write: bool = true) -> void:
	parting_words = words
	# SAID WHERE A HARNESS READS IT as well, since a joiner turned away after its connection came up is past the point
	# `boot` prints BOOT_ERROR= for (`tests/players_peers.gd`, the session that is full).
	_report("NET_PARTED words=%s" % words)
	if write:
		logbook.write("PARTED", "host" if is_host else "client", {"who": _where_to(), "words": words})
	leave(words)
	session_message.emit(words)


## A SESSION ENDED FROM OUTSIDE IT, with the words the player is to read wherever they are taken: the host gone, a
## joiner refused after it had loaded, a level whose edge will not fit. The flight level takes the player back to
## the desk on it, and the desk says the words.
func refuse_the_session(words: String) -> void:
	_refuse(words)


func host(port: int = usual_port) -> void:
	suit_the_session(true)
	var refused: String = host_refusal()
	if refused != "":
		_refuse(refused)
		return
	_start_afresh()
	_start_the_sky()
	var peer := ENetMultiplayerPeer.new()
	# ENet counts the peers that are not the host: `session_players` of them is every joiner the session takes and one
	# more, who is told in words that it is full (`_on_peer_arrived`). A server at the cap turned the 65th away unsaid.
	var err: int = peer.create_server(port, session_players)
	if err != OK:
		session_message.emit("Could not listen on %d: %s" % [port, error_string(err)])
		return
	multiplayer.multiplayer_peer = peer
	is_host = true
	is_in_session = true
	transport = "enet"
	session_message.emit("Hosting on port %d." % port)
	session_ready.emit()


func join(address: String = "127.0.0.1", port: int = usual_port) -> void:
	_start_afresh()
	var peer := ENetMultiplayerPeer.new()
	_wanted = ""
	_where = "%s:%d" % [address, port]
	logbook.write("CONNECTING", "client", {"who": _where, "client": identity()["line"]})
	var err: int = peer.create_client(address, port)
	if err != OK:
		_refuse("Could not connect to %s: %s." % [_where, error_string(err)])
		return
	multiplayer.multiplayer_peer = peer
	is_host = false
	transport = "enet"
	# A DEADLINE OF ITS OWN, here and not at the desk: ENet against a port nothing holds sits in CONNECTING for ever and
	# never fails (working_with_godot.md), so without it a join from any door but the desk's waited for ever unsaid.
	_begin("connect")
	session_message.emit("Connecting to %s…" % _where)


func _on_connected() -> void:
	if _stage == "connect":
		session_code = _wanted
	# CONNECTED IS NOT IN THE SESSION: this machine says which build it is, and the host says which level it is flying
	# if the build is its own. See "THE HANDSHAKE" and "THE HELLO".
	_begin("hello")
	_hi_next = 0
	logbook.write("CONNECTED", "client", {"who": _where_to()})
	session_message.emit("Connected. Asking the host which level...")


func _on_connection_failed() -> void:
	# EVERY WAY IN ENDS IN WORDS: a failure outside the connect stage used to say "Could not reach the host." and
	# leave the half-open session standing.
	_refuse("Could not reach %s: the connection failed." % _where_to())


## THE HOST WENT AWAY WITHOUT A REFUSAL: it crashed, the network dropped, or it is a build older than the one that says
## why it closes. Said as exactly that, since "Host left" read as though the host had said something.
func _on_host_gone() -> void:
	var words: String = "Lost the host at %s without a reason: it may have crashed or quit, or the network dropped." \
		% _where_to()
	logbook.write("DROPPED", "client", {"who": _where_to(), "words": words})
	refuse_the_session(words)


## WHERE THIS MACHINE IS KNOCKING, in words: the address over ENet, the code over Steam, or "the host".
func _where_to() -> String:
	if _where != "":
		return _where
	if _wanted != "":
		return "game %s" % JoinCode.spell(_wanted)
	return "the host"


## WHAT A STAGE SAYS WHEN ITS DEADLINE PASSES: `TOO_LONG`'s words, with the address and the seconds for the two that
## wait on a host. The user: "the client MUST know why (if possible), it couldn't connect."
func too_long(stage: String) -> String:
	var seconds: float = float(patience.get(stage, PATIENCE.get(stage, 0.0)))
	if stage == "connect":
		return connect_words(_where_to(), seconds, transport == "steam")
	if stage == "hello":
		return "Connected to %s, but the host said nothing for %s s: it may be a much older build, or stuck." % [
			_where_to(), _seconds(seconds)]
	return String(TOO_LONG.get(stage, "Gave up waiting."))


## SECONDS AS A PERSON WRITES THEM: 10 s, 0.3 s.
static func _seconds(seconds: float) -> String:
	return str(roundi(seconds)) if is_equal_approx(seconds, roundf(seconds)) else String.num(seconds, 1)


## A CONNECTION NOBODY ANSWERED, in words: where, how long, and what it may mean -- which differs by carrier, since a
## Steam join has no address to have typed wrong. Static, so a suite asks for the sentence rather than typing it again.
static func connect_words(where: String, seconds: float, steam: bool) -> String:
	if steam:
		return "No answer from the host of %s after %s s: it may have gone, or Steam could not reach it." % [where,
			_seconds(seconds)]
	return "No answer from %s after %s s: the host may be down, the address wrong, or a firewall in the way." % [where,
		_seconds(seconds)]


func leave(reason: String = "left") -> void:
	_start_afresh()
	is_host = false
	is_in_session = false
	transport = "none"
	session_ended.emit(reason)


## Nothing half done left behind: no peer, no lobby, no stage waiting on an answer, no code.
func _start_afresh() -> void:
	session_epoch += 1
	session_reset.emit(session_epoch)
	_clear_peer()
	_cancel_find(_stage_find)
	_stage_find = 0
	_stage = ""
	session_code = ""
	_knocking = 0
	if lobby != 0 and lobbies != null:
		lobbies.leave(lobby)
	lobby = 0
	admitted.clear()
	_telling.clear()
	_greeting.clear()
	_refusal_said.clear()
	_their_line.clear()
	_their_built.clear()
	_joined.clear()
	_addresses.clear()
	_hi_next = -1
	_where = ""
	_built_here = false
	_ground_here = ""
	_loaded_next = -1
	held_back = 0
	_sending_away.clear()
	said_to.clear()
	_sky_owed.clear()
	_sky_heard = -1
	_music_owed.clear()
	_music_heard = -1
	_music_version = 0
	music_state = empty_music_state()
	_notice_owed.clear()
	_notice_heard = -1
	_notice_version = 0
	_called = {}
	_players.clear()
	notice = {}
	roster.clear()
	_cards_by_peer.clear()
	_roster_version = 0
	chat_log.clear()
	_chat_version = 0
	_chat_taken.clear()
	_chat_owed_at.clear()
	_chat_from.clear()
	_chat_outbox.clear()
	_chat_said = 0
	_chat_next = 0
	_chat_heard_to = 0
	talking = []
	_talking_since.clear()
	_talking_version = 0
	_talking_owed.clear()
	_talking_heard = -1
	_voice_said = 0
	_teams_by_client.clear()
	_roster_owed.clear()
	_roster_pages_heard.clear()
	_roster_parts.clear()
	_roster_heard = -1
	_card_next = 0 if not is_host else -1
	_card_heard = false
	_long.clear()
	_long_pump_deferred = false
	_send_in_flight.clear()
	_receive_in_flight.clear()


func _find(wanted: Dictionary, most: int, kind: String) -> int:
	_next_find += 1
	_find_kinds[_next_find] = kind
	lobbies.find(_next_find, wanted, most)
	return _next_find


func _cancel_find(request: int) -> void:
	if request == 0:
		return
	_find_kinds.erase(request)
	if lobbies != null:
		lobbies.cancel_find(request)


func _on_find_started(request: int) -> void:
	var kind: String = String(_find_kinds.get(request, ""))
	if kind == "browse":
		_browse_until = Time.get_ticks_msec() + int(float(patience.get("browse", PATIENCE["browse"])) * 1000.0)
	elif kind == "stage":
		_stage_until = Time.get_ticks_msec() + int(float(patience.get(_stage, PATIENCE[_stage])) * 1000.0)


func _clear_peer() -> void:
	# A HOST CLOSING SAYS SO to everybody still on its socket, and pushes it out before the socket goes: `poll` is what
	# sends what is queued, and `close` drops the queue. Best effort -- a crash says nothing -- and a client that hears
	# nothing says it lost the host without a reason (`_on_host_gone`).
	if is_host and is_networked() and not multiplayer.get_peers().is_empty():
		var closing: String = refusal_words("host_closed", identity()["line"], "", "")
		logbook.write("CLOSED", "host", {"code": "host_closed", "words": "%d still connected" %
			multiplayer.get_peers().size()})
		for peer in multiplayer.get_peers():
			_send_now(peer, JSON.stringify({"say": "refused", "code": "host_closed", "why": closing,
				"host": identity()["line"], "client": String(_their_line.get(peer, ""))}).to_utf8_buffer(),
				HELLO_BITS, "hello")
		multiplayer.multiplayer_peer.poll()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null


## WHICH RPC CARRIES SYNC'S BYTES over a transport. One question, one predicate, so a test can ask it and the send
## cannot disagree with the answer: over Steam the unreliable one, and over ENet the ordered one every measurement in
## this file and in agents.md was taken on.
static func carrier_for(which_transport: String) -> StringName:
	return &"_receive_unordered" if which_transport == "steam" else &"_receive"


## Packets handed to each carrier, by the carrier's name. The real path's evidence that a Steam session's packets go
## where `carrier_for` says.
var carried: Dictionary = {}


## Server to one client. Checked against the live peer list rather than just "are we
## networked": sync goes on sending to a client for a moment after it disconnects, because
## it finds out on its own schedule, and an rpc_id to a departed peer is an error every
## frame until it does.
func send_to(peer: int, bytes: PackedByteArray, bits: int) -> void:
	# SYNC'S BYTES ONLY. A bit count below one is Net's own hello on the same carriers ("THE HELLO"), and the other end
	# would read a sync packet sent so as one: refused here, and tests/lint.gd fails any other script that sends one.
	if bits < 1:
		push_error("[net] a sync packet of %d bits is not sent: below one is the hello's" % bits)
		return
	if is_networked() and peer in multiplayer.get_peers():
		_count_sent(peer, bytes.size())
		_carry(peer, bytes, bits, "sync")


func send_to_server(bytes: PackedByteArray, bits: int) -> void:
	# SYNC'S BYTES ONLY. A bit count below one is Net's own hello on the same carriers ("THE HELLO"), and the other end
	# would read a sync packet sent so as one: refused here, and tests/lint.gd fails any other script that sends one.
	if bits < 1:
		push_error("[net] a sync packet of %d bits is not sent: below one is the hello's" % bits)
		return
	if is_networked():
		_count_sent(1, bytes.size())
		_carry(1, bytes, bits, "sync")


## THE CARRIERS TAKE THREE KINDS OF PACKET, told apart by the bit count: sync's, one bit or more, Net's hellos at
## `HELLO_BITS`, and bounded documents at `LONG_BITS`. `_arrived` routes them by the same test.
func _carry(peer: int, bytes: PackedByteArray, bits: int, category: String = "sync") -> void:
	if extra_latency_ms > 0:
		_send_in_flight.append({"due": Time.get_ticks_msec() + extra_latency_ms,
			"peer": peer, "bytes": bytes, "bits": bits, "category": category})
		return
	_send_now(peer, bytes, bits, category)


func _send_now(peer: int, bytes: PackedByteArray, bits: int, category: String) -> void:
	# A peer can leave while its packet waits. An RPC to it is an engine error, so the same
	# live-peer gate as the public callers is repeated at the actual send edge.
	if not is_networked() or peer not in multiplayer.get_peers():
		return
	# Selective repeat needs late chunks. ENet's unreliable-ordered carrier discards those once a
	# newer packet has arrived, so long documents use the already-existing unordered RPC on both transports.
	var carrier: StringName = &"_receive_unordered" if bits == LONG_BITS else carrier_for(transport)
	carried[carrier] = int(carried.get(carrier, 0)) + 1
	_count_traffic(traffic_sent, category, peer, bytes.size())
	if carrier == &"_receive_unordered":
		_receive_unordered.rpc_id(peer, bytes, bits)
	else:
		_receive.rpc_id(peer, bytes, bits)


## WHAT THE SOCKET CARRIED, counted at the last place a packet is ours to count and the first place one arrives.
## sync's own `packets_missing` is a gap in its packet numbers, which is not the same question: a joined machine read
## 10,134 missing against 2,095 received and still drew most of the sky, so the transport is asked directly.
## peer -> [packets, bytes, largest]
var sent: Dictionary = {}
var received: Dictionary = {}
## category -> peer -> [packets, bytes, largest], so a load run can separate simulation,
## handshake and background-document traffic without estimating from payload contents.
var traffic_sent: Dictionary = {"sync": {}, "hello": {}, "long": {}}
var traffic_received: Dictionary = {"sync": {}, "hello": {}, "long": {}}


func _count_sent(peer: int, size: int) -> void:
	var row: Array = sent.get(peer, [0, 0, 0])
	sent[peer] = [int(row[0]) + 1, int(row[1]) + size, maxi(int(row[2]), size)]


func _count_traffic(table: Dictionary, category: String, peer: int, size: int) -> void:
	var category_rows: Dictionary = table.get(category, {})
	var row: Array = category_rows.get(peer, [0, 0, 0])
	category_rows[peer] = [int(row[0]) + 1, int(row[1]) + size, maxi(int(row[2]), size)]
	table[category] = category_rows


## unreliable_ordered, and that is not laziness: sync already acks, resends and reorders
## what it cares about, so a reliable channel underneath would add head-of-line blocking
## and hide the packet loss its bandwidth control is measuring.
##
## `bits` travels with the bytes because a BitBuffer is bit-addressed -- its last byte is
## usually partial, and a buffer rebuilt from bytes alone leaves the reader believing
## there are up to seven bits of real data past the end of the packet. It decodes those as
## garbage, runs off the end, and takes the process down with no Godot error at all.
##
## OVER ENET ONLY. Over Steam this mode would be reliable -- see `_receive_unordered`.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _receive(bytes: PackedByteArray, bits: int) -> void:
	_queue_arrival(multiplayer.get_remote_sender_id(), bytes, bits)


## AND UNRELIABLE, OVER STEAM. Read in GodotSteam v4.21-gde's own source, godotsteam_multiplayer_peer.cpp:721-723:
## TRANSFER_MODE_UNRELIABLE_ORDERED is sent `k_nSteamNetworkingSend_Reliable`, commented "No equivalent" -- exactly the
## head-of-line blocking the comment on `_receive` rules out -- while UNRELIABLE is sent Unreliable.
##
## WHAT UNRELIABLE COSTS, MEASURED. Valve's isteamnetworkingsockets.h: unreliable messages "may be dropped, or delivered
## out of order ... The same unreliable message may be received multiple times." ashiato-gd/addon/tests/crowd_shuffled.gd
## flew crowd_sight's 80-autopilot sky over its 4-tick link (2026-09-14): with one packet in twenty swapped, dropped or
## delivered twice the sky was spotless -- 0 steps in 95,920 craft-ticks, every missile and every missile end -- because
## sync files an update at its own frame. Only a pathological link stepped it: every other packet swapped, 20,605 steps
## (3,840 on the same delays held in order); every other packet dropped, a 325-tick leap and missiles lost. So no
## sequence guard here: at one in twenty, a guard that dropped stragglers measured no better than delivering them.
@rpc("any_peer", "call_remote", "unreliable")
func _receive_unordered(bytes: PackedByteArray, bits: int) -> void:
	_queue_arrival(multiplayer.get_remote_sender_id(), bytes, bits)


func _queue_arrival(from_peer: int, bytes: PackedByteArray, bits: int) -> void:
	if extra_latency_ms > 0:
		_receive_in_flight.append({"due": Time.get_ticks_msec() + extra_latency_ms,
			"peer": from_peer, "bytes": bytes, "bits": bits})
		return
	_arrived(from_peer, bytes, bits)


func _flush_in_flight() -> void:
	var now := Time.get_ticks_msec()
	var send_left: Array[Dictionary] = []
	for packet in _send_in_flight:
		if now >= int(packet["due"]):
			_send_now(int(packet["peer"]), packet["bytes"], int(packet["bits"]), String(packet["category"]))
		else:
			send_left.append(packet)
	_send_in_flight = send_left
	var receive_left: Array[Dictionary] = []
	for packet in _receive_in_flight:
		if now >= int(packet["due"]):
			_arrived(int(packet["peer"]), packet["bytes"], int(packet["bits"]))
		else:
			receive_left.append(packet)
	_receive_in_flight = receive_left


func _arrived(from_peer: int, bytes: PackedByteArray, bits: int) -> void:
	if bits == LONG_BITS:
		_count_traffic(traffic_received, "long", from_peer, bytes.size())
		_long.receive(from_peer, bytes, Time.get_ticks_msec(), _may_receive_long, _validate_long_payload)
		return
	if bits == VOICE_BITS:
		_count_traffic(traffic_received, "voice", from_peer, bytes.size())
		_hear_a_voice_frame(from_peer, bytes)
		return
	# NET'S OWN, NEVER SYNC'S: a hello. See "THE HELLO".
	if bits == HELLO_BITS:
		_count_traffic(traffic_received, "hello", from_peer, bytes.size())
		hear_hello(from_peer, bytes)
		return
	if bits < 0:
		push_warning("[net] a packet with unknown negative bit count %d; dropped" % bits)
		return
	# THE HOST'S SIMULATION HAS ARRIVED, so it has taken this machine in: "loaded" has been heard.
	if _loaded_next >= 0 and from_peer == 1:
		_loaded_next = -1
	var row: Array = received.get(from_peer, [0, 0, 0])
	received[from_peer] = [int(row[0]) + 1, int(row[1]) + bytes.size(), maxi(int(row[2]), bytes.size())]
	_count_traffic(traffic_received, "sync", from_peer, bytes.size())
	packet_arrived.emit(from_peer, bytes, bits)


func _may_receive_long(peer: int, kind: StringName) -> bool:
	if bool(LongTransfer.KINDS.get(kind, {}).get("host_only", false)):
		return not is_host and peer == 1
	return (not is_host and peer == 1) or (is_host and admits(peer))


func _validate_long_payload(kind: StringName, bytes: PackedByteArray) -> bool:
	return not long_validators.has(kind) or bool((long_validators[kind] as Callable).call(bytes))

## ---- THE HELLO: WHICH LEVEL, BEFORE ANY SIMULATION -----------------------------------------------------------------
##
## Asked for on 2026-09-15: "a joiner learns the host's level before its simulation starts, loads it, and only then
## begins receiving and predicting." Static collision is not replicated -- every machine builds a level's ground from its
## own files -- so a joiner on another level predicts itself through ground the server does not have. Until this nothing
## told a joiner anything: peers agreed on a world only by running one build (cockpit-terrain, 2026-09-14).
##
## THREE MESSAGES, UTF-8 JSON, ON THE CARRIERS SYNC'S PACKETS ALREADY RIDE, told apart from sync's by a bit count below
## zero. Sync never sends a packet of no bits, and no byte value inside a sync packet could be reserved instead, because
## its first bits are data.
##
##   host -> joiner   {"say": "level", "protocol", "level", "hash", "name"}   again every 200 ms until answered
##   joiner -> host   {"say": "loaded", "protocol", "level", "hash", "ground"}  again every 200 ms until admitted
##   host -> joiner   {"say": "admitted"}                                      to every "loaded", however often it comes
##   host -> joiner   {"say": "refused", "why"}                                a joiner whose ground differs, closed 0.5 s after
##   joiner -> host   {"say": "refused", "why"}                                once, on the way out
##
## LOST AND SLOW ARE BOTH ORDINARY (team-lead, 2026-09-15). A Steam session's carrier is unreliable, and a ground
## takes seconds to stand, so every message that needs an answer is said again until it has one: the level until
## "loaded", "loaded" until "admitted" (or the host's simulation, which only an admitted joiner is sent), and
## "admitted" again for every "loaded" heard. "ground" is the hash of the height fields the joiner's worlds stand on,
## Box3D's own and the same on both editors (cockpit-terrain): the level file cannot say that the function that makes
## its ground changed under one build, and this does.
##
## A JOINER IS NOT IN THE SESSION until the level it is told is one it has, with the same hash (`why_not_the_level`): the
## stage "hello", with its own deadline. THE HOST HOLDS BACK every sync packet from a peer until that peer has said
## "loaded" (`admits`, asked by `Sim._on_packet`), so sync never makes, seats or simulates a joiner still building.
##
## Rejected: a third Godot RPC, which lint refuses and which would be a second ordering model beside sync's; sync's own
## connect token, which travels joiner to host only, so a joiner could not learn a level before building one, and a
## refusal would need C++; and a Steam lobby's data alone, which ENet does not have. Said again until answered rather than
## sent reliably, because a Steam session's carrier is unreliable, and a lost hello must not become a join that never ends.

## The host's: every peer let into the simulation, peer -> the Unix time it said its level was loaded.
var admitted: Dictionary = {}
## The host's: sync packets held back from peers not yet admitted, this session. Evidence for a harness.
var held_back: int = 0
## The host's: peer -> when to say the level to it again, until it answers.
var _telling: Dictionary = {}
## The joiner's: when to say "loaded" again, or -1 when it is not being said.
var _loaded_next: int = -1
## WHETHER THIS MACHINE HAS BUILT THE LEVEL IT IS ON. False from the moment a session starts or its level changes, true
## when the flight level says so (`level_loaded`). A host answers nobody's `loaded` before it is true: see `change_level`.
var _built_here: bool = false
## This machine's ground hash, as its level last built it: what a host checks a joiner's against.
var _ground_here: String = ""
## The host's: peer -> when to close a joiner it has refused, if the joiner has not gone by then.
var _sending_away: Dictionary = {}
## The host's: peer -> the refusal it is being told, said again every `HELLO_EVERY_MSEC` until it goes.
var _refusal_said: Dictionary = {}
## THE LONGEST A REFUSED JOINER IS LEFT CONNECTED, milliseconds. The refusal is said again every 200 ms until then, and a
## joiner that hears it leaves at once -- its going IS the acknowledgement -- so on a live link this is never reached.
## It was a flat 500 ms with the refusal said once (seats step 3), which a lost packet turned into "Host left".
const SENDING_AWAY_MSEC: int = 3000
## THE LAST THING SAID TO EACH PEER, by its `say`: evidence for a suite, since a peer that is not there is told nothing.
var said_to: Dictionary = {}


## ---- THE HANDSHAKE: WHICH BUILD, BEFORE WHICH LEVEL -------------------------------------------------------------------
##
## Asked for on 2026-09-18, the day the game got release builds: "we need to reject connections from clients that are
## not running the same version ... The server should tell the client explicitly that it can't connect for some reason,
## 'too many players', 'wrong version number', etc. It should INCLUDE the version number of the server and client in the
## message. It's REALLY important that a client (and the server) know why they can't play together."
##
##   joiner -> host   {"say": "hi", "protocol", "commit", "line", "built"}   its FIRST word, again every 200 ms until
##                                                                            answered
##   host -> joiner   {"say": "level", ..., "built"}                 only once the hi has passed (see "THE HELLO")
##   host -> joiner   {"say": "refused", "code", "why", "host", "client"}   again every 200 ms until the joiner goes
##
## THE RULE: the same PROTOCOL and the same COMMIT. `BuildPlate` is the one answer to "which build am I" and the commit is
## its sharpest part: a release's version and name are labels for the commit it was exported from, so two releases of
## one version from different commits are different builds and are refused, a dev run meets a dev run only on the same
## commit, and a release meets a dev run of the SAME commit (the same code; what is in the pck is what is in the
## checkout). "unknown" -- a checkout with no readable `.git` -- matches nothing, because it cannot say what it is. The
## LINE is shown and never compared.
##
## AND WHO NEEDS TO UPDATE (2026-09-19, from a player: "put the current date into the build id that you check with the
## server so you can say who needs to update"). `built` is `BuildPlate.time()`, epoch seconds UTC, and it DECIDES
## NOTHING: the rule above is the rule. It is said so both sides can be told how far apart they are -- "Yours is 3 days
## older than the host's: update yours" -- in the refusal (`update_words`), on the host's LOG row for a greeting, in the
## joiner's "Connected" line, and per player on the CREW page (each roster card carries its player's, which the host
## heard in that player's hi). A joiner whose hi has no `built` (protocol 36 and before) is refused on its protocol
## and told it is the older build, which the protocol numbers alone can say. See `BuildPlate` for where the time comes
## from, and why a dev run's is its commit's.
##
## WHERE THE CHECK SITS: before the level is named, so a refused joiner has built nothing and been told nothing about
## the session, and before `admits`, which is what holds a peer's sync packets away from the simulation -- a peer is only
## put in `_telling` once its hi passes, and `_heard_loaded` answers nobody who is not there. A joiner that never says hi
## (an older build: every build before protocol 26) is told so after `HI_WAIT_MSEC`, in the `refused` it already reads.
##
## RELIABLE WITHOUT A RELIABLE CHANNEL: the carriers are unordered or unreliable (Steam), and lint allows no third RPC, so
## a refusal is said again every 200 ms until the joiner leaves -- which it does the moment it hears one -- or
## `SENDING_AWAY_MSEC` passes and the host closes it. Said first, closed after: the other order is a client that learns
## only that the host went away (`tests/handshake_peers.gd`'s mutant B).

## How long a connected peer has to say hi before it is told it is too old to, milliseconds. A joiner says it the frame
## its connection comes up; the rest is room for a loaded machine and a `--latency=` link.
const HI_WAIT_MSEC: int = 5000
## The longest a build line may be, as a joiner's is kept. A release line is about 40 letters.
const LINE_MOST: int = 64
## THE CODES A REFUSAL CARRIES, one each, so a log can be grepped and a page coloured by them; the words are the host's.
const REFUSALS: Array[String] = ["wrong_version", "wrong_protocol", "full", "bad_hello", "no_hello", "wrong_level",
	"wrong_ground", "host_closed"]

## EVERY KNOCK AT THE DOOR AND WHAT BECAME OF IT. See `Logbook`; the clipboard's LOG tab draws it.
var logbook := Logbook.new()
## The host's: peer -> by when it must say hi, for every peer connected and not yet heard.
var _greeting: Dictionary = {}
## The host's: peer -> the build line it said, once its hi has been read, for the log and for a later refusal's words.
var _their_line: Dictionary = {}
## The host's: peer -> when its build was made, as its hi said (0 for unknown), for its roster card.
var _their_built: Dictionary = {}
## The host's: every peer that has joined this session, so a level change's re-admission is not logged as a join.
var _joined: Dictionary = {}
## The host's: peer -> the address it connected from, kept until it has gone and its LEFT row is written.
var _addresses: Dictionary = {}
## The joiner's: when to say hi again, or -1 when it is not being said.
var _hi_next: int = -1
## Where this machine is knocking, "127.0.0.1:7788", for a client's words; "" when not joining over ENet.
var _where: String = ""
## THE BUILD A SUITE MAKES THIS PROCESS PRETEND TO BE: `--pretend-build=<commit>|<line>`, `--pretend-protocol=N` and
## `--pretend-built=<epoch>` (or `none`, a hi with no time) after the bare `--`. For `tests/handshake_peers.gd`, which
## needs several builds and has one checkout. Empty in every real run.
## `silent` (set by that suite in its own process) says no hi at all: a build from before the hi, as the host sees one.
var _pretend: Dictionary = {}


## WHICH BUILD THIS MACHINE IS, as the handshake says it: {protocol, commit, line, built}. `BuildPlate` answers, unless a
## suite has made this process pretend. `built` is -1 only for a suite pretending to be a build from before it existed.
func identity() -> Dictionary:
	return {
		"protocol": int(_pretend.get("protocol", PROTOCOL)),
		"commit": String(_pretend.get("commit", BuildPlate.commit())),
		"line": String(_pretend.get("line", BuildPlate.line())),
		"built": int(_pretend.get("built", BuildPlate.time())),
	}


## WHY TWO BUILDS CANNOT PLAY TOGETHER, or {} when they can: {code, words}. Pure, over two `identity()`s, so a suite puts
## every pair through it without a socket and the host cannot disagree with it.
static func why_not_the_build(host: Dictionary, client: Dictionary) -> Dictionary:
	var host_line: String = String(host.get("line", ""))
	var client_line: String = String(client.get("line", ""))
	if int(host.get("protocol", -1)) != int(client.get("protocol", -2)):
		return {"code": "wrong_protocol", "words": refusal_words("wrong_protocol", host_line, client_line,
			"%d|%d" % [int(host.get("protocol", -1)), int(client.get("protocol", -2))], update_words(host, client))}
	var host_commit: String = String(host.get("commit", "unknown"))
	var client_commit: String = String(client.get("commit", "unknown"))
	if host_commit == "unknown" or client_commit == "unknown" or host_commit != client_commit:
		return {"code": "wrong_version", "words": refusal_words("wrong_version", host_line, client_line, "",
			update_words(host, client))}
	return {}


## WHO NEEDS TO UPDATE, in a sentence to the JOINER: "Yours is 3 days older than the host's: update yours.", or "You both
## need the same build." when nothing can say which. From the two build times when both are known and a minute or more apart (`BuildPlate.age_words`);
## otherwise from the two protocols, since a lower protocol is an older build whatever it says about its time -- which
## is how a joiner from before `built` existed is still told it is the one behind.
static func update_words(host: Dictionary, client: Dictionary) -> String:
	var age: String = BuildPlate.age_words(int(client.get("built", 0)), int(host.get("built", 0)))
	var host_protocol: int = int(host.get("protocol", -1))
	var client_protocol: int = int(client.get("protocol", -1))
	var older: bool = age.ends_with("older") if age != "" else client_protocol < host_protocol
	if age == "" and client_protocol == host_protocol:
		return "You both need the same build."
	var fix: String = "update yours." if older else "the host needs to update."
	if age != "":
		return "Yours is %s than the host's: %s" % [age, fix]
	return "Yours is the %s build: %s" % ["older" if older else "newer", fix]


## A REFUSAL IN WORDS A PLAYER READS, and EVERY ONE NAMES BOTH BUILDS: the user asked for exactly that. `detail` is what
## only that refusal knows -- the two protocols, the count, what was wrong with a hello. `client_line` is "" only when the
## joiner never said one, and the words say so rather than printing a blank. `update` is `update_words` for the two
## refusals about the build, and takes the place of "You both need the same build." when it can say who.
static func refusal_words(code: String, host_line: String, client_line: String, detail: String,
		update: String = "") -> String:
	var yours: String = client_line if client_line != "" else "a build that did not say which it is"
	var builds: String = "This game is %s; you're running %s." % [host_line, yours]
	var same: String = update if update != "" else "You both need the same build."
	match code:
		"wrong_version":
			return "Can't join: this game is %s, and you're running %s. %s" % [host_line, yours, same]
		"wrong_protocol":
			var p: PackedStringArray = detail.split("|")
			return "Can't join: this game speaks network protocol %s (%s), and yours speaks %s (%s). %s" \
				% [p[0], host_line, p[1] if p.size() > 1 else "?", yours, same]
		"full":
			return "Can't join: the session is full (%s players). %s" % [detail, builds]
		"bad_hello":
			return "Can't join: your game's hello could not be read (%s). %s" % [detail, builds]
		"no_hello":
			return "Can't join: your game never said which build it is, so it is older than this one (%s). " % host_line \
				+ "Update yours."
		"host_closed":
			return "The host closed the game (%s)." % host_line
	return "Can't join: %s %s" % [detail, builds]


## A PEER HAS SAID HI, on the host. It is let on to hear the level only if its build is this one's and there is room.
func _heard_hi(peer: int, said: Dictionary) -> void:
	if not _greeting.has(peer):
		# SAID AGAIN: a hi repeats until the level hello reaches it, and one already answered is answered already.
		return
	_greeting.erase(peer)
	var theirs: Dictionary = {"protocol": int(said["protocol"]), "commit": String(said["commit"]),
		"line": String(said["line"]), "built": int(said["built"])}
	_their_line[peer] = theirs["line"]
	_their_built[peer] = theirs["built"]
	var wrong: Dictionary = why_not_the_build(identity(), theirs)
	if wrong.is_empty():
		# A FULL SESSION, counted in peers past their hi: the ones being told the level and the ones in. A peer still
		# knocking holds a socket, not a place, so two knocking at once for the last place do not both lose it.
		var taken: int = 1 + _telling.size() + admitted.size()
		if taken >= session_players:
			wrong = {"code": "full", "words": refusal_words("full", identity()["line"], theirs["line"],
				"%d of %d" % [taken, session_players])}
	if not wrong.is_empty():
		_send_away(peer, String(wrong["code"]), String(wrong["words"]))
		return
	# AND HOW FAR APART THE TWO BUILDS ARE, when they are: one commit exported twice, or a release beside a dev run of it.
	var greeted: Dictionary = {"peer": peer, "who": _who(peer), "client": theirs["line"]}
	var age: String = BuildPlate.age_words(int(theirs["built"]), int(identity()["built"]))
	if age != "":
		greeted["build"] = "theirs is %s than this one" % age
	logbook.write("GREETED", "host", greeted)
	_telling[peer] = 0
	# A peer connecting during a called transition gets the cue before it has finished the level handshake. Waiting
	# until admission can be too late for a short remaining countdown; the cue is content-hash checked by the receiver.
	if not _called.is_empty() and notice.get("kind") == "level":
		_notice_owed[peer] = 0


## TURN A PEER AWAY, on the host: written in the book, said now, said again until it goes, closed if it will not.
func _send_away(peer: int, code: String, words: String) -> void:
	_greeting.erase(peer)
	_telling.erase(peer)
	var said: Dictionary = {"say": "refused", "code": code, "why": words, "host": identity()["line"],
		"client": String(_their_line.get(peer, ""))}
	logbook.write("REFUSED", "host", {"code": code, "peer": peer, "who": _who(peer), "host": said["host"],
		"client": said["client"], "words": words})
	_hello(peer, said)
	_refusal_said[peer] = said.merged({"next": Time.get_ticks_msec() + HELLO_EVERY_MSEC})
	_sending_away[peer] = Time.get_ticks_msec() + SENDING_AWAY_MSEC


## WHO A PEER IS, for the log: its address over ENet, its number otherwise -- and the address it had, once it has gone,
## so a LEFT row says who left rather than a number nobody saw.
func _who(peer: int) -> String:
	if _addresses.has(peer) and peer not in multiplayer.get_peers():
		return String(_addresses[peer])
	var carrier := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if carrier != null and peer in multiplayer.get_peers():
		var packet_peer: ENetPacketPeer = carrier.get_peer(peer)
		if packet_peer != null:
			return "%s:%d" % [packet_peer.get_remote_address(), packet_peer.get_remote_port()]
	if transport == "steam":
		return "steam peer %d" % peer
	return "peer %d" % peer


## WHETHER THE HOST'S SIMULATION MAY HEAR FROM A PEER: every peer on a machine that is not hosting, this machine's own,
## and a joiner once its level is loaded.
func admits(peer: int) -> bool:
	return not is_host or not is_networked() or peer == my_peer_id() or admitted.has(peer)


## THE LEVEL IS BUILT, from the flight level at the end of every build, with the hash of the ground its worlds stand on
## ("" on the island). Every machine keeps the hash; a joiner tells its host, until admitted.
func level_loaded(ground_hash: String) -> void:
	_ground_here = ground_hash
	_built_here = true
	level_loaded_here.emit(level)
	if is_host or not is_networked() or not is_in_session:
		return
	_loaded_next = 0
	_report("NET_LOADED level=%s ground=%s at=%.3f" % [level, ground_hash, Time.get_unix_time_from_system()])


func _on_peer_arrived(peer: int) -> void:
	if is_host and is_networked() and peer != my_peer_id():
		# NOTHING IS SAID TO IT until it says which build it is (`_heard_hi`), and that includes whether the session is
		# full: the refusal names both builds, and until the hi this host does not know the joiner's. The carrier keeps
		# one place spare so a joiner past the cap connects and is told, rather than turned away by ENet unsaid.
		_greeting[peer] = Time.get_ticks_msec() + HI_WAIT_MSEC
		_addresses[peer] = _who(peer)
		logbook.write("CONNECTED", "host", {"peer": peer, "who": _addresses[peer]})


func _on_peer_gone(peer: int) -> void:
	if is_host:
		var was: String = "refused" if _refusal_said.has(peer) else "in" if admitted.has(peer) \
			else "joining" if _telling.has(peer) else "knocking"
		logbook.write("LEFT", "host", {"peer": peer, "who": String(_addresses.get(peer, "peer %d" % peer)), "was": was,
			"client": String(_their_line.get(peer, ""))})
	_greeting.erase(peer)
	_refusal_said.erase(peer)
	_sending_away.erase(peer)
	_their_line.erase(peer)
	_their_built.erase(peer)
	_joined.erase(peer)
	_addresses.erase(peer)
	_long.forget_peer(peer)
	_telling.erase(peer)
	admitted.erase(peer)
	_sky_owed.erase(peer)
	_music_owed.erase(peer)
	_notice_owed.erase(peer)
	_roster_owed.erase(peer)
	_cards_by_peer.erase(peer)
	# WHO LEFT, said by the host with the number the CREW page called them -- and only for somebody who was announced,
	# since a joiner refused on the way in never became anybody on anybody's board.
	if is_host and _players.has(peer):
		_notify({"kind": "left", "player": int(_players[peer])})
		_players.erase(peer)


func _say_hellos() -> void:
	if not is_networked():
		return
	var now: int = Time.get_ticks_msec()
	# THE REFUSED: said again until they go, and closed only when they will not. See "THE HANDSHAKE".
	for peer in _sending_away.keys():
		if now >= int(_sending_away[peer]):
			_sending_away.erase(peer)
			if peer in multiplayer.get_peers():
				logbook.write("CLOSED", "host", {"peer": peer, "words": "did not leave %d ms after it was refused" %
					SENDING_AWAY_MSEC})
				multiplayer.multiplayer_peer.disconnect_peer(int(peer))
		elif _refusal_said.has(peer) and now >= int(_refusal_said[peer].get("next", 0)):
			_refusal_said[peer]["next"] = now + HELLO_EVERY_MSEC
			var again: Dictionary = (_refusal_said[peer] as Dictionary).duplicate()
			again.erase("next")
			_hello(int(peer), again)
	# THE SILENT: a peer that has not said hi in `HI_WAIT_MSEC` is a build older than the hi.
	for peer in _greeting.keys():
		if now >= int(_greeting[peer]):
			_send_away(int(peer), "no_hello", refusal_words("no_hello", identity()["line"], "", ""))
	# THE JOINER'S HI, its first word, until the host names a level or refuses it.
	if not is_host and _hi_next >= 0 and now >= _hi_next and not bool(_pretend.get("silent", false)):
		_hi_next = now + HELLO_EVERY_MSEC
		var me: Dictionary = identity()
		var hi: Dictionary = {"say": "hi", "protocol": me["protocol"], "commit": me["commit"], "line": me["line"]}
		# NO `built` ONLY FROM A SUITE PRETENDING TO BE A BUILD FROM BEFORE PROTOCOL 37, which never said one.
		if int(me["built"]) >= 0:
			hi["built"] = int(me["built"])
		_hello(1, hi)
	var mine: LevelChart = null
	for peer in _telling.keys():
		if now < int(_telling[peer]):
			continue
		_telling[peer] = now + HELLO_EVERY_MSEC
		mine = ChartDrawer.chart(level) if mine == null else mine
		if mine != null and peer in multiplayer.get_peers():
			var level_hello: Dictionary = {"say": "level", "protocol": PROTOCOL, "level": mine.id,
				"hash": mine.content_hash, "name": mine.name, "built": maxi(int(identity()["built"]), 0)}
			# AND THE SKY, so a joiner builds under the host's rather than flipping to it once admitted. See "THE SKY".
			level_hello.merge(_the_sky_said())
			level_hello.merge(_roster_said())
			level_hello.merge(_music_level_said())
			# A maximum roster and a 64-character track id do not both fit the bounded
			# carrier. Music is still owed immediately after admission; joining must never
			# time out because optional first-frame audio made the level hello too large.
			# AND NEITHER DOES A ROSTER OF MORE THAN ABOUT TWELVE (lane/seats, 2026-09-18: sixty-four players). The roster
			# is owed in pages from admission anyway, so a level hello it would not fit in goes without it, first.
			if JSON.stringify(level_hello).to_utf8_buffer().size() > HELLO_MOST_BYTES:
				level_hello.erase("roster_n")
				level_hello.erase("cards")
			if JSON.stringify(level_hello).to_utf8_buffer().size() > HELLO_MOST_BYTES:
				level_hello.erase("music_state")
			_hello(int(peer), level_hello)
	for peer in _sky_owed.keys():
		if now < int(_sky_owed[peer]):
			continue
		_sky_owed[peer] = now + HELLO_EVERY_MSEC
		if peer in multiplayer.get_peers():
			var sky: Dictionary = {"say": "sky"}
			sky.merge(_the_sky_said())
			_hello(int(peer), sky)
	var pages: Array = []
	for peer in _roster_owed.keys():
		if now < int(_roster_owed[peer]):
			continue
		_roster_owed[peer] = now + HELLO_EVERY_MSEC
		if peer in multiplayer.get_peers():
			pages = roster_pages() if pages.is_empty() else pages
			var heard: Dictionary = _roster_pages_heard.get(peer, {})
			for page in range(pages.size()):
				if not heard.has(page):
					_hello(int(peer), pages[page])
	if not is_host and _card_next >= 0 and not _card_heard and now >= _card_next:
		_card_next = now + HELLO_EVERY_MSEC
		_card_said_name = _candidate_name()
		_hello(1, {"say": "card", "name": _card_said_name, "colour": int(_local_card.get("colour", 0))})
	for peer in _music_owed.keys():
		if now < int(_music_owed[peer]):
			continue
		_music_owed[peer] = now + HELLO_EVERY_MSEC
		if peer in multiplayer.get_peers():
			var music: Dictionary = {"say": "music"}
			music.merge(_the_music_said())
			_hello(int(peer), music)
	if _loaded_next >= 0 and now >= _loaded_next:
		_loaded_next = now + HELLO_EVERY_MSEC
		mine = ChartDrawer.chart(level)
		if mine != null:
			_hello(1, {"say": "loaded", "protocol": PROTOCOL, "level": mine.id, "hash": mine.content_hash,
				"ground": _ground_here})


func _hello(peer: int, said: Dictionary) -> void:
	said_to[peer] = String(said["say"])
	# ONLY TO A PEER THAT IS THERE: an RPC to a departed or unknown peer is an engine error.
	if not is_networked() or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED \
			or (is_host and peer not in multiplayer.get_peers()):
		return
	_carry(peer, JSON.stringify(said).to_utf8_buffer(), HELLO_BITS, "hello")


## ---- THE STATISTICS CARD ------------------------------------------------------------------------------------------
##
## Asked for on 2026-09-17: "Once per second, have every client send their stats to the server and the level should
## have a large monitor that shows a table of everyone's network stats."
##
##   joiner -> host   {"say": "netstats", "row": [...]}      once a second, never repeated
##   host -> everyone {"say": "netboard", "rows": [[...]]}   once a second, never repeated
##
## THEY ARE NOT SAID AGAIN WHEN THEY GO MISSING, and that is the difference between these and every other hello here.
## A level hello is repeated until it is answered because a session cannot start without it; a statistics card is worth
## nothing a second later, and a board that redelivered stale rows would be drawing last second's numbers as though
## they were this second's. A lost card shows up as a row growing old, which `NetStats.table` reports as its age and a
## board says in words.
##
## A ROW IS AN ARRAY, NOT A DICTIONARY, because eight players of named fields do not fit in a 512-byte hello:
## `NetStats.COLUMNS` is the order, in one place, read by both ends.
func say_my_stats(row: Array) -> void:
	if not is_networked() or is_host:
		return
	_hello(1, {"say": "netstats", "row": row})


## THE HOST'S TABLE, to everybody, IN PAGES of at most one hello each: `{rows, page, pages}`, the host's own row first.
##
## It was cut to what one hello carried, which was the whole table at eight players and would have been the first
## eleven or so at sixty-four (lane/seats, 2026-09-18). A board is said once a second and never again, so a lost page
## is a row that grows old on the board until the next second's arrives -- which `NetStats.table` already says in words.
func publish_the_stats_board(table: Array) -> void:
	if not is_networked() or not is_host or table.is_empty():
		return
	var pages: Array = board_pages(table)
	for peer in multiplayer.get_peers():
		for page in pages:
			_hello(int(peer), page)


## THE BOARD'S PAGES, each a `netboard` hello no bigger than `HELLO_MOST_BYTES`. Static, so a suite measures the pages
## the host sends rather than a copy of how they are cut.
## CUT BY `_pages_of`, which is also what `radar_pages` uses. It was this function's own loop until radar wanted the
## same one: two carriers with their own copy of "what fits in a hello" is two carriers that will one day disagree
## about it, and the copy would be the one nobody tested (rule 4). `tests/net_stats.gd` measures this one against the
## widest plausible row and so covers both.
static func board_pages(table: Array) -> Array:
	return _pages_of("netboard", table)


## THE RADAR PICTURE THIS HOST DREW FOR EACH PEER, to that peer and to nobody else: `{peer: rows}`, each peer's own
## rows cut into `radar` hellos no bigger than `HELLO_MOST_BYTES`.
##
## PER PEER, WHICH IS THE WHOLE POINT. Every other carrier here publishes one thing to everybody; a radar picture is
## what ONE head can see, and sending everybody the same one would make terrain masking a decoration. The loop is
## `publish_the_stats_board`'s with the table moved inside it.
##
## SAID ONCE AND NEVER REPEATED, like the board and for a sharper reason: a lost page is a contact that ages off the
## plot until the next second's sweep, and **a controller acting on a contact that has moved is worse off than one
## looking at a gap.** Nothing here acknowledges and nothing retries.
##
## A PEER WITH NO CONTACTS STILL GETS A PAGE, an empty one, and that is not a special case to be tidied away: without
## it a peer whose picture went empty -- everybody it could see having flown behind a ridge -- would keep drawing the
## last thing it was told for ever. An empty page is how radar says "nothing".
func publish_the_radar_picture(by_peer: Dictionary) -> void:
	if not is_networked() or not is_host:
		return
	_radar_sweep += 1
	for peer in multiplayer.get_peers():
		var rows: Array = by_peer.get(int(peer), []) as Array
		for page in radar_pages(rows, _radar_sweep):
			_hello(int(peer), page)


## WHICH SWEEP IS BEING SENT. Every page of one sweep carries it, and it is what tells a reader that a new picture
## has started -- NOT page 0 arriving.
##
## THIS IS NOT BELT AND BRACES; A READER THAT TRUSTED PAGE 0 WAS MEASURED WRONG. Pages are sent once and never
## repeated, so losing one is ordinary -- and a reader that started a fresh picture only when page 0 arrived went on
## APPENDING later pages to the previous sweep's list every time page 0 was the one that went missing. Measured on
## the island: a joiner drew **120 contacts in a world holding 96**, and it only ever grows.
var _radar_sweep: int = 0


## ONE PEER'S PICTURE AS `radar` HELLOS, all stamped with the sweep. Static, so a suite measures the pages a host
## sends rather than a copy of how they are cut.
static func radar_pages(rows: Array, sweep: int = 0) -> Array:
	return _pages_of("radar", rows, {"n": sweep})


## HOW A TABLE IS CUT INTO HELLOS, in one place because two places is how two carriers come to disagree about what
## fits (CLAUDE.md rule 4). `board_pages` and `radar_pages` are this function with their own word.
##
## THE PAGE AND PAGES NUMBERS ARE MEASURED AT 99 while the cut is decided, not at their real values: a table that
## grew to a hundred pages would otherwise have its later pages measured two characters short and overflow.
## AN EMPTY TABLE IS ONE EMPTY PAGE and not none, so a carrier can say "nothing" as distinct from saying nothing.
## `extra` is merged into every page and is MEASURED WITH THEM, so a carrier that stamps a sweep number on each page
## does not quietly overflow the hello it was cut to fit.
static func _pages_of(say: String, rows: Array, extra: Dictionary = {}) -> Array:
	var groups: Array = [[]]
	for row in rows:
		var trial: Array = (groups.back() as Array).duplicate()
		trial.append(row)
		var measuring: Dictionary = {"say": say, "rows": trial, "page": 99, "pages": 99}
		for key in extra:
			measuring[key] = 999999999
		var measured: int = JSON.stringify(measuring).to_utf8_buffer().size()
		if measured > HELLO_MOST_BYTES and not (groups.back() as Array).is_empty():
			groups.append([row])
		else:
			groups[groups.size() - 1] = trial
	var out: Array = []
	for page in range(groups.size()):
		var said: Dictionary = {"say": say, "rows": groups[page], "page": page, "pages": groups.size()}
		said.merge(extra)
		out.append(said)
	return out


## A HELLO ARRIVED from a peer: what the carriers do with a packet whose bit count is below zero. Public, so a suite
## whose host is a bare socket can stand in for the host's hello.
func hear_hello(from_peer: int, bytes: PackedByteArray) -> void:
	var said: Dictionary = read_hello(bytes)
	if said.is_empty():
		# FROM A PEER STILL AT THE DOOR, A HELLO THAT CANNOT BE READ IS A REFUSAL, in words, not a silence it would wait
		# out: rule 8's "a malformed item says so". From a peer already in, it is dropped with its warning as before --
		# one bad statistics card is not a reason to throw a player out of a session.
		if is_host and _greeting.has(from_peer):
			_send_away(from_peer, "bad_hello", refusal_words("bad_hello", identity()["line"], "",
				hello_fault if hello_fault != "" else "it was not a hello this game reads"))
		return
	# AT THE DOOR, THE ONLY WORD HEARD IS HI. Anything else from a peer that has not said it -- a `loaded` that skips the
	# handshake, a card -- is not answered.
	if is_host and _greeting.has(from_peer) and String(said["say"]) != "hi" and String(said["say"]) != "refused":
		return
	match String(said["say"]):
		"hi":
			if is_host:
				_heard_hi(from_peer, said)
		"level":
			if from_peer == 1 and not is_host:
				_told_the_level(said)
		"loaded":
			if is_host:
				_heard_loaded(from_peer, said)
		"admitted":
			if not is_host and from_peer == 1:
				_loaded_next = -1
		"netstats":
			if is_host:
				stats_row_heard.emit(said["row"])
		"netboard":
			if not is_host and from_peer == 1:
				stats_board_heard.emit(said["rows"], int(said.get("page", 0)))
		# THE RADAR PICTURE, FROM THE HOST ONLY. A peer cannot tell another peer what it can see: that would be a
		# client deciding what is on somebody else's plot, which is the whole of rule 10 given away.
		"radar":
			if not is_host and from_peer == 1:
				radar_heard.emit(said.get("rows", []), int(said.get("page", 0)), int(said.get("n", 0)))
		"sky":
			if not is_host and from_peer == 1:
				_hear_the_sky(said, true)
		"sky_heard":
			if is_host and int(said["n"]) == _sky_version:
				_sky_owed.erase(from_peer)
		"music":
			if not is_host and from_peer == 1:
				_hear_the_music(said, true)
		"music_heard":
			if is_host and int(said["music_n"]) == _music_version:
				_music_owed.erase(from_peer)
		"notice":
			if not is_host and from_peer == 1:
				_hear_the_notice(said)
		"notice_heard":
			if is_host and int(said["n"]) == _notice_version:
				_notice_owed.erase(from_peer)
		"talking":
			if not is_host and from_peer == 1:
				_hello(1, {"say": "talking_heard", "n": int(said["n"])})
				if int(said["n"]) > _talking_heard:
					_talking_heard = int(said["n"])
					talking = said["who"]
					talking_changed.emit()
		"talking_heard":
			if is_host and int(said["n"]) == _talking_version:
				_talking_owed.erase(from_peer)
		# A CHAT LINE FROM A PEER, taken only from a peer the host has admitted -- the same gate the player's card
		# passes -- so nothing a machine says before it is in the session reaches the board.
		"chat":
			if is_host and admitted.has(from_peer):
				_hear_a_chat_offer(from_peer, said)
		"chat_heard":
			if not is_host and from_peer == 1 and not _chat_outbox.is_empty() and int(said["n"]) == _chat_said + 1:
				_chat_said += 1
				_chat_outbox.pop_front()
				_chat_next = 0
		"chatline":
			if not is_host and from_peer == 1:
				_hear_a_chat_line(said)
		"chatline_heard":
			if is_host:
				_chat_taken[from_peer] = maxi(int(_chat_taken.get(from_peer, 0)), int(said["n"]))
				_chat_owed_at[from_peer] = 0
		"card":
			if is_host and admitted.has(from_peer):
				_hear_card(from_peer, said)
		"card_heard":
			if not is_host and from_peer == 1:
				_card_heard = true
				if _card_first_heard_msec < 0:
					_card_first_heard_msec = Time.get_ticks_msec()
				_card_next = -1
		"roster":
			if not is_host and from_peer == 1:
				_hear_roster(said, true)
		"roster_heard":
			if is_host and int(said["n"]) == _roster_version:
				var heard: Dictionary = _roster_pages_heard.get_or_add(from_peer, {})
				heard[int(said.get("page", 0))] = true
				# AGAINST THE HOST'S OWN COUNT OF PAGES, not the one the joiner said back.
				if heard.size() >= roster_pages().size():
					_roster_owed.erase(from_peer)
		"refused":
			if is_host:
				# THE JOINER TURNED THE HOST DOWN: a level it has not got, say. Its words, in the host's book.
				_telling.erase(from_peer)
				logbook.write("REFUSED", "host", {"code": "by_joiner", "peer": from_peer, "who": _who(from_peer),
					"client": String(_their_line.get(from_peer, "")), "words": said["why"]})
			elif from_peer == 1 and transport != "none":
				_hi_next = -1
				logbook.write("REFUSED", "client", {"code": String(said.get("code", "")), "who": _where_to(),
					"host": String(said.get("host", "")), "client": String(said.get("client", "")) \
						if String(said.get("client", "")) != "" else String(identity()["line"]),
					"words": said["why"]})
				_refuse(String(said["why"]), false)


## A LEVEL HELLO ARRIVES AT TWO MOMENTS IN A SESSION'S LIFE, and it says the same thing at both: this is the level.
##
##   ON THE WAY IN, while this machine is connected and waiting to be told where it is (`_stage == "hello"`);
##   AND WHENEVER THE HOST CHANGES IT under a session that is already up (`change_level`).
##
## Until 2026-09-15 only the first was heard and the second returned at once, which is why item 11 did not work at all.
## The refusal is the same refusal either way -- a client that cannot fly the new level leaves in the host's own words
## rather than flying on in a world its host has left.
func _told_the_level(said: Dictionary) -> void:
	var joining: bool = _stage == "hello"
	# NOT A HOST, AND NOT A MACHINE WITH NO SESSION: a hello about a level means nothing to either.
	if not joining and not (is_in_session and not is_host):
		return
	var why: String = why_not_the_level(said)
	# THE SKY RIDES THE LEVEL, and is heard before anything is built under it -- joining or changing -- so the first
	# frame drawn is the host's. Only a hello that got past `why_not_the_level` is listened to.
	if why == "" and said.has("n"):
		_hear_the_sky(said, false)
	if why == "" and said.has("roster_n"):
		_hear_roster(said, false)
	if why == "" and said.has("music_n"):
		_hear_the_music(said, false)
	# THE HI HAS BEEN ANSWERED, whatever the answer: a host that names a level has passed this machine's build.
	_hi_next = -1
	if why != "":
		# SAID TO THE HOST ON THE WAY OUT, once. The socket closes straight after, so it may not arrive; the host learns the
		# joiner went either way.
		_hello(1, {"say": "refused", "why": why})
		_refuse(why)
		return
	# SAID AGAIN WITH THE LEVEL THIS MACHINE IS ALREADY ON: nothing to do. The host repeats it until it is answered, and
	# what answers it is `loaded`, which the flight level sends when it has built.
	if not joining and String(said["level"]) == level:
		return
	_stage = ""
	level = String(said["level"])
	is_in_session = true
	if joining:
		# AND HOW FAR THIS BUILD IS FROM THE HOST'S, when the two are a minute or more apart: the same commit, since the hi
		# passed, but perhaps a release beside a dev run of it, or one commit exported twice.
		var age: String = BuildPlate.age_words(int(identity()["built"]), int(said.get("built", 0)))
		session_message.emit("Connected. Flying %s.%s" % [ChartDrawer.chart(level).name,
			" Your build is %s than the host's." % age if age != "" else ""])
		session_ready.emit()
		return
	# A LEVEL CHANGE: the same session, the same socket, a different world. `_built_here` goes back to false because this
	# machine has not built the new one yet, and `level_loaded` is what says it has.
	_built_here = false
	_ground_here = ""
	_loaded_next = -1
	session_message.emit("The host is flying %s." % ChartDrawer.chart(level).name)
	_report("NET_LEVEL_CHANGING level=%s at=%.3f" % [level, Time.get_unix_time_from_system()])
	level_changing.emit(level)


## A HOST ON ANOTHER PROTOCOL, in words, as a client can say it without the host's build line.
## Since protocol 37 it says who is behind, which the two protocol numbers alone can tell.
static func host_protocol_words(theirs: int, mine: String) -> String:
	return "Can't join: the host speaks network protocol %d and you're running %s (protocol %d). %s" \
		% [theirs, mine, PROTOCOL, update_words({"protocol": theirs}, {"protocol": PROTOCOL})]


## WHY A JOINER CANNOT FLY THE LEVEL ITS HOST NAMED, or "" when it can. Pure, over a hello `read_hello` passed.
static func why_not_the_level(said: Dictionary) -> String:
	if int(said.get("protocol", -1)) != PROTOCOL:
		# AN OLDER OR NEWER HOST, the one refusal a client makes for itself: a host from before protocol 26 never reads a
		# hi, so it cannot say its build, and this is everything the client can know -- its protocol and this build.
		return host_protocol_words(int(said.get("protocol", -1)), BuildPlate.line())
	var chart: LevelChart = ChartDrawer.chart(String(said.get("level", "")))
	if chart == null:
		return "The host is flying %s, a level this game does not have." % String(said.get("name", said.get("level", "")))
	if chart.content_hash != String(said.get("hash", "")):
		return "The host's copy of %s is not the same as yours." % chart.name
	return ""


func _heard_loaded(peer: int, said: Dictionary) -> void:
	# SAID AGAIN UNTIL ANSWERED, SO ANSWERED EVERY TIME: a joiner whose "admitted" was lost says "loaded" again.
	if admitted.has(peer):
		_hello(peer, {"say": "admitted"})
		return
	if _sending_away.has(peer):
		return
	# NOBODY WHO HAS NOT BEEN TOLD A LEVEL: a `loaded` from a peer that never passed its hi is a peer skipping the
	# handshake, and answering it would admit a build nobody checked (`tests/handshake_peers.gd`'s mutant A).
	if not _telling.has(peer):
		return
	# NOT BEFORE THIS MACHINE HAS BUILT ITS OWN LEVEL. `_ground_here` is the hash of the level this host last built, so
	# between a `change_level` and the host's own rebuild it is the OLD level's -- and answering with it would send away
	# a peer that had loaded exactly what it was told to. Nothing is said; the peer says `loaded` again in 200 ms.
	if not _built_here:
		return
	# A peer can finish the OLD level just after the host changes. It is already in `_telling`, so the new hello is on
	# its way; refusing this delayed but honest `loaded` disconnects exactly the late joiner a transition must carry.
	if _telling.has(peer) and String(said.get("level", "")) != level:
		return
	var mine: LevelChart = ChartDrawer.chart(level)
	var why: String = ""
	var code: String = ""
	if mine == null or int(said["protocol"]) != PROTOCOL or String(said["level"]) != mine.id \
			or String(said["hash"]) != mine.content_hash:
		code = "wrong_level"
		why = "You loaded a level that is not the host's %s." % (mine.name if mine != null else level)
	elif String(said["ground"]) != _ground_here:
		code = "wrong_ground"
		why = "The ground under your %s is not the host's: the two builds make it differently." % mine.name
	if why != "":
		push_warning("[net] peer %d is sent away: %s (its ground '%s', the host's '%s')" % [peer, why, said["ground"],
			_ground_here])
		_send_away(peer, code, "%s This game is %s; you're running %s." % [why, identity()["line"],
			String(_their_line.get(peer, "?"))])
		return
	_telling.erase(peer)
	admitted[peer] = Time.get_unix_time_from_system()
	_hello(peer, {"say": "admitted"})
	# A PEER ARRIVING DURING A COUNTDOWN NEEDS THE CURRENT CUE TOO. `_notify` could only owe it to peers admitted when
	# the button was pressed; without this, a late arrival saw the old level until the hello changed it underfoot.
	if not _called.is_empty() and notice.get("kind") == "level":
		_notice_owed[peer] = 0
	# AND THE SKY AGAIN, owed until heard: the level hello carried it, but the host may have changed it since that hello
	# was answered, and a peer not yet admitted is not told about a change. Cheap, and it closes the gap. See "THE SKY".
	_sky_owed[peer] = 0
	_roster_owed[peer] = 0
	_roster_pages_heard.erase(peer)
	_music_owed[peer] = 0
	_report("NET_ADMITTED peer=%d level=%s held=%d at=%.3f" % [peer, level, held_back, float(admitted[peer])])
	# JOINED ONCE: a level change un-admits everybody and admits them again, which is the same people coming back.
	logbook.write("RELOADED" if _joined.has(peer) else "JOINED", "host",
		{"peer": peer, "who": _who(peer), "client": String(_their_line.get(peer, "")), "level": level})
	_joined[peer] = true


## WHAT A PEER SENT, CHECKED: the hello as a Dictionary with only the keys its `say` has, or {} and a warning. Untrusted
## input proposes (CLAUDE.md, rule 8): anything over `HELLO_MOST_BYTES`, not a JSON object, saying nothing a hello says,
## or holding a field of the wrong shape is dropped and said; a refusal's reason is cut to `HELLO_WHY_MOST`, and said.
## WHY THE LAST HELLO `read_hello` DROPPED WAS DROPPED, in words, or "": what a peer still at the door is told
## (`bad_hello`), so the refusal says what was wrong rather than only that something was.
static var hello_fault: String = ""


static func _fault(words: String) -> Dictionary:
	push_warning("[net] %s; dropped" % words)
	hello_fault = words
	return {}


## A JOINER'S HI, CHECKED (rule 8): a protocol that is a whole number, a commit that is hex or "unknown", and a line
## that is a string, cleaned and cut to `LINE_MOST`. A hi that fails any of these is not a build this host can compare,
## and the peer is told so (`bad_hello`) rather than left to time out.
static func _read_hi(d: Dictionary) -> Dictionary:
	var protocol: Variant = d.get("protocol")
	if not (protocol is float or protocol is int) or float(protocol) != floorf(float(protocol)) \
			or float(protocol) < 0.0 or float(protocol) > 65535.0:
		return _fault("a hi with no protocol number")
	if not d.get("commit") is String or RegEx.create_from_string("^([0-9a-f]{7,40}|unknown)$").search(
			String(d["commit"])) == null:
		return _fault("a hi with no commit a build could have")
	if not d.get("line") is String or Logbook.clean(String(d["line"]), LINE_MOST).is_empty():
		return _fault("a hi with no build line")
	# `built` IS OPTIONAL, AND 0 WHEN ABSENT: a protocol-36 joiner never says it, and must be refused on its protocol --
	# told it is the older build -- rather than as a hello nobody could read. One that IS said is a time or nothing.
	var built: int = 0
	if d.has("built"):
		built = _read_built(d["built"])
		if built < 0:
			return _fault("a hi with a build time that is not a time")
	return {"say": "hi", "protocol": int(protocol), "commit": String(d["commit"]),
		"line": Logbook.clean(String(d["line"]), LINE_MOST), "built": built}


## THE LATEST A BUILD TIME MAY BE: the year 2100, in epoch seconds. Anything past it is not a build anybody made.
const BUILT_MOST: int = 4102444800


## A BUILD TIME AS A PEER SAID IT: whole epoch seconds from 0 to `BUILT_MOST`, or -1 for anything else. The callers
## drop and warn (rule 8); 0 is a build that did not know its time, and is allowed.
static func _read_built(value: Variant) -> int:
	if not (value is int or value is float) or float(value) != floorf(float(value)) or float(value) < 0.0 \
			or float(value) > float(BUILT_MOST):
		return -1
	return int(value)


static func read_hello(bytes: PackedByteArray) -> Dictionary:
	hello_fault = ""
	if bytes.size() > HELLO_MOST_BYTES:
		return _fault("a hello of %d bytes, over %d" % [bytes.size(), HELLO_MOST_BYTES])
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return _fault("a hello that is not a JSON object")
	var d: Dictionary = parser.data
	var say: String = String(d.get("say", "")) if d.get("say") is String else ""
	if say == "refused":
		if not d.get("why") is String:
			return _fault("a refusal with no reason")
		var why: String = String(d["why"])
		if why.length() > HELLO_WHY_MOST:
			push_warning("[net] a refusal of %d letters, cut to %d" % [why.length(), HELLO_WHY_MOST])
			why = why.left(HELLO_WHY_MOST)
		var refused: Dictionary = {"say": say, "why": Logbook.clean(why, HELLO_WHY_MOST)}
		# AND, FROM A HOST OF PROTOCOL 26 ON, WHICH REFUSAL AND WHOSE BUILDS: optional, because an older host's refusal
		# is still a refusal in words and must be shown rather than dropped.
		for key in ["code", "host", "client"]:
			if d.get(key) is String:
				refused[key] = Logbook.clean(String(d[key]), LINE_MOST if key != "code" else 24)
		return refused
	if say == "hi":
		return _read_hi(d)
	if say == "admitted":
		return {"say": say}
	if say == "netstats" or say == "netboard":
		return _read_the_stats(say, d)
	if say == "radar":
		return _read_the_radar(d)
	if say == "sky" or say == "sky_heard":
		return _read_the_sky(say, d)
	if say == "music" or say == "music_heard":
		return _read_the_music(say, d)
	if say == "notice" or say == "notice_heard":
		return _read_the_notice(say, d)
	if say == "talking" or say == "talking_heard":
		return _read_the_talking(say, d)
	if say == "chat" or say == "chat_heard" or say == "chatline" or say == "chatline_heard":
		return _read_the_chat(say, d)
	if say == "card" or say == "card_heard" or say == "roster" or say == "roster_heard":
		return _read_roster_message(say, d)
	if say != "level" and say != "loaded":
		return _fault("a hello that says '%s', which no hello says" % say)
	var protocol: Variant = d.get("protocol")
	if not (protocol is float or protocol is int) or float(protocol) != floorf(float(protocol)) \
			or float(protocol) < 0.0 or float(protocol) > 65535.0:
		return _fault("a hello with no protocol number")
	if not d.get("level") is String or RegEx.create_from_string(LevelChart.ID_PATTERN).search(String(d["level"])) == null:
		return _fault("a hello naming no level id")
	if not d.get("hash") is String or RegEx.create_from_string("^[0-9a-f]{64}$").search(String(d["hash"])) == null:
		return _fault("a hello with no level hash")
	var out: Dictionary = {"say": say, "protocol": int(protocol), "level": String(d["level"]), "hash": String(d["hash"])}
	if say == "loaded":
		if not d.get("ground") is String or RegEx.create_from_string("^(-?[0-9]{1,20})?$").search(String(d["ground"])) == null:
			return _fault("a loaded hello with no ground hash")
		out["ground"] = String(d["ground"])
	if say == "level":
		if not d.get("name") is String or String(d["name"]).strip_edges().is_empty() \
				or String(d["name"]).length() > LevelChart.NAME_MOST:
			return _fault("a level hello with no name a level could have")
		out["name"] = String(d["name"]).strip_edges()
		# THE HOST'S BUILD TIME, optional as the sky is: an older host says none, and is refused on its protocol by
		# `why_not_the_level` rather than dropped here.
		if d.has("built"):
			var built: int = _read_built(d["built"])
			if built < 0:
				return _fault("a level hello with a build time that is not a time")
			out["built"] = built
		# THE SKY IS OPTIONAL HERE, and only here: a host a protocol behind sends a level hello without it, and that host
		# must be refused as "a different version" by `why_not_the_level` rather than dropped as a malformed hello and
		# left to time out. A sky that IS present is read whole or not at all.
		if d.has("n") or d.has("clock") or d.has("clouds"):
			var sky: Dictionary = _read_the_sky("sky", d)
			if sky.is_empty():
				return {}
			sky.erase("say")
			out.merge(sky)
		if d.has("roster_n") or d.has("cards"):
			var people: Dictionary = _read_roster_fields(d, "roster_n")
			if people.is_empty():
				return {}
			out.merge(people)
		if d.has("music_state") or d.has("music_n") or d.has("music") or d.has("music_started"):
			var music_source: Dictionary = d
			if d.has("music_state"):
				var compact_music: Variant = d["music_state"]
				if not compact_music is Array or (compact_music as Array).size() != 7:
					return _fault("a level hello with no compact music state")
				music_source = {"music": compact_music[0], "music_started": compact_music[1],
					"music_from": compact_music[2], "music_to": compact_music[3],
					"music_fade_at": compact_music[4], "music_fade_frames": compact_music[5],
					"music_n": compact_music[6]}
			var music: Dictionary = _read_the_music("music", music_source)
			if music.is_empty():
				return {}
			music.erase("say")
			out.merge(music)
	return out


## ---- PLAYER IDENTITY ---------------------------------------------------------------------------
## A client proposes one small card. The host validates it, waits until sync maps that peer to a
## client id, and republishes an authoritative revision. Lost messages repeat until acknowledged.

## ---- THE PLAYER'S NAME: STEAM'S, UNLESS THEY TYPED ONE ----------------------------------------------------------
##
## Asked for on 2026-09-19: "if it's available, we should have players names pulled from steam (not player 1, player
## 2)". The persona was already preferred, but only ever read from a Steam some Steam ACTION had started, because
## `SteamLobbyDirectory` starts Steam the first time it is asked and not at boot. So everybody who hosted or joined by
## IP, or played solo, was "PLAYER N" with Steam running beside them; and a joiner's card, sent once and acknowledged,
## kept "PLAYER N" even after Steam did start. Three causes, three fixes:
##
##   STEAM STARTS AT BOOT FOR A PLAYER, and only for one (`steam_at_boot_refusal`): a window, the Steam client running,
##     no suite, no probe, no `--no-steam`, and no session asked for on the command line -- which is how a suite's and
##     an agent's second local instance start, and the reason the rule "asking for a name must not start Steam" was
##     written: two local processes, one Steam account, and nothing in a headless run touching the client at all.
##   A CARD IS SAID AGAIN WHEN THE NAME IT WOULD CARRY CHANGES (`_keep_my_card`): Steam starting later, by a Steam
##     button, is then a new card to the host within a frame. The host's own card is read afresh every frame already.
##   A NAME THE PLAYER TYPED WINS, ACROSS RUNS: player.json says `typed`. Before, the flag lived only as long as the run,
##     so a name typed yesterday lost to Steam today. A name that is the fallback ("PLAYER 3") or the persona itself,
##     pressed OK on unchanged, is not a typed name: it would pin "PLAYER 3" for ever, the very thing asked away.

## WHY STEAM IS NOT STARTED AT BOOT, or "" when it may be. Pure over what the process was given, so a suite can put every
## case through it without a Steam client. `args` is the whole command line (a probe's scene path is in it), `user_args`
## what follows the bare `--`.
static func steam_at_boot_refusal(args: PackedStringArray, user_args: PackedStringArray, display: String, test_slot: String,
		client_running: bool) -> String:
	if display == "headless":
		return "headless"
	if test_slot != "":
		return "a suite (COCKPIT_TEST_SLOT)"
	for argument in args:
		if argument.begins_with("res://tests/") or argument.replace("\\", "/").contains("/tests/"):
			return "a test scene"
	for argument in user_args:
		if argument == "--no-steam":
			return "--no-steam"
		# AN ENET SESSION ON THE COMMAND LINE (`LaunchOrder`'s `--host` and `--join=`): how every multi-instance run on one
		# machine starts. A Steam one (`--steam-host`, `--steam-join=`, an invite) starts Steam itself a moment later.
		if argument == "--host" or argument.begins_with("--host=") or argument.begins_with("--join="):
			return "an ENet session asked for on the command line (%s)" % argument.get_slice("=", 0)
	if not client_running:
		return "the Steam client is not running"
	return ""


## WHETHER THE STEAM CLIENT IS UP, asked without starting anything: `isSteamRunning` needs no `steamInit`.
func _steam_client_running() -> bool:
	if not Engine.has_singleton("Steam"):
		return false
	var steam: Object = Engine.get_singleton("Steam")
	return steam.has_method("isSteamRunning") and bool(steam.call("isSteamRunning"))


## The name the last card this client sent carried, so a change is noticed. "" before any was sent.
var _card_said_name: String = ""
## When the host first acknowledged this machine's card, or -1: what `--pretend-persona=NAME@heard` waits for.
var _card_first_heard_msec: int = -1


## A JOINER'S CARD, SAID AGAIN WHEN ITS NAME WOULD CHANGE: Steam started after it was sent, most often. Once a frame, and
## it only compares two strings until something moved.
func _keep_my_card() -> void:
	if is_host or not is_in_session or not _card_heard:
		return
	if _candidate_name() != _card_said_name:
		_card_heard = false
		_card_next = 0


## The Steam persona, or "" while Steam has not started (or a suite's pretend one, `persona_name`).
func _persona() -> String:
	if persona_name.is_valid():
		return String(persona_name.call())
	if lobbies != null and lobbies.has_method("persona_name"):
		return String(lobbies.call("persona_name"))
	return ""


func _candidate_name() -> String:
	var from_steam: String = _persona()
	var saved: String = String(_local_card.get("name", ""))
	var typed: bool = _profile_edited and PROFILE.is_a_typed_name(saved)
	var candidate: String = saved if typed or from_steam.strip_edges().is_empty() else from_steam
	if candidate.strip_edges().is_empty():
		candidate = "PLAYER %d" % maxi(Sim.local_client_id(), 1)
	return _clean_name(candidate)


func set_profile(player_name: String, colour: int, persist: bool = true) -> String:
	if colour < 0 or colour >= PlayerColours.PALETTE.size():
		return "Choose one of the eight colours."
	var clean: String = _clean_name(player_name)
	if clean.is_empty():
		return "Type a name first."
	# TYPED, unless it is the name the player would have had anyway -- the persona, or the fallback -- pressed OK on
	# unchanged: see "THE PLAYER'S NAME".
	var persona: String = _persona()
	_profile_edited = PROFILE.is_a_typed_name(clean) and clean != _clean_name(persona)
	_local_card = {"name": clean, "colour": colour, "typed": _profile_edited}
	if persist:
		var saved: Error = PROFILE.save_card(_local_card)
		if saved != OK:
			push_warning("[profile] player.json was not saved: %s" % error_string(saved))
	if is_host:
		_cards_by_peer[my_peer_id()] = _local_card.duplicate()
		_publish_roster_if_changed()
	else:
		_card_heard = false
		_card_next = 0
	return ""


func local_card() -> Dictionary:
	return {"name": _candidate_name(), "colour": int(_local_card.get("colour", 0))}


func name_of(client_id: int) -> String:
	return String((roster.get(client_id, {}) as Dictionary).get("name", "PLAYER %d" % client_id))


## A PLAYER'S COLOUR: the palette colour their card chose, unless a player with a lower number already wears it, when
## it is `PlayerColours.fallback` for their client id. Eight colours were one each at eight players; at sixty-four
## (lane/seats, 2026-09-18) they would be eight each, and a colour is how a player is told apart on the CREW page, the
## air picture and a remote head. The first to choose keeps it; nobody's choice is refused.
func colour_of(client_id: int) -> Color:
	var card: Dictionary = roster.get(client_id, {})
	var chosen: int = int(card.get("colour", -1))
	for other in roster:
		if int(other) < client_id and int((roster[other] as Dictionary).get("colour", -1)) == chosen:
			return PlayerColours.fallback(client_id)
	return PlayerColours.at(chosen, client_id)


## WHICH TEAM A PLAYER IS ON, off the roster: the host's answer, on every machine, 0 for nobody's team. Asked rather
## than remembered (rule 4) -- the lobby's rows, the voice sender's filter and the tests all read this one function, so
## there is no second roster of teams to disagree with the host's.
func team_of(client_id: int) -> int:
	return TeamBoard.read(int((roster.get(client_id, {}) as Dictionary).get("team", TeamBoard.NOBODY)))


## PUT A PLAYER ON A TEAM, or take them off one with `TeamBoard.NOBODY`. The host's alone: a client that could write a
## team could put itself on a team it was not invited to and listen to it, which is the whole thing teams exist to stop.
## Says why in words when it refuses, because a button press is answered where it was pressed.
func set_team(client_id: int, team: int) -> String:
	if not is_host:
		return "Only the host assigns teams."
	if client_id <= 0 or client_id > PLAYER_MOST:
		return "That is not a player."
	if team != TeamBoard.NOBODY and not TeamBoard.holds(team):
		return "There is no team %d." % team
	if team == TeamBoard.NOBODY:
		_teams_by_client.erase(client_id)
	else:
		_teams_by_client[client_id] = team
	_publish_roster_if_changed()
	return ""


func colour_index_of(client_id: int) -> int:
	return int((roster.get(client_id, {}) as Dictionary).get("colour", -1))


func roster_cards() -> Array:
	var cards: Array = roster.values()
	cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["player"]) < int(b["player"]))
	return cards


func _keep_the_roster() -> void:
	if not is_in_session:
		return
	if is_host:
		var mine: int = Sim.local_client_id()
		if mine > 0:
			_cards_by_peer[my_peer_id()] = local_card()
		_publish_roster_if_changed()


func _hear_card(peer: int, said: Dictionary) -> void:
	_cards_by_peer[peer] = {"name": said["name"], "colour": said["colour"]}
	_hello(peer, {"say": "card_heard"})
	_publish_roster_if_changed()


func _publish_roster_if_changed() -> void:
	if not is_host:
		return
	var next: Dictionary = {}
	for peer in _cards_by_peer:
		# ASK THE AUTHORITY, NOT THE PILOTS. This asked `Sim.client_of_peer`, which reads the pairing off replicated
		# PilotOwner components -- right for a joiner, which never saw anybody connect, and wrong here: a host has its own
		# server, which saw the client arrive on the peer. In a session where nobody has a pilot there are no components to
		# read, so the host published a roster with only itself on it (the flat voice lobby, measured 2026-09-19). The
		# pilots remain the fallback, so a host whose server has not answered yet behaves exactly as it did.
		var player: int = Sim.local_client_id() if int(peer) == my_peer_id() else Sim.server_client_of_peer(int(peer))
		if player <= 0 and int(peer) != my_peer_id():
			player = Sim.client_of_peer(int(peer))
		if player <= 0:
			continue
		var card: Dictionary = _cards_by_peer[peer]
		# THE BUILD TIME IS THE HOST'S TO WRITE, from what each peer's hi said (and its own for itself), never from the
		# card a player proposes: a player cannot make themselves look up to date.
		var built: int = maxi(int(identity()["built"]), 0) if int(peer) == my_peer_id() \
			else int(_their_built.get(int(peer), 0))
		next[player] = {"player": player, "name": String(card["name"]), "colour": int(card["colour"]), "built": built,
			"team": int(_teams_by_client.get(player, TeamBoard.NOBODY))}
	# Duplicate names remain valid identities; suffixes make the visible labels unambiguous.
	var seen: Dictionary = {}
	var ids: Array = next.keys()
	ids.sort()
	for player in ids:
		var base: String = String((next[player] as Dictionary)["name"])
		var occurrence: int = int(seen.get(base.to_lower(), 0)) + 1
		seen[base.to_lower()] = occurrence
		if occurrence > 1:
			var suffix: String = " (%d)" % occurrence
			(next[player] as Dictionary)["name"] = base.left(NAME_MOST - suffix.length()) + suffix
	if next == roster:
		return
	roster = next
	_roster_version += 1
	_roster_pages_heard.clear()
	for peer in admitted:
		_roster_owed[int(peer)] = 0
	roster_changed.emit()
	_report("NET_ROSTER n=%d cards=%d" % [_roster_version, roster.size()])


func _roster_said() -> Dictionary:
	# Compact inside the level hello, as the pages are. A level hello the whole roster does not fit in goes without it
	# (`_say_hellos`), and the pages follow admission.
	return {"roster_n": _roster_version, "cards": _compact_cards(roster_cards())}


static func _compact_cards(cards: Array) -> Array:
	var compact: Array = []
	for card in cards:
		compact.append([int(card["player"]), String(card["name"]), int(card["colour"]), int(card.get("built", 0)),
			int(card.get("team", TeamBoard.NOBODY))])
	return compact


## THE ROSTER, IN PAGES: every card, as `roster` hellos each no bigger than `HELLO_MOST_BYTES`, in player order.
##
## A hello is one unreliable packet, said again until it is answered, and 512 bytes is what keeps it one packet. Eight
## cards of the longest names fitted in one; sixty-four do not, about 25 bytes a card (lane/seats, 2026-09-18). So the
## roster is cut into pages, each `{n, page, pages, cards}`: the joiner answers every page it hears, the host says again
## only the pages not yet answered, and a joiner takes revision `n` once every page of it is in -- never a half roster.
## One page for any session of about twelve or fewer, which is every session before the cap was raised.
func roster_pages() -> Array:
	var compact: Array = _compact_cards(roster_cards())
	var groups: Array = [[]]
	for card in compact:
		var trial: Array = (groups.back() as Array).duplicate()
		trial.append(card)
		var said: Dictionary = {"say": "roster", "n": _roster_version, "page": 99, "pages": 99, "cards": trial}
		if JSON.stringify(said).to_utf8_buffer().size() > HELLO_MOST_BYTES and not (groups.back() as Array).is_empty():
			groups.append([card])
		else:
			groups[groups.size() - 1] = trial
	var out: Array = []
	for page in range(groups.size()):
		out.append({"say": "roster", "n": _roster_version, "page": page, "pages": groups.size(), "cards": groups[page]})
	return out


func _hear_roster(said: Dictionary, answer: bool) -> void:
	var n: int = int(said.get("n", said.get("roster_n", -1)))
	var pages: int = int(said.get("pages", 1))
	var page: int = int(said.get("page", 0))
	if answer:
		_hello(1, {"say": "roster_heard", "n": n, "page": page, "pages": pages})
	if n <= _roster_heard:
		return
	# EVERY PAGE OF ONE REVISION BEFORE ANY OF IT IS TAKEN, so no machine ever draws half a session.
	var parts: Dictionary = _roster_parts.get_or_add(n, {})
	parts[page] = said.get("cards", [])
	if parts.size() < pages:
		return
	var next: Dictionary = {}
	for part in parts.values():
		for card in part:
			if next.has(int(card["player"])):
				push_warning("[net] a roster's pages name player %d twice; dropped" % int(card["player"]))
				_roster_parts.erase(n)
				return
			next[int(card["player"])] = (card as Dictionary).duplicate()
	if next.size() > MAX_PLAYERS:
		push_warning("[net] a roster of %d cards across its pages; dropped" % next.size())
		_roster_parts.erase(n)
		return
	for older in _roster_parts.keys():
		if int(older) <= n:
			_roster_parts.erase(older)
	_roster_heard = n
	roster = next
	roster_changed.emit()


static func _clean_name(raw: String) -> String:
	var out: String = ""
	for i in range(raw.length()):
		var code: int = raw.unicode_at(i)
		if code >= 32 and code != 127:
			out += raw[i]
	return out.strip_edges().left(NAME_MOST)


static func _read_roster_message(say: String, d: Dictionary) -> Dictionary:
	if say == "card_heard":
		return {"say": say}
	if say == "roster_heard":
		var heard: Variant = d.get("n")
		if not (heard is int or heard is float) or float(heard) != floorf(float(heard)) or int(heard) < 0:
			push_warning("[net] a roster acknowledgement with no revision; dropped")
			return {}
		var paged: Dictionary = _read_page(d)
		if paged.is_empty():
			return {}
		paged.merge({"say": say, "n": int(heard)})
		return paged
	if say == "card":
		var card: Dictionary = _read_card(d, false)
		if card.is_empty():
			return {}
		card["say"] = say
		return card
	var fields: Dictionary = _read_roster_fields(d, "n")
	if fields.is_empty():
		return {}
	var page: Dictionary = _read_page(d)
	if page.is_empty():
		return {}
	fields.merge(page)
	fields["say"] = say
	return fields


## WHICH PAGE OF HOW MANY, read off a paged hello: {page, pages}, {page: 0, pages: 1} for one that names none, or {}
## with a warning for a page that is not one of its pages. At most one page a player, which no roster or board reaches.
static func _read_page(d: Dictionary) -> Dictionary:
	var page: Variant = d.get("page", 0)
	var pages: Variant = d.get("pages", 1)
	if not (page is int or page is float) or not (pages is int or pages is float) \
			or float(page) != floorf(float(page)) or float(pages) != floorf(float(pages)) \
			or int(pages) < 1 or int(pages) > MAX_PLAYERS or int(page) < 0 or int(page) >= int(pages):
		push_warning("[net] a page %s of %s; dropped" % [str(page), str(pages)])
		return {}
	return {"page": int(page), "pages": int(pages)}


static func _read_roster_fields(d: Dictionary, revision_key: String) -> Dictionary:
	var revision: Variant = d.get(revision_key)
	if not (revision is int or revision is float) or float(revision) != floorf(float(revision)) \
			or int(revision) < 0 or int(revision) > 1000000000:
		push_warning("[net] a roster with no revision; dropped")
		return {}
	if not d.get("cards") is Array or (d["cards"] as Array).size() > MAX_PLAYERS:
		push_warning("[net] a roster with the wrong number of cards; dropped")
		return {}
	var cards: Array = []
	var players: Dictionary = {}
	for proposed in d["cards"]:
		if proposed is Array and (proposed as Array).size() == 3:
			proposed = {"player": proposed[0], "name": proposed[1], "colour": proposed[2]}
		elif proposed is Array and (proposed as Array).size() == 4:
			proposed = {"player": proposed[0], "name": proposed[1], "colour": proposed[2], "built": proposed[3]}
		elif proposed is Array and (proposed as Array).size() == 5:
			proposed = {"player": proposed[0], "name": proposed[1], "colour": proposed[2], "built": proposed[3],
				"team": proposed[4]}
		if not proposed is Dictionary:
			push_warning("[net] a roster card that is not an object; dropped")
			return {}
		var card: Dictionary = _read_card(proposed, true)
		if card.is_empty() or players.has(card.get("player")):
			if not card.is_empty(): push_warning("[net] a roster names one player twice; dropped")
			return {}
		players[card["player"]] = true
		cards.append(card)
	return {revision_key: int(revision), "cards": cards}


static func _read_card(d: Dictionary, with_player: bool) -> Dictionary:
	if not d.get("name") is String:
		push_warning("[net] a player card with no name; dropped")
		return {}
	var raw: String = String(d["name"])
	var clean: String = _clean_name(raw)
	if clean.is_empty():
		push_warning("[net] an empty player name; dropped")
		return {}
	if clean != raw:
		push_warning("[net] a player name was trimmed or clamped to %d printable characters" % NAME_MOST)
	var colour: Variant = d.get("colour")
	if not (colour is int or colour is float) or float(colour) != floorf(float(colour)) \
			or int(colour) < 0 or int(colour) >= PlayerColours.PALETTE.size():
		push_warning("[net] a player card with colour outside 0..7; dropped")
		return {}
	var out: Dictionary = {"name": clean, "colour": int(colour)}
	if with_player:
		var player: Variant = d.get("player")
		if not (player is int or player is float) or float(player) != floorf(float(player)) \
				or int(player) < 1 or int(player) > PLAYER_MOST:
			push_warning("[net] a roster card with no player; dropped")
			return {}
		out["player"] = int(player)
		# WHEN THAT PLAYER'S BUILD WAS MADE, as the host heard it: 0 when a card says none, and a card whose time is not a
		# time is dropped, like any other field of the wrong shape.
		out["built"] = 0
		if d.has("built"):
			out["built"] = _read_built(d["built"])
			if int(out["built"]) < 0:
				push_warning("[net] a roster card with a build time that is not a time; dropped")
				return {}
		# WHICH TEAM THE HOST PUT THAT PLAYER ON, and 0 -- nobody's team -- for a card that names none, which is the
		# explicit default rule 8 asks for at the call site. A number that is not a team this build has is DROPPED rather
		# than clamped: `TeamBoard` says why, and a clamp would quietly put somebody on RED.
		out["team"] = TeamBoard.NOBODY
		if d.has("team"):
			var team: Variant = d["team"]
			if not (team is int or team is float) or float(team) != floorf(float(team)) \
					or not (int(team) == TeamBoard.NOBODY or TeamBoard.holds(int(team))):
				push_warning("[net] a roster card with a team that is not a team; dropped")
				return {}
			out["team"] = int(team)
	return out


## HOW `client_id`'S BUILD STANDS AGAINST THIS ONE, "2 days older" or "5 hours newer", or "" when they are the same age
## or either is unknown. Off the roster, whose build times the host wrote from each player's hi; what the CREW page says.
func build_age_of(client_id: int) -> String:
	var card: Dictionary = roster.get(client_id, {})
	return BuildPlate.age_words(int(card.get("built", 0)), int(identity()["built"]))



## ---- THE VOICE: LIVE FRAMES, ROUTED BY A HOST THAT DECIDES WHO MAY HEAR THEM --------------------------------------
##
## The user (2026-09-19): *"there should be a button a user holds down to talk to everyone and another that allows them
## to talk to their team"*, and *"can there be more than one channel of audio from server to client?"*
##
## A FRAME IS `VOICE_BITS` ON THE UNORDERED CARRIER, and not a hello, a notice or a long document. Voice is droppable:
## a frame that arrives late is worth less than nothing, and none of the three existing carriers will drop anything --
## the hello repeats until heard, the notice repeats until heard, the long document retries a missing chunk. It rides
## `_receive_unordered` and NOT `_receive`, because `_receive`'s own comment records that GodotSteam sends
## `unreliable_ordered` as **Reliable**: the unordered carrier is the only one genuinely unreliable on both transports,
## which is what voice wants.
##
## THE HOST IS IN THE PATH, ALWAYS, and that is not a cost -- it is the feature. Only the host knows the roster, so only
## the host can decide that a team frame reaches that team and nobody else. A peer-to-peer arrangement would have to
## trust every sender about its own audience.
##
##   peer -> host      a frame, with the sender's INTENT in its audience byte
##   host -> peers     the same frame, with the speaker STAMPED from the peer it arrived on, to the peers entitled to it
##   host -> everyone  {"say": "talking", "n", "who": [client ids]}   when the set changes, until heard
##   peer -> host      {"say": "talking_heard", "n"}
##
## WHO IS TALKING IS A PUBLISHED FACT AND NOT A GUESS. A listener on another team receives NONE of a speaker's audio and
## must still light them -- the user asked for an indicator that is always visible -- so the lamp reads `is_talking`,
## which is the host's answer, carried to every machine whether or not the audio was. The set is published only when it
## CHANGES, in the repeat-until-heard shape every other small fact here uses; somebody starting or stopping talking is a
## few events a second at worst, where a fixed ten-a-second heartbeat would be a hello every 100 ms for ever.

## WHO THE HOST SAYS IS TALKING, as sync client ids. Read it with `is_talking`.
var talking: Array = []
## The host's: client id -> when its last frame arrived, in ticks. A speaker is dropped from `talking` once quiet.
var _talking_since: Dictionary = {}
## The host's: how many times the talking set has changed this session.
var _talking_version: int = 0
## The host's: peer -> when to say the set again, until acknowledged.
var _talking_owed: Dictionary = {}
## A peer's: the highest talking revision taken, or -1.
var _talking_heard: int = -1
## This machine's own frame counter, which every frame it sends carries so a listener can tell a repeat from a new one.
var _voice_said: int = 0
## How long after its last frame a speaker stops being "talking". Two frames' worth plus slack: a speaker whose lamp
## flickered between frames would be worse than one that lingers a moment.
const TALK_QUIET_MSEC: int = 250

## ---- THE CHAT ------------------------------------------------------------------------------------
## See the design note above `chat_log`. Every piece of the wire's shape is there; this is what runs it.

## SAY A LINE. Returns "" when it is on its way, or why not, in words for the player who typed it. On the host it is
## accepted here and now; on a client it joins the outbox and is offered until the host takes it.
func say_in_chat(text: String) -> String:
	var why: String = ChatLine.problem(text)
	if not why.is_empty():
		return why
	var line: String = ChatLine.clean(text)
	if is_host or not is_networked():
		var me: int = maxi(Sim.local_client_id(), 1)
		_take_a_chat_line(me, line)
		return ""
	if not is_in_session:
		return "You are not in a session."
	if _chat_outbox.size() >= ChatLine.MOST_KEPT:
		return "Too many messages are still going out."
	_chat_outbox.append(line)
	_chat_next = 0
	return ""


## THE HOST TAKES A LINE, from a peer or from the player at the host, and it is here that a line gets its number. Every
## machine, the host included, draws a line because this ran -- so the host sees its own line the way everybody else
## sees it, which is the rule `Radio.publish_pcm` already follows for a spoken one.
func _take_a_chat_line(player: int, text: String) -> void:
	_chat_version += 1
	var line: Dictionary = {"n": _chat_version, "player": player, "text": text}
	chat_log.append(line)
	while chat_log.size() > ChatLine.MOST_KEPT:
		chat_log.pop_front()
	chat_arrived.emit(line)


## A LINE ARRIVING AT A CLIENT: drawn once, in order, and kept bounded. A repeat of one already taken is dropped
## silently -- the acknowledgement is what the host is waiting for, and it is sent whether or not the line was new.
func _hear_a_chat_line(said: Dictionary) -> void:
	var n: int = int(said["n"])
	_hello(1, {"say": "chatline_heard", "n": n})
	if n <= _chat_heard_to:
		return
	_chat_heard_to = n
	var line: Dictionary = {"n": n, "player": int(said["player"]), "text": String(said["text"])}
	chat_log.append(line)
	while chat_log.size() > ChatLine.MOST_KEPT:
		chat_log.pop_front()
	chat_arrived.emit(line)


## A PEER OFFERS A LINE. The host accepts it if it is the next one from that peer, acknowledges it either way so a
## repeat stops being repeated, and refuses to be told who said it: the player is who the peer IS, read off sync, never
## a field the peer filled in.
func _hear_a_chat_offer(peer: int, said: Dictionary) -> void:
	var n: int = int(said["n"])
	var already: int = int(_chat_from.get(peer, 0))
	_hello(peer, {"say": "chat_heard", "n": n})
	if n <= already:
		return
	if n != already + 1:
		# A GAP MEANS A LINE WAS LOST, and the peer is still offering the one before it. Acknowledging this one would
		# tell the peer to move on and leave the hole for ever, so it is not taken -- and the acknowledgement above
		# names `n`, which the peer compares with the line it is actually offering.
		push_warning("[net] a chat line %d from peer %d with %d taken; waiting for the one between" % [n, peer, already])
		return
	# WHO THAT PEER IS, asked of this host's own server first for the reason `_publish_roster_if_changed` gives: in a room
	# where nobody has a pilot there is no replicated pairing to read.
	var player: int = Sim.server_client_of_peer(peer)
	if player <= 0:
		player = Sim.client_of_peer(peer)
	if player <= 0:
		push_warning("[net] a chat line from peer %d, which is no player yet; dropped" % peer)
		return
	_chat_from[peer] = n
	_take_a_chat_line(player, String(said["text"]))


## WHAT THE CHAT OWES, every frame: a client offers its oldest unacknowledged line, and a host says each peer its oldest
## line that peer has not taken. Both again every `HELLO_EVERY_MSEC` until answered, which is how every other small fact
## in this file travels.
func _keep_the_chat() -> void:
	if not is_in_session or not is_networked():
		return
	var now: int = Time.get_ticks_msec()
	if not is_host:
		if not _chat_outbox.is_empty() and now >= _chat_next:
			_chat_next = now + HELLO_EVERY_MSEC
			_hello(1, {"say": "chat", "n": _chat_said + 1, "text": String(_chat_outbox[0])})
		return
	for peer in multiplayer.get_peers():
		var taken: int = int(_chat_taken.get(peer, 0))
		var owed: Dictionary = _oldest_chat_line_after(taken)
		if owed.is_empty():
			continue
		if now < int(_chat_owed_at.get(peer, 0)):
			continue
		_chat_owed_at[peer] = now + HELLO_EVERY_MSEC
		_hello(int(peer), {"say": "chatline", "n": int(owed["n"]), "player": int(owed["player"]),
			"text": String(owed["text"])})


## THE OLDEST LINE NEWER THAN `taken`, or {}. A peer that has been away longer than the log is caught up from the oldest
## line still kept rather than never caught up at all: the log is bounded on purpose (`ChatLine.MOST_KEPT`).
func _oldest_chat_line_after(taken: int) -> Dictionary:
	for line in chat_log:
		if int(line["n"]) > taken:
			return line
	return {}


## WHAT A CHAT HELLO MAY BE. Free text, which nothing else on this wire carries, so it is checked the way `ChatLine` says
## and dropped with a warning when it is not -- and the harness fails on any warning.
static func _read_the_chat(say: String, d: Dictionary) -> Dictionary:
	var n: Variant = d.get("n")
	if not (n is int or n is float) or float(n) != floorf(float(n)) or int(n) < 1 or int(n) > 1000000000:
		push_warning("[net] a chat hello with no line number; dropped")
		return {}
	var out: Dictionary = {"say": say, "n": int(n)}
	if say == "chat_heard" or say == "chatline_heard":
		return out
	if not d.get("text") is String or not ChatLine.acceptable(String(d["text"])):
		push_warning("[net] a chat line that is not a line anybody may send; dropped")
		return {}
	out["text"] = ChatLine.clean(String(d["text"]))
	if say == "chat":
		return out
	var player: Variant = d.get("player")
	if not (player is int or player is float) or float(player) != floorf(float(player)) or int(player) < 1 or int(player) > PLAYER_MOST:
		push_warning("[net] a chat line naming no player; dropped")
		return {}
	out["player"] = int(player)
	return out


## ---- THE VOICE -----------------------------------------------------------------------------------
## See the design note above `talking`.

## IS THIS PLAYER TALKING, as the host says. Every lamp on every machine asks this and nothing else.
func is_talking(client_id: int) -> bool:
	return talking.has(client_id)


## SEND ONE FRAME. A client offers it to its host; a host takes its own straight into the routing, so the host hears
## itself exactly the way everybody else does. Returns "" or why not.
func say_with_your_voice(bytes: PackedByteArray) -> String:
	var why: String = VoiceFrame.problem(bytes)
	if not why.is_empty():
		return why
	_voice_said += 1
	if not is_networked() or not is_in_session:
		return "You are not in a session."
	if is_host:
		var me: int = maxi(Sim.local_client_id(), 1)
		_route_a_voice_frame(me, VoiceFrame.stamp_the_speaker(bytes, me))
		return ""
	_carry(1, bytes, VOICE_BITS, "voice")
	return ""


## A FRAME ARRIVES. On a client it can only have come from the host and is announced. On a host it came from a player,
## and the host writes who that player IS before anybody sees it.
func _hear_a_voice_frame(from_peer: int, bytes: PackedByteArray) -> void:
	var label: Dictionary = VoiceFrame.label(bytes)
	if label.has("why"):
		push_warning("[net] a voice frame that is not one; dropped (%s)" % label["why"])
		return
	if not is_host:
		if from_peer != 1:
			push_warning("[net] a voice frame from peer %d, which is not the host; dropped" % from_peer)
			return
		voice_arrived.emit(bytes)
		return
	if not admitted.has(from_peer):
		push_warning("[net] a voice frame from peer %d before it was admitted; dropped" % from_peer)
		return
	# THE SPEAKER IS WHO THE PEER IS, never what the frame says. A sender that could name itself could put another
	# player's name on its own voice, and the lamp reads the same field.
	var speaker: int = Sim.server_client_of_peer(from_peer)
	if speaker <= 0:
		speaker = Sim.client_of_peer(from_peer)
	if speaker <= 0:
		push_warning("[net] a voice frame from peer %d, which is no player yet; dropped" % from_peer)
		return
	_route_a_voice_frame(speaker, VoiceFrame.stamp_the_speaker(bytes, speaker))


## WHO HEARS IT. The one place that answers it, so the sender's filter and the test that proves a third player is
## excluded cannot drift apart: `TeamBoard.share_a_team` decides, off the roster the host published.
##
## A TEAM FRAME FROM A PLAYER ON NO TEAM REACHES NOBODY, and that is deliberate rather than an oversight -- see
## `TeamBoard.share_a_team`. The lamp still lights, because talking is talking.
func _route_a_voice_frame(speaker: int, bytes: PackedByteArray) -> void:
	_talking_since[speaker] = Time.get_ticks_msec()
	var label: Dictionary = VoiceFrame.label(bytes)
	var to_the_team: bool = int(label.get("audience", VoiceFrame.Audience.EVERYONE)) == VoiceFrame.Audience.TEAM
	var mine: int = team_of(speaker)
	for peer in multiplayer.get_peers():
		if not admits(int(peer)):
			continue
		var listener: int = Sim.server_client_of_peer(int(peer))
		if listener <= 0:
			listener = Sim.client_of_peer(int(peer))
		if listener == speaker:
			continue
		if to_the_team and not TeamBoard.share_a_team(mine, team_of(listener)):
			continue
		_carry(int(peer), bytes, VOICE_BITS, "voice")
	# AND THE HOST ITSELF, which is a listener like any other and subject to the same filter.
	var me: int = Sim.local_client_id()
	if me != speaker and (not to_the_team or TeamBoard.share_a_team(mine, team_of(me))):
		voice_arrived.emit(bytes)


## WHAT THE TALKING SET OWES: recompute it, and say it again to anybody who has not acknowledged the current one.
func _keep_the_talking() -> void:
	if not is_host or not is_in_session:
		return
	var now: int = Time.get_ticks_msec()
	var still: Array = []
	for client in _talking_since.keys():
		if now - int(_talking_since[client]) <= TALK_QUIET_MSEC:
			still.append(int(client))
		else:
			_talking_since.erase(client)
	still.sort()
	if still != talking:
		talking = still
		_talking_version += 1
		talking_changed.emit()
		for peer in multiplayer.get_peers():
			_talking_owed[peer] = 0
	if not is_networked():
		return
	for peer in _talking_owed.keys():
		if now < int(_talking_owed[peer]):
			continue
		if peer not in multiplayer.get_peers():
			_talking_owed.erase(peer)
			continue
		_talking_owed[peer] = now + HELLO_EVERY_MSEC
		_hello(int(peer), {"say": "talking", "n": _talking_version, "who": talking})


## WHAT A TALKING HELLO MAY BE: a revision and a list of player numbers, each one a number a player could have.
static func _read_the_talking(say: String, d: Dictionary) -> Dictionary:
	var n: Variant = d.get("n")
	if not (n is int or n is float) or float(n) != floorf(float(n)) or int(n) < 0 or int(n) > 1000000000:
		push_warning("[net] a talking hello with no revision; dropped")
		return {}
	if say == "talking_heard":
		return {"say": say, "n": int(n)}
	if not d.get("who") is Array or (d["who"] as Array).size() > MAX_PLAYERS:
		push_warning("[net] a talking hello with the wrong number of speakers; dropped")
		return {}
	var who: Array = []
	for player in d["who"]:
		if not (player is int or player is float) or float(player) != floorf(float(player)) or int(player) < 1 or int(player) > PLAYER_MOST or who.has(int(player)):
			push_warning("[net] a talking hello naming no player, or one twice; dropped")
			return {}
		who.append(int(player))
	return {"say": say, "n": int(n), "who": who}


## ---- THE SKY: WHAT THE WORLD IS, NOT WHAT A MACHINE CAN AFFORD TO DRAW ---------------------------------------------
##
## Plan item 17, asked for on 2026-09-15: "time of day and other level options are not synced, graphics detail shouldn't
## be synced, but time of day should. Toggle clouds could also be a networked choice." Until this the TIME tab and the
## time-of-day dial set `FlightLevel.daylight` on the machine they were pressed on and nowhere else, so a pilot who chose
## night flew at night beside a copilot flying in the afternoon (agents.md, WHAT IS NOT HERE YET, since 2026-09-13).
##
## THE LINE IS WHO IT IS ABOUT. The time of day and whether there are clouds are facts about the WORLD everybody in the
## session is standing in, so they are the host's and every machine is told. The finish (`Finish`), the fog clouds a
## Forward+ machine may be asked to draw (`CloudBank.asked_for`) and anything else a weaker machine turns down are about
## what THIS machine can afford, and stay on it -- a client turning its own detail down is correct, and one whose detail
## followed the host's would be a bug with the host's frame rate attached.
##
## TWO MESSAGES, AND THE LEVEL HELLO CARRIES THE SAME FIELDS:
##
##   host -> peer   {"say": "sky", "clock", "frame", "rate", "clouds", "n"}   again every 200 ms until heard with this `n`
##   peer -> host   {"say": "sky_heard", "n"}                                  to every `sky`, however often it comes
##   host -> joiner {"say": "level", ..., "clock", "frame", "rate", "clouds", "n"}   so a joiner BUILDS under the host's sky
##
## THE TIME OF DAY IS A CLOCK (2026-09-18), said as WHERE IT WAS AND HOW FAST IT RUNS, NOT AS A STREAM: `clock` minutes at
## the session's `frame`, running `rate` game seconds a real second. Every machine works out the time for itself from the
## session's frame -- the server's, which a client estimates (`estimated_server_frame`), the same clock the music's fades are
## kept on -- so a running clock costs no packets at all, and the sky is said again only when somebody sets it. Two
## machines' suns agree to the sky's own step (`Daylight.STEP_DEGREES`) and the estimate's few frames, which at the
## fastest rate is a hundredth of a degree. REJECTED: saying the time every second, which is a packet a second per peer and
## still a second stale; and the time alone with the rate kept per machine, which is two skies drifting apart.
##
## `n` counts the host's changes this session, and a peer takes a sky only with an `n` above the last it took: the carrier
## is unreliable over Steam, so a level hello said before a change can arrive after the `sky` that announced it, and
## would otherwise put the old time back. The level hello is not answered for its sky -- `loaded` answers it -- so an
## admitted peer is owed a `sky` as well, which closes the gap between its `loaded` and a change made meanwhile.
##
## Rejected: a replicated component in the simulation, which is C++ and a tuned wire for a value that changes a few
## times an evening; saying the sky every second for ever, which would be simpler and is a packet a second per peer for
## the life of the session to save one counter; and the lobby's written-down data, which ENet does not have.

## THE TIME-LAPSE: a whole day in ten seconds, 8,640 game seconds a real second. "Make sure the time of day work results in
## a sunrise/sunset/moonrise (at very fast speed, shorter than 10 seconds), so we can see the full time of day cycle" (the
## user, 2026-09-18). The TIME tab's TIMELAPSE button, and the fastest the clock may run: a rate said faster is clamped here
## and the clamp said, as every magnitude off the wire is (CLAUDE.md, rule 8). Until then the most was 3,600, an hour a
## second.
const CLOCK_RATE_LAPSE: float = 8640.0
const CLOCK_RATE_MOST: float = CLOCK_RATE_LAPSE
## THE RATE A SESSION STARTS AT: real time, so the sun moves as the user asked it to -- slowly, a quarter of a degree a
## minute, which no suite sees. `--clock-rate=` after the bare `--` says otherwise.
const CLOCK_RATE_START: float = 1.0

## THE CLOCK THIS SESSION IS UNDER: minutes at `clock_frame` of the session's frames, running `clock_rate` game seconds a real
## second. The host's, on every machine in a session. Read it with `clock_now`.
var clock_at: float = 0.0
var clock_frame: float = 0.0
var clock_rate: float = CLOCK_RATE_START
## WHETHER `clock_frame` IS A FRAME OF THE SESSION'S (a client's estimate of the server's) or this machine's own physics
## frames, which is all a machine has before it has joined anything. See `_session_frame`.
var _clock_on_the_session: bool = false
## WHETHER THIS SESSION'S SKY HAS CLOUDS IN IT. The host's, like the time. Not the fog clouds, which are a local choice.
var clouds_on: bool = true
## The host's: how many times the sky has changed this session, which every `sky` said carries as `n`.
var _sky_version: int = 0
## The host's: peer -> when to say the sky to it again, until it answers with the current `n`.
var _sky_owed: Dictionary = {}
## A peer's: the highest `n` it has taken from its host, or -1.
var _sky_heard: int = -1


## WHETHER THIS MACHINE DECIDES THE SKY: a host, or a machine in no networked session at all (solo, the desk, a bench).
## THE AUTHORITY QUESTION, NAMED (CLAUDE.md rule 10), and asked by everything that would change the sky or say who may.
func decides_the_sky() -> bool:
	return is_host or not is_networked()


## THE SESSION'S CLOCK NOW, minutes, 0 to 1440: where it was said to be, run on at its rate for the frames since.
func clock_now() -> float:
	var frame: float = _clock_frame_now()
	if is_nan(frame):
		return fposmod(clock_at, Orrery.DAY_LONG)
	return fposmod(clock_at + (frame - clock_frame) / maxf(Sim.tick_hz, 1.0) * clock_rate / 60.0, Orrery.DAY_LONG)


## The frame the clock is counted in now, re-counting the clock from this machine's own frames onto the session's the first
## time the session has one -- a host sets its sky before its own client is running -- so the time does not jump by however
## many frames this machine ran before. NAN on a joiner with no estimate yet: its clock stands where its host said.
func _clock_frame_now() -> float:
	var on_the_session: bool = Sim.client != null and Sim.client.has_method("timing")
	if on_the_session and not _clock_on_the_session:
		if decides_the_sky():
			clock_at = snappedf(clock_at + (float(Engine.get_physics_frames()) - clock_frame) / maxf(Sim.tick_hz, 1.0)
				* clock_rate / 60.0, 0.001)
			clock_frame = roundf(_session_frame())
		_clock_on_the_session = true
	if not on_the_session and not decides_the_sky():
		return NAN
	return _session_frame() if _clock_on_the_session else float(Engine.get_physics_frames())


## The session's frame as this machine knows it: its client's estimate of the server's, or its own physics frames.
func _session_frame() -> float:
	if Sim.client != null and Sim.client.has_method("timing"):
		return float(Sim.client.timing().get("estimated_server_frame", Engine.get_physics_frames()))
	return float(Engine.get_physics_frames())


## CHOOSE A PRESET'S TIME OF DAY -- a `DaylightTuning.When`, its point on the clock -- keeping the rate: "" when it was taken,
## a sentence when it was not. Announced by the TIME tab and the dial, and decided here, because it is the session's.
func choose_time(which: int) -> String:
	if which < 0 or which >= DaylightTuning.When.size():
		return "There is no such time of day."
	return choose_clock(DaylightTuning.clock_of(which))


## CHOOSE THE CLOCK, minutes, keeping its rate: "" when it was taken, a sentence when it was not.
func choose_clock(minutes: float) -> String:
	if is_nan(minutes) or is_inf(minutes):
		return "That is not a time of day."
	if not decides_the_sky():
		return "The host sets the time of day."
	_set_the_clock(fposmod(minutes, Orrery.DAY_LONG), clock_rate)
	return ""


## CHOOSE HOW FAST THE CLOCK RUNS, game seconds a real second, from the time it is now: "" when it was taken, a sentence when
## it was not. Over `CLOCK_RATE_MOST` is clamped, as a rate off the wire is.
func choose_rate(rate: float) -> String:
	if is_nan(rate) or rate < 0.0:
		return "That is not a rate a clock runs at."
	if not decides_the_sky():
		return "The host sets how fast the time of day runs."
	_set_the_clock(clock_now(), minf(rate, CLOCK_RATE_MOST))
	return ""


## THE CLOCK, SET: said from now, and told to every peer, unless it is already that.
func _set_the_clock(minutes: float, rate: float) -> void:
	if is_equal_approx(minutes, clock_now()) and is_equal_approx(rate, clock_rate):
		return
	_anchor_the_clock(minutes, rate)
	_changed_the_sky()


## WHERE THE CLOCK IS SAID FROM, SNAPPED to what the wire says -- a thousandth of a minute, a whole frame, a thousandth of a
## rate -- so the host runs the very clock its peers are told, and a level hello with eight names in it still fits
## `HELLO_MOST_BYTES` (tests/names.gd: 521 bytes with every figure a float carries, over the 512).
func _anchor_the_clock(minutes: float, rate: float) -> void:
	_clock_on_the_session = Sim.client != null and Sim.client.has_method("timing")
	clock_at = snappedf(minutes, 0.001)
	clock_rate = snappedf(rate, 0.001)
	clock_frame = roundf(_session_frame())


## CHOOSE WHETHER THERE ARE CLOUDS: "" when it was taken, a sentence when it was not. The same authority as the time.
func choose_clouds(on: bool) -> String:
	if not decides_the_sky():
		return "The host decides whether there are clouds."
	if on != clouds_on:
		clouds_on = on
		_changed_the_sky()
	return ""


## THE SKY A SESSION OF THIS MACHINE'S OWN STARTS UNDER: `--time=` and `--clock-rate=` on the command line, or the start
## (DAY, at real time), and clouds. Called by the doors `suit_the_session` is called by, and at boot. A joiner is not one of
## them: its host tells it.
##
## PER SESSION, NOT KEPT, which is the opposite of `level`: the desk has nowhere to choose a time, so a sky kept from the
## last session would be one nobody on this screen chose -- a joiner back from a friend's night flight flying alone in
## the dark with no idea why.
func _start_the_sky() -> void:
	var asked: float = Daylight.asked_on_the_command_line()
	var rate: float = Daylight.rate_asked_on_the_command_line()
	_anchor_the_clock(asked if asked >= 0.0 else DaylightTuning.clock_of(DaylightTuning.START),
		rate if rate >= 0.0 else CLOCK_RATE_START)
	clouds_on = true
	_sky_version = 0
	_sky_owed.clear()
	sky_changed.emit()


func _changed_the_sky() -> void:
	_sky_version += 1
	var now: int = Time.get_ticks_msec()
	for peer in admitted.keys():
		_sky_owed[int(peer)] = now
	_report("NET_SKY clock=%s rate=%s clouds=%s n=%d peers=%d" % [Orrery.words(clock_now()), clock_rate, clouds_on,
		_sky_version, _sky_owed.size()])
	sky_changed.emit()
	# THE LEVEL CUE OWNS THE NOTICE SURFACE until its countdown has finished. A sky choice still changes the shared
	# world while everybody is being called elsewhere, but it must not erase the warning which says why the screen is
	# about to go black. Otherwise each choice uses the same revisioned, acknowledged stream as joins and leaves; two
	# quick choices naturally leave only the newest revision on show and in the resend queue.
	if _called.is_empty():
		_notify({"kind": "sky", "clock": clock_now(), "rate": clock_rate, "clouds": clouds_on})


## THE CLOCK AS A NOTICE SAYS IT: "17:45", and how it runs when that is not real time -- "17:45, FROZEN", "17:45 AT 60X".
static func clock_words(minutes: float, rate: float) -> String:
	if rate <= 0.0:
		return "%s, FROZEN" % Orrery.words(minutes)
	if is_equal_approx(rate, 1.0):
		return Orrery.words(minutes)
	return "%s AT %sX" % [Orrery.words(minutes), String.num(rate, 1).trim_suffix(".0")]


## The sky's fields as a hello says them.
func _the_sky_said() -> Dictionary:
	# A CLIENT'S FRAME, ALWAYS: said in the session's frames, so the host re-counts its clock onto them first if it can.
	_clock_frame_now()
	return {"clock": clock_at, "frame": clock_frame, "rate": clock_rate, "clouds": clouds_on, "n": _sky_version}


## A STATISTICS CARD OR A BOARD, CHECKED. Untrusted input proposes and the host disposes (CLAUDE.md, rule 8): a row
## that is not a row would otherwise reach a board as null columns, and a board of ten thousand rows would reach it as
## a frozen frame. Every row is checked by the one predicate both ends use, and a board is cut to the session's size.
static func _read_the_stats(say: String, d: Dictionary) -> Dictionary:
	if say == "netstats":
		if not NetStats.is_a_row(d.get("row")):
			push_warning("[net] a statistics card that is not a row; dropped")
			return {}
		return {"say": say, "row": d["row"]}
	if not d.get("rows") is Array or (d["rows"] as Array).size() > MAX_PLAYERS:
		push_warning("[net] a statistics board of %s rows; dropped" % [
			(d["rows"] as Array).size() if d.get("rows") is Array else "no"])
		return {}
	for row in d["rows"] as Array:
		if not NetStats.is_a_row(row):
			push_warning("[net] a statistics board with a row that is not a row; dropped")
			return {}
	var page: Dictionary = _read_page(d)
	if page.is_empty():
		return {}
	page.merge({"say": say, "rows": d["rows"]})
	return page


## A PAGE OF A RADAR PICTURE, validated before anything draws it. `RadarSet.is_a_row` owns the shape.
##
## EVERY ROW OR NONE. One bad row drops the whole page rather than being skipped, because a plot missing a contact it
## was sent is worse than a plot missing a page: the page is replaced in a second, and a silently shortened picture
## would look exactly like the terrain hiding something. It warns, and the harness fails on a warning.
static func _read_the_radar(d: Dictionary) -> Dictionary:
	if not d.get("rows") is Array or (d["rows"] as Array).size() > RadarSet.MOST_PER_PAGE:
		push_warning("[net] a radar page of %s contacts; dropped" % [
			(d["rows"] as Array).size() if d.get("rows") is Array else "no"])
		return {}
	for row in d["rows"] as Array:
		if not RadarSet.is_a_row(row):
			push_warning("[net] a radar page with a contact that is not a contact; dropped")
			return {}
	var page: Dictionary = _read_page(d)
	if page.is_empty():
		return {}
	# THE SWEEP NUMBER, which is what a reader starts a fresh picture on. Bounded like every other counter here.
	var sweep: Variant = d.get("n", 0)
	if not (sweep is int or sweep is float) or float(sweep) != floorf(float(sweep)) 			or float(sweep) < 0.0 or float(sweep) > 1000000000.0:
		push_warning("[net] a radar page with no sweep number; dropped")
		return {}
	page.merge({"say": "radar", "rows": d["rows"], "n": int(sweep)})
	return page


## THE HOST SAID THE SKY, in a `sky` or a level hello `read_hello` passed. Taken when it is newer than the last one taken;
## a `sky` is answered either way, since an answer lost is what makes the host say it again.
func _hear_the_sky(said: Dictionary, answer: bool) -> void:
	var n: int = int(said["n"])
	if answer:
		_hello(1, {"say": "sky_heard", "n": n})
	if n <= _sky_heard:
		return
	_sky_heard = n
	var changed: bool = float(said["clock"]) != clock_at or float(said["frame"]) != clock_frame \
		or float(said["rate"]) != clock_rate or bool(said["clouds"]) != clouds_on
	clock_at = float(said["clock"])
	clock_frame = float(said["frame"])
	clock_rate = float(said["rate"])
	_clock_on_the_session = true
	clouds_on = bool(said["clouds"])
	if changed:
		_report("NET_SKY_HEARD clock=%s rate=%s clouds=%s n=%d" % [Orrery.words(clock_now()), clock_rate, clouds_on, n])
		sky_changed.emit()


## A `sky` or a `sky_heard`, CHECKED, as `read_hello` checks the rest. A clock, a frame or a rate that is not a number, clouds
## that are not yes or no, or a count that is not a count is dropped and said. The clock and the rate are MAGNITUDES, and
## are clamped with a warning rather than dropped (CLAUDE.md, rule 8): a clock of 1440 is midnight said the long way, and a
## rate past `CLOCK_RATE_MOST` is the fastest one.
static func _read_the_sky(say: String, d: Dictionary) -> Dictionary:
	var n: Variant = d.get("n")
	if not (n is float or n is int) or float(n) != floorf(float(n)) or float(n) < 0.0 or float(n) > 1.0e9:
		push_warning("[net] a %s hello with no count; dropped" % say)
		return {}
	if say == "sky_heard":
		return {"say": say, "n": int(n)}
	var clock: Variant = d.get("clock")
	var frame: Variant = d.get("frame")
	var rate: Variant = d.get("rate")
	if not (clock is float or clock is int) or is_nan(float(clock)) or is_inf(float(clock)) \
			or not (frame is float or frame is int) or is_nan(float(frame)) or absf(float(frame)) > 1.0e12 \
			or not (rate is float or rate is int) or is_nan(float(rate)) or is_inf(float(rate)):
		push_warning("[net] a sky hello with no clock, frame and rate; dropped")
		return {}
	if not d.get("clouds") is bool:
		push_warning("[net] a sky hello that does not say whether there are clouds; dropped")
		return {}
	var minutes: float = clampf(float(clock), 0.0, Orrery.DAY_LONG)
	if minutes != float(clock):
		push_warning("[net] a sky at %s minutes, clamped to %s" % [clock, minutes])
	var runs: float = clampf(float(rate), 0.0, CLOCK_RATE_MOST)
	if runs != float(rate):
		push_warning("[net] a sky clock running at %s, clamped to %s" % [rate, runs])
	return {"say": say, "clock": minutes, "frame": float(frame), "rate": runs, "clouds": bool(d["clouds"]), "n": int(n)}


## ---- MUSIC: SMALL SESSION STATE, AUDIO FILES STAY LOCAL ------------------------------------------------------------

const MUSIC_DB_MIN := -60.0
const MUSIC_DB_MAX := 0.0
var music_state: Dictionary = empty_music_state()
var _music_version := 0
var _music_owed: Dictionary = {}
var _music_heard := -1


static func empty_music_state() -> Dictionary:
	return {"track": "", "started_frame": 0.0, "volume_from": -12.0, "volume_to": -12.0,
		"fade_from_frame": 0.0, "fade_frames": 0.0, "music_n": 0}


func decides_the_music() -> bool:
	return is_host or not is_networked()


## Set a track (empty stops) and its target level. A fade is represented by two frames, so peers need no volume stream.
func choose_music(track: String, target_db: float = -12.0, fade_seconds: float = 0.0) -> String:
	if not decides_the_music():
		return "Only the host chooses the music."
	if not track.is_empty() and not RecordShelf.valid_id(track):
		return "That is not a music id."
	if not is_finite(target_db) or target_db < MUSIC_DB_MIN or target_db > MUSIC_DB_MAX:
		return "Music volume must be between -60 and 0 dB."
	if not is_finite(fade_seconds) or fade_seconds < 0.0 or fade_seconds > 60.0:
		return "A music fade must be between 0 and 60 seconds."
	var frame := _music_frame()
	var from_db := _music_volume_at(frame)
	if track != String(music_state.get("track", "")):
		music_state["started_frame"] = frame
		from_db = target_db if fade_seconds <= 0.0 else MUSIC_DB_MIN
	music_state["track"] = track
	music_state["volume_from"] = from_db
	music_state["volume_to"] = target_db
	music_state["fade_from_frame"] = frame
	music_state["fade_frames"] = fade_seconds * Sim.tick_hz
	_changed_the_music()
	return ""


func fade_music(target_db: float, seconds: float) -> String:
	return choose_music(String(music_state.get("track", "")), target_db, seconds)


func _music_volume_at(frame: float) -> float:
	var duration := float(music_state.get("fade_frames", 0.0))
	if duration <= 0.0:
		return float(music_state.get("volume_to", -12.0))
	var at := clampf((frame - float(music_state.get("fade_from_frame", frame))) / duration, 0.0, 1.0)
	return lerpf(float(music_state.get("volume_from", -12.0)), float(music_state.get("volume_to", -12.0)), at)


func _music_frame() -> float:
	if Sim.client != null and Sim.client.has_method("timing"):
		return float(Sim.client.timing().get("estimated_server_frame", Engine.get_physics_frames()))
	return float(Engine.get_physics_frames())


func _changed_the_music() -> void:
	_music_version += 1
	music_state["music_n"] = _music_version
	var now := Time.get_ticks_msec()
	for peer in admitted.keys():
		_music_owed[int(peer)] = now
	_report("NET_MUSIC track=%s n=%d peers=%d" % [music_state["track"], _music_version, _music_owed.size()])
	music_changed.emit()


func _the_music_said() -> Dictionary:
	return {"music": String(music_state.get("track", "")),
		"music_started": float(music_state.get("started_frame", 0.0)),
		"music_from": float(music_state.get("volume_from", -12.0)),
		"music_to": float(music_state.get("volume_to", -12.0)),
		"music_fade_at": float(music_state.get("fade_from_frame", 0.0)),
		"music_fade_frames": float(music_state.get("fade_frames", 0.0)),
		"music_n": _music_version}


## Compact only inside the level hello, which also carries eight roster cards and remains
## bounded to 512 bytes. Standalone music messages retain named fields for clarity.
func _music_level_said() -> Dictionary:
	return {"music_state": [String(music_state.get("track", "")),
		float(music_state.get("started_frame", 0.0)), float(music_state.get("volume_from", -12.0)),
		float(music_state.get("volume_to", -12.0)), float(music_state.get("fade_from_frame", 0.0)),
		float(music_state.get("fade_frames", 0.0)), _music_version]}


func _hear_the_music(said: Dictionary, answer: bool) -> void:
	var n := int(said["music_n"])
	if answer:
		_hello(1, {"say": "music_heard", "music_n": n})
	if n <= _music_heard:
		return
	_music_heard = n
	music_state = {"track": String(said["music"]), "started_frame": float(said["music_started"]),
		"volume_from": float(said["music_from"]), "volume_to": float(said["music_to"]),
		"fade_from_frame": float(said["music_fade_at"]), "fade_frames": float(said["music_fade_frames"]),
		"music_n": n}
	music_changed.emit()


static func _read_the_music(say: String, d: Dictionary) -> Dictionary:
	var n: Variant = d.get("music_n")
	if not (n is float or n is int) or float(n) != floorf(float(n)) or float(n) < 0.0 or float(n) > 1.0e9:
		push_warning("[net] a %s hello with no music count; dropped" % say)
		return {}
	if say == "music_heard":
		return {"say": say, "music_n": int(n)}
	if not d.get("music") is String or (not String(d["music"]).is_empty() and not RecordShelf.valid_id(String(d["music"]))):
		push_warning("[net] a music hello naming no track id; dropped")
		return {}
	var keys := ["music_started", "music_from", "music_to", "music_fade_at", "music_fade_frames"]
	for key in keys:
		var value: Variant = d.get(key)
		if not (value is float or value is int) or not is_finite(float(value)):
			push_warning("[net] a music hello with no %s number; dropped" % key)
			return {}
	if float(d["music_from"]) < MUSIC_DB_MIN or float(d["music_from"]) > MUSIC_DB_MAX \
			or float(d["music_to"]) < MUSIC_DB_MIN or float(d["music_to"]) > MUSIC_DB_MAX \
			or float(d["music_started"]) < 0.0 or float(d["music_fade_at"]) < 0.0 \
			or float(d["music_fade_frames"]) < 0.0 or float(d["music_fade_frames"]) > 7200.0:
		push_warning("[net] a music hello with values out of range; dropped")
		return {}
	return {"say": say, "music": String(d["music"]), "music_started": float(d["music_started"]),
		"music_from": float(d["music_from"]), "music_to": float(d["music_to"]),
		"music_fade_at": float(d["music_fade_at"]), "music_fade_frames": float(d["music_fade_frames"]),
		"music_n": int(n)}


## ---- THE NOTICES: WHAT EVERYBODY IN THE SESSION SHOULD BE TOLD ------------------------------------------------------
##
## Plan item 13, asked for on 2026-09-15: "we need a notification system so we know when users join, leave, or other
## important things happen." BUILT AGAINST THE LEVEL CHANGE FIRST, because that is the case somebody had already hit:
## `lane/lobby` left "nothing yet says a level change is coming. The client learns about it when its screen goes away."
## Who joined and who left then fell out of the same three things -- a notice, a message that carries it, and a line.
##
## A NOTICE IS A KIND AND ITS FACTS, NEVER A SENTENCE. {"kind": "level", "level": id, "hash", "in": ms} /
## {"kind": "joined" |
## "left", "player": n}. Every machine writes its own words (`notice_words`), so nothing a host sends is text another
## machine prints: untrusted input proposes (CLAUDE.md rule 8), and a kind this build has no words for is dropped, said.
##
##   host -> peer   {"say": "notice", "kind", ..., "n"}   again every 200 ms until heard with this `n`
##   peer -> host   {"say": "notice_heard", "n"}         to every `notice`
##
## Only the latest notice is owed: a board has one line for it, and a joined that is overtaken by a level change a moment
## later is not news anybody needs afterwards. `in` is the time LEFT when that copy was said, so a copy said again later
## says less, and no two clocks have to agree.
##
## THE HOST ANNOUNCES A LEVEL CHANGE AND MAKES IT `LEVEL_WARNING_MSEC` LATER (`call_the_level`), because a warning
## delivered with the change is the screen going away with words on it. `change_level` itself stays immediate: it is the
## handshake, and the suites that call it are about the handshake. AND NOT WHEN NOBODY IS THERE TO BE TOLD (team-lead,
## 2026-09-16). Since 2026-09-17, a player alone gets the short local cue needed to animate the same curtain.
##
## Rejected: the HUD, which is off by default, so a notice there is one nobody sees (the board and the flat status line
## carry it instead, and the flat line is what makes it testable without a headset); and free text on the wire, which is
## the first thing a validator would have to learn to distrust.

## How long a host warns its peers before the level changes, milliseconds.
const LEVEL_WARNING_MSEC: int = 3000
## A SOLO/HOST-ALONE launch still gets enough time to fade rather than cutting straight to black. Networked sessions use
## the longer warning above. This is wall time because the cue's countdown and the scene change both use ticks_msec.
const LEVEL_LOCAL_CUE_MSEC: int = 500
## How long a notice stays on a board after it is said, or after the level change it warned of, milliseconds.
const NOTICE_MSEC: int = 6000
## The kinds of notice there are, and the facts each carries besides its kind.
const NOTICE_KINDS: Dictionary = {"level": ["level", "hash", "in"], "joined": ["player"], "left": ["player"],
	"sky": ["clock", "rate", "clouds"]}
## The highest player number a notice may name: sync's client ids, which the CREW page prints.
const PLAYER_MOST: int = 65535

## THE NOTICE ON SHOW on this machine: its kind and facts, plus `shown_until` and (for a level) `due`, both in this
## machine's own `Time.get_ticks_msec`. {} when there is none.
var notice: Dictionary = {}
## The host's: a level change announced and not yet made -- {"level", "due"} -- or {}.
var _called: Dictionary = {}
## The host's: how many notices it has said this session, which every one carries as `n`.
var _notice_version: int = 0
## The host's: peer -> when to say the latest notice to it again, until it answers with the current `n`.
var _notice_owed: Dictionary = {}
## A peer's: the highest `n` it has taken, or -1.
var _notice_heard: int = -1
## The host's: peer -> the player number it was announced as, once it had one. See `_keep_the_notices`.
var _players: Dictionary = {}


## WHETHER A LEVEL CHANGE HERE WOULD HAVE ANYBODY TO WARN: a peer admitted, or still being told the level.
## The question the warning's delay hangs on, named.
func has_anybody_to_tell() -> bool:
	return is_networked() and not (admitted.is_empty() and _telling.is_empty())


## CALL THE SESSION TO ANOTHER LEVEL: warn everybody and change it `LEVEL_WARNING_MSEC` later, or use the short local
## curtain cue when there is nobody to warn. "" when it was taken, a sentence when it was not, in `change_level`'s words.
func call_the_level(id: String) -> String:
	# Validate in `change_level`'s words before scheduling anything. A valid user launch always goes through a cue, even
	# alone: otherwise there is no interval in which a fade-to-black can be an animation.
	if not is_in_session or not is_host or ChartDrawer.chart(id) == null or id == level:
		return change_level(id)
	if not _called.is_empty():
		var going: LevelChart = ChartDrawer.chart(String(_called["level"]))
		return "Already going to %s." % (going.name if going != null else String(_called["level"]))
	var wait_msec: int = LEVEL_WARNING_MSEC if has_anybody_to_tell() else LEVEL_LOCAL_CUE_MSEC
	_called = {"level": id, "due": Time.get_ticks_msec() + wait_msec}
	_notify({"kind": "level", "level": id, "hash": ChartDrawer.chart(id).content_hash, "in": wait_msec})
	return ""


## Milliseconds until a called level change is made, or -1 when none is called.
func level_called_in() -> int:
	return maxi(0, int(_called["due"]) - Time.get_ticks_msec()) if not _called.is_empty() else -1


## A NOTICE ON THIS MACHINE AND, ON A HOST, TO EVERY ADMITTED PEER. A peer cannot notify: it is told.
func _notify(said: Dictionary) -> void:
	if not decides_the_sky():
		return
	_notice_version += 1
	var now: int = Time.get_ticks_msec()
	for peer in admitted.keys():
		_notice_owed[int(peer)] = now
	_show_the_notice(said)
	_report("NET_NOTICE kind=%s n=%d peers=%d" % [said["kind"], _notice_version, _notice_owed.size()])


## THE HOST'S ROUNDS, once a frame: the called level made when it is due, a joiner announced once sync has given it a
## number, and the latest notice said to whoever has not heard it.
func _keep_the_notices() -> void:
	var now: int = Time.get_ticks_msec()
	if not _called.is_empty() and now >= int(_called["due"]):
		var id: String = String(_called["level"])
		_called = {}
		var why: String = change_level(id)
		if why != "":
			push_warning("[net] the level called was not changed: %s" % why)
	if not is_host or not is_networked():
		return
	# WHO JOINED: an admitted peer, announced once for the session, and only once sync has named it -- a player number the
	# CREW page will never show would be a name nobody can find. Held across level changes, which re-admit everybody.
	# A joined line is allowed to wait; a level cue is not. Notices intentionally retain only the latest revision, so do
	# not replace the active cue while its countdown is running. The peer is announced after it is admitted on the new level.
	if _called.is_empty():
		for peer in admitted.keys():
			if _players.has(peer):
				continue
			var player: int = Sim.client_of_peer(int(peer))
			if player > 0:
				_players[peer] = player
				_notify({"kind": "joined", "player": player})
	if _notice_owed.is_empty():
		return
	for peer in _notice_owed.keys():
		if now < int(_notice_owed[peer]):
			continue
		_notice_owed[peer] = now + HELLO_EVERY_MSEC
		if peer in multiplayer.get_peers():
			var said: Dictionary = {"say": "notice", "n": _notice_version}
			for key in NOTICE_KINDS[String(notice.get("kind", "joined"))]:
				said[key] = notice.get(key)
			said["kind"] = notice.get("kind")
			if said["kind"] == "level":
				said["in"] = maxi(0, int(notice.get("due", now)) - now)
			_hello(int(peer), said)


## A NOTICE FROM THE HOST, `read_notice` passed: answered always, taken when newer.
func _hear_the_notice(said: Dictionary) -> void:
	var n: int = int(said["n"])
	_hello(1, {"say": "notice_heard", "n": n})
	if n <= _notice_heard:
		return
	_notice_heard = n
	_show_the_notice(said)
	_report("NET_NOTICE_HEARD kind=%s n=%d" % [said["kind"], n])


func _show_the_notice(said: Dictionary) -> void:
	var now: int = Time.get_ticks_msec()
	notice = {"kind": String(said["kind"])}
	for key in NOTICE_KINDS[notice["kind"]]:
		notice[key] = said[key]
	if notice["kind"] == "level":
		notice["due"] = now + int(said["in"])
		notice["shown_until"] = int(notice["due"]) + NOTICE_MSEC
		var revision: int = int(said.get("n", _notice_version))
		level_cued.emit({"kind": "level", "target": String(notice["level"]), "hash": String(notice["hash"]),
			"revision": revision, "epoch": session_epoch, "due": int(notice["due"])})
	else:
		notice["shown_until"] = now + NOTICE_MSEC
	noticed.emit()


## WHAT THE NOTICE ON SHOW SAYS, NOW, in this machine's words: "" when there is none or it has run its time. Asked by the
## board and the flat status line every time they are drawn, so a count-down counts down.
func notice_words() -> String:
	if notice.is_empty() or Time.get_ticks_msec() > int(notice["shown_until"]):
		return ""
	match String(notice["kind"]):
		"level":
			var chart: LevelChart = ChartDrawer.chart(String(notice["level"]))
			var name: String = chart.name if chart != null else String(notice["level"])
			var left_ms: int = int(notice["due"]) - Time.get_ticks_msec()
			if left_ms > 0:
				return "EVERYBODY TO %s IN %d S" % [name.to_upper(), ceili(float(left_ms) / 1000.0)]
			return "EVERYBODY TO %s" % name.to_upper()
		"joined":
			if int(notice["player"]) == Sim.local_client_id():
				return "YOU JOINED AS %s" % name_of(int(notice["player"])).to_upper()
			return "%s JOINED" % name_of(int(notice["player"])).to_upper()
		"left":
			return "%s LEFT" % name_of(int(notice["player"])).to_upper()
		"sky":
			return "SKY: %s, CLOUDS %s" % [clock_words(float(notice["clock"]), float(notice["rate"])),
				"ON" if bool(notice["clouds"]) else "OFF"]
	return ""


## A `notice` or a `notice_heard`, CHECKED: a kind there are no words for, a level that is not a level id, a player number
## out of range, or a count-down that is not a count of milliseconds is dropped and said. The count-down is CLAMPED to
## the warning's length rather than dropped -- it is a magnitude, and a host whose copy was delayed is not lying.
static func _read_the_notice(say: String, d: Dictionary) -> Dictionary:
	var n: Variant = d.get("n")
	if not (n is float or n is int) or float(n) != floorf(float(n)) or float(n) < 0.0 or float(n) > 1.0e9:
		push_warning("[net] a %s with no count; dropped" % say)
		return {}
	if say == "notice_heard":
		return {"say": say, "n": int(n)}
	var kind: String = String(d.get("kind")) if d.get("kind") is String else ""
	if not NOTICE_KINDS.has(kind):
		push_warning("[net] a notice of a kind there are no words for ('%s'); dropped" % kind)
		return {}
	var out: Dictionary = {"say": say, "kind": kind, "n": int(n)}
	if kind == "level":
		if not d.get("level") is String or RegEx.create_from_string(LevelChart.ID_PATTERN).search(String(d["level"])) == null:
			push_warning("[net] a level notice naming no level id; dropped")
			return {}
		var chart: LevelChart = ChartDrawer.chart(String(d["level"]))
		if chart == null or not d.get("hash") is String or String(d["hash"]) != chart.content_hash:
			push_warning("[net] a level notice naming a level this build does not have; dropped")
			return {}
		var in_ms: Variant = d.get("in")
		if not (in_ms is float or in_ms is int) or float(in_ms) < 0.0:
			push_warning("[net] a level notice with no count-down; dropped")
			return {}
		if float(in_ms) > float(LEVEL_WARNING_MSEC):
			push_warning("[net] a level notice counting down %d ms, clamped to %d" % [int(in_ms), LEVEL_WARNING_MSEC])
		out["level"] = String(d["level"])
		out["hash"] = String(d["hash"])
		out["in"] = mini(int(in_ms), LEVEL_WARNING_MSEC)
	elif kind == "sky":
		var clock: Variant = d.get("clock")
		var rate: Variant = d.get("rate")
		if not (clock is float or clock is int) or is_nan(float(clock)) or is_inf(float(clock)) \
				or not (rate is float or rate is int) or is_nan(float(rate)) or is_inf(float(rate)) \
				or not d.get("clouds") is bool:
			push_warning("[net] a sky notice with no valid clock, rate or clouds; dropped")
			return {}
		# MAGNITUDES, clamped and said, as the sky's own hello clamps them.
		out["clock"] = clampf(float(clock), 0.0, Orrery.DAY_LONG)
		out["rate"] = clampf(float(rate), 0.0, CLOCK_RATE_MOST)
		if out["clock"] != float(clock) or out["rate"] != float(rate):
			push_warning("[net] a sky notice at %s minutes running at %s, clamped" % [clock, rate])
		out["clouds"] = bool(d["clouds"])
	else:
		var player: Variant = d.get("player")
		if not (player is float or player is int) or float(player) != floorf(float(player)) or float(player) < 1.0 \
				or float(player) > float(PLAYER_MOST):
			push_warning("[net] a %s notice naming no player; dropped" % kind)
			return {}
		out["player"] = int(player)
	return out


## A LINE FOR A HARNESS, with `--report=1` after the bare `--`, as the flight level's SESSION_REPORT is.
static func _report(line: String) -> void:
	if OS.get_cmdline_user_args().has("--report=1"):
		print(line)

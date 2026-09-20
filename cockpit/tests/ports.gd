extends RefCounted
class_name TestPorts
## WHICH SOCKET A SUITE OPENS, AND WHICH LOG ITS CHILDREN WRITE, SO TWO CHECKOUTS NEVER SHARE EITHER.
##
## Twenty-five suites in this folder each typed a port number, and at least five pairs typed the SAME number:
## `craft_peers` 48120-48129 overlaps `radio_peers` 48120-48125; `names_peers` and `sky_peers` are both 47940-47947;
## `level_change_shot` and `no_vr_flight` are both 47966-47969; `lobby_peers` overlaps `music_peers`; `link_ms` and
## `priority_peers` were both 47994; and `crew_peers` 47990-47999 swallows five other suites whole. Inside one gate
## they run one at a time, so it has never bitten -- but two LANES gating at once bind the same port, the second host
## never comes up, and the suite fails on a timeout that looks like the code under test.
##
## THE FAULT IS THAT THERE WAS NO AUTHORITY: a number typed in twenty-five places is a number kept in no place
## (CLAUDE.md, rule 4). This is the authority. A suite still writes the port it wants, from the block 47900-48299; this
## moves the whole block to a place of its own for each checkout, so a suite's ports keep the order and the spacing its
## author chose and two checkouts' suites land on different sockets. `lint` fails a test file that types a port in that
## block anywhere but inside a call to this, and one that calls `Net.host` or `Net.join` without naming a port.
##
## THE PLACE COMES FROM THE WORKTREE PATH, and not from an environment variable the runner sets. A path is a fact
## the process already has, so this works under `run_all.ps1`, under `gate_run.ps1`, under a bare Godot command line
## and inside a CHILD process -- which matters, because a suite passes `--host=<port>` to one child and
## `--join=127.0.0.1:<port>` to another and all three must agree without being told. An environment variable would
## have coupled this to one launcher and would have been absent in exactly the case that is hardest to debug.
##
## A HASH CAN STILL PUT TWO CHECKOUTS IN ONE PLACE, and so can two runs in the SAME checkout, and so can anything else on
## the machine that happens to hold a port. So a suite does not bind what it was given blind: `first_free` asks the
## machine, silently, which of its ports is free, and a suite that finds none says PORT BUSY and stops in a second rather
## than binding a held socket and waiting three minutes for a peer that is talking to somebody else's host.
##
## WHAT WENT WRONG BEFORE (2026-09-18, `lane/ports`). The first version shifted the block by 0 to 3,900 above 47900.
## That reached 51,799: inside Windows' dynamic range (49152 up), where the OS hands out the ephemeral ports ENet's own
## clients bind, and across 50000-50059, which this machine EXCLUDES for UDP (`netsh int ipv4 show excludedportrange
## protocol=udp`) -- a checkout that hashed there could never host at all. And only two suites of twenty-five used it.
## The block now moves to 10,000 and up, and stops below 49,152.
##
##     static var PORT: int = TestPorts.of(47996)     # a `static var`: a call is not a constant

## THE BLOCK A SUITE MAY ASK FOR, as the suites have always written it: 47900 up to (not including) 48400.
##
## IT WAS 400 WIDE AND RAN OUT (lane/flatcrew, 2026-09-20). `server_peers` took 48290-48299, the last ten, and
## `radar_peers` had nowhere to go: a suite that asks for 48300 gets a push_error from `of`, 0 back, and then reports
## that every one of its ports is held -- four seconds of a message that names the wrong problem entirely.
##
## WIDENING IS THE CHEAP END OF THIS. Every checkout's actual ports move, because a place is `FLOOR + n * WIDTH`, but
## nothing persists a port between runs and the mapping stays deterministic per worktree, which is the property that
## makes a stuck socket findable. The cost is that there are fewer distinct places for concurrent checkouts to land
## in -- 78 rather than 97 -- which matters only if this workshop ever runs that many worktrees at once.
## **WHEN IT FILLS AGAIN, GROW THE TOP -- DO NOT REUSE A BLOCK.** Two suites sharing ten ports pass alone and clash
## under `-Jobs 8`, which is a red that appears only sometimes and names the wrong suite when it does. Raise `WIDTH`,
## check `lint`'s `TYPED_PORT` covers the new top, and take the next free block. **And do not type a port instead:**
## the day the authority looks full is exactly the day a lane reaches for a literal, which is how
## `and_every_suite_takes_its_ports_from_the_authority` went red on main on 2026-09-20. `lint` allows a literal in
## this block under two names only, `FIRST_PORT` and `LAST_PORT`.
const LOWEST: int = 47900
const WIDTH: int = 500
## WHERE THE PLACES ARE. Above everything a developer's machine is likely to be using -- 7788 is the game's own, and
## Steam's are 27000-27100, inside which no place's ports fall only by luck, so the floor is below them and the places
## step over them -- and below Windows' dynamic range, 49152 up, where ENet's clients get their own ports.
const FLOOR: int = 10000
const CEILING: int = 49152
## Every whole place between the floor and the ceiling that does not touch Steam's ports.
const STEAM_LOW: int = 27000
const STEAM_HIGH: int = 27100


## THE PORT THIS CHECKOUT USES FOR `wanted`. Deterministic: the same worktree always gets the same port, so a run is
## repeatable and a stuck socket is findable. A number outside the block is a mistake in the suite and says so loudly.
static func of(wanted: int) -> int:
	if wanted < LOWEST or wanted >= LOWEST + WIDTH:
		push_error("[TestPorts] %d is outside the block %d-%d every suite asks from" % [wanted, LOWEST, LOWEST + WIDTH - 1])
		return 0
	return _places()[place()] + (wanted - LOWEST)


## WHICH PLACE THIS CHECKOUT'S BLOCK IS IN: the first four hex characters of the MD5 of the project's real path,
## lower-cased so a child started with a differently-cased `--path` agrees with its parent.
static func place() -> int:
	return ("0x" + _key().substr(0, 4)).hex_to_int() % _places().size()


## THE FIRST OF `count` PORTS FROM `of(wanted)` THAT NOTHING ON THIS MACHINE HOLDS, or 0 when every one of them is held.
## Asked by binding a UDP socket the way ENet does -- both address families, every interface -- and closing it at once.
## `PacketPeerUDP.bind` on a held port returns an error and PRINTS NOTHING, where `ENetMultiplayerPeer.create_server`
## prints "ERROR: Couldn't create an ENet host.", which the runner's error gate turns red even when the suite then
## moves to the next port and passes: that was `notices` and `sky_peers` failing on another lane's sockets.
##
## `above` skips every port up to and including it, for a suite that hosts more than once from one range at a time: the
## second host takes the first free port above the first host's, and never the one the first is still holding.
static func first_free(wanted: int, count: int = 1, above: int = 0) -> int:
	var first: int = of(wanted)
	if first == 0:
		return 0
	for port in range(first, first + count):
		if port > above and not is_held(port):
			return port
	return 0


## WHETHER SOMETHING ON THIS MACHINE ALREADY HOLDS `port` FOR UDP. See `first_free`.
static func is_held(port: int) -> bool:
	var probe := PacketPeerUDP.new()
	var err: int = probe.bind(port, "*")
	probe.close()
	return err != OK


## WHAT A SUITE SAYS WHEN `first_free` FOUND NOTHING: which ports, and the likeliest reason. One sentence in one place,
## so every suite's PORT BUSY reads the same and a grep of the logs finds them all.
static func busy(wanted: int, count: int = 1) -> String:
	var first: int = of(wanted)
	return "PORT BUSY: %d to %d are all held -- another run of this suite in this checkout, a child left over from a " \
		% [first, first + count - 1] + "killed run, or another checkout that hashed to the same place (%d)" % place()


## WHAT TO CALL A CHILD'S LOG FILE, so two checkouts' children never write the same one. A fixed name like
## `notices_joiner.log` was written by two lanes' joiners at once, interleaved, and deleted by one lane's suite while
## the other's waited on it: that was `notices`' three-minute hang.
##
## THIS DOC BLOCK USED TO SAY `override.cfg` IS READ TOO LATE TO MOVE `user://`. THAT IS FALSE AND WAS MEASURED FALSE
## (`lane/voicelobby`, 2026-09-20): with `config/use_custom_user_dir=true` and a `custom_user_dir_name` in
## `cockpit/override.cfg`, `ProjectSettings.globalize_path("user://")` prints
## `C:/Users/Graham/AppData/Roaming/cockpit_lane_voicelobby/` rather than
## `AppData/Roaming/Godot/app_userdata/cockpit/`. It moves. Every lane worktree gets one from
## `.claude/team/tools/provision_lane.ps1`, so lanes are genuinely isolated in `user://` and not merely separated by
## these filenames.
##
## THE HASHING STAYS ANYWAY, and the reason is now the honest one rather than the stated impossibility of the
## alternative: it costs nothing, and it protects a checkout that has NO override -- the main tree, a hand-made
## worktree, or a lane provisioned before the script wrote one. A defence that only works when someone remembered to
## configure something is not a defence.
static func log_for(suite: String, who: String) -> String:
	return "user://%s_%s_%s.log" % [suite, _key().substr(0, 8), who]


## AND THE JOB SLOT, when `run_all.ps1 -Jobs` runs several suites of one checkout at once: two peers suites side by side
## in one tree would otherwise share a place (see `CockpitLayout.test_slot`). Empty by hand, so nothing moves then.
static func _key() -> String:
	return (ProjectSettings.globalize_path("res://").to_lower() + CockpitLayout.test_slot()).md5_text()


## Every place's first port, low to high: whole blocks from the floor, skipping any that would touch Steam's ports and
## stopping before the dynamic range. 96 of them.
static func _places() -> PackedInt32Array:
	var places := PackedInt32Array()
	var at: int = FLOOR
	while at + WIDTH <= CEILING:
		if at + WIDTH <= STEAM_LOW or at > STEAM_HIGH:
			places.append(at)
		at += WIDTH
	return places

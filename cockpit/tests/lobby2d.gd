extends Node
## THE RULES THE FLAT VOICE LOBBY STANDS ON, in one process and in under a second: what a team may be, what a typed line
## may be, who is allowed to say either, and what the wire drops.
##
##   Godot --headless --path cockpit res://tests/lobby2d.tscn
##
## `tests/lobby2d_peers.gd` is the other half and the expensive one: three real processes proving that a roster, a team
## and a line actually cross a socket. This suite is the cheap half, and it is where the REFUSALS live, because a refusal
## is the one thing a happy two-peer run never exercises: nothing in that run asks a client to assign a team or sends a
## line full of control characters.
##
## Read RESULT=, not the exit code.

var failures: PackedStringArray = []


func check(label: String, ok: bool, detail: String = "") -> void:
	print("[lobby2d] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		failures.append(label)


func _ready() -> void:
	_the_teams()
	_a_typed_line()
	_who_may_assign_a_team()
	_what_the_wire_drops()
	print("RESULT=%s" % ("PASS" if failures.is_empty() else "FAIL %s" % ", ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)


## ---- what a team may be --------------------------------------------------------------------------

func _the_teams() -> void:
	check("nobodys_team_is_not_a_team", not TeamBoard.holds(TeamBoard.NOBODY) and TeamBoard.holds(1)
		and TeamBoard.holds(TeamBoard.COUNT), "0 no, 1 yes, %d yes" % TeamBoard.COUNT)
	check("a_team_past_the_last_one_is_not_a_team", not TeamBoard.holds(TeamBoard.COUNT + 1),
		"%d" % (TeamBoard.COUNT + 1))
	# NOT CLAMPED. A magnitude clamped onto the nearest real team is how somebody ends up on RED by accident, and rule 8
	# says a clamp is invisible to every counter: a number that is not a team is NOBODY.
	check("a_team_number_off_the_wire_is_not_clamped_onto_a_real_team",
		TeamBoard.read(TeamBoard.COUNT + 5) == TeamBoard.NOBODY and TeamBoard.read(-3) == TeamBoard.NOBODY
			and TeamBoard.read(2) == 2,
		"%d, %d, %d" % [TeamBoard.read(TeamBoard.COUNT + 5), TeamBoard.read(-3), TeamBoard.read(2)])
	var walked: PackedInt32Array = []
	var team: int = TeamBoard.NOBODY
	for i in range(TeamBoard.COUNT + 1):
		team = TeamBoard.next(team)
		walked.append(team)
	check("the_one_button_walks_every_team_and_comes_back_to_none",
		walked.size() == TeamBoard.COUNT + 1 and int(walked[TeamBoard.COUNT - 1]) == TeamBoard.COUNT
			and int(walked[TeamBoard.COUNT]) == TeamBoard.NOBODY, "%s" % [walked])
	check("every_team_has_a_name_and_so_does_a_number_that_is_not_one",
		TeamBoard.name_of(1) != "" and TeamBoard.name_of(TeamBoard.COUNT) != ""
			and TeamBoard.name_of(999) == TeamBoard.name_of(TeamBoard.NOBODY),
		"%s, %s, %s" % [TeamBoard.name_of(1), TeamBoard.name_of(TeamBoard.COUNT), TeamBoard.name_of(999)])
	# THE CHECK THE WHOLE FEATURE TURNS ON, and the one a `mine == theirs` would get wrong: "no team" is not a team two
	# people can share. Without this, every unassigned player quietly has a private channel with every other one.
	check("two_players_on_the_same_team_share_it", TeamBoard.share_a_team(2, 2))
	check("and_two_on_different_teams_do_not", not TeamBoard.share_a_team(1, 2))
	check("and_two_on_no_team_at_all_do_not_share_one",
		not TeamBoard.share_a_team(TeamBoard.NOBODY, TeamBoard.NOBODY))


## ---- what a typed line may be --------------------------------------------------------------------

func _a_typed_line() -> void:
	check("an_ordinary_line_is_allowed", ChatLine.problem("radio check, over") == "",
		ChatLine.problem("radio check, over"))
	check("an_empty_line_is_refused_in_words", ChatLine.problem("   ") != "", ChatLine.problem("   "))
	check("a_line_past_the_character_count_is_refused",
		ChatLine.problem("x".repeat(ChatLine.MOST_CHARS + 1)) != ""
			and ChatLine.problem("x".repeat(ChatLine.MOST_CHARS)) == "",
		"%d refused, %d allowed" % [ChatLine.MOST_CHARS + 1, ChatLine.MOST_CHARS])
	# AND IN BYTES, SEPARATELY. A hello is one 512-byte packet, and 200 characters of a four-byte script is 800 bytes:
	# without this the carrier would drop the line instead of the sender refusing it.
	var wide: String = "ア".repeat(ChatLine.MOST_CHARS - 10)
	check("a_line_short_enough_in_characters_but_too_many_bytes_is_refused",
		wide.length() <= ChatLine.MOST_CHARS and wide.to_utf8_buffer().size() > ChatLine.MOST_BYTES
			and ChatLine.problem(wide) != "",
		"%d characters, %d bytes: %s" % [wide.length(), wide.to_utf8_buffer().size(), ChatLine.problem(wide)])
	check("a_line_with_a_control_character_is_refused", ChatLine.problem("hello\u0007there") != ""
		and ChatLine.problem("two\nlines") != "" and ChatLine.problem("del\u007f") != "",
		ChatLine.problem("two\nlines"))
	check("and_the_line_that_travels_is_the_trimmed_one", ChatLine.clean("  over  ") == "over",
		"'%s'" % ChatLine.clean("  over  "))
	# A VALIDATOR THAT REPAIRS ITS INPUT WAS REJECTED: see ChatLine's note. `clean` must not be a filter.
	check("and_clean_does_not_quietly_repair_a_line_problem_refused",
		ChatLine.clean("bad\u0007line") == "bad\u0007line", "clean left it alone")


## ---- who may assign a team -----------------------------------------------------------------------

## The refusals, which the three-peer run never reaches: it has no client rude enough to try.
func _who_may_assign_a_team() -> void:
	var was_host: bool = Net.is_host
	Net.is_host = false
	check("a_client_asking_to_assign_a_team_is_refused_in_words", Net.set_team(2, 1) != "",
		Net.set_team(2, 1))
	Net.is_host = true
	check("a_team_that_does_not_exist_is_refused", Net.set_team(2, TeamBoard.COUNT + 1) != "",
		Net.set_team(2, TeamBoard.COUNT + 1))
	check("and_so_is_a_player_who_is_not_one", Net.set_team(0, 1) != "", Net.set_team(0, 1))
	check("the_host_may_put_a_player_on_a_team", Net.set_team(2, 1) == "", Net.set_team(2, 1))
	check("and_take_them_off_it_again", Net.set_team(2, TeamBoard.NOBODY) == "")
	Net.is_host = was_host
	# OFF THE ROSTER AND NOWHERE ELSE. `team_of` answers from the card the host published, so a player nobody has a card
	# for is on nobody's team rather than missing.
	Net.roster.erase(4242)
	check("a_player_with_no_card_is_on_nobodys_team", Net.team_of(4242) == TeamBoard.NOBODY)


## ---- what the wire drops -------------------------------------------------------------------------

func _what_the_wire_drops() -> void:
	var good: Dictionary = Net.read_hello(JSON.stringify({"say": "roster", "n": 3, "cards": [
		[1, "HOST", 1, 0, 2]]}).to_utf8_buffer())
	var cards: Array = good.get("cards", [])
	check("a_roster_card_carries_the_team_the_host_put_that_player_on",
		cards.size() == 1 and int((cards[0] as Dictionary).get("team", -1)) == 2,
		"%s" % [cards])
	var teamless: Dictionary = Net.read_hello(JSON.stringify({"say": "roster", "n": 3, "cards": [
		[1, "HOST", 1, 0]]}).to_utf8_buffer())
	check("and_a_card_that_names_no_team_reads_as_nobodys",
		int(((teamless.get("cards", []) as Array)[0] as Dictionary).get("team", -1)) == TeamBoard.NOBODY)
	check("a_card_with_a_team_that_is_not_a_team_is_dropped", Net.read_hello(JSON.stringify({"say": "roster",
		"n": 3, "cards": [[1, "HOST", 1, 0, 99]]}).to_utf8_buffer()).is_empty())
	# CHAT, WHICH IS THE ONLY FREE TEXT ON THIS WIRE. Each of these is a packet a peer could send on purpose.
	check("a_chat_hello_is_read", Net.read_hello(JSON.stringify({"say": "chat", "n": 1,
		"text": "radio check"}).to_utf8_buffer()).get("text") == "radio check")
	check("a_chat_hello_with_no_line_number_is_dropped", Net.read_hello(JSON.stringify({"say": "chat",
		"text": "radio check"}).to_utf8_buffer()).is_empty())
	check("a_chat_hello_numbered_zero_is_dropped", Net.read_hello(JSON.stringify({"say": "chat", "n": 0,
		"text": "radio check"}).to_utf8_buffer()).is_empty())
	check("a_chat_hello_carrying_a_control_character_is_dropped", Net.read_hello(JSON.stringify({"say": "chat",
		"n": 1, "text": "two\nlines"}).to_utf8_buffer()).is_empty())
	check("a_chat_hello_carrying_nothing_is_dropped", Net.read_hello(JSON.stringify({"say": "chat", "n": 1,
		"text": "   "}).to_utf8_buffer()).is_empty())
	check("a_chat_hello_with_no_text_at_all_is_dropped", Net.read_hello(JSON.stringify({"say": "chat",
		"n": 1}).to_utf8_buffer()).is_empty())
	# A HOST'S LINE NAMES WHO SAID IT; A PEER'S OFFER MUST NOT, and does not get to: `chat` carries no player at all, and
	# the host writes it from who the peer IS. A `chatline` with no player is malformed.
	check("a_host_line_names_the_player_who_said_it", int(Net.read_hello(JSON.stringify({"say": "chatline",
		"n": 2, "player": 3, "text": "over"}).to_utf8_buffer()).get("player", -1)) == 3)
	check("and_a_host_line_with_no_player_is_dropped", Net.read_hello(JSON.stringify({"say": "chatline",
		"n": 2, "text": "over"}).to_utf8_buffer()).is_empty())
	check("an_acknowledgement_is_a_number_and_nothing_else",
		Net.read_hello(JSON.stringify({"say": "chat_heard", "n": 4}).to_utf8_buffer()).get("n") == 4
			and Net.read_hello(JSON.stringify({"say": "chatline_heard", "n": 4}).to_utf8_buffer()).get("n") == 4)
	# AND A LINE AT THE VERY EDGE STILL FITS ONE PACKET, which is the number ChatLine.MOST_BYTES was chosen for.
	var longest: String = "x".repeat(ChatLine.MOST_CHARS)
	var packet: PackedByteArray = JSON.stringify({"say": "chatline", "n": 999999, "player": 65535,
		"text": longest}).to_utf8_buffer()
	check("the_longest_line_anybody_may_send_still_fits_one_hello",
		packet.size() <= Net.HELLO_MOST_BYTES and not Net.read_hello(packet).is_empty(),
		"%d bytes of %d" % [packet.size(), Net.HELLO_MOST_BYTES])

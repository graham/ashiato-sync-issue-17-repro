class_name ChatLine
extends RefCounted
## ONE TYPED LINE OF TEXT, and what makes it fit to put on the wire.
##
## THIS IS THE ONE PLACE IN COCKPIT WHERE FREE TEXT A PLAYER TYPED TRAVELS BETWEEN MACHINES, and that deserves saying
## out loud, because `Net`'s notices block rejects exactly that: "free text on the wire, which is the first thing a
## validator would have to learn to distrust". That rejection is right for a NOTICE -- a notice is a fact and every
## machine writes its own words for it, so text there would be one machine printing another's sentence. A chat line is
## different in kind: the text IS the message, and no machine can word it for the player who typed it. So the rule it
## answers instead is CLAUDE.md rule 8 -- untrusted input proposes, the host disposes -- and this file is the validator
## both ends share.
##
## WHAT A LINE MAY BE. At most `MOST_CHARS` characters after its edges are trimmed, not empty, and free of control
## characters -- which are what turn one line of somebody else's text into two lines, a moved cursor or a cleared board.
## Every check says why in words, because the refusal is shown to the player who typed it.
##
## IT IS NEVER INTERPRETED, ONLY DRAWN. The lobby writes a line into a `Label`'s `text`, never into BBCode and never
## through `RichTextLabel`'s parser, so `[color=red]` and `[img]` are eight and six characters somebody typed rather than
## markup another player's machine obeys. That is the whole reason the log is Labels; see `FlatLobby`.
##
## Rejected: a filter that silently drops the bad characters and sends the rest. A player whose line arrives altered
## cannot tell that it was altered, and a validator that repairs its input is one that never reports a sender doing
## something odd. This refuses, in words, at the machine that typed it, and the host refuses again for anyone who did
## not ask nicely.

## The longest line anybody may send. `Radio.MOST_TEXT` is 160 for a spoken line because Kokoro has to say it; a typed
## line has no such cost, and 200 is about two lines on the lobby's log at its width.
const MOST_CHARS: int = 200
## AND THE SAME LINE IN BYTES. A hello is one 512-byte packet (`Net.HELLO_MOST_BYTES`) and its envelope spends about
## sixty, so a line whose UTF-8 runs past this would be dropped by the carrier rather than refused here -- and 200
## characters of a script whose letters cost four bytes each is 800. Checked separately from the character count because
## the two refusals mean different things and a player typing Japanese deserves the honest one.
const MOST_BYTES: int = 320
## How many lines the host keeps and a joiner is caught up on. A lobby is a place to check that voice works, not a
## record: sixty-four lines is more than fits on the board and bounded is the point.
const MOST_KEPT: int = 64


## WHY THIS LINE CANNOT BE SENT, in words for the player who typed it, or "" if it can.
static func problem(text: String) -> String:
	var clean: String = text.strip_edges()
	if clean.is_empty():
		return "Type something first."
	if clean.length() > MOST_CHARS:
		return "A message may be at most %d characters." % MOST_CHARS
	if clean.to_utf8_buffer().size() > MOST_BYTES:
		return "A message may be at most %d bytes of text." % MOST_BYTES
	for i in range(clean.length()):
		var code: int = clean.unicode_at(i)
		# DEL as well as the C0 block: both are invisible, and a board that prints one has a hole in it.
		if code < 32 or code == 127:
			return "A message may not contain control characters."
	return ""


## THE LINE AS IT TRAVELS: trimmed, and nothing else. `problem` has already refused anything this would have to repair,
## so this never alters what it is given -- it is here so that the sender, the host's validator and the board all agree
## on what "the line" is without three copies of `strip_edges`.
static func clean(text: String) -> String:
	return text.strip_edges()


## IS THIS A LINE A HOST MAY ACCEPT FROM A PEER. The same question as `problem`, asked of what arrived rather than of
## what was typed, and answered without the player's wording: a host does not tell a peer to type something first, it
## drops the packet and warns (CLAUDE.md rule 8, and the harness fails on any warning).
static func acceptable(text: String) -> bool:
	return problem(text).is_empty()

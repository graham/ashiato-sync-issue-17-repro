extends RefCounted
class_name Logbook
## THE CONNECTION LOG: every knock at this machine's door and what became of it, newest last, the last `MOST` of them.
##
## Asked for on 2026-09-18: "There should be a server log message that explains why a user couldn't connect (we need a
## server log panel in the ipad). and the client MUST know why (if possible), it couldn't connect." Named for a ship's
## LOGBOOK, where the watch writes down who came aboard, who was turned away and why. `Net` keeps one and writes in it;
## the clipboard's LOG tab is handed its rows and draws them (`ClipboardPage.show_log`), and a shell reads the same
## entries as one line each (`line`), so a host's refusal is findable with one grep:
##
##   NET_REFUSED side=host code=wrong_version peer=2 who="127.0.0.1:52811" host="dev · 3f224dd2 · 2026-09-18"
##       client="0.2.0 soaring-otter · 1a2b3c4d" words="Can't join: ..."
##
## ON THE HOST it is the session's door: joined, refused, left, timed out. ON A CLIENT it is the client's own attempts:
## connecting, connected, refused and why, gave up waiting. Same book, same rows, because it answers one question on
## both -- what happened at the door -- and a client refused by a host has exactly the host's words in its own book.
##
## A RING, not a file: two hundred rows is an evening of people coming and going, and nothing here outlives the process.
## The console line is what outlives it, in the log file Godot already writes.
##
## EVERY FIELD IS CLEANED BEFORE IT IS WRITTEN (CLAUDE.md, rule 8): a joiner's build line and its words are a stranger's,
## and they end up on a shell and on a page. `clean` takes control characters and quotes out and cuts to `FIELD_MOST`.

## How many rows are kept.
const MOST: int = 200
## The longest any one field is kept, in letters. The longest real thing is a refusal's words.
const FIELD_MOST: int = 300

## The fields a person or a stranger wrote, always quoted in a line.
const FREE_TEXT: Array[String] = ["who", "host", "client", "words"]

## Something was written. The page that shows it is handed `rows()` again.
signal changed

var _rows: Array[Dictionary] = []
## Whether each row is printed as it is written. Off for a suite that builds a book of its own to draw.
var prints: bool = true


## WRITE ONE ROW: an event ("REFUSED", "JOINED", ...), which side of the door this machine is on, and the facts, each
## cleaned. `facts` may hold code, peer, who, host, client, words; anything else is kept too, cleaned the same way.
func write(event: String, side: String, facts: Dictionary = {}) -> Dictionary:
	var row: Dictionary = {"at": Time.get_unix_time_from_system(), "event": clean(event, 32), "side": clean(side, 8)}
	for key in facts.keys():
		var value: Variant = facts[key]
		row[String(key)] = value if value is int else clean(str(value), FIELD_MOST)
	_rows.append(row)
	while _rows.size() > MOST:
		_rows.pop_front()
	if prints:
		print(line(row))
	changed.emit()
	return row


## THE ROWS, newest FIRST: the order the LOG tab reads them in, and the order a person reading a log wants.
func rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = _rows.duplicate()
	out.reverse()
	return out


func size() -> int:
	return _rows.size()


func clear() -> void:
	_rows.clear()
	changed.emit()


## ONE ROW AS ONE LINE, for a shell: `NET_<EVENT>` and then `key=value`, strings in double quotes. The fields come in a
## fixed order so two lines of one event line up, and anything else a row holds follows in name order.
static func line(row: Dictionary) -> String:
	var parts: PackedStringArray = ["NET_%s" % String(row.get("event", "?"))]
	var order: Array = ["side", "code", "peer", "who", "host", "client", "words"]
	var rest: Array = row.keys().filter(func(k: Variant) -> bool: return not String(k) in order and k != "at" \
		and k != "event")
	rest.sort()
	for key in order + rest:
		if not row.has(key):
			continue
		var value: Variant = row[key]
		# A WORD STAYS BARE, so `grep code=full` finds it; anything a stranger wrote, or with a space in, is quoted.
		var bare: bool = value is int or (not key in FREE_TEXT and not String(value).contains(" ") \
			and not String(value).is_empty())
		parts.append("%s=%s" % [key, str(value) if bare else "\"%s\"" % String(value)])
	return " ".join(parts)


## A STRANGER'S STRING, MADE SAFE TO PRINT AND TO DRAW: no control characters, no double quotes (a line's own quoting
## would break), whitespace runs made one space, and cut to `most` letters with an ellipsis when it was cut.
static func clean(raw: String, most: int = FIELD_MOST) -> String:
	var out: String = ""
	var last_space: bool = false
	for i in range(raw.length()):
		var c: int = raw.unicode_at(i)
		var space: bool = c <= 32 or c == 127 or (c >= 0x80 and c < 0xA0)
		if space:
			if not last_space and not out.is_empty():
				out += " "
			last_space = true
			continue
		last_space = false
		out += "'" if c == 34 else String.chr(c)
	out = out.strip_edges()
	if out.length() > most:
		out = out.left(maxi(most - 1, 0)) + "…"
	return out

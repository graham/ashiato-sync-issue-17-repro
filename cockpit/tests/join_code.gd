extends Node
## Headless: is a join code something a person can read aloud, type on a keypad and have understood?
##
##   Godot --headless --path cockpit res://tests/join_code.tscn
##
## THE CODE A HOST READS OUT AND A FRIEND TYPES, and nothing about Steam. `JoinCode` is pure: it makes a code from
## random bytes, reads what a person typed back into one, says in words why something typed is not one, and spells a
## code the way it is shown. Everything downstream -- the keypad, `Net.join_code`, the lobby search -- asks it, so every
## malformed spelling a person can produce is refused HERE, once, before any directory is asked anything. Untrusted
## input proposes.
##
## Asked for on 2026-09-14: "a join code for steam players so they can join a game via a join code rather than having
## to be invited or searching for a game." The alphabet and length come from tests/steam_probe.gd, which found a real
## invisible lobby by its code alone.
##
## Read RESULT=, not the exit code.

var _failures: PackedStringArray = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("[join_code] %s %s (%s)" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_failures.append(label)


func _ready() -> void:
	_the_alphabet_cannot_be_misread()
	_every_code_made_reads_back()
	_what_a_person_types_is_read_or_refused_in_words()
	_finish()


## ---- the symbols --------------------------------------------------------------------------------------------------

## THIRTY-TWO SYMBOLS, NONE OF THEM ONE ANOTHER. 0 and O, and 1 and I, are the pairs a code read off a screen across a
## room or down a voice channel loses; with neither of either pair in the alphabet there is nothing to confuse them
## with. Thirty-two because it divides a byte: a random byte reduced modulo the alphabet then lands on every symbol
## exactly as often, which a count over all 256 bytes shows rather than asserts.
func _the_alphabet_cannot_be_misread() -> void:
	var symbols: String = JoinCode.ALPHABET
	_check("the_alphabet_has_thirty_two_symbols", symbols.length() == 32, "'%s', %d" % [symbols, symbols.length()])
	var twice: PackedStringArray = []
	for i in range(symbols.length()):
		if symbols.find(symbols[i]) != i:
			twice.append(symbols[i])
	_check("and_none_of_them_twice", symbols.length() > 0 and twice.is_empty(), "%s" % [twice])
	_check("and_all_of_them_capitals_or_digits", symbols.length() > 0 and symbols == symbols.to_upper()
		and RegEx.create_from_string("^[A-Z0-9]*$").search(symbols) != null, symbols)
	var confusable: PackedStringArray = []
	for c in ["0", "O", "1", "I"]:
		if symbols.contains(c):
			confusable.append(c)
	_check("and_no_0_O_1_or_I", symbols.length() > 0 and confusable.is_empty(), "%s" % [confusable])

	var landed: Dictionary = {}
	for byte in range(256):
		var one: PackedByteArray = []
		one.resize(JoinCode.LENGTH)
		one.fill(byte)
		var code: String = JoinCode.make(one)
		if code.length() > 0:
			landed[code[0]] = int(landed.get(code[0], 0)) + 1
	var even: bool = landed.size() == 32
	for symbol in landed:
		even = even and int(landed[symbol]) == 256 / 32
	_check("every_byte_lands_on_a_symbol_and_every_symbol_is_landed_on_equally", even,
		"%d symbols landed on, counts %s" % [landed.size(), landed.values()])


## ---- making them ---------------------------------------------------------------------------------------------------

func _every_code_made_reads_back() -> void:
	var wrong: PackedStringArray = []
	var seen: Dictionary = {}
	for i in range(5000):
		var code: String = JoinCode.fresh()
		if code.length() != JoinCode.LENGTH or JoinCode.read(code) != code or JoinCode.why_not(code) != "" \
				or JoinCode.read(JoinCode.spell(code)) != code:
			wrong.append(code)
		seen[code] = true
	_check("five_thousand_fresh_codes_are_codes_and_read_back_plain_and_spelled", wrong.is_empty(),
		"%d wrong, first %s" % [wrong.size(), wrong.slice(0, 3)])
	# REPEATS UNDER A BOUND, NOT NONE. Five thousand draws from N = 32^6 = 1,073,741,824 codes are expected to repeat
	# lambda = n^2 / 2N = 25,000,000 / 2,147,483,648 = 0.0116 times, so "not one repeat" fails about 1.2 % of runs by
	# arithmetic alone -- and did, on the double lane's gate of 2026-09-14 (4,999 distinct). Repeats are close to Poisson
	# with that mean, so three or more happen with probability about lambda^3 / 6 = 2.6e-7: never, in practice. A generator
	# drawing from a shrunken space is what this exists to catch, and it cannot hide under the bound: four random symbols
	# (32^4) give lambda = 11.9, and then P(two or fewer) = e^-11.9 (1 + 11.9 + 70.8) = 5.7e-4.
	var repeats: int = 5000 - seen.size()
	_check("and_they_hardly_ever_repeat", repeats <= 2,
		"%d distinct, %d repeated, %.4f expected, the check allows 2" % [seen.size(), repeats, 5000.0 * 5000.0 / (2.0 * pow(32.0, 6.0))])
	_check("a_code_is_spelled_in_two_threes", JoinCode.spell(JoinCode.EXAMPLE) == "K7M-Q2X",
		"'%s'" % JoinCode.spell(JoinCode.EXAMPLE))


## ---- reading them ----------------------------------------------------------------------------------------------------

## WHAT A PERSON TYPES, and what comes back: the code they meant, or "" and a sentence saying why not. Case folds,
## and spaces and dashes are how people group six characters, so they separate rather than refuse. Anything else is
## refused with words a person can act on, and the words are asserted exactly, because the words are the feature.
func _what_a_person_types_is_read_or_refused_in_words() -> void:
	var spelled: String = JoinCode.spell(JoinCode.EXAMPLE)
	var too_short: String = "A code is 6 characters, like %s (you typed %d)." % [spelled, 5]
	var too_long: String = "A code is 6 characters, like %s (you typed %d)." % [spelled, 7]
	var confusable: String = "Codes have no 0, O, 1 or I."
	var cases: Array = [
		# typed, reads as, refused with
		["K7MQ2X", "K7MQ2X", ""],
		["k7m-q2x", "K7MQ2X", ""],
		[" K7M Q2X ", "K7MQ2X", ""],
		["K7M-Q2X", "K7MQ2X", ""],
		["", "", "Type the host's code first."],
		["  - ", "", "Type the host's code first."],
		["K7MQ2", "", too_short],
		["K7MQ2XX", "", too_long],
		["K0MQ2X", "", confusable],
		["KOMQ2X", "", confusable],
		["K1MQ2X", "", confusable],
		["KIMQ2X", "", confusable],
		["kimq2x", "", confusable],
		["K7MQ2!", "", "A code is letters and the digits 2 to 9, and '!' is not one."],
		[String.chr(0x041A) + "7MQ2X", "", "A code is letters and the digits 2 to 9, and '%s' is not one." % String.chr(0x041A)],
		# A LENGTH AND A BAD SYMBOL AT ONCE: the symbol is what the person can see they got wrong, so it is said first.
		["K0MQ2", "", confusable],
	]
	for case in cases:
		var typed: String = case[0]
		_check("reads_%s" % JSON.stringify(typed), JoinCode.read(typed) == case[1],
			"got '%s' want '%s'" % [JoinCode.read(typed), case[1]])
		_check("and_says_of_%s" % JSON.stringify(typed), JoinCode.why_not(typed) == case[2],
			"got '%s' want '%s'" % [JoinCode.why_not(typed), case[2]])


func _finish() -> void:
	if _failures.is_empty():
		print("RESULT=PASS")
	else:
		print("RESULT=FAIL %s" % ", ".join(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)

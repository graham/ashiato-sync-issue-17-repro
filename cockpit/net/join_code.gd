extends RefCounted
class_name JoinCode
## A JOIN CODE: six characters a host reads out and a friend types, and the words for why something typed is not one.
##
## Asked for on 2026-09-14: "a join code for steam players so they can join a game via a join code rather than having
## to be invited or searching for a game." The host's lobby carries the code as lobby data and a joiner finds it by a
## search filtered on it; see `Net.host_steam` and `Net.join_code`. This file knows nothing about Steam and depends on
## nothing, so `Net`, the keypad and every test can ask it without reaching back.
##
## ONE VALIDATOR. Untrusted input proposes: what a person typed on a keypad or a keyboard comes here first, and a
## directory is never asked about anything this refuses. The refusal is a sentence, because a person who typed a zero
## needs to be told that codes have none, not that "the code is invalid".
##
## THE ALPHABET. Thirty-two symbols, the digits 2 to 9 and the capitals without I or O. 0 and O, and 1 and I, are
## the pairs a code read across a room or down a voice channel loses, and with neither of either pair in the alphabet
## there is nothing to mistake them for. Thirty-two because it divides a byte: a random byte reduced modulo the alphabet
## lands on every symbol exactly eight times in 256, so no symbol is likelier than another. L and U stay in -- nobody
## reads a capital L as a digit that is not there.
##
## SIX OF THEM. 32^6 is 1,073,741,824 codes. The chance a new code matches one of n lobbies already open is n/32^6:
## 9.3e-8 at a hundred, 9.3e-6 at ten thousand. `Net.host_steam` searches for a code before it opens a lobby with it and
## draws again if anything answers, and a joiner who finds two refuses, so a clash is a sentence rather than a wrong
## game. It is not a password: at a hundred open lobbies a guessed code finds one about once in ten million searches.
##
## Measured in tests/steam_probe.gd on 2026-09-14: Steam's lobby string filter ignores case, so a code typed in lower
## case finds its lobby even before this folds it -- this folds it anyway, so the code a person sees read back is the
## code that is searched for.

const ALPHABET: String = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
const LENGTH: int = 6
## The pairs the alphabet leaves out, named so the refusal can say which.
const CONFUSABLE: String = "0O1I"
## The code the refusals show as an example of what one looks like.
const EXAMPLE: String = "K7MQ2X"
## How a code is shown: two threes, which is how a person reads six characters aloud.
const GROUP: int = 3


## A CODE FROM `LENGTH` RANDOM BYTES. Pure, so a test can hand it any bytes it likes; `fresh` is the one that draws.
static func make(random: PackedByteArray) -> String:
	var out: String = ""
	for i in range(mini(LENGTH, random.size())):
		out += ALPHABET[int(random[i]) % ALPHABET.length()]
	return out if out.length() == LENGTH else ""


## A new code, from the operating system's random source rather than `randi`, whose seed a test or a replay can fix.
static func fresh() -> String:
	return make(Crypto.new().generate_random_bytes(LENGTH))


## THE CODE A PERSON MEANT, or "" when what they typed is not one. Case folds; spaces and dashes separate groups.
static func read(typed: String) -> String:
	return _plain(typed) if why_not(typed) == "" else ""


## WHY WHAT WAS TYPED IS NOT A CODE, as a sentence, or "" when it is one.
##
## A wrong symbol is said before a wrong length: it is the thing a person can see they got wrong, and fixing the length
## first would leave them with a code that is still refused.
static func why_not(typed: String) -> String:
	var plain: String = _plain(typed)
	if plain.is_empty():
		return "Type the host's code first."
	for c in plain:
		if CONFUSABLE.contains(c):
			return "Codes have no 0, O, 1 or I."
	for c in plain:
		if not ALPHABET.contains(c):
			return "A code is letters and the digits 2 to 9, and '%s' is not one." % c
	if plain.length() != LENGTH:
		return "A code is %d characters, like %s (you typed %d)." % [LENGTH, spell(EXAMPLE), plain.length()]
	return ""


## A code as it is shown: K7M-Q2X.
static func spell(code: String) -> String:
	if code.length() <= GROUP:
		return code
	return "%s-%s" % [code.substr(0, GROUP), code.substr(GROUP)]


static func _plain(typed: String) -> String:
	return typed.strip_edges().to_upper().replace(" ", "").replace("-", "")

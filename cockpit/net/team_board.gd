class_name TeamBoard
extends RefCounted
## WHICH TEAM EACH PLAYER IS ON, and who is allowed to say so.
##
## The user asked for it in those words (2026-09-19): "let's have 'TEAMS' that are assigned by the host, there should be
## a button a user holds down to talk to everyone and another that allows them to talk to their team."
##
## THE HOST DECIDES; EVERYBODY ELSE DISPLAYS (CLAUDE.md rule 10). A team is not a thing a player may set about
## themselves: it decides who hears them, so a client that could write its own team could put itself on a team it was not
## invited to and listen. So this file holds the RULES -- which teams there are, what a team number may be, what a team
## is called -- and the authority lives on the host, which publishes each player's team on the roster card it already
## publishes (`Net._publish_roster_if_changed`). A client's team is therefore read from the same place its name and
## colour are read from, and the host's copy is the only one that is written.
##
## ONE NUMBER, ONE PLACE (rule 4): NOBODY is 0 and the teams are 1..COUNT, and both the UI's cycle button and the wire
## validator ask this file rather than each keeping a bound. A team number that does not pass `holds` is NOBODY, not a
## clamp to the nearest team -- a magnitude clamped into a real team would put a player on somebody's team by accident,
## which is the one failure this whole file exists to prevent.
##
## Rejected: teams as a free string the host types. It reads better on a board and it is a validator that has to distrust
## text on every card, for a feature whose whole point is that the number decides who hears you. Four numbered teams with
## fixed names cost nothing to check and cannot be spoofed into looking like another team.

## NOT ON A TEAM. Talks to everyone, hears everyone, and its team-talk button is refused with words.
const NOBODY: int = 0
## HOW MANY TEAMS THERE ARE. Four because two is not enough to test that a third is excluded, and because the lobby
## draws them as buttons in a row that has to stay legible; a session of 64 players on four teams is 16 each.
const COUNT: int = 4
## What each team is called on the board. The index is the team number, so `NAMES[0]` is what "no team" reads as.
const NAMES: Array[String] = ["NO TEAM", "RED", "BLUE", "GREEN", "GOLD"]


## IS THIS A TEAM SOMEBODY CAN BE ON. `NOBODY` is not: it is the absence of one, and the two are told apart everywhere
## because "talk to my team" must be refused for a player on none rather than quietly reaching every other unassigned
## player.
static func holds(team: int) -> bool:
	return team >= 1 and team <= COUNT


## A TEAM NUMBER OFF THE WIRE, or `NOBODY`. Anything that is not a team this build has is NOBODY: see the note above on
## why this does not clamp.
static func read(team: int) -> int:
	return team if holds(team) else NOBODY


## WHAT TO WRITE FOR A TEAM, for any number at all, so a board never has a blank where a team should be.
static func name_of(team: int) -> String:
	return NAMES[team] if team >= 0 and team < NAMES.size() else NAMES[NOBODY]


## THE NEXT TEAM ROUND, which is what the host's one button per player does: NO TEAM, RED, BLUE, GREEN, GOLD, NO TEAM.
## A cycle rather than a team each: the row stays one button wide however many teams there are, and the host can always
## take somebody off a team, which a row of four team buttons cannot do without a fifth.
static func next(team: int) -> int:
	return 0 if team >= COUNT or team < 0 else team + 1


## CAN THESE TWO HEAR EACH OTHER ON TEAM TALK. The one question the whole feature turns on, in one place, so the sender's
## filter and the test that proves a third player is excluded ask the same function.
##
## A player on NO TEAM shares a team with nobody, INCLUDING other players on no team. Otherwise "no team" would quietly
## become a fifth team whose members talk privately to each other -- which is what a straight `mine == theirs` gives you,
## and what `tests/flat_lobby.gd` has a check for.
static func share_a_team(mine: int, theirs: int) -> bool:
	return holds(mine) and mine == theirs

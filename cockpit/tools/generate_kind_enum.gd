extends Node
## WRITES `Sim.Kind` FROM THE LIBRARY'S KIND TABLE, so the enum is never typed by hand.
##
## Run from cockpit with:   Godot --headless res://tools/generate_kind_enum.tscn
##
## The kinds are a row each in `ashiato-gd/src/cockpit/cockpit_kinds.inc`, and the library answers them as
## `CockpitWorld.kind_table()`. GDScript needs a NAMED enum -- `Sim.Kind.TOMCAT` is written in two hundred places and a
## number there would be a bug waiting -- and an enum cannot be read from an engine call, so it is written out, here,
## between two marker lines in sim.gd. It was typed by hand beside the C++ until lane/kinds (2026-09-18), and agreed
## only because a test counted both. tests/many_kinds.gd now compares the written block with what this would write, so
## a hand edit, or a row added without running this, is red and names the entry.
##
## Rewrites only when the text differs, keeps sim.gd's line endings, and prints RESULT=.

const SIM := "res://autoload/sim.gd"
const BEGIN := "## BEGIN KINDS: written by tools/generate_kind_enum.tscn from cockpit_kinds.inc. Do not edit by hand."
const END := "## END KINDS"
## Wrapped a little under the house's 120 columns.
const WIDTH := 110


## THE ENUM AS IT SHOULD READ for a kind table, with `newline` between lines. The test asks this too.
static func enum_text(table: Array, newline: String = "\n") -> String:
	var lines: PackedStringArray = ["enum Kind {"]
	var line := "\t"
	for i in range(table.size()):
		var word := String((table[i] as Dictionary)["id"]) + ("," if i < table.size() - 1 else "")
		if line.length() > 1 and line.length() + 1 + word.length() > WIDTH:
			lines.append(line)
			line = "\t"
		line += (" " if line.length() > 1 else "") + word
	lines.append(line)
	lines.append("}")
	return newline.join(lines)


## THE BLOCK BETWEEN THE MARKERS in sim.gd's text, without them, or "" when either marker is missing.
static func written_block(text: String) -> String:
	var begin := text.find(BEGIN)
	var end := text.find(END)
	if begin < 0 or end < begin:
		return ""
	return text.substr(begin + BEGIN.length(), end - begin - BEGIN.length()).strip_edges()


func _ready() -> void:
	if not ClassDB.class_exists("CockpitWorld"):
		print("RESULT=FAIL the ashiato extension did not load")
		get_tree().quit(1)
		return
	var table: Array = ClassDB.class_call_static(&"CockpitWorld", &"kind_table")
	var text := FileAccess.get_file_as_string(SIM)
	var newline := "\r\n" if text.contains("\r\n") else "\n"
	var begin := text.find(BEGIN)
	var end := text.find(END)
	if begin < 0 or end < begin:
		print("RESULT=FAIL %s has no '%s' ... '%s' block" % [SIM, BEGIN, END])
		get_tree().quit(1)
		return
	var fresh := text.substr(0, begin) + BEGIN + newline + enum_text(table, newline) + newline + text.substr(end)
	if fresh == text:
		print("RESULT=PASS Sim.Kind already lists the library's %d kinds" % table.size())
	else:
		var file := FileAccess.open(SIM, FileAccess.WRITE)
		file.store_string(fresh)
		file.close()
		print("RESULT=PASS wrote Sim.Kind from the library's %d kinds" % table.size())
	get_tree().quit(0)

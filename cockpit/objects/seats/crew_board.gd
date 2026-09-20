@tool
extends Node3D
class_name CrewBoard
## WHO IS IN WHAT SEAT, on a small placard low on the outboard console.
##
## A crew of four spread through a fuselage cannot see each other. The pilot has no way to
## know whether anybody is on the ramp, and a gunner has no way to know whether the seat
## they are about to take is free -- and both of those matter before you press the button
## that moves you.
##
## One row per SEAT and not per occupant, because an empty seat is the interesting half: the
## board says what the craft has as well as who is in it -- up to `ROWS` seats. Past that
## the board shows your seat, the pilot's and whoever else is aboard, and says how many more
## seats there are, so a 64-seat craft does not grow a 64-row board.
##
## SMALL, LOW AND OUT OF THE WAY, which it was not. It was a 0.34 x 0.175 m slab with 4 cm
## letters standing 0.21 m under the eye and 0.36 m ahead, beside the flight display: 27
## degrees off the nose at its inner top corner, the biggest thing in the cockpit, and the
## user called it "the GIANT PILOT screen" (2026-09-18). It is now an 11 x 5.5 cm placard
## with 7 mm capitals beside the hip, 0.57 m from the eye, 60 degrees below it and 65 to the
## side -- about 12 mrad of capital, 15 pixels of a headset's 0.8 mrad pixel, and nowhere
## near the view. FIRST PUT 0.43 m under the eye and 0.22 ahead, where it stood over the
## lower corner of the map screen in the eye shot; 0.10 m further aft it clears it.
##
## ITS PLACE IS HERE AND NOWHERE ELSE (`placement`). The station puts it there on `fit`,
## before a right-hand seat is mirrored, so no seat scene types a transform for it and the
## authored packages carry whatever the generator read off a fitted station. It is the ONE
## thing on the console every station has, so its side of the seat is what `_outboard_side`
## reads: +x on a left-hand seat, -x once mirrored.

## How wide the placard is, how tall each row, and how many rows it shows, in metres.
const WIDTH: float = 0.11
const ROW: float = 0.011
const ROWS: int = 4
## The whole slab: the rows and a margin of half a row above and below.
const HEIGHT: float = ROW * (ROWS + 1)
## Thick enough to read as a thing screwed to the console rather than a decal.
const THICK: float = 0.006

## WHERE IT SITS, in the station's frame on a left-hand seat: outboard of the stick and aft of
## the map screen, 0.49 m under the eye. See the doc block; the numbers are measured there.
const OUTBOARD: float = 0.26
const BELOW_EYE: float = 0.49
const AHEAD: float = -0.12
## TILTED UP AND TURNED IN AT THE FACE, so the lines are read square rather than
## foreshortened: 60 degrees up to the eye and most of the way round towards it.
const TILT: float = -1.05
const TURN: float = -0.90

var _label: Label3D = null


func _ready() -> void:
	var panel := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(WIDTH, HEIGHT, THICK)
	panel.mesh = slab
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.06, 0.07)
	dark.roughness = 0.9
	panel.material_override = dark
	add_child(panel)

	# A Label3D rather than a viewport with a Control in it: this is four short lines that
	# change when somebody sits down, and a render target per cockpit to draw them would
	# cost more than every station in the game put together.
	_label = Label3D.new()
	_label.font_size = 32
	# A LINE A ROW TALL: Label3D sets a line at about 1.1 of its font size, in pixels.
	_label.pixel_size = ROW / (32.0 * 1.1)
	_label.modulate = Color(0.60, 0.85, 0.62)
	_label.outline_size = 0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_label.no_depth_test = false
	_label.position = Vector3(-WIDTH * 0.5 + 0.005, 0.0, THICK * 0.5 + 0.001)
	add_child(_label)


## WHERE THE BOARD GOES in a left-hand seat's station, with the eye at `eye_height`.
static func placement(eye_height: float) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(TILT, TURN, 0.0)),
		Vector3(OUTBOARD, eye_height - BELOW_EYE, AHEAD))


## Half the face, for the checks that ask what stands in front of it.
static func half() -> Vector2:
	return Vector2(WIDTH * 0.5, HEIGHT * 0.5)


## Show a crew. Each row is `{seat, station, client, mine}` -- see VehicleView.crew.
func show_crew(crew: Array) -> void:
	if _label == null:
		return
	var wanted: String = "
".join(lines_for(crew))
	if _label.text != wanted:
		_label.text = wanted


## THE LINES FOR A CREW, never more than `ROWS`. Every seat while they fit; past that your
## own, the pilot's (seat 1), every other one somebody is in while there is room, and a last
## line saying how many seats are left out.
static func lines_for(crew: Array) -> PackedStringArray:
	var shown: Array = crew
	var left_out: int = 0
	if crew.size() > ROWS:
		shown = []
		for row in crew:
			if bool(row.get("mine", false)) or int(row.get("seat", -1)) == 0:
				shown.append(row)
		for row in crew:
			if shown.size() >= ROWS - 1:
				break
			if not shown.has(row) and int(row.get("client", 0)) > 0:
				shown.append(row)
		shown.sort_custom(func(a, b): return int(a.get("seat", 0)) < int(b.get("seat", 0)))
		left_out = crew.size() - shown.size()
	var lines: PackedStringArray = []
	for row in shown:
		var who: String = "--"
		var client: int = int(row.get("client", 0))
		if bool(row.get("mine", false)):
			who = "YOU"
		elif client > 0:
			who = "P%d" % client
		lines.append("%d %-8s %s" % [int(row.get("seat", 0)) + 1,
			String(row.get("station", "?")).to_upper(), who])
	if left_out > 0:
		lines.append("+%d MORE SEATS" % left_out)
	return lines

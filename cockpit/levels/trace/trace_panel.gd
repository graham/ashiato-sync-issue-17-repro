extends Control
class_name TracePanel
## THE TRACE LEVEL'S INSTRUMENTS: the banner, the timeline and the inputs, drawn from the sample the level is on.
##
## It is handed the level and draws what the level has; it decides nothing but where a click on the timeline lands (which
## it announces by asking the level to seek). Three parts:
##   - THE BANNER (top left): that this is a puppet posed from a file, which file, the craft, the time and the rate, and the
##     keys. It is the answer to "is this a simulation?", so it is never turned off.
##   - THE STRIP (bottom): each recorded input as a line over the last `STRIP_BEHIND` seconds and the next `STRIP_AHEAD`,
##     one lane a channel, with the marker at now. A stick sawing about what it chases shows here as a comb, beside the aeroplane
##     whose motion it makes. A file without the stick (a library before `flight_controls`) shows the attitude and the lever
##     and SAYS the stick was not recorded.
##   - THE DIALS (bottom right): the stick as a dot in a box, rudder and throttle as bars, and the levers as words.
## The timeline is the bar under the strip: a click on it jumps there.

const LANE_HEIGHT: float = 46.0
const MARGIN: float = 18.0
## The game's own status and key hints take the top 70 px; the banner stands under them.
const TOP: float = 70.0
const DIAL: float = 150.0
const INK := Color(0.95, 0.86, 0.55)
const DIM := Color(0.62, 0.58, 0.45)
const LINE := Color(0.35, 0.95, 1.0)
const NOW := Color(1.0, 0.72, 0.15)
const BACK := Color(0.03, 0.04, 0.06, 0.62)

var level: TraceLevel = null


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and level != null:
		var bar: Rect2 = timeline_rect()
		if bar.grow(6.0).has_point(click.position):
			level.seek_fraction((click.position.x - bar.position.x) / bar.size.x)
			accept_event()


func timeline_rect() -> Rect2:
	return Rect2(MARGIN, size.y - MARGIN - 12.0, size.x - MARGIN * 2.0, 12.0)


func _strip_rect(lanes: int) -> Rect2:
	var height: float = LANE_HEIGHT * float(lanes)
	return Rect2(MARGIN, size.y - MARGIN - 12.0 - 14.0 - height, size.x - DIAL - MARGIN * 4.0, height)


func _draw() -> void:
	if level == null:
		return
	var font: Font = ThemeDB.fallback_font
	var lines: PackedStringArray = _banner_lines()
	var box := Rect2(MARGIN - 8.0, TOP - 8.0, 620.0, 22.0 * float(lines.size()) + 12.0)
	draw_rect(box, BACK)
	for i in lines.size():
		draw_string(font, Vector2(MARGIN, TOP + 14.0 + 22.0 * float(i)), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
			NOW if i == 0 else INK)
	if not level.has_flight():
		return
	_draw_the_strip(font)
	_draw_the_dials(font)
	_draw_the_timeline()


func _banner_lines() -> PackedStringArray:
	var out := PackedStringArray()
	out.append("TRACE PLAYBACK: A PUPPET POSED FROM A FILE, NOT A SIMULATION")
	if not level.has_flight():
		out.append(level.refusal)
		out.append("Start with:  -- --world=trace --trace-in=<file.jsonl>   (written by --trace-craft=)")
		return out
	out.append("%s  ·  %s  ·  %d samples at %s Hz  ·  stick %s" % [level.path_asked.get_file(),
		Sim.kind_name(level.kind), level.rows.size(), str(level.header.get("hz", "?")),
		"recorded" if String(level.header.get("stick", "absent")) == "flight_controls" else "NOT recorded"])
	var row: Dictionary = level.row_at(level.clock)
	out.append("t %.2f / %.2f s   ·   %s   ·   %sx   ·   flown by %s" % [level.clock, level.duration(),
		"PLAYING" if level.playing else "PAUSED", str(level.rate), String(row.get("flown", "?"))])
	var euler: Dictionary = row.get("euler", {})
	out.append("speed %.1f m/s   ·   height %.0f m   ·   pitch %.1f  roll %.1f  yaw %.0f deg   ·   aoa %s" % [
		float(row.get("speed", 0.0)), float((row.get("pos", [0, 0, 0]) as Array)[1]),
		float(euler.get("pitch", 0.0)), float(euler.get("roll", 0.0)), float(euler.get("yaw", 0.0)),
		"%.1f" % float(row["aoa"]) if row.has("aoa") else "-"])
	out.append("SPACE play · , . speed · ←/→ 5 s (SHIFT 30) · 0-9 tenths · click the bar · C camera · right drag · wheel")
	if level.wider_than_map:
		out.append("this flight is wider than the map: the ground ends before the path does")
	return out


func _draw_the_strip(font: Font) -> void:
	var channels: Array[Dictionary] = level.strip_channels()
	var rect: Rect2 = _strip_rect(channels.size())
	draw_rect(rect.grow(6.0), BACK)
	var start: float = level.clock - TraceLevel.STRIP_BEHIND
	var window: float = TraceLevel.STRIP_BEHIND + TraceLevel.STRIP_AHEAD
	var first: int = level.index_at(maxf(start, 0.0))
	var last: int = level.index_at(minf(level.clock + TraceLevel.STRIP_AHEAD, level.duration()))
	# EVERY SAMPLE IN THE WINDOW, and no thinning: a stick that saws at 20 Hz has to be seen sawing, and 600 points a lane is cheap.
	for lane in channels.size():
		var channel: Dictionary = channels[lane]
		var band := Rect2(rect.position.x, rect.position.y + LANE_HEIGHT * float(lane), rect.size.x, LANE_HEIGHT)
		draw_line(Vector2(band.position.x, band.end.y), Vector2(band.end.x, band.end.y), DIM, 1.0)
		draw_string(font, band.position + Vector2(4.0, 13.0), String(channel["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DIM)
		var points := PackedVector2Array()
		var low: float = float(channel["low"])
		var high: float = float(channel["high"])
		for i in range(maxi(first, 0), last + 1):
			var row: Dictionary = level.rows[i]
			var group: Dictionary = row.get(String(channel["group"]), {})
			if not group.has(channel["key"]):
				continue
			var x: float = band.position.x + band.size.x * (float(level.times[i]) - start) / window
			var frac: float = clampf((float(group[channel["key"]]) - low) / (high - low), 0.0, 1.0)
			points.append(Vector2(x, band.end.y - 4.0 - frac * (band.size.y - 8.0)))
		if points.size() >= 2:
			draw_polyline(points, LINE, 1.5)
	var now_x: float = rect.position.x + rect.size.x * TraceLevel.STRIP_BEHIND / window
	draw_line(Vector2(now_x, rect.position.y), Vector2(now_x, rect.end.y), NOW, 2.0)
	if String(level.header.get("stick", "absent")) != "flight_controls":
		draw_string(font, Vector2(rect.position.x + 4.0, rect.position.y - 10.0),
			"the stick was not recorded in this file (the library predates flight_controls): attitude and lever shown", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, NOW)


func _draw_the_dials(font: Font) -> void:
	var row: Dictionary = level.row_at(level.clock)
	var stick: Dictionary = row.get("stick", {})
	var levers: Dictionary = row.get("levers", {})
	var square := Rect2(size.x - DIAL - MARGIN, size.y - DIAL - MARGIN - 70.0, DIAL, DIAL)
	draw_rect(square.grow(6.0), BACK)
	draw_rect(square, DIM, false, 1.0)
	draw_line(square.get_center() - Vector2(DIAL * 0.5, 0.0), square.get_center() + Vector2(DIAL * 0.5, 0.0), DIM, 1.0)
	draw_line(square.get_center() - Vector2(0.0, DIAL * 0.5), square.get_center() + Vector2(0.0, DIAL * 0.5), DIM, 1.0)
	if stick.is_empty():
		draw_string(font, square.position + Vector2(10.0, DIAL * 0.5), "no stick", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DIM)
	else:
		# Pull (positive pitch) is toward the pilot, so the dot goes DOWN the box; roll right is right.
		var dot: Vector2 = square.get_center() + Vector2(float(stick.get("roll", 0.0)), float(stick.get("pitch", 0.0))) * DIAL * 0.5
		draw_circle(dot, 7.0, NOW)
		var rudder := Rect2(square.position.x, square.end.y + 8.0, DIAL, 8.0)
		draw_rect(rudder, DIM, false, 1.0)
		var bar: float = clampf(float(stick.get("rudder", 0.0)), -1.0, 1.0)
		draw_rect(Rect2(rudder.get_center().x, rudder.position.y, bar * DIAL * 0.5, rudder.size.y), LINE)
		var throttle := Rect2(square.position.x, square.end.y + 22.0, DIAL, 8.0)
		draw_rect(throttle, DIM, false, 1.0)
		draw_rect(Rect2(throttle.position.x, throttle.position.y, float(stick.get("throttle", 0.0)) * DIAL, throttle.size.y), NOW)
	var words: String = ""
	for key in ["throttle", "flaps", "trim"]:
		if levers.has(key):
			words += "%s %.2f  " % [key, float(levers[key])]
	for key in ["gear", "spoilers"]:
		if levers.has(key):
			words += "%s %s  " % [key, "down" if bool(levers[key]) else "up"]
	draw_string(font, Vector2(size.x - 470.0, square.end.y + 50.0), words, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)


func _draw_the_timeline() -> void:
	var bar: Rect2 = timeline_rect()
	draw_rect(bar, BACK)
	draw_rect(bar, DIM, false, 1.0)
	var fraction: float = level.clock / maxf(level.duration(), 0.001)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * fraction, bar.size.y)), Color(NOW, 0.55))
	# A tick for every mark on the path, so the bar and the marks in the air are the same instants.
	var when: float = 0.0
	while when <= level.duration() + 0.0001 and level.mark_every > 0.0:
		var x: float = bar.position.x + bar.size.x * when / maxf(level.duration(), 0.001)
		draw_line(Vector2(x, bar.position.y), Vector2(x, bar.position.y + 4.0), LINE, 1.0)
		when += level.mark_every

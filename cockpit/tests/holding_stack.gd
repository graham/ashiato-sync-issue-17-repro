extends Node
## THE TRAFFIC PAGE drives the real layered stack. Counts come back from the page and
## from native vehicle state, batching is observed frame by frame, and every assignment
## is judged against the aircraft's state rather than the stack's request.

var _failed := false
var _said: Array[String] = []


func _ready() -> void:
	if not Sim.is_available():
		print("[holding_stack] extension missing")
		get_tree().quit(1)
		return
	await _start()
	Sim.add_static_box(Vector3(0.0, -400.0, 0.0), Vector3(7200.0, 400.0, 7200.0))
	for at in [Vector3(-3000.0, 500.0, -3000.0), Vector3(3000.0, 500.0, -3000.0),
			Vector3(3000.0, 500.0, 3000.0), Vector3(-3000.0, 500.0, 3000.0)]:
		Sim.server.add_ai_waypoint(Sim.Kind.PLANE, at)
	var page := ClipboardPage.new()
	add_child(page)
	var stack := HoldingStack.new()
	add_child(stack)
	stack.setup(Sim.server)
	page.chose_stack.connect(stack.set_count)
	# WHERE EVERY AEROPLANE GOES, BEFORE ANY OF THEM IS STOOD UP. The cap was raised from 200 to 600 on
	# 2026-09-17, and the whole of that change is that the ring stayed 200 wide and the stack laps UPWARD. If the
	# angle had gone on being `TAU * index / MOST`, raising the cap would have moved all 200 of the aeroplanes
	# every measurement in agents.md was taken on, silently. THE DATUM IS THE OLD ARITHMETIC, WRITTEN OUT HERE BY
	# HAND: asking `slot_of` what `slot_of` does would agree with any mistake in it.
	var moved := PackedStringArray()
	for index in range(200):
		var slot: Dictionary = HoldingStack.slot_of(index)
		var was_angle: float = TAU * float(index) / 200.0
		var was_layer: int = index % 10
		if absf(float(slot["angle"]) - was_angle) > 1e-6 or int(slot["layer"]) != was_layer:
			moved.append("%d: %.6f/%d against %.6f/%d" % [index, float(slot["angle"]), int(slot["layer"]),
				was_angle, was_layer])
	_check("the_first_two_hundred_are_where_they_have_always_been", moved.is_empty(),
		"%d moved%s" % [moved.size(), "" if moved.is_empty() else ": " + ", ".join(moved.slice(0, 3))])
	# AND A LAP GOES ABOVE THE LAST, NOT BESIDE IT: same angle round the ring, ten layers higher. That is what keeps
	# the horizontal crowding identical -- each altitude band still holds twenty aeroplanes, 18 degrees apart.
	var beside := PackedStringArray()
	for index in range(200, HoldingStack.MOST):
		var slot: Dictionary = HoldingStack.slot_of(index)
		var below: Dictionary = HoldingStack.slot_of(index - 200)
		if absf(float(slot["angle"]) - float(below["angle"])) > 1e-6 \
				or int(slot["layer"]) != int(below["layer"]) + HoldingStack.LAYERS:
			beside.append(str(index))
	_check("each_lap_stands_ten_layers_above_the_one_below", beside.is_empty(),
		"%d out of place" % beside.size())

	var two_hundred := _button(page, "200")
	_check("the_page_offers_the_200_plane_rung", two_hundred != null, "button=%s" % two_hundred)
	if two_hundred != null:
		two_hundred.pressed.emit()
	var prior := 0
	var largest_batch := 0
	for i in range(300):
		await get_tree().physics_frame
		var now := stack.count()
		largest_batch = maxi(largest_batch, now - prior)
		prior = now
		if now == 200:
			break
	_check("the_200_button_stands_up_200", stack.count() == 200, "%d planes" % stack.count())
	# AND FIFTY AT A TIME, which is what the user asked for. The step buttons are the real page path, not `set_count`.
	var plus_fifty := _button(page, "+50")
	_check("the_page_offers_a_fifty_at_a_time_step", plus_fifty != null, "button=%s" % plus_fifty)
	if plus_fifty != null:
		page.show_load_test(stack.count(), Net.extra_latency_ms, "test")
		plus_fifty.pressed.emit()
	for i in range(300):
		await get_tree().physics_frame
		if stack.count() >= 250:
			break
	_check("fifty_more_arrive_through_the_page", stack.count() == 250, "%d planes" % stack.count())
	# THEN THE CAP ITSELF, which is the rung this lane needs to be able to reach.
	var the_cap := _button(page, str(HoldingStack.MOST))
	_check("the_page_offers_the_cap", the_cap != null, "button=%s" % the_cap)
	if the_cap != null:
		the_cap.pressed.emit()
	for i in range(900):
		await get_tree().physics_frame
		if stack.count() == HoldingStack.MOST:
			break
	page.show_load_test(stack.count(), Net.extra_latency_ms, "test")
	_check("the_count_is_read_back_from_the_page", page.load_count() == HoldingStack.MOST,
		"page says %d" % page.load_count())
	_check("spawning_is_bounded_per_tick", largest_batch <= HoldingStack.BATCH,
		"largest observed batch %d, limit %d" % [largest_batch, HoldingStack.BATCH])
	# The stack's physics callback runs after this frame's native snapshot. Give the last
	# batch one server tick to appear in `vehicle_states`, then count that public view.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var states: Dictionary = {}
	for state in Sim.server.vehicle_states():
		states[int((state as Dictionary)["entity"])] = state
	var alive := 0
	for entity in stack.entities():
		if states.has(entity):
			alive += 1
	_check("every_aircraft_the_cap_allows_really_exists", alive == HoldingStack.MOST,
		"%d of %d stack ids in vehicle_states" % [alive, HoldingStack.MOST])
	# NO TWO WITHIN A DRAWN WINGSPAN, MEASURED FROM WHERE THEY ACTUALLY ARE rather than from the arithmetic that put
	# them there. A cap raised past what the ring can hold would show up here as two aeroplanes in one piece of air.
	#
	# THE DATUM IS THE DRAWN SPAN AND NOT THE COLLISION BOX, and the difference is a factor of nine. This check first
	# used `extents.x * 2`, which is the hull: 1.5 m, against aeroplanes 76 m apart. It passed, and it would have
	# passed with the stack ten times denser, because an aeroplane's hull is a fraction of the aeroplane
	# (agents.md, "Aircraft are drawn much wider than they collide": 13 m of aeroplane around a 1.5 m hull). `span`
	# is the semi-span the renderer builds the wing from, so the width a person sees is twice it.
	var geometry: Dictionary = Sim.server.kind_geometry(Sim.Kind.PLANE)
	var span: float = float(geometry.get("span", 6.5)) * 2.0
	var hull: float = float((geometry.get("extents", Vector3(8.0, 2.0, 6.0)) as Vector3).x) * 2.0
	var closest := INF
	var closest_pair := ""
	var places: Array = []
	for entity in stack.entities():
		if states.has(entity):
			places.append((states[entity] as Dictionary)["position"] as Vector3)
	for i in range(places.size()):
		for j in range(i + 1, places.size()):
			var apart: float = (places[i] as Vector3).distance_to(places[j] as Vector3)
			if apart < closest:
				closest = apart
				closest_pair = "%d and %d" % [i, j]
	_check("no_two_aircraft_stand_within_a_drawn_wingspan", closest >= span,
		"closest %.1f m (%s), drawn span %.1f m (hull %.1f m), %d aircraft" % [closest, closest_pair, span, hull,
			places.size()])
	# AND THE TOP OF THE STACK IS UNDER THE WIRE. An aeroplane above `height_max` is one no client could be sent.
	var tallest := 0.0
	for entity in stack.entities():
		tallest = maxf(tallest, stack.assigned_altitude(entity))
	var wire_top: float = float((Sim.server.wire_range() as Dictionary).get("height_max", 0.0))
	_check("the_top_of_the_stack_is_under_the_wire", tallest <= wire_top,
		"tallest %.0f m, wire %.0f m" % [tallest, wire_top])
	var worst := 0.0
	for i in range(1200):
		await get_tree().physics_frame
		if i % 30 != 0:
			continue
		for entity in stack.entities():
			var state: Dictionary = Sim.server.vehicle_state(entity)
			if not state.is_empty():
				worst = maxf(worst, absf((state["position"] as Vector3).y - stack.assigned_altitude(entity)))
	_check("every_aircraft_remains_inside_half_a_layer", worst <= stack.layer_spacing() * 0.5,
		"worst %.2f m, half spacing %.2f m" % [worst, stack.layer_spacing() * 0.5])
	var zero := _button(page, "0")
	if zero != null:
		zero.pressed.emit()
	for i in range(300):
		await get_tree().physics_frame
		if stack.count() == 0:
			break
	_check("zero_retires_the_whole_stack", stack.count() == 0, "%d remain" % stack.count())
	var latency := _button(page, "100 MS")
	var chosen_latency := [-1]
	page.chose_latency.connect(func(ms: int): chosen_latency[0] = ms)
	if latency != null:
		latency.pressed.emit()
	_check("link_latency_is_also_a_real_page_control", chosen_latency[0] == 100,
		"page announced %d ms" % chosen_latency[0])
	print("RESULT=%s%s" % ["FAIL " if _failed else "PASS", ", ".join(_said)])
	get_tree().quit(1 if _failed else 0)


func _button(root: Node, words: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		if (node as Button).text == words:
			return node as Button
	return null


func _check(name: String, passed: bool, detail: String) -> void:
	print("[holding_stack] %s %s (%s)" % ["PASS" if passed else "FAIL", name, detail])
	if not passed:
		_failed = true
		_said.append(name)


func _start() -> void:
	var waiting: Array = [not Sim.is_ready]
	if bool(waiting[0]):
		Sim.sim_ready.connect(func(): waiting[0] = false, CONNECT_ONE_SHOT)
	Net.play_solo()
	Sim.start()
	var patience := 600
	while bool(waiting[0]) and patience > 0:
		patience -= 1
		await get_tree().physics_frame

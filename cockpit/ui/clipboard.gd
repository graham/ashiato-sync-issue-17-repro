extends Node3D
class_name Clipboard
## THE MENU YOU CARRY: a panel in your left hand, worked with your right.
##
## Every menu in this game was furniture until now -- two screens standing on a desk in the
## room you start in -- and the moment you are flying there is nothing to press. This is the
## same `TouchPanel` those screens are, with a different page on it, held rather than stood
## on something.
##
## ---------------------------------------------------------------------------------
## IN THE HAND IS NOT THE SAME AS ON THE HEAD
## ---------------------------------------------------------------------------------
##
## There is a rule in this project that a summoned panel is placed ONCE and then belongs to
## the play space, because a panel welded in front of your eyes is one you cannot look away
## from, cannot look around and cannot lean in to read -- and in a headset that is genuinely
## unpleasant, because the one thing your eyes expect of the world is that it holds still
## while you move.
##
## A clipboard is not that. It is on the end of your arm: you look away from it by looking
## away, you put it away by dropping your hand, and it holds still relative to the thing
## holding it. The rule is about the HEAD, and this is a hand.
##
## THE LEFT HAND HOLDS IT AND THE RIGHT HAND PRESSES IT, which is the other half of why it
## works: a panel in a hand that also has to press it is a panel you cannot press.

const PAGE := preload("res://ui/menus/clipboard_page.tscn")

## How big the board is and how it sits in the hand: tilted back towards the face, the way
## anything held on a clipboard is, and set forward of the grip so the hand is not through
## the middle of it.
##
## HALF AS BIG AGAIN SINCE 2026-09-18: "since the number of tabs on the ipad is getting larger let's make the tab sizes a
## little smaller (4 across) and let's make the ipad itself a little bigger (50%)". `GROWN` is that 50 %, and the one
## number everything about the board's size is made from: the glass, the pixels drawn on it and where it sits.
const GROWN: float = 1.5
## The board as it was before, 24 x 30 cm at 1024 px across, which the growth is measured from.
const SIZE_WAS := Vector2(0.24, 0.30)
const SIZE := SIZE_WAS * GROWN
## THE PIXELS ACROSS THE GLASS, grown with it, so the writing keeps its 4,267 pixels a metre and reads as sharp in a
## headset as it did; the page lays out on a canvas 1536 px across and so has half as much room again each way, and
## the words on it are the size they were. A probe that photographs a page at the board's own size uses this too.
const PIXELS: int = int(1024.0 * GROWN)
## THE BUILD, WRITTEN ON THE BOARD'S FRAME UNDER THE GLASS. Asked for on 2026-09-18: a player asked "what build are you
## on" should "look at the ipad" and read it. On the FRAME, not the page, for three reasons: it is then on every tab by
## construction, whatever tab is up; it takes no height from a page whose height is spent (BUILD already scrolls, see
## `ClipboardPage.MAY_SCROLL`); and it never redraws the page's render target. `BuildPlate.line()`, and the same words
## as the lower right of the desktop. The frame is `TouchPanel.BEZEL`, 1 cm, and the writing is `BUILD_LINE_HEIGHT` of
## it: 6 mm, 0.86 degrees from 40 cm, about the size of a phone's small print held at arm's length.
const BUILD_LINE_HEIGHT: float = 0.006
const BUILD_LINE_FONT: int = 48
## Out beyond the grip, and ABOVE AND BEYOND THE CONTROLLER IN THE HAND HOLDING IT, so the eye sees the whole glass.
##
## MOVED 3.0 cm UP AND 5.5 cm FORWARD (2026-09-13), from (0.05, 0.06, -0.15): "the iPad should be raised a couple
## units. Right now the controller is blocking the bottom part of it." Seen from 40 cm straight in front of the glass,
## the controller and its button labels were 4.6 cm over the bottom of the page -- MAIN MENU and the switches, the
## furniture on every tab. Now nothing of it is nearer the glass than 1.1 cm (tests/clipboard.gd,
## `controller_clear_of_the_glass`), with the least total move of any up and forward in half-centimetre steps that
## leaves a centimetre. The tilt is as it was, so the page faces the eye as it did.
##
## GROWN UPWARD FROM ITS BOTTOM EDGE (2026-09-18): the board grew half as much again, and its centre moved up the glass
## by half of what it grew, so the bottom edge -- the one the controller was 4.6 cm over, and is now kept clear of -- is
## where it was. `AT_WAS` is the centre before, and `AT` is made from it and the growth, not typed.
const AT_WAS := Vector3(0.05, 0.09, -0.205)
## Laid back from vertical, not lying flat. At 55 degrees it was a page seen almost edge on
## from a seat, which is a board you cannot read without putting your head on your wrist.
const TILT := -32.0
const AT := AT_WAS + Vector3(0.0, cos(deg_to_rad(TILT)), sin(deg_to_rad(TILT))) * (SIZE.y - SIZE_WAS.y) * 0.5

signal chose_kind(kind: int)
## A JOIN on a free seat: that seat (or -1, any) of the craft that player is in. Passed through like the rest.
signal chose_join(client: int, seat: int)
## The board asked to go back to the desk. Passed straight through, like the other two: a
## panel announces and the thing holding it decides what that means.
signal chose_menu()
## One more machine of that kind, flying itself. Passed through like the rest: a panel
## announces, and the thing holding it decides what that means.
signal chose_traffic(kind: int)
signal chose_stack(count: int)
signal chose_attack(planes: int, helis: int)
signal chose_latency(ms: int)
signal chose_save_bandwidth(on: bool)
## Write what everything in the cockpit is, or stop. Passed through like the rest.
signal chose_labels(on: bool)
## Plain or fine scenery. Passed through like the rest.
signal chose_finish(fine: bool)
## Write what each finger does beside the controllers, or stop. Passed through like the rest.
signal chose_button_labels(on: bool)
## Work that control by turning the wrist rather than by moving the hand.
signal chose_drive(control_name: String, rotate: bool)
## Move the controls about instead of working them, and the three things that go with it.
## Passed through like the rest: a panel announces and the thing holding it decides.
signal chose_build(on: bool)
signal chose_try(on: bool)
signal chose_part(part: StringName)
signal chose_save()
signal chose_save_package()
signal chose_load_package()
signal chose_reset()
## Any time and rate at all, off the TIME tab. Passed through like the rest: the level decides. See ClipboardPage.
signal chose_clock(minutes: float)
signal chose_rate(rate: float)
## CLOUDS on the TIME tab. Passed through like the rest: the level decides, and the session says whose it is.
signal chose_clouds(on: bool)
## Put my head back in the seat. Passed through like the rest: the rig decides.
signal chose_recentre()
## GAME SOUND and VOICE. Passed through like the rest: `PilotHeadphones` decides.
signal chose_game_sound(on: bool)
signal chose_voice(on: bool)
signal chose_radio(text: String)
signal chose_music_sound(on: bool)
signal chose_music(track: String)
signal chose_music_stop
signal chose_music_fade(target_db: float, seconds: float)
## HUD, up or away. Passed through like the rest: the rig decides.
signal chose_hud(on: bool)
signal chose_level_horizon(on: bool)
## SPOTTING SIZE, passed through: the rig keeps it. See SpottingPage.
signal chose_spotting(strength: int)
signal chose_spotting_near(metres: float)

var _panel: TouchPanel = null
var _page: ClipboardPage = null


## THE CRAFT THIS LEVEL OFFERS, handed by the level once its ground stands, and why any are left out. See
## `ClipboardPage.show_kinds`.
func show_kinds(rows: Array, note: String) -> void:
	if _page != null:
		_page.show_kinds(rows, note)
var _pressing: bool = false
## Whether the hand's beam is on any glass this frame, as the rig says. Apart from the finger's press state, so a
## fingertip and a trigger on one frame cannot each think the other has already pressed. See `beam_on_glass`.
var _aimed: bool = false


func _ready() -> void:
	_panel = TouchPanel.new()
	_panel.name = "Glass"
	_panel.page = PAGE
	_panel.size = SIZE
	# THE BOARD IS THE CLOSEST THING TO YOUR FACE IN THE GAME -- it is on the end of your
	# arm -- so it gets the highest density of any panel: 4,267 pixels a metre, kept as the board grew (`PIXELS`).
	_panel.pixels = PIXELS
	_panel.bezel = true
	_panel.position = AT
	_panel.rotation = Vector3(deg_to_rad(TILT), 0.0, 0.0)
	add_child(_panel)
	_panel.add_child(_a_build_line())
	_page = _panel.shown() as ClipboardPage
	if _page != null:
		_page.chose_kind.connect(func(kind: int): chose_kind.emit(kind))
		_page.chose_join.connect(func(client: int, seat: int): chose_join.emit(client, seat))
		_page.chose_menu.connect(func(): chose_menu.emit())
		_page.chose_traffic.connect(func(kind: int): chose_traffic.emit(kind))
		_page.chose_stack.connect(func(count: int): chose_stack.emit(count))
		_page.chose_attack.connect(func(planes: int, helis: int): chose_attack.emit(planes, helis))
		_page.chose_latency.connect(func(ms: int): chose_latency.emit(ms))
		_page.chose_save_bandwidth.connect(func(on: bool): chose_save_bandwidth.emit(on))
		_page.chose_labels.connect(func(on: bool): chose_labels.emit(on))
		_page.chose_finish.connect(func(fine: bool): chose_finish.emit(fine))
		_page.chose_button_labels.connect(func(on: bool): chose_button_labels.emit(on))
		_page.chose_drive.connect(func(what: String, rotate: bool):
			chose_drive.emit(what, rotate))
		_page.chose_build.connect(func(on: bool): chose_build.emit(on))
		_page.chose_try.connect(func(on: bool): chose_try.emit(on))
		_page.chose_part.connect(func(part: StringName): chose_part.emit(part))
		_page.chose_save.connect(func(): chose_save.emit())
		_page.chose_save_package.connect(func(): chose_save_package.emit())
		_page.chose_load_package.connect(func(): chose_load_package.emit())
		_page.chose_reset.connect(func(): chose_reset.emit())
		_page.chose_clock.connect(func(minutes: float): chose_clock.emit(minutes))
		_page.chose_rate.connect(func(rate: float): chose_rate.emit(rate))
		_page.chose_clouds.connect(func(on: bool): chose_clouds.emit(on))
		_page.chose_recentre.connect(func(): chose_recentre.emit())
		_page.chose_game_sound.connect(func(on: bool): chose_game_sound.emit(on))
		_page.chose_voice.connect(func(on: bool): chose_voice.emit(on))
		_page.chose_radio.connect(func(text: String): chose_radio.emit(text))
		_page.chose_music_sound.connect(func(on: bool): chose_music_sound.emit(on))
		_page.chose_music.connect(func(track: String): chose_music.emit(track))
		_page.chose_music_stop.connect(func(): chose_music_stop.emit())
		_page.chose_music_fade.connect(func(db: float, seconds: float): chose_music_fade.emit(db, seconds))
		_page.chose_hud.connect(func(on: bool): chose_hud.emit(on))
		_page.chose_level_horizon.connect(func(on: bool): chose_level_horizon.emit(on))
		_page.chose_spotting.connect(func(strength: int): chose_spotting.emit(strength))
		_page.chose_spotting_near.connect(func(metres: float): chose_spotting_near.emit(metres))
	visible = false
	set_process(false)


## The build line on the frame. See `BUILD_LINE_HEIGHT`.
func _a_build_line() -> Label3D:
	var words := Label3D.new()
	words.name = "BuildLine"
	words.text = BuildPlate.line()
	words.font_size = BUILD_LINE_FONT
	words.pixel_size = BUILD_LINE_HEIGHT / float(BUILD_LINE_FONT)
	words.modulate = BoardStyle.PALE
	words.outline_size = 0
	words.shaded = false
	words.double_sided = false
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# In the middle of the frame's lower edge, just proud of its face, which is `BEZEL_DEPTH` / 2 in front of the panel.
	words.position = Vector3(0.0, -SIZE.y * 0.5 - TouchPanel.BEZEL * 0.5, TouchPanel.BEZEL_DEPTH * 0.5 + 0.0005)
	return words


## The build line on the board's frame. What a test reads.
func build_line() -> Label3D:
	return _panel.get_node_or_null("BuildLine") as Label3D if _panel != null else null


## WHAT THE PILOT HEARS, so the AUDIO tab's switches agree with the headphones. See ClipboardPage.show_audio.
func show_audio(game_sound: bool, voice: bool, said: String) -> void:
	if _page != null:
		_page.show_audio(game_sound, voice, said)
		_redraw()


func show_radio(words: String, can_speak: bool) -> void:
	if _page != null:
		_page.show_radio(words, can_speak)
		_redraw()


func show_music_catalog(ids: Array[String]) -> void:
	if _page != null:
		_page.show_music_catalog(ids)
		_redraw()


func show_music_sound(on: bool) -> void:
	if _page != null:
		_page.show_music_sound(on)
		_redraw()


func show_music(state: Dictionary, status: String, can_choose: bool) -> void:
	if _page != null:
		_page.show_music(state, status, can_choose)
		_redraw()


## WHAT TIME THE LEVEL'S CLOCK SAYS, minutes, or -1 where there is no sky, so the TIME tab shows it. See
## ClipboardPage.show_time.
func show_time(minutes: float) -> void:
	if _page != null:
		_page.show_time(minutes)
		_redraw()


## HOW FAST THE LEVEL'S CLOCK RUNS, game seconds a real second, so the TIME tab's rate row shows it.
func show_rate(rate: float) -> void:
	if _page != null:
		_page.show_rate(rate)
		_redraw()


## WHETHER THE LEVEL DRAWS CLOUDS, so the TIME tab's switch shows it. See ClipboardPage.show_clouds.
func show_clouds(on: bool) -> void:
	if _page != null:
		_page.show_clouds(on)
		_redraw()


func show_map(map: LevelMap, markers: Array[Dictionary]) -> void:
	if _page != null:
		_page.show_map(map, markers)
		_redraw()


func show_load_test(count: int, latency_ms: int, readout: String) -> void:
	if _page != null:
		_page.show_load_test(count, latency_ms, readout)
		_redraw()


## WHICH MODE THE BUILDER'S HANDS ARE IN, so the switch on the page agrees with the thumb
## button that also flips it. See ClipboardPage.show_building.
func show_building(trying: bool) -> void:
	if _page != null:
		_page.show_building(trying)


## WHICH FINISH THE SCENERY IS WEARING, so the switch agrees with the key that also flips it.
func show_finish(fine: bool) -> void:
	if _page != null:
		_page.show_finish(fine)


func show_button_labels(on: bool) -> void:
	if _page != null:
		_page.show_button_labels(on)


## WHETHER SAVE BANDWIDTH IS ON, so the switch agrees with the host's setting. See ClipboardPage.show_save_bandwidth.
func show_save_bandwidth(on: bool) -> void:
	if _page != null:
		_page.show_save_bandwidth(on)


## WHETHER THE HUD IS UP, so the switch agrees with the rig. See ClipboardPage.show_hud.
func show_hud(on: bool) -> void:
	if _page != null:
		_page.show_hud(on)
		_redraw()


## WHAT THE RIG'S SPECTACLES ARE SET TO, so the SPOTTING page agrees with the rig. See SpottingPage.show_spectacles.
func show_spotting(pair: Spectacles) -> void:
	if _page != null:
		_page.show_spotting(pair)
		_redraw()


## WHETHER THE HORIZON IS KEPT LEVEL IN SMALL BOATS, so the switch agrees with the rig. See ClipboardPage.show_level_horizon.
func show_level_horizon(on: bool) -> void:
	if _page != null:
		_page.show_level_horizon(on)
		_redraw()


## WHAT IS IN THIS COCKPIT, so the board can offer a switch for each of them. See
## ClipboardPage.show_controls.
func show_controls(named: Array) -> void:
	if _page != null:
		_page.show_controls(named)


func show_allowed_parts(allowed: Array[StringName]) -> void:
	if _page != null:
		_page.show_allowed_parts(allowed)


## WHAT EVERY INPUT DOES RIGHT NOW, so the board can show a legend. See
## ClipboardPage.show_help, and `PilotRig.legend`, which is where the rows come from.
func show_help(rows: Array) -> void:
	if _page != null:
		_page.show_help(rows)


## WHAT HAPPENED AT THE DOOR, for the LOG tab: `Net.logbook`'s rows, handed on by the rig. See ClipboardPage.show_log.
func show_log(rows: Array) -> void:
	if _page != null:
		_page.show_log(rows)
		_redraw()


## HOW THE FIRE JOB IS GOING, so the board can say so on every tab. See
## ClipboardPage.show_debrief, and `FireFront.debrief`, which is where the sentence comes
## from.
func show_debrief(text: String) -> void:
	if _page != null:
		_page.show_debrief(text)


## UP OR DOWN THE PAGE, a press at a time. See ClipboardPage.scroll.
func scroll(by: int) -> void:
	if _page != null:
		_page.scroll(by)
		if _panel != null:
			_panel.redraw()


## WHAT THE FINGERS DO WHILE THE BOARD IS UP. See `ClipboardPage.bindings`; empty while it is
## away, so a rig that forgot to ask whether it was up would still get nothing from it.
func bindings(hand: int) -> Dictionary:
	return _page.bindings(hand) if _page != null and visible else {}


## THE STICK, FLICKED. See `ClipboardPage.navigate`.
func navigate(towards: Vector2) -> void:
	if _page != null and visible:
		_page.navigate(towards)
		_redraw()


## THE TRIGGER, ON WHAT IS HIGHLIGHTED. See `ClipboardPage.press_highlighted`.
func press_highlighted() -> bool:
	# NOT WHILE THE POINTER IS ON THE GLASS. The same trigger presses what the pointer is on, and
	# a pull that pressed that AND the highlighted control would press two things at once.
	if _aimed:
		return false
	var pressed: bool = _page != null and visible and _page.press_highlighted()
	_redraw()
	return pressed


## THE NEXT TAB ALONG, or back one.
func next_tab(by: int) -> void:
	if _page != null and visible:
		_page.next_tab(by)
		_redraw()


func _redraw() -> void:
	if _panel != null:
		_panel.redraw()


## A JOIN THE HOST NEVER ANSWERED, from the rig that held it: see ClipboardPage.show_unanswered_join.
func show_unanswered_join() -> void:
	if _page != null:
		_page.show_unanswered_join()


## A CRAFT PRESS THE SERVER NEVER SHOWED, from the rig that held it: see ClipboardPage.show_unanswered_kind.
func show_unanswered_kind(kind: int) -> void:
	if _page != null:
		_page.show_unanswered_kind(kind)


## A CRAFT PRESS THE HOST ANSWERED WITHOUT MOVING THIS PLAYER. Kept on the clipboard
## boundary with the other menu answers so PilotRig never reaches through to its page.
func show_kind_answer(kind: int, why: String) -> void:
	if _page != null:
		_page.show_kind_answer(kind, why)


## A MENU PRESS REFUSED because the last one is still waiting: see ClipboardPage.show_still_waiting.
func show_still_waiting() -> void:
	if _page != null:
		_page.show_still_waiting()


## A NO ON THE BOARD, amber. See ClipboardPage.say_no.
func say_no(what: String) -> void:
	if _page != null:
		_page.say_no(what)


## SAY SOMETHING ON THE BOARD, for whoever acted on what it announced. See ClipboardPage.say.
func say(what: String) -> void:
	if _page != null:
		_page.say(what)


## UP OR AWAY. The whole of the interface: one button, both ways.
func toggle() -> void:
	show_board(not visible)


func show_board(up: bool) -> void:
	if visible != up:
		print("[clipboard] %s" % ["up" if up else "away"])
	visible = up
	set_process(up)
	if up and _page != null:
		_hand_the_crew(true)
		_panel.redraw()


func is_up() -> bool:
	return visible


## THE RIGHT HAND AGAINST THE GLASS, once a frame, exactly as the desk offers a fingertip to
## its screens: the panel decides whether the point is on it, so nothing here has to know
## where the buttons are.
##
## A press is the fingertip ARRIVING, not a trigger pull -- a panel you have to point at and
## click is a panel being used with a mouse in a headset -- so it fires once on the way in
## and re-arms when the finger leaves.
func offer_finger(at: Vector3) -> void:
	if not visible or _panel == null:
		return
	var local: Vector3 = _panel.to_local(at)
	if absf(local.z) < TouchPanel.FINGER:
		if not _pressing:
			_pressing = true
			_panel.press(local, true)
			_panel.press(local, false)
		return
	# AND THE POINTER FOLLOWS THE FINGER IN FROM FURTHER OUT than a hover does. Seeing where
	# your hand is about to land is the part that was missing: the button lit up only once
	# you were nearly touching it, by which point you were already committed.
	_panel.point_at(local)
	if absf(local.z) < TouchPanel.FINGER * 6.0:
		_panel.hover(local)
	_pressing = false


## THE MOUSE ON A MONITOR is not this board's any more. On a desk there is no hand to reach with, so the mouse points: a
## ray from the eye through the cursor. That ray used to be offered to this board alone, and nothing else on the desk
## could be clicked; since 2026-09-14 the rig hands it to a `GlassPointer` with every glass that is up, this one among
## them, and the nearest along the ray is pressed the way a fingertip presses it.


## WHETHER THE HAND'S BEAM IS ON ANY GLASS this frame -- this board's, or a screen beyond it -- told by the rig, which
## hands every glass to `HandBeam`. While it is, the trigger is the beam's press, and `press_highlighted` holds off.
##
## It used to be this board's own `aim`, which kept the pull's press state here and knew only about its own glass. With
## the clipboard up and the beam on a desk monitor behind it, the same pull pressed the monitor AND the control
## highlighted here (tests/desk_screens.gd, 2026-09-14).
func beam_on_glass(on: bool) -> void:
	_aimed = on


## Whether the hand's beam is on glass, for the tests.
func is_aimed() -> bool:
	return _aimed


func _process(_delta: float) -> void:
	# The crew list, kept current while the board is up. See `_hand_the_crew`.
	_hand_the_crew(false)


## THE CREWS, READ OFF THE SIMULATION AND HANDED TO THE PAGE, once per simulated tick at most.
##
## `Sim` makes a fresh pilots array each tick, so the SAME array as last time means nothing
## can have changed and the manifest is not built again: one is built at most once a frame and
## once a tick, whichever is rarer. The page then rebuilds its rows only when the manifest differs.
var _pilots_seen: Array = []


func _hand_the_crew(always: bool) -> void:
	if _page == null:
		return
	if not always and is_same(Sim.pilots, _pilots_seen):
		# `tick` rather than `refresh`: the crew list has nothing new, but the session's own line -- the join code and
		# who is aboard -- changes without anybody handing anything in. See `ClipboardPage.tick`.
		# AND REPAINTED ONLY WHEN IT MOVED: the page answers whether the board looks different for it, because this runs
		# every frame the board is up and a render target repainted ninety times a second is what the rosters exist to
		# avoid.
		if _page.tick():
			_redraw()
		return
	_pilots_seen = Sim.pilots
	var seats_of: Callable = Callable()
	if Sim.client != null:
		seats_of = func(vehicle: int) -> PackedInt64Array: return Sim.client.vehicle_seats(vehicle)
	if _page.show_crew(CrewManifest.read(Sim.pilots, Sim.current, Sim.local_client_id(), Callable(), seats_of),
			Sim.join_answer):
		_redraw()


## What is on show, for the tests.
func page() -> ClipboardPage:
	return _page


func panel() -> TouchPanel:
	return _panel

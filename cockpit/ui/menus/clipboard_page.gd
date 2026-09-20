extends Control
class_name ClipboardPage
## WHAT IS ON THE CLIPBOARD: which aircraft, and which person.
##
## Two pages behind two tabs, and it ANNOUNCES rather than acts -- the same rule
## `SessionMenu` and `LevelMenu` follow. Pressing a craft button emits `chose_kind`, pressing
## a row's JOIN emits `chose_join`, and what either of them MEANS is the rig's business,
## because a menu that called into the simulation itself could only ever be used in one
## place.
##
## Everything on the crew page is already replicated, and is HANDED IN: `Clipboard` reads a
## `CrewManifest` off `Sim.pilots` -- every player's vehicle and seat, from the Seats the server
## alone writes -- and hands it to `show_crew` with the answer the server last gave this machine.
## So the page is a LISTING of something the wire already says, and a press is a request the
## server may refuse; the page never seats anybody.

## Pressed one of the craft buttons: go and find me one of those.
signal chose_kind(kind: int)
## Pressed a JOIN on a free seat: put me in that seat of the craft that player is in. `seat` is any seat it has, or -1 for any
## free one.
signal chose_join(client: int, seat: int)
## Pressed LEAVE, twice: take me back to the desk.
signal chose_menu()
## Pressed ADD on a craft: put one more of those in the world, flying itself.
signal chose_traffic(kind: int)
## Set the host's layered aircraft load, or this machine's artificial socket delay.
signal chose_stack(count: int)
## SEND ATTACKERS at the host's own craft: `planes` aeroplanes and `helis` helicopters, or both -1 to call every one of
## them off (lane/combat). Announced; the level decides, and only on the host.
signal chose_attack(planes: int, helis: int)
signal chose_latency(ms: int)
## Flicked SAVE BANDWIDTH on TRAFFIC: the host's far-pose LOD on or off. What it means is `Sim.set_save_bandwidth`'s.
signal chose_save_bandwidth(on: bool)
## Flicked LABELS: write what everything is, or stop.
signal chose_labels(on: bool)
## Flicked FINE SCENERY: draw the world with more in it, or with less.
signal chose_finish(fine: bool)
## Flicked BUTTON LABELS: write what each finger does beside the controller in your hand, or stop.
signal chose_button_labels(on: bool)
## Flicked HUD: the panel on your head that says what you fly, up or away. What it means is the rig's.
signal chose_hud(on: bool)
## Flicked LEVEL HORIZON IN SMALL BOATS. What it means is the rig's: see `PilotRig.level_the_horizon`.
signal chose_level_horizon(on: bool)
## Flicked a control's switch: work that one by turning the wrist rather than by moving it.
signal chose_drive(control_name: String, rotate: bool)
## Flicked BUILD: move the controls about instead of working them.
signal chose_build(on: bool)
## Flicked USE: inside the builder, work the controls rather than move them.
signal chose_try(on: bool)
## Pressed one of the parts: put one of those in the cockpit.
signal chose_part(part: StringName)
## Pressed SAVE: write this cockpit down.
signal chose_save()
signal chose_save_package()
signal chose_load_package()
## Pressed RESET: throw the saved one away.
signal chose_reset()
## Pressed a time: a named point, an hour or ten minutes either way, or the slider let go -- minutes on the clock. What it
## means is the level's, and whose it is the session's.
signal chose_clock(minutes: float)
## Pressed a rate: game seconds a real second. The same.
signal chose_rate(rate: float)
## Flicked CLOUDS: a sky with clouds in it, or a clear one. What it means is the level's, and whose it is the session's.
signal chose_clouds(on: bool)
## Pressed RESET HEAD: put my head back in the seat, as R does on a desk. What it means is the rig's.
signal chose_recentre()
## Flicked GAME SOUND: the engines and the guns, heard or not. What it means is `PilotHeadphones`'.
signal chose_game_sound(on: bool)
## Flicked VOICE: a voice on the radio, loaded or let go of. What it means is `PilotHeadphones`'.
signal chose_voice(on: bool)
signal chose_radio(text: String)
signal chose_music_sound(on: bool)
signal chose_music(track: String)
signal chose_music_stop
signal chose_music_fade(target_db: float, seconds: float)
## SPOTTING SIZE: a strength (`Spectacles.Strength`) and the distance inside which nothing is magnified. See SpottingPage.
signal chose_spotting(strength: int)
signal chose_spotting_near(metres: float)

## The board's colours and sizes are `BoardStyle`'s, so a second board a hand holds up reads the same as this one.
const AMBER := BoardStyle.AMBER
const PALE := BoardStyle.PALE
const DIM := BoardStyle.DIM

## THE TABS, IN ORDER, AND THEIR WORDS: the row is built off `Tab.keys()`, so a tab is added here once.
## LOG since 2026-09-18: "There should be a server log message that explains why a user couldn't connect (we need a
## server log panel in the ipad)." The eleventh tab shares HELP's row, and SPOTTING (2026-09-19) is the twelfth: still four rows of three.
enum Tab { CRAFT, CREW, TRAFFIC, FEEL, BUILD, TIME, AUDIO, MUSIC, MAP, HELP, LOG, SPOTTING }
## HOW MANY TABS TO A ROW of the tab grid. Three keeps every label at hand-target width. See `_ready`.
## FOUR since 2026-09-18 (it was three): "let's make the tab sizes a little smaller (4 across)". Eleven tabs are three
## rows, not four, on a board half as big again, and the row that goes is page height given back.
const TABS_IN_A_ROW: int = 4
## A TAB, A LITTLE SMALLER THAN IT WAS (46 and 22, 2026-09-13 to 2026-09-18): still a beam's target from a seat.
const TAB_TALL: float = 40.0
const TAB_WORDS: int = 19

var _tab: int = Tab.CRAFT
var _tabs: Array[Button] = []
var _craft: Control = null
## THE CRAFT PAGE'S TWO HALVES: the bar of groups and the grid of craft under it, and which group is on show.
var _craft_bar: HFlowContainer = null
## THE LINE OVER THE BAR saying why some craft are not offered here, hidden when nothing is left out (`show_kinds`).
var _craft_note: Label = null
var _craft_grid: HFlowContainer = null
var _craft_group: String = ""
var _traffic: Control = null
var _load_count: Label = null
var _load_readout: Label = null
var _link_count: Label = null
## TRAFFIC's SAVE BANDWIDTH switch and the box that holds it with its line. See `_build_the_traffic_page`.
var _save_bandwidth: CheckButton = null
var _save_bandwidth_box: VBoxContainer = null
var _stack_shown := 0
var _latency_shown := 0
var _feel: VBoxContainer = null
var _scroll: ScrollContainer = null
var _build: Control = null
var _parts: GridContainer = null
var _allowed_parts: Array[StringName] = []
## THE TIME OF DAY: the readout, the named points, the nudges and slider, the rates, and the line that stands in for them
## where a level has no sky. See `show_time`.
var _time_page: Control = null
var _time_buttons: Array[Button] = []
var _nudge_buttons: Array[Button] = []
var _rate_buttons: Array[Button] = []
var _clock_words: Label = null
var _clock_slider: HSlider = null
## Whether a hand is dragging the slider, when the level's clock is not put back on it under the hand.
var _slider_held: bool = false

## THE NUDGES, minutes: an hour and ten minutes either way.
const CLOCK_STEPS: Array[int] = [-60, -10, 10, 60]
## THE RATES, game seconds a real second, and their words: frozen, real time, a minute a second, ten minutes a second, and
## the time-lapse, a day in ten seconds (`Net.CLOCK_RATE_LAPSE`).
const CLOCK_RATES: Array[float] = [0.0, 1.0, 60.0, 600.0, Net.CLOCK_RATE_LAPSE]
const CLOCK_RATE_WORDS: Array[String] = ["FROZEN", "REAL TIME", "60X", "600X", "TIMELAPSE"]
var _no_sky: Label = null
## The `DaylightTuning.When` whose point the level's clock stands on, or -1 at any other time or where there is no sky.
var _time_shown: int = -1
## The clock the level last handed over, minutes, or -1 if it never has (no sky), and the rate.
var _clock_shown: float = -1.0
var _rate_shown: float = 1.0
## THE CLOUDS SWITCH under the three times, and what the level last said of it. See `show_clouds`.
var _clouds: CheckButton = null
var _clouds_shown: bool = true
## WHAT THE PILOT HEARS: two switches and the line under VOICE. See `show_audio`.
var _audio_page: Control = null
var _map_page: MapCanvas = null
var _game_sound: CheckButton = null
var _voice: CheckButton = null
var _voice_said: Label = null
var _radio_column: VBoxContainer = null
var _radio_status: Label = null
var _radio_text: LineEdit = null
var _music_sound: CheckButton = null
## What `PilotHeadphones` last handed over: both off, with nothing to say, until it does.
var _heard: Dictionary = {"game_sound": false, "voice": false, "said": ""}
var _music_page: MusicPage = null
var _spotting_page: SpottingPage = null
## THE LEGEND. Every input and what it does, handed over by the rig from the tables the
## fingers are actually read through -- see `PilotRig.legend`.
var _help: VBoxContainer = null
## What the HELP page was last built from, so it is rebuilt when the BINDINGS change rather
## than every frame. The same reason the crew page keeps a roster: a panel is a render
## target, and one redrawn ninety times a second for a list that changes when a hand closes
## on a lever is the expensive way to show forty lines.
var _legend: String = ""
## THE CONNECTION LOG: `Net.logbook`'s rows, newest first, handed over by the rig (`show_log`). The page draws them and
## decides nothing; it is built only while the tab is up, because a host's door is busy while nobody is reading it.
var _log: VBoxContainer = null
var _log_rows: Array = []
## What the LOG page was last built from, so it is rebuilt when a row arrives rather than on every look.
var _log_drawn: int = -1
var _log_serial: int = 0
## The USE switch on the builder's page, kept because the upper thumb button flips the same
## mode -- and a switch on a page that disagrees with the mode the hands are in is worse
## than no switch. See `show_building`.
var _using: CheckButton = null
## What the FEEL page was last built from, so it is rebuilt when the cockpit CHANGES rather
## than every frame. Same reason the crew page keeps a roster.
## Nothing built yet, which no roster of controls is, so the first `show_controls` builds FEEL even with none: LEVEL
## HORIZON is on it whatever the craft.
var _felt: String = "(not built)"
var _crew: VBoxContainer = null
var _said: Label = null
## HOW THE FIRE JOB IS GOING, on every tab. Hidden until somebody tells it something: a
## level with no fires in it -- the hall, a bench -- has nothing to debrief.
var _debrief: Label = null
## THE CODE A FRIEND TYPES, on every tab. Hidden when this session has none -- solo, over ENet, or at a bench.
## See `_say_the_code`, and the note on it for why it is not on CREW alone any more.
var _code: Label = null
## What the code line last said, so it is written only when it CHANGES: `show_crew` runs every frame the board is up,
## and a Label whose text is assigned dirties the render target whether or not the string differs.
var _code_said: String = ""
## THE SESSION'S NOTICE, on every tab, and what it last said: written only when the words change, as the code line is.
var _notice: Label = null
var _notice_said: String = ""
## MAIN MENU, which arms on the first press and means it on the second. See `GuardedButton`, which keeps the guard and
## its countdown on the frame clock.
var _leave: GuardedButton = null
## The FINE SCENERY switch, kept so the key on the desk can move it. See `show_finish`.
var _fine: CheckButton = null
## The BUTTON LABELS switch, kept so the rig's remembered choice can be shown on it. See `show_button_labels`.
var _button_labels: CheckButton = null
## The HUD switch, kept so the rig's choice can be shown on it. See `show_hud`.
var _hud: CheckButton = null
## LEVEL HORIZON, first on FEEL, and what the rig last said of it: FEEL is rebuilt for every craft, and the switch with it.
var _horizon: CheckButton = null
var _horizon_on: bool = false
## The roster this page was last built from, so it is rebuilt when it CHANGES rather than
## every frame -- a panel is a render target, and one redrawn ninety times a second for a
## list that changes when somebody sits down is the expensive way to show four names.
var _roster: String = ""


## HOW BIG THE WRITING IS: `BoardStyle.TEXT_SCALE`, kept under this name for what already reads it here.
const TEXT_SCALE: float = BoardStyle.TEXT_SCALE


## A font size in the page's own terms, for writing. See `BoardStyle.text`.
static func _sized(pixels: int) -> int:
	return BoardStyle.text(pixels)


## THE TABS WHOSE CONTENT MAY BE TALLER THAN THE BOARD, and why. "Make sure everything fits on the screen" (2026-09-13),
## so a long list is laid out in columns before it is allowed to scroll, and a tab goes on this list only with how far
## over it is and why no layout fitted it. tests/clipboard.gd fails on one that scrolls unlisted.
##
##   HELP. The legend is every finger of both hands and every key on the desk -- 55 rows on a seated rig -- and its whole
##   point is that it is complete: tests/clipboard.gd checks every bound key and finger is on it. At the size the writing
##   has to be to be read in a headset it is 2101 px tall, more than twice the page, at the old control size as well as the
##   new one. Two columns do not fit it either: each row is a name 294 px wide and a sentence, and halving the sentence's
##   room doubles the lines it wraps to. It is a reference you walk with the thumb, not a panel you work.
##
##   FEEL. One switch for every control of the craft the player is in, so its length is the craft's control count, which
##   a saved layout changes: a cockpit a player saved can add controls to any craft. The authored aeroplane fits; the
##   user's own saved plane (2026-09-13, three controls more) made it 839 px in a page of 728 and failed the missiles
##   suite in a full gate while that layout was on the machine. Columns do not fix a list whose length a player sets,
##   they only move where it runs out.
##
##   BUILD, SINCE THE PARTS BIN REACHED TWENTY-TWO (2026-09-16, the director's camera). The bin's length is the number
##   of parts the game has, and that only ever goes up. Twenty-one parts fitted three columns in seven rows; the
##   twenty-second is an eighth row, and the eighth row is 712 px of content.
##
##   WHICH FITS UNTIL SOMEBODY HOSTS DURING A FIRE. The content is 712 px either way -- it is the SCROLLING AREA that
##   moves, 739 px on a quiet board and 655 px with the fire debrief and the Steam join code showing, because those are
##   two lines of furniture that take their height from the page. So BUILD has 27 px spare at a console and is 57 px
##   over on the board a hosting player in a fire actually flies with. Measured quiet it looks fine, and the first
##   person to host during a fire finds it; `tests/clipboard.gd` measures both and that is why.
##
##   Columns are spent. FOUR columns is 244 px a button, and the longest label, "+ PLUNGER THROTTLE", is 320 px at the
##   size the writing has to be to be read in a headset; it would clip or shrink, and a parts bin you cannot read is a
##   parts bin you press by counting. A SHORTER BUTTON was rejected on the page's own terms: the note below says each
##   button "is as tall as it was, so none is a smaller target", and 38 px of reach is what a fingertip in mid-air
##   needs. So the bin walks under the thumb like HELP does, which is what the thumb is already for on every tab.
##
##   CREW, WHEN THERE ARE MORE CREWED CRAFT THAN FIT. A session is at most `Net.MAX_PLAYERS` players, so at most eight
##   crewed craft, and a row is a craft and its four seats. Four rows fit with the Steam code and a refusal showing (459 px
##   in 739, 2026-09-15); eight do not, and ten -- which only a test's server-seated players make -- are two pages. Rows are
##   nearest first after your own (`CrewManifest.read`), so the ones in sight are on show, and the thumb on the beam's hand
##   scrolls to the rest. Pages or "N more" were rejected: a craft the page cannot reach is a friend you cannot join.
##
##   LOG. The connection log keeps its last two hundred rows (`Logbook.MOST`), newest first, and a row is two lines:
##   what happened and the words. Eight of them fill the page. It is a record read from the top, where the news is,
##   and the thumb walks down to what came before, as it does on HELP. `LOG_DRAWN` caps what is built.
##
##   CRAFT, WHEN ONE GROUP HAS MORE KINDS THAN FIT. The page shows one group at a time (`show_kinds`), so sixty kinds are
##   four pages of fifteen; but nothing stops a game having thirty aeroplanes, and a craft the page cannot reach is a
##   craft that is not in the game. So a group taller than the page scrolls under the thumb like every list here
##   (lane/kinds, 2026-09-18). tests/craft_page.gd measures how many fit before it does.
const MAY_SCROLL: Array[int] = [Tab.HELP, Tab.FEEL, Tab.BUILD, Tab.CREW, Tab.AUDIO, Tab.MUSIC, Tab.MAP, Tab.CRAFT,
	Tab.LOG, Tab.SPOTTING]
## THE MOST ROWS THE LOG PAGE BUILDS: sixty is an evening's door and three hundred controls on a render target, where
## all two hundred would be six hundred rebuilt at every knock. The line under the tabs says how many more there are.
const LOG_DRAWN: int = 60


func _ready() -> void:
	# EVERY SWITCH ON THIS BOARD WEARS BoardStyle'S, set here once and on no control. See `BoardStyle.theme`.
	theme = BoardStyle.theme()
	var back := ColorRect.new()
	back.color = BoardStyle.BOARD
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 18.0
	column.offset_top = 14.0
	column.offset_right = -18.0
	column.offset_bottom = -14.0
	# GAPS OF 6 px between the board's rows, not 10: RESET HEAD's row of its own (2026-09-13) had to come out of the
	# scrolling page's height, and six gaps at 4 px less each are 24 px of it.
	column.add_theme_constant_override("separation", 6)
	add_child(column)

	# THE TABS IN A GRID (four across since 2026-09-18, on a board half as big again; see TABS_IN_A_ROW). Before that, TWO ROWS OF FOUR. "Make sure that the top tabs on the iPad are wrapped correctly" (2026-09-13), with
	# AUDIO the eighth: one row of eight at this size wants 1013 px inside a page 988 px wide, and a row that wide
	# widens the whole column and cuts its right-hand tabs off the glass -- which is what the old single row did to
	# everything on every tab at seven tabs and x1.4 (1066 px, 2026-09-13). Two rows of four give each tab 241 px
	# rather than 134, a bigger target for a beam from a seat, with no word shortened or made smaller.
	# A GRID, NOT A FLOW. An `HFlowContainer` wraps where the words run out, so its rows would be five and three or four
	# and four depending on the font; a grid of four puts the same tabs in the same place whatever the words measure.
	# A ninth tab is a third row, and that row's height has to come from somewhere: see the height budget in agents.md.
	var tab_rows := GridContainer.new()
	tab_rows.columns = TABS_IN_A_ROW
	tab_rows.add_theme_constant_override("h_separation", 8)
	tab_rows.add_theme_constant_override("v_separation", 4)
	column.add_child(tab_rows)
	for name in Tab.keys():
		var tab := Button.new()
		tab.text = String(name)
		tab.toggle_mode = true
		# AS TALL AS MAIN MENU AND WORDED AS BIG as they were in one row: what the second row costs came out of
		# BUILD's parts bin, three columns now, and out of nothing you press.
		tab.custom_minimum_size = Vector2(0.0, BoardStyle.reach(TAB_TALL))
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", BoardStyle.pressed_text(TAB_WORDS))
		var which: int = _tabs.size()
		tab.pressed.connect(func(): show_tab(which))
		tab_rows.add_child(tab)
		_tabs.append(tab)

	# THE PAGES SCROLL, AND THE FURNITURE AROUND THEM DOES NOT.
	#
	# The tabs at the top and the way out at the bottom stay where they are -- a way out
	# that scrolls off the screen is a way out somebody cannot find -- and only the page
	# between them moves. That is the shape every hand-held list has, for the reason that
	# the two things you always want are the one you can always see.
	#
	# WITH NO SCROLL BAR. A bar is something you drag, and dragging a two-millimetre-wide
	# strip with a fingertip in a headset is not something anybody manages. It is worked
	# with the thumb buttons instead -- see `ClipboardPage.bindings` -- which is the
	# input a hand holding the board already has spare.
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	# AND IT FOLLOWS THE HIGHLIGHT, so walking it down the page with the stick brings each
	# control into view rather than wandering off the bottom of the board.
	_scroll.follow_focus = true
	column.add_child(_scroll)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.add_theme_constant_override("separation", 10)
	_scroll.add_child(pages)

	_craft = _build_the_craft_page()
	pages.add_child(_craft)
	_crew = VBoxContainer.new()
	_crew.add_theme_constant_override("separation", 6)
	pages.add_child(_crew)
	_traffic = _build_the_traffic_page()
	pages.add_child(_traffic)
	_feel = VBoxContainer.new()
	_feel.add_theme_constant_override("separation", 2)
	pages.add_child(_feel)
	show_controls([])
	_build = _build_the_builders_page()
	pages.add_child(_build)
	_time_page = _build_the_time_page()
	pages.add_child(_time_page)
	_audio_page = _build_the_audio_page()
	pages.add_child(_audio_page)
	_music_page = MusicPage.new()
	_music_page.chose_track.connect(func(id: String): chose_music.emit(id))
	_music_page.chose_stop.connect(func(): chose_music_stop.emit())
	_music_page.chose_fade.connect(func(db: float, seconds: float): chose_music_fade.emit(db, seconds))
	pages.add_child(_music_page)
	_map_page = (load("res://ui/menus/map_canvas.tscn") as PackedScene).instantiate() as MapCanvas
	# The tenth tab adds a fourth tab row. Keep the chart legible and let the
	# shared scroll surface move it past session furniture when all of that is up.
	_map_page.custom_minimum_size = Vector2(0.0, BoardStyle.reach(280.0))
	pages.add_child(_map_page)
	_help = VBoxContainer.new()
	_help.add_theme_constant_override("separation", 2)
	pages.add_child(_help)
	_log = VBoxContainer.new()
	_log.add_theme_constant_override("separation", 6)
	pages.add_child(_log)
	# SPOTTING SIZE, a page of its own file: see SpottingPage. It announces; the rig keeps the setting.
	_spotting_page = SpottingPage.new()
	_spotting_page.chose_strength.connect(func(strength: int): chose_spotting.emit(strength))
	_spotting_page.chose_near.connect(func(metres: float): chose_spotting_near.emit(metres))
	pages.add_child(_spotting_page)

	# THE JOIN CODE, ABOVE THE DEBRIEF AND ON EVERY TAB.
	#
	# Asked for on 2026-09-15: "make sure the multiplayer steam code is shown somewhere on the ipad or on the hud."
	# It WAS on the board -- at the head of the CREW list since 2026-09-14 -- and CREW is the sixth of eight tabs and
	# not the one the board opens on. A host reading a code out to a friend on a voice channel is a host who has to find
	# it first, and a code you have to go and look for is the same bug the debrief's note names one line below.
	# So it is furniture now, like the debrief: on whatever tab is up, off the scrolling page, and out of CREW's body so
	# that it is not said twice on the one tab that used to own it.
	# THE SESSION'S NOTICE, ABOVE THE CODE AND ON EVERY TAB (plan item 13): the level about to change, who joined, who left.
	# Furniture for the reason the code is -- news you have to go and find is news that arrives after the thing it warned
	# of -- and hidden when there is none, so a quiet board pays no height for it. `Net` writes the words; see `_say_the_notice`.
	_notice = Label.new()
	_notice.name = "SessionNotice"
	_notice.add_theme_font_size_override("font_size", _sized(21))
	_notice.add_theme_color_override("font_color", AMBER)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.visible = false
	column.add_child(_notice)

	_code = Label.new()
	_code.name = "SessionCode"
	_code.add_theme_font_size_override("font_size", _sized(19))
	_code.add_theme_color_override("font_color", AMBER)
	_code.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_code.visible = false
	column.add_child(_code)

	# THE DEBRIEF, ABOVE THE ANSWER LINE AND ON EVERY TAB.
	#
	# The one thing on this board that is about the SESSION rather than about the page: how
	# the fire job is going, which is the only thing in this game that can be won or lost.
	# It is furniture like the tabs and the way out, so it does not scroll away -- a score
	# you have to go and find is a score nobody looks at.
	_debrief = Label.new()
	_debrief.add_theme_font_size_override("font_size", _sized(18))
	_debrief.add_theme_color_override("font_color", AMBER)
	_debrief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_debrief.visible = false
	column.add_child(_debrief)

	_said = Label.new()
	_said.add_theme_font_size_override("font_size", _sized(17))
	_said.add_theme_color_override("font_color", DIM)
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_said)

	# LABELS, ABOVE THE WAY OUT AND ON EVERY TAB.
	#
	# A cockpit is twelve controls that all look like levers, and which one is the gear is
	# not something a shape can say. So they can be named, and it is a SWITCH rather than a
	# page: you want it on while you are learning an aircraft and off for ever afterwards,
	# and something you have to go and find on a tab is something you leave on.
	#
	# NOT REPLICATED. What one player has chosen to have written on their own cockpit is
	# nobody else's business, and a copilot who could turn your labels off would be a bug
	# with a very confusing report attached.
	var labels := CheckButton.new()
	labels.text = "LABELS"
	labels.add_theme_font_size_override("font_size", BoardStyle.pressed_text(18))
	labels.custom_minimum_size = Vector2(0.0, BoardStyle.reach(36.0))
	labels.toggled.connect(func(on: bool): chose_labels.emit(on))
	# THE THREE SWITCHES SHARE ONE ROW. Stacked, at the bigger size (2026-09-13), they were three rows of furniture on
	# every tab, and every tab's page lost their height: BUILD's content was 1595 px in a 770 px scrolling area.
	# RESET HEAD, IN A ROW OF ITS OWN ABOVE THE SWITCHES, ON EVERY TAB. Asked for on 2026-09-13: "a ipad command for
	# resetting the head position like the 'r' key on the keyboard". You reach for it when your head is wrong, whatever
	# page is up, so it is furniture; and it is a press, not a switch. It announces, and `PilotRig.recentre` -- what R
	# already calls -- answers it.
	#
	# ITS OWN ROW, as big as MAIN MENU. It was first put beside the three switches, and four in that row jammed BUTTON
	# LABELS' toggle into its word and spaced the row unevenly -- and it mixed kinds, three switches and an action, which
	# is the row the note on MAIN MENU below warns against. Beside MAIN MENU was rejected for the same reason, and worse:
	# a beam that slips off RESET HEAD would land on an exit that arms.
	var reset := Button.new()
	reset.text = "RESET HEAD"
	# reach(42), not MAIN MENU's 46: a row of its own cost BUILD's page its fit, 855 px of content in 825 (2026-09-13),
	# and this row a little shorter, the column's gaps at 6 and BUILD's SAVE/RESET row at 38 buy it back with room over.
	reset.custom_minimum_size = Vector2(0.0, BoardStyle.reach(42.0))
	reset.add_theme_font_size_override("font_size", BoardStyle.pressed_text(20))
	reset.pressed.connect(func(): chose_recentre.emit())
	column.add_child(reset)

	# THE SWITCHES IN TWO ROWS OF TWO: LABELS and FINE SCENERY, then BUTTON LABELS and HUD. A fourth switch in the row of
	# three had no width -- BUTTON LABELS already asked 318 of its 324 px (2026-09-14) -- and a grid puts each switch in the
	# same place whatever its words measure, as the tabs' grid does. The second row is one `reach(36)` row and a 4 px gap.
	var settings := GridContainer.new()
	settings.columns = 2
	settings.add_theme_constant_override("h_separation", 8)
	settings.add_theme_constant_override("v_separation", 4)
	column.add_child(settings)
	# EACH SWITCH IN THE MIDDLE OF ITS HALF, AS WIDE AS ITS WORDS AND ITS PILL, and not filling the half. A CheckButton
	# draws its pill against its right-hand edge, so a switch stretched across its share put LABELS' pill 20 px from the
	# words FINE SCENERY and 152 px from its own (2026-09-14), which reads as the wrong switch. EXPAND keeps the columns'
	# shares equal; SHRINK_CENTER sits the switch in the middle of its share. BUILD and USE CONTROLS do the same.
	labels.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	settings.add_child(labels)

	# FINE SCENERY, BESIDE LABELS AND ON EVERY TAB.
	#
	# The one control in a headset that makes the world cheaper to draw, and it has to be
	# somewhere a player finds while the frame rate is bad -- not three tabs down. It says
	# what it is rather than "QUALITY", because what it changes is the sea and the smoke and
	# the clouds, and a player deciding whether to give those up should know that is the
	# trade. It announces; see `Finish` for who decides.
	_fine = CheckButton.new()
	_fine.text = "FINE SCENERY"
	_fine.add_theme_font_size_override("font_size", BoardStyle.pressed_text(18))
	_fine.custom_minimum_size = Vector2(0.0, BoardStyle.reach(36.0))
	_fine.toggled.connect(func(on: bool): chose_finish.emit(on))
	_fine.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	settings.add_child(_fine)

	# BUTTON LABELS, BESIDE LABELS AND ON EVERY TAB. Asked for on 2026-09-13: "labels so I can tell what buttons do what
	# when I grab a device... a setting we turn on and off on the iPad". NOT the LABELS switch above, which writes each
	# cockpit control's NAME on the control; this writes what each FINGER does, beside the controller in your hand (see
	# `ControllerModel`). ON unless somebody turns it off -- a player who has not found the switch is the one who most
	# needs the labels. Yours alone, like LABELS: never sent, never anybody else's business.
	_button_labels = CheckButton.new()
	_button_labels.text = "BUTTON LABELS"
	_button_labels.button_pressed = true
	_button_labels.add_theme_font_size_override("font_size", BoardStyle.pressed_text(18))
	_button_labels.custom_minimum_size = Vector2(0.0, BoardStyle.reach(36.0))
	_button_labels.toggled.connect(func(on: bool): chose_button_labels.emit(on))
	_button_labels.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	settings.add_child(_button_labels)

	# HUD, BESIDE BUTTON LABELS AND ON EVERY TAB. Asked for on 2026-09-14: "turn off the hud that shows up connected to
	# the head (we need a toggle in the ipad to turn it back on)". OFF, as the rig starts it; the rig decides and hands
	# the answer back through `show_hud`. Yours alone, like the other three.
	_hud = CheckButton.new()
	_hud.text = "HUD"
	_hud.add_theme_font_size_override("font_size", BoardStyle.pressed_text(18))
	_hud.custom_minimum_size = Vector2(0.0, BoardStyle.reach(36.0))
	_hud.toggled.connect(func(on: bool): chose_hud.emit(on))
	_hud.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	settings.add_child(_hud)

	# THE WAY OUT, at the bottom and on its own.
	#
	# Every level was a one-way door until now: you could reach the world, the hall and both
	# marshalling levels from the desk, and the only way back was to quit the program --
	# which in a headset means taking it off. The clipboard is the one piece of furniture
	# that follows the player into every one of them, so this is where the door goes.
	#
	# AT THE BOTTOM, past a spacer, and not up beside the tabs. The tabs change what you are
	# looking at and this ends the session; a row where the third button does something of a
	# different KIND is a row somebody presses by accident.
	_leave = GuardedButton.new("MAIN MENU", "PRESS AGAIN TO LEAVE")
	_leave.custom_minimum_size = Vector2(0.0, BoardStyle.reach(46.0))
	_leave.add_theme_font_size_override("font_size", BoardStyle.pressed_text(20))
	_leave.meant.connect(func(): chose_menu.emit())
	column.add_child(_leave)

	show_tab(Tab.CRAFT)
	refresh()


## ---- the way out ---------------------------------------------------------------------

## TWICE, BECAUSE ONCE IS AN ACCIDENT.
##
## This throws away the session, and the thing pressing it is a fingertip waved at a panel on
## the end of the player's own arm -- which is a good deal easier to brush against than a
## mouse is to misclick. So the first press only arms it, the label says so, and a few
## seconds of not meaning it puts the board back the way it was.
##
## THE GUARD IS A `GuardedButton`, since 2026-09-14: this page had it as its own members and functions until the desk's
## QUIT wanted exactly the same one. The time is the guard's, and asked for here so everything that reads it here still
## does.
const MEANT_IT: float = GuardedButton.MEANT_IT


## Whether the way out is waiting to be confirmed, for the tests.
func leaving() -> bool:
	return _leave != null and _leave.is_armed()


## WHAT THE FINISH IS, handed in. `set_pressed_no_signal`, or showing the key's choice here
## would announce it again as though somebody had flicked the switch.
func show_finish(fine: bool) -> void:
	if _fine != null:
		_fine.set_pressed_no_signal(fine)


## WHETHER THE BUTTON LABELS ARE ON, handed in from the rig that remembers it, without announcing it again.
func show_button_labels(on: bool) -> void:
	if _button_labels != null:
		_button_labels.set_pressed_no_signal(on)


## WHETHER THE HUD IS UP, handed in from the rig that decides it, without announcing it again.
func show_hud(on: bool) -> void:
	if _hud != null:
		_hud.set_pressed_no_signal(on)


## WHETHER THE RIG KEEPS THE HORIZON LEVEL IN SMALL BOATS, handed in from the rig without announcing it again.
func show_level_horizon(on: bool) -> void:
	_horizon_on = on
	if _horizon != null and is_instance_valid(_horizon):
		_horizon.set_pressed_no_signal(on)


## ---- which tab ----------------------------------------------------------------------

func show_tab(which: int) -> void:
	_tab = which
	if _said != null:
		_said.add_theme_color_override("font_color", DIM)
	for i in range(_tabs.size()):
		_tabs[i].button_pressed = i == which
	_craft.visible = which == Tab.CRAFT
	_crew.visible = which == Tab.CREW
	_traffic.visible = which == Tab.TRAFFIC
	# Asked again here and not only when built: a board is built before its machine hosts or joins.
	if _save_bandwidth_box != null:
		_save_bandwidth_box.visible = Sim.decides_what_is_sent()
	_feel.visible = which == Tab.FEEL
	_build.visible = which == Tab.BUILD
	_time_page.visible = which == Tab.TIME
	_audio_page.visible = which == Tab.AUDIO
	_music_page.visible = which == Tab.MUSIC
	_map_page.visible = which == Tab.MAP
	_help.visible = which == Tab.HELP
	_log.visible = which == Tab.LOG
	_spotting_page.visible = which == Tab.SPOTTING
	# AND A NEW TAB STARTS AT THE TOP. Arriving on a page already scrolled halfway down is
	# arriving on a page that looks like it is missing its first three rows.
	if _scroll != null:
		_scroll.scroll_vertical = 0
	match which:
		Tab.AUDIO:
			# BOTH START OFF, EVERY TIME, and this is where somebody finds out why it is quiet. ONE LINE, like BUILD's.
			_said.text = "Both start off every time. VOICE takes a few seconds to load."
		Tab.MUSIC:
			_said.text = "Tracks are .ogg files in the music folder beside the game."
		Tab.TIME:
			# WHOSE SKY IT IS, said where somebody is about to change it (plan item 17): the host's, and everybody's. Until
			# 2026-09-16 this said "Nobody else's sky changes", which was true and was the bug.
			_said.text = time_words()
		Tab.MAP:
			_said.text = "Tap a crew marker to draw a line and distance from you."
		Tab.LOG:
			_draw_the_log()
			_said.text = log_words()
		Tab.SPOTTING:
			_said.text = "Yours alone, and kept for next time."
		Tab.CRAFT:
			_said.text = "Press a craft and you will be put in one of them."
		Tab.CREW:
			# THE INSTRUCTION, ALWAYS, on this tab: the host's answer stands at the head of the list, and the same words
			# twice on one page read as a mistake (team-lead, 2026-09-15, crew_shot_refused.png).
			_said.text = JOIN_HINT
		Tab.BUILD:
			# THE ONE PAGE THAT CHANGES WHAT A GRAB MEANS, so it says so before anybody
			# wonders why the throttle has stopped working.
			# ONE LINE, NOT TWO. It wrapped to two, and on BUILD, the fullest page on the board, the second line was 37 px
			# the page did not have once RESET HEAD had a row of its own (2026-09-13: 848 px of parts in 852).
			_said.text = "BUILD moves the controls. Lower thumb bins what you hold."
		Tab.HELP:
			# WHAT THE THUMB DOES DEPENDS ON WHAT THE HAND IS HOLDING, which is the whole
			# design of the bindings and the reason this page cannot be a fixed picture.
			_said.text = "What each finger does, in the hand you have now. " \
				+ "Take hold of something and it changes."
		Tab.FEEL:
			# THE ONE SETTING THE GAME SHOULD NOT BE CONFIDENT ABOUT. Pushing a stick is
			# what the thing in front of you looks like it should do; turning a wrist is
			# what an arm can keep doing for an hour. Which is better depends on the
			# aircraft, the control, the length of the flight and whose arm it is.
			_said.text = "PUSH moves a control with your hand. TURN works it " \
				+ "with your wrist, so your arm can rest."
		_:
			# WHY THE SKY STARTS QUIET, said where somebody is about to make it loud. The
			# wire fits about fifty-two machines a tick and shares them out evenly, so every
			# one you add takes a little freshness from all the others -- see Terrain's note
			# and the crowd measurements in agents.md.
			_said.text = "Adds one more, flying itself. About fifty machines fit " \
				+ "before they start to jitter."
	_roster = ""
	refresh()


## The level picture and moving crew markers are handed in. The page has no
## network or simulation dependency of its own.
func show_map(map: LevelMap, markers: Array[Dictionary]) -> void:
	if _map_page != null:
		_map_page.show_map(map, markers)


func map_page() -> MapCanvas:
	return _map_page


## AN ANSWER TO WHAT WAS JUST PRESSED, in the line that already explains this tab.
##
## The page announces and does not act, so it never learns what became of a press unless
## somebody tells it. Adding traffic is the first button here that can be REFUSED -- only
## the host may spawn -- and a button that silently does nothing is the worst kind.
##
## It is wiped by `show_tab`, which is right: the answer is about the press, not the page.
func say(what: String) -> void:
	if _said != null:
		_said.text = what


## A NO, IN THE LINE UNDER THE TABS, amber as every refusal on this board is: for whoever refused what the page announced.
func say_no(what: String) -> void:
	_say_answer(what)


## What the line under the tabs says now, for the tests and a harness.
func said_text() -> String:
	return _said.text if _said != null else ""


## HOW THE JOB IS GOING, handed over by the level.
##
## The board does not know what a fire is, exactly as it does not know what a cockpit or a
## binding is. `FlightLevel` owns the `FireFront` and writes the sentence; this draws it.
## An empty string hides the line rather than leaving a blank one, because a level with no
## fires in it should not have a gap where a score would be.
func show_debrief(text: String) -> void:
	if _debrief == null:
		return
	_debrief.text = text
	_debrief.visible = not text.is_empty()


## What the debrief line reads, for the tests.
func debrief_text() -> String:
	return _debrief.text if _debrief != null else ""


## Which tab is on show, for the tests and for anybody asking.
func tab() -> int:
	return _tab


## ---- the craft page -------------------------------------------------------------------

## EVERY KIND, as a wrapped row of small buttons rather than a dropdown -- a popup opens a
## real window when the page is a SubViewport, which in a headset is a window you can
## neither see nor dismiss. The same reason `LevelMenu` does it this way.
##
## IN GROUPS, ONE ON SHOW (lane/kinds, 2026-09-18: "i'd like to have lots of vehicle kinds"). A bar of groups --
## aeroplanes, helicopters, ships, ground, by how each kind moves (`VehicleCatalogue.group`) -- and under it the craft
## of the one pressed. Twenty-eight kinds in one grid filled most of the board, and sixty would not have fitted. The
## other groups' buttons stay on the page, hidden, so every craft is still one press away and a test can still find
## every one. Rejected: pages of N with NEXT, which lose the one thing a player knows ("a helicopter"); and one long
## scrolling list, which puts the forty-fifth craft a minute of thumbing away.
func _build_the_craft_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	_craft_note = Label.new()
	_craft_note.add_theme_font_size_override("font_size", BoardStyle.pressed_text(16))
	_craft_note.visible = false
	page.add_child(_craft_note)
	_craft_bar = HFlowContainer.new()
	_craft_bar.add_theme_constant_override("h_separation", 6)
	_craft_bar.add_theme_constant_override("v_separation", 6)
	page.add_child(_craft_bar)
	_craft_grid = HFlowContainer.new()
	_craft_grid.add_theme_constant_override("h_separation", 6)
	_craft_grid.add_theme_constant_override("v_separation", 6)
	page.add_child(_craft_grid)
	# ONLY WHAT A PLAYER MAY BE PUT IN. A button for the pirate ship would be a press the host
	# refuses every time -- see `VehicleCatalogue.pilotable`.
	show_kinds(VehicleCatalogue.craft_rows())
	return page


## THE CRAFT TO OFFER, handed in: `{kind, name, group}` each, as `VehicleCatalogue.craft_rows` makes them. The bar gets a
## button for every group that has a craft in it, in `VehicleCatalogue.GROUPS` order, and the group on show stays on
## show if it still has craft, or else the first does. A page is handed its data and draws it. `note` is the one line
## over the bar that says why a group is missing on this level ("" hides it); the level hands both.
func show_kinds(rows: Array, note: String = "") -> void:
	if _craft_note != null:
		_craft_note.text = note
		_craft_note.visible = note != ""
	for child in _craft_bar.get_children() + _craft_grid.get_children():
		child.queue_free()
		(child as Node).get_parent().remove_child(child)
	var groups: Array[String] = []
	for group in VehicleCatalogue.GROUPS:
		if rows.any(func(row: Dictionary) -> bool: return String(row["group"]) == group):
			groups.append(group)
	for row in rows:
		if not groups.has(String(row["group"])):
			groups.append(String(row["group"]))
	for group in groups:
		var tab := Button.new()
		tab.text = group.to_upper()
		tab.toggle_mode = true
		tab.custom_minimum_size = Vector2(0.0, BoardStyle.reach(40.0))
		tab.add_theme_font_size_override("font_size", BoardStyle.pressed_text(18))
		tab.set_meta("group", group)
		var chosen_group: String = group
		tab.pressed.connect(func(): show_craft_group(chosen_group))
		_craft_bar.add_child(tab)
	for row in rows:
		var pick := Button.new()
		pick.text = String(row["name"])
		pick.custom_minimum_size = Vector2(0.0, BoardStyle.reach(40.0))
		pick.add_theme_font_size_override("font_size", BoardStyle.pressed_text(18))
		pick.set_meta("group", String(row["group"]))
		var chosen: int = int(row["kind"])
		pick.pressed.connect(func(): chose_kind.emit(chosen))
		_craft_grid.add_child(pick)
	show_craft_group(_craft_group if groups.has(_craft_group) else (groups[0] if not groups.is_empty() else ""))


## SHOW ONE GROUP'S CRAFT, and light its button in the bar. The page goes back to its top, as a new tab does.
func show_craft_group(group: String) -> void:
	_craft_group = group
	for tab in _craft_bar.get_children():
		(tab as Button).set_pressed_no_signal(String(tab.get_meta("group")) == group)
	for pick in _craft_grid.get_children():
		(pick as Control).visible = String(pick.get_meta("group")) == group
	if _scroll != null:
		_scroll.scroll_vertical = 0


## Which group of craft is on show, for the tests.
func craft_group() -> String:
	return _craft_group


## ---- up and down the page --------------------------------------------------------------

## HALF A PAGE PER PRESS.
##
## Half rather than a whole, so the row you were reading is still on the screen after the
## jump: a list that pages cleanly is one where you lose your place at every press. And a
## fixed fraction rather than a fixed number of pixels, because the board is one size in the
## hand and another on a monitor.
##
## `by` is +1 for further down the page and -1 for back up it.
func scroll(by: int) -> void:
	if _scroll == null:
		return
	_scroll.scroll_vertical += int(round(float(by) * _scroll.size.y * 0.5))


## How far down the page it is, for the tests.
func scrolled() -> int:
	return _scroll.scroll_vertical if _scroll != null else 0


## ---- the board's own fingers ------------------------------------------------------------

## THE HAND HOLDING THE BOARD. It is on the left controller -- see `Clipboard` -- so the right
## hand is the one free to work it.
const HOLDING_HAND: int = 0


## WHAT THE FINGERS DO WHILE THE BOARD IS UP, the same kind of table a control hands over.
##
## A lever says what the rest of the hand does while it is being held -- see `Bind` -- and a
## board being read is the thing a player is working, so it says the same. `PilotRig` lays
## this over everything else while the board is up and forgets it the moment the board goes
## away, which is the whole of how the fingers get back to flying.
##
## BOTH THUMBS SCROLL, on either hand, because which hand is free depends on what is being
## flown -- that is what they did before there was any more to it.
##
## THE FREE HAND ALSO NAVIGATES: its mini joystick walks a highlight through the page and turns
## the tabs, its trigger presses what is highlighted, and clicking the stick turns to the next
## tab. So the board can be worked without reaching over to it at all.
##
## AND THE HAND HOLDING IT STILL FLIES. Its stick is the control column and its trigger the
## brake, and a board that took those away would be a board that made the aeroplane stop
## answering whenever somebody looked at a menu. Nothing here names them, so they fall through.
func bindings(hand: int) -> Dictionary:
	var table: Dictionary = {
		Bind.THUMB_HIGH: Bind.local(Bind.Local.SCROLL_UP),
		Bind.THUMB_LOW: Bind.local(Bind.Local.SCROLL_DOWN),
	}
	if hand != HOLDING_HAND:
		table[Bind.STICK] = Bind.local(Bind.Local.NAVIGATE)
		table[Bind.TRIGGER] = Bind.local(Bind.Local.PRESS_HIGHLIGHTED)
		table[Bind.STICK_CLICK] = Bind.local(Bind.Local.TAB_NEXT)
	return table


## A FLICK OF THE STICK, whichever way it went. The larger of the two axes decides, so a stick
## pushed a little off straight still means the direction it was mostly pushed in.
##
## UP IS UP THE PAGE: a thumbstick reports +y pushed forward, which is towards the top of the
## controller and so towards the top of the list.
func navigate(towards: Vector2) -> void:
	if absf(towards.x) > absf(towards.y):
		next_tab(1 if towards.x > 0.0 else -1)
	elif towards.y != 0.0:
		move_highlight(-1 if towards.y > 0.0 else 1)


## THE TAB BESIDE THIS ONE, wrapping at both ends. Through `show_tab`, which is what pressing
## the tab itself does, so the page cannot end up half on one tab and half on another.
func next_tab(by: int) -> void:
	show_tab(posmod(_tab + by, Tab.size()))
	var tab_button: Button = _tabs[_tab] if _tab < _tabs.size() else null
	if tab_button != null:
		tab_button.grab_focus()


## WALK THE HIGHLIGHT, one control at a time, through everything on the page that could take a
## press. Godot's own focus does the walking, so what counts as next is what a keyboard or a
## gamepad would give -- and the scroll follows it, so the highlight is never off the board.
##
## NOTHING HIGHLIGHTED YET, or something on a tab that is no longer on show, starts at the top
## of the page that is.
func move_highlight(by: int) -> void:
	var now: Control = highlighted()
	var next: Control = null
	if now == null:
		next = _first_to_press(_page_on_show())
	else:
		next = now.find_next_valid_focus() if by > 0 else now.find_prev_valid_focus()
	if next != null:
		next.grab_focus()


## PRESS WHAT IS HIGHLIGHTED, as `ui_accept` -- the event a keyboard's Enter and a gamepad's
## A send -- pushed into the page's own viewport and let go again. The button decides what a
## press means: a tab turns the page, a switch flips, a craft button asks for a craft. Nothing
## here knows which it is, which is the point.
func press_highlighted() -> bool:
	if highlighted() == null:
		return false
	for down in [true, false]:
		var accept := InputEventAction.new()
		accept.action = &"ui_accept"
		accept.pressed = down
		get_viewport().push_input(accept)
	return true


## What is highlighted, or null -- including when the thing that had it has since gone out of
## sight, which a highlight left on a hidden tab would otherwise press.
func highlighted() -> Control:
	var viewport: Viewport = get_viewport()
	var focused: Control = viewport.gui_get_focus_owner() if viewport != null else null
	return focused if focused != null and focused.is_visible_in_tree() else null


func _page_on_show() -> Control:
	for page in [_craft, _crew, _traffic, _feel, _build, _time_page, _audio_page, _music_page, _map_page, _help, _log,
			_spotting_page]:
		if page != null and (page as Control).visible:
			return page
	return self


## ---- the time of day ----------------------------------------------------------------------

## THE TIME TAB: THE CLOCK, AND ANY TIME ON IT (2026-09-18). "Execute the ability to change the time to arbitrary times of
## day from the ipad (not just the three we have now)". Top to bottom: the readout -- the clock, what the sky is by an
## almanac's words (`DaylightTuning.sky_words`) and how fast it runs; the five named points on the clock (`Orrery.Point`,
## DAWN, DAY, EVENING, DUSK, NIGHT); an hour and ten minutes either way, with a slider across the day between them; the
## rates, FROZEN, REAL TIME, 60X, 600X and TIMELAPSE (a day in ten seconds); and CLOUDS.
##
## THE HIGHLIGHT IS THE LEVEL'S. Every press announces `chose_clock` or `chose_rate` and then puts the buttons back to what
## the level last said -- a toggle button presses itself, and a highlight that moved on the press would be the page's guess
## about a decision that is not its to make. The level answers with `show_time` and `show_rate`, which is what moves it,
## and the slider is put back to the clock on every one unless a hand is dragging it. The slider announces when it is let
## go, not on every step of a drag, which would be a sky said to every peer thirty times a second.
##
## NO SKY, NO BUTTONS. The hall and the marshalling levels hand the board no time of day, and buttons that do nothing
## there would be the dead switch this project has a rule about.
func _build_the_time_page() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	# THE READOUT: the clock, what the sky is doing by an almanac's words, and how fast the clock runs.
	_clock_words = Label.new()
	_clock_words.name = "ClockWords"
	_clock_words.add_theme_font_size_override("font_size", _sized(24))
	_clock_words.add_theme_color_override("font_color", PALE)
	column.add_child(_clock_words)
	# THE FIVE NAMED POINTS, in the clock's order: the three presets and the two twilights.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	for name in Orrery.Point.keys():
		var pick: Button = _time_button(String(name), 58.0, 20)
		var minutes: float = Orrery.point(Orrery.point_named(String(name)))
		pick.pressed.connect(func():
			chose_clock.emit(minutes)
			_mark_the_time())
		row.add_child(pick)
		_time_buttons.append(pick)
	# ANY TIME: an hour or ten minutes either way, and a slider across the day. The buttons are what a beam or a robot
	# presses exactly; the slider is for the big moves, and announces when it is let go, not on every step of the drag.
	var nudge := HBoxContainer.new()
	nudge.add_theme_constant_override("separation", 8)
	column.add_child(nudge)
	for step in CLOCK_STEPS:
		var by: float = float(step)
		var press: Button = _time_button(("+" if by > 0.0 else "-") + ("%dH" % int(absf(by) / 60.0) if absf(by) >= 60.0
			else "%dM" % int(absf(by))), 52.0, 20)
		press.toggle_mode = false
		press.pressed.connect(func():
			if _clock_shown >= 0.0:
				chose_clock.emit(fposmod(_clock_shown + by, Orrery.DAY_LONG)))
		if by > 0.0 and nudge.get_child_count() == 2:
			_clock_slider = HSlider.new()
			_clock_slider.name = "ClockSlider"
			_clock_slider.min_value = 0.0
			_clock_slider.max_value = Orrery.DAY_LONG - 5.0
			_clock_slider.step = 5.0
			_clock_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_clock_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_clock_slider.custom_minimum_size = Vector2(0.0, BoardStyle.reach(40.0))
			_clock_slider.drag_started.connect(func(): _slider_held = true)
			_clock_slider.drag_ended.connect(func(changed: bool):
				_slider_held = false
				if changed:
					chose_clock.emit(_clock_slider.value))
			nudge.add_child(_clock_slider)
		nudge.add_child(press)
		_nudge_buttons.append(press)
	# HOW FAST IT RUNS.
	var rates := HBoxContainer.new()
	rates.add_theme_constant_override("separation", 8)
	column.add_child(rates)
	for i in range(CLOCK_RATES.size()):
		var rate: float = CLOCK_RATES[i]
		var pick: Button = _time_button(CLOCK_RATE_WORDS[i], 52.0, 20)
		pick.pressed.connect(func():
			chose_rate.emit(rate)
			_mark_the_time())
		rates.add_child(pick)
		_rate_buttons.append(pick)
	# CLOUDS, UNDER THE TIMES and on the same terms: it announces, and the level's answer is what moves it. A switch
	# and not another button, because it is a yes or a no and not a time of day. Hugging its words, as AUDIO's do.
	_clouds = CheckButton.new()
	_clouds.name = "Clouds"
	_clouds.text = "CLOUDS"
	_clouds.add_theme_font_size_override("font_size", BoardStyle.pressed_text(20))
	_clouds.custom_minimum_size = Vector2(0.0, BoardStyle.reach(40.0))
	_clouds.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_clouds.toggled.connect(func(on: bool):
		chose_clouds.emit(on)
		_mark_the_time())
	column.add_child(_clouds)
	_no_sky = Label.new()
	_no_sky.text = "No sky to change here."
	_no_sky.add_theme_font_size_override("font_size", _sized(19))
	_no_sky.add_theme_color_override("font_color", DIM)
	column.add_child(_no_sky)
	_mark_the_time()
	return column


## ONE BUTTON OF THE TIME TAB: a toggle, a share of its row, amber when pressed, `tall` page pixels high.
func _time_button(words: String, tall: float, text_pixels: int) -> Button:
	var pick := Button.new()
	pick.text = words
	pick.toggle_mode = true
	pick.custom_minimum_size = Vector2(0.0, BoardStyle.reach(tall))
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.add_theme_font_size_override("font_size", BoardStyle.pressed_text(text_pixels))
	pick.add_theme_color_override("font_pressed_color", AMBER)
	pick.add_theme_color_override("font_hover_pressed_color", AMBER)
	return pick


## WHAT TIME THE LEVEL'S CLOCK SAYS, handed in, minutes, or -1 where there is no sky. `set_pressed_no_signal`, or showing it
## would announce it again.
func show_time(minutes: float) -> void:
	_clock_shown = minutes
	_time_shown = -1
	if minutes >= 0.0:
		for which in DaylightTuning.When.values():
			if absf(wrapf(minutes - DaylightTuning.clock_of(which), -720.0, 720.0)) < 0.5:
				_time_shown = which
	_mark_the_time()


## HOW FAST THE LEVEL'S CLOCK RUNS, handed in, without announcing it again.
func show_rate(rate: float) -> void:
	_rate_shown = rate
	_mark_the_time()


## The clock the level last handed over, minutes, or -1; and its rate. For the tests.
func clock_shown() -> float:
	return _clock_shown


func rate_shown() -> float:
	return _rate_shown


## WHETHER THE LEVEL DRAWS CLOUDS, handed in, without announcing it again.
func show_clouds(on: bool) -> void:
	_clouds_shown = on
	_mark_the_time()


## What the level last said of the clouds, for the tests.
func clouds_shown() -> bool:
	return _clouds_shown


## THE LINE UNDER THE TABS ON TIME: whose sky this is. `Net.decides_the_sky` answers it, so the words cannot tell a joiner
## it may set a time the level will then refuse.
static func time_words() -> String:
	if not Net.decides_the_sky():
		return "The host sets the time of day and the clouds for everybody."
	if Net.is_networked():
		return "Sets the time of day and the clouds for everybody in this game."
	return "Sets the sun, the sky, the clouds and the lit windows."


## The time the level last handed over, or -1, for the tests.
func time_shown() -> int:
	return _time_shown


## ---- what the pilot hears -------------------------------------------------------------------

## GAME SOUND AND VOICE: two switches, and under VOICE the line that says what it is doing or why it cannot.
##
## "An audio panel in the iPad (default to all off), one for game sound another for using kokoro to play audio"
## (2026-09-13). The switches were in `PilotHeadphones` from that day and on no page, so a player looking for the sound
## found nothing (2026-09-13: "I wasn't able to find the settings for audio"). Both OFF until the headphones say
## otherwise, and they start them off every run.
##
## THE SWITCHES ARE THE HEADPHONES'. A flick announces and then puts the switch back to what the headphones last said,
## exactly as the TIME buttons do: VOICE on a machine with no model is a switch that springs back off with the reason
## under it, rather than a switch that stays on over nothing.
func _build_the_audio_page() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_game_sound = _an_audio_switch("GAME SOUND", func(on: bool): chose_game_sound.emit(on))
	column.add_child(_game_sound)
	_voice = _an_audio_switch("VOICE", func(on: bool): chose_voice.emit(on))
	column.add_child(_voice)
	_music_sound = _an_audio_switch("MUSIC", func(on: bool): chose_music_sound.emit(on))
	column.add_child(_music_sound)
	_voice_said = Label.new()
	_voice_said.add_theme_font_size_override("font_size", _sized(17))
	_voice_said.add_theme_color_override("font_color", DIM)
	_voice_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_voice_said)
	_radio_column = VBoxContainer.new(); _radio_column.add_theme_constant_override("separation", 5)
	var title := Label.new(); title.text = "HOST RADIO"; title.add_theme_font_size_override("font_size", _sized(19))
	title.add_theme_color_override("font_color", AMBER); _radio_column.add_child(title)
	var phrase_row := GridContainer.new(); phrase_row.columns = 2
	for phrase in Radio.phrases():
		var pick := Button.new(); pick.name = "Radio_%s" % phrase.id
		pick.text = String(phrase.id).replace("_", " ").to_upper()
		pick.tooltip_text = String(phrase.text); pick.custom_minimum_size.y = BoardStyle.reach(34.0)
		pick.pressed.connect(func(): chose_radio.emit(String(phrase.text)))
		phrase_row.add_child(pick)
	_radio_column.add_child(phrase_row)
	var typed := HBoxContainer.new(); _radio_text = LineEdit.new(); _radio_text.name = "RadioText"
	_radio_text.placeholder_text = "Typed ATC line"; _radio_text.max_length = Radio.MOST_TEXT
	_radio_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL; typed.add_child(_radio_text)
	var speak := Button.new(); speak.name = "RadioSpeak"; speak.text = "SPEAK"
	speak.pressed.connect(func(): chose_radio.emit(_radio_text.text)); typed.add_child(speak)
	_radio_column.add_child(typed)
	_radio_status = Label.new(); _radio_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_radio_status.add_theme_color_override("font_color", DIM); _radio_column.add_child(_radio_status)
	column.add_child(_radio_column)
	_mark_the_audio()
	return column


func _an_audio_switch(words: String, announce: Callable) -> CheckButton:
	var flick := CheckButton.new()
	flick.text = words
	flick.add_theme_font_size_override("font_size", BoardStyle.pressed_text(18))
	flick.custom_minimum_size = Vector2(0.0, BoardStyle.reach(36.0))
	# AS WIDE AS ITS WORDS AND ITS PILL, from the left, and not across the page: stretched, VOICE's pill stood 835 px from
	# its word and 27 px from the line under it (2026-09-14). See the row of switches in `_ready`.
	flick.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	flick.toggled.connect(func(on: bool):
		announce.call(on)
		_mark_the_audio())
	return flick


## WHAT THE PILOT HEARS, handed in by `PilotHeadphones.changed`. `set_pressed_no_signal`, or showing it would announce it.
func show_audio(game_sound: bool, voice: bool, said: String) -> void:
	_heard = {"game_sound": game_sound, "voice": voice, "said": said}
	_mark_the_audio()


func show_radio(words: String, can_speak: bool) -> void:
	if _radio_column == null: return
	for control in _radio_column.find_children("*", "Button", true, false):
		(control as Button).disabled = not can_speak
	if _radio_text != null: _radio_text.editable = can_speak
	_radio_status.text = words if can_speak else "The host speaks on the radio."


## What the headphones last handed over, for the tests.
func audio_shown() -> Dictionary:
	return _heard.duplicate()


func show_music_sound(on: bool) -> void:
	if _music_sound != null:
		_music_sound.set_pressed_no_signal(on)


func show_music_catalog(ids: Array[String]) -> void:
	if _music_page != null:
		_music_page.show_catalog(ids)


func show_music(state: Dictionary, status: String, can_choose: bool) -> void:
	if _music_page != null:
		_music_page.show_state(state, status, can_choose)


func music_page() -> MusicPage:
	return _music_page


## WHAT THE RIG'S SPECTACLES ARE SET TO. See SpottingPage.show_spectacles.
func show_spotting(pair: Spectacles) -> void:
	if _spotting_page != null:
		_spotting_page.show_spectacles(pair)


func spotting_page() -> SpottingPage:
	return _spotting_page


func _mark_the_audio() -> void:
	if _game_sound == null:
		return
	_game_sound.set_pressed_no_signal(bool(_heard["game_sound"]))
	_voice.set_pressed_no_signal(bool(_heard["voice"]))
	_voice_said.text = String(_heard["said"])
	_voice_said.visible = not String(_heard["said"]).is_empty()


func _mark_the_time() -> void:
	var sky: bool = _clock_shown >= 0.0
	for i in range(_time_buttons.size()):
		_time_buttons[i].set_pressed_no_signal(sky and absf(wrapf(_clock_shown - Orrery.point(i), -720.0, 720.0)) < 0.5)
		_time_buttons[i].visible = sky
	for button in _nudge_buttons:
		button.visible = sky
	for i in range(_rate_buttons.size()):
		_rate_buttons[i].set_pressed_no_signal(is_equal_approx(CLOCK_RATES[i], _rate_shown))
		_rate_buttons[i].visible = sky
	if _clock_slider != null:
		_clock_slider.visible = sky
		if sky and not _slider_held:
			_clock_slider.set_value_no_signal(clampf(snappedf(_clock_shown, 5.0), 0.0, _clock_slider.max_value))
	if _clock_words != null:
		_clock_words.visible = sky
		if sky:
			_clock_words.text = "%s   %s%s" % [Orrery.words(_clock_shown),
				DaylightTuning.sky_words(DaylightTuning.look_at(_clock_shown)), _rate_words()]
	if _clouds != null:
		_clouds.set_pressed_no_signal(_clouds_shown)
		_clouds.visible = sky
	if _no_sky != null:
		_no_sky.visible = not sky


## How the readout says the rate: nothing at real time, else its button's words.
func _rate_words() -> String:
	if is_equal_approx(_rate_shown, 1.0):
		return ""
	for i in range(CLOCK_RATES.size()):
		if is_equal_approx(CLOCK_RATES[i], _rate_shown):
			return "   " + CLOCK_RATE_WORDS[i]
	return "   %sX" % String.num(_rate_shown, 0)


static func _first_to_press(root: Node) -> Control:
	for child in root.get_children():
		var control := child as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if control.focus_mode != Control.FOCUS_NONE:
			return control
		var inside: Control = _first_to_press(control)
		if inside != null:
			return inside
	return null


## ---- the parts bin -------------------------------------------------------------------

## BUILD, THE PARTS, AND THE TWO BUTTONS THAT MAKE IT STICK.
##
## A cockpit is a set of controls and the places they are bolted to, and the second half was
## only ever decided in the Godot editor by somebody looking at a viewport from outside.
## Whether a lever is comfortable is a question about an ARM. This is the page that lets it
## be answered from the seat.
##
## THE SWITCH IS AT THE TOP AND THE PARTS ARE BELOW IT, in that order, because adding a
## lever you cannot then move is worse than not being able to add one.
func _build_the_builders_page() -> Control:
	var column := VBoxContainer.new()
	# GAPS OF 2 px, not 4: in the real level BUILD was 879 px of content in an 871 px scrolling area (2026-09-13), where the
	# fire debrief takes a line of furniture a console on a plinth does not have.
	column.add_theme_constant_override("separation", 2)

	var building := CheckButton.new()
	building.text = "BUILD"
	building.add_theme_font_size_override("font_size", BoardStyle.pressed_text(20))
	building.custom_minimum_size = Vector2(0.0, BoardStyle.reach(36.0))
	building.toggled.connect(func(on: bool): chose_build.emit(on))
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	column.add_child(modes)
	building.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	modes.add_child(building)

	# AND THE MODE SWITCH INSIDE IT.
	#
	# Putting a lever somewhere is a guess. Whether your hand lands on it without looking is
	# the answer, and the only way to get it is to reach out and use the thing -- so the
	# builder has to be able to hand the controls back without being turned off.
	#
	# ALSO ON THE UPPER THUMB BUTTON, which is where it will actually be used: see
	# `PilotRig._building_bindings`. It is here as well because a mode you can only reach
	# by a button nothing tells you about is a mode nobody finds.
	_using = CheckButton.new()
	_using.text = "USE CONTROLS"
	_using.add_theme_font_size_override("font_size", BoardStyle.pressed_text(20))
	_using.custom_minimum_size = Vector2(0.0, BoardStyle.reach(36.0))
	_using.toggled.connect(func(on: bool): chose_try.emit(on))
	_using.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	modes.add_child(_using)

	var keeping := HBoxContainer.new()
	keeping.add_theme_constant_override("separation", 6)
	var save := Button.new()
	save.text = "SAVE"
	# 38, not 42, like the parts below it: the other part of what RESET HEAD's row cost this page (2026-09-13).
	save.custom_minimum_size = Vector2(140.0 * TEXT_SCALE, BoardStyle.reach(38.0))
	save.add_theme_font_size_override("font_size", BoardStyle.pressed_text(18))
	save.pressed.connect(func(): chose_save.emit())
	keeping.add_child(save)
	var reset := Button.new()
	reset.text = "RESET"
	reset.custom_minimum_size = Vector2(140.0 * TEXT_SCALE, BoardStyle.reach(38.0))
	reset.add_theme_font_size_override("font_size", BoardStyle.pressed_text(18))
	reset.pressed.connect(func(): chose_reset.emit())
	keeping.add_child(reset)
	column.add_child(keeping)
	var package_row := HBoxContainer.new()
	package_row.add_theme_constant_override("separation", 6)
	var save_package := Button.new()
	save_package.text = "SAVE PACKAGE"
	save_package.custom_minimum_size = Vector2(140.0 * TEXT_SCALE, BoardStyle.reach(38.0))
	save_package.add_theme_font_size_override("font_size", BoardStyle.pressed_text(16))
	save_package.pressed.connect(func(): chose_save_package.emit())
	package_row.add_child(save_package)
	var load_package := Button.new()
	load_package.text = "LOAD PACKAGE"
	load_package.custom_minimum_size = Vector2(140.0 * TEXT_SCALE, BoardStyle.reach(38.0))
	load_package.add_theme_font_size_override("font_size", BoardStyle.pressed_text(16))
	load_package.pressed.connect(func(): chose_load_package.emit())
	package_row.add_child(load_package)
	column.add_child(package_row)

	var heading := Label.new()
	heading.text = "PARTS"
	heading.add_theme_font_size_override("font_size", _sized(17))
	heading.add_theme_color_override("font_color", DIM)
	column.add_child(heading)

	# ONE BUTTON PER PART, and the list comes from the bin rather than from here. See
	# ControlCatalogue: what may be placed is a decision with reasons attached, and a second
	# copy of it on a menu page is the copy that goes stale.
	# TWO COLUMNS, now that the guarded switch makes a part name wider than one third of the
	# glass. BUILD is already an explicitly scrolling page, so preserving full readable names
	# and fingertip-sized buttons costs vertical travel rather than clipping the board at its
	# right edge. The per-craft allowlist keeps that travel to devices the craft can use.
	_parts = GridContainer.new()
	_parts.columns = 2
	_parts.add_theme_constant_override("h_separation", 6)
	_parts.add_theme_constant_override("v_separation", 2)
	column.add_child(_parts)
	show_allowed_parts(ControlCatalogue.PARTS)
	return column


## The rig hands in the craft's bin; this page only draws it.
func show_allowed_parts(allowed: Array[StringName]) -> void:
	if _parts == null or allowed == _allowed_parts:
		return
	_allowed_parts.assign(allowed)
	for child in _parts.get_children():
		_parts.remove_child(child)
		child.queue_free()
	for part in allowed:
		var add := Button.new()
		add.text = "+ %s" % ControlCatalogue.label_of(part)
		add.custom_minimum_size = Vector2(0.0, BoardStyle.reach(38.0))
		add.add_theme_font_size_override("font_size", BoardStyle.pressed_text(17))
		var which: StringName = part
		add.pressed.connect(func(): chose_part.emit(which))
		add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_parts.add_child(add)


## THE BUILDER SAYS WHICH MODE THE HANDS ARE IN.
##
## Pushed the other way for once: everything else on this board is the player telling the
## game something, and this is the game telling the board. The upper thumb button switches
## between moving the controls and working them, so by the time somebody looks at the page
## again the switch on it may be a frame or an hour out of date.
##
## `set_pressed_no_signal`, or flipping it here would emit the very signal that flipped it.
func show_building(trying: bool) -> void:
	if _using != null:
		_using.set_pressed_no_signal(trying)


## ---- the legend ----------------------------------------------------------------------

## EVERY INPUT AND WHAT IT DOES, handed over by the rig.
##
## The page does not know what a binding is. It is given rows of three strings -- where the
## input is, what it is called, and what it does -- and it draws them under a heading per
## place. That is the same contract every other page here has: a page is handed its data and
## draws it, and anything it wants that it has not been given is a gap in what the thing
## above it shares.
##
## THIS EXISTS BECAUSE THE ONLY LEGEND IN THE GAME WAS A `print`. `PilotRig._enter_desktop`
## wrote the key list to stdout, which a player who double-clicks the game never sees and
## which in a headset is invisible twice over -- and the VR bindings, which are the rich
## half ("the trigger fires the gun the hand is holding, and the thumb depends on what that
## is"), were written down nowhere a player could read at all.
func show_help(rows: Array) -> void:
	if _help == null:
		return
	var as_text: PackedStringArray = []
	for row in rows:
		as_text.append("%s|%s|%s" % [(row as Dictionary).get("where", ""),
			(row as Dictionary).get("what", ""), (row as Dictionary).get("does", "")])
	var now: String = "\n".join(as_text)
	if now == _legend:
		return
	_legend = now
	for old_row in _help.get_children():
		old_row.queue_free()
	var heading: String = ""
	for row in rows:
		var where: String = String((row as Dictionary).get("where", ""))
		if where != heading:
			heading = where
			var title := Label.new()
			title.text = where
			title.add_theme_font_size_override("font_size", _sized(20))
			title.add_theme_color_override("font_color", AMBER)
			_help.add_child(title)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		var what := Label.new()
		what.text = String((row as Dictionary).get("what", ""))
		what.custom_minimum_size = Vector2(210.0, 0.0) * TEXT_SCALE
		what.add_theme_font_size_override("font_size", _sized(17))
		what.add_theme_color_override("font_color", PALE)
		line.add_child(what)
		var does := Label.new()
		does.text = String((row as Dictionary).get("does", ""))
		does.add_theme_font_size_override("font_size", _sized(17))
		does.add_theme_color_override("font_color", DIM)
		does.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		does.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(does)
		_help.add_child(line)


## What the legend currently reads, for the tests: one row per line, `where|what|does`.
func help_text() -> String:
	return _legend


## ---- the connection log -------------------------------------------------------------------

## WHAT HAPPENED AT THE DOOR, newest first: `Net.logbook.rows()`, handed over by the rig whenever a row is written. On a
## host that is everybody who knocked; on a client it is this machine's own knocks. The page does not ask which.
func show_log(rows: Array) -> void:
	_log_rows = rows.duplicate()
	_log_serial += 1
	if _log != null and _log.visible:
		_draw_the_log()
		if _said != null and _tab == Tab.LOG:
			_said.text = log_words()


## The line under the tabs on LOG: what the page is, and how many rows it is not showing.
func log_words() -> String:
	var hidden: int = maxi(_log_rows.size() - LOG_DRAWN, 0)
	return "Who came to the door and what became of it, newest first." + \
		(" %d older not shown." % hidden if hidden > 0 else "")


## A ROW, AS TWO LINES: when, what and to whom in the colour of what it was; and then the words, dim and wrapped. A
## refusal and a timeout are amber, as every no on this board is; a join is pale; the rest is the quiet grey.
static func log_head(row: Dictionary) -> String:
	var at: float = float(row.get("at", 0.0))
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var when: String = Time.get_time_string_from_unix_time(int(at) + bias)
	var event: String = String(row.get("event", "?"))
	var head: String = "%s  %s" % [when, event]
	if String(row.get("code", "")) != "":
		head += " " + String(row["code"]).replace("_", " ")
	if String(row.get("who", "")) != "":
		head += "  " + String(row["who"])
	elif row.has("peer"):
		head += "  peer %d" % int(row["peer"])
	return head


static func log_body(row: Dictionary) -> String:
	if String(row.get("words", "")) != "":
		return String(row["words"])
	var parts: PackedStringArray = []
	if String(row.get("client", "")) != "":
		parts.append("running " + String(row["client"]))
	if String(row.get("level", "")) != "":
		parts.append("on " + String(row["level"]))
	if String(row.get("was", "")) != "":
		parts.append("was " + String(row["was"]))
	return ", ".join(parts)


static func log_colour(row: Dictionary) -> Color:
	match String(row.get("event", "")):
		"REFUSED", "TIMED_OUT", "DROPPED", "CLOSED", "PARTED":
			return AMBER
		"JOINED", "GREETED", "RELOADED":
			return PALE
	return DIM


func _draw_the_log() -> void:
	if _log == null or _log_drawn == _log_serial:
		return
	_log_drawn = _log_serial
	for old_row in _log.get_children():
		_log.remove_child(old_row)
		old_row.queue_free()
	if _log_rows.is_empty():
		var nothing := Label.new()
		nothing.text = "Nobody has knocked yet."
		nothing.add_theme_font_size_override("font_size", _sized(17))
		nothing.add_theme_color_override("font_color", DIM)
		_log.add_child(nothing)
		return
	for i in range(mini(_log_rows.size(), LOG_DRAWN)):
		var row: Dictionary = _log_rows[i]
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 0)
		var head := Label.new()
		head.text = log_head(row)
		head.add_theme_font_size_override("font_size", _sized(17))
		head.add_theme_color_override("font_color", log_colour(row))
		head.clip_text = true
		entry.add_child(head)
		var body_text: String = log_body(row)
		if body_text != "":
			var body := Label.new()
			body.text = body_text
			body.add_theme_font_size_override("font_size", _sized(15))
			body.add_theme_color_override("font_color", DIM if log_colour(row) != AMBER else PALE)
			body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			entry.add_child(body)
		_log.add_child(entry)


## What the LOG page draws now, one line per label, for the tests: "" when it is not built.
func log_text() -> String:
	var lines: PackedStringArray = []
	if _log == null:
		return ""
	for entry in _log.get_children():
		for label in entry.find_children("*", "Label", true, false) + ([entry] if entry is Label else []):
			lines.append((label as Label).text)
	return "\n".join(lines)


## ---- how each control is worked ------------------------------------------------------

## ONE SWITCH PER CONTROL IN THIS COCKPIT, listed by the name it writes on its own label.
##
## Built from what is actually in front of the player rather than from a table of every
## control in the game: a tower has a radio and a button, an aeroplane has eight things, and
## a page offering switches for controls this craft does not have is a page of dead rows.
##
## `show_controls` is how the rig hands them over -- the page has no idea what a cockpit is
## and does not want one.
func show_controls(named: Array) -> void:
	if _feel == null:
		return
	var roster: String = "|".join(named)
	if roster == _felt:
		return
	_felt = roster
	for old in _feel.get_children():
		old.queue_free()
	# LEVEL HORIZON IN SMALL BOATS, FIRST ON FEEL, whatever the craft. Asked for with the wind-sea (C1, 2026-09-15): a
	# seated player sees a launch roll and pitch and does not feel it, which is the motion that makes a seated player
	# sick. It is about how the craft moves you, so it lives with the controls' feel; the settings grid is full. Off
	# unless chosen, and yours alone, like HUD.
	_horizon = CheckButton.new()
	_horizon.text = "LEVEL HORIZON IN SMALL BOATS"
	_horizon.button_pressed = _horizon_on
	_horizon.add_theme_font_size_override("font_size", BoardStyle.pressed_text(18))
	_horizon.custom_minimum_size = Vector2(0.0, BoardStyle.reach(36.0))
	# HUGGING ITS WORDS: a full-width switch drew its pill 417 px from them and nearer another switch's.
	_horizon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_horizon.toggled.connect(func(on: bool): chose_level_horizon.emit(on))
	_feel.add_child(_horizon)
	if named.is_empty():
		var none := Label.new()
		none.text = "Nothing to configure here."
		none.add_theme_font_size_override("font_size", _sized(17))
		none.add_theme_color_override("font_color", DIM)
		_feel.add_child(none)
		return
	# IN TWO COLUMNS. A four-seat aeroplane hands this every control the rig can reach across the craft -- twenty-odd --
	# and one column of them ran off the bottom of the board at the bigger control size (2026-09-13), in the first
	# screenshot from a rig actually sitting in one. Each entry is a name and its switch, and half the board holds both.
	var columns := GridContainer.new()
	columns.columns = 2
	columns.add_theme_constant_override("h_separation", 12)
	columns.add_theme_constant_override("v_separation", 2)
	_feel.add_child(columns)
	for name in named:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var what := Label.new()
		what.text = String(name).to_upper()
		what.custom_minimum_size = Vector2(150.0, 0.0) * TEXT_SCALE
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		what.add_theme_font_size_override("font_size", _sized(17))
		what.add_theme_color_override("font_color", PALE)
		line.add_child(what)
		var how := CheckButton.new()
		how.text = "TURN"
		how.add_theme_font_size_override("font_size", BoardStyle.pressed_text(15))
		var which: String = String(name)
		how.toggled.connect(func(on: bool): chose_drive.emit(which, on))
		line.add_child(how)
		columns.add_child(line)


## ---- the traffic page -----------------------------------------------------------------

## ONE MORE OF THAT, PLEASE.
##
## The sky used to be built full -- a hundred and sixty machines against a wire that fits
## about fifty-two a tick -- and what that looks like from a cockpit is jitter and aeroplanes
## that seem to sink. It starts quiet now, and this is how it gets filled: a machine at a
## time, by somebody who can see what it costs.
##
## THE FOUR THAT FLY THEMSELVES and no others. Every kind has an autopilot in the table, but
## only these four have waypoint pools -- see `Terrain.waypoints` -- and a machine with
## nowhere to go is a machine that sits there being replicated.
func _build_the_traffic_page() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	var title := Label.new()
	title.text = "PLANES IN THE STACK"
	title.add_theme_font_size_override("font_size", _sized(18))
	title.add_theme_color_override("font_color", PALE)
	column.add_child(title)
	_load_count = Label.new()
	_load_count.text = "0 / %d" % HoldingStack.MOST
	_load_count.add_theme_font_size_override("font_size", _sized(26))
	_load_count.add_theme_color_override("font_color", AMBER)
	column.add_child(_load_count)
	var counts := HFlowContainer.new()
	counts.add_theme_constant_override("h_separation", 6)
	counts.add_theme_constant_override("v_separation", 6)
	# 0, A FIFTY, THE MEASURED RUNG AND THE CAP. The user asked to add and remove planes fifty at a time
	# (2026-09-17), so the steps below are fifty; 200 stays because it is the rung every measurement in
	# agents.md was taken at, and the last button is whatever the stack's cap is rather than a number typed here.
	for wanted in [0, 50, 200, HoldingStack.MOST]:
		var exact := Button.new()
		exact.text = str(wanted)
		exact.custom_minimum_size = Vector2(BoardStyle.reach(54.0), BoardStyle.reach(42.0))
		exact.add_theme_font_size_override("font_size", BoardStyle.pressed_text(17))
		var chosen: int = wanted
		exact.pressed.connect(func(): chose_stack.emit(chosen))
		counts.add_child(exact)
	for change in [-50, 50]:
		var step := Button.new()
		step.text = "%+d" % change
		step.custom_minimum_size = Vector2(BoardStyle.reach(62.0), BoardStyle.reach(42.0))
		step.add_theme_font_size_override("font_size", BoardStyle.pressed_text(17))
		var by: int = change
		step.pressed.connect(func(): chose_stack.emit(clampi(_stack_shown + by, 0, HoldingStack.MOST)))
		counts.add_child(step)
	column.add_child(counts)
	_link_count = Label.new()
	_link_count.text = "LINK 0 MS EACH WAY"
	_link_count.add_theme_font_size_override("font_size", _sized(18))
	column.add_child(_link_count)
	var links := HFlowContainer.new()
	links.add_theme_constant_override("h_separation", 6)
	# 80 MS IS THE STRESS LEVEL'S OWN LINK, and it is on this row so a person in the headset can take it off and put it
	# back without a command line. The numbers are ONE WAY: see `Net.suit_the_link`.
	for value in [0, 80, 100, 200]:
		var link := Button.new()
		link.text = "%d MS" % value
		link.custom_minimum_size = Vector2(BoardStyle.reach(72.0), BoardStyle.reach(42.0))
		link.add_theme_font_size_override("font_size", BoardStyle.pressed_text(15))
		var latency: int = value
		link.pressed.connect(func(): chose_latency.emit(latency))
		links.add_child(link)
	column.add_child(links)
	# SAVE BANDWIDTH, THE HOST'S ALONE. The user, 2026-09-18: "let's keep bandwidth saving off by default, but make it an
	# option in the ipad." Here, beside the other things that decide what the wire carries, and SHOWN ONLY TO WHOEVER
	# DECIDES IT (`Sim.decides_what_is_sent`, asked again at every `show_tab`): a joiner's press would change nothing, so a
	# joiner is not offered one. OFF until the host's own settings say otherwise; the level hands the answer back through
	# `show_save_bandwidth`, so the switch is never its own guess.
	_save_bandwidth_box = VBoxContainer.new()
	_save_bandwidth_box.add_theme_constant_override("separation", 2)
	_save_bandwidth = CheckButton.new()
	_save_bandwidth.text = "SAVE BANDWIDTH"
	_save_bandwidth.add_theme_font_size_override("font_size", BoardStyle.pressed_text(18))
	_save_bandwidth.custom_minimum_size = Vector2(0.0, BoardStyle.reach(36.0))
	_save_bandwidth.toggled.connect(func(on: bool): chose_save_bandwidth.emit(on))
	# AS WIDE AS ITS WORDS, so the pill sits beside them and not at the far edge of the page (tests/clipboard.gd,
	# `and_every_switchs_pill_is_nearer_its_own_words_than_any_others`: full width, it was 646 px from them).
	_save_bandwidth.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_save_bandwidth_box.add_child(_save_bandwidth)
	var why := Label.new()
	why.text = "Stop sending far players' heads and hands (they return within %d m). Off by default." % int(Sim.POSE_NEAR_M)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.add_theme_font_size_override("font_size", _sized(14))
	why.add_theme_color_override("font_color", DIM)
	_save_bandwidth_box.add_child(why)
	_save_bandwidth_box.visible = Sim.decides_what_is_sent()
	column.add_child(_save_bandwidth_box)
	_load_readout = Label.new()
	_load_readout.text = "0 peers · 0 kB/s · 0 pkt/tick · buffer 0 · 0 rollback/s · tick 0.00 ms"
	_load_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_load_readout.add_theme_font_size_override("font_size", _sized(14))
	_load_readout.add_theme_color_override("font_color", DIM)
	column.add_child(_load_readout)
	var divider := HSeparator.new()
	column.add_child(divider)
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for kind in [Sim.Kind.PLANE, Sim.Kind.HELI, Sim.Kind.CAR, Sim.Kind.BOAT]:
		var add := Button.new()
		add.text = "+ " + Sim.kind_name(kind)
		add.custom_minimum_size = Vector2(0.0, BoardStyle.reach(44.0))
		add.add_theme_font_size_override("font_size", BoardStyle.pressed_text(18))
		var chosen: int = kind
		add.pressed.connect(func(): chose_traffic.emit(chosen))
		grid.add_child(add)
	column.add_child(grid)
	# ATTACKERS, AT WHATEVER THE HOST IS IN (lane/combat): bad pilots and bad shots, sent to be shot down. The host's,
	# because a raid is entities, and the level says so to anybody else who presses.
	column.add_child(HSeparator.new())
	var attack_title := Label.new()
	attack_title.text = "ATTACK MY CRAFT"
	attack_title.add_theme_font_size_override("font_size", _sized(18))
	attack_title.add_theme_color_override("font_color", PALE)
	column.add_child(attack_title)
	var attacks := HFlowContainer.new()
	attacks.add_theme_constant_override("h_separation", 6)
	attacks.add_theme_constant_override("v_separation", 6)
	for raid in [["2 PLANES", 2, 0], ["2 HELICOPTERS", 0, 2], ["PLANES + HELI", 2, 1], ["CALL OFF", -1, -1]]:
		var send := Button.new()
		send.name = "Attack" + String(raid[0]).replace(" ", "").replace("+", "And")
		send.text = String(raid[0])
		send.custom_minimum_size = Vector2(0.0, BoardStyle.reach(44.0))
		send.add_theme_font_size_override("font_size", BoardStyle.pressed_text(17))
		var planes: int = int(raid[1])
		var helis: int = int(raid[2])
		send.pressed.connect(func(): chose_attack.emit(planes, helis))
		attacks.add_child(send)
	column.add_child(attacks)
	return column


func show_load_test(count: int, latency_ms: int, readout: String) -> void:
	_stack_shown = count
	_latency_shown = latency_ms
	if _load_count != null:
		_load_count.text = "%d / %d" % [count, HoldingStack.MOST]
	if _link_count != null:
		_link_count.text = "LINK %d MS EACH WAY" % latency_ms
	if _load_readout != null:
		_load_readout.text = readout


func load_count() -> int:
	return _stack_shown


## WHETHER SAVE BANDWIDTH IS ON, handed in from the level that decides it, without announcing it again.
func show_save_bandwidth(on: bool) -> void:
	if _save_bandwidth != null:
		_save_bandwidth.set_pressed_no_signal(on)


## The SAVE BANDWIDTH switch, for a suite that presses it with a hand; and whether this board offers it at all.
func save_bandwidth_switch() -> CheckButton:
	return _save_bandwidth


func offers_save_bandwidth() -> bool:
	return _save_bandwidth_box != null and _save_bandwidth_box.visible


## ---- the crew page --------------------------------------------------------------------

## WHAT THE HOST SAID TO A JOIN, in words, keyed by the name the simulation gives each reason
## (`CockpitWorld::join_why_name`). A reason with no sentence here still says something.
const ANSWERS: Dictionary = {
	"joined": "You are in seat %d.",
	"seat_taken": "Somebody else has that seat. Choose a free one.",
	"full": "Every seat in that craft is taken.",
	"gone": "That player is not flying anything now.",
	"already_there": "You are already in that seat.",
	"no_such_seat": "That craft has no such seat.",
	"not_boardable": "Nobody may board that craft.",
	"kind_no_issue_place": "This level has no clear place to issue that craft.",
}
## Said the moment JOIN is pressed, until the answer lands: a press that shows nothing for a
## tenth of a second over a slow link reads as a press that missed.
const ASKING: String = "Asking the host for that seat..."
## Said when the rig let a JOIN go after its patience with no answer. Amber, like any no.
const NO_ANSWER: String = "The host didn't answer. Try again."
## Said when the rig let a craft press go after its patience with no new craft: the kind, in capitals, goes in.
const NO_MOVE: String = "The host didn't move you to a %s. Try again."
## Said when a menu press is refused because the last one is still waiting for the server: one at a time.
const STILL_WAITING: String = "Still waiting for the host to answer your last press."
## What the line under the tabs says on CREW.
const JOIN_HINT: String = "Press JOIN on a free seat. The host seats you there, or says why not."

## The manifest last handed in: `CrewManifest.read`'s rows.
var _manifest: Array = []
## What the server last said to this machine's JOIN: {count, why, seat}, or {}.
var _answer: Dictionary = {}
## The answer's count when JOIN was last pressed here, or -1 while no press is waiting for one.
## A new count after a press is the answer to that press.
var _asked_at: int = -1
## The sentence the last answer made, or ASKING while one is awaited. See `show_tab`.
var _answer_line: String = ""


## THE CREWS, AND THE HOST'S LAST ANSWER, handed in by whatever holds the board. Answers `tick`'s question: whether the
## board looks different for it and wants repainting.
func show_crew(manifest: Array, answer: Dictionary) -> bool:
	_manifest = manifest
	_answer = answer
	# A NEW ANSWER TO A PRESS MADE HERE is said at once, on whatever tab is up, in the line
	# that answers presses. An answer that was already standing when the page was built is
	# not news, which is why only a count that MOVED after a press counts.
	if _asked_at >= 0 and int(answer.get("count", 0)) != _asked_at:
		_asked_at = -1
		_answer_line = answer_words(answer)
		# ON CREW the head of the list says it; on any other tab, which a pilot may have turned to while the answer was
		# on its way, the line under the tabs does, because that is the only place on show.
		if _tab != Tab.CREW:
			_say_answer(_answer_line)
	return tick()


## EVERY FRAME THE BOARD IS UP, whether or not anything was handed in: the furniture that is about the SESSION rather
## than about a page. `Clipboard` calls it both ways round -- with a fresh manifest through `show_crew`, and on its own
## when the simulation's pilots have not changed since last frame, which is most frames. The code line was first written
## from `show_crew` alone and so appeared only when somebody took off or landed (2026-09-15).
## Answers whether the board LOOKS different for it, so the panel is repainted only when it does.
func tick() -> bool:
	var moved: bool = _say_the_code()
	moved = _say_the_notice() or moved
	refresh()
	return moved


## THE SESSION'S NOTICE, as `Net` words it now: a count-down moves once a second, so the line is rewritten once a second
## and not once a frame.
func _say_the_notice() -> bool:
	if _notice == null:
		return false
	var line: String = Net.notice_words()
	if line == _notice_said:
		return false
	_notice_said = line
	_notice.text = line
	_notice.visible = line != ""
	return true


## What the notice line reads, for the tests.
func notice_text() -> String:
	return _notice.text if _notice != null and _notice.visible else ""


## THE CODE AND WHO IS ABOARD, on whatever tab is up.
##
## `Net` knows the code and the transport knows who is connected; this repeats them and decides nothing, which is the
## same listing the CREW page is. Written from `show_crew`, which `Clipboard` calls every frame the board is up, so a
## code drawn or a player arriving is on the glass within a frame -- and only when the sentence CHANGES, because
## assigning a Label's text redraws the render target the board is painted on.
##
## WHAT IT COUNTS, SAID: machines in the session, not people in your craft. "1 of 8 aboard" above a craft that visibly
## held two read as a wrong count (team-lead, 2026-09-15).
func _say_the_code() -> bool:
	if _code == null:
		return false
	var line: String = ""
	if Net.session_code != "":
		line = "STEAM CODE %s  ·  %d of %d players connected" % [JoinCode.spell(Net.session_code), Net.aboard(),
			Net.MAX_PLAYERS]
	if line == _code_said:
		return false
	_code_said = line
	_code.text = line
	_code.visible = line != ""
	return true


## What the code line reads, for the tests.
func code_text() -> String:
	return _code.text if _code != null and _code.visible else ""


## THE HOST NEVER ANSWERED: the rig held the press for its patience and let it go. Said where an answer would have been.
func show_unanswered_join() -> void:
	_asked_at = -1
	_answer_line = NO_ANSWER
	if _tab != Tab.CREW:
		_say_answer(_answer_line)
	refresh()


## A CRAFT PRESS THE SERVER NEVER SHOWED: said in the line under the tabs, amber, on whatever tab is up.
func show_unanswered_kind(kind: int) -> void:
	_say_answer(NO_MOVE % Sim.kind_name(kind).to_upper())


## THE HOST ANSWERED A CRAFT PRESS WITHOUT MOVING US. Today that means the level has no
## clear registered issue place (including every room); keep the kind in the sentence so
## the response still identifies the button when it arrives over a slow link.
func show_kind_answer(kind: int, why: String) -> void:
	if why == "kind_moved":
		_say_answer("The host is moving you to a %s." % Sim.kind_name(kind).to_upper())
		return
	if why == "kind_no_issue_place":
		_say_answer("This level has no clear place to issue a %s." % Sim.kind_name(kind).to_upper())
		return
	_say_answer(String(ANSWERS.get(why, "The host refused that %s." % Sim.kind_name(kind).to_upper())))


## A MENU PRESS REFUSED BECAUSE THE LAST ONE IS STILL WAITING: said in the line under the tabs, amber, on whatever tab is up.
## The press it refused set nothing waiting of its own, so the answer to the earlier press still lands where it would have.
func show_still_waiting() -> void:
	_say_answer(STILL_WAITING)


## AN ANSWER IN THE LINE UNDER THE TABS, amber when it is a no, as the head of the crew list writes one. `show_tab` puts the
## line back to its own colour.
func _say_answer(line: String) -> void:
	say(line)
	if _said != null:
		_said.add_theme_color_override("font_color", AMBER if refused(line) else DIM)


## An answer as a sentence. Static, so a test can read the words without a page.
static func answer_words(answer: Dictionary) -> String:
	var why: String = String(answer.get("why", ""))
	if why == "joined":
		return String(ANSWERS[why]) % (int(answer.get("seat", 0)) + 1)
	return String(ANSWERS.get(why, "The host said no (%s)." % why))


## A JOIN PRESSED: remember where the answers stood, say that it is asking, and announce it.
func _join_pressed(client: int, seat: int) -> void:
	_asked_at = int(_answer.get("count", 0))
	_answer_line = ASKING
	chose_join.emit(client, seat)
	refresh()


## Whether an answer is a no. Asking and joined are not.
static func refused(answer_line: String) -> bool:
	return answer_line != "" and answer_line != ASKING and not answer_line.begins_with("You are in seat")


## EVERY CREWED CRAFT, ONE ROW EACH: what it is, and each seat with who is in it or a JOIN.
## Yours first. A craft's JOIN names the craft by a player aboard, and the seat by number.
##
## FIVE COLUMNS OF EQUAL WIDTH -- the craft, then its four seats -- rather than a card per
## seat, because eight players in four craft stacked as a list is taller than the page
## (see `tests/clipboard.gd`, "the crew page fits full"), and a seat's column lining up with
## the same seat of the craft above reads as a table at a glance.
##
## Rebuilt only when the manifest changes. A row is a dozen controls; forty of them rebuilt
## every frame on a render target is the whole cost of this panel.
func refresh() -> void:
	if _crew == null or not _crew.visible:
		return
	var builds: Array = build_rows()
	var seen: String = "%s|%s|%s|%s" % [Net.level, _answer_line, _manifest, builds]
	if seen == _roster:
		return
	_roster = seen
	# OUT OF THE TREE BEFORE FREED: a row only queued stays on the page until the frame ends, and a page rebuilt twice in
	# one frame -- a count that changed -- then showed its old line beside its new one.
	for old in _crew.get_children():
		_crew.remove_child(old)
		old.queue_free()
	# WHICH LEVEL EVERYBODY HERE IS FLYING, first: chosen on the desk and gone with it, and the same on every machine in
	# the session -- a joiner is told the host's. `Net` knows it; this repeats it.
	var chart: LevelChart = ChartDrawer.chart(Net.level)
	if chart != null:
		var where := Label.new()
		where.name = "Level"
		where.text = "LEVEL  %s" % chart.name.to_upper()
		where.add_theme_font_size_override("font_size", _sized(21))
		where.add_theme_color_override("font_color", PALE)
		_crew.add_child(where)
	# THE CODE A FRIEND TYPES IS NOT HERE ANY MORE. It led this list from 2026-09-14 until the afternoon of 2026-09-15,
	# when it became a line of furniture on every tab (see `_say_the_code`): a host looking for it had to find CREW
	# first. The same words twice on one page read as a mistake, so CREW says it once, at the head of the board.
	# THE HOST'S ANSWER, AT THE HEAD OF THE LIST THE PRESS WAS MADE ON, and bigger than anything else written on the
	# page. "Make the answer line readable at clipboard distance, and put the refusal where the pilot is looking"
	# (team-lead, 2026-09-15): the line under the tabs is 24 px and dim, and it is the far end of the board from a JOIN
	# near the bottom of the list. A pilot who has just pressed is looking at the list, so this is where the answer goes,
	# amber when it is a no. It stays until the next press. The line under the tabs still says it too, on any tab.
	if _answer_line != "":
		var answer := Label.new()
		answer.name = "Answer"
		answer.text = _answer_line
		answer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		answer.add_theme_font_size_override("font_size", _sized(24))
		answer.add_theme_color_override("font_color", AMBER if refused(_answer_line) else PALE)
		_crew.add_child(answer)
	for craft in _manifest:
		_crew.add_child(_a_craft(craft as Dictionary))
	# WHO IS ON ANOTHER BUILD, AND BY HOW MUCH, under the crews: one line a player, amber, and nothing at all when
	# everybody is on this one. See `build_rows`.
	for row in builds:
		var build := Label.new()
		build.name = "Build%d" % int(row["player"])
		build.text = String(row["words"])
		build.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		build.add_theme_font_size_override("font_size", _sized(17))
		build.add_theme_color_override("font_color", AMBER)
		_crew.add_child(build)
	if CrewManifest.others(_manifest) == 0:
		var alone := Label.new()
		alone.text = "Nobody else is here." if Net.is_in_session \
			else "Not in a session."
		alone.add_theme_font_size_override("font_size", _sized(19))
		alone.add_theme_color_override("font_color", DIM)
		_crew.add_child(alone)


## EVERY OTHER PLAYER WHOSE BUILD IS NOT THIS ONE'S AGE: [{player, words}], "PLAYER 2 · BUILD 2 DAYS OLDER THAN YOURS",
## in player order.
##
## Asked for on 2026-09-19: the host "sees, per crew member, who is on an older or newer build and by how much" -- the
## player's own words were "so you can say who needs to update". A peer on another COMMIT never gets this far (the
## handshake refuses it, saying who is behind), so what shows here is one commit built at two times: a release beside a
## dev run of it, or two exports. Off the ROSTER rather than the seats, because the roster has every player in the
## session whether or not they have sat anywhere, and its build times are the host's, from each player's hi.
## `Net.build_age_of` answers; this only words it. Every machine shows it against its own build.
func build_rows() -> Array:
	var rows: Array = []
	for card in Net.roster_cards():
		var player: int = int((card as Dictionary).get("player", 0))
		if player == Sim.local_client_id():
			continue
		var age: String = Net.build_age_of(player)
		if age != "":
			rows.append({"player": player, "words": "%s  ·  BUILD %s THAN YOURS" % [Net.name_of(player).to_upper(),
				age.to_upper()]})
	return rows


## How much wider the craft's column is than a seat's.
const TITLE_WIDTH: float = 1.35


## " · 1.2 KM", " · 38 KM", or nothing for your own craft or a distance nobody knows.
static func _how_far(metres: float, yours: bool) -> String:
	if yours or metres < 0.0:
		return ""
	if metres < 10000.0:
		return " · %.1f KM" % (metres / 1000.0)
	return " · %d KM" % roundi(metres / 1000.0)


func _a_craft(craft: Dictionary) -> Control:
	var named: int = int(craft.get("names", 0))
	var row := HBoxContainer.new()
	row.name = "Craft%d" % named
	row.add_theme_constant_override("separation", 8)

	# THREE LINES: what it is, whose it is, and how much room it has -- the last the same on every row, yours included.
	# A LITTLE WIDER than a seat's column, for "PLAYER 254'S" and "2 FREE · 38 KM"; a seat's column still holds
	# "PLAYER 254" (tests/clipboard.gd, "the crew page fits full").
	var title := VBoxContainer.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_stretch_ratio = TITLE_WIDTH
	title.add_theme_constant_override("separation", 0)
	row.add_child(title)
	var kind := Label.new()
	kind.text = String(craft.get("kind_name", "?")).to_upper()
	kind.add_theme_font_size_override("font_size", _sized(20))
	kind.add_theme_color_override("font_color", AMBER)
	title.add_child(kind)
	var whose := Label.new()
	whose.name = "Whose"
	whose.text = "YOURS" if bool(craft.get("yours", false)) else "%s'S" % Net.name_of(named).to_upper()
	whose.add_theme_font_size_override("font_size", _sized(17))
	whose.add_theme_color_override("font_color", AMBER if bool(craft.get("yours", false)) else PALE)
	title.add_child(whose)
	var room := Label.new()
	room.name = "Room"
	var free: int = int(craft.get("free", 0))
	room.text = ("FULL" if free == 0 else "%d FREE" % free) + _how_far(float(craft.get("distance", -1.0)),
		bool(craft.get("yours", false)))
	room.add_theme_font_size_override("font_size", _sized(17))
	room.add_theme_color_override("font_color", DIM)
	title.add_child(room)

	# THE CELLS, `CrewManifest.ROW_SEATS` TO A LINE. A craft of four seats or fewer is the row it always was; a longer
	# one wraps onto further lines under the first, each with an empty column where the title is, and one of more than
	# `CrewManifest.FOLD_PAST` seats has its free seats folded a station to a cell (lane/seats, 2026-09-18).
	var cells: Array = CrewManifest.cells(craft)
	var lines: int = maxi(1, ceili(float(cells.size()) / float(CrewManifest.ROW_SEATS)))
	var line: HBoxContainer = row
	var block: VBoxContainer = null
	if lines > 1:
		block = VBoxContainer.new()
		block.name = row.name
		block.add_theme_constant_override("separation", 4)
		row.name = "Line0"
		block.add_child(row)
	for index in range(lines * CrewManifest.ROW_SEATS):
		if index > 0 and index % CrewManifest.ROW_SEATS == 0:
			line = HBoxContainer.new()
			line.name = "Line%d" % (index / CrewManifest.ROW_SEATS)
			line.add_theme_constant_override("separation", 8)
			var under := Control.new()
			under.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			under.size_flags_stretch_ratio = TITLE_WIDTH
			line.add_child(under)
			block.add_child(line)
		# A CELL FOR EVERY PLACE ON THE LINE, empty past the ones this craft has, so a car's three seats line up
		# under an aeroplane's four.
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 0)
		line.add_child(cell)
		if index >= cells.size():
			continue
		var seat: Dictionary = cells[index]
		var seat_number: int = int(seat.get("seat", index))
		var free_here: int = int(seat.get("free", 0))
		var role := Label.new()
		role.text = "%s ×%d" % [String(seat.get("station", "seat")).to_upper(), free_here] if free_here > 1 \
			else "%d %s" % [seat_number + 1, String(seat.get("station", "seat")).to_upper()]
		role.add_theme_font_size_override("font_size", _sized(17))
		role.add_theme_color_override("font_color", DIM)
		cell.add_child(role)
		var who: int = int(seat.get("client", -1))
		if who < 0:
			var join := Button.new()
			join.name = "Join%d_%d" % [named, seat_number]
			join.text = "JOIN"
			join.custom_minimum_size = Vector2(0.0, BoardStyle.reach(36.0))
			join.add_theme_font_size_override("font_size", BoardStyle.pressed_text(18))
			var chosen: int = seat_number
			join.pressed.connect(func(): _join_pressed(named, chosen))
			cell.add_child(join)
			continue
		var person := Label.new()
		person.text = "YOU" if bool(seat.get("you", false)) else Net.name_of(who).to_upper()
		person.custom_minimum_size = Vector2(0.0, BoardStyle.reach(36.0))
		person.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		person.add_theme_font_size_override("font_size", _sized(19))
		person.add_theme_color_override("font_color", AMBER if bool(seat.get("you", false)) else Net.colour_of(who))
		cell.add_child(person)
	return block if block != null else row

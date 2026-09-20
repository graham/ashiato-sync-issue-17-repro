# The cockpit plan, as asked for on 2026-09-15

Eighteen things, to be built **one at a time**, in the order below unless a reason to reorder is
written down here. This file is the tracker: a session picks the first item that is not `DONE`,
builds it, proves it, lands it, and updates the item's block before starting the next.

**Status words.** `TODO` — not started. `IN HAND` — being built now, by whoever wrote their name
in it. `BLOCKED` — cannot proceed, with what on. `DONE` — landed on `main`, with the commit and
what proved it.

**Every item ends with a gate**, and the gate is named in the item before the work starts. A gate
is a headless suite that can fail, plus a picture where the thing is visible. "It looked right when
I tried it" is not a gate. See `agents.md` and `testing_godot_headless.md`.

**Keep this file honest.** An item that turns out to be three items gets split here first. An item
that turns out to be wrong gets struck through with the reason, not deleted.

---

## 0. STANDING RULE: everything must be workable and testable outside VR

> "from now on we need to be able to test and work on the game outside of VR, take that into
> consideration going forward, especially for menus and main menu and lobby."

**This is not an item. It is a condition on every item below**, and on anything built after them.

What it means in practice, to be filled in as each item meets it:

- Anything a player operates must be reachable with **keyboard and mouse** as well as with the
  headset. The rig already has a desk mode (`PilotRig`, `DESK_KEYS`) and the desk screens already
  take a mouse ray through `GlassPointer` — the rule is that no NEW control may be headset-only.
- Anything a player *sees* must be checkable **headless** or in a **window**, not only through a
  headset. A menu gets a suite that presses it through the real path (`tests/code_pad.gd` is the
  model: `force_hand` and `force_input` drive the rig's own seams) and a shot probe that saves a
  picture (`tests/code_pad_shot.gd` is the model).
- The V-toggle into the headset stays what it is: a thing you press when you want it, never a
  thing the game needs to do its job.

**Why it is first.** Most of what follows is menus, a lobby, a map page and a music tab — the parts
that are slowest to test in a headset and the parts a desk can test perfectly well.

---

## 1. Hosting does not work unless the client plays solo first — PART DONE, and the report did not reproduce

> "When a server starts, it doesn't work correctly, clients need to start the single player game,
> then join, they should be able to load from the main menu, build some tests to make sure that this
> works correctly by connecting via ip."

**What is claimed:** a client cannot go straight from the main menu to a hosted game by IP. The
workaround is to start a solo session first and join from inside it.

**Not yet diagnosed.** `tests/session.gd` and `tests/two_peers.gd` already drive ENet host/join, and
they pass — so whatever is broken is either on a path those do not take (the desk's Join button,
rather than `Net.join` called directly) or is about what the level does once joined.

**Gate:** a headless suite that starts a host in one process and, in a second, presses **Join** on
the desk's session screen with an address typed into the field, and lands in the host's world with
both machines flying. It must fail against today's code. Plus the same by hand, two windows.

**What was found (2026-09-15).** The gate was built first — `tests/desk_join.gd`, which is the
joiner itself and starts a child host with `--host=PORT --report=1`. **The reported fault did not
reproduce.** From a cold main menu, with nothing played solo, typing an address and pressing Join
lands in the host's world; the host's own report line names two sync clients and draws two pilots.
So the desk-to-session path is sound, and `tests/session.gd` / `two_peers.gd` had left exactly this
one path uncovered, which is why it was worth building anyway.

**What WAS broken, and is fixed:** the address field could only ever mean an address. `DeskRoom`
handed its text to `Net.join`, whose port argument defaults, so **the only host reachable from the
main menu was one on 7788**, and a player typing the natural `192.168.1.50:7788` passed that whole
string to `create_client` as a host name. ENet returns OK for a name that does not resolve and then
sits in CONNECTION_CONNECTING for ever, so the only thing that ever said no was the desk's
ten-second timeout, with the thoroughly misleading "Nothing is listening there." That is a very
good candidate for what was actually being seen. The field now reads `ADDRESS[:PORT]` through
`LaunchOrder.read_address`, the same parser `--join=` has always used — one parser, two doors — and
a port that is not a port is said at once instead of waited out. RED proved by reverting the desk to
`Net.join(detail)`: both end-to-end checks fail, 84 s of timeouts.

**Still to do on this item, and why it is not closed:**
- The same by hand, two windows, with a real IP rather than the loopback. Only a person can do that.
- If the fault persists for the user after this, the next suspects are the **windowed press path**
  (mouse ray through `GlassPointer`, not the button's signal) and a **firewall on the host**, neither
  of which a headless suite touches. Ask what the address bar said before the ten seconds ran out.

## 2. Lobby level with a briefing room — DONE (all of 2a..2d, `lane/lobby`, merged 2026-09-15)

> "let's make a lobby level, where players join, players still need to be able to join a game that is
> already in progress, but let's make sure we have a lobby, that has a briefing room where all
> players load, they should be able move forward/back/strafe-left/strafe-right with 'wasd' and the
> left little joystick on the left vr controller, and rotate with the joystick on the right
> controller (or use the mouse in 2d). there should be some joysticks and buttons (that don't do
> anything) in the lobby so players can prepare before loading into the level."

**THE SEGWAY, decided by the user on 2026-09-15**, when the note here said walking was the
substantial part:

> "just put them in an invisible vehicle called a segway that way they can move around and they are
> still in a vehicle (but just make it a sphere at their feet."

That settles the hard part and settles it well. This game has no walking and every rig is seated
(`PilotRig.sit_in`); building a walking player would mean a second kind of thing that moves, a
second thing to replicate, and a second thing for every system that asks "what am I in" to get
wrong. A segway is a VEHICLE, so it is already replicated, already has a seat, already appears in
the crew manifest, already rides the rollback, and already answers every question the game knows
how to ask. The lobby then needs a room and some props, not a new player model.

**What it costs, checked before starting.** A kind is C++: `kKind*` and the shape table live in
`ashiato-gd/src/cockpit/cockpit_world.cpp`, and `Sim.Kind` says so ("matching kKind* in
cockpit_world.cpp"). So 2a is a C++ change and a rebuild of both DLLs. Checked 2026-09-15: the
`Z:	anagra\godot-cpp` share the build needs is reachable and both DLLs are in
`cockpit/addons/ashiato/bin/`. There are 21 kinds and the wire gives a kind 5 bits with
`NO_KIND = 31`, so a 22nd costs no wire change — worth confirming in the build, not assuming.

**The movement model is the one open question.** `Model::Hover` gives full authority at a standstill,
which is exactly the strafe that is wanted, but it flies. `Model::Car` stays on the ground and
cannot strafe. So a segway is likely its own small model: horizontal velocity straight from the
input, yaw from the rotate axis, no pitch or roll authority, gravity and a sphere resting on the
ground. Decide it by reading `Model::Car`'s integration before writing a third thing.

### 2a. The segway kind — DONE
C++ `kKindSegway` with a sphere shape and one seat at standing eye height, its movement model, both
DLLs rebuilt and verified (`DrivingWorld` present in both, per `running_a_team_here.md`), plus
`Sim.Kind.SEGWAY` and an invisible `craft_segway.tscn`.
**Gate:** an addon-level suite that spawns one, drives it with an input frame and holds that it
moves horizontally, stays on the ground, yaws, and does not pitch or roll; `tests/air.gd`-style.

**Built 2026-09-15.** `kKindSegway = 21` (`kKindCount` 22, still inside the wire's 5 bits with
`kNoKindWanted` at 31), `segway_shape()` — a 0.35 m sphere, 85 kg, one Pilot seat at the bottom so
the tracker's eye height lands at standing height — and `Model::Segway` with `ride_segway`.
`Sim.Kind.SEGWAY` beside it. Both DLLs rebuilt, single and double, each carrying `DrivingWorld`.

**Why it is its own model, which was the one open question.** `Hover` gives the strafe and flies;
`Car` stays down and steers instead of strafing. Neither stops when you let go, because a person does
not coast — so the segway COMMANDS A VELOCITY rather than applying thrust against drag, closing on
the asked-for horizontal velocity with a clamped step, exactly as `command_rate` closes on a rate.
Pitch and roll are pinned at zero at full authority whether or not anybody is aboard, and there is no
authority at all off the ground.

**Measured (`tests/segway.gd`, a bare `CockpitWorld` with a floor):** walks forward, back and both
ways sideways at 3.01 m/s against the 3.2 asked for, with 0.00 m of drift on every one; 3.18 m/s
walking to 0.00 m/s a second after the stick is let go; worst lean 0.000 rad and highest 0.35 m from
a 0.35 m start, driven with pitch, roll, rudder AND full throttle at once.

**The RED is kept rather than performed.** Breaking this would mean editing C++ and rebuilding twice,
and the proof would vanish with the revert — so the contrast is a section instead. The same drive on
the same floor given a POD (`Model::Hover`, which is what `model_of` would have defaulted a segway to)
climbs to 1.79 m, leans 97.7 degrees and is still doing 19.99 m/s a second after release. If a change
ever makes a segway hover, section 4 goes red; if it makes the suite toothless, section 5 does.

### 2b. Driving it from the desk and the headset — DONE except the mouse
WASD and the left stick to move, right stick or mouse to turn, through the rig's existing binding
tables so it is a control like any other. **Item 0 applies hardest here**: the desk path is the one
that must work first, because it is the one a suite can press.
**Gate:** a suite that drives the rig's own seams and reads the pose back.

**Almost nothing had to be built, which is the segway design paying off.** W and S are already
`pitch_down` and `pitch_up`, A is `roll_left`, Q and E are the rudder, and the global headset
bindings already give the left stick pitch and roll and the right stick rudder — because that is the
arrangement every stick-and-throttle setup uses. A segway reads pitch as ahead, roll as sideways and
rudder as turn, so the user's "left joystick to move, right to rotate" was true before it was asked
for.

**One key was taken: D.** It has been `spot` — the red boxes round distant aircraft — since long
before there was anything to walk, and `roll_right` lives on the arrow key alone. Rebinding it would
have changed what every pilot's keyboard does to fix what a person standing in a room needs, so a
segway LAYS A LAYER over the desk keys instead, the way a hand holding a control lays one over the
global set. `PilotRig.reading_a_segway()` is the single predicate BOTH ends ask — the rig before
letting D strafe, and `FlightLevel` before letting D toggle the boxes — so the key has one owner at a
time and the two cannot disagree.

**Measured (`tests/segway_keys.gd`), keys pressed through the real event queue and read off
`read_controls`:** W → pitch -1.0, S → pitch +1.0, A → roll -1.0, D → roll +1.0, E → rudder 1.0; in
an aeroplane D → roll 0.0 and D is still the spotting key. The headset half is READ off the live
binding table rather than pressed, and the suite says so in as many words — this machine has no
headset, so that is the honest limit.

**Still open: the mouse.** "or use the mouse in 2d" is not built. The desk mouse is the panel pointer
(`GlassPointer`, a ray from the eye through the cursor), so mouse-look would fight it, and the answer
is probably a captured-mouse mode that releases when a panel is aimed at. It wants a decision rather
than a guess, and Q/E turn a segway on the desk meanwhile.

### 2c. The briefing room — DONE (`lane/lobby`, merged 2026-09-15)
The level, spawn points, and the props that do nothing (joysticks and buttons to stand at).
**Gate:** a picture from a player's eye, and a suite that loads the level headless and finds the
props and the spawn points.

**THE DECISION: is the lobby a LEVEL, or a room you visit?** Looked into on 2026-09-15 and not
guessed at, because the two go different ways and one of them is much more work to undo.

What exists today. A **level** is a folder under `levels/` read by `LevelChart` — `island` and
`alpine` — and its `world` field names the ground a flight level stands on. `Net.level` is what the
whole session agrees about: the host writes it on its Steam lobby, the hello says it again, and a
joiner that cannot fly it is refused before it builds anything. A **room**, meanwhile, is just a
scene: `hall.tscn`, `signal_room.tscn`, the marshalling levels. `MarshalRig` is already "a seated
pilot who happens to be standing up", bolted to a post — but nothing about a room is simulated or
replicated, so two players in one would not see each other.

**Recommended: the lobby is a LEVEL**, with a `world` that is a room rather than terrain. Everything
the user asked for then comes from machinery that already exists and is already tested: players join
a session whose level is the lobby, the hello agrees on it, segways replicate because a level runs a
`Sim` world, and "join a game already in progress" is the ordinary join it has always been. A room
would need a second copy of all of that, for one scene.

**And it makes 2d and item 11 the same machinery.** If the lobby is a level, then launching the
briefing into the flight is THE HOST CHANGING THE LEVEL — which is item 11, "make sure that the
server can change the level and the clients correctly load that level and join the game". They
should be built together or at least designed together; building 2d as its own path would be
building item 11 twice.

**What to check before writing any of it:** what `LevelChart.worlds()` will accept, what a level with
no terrain does to `FlightLevel` (which assumes ground, a sky, mist, scenery and a boundary), and
whether `Sim._seat_new_clients` can be told which KIND to seat an arriving player in — it spawns
`Kind.POD` today, and a briefing room wants `Kind.SEGWAY`. That last one is small and is the first
thing to do.

### 2d. Getting there and getting out — DONE (`lane/lobby`, merged 2026-09-15)
Main menu into the lobby, lobby into the flight level, and **joining a game already in progress
still works** — which is the part most easily broken by putting a room in front of the world.
**Gate:** extend `tests/desk_join.gd`: a joiner arriving while the host is already flying must still
land in the host's world, not in the lobby.

## 3. Steam join-by-code always says no game has that code — CLOSED, and it WAS the reported sentence

> "steam session seem to work, but joining by code doesn't it always says there is no game at that
> code, look online and try to fix this."

The message is `Net._check_the_lobby`'s "No game has the code %s", which means the filtered search
came back empty. `tests/steam_probe.gd` measured a lobby found by its code in 186 ms on 2026-09-14,
so something has changed or the probe does not take the real path. Two accounts on two machines are
needed to be sure; what can be done from one is to re-run the probe and read what Steam answers.

**Gate:** whatever part of it a single Steam account can prove, plus a written note of what only two
machines can.

**CLOSED 2026-09-16, and the correction is the user's:** *"the host has left the game is what i was
seeing i think i got the words wrong, maybe `getLobbyOwner` isn't getting set correctly?"*

So the sentence on screen was **"The host has left that game"**, not "no game has that code" — and
that is exactly what `lane/steamcode` diagnosed before knowing it. `Steam.getLobbyOwner` returns 0 to
a machine that is not a member of the lobby, and a search result is by definition a lobby you have not
joined, so `Net._what_is_wrong_with` refused EVERY result it was ever handed. The user's guess is the
finding: `getLobbyOwner` is not "not getting set correctly", it is **not answerable from outside the
lobby at all**, and asking it there is the bug. Nothing about the code, the filter or the search was
ever wrong.

**This is why the reported wording matters more than the reported symptom.** Half a day went into
re-running the code search because "no game has that code" named a different function. Ask for the
sentence verbatim next time — there are two refusals a join can print and they have different causes.

**What `lane/steamcode` found (2026-09-15).** `Net._what_is_wrong_with` asked "is this lobby still
owned by the host that wrote itself down on it?" of a SEARCH RESULT, before entering. **Steam's
`getLobbyOwner` answers 0 to a machine that is not in the lobby**, so the comparison was "0" against a
17-digit Steam id and **every lobby a search ever found was refused** -- a typed code turned away the
instant its search succeeded, and every row of the games list carrying "The host has left that game."
where its JOIN should have been.

**Proved from one account**, which is the part worth keeping: App ID 480 is shared, so an unfiltered
search returns fifty strangers' lobbies -- the exact shape a joiner's search finds. Of those fifty,
50 gave a member limit, 50 a member count, 44 their lobby data and **0 gave an owner**, reproduced on
a second run. The fix moves that one question to `_on_entered`, where this machine is a member, which
is where an invite has always been checked. The gate was built first: `PaperLobbyDirectory.owner` now
answers 0 for a lobby we are not in, as Steam does, which read RED on 22 checks of `steam_join` and 7
of `code_pad`.

**AND IT IS NOT THE USER'S SENTENCE, which the lane was right to refuse to claim.** "No game has the
code" needs the search to come back EMPTY; this bug needs it to have SUCCEEDED. They cannot be the
same failure. **So the item stays open on that point**, and the two-machine run in
`cockpit/docs/crew.md` ("Joining over Steam on two machines") is the only thing that can close it -- it starts at "check the two
`STEAM_ID=` lines differ" and decodes each sentence the joiner might see.

**A first-class negative: two processes on one machine cannot test a join at all.** Both report the
same Steam id; membership is per USER, not per process, so the joiner is never a stranger to its own
lobby and the socket to itself never connects. That is precisely why this bug shipped green, and it
means a join tested that way can never succeed whatever the code does. **If the user was testing with
two instances on one account, that is the likeliest account of what they saw** -- and it is a test
that cannot work rather than a fault in the game.

**Two numbers now on record**, neither previously anywhere: lobby data reaches the matchmaking servers
at **~1.7 s** (nothing at 371 ms, the whole lobby arriving at once at 1717 ms), and **two lobby
searches asked together leave only the later one**.

**Two follow-ups carried out of that lane's learnings, so they do not sit only there:**
- `Net.build()` reads "unknown", which makes the build check between a host and a joiner **vacuous**.
  Worth its own item; a joiner a release behind is currently not refused for it.
- A browse abandoned by a code search **leaves the games list empty for ever**. One line, but it wants
  its own `code_pad` check rather than a guess.

## 4. Minigun on the fighter, cycled with the missiles — DONE (`lane/weapons`, merged 2026-09-16 at `c82da6cf`), and 16 with it

> "the fighter plane with missiles should have a minigun on the front and selecting is one of the
> options cycling through, guns, heat seeker, radar missile."

## 5. Client-held machine guns spin — DONE (`lane/guns`, merged 2026-09-15)

> "in multiplayer, when a client player holds on to the machine guns they spin for a unknown reason,
> they don't work properly, but they do work for the server."

An authority bug, almost certainly: the client is predicting a mount it does not own, or the
server's answer and the local hold disagree every tick.

## 6. Boat steering wheels are not synced — DONE (`lane/guns`, merged 2026-09-15)

> "steering wheels are not synced in network boats, both steering wheels should be able to control
> the boat (and that works) but i don't see the other players inputs in my wheel if i'm not holding
> it."

The wheel's *effect* replicates; the wheel's *pose* does not.

## 7. Audit every craft's synced values — DONE as a SUITE (`lane/guns`, merged 2026-09-15)

> "do a general audit of craft and their synced values, you should make sure that they work as if
> they are linked. Rudders should move together, buttons, switches. The arm switch in the fighter
> only syncs when released, not while being moved."

5 and 6 are instances of this. Do them first, then make the audit a **suite** that walks every
craft's controls rather than a one-off read-through, or it will rot.

## 8. Controls that make no sense for the craft — DONE (`lane/sense`, 2026-09-16)

> "make sure the controls in craft make sense, the boat has 'flaps' which doesn't make sense."

## 9. A builder level, and cockpit definitions as JSON — DONE (`lane/item9-final`, 2026-09-16)

> "Build a special level that is ONLY for modifying and saving cockpit definitions, we should also
> move cockpit definitions into json files so we can modify them each station type should have a
> json object that has all the data with position, rotation, and settings. The "builder" level
> allows us to configure and save new ones (or alternate versions). The craft should still determine
> what devices work on it, that way the builder knows what things they have to add (and what won't
> work). Allowed devices should be part of the craft definition."

Large. There is already a builder mode on the clipboard (`BUILD` tab) and a saved-layout path; this
is making the definition itself data, which is the house style (`building_a_game_here.md`, content
is a folder scanned at boot).

Authored packages now supply JSON craft manifests and station layouts for every craft. The
networked builder level parks a selected craft at model origin, gives every native seat a BOARD
action, accepts only the occupant's validated whole-station proposal, relays revisioned layouts,
and saves every seat on the host under a named version. `builder_peers` proves the real three-process
flow, including a true late join, desktop and hand edits, two authority refusals, SAVE, and reload;
`builder_shot` records the craft/stations and readable board without starting XR.

## 10. Network load test with a spawn/despawn page — DONE (`lane/item10-stack`, 2026-09-16)

> "we need a network load test that has a special ipad menu where we can spawn/despawn large amounts
> of planes to test networking and load."

## 11. The server changes the level and clients follow — DONE (`lane/lobby`, merged 2026-09-15)

> "make sure that the server can "change the level" and the clients correctly load that level and
> join the game."

`tests/level_swap.gd` and `level_join.gd` exist; this is about the host *choosing* mid-session.

## 12. Networked music with volume — DONE (`lane/music`, 2026-09-16)

> "I need to be able to play music ... i need to be able to have a music tab where i can play music
> on command (this needs to play for all players correctly synced) (i need to be able to control
> volume as well and that should also be networked so i can fade it in)"

**The tracks are in, 2026-09-15.** `cockpit/music/` holds `lotr.ogg` (38:24), `pirates.ogg` (7:01)
and `ride.ogg` (5:00), copied from `godotgames/music/` where they were left. Godot imported all
three as `AudioStreamOggVorbis` and a probe loaded each and read its length back, so they are
playable resources and not just files in a folder.

**No special data directory is needed.** `cockpit/export_presets.cfg` has
`export_filter="all_resources"` with empty include and exclude filters, which exports every
imported resource in the project — so anything under `res://music/` ships in the PCK, and
`binary_format/embed_pck=true` puts it inside the .exe. That was checked rather than assumed.

**Two things for the user to decide before this is built:**
- **58 MB of audio in git**, 46 MB of it one file. Git keeps every version of a binary for ever and
  this repository has no LFS. If these tracks are final, committing is fine; if they are placeholders
  that will be replaced a few times, each replacement costs another 58 MB of history that cannot be
  removed without a rewrite. Alternatives: Git LFS, or keeping `music/` out of the repo and shipping
  it as a folder beside the .exe with a loader that scans it.
- **Licensing.** The three titles look like commercial soundtrack recordings. Shipping them inside
  the executable is distribution. Worth confirming the rights before release; it changes nothing
  about how the feature is built.

**How it should be built when its turn comes:** the folder is the content, scanned at boot, the file
name the id (CLAUDE.md rule 7), so adding a track is dropping a file in. The host decides what plays
and when — the authority rule — and clients follow; volume rides the same path so a fade is the
host's fade, not each machine's.

## 13. Notifications: who joined, who left — DONE (`lane/session`, merged 2026-09-16 at `6484c6e4`)

> "we need a notification system so we know when users join, leave, or other important things
> happen."

## 14. Grab versus pinch — DONE (`lane/pinch`, merged 2026-09-15)

> "the arm switch in the airplane, some devices should be "grabbable" by the grab button, and others
> should use the trigger button, it's more natural to grab joysticks or wheels and 'pinch' buttons
> and switches."

## 15. Steam name, and changing name and colour in the lobby — DONE (`lane/item15-roster`, 2026-09-16)

> "show the steam username, and provide users the ability to change their name and color in the
> lobby."

Depends on 2.

## 16. Joystick-controlled plane cannons do not fire — CLOSED WITH ITEM 4

> "the cannons in planes that are controlled by joysticks don't seem to work."

Probably the same fault as 5; check before building twice.

## 17. Sync time of day and cloud toggle, not graphics detail — DONE (`lane/session`, merged 2026-09-16 at `f0ad8125`)

> "time of day and other level options are not synced, graphics detail shouldn't be synced, but time
> of day should. Toggle clouds could also be a networked choice."

The line is already drawn in the code: `Finish` is explicitly never replicated ("what one player's
machine can afford to draw is nobody else's business"). Time of day is a level fact and should be
the host's.

## 18. Spawning a vehicle and getting into it, in multiplayer — DONE (`lane/item18-issue`, 2026-09-16)

> "Let's also make it so we can spawn new vehicles and enter them (this doesn't appear to work in
> multiplayer yet)."

The host now prefers an existing free craft and authoritatively issues one only when none
is free. Flight levels register terrain-clear places per kind; rooms register none and the
CRAFT page says why it refused. Issued craft are swept when empty. `tests/issue.gd` proves
the lifecycle in the native replication loop and `tests/craft_peers.gd` proves the real
CRAFT button over ENet, including two simultaneous one-seat issues and lobby refusal text.

## 19. A map tab, and a map MFD — DONE (`lane/item19-map`, 2026-09-16)

> "We need a map tab in the ipad that shows where other players are and helps you find them. We also
> need a mfd that has a map that shows the same information (but it's the only thing it does is show
> a map and shows arrows to other players)"

(Numbered 19 because the ask listed it as 18 after an earlier 18; the order is what matters, not the
number.)

## 20. A director's camera, for recording play sessions — DONE (`lane/camera`, merged 2026-09-16), WITH ONE THING FOR THE USER

Asked for on 2026-09-15:

> "it's very important that I can record my play sessions, so i want the ability to make the
> "desktop" show a different view than what is in the vr headset. I want a floating camera that i
> can position in my cockpit, and grab it with my hand and move it. It should have controls like FOV
> and it's image should be on the desktop screen (and i should be able to fullscreen it as well like
> the other games in this directory). Make the actual system have a button to turn it on and off and
> a red light if it's on, and some fov buttons so i can modify those things by clicking small buttons
> with the pinch gesture we built earlier."

**Six things, and they are not equally hard:**
1. a floating camera object in the cockpit, grabbable and movable by hand;
2. its image on the DESKTOP window, instead of the headset mirror;
3. fullscreen, as the other games here do it;
4. FOV, changed from the object itself;
5. an on/off button with a red light that is lit only while it is on;
6. those buttons worked with the PINCH, which is item 14's other half.

**The hard one is 2, and it is the whole feature.** Today the desktop window is a MIRROR of the
headset's viewport — one camera, drawn once, shown twice. A different view is a SECOND camera and a
second render of the world, which is a second full pass over the scene, and this is the one feature
on the list that deliberately costs frames. The Mobile/PCVR review (agents.md, 2026-09-15) says it in
as many words: "Spectator / desktop mirror: separate cheap viewport or a blit. Do not render a third
full-quality eye for the monitor."

**So it must be off by default and cheap when on** — which is exactly what the user asked for with
the on/off button, and the red light is then not decoration but the thing that says "you are paying
for this". Its viewport wants its own render scale and its own quality, well under the headset's:
the recording is 2D and flat, and 1.0x of a 1080p window is a fraction of two eyes at 1.4x.
`PilotRig.RENDER_SCALE`'s `--render-scale=` note applies.

**What to check before designing:** whether Godot 4.7 will draw a second `Viewport` with its own
`Camera3D` while the root viewport is in XR mode, and what that costs on the Mobile renderer. Neither
is written down here, and the answer decides whether this is a viewport or a `SubViewport` blitted
into the window. Measure it with `tests/scenery_shot.gd`'s GPU timer before building the furniture.

**Depends on 14** for the pinch, and the user's phrase "the pinch gesture we built earlier" should be
checked rather than believed: as of 2026-09-15 item 14 is TODO and the rig has one grab for
everything. If the pinch does not exist yet, 14 comes first or this ships on the grab.

**Gate:** a suite that turns it on, proves the desktop viewport draws a DIFFERENT camera from the
headset's (two poses, two pictures that differ), that the light is lit only while it is on, and that
FOV changes what is drawn; plus a saved picture of the cockpit with the camera in it, and a GPU-timer
A/B of the cost with it on and off.

### What `lane/camera` built, and the two answers that matter (merged 2026-09-16, `d0da4e84`)

All six parts are in. `DirectorCamera` with a `CameraKeypad` on its back — a fist carries it, a
fingertip works its keys, which is item 14's rule at its best case and the reason 20 waited for 14.
`Monitor` draws the second window, `Fullscreen` gives that window its own key, `tests/director.gd` is
forty-three checks in eight sections and every one was proved able to fail by mutation. Pictures 35-38
of 2026-09-15.

**ANSWER 1 — the cost, measured before anything was built.** A second `Viewport` with its own
`Camera3D` sharing the root's `World3D` does draw the live world, and it costs **about two thirds of a
millisecond**. On the RTX 5080 under D3D12 and Mobile, seventy-nine vehicles in the world, root at the
headset's 1.4x, against a 2.05 ms baseline:

| | added to a frame | its own GPU | its own CPU |
|---|---|---|---|
| `sub_1920` | +0.617 ms | 0.740 ms | 0.489 ms |
| `sub_1280` | +0.607 ms | 0.487 ms | 0.478 ms |
| `sub_960` | +0.596 ms | 0.411 ms | 0.473 ms |
| `window_1600` | +0.702 ms | 0.604 ms | 0.490 ms |

**ANSWER 2 — and it contradicts this plan's own spec above.** *"Its viewport wants its own render scale
and its own quality, well under the headset's"* is **WRONG, and the measurement is why.** 960x540 costs
0.596 ms and 1920x1080 costs 0.617: a fiftieth of a millisecond for a ninth of the pixels. The per-pixel
half falls exactly as it should — the second viewport's own GPU timer goes 0.740 to 0.411 — and the
frame does not get faster, **because what it waits on is the CPU half**: a second cull and a second
render list over every vehicle and the whole island, 0.47 to 0.50 ms at every size. So **the feature has
no render-scale knob and a future one would be a knob that does nothing.** Record at 1080p.

The CPU timer is only in the probe because the first numbers did not add up. Had it reported the GPU
alone, "record at 960 and save a third" would have looked like a finding. **That is the general lesson:
a per-pixel measurement of a CPU-bound pass reads as a clean scaling law and is an artefact.**

**[FOR THE USER] The desktop view is a SECOND OS WINDOW, not a replacement for the mirror — and that is
a deviation from what was asked.** The obvious reading of "make the desktop show a different view" is
that the main window stops mirroring the headset. **Godot 4.7 will not do that.** While the root
viewport has `use_xr` on, everything drawn into it — every `CanvasLayer`, every 2D node, every embedded
subwindow — is composited into the EYE buffers, and the desktop is a blit of an eye. A fullscreen
`TextureRect` showing the camera's picture would put that picture *inside the headset, over the
cockpit*. There is no engine call that replaces what the XR blit puts on screen.

A `Window` node is a viewport of its own, drawn as an ordinary non-XR viewport and blitted to its own
OS window, and the root's `use_xr` never touches it. It is also not dearer: 0.702 ms against a
`SubViewport`'s 0.671. So what the player gets is **two windows while recording** — the mirror, and the
one a recorder captures. Point OBS at the second window, or press F11 in it. **If the user wants the
mirror itself replaced, that is an engine change and should be said out loud rather than attempted.**

**Five smaller things the lane left, none of them blocking:**
1. **Somebody in a headset should switch it on and try to frame a shot.** Nothing here can say whether
   a 16 mm key can be hit without looking, whether a thumbnail tally reads as lit at arm's length, or
   whether the beam vanishing as your hand arrives at the keypad feels helpful or broken.
2. **The camera's view has no HUD and no overlay, on purpose** — a recording wants the world, not the
   instrument text. A director's overlay, if ever wanted, is a `CanvasLayer` inside `Monitor`'s window.
3. **`FlightLevel._far()` follows the ROOT viewport's camera**, so a camera pointed a long way from the
   aeroplane may see unbuilt ground. That is the right default — the recording must not decide what the
   world costs — but somebody will notice it and think it is a bug.
4. **Nothing about the camera goes on the wire.** Both parts are `Scope.PILOT` with no channel, so a
   crewmate knows nothing about whether it is recording. If a red light should mean "you are on camera"
   to the rest of the crew, that is a channel and a decision about whose recording it is.
5. **F11 already flies a Cessna.** `PilotRig.desk_keys` binds `KEY_F1 + kind` for every pilotable craft
   and there are enough kinds to reach F11; F is `next seat` and a plain event matches inside a modified
   press, so Shift+F changes seat. Hence no global fullscreen key — which is what was asked for anyway,
   since "fullscreen IT" is about the recording. A later "let us bind it globally too" costs a player an
   aeroplane, and `tests/director.gd` holds that by reading `Fullscreen`'s own method list.

## 21. ATC voice generated on the server and heard by everyone — DONE 2026-09-16

Asked for on 2026-09-15:

> "Since the voice atc didn't make it into the last version of the game, let's try to figure out how
> to fix it and remove anything that just adds chatter the scene, we'll need to generate it on the
> server, and then play it as audio on the voice channel via steam. Figure out how to do this so we
> can use the server's ability to generate the audio file and it will be played on all machines via
> steam voice chat. That way clients don't need to worry about voice gen, only the server."

**Why it did not make the build, and this looks like the whole answer.**
`Headphones.WORKSHOP_MODELS` is `res://../kokoro-gd/models` — a path that climbs OUT of the project.
Nothing above `res://` is in the PCK, so an exported game has no models wherever it looks, and
`KOKORO_MODELS` is an environment variable a player does not have set. `export_filter="all_resources"`
cannot help: it exports resources in the project, and these are neither. The kokoro GDExtension's own
native dependencies (ONNX Runtime) are a second shipping question beside it. **Verify this against an
actual export before building anything** — it is a strong hypothesis, not a measurement.

**The instinct to put generation on the server alone is right** and worth more than the shipping fix:
one machine needs the models, one machine pays the CPU, and every client hears the same words at the
same time instead of eight machines each speaking their own.

**But "via steam voice chat" needs checking before it is designed, and I expect it will not work.**
Steam's voice API (`ISteamUser::GetVoice` / `DecompressVoice`) is built to capture from the local
MICROPHONE and hand you compressed frames; there is no call that injects arbitrary audio into it.
If that holds, the honest route to the same outcome is the one this game already uses for everything
else: **the server sends the generated speech as ordinary session data** on the carrier `Net` already
owns, and each client plays it through `Radio` — the same bus, band-pass and drive the voice uses now.
A few seconds of speech as Opus or Vorbis is a few kilobytes; raw PCM would not be, so it is
compressed before it is sent, and a line that arrives late is dropped rather than queued, because
stale ATC is worse than silence. Clients still need no models and no generation, which is the actual
requirement.

**"Remove anything that just adds chatter"** reads as: keep ATC that means something and delete the
ambient filler. `TowerFrequency` currently picks somebody every fifteen seconds and makes up a line
from what that aircraft is doing. Confirm which half is wanted before deleting — the phrase could
mean "remove the random filler" or "remove everything that is not a real instruction".

**It may take a red suite with it.** `chatter` is one of the two suites red on `main` today (engine
errors from the wire clamp, unrelated to voice); `voice_thread` is the other. Whatever happens here
should say plainly what became of both.

**Gate:** an export that actually speaks, which is the thing that failed; plus a two-peer headless run
where the SERVER generates and the client plays without models present, proving a client needs
neither. And a written note of what was established about Steam voice injection, with the API
reference, so nobody has to find it out twice.

**Built.** Steam voice was confirmed to expose microphone capture/decompression and no arbitrary PCM injection.
The host captures Kokoro on a silent bus, resamples to 8 kHz and encodes standard IMA ADPCM at 4,003.0 bytes/s;
Item 9's bounded `LongTransfer` sends it, and host and clients decode the same bytes onto `Radio`. Ambient
`TowerFrequency` filler is deleted. The real ENet gate generated 45,603 samples on the host and played one clip on
a client pointed at an empty model folder and missing extension. A `-HostVoice` Windows export found its explicitly
packaged executable-side model and printed `VOICE_SAMPLES=28235 CLIP_BYTES=14138` from `--speak-test`.

## 22. The battleship's turret seats work the big guns — DONE, 22a-e (`lane/weapons`, merged 2026-09-16; last at `1de6a9ad`)

**What is on main.** Seats 2 and 3 lay and fire the forward and aft 406 mm turrets with a joystick. A shell
laid at the elevation stop lands 6 km off by the flight (5,962 and 6,020 m), bursts on the sea surface
rather than on the seabed floor, and starts no fire. The fire is PREDICTED through ashiato's own cues: the
gunner sees the shell the tick the trigger is pulled, the server makes that one shell, and at a 16-tick
link a rollback across the fire frame neither doubles nor loses it (asserted since `lane/starve`'s fix; it
was 6 played / 5 withdrawn before). The sight looks LEVEL along the turret's bearing with a range drum,
because a gun laid for 6 km points 11.6° above its target; a mil scale gauges distance by eye (a 270 m
hull at 5 km measured 54.19 mils on the picture against 54.05 true), and SPLASH reports where the
gunner's own shell fell. At a desk the camera follows the turret; in a headset nothing is turned.

**22d, DONE (`b63068b3`): each turret seat is on a 3 m hood over its own turret's axis, fixed to the hull.**
The forward gunner is blind on 42° of a 297° arc (was 140°, all of starboard), the aft gunner on none
(was 48°). A hood rather than the bare roof because an eye on the axis looks straight down the centre
barrel, which would have covered the crosshair for every shot past 3.4 km; at 3 m the sight line clears
the barrel by 0.45 m at the elevation stop, computed in `turret_seats`. TRAIN ◀/▶ tells a gunner looking
away which way the gun is. Pictures 51-52.

**22e, DONE (`1de6a9ad`): the range drum reads the barrel against the world, every drawn frame.** The
battleship ROLLS about ±0.8° at rest (not a list, and the same before 22d), and the drum used to read
elevation against the hull, so beam shots landed +180 m and −88 m off a 2,181 m drum. It now reads the
world elevation, and every drawn frame rather than on the 5 Hz instrument pass: a stale drum was still up
to 70 m out at 6 km while the barrel rolled. Beam shots land −7 m and +3 m; a 6 km shot on a 6,102 m drum
splashed at 6,117 m. Also fixed: every turret's sight drew for whichever camera was active, seated or not.
Picture 53.

**Filed, not built:** a "face the gun" snap-turn for a headset gunner, and a magnified periscope glass
(which would also fix the mil ticks' 5.7 headset px spacing).

Asked for on 2026-09-15:

> "the turret seats on the battleship should be for the big guns and the player should be able to
> shoot them, like large battleship guns they go very far."

**Half of it already exists.** `battleship_shape()` gives the ship four seats: a Pilot and a Copilot
in the pilot house, and **two `Station::Turret` seats**, placed in `Part::Station` boxes at -12.0 and
+46.0 along the hull — fore and aft, where the main turrets belong. So the seats are there and a
player can already sit in them. What is missing is a gun worth sitting behind.

**The gap is ballistics, not plumbing.** Every gun in the game today is a flat-shooting one: muzzle
velocities of 853 and 890 m/s on mounts meant for aircraft, where the shell arrives about when you
pull the trigger and you aim by pointing. A battleship gun is the opposite — you aim by ELEVATION,
the shell climbs and falls for tens of seconds, and the target is usually over the horizon. That is a
different projectile, and probably a different aiming control, rather than a bigger number on an
existing one.

**Depends on** `lane/guns` landing first — same code, and its findings about gun authority are this
item's foundation. No longer depends on item 19.
**Risk:** the prediction, not the ballistics. A shell that is drawn locally and settled remotely is the
easy thing to build and the wrong one.

**THE SHELL IS AN ASHIATO ENTITY, SYNCED AND PREDICTED.** Stated by the user on 2026-09-15:
*"projectiles must be synced and predicted by ashiato."* This is the constraint that decides where the
work happens, so it is written above the rest rather than in a gate.

It rules out the cheap implementation completely. A shell cannot be a local effect that each machine
draws from a "somebody fired" message — with fifteen seconds of flight, two machines integrating their
own copies would disagree about where it lands by the time it got there, and the splash is the
feedback the whole aiming loop is built on. So the shell lives in the simulation like a vehicle does:
the server is the authority, a firing client PREDICTS it and is corrected, and it rides the rollback
with everything else. That also means it must survive a rollback and re-simulation without being fired
twice, which is the thing to write the first failing test against.

**Check what already exists before building a projectile system.** `objects/weapons/` has a shot yard
and ammunition, and `ashiato-gd/addon/tests/` has rounds in flight under loss and reordering
(`crowd_shuffled`, `resim_events`); the guns lane is in that code right now for items 5 and 16.
**This item should not start until that lane has landed**, both because they would collide and because
what it learns about gun authority is exactly what this needs.

**Gate.** A headless suite that fires from a turret seat at a given elevation and bearing and holds
where the shell lands — the point being that the answer is six kilometres away and predictable — and,
because of the constraint above, a two-peer check that **a client's predicted shell and the server's
land in the same place**, and that a rollback does not double-fire or lose one. Plus a picture of a
shell leaving the ship and of the splash at range, since "visible from six kilometres" is a claim only
a picture can settle.

**Questions: all four answered by the user on 2026-09-15.**

1. ~~How far is "very far"?~~ **ANSWERED 2026-09-15: six kilometres.**

   **And that answer decides question 2, which is why it was worth asking first.** Six kilometres is
   INSIDE the island, not across it: the ship has to manoeuvre into range rather than shell the map
   from a corner, and at sea level the horizon from a battleship's bridge is about ten kilometres,
   so **the target is usually visible**. That turns the aiming problem from indirect fire with a
   spotter into direct fire with an elevation aid — much simpler, and it removes the dependency on
   item 19's map.

   **What is still open is what the shell DOES over those six kilometres**, and it is a real choice
   with a real feel attached. Worked out below with no drag, which is close enough to choose by
   (`g` 9.81, range 6000 m, the low-angle solution, since the high-angle one is a mortar):

   | muzzle | elevation to reach 6 km | time of flight | apex | what it feels like |
   |---|---|---|---|---|
   | 853 m/s (today's gun) | 2.3° | **7.0 s** | 61 m | a rifle. Nearly flat; you aim by pointing |
   | 400 m/s | 10.8° | **15.3 s** | 287 m | a naval gun. A visible arc, a wait, a splash |
   | 243 m/s | 45° | **35 s** | 1500 m | a mortar. Enormous lob, very slow shell |

   **Recommend the middle row, about 400 m/s.** Six kilometres in fifteen seconds with a 287 m apex
   is an arc you can watch, a wait long enough that a moving target must be led, and a shell that
   still arrives while anybody cares. The top row would make the big guns behave exactly like the
   aircraft cannons that already exist, which is the one outcome that would make this item pointless;
   the bottom row is thirty-five seconds of waiting per shot.

   A lane may take the recommendation and record it. What it must NOT do is quietly reuse 853 m/s
   because that is what the other guns say.
2. ~~How does the gunner aim?~~ **ANSWERED: "build a sight for them, they can fire and gauge
   distance."**

   So it is direct fire through a SIGHT, which the six-kilometre range already made possible: at that
   distance over water the target is inside the horizon and visible. **No spotter, and no dependency
   on item 19's map.** "Gauge distance" is the design: the sight must let a gunner work out how far
   away something is and set the gun accordingly — the classic answer is a reticle with range marks
   (a stadiametric scale: a ship of known size subtends a known height at a known range), read against
   an elevation the gunner then sets. Fire, watch the fall of shot, correct, fire again. That loop is
   the game in a turret, and it is why the shell's flight time matters so much.

   It also settles the shell-speed question in the table above: **the correction loop needs a flight
   long enough to watch and short enough to bear, which is the 400 m/s row.** At 7 s and a flat 61 m
   arc there is nothing to watch; at 34 s nobody corrects twice.

3. ~~What happens where it lands?~~ **ANSWERED: "big explosion no fire."** Take it literally — no
   `FireFront`, no burning. The splash is the feedback, and it has to be visible from six kilometres
   away or the correction loop does not work, which makes the explosion's SIZE a gameplay number
   rather than a decoration.

4. ~~Two turrets, independently gunned?~~ **ANSWERED: yes.** One gunner each, fore and aft, in the two
   `Station::Turret` seats that already exist.


---

---

# The planning pass, 2026-09-15

Written after 2a and 2b landed, when the user asked for **all the rest** planned up front "so we can
determine if there are any questions before hand", with **no more than two teammates at a time**
implementing, and this session orchestrating rather than building.

Each item below now carries: the APPROACH, what it DEPENDS on, the RISK that could stop it, its GATE,
and any QUESTION that must be answered first. **A question marked [BLOCKING] changes what gets built;
one marked [CHECK] only changes how, and a lane may take the recommended answer and say so.**

## The lane ledger, and how a lane ends

Asked for on 2026-09-15: *"keep track of completed contexts, have them report their learnings, and
then remove them and shut them down."*

**A lane is not finished when its work is merged.** The five steps are **watch, cleanup, learnings,
screenshot, shutdown**, and the canonical version with the failure each one prevents is in
`running_a_team_here.md`, section 1 — read it there. This is the ledger, one row per lane and a tick
per step:

The steps themselves, and the failure each one prevents, are NOT repeated here — a rule kept in two
places is a rule and a copy of it, which `suites.txt` taught this project once already.

| Lane | Items | Watch | Cleanup | Learnings | Screenshot | Shutdown |
|---|---|---|---|---|---|---|
| `steamcode` | 3 | `07b1f71b` | yes | carried to item 3 | **none — predates the rule** | yes |
| `pinch` | 14 | `4521dd05` | yes | carried to items 14 and 20 | **none — predates the rule** | yes |
| `lobby` | 2b..2d, 11 | `5c04105d` | yes | carried to items 13, 15 and 2 | 29-32 | yes |
| `guns` | 5, 6, 7 (16 stays open) | `17c21d9a` | yes | carried to items 4, 16, 22 and the loose list | 33-34 | yes |
| `camera` | 20 | `e2964585` | yes | carried to item 20 and the loose list | 35-38 | yes |

| `sinking` | the island craft falling through the world | `268a045b` | yes, junctions removed first, model confirmed 59 files | carried to the loose list and the user's questions | 44-46 | yes |
| `session` | 17, 13 | `6484c6e4` | yes | carried to items 13, 15 and the loose list | 39-40, 42-43 | yes |

All seven above are closed.

**Nothing is in flight.** Closed on 2026-09-16:

| Lane | Items | Watch | Cleanup | Learnings | Screenshot | Shutdown |
|---|---|---|---|---|---|---|
| `starve` | the input starvation past 125 ms | `34603ad9` | yes, both private sync worktrees removed | carried to the loose list | 48 | yes |
| `weapons` | 4, 16, `hands_on`, 22a-e | `1de6a9ad`, learnings `a236c0f7` | yes, private sync worktree removed | carried to item 22 and the user's questions | 41, 47, 49-53 | yes |

**Fences.** `weapons` owns `ashiato-gd/**` (the only C++ lane) and `cockpit/objects/vehicles/ships/**`.
`session` owns `net.gd`, `cloud_bank.gd`, time of day and `cockpit/ui/menus/**` including
`clipboard_page.gd`. **`sinking` owns nothing until it reports what it found** — read-only until then,
because its fix may land in either of the other two fences and that has to be arranged, not discovered.

### The 2026-09-17 round

A much wider round than the 15th or the 16th, because most of it is modelling, which needs no C++ and
touches no shared file. Closed so far:

| Lane | Work | Watch | Cleanup | Learnings | Screenshot | Shutdown |
|---|---|---|---|---|---|---|
| `planner` | the plan for items 8, 9, 10, 12, 15, 18, 19, 21 | `de67f2ee` | yes | `plan_next.md`, and its questions are recorded as open | none — a paper lane | yes |
| `actuators` | how a gear leg or a nacelle takes time for everybody | `82d9089c` | yes | `cockpit/actuators_research.md`, §3 the recommendation, §3.10 the user's answers | none — a paper lane | yes |
| `upstream` | S-5 to S-11, ten PRs at `ErikGoldman/ashiato-sync` | `bf454cda`, then `5ee8dd56` | yes, `upstream-learn` removed; `sync-temp` kept on purpose for the next ashiato lane | `learnings/2026-09-17-upstream.md` | 70 | yes |
| `sphere` | the priority sphere, C++, 10 km on by default | `5c4b6509`, patch `43906070` | yes | `learnings/2026-09-17-sphere.md` | 73 | yes |
| `craft` | the retrospective: `modelling_here.md`, `learnings/README.md`, the anchoring rule | `063be176` | yes | pruned 2026-09-20 (its lessons are in `modelling_here.md`) | waived, a paper lane | yes |
| `upstream2` | S-6 as PR #11, PR #4's missing test, all eleven green on the author's own CI | `318395f7` | yes, fork probe branches kept on purpose | `learnings/2026-09-17-upstream2.md` | 74 | yes |
| `hangar` | the SKYFRONT hangar from the user's drawing, and a yard to stand it in | `3cdf2fcd` | yes | `learnings/2026-09-17-hangar.md` | `cockpit-hangar-01..10` | yes |
| `hornet` | the F/A-18F remodel, the crew's real eye points, the arresting-hook channel | `dfc37668` | yes | `learnings/2026-09-17-hornet.md` | `cockpit-hornet-54..70` | yes |
| `airbase` | an air base from one JSON file, a tower drawn at last, and the desk throttle | `735e6c84` | yes | `learnings/2026-09-17-airbase.md` | `cockpit-airbase-01..08` | yes |
| `prowler` | the EA-6B, measured three ways and overlaid at the drawing's own scale | `352fbd40` | yes | `learnings/2026-09-17-prowler.md` | `cockpit-prowler-01..06` | yes |

**`sync-temp` is deliberately left standing.** It is the private checkout an ashiato lane branches from,
it takes minutes to recreate, and the next such lane was promised it.

**Screenshot numbers collided five times this round** — 63, 64, 65, 66 and 70 each name two different
pictures, because lanes claimed "the next free number" at the same second. The files are hashed in
`SHA256SUMS.txt` so they stay; the rule is now **`cockpit-<lane>-NN-<what>.png`, numbered per lane**,
which needs no coordination and cannot race. A coordinated version was tried first and dropped, because
a rule that needs the lead in the loop breaks exactly when the lead is busy.

**Still running at the time of writing:** `shell` (the station shell rebuilt, eleven slabs to two),
`skyhawk` (the Cessna 172S and `VehicleView.cabin_room()`), `fleet3` (the Arleigh Burke, after the two
merchant ships landed), and `stress` (the 80 ms craft-count answer).

### What this round cost, and what it bought

**Four false-verdict mechanisms were found in one afternoon**, every one by a lane rather than by the
lead, and every one capable of producing a confident wrong answer from a pipeline that looks green:

1. **A shared per-user log directory.** `run_all.ps1` wrote `$env:TEMP\cockpit_tests\<suite>.log` and
   judged the run by the `RESULT=` line it read back, so two lanes running the same suite name read each
   other's verdicts. A lane was handed a neighbour's `lint FAIL`; the reverse is a bad merge. Fixed in
   `ab17b7c0`, keyed by checkout path.
2. **A stale class cache, reported as somebody else's regression.** The import that registers a new
   `class_name` ran only on a full gate, and `-Only <suite>` is what a lane uses after a rebase. The
   failure names a class that is sitting in the tree, so it reads as a real fault in whoever added it.
   It cost three lanes an hour each and nearly cost a fourth: a twelve-suite verification reported
   `smoke FAIL and_a_gunner_holding_a_gun_gets_none` on the day a lane changed the crew linkage, and the
   cache was the whole of it. Fixed in `310e45db`, with the collision it introduced retried in `da22754a`.
3. **A gate that can run twice in one worktree.** `TaskStop` kills the tracked shell and not the loop
   under it, so a stopped gate keeps writing the same log names — and a lane can read a verdict for a run
   that never happened. Ten stray shells when `lane/airbase` counted. Guarded with a lock in that lane.
4. **A waiter that cannot recognise its own hold.** A script that takes the GPU slot and then calls the
   runner waits for itself for ever, and the log line reads like ordinary patience. Two lanes, thirty-four
   minutes. Not yet fixed — see the carried-forward list.

The common shape is worth more than the four fixes: **the evidence and the thing it judged shared
something.** That is the same rule the team named in `testing_godot_headless.md` this morning — anchor the
check outside the thing it is checking — arriving from the tooling's side rather than the suite's.

## Carried forward: what the finished lanes left behind

Lifecycle step 3 — *"a learnings file is where a lane writes what it knows; the plan is where the next
lane looks."* Everything here came out of a lane that has since been shut down, so this is the only
copy that is anybody's business. Each says which lane, so the learnings file can be read for the
reasoning.

**Against item 3 (Steam), from `lane/steamcode`:**
- **FIXED 2026-09-16:** the public channel is exactly `alpha`; a separate deterministic compatibility
  identity combines the cockpit revision, protocol, and stamped native revision. Missing or mismatched
  compatibility is refused before entry and cannot collapse to `unknown == unknown`.
- **FIXED 2026-09-16:** Steam lobby searches carry owner ids and use its one request slot in order. A
  code lookup supersedes an unanswered browse, then retries the browse; each deadline starts when its
  request owns the slot, and a timed-out request cannot poison later searches.

**Against item 13 (notifications), from `lane/lobby`:**
- **Nothing warns a client that a level change is coming.** It learns when its screen goes away. This
  is item 13's natural FIRST customer — build it against this case rather than against "who joined".

**Against item 2/15 (the lobby's furniture), from `lane/lobby`:**
- **A LEVELS tab on the clipboard**, so a host can return the session to the lobby mid-flight. The
  launch board is in the briefing room only, so today the only way back is MAIN MENU and a fresh
  session. `Net.change_level` already refuses a non-host in words, so the machinery is there.
- **The briefing room is big and bare** — 20 m by 14 m for eight people. Item 15 (names and colours)
  is what gives the wall beside the board something to say.
- **The props do nothing on purpose.** `tests/lobby.gd` §3 fails by design if anybody wires them up,
  which is the intended way to be told.

**Against item 4 and item 16 (weapons), from `lane/guns`:**
- **Item 4 lands on a check that is already waiting.** When the fighter gets a gun, `_fit_the_missiles`
  moves LAUNCH to the lower thumb and `fit.gd`'s `and_nothing_has_taken_that_finger_for_the_missiles`
  runs for the first time on a craft that has both. That is the whole guard; do not re-derive it.
- **`PintleGun.lead`'s re-anchor is deliberately conservative.** If a jittery link is ever seen to
  leave a gun a degree out for longer than that, the honest next step is a history of the belief
  indexed by round trip — a proper Smith predictor — **not a faster blend**, which drags the gun back
  into the swing it has just finished.

**Against the next C++ lane, from `lane/guns`:**
- **FIXED 2026-09-16 (`c82da6cf`, `lane/weapons`): `CrewControls::hands_on` "nobody" is now seven**
  (`kNobodyHandsOn`, `cockpit_components.hpp:290`), the value three bits on the wire can carry, held by
  `crew_cabin`'s "nobody flying reads the same on the server and both crew machines".

**Against every lane, from `lane/guns`, and it is already earning:**
- **A suite written before 2026-09-15 that closes `force_grip` on a switch, a button, a knob, a dial or
  a screen will report a reach fault it does not have.** Item 14 made a fist see only grabbed parts.
  `scenery` was exactly this. Check it first when a suite goes red near a control.

**Against item 20 and whoever flies it, from `lane/camera`:** see item 20 below, which carries its own.

**Loose, and none of them owned:**
- **FIXED 2026-09-16 (`lane/sinking`, `268a045b`): craft sank through the world, because neither world's
  open sea had a floor.** Two bugs: `chatter` left two unflown aircraft in the sky, and anything that went
  into the sea fell for ever. There is now a static floor from −150 m to the wire's −200 m on both worlds
  (`world/seabed.gd`), held by `seabed` and `seabed_alpine`, which need no voice model. The island's open
  sea now sounds 150.0 m deep instead of infinite, which is what alpine already said. The whole story,
  with the rejected −201 m floor, is in `cockpit/agents.md` and `cockpit/docs/world.md`.
  **What the floor does not do:** a test that spawns a craft over water and forgets it no longer trips
  the error gate — the craft just lies on the seabed.
- **`voice_thread` is red on main and has been since at least 2026-09-15**, on
  `the_first_voice_on_returns_within_two_headset_frames_of_any_switch` — the first VOICE on loads the
  325 MB model on the frame and takes 15.1 ms against a 2 ms budget. Same main-only blindness. The fix
  is to load the library off the frame, or to allow the first load its cost and say so.
- **`hitch`'s `the_whole_world_fits_in_a_tick` is a wall-clock budget and has now flaked for three
  separate lanes.** That is the number that makes it worth fixing rather than re-running. The shape of
  the fix is in `running_a_team_here.md`: time the work several times and keep the fastest, since a
  regression still raises the minimum.
- **FIXED 2026-09-17 (`lane/level-cues`): the 564 to 832 ms level reload is hidden by a persistent curtain.** The
  host's revisioned/content-hashed level cue reaches every peer before the change; each machine fades to black, reloads
  beneath it, and reveals only after its local `level_loaded`. The real ENet gate includes 125/175 ms delayed clients
  and one joining during the countdown. The CPU hitch still exists under black; it is no longer a frozen old view.
- **A sky change says nothing on other machines** (`lane/session`): the host's night simply arrives. A
  `sky` notice kind is one entry in `Net.NOTICE_KINDS`, its words, and a read case.
- **Only the latest notice shows**, so two joins in a second show one (`lane/session`). Fix if it is seen.
- **Every `PATIENCE`-frame wait on a child process in `tests/`** is a wait that `--fixed-fps` spends in
  about a second. Two suites have already been moved to the wall clock for it (`sky_peers`,
  `no_vr_flight`); the rest want the same pass before the next real-time delay lands on a session path.
- **Desk mouse-look IS built in code** (`_enter_desktop` captures the mouse; motion turns `_look_yaw` while
  no glass is up), correcting the earlier "unbuilt". Nobody has moved a real mouse at a window to confirm
  it, because that takes the user's mouse.
- **FIXED 2026-09-16 (`lane/starve`, `34603ad9`): every predicted client past 125 ms one way starved the
  server.** ashiato-sync filled each input packet from the OLDEST unacknowledged frame and cut it silently
  at the 1,200-byte MTU (29 frames of cockpit's then-327-bit input) and then at a 31-frame count, so the
  newest input never left. It hit cockpit, driving and vr alike. The fix is a new ashiato-sync patch that
  sends the newest 8 frames every tick (chosen over a spill into extra packets, which ENet's sequenced
  channel discarded under jitter), held by `input_window`. Link 16 went from 600 of 600 starved frames and
  60 rollbacks to 0 and 11, at 337 B a tick. `cockpit/agents.md`'s "mispredicts are set by the ping" was
  this bug and is corrected.
- **FIXED 2026-09-17: the lead clamp.** Cockpit alone now uses 128-frame input and prediction histories.
  The exact pump at 300/350 ms one way went from 600/600 starved frames to zero, with leads 72/84.
- **FIXED 2026-09-17: `ControlInput` deltas (protocol 9).** A 21-bit mask against sync's acknowledged
  baseline cuts steady flight from 338 to 70.5 B/tick and three moving tracked poses to 264.3 B/tick;
  the 200-aircraft rerun cuts measured upstream from about 44 to 13.0 kB/s per client. A deliberate
  packet loss proves the next packet reconstructs a changed byte without cascading starvation.
- **MEASURED AND REJECTED 2026-09-17: distance priority and per-entity interpolation.** Six 200-craft
  cells at 2/4/8 peers and links 8/16 froze 0.0% of watched ticks, held p99/median step at 1.0, and
  had a one-tick traced update gap against two ticks of prediction. There is no freshness failure for
  either mechanism to improve yet.
- **Cockpit cannot add latency to a real connection.** Everything above was measured in two-world
  harnesses. racer has `Network.extra_latency_ms` (`racer/autoload/network.gd`) to copy.
- **The left trigger brakes before a pinch lands** (`lane/pinch`).

## Next items asked for on 2026-09-17 (not yet dispatched)

- **Timed actuators: gear, nacelles, fold, hook and doors that take time, seen alike by everybody.** Researched in
  `cockpit/actuators_research.md` (recommendation §3, the user's answers §3.10). Replicate the command plus the frame
  it started on, and derive position in the simulation. Travel time is an adjustable per-kind, per-channel number
  (0 = instant; 5 s gear is a placeholder). Linear travel, no curves yet. Nacelles chase the lever at a fixed rate.
  Loaded and spawned craft arrive settled. C++; it follows `lane/sphere` and `lane/hornet`'s C++ commits. First
  migration step: carry the nacelle command as a full byte (§2.4).
- **Display devices: cockpit parts that only read a value and show it.** Start with gear position, flap position,
  airspeed and altitude. No control, no channel write, no grab. Fittable in the builder like any part. Wants the
  actuator work to expose gear and flap position, not only the command. Check what `FlightPage` and `MfdPage` already
  draw before designing, so a display device reuses what reads those values rather than duplicating it.
- **A half-spread fold stops a take-off:** agreed, deliberately deferred.
- **Response curves for actuator travel and its physics effects:** agreed, deliberately deferred.
- **The F/A-18F's arresting-wire trap:** approved as its own C++ lane after `lane/hornet`; brief in that lane's
  learnings. Its headline is already written: anchor the catch on **where the aircraft physically stopped** against an
  MK 7's ~100 m run-out, never on the arrestor reporting that it arrested, and judge rest in the moving deck's true
  point velocity (0.278 m/s) rather than its plan-only turn (0.475).

### Found by the 2026-09-17 round and not taken

Each was found by a lane that deliberately did not fix it, because it was outside that lane's craft.

- **A desk cannot CLOSE a throttle.** Shift opens the lever and no key shuts it, where a headset's thumbstick pushes
  both ways. One key and one `DESK_KEYS` row — but it touches the clipboard legend and `docs.gd`, and `J` for the gear
  and `T` for the hook have just landed, so it is a decision about the desk's key layout rather than a bug fix.
  Named at the head of `cockpit/tests/airbase_taxi.gd` (`lane/airbase`).
- **The builder's build box reaches outside the aeroplane.** Its front face is at −0.92 m, and that face is outside the
  drawn machine on **nine of the thirty-five enclosed stations** — the AC-130's gunners by 2.12 m. A player can place a
  control outside the craft they are sitting in and nothing refuses it. `lane/shell` found it and left it; its own lane.
- **Nine — now ten — craft draw nothing that encloses their crew.** The user has ruled these are bugs to fix. The tenth
  arrived today: `lane/hornet` re-modelled the F/A-18's canopy from a `CapsuleMesh`, closed by construction, into a
  strip of quads with no caps or bottom, so nothing closed holds its pilot. **Re-modelling a part can silently change
  what it is, not just how it looks.** The canopy-height check still holds the fighter.
- **`CockpitShell`'s floor is a fixed 0.60 m and wants deriving from `cabin_room()`**, clamped below by the 45 cm
  shoulders the class documents. Two footwells 1.10 m apart leave a 0.50 m see-through strip on the centreline. The
  derivation was not possible when the shell landed because `cabin_room()` was not yet on main; it is now.
- **A waiter cannot recognise its own GPU hold.** A script that takes the slot and then calls `run_all.ps1` waits for
  itself for ever, and the log line reads like ordinary patience. Two lanes, thirty-four minutes, one missing concept.
  `gate_run.ps1 -Suite` is immune because it delegates without writing a hold.
- **`station_shot` prints no `RESULT=`**, so `gate_run.ps1 -Probe station_shot` reports NO RESULT; and `-Extra` does
  not reach a probe past the bare `--`. Both `lane/shell`'s, both in the wrapper rather than the probe.
- **`hitch` fails on main**, and worse than in a lane: 0.655 ms median against a lane's 0.602, both against a 0.55
  allowance and an 8.33 ms frame budget. A tight regression threshold rather than a real-time risk, but main being
  slower than a lane is a real signal on a day that landed a priority sphere, an air base, a hangar and two airframes.
  **Measure it on a quiet machine before touching it.**
- **A floating flight-stick boot.** With the console gone a stick's boot sits ~0.68 m above the floor with nothing under
  it. The honest fix is a control drawing its own stalk, which belongs to `VehicleControl` and not to the shell.

## Waiting on the user

Neither blocks a lane. Both came out of `lane/sinking`, and the floor it built answers neither.

1. **What should ditching do?** Aircraft feel no water at all: the airliner went through the surface at
   27.5 m/s without slowing, and every aircraft kind sinks to the floor. Float, break up, slow hard, or be
   removed?
2. **What happens to a player whose craft comes to rest on the seabed?** They sit at −150 m under the sea
   with nothing to tell them and no way up but the next-craft button. Put back somewhere, told, or left?
3. **Should a battleship roll ±0.8° at rest?** It rolls continuously between about −0.8° and +0.8° over
   tens of seconds, trim within ±0.35°, identical before and after the turret hoods. Most likely the wind
   sea boats are meant to feel (ocean C1), but whether a 45,000-tonne ship should feel it that much is yours.
4. **Should the big guns be stabilised to the vertical,** as real naval guns were? Today the gun lays
   relative to the rolling hull and the drum follows the roll (22e), so a gunner fires on the roll.
   Stabilising the gun itself is a design change.

**Six more, recorded 2026-09-17, from `plan_next.md`.** Asked before items 9, 12, 15, 18 and 19 were built, and
the builds went ahead without answers. Each now asks whether the built behaviour is right. The full wording, the
recommendations, and what is to be checked on main are in `plan_next.md`, "Questions for the user — OPEN".

5. **[9]** Are builder cockpits used in flight sessions only once committed to the repo? *Recommended: yes.*
6. **[9]** May the builder move or add seats? *Recommended: no.*
7. **[12]** When the host plays music, does everybody hear it, with a per-player MUSIC switch? *Recommended: yes.*
8. **[15]** Should Steam start at launch just to read a player's name? *Recommended: no.*
9. **[19]** Is the map screen fitted by default in pilot stations where there is room? *Recommended: yes.*
10. **[18]** What was pressed when spawning a vehicle "did not work", and what did the board say, word for word?
    Now built: does the case the user saw work?

## The batches, two lanes at a time

Ordered so nothing waits on the other lane, and so the two riskiest pieces (9 and 20) are never in
flight together.

**Batch A - the authority bugs, as one job. DONE 2026-09-15** (`lane/guns`), except 16, which is
blocked on the user — see below. 5, 6 and 7 are closed and 7's audit is a suite (`crew_sync`).

**Batch B - the cockpit's contents, as one job.** Items **9 then 8**. 8 ("the boat has flaps") is a
symptom of what 9 fixes: which controls a craft is fitted with becomes data, and the boat's
definition simply does not list flaps. Doing 8 first would be hand-patching a table that 9 replaces.

**Batch C - the session's shared state.** Items **17, 12, 13**. All three are "the host decides and
everyone follows", all three ride the same path, none touches the simulation.

**Batch D - the iPad pages.** Items **19, 10**. Both are clipboard pages over data that already
exists; 19 wants an MFD besides.

**Batch E - hands and cameras. DONE** — 14 on 2026-09-15 (`lane/pinch`), 20 on 2026-09-16
(`lane/camera`). The order was right: 20's keypad is 14's rule at its best case.

**Batch F - the lobby's furniture.** Items **15, 18**. Both want the lobby finished first.

**Batch G - the big guns.** Item **22**, added 2026-09-15. Its own lane: 6 km ballistics, a sight, an
explosion, two independent turrets, and projectiles synced and predicted by ashiato, which makes it
the C++ lane. It also carries `lane/guns`'s `CrewControls::hands_on` one-liner, because it is already
rebuilding the extension.

**Last: 21**, the ATC voice, because its first step is an export and a finding, not a feature.

---

## The next round is planned in `plan_next.md`

**Read `cockpit/plan_next.md` before dispatching anything for items 8, 9, 10, 12, 15, 18, 19 or 21.** It was
written on 2026-09-16 from the code, not from this file, and it changes the order proposed below in six places:
8 goes first and does not wait for 9; 10 is a C++ lane (per-craft autopilot altitude); 18 is a missing
feature and also C++, so it cannot fly beside 10; 9 builds a long-message mechanism in `net.gd` that 21
reuses; and 19 wants 9's craft definitions and 15's colours. It carries the fence table, the C++ brief, the
load-test design with its failure conditions, a dispatch section per item, and five questions for the user,
each with a recommendation. The first dispatch it proposes is **10 + 8 + 9's design step**.

## What is next (2026-09-16)

**Closed:** 0 (standing), 1, 2 (all of a..d), 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22.
**Blocked on the user:** nothing.
**Open:** none. **In flight:** nothing. The numbered roadmap is complete.

**Item 16 is DECIDED, by team-lead rather than by asking, under the user's standing preference to
take the recommendation unless the choice has large ramifications. It does not — it is a choice
between doing item 4 and scoping a device layer, and only one of those matches what is on disk.**
*"joystick controlled planes cannons don't fire."* `lane/guns` could not reproduce it and found that
the two readings want opposite work:
1. **The fighter has no gun yet**, so a trigger that does nothing is item 4 and not a bug at all; or
2. **a physical joystick's button is not being read.** `Input.get_joy_axis` appears exactly once in the
   whole project, inside a TODO. There is no joystick-device support to be broken.

**Taken: (1).** `lane/guns` could not reproduce a failure because there is nothing to fail: the
fighter has no gun, so its trigger is bound to LAUNCH and firing a cannon is not a thing the craft can
do yet. **Item 16 is therefore item 4, and closes when item 4 ships.** If the user meant a physical
joystick, that is a device layer and a new item, and they will say so when a gun appears and their
stick still does nothing — which is a cheaper way to find out than scoping it blind.

The evidence for (1) over (2): `Input.get_joy_axis` appears exactly ONCE in the whole project, inside
a TODO. A feature that is not built cannot have regressed, and a user reporting a regression is far
more likely to be describing the craft than the device.

**Proposed next dispatch (2026-09-16, after items 4, 13, 17 and 22 closed): 10 beside 9.**
- **10, the 200-plane network load test**, first, because the user asked for it by name and because it is
  newly honest: until `lane/starve`'s fix every predicted client past 125 ms starved the server, so a load
  test run earlier would have measured that bug. It owns `net.gd`'s load paths and one clipboard page.
- **9, the builder level and cockpit definitions as JSON**, beside it, because the two barely share a
  file: 9 lives in `cockpit_station`/`cockpit_layout`, a level and C++ shape tables, and 10 in the network
  and a page. 9 is the riskiest item left, so it starts with its design. **8 follows 9**, as planned.
- **Then 12 and 19**, which both want clipboard pages, so not together and not beside 10's page.
- **Then 15 + 18**, the lobby's furniture, and **21** last.
- **The clipboard is the contested surface for nearly everything left.** Whichever lane holds a page on
  it holds `clipboard_page.gd`; the other asks.

## Item by item

### 4. Minigun on the fighter, cycled with the missiles
**Approach.** The plane already has weapon stations, a master arm and a `weapon_station` key, and a
gun is already something the game fires (turrets, `fire_yard.gd`). So this is most likely "a gun
becomes a selectable station" rather than a new weapon system.
**Depends on** nothing. **Risk:** if a nose gun is not expressible as a station in the C++ weapon
table this becomes a simulation change, a different size of job. Establish that first.
**Gate.** A headless suite that cycles the selector, holds that each of the three is armed in turn
and that firing each does the right thing; and what a CLIENT sees, since guns are where the authority
bugs are (item 5).
**INVESTIGATED 2026-09-15, and it answers its own question.** `loadout_of(kind)` in the C++ says
"The aeroplane and nothing else, for now" - **`kKindPlane` is the only craft with missiles**, so "the
fighter plane with missiles" is the `plane` and there is nothing to ask. Better still, the selector
already exists and already has room: `Channel::Weapon` is fitted to the aeroplane as `Fitted{"weapon",
3}` - three positions - and a `MissileRack` already carries a `type` (heat, radar). The comment on it
is explicit that "THE SELECTOR IS THE STATION", chosen as a bus command like any other switch.

So this is **a gun becoming a third rack type on a selector that already has three positions**, which
is the smallest shape it could have taken. The one thing to establish first is whether a gun can BE a
rack type or whether firing it needs its own path, since a rack launches a missile and a gun does not.
**Recommend:** guns -> heat -> radar in that order on the existing selector, no new control.

### 5. Client-held machine guns spin
**Approach.** Almost certainly authority: the client predicts a mount it does not own, or the server's
answer and the local hold disagree every tick. Read the gun mount's ownership first; the crew-join
work (2026-09-15) has the pattern for "the server alone decides".
**Depends on** nothing. **Risk:** it is C++, and a fix in the wrong place makes the server's guns worse.
**Gate.** Two peers: a client holds a gun and its pose on BOTH machines is held to the same value
within the answer window. RED must be the spin itself.
**Question.** None - reproduce it first; a suite that shows the spin is most of the fix.

### 16. Joystick-controlled plane cannons do not fire
**Approach.** Do this straight after 5 and check whether it is the SAME fault before building twice.
A cannon on a joystick-driven mount is the same ownership question.
**Depends on** 5. **Gate.** As 5.

### 6. Boat steering wheels are not synced
**Approach.** The wheel's EFFECT replicates (the boat turns); its POSE does not, so a player not
holding it sees a still wheel. A replicated-control-position question, not a physics one.
**Depends on** nothing, but shares code with 5 and 16.
**Gate.** Two peers, one holding the wheel, the other reading the wheel's drawn angle.
**[CHECK] Question.** Should a control held by somebody else be VISIBLY held - a hand on it, a colour -
or just move? Recommend: just move, and leave "who is holding it" to item 13 and the CREW page.

### 7. Audit every craft's synced values
**Approach.** Last of the batch, and a SUITE rather than a read-through, which rots the day it is
written: walk every craft, every control, set it on one machine, read it on the other. The user named
one case exactly - "The arm switch in the fighter only syncs when released, not while being moved" -
so the suite must move a control and read it MID-MOVEMENT, not only at rest.
**Depends on** 5, 16, 6 being understood. **Gate.** The suite, RED against whatever those turn out to be.

### 8. Controls that make no sense for the craft
**Approach.** Fold into 9. Fitting becomes data and the boat's flaps disappear because its definition
does not list them.
**Depends on** 9. **[CHECK] Question.** Recommend doing it inside 9 rather than patching first.

### 9. A builder level, and cockpit definitions as JSON — DONE 2026-09-16
**Approach.** The biggest item on the list. A BUILD tab and a saved-layout path already exist, so the
builder LEVEL is partly there; the new thing is the definition itself as data - a JSON per station
type with position, rotation and settings - and **allowed devices as part of the craft definition**,
so the builder knows what may be added and what will not work. House style is on your side: content
is a folder scanned at boot, the folder name is the id, a malformed item disables itself with a message.
**Depends on** nothing, but conflicts with anything else touching a cockpit, so it must not run beside
a lane that edits controls. **Risk:** highest on the list; a half-migrated definition system is worse
than none.
**Gate.** Every craft still builds its cockpit from the new data with nothing moved - compared
numerically against today's positions, not by eye - plus a newly saved definition reloading.
**INVESTIGATED 2026-09-15, and this item is much further along than the ask implies.**
**`CockpitLayout` already exists and already writes a cockpit as JSON**, in very nearly the shape the
user described: `{"craft", "kind", "seat", "units", "controls": [{"part", "name", "label", "channel",
"channel_name", "range", "at", "facing"}]}`, in the seat's own frame, with the units stated in the
file. Its doc block already argues why JSON and not a scene, in the user's own terms: a `.tscn` is
node paths and packed transforms, and this is "a list of parts and where they are... one of those you
can paste into a conversation".

And it already reads as well as writes: `CockpitLayout.read(kind, seat)` and
`CockpitLayout.apply(saved, station, seat)`. `ControlCatalogue` is the list of parts a layout may
name. The builder that produces one is the clipboard's BUILD tab.

**So the item is not "invent a format". It is four smaller things:**
1. move the AUTHORED cockpits out of scenes and into layout files, craft by craft;
2. make **allowed devices part of the craft definition**, which is the genuinely new part - the
   builder must know what may be added to this craft and what will not work on it;
3. a builder LEVEL that exists only for this, rather than the BUILD tab inside a flying game;
4. alternate versions, saved and chosen.

**Recommend:** migrate one craft at a time with the scene path intact until the last one moves, and do
(2) first, because "what may this craft have" is the thing the builder needs before it can refuse
anything.

**ANSWERED 2026-09-15, and it makes the builder a bigger thing than a mode:** *"let's make the builder
level support building multi-user cockpits as well, so that multiple people can join (make this a
target level from the lobby), that way a group of people can decide how to layout a vehicle and build
different stations."*

So the builder is **a LEVEL reached from the lobby, with a session in it**, not a bench on a plinth.
That changes it in three ways worth stating before anybody starts:

1. **It is a networked level**, so it is the same machinery as the lobby - a level a session agrees
   about, players arriving in it, seats. **It should be built after `lane/lobby` lands**, on top of
   what that lane learns, rather than beside it.
2. **Two people building two stations at once** means a layout is per SEAT and two seats are edited
   independently - which `CockpitLayout` already is, since it saves `{"craft", "kind", "seat", ...}`
   with the seat in it. That is a real piece of luck: the format already has the right grain.
3. **Who may move what.** Two people in one cockpit both dragging the same lever is the obvious
   failure. Recommend the same rule the crew page already uses for seats: a station belongs to whoever
   is in its seat, and you may only move the controls of the seat you are sitting in. It is the
   existing authority rule rather than a new one, and it makes "build different stations" literal.

**Gate grows accordingly:** two peers in the builder level, each editing a different seat, both
layouts saved and reloaded, and neither able to move the other's controls.

**Completed.** Every authored station is package JSON; the craft manifest owns its allowlist. The
builder is a normal session level with host-owned BOARD, revisioned/coalesced whole-layout
proposals, late-client snapshots, host SAVE and alternate version names. The final gate used three
real ENet processes: A's rapid desktop edits and B's hand edit converged on host, A and late B;
forged-other-seat and disallowed-part proposals were refused; all four gunship stations saved and
reloaded. The solo render probe also caught and fixed a server/client entity-handle mix-up before
recording the craft and board pictures.

### 10. Network load test with a spawn/despawn page
**Approach.** A clipboard tab that spawns and despawns craft in bulk. `Sim.spawn_vehicle` exists and
the traffic page already adds one at a time.
**Depends on** nothing. **Gate.** A suite that spawns N and despawns them with counts read back off the
simulation, plus a measured frame cost at a few counts.
**ANSWERED 2026-09-15:** *"we have the option for 200 planes in flight at the same time (at different
altitudes so we don't have to worry about collisions too much). I want to stress test the network on
the bulk test."*

So: **200, flying, layered by altitude, and the thing under test is the NETWORK.** That is twice the
recommendation and it changes the item from a frame-cost probe into a wire probe. What it settles:

- **Flying, not parked.** A parked craft is a fixed transform and measures almost nothing; a flying one
  is a body the server integrates and a state every peer must be told about. 200 of them is the load.
- **Layered altitudes are a DESIGN CONSTRAINT, not a convenience.** Collisions would make the test
  measure the physics solver's worst afternoon instead of the wire. Deal them a slice each — a
  separation that is wider than any autopilot's wander, and say in the doc block that the separation is
  what keeps the measurement about the network.
- **The count is a control on the page, not a constant.** Rule 4: the suite asks the page for the count
  rather than keeping a roster beside it. 0, 50, 100 and 200 are then rungs of a ladder rather than
  four hard-coded tests, and the page is the thing a person uses in a real session.

**What to measure, and it is a table rather than a number.** Bytes per second on the wire at 0, 50,
100 and 200 craft, against 2, 4 and 8 peers — because the interesting question is whether cost is
linear in craft, linear in peers, or the product. Alongside it, and each for its own reason:

- **Packet fragmentation.** A per-tick snapshot that outgrows the MTU is the cliff, and it is invisible
  in a bytes-per-second average. Find the count where a tick's largest packet crosses it.
- **Client buffer growth.** `buffer 3` is on the HUD already. A client whose buffer climbs is a client
  losing, and it will do so long before anything looks wrong on screen. Watch it, per peer, over the
  whole run.
- **Rollbacks per second**, also on the HUD. Under load a misprediction is the symptom that arrives
  first.
- **The server's own tick time**, so a red result can be told apart from "the server ran out of CPU and
  the wire was fine".

**Gate.** `tests/bulk_load.gd`: spawn the ladder off the PAGE's own control, counts read back from the
simulation on every peer rather than from the spawner, and the table above printed. Multi-peer, so it
is a `two_peers`-shaped suite rather than a single process. **A pass is not "it did not crash"** — it
is the table, with the fragmentation threshold and the buffer trend named. Write the numbers into
`cockpit/agents.md` the way the other measurements are written.

**Risk.** This is the one item that is allowed to find a NO. If 200 flying craft cannot be replicated
to 8 peers, the deliverable is the count at which it stops working and why — which is worth more than
a feature.

### 12. Networked music with volume
**Approach.** Host decides, clients follow, volume on the same path so a fade is the host's fade.
Folder scanned at boot, file name the id.
**Depends on** the decision below. **Gate.** Two peers hearing the same track at the same offset, and a
fade both follow.
**ANSWERED 2026-09-15:** *"just make sure we can include the ogg file in a data folder, or make it
part of the build process, it doesn't need to be in the repo."*

**So `cockpit/music/` comes OUT of the project and out of git**, and with it the 58 MB and every future
replacement of it. That settles the repository question and changes how the tracks are found.

**What that costs, and it is the thing to get right.** `export_filter="all_resources"` exports what is
in the project; a folder that is not in the project is not exported, so the music can no longer be
found with `load("res://music/...")` and cannot ride inside the PCK. The two honest routes:

1. **A data folder beside the executable**, scanned at boot, loaded with `AudioStreamOggVorbis.load_from_file`
   (which reads from an ordinary path rather than a resource path) - and the export step copies
   `music/` next to `cockpit.exe`. **Recommended.** It is rule 7 exactly: a folder scanned at boot, the
   file name the id, a malformed item disabling itself with a message. It also means a player can drop
   a track in, which the user will want the first time they want a different one.
2. Part of the build: a step that copies the folder into the export directory. Same thing, said from
   the other end; do it as part of (1) rather than instead of it.

**Watch for the trap this game has already met once.** `Headphones.WORKSHOP_MODELS` is
`res://../kokoro-gd/models`, a path that climbs out of the project - which is very likely why the ATC
voice did not ship (item 21). Do not repeat it: a path out of `res://` works in the editor and is
empty in an export. The music folder must be found relative to the EXECUTABLE (`OS.get_executable_path()`),
with the project folder as a fallback for running from the editor, and a suite must prove the
exported shape rather than the editor one.

**The licensing note stands** and is the user's to settle: shipping the three named tracks is
distribution. It changes nothing about how this is built.

### 13. Notifications: who joined, who left
**Approach.** `Net` already emits `peer_joined`, `peer_left` and `session_message`; this is somewhere to
SHOW them, and it should be the same surface the level change uses.
**Depends on** nothing. **Gate.** A suite that joins and leaves a peer and reads the notice back.
**INVESTIGATED.** There is a surface already: `ClipboardPage.say()` writes the line under the tabs,
which is furniture and does not scroll, and the board already carries the join code and the fire
debrief the same way. So a notification is a third line of that kind rather than a new system.
**[CHECK] Question.** Where do they appear? Recommend the board, as a line that does not scroll away,
plus the HUD when it is up - the HUD is off by default, so the board must carry it alone.

### 14. Grab versus pinch
**Approach.** Joysticks and wheels take the GRAB; buttons and switches take the TRIGGER. The rig already
lays per-control binding tables over a global set, so this is a property of a control KIND rather than
a new input path.
**Depends on** nothing. **Blocks 20.**
**Gate.** A suite that closes a hand on each control kind and holds which button worked it.
**THE USER'S SPEC, 2026-09-15, and it is the heart of the item:** *"there is no 'quick tap to grab'
with grip, long press and release will release but quick grab on/off should hold until the grab button
is hit again, this is different with pinch, any release is a full release, this makes working with
switches (which you only want to grab until you have the setting you want) easier."*

**The two gestures differ in their RELEASE, not only in which finger takes hold.** The GRIP latches - a
tap on, a tap off, and the hand stays put in between, which is why holding a lever at 300 kph is not a
hand cramp; that behaviour exists today and does not change. The PINCH never latches: any release is a
full release, because a switch is something you hold only until it is at the setting you want, and a
latched switch leaves your hand stuck to it after every flick. A pinch that quietly inherited the
grip's latch is the likeliest bug here and would feel almost right, which is worse than feeling wrong.

**BUILT 2026-09-15 by `lane/pinch`.** A control declares which finger takes it (`Bind.Take`,
`VehicleControl.taken_by()`, default GRIP); five parts answer PINCH. **The finger that is closing
decides which controls are even CANDIDATES, and only then does nearest choose between them** — the
rejected alternative, which is what the code did, let a fist four centimetres from a stick take a
switch six centimetres away, because millimetres were settling a question a finger had answered. With
both closed the GRIP wins, because an index finger RESTS on a trigger that is also the brake, the gun
and the beam, so a pull can be incidental, while a fist is closed on purpose. The latch stays the
grip's alone.

**The gate caught a fault reading would not have:** the grips are written on the physics clock and the
controls worked on the render one, so a pinch arrived up to a frame before the fist beside it and the
switch was taken before the grip reading caught up — the exact case "the grip wins" exists to settle.
**Two readings that decide one question have to be taken at the same moment.**

**TWO LESSONS FROM THAT LANE WORTH MORE THAN THE FEATURE.**

**A behaviour that is correct BY CONSEQUENCE has no gate.** The pinch already did not latch before the
work started -- but only because `_taking_finger` happened to read the trigger raw, with nothing
holding it there. Every suite was green and the rule was one tidy-up away from being deleted. Writing
the gate is what turned an accident into a guarantee, and the user's REASON went into the doc blocks
beside the rule, because "the pinch does not latch" on its own invites a helpful exception later.

**The latch belongs to the gesture, not to the hand.** The new section found this on its first run:
the latch pinned a hand to WHATEVER it was holding, and a hand pinching a switch is holding something
-- so a fist tapped while pinching latched onto a switch no fist had hold of, then took the stick
beside it when the trigger let go, having been told to do neither.

**And two rules about mutation testing, from the same lane:** routing one finger's read through the
other's is NOT the experiment, because they then share the latch state and the mutation breaks the
wrong check; and a tap must be MEASURED rather than assumed, because `--fixed-fps` runs frames far
faster than the wall clock a tap is timed on, so a "quick" pull can exceed the window and pass for the
wrong reason. The suite reports the pull it made: 1 ms against a 350 ms window.

**INVESTIGATED 2026-09-15: THE PINCH DID NOT EXIST, and was built here.** `Bind`'s own doc says it plainly:
"GRIP is always take-hold-of-this, everywhere, on every control." There is one grab for everything and
no pinch anywhere in the game. The user's "the pinch gesture we built earlier" refers to something that
was discussed rather than built.

**So this item is the pinch's origin, and item 20 waits on it.** The good news is that the machinery is
the right shape already: `Bind` distinguishes TRIGGER from GRIP as separate inputs, and the rig lays a
control's own binding table over the global set - so "which finger takes this control" is a property of
a control KIND, and no new input path is needed. **No question remains; a lane may start.**

### 15. Steam name, and changing name and colour in the lobby
**Approach.** The name comes from Steam; the change is a lobby page. Colour presumably tints the pilot
and anything that names a player.
**INVESTIGATED.** There is no player name anywhere today: `FlightLevel` calls
`pilot.setup(client_id, "Pilot %d" % client_id)`, so everything that names somebody says "Pilot 3".
A name is therefore new all the way through, and the Steam name is simply where the default comes from.
**Depends on** 2. **[CHECK] Question.** Where does the colour show - the pilot model, the CREW page, the
map arrows of item 19, or all three? Recommend all three, from one place.

### 17. Sync time of day and the cloud toggle, not graphics detail
**Approach.** The line is already drawn in the code: `Finish` is explicitly never replicated ("what one
player's machine can afford to draw is nobody else's business"). Time of day is a level fact and should
be the host's.
**INVESTIGATED.** `FlightLevel.choose_time(which)` calls `daylight.show_time(which)` and nothing
else - it is **purely local, with no replicated path at all**, so this is genuinely new work rather
than a fix. `Finish` is explicitly never replicated and must stay that way. The clean shape is the one
the level hello already uses: the host states the time, and a joiner is told it when it arrives as
well as when it changes, or a client that joined late has the wrong sky.
**Depends on** nothing, but it touches `sky.gd`, which `lane/lobby` owns until it lands.
**Gate.** Two peers: host changes the time and the client follows; host changes the finish and the
client does NOT; and a peer that joins AFTER the change arrives with the right sky.
**[CHECK] Question.** "Toggle clouds could also be a networked choice" - is that clouds ON/OFF as a world
fact (recommend: yes, the host's), as distinct from the PLAIN/FINE finish, which stays local?
**TAKEN: yes**, under the standing preference. There was no cloud toggle at all, so it is a new CLOUDS switch under
DAY/EVENING/NIGHT, the host's like the time; the fog clouds (`CloudBank.asked_for`) stay a local affordance.
**BUILT (`lane/session`).** `Net.time_of_day` / `Net.clouds_on`, one predicate `Net.decides_the_sky()`, carried by the
level hello (so a joiner builds under the host's sky) and by a `sky` message said until heard with its count. A joiner's
press is refused in amber on its own board. Per session, not kept like `Net.level`. Gate `tests/sky_peers.gd`: three
machines, red by three mutants, one of which was first masked by a race in the suite and is written up in agents.md
("The host's sky, and every machine's own finish"). Pictures `cockpit-39`, `cockpit-40`.
**Left:** the joiner sees nothing SAY the host changed the sky -- the sky just changes. That is item 13's second customer.

### 18. Spawning a vehicle and getting into it, in multiplayer
**Approach.** The craft page already asks for a kind and the server already decides seating
(`answer_the_joins`). "Does not appear to work in multiplayer" needs reproducing first.
**Depends on** nothing, but it is the same authority question as items 5 and 16, so **read
`lane/guns`'s findings before starting** - "a client asks and the server decides" is exactly what that
lane is in.
**Gate.** Two peers: a client asks for a new craft and ends up in it, proved on both machines.
**BUILT (`lane/item18-issue`, 2026-09-16).** `CockpitWorld` queues an unanswered named-kind
press until jobs finish, chooses the first clear place registered by the level, inserts the
new craft in `issued_`, seats the requester, and launches grounded aircraft. A missing or
blocked place increments the refusal counter and returns `kind_no_issue_place`; the board
says, for example, "This level has no clear place to issue a PLANE." Flight levels register
rows from `Terrain.spawns()` plus a ground apron for segways. Lobby and other indoor levels
deliberately register none. See `plan_next.md` Item 18 for the reproduction table and gates.

### 19. A map tab, and a map MFD
**Approach.** Both draw the same data - where everybody is - so it is one source and two surfaces, the
way the CREW page and the status line already share `Net.aboard()`. The MFD is a device in the cockpit
that shows only the map.
**Depends on** nothing; 15's colour would feed it.
**INVESTIGATED, and the MFD half is largely built.** `MfdPanel` already exists - "a screen with a
ring of keys round the bezel", with the reasoning for why the keys are round the edge rather than on
the glass already written down. So the map MFD is **a page on a panel that exists**, not a new device.
`WorldMap` already files the island by the kilometre, which is where an outline would come from.

**ANSWERED 2026-09-15 with a question back:** *"can you render to a texture and the add overlays based
on xyz position?"* **Yes, and it is the right answer** - better than either option I offered.

**How it works.** A `SubViewport` holds a `Camera3D` looking straight down at the island in orthogonal
projection; its `ViewportTexture` is the map picture, shown on the clipboard page and on the MFD.
Overlays are ordinary `Control` nodes drawn on top, placed by projecting a world XYZ through that same
camera (`Camera3D.unproject_position`), so an aircraft at a world position lands on the right pixel of
the map with no second coordinate system to keep in step. Arrows, headings and colours are then just
things drawn at that point.

**AND IT DOES NOT COST A RENDER A FRAME, which is what makes it affordable.** The terrain does not
move. So the map viewport is rendered ONCE - `SubViewport.UPDATE_ONCE`, the same call
`TouchPanel.redraw` already uses for every panel in the game - and re-rendered only when something
about the WORLD changes: the level, the time of day, the scenery finish. The overlays move every
frame and cost nothing, because they are 2D nodes over a still picture.

That is the difference between a map and item 20's director camera: the camera must draw a live world
every frame and is therefore the one feature that deliberately costs frames; the map draws a dead one
once. **Say that in the doc block**, or somebody will later "fix" the map by making it live.

**What is still to decide, and a lane may decide it:** how much of the world one map shows, and
whether it zooms. Recommend a fixed extent covering the level, with the arrows carrying the detail.

### 20. A director's camera — DONE, and what it left behind
Planned in full above. **Depends on 14** for the pinch, which is now built — so this is unblocked.

**A TRAP `lane/pinch` LEFT FOR THIS ITEM, and it named the exact line.** `PilotRig._point_a_hand`
presses glass with `_read_input(hand, Bind.TRIGGER)`, and `_nearest_takeable` now takes PINCHED
controls from that same raw reading — **and neither knows about the other.** The beam and the pinch They do not collide anywhere in the game today, and nobody had to decide what
happens when they do — **but this item puts small pinched buttons on a floating object that a player
may well hold within arm's reach of a `TouchPanel`**, which is exactly the case that has no rule. Read
`cockpit/docs/craft.md` (the pinch) before designing the camera's buttons, and expect to be the lane that
writes that rule.

**And a second one, smaller:** the left trigger still brakes in the frames BEFORE a pinch lands. The
reservation that stops a held pinch also braking is applied once the control is held, so a pull that
is on its way to a switch is briefly still the brake. Honest, and possibly annoying in a headset; it
is written down rather than guessed at.
**[CHECK] Question.** Already stated: measure whether a second viewport draws while the root is in XR,
and what it costs, before building any furniture.

### 21. ATC voice generated on the server
Planned in full above.
**ANSWERED 2026-09-15:** *"remove the random filler, have a sound panel on the ipad on the server that
generates the audio and plays it to the clients (and the server player)."*

So: **`TowerFrequency`'s once-every-fifteen-seconds invented line goes**, and what replaces it is
deliberate rather than ambient - **a panel on the board, on the HOST, that generates a line and plays
it to everybody including the host's own player.** That is a much smaller and much more testable
feature than an ATC that decides for itself when to speak.

**It also settles the architecture question.** The host is the only machine that generates, which is
what the user asked for, and the trigger is a person pressing a button rather than a timer - so there
is no question of two machines deciding to speak at once. "And the server player" is worth noting: the
host must hear its own line through the same path the clients do, or the host is the one machine that
cannot tell whether it worked.

**The Steam-voice question remains** and must be established before the sending is designed: Steam's
voice API captures from a microphone and, as far as is known, has no call that injects audio. If that
holds, the line goes as ordinary session data on the carrier `Net` already owns and is played through
`Radio` - which meets the requirement, since clients still generate nothing.

**And the shipping bug stands as the first thing to fix:** `Headphones.WORKSHOP_MODELS` is
`res://../kokoro-gd/models`, out of the project and therefore out of every export. See item 12, which
has the same shape and the recommended way round it.

### 22. EVERY SUITE'S SOCKETS THROUGH `TestPorts` — DONE 2026-09-18 (`lane/ports`)

**Built.** All twenty-eight suites that open a socket take their ports from `tests/ports.gd`, and `lint`'s
`and_every_suite_takes_its_ports_from_the_authority` fails a test file that types one anywhere else: a number in the
block the suites ask from (47900-48299) or 7788 outside a `TestPorts` call or the suite's own `FIRST_PORT`/`LAST_PORT`,
a `Net.host()` or `Net.join(address)` with the port left off, or `DEFAULT_PORT` handed to anything that opens a socket.

- **Each checkout gets a place of its own:** one of 96 blocks of 400 between 10,000 and 49,151, picked by a hash of the
  project path and stepping over Steam's 27000-27100. The first version shifted ports up to 51,799. That is inside
  Windows' dynamic range and across **50000-50059, which this machine excludes for UDP**
  (`netsh int ipv4 show excludedportrange protocol=udp`).
- **A held port is found silently and said at once.** `TestPorts.first_free` binds a `PacketPeerUDP` the way ENet does
  and closes it. That prints nothing, where `create_server` on a held port prints `ERROR: Couldn't create an ENet
  host.` and the error gate turns the suite red **even when its hunt then moves on and passes**. That is the error
  `lane/train` saw in `sky_peers` and `lane/boats` saw in `notices`. A suite whose ports are all held prints `PORT BUSY`
  and stops, instead of binding blind and waiting minutes for a peer that has joined somebody else's host.
- **`Net.usual_port`** is what `host()`, a bare `--host`, the desk's "Host a game" and a port-less address use. A player's
  game leaves it at `DEFAULT_PORT`. `session` and `lobby` set it from `TestPorts` before pressing the real button, and
  `desk_screens` names its port. All three had been hosting on 7788 in every lane at once.
- **Child logs are named for the checkout** (`TestPorts.log_for(suite, who)`).

**This item used to say `override.cfg` does not isolate `user://`. That was wrong.** Every lane that wrote one has an
`AppData\Roaming\cockpit_lane_<name>` folder (83 of them on this machine on 2026-09-18). A lane's user data was
already its own. The main checkout and a fresh worktree without the file share `app_userdata\cockpit`, which is why
`log_for` still keys on the checkout.

**AND `notices` WAS NEVER A PORTS FAILURE.** It timed out at 180 s in nearly every lane's gate on 2026-09-18, and in
an isolated lane twice in a row. Its late joiner was started 0.2 s after the launch press and had to connect inside the
3 s warning. **Measured under that night's load, that joiner's engine took 5,577 ms to come up.** It arrived after the
change and loaded the island directly, so it never wrote a cue. The suite then waited 60 s on each of three log lines
that could never come, which is exactly the 180 s deadline. **The joiner is now booted before the press and HELD**:
`--hold-until=<file>` (world/boot.gd) boots it, prints HOLDING, and starts its session only once the file exists. The
suite writes that file only after the press, so the joiner connects during the countdown by construction, not by luck.
`the_late_joiner_connected_after_the_press_and_before_the_change` checks this on the host's own clock: booted and held
in 4,192 ms, connected 5 ms after the press, change at 3,000 ms. **The mutant was red:** releasing the joiner before the
press gave "connected 0 ms after the press" and FAIL. **The old cue check still PASSED under that mutant**, so without
the new check the suite could not tell a late joiner from an early one. 32.7 s under the same load.

**The proof, two checkouts running each suite at the same moment (2026-09-18).** With the old code in two scratch
worktrees, `notices` timed out in both, `sky_peers` failed in one and printed "Couldn't create an ENet host." in the
other, `bulk_peers` failed in both, and `crew_peers` passed (its own BOOT_ERROR walk). With this code in the lane and a
scratch worktree, `notices` (38.0 / 38.1 s), `sky_peers` and `crew_peers` pass in both. `bulk_peers`' sockets hold (both
host pages build 287 vehicles, one per lane), **but its `*_matches_the_in_process_bandwidth` checks fail with two copies
running**: 199 and then 84 kB/s against 246.6 in-process. Six simulating processes at once cannot meet a wall-clock
budget, which makes this a load check like `hitch`, not a collision. It passed alone in this lane at 43.3 s. In
the lane's full gate it failed the bandwidth checks again, and a rerun with 16 Godots live on the machine failed
`b_buffer_does_not_climb` instead. Its sockets held every time. With
every one of its ports held by a dummy listener, `notices` now fails in 10.1 s on `PORT BUSY` and prints no engine error.

**The boundary still stands.** A hash can put two checkouts in one place (96 places; with ten lanes live that is about
a one-in-three chance for some pair), and two runs in one checkout share everything. In both cases `first_free` walks
to a free port or says PORT BUSY, where before it hung.

### 23. EVERY WINDING CHECK IN THE FLEET IS VACUOUS — THREE SUITES, NINE MODELS

**This is the biggest open thing on the board, it reaches work already merged, and it is measured rather than
suspected.** `lane/cooling` flipped one comparison in `Plating.facing` on 2026-09-17, turning **every quad in the
game inwards**, and ran the fleet's winding checks:

| suite | result with the models inside out |
|---|---|
| `merchant_models` | PASS, 0 of 7,902 faces wrong (crude carrier, ferry, **destroyer**) |
| `hangar` | PASS, 0 of 8,072 |
| `prowler` | PASS, 0 of 984 |
| `ship_models` | PASS, 0 of 15,750 (carrier, battleship, gunboat, boat, submarine) |

**Over 31,000 faces across ten models, and not one check noticed.** `hangar`, `prowler`, `ship_models` and
`carrier_shape` printed `RESULT=PASS` outright. `plating.gd` was restored byte-identical afterwards and verified.

**Why.** `Plating.quad` computes its normal as `(corners[2] - corners[0]).cross(corners[1] - corners[0])` — **from the
winding**. `Plating.facing` reorders the corners when they disagree with `out` and **then calls `quad`**, which
recomputes from the *final* winding. `ProwlerAirframe._fan` is more explicit still: on disagreement it swaps two
corners **and** negates the normal together. **So the stored normal is a function of the winding by construction, and
a check asking whether they agree can only ever say yes.** The general form, which is the deepest rule in
`modelling_here.md`: **a check that shares its subject's frame of reference cannot catch the frame being wrong.**

**The Arleigh Burke merged on 2026-09-17 partly on "every face is wound outwards, 1,396 in one draw call".** That
sentence was worth nothing. So is every other one on main.

**The pattern for the repair, from the lane that found it.** What caught it on the cooling tower is **a fact about the
object, not about the file**: *the shell is convex about the tower's axis, so no face of it may look inwards.* For a
hull the equivalent is that a closed hull's faces must point away from an interior point, or that a ray from outside
must meet an outward-facing face first. **Anchored outside the builder, stated as geometry.**

**And the second half matters as much as the first.** `lane/cooling`'s own first replacement asked the *whole* mesh and
went red on **every** mutant including the innocent ones — because a raked column is a prism whose inner face genuinely
looks at the axis, and so does a pond wall from inside. **A check that fires on everything carries as little
information as one that fires on nothing.** So the selection has to exclude the parts the invariant is false for **by
geometry rather than by a label**; a hull has exactly that problem with its superstructure interiors.

**A SECOND, OPPOSITE FINDING IN THE SAME EXPERIMENT.** `merchant_models` was the only suite that went red — and it went
red for the wrong reason. Its three destroyer freeboard checks failed with **the reference values rotated by one
station** (the mutant's "transom" reading the reference's amidships). Reversing a quad's corner order moves no vertex
at all, so **those checks are reading the vertex buffer by INDEX, not by position.** The only thing in the fleet that
noticed a wholesale winding flip noticed it by accident. **It will equally cry wolf on a retessellation that changes
nothing measurable** — and `lane/shell` found a retessellation silently opening a solid the same morning, so it is a
check that will go red on exactly the change it should be quiet about. Fix both together.

**One process note that nearly cost the whole measurement.** The mutant runner **refused twice** before it applied —
first spaces against the file's tabs, then **`plating.gd` is CRLF and the anchor was LF**. `modelling_here.md` lists
five occurrences of that across three lanes, each time the mutant silently not applying while the suite printed PASS.
**On this experiment a silent non-application would have printed the identical all-green output as the real result, and
the opposite conclusion would have been reported with complete confidence.** The "assert the anchor appears exactly
once" rule is the only thing standing between those two outcomes.

### 24. `TownPlan.Roof` HAS NEVER BEEN DRAWN — WP4, "building roof dressing"

**Not one of the four roof kinds is visible, and the enum has been computed and thrown away since `2a733e2b`.**
`FLAT`, `PLANT`, `PITCHED` and `SETBACK` render identically. `TownView.building_custom` packs the kind into
`INSTANCE_CUSTOM.x`; `building.gdshaderinc` reads **`.y`** for a shade hash and **never reads `.x` at all**. The only
roof handling in the file is `albedo = mix(albedo, roof_colour, step(0.5, facade.z))` — one flat colour on any upward
face, the same for all four kinds. `building.gdshader` and `building_fine.gdshader` are four lines each and both just
`#include` it.

**How it was found, on 2026-09-17, and the rule it earned.** `lane/buildings` changed `PITCHED_WIDE`, ran `smoke`, and
shot the after picture. **The caption changed and the picture did not** — `ford` went from *"37 buildings, 37 flat"* to
*"37 buildings, 12 flat, 25 pitched"*, exactly as predicted, over a pixel-for-pixel identical town. **A caption is not
evidence about a shader.** The commit was held rather than landed.

**What is ready for whoever takes it**, all measured rather than calculated — each value compiled and the roofs counted:

| `PITCHED_WIDE` | pitched buildings | where |
|---|---|---|
| 14.0 (today) | **0** | — |
| 16.0 | 54 (14%) | ford 12, hollow 22, brook 20 |
| 20.0 | 98 (26%) | ford 25, hollow 40, brook 33 |

**No city building changes at either value** — inner, eastern and western are byte-identical at 14, 16 and 20, because
a city's narrowest split lot is 21 m. And the threshold has a derivation rather than a taste: **22 − 2 × `LOT_MARGIN_MIN`
= 20.0** is the widest building a split lot in a village can produce as the catalogue stands, so the rule reads *every
split lot in a village gets a pitched roof unless it is over 15 m tall*.

**Pick the threshold with the roofs visible on screen.** The number and the drawing are one decision and separating them
was the mistake; the threshold was deliberately reverted so that whoever draws the roofs chooses it seeing them.

**The defect underneath is worth more than the feature.** The narrowest building the generator can make is **14.02 m**
and the gate is **14.00** — it misses by two centimetres, and there is no measurement behind 14.0: `git log -S` puts it
in the same commit that introduced the roof enum, **whose own body says "building roof dressing (WP4) ... not in this
commit"**. *The gate and the generator were written in the same commit and never compared against each other.* The
gallery now prints the narrowest town building beside the gate on every run so the two cannot drift again unnoticed.

**One thing that should land whoever takes this**: `building.gdshaderinc:38` documents a contract the file does not
honour, **and that comment is why nobody noticed** — a comment describing an unimplemented interface is
indistinguishable from one describing an implemented interface.

**This is a shader on the hot path for 377 buildings drawn by MultiMesh.** It wants a frame-time measurement and the
GPU slot, and probably its own lane.

### 25. THE CRAFT NOBODY OWNS, AND THE CHECKS THAT SHOULD BE FLEET-WIDE

**Ten craft have no lane and no roster entry** (`lane/audit`, 2026-09-17, `cockpit/craft_model_audit.md`): `heli`,
`segway`, `car`, `pod`, `airliner`, `plane`, `mercury`, `uh60`, `submarine`, `boat`. **`heli` and `segway` are the two
worst in the game on both columns.**

- **`segway` reads FLAT 1.00 / HULL 0.99** — its body *is* the collision cuboid to three figures, the highest in the
  fleet. It is in no photograph, no roster and not in the fidelity plan, because `craft_gallery_shot.gd` skips it
  *"deliberately, because it has no visible hull in that level"* — **and it has no visible hull because it has never
  been drawn.** That circularity is the finding: a skip nobody revisits is a craft nobody ever looks at.
- **`heli` carries a `sources.md` that disclaims itself in writing**, saying the package predates the reference-aircraft
  programme and naming `uh60` as its successor. **A cited source that disclaims itself is not a model**, and counting
  source files would have put the fleet's worst craft in its top half.
- **`pod`'s builder doc block promises "a rounded pressure hull and a distinct dark canopy"** and draws an open scaffold
  of struts round empty air. The code and the picture disagree and nothing has ever compared them.

**Do not put a pass/fail threshold on FLAT or HULL.** Nobody has measured what number a good model reads, and **four of
the five faults a person actually found sit in the best half of the table** — osprey 0.05 (no nacelles), chinook 0.09
(no aft pylon), tanker 0.33 (tail detached), pod 0.31 (no hull), tank 0.80 (five road wheels). *Replacing the looking
with the measuring would ship an osprey with no nacelles, green.*

**Two checks exist and should be fleet-wide, each found by one lane and left deliberately narrow:**
1. **`_nothing_floats`** (`lane/buildings`) unions every drawn box and holds the group count to the number of things
   laid, **derived and never typed**. It belongs in `tests/airbase.gd` as a headless check — `structure_pieces` is
   static and needs no rendering device. The aircraft twin is already in `aircraft_fidelity` from `lane/cl415`.
2. **No visible mesh whose path contains `@` or `MeshInstance3D`** (`lane/tank`). It found **four anonymous meshes on
   the first craft it was pointed at**, and the cause is now known: **Godot silently renames a duplicate to
   `@MeshInstance3D@9`**, so `_add_airframe_part` called twice with one name loses the second. **A part built in a
   `for side` loop needs the side in its name.**

---

## Log

- **2026-09-17** — the craft-count sweep in `lane/stress`: about 300 craft at eight players at 83 ms one way, and 91%
  of the host's tick is replication. 22 recorded, and the answer is in agents.md, "HOW MANY CRAFT AT 80 MS".

- **2026-09-16** — 17 built in `lane/session`: the host's time of day and clouds on every machine, the finish on none.
  Full gate 105/105 before the docs. 13 next, against the level change first.

- **2026-09-15** — file written, 0 recorded as a standing rule, 1 taken in hand.
- **2026-09-15** — 22: all four questions answered — a sight the gunner gauges distance with, a big
  explosion and no fire, two independent turrets — and the shell must be **synced and predicted by
  ashiato**, which moves the work into the simulation and puts this after `lane/guns`.
- **2026-09-15** — 22: the user set the range at **6 km**, which makes the guns direct-fire and
  unblocks the aiming question. The open choice is now the shell's speed; 400 m/s recommended.
- **2026-09-15** — 22 added: the battleship's turret seats work the big guns. The seats already
  exist; the gap is ballistics and aiming.
- **2026-09-15** — the default level becomes a RULE rather than a constant: hosting defaults to the
  lobby, flying alone to the island, and an explicit choice on the chart monitor beats both. Same
  shape as `Finish._chosen`. Folded into `lane/lobby`'s item (d).
- **2026-09-15** — the user chose: the lobby IS a level. `lane/lobby` dispatched with 2b..2d, item 11
  folded in, and a no-VR end-to-end gate (start, lobby, island, change seat, change craft) as its
  acceptance test. A planning pass over items 4-21 written above with the blocking questions marked.
- **2026-09-15** — 2c held for one decision: whether the lobby is a level or a room. Recommended a
  level, which makes 2d and item 11 the same machinery. Not started.
- **2026-09-15** — 21 added: server-side ATC voice over the session, at the end of the list.
- **2026-09-15** — 2b done bar the mouse: WASD and the sticks walk a segway, D layered so it
  strafes in one and still spots in a craft. 2c, the briefing room, is next.
- **2026-09-15** — 20 added: a director's camera for recording, at the end of the list.
- **2026-09-15** — 2a DONE: segway kind, shape and model in C++, both DLLs rebuilt,
  `tests/segway.gd` registered. 2b (driving it from the desk) is next.
- **2026-09-15** — 2: the user settled the design (a segway, not walking) and it was split into
  2a..2d. C++ prerequisites checked: godot-cpp share reachable, both DLLs present, 22nd kind fits
  the wire's 5 bits.
- **2026-09-15** — 1: gate built (`tests/desk_join.gd`, registered in `suites.txt`). The reported
  fault did not reproduce; a real one beside it (no port in the address field) was found and fixed.
  Item left open for the two-window check only a person can make.

# The cockpit plan for items 8, 9, 10, 12, 15, 18, 19 and 21 — written 2026-09-16

The plan a fresh team-lead dispatches the rest of `cockpit/plan.md` from. **`plan.md` stays the tracker.** This file
is the how: the order, the fences, the questions, and a section per item that a lane can be sent from. Every file,
function and number here was read in the code on 2026-09-16 at `d3fa7e39`. Where a claim could not be confirmed it is
marked **UNVERIFIED**, with what would confirm it. Nothing was run to write it: no suite, no build, no worktree.

> **STATUS, 2026-09-17: all eight items were built, and this file is now a record to come back to, not a queue.**
> Lanes that ran after it was written (`lane/sense`, `lane/item9-final`, `lane/item10-stack`, `lane/music`,
> `lane/item15-roster`, `lane/item18-issue`, `lane/item19-map`, `lane/radio`) built items 8, 9, 10, 12, 15, 18, 19
> and 21, and `plan.md` marks each DONE. **Nothing below should be dispatched as written.** The order, fences and
> step lists describe the plan those lanes started from, not what they built; read each item's section in `plan.md`,
> its learnings file and the code on main for that.
>
> **What is still open is the user's six questions**, below. The lanes built without the user's answers. Where a
> lane took a recommendation, that is now the game's behaviour and stands until the user says otherwise. **The user
> will come back to these.** When they do, check each against main before changing anything: an answer that differs
> from the recommendation is now a change to built work, not a choice before building it.

---

## THE ONE SCREEN

### What reading the code changed about the proposed order

The proposal was 10 beside 9, then 8 after 9, then 12 and 19, then 15 + 18, then 21. The code agrees with most of it.
It disagrees in six places, and each changes what gets built:

1. **8 does not wait for 9.** A boat shows "flaps" in two places, and 9's JSON replaces neither. The first is the
   throttle's shared thumb table: `ThrottleLever.throttle_bindings()` binds THUMB_HIGH/LOW to `Sim.Channel.FLAPS` on
   every throttle in the game, `seat_wheel.tscn` puts a `ThrottleLever` in the boat, and `PilotRig._bindings_for` →
   `legend()` / `ControllerModel.show_bindings` print "flaps up a notch" without asking whether the craft is fitted with
   flaps. The boat's bus (`default_bus`, `kKindBoat`) has no Flaps. The second is `FlightPage`, which always draws a FLAP
   row and writes "---" on a craft without flaps. **So 8 is a small GDScript lane and goes first.** The part of 8 that
   really is 9's (the BUILD bin offering a flap lever to a boat) moves into 9.
2. **10 is a C++ lane.** The user wants 200 planes at different altitudes. Autopilot waypoints are **per kind**
   (`CockpitWorld::add_ai_waypoint(kind, position)` pushes onto `waypoints_[kind]`), and a plane flies at its
   waypoint's height. No planes of one kind can be given altitudes of their own without a small server-only C++
   addition. (Details and the rejected alternatives are in item 10.)
3. **10 does not need a new tab.** The TRAFFIC page is 77 px of content in a 739 px scrolling area
   (`agents.md` 2714). The load controls go there as a LOAD TEST section.
4. **9 and 21 both need to send messages bigger than a hello.** `Net.read_hello` drops anything over
   `HELLO_MOST_BYTES` = 512. One station layout is several kilobytes, and one spoken ATC line is tens of kilobytes. So
   there is **one long-message mechanism in `net.gd`**: 9 builds it and 21 reuses it. That puts 21 after 9, as proposed,
   but for this reason.
5. **19 wants 9 and 15.** The map screen is a new part, which 9's craft definitions have to allow. Its arrows want
   15's colours. 19 lifts the one colour formula that exists today
   (`RemotePilot.setup`: `Color.from_hsv(fmod(id * 0.37, 1.0), 0.55, 0.95)`) into one function, and 15 then changes
   only that function.
6. **18 is most likely a missing feature, and it is C++.** `CockpitWorld::switch_kind` never makes a craft. It only
   moves the pilot into an **existing** craft of that kind that has a free seat. On the island that is the spawn
   table's spare craft. So the second player to press PLANE after the only spare is taken gets nothing, and the rig
   says "The host didn't move you to a PLANE. Try again." once its patience runs out. In the lobby every press does
   that. A craft made for a player has to be *issued* (`issued_`, swept when empty by `sweep_empty_issues`), and only
   C++ can issue one. **So 18 and 10 cannot be in flight together** (the DLL rule).

### The order: three slots, each one a queue

At most three lanes at once. A lane in a slot starts when the lane before it in that slot has merged, and also when
its "starts when" condition holds.

| Slot | First | Then | Then |
|---|---|---|---|
| **A, the C++ slot** | **10 `stack`**: load test (C++ step 1, then GDScript) | **18 `issue`**: a craft made for whoever asks (C++) | — |
| **B** | **8 `sense`**: only what the craft has, named as the craft names it | **12 `music`** | **21 `radio`**: starts when 9's long message has merged |
| **C** | **9 `builder`**: step 0 (the design) at once; step 1 starts when 8 has merged | **19 `map`**: starts when 9's craft definitions (step 3) have merged | **15 `names`** |

So the first dispatch is **three lanes: 10, 8, and 9's design step.** None of them shares a file with another in its
first steps (fence table below). Rough total: 22 to 30 lane-days, from the per-item sizes below.

### Fences: who owns what, and who asks whom

The contested files are named. **"Holds" means the only lane allowed to edit that file right now. Any other lane
asks the holder.** A lane gives a file up when its step that touched the file has merged, and says so to team-lead.

| File or area | Who, in order | Rule |
|---|---|---|
| `ashiato-gd/**`, both committed DLLs, racer's and vrplayground-2's DLLs | 10 (step 1 only), then 18 | One C++ lane at a time. The DLL rule decides merge order. |
| `cockpit/autoload/net.gd` | 10 (the latency step), then 9 (the long message, then layouts), then 12 (music), then 21 (clips), then 15 (the roster) | Held one step at a time, never across steps. **Each lane that adds a hello kind takes the next `Net.PROTOCOL` number when it rebases, and says so in its commit.** |
| `cockpit/ui/menus/clipboard_page.gd`, `cockpit/ui/clipboard.gd`, `tests/clipboard.gd` | 10 (TRAFFIC section), 9 (BUILD bin filter), 12 (**first new tab**: MUSIC, plus a MUSIC switch on AUDIO), 19 (MAP tab), 21 (RADIO section on AUDIO), 15 (CREW names) | Held per step. **12 measures the tab grid for everyone after it** (see Shared mechanisms, S1). A new page lives in its own script under `ui/menus/`; `clipboard_page.gd` gains only the enum entry, the child and the signal. |
| `cockpit/player/pilot_rig.gd` | 8 (`_bindings_for` and the legend), then 9 (builder functions and a desk key layer) | 9 edits it only after 8 has merged. |
| `cockpit/world/sky.gd` (`FlightLevel`) | 10 (load wiring), 9 (the builder level), 19 (building the map picture), 18 (taking issue places), 15 (pilot names) | Different functions each. Merge in slot order. A lane that finds another's hunk in its way asks team-lead, not the other lane. |
| `objects/seats/cockpit_station.gd`, `cockpit_layout.gd`, `objects/controls/control_catalogue.gd`, `objects/seats/seat_*.tscn`, `objects/vehicles/vehicle_catalogue.gd` | 9 alone, then 19 (adds one part) | 19 asks 9 while 9 is live. |
| `objects/seats/flight_page.gd`, `objects/controls/bind.gd`, `objects/hands/controller_model.gd` | 8 | — |
| `autoload/headphones.gd`, `world/tower_frequency.gd`, `world/radio_*.gd`, `tests/chatter.gd`, `tests/headphones.gd` | 12 (a Music bus only), then 21 | — |
| `world/briefing_room.gd`, `player/remote_pilot.gd`, `ui/menus/crew_manifest.gd` | 15 | 19 asks 15 for nothing: it reads the colour through the function it lifts. |
| `tests/suites.txt`, `tests/docs.gd`, `cockpit/agents.md` | every lane | Shared-file rebase churn. Name them in every "main moved" message. |

### Which lanes build C++

- **10, step 1 only:** `CockpitWorld::set_ai_altitude`. It is server-only autopilot state, with no wire change and no
  new component.
- **18, step 1:** issue places, and a kind press that issues a craft.
- **9 needs no C++**, provided the user takes question 2's recommendation. **21 may change `kokoro-gd`**, which is a
  different library whose binaries are not committed (`headphones.gd`: "NOT COMMITTED"), so the ashiato DLL rule does
  not apply to it. It is still built on the one machine only.
- **No other item touches C++.** The next C++ lane after 18 also carries anything filed against the extension in the
  meantime.

### Questions for the user — OPEN, recorded 2026-09-17, to be revisited

Asked of the user on 2026-09-16 and **not yet answered.** The items they belong to were built overnight, so each
question now asks whether the built behaviour is what the user wants. Under the standing preference a lane took the
recommendation where it had to choose. **What each build actually chose has not been checked question by question**:
where below says "as built", it is read from `plan.md`'s DONE entry; everything else is to confirm on main when the
user comes back.

| # | Item | Question | Recommended | As built (to confirm) |
|---|---|---|---|---|
| 1 | 9 | Are builder cockpits used in flight sessions only once committed to the repo? | Yes | The builder saves every seat on the host under a named version (`plan.md` item 9). Whether a flight session ever reads a saved version: **check** |
| 2 | 9 | May the builder move or add seats? | No | Every native seat gets a BOARD action and the occupant proposes a whole station, which points at seats staying native. **Check** |
| 3 | 12 | When the host plays music, does everybody hear it, with a per-player MUSIC switch? | Yes | Host playback is synchronised to every player (`feat: synchronize host music playback`). The per-player switch: **check** |
| 4 | 15 | Should Steam start at launch just to read a player's name? | No | **Check** |
| 5 | 19 | Is the map screen fitted by default in pilot stations where there is room? | Yes | **Check** |
| 6 | 18 | What exactly was pressed when spawning a vehicle "did not work", and what did the board say, word for word? | — | The host now issues a craft when none is free (`plan.md` item 18). **Ask the user whether the case they saw now works** |

The original text of each question, with its reasoning and rejected alternatives, follows unchanged.

1. **[Item 9. Blocks step 6, not steps 0 to 5.] Where does a cockpit built in the builder get used?**
   **Recommended:** in flight sessions, only cockpit definitions committed to the repo (`cockpit/stations/`). The
   builder level shares layouts live between the people in it, and saves them on the host. A person copies one into
   the repo to make it everybody's, which is the rule `CockpitLayout`'s own doc block already states.
   *Rejected:* sending the host's saved layouts to joiners in every session. That means every join needs a layout
   hash, a transfer and a refusal case, and today's personal saved layouts would have to be retired or sent as well.
   *What the recommendation costs:* a group cannot fly a variant they built without a commit. The per-player saved
   layout in `user://cockpits` (applied today by `CockpitStation._fit_the_saved_layout` on that player's machine only)
   stops being applied in sessions. It never showed the same thing on two machines anyway, because a copilot's machine
   builds the pilot's station from the scene.
2. **[Item 9.] May the builder move or add SEATS?**
   **Recommended: no.** Seats, guns, missiles and fitted channels stay in the simulation's C++ shape and bus tables
   (`cockpit_world.cpp`: `*_shape()`, `default_bus`, `loadout_of`). The builder edits what is in front of a seat:
   controls, screens and the shell. A yes makes 9 a C++ lane with a data-driven shape table that every peer must agree
   on, which is several times the size.
3. **[Item 12.] When the host plays music, does everybody hear it straight away?**
   **Recommended: yes.** Nothing plays until a host presses PLAY, so the "sound off by default" rule for suites is not
   touched. Each player also gets a MUSIC switch on AUDIO that turns the music off for them alone, like GAME SOUND.
4. **[Item 15.] Should the game start Steam when it launches, so a player on an IP game still shows their Steam name?**
   **Recommended: no.** Steam is initialised today only when a Steam button is pressed (`SteamLobbyDirectory`), and
   agents.md records the crash on exit that follows touching it. So: the Steam name in a Steam session; otherwise the
   name the player last typed, kept in `user://`; otherwise "PLAYER n".
5. **[Item 19.] Where is the map screen fitted?**
   **Recommended:** in each craft's pilot station wherever `tests/fit.gd` finds it a clear place, and in the builder's
   parts bin everywhere. *Alternative:* in the bin only, so no cockpit gets more crowded until somebody puts one in.
6. **[Item 18. Not blocking.] When spawning a vehicle and getting in "did not work", what did you press, and what did
   the board say, word for word?** Item 3 lost half a day to a reported sentence that was not the one on screen. The
   lane reproduces all four likely paths first either way.

**The four questions already waiting (ditching, a player on the seabed, battleship roll, stabilised guns) block none
of these eight.** 10's stack flies clear of the ground and the sea, and 18 issues craft at the level's own places.
Neither ever needs to know what ditching does.

---

## SHARED MECHANISMS: read these before any item

### S1. The clipboard

- **8 tabs today** (`ClipboardPage.Tab`: CRAFT, CREW, TRAFFIC, FEEL, BUILD, TIME, AUDIO, HELP), laid out as two rows of
  four (`TABS_IN_A_ROW` = 4). `MAY_SCROLL` = HELP, FEEL, BUILD, CREW. The last measured BUILD scroll area is **609 px** in
  the worst case: fire debrief, Steam code and notice line all showing (agents.md 9706).
- **This plan adds two tabs, MUSIC (12) and MAP (19).** LOAD TEST goes on TRAFFIC (10), and the host's RADIO panel goes
  on AUDIO (21). The user asked by name for "a music tab" and "a map tab". A "special ipad menu" and a "sound panel"
  are satisfied by a section on an existing page.
- **Whichever lane adds the ninth tab (planned: 12) measures before building, for both new tabs.** Ten tabs as
  **two rows of five** cost no height, but each
  tab is about 189 px wide instead of 241. Ten as rows of 4, 4 and 2 cost every scrolling page a row of height (46 px
  reach plus the gap) and BUILD's worst case with it. First measurement: set `TABS_IN_A_ROW` to 5 in a throwaway probe
  and run `every_tab_lies_whole_on_the_glass_at_its_own_size` in `tests/clipboard.gd`, which fails any tab whose words
  do not fit. Take five a row if it passes. If it does not, take the third row and re-measure BUILD's worst case.
  *Rejected:* shortening tab words, and smaller tab text. The existing notes rule both out.
- **Every new page** is a `Control` in its own script under `ui/menus/`. It announces (signals) and is handed its data
  (`show_*`), as every page there does. It needs a `tests/clipboard.gd` fit check in the worst case and a shot probe
  picture. A page that scrolls goes on `MAY_SCROLL` with its measurement written beside it.

### S2. Messages between machines

- **What exists:** the hello (`net.gd` "THE HELLO"). It is UTF-8 JSON on the same carriers as sync's packets, marked by
  `HELLO_BITS` = -1, capped at `HELLO_MOST_BYTES` = 512, checked by `Net.read_hello`, repeated every
  `HELLO_EVERY_MSEC` = 200 until heard, with a count `n` so an older message never overwrites a newer one (the
  `sky`/`sky_heard` and `notice`/`notice_heard` pairs). **`tests/lint.gd` fails any `@rpc` except the two carriers**
  (`and_only_the_packet_transport_is_a_godot_rpc`).
- **A small new fact** (music state in 12, the roster in 15) is a new pair in exactly that shape: a `say` and its
  `_heard`, a `_read_the_*` validator that drops and warns (CLAUDE.md rule 8), a place in the level hello if a late
  joiner needs it, and a `PROTOCOL` bump.
- **A long message is a paced background transfer, not a bigger hello.** Layouts (9) and spoken clips (21) are built
  once by 9 step 5, through `Net.send_long(peer, kind, bytes, stale_msec)`. They share the two existing packet carriers
  with sync, so they may never turn a 64 KB save or a radio line into lost control input. This is why this game keeps
  application reliability here rather than using a reliable RPC: Godot documents reliable RPCs as preserving order at
  a significant performance cost, and documents channels as separate streams; Steam's peer must first prove that it
  implements the same channel semantics as ENet before that alternative is considered.

  The wire is a compact binary `LONG_BITS = -2` envelope, distinct from JSON `HELLO_BITS = -1`, so a chunk does not
  spend half its packet on JSON text. It has `kind`, a nonzero per-sender `transfer_id`, `total_bytes`, `chunk_index`,
  `chunk_count`, `crc32`, and at most **384 bytes** of payload. The receiver rejects before allocating unless every
  field is well formed, `total_bytes <= 64 KiB`, `chunk_count <= 171`, the byte count agrees with the chunk count, the
  sender is entitled to that kind, and the transfer has not expired. A completed transfer is accepted only when its
  CRC matches and its kind-specific validator accepts the reassembled bytes.

  The sender has **one transfer in flight per peer** and a four-chunk selective-repeat window. An acknowledgement says
  the highest contiguous chunk plus a 32-bit selective mask; it is coalesced (at most once per 50 ms) and a missing
  chunk is retried after 200 ms, with capped exponential backoff. A newer transfer of the same replaceable kind
  supersedes the old one. A receiver has **one reassembly per peer**, no more than 64 KiB reserved for it, and drops it
  on expiry, disconnect, level/protocol change, malformed input, or replacement. Sender queues have the same lifetime
  rules. IDs are not reused while a sender's process lives, so a late chunk or acknowledgement cannot attach to a new
  transfer.

  **Sync has priority.** `Net` accounts bytes separately for sync, hello, and long traffic. The long-message pump runs
  deferred after the physics-frame sync sends; it sends no more than one 384-byte chunk per peer per pump and no more
  than 12 KiB/s per peer or 48 KiB/s from a host in total. It pauses a peer's long transfer while that peer has recent
  sync loss/rollback above the load-test baseline, then resumes from the acknowledged window. These are starting
  budgets, measured by item 10 and tightened if they move control freshness. Builder layouts are background work and
  may wait up to 15 s. Radio is latency-sensitive: one radio clip replaces the previous one, must fit in 32 KiB after
  encoding, and is dropped after 3 s rather than competing indefinitely with flying.

  `tests/long_message.gd` owns the deterministic packet pump. It proves a 64 KiB layout survives loss, reordering and
  duplication; a bounded radio clip arrives before its deadline; a lost acknowledgement causes only the missing chunk
  to retry; and expiry, disconnect, malformed headers, a bad CRC, over-cap messages, duplicate chunks, replacement,
  and unauthorised kinds release every reserved byte. `tests/crowd_join.gd` (or the item-10 load harness) adds a large
  transfer during active flight and fails if the agreed packet, rollback, or pose-freshness budget regresses. Mutants:
  remove the byte budget, retain a stale reassembly, and acknowledge only contiguously; each must turn a named check
  red.
  *Rejected, and to be re-weighed in 9's design step:*
  - `SceneMultiplayer.send_bytes` on a reliable channel. That is less code, but it is a second ordering model beside
    sync's, which is the reason the lint rule exists. **UNVERIFIED** that GodotSteam's multiplayer peer honours a
    separate channel; confirm in its source (`godotsteam_multiplayer_peer.cpp`, the file `_receive_unordered` quotes).
  - Raising `HELLO_MOST_BYTES` to 64 KB. A 64 KB datagram fragments on ENet and Steam, and losing one fragment loses
    the whole message, so it would be repeated in full.

### S3. The export (12 builds it, 21 uses it)

`cockpit/export_presets.cfg` preset 0 has `export_filter="all_resources"`, `embed_pck=true` and
`export_path="../../builds/cockpit.exe"`. Export templates for `4.7.2.stable` and `4.7.2.stable.double` are installed
under `%APPDATA%\Godot\export_templates`. **Nothing here has ever exported:** `C:\Users\Graham\Desktop\builds` does not
exist. 12 writes `cockpit/tools/export.ps1`, which runs `--headless --export-release`, copies the data folders the game
reads from beside the executable (`music/`), and prints the exe's size and SHA-256. 21 adds its own folders to the same
script.

### S4. One colour per player (19 lifts it, 15 replaces its source)

Today the only colour is `RemotePilot.setup`'s hue from the sync client id. 19 moves that expression, unchanged, into
`Net.colour_of(client) -> Color` (with `Net.name_of(client) -> String` returning `"PLAYER %d"`). It then changes
`RemotePilot`, the CREW page's "PLAYER %d" and `notice_words` to call them. That is a no-op refactor, gated by the
existing `clipboard`, `notices` and `crew_shot` suites. 15 then changes only what those two functions return.

### S5. Every lane's standing brief (paste into every dispatch)

- Set up by `running_a_team_here.md` section 2, every step:
  - copy the engines' `.exe` and `.dll` files only;
  - copy `cockpit/addons/kokoro_gd/bin/*.dll` and `ashiato-gd/addon/addons/ashiato/bin/*.dll`;
  - write `override.cfg` with `custom_user_dir_name="cockpit_lane_<name>"`;
  - import `cockpit` and `ashiato-gd/addon` (double editor) and `racer`;
  - set your own `TEMP`/`TMP`, e.g. `C:\gg-wt\<name>-temp`;
  - pass `-Names a,b` as separate arguments.
- **Land one step, then ready.** Gate each step, send `ready to merge lane/<name> <sha>` with the evidence, and start the
  next step only on the new main.
- Every new check fails first. If it passes first time, get the red by mutation, and **commit before arming a mutant in
  the same file**. Budget: one check per new behaviour, one mutant each, at most three a step; one set of pictures;
  one full `run_all` per step.
- Judge by `RESULT=`. A wait on a child process or a socket is `Time.get_ticks_msec` against seconds, never `PATIENCE`
  frames (session lane: `--fixed-fps` spends 2,400 frames in about a second). **A suite names its level.**
- Every direct launch of a cockpit scene passes `--xr-mode off`. A GPU timing run holds `C:\gg-wt\GPU_SLOT_HOLD`.
  Picture runs do not.
- A new `class_name` means team-lead re-imports at merge. List every new class in the ready message.
- `voice_thread` and `chatter` are **main-only**: a lane's pass of them in 3.5 s has not run them.
- The last commit is `learnings/<date>-<name>.md`, ending `## What's next`. The screenshot goes to
  `screenshots/<date>/cockpit-NN-<what>.png`; `ls` the folder immediately before copying, because numbers race. Copy
  it to `~/godotgames-drafts/<date>/cockpit-<name>/`.
- Rule 0: every new control works with keyboard and mouse. Every new menu has a suite that presses it through the real
  path (`tests/code_pad.gd` is the model) and a shot probe (`tests/code_pad_shot.gd`).

### S6. The C++ brief (10 step 1 and 18 step 1)

- Build both precisions with `-WithDriving -WithVr -WithCockpit`, using `running_a_team_here.md` section 3's command
  line and siblings from the main checkout. godot-cpp is on `Z:\tanagra\godot-cpp`.
- **Three ashiato-sync patches** must already be applied in the shared checkout (`ashiato-gd/tools/patches/`:
  baseline-on-mask-open, retain-before-release, send-newest-inputs-first); `build.ps1` refuses otherwise. Experiment
  only in a private detached ashiato-sync worktree. **Neither item needs a sync change**; if one seems needed, stop and
  propose it.
- `build.ps1` also rewrites racer's and vrplayground-2's tracked `ashiato_gd.dll` and leaves `~ashiato_gd.double.dll`
  behind. Commit the same bytes everywhere, check both DLLs contain `DrivingWorld`, and quote SHA-256.
- Before ready: the addon suites and `racer_smoke`. After merge, team-lead copies the DLLs into
  `ashiato-gd/addon/addons/ashiato/bin/` in the main checkout and every live lane.

---

## ITEM 8. Controls that make no sense for the craft (`lane/sense`, slot B first)

**BUILT 2026-09-16.** `PilotRig._bindings_for` now removes commands for channels the
current craft does not carry before the same table reaches input, controller labels and
HELP. `Bind.says` and `FlightPage` use each fitted bus entry's own name, and the flight page
hides every unfitted bus row. `tests/sense.gd` walks all 21 pilotable kinds: 280 real
controls, 114 inappropriate shared actions removed, every fitted row checked, and the
Chinook ramp, car handbrake and tank parking brake named explicitly. `lint`, `sense`,
`hands`, `pinch`, `snap`, `fit`, `feel`, `crew_sync`, `desk_screens`, `shared_controls` and
`segway_keys` pass. `clipboard` and `missiles` still expose the pre-existing BUILD-page
width defect introduced by the enlarged device catalogue; their Item 8 checks pass.

### The ask

> "make sure the controls in craft make sense, the boat has 'flaps' which doesn't make sense."

No ANSWERED section. `plan.md` folded it into 9. This plan takes it back out (see the one screen, point 1).

### What exists today (read)

- `objects/controls/throttle_lever.gd`: `static func throttle_bindings()` gives THUMB_HIGH `Bind.step(FLAPS, 1)`,
  THUMB_LOW `Bind.step(FLAPS, -1)` and STICK_CLICK `Bind.step(GEAR, 1, true)`. Its doc says the table is shared by
  "a quadrant lever, a Cessna's plunger and a helicopter's collective".
- `objects/seats/seat_wheel.tscn`, used by car, boat, gunboat, carrier, battleship, pirate and submarine
  (`VehicleCatalogue.CRAFT`), has a `Throttle` node that is a `ThrottleLever`.
- `ashiato-gd/src/cockpit/cockpit_world.cpp` `default_bus`: `kKindBoat` fits Trim ("drive trim"), Mode ("anchor") and
  Display ("sounder"), plus throttle, lights, crew button and radio on every craft. **No Flaps, no Gear.** The car's
  Gear is "handbrake", the Chinook's is "ramp" and the tank's is "parking brake".
- `player/pilot_rig.gd`:
  - `_bindings_for(hand)` merges `held.bindings()` without asking about fit;
  - `_do_command` ignores an unfitted channel silently (`if top <= 0 ... return`), so the thumb does nothing;
  - `legend()` prints `Bind.says(...)` for every entry;
  - `_show_the_legend` and the controller labels (`model.show_bindings(_bindings_for(side), ...)`) read the same table.
- `objects/controls/bind.gd` `says()`: a COMMAND is named with `Sim.channel_name(channel)`. That is the **enum's** name
  ("gear"), not the craft's fitted name ("ramp", "handbrake").
- `objects/seats/flight_page.gd`: the right column always has `["flaps", "FLAP"]` and `["gear", "GEAR"]` rows, and
  writes "---" where `state` has no such key.
- For contrast, `objects/seats/mfd_page.gd` `MfdSwitches.show_bus` already lists only fitted channels ("A screen
  offering flaps to a boat is a screen with a dead switch on it"). That page is the model.

### The approach, in steps

**Step 1: the suite, red first.** `tests/sense.gd`. For every pilotable kind (`VehicleCatalogue.pilotable_kinds()`),
every seat, and the station fitted as `tests/fit.gd` fits it (`CockpitStation.use_saved_layouts = false`), it collects
every channel a player can **read or press**:

- each control's `channel`;
- every COMMAND action in each control's own `bindings()`, as `_bindings_for` would merge it with that control held;
- the rows `FlightPage` shows with a value;
- the MFD SWITCHES page (as a contrast that already passes).

It fails on any channel whose range on that kind's bus is 0 (`Sim.schema_of(kind)["channels"]`), and prints each case
as `boat seat 0: THROTTLE thumb high -> flaps (not fitted)`. It also fails where a fitted channel is **named** with
the enum's word rather than the craft's own (`chinook gear -> "ramp"`).

*Red expected on main:* boat, car, gunboat, carrier, battleship and submarine throttles (flaps); car, Chinook, tank and
boat naming; the FLAP and GEAR rows on every craft not fitted with those channels.

**Step 2: the fix.**

- The rig lays the held control's table over the global one and then **drops any COMMAND whose channel
  `vehicle_view().channel_range(channel)` is 0**. Do it in one place in `_bindings_for`, so the thumb, the legend and
  the controller labels cannot disagree. *Rejected:* filtering in `Bind.says`, which would hide the words and leave a
  binding that silently does nothing; and a per-craft copy of `throttle_bindings`, which is three tables that drift,
  which is what its own doc block warns about.
- `Bind.says` names a command by the fitted name when handed the craft's schema: an optional
  `names: Dictionary = {}` argument, passed explicitly at every call site (rule 8's "every optional gets an explicit
  default at its own call site").
- `FlightPage` hides a row whose channel the craft is not fitted with, instead of writing "---". It learns what is
  fitted from `state["fitted"]`, which the MFD page already reads (**UNVERIFIED** that `FlightPage.render` is handed
  the same `state`; confirm in `CraftDisplay.show_state`).

### The gate

- `tests/sense.gd`, red on main as above and green after step 2.
  - Mutant 1: drop the fit filter, and the boat goes red.
  - Mutant 2: `Bind.says` ignores the names, and the Chinook ramp goes red.
- Existing suites that must stay green: `clipboard` (HELP legend completeness: it checks every bound key and finger
  is listed, so a dropped binding must also drop its row), `pinch`, `hands`, `snap`, `fit`, `feel`, `missiles`
  (the stick's LAUNCH rebinding in `_fit_the_missiles`), `crew_sync`, `desk_screens`.
- **Rule 0:** the desk HELP legend is the no-VR surface. The check reads `legend()`, which the desk and the board both
  show.
- **Picture:** `tests/controller_shot.gd` with the boat's throttle held and BUTTON LABELS on. It shows the thumb row
  with no flaps and the helm's own names. Also the boat's flight page without FLAP and GEAR rows (`station_shot`).

### Affected set

`clipboard`, `hands`, `pinch`, `snap`, `fit`, `feel`, `missiles`, `crew_sync`, `desk_screens`, `smoke`,
`segway_keys` (the segway lays its own layer over the desk keys), `lint` and `docs`. Add the new suite to
`suites.txt`. There is no new `class_name` unless the lane adds one.

### Risks and the first measurement for each

- **A binding a test relies on disappears.** For example, a suite that steps flaps on a craft that is not fitted with
  them and expects nothing to happen. First measurement: `rg "Channel.FLAPS|Channel.GEAR" cockpit/tests` before step 2.
- **`channel_range` on a station with no craft** (the hall, the bench) returns 0 for everything, which would strip a
  bench's bindings. First measurement: run `bench` and `hall` probes and read the legend. If they are stripped, the
  filter applies only when `vehicle_view()` exists.

### Fence, dependencies and size

`player/pilot_rig.gd` (`_bindings_for`, `legend`), `objects/controls/bind.gd`, `objects/seats/flight_page.gd`,
`objects/hands/controller_model.gd` if touched, and `tests/sense.gd`. Depends on nothing. **About one lane-day.**

### Dispatch essentials

- The flaps come from `ThrottleLever.throttle_bindings()` (shared by every throttle), `_bindings_for` (no fit filter)
  and `FlightPage`'s fixed rows. **Not** from a station scene, and not from anything item 9 will replace.
- `VehicleView.channel_range(channel)` is the fit question. `_do_command` already uses it.
- The HELP legend completeness check in `tests/clipboard.gd` must still pass. It is the no-VR proof.
- Do not touch the BUILD parts bin. Offering only allowed parts is item 9's step 4.

---

## ITEM 10. Network load test (`lane/stack`, slot A first)

**BUILT 2026-09-16.** `set_ai_altitude` holds server autopilots at individual layers and
NaN releases them; `Net.extra_latency_ms` delays both real socket edges without touching
the host's local simulation. TRAFFIC owns the host-authoritative 0/50/100/200 and +/-10
holding-stack controls plus 0/50/100/200 ms LINK controls and its 5 Hz readout.
`bulk_load` prices the bounded ladder with production timing separated from trace audits;
`bulk_probe` prints all 24 cells; `bulk_peers` confirms a real host and two 50 ms joiners.
The complete table, limits and exact commands are in `agents.md`, under **THE 200-AIRCRAFT
HOLDING STACK IS A MEASURED PRODUCTION RUNG**. The result is yes at 200 craft and eight
peers on this machine (4.53 ms fastest-block server tick at link 8, 1.98 MB/s host upload),
with the host upload plateau recorded as the practical cost.

### The ask, and the binding answer

> "we need a network load test that has a special ipad menu where we can spawn/despawn large amounts of planes to test
> networking and load."

**ANSWERED 2026-09-15:** *"we have the option for 200 planes in flight at the same time (at different altitudes so we
don't have to worry about collisions too much). I want to stress test the network on the bulk test."*

`plan.md` settles the rest: flying, not parked; layered altitudes are a design constraint; **the count is a control on
the page, and the suite asks the page**; measure bytes/s at 0, 50, 100 and 200 craft against 2, 4 and 8 peers, plus
packet fragmentation, the client buffer trend, rollbacks and the server tick time; write the numbers into `agents.md`.
This item is **allowed to find a NO**.

### What exists today (read)

- **Spawning:**
  - `FlightLevel.add_traffic(kind)` (`world/sky.gd`) is host only. It says "Only the host can add to the world." on a
    client, and spawns with `Terrain.one_more(kind, _added, _grid)` and `Sim.spawn_ai_vehicle`.
  - `Sim.spawn_ai_vehicle` returns 0 on a client.
  - `CockpitWorld::despawn_vehicle` refuses a craft with anybody aboard, and a client world.
- **Autopilot heights:** `CockpitWorld::add_ai_waypoint(kind, position)` builds a pool **per kind**. `AiPilot` has a
  waypoint, a leader and a slot, but **no altitude of its own**. `hold_course` exists for `Model::Sail` only.
  `set_ai_leader(follower, leader, slot)` exists.
- **The wire** (agents.md "THE CEILING IS 1024 BYTES PER CLIENT PER TICK" and what came after it):
  - The per-client send budget is **245 kB/s by default**, which is 2,042 bytes a tick at 120 Hz
    (`net_status().send_budget_per_second` / `send_budget_per_tick`).
  - A vehicle update was about 19.6 bytes before quantising, so past the budget craft **come round less often** and
    the channel does not get louder.
  - `options.prioritizer` is a flat 1.0 except for cockpit interiors.
  - The server's outbound is `clients × entities`.
  - **Sync never builds a packet over `mtu_bytes` = 1200** (`ashiato-sync/src/server/client_update_scheduler.cpp` splits
    at the MTU; `types.hpp` `ReplicationServerOptions::mtu_bytes = 1200`). So "fragmentation" is a question of packets
    per tick and the carrier's own overhead, not of sync's packet size.
- **Input:** since `lane/starve`, 8 newest frames per packet, 337 B a tick up per client at any latency. The lead clamp
  is at 63 frames (about 262 ms one way).
- **Measuring tools:**
  - `net_status()` gives `bytes_out_per_second`, `bytes_in_per_second` and `clients`;
  - `timing()` gives `buffer_frames`, `buffer_target`, `prediction_lead`, `latency_frames`, `jitter_frames`,
    `packets_received`, `packets_missing` and `input_packets_truncated`;
  - `resim_stats()["count"]`;
  - `set_tick_breakdown` / `tick_breakdown` on the server;
  - `set_tracing` / `take_trace_events` (server `input_starved` with `input_frame=N`, used by `tests/input_window.gd`);
  - `Net.sent` / `Net.received` as `[packets, bytes, largest]` per peer at the carrier.
- **Harness patterns:**
  - `tests/input_window.gd`: the **exact pump**, two worlds in one process ticked by hand with a link in ticks, a bad
    ENet link, and discard of late packets as ENet's sequenced channel does. Its header explains why the older pumps in
    `gun_link`, `big_guns` and `shell_prediction` are one tick long.
  - `ashiato-gd/addon/tests/crowd_sight.gd`: one server and clients in one process with 80 autopilots.
  - `tests/rota_probe.gd`: a server world built by hand with the island's boxes and waypoints, ticked in blocks and
    timed.
  - `tests/net_jump.gd`: two real processes over ENet on the loopback in `sky.tscn`. Includes `_sample_enet()` for
    `ENetPacketPeer` statistics.
- **Real latency:** none in cockpit. The model is racer's `Network.extra_latency_ms` (`racer/autoload/network.gd`, up
  to 500 ms each way, applied in both directions on the machine that sets it, including the host's own client;
  queued in `racer/world/race.gd` `_post` / `_flush_in_flight`).

### Does it need the real-latency tool first?

**It needs it, but not first.** Every number in the ladder comes from the in-process harness, which has its link in
ticks already and is the only way to run 8 peers without 9 Godot processes fighting for the CPU the server tick is
being timed on. The latency tool is needed for two other things: the **real-process confirmation** (host plus two
joiners, with the carrier's real per-packet overhead) and **a person using the page** on a real session. So it is
step 2, after the C++ step has merged and before the page.

### The approach, in steps

**Step 1 (C++): an autopilot altitude of its own.**
`CockpitWorld::set_ai_altitude(entity_id, metres)`, where NaN releases, in the shape of `hold_course`. While it is set,
the autopilot flies its waypoint's x and z at that height: `want.altitude` is the held height. **The look-ahead escape
climb still wins**, because safety is not negotiable. It is server-only (`ai_` is server-only) and changes no
component and no wire.

- *Rejected:*
  - **Formations with vertical slots** (`set_ai_leader`). A 200-plane lattice turning about one leader measures the
    formation guidance's worst afternoon ("A follower a long way out stacks up", agents.md 606) instead of the
    network.
  - **Separate waypoint pools per wing kind.** That gives at most seven layers, each kind costs different bytes, and it
    reshuffles every existing kind's routes.
  - **A GDScript autopilot.** There is no per-vehicle AI input binding, so it would be C++ anyway.
- *Gate:* a check in `cockpit/tests/climb.gd` or a new `cockpit/tests/altitude_hold.gd`. Twenty planes on the
  island pool, half held at a height: the held half stay within a tolerance **measured on the first run** (report the
  worst |altitude − held| over 120 s), and the free half still change height with their legs.
  - *Mutant:* ignore the override, and the check goes red.
  - `climb`, `avoid`, `rota` and `smoke` stay unchanged. `wire_budget` shows no new bytes.

**Step 2 (GDScript): `Net.extra_latency_ms`.**
Send-side queues in `Net._carry` and receive-side queues in `Net._arrived`, both keyed by due time, on the machine
that sets it. It is set by `--latency=MS` after the bare `--`, and changeable on the LOAD TEST section.
The host's own client-to-server loop (`Sim._carry_packets` delivers straight across) is **left alone, and the doc block
says so**. *Rejected:* racer's host-loop latency, which would put the host's own pilot on a fake link in a load test
whose host is the thing being measured.

- *Gate:* `tests/latency.gd`, two real processes. The joiner with `--latency=100` shows `timing().latency_frames` of
  about 12 at 120 Hz against about 0 without (tolerance from the first run), and hellos still arrive.
- *Mutant:* queue only one direction, and latency comes out as half.

**Step 3: `HoldingStack` and the LOAD TEST section.**
`world/holding_stack.gd`, `class_name HoldingStack`. A holding stack is what air traffic control calls aircraft layered
by altitude, so it is a physical object and not a manager. It is handed a server world (so the harness can hand it a
bare `CockpitWorld`) and a level.

- `set_count(n)` converges towards n, spawning or despawning in batches of `BATCH` a tick (sized by the first
  measurement below). It never despawns a craft somebody is sitting in, and says so.
- **Layers are derived, not typed:**
  - the base = the highest ground on the level (`Terrain.highest_near` across the level, or the ground field's
    maximum) + `CLEARANCE`;
  - the spacing = 3 × the worst altitude error measured in step 1 + the wing's span (`kind_geometry`);
  - planes per layer = `ceil(most / layers)`.
- Each plane spawns on its layer's ring, heading along the ring at `Terrain.cruise_for(PLANE)`, and is held there with
  `set_ai_altitude`.
- The section on TRAFFIC has:
  - PLANES IN THE STACK, with the count;
  - 0, 50, 100 and 200 as buttons, plus −10 and +10;
  - LINK, this machine's latency;
  - a readout at 5 Hz: count, peers, kB/s per peer, packets per tick, buffer, rollbacks per second, server tick.
- The page announces `chose_stack(count)` and `chose_latency(ms)`. `FlightLevel` decides: the host's stack, and a
  client refused in words, in amber.
- The top of the count is `HoldingStack.MOST` = 200, clamped with a warning (rule 8). The probe may pass `--most=` to
  push past it and find the NO.
- *Gate:* `tests/holding_stack.gd`, solo on the island (named).
  - The PAGE's buttons are pressed through the real path (`force_input` / a beam press, as `tests/clipboard.gd` does).
  - **The count is read off the page** (`load_count()`) and **the planes are counted off `Sim.current`** after the stack
    converges.
  - 200 then 0: all spawned, then all gone.
  - A pilot sitting in one: 1 left, and the board says why.
  - Every plane is within half a layer's spacing of its layer for 60 s.
  - A client pressing: refused in words (a child host, as `desk_join` does).
  - *Mutants:* the stack puts every layer at one height (separation red); a count read from a constant instead of the
    page (count red).
- *Picture:* `tests/holding_stack_shot.gd` from a plane at the stack's middle layer, 200 planes with visible layers,
  plus the TRAFFIC section with its readout.

**Step 4: the ladder, in one process.**
`tests/bulk_load.gd` (the gate suite) and `tests/bulk_probe.gd` (the full table). The design detail is in the next
section.

**Step 5: the real-process confirmation, and writing it down.**
`tests/bulk_peers.gd`: a child host and two joiner children with `--latency=50`, all on the island. The host fills the
stack to 200 through its own page (a `--stack=200` harness flag that presses the button, in the pattern of
`--launch=`). Numbers go into `cockpit/agents.md` as a new section under the wire sections, with the table, and the
loose-list follow-ups are updated (prioritizer, lead clamp, delta coding).

### THE LOAD-TEST DESIGN DETAIL

**Two harnesses, because they answer different questions.**

| | in-process (`bulk_load`, `bulk_probe`) | real processes (`bulk_peers`) |
|---|---|---|
| what | one server `CockpitWorld` and N client `CockpitWorld`s, ticked by hand at 120 Hz, packets carried by an exact pump with a link in ticks, per direction | a host process and two joiners over ENet on the loopback, `sky.tscn`, `--latency=50` on each joiner |
| answers | bytes a tick per client, packets a tick, freshness, buffer trend, rollbacks, starvation and server tick time, at every rung, without CPU contention from other Godots | the carrier's real overhead per packet, what the page does in a real session, and whether the in-process numbers hold on a socket |
| why not the other | 9 processes each drawing `sky.tscn` would put the server's tick time at the mercy of 8 other processes and make every timing cell void | a bare world cannot say how many bytes Godot's RPC and ENet add to a sync packet |

**How 200 planes are spawned and flown (both harnesses):** through `HoldingStack`, against whichever server world it
is handed. The in-process server and every client world are built as `tests/rota_probe.gd` builds one: the island's
`Terrain.boxes()` as static boxes and `Terrain.waypoints(PLANE, grid)` as the pool. Everything is built identically in
every world (the `Sim._worlds` rule). Each client gets a pilot in a pod, the way `crowd_sight` seats its clients, and
flies a rocking stick as `input_window` does, so its input changes and a stale frame mispredicts. **UNVERIFIED:** the
exact calls `crowd_sight` uses to add a client and seat it. Read `ashiato-gd/addon/tests/crowd_sight.gd` before
writing the harness.

**The pump:** `input_window`'s exact pump, generalised to N clients. A packet sent after tick T is delivered before the
receiver's tick T + link. It counts, per client and direction: packets, bytes, the largest packet, and packets per
tick. `bulk_load` runs at a clean link of 8 ticks (67 ms). The probe runs links 8 and 16.

**The rungs:**

- **Gate (`bulk_load`, must finish inside `run_all.ps1`'s 180 s deadline):**
  - craft {0, 200} × peers {2, 8} at link 8;
  - plus 200 × 8 at link 16 for starvation;
  - each cell is 600 settling ticks and 1,200 measured ticks.
  - First measurement: the wall time of one 200 × 8 cell. If the gate would pass 150 s, drop to peers {2, 8} at 200
    only, plus the 0 × 2 baseline.
- **Probe (`bulk_probe`, `--ladder=full`):** craft {0, 50, 100, 200} × peers {2, 4, 8} × links {8, 16}. Listed in
  `docs.gd` `PROBES`. Its table goes into agents.md.

**What is measured and where it is printed.** One line per cell, parsed by the suite and pasted by the probe:

```
BULK craft=200 peers=8 link=8 down_kB_s_per_client=<mean,max> down_pkts_per_tick=<mean,max> largest_down_B=<n>
     up_kB_s_per_client=<mean> server_out_kB_s=<n> budget_B_tick=<net_status> worst_update_gap_ticks=<n>
     predicted_gap_ticks=<n> buffer_frames=<first third median>-><last third median> rollbacks_per_s=<mean,max>
     starved=<n> truncated=<n> server_tick_ms=<fastest of 5 blocks, mean>/<p99> craft_seen=<min over clients>
     out_of_band=<n> lost=<n>
```

- `worst_update_gap_ticks` is the longest run of ticks in which a client's view of an entity was not updated. It comes
  from the server's sync trace (per-entity send events, as `net_jump`'s host `_sent_frames`), traced on **one** client.
  **First measurement:** `trace_events_dropped()` at 200 × 8 with tracing on. If it drops, trace one client in a 200 × 2
  cell and derive the rest.
- `predicted_gap_ticks` = ceil(entities × measured bytes per update ÷ budget). Measured bytes per update = the 200-craft
  cell's bytes a tick ÷ entities updated a tick, read off the trace.
- `server_tick_ms`: `CockpitWorld.tick` on the server, timed five blocks and keeping the fastest block's mean
  (`running_a_team_here.md` section 5: a wall-clock budget is a budget on the machine's load). Also `tick_breakdown`
  once, for the table.
- In `bulk_peers`, on each joiner:
  - `Net.received[1]` (packets, bytes, largest);
  - bytes on the socket per packet, as `ENetConnection.pop_statistic(HOST_TOTAL_RECEIVED_DATA)` ÷
    `HOST_TOTAL_RECEIVED_PACKETS` per window (**UNVERIFIED** those enum names on 4.7.2; confirm at
    docs.godotengine.org `class_enetconnection`);
  - the same BULK fields that are readable from `Sim` and `Net`.

**Pass and fail: what a red looks like.** Every threshold is derived in the run itself, never typed, except the two
invariants in points 5 and 6.

1. **Counts.** Every client world's `vehicle_states()` holds base + N planes within `ceil(N / BATCH) + link × 2 + 120`
   ticks of the stack being asked, and base again after 0.
   Red: `FAIL craft_seen 200x8: client 6 saw 187 of 200 after 2,400 ticks`.
2. **The measurement stayed about the network.** `out_of_band == 0` (every plane within half a spacing of its layer) and
   `lost == 0` (every stack entity alive and above its stall speed, `kind_geometry()["stall_speed"]`).
   Red: `FAIL separation 200x8: 3 planes left their layers`. That makes the whole cell VOID, and it says so.
3. **The budget holds.** Each client's mean downstream bytes a tick ≤ `send_budget_per_tick` × 1.02, and the largest
   tick ≤ the budget + one MTU (1,200). Red: `FAIL budget 200x8: client 3 averaged 2,610 B a tick against 2,042`.
4. **Rotation is fair.** `worst_update_gap_ticks ≤ 2 × predicted_gap_ticks`. Red means some craft starves while others
   stay fresh: the flat prioritizer has stopped being flat, or the trace shows a craft skipped.
5. **Load does not bring input starvation back.** `starved == 0` and `truncated == 0` at links 8 and 16, at every rung.
   Red is `lane/starve`'s bug returning under load.
6. **Rollbacks do not grow with craft.** Per client, rollbacks/s at 200 ≤ 2 × at 0, same peers and link. The craft are
   interpolated, not predicted, so growth means prediction has become coupled to the crowd.
7. **Buffers do not climb.** The last third's median `buffer_frames` − the first third's ≤ 1, per client.
   Red: `FAIL buffer 200x8: client 5 went 7 -> 13 frames`.
8. **The server keeps its tick.** `server_tick_ms` fastest mean < 8.33 ms (a 120 Hz tick) at 200 × 8. Red:
   `FAIL server 200x8: 9.4 ms a tick; the server cannot run this rung at 120 Hz`. **This is the NO the item is allowed
   to find**, and the suite reports it as a failure with that sentence, not as a void.
9. **(`bulk_peers` only) The carrier does not fragment.** The largest bytes on the socket per packet stay under ENet's
   MTU. Read it off the ENet host rather than assuming 1,392 (**UNVERIFIED** constant; `ENetConnection` /
   `ENetPacketPeer` expose the MTU or the host's `mtu`; confirm). Also, each joiner's downstream kB/s is within 15% of
   the in-process 200 × 2 cell.

**Mutants that prove the checks can fail (at most three a step):**

- the stack puts every layer at one height → 2;
- the pump drops 50% of downstream packets for one client → 4 and 7;
- the pump delays upstream by 40 ticks → 5 and 6.

For 3, a mutant check reads the budget from a world started with `set_send_budget` × 4. It must go red on the first
cell, which proves the check compares against the number the server actually used.

**What the table is expected to show, written down so a surprise is a finding** (predictions, not measurements):

- downstream per client flat at about 245 kB/s from roughly 100 craft up;
- server outbound linear in peers, about 1.96 MB/s (15.7 Mbit/s of host upload) at 8 peers;
- freshness falling as 1/craft past the budget;
- upstream flat at about 40 kB/s per client (337 B × 120 Hz);
- packets per tick per client growing to 2 or more (2,042 B ÷ 1,200);
- **no fragmentation at any rung**, because sync splits at 1,200.

If 15.7 Mbit/s of host upload is the practical ceiling, the honest follow-ups are a distance prioritizer and a lower
per-client budget, both already described in agents.md "THE ROOM TO GROW IS PRIORITY". **Neither is built here.**

### The gate (summary)

- Step 1: `altitude_hold` (or `climb`), plus `rota`, `avoid`, `smoke`, `wire_budget`, the addon suites and
  `racer_smoke`.
- Step 2: `latency`.
- Step 3: `holding_stack`, `clipboard` (TRAFFIC fit in the worst case) and `holding_stack_shot` (the picture).
- Step 4: `bulk_load`.
- Step 5: `bulk_peers` and `docs`.

Rule 0 is met because everything is on the TRAFFIC page and desk-pressable, and every suite is headless or windowed.

### Affected set

- Step 1 (C++): the full `run_all`, the addon suites and `racer_smoke`; it is a shared contract.
- Step 2: `session`, `two_peers`, `desk_join`, `lobby_peers`, `level_hello`, `sky_peers`, `notices`, `steam_join`,
  `code_pad`, `no_vr_flight`, `net_jump` (a probe).
- Step 3: `clipboard`, `smoke` (spawn counts), `chatter` (main-only, if the level changes what flies near the listener),
  `docs`, `lint`.

New classes: `HoldingStack`, so re-import at merge.

### Risks and the first measurement for each

- **Spawning 200 in one tick hitches the server.** Measure one tick with 200 `spawn_ai_vehicle` calls in `bulk_probe`
  before choosing `BATCH`.
- **Altitude hold error is larger than expected in turns.** Step 1's worst error sets the spacing, so measure before
  choosing the spacing, never after.
- **Tracing is too costly at 8 × 200.** Measure `trace_events_dropped` first (see above).
- **The wire's `height` range.** `cockpit_components.hpp`: `kHeightSpanMetres` = 41,900 from `kFloorMetres`. Fine, but
  check the top layer against `Sim.server.wire_range()["height_max"]` in code, not by eye.
- **200 `VehicleView`s on each real-process joiner cost CPU**, and `bulk_peers` is not a timing suite. Say so in its
  doc block.

### Fence, dependencies and size

`ashiato-gd/**` (step 1 only), `autoload/net.gd` (step 2 only), `world/sky.gd` (the load wiring beside
`add_traffic`), `world/holding_stack.gd`, the TRAFFIC section of `ui/menus/clipboard_page.gd` and forwarding in
`ui/clipboard.gd`, and the new tests. Depends on nothing. **3 to 5 lane-days.**

### Dispatch essentials

- **Step 1 is C++ and lands alone.** Brief S6. Server-only AI state. No component, no wire, no sync patch.
- Autopilot waypoints are per kind (`add_ai_waypoint`). That is why the altitude hold is needed. Do not try formations
  or per-kind pools; plan.md and this file say why.
- The ladder's numbers come from the **in-process** harness (`input_window`'s exact pump generalised to N clients, and
  `rota_probe`'s world building). The real-process run confirms the carrier. Read `crowd_sight.gd` before writing.
- Sync splits packets at 1,200 B, so expect "no fragmentation, more packets per tick". A table that says otherwise is a
  finding.
- Every threshold in `bulk_load` is derived in the run (budget from `net_status`, spacing from step 1, the predicted
  gap from measured bytes) except starvation 0 and the 120 Hz tick.
- The load controls go on **TRAFFIC**, not a new tab.
- Put the numbers in `cockpit/agents.md`, beside "THE CEILING IS 1024 BYTES PER CLIENT PER TICK".

---

## ITEM 9. A builder level, and cockpit definitions as JSON — BUILT 2026-09-16 (`lane/item9-final`)

### The ask, and the binding answer

> "Build a special level that is ONLY for modifying and saving cockpit definitions, we should also move cockpit
> definitions into json files so we can modify them each station type should have a json object that has all the data
> with position, rotation, and settings. The "builder" level allows us to configure and save new ones (or alternate
> versions). The craft should still determine what devices work on it, that way the builder knows what things they have
> to add (and what won't work). Allowed devices should be part of the craft definition."

**ANSWERED 2026-09-15:** *"let's make the builder level support building multi-user cockpits as well, so that multiple
people can join (make this a target level from the lobby), that way a group of people can decide how to layout a vehicle
and build different stations."*

Recorded recommendation (take it): **a station belongs to whoever sits in its seat.** Gate from plan.md: every craft
still builds its cockpit from the new data with nothing moved, compared numerically; a newly saved definition reloads;
two peers edit different seats, both layouts save and reload, and neither can move the other's controls.

### What exists today (read)

- **Stations are scenes.** 11 `objects/seats/seat_*.tscn` (plane, airliner, osprey, heli, wheel, train, cessna, tower,
  tanker, glider, tank), chosen per kind by `VehicleCatalogue.CRAFT[kind]["seat"]`, loaded by
  `VehicleCatalogue.seat_scene(kind)`. A scene holds a `CockpitStation` root and nodes that are:
  - bin parts (`Throttle`, `Stick`/`Yoke`/`Wheel`/`Brake`, `Button`, sometimes `Extra`);
  - furniture that is not in the bin: `Shell` (`CockpitShell`, with `width` and `depth`; `framed` went with the scaffold on 2026-09-17), `Rudder`
    (`RudderIndicator`), `Crew` (`CrewBoard`) and `Display` (`CraftDisplay` with `page`).
- **What `CockpitStation.fit` adds from the simulation after the scene:** the gunner's stick, `_fit_the_mfds` (seats
  that do not fly), `_fit_the_gun` / `_fit_the_trigger`, `_fit_the_trim_wheel`, `_fit_the_missiles` (LockSight,
  MasterArm at `ARM_PLACES`), `_fit_the_pedals`, `_mirror_the_layout` for the right-hand seat, and last
  `_fit_the_saved_layout`.
- **`CockpitLayout`** already reads and writes a seat's bin parts as JSON: `{craft, kind, seat, units, controls: [{part,
  name, label, channel, channel_name, range, scope, at, facing}]}`. Files go to `user://cockpits/<kind>_seat<N>.json`,
  or `user://test_cockpits` for suites (`folder_for`). `apply()` makes the file win outright over bin parts and leaves
  everything else alone.
- **`ControlCatalogue.PARTS`** is 24 parts, hand-listed with reasons (`PintleGun`, `RudderIndicator`, `CameraKeypad`
  excluded).
- **`VehicleCatalogue.CRAFT`** is the non-physics craft table: `seat`, `body`, `paint`, `helm`, `shared_throttle`,
  `plunger`, `drawn`.
- **The builder is the rig's.**
  - `PilotRig.add_control(part)` offers any bin part to any craft, with no craft check.
  - `save_the_cockpit()` writes through `CockpitLayout.write`.
  - `forget_the_cockpit()` rebuilds the station.
  - `_building` / `_trying`, `_building_bindings`, `PlacingGrid` and `SnapBoard` complete it.
  - **It is worked by HAND only.** At a desk the hands are welded (`_place_desktop_rig`), and there is no desk path for
    moving a control. `tests/builder.gd` and `tests/snap.gd` use `force_hand`.
- **Saved layouts apply only on the machine that saved them** (`_fit_the_saved_layout` reads the local `user://`), so a
  copilot's machine draws the pilot's station from the scene. They already disagree today.
- **Levels** are `levels/<id>/level.json` (island, alpine, lobby), read by `LevelChart`. `world: "room"` makes
  `FlightLevel` stand a `BriefingRoom` and seed nothing (`_indoors`). The launch board is a `ChartMenu` on a
  `TouchPanel` handed to `PilotRig.pointer_panels`. `Net.call_the_level` warns and changes level.
- **Messages:** see S2. A layout of about a dozen controls at about 250 B of JSON each is about 3 KB, which is over
  `HELLO_MOST_BYTES`. **UNVERIFIED:** measure the real size in step 0.
- **Suites that load stations or layouts** (read by `rg`): `fit`, `smoke`, `builder`, `snap`, `pinch`, `feel`,
  `pedals`, `gunners`, `turret_seats`, `ranging_sight`, `missiles`, `shared_controls`, `shots`, `gun_link`, `director`,
  `director_shot`, `clipboard`, `bench`, `station_shot`, `helm_shot`, `hawkeye_shot`, `ship_shot`, `ship_models`,
  `fleet_shapes`, `carrier_shape`, plus `marshalling/hand/marshal_rig.gd`, `world/hall.gd` and
  `objects/vehicles/ships/wheelhouse.gd`.

### What is C++ and what is GDScript

**Scope correction, 2026-09-16.** The next request expands this item from station
presentation into authored craft packages: each package must preserve a model-origin frame,
seat poses, model reference and bounded flight-template parameters. The original C++ fence
remains correct for a running multiplayer session, but is no longer the final architecture.
Before custom seat geometry or a new flyable craft is enabled, add a native pre-session
`CustomCraftRegistry` that validates the package, exposes a simulation-contract hash, and
refuses peers with a different manifest. Do not send editable physics or seat transforms on
the rollback wire. `builder_authoring.md` holds the package split, authority rules, device
route, fleet backlog and staged delivery.

- **C++, untouched (question 2's recommendation):**
  - seat count, positions, stations and `flies` (`*_shape()`, the `seat_poses` in `kind_geometry`);
  - fitted channels and names (`default_bus`, `craft_schema`);
  - guns (`gun_of`, `mount_of_seat`) and missiles (`loadout_of`, `missile_schema`);
  - `pilotable`.
- **GDScript and JSON, new:**
  - station definitions (everything a `seat_*.tscn` holds);
  - craft definitions (everything `VehicleCatalogue.CRAFT` holds, plus **allowed devices** and which station each seat
    uses);
  - the builder level, sharing layouts between players, and versions.
- **The allowed-devices rule ties the two together without copying:** a part that writes a bus channel (`FlapsLever`
  → FLAPS, `GearLever`/`GearHandle` → GEAR, `TiltLever` → TILT, `DropLever` → DROP, `TrimWheel` → TRIM, and a
  `ToggleSwitch`/`RotaryKnob`/`DetentDial` wired by a layout) is refused at load if that channel is not fitted
  (`Sim.schema_of`). That refusal is derived, not listed. The `allowed` list says which **presentation** parts a
  designer permits (an MFD, a camera, a map screen, a second stick). One number, one place: the bus is the authority on
  channels, and the craft file is the authority on the rest.

### Step 0: THE DESIGN (half to one lane-day; a document, a probe, no repo change)

Written to `~/godotgames-drafts/2026-09-16/cockpit-builder/design.md`, sent to team-lead, and summarised onto
`plan.md` item 9 by team-lead. It must settle, each with the rejected alternative:

1. **The station file.** Recommended: `cockpit/stations/<id>/station.json`, where the folder name is the id, a
   `_`-prefixed folder is skipped, and a malformed file disables itself with a message (rule 7, as `LevelChart` does).
   It has the `units` line from `CockpitLayout`, plus:
   - `shell: {width, depth}`;
   - `controls: [CockpitLayout entries]`;
   - `furniture: [{kind: "crew_board"|"display"|"rudder_indicator", name, at, facing, page?}]`.

   The loader is `StationChart`, the same pattern as `LevelChart`. It builds a `CockpitStation` node, and
   `CockpitStation.fit` is unchanged.
   *Rejected:* keeping `.tscn` and exporting JSON beside it (two copies of every cockpit); a scene saved from the
   running game (see `CockpitLayout`, "WHY JSON AND NOT A SCENE").
2. **The craft file.** Recommended: `cockpit/craft/<kind_name>/craft.json`, holding the whole of today's
   `VehicleCatalogue.CRAFT` entry (body and helm as the enum names in words), plus
   `stations: {"default": "plane", "1": "plane"}` and `allowed: ["FlightStick", ...]`. `VehicleCatalogue` reads the
   folder at boot and keeps its API (`of`, `body`, `paint`, `seat_scene` → `station_for(kind, seat)`).
   *Rejected:* allowed devices in C++ (the server has no use for presentation parts); allowed devices derived entirely
   from the bus (it cannot say whether a boat may have an MFD).
3. **The editor.** agents.md "SEEING A COCKPIT IN THE EDITOR" (10869) relies on the scenes. Recommended: a `@tool`
   `StationChart` preview node that builds from JSON in the editor. *Measure* whether a `@tool` script can read
   `res://stations/**` in the editor without a preload cycle (rule 6).
4. **Sharing layouts between players in the builder level.** A player's machine proposes its seat's layout **on
   release** (a drop, an add, a bin). The host checks that the proposer sits in that seat
   (`Sim.server.vehicle_seats`), validates it (allowed parts, fitted channels, positions clamped to the station's box,
   at most `MOST_CONTROLS`), and relays it to everyone with a count `n`. Every machine applies it with
   `CockpitLayout.apply`. It rides the long message (S2).
   *Rejected:* streaming drag poses, which is a control loop through the network (`building_a_game_here.md`, "Never
   close a control loop through the network") and bandwidth for a picture; a simulation component, which is C++, a
   tuned wire, and rollback for furniture.
5. **Ownership.** A station belongs to whoever sits in its seat (take the recommendation). A proposal for any other
   seat is refused, counted and warned. An unoccupied seat's layout is frozen.
6. **Versions and saving.** SAVE, by the seat's occupant, writes on the **host**:
   `user://cockpits/<craft>/<version>/seat<N>.json`, with the path said on the board. The builder level's board picks
   the craft and the version. Recommended default version name: `default`. A new version is named on a keypad (the
   `CodePad` shape, letters and digits). Question 1 settles whether a version is ever used outside the builder.
7. **A desk path (rule 0, required).** The builder has none today. Recommended: in BUILD at a desk, a mouse click on a
   control through the `GlassPointer` ray selects it (a ray against controls' grab points). Then a **desk key layer
   while building**, laid over `DESK_KEYS` exactly as the segway's is (`PilotRig.reading_a_segway()`): arrows and
   PageUp/PageDown nudge by the `PlacingGrid` step, and `,`/`.` turn by the rotation step. **Check every key against
   `desk_keys()` first:** F1 to F11 are craft, F/G/H/R/D/Q/E are taken, and `[ ] ; '` are the tick rate and buffer.
   *Rejected:* a 3D mouse drag, whose depth is ambiguous on a monitor and cannot be pressed exactly by a suite.
8. **The level.** Recommended: `levels/builder/level.json` with `world: "room"`, arrivals in segways, a floor where one
   craft of the chosen kind is spawned parked (host only), a board to pick the craft and version, and the launch
   board's LEVELS reachable from the lobby's launch board (it lists every level already). **Measure** whether a room
   level can host a parked craft. `_indoors` seeds nothing today, so the craft must be issued by the builder level
   itself, and a 70 m airliner needs a room size read from the craft (`kind_geometry` extents, not typed).
9. **The migration order.** One station at a time, with the scene path intact until the last. Recommended order:
   tower, train, glider, cessna, tank, wheel, heli, osprey, tanker, airliner, plane. That is fewest controls first and
   the plane (the most suites) last.

**Probe for step 0:** `tests/station_census.gd` (probe; listed in `docs.gd` `PROBES`). For each scene, list every node,
its script's global name, its transform, and every `@export` whose value differs from the script default. This is the
list the JSON has to hold. It also measures **one layout's JSON size in bytes** (plane seat 0, airliner seat 0), which
decides the long message's cap.

### Steps 1 to 6: the building

**Production slice landed 2026-09-16.** The durable package layout supersedes the older
global-station sketch below: `craft/<kind>/1/` now holds all 23 manifests and all 79 native
seat documents. `AuthoredCraftPackages` refuses malformed, stale or hash-mismatched
revisions; `tests/stations.gd` fits each legacy scene and compares 318 fitted controls plus
shell and furniture against the checked-in package. Every craft has an explicit device
allowlist, and package save/load enforces it. **The runtime slice then landed:**
`VehicleView` constructs all 79 stations directly from those documents, with a strict
legacy-scene fallback for a refused package; the BUILD bin, direct add path, saved-layout
application and package validation all enforce the same allowlist and fitted schema. The
builder room and paced transfer landed in `lane/item9-final`; the detailed steps below are retained as the design record.

**Step 1: stations as JSON, alongside the scenes.** `StationChart`, the `cockpit/stations/` folder generated **once by
a script from the scenes** (then hand-checked, and the script is deleted or kept as a probe), and
`tests/stations.gd`: for every station, the scene-built node and the JSON-built node, both put through `fit` for every
kind and seat that uses them, are **numerically equal**:

- every control: part, name, position to 0.001 m, rotation to 0.01°, channel, range, scope;
- every furniture node the same way;
- the shell's exports.

Malformed fixtures (`tests/station_fixtures/`, like `level_fixtures`) disable themselves with a message and fail no
other station. Nothing in the game switches yet.
*Red first:* the equality check fails with the JSON missing `Shell`'s exports, as step 0's census predicts.

**Step 2: the game builds from JSON.** `VehicleCatalogue` → `StationChart`, one station per commit in step 0's order,
with `tests/stations.gd` plus `fit`, `smoke` and each station's picture checked per commit. When the last station
moves, the scenes go, in one commit, with the editor preview from step 0.3.
*Gate:* the whole affected set, plus `station_shot`, `helm_shot` and `craft_gallery_shot` pictures compared with main's
(the before and after pair).

**Step 3: craft definitions and allowed devices.** `cockpit/craft/<kind>/craft.json` and `VehicleCatalogue` reading
them. `tests/craft_charts.gd`:

- every `Sim.Kind` has a file, including segway;
- every field is read with an explicit default at its own call site (rule 8);
- a malformed fixture disables itself;
- **every authored station's bin parts are allowed on every craft that uses it, and every channel part is fitted.**
  This is what makes the boat's authored station prove itself.

*Red first:* delete the boat's `ThrottleLever` from `allowed` and see the check name it.

**Step 4: the builder obeys the craft.** The BUILD bin shows only allowed parts: `ControlCatalogue.PARTS` filtered by
`VehicleCatalogue.allowed(kind)`, handed to the page by the rig, so the page stays ignorant.
`PilotRig.add_control` refuses a disallowed part in words, and `CockpitLayout.apply` refuses (warns and skips) a
disallowed part or an unfitted channel. This is item 8's bin half.
*Gate:* `builder` extended. On a boat, no `+ FLAPS LEVER` button on the page, and a forced `add_control(&"FlapsLever")`
is refused with the sentence on the board. The existing `clipboard` BUILD fit check is re-measured, because the page
becomes shorter on most craft.

**Step 5: the paced long-message transfer** (S2), in `net.gd`. Implement the S2 envelope, four-chunk selective-repeat
window, ownership checks, hard memory caps, expiry/replacement cleanup, and the deferred byte-budgeted pump exactly as
specified above. Keep JSON `read_hello` for facts that fit in 512 bytes; validate `LONG_BITS` separately before a
buffer is allocated. `PROTOCOL` bumps.

**Built 2026-09-16.** `LongTransfer` supplies the bounded binary envelope and selective-repeat engine; `Net` routes
`LONG_BITS = -2` over its existing `_receive_unordered` RPC on both transports, enforces sender authority, exposes the
semantic-validator and sync-pause seams, and counts sync/hello/long traffic separately. The protocol is now 4. The
receiver releases a completed payload immediately but keeps a small ACK tombstone through the original expiry, and
transfer ids are never reused during a process. The deterministic gate below is green: the 64 KiB layout crossed its
lossy/reordered/duplicating link in 8.2 s and the 8 KiB clip in 1.03 s. The active-flight budget comparison remains an
item-10 load measurement, where the sync loss/rollback signal needed by the pause predicate is measured rather than
guessed here.

`tests/long_message.gd` uses the `gun_link` packet-list shape with loss, reordering and duplication. It checks the
layout and clip deadlines, only-missing-chunk retries, every refusal and cleanup path, and the exact per-peer/global
byte ceiling. The load harness sends a layout while a client flies and asserts that sync's packet, rollback and
pose-freshness measurements stay inside item 10's baseline budget.

*Mutants:* acknowledgements ignored (the transfer never drains), the byte budget removed (the load budget regresses),
and stale reassembly cleanup removed (reserved-byte accounting remains nonzero).

**Step 6: the builder level, multi-user.** `levels/builder/`, the room built for one parked craft, the craft and
version board, per-seat ownership, proposals, relays and SAVE on the host, and the desk key layer from step 0.7.

**Built 2026-09-16.** The room, parked craft, dynamic BOARD actions, revisioned/coalesced
proposals, strict authority boundary, repeated READY for late consumers, host SAVE, desktop and
hand paths, and alternate package versions are complete. The final three-process ENet gate proves
host plus A plus a genuinely late B; A's rapid desk edit and B's hand edit converge everywhere;
forged-other-seat and disallowed-part proposals are refused; SAVE writes and reloads every gunship
seat. The solo visual probe separately proved the production level startup and caught a
server/client entity-handle mix-up that the network report had hidden. Its inspected 1600x900
craft/stations and board images are in `screenshots/2026-09-16/item9-builder/`. All automated
launches use both `--xr-mode off` and `--desktop-only`, so application code does not initialize
OpenXR during headless gates or the windowed probe.

- **Gate: `tests/builder_peers.gd`, three machines.** This process joins, and there are a child host and a second
  child joiner, with the harness flags in the pattern of `--board=`/`--launch=`.
  - Joiner A sits in seat 0 and joiner B in seat 1.
  - A moves its throttle 0.10 m through **the desk key layer** (the no-VR path) and B moves its trigger 0.05 m through
    `force_hand` (the hand path).
  - All three machines' stations show both moves within 2 s wall-clock.
  - A's forged proposal for seat 1 is refused (the host's warning count moves; B's layout is unchanged on all three).
  - The host's SAVE writes both files, a rebuilt level reloads both, and a disallowed part in a proposal is refused.
- `tests/builder_shot.gd`: the room with the craft, two players at two stations, and the board.
- *Mutants:*
  - the host skips the seat check (forgery red);
  - the relay skips `n` (an older proposal wins, red; the joiner sends two proposals out of order through the pump);
  - SAVE writes on the proposer instead of the host (the reload check is red, from the host's file).

### The gate (summary)

- Step 0: the census probe and the design.
- Steps 1 and 2: `stations`, `fit`, `smoke`, plus pictures.
- Step 3: `craft_charts`.
- Step 4: `builder` and `clipboard`.
- Step 5: `long_message`.
- Step 6: `builder_peers` and `builder_shot`.

Every step runs the affected set below. Steps 2 and 6 are shared-contract changes, so they run the full `run_all`.

### Affected set

- Every suite named under "What exists today", plus `crew_sync`, `hands`, `pinch`, `snap`, `feel`, `pedals`, `lint`,
  `docs`, `levels` (a new level folder), `level_hello` (a new level hash), `lobby`, `no_vr_flight` (the launch board
  lists a new level) and `desk_screens` (the desk's levels monitor lists it; `cockpit/docs/craft.md`
  says about seven levels fit).
- **A new level on the desk's monitor is a shared-mechanism change.**
- New classes (`StationChart` and whatever else is added): re-import at merge.
- `player-files`: `run_all.ps1` fails a gate that changes `user://cockpits`. Builder process tests also pass
  `--builder-test-files=1`, which directs versioned packages to `user://test_cockpit_packages`.

### Risks and the first measurement for each

- **A half-migrated definition system** (plan.md's highest risk). Controlled by step 1's equality suite existing before
  anything switches, and step 2 going one station per commit.
- **`fit` applies mirroring and fitted parts after the scene**, so equality must be compared **after `fit`** for each
  kind and seat, not on the raw node. Measure step 1 on the airliner (mirrored, shared throttle) first.
- **The editor preview is lost.** Step 0.3 measures before step 2 deletes a scene.
- **The builder level cannot host a parked craft in a room** (`_indoors` seeds nothing). Step 0.8 measures.
- **The desk key layer collides with an existing key.** Step 0.7 reads `desk_keys()` and the segway layer first.
- **The layout size exceeds the long message's cap for a busy station** (four seats of an airliner at once). Step 0's
  census measures it.

### Fence, dependencies and size

`objects/seats/**`, `objects/controls/control_catalogue.gd`, `objects/vehicles/vehicle_catalogue.gd`, `cockpit/stations/`
and `cockpit/craft/` (new), `levels/builder/`, the builder functions of `player/pilot_rig.gd`, the BUILD page of
`ui/menus/clipboard_page.gd`, `autoload/net.gd` (steps 5 and 6), the builder part of `world/sky.gd`, and tests.

Step 0 depends on nothing. **Step 1 onward starts after 8 has merged** (both touch `pilot_rig.gd`). Step 6 needs
question 1 answered.

**Size:** step 0 is 0.5 to 1 lane-day; steps 1 to 4 are about 4 lane-days; steps 5 and 6 about 3 lane-days. **7 to 9
lane-days**, the largest item.

### Dispatch essentials

- **Start with step 0 only.** It is a design document and a census probe. Send the design to team-lead before writing
  any definition.
- `CockpitLayout` already writes and reads a seat's bin parts as JSON. Extend its format; do not invent a second one.
- Stations hold non-bin furniture (`Shell`, `Crew`, `Display`, `Rudder`) that `CockpitLayout` deliberately does not
  write. The station file must.
- `CockpitStation.fit` adds guns, sights, MFDs, trim wheels, pedals, the master arm and the mirror from the
  **simulation**. None of that goes in a station file. Compare equality **after** `fit`.
- Seats, channels, guns and missiles stay C++ (question 2). A part's channel must be fitted: derive that from
  `Sim.schema_of`, never list it.
- The builder has **no desk path today**. Rule 0 requires one. See step 0.7.
- Suites write layouts to `user://test_cockpits` (`CockpitLayout.folder_for`). A gate that changes `user://cockpits`
  fails as `player-files`.

### Item 8 after 9: what 9 must deliver so the rest of 8 is data

Item 8's bindings and pages are fixed in batch 1 (`lane/sense`). What remains of "controls that make no sense for the
craft" is **what the builder offers and what a layout may hold**. It becomes a data change, with no hand-patching, only
if 9 delivers these four things:

1. **`allowed` in every craft file** (step 3), read by the BUILD bin (step 4). Taking a flap lever away from a boat is
   then one line in `cockpit/craft/boat/craft.json`.
2. **The derived channel refusal** (step 3): a part or a layout control on an unfitted channel is refused at load with
   a message. A new craft cannot ship a dead lever even if its `allowed` list is wrong.
3. **`tests/craft_charts.gd`'s check that every authored station is allowed and fitted for every craft using it.** Any
   future nonsense in an authored cockpit goes red there, instead of in a user report.
4. **Stations chosen per seat in the craft file** (`stations`). A boat can then have a helm station without a
   quadrant throttle (a boat's throttle is a lever on the helm), by pointing at a different station file, without a
   new scene.

If step 3 ships without the derived refusal, 8's bin half is hand-patching after all. Do not let step 3 merge without
it.

---

## ITEM 12. Networked music with volume (`lane/music`, slot B second)

**BUILT 2026-09-16.** Runtime Ogg files are scanned from `--music`, beside the executable, or from the editor-only
project fallback. The host's revisioned track/start/fade state is resent until acknowledged and rides the level hello
for late joiners; `MusicBox` seeks it on the simulation clock. The ninth clipboard tab controls playback and fades,
while AUDIO's MUSIC switch is local. `record_shelf`, `music_page`, real-ENet `music_peers`, `clipboard`, `level_hello`,
`headphones`, `docs` and `lint` pass. The Dummy driver advances the runtime-loaded fixture. A measured Windows export
was a 4,282,200-byte PCK with the external fixture folder beside it; the exported `--music-list` found only `test_tone`.
The visual record is `user://music_shot.png`.

### The ask, and the binding answer

> "I need to be able to play music ... i need to be able to have a music tab where i can play music on command (this
> needs to play for all players correctly synced) (i need to be able to control volume as well and that should also be
> networked so i can fade it in)"

**ANSWERED 2026-09-15:** *"just make sure we can include the ogg file in a data folder, or make it part of the build
process, it doesn't need to be in the repo."*

From plan.md: a folder scanned at boot, where the file name is the id; the host decides and clients follow; volume
travels the same way so a fade is the host's fade; found relative to the **executable** (`OS.get_executable_path()`),
with a project fallback for the editor; a suite proves the exported shape; licensing is the user's own matter.

### What exists today (read)

- **The tracks:**
  - `cockpit/music/` holds `lotr.ogg`, `pirates.ogg` and `ride.ogg` (58 MB), **with `.import` files**, so Godot imports
    them.
  - `.gitignore` lines 124 and 125 already ignore `/music/` and `/cockpit/music/`, so they are **out of git already**.
  - They are **still in the project**, so `export_filter="all_resources"` would put 58 MB into the PCK. This is an
    inference; step 1 measures it.
  - `godotgames/music/` (the workshop, gitignored) has seven tracks: lotr, mighty, pirates, ride, stalker,
    transformers, tullia.
- **Sound:**
  - `autoload/headphones.gd` (`PilotHeadphones`) makes the `Game` and `Radio` buses (`_make_the_buses`), and
    `choose_game_sound` mutes `Game`;
  - nothing is replicated ("what a player has in their ears is theirs");
  - every run starts with both switches off;
  - `--audio` starts GAME SOUND on.
- **The shared clock:** `Sim.client.timing()["estimated_server_frame"]` is a continuous server-frame estimate on
  **every** machine, including the host's own client world. It is the clock the simulation already agrees on.
- **Messages:** S2. A music state message is small.

### The approach, in steps

**Step 1: the data folder, and the exported shape.**
`world/record_shelf.gd`, `class_name RecordShelf` (a physical object). It scans the first folder that exists, in this
order:

1. `--music=DIR`;
2. `OS.get_executable_path().get_base_dir().path_join("music")`;
3. **editor only** (`OS.has_feature("editor")`), the project's own `music` folder via
   `ProjectSettings.globalize_path("res://music")`, never `res://../`.

It reads with `AudioStreamOggVorbis.load_from_file` (**UNVERIFIED** on 4.7.2; confirm at docs.godotengine.org
`class_audiostreamoggvorbis`). The file name without `.ogg` is the id. A file that will not load disables itself with
a message; `_`-prefixed files are skipped. The id pattern is validated (it goes on the wire).

- Add `cockpit/music/.gdignore` so the tracks are neither imported nor exported. **Un-ignore that one file in
  `.gitignore`** (`!/cockpit/music/.gdignore`), or it cannot be committed. Remove the stale `.import` files.
- `cockpit/tools/export.ps1` (S3) exports and copies `music/` beside the exe. It uses the workshop's
  `godotgames/music` as the source by default, overridable.
- *Gate:* `tests/record_shelf.gd`.
  - Folder order, tested with `RecordShelf.folders(args, exe_path, is_editor)` as a static with synthetic paths.
    Rule 3 is satisfied because the real function is called with the real `OS` values in the game.
  - A fixture folder with a good track, a text file named `.ogg` (disabled, said) and `_skip.ogg` (skipped).
  - The id pattern.
- **Export measurement (the lane runs it once, recorded, not a suite):** the exe's size before and after `.gdignore`
  (it should shrink by about 58 MB), and the exported exe run headless with `--music-list` printing what it found
  beside itself.
- **While the export exists, record item 21's hypothesis for free:** run the exported exe with VOICE on (a
  `--voice-test` flag or the board's words) and write down whether `Headphones.models_folder()` finds anything. This
  settles plan.md's "strong hypothesis, not a measurement" before 21 starts.

**Step 2: synced playback, and volume on the host's clock.**
`autoload/net.gd` gets a `music` / `music_heard` pair (S2), carrying:

```
{track: id or "", started_frame: float, volume_from, volume_to, fade_from_frame, fade_frames, n}
```

- The level hello carries it too, so a late joiner starts at the right place.
- It is the host's (`Net.decides_the_sky()` is the existing predicate for "this machine decides session facts"; add
  `decides_the_music()` beside it, named for its own question).
- `world/music_box.gd`, `class_name MusicBox`, on a new `Music` bus that `PilotHeadphones` makes. Every machine plays
  `track` from `(estimated_server_frame − started_frame) / Sim.tick_hz` seconds, and re-seeks only if it has drifted
  more than `DRIFT_MS`. The volume is a pure function of the frame (a linear fade in dB between two frames), so a fade
  is the same on every machine without per-frame messages.
- A client missing the track says so on its board ("You have no track called 'ride'") and stays silent.
- The host's own machine plays through the same `MusicBox`.
- *Rejected:*
  - **Wall clocks:** machines disagree by the link, and the simulation already has a shared frame.
  - **Streaming audio:** 58 MB of history, which the user ruled out.
  - **Per-frame volume messages:** a control loop through the network.

**Step 3: the MUSIC tab, and the MUSIC switch on AUDIO.**
The ninth tab. Measure S1 first. The page lists the shelf's tracks, PLAY/STOP, a volume slider with FADE IN / FADE OUT
over `FADE_SECONDS`, and what is playing and where. On a client it shows the same readout, with the controls refused
in amber (the TIME tab's pattern). AUDIO gets a MUSIC switch, which is local only (question 3).

### The gate

- Step 1: `record_shelf`, plus the export measurement in the commit message.
- Step 2: `tests/music_peers.gd`, a child host and this process joining.
  - The host plays `_test_tone.ogg`, a tiny fixture committed under `tests/music_fixtures/`, found via `--music=`.
  - At the same `estimated_server_frame`, both machines' `get_playback_position()` agree within a tolerance **measured
    on the first run**. Headless uses the Dummy driver, which mixes in real time per `headphones.gd`; **UNVERIFIED**
    that playback position advances there, and that is the first measurement.
  - A fade reads the same volume on both at three frames.
  - A late joiner starts mid-track at the right place.
  - A joiner's PLAY is refused.
  - A malformed `music` hello is dropped and warned.
  - *Mutants:* play from 0 instead of the frame offset (late joiner red); a joiner applying its own volume (fade red).
- Step 3: `clipboard` (tab fit, worst case), `tests/music_page.gd` (the page pressed through the real path), and
  `tests/music_shot.gd` (the picture: the MUSIC tab with a track playing, the fade, and the readout).

### Affected set

`headphones` (a new bus), `chatter` and `voice_thread` (main-only, because the buses change), `clipboard`,
`desk_screens`, `sky_peers` and `notices` (the level hello's fields and the `PROTOCOL` bump), `level_hello`,
`steam_join`, `lint` and `docs`. New classes: `RecordShelf` and `MusicBox`, so re-import at merge.

### Risks and the first measurement for each

- **Playback position does not advance headless.** Measure it in a throwaway before writing `music_peers`. If it does
  not advance, the suite compares the computed seek offsets and the picture proves sound only by a person, said plainly.
- **`load_from_file` seeking in a 38-minute Ogg is slow.** Time a seek to 30:00 once.
- **The export fallback path.** `OS.has_feature("editor")` is true in an editor run and false in an export, but
  **UNVERIFIED** whether it is also true for a suite started from the console editor. Measure it, because suites use
  the fixture folder anyway.

### Fence, dependencies and size

`autoload/net.gd` (step 2, after 10's latency step has merged), `autoload/headphones.gd` (the bus only), `world/`
new files, `ui/menus/music_page.gd`, and the tab row, MUSIC switch and forwarding in `clipboard_page.gd` and
`clipboard.gd` (step 3). Also `.gitignore` (one line), `cockpit/music/.gdignore` and `tools/export.ps1`.

**Starts when 8 has merged** (slot B). Its step 2 waits for 10's step 2 if that is still open (both touch `net.gd`),
and its step 3 is the first tab. **2 to 3 lane-days.**

### Dispatch essentials

- The tracks are already gitignored but **still imported**. Find, measure and fix the exported shape first
  (`.gdignore`, and export size before and after).
- Never `res://../`. `Headphones.WORKSHOP_MODELS` is the bug that shipped item 21 broken.
- Sync the music on `timing()["estimated_server_frame"]`, not wall time. Make the fade a function of the frame.
- You add the first new tab (S1). Measure five-a-row before choosing a third row.
- While the export exists, record whether the exported game finds the kokoro model. Item 21 needs that answer.

---

## ITEM 19. A map tab, and a map screen (`lane/item19-map`, BUILT 2026-09-16)

**Built:** `LevelMap` takes one 1024 px orthographic picture of the shared `World3D` with its own fog-free environment,
then sleeps at `UPDATE_DISABLED`; level, daylight and finish changes request exactly one new frame. `MapCanvas` puts
replicated crew markers over that texture on both the MAP clipboard tab and the dedicated `MapScreen` part. The screen
is in every authored craft allowlist and is fitted to each flying station; it remains movable in BUILD but takes neither
flight hand. Marker names and colours come from item 15's authoritative `Net.name_of` / `Net.colour_of` roster through
`LevelMap.marker_style`; the map owns no roster state. Headless projection measured 0.000 px worst error at the four
island corners. The windowed probe cost 35.21 ms
for the one 1024 px render on the RTX 5080 used for the probe; subsequent ordinary frames requested zero rebuilds.
Evidence: `screenshots/2026-09-16/map-item19-island.png`, `cockpit-device-map-screen.png`, and
`map-item19-pilot-seat.png` (the fitted screen from the pilot eye point).

### The ask, and the binding answer

> "We need a map tab in the ipad that shows where other players are and helps you find them. We also need a mfd that
> has a map that shows the same information (but it's the only thing it does is show a map and shows arrows to other
> players)"

**ANSWERED 2026-09-15:** *"can you render to a texture and the add overlays based on xyz position?"* — **yes.** A
`SubViewport` with a `Camera3D` looking straight down, in orthogonal projection, rendered **once** (`UPDATE_ONCE`), and
re-rendered only when the world changes (level, time of day, finish). Overlays are `Control`s placed with
`Camera3D.unproject_position`. **Say in the doc block that the map draws a dead world once**, unlike item 20's live
camera. A lane may choose the extent and whether it zooms; recommended: a fixed extent covering the level.

### What exists today (read)

- `objects/controls/mfd_panel.gd` `MfdPanel`: a bin part, a screen with 18 keys round the bezel. Its page is
  `objects/seats/mfd_page.tscn`. It is only fitted by `CockpitStation._fit_the_mfds` to seats that **do not fly**, and
  it is in `ControlCatalogue.PARTS`.
- `objects/seats/mfd_page.gd` already has an `MfdPlan` (a 2D plan of `state["contacts"]` for SA, EW and ATTK RDR
  pages).
- `objects/seats/craft_display.gd` `CraftDisplay` redraws a `TouchPanel` at 5 Hz. `addons/touch_panel/touch_panel.gd`
  sets `render_target_update_mode = SubViewport.UPDATE_ONCE` per redraw.
- `world/world_map.gd` `WorldMap` files the island's boxes by the kilometre, and draws nothing.
- **Where players are:** `Sim.pilots` (client → vehicle, seat) and `Sim.current[entity]["position"]`.
  `ui/menus/crew_manifest.gd` `CrewManifest.read` already computes crews and distances.
- **The world is not all drawn at once.**
  - `SceneryYard` builds cells round the eye (a 24 km reach is measured in agents.md "nothing is built to draw the far
    band"), so the island's 14 km is likely all standing.
  - The alpine ground is drawn at levels round the eye (`GroundView`).
  - The level's `WorldEnvironment` has depth fog and the compute mist on its compositor (`MistLayer.use_environment`).
  - An orthographic camera 8 km up, **sharing the world**, looks through that fog unless it has its own
    `Camera3D.environment`.

### The approach, in steps

**Step 0: two measurements, before anything is built.**

1. A throwaway windowed probe (`--xr-mode off`, no GPU slot needed) renders the island and alpine from an orthographic
   camera at the level's middle with its own `Environment` (no fog, a flat ambient light). The picture decides whether
   the render-once map is complete.
   - **If the alpine far rings are coarse or missing,** the fallback, recorded as the rejected-then-taken alternative,
     is a map image drawn from data: `Terrain.boxes()` and the ground field's heights coloured by height into an
     `Image`.
   - Take the render if it reads. Fall back **only on the picture's evidence**, and tell team-lead, because the user
     chose the render.
2. The cost: `UPDATE_ONCE` of a 1024 px orthographic viewport over the whole level, timed once on the windowed stock
   editor. It is one frame, so it matters only as a hitch at level build.

**Step 1: `LevelMap`, the picture and the projection.**
`world/level_map.gd`, `class_name LevelMap`. It is built by `FlightLevel` after `_build` and rebuilt on the level change,
time change and finish change signals that `FlightLevel` already has. It exposes `texture()` and
`to_map(world: Vector3) -> Vector2` through the camera's `unproject_position`.

- Colour and name per player: `LevelMap.marker_style` calls S4's authoritative `Net.colour_of` / `Net.name_of` APIs.
- *Gate:* `tests/level_map.gd`, headless.
  - `to_map` of the four corners of the level's extent lands on the texture's corners within 1 px.
  - A craft's position from `Sim.current` lands on the pixel its x and z predict.
  - A rebuild happens on each of the three triggers and **not** on an ordinary frame (count renders).
  - *Mutant:* make the map `UPDATE_ALWAYS`, and the no-render-per-frame check goes red. That is the check that stops
    somebody "fixing" it into a live map.
  - **UNVERIFIED** that `unproject_position` gives correct numbers headless with the dummy renderer. Measure it. If it
    does not, the maths is the camera's own orthographic projection, computed from its `size` and transform, and the
    check compares the two in a windowed run once.

**Step 2: the MAP tab.**
The tenth tab (S1). A page shows the texture with an arrow per crewed craft, drawn in the player's colour and pointing
along the craft's heading, with the name beside it. Your own arrow is larger. A tap on a player's arrow or name
highlights them and draws a line from you to them with the distance ("helps you find them"). The page is handed the
rows by `Clipboard` (`CrewManifest.read`'s rows plus positions and headings), and announces nothing it cannot decide.

- *Gate:* `tests/map_page.gd` with two server-seated players (the pattern of `clipboard`'s crew page). Both arrows are
  on the pixels `to_map` gives, their colours are `Net.colour_of`, a press on a name highlights it, and the fit check
  passes in the worst case.
- *Picture:* `tests/map_shot.gd`, the island with three arrows.

**Step 3: the map screen.**
Recommended: a new part, `MapScreen` (`objects/controls/map_screen.gd`), a `CraftDisplay`-style glass that shows **only**
the map and arrows. The user said it is the only thing it does, so no bezel keys. It redraws its overlay at 5 Hz, and
its picture only when `LevelMap` rebuilds.

- It is added to `ControlCatalogue.PARTS` with its `taken_by` decided (a screen is neither gripped nor pinched; see
  `tests/pinch.gd`'s first section, which fails until that is decided), allowed in every craft file, and fitted by
  default per question 5.
- *Rejected:* a MAP page on `MfdPanel`. It is a bezel of keys for a screen that must do one thing, and `MfdPanel` is
  fitted only to seats that do not fly.
- *Gate:* `builder` (the part is in the bin, and the bin still scrolls as `MAY_SCROLL` says, re-measured), `pinch`
  (the part has decided), `fit` (every default placement is clear of every grip), and `tests/map_screen.gd` (the arrows
  on the screen are the same as on the page for the same state; the screen redraws its picture only on a rebuild).
- *Picture:* the pilot's eye on a plane with the map screen fitted.

### Affected set

`clipboard` (a tab), `builder` (a part), `pinch`, `fit`, `smoke`, `director` (the bin order and length), `feel`,
`notices` and `crew_shot` (the S4 refactor), `desk_screens`, `lint` and `docs`. **A new part is a shared-mechanism
change: run the full `run_all`.** New classes (`LevelMap`, `MapScreen`): re-import at merge.

### Risks and the first measurement for each

- The render is incomplete or fogged: step 0.1.
- Rebuild hitches on a time-of-day change: step 0.2.
- The headless projection: step 1's first run.
- **BUILD gets longer.** The parts bin has 22 parts and scrolls since the 22nd. A 23rd adds a row: re-measure the
  worst case.

### Fence, dependencies and size

`world/level_map.gd`, `world/sky.gd` (building and rebuilding the map), `ui/menus/map_page.gd` and the tab in
`clipboard_page.gd`, `objects/controls/map_screen.gd`, `control_catalogue.gd`, the craft files' `allowed` lists, and
S4's refactor of `remote_pilot.gd`, `clipboard_page.gd` and `net.gd` (two static functions).

**Starts when 9 step 3 has merged** (craft definitions and `allowed`). The tab comes after 12's tab. **2 to 3
lane-days.**

### Dispatch essentials

- The user chose render-once plus overlays. **Look at the picture first** (step 0), because the scenery is drawn round
  the eye and the level's fog is on its environment. Give the map camera its own `Environment`.
- `UPDATE_ONCE`, rebuilt on level, time and finish only. Write a check that fails if it renders every frame.
- One colour function for players (S4). Item 15 will change what it returns.
- The screen is a new part. `pinch.gd`'s first section fails until you decide `taken_by`, and BUILD's bin grows by a
  row.

---

## ITEM 21. ATC voice generated on the host and heard by everyone — BUILT 2026-09-16 (`lane/radio`)

The host captures Kokoro output with `AudioEffectCapture`, box-filters it to 8 kHz, and encodes standard IMA ADPCM.
Measured by `radio_clip`: 25.98 dB speech-band SNR and 4,003.0 bytes/s, with exact completion of the seven-second
maximum through deterministic 10% loss in 2,800 ms. `radio_peers` proves the host and a real ENet client with no model/library play one decoded clip
and the client cannot publish. `tools/export.ps1 -HostVoice` explicitly packages the models and native dependencies;
the clean exported `--speak-test` printed 28,235 decoded samples from a 14,138-byte clip. Steamworks voice was verified
as microphone capture/decompression only, with no arbitrary PCM injection, so clips use the session carrier.

**EXPORT MEASUREMENT 2026-09-16:** the Item 12 Windows export printed `VOICE_MODELS=`. The current executable-side
fallback finds no Kokoro model in a clean export; Item 21 must copy its model data beside the executable explicitly.

### The ask, and the binding answer

> "...remove anything that just adds chatter the scene, we'll need to generate it on the server, and then play it as
> audio on the voice channel via steam..."

**ANSWERED 2026-09-15:** *"remove the random filler, have a sound panel on the ipad on the server that generates the
audio and plays it to the clients (and the server player)."*

From plan.md:

- The shipping bug is `Headphones.WORKSHOP_MODELS = "res://../kokoro-gd/models"`. Verify it against an actual export
  before building.
- Steam voice injection is expected not to exist. Establish it and write it down with the API reference.
- If it does not exist, the line goes as session data, compressed, dropped if late, and played through `Radio`.
- The host hears its own line through the same path.
- Say what became of `chatter` and `voice_thread`.
- *Gate:* an export that speaks, and a two-peer headless run where the host generates and the client plays with no
  model and no library present.

### What exists today (read)

- **`world/tower_frequency.gd` `TowerFrequency`** is the filler. It is built by `FlightLevel._ready` and runs
  `_say_something` every `RadioTuning.INTERVAL ± JITTER` wall seconds while VOICE is on. It uses `RadioPhrases`,
  `Headphones.say`, `on_air` and `priority`. It is **this machine's only**.
- **`autoload/headphones.gd` `PilotHeadphones`:**
  - VOICE loads `KokoroServer` through `ClassDB`, from `addons/kokoro_gd/bin/kokoro_gd.gdextension` under `.gdignore`;
  - `say(text, voice, priority, speed) -> utterance id`;
  - lines play through a `RadioChannel` on the `Radio` bus;
  - models are looked for in `KOKORO_MODELS`, then `WORKSHOP_MODELS` (`res://../`), then `user://kokoro`;
  - the libraries (`libkokoro_gd.windows.x86_64[.double].dll` and `onnxruntime.dll`) are present in
    `cockpit/addons/kokoro_gd/bin/` on this machine and **not committed**.
- **`kokoro-gd` (tracked source)** binds `queue`, `queue_phonemes`, `barge_in`, `cancel`, `clear`, `is_transmitting`
  and friends, with signals `utterance_started`, `utterance_finished` and `synthesis_failed`.
  **There is no binding that returns samples.** `SynthEngine::synthesize_text` (`kokoro-gd/src/synth_engine.cpp`)
  produces PCM chunks internally, and the stream goes to a channel.
- **Steam:** cockpit calls no GodotSteam voice function (`rg "getVoice|startVoiceRecording|decompressVoice"` finds
  nothing).
- **Messages:** a clip is tens of kilobytes, which is the long message (S2, built by 9 step 5).
- **Suites at dispatch:** `chatter` and `voice_thread` are main-only and model-dependent. `voice_thread` measured
  15.1 ms here; the 2026-09-17 follow-up below resolved it by preparing the native library during initial boot.

### The approach, in steps

**Step 0: the findings, before a feature.**

1. **The export.** If item 12 has recorded it, read that. Otherwise, with `tools/export.ps1`: does the exported game
   find the model, and does it find `onnxruntime.dll`? Write down what the VOICE line says in the exported exe, and what
   it says after the libraries and models are copied beside it.
2. **Steam voice.** Read GodotSteam's function list in its source or docs (the version already built,
   `cockpit/tools/build_godotsteam.ps1`) and Steamworks' `ISteamUser` voice functions (`StartVoiceRecording`,
   `GetVoice`, `DecompressVoice`). Record with references that there is no call to inject arbitrary PCM. **UNVERIFIED**
   until read; `.claude/settings.local.json` allows `github.com` and `raw.githubusercontent.com` for WebFetch.
3. **Where the samples come from.**
   - *Option B, recommended:* a `KokoroServer.render(text, voice, speed) -> PackedFloat32Array` (or a `rendered(id,
     pcm, rate)` signal) in `kokoro-gd`, built with `kokoro-gd/scripts/build.ps1`. First measurement: does that build
     work unchanged on this machine?
   - *Option A:* an `AudioEffectCapture` on a silent bus the host's radio line plays into. This needs no C++, but it is
     real-time (a 4 s line takes 4 s to capture) and **UNVERIFIED** headless.
   - Take B if the unchanged build works in under an hour. Otherwise A.

**Step 1: remove the filler.**
Delete `TowerFrequency` and its construction in `FlightLevel._ready`. Keep `RadioPhrases` for the panel. Keep the radio
check on VOICE on: it is how a player knows the switch worked, and it is not chatter. Rewrite `chatter` to cover what
is left (the radio check, and later the clip) or retire it with a sentence in `suites.txt`'s history and agents.md.
**Say in the commit what became of `chatter` and `voice_thread`.**
*Gate:* main-only `headphones` and `chatter`; `lint` and `docs`. `rg TowerFrequency` returns nothing.

**Step 2: a clip.**
The host renders PCM (step 0.3), then **encodes**. Recommended: 4-bit IMA ADPCM at 8 kHz after a 3:1 decimation with a
low-pass. The `Radio` bus band-passes to about 300 to 3,400 Hz anyway, so that is about 4 kB/s of speech.

- *Rejected:* Opus and Vorbis, which have no runtime encoder in GDScript on 4.7.2 (**UNVERIFIED**: confirm there is no
  encoder in `AudioStreamOggVorbis` or `AudioStreamWAV` at docs.godotengine.org); raw 16-bit PCM, which is 64 kB/s at
  8 kHz.
- The clip goes as a long message with kind `clip`, `{id, rate, format, spoken_frame, bytes}`, **stale after**
  `CLIP_STALE_MS` (recommend 3,000 ms past `spoken_frame` on `estimated_server_frame`; "stale ATC is worse than
  silence").
- Clients decode into an `AudioStreamWAV` (or an `AudioStreamGenerator`) on `Radio`. **The host plays its own clip from
  the decoded bytes through the same player.** Only the host may send a clip; a joiner's clip is dropped and warned.
- *Gate:* `tests/radio_clip.gd`, in-process and model-free.
  - It encodes a synthetic PCM sweep and decodes it: SNR ≥ a figure **measured on the first run** in the 300 to
    3,400 Hz band.
  - Bytes per second.
  - A clip through the long-message pump with 10% loss arrives whole.
  - A stale one is dropped.
  - A joiner-origin clip is refused.

**Step 3: the RADIO panel on the host's board.**
A host-only section on AUDIO (S1): the station phrases that name no aircraft, from `RadioPhrases.station_slots()`, as
buttons; a desk text field for a typed line (rule 0); SPEAK; and a line saying "Sent to N players" or why not. A client
sees "The host speaks on the radio." A clip heard shows on the notice line as a new `radio` notice kind (optional; one
entry in `Net.NOTICE_KINDS`).

- *Gate:* `tests/radio_peers.gd`, **main-only**, because the host needs the model. A lane junctions
  `kokoro-gd/models` in (`running_a_team_here.md` section 4).
  - A child host with the model, and this process joining with `KOKORO_MODELS` pointed at an empty folder and
    `Headphones.extension_path` pointed at nothing.
  - The host presses SPEAK through the real button (a `--speak=<phrase id>` harness flag).
  - The joiner plays a clip whose decoded length matches the host's within one block.
  - The host's own player played the same clip.
  - A joiner with no model and no library heard it (the proof a client needs neither).
  - *Mutants:* the host plays from kokoro's channel instead of the decoded clip (same-path red); the stale check off
    (a clip delayed 5 s through a pump is played, red).
- *Picture:* the host's AUDIO tab with the RADIO section, and the joiner's notice line.

**Step 4: the export that speaks.**
`tools/export.ps1` copies the kokoro libraries and the model folder beside the exe, **on the host's build only**.
`Headphones` looks beside the executable before `user://kokoro`: add `<exe dir>/kokoro/models`, and drop `res://../`
for exports, keeping it editor-only. The exported exe run headless with `--speak-test` renders a line and prints the
sample count. **This is the gate plan.md asked for: an export that speaks.** A person confirms by ear on the host.

### Affected set

`headphones`, `chatter` and `voice_thread` (main-only), `clipboard` (the AUDIO section's fit), `notices` (if a notice
kind is added), `level_hello` and `steam_join` (`PROTOCOL`), `smoke` (`FlightLevel` no longer builds the frequency),
`lint` and `docs`. New classes: re-import at merge.

### Risks and the first measurement for each

- **kokoro-gd will not build here.** Step 0.3's unchanged build.
- **ADPCM quality through the radio band.** Step 2's SNR, and one listen by a person.
- **A long line (10 s) exceeds the long message's cap.** 10 s × 4 kB/s = 40 kB, under a 64 kB cap. Clamp line length
  at the panel.
- **Resolved after this item:** `voice_thread` was red at dispatch. The 2026-09-17 follow-up prepares the native
  library during initial boot and measures the first switch pull below one 90 Hz frame.

### Fence, dependencies and size

`world/tower_frequency.gd` (deleted), `autoload/headphones.gd`, `world/radio_*.gd`, `world/sky.gd` (one line),
`autoload/net.gd` (the clip kind), the AUDIO section in `clipboard_page.gd`, `kokoro-gd/src/**` (option B),
`tools/export.ps1`, and tests.

**Starts when 9 step 5 (the long message) has merged, and after 12** (slot B). **3 to 4 lane-days**, with the most
unknowns after 9.

### Dispatch essentials

- **Step 0 is findings, not code:** the export, the Steam voice API, and where PCM comes from. Send them before step 1.
- `kokoro-gd` has **no binding that returns samples** today. `SynthEngine::synthesize_text` is where they are.
- Only the host generates. The host plays its **own decoded clip** through the same path as clients.
- Reuse item 9's long message. Do not raise `HELLO_MOST_BYTES`.
- `chatter` and `voice_thread` are main-only. Junction the model folder into your worktree to run them.

---

## ITEM 15. Steam name, and changing name and colour in the lobby — BUILT 2026-09-16 (`lane/item15-roster`)

Protocol v6 carries synchronized music plus a validated client card and revisioned authoritative roster, including
compact forms in the bounded level hello for late joiners. `Net.name_of` and `Net.colour_of` are the shared display
API. The briefing room has a beam/keyboard roster
board with eight fixed colours; profiles persist in `user://player.json`, and an already-open Steam directory supplies
the initial persona without starting Steam. `names` exercises validation and the real controls/surfaces;
`names_peers` proves convergence on a host, an initial client and a late client over ENet; `names_shot` records the
board and coloured pilots. The screenshot is `screenshots/2026-09-16/cockpit-item15-names.png`.

### The ask

> "show the steam username, and provide users the ability to change their name and color in the lobby."

No ANSWERED section. From plan.md: there is no player name anywhere today; the Steam name is where the default comes
from; the colour shows in all three places (the pilot model, the CREW page and the map arrows), from one place. The
lobby lane's carried entry: the briefing room is big and bare, and names are what give the wall beside the board
something to say. The session lane's carried entry: `notice_words` and the CREW page should change together, from one
lookup.

### What exists today (read)

- `world/sky.gd` line 1588: `pilot.setup(client_id, "Pilot %d" % client_id)`.
- `player/remote_pilot.gd` `setup()` colours head, hands and label from the id's hue.
- `ui/menus/clipboard_page.gd` `_a_craft`: "PLAYER %d'S" and "PLAYER %d".
- `autoload/net.gd` `notice_words`: "PLAYER %d JOINED/LEFT", and "YOU JOINED AS PLAYER %d".
- `FlightLevel`'s `SESSION_REPORT crew=` line uses client ids, and **suites parse it**, so keep the ids there.
- **Steam:** `net/steam_lobby_directory.gd` calls `steamInitEx` only when a Steam button is pressed. The persona name
  function (`getPersonaName`) is not called anywhere (**UNVERIFIED** name on GodotSteam 4.21; read it off the binary
  as `tests/steam_probe.gd` does).
- **The lobby:** `world/briefing_room.gd` hangs a `ChartMenu` launch board on the wall (`_hang_the_board`,
  `BOARD_WIDE` 2.2 m, `BOARD_HIGH` 1.6 m), handed to `PilotRig.pointer_panels`. `tests/lobby.gd` §3 fails if any prop
  gets a script, and the board is not a prop.
- **The session trap** (`cockpit/agents.md`): `Sim.client_of_peer` is 0 at admission, so a roster keyed
  by client id must wait for sync to name the peer (`_keep_the_notices` already does this).

### The approach, in steps

**Step 1: the roster, on the wire.**

- `card` / `card_heard`, joiner → host: `{name, colour}`, repeated until heard.
- `roster` / `roster_heard`, host → all: `{n, cards: [{player, name, colour}]}` (8 × about 40 B, under 512).
- The level hello carries the roster.
- The host validates:
  - a name is trimmed, 1 to `NAME_MOST` = 16 characters, printable, with control characters removed, and clamped with
    a warning;
  - a colour is an index 0 to 7 into `PlayerColours.PALETTE`, and anything else is dropped with a warning;
  - two players with the same name keep both, with the second shown as "NAME (2)";
  - one card per peer.
- `Net.name_of(client)` and `Net.colour_of(client)` (S4) answer from the roster, falling back to "PLAYER n" and the
  hue.
- *Rejected:* free RGB, which gives eight near-identical greens and a validator that must judge contrast; and names as
  a sync component, which is C++ for a string that changes twice an evening.

**Step 2: where the name comes from.**
On this machine: the Steam persona if Steam is initialised (question 4), else `user://player.json`'s last typed name,
else "PLAYER n". The Steam call is reached through `Engine.get_singleton("Steam")`, as `SteamLobbyDirectory` does, and
injectable for suites (the `Net.draw_code` pattern).

**Step 3: the surfaces.**

- `RemotePilot` label and colour, the CREW page, `notice_words`, and the map arrows (through S4, already).
- **A roster board** in the briefing room beside the launch board: every player's name in their colour, and for this
  machine's player a NAME field (a `CodePad`-shaped keypad of letters and digits for the beam, plus the desk keyboard)
  and eight colour swatches.
- The board announces and `FlightLevel` decides.

### The gate

- `tests/names_peers.gd`, a child host and this process joining, in the lobby (named).
  - The joiner types "ALICE" on the roster board's field and presses the fourth swatch through the real path (a
    `LineEdit` typed into, and a beam press on a `Button`).
  - The host's CREW page, `notice_words`, `RemotePilot` label and colour all show ALICE in palette colour 3.
  - A late second joiner receives the roster.
  - A 300-character name is clamped with a warning; colour 99 is dropped with a warning.
  - The Steam path uses a stubbed persona Callable.
  - *Mutants:* the host takes a joiner's card without the clamp (clamp red); the roster missing from the level hello
    (late joiner red).
- `tests/lobby.gd` §3 still counts the props as inert.
- `tests/names_shot.gd` (the picture): the briefing room with two coloured pilots and the roster board.

### Affected set

`lobby`, `lobby_peers`, `lobby_shot`, `notices`, `clipboard` (CREW), `crew_shot`, `crew_peers` (the report line keeps
ids), `level_hello`, `steam_join`, `code_pad`, `no_vr_flight`, `lint` and `docs`. New classes: re-import at merge.

### Risks and the first measurement for each

- **The persona function name on GodotSteam 4.21.** Read it off the binary (`tests/steam_probe.gd`'s method).
- **A text keypad in a headset is tedious.** Keep names at 16 characters and offer the Steam name as the default. A
  person decides by trying it.
- **Wall space.** The board's size is read from the room (`INSIDE`, `desk_places`), not typed. Look at the picture.

### Fence, dependencies and size

`autoload/net.gd` (roster), `player/remote_pilot.gd`, `ui/menus/clipboard_page.gd` (CREW), `world/briefing_room.gd`, a
new `ui/menus/roster_page.gd`, `world/sky.gd` (pilot setup), and tests.

**Starts when 19 has merged** (S4's functions exist) **and 12's `net.gd` step has merged.** **2 to 3 lane-days.**

### Dispatch essentials

- **One lookup:** `Net.name_of` and `Net.colour_of` (lifted by item 19). Every surface calls them.
- `Sim.client_of_peer` is 0 at admission. Key the host's cards by peer and publish them by client id once sync names
  the peer, as `_keep_the_notices` does.
- Names and colours are untrusted input. Clamp names, drop bad colours, and warn on every drop (rule 8).
- Steam is not initialised unless a Steam button was pressed. Do not start it for a name (question 4).
- The roster board is not a prop. `tests/lobby.gd` §3 must still see the props inert.

---

## ITEM 18. Spawning a vehicle and getting into it, in multiplayer (`lane/item18-issue`) — BUILT 2026-09-16

### The ask

> "Let's also make it so we can spawn new vehicles and enter them (this doesn't appear to work in multiplayer yet)."

No ANSWERED section. From plan.md: reproduce first; the craft page asks for a kind and the server decides the seating;
read `lane/guns`'s findings, because "a client asks and the server decides" is the pattern.

### Built result and reproduction

The frozen-tip behavior was traced before the change through the real page and server paths, then
kept as executable coverage. `craft_peers` presses the actual CRAFT and TRAFFIC buttons over ENet.

| path | before | built result and evidence |
|---|---|---|
| Existing free PLANE | Green: `switch_kind` found the first free seat. | Still preferred; the peer run does not add a vehicle and both peers agree the joiner is in `plane`. |
| No spare of the named kind | Red: `switch_kind` returned silently and the board timed out to `NO_MOVE`. | Two same-tick SEGWAY presses create two distinct issued one-seat craft; both peers agree on `segway:1/segway:2`. |
| Lobby PLANE | Red: the room seeded only occupied arrival segways and the press timed out. | No craft is made; both peers stay at two vehicles and the joiner receives `kind_no_issue_place` plus "This level has no clear place to issue a PLANE." |
| TRAFFIC `+ plane`, then CRAFT PLANE | Green when the unchanged walk reached a free seat in the AI craft. | Still green: the real ADD button increases the replicated vehicle count, then the joiner reaches a free plane. ADD remains host-owned AI traffic, separate from issuance. |

Native `tests/issue.gd` additionally proves an existing free craft wins, blocked places are counted,
two same-tick requests get distinct craft, and moving the last player out sweeps an issued craft. Its
sweep assertion goes red if `issued_.insert` is removed. The answer fit in `CabinOwner`'s four-bit
reason field: `kind_moved` and `kind_no_issue_place` are reasons 8 and 9.

Both full modules were built for stock and double precision and their DLLs propagated to cockpit,
racer, and vrplayground-2 under the repository's precision rules. The affected gates passed:
`lint`, `issue`, `craft_peers`, `terrain_level`, `lobby`, `lobby_peers`, `crew_peers`, `crew_sync`,
`no_vr_flight`, `clipboard`, `ship_legs`, `seabed`, `crew_join`, `cockpit_loopback`, and
`racer_smoke`. After merging the later builder, radio, load, and model fixes, the combined matrix also
passed `docs`, broad `smoke`, `stations`, `craft_package`, `builder_authority`, `bulk_peers`, and
`radio_clip`. Every launch and nested peer used both
`--xr-mode off` and `--desktop-only`, with zero OpenXR initialization/runtime lines.

Visual proof is `screenshots/2026-09-16/cockpit-issued-planes.png`: two planes at the same 17 m
centre spacing used by `FlightLevel` and the native span clearance. Regenerate it with
`res://tests/craft_issue_shot.tscn` and `--out=<png>`.

### What existed at dispatch (read)

- **The press path:** `ClipboardPage` CRAFT → `chose_kind` → `PilotRig.ask_for_kind(kind)` → `Sim.next_menu_request()`,
  with `kind_wanted` on the input frame. The rig waits in `_kind_press_answered`, and on patience says
  `ClipboardPage.NO_MOVE` ("The host didn't move you to a %s. Try again.").
- **The server:** `CockpitWorld` notes a changed `menu_request` and calls `switch_kind(client, kind_wanted)`.
  **`switch_kind` only moves the pilot into an existing craft of that kind with a free seat, and never spawns one.** It
  returns silently when there is none.
- `spawn_pilot` issues the arrival craft (`issued_.insert`). `sweep_empty_issues` retires an issued craft when it is
  empty. `seat_client(client, vehicle, seat)` and `despawn_vehicle` are bound.
- **The island:** `FlightLevel._on_sim_ready` spawns `Terrain.spawns()` (one table, a few spares per kind) and
  `Terrain.ai_fleet`. **The lobby** (`_indoors`) seeds nothing, so a craft press there never has a craft.
- **TRAFFIC's ADD** is host only, and says so on a client.
- **Coverage:** `tests/no_vr_flight.gd` §4 presses H (the next kind, `BUTTON_KIND`) on a **client** over a real socket,
  and it passes. No suite presses a **named** kind on a client when none is free.

### The approach, in steps

**Step 0: reproduce, and record which path the user meant.**
`tests/craft_peers.gd`, a child host and this process joining, on the island (named). Four sections, each recording
red or green:

- (a) the joiner presses PLANE on CRAFT with a spare plane free;
- (b) the host takes the island's only free craft of a kind first, then the joiner presses that kind;
- (c) the joiner presses PLANE in the lobby;
- (d) the host presses ADD PLANE, and the joiner then presses G or PLANE.

**Predicted from the code:** (a) green; (b) red after the rig's patience, with NO_MOVE on the board; (c) red; (d) green
only if the added plane has a free seat and is reached by the walk. First count the spares per kind in
`Terrain.spawns()` so (b) is built on a real "only one". Send the table to team-lead with question 6's answer if it
has come.

**Step 1 (C++): a press nobody can answer issues a craft, at a place the level gave.**

- `CockpitWorld::add_issue_place(kind, position, yaw, velocity)` is world build, identical in every world, like
  `add_ai_waypoint`.
- `switch_kind` with no free craft of the named kind **records the press**. After the jobs (as `answer_the_joins`
  does, because a job may not create entities), the server issues a new craft at the first clear place for that kind:
  - clear = no vehicle within the kind's own span, from `kind_geometry`;
  - `move_pilot` puts the asker in it, `issued_.insert` adds it, and `launch_if_grounded` runs as today.
- No place for that kind means a refusal, counted and warned once a second (`refuse_boarding`'s shape).
- **UNVERIFIED:** whether the refusal can reach the player's board as an answer. `CabinOwner`'s answer is a join
  answer; check its bit width in `cockpit_components.hpp` before adding a reason. If there is no room, the rig's
  NO_MOVE stays, and it says so in the doc block.
- *Rejected:*
  - **A GDScript host spawning and `seat_client`.** The craft would not be issued, so it is never swept, and there
    would be two paths for one seating decision.
  - **Spawning inside `switch_kind`.** A job writes only what it declares.
  - **The walk choosing a craft elsewhere.** It already does; the point is that there is none.
- *Gate:* an addon-level check (`crew_join` or a new `tests/issue.gd`):
  - with one place registered, two clients pressing PLANE on one tick get two craft;
  - a third with every place blocked is refused and counted;
  - leaving an issued craft empties it and the sweep removes it;
  - a craft already free is still preferred over issuing one.
  - *Mutant:* skip `issued_.insert`, and the sweep check goes red.

**Step 2: the level gives its places.**
`FlightLevel` registers issue places: per pilotable kind, the spawn table's own place for that kind (`Terrain.spawns()`)
offset along its row, and on generated ground over the highest surface within its room (`Terrain.highest_near`). A room
level registers none, so the lobby refuses in words.
*Gate:* `craft_peers` sections (b) and (c) go green or refuse in words. Plus `terrain_level` (spawns clear of the
ground), `smoke`, `lobby` and `no_vr_flight`.
*Picture:* two players' planes side by side on the island's apron, issued within a second of each other.

### Affected set

- Step 1 (C++): the full `run_all`, the addon suites and `racer_smoke`.
- Step 2: `smoke`, `terrain_level`, `lobby`, `lobby_peers`, `crew_peers`, `crew_sync`, `no_vr_flight`, `clipboard`,
  `ship_legs` (a ship spawn's place) and `seabed`.

### Risks and the first measurement for each

- **The user meant something else.** Step 0's table and question 6.
- **An issued plane in the air collides with the spawn table's plane.** "Clear" is measured by span. Count collisions
  in step 2's gate.
- **Players spam kinds and fill the world.** The sweep removes empty issued craft. Check that pressing PLANE ten times
  leaves at most one issued plane per player.

### Fence, dependencies and size

`ashiato-gd/**` (step 1), `autoload/sim.gd` (a wrapper), `world/sky.gd` (issue places), `world/terrain.gd` (read only;
ask whoever holds it), and tests.

**Starts when all of 10 has merged** (slot A). 10's C++ step lands early, but starting 18 then would make a fourth
lane. **1.5 to 2 lane-days.**

### Dispatch essentials

- `switch_kind` never spawns. It walks existing craft of the kind. Reproduce four paths before changing anything.
- A craft made for a player must be **issued** (`issued_`) or it is never swept. Only C++ can do that.
- Issue after the jobs (as `answer_the_joins`), at places the level registered in every world.
- C++ brief S6. This is the only C++ in flight at the time.

---

## FOLLOW-UPS THIS PLAN DELIBERATELY DOES NOT SCHEDULE

From `plan.md`'s loose list and the learnings. Each waits for a stated reason.

- **DONE 2026-09-17: the 63-frame lead clamp.** Cockpit's history is 128 frames; exact 300/350 ms one-way links
  now starve zero frames at prediction leads 72/84 (600/600 starved before).
- **DONE 2026-09-17: delta-encoded `ControlInput` (protocol 9).** Steady flight is 70.5 B/tick and three moving
  tracked poses are 264.3 B/tick, from 338; Item 10's 200-craft upstream falls from about 44 to 13.0 kB/s/client.
- **MEASURED AND REJECTED 2026-09-17: distance priority and per-entity interpolation.** The repeated 200-craft
  2/4/8-peer cells have 0.0% frozen watched ticks, a 1.0 p99/median step, and a one-tick traced update gap against
  two predicted ticks. Keep the existing prioritizer seam; add policy only when a larger rung shows a freshness loss.
- **DONE 2026-09-17: `voice_thread` first-use hitch.** The optional native library is prepared during initial boot;
  the 325 MB model and worker remain lazy. First VOICE activation now stays below one 90 Hz frame.
- **DONE 2026-09-17: `hitch`'s wall-clock flake.** The verdict uses the median and an explicit floor instead of
  letting one scheduler interruption decide a deterministic simulation check.
- **DONE 2026-09-17 (`lane/level-cues`): the level-change jolt is covered.** A host-authoritative, revisioned,
  content-hashed cue fades every machine to a persistent black CanvasLayer before replacement and reveals after local
  readiness. Real ENet tests cover delayed and mid-countdown joiners; the screenshot probe records before/black/after.
- **DONE 2026-09-17: sky-change notices and latest-only display.** The revisioned sky update announces on every
  machine and a newer notice replaces the older one without hiding a level-transition cue.
- **DONE 2026-09-17: child-process and external waits use monotonic wall time.** The older frame-count waits were
  swept after the multiprocess suites landed; simulated settling still deliberately uses frames.
- **Desk mouse-look confirmed at a window.** It needs the user's mouse, not a lane.
- **The left trigger braking before a pinch lands.** A headset feel question for the user.
- **DONE 2026-09-16: `alpha` build compatibility and owned Steam searches.** The public channel and compatibility
  identity are separate; request ownership, browse/code overlap, timeout recovery, and mismatch refusal have suites.
- **DONE 2026-09-17: `crew_sync` covers every authored flying station.** The test derives flight seats from each
  immutable package and walks the full catalogue, including the fighter and UH-60.
- **`CrewControls::hands_on` as seat 7. Already done:** `cockpit_components.hpp` line 292 is "SEVEN, BECAUSE THE WIRE
  CARRIES THREE BITS". The loose list is stale here, and team-lead should strike it.
- **Item 22's filed C and D** (a "face the gun" snap turn, a magnified periscope glass). These wait for the user's
  headset verdict.
- **The four questions waiting on the user** (ditching, the seabed, battleship roll, stabilised guns). None blocks
  these eight items.
- **Joystick devices (the other reading of 16).** Waits for the user to say a stick still does nothing now that the
  fighter has a gun.

---

## WHAT WAS READ, AND WHAT IS STILL UNVERIFIED

**Read:**

- `CLAUDE.md`, `cockpit/plan.md` (all), `running_a_team_here.md` (all), `cockpit/docs/crew.md`,
  the level hello and notices in `cockpit/docs/world.md`, and the `todo/` folder.
- The `cockpit/agents.md` sections cited above.
- Code:
  - `ui/menus/clipboard_page.gd` (all);
  - `objects/seats/cockpit_layout.gd`, `cockpit_station.gd` and `control_catalogue.gd` (all);
  - `objects/vehicles/vehicle_catalogue.gd` (all);
  - `objects/seats/seat_wheel.tscn`;
  - the `throttle_lever.gd` bindings;
  - `flight_page.gd` rows and `mfd_page.gd` structure;
  - `pilot_rig.gd` (`_bindings_for`, `legend`, `add_control`, `save_the_cockpit`, `ask_for_kind`);
  - `autoload/sim.gd` (API, spawning, seating, carrying);
  - `autoload/net.gd` (carriers, the hello, sky, notices);
  - `autoload/headphones.gd` (header and API);
  - `world/tower_frequency.gd` (all);
  - `world/sky.gd` (`_ready`, seeding, `add_traffic`, status);
  - `world/briefing_room.gd` (header and API), `world/world_map.gd`, `ui/menus/code_pad.gd`,
    `player/remote_pilot.gd`, `ui/snap_board.gd` (header);
  - `tests/input_window.gd` (header and pump), `tests/net_jump.gd` (structure), `tests/no_vr_flight.gd` §4,
    `tests/builder.gd` (header), `tests/suites.txt`;
  - in `ashiato-gd/src/cockpit/cockpit_world.cpp`: `default_bus`, `loadout_of`, `add_ai_waypoint`,
    `spawn_ai_vehicle`, `despawn_vehicle`, `hold_course`, `switch_kind`, `free_seat`, `move_pilot`, `seat_client`,
    `spawn_pilot` (issued), `sweep_empty_issues`, `net_status`, `timing`, `resim_stats`, `wire_range`, and the bound
    method list;
  - ashiato-sync `types.hpp` and `client_update_scheduler.cpp` (MTU splitting);
  - `racer/autoload/network.gd` and `race.gd` (latency);
  - kokoro-gd's bound methods and signals;
  - `export_presets.cfg`, `.gitignore`, and the export templates folder.

**UNVERIFIED, and what confirms each:**

| Claim | How to confirm |
|---|---|
| `SceneMultiplayer.send_bytes` channels on GodotSteam | its multiplayer peer source |
| `ENetConnection` statistic enum names, and ENet's MTU on 4.7.2 | docs.godotengine.org |
| `AudioStreamOggVorbis.load_from_file` on 4.7.2 | the docs |
| No runtime Vorbis or Opus encoder | the docs |
| Playback position advancing headless on the Dummy driver | a throwaway probe |
| `unproject_position` headless | a throwaway probe |
| `crowd_sight`'s client-seating calls | read the file |
| `FlightPage` being handed `state["fitted"]` | `CraftDisplay.show_state` |
| `CabinOwner` answer bit width | `cockpit_components.hpp` |
| GodotSteam persona function name | `tests/steam_probe.gd`'s method |
| One layout's JSON size | item 9's census |
| 58 MB of music inside an export today | item 12's export measurement |
| The Steam voice API having no injection call | item 21 step 0 |

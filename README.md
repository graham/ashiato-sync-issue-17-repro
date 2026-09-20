# A reproduction for ashiato-sync issue #17

A joining client stops being told about a replicated entity for over a thousand ticks,
while nothing is refused, nothing is lost, and every total looks healthy.

This repository reproduces it on demand, on one Windows machine, in about forty seconds a
run. It is the flight simulator the fault was found in, cut down to the parts that carry
it, with the two scripts below on the front.

```
find_once.bat        set everything up, run it once, print a verdict
find_repeating.bat   run it until it fails, which is usually inside two minutes
```

**`find_once.bat` may well say "healthy this run" on your machine.** It reproduces about
four runs in five here. That is why there are two scripts: the first proves the rig works,
the second gets a failure in front of you.

Exit code `0` means the bug appeared. That is backwards from a test and the right way round
for a reproduction.

## What you need

Git, CMake, Ninja, and the Visual Studio 2022 Build Tools with the C++ workload. CMake and
Ninja are found on `PATH`. Nothing else: the engine is downloaded and the four C++
dependencies are cloned at pinned revisions by the setup step, which both scripts run and
which is safe to run twice.

The first run builds a GDExtension from source and takes ten to twenty minutes. Every run
after that is about forty seconds.

You do **not** need a double-precision Godot. The game is normally run on one, but the
fault has nothing to do with precision and reproduces identically on the stock 4.7.2
download, which is what the setup fetches.

## What it actually does

Two real OS processes talk over ENet on the loopback. A host serves about 146 replicated
aircraft; one client joins 300 ms later. Both are given a priority sphere of 1000 m
weighted 4.0 inside against 1.0 outside, so craft near the joining client are chosen four
times as often as craft far from it. The sphere is a rate and never a filter: a craft
outside it must still arrive, and keep arriving.

After a three second settle, the joining client is watched for eight seconds. It reports,
per craft, how many server frames have passed since the newest `VehicleState` record it
decoded for that craft — counted at decode time, in `ComponentReceived`, before any apply.

Only craft moving faster than 5 m/s are judged. The level has aircraft that legitimately
never move, and sync correctly sends nothing for an entity that has not changed, so
"everything moved" would fail for the wrong reason. A moving craft is dirty on the host
every tick, so its staleness is exactly how long it waited to be chosen.

**The allowance is computed from the run, not typed in.** With N near craft at weight k and
F far ones at 1, a far craft's turn comes round every `A = (k*N + F) / M` ticks when M
records fit in a tick. The client reports the M it actually achieved, so the bound follows
the run. It lands near 10.

A healthy run has the stalest far craft at 1 tick. A failing run has one craft at 500 to
1500.

## What a failure looks like

```
ISSUE17 near=4 far=119 per_tick=64.33 k=4.0 A=2.10 bound=10 near_worst=0 far_worst=1342 unseen=0 reports=39
ISSUE17 stalest_far_entity=4294967402 last_server_frame=274 newest_server_frame=1616 client_id=2

---------------- ashiato-sync issue #17 ----------------
  scenario : 146 craft on the host, one joining client, two OS processes over ENet
  measured : the joiner's stalest moving FAR craft waited 1342 server frames for an update
  allowed  : 10, computed from the 64.33 records a tick this run actually achieved
  VERDICT  : BUG REPRODUCED. One craft waited 1342 ticks where 10 was the allowance, about 134x over.
--------------------------------------------------------
RESULT=FAIL far_craft_stay_fresh
```

`unseen=0` is worth a second look: nothing was lost. `stalest_far_entity` is the **joining
client's** entity id. The host numbers the same craft differently.

## Testing a candidate fix

Both scripts take the ashiato-sync revision to build against:

```
find_once.bat <40-character-revision>
```

It defaults to `fa4758f3de0c4e8ae0d2ee2dd5a6f51011ee5632`, `main` at the time of writing.
Two others are worth knowing:

| revision | what it is | what it does here |
|---|---|---|
| `fa4758f` | `main` | fails, about four runs in five |
| `e48b86d` | first bad commit | fails |
| `24334dd` | its direct parent | passes, stalest far craft 1 tick, every run |

Push a candidate to any branch this clone can fetch, pass its revision, and then use
`find_repeating.bat 40 all`, which runs all forty and prints the rate. **One clean run does
not prove a fix** when the fault only appears in four runs of five. Twenty in a row is
worth something.

## Getting the raw traces

The same scenario writes `ashiato-sync`'s own trace directories when asked. Build against
`issue-17-diagnostics` and pass a directory:

```
find_once.bat a4d8b9499c11345cc6d26a9ab909821884378709
powershell -ExecutionPolicy Bypass -File cockpit\tools\issue17\run_repro.ps1 -Repeat 40 -TraceRoot D:\issue17
```

That writes a directory per run holding the server trace, the joining client's trace, both
application logs and a manifest. About 210 MB a run, which compresses to about 14 MB. Both
processes are asked to leave rather than killed, so the asynchronous writers flush — a
killed process loses the end of the run, which is the part with the stall in it.

## The layout

```
find_once.bat, find_repeating.bat      the two entry points
cockpit/                               the Godot project
cockpit/tests/issue17_repro.gd         the reproduction, and what it measures
cockpit/tools/issue17/setup.ps1        dependencies, engine, build, import
cockpit/tools/issue17/run_repro.ps1    one run, judged, or many
ashiato-gd/                            the GDExtension binding Godot to ashiato-sync
tools/get_godot.ps1                    downloads the stock editor
```

`ashiato`, `ashiato-sync`, `box3d`, `godot-cpp` and `_tools` are cloned or downloaded
beside these and are not in this repository.

## Honest notes

- The fault is intermittent. Everything above is written around that and none of the
  numbers here come from a single run.
- Timing measurements on a loaded machine move. The runs quoted were taken with 8 to 10
  other Godot processes on the box, and one run passed with 6, so load does not appear to
  drive it.
- This is a cut-down copy of a working game, not a minimal case. Reducing it to one has
  been tried repeatedly and has not worked: the same scenario built in-process, against the
  library directly, stays healthy. That failure to reduce is itself reported on the issue.

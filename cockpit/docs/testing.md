# The cockpit test framework: what it is, what it costs, and what to do with it

*An audit, 2026-09-20, by `lane/testaudit`. Nothing in the cockpit test suite was changed to produce it.*

Every number here came out of two scripts in `research/test_audit/` or out of the runner's
own logs, and every one can be re-derived by running them again:

```
python cockpit/research/test_audit/measure.py    # parses suites.txt, counts the scripts, joins the durations
python cockpit/research/test_audit/groups.py     # puts each suite in a group and totals the groups
```

They start no Godot. The wall-clock in this document is not mine: it is the median of the
durations `run_all.ps1` itself wrote to `%TEMP%\cockpit_tests_*\durations.txt` after runs that
passed, across the seventeen checkouts on this machine that have one. Where a suite has never been
timed here, this document says so rather than guessing.

**Read sections 1, 5 and 6 if you have five minutes.** Section 5 is the strategy; section 6 is what
to do first. **If you read one recommendation, read 6.3**: nine of the fourteen obligations a new
craft kind carries are one missing registration, discovered nine times by nine separate Godot
processes, and a single suite replaces that discovery for about two days' work.

---

## 1. The size of it, measured

| | |
|---|---|
| suite rows in `tests/suites.txt` | **291** (266 `cockpit`, 25 `addon`) |
| distinct scripts behind them | 289 — `seabed.gd` and `testfield.gd` each serve two rows |
| lines in those scripts | **116,397** |
| `.gd` files under `tests/` | 416, totalling **144,935** lines |
| ...not named by any suites.txt row | 153 (probes, fixtures, robots, `class_name` libraries) |
| `.gd` files in the addon's own tests | 29, totalling 9,215 lines |
| **all test code in the project** | **154,150 lines** |
| assertions across all 291 suites | **5,577** |
| **lines of test code per assertion** | **20.9** |
| distinct check labels | 4,010; 90 of them are used by more than one suite |
| suites that define their own private check helper | **285 of 291** |

**How the assertions were counted, and why you can believe the number.** Nearly every suite defines
a helper of the shape `func _check(label: String, ok: bool, detail: String)` that records a failure
when `ok` is false. The script finds those helpers by shape — a function taking a boolean that
mutates state — and counts their call sites. It is validated against a figure the project already
knew: `suites.txt` records `smoke` writing `RESULT=PASS` on **215** checks, and the counter says
**216**. Call it accurate to about half a percent.

**The largest single test file in the workshop is not `smoke.gd`.** It is
`cockpit_loopback.gd`, in the addon's tests, at 3,917 lines, against `smoke.gd`'s 3,218.

### The tiers

`run_all.ps1` accepts exactly three tier names and stops the run on a fourth, so a typo cannot drop
a suite from a gate in silence. Parsing the tier column of each row rather than grepping the file
gives:

| tier | suites | lines | assertions | recorded wall-clock, serial |
|---|---|---|---|---|
| `core` | **39** | 20,278 | 1,036 | 518 s |
| `net` | 67 | — | — | — |
| `solo` | 18 | — | — | — |
| `slow` | **0 — there is no such tier** | | | |
| **no tier at all** | **184 (63%)** | **75,075** | 3,514 | 1,893 s over the 88 of them that have ever been timed |

A count made by grepping `suites.txt` for the tier names returns 42/70/20/1, because the file's own
long commentary discusses its tiers by name. The table above is what the runner actually parses.

### Four things this audit set out believing, and had to correct

Recorded because each was believed by somebody who knows this framework well, and because a wrong
number that nobody re-derives gets quoted for a year.

**There is no `slow` tier.** The brief for this audit said 42 core, 70 net, 20 solo and 1 slow. The
runner accepts exactly `core`, `net` and `solo` and stops the run on a fourth name. The counts are
39/67/18/0.

**The framework is bigger than `tests/`.** The addon project carries 25 more suite rows, 29 more
files and 9,215 more lines, and the largest single test file in the workshop lives there.

**There is no dead test code, and deleting files is not where the win is.** This audit began with
"orphan files" on its list. 153 of the 416 `.gd` files under `tests/` are not named by any
`suites.txt` row, and every one of them is a probe, a fixture, a robot or a `class_name` library
that a suite really uses — including two that looked unreferenced only because they are referenced
by class name rather than by file stem. Nothing here should be deleted to make the line count
smaller. The number that should come down is 20.9.

**And the most dramatic finding this audit produced was false.** The first detector written to
answer "which suites cannot fail?" looked for a raised flag and reported **136 suites that appeared
unable to fail**. That number is wrong. The house idiom is a private `_check(label, ok, detail)`
helper per suite, and there are three variants of it; once all three are counted the answer is
**three** suites, each small, each then verified by hand. It is in this document because a
fourteen-word version of it — "half the suites can't fail" — would have been repeated for a year,
and because the reason the detector was wrong is itself the finding in 4.3: with 285 private
harnesses, nobody can tell by looking whether a suite can fail.

---

## 2. What is good here, and was paid for

A report that finds everything wrong is not a report, it is a mood. These are load-bearing and
should survive any refactor.

**The `RESULT=` discipline.** Godot writes to stderr on a healthy run and a GDScript parse error
*hangs* rather than fails, so an exit code means nothing and a silent run means a parse error. Every
suite prints one line that says what happened. This is the single decision that makes the rest
possible, and it is worth noticing that the framework applies it to itself: a log with no `RESULT=`
line is the one thing no exit-code-based runner would ever notice. **`testfield_traffic`'s log looked
exactly like that and it was not a hang — see 4.2. It takes 776 seconds.** Which is the honest
version of the same point: the discipline told us something was wrong with that suite, and it was
wrong about *what*, because a suite that has not finished and a suite that never will are the same
silence.

**The error gate.** A suite that prints engine errors fails even when all its own checks passed. It
was bought by two million lines of unread stderr hiding a dead lift-zone shader.

**The deadline as a guard against a hang, not a performance budget.** The reasoning recorded in
`suites.txt` about `world_edge` — where a plausible story ("the thirty-seventh craft kind pushed it
over") was killed by measuring the suite alone at 65.3 s with 37 kinds and 68.7 s with 36 — is the
best short piece of engineering writing in this repository, and the rule it defends is right.

**The `solo` tier and the retry.** Eight unrelated checks failing at once is the signature of a
loaded desk, not of a fault; a real fault takes out one thing. A suite that fails in the batch and
passes alone is printed `PASS on retry (load)` and never hidden.

**Derived rosters.** `trim` asks the simulation which kinds have a wing rather than keeping a list;
`named_parts` walks `Sim.Kind` rather than an enumeration somebody maintains. This is CLAUDE.md's
rule 4 actually implemented, and it is why adding a craft kind is caught by suites nobody edited.

**One script, two rows.** `seabed.gd` serves `seabed` and `seabed_alpine`; `testfield.gd` serves
`testfield` and `testfield_traffic`. Same checks, different scene, different world. This is the
right pattern and section 6 recommends spreading it.

**The mutant discipline, where it has been applied.** `craft_model_audit` was sabotaged on purpose —
every craft built as a Cessna — and it *passed*, with twenty-five distinct fingerprints, because
three of the fingerprint's five fields were sourced from the identifier rather than from the
observation. Somebody found that by attacking their own test. That is the standard.

---

## 3. The ten groups

Every suite is in exactly one group. The rules and the named exceptions are in `groups.py`, so
disagreeing with this table is a one-line edit rather than an argument.

| group | n | lines | assertions | lines per assertion | recorded s | commits | written about | core | no tier | starts a 2nd engine |
|---|---|---|---|---|---|---|---|---|---|---|
| **shape** — what a thing is drawn like | 44 | 24,434 | 915 | 26.7 | 161 | 207 | 151 | 5 | 39 | 3 |
| **world** — levels, ground, scenery, weather | 42 | 18,711 | 946 | 19.8 | 613 | 222 | 166 | 1 | 38 | 5 |
| **flying** — how a craft flies, drives or sails | 41 | 15,195 | 537 | **28.3** | 564 | 132 | 155 | 3 | 38 | 3 |
| **devices** — controls and the pages that show them | 37 | 14,031 | 890 | **15.8** | 226 | 140 | 80 | 7 | 26 | 6 |
| **weapons** — guns, missiles, damage | 23 | 10,078 | 500 | 20.2 | 598 | 77 | 46 | 4 | 19 | 2 |
| **net** — the wire: authority and replication | 29 | 7,784 | 428 | 18.2 | 587 | 103 | 59 | 3 | 6 | 12 |
| **session** — getting in: lobby, identity, voice | 27 | 7,033 | 428 | 16.4 | 343 | 105 | 85 | 3 | 8 | 14 |
| **crew** — seats and stations | 20 | 6,749 | 252 | 26.8 | 263 | 97 | 101 | **10** | 6 | 2 |
| **upstream** — the extension underneath | 19 | 6,408 | 369 | 17.4 | 30 | 51 | 16 | 0 | 0 | 3 |
| **housekeeping** — lint, docs, the build, cost | 9 | 5,974 | 312 | 19.1 | 316 | 276 | 99 | 3 | 4 | 5 |
| **TOTAL** | **291** | **116,397** | **5,577** | **20.9** | **3,701** | 1,410 | 958 | 39 | 184 | 55 |

*"written about" counts the files in the learnings and todo folders that name the suite. "recorded s" sums
the runner's medians and only 191 suites have one, so the column understates every group.*

### Your three axes, and where they break

**Devices** (37 suites) and **stations** (inside crew, 20 suites) are real groups, they are small,
and they are in good order: `devices` has the *best* lines-per-assertion ratio in the framework at
15.8, and `crew` has ten of the thirty-nine core suites — more than any other group — which is
correct, because a seat is the thing every craft and every player has in common.

**Vehicles is not one axis. It is two, and separating them is the most useful cut in this report.**
`shape` asks whether a thing is *drawn* right; `flying` asks whether it *moves* right. They fail for
different reasons, cost differently, and want different treatment:

- `shape` is cheap to run and expensive to write: 24,434 lines for 161 seconds. It fails at build
  time, deterministically, from drawn vertices. Only 5 of its 44 suites are in `core`.
- `flying` is expensive to run and the worst value in the framework by code: 28.3 lines per
  assertion, 564 seconds, and **38 of its 41 suites are in no tier at all**.

**Together they are 85 suites and 39,629 lines — a third of the whole framework — and 77 of the 85
are in no tier at all.** A third of this project's test code is asking the two questions the user
cares most about, and almost none of it is in anybody's gate.

---

## 4. Four faults, each with its measurement

### 4.1 Sixty-three per cent of the suites are in no tier, and eighteen have never run

184 suites carry no tier. That by itself is not damning — the sweeper runs everything on main, so
untiered means "sweeper only" rather than "never". But the runner's own logs say otherwise.

In the main checkout's log directory (277 logs, spanning 2026-09-17 to 2026-09-20 09:21):

- **25 suites have no log on main at all.**
- **18 of those have never run in *any* checkout on this machine** — not on main, and not in the
  lane that wrote them: `adriatic`, `canyon`, `gliderlevel`, `gliderlevel_traffic`, `p38`,
  `radar_set`, `road_diesel`, `road_vehicles`, `rock_quality`, `seethrough`, `shore_structures`,
  `sight_line`, `trace_cost`, `trace_log`, `trace_replay`, `track_drawn`, `twin310`, `warbird_book`,
  `warbird_cockpit`, `warbird_guns`.

That is 18 suites of code that has been written, reviewed, committed and never executed since.
**The caveat, stated plainly: `%TEMP%` can be cleared, and a removed lane takes its logs with it, so
this is evidence of absence rather than proof.** But `road_diesel`, `track_drawn` and the
`warbird_*` set are days old and their own lanes' log directories still exist and do not contain
them, which is harder to explain away.

`build_stamp` is the live example the brief named, and it is not alone: it is in `suites.txt`, it is
not in `core`, and it is red.

### 4.2 Five reds were read out of the logs. RE-RUN, ONE IS RED AND ONE IS SLOW.

**This section is corrected, and the correction is the point.** The table below was built from the
runner's own logs across four days. Team-lead then re-ran all five on the tree the report describes,
and **three of them pass**. The logs were true when written and stale when read.

| suite | from the logs | re-run on main `2aa5b7fa` |
|---|---|---|
| `build_stamp` | `FAIL every_probe_that_photographs_a_stage_puts_the_stamp_in_it` | **still FAIL** — six probes have no `attach_to(`; `../../todo/dirtystamp--stamp-suite-red-and-outside-core.md` |
| `docs` | `FAIL every_test_scene_is_in_suites_txt_or_is_a_named_probe` | **fixed** at `d04b433d` — `splay_reel` had no `PROBES` entry |
| `intercom_peers` | `FAIL` | **PASS** in 11.5 s — the log predated the CRLF fix in `f29fd6b5` |
| `hitch` | `FAIL` | **PASS** in 7.8 s |
| `testfield_traffic` | **no `RESULT=` line at all** | **PASS — in 776.1 s** |

**`testfield_traffic` is not a hang. It is a thirteen-minute suite.** Its row carries its own
1800-second deadline, so it is inside its budget and the runner is content; the log that showed four
lines and silence was a run that had not got there yet. **A suite whose honest runtime is 776 s is
indistinguishable from a hang while you are watching it**, which is why it read as one — and it is
the single most expensive suite in the framework by a wide margin, against a 3,701 s total for the
191 suites that have a median at all. That is a cost finding, not a correctness one, and it belongs
in §5's pare-down list rather than here.

**The general lesson is worth more than the five rows.** A log says what happened when it was
written. **Re-run before reporting a red**, and prefer a suite's own deadline column to your
impression of how long it should take. Two of the three false reds here were simply older than the
fix that cured them — and this report would have sent somebody hunting two bugs that no longer exist.

**The log that made it look like rule 1's class is below, and it is worth keeping** — because this
is what a slow suite and a hung one look like to a reader, and they look identical. Four lines of
progress and then silence. The only thing that told them apart was running it and waiting thirteen
minutes:

```
BUILT=1789850225
[testfield] PASS the_extension_has_the_ground_and_the_world (engine 4.7.2-stable (custom_build), double=true)
[testfield] PASS the_drawer_lists_the_test_field_usable (The test field, ground { "world_half": 32768, ... })
[testfield] PASS the_test_field_can_be_chosen ('')
[daylight] 10:28 DAY
[XR] Desktop: W nose down - S nose up - Left/A roll left - ...
```

Three checks passed, the level came up, the key list printed, and then nothing — no fourth check, no
`RESULT=`, no error. It is the only one of the seven suites with a `.first` retry log that produced
no result on either attempt. An exit-code-based runner would have called this a pass. It is also the only one of the seven suites with a `.first` retry log that never produced a
result on either attempt.

**And a fifth arrived while this was being written.** Rebasing this lane onto main on the afternoon
of 2026-09-20 turned `docs` red on `every_test_scene_is_in_suites_txt_or_is_a_named_probe`:
`splay_reel.tscn` had landed with no row in `tests/suites.txt` and no entry in `docs.gd`'s `PROBES`
table. Nothing runs it and nothing ever would have. It is one line to fix and it is somebody else's
line, but it is worth recording here because it is *this section's fault class arriving in real
time*, four days after the last one — and because `docs` is in `core`, so it was red in every lane's
gate on the whole machine until it was noticed. The check worked exactly as designed; what failed is
that landing a test scene and listing it are two separate acts.

**And this compounds with a rule the runner documents about itself: a suite that FAILS is never
scanned for engine errors**, because the gate runs only after `RESULT=PASS`. So these five logs are
also five logs in which any number of engine errors are sitting unread. The runs most likely to be
concealing an error are the runs already showing you a failure.

### 4.3 Two hundred and eighty-five private harnesses

285 of the 291 suites define their own assertion helper. There is no shared harness, and there are
**three different pass/fail idioms** in use across the tree: a `PackedStringArray` of failed labels,
a `bool`, and an `int` counter. This is not a stylistic complaint — it is measurable cost:

- **88 suites separately assert `extension_loaded`** and 47 separately assert
  `every_section_of_the_suite_ran`. Both are harness concerns. A harness would provide them once,
  for all 291, and the second one — which exists because a GDScript error ends a function and the
  caller carries on regardless — is exactly the kind of thing no suite should have to remember.
- **14 suites separately assert `a_port_was_free_to_host_on`** before starting a second engine.
- It cost this audit real time: a detector written against one idiom reported 136 suites that
  appeared unable to fail. The true figure is three, and all three are small and were checked by
  hand. If an auditor cannot tell at a glance whether a suite can fail, neither can a reviewer.

**The one thing that must not be forgotten when fixing this:** `testing_godot_headless.md` records
that a suite naming a `class_name` does not parse in a fresh clone until the project has been
imported once, and a parse error hangs — a 240 s silent timeout instead of a two-second `FAIL`. A
shared harness must therefore be reached by `preload`, not by `class_name`, in any suite that runs
before an import.

### 4.4 The wall-clock class, quantified

`get_ticks_msec` appears at **321 sites in 71 of the 416 `.gd` files** under `tests/`, and
**26 of those files also advance on physics frames** — a budget measured in wall-clock against
progress measured in frames, which is the class `phantom--until-budgets-in-wall-clock-and-progresses-in-physics-frames.md`
opened. 58 of the 291 suite scripts time the wall clock directly.

This is also the mechanism behind the documented flakiness. `sweeper--flaky-suites-under-load.md`
is a real artefact and a real liability: seven suites needed the solo retry in the last run
(`bulk_peers`, `craft_peers`, `crew_peers`, `lamp_peers`, `no_vr_flight`, `sweep_peers`,
`testfield_traffic`), and the documented-flaky list is the most expensive place a real regression
can hide, because a red there has a ready-made innocent explanation. The fix is not a longer budget;
it is counting frames.

### 4.5 One latent vacuous pass, found and verified

`voice_thread` prints `SKIP voice assets unavailable` followed by `RESULT=PASS` when the Kokoro
model is missing. It is not firing today — all six live lanes have the model junction and the main
checkout's log shows it really ran — but a lane whose junction was removed (which is a documented
step when tearing a worktree down) would get a green `voice_thread` that tested nothing. It is one
line to turn into a `FAIL`, or into a check that records that it skipped.

This is the only instance found. Searching for the documented "clean-sheet early return reports
PASS" shape across all 291 suites returned four candidates and three were false positives —
`nobody_aboard`, for instance, records `_check("extension_loaded", ...)` *before* it finishes, so it
goes red properly. **The workshop has already internalised that lesson**; this is the one that got
away.

---

## 5. The strategy: what gets what kind of check

This is the part that was actually asked for. It exists so the next person writing a test knows
where it belongs, what tier it gets, and when not to write one.

### The four questions, in order

**1. What kind of thing is it?** That decides the group, and the group decides the shape of the
check.

| if the thing is... | it joins | the check is | it must have | tier |
|---|---|---|---|---|
| a model — a craft, ship, train, building | `shape` | measured off **drawn vertices**, against a published figure from outside the project | the source of the published figure, named, in the file | none; the cross-craft roster suites in `core` cover it |
| a way of moving — flight, drive, sail | `flying` | a **robot flying it through the pilot's own control frame**, asserting an envelope | where the thing went, printed; a control (the unchanged kind) | `core` if it walks every kind, else none |
| a seat or a station | `crew` | the geometry of a person in it, every seat of every craft | the derived roster — ask `Sim`, never keep a list | `core` |
| a device or a page | `devices` | pressed through **real input**, both `keycode` and `physical_keycode` | a focus gate, and an answer a robot can give | `core` if fitted to every craft |
| a weapon | `weapons` | fired from the seat, landing somewhere stated | the measurement in the detail line | none unless cross-craft |
| anything two machines can disagree about | `net` | **two real processes over a real socket** | `net`, and `solo` if it waits on a second engine | `net` |
| joining, naming, voice | `session` | the whole flow a person walks | a refusal test — the wrong code, the wrong build | `net` |
| a level or terrain | `world` | asked of the authority, walked over **every** level | a second level, or it proves nothing about levels | none |
| the build, the docs, the cost | `housekeeping` | a property of the repository | — | `core` |

**2. Can it fail?** Before committing a new suite, break the thing it checks on purpose and watch it
go red. If it does not, the check is about something other than its name says. The two shapes this
project keeps producing:

- **A fingerprint built from the identifier.** `craft_model_audit` fingerprinted on five fields,
  three of which came from `Sim.geometry_of(kind)`, so twenty-five Cessnas produced twenty-five
  distinct fingerprints. **Any field sourced from the identifier re-introduces the identifier's
  variety and hides the bug.** Fingerprint from the observation alone.
- **One of a thing.** An identity error is invisible at N=1 by construction. If a check
  distinguishes A from B it needs two of them, far enough apart that a mix-up is visible — the
  `Sim.current`/`Sim.server` bug hid for the life of the project behind a measured gap of 0.000 in a
  world with one aeroplane.

**3. What tier?** The rule that follows from section 4.1: **every row gets a tier, and "none" stops
being a tier.** A suite that is not in `core`, `net` or `solo` should have to say what it *is* in —
see section 6.1 — because a row with an empty last column is currently a row nothing is obliged to
run, and eighteen of them have never run at all.

**4. When not to write one.** Three cases, all of which this framework currently ignores:

- **When a roster suite already walks every kind.** `named_parts` and `joined_parts` walk
  `Sim.Kind`. A new airframe does not need its own `every_visible_mesh_is_a_named_part` — 13 suites
  have one anyway, and 10 have their own `it_is_one_object_and_not_a_set_of_parts`. Add the property
  to the roster; do not copy it.
- **When the thing is invisible to a headless run.** Layout, legibility, scale and "is it on screen
  at all" want a picture and a person, and a suite that pretends to check them costs wall-clock and
  buys a false sense of cover.
- **When the check would time the wall clock to measure something that advances on physics frames.**
  Count frames instead, or do not write it.

### And the thing the strategy has to fix: fourteen suites for one craft

`docs/craft.md` says a new craft kind must satisfy fourteen suites and that the list is a
floor. **The `breaks by` column in that table is the answer to whether fourteen is the right shape,
and it says no.** Nine of the fourteen are marked **FORGET** — meaning they are not broken by
anything the lane wrote, but by a registration it never made: a missing `Terrain.spawns` row, a
package not regenerated, a `fleet_size` default taken silently. craft.md's own account of the eight
reds two lanes shipped is that *"every one of the eight was a FORGET… all eight were code that was
not written."*

So fourteen-for-one-feature is not fourteen tests of a feature. It is **one registration contract,
discovered fourteen times, by fourteen separate Godot processes, each reporting only its own half**
— 4,489 lines and 122 seconds to tell somebody they forgot a table row. The fix is in section 6.3
and it is cheap.

---

## 6. What to do, in order

Sequenced by value per unit of risk. Items 1 and 2 are maintenance and should happen this week;
3 to 5 are the actual refactor; 6 is what not to do.

### 6.1 Tier every row, and prove the untiered ones run — half a day

Add a fourth tier name, `rare`, meaning "the sweeper's full run and nothing else", and give it to
every row that has no tier today. Nothing about what runs changes on day one; what changes is that
`-Tier core,net,solo,rare` is the whole file, an empty last column becomes impossible, and
`run_all.ps1 -Tier rare -List` answers "what has nothing watching it?" in one second.

Then run the 25 suites that have no log on main, once, and find out what state they are actually in.
**Expect reds.** 18 of them have not been executed since they were written, some of them for days,
against a tree that has moved under them. This is the cheapest item here and the most likely to find
something.

**Buys:** an honest answer to "is this suite run?" for all 291. **Risks:** the reds it finds are work
nobody has budgeted for. **Does not buy:** anything at all if the sweeper's full run is not actually
happening — check that first, because the evidence in 4.1 suggests it is not.

### 6.2 One red is left, and the re-run is the lesson — an hour, not a day

**This was costed at a day for five reds. Re-running them cost an hour and left one.** `docs` was
fixed at `d04b433d` (a `PROBES` entry for `splay_reel`); `intercom_peers` and `hitch` pass, their
logs having simply predated the fix in `f29fd6b5`; `testfield_traffic` passes in **776 s**, inside
its own 1800-second deadline.

**What remains is `build_stamp`**, genuinely red on six probes with no `attach_to(`, written up in
`../../todo/dirtystamp--stamp-suite-red-and-outside-core.md`. Half a day at most.

**Do not skip the re-run step when this recurs**, which is the transferable part: a log says what
happened when it was written, and three of these five were cured before anybody read them. The
standing rule that the error gate never runs on a red still holds — **fix the fail and re-run before
believing a clean log** — but it now has a companion: **re-run before believing a red, too.**

`testfield_traffic` at 776 s is the real item here and it is a cost, not a fault: **one suite is 21%
of the 3,701 s this whole framework has ever been recorded taking.** It belongs in the pare-down
list above, not in a red list.

### 6.3 One registration suite for a new craft kind — two days. **This is the headline.**

**What it costs today.** The nine FORGET rows of craft.md's checklist are `many_kinds`, `stations`,
`docs`, `shell_room`, `screens_face`, `crew_sync`, `joined_parts`, `no_vr_flight`, `vehicle_gym` and
`exhaust` — **4,489 lines, 140 assertions and 122 seconds of measured wall-clock, in nine separate
Godot processes**, to tell somebody they forgot a table row. Not one of them is broken by code the
lane wrote. Each reports its own half and none of them says the word "registration".

**What to write.** `craft_registered`: one suite, walking every kind, asserting the contract those
nine discover between them — a `Terrain.spawns` row exists; the station package matches the runtime
station; the handling table has a case rather than a default; the exhaust ports are a dictionary;
the enum matches the library's table; every seat has a station; the kind is reachable through the
real CRAFT path. One process, about three seconds, one `RESULT=` line naming every missing
registration at once.

The nine suites stay — they check real things and several are in `core`. What changes is that the
new kind's author gets **one red line naming everything they forgot**, instead of finding out from
`no_vr_flight` two suites away with no error printed. craft.md's checklist then becomes "run
`craft_registered` and your own suites", and the table of fourteen becomes documentation of what
those suites want rather than a list to work through.

**Buys:** the failure mode that has cost two lanes four red suites each. **Risks:** it duplicates
assertions that already exist, so it must be written to *fail differently* — naming the missing
registration, not the downstream symptom. **Costed at two days because the contract has to be read
out of nine suites first.**

### 6.4 A harness, reached by preload — three days

One file in `tests/`, called `suite.gd`, providing `check(label, ok, detail)`, the failure list, the
`RESULT=` line, the `extension_loaded` guard and the `every_section_ran` counter. **Reached by
`preload`, never by `class_name`**, for the reason in 4.3.

Convert suites as they are next touched rather than in one sweep — a 291-file mechanical edit is a
merge conflict with every live lane and buys nothing a gradual conversion does not. The measurable
target is the 88 `extension_loaded` checks and the 47 `every_section_ran` checks becoming zero
hand-written ones, and three pass/fail idioms becoming one.

**Buys:** a reader (and an auditor, and a reviewer) can tell whether a suite can fail by looking at
one file. **Risks:** the `class_name` trap, which is why it is a `preload`; and a shared file that
every suite depends on is a file whose bugs are everywhere at once, so it wants a suite of its own.

### 6.5 A measuring library for drawn geometry — three days, and the biggest code saving

81 suites read drawn vertices. The 23 airframe and model contract suites spend **15,404 lines on 536
assertions — 28.7 lines per assertion**, the worst ratio in the framework.

**But do not collapse those suites.** I expected to recommend it and the measurement says no: only
**18% of their checks use a label that five or more other suites also use**. 82% are genuinely
specific to that airframe — the Harrier's nozzles through 98.5 degrees is not a generic property and
should not be a generic check. The waste is not in *what* they assert, it is in the code it takes to
assert it: every one of them re-implements measuring a span, a length, a wound face, a named part
off an `ArrayMesh`.

So: a `drawn.gd` library of measurements in `tests/` (extents, span, length, winding, named parts,
joinedness, LOD budget), preloaded, with the per-airframe suites keeping their published figures and
their own peculiarities. And two properties that are currently asserted per-craft should move to the
roster suites that already walk every kind:

- `every_face_is_wound_outwards` is asserted in **15 separate suites and by no cross-craft suite at
  all** — so a craft with no suite of its own is never checked for winding. Put it in the walk.
- `every_visible_mesh_is_a_named_part` (13 suites) and `it_is_one_object_and_not_a_set_of_parts`
  (10 suites) already *have* cross-craft owners in `named_parts` and `joined_parts`. Those 23 copies
  can go.

Where a check really is generic across two subjects, use the pattern the framework already has and
has not spread: **one script, two rows**, as `seabed.gd` and `testfield.gd` do.

### 6.6 What I would not do

- **Do not delete test files to make the number smaller.** There is no dead code: all 153 `.gd`
  files not named by a suites.txt row are probes, fixtures, robots or `class_name` libraries that a
  suite really uses. Two that looked unreferenced are referenced by class name rather than by file
  stem. 144,935 lines is a real number and deleting is not how it comes down; the lines-per-assertion
  ratio is.
- **Do not merge suites into bigger ones.** `testing_godot_headless.md` is explicit that a 2,500-line
  shared suite is where tests go to be slow and to break each other, and `smoke` at 3,218 lines and
  183.9 seconds is already past that line. If `smoke` is touched at all it should be to *split* it —
  its 209 labelled checks span the level, the seats, the desk, the screens, the pages and the
  railway, and every lane pays 183.9 seconds for all of it.
- **Do not raise a deadline because a loaded desk was slow.** The `world_edge` reasoning in
  `suites.txt` settles this: raising one buys nothing and blinds the guard.
- **Do not retire the `upstream` group** (19 suites, 6,408 lines, 30 seconds) because it is about a
  car and this is a flight sim. It is the conformance layer under everything, it is the cheapest
  group per assertion to run, and it is the only thing that would notice the extension changing
  underneath.
- **Do not chase the 100 suites that have never been timed** by timing them. They will be timed the
  next time they pass; that is how `durations.txt` works.

---

## 7. What this audit did not do

**No mutants were run.** Six lanes were live and the brief preferred static measurement, so
"suites that cannot fail" is answered by static analysis verified by hand — three suites with no
detectable assertion, all small, plus the one vacuous pass in 4.5 — rather than by killing mutants.
A mutant pass over the 39 `core` suites is the obvious follow-up and would cost about an hour of
quiet machine.

**No suite was timed by me.** All wall-clock is the runner's own recorded medians, and 100 of the
291 suites have none.

**"Has it ever caught anything" is approximated**, by counting the files in the learnings and todo folders
that name each suite. 95 suites are named in none. That is a weak proxy — a lane does not write down
every catch — and it is reported as a prompt to look, not as a verdict. The five most written-about
suites are `docs` (42 files), `fit` (34), `air` (30), `stations` (26) and `fighter` (26), which is a
reasonable sanity check on the proxy: those are the suites people talk about.

# The airport traffic pattern, from the FAA's own words, and the numbers this game flies it on

Asked for on 2026-09-19: *"research landing patterns for airports, usually entering a "traffic pattern" either on the
right or left, usually 1000 feet above the airport, descending as they move through downwind, base and final. Sometimes
planes don't have to turn as much because they are "already on final" from a long distance away. Research this, and
build a ai mode that can honor this (while avoiding other planes)."*

Everything below the first rule is quoted or paraphrased from three public-domain US government works, read on
2026-09-19. Each is cited by paragraph so the next reader can check it rather than trust it:

- **[AIM]** Aeronautical Information Manual, chapter 4 section 3 ("Airport Operations") and 5-4-7.
  https://www.faa.gov/air_traffic/publications/atpubs/aim_html/chap4_section_3.html
- **[AC]** Advisory Circular 90-66C, *Non-Towered Airport Flight Operations*, 6 June 2023.
  https://www.faa.gov/documentLibrary/media/Advisory_Circular/AC_90-66C.pdf
- **[AFH]** *Airplane Flying Handbook*, FAA-H-8083-3C (2021): chapter 8 "Airport Traffic Patterns" and chapter 9
  "Approaches and Landings".
  https://www.faa.gov/regulations_policies/handbooks_manuals/aviation/airplane_handbook
  (AC 90-66C still says "chapter 7", which was the traffic-pattern chapter in the older -3B edition.)

## 1. The shape

**The legs** ([AIM] 4-3-2, [AC] appendix A):

| leg | what it is |
|---|---|
| departure | straight ahead along the extended centreline after take-off. The climb continues until at least **1/2 mile past the departure end** and **within 300 ft of pattern altitude** |
| upwind | the same line as the departure, flown after a go-around or when sequenced |
| crosswind | at right angles to the runway, off its take-off end |
| downwind | parallel to the runway, **opposite** to the landing direction |
| base | at right angles to the runway, off its approach end, from downwind to the extended centreline |
| final | along the extended centreline, in the landing direction, from base to the runway |

**Which side.** "Unless otherwise indicated, all turns in the traffic pattern must be made to the left" ([AIM] 4-3-3 b).
Right-hand patterns are published per runway end: charts print "RP" and the runway numbers, e.g. `RP 9, 18, 22R`
([AIM] 4-3-3 b). A segmented circle shows it with traffic pattern indicators ([AIM] 4-3-4). **So the side belongs to
a runway END, not to the airport**, and it is data.

**How high.** [AIM] 4-3-3 a:

- propeller-driven aircraft: **1,000 ft AGL** (305 m);
- large and turbine-powered aircraft: **not less than 1,500 ft AGL** (457 m), or 500 ft above the established
  pattern altitude;
- helicopters: a similar pattern at **500 ft AGL**, closer in, and they avoid the fixed-wing flow.

"The use of a common altitude at a given airport is the key factor in minimizing the risk of collisions" ([AFH] 8,
[AC] appendix A). "A pilot may vary the size of the traffic pattern depending on the aircraft's performance
characteristics" ([AIM] 4-3-3 a).

**How wide.** The downwind "is flown approximately **1/2 to 1 mile** out from the landing runway" ([AFH] 8). Nothing
in the three sources gives a wider figure for faster aircraft, but "jets or heavy airplanes will frequently fly
wider and/or higher patterns" ([AFH] 8).

## 2. Getting in

- **The 45° entry.** "Entry to the downwind leg should be at a 45-degree angle abeam the midpoint of the runway"
  ([AC] 11.3). The pattern is always entered **level, at pattern altitude**: "entries into traffic patterns while
  descending may create collision hazards and should be avoided" ([AC] 11.3; [AIM] FIG 4-3-3 key 1).
- **From the far side** ([AFH] 8, figure 8-3):
  - (A), preferred: cross over mid-field **at least 500 ft above pattern altitude**. Go well clear, about **2 miles**,
    descend to pattern altitude, and turn back to enter on the 45°. This is the teardrop.
  - (B), alternate: cross mid-field at pattern altitude on a crosswind and turn downwind. "This technique should not
    be used if the pattern is busy" ([AFH] 8; [AC] appendix A note).
  - Why the 45° is preferred: a pilot who can't fit in "can continue to turn away from the downwind, fly a safe
    distance away, and return for another attempt" ([AFH] 8).
- **Straight in.** Allowed, and **discouraged** at non-towered fields: "The FAA discourages VFR straight-in
  approaches". The pilot announces 8 to 10 miles out and has **no priority** over pattern traffic ([AC] 9.11.1). Those
  who fly one "should not disrupt the flow of arriving and departing traffic" ([AIM] 4-3-3 NOTE). At towered fields
  the tower may clear a straight-in ([AFH] 8), and heavy aircraft often fly one.

## 3. Coming down

- **Hold pattern altitude until abeam the approach end** of the landing runway on downwind ([AIM] FIG 4-3-3 key 2,
  [AC] 11.4, [AFH] 8). "At this point, the pilot should reduce power and begin a descent" ([AFH] 8).
- **Turn base at about 45°**: "The base leg turn should commence when the aircraft is at a point approximately 45
  degrees relative bearing from the approach end of the runway" ([AC] 11.4); a "medium-bank turn onto the base leg"
  ([AFH] 8). Save enough height for the base: "not descend too much on the downwind" ([AFH] 8).
- **Final:** "Complete turn to final at least **1/4 mile** from the runway" ([AIM] FIG 4-3-3 key 3).
- **The stabilised approach** ([AFH] 9):
  - a constant **3°** glide path to the touchdown zone;
  - speed **+10/−5 kt** of the landing speed, which is **1.3 VSO** when the manufacturer gives none;
  - **500 to 1,000 fpm** descent for light GA, reduced below 300 ft if it was steeper;
  - "go-around if unable to establish a stabilized approach by **500 ft** above airport elevation in VMC"; for a
    piston in the pattern, "an **immediate** go-around should be initiated if the approach becomes unstabilized
    **below 300 ft AGL**".
- **Speeds** ([AFH] 8 and 9): downwind 70 to 90 kt for typical piston singles; base about **1.4 VSO**; final
  **1.3 VSO**.
- **Round out (flare)** ([AFH] 9): begin at **10 to 20 ft**. Power to idle, and raise the nose so the aircraft settles
  as it slows. Touch down on the mains "at or just above the approximate stalling speed", axis parallel to the runway.
  No brakes at the moment of touchdown; brake as the weight comes onto the wheels.

## 4. Other aircraft

- **Right of way:** "the pilot of the aircraft at the lower altitude has the right-of-way ... However, the pilot
  operating at the lower altitude should not take advantage of another aircraft, which is on final approach to land,
  by cutting in front of, or overtaking that aircraft" ([AIM] 4-3-4 d; the same words in [AFH] 8).
- **Spacing:** "Before joining the downwind leg, adjust course or speed to fit the traffic" ([AFH] 8). Towers "require
  them to adjust flight as necessary to achieve proper spacing". Shallow S-turns are expected. **A 360° turn in the
  pattern is not**, because "it causes a chain reaction" behind ([AIM] 4-3-5). The tower's usual tool is extending
  the downwind and calling the base turn ([AIM] 4-3-2 b 4, "advise a pilot on an extended downwind when to turn base
  leg").
- **Go-around:** a normal manoeuvre. Among its reasons are "unexpected appearance of hazards on the runway, overtaking
  another airplane" ([AFH] 9). "If there is traffic on the runway, there should be sufficient time for that traffic
  to clear ... an early go-around may be in order" ([AFH] 8). "If the turn to final would create a collision hazard, a
  go-around or avoidance maneuver is in order" ([AFH] 8). The go-around runs "straight ahead until beyond the
  departure end of the runway" ([AC] 11.6), onto the upwind leg, offset to the upwind side so departing traffic
  stays in view ([AFH] 8).

## 5. Getting out

- "Airplanes on takeoff ... should continue straight ahead until beyond the departure end of the runway" ([AC] 11.6).
- Staying in the pattern: turn crosswind "beyond the departure end of the runway and within 300 feet below traffic
  pattern altitude" ([AC] 11.7).
- Leaving it: "continue straight out or exit with a 45-degree left turn (right turn for right traffic pattern)
  beyond the departure end of the runway after reaching pattern altitude" ([AC] 11.8, [AIM] FIG 4-3-3 key 6).

## 6. Categories

"Aircraft approach category means a grouping of aircraft based on a speed of VREF ... or if VREF is not specified,
1.3 VSO at the maximum certified landing weight" ([AIM] 5-4-7):

| category | A | B | C | D | E |
|---|---|---|---|---|---|
| 1.3 VSO | < 91 kt | 91-120 | 121-140 | 141-165 | 166 + |

Bank matters as much as speed. At 165 kt the turn radius is "4,194 feet using 30 degrees of bank" and "6,654 feet
when using 20 degrees" ([AIM] 5-4-7). **That is why this game sizes a pattern by turn radius rather than by a
table:** a radius is v²/(g tan bank), and it grows with the square of the speed.

## 7. The numbers the game flies it on

The game's aircraft are not the real ones' numbers. Its Cessna stalls at **38.0 m/s** and cruises at **55.1 m/s**
(`CockpitWorld.handling`, asked 2026-09-19). A real 172S stalls at about 48 kt, or 25 m/s. So nothing below is a
typed knot figure. Each is a multiple of what the library says the kind does, or a distance the research gives:

| | rule | source | Cessna | Hawkeye | airliner |
|---|---|---|---|---|---|
| pattern height | 305 m propeller; 457 m turbine or large | [AIM] 4-3-3 a | 305 m | 457 m | 457 m |
| pattern bank | a medium bank, 30°, or the kind's own limit if that is less | [AFH] 8 | 30° | 30° | 25° (its limit, 0.44 rad) |
| downwind speed | the kind's cruise, but no more than 1.6 x stall | [AFH] 8 | 55.1 m/s | 70.0 | 72.6 |
| base speed | 1.4 x stall | [AFH] 9 | 53.2 | 67.2 | 70.1 |
| final speed | 1.35 x stall: 1.3 VSO plus a little, because the autopilot's mixer allows NO climb at 1.3 x stall (`slow_margin`), and a final with no climb left cannot correct a low glide path | [AFH] 9 | 51.3 | 64.8 | 67.6 |
| downwind offset | the greater of 1/2 mile (926 m) and 2.5 turn radii at downwind speed and pattern bank: a base and a final turn with room for the base leg between them | [AFH] 8 | 1,340 m (0.72 NM) | 2,160 m (1.17 NM) | 2,850 m (1.54 NM) |
| final joins | 91 m (300 ft) above the runway, on 3° | [AFH] 9 (300 ft gate) | 1,740 m from the aim point | the same | the same |
| glide path | 3°, aiming 300 m into the runway (the island strip's PAPI stands there) | [AFH] 9; `Terrain.PAPI_FROM_THRESHOLD` | | | |
| descent | from pattern height abeam the threshold, straight down the path length to the final join | [AFH] 8, [AC] 11.4 | about 4.4°: 214 m over some 2.8 km of downwind and base, 4.2 m/s (830 fpm) at 55 m/s | | |
| go-around gate | 91 m (300 ft): runway occupied, spacing lost, or not stabilised | [AFH] 9 | | | |
| flare | begin at 10 to 20 ft (3 to 6 m) | [AFH] 9 | the C++'s, from the kind's sink | | |
| touchdown | on the mains, near the stall | [AFH] 9 | | | |

The offset works out inside the handbook's 1/2 to 1 mile for the Cessna, and wider for the heavy aircraft. [AFH] 8
says those fly wide as well.

**The 3° path does not reach pattern height inside a pattern.** 305 m on 3° is 5.8 km of final. A real pilot descends
through the downwind and base at 500 to 1,000 fpm, which is steeper than the final. The game does what the handbook
describes: level to abeam the threshold, then down the path to the 300 ft final join, then 3°.

## 8. What the game leaves out, on purpose

- **Wind.** The island's wind is still (`Terrain.WIND` is zero, user 2026-09-15: "no wind"). The runway in use is
  the one the airfield file names, rather than the one "most nearly aligned into the wind" ([AC] 11.5).
- **Radio calls.** The CTAF position reports ([AC] 9.11.2) are not spoken. The sequence they would set up is kept
  by the airfield's circuit instead: the order in which aircraft will reach the runway.
- **The towered airport's clearances** ([AIM] 4-3-2). A tower exists at the island strip. Nobody sits in it yet to
  clear anyone.

## 9. Large aircraft: an instrument approach, not the pattern

The user, 2026-09-19: *"make sure large planes use something more similar to a IFR approach which requires far less
turning and supports the large turning radius of a large plane."* More sources, all public domain:

- **[AIM] 5-4**, https://www.faa.gov/air_traffic/publications/atpubs/aim_html/chap5_section_4.html
- **[7110.65]** FAA Order JO 7110.65, *Air Traffic Control*, 5-9-1,
  https://www.faa.gov/air_traffic/publications/atpubs/atc_html/chap5_section_9.html
- **[P/CG]** Pilot/Controller Glossary, "approach gate"
- **[IPH]** *Instrument Procedures Handbook*, FAA-H-8083-16B, chapter 4 "Approaches"
- **[IFH]** *Instrument Flying Handbook*, FAA-H-8083-15B, chapter 4

What they say:

- **Vectors to final:** "aircraft are vectored to the final approach course", and the final vector is "such as to enable
  the pilot to establish the aircraft on the final approach course prior to reaching the final approach fix" ([AIM]
  5-4-3).
- **Where and how steeply to intercept** ([7110.65] 5-9-1 a and TBL 5-9-1): at least **2 miles outside the approach
  gate**, at no more than **30 degrees**; 20 degrees if within 2 miles of the gate.
- **The approach gate:** "1 mile from the final approach fix on the side away from the airport and ... no closer than 5
  miles from the landing threshold" ([P/CG]).
- **The glideslope:** "intended to be intercepted at the published glide slope intercept altitude. This point marks the
  PFAF" ([AIM] 5-4-5), level until it is met, so from below. A 3-degree path is "300 feet to 1 NM": **1,500 ft at
  5 NM**, 3,000 at 10 ([IPH] 4).
- **The intermediate segment** is "normally aligned within 30 degrees of the final approach course" ([IPH] 4). ATC may
  vector to an IF at up to 90 degrees ([IPH] 4, [AIM] 5-4-6).
- **Standard rate** is 3 degrees a second. Its bank is about "the airspeed divided by ten and add 7" ([IFH] 4), about
  20 degrees at 130 kt.

**What the game flies** (`world/instrument_approach.gd`):

| | rule | value |
|---|---|---|
| who | more than 14 CFR 1.1's 12,500 lb | airliner, gunship, tanker, Mercury, Hawkeye, fighter, Tomcat, Falcon, Prowler |
| FAF | 5 NM, glideslope met there from below | intercept height (5 NM + 300 m) x tan 3 = 501 m, 1,643 ft |
| established | approach gate (FAF + 1 NM) + 2 NM | 8 NM, 14.8 km |
| intercept | 30 degrees | |
| bank | at most 25 degrees, the kind's limit, and a flown turn no faster than standard rate | |
| vectors | a downwind, a base and a 30-degree intercept leg | sized to 2.5, 2 and 2 FLOWN turn radii |
| straight-in | inbound, and a 30-degree intercept from where it is meets the centreline 2 radii outside 8 NM | |

**Measured** (`tests/traffic_pattern.gd` section 7): an airliner starting abeam the runway on the wrong side, heading
away, is vectored in.

| | measured |
|---|---|
| worst bank | 25.0 degrees |
| fastest turn | 2.31 degrees a second |
| tightest steady level turn | 2,961 m, against 3,241 planned |
| established on the final | 7.6 NM out |
| above the glideslope | at most 0.2 m |
| at 300 ft | stabilised |

Flying the same airliner round the VFR pattern (the mutant) goes around, unstabilised.

**Still owed** (a C++ step): landing configuration. The AI never lowers flaps or gear, and the Hawkeye cannot slow to
1.35 x its stall on a 3-degree path at idle: it reached the gate at 76 m/s against 65, and went around. The roll-out's
back stick also lifted the airliner off the runway again after touchdown.

## 10. The acceptance target for the Cessna's flight model

The user, 2026-09-19: *"restart the flight model work, focus on getting the cessna right first, then repair the
traffic work."* This is what the Cessna must still do on its new flight model for airport life to work, with what it
does today on the lumped model (2026-09-19). Run `tests/traffic_pattern.gd`. Every number below is printed by a check
in it, and the check's limit is in the right-hand column.

| what | today | must |
|---|---|---|
| turn per bank: flown rate / (g tan bank / v), steady level turn | 0.53, the same at 20, 30 and 45 degrees | measured by the traffic in flight (`_gauge_the_turn`), so any value works; nearer 1 is a real aeroplane |
| downwind: height held, mid-field to abeam the threshold | worst 1.4 m off 304.8 | within 15 m |
| downwind: offset held | 0 m off | within 150 m |
| the 300 ft gate | 19 m off the centreline, 51.4 m/s against 51.3 | within 22.5 m; +10/-5 kt |
| final path, gate to 100 ft | 2.98 degrees (pattern), 3.00 (straight-in) | 3 +/- 1 degree |
| flare and touchdown | 296 m past the threshold, 1.08 m/s down, 43.8 m/s along | first half of the runway; at most 3.05 m/s down (10 ft/s) |
| roll-out | stops 471 m in, taxis clear | clear of the runway, not destroyed |
| two at once | 963 m apart at closest; the second lands 112 s after the first is clear | never within 463 m; never on an occupied runway |
| taxi | within 4.5 m of the route, at most 8.8 m/s | within 11.4 m; 9.5 m/s |
| take-off | lift-off 387 m in, 1.0 m off the centreline | within the runway |
| climb-out | within 2 m of the centreline, turn 3,156 m out at 214 m | straight to half a mile past the end and within 300 ft of pattern height |

The lumped wing's numbers the pattern leans on: the stall 38.0 m/s, cruise 55.1 m/s, and the autopilot's 0.9 rad bank
limit (`CockpitWorld.handling`, `turn_radii`). A new flight model changes them, and the pattern is sized from them, so
nothing needs retyping. It only needs the checks above to stay green.

## 11. Intersecting runways (lane/airport, 2026-09-19)

The user asked for an airport with runways that "sometimes cross one another" (Cape International, `agents.md`). The
rules, from FAA Order JO 7110.65BB, read on 2026-09-19
(https://www.faa.gov/air_traffic/publications/atpubs/atc_html/chap3_section_9.html and `chap3_section_10.html`):

- **3-9-8 b, departures.** A departure may not begin its take-off roll until one of these is true:
  - (1) the preceding departure on the other runway has passed the intersection, or is turning away from it;
  - (2) the preceding arrival is clear of its runway, or has completed its landing roll and will hold short of the
    intersection, or is seen turning off before it, or has passed it;
  - (3) the arrival has accepted a land-and-hold-short clearance.
- **3-10-4 b, arrivals.** An arrival may not cross the landing threshold until the same is true of whoever is using
  the other runway.
- **3-10-4 c, LAHSO.** An arrival accepts a clearance to stop short of the crossing runway, so that runway stays in
  use. The game has no tower to clear one, so it is not flown.
- **Wake turbulence (3-9-8 c, 3-10-4 d).** When flight paths cross, the wait is two or three minutes behind a heavy.
  Not modelled.

What the game flies (`AirportTraffic._crossing_busy`):
- The departure test is at the hold short.
- The arrival test is the existing 100 ft check, which already sends an arrival around when its own runway is not
  clear.
- "Short of the intersection" is the hold bar's distance before it, along the other runway.
- An arrival within `DEPARTURE_CLEAR_S` of the other runway's threshold also holds a departure, as on its own runway.

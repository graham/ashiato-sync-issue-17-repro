# The warbirds against their books: what each kind is held to, and where every number came from

Lane/warbirds2, 2026-09-19. The user: *"let's finish the p-51, p-47, p-38 and b-17. Make sure they fly well, since some are
tail dragger aircraft you'll have to make sure to handle that correctly."* This file is step 0 of
`real_wing_playbook.md` for the four warbirds: the book, the planform read off each drawn airframe, the engine and the
drag fitted to the book, and the job each kind is held to. The sources, figure by figure, are in
`warbirds_sources.md` beside it, gathered for this lane. Read that for what a number is and how sure it is. This file
records what the game does with each figure.

**The decision: the warbirds are born on their own lifting surfaces**, not tuned on the lumped wing first.
- A taildragger's take-off needs the elevator live on its wheels to raise the tail, and the lumped wing takes the stick
  away until it is past flying speed.
- The lumped wing's rate servo turns at about half of textbook, where the surfaces turn at 0.99.
- `real_wing_playbook.md` moves every warbird onto its surfaces anyway (the fleet's item 5), so tuning them lumped first
  would be paying twice.

The price was the Cessna's: +57 to 75 ns an aircraft a tick, bracketed, and the P-51 is priced against it in a
MEASUREMENT slot.

## 0. What every kind shares

- **Sea level only.** The model has no density with height, so every speed and climb held here is the book's
  sea-level figure. A warbird flown at 25,000 ft here is as fast as it is at sea level, 60 to 90 mph slower than the book
  there. That is expected, and not a bug (`warbirds_sources.md`, caveat 2).
- **Full throttle is military power**, not war emergency. WEP is a five-minute rating, and the game has no timer for it.
- **Every CD0 is NASA SP-468's.** Loftin derived them from published speed and power; they were not measured. Held
  against the top speed they were derived from, they are consistent with it. The P-47 has no SP-468 row: its CD0 is
  fitted here from its own speed and power, and says so.
- **The propeller is the Cessna's line** (`aero::thrust_at`): thrust falls from its static figure to nothing at
  `thrust_gone_at`. The line is the one through two book points: the sea-level top speed, and the climb at its
  best-climb speed, each with the aeroplane's own drag. Both points hold only at full throttle. A closed throttle
  windmills at the same slope, which is steeper than a constant-speed propeller really windmills. See section 5.
- **CLmax is the book's power-off stall** at the weight the table is printed at: clean, and with gear and full flap.
  Stall tables are in IAS, taken as EAS. `flap_clmax` is the difference.
- **The mass is the weight the stall table is printed at**, so the stall needs no scaling. The top speed and the climb
  are quoted within a few per cent of it.

## 1. The P-51D Mustang (kind `p51`)

### The book

| | the book | source | the game holds |
|---|---|---|---|
| mass | 9,500 lb stall table; 9,760 lb speed test | [P6], [P2] | 4,300 kg (9,480 lb) |
| wing | 233 sq ft, 37 ft 0 in | [P1], SP-468 | 21.65 m^2, the drawn 11.286 m span |
| top speed at sea level, military | 364 mph TAS (162.7 m/s) at 9,760 lb with racks | [P2] Wright Field TSCEP5E-1908 | 162.7 m/s, to 5 per cent |
| climb at sea level, military | 3,030 ft/min (15.4 m/s) | [P3] NAA NA-46-130 | 15.4 m/s, to 15 per cent |
| best-climb speed | NOT FOUND | | 170 mph (76 m/s), ESTIMATE |
| stall, power off, clean | 103 mph IAS (46.0 m/s) at 9,500 lb | [P6] | CLmax 1.50 |
| stall, gear and flaps down | 96 mph IAS (42.9 m/s) at 9,500 lb | [P6] | CLmax 1.73 (flap_clmax 0.23) |
| take-off ground run | 1,450 ft at 9,400 lb, 1,730 at 10,100 (15 to 20 degrees of flap) | [P1] | about 455 m, to a band |
| lift-off speed | 95 mph at 9,000 lb, 103 at 10,000 | [P6] | about 44 m/s |
| roll | P-51B 94 deg/s peak at 290 to 330 mph IAS, 50 lb of stick | NACA TR 868 | pb/2V 0.06 to 0.10 at full aileron |
| touchdown | 90 mph IAS at 8,500 lb, three-point | [P6], [P4] | a three-point landing |
| CD0 | 0.0163 | SP-468 | 0.0163 |

### The fit

At 4,300 kg (42,183 N), S = 21.65 m^2, an aspect ratio of 5.88 and an Oswald factor of 0.8 (`aero::build_wing`):
- **flat out at 162.7 m/s:** parasite drag 5,722 N, induced 340 N, so the propeller gives **6.06 kN** there;
- **climbing at 15.4 m/s at 76 m/s:** parasite 1,248 N, induced (CL 0.55) 1,578 N, and climb power 42,183 x 15.4 / 76 =
  8,548 N, so it gives **11.37 kN** there;
- **the line through them:** 61.3 N per m/s, so the static thrust is **16.03 kN**, falling to nothing at **261.6 m/s**.

16 kN static is low for a 1,490 bhp Merlin, where about 20 to 24 kN is typical. That is what a straight line through
two powered points gives: a real constant-speed propeller's thrust curve bows upward at low speed. The take-off run
shows it, and is held to a band that allows for it (see "What the taildragger costs").

### The planform, read off `P51Airframe`

Every number is the class's own table, integrated here (`craft/p51/`). Stations are metres aft of the spinner's tip.
Heights are metres over the ground under the main tyres with the aeroplane built level, which is 2.00 m under the
thrust line.

| | the table | the game |
|---|---|---|
| wing | WING_LE 2.687 + 0.0671 x, WING_TE 5.416 - 0.1886 x, to 5.40 m, the tip to 5.643 | the panel's spanwise centroid 2.40 m out; its quarter chord at station 3.377, 1.645 m up |
| dihedral | WING_MID's slope 0.0993 (5.7 degrees drawn, 5 printed at the reference plane) | 0.0990 rad |
| incidence and camber | +1 degree at the root, -0.5 at the tip; NAA/NACA 45-100 zero-lift about -1 degree | alpha0 0.024 rad, ESTIMATE |
| ailerons | 3.31 to 5.40 m out aft of HINGE 4.80 - 0.108 x; 15 degrees printed | 31 per cent of a panel, tau 0.25 |
| tailplane | TAIL_LE 7.84 + 0.213 x, TAIL_TE 9.207 - 0.092 x, to 2.01 m | 4.25 m^2, its quarter chord at 8.305, 2.34 m up |
| elevators | aft of 8.745, 35 per cent of the chord; 30 up and 20 down printed | tau 0.55 |
| fin and rudder | FIN and RUDDER outlines over the tail cone | 2.05 m^2 (the rudder 45 per cent), 1.38 m tall, its quarter chord at 8.95, its centroid 2.84 m up |
| main wheels | MAIN_AXLE station 2.747, PRINTED_TRACK 3.607 | mains 2.747, track 3.607 |
| tail wheel | TAIL_AXLE (7.875, -0.666), TAIL_TYRE 0.31 m | its tyre's bottom 1.179 m up at 7.875: **12.95 degrees of rake** (the class's `parked()` 12.99, the printed 13 deg 36 min) |
| propeller | PRINTED_PROP 3.404 m at PROP_STATION 0.51 | its disc's bottom 0.298 m up: **the propeller strikes 7.6 degrees nose down** about the mains |
| tail wheel steering | [P4] and [P6]: locked and steerable 6 degrees each way with the stick at or aft of neutral, full swivel forward of it | 0.1047 rad, unlocked with the stick 10 per cent forward |

**The inertia, ESTIMATE, from component masses** at 4,300 kg:
- pitch about 13,500 kg m^2: the Merlin and propeller, 900 kg at 2.5 m ahead (5,600); the tail, 100 kg at 5 m (2,500);
  the fuselage, 700 kg over 9 m (4,700); the pilot, fuel and guns near the centre (700);
- roll about 8,500: the wing, 700 kg over 11.3 m (5,500); the guns and ammunition, 300 kg at 2.3 m (1,600); the wing fuel
  (1,400);
- yaw about 21,500.

### The job, and its pass mark

**A take-off, a circuit and a landing**, flown by its autopilot on the test field's flat ground, as the pilot's manual
flies them:
- **The take-off run.** The tail is held down while the rudder has no air over it, then raised to a nearly level
  attitude, and the aeroplane is lifted off at about 1.15 x its stall.
- **The circuit.** It is the Cessna's circuit (`TrafficPattern`), sized on the P-51's own speeds by `AirportTraffic`.
- **The landing.** It flares to the three-point attitude and holds the stick back on the roll-out, braking gently.
  [P4]: "continuous back pressure on the stick to obtain a tail-low attitude for actual touchdown".

The landing rule must read every touchdown as a landing: not a tail strike, not a nose-over, and under the land
aeroplane's 6.1 m/s.

## 2. The P-47D-30 Thunderbolt (kind `p47`)

### The book

| | the book | source | the game holds |
|---|---|---|---|
| mass | 13,230 lb combat take-off, which the stall table is printed at; 12,700 lb "mean" for the speeds | [T3], [T4] | 6,001 kg (13,230 lb) |
| wing | 300 sq ft; 40 ft 9-5/16 in, and the sources disagree by nearly a foot | [T1]-[T4] | 27.87 m^2, the drawn 12.429 m span |
| top speed at sea level, military | 299 mph (133.7 m/s) at 52 in Hg dry, GRAPH +/-3 mph | [T3] Fig. 2 | 133.4 m/s, 298 mph, to 5 per cent |
| climb at sea level, military | NOT FOUND | | 13.45 m/s, 2,647 ft/min, held BETWEEN two published figures |
| best-climb speed | 158 mph (the trim point; the 1943 manual says 140 to 165 IAS) | [T2] Table II | 158 mph (70.6 m/s) |
| stall, power off, clean | 116 mph IAS (51.9 m/s) at about 13,230 lb | [T3] §V-D | CLmax 1.28 |
| stall, gear and full flap | 98 mph IAS (43.8 m/s) | [T3] | CLmax 1.80 (flap_clmax 0.52) |
| take-off | 1,050 yd over 50 ft at 14,600 lb; NO GROUND RUN IS PUBLISHED | [T4] | about 520 m DERIVED, held 0.6 to 2.1 |
| roll | max pb/2V 0.074 at 30 lb of stick | [T2] pp.7, 9 | 0.075, 56 deg/s at 80 m/s |
| three-point attitude | ground line 12 degrees to the thrust line | [T2] Fig. 1 | the drawn gear rests it at 12.07 |
| propeller clearance, level | 4.15 in (0.105 m) | [T2] Fig. 1 | the drawn disc's bottom 0.117 m over the ground |
| tail wheel | full swivel when unlocked, locks at centre; NO STEERING LINKAGE | [T3] §IV-A, [T6] | `tailwheel_steer` 0 |
| landing | three-point, "very easily made... with full flaps and elevator trim well back" | [T3] §IV-L | a three-point landing (tests/taildragger.gd) |
| CD0 | **NOT FOUND.** SP-468 has no P-47 row | | 0.0284, DERIVED and marked so |

### The fit

At 6,001 kg (58,847 N), S = 27.87 m^2, an aspect ratio of 5.54 and an Oswald factor of 0.8:
- **CD0 IS DERIVED, which no other kind's is.** SP-468's method on the one speed this game flies -- 299 mph at sea level
  on MILITARY power -- with 2,000 bhp and a propulsive efficiency of 0.85, Loftin's own upper figure: parasite drag
  8,667 N on a dynamic pressure of 10.94 kPa over 27.87 m^2, so **CD0 = 0.0284**. That is a flat-plate area of 8.5 sq ft
  against the P-38's 8.8 and the P-51's 3.8: two big heavy fighters of a size, and the clean one at less than half of
  either. Worked the same way, the WEP point (345 mph on 2,535 bhp) gives 0.0242; the military point is chosen because
  military power is what full throttle is here (section 0), so the one speed the game holds is right by construction.
  The 0.020 to 0.022 often quoted for a P-47 is unsourced and was not used.
- **THE PROPELLER, 22.96 kN falling to nothing at 227.7 m/s:** the line through that top speed (thrust = drag, 9.48 kN)
  and the climb at 158 mph on the same 2,000 bhp at a climb efficiency of 0.75 (15.84 kN), DERIVED, because no sea-level
  military climb is published for the D-30. The cross-check that makes it believable: momentum theory on the drawn 13 ft
  disc gives 40.7 kN ideal, so 22.96 is a figure of merit of 0.56 -- and the P-51's independently fitted 16.03 kN on its
  11 ft 2 in disc works out at 0.55.
- **THE CLIMB IS HELD BETWEEN TWO PUBLISHED FIGURES, not to one.** It must beat the 2,030 ft/min it made at 12,000 ft on
  the same 52 in Hg (the turbo holds the power, the drag at a given EAS is the same, and the true airspeed to drag
  through is a fifth greater up there, so sea level must be better), and it must not beat the 3,260 ft/min best rate it
  made at 10,000 ft on 65 in WET, which is a quarter more power again. It flies 2,647.

### The planform, read off `P47Airframe`

Stations are metres aft of the spinner's tip; heights are metres over the ground under the main tyres with the aeroplane
built level, which is 2.098 m under the thrust line.

| | the table | the game |
|---|---|---|
| wing | WING_ROWS, outs stretched by WING_STRETCH (1.0096) | 27.75 m^2 drawn against the published 27.87; centroid 2.71 m out, quarter chord at station 3.349, 1.870 m up |
| dihedral | WING_MID's slope 0.0973 | 0.0970 rad, 5.56 degrees (printed 6 on the top surface) |
| ailerons | AILERON_SPAN 3.35 to 5.85 m out aft of AILERON_HINGE | 1.149 m^2, 8.2 per cent of a panel against the Mustang's 5.1; share 0.50, tau derated to 0.27 |
| tailplane | TAIL_ROWS to the tip 2.44 m out; ELEVATOR_HINGE straight at 10.34 | 5.79 m^2, quarter chord at 9.768, 2.403 m up; the elevators 31.7 per cent of its area, tau 0.52 |
| fin and rudder | FIN and RUDDER's outlines | 2.645 m^2 (the rudder 46 per cent), 1.37 m tall, quarter chord at 9.46, centroid 3.02 m up |
| main wheels | MAIN_AXLE station 2.86, PRINTED_TRACK 4.750 | mains 2.86, track 4.750 |
| tail wheel | TAIL_AXLE (9.04, -0.607), TAIL_TYRE 0.34 m | its tyre's bottom 1.321 m up at 9.04: **12.07 degrees of rake** against the printed 12 |
| propeller | PRINTED_PROP 3.962 m at PROP_STATION 0.50 | its disc's bottom 0.117 m up (printed clearance 4.15 in): **the propeller strikes 2.84 degrees nose down** about the mains |

**The inertia, ESTIMATE, from component masses** at 6,001 kg: pitch about 23,000, roll about 19,000, yaw about 42,000 --
each 1.7 to 2.2 times the Mustang's, where mass times size squared says 1.75.

### The job, and its pass mark

The Mustang's, with two differences that are the aeroplane's own and not a tuning choice.

**IT STEERS ON ITS BRAKES AND NOTHING ELSE.** `tailwheel_steer` is 0, which in `roll_a_taildragger` is a wheel that is
held straight ahead while it is locked and holds nothing at all once the stick unlocks it -- the P-47's lock handle,
exactly. The taxi turn that was written for the Mustang's six steering degrees works unchanged: **7.5 m of radius, 60
degrees round in 2.3 s**, against the Mustang's 6.9 and 2.1, and with the wheel locked it never comes round at all.

**IT IS TOO HEAVY FOR THE VISUAL CIRCUIT.** At 6,001 kg it is over `TrafficPattern.LARGE_MASS` (5,670 kg, the FAA's
12,500 lb), so `AirportTraffic` gives it an INSTRUMENT approach -- vectors to a long final, the thing the user asked for
for large aeroplanes -- and it is the first fighter here on the far side of that line. An instrument approach is flown
ONTO the runway and not flared, so it arrives in a WHEEL-landing attitude, 8.0 degrees nose up at 66 m/s, 296 m past the
threshold, 0.77 m/s of sink. Its three-point landing is held by `tests/taildragger.gd`, which flies it by hand.

## 3. The P-38L Lightning (kind `p38`): the book, for step 3

- normal gross 17,500 lb and 327.5 sq ft (SP-468);
- 339 mph at sea level on military and 345 on WEP (P-38J, same ratings);
- climb at sea level 3,720 ft/min military at 16,200 lb;
- stall per [L3] (P-38J-15, 17,363 lb): 97.5 mph clean and 80.5 mph with gear and flaps down;
- lift-off at about 100 mph, a tricycle, "ease back at 80";
- CD0 0.0268;
- roll with the aileron boost about 103 deg/s at 200 mph, averaged over time to 90 degrees.

It is a tricycle, and its nosewheel castors: it steers with its brakes and throttles.

## 4. The B-17G Flying Fortress (kind `b17`): the book, for step 4

- combat weight 48,692 lb, 1,420 sq ft, 21.1 ft of track [B1];
- about 220 mph at sea level on normal power and 247 on 1,380 bhp WEP (read off a graph);
- climb 1,870 ft/min at max power;
- stall at 50,000 lb: 100 mph clean and 88 mph with full flap (read off a graph), so CLmax about 1.39 and 1.77;
- CD0 0.0302;
- the tail wheel locks in the centre and swivels fully when unlocked; turns are made "by using the throttles, with as
  little brakes as possible";
- crew: 12 or 13 .50s (`warbirds_sources.md`, the stations table).

## 5. What the model does not do yet

- **P-factor and engine torque**, the swing on a taildragger's take-off run: a todo (team-lead, 2026-09-19).
- **A constant-speed propeller windmilling at idle.** The Cessna's line makes a closed throttle drag as hard as the
  line's slope, which on a P-51 is several kilonewtons at approach speed. The glide is steeper than the P-51's
  published best L/D of 14.6 (SP-468). The book holds no glide, since no sink rate was found.
- **Density with height**, so no critical altitude.

# Warbirds: published performance figures with sources

**Aircraft:** P-51D Mustang, P-47D-30 Thunderbolt, P-38L Lightning, B-17G Flying Fortress.

Compiled 2026-09-19 from web research. Primary sources were used wherever one could be found. Every figure carries a source tag, and the sources list at the end of each section gives URLs and licence.

**Markers used in the tables**

| Marker | Meaning |
|---|---|
| **GRAPH** | Read by eye from a scanned chart; treat as roughly ±2–3 % |
| **DERIVED** | Calculated here from published numbers; not itself published |
| **SECONDARY** | From a non-primary source |
| **UNSOURCED** | Recalled with no source found |
| **NOT FOUND** | Searched for and not located |

**Units.** Speeds are as the source gives them: TAS for flight-test speed-versus-altitude figures, IAS for stall, approach and pilot's-manual figures. SI conversions: 1 mph = 0.44704 m/s, 1 kn = 0.51444 m/s, 1 ft = 0.3048 m, 1 lb = 0.45359 kg, 1 ft/min = 0.00508 m/s, 1 ft² = 0.092903 m², 1 bhp = 0.7457 kW.

## Before using any figure, note these three caveats

1. **Every CD0 in this file is a derived number, not a measurement.** The CD0 figures come from NASA SP-468 (Loftin, *Quest for Performance*, 1985). Its appendix C says it *estimated* CD0 from published maximum speed and power:

   > CD = 1.456×10⁵ · ηP / (σ S V³), then CD0 = CD − CL²/(πAe)

   It assumed a propulsive efficiency η of 0.70–0.85 and an Oswald factor e of 0.70–0.75. So these are consistent, citable numbers but not wind-tunnel values. SP-468 has **no P-47 row**.

2. **"Sea-level max speed" is a turbo- or supercharger artefact on all four aircraft.** Each gains 60–90 mph by critical altitude.
   - The sea-level figures below are the right ones to tune a constant-density sim against.
   - If the sim matches sea-level speed, it will be slow at altitude. That is expected, not a bug.

3. **Several key numbers were read off chart scans (GRAPH).** Re-read the original before hard-coding any of them. They are: the P-47 sea-level speeds, all roll rates, the B-17 sea-level speed and the B-17 stall table.

---

## 1. P-51D Mustang (Packard V-1650-7)

| # | Figure | Value (SI) | Condition | Source |
|---|---|---|---|---|
| 1 | Basic (empty) weight | 7,635 lb (3,463 kg) | P-51D-5-NA / D-5-NT | [P1] |
| 1 | Empty weight (SP-468) | 7,125 lb (3,232 kg) | — | [X1] Table III p.484 |
| 1 | Combat weight (performance quoted at) | 10,100 lb (4,581 kg) | Tactical chart figures | [P1]; also [X1] Table III (Wg) |
| 1 | Max ("war max / recommended") weight | 11,600 lb (5,262 kg) | — | [P1] |
| 1 | Max gross with external stores | 12,300 lb (5,579 kg) | Post-war F-51D handbook | [P4] |
| 1 | Normal gross, no external load | about 9,000 lb (4,082 kg) | — | [P4] |
| 1 | Flight-test weight | 9,760 lb (4,427 kg) | Take-off weight: full ammunition, 184 gal wing fuel + 25 gal fuselage tank | [P2] |
| 2 | Span | 37 ft 0 in (11.28 m) | — | [P1], [P5], [X1] |
| 2 | Wing area | 233 ft² (21.65 m²) | — | [P1], [X1] |
| 2 | Aspect ratio | 5.86 | — | [X1] Table III (37²/233 = 5.88) |
| 2 | Airfoil | NAA/NACA laminar-flow ("NAA/NACA 45-100"); root and tip thickness **NOT FOUND** in a primary source | — | SP-468 text says NACA laminar-flow sections [X1]; section name from forums only |
| 3 | Take-off power | 1,490 bhp (1,111 kW); 3,000 rpm, 61 in Hg | Sea level | [P1], [X1]; rpm and boost [P5], [P6] |
| 3 | Military power | 3,000 rpm, 61 in Hg, 15 min limit | — | [P5] |
| 3 | War emergency (WEP) | 3,000 rpm, 67 in Hg, 5 min limit; about 1,630 bhp (1,215 kW) at sea level as tested | — | [P5], [P6]; bhp [P2] |
| 3 | Max continuous / max cruise | 2,700 rpm, 46 in Hg / 2,400 rpm, 36 in Hg | — | [P5] |
| 3 | Propeller | Hamilton Standard Hydromatic, 4 blades, 11 ft 2 in (3.40 m), constant speed | — | [P1] |
| 4 | **Max speed at sea level, WEP** | **375 mph TAS (167.6 m/s, 603 km/h)** | 9,760 lb; a bomb rack under each wing | [P2] Wright Field TSCEP5E-1908 |
| 4 | **Max speed at sea level, military** | **364 mph TAS (162.7 m/s)** | Same | [P2] |
| 4 | Max speed at sea level, normal rated | 323 mph (144.4 m/s) | Same | [P2] |
| 4 | Sea-level speeds, NAA calculation (**DISAGREES** with [P2] by 7–9 mph) | 368 mph WEP / 355 military / 312 normal (164.5 / 158.7 / 139.5 m/s) | 9,611 lb | [P3] NAA NA-46-130 |
| 4 | Max speed at critical altitude | 442 mph (197.6 m/s) at 26,000 ft on WEP; 439 mph at 28,000 ft on military; low blower 417 mph at 10,000 ft on WEP | 9,760 lb | [P2] |
| 4 | Max speed at critical altitude (SP-468) | 437 mph at 25,000 ft | 10,100 lb | [X1] |
| 5 | **Climb at sea level, WEP** | **about 3,600 ft/min (18.3 m/s), GRAPH** | 9,760 lb | [P2] Fig. 5 |
| 5 | Climb at sea level, NAA calculation | 3,410 ft/min on WEP (17.3 m/s); **3,030 ft/min on military (15.4 m/s)**; 1,900 ft/min normal | 9,611 lb | [P3] |
| 5 | Best-climb airspeed | **NOT FOUND** as a figure. The manual's minimum-run technique climbs at 100 mph IAS straight after lift-off | — | [P6] |
| 6 | Stall, power off, gear and flaps up | 103 / 97 / 91 mph IAS (46.0 / 43.4 / 40.7 m/s) | 9,500 / 8,500 / 7,500 lb, no external load | [P6] stalling-speed table |
| 6 | Stall, power off, gear and flaps down | 96 / 90.5 / 85 mph IAS (42.9 / 40.5 / 38.0 m/s) | Same weights | [P6] |
| 6 | Stall with bombs or tanks | 113 / 107.5 / 102 mph up; 103 / 98 / 93 mph down | 11,000 / 10,000 / 9,000 lb | [P6] |
| 6 | Stall (SP-468) | 100 mph | 10,100 lb | [X1] |
| 6 | CLmax | **NOT FOUND** as published. DERIVED from [P6] at 9,500 lb: about 1.50 clean, 1.73 gear and flaps down (IAS taken as EAS) | — | DERIVED |
| 7 | Take-off distance | Ground run / over 50 ft: 1,200 / 1,830 ft at 8,700 lb; 1,450 / 2,120 ft at 9,400 lb; **1,730 / 2,430 ft (527 / 741 m) at 10,100 lb** | Hard surface, sea level, no wind | [P1] |
| 7 | Take-off distance, NAA calculation | 1,040 ft ground run (317 m); 1,720 ft over 50 ft (524 m) | 9,611 lb | [P3] |
| 7 | Take-off (lift-off) speed | 95 / 103 / 110 mph IAS (42.5 / 46.0 / 49.2 m/s) | 9,000 / 10,000 / 11,000 lb | [P6] |
| 7 | Take-off technique | Flaps 15–20° ([P5] calls 20° "TAKE-OFF"). 61 in Hg, 3,000 rpm; rudder trim 5° right. Stick at or aft of neutral, so the tailwheel is locked and steerable. "Hold the tail down until sufficient speed for rudder control is attained, then raise the tail slowly"; raising it early worsens torque. Minimum run: three-point, let it fly itself off, climb at 100 mph | — | [P4], [P5], [P6] |
| 8 | Approach | Pattern 150 mph IAS. Gear down below 170 mph; full flap below 165 mph and above 400 ft. **120 mph IAS (53.6 m/s) over the field edge** | — | [P6], [P4] |
| 8 | Touchdown speed | 93 / 90 / 87 mph IAS | 9,000 / 8,500 / 8,000 lb | [P6] |
| 8 | Landing speed (chart) | 100 / 104 / 108 / 112 mph | 8,000 / 8,700 / 9,400 / 10,100 lb | [P1] |
| 8 | Landing roll | Ground roll / over 50 ft: 1,550 / 2,450 ft at 8,000 lb; **1,970 / 2,970 ft (600 / 905 m) at 10,100 lb** | Hard surface, no wind | [P1] |
| 8 | Landing technique | **Three-point.** "Continuous back pressure on the stick to obtain a tail-low attitude for actual touchdown" [P4]. The training manual (read second-hand only) says hold off in a three-point attitude; the aircraft "stalls rather suddenly" | — | [P4]; [P7] |
| 9 | Speed at max continuous power | 409 mph at 25,000 ft; 354 mph at 10,000 ft; about 329 mph at 5,000 ft | 10,100 lb, 2,700 rpm, 46 in Hg | [P1] |
| 9 | Cruise with drop tanks | 358 mph (160 m/s) at 25,000 ft, range 1,650 mi | — | [X1] text |
| 9 | Economical cruise | **NOT FOUND** as a speed. Cruise chart [P8] not read | — | — |
| 10 | Roll rate, P-51B-1-NA (nearest variant plotted) | About 90°/s at 260 mph IAS; **about 94°/s peak at 290–330 mph IAS**; about 87°/s at 390 mph IAS. GRAPH ±2°/s | 50 lb stick force, 10,000 ft | [X2] NACA TR 868 Fig. 47 p.40 |
| 10 | Roll rate, XP-51 | About 80°/s at 340 mph IAS; about 85°/s at 390 mph IAS. GRAPH | Same | [X2] Fig. 47 |
| 10 | Roll rate, P-51D | **NOT FOUND** in NACA data. An NAA hand plot [P9] shows p ≈ 1.6 (probably rad/s, about 92°/s) 0.3 s after full aileron at 450 mph; units not labelled, use with caution | — | [P9] |
| 11 | Tailwheel | Stick at or aft of neutral: locked, **steerable ±6°** through cables from the rudder pedals. Stick forward of neutral: **full swivel** | — | [P4], [P6] |
| 11 | Main-gear track ("tread") | 11 ft 10 in (3.61 m) | — | [P1] |
| 11 | Brakes | Hydraulic disc brakes, toe pressure on the rudder pedals; parking brake | — | [P4], [P6] |
| 11 | Three-point ground attitude | **NOT FOUND** | — | — |
| 11 | Height (**sources disagree**) | 13 ft 8 in (4.17 m) "three-point attitude" | — | [P1], [P4]; [P5] gives 12 ft 2 in "tail down" |
| 12 | Glide | Best glide for distance 175 mph IAS (78.2 m/s), gear and flaps up. **Sink rate NOT FOUND** | — | [P4], [P6] |
| 12 | Max L/D | 14.6 | — | [X1] Table III |
| 13 | **CD0** | **0.0163**; drag area f = 3.80 ft² (0.353 m²) | S = 233 ft²; DERIVED by SP-468 from performance | [X1] Table III p.484; same value in the text |
| 13 | CD0 **conflict** | The SP-468 introduction text says "about 0.0161 (table III)" with f = 3.57 ft², which does not match S = 233 ft². The table itself is self-consistent at 0.0163 / 3.80 | — | [X1] |
| 13 | CD0 = 0.0176 | **NOT FOUND** in any source checked | — | — |
| 13 | Measured drag | NACA report "Correlation of the Drag Characteristics of a P-51B Airplane Obtained from High-Speed Wind-Tunnel and Flight Tests" exists but was **not read** (PDF too large to fetch) | — | [X3] |

**Disagreements**
- **Sea-level speed:** Wright Field measured 375 / 364 mph (WEP / military) at 9,760 lb. NAA calculated 368 / 355 mph at 9,611 lb. The Wright Field aircraft carried bomb racks, and [P1] says those cost about 4 mph, so the clean figure would be slightly higher still. **Recommend 364 mph military / 375 mph WEP.**
- **Height:** 12 ft 2 in "tail down" [P5] against 13 ft 8 in "three-point" [P1], [P4].
- **NAA "normal power":** [P3] gives 3,000 rpm / 46 in Hg; every other source gives 2,700 rpm / 46 in Hg.

**Sources.** All are US government works and public domain unless noted. Scans on wwiiaircraftperformance.org carry an "Archives of M. Williams" watermark over public-domain documents.
- [P1] USAAF *Tactical Planning Characteristics & Performance Chart, P-51 "Mustang"*, dated 26 May (probably 1944); references T.O. 01-60JE-1. https://www.wwiiaircraftperformance.org/mustang/p-51-tactical-chart.jpg
- [P2] Wright Field Memo Report **TSCEP5E-1908**, 15 June 1945, *Flight Tests on the North American P-51D Airplane, AAF No. 44-15342*, incl. Fig. 5. https://www.wwiiaircraftperformance.org/mustang/p51d-15342.html
- [P3] North American Aviation, *Performance Calculations for Model P-51D*, **NA-46-130**. Company report; copyright status uncertain. https://www.wwiiaircraftperformance.org/mustang/p-51d-na-46-130.html
- [P4] **T.O. 1F-51D-1** (formerly AN 01-60JE-1), *Flight Handbook F-51D*, 20 Jan 1954. https://archive.org/details/01-60-jf-1-foi-p-51-h (file "01-60JE-1 FH_F51D")
- [P5] **AN 01-60JE-1**, *Pilot's Flight Operating Instructions, P-51D-5 and Mustang IV*, 5 April 1944. https://www.wwiiaircraftperformance.org/mustang/P-51D-manual-5april44.pdf
- [P6] **AN 01-60JE-1**, *P-51D/K*, revised 17 Dec 1947, stalling-speed and take-off tables. Same archive.org item, file "01-60JE-1(2) FOI P-51D K".
- [P7] AAF Manual **51-127-5**, *Pilot Training Manual for the P-51 Mustang*, 15 Aug 1945. https://digitalcollections.museumofflight.org/nodes/view/2885. Quoted second-hand from a search excerpt only.
- [P8] P-51D/K flight operation instruction (cruise) chart, not read. https://www.wwiiaircraftperformance.org/mustang/p_51_flightopschart_199.jpg
- [P9] NAA "P51 Roll Fig 1". Company document. https://www.wwiiaircraftperformance.org/mustang/P-51D_roll.jpg

---

## 2. P-47D-30 Thunderbolt, bubble canopy (P&W R-2800-59/-63, water injection)

**About the sources.** The manual that covers the D-30 is **AN 01-65BC-1A** (P-47D-25 to D-35). It is only on AirCorps Library, behind a paywall, and was not read. The primary D-30 sources used are:
- the two NACA flight-test notes on an F-47D-30 [T1], [T2];
- the Wright Field 44-1 fuel test of P-47D 42-26167, R-2800-63, Curtiss 836 paddle-blade propeller [T3];
- two RAF Air Ministry data cards for the Thunderbolt Mk I and Mk II, R-2800-59 [T4]. The Mk II corresponds to the bubble-canopy P-47D-25/30.

The 1943 manual [T6] covers the razorback with the R-2800-21 and is lighter, so use it only where nothing else exists.

| # | Figure | Value (SI) | Condition | Source |
|---|---|---|---|---|
| 1 | "Light" weight (no fuel, oil, bombs or ammunition) | 10,800 lb (4,899 kg) | Thunderbolt Mk II | [T4] card 2 |
| 1 | Mean weight (performance quoted at) | 12,700 lb (5,761 kg) | Mk II | [T4] |
| 1 | Max weight | 14,600 lb (6,622 kg) | Mk II | [T4] |
| 1 | Full combat take-off weight | 13,230 lb (6,001 kg) | Full internal fuel, 15 gal water, 300 rounds per gun; P-47D 42-26167 | [T3] Eng-47-1774-A §III |
| 1 | Combat test weight | 13,260 lb (6,015 kg) | 305 gal fuel, 6 guns × 300 rounds; P-47D-10 | [T5] Eng-47-1714-A |
| 1 | NACA D-30 test weights | 11,870–13,200 lb | Take-off weight 12,810 lb | [T1] p.2 |
| 1 | Max take-off 17,500 lb / empty 10,700 lb | 7,938 kg / 4,853 kg | — | SECONDARY (DCS manual, matches Wikipedia) |
| 2 | Wing area | 300 ft² (27.87 m²) | — | [T1], [T2] Table I, [T3], [T4] |
| 2 | Span (**sources disagree**) | 40 ft 0-5/16 in (12.20 m) | Dimensioned on the NACA three-view; NASM exhibit agrees | [T2] Fig. 1 p.12; [T8] |
| 2 | Span, second value | 40 ft 9 in (12.42 m) | — | [T4] RAF cards (also Wikipedia) |
| 2 | Span, third value | "41 ft" | — | [T3] §IX |
| 2 | Aspect ratio | **5.34** with 40.03 ft; 5.54 with 40.75 ft | — | DERIVED (b²/S) |
| 2 | Mean aerodynamic chord | 87.46 in (2.22 m) | — | [T2] Fig. 1 |
| 2 | Airfoil | **Republic S-3**; incidence +1°; dihedral 4° (top surface) / 7½° (bottom surface) | — | [T2] Fig. 1 |
| 3 | Standard WEP | **2,300 hp (1,715 kW)** | 2,700 rpm, 56 in Hg with water; "Standard WER for P-47D" | [T7] HQ AAF routing sheet, 17 May 1944; [T4] card 1 |
| 3 | Improved WEP "64-130-W" | **2,535 hp (1,890 kW)** | 2,700 rpm, 64 in Hg, grade 130 fuel, water | [T7]; [T4] card 2 (R-2800-59, sea level to 24,000 ft) |
| 3 | Take-off / military | 2,700 rpm, 52 in Hg | R-2800-21 manual limit | [T6] pp.22, 33 |
| 3 | Military power in bhp | **NOT FOUND** in a primary source. 2,000 bhp is UNSOURCED | — | — |
| 3 | Propeller | Curtiss Electric, 4 blades, **13 ft 0 in (3.96 m)**, constant speed; paddle blade 836-2C2-18 | — | [T2] Fig. 1; [T3] |
| 4 | **Max speed at sea level, 64 in Hg WEP** | **345 mph (154.2 m/s, 555 km/h)** | Mean weight 12,700 lb, 2,535 bhp | [T4] Mk II card ("Maximum speed M.S.L. 345") |
| 4 | **Max speed at sea level, 56 in Hg WEP** | **332 mph (148.4 m/s)** | Mean weight 12,103 lb, 2,300 bhp | [T4] Mk I card |
| 4 | Sea level, Wright Field chart (GRAPH ±3 mph) | 52 in Hg (military, dry) ≈ **299 mph (133.7 m/s)**; 56 in ≈ 310; 65 in dry ≈ 330; 65 in wet ≈ 338; 70 in wet ≈ 346 mph | 13,230 lb, 2,700 rpm, 44-1 fuel | [T3] Fig. 2 |
| 4 | Max speed at critical altitude | 444 mph (198.5 m/s) at 23,200 ft (70 in wet); 439 mph at 25,200 ft (65 in wet); 412 mph at 31,900 ft (52 in) | 13,230 lb | [T3] |
| 4 | Max speed at critical altitude, D-30 | about 445 mph, critical altitude about 24,200 ft | — | [T9] Materiel Center memo, 30 Sept 1944 |
| 4 | Max speed at critical altitude, RAF cards | 427 mph at 26,000 ft (Mk II); 420 mph (Mk I) | — | [T4] |
| 5 | Climb | Best rate 3,260 ft/min (16.6 m/s) at 10,000 ft (65 in wet); 2,030 ft/min at 12,000 ft (52 in) | 13,230 lb | [T3] |
| 5 | Climb at sea level on military | **NOT FOUND**, and the game holds it BETWEEN the two figures above instead of to one: over 2,030 ft/min (same power on the turbo, same drag at a given EAS, a fifth more true airspeed to drag through at 12,000 ft) and under 3,260 (a quarter more power, and only 10,000 ft up). Flown: 2,647 | — | DERIVED, `warbirds_book.md` §2 |
| 5 | Climb at sea level | **NOT FOUND** as a stated value for the D-30. Nearest: sea level to 5,000 ft ≈ 2,300 ft/min (11.7 m/s) at 12,500 lb and 2,050 ft/min at 14,000 lb | Razorback, 52 in Hg | [T6] p.33 chart |
| 5 | Best-climb speed | 158 mph (trim point, [T2]); 165 mph IAS in the [T6] chart; 140–155 mph IAS in the [T6] text | — | [T2] Table II; [T6] |
| 6 | Stall, idle power (IAS, uncorrected) | Flaps up / gear up: **116 mph (51.9 m/s)**; gear down: 114; flaps ¼ / ½ / ¾ with gear down: 109 / 105 / 101; **full flap, gear down: 98 mph (43.8 m/s)** | About 13,230 lb, cowl flaps closed | [T3] §V-D stall table |
| 6 | Stall, power on | 103–107 mph IAS | 35 in / 2,200 rpm to 45 in / 2,550 rpm | [T3] |
| 6 | Stall (1943 manual) | 115 mph IAS clean, 100 mph gear and flaps down; weight not stated | Razorback | [T6] p.25 |
| 6 | Stall behaviour | Warning buffet 3–5 mph before the stall; the stick snatches left; the nose falls straight; recovery easy | — | [T1] pp.5, 9; [T3] §IV-G |
| 6 | CLmax | **NOT FOUND.** DERIVED from [T3] at 13,230 lb: about 1.33 clean, 1.86 full flap (IAS uncorrected) | — | DERIVED |
| 7 | Take-off over 50 ft | 1,050 yd (960 m) | Max weight 14,600 lb | [T4] Mk II |
| 7 | Take-off chart (1943) | Ground run / over 50 ft: 1,800 / 2,800 ft (549 / 853 m) at 12,500 lb; 2,100 / 3,100 ft (640 / 945 m) at 14,000 lb | Razorback, 52 in Hg | [T6] p.33 |
| 7 | Take-off technique | Tailwheel **locked**; rudder and a few degrees of right rudder trim; elevator and aileron trim neutral. "All take-offs were made without flaps" in [T3]; the 1943 manual says half flap helps. Hold on the brakes to 30 in Hg, then release and open up to 52 in | — | [T3] §IV-B; [T6] p.22 |
| 7 | Lift-off and tail | Lifts off at about 100 mph; raise the tail about 6 in and hold to about 110 mph | — | SECONDARY (DCS manual) |
| 8 | Approach | 115–120 mph IAS power on; 120–130 mph power off | — | [T6] p.26 |
| 8 | Landing distance | Ground roll / over 50 ft: 1,550 / 2,400 ft (472 / 732 m) at 13,500 lb; 1,200 / 2,000 ft at 10,600 lb | Hard surface | [T6] p.33 |
| 8 | Landing over 50 ft | 800 yd (732 m) | Light weight | [T4] |
| 8 | Landing technique | **Three-point.** "Three point landings are very easily made in this airplane with full flaps and elevator trim well back"; the ground roll is straight, with little tendency to swing | — | [T3] §IV-L |
| 9 | Cruise | 270 mph (120.7 m/s) most economical and 300 mph at maximum weak mixture, both at 20,000 ft | Mk II | [T4] |
| 9 | Max-range cruise setting | 219 mph IAS | 30 in Hg, 1,900 rpm, auto-lean | [T2] Table II |
| 10 | Roll rate, P-47C-1-RE (nearest variant plotted) | **About 84°/s at 230–270 mph IAS**; about 80°/s at 300; about 75°/s at 350; about 67°/s at 390 mph IAS. GRAPH | 50 lb stick force, 10,000 ft | [X2] TR 868 Fig. 47 |
| 10 | Roll, D-30 | Max pb/2V = 0.074 (AAF requirement 0.09) | 30 lb stick force (as reported by the research agent) | [T2] pp.7, 9 |
| 10 | Roll, AAF comparison | 63°/s at 400 mph | 50 lb stick force | [T10] |
| 11 | Tailwheel | **Full swivel when unlocked**; a lock handle on the right of the cockpit, and the wheel locks when it returns to centre. Unlock to taxi, lock for take-off and landing. No steering linkage is described | — | [T3] §IV-A; [T6] p.22 |
| 11 | Three-point attitude | Ground line drawn **12°** to the thrust line in the three-view. Prop tip clearance 4.15 in in the level attitude | — | [T2] Fig. 1 |
| 11 | Main-gear track | **15 ft 7 in (4.75 m)** static; tyres 34 × 9 | — | [T2] Fig. 1 |
| 11 | Brakes | Hydraulic, toe-operated; "touchy for the first one or two times… then smooth" | — | [T3] §IV-A; toe operation SECONDARY |
| 12 | Glide / sink | **NOT FOUND.** [T3] trimmed a 180 mph glide for stability tests | — | — |
| 13 | CD0 | **NOT FOUND.** SP-468 has no P-47. The 0.020–0.022 range often quoted is UNSOURCED | — | — |
| 13 | CD0, as the game uses it | **0.0284, DERIVED** by SP-468's own method from [T3]'s 299 mph at sea level on military power, 2,000 bhp and a propulsive efficiency of 0.85. A flat-plate area of 8.5 ft², against the P-38's 8.8 and the P-51's 3.8 | The WEP point (345 mph, 2,535 bhp) worked the same way gives 0.0242; the military point is chosen because military power is what the game's full throttle is | DERIVED, `warbirds_book.md` §2 |

**Disagreements**
- **Span:** 40 ft 0-5/16 in (NACA drawing, NASM) against 40 ft 9 in (RAF cards) against "41 ft" (Wright Field). Use the NACA drawing, which was dimensioned from the test aircraft.
- **Sea-level speed:** the RAF card (345 mph at 64 in Hg, 12,700 lb) and the Wright Field chart (about 338–346 mph at 65–70 in Hg, 13,230 lb) agree. The Stirling & Williams composite chart puts the P-47D-10 at 56 in Hg at about 333–338 mph at sea level. **Recommend about 300 mph at military power (52 in, dry) and about 332–345 mph at WEP.**

**Sources.** All are US government works and public domain unless noted.
- [T1] Kraft, Goranson & Reeder, NACA **TN 2899**, *Measurements of Flying Qualities of an F-47D-30 Airplane… Longitudinal… and Stalling Characteristics*, Feb 1953. https://ntrs.nasa.gov/citations/19930083857
- [T2] Goranson & Kraft, NACA **TN 2675**, *…F-47D-30… Lateral and Directional Stability and Control*, July 1952; Fig. 1 three-view on p.12, Table I. https://ntrs.nasa.gov/citations/19930083825
- [T3] Wright Field Flight Test Engineering Branch Memo Report **Eng-47-1774-A**, 15 July 1944, *Flight Tests on the Republic P-47D, AAF No. 42-26167, using 44-1 Fuel*, incl. Fig. 2. The P-47 pages on wwiiaircraftperformance.org are now 404, so read via Wayback: https://web.archive.org/web/2022/http://www.wwiiaircraftperformance.org/p-47/p47-26167.html ; chart …/p-47/p47d-44-1-level.jpg
- [T4] RAF / Air Ministry aircraft data cards, *Thunderbolt Mk I* and *Mk II*, dated 2.2.45 (Supp 9/2, cards 160 and 162). **UK Crown copyright**; facts citable, status of the scan uncertain. Wayback: …/p-47/P-47_thunderbolt1-aircraftdatasheet.jpg and …/P-47_thunderbolt2-aircraftdatasheet.jpg
- [T5] Memo Report **Eng-47-1714-A**, 27 March 1944, P-47D-10 42-75035, comparative propeller tests. Wayback: …/p-47/p-47d-75035.html
- [T6] **T.O. 01-65BC-1**, *Pilot's Flight Operating Instructions, P-47B, -C, -D and -G*, 20 Jan 1943. https://everyspec.com/ARMY/ARMY-General/P-47-BxCxDxG_AIRCRAFT_PILOTS_OPERATING_MANUAL_TO_01-65BC-1--_20JAN1943_57080/
- [T7] HQ AAF Routing and Record Sheet, *Improved High Power Equipment for P-47 Aircraft*, 17 May 1944 (R. C. Wilson). Wayback: …/p-47/p-47-2535hp.jpg
- [T8] NASM, P-47D-30-RA, catalogue A19600306000. Facts only; Smithsonian terms apply. https://airandspace.si.edu/collection-objects/republic-p-47d-30-ra-thunderbolt/nasm_A19600306000
- [T9] AAF Materiel Center inter-office memo, *High Speed P-47 Airplanes*, 30 Sept 1944. Wayback: …/p-47/P-47-high-speed-30sept44.jpg
- [T10] AAF Materiel Command, *Performance Data on Fighter Aircraft*, 26 July 1944, Table I. https://www.wwiiaircraftperformance.org/mustang/Performance_Data_on_Fighter_Aircraft.pdf
- Not reached: **AN 01-65BC-1A** (the D-25 to D-35 manual, paid). https://aircorpslibrary.com/pilots-flight-operating-instructions-for-p-47d-25-p-47d-26-p-47d-27-p-47d-28-p-47d-30-and-p-47d-35/

---

## 3. P-38L Lightning (2 × Allison V-1710-111/113, turbosupercharged)

**About the sources.** No primary P-38**L** speed test was found. The measured speeds and climbs come from P-38J tests. The J's V-1710-89/91 engines carry the same ratings as the L's -111/-113: 54 in Hg military and 60 in Hg WEP, both at 3,000 rpm. As on the P-47, the wwiiaircraftperformance.org P-38 pages are now 404, so the Wayback URLs are given.

| # | Figure | Value (SI) | Condition | Source |
|---|---|---|---|---|
| 1 | Empty weight | 12,800 lb (5,806 kg) | P-38L | [L5] SP-468 Table III |
| 1 | Empty weight (**disagrees**) | 14,100 lb (6,396 kg) | — | SECONDARY (Baugher) |
| 1 | Normal gross | 17,500 lb (7,938 kg) | P-38L | [L5]; SECONDARY (Baugher) |
| 1 | "Gross weight (combat)" | 16,000 lb (7,257 kg) | — | [L1] Pilot Training Manual |
| 1 | Test weights | 16,200 lb (Lockheed); 16,597 lb (300 gal fuel); 17,363 lb (416 gal) | P-38J | [L4] / [L2] / [L3] |
| 1 | Max take-off weight | 21,600 lb (9,798 kg) | — | **Wikipedia only**, unverified |
| 2 | Span | 52 ft 0 in (15.85 m) | — | [L6] AN 01-75FF-2 §I p.1 |
| 2 | Wing area | 327.5 ft² (30.43 m²) | — | [L1], [L5]; [L6] gives 303.06 ft² less ailerons + 25.44 ft² ailerons |
| 2 | Aspect ratio | 8.26 | — | [L1], [L5] |
| 2 | Airfoil | **NACA 23016 root, NACA 4412 tip**; incidence +2°; dihedral 5°40′ | — | [L6] p.1 |
| 3 | Military / take-off power | 1,425 bhp (1,063 kW) each at 54 in Hg, 3,000 rpm | P-38J | [L4] p.2; [L1] p.72 |
| 3 | Military power, P-38L | 1,475 bhp (SECONDARY, Baugher); SP-468 lists 1,470 | — | [L5] |
| 3 | WEP | **1,600 bhp (1,193 kW) each at 60 in Hg, 3,000 rpm**; measured 1,548 bhp at sea level in flight test | — | [L4] p.2; [L2] §VI-B |
| 3 | Normal rated / max cruise | 44 in Hg, 2,600 rpm / 30 in Hg, 2,300 rpm | — | [L1] p.72 |
| 3 | Propellers | Curtiss Electric, 3 blades, 11 ft 6 in (3.51 m), constant speed | — | [L2], [L3], [L4] |
| 3 | Propeller rotation | Counter-rotating: right engine clockwise, left engine anticlockwise. The viewpoint is not stated; seen from behind, the tops of the discs move **outboard** | — | [L1] |
| 4 | **Max speed at sea level, WEP** | **345 mph TAS (154.2 m/s, 555 km/h)** | P-38J at 16,597 lb [L2] and at 16,200 lb [L4]; two sources agree | [L2] Eng-47-1706-A; [L4] |
| 4 | **Max speed at sea level, military** | **339 mph TAS (151.5 m/s)** | P-38J at 16,200 lb; Lockheed test, not checked by Wright Field | [L4] p.1 |
| 4 | Max speed at sea level, P-38L | **NOT FOUND** in a primary source | — | — |
| 4 | Speed versus altitude, WEP | 362.5 mph at 5,000 ft; 379 at 10,000; 409 at 20,000; **421.5 mph (188.4 m/s) at 25,800 ft (critical)** | P-38J at 16,597 lb | [L2] |
| 4 | Critical altitude (Lockheed) | 428 mph at 29,000 ft on WEP; 419 mph at 30,500 ft on military | P-38J | [L4] |
| 4 | Critical altitude (SP-468) | 414 mph at 25,000 ft | P-38L at 17,500 lb | [L5] |
| 5 | **Climb at sea level, WEP** | **4,000 ft/min (20.3 m/s) at 160 mph TAS** | P-38J at 16,597 lb | [L2] §VI-D |
| 5 | Climb at sea level, WEP (other tests) | 4,050 ft/min at 16,200 lb [L4]; 3,570 ft/min at 17,363 lb [L3] | — | — |
| 5 | **Climb at sea level, military** | **3,720 ft/min (18.9 m/s)** | P-38J at 16,200 lb | [L4] p.2 |
| 5 | Climb at sea level, normal rated | about 2,000 ft/min (GRAPH) | **P-38L** 44-25092, 44 in / 2,600 rpm | [L7] |
| 5 | Best-climb speed | 155–175 mph IAS; the manual says hold **165 mph IAS (73.8 m/s)** | — | [L1] p.73 |
| 6 | Stall, power off, clean | 94 / **100** / 105 mph IAS (42.0 / **44.7** / 46.9 m/s) | 15,000 / **17,000** / 19,000 lb | [L1] p.73 |
| 6 | Stall, power off, gear and flaps down | 69 / **74** / 78 mph IAS (30.8 / **33.1** / 34.9 m/s) | Same weights | [L1] p.73 |
| 6 | Stall, P-38J-15 (**disagrees** with [L1]) | Power off: clean 97.5; gear down 99.5; flaps down 86.0; gear and flaps down **80.5** mph IAS | 17,363 lb | [L3] §V-e |
| 6 | Stall (SP-468) | 105 mph | 17,500 lb | [L5] |
| 6 | CLmax | **NOT FOUND.** Taken at face value, [L1]'s IAS gives an implausible clean CLmax of about 2.0 and about 3.7 flaps down; the airspeed system under-reads at low speed. [L3] is more plausible | — | — |
| 6 | Critical single-engine speed (Vmc) | 110 mph IAS [L2]; 115 mph IAS [L3]. "Safe single-engine speed" (training): 130 mph IAS | — | [L2], [L3], [L1] |
| 7 | Take-off technique (tricycle) | Roll forward to line up the nosewheel; run up on the brakes. No flap preferred; about half flap (scan partly illegible) for short fields or drop tanks. The aircraft sits level with the wing at negative angle of attack, so it must be lifted off: **ease back at 80 mph, airborne at about 100 mph (44.7 m/s)** | — | [L1] pp.70–71 |
| 7 | Take-off distance | Lift-off in 10 s / **1,378 ft (420 m)** at 54 in / 3,000 rpm; 14 s / 1,833 ft at 45 in; 18 s / 2,287 ft at 35 in. Weight not stated; "approximate" | — | [L1] "P-38 Takeoffs" chart |
| 7 | Distance over 50 ft | **NOT FOUND** | — | — |
| 8 | Landing pattern | Downwind 175 mph with gear down; base 150 mph; full flaps; glide at 130 mph holding at least 15 in Hg; **110 mph over the fence (49.2 m/s)**; **touch down 90–100 mph on the mains, nose held off**; steer with rudder. Add 15 mph with full drop tanks | — | [L1] |
| 8 | Landing roll | **NOT FOUND** | — | — |
| 9 | Cruise | 351 mph at 43.4 in / 2,600 rpm (1,185 bhp); 313.5 mph at 33 in / 2,300 rpm; 268.5 mph at 24.4 in / 1,600 rpm auto-lean | P-38J, 11,850 ft, 16,597 lb | [L2] §VI-C |
| 9 | Cruise and range | 339 mph for 475 mi; 195 mph for 1,175 mi | P-38L, internal fuel | [L5] text p.132 |
| 10 | Roll, aileron boost on | Time to 90° bank about 1.7 s at 125 mph IAS, 0.87 s at 200, 0.55 s at 300, 0.47 s at 400. **Average rate about 53 / 103 / 164 / 191°/s.** GRAPH | "P-38-J with hydraulic ailerons"; includes roll-in time, so the steady rate is higher | [L8] |
| 10 | Roll, boost off | About 3.0 s at 125 mph; 2.0 s at 200; 1.85 s minimum at about 250; 2.3 s at 300; 3.0 s at 355. **About 30 / 45 / 49 / 39 / 30°/s** | Same chart | [L8] |
| 10 | Boost effect | "Triples the rate of roll" | — | [L1] p.52 |
| 10 | NACA roll data | **NOT FOUND.** TR 868 has no P-38 | — | [X2] |
| 11 | Nosewheel | **No steering control described.** Shimmy damper; line the wheel up by rolling forward; steer with brakes and throttles. Free-castering is **inferred**, not stated | — | [L1]; [L2] §IV-A |
| 11 | Ground attitude | Sits **level**; wing at negative angle of attack on the take-off roll | — | [L1] |
| 11 | Main-gear track | 198 in (5.03 m) | — | [L6] Fig. 2 |
| 11 | Wheelbase | About 120.8 in (3.07 m); **poorly legible, verify** | — | [L6] Fig. 2 |
| 11 | Brakes | Hydraulic, on a separate system; "considerable pressure" needed | — | [L1]; [L3] |
| 12 | Glide | Normal glide 125–130 mph IAS, power off. **Sink rate NOT FOUND** | — | [L3] §IV-l |
| 12 | Max L/D | 13.5 | — | [L5] |
| 13 | **CD0** | **0.0268**; drag area f = 8.78 ft² (0.816 m²) | S = 327.5 ft²; DERIVED by SP-468 | [L5] Table III p.484 |

**Sources.** All are US government works and public domain unless noted.
- [L1] AAF Manual **51-127-1**, *Pilot Training Manual for the Lightning P-38*, 1 Aug 1945. https://archive.org/details/PilotTrainingManualP38
- [L2] Memo Report **Eng-47-1706-A**, 4 Feb 1944, *Flight Tests of a P-38J Airplane*, AAF 42-67869. https://web.archive.org/web/2022/http://www.wwiiaircraftperformance.org/p-38/p-38-67869.html
- [L3] Memo Report **Eng-47-1771-A**, 5 July 1944, P-38J-15 43-28392 on 44-1 fuel. https://web.archive.org/web/2022/http://www.wwiiaircraftperformance.org/p-38/p-38-28392.html
- [L4] AAF Materiel Command letter (R. O. Wickersham), 11 March 1944, *Additional Performance of P-38J Airplanes* (Lockheed tests). https://web.archive.org/web/2022/http://www.wwiiaircraftperformance.org/p-38/P-38J_performance_11march44.pdf
- [L5] = [X1] NASA SP-468 Table III p.484; text p.132.
- [L6] **AN 01-75FF-2**, *Erection and Maintenance Instructions, P-38L-1*, §I pp.1–2, Fig. 2. https://stephentaylorhistorian.com/wp-content/uploads/2020/04/army-model-p-38l-1-airplane-an-01-75ff-2-part-1.pdf
- [L7] Flight Test Engineering, P-38L 44-25092 rate-of-climb chart (Fig. 11); report number illegible. https://web.archive.org/web/2022/http://www.wwiiaircraftperformance.org/p-38/p-38l-25092-climb.jpg
- [L8] Chart "P-38-J with hydraulic ailerons: time to bank to 90°"; no document number visible, probably Lockheed or AAF. https://web.archive.org/web/2022/http://www.wwiiaircraftperformance.org/p-38/p-38j-roll.jpg
- Not reached: **AN 01-75FF-1**. Its Appendix II take-off, climb and landing chart would fill the distance over 50 ft and the landing roll. A ManualsLib reprint exists: https://www.manualslib.com/manual/2809654/Lockheed-P-38-Lightning.html

---

## 4. B-17G Flying Fortress (4 × Wright R-1820-97, turbosupercharged)

**About the sources.** The spine is the **B-17G Standard Aircraft Characteristics (SAC), 27 April 1949** [B1], all six pages read. Its "max power" figures use the **1,380 bhp** war-emergency rating.

AN 01-20EG-1 was not found as a scan. Its charts were read as reproduced in the EAA B-17 training manual [B4]. That manual is copyright EAA: cite the facts from it, do not copy it.

| # | Figure | Value (SI) | Condition | Source |
|---|---|---|---|---|
| 1 | Empty weight | 35,972 lb (16,317 kg); basic 37,672 lb (17,088 kg) | — | [B1] p.3 |
| 1 | Empty weight (SP-468) | 36,135 lb (16,390 kg) | — | [X1] Table II p.483 |
| 1 | Combat weight (performance quoted at) | **48,692 lb (22,086 kg)** | Basic-mission combat weight | [B1] p.4 |
| 1 | Gross weight | 55,000 lb (24,948 kg) | — | [X1] Table II |
| 1 | Max take-off (**sources disagree**) | 67,860 lb (30,781 kg), "limited by structure" | — | [B1] p.3 |
| 1 | Max take-off, second value | 64,500 lb (29,257 kg) "maximum gross" | — | [B3] AAF 50-13 |
| 1 | Max take-off, civil | 59,000 lb (26,762 kg) | Civil type certificate LTC-1 | [B4] p.27 |
| 2 | Wing area / span / aspect ratio | 1,420 ft² (131.9 m²) / 103.8 ft (31.64 m) / **7.58**; MAC 177.5 in (4.51 m) | — | [B1] p.2; [X1] |
| 2 | Airfoil | Listed as NACA 0018 root, NACA 0010 tip (thickness family). "Boeing 103" is UNSOURCED | — | [B1] p.2 |
| 2 | Flaps | Split, 45° full | — | [B4] |
| 3 | Take-off / military | **1,200 bhp (895 kW) each**; 2,500 rpm, 46 in Hg at sea level; military rating held to 25,000 ft | — | [B1] pp.3, 6; [X1] |
| 3 | War emergency ("max power") | **1,380 bhp (1,029 kW) each**, 2,500 rpm, about 51 in Hg (GRAPH); critical altitude 26,700 ft | Basis of the SAC max-power figures | [B1] p.6; [B4] p.97 |
| 3 | Normal rated | 1,000 bhp (746 kW), 2,300 rpm | — | [B1] p.3 |
| 3 | Propellers | Hamilton Standard Hydromatic, 3 blades, **11 ft 7 in (3.53 m)**, constant speed, full-feathering; reduction 0.5625 | — | [B1] p.3; [B4] p.52 |
| 4 | **Max speed at sea level, max power** | **about 215 kn (110.6 m/s, 247 mph, 398 km/h), GRAPH** | 48,692 lb, 4 × 1,380 bhp | [B1] p.5 speed chart (read by eye twice, independently) |
| 4 | **Max speed at sea level, normal power** | **about 191 kn (98.3 m/s, 220 mph), GRAPH** | 48,692 lb, 4 × 1,000 bhp | [B1] p.5 |
| 4 | Max speed at altitude | 282 kn (145.1 m/s, 324 mph) at 26,700 ft; 278 kn at 25,000 ft | 48,692 lb, max power | [B1] p.4 |
| 4 | Max speed at altitude (flight tests, **disagrees** with [B1]) | 296 mph at 25,000 ft military; 277 mph normal (43-37746, 1945); 297.5–300 mph at 24,900 ft (1944 paint test) | Military = 1,200 bhp | [B5] summaries |
| 4 | Max speed at altitude (SP-468) | 287 mph at 25,000 ft | 55,000 lb, 4 × 1,200 bhp | [X1] Table II |
| 5 | **Climb at sea level** | **1,870 ft/min (9.50 m/s)** max power at 48,692 lb; 2,140 ft/min (10.9 m/s) at 43,982 lb; 630 ft/min (3.2 m/s) at 67,860 lb normal power | — | [B1] p.4 |
| 5 | Climb speeds | Climb about 150 mph IAS (67 m/s) at 35 in / 2,300 rpm | Modern civil practice, not wartime | [B4] pp.30, 141–142 |
| 6 | Stall, power off (mph IAS; flaps up / middle column / full flap) | 40,000 lb: 89 / 86 / 79 · 50,000 lb: **100 / 96 / 88** · 60,000 lb: 110 / 105 / 97 · 70,000 lb: 118 / 114 / 104. GRAPH, from a low-resolution rotated scan; the middle-column header is illegible | — | AN 01-20EG-1 Fig. 89 via [B4] p.100 |
| 6 | Stall (SAC) | 89.0 kn (45.8 m/s, 102 mph) power off; matches the full-flap column | 67,860 lb | [B1] p.4 |
| 6 | Stall (SP-468) | 90 mph | 55,000 lb | [X1] |
| 6 | CLmax | **NOT FOUND.** DERIVED from the stall table: about 1.39 clean, about 1.77 full flap | — | DERIVED |
| 7 | Take-off distance | Ground run **3,780 ft (1,152 m)**; over 50 ft **4,925 ft (1,501 m)** at 67,860 lb. At 64,975 lb: 3,350 / 4,400 ft | Sea level, no wind, "normal technique"; flap not stated | [B1] p.4 |
| 7 | Take-off distance, lighter | Ground run about 1,100 ft at 44,000 lb, about 2,000 ft at 55,000 lb (GRAPH) | — | [B1] p.5 chart |
| 7 | Lift-off speed | 90 / 95 / 100 / 105 / 110 / 113 mph IAS at 40 / 45 / 50 / 55 / 60 / 65 thousand lb | — | AN 01-20EG-1 chart via [B4] p.99 |
| 7 | Take-off technique | Line up, then **lock the tailwheel**. Flaps 0 (⅓ for short field). Rudder plus differential power early. Raise the tail slightly to a medium tail-low attitude; lift off at about 100 mph. Short field: tail held down, three-point lift-off at 70–75 mph | Modern EAA practice | [B4] pp.130, 141–143 |
| 7 | Wartime take-off technique | EAA says the wartime manuals teach a **three-point lift-off**. The Pilot Training Manual's own take-off pages were **not extracted** (the OCR truncates; the 123 MB PDF is at [B3]) | — | [B4] p.150 |
| 8 | Approach | Downwind 130 mph at 1,000 ft; base 110–120 mph; **threshold 100–105 mph (45–47 m/s)**; short field 95 mph; no-flap 110–115 mph; final flaps ⅔ or full | Modern EAA practice | [B4] pp.31, 144, 146, 157 |
| 8 | Landing roll | **1,265 ft (386 m)** ground roll; 2,710 ft (826 m) from 50 ft | 43,214 lb, sea level | [B1] p.4 |
| 8 | Landing technique | EAA: "tail-low touchdown", then lower the tail; three-point for short fields. The **Pilot Training Manual's wording was NOT FOUND** | — | [B4] pp.145–146 |
| 9 | Cruise | **171 kn (88.0 m/s, 197 mph) at 10,000 ft**, basic mission average; 156 kn long-range; 182 kn (93.6 m/s) at 25,000 ft | — | [B1] p.4 |
| 9 | Cruise (SP-468) | 182 mph, altitude unknown | — | [X1] Table II |
| 9 | Max cruise setting | 2,100 rpm, 31 in Hg, about 760 hp | — | [B4] p.97 |
| 10 | Roll rate | **NOT FOUND** | — | — |
| 11 | Tailwheel | Locks in the centre from the cockpit; **full swivel when unlocked**; no steering linkage. "For all straight ahead taxiing… keep the tailwheel locked"; "before making a turn, have the copilot unlock the tailwheel"; "make turn by using the throttles, with as little brakes as possible" | — | [B4] p.37; [B3] AAF 50-13 |
| 11 | Main-gear track | **21.1 ft (6.43 m)** | — | [B1] p.3 |
| 11 | Brakes | Hydraulic expander-tube, metered from the pedals | — | [B4] pp.61–64 |
| 11 | Three-point attitude | **NOT FOUND** in degrees. EAA: lift-off attitude is "approximately the same as … sitting on the ramp" | — | [B4] p.141 |
| 12 | Glide / sink | **NOT FOUND** | — | — |
| 12 | Max L/D | 12.7 | — | [X1] Table II |
| 13 | **CD0** | **0.0302**; drag area f = 42.83 ft² (3.98 m²) | S = 1,420 ft²; DERIVED by SP-468 | [X1] Table II p.483 and text p.121 |
| 13 | CD0 about 0.024 | **NOT FOUND** for the B-17. SP-468 gives **0.0241 for the B-29**, which is probably where that figure comes from | — | [X1] Table III |

**Disagreements**
- **Max take-off weight:** 67,860 lb (SAC) against 64,500 lb (Pilot Training Manual).
- **Top speed:** the SAC's 282 kn (324 mph) uses 1,380 bhp WEP. Flight tests on 1,200 bhp military power measured about 296–300 mph. SP-468 gives 287 mph.
- **The SP-468 CD0 of 0.0302 is consistent with the SAC sea-level speed.** A check at about 247 mph, 48,692 lb, 4 × 1,380 bhp, η = 0.8 and e = 0.75 gives a required power close to the available power.

### B-17G crew stations and guns

| Station | Crew member | Guns (.50 cal M2) | Source |
|---|---|---|---|
| Nose, chin turret (Bendix, remote, sighted from the nose) | Bombardier | 2 (365 rounds each) | [B1] p.3 (count and ammunition); bombardier operation per [B4] |
| Nose, cheek guns | Navigator (and bombardier) | 2, one each side (305 rounds each) | [B1] p.3. Who mans them: [B4]. **Which cheek gun sits further forward: NOT FOUND** |
| Flight deck | Pilot, co-pilot | — | [B1] p.3 |
| Top turret (Sperry, behind the flight deck) | Flight engineer / top turret gunner | 2 (650 rounds each) | [B1] p.3; [B4] pp.34–35 |
| Radio room | Radio operator | 1 flexible gun through the roof hatch. **Deleted on later blocks** (from B-17G-85-VE 44-8817 per a secondary site); not listed in the 1949 SAC | [B3] AAF 50-13 ("The radio compartment is equipped with one .50-cal. machine gun"); deletion SECONDARY (b17flyingfortress.de) |
| Ball turret (Sperry) | Ball turret gunner | 2 (500 rounds each) | [B1] p.3; [B4] |
| Waist, left and right | 2 waist gunners (1 on some late-war crews) | 1 each, 2 total (600 rounds each). Windows level on early G, staggered on later G | [B1] p.3; [B4] pp.34–35 |
| Tail | Tail gunner | 2 (565 rounds each); "Cheyenne" tail turret on later G | [B1] p.3; Cheyenne start date SECONDARY / NOT FOUND |

- **Total:** 13 guns with the radio-room gun, 12 without it.
- NASA SP-468 p.121: "the B-17G carried no less than 13 .50-caliber machine guns".
- The 1949 SAC lists **12 guns and no radio gun**. Its crew list is: pilot, co-pilot, navigator, bombardier, upper turret gunner, lower turret gunner, radio operator, side gunner(s), tail gunner.

**Sources**
- [B1] **Standard Aircraft Characteristics, B-17G**, Air Materiel Command, 27 April 1949, 6 pp. US government work, public domain. http://www.wwiiaircraftperformance.org/B-17/B-17G_Standard_Aircraft_Characteristics.pdf
- [B2] **AN 01-20EG-1**, *Pilot's Flight Operating Instructions, B-17F/G*. No scan found; its Figures 87–90 were read only as reproduced in [B4]. Public domain.
- [B3] AAF Manual **50-13**, *Pilot Training Manual for the B-17 Flying Fortress* (rev. 1 May 1945). Public domain. https://archive.org/details/50-13. The take-off and landing pages need reading by hand from the PDF.
- [B4] EAA, *Flight Training Manual for the Flying Fortress*, rev. 3-4-2012. **Copyright EAA**; facts only. It includes CAA Type Certificate Data Sheet LTC-1, a US government work. https://www.eaa.org/~/media/files/eaa/flight%20experiences/safety/b-17-flight-training-manual.pdf
- [B5] wwiiaircraftperformance.org B-17 index: Eng-47-1722-A (1944 paint-finish test) and TSCEP5E-1909 (1945 test). Summary figures only; the scans were not rendered. https://www.wwiiaircraftperformance.org/B-17/B-17.html
- Radio-gun deletion (SECONDARY, copyright): https://b17flyingfortress.de/en/production-block/b-17g-85-ve-44-8801-44-8900/

---

## Shared sources

- **[X1]** L. K. Loftin Jr., *Quest for Performance: The Evolution of Modern Aircraft*, **NASA SP-468**, 1985. NTRS 19850023776; NASA marks it "GOV_PUBLIC_USE_PERMITTED", public domain. https://ntrs.nasa.gov/citations/19850023776 (121 MB PDF).
  - Appendix A Table II p.483 has the B-17G row: 1,200 hp ×4; Wg 55,000; We 36,135; b 103.8; S 1,420; Vmax 287 mph at 25,000 ft; Vc 182; Vs 90; CD0 0.0302; f 42.83; A 7.58; (L/D)max 12.7.
  - Table III p.484 has the P-51D row (1,490 hp; 10,100 / 7,125 lb; b 37.0; S 233; 437 mph at 25,000 ft; Vc 362; Vs 100; CD0 0.0163; f 3.80; A 5.86; L/D 14.6) and the P-38L row (1,470 hp ×2; 17,500 / 12,800 lb; b 52.0; S 327.5; 414 mph at 25,000 ft; Vs 105; CD0 0.0268; f 8.78; A 8.26; L/D 13.5).
  - Appendix C pp.509–511 gives the estimation method: η 0.70–0.85, e 0.70–0.75.
  - There is **no P-47 row**.
- **[X2]** T. A. Toll, *Summary of Lateral-Control Research*, **NACA Report 868**, 1947. Fig. 47 p.40: rolling velocity against IAS at 50 lb stick force, 10,000 ft. It plots P-51B-1-NA, XP-51, P-47C-1-RE, P-40F, P-39D, P-63A, F6F-3, F4F-3, FW 190, Spitfire and Zero. **No P-38, P-51D, P-47D or B-17.** Public domain. https://ntrs.nasa.gov/citations/19930090943
- **[X3]** NACA, *Correlation of the Drag Characteristics of a P-51B Airplane Obtained from High-Speed Wind-Tunnel and Flight Tests*. NTRS 19930092458; **not read**. Public domain. https://ntrs.nasa.gov/citations/19930092458

## Gaps worth a manual follow-up

1. **P-47D-30 flight manual AN 01-65BC-1A** (paid, AirCorps Library). It would give the D-30 weights, the R-2800-59 military bhp, a take-off/landing chart and the stall table.
2. **P-47 CD0.** No source at all. It could be derived by the SP-468 method from the [T3] or [T4] speeds, but that would be our number, not a published one.
3. **P-38L:** a primary sea-level speed, the take-off distance over 50 ft and the landing roll (AN 01-75FF-1 Appendix II).
4. **B-17G:** the Pilot Training Manual's own take-off and landing technique and speeds ([B3], read the PDF by hand); a legible AN 01-20EG-1 stall chart; roll rate.
5. **Three-point ground attitude in degrees** for the P-51D and the B-17G. Only the P-47 has one (12°, NACA TN 2675 Fig. 1).
6. **Roll rates** for the exact variants. NACA TR 868 plots only the P-51B, XP-51 and P-47C. For the P-38J the only source is a chart of time to 90° bank.
7. **Measured P-51 drag:** read the NACA P-51B drag-correlation report [X3] for a flight-measured CD0 to set beside SP-468's derived 0.0163.

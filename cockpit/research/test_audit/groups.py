"""GROUPS THE 291 SUITES BY WHAT THEY ASSERT. Written by lane/testaudit for the 2026-09-20 audit.

Ordered rules over the suite name and its own doc-block title. The first rule that matches wins,
and OVERRIDE names every suite a rule gets wrong -- so the grouping is re-derivable, and every
disagreement with it is one line in this file rather than an argument about taste.

    python cockpit/research/test_audit/groups.py
"""
import csv, re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
AUD = Path(__file__).resolve().parent

# Hand overrides: suite -> group, where the rules below land it in the wrong place.
OVERRIDE = {
    "fit": "crew", "shell_room": "crew", "hull_hidden": "crew", "screens_face": "crew",
    "seat_room": "crew", "pilot_seat": "crew", "plot_room": "crew", "boat_seats": "crew",
    "turret_seats": "crew", "stations": "crew", "station_budget": "crew", "many_seats": "crew",
    "warbird_cockpit": "crew", "crew_sync": "crew", "crew_join": "crew", "crew_cabin": "crew",
    "crew_peers": "crew", "restage": "crew", "nobody_aboard": "crew",
    "smoke": "housekeeping", "lint": "housekeeping", "docs": "housekeeping",
    "build_stamp": "housekeeping", "build_time": "housekeeping", "build_export": "housekeeping",
    "hitch": "housekeeping", "sheet_cost": "housekeeping", "trace_cost": "housekeeping",
    "handling": "flying", "vehicle_gym": "flying", "flight_fingerprint": "flying",
    "trim": "flying", "climb": "flying", "avoid": "flying", "rota": "flying",
    "ship_legs": "flying", "sailing": "flying", "seakeeping": "flying", "pirate_ai": "flying",
    "train_runs": "flying", "segway": "flying", "segway_keys": "flying", "braking_curve": "flying",
    "ground_stick": "flying", "water_rudder": "flying", "holding_stack": "flying",
    "traffic_pattern": "flying", "altitude_hold": "flying", "trace_log": "flying",
    "trace_replay": "flying", "world_edge": "flying", "far_out": "flying",
    "craft_model_audit": "shape", "aircraft_fidelity": "shape", "named_parts": "shape",
    "joined_parts": "shape", "lights_on_skin": "shape", "phantom_wear": "shape",
    "many_kinds": "shape",
    "marshalling": "devices", "sense": "devices", "clipboard": "devices", "craft_page": "devices",
    "tower": "devices", "director": "devices", "signal_lamp": "devices", "map_page": "devices",
    "level_map": "devices", "map_screen": "devices", "air_picture": "devices",
    "radar_set": "devices", "sight_line": "devices", "spotting": "devices", "feel": "devices",
    "many_devices": "devices", "device_router": "devices", "device_farm": "devices",
    "room_transport": "devices", "room_load_proof": "devices",
    "ranging_sight": "weapons", "attackers": "weapons", "hulls": "weapons", "bursts": "weapons",
    "respawn": "weapons", "crashes": "weapons", "water": "weapons",
    "fires": "world", "seethrough": "world", "transition_curtain": "world",
    "level_swap": "world", "levels": "world",
    "long_message": "net", "radio_clip": "net", "craft_package": "net", "issue": "net",
    "cockpit_loopback": "upstream", "vr_loopback": "upstream",
    "radio_peers": "session", "air": "world", "night_lights": "world",
    "tank_shape": "shape", "skyhawk": "shape", "prowler": "shape", "brig": "shape",
    "cooling_towers": "shape", "hangar": "shape", "oil_platform": "shape",
    "shore_structures": "shape", "road_vehicles": "shape", "fleet_shapes": "shape",
    "warthog_seat": "weapons", "warthog_flight": "flying", "warbird_circuit": "flying",
    "rotor_rates": "flying", "rotor_turn": "flying", "falcon_flight": "flying",
    "taildragger": "flying", "apache_flight": "flying", "littlebird_flight": "flying",
    "scenery": "world", "authored_chunks": "world", "airbase_taxi": "crew",
    "radar_peers": "devices", "spotting_peers": "devices", "craft_peers": "net",
    "gliderlevel_peers": "world", "sweep_peers": "devices", "lamp_peers": "devices",
    "builder_peers": "devices", "crew_peers": "crew", "lobby_peers": "session",
    "lobby2d_peers": "session", "names_peers": "session", "intercom_peers": "session",
    "players_peers": "session", "handshake_peers": "session", "music_peers": "session",
    "jet_arms_peers": "weapons", "server_peers": "net", "sky_peers": "world",
    "pirate_wire": "net", "exhaust": "shape",
}

# name-or-title rules, in order. The first match wins.
RULES = [
    ("upstream", r"^(conformance|physics_rewind|resim_|two_clients|predict_all|input_release|tracing|"
                 r"balance_probe|car_collision|correction_smoothness|reverse_wheels|roll_probe|tire_slip|"
                 r"top_speed|handling_probe|driving_loopback)"),
    ("housekeeping", r"^(lint|docs|build_|smoke|hitch)"),
    ("session", r"^(session|launch_order|desk_join|lobby|names|join_code|steam_join|code_pad|players|"
                r"handshake|intercom|headphones|voice_|music_|record_shelf|desk_screens|two_peers|no_vr_flight)"),
    ("net", r"_peers$|^(latency|link_ms|net_stats|bulk_|priority_|pose_lod|save_bandwidth|input_window|"
            r"command_burst|shell_prediction|gun_link|hull_link|cue_crowd|crowd_|notices|sky_peers|level_join|"
            r"level_hello|pirate_wire|server_peers|missile_cues|lamp_wire)"),
    ("weapons", r"gun|missile|shot|shell|arms|helmet|bays|crash|hull|respawn|turret"),
    ("devices", r"builder|device|clipboard|page|screen|hand|pinch|snap|pedal|control|lamp|switch|tower|director"),
    ("world", r"level|terrain|ground|mountain|rock|forest|town|scenery|canyon|seabed|airbase|airport|pavement|"
              r"world_map|chunk|mist|daytime|puff|sky|wind_sea|water_surfaces|wakes|air$|hangar|cooling|oil_platform|"
              r"shore|testfield|gliderlevel|adriatic|brig"),
    ("flying", r"flight|circuit|book|flies|handling|climb|trim|rotor|sail|seakeep|taxi|surfaces|taildragger|"
               r"legs|gym|fingerprint|brak|stick|rudder|traffic"),
    ("shape", r"."),   # the fallback: a suite that measures a drawn thing against a published figure
]

GROUP_TITLE = {
    "shape": "What a thing is SHAPED like -- geometry off drawn vertices",
    "flying": "How a craft FLIES, drives or sails",
    "crew": "Crew, seats and stations",
    "devices": "Devices, controls and the pages that show them",
    "weapons": "Guns, missiles and damage",
    "net": "The wire: peers, authority and replication",
    "session": "Getting into the game: session, lobby, identity, voice",
    "world": "The world: levels, ground, scenery, weather",
    "housekeeping": "Housekeeping: lint, docs, the build, and cost",
    "upstream": "The extension underneath -- ashiato, Box3D and the car",
}


def group_of(name, title):
    if name in OVERRIDE:
        return OVERRIDE[name]
    hay = (name + " " + title).lower()
    for g, pat in RULES:
        if re.search(pat, hay):
            return g
    return "shape"


def main():
    meas = {r["name"]: r for r in csv.DictReader(open(AUD / "suites_measured.tsv", encoding="utf-8"), delimiter="\t")}
    chk = {r["name"]: r for r in csv.DictReader(open(AUD / "checks.tsv", encoding="utf-8"), delimiter="\t")}
    ev = {r["name"]: r for r in csv.DictReader(open(AUD / "evidence.tsv", encoding="utf-8"), delimiter="\t")}
    tit = {r["name"]: r for r in csv.DictReader(open(AUD / "titles.tsv", encoding="utf-8"), delimiter="\t")}

    out = open(AUD / "grouped.tsv", "w", newline="", encoding="utf-8")
    w = csv.writer(out, delimiter="\t")
    w.writerow(["group", "name", "tiers", "lines", "secs", "assertions", "commits", "learnings", "peers", "title"])
    agg = {}
    for n, m in meas.items():
        g = group_of(n, tit[n]["title"])
        secs = float(m["secs"]) if m["secs"] else None
        a = agg.setdefault(g, dict(n=0, lines=0, secs=0.0, timed=0, asserts=0, commits=0, learn=0,
                                   core=0, untiered=0, peers=0))
        a["n"] += 1
        a["lines"] += int(m["lines"])
        a["asserts"] += int(chk[n]["assertions"])
        a["commits"] += int(ev[n]["commits"])
        a["learn"] += int(ev[n]["learnings_todo_files"])
        if secs is not None:
            a["secs"] += secs
            a["timed"] += 1
        if "core" in m["tiers"]:
            a["core"] += 1
        if m["tiers"] == "-":
            a["untiered"] += 1
        peers = 1 if re.search(r"create_process|OS\.execute|--join|second engine|_spawn", 
                               (ROOT / m["script"]).read_text(encoding="utf-8", errors="replace")) else 0
        a["peers"] = a.get("peers", 0) + peers
        w.writerow([g, n, m["tiers"], m["lines"], m["secs"], chk[n]["assertions"], ev[n]["commits"],
                    ev[n]["learnings_todo_files"], peers, tit[n]["title"]])
    out.close()

    head = ("group", "n", "lines", "asrt", "secs", "commits", "learn", "core", "no-tier", "peers")
    print("%-13s %4s %7s %6s %7s %8s %6s %5s %8s %6s" % head)
    for g, a in sorted(agg.items(), key=lambda kv: -kv[1]["lines"]):
        print("%-13s %4d %7d %6d %7.0f %8d %6d %5d %8d %6d"
              % (g, a["n"], a["lines"], a["asserts"], a["secs"], a["commits"], a["learn"],
                 a["core"], a["untiered"], a.get("peers", 0)))
    t = lambda k: sum(a[k] for a in agg.values())
    print("%-13s %4d %7d %6d %7.0f %8d %6d %5d %8d %6d"
          % ("TOTAL", t("n"), t("lines"), t("asserts"), t("secs"), t("commits"), t("learn"),
             t("core"), t("untiered"), t("peers")))
    print("\n(secs = the sum of the runner's own recorded medians; only %d of %d suites have one)"
          % (t("timed"), t("n")))


if __name__ == "__main__":
    main()

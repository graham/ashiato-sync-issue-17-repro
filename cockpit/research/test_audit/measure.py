"""MEASURING SCRIPT FOR THE 2026-09-20 TEST AUDIT. Written by lane/testaudit; not part of the suite.

Reads cockpit/tests/suites.txt, resolves every row to the script behind its scene, counts what is
there, and joins it to the wall-clock the RUNNER ITSELF recorded in %TEMP%/cockpit_tests_*/durations.txt.

    python cockpit/research/test_audit/measure.py            # writes suites_measured.tsv beside itself

Nothing here runs Godot. Every number it prints can be re-derived by running it again.
"""
import csv, os, re, sys, glob, json, statistics, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
COCKPIT = ROOT / "cockpit"
TESTS = COCKPIT / "tests"
OUT = Path(__file__).resolve().parent

TIERS = ("core", "net", "solo", "slow")


def read_suites():
    rows = []
    for raw in (TESTS / "suites.txt").read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        p = line.split()
        name, project, scene = p[0], p[1], p[2]
        deadline, tiers = 0, []
        for cell in p[3:]:
            if re.fullmatch(r"[0-9]+", cell):
                deadline = int(cell)
            else:
                tiers += [t for t in cell.split(",") if t]
        rows.append(dict(name=name, project=project, scene=scene, deadline=deadline, tiers=tiers))
    return rows


def scene_to_script(project, scene):
    """res://tests/trim.tscn -> the .gd its ExtResource points at."""
    base = COCKPIT if project == "cockpit" else ROOT / "ashiato-gd" / "addon"
    rel = scene.replace("res://", "")
    tscn = base / rel
    if not tscn.exists():
        return None
    body = tscn.read_text(encoding="utf-8", errors="replace")
    # TWO ATTRIBUTE ORDERS IN THIS TREE: `type="Script" ... path=` and `path=... type="Script"`.
    # The first pattern alone missed three rows (long_message, craft_peers, issue) and they looked
    # like suites with no script at all, which is the shape of a real fault.
    pat_a = r'ext_resource[^\n]*type="Script"[^\n]*path="res://([^"]+)"'
    pat_b = r'ext_resource[^\n]*path="res://([^"]+)"[^\n]*type="Script"'
    m = re.search(pat_a, body) or re.search(pat_b, body)
    if not m:
        return None
    gd = base / m.group(1)
    return gd if gd.exists() else None


def count_file(path):
    """lines, code lines (not blank, not comment), doc-block lines (## ...), comment lines."""
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    doc = code = comment = blank = 0
    for ln in lines:
        s = ln.strip()
        if not s:
            blank += 1
        elif s.startswith("##"):
            doc += 1
        elif s.startswith("#"):
            comment += 1
        else:
            code += 1
    return dict(
        lines=len(lines), code=code, doc=doc, comment=comment, blank=blank,
        ticks=len(re.findall(r"get_ticks_msec", text)),
        results=len(re.findall(r'"RESULT=', text)) + len(re.findall(r"'RESULT=", text)),
        awaits=len(re.findall(r"\bawait\b", text)),
        physics_frames=len(re.findall(r"physics_frame", text)),
        preloads=re.findall(r'(?:pre)?load\("res://([^"]+)"\)', text),
        text=text,
    )


def durations():
    """Every durations.txt the runner has written in every checkout, medianed per suite."""
    by = {}
    temp = Path(os.environ.get("TEMP", r"C:\Users\Graham\AppData\Local\Temp"))
    files = sorted(temp.glob("cockpit_tests_*/durations.txt"))
    for f in files:
        for row in f.read_text(encoding="utf-8", errors="replace").splitlines():
            c = row.split()
            if len(c) == 2:
                try:
                    by.setdefault(c[0], []).append(float(c[1]))
                except ValueError:
                    pass
    return {k: (statistics.median(v), len(v), max(v)) for k, v in by.items()}, len(files)


def main():
    suites = read_suites()
    dur, nfiles = durations()
    used_scripts = set()
    out = []
    for s in suites:
        gd = scene_to_script(s["project"], s["scene"])
        row = dict(s)
        row["tiers"] = ",".join(s["tiers"]) or "-"
        row["script"] = str(gd.relative_to(ROOT)).replace("\\", "/") if gd else ""
        if gd:
            used_scripts.add(gd.resolve())
            c = count_file(gd)
            row.update(lines=c["lines"], code=c["code"], doc=c["doc"], comment=c["comment"],
                       ticks=c["ticks"], awaits=c["awaits"], results=c["results"])
        else:
            row.update(lines=0, code=0, doc=0, comment=0, ticks=0, awaits=0, results=0)
        d = dur.get(s["name"])
        row["secs"] = round(d[0], 1) if d else ""
        row["secs_n"] = d[1] if d else 0
        row["secs_max"] = round(d[2], 1) if d else ""
        out.append(row)

    cols = ["name", "project", "tiers", "deadline", "secs", "secs_max", "secs_n",
            "lines", "code", "doc", "comment", "ticks", "awaits", "results", "script", "scene"]
    with open(OUT / "suites_measured.tsv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=cols, delimiter="\t", extrasaction="ignore")
        w.writeheader()
        for r in out:
            w.writerow(r)

    all_gd = sorted(p for p in TESTS.rglob("*.gd"))
    orphans = [p for p in all_gd if p.resolve() not in used_scripts]
    total_lines = sum(count_file(p)["lines"] for p in all_gd)
    with open(OUT / "orphans.txt", "w", encoding="utf-8") as f:
        for p in orphans:
            f.write("%s\t%d\n" % (p.relative_to(TESTS), len(p.read_text(encoding='utf-8', errors='replace').splitlines())))

    untiered = [r for r in out if r["tiers"] == "-"]
    print("suites.txt rows           : %d" % len(suites))
    print("  with a script resolved  : %d" % sum(1 for r in out if r["script"]))
    print("  script NOT resolved     : %s" % ([r["name"] for r in out if not r["script"]] or "none"))
    print(".gd files under tests/    : %d  (%d lines)" % (len(all_gd), total_lines))
    print("  reached by a suite row  : %d" % len(used_scripts))
    print("  NOT reached (orphans)   : %d  (%d lines)" % (len(orphans), sum(len(p.read_text(encoding='utf-8',errors='replace').splitlines()) for p in orphans)))
    print("lines in suite scripts    : %d" % sum(r["lines"] for r in out))
    for t in TIERS:
        rs = [r for r in out if t in r["tiers"].split(",")]
        print("  tier %-5s              : %3d suites, %6d lines, %s s of recorded wall-clock"
              % (t, len(rs), sum(r["lines"] for r in rs), round(sum(r["secs"] for r in rs if r["secs"] != ""), 0)))
    print("  NO TIER AT ALL          : %3d suites, %6d lines" % (len(untiered), sum(r["lines"] for r in untiered)))
    print("durations.txt files read  : %d, covering %d of %d suites" % (nfiles, sum(1 for r in out if r["secs"] != ""), len(out)))
    print("total recorded wall-clock : %.0f s over %d timed suites (median of %d samples each)"
          % (sum(r["secs"] for r in out if r["secs"] != ""), sum(1 for r in out if r["secs"] != ""),
             round(statistics.mean([r["secs_n"] for r in out if r["secs_n"]]))))
    print("get_ticks_msec sites      : %d in suite scripts, %d in every .gd under tests/"
          % (sum(r["ticks"] for r in out), sum(count_file(p)["ticks"] for p in all_gd)))


if __name__ == "__main__":
    main()

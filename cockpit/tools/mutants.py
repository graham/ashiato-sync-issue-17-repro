"""Runs a model's suite against one mutant at a time and says which check each one turned red (lane/warbirds).

    from mutants import run_all
    run_all("res://tests/p51.tscn", MUTANTS)

Each craft's `craft/<kind>/mutants.py` holds its own list and calls this. Each mutant is THE BUG, not the source's
number (`modelling_here.md` section 6): the fault a check exists to catch, typed back into the airframe. A mutant is
(name, file relative to the project, anchor, replacement, the check it must turn red). The runner refuses a mutant whose
anchor is not in its file exactly once (a mutant that did not apply prints PASS), prints "applied", restores the file's
whole text afterwards whatever happened, and judges the run by its RESULT= line under a deadline. A mutant is KILLED when
the check it names is red, and whatever else it turned red is printed beside it: a leg that does not shorten also meets its
door, and a wing built short also moves its guns, and those are the model being consistent, not the checks overlapping.
"""
import os
import subprocess
import sys

PROJECT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
GODOT = os.path.expanduser(
    "~/Desktop/godotgames/_tools/godot-4.7.2-double/godot.windows.editor.double.x86_64.console.exe")


def run(scene):
    env = dict(os.environ)
    temp = os.environ.get("WARBIRDS_TEMP")
    if temp:
        env["TEMP"] = env["TMP"] = temp
    try:
        done = subprocess.run([sys.argv[1] if len(sys.argv) > 1 else GODOT, "--headless", "--xr-mode", "off",
                               "--desktop-only", "--path", PROJECT, scene], capture_output=True, text=True,
                              timeout=240, env=env)
        out = done.stdout
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or b"").decode() if isinstance(e.stdout, bytes) else (e.stdout or "")
    lines = [line for line in out.splitlines() if line.startswith("RESULT=")]
    return lines[-1] if lines else "RESULT=NONE (no result line: a parse error or a hang)"


def run_all(scene, mutants):
    good = 0
    for name, rel, anchor, replacement, check in mutants:
        path = os.path.join(PROJECT, rel)
        with open(path, "rb") as f:
            original = f.read()
        text = original.decode("utf-8")
        if text.count(anchor) != 1:
            print("REFUSED %s: its anchor is in %s %d times" % (name, rel, text.count(anchor)))
            continue
        try:
            with open(path, "wb") as f:
                f.write(text.replace(anchor, replacement).encode("utf-8"))
            print("applied: %s" % name)
            result = run(scene)
        finally:
            with open(path, "wb") as f:
                f.write(original)
        red = result.startswith("RESULT=FAIL") and check in result
        others = result.replace("RESULT=FAIL", "").replace(check, "").strip(" ,")
        good += 1 if red else 0
        print("  %s -> %s%s" % ("KILLED" if red else "SURVIVED", check if red else result,
                                ("  (also red: %s)" % others) if red and others else ""))
    print("%d of %d mutants killed by their own checks" % (good, len(mutants)))

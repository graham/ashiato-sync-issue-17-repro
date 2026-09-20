"""Write `ashiato-gd/src/cockpit/flight/handling_fields.inc` from `struct Handling` itself.

    python cockpit/tools/generate_handling_fields.py          # writes it, prints what changed
    python cockpit/tools/generate_handling_fields.py --check  # says whether it is up to date, and writes nothing

WHY IT IS GENERATED. The list is the one place a per-kind tuning number is declared, and `cockpit_world.cpp` makes the
struct, `set_handling` and `handling()` from it. But the numbers themselves still live in the struct's own
declaration, where the doc block above each one explains what it is and what it cost to learn -- and those comments are
the most valuable thing in that file. So the struct stays the source, and this writes the list from it.

WHAT IT IS FOR, in practice: a lane that adds a field (lane/warbirds2's `ground_mutant`, say) adds it to the struct
with its comment, as it always did, and runs this. Nothing is typed twice and nothing is typed here at all. A rebase
that lands new fields is the same one command.

Read RESULT=. It exits 1 if `--check` finds the file stale, so a suite or a gate can run it.
"""

import argparse
import pathlib
import re
import sys

HEAD = """\
// EVERY NUMBER IN `Handling`, ONE ROW EACH: the one list a per-kind tuning number is added to (lane/flightcore, step 1).
//
// A field used to be typed three times -- in `struct Handling`, in `set_handling`'s `dict_get` and in `handling()`'s
// dictionary -- a hundred and fifty lines apart, and the file's own comment warns what the third one is for:
// `set_handling` "treats a misspelled key as absent, so a typo leaves the setting at its default while the game goes on
// believing it applied". A field missed in `set_handling` is a `--set=` that silently does nothing; one missed in
// `handling()` is a number no suite can read back. Now it is a row here, and cockpit_world.cpp makes all three from it.
//
//   HANDLING_FIELD(name, default)
//
// WRITTEN BY `cockpit/tools/generate_handling_fields.py` FROM `struct Handling` ITSELF, so the struct keeps the doc
// blocks that say what each number is and what it cost to learn, and this file cannot drift from them. Add a field to
// the struct, with its comment, and run the script.
//
// The row order is the struct's, so the file still reads as the table it is, and the sections are the struct's too.
// What is NOT here: the `Rig` a ship under sail carries (a struct, not a number), and `cruise_pinned`, which is a
// second NAME for `cruise` in the dictionary. Both stay hand-written beside the generated ones.
//
// The same shape as `cockpit_kinds.inc`, and for the same reason (lane/kinds, 2026-09-18): a list kept in three places
// is a list kept in one place and two copies of it.
"""


def fields_from(source: str) -> str:
    """The rows, and the struct's own section comments, in the struct's order."""
    start = source.index("struct Handling {")
    end = source.index("\n};", start)
    out = []
    for line in source[start:end].split("\n"):
        section = re.match(r"^\s{4}// ---- (.*) ----", line)
        if section:
            out.append("// ---- %s ----" % section.group(1))
        field = re.match(r"^\s{4}float (\w+) = ([^;]+);", line)
        if field:
            out.append("HANDLING_FIELD(%s, %s)" % (field.group(1), field.group(2)))
    return HEAD + "\n" + "\n".join(out) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="say whether it is up to date; write nothing")
    args = parser.parse_args()
    here = pathlib.Path(__file__).resolve().parent.parent.parent
    world = here / "ashiato-gd" / "src" / "cockpit" / "cockpit_world.cpp"
    target = here / "ashiato-gd" / "src" / "cockpit" / "flight" / "handling_fields.inc"
    wanted = fields_from(world.read_text(encoding="utf-8", errors="replace"))
    rows = wanted.count("HANDLING_FIELD(")
    have = target.read_text(encoding="utf-8") if target.exists() else ""
    if have.replace("\r\n", "\n") == wanted:
        print("RESULT=PASS %d fields, up to date" % rows)
        return 0
    if args.check:
        print("RESULT=FAIL %s is stale: %d fields in the struct. Run the script." % (target.name, rows))
        return 1
    target.write_text(wanted, encoding="utf-8", newline="\n")
    print("RESULT=PASS wrote %d fields to %s" % (rows, target.name))
    return 0


if __name__ == "__main__":
    sys.exit(main())

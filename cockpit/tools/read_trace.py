#!/usr/bin/env python3
"""Read a craft trace (`CraftTrace`, one `.jsonl` file) and say whether any control is hunting.

    python cockpit/tools/read_trace.py flight.jsonl [--from S] [--to S] [--deadband 0.02] [--json] [--chart out.png]

The file is JSON lines: a header line, then one sample per line (the field list is in `world/craft_trace.gd`). A killed
run's last line may be cut short; it is skipped and counted, not fatal.

For every channel -- the stick (pitch, roll, rudder, brake, throttle), the levers, and the attitude, spin and speed -- it
prints the minimum, maximum and mean, and SIGN CHANGES A SECOND (sc/s): how often the channel crosses its own whole-flight mean, which
is the right number for a leg flown straight and level. HUNT/S is the number for a flight with manoeuvres in it: how often the
channel crosses its own moving average (`--window`, 2 s), so a circuit's turns are not counted but a stick sawing about where it is
going is. A stick that
holds a value has a number near zero; one sawing about what it wants has one that is large. A crossing must clear
`--deadband` (a fraction of the channel's own range, default 5 %, and never less than a floor for its unit: half a degree, 0.02 rad/s or lever, 0.3 m/s) to count, so noise sitting on the mean is not an
oscillation. The last column is the period of the sawing in seconds, when there is one.

Exit status 2 for a file with no samples or no header, 0 otherwise.
"""
import argparse
import json
import statistics
import sys


def load(path):
    header, samples, bad = None, [], 0
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                bad += 1
                continue
            if header is None and "trace" in row:
                header = row
            elif "tick" in row:
                samples.append(row)
            else:
                bad += 1
    return header, samples, bad


def channels(samples):
    """{name: [(t, value)]} for every numeric channel the samples carry."""
    out = {}

    def put(name, t, value):
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            return
        out.setdefault(name, []).append((t, float(value)))

    for row in samples:
        t = row["t"]
        for key in ("speed", "aoa", "slip"):
            if key in row:
                put(key, t, row[key])
        for group in ("stick", "levers", "euler"):
            for key, value in (row.get(group) or {}).items():
                put("%s.%s" % (group, key), t, value)
        for key in ("pos", "vel", "spin"):
            for axis, value in zip("xyz", row.get(key) or []):
                put("%s.%s" % (key, axis), t, value)
    return out


def sign_changes(series, deadband, floor=0.0):
    """How many times the series crosses its mean by more than the deadband, and the crossings' times."""
    values = [v for _, v in series]
    mean = statistics.fmean(values)
    band = max(floor, deadband * (max(values) - min(values)))
    if band <= 0.0:
        return []
    side, crossings = 0, []
    for t, v in series:
        now = 1 if v - mean > band else -1 if v - mean < -band else 0
        if now == 0:
            continue
        if side != 0 and now != side:
            crossings.append(t)
        side = now
    return crossings


def detrended(series, window):
    """The series minus its own moving average over `window` seconds (centred, on the samples' own clock).

    A whole-flight mean is the wrong line to count crossings of: a circuit's turns move a channel a long way on purpose.
    What hunting looks like is a channel crossing where it has just BEEN, over and over, so the line is the channel's
    own recent past."""
    times = [t for t, _ in series]
    prefix = [0.0]
    for _, v in series:
        prefix.append(prefix[-1] + v)
    out, lo, hi = [], 0, 0
    for i, (t, v) in enumerate(series):
        while times[lo] < t - window / 2.0:
            lo += 1
        while hi < len(times) and times[hi] <= t + window / 2.0:
            hi += 1
        out.append((t, v - (prefix[hi] - prefix[lo]) / (hi - lo)))
    return out


def floor_for(name):
    """The smallest swing worth calling a swing, in the channel's own unit. A channel that barely moves has a tiny range,
    so five per cent of it is noise: a parked craft's pitch of 0.02 degrees would otherwise be a wild oscillation."""
    group = name.split(".")[0]
    return {"euler": 0.5, "aoa": 0.5, "slip": 0.5, "spin": 0.02, "stick": 0.02, "levers": 0.02, "speed": 0.3, "vel": 0.3,
            "pos": 1.0}.get(group, 0.0)


def crossings_about_zero(series, band):
    side, out = 0, []
    for t, v in series:
        now = 1 if v > band else -1 if v < -band else 0
        if now == 0:
            continue
        if side != 0 and now != side:
            out.append(t)
        side = now
    return out


def summarise(samples, deadband, window=2.0):
    rows = []
    span = samples[-1]["t"] - samples[0]["t"]
    for name, series in channels(samples).items():
        values = [v for _, v in series]
        crossings = sign_changes(series, deadband, floor_for(name))
        rate = len(crossings) / span if span > 0 else 0.0
        period = 2.0 * span / len(crossings) if len(crossings) >= 2 and span > 0 else None
        # HUNTING: crossings of the channel's own 2-second average, each of which must clear `deadband` of the channel's swing.
        hunts = crossings_about_zero(detrended(series, window), max(floor_for(name), deadband * (max(values) - min(values))))
        rows.append({"channel": name, "min": min(values), "max": max(values), "mean": statistics.fmean(values),
                     "sign_changes": len(crossings), "per_second": rate, "period": period,
                     "hunting_per_second": len(hunts) / span if span > 0 else 0.0})
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("file")
    parser.add_argument("--from", dest="start", type=float, default=None, help="first second to read")
    parser.add_argument("--to", dest="end", type=float, default=None, help="last second to read")
    parser.add_argument("--deadband", type=float, default=0.05)
    parser.add_argument("--window", type=float, default=2.0, help="seconds of the moving average hunting is judged against")
    parser.add_argument("--json", action="store_true", help="print the table as JSON")
    parser.add_argument("--chart", help="write a PNG of the stick channels against time (needs matplotlib)")
    args = parser.parse_args()

    header, samples, bad = load(args.file)
    if header is None or not samples:
        print("%s: no header or no samples (%d unreadable lines)" % (args.file, bad), file=sys.stderr)
        return 2
    if args.start is not None:
        samples = [s for s in samples if s["t"] >= args.start]
    if args.end is not None:
        samples = [s for s in samples if s["t"] <= args.end]
    if len(samples) < 2:
        print("fewer than two samples in that window", file=sys.stderr)
        return 2

    span = samples[-1]["t"] - samples[0]["t"]
    rows = summarise(samples, args.deadband, args.window)
    if args.json:
        print(json.dumps({"header": header, "duration": span, "samples": len(samples), "unreadable": bad,
                          "channels": rows}, indent=1))
    else:
        print("%s %s entity %s, %d Hz, stick %s" % (args.file, header.get("kind"), header.get("entity"),
                                                    header.get("hz"), header.get("stick")))
        print("%.2f s, %d samples, %d unreadable lines, flown by %s" % (
            span, len(samples), bad, ",".join(sorted({s.get("flown", "?") for s in samples}))))
        print("%-16s %10s %10s %10s %8s %8s %6s" % ("channel", "min", "max", "mean", "sc/s", "hunt/s", "period"))
        for row in rows:
            if row["channel"].split(".")[0] in ("pos", "quat"):
                continue
            print("%-16s %10.3f %10.3f %10.3f %8.2f %8.2f %6s" % (
                row["channel"], row["min"], row["max"], row["mean"], row["per_second"], row["hunting_per_second"],
                "%.2f" % row["period"] if row["period"] else "-"))

    if args.chart:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        wanted = [name for name in channels(samples) if name.startswith("stick.") and name != "stick.brake"]
        fig, axes = plt.subplots(len(wanted) + 1, 1, sharex=True, figsize=(10, 2 + 1.6 * len(wanted)))
        series = channels(samples)
        for axis, name in zip(axes, wanted):
            axis.plot([t for t, _ in series[name]], [v for _, v in series[name]], lw=0.8)
            axis.set_ylabel(name.split(".")[1])
        axes[-1].plot([t for t, _ in series["euler.roll"]], [v for _, v in series["euler.roll"]], lw=0.8)
        axes[-1].set_ylabel("roll deg")
        axes[-1].set_xlabel("seconds")
        fig.suptitle("%s %s" % (header.get("kind"), args.file))
        fig.savefig(args.chart, dpi=110)
    return 0


if __name__ == "__main__":
    sys.exit(main())

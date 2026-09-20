"""Reads an SVG line drawing into polylines in the drawing's own document units.

Shared by `measure_threeview.py`. It exists because the two F-16 three-views this model is measured from are VECTOR
files, and a vector drawing can be measured from its own coordinates rather than from pixels: no rasterising, no
anti-aliasing, no rotation of a scanned page (the EA-6B's sheet was turned 0.26 degrees). Handles what the two files
actually use -- nested <g> with translate/scale/matrix transforms, and path commands M L H V C S Q T Z in both cases.
Arcs are not used by either file and raise, so a third drawing that needs them says so rather than drops them.
"""
import math
import re
import xml.etree.ElementTree as ET

CURVE_STEPS = 12


def _matrix(text):
    m = [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]
    for name, args in re.findall(r"(\w+)\s*\(([^)]*)\)", text or ""):
        v = [float(a) for a in re.split(r"[\s,]+", args.strip()) if a]
        if name == "translate":
            t = [1, 0, 0, 1, v[0], v[1] if len(v) > 1 else 0.0]
        elif name == "scale":
            t = [v[0], 0, 0, v[1] if len(v) > 1 else v[0], 0, 0]
        elif name == "matrix":
            t = v
        elif name == "rotate":
            a = math.radians(v[0])
            t = [math.cos(a), math.sin(a), -math.sin(a), math.cos(a), 0, 0]
        else:
            raise ValueError("transform %s not handled" % name)
        m = _mul(m, t)
    return m


def _mul(a, b):
    return [a[0] * b[0] + a[2] * b[1], a[1] * b[0] + a[3] * b[1],
            a[0] * b[2] + a[2] * b[3], a[1] * b[2] + a[3] * b[3],
            a[0] * b[4] + a[2] * b[5] + a[4], a[1] * b[4] + a[3] * b[5] + a[5]]


def _apply(m, p):
    return (m[0] * p[0] + m[2] * p[1] + m[4], m[1] * p[0] + m[3] * p[1] + m[5])


def _tokens(d):
    return re.findall(r"[A-Za-z]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?", d)


def _bezier(p0, p1, p2, p3):
    out = []
    for i in range(1, CURVE_STEPS + 1):
        t = i / CURVE_STEPS
        u = 1 - t
        out.append((u ** 3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t ** 3 * p3[0],
                    u ** 3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t ** 3 * p3[1]))
    return out


def path_polylines(d):
    toks = _tokens(d)
    i = 0
    cmd = None
    cur = (0.0, 0.0)
    start = cur
    last_ctrl = None
    lines = []
    line = []

    def num():
        nonlocal i
        v = float(toks[i])
        i += 1
        return v

    while i < len(toks):
        if re.match(r"[A-Za-z]", toks[i]):
            cmd = toks[i]
            i += 1
            if cmd in "zZ":
                if line:
                    line.append(start)
                    lines.append(line)
                line = []
                cur = start
                last_ctrl = None
                continue
        rel = cmd.islower()
        c = cmd.upper()
        ox, oy = cur if rel else (0.0, 0.0)
        if c == "M":
            if line:
                lines.append(line)
            cur = (ox + num(), oy + num())
            start = cur
            line = [cur]
            cmd = "l" if rel else "L"
            last_ctrl = None
        elif c == "L":
            cur = (ox + num(), oy + num())
            line.append(cur)
            last_ctrl = None
        elif c == "H":
            cur = ((cur[0] if rel else 0.0) + num(), cur[1])
            line.append(cur)
            last_ctrl = None
        elif c == "V":
            cur = (cur[0], (cur[1] if rel else 0.0) + num())
            line.append(cur)
            last_ctrl = None
        elif c == "C":
            p1 = (ox + num(), oy + num())
            p2 = (ox + num(), oy + num())
            p3 = (ox + num(), oy + num())
            line.extend(_bezier(cur, p1, p2, p3))
            last_ctrl = p2
            cur = p3
        elif c == "S":
            p1 = (2 * cur[0] - last_ctrl[0], 2 * cur[1] - last_ctrl[1]) if last_ctrl else cur
            p2 = (ox + num(), oy + num())
            p3 = (ox + num(), oy + num())
            line.extend(_bezier(cur, p1, p2, p3))
            last_ctrl = p2
            cur = p3
        elif c == "Q":
            q = (ox + num(), oy + num())
            p3 = (ox + num(), oy + num())
            line.extend(_bezier(cur, (cur[0] + 2 / 3 * (q[0] - cur[0]), cur[1] + 2 / 3 * (q[1] - cur[1])),
                                (p3[0] + 2 / 3 * (q[0] - p3[0]), p3[1] + 2 / 3 * (q[1] - p3[1])), p3))
            cur = p3
            last_ctrl = None
        else:
            raise ValueError("path command %s not handled" % cmd)
    if line:
        lines.append(line)
    return lines


def read(path):
    """Every path in the file as a list of (x, y) points in document units, transforms applied. Returns a list of
    dicts {"points", "filled", "stroke"} so a caller can tell a black-filled canopy from an outline."""
    tree = ET.parse(path)
    out = []

    def walk(node, m, style):
        m = _mul(m, _matrix(node.get("transform")))
        st = dict(style)
        for k in ("fill", "stroke", "stroke-width"):
            if node.get(k) is not None:
                st[k] = node.get(k)
        for part in (node.get("style") or "").split(";"):
            if ":" in part:
                k, v = part.split(":", 1)
                st[k.strip()] = v.strip()
        tag = node.tag.split("}")[-1]
        shapes = []
        if tag == "path":
            shapes = path_polylines(node.get("d"))
        elif tag in ("circle", "ellipse"):
            cx, cy = float(node.get("cx", 0)), float(node.get("cy", 0))
            rx = float(node.get("r", node.get("rx", 0)))
            ry = float(node.get("r", node.get("ry", 0)))
            shapes = [[(cx + rx * math.cos(a * math.pi / 36), cy + ry * math.sin(a * math.pi / 36)) for a in range(73)]]
        elif tag == "rect" and st.get("stroke") not in (None, "none"):
            # A rect with no stroke is a page background, not a line of the drawing.
            x, y = float(node.get("x", 0)), float(node.get("y", 0))
            w, h = float(node.get("width")), float(node.get("height"))
            shapes = [[(x, y), (x + w, y), (x + w, y + h), (x, y + h), (x, y)]]
        for pl in shapes:
            out.append({"points": [_apply(m, p) for p in pl], "fill": st.get("fill"), "stroke": st.get("stroke"),
                        "width": st.get("stroke-width"), "id": node.get("id")})
        for child in node:
            walk(child, m, st)

    walk(tree.getroot(), [1, 0, 0, 1, 0, 0], {})
    return out

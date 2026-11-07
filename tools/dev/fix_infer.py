#!/usr/bin/env python3
"""Dev-Helfer: führt den Godot-Check aus und ersetzt `var x := <Variant-Ausdruck>` durch explizite Typen."""
import re, subprocess, sys
G = "/home/user/tools/godot/Godot_v4.7.2-stable_linux.x86_64"
pat = re.compile(r'Cannot infer the type of "(\w+)"|inferred from a Variant value')
for it in range(40):
    out = subprocess.run(["timeout", "90", G, "--headless", "--path", ".", "res://tools/dev/Check.tscn"],
                         capture_output=True, text=True).stdout + ""
    out += subprocess.run(["true"], capture_output=True, text=True).stdout
    lines = (out).splitlines()
    res = subprocess.run(["timeout", "90", G, "--headless", "--path", ".", "res://tools/dev/Check.tscn"], capture_output=True, text=True)
    lines = (res.stdout + res.stderr).splitlines()
    errs = []
    for i, l in enumerate(lines):
        if "SCRIPT ERROR" in l and i + 1 < len(lines):
            m = re.search(r"\(res://(.+?):(\d+)\)", lines[i + 1])
            if m:
                errs.append((l, m.group(1), int(m.group(2))))
    if not errs:
        print("keine Fehler"); sys.exit(0)
    fixed = 0
    for msg, f, ln in errs:
        if not pat.search(msg):
            print("NICHT AUTO:", msg.strip(), f, ln); continue
        src = open(f).read().split("\n")
        line = src[ln - 1]
        m = re.match(r"(\s*)var (\w+) := (.*)$", line)
        if not m:
            print("kein Muster:", f, ln, line); continue
        expr = m.group(3)
        t = "float"
        if "Vector3(" in expr or "origin" in expr or "basis" in expr or "global_position" in expr or ".position" in expr and "x" not in expr.split(".position")[-1][:2]:
            t = "Vector3"
        if "Vector2(" in expr and "Vector3(" not in expr:
            t = "Vector2"
        if re.search(r"\bint\(|randi|\.size\(\)|_lane|lane\b", expr) and "float" not in expr:
            t = "int"
        if re.search(r"\bas (\w+)", expr):
            t = re.search(r"\bas (\w+)", expr).group(1)
        src[ln - 1] = f"{m.group(1)}var {m.group(2)}: {t} = {expr}"
        open(f, "w").write("\n".join(src))
        print(f"fix {f}:{ln} -> {t}")
        fixed += 1
    if not fixed:
        sys.exit(1)
